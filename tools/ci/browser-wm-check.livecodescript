script "OXTBrowserWMCheck"
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

-- The stacks for tools/ci/browser_wm_check.py (see there), which runs
--
--    <standalone engine> tools/ci/browser-wm-check.livecodescript
--
-- on Linux under Xvfb and a window manager, and checks from outside what
-- is on the screen and where the keys go. Environment:
--    OXT_WM_DIR         a folder: the script appends its lines (READY n,
--                       EVENT ..., FIELD ..., ERROR ..., DONE) to log.txt
--                       and goes on from step n once go-n exists there
--    OXT_WM_URL         the test page (one colour all over)
--    OXT_WM_EXTENSIONS  the Extensions folder with the browser widget

local sEvents

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_WM_DIR & "/log.txt")
end logLine

-- Called by the test stacks' scripts
command wmCheckEvent pEvent
   put pEvent & return after sEvents
   if pEvent begins with "suspend" or pEvent begins with "resume" then logLine "EVENT " & pEvent
end wmCheckEvent

function waitFor pEvent, pSeconds
   put the milliseconds + pSeconds * 1000 into tEnd
   repeat while the milliseconds < tEnd
      if sEvents contains pEvent then return true
      wait 100 milliseconds with messages
   end repeat
   return sEvents contains pEvent
end waitFor

-- Until browser_wm_check.py has done its checks of step pStep
command waitGo pStep
   put the milliseconds + 120000 into tEnd
   repeat while the milliseconds < tEnd
      if there is a file ($OXT_WM_DIR & "/go-" & pStep) then exit waitGo
      wait 100 milliseconds with messages
   end repeat
   logLine "ERROR no go-" & pStep
end waitGo

private function stackScript
   local tScript
   repeat for each item tMessage in "browserDocumentLoadComplete,browserDocumentLoadFailed,suspend,resume"
      put "on" && tMessage && "p1, p2" & return after tScript
      put "   dispatch" && quote & "wmCheckEvent" & quote && "to stack" && quote & "OXTBrowserWMCheck" & quote && "with" && quote & tMessage & ":" & quote && "&& the short name of this stack && p1" & return after tScript
      put "   pass" && tMessage & return after tScript
      put "end" && tMessage & return after tScript
   end repeat
   return tScript
end stackScript

-- A stack with a browser at 10,10,400,340 of its card and a field at
-- 410,20,490,50
command makeStack pName, pRect
   create stack pName
   set the script of stack pName to stackScript()
   set the title of stack pName to pName
   set the rect of stack pName to pRect
   create widget "Browser" as "com.livecode.widget.browser" in card 1 of stack pName
   set the rect of widget "Browser" of stack pName to 10,10,400,340
   create field "Typing" in card 1 of stack pName
   set the rect of field "Typing" of stack pName to 410,20,490,50
   set the traversalOn of field "Typing" of stack pName to true
end makeStack

on startup
   put empty into sEvents
   logLine "INFO platform=" & the platform & " version=" & the version
   try
      load extension from file ($OXT_WM_EXTENSIONS & "/com.livecode.library.widgetutils/module.lcm")
      load extension from file ($OXT_WM_EXTENSIONS & "/com.livecode.widget.browser/module.lcm")
      if the result is not empty then
         logLine "ERROR the browser widget does not load: " & the result
      else
         -- A stack that stays open, so that closing the test stack in
         -- step 2 does not close the last window
         create stack "WMKeeper"
         set the rect of stack "WMKeeper" to 100,700,300,780
         go stack "WMKeeper"
         
         -- 1: a browser in a new stack
         makeStack "WMCheckA", "100,100,600,450"
         go stack "WMCheckA"
         set the url of widget "Browser" of stack "WMCheckA" to $OXT_WM_URL
         if not waitFor("browserDocumentLoadComplete: WMCheckA", 30) then logLine "ERROR the page did not load: " & sEvents
         wait 1 second with messages
         logLine "READY 1"
         waitGo 1
         logLine "FIELD 1 " & field "Typing" of stack "WMCheckA"

         -- 2: the same stack closed and opened again (the browser is made
         -- again and loads the page again)
         put empty into sEvents
         close stack "WMCheckA"
         wait 1 second with messages
         go stack "WMCheckA"
         if not waitFor("browserDocumentLoadComplete: WMCheckA", 30) then logLine "ERROR the page did not load again: " & sEvents
         wait 1 second with messages
         logLine "READY 2"
         waitGo 2

         -- 3: a second stack with a browser of its own
         put empty into sEvents
         makeStack "WMCheckB", "700,100,1200,450"
         go stack "WMCheckB"
         set the url of widget "Browser" of stack "WMCheckB" to $OXT_WM_URL
         if not waitFor("browserDocumentLoadComplete: WMCheckB", 30) then logLine "ERROR the page did not load in the second stack: " & sEvents
         wait 1 second with messages
         logLine "READY 3"
         waitGo 3
         logLine "FIELD 3 " & field "Typing" of stack "WMCheckB"
      end if
   catch tError
      replace return with " | " in tError
      logLine "ERROR script error: " & tError
   end try
   logLine "DONE"
   quit 0
end startup
