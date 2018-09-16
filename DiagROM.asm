;; w00t a new operating system.
;; Based on DiagROM

; A6 is ONLY to be used as a memorypointer to variables etc. so never SET a6 in the code.

	include "settings.i"
	include "resources.i"
	include "macros.i"
	include "memory.i"
	
	org	rom_base
START:	
	; Lets start the code..  with a jump
TheStart:
	bra.s	_main
	dc.w	$0206		; pretend we are TOS 2.06 to emulators.

	dc.l    _main       ; reseth, pointer to reset handler 
	dc.l	rom_base
	
	dc.l	POSTAddressError			; if something is wrong rom starts at $0
	dc.l	POSTIllegalError			; so this will actually be pointers to
	dc.l	POSTDivByZero				; traps.
	dc.l	POSTChkInst
	dc.l	POSTTrapV
	dc.l	POSTPrivViol
	dc.l	POSTTrace
	dc.l	POSTUnimplInst

_main:	jmp	Begin

strstart:
	DC.B	"IHOL : :6U6U,A,B1U1U5767U,U,8181 1 0    "	; This string will make a readable text on each 32 bit
	DC.B	"HILO: : U6U6A,B,U1U17576,U,U18181 0     "	; rom what socket to use. (SOME programming software does byteshift so both orders)
	dc.b	"$VER: DiagROM Atari ST by Stephen Leary. "

	dc.b	"www.diagrom.com "
	incbin	"BuildDate.txt"
	dc.b	"- "
	VERSION
strstop:

	blk.b	166-(strstop-strstart),0		; Crapdata that needs to be here

	EVEN

Begin:	

	move.w  #$2700,sr		 ; Disable interrupts
	move.w	#$F00,color0	 ; red screen
	move.b  #$0A,(memconf)	 ; set hw to 2 banks by 2 mb (reg 0xffff8001 - memorycontroller) 

	lea		$400,SP		 	 ; Set the stack. BUT!!! do not use it yet. we need to check chipmem first!
	InitVideo $10000

	move.w	#$ff0,color0	 ; yellow screen

	;; set up white
	SETALLCOLORS $fff
	
	; shut down the MFP completely
	RESETMFP

	; setup the exception handlers

	move.l	#POSTBusError,$8
	move.l	#POSTAddressError,$c
	move.l	#POSTIllegalError,$10
	move.l	#POSTDivByZero,$14
	move.l	#POSTChkInst,$18
	move.l	#POSTTrapV,$1c
	move.l	#POSTPrivViol,$20
	move.l	#POSTTrace,$24
	move.l	#POSTUnimplInst,$28
	move.l	#POSTUnimplInst,$2c

	; chips have been asked to be in a consistent state.

	InitMFP

	KPRINT Ansi
	KPRINT InitSerial

	PAROUT #$ff		; Send #$ff to Paralellport.
	; And explaining simliar text to serialport.
	KPRINTSLN '- Parallel Code $ff - Start of ROM, CPU Seems somewhat alive'

	KPRINTS ' - Resetting all hardware (RESET instruction):'
	reset
	KPRINTSLN ' Done.'

	;; setup the hardware again

	InitMFP

	KPRINTS   ' - Reinitialising Video ($10000): '
	InitVideo $10000
	KPRINTSLN 'Done.'

	;; set up white
	SETALLCOLORS $fff

	;; Keyboard reset 
	KPRINTS ' - Sending reset to keyboard controller (IKBD Reset): '
	
IKBDReset:	

	; setup some timer speeds
    move.b    #$03,(ACIA_MIDI_BASE+ACIA_CTRL).w   ; init the midi acia via master reset 
    move.b    #$95,(ACIA_MIDI_BASE+ACIA_CTRL).w   ; divide by 16 
	
	move.b    #$03,(ACIA_IKBD_BASE+ACIA_CTRL).w   ; init the acia via master Reset 
	move.b    #$96,(ACIA_IKBD_BASE+ACIA_CTRL).w   ; divide by 64 

	;; reset the keyboard controller.
	IKBDWrite #$80
	cmp.w	#0,d0
	bne		IKBDResetFail

	IKBDWrite #$01
	cmp.w	#0,d0
	bne		IKBDResetFail

	move.b	#$12,d1
	IKBDWrite #$12

	KPRINTSLN 'Done.' 
	bra	IKBDResetDone

IKBDResetFail:
	KPRINTSLN 'Failed.'

IKBDResetDone:

	;; Keyboard has been reset here. 

	move.w	#$200,color0

;	Now lets check for some memory, the only thing we KNOW exists on all machines is Chipmem.
;	so this will only really rely on Chipmem.  but does it work?  anyway. NO stack is allowed at this
;	point, meaning NO Stack, no subroutines only registers A0-A6 and D0-D7 and no memory.

	PAROUT	#$fe
	KPRINTSLN '- Parallel Code $fe - Test UDS/LDS line'

ldsudsffff:
	KPRINTS ' - Test of writing word $FFFF to $400 '
	TestMemWord $ffff, $400

ldsuds00ff:
	KPRINTS ' - Test of writing word $00FF to $400 '
	TestMemWord $00ff, $400

ldsudsff00:	
	KPRINTS ' - Test of writing word $FF00 to $400 '
	TestMemWord $ff00, $400

ldsuds0000:	
	KPRINTS ' - Test of writing word $0000 to $400 '
	TestMemWord $0000, $400

udsldseven:
	KPRINTS ' - Test of writing byte (even) $ff to $400 '

	move.w	#$0,d0
	move.w	d0,$400
	move.b	#$ff,d1
	move.b	d1,$400
	move.w	#$ff00,d1

	cmp.b	d0,d1
	bne		.fail
	KPRINTSLN 'OK.'
	bra		.done	
.fail:
	KPRINTSLN 'FAILED.'
.done:

udsldsodd:
	KPRINTS ' - Test of writing byte (odd) $ff to $401 '

	move.w	#$0,d0
	move.w	d0,$400
	move.b	#$ff,d1
	move.b	d1,$401
	move.w	#$00ff,d1
	move.w	$400,d0

	cmp.b	d0,d1
	bne		.fail
	KPRINTSLN 'OK.'
	bra		.done	
.fail:
	KPRINTSLN 'FAILED.'
.done:

	PAROUT	#$fd	
	KPRINTSLN '- Parallel Code $fd - Start of chipmemdetection'

	KPRINTS '  - Performing MMU Configuration: '

	MMUConfigure 

	KPRINTS '$'
	KPRINTHEX8 d6
	KPRINTSLN ' Done.'

	POSTDetectChipmem

	; At EXIT registers that are interesting:
	; D0 = Number of usable 32Kb blocks
	; D3 = First usable address
	; A6 = Last usable address
	
    sub.l	#EndData-Variables,a6	; Subtract total chipmemsize, putting workspace at end of memory
	sub.l	#2048,a6		; Subtract 2Kb more, "just to be sure"
						; A6 from now on points to where diagroms workspace begins. do NOT change A6
						; A6 is from now on STATIC

	PAROUT #$fd
	KPRINTSLN	"- Parallel Code $fb - Memorydetection done"

	;	memdetection done
	
	;	d0				; total chipmem *32
	;	d1				; total fastmem *64
	;	a0				; Start of Fastmemblock
	;	a1				; end of fastmemblock
	;	a4				; Startupbits (pressed mousebuttons etc)
	;	a7				; Start of chipmem

	

;----------- Chipmemtest done

    PAROUT	#$fc			; Send $fd to parallelport
    ; And explaining simliar text to serialport.
   
    KPRINTSLN "- Parallel Code $fc - Start of motherboard fastmemdetection"	  
	move.l	d3,a7			; Store start of chipmem

	clr.l	d1
	clr.l	d2
	move.l	#0,a0

	move.l	#"24BT",$4000700	; Write "TEST" to highmem
	cmp.l	#"24BT",$700		; IF memory is readable at $700 instead. we are using a cpu with 24 bit adress. no memory to detect in next routines
	beq	.a1200done

	move.l	#$4000000,a1		; Detect motherboardmem on A3000/4000
	move.l	#$7ffffff,a2
	lea	.a3k4kdone,a3
	bra	DetectMBFastmem
.a3k4kdone:
	move.l	#$70000000,a1		; Detect memory on A1200/4000 accelerators
	move.l	#$7affffff,a2
	lea	.a1200done,a3
	bra	DetectMBFastmem
.a1200done:
	move.l	#$200000,a1		; Detect memory on 24 bit range
	move.l	#$9fffff,a2
	lea	.24bitdone,a3
	bra	DetectMBFastmem
.24bitdone:
	move.l	#$c00000,a1		; Detect memory on 24 bit range
	move.l	#$c80000,a2
	lea	.fakefastdone,a3
	bra	DetectMBFastmem
.fakefastdone:
	move.l	d1,d6			; Store size in d6 as Dumpserial uses d1
	move.l	a0,a5			; Store detected mem to a5
	PAROUT	#$fb			; Send $fd to parallelport
	KPRINTSLN "- Parallel Code $fb - Memorydetection done"
.jmp16:
	move.l	d6,d1
	move.l	a5,a0			; Restore important data from fastmemdetection


					; ok we ACTUALLY did have memory here.. so this was the last time this routine was used.
	cmp.l	#(EndData-Variables)/32768+1,d0
	bgt	.enoughchip		; ok we had enough chipmem
					; so we are not happy with the amount of found chipmem

	cmp.l	#(EndData-Variables)/16384+1,d1		; but was there enough FASTMEM??
	bgt	.enoughfast		; if so, jump there  (should be enoughfast..)

					; OK we are is trouble.. not enough memory
	cmp.l	#2,d0			; do we have extremly little chipmem
	ble	.nochip
	
					; ok we did not have enough chipmem, or fastmem, but SOME chipmem
 	PAROUT	#$81		; Set code to $81 to paralellport, NOT ENOUGH chipmem avaible
	KPRINTSLN "- Parallel Code $fd - Not enough Chipmem detected"
.jmp14:
	move.l	#$0080,d6		; set D6 to darker green
	bra	ERRORHALT	
.nochip:				; we had NO chipmem
 	PAROUT	#$80		; Set code to $80 to paralellport, NO chipmem avaible
	KPRINTSLN "- Parallel Code $80 - NO Chipmem detected"
.jmp15:
	move.l	#$00f0,d6		; set D0 to darker green
	bra	ERRORHALT	

.enoughfast:

	move.l	a5,a6			; We had enough fastmem, so lets set fastmem adress as base memory.
	move.l	#1,a4			; Set do NODRAW mode.
	move.l	d6,d1
	move.l	a5,a0			; Restore important data from fastmemdetection
	bra	code

	
.enoughchip:
					; OK we had enough chipmem avaible.
	move.l	a4,d7

	btst	#0,d7			; Check if LMB was pressed during boot
	bne	.LMB

	cmp.l	#$20000,a6		; check if a6 is in chipmem
	ble	.wearechip		; if we are do not set to nodraw mode
	move.l	#1,d7			; Set d7 to non 0 mode to force "nodraw" mode.
.wearechip:
	bra	startcode		; Start ROM for real, now with memory.
	
.LMB:					; LMB Pressed so we force chipmem if avaible, and if not just turn off screenstuff etc.
	move.l	#1,d7			; OK we are in a nodraw mode..
	
	cmp.l	#0,a5			; Was there any useful fastmem
	beq	.nofast

	move.l	a5,a6			; OK we had fastmem, set it as baseadress
.nofast:				; we didnt have any fastmem, lets use chipmem but skip screenstuff.
startcode:
	move.l	d1,d6			; Store size in d6 as Dumpserial uses d1
	move.l	a0,a5			; Store detected mem to a1

 	PAROUT #$fb		; Set code to $fb to paralellport, NO chipmem avaible
	KPRINTSLN "- Parallel Code $fb - Memorydetection done"

.jmp:


	move.l	d6,d1
	move.l	a5,a0			; Restore important data from fastmemdetection
	bra	code

	
ERRORHALT:				; This is a critical Error. stop everything. we are fucked.
	move.l	d6,d4			; as d4 isnt used in motherboardcheck, store color

ERRORHALT2:

	KPRINTSLN "- NO MEMORY FOUND - HALTING SYSTEM"

.loop:
	TOGGLEPWRLED		; Change value of Powerled.
	bne	.not
	move.w	d6,color0		; Set Screencolor to d6 (usual chipmemproblem color)
	bra	.yes
.not:
	move.w	#$030,color0		; just every 2:nd turn, show a DARK green color instead. making the screen flash some.
.yes:
	move.l	#$ffff,d7		; Do a nonsense loop
.loopa:
	move.b	slowcia,d5		; Actually a nonsense read. but CIA space is slow to read from.
	move.b	slowcia_alt,d5		; Actually a nonsense read. but CIA space is slow to read from.
	dbf	d7,.loopa
	bra.w	.loop			; Loop forever

code:

	move.l	a7,d3			; Copy start of chipmem (temporary stored in a7) do d3

	move.l	a6,a7			; ok.  we have found memory. so put stack there. BUT first put a6 to a7 (SP)
	move.l	#Endstack-Variables,d6	; set d7 to the stacksize	
	add.l	d6,a7			; and add stacksize so we have a stack
	move.l	a7,a6			
	add.l	#4,a6			; make a6 first usable address AFTER stack. for variables.

	asl.l	#4,d1			; Multiply  d1 with 16 to get correct number of kilobytes of fastmem.;

	clr.l	d2

	move.l	#RTEcode,$34
	move.l	#RTEcode,$64
	move.l	#RTEcode,$68
	move.l	#RTEcode,$6c
	move.l	#RTEcode,$70
	move.l	#RTEcode,$74
	move.l	#RTEcode,$78
	move.l	#RTEcode,$7c
	
	move.l	#BusError,$8		; This time to a routine that can present more data.
	move.l	#AddressError,$c
	move.l	#IllegalError,$10
	move.l	#DivByZero,$14
	move.l	#ChkInst,$18
	move.l	#TrapV,$1c
	move.l	#PrivViol,$20
	move.l	#Trace,$24
	move.l	#UnimplInst,$28
	move.l	#UnimplInst,$2c
	move.l	#Trap,$80
	move.l	#Trap,$84
	move.l	#Trap,$88
	move.l	#Trap,$8c
	move.l	#Trap,$90
	move.l	#Trap,$94
	move.l	#Trap,$98
	move.l	#Trap,$9c
	move.l	#Trap,$a0
	move.l	#Trap,$a4
	move.l	#Trap,$a8
	move.l	#Trap,$ac
	move.l	#Trap,$b0
	move.l	#Trap,$b4
	move.l	#Trap,$b8
	move.l	#Trap,$bc
	TOGGLEPWRLED
	
; Normal code

;	Put initstuff here that consumes time, so user have time to read text on console
					; Before we actually do start, lets clear all used memory
	
	move.l	a6,a0
	move.l	a6,d2
	addi.l	#EndData-V,d2
.loop:
	move.b	#0,(a0)+
	cmp.l	d2,a0
	blo	.loop

	move.l	a4,d7

	btst	#0,d7			; is d7 set? then we should not draw anything onscreen
	beq	.notset
	move.b	#0,NoDraw-V(a6)

.notset:
	
	move.b	#0,NoSerial-V(a6)
	btst	#1,d7			; Check if noserial is to be set
	beq	.notset2

	move.b	#0,NoSerial-V(a6)	; set it
.notset2:
	move.l	d1,TotalFast-V(a6)	; Store total fastmem detected
	move.l	d1,BootMBFastmem-V(a6)
	asl.l	#5,d0			; Multiply d0 with 32 as it contains number of blocks of 32K
	move.l	d3,ChipStart-V(a6)	; Write where detected chipmem starts
	move.l	d0,TotalChip-V(a6)	; Write totalchipvalue so we know how much chipmem is detected


	move.l	a6,d0			; Subtract startaddress with lowest value of detected ram
	sub.l	#V-Variables,d0

	move.l	d0,ChipUnreservedAddr-V(a6)
	sub.l	d3,d0			; also subtract stacksize, now we got all usable NONUSED chipmem
	move.l	d0,ChipUnreserved-V(a6)	; Store amount of NONRESERVED chipmem

	bsr	GetHWReg		; Store HW Registers

	move.l	ChipStart-V(a6),d1	; Get startaddress of chipmem
	move.l	TotalChip-V(a6),d0	; Get total of chipmemblocks detected
	mulu	#1024,d0
	sub.l	#$400,d0		; Subtract first 1Kb
	add.l	d1,d0			; add Startaddess of chipmem, so d0 now contains last memaddress

	move.l	d0,ChipEnd-V(a6)	; Write lastchipmemaddress into EndChip

	cmp.b	#1,NoSerial-V(a6)	; Check if noserial is set
	beq	.noser


	move.w	#2,SerialSpeed-V(a6) 
	bsr	Init_Serial	
	
	bra	.ser
.noser:
	move.w	#0,SerialSpeed-V(a6)	; Set Serialspeed to 0
.ser:

	lea	DetectRasterTxt,a0
	bsr	SendSerial

	move.l	 #VBLHandler,$70
	move.l	 #HBLHandler,$68

	move.w	#1000,d2
	move.w   #$2000,sr
	move.w	#0,HLINE-V(a6)
.wait:
	move.b	slowcia,d0
	
	sub.w	#1,d2
	cmp.w	#0,d2
	beq	.noraster
	
	cmp.w	#10,HLINE-V(a6)
	ble.s	.wait

	move.w   #$2700,sr
				; if raster was the same, We assume we have no working raster
	move.b	#1,RASTER-V(a6)		; it was different so we assume we have working raster.
	lea	DETECTED,a0
	bsr	SendSerial
	beq	.rastercheckdone

.noraster:
	move.w   #$2700,sr
	move.b	#0,RASTER-V(a6)
	lea	FAILED,a0
	bsr	SendSerial
.rastercheckdone:

	lea	NewLineTxt,a0
	bsr	SendSerial

	move.l	#AtariKey,keymap-V(a6)	; Set english keymap as default

	lea	DetChipTxt,a0
	bsr	SendSerial


	move.l	TotalChip-V(a6),d0
	bsr	bindec
	bsr	SendSerial
	lea	KB,a0
	bsr	SendSerial		; Put out detected chipmem on serialport..
	lea	NewLineTxt,a0
	bsr	SendSerial

	lea	DetMBFastTxt,a0
	bsr	SendSerial
	
	nop
	move.l	BootMBFastmem-V(a6),d0
	bsr	bindec
	bsr	SendSerial
	lea	KB,a0
	bsr	SendSerial
	lea	NewLineTxt,a0
	bsr	SendSerial

	lea	BaseAdrTxt,a0
	bsr	SendSerial
	move.l	a6,d0

	sub.l	#Endstack-Variables+4,d0

	bsr	binhex
	bsr	SendSerial
	lea	NewLineTxt,a0
	bsr	SendSerial


 	PAROUT	#$f9		; Set code to $81 to paralellport, NOT ENOUGH chipmem avaible
	KPRINTSLN "- Parallel Code $f9 - Detected memory in use, we now have a stack etc"

	move.l	#"DATA",Endstack-Variables(a6)	; Write "DATA" to first usable longword after stack

	move.l	#Endstack-Variables,StackSize-V(a6)		; write stacksize to varible for stacksize.
	move.l	a6,StartAddress-V(a6)
	
	move.l	a6,a5
	add.l	#Bpl1str-V,a5		; we do this way as this are in the end and big segments above 64k...
	move.l	#"BPL1",(a5)+		; Put the BPL1 string, just to be able to identify BPL1
	move.l	a5,Bpl1Ptr-V(a6)	; and store the pointer to bitplane

	move.l	a6,a5
	add.l	#Bpl2str-V,a5
	move.l	#"BPL2",(a5)+
	move.l	a5,Bpl2Ptr-V(a6)

	move.l	a6,a5
	add.l	#Bpl3str-V,a5
	move.l	#"BPL3",(a5)+
	move.l	a5,Bpl3Ptr-V(a6)
	clr.l	BplEnd-V(a6)		; make it 0, so we have a bitplanelist

	move.l	a6,a5
	add.l	#EndData-V,a5
	move.l	#"END!",(a5)

	bsr	CopyToChip

	bsr	InitStuff

					
; Initialize the screen.

	cmp.b	#0,NoDraw-V(a6)
	bne	.NoChip

	lea	InitDONEtxt,a0
	bsr	SendSerial

 	PAROUT	#$f8			; Set code to $81 to paralellport, NOT ENOUGH chipmem avaible
	KPRINTSLN "- Parallel Code $f8 - Starting up screen, text echoed to serialport"

	bsr	ClearScreenNoSerial

	lea	InitTxt,a0
	move.l	#7,d1
	bsr	Print
	bra	.Chip

.NoChip:
	lea	NoDrawTxt,a0
	bsr	SendSerial
.Chip:

	lea	InitSerial2,a0
	move.l	#7,d1
	bsr	Print

	cmp.b	#1,NoDraw-V(a6)			; Check if we are in NoDraw Mode. if so. do not disable serialport
	beq	.nodraw

	cmp.b	#1,NoSerial-V(a6)
	beq	.serialon			; IF Noserial was set, skip this part


	move.l	#1200,d7			; read data for a while.. Giving user a possability of try to press a key on serialport
	clr.l	d6
.waitloop:
	move.b	d7,color1			; Just flash some colors. so local user can see that something is happening
	bsr	GetInput
	cmp.b	#1,RMB-V(a6)			; RMB pressed? then turn serial on
	beq	.serialon
	btst	#2,d0
	bne	.serialon			; if any key was pressed turn serial on
	btst	#3,d0
	bne	.serialon
	add.l	#1,d6
	cmp	#16,d6
	bne	.nodot
	lea	DotTxt,a0
	move.l	#7,d1
	bsr	Print
	clr.l	d6
.nodot:
	dbf	d7,.waitloop
	bra	.serialon
	lea	EndSerial,a0			; Send text about "no key pressed"
	move.l	#7,d1
	bsr	SendSerial
	move.w	#0,SerialSpeed-V(a6)
	bra	.serialon

.nodraw:
	TOGGLEPWRLED
	move.w	#2,SerialSpeed-V(a6)
	lea	NoDrawTxt,a0
	bsr	SendSerial
	
.serialon:

; Clears screen and lets go on

;	clr.w	SerialSpeed-V(a6)	; Disable Serialport

	clr.l	d7

	bsr	DefaultVars
	bsr InitStuff

	move.l	#Menus,Menu-V(a6)
	bra	MainMenu			; Print the mainmenu



MainLoop:

	move.l	#0,a0
	bsr	PrintMenu			; Print or update the menu

	bsr	GetInput			; Scan keyboard, mouse, buttons, serialport etc..


	clr.l	d0
	move.l	#27,d1
	bsr	SetPos
	clr.l	d0

.no:
	bsr	HandleMenu			; ok, LMB pressed, do menuhandling

.notpressed:
	clr.l	d0
	move.l	InputRegister-V(a6),d0
	btst	#0,d0
		
	bra	MainLoop
	
Exit:
	
	rts

InitStuff:
	move.l	a6,a1
	add.l	#Bpl1Ptr-V,a1
	move.l	a6,a0
	add.l	#MenuCopper-V,a0
	add.l	#MenuBplPnt-RomMenuCopper,a0
	bsr	FixBitplane
	rts

ClearScreen:
	PUSH

	cmp.b	#0,NoDraw-V(a6)
	bne	.no
	move.l	Bpl1Ptr-V(a6),a0		; load A0 with address of BPL1
	move.l	#160*200,d0

	cmp.l	#0,a0
	beq.s	.no	
	
.loop:
	clr.l	(a0)+
	dbf	d0,.loop
.no:
	lea	AnsiNull,a0
	bsr	SendSerial

	move.l	#12,d0
	bsr	rs232_out
	lea	AnsiNull,a0
	bsr	SendSerial

	clr.l	d0
	clr.l	d1
	bsr	SetPos
	POP
	rts

ClearScreenNoSerial:				; Clear screen but does not dump to serialport.
	cmp.b	#0,NoDraw-V(a6)
	bne	.no
	move.l	Bpl1Ptr-V(a6),a0		; load A0 with address of BPL1

	move.l	#160*200,d0
.loop:
	clr.l	(a0)+
	dbf	d0,.loop
.no:
	clr.l	d0
	clr.l	d1
	bsr	SetPosNoSerial
	rts



GetMouse:
	PUSH
	clr.l	d0				; Clear d0..
	move.b	#0,BUTTON-V(a6)			; Clear the generic "Button" variable
	move.b	#0,LMB-V(a6)			; I use move as clr actually does a read first
	move.b	#0,P1LMB-V(a6)
	move.b	#0,P2LMB-V(a6)
	move.b	#0,RMB-V(a6)
	move.b	#0,P1RMB-V(a6)
	move.b	#0,P2RMB-V(a6)
	move.b	#0,MBUTTON-V(a6)		; Clear the generic "Mbutton" variable
	clr.l	d1
	bsr	GetMouseData
	move.l	d0,InputRegister-V(a6)
	POP
	move.l	InputRegister-V(a6),d0
	rts



GetInput:
						; Check inputsignals and return actions.
						; in: none
						; out: d0 - messageflags.
						;	bits:
						;		0 = Mouse moved
						;		1 = Mouse button
						;		2 = Keyboard action happened
						;		3 = Serial action happened

	PUSH

	clr.l	d0				; Clear d0..
	move.w	#0,CurAddX-V(a6)
	move.w	#0,CurSubX-V(a6)
	move.w	#0,CurAddY-V(a6)
	move.w	#0,CurSubY-V(a6)
	move.b	#0,MOUSE-V(a6)
	move.b	#0,BUTTON-V(a6)			; Clear the generic "Button" variable
	move.b	#0,LMB-V(a6)			; I use move as clr actually does a read first
	move.b	#0,P1LMB-V(a6)
	move.b	#0,P2LMB-V(a6)
	move.b	#0,RMB-V(a6)
	move.b	#0,P1RMB-V(a6)
	move.b	#0,P2RMB-V(a6)
	move.b	#0,key-V(a6)
	move.b	#0,Serial-V(a6)
	move.b	#0,GetCharData-V(a6)

	clr.l	d1

	clr.l	d0

	bsr	GetMouseData
;	clr.l	d0
;	cmp.b	#1,MOUSE-V(a6)
;	bne	.nomouse
;	bset	#0,d0				; Set that we had mousemovement

;.nomouse:


	move.l	d0,d1
	bsr	GetCharSerial
	cmp.b	#0,d0
	beq	.noserial
	move.b	d0,GetCharData-V(a6)
	move.b	#1,BUTTON-V(a6)
	move.l	d1,d0
	bset	#3,d1
	bra	.getkey

.noserial:

	move.l	d1,d0


.getkey:
	move.l	d0,d1
	bsr	GetCharKey
	cmp	#0,d0
	beq	.nokey

	move.b	#1,BUTTON-V(a6)

	move.b	d0,GetCharData-V(a6)
	move.l	d1,d0
	bset	#2,d0
	bra	.exit

.nokey:
	move.l	d1,d0	


	
.exit:
	move.l	d0,InputRegister-V(a6)
	POP
	move.l	InputRegister-V(a6),d0
	rts
	
GetSerial:					; Reads serialport and returns first char in buffer.
	cmp.w	#0,SerialSpeed-V(a6)		; if serialport is disabled.  skip all serial stuff
	beq	.exit
	move.b	#0,SerData-V(a6)
	bsr	ReadSerial
	cmp.b	#0,SerBufLen-V(a6)		; Check if we have a serialbuffer, if not, just exit
	beq	.exit
						; OK, we do have a serialbuffer, so return first char in buffer
	clr.l	d6
	move.b	SerBufLen-V(a6),d6
	lea	SerBuf-V(a6),a5
	move.b	(a5),Serial-V(a6)		; Read char in the buffer and put it to "Serial" that is the output variable
	PUSH
	move.l	#$fe,d6
.loop:
	move.b	1(a5),(a5)+
	dbf	d6,.loop
	sub.b	#1,SerBufLen-V(a6)
	move.b	#0,(a5)				; Clear the last byte in the buffer
	POP
	bset	#3,d0				; Mark that we had a serialevent
	rts
.exit:
	rts

ReadSerial:					; Read serialport, and if anything there store it in the buffer
	cmp.w	#0,SerialSpeed-V(a6)		; is serialport is disabled.  skip all serial stuff
	beq	.exit
        move.b  mfp_rsr,d5
        lsl.w   #8,d5
	move.b	mfp_udr,d5

	move.b	OldSerial-V(a6),d6
	cmp.b	d5,d6				; is there a change from last scan?
	bne	.serial				; yes. so. well handle it as a new char.
	btst	#15,d5				; Buffer full, we have a new char
	beq	.exit

.serial:
	move.b	#1,SerData-V(a6)
	move.b	d5,OldSerial-V(a6)
	move.b	#1,BUTTON-V(a6)

	clr.l	d6
	move.b	SerBufLen-V(a6),d6
	add.b	#1,SerBufLen-V(a6)
	lea	SerBuf-V(a6),a5
	move.b	d5,(a5,d6)
.exit:
	rts


GetMouseData:
						; Get data from mouse.. ANY port.
	rts
	;First handle Y position
	bsr	.CheckButton
	move.l	d0,d4				; Store d0 in d4 temporary

	move.b	$dff00a,d2
	move.b	OldMouse1Y-V(a6),d1
	cmp.b	d1,d2				; Check to old Y pos at mouse 1. if differs, mouse is moved.
	bne	.Mouse1YMove
.Check2Y:
	move.b	$dff00c,d2
	move.b	OldMouse2Y-V(a6),d1
	cmp.b	d1,d2
	bne	.Mouse2YMove
.CheckX:
	move.b	$dff00b,d2
	move.b	OldMouse1X-V(a6),d1
	cmp.b	d1,d2
	bne.w	.Mouse1XMove
.Check2X:
	move.b	$dff00d,d2
	move.b	OldMouse2X-V(a6),d1
	cmp.b	d1,d2
	bne.w	.Mouse2XMove


						; ok now we have a raw "mouse" data from either port.
						; but maybe time to convert it to a real X, Y cursor instead.
						; that goes between 0 and 640 on X, and 0 and 512 on Y.

	clr.l	d0
	clr.l	d1
	move.b	MouseX-V(a6),d0			; Store X pos in d0
	move.b	OldMouseX-V(a6),d1		; Store old X pos value in d1
	cmp.b	d1,d0				; Compare them to check if we have mousemovement
	bne	.XMove				; We have mousemovements in the X Axis

.CheckY:
	clr.l	d0
	clr.l	d1
	move.b	MouseY-V(a6),d0			; Store Y pos in d0
	move.b	OldMouseY-V(a6),d1		; Store old Y pos value in d1
	cmp.b	d1,d0				; Compare them to check if we have mousemovement
	bne	.YMove				; We have mousemovements in the Y Axis
.DoneM:
	move.l	d4,d0				; Restore d0 to keep flags
	rts

.XMove:
	bset	#0,d4				; Set flag that we have mousemovements, d4 is temporary
	move.b	#1,MOUSE-V(a6)
	move.b	d0,OldMouseX-V(a6)		; Store current to old.
						; OK , we have a movement, but what direction?
	bsr	.GetMouseDir
	cmp.b	#1,d1				; Check what direction
	beq	.backX
	add.w	d0,CurX-V(a6)
	move.w	d0,CurAddX-V(a6)
	cmp.w	#640,CurX-V(a6)
	bge	.highX
	bra	.DoneX
.highX:
	move	#640,CurX-V(a6)
	bra	.DoneX

.backX:
	sub.w	d0,CurX-V(a6)
	move.w	d0,CurSubX-V(a6)
	cmp.w	#0,CurX-V(a6)
	blt	.MaxX
	bra	.DoneX
.MaxX:
	move.w	#0,CurX-V(a6)
	bra	.DoneX
.DoneX:
	bra	.CheckY


.YMove:
	bset	#0,d4				; Set flag that we have mousemovements, d4 is temporary
	move.b	#1,MOUSE-V(a6)
	move.b	d0,OldMouseY-V(a6)		; Store current to old.
						; OK , we have a movement, but what direction?
	bsr	.GetMouseDir
	cmp.b	#1,d1				; Check what direction
	beq	.backY
	add.w	d0,CurY-V(a6)
	move.w	d0,CurAddY-V(a6)
	cmp.w	#512,CurY-V(a6)
	bge	.highY
	bra	.DoneY
.highY:
	move	#512,CurY-V(a6)
	bra	.DoneY

.backY:
	move.w	d0,CurSubY-V(a6)
	sub.w	d0,CurY-V(a6)
	cmp.w	#0,CurY-V(a6)
	blt	.MaxY
	bra	.DoneY
.MaxY:
	move.w	#0,CurY-V(a6)
	bra	.DoneY
.DoneY:
	bra	.DoneM



.GetMouseDir:
						; INDATA:
						;	D0 = Old pos
						;	D1 = New pos
						; OUTDATA:
						;	D0 = Number of steps
						;	D1 = if 0 = "backwards"

	move.l	d0,d2
	move.l	d1,d3				; Store values

	cmp.b	d0,d1				; Check what direction mousemovement is
	blt	.Lower				; ok we have a lower value
	sub.b	d0,d1				; Calculate how big the movement was.
	move.l	d1,d0				; put it in d0
	move.b	#1,d1				; Mark as "forward" movement

	cmp.w	#128,d0				; Check if we had a BIG movement.
	bge	.highadd			; yes.  so it must be the OPPOSITE direction instead
	rts

.highadd:
	move.b	#255,d1
	sub.b	d1,d0
	clr.b	d1
	rts	

.Lower:
	sub.b	d1,d0
	clr.l	d1				; Mark as "backward"
	cmp.w	#128,d0
	bge	.highsub
	rts	
.highsub:
	move.b	#255,d1
	sub.b	d1,d0
	move.b	#1,d1
	rts




.Mouse2XMove:
	move.b	d2,OldMouse2X-V(a6)
	sub.b	d2,d1
	sub.b	d1,MouseX-V(a6)
	bset	#0,d0
	bra	.CheckButton
	
.Mouse1XMove:
	move.b	d2,OldMouse1X-V(a6)
	sub.b	d2,d1
	sub.b	d1,MouseX-V(a6)
	bset	#0,d0
	bra	.Check2X
.Mouse1YMove:
	move.b	d2,OldMouse1Y-V(a6)
	sub.b	d2,d1				; Get delta from old value
	sub.b	d1,MouseY-V(a6)
	bset	#0,d0
	bra	.Check2Y
.Mouse2YMove:
	move.b	d2,OldMouse2Y-V(a6)
	sub.b	d2,d1
	sub.b	d1,MouseY-V(a6)
	bset	#0,d0
	bra	.CheckX	


.CheckButton:					; X and Y are now checked, lets check the buttons.
	cmp.b	#0,STUCKP1LMB-V(a6)		; Check if button was marked as stuck, if so. skip it
	bne	.nolmb1
; 	btst	#6,$bfe001	; Check LMB
	beq	.P1LMB
.nolmb1:
	cmp.b	#0,STUCKP2LMB-V(a6)
	bne	.CheckRight
; 	btst	#7,$bfe001
	beq	.P2LMB
.CheckRight:
	cmp.b	#0,STUCKP1RMB-V(a6)
	bne	.normb1
;	btst	#10,$dff016			; Check RMB port 1
;	beq	.P1RMB
.normb1:
	cmp.b	#0,STUCKP2RMB-V(a6)
	bne	.CheckMiddle
;	btst	#14,$dff016			; Check RMB port 2
;	beq	.P2RMB

.CheckMiddle
	cmp.b	#0,STUCKP1MMB-V(a6)
	bne	.nommb1
;	btst	#8,$dff016			; Check MMB
;	beq	.MMB
.nommb1:
	cmp.b	#0,STUCKP2MMB-V(a6)
	bne	.Done
;	btst	#12,$dff016
;	beq	.MMB
.Done:
	rts	

.P1LMB:
	move.b	#1,P1LMB-V(a6)
	bra	.LMB
.P2LMB:
	move.b	#1,P2LMB-V(a6)
.LMB:
	move.b	#1,BUTTON-V(a6)
	move.b	#1,MBUTTON-V(a6)
	move.b	#1,LMB-V(a6)			; Mark LMB as pressed
	bset	#1,d0
	bra	.CheckRight
.P1RMB:
	move.b	#1,P1RMB-V(a6)
	bra	.RMB
.P2RMB:
	move.b	#1,P2RMB-V(a6)
.RMB:
	move.b	#1,MBUTTON-V(a6)
	move.b	#1,BUTTON-V(a6)
	move.b	#1,RMB-V(a6)
	bset	#1,d0
	rts
.MMB:
	move.b	#1,MBUTTON-V(a6)
	move.b	#1,BUTTON-V(a6)
	move.b	#1,MMB-V(a6)
	bset	#1,d0
	rts

GetChar:					; Reads keyboard and serialport and returns the value in D0
	bsr	GetCharKey
	cmp.b	#0,d0
	bne	.noserial
	bsr	GetCharSerial
.noserial:
	move.b	d0,GetCharData-V(a6)
	rts

GetCharKey:
						; Keyboard have priority

	PUSH
	move.b	#0,keyresult-V(a6)
	bsr	GetKey				; Read keyboard
	cmp.b	#1,keynew-V(a6)			; Did we have a new keypress on the keyboard?
	bne	.no				; no, do serialstuff instead

	lea	keymap-V(a6),a0
	move.l	(a0),a0				; Set wanted keymap.
	bsr	ConvertKey			; Convert keyscan to actual ASCII

.no:
	POP
	clr.l	d0
	move.b	keyresult-V(a6),d0
	rts


GetCharSerial:
	PUSH
	clr.b	Serial-V(a6)
	bsr	GetSerial			; Read Serialport
	
	cmp.b	#1,SerAnsiFlag-V(a6)		; Are we in ANSI mode?
	beq	.ansimode

	POP
	clr.l	d0
	move.b	Serial-V(a6),d0			; Return what was in serial, if nothing it will be 0 (nothing happend)
	cmp.b	#$1b,d0				; is it ESC? if so. we might be in ANSI mode.
	beq	.ansion
	cmp.b	#$d,d0				; is it a linefeed?
	bne	.nolf
	move.b	#$a,d0				; convert it to CR
.nolf:
	rts
.ansion:
	move.b	#1,SerAnsiFlag-V(a6)		; Set flag that we are in ANSImode
	move.w	#0,SerAnsiChecks-V(a6)		; Clear ansicheck variable

	move.b	#0,d0				; return that nothing was recieved
	move.b	d0,Serial-V(a6)
	rts

.ansimode:
	
	move.b	Serial-V(a6),d0			; Load the serialdata to d0
	clr.l	d1				; clear d1 to make sure we do not get crapdata
	cmp.b	#0,d0				; did we get a 0 from serialport?
	beq	.sernull			; if so.. handle it
	cmp.b	#$1b,d0
	beq	.sernull

	cmp.b	#32,d0				; Strip away all nonascii chars
	blt	.noascii


	cmp.b	#$41,d0				;UP
	beq	.up
	cmp.b	#$42,d0				;DOWN
	beq	.down
	cmp.b	#$43,d0				;RIGHT
	beq	.right
	cmp.b	#$44,d0				;LEFT
	beq	.left
.noascii:
	clr.b	d0
	bra	.ansiexit
.ansichar
	move.b	#0,SerAnsiFlag-V(a6)
	bra	.ansiexit

.up:
	clr.b	SerAnsiFlag-V(a6)
	move.l	#30,d0
	bra	.ansiexit
.down:
	clr.b	SerAnsiFlag-V(a6)
	move.l	#31,d0
	bra	.ansiexit
.right:
	clr.b	SerAnsiFlag-V(a6)
	move.l	#28,d0
	bra	.ansiexit
.left:
	clr.b	SerAnsiFlag-V(a6)
	move.l	#29,d0
	bra	.ansiexit
.exitchar:
	POP
	clr.l	d0
	rts
	
.nochar:
	move.b	#$1b,d0
	move.b	#0,SerAnsiFlag-V(a6)

.ansiexit:
	move.b 	d0,Serial-V(a6)
.ansidone:
	POP
	clr.l	d0
	move.b	Serial-V(a6),d0			; Return what was in serial, if nothing it will be 0 (nothing happend)
	rts

.sernull:
	clr.b	d0				; OK we had a binary 0 as result
	add.w	#1,SerAnsiChecks-V(a6)		; add number of times we run through this
	cmp.w	#$f,SerAnsiChecks-V(a6)		; is it max?
	bne	.ansiexit			; if not. just exit with 0
	TOGGLEPWRLED
	move.w	#0,SerAnsiChecks-V(a6)		; ok we had too many checks. guess nothing happened. so exit with an ESC.
	bra	.nochar		
	

ConvertKey:					; Converts keystroke to char.
							; INDATA:
						; a0=pointer to keymap
	move.b	(a0,d0),d1
	move.b	d1,keypressed-V(a6)
	move.b	d1,keyresult-V(a6)
	move.b	AtariKeyShifted-AtariKey(a0,d0),d1
	move.b	d1,keypressedshifted-V(a6)
	cmp.b	#0,keyshift-V(a6)
	beq	.notshift
	move.b	d1,keyresult-V(a6)
.notshift:
	rts	

IKBDRead:
	move.w	#0,d1
.status
	lea.l	(ACIA_IKBD_BASE).w,a2
	move.b	slowcia,d0			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	move.b   ACIA_CTRL(a2),d0      /* read status byte */
	btst	#0,d0
	beq.s	.none
	
	move.b   ACIA_DATA(a2),d1      /* read data byte */
.none
	jmp	(a1)


IKBDWrite:
        lea.l     (ACIA_IKBD_BASE).w,a2         /* point to ikbd register base */

	move.l	  #900000,d3	; make sure we dont wait for the keyboard forever.
.ikbd_wr1
        move.b    (a2),d2                       /* grab keyboard status */
	sub.l	#1,d3				; count down timeout value
	cmp.l	#0,d3				; if 0, timeout.
	beq	.fail
	
        btst      #1,d2	
        beq.s     .ikbd_wr1


	lea	mfp_tcdr,a0
	move.w	#$BF,d0
.oloop		
	move.b	(a0),d2
	dbf	d0,.oloop

	move.b    d1,ACIA_DATA(a2)              /* write char to the ikbd port */
	move.l	  #0,d0
	jmp	  (a1)
	
.fail	move.l	  #1,d0	
	jmp	  (a1)

	
GetKey:
	PUSH					; Read keyboard

	bsr	WaitShort
	bsr	WaitShort
	bsr	WaitShort

	clr.b	keynew-V(a6)			; Clear keynew variable, will be set if we have a new keypress
	clr.b	keyup-V(a6)
	clr.b	keydown-V(a6)

	
	lea.l	(ACIA_IKBD_BASE).w,a2
	move.b	slowcia,d1			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	move.b   ACIA_CTRL(a2),d1      /* read status byte */
	btst	#0,d1
	beq.s	.nothing

	move.b  ACIA_DATA(a2),d1      /* read data byte */
	beq	.nothing
	
	cmp.b	#$F6,d1
	blt.s	.keyboard
	cmp.b	#0,d1

	
	;; eat special codes

.keyboard	
	move.b	d1,d0
	and.b	#$7f,d0

	move.b	d1,scancode-V(a6)		; Store the original scancode	
	btst	#7,d1
	beq	.down

	;; it was a key up event.
	move.b	#1,keyup-V(a6)		; Set that a key was pressed
	move.b	#0,keystatus-V(a6)
	bra	.finish
	
.down
	;; it was a key down event
	move.b	#1,keydown-V(a6)		; Set that a key was pressed
	move.b	#1,keystatus-V(a6)
	move.b	#1,keynew-V(a6)		
.finish
	move.b	d0,key-V(a6)			; after rotates etc, store the keycode
.nothing
	
	POP
	move.b	key-V(a6),d0
	rts

	move.b	#$88,$bfed01			
	bsr	WaitShort
	bsr	WaitShort
	bsr	WaitShort
	clr.b	keynew-V(a6)			; Clear keynew variable, will be set if we have a new keypress
	clr.b	keyup-V(a6)
	clr.b	keydown-V(a6)
	move.b	$bfec01,d0			; Read keyboard
	move.b	d0,scancode-V(a6)		; Store the original scancode
	ror.b	#1,d0
	not.b	d0
	
	move.b	d0,key-V(a6)			; after rotates etc, store the keycode
	btst	#7,d0				; Test if key is up or down
	beq	.down2
	move.b	#1,keyup-V(a6)			; Set that a key was released
	clr.b	keystatus-V(a6)
	bra	.nokey				; Somewhat wrong label.. :)
.down2:	
	move.b	#1,keydown-V(a6)		; Set that a key was pressed
	move.b	#1,keystatus-V(a6)
	move.b	#1,keynew-V(a6)

.nokey:
	bset	#6,$bfee01			; Set handshakebit
	sf.b	$bfec01				; Clear keyboardbuffer
	bsr	WaitShort			; Wait a short while
	Bsr	WaitShort
	bsr	WaitShort
	bsr	WaitShort
	bclr	#6,$bfee01			; Clear the handshakebit

						; OK.  we have read the buffer and also cleared it. Lets handle it.

	bclr	#7,d0				; We clear the up/down bit, so we know what key we handled

	cmp.b	#$60,d0
	beq	.shift
	cmp.b	#$61,d0
	beq	.shift
	cmp.b	#$62,d0
	beq	.capsshift			; Now we have handled shift


	cmp.b	#$64,d0
	beq	.alt
	cmp.b	#$65,d0
	beq	.alt				; Now we have handled alt

	cmp.b	#$63,d0
	beq	.ctrl
	cmp.b	#$67,d0
	beq	.ctrl				; Now we have handled ctrl

.keydone:
	POP
	move.b	key-V(a6),d0
	rts

.alt:
	move.b	keystatus-V(a6),keyalt-V(a6)
	move.b	#0,key-V(a6)
	bra	.keydone

.ctrl:
	move.b	keystatus-V(a6),keyctrl-V(a6)
	move.b	#0,key-V(a6)
	bra	.keydone

.shift:						; we have a happening on the SHIFT key
	cmp.b	#0,keycaps-V(a6)		; Check if caps is pressed
	bne	.caps
	move.b	#0,key-V(a6)
	move.b	keystatus-V(a6),keyshift-V(a6)
.caps:
	bra	.keydone
.capsshift:
	move.b	keystatus-V(a6),keycaps-V(a6)
	move.b	keystatus-V(a6),keyshift-V(a6)
	move.b	#0,key-V(a6)
	bra	.keydone


GetHex:						; Takes an ASCII and returns only valid chars for hex. (and backspace/enter)

						; Input:
						;	D0 = Char

						; Output:
						; 	D0 = Char
	cmp.b	#"0",d0
	blt	.nonumber
	cmp.b	#"9",d0
	bgt	.nonumber
	rts

.nonumber:
	bclr	#5,d0				; Make it uppercase
	cmp.b	#"A",d0
	blt	.nochar
	cmp.b	#"F",d0
	bgt	.nochar
	rts
.nochar:
	cmp.b	#8,d0
	bne	.nobackspace
	rts
.nobackspace:
	cmp.b	#$d,d0
	bne	.checkenter
						; we had linefeed? convert to an enter :)
	move.b	#$a,d0
.checkenter:
	cmp.b	#$a,d0
	bne	.noenter
	rts
.noenter:
	cmp.b	#27,d0
	bne	.noesc
	rts
.noesc:
	move.b	#0,d0
	rts
	

FixBitplane:
; Set bitplanes in copperlist
;
; Indata
;
;	A0 = bitplanespointers in copper
;	A1 = List to bitplane pointers, 0 = End of list
;
	move.b	  #$1,v_mode ; set medium res
	move.b 	  #$2,v_sync ; setup pal
	
	; load display address (add 255 & round off low byte for STF)
	move.l	(a1),d0 ;  $00HHMMLL 
	add.l	#$FF,d0
	lsr.w #8,d0 ; $00HH00MM
	move.l d0,v_base ; load mid and high bytes of gapped 24bit address. low byte not assigned.
	
	move.w	#$0000,color0
	move.w	#$0f00,color2	
	move.w	#$00f0,color1
	move.w	#$0ff0,color3
	move.w	#$000f,color4
	move.w	#$0f0f,color5
	move.w	#$00ff,color3
	move.w	#$0fff,color7
	move.w	#$0ff0,color8
	
	rts

CopyToChip:					; Copy data that needs to be in Chipmem from ROM for menusystem etc.

	move.l	#0,DummySprite-V(a6)		; Just make sure sprite i empty

	lea	RomMenuCopper,a0
	move.l	a6,a1
	add.l	#MenuCopper-V,a1
	move.l	#EndRomMenuCopper-RomMenuCopper,d0
	bsr	CopyMem				; Copy the font to chipmem

	lea.l	MenuCopper-V(a6),a0
	move.l	a0,shit-V(a6)
ClearSprite:
	move.w	#7,d0
	move.l	a6,d1
	add.l	#DummySprite-V,d1
.ClearS:
	swap	d1
	move.w	d1,2(a0)

	swap	d1
	move.w	d1,6(a0)

	adda.l	#8,a0
	dbf	d0,.ClearS			; A empty dummysprite is now defined
	

	lea	ROMAudioWaves,a0
	move.l	a6,a1
	add.l	#AudioWaves-V,a1
	move.l	#EndROMAudioWaves-ROMAudioWaves,d0
	bsr	CopyMem				; Copy the font to chipmem

	lea	MT_Init,a0
	move.l	a6,a1
	add.l	#ptplay-V,a1
	move.l	#mt_END-MT_Init,d0
	bsr	CopyMem				; Copy the protracker replayroutine to mem

	move.l	a6,d0
	add.l	#ptplay-V,d0			; d0 now contains first address of where replayroutine is in memory
	move.l	d0,AudioModInit-V(a6)
	move.l	d0,d2				; Make a backup of it

	add.l	#MT_End-MT_Init,d0		; Add where MR_End is to a1 so we can store it aswell
	move.l	d0,AudioModEnd-V(a6)		; Store it for future use
	move.l	d2,d0				; Restore a1
	
	add.l	#MT_Music-MT_Init,d0		; Add where MR_Music is to a1 so we can store it aswell
	move.l	d0,AudioModMusic-V(a6)		; Store it

	move.l	d2,d0
	add.l	#mt_MasterVol-MT_Init,d0
	move.l	d0,AudioModMVol-V(a6)


	rts


CopyMem:
						; Copy one block memory to another
						; INDATA:
						;	A0 = Source
						;	D0 = Bytes to copy. (YES. being lazy, we do this bytestyle)
						;	A1 = Destination
	clr.l	d7
.loop:
	move.b	(a0)+,(a1)+
	add.l	#1,d7
	cmp.l	d7,d0
	bgt	.loop				; YES a DBF would do just fine. but i want to support more then 64k
	rts


Init_Serial:
	
        PUSH

        ;* init the "d" timer		
        moveq     #3,d0                     ; select the d timer
        moveq     #1,d1                     ; init for /4 for 9600 baud
        moveq     #2,d2                     ; init for 9600 baud
	move.l    #.ret,a4
        bra       settimer                  ; branch to out timer initialier...
.ret
	lea       (mfp_gpip).w,a0
        move.l    #$880105,d0
        movep.l   d0,$26(a0)                ; inits scr,ucr,rsr,tsr
        POP

	rts
	

Clean_Serial:
	nop
rs232_out:	
	cmp.w	#0,SerialSpeed-V(a6)
	beq	.noserial
	cmp.b	#1,NoSerial-V(a6)
	beq	.noserial
	PUSH
	bsr	ReadSerial
	move.l	#$9000,d2			; Load d2 with a timeoutvariable. only test this number of times.
						; IF CIA for serialport is dead we will not end up in a wait-forever-loop.
						; and as we cannot use timers. we have to do this dirty style of coding...
	SENDSERIAL d0
	POP
.noserial:
	rts


PutChar:

	PUSH					; Puts a char on the screen.
						; INDATA: (expects longwords)
						; D0 = Char (IF color above 8, it gets reversed in that color - 8)
						; D1 = Color
						; D2 = XPos
						; D3 = YPos
	lsr.w	#1,d1

	cmp.b	#1,d0				; Nonprinted char?
	beq	.noprint					

	cmp.b	#0,NoDraw-V(a6)			; Check if we should draw
	bne	.exit

	move.l	d0,d5
	sub.b	#32,d0				; Subtract 32 from the char as " " is the first char in the Font.
	clr.l	d4				; if d4 if 0. no invert of char
	
	cmp.b	#4,d1
	blt	.Normal				; Normal color. do not invert
	move.b	#1,d4
	sub.b	#4,d1
.Normal:

	mulu	#160*8,d3				; Multiply Y with 640 to get a correct Y pos on screen
	move.w	d2,d7
	and.w	#$fffe,d2
	and.w	#$1,d7
	mulu	#2,d2
	add.w	d7,d2
	add.w	d2,d3				; Add X pos to the d3. D3 now contains how much to add to bitplane to print

	
	move.l	Bpl1Ptr-V(a6),d7		; load A0 with address of BPL1
	add.l	#$ff,d7
	and.l	#$ffffff00,d7
	move.l	d7,a0
	move.l	a0,a1		; load A1 with address of BPL2
	addq.l	#2,a1
	
	lea	RomFont,a3

	adda.l	d3,a0
	adda.l	d3,a1

	mulu	#8,d0
	add.l	d0,a3
	
	cmp.b	#0,NoChar-V(a6)			; Check if we should print
	bne	.no				; nonzero. do not print

	move.l	#7,d0
.loop:
	move.b	(a3)+,d2

	cmp.b	#1,d4				; IF D4 is 1, invert char
	bne.s	.noinvert
	eor	#$ff,d2

.noinvert:
	clr.b	(a0)
	clr.b	(a1)

	btst	#0,d1				; Check what bitplane to print on
	beq.w	.nopl1
	move.b	d2,(a0)

.nopl1:
	btst	#1,d1
	beq.s	.nopl2
	move.b	d2,(a1)

.nopl2:
	adda.l	#80*2,a0
	adda.l	#80*2,a1
	dbf	d0,.loop			; put char on the screen
.no:
	move.l	d5,d0
.exitwithserial:
	bsr	rs232_out
	POP
	rts


.noprint:
	move.l	#" ",d0
	bsr	rs232_out
	POP
	rts
.exit:
	TOGGLEPWRLED			; As we cannot put any chars on screen. flicker the powerled so user MIGHT
						; notice something is happening. as DMA etc are out. we cannot rely on colors etc.
	move.b	d3,color0			; but. just for the "fun" of it. push some random crap on background colotr
	move.b	d0,color1
	bra	.exitwithserial

PrintChar:					; Puts a char on screen and add X, Y variables depending on char etc.
						; INDATA: (Longwords expected)
						;	D0 = Char
						;	D1 = Color
	PUSH
	cmp.b	#1,d0				; check if char is $1
	beq	.Noprint			; then it is a nonprinted char
	cmp.b	#$d,d0
	beq	.ignore

	move.l	d0,d7
	move.l	d1,d6
	move.l	d1,d0
	cmp.b	Color-V(a6),d0

	beq	.samecol			; if it is the same color as last time.. do nothing special
	move.b	d0,Color-V(a6)

						; ok we have a new color, change it to serialport
	cmp.b	#8,d0
	blt	.noinvert

	move.b	#1,Inverted-V(a6)		; set the inverted-flag

	lea	Black,a0
	bsr	SendSerial
	sub.l	#8,d1

	lea	Ansi,a0
	bsr	SendSerial			; Send ANSI esc code.
	move.b	#"4",d0
	bsr	rs232_out
	move.b	d1,d0
	bsr	oldbindec
	bsr	SendSerial
	move.l	#"m",d0
	bsr	rs232_out
	bra	.samecol

.noinvert:

	cmp.b	#0,Inverted-V(a6)		; Check if the invertedflag is 0
	beq	.notinverted			; it was 0, last char printed was not inverted

						; last char WAS inverted. we must clear it on the serialport.
	lea	AnsiNull,a0
	bsr	SendSerial			; Send the string to serialport that clears inverted.
	clr.b	Inverted-V(a6)			; clear the invertedflag aswell


.notinverted:

	lea	Ansi,a0
	bsr	SendSerial			; Send ANSI esc code.
	move.b	#"3",d0

	bsr	rs232_out
	move.b	d1,d0
	bsr	oldbindec


	bsr	SendSerial
	move.l	#"m",d0
	bsr	rs232_out
	
.samecol:
	move.l	d6,d1
	move.l	d7,d0
	move.l	#0,d2
	move.l	#0,d3

	cmp.b	#$a,d0				; IF char is $a, new line
	beq.s	.NewLine
	cmp.b	#$d,d0				; IF Char is $d, put cursor to the left
	bne.s	.No
	clr.b	Xpos-V(a6)


	PUSH
	move.b	#"A",d0
	bsr	rs232_out
	POP
.No:
	clr.l	d2
	clr.l	d3				; Clear d2 and d3 so it is all clear before printing the char
.Noprint:
	move.b	Xpos-V(a6),d2
	move.b	Ypos-V(a6),d3			; Take current X and Y positions to d2 and d3 as argument to PutChar
	bsr	PutChar				; Print the char on screen
	add.b	#1,Xpos-V(a6)			; Add one to the Xpos
	cmp.b	#79,Xpos-V(a6)			; check if we have hit the border
	bgt	.NewLine			; we have hit the border. put it on a new line instead.
.ignore:
	POP
	rts

.NewLine:
	clr.b	Xpos-V(a6)			; Put X pos to the left
	add.b	#1,Ypos-V(a6)			; Add Y pos
	PUSH
	move.l	#$a,d0
	bsr	rs232_out
	move.l	#$d,d0
	bsr	rs232_out
	POP
	cmp.b	#31,Ypos-V(a6)			; Hit the border?
	bgt	.EndOfPage			; ohyes.
	POP
	rts
.EndOfPage:
	bsr	ScrollScreen
	clr.b	Xpos-V(a6)
	sub.b	#1,Ypos-V(a6)
	POP
	rts

MakePrintable:
						; Makes the char in D0 printable. remove controlchars etc.
	cmp.b	#" ",d0
	ble	.lessthenspace			; is less then space.. make it space.
	rts
.lessthenspace:
	move.b	#" ",d0
	rts

StrLen:
					; Returns length of string
						; IN:
						;	A0 = Pointer to nullterminated string
						; OUT:
						;	D0 = Length of string
	PUSH
	clr.l	d0				; Clear d0
.loop:
	move.b	(a0)+,d7			; Load d7 with char
	cmp.b	#0,d7
	beq	.exit				; Exit if we found a null
	cmp.b	#2,d7				; if centercommand, skip char
	beq	.skip
	add.l	#1,d0				; add 1 to stringlength
.skip:
	bra	.loop
.exit:
	move.l	d0,temp-V(a6)			; Store length in temp. as we will restore all registers
	POP
	move.l	temp-V(a6),d0			; So back to D0 again
	rts
	

Print:						; Prints a string
	PUSH					; INDATA:
	clr.l	d7				; Clear d7
	cmp.b	#2,(a0)				; Check if first byte in string is a 2, then we will center it.
	beq	.center
.print:						; A0 = string to print, nullterminated
						; D1 = Color
	clr.l	d0
	move.b	(a0)+,d0
	cmp.b	#0,d0				; is the char 0?
	beq	.exit				; exit printing, we are done

	bsr	PrintChar

	add.l	#1,d7				; add one to d7
	cmp.l	#3000,d7			; to avoid "foreverprinting" bug, if string is too long, just stop
	beq	.exit
	bra.s	.print
.exit:
	POP
	rts


.center:
	move.l	d1,d5				; backup colordata
	adda.l	#1,a0				; First skip this first char.
	move.l	a0,a1				; Store stringaddress for future use.
	clr.l	d7				; Clear d7
.loop:
	move.b	(a0)+,d6			; Read char into d6

	cmp.b	#0,d6				; End of string?
	beq	.end

	cmp.b	#31,d6
	ble	.loop				; is less then space? then it is not printable and should be ignored

	add.l	#1,d7				; Add 1 to length of string
	bra	.loop
.end:						; OK we are done, d7 now contains length of string
	cmp.b	#80,d7				; Check if string is larger then one row, then skip centerstuff
	bge	.zero

	move.l	#80,d1
	sub.b	d7,d1				; d7 now contains number of chars to fill row.
	asr	#1,d1				; Divide by 2, d7 now contains number of spaces to fill out to center

	cmp.b	#0,d1				; Check if zero, then no spaces to be printed
	beq	.zero
	move.l	d1,d7
	sub.b	#1,d7				; Subtract with 1 so loop gets correct number of spaces.

.spaceloop:
	move.b	#" ",d0				; make sure a space is printed
	move.l	d5,d1
	bsr	PrintChar			; Print it
	dbf	d7,.spaceloop			; loop it.

.zero:
	move.l	a1,a0				; We are done, restore string to print (minus first char) and print it
	move.l	d5,d1				; Restore d1 (color)
	bra	.print


ScrollScreen:
	cmp.b	#0,NoDraw-V(a6)			; Check if we should draw
	bne	.exit

	PUSH
	move.l	Bpl1Ptr-V(a6),a0		; load A0 with address of BPL1
	move.l	#200*8,d0		; How much data is one screen
	sub.l	#160*8,d0				; Subtract 8 pixels
	divu	#4,d0				; Divide by 4 to get longwords.
.loop:
	move.l	160*8(a0),(a0)+
	dbf	d0,.loop

	move.w	#160*8,d0
.loop2:
	clr.l	(a0)+				; Clear last row
	dbf	d0,.loop2

	POP
.exit:	rts

SendSerial:
						; Indata a0=string to send to serialport
						; nullterminated
	PUSH
	clr.l	d0				; Clear d0
.loop:
	move.b	(a0)+,d0
	cmp.b	#0,d0				; end of string?
	beq	.nomore				; yes
	bsr	rs232_out
	bra.s	.loop
.nomore:
	POP
	rts

SetPos:						; Set cursor at wanted position on screen
						; Indata:
						; d0 = xpos
						; d1 = ypos

	PUSH
	move.b	d0,Xpos-V(a6)
	move.b	d1,Ypos-V(a6)
	move.l	d0,d2
	move.l	d1,d0
	add.l	#1,d0
	lea	Ansi,a0
	bsr	SendSerial
	bsr	oldbindec			;convert d0 to decimal string (x pos)
	bsr	SendSerial			;and send result to serialport
	move.l	#";",d0				;load d0 with ;
	bsr	rs232_out
	move.l	d2,d0
	add.l	#1,d0
	bsr	oldbindec			;convert d0 (from d1. Ypos) to decimal
	bsr	SendSerial
	move.l	#"H",d0
	bsr	rs232_out
	POP
	rts


SetPosNoSerial:					; Set cursor at wanted position on screen but not on serialport
						; Indata:
						; d0 = xpos
						; d1 = ypos

	move.b	d0,Xpos-V(a6)
	move.b	d1,Ypos-V(a6)
	rts




	; *********************************************
	;
	; $VER:	Binary2Decimal.s 0.2b (22.12.15)
	;
	; Author: 	Highpuff
	; Orginal code: Ludis Langens
	;
	; In:	D0.L = Hex / Binary
	;
	; Out:	A0.L = Ptr to null-terminated String
	;	D0.L = String Length (Zero if null on input)
	;
	; *********************************************


b2dNegative	equ	0			; 0 = Only Positive numbers
						; 1 = Both Positive / Negative numbers

	; *********************************************


bindec:		movem.l	d1-d5/a1,-(sp)

		moveq	#0,d1			; Clear D1/2/3/4/5
		moveq	#0,d2
		moveq	#0,d3
		moveq	#0,d4
		moveq	#0,d5

		lea.l	b2dString+12-V(a6),a0
		movem.l	d1-d3,-(a0)		; Clear String buffer

		neg.l	d0			; D0.L ! D0.L = 0?
		bne	.notZero		; If NOT True, Move on...
		move.b	#$30,(a0)		; Put a ASCII Zero in buffer
		moveq	#1,d0			; Set Length to 1
		bra	.b2dExit		; Exit	
		
.notZero:	neg.l	d0			; Restore D0.L
	IF b2dNegative				; Is b2dNegative True?

		move.l	d0,d1			; D1.L = D0.L
		swap	d1			; Swap Upper Word with Lower Word
		rol.w	#1,d1			; MSB  = First byte
		btst	#0,d1			; Negative?
		beq	.notNegative		; If not, jump to .notNegative
		move.b	#$2d,(a0)+		; Add a '-' to the String
		neg.l	d0			; Make D0.L positive
.notNegative:	moveq	#0,d1			; Clear D1 after use

	ENDC
.lftAlign:	addx.l	d0,d0			; D0.L = D0.L << 1
		bcc.s	.lftAlign		; Until CC is set (all trailing zeros are gone)

.b2dLoop:	abcd.b	d1,d1			; xy00000000
		abcd.b	d2,d2			; 00xy000000
		abcd.b	d3,d3			; 0000xy0000
		abcd.b	d4,d4			; 000000xy00
		abcd.b	d5,d5			; 00000000xy
		add.l	d0,d0			; D0.L = D0.L << 1
		bne.s	.b2dLoop		; Loop until D0.L = 0
	
		; Line up the 5x Bytes

		lea.l	b2dTemp-V(a6),a1	; A1.L = b2dTemp Ptr
		move.b	d5,(a1)			; b2dTemp = d5.xx.xx.xx.xx
		move.b	d4,1(a1)		; b2dTemp = d5.d4.xx.xx.xx
		move.b	d3,2(a1)		; b2dTemp = d5.d4.d3.xx.xx
		move.b	d2,3(a1)		; b2dTemp = d5.d4.d3.d2.xx
		move.b	d1,4(a1)		; b2dTemp = d5.d4.d3.d2.d1


		; Convert Nibble to Byte
		
		moveq	#5-1,d5			; 5 bytes (10 Bibbles) to check
.dec2ASCII:	move.b	(a1)+,d1		; D1.W = 00xy
		ror.w	#4,d1			; D1.W = y00x
		move.b	d1,(a0)+		; Save ASCII
		sub.b	d1,d1			; D1.B = 00
		rol.w	#4,d1			; D1.W = 000y
		move.b	d1,(a0)+		; Save ASCII
		dbf	d5,.dec2ASCII		; Loop until done...

		sub.l	#10,a0			; Point to first byte (keep "-" if it exists)
		move.l	a0,a1

		; Find where the numbers start and trim it...

		moveq	#10-1,d5		; 10 Bytes total to check
.trimZeros:	move.b	(a0),d0			; Move byte to D0.B
		bne.s	.trimSkip		; Not Zero? Exit loop
		add.l	#1,a0			; Next Character Byte
		dbf	d5,.trimZeros		; Loop
.trimSkip:	move.b	(a0)+,d0		; Move Number to D0.B
		add.b	#$30,d0			; Add ASCII Offset to D0.B
		move.b	d0,(a1)+		; Move to buffer
		dbf	d5,.trimSkip		; Loop

		; Get string length

		move.l	a1,d0			; D0.L = EOF b2dString
		lea.l	b2dString-V(a6),a0	; A0.L = SOF b2dString
		sub.l	a0,d0			; D0.L = b2dString.Length
		move.b	#0,(a0,d0)
.b2dExit:	movem.l	(sp)+,d1-d5/a1
		rts





oldbindec:					; Converts a binary number to decimal textstring
						; this is my old bin->dec code. it is still here as I need a bin-dec
						; convertion done for ANSI stuff in my print routine. and that can
						; overwrite other data when printing. so to separate the different things
						; why not have this left.  this only handles word and no longwords...
						;
						; INDATA:
						;	D0 = binary number (word)
						; OUTDATA:
						;	A0 = Pointer to "bindecoutput" contining the string

	PUSH
	lea	bindecoutput-V(a6),a0
	move.b	#$20,d1
	tst.w	d0
	bpl	.notneg
	move.b	#$2d,d1
	neg.w	d0
	clr.l	d3
.notneg:
	move.b	d1,(a0)
	adda.l	#5,a0
	move.w	#4,d1
.loop:
	ext.l	d0
	divs	#10,d0
	swap	d0
	move.b	d0,-(a0)
	add.b	#$30,(a0)
	swap	d0
	dbra	d1,.loop
	clr.l	d0
.scroll:
	move.w	#6,d2
	lea	bindecoutput-V(a6),a0
	lea	bindecoutput+1-V(a6),a1
	move.b	(a0),d1
	cmp.b	#"0",d1
	bne.s	.stop
	add.b	#1,d0
	cmp.b	#5,d0
	beq.s	.stop
.scroll1:
	move.b	(a1)+,(a0)+
	dbf	d2,.scroll1
	bra.s	.scroll
.stop:
	POP
	lea	bindecoutput-V(a6),a0
	rts


hexbin:						; Converts a longword to binary.
						; NO ERRORCHECk WHATSOEVER!
						; Input:
						;	A0 = String to convert (8 bytes)
						; Output:
						;	D0 = binary number
						;
	PUSH
	clr.l	d0				; Clear D0 that will contain the binary number
	move.l	#3,d7				; Loop this 3 times.
.loop:

	bsr	hexbytetobin

	asl.l	#8,d0				; Rotate d0 8 bits to make room for the next byte
	add.l	d2,d0				; Add the content of d2 to d0
	dbf	d7,.loop			; Repeat 3 times to complete one longword
	move.l	d0,HexBinBin-V(a6)
	POP
	move.l	HexBinBin-V(a6),d0
	rts



hexbytetobin:
	clr.l	d2				; Clear D2 that holds the ASCII code
	move.b	(a0)+,d2			; Read one byte of the string
	bsr	.tobin				; Convert to binary
	move.l	d2,d1				; Store the value in D1
	move.b	(a0)+,d2			; Read next char to complete this byte
	bsr	.tobin				; Convert to binary
	asl.l	#4,d1				; Rotate the first char 4 bits
	add.l	d1,d2				; add d1 to d2, d2 will now contain this byte in binary
	rts
.tobin:
	cmp.b	#"A",d2				; Check if it is "A"
	blt	.nochar				; Lower then A, this is not a char
	sub.l	#7,d2				; ok we have a char, subtract 7
.nochar:
	sub.l	#$30,d2				; Subtract $30, converting it to binary.
	rts

binhexbyte:
						; Same as binhex but only for one byte.
	PUSH
	lea	hextab,a1			; location of hexstring source
	lea	binhexoutput-V(a6),a0
	clr.l	(a0)
	clr.l	4(a0)
	clr.w	8(a0)				; Clear the area first.
	adda.l	#9,a0
	move.l	#1,d1
.loop:
	move.l	d0,d2
	and.l	#15,d2
	move.b	(a1,d2),-(a0)
	lsr.l	#4,d0
	dbra	d1,.loop
	POP
	lea	binhexoutput+7-V(a6),a0
	rts



binhexword:
						; Same as binhex but only for one word.
	PUSH
	lea	hextab,a1			; location of hexstring source
	lea	binhexoutput-V(a6),a0
	clr.l	(a0)
	clr.l	4(a0)
	clr.w	8(a0)				; Clear the area first.
	adda.l	#9,a0
	move.l	#3,d1
.loop:
	move.l	d0,d2
	and.l	#15,d2
	move.b	(a1,d2),-(a0)
	lsr.l	#4,d0
	dbra	d1,.loop
	POP
	lea	binhexoutput+4-V(a6),a0
	move.b	#"$",(a0)
	rts
						; Same as binhex but only for one byte.


binstringbyte:
						; Converts a binary number (byte) to binary string
						; INDATA:
						;	D0 = binary number
						; OUTDATA:
						;	A0 = Poiner to outputstring
	PUSH
	move.l	#7,d7
	lea	binstringoutput-V(a6),a0
.loop:
	btst	d7,d0
	beq	.notset
	move.b	#"1",(a0)+
	bra	.done
.notset:
	move.b	#"0",(a0)+
.done:
	dbf	d7,.loop
	move.b	#0,(a0)
	
	POP
	lea	binstringoutput-V(a6),a0
	rts


binstring:
						; Converts a binary number (longword) to binary string
						; INDATA:
						;	D0 = binary number
						; OUTDATA:
						;	A0 = Poiner to outputstring
	PUSH
	move.l	#31,d7
	lea	binstringoutput-V(a6),a0
.loop:
	btst	d7,d0
	beq	.notset
	move.b	#"1",(a0)+
	bra	.done
.notset:
	move.b	#"0",(a0)+
.done:
	dbf	d7,.loop
	move.b	#0,(a0)
	
	POP
	lea	binstringoutput-V(a6),a0
	rts

		

binhex:						; Converts a binary number to hex
						; INDATA:
						;	D0 = binary nymber
						; OUTDATA:
						;	A0 = Pointer to "binhexoutput" contiaing the string
	PUSH
	lea	hextab,a1			; location of hexstring source
	lea	binhexoutput-V(a6),a0
	clr.l	(a0)
	clr.l	4(a0)
	clr.w	8(a0)				; Clear the area first.
	move.b	#"$",(a0)			; put a leading "$" char in the beginning
	adda.l	#9,a0
	move.l	#7,d1
.loop:
	move.l	d0,d2
	and.l	#15,d2
	move.b	(a1,d2),-(a0)
	lsr.l	#4,d0
	dbra	d1,.loop
	POP
	lea	binhexoutput-V(a6),a0
	rts

HandleMenu:					; Routine that handles menus.
	cmp.b	#0,MenuChoose-V(a6)		; If this item chosen with keyboard etc?
	bne	.released			; if so.  go to "releaaed" (after LMB is released again..)
	cmp.b	#1,LMB-V(a6)
	bne	.nolmb				; no LMB pressed

.CheckButton:
	bsr	GetInput
	bsr	WaitShort
	cmp.b	#0,LMB-V(a6)
	bne	.CheckButton
.released:
	clr.b	MenuChoose-V(a6)		; Clear value of choosen item
	clr.l	d0
	move.w	MenuNumber-V(a6),d0
	lea	MenuCode,a0			; Get list of pointers to list for the menu
	mulu	#4,d0				; Multiply menunumber with 4
	add.l	d0,a0				; read pointer to the correct menu
	move.l	(a0),a0				; a0 now contains address of menu routines

	clr.l	d0
	move.b	MarkItem-V(a6),d0		; Get the marked item
	mulu	#4,d0
	
	add.l	d0,a0				; a0 now contains the address of the pointer to the routing
	move.l	(a0),a0				; a0 now contains the address of the routine.

	jmp	(a0)				; go there
.nolmb:

	clr.l	d0
	move.w	MenuNumber-V(a6),d0
	lea	MenuKeys,a0
	mulu	#4,d0
	add.l	d0,a0
	move.l	(a0),a0				; A0 now contains pointer to where list of interesting keys are.
	clr.l	d0				; Clear d0
.loop:
	cmp.b	#0,(a0)				; does A0 point to 0? in that case, out of list
	beq	.nokey

	move.b	GetCharData-V(a6),d7		; d7 is now what the last keycode was.
	cmp.b	(a0),d7				; check if value in list is the same as pressed keycode
	beq	.Pressed
.nokeyboard:
	add.l	#1,a0
	add.l	#1,d0
	bra	.loop
.nokey:	
	rts

.Pressed:					; ok we have a match of key or serial.
	move.b	d0,MarkItem-V(a6)		; store it to marked item
	bra	.released			; so jump to the part of the code that actually executes the routine

PrintMenu:
						; Prints out menu.
						; INDATA = D0 - MenuNumber
	PUSH
	
	clr.l	d1
	clr.l	d2
	clr.l	d3
	clr.l	d4
	clr.l	d5
	clr.l	d6
	clr.l	d7

	
	cmp.b	#0,PrintMenuFlag-V(a6)
	beq	.noprint			; if flag is 0, menu is already printed.
	cmp.b	#2,PrintMenuFlag-V(a6)		; Check if we just want to update
	beq	.noupdatemenu
	move.b	#0,MenuPos-V(a6)		; Clear menuposition. always start at the top as we didnt want to update
.noupdatemenu:	
	clr.l	d0
	move.w	MenuNumber-V(a6),d0		; Load what menunumber to print
	move.l	MenuVariable-V(a6),a2		; A2 now contains pointer to pointerlist of variables. if 0 = no variables ignore

	move.l	Menu-V(a6),a0			; Load a0 with pointer to list of menus.
.nozero:
	mulu	#4,d0				; multiply d0 with 4 to point on the correct item on list.
	add.l	d0,a0				; A0 now points on the correct item in the menulist
	move.l	(a0),a1				; A1 now contains the menuinfo.

	clr.l	d0
	clr.l	d1
	bsr	SetPos
	move.l	(a1),a0				; Print first line (label) of the menu
	move.l	#7,d1
	
	cmp.b	#0,UpdateMenuNumber-V(a6)	; Check if we will only update one line.
	bne	.nolabel			; if so, skip printing label
	bsr	Print				; Print label of the menu
.nolabel:
	add.l	#4,a1				; Skip first row of itemlist as it was the label
	move.l	a1,a0				; Copy a1 to a0


	clr.l	d1				; Clear D1
	move.l	a0,a1


.loop:
	add.l	#1,d1				; Add 1 to D1 for number of entrys in list
	cmp.l	#0,(a1)+			; is A1 pointing to a 0?
	bne.s	.loop				; no, we are not at end of list if items in the menu.
	sub.l	#2,d1				; we ARE at end of itmes, and as we counted the last 0 aswell.. subtract with 2
						; d1 now contrains number of items in this menu.

	move.b	d1,MenuEntrys-V(a6)


	move.l	d1,d5				; Copy d1 to d5

	move.l	#20,d6				; Set d6 to X pos of text in menu
	move.l	#5,d7				; Set d7 to 5, where to start text on the meny on the Y pos

	move.l	a0,a1				; a1 is now list of items in menu
	clr.l	d4


.loop2:
	add.l	#1,d4
	move.l	(a1)+,a0

	cmp.b	#0,UpdateMenuNumber-V(a6)
	beq	.prnt
	cmp.b	UpdateMenuNumber-V(a6),d4	; Check if we just should update one line
	bne	.noprnt	
.prnt:
	move.l	d6,d0
	move.l	d7,d1
	bsr	SetPos				; Set position on screen for next item to be printed.
	move.l	#6,d1
	bsr	Print

.noprnt:
	cmp.l	#0,a2				; Check if A2 is 0.  if so, do not do anything with variables
	beq	.novar
						; OK, we have variables to be printed after the normal menuitem
						; A2 is a pointer to where a list of variables are located.
						; it is actually just a list if pointers to strings to be printed.
						; first word is color to print, next longword is pointer to string to be
						; printed.

	cmp.b	#0,UpdateMenuNumber-V(a6)
	beq	.prntvar
	cmp.b	UpdateMenuNumber-V(a6),d4	; Check if we just should update one line
	bne	.noprntvar
.prntvar:
	lea	SPACE,a0
	bsr	Print

	move.w	(a2),d1				; Set color
	move.l	2(a2),a0			; Set string
	cmp.l	#0,a0				; is A0 0? then skip printing
	beq	.novar
		
	bsr	Print				; Print it
.noprntvar:
	add.l	#6,a2				; add 6 to a2 for next varaibledata to print

.novar:
	add.l	#2,d7				; Add 2 to next row to print.
	dbf	d5,.loop2			; Print all items on the menu
	move.b	#1,UpdateMenuFlag-V(a6)
	move.b	#0,UpdateMenuNumber-V(a6)
.noprint:
						; ok we have printed the menu (or skipped it, depending on flag)
						; now lets see if it needs to be updated.
	clr.l	d7
	move.b	MenuEntrys-V(a6),d7
						; but to be sure, we add 1 to the result.
					
	clr.l	d0
	move.b	GetCharData-V(a6),d0

	cmp.b	#30,d0
	bne	.NoUp

	bsr	.Up
	bra	.NoKeyMove
	
.NoUp:
	cmp.b	#31,d0
	bne	.NoDown
	bsr	.Down
	bra	.NoKeyMove

.NoDown:
	cmp.b	#$a,d0
	bne	.NoEnter
	move.b	#1,MenuChoose-V(a6)

.NoEnter:


.NoKeyMove:


	move.w	CurAddY-V(a6),d7		; Load d7 with any value of added (lower) mousemovement
	cmp.w	#0,d7
	beq	.noadd				; no movements down...


	clr.w	MenuMouseSub-V(a6)		; ok we add, then clear any sub variable
	add.w	d7,MenuMouseAdd-V(a6)		; add it to mouseadd variable
	cmp	#40,MenuMouseAdd-V(a6)		; Check if we moved enough to bump menu one step
	blt	.noadd	

	clr.w	MenuMouseAdd-V(a6)
	bsr	.Down
	
.noadd:
	move.w	CurSubY-V(a6),d7
	cmp.w	#0,d7
	beq	.nosub

	clr.w	MenuMouseAdd-V(a6)
	add.w	d7,MenuMouseSub-V(a6)
	cmp.w	#40,MenuMouseSub-V(a6)
	blt	.nosub

	clr.w	MenuMouseSub-V(a6)
	bsr	.Up

.nosub:

	clr.l	d7
	move.b	MenuPos-V(a6),d7		; Load d7 with menupostin to highlight

	move.b	d7,MarkItem-V(a6)

	cmp.b	#0,PrintMenuFlag-V(a6)		; check if menu is printed
	bne	.forceupdate			; if so, also force update of the marked line etc

	cmp.b	OldMarkItem-V(a6),d7		; Compare the value with the old marked item
	beq	.noupdate			; no changes done, no updates needed.
.forceupdate:

	clr.l	d7
	move.b	OldMarkItem-V(a6),d7		; d7 now contains the number of the FORMERLY marked item.
	move.b	#6,d6				; Set Color
	bsr	.PrintItem			; print it.
	

	clr.l	d7
	move.b	MarkItem-V(a6),d7
	move.b	d7,OldMarkItem-V(a6)

	move.l	#13,d6
	bsr	.PrintItem


.noupdate:				
	clr.b	PrintMenuFlag-V(a6)		; ok, clear the print menu flag..  we do not want this to be printed again;
	
	POP
	rts


.Up:
	cmp.b	#0,MenuPos-V(a6)		; check if we already are at the top
	beq	.No
	sub.b	#1,MenuPos-V(a6)		; Move up one step
.No:	rts

.Down:
	clr.l	d7
	move.b	MenuEntrys-V(a6),d7
	cmp.b	MenuPos-V(a6),d7
	beq	.No
	add.b	#1,MenuPos-V(a6)
	rts


.PrintItem:					; Prints item on menu.
						; d7 = item to print
						; d6 = color to use when printing

	PUSH					
	move.w	MenuNumber-V(a6),d0		; Load what menunumber to print

	move.l	Menu-V(a6),a0			; Load a0 with pointer to list of menus.
	mulu	#4,d0				; multiply d0 with 4 to point on the correct item on list.
	add.l	d0,a0				; A0 now points on the correct item in the menulist
	move.l	(a0),a1				; A1 now contains the menuinfo.
	add.l	#4,a1				; Skip first item as it is the label anyway.

	move.l	d7,d2				; copy d1 to d2 so d2 also contains the item to highlight.
	mulu	#2,d2				; Multiply d2 with 2 to get the row to print the text on.

	move.l	#20,d0				; Load d0 with X Postition of menu
	move.l	#5,d1				; Load d1 with beginning of Y position
	add.l	d2,d1				; add number of lines for the item to update
	bsr	SetPos				; Set screenposition
	move.l	d7,d2				; copy d7 to d2
	mulu	#4,d2				; Multiply with 4, so we know what item in list to point to
	add.l	d2,a1				; add it to a1, a1 now points to pointer of string to update
	move.l	(a1),a0				; load A0 with actual string
	move.l	d6,d1				; Set color
	bsr	Print				; Print it.
	POP
	rts

STATUSPOS	equ	24
	
PrintStatus:
	move.l	#0,d0
	move.l	#STATUSPOS,d1
	bsr	SetPos
	lea	StatusLine,a0
	move.l	#3,d1
	bsr	Print
	rts

UpdateStatus:
	move.l	#8,d0				; Print Serialspeed
	move.l	#STATUSPOS,d1
	bsr	SetPos
	clr.l	d0
	move.w	SerialSpeed-V(a6),d0		; Get SerialSpeed value
	mulu	#4,d0				; Multiply with 4
	lea	SerText,a0			; Load table of pointers to different texts
	move.l	(a0,d0.l),a0			; load a0 with the value that a0+d0 points to (text of speed)
	move.l	#7,d1
	bsr	Print

	move.l	#25,d0				; Print CPU type
	move.l	#STATUSPOS,d1
	bsr	SetPos
	lea	CPU,a0
	move.l	#7,d1
	bsr	Print

	move.l	#39,d0				; Print Chipmem
	move.l	#STATUSPOS,d1
	bsr	SetPos
	move.l	TotalChip-V(a6),d0
	bsr	bindec
	move.l	#7,d1
	bsr	Print
	lea	KB,a0
	bsr	Print
	move.l	#56,d0
	move.l	#STATUSPOS,d1
	bsr	SetPos
	move.l	#7,d1
	move.l	TotalFast-V(a6),d0
	bsr	bindec
	bsr	Print
	move.l	#69,d0
	move.l	#STATUSPOS,d1
	bsr	SetPos
	move.l	a6,d0
	
	sub.l	#Endstack-Variables+4,d0
	
	bsr	binhex
	move.l	#7,d1
	bsr	Print

	rts


MainMenu:
	bsr	FilterON
	bsr	ClearScreen			; Clear the screen
	bsr	PrintStatus			; Print the statusline
	bsr	UpdateStatus			; Update "static" data of statusline
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	move.l	#Menus,Menu-V(a6)		; Set Menus as default menu. if different set another manually
	move.l	#0,MenuVariable-V(a6)
	move.w	#0,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)


	bra	MainLoop


InitScreen:
	bsr	ClearScreen
	bsr	PrintStatus
	bsr	UpdateStatus
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	rts

CheckMemory:
						; Checks memory
						; IN:
						;	D0 = Startaddress
						;	D1 = Endaddress
						;	D2 = 0=NORMAL Check NON 0=FAST Check (no bitchecks etc and no counting/errors)
						;	     2=NORMAL but no clear of detected memory etc, to be used to check another block.
						;
						; OUT:
						;	D0 = Number of errors


	cmp.l	d0,d1				; Check if we actually have memory to scan
	bls	.nomem

 ;	move.l	#"BEEF",$0 ; make sure address 0 is something we never check for.  for shadowramtests

	move.b	d2,CheckMemFast-V(a6)
	lea	CheckMemBitErrors-V(a6),a0
	move.l	#31,d6				; ok lets do this for all bits
.clearloop:
	clr.b	(a0)+
	dbf	d6,.clearloop
	lea	CheckMemByteErrors-V(a6),a0
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+

	cmp.b	#2,CheckMemFast-V(a6)		; Check if mode is 2=normal check but no clearing of some resultdata.
	beq	.continue			; if so. skip some clearing here

	lea	CheckMemErrors-V(a6),a0
	clr.l	(a0)				; now all data is cleared so old results doesnt show
	lea	CheckMemRow-V(a6),a0
	move.b	#13,(a0)
.continue:

	lea	CheckMemFrom-V(a6),a0

	move.l	d0,(a0)+			; Set startaddress
	move.l	d1,(a0)+			; Set endaddress
	clr.l	(a0)+				; clear current address
	cmp.b	#2,CheckMemFast-V(a6)
	beq	.continue2
	clr.l	(a0)+				; clear checked mem
	clr.l	(a0)+				; clear usable mem
	clr.l	(a0)+				; clear nonusable mem
	bra	.nocontinue			; ok this is the last part of "skippable" stuff if in continue mode.
.continue2:
	move.b	#0,CheckMemFast-V(a6)		; so now set the flag to 0 as in Normal mode.
	bsr	CheckMemNewRow			; Get next row for status
.nocontinue:
	lea	CheckMemType-V(a6),a0
	clr.b	(a0)
	lea	CheckMemOldType-V(a6),a0
	move.b	#$87,(a0)			; writing a crapnumber there.. so there will be a change first time
	

	clr.l	d0
	move.l	#3,d1
	bsr	SetPos
	lea	CheckMemRangeTxt,a0
	move.l	#7,d1
	bsr	Print				; Print checking memory from...


	clr.l	d0
	move.l	#5,d1
	bsr	SetPos
	lea	CheckMemCheckAdrTxt,a0
	move.l	#7,d1
	bsr	Print				; Print Checking address..


	cmp.b	#0,CheckMemFast-V(a6)		; Check if in fastmode
	bne	.fastmode			; if so.. skip som texts here

	lea	CheckMemBitErrTxt,a0
	move.l	#7,d1
	bsr	Print				; Print Bit error shows max....


	lea	CheckMemBitErrorsTxt,a0
	move.l	#3,d1				; Print Biterros and byte errors
	bsr	Print


	move.l	#53,d0
	move.l	#9,d1
	bsr	SetPos
	lea	CheckMemNumErrTxt,a0
	move.l	#3,d1
	bsr	Print				; Print "Number of errors"
	bra	.nofast
.fastmode:
	lea	CheckMemFastModeTxt,a0
	move.l	#2,d1
	bsr	Print


.nofast:
	move.l	#0,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemCheckedTxt,a0
	move.l	#6,d1
	bsr	Print

	move.l	#26,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemUsableTxt,a0
	move.l	#6,d1
	bsr	Print

	move.l	#52,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemNonUsableTxt,a0
	move.l	#6,d1
	bsr	Print

	move.l	#3,d1
	move.l	#21,d0
	bsr	SetPos
	lea	CheckMemFrom-V(a6),a0
	move.l	(a0),d0
	move.l	d0,d7
	bsr	binhex
	move.l	#6,d1
	bsr	Print				; Print startaddress of test

	move.l	#3,d1
	move.l	#34,d0
	bsr	SetPos
	lea	CheckMemTo-V(a6),a0
	move.l	(a0),d0
	move.l	d0,d6
	bsr	binhex
	move.l	#6,d1
	bsr	Print				; Print endaddress of test


	clr.l	d0
	move.l	#12,d1
	bsr	SetPos
	lea	DividerTxt,a0
	move.l	#4,d1
	bsr	Print

	move.l	d7,a0				; set A0 to startaddress
	move.l	d6,a1				; set A1 to endaddress
	sub.l	#8,a1

						; Lets do actual memorytesting
.checkloop:	

	cmp.b	#0,CheckMemNoShadow-V(a6)	; check if we should skip shadowmemtests
	bne	.notchip			; so go to "not chip" so we skip shadowtests on chipmem
	

	cmp.l	#$200000,a0
	bhi	.notchip			; check if scanned memory is within chipmem
						; ok we are in chipmem
						; so lets check if we have "shadow" memory. meaning we write at one address
						; is it readable on another. meaning we actually do not have any memory there



	cmp.l	#1024*1024,a0			; have we checked more then 1024kb of chipmem?
	blo	.nomorethen1024
						; ok we have checked more then 1024k
	move.l	a0,a2
	sub.l	#1024*1024,a2			; subtract 1MB to current address

	bsr	.checkshadow
	bra	.notchip
.nomorethen1024:

	cmp.l	#512*1024,a0			; have we checked more then 512kb of chipmem?
	blo	.nomorethen512
						; ok we have checked more then 512k
	move.l	a0,a2
	sub.l	#512*1024,a2			; subtract 512k to current address

	bsr	.checkshadow
	bra	.notchip
.nomorethen512:

	cmp.l	#256*1024,a0			; have we checked more then 256kb of chipmem?
	blo	.nomorethen256
						; ok we have checked more then 256k
	move.l	a0,a2
	sub.l	#256*1024,a2			; subtract 256k to current address

	bsr	.checkshadow

.nomorethen256:					; ok those tests could be "nicer" done...

.notchip:

	TOGGLEPWRLED

	lea	MEMCheckPattern,a2		; Load list of data to test.
	clr.l	d7				; Clear d7, as it will contain set bits of faliing bits

	lea	CheckMemChecked-V(a6),a3
	cmp.b	#0,CheckMemFast-V(a6)
	bne	.fastmode3
	add.l	#4,(a3)
	bra	.nofastmode3
.fastmode3:
	add.l	#1024,(a3)
.nofastmode3:

.checkpattern:
	move.l	(a0),d2				; Take a backup of what is in the memory for the moment
	move.l	(a2)+,d0

	move.l	d0,(a0)				; Write d0 to memoryaddress
	nop					; 040 will need this to write data to memory

	move.l	(a0),d1				; Read from memory and put into d1. (this will work in ROM mode, as cache is off)

.noerr:

	cmp.b	#0,CheckMemNoShadow-V(a6)	; check if we should skip shadowmemtests
	bne	.noshdw				; so we skip shadowtest


	cmp.l	$0,d0				; IF the data we are looking for is also on $0, then we are dealing
	bne	.noshdw				; with shadowram and should stop
	move.l	#"SHDW",d7
	bra	.finished
.noshdw:

	move.l	d2,(a0)				; Write back old data to the memory so we do not corrupt anything
	cmp.l	d0,d1				; Compare what we wrote with what we read..
	bne	.error				; If there was an error jump to .error

.aftererror:					; we are safe

	cmp.l	#0,d0				; was d0 = 0 then we are at the end of the memorytest-list
	bne	.checkpattern

						; Now d7 will contain 0 if memory was OK, if not. the bit with problem will
						; be set in d7

	lea	CheckMemCurrent-V(a6),a5
	move.l	a0,(a5)				; Write a0 to current address being checked.



	cmp.l	#0,d7				; Did we have an error on last run?
	beq	.noerror			; Nope, jump to noerror

						; OK we are in an errorcondition. (gahh! not good :))

						; so lets present type of error to the user. First bitwise.
						; and as we can only see up to $ff on screen we will only see max 255 errors
						; on bits. but hey.. then you atleast knows there are a problem.
					



	lea	CheckMemNonUsable-V(a6),a3
	cmp.b	#0,CheckMemFast-V(a6)		; check if we are in fastmode
	bne	.fastmode2
	add.l	#4,(a3)
	bra	.nofastmode2
	
.fastmode2:
	add.l	#1024,(a3)

.nofastmode2:
	cmp.b	#$ffffffff,d7			; did we have error on ALL bits? meaing a DEAD memory???
	bne.w	.nodead				;nope

	lea	CheckMemType-V(a6),a2
	move.b	#0,(a2)				; Write that we had an error
	bra	.wehaddead
.nodead:


	lea	CheckMemType-V(a6),a2
	move.b	#1,(a2)				; Write that we had an error

.wehaddead:

	lea	CheckMemErrors-V(a6),a2
	add.l	#1,(a2)

	lea	CheckMemBitErrors-V(a6),a2
	move.l	#31,d6				; ok lets do this for all bits
.loop:
	btst	d6,d7				; check if this bit had an error
	beq	.nobiterror
						; OK, we had an error.  lets step up the bitcounter
	clr.l	d0
	move.b	(a2),d0
	cmp.b	#255,d0				; is this already 255? then do not add any more
	beq	.nobiterror			; this name is wrong.. but anyway.. :)
	add.b	#1,(a2)				; add 1 to biterror
.nobiterror
	add.l	#1,a2				; use next address to store next biterror
	dbf	d6,.loop			; loop through all bits

	lea	CheckMemByteErrors-V(a6),a2
	move.l	d7,d1
	and.l	#$ff000000,d1
	cmp.l	#0,d1
	beq	.noerr1
	add.l	#1,(a2)
.noerr1:
	move.l	d7,d1
	and.l	#$00ff0000,d1
	cmp.l	#0,d1
	beq	.noerr2
	add.l	#1,4(a2)
.noerr2:
	move.l	d7,d1
	and.l	#$0000ff00,d1
	cmp.l	#0,d1
	beq	.noerr3
	add.l	#1,8(a2)
.noerr3:
	move.l	d7,d1
	and.l	#$000000ff,d1
	cmp.l	#0,d1
	beq	.noerr4
	add.l	#1,12(a2)
.noerr4:

	bra	.notusable			; Just to skip adding of usable memory
.noerror:

	cmp.b	#0,CheckMemFast-V(a6)		; check if we are in fastmode
	bne	.infast1


	lea	CheckMemUsable-V(a6),a3
	add.l	#4,(a3)

	lea	CheckMemType-V(a6),a2
	move.b	#2,(a2)				; Write that we had an usable block of memory
	bra	.notinfast1
.infast1:					; We are in fastmode, we actually only test every longword every 1KB.
	lea	CheckMemUsable-V(a6),a3		; not much as memorytest, more like a scan where there is memory..
	add.l	#1024,(a3)

	lea	CheckMemType-V(a6),a2
	move.b	#2,(a2)				; Write that we had an usable block of memory
	bra	.notinfast1

.notinfast1:
.notusable:
	
	cmp.l	a1,a0				; Checked all memory?
	bhi	.finished			; Yes


	cmp.b	#0,CheckMemFast-V(a6)		; check if we are in fastmode
	bne	.infast2

	add.l	#4,a0				; Add 4 to a0 so we check the next longword later
	bra	.notinfast2
.infast2:
	add.l	#1024,a0			; Add 1024 to a0 so we check the "next" longword later, being in fastmode

.notinfast2:

	bsr	GetMouse
	cmp.b	#1,BUTTON-V(a6)			; Check mouse during check, if pressed cancel.  but we do NOT check
	beq	.break				; keyboard and mouse so it doesnt affect speed

	move.l	a0,d0
	divu	#32768,d0			; divide with 32768, if answer is even we have a new 32k block. update status
	swap	d0
	cmp.w	#0,d0
	beq	.update
						; Check if type of memory has been changed, if so force a screenupdate
	lea	CheckMemType-V(a6),a4
	move.b	(a4),d0				; d0 now contains what the type of memory was
	lea	CheckMemOldType-V(a6),a5
	move.b	(a5),d1				; d1 now contains what the former type of memory was. (type=good or not)

	cmp.b	d0,d1				; compare.. do we have a change?
	beq	.noupdate			; if no change.. go to nochange

.update:

	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)			; Check mouse AND keyboard/serial if anything pressed if so cancel
	beq	.break
	bsr	CheckMemoryUpdate		; Update text with memorylocation etc

.noupdate:
	bra	.checkloop

.break:
	bsr	WaitReleased
	
.finished:

	lea	CheckMemType-V(a6),a5
	move.b	#255,(a5)			; write anything that is not in the type. forcing it to update.

	lea	CheckMemCurrent-V(a6),a5
	sub.l	#1,(a5)				; Subtract current address with 1 to show the end.. for a "nicer" look

	bsr	CheckMemoryUpdate		; Update final status of memorycheck
	cmp.l	#"SHDW",d7			; did we exit due to shadow??
	bne	.noshadowmem			; nahhh

	bsr	CheckMemNewRow

	lea	CheckMemRow-V(a6),a0		; Get row.
	clr.l	d1
	move.b	(a0),d1
	clr.l	d0
	move.l	#28,d1
	bsr	SetPos

	lea	MemtestShadowTxt,a0
	move.l	#3,d1
	bsr	Print

.noshadowmem:
.nomem:
	PWRLEDON	

	rts

.error:						; OK, we have a memoryerror. lets break it down and analyze the error.
						; d0 contains what was written
						; d1 contains what was read

	move.l	#31,d6				; We will check 31+1 bits (longword)
.bitloop:
	btst	d6,d0				; Check bit at d6 with d0
	bne	.setread
	clr.l	d2				; we clear d2 as in bit is 0
	bra	.notsetread
.setread:
	move.l	#1,d2				; set it as set.
.notsetread:
						; d2 now contains 0 if bit was not set, 1 if it was set
	btst	d6,d1
	bne	.setwrite
	clr.l	d3
	bra	.notsetwrite
.setwrite:
	move.l	#1,d3
.notsetwrite:	
	cmp.l	d2,d3
	bne	.notsame
	dbf	d6,.bitloop
	bra	.errordone
.notsame:
	bset	d6,d7
	dbf	d6,.bitloop
.errordone:
	bra	.aftererror

.checkshadow:
	move.l	(a0),d7				; make a backup of what is in address now
	move.l	#"SHD!",(a0)			; write TEST to current testaddress
	cmp.l	#"SHD!",(a2)			; is it readable on "shadow"
	beq	.shadow				; YES! we DO have a shadow!
	move.l	d7,(a0)
	bra	.noshadow
	
.shadow:					; We have Shadowmemory.. lets stop the test afterall.
	move.l	d7,(a0)
	move.l	#"SHDW",d7			; Write a nonsensestring to d7..
	bra	.finished
.noshadow:
	rts


CheckMemoryUpdate:				; Update text on screen while checking memory

	PUSH


	move.l	#18,d0
	move.l	#5,d1
	bsr	SetPos
	lea	CheckMemCurrent-V(a6),a0	; Print current address to test
	move.l	(a0),d0
	move.l	d0,d7				; Store current address to D7 aswell
	add.l	#4,d0				; Add 4 just to show a more "even" address
	bsr	binhex
	move.l	#7,d1
	bsr	Print				; Print current position of test

	lea	CheckMemTypeChange-V(a6),a1
	clr.b	(a1)				; Just to be sure. clear that we had a change of type

	lea	CheckMemType-V(a6),a0
	move.b	(a0),d0				; d0 now contains what the type of memory was
	lea	CheckMemOldType-V(a6),a1
	move.b	(a1),d1				; d1 now contains what the former type of memory was. (type=good or not)

	move.l	#$fe,d5				; set d5 to $fe telling stuff that we did not have a change..


	cmp.b	d0,d1				; compare.. do we have a change?
	beq	.nochange			; if no change.. go to nochange
						; ok there was a change of blocktype.. (good, bad etc)

	move.b	d0,(a1)				; store the current type to oldtype

	
	lea	CheckMemTypeChange-V(a6),a2
	move.b	#1,(a2)				; Write 1 to tell that there was a change of type.

.scanagain:
	lea	CheckMemTypeStart-V(a6),a0
	cmp.l	#0,(a0)				; if start is 0 we have a new block. if not we are at the end of that block
	beq	.notatend

	move.l	#1,d5				; if d5 is 1.. we are at the end of the block

	bra	.startendsorted	
						; ok we are at the start of the block.
						; d0 still contains type of block.


.notatend:

	lea	CheckMemCurrent-V(a6),a1
	move.l	(a1),d7				; as we can be looped, we are not sure that d7 actually contains the start anymore
						; so better reload it
						; ok we are at the beginning of the block....
	move.l	d7,(a0)				; store the beginning
	clr.l	d5				; d5 is cleared. we are at the beginning of the block


						; As we are in the beginning if the block. lets find out what type of block
						; and set the correct color

	lea	CheckMemType-V(a6),a1
	move.b	(a1),d0				; d0 now contains what the type of memory was


	lea	CheckMemCol-V(a6),a1

	cmp.b	#2,d0				; check if we are type 2 (good)
	bne	.nogood				; nope
.notend:
	move.b	#2,(a1)				; write 2 as color to print
	bra	.gooddone

.nogood:
	cmp.b	#0,d0
	bne.s	.bad				; well not dead either
						; so it is not good or bad. so it is dead....
	move.b	#5,(a1)
	bra	.gooddone
.bad:	
	move.b	#1,(a1)				; write 1 as color to print
	bra	.gooddone			; well. label is somewhat wrong
	
.gooddone:

.startendsorted:

	cmp.b	#255,d0				; are we at the end?
	bne	.notendofscan

	move.b	#255,d5				; we was at the end.. so set d5 to 255

.notendofscan:

	lea	CheckMemCol-V(a6),a1

	clr.l	d6
	move.b	(a1),d6				; color to actually print on


	clr.l	d0				; Clear d0 so it is clear before setpos
	clr.l	d1				; clear d1 aswell

	lea	CheckMemRow-V(a6),a0		; Get what row to print string on
	move.b	(a0),d1				; Set Y pos to that row
	bsr	SetPos				; Set pos of screen

	cmp.b	#5,d6				; check if we print with "dead" color
	bne	.notdead

	lea	CheckMemDeadTxt,a0
	move.l	d6,d1
	bsr	Print
	bra	.notbad

.notdead:
	cmp.b	#2,d6				; check if we print with red color"
	bne	.badblk

	lea	CheckMemGoodTxt,a0
	move.l	d6,d1
	bsr	Print				; Print "Good block.."
	bra	.notbad
.badblk:
	lea	CheckMemBadTxt,a0
	move.l	d6,d1
	bsr	Print				; Print "Bad block.."
	bra	.notbad
	
.notbad:
	lea	CheckMemTypeStart-V(a6),a0
	move.l	(a0),d0
	move.l	d0,d4				; store current position to d4 for later use..
	bsr	binhex
	move.l	d6,d1
	bsr	Print				; Print address

	cmp	#0,d5				; is d5 clear?
	beq	.nochange			; yes. we are at the begining of the block.. no more update to do..
						; no..  we are at the end

	lea	CheckMemEndAtTxt,a0		; print "and ends at"
	move.l	d6,d1
	bsr	Print



	cmp.b	#$ff,d5				; end?
	bne	.nottheend
	add.l	#5,d7

.nottheend:
	move.l	d7,d0				; copy current pos to d0
	sub.l	#1,d0				; Subtract with 1 to show address of last working byte.
	bsr	binhex
	move.l	d6,d1
	bsr	Print				; Print endaddress


	lea	CheckMemSizeOfTxt,a0		; print "with a size of"
	move.l	d6,d1
	bsr	Print


	lea	CheckMemTypeStart-V(a6),a0
	move.l	(a0),d0				; Get startaddress of this block

	sub.l	d0,d7				; d7 now contains total size of this block
	move.l	d7,d0

	asr.l	#8,d0
	asr.l	#2,d0				; Divide d0 with 1024 so we know how much memory in kb we got

	bsr	bindec
	move.l	d6,d1
	bsr	Print				; Print out number of KB
	

	move.l	d6,d1
	lea	KB,a0
	bsr	Print				; Print "KB" text


	lea	CheckMemTypeStart-V(a6),a2
	clr.l	(a2)				; clear the startaddress. as we had a change


.nochange:


	cmp.b	#0,CheckMemFast-V(a6)		; check if we are in fastmode
	bne	.fastmode

	move.l	#12,d0				; Set cursor at beginning of biterror
	move.l	#8,d1
	bsr	SetPos

	lea	CheckMemBitErrors-V(a6),a5


	move.l	#3,d6
.bitloop2:
	move.l	#7,d7
.bitloop:
	clr.l	d0
	move.b	(a5)+,d0
	move.l	#2,d1				; Set for Green color
	cmp.b	#0,d0
	beq	.noerr
	move.l	#1,d1				; we had an error, set for red color
.noerr:	
	bsr	binhexbyte
	bsr	Print
	dbf	d7,.bitloop
	move.b	#" ",d0
	bsr	PrintChar
	dbf	d6,.bitloop2			; Loop so we print 4 chunks of bitdata

	lea	CheckMemByteErrors-V(a6),a5
	move.l	#3,d2
	move.l	#13,d6				; set X pos of text
.byteloop:
	move.l	d6,d0				; Set X pos
	move.l	#9,d1				; Set Y pos
	bsr	SetPos

	move.l	(a5)+,d0
	move.l	#2,d1				; Set for green color
	cmp.l	#0,d0
	beq	.noerr2
	move.l	#1,d1				; We had an error, set color to red
.noerr2:
	bsr	bindec
	bsr	Print
	move.b	#" ",d0
	bsr	PrintChar
	add.l	#10,d6
	dbf	d2,.byteloop			; Loop and print 4 longwords of errordata


	move.l	#71,d0
	move.l	#9,d1
	bsr	SetPos
	move.l	#1,d1
	lea	CheckMemErrors-V(a6),a0
	move.l	(a0),d0
	move.l	#2,d1
	cmp.l	#0,d0
	beq	.noerr3
	move.l	#1,d1
.noerr3:
	bsr	bindec
	bsr	Print
.fastmode:
	move.l	#16,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemChecked-V(a6),a0
	move.l	(a0),d0
	asr.l	#8,d0
	asr.l	#2,d0

	bsr	bindec
	move.l	#7,d1
	bsr	Print
	lea	KB,a0
	bsr	Print				; Print how much memory is tested

	move.l	#41,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemUsable-V(a6),a0
	move.l	(a0),d0
	asr.l	#8,d0
	asr.l	#2,d0

	bsr	bindec
	move.l	#7,d1
	bsr	Print
	lea	KB,a0
	bsr	Print				; Print how mush memory is usable

	move.l	#70,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemNonUsable-V(a6),a0
	move.l	(a0),d0
	asr.l	#8,d0
	asr.l	#2,d0


	bsr	bindec
	move.l	#7,d1
.nonousableprint:
	bsr	Print
	lea	KB,a0
	bsr	Print				; Print hos much memory is not usable


	cmp.b	#0,d5				; check if we was at the end of the scan
	beq	.endofscan
						; ok we is not at the end of the scan. and we had a typedifference.
						; so we have to do this all again on a new row.

	cmp.b	#$fe,d5				; check if we didnt have a change of type
	beq	.endofscan

	cmp.b	#$ff,d5				; check if we was at the end of memoryscan
	beq	.endofscan

	lea	CheckMemTypeStart-V(a6),a0

	clr.l	(a0)				; first clear the startaddress. so the routine handles it as a new happening

	bsr	CheckMemNewRow

	lea	CheckMemTypeChange-V(a6),a1
	cmp.b	#1,(a1)				; did we have a change of type? if so we have to do this all over again.
	bne	.endofscan			; no. we did not have a change of type
						; yes we had
	clr.b	(a1)				; to avoid an eternal loop. clear the changeflag
	bra	.scanagain			; do it all again
.endofscan:

	POP
	rts

CheckMemNewRow:
	lea	CheckMemRow-V(a6),a0		; Get row.
	clr.l	d0
	move.b	(a0),d0
	cmp.b	#30,d0
	bne	.notlastrow
	move.b	#13,(a0)			; we reaced last row. .so start from the beginning again
	bra	.rowdone
.notlastrow:
	add.b	#1,(a0)				; write the stuff on the next row
.rowdone:	
	rts


	
DetectMBFastmem:				; A very fast detection of fastmem made for startup before stackusage etc.
						; INdata:
						; d1 = total block of known working 16Kb fastmem blocks. (CLEAR before first usage)
						; d2 = size of memory found at a0 (CLEAR before fist usage) (in number of 16k blocks)
						; a0 = First usable address (CLEAR before first usage)
						; a1 = First address to scan
						; a2 = Address to end scan
						; a3 = adress to jump to after we are done with this routine
						; 
						; Detection is done that it checks one longword every 16k and assumes a working 16k block if successful)

	clr.l	d3				; total size of memory found in this scan
	clr.l	d4
	clr.l	d5				; Will contain first memoryadress found
	move.l	#.nomemneeded,$8
.loop1:
	lea	MEMCheckPattern,a5		; list of memcheck pattern
	add.b	#4,d4				; just add a number, d4 is only for screenflash when a good longword is found
.loop:
	move.l	(a5)+,d7			; load next pattern to d7
	move.l	d7,(a1)				; write d7 to memoryaddress to check
	move.b	d7,color0
	nop					; needed for 040
	move.l	(a1),d6				; read the same address to d6
	cmp.l	d6,d7				; compare if they are the same
	bne	.checknext			; if not. go to check next block
	cmp.l	#0,d7				; Check if d7 was 0, meaning we are done with out check of this longword
	bne	.loop

	move.b	d4,color1			; just to make somewhat coloreffect onscreen so user can see that something is happening

	cmp.l	#0,d5				; check if this is the first memoryblock we found that are working
	bne	.notfirst			; nope, not first block
	move.l	a1,d5				; store the current address to a5 as it is the first working address
.notfirst:
	add.l	#1,d3				; Add 1 to d3 for a working block
.checknext:
	adda.l	#16384,a1			; add 16k to a1 for next memoryblock to scan
	cmp.l	a1,a2				; check if we are finished
	bgt	.loop1				; OK, we are not finished. lets check next block

						; OK  we are done with checking everyting
	cmp.l	#0,a0				; check if a0 is 0, if not we already have memory that are usable
	bne	.nomemneeded
						; ok we had no working memory, lets tell what memory we have
	cmp.l	#0,d5				; check if we actually did find any memory atall?
	beq	.nomemneeded			; ok fuck it, we did not find any memory anyway

	move.l	d5,a0				; we found memory and no memory detected before that. so make this detected
						; memory as found block
	move.l	d3,d2				; also store size of this block

.nomemneeded:
	add.l	d3,d1				; add this detected blocksize of total size of fastmem
	move.l	#POSTBusError,$8
	jmp	(a3)				; we are done.  jump to what a3 points to.

	
DetectMem:
						; Detects memory
						; Indata:
						; a0 = Startadress.. or actually END of block as it scans backwards.
						; a1 = Endadress (or.. startadress)
						; Outdata:
						; d0 = Total amoumt of memory found (caluclated from 16Kb blocks)
						; d1 = if anything then 0, total memory was found in several blocks.
						; (like: you have  bad simm, placed wrong or so...)
						; a0 = first memoryaddress
						; a1 = last memoryaddress

			
						; (as the Amiga assigns memory that way)

	PUSH
	clr.l	d0				; Clear total amount of memory
	clr.l	d1				; Clear the "several block" flag
	clr.l	d3				; if 0, no memory found yet
	clr.l	d4				; Tempvariable holding the last working memaddress
	clr.l	d5				; Tempvariable holding the first working memaddress (last. scanning backwards)
	

	move.l	a0,a3				; Make a backup of the lowest memoryaddress
	cmp.l	#$ffffff,a1			; Check if testadress is above the 24bit limit
	ble	.check				; no, jump to check

	move.l	$700,d2				; Make a backup of $700
	clr.l	$700				; Clear $700 to be sure
	move.l	#"24BT",$4000700		; Write "24BT" to highmem
	cmp.l	#"24BT",$700			; IF memory is readable at $700 instead. we are using a cpu with 24 bit adress. no memory to detect this time
	beq	.24bitcpu
	move.l	d2,$700				; Restore $700 again

.check:
	suba.l	#$4000,a1			; Check next block of 16K of memory
	move.l	(a1),d2				; Backup data in position to test

	clr.l	d7				; should return 0 if there was no errors.
	lea	MEMCheckPattern,a4
.loop:
	move.l	(a4)+,d6
	move.l	d6,(a1)
	nop
	cmp.l	(a1),d6
	beq	.noerror
	move.b	#1,d7				; Mark that we had an error
.noerror:
	cmp.l	#0,d6				; Was last value a 0? if so, this longword is fully checked
	bne.s	.loop				; no, test some more
	move.l	d2,(a1)				; Restore backup of data to address

	cmp.b	#1,d7
	beq	.error				; If we had an error, handle it


	move.l	a1,d4				; OK, we had no error, meaning this is working memory
						; So store this address in d4
						
	cmp.b	#1,d3				; Check if we had working memory before
	beq	.yesmem				; yes we had
	move.b	#1,d3				; Mark that we now have memory
	move.l	a1,d5				; And store at what memory this segments ends. (yes we scan backwards)
	
.yesmem:

	add.l	#1,d0				; ok, no error, so we had memory. add one to block
.nomem:
	cmp.l	a0,a1				; Check if we scanned the whole block
	bge	.check				; no, scan more
.done:
	move.l	d0,temp-V(a6)			; Store size
	move.l	d4,temp+4-V(a6)			; Store firstmemaddress
	move.l	d5,temp+8-V(a6)			; Store last memaddress
	move.l	a3,temp+12-V(a6)		; Store the first WANTED memaddress to scan

						; lets change it to the lowest address we wanted to test
	POP					; Restore all registers
	move.l	temp-V(a6),d0
	asl.l	#6,d0
	asl.l	#8,d0
	move.l	temp+4-V(a6),a0
	move.l	temp+8-V(a6),a1
	cmp.l	temp+12-V(a6),a0		; Check is first memoryaddress is in a lower address than wanted
						; meaning that the 16K chunk was too big
	bgt	.notlower

	PUSH

	move.l	temp+12-V(a6),d1
	move.l	a0,d2
	sub.l	d2,d1				; D1 is now the difference between address we got and the real one
	move.l	d1,temp+8-V(a6)			; Lets store it as temp
	
	TOGGLEPWRLED			; So lets correct it
	move.w	#$fff,color0
	POP
	move.l	temp+12-V(a6),a0		; Lets put the lowest address to check as address of detected mem
	sub.l	temp+8-V(a6),d0			; Lets subtract sizedifference to size found

.notlower:

	rts

.error:						; OK we had an error in check
	cmp.b	#1,d3				; did we have memory detected before?
	bne	.nomem				; no, so scan for some
	beq	.done				; ok we had memory, this is the end (or beginning of it)
						; so stop.
						

.24bitcpu:					; OK we had a 24bit cpu and wanted to check memory above 24bit.
						; give null as answer
	POP
	clr.l	d0
	lea	$0,a0
	lea	$0,a1
	rts


WaitButton:					; Waits until a button is pressed AND released
	bsr	WaitPressed
	bsr	WaitReleased
	rts


WaitPressed:					; Waits until some "button" is pressed
	clr.l	d7				; Clear d7 that is used for a timeout counter
.loop:
					; if we are in rommode, do timeout code..
	add.l	#1,d7				; Add 1 to the timout counter
	cmp.l	#$ffff,d7			; did we count for a lot of times? well then there is a timeout
	beq	.timeout
		
	bsr	GetInput			; get inputdata
	cmp.b	#1,BUTTON-V(a6)			; check if any button was pressed.
	bne	.loop				; nope. lets loop
	rts
.timeout:
	rts
	move.b	P1LMB-V(a6),STUCKP1LMB-V(a6)	; ok we had a timeout. so we GUESS a port is stuck.
	move.b	P2LMB-V(a6),STUCKP2LMB-V(a6)	; if we just simply copy the status of all keys
	move.b	P1LMB-V(a6),STUCKP1LMB-V(a6)	; to the STUCK version. we will disable all stuck ports
	move.b	P2RMB-V(a6),STUCKP2RMB-V(a6)
	move.b	P1MMB-V(a6),STUCKP1MMB-V(a6)
	move.b	P2MMB-V(a6),STUCKP2MMB-V(a6)
	rts

WaitReleased:					; Waits until some "button" is unreleased

	clr.l	d7				; Clear d7 that is used for a timeout counter
.loop:
		
	move.b	slowcia,color0
	move.b  #0,color0
	add.l	#1,d7				; Add 1 to the timout counter
	cmp.l	#$ffff,d7			; did we count for a lot of times? well then there is a timeout
	beq	.timeout
		
	bsr	GetInput			; get inputdata
	cmp.b	#0,BUTTON-V(a6)			; check if any button was pressed.
	bne	.loop				; nope. lets loop
	rts
.timeout:
	move.b	P1LMB-V(a6),STUCKP1LMB-V(a6)	; ok we had a timeout. so we GUESS a port is stuck.
	move.b	P2LMB-V(a6),STUCKP2LMB-V(a6)	; if we just simply copy the status of all keys
	move.b	P1LMB-V(a6),STUCKP1LMB-V(a6)	; to the STUCK version. we will disable all stuck ports
	move.b	P2RMB-V(a6),STUCKP2RMB-V(a6)
	move.b	P1MMB-V(a6),STUCKP1MMB-V(a6)
	move.b	P2MMB-V(a6),STUCKP2MMB-V(a6)
	rts


;------------------------------------------------------------------------------------------


AudioMenu:
	bsr	InitScreen
	move.w	#2,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

AudioSimple:

	bsr	ClearScreen
	move.w	#0,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	move.l	#AudioSimpleMenu,Menu-V(a6)	; Set different menu

						;	OK we have variables to handle here
	move.l	a6,d0
	lea	AudSimpChan1-V(a6),a0

	add.l	#AudSimpVar-V,d0
	move.l	d0,MenuVariable-V(a6)

						; ok lets populate this with default values.
	move.b	#0,(a0)+
	move.b	#0,(a0)+
	move.b	#0,(a0)+
	move.b	#0,(a0)+
	move.b	#64,(a0)+
	move.b	#12,(a0)+
	move.b	#1,(a0)+
	move.b	#0,(a0)+
 
	bsr	.setvar
.loop:
	bsr	.Playaudio

	bsr	PrintMenu
	bsr	GetInput
	bsr	WaitLong
	cmp.b	#0,d0
	beq	.no


	move.b	keyresult-V(a6),d1		; Read value from last keyboardread
	cmp.b	#$a,d1				; if it was enter, select this item
	beq	.action
	move.b	Serial-V(a6),d2			; Read value from last serialread
	cmp.b	#$a,d2
	beq	.action
	cmp.b	#1,LMB-V(a6)
	beq	.action

	lea	AudioSimpleWaveKeys,a5		; Load list of keys in menu
	clr.l	d0				; Clear d0, this is selected item in list

.keyloop:
	move.b	(a5)+,d3				; Read item
	cmp.b	#0,d3				; Check if end of list
	beq	.nokey
	cmp.b	d1,d3				; fits with keyboardread?
	beq	.goaction
	cmp.b	d2,d3				; fits with serialread?
	beq	.goaction				; if so..  do it
	add.l	#1,d0				; Add one to d0, selecting next item
	bra	.keyloop
.goaction:
	move.b	d0,MenuPos-V(a6)
	bra	.action

.nokey:	
	cmp.b	#1,RMB
	beq	Exit
	btst	#1,d0
	beq	.no

.action:
	clr.l	d0
	move.b	MenuPos-V(a6),d0
	cmp.b	#0,d0
	beq	.chan1
	cmp.b	#1,d0
	beq	.chan2
	cmp.b	#2,d0
	beq	.chan3
	cmp.b	#3,d0
	beq	.chan4
	cmp.b	#4,d0
	beq	.vol
	cmp.b	#5,d0
	beq	.wave
	cmp.b	#6,d0
	beq	.filter
	cmp.b	#7,d0
	beq	.exit

	


.no:
	bra	.loop

.setvar:
	move.l	a6,a0
	move.l	a6,a1
	add.l	#AudSimpChan1-V,a0	
	add.l	#AudSimpVar-V,a1

	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer
	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer
	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer
	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer

	clr.l	d0
	move.b	(a0)+,d0			; Get Volume

	lea	AudSimpVolStr-V(a6),a2
	move.w	#3,(a1)+
	move.l	a2,(a1)+	
	PUSH	
	bsr	bindec
	move.l	#7,d0				; Lets copy output to a safe location
.setvarloop:
	move.b	(a0)+,(a2)+
	dbf	d0,.setvarloop
	POP
	add.l	#1,a0	
	move.w	#2,(a1)+			; Write color
	lea	AudSimpWave-V(a6),a2
	clr.l	d1
	move.b	(a2),d1
	asl.l	#2,d1
	lea.l	AudioName,a2
	move.l	(a2,d1.w),(a1)+			; Write Stringpointer


	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer
	rts

.Playaudio:
	clr.l	d0
	move.b	AudSimpWave-V(a6),d0
	move.l	d0,d1
	mulu	#2,d1
	mulu	#4,d0
	
	lea	AudioPointers,a2
	move.l	a6,a0
	add.l	#AudioWaves-V,a0
	add.l	(a2,d0.l),a0

	lea	AudSimpChan1-V(a6),a1
	move.l	a0,$dff0a0			;Wave
	move.l	a0,$dff0b0			;Wave
	move.l	a0,$dff0c0			;Wave
	move.l	a0,$dff0d0			;Wave


	cmp.b	#0,(a1)+
	beq	.noch1

	move.w	#64,$dff0a8			;volume
	lea	AudioLen,a2
	move.w	(a2,d1),$dff0a4			;number of words
	lea	AudioPer,a2
	move.w	(a2,d1),$dff0a6
	move.w	#$8201,$dff096
	bra	.checkch2
.noch1:
	move.w	#$1,$dff096
	
.checkch2:

	cmp.b	#0,(a1)+
	beq	.noch2

	move.w	#64,$dff0b8			;volume
	lea	AudioLen,a2
	move.w	(a2,d1),$dff0b4			;number of words
	lea	AudioPer,a2
	move.w	(a2,d1),$dff0b6			;frequency
	move.w	#$8202,$dff096
	bra	.checkch3
.noch2:
	move.w	#$2,$dff096
	
.checkch3:
	cmp.b	#0,(a1)+
	beq	.noch3

	move.w	#64,$dff0c8			;volume
	lea	AudioLen,a2
	move.w	(a2,d1),$dff0c4			;number of words
	lea	AudioPer,a2
	move.w	(a2,d1),$dff0c6			;frequency
	move.w	#$8204,$dff096
	bra	.checkch4
.noch3:
	move.w	#$4,$dff096
	
.checkch4:

	cmp.b	#0,(a1)+
	beq	.noch4

	move.w	#64,$dff0d8			;volume
	lea	AudioLen,a2
	move.w	(a2,d1),$dff0d4			;number of words
	lea	AudioPer,a2
	move.w	(a2,d1),$dff0d6			;frequency
	move.w	#$8208,$dff096
	bra	.checkdone
.noch4:
	move.w	#$8,$dff096
	
.checkdone:

	rts


.chan1:
	bchg	#0,AudSimpChan1-V(a6)
	move.b	#1,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop



.chan2:
	bchg	#0,AudSimpChan2-V(a6)
	move.b	#2,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop



.chan3:
	bchg	#0,AudSimpChan3-V(a6)
	move.b	#3,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop




.chan4:
	bchg	#0,AudSimpChan4-V(a6)
	move.b	#4,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop

.vol:
	move.l	a6,a0
;	add.l	#AudSimpVol-V,a0
	move.w	#4,(a0)+
	move.l	#OFF,(a0)+
	move.b	#5,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop

.wave:
	TOGGLEPWRLED
	clr.l	d7
	move.b	AudSimpWave-V(a6),d7

	cmp.b	#17,d7
	beq	.notmax
	add.b	#1,d7
	bra	.wave2
.notmax:
	clr.l	d7
.wave2:
	move.b	d7,AudSimpWave-V(a6)

	move.b	#6,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop

.filter:
	bchg	#0,AudSimpFilter-V(a6)
	btst	#0,AudSimpFilter-V(a6)
	beq	.off
	;bclr	#1,$bfe001	
	bra	.on
.off:
	;bset	#1,$bfe001
.on:
	move.b	#7,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop


.exit:
	move.w	#15,$dff096
	bsr	WaitReleased

	move.l	#Menus,Menu-V(a6)		; Set Menus as default menu. if different set another manually
	move.l	#0,MenuVariable-V(a6)
	bra	AudioMenu

CheckKeyReleased:
	bsr	GetInput
	btst	#1,d0
	bne.s	CheckKeyReleased
	rts

CheckOnOff:					; Checks if a0 is pointing to a variable that is on or off
						; OUTPUT =   D0 = Color
						;	     D1 = Address of String
			
	cmp.b	#0,(a0)+
	bne	.on
	move.l	#1,d0
	move.l	#OFF,d1
	rts
.on:
	move.l	#2,d0
	move.l	#ON,d1
	rts
	

AudioMod:
	bsr	FilterOFF

	bsr	ClearScreen
	lea	AudioModStatData-V(a6),a1	; Get statusvariable
	clr.l	(a1)+

	bset	#1,(a1)+			; Set Default filter off
	move.b	#64,(a1)+			; Set Default MasterVolume
	clr.w	(a1)+
	move.l	#-1,(a1)+
	move.l	#-1,(a1)			; and the "former" values aswell
						; but to something that never can happen
						; forcing an update first run
	lea	AudioModTxt,a0
	move.l	#2,d1
	bsr	Print


	move.l	#EndMusic-Music,d0
	bsr	GetChip				; Get memory for module

	cmp.l	#0,d0				; if it is 0, no chipmem avaible
	bne	.chip

	move.l	#1,d1
	lea	NoChiptxt,a0
	bsr	Print				; We did not have enough chipmem
	bra	.exit

.chip:

	cmp	#1,d0
	bne	.enough

	move.l	#1,d1
	lea	NotEnoughChipTxt,a0
	bsr	Print
	bra	.exit

.enough:

	move.l	d0,AudioModAddr-V(a6)		; Store address of module
	move.l	d0,AudioModData-V(a6)

	lea	AudioModCopyTxt,a0
	move.l	#3,d1
	bsr	Print


	move.l	AudioModAddr-V(a6),a0
	move.l	#EndMusic-Music,d0		; get size of module
	asr.l	#2,d0				; Divide by 4 to get number of longwords
	lea	Music,a1			; Get address where module is in ROM
.loop:
	move.l	(a1)+,(a0)+
	dbf	d0,.loop			; Copy module into chipmem



	move.l	#2,d1
	lea	Donetxt,a0
	bsr	Print

	lea	AudioModInitTxt,a0
	move.l	#3,d1
	bsr	Print


	move.l	AudioModAddr-V(a6),a0
	
	move.l	AudioModInit-V(a6),a1
	lea	$dff000,a5
	jsr	(a1)				; Call MT_Init

	lea	Donetxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	AudioModMVol-V(a6),a0
	move.b	#4,(a0)				; Set Mastervolume

	lea	AudioModName,a0
	move.l	#3,d1
	bsr	Print

	move.l	AudioModAddr-V(a6),a0
	move.l	#5,d1
	bsr	Print

	lea	AudioModInst,a0
	move.l	#3,d1
	bsr	Print

	move.l	AudioModAddr-V(a6),a1
	add.l	#20,a1
	move.l	#1,d7
	move.l	#15,d6
	move.l	#7,d5
.instloop:
	clr.l	d0
	move.l	d5,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binhexbyte
	move.l	#2,d1
	bsr	Print
	add.l	#1,d7

	lea	SpaceTxt,a0
	bsr	Print

	move.l	a1,a0
	move.l	#5,d1
	bsr	Print
	add.l	#30,a1

	move.l	#40,d0
	move.l	d5,d1
	bsr	SetPos
	move.l	d7,d0
	cmp.l	#$20,d0
	beq	.noprint
	bsr	binhexbyte
	move.l	#2,d1
	bsr	Print
	lea	SpaceTxt,a0
	bsr	Print

	move.l	a1,a0
	move.l	#5,d1
	bsr	Print

	add.l	#30,a1

	add.l	#1,d7

.noprint:
	lea	NewLineTxt,a0
	bsr	Print
	add.l	#1,d5
	dbf	d6,.instloop

	lea	NewLineTxt,a0
	bsr	Print

	lea	AudioModPlayTxt,a0
	move.l	#3,d1
	bsr	Print

	lea	AudioModOptionTxt,a0
	move.l	#3,d1
	bsr	Print

	lea	AudioModEndTxt,a0
	move.l	#3,d1
	bsr	Print

	bsr	AudioModStatus

.loopa:
	cmp.b	#$e0,$dff006
	bne.s	.loopa

	move.l	AudioModMusic-V(a6),a1
	lea	$dff000,a5
	jsr	(a1)				; Call MT_Music

	bsr	GetInput
	
	lea	AudioModStatData-V(a6),a1	; Get statusvariable

	cmp.b	#"1",GetCharData-V(a6)
	beq	.chan1
	cmp.b	#"2",GetCharData-V(a6)
	beq	.chan2
	cmp.b	#"3",GetCharData-V(a6)
	beq	.chan3
	cmp.b	#"4",GetCharData-V(a6)
	beq	.chan4
	cmp.b	#"f",GetCharData-V(a6)
	beq	.filter
	cmp.b	#"+",GetCharData-V(a6)
	beq	.volup
	cmp.b	#"-",GetCharData-V(a6)
	beq	.voldown
	cmp.b	#"l",GetCharData-V(a6)
	beq	.left
	cmp.b	#"r",GetCharData-V(a6)
	beq	.right
	cmp.b	#$1b,GetCharData-V(a6)
	beq	.exitit

.keydone:

	bsr	AudioModStatus
	cmp.b	#1,LMB-V(a6)
	bne.w	.loopa
.exitit:


	move.l	AudioModEnd-V(a6),a1
	lea	$dff000,a5
	jsr	(a1)				; Call MT_End

.exit:
	bra	AudioMenu

.chan1:
	bchg	#1,(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.chan2:
	bchg	#1,1(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.chan3:
	bchg	#1,2(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.chan4:
	bchg	#1,3(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.filter:
	bchg	#1,4(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.volup:
	cmp.b	#64,5(a1)			; Check if volume is already at max
	beq	.volmax
	add.b	#1,5(a1)
.volmax:
	clr.b	BUTTON-V(a6)
	bra	.keydone
		
.voldown:
	cmp.b	#0,5(a1)
	beq	.volmin
	sub.b	#1,5(a1)
.volmin:
	clr.b	BUTTON-V(a6)
	bra	.keydone
.left:
	bchg	#1,6(a1)			; Toggle left. copy it to chan1 & 4
	move.b	6(a1),(a1)
	move.b	6(a1),3(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.right:
	bchg	#1,7(a1)
	move.b	7(a1),1(a1)
	move.b	7(a1),2(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
	
AudioModStatus:
	PUSH
	lea	AudioModStatData-V(a6),a1	; Get statusvariable
	lea	AudioModStatFormerData-V(a6),a2	; Get statusvariable
	move.l	#3,d7
	move.l	#20,d6
.loop:
	move.b	(a1),d2
	cmp.b	(a2),d2			; Compare 2 data, if we had a change
	beq	.done			; if no change do not do anything
	move.b	d2,(a2)			; Store the real value into former data

	move.l	d6,d0
	move.l	#26,d1
	bsr	SetPos

	cmp.b	#0,(a1)			; if it is 0, channel is on
	bne	.off
	lea	ON,a0			; Print ON
	move.l	#2,d1
	bsr	Print
	beq	.done
.off:
	lea	OFF,a0			; Print OFF
	move.l	#1,d1
	bsr	Print
.done:
	add.l	#1,a2			; add 1 to fomerdatapos
	add.l	#1,a1
	add.l	#16,d6			; change variable to put next string 16 chars away
	dbf	d7,.loop	


	move.b	(a1),d2
	cmp.b	(a2),d2			; Compare 2 data, if we had a change
	beq	.donefilter		; if no change do not do anything
	move.b	d2,(a2)			; Store the real value into former data

	move.l	#33,d0
	move.l	#27,d1
	bsr	SetPos

	cmp.b	#0,(a1)			; if it is 0, channel is on
	bne	.filteroff
	bsr	FilterON
	lea	ON,a0			; Print ON
	move.l	#2,d1
	bsr	Print
	beq	.donefilter
.filteroff:
	bsr	FilterOFF
	lea	OFF,a0			; Print OFF
	move.l	#1,d1
	bsr	Print
.donefilter:	

	add.l	#1,a2			; add 1 to fomerdatapos
	add.l	#1,a1


	move.b	(a1),d2
	cmp.b	(a2),d2			; Compare 2 data, if we had a change
	beq	.donevol		; if no change do not do anything
	move.b	d2,(a2)			; Store the real value into former data


	
	move.l	#59,d0
	move.l	#27,d1
	bsr	SetPos

	clr.l	d0
	move.b	d2,d0
	bsr	bindec
	move.l	#2,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
.donevol:
	move.l	AudioModMVol-V(a6),a0
	move.b	(a1),(a0)+				; Set Mastervolume
	lea	AudioModStatData-V(a6),a1	; Get statusvariable
	move.b	(a1)+,(a0)+	
	move.b	(a1)+,(a0)+	
	move.b	(a1)+,(a0)+	
	move.b	(a1)+,(a0)+			; Copy data to protrackerroutine.
						; move.l WILL crash on non 020+ machines
	POP
	rts

;------------------------------------------------------------------------------------------

MemtestMenu:
	bsr	InitScreen
	move.w	#3,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

CheckDetectedChip:
	bsr	ClearScreen
	lea	MemtestDetChipTxt,a0
	move.l	#2,d1
	bsr	Print

	move.b	#0,CheckMemNoShadow-V(a6)

	move.l	ChipStart-V(a6),d0
	lea	TotalChip-V(a6),a0	; Total Chipmem detected
	move.l	(a0),d1

	mulu	#1024,d1
	add.l	d0,d1
	sub.l	#$400,d1

	move.l	#0,d2
	bsr	CheckMemory

	bsr	WaitButton
	bra	MemtestMenu


CheckExtendedChip:
	bsr	ClearScreen
	lea	MemtestExtChipTxt,a0
	move.l	#2,d1
	bsr	Print
	move.b	#0,CheckMemNoShadow-V(a6)

	move.l	#$400,d0
	move.l	#$200000,d1

	clr.l	d2
	bsr	CheckMemory

	bsr	WaitButton
	bra	MemtestMenu


CheckDetectedMBMem:
	bsr	ClearScreen

	clr.b	nomem-V(a6)
	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	FirstMBMem-V(a6)
	clr.l	MBMemSize-V(a6)

	lea	$200000,a0
	lea	$a00000,a1
	bsr	DetectMem

	move.l	a0,FirstMBMem-V(a6)
	move.l	d0,MBMemSize-V(a6)

	cmp.l	#0,d0					; Check if we had nomem
	beq	.nomem

	clr.b	temp-V(a6)				; Clear tempvariable

	lea	MemtestDetMBMemTxt3,a0

	bsr	.CheckPrint
	clr.l	d2
	move.l	FirstMBMem-V(a6),d0
	move.l	d0,d1
	add.l	MBMemSize-V(a6),d1
	move.b	#0,CheckMemNoShadow-V(a6)
	bsr	CheckMemory
	bra	.next
.nomem:
	add.b	#1,nomem-V(a6)				; Store 1 into temp, telling we had no memory
.next:

	bsr	.ClearTop
	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	FirstMBMem-V(a6)
	clr.l	MBMemSize-V(a6)
	lea	$4000000,a0
	lea	$8000000,a1
	bsr	DetectMem
	move.l	a0,FirstMBMem-V(a6)
	move.l	d0,MBMemSize-V(a6)

	cmp.l	#0,d0					; Check if we had nomem
	beq	.nomem2

	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	d0
	clr.l	d1
	bsr	SetPos

	lea	MemtestDetMBMemTxt,a0
	bsr	.CheckPrint
	clr.l	d2
	move.l	FirstMBMem-V(a6),d0
	move.l	d0,d1
	add.l	MBMemSize-V(a6),d1
	move.b	#0,CheckMemNoShadow-V(a6)
	move.l	#2,d2
	bsr	CheckMemory
	bra	.next2

.nomem2:
	add.b	#1,nomem-V(a6)
.next2:

	bsr	.ClearTop
	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	FirstMBMem-V(a6)
	clr.l	MBMemSize-V(a6)

	lea	$8000000,a0
	lea	$10000000,a1
	bsr	DetectMem

	move.l	a0,FirstMBMem-V(a6)
	move.l	d0,MBMemSize-V(a6)

	cmp.l	#0,d0					; Check if we had nomem
	beq	.nomem3


	lea	MemtestDetMBMemTxt2,a0
	bsr	.CheckPrint
	clr.l	d2
	move.l	FirstMBMem-V(a6),d0
	move.l	d0,d1
	add.l	MBMemSize-V(a6),d1
	move.b	#0,CheckMemNoShadow-V(a6)
	move.l	#2,d2
	bsr	CheckMemory
	bra	.next3

.nomem3:
	add.b	#1,nomem-V(a6)
.next3:

	cmp.b	#3,nomem-V(a6)				; Check if we had no memory. put errormessage
	bne	.wehadmem

	lea	MemtestNORAM,a0
	move.l	#1,d1
	bsr	Print

.wehadmem:
	bsr	.ClearTop
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	lea	AnyKeyMouseTxt,a0
	move.l	#4,d1
	bsr	Print
	bsr	WaitButton
	bra	MemtestMenu


.ClearTop:
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	lea	EmptyRowTxt,a0
	bsr	Print
	rts
.CheckPrint:
	PUSH
	move.l	#2,d1
	bsr	Print


	move.l	MBMemSize-V(a6),d0

	asr.l	#8,d0
	asr.l	#2,d0

	bsr	bindec
	move.l	#2,d1
	bsr	Print
	lea	KB,a0
	bsr	Print

	POP
	rts

CheckExtended16MBMem:
	bsr	ClearScreen

	lea	MemtestExtMBMemTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	#$7000000,d0
	move.l	#$7ffffff,d1

	move.l	#1,d2
	move.b	#0,CheckMemNoShadow-V(a6)
	bsr	CheckMemory
	bsr	WaitButton
	bra	MemtestMenu


CheckExtendedMBMem:
	bsr	ClearScreen
	lea	MemtestExtMBMemTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	#$4000000,d0
	move.l	#$fffffff,d1

	move.l	#1,d2
	move.b	#0,CheckMemNoShadow-V(a6)
	bsr	CheckMemory
	bsr	WaitButton
	bra	MemtestMenu


CheckMemManual:
	bsr	ClearScreen
	lea	MemtestManualTxt,a0
	move.l	#6,d1
	bsr	Print

	move.b	#41,d0
	move.b	#13,d1

	lea	$0,a0
	bsr	InputHexNum
	cmp.l	#-1,d0
	beq	.exit

	move.l	d0,d6

	lea	MemtestManualEndTxt,a0
	move.l	#6,d1
	bsr	Print

	lea	$0,a0
	bsr	InputHexNum
	cmp.l	#-1,d0
	beq	.exit

	move.l	d0,d7

	lea	MemtextManualModeTxt,a0
	move.l	#6,d1
	bsr	Print

.loop:
	bsr	GetChar
	cmp.b	#0,d0
	beq	.nochar

	cmp.b	#$1b,d0
	beq	.done3

	bclr	#5,d0				; make it uppercase

	cmp.b	#"F",d0
	beq	.fast

	cmp.b	#"S",d0
	beq	.slow

.nochar:
	bsr	GetMouse
	cmp.b	#1,RMB-V(a5)
	beq	.fast
	cmp.b	#1,LMB-V(a6)
	bne	.loop

.fast:
	move.l	#1,d2
	bra	.done

.slow:
	move.l	#0,d2
	bra	.done

.done:


	lea	MemtextManualShadowTxt,a0
	move.l	#6,d1
	bsr	Print

.loop2:
	bsr	GetChar
	cmp.b	#0,d0
	beq	.nochar2

	cmp.b	#$1b,d0
	beq	.done

	bclr	#5,d0				; make it uppercase

	cmp.b	#"Y",d0
	beq	.shadow
	bra	.done2
.nochar2:
	bsr	GetMouse
	cmp.b	#1,RMB-V(a5)
	beq	.done2
	cmp.b	#1,LMB-V(a6)
	bne	.loop2

.shadow:
	move.b	#1,CheckMemNoShadow-V(a6)
	bra	.done3

.done2:
	move.b	#0,CheckMemNoShadow-V(a6)
.done3:
	bsr	ClearScreen

	move.l	d7,d1
	move.l	d6,d0
	bsr	CheckMemory


	bsr	WaitButton
.exit:
	bra	MemtestMenu


CheckMemEdit:
	bsr	ClearScreen
	lea	CheckMemEditTxt,a0
	move.l	#2,d1
	bsr	Print

	move.b	#0,CheckMemEditXpos-V(a6)
	move.b	#0,CheckMemEditYpos-V(a6)	; Clear X and Y positions
	move.b	#0,CheckMemEditOldXpos-V(a6)
	move.b	#0,CheckMemEditOldYpos-V(a6)	; Clear X and Y positions

	clr.l	d0
	move.l	#3,d1
	bsr	SetPos

	move.l	CheckMemEditScreenAdr-V(a6),d0
	move.l	d0,a0
	bsr	CheckMemEditUpdateScreen

.loop:

	bsr	.putcursor

	bsr	GetMouse
	cmp.b	#1,RMB-V(a6)
	beq	.exit

.ansimode:
	bsr	GetChar

	cmp.b	#$1b,d0
	beq	.exit
	
	cmp.b	#30,d0
	beq	.up	

	cmp.b	#31,d0
	beq	.down
	
	cmp.b	#28,d0
	beq	.right

	cmp.b	#29,d0
	beq	.left

	move.b	d0,d1				; Copy char to d1, so we do not trash for hexnumbers
	bclr	#5,d1				; make it uppercase
	cmp.b	#"G",d1
	beq	.GotoMem			; G was pressed, let user enter address to dump


	cmp.b	#"R",d1
	beq	.Refresh


	bsr	GetHex				; OK, convert it to hex. if anything is left now, we have a hexdigit that
	cmp.b	#"0",d0
	blt	.nohex

.tobin:
	cmp.b	#"A",d0				; Check if it is "A"
	blt	.nochar				; Lower then A, this is not a char
	sub.l	#7,d0				; ok we have a char, subtract 7
.nochar:
	sub.l	#$30,d0				; Subtract $30, converting it to binary.

	move.l	d0,d2				; Store d0 into d2 temporary

	move.b	CheckMemEditXpos-V(a6),d0
	move.b	CheckMemEditYpos-V(a6),d1
	bsr	.getcursoradr			; a0 will now contain the address of memoryadress where cursor is
	clr.l	d7
	move.b	(a0),d7				; and D7 will contain what that address contains

	move.l	d2,d0				; Restore d2

	cmp.b	#0,CheckMemEditCharPos-V(a6)
	bne	.nocurleft

	and.b	#$f,d7				; Strip out high nibble from d7
	asl	#4,d0				; rotate input data to high nibble
	add.b	d0,d7				; add them together
	move.b	d7,(a0)				; store in memory
	add.b	#1,CheckMemEditCharPos-V(a6)	; add 1 to pos, for next nibble
	bra	.editdone
.nocurleft:
	and.b	#$f0,d7				; Strip out low nibble
	add.b	d0,d7				; add indata with the rest of d7
	move.b	d7,(a0)				; store in memory
	clr.b	CheckMemEditCharPos-V(a6)	; Clear charpos
	cmp.b	#15,CheckMemEditXpos-V(a6)
	beq	.noright
	add.b	#1,CheckMemEditXpos-V(a6)	; move one step to the right

.editdone:

						; Should go into memory. (Whaa.  BANGING on da shit here)

.nohex:
.keydone:
	bra	.loop




.getcursoradr:					; Get memoryaddress of X, Y pos
						; INDATA:
						;	d0 = xpos
						;	d1 = ypos
						;
						; OUTDATA:
						;	a0 = memoryaddress
	and.l	#$ff,d0
	and.l	#$ff,d1
	move.l	CheckMemEditScreenAdr-V(a6),a0
	add.l	d0,a0
	asl.l	#4,d1
	add.l	d1,a0
	rts

.putcursor:
	clr.l	d2
	clr.l	d3
	clr.l	d4
	clr.l	d5
	move.b	CheckMemEditXpos-V(a6),d2
	move.b	CheckMemEditYpos-V(a6),d3
	move.b	CheckMemEditOldXpos-V(a6),d4
	move.b	CheckMemEditOldYpos-V(a6),d5
	cmp.b	d2,d4
	bne	.notequal
	cmp.b	d3,d5
	bne	.notequal			; ok cursorpos have changed.. lets put a nonrevesed char in spot
.equal:
	move.l	#10,d0
	move.l	#4,d1

	mulu	#3,d2


	add.l	d2,d0
	add.l	d3,d1
	bsr	SetPos				; First byte


	move.b	CheckMemEditXpos-V(a6),d0
	move.b	CheckMemEditYpos-V(a6),d1
	bsr	.getcursoradr

	clr.l	d0

	move.b	(a0),d0
	move.l	d0,d7				; Store d0 to d7 temporary
	bsr	binhexbyte
	move.l	#11,d1
	bsr	Print				; Print what is in current memorypos as a HEX digit and yellow.

	move.l	#60,d0
	move.l	#4,d1

	add.b	CheckMemEditXpos-V(a6),d0
	add.b	CheckMemEditYpos-V(a6),d1

	bsr	SetPos
	

	move.b	CheckMemEditXpos-V(a6),d0
	move.b	CheckMemEditYpos-V(a6),d1
	bsr	.getcursoradr

	clr.l	d0
	move.b	(a0),d0
	bsr	MakePrintable
	move.l	#11,d1
	bsr	PrintChar

	move.l	#17,d0
	move.l	#25,d1
	bsr	SetPos

	move.l	a0,d0
	bsr	binhex
	move.l	#3,d1
	bsr	Print	


	move.l	#52,d0
	move.l	#25,d1
	bsr	SetPos

	move.l	d7,d0				; restore d0 with value from current pos
	bsr	binstringbyte
	move.l	#3,d1
	bsr	Print


	rts

.notequal:					; We had movement.  lets put stuff to "normal" case
	clr.b	CheckMemEditCharPos-V(a6)	; Clear charpos
	move.b	d2,CheckMemEditOldXpos-V(a6)
	move.b	d3,CheckMemEditOldYpos-V(a6)	; Set current pos to "old" pos

	move.l	d4,d7				; Copy d4 to d7 so we do not screw up data for later
	move.l	#10,d0
	move.l	#4,d1
	mulu	#3,d7				; Multiply X pos with 3 so we have space for 2 hexchars and a space
	add.l	d7,d0
	add.l	d5,d1

	PUSH					; Store this in stack, we will need it later
	bsr	SetPos				; Put cursor on screen
	move.l	d4,d0
	move.l	d5,d1
	bsr	.getcursoradr			; Get what memoryaddress we are pointing on
	clr.l	d0
	move.b	(a0),d0
	bsr	binhexbyte
	move.l	#7,d1
	bsr	Print				; Print that byte.
	POP					; ok roll back stack, we will need this data again

	move.l	d4,d0
	move.l	d5,d1
	add.l	#60,d0
	add.l	#4,d1
	bsr	SetPos
	move.l	d4,d0
	move.l	d5,d1
	bsr	.getcursoradr
	clr.l	d0
	move.b	(a0),d0
	bsr	MakePrintable
	move.l	#7,d1
	bsr	PrintChar

	bra	.equal


	PUSH					; Store in stack
	bsr	SetPos
	POP					; ok. d4 and d5 still contains x and y

	move.l	d4,d0
	move.l	d5,d1
	bsr	.getcursoradr
	add.l	#10,d0
	add.l	#4,d1
	bsr	SetPos

	move.b	(a0),d0
	bsr	binhexbyte
	move.l	#7,d1
	bsr	Print

	bra	.equal


.GotoMem:
	clr.b	CheckMemEditCharPos-V(a6)	; Clear charpos
	move.l	#0,d0
	move.l	#3,d1
	bsr	SetPos
	lea	CheckMemEditGotoTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	CheckMemEditScreenAdr-V(a6),d0	; Read the screenaddress currently showed
	add.l	#$150,d0			; Add $150 to that, (next screen)
	move.l	d0,a0
	bsr	InputHexNum
	cmp.l	#-1,d0
	beq	.exit
	move.l	d0,CheckMemEditScreenAdr-V(a6)	; Store address in memory
	move.l	d0,a0
	bsr	CheckMemEditUpdateScreen	; Update the screen
	bsr	.ClearCommandRow		; Clear the "goto" row.
	bra	.loop

.Refresh:
	clr.b	CheckMemEditCharPos-V(a6)	; Clear charpos
	move.l	CheckMemEditScreenAdr-V(a6),a0	; Get address
	bsr	CheckMemEditUpdateScreen	; Update the screen
	bsr	.ClearCommandRow		; Clear the "goto" row.
	bra	.loop
	

.exit:
	bra	MemtestMenu

.up:
	cmp.b	#0,CheckMemEditYpos-V(a6)
	beq	.noup
	sub.b	#1,CheckMemEditYpos-V(a6)
	bra	.keydone
.noup:
	move.l	CheckMemEditScreenAdr-V(a6),d0	; Read the screenaddress currently showed
	sub.l	#$10,d0
	move.l	d0,CheckMemEditScreenAdr-V(a6)	; Store address in memory
	move.l	d0,a0
	bsr	CheckMemEditUpdateScreen
	bra	.keydone
	
.down:
	cmp.b	#20,CheckMemEditYpos-V(a6)
	beq	.nodown
	add.b	#1,CheckMemEditYpos-V(a6)
	bra	.keydone
.nodown:
	move.l	CheckMemEditScreenAdr-V(a6),d0	; Read the screenaddress currently showed
	add.l	#$10,d0
	move.l	d0,CheckMemEditScreenAdr-V(a6)	; Store address in memory
	move.l	d0,a0
	bsr	CheckMemEditUpdateScreen
	bra	.keydone


.right:
	cmp.b	#15,CheckMemEditXpos-V(a6)
	beq	.noright
	add.b	#1,CheckMemEditXpos-V(a6)
.noright:
	bra	.keydone

.left:
	cmp.b	#0,CheckMemEditXpos-V(a6)
	beq	.noleft
	sub.b	#1,CheckMemEditXpos-V(a6)
.noleft:
	bra	.keydone
	
.ClearCommandRow:
	move.l	#0,d0
	move.l	#3,d1
	bsr	SetPos
	lea	EmptyRowTxt,a0
	bsr	Print
	rts

CheckMemEditUpdateScreen:			; Updates the whole screen with memorydump
						; INDATA:
						;	A0 = Startaddress
	move.l	#1,d0
	move.l	#20,d7
.loop:
	bsr	CheckMemEditUpdateRow
	add.l	#16,a0
	add.l	#1,d0
	dbf	d7,.loop			; Print 21 rows of memorydump on screen

	move.l	#0,d0
	move.l	#25,d1
	bsr	SetPos

	lea	CheckMemAdrTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	#28,d0
	move.l	#25,d1
	bsr	SetPos
	lea	CheckMemBinaryTxt,a0
	move.l	#2,d1
	bsr	Print

	rts


CheckMemEditUpdateRow:
	;	Show memoryadress on screen
	;	INDATA:
	;		a0 = memory address
	;		d0 = row to update

	PUSH
	move.l	a0,a1				; store a0 in a1 for usage here.. as a0 is used
	add.l	#3,d0				; Add 3 to line to work on.
	move.l	d0,d1				; copy d0 to d1 to use it as Y adress
	clr.l	d0				; clear X pos
	bsr	SetPos				; Set position
	
	move.l	a0,d0
	bsr	binhex
	move.l	#6,d1
	bsr	Print				; Print address

	clr.l	d2				; Column to print
	move.l	#15,d7
.loop:
	lea	SpaceTxt,a0
	bsr	Print
	clr.l	d0				; Clear d0 just to be sure
	move.b	(a1,d2),d0
	bsr	binhexbyte			; Convert that byte to hex
	move.l	#7,d1
	bsr	Print				; Print it
	add.l	#1,d2
	dbf	d7,.loop
	lea	ColonTxt,a0			; Print a Colon
	move.l	#3,d1
	bsr	Print

	move.l	#15,d7				; Now print the same bytes.  as chars instead	
	clr.l	d2
.loop2:
	clr.l	d0
	move.b	(a1,d2),d0
	bsr	MakePrintable			; make the char printable.  strip controlstuff..
	add.l	#1,d2
	move.l	#7,d1
	bsr	PrintChar
	dbf	d7,.loop2
	POP
	rts


;------------------------------------------------------------------------------------------

IRQCIAtestMenu:
	bsr	InitScreen
	move.w	#4,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

IRQCIAIRQTest:
	bsr FixBitplane
	bsr	InitScreen
	lea	IRQCIAIRQTestText,a0
	move.w	#2,d1
	bsr	Print

.loop:
	bsr	GetInput

	cmp.b	#$1b,GetCharData-V(a6)
	beq	.exit
	cmp.b	#1,RMB-V(a6)
	beq	.exit
	cmp.b	#1,BUTTON-V(a6)
	bne	.loop

	lea	IRQCIAIRQTestText2,a0
	move.w	#7,d1
	bsr	Print

	bsr	WaitReleased
	
	move.w	#$2000,sr			; Set SR to allow IRQs
	
	lea	IRQLev1Txt,a0
	move.l	#6,d1
	bsr	Print

	move.l	#IRQLevTest,$64			; Set up IRQ Level 1
	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	;move.w	#$c004,$dff09a			; Enable IRQ
	;move.w	#$c004,$dff09a			; Enable IRQ
	;move.w	#$8004,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	;move.w	#$7fff,$dff09c			; Disable all INTREQ
	;move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	bne	.done1

	bsr	WaitReleased
	
.done1:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev2Txt,a0
	move.l	#6,d1
	bsr	Print


	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$68			; Set up IRQ Level 2
	
	;move.w	#$c008,$dff09a			; Enable IRQ
	;move.w	#$c008,$dff09a			; Enable IRQ
	;move.w	#$8008,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	;move.w	#$7fff,$dff09c			; Disable all INTREQ
	;move.w	#$7fff,$dff09a			; Disable all INTREQ

	cmp.b	#2,d0
	beq	.done2

	bsr	WaitReleased

.done2:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev3Txt,a0
	move.l	#6,d1
	bsr	Print


	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$6c			; Set up IRQ Level 3
	;move.w	#$c020,$dff09a			; Enable IRQ
	;move.w	#$c020,$dff09a			; Enable IRQ
	;move.w	#$8020,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	;move.w	#$7fff,$dff09c			; Disable all INTREQ
	;move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done3

	bsr	WaitReleased

.done3:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev4Txt,a0
	move.l	#6,d1
	bsr	Print


	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$70			; Set up IRQ Level 4
	;move.w	#$c080,$dff09a			; Enable IRQ
	;move.w	#$c080,$dff09a			; Enable IRQ
	;move.w	#$8080,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	;move.w	#$7fff,$dff09c			; Disable all INTREQ
	;move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done4

	bsr	WaitReleased

.done4:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev5Txt,a0
	move.l	#6,d1
	bsr	Print


	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$74			; Set up IRQ Level 5
	;move.w	#$c800,$dff09a			; Enable IRQ
	;move.w	#$c800,$dff09a			; Enable IRQ
	;move.w	#$8800,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	;move.w	#$7fff,$dff09c			; Disable all INTREQ
	;move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done5

	bsr	WaitReleased

.done5:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev6Txt,a0
	move.l	#6,d1
	bsr	Print

	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$78			; Set up IRQ Level 6
	;move.w	#$e000,$dff09a			; Enable IRQ
	;move.w	#$e000,$dff09a			; Enable IRQ
	;move.w	#$a000,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	;move.w	#$7fff,$dff09c			; Disable all INTREQ
	;move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done6

	bsr	WaitReleased

.done6:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev7Txt,a0
	move.l	#6,d1
	bsr	Print

	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$78			; Set up IRQ Level 7
	bsr	TestIRQ
	;move.w	#$7fff,$dff09c			; Disable all INTREQ
	;move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done7

	bsr	WaitReleased

.done7:


	lea	IRQTestDone,a0
	move.l	#2,d1
	bsr	Print


	

	bsr	WaitButton

.exit:
	bsr	IRQCIAtestMenu


TestIRQ:				; Test if IRQ was triggered
					; OUT:
					;	d0 = 0	== Everything sucessful
					;	d0 = 1	== We have failure
					;	d0 = 2	== User pressed cancel
	clr.l	d0
	move.w	#1000,d7
.loop:
	bsr	GetInput			; Check for input from user
	cmp.b	#1,BUTTON-V(a6)			; If button is pressed, exit
	beq	.exitloop
	bsr	WaitLong
	cmp.w	#1,IRQLevDone-V(a6)		; Check if IRQLevDone is set, done in IRQ routine
	beq	.yes
	dbf	d7,.loop

	lea	FAILED,a0
	move.l	#5,d1
	bsr	Print
	move.b	#1,d0				; we exited loop, test failed
	rts
.yes:
	lea	OK,a0
	move.l	#2,d1
	bsr	Print
	rts
.exitloop:
	lea	CANCELED,a0
	move.l	#3,d1
	bsr	Print
	rts

	move.b	#2,d0
	rts
	

IRQLevTest:					; Small IRQ Rouine, all it does is to set IRQLevDone to 1
	move.w	#$fff,color0
	move.w	#1,IRQLevDone-V(a6)
	;move.w	#$7fff,$dff09c			; Disable all INTREQ
	;move.w	#$7fff,$dff09a			; Disable all INTREQ
	rte

CIATIME	EQU	174
;	equ	174			(10000ms / 1.3968255 for PAL)

IRQCIACIATest:
	cmp.b	#1,RASTER-V(a6)			; Check if we have a working raster, if not we are unable to
	bne	.noraster			; count frames (for timing) so not possible to perform tests

	bsr	InitScreen


	lea	CIATestTxt,a0
	move.w	#2,d1
	bsr	Print
	lea	CIATestTxt2,a0
	move.w	#2,d1
	bsr	Print
.loop:
	bsr	GetInput
	cmp.b	#$1b,GetCharData-V(a6)
	beq	IRQCIAtestMenu
	cmp.b	#1,RMB-V(a6)
	beq	IRQCIAtestMenu

	cmp.b	#1,BUTTON-V(a6)
	bne.s	.loop

	lea	CIATestTxt3,a0
	move.w	#4,d1
	bsr	Print


;	move.w	#$7fff,$dff09a			; Kill all chip interrupts


	lea	CIAATestAATxt,a0
	lea	$bfe001,a5			; load a5 with a base
	lea	$bfe001,a4			; load a5 with a base
	lea	$bfee01,a3			; load a5 with a base
	move.l	#0,d2
	move.l	#7,d5	
	bsr	.TestCIA


	lea	CIAATestBATxt,a0
	lea	$bfe201,a5			; load a5 with a base
	lea	$bfe001,a4			; load a5 with a base
	lea	$bfef01,a3			; load a5 with a base
	move.l	#1,d2
	move.l	#8,d5	
	bsr	.TestCIA

	bsr	TestATOD

	lea	CIAATestABTxt,a0
	lea	$bfd000,a5			; load a5 with a base
	lea	$bfd000,a4			; load a5 with a base
	lea	$bfde00,a3			; load a5 with a base
	move.l	#0,d2
	move.l	#10,d5	
	bsr	.TestCIA


	lea	CIAATestBBTxt,a0
	lea	$bfd200,a5			; load a5 with a base
	lea	$bfd000,a4			; load a5 with a base
	lea	$bfdf00,a3			; load a5 with a base
	move.l	#1,d2
	move.l	#11,d5	
	bsr	.TestCIA

	bsr	TestBTOD




.keyloop:
	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)
	bne.s	 .keyloop

	bra	IRQCIAtestMenu
	
.noraster:					; We had no working raster, print errormessage
	bsr	InitScreen			; and prompt for keypress to go back to mainmenu.
	lea	CIANoRasterTxt,a0
	move.w	#1,d1
	bsr	Print
	lea	CIANoRasterTxt2,a0
	move.w	#2,d1
	bsr	Print
.nrloop:
	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)
	bne.s	.nrloop
	bra	MainMenu



.TestCIA:

	clr.l	d0
	move.l	d5,d1
	bsr	SetPos
	
	move.l	#3,d1
	bsr	Print


	clr.w	Frames-V(a6)			; Clear number frames
	clr.w	TickFrame-V(a6)
	clr.l	Ticks-V(a6)

	move.l	#CIALevTst,$6c			; Set up IRQ Level 3
	move.w	#$c020,$dff09a			; Enable IRQ
	move.w	#$c020,$dff09a			; Enable IRQ

	move.w	#$2000,sr			; Set SR to allow IRQs


	move.b	(a3),d0				; Set control register A on CIAA
	move.b	d0,CIACtrl-V(a6)
	andi.b	#$c0,d0				; Do not touch bits we are not
	ori.b	#8,d0				; Using...
	move.b	d0,(a3)



	move.w	#7812,d6
	clr.l	d7


.loopa:
	move.b	$400(a5),CIACtrl-V+1(a6)
	move.b	$500(a5),CIACtrl-V+2(a6)

	move.b	#(CIATIME&$FF),$400(a5)
	move.b	#(CIATIME>>8),$500(a5)			; Set registers to wait for 10000ms

.wait:
	move.w	#$0,color0

	cmp.w	#120,Frames-V(a6)
	bge	.vblankoverrun

	btst	d2,$d00(a4)
	beq	.wait
	add.l	#1,Ticks-V(a6)
	move.w	#$f,color0
.no:

	dbf	d6,.loopa				; Repeat this so we are doing it for a while
	bset	#0,(a3)
	clr.l	d6				; Clear D6, meaning we have executed this without Vblank overrun

	bra	.exit

.vblankoverrun:	
	move.l	#1,d6				; Set it as 1, to mark we had a overrun

.exit:

	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ

	move.l	#RTEcode,$6c			; Restore IRC Vector to empty code

	move.b	CIACtrl-V(a6),(a3)
	move.b	CIACtrl-V+1(a6),$400(a5)
	move.b	CIACtrl-V+2(a6),$500(a5)
	

	move.w	Frames-V(a6),TickFrame-V(a6)

	move.l	#35,d0
	move.l	d5,d1
	bsr	SetPos

	move.l	Ticks-V(a6),d0
	asl.l	#8,d0

	bsr	bindec
	move.w	#2,d1
	bsr	Print
	lea	ms,a0
	bsr	Print


	move.w	TickFrame-V(a6),d0

;	cmp.w	#105,d0
;	bge	.underrun
	cmp.w	#95,d0
	ble	.underrun
	bra	.nounderrun

.underrun:
	lea	VblankUnderrunTXT,a0
	move.l	#1,d1
	bsr	Print
	move.l	#2,d6
	bra	.nooverrun

.nounderrun:

	cmp.b	#1,d6
	bne	.nooverrun
	lea	VblankOverrunTXT,a0
	move.l	#1,d1
	bsr	Print
	
.nooverrun:

	cmp.b	#0,d6				; Check d6, if it isnt 0, we had a failure
	beq	.nooverrun2

	move.l	#70,d0
	move.l	d5,d1
	bsr	SetPos

	lea	FAILED,a0
	move.w	#1,d1
	bsr	Print
	rts
		
.nooverrun2:
	move.l	#70,d0
	move.l	d5,d1
	bsr	SetPos
	lea	OK,a0
	move.l	#2,d1
	bsr	Print



	rts
	
	clr.l	d0
	move.l	#1,d1
	bsr	SetPos
	clr.l	d0
	move.w	TickFrame-V(a6),d0
	bsr	bindec
	move.l	#3,d1
	bsr	Print

	rts

CIALevTst:
	move.w	#$020,$dff09c			; Enable IRQ
	move.w	#$020,$dff09c			; Enable IRQ
	add.w	#1,Frames-V(a6)				; Add 1 to Frames so we can keep count of frames shown.
							; (or VBlanks)
;	move.w	#$f4,color0
	TOGGLEPWRLED
.no:
	rte





TestATOD:
	lea	CIATestATOD,a0
	clr.l	d0
	move.l	#9,d1
	bsr	SetPos
	
	move.l	#3,d1
	bsr	Print


	clr.w	Frames-V(a6)			; Clear number frames
	clr.l	Ticks-V(a6)

	move.l	#CIALevTst,$6c			; Set up IRQ Level 3
	move.w	#$c020,$dff09a			; Enable IRQ
	move.w	#$c020,$dff09a			; Enable IRQ;
;	move.w	$dff01c,$d7
	bclr	#7,$bfef01
	move.b	#0,$bfea01
	move.b	#0,$bfe901
	move.b	#0,$bfe801

.loopa:

	moveq	#0,d6
	move.b	$bfea01,d6
	lsl.l	#8,d6
	move.b	$bfe901,d6
	lsl.l	#7,d6
	move.b	$bfe801,d6


	cmp.l	Ticks-V(a6),d6
	beq.s	.no
	move.w	#$f,color0
.no:

	move.l	d6,Ticks-V(a6)

	clr.l	d0
	move.l	#10,d1
	bsr	SetPos
	clr.l	d0

	cmp.w	#100,Frames-V(a6)		; Check if we have tested for 200 VBlanks
	blt	.loopa


	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ

	move.l	#RTEcode,$6c			; Restore IRC Vector to empty code



	move.l	#35,d0
	move.l	#9,d1
	bsr	SetPos

	move.l	Ticks-V(a6),d0

	bsr	bindec
	move.w	#2,d1
	bsr	Print
	lea	ticks,a0
	bsr	Print



	cmp.l	#95,d6
	ble	.tooslow
	cmp.l	#105,d6
	bge	.toofast

	move.l	#70,d0
	move.l	#9,d1
	bsr	SetPos

	lea	OK,a0
	move.w	#2,d1
	bsr	Print
	rts

.tooslow:
	move.l	#1,d1
	lea	CIATickSlowTxt,a0
	bsr	Print
	move.l	#70,d0
	move.l	#9,d1
	bsr	SetPos
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print

	rts
.toofast:
	move.l	#1,d1
	lea	CIATickFastTxt,a0
	bsr	Print
	move.l	#70,d0
	move.l	#9,d1
	bsr	SetPos
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print

	rts




TestBTOD:
	lea	CIATestBTOD,a0
	clr.l	d0
	move.l	#12,d1
	bsr	SetPos
	
	move.l	#3,d1
	bsr	Print


	clr.w	Frames-V(a6)			; Clear number frames
	clr.l	Ticks-V(a6)

	move.l	#CIALevTst,$6c			; Set up IRQ Level 3
	move.w	#$c020,$dff09a			; Enable IRQ
	move.w	#$c020,$dff09a			; Enable IRQ;
;	move.w	$dff01c,$d7
	bclr	#7,$bfdf00
	move.b	#0,$bfda00
	move.b	#0,$bfd900
	move.b	#0,$bfd800

.loopa:

	moveq	#0,d6
	move.b	$bfda00,d6
	lsl.l	#8,d6
	move.b	$bfd900,d6
	lsl.l	#8,d6
	move.b	$bfd800,d6


	cmp.l	Ticks-V(a6),d6
	beq.s	.no
	move.w	#$f,color0
.no:

	move.l	d6,Ticks-V(a6)

	clr.l	d0
	move.l	#12,d1
	bsr	SetPos
	clr.l	d0

	cmp.w	#100,Frames-V(a6)		; Check if we have tested for 200 VBlanks
	ble	.loopa


	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ

	move.l	#RTEcode,$6c			; Restore IRC Vector to empty code



	move.l	#35,d0
	move.l	#12,d1
	bsr	SetPos

	move.l	Ticks-V(a6),d0

	bsr	bindec
	move.w	#2,d1
	bsr	Print
	lea	ticks,a0
	bsr	Print



	cmp.l	#30000,d6
	ble	.tooslow
	cmp.l	#32000,d6
	bge	.toofast
	
	move.l	#70,d0
	move.l	#12,d1
	bsr	SetPos

	lea	OK,a0
	move.w	#2,d1
	bsr	Print
	rts

.tooslow:
	move.l	#1,d1
	lea	CIATickSlowTxt,a0
	bsr	Print
	move.l	#70,d0
	move.l	#12,d1
	bsr	SetPos
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print

	rts
.toofast:
	move.l	#1,d1
	lea	CIATickFastTxt,a0
	bsr	Print
	move.l	#70,d0
	move.l	#12,d1
	bsr	SetPos
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print

	rts





;------------------------------------------------------------------------------------------




GFXtestMenu:
	bsr	InitScreen
	move.w	#5,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

GFXTestScreen:
	bsr	ClearScreen

	move.l	#EndTestPic-TestPic,d0
	move.l	d0,d2

	move.l	Bpl1Ptr-V(a6),d7
	add.l	#$ff,d7
	and.l	#$ffffff00,d7
	move.l	d7,a0

	lea	TestPic+34,a1				; Set a1 to where testscreen is in ROM
.loop:
	move.b	(a1)+,(a0)+				; Copy testimage to Chipmem
	dbf	d2,.loop

	move.l  #16-1,d2
	lea	TestPic+2,a1				; Set a1 to where testscreen is in ROM
	lea color0,a0
.palloop:
	move.w	(a1)+,(a0)+				; Copy testimage to Chipmem
	dbf	d2,.palloop

	move.b	  #$0,v_mode ; set low res
	move.b 	  #$2,v_sync ; setup pal

.exit:
	bsr	WaitButton
	bsr InitStuff
	bra	GFXtestMenu


GFXtest320x200:

	move.w	#$83f0,$dff096				; Turn on all DMA required


	bsr	ClearScreen
	move.l	#HIRESSize*5,d0
	bsr	GetChip
	cmp.l	#0,d0
	beq	.exit
	cmp.l	#1,d0
	beq	.exit
	move.l	#HIRESSize,d1
	lea	ECSCopper-V(a6),a0			; Location of copperlist in memory
	lea	ECSColor32,a1

	clr.l	d0
	clr.l	d1
	move.l	#640,d2
	move.l	#512,d3
	move.l	#6,d4
	bsr	DrawLine

	move.l	#640,d0
	clr.l	d1
	clr.l	d2
	move.l	#512,d3
	move.l	#6,d4
	bsr	DrawLine



	move.l	#640,d7
	move.l	#1,d2
	clr.l	d0
.loop6:
	move.l	#236,d1
	move.l	#40,d6
.loop5:
	bsr	PlotPixel
	add.l	#1,d1
	dbf	d6,.loop5
	move.l	d7,d2
	asr	#4,d2

	add.l	#1,d0
	dbf	d7,.loop6



	clr.l	d0
	move.l	#511,d1
.loop:
	move.l	#1,d2
	bsr	PlotPixel
	dbf	d1,.loop
	move.l	#640,d0
.loop2:
	move.l	#511,d1
	move.l	#1,d2
	bsr	PlotPixel
	dbf	d0,.loop2

	move.l	#639,d0
	move.l	#511,d1
.loop3:
	move.l	#1,d2
	bsr	PlotPixel
	dbf	d1,.loop3

	move.l	#639,d0
	clr.l	d1
.loop4:
	move.l	#1,d2
	bsr	PlotPixel
	dbf	d0,.loop4






	



	bsr	WaitButton

	move.w	#$3ff,$dff096				; Turn off all DMA
	
.exit:
	bsr	GFXtestMenu


;.exit:
	POP
	rts




DrawLine:							
	PUSH
	asr	#1,d0
	asr	#1,d1
	asr	#1,d2
	asr	#1,d3
	lea	GfxTestBpl-V(a6),a5		; Load pointerlist for bitplanes
	move.l	#4,d7				; number of bitplanes to handle - 1
	clr.l	d6				; Clear d6, d6 is bit to test for palette
	move.l	#40,a1
.loop:
	move.l	(a5)+,a0				; A0 now contains address of bitplane
	btst	d6,d4				; Check if pixel is to be set of cleared
	bne.s	.set				; it is to be set
	bra.s	.clear				; if not, clear it

		
.set:
	move.l	#$ffffffff,a2
	bsr	.DrawLine
	bra	.done
.clear:
	move.l	#$0,a2
	bsr	.DrawLine
.done:
	add.l	#1,d6
	dbf	d7,.loop

	POP

	rts


.DrawLine:
	move.w	#$fff,color0
	; d0 = x1
	; d1 = y1
	; d2 = x2
	; d3 = y2
	; a0 = Bitplanr
	; a1 = bitplanewidth in bytes
	; a2 = word written directly to mast register
	PUSH
;	asr.l	#1,d0
;	asr.l	#1,d1
;	asr.l	#1,d2
;	asr.l	#1,d3
	clr.l	d5	
	cmp.w	#320,d0
	ble	.nohighx1
	rts
.nohighx1:	
	cmp.w	#256,d1
	ble	.nohighy1
	rts
.nohighy1:	
	cmp.w	#640,d2
	ble	.nohighx2
	rts
.nohighx2:	
	cmp.w	#256,d3
	ble	.nohighy2
	rts
.nohighy2:	
	clr.l	d4
	add.w	d4,d2
	add.w	d4,d3

	move.l	a1,d4	; Width in work register
	mulu	d1,d4	;Y1 * byte per line
	moveq	#-$10,d5	; No leading characters $f0
	and.w	d0,d5	; Bottom four bits masked from x1
	lsr.w	#3,d5	; Reminder divided by 8
	add.w	d5,d4	; Y1 * bytes per line + x1/8
	add.l	a0,d4	; Plus startong adress of the bitplanes

	clr.l	d5
	sub.w	d1,d3	; Y2-Y1 DeltaY from D3
	roxl.b	#1,d5	; Shift leading char from DeltaY in D5
	tst.w	d3	; Restore N-Flag
	bge.s	.y2gy1	; When DeltaY positive, goto g2gy1
	neg.w	d3	; DeltaY invert (if not positive)

.y2gy1:
	sub.w	d0,d2	; X2-X1 DeltaX to D2
	roxl.b	#1,d5	; move leading char in DeltaX to d5
	tst.w	d2	; Restore N-Flag
	bge.s	.x2gx1	; When Delta X positive
	neg.w	d2	; DeltaX invert

.x2gx1:
	move.w	d3,d1	; DeltaY to d1
	sub.w	d2,d1	; DeltaY-DeltaX
	bge.s	.dygdx	; When DeltaY > DeltaX
	exg	d2,d3	; Smaller delta goto d2
.dygdx:
	roxl.b	#1,d5	; D5 contains result of 3 comparisons
	lea	Octant_Table,a5
	move.b	(a5,d5),d5	; Get matching octants
;	move.b	Octant_Table(pc,d5),d5	; Get matching octants
	add.w	d2,d2	; Smaller Delta * 2

	VBLT

	move.w	d2,$dff062	;2*Smaller delta tp BLTBMOD
	sub.w	d3,d2	; 2*smaööer delta - larger delta
	ble.s	.signn1	;When 2*small delta > largedelta to signn1

	or.b	#$40,d5	;Sign flag set
.signn1:
	move.w	d2,$dff052	; 2*smal delta - large delta in BLTAPTL
	sub.w	d3,d2		; 2*smaller delta -2*larger delta
	move.w	d2,$dff064	; tp BLTAMOD

	move.w	#$8000,$dff074	; BLTADAT
	move.w	a2,$dff072	; mask from a2 in BLTBDAT
	move.w	#$ffff,$dff044 ; BLTAFWM
	and.w	#$000f,d0	; Bottom 4 bits from X1
	ror.w	#4,d0		; to START0-3
	or.w	#$0bca,d0	; USEx and LFx set
	move.w	d0,$dff040	; BLTCON0
	move.w	d5,$dff042	; Octant ib blitter BLTCON1
	move.l	d4,$dff048	; Start adress of line  BLTCPTH
	move.l	d4,$dff054	; BLTDPTH
	move.w	a1,$dff060	; Width of bitplanes i both BLTCMOD
	move.w	a1,$dff066	; and BLTDMOD registers

	lsl.l	#6,d3	; Length * 64
	addq.w	#2,d3	; Plus wodth=2
	move.w	d3,$dff058	; set size and start blit
	POP
	rts

PlotPixel:						; Plots a pixel
							; INDATA:
							;	D0 = XPos
							;	D1 = YPos
							;	D2 = Color
							
	PUSH

	asr.l	#1,d0
	asr.l	#1,d1

	move.l	d0,d4				; Make a copy of the X Cordinate
	asr	#3,d0				; Divide te XCordinate with 8 to get what byte to do stuff on
	move.l	d0,d3				; Make a copy of this byte
	asl	#3,d3				; multiply it with 8
	sub.l	d3,d4				; Diff it, so we know what BIT to set

	move.l	#7,d5				; But as it is "reversed" put 7 into d5 and
	sub.l	d4,d5				; Subtract but to do stuff in, d5 now contains bit

	mulu	#40,d1				; Multiply with 40 to get Y position

	add.l	d1,d0				; Add d1 to d0. so d0 now contains how much to add for the pixel

	lea	GfxTestBpl-V(a6),a2		; Load pointerlist for bitplanes
	move.l	#4,d7				; number of bitplanes to handle - 1
	clr.l	d6				; Clear d6, d6 is bit to test for palette

.loop:
	move.l	(a2)+,a0				; A0 now contains address of bitplane
	btst	d6,d2				; Check if pixel is to be set of cleared
	bne.s	.set				; it is to be set
	bra.s	.clear				; if not, clear it

		
.set:
	bset	d5,(a0,d0)
	bra	.done
.clear:
	bclr	d5,(a0,d0)
.done:
	add.l	#1,d6
	dbf	d7,.loop

	POP
	rts



;--------------------------------------------------
;
; Clear screen with blitter..
;
;--------------------------------------------------



BlitterClear:
	; Clears area with blitter
	; INDATA
	; D0 = Pointer to plane.
	; D1 = Number of rows
	; D2 = Number of Words in width
	; D3 = Modulo
	
	PUSH
	VBLT				;Wait for blitter to finish before using the blitter again
	move.w	#$100,$dff040		;Use D,A Set minterm D=A
	clr.w	$dff042			;O=BLTCON1
	move.w	#$ffff,$dff044
	move.w	#$ffff,$dff046
	move.w	#$8040,$dff096		;Turn on blitter DMA
	move.l	d0,$dff054
	move.w	d3,$dff066		;Modulo D
	asl.l	#6,d1
	add.l	d2,d1
	move.w	d1,$dff058	;Set Size and start blitter
;	move.w	#10*62+20,$dff058
	POP
	rts


;------------------------------------------------------------------------------------------

SystemInfoTest:
	bsr	InitScreen
	lea	SystemInfoTxt,a0
	move.w	#2,d1
	bsr	Print

	lea	SystemInfoHWTxt,a0
	move.w	#2,d1
	bsr	Print

	bsr	GetHWReg
	bsr	PrintHWReg

	lea	NewLineTxt,a0
	bsr	Print

	move.l	#2,d1
	lea	ChipstartTxt,a0
	bsr	Print

	move.l	ChipStart-V(a6),d0			; Get startaddress of chipmem
	move.l	d0,d7					; make a backup of address
	bsr	binhex
	bsr	Print

	move.l	#2,d1
	lea	AndendTxt,a0
	bsr	Print


	move.l	ChipEnd-V(a6),d0			; Get startaddress of chipmem
	bsr	binhex
	move.l	#2,d1
	bsr	Print


	lea	UnusedChipTxt,a0
	move.l	#2,d1
	bsr	Print


	move.l	ChipUnreserved-V(a6),d0
	bsr	bindec
	bsr	Print

	lea	Bytes,a0
	bsr	Print

	bsr	WaitButton
	bsr	IRQCIAtestMenu
	



;------------------------------------------------------------------------------------------




PortTestMenu:
	bsr	InitScreen
	move.w	#6,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop



PortTestJoystick:
	bsr	ClearScreen

	move.w	#$ffff,JOY0DAT-V(a6)
	move.w	#$ffff,JOY1DAT-V(a6)
	move.w	#$ffff,POT0DAT-V(a6)
	move.w	#$ffff,POT1DAT-V(a6)
	move.w	#$ffff,POTINP-V(a6)
	move.b	#$ff,CIAAPRA-V(a6)
	clr.l	PortJoy0-V(a6)
	clr.l	PortJoy1-V(a6)
	move.w	#$fff,PortJoy0OLD-V(a6)
	move.w	#$fff,PortJoy1OLD-V(a6)
	clr.w	P0Fire-V(a6)
	clr.w	P1Fire-V(a6)
	move.w	#$fff,P0FireOLD-V(a6)
	move.w	#$fff,P1FireOLD-V(a6)
	
	lea	PortJoyTest,a0
	move.l	#7,d1
	bsr	Print
	lea	PortJoyTest1,a0
	move.l	#6,d1
	bsr	Print
	lea	PortJoyTestHW1,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW2,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW3,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW4,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW5,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW6,a0
	move.l	#3,d1
	bsr	Print


	move.l	#0,d0
	move.l	#11,d1
	bsr	SetPos

	lea	PortJoyTest2,a0
	move.l	#6,d1
	bsr	Print
	lea	PortJoyTest3,a0
	move.l	#6,d1
	bsr	Print


	move.l	#0,d0
	move.l	#23,d1
	bsr	SetPos

	lea	PortJoyTestExitTxt,a0
	move.l	#7,d1
	bsr	Print




.loop:
	move.w	$dff00a,d7
	lea	JOY0DAT-V(a6),a0
	cmp.w	(a0),d7
	beq	.samejoy0dat
	move.w	d7,(a0)
	move.w	d7,PortJoy0-V(a6)
	move.l	#36,d0
	move.l	#4,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#4,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print
.samejoy0dat:

	move.w	$dff00c,d7
	lea	JOY1DAT-V(a6),a0
	cmp.w	(a0),d7
	beq	.samejoy1dat
	move.w	d7,(a0)
	move.w	d7,PortJoy1-V(a6)

	move.l	#36,d0
	move.l	#5,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#5,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	PUSH
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print

	POP

.samejoy1dat:
	move.w	$dff012,d7
	lea	POT0DAT-V(a6),a0
	cmp.w	(a0),d7
	beq	.samepot0dat
	move.w	d7,(a0)
	move.l	#36,d0
	move.l	#6,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#6,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print

.samepot0dat:

	move.w	$dff014,d7
	lea	POT1DAT-V(a6),a0
	cmp.w	(a0),d7
	beq	.samepot1dat
	move.w	d7,(a0)


	move.l	#36,d0
	move.l	#7,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#7,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print
.samepot1dat:


;	move.w	$dff016,d7
	lea	POTINP-V(a6),a0
	cmp.w	(a0),d7
	beq	.samepotinp
	move.w	d7,(a0)

	move.l	#36,d0
	move.l	#8,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#8,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print
.samepotinp:
	clr.l	d7
	move.b	$bfe001,d7
	lea	CIAAPRA-V(a6),a0
	cmp.w	(a0),d7
	beq	.samefire
	move.w	d7,(a0)

	btst	#6,$bfe001
	bne	.noport0
	move.w	#1,P0Fire-V(a6)
	bra	.p1
.noport0:
	move.w	#0,P0Fire-V(a6)
.p1:
	btst	#7,$bfe001
	bne	.noport1
	move.w	#1,P1Fire-V(a6)
	bra	.nop
.noport1:
	move.w	#0,P1Fire-V(a6)
.nop:
	move.l	#36,d0
	move.l	#9,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#9,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print
.samefire:
	clr.l	d0
	move.w	PortJoy0-V(a6),d0
	cmp.w	PortJoy0OLD-V(a6),d0
	beq	.samejoy0
	move.w	d0,PortJoy0OLD-V(a6)
	bsr	GetJoy
	move.l	d0,d7
	move.l	#0,d2
	bsr	PrintJoy

.samejoy0:

	clr.l	d0
	move.w	PortJoy1-V(a6),d0
	cmp.w	PortJoy1OLD-V(a6),d0
	beq	.samejoy1


	move.w	d0,PortJoy1OLD-V(a6)

	clr.l	d0
	move.w	PortJoy1-V(a6),d0
	bsr	GetJoy
	move.l	d0,d7
	move.l	#37,d2
	bsr	PrintJoy
.samejoy1:


	clr.l	d0
	move.w	P0Fire-V(a6),d0
	cmp.w	P0FireOLD-V(a6),d0
	beq	.samefire0

	TOGGLEPWRLED

	move.w	d0,P0FireOLD-V(a6)


	move.l	#19,d0
	move.l	#17,d1
	bsr	SetPos
	lea	FIRE,a0
	cmp.w	#0,P0Fire-V(a6)
	bne	.nop0
	move.l	#6,d1
	bra	.p0
.nop0:
	move.l	#1,d1
.p0:
	bsr	Print

.samefire0:


	clr.l	d0
	move.w	P1Fire-V(a6),d0
	cmp.w	P1FireOLD-V(a6),d0
	beq	.samefire1

	move.w	d0,P1FireOLD-V(a6)


	move.l	#56,d0
	move.l	#17,d1
	bsr	SetPos
	lea	FIRE,a0
	cmp.w	#0,P1Fire-V(a6)
	bne	.nop1
	move.l	#6,d1
	bra	.p2
.nop1:
	move.l	#1,d1
.p2:
	bsr	Print

.samefire1:



	bsr	GetInput

	cmp.b	#$1b,GetCharData-V(a6)
	beq	.exit

	cmp.b	#1,LMB-V(a6)
	bne	.loop
	cmp.b	#1,RMB-V(a6)
	bne	.loop
	
.exit:
	bra	PortTestMenu



PrintJoy:				; Print Joystatus
					; IN =	d7 = joydata
					;	d2 = how much to add in X axis
	move.l	#20,d0
	add.l	d2,d0
	move.l	#15,d1
	bsr	SetPos
	lea.l	UP,a0

	btst	#2,d7
	beq	.noup
	move.l	#1,d1				; 4 blue   6 cyan
	bra	.up
.noup:
	move.l	#6,d1
.up:
	bsr	Print


	move.l	#19,d0
	add.l	d2,d0
	move.l	#19,d1
	bsr	SetPos

	lea.l	DOWN,a0

	btst	#0,d7
	beq	.nodown
	move.l	#1,d1
	bra	.down
.nodown:
	move.l	#6,d1
.down:	
	bsr	Print


	move.l	#13,d0
	add.l	d2,d0
	move.l	#17,d1
	bsr	SetPos
	lea	LEFT,a0

	btst	#3,d7
	beq	.noleft
	move.l	#1,d1
	bra	.left
.noleft:
	move.l	#6,d1
.left:
	bsr	Print


	move.l	#25,d0
	add.l	d2,d0
	move.l	#17,d1
	bsr	SetPos
	lea	RIGHT,a0
	btst	#1,d7
	beq	.noright
	move.l	#1,d1
	bra	.right
.noright:
	move.l	#6,d1
.right:
	bsr	Print
	rts


GetJoy:
	;			IN d0=joy data
	;			OUT: D0   bits =  0=down, 1=right, 2=up, 3=left
	PUSH
	clr.l	d7
	move.l	d0,d6
	move.l	d0,d1
	and.w	#1,d1
	and.w	#2,d0
	asr.w	#1,d0
	eor.w	d1,d0
	btst	#0,d0
	beq	.nodown
	bset	#0,d7
.nodown:
	move.l	d6,d0
	btst	#1,d0
	beq	.noright
	bset	#1,d7
.noright:
	move.l	d0,d1
	and.w	#256,d1
	asr	#8,d1
	and.w	#512,d0
	asr	#8,d0

	asr.w	#1,d0
	eor.w	d1,d0
	btst	#0,d0
	beq	.noup
	bset	#2,d7
.noup:
	move.l	d6,d0
	asr.l	#8,d0
	btst	#1,d0
	beq	.noleft
	bset	#3,d7
.noleft:

	move.l	d7,temp-V(a6)
	POP
	move.l	temp-V(a6),d0
	rts


;------------------------------------------------------------------------------------------




KeyBoardTest:
	bsr	InitScreen
	lea	KeyBoardTestText,a0
	move.l	#7,d1
	bsr	Print
	lea	KeyBoardTestCodeTxt,a0
	move.l	#6,d1
	bsr	Print
	lea	KeyBoardTestCodeTxt2,a0
	move.l	#6,d1
	bsr	Print
	move.b	#0,KeyBOld-V(a6)

.loop:
	bsr	GetCharKey			; Get chardata
	bsr	WaitShort			; just wait a short time
	move.b	scancode-V(a6),d0
	cmp.b	#0,d0
	beq	.null				; If scancode was 0 we had noting

	move.b	KeyBOld-V(a6),d1
	cmp.b	d0,d1				; Check if it is the same as last scan
	beq	.samecode
	move.b	d0,KeyBOld-V(a6)


	move.l	#43,d0
	move.l	#2,d1
	bsr	SetPos
	lea	Space3,a0
	bsr	Print
	move.l	#43,d0
	move.l	#2,d1
	bsr	SetPos
	clr.l	d0
	move.b	scancode-V(a6),d0
	cmp.b	#116,d0				; is it 116? (esc released)
	beq	.exit
	bsr	bindec
	move.l	#3,d1
	bsr	Print

	move.l	#17,d0
	move.l	#3,d1
	bsr	SetPos

	move.b	scancode-V(a6),d0
	bsr	binstringbyte
	move.l	#3,d1
	bsr	Print

	move.l	#62,d0
	move.l	#2,d1
	bsr	SetPos
	lea	Space3,a0
	bsr	Print

	move.l	#62,d0
	move.l	#2,d1
	bsr	SetPos

	clr.l	d0
	move.b	key-V(a6),d0
	bsr	bindec
	move.l	#3,d1
	bsr	Print

	move.l	#69,d0
	move.l	#3,d1
	bsr	SetPos

	move.b	key-V(a6),d0
	bsr	binstringbyte
	move.l	#3,d1
	bsr	Print


	move.l	#73,d0
	move.l	#2,d1
	bsr	SetPos
	move.l	#2,d1

	lea	keyresult-V(a6),a0
	move.b	(a0),d0
	cmp.b	#0,d0				; Check if it was no char, then do not print
	beq	.samecode
	move.l	#3,d1
	bsr	MakePrintable
	bsr	PrintChar
.null:
.samecode:

	cmp.b	#$1b,Serial-V(a6)
	beq	.exit
	bsr	GetMouse
	cmp.b	#1,MBUTTON-V(a6)
	bne.w	.loop
.exit:

	bra	MainMenu

SSPError:
	lea	SSPErrorTxt,a0
	bra	ErrorScreen

BusError:
	lea	BusErrorTxt,a0
	bra	ErrorScreen

AddressError:
	lea	AddressErrorTxt,a0
	bra	ErrorScreen

IllegalError:
	lea	IllegalErrorTxt,a0
	bra	ErrorScreen

DivByZero:
	lea	DivByZeroTxt,a0
	bra	ErrorScreen

ChkInst:
	lea	ChkInstTxt,a0
	bra	ErrorScreen

TrapV:
	lea	TrapVTxt,a0
	bra	ErrorScreen

PrivViol:
	lea	PrivViolTxt,a0
	bra	ErrorScreen

Trace:
	lea	TraceTxt,a0
	bra	ErrorScreen

UnimplInst:
	lea	UnImplInstrTxt,a0
	bra	ErrorScreen
	
Trap:
	lea	TrapTxt,a0
	bra	ErrorScreen


HBLHandler:
	add.w	 #1,HLINE-V(a6)
	rte

VBLHandler:
	move.w	 #0,HLINE-V(a6)
	rte
		
POSTBusError:
	lea	BusErrorTxt,a0
	move.w	#$f00,d5
	move.l	#$fff,d6
	bra	POSTErrorScreen

POSTAddressError:
	lea	AddressErrorTxt,a0
	move.w	#$f00,d5
	move.l	#$f0f,d6
	bra	POSTErrorScreen

POSTIllegalError:
	lea	IllegalErrorTxt,a0
	move.w	#$f00,d5
	move.l	#$0ff,d6
	bra	POSTErrorScreen

POSTDivByZero:
	lea	DivByZeroTxt,a0
	move.w	#$f00,d5
	move.l	#$ff0,d6
	bra	POSTErrorScreen

POSTChkInst:
	lea	ChkInstTxt,a0
	move.w	#$f00,d5
	move.l	#$00f,d6
	bra	POSTErrorScreen

POSTTrapV:
	lea	TrapVTxt,a0
	move.w	#$000,d5
	move.l	#$fff,d6
	bra	POSTErrorScreen

POSTPrivViol:
	lea	PrivViolTxt,a0
	move.w	#$000,d5
	move.l	#$f0f,d6
	bra	POSTErrorScreen

POSTTrace:
	lea	TraceTxt,a0
	move.w	#$000,d5
	move.l	#$0ff,d6
	bra	POSTErrorScreen

POSTUnimplInst:
	lea	UnImplInstrTxt,a0
	move.w	#$000,d5
	move.l	#$ff0,d6
	bra	POSTErrorScreen

POSTErrorScreen:
	; move.w	#$200,$dff100
	; move.w	#0,$dff110

	move.l	a0,a2
	
	lea	NewLineTxt,a0		; Tell user on serialport that we are totally halted.
	lea	.post1,a1
	bra	DumpSerial
.post1:
	move.l	a2,a0
	adda.l	#1,a0			; Skip first char as we do not use it in this routine.
	lea	.post2,a1
	bra	DumpSerial

.post2:
	KPRINTSLN "- NO MEMORY FOUND - HALTING SYSTEM"
	
.loop:
	TOGGLEPWRLED		; Change value of Powerled.
	bne	.not
	move.w	d6,color0		; Set Screencolor to d6 (usual chipmemproblem color)
	bra	.yes
.not:
	move.w	d5,color0		; just every 2:nd turn, show a DARK green color instead. making the screen flash some.
.yes:
	move.l	#$ffff,d7		; Do a nonsense loop
.loopa:
	move.b	slowcia,d5		; Actually a nonsense read. but CIA space is slow to read from.
	move.b	slowcia,d5		; Actually a nonsense read. but CIA space is slow to read from.
	move.b	$400,d5
	dbf	d7,.loopa
	bra.w	.loop			; Loop forever




ErrorScreen:
;	bsr	ClearScreen	
	move.l	#1,d1
	bsr	Print
	bsr	DebugScreen

	bsr	WaitButton
	bra	MainMenu

;------------------------------------------------------------------------------------------

Setup:
	bsr	ClearScreen
	lea	SetupTxt,a0
	move.l	#1,d1
	bsr	Print
	bsr	DebugScreen
	bsr	WaitButton
	bra	MainMenu

;------------------------------------------------------------------------------------------

DevPrint:
	clr.l	d0
	move.l	#25,d1
	bsr	SetPos
	lea	UnderDevTxt,a0
	move.l	#1,d1
	bsr	Print
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	rts


NotImplemented:
	bsr	ClearScreen
	lea	NotImplTxt,a0
	move.l	#1,d1
	bsr	Print

	lea	AnyKeyMouseTxt,a0
	move.l	#2,d1
	bsr	Print
	
	bsr	DebugScreen
	bsr	WaitButton
	bra	MainMenu


DebugScreen:					; This dumps out registers..
	move.l	d0,DebD0-V(a6)			; first store everything in registers
	move.l	d1,DebD1-V(a6)			; and for visability etc.. I do several move instead of movem. dunno why :)
	move.l	d2,DebD2-V(a6)
	move.l	d3,DebD3-V(a6)
	move.l	d4,DebD4-V(a6)
	move.l	d5,DebD5-V(a6)
	move.l	d6,DebD6-V(a6)
	move.l	d7,DebD7-V(a6)
	move.l	a0,DebA0-V(a6)
	move.l	a1,DebA1-V(a6)
	move.l	a2,DebA2-V(a6)
	move.l	a3,DebA3-V(a6)
	move.l	a4,DebA4-V(a6)
	move.l	a5,DebA5-V(a6)
	move.l	a6,DebA6-V(a6)
	move.l	a7,DebA7-V(a6)			; OK now everything is stored.

	PUSH
	clr.l	d0
	move.l	#26,d1
	bsr	SetPos
	lea	DebugTxt,a0
	move.l	#3,d1
	bsr	Print

	clr.l	d0
	move.l	#27,d1
	bsr	SetPos
	move.l	DebD0-V(a6),d0
	bsr	binhex
	move.l	#2,d1
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD1-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD2-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD3-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD4-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD5-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD6-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD7-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA0-V(a6),d0
	bsr	binhex
	move.l	#3,d1
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA1-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA2-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA3-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA4-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA5-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA6-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA7-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	clr.l	d0
;	move.w	SR,d0
;	bsr	binhexword
;	bsr	Print
;	lea	SPACE,a0
;	bsr	Print
;	clr.l	d0
;	move.w	CCR,d0
;	bsr	binhexword
;	bsr	Print
	POP
	rts


DebugSerial:					; This dumps out registers..
	PUSH
	move.l	d0,DebD0-V(a6)			; first store everything in registers
	move.l	d1,DebD1-V(a6)			; and for visability etc.. I do several move instead of movem. dunno why :)
	move.l	d2,DebD2-V(a6)
	move.l	d3,DebD3-V(a6)
	move.l	d4,DebD4-V(a6)
	move.l	d5,DebD5-V(a6)
	move.l	d6,DebD6-V(a6)
	move.l	d7,DebD7-V(a6)
	move.l	a0,DebA0-V(a6)
	move.l	a1,DebA1-V(a6)
	move.l	a2,DebA2-V(a6)
	move.l	a3,DebA3-V(a6)
	move.l	a4,DebA4-V(a6)
	move.l	a5,DebA5-V(a6)
	move.l	a6,DebA6-V(a6)
	move.l	a7,DebA7-V(a6)			; OK now everything is stored.

	lea	DebugTxt,a0
	bsr	ForceSer

	lea	NewLineTxt,a0
	bsr	ForceSer
	lea	NewLineTxt,a0
	bsr	ForceSer
	move.l	DebD0-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD1-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD2-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD3-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD4-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD5-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD6-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD7-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	NewLineTxt,a0
	bsr	ForceSer
	move.l	DebA0-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA1-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA2-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA3-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA4-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA5-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA6-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA7-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	NewLineTxt,a0
	
	POP
	rts



ForceSer:					; For debug. print stuff on serialport. if port disabled force 9600BPS


						; Indata a0=string to send to serialport
						; nullterminated

	cmp.w	#0,SerialSpeed-V(a6)
	beq	.noserial
.serial:

	PUSH
	clr.l	d0				; Clear d0
.loop:
	move.b	(a0)+,d0
	cmp.b	#0,d0				; end of string?
	beq	.nomore				; yes
	bsr	.out

	bra.s	.loop
.nomore:
	POP
	rts


.out:						; Send what is in d0 to serialport
	PUSH

	move.l	#10000,d2			; Load d2 with a timeoutvariable. only test this number of times.
						; IF CIA for serialport is dead we will not end up in a wait-forever-loop.
						; and as we cannot use timers. we have to do this dirty style of coding...

	SENDSERIAL d0
	POP
	rts
.noserial:
	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd100			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c
	bra	.serial
DumpHexByte:				; PRE MEM-CODE!  dumps content of BYTE in d1 to serialport-
					; INDATA:
					;	D1 = byte to print
					;	A2 = address to jump after done

	lea	bytehextxt,a0
	clr.l	d2
	move.b	d1,d2
	asl	#1,d2
	add.l	d2,a0
	lea	.char1,a1
	bra	DumpSerialChar
.char1:
	lea	.char2,a1
	bra	DumpSerialChar
.char2:
	jmp	(a2)


DumpHexWord:	
	move.l	d1,d6
	asr	#8,d1
	lea	.byte3,a2
	bra	DumpHexByte		
.byte3:
	move.l	d6,d1
	lea	.byte4,a2
	bra	DumpHexByte
.byte4:
	jmp	(a3)
	

DumpHexLong:
					; Same as DumpHexByte but longword.
					; A3 is jumppointer for exit
	move.l	d1,d6
	swap	d1
	asr.l	#8,d1
	lea	.byte1,a2
	bra	DumpHexByte
.byte1:
	move.l	d6,d1
	swap	d1
	lea	.byte2,a2
	bra	DumpHexByte
.byte2:
	move.l	d6,d1
	asr	#8,d1
	lea	.byte3,a2
	bra	DumpHexByte		
.byte3:
	move.l	d6,d1
	lea	.byte4,a2
	bra	DumpHexByte
.byte4:
	jmp	(a3)


DumpSerial:				; This is only for PRE-Memory usage. Dumps a string to serialport.
					; IN:
					; a0 = String to put out on serial port.
					; a1 = where to jump after code is run. Remember we have NO stack
					; meaning that there is no place to store returnadresses for bsr/jsr
	
	clr.l	d7				; Clear d0
.loop:
	move.b	(a0)+,d7
	cmp.b	#0,d7				; end of string?
	beq	.nomore				; yes

	move.l	#10000,d2			; Load d2 with a timeoutvariable. only test this number of times.
						; IF CIA for serialport is dead we will not end up in a wait-forever-loop.
						; and as we cannot use timers. we have to do this dirty style of coding...
	SENDSERIAL d7
	bra.s	.loop
.nomore:
	jmp	(a1)				; AS we cannot use RTS (and bsr/jsr) jump here after we are done.


DumpSerialChar:				; This is only for PRE-Memory usage. Dumps a string to serialport.
					; IN:
					; a0 = pointer to char to print
					; a1 = where to jump after code is run. Remember we have NO stack
					; meaning that there is no place to store returnadresses for bsr/jsr
	
	clr.l	d7				; Clear d0
	move.b	(a0)+,d7
	move.l	#10000,d2			; Load d2 with a timeoutvariable. only test this number of times.
						; IF CIA for serialport is dead we will not end up in a wait-forever-loop.
						; and as we cannot use timers. we have to do this dirty style of coding...
DumpSerialCharD7:	
	SENDSERIAL d7
.nomore:
	jmp	(a1)				; AS we cannot use RTS (and bsr/jsr) jump here after we are done.



InputHexNum:					; Inputs a 32 bit hexnumber
						; INDATA
						;	A0 = Defualtaddress
	PUSH
	move.b	Xpos-V(a6),CheckMemManualX-V(a6)
	move.b	Ypos-V(a6),CheckMemManualY-V(a6); Store X and Y positions

	move.l	a0,d0				; Store the defaultaddress in d0
	bsr	binhex				; Convert it to hex
	adda.l	#1,a0				; Skip first $ sign in string
	move.l	#8,d0
	lea	CheckMemStartAdrTxt-V(a6),a1	; Clear workspace
.clearloop:
	clr.b	(a1,d0)
	dbf	d0,.clearloop
	move.l	#7,d0
	
	clr.l	d7				; Clear d7, if this is 0 later we had not had any 0 yet
.hexloop:
	move.b	(a0)+,d1			; Store char in d1
	cmp.b	#"0",d1				; is it a 0?
	bne	.nozero
	cmp.b	#0,d7				; Check if d7 is 0. if so, we will skip this
	beq	.zero
.nozero:
	move.b	d1,(a1)+			; Copy to where a1 points to
	move.b	#1,d7				; We had a nonzero.  set d7 to 1 so we handle 0 in the future
.zero:
	dbf	d0,.hexloop			; Copy string to defaultadress to be shown
	move.l	a0,shit-V(a6)

	lea	CheckMemStartAdrTxt-V(a6),a5	; Store pointer to string at a5
	move.l	a5,a0

	move.l	#7,d1
	bsr	Print				; Print it
	bsr	StrLen				; Get Stringlength
	move.l	d0,d6


	clr.l	d7				; Clear d7, this is the current position of the string
	sub.b	#1,d7				; Change d7 so we will force a update of cursor first time
.loop:
	bsr	GetMouse
	cmp.b	#1,RMB-V(a6)
	beq	.exit
	cmp.b	#1,LMB-V(a6)
	beq	.exit
	bsr	WaitShort
	bsr	GetChar				; Get a char from keyboard/serial
	bsr	WaitShort
	bsr	WaitShort
	cmp.b	#"x",d0				; did user press X?
	beq	.xpressed

.gethex:
	bsr	GetHex				; Strip it to hexnumbers
	cmp.b	#0,d0				; if returned value is 0, we had no keypress
	beq	.no
	cmp.b	#$1b,d0				; Was ESC pressed?
	beq	.exit				; if so, Exit
	cmp.b	#$a,d0				; did user press enter?
	beq	.enter				; if so, we are done

	cmp.b	#$8,d0				; Did we have a backspace?
	bne	.nobackspace			; no
						; oh. we had. lets erase one char
	move.b	#$0,(a5,d6)			; Store a null at that position
	cmp.b	#0,d6				; check if we are at the back?
	beq	.backmax			; yes, do not remove
	move.b	#" ",d0
	sub.b	#1,d6				; Subtract one
	move.b	d0,(a5,d6)			; Put char in memory
	bra	.back
.nobackspace:
	cmp.b	#8,d6				; Check if we have max number of chars
	beq	.nomore
	move.b	d0,(a5,d6)			; Put char in memory
	add.b	#1,d6

.back:
	move.l	#7,d1
	bsr	PrintChar			; Print the char
.backmax:
.nomore:

.no:	cmp.b	d6,d7				; Check if d6 and d7 is same, if not, update cursor
	beq	.same
	move.b	d6,d7
	bsr	.putcursor			; Put cursor
.same:
	bra	.loop

.exit:
	POP
	move.l	#-1,d0				; Show we had an exit
	rts
.xpressed:					; X is pressed, lets clear the whole area.
	clr.l	d6

	move.l	#7,d0
.xloop:
	move.b	#" ",(a5,d0)
	dbf	d0,.xloop
	clr.l	d7
	bsr	.putcursor
	lea	space8,a0
	move.l	#7,d1
	bsr	Print
	clr.l	d7
	bsr	.putcursor
	clr.l	d6
	clr.l	d0
	bra.w	.gethex
.enter:
	cmp.b	#0,d6				; was cursor at 0? then we had nothing
	beq	.exit
	bsr	.putcursor
	move.l	#" ",d0
	bsr	PrintChar			; Print a space to remove the old cursor

	clr.l	d6				; Clear d6, we need to check how many numbers we have

.countloop:
	move.b	(a5,d6),d0			; load char in string
	cmp.b	#0,d0				; is it a null?
	beq	.null
	cmp.b	#" ",d0				; same with space
	beq	.null
	add.b	#1,d6				; nope, so lets add 1 to the counter
	cmp.b	#8,d6				; Check if we actually DID have 8 chars, then no rotate of data is needed
	beq	.norotate
	bra	.countloop			; do it all over again

.null:						; ok we had a null, before doing 8 chars.
						; We had less then 8 chars, meaning we need to trimp it to 8 chars.
	move.l	d6,d7
	sub.b	#1,d7
	move.l	#7,d0
.copyloop2:
	move.b	(a5,d7),(a5,d0)
	sub.b	#1,d0
	dbf	d7,.copyloop2
						; ok now we have moved the data to the end of the string, lets fill up with 0
	move.l	#8,d0
	sub.b	d6,d0				; d0 now contains of how many 0 to put in
	sub.b	#1,d0
.fill:
	move.b	#"0",(a5,d0)
	dbf	d0,.fill
.norotate:
	move.b	CheckMemManualX-V(a6),d0
	move.b	CheckMemManualY-V(a6),d1
	sub.l	#1,d0				; Set cursor to the first adress, minus pone

	bsr	SetPos
	lea	CheckMemStartAdrTxt-V(a6),a0
	bsr	hexbin
	bsr	binhex
	move.l	#3,d1
	bsr	Print				; Print the result in yellow, so user can se the confirmed adress
	POP
	move.l	HexBinBin-V(a6),d0		; return the value
	rts

.putcursor:
	PUSH
	move.b	CheckMemManualX-V(a6),d0
	add.b	d7,d0				; Add postion to X pos to get correct position
	move.b	CheckMemManualY-V(a6),d1
	bsr	SetPos
	clr.l	d0
	move.b	(a5,d7),d0			; Load current char from string
	move.l	#11,d1
	bsr	PrintChar			; Print it reversed
	move.b	CheckMemManualX-V(a6),d0
	add.b	d7,d0				; Add postion to X pos to get correct position
	move.b	CheckMemManualY-V(a6),d1
	bsr	SetPos
	POP
	rts

WaitShort:					; Wait a short time, aprox 10 rasterlines. (or exact IF we have detected working raster)
	PUSH
	cmp.b	#1,RASTER-V(a6)			; Check if we have a confirmed working raster
	beq	.raster				
	move.l	#$1000,d0			; if now.  lets try to wait some anyway.
	bsr	ReadSerial			; as we have no IRQs..  read serialport just in case
.loop:
	move.b	slowcia,d1			; Dummyread from slow memory
	move.b	slowcia,d1			; Dummyread from slow memory
	dbf	d0,.loop
	POP
	rts
.raster:
	bsr	ReadSerial			; as we have no IRQs..  read serialport just in case

	move.l	 #VBLHandler,$70
	move.l	 #HBLHandler,$68

	move.w	sr,d0
	move.w   #$2000,sr
	move.w	#0,HLINE-V(a6)
.wait:
	cmp.w	#10,HLINE-V(a6)
	ble.s	.wait
	move.w   d0,sr
	POP
	rts


WaitLong:					; Wait a short time, aprox 10 rasterlines. (or exact IF we have detected working raster)
	PUSH
	cmp.b	#1,RASTER-V(a6)			; Check if we have a confirmed working raster
	beq	.raster
	move.w	#3,d1
	bsr	ReadSerial			; as we have no IRQs..  read serialport just in case
.loop2
	move.l	#$1000,d0			; if now.  lets try to wait some anyway.
.loop:
	move.b	slowcia,d2			; Dummyread from slow memory
	move.b	slowcia,d2
	dbf	d0,.loop
	dbf	d1,.loop2
	POP
	rts

.raster:

	move.l	 #VBLHandler,$70
	move.l	 #HBLHandler,$68

	move.w	sr,d0
	move.w   #$2000,sr
	move.w	#1,HLINE-V(a6)
.wait:
	cmp.w	#0,HLINE-V(a6)
	ble.s	.wait

	bsr	ReadSerial			; as we have no IRQs..  read serialport just in case

	move.w	#1,HLINE-V(a6)
.wait2:
	cmp.w	#0,HLINE-V(a6)
	ble.s	.wait2
	move.w   d0,sr
	POP
	rts


DefaultVars:					; Set defualtvalues
	move.l	a6,d0
	add.l	#EndData-V,d0
	move.l	d0,CheckMemEditScreenAdr-V(a6)
	rts

InitMfp:	
        ;; setup the serial port
	lea       (mfp_gpip).w,a0               ; init mfp address pointer
        moveq     #0,d0                     ; init to zero for clearing mfp
        movep.l   d0,0(a0)                  ; clear gpip thru iera
        movep.l   d0,8(a0)                  ; clear ierb thru isrb
        movep.l   d0,$10(a0)                ; clear isrb thru vr
	move.b    #$48,$16(a0)              ; set mfp autovector to $100 and s-bit	
        bset      #2,2(a0)                  ; set cts to low to high transition

	move.l	  #RTEcode,$114

        ;* init the "d" timer		
        moveq     #3,d0                     ; select the d timer
        moveq     #1,d1                     ; init for /4 for 9600 baud
        moveq     #2,d2                     ; init for 9600 baud
	move.l    #.ret,a4
        bra       settimer                  ; branch to out timer initialier...
.ret
	lea       (mfp_gpip).w,a0
        move.l    #$880105,d0
        movep.l   d0,$26(a0)                ; inits scr,ucr,rsr,tsr
	jmp       (a5)
	
***********************************************************************************
*                                                                                 *
*                routine to set up a timer                                        *
*                                                                                 *
*                algorithm to init a timer                                        *
*                                                                                 *
*                1.  determine which timer and set d0.b = to timer's index value  *
*                    as shown below;                                              *
*                2.  disable the associated interrupt;                            *
*                3.  disable the timer itself via it's timer control register;    *
*                4.  initialize the timer's data register                         *
*                5.  repeat step #4 until the data register's contents are        *
*                    verified, per the errata sheet to the 68901 description;     *
*                6.  turn on the timer by using the value that you previously     *
*                    stored in d1;                                                *
*                                                                                 *
*                note:    the interrupt vector for the associated timer           *
*                         is not set in this routine, so it is the user's         *
*                         responsiblity to set it if so desired!                  *
*                                                                                 *
*                                                                                 *
*                registers used:          d0-d3/a0-a3                             *
*                registers saved:         d0-d3/a0-a3                             *
*                entry:                                                           *
*                        d0.l - timer to be set                                   *
*                                0 - timer a                                      *
*                                1 - timer b                                      *
*                                2 - timer c                                      *
*                                3 - timer d                                      *
*                        d1.b - timer's new control setting                       *
*                        d2.b - timer's data register data                        *
*                                                                                 *
*                exit:   no values to pass                                        *
*                                                                                 *
*                        d3   - used and abused by call to mskreg routine         *
*                        a0.l - set to mfp register base                          *
*                        a1.l - temporary location for a3                         *
*                        a2.l - used to pass table address to mskreg routine      *
*                        a3.l - used to pass table address to mskreg routine      *
*                                                                                 *
***********************************************************************************
settimer:   
            lea	      mfp_gpip,a0                  ; set mfp chip address pointer

            movea.l   #imrt,a3                  ; mask off the timer's interrupt maskable bit
            movea.l   #imrmt,a2
            MSKREG

            movea.l   #iert,a3                  ; mask off the timer's interrupt enable bit
            movea.l   #imrmt,a2
            MSKREG

            movea.l   #iprt,a3                  ; mask off the timer's interrupt pending bit
            movea.l   #imrmt,a2
            MSKREG

            movea.l   #isrt,a3                  ; mask off the timer's interrupt inservice bit
            movea.l   #imrmt,a2
            MSKREG

            movea.l   #tcrtab,a3                ; mask off the timer's control bits
            movea.l   #tcrmsk,a2
            MSKREG 

            exg       a3,a1                     ; save address pointer for restoring control

            lea       (tdrtab).l,a3             ; initialize the timer data register
            moveq     #0,d3                     ; to prevent false effective address generation
            move.b    (a3,d0.w),d3
verify:     move.b    d2,(a0,d3.w)
            cmp.b     (a0,d3.w),d2
            bne.s     verify

            exg       a3,a1                     ; grab that register address back
            or.b      d1,(a3)                   ; mask the timer control register value

            jmp	     (a4)

GetHWReg:					; Dumps all readable HW registers to memory
	
	move.b	memconf,_MEMCONF-V(a6)
	move.b  v_sync,_V_SYNC-V(a6)
	move.b  v_mode,_V_MODE-V(a6)

	move.b  v_bas_h,_V_BAS_H-V(a6)
	move.b  v_bas_m,_V_BAS_M-V(a6)
	move.b  v_bas_l,_V_BAS_L-V(a6)

	move.b  v_adr_h,_V_ADR_H-V(a6)
	move.b  v_adr_m,_V_ADR_M-V(a6)
	move.b  v_adr_l,_V_ADR_L-V(a6)

	rts
	move.w	$dff002,DMACONR-V(a6)
	move.w	$dff004,VPOSR-V(a6)
	move.w	$dff006,VHPOSR-V(a6)
	move.w	$dff008,DSKDATR-V(a6)
	move.w	$dff00a,JOY0DAT-V(a6)
	move.w	$dff00c,JOY1DAT-V(a6)
	move.w	$dff00e,CLXDAT-V(a6)
	move.w	$dff010,ADKCONR-V(a6)
	move.w	$dff012,POT0DAT-V(a6)
	move.w	$dff014,POT1DAT-V(a6)
;	move.w	$dff016,POTINP-V(a6)
	move.w	$dff018,SERDATR-V(a6)
	move.w	$dff01a,DSKBYTR-V(a6)
	move.w	$dff01c,INTENAR-V(a6)
	move.w	$dff01e,INTREQR-V(a6)
	move.w	$dff07c,DENISEID-V(a6)
	move.w	$dff1da,HHPOSR-V(a6)
	rts

PrintHWReg:

	HWRegPrintByte _MEMCONF, "MEMCONF  ($FF8001): "

	lea	Space3,a0
	bsr	Print

	HWRegPrintByte _V_SYNC, "V_RES    ($FF8260): "

	lea	Space3,a0
	bsr	Print

	HWRegPrintByte _V_MODE, "V_MODE   ($FF820A): "

	lea	NewLineTxt,a0
	bsr	Print

	; -----------------------------------

	HWRegPrintByte _V_BAS_H, "V_BAS_H  ($FF8201): "

	lea	Space3,a0
	bsr	Print

	HWRegPrintByte _V_BAS_M, "V_BAS_M  ($FF8203): "

	lea	Space3,a0
	bsr	Print

	HWRegPrintByte _V_BAS_L, "V_BAS_L  ($FF820D): "

	lea	NewLineTxt,a0
	bsr	Print

	; -----------------------------------

	HWRegPrintByte _V_ADR_H, "V_ADR_H  ($FF8205): "

	lea	Space3,a0
	bsr	Print

	HWRegPrintByte _V_ADR_M, "V_ADR_M  ($FF8207): "

	lea	Space3,a0
	bsr	Print

	HWRegPrintByte _V_ADR_L, "V_ADR_L  ($FF8209): "

	lea	NewLineTxt,a0
	bsr	Print

	rts

RTEcode:					; Just to have something to point IRQ to.. doing nothing
	rte

GetChip:					; Gets extra chipmem below the reserved workarea.
						; IN = D0=Size requested
						; OUT = D0=Startaddress of chipmem.  1=not enough, 0=no chipmem
	PUSH


	clr.l	GetChipAddr-V(a6)		; Clear the address replied.
	cmp.l	#0,TotalChip-V(a6)		; if there are no chipmem, exit
	beq	.exit	

	move.l	ChipUnreserved-V(a6),d1		; Get total amount of nonused chipmem
	cmp.l	d0,d1				; Compare it with amount of mem wanted
	blt	.low				; we did not have enough. exit

	move.l	ChipUnreservedAddr-V(a6),d1	; ok load d1 with value of last usable noreserved chipmemarea
	sub.l	d0,d1				; Subtract with amount of memory wanted
	move.l	d1,GetChipAddr-V(a6)		; Store it to returnvalue

	move.l	d1,a0				; Now lets clear the ram
	asr.l	#2,d0
.loop:
	clr.l	(a0)+
	dbf	d0,.loop	



	bra	.exit

.low:
	move.l	#1,GetChipAddr-V(a6)		; put 1 into returnvalue, telling we did not have enough mem.
.exit:
	POP
	move.l	GetChipAddr-V(a6),d0		; Return the value
	rts

FilterOFF:
	rts
FilterON:
	rts

	;	This is the protrackerreplayer, to be copied to chipmem due to the fact it would require too mucg
	; 	of reprogramming to make it work in ROM. <-  YUPP!  being a lazy fuck



* ProTracker2.2a replay routine by Crayon/Noxious. Improved and modified
* by Teeme of Fist! Unlimited in 1992. Share and enjoy! :)
* Rewritten for Devpac (slightly..) by CJ. Devpac does not like bsr.L
* cmpi is compare immediate, it requires immediate data! And some
* labels had upper/lower case wrong...
*
* Now improved to make it work better if CIA timed - thanks Marco!

* Call MT_Init with A0 pointing to your module data...
* mastervolumepatch by Chucky of The Gang
* mt_mastervol is a byte  0 to 64 containing the mastervolume


N_Note = 0  ; W
N_Cmd = 2  ; W
N_Cmdlo = 3  ; B
N_Start = 4  ; L
N_Length = 8  ; W
N_LoopStart = 10 ; L
N_Replen = 14 ; W
N_Period = 16 ; W
N_FineTune = 18 ; B
N_Volume = 19 ; B
N_DMABit = 20 ; W
N_TonePortDirec = 22 ; B
N_TonePortSpeed = 23 ; B
N_WantedPeriod = 24 ; W
N_VibratoCmd = 26 ; B
N_VibratoPos = 27 ; B
N_TremoloCmd = 28 ; B
N_TremoloPos = 29 ; B
N_WaveControl = 30 ; B
N_GlissFunk = 31 ; B
N_SampleOffset = 32 ; B
N_PattPos = 33 ; B
N_LoopCount = 34 ; B
N_FunkOffset = 35 ; B
N_WaveStart = 36 ; L
N_RealLength = 40 ; W
MT_SizeOf = 42*4+22
MT_SongDataPtr = -18
MT_Speed = -14
MT_Counter = -13
MT_SongPos = -12
MT_PBreakPos = -11
MT_PosJumpFlag = -10
MT_PBreakFlag = -9
MT_LowMask = -8
MT_PattDelTime = -7
MT_PattDelTime2 = -6
MT_PatternPos = -4
MT_DMACONTemp = -2
MT_CiaSpeed = 0
MT_Signal = 2
MT_TimerSpeed = 4
MT_CiaBase = 8
MT_CiaTimer = 12
MT_Volume = 14

MT_Init:
	move.l	a5,-(sp)
	lea	MT_Variables(pc),a5
	move.l	a0,MT_SongDataPtr(a5)
	lea	952(a0),a1
	moveq	#127,D0
	moveq	#0,D1
MTLoop:
	move.l	d1,d2
	subq.w	#1,d0
MTLoop2:
	move.b	(a1)+,d1
	cmp.b	d2,d1
	bgt.s	MTLoop
	dbf	d0,MTLoop2
	addq.b	#1,d2
			
	move.l	a5,a1
	suba.w	#142,a1
	asl.l	#8,d2
	asl.l	#2,d2
	addi.l	#1084,d2
	add.l	a0,d2
	move.l	d2,a2
	moveq	#30,d0
MTLoop3:
;	clr.l	(a2)
	move.l	a2,(a1)+
	moveq	#0,d1
	move.w	42(a0),d1
	add.l	d1,d1
	add.l	d1,a2
	adda.w	#30,a0
	dbf	d0,MTLoop3

	ori.b	#2,$bfe001
	move.b	#6,MT_Speed(a5)
	clr.b	MT_Counter(a5)
	clr.b	MT_SongPos(a5)
	clr.w	MT_PatternPos(a5)
	move.l	(sp)+,a5
MT_End:	clr.w	$0A8(a5)
	clr.w	$0B8(a5)
	clr.w	$0C8(a5)
	clr.w	$0D8(a5)
	move.w	#$f,$096(a5)
	rts

MT_Music:
	movem.l	d0-d4/a0-a6,-(a7)
	move.l	a5,a6
	lea	MT_Variables(pc),a5
	addq.b	#1,MT_Counter(a5)
	move.b	MT_Counter(a5),d0
	cmp.b	MT_Speed(a5),d0
	blo.s	MT_NoNewNote
	clr.b	MT_Counter(a5)
	tst.b	MT_PattDelTime2(a5)
	beq	MT_GetNewNote
	bsr.s	MT_NoNewAllChannels
	bra	MT_Dskip

	IFD	ST_CiaOn
MT_SetCia
	movem.l	a0/d0/d2,-(sp)
	cmp.w	#32,d0
	bge.s	.right
	moveq.l	#32,d0
.right	and.w	#$FF,d0
	move.w	d0,MT_CiaSpeed(a5)
	move.l	MT_TimerSpeed(a5),d2
	divu	d0,d2
	tst.w	MT_CiaTimer(a5)
	beq.s	.settia
	move.l	MT_CiaBase(a5),a0
	move.b	d2,ciatblo(a0)
	lsr.w	#8,d2
	move.b	d2,ciatbhi(a0)
.skip	movem.l	(sp)+,a0/d0/d2
	rts
.settia	move.l	MT_CiaBase(a5),a0
	move.b	d2,ciatalo(a0)
	lsr.w	#8,d2
	move.b	d2,ciatahi(a0)
	movem.l	(sp)+,a0/d0/d2
	rts
	ENDC

MT_NoNewNote:
	bsr.s	MT_NoNewAllChannels
	bra	MT_NoNewPosYet
MT_NoNewAllChannels:
	move.w	#$a0,d5
	move.l	a5,a4
	suba.w	#318,a4
	bsr	MT_CheckEfx
	move.w	#$b0,d5
	adda.w	#44,a4
	bsr	MT_CheckEfx
	move.w	#$c0,d5
	adda.w	#44,a4
	bsr	MT_CheckEfx
	move.w	#$d0,d5
	adda.w	#44,a4
	bra	MT_CheckEfx
MT_GetNewNote:
	move.l	MT_SongDataPtr(a5),a0
	lea	12(a0),a3
	lea	952(a0),a2	;pattpo
	lea	1084(a0),a0	;patterndata
	moveq	#0,d0
	moveq	#0,d1
	move.b	MT_SongPos(a5),d0
	move.b	(a2,d0.w),d1
	asl.l	#8,d1
	asl.l	#2,d1
	add.w	MT_PatternPos(a5),d1
	clr.w	MT_DMACONTemp(a5)

	move.w	#$a0,d5
	move.l	a5,a4
	suba.w	#318,a4
	bsr.s	MT_PlayVoice
	move.w	#$b0,d5
	adda.w	#44,a4
	bsr.s	MT_PlayVoice
	move.w	#$c0,d5
	adda.w	#44,a4
	bsr.s	MT_PlayVoice
	move.w	#$d0,d5
	adda.w	#44,a4
	bsr.s	MT_PlayVoice
	bra	MT_SetDMA

MT_PlayVoice:
	tst.l	(a4)
	bne.s	MT_PlvSkip
	bsr	MT_PerNop
MT_PlvSkip:
	move.l	(a0,d1.l),(a4)
	addq.l	#4,d1
	moveq	#0,d2
	move.b	N_Cmd(a4),d2
	andi.b	#$f0,d2
	lsr.b	#4,d2
	move.b	(a4),d0
	andi.b	#$f0,d0
	or.b	d0,d2
	beq	MT_SetRegs
	moveq	#0,d3
	move.l	a5,a1
	suba.w	#142,a1
	move	d2,d4
	subq.l	#1,d2
	asl.l	#2,d2
	mulu	#30,d4
	move.l	(a1,d2.l),N_Start(a4)
	move.w	(a3,d4.l),N_Length(a4)
	move.w	(a3,d4.l),N_RealLength(a4)
	move.b	2(a3,d4.l),N_FineTune(a4)
	move.b	3(a3,d4.l),N_Volume(a4)
	move.w	4(a3,d4.l),d3 ; Get repeat
	beq.s	MT_NoLoop
	move.l	N_Start(a4),d2 ; Get start
	add.w	d3,d3
	add.l	d3,d2		; Add repeat
	move.l	d2,N_LoopStart(a4)
	move.l	d2,N_WaveStart(a4)
	move.w	4(a3,d4.l),d0	; Get repeat
	add.w	6(a3,d4.l),d0	; Add replen
	move.w	d0,N_Length(a4)
	move.w	6(a3,d4.l),N_Replen(a4)	; Save replen
	moveq	#0,d0
	move.b	N_Volume(a4),d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)	; Set volume
	bra.s	MT_SetRegs

MT_NoLoop:
	move.l	N_Start(a4),d2
	add.l	d3,d2
	move.l	d2,N_LoopStart(a4)
	move.l	d2,N_WaveStart(a4)
	move.w	6(a3,d4.l),N_Replen(a4)	; Save replen
	moveq	#0,d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	move.b	N_Volume(a4),d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)	; Set volume
MT_SetRegs:
	move.w	(a4),d0
	andi.w	#$0fff,d0
	beq	MT_CheckMoreEfx	; If no note
	move.w	2(a4),d0
	andi.w	#$0ff0,d0
	cmpi.w	#$0e50,d0
	beq.s	MT_DoSetFineTune
	move.b	2(a4),d0
	andi.b	#$0f,d0
	cmpi.b	#3,d0	; TonePortamento
	beq.s	MT_ChkTonePorta
	cmpi.b	#5,d0
	beq.s	MT_ChkTonePorta
	cmpi.b	#9,d0	; Sample Offset
	bne.s	MT_SetPeriod
	bsr	MT_CheckMoreEfx
	bra.s	MT_SetPeriod

MT_DoSetFineTune:
	bsr	MT_SetFineTune
	bra.s	MT_SetPeriod

MT_ChkTonePorta:
	bsr	MT_SetTonePorta
	bra	MT_CheckMoreEfx

MT_SetPeriod:
	movem.l	d0-d1/a0-a1,-(a7)
	move.w	(a4),d1
	andi.w	#$0fff,d1
	lea	MT_PeriodTable(pc),a1
	moveq	#0,d0
	moveq	#36,d7
MT_FtuLoop:
	cmp.w	(a1,d0.w),d1
	bhs.s	MT_FtuFound
	addq.l	#2,d0
	dbf	d7,MT_FtuLoop
MT_FtuFound:
	moveq	#0,d1
	move.b	N_FineTune(a4),d1
	mulu	#72,d1
	add.l	d1,a1
	move.w	(a1,d0.w),N_Period(a4)
	movem.l	(a7)+,d0-d1/a0-a1

	move.w	2(a4),d0
	andi.w	#$0ff0,d0
	cmpi.w	#$0ed0,d0 ; Notedelay
	beq	MT_CheckMoreEfx

	move.w	N_DMABit(a4),$096(a6)
	btst	#2,N_WaveControl(a4)
	bne.s	MT_Vibnoc
	clr.b	N_VibratoPos(a4)
MT_Vibnoc:
	btst	#6,N_WaveControl(a4)
	bne.s	MT_Trenoc
	clr.b	N_TremoloPos(a4)
MT_Trenoc:
	move.l	N_Start(a4),(a6,d5.w)	; Set start
	move.w	N_Length(a4),4(a6,d5.w)	; Set length
	move.w	N_Period(a4),d0
	move.w	d0,6(a6,d5.w)		; Set period
	move.w	N_DMABit(a4),d0
	or.w	d0,MT_DMACONTemp(a5)
	bra	MT_CheckMoreEfx
 
MT_SetDMA:
	bsr	MT_DMAWaitLoop
	move.w	MT_DMACONTemp(a5),d0
	ori.w	#$8000,d0
	move.w	d0,$096(a6)
	bsr	MT_DMAWaitLoop
	move.l	a5,a4
	suba.w	#186,a4
	move.l	N_LoopStart(a4),$d0(a6)
	move.w	N_Replen(a4),$d4(a6)
	suba.w	#44,a4
	move.l	N_LoopStart(a4),$c0(a6)
	move.w	N_Replen(a4),$c4(a6)
	suba.w	#44,a4
	move.l	N_LoopStart(a4),$b0(a6)
	move.w	N_Replen(a4),$b4(a6)
	suba.w	#44,a4
	move.l	N_LoopStart(a4),$a0(a6)
	move.w	N_Replen(a4),$a4(a6)

MT_Dskip:
	addi.w	#16,MT_PatternPos(a5)
	move.b	MT_PattDelTime(a5),d0
	beq.s	MT_Dskc
	move.b	d0,MT_PattDelTime2(a5)
	clr.b	MT_PattDelTime(a5)
MT_Dskc:
	tst.b	MT_PattDelTime2(a5)
	beq.s	MT_Dska
	subq.b	#1,MT_PattDelTime2(a5)
	beq.s	MT_Dska
	sub.w	#16,MT_PatternPos(a5)
MT_Dska:
	tst.b	MT_PBreakFlag(a5)
	beq.s	MT_Nnpysk
	clr.b	MT_PBreakFlag(a5)
	moveq	#0,d0
	move.b	MT_PBreakPos(a5),d0
	clr.b	MT_PBreakPos(a5)
	lsl.w	#4,d0
	move.w	d0,MT_PatternPos(a5)
MT_Nnpysk:
	cmpi.w	#1024,MT_PatternPos(a5)
	blo.s	MT_NoNewPosYet
MT_NextPosition:	
	moveq	#0,d0
	move.b	MT_PBreakPos(a5),d0
	lsl.w	#4,d0
	move.w	d0,MT_PatternPos(a5)
	clr.b	MT_PBreakPos(a5)
	clr.b	MT_PosJumpFlag(a5)
	addq.b	#1,MT_SongPos(a5)
	andi.b	#$7F,MT_SongPos(a5)
	move.b	MT_SongPos(a5),d1
	move.l	MT_SongDataPtr(a5),a0
	cmp.b	950(a0),d1
	blo.s	MT_NoNewPosYet
	clr.b	MT_SongPos(a5)
	st	MT_Signal(a5)
MT_NoNewPosYet:	
	tst.b	MT_PosJumpFlag(a5)
	bne.s	MT_NextPosition
	movem.l	(a7)+,d0-d4/a0-a6
	rts

MT_CheckEfx:
	bsr	MT_UpdateFunk
	move.w	N_Cmd(a4),d0
	andi.w	#$0fff,d0
	beq.s	MT_PerNop
	move.b	N_Cmd(a4),d0
	andi.b	#$0f,d0
	beq.s	MT_Arpeggio
	cmpi.b	#1,d0
	beq	MT_PortaUp
	cmpi.b	#2,d0
	beq	MT_PortaDown
	cmpi.b	#3,d0
	beq	MT_TonePortamento
	cmpi.b	#4,d0
	beq	MT_Vibrato
	cmpi.b	#5,d0
	beq	MT_TonePlusVolSlide
	cmpi.b	#6,d0
	beq	MT_VibratoPlusVolSlide
	cmpi.b	#$E,d0
	beq	MT_E_Commands
SetBack:
	move.w	N_Period(a4),6(a6,d5.w)
	cmpi.b	#7,d0
	beq	MT_Tremolo
	cmpi.b	#$a,d0
	beq	MT_VolumeSlide
MT_Return2:
	rts

MT_PerNop:
	move.b	N_Volume(a4),d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)	; Set volume
	move.w	N_Period(a4),6(a6,d5.w)
	rts

MT_Arpeggio:
	moveq	#0,d0
	move.b	MT_Counter(a5),d0
	divs	#3,d0
	swap	d0
	tst.w	D0
	beq.s	MT_Arpeggio2
	cmpi.w	#2,d0
	beq.s	MT_Arpeggio1
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	lsr.b	#4,d0
	bra.s	MT_Arpeggio3

MT_Arpeggio1:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#15,d0
	bra.s	MT_Arpeggio3

MT_Arpeggio2:
	move.w	N_Period(a4),d2
	bra.s	MT_Arpeggio4

MT_Arpeggio3:
	add.w	d0,d0
	moveq	#0,d1
	move.b	N_FineTune(a4),d1
	mulu	#72,d1
	lea	MT_PeriodTable(pc),a0
	add.w	d1,a0
	moveq	#0,d1
	move.w	N_Period(a4),d1
	moveq	#36,d7
MT_ArpLoop:
	move.w	(a0,d0.w),d2
	cmp.w	(a0),d1
	bhs.s	MT_Arpeggio4
	addq.w	#2,a0
	dbf	d7,MT_ArpLoop
	rts

MT_Arpeggio4:
	move.w	d2,6(a6,d5.w)
	rts

MT_FinePortaUp:
	tst.b	MT_Counter(a5)
	bne.w	MT_Return2
	move.b	#$0f,MT_LowMask(a5)
MT_PortaUp:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	and.b	MT_LowMask(a5),d0
	st	MT_LowMask(a5)
	sub.w	d0,N_Period(a4)
	move.w	N_Period(a4),d0
	andi.w	#$0fff,d0
	cmpi.w	#113,d0
	bpl.s	MT_PortaUskip
	andi.w	#$f000,N_Period(a4)
	ori.w	#113,N_Period(a4)
MT_PortaUskip:
	move.w	N_Period(a4),d0
	andi.w	#$0fff,d0
	move.w	d0,6(a6,d5.w)
	rts
 
MT_FinePortaDown:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	move.b	#$0f,MT_LowMask(a5)
MT_PortaDown:
	clr.w	d0
	move.b	N_Cmdlo(a4),d0
	and.b	MT_LowMask(a5),d0
	st	MT_LowMask(a5)
	add.w	d0,N_Period(a4)
	move.w	N_Period(a4),d0
	andi.w	#$0fff,d0
	cmpi.w	#856,d0
	bmi.s	MT_PortaDskip
	andi.w	#$f000,N_Period(a4)
	ori.w	#856,N_Period(a4)
MT_PortaDskip:
	move.w	N_Period(a4),d0
	andi.w	#$0fff,d0
	move.w	d0,6(a6,d5.w)
	rts

MT_SetTonePorta:
	move.l	a0,-(a7)
	move.w	(a4),d2
	andi.w	#$0fff,d2
	moveq	#0,d0
	move.b	N_FineTune(a4),d0
	mulu	#74,d0
	lea	MT_PeriodTable(pc),a0
	add.w	d0,a0
	moveq	#0,d0
MT_StpLoop:
	cmp.w	(a0,d0.w),d2
	bhs.s	MT_StpFound
	addq.w	#2,d0
	cmpi.w	#74,d0
	blo.s	MT_StpLoop
	moveq	#70,d0
MT_StpFound:
	move.b	N_FineTune(a4),d2
	andi.b	#8,d2
	beq.s	MT_StpGoss
	tst.w	d0
	beq.s	MT_StpGoss
	subq.w	#2,d0
MT_StpGoss:
	move.w	(a0,d0.w),d2
	move.l	(a7)+,a0
	move.w	d2,N_WantedPeriod(a4)
	move.w	N_Period(a4),d0
	clr.b	N_TonePortDirec(a4)
	cmp.w	d0,d2
	beq.s	MT_ClearTonePorta
	bge	MT_Return2
	move.b	#1,N_TonePortDirec(a4)
	rts

MT_ClearTonePorta:
	clr.w	N_WantedPeriod(a4)
	rts

MT_TonePortamento:
	move.b	N_Cmdlo(a4),d0
	beq.s	MT_TonePortNoChange
	move.b	d0,N_TonePortSpeed(a4)
	clr.b	N_Cmdlo(a4)
MT_TonePortNoChange:
	tst.w	N_WantedPeriod(a4)
	beq	MT_Return2
	moveq	#0,d0
	move.b	N_TonePortSpeed(a4),d0
	tst.b	N_TonePortDirec(a4)
	bne.s	MT_TonePortaUp
MT_TonePortaDown:
	add.w	d0,N_Period(a4)
	move.w	N_WantedPeriod(a4),d0
	cmp.w	N_Period(a4),d0
	bgt.s	MT_TonePortaSetPer
	move.w	N_WantedPeriod(a4),N_Period(a4)
	clr.w	N_WantedPeriod(a4)
	bra.s	MT_TonePortaSetPer

MT_TonePortaUp:
	sub.w	d0,N_Period(a4)
	move.w	N_WantedPeriod(a4),d0
	cmp.w	N_Period(a4),d0     	; was cmpi!!!!
	blt.s	MT_TonePortaSetPer
	move.w	N_WantedPeriod(a4),N_Period(a4)
	clr.w	N_WantedPeriod(a4)

MT_TonePortaSetPer:
	move.w	N_Period(a4),d2
	move.b	N_GlissFunk(a4),d0
	andi.b	#$0f,d0
	beq.s	MT_GlissSkip
	moveq	#0,d0
	move.b	N_FineTune(a4),d0
	mulu	#72,d0
	lea	MT_PeriodTable(pc),a0
	add.w	d0,a0
	moveq	#0,d0
MT_GlissLoop:
	cmp.w	(a0,d0.w),d2
	bhs.s	MT_GlissFound
	addq.w	#2,d0
	cmpi.w	#72,d0
	blo.s	MT_GlissLoop
	moveq	#70,d0
MT_GlissFound:
	move.w	(a0,d0.w),d2
MT_GlissSkip:
	move.w	d2,6(a6,d5.w) ; Set period
	rts

MT_Vibrato:
	move.b	N_Cmdlo(a4),d0
	beq.s	MT_Vibrato2
	move.b	N_VibratoCmd(a4),d2
	andi.b	#$0f,d0
	beq.s	MT_VibSkip
	andi.b	#$f0,d2
	or.b	d0,d2
MT_VibSkip:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$f0,d0
	beq.s	MT_VibSkip2
	andi.b	#$0f,d2
	or.b	d0,d2
MT_VibSkip2:
	move.b	d2,N_VibratoCmd(a4)
MT_Vibrato2:
	move.b	N_VibratoPos(a4),d0
	lea	MT_VibratoTable(pc),a0
	lsr.w	#2,d0
	andi.w	#$001f,d0
	moveq	#0,d2
	move.b	N_WaveControl(a4),d2
	andi.b	#$03,d2
	beq.s	MT_Vib_Sine
	lsl.b	#3,d0
	cmpi.b	#1,d2
	beq.s	MT_Vib_RampDown
	st	d2
	bra.s	MT_Vib_Set
MT_Vib_RampDown:
	tst.b	N_VibratoPos(a4)
	bpl.s	MT_Vib_RampDown2
	st	d2
	sub.b	d0,d2
	bra.s	MT_Vib_Set
MT_Vib_RampDown2:
	move.b	d0,d2
	bra.s	MT_Vib_Set
MT_Vib_Sine:
	move.b	(a0,d0.w),d2
MT_Vib_Set:
	move.b	N_VibratoCmd(a4),d0
	andi.w	#15,d0
	mulu	d0,d2
	lsr.w	#7,d2
	move.w	N_Period(a4),d0
	tst.b	N_VibratoPos(a4)
	bmi.s	MT_VibratoNeg
	add.w	d2,d0
	bra.s	MT_Vibrato3
MT_VibratoNeg:
	sub.w	d2,d0
MT_Vibrato3:
	move.w	d0,6(a6,d5.w)
	move.b	N_VibratoCmd(a4),d0
	lsr.w	#2,d0
	andi.w	#$3C,d0
	add.b	d0,N_VibratoPos(a4)
	rts

MT_TonePlusVolSlide:
	bsr	MT_TonePortNoChange
	bra	MT_VolumeSlide

MT_VibratoPlusVolSlide:
	bsr.s	MT_Vibrato2
	bra	MT_VolumeSlide

MT_Tremolo:
	move.b	N_Cmdlo(a4),d0
	beq.s	MT_Tremolo2
	move.b	N_TremoloCmd(a4),d2
	andi.b	#$0f,d0
	beq.s	MT_TreSkip
	andi.b	#$f0,d2
	or.b	d0,d2
MT_TreSkip:
	move.b	N_Cmdlo(a4),d0
	and.b	#$f0,d0
	beq.s	MT_TreSkip2
	andi.b	#$0f,d2
	or.b	d0,d2
MT_TreSkip2:
	move.b	d2,N_TremoloCmd(a4)
MT_Tremolo2:
	move.b	N_TremoloPos(a4),d0
	lea	MT_VibratoTable(pc),a0
	lsr.w	#2,d0
	andi.w	#$1f,d0
	moveq	#0,d2
	move.b	N_WaveControl(a4),d2
	lsr.b	#4,d2
	andi.b	#3,d2
	beq.s	MT_Tre_Sine
	lsl.b	#3,d0
	cmpi.b	#1,d2
	beq.s	MT_Tre_RampDown
	st	d2
	bra.s	MT_Tre_Set
MT_Tre_RampDown:
	tst.b	N_VibratoPos(a4)
	bpl.s	MT_Tre_RampDown2
	st	d2
	sub.b	d0,d2
	bra.s	MT_Tre_Set
MT_Tre_RampDown2:
	move.b	d0,d2
	bra.s	MT_Tre_Set
MT_Tre_Sine:
	move.b	(a0,d0.w),d2
MT_Tre_Set:
	move.b	N_TremoloCmd(a4),d0
	andi.w	#15,d0
	mulu	d0,d2
	lsr.w	#6,d2
	moveq	#0,d0
	move.b	N_Volume(a4),d0
	tst.b	N_TremoloPos(a4)
	bmi.s	MT_TremoloNeg
	add.w	d2,d0
	bra.s	MT_Tremolo3
MT_TremoloNeg:
	sub.w	d2,d0
MT_Tremolo3:
	bpl.s	MT_TremoloSkip
	clr.w	d0
MT_TremoloSkip:
	cmpi.w	#$40,d0
	bls.s	MT_TremoloOk
	move.w	#$40,d0
MT_TremoloOk:
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)
	move.b	N_TremoloCmd(a4),d0
	lsr.w	#2,d0
	andi.w	#$3c,d0
	add.b	d0,N_TremoloPos(a4)
	rts

MT_SampleOffset:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	beq.s	MT_SoNoNew
	move.b	d0,N_SampleOffset(a4)
MT_SoNoNew:
	move.b	N_SampleOffset(a4),d0
	lsl.w	#7,d0
	cmp.w	N_Length(a4),d0
	bge.s	MT_SofSkip
	sub.w	d0,N_Length(a4)
	add.w	d0,d0
	add.l	d0,N_Start(a4)
	rts
MT_SofSkip:
	move.w	#1,N_Length(a4)
	rts

MT_VolumeSlide:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	lsr.b	#4,d0
	tst.b	d0
	beq.s	MT_VolSlideDown
MT_VolSlideUp:
	add.b	d0,N_Volume(a4)
	cmpi.b	#$40,N_Volume(a4)
	bmi.s	MT_VsuSkip
	move.b	#$40,N_Volume(a4)
MT_VsuSkip:
	move.b	N_Volume(a4),d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)
	rts

MT_VolSlideDown:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
MT_VolSlideDown2:
	sub.b	d0,N_Volume(a4)
	bpl.s	MT_VsdSkip
	clr.b	N_Volume(a4)
MT_VsdSkip:
	move.b	N_Volume(a4),d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)
	rts

MT_PositionJump
	move.b	N_Cmdlo(a4),d0
	subq.b	#1,d0
	cmp.b	MT_SongPos(a5),d0
	bge.s	.nosign
	st	MT_Signal(a5)
.nosign	move.b	d0,MT_SongPos(a5)
MT_PJ2	clr.b	MT_PBreakPos(a5)
	st 	MT_PosJumpFlag(a5)
	rts

MT_VolumeChange:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	cmpi.b	#$40,d0
	bls.s	MT_VolumeOk
	moveq	#$40,d0
MT_VolumeOk:
	move.b	d0,N_Volume(a4)
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)
	rts

MT_PatternBreak:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	move.l	d0,d2
	lsr.b	#4,d0
	mulu	#10,d0
	andi.b	#$0f,d2
	add.b	d2,d0
	cmpi.b	#63,d0
	bhi.s	MT_PJ2
	move.b	d0,MT_PBreakPos(a5)
	st	MT_PosJumpFlag(a5)
	rts

	IFD	ST_CiaOn
MT_SetSpeed:
	moveq.l	#0,d0
	move.b	3(a4),d0
	beq	MT_Return2
	cmp.b	#32,d0
	bhs.s	.ciatim
	clr.b	MT_Counter(a5)
	move.b	d0,MT_Speed(a5)
	rts
.ciatim	bra	MT_SetCia
	ELSE
MT_SetSpeed:
	moveq.l	#0,d0
	move.b	3(a4),d0
	beq	MT_Return2
	cmp.b	#32,d0
	bhs.s	.ciatim
	clr.b	MT_Counter(a5)
	move.b	d0,MT_Speed(a5)
.ciatim	rts
	ENDC

MT_CheckMoreEfx:
	bsr	MT_UpdateFunk
	move.b	2(a4),d0
	andi.b	#$0f,d0
	cmpi.b	#$9,d0
	beq	MT_SampleOffset
	cmpi.b	#$b,d0
	beq	MT_PositionJump
	cmpi.b	#$d,d0
	beq.s	MT_PatternBreak
	cmpi.b	#$e,d0
	beq.s	MT_E_Commands
	cmpi.b	#$f,d0
	beq.s	MT_SetSpeed
	cmpi.b	#$c,d0
	beq	MT_VolumeChange
	bra	MT_PerNop

MT_E_Commands:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$f0,d0
	lsr.b	#4,d0
	beq.s	MT_FilterOnOff
	cmpi.b	#1,d0
	beq	MT_FinePortaUp
	cmpi.b	#2,d0
	beq	MT_FinePortaDown
	cmpi.b	#3,d0
	beq.s	MT_SetGlissControl
	cmpi.b	#4,d0
	beq	MT_SetVibratoControl
	cmpi.b	#5,d0
	beq	MT_SetFineTune
	cmpi.b	#6,d0
	beq	MT_JumpLoop
	cmpi.b	#7,d0
	beq	MT_SetTremoloControl
	cmpi.b	#9,d0
	beq	MT_RetrigNote
	cmpi.b	#$a,d0
	beq	MT_VolumeFineUp
	cmpi.b	#$b,d0
	beq	MT_VolumeFineDown
	cmpi.b	#$c,d0
	beq	MT_NoteCut
	cmpi.b	#$d,d0
	beq	MT_NoteDelay
	cmpi.b	#$e,d0
	beq	MT_PatternDelay
	cmpi.b	#$f,d0
	beq	MT_FunkIt
	rts

MT_FilterOnOff:
	move.b	N_Cmdlo(a4),d0
	andi.b	#1,d0
	add.b	d0,d0
	andi.b	#$fd,$bfe001
	or.b	d0,$bfe001
	rts

MT_SetGlissControl:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	andi.b	#$f0,N_GlissFunk(a4)
	or.b	d0,N_GlissFunk(a4)
	rts

MT_SetVibratoControl:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	andi.b	#$f0,N_WaveControl(a4)
	or.b	d0,N_WaveControl(a4)
	rts

MT_SetFineTune:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	move.b	d0,N_FineTune(a4)
	rts

MT_JumpLoop:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	beq.s	MT_SetLoop
	tst.b	N_LoopCount(a4)
	beq.s	MT_JumpCnt
	subq.b	#1,N_LoopCount(a4)
	beq	MT_Return2
MT_JmpLoop:
	move.b	N_PattPos(a4),MT_PBreakPos(a5)
	st	MT_PBreakFlag(a5)
	rts

MT_JumpCnt:
	move.b	d0,N_LoopCount(a4)
	bra.s	MT_JmpLoop

MT_SetLoop:
	move.w	MT_PatternPos(a5),d0
	lsr.w	#4,d0
	move.b	d0,N_PattPos(a4)
	rts

MT_SetTremoloControl:
	move.b	N_Cmdlo(a4),d0
*	andi.b	#$0f,d0
	lsl.b	#4,d0
	andi.b	#$0f,N_WaveControl(a4)
	or.b	d0,N_WaveControl(a4)
	rts

MT_RetrigNote:
	move.l	d1,-(a7)
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	beq.s	MT_RtnEnd
	moveq	#0,d1
	move.b	MT_Counter(a5),d1
	bne.s	MT_RtnSkp
	move.w	(a4),d1
	andi.w	#$0fff,d1
	bne.s	MT_RtnEnd
	moveq	#0,d1
	move.b	MT_Counter(a5),d1
MT_RtnSkp:
	divu	d0,d1
	swap	d1
	tst.w	d1
	bne.s	MT_RtnEnd
MT_DoRetrig:
	move.w	N_DMABit(a4),$096(a6)	; Channel DMA off
	move.l	N_Start(a4),(a6,d5.w)	; Set sampledata pointer
	move.w	N_Length(a4),4(a6,d5.w)	; Set length
	bsr	MT_DMAWaitLoop
	move.w	N_DMABit(a4),d0
	ori.w	#$8000,d0
*	bset	#15,d0
	move.w	d0,$096(a6)
	bsr	MT_DMAWaitLoop
	move.l	N_LoopStart(a4),(a6,d5.w)
	move.l	N_Replen(a4),4(a6,d5.w)
MT_RtnEnd:
	move.l	(a7)+,d1
	rts

MT_VolumeFineUp:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	bra	MT_VolSlideUp

MT_VolumeFineDown:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	bra	MT_VolSlideDown2

MT_NoteCut:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	cmp.b	MT_Counter(a5),d0   ; was cmpi!!!
	bne	MT_Return2
	clr.b	N_Volume(a4)
	clr.w	8(a6,d5.w)
	rts

MT_NoteDelay:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	cmp.b	MT_Counter(a5),d0   ; was cmpi!!!
	bne	MT_Return2
	move.w	(a4),d0
	beq	MT_Return2
	move.l	d1,-(a7)
	bra	MT_DoRetrig

MT_PatternDelay:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	tst.b	MT_PattDelTime2(a5)
	bne	MT_Return2
	addq.b	#1,d0
	move.b	d0,MT_PattDelTime(a5)
	rts

MT_FunkIt:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	move.b	N_Cmdlo(a4),d0
*	andi.b	#$0f,d0
	lsl.b	#4,d0
	andi.b	#$0f,N_GlissFunk(a4)
	or.b	d0,N_GlissFunk(a4)
	tst.b	d0
	beq	MT_Return2
MT_UpdateFunk:
	movem.l	a0/d1,-(a7)
	moveq	#0,d0
	move.b	N_GlissFunk(a4),d0
	lsr.b	#4,d0
	beq.s	MT_FunkEnd
	lea	MT_FunkTable(pc),a0
	move.b	(a0,d0.w),d0
	add.b	d0,N_FunkOffset(a4)
	btst	#7,N_FunkOffset(a4)
	beq.s	MT_FunkEnd
	clr.b	N_FunkOffset(a4)

	move.l	N_LoopStart(a4),d0
	moveq	#0,d1
	move.w	N_Replen(a4),d1
	add.l	d1,d0
	add.l	d1,d0
	move.l	N_WaveStart(a4),a0
	addq.w	#1,a0
	cmp.l	d0,a0
	blo.s	MT_FunkOk
	move.l	N_LoopStart(a4),a0
MT_FunkOk:
	move.l	a0,N_WaveStart(a4)
	moveq	#-1,d0
	sub.b	(a0),d0
	move.b	d0,(a0)
MT_FunkEnd:
	movem.l	(a7)+,a0/d1
	rts

MT_DMAWaitLoop:
	move.w	d1,-(sp)
;	moveq	#5,d0		; wait 5+1 lines
;.loop	move.b	6(a6),d1		; read current raster position
;.wait	cmp.b	6(a6),d1
;	beq.s	.wait		; wait until it changes
;	dbf	d0,.loop		; do it again


	move.b	$dff006,d1
	add.b	#5,d1
.loop:	cmp.b	$dff006,d1
	bne.s	.loop

	move.w	(sp)+,d1
	rts


mt_MasterVolume:	; Patch by Chucky of The Gang
;	rts
			; Mastervolumesupport
			; IN:  D0 = Wanted volume
			; OUT: D0 = Real Volume after fade with mt_MasterVol
	movem.l D1-D3,-(SP)
	cmp.w	#0,d0
	beq.w	.Zero
			; First check if one chnnel is to be muted
	cmp.w	#$a0,d5	; chan1?
	bne.w	.chan1
	move.b	mt_Chan1(PC),d1
	cmp.b	#0,d1
	beq.w	.chan1
	bra	.Zero

.chan1:
	cmp.w	#$b0,d5	; chan2?
	bne.s	.chan2
	move.b	mt_Chan2(PC),d1
	cmp.b	#0,d1
	beq.s	.chan2
	bra	.Zero

.chan2:
	cmp.w	#$c0,d5	; chan3?
	bne.s	.chan3
	move.b	mt_Chan3(PC),d1
	cmp.b	#0,d1
	beq.s	.chan3
	bra	.Zero

.chan3:
	cmp.w	#$d0,d5	; chan4?
	bne.s	.chan4
	move.b	mt_Chan4(PC),d1
	cmp.b	#0,d1
	beq.s	.chan4
	bra	.Zero

.chan4:
	clr.l	d1
	move.b	mt_MasterVol(PC),d1
	clr.l	d2
	clr.l	d3
	move.w	d0,d2
	move.w	#64,d3
	cmp.w	#0,d2
	beq.s	.Zero
	divu	d2,d3
	cmp.w	#0,d3
	beq.s	.Zero
	divu	d3,d1	
	cmp.w	d1,d0
	blt	.stor
	bra.s	.exit
.Zero:
	clr.l	d1
.exit:
	move.l	d1,d0
	movem.l	(SP)+,D1-D3
	rts

.stor:
	move.w	d0,d1
	bra.s	.exit

MT_FunkTable:
	dc.b	0,5,6,7,8,10,11,13,16,19,22,26,32,43,64,128

MT_VibratoTable:
	dc.b	0,24,49,74,97,120,141,161
	dc.b	180,197,212,224,235,244,250,253
	dc.b	255,253,250,244,235,224,212,197
	dc.b	180,161,141,120,97,74,49,24

MT_PeriodTable:
; Tuning 0, Normal
	dc.w	856,808,762,720,678,640,604,570,538,508,480,453
	dc.w	428,404,381,360,339,320,302,285,269,254,240,226
	dc.w	214,202,190,180,170,160,151,143,135,127,120,113
; Tuning 1
	dc.w	850,802,757,715,674,637,601,567,535,505,477,450
	dc.w	425,401,379,357,337,318,300,284,268,253,239,225
	dc.w	213,201,189,179,169,159,150,142,134,126,119,113
; Tuning 2
	dc.w	844,796,752,709,670,632,597,563,532,502,474,447
	dc.w	422,398,376,355,335,316,298,282,266,251,237,224
	dc.w	211,199,188,177,167,158,149,141,133,125,118,112
; Tuning 3
	dc.w	838,791,746,704,665,628,592,559,528,498,470,444
	dc.w	419,395,373,352,332,314,296,280,264,249,235,222
	dc.w	209,198,187,176,166,157,148,140,132,125,118,111
; Tuning 4
	dc.w	832,785,741,699,660,623,588,555,524,495,467,441
	dc.w	416,392,370,350,330,312,294,278,262,247,233,220
	dc.w	208,196,185,175,165,156,147,139,131,124,117,110
; Tuning 5
	dc.w	826,779,736,694,655,619,584,551,520,491,463,437
	dc.w	413,390,368,347,328,309,292,276,260,245,232,219
	dc.w	206,195,184,174,164,155,146,138,130,123,116,109
; Tuning 6
	dc.w	820,774,730,689,651,614,580,547,516,487,460,434
	dc.w	410,387,365,345,325,307,290,274,258,244,230,217
	dc.w	205,193,183,172,163,154,145,137,129,122,115,109
; Tuning 7
	dc.w	814,768,725,684,646,610,575,543,513,484,457,431
	dc.w	407,384,363,342,323,305,288,272,256,242,228,216
	dc.w	204,192,181,171,161,152,144,136,128,121,114,108
; Tuning -8
	dc.w	907,856,808,762,720,678,640,604,570,538,508,480
	dc.w	453,428,404,381,360,339,320,302,285,269,254,240
	dc.w	226,214,202,190,180,170,160,151,143,135,127,120
; Tuning -7
	dc.w	900,850,802,757,715,675,636,601,567,535,505,477
	dc.w	450,425,401,379,357,337,318,300,284,268,253,238
	dc.w	225,212,200,189,179,169,159,150,142,134,126,119
; Tuning -6
	dc.w	894,844,796,752,709,670,632,597,563,532,502,474
	dc.w	447,422,398,376,355,335,316,298,282,266,251,237
	dc.w	223,211,199,188,177,167,158,149,141,133,125,118
; Tuning -5
	dc.w	887,838,791,746,704,665,628,592,559,528,498,470
	dc.w	444,419,395,373,352,332,314,296,280,264,249,235
	dc.w	222,209,198,187,176,166,157,148,140,132,125,118
; Tuning -4
	dc.w	881,832,785,741,699,660,623,588,555,524,494,467
	dc.w	441,416,392,370,350,330,312,294,278,262,247,233
	dc.w	220,208,196,185,175,165,156,147,139,131,123,117
; Tuning -3
	dc.w	875,826,779,736,694,655,619,584,551,520,491,463
	dc.w	437,413,390,368,347,328,309,292,276,260,245,232
	dc.w	219,206,195,184,174,164,155,146,138,130,123,116
; Tuning -2
	dc.w	868,820,774,730,689,651,614,580,547,516,487,460
	dc.w	434,410,387,365,345,325,307,290,274,258,244,230
	dc.w	217,205,193,183,172,163,154,145,137,129,122,115
; Tuning -1
	dc.w	862,814,768,725,684,646,610,575,543,513,484,457
	dc.w	431,407,384,363,342,323,305,288,272,256,242,228
	dc.w	216,203,192,181,171,161,152,144,136,128,121,114

MT_Chan1Temp:
	dc.l	0,0,0,0,0,$00010000,0,0,0,0,0
MT_Chan2Temp:
	dc.l	0,0,0,0,0,$00020000,0,0,0,0,0
MT_Chan3Temp:
	dc.l	0,0,0,0,0,$00040000,0,0,0,0,0
MT_Chan4Temp:
	dc.l	0,0,0,0,0,$00080000,0,0,0,0,0
MT_SampleStarts:
	dc.l	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.l	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
*MT_SongDataPtr:
	dc.l	0
*MT_Speed:
	dc.b	6
*MT_Counter:
	dc.b	0
*MT_SongPos:
	dc.b	0
*MT_PBreakPos:
	dc.b	0
*MT_PosJumpFlag:
	dc.b	0
*MT_PBreakFlag:
	dc.b	0
*MT_LowMask:
	dc.b	0
*MT_PattDelTime:
	dc.b	0
*MT_PattDelTime2:
	dc.b	0,0
*MT_PatternPos:
	dc.w	0
*MT_DMACONtemp:
	dc.w	0
MT_Variables:
*MT_CiaSpeed
	dc.w	125
*MT_Signal
	dc.w	0
*MT_TimerSpeed
	dc.l	0
*MT_CiaBase
	dc.l	0
*MT_CiaTimer
	dc.w	0
*MT_VolumeControl
	dc.w	64
*mt_data:
	dc.l	0
mt_MasterVol:
	dc.b	64
mt_Chan1:			; If not 0 channel is to be muted
	dc.b	0		; NO Data between Mastervol and this or you will have BUGS
mt_Chan2:
	dc.b	0
mt_Chan3:
	dc.b	0
mt_Chan4:
	dc.b	0
	EVEN


mt_END:
;------------------------------------------------------------------------------------------
; STATIC Data located here.  (HEY!! it IS in ROM!)

RomFont:
	incbin	TopazFont.bin
EndRomFont:
	EVEN


RomMenuCopper:
MenuSprite:
	dc.l	$01200000,$01220000,$01240000,$01260000,$01280000,$012a0000,$012c0000,$012e0000,$01300000,$01320000,$01340000,$01360000,$01380000,$013a0000,$013c0000,$013e0000

	dc.l	$0100b200,$00920038,$009400d0,$008e2781,$009027cc,$01020000,$01080000,$010a0000
	dc.l	$01800000,$01820f00,$018400f0,$01860ff0,$0188000f,$018a0f0f,$018c00ff,$018e0fff,$01900ff0

MenuBplPnt:
	dc.l	$00e00000,$00e20000,$00e40000,$00e60000,$00e80000,$00ea0000

	dc.l	$fffffffe	;End of copperlist
EndRomMenuCopper:

RomEcsCopper:
	dc.l	$01200000,$01220000,$01240000,$01260000,$01280000,$012a0000,$012c0000,$012e0000,$01300000,$01320000,$01340000,$01360000,$0138000,$013a0000,$013c0000,$013e0000
	dc.l	$01005200,$00920038,$009400d0,$008e2781,$009027cc,$01020000,$01080000,$010a0000

	blk.l	32,0
;MenuBplPnt2:
	dc.l	$00e00000,$00e20000,$00e40000,$00e60000,$00e80000,$00ea0000,$00ec0000,$00ee0000,$00f00000,$00f20000

	dc.l	$fffffffe	;End of copperlist
EndRomEcsCopper:
ECSColor32:
	dc.w	$000,$fff,$eee,$ddd,$ccc,$aaa,$999,$888,$777,$555,$444,$333,$222,$111,$f00,$800
	dc.w	$400,$0f0,$080,$040,$00f,$008,$004,$ff0,$880,$440,$f0f,$808,$404,$0ff,$088,$044
ECSTestColor:
	dc.w	$000,$aaa,$666,$777,$777,$00b,$76e,$0b0,$397,$790,$0bb,$fff,$971,$b48,$bb0,$888
	dc.w	$999,$333,$b00,$ddd,$333,$444,$555,$666,$777,$888,$999,$aaa,$ccc,$ddd,$eee,$fff
ECSColor16:
	dc.w	$000,$fff,$ddd,$aaa,$888,$555,$333,$f00
	dc.w	$400,$0f0,$040,$00f,$00f,$ff0,$440,$f0f

Texts:

InitSerial:
	dc.b	1,2,4,8,16,32,64,128,240,15,170,85,$a,$d,$a,$d
	dc.b	"Garbage before this text was binary numbers: 1, 2, 4, 8, 16, 32, 64, 128, 240, 15, 170 and 85",$a,$d
	dc.b	"To help you find biterrors to the mfp. Now starting normal startuptext etc",$a,$d
	dc.b	12,27,"[0m"
InitTxt:
	dc.b	"Atari DiagROM "
	VERSION
	dc.b	" - "
		incbin	"BuildDate.txt"
	dc.b	" - By Stephen J. Leary",$a,$d
	dc.b	" - Based on the Amiga Version By John (Chucky/The Gang) Hertell",$a,$d,$a,$d,0
WaitReleasedTxt:
	dc.b	"Waiting for all buttons to be released",$a
	dc.b	"Release all buttons NOW or they will be disabled",$a,0

InitHardwaretxt:
	dc.b	"    Resetting all hardware (RESET instruction): ",0
InitKeyboardResettxt:
	dc.b	"    Sending reset to keyboard controller (IKBD Reset): ",0
Initmousetxt:
	dc.b	"    Checking status of mousebuttons for different startups: ",$a,$d
	dc.b	"            ",0
InitDMACON:
	dc.b	"    Set all DMA enablebits (DMACON $dff096) to Enabled: ",0
InitBEAMCON0:
	dc.b	"    Set Beam Conter control register to 32 (PAL) (BEAMCON0 $dff1dc): ",0
InitPOTGO:
	dc.b	"    Set POTGO to all OUTPUT ($FF00) (POTGO $dff034): ",0

InitDONEtxt:
	dc.b	"Done",$a,$d,0	
Donetxt:
	dc.b	"Done",$a,0
InitP1LMBtxt:
	dc.b	"P1LMB ",0
InitP2LMBtxt:
	dc.b	"P2LMB ",0
InitP1RMBtxt:
	dc.b	"P1RMB ",0
InitP2RMBtxt:
	dc.b	"P2RMB ",0

InitSerial2:
	dc.b	$a,$d,$a,$d,"To use serial communication please hold down ANY key now",$a,$d
	dc.b	"OR hold down the RIGHT mousebutton on the Amiga during poweron",$a,$d
	dc.b	"Holding down the LEFT mousebutton will force serial on and turn off screen",$a,$d
	dc.b	"forcing stuff to run in fastmem if avaible",$a,$d,$a,$d,0
EndSerial:
	dc.b	27,"[0m",$a,$d,"No key pressed, disabling any serialcommunications. Enable it in program",$a,$d,0

Ansi:
	dc.b	27,"[",0
AnsiNull:
	dc.b	27,"[0m",27,"[40m",27,"[37m",0
Black:
	dc.b	27,"[30m",0
StatusLine:
	dc.b	"Serial: ",1,1,1,1,1," BPS - CPU: ",1,1,1,1,1," - Chip: ",1,1,1,1,1,1," - KBFast: ",1,1,1,1,1,1," Base: ",0
Space3:
	dc.b	"   ",0

	EVEN
	
CPU:	dc.b	"680x0",0,"68010",0,"68020",0,"68030",0,"68040",0,"68060",0,"68???",0

Bps:
	dc.l	BpsNone,Bps2400,Bps9600,Bps38400,Bps115200,0
	
BpsNone:
	dc.b	"N/A   ",0
Bps2400:
	dc.b	"2400  ",0
Bps9600:
	dc.b	"9600  ",0
Bps38400:
	dc.b	"38400 ",0
Bps115200:
	dc.b	"115200",0
ON:
	dc.b	"ON ",0
OFF:
	dc.b	"OFF",0
YES:
	dc.b	"YES",0
NO:
	dc.b	"NO ",0
SPACE:
	dc.b	" ",0
MB:
	dc.b	"MB",0
KB:
	dc.b	"KB",0
DOWN:
	dc.b	"DOWN",0
UP:
	dc.b	"UP  ",0
LEFT:
	dc.b	"LEFT",0
RIGHT:
	dc.b	"RIGHT",0
FIRE:
	dc.b	"FIRE",0
FAILED:
	dc.b	"FAILED",0
DETECTED:
	dc.b	"DETECTED",0
CANCELED:
	dc.b	"CANCELED",0
II:
	dc.b	" II",0
III:
	dc.b	"III",0
OK:
	dc.b	"OK",0	
MinusTxt:
	dc.b	" - ",0	
SPACEOK:
	dc.b	"   OK",0
SPACEFAIL:
	dc.b	"  FAILED",$a,$d,0
ms:
	dc.b	"ms",0
space8:
	dc.b	"        ",0
ticks:
	dc.b	" Ticks",0
Bytes:
	dc.b	" Bytes",0
	EVEN
SerSpeeds:		; list of Baudrates (3579545/BPS)+1
	dc.l	0,1492,373,94,32,0
SerText:
	dc.l	BpsNone,Bps2400,Bps9600,Bps38400,Bps115200,BpsNone
	
Menus:					; Pointers to the menus
	dc.l	MainMenuItems,0,AudioMenuItems,MemtestMenuItems,IRQCIAtestMenuItems,GFXtestMenuItems,PortTestMenuItems,0,0
MenuCode:				; Pointers to pointers of the menus.
	dc.l	MainMenuCode,0,AudioMenuCode,MemtestMenuCode,IRQCIAtestMenuCode,GFXtestMenuCode,PortTestMenuCode,0,0
MenuKeys:
	dc.l	MainMenuKey,0,AudioMenuKey,MemtestMenuKey,IRQCIAtestMenuKey,GFXtestMenuKey,PortTestMenuKey,0,0

MainMenuText:
	dc.b	"               Atari DiagROM "
	VERSION
	dc.b	" - "
	incbin	"BuildDate.txt"
	dc.b	$a
	dc.b	"                       MAIN MENU",$a,$a,0

MainMenu1:
	dc.b	"0 - Systeminfo",0
MainMenu2:
	dc.b	"1 - Audiotests",0
MainMenu3:
	dc.b	"2 - Memorytests",0
MainMenu4:
	dc.b	"3 - IRQ/CIA Tests",0
MainMenu5:
	dc.b	"4 - Graphictests",0
MainMenu6:
	dc.b	"5 - Porttests",0
MainMenu7:
	dc.b	"6 - Diskdrivetests",0
MainMenu8:
	dc.b	"7 - Keyboardtests",0
MainMenu10:
	dc.b	"S - Setup",0
	EVEN

MainMenuItems:
	dc.l	MainMenuText,MainMenu1,MainMenu2,MainMenu3,MainMenu4,MainMenu5,MainMenu6,MainMenu7,MainMenu8,MainMenu10,0,0
MainMenuCode:
	dc.l	SystemInfoTest,AudioMenu,MemtestMenu,IRQCIAtestMenu,GFXtestMenu,PortTestMenu,NotImplemented,KeyBoardTest,Setup,0,0
MainMenuKey:	; Keys needed to choose menu. first byte keykode 2:nd byte serialcode.
	dc.b	"0","1","2","3","4","5","6","7","8","S",0

NotImplTxt:
	dc.b	2,"This function is not implemented yet. Anyday.. soon(tm), Thursday?",$a,$a,0
AnyKeyMouseTxt:
	dc.b	2,"Press any key/mouse to continue",0
SetupTxt:
	dc.b	2,"Setupmenu",$a,0



SystemInfoTxt:
	dc.b	2,"Information of this machine:",$a,$a,0
ChipstartTxt:
	dc.b	"Chipmem starts at: ",0
AndendTxt:
	dc.b	" and Ends at: ",0
UnusedChipTxt:
	dc.b	"  Unused chip: ",0
SystemInfoHWTxt:
	dc.b	2,"Dump of all readable Custom Chipset HW Registers:",$a,0

AudioMenuText:
	dc.b	2,"Audiotests",$a,$a,0
AudioMenu1:
	dc.b	"1 - Simple waveformtest",0
AudioMenu2:
	dc.b	"2 - Play test-module",0
AudioMenu3:
	dc.b	"9 - MainMenu",0
	EVEN
AudioMenuItems:
	dc.l	AudioMenuText,AudioMenu1,AudioMenu2,AudioMenu3,0
AudioMenuCode:
	dc.l	AudioSimple,AudioMod,MainMenu
AudioMenuKey:
	dc.b	"1","2","9",0

AudioSimpleMenu:
	dc.l	AudioSimpleWaveItems,0
	dc.l	0
AudioSimpleWaveText:
	dc.b	2,"Simple Audiowavetest",0
AudioSimpleWaveMenu1:
	dc.b	"1 - Channel 1:",0
AudioSimpleWaveMenu2:
	dc.b	"2 - Channel 2:",0
AudioSimpleWaveMenu3:
	dc.b	"3 - Channel 3:",0
AudioSimpleWaveMenu4:
	dc.b	"4 - Channel 4:",0
AudioSimpleWaveMenu5:
	dc.b	"5 - Volume:",0
AudioSimpleWaveMenu6:
	dc.b	"6 - Waveform:",0
AudioSimpleWaveMenu7:
	dc.b	"7 - Filter:",0
AudioSimpleWaveMenu8:
	dc.b	"9 - AudioMenu",0
AudioSimpleWaveKeys:
	dc.b	"1","2","3","4","5","6","7","9",0
AudioModTxt:
	dc.b	2,"Play a Protracker module",$a,$a,0
AudioModCopyTxt:
	dc.b	"Copying moduledata from ROM to Chipmem: ",0
AudioModInitTxt:
	dc.b	"Initilize module: ",0
AudioModPlayTxt:
		;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	dc.b	2,"Starting to play music, Press any key for option (1,2,3,4,f,+,-,l,r)",$a,0
AudioModOptionTxt:	
	dc.b	$a,"         Channel 1:      Channel 2:      Channel 3:      Channel 4:    ",$a
	dc.b	"                  Audio F)ilter:       Mastervolume (+ -):   ",$a,$a,0
AudioModEndTxt:
	dc.b	2,"Press any button to exit",0
AudioModName:
	dc.b	$a,"Modulename: ",0
AudioModInst:
	dc.b	$a,"Instruments:",$a,0
	EVEN
AudioSimpleWaveItems:
	dc.l	AudioSimpleWaveText,AudioSimpleWaveMenu1,AudioSimpleWaveMenu2,AudioSimpleWaveMenu3,AudioSimpleWaveMenu4,AudioSimpleWaveMenu5,AudioSimpleWaveMenu6,AudioSimpleWaveMenu7,AudioSimpleWaveMenu8,0,0

MemtestText:
	dc.b	2,"Memorytests",$a,$a,0
MemtestMenu1:
	dc.b	"1 - Test detected chipmem",0
MemtestMenu2:
	dc.b	"2 - Extended chipmemtest",0
MemtestMenu3:
	dc.b	"3 - Test detected fastmem",0
MemtestMenu4:
	dc.b	"4 - Fast scan of 16MB fastmem-areas",0
MemtestMenu5:
	dc.b	"5 - Large Fast scan of fastmem-areas",0
MemtestMenu6:
	dc.b	"6 - Manual memorytest",0
MemtestMenu7:
	dc.b	"7 - Manual memoryedit",0
MemtestMenu9:
	dc.b	"9 - Mainmenu",0
	EVEN
MemtestMenuItems:
	dc.l	MemtestText,MemtestMenu1,MemtestMenu2,MemtestMenu3,MemtestMenu4,MemtestMenu5,MemtestMenu6,MemtestMenu7,MemtestMenu9,0
MemtestMenuCode:
	dc.l	CheckDetectedChip,CheckExtendedChip,CheckDetectedMBMem,CheckExtended16MBMem,CheckExtendedMBMem,CheckMemManual,CheckMemEdit,MainMenu
MemtestMenuKey:
	dc.b	"1","2","3","4","5","6","7","9",0
	EVEN

hextab:
	dc.b	"0123456789ABCDEF"	; For bin->hex convertion

MemtestDetChipTxt:
	dc.b	2,"Checking detected chipmem",0
MemtestExtChipTxt:
	dc.b	2,"Checking full Chipmemarea until 2MB or Shadow-Memory is detected",0
MemtestShadowTxt:
	dc.b	2,"Shadowmemory detected. Scan stopped. You can ignore the last error if any!",0
MemtestDetMBMemTxt:
	dc.b	" Detecting A3000/4000 Motherboard memory: Detected: ",0
MemtestDetMBMemTxt2:
	dc.b	" Detecting CPU Card memory: Detected: ",0
MemtestDetMBMemTxt3:
	dc.b	" Detecting Z2 memoryarea: (NON Autoconfig) Detected: ",0
MemtestExtMBMemTxt:
	dc.b	"Scanning for memory on all fastmem-areas (no autoconfig mem will be scanned)",0
MemtestNORAM:
	dc.b	2,"No memory found, Press any key/mouse!",0
MemtestManualTxt:
	dc.b	"                              Manual memoryscan",$a,$a
	dc.b	"Here you can enter a manual value of memoryadress to test, but please remember",$a
	dc.b	"that only NON Autoconfig memory will be possible to test. and if you select an",$a
	dc.b	"illegal area your machine might behave strange/crash etc.",$a,$a,"You are on your own!",$a,$a
	dc.b	"YOU HAVE BEEN WARNED!!!",$a,$a,$a
	dc.b	"Pressing a mousebutton or ESC cancels this screen",$a,$a
	dc.b	"Please enter startaddress to check from: $",0
MemtestManualEndTxt:
	dc.b	$a,$a,$a,"Please enter endadress to check to: $",0
MemtextManualModeTxt:
	dc.b	$a,$a,"Do you want to do a S)low test or a F)ast test?",0
MemtextManualShadowTxt:
	dc.b	$a,$a,"Do you want to disable shadowramtest? Y)es",0
CheckMemRangeTxt:
	dc.b	"Checking memory from ",1,1,1,1,1,1,1,1,1," to ",1,1,1,1,1,1,1,1,1," - Press any key/mousebutton to stop",0
CheckMemCheckAdrTxt:	
	dc.b	"Checking Address:",1,1,1,1,1,1,1,1,1,1,1,1,0
CheckMemBitErrTxt:
	dc.b	"|  Bit error shows max $FF errors due to space",$a,$a
	dc.b	"            8|7|6|5|4|3|2|1| 8|7|6|5|4|3|2|1| 8|7|6|5|4|3|2|1| 8|7|6|5|4|3|2|1|",$a,0
CheckMemBitErrorsTxt:
	dc.b	"Bit errors:",$a
	dc.b	"Byte errors:",$a,0
CheckMemCheckedTxt:
	dc.b	"Checked memory:",0
CheckMemUsableTxt:
	dc.b	"Usable memory:",0	
CheckMemNonUsableTxt:
	dc.b	"NONUsable memory:",0
CheckMemFastModeTxt:
	dc.b	"    ---   Running in Fast-Scan mode!",$a
	dc.b	"Only one longword every 1k block is tested and no errors reported",$a
	dc.b	"Result can be aproximate! No shadowmem tests! Used to scan for memoryareas",$a
	dc.b	"Dead block = ALL bits checked failed, most likly no mem at all",$a
	dc.b	"Bad block = Some bits works, most likly bad memory with biterrors",0	
CheckMemNumErrTxt:
	dc.b	"Number of errors:",0
CheckMemGoodTxt:
	dc.b	"Good Block start at ",0
CheckMemEndAtTxt:
	dc.b	" and ends at ",0
CheckMemSizeOfTxt:
	dc.b	" with a size of ",0
CheckMemBadTxt:
	dc.b	"Bad Block start at ",0
CheckMemDeadTxt:
	dc.b	"Dead Block start at ",0
CheckMemEditTxt:
	dc.b	"  Manual Memoryedit. BE WARNED, EVERYTHING HAPPENS IN REALTIME! NO PROTECTION!",$a
	dc.b	"G)oto address  R)efresh    ESC)Main Menu",$a,0
CheckMemEditGotoTxt:
	dc.b	"Enter address to dump memory from: $",0
CheckMemAdrTxt:
	dc.b	"Current address: ",0
CheckMemBinaryTxt:
	dc.b	"Current byte in binary: ",0


IRQCIATestText:
	dc.b	2,"IRQ & CIA Tests",$a,$a,0
IRQCIATestMenu1:
	dc.b	"1 - Test IRQs",0,0
	EVEN
IRQCIATestMenu2:
	dc.b	"2 - Test CIAs",0,0
	EVEN
IRQCIAtestMenu7:
	dc.b	"9 - Mainmenu",0,0
	EVEN

IRQLev1Txt:
	dc.b	"Testing IRQ Level 1: ",0
IRQLev2Txt:
	dc.b	"Testing IRQ Level 2: ",0
IRQLev3Txt:
	dc.b	"Testing IRQ Level 3: ",0
IRQLev4Txt:
	dc.b	"Testing IRQ Level 4: ",0
IRQLev5Txt:
	dc.b	"Testing IRQ Level 5: ",0
IRQLev6Txt:
	dc.b	"Testing IRQ Level 6: ",0
IRQLev7Txt:
	dc.b	"Testing IRQ Level 7 (WILL Fail unless you press a custom IRQ7 button): ",0
IRQTestDone:
	dc.b	$a,$a,$a,"IRQ Tests done",$a,0

CIATestTxt:
	dc.b	2,"CIA Tests. Check if your CIAs can time stuff. REQUIRES LEV3 IRQ!",$a,$a,0
CIATestTxt2:
	dc.b	2,"Press any key to start tests (2 sec/each), Press ESC for mainmenu",$a,$a,$a,0
CIATestTxt3:
	dc.b	2,"Flashing on screen is fully normal, indicating CIA timing",$a,$a

CIAATestAATxt:
	dc.b	"Testing Timer A, on CIA-A (ODD) :",$a,0
CIAATestBATxt:
	dc.b	"Testing Timer B, on CIA-A (ODD) :",$a,0
CIATestATOD:
	dc.b	"Testing CIA-A TOD (Tick/VSync)  :",$a,0
CIAATestABTxt:
	dc.b	"Testing Timer A, on CIA-B (EVEN):",$a,0
CIAATestBBTxt:
	dc.b	"Testing Timer B, on CIA-B (EVEN):",$a,0
CIATestBTOD:
	dc.b	"Testing CIA-B TOD (HSync)       :",$a,0
VblankOverrunTXT:
	dc.b	" - CIA Timing too slow! ",0
VblankUnderrunTXT:
	dc.b	" - CIA Timing too fast! ",0
CIATickSlowTxt:
	dc.b	" - Too slow ticksignal ",0
CIATickFastTxt:
	dc.b	" - Too fast ticksignal ",0

CIANoRasterTxt:
	dc.b	2,"CIA Tests requires a working raster, Unable to test",$a,$a,0
CIANoRasterTxt2:
	dc.b	2,"Press any key to return to Main Menu",$a,0
	

	EVEN
IRQCIAtestMenuItems:
	dc.l	IRQCIATestText,IRQCIATestMenu1,IRQCIATestMenu2,IRQCIAtestMenu7,0,0
IRQCIAtestMenuCode:
	dc.l	IRQCIAIRQTest,IRQCIACIATest,MainMenu,0,0
IRQCIAtestMenuKey:
	dc.b	"1","2","9",0

IRQCIAIRQTestText:
	dc.b	2,"Testing IRQ Levels. Press any key to start.   ESC or RMB to exit",$a,$a,0
IRQCIAIRQTestText2:
	dc.b	2,"Screen Flashing during test is normal, it is a sign that IRQ is executed",$a,$a,0

	EVEN
GFXtestMenuItems:
	dc.l	GFXtestText,GFXtestMenu1,GFXtestMenu3,0
GFXtestMenuCode:
	dc.l	GFXTestScreen,MainMenu,0	
GFXtestMenuKey:
	dc.b	"1","9",0

GFXtestText:
	dc.b	2,"Graphicstests",$a,$a,0
GFXtestMenu1:
	dc.b	"1 - Testpicture in lowres 16 Col",0
GFXtestMenu3:
	dc.b	"9 - Exit to mainmenu",0
GFXtestNoSerial:
	dc.b	$a,$d,$a,$d,"GRAPHICTEST IN ACTION, Serialoutput is not possible during test",$a,$d,$a,$d,0

PortTestText:
	dc.b	2,"Porttests",$a,$a,0
PortTestMenu1:
	dc.b	"1 - Parallel Port",0
PortTestMenu2:
	dc.b	"2 - Serial Port",0
PortTestMenu3:
	dc.b	"3 - Joystick/Mouse Ports",0
PortTestMenu4:
	dc.b	"9 - Mainmenu",0
	EVEN
PortTestMenuItems:
	dc.l	PortTestText,PortTestMenu1,PortTestMenu2,PortTestMenu3,PortTestMenu4,0
PortTestMenuCode:
	dc.l	NotImplemented,NotImplemented,PortTestJoystick,MainMenu
PortTestMenuKey:
	dc.b	"1","2","3","9",0

PortJoyTest:
	dc.b	2,"Joystickport tests",$a,$a,0
PortJoyTest1:
	dc.b	2,"Dumping data of hardwareregisters:",$a,$a,0
PortJoyTestHW1:
	dc.b	2,"JOY0DAT ($DFF00A):       BIN:                 ",$a,0
PortJoyTestHW2:
	dc.b	2,"JOY1DAT ($DFF00C):       BIN:                 ",$a,0
PortJoyTestHW3:
	dc.b	2,"POT0DAT ($DFF012):       BIN:                 ",$a,0
PortJoyTestHW4:
	dc.b	2,"POT1DAT ($DFF014):       BIN:                 ",$a,0
PortJoyTestHW5:
	dc.b	2,"POTINP  ($DFF016):       BIN:                 ",$a,0
PortJoyTestHW6:
	dc.b	2,"CIAAPRA ($BFE001):       BIN:                 ",$a,0

PortJoyTest2:
	dc.b	2,"Joystick positions",$a,$a,0
PortJoyTest3:
	dc.b	2,"PORT0                               PORT1",0
PortJoyTestExitTxt:
	dc.b	2,"Exit with both mousebuttons or ESC",0


KeyBoardTestText:
	dc.b	2,"Keyboardtest ESC or mouse to exit",$a,$a,0
KeyBoardTestCodeTxt:
	dc.b	"Current Scancode read from Keyboardbuffer:      Keyboardcode:      Char: ",$a,0
KeyBoardTestCodeTxt2:
	dc.b	"Scancode binary:                                Keyboardcode binary:         ",0
RTCByteTxt:
	dc.b	"Raw RTC data in hex:",$a,0

RTCBitTxt:
	dc.b	"Raw RTC data in binary:",$a,0
RTCRicoh:
	dc.b	"Ricoh Chipset output:",$a,0
RTCOKI:
	dc.b	"OKI Chipset output:",$a,0
	EVEN
RTCMonth:
	dc.b	"Jan",0
	dc.b	"Feb",0
	dc.b	"Mar",0
	dc.b	"Apr",0
	dc.b	"May",0
	dc.b	"Jun",0
	dc.b	"Jul",0
	dc.b	"Aug",0
	dc.b	"Sep",0
	dc.b	"Oct",0
	dc.b	"Nov",0
	dc.b	"Dec",0
	dc.b	"BAD",0
RTCDay:
	dc.b	"   Sunday",0
	dc.b	"   Monday",0
	dc.b	"  Tuesday",0
	dc.b	"Wednesday",0
	dc.b	" Thursday",0
	dc.b	"   Friday",0
	dc.b	" Saturday",0	

DividerTxt:
	dc.b	"--------------------------------------------------------------------------------",0
EmptyRowTxt:
	dc.b	"                                                                                ",0

DetChipTxt:
	dc.b	"Detected Chipmem: ",0
DetMBFastTxt:
	dc.b	"Detected Motherboard Fastmem: ",0
BaseAdrTxt:
	dc.b	"Basememory address: ",0
DetectRasterTxt:
	dc.b	"Detecting if we have a working raster: ",0
NoDrawTxt:
	dc.b	"We are in a nonchip/nodraw mode. Serialoutput is all we got. colorflash on screen",$a,$d
	dc.b	"is actually chars that should be printed on screen. telling user something happens",$a,$d,0
NewLineTxt:
	dc.b	$a,$d,0
DotTxt:
	dc.b	".",0
SpaceTxt:
	dc.b	" ",0
ColonTxt:
	dc.b	" : ",0

SSPErrorTxt:
	dc.b	2,"oOoooops Something went borked",0
BusErrorTxt:
	dc.b	2,"BusError Detected",0
AddressErrorTxt:
	dc.b	2,"AddressError Detected",0
IllegalErrorTxt:
	dc.b	2,"Illegal Instruction Detected",0
DivByZeroTxt:
	dc.b	2,"Division by Zero Detected",0
ChkInstTxt:
	dc.b	2,"Chk Inst Detected",0
TrapVTxt:
	dc.b	2,"Trap V Detected",0
PrivViolTxt:
	dc.b	2,"Privilige Violation Detected",0
TraceTxt:
	dc.b	2,"Trace Detected",0
UnImplInstrTxt:
	dc.b	2,"Unimplemented instruction Detected",0
TrapTxt:
	dc.b	2,"TRAP Detected",0
DebugTxt:
	dc.b	"Debugdata (Dump of CPU Registers D0-D7/A0-A7):",0
HaltTxt:
	dc.b	$a,$d,"PANIC! System halted, not enough resources found to generate better dump",$a,$d,0
	
	EVEN

AddrTxt:
	dc.b	$d,"Addr $",0
	EVEN
StartAddrTxt:
	dc.b	$a,$d,"Startaddr: $",0
EndAddrTxt:
	dc.b	"  Endaddr: $",0
WTxt:
	dc.b	"  Write: $",0
RTxt:
	dc.b	"  Read: $",0
Txt32KBlock:
	dc.b	"  Number of 32K blocks found: $",0
Base1Txt:
	dc.b	$a,$d,"  Using $",0
Base2Txt:
	dc.b	" as start of workmem",$a,$d,$a,$d,0
UnderDevTxt:
	dc.b	2,"This function is under development, output can be weird, strange and false",$a,$d,$a,$d,0
NoChiptxt:
	dc.b	$a,$d,"NO Chipmem detected",$a,$d,0
NotEnoughChipTxt:
	dc.b	"Not enough chipmem detected",$a,$a,0
ShadowChiptxt:
	dc.b	$a,$d,"Chipmem Shadowram detected, guess there is no more chipmem, stopping here",$a,$d,0

S8MB:
	dc.b	"8MB",0
S64k:
	dc.b	"64KB",0
S128k:
	dc.b	"128KB",0
S256k:
	dc.b	"256KB",0
S512k:
	dc.b	"512KB",0
S1MB:
	dc.b	"1MB",0
S2MB:
	dc.b	"2MB",0
S4MB:
	dc.b	"4MB",0
MemCardTxt:
	dc.b	$a,"    Memory detected and assigned to: ",0
	EVEN
SizePointer:
	dc.l	S8MB,S64k,S128k,S256k,S512k,S1MB,S2MB,S4MB
SizePointer2:
	dc.l	$800000,$10000,$20000,$40000,$80000,$100000,$200000,$400000
IllegalZ2:
	dc.b	$a,"  ---- ILLEGAL Configuration. Memory outside Zorro II Area!!",$a,0
bytehextxt:
	dc.b	"000102030405060708090A0B0C0D0E0F"
	dc.b	"101112131415161718191A1B1C1D1E1F"
	dc.b	"202122232425262728292A2B2C2D2E2F"
	dc.b	"303132333435363738393A3B3C3D3E3F"
	dc.b	"404142434445464748494A4B4C4D4E4F"
	dc.b	"505152535455565758595A5B5C5D5E5F"
	dc.b	"606162636465666768696A6B6C6D6E6F"
	dc.b	"707172737475767778797A7B7C7D7E7F"
	dc.b	"808182838485868788898A8B8C8D8E8F"
	dc.b	"909192939495969798999A9B9C9D9E9F"
	dc.b	"A0A1A2A3A4A5A6A7A8A9AAABACADAEAF"
	dc.b	"B0B1B2B3B4B5B6B7B8B9BABBBCBDBEBF"
	dc.b	"C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF"
	dc.b	"D0D1D2D3D4D5D6D7D8D9DADBDCDDDEDF"
	dc.b	"E0E1E2E3E4E5E6E7E8E9EAEBECEDEEEF"
	dc.b	"F0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF"
	dc.b	0

AtariKey:
	dc.b	0
	dc.b	27 ; esc
	dc.b	"1234567890-="
	dc.b	8 ; backspace
	dc.b	9 ; Tab
	dc.b	"qwertyuiop[]"
	dc.b	$a ; Return
	dc.b	0 ; ctrl 
	dc.b	"asdfghjkl;'`"
	dc.b	0 ; left shift
	dc.b	"\zxcvbnm,./" ;3b
	dc.b	0 ; right shift
	dc.b	0 ; Not used
	dc.b	0 ; alt
	dc.b	" " 		; space bar
	dc.b	0 ; caps lock
	
	dc.b	"1" ;f1
	dc.b	"2" ;f2
	dc.b	"3" ;f3
	dc.b	"4" ;f4
	dc.b	"5" ;f5
	dc.b	"6" ;f6
	dc.b	"7" ;f7
	dc.b	"8" ;f8
	dc.b	"9" ;f9
	dc.b	"0" ;f10

	dc.b	0 ; Not used
	dc.b	0 ; Not used
	dc.b	0 ; Home

	dc.b	30 ; Up
	dc.b	0 ; Not used
	dc.b	"-" ; 4A	KEYPAD -
	dc.b	29  ; 4B	LEFT ARROW
	dc.b	0 ; Not used
	dc.b	28 ; 4D	RIGHT ARROW
	dc.b	"+" ;4E	KEYPAD +
	dc.b	0 ; Not used
	dc.b	31 ; 50	DOWN ARROW
	dc.b	0 ; Not used
	dc.b	" "
	dc.b	127 ; 53	DEL
	dc.b 	"     "
	dc.b	"(/**7894561230.",$a

	
AtariKeyShifted:
	; Shifted
	dc.b	"~!@#$%^& ()_+| 0QWERTYUIOP{} 123ASDFGHJKL:",34,"  456 ZXCVBNM<>? .789          - "
	dc.b	0 ; Up
	dc.b	0 ;down
	dc.b	0 ; forward
	dc.b	0 ; backward
	dc.b	0 ;f1
	dc.b	0 ;f2
	dc.b	0 ;f3
	dc.b	0 ;f4
	dc.b	0 ;f5
	dc.b	0 ;f6
	dc.b	0 ;f7
	dc.b	0 ;f8
	dc.b	0 ;f9
	dc.b	0 ;f10
	dc.b	"()/*+"
	dc.b	0 ; Help

	
EnglishKey:
	dc.b	"´1234567890-=| 0"
	dc.b	"qwertyuiop[] "; 1c
	dc.b	"123asdfghjkl;`" ; 2a
	dc.b	"  456 zxcvbnm,./ " ;3b
	dc.b	".789 "
	dc.b	8 ; backspace
	dc.b	9 ; Tab
	dc.b	$d ; Return
	dc.b    $a ; Enter (44)
	dc.b	27 ; esc
	dc.b	127 ; del
	dc.b	"   " ; Undefined
	dc.b	"-" ; - on numpad
	dc.b	" " ; Undefined
	dc.b	30 ; Up
	dc.b	31 ;down
	dc.b	28 ; forward
	dc.b	29 ; backward
	dc.b	"1" ;f1
	dc.b	"2" ;f2
	dc.b	"3" ;f3
	dc.b	"4" ;f4
	dc.b	"5" ;f5
	dc.b	"6" ;f6
	dc.b	"7" ;f7
	dc.b	"8" ;f8
	dc.b	"9" ;f9
	dc.b	"0" ;f10
	dc.b	"()/*+"
	dc.b	0 ; Help
EnglishKeyShifted:
	; Shifted
	dc.b	"~!@#$%^& ()_+| 0QWERTYUIOP{} 123ASDFGHJKL:",34,"  456 ZXCVBNM<>? .789          - "
	dc.b	0 ; Up
	dc.b	0 ;down
	dc.b	0 ; forward
	dc.b	0 ; backward
	dc.b	0 ;f1
	dc.b	0 ;f2
	dc.b	0 ;f3
	dc.b	0 ;f4
	dc.b	0 ;f5
	dc.b	0 ;f6
	dc.b	0 ;f7
	dc.b	0 ;f8
	dc.b	0 ;f9
	dc.b	0 ;f10
	dc.b	"()/*+"
	dc.b	0 ; Help


TTxt206:	dc.b	"Triangle 20.6Hz",0
TTxt55:		dc.b	"Triangle 55Hz  ",0
TTxt239:	dc.b	"Triangle 239Hz ",0
TTxt440:	dc.b	"Triangle 440Hz ",0
TTxt640:	dc.b	"Triangle 640Hz ",0
TTxt879:	dc.b	"Triangle 879Hz ",0
TTxt985:	dc.b	"Triangle 985Hz ",0
TTxt1295:	dc.b	"Triangle 1295Hz",0
TTxt1759:	dc.b	"Triangle 1759Hz",0
STxt206:	dc.b	"Sinus 20.6Hz   ",0
STxt55:		dc.b	"Sinus 55Hz     ",0
STxt239:	dc.b	"Sinus 239Hz    ",0
STxt440:	dc.b	"Sinus 440Hz    ",0
STxt640:	dc.b	"Sinus 640Hz    ",0
STxt879:	dc.b	"Sinus 879Hz    ",0
STxt985:	dc.b	"Sinus 985Hz    ",0
STxt1295:	dc.b	"Sinus 1295Hz   ",0
STxt1759:	dc.b	"Siuns 1759Hz   ",0

test:
 	dc.b	$a,"# $ % & ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : ; < = > ? @",$a
 	dc.b	"A B C D E F G H I J K L M N O P Q R S T U V W X Y Z Å Ä Ö",0

ROMAudioWaves:

ROMAudio64ByteTriangle:
	dc.b	127,119,111,103,95,87,79,71,63,55,47,39,31,23,15,6
	dc.b	-1,-9,-17,-25,-33,-41,-49,-57,-65,-73,-81,-89,-97,-105,-113,-121,-127
	dc.b	-121,-113,-105,-97,-89,-81,-73,-65,-57,-49,-41,-33,-25,-17,-9,-1
	dc.b	6,15,23,31,39,47,55,63,71,79,87,95,103,111,119,127,127
ROMAudio32ByteTriangle:
	dc.b	127,111,95,79,63,47,31,15
	dc.b	-1,-17,-33,-49,-65,-81,-97,-113,-127
	dc.b	-113,-97,-81,-65,-49,-33,-17,-1
	dc.b	15,31,47,63,79,95,111,127
ROMAudio16ByteTriangle:
	dc.b	127,95,63,31
	dc.b	-1,-33,-65,-97
	dc.b	-127,-97,-65,-33
	dc.b	-1,31,63,95
ROMAudio64ByteSinus:
	dc.b 	0,-12,-25,-37,-49,-61,-72,-82,-91,-100,-107,-113,-119,-123,-126,-127
	dc.b 	-127,-127,-124,-121,-116,-110,-103,-95,-87,-77,-66,-55,-43,-31,-19,-6
	dc.b 	6,19,31,43,55,66,77,87,95,103,110,116,121,124,127,127
	dc.b 	127,126,123,119,113,107,100,91,82,72,61,49,37,25,12,0
ROMAudio32ByteSinus:
	dc.b 	0,-25,-50,-73,-92,-108,-120,-126,-127,-123,-114,-101,-83,-62,-38,-12
	dc.b 	12,38,62,83,101,114,123,127,126,120,108,92,73,50,25,0
ROMAudio16ByteSinus:
	dc.b 	0,-52,-95,-121,-127,-110,-75,-26,26,75,110,127,121,95,52,0
	EVEN
EndROMAudioWaves:

AudioPointers:	; Pointers to actual waveform
	dc.l	0,0,0,0
	dc.l	ROMAudio32ByteTriangle-ROMAudioWaves,ROMAudio32ByteTriangle-ROMAudioWaves
	dc.l	ROMAudio16ByteTriangle-ROMAudioWaves,ROMAudio16ByteTriangle-ROMAudioWaves,ROMAudio16ByteTriangle-ROMAudioWaves
	dc.l	ROMAudio64ByteSinus-ROMAudioWaves,ROMAudio64ByteSinus-ROMAudioWaves,ROMAudio64ByteSinus-ROMAudioWaves,ROMAudio64ByteSinus-ROMAudioWaves
	dc.l	ROMAudio32ByteSinus-ROMAudioWaves,ROMAudio32ByteSinus-ROMAudioWaves
	dc.l	ROMAudio16ByteSinus-ROMAudioWaves,ROMAudio16ByteSinus-ROMAudioWaves,ROMAudio16ByteSinus-ROMAudioWaves
	
AudioLen:	; Length of audio
	dc.w	32,32,32,32,16,16,8,8,8,32,32,32,32,16,16,8,8,8,8
AudioPer:	; Period (speed) of audio
	dc.w	2390,1007,185,126,173,126,225,159,129,2390,1007,185,126,173,126,225,159,129
AudioName:	; Pointers to string of name of wave
	dc.l	TTxt206,TTxt55,TTxt239,TTxt440,TTxt640,TTxt879,TTxt985,TTxt1295,TTxt1759
	dc.l	STxt206,STxt55,STxt239,STxt440,STxt640,STxt879,STxt985,STxt1295,STxt1759

Octant_Table:
	dc.b	0*4+1
	dc.b	4*4+1
	dc.b	2*4+1
	dc.b	5*4+1
	dc.b	1*4+1
	dc.b	6*4+1
	dc.b	3*4+1
	dc.b	7*4+1

Music:
	incbin	"Music.MOD"
	EVEN
TestPic:
	incbin	"TestPIC.PI1"
EndTestPic:
	EVEN
EndMusic:
	dc.b	"This is the brutal end of this ROM, everything after this are just pure noise.    End of Code...",0

EndRom:
		
	EVEN
; Here you put REFERENCES to variabes in RAM. remember that you cannot know what is stored in
; this part of memory. so you have to set any default values in the code or data will be random.

Variables:
	blk.b	8192,0			; Just reserve memory for "Stack" not used in nonrom mode
Endstack:
	EVEN
V:
	dc.l	0			; Just a string to mark first part of data
StackSize:
	dc.l	0			; Will contain size of the stack	
StartAddress:
	dc.l	0
Bpl1Ptr:
	dc.l	0			; Pointer to Bitplane 1
Bpl2Ptr:
	dc.l	0			; Pointer to Bitplane 2
Bpl3Ptr:
	dc.l	0			; Pointer to Bitplane 3
BplEnd:
	dc.l	0			; Let it be 0
Xpos:	dc.l	0			; Variable for X position on screen to print on
Ypos:	dc.l	0			; Variable for Y position on screen to print on

shit:	dc.l	0			; crapvariable for debugging
b2dTemp:	dc.l	0,0
b2dString:	dc.l	0,0,0
bindecoutput:
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0
	EVEN
binhexoutput:
	blk.b	10,0
binstringoutput:
	blk.b	33,0

Color:	dc.b	0
	EVEN
HexBinBin:
	dc.l	0
SerialSpeed:
	dc.w	0
OldSerialSpeed:
	dc.w	0
keymap:
	dc.l	0			; Points to keymap to be used.
NoSerial:
	dc.b	0			; if other then 0, no serial output at start.
GetCharData:
	dc.b	0			; Result of GetChar
keypressed:
	dc.b	0,0			; What key is pressed
keypressedshifted:
	dc.b	0,0			; Same but without shift
keyresult:
	dc.b	0,0			; Actual result to be printed on screen
scancode:
	dc.b	0			; Scancode from buffer
key:
	dc.b	0			; Keycode
keyctrl:
	dc.b	0
keyalt:
	dc.b	0
keyshift:
	dc.b	0			; if !0 = shift is pressed Will actually contain the scancode
keycaps:
	dc.b	0
keyup:
	dc.b	0			; if 1 = key is pressed
keydown:
	dc.b	0
keystatus:
	dc.b	0
keynew:
	dc.b	0			; if 1 the keypress is new
keyrepeat:
	dc.b	0			; if 1 the key is still pressed down

	EVEN
	
ChipStart:
	dc.l	0			; Start of detected chipmem
ChipEnd:
	dc.l	0			; End of chipmem
ChipUnreserved:
	dc.l	0			; Total of UNRESERVED Chipmem detected
ChipUnreservedAddr:
	dc.l	0			; END of the Unreserved space
GetChipAddr:
	dc.l	0			; Response from GetChip routine
TotalChip:				; Total Chipmem detected
	dc.l	0
TotalFast:
	dc.l	0			; Total Motherboard Fastmem detected
ChipAdr:
	dc.l	0			; Where chipmem starts
oldkey:
	dc.l	0
InputRegister:
	dc.l	0	; the value of D0 of GetInput is stored here aswell
OldMouse1X:
	dc.b	0	; old value of mouseport X
OldMouse1Y:
	dc.b	0	; mouseport Y
OldMouse2X:
	dc.b	0	; old value of mouseDATA on non mouseport X
OldMouse2Y:
	dc.b	0	; Y
MouseX:
	dc.b	0	; Mouse X position
MouseY:
	dc.b	0	; Mouse Y Position
OldMouseX:
	dc.b	0
OldMouseY:
	dc.b	0
MOUSE:
	dc.b	0	; if not 0, moouse is moved
BUTTON:
	dc.b	0	; if not 0, a button is pressed
MBUTTON:
	dc.b	0	; if not 0, a mousebutton is pressed
LMB:
	dc.b	0	; if not 0, LMB pressed
RMB:
	dc.b	0	; if not 0, RMB pressed
MMB:
	dc.b	0	; if not 0, MMB pressed
P1LMB:
	dc.b	0	; if not 0, LMB port1 pressed
P2LMB:
	dc.b	0	; if not 0, LMB port2 pressed
P1RMB:
	dc.b	0	; if not 0, RMB port1 pressed
P2RMB:
	dc.b	0	; if not 0, RMB port1 pressed
P1MMB:
	dc.b	0	; if not 0, MMB port1 pressed
P2MMB:
	dc.b	0	; if not 0, MMB port1 pressed
STUCKP1LMB:
	dc.b	0	; if not 0, LMB port1 stuck and should be ignored
STUCKP2LMB:
	dc.b	0	; if not 0, LMB port2 stuck and should be ignored
STUCKP1RMB:
	dc.b	0	; if not 0, RMB port1 stuck and should be ignored
STUCKP2RMB:
	dc.b	0	; if not 0, RMB port1 stuck and should be ignored
STUCKP1MMB:
	dc.b	0	; if not 0, MMB port1 stuck and should be ignored
STUCKP2MMB:
	dc.b	0	; if not 0, MMB port1 stuck and should be ignored
RASTER:
	dc.b	0	; if not 0, We have detected working raster
	even
HLINE:
	dc.w	0	; if not 1, Then the timer did not work/expire
SerData:
	dc.b	0	; if 0  we had no serialdata
Serial:
	dc.b	0	; Will contain data from the serialport
OldSerial:
	dc.b	0	; Will contain the last char that was detected on the serialport
SerBufLen:
	dc.b	0	; Current length of serialbuffer
SerBuf:
	blk.b	256,0	; 256 bytes of serialbuffer
SerAnsiFlag:
	dc.b	0	; nonzero means that we are in buffermode (number is actually number of chars in buffer)
SerAnsiBufLen:
	dc.b	0	; Buffertlength used for the moment.
	EVEN
SerAnsiChecks:
	dc.w	0	; Number of checks with a result of 0 in Ansimode.
SerAnsiBuff:
	dc.l	0	; Reserve a longword for ANSI serialbuffer
PrintMenuFlag:
	dc.b	0	; if set to anything else then 0, print the menu
UpdateMenuFlag:
	dc.b	0	; if set to anything else then 0, update the menu.
UpdateMenuNumber:
	dc.b	0	; What itemnumber to update. 0 = all  (0 is the only that prints label)
MenuEntrys:
	dc.b	0	; Will contain number of entrys in the menu being displayed
MenuPos:
	dc.b	0	; What menu item to highlight
MenuChoose:
	dc.b	0	; If anything else then 0, user have chosen this item on the menu
MenuMouseAdd:
	dc.w	0	; Variable for how many mousetics have been done..
MenuMouseSub:
	dc.w	0	
PortJoy0:		; Detected directions of Joystick 0
	dc.l	0
PortJoy1:		; Detected directions of Joystick 1
	dc.l	0
P0Fire:
	dc.w	0	; Detected fire on Joystick 0
P1Fire:
	dc.w	0	; Detected fire on Joystick 1
P0FireOLD:
	dc.w	0	; just to detect changes.
P1FireOLD:
	dc.w	0
PortJoy0OLD:
	dc.l	0
PortJoy1OLD:
	dc.l	0
OldMarkItem:
	dc.b	0	; Contains the item marked before
MarkItem:
	dc.b	0	; Contains the item being marked.
	EVEN
	dc.l	0
NoDraw:
	dc.b	0	; If this is other then 0, no screen is drawn, no text. for "no chipmem" modes
	EVEN
	dc.l	0
MenuNumber:
	dc.w	0	; Contains the menunuber to be printed, from the Menus list
NoChar:	dc.b	0	; if 0 print char, anything else, never do screenactions. (no chipmem avaible)
Inverted:
	dc.b	0	; if 0, former char was not inverted
	EVEN
Menu:
	dc.l	0	; What menulist to use
MenuVariable:
	dc.l	0	; List of pointers to variables to print after menuitem.

CurX:	dc.w	0	; Cursor X pos. "mouse" cursor
CurY:	dc.w	0	; Cursor Y pos
CurAddX:
	dc.w	0	; How much was added in X dir
CurSubX:
	dc.w	0	; How much was subtracted uin X dir
CurAddY:
	dc.w	0
CurSubY:
	dc.w	0
temp:	dc.l	0,0,0,0,0,0,0,0,0,0	; 10 longwords reserved for temporary crapdata
nomem:	dc.l	0
AudSimpVar:		; Variablelist for the menusystem
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0

AudSimpChan1:
	dc.b	0
AudSimpChan2:
	dc.b	0
AudSimpChan3:
	dc.b	0
AudSimpChan4:
	dc.b	0
AudSimpVol:
	dc.b	0
AudSimpWave:
	dc.b	0
AudSimpFilter:
	dc.b	0	
AudSimpVolStr:
	blk.b	10,0
	EVEN
AudioWaveNo:
	dc.w	0			; What wave to play
AudioModAddr:
	dc.l	0			; Address of module in modtest
AudioModInit:
	dc.l	0			; Address to MT_Init
AudioModEnd:
	dc.l	0			; Address to MT_End
AudioModMusic:
	dc.l	0			; Address to MT_Music
AudioModMVol:
	dc.l	0			; Address to Mastervolume
AudioModData:
	dc.l	0			; Address to mt_data (pointer to mod)
AudioModStatData:			; Audiomod status
	dc.b	0,0,0,0			; if channels if turned off or not (1=OFF)
	dc.b	0			; Audiofilter
	dc.b	64			; Mastervolume
	dc.b	0,0
AudioModStatFormerData:			; NO DATA IN BETWEEN HERE!!! OR YOU WILL HAVE BUGS!!
	dc.b	0,0,0,0
	dc.b	0,0			; Just a backup of former state of above.
	dc.b	0,0			; so it will not update all everytime.
IRQLevDone:
	dc.w	0
Frames:	dc.w	0			; Number of frames shown
Ticks:	dc.l	0			; Number of "ticks" in CIA test
TickFrame:
	dc.w	0			; how many frames reached when CIA test was done.
CIACtrl:
	dc.l	0
RTCold:
	dc.l	0			; How RTC first longword was last read
RTCString:
	blk.b	14,0			; Block of RTC data
MemTestStart:
	dc.l	0
MemTestEnd:
	dc.l	0
MemTestFail:
	dc.l	0,0,0,0			; Add 1 to every byte that is wrong during check
	
GfxChipset:
	dc.b	0			; What GfxChipset is detected: 0 = OCS, 1 = ECS, 2 = AGA

	EVEN
BootMBFastmem:				; Amount of motherboard fastmem detected at bootpoint
	dc.l	0
CheckMemFrom:
	dc.l	0			; Startaddress of memory to check
CheckMemTo:
	dc.l	0			; endaddress to check memory
CheckMemCurrent: 
	dc.l	0			; current address to check
CheckMemChecked:
	dc.l	0			; how much memory is checked
CheckMemUsable:
	dc.l	0			; how much usable memory
CheckMemNonUsable:
	dc.l	0			; how much non usable memory
CheckMemBitErrors:
	blk.b	32,0			; number of errors in each bit in a longword (max 255 errors per bit)
CheckMemByteErrors:
	dc.l	0,0,0,0			; number of errors on each byte in a longword
CheckMemErrors:
	dc.l	0			; Number of errors foun
CheckMemType:
	dc.b	0			; type of memory detected last time 0=none  1=Error 2=Good
CheckMemOldType:
	dc.b	0
CheckMemTypeChange:			; if 0, there is no change of type
	dc.b	0
CheckMemRow:
	dc.b	0			; What row to print message of type of memory on
CheckMemCol:
	dc.b	0			; What color to print row at
CheckMemFast:
	dc.b	0			; if anything else then 0, a fast scan will be perfomed
CheckMemNoShadow:
	dc.b	0			; if anything else then 0, no shadowcheck will be done
CheckMemManualX:
	dc.b	0			; Contains X cord of current text to input while asking for memadress
CheckMemManualY:
	dc.b	0			; .... and Y
CheckMemStartAdrTxt:
	dc.b	0,0,0,0,0,0,0,0,0	; String for startaddress
CheckmemEndAdrTxt:
	dc.b	0,0,0,0,0,0,0,0,0	; String for endaddress
	EVEN
CheckMemTypeStart:
	dc.l	0			; Startaddress of this "type" of memory
CheckMemEditAdr:
	dc.l	0			; Current address cursor points to in edit-mode
CheckMemEditScreenAdr:
	dc.l	0			; Startaddress of memorydump on screen in edit-mode
CheckMemEditXpos:
	dc.b	0			; Current X pos of cursor
CheckMemEditYpos:
	dc.b	0			; Current Y pos of cursor
CheckMemEditOldXpos:
	dc.b	0			; Old X pos of cursor
CheckMemEditOldYpos:
	dc.b	0			; Old Y pos of cursor
CheckMemEditCharPos:
	dc.b	0			; Current pos to edit memory.  0 or 1, 0 = high nibble, 1 = low)
KeyBOld:
	dc.b	0			; Stores old scancode of keyboard

	even
FirstMBMem:
	dc.l	0
MBMemSize:
	dc.l	0
DebD0:
	dc.l	0			; For debug..  to store registers
DebD1:
	dc.l	0			; For debug..  to store registers
DebD2:
	dc.l	0			; For debug..  to store registers
DebD3:
	dc.l	0			; For debug..  to store registers
DebD4:
	dc.l	0			; For debug..  to store registers
DebD5:
	dc.l	0			; For debug..  to store registers
DebD6:
	dc.l	0			; For debug..  to store registers
DebD7:
	dc.l	0			; For debug..  to store registers
DebA0:
	dc.l	0			; For debug..  to store registers
DebA1:
	dc.l	0			; For debug..  to store registers
DebA2:
	dc.l	0			; For debug..  to store registers
DebA3:
	dc.l	0			; For debug..  to store registers
DebA4:
	dc.l	0			; For debug..  to store registers
DebA5:
	dc.l	0			; For debug..  to store registers
DebA6:
	dc.l	0			; For debug..  to store registers
DebA7:
	dc.l	0			; For debug..  to store registers



; Reserved area for dumps of customregisters
_MEMCONF:
	dc.b	0
	EVEN
_V_BAS_H:
	dc.b	0
	EVEN
_V_BAS_M:
	dc.b	0
	EVEN
_V_BAS_L:
	dc.b	0
	EVEN
_V_ADR_H:
	dc.b	0
	EVEN
_V_ADR_M:
	dc.b	0
	EVEN
_V_ADR_L:
	dc.b	0
	EVEN
_V_SYNC:
	dc.b	0
	EVEN
_V_MODE:
	dc.b	0
	EVEN
DMACONR:
	dc.w	0
VPOSR:
	dc.w	0
VHPOSR:
	dc.w	0
DSKDATR:
	dc.w	0
JOY0DAT:
	dc.w	0
JOY1DAT:
	dc.w	0
CLXDAT:
	dc.w	0
ADKCONR:
	dc.w	0
POT0DAT:
	dc.w	0
POT1DAT:
	dc.w	0
POTINP:
	dc.w	0
SERDATR:
	dc.w	0
DSKBYTR:
	dc.w	0
INTENAR:
	dc.w	0
INTREQR:
	dc.w	0
DENISEID:
	dc.w	0
HHPOSR:
	dc.w	0
CIAAPRA:
	dc.w	0

GfxTestBpl:				; Pointers to bitplanes for gfxtest
	dc.l	0,0,0,0,0,0,0,0
SHIT:
	dc.l	0			; SHITData
ZorroSize:
	dc.l	0

C:
	EVEN
MenuCopper:
	blk.b	EndRomMenuCopper-RomMenuCopper,0
	EVEN
ECSCopper:
	blk.b	EndRomEcsCopper-RomEcsCopper,0

	; Put this data at the end of everything.

AudioWaves:
	blk.b	EndROMAudioWaves-ROMAudioWaves,0

	EVEN
DummySprite:
	dc.l	0

Bpl1str:
	dc.l	0			; Space for the "BPL1" string
Bpl1:
	blk.b	81*256,2		; bitplane 1
EndBpl1:

Bpl2str:
	dc.l	0			; Space for the "BPL1" string
Bpl2:
	blk.b	80*256,33		; bitplane 2
EndBpl2:


	
Bpl3str:
	dc.l	0			; Space for the "BPL1" string
Bpl3:
	blk.b	80*256,3		; bitplane 3
EndBpl3:
	
	dc.l	0			; extra null-longword

ptplay:
	blk.b	mt_END-MT_Init,0			; Reserve memory of protracker replayroutine

	EVEN


	dc.b	"This is the brutal end of this ROM, everything after this are just pure noise.    End of Code...",0

	EVEN

EndData:
	dc.l	0

BITTEREND:
	blk.b	$40000-(BITTEREND-START)-16,0		; Crapdata that needs to be here
	dc.l	$00180019,$001a001b,$001c001d,$001e001f	; or IRQ will TOTALLY screw up on machines with 68000-68010

ROMEND:
