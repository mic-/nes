include memory.e

-- Addressing modes
constant
    IMPLIED    = 0,
    ZEROPAGE   = 1,
    ZEROPAGE_X = 2,
    ZEROPAGE_Y = 3,
    ABSOLUTE   = 4,
    ABSOLUTE_X = 5,
    ABSOLUTE_Y = 6,
    INDIRECT   = 7,
    INDIRECT_X = 8,
    INDIRECT_Y = 9,
    IMMEDIATE  = 10,
    RELATIVE   = 11

constant MNEMONICS = {
{"BRK",IMPLIED},
{"ORA",INDIRECT_X},
{},
{},
{},
{"ORA",ZEROPAGE},
{"ASL",ZEROPAGE},
{},
{"PHP",IMPLIED},
{"ORA",IMMEDIATE},
{"ASL",IMPLIED},
{},
{"NOP",ABSOLUTE},
{"ORA",ABSOLUTE},
{"ASL",ABSOLUTE},
{},
{"BPL",RELATIVE},
{"ORA",INDIRECT_Y},
{},
{},
{"NOP",ZEROPAGE_X},
{"ORA",ZEROPAGE_X},
{"ASL",ZEROPAGE_X},
{},
{"CLC",IMPLIED},
{"ORA",ABSOLUTE_Y},
{"NOP",IMPLIED},
{},
{"NOP",ABSOLUTE_X},
{"ORA",ABSOLUTE_X},
{"ASL",ABSOLUTE_X},
{},

{"JSR",ABSOLUTE},
{"AND",INDIRECT_X},
{},
{},
{"BIT",ZEROPAGE},
{"AND",ZEROPAGE},
{"ROL",ZEROPAGE},
{},
{"PLP",IMPLIED},
{"AND",IMMEDIATE},
{"ROL",IMPLIED},
{},
{"BIT",ABSOLUTE},
{"AND",ABSOLUTE},
{"ROL",ABSOLUTE},
{},
{"BMI",RELATIVE},
{"AND",INDIRECT_Y},
{},
{},
{},
{"AND",ZEROPAGE_X},
{"ROL",ZEROPAGE_X},
{},
{"SEC",IMPLIED},
{"AND",ABSOLUTE_Y},
{},
{},
{},
{"AND",ABSOLUTE_X},
{"ROL",ABSOLUTE_X},
{},

--40
{"RTI",IMPLIED},
{"EOR",INDIRECT_X},
{},
{},
{},
{"EOR",ZEROPAGE},
{"LSR",ZEROPAGE},
{},
{"PHA",IMPLIED},
{"EOR",IMMEDIATE},
{"LSR",IMPLIED},
{"ASR",IMMEDIATE},
{"JMP",ABSOLUTE},
{"EOR",ABSOLUTE},
{"LSR",ABSOLUTE},
{},
{"BVC",RELATIVE},
{"EOR",INDIRECT_Y},
{},
{},
{},
{"EOR",ZEROPAGE_X},
{"LSR",ZEROPAGE_X},
{},
{"CLI",IMPLIED},
{"EOR",ABSOLUTE_Y},
{},
{},
{},
{"EOR",ABSOLUTE_X},
{"LSR",ABSOLUTE_X},
{},

--60
{"RTS",IMPLIED},
{"ADC",INDIRECT_X},
{},
{},
{},
{"ADC",ZEROPAGE},
{"ROR",ZEROPAGE},
{},
{"PLA",IMPLIED},
{"ADC",IMMEDIATE},
{"ROR",IMPLIED},
{},
{"JMP",INDIRECT},
{"ADC",ABSOLUTE},
{"ROR",ABSOLUTE},
{},
{"BVS",RELATIVE},
{"ADC",INDIRECT_Y},
{},
{},
{},
{"ADC",ZEROPAGE_X},
{"ROR",ZEROPAGE_X},
{},
{"SEI",IMPLIED},
{"ADC",ABSOLUTE_Y},
{},
{},
{},
{"ADC",ABSOLUTE_X},
{"ROR",ABSOLUTE_X},
{},

--80
{},
{"STA",INDIRECT_X},
{},
{},
{"STY",ZEROPAGE},
{"STA",ZEROPAGE},
{"STX",ZEROPAGE},
{},
{"DEY",IMPLIED},
{},
{"TXA",IMPLIED},
{},
{"STY",ABSOLUTE},
{"STA",ABSOLUTE},
{"STX",ABSOLUTE},
{},
{"BCC",RELATIVE},
{"STA",INDIRECT_Y},
{},
{},
{"STY",ZEROPAGE_X},
{"STA",ZEROPAGE_X},
{"STX",ZEROPAGE_Y},
{},
{"TYA",IMPLIED},
{"STA",ABSOLUTE_Y},
{"TXS",IMPLIED},
{},
{},
{"STA",ABSOLUTE_X},
{},
{},

--A0
{"LDY",IMMEDIATE},
{"LDA",INDIRECT_X},
{"LDX",IMMEDIATE},
{},
{"LDY",ZEROPAGE},
{"LDA",ZEROPAGE},
{"LDX",ZEROPAGE},
{},
{"TAY",IMPLIED},
{"LDA",IMMEDIATE},
{"TAX",IMPLIED},
{},
{"LDY",ABSOLUTE},
{"LDA",ABSOLUTE},
{"LDX",ABSOLUTE},
{},
{"BCS",RELATIVE},
{"LDA",INDIRECT_Y},
{},
{},
{"LDY",ZEROPAGE_X},
{"LDA",ZEROPAGE_X},
{"LDX",ZEROPAGE_Y},
{},
{"CLV",IMPLIED},
{"LDA",ABSOLUTE_Y},
{"TSX",IMPLIED},
{},
{"LDY",ABSOLUTE_X},
{"LDA",ABSOLUTE_X},
{"LDX",ABSOLUTE_Y},
{},

--C0
{"CPY",IMMEDIATE},
{"CMP",INDIRECT_X},
{},
{},
{"CPY",ZEROPAGE},
{"CMP",ZEROPAGE},
{"DEC",ZEROPAGE},
{},
{"INY",IMPLIED},
{"CMP",IMMEDIATE},
{"DEX",IMPLIED},
{},
{"CPY",ABSOLUTE},
{"CMP",ABSOLUTE},
{"DEC",ABSOLUTE},
{},
{"BNE",RELATIVE},
{"CMP",INDIRECT_Y},
{},
{},
{},
{"CMP",ZEROPAGE_X},
{"DEC",ZEROPAGE_X},
{},
{"CLD",IMPLIED},
{"CMP",ABSOLUTE_Y},
{},
{},
{},
{"CMP",ABSOLUTE_X},
{"DEC",ABSOLUTE_X},
{},

--E0
{"CPX",IMMEDIATE},
{"SBC",INDIRECT_X},
{},
{},
{"CPX",ZEROPAGE},
{"SBC",ZEROPAGE},
{"INC",ZEROPAGE},
{},
{"INX",IMPLIED},
{"SBC",IMMEDIATE},
{"NOP",IMPLIED},
{},
{"CPX",ABSOLUTE},
{"SBC",ABSOLUTE},
{"INC",ABSOLUTE},
{},
{"BEQ",RELATIVE},
{"SBC",INDIRECT_Y},
{},
{},
{},
{"SBC",ZEROPAGE_X},
{"INC",ZEROPAGE_X},
{},
{"SED",IMPLIED},
{"SBC",ABSOLUTE_Y},
{},
{},
{},
{"SBC",ABSOLUTE_X},
{"INC",ABSOLUTE_X},
{}}


constant ADDRESSING_NAMES = {
"",
"aa",
"aa,X",
"aa,Y",
"aaaa",
"aaaa,X",
"aaaa,Y",
"(aaaa)",
"(aa,X)",
"(aa),Y",
"#aa",
"<aa"
}



function disassemble_once(atom pc)
    atom save_pc
    integer op, i
    sequence s, t, ret

    save_pc = reg_PC
    reg_PC = pc

    op = fetch_byte()
    s = MNEMONICS[op+1]

    if not length(s) then
        ret = {sprintf("Illegal opcode ($%02x)",op), pc, reg_PC, op}
    else
        if s[2] = IMPLIED then
            t = s[1]
        elsif s[2] = ZEROPAGE then
            t = s[1] & sprintf(" $%02x", fetch_byte())
        elsif s[2] = ZEROPAGE_X then
            t = s[1] & sprintf(" $%02x,X", fetch_byte())
        elsif s[2] = ZEROPAGE_Y then
            t = s[1] & sprintf(" $%02x,Y", fetch_byte())
        elsif s[2] = ABSOLUTE then
            t = s[1] & sprintf(" $%04x", fetch_word())
        elsif s[2] = ABSOLUTE_X then
            t = s[1] & sprintf(" $%04x,X", fetch_word())
        elsif s[2] = ABSOLUTE_Y then
            t = s[1] & sprintf(" $%04x,Y", fetch_word())
        elsif s[2] = INDIRECT then
            t = s[1] & sprintf(" ($%04x)", fetch_word())
        elsif s[2] = INDIRECT_X then
            t = s[1] & sprintf(" ($%02x,X)", fetch_byte())
        elsif s[2] = INDIRECT_Y then
            t = s[1] & sprintf(" ($%02x),Y", fetch_byte())
        elsif s[2] = IMMEDIATE then
            t = s[1] & sprintf(" #$%02x", fetch_byte())
        elsif s[2] = RELATIVE then
            i = fetch_byte()
            if i > 127 then
                i -= 256
            end if
            t = s[1] & sprintf(" %04x", i+reg_PC)
        end if
        ret = {t, pc, reg_PC, op}
    end if

    reg_PC = save_pc

    return ret
end function


global function disassemble(atom pc, integer numOps)
    sequence code,s

    code = {}

    for i = 1 to numOps do
        s = disassemble_once(pc)
        code = append(code, {pc,s[1],s[4]})
        pc = s[3]
    end for
        
    return code
end function



global function instruction_name(integer op)
    sequence s

    s = MNEMONICS[op+1]
    if length(s) then
        s = s[1] & " " & ADDRESSING_NAMES[s[2]+1]
    else
        s = "Illegal opcode"
    end if

    return s
end function
