script "BeyondBeatsBuilder"
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

-- Builds stacks/Beyond Beats.oxtstack, a pattern studio for a browser.
-- The stack is never edited by hand: change this script, the stack's
-- script (beyond-beats-stack.livecodescript beside it) or its audio core
-- (beyond-beats/audio-core.js), and build it again, with any OXT-Beyond
-- engine (the IDE's, or the development engine of a build):
--
--    <engine> -ui tools/web-player/beyond-beats.livecodescript
--
-- OXT_BEYOND_BEATS names another file to write. It prints "BUILT <file>"
-- or "FAILED <why>".
--
-- What goes in:
--   card "Studio"  the top bar (Play, the tempo, the swing, the steps of
--                  the pattern, New and Demo), the pattern list, the
--                  channel rack (twelve rows, each a swatch, the sound's
--                  name, mute and solo, volume and pan, and 32 pads), the
--                  playhead, the status line, and the sound picker, a
--                  group over the rack
--   the audio core beyond-beats/audio-core.js, as the custom property
--                  cAudioCore, which the stack runs in the page
--   cWindow        the size it is built with, 960 by 600
--
-- Every control is made here and placed by the stack's own btLayout;
-- then the demo song is drawn on it, so that the stack's first card is a
-- picture of what it does before it has run a line in a browser.

constant kStack = "Beyond Beats"
constant kWidth = 960
constant kHeight = 600
constant kMaxChannels = 12
constant kMaxSteps = 32
constant kKit = "Kick,Boom,Snare,Rim,Clap,Closed hat,Open hat,Crash,Ride,Low tom,High tom,Shaker,Cowbell,Clave,Snap,Bass"

constant kNight = "#0B0D1F"
constant kPanel = "#151839"
constant kCell = "#1F2249"
constant kInk = "#F4EEFF"
constant kMuted = "#9A96C0"
constant kAmber = "#FFB52E"
constant kEmber = "#FF7A3D"

on startup
   local tFile, tError
   put $OXT_BEYOND_BEATS into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/Beyond Beats.oxtstack" into the last item of tFile
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
   local tCard, n, s, i, tTemp
   if there is a stack kStack then
      delete stack kStack
   end if
   create invisible stack kStack
   set the defaultStack to kStack
   set the rect of stack kStack to 100, 60, 100 + kWidth, 60 + kHeight
   set the resizable of stack kStack to false
   set the title of stack kStack to kStack
   set the backgroundColor of stack kStack to kNight
   set the textFont of stack kStack to empty
   set the textSize of stack kStack to 14
   set the cWindow of stack kStack to kWidth & comma & kHeight
   set the cAudioCore of stack kStack to textFile("beyond-beats/audio-core.js")
   set the name of card 1 of stack kStack to "Studio"

   -- the top bar
   makeBox "Bar", kPanel
   makeLabel "Logo", "Beyond Beats" & return & "pattern studio", 18, kAmber, "bold"
   set the textSize of line 2 of field "Logo" to 11
   set the textColor of line 2 of field "Logo" to kMuted
   set the textStyle of line 2 of field "Logo" to "plain"
   set the fixedLineHeight of field "Logo" to false
   makeButton "Play", "Play", kEmber, kNight
   set the textSize of button "Play" to 16
   makeLabel "Tempo Label", "Tempo", 13, kMuted, "plain"
   makeButton "Tempo Down", "-", kCell, kInk
   makeLabel "Tempo", "120", 20, kInk, "bold"
   set the textAlign of field "Tempo" to "center"
   makeButton "Tempo Up", "+", kCell, kInk
   makeLabel "Swing Label", "Swing", 13, kMuted, "plain"
   set the textAlign of field "Swing Label" to "right"
   makeBox "Swing Track", kCell
   makeBox "Swing Fill", kAmber
   makeBox "Swing Knob", kInk
   set the style of graphic "Swing Knob" to "oval"
   makeLabel "Swing Value", "0%", 13, kInk, "bold"
   makeLabel "Steps Label", "Steps", 13, kMuted, "plain"
   set the textAlign of field "Steps Label" to "right"
   makeButton "Steps 16", "16", kCell, kMuted
   makeButton "Steps 32", "32", kCell, kMuted
   makeButton "New", "New", kCell, kInk
   makeButton "Demo", "Demo", kCell, kInk

   -- the pattern list
   makeBox "Side", kPanel
   makeLabel "Patterns Label", "Patterns", 13, kMuted, "bold"
   create field "Patterns"
   set the listBehavior of field "Patterns" to true
   set the lockText of field "Patterns" to true
   set the dontWrap of field "Patterns" to true
   set the traversalOn of field "Patterns" to false
   set the showBorder of field "Patterns" to false
   set the threeD of field "Patterns" to false
   set the opaque of field "Patterns" to false
   set the vScrollbar of field "Patterns" to false
   set the textSize of field "Patterns" to 14
   set the fixedLineHeight of field "Patterns" to true
   set the textHeight of field "Patterns" to 22
   set the textColor of field "Patterns" to kInk
   set the hiliteColor of field "Patterns" to kEmber
   set the showFocusBorder of field "Patterns" to false
   makeButton "Pattern New", "New", kCell, kInk
   makeButton "Pattern Clone", "Clone", kCell, kInk
   makeButton "Pattern Clear", "Clear", kCell, kInk
   makeButton "Pattern Delete", "Delete", kCell, kInk

   -- the channel rack
   makeBox "Rack", kPanel
   makeLabel "Rack Label", "Channels", 13, kMuted, "bold"
   makeLabel "Vol Label", "Volume", 11, kMuted, "plain"
   makeLabel "Pan Label", "Pan", 11, kMuted, "plain"
   repeat with s = 1 to kMaxSteps
      makeBox "dot" && s, kCell
   end repeat
   repeat with n = 1 to kMaxChannels
      makeBox "swatch" && n, kAmber
      makeButton "chan" && n, "Kick", kCell, kInk
      set the textAlign of button ("chan" && n) to "left"
      set the margins of button ("chan" && n) to 8
      makeButton "mute" && n, "M", kCell, kMuted
      set the textSize of button ("mute" && n) to 11
      set the tooltip of button ("mute" && n) to "Mute"
      makeButton "solo" && n, "S", kCell, kMuted
      set the textSize of button ("solo" && n) to 11
      set the tooltip of button ("solo" && n) to "Solo"
      makeBox "vol" && n, kCell
      makeBox "volfill" && n, kAmber
      makeBox "pan" && n, kCell
      makeBox "panfill" && n, kAmber
      repeat with s = 1 to kMaxSteps
         makeBox "pad" && n & comma & s, kCell
      end repeat
   end repeat
   makeButton "Add Channel", "+ Add channel", kCell, kMuted
   makeBox "Head", kAmber
   set the blendLevel of graphic "Head" to 78
   set the visible of graphic "Head" to false
   makeLabel "Status", empty, 13, kMuted, "plain"

   -- the sound picker
   create group "Picker"
   makeBox "Picker Back", "#23275A" , "Picker"
   set the style of graphic "Picker Back" to "roundrect"
   set the roundRadius of graphic "Picker Back" to 14
   set the lineSize of graphic "Picker Back" to 1
   set the foregroundColor of graphic "Picker Back" to kEmber
   makeLabel "Picker Title", "Choose a sound", 13, kAmber, "bold", "Picker"
   repeat with i = 1 to the number of items of kKit
      makeButton "pick" && i, item i of kKit, kCell, kInk, "Picker"
   end repeat
   makeButton "Pick Remove", "Remove this channel", "#3A1F35", kEmber, "Picker"
   set the margins of group "Picker" to 0
   set the showBorder of group "Picker" to false
   set the opaque of group "Picker" to false

   -- the stack's script, its layout, and the demo song drawn on it
   set the script of stack kStack to textFile("beyond-beats-stack.livecodescript", true)
   if the result is not empty then
      throw "the stack's script does not compile:" && the result
   end if
   dispatch "btLayout" to card "Studio" of stack kStack
   if it is not "handled" then
      throw "btLayout did not run:" && it
   end if
   put specialFolderPath("temporary") & "/beyond-beats-build-" & the milliseconds & ".txt" into tTemp
   dispatch "btTestBegin" to card "Studio" of stack kStack with tTemp
   dispatch "btDemoSong" to card "Studio" of stack kStack
   if it is not "handled" then
      throw "btDemoSong did not run:" && it
   end if
   dispatch "btTestEnd" to card "Studio" of stack kStack
   if there is a file tTemp then
      delete file tTemp
   end if

   set the visible of stack kStack to true
   save stack kStack as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
end buildStack

-- A file beside this one, as UTF-8 text; pScript drops its first line
-- ("script ...").
private function textFile pName, pScript
   local tFile, tText
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put pName into the last item of tFile
   set the itemDelimiter to comma
   open file tFile for "UTF-8" text read
   if the result is not empty then
      throw "cannot read" && tFile & ":" && the result
   end if
   read from file tFile until end
   put it into tText
   close file tFile
   if pScript is true then
      delete line 1 of tText
   end if
   return tText
end textFile

private command makeBox pName, pColor, pGroup
   if pGroup is empty then
      create graphic pName
   else
      create graphic pName in group pGroup
   end if
   set the style of graphic pName to "rectangle"
   set the opaque of graphic pName to true
   set the lineSize of graphic pName to 0
   set the showBorder of graphic pName to false
   set the backgroundColor of graphic pName to pColor
end makeBox

private command makeLabel pName, pText, pSize, pColor, pStyle, pGroup
   if pGroup is empty then
      create field pName
   else
      create field pName in group pGroup
   end if
   set the lockText of field pName to true
   set the traversalOn of field pName to false
   set the opaque of field pName to false
   set the showBorder of field pName to false
   set the threeD of field pName to false
   set the dontWrap of field pName to true
   set the showFocusBorder of field pName to false
   set the textSize of field pName to pSize
   set the textColor of field pName to pColor
   set the textStyle of field pName to pStyle
   set the margins of field pName to 2
   set the text of field pName to pText
end makeLabel

private command makeButton pName, pLabel, pColor, pTextColor, pGroup
   if pGroup is empty then
      create button pName
   else
      create button pName in group pGroup
   end if
   set the style of button pName to "roundrect"
   set the showBorder of button pName to false
   set the threeD of button pName to false
   set the opaque of button pName to true
   set the showFocusBorder of button pName to false
   set the traversalOn of button pName to false
   set the autoHilite of button pName to false
   set the backgroundColor of button pName to pColor
   set the borderColor of button pName to pColor
   set the borderWidth of button pName to 0
   set the textColor of button pName to pTextColor
   set the textStyle of button pName to "bold"
   set the textSize of button pName to 13
   set the label of button pName to pLabel
end makeButton
