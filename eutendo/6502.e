-- A 6502 emulator in Euphoria
-- /Mic, 2003.2019

include memory.e
include debug.e

-- FLAGS
constant C_FLAG = 1,    -- carry
         Z_FLAG = 2,    -- zero
         I_FLAG = 4,    -- irq disable
         D_FLAG = 8,    -- decimal mode
         B_FLAG = 16,   -- break
                        -- (bit 5 is unused)
         V_FLAG = 64,   -- overflow
         N_FLAG = 128   -- negative
         

integer executed,address,operand,op,temp,condition,old_PC
global integer Carry,Zero,Interrupt,Decimal,Break,Overflow,Negative

-------------------------------------- OPCODES ------------------------------------------------------

procedure ADC_()
    integer val

    val = operand + reg_A + Carry

    Carry = (val > #FF)

    if (not and_bits(xor_bits(reg_A,operand),#80)) and and_bits(xor_bits(reg_A,val),#80) then
        Overflow = 1
    else
        Overflow = 0
    end if
    reg_A = and_bits(val,#FF)
    Negative = (reg_A >= #80)
    Zero = (reg_A = 0)
end procedure



procedure AND_()
    reg_A = and_bits(reg_A, operand)
    Negative = (reg_A >= #80)
    Zero = (reg_A = 0)
end procedure



procedure ASL_()
    operand = read_byte(address)
    operand += operand

    Carry = (operand > #FF)
    operand = and_bits(operand, #FF)
    write_byte(address, operand)

    Negative = (operand >= #80)
    Zero = (operand = 0)
end procedure


procedure CMP_()
    Carry = (operand >= 0)
    Negative = (operand < 0 or operand >= #80)
    Zero = (operand = 0)
end procedure


procedure DEC_()
    operand = read_byte(address)
    operand = and_bits(operand+#FF, #FF)

    write_byte(address,operand)

    Negative = (operand >= #80)
    Zero = (operand = 0)
end procedure


procedure EOR_()
    reg_A = xor_bits(reg_A, operand)
    Negative = (reg_A >= #80)
    Zero = (reg_A = 0)
end procedure



procedure INC_()
    operand = read_byte(address)
    operand = and_bits(operand+1, #FF)

    write_byte(address,operand)

    Negative = (operand >= #80)
    Zero = (operand = 0)
end procedure


procedure LSR_()
    operand = read_byte(address)

    Carry = and_bits(operand, 1)

    operand = floor(operand / 2)
    write_byte(address, operand)

    Negative = 0
    Zero = (operand = 0)
end procedure


procedure ORA_()
    reg_A = or_bits(reg_A, operand)
    Negative = (reg_A >= #80)
    Zero = (reg_A = 0)
end procedure



procedure ROL_()
    operand = read_byte(address)
    operand += operand + Carry
    if operand < #100 then
        Carry = 0
    else
        Carry = 1
        operand = and_bits(operand, #FF)
    end if

    write_byte(address,operand)

    Negative = (operand >= #80)
    Zero = (operand = 0)
end procedure


procedure ROR_()
    operand = read_byte(address)
    if Carry then
        operand += #100
    end if

    Carry = and_bits(operand, 1)

    operand = floor(operand / 2)
    write_byte(address,operand)

    Negative = (operand >= #80)
    Zero = (operand = 0)
end procedure


procedure Branch()
    if condition then
        if reg_PC < #C000 then
            address = peek(reg_PC+PRGROM1-#8000)
        else
            address = peek(reg_PC+PRGROM2-#C000)
        end if
        if address >= #80 then
            address -= #100
        end if
        reg_PC += address+1
    else
        reg_PC += 1
    end if
    cycle += 3.0 + (and_bits(reg_PC,#FF00) != and_bits(old_PC,#FF00))
end procedure

------------------------------------------------------------------------------------------------------


global procedure execute()
    -- Fetch opcode
    if reg_PC < #C000 then
        op = peek(reg_PC+PRGROM1-#8000)
    else
        op = peek(reg_PC+PRGROM2-#C000)
    end if
    reg_PC += 1

    switch op do
        -- BRK
        case #00 then
           push_word(reg_PC+1)
           temp = Carry+
                Zero*Z_FLAG+
                Interrupt*I_FLAG+
                Decimal*D_FLAG+
                B_FLAG+  -- B flag is always set on BRK
                32+
                Overflow*V_FLAG+
                Negative*N_FLAG
            push(temp)
            Interrupt = 1
            Break = 1
            reg_PC = read_word2(#FFFE)
            cycle += 7.0

        -- ORA (aa,X)
        case #01 then
            operand = read_byte(inx8pre())
            ORA_()
            cycle += 6.0

        -- SLO (aa,X)
        case #03 then
            cycle += 2.0

        -- NOP aa
        case #04 then
            cycle += 3.0

        -- JMP aaaa
        case #4C then
            if reg_PC < #C000 then
                address = PRGROM1+reg_PC-#8000
            else
                address = PRGROM2+reg_PC-#C000
            end if
            reg_PC = peek(address) + peek(address+1)*#100
            cycle += 3.0

        -- LDA aa
        case #A5 then
            if reg_PC < #C000 then
                reg_A = read_byte(peek(reg_PC+PRGROM1-#8000))
            else
                reg_A = read_byte(peek(reg_PC+PRGROM2-#C000))
            end if
            reg_PC += 1
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 3.0

        -- BEQ <aa
        case #F0 then
            old_PC = reg_PC
            if Zero then
                if reg_PC < #C000 then
                    address = peek(reg_PC+PRGROM1-#8000)
                else
                    address = peek(reg_PC+PRGROM2-#C000)
                end if
                if address >= #80 then
                    address -= #100
                end if
                reg_PC += address+1
            else
                reg_PC += 1
            end if
            cycle += 3.0 + (and_bits(reg_PC,#FF00) != and_bits(old_PC,#FF00))

        -- STA aa
        case #85 then
            if reg_PC < #C000 then
                address = peek(reg_PC+PRGROM1-#8000)
            else
                address = peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            write_byte(address, reg_A)
            cycle += 3.0

        -- BNE <aa
        case #D0 then
            old_PC = reg_PC
            if not Zero then
                if reg_PC < #C000 then
                    address = peek(reg_PC+PRGROM1-#8000)
                else
                    address = peek(reg_PC+PRGROM2-#C000)
                end if
                if address>=#80 then
                    address -= #100
                end if
                reg_PC += address+1
            else
                reg_PC += 1
            end if
            cycle += 3.0 + (and_bits(reg_PC, #FF00) != and_bits(old_PC, #FF00))

        -- LDA #aa
        case #A9 then
            if reg_PC < #C000 then
                reg_A = peek(reg_PC+PRGROM1-#8000)
            else
                reg_A = peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 2.0

        -- DEX
        case #CA then
            reg_X = and_bits(reg_X+#FF, #FF)
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 2.0

        -- LDA aaaa
        case #AD then
            if reg_PC < #C000 then
                address = PRGROM1+reg_PC-#8000
            else
                address = PRGROM2+reg_PC-#C000
            end if
            reg_A = read_byte(peek(address) + peek(address+1)*#100)
            reg_PC += 2
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 4.0

        -- RTS
        case #60 then
            reg_PC = pull()
            reg_PC += (pull()*#100)+1
            cycle += 6.0

        -- LDA aa,X
        case #B5 then
            if reg_PC<#C000 then
                reg_A = read_byte(and_bits(peek(reg_PC+PRGROM1-#8000)+reg_X,#FF))
            else
                reg_A = read_byte(and_bits(peek(reg_PC+PRGROM2-#C000)+reg_X,#FF))
            end if
            reg_PC += 1
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 4.0

        -- LDA aaaa,X
        case #BD then
            if reg_PC < #C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_A = read_byte(and_bits(address+reg_X,#FFFF))
            reg_PC += 2
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 4.0

        -- BCC <aa
        case #90 then
            old_PC = reg_PC
            condition = (not Carry)
            Branch()

        -- JSR aaaa
        case #20 then
            address = fetch_word()
            push_word(reg_PC-1)
            reg_PC = address
            cycle += 6.0

        -- BIT aaaa
        case #2C then
            operand = read_byte(fetch_word())
            Negative = (and_bits(operand, N_FLAG)!=0)
            Overflow = (and_bits(operand, V_FLAG)!=0)
            if and_bits(reg_A, operand) then
                Zero = 0
            else
                Zero = 1
            end if
            cycle += 4.0

        -- BVC <aa
        case #50 then
            old_PC = reg_PC
            condition = (not Overflow)
            Branch()

        -- STA aaaa,X
        case #9D then
            if reg_PC<#C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            write_byte(and_bits(address+reg_X,#FFFF),reg_A)
            cycle += 5.0

        -- CMP #aa
        case #C9 then
            if reg_PC < #C000 then
                operand = reg_A-peek(reg_PC+PRGROM1-#8000)
            else
               operand = reg_A-peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            CMP_()
            cycle += 2.0

        -- LDA (aa),Y
        case #B1 then
            reg_A = read_byte(iny8post())
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 5.0

        -- BCS <aa
        case #B0 then
            old_PC = reg_PC
            condition = Carry
            Branch()

        -- SEC
        case #38 then
            Carry = 1
            cycle += 2.0

        -- PLA
        case #68 then
            reg_A = pull()
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 4.0

        -- AND #aa
        case #29 then
            if reg_PC < #C000 then
                operand = peek(reg_PC+PRGROM1-#8000)
            else
                operand = peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            reg_A = and_bits(reg_A, operand)
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 2.0

        -- INX
        case #E8 then
            reg_X = and_bits(reg_X+1, #FF)
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 2.0

        -- INY
        case #C8 then
            reg_Y = and_bits(reg_Y+1, #FF)
            Negative = (reg_Y >= #80)
            Zero = (reg_Y = 0)
            cycle += 2.0

        -- LSR
        case #4A then
            Negative = 0
            Carry = and_bits(reg_A, 1)
            reg_A = floor(reg_A / 2)
            if reg_A then
                Zero = 0
            else
                Zero = 1
                Negative = 0
            end if
            cycle += 2.0

        -- TAX
        case #AA then
            reg_X = reg_A
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 2.0

        -- STA aaaa
        case #8D then
            if reg_PC<#C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            write_byte(address,reg_A)
            cycle += 4.0

        -- TAY
        case #A8 then
            reg_Y = reg_A
            Negative = (reg_Y >= #80)
            Zero = (reg_Y = 0)
            cycle += 2.0

        -- STA aa,X
        case #95 then
            write_byte(zpx8(),reg_A)
            cycle += 4.0

        -- ASL
        case #0A then
            reg_A += reg_A
            if reg_A<#100 then
                Carry = 0
            else
                Carry = 1
                reg_A = and_bits(reg_A,#FF)
            end if
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 2.0

        -- SBC aa
        case #E5 then
            operand = xor_bits(read_byte(fetch_byte()), #FF)
            ADC_()
            cycle += 3.0

        -- CMP aa
        case #C5 then
            operand = reg_A - read_byte(fetch_byte())
            CMP_()
            cycle += 3.0

        -- CLC
        case #18 then
            Carry = 0
            cycle += 2.0

        -- BPL <aa
        case #10 then
            old_PC = reg_PC
            condition = (not Negative)
            Branch()

        -- ADC aa
        case #65 then
            operand = read_byte(fetch_byte())
            ADC_()
            cycle += 3.0

        -- NOP
        case #EA then
            cycle += 2.0

        -- SBC #aa
        case #E9 then
            operand = xor_bits(fetch_byte(), #FF)
            ADC_()
            cycle += 3.0

        -- EOR #aa
        case #49 then
            operand = fetch_byte()
            EOR_()
            cycle += 3.0

        -- LDA aaaa,Y
        case #B9 then
            reg_A = read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 5.0

        -- DEY
        case #88 then
            reg_Y = and_bits(reg_Y+#FF, #FF)
            Negative = (reg_Y >= #80)
            Zero = (reg_Y = 0)
            cycle += 2.0

        -- PHA
        case #48 then
            push(reg_A)
            cycle += 3.0

        -- BMI <aa
        case #30 then
            old_PC = reg_PC
            condition = Negative
            Branch()

        -- LDY #aa
        case #A0 then
            if reg_PC < #C000 then
                reg_Y = peek(reg_PC+PRGROM1-#8000)
            else
                reg_Y = peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            Negative = (reg_Y >= #80)
            Zero = (reg_Y = 0)
            cycle += 2.0

        -- ROR
        case #6A then
            if Carry then
                reg_A += #100
            end if
            Carry = and_bits(reg_A, 1)
            reg_A = floor(reg_A / 2)
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 2.0

        -- STY aa
        case #84 then
            write_byte(fetch_byte(),reg_Y)
            cycle += 3.0

        -- Illegal opcode
        case #02 then
            puts(1,"#02\n")

        -- TXA
        case #8A then
            reg_A = reg_X
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 2.0

        -- ROL
        case #2A then
            reg_A += reg_A+Carry
            if reg_A<#100 then
                Carry = 0
            else
                Carry = 1
                reg_A = and_bits(reg_A,#FF)
            end if
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 2.0

        -- ROL aa
        case #26 then
            if reg_PC < #C000 then
                address = peek(reg_PC+PRGROM1-#8000)
            else
                address = peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            ROL_()
            cycle += 5.0

        -- ADC #aa
        case #69 then
            if reg_PC < #C000 then
                operand = peek(reg_PC+PRGROM1-#8000)
            else
                operand = peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            ADC_()
            cycle += 2.0

        -- ORA aa
        case #05 then
            operand = read_byte(fetch_byte())
            ORA_()
            cycle += 3.0

        -- ASL aa
        case #06 then
            address = fetch_byte()
            ASL_()
            cycle += 5.0

        -- INC aa
        case #E6 then
            address = fetch_byte()
            INC_()
            cycle += 3.0

        -- TYA
        case #98 then
            reg_A = reg_Y
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 2.0

        -- STA (aa),Y
        case #91 then
            write_byte(iny8post(),reg_A)
            cycle += 6.0

        -- LDX #aa
        case #A2 then
            if reg_PC < #C000 then
                reg_X = peek(reg_PC+PRGROM1-#8000)
            else
                reg_X = peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 2.0

        -- CPX #aa
        case #E0 then
            if reg_PC < #C000 then
                operand = reg_X - peek(reg_PC+PRGROM1-#8000)
            else
                operand = reg_X - peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            CMP_()
            cycle += 2.0

        -- SBC aaaa,Y
        case #F9 then
            if reg_PC < #C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            operand = xor_bits(read_byte(and_bits(address+reg_Y,#FFFF)),#FF)
            ADC_()
            cycle += 4.0

        -- CPY #aa
        case #C0 then
            if reg_PC < #C000 then
                operand = reg_Y-peek(reg_PC+PRGROM1-#8000)
            else
                operand = reg_Y-peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            CMP_()
            cycle += 2.0

        -- LSR aa
        case #46 then
            address = fetch_byte()
            LSR_()
            cycle += 5.0

        -- DEC aa
        case #C6 then
            address = fetch_byte()
            DEC_()
            cycle += 4.0

        -- ROL aa,X
        case #36 then
            address = zpx8()
            ROL_()
            cycle += 6.0

        -- JMP (aaaa)
        case #6C then
             reg_PC = read_word(fetch_word())
             cycle += 5.0

        -- CPX aa
        case #E4 then
            operand = reg_X-read_byte(fetch_byte())
            CMP_()
            cycle += 3.0

        -- STX aaaa
        case #8E then
            if reg_PC < #C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            write_byte(address, reg_X)
            cycle += 4.0

        -- LDX aa
        case #A6 then
            if reg_PC < #C000 then
                reg_X = read_byte(peek(reg_PC+PRGROM1-#8000))
            else
                reg_X = read_byte(peek(reg_PC+PRGROM2-#C000))
            end if
            reg_PC += 1
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 3.0

        -- STX aa
        case #86 then
            write_byte(fetch_byte(), reg_X)
            cycle += 3.0

        -- SBC aaaa
        case #ED then
            if reg_PC < #C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            operand = xor_bits(read_byte(address),#FF)
            ADC_()
            cycle += 4.0

        -- SBC aa,X
        case #F5 then
            operand = xor_bits(read_byte(and_bits(fetch_byte()+reg_X,#FF)), #FF)
            ADC_()
            cycle += 4.0

        -- DEC aaaa
        case #CE then
            address = fetch_word()
            DEC_()
            cycle += 4.0

        -- EOR aa
        case #45 then
            if reg_PC<#C000 then
                operand = read_byte(peek(reg_PC+PRGROM1-#8000))
            else
                operand = read_byte(peek(reg_PC+PRGROM2-#C000))
            end if
            reg_PC += 1
            EOR_()
            cycle += 3.0

        -- LDY aaaa
        case #AC then
            reg_Y = read_byte(fetch_word())
            Negative = (reg_Y >= #80)
            Zero = (reg_Y = 0)
            cycle += 4.0

        -- CMP aaaa,Y
        case #D9 then
            operand = reg_A-read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
            CMP_()
            cycle += 4.0

        -- INC aaaa,X
        case #FE then
            address = and_bits(fetch_word()+reg_X,#FFFF)
            INC_()
            cycle += 4.0

        -- ADC aaaa,Y
        case #79 then
            if reg_PC < #C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            operand = read_byte(and_bits(address+reg_Y,#FFFF))
            ADC_()
            cycle += 4.0

        -- LDY aa,X
        case #B4 then
            reg_Y = read_byte(and_bits(fetch_byte()+reg_X, #FF))
            Negative = (reg_Y >= #80)
            Zero = (reg_Y = 0)
            cycle += 4.0

        -- ORA #aa
        case #09 then
            if reg_PC<#C000 then
                operand = peek(reg_PC+PRGROM1-#8000)
            else
                operand = peek(reg_PC+PRGROM2-#C000)
            end if
            reg_PC += 1
            ORA_()
            cycle += 2.0

        -- CMP aa,X
        case #D5 then
            operand = reg_A-read_byte(zpx8())
            CMP_()
            cycle += 4.0

        -- INC aaaa
        case #EE then
            address = fetch_word()
            INC_()
            cycle += 4.0

        -- SBC (aa),Y
        case #F1 then
            operand = xor_bits(read_byte(iny8post()), #FF)
            ADC_()
            cycle += 5.0

        -- INC aa,X
        case #F6 then
            address = zpx8()
            INC_()
            cycle += 4.0

        -- ORA aa,X
        case #15 then
            operand = read_byte(zpx8())
            ORA_()
            cycle += 4.0

        -- LDY aa
        case #A4 then
            if reg_PC<#C000 then
                reg_Y = read_byte(peek(reg_PC+PRGROM1-#8000))
            else
                reg_Y = read_byte(peek(reg_PC+PRGROM2-#C000))
            end if
            reg_PC += 1
            Negative = (reg_Y >= #80)
            Zero = (reg_Y = 0)
            cycle += 3.0

        -- CMP aaaa,X
        case #DD then
            operand = reg_A-read_byte(and_bits(fetch_word()+reg_X, #FFFF))
            CMP_()
            cycle += 4.0

        -- ORA aaaa
        case #0D then
            operand = read_byte(fetch_word())
            ORA_()
            cycle += 4.0

        -- EOR aaaa
        case #4D then
            operand = read_byte(fetch_word())
            EOR_()
            cycle += 4.0

        -- ADC aa,X
        case #75 then
            operand = read_byte(and_bits(fetch_byte()+reg_X,#FF))
            ADC_()
            cycle += 4.0

        -- ORA (aa),Y
        case #11 then
            operand = read_byte(iny8post())
            ORA_()
            cycle += 5.0

        -- AND aa,X
        case #35 then
            operand = read_byte(zpx8())
            AND_()
            cycle += 4.0

        -- STA aaaa,Y
        case #99 then
            if reg_PC<#C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            write_byte(and_bits(address+reg_Y,#FFFF),reg_A)
            cycle += 5.0

        -- DEC aaaa,X
        case #DE then
            address = fetch_word()+reg_X
            DEC_()
            cycle += 4.0

        -- RTI
        case #40 then
            reg_P = pull()
            Carry = and_bits(reg_P,C_FLAG)
            Zero = floor(and_bits(reg_P,Z_FLAG)/Z_FLAG)
            Interrupt = floor(and_bits(reg_P,I_FLAG)/I_FLAG)
            Decimal = floor(and_bits(reg_P,D_FLAG)/D_FLAG)
            Break = floor(and_bits(reg_P,B_FLAG)/B_FLAG)
            Overflow = floor(and_bits(reg_P,V_FLAG)/V_FLAG)
            Negative = floor(and_bits(reg_P,N_FLAG)/N_FLAG)

            reg_PC = pull()
            reg_PC += (pull()*#100)
            cycle += 6.0

        -- AND aa
        case #25 then
            operand = read_byte(fetch_byte())
            AND_()
            cycle += 3.0

        -- ADC (aa),Y
        case #71 then
            operand = read_byte(iny8post())
            ADC_()
            cycle += 5.0

        -- CMP aaaa
        case #CD then
            operand = reg_A-read_byte(fetch_word())
            CMP_()
            cycle += 4.0

        -- LDY aaaa,X
        case #BC then
            reg_Y = read_byte(fetch_word()+reg_X)
            Negative = (reg_Y >= #80)
            Zero = (reg_Y = 0)
            cycle += 4.0

        -- ROR aa,X
        case #76 then
            address = zpx8()
            ROR_()
            cycle += 6.0

        -- ROR aa
        case #66 then
            address = fetch_byte()
            ROR_()
            cycle += 5.0

        -- STY aaaa
        case #8C then
            if reg_PC < #C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            write_byte(address,reg_Y)
            cycle += 4.0

        -- DEC aa,X
        case #D6 then
            address = zpx8()
            DEC_()
            cycle += 4.0

        -- LDX aaaa
        case #AE then
            reg_X = read_byte(fetch_word())
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 4.0

        -- ORA aaaa,X
        case #1D then
            operand = read_byte(fetch_word()+reg_X)
            ORA_()
            cycle += 4.0

        -- ADC aaaa
        case #6D then
            if reg_PC<#C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            operand = read_byte(address)
            ADC_()
            cycle += 4.0

        -- ROR aaaa
        case #6E then
            address = fetch_word()
            ROR_()
            cycle += 6.0

        -- ROL aaaa
        case #2E then
            address = fetch_word()
            ROL_()
            cycle += 6.0

        -- CPY aa
        case #C4 then
            operand = reg_Y-read_byte(fetch_byte())
            CMP_()
            cycle += 3.0

        -- PLP
        case #28 then
            reg_P = pull()
            Carry = and_bits(reg_P,C_FLAG)
            Zero = floor(and_bits(reg_P,Z_FLAG)/Z_FLAG)
            Interrupt = floor(and_bits(reg_P,I_FLAG)/I_FLAG)
            Decimal = floor(and_bits(reg_P,D_FLAG)/D_FLAG)
            Break = floor(and_bits(reg_P,B_FLAG)/B_FLAG)
            Overflow = floor(and_bits(reg_P,V_FLAG)/V_FLAG)
            Negative = floor(and_bits(reg_P,N_FLAG)/N_FLAG)
            cycle += 4.0

        -- PHP
        case #08 then
            reg_P = Carry+
                Zero*Z_FLAG+
                Interrupt*I_FLAG+
                Decimal*D_FLAG+
                B_FLAG+
                32+
                Overflow*V_FLAG+
                Negative*N_FLAG
            push(reg_P)
            cycle += 3.0

        -- BVS <aa
        case #70 then
            condition = Overflow
            Branch()

        -- LDX aaaa,Y
        case #BE then
            reg_X = read_byte(and_bits(fetch_word()+reg_Y, #FFFF))
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 4.0

        -- SEI
        case #78 then
            Interrupt = 1
            cycle += 2.0

        -- LSR aaaa
        case #4E then
            address = fetch_word()
            LSR_()
            cycle += 6.0

        -- BIT aa
        case #24 then
            operand = read_byte(fetch_byte())
            Negative = (and_bits(operand,N_FLAG)!=0)
            Overflow = (and_bits(operand,V_FLAG)!=0)
            if and_bits(reg_A, operand) then
                Zero = 0
            else
                Zero = 1
            end if
            cycle += 3.0

        -- LDX aa,Y
        case #B6 then
            if reg_PC<#C000 then
                reg_X = read_byte(and_bits(peek(reg_PC+PRGROM1-#8000)+reg_Y,#FF))
            else
                reg_X = read_byte(and_bits(peek(reg_PC+PRGROM2-#C000)+reg_Y,#FF))
            end if
            reg_PC += 1
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 3.0

        -- ADC aaaa,X
        case #7D then
            operand = read_byte(fetch_word()+reg_X)
            ADC_()
            cycle += 4.0

        -- CMP (aa),Y
        case #D1 then
            operand = reg_A-read_byte(iny8post())
            CMP_()
            cycle += 5.0

        -- SBC aaaa,X
        case #FD then
            if reg_PC<#C000 then
                temp = PRGROM1+reg_PC-#8000
            else
                temp = PRGROM2+reg_PC-#C000
            end if
            address = peek(temp) + peek(temp+1)*#100
            reg_PC += 2
            operand = xor_bits(read_byte(address+reg_X),#FF)
            ADC_()
            cycle += 4.0

        -- ORA aaaa,Y
        case #19 then
            operand = read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
            ORA_()
            cycle += 4.0

        -- LDA (aa,X)
        case #A1 then
            reg_A = read_byte(inx8pre())
            Negative = (reg_A >= #80)
            Zero = (reg_A = 0)
            cycle += 6.0

        -- ROR aaaa,X
        case #7E then
            address = fetch_word()+reg_X
            ROR_()
            cycle += 7.0

        -- ROL aaaa,X
        case #3E then
            address = fetch_word()+reg_X
            ROL_()
            cycle += 7.0

        -- STY aa,X
        case #94 then
            write_byte(zpx8(), reg_Y)
            cycle += 4.0

        -- AND aaaa,Y
        case #39 then
            operand = read_byte(and_bits(fetch_word()+reg_Y, #FFFF))
            AND_()
            cycle += 4.0

        -- AND aaaa,X
        case #3D then
            operand = read_byte(and_bits(fetch_word()+reg_X, #FFFF))
            AND_()
            cycle += 4.0

        -- EOR aaaa,Y
        case #59 then
            operand = read_byte(and_bits(fetch_word()+reg_Y, #FFFF))
            EOR_()
            cycle += 4.0

        -- AND aaaa
        case #2D then
            operand = read_byte(fetch_word())
            AND_()
            cycle += 4.0

        -- CPY aaaa
        case #CC then
            operand = reg_Y-read_byte(fetch_word())
            CMP_()
            cycle += 4.0

        -- LSR aaaa,X
        case #5E then
            address = fetch_word()+reg_X
            LSR_()
            cycle += 7.0

        -- TXS
        case #9A then
            reg_S = reg_X
            cycle += 2.0

        -- CLD
        case #D8 then
            Decimal = 0
            cycle += 2.0

        -- ASL aaaa
        case #0E then
            address = fetch_word()
            ASL_()
            cycle += 6.0

        -- SLO aa
        case #07 then
            --reg_PC += 1
            cycle += 3.0

        -- TSX
        case #BA then
            reg_X = reg_S
            Negative = (reg_X >= #80)
            Zero = (reg_X = 0)
            cycle += 2.0

        -- CLI
        case #58 then
            Interrupt = 0
            cycle += 2.0

        -- EOR aa,X
        case #55 then
            operand = read_byte(zpx8())
            EOR_()
            cycle += 4.0

        -- STX aa,Y
        case #96 then
            write_byte(zpy8(), reg_X)
            cycle += 4.0

        -- STA (aa,X)
        case #81 then
            write_byte(inx8pre(), reg_A)
            cycle += 6.0

        -- EOR (aa),Y
        case #51 then
            operand = read_byte(iny8post())
            EOR_()
            cycle += 5.0

        -- CPX aaaa
        case #EC then
            operand = reg_X-read_byte(fetch_word())
            CMP_()
            cycle += 4.0

        -- ASL aa,X
        case #16 then
            address = zpx8()
            ASL_()
            cycle += 6.0

        -- AND (aa),Y
        case #31 then
            operand = read_byte(iny8post())
            AND_()
            cycle += 5.0

        -- CLV
        case #B8 then
            Overflow = 0
            cycle += 2.0

        -- EOR aaaa,X
        case #5D then
            operand = read_byte(fetch_word()+reg_X)
            EOR_()
            cycle += 4.0

        -- LSR aa,X
        case #56 then
            address = zpx8()
            LSR_()
            cycle += 6.0

        -- ISB aaaa,X
        case #FF then
            cycle += 5.0

        -- SED
        case #F8 then
            Decimal = 1
            cycle += 2.0

        -- SHA aaaa,Y
        case #9F then
            puts(1,"#9F\n")

        -- Illegal opcode
        case #7F then
            cycle += 2.0

        -- RRA aa
        case #67 then
            cycle += 5.0

        -- RLA aa,X
        case #37 then
            cycle += 6.0

        -- RLA (aa),Y
        case #33 then
            puts(1,"#33\n")

        -- SLO aaaa
        case #0F then
            cycle += 5.0

        -- NOP aaaa,X
        case #FC then
            cycle += 4.0

        -- ISB aaaa,Y
        case #FB then
            cycle += 5.0

        -- NOP 
        case #FA then
            puts(1,"#FA\n")
            cycle += 2.0

        -- ISB aa,X
        case #F7 then
            puts(1,"#F7\n")

        -- NOP aa,X
        case #F4 then
            puts(1,"#F4\n")

        -- Illegal opcode
        case #F3 then

        -- Illegal opcode
        case #F2 then

        -- ISB aaaa
        case #EF then

        -- Illegal opcode
        case #EB then

        -- ISB aa
        case #E7 then

        -- ISB (aa,X)
        case #E3 then

        -- NOP #aa
        case #E2 then

        -- SBC (aa,X)
        case #E1 then
            operand = xor_bits(read_byte(inx8pre()), #FF)
            ADC_()
            cycle += 6.0

        -- Illegal opcode
        case #DF then

        -- NOP aaaa,X
        case #DC then

        -- DCP aaaa,Y
        case #DB then
            puts(1,"#DB\n")

        -- Illegal opcode
        case #DA then
            puts(1,"#DA\n")

        -- Illegal opcode
        case #D7 then

        -- Illegal opcode
        case #D4 then

        -- Illegal opcode
        case #D3 then

        -- Illegal opcode
        case #D2 then

        -- DCP aaaa,X
        case #CF then

        -- Illegal opcode
        case #CB then

        -- Illegal opcode
        case #C7 then

        -- DCP (aa,X)
        case #C3 then

        -- NOP #aa
        case #C2 then

        -- CMP (aa,X)
        case #C1 then
            operand = reg_A-read_byte(inx8pre())
            CMP_()
            cycle += 7.0

        -- LAX aaaa,Y
        case #BF then
            puts(1,"#BF\n")

        -- LAS aaaa,Y
        case #BB then
            puts(1,"#BB\n")

        -- Illegal opcode
        case #B7 then
            cycle += 1.0

        -- Illegal opcode
        case #B3 then
            cycle += 1.0

        -- Illegal opcode
        case #B2 then
            cycle += 1.0

        -- Illegal opcode
        case #AF then
            cycle += 1.0

        -- LSA #aa
        case #AB then
            puts(1,"#AB\n")

        -- Illegal opcode
        case #A7 then
            puts(1,"#A7\n")

        -- Illegal opcode
        case #A3 then
            puts(1,"#A3\n")

        -- Illegal opcode
        case #9E then
            puts(1,"#9E\n")

        -- SHY aaaa,X
        case #9C then
            puts(1,"#9C\n")

        -- SHS aaaa,Y
        case #9B then
            puts(1,"#9B\n")

        -- SAX aa,Y
        case #97 then
            puts(1,"#97\n")

        -- SHA (aa),Y
        case #93 then
            puts(1,"#93\n")

        -- Illegal opcode
        case #92 then
            puts(1,"#92\n")

        -- Illegal opcode
        case #8F then
            cycle += 2.0

        -- ANE #aa
        case #8B then
            puts(1,"#8B\n")

        -- Illegal opcode
        case #89 then
            puts(1,"#89\n")

        -- Illegal opcode
        case #87 then
            puts(1,"#87\n")

        -- Illegal opcode
        case #83 then
            puts(1,"#83\n")

        -- Illegal opcode
        case #82 then
            puts(1,"#82\n")

        -- Illegal opcode
        case #80 then
            puts(1,"#80\n")
            cycle += 2.0

        -- NOP aaaa,X
        case #7C then
            puts(1,"#7C\n")

        -- RRA aaaa,Y
        case #7B then
            puts(1,"#7B\n")

        -- NOP 
        case #7A then
            puts(1,"#7A\n")

        -- RRA aa,X
        case #77 then
            puts(1,"#77\n")

        -- Illegal opcode
        case #74 then
            puts(1,"#74\n")

        -- Illegal opcode
        case #73 then
            puts(1,"#73\n")

        -- Illegal opcode
        case #72 then
            puts(1,"#72\n")

        -- Illegal opcode
        case #6F then
            puts(1,"#6F\n")

        -- Illegal opcode
        case #6B then
            puts(1,"#6B\n")

        -- NOP aa
        case #64 then
            puts(1,"#64\n")

        -- RRA (aa,X)
        case #63 then
            cycle += 4.0

        -- Illegal opcode
        case #62 then
            puts(1,"#62\n")

        -- ADC (aa,X)
        case #61 then
            operand = read_byte(inx8pre())
            ADC_()
            cycle += 6.0

        -- Illegal opcode
        case #5F then
            puts(1,"#5F\n")

        -- NOP aaaa,X
        case #5C then
            cycle += 4.0

        -- SRE aaaa,Y
        case #5B then
            puts(1,"#5B\n")

        -- NOP 
        case #5A then
            cycle += 2.0

        -- Illegal opcode
        case #57 then
            puts(1,"#57\n")

        -- NOP aa,X
        case #54 then
            cycle += 2.0

        -- SRE (aa),Y
        case #53 then
            puts(1,"#53\n")

        -- Illegal opcode
        case #52 then
            puts(1,"#52\n")

        -- SRE aaaa
        case #4F then
            cycle += 1.0

        -- ASR #aa
        case #4B then
            cycle += 2.0

        -- Illegal opcode
        case #47 then
            puts(1,"#47\n")

        -- NOP aa
        case #44 then
            puts(1,"#44\n")

        -- SRE (aa,X)
        case #43 then
            puts(1,"#43\n")

        -- Illegal opcode
        case #42 then
            puts(1,"#42\n")

        -- EOR (aa,X)
        case #41 then
            operand = read_byte(inx8pre())
            EOR_()
            cycle += 6.0

        -- RLA aaaa,X
        case #3F then
            cycle += 1.0

        -- NOP aaaa,X
        case #3C then
            puts(1,"#3C\n")

        -- RLA aaaa,Y
        case #3B then
            puts(1,"#3B\n")

        -- NOP 
        case #3A then
            cycle += 2.0

        -- NOP aa,X
        case #34 then
            cycle += 2.0

        -- Illegal opcode
        case #32 then
            cycle += 2.0

        -- RLA aaaa
        case #2F then
            cycle += 2.0

        -- ANC #aa
        case #2B then

        -- RLA aa
        case #27 then

        -- RLA (aa,X)
        case #23 then

        -- Illegal opcode
        case #22 then
            cycle += 2.0

        -- AND (aa,X)
        case #21 then
            operand = read_byte(inx8pre())
            AND_()
            cycle += 3.0

        -- SLO aaaa,X
        case #1F then
            cycle += 2.0

        -- ASL aaaa,X
        case #1E then
            address = fetch_word()+reg_X
            ASL_()
            cycle += 7.0

        -- NOP aaaa,X
        case #1C then

        -- SLO aaaa,Y
        case #1B then
            puts(1,"#1B\n")

        -- NOP 
        case #1A then
            cycle += 2.0

        -- SLO aa,X
        case #17 then
            cycle += 3.0

        -- NOP aa,X
        case #14 then

        -- SLO (aa),Y
        case #13 then

        -- Illegal opcode
        case #12 then
            puts(1,"#12\n")
            cycle += 2.0

        -- NOP aaaa
        case #0C then
            cycle += 4.0

        -- ANC #aa
        case #0B then
            cycle += 2.0
             
    end switch
end procedure



global procedure push_status()
    reg_P = Carry+
        Zero*Z_FLAG+
        Interrupt*I_FLAG+
        Break*B_FLAG+
        32+
        Overflow*V_FLAG+
        Negative*N_FLAG
    push(reg_P)
end procedure



global procedure reset_6502()
    reg_PC = read_word2(#FFFC)
    reg_A = 0
    reg_X = 0
    reg_Y = 0
    reg_S = #FF

    reg_P = #20
    Carry = 0
    Zero = 0
    Interrupt = 0
    Decimal = 0
    Break = 0
    Overflow = 0
    Negative = 0

    executed = 0
    cycle = 7.0
end procedure



global procedure init_6502(atom mem)
    init_memory(mem)

    reg_A = 0
    reg_X = 0
    reg_Y = 0
    reg_PC = 0
    reg_S = #FF

    reg_P = #20
    Carry = 0
    Zero = 0
    Interrupt = 0
    Decimal = 0
    Break = 0
    Overflow = 0
    Negative = 0

    executed = 0
    cycle = 7.0
end procedure
