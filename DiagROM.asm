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
	move.w	#$f00,color0	 ; red screen
	move.b  #$0a,(memconf)	 ; set hw to 2 banks by 2 mb (reg 0xffff8001 - memorycontroller) 

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
	
	;	sub.l	#EndData-Variables,a6	; Subtract total chipmemsize, putting workspace at end of memory
	;	sub.l	#2048,a6		; Subtract 2Kb more, "just to be sure"
	;					; A6 from now on points to where diagroms workspace begins. do NOT change A6
	;					; A6 is from now on STATIC

	PAROUT #$fd
	KPRINTSLN	"- Parallel Code $fb - Memorydetection done"

	; POSTDetectFastmem

	;	memdetection done
	
	;	d0				; total chipmem *32
	;	d1				; total fastmem *64
	;	a0				; Start of Fastmemblock
	;	a1				; end of fastmemblock
	;	a4				; Startupbits (pressed mousebuttons etc)
	;	a7				; Start of chipmem

	

	; Copy the workspace

	; Start the meu


_halt:
	jmp _halt

BusError:
	SHOWERROR 'Bus Error Detected'

AddressError:
	SHOWERROR 'Address Error Detected'

IllegalError:
	SHOWERROR 'Illegal Instruction Detected'

DivByZero:
	SHOWERROR 'Division by Zero Detected'

ChkInst:
	SHOWERROR 'Chk Inst Detected'

TrapV:
	SHOWERROR 'TRAP V Detected'

PrivViol:
	SHOWERROR 'Privilige Violation Detected'

Trace:
	SHOWERROR 'Trace Detected'

UnimplInst:
	SHOWERROR 'Unimplemented instruction Detected'

Trap:
	SHOWERROR 'Trap Detected'
		
ErrorScreen: 
	jmp ErrorScreen

POSTBusError:
	POSTError $f00, $fff, 'Bus Error Detected'

POSTAddressError:
	POSTError $f00, $f0f, 'Address Error Detected'

POSTIllegalError:
	POSTError $f00, $ff0, 'Illegal Instruction Detected'

POSTDivByZero:
	POSTError $f00, $ff0, 'Division by Zero Detected'

POSTChkInst:
	POSTError $f00, $00f, 'Chk Inst Detected'

POSTTrapV:
	POSTError $000, $fff, 'TrapV Detected'

POSTPrivViol:
	POSTError $000, $f0f, 'Privilige Violation Detected'
	
POSTTrace:
	POSTError $000, $0ff, 'Trace Detected'

POSTUnimplInst:
	POSTError $000, $ff0, 'Unimplemented Instruction Detected'

POSTErrorScreen: 
	jmp POSTErrorScreen

HBLHandler:
	add.w	 #1,HLINE-V(a6)
	rte

VBLHandler:
	move.w	 #0,HLINE-V(a6)
	rte

RTEcode:
	rte

; STATIC Data located here.  (HEY!! it IS in ROM!)

RomFont:
	incbin	TopazFont.bin
EndRomFont:
	EVEN

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

Ansi:
	dc.b	27,"[",0
AnsiNull:
	dc.b	27,"[0m",27,"[40m",27,"[37m",0
Black:
	dc.b	27,"[30m",0


; Here you put REFERENCES to variabes in RAM. remember that you cannot know what is stored in
; this part of memory. so you have to set any default values in the code or data will be random.

Variables:
	blk.b	8192,0	; Just reserve memory for "Stack" not used in nonrom mode
Endstack:
	EVEN
V:
	dc.l	0	; Just a string to mark first part of data
StackSize:
	dc.l	0	; Will contain size of the stack	
StartAddress:
	dc.l	0
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

				; Put this data at the end 
Bpl1str:
	dc.l	0	; Space for the "BPL1" string
Bpl1:
	blk.b	81*256,2		; bitplane 1
EndBpl1:	
	dc.l	0	; extra null-longword

	EVEN

	dc.b	"This is the brutal end of this ROM, everything after this are just pure noise.    End of Code...",0

	EVEN

EndData:
	dc.l	0

BITTEREND:
	blk.b	$40000-(BITTEREND-START)-16,0		; Crapdata that needs to be here
	dc.l	$00180019,$001a001b,$001c001d,$001e001f	; or IRQ will TOTALLY screw up on machines with 68000-68010

ROMEND:
