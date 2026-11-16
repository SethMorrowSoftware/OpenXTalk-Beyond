script "CoreDatetimeInternetDateZone"
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

/*
OXT-Beyond: convert reads an internet date's zone when no "from" form is
named (seth's decision, 2026-11-16). From LiveCode 7.0 until 0.2.8-dp.1,
"convert tDate to seconds" took the time of "Mon, 16 Nov 2026 12:00:00
+0000" as local time and dropped the "+0000", so that date, the same one
at "+0100" and at "-0500" all gave the same seconds; only "convert tDate
from internet date to seconds" applied the zone. Every test here holds
whatever the computer's time zone is: the dates' zones differ from each
other, and a date in the local zone is made from the internet date.

1794830400 is 16 November 2026, 12:00:00 universal time.
*/

constant kNoon = "Mon, 16 Nov 2026 12:00:00"
constant kNoonUniversal = 1794830400

private function zoned pZone
   return kNoon && pZone
end zoned

on TestInternetDateToSecondsAppliesZone
   local tDate

   put zoned("+0000") into tDate
   convert tDate to seconds
   TestAssert "+0000 is noon universal time", tDate is kNoonUniversal

   put zoned("+0100") into tDate
   convert tDate to seconds
   TestAssert "+0100 is an hour earlier", tDate is kNoonUniversal - 3600

   put zoned("-0500") into tDate
   convert tDate to seconds
   TestAssert "-0500 is five hours later", tDate is kNoonUniversal + 5 * 3600

   put zoned("+0530") into tDate
   convert tDate to seconds
   TestAssert "+0530 is five and a half hours earlier", \
         tDate is kNoonUniversal - 5 * 3600 - 30 * 60

   put zoned("-0930") into tDate
   convert tDate to seconds
   TestAssert "-0930 is nine and a half hours later", \
         tDate is kNoonUniversal + 9 * 3600 + 30 * 60
end TestInternetDateToSecondsAppliesZone

on TestInternetDateAgreesWithFromInternetDate
   local tZone, tPlain, tFrom
   repeat for each item tZone in "+0000,+0100,-0500,+0530,-0930,+1400,-1200"
      put zoned(tZone) into tPlain
      put tPlain into tFrom
      convert tPlain to seconds
      convert tFrom from internet date to seconds
      TestAssert "convert to seconds agrees with from internet date at" && tZone, \
            tPlain is tFrom
   end repeat
end TestInternetDateAgreesWithFromInternetDate

on TestInternetDateToOtherForms
   local tDate, tExpected

   -- dateItems are local time: the same moment as the seconds give
   put kNoonUniversal into tExpected
   convert tExpected to dateItems
   put zoned("+0000") into tDate
   convert tDate to dateItems
   TestAssert "to dateItems: the moment it names, in local time", tDate is tExpected

   put kNoonUniversal + 5 * 3600 into tExpected
   convert tExpected to dateItems
   put zoned("-0500") into tDate
   convert tDate to dateItems
   TestAssert "to dateItems from -0500", tDate is tExpected

   -- and to an internet date: in the local zone, the same moment
   put kNoonUniversal into tExpected
   convert tExpected to internet date
   put zoned("+0000") into tDate
   convert tDate to internet date
   TestAssert "to internet date: the same moment in the local zone", tDate is tExpected
end TestInternetDateToOtherForms

on TestLocalInternetDateUnchanged
   -- A date in the local zone gave the right seconds before the fix, and
   -- gives the same now.
   local tSeconds, tDate
   put kNoonUniversal into tSeconds
   put tSeconds into tDate
   convert tDate to internet date
   convert tDate to seconds
   TestAssert "a local internet date round trips", tDate is tSeconds

   put the seconds into tSeconds
   put tSeconds into tDate
   convert tDate to internet date
   convert tDate to seconds
   TestAssert "now, as an internet date, round trips", tDate is tSeconds
end TestLocalInternetDateUnchanged

on TestNotAnInternetDateUnchanged
   -- What was not read as a date still is not
   local tDate
   put zoned("+0000") && "x" into tDate
   TestAssert "text after the zone: not a date", tDate is not a date
   convert tDate to seconds
   TestAssert "and convert leaves it", tDate is zoned("+0000") && "x"

   put "16 Nov 2026 12:00:00 +0000" into tDate
   TestAssert "no weekday: not a date", tDate is not a date

   TestAssert "an internet date is a date", zoned("+0100") is a date
   TestAssert "empty is not a date", empty is not a date
end TestNotAnInternetDateUnchanged
