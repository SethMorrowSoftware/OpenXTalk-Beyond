script "CoreSecurityRandomBytes"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- randomBytes takes its bytes from the system's own random source and no
-- longer needs the security library (from HyperXTalk #590). What it gives
-- is what it gave: that many bytes, and the result empty.

on TestRandomBytesLength
   local tCount
   repeat for each item tCount in "0,1,16,64,1000,65536"
      TestAssert "randomBytes(" & tCount & ") is that many bytes", the number of bytes of randomBytes(tCount) is tCount
      TestAssert "the result is empty after randomBytes(" & tCount & ")", the result is empty
   end repeat
end TestRandomBytesLength

on TestRandomBytesDiffer
   local tFirst, tSecond
   put randomBytes(32) into tFirst
   put randomBytes(32) into tSecond
   TestAssert "two calls give different bytes", tFirst is not tSecond
end TestRandomBytesDiffer

on TestRandomBytesSpread
   -- 64 KB from a uniform source has every byte value in it; a source
   -- that was stuck, or gave only some values, would not
   local tBytes, tSeen, tMissing
   put randomBytes(65536) into tBytes
   repeat for each byte tByte in tBytes
      put true into tSeen[byteToNum(tByte)]
   end repeat
   repeat with i = 0 to 255
      if tSeen[i] is not true then
         add 1 to tMissing
      end if
   end repeat
   TestAssert "every byte value appears in 64 KB", tMissing is empty
end TestRandomBytesSpread

on TestRandomBytesIsBinary
   TestAssert "randomBytes gives binary data", randomBytes(8) is strictly a binary string
end TestRandomBytesIsBinary
