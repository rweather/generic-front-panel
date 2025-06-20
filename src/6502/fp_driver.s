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
; Address in the zero page for temporary 8-bit variables.  Modify as needed.
;
    .ifndef FP_TEMP
FP_TEMP .equ $2E
    .endif
    .ifndef FP_TEMP2
FP_TEMP2 .equ $2F
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
; Keycodes, which are mapped to ASCII characters 0..9, A..I where
; CMD1, CMD2, and CMD3 are mapped to G, H, and I respectively.
;
FP_KEY_0 .equ $30
FP_KEY_1 .equ $31
FP_KEY_2 .equ $32
FP_KEY_3 .equ $33
FP_KEY_4 .equ $34
FP_KEY_5 .equ $35
FP_KEY_6 .equ $36
FP_KEY_7 .equ $37
FP_KEY_8 .equ $38
FP_KEY_9 .equ $39
FP_KEY_A .equ $41
FP_KEY_B .equ $42
FP_KEY_C .equ $43
FP_KEY_D .equ $44
FP_KEY_E .equ $45
FP_KEY_F .equ $46
FP_KEY_CMD1 .equ $47   ; CMD1 key.
FP_KEY_CMD2 .equ $48   ; CMD2 key.
FP_KEY_CMD3 .equ $49   ; CMD3 key.
FP_KEY_NONE .equ 0     ; No key pressed.

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
; Draw an ASCII character.  A contains the character and X contains the
; offset of the 7-segment display to draw it on.
;
; Preserves A and Y.  X is advanced to the position of the next display digit.
;
; X can be one of FP_DISP_1, FP_DISP_2, FP_DISP_3, FP_DISP_4, FP_DISP_5,
; or FP_DISP_6.  Any other value will give unexpected results.
;
; The high bit of A can be set to draw the character with a decimal point.
; For example, $C1 is A with a decimal point.  $00 to $1F and $80 to $9F
; will produce garbage, but all other characters will draw something.
;
FP_DRAW_CHAR:
        sta     FP_TEMP
        pha
    .ifdef CPU_65C02
        phy
    .else
        tya
        pha
        lda     FP_TEMP
    .endif
        and     #$7F
        tay
        lda     FP_BITMAPS-32,y
        ldy     FP_TEMP
        bpl     FP_DRAW_CHAR_2
        and     #$7F            ; Turn on the decimal point.
FP_DRAW_CHAR_2:
        sta     FP_TEMP
        ldy     #8
FP_DRAW_SEGMENT:
        lsr     FP_TEMP
        rol     a
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
; Get the key that is currently pressed into A.  Returns 0 if no key is
; currently pressed.  If multiple keys are pressed, then the key with the
; lowest numeric value will be returned.
;
; There is no debouncing in this function so the keys may be a little jumpy.
; FP_WAIT_KEY implements debouncing.
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
        lda     FP_ADDR+$0F
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
        clc                     ; Convert the key into ASCII.
        adc     #$30
        cmp     #$3A
        bcc     FP_GET_KEY_RETURN
        adc     #6
FP_GET_KEY_RETURN:
        rts
FP_GET_KEY_NONE:
        lda     #FP_KEY_NONE
        rts

;
; Wait for a key to be pressed and then released.  Returns the key in A.
;
; This function implements debouncing of the key, with the key reported
; once the release has been fully debounced.
;
; Destroys A.  Preserves X and Y.
;
FP_DEBOUNCE_COUNT .equ 255
FP_WAIT_KEY:
    .ifdef CPU_65C02
        phy
    .else
        tya
        pha
    .endif
FP_WAIT_KEY_LOOP:
        jsr     FP_GET_KEY
        cmp     #FP_KEY_NONE
        beq     FP_WAIT_KEY_LOOP
FP_CHANGE_KEYS:
        sta     FP_TEMP2
        ldy     #FP_DEBOUNCE_COUNT
FP_WAIT_RELEASE:
        jsr     FP_GET_KEY
        cmp     #FP_KEY_NONE
        beq     FP_WAIT_KEY_LOOP    ; Release during the debounce period.
        cmp     FP_TEMP2
        bne     FP_CHANGE_KEYS      ; Switched to another key during debounce.
        dey                         ; Have we debounced the press?
        bne     FP_WAIT_RELEASE
        ldy     #FP_DEBOUNCE_COUNT  ; Now to debounce the release.
FP_WAIT_RELEASE_LOOP:
        jsr     FP_GET_KEY
        cmp     #FP_KEY_NONE
        bne     FP_WAIT_RELEASE_LOOP
        dey                         ; Have we debounced the release?
        bne     FP_WAIT_RELEASE_LOOP
    .ifdef CPU_65C02
        ply
    .else
        pla
        tay
    .endif
        lda     FP_TEMP2
        rts

;
; 7-segment bit patterns for the ASCII characters $20 to $7F.
; Some cannot be drawn properly, so they are mapped to something else.
;
; Characters marked with (**) won't look very good, so avoid them.
;
; Some ideas from here: https://github.com/dmadison/LED-Segment-ASCII
;
FP_BITMAPS:
        .db     %11111111       ; $20 - SP
        .db     %01111001       ; $21 - !
        .db     %11011101       ; $22 - "
        .db     %10001001       ; $23 - # (**)
        .db     %10010010       ; $24 - $ (**)
        .db     %00101101       ; $25 - %
        .db     %10000010       ; $26 - &
        .db     %11011111       ; $27 - '
        .db     %11011110       ; $28 - (
        .db     %11110011       ; $29 - )
        .db     %10001001       ; $2A - * (**)
        .db     %10001111       ; $2B - + (**)
        .db     %11101111       ; $2C - ,
        .db     %10111111       ; $2D - -
        .db     %01111111       ; $2E - .
        .db     %10101101       ; $2F - /
;
        .db     %11000000       ; $30 - 0
        .db     %11111001       ; $31 - 1
        .db     %10100100       ; $32 - 2
        .db     %10110000       ; $33 - 3
        .db     %10011001       ; $34 - 4
        .db     %10010010       ; $35 - 5
        .db     %10000010       ; $36 - 6
        .db     %11111000       ; $37 - 7
        .db     %10000000       ; $38 - 8
        .db     %10010000       ; $39 - 9
        .db     %11110110       ; $3A - :
        .db     %11110010       ; $3B - ;
        .db     %10011110       ; $3C - < (**)
        .db     %10110111       ; $3D - =
        .db     %10111100       ; $3E - > (**)
        .db     %00101100       ; $3F - ?
;
        .db     %10100000       ; $40 - @
        .db     %10001000       ; $41 - A
        .db     %10000011       ; $42 - B => b
        .db     %11000110       ; $43 - C
        .db     %10100001       ; $44 - D => d
        .db     %10000110       ; $45 - E
        .db     %10001110       ; $46 - F
        .db     %11000010       ; $47 - G
        .db     %10001001       ; $48 - H
        .db     %11001111       ; $49 - I
        .db     %11100001       ; $4A - J
        .db     %10001010       ; $4B - K => k
        .db     %11000111       ; $4C - L
        .db     %11101010       ; $4D - M (**)
        .db     %11001000       ; $4E - N
        .db     %11000000       ; $4F - O
;
        .db     %10001100       ; $50 - P
        .db     %10011000       ; $51 - Q => q
        .db     %10101111       ; $52 - R => r
        .db     %10010010       ; $53 - S
        .db     %10000111       ; $54 - T => t
        .db     %11000001       ; $55 - U
        .db     %11100011       ; $56 - V => v (**)
        .db     %11010101       ; $57 - W (**)
        .db     %10001001       ; $58 - X
        .db     %10010001       ; $59 - Y => y
        .db     %10100100       ; $5A - Z
        .db     %11000110       ; $5B - [
        .db     %10011011       ; $5C - \
        .db     %11110000       ; $5D - ]
        .db     %11011100       ; $5E - ^
        .db     %11110111       ; $5F - _
;
        .db     %11111101       ; $60 - `
        .db     %10100000       ; $61 - a
        .db     %10000011       ; $62 - b
        .db     %10100111       ; $63 - c
        .db     %10100001       ; $64 - d
        .db     %10000100       ; $65 - e
        .db     %10001110       ; $66 - f => F
        .db     %10010000       ; $67 - g
        .db     %10001011       ; $68 - h
        .db     %11101111       ; $69 - i
        .db     %11110011       ; $6A - j
        .db     %10001010       ; $6B - k
        .db     %11001111       ; $6C - l
        .db     %11101011       ; $6D - m (**)
        .db     %10101011       ; $6E - n
        .db     %10100011       ; $6F - o
;
        .db     %10001100       ; $70 - p => P
        .db     %10011000       ; $71 - q
        .db     %10101111       ; $72 - r
        .db     %10010010       ; $73 - s => S
        .db     %10000111       ; $74 - t
        .db     %11100011       ; $75 - u
        .db     %11100011       ; $76 - v (**)
        .db     %11101011       ; $77 - w (**)
        .db     %10001001       ; $78 - x => X
        .db     %10010001       ; $79 - y
        .db     %10100100       ; $7A - z => Z
        .db     %10111001       ; $7B - {
        .db     %11001111       ; $7C - |
        .db     %10001111       ; $7D - }
        .db     %11111110       ; $7E - ~
        .db     %00000000       ; $7F - DEL (**)
