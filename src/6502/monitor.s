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
; Keypad is laid out as follows:
;
;     Func  Prev Next Reset
;       C    D    E    F
;       8    9    A    B
;       4    5    6    7
;       0    1    2    3
;
; Pressing "Func" puts the monitor into the main menu.  The display will
; show "Func" to request a function mode:
;
;       A - Registers
;       C - Change
;       D - Do
;       E - Examine
;       5 - Single Step
;
; After "Reset", the words "CPU UP" will be displayed.  Press any key
; except "Func" or "Reset" to shift to "C" / "Change" mode.  "Func" will
; immediately go to the main menu.
;
; In "C" / "Change" mode, pressing "Next" and "Prev" moves forwards and
; backwards in memory examining the contents without changing them.
; Pressing hexadecimal digits will modify the current byte.  After two
; digits, the address will move onto the next location in memory automatically.
;
; In "E" / "Examine" mode, the user is prompted for a 16-bit address.
; Press "Next" or "Prev" to switch to "C" / "Change" mode at that address.
; When modifying the address, the value at the new address will not be
; displayed until "Next" or "Prev" is pressed.  This avoids reads to invalid
; memory (e.g. in I/O space) if the address has not been set properly yet.
;
; In "A" / "Registers" mode, "Next" and "Prev" will scroll forwards and
; backwards through the registers: A, X, Y, P, SP, and PC.  Pressing a
; hexadecimal digit will modify the value of the displayed register.
;
; In "D" / "Do" mode, the current value of the PC register will be
; displayed.  Hexadecimal digits can be typed to alter the PC value.
; Press "Next" or "Prev" to start executing ("doing") the code at PC.
; Or press "Func" to select a different function.
;
; In "5" / "Single Step" mode, the current instruction at "PC" is displayed.
; Press "Next" or "Prev" to step the instruction, then show the next one.
; Pressing any other key will abort back to the monitor or main menu.
;

;
; Locations between $20 and $4F in the zero page are reserved for the monitor.
;
TEMP1   .equ    $20         ; Temporary register.
TEMP2   .equ    $21         ; Temporary register.
REG_AQ  .equ    $22         ; Saved A during IRQBRK handler.
REG_A   .equ    $23         ; Saved A register.
REG_P   .equ    $24         ; Saved status register.
REG_X   .equ    $25         ; Saved X register.
REG_Y   .equ    $26         ; Saved Y register.
REG_SP  .equ    $27         ; Saved stack pointer.
REG_PC  .equ    $28         ; Saved program counter (16-bit).
REG1    .equ    $2A         ; First 16-bit register for the monitor.
REG2    .equ    $2C         ; Second 16-bit register for the monitor.
D_POSN  .equ    $2E         ; Position on the display for the next character.
M_TEMP  .equ    $2F         ; Temporary register for use by the monitor.
H_IRQ   .equ    $30         ; Address of the user's IRQ handler.
H_BREAK .equ    $32         ; Address of the user's BREAK handler.
H_NMI   .equ    $34         ; Address of the user's NMI handler.
H_RESET .equ    $36         ; Address of the user's soft reset handler.
H_CHKS  .equ    $38         ; Checksum over the last 8 bytes.
H_ICHKS .equ    $39         ; Inverted version of the value at H_CHKS.
DISPLAY .equ    $3A         ; Display buffer (6 bytes).
STEPBUF .equ    $40         ; Single-step instruction buffer (max 9 bytes).

;
; Map command keycodes to more useful names.
;
K_FUNC  .equ    FP_KEY_CMD1 ; Function selection key.
K_PREV  .equ    FP_KEY_CMD2 ; Previous.
K_NEXT  .equ    FP_KEY_CMD3 ; Next.
K_REGS  .equ    FP_KEY_A    ; Show accumulator and other registers.
K_CHG   .equ    FP_KEY_C    ; "Change" / "Modify" bytes.
K_DO    .equ    FP_KEY_D    ; "Do" / "Run" from address.
K_EXAM  .equ    FP_KEY_E    ; Examine address.
K_STEP  .equ    FP_KEY_5    ; Single-step.

;
; Default value to write to "REG_PC" on a cold start, as the first
; RAM location where new programs can be entered.
;
    .ifndef DEF_PC
DEF_PC  .equ    $0300
    .endif

    .ifdef FILL_ROM
        .org    $8000
    .endif
        .org    $F800
;
; Public routines in the monitor ROM for use by user programs.
;
        jmp     req_cold_start  ; $F800 - Request a cold start on the system.
        jmp     req_warm_start  ; $F803 - Request a warm start on the system.
        jmp     enter_monitor   ; $F806 - Enter the machine monitor.
        jmp     wait_enter      ; $F809 - Wait for keypress and then enter mon.
        jmp     set_handler     ; $F80C - Set an interrupt or reset handler.
        jmp     clear_display   ; $F80F - Clear the display.
        jmp     refresh_display ; $F812 - Refresh from the DISPLAY buffer.
        jmp     move_cursor     ; $F815 - Move the cursor on the display.
        jmp     draw_char       ; $F818 - Draw a character on the display.
        jmp     draw_nibble     ; $F81B - Draw a nibble on the display.
        jmp     draw_byte       ; $F81E - Draw a byte on the display.
        jmp     draw_word       ; $F821 - Draw a 16-bit word on the display.
        jmp     draw_string     ; $F824 - Draw a string on the display
        jmp     FP_GET_KEY      ; $F827 - Get the key that is pressed.
        jmp     FP_WAIT_KEY     ; $F82A - Wait for a key to be pressed.
        jmp     spare_handler   ; $F82D - Spare for the future.
        jmp     spare_handler   ; $F830 - Spare for the future.
        jmp     spare_handler   ; $F833 - Spare for the future.
        jmp     spare_handler   ; $F836 - Spare for the future.
        jmp     spare_handler   ; $F839 - Spare for the future.
        jmp     spare_handler   ; $F83C - Spare for the future.
        jmp     spare_handler   ; $F83F - Spare for the future.

;
; User code has requested a warm start of the computer.
;
req_warm_start:
        cld
        sei
        jmp     warm_start

;
; User code has requested a cold start of the computer.
;
req_cold_start:
        lda     #0
        sta     H_CHKS      ; Zero the checksums to force a cold start.
        sta     H_ICHKS

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
; Determine if we have a cold or warm start.
;
        ldx     #H_CHKS-H_IRQ-1
        lda     #0
verify_irq_checksum:
        clc
        adc     H_IRQ,x
        dex
        bpl     verify_irq_checksum
        cmp     H_CHKS
        bne     cold_start
        eor     #$FF
        cmp     H_ICHKS
        beq     warm_start
;
; Perform a cold start of the system.
;
cold_start:
;
; Clear the zero page and stack so that they are in a known state.
;
; Having zero bytes on the stack means that an errant "RTS" is likely to
; jump to address $0001 in memory and most likely execute a "BRK".
;
        ldx     #0
        txa
clear_zero_page_and_stack:
        sta     $0000,x
        sta     $0100,x
        inx
        bne     clear_zero_page_and_stack
;
; Save the stack pointer.
;
        tsx
        stx     REG_SP
;
; Set the default PC and examine addresses on a cold start.
;
        lda     #<DEF_PC
        sta     REG_PC
        sta     REG1
        lda     #>DEF_PC
        sta     REG_PC+1
        sta     REG1+1
;
; Reset the saved status flags to default.
;
        lda     #$20
        sta     REG_P
;
; Set up the default interrupt and reset vectors.
;
        lda     #<default_irq
        sta     H_IRQ
        sta     H_NMI
        lda     #>default_irq
        sta     H_IRQ+1
        sta     H_NMI+1
        lda     #<break
        sta     H_BREAK
        lda     #>break
        sta     H_BREAK+1
;
; Check if BASIC (or some other auto-run program) is in ROM.
;
        ldy     $E000       ; If BASIC is in ROM, it starts at $E000.
        cpy     #$20        ; We expect a JSR or JMP instruction.
        beq     have_basic
        cpy     #$4C
        bne     no_basic
have_basic:
        lda     #$03        ; Set the BASIC warm start address as "reset".
        ldx     #$E0
        sta     H_RESET
        stx     H_RESET+1
        jsr     calc_irq_checksum
        jsr     clear_display
    .ifdef init_hardware
        jsr     init_hardware
    .endif
        cli
        jmp     $E000       ; Cold start of BASIC.
;
; No BASIC, so set the warm start address to "monitor_reset".
;
no_basic:
        lda     #<monitor_reset
        ldx     #>monitor_reset
        sta     H_RESET
        stx     H_RESET+1
        jsr     calc_irq_checksum
;
; Perform a warm start of the system.
;
warm_start:
        jsr     clear_display
    .ifdef init_hardware
        jsr     init_hardware
    .endif
;
; Jump to the user-supplied reset vector.
;
        cli
        jmp     (H_RESET)

;
; Clear the front panel display.
;
clear_display:
        pha
        jsr     FP_CLEAR        ; Set every segment to off.
        lda     #FP_DISP_1      ; Home the cursor.
        sta     D_POSN
        lda     #$20            ; Update the shadow buffer in the zero page.
        sta     DISPLAY
        sta     DISPLAY+1
        sta     DISPLAY+2
        sta     DISPLAY+3
        sta     DISPLAY+4
        sta     DISPLAY+5
        pla
spare_handler:
        rts

;
; Refresh the display from the DISPLAY buffer in case a user program has
; overwritten it.  Preserves A, X, and Y.
;
refresh_display:
    .ifdef CPU_65C02
        pha
        phx
    .else
        pha
        txa
        pha
    .endif
        ldx     #FP_DISP_1
        lda     DISPLAY
        jsr     FP_DRAW_CHAR
        lda     DISPLAY+1
        jsr     FP_DRAW_CHAR
        lda     DISPLAY+2
        jsr     FP_DRAW_CHAR
        lda     DISPLAY+3
        jsr     FP_DRAW_CHAR
        lda     DISPLAY+4
        jsr     FP_DRAW_CHAR
        lda     DISPLAY+5
        jsr     FP_DRAW_CHAR
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
; Move the cursor on the display.  Position 0..6 is in A where 6 indicates
; the insert position is just off the display to the right.  Values greater
; than 6 will be converted into 6.
;
; Destroys A.  Preserves X and Y.
;
move_cursor:
        cmp     #6
        bcc     move_cursor_ok
        lda     #6
move_cursor_ok:
        asl     a
        asl     a
        asl     a
        sta     D_POSN
        rts

;
; Draw the 16-bit hexadecimal word in A:Y at the current location
; on the display.  A is the high byte.  Destroys A.  Preserves X and Y.
;
draw_word:
        jsr     draw_byte
        tya
        ; Fall through to the next subroutine.

;
; Draw the hexadecimal byte in A at the current location on the display.
; Destroys A.  Preserves X and Y.
;
draw_byte:
        pha
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        jsr     draw_nibble_2
        pla
        ; Fall through to the next subroutine.

;
; Draw the hexadecimal nibble in the low 4 bits of A at the current
; location on the display.  Destroys A.  Preserves X and Y.
;
draw_nibble:
        and     #$0F
draw_nibble_2:
        ora     #$30
        cmp     #$3A
        bcc     draw_char
        adc     #6
        ; Fall through to the next subroutine.

;
; Draw the ASCII character in A at the current location on the display,
; scrolling the display left if necessary.  Preserves A, X, and Y.
;
draw_char:
        sta     TEMP2
        cmp     #$20            ; Is this a control character?
        bcc     draw_ctrl_char
        cmp     #$7F            ; DEL deletes the character under the cursor.
        beq     delete_char
    .ifdef CPU_65C02
        phx
    .else
        txa
        pha
    .endif
        lda     D_POSN
        cmp     #FP_DISP_6+1
        bcc     draw_char_ok
        lda     DISPLAY+1       ; Scroll the display left by one character.
        sta     DISPLAY
        lda     DISPLAY+2
        sta     DISPLAY+1
        lda     DISPLAY+3
        sta     DISPLAY+2
        lda     DISPLAY+4
        sta     DISPLAY+3
        lda     DISPLAY+5
        sta     DISPLAY+4
        lda     #$20
        sta     DISPLAY+5
        jsr     refresh_display
        lda     #FP_DISP_6
draw_char_ok:
        pha
        lsr     a
        lsr     a
        lsr     a
        tax
        lda     TEMP2
        sta     DISPLAY,x
    .ifdef CPU_65C02
        plx
    .else
        pla
        tax
        lda     TEMP2
    .endif
        jsr     FP_DRAW_CHAR
        stx     D_POSN
    .ifdef CPU_65C02
        plx
    .else
        pla
        tax
    .endif
draw_done:
        lda     TEMP2
draw_exit:
        rts
draw_ctrl_char:
        cmp     #$08                ; Backspace moves back one position.
        beq     backspace
        cmp     #$1F                ; CTRL-_ inserts a space.
        beq     insert_char
        cmp     #$0D                ; CR, LF, and FF clear the display.
        beq     draw_clear
        cmp     #$0A
        beq     draw_clear
        cmp     #$0C
        bne     draw_exit
draw_clear:
        jmp     clear_display
backspace:
        lda     D_POSN
        beq     draw_done
        sec
        sbc     #8
        sta     D_POSN
        lda     TEMP2
        rts
delete_char:
    .ifdef CPU_65C02
        phx
    .else
        txa
        pha
    .endif
        ldx     D_POSN
delete_char_loop:
        cpx     #FP_DISP_6
        bcs     delete_char_done
        lda     DISPLAY+1,x
        sta     DISPLAY,x
        txa
        clc
        adc     #8
        tax
        bne     delete_char_loop
delete_char_done:
        lda     #$20
        sta     DISPLAY+5
    .ifdef CPU_65C02
        plx
    .else
        pla
        tax
    .endif
        lda     TEMP2
        jmp     refresh_display
insert_char:
    .ifdef CPU_65C02
        phx
        phy
    .else
        txa
        pha
        tya
        pha
    .endif
        ldx     D_POSN
        lda     #$20
insert_char_loop:
        cpx     #FP_DISP_6+1
        bcs     insert_char_done
        ldy     DISPLAY,x
        sta     DISPLAY,x
        txa
        clc
        adc     #8
        tax
        tya
    .ifdef CPU_65C02
        bra     insert_char_loop
    .else
        jmp     insert_char_loop
    .endif
insert_char_done:
    .ifdef CPU_65C02
        ply
        plx
    .else
        pla
        tay
        pla
        tax
    .endif
        lda     TEMP2
        jmp     refresh_display

;
; Draw a NUL-terminated string on the display starting at the current
; location and scrolling left as needed.  The pointer to the string is in
; A:Y on entry where A is the high byte.  Preserves A, X, and Y.
; There is a maximum of 256 characters in the string.  NUL will be assumed
; after that.
;
draw_string:
        sty     REG2
        sta     REG2+1
        ldy     #0
draw_string_loop:
        lda     (REG2),y
        beq     draw_string_end
        jsr     draw_char
        iny
        bne     draw_string_loop
draw_string_end:
        ldy     REG2
        lda     REG2+1
        rts

;
; Jump to "REG_PC" after restoring all registers except SP.
;
jump_to_pc:
        lda     REG_P
        pha
        lda     REG_A
        ldx     REG_X
        ldy     REG_Y
        plp
        jmp     (REG_PC)
;
; Return to the monitor due to a "RTS" instruction in the subroutine
; that was called by the "D" / "Do" function.
;
; Saves everything except "PC" because the top of stack will not
; necessarily be a return address.  Preserve the previous "PC" value.
;
return_to_monitor:
        sta     REG_A
        stx     REG_X
        sty     REG_Y
        php
        pla
        sta     REG_P
        tsx
        stx     REG_SP
        cld                 ; Fix the status flags just in case.
        cli
        jsr     FP_WAIT_KEY ; Wait for a keypress before continuing.
        cmp     #K_FUNC
        beq     ask_for_function
        jmp     monitor

;
; Entry to the monitor at reset time.  Display "CPU UP" and wait for a key.
; Then jump into the monitor proper.
;
monitor_reset:
        lda     #>reset_msg
        ldy     #<reset_msg
        jsr     draw_string
        jsr     FP_WAIT_KEY
        cmp     #K_FUNC
        beq     ask_for_function
        jmp     monitor

;
; Wait for a keypress and then enter the machine monitor.
; Avoids the display being cleared so that the last thing the
; program did is still on the display.
;
wait_enter:
        php
        pha
        cld
        cli
        jsr     FP_WAIT_KEY
        pla
        plp
        ; Fall through to the next subroutine.

;
; Save the caller's registers and enter the machine monitor.
;
enter_monitor:
        php
        cld
        sta     REG_A
        pla
        sta     REG_P
        pla
        clc
        adc     #1      ; Turn the return address into an actual PC value.
        sta     REG_PC
        sta     REG1
        pla
        adc     #0
        sta     REG_PC+1
        sta     REG1+1
        stx     REG_X
        sty     REG_Y
        tsx
        stx     REG_SP
        cli
        ; Fall through to the next subroutine.

;
; The machine monitor.
;
monitor:
;
; Examine the data at "PC" and display it on-screen.
;
        jsr     examine
;
monitor_loop:
        lda     #2
        sta     M_TEMP
;
monitor_key:
        jsr     FP_WAIT_KEY
        cmp     #K_FUNC
        beq     ask_for_function
        cmp     #K_NEXT
        beq     examine_next
        cmp     #K_PREV
        beq     examine_prev
        jsr     change              ; Change the current byte.
        dec     M_TEMP              ; Any digits left in this byte?
        beq     examine_next        ; If not, advance to the next address.
        bne     monitor_key
;
; Examine the next memory location.
;
examine_next:
        inc     REG1
        bne     examine_next_2
        inc     REG1+1
examine_next_2:
        jsr     examine
        jmp     monitor_loop
;
; Examine the previous memory location.
;
examine_prev:
        lda     REG1
        bne     examine_prev_2
        dec     REG1+1
examine_prev_2:
        dec     REG1
        jsr     examine
        jmp     monitor_loop

;
; Ask the user for a function.
;
ask_for_function:
        lda     #>function_msg
        ldy     #<function_msg
        jsr     draw_string
ask_for_function_2:
        jsr     FP_WAIT_KEY
        cmp     #K_FUNC
        beq     ask_for_function_2
        bcs     goto_monitor    ; "Next" or "Prev" return to the default mode.
        cmp     #K_EXAM         ; "E" / "Examine" changes the examine address.
        beq     examine_address
        cmp     #K_REGS         ; "A" / "Registers" inspects the CPU registers.
        beq     goto_inspect_registers
        cmp     #K_DO           ; "D" / "Do" to start running from PC onwards.
        beq     do_run
        cmp     #K_STEP         ; "5" / "Single-Step" to step through the code.
        beq     do_step
goto_monitor:
        jmp     monitor
goto_inspect_registers:
        jmp     inspect_registers
do_step:
        jmp     single_step

;
; Examine mode - ask for a new address.
;
examine_address:
        jsr     clear_display
        lda     #$45            ; Print "E " before the address.
        jsr     draw_char
        lda     #$20
        jsr     draw_char
        ldy     REG1            ; Print the current address.
        lda     REG1+1
        jsr     draw_word
        jsr     FP_WAIT_KEY
        cmp     #K_NEXT         ; "Next/"Prev" goes back to examine the data.
        beq     monitor
        cmp     #K_PREV
        beq     goto_monitor
        cmp     #K_FUNC
        beq     ask_for_function ; "Func" quits examine address mode.
        jsr     to_hex          ; Convert into hexadecimal.
        asl     REG1            ; REG1 = REG1 * 16 + digit
        rol     REG1+1
        asl     REG1
        rol     REG1+1
        asl     REG1
        rol     REG1+1
        asl     REG1
        rol     REG1+1
        ora     REG1
        sta     REG1
        jmp     examine_address

;
; Do the program starting at the PC.  The PC value can be modified
; before "Next" or "Prev" is pressed to start running the code.
;
do_run_loop:
        lda     #$64            ; "d"
        jsr     draw_char
        lda     #$EF            ; "o."
        jsr     draw_char
        ldy     REG_PC          ; Display the current PC.
        lda     REG_PC+1
        jsr     draw_word
        jsr     FP_WAIT_KEY
        cmp     #K_FUNC
        beq     ask_for_function
        cmp     #K_NEXT         ; "Next" or "Prev" starts running.
        beq     do_run_2
        cmp     #K_PREV
        beq     do_run_2
        jsr     to_hex          ; PC = PC * 16 + digit.
        jsr     update_pc
do_run:
        lda     #FP_DISP_1
        sta     D_POSN
        jmp     do_run_loop
;
; Push the address of "return_to_monitor" on the stack to jump back
; into the monitor if the program executes an "RTS" instruction.
;
do_run_2:
        lda     #>(return_to_monitor-1)
        pha
        lda     #<(return_to_monitor-1)
        pha
        jsr     clear_display
        jmp     jump_to_pc

;
; Inspect or modify the registers.
;
inspect_registers:
        lda     #0
        sta     M_TEMP          ; Number of the register to inspect.
inspect_next:
        lda     #FP_DISP_1
        sta     D_POSN
        lda     M_TEMP
        asl     a
        tax
        lda     reg_names,x     ; Display the name of the register.
        jsr     draw_char
        lda     reg_names+1,x
        jsr     draw_char
        ldx     M_TEMP
        cpx     #5
        beq     inspect_pc
        lda     #$20
        jsr     draw_char
        jsr     draw_char
        lda     REG_A,x         ; Display the register's value.
        jsr     draw_byte
modify_register:
        jsr     FP_WAIT_KEY
        cmp     #K_FUNC
        beq     goto_ask_for_function
        cmp     #K_NEXT
        beq     next_register
        cmp     #K_PREV
        beq     prev_register
        ldx     M_TEMP
        jsr     to_hex          ; Convert the digit into hexadecimal.
        cpx     #5              ; Program counter needs special 16-bit handling.
        beq     modify_pc
        asl     REG_A,x         ; value = value * 16 + digit
        asl     REG_A,x
        asl     REG_A,x
        asl     REG_A,x
        ora     REG_A,x
        sta     REG_A,x
        cpx     #4              ; Did we modify the stack pointer?
        bne     inspect_next
        tax                     ; Update the real SP register to match.
        txs
        jmp     inspect_next
reg_names:
        db      "A P X Y SPP",$C3
next_register:
        inc     M_TEMP
        lda     M_TEMP
        cmp     #6
        bcc     inspect_next
        lda     #0
        sta     M_TEMP
        beq     inspect_next
prev_register:
        dec     M_TEMP
        lda     M_TEMP
        bpl     inspect_next
        lda     #5
        sta     M_TEMP
        bne     inspect_next
inspect_pc:
        ldy     REG_PC
        lda     REG_PC+1
        jsr     draw_word
        jmp     modify_register
modify_pc:
        jsr     update_pc
        jmp     inspect_next
goto_ask_for_function:
        jmp     ask_for_function

;
; Change the byte at "REG1" by shifting in a new hexadecimal digit.
; If "REG1" is pointing to ROM, then this won't have any effect.
;
change:
        jsr     to_hex
        sta     TEMP1+1
        ldy     #0
        lda     (REG1),y
        asl     a
        asl     a
        asl     a
        asl     a
        ora     TEMP1+1
        sta     (REG1),y
        ; Fall through to the next subroutine to display the new value.

;
; Examine the memory at "PC" and display the data byte on the display.
;
examine:
        lda     #FP_DISP_1
        sta     D_POSN
        ldy     REG1
        lda     REG1+1
        jsr     draw_word
        ldx     D_POSN          ; Add a decimal point to the last
        dex                     ; character of the address field to act
        lda     #0              ; as a separator between address and data.
        sta     FP_ADDR,x
        ldy     #0
        lda     (REG1),y
        jmp     draw_byte

;
; Convert an ASCII character in A 0..9,A-F into hexadecimal, also in A.
;
to_hex:
        sec
        sbc     #$30
        cmp     #$0A
        bcc     to_hex_done
        sbc     #7
to_hex_done:
        rts

;
; Messages.
;
reset_msg:
        .db     "CPU UP", 0
function_msg:
        db      "Func  ",0

;
; Update "REG_PC" by shifting in the hexadecimal digit in A.
;
update_pc:
        asl     REG_PC
        rol     REG_PC+1
        asl     REG_PC
        rol     REG_PC+1
        asl     REG_PC
        rol     REG_PC+1
        asl     REG_PC
        rol     REG_PC+1
        ora     REG_PC
        sta     REG_PC
        rts

;
; Set an interrupt or reset handler in the zero page to the address A:Y
; where A is the high byte of the pointer.  If A:Y is zero, then revert
; back to the default handler.
;
; X is the offset of the handler in the zero page:
;       0       IRQ handler.
;       2       BREAK handler.
;       4       NMI handler.
;       6       Reset handler.
;
; Preserves A, X, and Y.
;
set_handler:
        php
        sei
        pha
        sty     H_IRQ,x
        sta     H_IRQ+1,x
        tya
        ora     H_IRQ+1,x
        bne     set_handler_done
        cpx     #0
        beq     set_handler_default_irq
        cpx     #4
        beq     set_handler_default_irq
        cpx     #2
        beq     set_handler_default_break
        lda     $E000
        cmp     #$20
        beq     set_handler_basic
        cmp     #$4C
        beq     set_handler_basic
        lda     #<monitor_reset
        sta     H_IRQ,x
        lda     #>monitor_reset
        sta     H_IRQ+1,x
        bne     set_handler_done
set_handler_basic:
        lda     #$03
        sta     H_IRQ,x
        lda     #$E0
        sta     H_IRQ+1,x
        bne     set_handler_done
set_handler_default_irq:
        lda     #<default_irq
        sta     H_IRQ,x
        lda     #>default_irq
        sta     H_IRQ+1,x
        bne     set_handler_done
set_handler_default_break:
        lda     #<break
        sta     H_IRQ,x
        lda     #>break
        sta     H_IRQ+1,x
set_handler_done:
        jsr     calc_irq_checksum
        pla
        plp
        rts
;
; Re-calculate the interrupt and reset handler checksum.
;
calc_irq_checksum:
    .ifdef CPU_65C02
        phx
    .else
        txa
        pha
    .endif
        ldx     #H_CHKS-H_IRQ-1
        lda     #0
calc_irq_checksum_loop:
        clc
        adc     H_IRQ,x
        dex
        bpl     calc_irq_checksum_loop
        sta     H_CHKS
        eor     #$FF
        sta     H_ICHKS
    .ifdef CPU_65C02
        plx
    .else
        pla
        tax
    .endif
        rts

;
; NMI handler.
;
nmi_handler:
        jmp     (H_NMI)

;
; Default BREAK handler.
;
break:
;
; Save all registers.
;
        sta     REG_A
        pla
        sta     REG_P
        pla
        sec
        sbc     #2              ; "BRK" address is two positions back.
        sta     REG_PC
        sta     REG1
        pla
        sbc     #0
        sta     REG_PC+1
        sta     REG1+1
        stx     REG_X
        sty     REG_Y
        tsx
        stx     REG_SP
        cli
;
; Display the break address on the display.
;
display_break:
        jsr     clear_display
        lda     #$62            ; "b"
        jsr     draw_char
        lda     #$F2            ; "r."
        jsr     draw_char
        ldy     REG_PC
        lda     REG_PC+1
        jsr     draw_word
;
; Wait for a key to be pressed and then enter the monitor.
;
        jsr     FP_WAIT_KEY
        cmp     #K_FUNC
        beq     break_function
        jmp     monitor
break_function:
        jmp     ask_for_function

;
; IRQBRK handler.
;
irqbrk_handler:
        sta     REG_AQ          ; Save A for later.
        cld                     ; Make sure that D is off.
        pla                     ; Copy the status register into A.
        pha
        and     #$10            ; Is the BREAK bit set?
        bne     do_break
        lda     REG_AQ          ; Restore A.
        jmp     (H_IRQ)         ; Jump to the user's IRQ handler.
do_break:
        lda     REG_AQ          ; Restore A.
        jmp     (H_BREAK)       ; Jump to the user's BREAK handler.

;
; Single-step the next instruction at "PC".
;
single_step:
        ldy     #0
        lda     (REG_PC),y      ; Fetch the opcode.
;
; Fetch the corresponding single-stepping rule.  There are two rules
; per byte in the table for even and odd opcodes.
;
        lsr     a
        tax
        lda     single_step_rules,x
        bcc     step_even_opcode
        lsr     a
        lsr     a
        lsr     a
        lsr     a
step_even_opcode:
        and     #$0F
        sta     M_TEMP          ; Rule is now in M_TEMP.
        tax
        lda     single_step_lengths,x
        sta     REG1            ; Instruction length is now in REG1.
        tay
;
; Copy the instruction to the zero page so it can be executed in isolation.
;
        dey
copy_instruction:
        lda     (REG_PC),y
        sta     STEPBUF,y
        dey
        bpl     copy_instruction
;
; Display the current "PC" value and the opcode byte.
;
        jsr     clear_display
        ldy     REG_PC
        lda     REG_PC+1
        jsr     draw_word
        ldx     D_POSN          ; Add a decimal point to the last
        dex                     ; character of the address field to act
        lda     #0              ; as a separator between address and data.
        sta     FP_ADDR,x
        lda     STEPBUF
        jsr     draw_byte
;
; Wait for a key to be pressed.  "Next" or "Prev" will step.
; Everything else will return to the monitor to examine "PC".
;
        jsr     FP_WAIT_KEY
        cmp     #K_NEXT
        beq     single_step_now
        cmp     #K_PREV
        beq     single_step_now
        ldx     REG_PC
        stx     REG1
        ldx     REG_PC+1
        stx     REG1+1
        cmp     #K_FUNC
        beq     single_step_func
        jmp     monitor
single_step_func:
        jmp     ask_for_function
;
; Update "PC" to skip over the current instruction.
;
single_step_now:
        lda     REG_PC
        clc
        adc     REG1
        sta     REG_PC
        lda     REG_PC+1
        adc     #0
        sta     REG_PC+1
;
; Follow up the instruction with jumps back into the monitor for normal
; execution and branching execution.
;
        ldy     REG1
        lda     #$4C
        sta     STEPBUF,y
        sta     STEPBUF+3,y
        lda     #<single_step_end
        sta     STEPBUF+1,y
        lda     #>single_step_end
        sta     STEPBUF+2,y
        lda     #<single_step_branch
        sta     STEPBUF+4,y
        lda     #>single_step_branch
        sta     STEPBUF+5,y
;
; Determine how to handle the single-stepping rule.
;
        ldx     M_TEMP
        lda     single_step_handlers_low-1,x
        sta     REG2
        lda     single_step_handlers_high-1,x
        sta     REG2+1
        jmp     (REG2)
;
single_step_handlers_low:
        .db     <step_normal            ; Rule 1
        .db     <step_normal            ; Rule 2
        .db     <step_normal            ; Rule 3
        .db     <step_illegal           ; Rule 4
        .db     <step_relative_branch   ; Rule 5
        .db     <step_indirect_jump     ; Rule 6
        .db     <step_jsr               ; Rule 7
        .db     <step_jmp               ; Rule 8
        .db     <step_rts               ; Rule 9
        .db     <step_rti               ; Rule 10
        .db     <step_indirect_x_jump   ; Rule 11
        .db     <step_relative_branch   ; Rule 12
        .db     <step_break             ; Rule 13
single_step_handlers_high:
        .db     >step_normal            ; Rule 1
        .db     >step_normal            ; Rule 2
        .db     >step_normal            ; Rule 3
        .db     >step_illegal           ; Rule 4
        .db     >step_relative_branch   ; Rule 5
        .db     >step_indirect_jump     ; Rule 6
        .db     >step_jsr               ; Rule 7
        .db     >step_jmp               ; Rule 8
        .db     >step_rts               ; Rule 9
        .db     >step_rti               ; Rule 10
        .db     >step_indirect_x_jump   ; Rule 11
        .db     >step_relative_branch   ; Rule 12
        .db     >step_break             ; Rule 13
;
; Single-step a relative branch.
;
step_relative_branch:
;
; Re-write the instruction to jump over the normal exit if the branch is taken.
;
        lda     STEPBUF+1
        sta     STEPBUF+8
        lda     #$03
        sta     STEPBUF+1
        ; Fall through to the next case.
;
; Single-step a normal instruction that doesn't need special handling.
;
; Restore all registers and jump to the patched code at "STEPBUF".
;
step_normal:
        ldx     REG_X
        ldy     REG_Y
        lda     REG_P
        pha
        lda     REG_A
        plp
        jmp     STEPBUF
;
; Single-step an illegal instruction.  The instruction is treated as a "NOP".
;
step_illegal .equ single_step
;
; Single-step an indirect jump with X offset.
;
step_indirect_x_jump:
        lda     REG_X               ; Add "X" to the indirect jump address.
        clc
        adc     STEPBUF+1
        sta     STEPBUF+1
        lda     STEPBUF+2
        adc     #0
        sta     STEPBUF+2
        ; Fall through to the next subroutine.
;
; Single-step an indirect jump.
;
step_indirect_jump:
        ldy     #0
        lda     (STEPBUF+1),y
        sta     REG_PC
        iny
        lda     (STEPBUF+1),y
        sta     REG_PC+1
        jmp     single_step
;
; Single-step a jump to subroutine.
;
step_jsr:
;
; If this is a call to a monitor routine, then call it directly rather
; than single-step into it.  Usually such routines draw characters on the
; display or wait for input.  Single-stepping monitor routines will act weird.
;
        lda     STEPBUF+2
        cmp     #$F8
        bcs     step_normal
        lda     REG_PC
        sbc     #0
        tax
        lda     REG_PC+1
        sbc     #0
        pha
    .ifdef CPU_65C02
        phx
    .else
        txa
        pha
    .endif
        ; Fall through to the next subroutine.
;
; Single-step an unconditional branch to a 16-bit address.
;
step_jmp:
        lda     STEPBUF+1
        sta     REG_PC
        lda     STEPBUF+2
        sta     REG_PC+1
        jmp     single_step
;
; Single-step a return from subroutine.
;
step_rts:
        pla
        clc
        adc     #1
        sta     REG_PC
        pla
        adc     #0
        sta     REG_PC+1
        jmp     single_step
;
; Single-step a return from interrupt.
;
step_rti:
        pla
        sta     REG_P
        pla
        sta     REG_PC
        pla
        sta     REG_PC+1
        jmp     single_step
;
; Single-step a "BRK" instruction.
;
step_break:
        lda     REG_PC          ; Back up to the location of the "BRK".
        sec
        sbc     #1
        sta     REG_PC
        lda     REG_PC+1
        sbc     #0
        sta     REG_PC+1
        jmp     display_break
;
; Continue execution after a normal instruction finishes single-stepping.
;
; Save all registers and then go around for the next instruction.
;
single_step_end:
        sta     REG_A
        stx     REG_X
        sty     REG_Y
        php
        pla
        sta     REG_P
        tsx
        stx     REG_SP
        cld
        cli
        jmp     single_step
;
; Continue execution after a branch instruction branches during single-stepping.
;
; Save all registers and perform the branch.
;
single_step_branch:
        sta     REG_A
        stx     REG_X
        sty     REG_Y
        php
        pla
        sta     REG_P
        tsx
        stx     REG_SP
        cld
        cli
        lda     STEPBUF+8
        bmi     branch_backwards
        clc
        adc     REG_PC
        sta     REG_PC
        lda     REG_PC+1
        adc     #0
        sta     REG_PC+1
        jmp     single_step
branch_backwards:
        clc
        adc     REG_PC
        sta     REG_PC
        lda     REG_PC+1
        adc     #$FF
        sta     REG_PC+1
        jmp     single_step

;
; Include the table of single-stepping rules.
;
        .include "steprules.s"
;
; Map single-stepping rules to the corresponding instruction length.
;
single_step_lengths:
        .db     1, 1, 2, 3, 1, 2, 3, 3, 3, 1, 1, 3, 2, 1

;
; Include the front panel driver code.
;
FP_TEMP     .equ TEMP1
FP_TEMP2    .equ REG2+1
        .include "fp_driver.s"

        .org    $FFF9
;
; Default IRQ or NMI handler.
;
default_irq:
        rti

;
; Interrupt and reset vectors.
;
        .dw     nmi_handler
        .dw     reset
        .dw     irqbrk_handler
