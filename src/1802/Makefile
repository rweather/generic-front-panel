
.PHONY: all clean

A18 = a18

all: hello.bin

hello.bin: hello.asm fp_driver.asm
	$(A18) hello.asm -l hello.lst -b hello.bin

clean:
	rm -f *.bin *.lst
