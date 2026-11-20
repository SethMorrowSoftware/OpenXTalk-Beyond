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

-- Builds stacks/Beyond Beats.oxtstack, a beat studio for a browser.
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
--   card "Studio"  the top bar (Play, Pattern and Song, the tempo, the
--                  swing, Undo, Redo and File), the pattern list, the main
--                  panel with its four tabs and a group a view over it:
--                  "View Rack" (twelve channel rows, each a swatch, the
--                  sound's name, mute and solo, volume and pan, and 32
--                  pads), "View Piano" (24 keys, their lanes and 64
--                  notes), "View Song" (a ruler and eight tracks of 32
--                  bars) and "View Mixer" (twelve strips and the
--                  master's, with meters); the status line, the sound
--                  picker and the File menu, groups over the panel
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
constant kMaxPatterns = 16
constant kMaxSteps = 32
constant kMaxNotes = 64
constant kTracks = 8
constant kViewBars = 32
constant kKeys = 24
constant kKit = "Kick,Boom,Snare,Rim,Clap,Closed hat,Open hat,Crash,Ride,Low tom,High tom,Shaker,Cowbell,Clave,Snap,Bass"
constant kSynths = "Saw lead,Square bass,Soft pad,Pluck,Keys"
constant kUserSlots = 8

constant kNight = "#0B0D1F"
constant kPanel = "#151839"
constant kCell = "#1F2249"
constant kInk = "#F4EEFF"
constant kMuted = "#9A96C0"
constant kDim = "#4A4870"
constant kAmber = "#FFB52E"
constant kEmber = "#FF7A3D"
constant kMeter = "#7CF29A"

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
   local n, s, i, t, b, k, tTemp, tName, tG
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
   makeLabel "Logo", "Beyond Beats" & return & "beat studio", 18, kAmber, "bold"
   set the textSize of line 2 of field "Logo" to 11
   set the textColor of line 2 of field "Logo" to kMuted
   set the textStyle of line 2 of field "Logo" to "plain"
   set the fixedLineHeight of field "Logo" to false
   makeButton "Play", "Play", kEmber, kNight
   set the textSize of button "Play" to 16
   makeButton "Mode Pattern", "Pattern", kAmber, kNight
   set the tooltip of button "Mode Pattern" to "Play loops the pattern chosen"
   makeButton "Mode Song", "Song", kCell, kMuted
   set the tooltip of button "Mode Song" to "Play plays the playlist"
   makeLabel "Tempo Label", "Tempo", 13, kMuted, "plain"
   set the textAlign of field "Tempo Label" to "right"
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
   makeButton "Undo", "Undo", kCell, kInk
   set the tooltip of button "Undo" to "Undo (Ctrl+Z)"
   makeButton "Redo", "Redo", kCell, kInk
   set the tooltip of button "Redo" to "Redo (Ctrl+Y)"
   makeButton "File", "File", kCell, kInk

   -- the pattern list
   makeBox "Side", kPanel
   makeLabel "Patterns Label", "Patterns", 13, kMuted, "bold"
   repeat with i = 1 to kMaxPatterns
      makeBox "pswatch" && i, kAmber
   end repeat
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
   makeLabel "Patterns Hint", "Double-click a name to rename it", 10, kDim, "plain"

   -- the main panel, under its views
   makeBox "Rack", kPanel

   -- the rack
   makeGroup "View Rack"
   makeLabel "Vol Label", "Volume", 11, kMuted, "plain", "View Rack"
   makeLabel "Pan Label", "Pan", 11, kMuted, "plain", "View Rack"
   repeat with s = 1 to kMaxSteps
      makeBox "dot" && s, kCell, "View Rack"
   end repeat
   makeBox "Chosen", kAmber, "View Rack"
   repeat with n = 1 to kMaxChannels
      makeBox "swatch" && n, kAmber, "View Rack"
      set the tooltip of graphic ("swatch" && n) to "Play it, and edit its notes in the piano roll"
      makeButton "chan" && n, "Kick", kCell, kInk, "View Rack"
      set the textAlign of button ("chan" && n) to "left"
      set the margins of button ("chan" && n) to 8
      makeButton "mute" && n, "M", kCell, kMuted, "View Rack"
      set the textSize of button ("mute" && n) to 11
      set the tooltip of button ("mute" && n) to "Mute"
      makeButton "solo" && n, "S", kCell, kMuted, "View Rack"
      set the textSize of button ("solo" && n) to 11
      set the tooltip of button ("solo" && n) to "Solo"
      makeBox "vol" && n, kCell, "View Rack"
      makeBox "volfill" && n, kAmber, "View Rack"
      makeBox "pan" && n, kCell, "View Rack"
      makeBox "panfill" && n, kAmber, "View Rack"
      repeat with s = 1 to kMaxSteps
         makeBox "pad" && n & comma & s, kCell, "View Rack"
      end repeat
   end repeat
   makeButton "Add Channel", "+ Add channel", kCell, kMuted, "View Rack"
   makeBox "Head", kAmber, "View Rack"
   set the blendLevel of graphic "Head" to 78
   set the visible of graphic "Head" to false

   -- the piano roll
   makeGroup "View Piano"
   makeButton "Piano Prev", "<", kCell, kInk, "View Piano"
   set the tooltip of button "Piano Prev" to "The channel before"
   makeLabel "Piano Chan", "1. Kick", 14, kAmber, "bold", "View Piano"
   makeButton "Piano Next", ">", kCell, kInk, "View Piano"
   set the tooltip of button "Piano Next" to "The next channel"
   makeButton "Oct Down", "-", kCell, kInk, "View Piano"
   set the tooltip of button "Oct Down" to "An octave lower"
   makeLabel "Oct Label", "C3 to B4", 12, kInk, "plain", "View Piano"
   set the textAlign of field "Oct Label" to "center"
   makeButton "Oct Up", "+", kCell, kInk, "View Piano"
   set the tooltip of button "Oct Up" to "An octave higher"
   makeLabel "Piano Info", empty, 11, kMuted, "plain", "View Piano"
   set the textAlign of field "Piano Info" to "right"
   repeat with k = 1 to kKeys
      makeBox "lane" && k, kCell, "View Piano"
   end repeat
   repeat with s = 1 to kMaxSteps
      makeBox "pline" && s, kDim, "View Piano"
   end repeat
   repeat with k = 1 to kKeys
      makeBox "key" && k, kInk, "View Piano"
      set the showName of graphic ("key" && k) to true
      set the textSize of graphic ("key" && k) to 9
      set the textColor of graphic ("key" && k) to kNight
   end repeat
   repeat with i = 1 to kMaxNotes
      makeBox "note" && i, kAmber, "View Piano"
      set the style of graphic ("note" && i) to "roundrect"
      set the roundRadius of graphic ("note" && i) to 6
   end repeat
   makeBox "PianoHead", kAmber, "View Piano"
   set the visible of graphic "PianoHead" to false
   makeLabel "Piano Hint", "Click: add a note, and drag to make it longer. Drag a note to move it; " & \
         "click it to take it away; shift-click: louder or softer. Click a key to hear it.", 11, kMuted, "plain", "View Piano"

   -- the playlist
   makeGroup "View Song"
   makeLabel "Bars Label", "Bars 1 to 32", 12, kMuted, "plain", "View Song"
   set the textAlign of field "Bars Label" to "right"
   makeButton "Bars Back", "<", kCell, kInk, "View Song"
   makeButton "Bars On", ">", kCell, kInk, "View Song"
   makeLabel "Ruler Label", "Bar", 11, kMuted, "plain", "View Song"
   makeBox "Ruler", kCell, "View Song"
   set the tooltip of graphic "Ruler" to "Click: where Song mode starts"
   repeat with b = 1 to kViewBars
      makeLabel "barno" && b, empty, 10, kMuted, "plain", "View Song"
   end repeat
   makeBox "StartMark", kAmber, "View Song"
   repeat with t = 1 to kTracks
      makeLabel "trk" && t, "Track" && t, 11, kMuted, "plain", "View Song"
      repeat with b = 1 to kViewBars
         put "cell" && t & comma & b into tName
         makeBox tName, kCell, "View Song"
         set the showName of graphic tName to true
         set the textSize of graphic tName to 11
         set the textStyle of graphic tName to "bold"
         set the textColor of graphic tName to kNight
      end repeat
   end repeat
   makeBox "SongHead", kAmber, "View Song"
   set the visible of graphic "SongHead" to false
   makeLabel "Song Hint", "Click: put the chosen pattern in, or take a block out. Shift-click: choose its pattern. " & \
         "Ruler: where Song starts.", 11, kMuted, "plain", "View Song"
   makeLabel "Song Length", empty, 12, kInk, "bold", "View Song"
   set the textAlign of field "Song Length" to "right"

   -- the mixer
   makeGroup "View Mixer"
   repeat for each item tName in "Filter,Reverb,Delay,Pan,Volume,Tune"
      makeLabel "Label" && tName, tName, 11, kMuted, "plain", "View Mixer"
   end repeat
   repeat with n = 0 to kMaxChannels
      if n > 0 then
         makeBox "mxsw" && n, kAmber, "View Mixer"
         makeLabel "mxname" && n, "Kick", 10, kInk, "bold", "View Mixer"
         set the textAlign of field ("mxname" && n) to "center"
         -- a strip is narrow: "Square bass" goes on two lines
         set the dontWrap of field ("mxname" && n) to false
         set the fixedLineHeight of field ("mxname" && n) to true
         set the textHeight of field ("mxname" && n) to 12
         repeat for each item tG in "cut,rev,dly,mxpan"
            makeBox tG && n, kCell, "View Mixer"
            makeBox tG & "fill" && n, kAmber, "View Mixer"
         end repeat
         set the tooltip of graphic ("cut" && n) to "Filter: drag left to make it duller"
         set the tooltip of graphic ("rev" && n) to "How much goes to the reverb"
         set the tooltip of graphic ("dly" && n) to "How much goes to the delay"
      end if
      makeBox "meterbg" && n, kNight, "View Mixer"
      makeBox "meter" && n, kMeter, "View Mixer"
      set the visible of graphic ("meter" && n) to false
      makeBox "fader" && n, kCell, "View Mixer"
      makeBox "faderfill" && n, kAmber, "View Mixer"
      makeBox "fadercap" && n, kInk, "View Mixer"
      set the style of graphic ("fadercap" && n) to "roundrect"
      set the roundRadius of graphic ("fadercap" && n) to 4
      makeLabel "mxvol" && n, "78", 11, kMuted, "plain", "View Mixer"
      set the textAlign of field ("mxvol" && n) to "center"
      if n > 0 then
         makeButton "mxmute" && n, "M", kCell, kMuted, "View Mixer"
         set the textSize of button ("mxmute" && n) to 11
         set the tooltip of button ("mxmute" && n) to "Mute"
         makeButton "mxsolo" && n, "S", kCell, kMuted, "View Mixer"
         set the textSize of button ("mxsolo" && n) to 11
         set the tooltip of button ("mxsolo" && n) to "Solo"
         makeLabel "mxtune" && n, "0", 12, kInk, "bold", "View Mixer"
         set the textAlign of field ("mxtune" && n) to "center"
         set the tooltip of field ("mxtune" && n) to "Tuning in semitones: drag up or down"
      end if
   end repeat
   makeLabel "Master Label", "Master", 11, kAmber, "bold", "View Mixer"
   set the textAlign of field "Master Label" to "center"
   makeLabel "Reverb Label", "Reverb", 12, kMuted, "plain", "View Mixer"
   makeButton "Reverb Room", "Room", kCell, kMuted, "View Mixer"
   makeButton "Reverb Hall", "Hall", kCell, kMuted, "View Mixer"
   makeLabel "Delay Label", "Delay", 12, kMuted, "plain", "View Mixer"
   makeButton "Delay 2", "1/8", kCell, kMuted, "View Mixer"
   makeButton "Delay 3", "3/16", kCell, kMuted, "View Mixer"
   makeButton "Delay 4", "1/4", kCell, kMuted, "View Mixer"
   makeLabel "Feedback Label", "Feedback", 12, kMuted, "plain", "View Mixer"
   makeBox "fb", kCell, "View Mixer"
   makeBox "fbfill", kAmber, "View Mixer"
   makeLabel "fbValue", "35%", 12, kInk, "bold", "View Mixer"
   makeLabel "Mixer Hint", "Drag a fader, a slider or a tuning (up and down). The meters move as it plays.", \
         11, kMuted, "plain", "View Mixer"

   -- the tabs and the pattern's steps, over the views
   makeButton "Tab Rack", "Channels", kAmber, kNight
   makeButton "Tab Piano", "Piano roll", kCell, kMuted
   makeButton "Tab Song", "Playlist", kCell, kMuted
   makeButton "Tab Mixer", "Mixer", kCell, kMuted
   makeLabel "Steps Label", "Steps", 13, kMuted, "plain"
   set the textAlign of field "Steps Label" to "right"
   makeButton "Steps 16", "16", kCell, kMuted
   makeButton "Steps 32", "32", kCell, kMuted
   makeLabel "Status", empty, 13, kMuted, "plain"

   -- the sound picker
   create group "Picker"
   makeBox "Picker Back", "#23275A", "Picker"
   set the style of graphic "Picker Back" to "roundrect"
   set the roundRadius of graphic "Picker Back" to 14
   set the lineSize of graphic "Picker Back" to 1
   set the foregroundColor of graphic "Picker Back" to kEmber
   makeLabel "Picker Title", "Choose a sound", 13, kAmber, "bold", "Picker"
   makeLabel "Pick Kit Label", "Drums and the kit", 11, kMuted, "plain", "Picker"
   makeLabel "Pick Synth Label", "Synths: play their notes in the piano roll", 11, kMuted, "plain", "Picker"
   makeLabel "Pick User Label", "Your samples (an empty one loads a sound file)", 11, kMuted, "plain", "Picker"
   repeat with i = 1 to the number of items of kKit
      makeButton "pick" && i, item i of kKit, kCell, kInk, "Picker"
   end repeat
   repeat with i = 1 to the number of items of kSynths
      makeButton "pick" && i + the number of items of kKit, item i of kSynths, kCell, kInk, "Picker"
   end repeat
   repeat with i = 1 to kUserSlots
      makeButton "pick" && i + the number of items of kKit + the number of items of kSynths, "+ load", kCell, kInk, "Picker"
      set the textSize of button ("pick" && i + the number of items of kKit + the number of items of kSynths) to 11
   end repeat
   makeButton "Pick Load", "Load a sample...", kCell, kAmber, "Picker"
   makeButton "Pick Remove", "Remove this channel", "#3A1F35", kEmber, "Picker"
   set the margins of group "Picker" to 0
   set the showBorder of group "Picker" to false
   set the opaque of group "Picker" to false

   -- the File menu
   create group "Files"
   makeBox "Files Back", "#23275A", "Files"
   set the style of graphic "Files Back" to "roundrect"
   set the roundRadius of graphic "Files Back" to 12
   set the lineSize of graphic "Files Back" to 1
   set the foregroundColor of graphic "Files Back" to kEmber
   makeButton "File Open", "Open a song...", kCell, kInk, "Files"
   makeButton "File Save", "Save the song...", kCell, kInk, "Files"
   makeButton "File Export", "Export a WAV...", kCell, kInk, "Files"
   makeButton "File Sample", "Add a sample as a channel...", kCell, kInk, "Files"
   makeButton "New", "New empty song", kCell, kInk, "Files"
   makeButton "Demo", "Demo song", kCell, kInk, "Files"
   repeat for each item tName in "File Open,File Save,File Export,File Sample,New,Demo"
      set the textAlign of button tName to "left"
      set the margins of button tName to 10
   end repeat
   set the margins of group "Files" to 0
   set the showBorder of group "Files" to false
   set the opaque of group "Files" to false

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
   if it is not "handled" then
      throw "btTestBegin did not run:" && it
   end if
   dispatch "btTestEnd" to card "Studio" of stack kStack
   if there is a file tTemp then
      delete file tTemp
   end if
   if there is a folder (tTemp & "-samples") then
      delete folder (tTemp & "-samples")
   end if

   set the visible of stack kStack to true
   save stack kStack as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
end buildStack

-- A group a view is made in: no border, no background of its own.
private command makeGroup pName
   create group pName
   set the margins of group pName to 0
   set the showBorder of group pName to false
   set the opaque of group pName to false
end makeGroup

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
