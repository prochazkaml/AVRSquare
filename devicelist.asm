; -------------------------------------------------------------------
; DEVICE DEFINITIONS
; -------------------------------------------------------------------

.ifdef USES_ATMEGA328P
	.include "devices/m328Pdef.inc"
	.define TIMER_STYLE_328
.endif

.ifdef USES_ATMEGA644
	.include "devices/m644def.inc"
	.define TIMER_STYLE_328
.endif

; -------------------------------------------------------------------
; TIMER SETUP MACRO
; -------------------------------------------------------------------

.macro CPU_SETUP_TIMER
	.ifdef TIMER_STYLE_328
		ldi TMP, (1 << 1)		; Overflow mode (TCCR0A)
								; Enable interrupt (TIMSK0)
		out TCCR0A, TMP
		sts TIMSK0, TMP
		
		ldi TMP, 243			; 16000000 / (243 + 1) = ~131148 Hz
								; (close enough to 131072 Hz)
		out OCR0A, TMP
		
		ldi TMP, (1 << 0)		; Start the timer (without prescaler)
		out TCCR0B, TMP
		
		.equ TimerOverflowVect = OVF0addr
	.endif
.endm

; -------------------------------------------------------------------
; COMMON DEFINITIONS
; -------------------------------------------------------------------

.equ ResetVect = 0x00
