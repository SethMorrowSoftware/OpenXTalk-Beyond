script "DateTime"
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


on TestLongTime24Hours
 local tDateItems
 set the twelveHourTime to false
 put "2017,3,28,2,0,0,3" into tDateItems
 convert tDateItems to long time

 TestAssert "Test 24-hour format 1", char 1 to 2 of tDateItems is a number
 TestAssert "Test 24-hour format 2", char 3 of tDateItems is ":"
 TestAssert "Test 24-hour format 3", tDateItems is "02:00:00"
end TestLongTime24Hours

on Test2038Problem
   local tDate
   put 2147483648 into tDate
   convert tDate to dateItems
   -- OXT-Beyond: the web engine converts them too (its time_t has 64 bits)
   if the platform is "Linux" and the processor is "x86" then
      TestAssertBroken "Convert dates over long max seconds", item 1 of tDate is 2038, "Bug 19801"
   else
      TestAssert "Convert dates over long max seconds", item 1 of tDate is 2038
   end if
end Test2038Problem

on TestConvertDatesBefore1970
   -- No date before 1970 converted on Windows (its C runtime's time
   -- functions start then): the value stayed as it was.
   local tDate
   put "1/1/1960" into tDate
   convert tDate to dateItems
   TestAssert "convert 1/1/1960 to dateItems", tDate is "1960,1,1,0,0,0,6"

   put "12/31/1969 11:59:59 PM" into tDate
   convert tDate to dateItems
   TestAssert "convert 12/31/1969 11:59:59 PM to dateItems", tDate is "1969,12,31,23,59,59,4"

   put "7/4/1776" into tDate
   convert tDate to long date
   TestAssert "convert 7/4/1776 to a long date", tDate is "Thursday, July 4, 1776"

   put "2/29/1904" into tDate
   TestAssert "the leap day 2/29/1904 is a date", tDate is a date
end TestConvertDatesBefore1970

on TestConvertYearsBefore100
   -- A year from 0 to 99 written with more than two digits is that year (in
   -- two it goes through the centuryCutoff). The web engine converted it as
   -- 1900 to 1999: its date functions go through JavaScript's Date, which
   -- reads such a year so.
   local tDate
   put "0099,10,24,14,30,5,1" into tDate
   convert tDate from dateItems to dateItems
   if the result is "invalid date" then
      -- where time_t has 32 bits (32-bit Linux), the engine converts only
      -- the years 1901 to 2038 and refuses the others
      TestAssert "a year the engine cannot convert is refused and left as it was", \
            tDate is "0099,10,24,14,30,5,1"
      TestSkip "a year from 0 to 99", "this engine converts only the years 1901 to 2038"
      exit TestConvertYearsBefore100
   end if
   TestAssert "the year 99 in dateItems", tDate is "99,10,24,14,30,5,7"

   put "0004,2,29,12,0,0,1" into tDate
   convert tDate from dateItems to dateItems
   TestAssert "the leap day of the year 4", tDate is "4,2,29,12,0,0,1"

   put "100,1,0,12,0,0,1" into tDate
   convert tDate from dateItems to dateItems
   TestAssert "the day before the year 100 is in the year 99", tDate is "99,12,31,12,0,0,5"

   put "10/24/0099" into tDate
   convert tDate to long date
   TestAssert "the year 99 as a long date", tDate is "Saturday, October 24, 99"

   put "Sat, 24 Oct 0099 14:30:05 +0000" into tDate
   convert tDate from internet date to seconds
   TestAssert "the year 99 in seconds", tDate is -59017368595

   put "99,10,24,14,30,5,1" into tDate
   convert tDate from dateItems to dateItems
   TestAssert "in two digits the year 99 is 1999, as before", tDate is "1999,10,24,14,30,5,1"
end TestConvertYearsBefore100
