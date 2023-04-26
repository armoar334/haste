#!/usr/bin/env bash

for code in {0..7};
do
	declare f$code=$(printf '\e[3'$code'm')
	declare b$code=$(printf '\e[4'$code'm')
done

read -rd '' logo <<'EOF'
__   _    _    ____ _____ _____         _  _   
| | | |  / \  / ___|_   _| ____| __   _| || |  
| |_| | / _ \ \___ \ | | |  _|   \ \ / / || |_ 
|  _  |/ ___ \ ___) || | | |___   \ V /|__   _|
|_| |_/_/   \_\____/ |_| |_____|   \_/    |_|  
HASTE (is) another shell text editor

		(^O)pen a file
		(^Q)uit

EOF

trap 'get_term && redraw_all' WINCH

## Setup

get_term() {
	read -r lines columns _ < <(stty size)
}

setup_term() {
	printf '\e[?1049h'
	read -r default_settings < <(stty -g)
	printf '\e[?7l'
	printf '\e[?25l'
	stty -ixon
	stty -echo
	stty intr ''
}

restore_term() {
	stty "$default_settings"
	printf '\e[?1049l'
}

## Graphics

go_to() {
	# Lines then columns
	printf '\e[%s;%sH' "$1" "$2"
}

draw_logo() {
	log_lines=$(wc -l <<<"$logo")
	log_columns=$(wc -m <<<"${logo%%$'\n'*}")
	local temp_c=$(( (columns / 2) - (log_columns / 2) ))
	go_to $(( (lines / 2) - (log_lines / 2 ) ))
	while IFS= read -r line; do
		printf '\r\e['$temp_c'C%s\n' "$line"
	done <<< "$logo"
}

get_tab_size() {
	printf '\e[H'
	printf '\t'
	IFS='[;' read -sp $'\e7\e[9999;9999H\e[6n\e8' -d R -rs _ tabsize _
	faux_tab=$(printf '%-s' "$tabsize")
}

top_bar() {
	local offset=$1
	go_to 1 1
	printf '\e[7m%-*s' "$columns" | tr ' ' '-'
	go_to 1 $((offset+1))
	printf '|%s|%s|%s|%s|\e[0m' "File: ${buffer_meta[1]}" "C: $cursor_col" "L: $cursor_line" "T: $top_line"
}

bot_bar() {
	local offset=$1
	go_to $((lines - 1)) 1
	printf '%-*s' "$columns" | tr ' ' '-'
	go_to $((lines - 1)) $((offset+1))
	printf '%s\n' "|"
	printf 'Keys: \e[7m^Q\e[0m Quit \e[7m^S\e[0m Save'
}

ruler() {
	local start=$1
	local pad=$2
	go_to 2 1
	for rloop in $(seq 0 $((lines - 4)));
	do
		printf '%*s%s \n' "$pad" "$((start+rloop))"
	done
	go_to $(( (cursor_line + 2) - top_line )) 1
	printf '\e[7m%*s%s\e[0m' "$pad" "$cursor_line"
}

main() {
	local offset=$1
	go_to 2 1
	for tloop in $(seq 0 $((lines - 4)));
	do
		printf '\e[%sC\e[K%s\n' "$((offset+1))" "${buffer_text[$((top_line+tloop-1))]}"
	done
	go_to $(( (cursor_line - top_line) + 2 )) 1
	printf '\e[%sC\e[K%s' "$((offset+1))" "${buffer_text[$((cursor_line-1))]}"
}

draw_curr_line() {
	local offset=$1
	drawn=$(
	go_to $(( (cursor_line - top_line) + 2 )) 1
	printf '\e[%sC' "$((offset+1))"
	printf '%s' "${buffer_text[$((cursor_line-1))]:0:$cursor_col}"
	)
	echo -n "$drawn"
}

draw_line() {
	local offset=$1
	local cursor_line=$2
	drawn=$(
	go_to $(( (cursor_line - top_line) + 2 )) 1
	printf '\e[%sC\e[K' "$((offset+1))"
	printf '%s' "${buffer_text[$((cursor_line-1))]}"
	)
	echo -n "$drawn"
}

redraw_all() {
	drawn=$(
	offset=${#buffer_text[@]}
	offset=${#offset}
	top_bar "$offset"
	main "$offset"
	draw_curr_line "$offset"
	ruler "$top_line" "$offset"
	bot_bar "$offset"
	)
	echo -n "$drawn"	
}

redraw_main() {
	drawn=$(
	offset=${#buffer_text[@]}
	offset=${#offset}
	top_bar "$offset"
	ruler "$top_line" "$offset"
	main "$offset"
	)
	echo -n "$drawn"	

}

## Magic (not graphics)

input_loop() {
	local running=true
	top_line=1
	cursor_line=1
	cursor_col=0
	redraw_all
	while $running;
	do
		offset=${#buffer_text[@]}
		offset=${#offset}
		drawn=$(
		ruler "$top_line" "$offset"
		draw_curr_line "$offset"
		)
		echo -n "$drawn"
		printf '\e[?25h'
		read -rsn1 mode
		case "$mode" in
			$'\e') 
					read -rsn2 mode
					case "$mode" in
						'[A') cur_up && draw_line "$offset" "$((cursor_line+1))";; # Up
						'[B') cur_down && draw_line "$offset" "$((cursor_line-1))";; # Down
						'[C') cur_right ;; # Right
						'[D') cur_left  ;; # Left
						'[5') read -rsn1 _ ;; # PgUp
						'[6') read -rsn1 _ ;; # PgDn
					esac ;;
			$'\cc') echo balls ;;
			$'\cq') running=false ;;
			$'\c?') delete_char && draw_line;; # Delete
			'	') insert_char '	' ;; # I have to use lit. tabs idk y
			"") insert_newl ;;
			[[:print:]]) insert_char "$mode" ;; # Any POSIX printable 
		esac
		printf '\e[?25l'

		cur_val

		# Scroll redraw
		scroll_red=false

		# Scroll
		if [[ $(( (lines / 2) - 1 )) -le $(( cursor_line - top_line)) ]];
		then
			top_line=$(( cursor_line - ( lines / 2 ) ))
			scroll_red=true
		fi

		if [[ $(( top_line + ( lines - 4 ) )) -gt "${buffer_meta[0]}" ]]
		then
			top_line=$(( ${buffer_meta[0]} - ( lines - 4 ) ))
		fi

		if [[ $top_line -le 1 ]]; then top_line=1; fi

		cur_val
		
		if $scroll_red; then main "$offset"; fi
	done
}

insert_newl() {
	buffer_text=("${buffer_text[@]:0:$((cursor_line-1))}" "" "${buffer_text[@]:$((cursor_line-1))}")
	buffer_meta[0]=$((${buffer_meta[0]}+1))
	redraw_all
}

insert_char() {
	local char="$1"
		buffer_text[$((cursor_line-1))]="${buffer_text[$((cursor_line-1))]:0:$cursor_col}$char${buffer_text[$((cursor_line-1))]:$cursor_col}"
	((cursor_col+=1))
}

delete_char(){
	if [[ $cursor_col -gt 0 ]];	
	then
		buffer_text[$((cursor_line-1))]="${buffer_text[$((cursor_line-1))]:0:$((cursor_col-1))}${buffer_text[$((cursor_line-1))]:$cursor_col}"
		((cursor_col-=1))
	fi
}

cur_up() {
	((cursor_line-=1))
}

cur_down() {
	((cursor_line+=1))
}

cur_left() {
	((cursor_col-=1))
	if [[ $cursor_col -lt 0 ]] && [[ $cursor_line -gt 1 ]];
	then
		((cursor_line-=1))
		cursor_col=${#buffer_text[$((cursor_line-1))]}
		draw_line "$offset" "$((cursor_line+1))"
	fi
}

cur_right() {
	((cursor_col+=1))
	if [[ $cursor_col -gt ${#buffer_text[$((cursor_line-1))]} ]] && [[ $cursor_line -lt ${buffer_meta[0]} ]];
	then
		((cursor_line+=1))
		cursor_col=0
		draw_line "$offset" "$((cursor_line-1))"
	fi
}

cur_val() {
	if [[ $cursor_line -le 1 ]]; then cursor_line=1; fi
	if [[ $cursor_line -gt ${buffer_meta[0]} ]];
	then
		cursor_line=${buffer_meta[0]}
	fi
	
	if [[ $cursor_col -lt 0 ]]; then cursor_col=0; fi
}

## Main

get_term
if [[ $lines -ge 24 ]] && [[ $columns -ge 80 ]];
then
	# Main
	# meta: final line, filename
	buffer_meta=("$(wc -l < $1)" "$1")

	readarray -t buffer_text < "${buffer_meta[1]}"

	setup_term
	#draw_logo
	get_tab_size
	input_loop
	restore_term
else
	printf '\nYour terminal must be at least 24x80, yours is %sx%s' "$lines" "$columns"
fi
