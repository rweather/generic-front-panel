
This directory contains driver code for 6502-based machines in "fp\_driver.s".

The "hello.s" example is designed to work with
[Ben Eater's 6502 Breadboard Computer](https://eater.net/6502), with the
front panel placed at address $4000 in memory.  The front panel should be
wired up to the breadboard computer as follows:

<img alt="Wiring for 6502" src="wiring.png"/>

The example scrolls "HELLORLD!" followed by the printable ASCII characters
across the display from right to left.

Press any key except RESET to stop the scrolling message.  Keys pressed
after that (except RESET) will be shown on the display, scrolling in from
the right.  This allows all keys on the keypad to be tested.  Press RESET
to start again with the scrolling message.
