;
; Copyright (C) 2025 Rhys Weatherley
;
; Permission is hereby granted, free of charge, to any person obtaining a
; copy of this software and associated documentation files (the "Software"),
; to deal in the Software without restriction, including without limitation
; the rights to use, copy, modify, merge, publish, distribute, sublicense,
; and/or sell copies of the Software, and to permit persons to whom the
; Software is furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included
; in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
; OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
; DEALINGS IN THE SOFTWARE.
;

        .org $8000

;
; Variables in the zero page.
;
MSG_INDEX .equ $20
BUFFER    .equ $30

;
; Main entry to the ROM on reset.
;
reset:
        cld                 ; Disable BCD mode.
        sei                 ; Disable interrupts.
        ldx     #$FF        ; Set up the stack.
        txs
;
; Wait for the voltage rails on the daughter chips to settle at reset time.
;
        lda     #0
        tay
reset_delay:
        adc     #1
        bne     reset_delay
        dey
        bne     reset_delay
;
; Clear the front panel display.
;
        jsr     FP_CLEAR
;
; Scroll the message on the display until a key is pressed.
;
        lda     #0
        sta     MSG_INDEX
loop:
        jsr     FP_GET_KEY
        cmp     #FP_KEY_NONE
        bne     read_keys
;
        lda     #<message
        clc
        adc     MSG_INDEX
        tay
        lda     #>message
        adc     #0
        ldx     #FP_DISP_1
        jsr     FP_DRAW_STRING
;
        lda     #0
        tay
digit_delay:
        adc     #1
        bne     digit_delay
        dey
        bne     digit_delay
;
        inc     MSG_INDEX
        lda     MSG_INDEX
        cmp     #(message_end - message - 5)
        bcc     loop
        lda     #0
        sta     MSG_INDEX
        jmp     loop

;
; Clear the display and print keys as they are pressed on the keypad.
;
read_keys:
        jsr     FP_CLEAR
        lda     #$20
        sta     BUFFER
        sta     BUFFER+1
        sta     BUFFER+2
        sta     BUFFER+3
        sta     BUFFER+4
        sta     BUFFER+5
        lda     #0
        sta     BUFFER+6
;
next_key:
        lda     BUFFER+1        ; Scroll the buffer contents left.
        sta     BUFFER
        lda     BUFFER+2
        sta     BUFFER+1
        lda     BUFFER+3
        sta     BUFFER+2
        lda     BUFFER+4
        sta     BUFFER+3
        lda     BUFFER+5
        sta     BUFFER+4
        jsr     FP_WAIT_KEY     ; Wait for a key to be pressed.
        sta     BUFFER+5        ; Add the new character on the right.
        ldy     #<BUFFER
        lda     #>BUFFER
        ldx     #FP_DISP_1
        jsr     FP_DRAW_STRING  ; Redraw the buffer's contents.
;
        jmp     next_key

;
; Message to display.  See "https://github.com/Nakazoto/Hellorld/wiki" for why.
;
message:
        .db     "      HELLORLD      "
;
; Follow the main message with the printable ASCII characters.
;
        .db     "!",$22,"#$%&'()*+,-./0123456789:;<=>?"
        .db     "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[",$5C,"]^_"
        .db     "`abcdefghijklmnopqrstuvwxyz{|}~",$7F
        .db     "      "
message_end:
        .db     0

;
; Include the front panel driver code.
;
        .include "fp_driver.s"

;
; NMI handler - not used.
;
nmi_handler:
        rti

;
; IRQ handler - not used.
;
irq_handler:
        rti

        .org    $FFFA
        .dw     nmi_handler
        .dw     reset
        .dw     irq_handler
