; ===================================================================
; Simple AVR square wave player
; Tested with: ATmega328P, ATmega644A
; Probably compatible with: ATmega88/168/328(-/P/PB), ATmega164/324/644/1284(-/P/A/PA)
; Plays 8 square waves, each through a pin in the selected port.
; Mixing is done using resistors.
; ===================================================================

; -------------------------------------------------------------------
; CPU SELECTION
; For the list all off the possible CPUs see "devicelist.asm"
; -------------------------------------------------------------------

	.define USES_ATMEGA328P
	.include "devicelist.asm"

; -------------------------------------------------------------------
; REGISTER DEFINITIONS
; -------------------------------------------------------------------

	; Selected port
	.equ IO_PORT = PORTD
	.equ IO_DDR = DDRD

	; Channel counter registers
	.def CHANNEL_0_CTR = r0
	.def CHANNEL_1_CTR = r2
	.def CHANNEL_2_CTR = r4
	.def CHANNEL_3_CTR = r6
	.def CHANNEL_4_CTR = r8
	.def CHANNEL_5_CTR = r10
	.def CHANNEL_6_CTR = r12
	.def CHANNEL_7_CTR = r14
	.def CHANNEL_0_CTR_L = r0
	.def CHANNEL_1_CTR_L = r2
	.def CHANNEL_2_CTR_L = r4
	.def CHANNEL_3_CTR_L = r6
	.def CHANNEL_4_CTR_L = r8
	.def CHANNEL_5_CTR_L = r10
	.def CHANNEL_6_CTR_L = r12
	.def CHANNEL_7_CTR_L = r14
	.def CHANNEL_0_CTR_H = r1
	.def CHANNEL_1_CTR_H = r3
	.def CHANNEL_2_CTR_H = r5
	.def CHANNEL_3_CTR_H = r7
	.def CHANNEL_4_CTR_H = r9
	.def CHANNEL_5_CTR_H = r11
	.def CHANNEL_6_CTR_H = r13
	.def CHANNEL_7_CTR_H = r15

	; Temporary register
	.def TMP = r16
	.def TMP_L = r16
	.def TMP_H = r17
	
	; Channel parsing register
	.def BITMAP = r20
	
	; Sum register
	.def SUM = r18

	; Current position in the tune
;	.def CURR_NUM_OF_ROWS = r26
;	.def CURR_NUM_OF_ROWS_L = r26
;	.def CURR_NUM_OF_ROWS_H = r27
	
	; Current wait value
	.def CURR_WAIT_PRESCALER = r26
	.def CURR_WAIT_PRESCALER_L = r26
	.def CURR_WAIT_PRESCALER_H = r27
	.def CURR_WAIT = r24
	.def CURR_WAIT_L = r24
	.def CURR_WAIT_H = r25

; -------------------------------------------------------------------
; MACROS
; -------------------------------------------------------------------

; update_channel: Updates a channel. (duh)
; Arguments: register: low channel register (eg. CHANNEL_0_CTR_L)
;            register: high channel register (eg. CHANNEL_0_CTR_H)
;            constant: channel number
; Required setup: Y pointer (0x100)
; Destroys: r16:r17 (TMP)

.macro update_channel
	ldd TMP_L, Y+(@2 * 2)	; Load the data
	ldd TMP_H, Y+(@2 * 2 + 1)
	
	add @0, TMP_L		; Add the loaded data to the counter
	adc @1, TMP_H
	
	brcc no_overflow_@2	; Has the counter overflowed?
	ldi TMP, (1 << @2)	; If it has, toggle channel's pin
	eor SUM, TMP

no_overflow_@2:

.endm

; parse_channel: Parses a channel. (wow, such creative names, I know)
; Arguments: constant: channel number
; Required setup: Y pointer (0x100), BITMAP
; Destroys: r16:r17 (TMP)

.macro parse_channel
	sbrs BITMAP, @0		; Is the channel supposed to update?
	rjmp no_parse_@0	; If not, then skip
	
	lpm TMP_L, Z+		; Load the data
	lpm TMP_H, Z+
	
	std Y+(@0 * 2), TMP_L
	std Y+(@0 * 2 + 1), TMP_H
	
no_parse_@0:
	
.endm

; -------------------------------------------------------------------
; MAIN ROUTINE
; Only 32 words can fit here (before the timer overflow interrupt
; vector), so this section has to be as compact as possible!
; -------------------------------------------------------------------

.org ResetVect

start:
	; Clear the registers
	
	ldi r30, 28		; Loop counter
	clr r31			; Data
	clr YL			; Address 0 - this is where the registers are
	clr YH
	
clear_loop:
	st Y+, r31
	dec r30
	brne clear_loop
	
	; Set up the I/O
	
	ser TMP						; All outputs
	
	out IO_DDR, TMP
	out DDRB, TMP
	
	; Set up the tune

	ldi	ZL, LOW(2 * tune)		; Load the tune address
	ldi	ZH, HIGH(2 * tune)		; into Z
	
	; Load the first row
	
	ldi YH, 1					; SRAM location = 0x100 (this register never changes!)
	clr YL
	call read_row
	
	; Set up the timer (see "devicelist.asm")
	
	cli
	CPU_SETUP_TIMER
	sei
	
halt_loop:
	; TODO: implement the sleep mode (maybe?)
	rjmp halt_loop

; -------------------------------------------------------------------
; TIMER OVERFLOW ROUTINE
; Here is where all of the magic happens.
; -------------------------------------------------------------------

.org TimerOverflowVect

int_routine:
	ldi TMP, 0b00100000			; CPU usage indicator
	out PORTB, TMP
	
	; Update the channel data
	
	update_channel CHANNEL_0_CTR_L, CHANNEL_0_CTR_H, 0
	update_channel CHANNEL_1_CTR_L, CHANNEL_1_CTR_H, 1
	update_channel CHANNEL_2_CTR_L, CHANNEL_2_CTR_H, 2
	update_channel CHANNEL_3_CTR_L, CHANNEL_3_CTR_H, 3
	update_channel CHANNEL_4_CTR_L, CHANNEL_4_CTR_H, 4
	update_channel CHANNEL_5_CTR_L, CHANNEL_5_CTR_H, 5
	update_channel CHANNEL_6_CTR_L, CHANNEL_6_CTR_H, 6
	update_channel CHANNEL_7_CTR_L, CHANNEL_7_CTR_H, 7

	; Output the data
	
	out IO_PORT, SUM
	
	; Update the clock
	
	adiw CURR_WAIT_PRESCALER, 1

	cpi CURR_WAIT_PRESCALER_H, HIGH(TUNE_TIMER_PRESCALER)
	brne no_next
	
	cpi CURR_WAIT_PRESCALER_L, LOW(TUNE_TIMER_PRESCALER)
	brne no_next
	
	clr CURR_WAIT_PRESCALER_L	; Looks like the prescaler has
	clr CURR_WAIT_PRESCALER_H	; reached the maximum value, so
								; reset it
	sbiw CURR_WAIT, 1			; Decrement the wait number

	; Check if we want to go to the next row or to stay
	
	cpi CURR_WAIT_L, 0
	brne no_next
	
	cpi CURR_WAIT_H, 0
	brne no_next
	
	; Looks like we want to go to the next row, 
	; so increment the row number
	
;	adiw CURR_NUM_OF_ROWS, 1
	
	; Check if the song has finished
	
;	cpi CURR_NUM_OF_ROWS_L, LOW(TUNE_NUM_OF_ROWS)
;	brne no_reset
	
;	cpi CURR_NUM_OF_ROWS_H, HIGH(TUNE_NUM_OF_ROWS)
;	brne no_reset
	
;	; It has, so reset the pointer
	
;	ldi	ZL, LOW(2 * tune)		; Load the tune
;	ldi	ZH, HIGH(2 * tune)		; address into Z
	
;	clr CURR_NUM_OF_ROWS_L		; Clear the tune counter
;	clr CURR_NUM_OF_ROWS_H
	
;no_reset:
	; Read the next row
	
	call read_row

no_next:
	; Looks like we want to stay, so don't do anything

	clr TMP						; CPU usage indicator
	out PORTB, TMP
	
	reti

; -------------------------------------------------------------------
; SUBROUTINES
; -------------------------------------------------------------------

; read_row: Reads a row and sets all of the channels accordingly.
; Arguments: none
; Required setup: Z pointer

read_row:
	; Read the delay value
	
	clr CURR_WAIT_H				; Clear the high delay value
	lpm CURR_WAIT_L, Z+			; Get the delay value...
	lpm BITMAP, Z+				; ... and the bit map

	; Detect if we've hit the bottom of the tune

	cpi CURR_WAIT_L, 0xFF
	brne detect_long_delay

	cpi BITMAP, 0xFF
	brne detect_long_delay

	; We have, so reset the pointer and start over

	ldi	ZL, LOW(2 * tune)		; Load the tune
	ldi	ZH, HIGH(2 * tune)		; address into Z

	rjmp read_row

detect_long_delay:
	cpi CURR_WAIT_L, 0			; Are we expecting a long delay?
								; (if 0, then a long
								;  delay follows)
	brne parse
	
	lpm CURR_WAIT_L, Z+			; Load the long delay value
	lpm CURR_WAIT_H, Z+
	
	; Parse the channels
	
parse:
	parse_channel 0
	parse_channel 1
	parse_channel 2
	parse_channel 3
	parse_channel 4
	parse_channel 5
	parse_channel 6
	parse_channel 7
	
	ret
	
; -------------------------------------------------------------------
; PROGRAM ENDS HERE - TUNE DATA STARTS HERE
; -------------------------------------------------------------------

; Tune format:
;		.equ TUNE_NUM_OF_ROWS = num
;		.equ TUNE_TIMER_PRESCALER = num
;		.dw WAIT0, CH0, CH1, CH2, ..., CH7
;		.dw WAIT1, CH0, CH1, CH2, ..., CH7
;			...
;		.dw WAIT(NUM_OF_NOTES - 1), CH0, CH1, CH2, ..., CH7
;
; TODO: This info is no longer accurate!
;
; TUNE_NUM_OF_ROWS = 16 bit value, number of rows
; TUNE_TIMER_PRESCALER = 16 bit value, prescaler - see below
;
; CHx = frequency, 1 unit = ~0.500288166 Hz
;       (safe to assume that 1 unit = 0.5 Hz)
;       32768 maximum (= 16384 Hz)
;       0 = silence
; WAITx = number of 1/65536 second ticks to wait
;         (this number will be multiplied by the prescaler)

	.include "tune.asm"
