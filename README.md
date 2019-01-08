# SIDPlayer
SID Player for BBC B, Master 128 or ELK with BeebSID

## A SID player for the BBC B, Master and Electron
A build system to create SSDs containing SID files

## Overview

This includes:

_sidreloc_ a hacked version of [Linus Akesson's](https://www.linusakesson.net/software/sidreloc/index.php) which is used 
to relocate the SIDS to page 1A and move any zero page variable down into the "language" area. 

_ripsid_ which takes the SID binary out of the PSID wrapper and generates some metadata variables and adds in a jump 
table that replaces ST* SID instructions with a JSR that sets both the original SID register and a copy that is 
used in the player screens for the display. 

_menu file_ The files are bundled up with a simple metadata files used to generate a menu file containing the song's BBC filename and 
the title from the SID.

_players_ Assembler play routines and menu systems. If the main player routine (which is Mode 7 based) is run
on an Electron it chains on to the SIDPELK player which starts in Mode 6 for the menu then does some garish 
scrolly graphics in mode 5 to keep you amused while the song plays.

## Usage
Escape to return to the menu, < and > can be used to select sub songs where the are a available a song indicator will show in blue near the bottom of the screen with i.e. "< 2 >" where there are more than 2 tune or just "1" where there is just one!

## Building
The build system should work on any *nixy system. (I use Cygwin - let me know if there are any problems on other platforms)

Preequisites:
 - cc65 (for the assembler)
 - dfs-0.4 (see my github)
 

