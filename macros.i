
ROMVERSION: MACRO
	ifne STE_ROM    ; if STE_ROM = 1
	dc.w	$0206		; pretend we are TOS 2.06 to emulators.	
	else
	dc.w	$0104		; pretend we are TOS 1.06 to emulators.	
	endc
ENDM

ROMHEADER: MACRO
	ifne ST_CART ; if ST_CART = 1
	dc.l $FA52235F 
	bra.s	_main
	else
	bra.s	_main
	ROMVERSION
	endc
ENDM

PUSH:	MACRO
	movem.l a0-a6/d0-d7,-(a7)	;Store all registers in the stack
	ENDM

POP:	MACRO
	movem.l (a7)+,a0-a6/d0-d7	;Restore the registers from the stack
	ENDM

PWRLEDON: MACRO
	NOP 
	ENDM

PWRLEDOFF: MACRO

	NOP

ENDM

VBLT: MACRO

	NOP

ENDM

TOGGLEPWRLED: MACRO

	NOP
	ENDM
	
PAROUT: MACRO

	move.b	#$ff,parddr		; set the parallel port data direction register
	move.b	\1,parport		; Send #$ff to Paralellport.

ENDM

SHOWERROR: MACRO

	lea	.Txt\@,a0
	jmp	ErrorScreen
.Txt\@	dc.b 2, \1, 0
	EVEN

ENDM

POSTError: MACRO

	lea	.Txt\@,a0
	move.w	#\1,d5
	move.l	#\2,d6
	bra	POSTErrorScreen
	PRINTT \3
.Txt\@:	dc.b 2, \3, 0

	EVEN

ENDM

; send a character to the serial port
SENDSERIAL: MACRO

.waitloop\@:

	sub.l	#1,\2				; count down timeout value
	cmp.l	#0,\2				; if 0, timeout.
	beq	.endloop\@

	btst #7,mfp_tsr
	beq  .waitloop\@
	move.b	\1,mfp_udr
.endloop\@:
ENDM

SENDMIDI: MACRO
.waitloop\@:
	sub.l	#1,\2				; count down timeout value
	cmp.l	#0,\2				; if 0, timeout.
	beq	.endloop\@

	btst #1,acia_midi_ctrl
	beq  .waitloop\@

	move.b	\1,acia_midi_data
.endloop\@:

ENDM

PUTCHAR: MACRO

	move.l \3,\2
	SENDSERIAL \1,\2
	move.l \3,\2
	SENDMIDI \1,\2

ENDM

KPRINT: MACRO

	lea		\1,a0
	clr.l	d7				; Clear d7
.\@loop:
	move.b	(a0)+,d7

	cmp.b	#0,d7				; end of string?
	beq	.\@finished				; yes

	PUTCHAR d7, d2, #10000

	bra	.\@loop
.\@finished:

ENDM

KPRINTS: MACRO

	KPRINT .Txt\@
	bra .\@finished
.Txt\@: dc.b \1,0
	EVEN
.\@finished:

ENDM


KNEWLINE: MACRO

	PUTCHAR #$a, d2, #10000
	PUTCHAR #$d, d2, #10000

ENDM


KPRINTLN: MACRO
	KPRINT \1
	KNEWLINE	
ENDM


KPRINTSLN: MACRO
	KPRINTS \1
	KNEWLINE
ENDM


KPRINTHEX8: MACRO
	lea	ByteHexTable,a0
	clr.l	d2
	move.b	\1,d2
	asl	#1,d2
	add.l	d2,a0
	move.b	(a0)+,d2

	PUTCHAR d2,d7, #10000

	move.b	(a0)+,d2

	PUTCHAR d2,d7, #10000

	; Resources
	ByteHexTableResource

ENDM

KPRINTHEX16: MACRO
   move.l  \1,d6
   asr     #8,\1
   KPRINTHEX8 \1
   move.l  d6,\1
   KPRINTHEX8 \1
ENDM

KPRINTHEX32:MACRO
	swap \1
	KPRINTHEX16 \1
	swap \1
	KPRINTHEX16 \1
ENDM


SETALLCOLORS: MACRO
	lea		color0,a0
	move.w 	#16-1,d1
.cloop1
	move.w	#\1,(a0)+
	dbra	d1,.cloop1	
	ENDM

SETTIMER: MACRO
\@:
		lea	      mfp_gpip,a0                  ; set mfp chip address pointer

		moveq     #\1,d0               
		moveq     #\2,d1               
		moveq     #\3,d2               

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
.verify     move.b    d2,(a0,d3.w)
		cmp.b     (a0,d3.w),d2
		bne.s     .verify

		exg       a3,a1                     ; grab that register address back
		or.b      d1,(a3)                   ; mask the timer control register value
	ENDM

RESETMFP: MACRO
		
	move.b  #$0,mfp_gpip 	; Clear register.
	move.b  #$0,mfp_aer 	;
	move.b  #$0,mfp_dd

	move.b  #$0,mfp_iera
	move.b  #$0,mfp_ierb
	move.b  #$0,mfp_ipra
	move.b  #$0,mfp_iprb
	move.b  #$0,mfp_isra
	move.b  #$0,mfp_isrb
	move.b  #$0,mfp_imra 
	move.b  #$0,mfp_imrb 
	move.b  #$0,mfp_vr

	move.b  #$0,mfp_tacr
	move.b  #$0,mfp_tbcr
	move.b  #$0,mfp_tcdcr
	move.b  #$0,mfp_tadr
	move.b  #$0,mfp_tbdr
	move.b  #$0,mfp_tcdr
	move.b  #$0,mfp_tddr

	move.b  #$0,mfp_rsr
	move.b  #$0,mfp_tsr

	ENDM

InitMFP: MACRO
\@:	
   	;; setup the serial port
	lea       (mfp_gpip).w,a0           ; init mfp address pointer
	moveq     #0,d0                     ; init to zero for clearing mfp
	movep.l   d0,0(a0)                  ; clear gpip thru iera
	movep.l   d0,8(a0)                  ; clear ierb thru isrb
	movep.l   d0,$10(a0)                ; clear isrb thru vr
	move.b    #$48,$16(a0)              ; set mfp autovector to $100 and s-bit	
	bset      #2,2(a0)                  ; set cts to low to high transition

	move.l	  #RTEcode,$114

	;* init the "d" timer		
	; select the d timer, init for /4 for 9600 baud, init for 9600 baud
	
	SETTIMER  3,1,2

	lea       (mfp_gpip).w,a0
	move.l    #$880105,d0
    movep.l   d0,$26(a0)                ; inits scr,ucr,rsr,tsr

	;; mfp table resource is only defined once. 
	MFPTableResource

ENDM

InitMidi: MACRO

	; init the midi acia next
    move.b    #$03,(acia_midi_ctrl).w          ; init the midi acia via master reset

	; init the acia to divide by 16x clock, 8 bit data, 1 stop bit, no parity,
	; rts low, transmitting interrupt disabled, receiving interrupt enabled
    move.b    #$95,(acia_midi_ctrl).w

ENDM

InitVideo: MACRO
	
	; TODO: Refactor
	move.b	  #$1,v_mode ; set medium res
	move.b 	  #$2,v_sync ; setup pal
	
	; load display address (add 255 & round off low byte for STF)
	move.l	#\1,d0 ;  $00HHMMLL 
	add.l	#$FF,d0
	lsr.w #8,d0 ; $00HH00MM
	move.l d0,v_base ; load mid and high bytes of gapped 24bit address. low byte not assigned.
	
ENDM

IKBDWrite: MACRO
    
	lea.l     (ACIA_IKBD_BASE).w,a2        ; point to ikbd register base 
	move.l	  #900000,d3	; make sure we dont wait for the keyboard forever.

.\@ikbd_wr1
    move.b    (a2),d2           ; grab keyboard status
	sub.l	#1,d3				; count down timeout value
	cmp.l	#0,d3				; if 0, timeout.
	beq		.\@fail
	
	btst      #1,d2	
	beq.s     .\@ikbd_wr1

	lea	mfp_tcdr,a0
	move.w	#$BF,d0
.\@oloop		
	move.b	(a0),d2
	dbf	d0,.\@oloop

	move.b    \1,ACIA_DATA(a2)  ; write char to the ikbd port 
	move.l	  #0,d0

	bra		  .\@exit
.\@fail:
	move.l	  #1,d0	
.\@exit:

ENDM

IKBDRead: MACRO
	move.w	#0,d1
.\@status
	lea.l	(ACIA_IKBD_BASE).w,a2
	move.b	slowcia,d0			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	move.b   ACIA_CTRL(a2),d0   ; read status byte 
	btst	#0,d0
	beq.s	.\@none
	
	move.b   ACIA_DATA(a2),d1      ; read data byte 
.\@none

ENDM

TestMemWord: MACRO

	move.w	#\1,d1
	move.w	d1,\2
	move.w	\2,d0

	cmp.w	d0,d1
	bne		.fail
	KPRINTSLN 'OK.'
	bra		.done	
.fail:
	KPRINTSLN 'FAILED.'
.done:
ENDM

HWRegPrintByte: MACRO
\@:
	lea	.label,a0
	move.w	#7,d1
	bsr	Print
	move.b	\1-V(a6),d0
	bsr	binhexbyte
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	bra .exit
.label:
	dc.b \2, 0 
	EVEN
.exit:
ENDM


