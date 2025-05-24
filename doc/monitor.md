Front Panel Machine Monitor
===========================

This page describes the operation of the 6502 machine monitor for the
front panel.  The code is located at $F800 in ROM and is just a little
under 2K in size.  The code can be found in the "src/6502/monitor.s"
file in this repository.

## Inspiration

The design of this monitor was inspired by the [Heathkit ET-3400](http://dunfield.classiccmp.org/heath/index.htm).

The Heathkit had 16 hexadecimal keys plus a "Reset" key.  Each of the
hexadecimal keys was assigned a monitor function: "E" for "EXAM" (examine
memory), "F" for "FWD" (move forward one address in memory),
"C" for "CHAN" (change memory), and so on.

The user would press "Reset", select a monitor function, and then type
hexadecimal digits to enter addresses or data, or to run programs.
To select another command, the user would press "Reset" again and repeat.

I made a few adjustments to the workflow to make program entry faster,
but the core idea of the Heathkit's monitor is intact.

## Keypad

The keypad is laid out as follows:

      Func  Prev Next Reset
        C    D    E    F
        8    9    A    B
        4    5    6    7
        0    1    2    3

The "Func" key is used to select monitor functions.

## System Reset

When the system resets due to power on, or pressing the "Reset" button,
the display will show "CPU UP", just like the Heathkit:

<img src="led-cpu-up.png"/>

Press "Func" to enter the main function menu, or any other key to enter the
default examine/change mode.

## Main Function Menu

The Heathkit used "Reset" to enter the main function menu.  I instead
used one of the three command keys on the front panel.

Press "Func" at any time to enter the main function menu, which will show
"Func" on the display:

<img src="led-main-menu.png"/>

From here, the hexadecimal keypad can be used to select a function:

* "A" displays the accumulator and other registers.
* "C" enters the default examine / change mode.
* "D" (or "do") starts executing programs.
* "E" changes the examine address.

All other keys act the same as "C".  They may be assigned functions
in the future.  The Heathkit also had functions for setting breakpoints and
single-stepping through code.

## Examine / Change

The default function of the monitor is Examine / Change.  The current
address is displayed on-screen, together with the byte value at
that address:

<img src="led-examine-mem.png"/>

The decimal point acts as a separator between the address and data,
making it easier to see which is which at a glance.

"Next" will move to the next address in memory, and "Prev" will move to the
previous address in memory.

Enter two hexadecimal digits to change the current byte and move onto the
next address in memory.  This allows programs to be entered very quickly.

Upon power up, the starting address is set to $0300 in RAM.  A later
soft reset will retain the current address.

## Change Examine Address

Press "Func" and then "E" to modify the address that is being used to
examine memory.  The current address is displayed:

<img src="led-examine-addr.png"/>

Press hexadecimal digit keys to modify the address.  Each new digit is
entered at the right of the address, shifting the other digits left.
This is the result after pressing "7" and "8" from the previous state:

<img src="led-examine-addr2.png"/>

Press either "Next" or "Prev" to return to the default Examine / Change
mode at the newly selected address.

## Inspecting and Modifying Registers

Press "Func" and then "A" to inspect the registers starting with the
accumulator.  Use "Next" and "Prev" to move to another register, or
enter hexadecimal digits to alter the current register.

<img src="led-reg-A.png"/>

<img src="led-reg-P.png"/>

<img src="led-reg-X.png"/>

<img src="led-reg-Y.png"/>

<img src="led-reg-SP.png"/>

<img src="led-reg-PC.png"/>

## Do Mode

Press "Func" and then "D" to enter "do" mode.  The current "PC" value is
displayed on the screen:

<img src="led-do-mode.png"/>

Use hexadecimal digits to modify the value of "PC", and then press
"Next" or "Prev" to start executing the code at the address.

When the code returns with a "RTS" instruction, the system will pause
waiting for a key to be pressed.  This allows the user to see the last
thing that the program printed on the display before erasing it and
re-entering the monitor.

## Breakpoints

If the program encounters a $00 or "BRK" instruction, it will enter
the monitor and display the address at which the breakpoint occurred:

<img src="led-breakpoint.png"/>

Press "Func" to go to the main function menu, or any other key to
enter examine / change mode at the breakpoint address.

The monitor doesn't currently offer a method to set and remove breakpoints
like the Heathkit did.  You can however set your own breakpoints by
putting a $00 byte in the code and remembering what the previous byte was
to restore it later.

## Acknowledgements

7-segment display images were generated with the online
[LCD Display Screenshot Generator](https://avtanski.net/projects/lcd/).
