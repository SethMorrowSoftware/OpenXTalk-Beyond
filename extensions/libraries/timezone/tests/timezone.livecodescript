script "TimeZoneLibrary"
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

on TestSetup
    TestSkipIfNot "platform", "macos,linux"
	TestLoadExtension "com.livecode.library.timezone"
end TestSetup

on TestTimezoneRoundTrip
   local tSeconds, tLocal, tRoundTrip
   put the seconds into tSeconds
   repeat for each line tZone in TimeZones()
      try
         put FromUniversalTime(tSeconds, tZone) into tLocal
         put ToUniversalTime(tLocal, tZone) into tRoundTrip
         -- OXT-Beyond: when a zone's clocks go back, the local times they
         -- go back over name two moments (an hour apart, two hours at
         -- Antarctica/Troll), and ToUniversalTime gives one of them, so
         -- the other is a right answer too: the moment it gives must have
         -- the same local time. Without this the test failed in those
         -- hours of any zone (Asia/Jerusalem, Europe/Chisinau and
         -- Antarctica/Troll on 2026-10-24 at 23:00 to 24:00 UTC)
         if tRoundTrip is not tSeconds and FromUniversalTime(tRoundTrip, tZone) is tLocal then
            put tSeconds into tRoundTrip
         end if
         TestAssert tZone & "timezone round trip", tRoundTrip is tSeconds
      catch tError
         TestAssert tZone & "timezone round trip", false
      end try
   end repeat
end TestTimezoneRoundTrip

-- OXT-Beyond: the hour that is there twice, whenever the tests run. In
-- London the clocks went back at 02:00 BST on 2026-10-25, so 00:30 and
-- 01:30 UTC (1792888200 and 1792891800) were both 01:30 there
on TestTimezoneRepeatedHour
   local tFirst, tSecond, tLocal, tBack
   put 1792888200 into tFirst
   put tFirst + 3600 into tSecond
   put FromUniversalTime(tFirst, "Europe/London") into tLocal
   TestAssert "the first 01:30 in London is 01:30", tLocal is tFirst + 3600
   TestAssert "the second 01:30 in London is 01:30", FromUniversalTime(tSecond, "Europe/London") is tLocal
   put ToUniversalTime(tLocal, "Europe/London") into tBack
   TestAssert "London's 01:30 is one of the two", tBack is tFirst or tBack is tSecond
   -- and an hour that is there once: noon in London that day, 12:00 UTC
   TestAssert "noon in London round trip", ToUniversalTime(FromUniversalTime(tFirst + 41400, "Europe/London"), "Europe/London") is tFirst + 41400
end TestTimezoneRepeatedHour
