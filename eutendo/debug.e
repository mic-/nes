include dis6502.e

global procedure memdump(integer fn, atom ptr, integer num, integer size)
    integer w
    sequence s

    for i = 1 to num do
        if remainder(i, 8) = 1 then
            printf(fn,"\n%04x: ", ptr)
        else
            puts(fn," ")
        end if

        if size = 8 then
            w = read_byte(ptr)
            ptr += 1
            s = sprintf("%02x", w)
        elsif size = 16 then
            w = read_word(ptr)
            ptr += 2
            s = sprintf("%04x", w)
        elsif size = 32 then
            w = peek(VRAM+ptr)
            ptr += 1
            s = sprintf("%02x", w)
        end if
        puts(fn, s)
    end for
    puts(fn, "\n")
end procedure
