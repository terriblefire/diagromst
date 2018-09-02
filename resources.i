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

