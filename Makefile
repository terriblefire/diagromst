.PHONY: DiagROM main.asm startup.o exceptions.o
VASM=vasmm68k_mot 

srcfile=DiagROM.asm

all: DiagROM
DiagROM: split date DiagROMST DiagROMSTE DiagROMFalcon DiagROMCart 
DiagROMST:
	$(VASM) -m68882 -opt-fconst -nowarn=62 -DST_ROM=1 -Fbin $(srcfile) -o $(@).rom -L $(@).lst
	dd conv=swab if=$(@).rom of=16bit_st.bin
	./split 16bit_st.bin 
DiagROMSTE:
	$(VASM) -m68882 -opt-fconst -nowarn=62 -DSTE_ROM=1 -Fbin $(srcfile) -o $(@).rom -L $(@).lst
	dd conv=swab if=$(@).rom of=16bit_ste.bin 
	./split 16bit_ste.bin 
DiagROMFalcon:
	$(VASM) -m68882 -opt-fconst -nowarn=62 -DFALCON_ROM=1 -Fbin $(srcfile) -o $(@).rom -L $(@).lst
	dd conv=swab if=$(@).rom of=16bit_falcon.bin 
	./split 16bit_falcon.bin 
DiagROMCart:
	$(VASM) -m68882 -opt-fconst -nowarn=62 -DST_CART=1 -Fbin $(srcfile) -o $(@)_toobig.tmp -L $(@).lst
	dd if=$(@)_toobig.tmp of=$(@).rom bs=1K count=128
	dd conv=swab if=$(@).rom of=16bit_cart.bin
	./split 16bit_cart.bin 
split: split.o
	$(CXX) -o split split.o
split.o: split.cpp
date:	
	date +"%d-%b-%y" > BuildDate.txt
runste: DiagROMSTE
	hatari --patch-tos false --machine ste --tos DiagROMSTE.rom --memsize 0 --rs232-in /tmp/vsp --rs232-out /tmp/vsp 
runfalcon: DiagROMFalcon
	hatari --patch-tos false --machine falcon --tos DiagROMFalcon.rom --memsize 0 --rs232-in /tmp/vsp --rs232-out /tmp/vsp 
runst: DiagROMST
	hatari --patch-tos false --machine st --tos DiagROMST.rom --memsize 0 --rs232-in /tmp/vsp --rs232-out /tmp/vsp 
runstmidi: DiagROMST
	hatari --patch-tos false --machine st --tos DiagROMST.rom --memsize 0 --midi-in /tmp/vsp --midi-out /tmp/vsp 
runcart: DiagROMCart
	hatari --patch-tos false --machine st --cartridge DiagROMCart.rom --tos tos.img --memsize 0 --rs232-in /tmp/vsp --rs232-out /tmp/vsp 
clean:
	rm -f DiagROM*.rom *.lst a.out *~ \#* *.o split 16bit* 32bit*
distclean: clean
	rm -f *~ *.txt
release: DiagROM
	cp 16bit_*.bin DiagROM*.rom ./bin/

