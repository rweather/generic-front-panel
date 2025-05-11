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
; Address of the generic front panel in memory space.  Modify as needed.
;
    .ifndef FP_ADDR
FP_ADDR .equ $4000
    .endif

;
; Address in the zero page for a temporary 16-bit pointer.  Modify as needed.
;
    .ifndef FP_TEMP_PTR
FP_TEMP_PTR .equ $2C
    .endif

;
; Address in the zero page for a temporary 8-bit variable.  Modify as needed.
;
    .ifndef FP_TEMP
FP_TEMP .equ $2E
    .endif

;
; Offsets of the six 7-segment displays in the memory map.  These values
; are passed in X to the subroutines below to indicate where to start
; drawing on the display.
;
FP_DISP_1 .equ 0
FP_DISP_2 .equ 8
FP_DISP_3 .equ 16
FP_DISP_4 .equ 24
FP_DISP_5 .equ 32
FP_DISP_6 .equ 40

;
; Keycodes.
;
FP_KEY_0 .equ 0
FP_KEY_1 .equ 1
FP_KEY_2 .equ 2
FP_KEY_3 .equ 3
FP_KEY_4 .equ 4
FP_KEY_5 .equ 5
FP_KEY_6 .equ 6
FP_KEY_7 .equ 7
FP_KEY_8 .equ 8
FP_KEY_9 .equ 9
FP_KEY_A .equ 10
FP_KEY_B .equ 11
FP_KEY_C .equ 12
FP_KEY_D .equ 13
FP_KEY_E .equ 14
FP_KEY_F .equ 15
FP_KEY_CMD1 .equ 16    ; CMD1 key.
FP_KEY_CMD2 .equ 17    ; CMD2 key.
FP_KEY_CMD3 .equ 18    ; CMD3 key.
FP_KEY_NONE .equ 255   ; No key pressed.

;
; Clear the display.  Preserves A, X, and Y.
;
FP_CLEAR:
    .ifdef CPU_65C02
        pha
        phx
    .else
        pha
        txa
        pha
    .endif
        ldx     #$2F
        lda     #$01
FP_CLEAR_LOOP:
        sta     FP_ADDR,x
        dex
        bpl     FP_CLEAR_LOOP
    .ifdef CPU_65C02
        plx
        pla
    .else
        pla
        tax
        pla
    .endif
        rts

;
; Turn on all segments on the display.  Preserves A, X, and Y.
;
FP_ALL_ON:
        sta     FP_ADDR+56
        rts

;
; Draw a 16-bit word on the display as four hexadecimal digits.
; The high byte of the address is in A and the low byte is in Y.
; X is the position on the display to start at.
;
; Destroys A.  Preserves Y.  X is advanced by four positions on the display.
;
; X can be one of FP_DISP_1, FP_DISP_2, or FP_DISP_3.  Any other
; value will give unexpected results.
;
FP_DRAW_WORD:
        jsr     FP_DRAW_BYTE
        tya
        ; Fall through to the next subroutine.

;
; Draw a byte on the display as two hexadecimal digits.  The byte is in A and
; X is the position on the display to start at.
;
; Destroys A.  X is advanced by two positions on the display.
;
; X can be one of FP_DISP_1, FP_DISP_2, FP_DISP_3, FP_DISP_4, or
; FP_DISP_5.  Any other value will give unexpected results.
;
FP_DRAW_BYTE:
        pha
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        jsr     FP_DRAW_NIBBLE
        pla
        ; Fall through to the next subroutine.

;
; Draw a hexadecimal nibble on the display.  The nibble is in the
; low 4 bits of A and X is the position on the display.
;
; Destroys A.  X is advanced to the position of the next display digit.
;
; X can be one of FP_DISP_1, FP_DISP_2, FP_DISP_3, FP_DISP_4, FP_DISP_5,
; or FP_DISP_6.  Any other value will give unexpected results.
;
FP_DRAW_NIBBLE:
        and     #$0F
        ora     #$30
        cmp     #$3A
        bcc     FP_DRAW_CHAR
        adc     #6
        ; Fall through to the next subroutine.

;
; Draw an ASCII character.  A contains the character and X contains the
; offset of the 7-segment display to draw it on.
;
; Preserves A and Y.  X is advanced to the position of the next display digit.
;
; X can be one of FP_DISP_1, FP_DISP_2, FP_DISP_3, FP_DISP_4, FP_DISP_5,
; or FP_DISP_6.  Any other value will give unexpected results.
;
FP_DRAW_CHAR:
    .ifdef CPU_65C02
        pha
        phy
    .else
        sta     FP_TEMP
        pha
        tya
        pha
        lda     FP_TEMP
    .endif
        cmp     #$20            ; Range-check the ASCII character.
        bcc     FP_DRAW_CHAR_INVALID
        cmp     #$7F
        bcc     FP_DRAW_CHAR_GOOD
FP_DRAW_CHAR_INVALID:
        lda     #$20            ; Invalid character, show it as a space.
FP_DRAW_CHAR_GOOD:
        tay
        lda     FP_BITMAPS-32,y
        eor     #$FF            ; Invert the bits, 0 = on, 1 = off.
        sta     FP_TEMP
        ldy     #8
FP_DRAW_SEGMENT:
        lda     #0
        lsr     FP_TEMP
        adc     #0
        sta     FP_ADDR,x
        inx
        dey
        bne     FP_DRAW_SEGMENT
    .ifdef CPU_65C02
        ply
        pla
    .else
        pla
        tay
        pla
    .endif
        rts

;
; Draw an ASCII string on the display.  A:Y points at the string, with the
; high byte of the address in A and the low byte of the address in Y.
;
; X is the position on the display to start drawing at.  Stops drawing when
; either X goes off the end of the display or a NUL is seen in the string.
;
; Destroys A and Y.  X is advanced by the number of characters drawn.
;
FP_DRAW_STRING:
        sty     FP_TEMP_PTR
        sta     FP_TEMP_PTR+1
        ldy     #0
FP_DRAW_STRING_LOOP:
        cpx     #(FP_DISP_6 + 1)
        bcs     FP_DRAW_STRING_DONE
        lda     (FP_TEMP_PTR),y
        beq     FP_DRAW_STRING_DONE
        jsr     FP_DRAW_CHAR
        iny
        bne     FP_DRAW_STRING_LOOP
FP_DRAW_STRING_DONE:
        rts

;
; Get the key that is currently pressed into A.  Returns FP_KEY_NONE
; if no key is currently pressed.  If multiple keys are pressed, then the
; key with the lowest numeric value will be returned.
;
; Destroys A.  Preserves X and Y.
;
FP_GET_KEY:
        lda     FP_ADDR+$1E
        eor     #$0F
        and     #$0F
        bne     FP_GET_KEY_ROW_0
        lda     FP_ADDR+$1D
        eor     #$0F
        and     #$0F
        bne     FP_GET_KEY_ROW_1
        lda     FP_ADDR+$1B
        eor     #$0F
        and     #$0F
        bne     FP_GET_KEY_ROW_2
        lda     FP_ADDR+$17
        eor     #$0F
        and     #$0F
        bne     FP_GET_KEY_ROW_3
        lda     FP_ADDR+$0E
        eor     #$07
        and     #$07
        beq     FP_GET_KEY_NONE
        sta     FP_TEMP
        lda     #16
        bne     FP_GET_KEY_FIND_BIT
FP_GET_KEY_ROW_3:
        sta     FP_TEMP
        lda     #12
        bne     FP_GET_KEY_FIND_BIT
FP_GET_KEY_ROW_2:
        sta     FP_TEMP
        lda     #8
        bne     FP_GET_KEY_FIND_BIT
FP_GET_KEY_ROW_1:
        sta     FP_TEMP
        lda     #4
        bne     FP_GET_KEY_FIND_BIT
FP_GET_KEY_ROW_0:
        sta     FP_TEMP
        lda     #0
FP_GET_KEY_FIND_BIT:
        lsr     FP_TEMP
        bcs     FP_GET_KEY_DONE
        adc     #1
        lsr     FP_TEMP
        bcs     FP_GET_KEY_DONE
        adc     #1
        lsr     FP_TEMP
        bcs     FP_GET_KEY_DONE
        adc     #1
FP_GET_KEY_DONE:
        rts
FP_GET_KEY_NONE:
        lda     #FP_KEY_NONE
        rts

;
; Wait for a key to be pressed and then released.
;
; Destroys A.  Preserves X and Y.
;
FP_WAIT_KEY:
        jsr     FP_GET_KEY
        cmp     #FP_KEY_NONE
        beq     FP_WAIT_KEY
        sta     FP_TEMP_PTR
FP_WAIT_RELEASE:
        jsr     FP_GET_KEY
        cmp     FP_TEMP_PTR
        beq     FP_WAIT_RELEASE
        lda     FP_TEMP_PTR
        rts

;
; 7-segment bit patterns for the ASCII characters $20 to $7E.
; Some cannot be drawn properly, so they are mapped to something else.
;
; Characters marked with (**) won't look very good, so avoid them.
;
; Some ideas from here: https://github.com/dmadison/LED-Segment-ASCII
;
FP_BITMAPS:
        .db     %00000000       ; $20 - SP
        .db     %10000110       ; $21 - !
        .db     %00100010       ; $22 - "
        .db     %01110110       ; $23 - # (**)
        .db     %01101101       ; $24 - $ (**)
        .db     %11010010       ; $25 - %
        .db     %01011101       ; $26 - & (**)
        .db     %00100000       ; $27 - '
        .db     %00100001       ; $28 - (
        .db     %00001100       ; $29 - )
        .db     %01110110       ; $2A - * (**)
        .db     %01110000       ; $2B - + (**)
        .db     %00010000       ; $2C - ,
        .db     %00001000       ; $2D - -
        .db     %10000000       ; $2E - .
        .db     %01010010       ; $2F - /
;
        .db     %00111111       ; $30 - 0
        .db     %00000110       ; $31 - 1
        .db     %01011011       ; $32 - 2
        .db     %01001111       ; $33 - 3
        .db     %01100110       ; $34 - 4
        .db     %01101101       ; $35 - 5
        .db     %01111101       ; $36 - 6
        .db     %00000111       ; $37 - 7
        .db     %01111111       ; $38 - 8
        .db     %01101111       ; $39 - 9
        .db     %00001001       ; $3A - :
        .db     %00001101       ; $3B - ;
        .db     %01100001       ; $3C - < (**)
        .db     %01001000       ; $3D - =
        .db     %01000011       ; $3E - > (**)
        .db     %11010011       ; $3F - ?
;
        .db     %01011111       ; $40 - @
        .db     %01110111       ; $41 - A
        .db     %01111100       ; $42 - B => b
        .db     %00111001       ; $43 - C
        .db     %01011110       ; $44 - D => d
        .db     %01111001       ; $45 - E
        .db     %01110001       ; $46 - F
        .db     %00111101       ; $47 - G
        .db     %01110110       ; $48 - H
        .db     %00110000       ; $49 - I
        .db     %00011110       ; $4A - J
        .db     %01110101       ; $4B - K => k
        .db     %00111000       ; $4C - L
        .db     %00010101       ; $4D - M (**)
        .db     %00110111       ; $4E - N
        .db     %00111111       ; $4F - O
;
        .db     %01110011       ; $50 - P
        .db     %01100111       ; $51 - Q => q
        .db     %01010000       ; $52 - R => r
        .db     %01101101       ; $53 - S
        .db     %01111000       ; $54 - T => t
        .db     %00111110       ; $55 - U
        .db     %00011100       ; $56 - V => v (**)
        .db     %00101010       ; $57 - W (**)
        .db     %01110110       ; $58 - X
        .db     %01101110       ; $59 - Y => y
        .db     %01011011       ; $5A - Z
        .db     %00111001       ; $5B - [
        .db     %01100100       ; $5C - \
        .db     %00001111       ; $5D - ]
        .db     %00100011       ; $5E - ^
        .db     %00001000       ; $5F - _
;
        .db     %00000010       ; $60 - `
        .db     %01011111       ; $61 - a
        .db     %01111100       ; $62 - b
        .db     %01011000       ; $63 - c
        .db     %01011110       ; $64 - d
        .db     %01111011       ; $65 - e
        .db     %01110001       ; $66 - f => F
        .db     %01101111       ; $67 - g
        .db     %01110100       ; $68 - h
        .db     %00010000       ; $69 - i
        .db     %00001100       ; $6A - j
        .db     %01110101       ; $6B - k
        .db     %00110000       ; $6C - l
        .db     %00010100       ; $6D - m (**)
        .db     %01010100       ; $6E - n
        .db     %01011100       ; $6F - o
;
        .db     %01110011       ; $70 - p => P
        .db     %01100111       ; $71 - q
        .db     %01010000       ; $72 - r
        .db     %01101101       ; $73 - s => S
        .db     %01111000       ; $74 - t
        .db     %00011100       ; $75 - u
        .db     %00011100       ; $76 - v (**)
        .db     %00010100       ; $77 - w (**)
        .db     %01110110       ; $78 - x => X
        .db     %01101110       ; $79 - y
        .db     %01011011       ; $7A - z => Z
        .db     %01000110       ; $7B - {
        .db     %00110000       ; $7C - |
        .db     %01110000       ; $7D - }
        .db     %00000001       ; $7E - ~
