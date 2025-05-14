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

;------------------------------------------------------------------------
;
; The following definitions can be modified to adapt the driver to
; different 1802-based board computers and calling software stacks.
;

;
; Input and output ports to use to communicate with the front panel.
;
FP_PORT_IN  equ 1
FP_PORT_OUT equ 1

;
; Address of a 64-byte region of RAM to use when staging data to and
; from the front panel.  Must be aligned on a 256-byte page boundary.
;
FP_ADDR equ $F000

;
; Register number for the stack pointer.  X will be restored to this
; register's contents on exit from the driver subroutines.
;
FP_SP equ R2

;
; Register number for setting up calls to the subroutines below.
; This will be the program counter during the driver code.
;
FP_CALL equ R3

;
; Register number for returning from subroutines back to the main code.
; This is the program counter in the main code.
;
FP_RET equ R4

;
; Register to pass a string pointer to FP_DRAW_STRING.
;
FP_PTR equ R11

;
; Temporary registers that the code below can freely destroy.
;
FP_REG1 equ R12
FP_REG2 equ R13
FP_REG3 equ R14
FP_REG4 equ R15

;------------------------------------------------------------------------

;
; Offsets of the six 7-segment displays in the memory map.  These values
; are passed in FP_REG1 to the subroutines below to indicate where to start
; drawing on the display.
;
FP_DISP_1 equ 0
FP_DISP_2 equ 8
FP_DISP_3 equ 16
FP_DISP_4 equ 24
FP_DISP_5 equ 32
FP_DISP_6 equ 40

;
; Keycodes.
;
FP_KEY_0 equ 0
FP_KEY_1 equ 1
FP_KEY_2 equ 2
FP_KEY_3 equ 3
FP_KEY_4 equ 4
FP_KEY_5 equ 5
FP_KEY_6 equ 6
FP_KEY_7 equ 7
FP_KEY_8 equ 8
FP_KEY_9 equ 9
FP_KEY_A equ 10
FP_KEY_B equ 11
FP_KEY_C equ 12
FP_KEY_D equ 13
FP_KEY_E equ 14
FP_KEY_F equ 15
FP_KEY_CMD1 equ 16      ; CMD1 key.
FP_KEY_CMD2 equ 17      ; CMD2 key.
FP_KEY_CMD3 equ 18      ; CMD3 key.
FP_KEY_NONE equ 255     ; No key pressed.

;
; Align on a 256-byte page boundary to ensure all branches are local.
;
        page

;
; Clear the display.
;
FP_CLEAR_EXIT:
        sep     FP_RET
FP_CLEAR:
        ldi     HIGH(FP_ADDR)
        phi     FP_REG1
        ldi     LOW(FP_ADDR)
        plo     FP_REG1
        ldi     48
        plo     FP_REG2
        sex     FP_REG1
FP_CLEAR_LOOP:
        ldi     1
        str     FP_REG1
        out     FP_PORT_OUT
        dec     FP_REG2
        glo     FP_REG2
        bnz     FP_CLEAR_LOOP
        sex     FP_SP
        br      FP_CLEAR_EXIT

;
; Turn on all segments on the display.
;
FP_ALL_ON_EXIT:
        sep     FP_RET
FP_ALL_ON:
        ldi     HIGH(FP_ADDR)
        phi     FP_REG1
        ldi     56
        plo     FP_REG1
        sex     FP_REG1
        ldi     0
        str     FP_REG1
        out     FP_PORT_OUT
        sex     FP_SP
        br      FP_ALL_ON_EXIT

;
; Draw a byte on the display as two hexadecimal digits.  The byte is in D and
; FP_REG1 is the position on the display to start at.
;
; The low byte of FP_REG1 will be advanced by two positions on the display.
; The high byte of FP_REG1 will be destroyed.
;
; FP_REG1 can be one of FP_DISP_1, FP_DISP_2, FP_DISP_3, FP_DISP_4, or
; FP_DISP_5.  Any other value will give unexpected results.
;
FP_DRAW_BYTE_EXIT:
        sep     FP_RET
FP_DRAW_BYTE:
        phi     FP_REG3
        ldi     HIGH(FP_DRAW_CHAR_INNER)
        phi     FP_REG4
        ldi     LOW(FP_DRAW_CHAR_INNER)
        plo     FP_REG4
;
; Convert the high nibble into hexadecimal and display it.
;
        ghi     FP_REG3
        shr
        shr
        shr
        shr
        adi     LOW(FP_TO_HEX)
        plo     FP_REG2
        ldi     HIGH(FP_TO_HEX)
        adci    0
        phi     FP_REG2
        ldn     FP_REG2
        sep     FP_REG4
;
; Convert the low nibble into hexadecimal and display it.
;
        ghi     FP_REG3
        ani     15
        adi     LOW(FP_TO_HEX)
        plo     FP_REG2
        ldi     HIGH(FP_TO_HEX)
        adci    0
        phi     FP_REG2
        ldn     FP_REG2
        sep     FP_REG4
;
; Return to the caller.
;
        br      FP_DRAW_BYTE_EXIT

;
; Draw an ASCII character.  D contains the character and the low byte of
; FP_REG1 contains the offset of the 7-segment display to draw it on.
;
; FP_REG1 is advanced to the position of the next display digit.
;
; FP_REG1 can be one of FP_DISP_1, FP_DISP_2, FP_DISP_3, FP_DISP_4, FP_DISP_5,
; or FP_DISP_6.  Any other value will give unexpected results.
;
; Only ASCII characters $20 to $7F can be drawn.  Anything else will
; produce garbage.
;
FP_DRAW_CHAR_EXIT:
        sep     FP_RET
FP_DRAW_CHAR:
        plo     FP_REG2
        ldi     HIGH(FP_DRAW_CHAR_INNER)
        phi     FP_REG4
        ldi     LOW(FP_DRAW_CHAR_INNER)
        plo     FP_REG4
        glo     FP_REG2
        sep     FP_REG4
        br      FP_DRAW_CHAR_EXIT
;
FP_DRAW_CHAR_INNER_EXIT:
        sep     FP_CALL
FP_DRAW_CHAR_INNER:
;
; Find the 7-segment bit pattern for the character.
;
        adi     LOW(FP_BITMAPS-32)
        plo     FP_REG2
        ldi     HIGH(FP_BITMAPS-32)
        adci    0
        phi     FP_REG2
        ldn     FP_REG2
        plo     FP_REG2         ; Bit pattern is now in the low byte of FP_REG2.
;
; Shift the bits out one by one and write them to the display.
;
        ldi     HIGH(FP_ADDR)
        phi     FP_REG1
        sex     FP_REG1
        ldi     8
        plo     FP_REG3
FP_DRAW_SEGMENT:
        glo     FP_REG2
        shr
        plo     FP_REG2
        ldi     0
        shlc
        str     FP_REG1
        out     FP_PORT_OUT
        dec     FP_REG3
        glo     FP_REG3
        bnz     FP_DRAW_SEGMENT
;
; Clean up and return to the caller.
;
        sex     FP_SP
        br      FP_DRAW_CHAR_INNER_EXIT

;
; Draw an ASCII string on the display.  FP_PTR points at the string,
; which is terminated by a NUL.
;
; The low byte of FP_REG1 is the position on the display to start drawing at.
; Stops drawing when either FP_REG1 goes off the end of the display or a
; NUL is seen in the string.
;
; FP_REG1 is advanced by the number of characters drawn.  FP_PTR is destroyed.
;
FP_DRAW_STRING_EXIT:
        sex     FP_SP
        sep     FP_RET
FP_DRAW_STRING:
        ldi     HIGH(FP_DRAW_CHAR_INNER)
        phi     FP_REG4
        ldi     LOW(FP_DRAW_CHAR_INNER)
        plo     FP_REG4
FP_DRAW_STRING_LOOP:
        plo     FP_REG1
        sdi     48
        bdf     FP_DRAW_STRING_EXIT
        sex     FP_PTR
        ldxa
        bz      FP_DRAW_STRING_EXIT
        sep     FP_REG4
        br      FP_DRAW_STRING_LOOP

;
; Get the key that is currently pressed into the low byte of FP_REG1.
; D is zero if a key is pressed.  D is set to FP_KEY_NONE if no key
; is pressed.
;
; If multiple keys are pressed, then the key with the lowest numeric
; value will be returned.
;
FP_GET_KEY_EXIT:
        sex     FP_SP
        sep     FP_RET
FP_GET_KEY:
        ldi     HIGH(FP_GET_KEY_INNER)
        phi     FP_REG4
        ldi     LOW(FP_GET_KEY_INNER)
        plo     FP_REG4
        sep     FP_REG4
        br      FP_GET_KEY_EXIT
;
FP_GET_KEY_INNER_EXIT:
        sep     FP_CALL
FP_GET_KEY_INNER:
        ldi     HIGH(FP_ADDR)
        phi     FP_REG2
        ldi     0
        plo     FP_REG1
        ldi     $1E
        plo     FP_REG2
        sex     FP_REG2
;
        inp     FP_PORT_IN
        xri     $0F
        ani     $0F
        bnz     FP_GET_KEY_COLUMN
;
        ldi     4
        plo     FP_REG1
        ldi     $1D
        plo     FP_REG2
        inp     FP_PORT_IN
        xri     $0F
        ani     $0F
        bnz     FP_GET_KEY_COLUMN
;
        ldi     8
        plo     FP_REG1
        ldi     $1B
        plo     FP_REG2
        inp     FP_PORT_IN
        xri     $0F
        ani     $0F
        bnz     FP_GET_KEY_COLUMN
;
        ldi     12
        plo     FP_REG1
        ldi     $17
        plo     FP_REG2
        inp     FP_PORT_IN
        xri     $0F
        ani     $0F
        bnz     FP_GET_KEY_COLUMN
;
        ldi     16
        plo     FP_REG1
        ldi     $07
        plo     FP_REG2
        inp     FP_PORT_IN
        xri     $07
        ani     $07
        bz      FP_GET_KEY_NONE
;
FP_GET_KEY_COLUMN:
        shr
        bdf     FP_GET_KEY_DONE
        inc     FP_REG1
        shr
        bdf     FP_GET_KEY_DONE
        inc     FP_REG1
        shr
        bdf     FP_GET_KEY_DONE
        inc     FP_REG1
FP_GET_KEY_DONE:
        ldi     0                   ; Set D to zero if we have a key.
        br      FP_GET_KEY_INNER_EXIT
;
FP_GET_KEY_NONE:
        ldi     FP_KEY_NONE         ; Set D to FP_KEY_NONE for no key.
        plo     FP_REG1
        br      FP_GET_KEY_INNER_EXIT

;
; Wait for a key to be pressed and then released.  The key that was
; pressed is returned in D.
;
FP_WAIT_KEY_EXIT:
        sep     FP_RET
FP_WAIT_KEY:
        ldi     HIGH(FP_GET_KEY_INNER)
        phi     FP_REG4
        ldi     LOW(FP_GET_KEY_INNER)
        plo     FP_REG4
;
FP_WAIT_FOR_PRESS:
        sep     FP_REG4
        bnz     FP_WAIT_FOR_PRESS
        glo     FP_REG1
        phi     FP_REG1
;
FP_WAIT_FOR_RELEASE:
        sep     FP_REG4
        lbz     FP_WAIT_FOR_RELEASE
        ghi     FP_REG1
        lbr     FP_WAIT_KEY_EXIT

;
; 7-segment bit patterns for the ASCII characters $20 to $7E.
; Some cannot be drawn properly, so they are mapped to something else.
;
; Characters marked with (**) won't look very good, so avoid them.
;
; Some ideas from here: https://github.com/dmadison/LED-Segment-ASCII
;
FP_BITMAPS:
        db      %11111111       ; $20 - SP
        db      %01111001       ; $21 - !
        db      %11011101       ; $22 - "
        db      %10001001       ; $23 - # (**)
        db      %10010010       ; $24 - $ (**)
        db      %00101101       ; $25 - %
        db      %10100010       ; $26 - & (**)
        db      %11011111       ; $27 - '
        db      %11011110       ; $28 - (
        db      %11110011       ; $29 - )
        db      %10001001       ; $2A - * (**)
        db      %10001111       ; $2B - + (**)
        db      %11101111       ; $2C - ,
        db      %10111111       ; $2D - -
        db      %01111111       ; $2E - .
        db      %10101101       ; $2F - /
;
        db      %11000000       ; $30 - 0
        db      %11111001       ; $31 - 1
        db      %10100100       ; $32 - 2
        db      %10110000       ; $33 - 3
        db      %10011001       ; $34 - 4
        db      %10010010       ; $35 - 5
        db      %10000010       ; $36 - 6
        db      %11111000       ; $37 - 7
        db      %10000000       ; $38 - 8
        db      %10010000       ; $39 - 9
        db      %11110110       ; $3A - :
        db      %11110010       ; $3B - ;
        db      %10011110       ; $3C - < (**)
        db      %10110111       ; $3D - =
        db      %10111100       ; $3E - > (**)
        db      %00101100       ; $3F - ?
;
        db      %10100000       ; $40 - @
        db      %10001000       ; $41 - A
        db      %10000011       ; $42 - B => b
        db      %11000110       ; $43 - C
        db      %10100001       ; $44 - D => d
        db      %10000110       ; $45 - E
        db      %10001110       ; $46 - F
        db      %11000010       ; $47 - G
        db      %10001001       ; $48 - H
        db      %11001111       ; $49 - I
        db      %11100001       ; $4A - J
        db      %10001010       ; $4B - K => k
        db      %11000111       ; $4C - L
        db      %11101010       ; $4D - M (**)
        db      %11001000       ; $4E - N
        db      %11000000       ; $4F - O
;
        db      %10001100       ; $50 - P
        db      %10011000       ; $51 - Q => q
        db      %10101111       ; $52 - R => r
        db      %10010010       ; $53 - S
        db      %10000111       ; $54 - T => t
        db      %11000001       ; $55 - U
        db      %11100011       ; $56 - V => v (**)
        db      %11010101       ; $57 - W (**)
        db      %10001001       ; $58 - X
        db      %10010001       ; $59 - Y => y
        db      %10100100       ; $5A - Z
        db      %11000110       ; $5B - [
        db      %10011011       ; $5C - \
        db      %11110000       ; $5D - ]
        db      %11011100       ; $5E - ^
        db      %11110111       ; $5F - _
;
        db      %11111101       ; $60 - `
        db      %10100000       ; $61 - a
        db      %10000011       ; $62 - b
        db      %10100111       ; $63 - c
        db      %10100001       ; $64 - d
        db      %10000100       ; $65 - e
        db      %10001110       ; $66 - f => F
        db      %10010000       ; $67 - g
        db      %10001011       ; $68 - h
        db      %11101111       ; $69 - i
        db      %11110011       ; $6A - j
        db      %10001010       ; $6B - k
        db      %11001111       ; $6C - l
        db      %11101011       ; $6D - m (**)
        db      %10101011       ; $6E - n
        db      %10100011       ; $6F - o
;
        db      %10001100       ; $70 - p => P
        db      %10011000       ; $71 - q
        db      %10101111       ; $72 - r
        db      %10010010       ; $73 - s => S
        db      %10000111       ; $74 - t
        db      %11100011       ; $75 - u
        db      %11100011       ; $76 - v (**)
        db      %11101011       ; $77 - w (**)
        db      %10001001       ; $78 - x => X
        db      %10010001       ; $79 - y
        db      %10100100       ; $7A - z => Z
        db      %10111001       ; $7B - {
        db      %11001111       ; $7C - |
        db      %10001111       ; $7D - }
        db      %11111110       ; $7E - ~
        db      %00000000       ; $7F - DEL (**)
;
; Table for converting nibbles into hexadecimal characters.
;
FP_TO_HEX:
        db      "0123456789ABCDEF"
