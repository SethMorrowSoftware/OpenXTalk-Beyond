script "Microseconds"
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

-- HyperXTalk's "the microseconds", added for stacks written in HyperXTalk,
-- and what stays as it was: its names are no keywords, so variables,
-- parameters, handlers and custom properties keep them. (microseconds()
-- with brackets is the HyperXTalk compatibility library's:
-- tests/lcs/extensions/libraries/hxtcompat.livecodescript.)

on TestTheMicroseconds
   local tMsBefore, tUs, tMsAfter
   put the milliseconds into tMsBefore
   put the microseconds into tUs
   put the milliseconds into tMsAfter
   TestDiagnostic "the microseconds:" && tUs
   TestAssert "the microseconds is a whole number", tUs is an integer
   -- On Windows the milliseconds counts from the time the engine started,
   -- with timeGetTime, and the microseconds reads the system time, so the
   -- two can drift apart when the clock is set: a minute is plenty
   TestAssert "the microseconds counts from the same time as the milliseconds", \
         tUs >= (tMsBefore - 60000) * 1000 and tUs <= (tMsAfter + 60000) * 1000
   if the platform is not "win32" then
      -- elsewhere both read the same clock (2 ms for the rounding of the
      -- milliseconds)
      TestAssert "the microseconds is between two milliseconds", \
            tUs >= (tMsBefore - 2) * 1000 and tUs <= (tMsAfter + 2) * 1000
   end if
end TestTheMicroseconds

on TestMicrosecondsNames
   local tBefore, tUs
   put the microseconds into tBefore
   put the microsecs into tUs
   TestAssert "the microsecs", tUs is an integer and tUs >= tBefore - 1000000
   put the microsecond into tUs
   TestAssert "the microsecond", tUs is an integer and tUs >= tBefore - 1000000
   put the microsec into tUs
   TestAssert "the microsec", tUs is an integer and tUs >= tBefore - 1000000
   put the MicroSeconds into tUs
   TestAssert "the microseconds in any case", tUs is an integer and tUs >= tBefore - 1000000
   put the MICROSECS into tUs
   TestAssert "the microsecs in any case", tUs is an integer and tUs >= tBefore - 1000000
end TestMicrosecondsNames

on TestMicrosecondsModifiers
   -- the forms the milliseconds takes
   local tBefore, tUs
   put the microseconds into tBefore
   put the long microseconds into tUs
   TestAssert "the long microseconds is a number", tUs is a number
   TestAssert "the long microseconds is no earlier", tUs >= tBefore - 1000000
   put the long microsecs into tUs
   TestAssert "the long microsecs", tUs is a number and tUs >= tBefore - 1000000
   put the short microseconds into tUs
   TestAssert "the short microseconds is the microseconds", tUs is an integer and tUs >= tBefore - 1000000
   put the abbreviated microseconds into tUs
   TestAssert "the abbreviated microseconds is the microseconds", tUs is an integer and tUs >= tBefore - 1000000
end TestMicrosecondsModifiers

on TestMicrosecondsInExpressions
   local tStart, tElapsed
   put the microseconds into tStart
   wait 20 milliseconds
   put the microseconds - tStart into tElapsed
   TestDiagnostic "20 milliseconds took" && tElapsed && "microseconds"
   -- (no upper bound: a busy test machine can wait much longer)
   TestAssert "the microseconds - a start", tElapsed >= 10000
   TestAssert "in brackets", (the microseconds) >= tStart
   TestAssert "the microseconds div 1000", the microseconds div 1000 >= tStart div 1000
   TestAssert "in a comparison", the microseconds > tStart
   get the microseconds
   TestAssert "get the microseconds", it >= tStart
   TestAssert "as a parameter", max(the microseconds, 0) >= tStart
   if the microseconds < tStart then
      TestAssert "in an if", false
   else
      TestAssert "in an if", true
   end if
end TestMicrosecondsInExpressions

on TestMicrosecondsInDoAndValue
   local tBefore
   put the microseconds into tBefore
   TestAssert "in value()", value("the microseconds") >= tBefore
   do "get the microseconds"
   TestAssert "in do", it >= tBefore
   TestAssert "compiles() can tell", compiles("get the microseconds")
end TestMicrosecondsInDoAndValue

on TestMicrosecondsRefusals
   -- as the milliseconds refuses them
   TestAssert "the internet milliseconds does not compile", not compiles("get the internet milliseconds")
   TestAssert "the internet microseconds does not compile", not compiles("get the internet microseconds")
   TestAssert "the milliseconds() does not compile", not compiles("get the milliseconds()")
   TestAssert "the microseconds() does not compile", not compiles("get the microseconds()")
end TestMicrosecondsRefusals

private function compiles pStatement
   local tError
   try
      do pStatement
   catch tError
   end try
   return tError is empty
end compiles

-- What scripts saw before stays as it was

on TestMicrosecondsIsStillAName
   local microseconds, microsecs, microsecond, microsec
   put 1 into microseconds
   put 2 into microsecs
   put 3 into microsecond
   put 4 into microsec
   TestAssert "a variable named microseconds", microseconds is 1
   TestAssert "variables named microsecs, microsecond and microsec", \
         microsecs & microsecond & microsec is "234"
   TestAssert "a variable named microseconds in an expression", microseconds + microsec is 5

   -- and the function, beside it
   put the microseconds into microseconds
   TestAssert "the microseconds into a variable named microseconds", \
         microseconds is an integer and microseconds > 1000000
end TestMicrosecondsIsStillAName

on TestMicrosecondsHandlers
   TestAssert "a function named microseconds", microseconds(2) is 4
   TestAssert "a function named microsec", microsec() is "mine"
   microsecs 5
   TestAssert "a command named microsecs", the result is 10
   TestAssert "a parameter named microseconds", withAParameter(7) is 7
end TestMicrosecondsHandlers

function microseconds pValue
   return pValue * 2
end microseconds

function microsec
   return "mine"
end microsec

command microsecs pValue
   return pValue * 2
end microsecs

private function withAParameter microseconds
   return microseconds
end withAParameter

on TestMicrosecondsCustomProperty
   -- set and read by another name too, so that a property set and read
   -- under some other name (none) would not pass
   local tName
   put "microseconds" into tName
   set the microseconds of me to "kept"
   TestAssert "a custom property named microseconds", the microseconds of me is "kept"
   TestAssert "the custom property is named microseconds", the tName of me is "kept"
   TestAssert "microseconds is among the custom keys", "microseconds" is among the lines of the customKeys of me
   set the tName of me to "changed"
   TestAssert "the microseconds of me reads it", the microseconds of me is "changed"
   set the microseconds[1] of me to "one"
   TestAssert "the microseconds of me with an index", the microseconds[1] of me is "one"
   set the microsec of me to "short"
   TestAssert "a custom property named microsec", the microsec of me is "short"
   -- and the function, beside it
   TestAssert "the microseconds is still the function", the microseconds is an integer
end TestMicrosecondsCustomProperty
