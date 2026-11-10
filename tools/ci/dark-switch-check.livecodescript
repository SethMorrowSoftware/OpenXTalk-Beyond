script "OXTDarkSwitchCheck"
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

-- The stack tools/ci/dark_switch_check.py measures while it switches
-- Windows between its light and dark appearance: a standard button, an
-- option menu and a combo box, with no colours of their own. It runs
--
--    <standalone engine> tools/ci/dark-switch-check.livecodescript
--
-- Environment:
--    OXT_DARK_LOG   the file to append lines to (below)
--    OXT_DARK_GO    <OXT_DARK_GO>.<n> is the file dark_switch_check.py
--                   writes to answer STEP <n>: one word, the label of the
--                   measurement to take now, or quit
--
-- The script logs WINDOW DarkSwitch <windowID>, and then, until it is told
-- to quit: STEP <n>, and when the answer has come
--
--    MEASURE <label> <control> face=<r,g,b> ink=<r,g,b> size=<w>x<h>
--                   for each control, from a snapshot of it taken at once
--                   (the first time anything is drawn after the answer):
--                   the face is the colour most of its inside has, the ink
--                   the colour there that differs most from it (its label)
--    SCREEN <label> <control> face=<r,g,b> ink=<r,g,b> size=<w>x<h>
--                   the same, read from the screen where the control is,
--                   after it was drawn again (hidden and shown): what a
--                   person sees
--    APPEARANCE <label> <the systemAppearance>
--    CHANGED <label> <n>
--                   how many times the stack was sent systemAppearanceChanged
--                   since STEP was logged
--    MEASURED <label>
--
-- and DONE when it quits. Between STEP and the answer, and for 600
-- milliseconds after the snapshots, it waits with messages, so that what
-- the engine has to do for a new appearance is done by MEASURED.
--
-- Quits when it is told to, or when a step gets no answer in 60 seconds.

constant kStack = "DarkSwitch"
constant kControls = "Push,Option,Combo"
-- (the frame, and the corners a theme rounds, are left out of a measurement)
constant kInset = 4

local sStep, sChanged

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_DARK_LOG)
end logLine

-- Called by the stack's systemAppearanceChanged handler, and by this
-- stack's own when it is the defaultStack
command darkCheckChanged
   add 1 to sChanged
end darkCheckChanged

on systemAppearanceChanged
   darkCheckChanged
end systemAppearanceChanged

private function stackScript
   return "on systemAppearanceChanged" & return & \
         "   dispatch" && quote & "darkCheckChanged" & quote && "to stack" && quote & "OXTDarkSwitchCheck" & quote & return & \
         "end systemAppearanceChanged"
end stackScript

-- The face and the ink of the picture just imported, which is then deleted
private function readLastImage
   local tData, tWidth, tHeight, tCount, tOffset, tKey, tX, tY
   local tFace, tMost, tInk, tFurthest, tDistance
   put the imageData of the last image of stack kStack into tData
   put the width of the last image of stack kStack into tWidth
   put the height of the last image of stack kStack into tHeight
   delete the last image of stack kStack

   repeat with tY = kInset to tHeight - kInset - 1
      repeat with tX = kInset to tWidth - kInset - 1
         put (tY * tWidth + tX) * 4 into tOffset
         put byteToNum(byte tOffset + 2 of tData) & comma & byteToNum(byte tOffset + 3 of tData) & comma & byteToNum(byte tOffset + 4 of tData) into tKey
         add 1 to tCount[tKey]
      end repeat
   end repeat

   put 0 into tMost
   repeat for each key tKey in tCount
      if tCount[tKey] > tMost then
         put tCount[tKey] into tMost
         put tKey into tFace
      end if
   end repeat
   put -1 into tFurthest
   repeat for each key tKey in tCount
      put abs(item 1 of tKey - item 1 of tFace) + abs(item 2 of tKey - item 2 of tFace) + abs(item 3 of tKey - item 3 of tFace) into tDistance
      if tDistance > tFurthest then
         put tDistance into tFurthest
         put tKey into tInk
      end if
   end repeat
   return "face=" & tFace && "ink=" & tInk && "size=" & tWidth & "x" & tHeight
end readLastImage

-- The face and the ink of a control, from a snapshot of it
private function measureControl pName
   import snapshot from button pName of stack kStack
   return readLastImage()
end measureControl

-- The same from the screen, where the control is in its window
private function measureScreen pName
   local tRect
   put globalLoc(the topLeft of button pName of stack kStack) & comma & globalLoc(the bottomRight of button pName of stack kStack) into tRect
   import snapshot from rect tRect
   return readLastImage()
end measureScreen

private command makeStack
   local tName
   create invisible stack kStack
   set the script of stack kStack to stackScript()
   set the rect of stack kStack to 120,160,480,360
   set the decorations of stack kStack to "title,menu,minimize,close"
   set the defaultStack to kStack

   -- No colour is set on the stack or on a control: each draws as the
   -- appearance has it. None takes the keyboard focus, whose mark inside
   -- a control's frame would be measured as its ink
   create button "Push"
   set the rect of button "Push" to 30,30,190,62
   set the label of button "Push" to "Ab Cd"

   create button "Option"
   set the style of button "Option" to "menu"
   set the menuMode of button "Option" to "option"
   set the text of button "Option" to "Ab Cd" & return & "Ef Gh"
   set the label of button "Option" to "Ab Cd"
   set the rect of button "Option" to 30,80,190,106

   create button "Combo"
   set the style of button "Combo" to "menu"
   set the menuMode of button "Combo" to "comboBox"
   set the text of button "Combo" to "Ab Cd" & return & "Ef Gh"
   set the label of button "Combo" to "Ab Cd"
   set the rect of button "Combo" to 30,124,190,150

   repeat for each item tName in kControls
      set the traversalOn of button tName to false
   end repeat

   go stack kStack
end makeStack

on startup
   local tAnswer, tLabel, tEnd, tName
   logLine "INFO platform=" & the platform & " version=" & the version & " systemVersion=" & the systemVersion
   try
      makeStack
      wait 300 milliseconds with messages
      logLine "WINDOW" && kStack && the windowID of stack kStack

      repeat
         add 1 to sStep
         put 0 into sChanged
         logLine "STEP" && sStep
         put $OXT_DARK_GO & "." & sStep into tAnswer
         put the milliseconds + 60000 into tEnd
         repeat while the milliseconds < tEnd and there is not a file tAnswer
            wait 50 milliseconds with messages
         end repeat
         if there is not a file tAnswer then
            logLine "ERROR step" && sStep && "got no answer in 60 seconds"
            exit repeat
         end if
         -- (the file is made, then written: its word may come a moment later)
         put the milliseconds + 2000 into tEnd
         repeat
            put word 1 of URL ("file:" & tAnswer) into tLabel
            if tLabel is not empty or the milliseconds > tEnd then exit repeat
            wait 20 milliseconds with messages
         end repeat
         if tLabel is "quit" or tLabel is empty then exit repeat

         set the defaultStack to kStack
         repeat for each item tName in kControls
            logLine "MEASURE" && tLabel && tName && measureControl(tName)
         end repeat
         wait 600 milliseconds with messages

         -- What the window shows now, each control drawn again
         repeat for each item tName in kControls
            hide button tName of stack kStack
            show button tName of stack kStack
         end repeat
         wait 300 milliseconds with messages
         repeat for each item tName in kControls
            logLine "SCREEN" && tLabel && tName && measureScreen(tName)
         end repeat

         logLine "APPEARANCE" && tLabel && the systemAppearance
         logLine "CHANGED" && tLabel && sChanged
         logLine "MEASURED" && tLabel
      end repeat
   catch tError
      replace return with " | " in tError
      logLine "ERROR " & tError
   end try
   logLine "DONE"
   quit 0
end startup
