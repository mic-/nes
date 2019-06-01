-- A 6502 emulator in Euphoria
-- /Mic, 2003


include memory.e
include debug.e


-- FLAGS
constant C_FLAG = 1,		-- carry
         Z_FLAG = 2,		-- zero
         I_FLAG = 4,		-- irq disable
         D_FLAG = 8,		-- decimal mode
         B_FLAG = 16,		-- break
         			-- (bit 5 is unused)
         V_FLAG = 64,		-- overflow
         N_FLAG = 128		-- negative
         


sequence usage
integer executed,address,operand,op,temp,condition,old_PC
global integer Carry,Zero,Interrupt,Decimal,Break,Overflow,Negative

usage = repeat(0,256)


-------------------------------------- OPCODES ------------------------------------------------------

procedure ADC_()
	integer val
	
	val = operand + reg_A + Carry

	if (val>#FF) then
		Carry = 1
	else 
		Carry = 0
	end if
	
	if not and_bits(val,#FF) then
		Zero = 1
		Negative = 0
	else
		Zero = 0
		if and_bits(val,#80) then
			Negative = 1
		else
			Negative = 0
		end if
	end if
	if (not and_bits(xor_bits(reg_A,operand),#80)) and and_bits(xor_bits(reg_A,val),#80) then
		Overflow = 1
	else
		Overflow = 0
	end if
	reg_A = and_bits(val,#FF)
end procedure



procedure AND_()
	reg_A = and_bits(reg_A,operand)
	
	if reg_A then
		if reg_A<#80 then
			Negative = 0
		else
			Negative = 1
		end if
		Zero = 0
	else
		Zero = 1
		Negative = 0
	end if
end procedure



procedure ASL_()
	operand = read_byte(address)
	operand += operand
	
	if operand>#FF then
		Carry = 1
	else
		Carry = 0
	end if
	
	operand = and_bits(operand,#FF)
	write_byte(address,operand)
	
	if operand then
		if operand<#80 then
			Negative = 0
		else
			Negative = 1
		end if
		Zero = 0
	else
		Zero = 1
		Negative = 0
	end if
end procedure


procedure CMP_()
	if operand<0 then
		Negative = 1
		Zero = 0
		Carry = 0
	elsif operand then
		Carry = 1
		Zero = 0
		if operand<#80 then
			Negative = 0
		else
			Negative = 1
		end if
	else
		Carry = 1
		Zero = 1
		Negative = 0
	end if
end procedure
		

procedure DEC_()
	operand = read_byte(address)
	operand = and_bits(operand+#FF,#FF)

	write_byte(address,operand)
	
	if operand then
		if operand<#80 then
			Negative = 0
		else
			Negative = 1
		end if
		Zero = 0
	else
		Zero = 1
		Negative = 0
	end if
end procedure

	
procedure EOR_()
	reg_A = xor_bits(reg_A,operand)
	
	if reg_A then
		if reg_A<#80 then
			Negative = 0
		else
			Negative = 1
		end if
		Zero = 0
	else
		Zero = 1
		Negative = 0
	end if
end procedure



procedure INC_()
	operand = read_byte(address)
	operand = and_bits(operand+1,#FF)

	write_byte(address,operand)
	
	if operand then
		if operand<#80 then
			Negative = 0
		else
			Negative = 1
		end if
		Zero = 0
	else
		Zero = 1
		Negative = 0
	end if
end procedure


procedure LSR_()
	operand = read_byte(address)
	
	if and_bits(operand,1) then
		Carry = 1
	else
		Carry = 0
	end if
	
	operand = floor(operand/2)
	write_byte(address,operand)
	
	if operand then
		Zero = 0
	else
		Zero = 1
	end if
	Negative = 0
end procedure


procedure ORA_()
	reg_A = or_bits(reg_A,operand)
	
	if reg_A then
		if reg_A<#80 then
			Negative = 0
		else
			Negative = 1
		end if
		Zero = 0
	else
		Zero = 1
		Negative = 0
	end if
end procedure



procedure ROL_()
	operand = read_byte(address)
	operand += operand+Carry
	if operand<#100 then
		Carry = 0
	else
		Carry = 1
		operand = and_bits(operand,#FF)
	end if
	write_byte(address,operand)
	if operand then
		Zero = 0
		if operand>=#80 then
			Negative = 1
		else
			Negative = 0
		end if
	else
		Zero = 1
		Negative = 0
	end if
end procedure


procedure ROR_()
	operand = read_byte(address)
	if Carry then
		operand += #100
	end if
	
	if and_bits(operand,1) then
		Carry = 1
	else
		Carry = 0
	end if
	
	operand = floor(operand/2) 
	write_byte(address,operand)
	
	if operand then
		if operand<#80 then
			Negative = 0
		else
			Negative = 1
		end if
		Zero = 0
	else
		Zero = 1
		Negative = 0
	end if
end procedure



procedure Branch()
	if condition then
		if reg_PC<#C000 then
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
	cycle += 3.0 + (and_bits(reg_PC,#FF00) != and_bits(old_PC,#FF00))
end procedure

------------------------------------------------------------------------------------------------------


global procedure execute()
	-- Fetch opcode
	if reg_PC<#C000 then
		op = peek(reg_PC+PRGROM1-#8000)
	else
		op = peek(reg_PC+PRGROM2-#C000)
	end if	
	reg_PC += 1


	-- Let the IFs begin...
	-- Opcodes are sorted by their frequency of use in typcial programs.

	-- JMP aaaa
	if op = #4C then
		--puts(1,"#4C\n")
		if reg_PC<#C000 then
			address = PRGROM1+reg_PC-#8000
		else
			address = PRGROM2+reg_PC-#C000
		end if	
		reg_PC = peek(address) + peek(address+1)*#100
		cycle += 3.0
	
	-- LDA aa
	elsif op = #A5 then
		--puts(1,"#A5\n")
		if reg_PC<#C000 then
			reg_A = read_byte(peek(reg_PC+PRGROM1-#8000))
		else
			reg_A = read_byte(peek(reg_PC+PRGROM2-#C000))
		end if	
		reg_PC += 1
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 3.0
	
	-- BEQ <aa
	elsif op = #F0 then
		--puts(1,"#F0\n")
		old_PC = reg_PC
		if Zero then
			if reg_PC<#C000 then
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
		cycle += 3.0 + (and_bits(reg_PC,#FF00) != and_bits(old_PC,#FF00))
	
	-- STA aa
	elsif op = #85 then
		--puts(1,"#85\n")
		if reg_PC<#C000 then
			address = peek(reg_PC+PRGROM1-#8000)
		else
			address = peek(reg_PC+PRGROM2-#C000)
		end if
		reg_PC += 1
		write_byte(address,reg_A)
		cycle += 3.0	
	
	-- BNE <aa
	elsif op = #D0 then
		--puts(1,"#D0\n")
		old_PC = reg_PC
		if not Zero then
			if reg_PC<#C000 then
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
		cycle += 3.0 + (and_bits(reg_PC,#FF00) != and_bits(old_PC,#FF00))

	-- LDA #aa
	elsif op = #A9 then
		--puts(1,"#A9\n")
		if reg_PC<#C000 then
			reg_A = peek(reg_PC+PRGROM1-#8000)
		else
			reg_A = peek(reg_PC+PRGROM2-#C000)
		end if	
		reg_PC += 1
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- DEX 
	elsif op = #CA then
		--puts(1,"#CA\n")
		reg_X = and_bits(reg_X+#FF, #FF)
		if reg_X then
			if reg_X<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- LDA aaaa
	elsif op = #AD then
		--puts(1,"#AD\n")
		if reg_PC<#C000 then
			address = PRGROM1+reg_PC-#8000
		else
			address = PRGROM2+reg_PC-#C000
		end if	
		reg_A = read_byte(peek(address) + peek(address+1)*#100)
		reg_PC += 2
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- RTS 
	elsif op = #60 then
		--puts(1,"#60\n")
		reg_PC = pull()
		reg_PC += (pull()*#100)+1
		cycle += 6.0
	
	-- LDA aa,X
	elsif op = #B5 then
		--puts(1,"#B5\n")
		if reg_PC<#C000 then
			reg_A = read_byte(and_bits(peek(reg_PC+PRGROM1-#8000)+reg_X,#FF))
		else
			reg_A = read_byte(and_bits(peek(reg_PC+PRGROM2-#C000)+reg_X,#FF))
		end if	
		reg_PC += 1
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- LDA aaaa,X
	elsif op = #BD then
		--puts(1,"#BD\n")
		if reg_PC<#C000 then
			temp = PRGROM1+reg_PC-#8000
		else
			temp = PRGROM2+reg_PC-#C000
		end if
		address = peek(temp) + peek(temp+1)*#100
		reg_A = read_byte(and_bits(address+reg_X,#FFFF))
		reg_PC += 2
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- BCC <aa
	elsif op = #90 then
		--puts(1,"#90\n")
		old_PC = reg_PC
		condition = (not Carry)
		Branch()
	
	-- JSR aaaa
	elsif op = #20 then
		--puts(1,"#20\n")
		address = fetch_word()
		push_word(reg_PC-1)
		reg_PC = address
		cycle += 6.0
	
	-- BIT aaaa
	elsif op = #2C then
		--puts(1,"#2C\n")
		operand = read_byte(fetch_word())
		Negative = (and_bits(operand,N_FLAG)!=0)
		Overflow = (and_bits(operand,V_FLAG)!=0)
		if and_bits(reg_A,operand) then
			Zero = 0
		else
			Zero = 1
			--Negative = 0
		end if
		cycle += 4.0
	
	-- BVC <aa
	elsif op = #50 then
		--puts(1,"#50\n")
		old_PC = reg_PC
		condition = (not Overflow)
		Branch()
	
	-- STA aaaa,X
	elsif op = #9D then
		--puts(1,"#9D\n")
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
	elsif op = #C9 then
		--puts(1,"#C9\n")
		if reg_PC<#C000 then
			operand = reg_A-peek(reg_PC+PRGROM1-#8000)
		else
			operand = reg_A-peek(reg_PC+PRGROM2-#C000)
		end if		
		reg_PC += 1
		CMP_()
		cycle += 2.0
	
	-- LDA (aa),Y
	elsif op = #B1 then
		--puts(1,"#B1\n")
		reg_A = read_byte(iny8post())
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if	
		cycle += 5.0
	
	-- BCS <aa
	elsif op = #B0 then
		--puts(1,"#B0\n")
		old_PC = reg_PC
		condition = Carry
		Branch()
	
	-- SEC 
	elsif op = #38 then
		--puts(1,"#38\n")
		Carry = 1
		cycle += 2.0

	-- PLA 
	elsif op = #68 then
		--puts(1,"#68\n")
		reg_A = pull()
		if reg_A then
			Zero = 0
			if reg_A>=#80 then
				Negative = 1
			else
				Negative = 0
			end if
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- AND #aa
	elsif op = #29 then
		--puts(1,"#29\n")
		if reg_PC<#C000 then
			operand = peek(reg_PC+PRGROM1-#8000)
		else
			operand = peek(reg_PC+PRGROM2-#C000)
		end if		
		reg_PC += 1
		reg_A = and_bits(reg_A, operand)
		
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- INX 
	elsif op = #E8 then
		--puts(1,"#E8\n")
		reg_X = and_bits(reg_X+1, #FF)
		if reg_X then
			if reg_X<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- INY 
	elsif op = #C8 then
		--puts(1,"#C8\n")
		reg_Y = and_bits(reg_Y+1, #FF)
		if reg_Y then
			if reg_Y<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- LSR 
	elsif op = #4A then
		--puts(1,"#4A\n")
		Negative = 0
		if and_bits(reg_A,1) then
			Carry = 1
		else
			Carry = 0
		end if
		reg_A = floor(reg_A/2)
		if reg_A then
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- TAX 
	elsif op = #AA then
		--puts(1,"#AA\n")
		reg_X = reg_A
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- STA aaaa
	elsif op = #8D then
		--puts(1,"#8D\n")
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
	elsif op = #A8 then
		--puts(1,"#A8\n")
		reg_Y = reg_A
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
		
	-- STA aa,X
	elsif op = #95 then
		--puts(1,"#95\n")
		write_byte(zpx8(),reg_A)
		cycle += 4.0
	
	-- ASL 
	elsif op = #0A then
		--puts(1,"#0A\n")
		reg_A += reg_A
		if reg_A<#100 then
			Carry = 0
		else
			Carry = 1
			reg_A = and_bits(reg_A,#FF)
		end if
		if reg_A then
			Zero = 0
			if reg_A>=#80 then
				Negative = 1
			else
				Negative = 0
			end if
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- SBC aa
	elsif op = #E5 then
		--puts(1,"#E5\n")
		operand = xor_bits(read_byte(fetch_byte()),#FF)
		ADC_()
		cycle += 3.0
	
	-- CMP aa
	elsif op = #C5 then
		--puts(1,"#C5\n")
		operand = reg_A-read_byte(fetch_byte())
		CMP_()
		cycle += 3.0

	-- CLC 
	elsif op = #18 then
		Carry = 0
		cycle += 2.0
	
	-- BPL <aa
	elsif op = #10 then
		old_PC = reg_PC
		condition = (not Negative)
		Branch()
		
	-- ADC aa
	elsif op = #65 then
		--puts(1,"#65\n")
		operand = read_byte(fetch_byte())
		ADC_()
		cycle += 3.0

	-- NOP 
	elsif op = #EA then
		--puts(1,"#EA\n")
		cycle += 2.0
		
	-- SBC #aa
	elsif op = #E9 then
		--puts(1,"#E9\n")
		operand = xor_bits(fetch_byte(),#FF)
		ADC_()
		cycle += 3.0

	-- EOR #aa
	elsif op = #49 then
		--puts(1,"#49\n")
		operand = fetch_byte()
		EOR_()
		cycle += 3.0

	-- LDA aaaa,Y
	elsif op = #B9 then
		--puts(1,"#B9\n")
		reg_A = read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 5.0
	
	-- DEY 
	elsif op = #88 then
		--puts(1,"#88\n")
		reg_Y = and_bits(reg_Y+#FF, #FF)
		if reg_Y then
			if reg_Y<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- PHA 
	elsif op = #48 then
		--puts(1,"#48\n")
		push(reg_A)
		cycle += 3.0
	
	-- BMI <aa
	elsif op = #30 then
		old_PC = reg_PC
		condition = Negative
		Branch()
	
	-- LDY #aa
	elsif op = #A0 then
		--puts(1,"#A0\n")
		if reg_PC<#C000 then
			reg_Y = peek(reg_PC+PRGROM1-#8000)
		else
			reg_Y = peek(reg_PC+PRGROM2-#C000)
		end if	
		reg_PC += 1
		if reg_Y then
			if reg_Y<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- ROR 
	elsif op = #6A then
		--puts(1,"#6A\n")
		if Carry then
			reg_A += #100
		end if
		if and_bits(reg_A,1) then
			Carry = 1
		else
			Carry = 0
		end if
		reg_A = floor(reg_A/2)
		if reg_A then
			Zero = 0
			if reg_A>=#80 then
				Negative = 1
			else
				Negative = 0
			end if
		else
			Zero = 1
			Negative = 0
			
		end if
		cycle += 2.0
	
	-- STY aa
	elsif op = #84 then
		--puts(1,"#84\n")
		write_byte(fetch_byte(),reg_Y)
		cycle += 3.0
	
	-- Illegal opcode
	elsif op = #02 then
		puts(1,"#02\n")

	-- TXA 
	elsif op = #8A then
		--puts(1,"#8A\n")
		reg_A = reg_X
		if reg_A then
			Zero = 0
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- ROL 
	elsif op = #2A then
		--puts(1,"#2A\n")
		reg_A += reg_A+Carry
		if reg_A<#100 then
			Carry = 0
		else
			Carry = 1
			reg_A = and_bits(reg_A,#FF)
		end if
		if reg_A then
			Zero = 0
			if reg_A>=#80 then
				Negative = 1
			else
				Negative = 0
			end if
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- ROL aa
	elsif op = #26 then
		--puts(1,"#26\n")
		if reg_PC<#C000 then
			address = peek(reg_PC+PRGROM1-#8000)
		else
			address = peek(reg_PC+PRGROM2-#C000)
		end if
		reg_PC += 1
		ROL_()
		cycle += 5.0	
	
	-- ADC #aa
	elsif op = #69 then
		--puts(1,"#69\n")
		if reg_PC<#C000 then
			operand = peek(reg_PC+PRGROM1-#8000)
		else
			operand = peek(reg_PC+PRGROM2-#C000)
		end if		
		reg_PC += 1
		ADC_()
		cycle += 2.0
	
	-- ORA aa
	elsif op = #05 then
		--puts(1,"#05\n")
		operand = read_byte(fetch_byte())
		ORA_()
		cycle += 3.0
	
	-- ASL aa
	elsif op = #06 then
		--puts(1,"#06\n")
		address = fetch_byte()
		ASL_()
		cycle += 5.0
	
	-- INC aa
	elsif op = #E6 then
		--puts(1,"#E6\n")
		address = fetch_byte()
		INC_()
		cycle += 3.0
	
	-- TYA 
	elsif op = #98 then
		--puts(1,"#98\n")
		reg_A = reg_Y
		if reg_A then
			Zero = 0
			if reg_A>=#80 then
				Negative = 1
			else
				Negative = 0
			end if
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0

	-- STA (aa),Y
	elsif op = #91 then
		--puts(1,"#91\n")
		write_byte(iny8post(),reg_A)
		cycle += 6.0
	
	-- LDX #aa
	elsif op = #A2 then
		--puts(1,"#A2\n")
		if reg_PC<#C000 then
			reg_X = peek(reg_PC+PRGROM1-#8000)
		else
			reg_X = peek(reg_PC+PRGROM2-#C000)
		end if	
		reg_PC += 1
		if reg_X then
			if reg_X<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- CPX #aa
	elsif op = #E0 then
		--puts(1,"#E0\n")
		--puts(1,"cpx #aa\n")
		if reg_PC<#C000 then
			operand = reg_X-peek(reg_PC+PRGROM1-#8000)
		else
			operand = reg_X-peek(reg_PC+PRGROM2-#C000)
		end if		
		reg_PC += 1
		CMP_()
		cycle += 2.0
	
	-- SBC aaaa,Y
	elsif op = #F9 then
		--puts(1,"#F9\n")
		if reg_PC<#C000 then
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
	elsif op = #C0 then
		--puts(1,"#C0\n")
		if reg_PC<#C000 then
			operand = reg_Y-peek(reg_PC+PRGROM1-#8000)
		else
			operand = reg_Y-peek(reg_PC+PRGROM2-#C000)
		end if		
		reg_PC += 1
		CMP_()
		cycle += 2.0
	
	-- LSR aa
	elsif op = #46 then
		--puts(1,"#46\n")
		address = fetch_byte()
		LSR_()
		cycle += 5.0
	
	-- DEC aa
	elsif op = #C6 then
		--puts(1,"#C6\n")
		address = fetch_byte()
		DEC_()
		cycle += 4.0
	
	-- ROL aa,X
	elsif op = #36 then
		--puts(1,"#36\n")
		address = zpx8()
		ROL_()
		cycle += 6.0
	
	-- JMP (aaaa)
	elsif op = #6C then
		--puts(1,"#6C\n")
		reg_PC = read_word(fetch_word())
		cycle += 5.0
	
	-- CPX aa
	elsif op = #E4 then
		--puts(1,"#E4\n")
		operand = reg_X-read_byte(fetch_byte())
		CMP_()
		cycle += 3.0
	
	-- STX aaaa
	elsif op = #8E then
		--puts(1,"#8E\n")
		if reg_PC<#C000 then
			temp = PRGROM1+reg_PC-#8000
		else
			temp = PRGROM2+reg_PC-#C000
		end if
		address = peek(temp) + peek(temp+1)*#100
		reg_PC += 2
		write_byte(address,reg_X)
		cycle += 4.0
	
	-- LDX aa
	elsif op = #A6 then
		--puts(1,"#A6\n")
		if reg_PC<#C000 then
			reg_X = read_byte(peek(reg_PC+PRGROM1-#8000))
		else
			reg_X = read_byte(peek(reg_PC+PRGROM2-#C000))
		end if	
		reg_PC += 1
		if reg_X then
			if reg_X<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 3.0
	
	-- STX aa
	elsif op = #86 then
		--puts(1,"#86\n")
		write_byte(fetch_byte(),reg_X)
		cycle += 3.0
		
	-- SBC aaaa
	elsif op = #ED then
		--puts(1,"#ED\n")
		if reg_PC<#C000 then
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
	elsif op = #F5 then
		--puts(1,"#F5\n")
		operand = xor_bits(read_byte(and_bits(fetch_byte()+reg_X,#FF)),#FF)
		ADC_()
		cycle += 4.0
	
	-- DEC aaaa
	elsif op = #CE then
		--puts(1,"#CE\n")
		address = fetch_word()
		DEC_()
		cycle += 4.0
	
	-- EOR aa
	elsif op = #45 then
		--puts(1,"#45\n")
		if reg_PC<#C000 then
			operand = read_byte(peek(reg_PC+PRGROM1-#8000))
		else
			operand = read_byte(peek(reg_PC+PRGROM2-#C000))
		end if
		reg_PC += 1
		EOR_()
		cycle += 3.0
	
	-- LDY aaaa
	elsif op = #AC then
		--puts(1,"#AC\n")
		reg_Y = read_byte(fetch_word())
		if reg_Y then
			if reg_Y<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- CMP aaaa,Y
	elsif op = #D9 then
		--puts(1,"#D9\n")
		operand = reg_A-read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
		CMP_()
		cycle += 4.0

	-- INC aaaa,X
	elsif op = #FE then
		--puts(1,"#FE\n")
		address = and_bits(fetch_word()+reg_X,#FFFF)
		INC_()
		cycle += 4.0
	
	-- ADC aaaa,Y
	elsif op = #79 then
		--puts(1,"#79\n")
		if reg_PC<#C000 then
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
	elsif op = #B4 then
		--puts(1,"#B4\n")
		reg_Y = read_byte(and_bits(fetch_byte()+reg_X,#FF))
		if reg_Y then
			if reg_Y<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- ORA #aa
	elsif op = #09 then
		--puts(1,"#09\n")
		if reg_PC<#C000 then
			operand = peek(reg_PC+PRGROM1-#8000)
		else
			operand = peek(reg_PC+PRGROM2-#C000)
		end if
		reg_PC += 1
		ORA_()
		cycle += 2.0
	
	-- CMP aa,X
	elsif op = #D5 then
		--puts(1,"#D5\n")
		operand = reg_A-read_byte(zpx8())
		CMP_()
		cycle += 4.0
		
	-- INC aaaa
	elsif op = #EE then
		--puts(1,"#EE\n")
		address = fetch_word()
		INC_()
		cycle += 4.0

	-- SBC (aa),Y
	elsif op = #F1 then
		--puts(1,"#F1\n")
		operand = xor_bits(read_byte(iny8post()),#FF)
		ADC_()
		cycle += 5.0

	-- INC aa,X
	elsif op = #F6 then
		--puts(1,"#F6\n")
		address = zpx8()
		INC_()
		cycle += 4.0

	-- ORA aa,X
	elsif op = #15 then
		--puts(1,"#15\n")
		operand = read_byte(zpx8())
		ORA_()
		cycle += 4.0

	-- LDY aa
	elsif op = #A4 then
		--puts(1,"#A4\n")
		if reg_PC<#C000 then
			reg_Y = read_byte(peek(reg_PC+PRGROM1-#8000))
		else
			reg_Y = read_byte(peek(reg_PC+PRGROM2-#C000))
		end if	
		reg_PC += 1
		if reg_Y then
			if reg_Y<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 3.0
	
	-- CMP aaaa,X
	elsif op = #DD then
		--puts(1,"#DD\n")
		operand = reg_A-read_byte(and_bits(fetch_word()+reg_X,#FFFF))
		CMP_()
		cycle += 4.0
	
	-- ORA aaaa
	elsif op = #0D then
		--puts(1,"#0D\n")
		operand = read_byte(fetch_word())
		ORA_()
		cycle += 4.0
	
	-- EOR aaaa
	elsif op = #4D then
		--puts(1,"#4D\n")
		operand = read_byte(fetch_word())
		EOR_()
		cycle += 4.0
	
	-- ADC aa,X
	elsif op = #75 then
		--puts(1,"#75\n")
		operand = read_byte(and_bits(fetch_byte()+reg_X,#FF))
		ADC_()
		cycle += 4.0
	
	-- ORA (aa),Y
	elsif op = #11 then
		--puts(1,"#11\n")
		operand = read_byte(iny8post())
		ORA_()
		cycle += 5.0

	-- AND aa,X
	elsif op = #35 then
		--puts(1,"#35\n")
		operand = read_byte(zpx8())
		AND_()
		cycle += 4.0

	-- STA aaaa,Y
	elsif op = #99 then
		--puts(1,"#99\n")
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
	elsif op = #DE then
		--puts(1,"#DE\n")
		address = fetch_word()+reg_X
		DEC_()
		cycle += 4.0
	
	-- RTI 
	elsif op = #40 then
		--puts(1,"#40\n")
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

	-- BRK 
	elsif op = #00 then
   		push_word(reg_PC+1)
   		temp = Carry+
   		       Zero*Z_FLAG+
   		       Interrupt*I_FLAG+
   		       Decimal*D_FLAG+
   		       B_FLAG+		-- B flag is always set on BRK
   		       32+
   		       Overflow*V_FLAG+
   		       Negative*N_FLAG
   		push(temp)       
   		Interrupt = 1
   		Break = 1
		reg_PC = read_word2(#FFFE)
		cycle += 7.0
	
	-- AND aa
	elsif op = #25 then
		--puts(1,"#25\n")
		operand = read_byte(fetch_byte())
		AND_()
		cycle += 3.0
	
	-- ADC (aa),Y
	elsif op = #71 then
		--puts(1,"#71\n")
		operand = read_byte(iny8post())
		ADC_()
		cycle += 5.0
	
	-- CMP aaaa
	elsif op = #CD then
		--puts(1,"#CD\n")
		operand = reg_A-read_byte(fetch_word())
		CMP_()
		cycle += 4.0
	
	-- LDY aaaa,X
	elsif op = #BC then
		--puts(1,"#BC\n")
		reg_Y = read_byte(fetch_word()+reg_X)
		if reg_Y then
			if reg_Y<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- ROR aa,X
	elsif op = #76 then
		--puts(1,"#76\n")
		address = zpx8()
		ROR_()
		cycle += 6.0

	-- ROR aa
	elsif op = #66 then
		--puts(1,"#66\n")
		address = fetch_byte()
		ROR_()
		cycle += 5.0
	
	-- STY aaaa
	elsif op = #8C then
		--puts(1,"#8C\n")
		if reg_PC<#C000 then
			temp = PRGROM1+reg_PC-#8000
		else
			temp = PRGROM2+reg_PC-#C000
		end if
		address = peek(temp) + peek(temp+1)*#100
		reg_PC += 2
		write_byte(address,reg_Y)
		cycle += 4.0
	
	-- DEC aa,X
	elsif op = #D6 then
		--puts(1,"#D6\n")
		address = zpx8()
		DEC_()
		cycle += 4.0

	-- LDX aaaa
	elsif op = #AE then
		--puts(1,"#AE\n")
		reg_X = read_byte(fetch_word())
		if reg_X then
			if reg_X<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- ORA aaaa,X
	elsif op = #1D then
		--puts(1,"#1D\n")
		operand = read_byte(fetch_word()+reg_X)
		ORA_()
		cycle += 4.0
	
	-- ADC aaaa
	elsif op = #6D then
		--puts(1,"#6D\n")
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
	elsif op = #6E then
		--puts(1,"#6E\n")
		address = fetch_word()
		ROR_()
		cycle += 6.0
	
	-- ROL aaaa
	elsif op = #2E then
		--puts(1,"#2E\n")
		address = fetch_word()
		ROL_()
		cycle += 6.0
	
	-- CPY aa
	elsif op = #C4 then
		--puts(1,"#C4\n")
		operand = reg_Y-read_byte(fetch_byte())
		CMP_()
		cycle += 3.0
	
	-- PLP 
	elsif op = #28 then
		--puts(1,"PLP\n")
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
	elsif op = #08 then
		--puts(1,"PHP\n")
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
	elsif op = #70 then
		--puts(1,"#70\n")
		condition = Overflow
		Branch()
		
	-- LDX aaaa,Y
	elsif op = #BE then
		--puts(1,"#BE\n")
		reg_X = read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
		if reg_X then
			if reg_X<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 4.0
	
	-- SEI 
	elsif op = #78 then
		--puts(1,"#78\n")
		Interrupt = 1
		cycle += 2.0
		
	-- LSR aaaa
	elsif op = #4E then
		--puts(1,"#4E\n")
		address = fetch_word()
		LSR_()
		cycle += 6.0
	
	-- BIT aa
	elsif op = #24 then
		--puts(1,"#24\n")
		operand = read_byte(fetch_byte())
		Negative = (and_bits(operand,N_FLAG)!=0)
		Overflow = (and_bits(operand,V_FLAG)!=0)
		if and_bits(reg_A,operand) then
			Zero = 0
		else
			Zero = 1
			--Negative = 0
		end if
		cycle += 3.0
	
	-- LDX aa,Y
	elsif op = #B6 then
		--puts(1,"#B6\n")
		if reg_PC<#C000 then
			reg_X = read_byte(and_bits(peek(reg_PC+PRGROM1-#8000)+reg_Y,#FF))
		else
			reg_X = read_byte(and_bits(peek(reg_PC+PRGROM2-#C000)+reg_Y,#FF))
		end if	
		reg_PC += 1
		if reg_X then
			if reg_X<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 3.0
	
	-- ADC aaaa,X
	elsif op = #7D then
		--puts(1,"#7D\n")
		operand = read_byte(fetch_word()+reg_X)
		ADC_()
		cycle += 4.0

	-- CMP (aa),Y
	elsif op = #D1 then
		--puts(1,"#D1\n")
		operand = reg_A-read_byte(iny8post())
		CMP_()
		cycle += 5.0

	-- SBC aaaa,X
	elsif op = #FD then
		--puts(1,"#FD\n")
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
	elsif op = #19 then
		--puts(1,"#19\n")
		operand = read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
		ORA_()
		cycle += 4.0

	-- LDA (aa,X)
	elsif op = #A1 then
		--puts(1,"#A1\n")
		reg_A = read_byte(inx8pre())
		if reg_A then
			if reg_A<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 6.0

	-- ROR aaaa,X
	elsif op = #7E then
		--puts(1,"#7E\n")
		address = fetch_word()+reg_X
		ROR_()
		cycle += 7.0

	-- ROL aaaa,X
	elsif op = #3E then
		--puts(1,"#3E\n")
		address = fetch_word()+reg_X
		ROL_()
		cycle += 7.0

	-- STY aa,X
	elsif op = #94 then
		--puts(1,"#94\n")
		write_byte(zpx8(),reg_Y)
		cycle += 4.0

	-- AND aaaa,Y
	elsif op = #39 then
		--puts(1,"#39\n")
		operand = read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
		AND_()
		cycle += 4.0

	-- AND aaaa,X
	elsif op = #3D then
		--puts(1,"#3D\n")
		operand = read_byte(and_bits(fetch_word()+reg_X,#FFFF))
		AND_()
		cycle += 4.0

	-- EOR aaaa,Y
	elsif op = #59 then
		--puts(1,"#59\n")
		operand = read_byte(and_bits(fetch_word()+reg_Y,#FFFF))
		EOR_()
		cycle += 4.0

	-- AND aaaa
	elsif op = #2D then
		operand = read_byte(fetch_word())
		AND_()
		cycle += 4.0

	-- CPY aaaa
	elsif op = #CC then
		operand = reg_Y-read_byte(fetch_word())
		CMP_()
		cycle += 4.0
	
	-- LSR aaaa,X
	elsif op = #5E then
		address = fetch_word()+reg_X
		LSR_()
		cycle += 7.0
	
	-- TXS 
	elsif op = #9A then
		--puts(1,"#9A\n")
		reg_S = reg_X
		cycle += 2.0
		
	-- CLD 
	elsif op = #D8 then
		--puts(1,"#D8\n")
		Decimal = 0
		cycle += 2.0
		
	-- ASL aaaa
	elsif op = #0E then
		--puts(1,"#0E\n")
		address = fetch_word()
		ASL_()
		cycle += 6.0
	
	-- SLO aa
	elsif op = #07 then
		--puts(1,"#07\n")
		--reg_PC += 1
		cycle += 3.0

	-- TSX 
	elsif op = #BA then
		--puts(1,"#BA\n")
		reg_X = reg_S
		if reg_X then
			if reg_X<#80 then
				Negative = 0
			else
				Negative = 1
			end if
			Zero = 0
		else
			Zero = 1
			Negative = 0
		end if
		cycle += 2.0
	
	-- CLI 
	elsif op = #58 then
		--puts(1,"#58\n")
		Interrupt = 0
		cycle += 2.0

	-- EOR aa,X
	elsif op = #55 then
		--puts(1,"#55\n")
		operand = read_byte(zpx8())
		EOR_()
		cycle += 4.0

	-- STX aa,Y
	elsif op = #96 then
		--puts(1,"#96\n")
		write_byte(zpy8(),reg_X)
		cycle += 4.0

	-- STA (aa,X)
	elsif op = #81 then
		--puts(1,"#81\n")
		write_byte(inx8pre(),reg_A)
		cycle += 6.0

	-- EOR (aa),Y
	elsif op = #51 then
		--puts(1,"#51\n")
		operand = read_byte(iny8post())
		EOR_()
		cycle += 5.0

	-- CPX aaaa
	elsif op = #EC then
		--puts(1,"#EC\n")
		operand = reg_X-read_byte(fetch_word())
		CMP_()
		cycle += 4.0

	-- ASL aa,X
	elsif op = #16 then
		--puts(1,"#16\n")
		address = zpx8()
		ASL_()
		cycle += 6.0
	
	-- AND (aa),Y
	elsif op = #31 then
		--puts(1,"#31\n")
		operand = read_byte(iny8post())
		AND_()
		cycle += 5.0
		
	-- CLV 
	elsif op = #B8 then
		--puts(1,"#B8\n")
		Overflow = 0
		cycle += 2.0

	-- EOR aaaa,X
	elsif op = #5D then
		--puts(1,"#5D\n")
		operand = read_byte(fetch_word()+reg_X)
		EOR_()
		cycle += 4.0

	-- LSR aa,X
	elsif op = #56 then
		--puts(1,"#56\n")
		address = zpx8()
		LSR_()
		cycle += 6.0
	
	-- ISB aaaa,X
	elsif op = #FF then
		--puts(1,"#FF\n")
		--reg_PC += 2
		cycle += 5.0

	-- SED 
	elsif op = #F8 then
		--puts(1,"#F8\n")
		Decimal = 1
		cycle += 2.0
		
	-- SHA aaaa,Y
	elsif op = #9F then
		puts(1,"#9F\n")

	-- Illegal opcode
	elsif op = #7F then
		--puts(1,"#7F\n")
		cycle += 2.0

	-- RRA aa
	elsif op = #67 then
		--puts(1,"#67\n")
		--reg_PC += 1
		cycle += 5.0

	-- RLA aa,X
	elsif op = #37 then
		--puts(1,"#37\n")
		--reg_PC += 1
		cycle += 6.0

	-- RLA (aa),Y
	elsif op = #33 then
		puts(1,"#33\n")

	-- SLO aaaa
	elsif op = #0F then
		--puts(1,"#0F\n")
		--reg_PC += 2
		cycle += 5.0

	-- NOP aaaa,X
	elsif op = #FC then
		--puts(1,"#FC\n")
		--reg_PC += 2
		cycle += 4.0

	-- ISB aaaa,Y
	elsif op = #FB then
		--puts(1,"#FB\n")
		--reg_PC += 2
		cycle += 5.0

	-- NOP 
	elsif op = #FA then
		puts(1,"#FA\n")
		cycle += 2.0

	-- ISB aa,X
	elsif op = #F7 then
		puts(1,"#F7\n")

	-- NOP aa,X
	elsif op = #F4 then
		puts(1,"#F4\n")

	-- Illegal opcode
	elsif op = #F3 then
		--puts(1,"#F3\n")

	-- Illegal opcode
	elsif op = #F2 then
		--puts(1,"#F2\n")

	-- ISB aaaa
	elsif op = #EF then
		--puts(1,"#EF\n")

	-- Illegal opcode
	elsif op = #EB then
		--puts(1,"#EB\n")

	-- ISB aa
	elsif op = #E7 then
		--puts(1,"#E7\n")

	-- ISB (aa,X)
	elsif op = #E3 then
		--puts(1,"#E3\n")

	-- NOP #aa
	elsif op = #E2 then
		--puts(1,"#E2\n")

	-- SBC (aa,X)
	elsif op = #E1 then
		--puts(1,"#E1\n")
		operand = xor_bits(read_byte(inx8pre()),#FF)
		ADC_()
		cycle += 6.0

	-- Illegal opcode
	elsif op = #DF then
		--puts(1,"#DF\n")

	-- NOP aaaa,X
	elsif op = #DC then
		--puts(1,"#DC\n")

	-- DCP aaaa,Y
	elsif op = #DB then
		puts(1,"#DB\n")

	-- Illegal opcode
	elsif op = #DA then
		puts(1,"#DA\n")

	-- Illegal opcode
	elsif op = #D7 then
		--puts(1,"#D7\n")

	-- Illegal opcode
	elsif op = #D4 then
		--puts(1,"#D4\n")

	-- Illegal opcode
	elsif op = #D3 then
		--puts(1,"#D3\n")

	-- Illegal opcode
	elsif op = #D2 then
		--puts(1,"#D2\n")

	-- DCP aaaa,X
	elsif op = #CF then
		--puts(1,"#CF\n")

	-- Illegal opcode
	elsif op = #CB then
		--puts(1,"#CB\n")

	-- Illegal opcode
	elsif op = #C7 then
		--puts(1,"#C7\n")

	-- DCP (aa,X)
	elsif op = #C3 then
		--puts(1,"#C3\n")

	-- NOP #aa
	elsif op = #C2 then
		--puts(1,"#C2\n")
		--reg_PC += 1

	-- CMP (aa,X)
	elsif op = #C1 then
		--puts(1,"#C1\n")
		operand = reg_A-read_byte(inx8pre())
		CMP_()
		cycle += 7.0

	-- LAX aaaa,Y
	elsif op = #BF then
		puts(1,"#BF\n")

	-- LAS aaaa,Y
	elsif op = #BB then
		puts(1,"#BB\n")

	-- Illegal opcode
	elsif op = #B7 then
		--puts(1,"#B7\n")
		cycle += 1.0

	-- Illegal opcode
	elsif op = #B3 then
		--puts(1,"#B3\n")
		cycle += 1.0

	-- Illegal opcode
	elsif op = #B2 then
		--puts(1,"#B2\n")
		cycle += 1.0

	-- Illegal opcode
	elsif op = #AF then
		--puts(1,"#AF\n")
		cycle += 1.0

	-- LSA #aa
	elsif op = #AB then
		puts(1,"#AB\n")

	-- Illegal opcode
	elsif op = #A7 then
		puts(1,"#A7\n")

	-- Illegal opcode
	elsif op = #A3 then
		puts(1,"#A3\n")

	-- Illegal opcode
	elsif op = #9E then
		puts(1,"#9E\n")

	-- SHY aaaa,X
	elsif op = #9C then
		puts(1,"#9C\n")

	-- SHS aaaa,Y
	elsif op = #9B then
		puts(1,"#9B\n")

	-- SAX aa,Y
	elsif op = #97 then
		puts(1,"#97\n")

	-- SHA (aa),Y
	elsif op = #93 then
		puts(1,"#93\n")

	-- Illegal opcode
	elsif op = #92 then
		puts(1,"#92\n")

	-- Illegal opcode
	elsif op = #8F then
		--puts(1,"#8F\n")
		cycle += 2.0

	-- ANE #aa
	elsif op = #8B then
		puts(1,"#8B\n")

	-- Illegal opcode
	elsif op = #89 then
		puts(1,"#89\n")

	-- Illegal opcode
	elsif op = #87 then
		puts(1,"#87\n")

	-- Illegal opcode
	elsif op = #83 then
		puts(1,"#83\n")

	-- Illegal opcode
	elsif op = #82 then
		puts(1,"#82\n")

	-- Illegal opcode
	elsif op = #80 then
		puts(1,"#80\n")
		cycle += 2.0

	-- NOP aaaa,X
	elsif op = #7C then
		puts(1,"#7C\n")

	-- RRA aaaa,Y
	elsif op = #7B then
		puts(1,"#7B\n")

	-- NOP 
	elsif op = #7A then
		puts(1,"#7A\n")

	-- RRA aa,X
	elsif op = #77 then
		puts(1,"#77\n")

	-- Illegal opcode
	elsif op = #74 then
		puts(1,"#74\n")

	-- Illegal opcode
	elsif op = #73 then
		puts(1,"#73\n")

	-- Illegal opcode
	elsif op = #72 then
		puts(1,"#72\n")

	-- Illegal opcode
	elsif op = #6F then
		puts(1,"#6F\n")

	-- Illegal opcode
	elsif op = #6B then
		puts(1,"#6B\n")

	-- NOP aa
	elsif op = #64 then
		puts(1,"#64\n")

	-- RRA (aa,X)
	elsif op = #63 then
		--puts(1,"#63\n")
		--reg_PC += 1
		cycle += 4.0

	-- Illegal opcode
	elsif op = #62 then
		puts(1,"#62\n")

	-- ADC (aa,X)
	elsif op = #61 then
		--puts(1,"#61\n")
		operand = read_byte(inx8pre())
		ADC_()
		cycle += 6.0

	-- Illegal opcode
	elsif op = #5F then
		puts(1,"#5F\n")

	-- NOP aaaa,X
	elsif op = #5C then
		--puts(1,"#5C\n")
		--reg_PC += 2
		cycle += 4.0

	-- SRE aaaa,Y
	elsif op = #5B then
		puts(1,"#5B\n")

	-- NOP 
	elsif op = #5A then
		--puts(1,"#5A\n")
		cycle += 2.0

	-- Illegal opcode
	elsif op = #57 then
		puts(1,"#57\n")

	-- NOP aa,X
	elsif op = #54 then
		--puts(1,"#54\n")
		--reg_PC += 1
		cycle += 2.0

	-- SRE (aa),Y
	elsif op = #53 then
		puts(1,"#53\n")

	-- Illegal opcode
	elsif op = #52 then
		puts(1,"#52\n")

	-- SRE aaaa
	elsif op = #4F then
		--puts(1,"#4F\n")
		--reg_PC += 2
		cycle += 1.0

	-- ASR #aa
	elsif op = #4B then
		--puts(1,"#4B\n")
		--reg_PC += 1
		cycle += 2.0

	-- Illegal opcode
	elsif op = #47 then
		puts(1,"#47\n")

	-- NOP aa
	elsif op = #44 then
		puts(1,"#44\n")

	-- SRE (aa,X)
	elsif op = #43 then
		puts(1,"#43\n")

	-- Illegal opcode
	elsif op = #42 then
		puts(1,"#42\n")

	-- EOR (aa,X)
	elsif op = #41 then
		--puts(1,"#41\n")
		operand = read_byte(inx8pre())
		EOR_()
		cycle += 6.0

	-- RLA aaaa,X
	elsif op = #3F then
		--puts(1,"#3F\n")
		--reg_PC += 2
		cycle += 1.0

	-- NOP aaaa,X
	elsif op = #3C then
		puts(1,"#3C\n")

	-- RLA aaaa,Y
	elsif op = #3B then
		puts(1,"#3B\n")

	-- NOP 
	elsif op = #3A then
		--puts(1,"#3A\n")
		cycle += 2.0

	-- NOP aa,X
	elsif op = #34 then
		--puts(1,"#34\n")
		--reg_PC += 1
		cycle += 2.0
		
	-- Illegal opcode
	elsif op = #32 then
		--puts(1,"#32\n")
		cycle += 2.0
		
	-- RLA aaaa
	elsif op = #2F then
		--puts(1,"#2F\n")
		--reg_PC += 2
		cycle += 2.0

	-- ANC #aa
	elsif op = #2B then
		--puts(1,"#2B\n")

	-- RLA aa
	elsif op = #27 then
		--puts(1,"#27\n")
		--reg_PC += 2

	-- RLA (aa,X)
	elsif op = #23 then
		--puts(1,"#23\n")

	-- Illegal opcode
	elsif op = #22 then
		--puts(1,"#22\n")
		cycle += 2.0

	-- AND (aa,X)
	elsif op = #21 then
		--puts(1,"#21\n")
		operand = read_byte(inx8pre())
		AND_()
		cycle += 3.0
	
	-- SLO aaaa,X
	elsif op = #1F then
		--puts(1,"#1F\n")
		--reg_PC += 2
		cycle += 2.0

	-- ASL aaaa,X
	elsif op = #1E then
		--puts(1,"#1E\n")
		address = fetch_word()+reg_X
		ASL_()
		cycle += 7.0
		
	-- NOP aaaa,X
	elsif op = #1C then
		--puts(1,"#1C\n")

	-- SLO aaaa,Y
	elsif op = #1B then
		puts(1,"#1B\n")

	-- NOP 
	elsif op = #1A then
		--puts(1,"#1A\n")
		cycle += 2.0

	-- SLO aa,X
	elsif op = #17 then
		--puts(1,"#17\n")
		--reg_PC += 1
		cycle += 3.0

	-- NOP aa,X
	elsif op = #14 then
		--puts(1,"#14\n")

	-- SLO (aa),Y
	elsif op = #13 then
		--puts(1,"#13\n")

	-- Illegal opcode
	elsif op = #12 then
		puts(1,"#12\n")
		cycle += 2.0

	-- NOP aaaa
	elsif op = #0C then
		--puts(1,"#0C\n")
		--reg_PC += 2
		cycle += 4.0

	-- ANC #aa
	elsif op = #0B then
		--puts(1,"#0B\n")
		--reg_PC += 1
		cycle += 2.0

	-- NOP aa
	elsif op = #04 then
		--puts(1,"#04\n")
		--reg_PC += 1
		cycle += 3.0

	-- SLO (aa,X)
	elsif op = #03 then
		--puts(1,"#03\n")
		--reg_PC += 1
		cycle += 2.0

	-- ORA (aa,X)
	elsif op = #01 then
		--puts(1,"#01\n")
		operand = read_byte(inx8pre())
		ORA_()
		cycle += 6.0		

end if
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
