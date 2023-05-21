#!/usr/bin/env bash

HASTE_VERSION=0.1

trap 'get_term' WINCH
#trap 'notify Error: $LINENO' ERR

get_term() {
	IFS='[;' read -sp $'\e7\e[9999;9999H\e[6n\e8' -d R -rs _ lines columns
}

setup_term() {
	read -r default_settings < <(stty -g)
	printf '\e[?1049h'
	printf '\e[?2004h' # Bracketed paste
	printf '\e[?7l'    # Disable line wrapping
	#printf '\e[?25l'  # Hide cursor
	stty -ixon # Disable XON/XOFF
	stty -echo # Dont echo user input
	stty intr '' # Unbind sigint, normally ctrl-c
}

restore_term() {
	printf '\e[?1049l'
	stty "$default_settings"
}

bottom_bar() {
	local base_string=" haste | $file_name ($((curl+1)),$((curc+1)))"
	if [[ $modified == true ]];
	then
		base_string+=" | modified"
	else
		base_string+=" | unmodified"
	fi
	printf '\e[%sH\e[7m%-*s\e[0m' "$((lines-1))" "$columns" "$base_string"
}

notify() {
	local message="[ $* ]"
	printf '\e[%sH\e[K\e[%sC' "$lines" "$(( ( columns / 2 ) - ( ${#message} / 2 ) ))"
	printf '\e[7m%s\e[0m' "$message"
}

draw_text() {
	local count=$((topl+1))
	printf '\e[H'
	for line in "${text_buffer[@]:$topl:$((lines-2))}"
	do
		[[ "$line_numbers" = true ]] && printf '\e[7m%*s\e[0m ' 3 "$count" && ((count+=1))
		printf '\e[K'
		echo "$line"
	done
}

draw_cursor() {
	local temp="${text_buffer[curl]:0:$curc}"
	printf '\e[%sH' "$((curl - topl + 1))"
	[[ "$line_numbers" = true ]] && printf '\e[4C'
	printf '\e[31m'
	echo -n "$temp"
	printf '\e[0m'
}

column_san() {
	if (( curc < 0 )) && (( curl > 0 ));
	then
		(( curl -= 1 ))
		(( curc = ${#text_buffer[curl]} ))
	elif (( curc < 0 ));
	then
		(( curc = 0 ))
	fi

	if (( curc > ${#text_buffer[curl]} )) && (( curl < ${#text_buffer[@]} - 1 ));
	then
		(( curl += 1 ))
		(( curc = 0 ))
	elif (( curc >= ${#text_buffer[curl]} ));
	then
		(( curc = ${#text_buffer[curl]} ))
	fi
}

line_san() {
	(( curl <= 0 )) && curl=0
	(( curl > ${#text_buffer[@]} - 1 )) && (( curl = ${#text_buffer[@]} - 1 ))
}

scroll() {
	# Scroll up top
	(( ( curl - topl ) < scroll_margin )) && (( topl = curl- scroll_margin ))
	# Scroll down bottom
	(( ( curl - topl ) > ( lines - scroll_margin - 3 ) )) && (( topl = curl - ( lines - scroll_margin - 3 ) ))
}

insert_char() {
	local char="$1"
	text_buffer=("${text_buffer[@]:0:curl}" "${text_buffer[curl]:0:curc}$char${text_buffer[curl]:curc}" "${text_buffer[@]:curl+1}")
	modified=true
}

backspace() {
	if (( curc >= 1 ));
	then
		text_buffer=("${text_buffer[@]:0:curl}" "${text_buffer[curl]:0:curc-1}${text_buffer[curl]:curc}" "${text_buffer[@]:curl+1}")
		((curc-=1))
	elif (( curl > 0 ))
	then
		(( curc = ${#text_buffer[curl-1]} ))
		text_buffer=("${text_buffer[@]:0:curl-1}" "${text_buffer[curl-1]}${text_buffer[curl]}" "${text_buffer[@]:curl+1}")
		(( curl -= 1 ))
	fi
	modified=true
}

newline() {
	text_buffer=("${text_buffer[@]:0:curl}" "${text_buffer[curl]:0:curc}" "${text_buffer[curl]:curc}" "${text_buffer[@]:curl+1}")
}

input() {
	read -rsN1 char
	case "$char" in
		[[:print:]]|$'\t')
			#notify "Keypress: $char"
			insert_char "$char"
			((curc+=1)) ;;
		$'\c?')
			backspace ;;
		$'\e')
			read -rsN5 -t 0.001 char
			case "$char" in
				'[5~')
					(( curl -= lines - 3 )) ;;
				'[6~')
					(( curl += lines - 3 )) ;;
				'[A')
					((curl-=1)) ;;
				'[B')
					((curl+=1)) ;;
				'[C')
					((curc+=1)) ;;
				'[D')
					((curc-=1)) ;;
				'') command_mode ;;
				*) ;;
			esac ;;
		$'\n')
			newline
			(( curc = 0 ))
			(( curl += 1 ))
			line_san ;;
		$'\ch') help_box 5 5 $((lines-10)) $((columns-10)) ;;
		$'\cq') running=false ;;
		$'\cs') save_func ;;
	esac
	line_san
	column_san
	scroll
	(( topl <= 0 )) && topl=0
	(( topl >= ${#text_buffer[@]} - lines + 2 )) && (( topl = ${#text_buffer[@]} - lines + 2 ))
}

save_func() {
	[[ -z "$file_name" ]] && read -e -p 'Filename to save: ' file_name
	printf '%s\n' "${text_buffer[@]}" > "$file_name"
	notify "Saved file $file_name"
	modified=false
}

help_box() {
	local topl="$1"
	local topc="$2"
	local height="$3"
	((height-=2))
	local width="$4"
	((width-=2))
	readarray -t help_text < <(cat <<-'EOF' | fold -s -w "$width"
	  Welcome to haste!
	Haste is a text editor written in (almost) pure bash

	  Navigation
	It can be navigated with the arrow keys
	Press Ctrl - Q to exit
	Press Ctrl - S to save current buffer to file
	Press Ctrl - H to bring up help (but you already knew that)

	  Command mode
	This is where the benefits of being written in bash begin to outweigh the negatives
	Press Esc to enter command mode
	You should now be in a prompt at the bottom of your terminal
	You now have two options:
	 - Press escape again... the story ends, you go back to your text editor and believe whatever you want to believe.
	 - Enter one of the following commands, and you see how deep the rabbithole goes...
	  Interface
	   line_numbers=[true/false]: set linenumbers on or off
	   scroll_margin=[0-9]: set scroll margin to the specified number
	  Text editing
	   line: run the specified parameter expansion on the current line only
	   buffer: run the specified parameter expansion on the whole buffer
	   line and buffer both take arguments in the form of bash parameter expansions, such as '//a/A' or '##a'. See [https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html] for further detail. 

	EOF
	)
	printf '\e[%s;%sH\e[7m+%*s+\e[0m\n' "$topl" "$topc" "$width" ''
	for index in $(seq 0 $height)
	do
		[[ "${help_text[index]+abc}" ]] && line="${help_text[index]}" || line=''
		printf '\e[%sC\e[7m \e[0m%-*s\e[7m \e[0m\n' "$((topc-1))" "$width" " $line"
	done
	printf '\e[%s;%sH\e[7m+%*s+\e[0m' "$((topl+height+1))" "$topc" "$width" 'Press any key to close '
	read -rsn1 _
}

command_mode() {
	local temp
	local temp_2
	printf '\e[%sH' "$lines"
	stty echo
	read -re -p '$ ' temp
	case "$temp" in
		'line_numbers='*|'scroll_margin='*)
			eval "$temp" ;;
		'line'*)
			temp="$(echo $temp | cut -d' ' -f2-)"
			temp_2="${text_buffer[$curl]}"
			eval 'temp=${temp_2'"$temp"'}' 2>&1
			text_buffer=("${text_buffer[@]:0:$curl}" "$temp" "${text_buffer[@]:$((curl+1))}") ;;
		'buffer'*)
			temp="$(echo $temp | cut -d' ' -f2-)"
			eval 'temp=("${text_buffer[@]'"$temp"'}")' 2>&1
			clear
			printf '%s\n' "${text_buffer[@]}"
			text_buffer=("${temp[@]}") ;;
	esac
	stty -echo
}

#
# Main
#


scroll_margin=3
line_numbers=true

for opt in "$@"
do
	if [[ -f "$opt" ]];
	then
		# Files
		file_name="$opt"
		readarray -t text_buffer <"$opt"
	else
		# Flags
		case "$opt" in
			'--scroll_margin='*)
				temp=$(<<<"$opt" cut -d'=' -f2)
				# Canonising as a number is one way to check
				((temp)) && scroll_margin="$temp" ;;
		esac
	fi
done

get_term
setup_term

[[ -z "${text_buffer[@]}" ]] && text_buffer=('' '' '')

curl=0
curc=0
topl=0
modified=false
line_numbers=true

running=true
notify "Welcome to haste! Press ^H for help"
while $running;
do
	echo -n "$(
	bottom_bar
	draw_text
	draw_cursor
	)"
	input
done

restore_term
