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
-- option menu, a combo box and a field, with no colours of their own; and,
-- as a stack made before the dark appearance would have them, a field with
-- a white background of its own, a field with no background of its own in
-- a group with a light one, a button with a light background of its own,
-- a check box with a white one, checked, and a field with a dark one, none
-- with a text colour. It runs
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
--    NOTICED <label> <n>
--                   how many times the stack was sent systemAppearanceChanged
--                   between STEP and the answer, while the script only
--                   waited: it drew nothing and asked for nothing, so what
--                   came then came from Windows' notice alone
--    MEASURE <label> <control> face=<r,g,b> ink=<r,g,b> size=<w>x<h>
--                   for each control, from a snapshot of it taken at once
--                   (the first time anything is drawn after the answer):
--                   the face is the colour most of its inside has, the ink
--                   the colour there that differs most from it (its label).
--                   The buttons and menus of kOwnSnapshot are snapshots of
--                   themselves; the others are of the card where they are,
--                   so that what their words are drawn on is in it (a field
--                   with no background of its own is drawn on its group's).
--                   A check box's box, which the theme draws in colours of
--                   its own, is left out (measureRect)
--    EFFECTIVE <label> <control> <r,g,b>
--                   for each field and button but the menus, its effective
--                   foregroundColor: the colour its words are drawn in (for
--                   a field of kLineWords, its first line's)
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
constant kControls = "Push,Option,Combo,Plain,Paper,Label,Key,Tick,Night,Shade"
-- (measured from a snapshot of themselves, as the check always did)
constant kOwnSnapshot = "Push,Option,Combo"
-- (their words are a field's or a button's, not a menu's)
constant kWords = "Plain,Paper,Label,Key,Tick,Night,Shade"
-- (fields whose words are all on their first line's colour: the effective
-- foregroundColor of that line is theirs)
constant kLineWords = "Shade"
-- (the frame, and the corners a theme rounds, are left out of a measurement)
constant kInset = 4
-- (a check box's box and the space after it: its label is in the middle)
constant kBox = 24

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

-- The effective foregroundColor of a control's words: of its first line
-- for a field of kLineWords, else of the control
private function effectiveWords pName
   if pName is among the items of kLineWords then
      return the effective foregroundColor of line 1 of field pName of stack kStack
   end if
   return the effective foregroundColor of control pName of stack kStack
end effectiveWords

-- Where a control is measured: its rect, but for a check box's box (the
-- rect is the card's, as the control's is)
private function measureRect pName
   local tRect
   put the rect of control pName of stack kStack into tRect
   if the style of control pName of stack kStack is "checkbox" then
      add kBox to item 1 of tRect
   end if
   return tRect
end measureRect

-- The face and the ink of a control, from a snapshot of it, or of the
-- card where it is
private function measureControl pName
   if pName is among the items of kOwnSnapshot then
      import snapshot from button pName of stack kStack
   else
      import snapshot from rect (measureRect(pName)) of card 1 of stack kStack
   end if
   return readLastImage()
end measureControl

-- The same from the screen, where the control is in its window (the rect
-- is counted from the window's own top left, so nothing depends on where
-- the window is or on which stack is the defaultStack)
private function measureScreen pName
   import snapshot from rect (measureRect(pName)) of window (the windowID of stack kStack)
   return readLastImage()
end measureScreen

private command makeStack
   local tName
   create invisible stack kStack
   set the script of stack kStack to stackScript()
   set the rect of stack kStack to 120,160,520,430
   set the decorations of stack kStack to "title,menu,minimize,close"
   set the defaultStack to kStack

   -- No colour is set on the stack, nor on the first four controls: each
   -- draws as the appearance has it. None takes the keyboard focus, whose
   -- mark inside a control's frame would be measured as its ink, nor has a
   -- text colour
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

   create field "Plain"
   set the rect of field "Plain" to 220,30,380,62
   put "Ab Cd" into field "Plain"

   -- The colours of a stack made before the dark appearance, which left
   -- the words to the engine: black in LiveCode Community, whatever the
   -- system's appearance. A field with a white background of its own
   create field "Paper"
   set the backgroundColor of field "Paper" to "255,255,255"
   set the rect of field "Paper" to 220,80,380,106
   put "Ab Cd" into field "Paper"

   -- A field with no background, in a group with a light one
   create group "Panel"
   set the backgroundColor of group "Panel" to "240,242,246"
   set the opaque of group "Panel" to true
   set the showBorder of group "Panel" to false
   create field "Label" in group "Panel"
   set the opaque of field "Label" to false
   set the showBorder of field "Label" to false
   set the rect of field "Label" to 220,124,380,150
   put "Ab Cd" into field "Label"
   set the lockLocation of group "Panel" to true
   set the rect of group "Panel" to 210,116,390,158

   -- A button with a light background of its own
   create button "Key"
   set the backgroundColor of button "Key" to "225,229,236"
   set the rect of button "Key" to 30,168,190,200
   set the label of button "Key" to "Ab Cd"

   -- A check box with a white background of its own, checked: its fill is
   -- not the hilite colour (it has no icon), so its words are on the white
   create button "Tick"
   set the style of button "Tick" to "checkbox"
   set the opaque of button "Tick" to true
   set the backgroundColor of button "Tick" to "255,255,255"
   set the textAlign of button "Tick" to "center"
   set the rect of button "Tick" to 30,218,190,250
   set the label of button "Tick" to "Ab Cd"
   set the hilite of button "Tick" to true

   -- A field with a dark background of its own: its words stay the dark
   -- appearance's
   create field "Night"
   set the backgroundColor of field "Night" to "40,48,64"
   set the rect of field "Night" to 220,168,380,200
   put "Ab Cd" into field "Night"

   -- A field with a white background of its own whose line has a dark one
   -- of its own: the line's words are on the dark colour, and stay the
   -- dark appearance's too (MCField::getwordsback). The line fills what
   -- is measured: no margins, and one line as tall as the field's inside
   create field "Shade"
   set the backgroundColor of field "Shade" to "255,255,255"
   set the margins of field "Shade" to "0,0,0,0"
   set the fixedLineHeight of field "Shade" to true
   set the textHeight of field "Shade" to 28
   set the rect of field "Shade" to 220,218,380,250
   put "Ab Cd" into field "Shade"
   set the backgroundColor of line 1 of field "Shade" to "40,48,64"

   repeat for each item tName in kControls
      set the traversalOn of control tName to false
   end repeat

   -- (made invisible, so that it is first seen whole: a stack made that way
   -- stays hidden when it is opened, and a window that is not shown is not
   -- on the screen to be read)
   go stack kStack
   show stack kStack
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

         logLine "NOTICED" && tLabel && sChanged
         set the defaultStack to kStack
         repeat for each item tName in kControls
            logLine "MEASURE" && tLabel && tName && measureControl(tName)
         end repeat
         repeat for each item tName in kWords
            logLine "EFFECTIVE" && tLabel && tName && effectiveWords(tName)
         end repeat
         wait 600 milliseconds with messages

         -- What the window shows now, each control drawn again
         repeat for each item tName in kControls
            hide control tName of stack kStack
            show control tName of stack kStack
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
