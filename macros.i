	

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
	btst #7,mfp_tsr
	beq  .waitloop\@
	move.b	\1,mfp_udr

ENDM

KPRINT: MACRO

	lea		\1,a0
	clr.l	d2				; Clear d0
.\@loop:
	move.b	(a0)+,d2

	cmp.b	#0,d2				; end of string?
	beq	.\@finished				; yes

	SENDSERIAL d2

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
	SENDSERIAL #$a
	SENDSERIAL #$d
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
	SENDSERIAL d2
	move.b	(a0)+,d2
	SENDSERIAL d2
ENDM


KPRINTHEX16: MACRO
   move.w  \1,d4
   lsr     #8,d4
   KPRINTHEX8 d4
   move.w  \1,d4
   KPRINTHEX8 d4
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

POSTDetectChipmem: MACRO
\@:
	lea	$400,a6				; Lets scan memory, start at $400
	move.l	#$33333333,(a6)	; Write a number that is NOT in the memcheck table. for shadowcheck
	clr.l	d0			
	clr.l	d3				; if d3 is not null, it contains first memaddr found
	
	KNEWLINE

.detectloop:
	move.l	(a6),d5				; Do a backup of content
	lea	MEMCheckPatternFast,a5		; Load list of data to test
	bclr	#31,d0
.memloop:

	SENDSERIAL #$d	
	KPRINTS 'Addr $'

	move.l	a6,d1
	KPRINTHEX32 d1

	move.l	(a5),(a6)			; Write data to memory
	move.l	(a5),d1
	asl.l	#4,d1
	and.w	#$0f0,d1
	move.w	d1,color0			; Write data to screen as green only.

	move.l	(a6),d4				; Read data from memory
	cmp.l	(a5),d4				; Check if written data is the same as the read data.
	beq	.ok				; YES it is OK

	cmp.l	#0,d3				; Check if d3 is 0, in that case we havent found any memory
						; and user might want to see whats wrong. if we had. we are simply out of mem
	bne	.faildone

	KPRINTS 'Write:'

	move.l	a6,d1				; Print address to check

	move.l	(a5),d1
	KPRINTHEX32 d1

	KPRINTS 'Read:'

	move.l	d4,d1
	KPRINTHEX32 d1
	KPRINTSLN '   FAILED'

.faildone:
	bset	#31,d0				; set bit 31 in d0 to tell we had an error
	move.w	#$f00,color0
.ok:
	cmp.l	#$400,a6
	beq	.yes400				; if we are checking address 400, skip this
	move.l	$400,d4
	beq	.shadow				; ok, we are not checking address 400, BUT we had same data there. meaning
						; we have a shadow. so exit

.yes400:
	TOGGLEPWRLED

	cmp.l	#0,(a5)+			; Was last longword tested null? if not, repeat
	bne	.memloop

	btst	#31,d0
	bne	.fail				; did we have failed memory

	cmp.l	#0,d3				; check if this is the first block of good memory
	bne	.notfirst
	move.l	a6,d3				; Store that this was the first sucessful memory

.notfirst:
	add.w	#1,d0				; Add 1 to mark a sucessful block

	KPRINTS '   OK'
	KPRINTS '  Number of 32K blocks found: $'

	move.l	d0,d1
	KPRINTHEX8 d1
	bra .longdone
.fail:						; We had a failure

	cmp.l	#0,d3				; Check if d3 is 0, in that case we havent found any memory yet
	beq	.longdone
						; ok we had memory, so this is the endblock.
	bra	.finished			; lets stop all check. we have found it all.

.longdone:
	move.l	d5,(a6)				; Restore backupped data

	add.l	#32768,a6			; Add 32k to a6
	cmp.l	#$200000,a6			; have we scanned more then 2MB of data, exit
	bhi	.finished
	bra	.detectloop			; Do one more turn.

.shadow:
	move.l	#"SHDW",(a6)			; to test that we REALLY have a shadowram. write a string
	cmp.l	#"SHDW",$400			; and check it at $400,  if it is there aswell SHADOW
	bne	.yes400				; go on checking ram. we did not have shadow

	KNEWLINE
	KPRINTSLN 'Chipmem Shadowram detected, guess there is no more chipmem, stopping here'

.finished:

	bclr	#31,d0				; Clear "the errorbit"
	cmp.l	#0,d0				; check if we had no chipmem
	beq	.nochipatall

	KNEWLINE
	KPRINTS 'Startaddr: $'

	move.l	d3,a7				; Store start of chipmem to a7
	move.l	d3,d1
	KPRINTHEX32 d1

	KPRINTS ' Endaddr: $'

	sub.l	#$400,a6
	move.l	a6,d1
	KPRINTHEX32 d1
	KNEWLINE
	bra	.exit

.nochipatall:

	KPRINTSLN 'NO Chipmem detected'

.exit:

ENDM

MEMCheck: MACRO
\@:
.memchk:     adda.l    d1,a0                     ; a0 -> memory to check
            clr.w     d0                        ; zap pattern seed
            lea       $1f8(a0),a1               ; a1 -> ending address
.memchk1:    cmp.w     (a0)+,d0                  ; match?
            bne.s     .memchkr                   ; (no -- return NE)
            add.w     #$fa54,d0                 ; yes -- bump pattern
            cmpa.l    a0,a1                     ; matched entire pattern?
            bne.s     .memchk1                   ; (no)
.memchkr:   

ENDM

MMUConfigure: MACRO

* First we try to configure the memory controller

            clr.w     d6
            move.b    #$a,(memconf).w			; default: setup controller for 2Mb/2Mb

            movea.w   #$8,a0
            lea       ($200008).l,a1			; + 2Mb
            clr.w     d0
chkpatloop: move.w    d0,(a0)+					; fill 512-8 bytes with a test pattern
            move.w    d0,(a1)+
            add.w     #$fa54,d0
            cmpa.w    #$200,a0
            bne.s     chkpatloop

            move.b    #90,(v_bas_l).w			; wrote low byte of video address
            tst.b     (v_bas_m).w				; touch the middle byte (this should reset the low byte)
            move.b    (v_bas_l).w,d0
            cmp.b     #90,d0					; low byte not reset?
            bne.s     chkmem1
            clr.b     (v_bas_l).w				; try a different low byte value
            tst.w     (palette).w				; touch the color palette
            tst.b     (v_bas_l).w				; low byte changed?
            bne.s     chkmem1
            move.l    #$40000,d7				; 256Kb offset
            bra.s     chkmem1b
chkmem1:    move.l    #$200,d7					; 512 byte offset
chkmem1b:   move.l    #$200000,d1				; 2Mb = maximum size per bank

chkmemloop: lsr.w     #2,d6						; shift memory configuration down by a bank (bank 1 is in bits 0..1, bank 0 is in bits 2..3)

            movea.l   d7,a0						; + 512/256Kb bytes
            addq.l    #8,a0
            lea       chkmem3(pc),a4
            MEMCheck
chkmem3:    beq.s     chkmem7					; bank is not working =>

            movea.l   d7,a0
            adda.l    d7,a0						; + 1024/512Kb byte
            addq.l    #8,a0
            lea       chkmem4(pc),a4
            MEMCheck
chkmem4:    beq.s     chkmem6					; bank has 512Kb of memory =>

            movea.w   #$8,a0					; + 0 bytes
            lea       chkmem5(pc),a4
            MEMCheck
chkmem5:    bne.s     chkmem7					; bank is empty =>

            addq.w    #4,d6						; 4+4 = 1000 2Mb bank size
chkmem6:    addq.w    #4,d6						; 4   = 0100 512Kb bank size
chkmem7:    sub.l     #$200000,d1				; - 2Mb
            beq.s     chkmemloop
            move.b    d6,(memconf).w			; set memory configuration
ENDM