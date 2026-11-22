script "Render3DTourBuilder"
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

-- Builds stacks/Render3D Tour.oxtstack: ten small 3D scenes, each showing
-- one thing render3dxt (the xTalk Suite's 3D renderer) can do. The stack
-- is never edited by hand: change this script or the tour's script
-- (render3d-tour-stack.livecodescript) and build it again, with any
-- OXT-Beyond engine (the IDE's, or the development engine of a build):
--
--    <engine> -ui tools/web-player/render3d-tour.livecodescript
--
-- OXT_RENDER3D_TOUR names another file to write. It prints "BUILT <file>"
-- or "FAILED <why>". The engine that builds it does not need render3dxt:
-- nothing of the tour's script runs here.
--
-- What goes in: one card, "Tour", with the picture (image "View", exactly
-- the size of the pictures the tour draws, because imageData is not
-- scaled), how fast it is going (Fps, on the picture's corner), a button for each exhibit (Ex1 to Ex10), three switches, the
-- words about an exhibit, what a picture cost, the labels that float over
-- the picture (Tag1 to Tag6), and what is said when the engine has no
-- render3dxt (Missing). No file goes in: the tour makes its textures and
-- models in script. The stack's script is set last, so that nothing it
-- does runs while the stack is built.

constant kWidth = 960
constant kHeight = 560
constant kViewW = 640
constant kViewH = 480
constant kViewLeft = 16
constant kViewTop = 62
constant kSideLeft = 672
constant kSideRight = 944
constant kTags = 6

-- The look
constant kPage = "#12151F"
constant kPanel = "#1C2130"
constant kInk = "#EEF1F7"
constant kSoft = "#A9B2C7"
constant kAccent = "#FF8A3D"
constant kButton = "#2A3146"

constant kExhibitNames = "Welcome,Shapes,Textures,Materials,Lights,A model,Your own mesh,Fog and distance,Click and aim,Many things"

on startup
   local tFile, tError
   put $OXT_RENDER3D_TOUR into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/Render3D Tour.oxtstack" into the last item of tFile
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
   local tName, tScript, tIndex, tTop, tLeft
   put "Render3D Tour" into tName
   if there is a stack tName then
      delete stack tName
   end if
   create invisible stack tName
   set the defaultStack to tName
   set the rect of stack tName to 100, 60, 100 + kWidth, 60 + kHeight
   set the resizable of stack tName to false
   set the backgroundColor of stack tName to kPage
   set the textFont of stack tName to empty
   set the textSize of stack tName to 13
   set the name of card 1 of stack tName to "Tour"
   set the backgroundColor of card "Tour" to kPage

   makeLabel "Heading", "Render3D Tour", 22, kInk, "bold"
   set the rect of field "Heading" to kViewLeft, 6, 360, 46
   makeLabel "Sub", "A 3D picture in an ordinary image, drawn by render3dxt. Drag it to look round; the wheel, or + and -, comes closer.", 12, kSoft, "plain"
   set the rect of field "Sub" to 250, 16, kSideRight, 40

   -- the picture and what frames it
   create graphic "Frame"
   set the style of graphic "Frame" to "rectangle"
   set the opaque of graphic "Frame" to true
   set the backgroundColor of graphic "Frame" to kPanel
   set the lineSize of graphic "Frame" to 0
   set the rect of graphic "Frame" to kViewLeft - 6, kViewTop - 6, kViewLeft + kViewW + 6, kViewTop + kViewH + 6
   create image "View"
   set the lockLocation of image "View" to true
   set the rect of image "View" to kViewLeft, kViewTop, kViewLeft + kViewW, kViewTop + kViewH
   makeText "Missing", "This tour needs render3dxt, the xTalk Suite's 3D renderer, and this OXT-Beyond does not have it yet. It comes with newer versions.", 15, kInk
   set the rect of field "Missing" to kViewLeft + 80, kViewTop + 190, kViewLeft + kViewW - 80, kViewTop + 290
   set the textAlign of field "Missing" to "center"
   set the visible of field "Missing" to false

   -- how fast it is going, on the picture's corner
   makeLabel "Fps", empty, 13, kInk, "bold"
   set the textAlign of field "Fps" to "center"
   set the opaque of field "Fps" to true
   set the backgroundColor of field "Fps" to kPage
   set the blendLevel of field "Fps" to 20
   set the margins of field "Fps" to 5
   set the rect of field "Fps" to kViewLeft + 8, kViewTop + 8, kViewLeft + 156, kViewTop + 38

   -- the labels over the picture
   repeat with tIndex = 1 to kTags
      makeLabel "Tag" & tIndex, empty, 12, kInk, "bold"
      set the textAlign of field ("Tag" & tIndex) to "center"
      set the opaque of field ("Tag" & tIndex) to true
      set the backgroundColor of field ("Tag" & tIndex) to kPage
      set the blendLevel of field ("Tag" & tIndex) to 25
      set the rect of field ("Tag" & tIndex) to 0, 0, 170, 24
      set the visible of field ("Tag" & tIndex) to false
   end repeat

   -- the exhibits, two to a row
   makeLabel "Exhibits", "EXHIBITS", 11, kAccent, "bold"
   set the rect of field "Exhibits" to kSideLeft, kViewTop - 6, kSideRight, kViewTop + 16
   repeat with tIndex = 1 to the number of items of kExhibitNames
      put kViewTop + 20 + ((tIndex - 1) div 2) * 30 into tTop
      put kSideLeft + ((tIndex - 1) mod 2) * 138 into tLeft
      makeButton "Ex" & tIndex, tIndex & "." && item tIndex of kExhibitNames
      set the rect of button ("Ex" & tIndex) to tLeft, tTop, tLeft + 134, tTop + 26
   end repeat

   makeLabel "Look", "THE PICTURE (LIT IS ON)", 11, kAccent, "bold"
   set the rect of field "Look" to kSideLeft, kViewTop + 178, kSideRight, kViewTop + 200
   makeTick "Smooth", "Smooth edges"
   set the rect of button "Smooth" to kSideLeft, kViewTop + 204, kSideLeft + 118, kViewTop + 228
   makeTick "Fog", "Fog"
   set the rect of button "Fog" to kSideLeft + 124, kViewTop + 204, kSideLeft + 190, kViewTop + 228
   makeTick "Spin", "Move"
   set the rect of button "Spin" to kSideLeft + 196, kViewTop + 204, kSideRight, kViewTop + 228

   makeLabel "AboutCap", "WHAT THIS SHOWS", 11, kAccent, "bold"
   set the rect of field "AboutCap" to kSideLeft, kViewTop + 240, kSideRight, kViewTop + 262
   makeText "About", empty, 13, kInk
   set the rect of field "About" to kSideLeft, kViewTop + 264, kSideRight, kViewTop + 432
   makeText "Stats", empty, 12, kSoft
   set the rect of field "Stats" to kSideLeft, kViewTop + 436, kSideRight, kViewTop + 492

   -- last: the script, which runs when the stack is opened
   put stackScript() into tScript
   set the script of stack tName to tScript
   if the result is not empty then
      throw "the stack's script does not compile:" && the result
   end if
   set the visible of stack tName to true
   save stack tName as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
end buildStack

-- One line of words that nobody types into
private command makeLabel pName, pText, pSize, pColor, pStyle
   create field pName
   setQuiet pName
   set the dontWrap of field pName to true
   set the textSize of field pName to pSize
   roomyLines pName, pSize
   set the textStyle of field pName to pStyle
   set the foregroundColor of field pName to pColor
   put pText into field pName
end makeLabel

-- Words that wrap
private command makeText pName, pText, pSize, pColor
   create field pName
   setQuiet pName
   set the dontWrap of field pName to false
   set the textSize of field pName to pSize
   roomyLines pName, pSize
   set the foregroundColor of field pName to pColor
   put pText into field pName
end makeText

-- Lines tall enough for any system's font. Left alone, a line is as tall
-- as the font the stack was BUILT with wants, and where it is opened the
-- font may be taller: on Windows the tops of the capitals were cut off
-- (seen 2026-11-21). So the height is said: half as much again as the size.
private command roomyLines pName, pSize
   set the fixedLineHeight of field pName to true
   set the textHeight of field pName to round(pSize * 1.5)
end roomyLines

private command setQuiet pName
   set the lockText of field pName to true
   set the traversalOn of field pName to false
   set the opaque of field pName to false
   set the showBorder of field pName to false
   set the threeD of field pName to false
   set the borderWidth of field pName to 0
   set the margins of field pName to 2
   set the vScrollbar of field pName to false
   set the autoHilite of field pName to false
end setQuiet

private command makeButton pName, pLabel
   create button pName
   set the label of button pName to pLabel
   set the style of button pName to "roundrect"
   set the opaque of button pName to true
   set the showBorder of button pName to false
   set the threeD of button pName to false
   set the shadow of button pName to false
   set the traversalOn of button pName to false
   set the textSize of button pName to 12
   set the backgroundColor of button pName to kButton
   set the foregroundColor of button pName to kInk
   set the hiliteColor of button pName to kAccent
   set the autoHilite of button pName to false
end makeButton

-- A switch: the same button as an exhibit's, lit while it is on. Not a
-- tick box: the system draws those, in its own theme's colours, and under
-- a dark theme a tick box's words came out white on white in another
-- stack (the suite's physics demo on Windows, 2026-11-20).
private command makeTick pName, pLabel
   makeButton pName, pLabel
end makeTick

private function fileText pFile
   local tText
   open file pFile for "UTF-8" text read
   if the result is not empty then
      throw "cannot read" && pFile & ":" && the result
   end if
   read from file pFile until end
   put it into tText
   close file pFile
   return tText
end fileText

-- The tour's script: the file beside this one, less its first line (which
-- belongs to a script-only stack, not to a script)
private function stackScript
   local tFile, tScript
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "render3d-tour-stack.livecodescript" into the last item of tFile
   set the itemDelimiter to comma
   put fileText(tFile) into tScript
   delete line 1 of tScript
   return tScript
end stackScript
