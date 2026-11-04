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
-- (mwcFit), and stop the library and fill again in a page that keeps its
-- own layout (mwcStopAndKeep). It changes nothing in the Phone Starter.

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
   put "saverect=" & the rect of button "Save" of card "Form" of stack kStack & return after tState
   put "screen=" & mwcOneLine(field "Screen" of card "Home" of stack kStack) & return after tState
   put "tabs=" & the top of graphic "Tabs Back" of card "Home" of stack kStack & return after tState
   put "farhit=" & (the cHit of stack "MobileWebCheck" is true) & return after tState
   put false into tFull
   if there is a stack "Wide Check" then
      put the fullscreen of stack "Wide Check" into tFull
   end if
   put "fullscreen=" & tFull after tState
   return tState
end mwcState

private function mwcOneLine pText
   replace return with "|" in pText
   return pText
end mwcOneLine

-- A stack laid out for a desktop, 800 by 500, with a button in its far
-- corner, fitted to the phone with mwFitStack: a tap where the button is
-- drawn must reach it
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
   go stack "Wide Check"
   mwStart "Wide Check", "none"
   mwFitStack "Wide Check"
   return the result
end mwcFit

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

-- The Phone Starter's own script, to compare with the file it is built
-- from (tools/web-player/phone-starter-stack.livecodescript)
function mwcStarterScript
   return the script of stack kStack
end mwcStarterScript
