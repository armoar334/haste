# haste.sh
## Haste's Another Shell Text Editor
haste is a text editor built in pure bash, designed to take full advantage of the shell text processing capabilites and modularity
It isn't yet complete, or especially optimised, but it should be mostly functional for day-to-day use for those with low expectations

## Why?
You may be thinking that a text editor written in bash is a bad idea. bash is notoriously slow, and having to use VT100 specific escapes instead of a termcap / curses based enviroment makes it less portable (although admiteddly this isnt a huge issue,since its not the 1980's anymore)
I think however, that the issues are far outweighed by the positives. The bash syntax for parameter expansions is (imo) a brillaint way to do command based editing

## Roadmap / future features
 - Syntax highlighting
	This is a little difficult in bash, as there is not great support for extended regexes that would be useful fo this sort of job
	However, this COULD be mitigated by the use of external tools. For speed concerns though, this is not currently an ideal solution
 - Line wrapping
	I'll do it later. not hard, just tedious
