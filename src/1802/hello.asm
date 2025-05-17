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

;
; Define the register numbers.
;
R0 equ  0
R1 equ  1
R2 equ  2
R3 equ  3
R4 equ  4
R5 equ  5
R6 equ  6
R7 equ  7
R8 equ  8
R9 equ  9
R10 equ	10
R11 equ	11
R12 equ	12
R13 equ	13
R14 equ	14
R15 equ	15

;
; Origin at the start of ROM - jump over the driver code.
;
        org     $0000
        lbr     init

;
; Message to display.  See "https://github.com/Nakazoto/Hellorld/wiki" for why.
;
message:
        db      "      HELLORLD!      "
;
; Follow the main message with the printable ASCII characters.
;
        db      "!",$22,"#$%&'()*+,-./0123456789:;<=>?"
        db      "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[",$5C,"]^_"
        db      "`abcdefghijklmnopqrstuvwxyz{|}~"
        db      "      "
message_end:
        db      0

;
; Include the driver code and extend the FP_TO_HEX table at the end.
;
        incl    "fp_driver.asm"
        db      "GHI"

;
; Entry point for the program.
;
init:
        ldi     $FF         ; Point the stack pointer to end of RAM at $FFFF.
        phi     R2
        plo     R2
        sex     R2
;
        ldi     HIGH(start) ; Shift to using R4 as the program counter.
        phi     R4
        ldi     LOW(start)
        plo     R4
        sep     R4
;
start:
;
; Clear the front panel display.
;
        ldi     HIGH(FP_CLEAR)
        phi     FP_CALL
        ldi     LOW(FP_CLEAR)
        plo     FP_CALL
        sep     FP_CALL
;
; Scroll the message on the display until a key is pressed.
;
init_loop:
        ldi     0
        plo     R8          ; R8 = scroll offset into the message.
loop:
;
; Bail out once the user presses a key.
;
        ldi     HIGH(FP_GET_KEY)
        phi     FP_CALL
        ldi     LOW(FP_GET_KEY)
        plo     FP_CALL
        sep     FP_CALL
        bz      read_keys
;
; Display the message at its current offset.
;
        glo     R8
        adi     LOW(message)
        plo     FP_PTR
        ldi     0
        adci    HIGH(message)
        phi     FP_PTR
        ldi     FP_DISP_1
        plo     FP_REG1
        ldi     HIGH(FP_DRAW_STRING)
        phi     FP_CALL
        ldi     LOW(FP_DRAW_STRING)
        plo     FP_CALL
        sep     FP_CALL
;
; Perform a delay before moving onto the next scroll position.
;
        ldi     32
        plo     R9
        phi     R9
digit_delay:
        dec     R9
        ghi     R9
        bnz     digit_delay
;
; Increment the scroll offset and wrap around at the end of the message.
;
        glo     R8
        adi     1
        plo     R8
        sdi     message_end-message-5
        bnf     loop
        br      init_loop

;
; Location of a 7-byte buffer in RAM.
;
buffer equ $F100

;
; Clear the display and print keys as they are pressed on the keypad.
;
read_keys:
        ldi     HIGH(FP_CLEAR)
        phi     FP_CALL
        ldi     LOW(FP_CLEAR)
        plo     FP_CALL
        sep     FP_CALL
;
; Clear the buffer and leave a pointer to it in R7.
;
        ldi     HIGH(buffer+6)
        phi     R7
        ldi     LOW(buffer+6)
        plo     R7
        sex     R7
        ldi     0
        stxd
        ldi     $20
        stxd
        stxd
        stxd
        stxd
        stxd
        str     R7
;
next_key:
;
; Scroll the buffer contents left.
;
        inc     R7          ; offset 1 => 0
        ldn     R7
        dec     R7
        str     R7
        inc     R7          ; offset 2 => 1
        inc     R7
        ldn     R7
        dec     R7
        str     R7
        inc     R7          ; offset 3 => 2
        inc     R7
        ldn     R7
        dec     R7
        str     R7
        inc     R7          ; offset 4 => 3
        inc     R7
        ldn     R7
        dec     R7
        str     R7
        inc     R7          ; offset 5 => 4
        inc     R7
        ldn     R7
        dec     R7
        str     R7
        inc     R7          ; R7 is now buffer + 5.
;
; Wait for a key to be pressed and store it's ASCII form to the buffer.
;
        ldi     HIGH(FP_WAIT_KEY)
        phi     FP_CALL
        ldi     LOW(FP_WAIT_KEY)
        plo     FP_CALL
        sep     FP_CALL
        adi     LOW(FP_TO_HEX)
        plo     R9
        ldi     HIGH(FP_TO_HEX)
        adci    0
        phi     R9
        ldn     R9
        str     R7
        ldi     LOW(buffer)
        plo     R7
;
; Draw the current contents of the buffer.
;
        glo     R7
        plo     FP_PTR
        ghi     R7
        phi     FP_PTR
        ldi     FP_DISP_1
        plo     FP_REG1
        ldi     HIGH(FP_DRAW_STRING)
        phi     FP_CALL
        ldi     LOW(FP_DRAW_STRING)
        plo     FP_CALL
        sep     FP_CALL
;
        lbr     next_key

;
; Pad to a 32K EEPROM size.
;
        org     $7FFF
        db      $FF
        end
