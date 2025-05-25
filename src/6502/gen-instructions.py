#!/usr/bin/python
#
# Generate the table that the monitor uses for single-stepping rules.

import sys

variants = sys.argv[1:]

file = open('instructions.txt', 'r')
lines = file.readlines()
file.close()

# Parse the instruction information.
names = []
modes = []
opcodes = {}
for line in lines:
    fields = line.strip().split(';')
    opcode = int(fields[0], 16)
    name = fields[1]
    mode = fields[2]
    if len(fields) > 3:
        variant = fields[3]
    else:
        variant = '6502'
    if name in names:
        name_index = names.index(name)
    else:
        name_index = len(names)
        names.append(name)
    opcodes[opcode] = {
        'opcode': opcode,
        'name': name,
        'mode': mode,
        'index': name_index,
        'variant': variant
    }
num_names = len(names)

# Header.
print("; Generated automatically from instructions.txt.")
print("")

# Numbers for the single-stepping rules.  Values less than or equal to 3
# give a length for instructions that don't need special handling.
opmodes = {
    'ill':          0x04,
    'imp':          0x01,
    'imm':          0x02,
    'abs':          0x03,
    'abs_X':        0x03,
    'abs_Y':        0x03,
    'X_ind':        0x02,
    'ind_Y':        0x02,
    'zpg':          0x02,
    'zpg_X':        0x02,
    'zpg_Y':        0x02,
    'rel':          0x05,
    'ind':          0x06,
    'jsr':          0x07,
    'jmp':          0x08,
    'rts':          0x09,
    'rti':          0x0A,
    'ind_zpg':      0x02,
    'ind_abs_X':    0x0B,
    'bit_zpg':      0x02,
    'bit_rel':      0x0C,
    'brk':          0x0D
}

# Generate single-stepping rules.
def gen_rules(is_c02):
    rule = 0
    phase = 0
    for opcode in range(256):
        rule = int(rule / 16)
        if opcode in opcodes:
            opc = opcodes[opcode]
            if not is_c02 and opc['variant'] != '6502':
                # Illegal instruction in 6502, but valid in 65C02.
                rule += 0x40
            elif len(opc['mode']) > 0:
                # Instruction with a complex mode.
                mode = opc['mode'].replace(',', '_').replace('#', 'imm')
                if mode == "A":
                    mode = "imp"
                rule += opmodes[mode] * 16
            else:
                # Implicit instruction with no operands.
                rule += 0x10
        else:
            # Illegal instruction.
            rule += 0x40
        if (opcode % 2) == 1:
            if phase == 0:
                print("        .db $%02X" % rule, end='')
            else:
                print(", $%02X" % rule, end='')
            phase = phase + 1
            if phase >= 8:
                print("")
                phase = 0
            rule = 0

# Dump the single-stepping rules for all opcodes.
print("single_step_rules:")
print("    .ifdef CPU_65C02")
gen_rules(True)
print("    .else")
gen_rules(False)
print("    .endif")
