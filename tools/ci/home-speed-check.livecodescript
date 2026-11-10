script "OXTHomeSpeedCheck"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- Run by tools/ci/home_speed_check.py, which starts this standalone engine
-- on its own X server. It opens OXT-Beyond Home (the Toolset's
-- palettes/home/revhub.livecodescript, $OXT_HOME_TOOLSET) at its first
-- place, Home (revWebHome), and writes one line for each thing it finds
-- to $OXT_HOME_LOG, separated by tabs. The Python script decides what
-- passes.
--
--   OPEN      milliseconds to open; controls; the tour's pages built
--   PAGE      a page shown by the right arrow key: its name, whether
--             it is built, whether it is shown, milliseconds
--   BUILT     the pages built once each has been shown, and controls
--   FRONT     Home in front: frames a second, CPU percent
--   SLOW      Home in front on a computer made slow (glows over its
--             hero that each frame draws again): frames a second, CPU
--             percent of one core
--   ERROR     a script error
--   DONE
--
-- The frames are counted by a front script that hears each hmTick; the
-- CPU is the engine's own, from /proc/<pid>/stat.

constant kPages = "home,speak,move,draw,web,app"
constant kSlowGlows = 12

local sFrames

on openStack
   send "homeRun" to me in 200 milliseconds
end openStack

command homeLog pLine
   put pLine & return after URL ("file:" & $OXT_HOME_LOG)
end homeLog

on errorDialog pError
   homeLog "ERROR" & tab & line 1 of pError
   quit 3
end errorDialog

-- The engine's CPU time so far, in milliseconds
function homeCpu
   local tStat, tAt
   put shell("cat /proc/" & the processID & "/stat") into tStat
   put offset(")", tStat) into tAt
   delete char 1 to tAt of tStat
   -- (utime and stime, in clock ticks of 10 milliseconds)
   return (word 12 of tStat + word 13 of tStat) * 10
end homeCpu

on homeCountFrame
   add 1 to sFrames
end homeCountFrame

command homeSettle pMilliseconds
   local tEnd
   put the milliseconds + pMilliseconds into tEnd
   repeat while the milliseconds < tEnd
      wait 10 milliseconds with messages
   end repeat
end homeSettle

-- Frames a second and CPU percent over pMilliseconds
function homeMeasure pMilliseconds
   local tCpu, tStart, tElapsed
   put 0 into sFrames
   put homeCpu() into tCpu
   put the milliseconds into tStart
   homeSettle pMilliseconds
   put the milliseconds - tStart into tElapsed
   return round(sFrames * 1000 / tElapsed, 1) & tab & round((homeCpu() - tCpu) * 100 / tElapsed, 1)
end homeMeasure

-- The tour's pages whose groups hold controls
function homeBuilt
   local tPage, tBuilt
   repeat for each item tPage in kPages
      if there is a group ("pg_" & tPage) of card 1 of stack "revHub" and \
            the number of controls of group ("pg_" & tPage) of card 1 of stack "revHub" > 0 then
         put tPage & comma after tBuilt
      end if
   end repeat
   delete the last char of tBuilt
   return tBuilt
end homeBuilt

on homeRun
   local tToolset, tStart, tPage, tGroup, tIndex, tGlow
   put $OXT_HOME_TOOLSET into tToolset
   start using stack $OXT_HOME_DRAWING
   -- (each frame Home draws, counted)
   create invisible stack "OXTHomeSpeedCounter"
   set the script of stack "OXTHomeSpeedCounter" to "on hmTick" & return & \
         "send " & quote & "homeCountFrame" & quote & " to stack " & quote & "OXTHomeSpeedCheck" & quote & return & \
         "pass hmTick" & return & "end hmTick"
   insert the script of stack "OXTHomeSpeedCounter" into front

   put the milliseconds into tStart
   get the short name of stack (tToolset & "/palettes/home/revhub.livecodescript")
   dispatch "revHubShow" to stack "revHub" with "home"
   homeLog "OPEN" & tab & (the milliseconds - tStart) & tab & \
         the number of controls of card 1 of stack "revHub" & tab & homeBuilt()

   homeSettle 1000
   homeLog "FRONT" & tab & homeMeasure(3000)

   -- each page in turn, as the right arrow key turns them
   repeat for each item tPage in kPages
      if tPage is "home" then
         next repeat
      end if
      put the milliseconds into tStart
      dispatch "arrowKey" to stack "revHub" with "right"
      put "pg_" & tPage into tGroup
      homeLog "PAGE" & tab & tPage & tab & (tPage is among the items of homeBuilt()) & tab & \
            the visible of group tGroup of card 1 of stack "revHub" & tab & (the milliseconds - tStart)
      homeSettle 300
   end repeat
   homeLog "BUILT" & tab & homeBuilt() & tab & the number of controls of card 1 of stack "revHub"

   -- back to the first page, and a slow computer
   dispatch "arrowKey" to stack "revHub" with "right"
   repeat with tIndex = 1 to kSlowGlows
      create graphic ("OXTHomeSlow" & tIndex) in card 1 of stack "revHub"
      put it into tGlow
      set the style of tGlow to "oval"
      set the opaque of tGlow to true
      set the blendLevel of tGlow to 97
      set the rect of tGlow to 250 + tIndex, 30, 1150 - tIndex, 380
      set the outerGlow["size"] of tGlow to 200
      set the outerGlow["spread"] of tGlow to 50
      set the dropShadow["size"] of tGlow to 200
      set the innerGlow["size"] of tGlow to 200
   end repeat
   homeSettle 3000
   homeLog "SLOW" & tab & homeMeasure(6000)
   homeLog "DONE"
   quit 0
end homeRun
