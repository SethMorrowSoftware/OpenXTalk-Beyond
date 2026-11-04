script "MobileWebCheck"
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

-- tools/ci/mobile_web_check.py's eyes in the page: a script-only stack
-- that the check's web standalone of the Phone Starter carries beside the
-- Mobile Web library. Its javascriptHandlers (set by the standalone's
-- startup script) let the check read what the Phone Starter shows
-- (mwcState), open a stack laid out for a desktop, fitted to the phone
-- (mwcFit), fit it again with mwFitStack alone (mwcFitAlone), and stop
-- the library and fill again in a page that keeps its own layout
-- (mwcStopAndKeep), and ask for the camera, the share sheet and the
-- whole screen other than from a tap (mwcNotFromATap). It changes nothing
-- in the Phone Starter.

constant kStack = "Phone Starter"

-- What the Phone Starter shows, a line "name=value" each (returns in a
-- value become |)
function mwcState
   local tState, tFull
   put "card=" & the short name of this card of stack kStack & return after tState
   put "rect=" & the rect of stack kStack & return after tState
   put "picked=" & field "Picked" of card "List" of stack kStack & return after tState
   put "vscroll=" & the vScroll of field "Items" of card "List" of stack kStack & return after tState
   put "said=" & field "Said" of card "Gestures" of stack kStack & return after tState
   put "dot=" & the width of graphic "Dot" of card "Gestures" of stack kStack & return after tState
   put "saved=" & field "Saved" of card "Form" of stack kStack & return after tState
   put "name=" & field "Name" of card "Form" of stack kStack & return after tState
   put "notestop=" & the top of field "Notes" of card "Form" of stack kStack & return after tState
   put "namerect=" & the rect of field "Name" of card "Form" of stack kStack & return after tState
   put "notesleft=" & the left of field "Notes" of card "Form" of stack kStack & comma & \
         the right of field "Notes" of card "Form" of stack kStack & return after tState
   put "saverect=" & the rect of button "Save" of card "Form" of stack kStack & return after tState
   put "screen=" & mwcOneLine(field "Screen" of card "Home" of stack kStack) & return after tState
   put "tabs=" & the top of graphic "Tabs Back" of card "Home" of stack kStack & return after tState
   put "contentbottom=" & mwcContentBottom() & return after tState
   put "farhit=" & (the cHit of stack "MobileWebCheck" is true) & return after tState
   put false into tFull
   if there is a stack "Wide Check" then
      put the fullscreen of stack "Wide Check" into tFull
   end if
   put "fullscreen=" & tFull & return after tState
   -- the touch messages' rings on the Gestures pad, and the Phone card
   put "fingers=" & mwcFingers() & return after tState
   put "phonesaid=" & mwcOneLine(field "Phone Said" of card "Phone" of stack kStack) & return after tState
   put "ball=" & the loc of graphic "Ball" of card "Phone" of stack kStack & return after tState
   put "frame=" & the rect of graphic "Frame" of card "Phone" of stack kStack & return after tState
   if there is an image "Photo" of card "Phone" of stack kStack then
      put "photo=" & the formattedWidth of image "Photo" of card "Phone" of stack kStack & comma & \
            the formattedHeight of image "Photo" of card "Phone" of stack kStack & comma & \
            the rect of image "Photo" of card "Phone" of stack kStack & return after tState
   else
      put "photo=" & return after tState
   end if
   put "labels=" & mwcLabels() & return after tState
   put "buttons=" & mwcButtons() after tState
   return tState
end mwcState

private function mwcFingers
   local tCount
   put 0 into tCount
   repeat with i = 1 to the number of graphics of group "Play" of card "Gestures" of stack kStack
      if the short name of graphic i of group "Play" of card "Gestures" of stack kStack begins with "Finger " then
         add 1 to tCount
      end if
   end repeat
   return tCount
end mwcFingers

-- The Phone card's buttons, "name:left,top,right,bottom" separated by ;
private function mwcButtons
   local tList, tName
   repeat for each item tName in "Camera,Share,Where,Tilt,Awake,Full"
      put tName & ":" & the rect of button tName of card "Phone" of stack kStack & ";" after tList
   end repeat
   delete the last char of tList
   return tList
end mwcButtons

-- and their labels, "name:label" separated by ;
private function mwcLabels
   local tList, tName
   repeat for each item tName in "Camera,Share,Where,Tilt,Awake,Full"
      put tName & ":" & the label of button tName of card "Phone" of stack kStack & ";" after tList
   end repeat
   delete the last char of tList
   return tList
end mwcLabels

-- The lowest bottom of the current card's own controls (not the header's
-- or the tab bar's), which must be above the tab bar
private function mwcContentBottom
   local tBottom, tOwner
   put 0 into tBottom
   repeat with i = 1 to the number of controls of this card of stack kStack
      put the short name of the owner of control i of this card of stack kStack into tOwner
      if tOwner is among the items of "Header,Tabs" or \
            the short name of control i of this card of stack kStack is among the items of "Header,Tabs" then
         next repeat
      end if
      if not the visible of control i of this card of stack kStack then next repeat
      put max(tBottom, the bottom of control i of this card of stack kStack) into tBottom
   end repeat
   return tBottom
end mwcContentBottom

private function mwcOneLine pText
   replace return with "|" in pText
   return pText
end mwcOneLine

-- A stack laid out for a desktop, 800 by 500, of a fixed size, with a
-- button in its far corner: mwStart alone fits it to the phone, as it is
-- too big for it, and a tap where the button is drawn must reach it
command mwcFit
   set the cHit of me to false
   if there is a stack "Wide Check" then
      delete stack "Wide Check"
   end if
   create stack "Wide Check"
   set the rect of stack "Wide Check" to 0, 0, 800, 500
   set the backgroundColor of stack "Wide Check" to "#203040"
   create button "Far" in card 1 of stack "Wide Check"
   set the rect of button "Far" of card 1 of stack "Wide Check" to 680, 420, 780, 480
   set the script of button "Far" of card 1 of stack "Wide Check" to \
         "on mouseUp" & return & "   set the cHit of stack " & quote & "MobileWebCheck" & quote & " to true" & return & "end mouseUp"
   set the resizable of stack "Wide Check" to false
   go stack "Wide Check"
   mwStart "Wide Check", "none"
   return the result
end mwcFit

-- The same stack fitted by mwFitStack alone, after mwStop: the library
-- must still fit it again when the phone turns
command mwcFitAlone
   set the cHit of me to false
   mwStop
   mwFitStack "Wide Check"
   return the result
end mwcFitAlone

-- mwStop, then mwFillScreen in a page that says it keeps its own layout
-- (data-mobile-web-fill="no", as the Stack Player's page says): whether
-- the page's fill style was there before mwStop and after it, the result
-- of that mwFillScreen, and whether the style is there after it, items
-- 1 to 4
function mwcStopAndKeep
   local tBefore, tAfter, tResult
   put mwcHasFillStyle() into tBefore
   mwStop
   put mwcHasFillStyle() into tAfter
   do "document.body.setAttribute('data-mobile-web-fill', 'no'); ''" as "JavaScript"
   mwFillScreen kStack
   put the result into tResult
   return tBefore & comma & tAfter & comma & tResult & comma & mwcHasFillStyle()
end mwcStopAndKeep

private function mwcHasFillStyle
   do "document.getElementById('oxt-mobile-web-fill') ? 'true' : 'false'" as "JavaScript"
   return the result
end mwcHasFillStyle

-- The camera, the share sheet and the whole screen asked for other than
-- from a tap, as from a timer: a browser opens none of them then, and
-- mwPickPhoto waited for a photo that could not come. Each says "not from
-- a tap" at once where the browser can tell. Items 1 to 3.
function mwcNotFromATap
   local tPhoto, tShare, tFull
   mwPickPhoto "library", 100, 100
   put the result into tPhoto
   mwShare "From the check"
   put the result into tShare
   mwFullScreen true
   put the result into tFull
   return tPhoto & comma & tShare & comma & tFull
end mwcNotFromATap

-- The Phone Starter's own script, to compare with the file it is built
-- from (tools/web-player/phone-starter-stack.livecodescript)
function mwcStarterScript
   return the script of stack kStack
end mwcStarterScript
