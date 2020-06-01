	;; w00t a new operating system.
        ;; Based on DiagROM

; A6 is ONLY to be used as a memorypointer to variables etc. so never SET a6 in the code.


  ifnd STE_ROM 
STE_ROM  EQU 0
  endc

  ifnd ST_ROM 
ST_ROM  EQU 0
  endc

  ifnd FALCON_ROM 
FALCON_ROM  EQU 0
  endc

  ifnd ST_CART 
ST_CART  EQU 0
  endc


autovec_hbl 		EQU	$000068
autovec_vbl		EQU 	$000070 
slowcia			EQU	$FFFC06
slowcia_alt		EQU	$FFFC06
parddr          EQU     $FFFA05
parport         EQU     $FFFA01

v_base    equ $FFFF8200
v_bas_h   equ $FFFF8201
v_bas_m   equ $FFFF8203
v_bas_l   equ $FFFF820D
v_adr_h   equ $FFFF8205
v_adr_m   equ $FFFF8207
v_adr_l   equ $FFFF8209
v_mode 	  equ $FFFF8260
v_spshift equ $FFFF8266

v_sync	  equ $FFFF820a

ACIA_IKBD_BASE equ $fffffc00
ACIA_MIDI_BASE equ $fffffc04

acia_midi_ctrl EQU ACIA_MIDI_BASE
acia_midi_data EQU ACIA_MIDI_BASE+2

	rsreset
ACIA_CTRL rs.w	1
ACIA_DATA rs.w	1
	

palette			EQU     $FFFF8240
color0          EQU     $FFFF8240
color1          EQU     $FF8242
color2          EQU     $FF8244
color3          EQU     $FF8246
color4          EQU     $FF8248
color5          EQU     $FF824A
color6          EQU     $FF824C
color7          EQU     $FF824E
color8          EQU     $FF8250
color9          EQU     $FF8252
color10         EQU     $FF8254
color11         EQU     $FF8256
color12         EQU     $FF8258
color13         EQU     $FF825A
color14         EQU     $FF825C
color15         EQU     $FF825E


FPCR    	EQU     $1000
FPSR    	EQU     $0800
FPIAR   	EQU     $0400

memconf     EQU		$FFFF8001


mfp_base        EQU     $FFFA01
mfp_gpip        EQU     $FFFFFA01 
mfp_aer         EQU     $FFFA03
mfp_dd          EQU     $FFFA05

mfp_iera        EQU     $FFFA07
mfp_ierb        EQU     $FFFA09
mfp_ipra        EQU     $FFFA0B
mfp_iprb        EQU     $FFFA0D
mfp_isra        EQU     $FFFA0F
mfp_isrb        EQU     $FFFA11
mfp_imra        EQU     $FFFA13
mfp_imrb        EQU     $FFFA15
mfp_vr          EQU     $FFFA17

mfp_tacr        EQU     $FFFA19
mfp_tbcr        EQU     $FFFA1B
mfp_tcdcr       EQU     $FFFA1D
mfp_tadr        EQU     $FFFA1F
mfp_tbdr        EQU     $FFFA21
mfp_tcdr        EQU     $FFFA23
mfp_tddr        EQU     $FFFA25
mfp_scr        EQU      $FFFA27
mfp_ucr        EQU      $FFFA29
mfp_rsr         EQU     $FFFA2B
mfp_tsr         EQU     $FFFA2D
mfp_udr        EQU     $FFFA2F

  ifne ST_CART
rom_base equ $FA0000
rom_size equ $20000
rom_setup equ 1
  endc 

  ifnd rom_setup
    ifne STE_ROM
rom_base equ $E00000
rom_size equ $40000
rom_setup equ 1
    endc
  endc

  ifnd rom_setup
    ifne FALCON_ROM
rom_base equ $E00000
rom_size equ $80000
rom_setup equ 1
    endc
  endc

  ifnd rom_setup
rom_base equ $fc0000
rom_size equ $30000
rom_setup equ 1
  endc	

	
LOWRESSize:	equ	40*256
HIRESSize:	equ	80*512


GETMASK: MACRO
	moveq.l    #0,d3                     ; to prevent false effective address generation
        adda.w    d0,a3                     ; have got pointer to mfp register now
        move.b    (a3),d3                   ; now have the address offset to mfp
        add.l     a0,d3
        movea.l   d3,a3                     ; now have address pointing to desired mfp reg.
        ;* now we get the mask to turn off interrupt
        adda.w    d0,a2                     ; have got pointer to mask now
	ENDM
	
MSKREG:	MACRO
	move.l	a2,d4
	move.l	a3,d5
	GETMASK
        move.b    (a2),d3                   ; grab mask now
        and.b     d3,(a3)                   ; and have masked off the desired bit(s)
        ENDM
