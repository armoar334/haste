#!/usr/bin/env bash

HASTE_VERSION=0.1

# This causes weird errors for some reason. I recommend just saving and Ctrl - R'ing
#trap 'get_term' WINCH
#trap 'notify Error: $LINENO' ERR

get_term() {
	IFS='[;' read -sp $'\e7\e[9999;9999H\e[6n\e8' -d R -rs _ lines columns
}

setup_term() {
	read -r default_settings < <(stty -g)

	printf '\e[?1049h'  # Switch buffer

	# Xterm mouse
	printf '\e[?1000h'  # Report on click
	printf '\e[?1006h'  # Legacy Mouse
	printf '\e[?1015h'  # Modern Mouse

	printf '\e[?2004h'  # Bracketed paste
	printf '\e[?7l'     # Disable line wrapping
	#printf '\e[?25l'   # Hide cursor
	printf '\e]0;haste' # Window title
	clear
	stty -ixon # Disable XON/XOFF
	stty -echo # Dont echo user input
	stty intr '' # Unbind sigint, normally ctrl-c
}

restore_term() {
	printf '\e[?1049l'
	printf '\e[?1000l'  # Mouse
	printf '\e[?1015l'  # Mouse
	printf '\e[?1006l'  # Mouse
	printf '\e]0;%s' "$TERM" # Window title
	stty "$default_settings"
}

bottom_bar() {
	local base_string=" haste v$HASTE_VERSION | $file_name $((curl+1))/${#text_buffer[@]} | $((curb+1))/${#text_buffers[@]}"
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
		if (( ${#line} > columns - 5 ))
		then
			echo -n "${line:0:$((columns-6))}"
			printf '\e[7m>\e[0m\n'
		else
			echo "$line"
		fi
	done
	#printf '\e[0J'
}

draw_cursor() {
	local temp="${text_buffer[curl]:0:curc}"
	local temp2="${text_buffer[curl]:curc}"
	printf '\e[%sH' "$((curl - topl + 1))"
	[[ "$line_numbers" = true ]] && printf '\e[4C'
	temp="${temp//$'\t'/    }"
	printf '\e[31m'
	if (( "$curc" > columns / 2 )) && (( ${#text_buffer[curl]} > columns - 6 ))
	then
		echo -n "${temp:$(( curc - ( columns / 2 ) ))}"
		printf '\e[0m\e7'
		echo -n "$temp2"
		printf '\e[K\e8'
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

bracketed_paste() {
	read -rs -d $'\e[201~' temp 
	read -rsN5 _
	for (( i=0; i<${#temp}; i++ ))
	do
		char="${temp:$i:1}"
		case "$char" in
			[[:print:]]|$'\t')
				insert_char "$char"
				((curc+=1))
				column_san ;;
			$'\n')
				newline
				(( curc = 0 ))
				(( curl += 1 ))
				line_san ;;
		esac
	done
}

backspace() {
	if (( curc >= 1 ));
	then
		text_buffer[curl]="${text_buffer[curl]:0:curc-1}${text_buffer[curl]:curc}"
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
	if [[ -n "$temp" ]]
	then
		count=1
		search_locs=()
		for i in "${text_buffer[@]}"
		do
			[[ "$i" == *"$temp"* ]] && search_locs+=("$count")
			((count++))
		done
		[[ "${#search_locs[@]}" -le 0 ]] && notify "Phrase \"$temp\" not found"
	fi
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
			case "$char" in
			'"'|"'")
				insert_char "$char$char" ;;
			'[')
				insert_char '[]' ;;
			'(')
				insert_char '()' ;;
			'{')
				insert_char '{}' ;;
			*)
				insert_char "$char" ;;
			esac
			((curc+=1)) ;;
		$'\c?')
			backspace ;;
		$'\e')
			read -rsN5 -t 0.001 char
			case "$char" in
				'[200~') bracketed_paste ;;
				'[1;3A')
					text_buffer=("${text_buffer[@]:0:curl-1}" "${text_buffer[curl]}" "${text_buffer[curl-1]}" "${text_buffer[@]:curl+1}")
					((curl-=1)) ;; # Alt + up
				'[1;3B')
					text_buffer=("${text_buffer[@]:0:curl}" "${text_buffer[curl+1]}" "${text_buffer[curl]}" "${text_buffer[@]:curl+2}")
					((curl+=1)) ;; # Alt + down
				'[1;3C') ((curc=${#text_buffer[curl]})) ;; # Alt + right
				'[1;3D') ((curc=0)) ;; # Alt + left
				'[1;5C') 
					temp="${text_buffer[curl]:curc+1}"
					temp="${temp#*[^[:alnum:]]}"
					(( curc = ${#text_buffer[curl]} - ${#temp} - 1 ));; # Ctrl - right
				'[1;5D')
					temp="${text_buffer[curl]:0:curc}"
					temp="${temp%[^[:alnum:]]*}"
					(( curc = ${#temp} ));; # Ctrl - left
				'[F') ((curc=${#text_buffer[curl]})) ;; # End
				'[H') ((curc=0)) ;; # Home
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
				'[<64;')
					(( curl -= 1 ))
					until [[ "$char" == 'M' ]]
					do
						read -rsN1 char
					done ;; # Mouse wheel up
				'[<65;')
					(( curl += 1 ))
					until [[ "$char" == 'M' ]]
					do
						read -rsN1 char
					done ;; # Mouse wheel down
				'[<0;'*)
					mouse_proc=''
					temp="$char"
					until [[ "$char" == 'M' ]] || [[ "$char" == 'm' ]]
					do
						read -rsN1 char
						mouse_proc+="$char"
					done
					if [[ "$char" == 'M' ]] # m is mouseup, so discard
					then
						IFS=';' read -d "$char" _ mx my <<<"$temp$mouse_proc"
						(( curl = topl + my - 1 ))

						temp="${text_buffer[curl]}"
						temp="${temp//[^	]/}"
						(( mx -= 5 )) # Account for line numbers
						for (( i=0; i<${#temp}; i++ ))
						do
							(( mx -= 3 )) # account for tabs
						done
						(( mx < 0 )) && (( mx = 0 ))
						#notify "Mouse X: $mx :${#temp}:"
						(( curc = mx ))
						(( curc >= ${#text_buffer[curl]} )) && (( curc = ${#text_buffer[curl]} ))
						line_san
					fi ;; # Mouse click
				'[<'*';'*)
					temp="$char"
					until [[ "$char" == 'M' ]] || [[ "$char" == 'm' ]]
					do
						read -rsN1 char
					done
					notify "Unkown / Unbound escape $temp" ;; # Discard middle click
				'') command_mode ;;
				*) notify "Unkown / Unbound escape $char" ;;
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
			temp=$(printf '%s\n' "${text_buffer[@]}")
			text_buffers[curb]="$temp"
			meta_buffer[curb]="$curl $curc $topl $modified"
			(( curb += 1 ))
			(( curb >= ${#text_buffers[@]} )) && (( curb = 0 ))
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

	unset file_names[curb]
	unset text_buffers[curb]
	unset meta_buffers[curb]

	# Rebuild arrays so no gaps
	for i in "${!file_names[@]}"; do
    	new_array+=( "${file_names[i]}" )
	done
	file_names=("${new_array[@]}")
	unset new_array

	for i in "${!text_buffers[@]}"; do
    	new_array+=( "${text_buffers[i]}" )
	done
	text_buffers=("${new_array[@]}")
	unset new_array

	for i in "${!meta_buffers[@]}"; do
    	new_array+=( "${meta_buffers[i]}" )
	done
	meta_buffers=("${new_array[@]}")
	unset new_array

	(( curb = ${#text_buffers[@]} - 1 ))

	case "${#file_names[@]}" in
		0) running=false ;;
		*) reload_buffer ;;
	esac
}

save_func() {
	if [[ -z "$file_name" ]]
	then
		printf '\e[%sH' "$lines"
		stty echo
		read -e -p 'Filename to save: ' file_name
		stty -echo
	fi
	printf '%s\n' "${text_buffer[@]}" > "$file_name"
	notify "Saved file $file_name"
	modified=false
}

open_new() {
	printf '\e[%sH' "$lines"
	stty echo
	read -e -p 'Open: ' temp
	stty -echo
	if [[ -z "$temp" ]]
	then
		return
	elif [[ -f "$temp" ]]
	then
		add_at=$(( ${#text_buffers[@]} ))
		file_names[add_at]="$temp"
		temp2=$(cat $temp)
		text_buffers[add_at]="$temp2"
		meta_buffer[add_at]="0 0 0 false"
		(( curb = ${#text_buffers[@]} - 1 ))
		reload_buffer
	else
		notify "File $temp not found / editable"
	fi
}

help_box() {
	file_names+=(help)
	meta_buffer+=("0 0 0 false")
	temp=$(cat <<-'EOF'
	  Welcome to haste!
	Haste is a text editor written in (almost) pure bash

	  Navigation
	It can be navigated with the arrow keys
	Press Ctrl - Left / Right to jump words
	Press Ctrl - Q to close the current buffer, or exit if there is only one
	Press Ctrl - S to save current buffer to file
	Press Ctrl - H to bring up help (but you already knew that)
	Press Ctrl - E / Alt - Right to go to end of line
	Press Ctrl - A / Alt - Left to go to start of line
	Press Ctrl - D to duplicate line
	Press Ctrl - K to delete line
	Press Ctrl - O to open a new file
	Press Ctrl - N to switch to the next buffer
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
	(( curb = ${#text_buffers[@]} - 1 ))
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
			IFS=' ' read -r _ temp <<<"$temp"
			temp_2="${text_buffer[$curl]}"
			eval 'temp=${temp_2'"$temp"'}' 2>&1
			text_buffer=("${text_buffer[@]:0:$curl}" "$temp" "${text_buffer[@]:$((curl+1))}") ;;
		'buffer'*)
			IFS=' ' read -r _ temp <<<"$temp"
			eval 'temp=("${text_buffer[@]'"$temp"'}")' 2>&1
			clear
			printf '%s\n' "${text_buffer[@]}"
			text_buffer=("${temp[@]}") ;;
		*) notify "Unknown command to \"${temp[@]}\"" ;;
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
		add_at=$(( ${#text_buffers[@]} ))
		# Files
		file_names[add_at]="$opt"
		temp=$(cat "$opt")
		text_buffers[add_at]="$temp"
		# Curl, Curc, topl, modified
		meta_buffer[add_at]="0 0 0 false"
	else
		# Flags
		case "$opt" in
			'--scroll_margin='*)
				temp="${opt:16}"
				# Canonising as a number is one way to check
				[[ $temp -ge 0 ]] && scroll_margin="$temp" ;;
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
notify "Welcome to haste! Press ^H to open help"
while [[ $running == true ]];
do
	echo -n "$(
	draw_text
	bottom_bar
	draw_cursor
	)"
	input
done

restore_term
