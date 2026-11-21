script "CoreInterfaceEffectiveLegacyWords"
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

/*
OXT-Beyond: the words of a field or a button with no text colour of their
own, on a light background colour that the stack gives the control, its
group or its card, are dark in the dark appearance too, as LiveCode
Community drew them (MCObject::getlegacywords). Up to 0.2.8-dp.2 they were
the dark appearance's white: white on white in a field with a white
background (seth's Windows 11 PC, 2026-11-21), and such a field's effective
foregroundColor was 255,255,255. The effective foregroundColor reads the
colour the words are drawn in. These tests read it in the appearance the
tests run in (with no screen there is no theme, and every one is black);
tools/ci/dark_switch_check.py measures what Windows shows, in both.
*/

on TestEffectiveLegacyWords
   local tDefault, tStack, tName, tFore, tPlain
   put the defaultStack into tDefault
   put "LegacyWords" & the milliseconds into tStack
   create invisible stack tStack
   set the defaultStack to tStack
   TestDiagnostic "the systemAppearance" && the systemAppearance

   -- No colours: the appearance's
   create field "Plain"
   put "Ab Cd" into field "Plain"
   -- An older stack's colours, and no text colour
   create field "Paper"
   set the backgroundColor of field "Paper" to "255,255,255"
   put "Ab Cd" into field "Paper"
   create group "Panel"
   set the backgroundColor of group "Panel" to "240,242,246"
   set the opaque of group "Panel" to true
   create field "Label" in group "Panel"
   set the opaque of field "Label" to false
   put "Ab Cd" into field "Label"
   create button "Key"
   set the backgroundColor of button "Key" to "225,229,236"
   create button "Tick"
   set the style of button "Tick" to "checkbox"
   set the opaque of button "Tick" to true
   set the backgroundColor of button "Tick" to "255,255,255"
   set the hilite of button "Tick" to true
   create field "Night"
   set the backgroundColor of field "Night" to "40,48,64"
   put "Ab Cd" into field "Night"

   repeat for each item tName in "Paper,Label,Key,Tick"
      put the effective foregroundColor of control tName of stack tStack into tFore
      TestDiagnostic tName & "'s effective foregroundColor:" && tFore
      TestAssert tName & "'s words are dark on its light colour", __IsLight(tFore) is false
      TestAssert "and" && tName && "has no text colour of its own", \
            the foregroundColor of control tName of stack tStack is empty
   end repeat

   -- A dark colour of the stack's own keeps the appearance's words, which
   -- a control with no colours has
   put the effective foregroundColor of field "Plain" of stack tStack into tPlain
   TestDiagnostic "Plain's effective foregroundColor:" && tPlain
   TestAssert "a field on a dark colour of its own has the appearance's words", \
         the effective foregroundColor of field "Night" of stack tStack is tPlain

   __Done tDefault, tStack
end TestEffectiveLegacyWords

on TestEffectiveWordsOfTheirOwn
   local tDefault, tStack
   put the defaultStack into tDefault
   put "LegacyWordsOwn" & the milliseconds into tStack
   create invisible stack tStack
   set the defaultStack to tStack

   -- A text colour of the control's own, or of its group's, is the colour
   -- of its words, whatever is under them
   create field "Own"
   set the backgroundColor of field "Own" to "255,255,255"
   set the foregroundColor of field "Own" to "200,0,0"
   create group "Inked"
   set the backgroundColor of group "Inked" to "255,255,255"
   set the opaque of group "Inked" to true
   set the foregroundColor of group "Inked" to "0,0,200"
   create field "Inherits" in group "Inked"
   set the opaque of field "Inherits" to false

   TestAssert "a field's own text colour", \
         the effective foregroundColor of field "Own" of stack tStack is "200,0,0"
   TestAssert "a text colour its group gives it", \
         the effective foregroundColor of field "Inherits" of stack tStack is "0,0,200"

   __Done tDefault, tStack
end TestEffectiveWordsOfTheirOwn

-- The default stack as it was, and the test's stack deleted (an engine run
-- with -ui and no default stack crashed at its next use up to 0.2.8-dp.1)
private command __Done pDefault, pStack
   if pDefault is not empty and there is a stack pDefault then
      set the defaultStack to pDefault
   end if
   delete stack pStack
end __Done

-- Whether the colour pColor ("r,g,b", or black or white, the colours with
-- no theme) is light: the mean of the three 128 or more
private function __IsLight pColor
   if pColor is "black" then return false
   if pColor is "white" then return true
   if the number of items of pColor is not 3 then return empty
   return (item 1 of pColor + item 2 of pColor + item 3 of pColor) / 3 >= 128
end __IsLight
