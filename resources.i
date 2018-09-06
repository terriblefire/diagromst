VER:	MACRO
	dc.b "0"			; Versionnumber
	ENDM
REV:	MACRO
	dc.b "9"			; Revisionmumber
	ENDM

VERSION:	MACRO
	dc.b	"V"			; Generates versionstring.
	VER
	dc.b	"."
	REV
	ENDM

BusErrorTxt: MACRO
		dc.b "Bus Error Detected"
		ENDM
AddressErrorTxt:MACRO
	    dc.b "Address Error Detected"
		ENDM
IllegalErrorTxt: MACRO
	    dc.b "Illegal Instruction Detected"
		ENDM
DivByZeroTxt:	MACRO
	    dc.b "Division by Zero Detected"
		ENDM
ChkInstTxt:	MACRO
	    dc.b "Chk Inst Detected"
		ENDM
TrapVTxt: MACRO
	    dc.b "TRAP V Detected"
		ENDM
PrivViolTxt: MACRO
	    dc.b "Privilige Violation Detected"
		ENDM
TraceTxt: MACRO
	    dc.b "Trace Detected"
		ENDM
UnimplInstTxt: MACRO
	    dc.b "Unimplemented instruction Detected"
		ENDM
TrapTxt: MACRO
	    dc.b "TRAP Detected"
		ENDM

TxtResource: MACRO

	ifnd \1txt
	bra	  \@skip
\1txt:
	dc.b \2,0
	EVEN
\@skip:
	endc

ENDM

FastFoundResource: MACRO
	TxtResource FastFound, '  - Fastmem found between: $'
ENDM

NoFastFoundResource: MACRO
	TxtResource NoFastFound, '  - No fastmem found, Autoconfig ram NOT checked'
ENDM

MFPTableResource: MACRO

	;; inline resource is only defined if its not been defined before
	ifnd iert
	bra	  \@skip

iert:       DC.B      $06,$06,$08,$08
iprt:       DC.B      $0a,$0a,$0c,$0c
isrt:       DC.B      $0e,$0e,$10,$10
imrt:       DC.B      $12,$12,$14,$14
imrmt:      DC.B      $df,$fe,$df,$ef
tcrtab:     DC.B      $18,$1a,$1c,$1c
tcrmsk:     DC.B      $00,$00,$8f,$f8
tdrtab:     DC.B      $1e,$20,$22,$24
	EVEN

\@skip:

	endc

ENDM

ByteHexTableResource: MACRO

	;; inline resource is only defined if its not been defined before
	ifnd ByteHexTable

	bra  \@skip

ByteHexTable:
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
	
	EVEN

\@skip:
	endc

ENDM

MemCheckPatternResource: MACRO

	;; inline resource is only defined if its not been defined before
	ifnd MEMCheckPattern

	bra  \@skip

MEMCheckPattern:
	dc.l	$aaaaaaaa,$55555555,$f0f0f0f0,$0f0f0f0f,$ffffffff,0,0
MEMCheckPatternFast:
	dc.l	$aaaaaaaa,$55555555,$f0f0f0f0,$0f0f0f0f,0,0
	EVEN

\@skip:
	endc

ENDM	