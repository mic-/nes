include file.e
include machine.e


global sequence includes,procmem
includes = {}
procmem = {}
integer incindex
incindex = 1


function get_dword(integer fh)
atom dwrd
  dwrd = getc(fh)
  dwrd += (getc(fh)*#100)
  dwrd += (getc(fh)*#10000)
  dwrd += (getc(fh)*#1000000)
  return dwrd
end function

function seq2dword(sequence dw)
atom dwrd
  dwrd = (floor(dw[1]) + floor(dw[2]*256) + floor(dw[3]*65536) + floor(dw[4]*16777216))
  return dwrd
end function



global function incbin(sequence fn)
integer fh,ch
sequence binfile
  fh = open(fn,"rb")
  if fh = -1 then
    return -1
  end if
  binfile = {}
  ch = 0
  while ch != -1 do
    ch = getc(fh)
    if ch != -1 then
      binfile = binfile & ch
    end if
  end while
  close(fh)
  includes = append(includes,binfile)
  procmem = append(procmem,{})
  incindex += 1
  return incindex-1
end function


global procedure freebin(integer slot)
  includes[slot] = 0
  if length(procmem[slot]) then
    for i = 1 to length(procmem[slot]) do
      free(procmem[slot][i])
    end for
    procmem[slot] = {}
  end if
end procedure



global function define_proc(sequence procname,integer slot,sequence resList)
sequence curslot,temps,paramlist
integer i1,i2,codesize,done
atom a1,codemem
-- puts(1,"Defining "&procname&"\n")

 if slot>length(includes) then
   return -1
 end if
 curslot = includes[slot]
 temps = "@"&procname
 i1 = 1
 i2 = (i1 + length(temps)) - 1

 while 1 do
   if not compare(temps,curslot[i1..i2]) then
     exit
   end if
   i1 += 1
   i2 += 1
   if i2>length(curslot) then
     puts(1,"Unable to resolve "&procname &"!\n")
     return -1
   end if
 end while

 i1 = i2+2
 codesize = seq2dword(curslot[i1..i1+3])

 i1 += 4
 codemem = allocate(codesize)
 if codemem<=0 then
   return -1
 end if
 procmem[slot] = procmem[slot] & codemem


 poke(codemem,curslot[i1..i1+codesize-1])
 i1 += codesize

 paramlist = {}
 done = 0
 while not done do
   if i1>length(curslot) then
     exit
   elsif curslot[i1] = '@' then
     exit
   end if
   --// get name
   temps = {}
   while curslot[i1]!=0 do
     temps = temps & curslot[i1]
     i1 += 1
   end while
   temps = {temps}
   i1 += 1
   i2 = curslot[i1]
   i1 += 1
   for i = 1 to i2 do
     a1 = seq2dword(curslot[i1..i1+3])
     temps = temps & a1
     i1 += 4
   end for
   paramlist = append(paramlist,temps)
 end while

 --// resolve params
 if length(resList) then
   for i=1 to length(resList) do
     for j=1 to length(paramlist[i])-1 do
       poke4(codemem+paramlist[i][j+1],resList[i])
     end for
   end for
 end if

 return {codemem,paramlist}
end function



global procedure set_param(sequence pname,atom val,sequence defined)
integer i1,i2
sequence paramlist
  paramlist = defined[2]
  i1 = 0
  for i=1 to length(paramlist) do
    if not compare(pname,paramlist[i][1]) then
      i1 = i
      exit
    end if
  end for
  if not i1 then
    return 
  end if
  for i=1 to length(paramlist[i1])-1 do
    poke4(defined[1]+paramlist[i1][i+1],val)
  end for
end procedure





