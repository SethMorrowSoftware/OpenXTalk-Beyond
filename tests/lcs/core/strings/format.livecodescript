script "CoreStringsFormat"
-- Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
-- (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
-- Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

/*
Copyright (C) 2017 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

on TestFormatMultipleHex
   TestAssert "Format multiple hex", format("\xaa\xbb") is numToByte(0xaa)&numToByte(0xbb)
end TestFormatMultipleHex

-- OXT-Beyond: whole numbers too large for 32 bits. format("%d", 3000000000)
-- gave -2147483648 on x86 and 2147483647 on ARM (LiveCode Community 9.6.3
-- too).
on TestFormatWideIntegers
   TestAssert "format %d above 32 bits", format("%d", 3000000000) is "3000000000"
   TestAssert "format %d of 2^40", format("%d", 2^40) is "1099511627776"
   TestAssert "format %d below 32 bits", format("%d", -3000000000) is "-3000000000"
   TestAssert "format %i above 32 bits", format("%i", 3000000000) is "3000000000"
   TestAssert "format %d rounds a wide number as a narrow one", format("%d", 3000000000.5) is "3000000001"
   TestAssert "format %8d pads a wide number", format("%14d|", 3000000000) is "    3000000000|"
   TestAssert "format %u above 31 bits", format("%u", 3000000000) is "3000000000"
   TestAssert "format %u above 32 bits", format("%u", 2^40) is "1099511627776"
   TestAssert "format %x above 31 bits", format("%x", 3000000000) is "b2d05e00"
   TestAssert "format %X above 32 bits", format("%X", 2^40) is "10000000000"
   TestAssert "format %o above 32 bits", format("%o", 2^33) is "100000000000"
   TestAssert "format two wide numbers and text", format("%d %s %d", 2^40, "and", 2^41) is "1099511627776 and 2199023255552"
end TestFormatWideIntegers

-- What format gave before for numbers that fit in 32 bits, which is not to
-- change.
on TestFormatNarrowIntegersUnchanged
   TestAssert "format %d", format("%d", 42) is "42"
   TestAssert "format %d negative", format("%d", -42) is "-42"
   TestAssert "format %d rounds", format("%d", 2.5) is "3" and format("%d", -2.5) is "-3"
   TestAssert "format %d largest 32-bit", format("%d", 2147483647) is "2147483647"
   TestAssert "format %d smallest 32-bit", format("%d", -2147483648) is "-2147483648"
   TestAssert "format %05d", format("%05d", 42) is "00042"
   TestAssert "format %x of -1", format("%x", -1) is "ffffffff"
   TestAssert "format %u of -1", format("%u", -1) is "4294967295"
   TestAssert "format %c", format("%c", 65) is "A"
   TestAssert "format %hd", format("%hd", 70000) is "4464"
end TestFormatNarrowIntegersUnchanged
