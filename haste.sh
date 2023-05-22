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
	clear
	stty -ixon # Disable XON/XOFF
	stty -echo # Dont echo user input
	stty intr '' # Unbind sigint, normally ctrl-c
}

restore_term() {
	printf '\e[?1049l'
	stty "$default_settings"
}

bottom_bar() {
	local base_string=" haste v$HASTE_VERSION | $file_name $((curl+1))/${#text_buffer[@]}"
	if [[ $modified == true ]];
	then
		base_string+=" | modified | "
	else
		base_string+=" | unmodified | "
	fi
	base_string+="Files: $( printf '%s, ' ${file_names[@]})"
	printf '\e[%sH\e[7m%-*s\e[0m' "$((lines-1))" "$columns" "$base_string"
}

notify() {
	local message="[ $* ]"
	printf '\e[%sH\e[K\e[%sC' "$lines" "$(( ( columns / 2 ) - ( ${#message} / 2 ) ))"
	printf '\e[7m'
	echo -n "$message" | cat -v
	printf '\e[0m'
}

draw_text() {
	local count=$((topl+1))
	printf '\e[H'
	for line in "${text_buffer[@]:$topl:$((lines-2))}"
	do
		[[ "$line_numbers" = true ]] && printf '\e[7m%*s\e[0m ' 3 "$count" && ((count+=1))
		printf '\e[K'
		line="${line//$'\t'/    }"
		if (( ${#line} > columns - 6 ))
		then
			echo -n "${line:0:$((columns-6))}"
			printf '\e[7m>\e[0m\n'
		else
			echo "$line"
		fi
	done
}

draw_cursor() {
	local temp="${text_buffer[curl]:0:curc}"
	local temp2="${text_buffer[curl]:curc}"
	printf '\e[%sH' "$((curl - topl + 1))"
	[[ "$line_numbers" = true ]] && printf '\e[4C'
	temp="${temp//$'\t'/    }"
	printf '\e[31m'
	if (( "$curc" > columns / 2 ))
	then
		echo -n "${temp:$(( curc - ( columns / 2 ) ))}"
		printf '\e[0m'
		echo -n "$temp2"
		printf '\e[K'
		[[ -n "$temp2" ]] && printf '\e[%sD' "${#temp2}"
	else
		echo -n "$temp"
	fi
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
	(( ( curl - topl ) < scroll_margin )) && (( ${#text_buffer[@]} > lines - 3 )) && (( topl = curl - scroll_margin ))
	# Scroll down bottom
	(( ( curl - topl ) > ( lines - scroll_margin - 3 ) )) && (( ${#text_buffer[@]} > lines - 3 )) && (( topl = curl - ( lines - scroll_margin - 3 ) ))
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
	modified=true
}

duplicate_line() {
	text_buffer=("${text_buffer[@]:0:$curl}" "${text_buffer[curl]}" "${text_buffer[curl]}" "${text_buffer[@]:curl+1}")
	modified=true
}

search_for() {
	printf '\e[%sH' "$lines"
	stty echo
	read -e -p 'Search: ' temp
	stty -echo
	[[ -n "$temp" ]] && readarray -t search_locs < <(printf '%s\n' "${text_buffer[@]}" | grep -n "$temp" | cut -d':' -f1)
	for i in "${search_locs[@]}"
	do
		[[ "$i" -gt $((curl+1)) ]] && curl=$((i-1)) && return
	done
	[[ -n "${search_locs[@]}" ]] && curl="$(( ${search_locs[0]} - 1 ))"
	scroll
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
				'[1;3A')
					text_buffer=("${text_buffer[@]:0:curl-1}" "${text_buffer[curl]}" "${text_buffer[curl-1]}" "${text_buffer[@]:curl+1}")
					((curl-=1)) ;; # Alt + up
				'[1;3B')
					text_buffer=("${text_buffer[@]:0:curl}" "${text_buffer[curl+1]}" "${text_buffer[curl]}" "${text_buffer[@]:curl+2}")
					((curl+=1)) ;; # Alt + down
				'[1;3C') ((curc=${#text_buffer[curl]})) ;; # Alt + right
				'[1;3D') ((curc=0)) ;; # Alt + left
				'[3~')
					(( curc += 1 ))
					column_san
					backspace ;;
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
		$'\ca') (( curc = 0 )) ;;
		$'\cd') duplicate_line && (( curl += 1 )) ;;
		$'\ce') (( curc = ${#text_buffer[curl]} )) ;;
		$'\cf') search_for ;;
		$'\ch') help_box 1 $(( columns / 2 )) $(( lines - 1 )) $(( columns - ( columns / 2 ) + 1 )) ;;
		$'\ck') text_buffer=("${text_buffer[@]:0:curl}" "${text_buffer[@]:curl+1}") ;;
		$'\cn')
			meta_buffer=("${meta_buffer[@]:0:curb}" "$curl $curc $topl $modified" "${meta_buffer[@]:curb}")
			(( curb += 1 ))
			(( curb > ${#file_names[@]} - 1 )) && (( curb = 0 ))
			(( curb < 0 )) && (( curb = 0 ))
			reload_buffer ;;
		$'\co') open_new ;;
		$'\cq') close_buffer ;;
		$'\cr') exec $0 ${args[@]} ;;
		$'\cs') save_func ;;
		*) notify "Unknown / Unbound key $char" ;;
	esac
	line_san
	column_san
	scroll
	(( topl >= ${#text_buffer[@]} - lines + 2 )) && (( topl = ${#text_buffer[@]} - lines + 2 ))
	(( topl <= 0 )) && topl=0
}

reload_buffer() {
	file_name="${file_names[curb]}"
	readarray -t text_buffer <<<"${text_buffers[curb]}"
	read -r curl curc topl modified <<<"${meta_buffer[curb]}"
}

close_buffer() {
	case "$modified" in
		'true')
			printf '\e[%sH' "$lines"
			stty echo
			read -e -p 'Save changes? (y/n) ' temp
			stty -echo
			case "$temp" in
				'y'*|'Y'*) save_func ;;
			esac ;;
	esac

	file_names=("${file_names[@]:0:curb}" "${file_names[@]:curb+1}")
	text_buffers=("${text_buffers[@]:0:curb}" "${text_buffers:0:curb}")
	meta_buffers=("${meta_buffers[@]:0:curb}" "${meta_buffers:0:curb}")
	(( curb -= 1 ))
	(( curb > ${#file_names[@]} - 1 )) && (( curb = 0 ))
	(( curb < 0 )) && (( curb = 0 ))
	case "${#file_names[@]}" in
		0) running=false ;;
		*) reload_buffer ;;
	esac
}

save_func() {
	[[ -z "$file_name" ]] && read -e -p 'Filename to save: ' file_name
	printf '%s\n' "${text_buffer[@]}" > "$file_name"
	notify "Saved file $file_name"
	modified=false
}

open_new() {
	printf '\e[%sH' "$lines"
	stty echo
	read -e -p 'Open: ' temp
	stty -echo
	[[ -z "$temp" ]] && return
	if [[ -f "$temp" ]]
	then
		file_names+=("$temp")
		temp2=$(cat "$temp")
		text_buffers+=("$temp2")
		meta_buffer+=("0 0 0 false")
	else
		notify "File $temp not found / editable"
	fi
	((curb+=1))
	reload_buffer
}

help_box() {
	file_names+=(help)
	meta_buffer+=("0 0 0 false")
	temp=$(cat <<-'EOF'
	  Welcome to haste!
	Haste is a text editor written in (almost) pure bash

	  Navigation
	It can be navigated with the arrow keys
	Press Ctrl - Q to close the current buffer, or exit if there is only one
	Press Ctrl - S to save current buffer to file
	Press Ctrl - H to bring up help (but you already knew that)
	Press Ctrl - E / Alt - Right to go to end of line
	Press Ctrl - A / Alt - Left to go to start of line
	Press Ctrl - D to duplicate line
	Press Ctrl - K to delete line
	Press Ctrl - N to switch to the next buffer
	Press Ctrl - O to open a new file
	Press Ctrl - F to search (and leave empty to jump to next of previous search)
	Press Ctrl - R to reload the script (mostly just a development thing, mostly just for me)


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
	   This is useful for testing things such as testing PS1 variables (@P) without opening a whole extra bash session

	EOF
	)
	text_buffers+=("$temp")
	((curb+=1))
	reload_buffer
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
		*) eval "${temp[@]}" ;;
	esac
	stty -echo
}

#
# Main
#


scroll_margin=3
line_numbers=true

args=("$@")

file_names=()
text_buffers=()

for opt in "${args[@]}"
do
	if [[ -f "$opt" ]];
	then
		# Files
		file_names+=("$opt")
		temp=$(cat "$opt")
		text_buffers+=("$temp")
		# Curl, Curc, topl, modified
		meta_buffer+=("0 0 0 false")
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

file_name="${file_names[0]}"
readarray -t text_buffer <<<"${text_buffers[0]}"

[[ -z "${text_buffer[@]}" ]] && text_buffer=('')

# Current buffer
curb=0
curl=0
curc=0
topl=0
modified=false
line_numbers=true

running=true
notify "Welcome to haste! Press ^H for help"
while [[ $running == true ]];
do
	echo -n "$(
	bottom_bar
	draw_text
	draw_cursor
	)"
	input
done

restore_term
