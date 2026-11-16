script "stack_Quick_Start_Guide"
-- Stack file: ide/Resources/Examples/Remastered/Quick Start Guide.oxtstack
-- Object: stack "Quick Start Guide"
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

--Quick Start Guide: Terry Little's Quick Start v1.5, remastered for OXT-Beyond in 2026
--Quick Start v1.5, Terry Little (c)2024, All Rights Reserved
--This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
--as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--This program is distributed in the hope that it will be useful, but without any warranty; without even the implied warranty of
--merchantability or fitness for a particular purpose. See the GNU General Public License for more details. <http://www.gnu.org/licenses/>.

--Each lesson is a card: the things to try at the left of its stage, the narrator under them, and the
--notes at the right (the field "Info"). The notes and the narrator are the background groups "Notes"
--and "Narration", as Terry's were. The sidebar, the header, the stage and the scripts drawer are the
--groups "Frame", "Workbench" and "Scripts", which the script of the group "Frame" runs.
--His bar of buttons "<Prev" and " Next>" (go prev cd and go next cd, with a quick dissolve) is
--the sidebar here: its Back and Next, and the arrow keys, go from lesson to lesson. His field
--"Title" heads the narrator.

on preOpenCard
   if there is a fld "Title" then put "("& (the number of this cd - 1) &")"&& the short name of this cd into fld "Title"  --the front page is card 1, so lesson 1 is card 2
   if there is a fld "Info" then set the vScroll of fld "Info" to "0"  --top
   if there is a grp "Narrator" then set the cLine of grp "Narrator" to "1"  --start over, custom prop (the narrator is a group here)
   narratorReset  --(remaster) the narrator's words start over too
   notesCodeFont  --(remaster) the code in the notes, in the font of the scripts panel
   scrollStop  --(remaster) a scroll still going stops, so this lesson's notes stay at the top
   scrollThumbs  --(remaster) the thumbs that show how far down the notes are
end preOpenCard

--(remaster) The narrator: what it is about to read, the words it reads, and how far it is

command narratorReset
   local tError
   try
      revStopSpeech  --the last lesson's voice stops when another card opens
   catch tError  --no voice here, so nothing to stop
   end try
   if there is no fld "Said" or there is no fld "Lesson" then exit narratorReset
   set the textColor of fld "Said" to narratorInk(false)  --(dark enough to read on the balloon's tint; light on the dark one)
   put "Press Read it to me, and I will read this lesson to you, a paragraph at each click. " & \
         "Try each thing as I go." into fld "Said"
   set the vScroll of fld "Said" to 0
   put the number of lines of fld "Lesson" && "paragraphs, one at each click" into fld "Progress"
end narratorReset

function narratorInk pReading  --the colour of the narrator's words, in the look the window has on (the group "Frame" keeps it in the stack's uLook)
   if the uLook of this stack is "dark" then
      if pReading is true then return "255,255,255"
      return "226,232,240"
   end if
   if pReading is true then return "15,23,42"
   return "71,85,105"
end narratorInk

command narratorShow pLine
   if there is no fld "Said" or there is no fld "Lesson" then exit narratorShow
   set the textColor of fld "Said" to narratorInk(true)
   put word 1 to -1 of line pLine of fld "Lesson" into fld "Said"
   set the vScroll of fld "Said" to 0
   put "Paragraph" && pLine && "of" && the number of lines of fld "Lesson" into fld "Progress"
   scrollThumb the long id of fld "Said"
end narratorShow

command narratorNoVoice  --a computer, or a browser, that cannot speak
   if there is a fld "Progress" then
      put "  " & numToCodepoint(183) & "  no voice here" after fld "Progress"
   end if
end narratorNoVoice

command narratorStopped
   if there is a fld "Progress" and there is a grp "Narrator" then
      put "Stopped: paragraph" && the cLine of grp "Narrator" && "is next" into fld "Progress"
   end if
end narratorStopped

--(remaster) The code in the notes is in Source Code Pro, which the IDE has: where it has not got
--it, the code is in the font the scripts panel found for code

command notesCodeFont
   local tFont, tLine
   if there is no fld "Info" or there is no fld "codeText" then exit notesCodeFont
   if "Source Code Pro" is among the lines of the fontNames then exit notesCodeFont
   put the textFont of fld "codeText" into tFont
   if tFont is empty then exit notesCodeFont
   repeat with tLine = 1 to the number of lines of fld "Info"
      if the textFont of line tLine of fld "Info" is "Source Code Pro" then
         set the textFont of line tLine of fld "Info" to tFont
      end if
   end repeat
end notesCodeFont

--(remaster) The notes, the list of commands and the narrator's words scroll with the wheel, without a
--scrollbar, as the scripts panel does: a slim thumb beside each shows how far down it is, and can
--be dragged. A field that scrolls so names its thumb in its custom property cThumb.

local sGlideField, sGlideGoal, sDragField, sDragFrom, sDragScroll

on rawKeyDown pKey
   local tField
   if pKey is not 65308 and pKey is not 65309 then pass rawKeyDown
   put scrollFieldAt(the mouseLoc) into tField
   if tField is empty then pass rawKeyDown
   if pKey is 65308 then scrollBy tField, 48
   else scrollBy tField, -48
end rawKeyDown

command scrollBy pField, pAmount
   local tGoing
   put sGlideField is pField and sGlideGoal is not empty into tGoing
   if not tGoing then
      put pField into sGlideField
      put the vScroll of pField into sGlideGoal
   end if
   put max(0, min(sGlideGoal + pAmount, scrollRoom(pField))) into sGlideGoal
   if not tGoing then scrollGlide  --a glide already going goes on, to the new goal
end scrollBy

--one step of the scroll toward where the wheel is taking it
on scrollGlide
   local tNow, tStep
   if sGlideGoal is empty or sGlideField is empty or not exists(sGlideField) then exit scrollGlide
   put the vScroll of sGlideField into tNow
   put round((sGlideGoal - tNow) * 0.35) into tStep
   if abs(sGlideGoal - tNow) <= 1 or tStep is 0 then
      set the vScroll of sGlideField to sGlideGoal
      put empty into sGlideGoal
   else
      set the vScroll of sGlideField to tNow + tStep
      if the vScroll of sGlideField is tNow then
         put empty into sGlideGoal  --it goes no further: its text has changed under it
      else
         send "scrollGlide" to me in 16 milliseconds
      end if
   end if
   scrollThumb sGlideField
end scrollGlide

--a scroll still going, or a thumb still held, stops as another card opens: the notes are one
--field on every card, so a scroll left going would carry on down the next lesson's notes
command scrollStop
   put empty into sGlideGoal
   put empty into sGlideField
   put empty into sDragField
end scrollStop

--the field the pointer is over that scrolls, but under the scripts drawer
function scrollFieldAt pLoc
   local tName
   if there is a grp "Scripts" and the visible of grp "Scripts" and there is a grc "codeBg" then
      if pLoc is within the rect of grc "codeBg" then return empty
   end if
   repeat for each item tName in "Lesson,Info,Display,Said"
      if there is a fld tName then
         if the visible of fld tName and pLoc is within the rect of fld tName then
            return the long id of fld tName
         end if
      end if
   end repeat
   return empty
end scrollFieldAt

--how far down a field scrolls, as the engine has it: set further down than it goes, its vScroll
--stops at the bottom. (Its formattedHeight minus its height is a few pixels out: it counts a
--border the field does not show, and a glide toward it would never arrive.)
function scrollRoom pField
   local tNow, tRoom
   lock screen
   put the vScroll of pField into tNow
   set the vScroll of pField to the formattedHeight of pField + the height of pField
   put the vScroll of pField into tRoom
   set the vScroll of pField to tNow
   unlock screen
   return max(0, tRoom)
end scrollRoom

command scrollThumbs
   local tName
   repeat for each item tName in "Info,Display,Said,Lesson"
      if there is a fld tName then scrollThumb the long id of fld tName
   end repeat
end scrollThumbs

command scrollThumb pField
   local tThumb, tRoom, tTrack, tSize, tTop
   put the cThumb of pField into tThumb
   if tThumb is empty or there is no grc tThumb then exit scrollThumb
   put scrollRoom(pField) into tRoom
   if tRoom < 8 or not the visible of pField then
      hide grc tThumb
      exit scrollThumb
   end if
   put the height of pField - 16 into tTrack
   put max(24, round(tTrack * tTrack / (tTrack + tRoom))) into tSize
   put the top of pField + 8 + round((tTrack - tSize) * min(1, the vScroll of pField / tRoom)) into tTop
   set the rect of grc tThumb to item 1 of the rect of grc tThumb, tTop, item 3 of the rect of grc tThumb, tTop + tSize
   show grc tThumb
end scrollThumb

--the field a thumb is beside, on this card
function thumbField pThumb
   local tName
   repeat for each item tName in "Info,Display,Said,Lesson"
      if there is a fld tName then
         if the cThumb of fld tName is pThumb then return the long id of fld tName
      end if
   end repeat
   return empty
end thumbField

--a thumb, dragged: its field goes as far down as the thumb does
on mouseDown pButton
   local tField
   if pButton is 1 and word 1 of the name of the target is "graphic" then
      put thumbField(the short name of the target) into tField
      if tField is not empty then
         put tField into sDragField
         put item 2 of the mouseLoc into sDragFrom
         put the vScroll of tField into sDragScroll
         put empty into sGlideGoal
      end if
   end if
   pass mouseDown
end mouseDown

on mouseMove pX, pY
   local tTrack, tRoom
   if sDragField is empty then pass mouseMove
   if not exists(sDragField) then
      put empty into sDragField
      pass mouseMove
   end if
   put scrollRoom(sDragField) into tRoom
   put the height of sDragField - 16 - the height of grc (the cThumb of sDragField) into tTrack
   if tTrack > 0 then
      set the vScroll of sDragField to max(0, min(tRoom, sDragScroll + round((pY - sDragFrom) * tRoom / tTrack)))
      scrollThumb sDragField
   end if
   pass mouseMove
end mouseMove

on mouseUp pButton
   put empty into sDragField
   pass mouseUp
end mouseUp

on mouseRelease pButton
   put empty into sDragField
   pass mouseRelease
end mouseRelease

--a field's thumb, as the pointer comes to it (a script may have changed its text)
on mouseEnter
   local tObj
   put the long id of the target into tObj
   if word 1 of tObj is "field" then
      if the cThumb of tObj is not empty then scrollThumb tObj
   end if
   pass mouseEnter
end mouseEnter
