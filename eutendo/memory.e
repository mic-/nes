include machine.e
--include safe.e as safe


global constant
    PPUCTR1  = #2000,
    PPUCTR2  = #2001,
    PPUSTAT  = #2002,
    SPRRADR  = #2003,
    SPRRIO   = #2004,
    VRAMADR1 = #2005,
    VRAMADR2 = #2006,
    VRAMIO   = #2007,
    SPRDMA   = #4014

global constant
    HORIZONTAL = 0,
    VERTICAL   = 1

-- REGISTERS
global integer
    reg_A,  -- accumulator
    reg_X,  -- index register
    reg_Y,  -- secondary index register
    reg_P,  -- processor status register
    reg_S,  -- stack register
    reg_PC  -- program counter


global integer
    hScroll,      -- horizontal scroll value
    vScroll,      -- vertical scroll value
    scrollWrite,  -- scroll register write counter
    firstVRAMRead,
    vramPtr,
    buttonInx,
    logfile,
    vramMirroring,
    vramBuffer,
    vramAdrFlipflop,
    mapper,
    nPrgPages,    -- number of 16k PRG-ROM pages
    nChrPages,    -- number of 8k CHR-ROM pages
    lines,
    scanline,
    chrRomPage,
    prgRomPage,
    in_vblank,
    refreshPatternTable,
    scrollLP,

    mmc1Buffer,
    mmc1BufferMask,
    mmc1RegisterSelectMask,
    mmc1OneScreenMirroring,
    mmc1PrgSwitchingArea,
    mmc1PrgSwitchingSize,
    mmc1Reg0Bit4,
    mmc1VROMSelect0,
    mmc1VROMSelect1,
    mmc1Select256K0,
    mmc1Select256K1,
    mmc1SelectROMBank,
    mmc1Register0,
    mmc1Register1,
    mmc1Register2,
    mmc1Register3

global atom
        RAM,
        RAMM1,
        RAMM2,
        RAMM3,
        EXROM,
        SRAM,
        PRGROM1,
        PRGROM2,
        VRAM,
        SPRRAM,
        PATTBL0,
        PATTBL1,
        chrMem,
        prgMem

global atom cycle

global sequence buttons,
        scrollList,
        ntmirrors

integer sprRAMOffs
sequence buttonCopy


global procedure init_memory(atom memory)
    RAM   = memory
    RAMM1 = memory + #0800
    RAMM2 = memory + #1000
    RAMM3 = memory + #1800
    EXROM = memory + #4020
    SRAM  = memory + #6000
    --PRGROM1 = memory + #8000
    --PRGROM2 = memory + #C000
    VRAM = memory + #10000
    SPRRAM = memory + #14000

    mem_set(RAM, 0, #14100)
    sprRAMOffs = 0
    hScroll = 0
    vScroll = 0
    scrollWrite = 0
    firstVRAMRead = 1
    vramBuffer = 0
    vramPtr = 0
    buttonInx = 0
    buttons = repeat(0,8)
    buttonCopy = buttons
    --mapper = 0
    scanline = 0
    vramAdrFlipflop = 0

    mmc1Buffer	= 0
    mmc1BufferMask	= 1
    mmc1RegisterSelectMask = 0
    mmc1OneScreenMirroring = 0
    mmc1PrgSwitchingArea = 0
    mmc1PrgSwitchingSize = 0
    mmc1Reg0Bit4 = 0
    mmc1VROMSelect0 = 0
    mmc1VROMSelect1 = 0
    mmc1Select256K0 = 0
    mmc1Select256K1 = 0
    mmc1SelectROMBank = 0

    mmc1Register0 = 0
    mmc1Register1 = 0
    mmc1Register2 = 0
    mmc1Register3 = 0
end procedure



-- Soft reset
global procedure reset_memory()
    --sprRAMOffs = 0
    --hScroll = 0
    --vScroll = 0
    --scrollWrite = 0
    firstVRAMRead = 1
    vramBuffer = 0
    vramPtr = 0
    buttonInx = 0
    buttons = repeat(0,8)
    buttonCopy = buttons
    --mapper = 0
    scanline = 0
    vramAdrFlipflop = 0

    mmc1Buffer = 0
    mmc1BufferMask = 1
    mmc1RegisterSelectMask = 0
    mmc1OneScreenMirroring = 0
    mmc1PrgSwitchingArea = 0
    mmc1PrgSwitchingSize = 0
    mmc1Reg0Bit4 = 0
    mmc1VROMSelect0 = 0
    mmc1VROMSelect1 = 0
    mmc1Select256K0 = 0
    mmc1Select256K1 = 0
    mmc1SelectROMBank = 0

    mmc1Register0 = 0
    mmc1Register1 = 0
    mmc1Register2 = 0
    mmc1Register3 = 0
end procedure



-- Read one byte (8 bits) from PC
global function fetch_byte()
    if reg_PC < #C000 then
        reg_PC += 1
        return peek(reg_PC+PRGROM1-#8001)
    end if
    reg_PC += 1
    return peek(reg_PC+PRGROM2-#C001)
end function



-- Read one word (16 bits) from PC
global function fetch_word()
    integer a
    if reg_PC < #C000 then
        a = PRGROM1 + reg_PC - #8000
    else
        a = PRGROM2 + reg_PC - #C000
    end if
    reg_PC += 2
    return peek(a) + peek(a+1)*#100
end function



--vramInaccessible()
--   return (enabled() and lines < 240)


global function read_byte(integer addr)
    integer b,c

    if addr < #2000 then
        b = peek(RAM+and_bits(addr,#7FF))

    elsif addr < #4000 then
        addr = and_bits(addr,7)+#2000

        if addr <= PPUCTR2 then
            b = peek(addr+RAM)

        elsif addr = PPUSTAT then
            b = peek(addr+RAM)
            --poke(addr+RAM,and_bits(b,#3F))
            --poke(RAM+#2005,0)
            --poke(RAM+#2006,0)
            --scrollWrite = 0
            --vramPtr = 0
            c = or_bits(and_bits(vramBuffer, #1F), b)
            if and_bits(c, #80) then
                poke(addr+RAM,and_bits(b,#60))
            end if
            b = c
            vramAdrFlipflop = 0

            --if not in_vblank then
            --    if not and_bits(peek(RAM+#2000),#80) then
            --        poke(RAM+#2000,and_bits(peek(RAM+#2000),#FC))
            --    end if
            --end if

        elsif addr = SPRRIO then
            return peek(SPRRAM+peek(RAM+SPRRADR))

        elsif addr = VRAMADR2 then
            return vramBuffer

        elsif addr=VRAMIO then
            --if (not firstVRAMRead) and vramPtr<#3F00 then
            --    b = peek(VRAM+vramPtr)
            --elsif vramPtr>=#3F00 then
            --    b = peek(VRAM+vramPtr)
            --else
            --    b = 0 --vramBuffer
            --end if
            --if not firstVRAMRead then
            --  vramPtr += 1 + (and_bits(peek(RAM+PPUCTR1),4)!=0)*31
            --  vramPtr = and_bits(vramPtr,#3FFF)
            --end if
            --firstVRAMRead = 0
            --if vramPtr<#3F00 then
            --  vramBuffer = peek(VRAM+vramPtr)
            --end if

            addr = and_bits(vramPtr,#3FFF)
            b = vramBuffer
            vramPtr += 1 + (and_bits(peek(RAM+PPUCTR1),4)!=0)*31
            if addr>=#3000 then
                if addr>=#3F00 then
                    if and_bits(addr,#10) then
                        return peek(VRAM+addr)
                    else
                        return peek(VRAM+addr)
                    end if
                end if
            end if
            vramBuffer = peek(VRAM+addr)

        else
            printf(1,"Trying to read from %04x\n",addr)
        end if

    elsif addr = #4016 then
        if buttonInx>0 and buttonInx<9 then
            b = #40 + buttonCopy[buttonInx]
        elsif buttonInx=17 or buttonInx=20 then
            b = 1  -- joypad 1 connected
        else
            b = 0
        end if
        if buttonInx>0 then
            buttonInx += 1
        end if
        if buttonInx>24 then
            buttonInx = 0
        end if

    elsif addr=#4017 then
        b = 0

    elsif addr >= #7000 and addr < #7200 then
        b = peek(RAM+addr)

    elsif addr >= #8000 then
        if addr < #C000 then
            b = peek(PRGROM1+addr-#8000)
        else
            b = peek(PRGROM2+addr-#C000)
        end if

    else 
        printf(logfile,"Illegal read from %04x at PC = %04x\n",{addr,reg_PC})
        b = 0
    end if

    return b
end function



global function read_word(integer addr)
    integer i

    i = read_byte(addr)
    -- Don't increase high byte of address on page wrap
    addr = and_bits(addr+1,#FF)+and_bits(addr,#FF00)
    --addr += 1

    return i + read_byte(addr)*#100
end function



global function read_word2(integer addr)
    integer i,j

    if addr < #8000 then
        i = peek(RAM+addr)
        return i + peek(RAM+addr+1)*#100
    elsif addr<#C000 then
        i = peek(PRGROM1+addr-#8000)
        return i + peek(PRGROM1+addr-#7FFF)*#100
    else
        i = peek(PRGROM2+addr-#C000)
        return i + peek(PRGROM2+addr-#BFFF)*#100
    end if
end function



procedure swap_prg_page(integer dest, integer size, integer bank)
    if not nPrgPages then
        -- Should never happen
        return
    end if

    if size = 32 then
        PRGROM1 = prgMem + and_bits(bank,floor(nPrgPages/2)-1)*#8000
        PRGROM2 = PRGROM1 + #4000

    elsif size = 16 then
        if dest = #8000 then
            PRGROM1 = prgMem + and_bits(bank,nPrgPages-1)*#4000
        elsif dest = #C000 then
            PRGROM2 = prgMem + and_bits(bank,nPrgPages-1)*#4000
        end if
    end if
end procedure



procedure swap_chr_page(integer dest, integer size, integer bank)
    if not nChrPages then
        return
    end if

    if size = 8 then
        PATTBL0 = chrMem + and_bits(bank,nChrPages-1)*#2000
        PATTBL1 = PATTBL0 + #1000
        refreshPatternTable = 1
    elsif size = 4 then
        if dest = #0000 then
            PATTBL0 = chrMem + and_bits(bank,nChrPages*2 - 1) * #1000
            refreshPatternTable = 1
        elsif dest = #1000 then
            PATTBL1 = chrMem + and_bits(bank,nChrPages*2 - 1) * #1000
            refreshPatternTable = 1
        end if
    end if
end procedure


-- MMC1 code translated from Matt Conte's ShatBox
procedure mmc1_write(integer addr, integer b)
    integer reg, mirror, bankSelect

    reg = floor(addr / #2000)

    if and_bits(b, #80) then
        mmc1Register0 = or_bits(mmc1Register0,#0C)
        mmc1BufferMask = 1
        mmc1Buffer = 0
        return
    end if

    if mmc1RegisterSelectMask != reg then
        mmc1RegisterSelectMask = reg
        mmc1BufferMask = 1
        mmc1Buffer = 0
    end if

    if and_bits(b, 1) then
        mmc1Buffer = or_bits(mmc1Buffer, mmc1BufferMask)
    end if

    mmc1BufferMask += mmc1BufferMask
    if mmc1BufferMask != 32 then
        return
    end if

    mmc1BufferMask = 1
    b = mmc1Buffer
    if reg = 0 then
        mmc1Register0 = b
    elsif reg = 1 then
        mmc1Register1 = b
    elsif reg = 2 then
        mmc1Register2 = b
    elsif reg = 3 then
        mmc1Register3 = b
    end if
    mmc1Buffer = 0

    if reg = 0 then
        if not and_bits(b,2) then
            -- One-screen mirroring
            mirror = and_bits(b,1)*#400
            ntmirrors = {mirror,mirror,mirror,mirror} + #2000
        elsif and_bits(b,1) then
            -- Horizontal mirroring
            ntmirrors = {#2000,#2000,#2400,#2400}
        else
            -- Vertical mirroring
            ntmirrors = {#2000,#2400,#2000,#2400}
        end if

    elsif reg = 1 then
        if and_bits(mmc1Register0, #10) then
            swap_chr_page(#0000, 4, b)
        else
            swap_chr_page(#0000, 8, floor(b/2))
        end if

    elsif reg=2 then
        if and_bits(mmc1Register0, #10) then
            swap_chr_page(#1000, 4, b)
        end if

    elsif reg = 3 then
        -- 512K carts
        if nPrgPages = #20 then
            --mBankSelect = (mRegs[1] & 0x10) ? 0 : 0x10;

        -- 1M carts
        elsif nPrgPages = #40 then
--          if (mRegs[0] & 0x10)
--              mBankSelect = (mRegs[1] & 0x10) | ((mRegs[2] & 0x10) << 1);
--          else
--              mBankSelect = (mRegs[1] & 0x10) << 1;
        else
            bankSelect = 0
        end if

        if not and_bits(mmc1Register0, 8) then
            swap_prg_page(#8000, 32, floor(mmc1Register3/1)+floor(bankSelect/2))
        elsif and_bits(mmc1Register0, 4) then
            swap_prg_page(#8000, 16, and_bits(mmc1Register3,#0F)+bankSelect)
        else
            swap_prg_page(#C000, 16, and_bits(mmc1Register3,#0F)+bankSelect)
        end if
    end if
end procedure




global procedure write_byte(integer addr, integer b)
    integer temp

    if addr < #2000 then
        poke(RAM+and_bits(addr,#7FF), b)

    elsif addr < #4000 then
        addr = and_bits(addr,7)+#2000

        if addr = PPUCTR1 or addr = PPUCTR2 then
            poke(RAM+addr, b)

        elsif addr = SPRRADR then
            poke(RAM+SPRRADR, b)

        elsif addr = SPRRIO then
            sprRAMOffs = peek(RAM+SPRRADR)
            poke(SPRRAM+sprRAMOffs, b)
            poke(RAM+SPRRADR, sprRAMOffs+1)

        elsif addr = VRAMADR1 then
            if vramAdrFlipflop then
                vScroll = b
                if vScroll > 239 then
                    vScroll = 0 ---= 240
                end if
            else
                hScroll = b
            end if
            vramAdrFlipflop = 1-vramAdrFlipflop

        elsif addr = VRAMADR2 then
            --vramPtr = and_bits(vramPtr,#FF)*#100 + b
            if vramAdrFlipflop then
                vramPtr = and_bits(vramPtr,#FF00) + b
            else
                vramPtr = and_bits(vramPtr,#00FF) + and_bits(b*#100,#3F00)
            end if
            vramAdrFlipflop = 1-vramAdrFlipflop
        
        elsif addr = VRAMIO then
            if not and_bits(peek(RAM+PPUSTAT),#10) then
                addr = and_bits(vramPtr, #3FFF)
                if addr >= #2000 then
                    if addr >= #3000 and addr < #3F00 then
                        addr = xor_bits(addr, #1000)
                    end if

                elsif mapper=2 or mapper=71 or (mapper=1 and nChrPages=0) then
                    poke(PATTBL0+addr,b)
                    refreshPatternTable = 1
                    --return
                end if

                if addr >= #2000 and addr < #3000 then
                    --if vramMirroring=VERTICAL then
                    --  if and_bits(vramPtr,#800) then
                    --      poke(VRAM+vramPtr-#800,b)
                    --  else
                    --      poke(VRAM+vramPtr+#800,b)
                    --  end if
                    --elsif vramMirroring=HORIZONTAL then
                    --  if and_bits(vramPtr,#400) then
                    --      poke(VRAM+vramPtr-#400,b)
                    --  else
                    --      poke(VRAM+vramPtr+#400,b)
                    --  end if
                    --end if

                        --printf(1,"Mirrored write to %04x to %04x\n",
                        --         {vramPtr,ntmirrors[floor(and_bits(vramPtr,#C00)/#400)+1]})
                        temp = ntmirrors[floor(and_bits(addr,#C00)/#400)+1]+and_bits(addr,#3FF)
                        poke(VRAM+temp,b)
                        --poke(VRAM+xor_bits(temp,#400),b)
                        --poke(VRAM+addr,b)
                        --return
                end if

                -- Palette mirroring
                if addr>=#3F00 and addr<=#3FFF then
                    if not and_bits(vramPtr,3) then
                        addr = and_bits(addr,#3F0F)
                        poke(VRAM+addr,b)
                        poke(VRAM+addr+#10,b)
                    else
                        poke(VRAM+addr,b)
                    end if
                end if

                vramPtr += 1 + (and_bits(peek(RAM+PPUCTR1),4)!=0)*31
                vramPtr = and_bits(vramPtr,#3FFF)
                firstVRAMRead = 0
            end if
        end if

    elsif addr = SPRDMA then
        -- Transfer 256 bytes from b*#100 to spr-ram
        mem_copy(SPRRAM,RAM+(and_bits(b,7)*#100), #100)
        --cycle += 513 -- This would mess up scrolling in some games

    elsif addr = #4016 then
        if not and_bits(b,1) then
            if and_bits(peek(RAM+#4016),1) then
                -- read joypad 1
                buttonCopy = buttons
                buttonInx = 1
            end if
        end if
        poke(RAM+#4016, b)

    elsif addr = #4017 then


    elsif addr >= #8000 then
        if mapper = 1 then
            mmc1_write(and_bits(addr,#7FFF), b)

        elsif mapper = 2 then
            --PRGROM1 = prgMem + b*#4000
            swap_prg_page(#8000, 16, b)

        elsif mapper = 3 then
            if and_bits(addr, #7FFF) and b != chrRomPage then
                chrRomPage = b
                PATTBL0 = chrMem + and_bits(b,15)*#2000
                PATTBL1 = PATTBL0 + #1000
                refreshPatternTable = 1
            end if

        -- Color Dreams
        elsif mapper = 11 then
            --if and_bits(floor(b/16),3)!=prgRomPage then
                prgRomPage = and_bits(b,nPrgPages-1)
                PRGROM1 = prgMem + prgRomPage*#8000
                PRGROM2 = PRGROM1 + #4000
                --	printf(1,"Switching in bank %d at $8000 ($%04x)\n",{and_bits(floor(b/16),3),addr})
            --end if

            if and_bits(floor(b/16),nChrPages-1)!=chrRomPage then
                chrRomPage = and_bits(floor(b/16),nChrPages-1)
                PATTBL0 = chrMem + chrRomPage*#2000
                PATTBL1 = PATTBL0 + #1000
                refreshPatternTable = 1
            end if

        -- GNROM
        elsif mapper = 66 then
            swap_prg_page(#8000,32,and_bits(floor(b/16),3))

            if and_bits(b,3)!=chrRomPage then
                swap_chr_page(#0000,8,and_bits(b,3))
                refreshPatternTable = 1
            end if

        -- Camerica
        elsif mapper = 71 then
            if addr >= #C000 then
                --PRGROM1 = prgMem + and_bits(b,nPrgPages-1)*#4000
                swap_prg_page(#8000,16,b)
            end if
        else
            puts(logfile,"Attempting to write to ROM!\n")
        end if
    else
        --poke(RAM+addr,b)	-- Temp. hack
    end if
end procedure



-- Return an 8-bit relative address in 2's complement
global function rel8()
    integer addr
    addr = fetch_byte()
    return addr - ((addr >= #80) * 256)
end function


-- Zero-paged X-indexed
global function zpx8()
    return and_bits(fetch_byte()+reg_X, #FF)
end function


global function zpy8()
    return and_bits(fetch_byte()+reg_Y, #FF)
end function


global function zpx16()
    return and_bits(fetch_word()+reg_X, #FFFF)
end function


global function zpy16()
    return and_bits(fetch_word()+reg_Y, #FFFF)
end function


-- Immediate
global function imm8()
    return fetch_byte()
end function


-- Indirect
global function in16()
    return read_word(fetch_word())
end function


-- Indirect, prefix X-indexed
global function inx8pre()
    return read_word(and_bits(fetch_byte()+reg_X, #FF))
end function


-- Indirect, postfix Y-indexed
global function iny8post()
    return read_word(fetch_byte()) + reg_Y
end function


global function abs8(integer addr)
    return and_bits(addr, #FF)
end function


global function abs16(integer addr)
    return and_bits(addr, #FFFF)
end function


-- Push b onto the stack (located on page 1 in CPU memory space)
global procedure push(integer b)
    poke(reg_S+RAM+#100, b)
    reg_S = and_bits(reg_S-1, #FF)
end procedure


-- Push w onto the stack (located on page 1 in CPU memory space)
global procedure push_word(integer w)
    poke(reg_S+RAM+#100, floor(w/#100))
    reg_S = and_bits(reg_S-1, #FF)
    poke(reg_S+RAM+#100, w)
    reg_S = and_bits(reg_S-1, #FF)
end procedure


-- Pull a byte from the stack
global function pull()
    reg_S = and_bits(reg_S+1, #FF)
    return peek(reg_S+RAM+#100)
end function
