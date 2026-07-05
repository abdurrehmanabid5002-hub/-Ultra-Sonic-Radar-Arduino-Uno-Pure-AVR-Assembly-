; Arduino Uno LED + Servo Radar Sweep (AVR asm)
; MCU: ATmega328P @ 16 MHz
; LED: PB5 (Pin 13)
; Servo signal: PD6 (Arduino D6)
; Ultrasonic: TRIG=PD7 (D7), ECHO=PD2 (D2)
; UART0 TX: Arduino D1 (TX0) at 9600 baud for logging

.equ DDRB,   0x04
.equ PORTB,  0x05
.equ DDRD,   0x0A
.equ PORTD,  0x0B
.equ PIND,   0x09
.equ SPH,    0x3E
.equ SPL,    0x3D

; USART0 registers (data space addresses; use lds/sts)
.equ UCSR0A, 0x00C0
.equ UCSR0B, 0x00C1
.equ UCSR0C, 0x00C2
.equ UBRR0L, 0x00C4
.equ UBRR0H, 0x00C5
.equ UDR0,   0x00C6

; Close threshold (16-bit) for echo count ~ about 1.5 ft
; Adjust after observing UART logs if needed
.equ CLOSE_THR_L, 0x00
.equ CLOSE_THR_H, 0x04   ; 0x0400 ~ 1024 counts (tune in tests)

.section .text
.org 0x0000

; Reset vector
    rjmp START

START:
    ; Initialize stack pointer
    ldi r16, 0x08
    out SPH, r16
    ldi r16, 0xFF
    out SPL, r16

    ; Set PB5 (LED) and PD6 (servo) as outputs
    sbi DDRB, 5
    sbi DDRD, 6
    ; Ultrasonic TRIG as output (PD7), ECHO as input (PD2)
    sbi DDRD, 7
    cbi DDRD, 2
    
    ; Turn LED OFF initially
    cbi PORTB, 5
    ; Servo line low initially
    cbi PORTD, 6
    ; TRIG low, ECHO no pull-up
    cbi PORTD, 7
    cbi PORTD, 2

    ; UART init @ 9600 8N1 (UBRR=103)
    ldi r16, 0
    sts UCSR0A, r16          ; U2X0=0
    sts UBRR0H, r16
    ldi r16, 103
    sts UBRR0L, r16
    ldi r16, 0x08            ; TXEN0
    sts UCSR0B, r16
    ldi r16, 0x06            ; UCSZ01|UCSZ00 = 8-bit
    sts UCSR0C, r16

    ; rate limit for UART prints (every ~10 frames)
    ldi r28, 10

    ; Init LED blink state
    ldi r27, 0       ; LED state flag (0=off, 1=on)
    ldi r25, 50      ; frames per LED toggle (~1s)

RADAR_LOOP:
    ; Sample distance; if close, hold center until far
    rcall ULTRA_SAMPLE
    tst r26
    breq RADAR_SEQ
CLOSE_HOLD:
    ; Hold center while close
    rcall SERVO_PULSE_1_5MS
    rcall BLINK_UPDATE
    rcall ULTRA_SAMPLE
    tst r26
    brne CLOSE_HOLD
    rjmp RADAR_SEQ

RADAR_SEQ:
    ; 90° (center ~1.5ms)
    rcall SERVO_CENTER_REPEAT
    ; 180° (right ~2.0ms)
    rcall SERVO_RIGHT_REPEAT
    ; 0° (left ~1.0ms)
    rcall SERVO_LEFT_REPEAT
    rjmp RADAR_LOOP

; ===== Servo helpers (fixed positions) =====
; Pulse PD6 high for given width, then low for remainder of 20ms frame
; Widths: 1.0ms, 1.5ms, 2.0ms

SERVO_PULSE_1MS:
    sbi PORTD, 6
    rcall DELAY_1MS
    cbi PORTD, 6
    rcall DELAY_MS_19
    ret

SERVO_PULSE_1_5MS:
    sbi PORTD, 6
    rcall DELAY_1MS
    rcall DELAY_0_5MS
    cbi PORTD, 6
    rcall DELAY_MS_18_5
    ret

SERVO_PULSE_2MS:
    sbi PORTD, 6
    rcall DELAY_1MS
    rcall DELAY_1MS
    cbi PORTD, 6
    rcall DELAY_MS_18
    ret

; LED blink update: toggle every ~50 frames
BLINK_UPDATE:
    ; Repurpose as proximity indicator + sampler + logger
    ; Sample distance each frame
    rcall ULTRA_SAMPLE
    ; LED ON if close (r26==1), else OFF
    tst r26
    breq BU_LED_OFF
    sbi PORTB, 5
    rjmp BU_LOG_RATE
BU_LED_OFF:
    cbi PORTB, 5
BU_LOG_RATE:
    ; log every ~10 frames to reduce overhead
    dec r28
    brne BU_DONE
    ldi r28, 10
    ; print 16-bit echo count in hex (r31:r30) and newline
    mov r24, r31
    rcall UART_PRINT_HEX_BYTE
    mov r24, r30
    rcall UART_PRINT_HEX_BYTE
    ldi r24, 13
    rcall UART_TX
    ldi r24, 10
    rcall UART_TX
BU_DONE:
    ret

; Repeat pulses to allow servo to reach target (about ~1s per position)
SERVO_CENTER_REPEAT:
    ldi r17, 50
SC_LOOP:
    rcall SERVO_PULSE_1_5MS
    rcall BLINK_UPDATE
    tst r26
    breq SC_CONT
    rjmp CLOSE_HOLD
SC_CONT:
    dec r17
    brne SC_LOOP
    ret

SERVO_RIGHT_REPEAT:
    ldi r17, 50
SR_LOOP:
    rcall SERVO_PULSE_2MS
    rcall BLINK_UPDATE
    tst r26
    breq SR_CONT
    rjmp CLOSE_HOLD
SR_CONT:
    dec r17
    brne SR_LOOP
    ret

SERVO_LEFT_REPEAT:
    ldi r17, 50
SL_LOOP:
    rcall SERVO_PULSE_1MS
    rcall BLINK_UPDATE
    tst r26
    breq SL_CONT
    rjmp CLOSE_HOLD
SL_CONT:
    dec r17
    brne SL_LOOP
    ret

; ===== Delay routines (approximate at 16 MHz) =====
; ~10 us
DELAY_10US:
    ldi r20, 40
D10US_LOOP:
    dec r20
    brne D10US_LOOP
    ret
; ~1.0 ms
DELAY_1MS:
    ldi r21, 53      ; middle count
D1MS_M:
    ldi r20, 100     ; inner count
D1MS_I:
    dec r20
    brne D1MS_I
    dec r21
    brne D1MS_M
    ret

; ~0.1 ms
DELAY_0_1MS:
    ldi r21, 5
D0_1MS_M:
    ldi r20, 100
D0_1MS_I:
    dec r20
    brne D0_1MS_I
    dec r21
    brne D0_1MS_M
    ret

; ~0.5 ms
DELAY_0_5MS:
    ldi r21, 26
D0_5MS_M:
    ldi r20, 100
D0_5MS_I:
    dec r20
    brne D0_5MS_I
    dec r21
    brne D0_5MS_M
    ret

; Delay N milliseconds by calling DELAY_1MS in a loop
; r22 holds ms count
DELAY_MS_GENERIC:
DMS_G_LOOP:
    rcall DELAY_1MS
    dec r22
    brne DMS_G_LOOP
    ret

; 19 ms
DELAY_MS_19:
    ldi r22, 19
    rcall DELAY_MS_GENERIC
    ret

; 18.5 ms (18 ms + 0.5 ms)
DELAY_MS_18_5:
    ldi r22, 18
    rcall DELAY_MS_GENERIC
    rcall DELAY_0_5MS
    ret

; 18 ms
DELAY_MS_18:
    ldi r22, 18
    rcall DELAY_MS_GENERIC
    ret

; ===== Ultrasonic routines =====
; ULTRA_SAMPLE:
; - Sends 10us TRIG pulse on PD7
; - Waits for ECHO high on PD2 with timeout
; - Measures ECHO high duration with a simple loop
; - Sets r26 = 1 if "close" (short echo), else r26 = 0
ULTRA_SAMPLE:
    ldi r26, 0          ; assume far
    ; Trigger 10us pulse
    sbi PORTD, 7
    rcall DELAY_10US
    cbi PORTD, 7

    ; Wait for ECHO to go high (timeout simple)
    ldi r18, 255
US_WAIT_HIGH:
    in r16, PIND
    sbrs r16, 2         ; if ECHO high, skip next
    rjmp US_WH_CONT
    rjmp US_MEASURE_START
US_WH_CONT:
    dec r18
    brne US_WAIT_HIGH
    ; timeout -> far, r31:r30 = 0
    clr r31
    clr r30
    ret

US_MEASURE_START:
    clr r31             ; high byte
    clr r30             ; low byte
US_MEASURE_LOOP:
    in  r16, PIND
    sbrs r16, 2         ; if ECHO still high, skip next
    rjmp US_MEASURE_DONE
    inc r30             ; 16-bit increment r31:r30
    brne US_MEASURE_LOOP
    inc r31
    rjmp US_MEASURE_LOOP

US_MEASURE_DONE:
    ; Compare r31:r30 with CLOSE_THR_H:L
    ldi r20, CLOSE_THR_L
    ldi r21, CLOSE_THR_H
    cp  r30, r20        ; compare low bytes
    cpc r31, r21        ; compare high with carry
    brlo US_IS_CLOSE    ; if count < threshold => close
    ret                 ; else far
US_IS_CLOSE:
    ldi r26, 1
    ret

; ===== UART routines =====
; UART_TX: send r24
UART_TX:
UART_TX_WAIT:
    lds r16, UCSR0A
    sbrs r16, 5         ; UDRE0 bit
    rjmp UART_TX_WAIT
    sts UDR0, r24
    ret

; Print one hex nibble from r24 (low 4 bits)
UART_PRINT_HEX_NIBBLE:
    andi r24, 0x0F
    cpi  r24, 10
    brlo UHX_DIG
    subi r24, 10
    ldi  r16, 'A'
    add  r24, r16
    rjmp UHX_OUT
UHX_DIG:
    ldi  r16, '0'
    add  r24, r16
UHX_OUT:
    rcall UART_TX
    ret

; Print r24 as two hex chars
UART_PRINT_HEX_BYTE:
    mov r16, r24
    swap r24
    rcall UART_PRINT_HEX_NIBBLE
    mov r24, r16
    rcall UART_PRINT_HEX_NIBBLE
    ret