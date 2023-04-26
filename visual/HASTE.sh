#!/usr/bin/env bash

# _   _    _    ____ _____ _____         _____
#| | | |  / \  / ___|_   _| ____| __   _|___ /
#| |_| | / _ \ \___ \ | | |  _|   \ \ / / |_ \
#|  _  |/ ___ \ ___) || | | |___   \ V / ___) |
#|_| |_/_/   \_\____/ |_| |_____|   \_/ |____/
#
#Haste's another shell text editor
#Written in pure bash for the 3rd time
#Lost 1st to corruption and 2nd to me deleting my ssd
#R.I.P to Haste v1 and v2
#Most of this code is entirely undocumented, i dont know what it does or why its there, but if i try to figure out then itll probably break
#in other words, have fun :)
#

SETTINGS() {
#The top toolbar, can be any bash sequence, or just static text
#Can also be a changing value as it is redrawn with scrolling / input
#	TOPTOOL="Haste's another shell text editor"
	TOPTOOL='File:'$PWD\/$FILENAME
#	TOPTOOL=$(date '+%b %d (%a) %I:%M%p')
#	TOPTOOL="yo mama"


#Characters used to draw lines, might be expanded but im not sure so be careful
#Horizontal
	HORCHAR='─'
#Vertical
	VERCHAR='│'
#T-piece that faces down
	TDOWN='┬'
#T-piece that faces up
	TUP='┴'
#Cross
	CROSS='┼'
}





#  ____ ___  ____  _____
# / ___/ _ \|  _ \| ____|
#| |  | | | | | | |  _|
#| |__| |_| | |_| | |___
# \____\___/|____/|_____|
#


#Trap resizing of terminal
trap 'FULL_DRAW' WINCH

#Trap exiting
trap 'CLEAN_EXIT' INT

#
#SETUP
#


#Get terminal size
GET_TERM() {
	read -r LINES COLUMNS < <(stty size)
}

#Set scroll areas
SET_SCROLL() {
	printf '\e[1:'$((LINES - 1))'r'
}

#Switch to secondary buffer / save terminal contents
SAVE_TERM() {
	printf '\e[?1049h'
}

#Switch to first buffer / restore terminal contents
RESTORE_TERM() {
	printf '\e[?1049l'
}

#Set variables
ENVIROMENT_VARS() {
	FILENAME="file.txt"
}

#
LINE_PARSER() {
	while IFS= read -r line || [ -n "$line" ]; do
		FILE_LENGTH=$((lines + 1))
	done < "$FILENAME"
}



#
#LOOK
#i.e nothing here does anything its mostly UI
#


TOP_BAR() {
	COUNT=1
	printf '\e[H'
	while [[ $COUNT -le $COLUMNS ]];
	do
		printf $HORCHAR
		COUNT=$((COUNT + 1))
	done
}

BOT_BAR() {
	COUNT=0
	printf '\e['$((LINES - 1))'H'
	while [[ $COUNT -le $((COLUMNS - 1)) ]];
	do
		printf $HORCHAR
		COUNT=$((COUNT + 1))
	done
}

SIDE_BAR() {
	COUNT=0
	if [[ $TOPLINE -le 1 ]];
	then
		TOPLINE=1
	fi
	printf '\e[2H'
	while [[ $COUNT -le $((LINES - 4)) ]];
	do
		TEMPLINE=$((COUNT + TOPLINE))
		printf "  % 5d $VERCHAR$TEXT" $TEMPLINE
		if [[ $COUNT -le $FILE_LENGTH ]];
		then
			sed -n $COUNTp $FILENAME
		fi
		printf '\e[100D'
		printf '\e[B'
#		sleep 0.2
		COUNT=$((COUNT + 1))
	done
	BOTTOMLINE=$((COUNT + TOPLINE - 1))
#	BOTTOMLINE=$(( $(($LINES - 2)) + TOPLINE - 1))
	printf '\e['$((LINES - 1))';9H'
	printf $TUP
}

TOOLTIP() {
	printf '\e[0;9H'
	printf "|$TOPTOOL|"
}

COMMANDS() {
	printf '\e['$LINES'H'
	printf '|Keys   | \e[7m^C\e[0m Quit'
}

STATBAR() {
	printf '\e[0;'$((${#TOPTOOL} + 1 + 9))'H'
	printf '|L:'$TRUELIN'|C:'$TRUECOL'|TOP:'$TOPLINE'|BOT:'$BOTTOMLINE'|'
}

ERRORBAR() {
	echo "it brokey"	

}

FULL_DRAW() {
	clear	
	GET_TERM
	SET_SCROLL
	SETTINGS
	TOP_BAR
	BOT_BAR
	SIDE_BAR
	TOOLTIP
	COMMANDS
}

PARTIAL_DRAW() {
	SETTINGS
	TOP_BAR
	SIDE_BAR
	TOOLTIP
	COMMANDS

}


#
#INPUT
#


MAIN_INPUT() {
	escape_char=$(printf "\u1b")
	read -rsn1 mode # get 1 character
	if [[ $mode == $escape_char ]]; then
		read -rsn2 mode # read 2 more chars
	fi
	case $mode in
#Lower
		'a') ADD_TEXT a ;;
		'b') ADD_TEXT b ;;	
		'c') ADD_TEXT c ;;
		'd') ADD_TEXT d ;;
		'e') ADD_TEXT e ;;
		'f') ADD_TEXT f ;;
		'g') ADD_TEXT g ;;
		'h') ADD_TEXT h ;;
		'i') ADD_TEXT i ;;
		'j') ADD_TEXT j ;;
		'k') ADD_TEXT k ;;
		'l') ADD_TEXT l ;;
		'm') ADD_TEXT m ;;
		'n') ADD_TEXT n ;;
		'o') ADD_TEXT o ;;
		'p') ADD_TEXT p ;;
		'q') ADD_TEXT q ;;
		'r') ADD_TEXT r ;;
		's') ADD_TEXT s ;;
		't') ADD_TEXT t ;;
		'u') ADD_TEXT u ;;
		'v') ADD_TEXT v ;;
		'w') ADD_TEXT w ;;
		'x') ADD_TEXT x ;;
		'y') ADD_TEXT y ;;
		'z') ADD_TEXT z ;;
#special
		'[3') REMOVE_TEXT ;;
		'?') REMOVE_TEXT ;;
		'¬') ADD_TEXT " " ;;
		'[6' ) for ((n=0; n < (LINES - 3); n++)); do CURSOR_DOWN; done ;;
		'[5' ) for ((n=0; n < (LINES - 3); n++)); do CURSOR_UP; done ;;

#Cursor / other
		'[A') CURSOR_UP ;;
		'[B') CURSOR_DOWN ;;
		'[D') CURSOR_LEFT ;;
		'[C') CURSOR_RIGHT ;;
		*) >&2  ;;
	esac
	VAR_SAN
	STATBAR
	printf '\e['$(( $((TRUELIN - TOPLINE)) + 2))';'$((TRUECOL + 9))'H'	
}

VAR_SAN() {
	if [[ $TOPLINE -le 1 ]];
	then
		TOPLINE=1
	fi
	if [[ $TRUELIN -le 1 ]];
	then
		TRUELIN=1
	fi

}	


CURSOR_UP() {
	if [[ $TRUELIN -le 1 ]];
	then
		TRUELIN=1
	fi
	if [[ $TRUELIN -eq $TOPLINE ]];
	then
		TRUELIN=$((TRUELIN - 1))
		SCROLL_UP
	elif [[ $TRUELIN -ge 1 ]];
	then
		TRUELIN=$((TRUELIN - 1))
	fi
}

CURSOR_DOWN() {
	if [[ $TRUELIN -ge $((BOTTOMLINE)) ]];
	then
		TRUELIN=$((TRUELIN + 1))
		SCROLL_DOWN
	elif [[ $TRUELIN -le $((BOTTOMLINE - 1)) ]];
	then
		TRUELIN=$((TRUELIN + 1))
	fi
}

CURSOR_LEFT() {
	if [[ TRUECOL -le 1 ]];
	then
		TRUECOL=1
	elif [[ TRUECOL -ge 1 ]];
	then
		TRUECOL=$((TRUECOL - 1))
	fi
}

CURSOR_RIGHT() {
	if [[ TRUECOL -ge $((COLUMNS - 9)) ]];
	then
		TRUECOL=$((TRUECOL))
	elif [[ TRUECOL -le $COLUMNS ]];
	then
		TRUECOL=$((TRUECOL + 1))
	fi
}

SCROLL_UP() {
	TOPLINE=$((TOPLINE - 1))
	PARTIAL_DRAW
}

SCROLL_DOWN() {
	TOPLINE=$((TOPLINE + 1))
	PARTIAL_DRAW
}

ADD_TEXT() {
	LETTER=$1
	printf $LETTER
	CURSOR_RIGHT
	TEXT=${TEXT:0:$((TRUECOL-2))}$LETTER${TEXT:$TRUECOL}

}

REMOVE_TEXT() {
	printf ' '
	TEXT=${TEXT:0:$((TRUECOL-1))} ${TEXT:$((TRUECOL))}
	CURSOR_LEFT
}

CLEAN_EXIT() {
	RESTORE_TERM
	exit
}










SAVE_TERM
GET_TERM
#ENVIROMENT_VARS
FILENAME=$1

#SET_SCROLL

#TOP_BAR
#BOT_BAR
#SIDE_BAR
#TOOLTIP
#COMMANDS
exec 2> log.txt
TOPLINE=1
FULL_DRAW
#TOPLINE=1
printf '\e[2;10H'
TRUECOL=1
TRUELIN=1
EDITING=True
TEXT=()
while [[ EDITING -eq True ]];
do
	MAIN_INPUT
done

sleep 3
RESTORE_TERM
