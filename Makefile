
# makefile for SCRAPYARD nes game

CA65=ca65 # supply the location of the compiler

EMU=fceux # supply an emulator

OUTPUT=scrapyard

SOURCES=$(wildcard src/*asm)

main: $(SOURCES)
	$(CA65) src/scrapyard.asm -g -o objdir/scrapyard.o
	ld65 -o $(OUTPUT).nes -C rom.cfg objdir/scrapyard.o -m objdir/$(OUTPUT).map.txt -Ln objdir/$(OUTPUT).labels.txt --dbgfile objdir/$(OUTPUT).nes.dbg

open: main
	$(EMU) 


clean:
	rm -f objdir/*.txt objdir/*.o objdir/*.txt objdir/*.dbg

