        
DetectMemory: MACRO
\@:
					; D1 Total block of known working ram in 16K blocks (clear before first use)
					; A0 first usable addr
					; a1 First addr to scan
					; a2 Addr to end
					; a3 Addr to jump after done (as this does not use any stack
					; only OK registers to use as write: (d1), d2,d3,d4,d5,d6,d7, a0,a1,a2,a5


					; D0 is a special "in" never to be modified but taken as a "random" generator for shadowcontrol

					; OUT:	d1 = blocks of found mem
					;	a0 = first usable address
					;	a1 = last usable address

	move.l	a1,d7
	and.l	#$fffffffc,d7		; just strip so we always work in longword area (just to be sure)
	move.l	d7,a1

	move.l	a3,d7			; Store jumpaddress in D7
	lea	$0,a0			; clear a0
.Detect:
	lea	MEMCheckPattern,a3
	move.l	(a1),d3			; Take a backup of content in memory to D3

.loop:
	cmp.l	a1,a2			; check if we tested all memory
	blo	.wearedone		; we have, we are done!

	move.l	(a3)+,d2		; Store value to test for in D2	

	move.l	d2,(a1)			; Store testvalue to a1
	nop
	nop
	nop
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
	move.l	(a1),d4			; read value from a1 to d4
					; Reading several times.  as sometimes reading once will give the correct answer on bad areas.
					

	btst	#6,$bfe001		; Check if LMB is pressed
	beq	.wearedone


	cmp.l	d4,d2			; Compare values
	bne	.failed			; ok failed, no working ram here.
	cmp.l	#0,d2			; was value 0? ok end of list
	bne	.loop			; if not, lets do this test again
					; we had 0, we have working RAM

	move.l	a1,a5			; OK lets see if this is actual CORRECT ram and now just a shadow.

	move.l	a5,(a1)			; So we store the address we found in that location.
	move.l	#32,d6			; ok we do test 31 bits
	move.l	a5,d5

.loopa:
	sub.l	#1,d6
	cmp.l	#0,d6
	beq	.done			; we went all to bit 0.. we are done I guess
	btst	d6,d5			; scan until it isnt a 0
	beq.s	.loopa
.bitloop:

	bclr	d6,d5			; ok. we are at that address, lets clear first bit of that address
	move.l	d5,a3


	cmp.l	(a3),a5			; ok check if that address contains the address we detected, if so. we have a "shadow"
	beq	.shadow

	cmp.l	#0,a3			; it was 0, so we "assume" we got memory
	beq	.mem

					; ok we didnt have a shadow here
					; a5 will contain address if there was detected ram
	sub.l	#1,d6

	cmp.l	#4,d6
	beq	.mem			; ok we was at 4 bits away..  we can be PRETTY sure we do not have a shadow here.  we found mem

	bra	.bitloop

.mem:
	move.l	d3,(a1)			; restore backup of data

	cmp.l	(a1),d0			; check if value at a1 is the same as d0. this means we have a shadow on top and we have already tested
	beq	.shadowdone			; this memory.  basically: we are done


	cmp.l	#0,a0			; check if a0 was 0, if so, this is the first working address
	bne	.wehadmem
	move.l	a5,a0			; so a5 contained the address we found, copy it to a0
	move.l	d7,16(a1)		; ok store d7 into what a1 points to.. to say that this is a block of mem)

.wehadmem:

	add.l	#4,d1			; OK we found mem, lets add 4 do d1(as old routine was 64K blocks  now 256.  being lazy)
	bra	.next

.wearedone:
	bra	.done

.shadow:
	TOGGLEPWRLED			; Flash with powerled doing this.. 
.failed:
	move.l	d3,(a1)			; restore backup of data
	cmp.l	#0,a0			; ok was a0 0? if so, we havent found memory that works yet, lets loop until all area is tested
	bne	.done

.next:
	btst	#6,$bfe001		; Check if LMB is pressed
	beq	.wearedone


	move.l	d0,(a1)			; put a note at the first found address. to mark this as already tagged
	move.l	a0,4(a1)		; put a note of first block found
	move.l	a1,8(a1)		; where this block was
	move.l	d1,12(a1)		; total amount of 64k blocks found
					; Strangly enough. this seems to also write onscreen at diagrom?

;	add.l	#64*1024,a1		; Add 64k for next block to test
	add.l	#256*1024,a1		; Add 64k for next block to test
	bra	.Detect
.shadowdone:
	TOGGLEPWRLED			; Flash with powerled doing this.. 
.done:

	; resources
	MemCheckPatternResource

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

	PUTCHAR #$d,d7, #1000	
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

	; resources
	MemCheckPatternResource

ENDM

POSTDetectFastmem: MACRO
					
	; Lets detect fastmem, do NOT touch D0, A6 or A4
	; As we have several blocks to search. we do it in a subroutine instead of in-code as we did with chipmem
					
	move.l	d3,a7			; Store start of chipmem

	clr.l	d1
	lea	$0,a0
	lea	$0,a0
	lea	$0,a3
	lea	$0,a6

	; as d0 is used as a "random" number in memcheck.  but d0 is also detected chipmem.
	; lets eor this to make it more... "random"
	; this detection is quite.. "poor" as it will stop when finding one block of ram. so fragmented memory only first block
	; will be found

	clr.l	d2			; We set d2 to 0.  if it is anything else than 0 after 24bit tests, we have32bit cpu

	cmp.l	#" PPC",$f00090		; Check if the string "PPC" is located in rom at this address. if so we have a BPPC

	; that will disable the 68k cpu onboard if memory  below $40000000 is tested.
	beq	\@bppc

	move.l	#"NONE",$700
	move.l	#"24BT",$40000700	; Write "24BT" to highmem
	cmp.l	#"24BT",$700		; IF memory is readable at $700 instead. we are using a cpu with 24 bit adress. no memory to detect in next routines
	beq	.nop5
	move.l	#1,d2			; blizzards etc will set this to 1..  apollo etc will not

.nop5

	move.l	#"NONE",$700
	move.l	#"24BT",$2000700	; Write "24BT" to highmem
	cmp.l	#"24BT",$700		; IF memory is readable at $700 instead. we are using a cpu with 24 bit adress. no memory to detect in next routines
	beq	.no24
	move.l	#1,d2			; other cards will trigger here
	
.no24
	move.l	#"NONE",$700
	move.l	#"24BT",$4000700	; Write "24BT" to highmem
	cmp.l	#"24BT",$700		; IF memory is readable at $700 instead. we are using a cpu with 24 bit adress. no memory to detect in next routines
	beq	.no24a
	move.l	#1,d2			; blizzards etc will set this to 1..  apollo etc will not

.no24a:
	cmp.l	#0,d2			; if d2 is 0, we have 24 bit addressing
	beq	\@a1200done

	eor.l	#$01110000,d0
	move.w	#$003,color0

	lea	$1000000,a1		; Detect motherboardmem on A3000/4000
	lea	$7ffffff,a2

	DetectMemory

.a3k4kdone:				; Again, the wonders without stack.  pasta-code.. :)
	
	move.l	a0,d5		; Backup startaddress of memory found
	move.l	a1,d4		; Backup endaddress of memory found
	move.l	d1,d3		; Backup data of addresses found to registers not used

	cmp.l	#0,a0		; was a0 0?  if so. no memory was found
	beq	.det16

	KPRINT FastFoundtxt
	KPRINTHEX32 d5
	KPRINTS ' - $'
	KPRINTHEX32 d4
	KNEWLINE
	
	move.l	d5,a3			;Start of mem
	move.l	d4,a6			;end of mem
	move.l	d3,d1

.det16:

	eor.l	#$01110000,d0
	move.w	#$006,color0

	lea	$8000000,a1		; Detect cpuboard on A3000/4000
	lea	$10000000,a2

	eor.l	#$01010000,d0

	DetectMemory
	
.a3k4kcpudone:

	cmp.l	#0,a0			; if a0 is 0, we did not find memory
	bne	.det20			; it wasnt, we did have memory
					; ok we did not have memory, copy data from last detect
	move.l	a3,a0
	move.l	a6,a1
	bra	.det26

.det20:
	move.l	a0,d5			; Backup startaddress of memory found
	move.l	a1,d4			; Backup endaddress of memory found
	move.l	d1,d3			; Backup data of addresses found to registers not used

	KPRINT FastFoundtxt
	KPRINTHEX32 d5
	KPRINTS ' - $'
	KPRINTHEX32 d4
	KNEWLINE

	move.l	d5,a3			;Start of mem
	move.l	d4,a6			;end of mem
	move.l	d3,d1
.det26:

	eor.l	#$01010000,d0

\@bppc:	
	move.w	#$009,color0

	lea	$40000000,a1
	lea	$f0000000,a2
	
	eor.l	#$11010000,d0

	DetectMemory

.det1200cpu:
	cmp.l	#0,a0			; if a0 is 0, we did not find memory
	bne	.det30			; it wasnt, we did have memory
					; ok we did not have memory, copy data from last detect
	move.l	a3,a0
	move.l	a6,a1
	bra	.det36

.det30:
	move.l	a0,d5			; Backup startaddress of memory found
	move.l	a1,d4			; Backup endaddress of memory found
	move.l	d1,d3			; Backup data of addresses found to registers not used

	KPRINT FastFoundtxt
	KPRINTHEX32 d5 
	KPRINTS " - $"
	KPRINTHEX32 d4
	KNEWLINE

	move.l	d5,a3			;Start of mem
	move.l	d4,a6			;end of mem
	move.l	d3,d1
.det36:

	eor.l	#$11010000,d0
\@a1200done:

	move.w	#$00c,color0

	lea	$200000,a1		; Detect memory on 24 bit range
	lea	$9fffff,a2
	
	eor.l	#$10010000,d0

	DetectMemory
.24bitdone:
	cmp.l	#0,a0	; if a0 is 0, we did not find memory
	bne	.det40		; it wasnt, we did have memory
					; ok we did not have memory, copy data from last detect
	move.l	a3,a0
	move.l	a6,a1
	bra	.det46

.det40:
	move.l	a0,d5			; Backup startaddress of memory found
	move.l	a1,d4			; Backup endaddress of memory found
	move.l	d1,d3			; Backup data of addresses found to registers not used
	
	KPRINT FastFoundtxt
	KPRINTHEX32 d5
	KPRINTS " - $"
	KPRINTHEX32	d4	
	KNEWLINE
	
	move.l	d5,a3			;Start of mem
	move.l	d4,a6			;end of mem
	move.l	d3,d1
.det46:

	eor.l	#$10010000,d0
	move.w	#$00f,color0

	lea	$c00000,a1		; Detect memory on 24 bit range
	lea	$c80000,a2

	eor.l	#$10110000,d0

	DetectMemory

.fakefastdone:

	; make screen light grey
	move.w	#$aaa,color0 

	cmp.l	#0,a0		; if a0 is 0, we did not find memory
	bne	.det50			; it wasnt, we did have memory
						; ok we did not have memory, copy data from last detect
	move.l	a3,a0
	move.l	a6,a1
	move.l	d1,d3
	bra	.det55

.det50:
	move.l	a0,d5		; Backup startaddress of memory found
	move.l	a1,d4		; Backup endaddress of memory found
	move.l	d1,d3		; Backup data of addresses found to registers not used

	KPRINTS '  - Fastmem found between: $'
	
	KPRINTHEX32 d5
	KPRINTS " - $"
	KPRINTHEX32 d4
	KNEWLINE

.det55:
	move.l	d3,d1
.det56:

	eor.l	#$10110000,d0
	move.l	d1,d3

	cmp.l	#0,d1			; check if we had any fastmem
	bne	.fast			; if it wasnt 0 , we had fastmem

	KPRINTLN NoFastFoundtxt

.fast:
	move.l	d3,d1
	move.l	d1,d3			; Store size in d3 as Dumpserial uses d1

	PAROUT	#$fb			; Send $fd to parallelport
	KPRINTSLN '- Parallel Code $fb - Memorydetection done'

	move.l	d3,d1
	move.l	d4,a1			; Restore important data from fastmemdetection
	move.l	d5,a0

	FastFoundResource
	NoFastFoundResource

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
