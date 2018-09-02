.PHONY: DiagROM
VASM=vasmm68k_mot 

all: DiagROM
#compare: DiagROM
#	cmp -l DiagROM.orig DiagROM.new | gawk '{printf "%08X %02X %02X\n", $$1, strtonum(0$$2), strtonum(0$$3)}'	
DiagROM: split date
	$(VASM) -m68882 -no-opt -Fbin $(@).asm -o $(@).rom -L $(@).lst
	dd conv=swab if=$(@).rom of=16bit.bin
	./split 16bit.bin 
split: split.o
	$(CXX) -o split split.o
split.o: split.cpp
date:	
	date +"%d-%b-%y" > BuildDate.txt
run:
	hatari --machine st --tos DiagROM.rom --memsize 0 --rs232-in /tmp/vsp --rs232-out /tmp/vsp 
mif:
	bin2mif -w 16 DiagROM.rom  > 16bit.mif
clean:
	rm -f DiagROM.rom *.lst a.out *~ \#* *.o split 16bit* 32bit*
distclean: clean
	rm -f *~ *.txt
