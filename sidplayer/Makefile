

all:	sidpl.bbc sidpelk.bbc

.PHONY:		all clean

sidpl.bbc:	sidpl.o play_screen.o menu_screen.o mul.o sidpl.cfg
	  ld65 --mapfile sidpl.map -S 0x6000 -o sidpl.bbc -C sidpl.cfg  sidpl.o play_screen.o menu_screen.o mul.o
	  da65 --comments 4 -S 0x6000 -o sidpl.ls2 sidpl.bbc

sidpelk.bbc:	sidpelk.o mul.o sidpelk.cfg hexdigs.bin
	  	ld65 --mapfile sidpl.map -S 0x5800 -o sidpelk.bbc -C sidpelk.cfg  sidpelk.o mul.o
	  	da65 --comments 4 -S 0x5800 -o sidpelk.ls2 sidpelk.bbc

    
%.o : %.s
	  ca65 -l $<.lst $<

play_screen.s : sidframe_mo7,ffd mo72asm.pl
	  perl mo72asm.pl sidframe_mo7,ffd play_screen.s "play_screen"

menu_screen.s : sidmenu_mo7,ffd mo72asm.pl
	  perl mo72asm.pl sidmenu_mo7,ffd menu_screen.s "menu_screen"

clean:
		rm -rf *.o
		rm -rf *.bbc
		rm -rf play_screen.s
		rm -rf menu_screen.s
    
