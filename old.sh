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
	local log_lines=$(wc -l <<<"$logo")
	local log_columns=$(wc -m <<<"${logo%%$'\n'*}")
	local temp_c=$(( (columns / 2) - (log_columns / 2) ))
	go_to $(( (lines / 2) - (log_lines / 2 ) ))
	while IFS= read -r line; do
		printf '\r\e['$temp_c'C%s\n' "$line"
	done <<< "$logo"
}

draw_top() {
	local topx=$1
	local topy=$2
	local width=$(( $3 - $1 ))
	local bar="$4"

	go_to "$topy" "$topx"
	printf '\e[7m+%*s+\e[0m' "$((width-2))" | tr ' ' '-'
	go_to "$topy" "$((topx+1))"
	printf '\e[7m%s\e[0m' "$bar"
}

draw_bot() {
	go_to "$((lines-1))" 1
	printf '\e[7m%*s\e[0m' "$columns" | tr ' ' '-'
}

draw_box() {
	local topx=$1
	local topy=$2
	local width=$(( $3 - $1 ))
	local height=$(( $4 - $2 ))
	((width-=2))
	((height-=2))
	go_to "$topy" "$topx"
	printf '/%*s+\' "$width" | tr ' ' '-'
	for i in $(seq 1 $height );
	do
		go_to $((topy + i)) "$topx"
		printf '|%*s|' "$width"
	done

}

switch_buffer() {
	local index=$1
	read -r topx topy xperc yperc _ topl _ _ _ _ file _ <<<"${buffer_meta[$index]}"
}

do_perc() {
	(( topx=(topx * columns ) / 100 ))
	(( topy=(topy * (lines-1) ) / 100 ))
	if [[ "$topx" -eq 0 ]];
	then
		topx=1
	fi
	if [[ "$topy" -eq 0 ]];
	then
		topy=1
	fi

	(( xperc=(xperc * columns ) / 100 ))
	(( yperc=(yperc * (lines-1) ) / 100 ))
	((xperc+=2))
	((yperc+=1))

	draw_box "$topx" "$topy" "$xperc" "$yperc"
	draw_top "$topx" "$topy" "$xperc" "$file |"

	go_to "$((topy+1))" "$((topx))"
	# This is fucking ridiculous, but its funny so its staying
	<<< "${buffer_text[index]}" sed -n "$topl,$(( topl + (yperc-topy-2) ))p" |\
	while IFS= read -r line;
	do
		printf '\e[%sC%s\n' "$topx" "$line"
	done
}

## Magic (not graphics)

input_loop() {
	local running=true
	while $running;
	do
		read -rsn1 mode
		case "$mode" in
			$'\e') 
					read -rsn2 mode
					case "$mode" in
						'[A') ;; # Up
						'[B') ;; # Down
						'[C') ;; # Right
						'[D') ;; # Left
						'[5') read -rsn1 _ ;; # PgUp
						'[6') read -rsn1 _ ;; # PgDn
					esac ;;
			$'\cc') ;;
			$'\cq') running=false ;;
			$'\c?') ;; # Delete
			[[:print:]]) ;; # Any POSIX printable 
		esac
		printf '\e[?25l'
	done
}

get_term
if [[ $lines -ge 24 ]] && [[ $columns -ge 80 ]];
then
	setup_term
	# Main
	# meta: c1, l1, c2, l2, modified (bool), topline, length, cursorline, cursorcol, file location
	buffer_meta=(
	"1 1 100 100 true 1 $(wc -l /home/alfie/.bashrc) 1 1 /home/alfie/.bashrc"
	)

	buffer_text=()
	for number in $( seq 1 "${#buffer_meta[@]}" )
	do
		read -r _ _ _ _ _ _ _ file _ <<<"${buffer_meta[number-1]}"
		buffer_text[number-1]="$(< $file)"
	done
	for number in $( seq 1 "${#buffer_meta[@]}" )
	do
		switch_buffer "$((number-1))"
		do_perc
	done

	draw_bot
	#draw_logo

	input_loop

	restore_term
else
	printf '\nYour terminal must be at least 24x80, yours is %sx%s' "$lines" "$columns"
fi
