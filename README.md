# haste.sh
## Haste's Another Shell Text Editor
haste is a text editor built in pure bash, designed to take full advantage of the shell text processing capabilites and modularity  
It isn't yet complete, or especially optimised, but it should be mostly functional for day-to-day use for those with low expectations  

## The story (not interesting)
This is technichally the fifth text editor I have written called haste. Versions 1 - 4 were lost on a few seperate occasions of partitioning gone wrong.  
This specific version started life as a nano clone called board (nano > planck (taken) > board (planck/plank) ). I decided to change it into haste v5 after realising it was a little bit of a waste of time to make a clone of nano that is inferior in every way.  


## Why?
You may be thinking that a text editor written in bash is a bad idea. bash is notoriously slow, and having to use VT100 specific escapes instead of a termcap / curses based enviroment makes it less portable (although admiteddly this isnt a huge issue,since its not the 1980's anymore)  
I think however, that the issues are far outweighed by the positives. The bash syntax for parameter expansions is (imo) a brillaint way to do command based editing  

## Features
 - Multiple buffers
 - Mouse addressing using xterm sequences
 - Fully supported bash parameter expansion for text editing
 - Pure bash, no external dependencies (even coreutils)

## Roadmap / future features
 - Syntax highlighting:  
	This is a little difficult in bash, as there is not great support for extended regexes that would be useful fo this sort of job
	However, this COULD be mitigated by the use of external tools. For speed concerns though, this is not currently an ideal solution.
 - Line wrapping:  
	I'll do it later. not hard, just tedious
 - Custom keybinds:  
	I'm honestly not super bothered about this. If you want custom keybinds, you can realistically just edit the script itself. It isn't like linecomp where custom keybinds can be a make or break feature for adoption, most text editors have set keybinds anyway.
 - Figure out why it doesnt like being resized  
	Might be terminal specific, dont know atm
 - Add readonly flag for help / extra buffers  
	Again might not bother
