
INCLUDE_DIR = .

VASM = vasm6502_oldstyle
VASM_OPTIONS = -quiet -dotdir -Fbin -I$(INCLUDE_DIR)

INCLUDES = fp_driver.s

all: hello.bin

hello.bin: hello.s $(INCLUDES)
	$(VASM) $(VASM_OPTIONS) -DCPU_65C02 -c02 -L hello.lst -o hello.bin hello.s

clean:
	rm -f hello.bin hello.lst
