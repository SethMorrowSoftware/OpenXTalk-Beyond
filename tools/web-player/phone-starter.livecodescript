script "PhoneStarterBuilder"
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

-- Builds stacks/Phone Starter.oxtstack, the stack to copy for a stack made
-- for phones, with the Mobile Web library
-- (extensions/script-libraries/mobileweb). The stack is never edited by
-- hand: change this script and build it again, with any OXT-Beyond engine
-- (the IDE's, or the development engine of a build):
--
--    <engine> -ui tools/web-player/phone-starter.livecodescript
--
-- OXT_PHONE_STARTER names another file to write. It prints "BUILT <file>"
-- or "FAILED <why>".
--
-- What it shows, a card each, under a header and above a tab bar:
--   Home      what the stack does, the screen it has (mwViewport), a buzz
--   List      a long list that a finger scrolls (mwDragScroll), and a tap
--             that picks a line
--   Form      fields that stay above the on-screen keyboard
--             (mwViewportChanged)
--   Gestures  swipe, pinch and long press on a pad (a group, "Play", whose
--             script takes its own gestures), and a ring under each finger
--             on it (the touch messages)
--   Phone     a photo from the camera, the share sheet, the location, a
--             ball that rolls as the phone tilts, the screen kept on, and
--             the browser's bars hidden
-- A swipe left or right goes to the next or the previous tab, except on
-- the pad, which keeps its swipes. On a desktop the stack is a
-- phone-sized window that can be resized; in a phone's browser it fills
-- the screen (mwStart, as the stack is resizable), in portrait or
-- landscape. Without the library (an engine older than 0.2.7) it still
-- opens and works, without the gestures.

constant kWidth = 390
constant kHeight = 760
constant kTabs = "Home,List,Form,Gestures,Phone"

on startup
   local tFile, tError
   put $OXT_PHONE_STARTER into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/Phone Starter.oxtstack" into the last item of tFile
      set the itemDelimiter to comma
   end if
   try
      buildStack tFile
   catch tError
      write "FAILED" && tError & return to stdout
      quit 1
   end try
   write "BUILT" && tFile & return to stdout
   quit 0
end startup

private command buildStack pFile
   local tName, tCard
   put "Phone Starter" into tName
   if there is a stack tName then
      delete stack tName
   end if
   create invisible stack tName
   set the defaultStack to tName
   set the rect of stack tName to 100, 60, 100 + kWidth, 60 + kHeight
   set the minWidth of stack tName to 320
   set the minHeight of stack tName to 480
   set the resizable of stack tName to true
   set the backgroundColor of stack tName to "#F4F5FB"
   set the textFont of stack tName to empty
   set the textSize of stack tName to 16
   set the script of stack tName to stackScript()
   if the result is not empty then
      throw "the stack's script does not compile:" && the result
   end if

   -- the header and the tab bar: groups on every card
   create group "Header"
   create graphic "Header Back" in group "Header"
   setBox the long id of graphic "Header Back", "#4F46E5"
   create field "Title" in group "Header"
   setLabel the long id of field "Title", "Phone Starter", 20, "#FFFFFF", "bold"
   set the backgroundBehavior of group "Header" to true

   create group "Tabs"
   create graphic "Tabs Back" in group "Tabs"
   setBox the long id of graphic "Tabs Back", "#FFFFFF"
   create graphic "Tabs Line" in group "Tabs"
   set the style of graphic "Tabs Line" to "line"
   set the foregroundColor of graphic "Tabs Line" to "#D9DBE8"
   repeat for each item tName in kTabs
      create button ("Tab" && tName) in group "Tabs"
      setTab the long id of button ("Tab" && tName), tName
   end repeat
   set the backgroundBehavior of group "Tabs" to true

   -- the cards
   set the name of card 1 to "Home"
   buildHome
   create card "List"
   buildList
   create card "Form"
   buildForm
   create card "Gestures"
   buildGestures
   create card "Phone"
   buildPhone
   go card "Home"

   -- (made invisible while it is built; it opens visible)
   set the visible of stack "Phone Starter" to true
   save stack "Phone Starter" as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
end buildStack

-- A filled rectangle with no border
private command setBox pObject, pColor
   set the style of pObject to "rectangle"
   set the opaque of pObject to true
   set the lineSize of pObject to 0
   set the showBorder of pObject to false
   set the backgroundColor of pObject to pColor
end setBox

-- A field that is a label: locked, no frame, no focus
private command setLabel pField, pText, pSize, pColor, pStyle
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to false
   set the textSize of pField to pSize
   set the textColor of pField to pColor
   set the textStyle of pField to pStyle
   set the text of pField to pText
end setLabel

-- A tab: a big, flat button
private command setTab pButton, pName
   set the style of pButton to "transparent"
   set the showBorder of pButton to false
   set the threeD of pButton to false
   set the opaque of pButton to false
   set the showFocusBorder of pButton to false
   set the traversalOn of pButton to false
   set the autoHilite of pButton to false
   set the label of pButton to pName
   set the textSize of pButton to 14
   set the textStyle of pButton to "bold"
   set the textColor of pButton to "#6B6F86"
   set the script of pButton to "on mouseUp" & return & \
         "   psGoTab" && quote & pName & quote & return & "end mouseUp"
end setTab

-- A filled, rounded button
private command setButton pButton, pLabel, pColor
   set the style of pButton to "roundrect"
   set the showBorder of pButton to false
   set the threeD of pButton to false
   set the opaque of pButton to true
   set the showFocusBorder of pButton to false
   set the traversalOn of pButton to false
   set the backgroundColor of pButton to pColor
   -- (a roundrect button draws its edge whatever showBorder says)
   set the borderColor of pButton to pColor
   set the textColor of pButton to "#FFFFFF"
   set the textStyle of pButton to "bold"
   set the label of pButton to pLabel
end setButton

-- A field to type in, with room for a finger
private command setInput pField
   set the lockText of pField to false
   set the traversalOn of pField to true
   set the opaque of pField to true
   set the backgroundColor of pField to "#FFFFFF"
   set the showBorder of pField to true
   set the borderColor of pField to "#C9CCDD"
   set the threeD of pField to false
   set the textSize of pField to 17
   set the margins of pField to 10
   set the dontWrap of pField to true
end setInput

private command buildHome
   create field "Welcome"
   setLabel the long id of field "Welcome", \
         "A stack made for phones." & return & return & \
         "It fills the screen, and fills it again when the phone turns. The tabs below are big " & \
         "enough for a thumb, a swipe left or right changes tab, the list scrolls with a finger, " & \
         "the form stays above the keyboard, and the Phone tab uses the camera, the share sheet, " & \
         "the location and the tilt." & return & return & \
         "Copy it, then change it: one line, mwStart, makes it a phone stack, and every card " & \
         "lays itself out in the stack's psLayout handler.", \
         17, "#1F2240", "plain"
   create field "Screen"
   setLabel the long id of field "Screen", empty, 14, "#6B6F86", "plain"
   create button "Buzz"
   setButton the long id of button "Buzz", "Buzz the phone", "#4F46E5"
   set the script of button "Buzz" to "on mouseUp" & return & \
         "   psBuzz" & return & "end mouseUp"
end buildHome

private command buildList
   local tLines, i
   create field "Items"
   set the lockText of field "Items" to true
   set the traversalOn of field "Items" to false
   set the opaque of field "Items" to true
   set the backgroundColor of field "Items" to "#FFFFFF"
   set the showBorder of field "Items" to false
   set the threeD of field "Items" to false
   set the dontWrap of field "Items" to true
   set the vScrollbar of field "Items" to false
   set the textSize of field "Items" to 17
   set the leftMargin of field "Items" to 16
   repeat with i = 1 to 60
      put "Item" && i & return after tLines
   end repeat
   delete the last char of tLines
   set the text of field "Items" to tLines
   -- rows a finger can pick one of
   set the fixedLineHeight of field "Items" to true
   set the textHeight of field "Items" to 48
   set the script of field "Items" to listScript()
   if the result is not empty then
      throw "the list's script does not compile:" && the result
   end if
   create field "Picked"
   setLabel the long id of field "Picked", "Tap an item, or drag the list.", 15, "#6B6F86", "plain"
end buildList

private command buildForm
   local tName
   create group "Form"
   repeat for each item tName in "Name,Email,Notes"
      create field (tName && "Label") in group "Form"
      setLabel the long id of field (tName && "Label") of group "Form", tName, 14, "#6B6F86", "bold"
      create field tName in group "Form"
      setInput the long id of field tName of group "Form"
   end repeat
   set the dontWrap of field "Notes" of group "Form" to false
   create button "Save" in group "Form"
   setButton the long id of button "Save" of group "Form", "Save", "#4F46E5"
   set the script of button "Save" of group "Form" to "on mouseUp" & return & \
         "   psSave" & return & "end mouseUp"
   create field "Saved" in group "Form"
   setLabel the long id of field "Saved" of group "Form", empty, 15, "#15803D", "bold"
end buildForm

private command buildGestures
   create group "Play"
   set the lockLoc of group "Play" to true
   set the showBorder of group "Play" to false
   set the margins of group "Play" to 0
   set the script of group "Play" to playScript()
   if the result is not empty then
      throw "the play area's script does not compile:" && the result
   end if
   create graphic "Pad" in group "Play"
   set the style of graphic "Pad" to "roundrect"
   set the roundRadius of graphic "Pad" to 24
   set the opaque of graphic "Pad" to true
   set the lineSize of graphic "Pad" to 0
   set the backgroundColor of graphic "Pad" to "#E4E6F6"
   create graphic "Dot" in group "Play"
   set the style of graphic "Dot" to "oval"
   set the opaque of graphic "Dot" to true
   set the lineSize of graphic "Dot" to 0
   set the backgroundColor of graphic "Dot" to "#F59E0B"
   create field "Said"
   setLabel the long id of field "Said", \
         "Swipe on the pad, pinch the dot bigger or smaller, hold a finger still, or put fingers down.", \
         16, "#1F2240", "plain"
   set the textAlign of field "Said" to "center"
end buildGestures

private command buildPhone
   local tName, tLabel
   create field "Phone Said"
   setLabel the long id of field "Phone Said", "What the phone can do, from a stack in its browser.", 15, "#1F2240", "plain"
   repeat for each line tLabel in "Camera|Take a photo" & return & "Share|Share" & return & \
         "Where|Where am I?" & return & "Tilt|Roll the ball" & return & "Awake|Keep screen on" & return & \
         "Full|Full screen"
      set the itemDelimiter to "|"
      put item 1 of tLabel into tName
      create button tName
      setButton the long id of button tName, item 2 of tLabel, "#E0E7FF"
      set the textColor of button tName to "#3730A3"
      -- (a second tap soon after the first is a double click: it
      -- toggles again)
      set the script of button tName to "on mouseUp" & return & \
            "   psPhone" && quote & tName & quote & return & "end mouseUp" & return & \
            "on mouseDoubleUp" & return & "   psPhone" && quote & tName & quote & return & "end mouseDoubleUp"
      set the itemDelimiter to comma
   end repeat
   create graphic "Frame"
   set the style of graphic "Frame" to "roundrect"
   set the roundRadius of graphic "Frame" to 20
   set the opaque of graphic "Frame" to true
   set the lineSize of graphic "Frame" to 0
   set the backgroundColor of graphic "Frame" to "#E4E6F6"
   create field "Frame Hint"
   setLabel the long id of field "Frame Hint", "Your photo goes here.", 15, "#6B6F86", "plain"
   set the textAlign of field "Frame Hint" to "center"
   create graphic "Ball"
   set the style of graphic "Ball" to "oval"
   set the opaque of graphic "Ball" to true
   set the lineSize of graphic "Ball" to 0
   set the backgroundColor of graphic "Ball" to "#F59E0B"
   set the width of graphic "Ball" to 36
   set the height of graphic "Ball" to 36
end buildPhone

-- The play area's gestures: they come to the control under the finger
-- (the pad or the dot) and up to the group, which keeps them
private function playScript
   local tScript
   put "on swipe pDirection" & return & "   psPlaySwipe pDirection" & return & "end swipe" & return & \
         "on pinchStart" & return & "   psPlayPinchStart" & return & "end pinchStart" & return & \
         "on pinch pScale" & return & "   psPlayPinch pScale" & return & "end pinch" & return & \
         "on pinchEnd" & return & "   psPlayPinchEnd" & return & "end pinchEnd" & return & \
         "on longPress pX, pY" & return & "   psPlayLongPress pX, pY" & return & "end longPress" & return & \
         "on touchStart pId, pX, pY" & return & "   psPlayTouch ~start~, pId, pX, pY" & return & "end touchStart" & return & \
         "on touchMove pId, pX, pY" & return & "   psPlayTouch ~move~, pId, pX, pY" & return & "end touchMove" & return & \
         "on touchEnd pId" & return & "   psPlayTouch ~end~, pId" & return & "end touchEnd" & return & \
         "on touchRelease pId" & return & "   psPlayTouch ~end~, pId" & return & "end touchRelease" into tScript
   replace "~" with quote in tScript
   return tScript
end playScript

private function listScript
   return "on mouseDown" & return & \
         "   psListDown the long id of me" & return & \
         "end mouseDown" & return & \
         "on mouseUp" & return & \
         "   psListUp the long id of me" & return & \
         "end mouseUp"
end listScript

-- The stack's script: phone-starter-stack.livecodescript beside this
-- file, without its first line (a script-only stack's header, there so
-- that editors and checkers read it as xTalk)
private function stackScript
   local tFile, tScript
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "phone-starter-stack.livecodescript" into the last item of tFile
   set the itemDelimiter to comma
   open file tFile for "UTF-8" text read
   if the result is not empty then
      throw "cannot read" && tFile & ":" && the result
   end if
   read from file tFile until end
   put it into tScript
   close file tFile
   delete line 1 of tScript
   return tScript
end stackScript
