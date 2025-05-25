
INCLUDE_DIR = .

VASM = vasm6502_oldstyle
VASM_OPTIONS = -quiet -dotdir -Fbin -I$(INCLUDE_DIR)

INCLUDES = fp_driver.s

all: hello.bin monitor.bin

hello.bin: hello.s $(INCLUDES)
	$(VASM) $(VASM_OPTIONS) -DCPU_65C02 -c02 -L hello.lst -o hello.bin hello.s

monitor.bin: monitor.s $(INCLUDES) steprules.s
	$(VASM) $(VASM_OPTIONS) -DCPU_65C02 -DFILL_ROM -c02 -L monitor.lst -o monitor.bin monitor.s

steprules.s: gen-instructions.py instructions.txt
	python3 gen-instructions.py >steprules.s

clean:
	rm -f hello.bin hello.lst
	rm -f monitor.bin monitor.lst
