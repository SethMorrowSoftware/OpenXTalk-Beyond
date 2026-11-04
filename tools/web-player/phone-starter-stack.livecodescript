script "Phone Starter"
-- Phone Starter: a stack made for phones, with the Mobile Web library.
-- Built by tools/web-player/phone-starter.livecodescript in OXT-Beyond's
-- repository; to make your own, save a copy of it and change it.
--
-- One line makes it a phone stack: mwStart, in preOpenStack. The stack is
-- resizable, so in a phone's browser it fills the screen, and fills it
-- again when the phone turns; each time it gets resizeStack, and psLayout
-- puts every control in its place for the new size (portrait or
-- landscape, out of the notch). The gestures come as messages, to the
-- control under the finger, as mouse messages do: the "Play" group on the
-- Gestures card handles its own, and a swipe anywhere else comes up to
-- this script's "on swipe", which changes tab.

constant kTabs = "Home,List,Form,Gestures"
constant kAccent = "#4F46E5"
constant kQuiet = "#6B6F86"

-- whether the Mobile Web library is there, how far the form is moved up
-- for the keyboard, and the dot's size (and its size when a pinch began)
local sLibrary, sFormShift, sDotSize, sPinchFrom

on preOpenStack
   put 0 into sFormShift
   put 120 into sDotSize
   -- the library is in OXT-Beyond 0.2.7 and later; without it, the stack
   -- is a phone-sized window, without the gestures
   put true into sLibrary
   try
      mwStart the short name of me
   catch tError
      put false into sLibrary
   end try
   psLayout
end preOpenStack

on closeStack
   if sLibrary then mwStop
end closeStack

on resizeStack
   psLayout
   pass resizeStack
end resizeStack

on preOpenCard
   psLayout
   pass preOpenCard
end preOpenCard

-- The part of the screen under a notch, a rounded corner or the home bar:
-- the library's safe-area insets, 0 without it
private function psInset pSide
   local tView
   if not sLibrary then return 0
   put mwViewport() into tView
   return max(0, tView[pSide])
end psInset

-- Every control in its place, for the stack's size: a header and a tab
-- bar (lower in landscape, where height is short), and the card's own
-- controls between them, kept out of the notch at either side
command psLayout
   local tW, tH, tLeft, tRight, tTop, tBottom, tTabH, tHeadH, tTabW, tName, i, tContent, tCompact
   lock screen
   put the width of me into tW
   put the height of me into tH
   put tH < 500 into tCompact
   put psInset("left") into tLeft
   put tW - psInset("right") into tRight
   if tCompact then
      put 44 into tHeadH
      put 48 into tTabH
   else
      put 56 into tHeadH
      put 60 into tTabH
   end if
   put tHeadH + psInset("top") into tTop
   put tH - tTabH - psInset("bottom") into tBottom
   set the rect of graphic "Header Back" to 0, 0, tW, tTop
   set the rect of field "Title" to tLeft + 16, tTop - tHeadH + 8, tRight - 16, tTop - 8
   set the text of field "Title" to the short name of this card
   set the rect of graphic "Tabs Back" to 0, tBottom, tW, tH
   set the points of graphic "Tabs Line" to 0, tBottom & return & tW, tBottom
   put (tRight - tLeft) / the number of items of kTabs into tTabW
   put 0 into i
   repeat for each item tName in kTabs
      set the rect of button ("Tab" && tName) to tLeft + round(i * tTabW), tBottom + 1, \
            tLeft + round((i + 1) * tTabW), tBottom + tTabH
      if tName is the short name of this card then
         set the textColor of button ("Tab" && tName) to kAccent
      else
         set the textColor of button ("Tab" && tName) to kQuiet
      end if
      add 1 to i
   end repeat
   put tLeft, tTop, tRight, tBottom into tContent
   switch the short name of this card
      case "Home"
         psLayoutHome tContent
         break
      case "List"
         psLayoutList tContent
         break
      case "Form"
         psLayoutForm tContent
         break
      case "Gestures"
         psLayoutGestures tContent
         break
   end switch
   unlock screen
end psLayout

-- Whether the content is wide enough for two columns (a phone on its
-- side, a tablet)
private function psTwoColumns pRect
   return item 3 of pRect - item 1 of pRect >= 560
end psTwoColumns

-- The welcome text, then the button and what the screen is; side by side
-- when there is room. The text scrolls with a finger if it is cut off
private command psLayoutHome pRect
   local tL, tT, tR, tB, tMid
   put item 1 of pRect + 20 into tL
   put item 2 of pRect + 16 into tT
   put item 3 of pRect - 20 into tR
   put item 4 of pRect - 12 into tB
   psShowScreen
   if psTwoColumns(pRect) then
      put round((tL + tR) / 2) into tMid
      set the width of field "Welcome" to tMid - 10 - tL
      set the rect of field "Welcome" to tL, tT, tMid - 10, \
            min(tB, tT + the formattedHeight of field "Welcome")
      set the rect of button "Buzz" to tMid + 10, tT, tR, tT + 52
      set the rect of field "Screen" to tMid + 10, tT + 68, tR, min(tB, tT + 172)
   else
      set the width of field "Welcome" to tR - tL
      set the rect of field "Welcome" to tL, tT, tR, \
            min(tB - 52 - 16 - 60, tT + the formattedHeight of field "Welcome")
      set the rect of button "Buzz" to tL, the bottom of field "Welcome" + 16, tR, the bottom of field "Welcome" + 68
      set the rect of field "Screen" to tL, the bottom of button "Buzz" + 12, tR, \
            min(tB, the bottom of button "Buzz" + 116)
   end if
   set the vScroll of field "Welcome" to 0
end psLayoutHome

private command psShowScreen
   local tView, tText
   if there is not a field "Screen" then exit psShowScreen
   if sLibrary then
      put mwViewport() into tView
      put "Screen:" && tView["width"] && "by" && tView["height"] & comma && tView["orientation"] into tText
      if tView["keyboard"] > 0 then put return & "Keyboard:" && tView["keyboard"] && "pixels" after tText
      put return & "Touch screen:" && mwIsTouchScreen() after tText
      put return & "In a browser:" && mwIsWeb() after tText
   else
      put "Without the Mobile Web library (OXT-Beyond 0.2.7 or later has it)." into tText
   end if
   set the text of field "Screen" to tText
end psShowScreen

private command psLayoutList pRect
   set the rect of field "Picked" to item 1 of pRect + 16, item 2 of pRect + 8, item 3 of pRect - 16, item 2 of pRect + 40
   set the rect of field "Items" to item 1 of pRect, item 2 of pRect + 48, item 3 of pRect, item 4 of pRect
end psLayoutList

-- Name and Email, then Notes and Save; Notes and Save in a second column
-- when there is room. Moved up by sFormShift while the keyboard is up
private command psLayoutForm pRect
   local tL, tR, tY, tName, tMid, tNotesH, tColL, tColR
   put item 1 of pRect + 20 into tL
   put item 3 of pRect - 20 into tR
   put item 2 of pRect + 16 - sFormShift into tY
   put tL into tColL
   put tR into tColR
   if psTwoColumns(pRect) then
      put round((tL + tR) / 2) into tMid
      put tMid - 10 into tColR
   end if
   repeat for each item tName in "Name,Email,Notes"
      if tName is "Notes" and psTwoColumns(pRect) then
         put tMid + 10 into tColL
         put tR into tColR
         put item 2 of pRect + 16 - sFormShift into tY
      end if
      set the rect of field (tName && "Label") to tColL, tY, tColR, tY + 24
      if tName is "Notes" then
         -- as tall as there is room for, from 72 to 120
         put max(72, min(120, item 4 of pRect - sFormShift - (tY + 26) - 12 - 52 - 40)) into tNotesH
         set the rect of field tName to tColL, tY + 26, tColR, tY + 26 + tNotesH
      else
         set the rect of field tName to tColL, tY + 26, tColR, tY + 74
      end if
      put the bottom of field tName + 12 into tY
   end repeat
   set the rect of button "Save" to tColL, tY + 4, tColR, tY + 56
   set the rect of field "Saved" to tColL, tY + 62, tColR, tY + 92
end psLayoutForm

-- What was said above, and the play area (the pad, with the dot on it)
-- below
private command psLayoutGestures pRect
   local tL, tR, tT, tB
   put item 1 of pRect + 20 into tL
   put item 3 of pRect - 20 into tR
   put item 2 of pRect into tT
   put item 4 of pRect into tB
   set the rect of field "Said" to tL, tT + 8, tR, tT + 56
   set the rect of group "Play" to tL, tT + 60, tR, tB - 16
   set the rect of graphic "Pad" to the rect of group "Play"
   put min(sDotSize, min(the width of graphic "Pad", the height of graphic "Pad") - 20) into sDotSize
   set the width of graphic "Dot" to sDotSize
   set the height of graphic "Dot" to sDotSize
   set the loc of graphic "Dot" to the loc of graphic "Pad"
end psLayoutGestures

command psGoTab pName
   if pName is the short name of this card then exit psGoTab
   if itemOffset(pName, kTabs) > itemOffset(the short name of this card, kTabs) then
      lock screen for visual effect
      go card pName
      unlock screen with visual effect push left very fast
   else
      lock screen for visual effect
      go card pName
      unlock screen with visual effect push right very fast
   end if
end psGoTab

command psBuzz
   if sLibrary then
      mwVibrate 40
      if the result is not true then
         answer "This phone or browser cannot buzz (iPhones and desktops cannot)."
      end if
   end if
end psBuzz

-- The list: a drag scrolls it, a tap picks a line
command psListDown pField
   if sLibrary then
      mwDragScroll pField
   end if
end psListDown

-- (the engine can send the mouseUp while mwDragScroll still waits for the
-- finger to let go, so ask mwDragMoved here, not mwDragScroll's result)
command psListUp pField
   local tLine
   if sLibrary then
      if mwDragMoved() then exit psListUp
   end if
   put word 2 of the clickLine into tLine
   if tLine is not a number then exit psListUp
   set the text of field "Picked" to "You picked" && line tLine of the text of pField & "."
end psListUp

command psSave
   focus on nothing
   if field "Name" is empty then
      set the text of field "Saved" to "Type a name first."
   else
      set the text of field "Saved" to "Saved, thank you" && field "Name" & "."
   end if
end psSave

-- A field that is cut off (the welcome text in a small window) scrolls
-- with a finger
on mouseDown
   if sLibrary and the short name of the target is "Welcome" then
      mwDragScroll the long id of the target
   end if
   pass mouseDown
end mouseDown

-- The library's messages ----------------------------------------------

-- A swipe that no control took: left and right change tab
on swipe pDirection
   local tIndex
   put itemOffset(the short name of this card, kTabs) into tIndex
   if pDirection is "left" and tIndex < the number of items of kTabs then
      psGoTab item tIndex + 1 of kTabs
   else if pDirection is "right" and tIndex > 1 then
      psGoTab item tIndex - 1 of kTabs
   end if
end swipe

-- The keyboard came up (or changed its height), or went away: on the Form
-- card, the form moves up so that the field being typed in stays above
-- it
on keyboardActivated
   psKeepAboveKeyboard
end keyboardActivated

on keyboardDeactivated
   psKeepAboveKeyboard
end keyboardDeactivated

-- Another field focused while the keyboard stays up (its height the
-- same, so no keyboardActivated): that field too must be above it
on openField
   local tView
   if sLibrary and the short name of this card is "Form" then
      put mwViewport() into tView
      if tView["keyboard"] > 0 then psKeepAboveKeyboard
   end if
   pass openField
end openField

private command psKeepAboveKeyboard
   local tFocus, tLimit, tWas, tKeyboard
   put mwViewport() into tKeyboard
   put tKeyboard["keyboard"] into tKeyboard
   -- where the field would be without the shift, against the top of the
   -- keyboard
   put sFormShift into tWas
   put 0 into sFormShift
   if tKeyboard > 0 and the short name of this card is "Form" then
      put the focusedObject into tFocus
      put the height of me - tKeyboard - 12 into tLimit
      if word 1 of tFocus is "field" and the bottom of tFocus + tWas > tLimit then
         put the bottom of tFocus + tWas - tLimit into sFormShift
      end if
   end if
   psLayout
end psKeepAboveKeyboard

-- The "Play" group's gestures (its script sends them here): it keeps its
-- swipes, so they do not change tab
command psPlaySwipe pDirection
   set the text of field "Said" to "A swipe" && pDirection & "."
end psPlaySwipe

command psPlayPinchStart
   put sDotSize into sPinchFrom
end psPlayPinchStart

command psPlayPinch pScale
   if sPinchFrom is not a number then exit psPlayPinch
   put max(40, min(min(the width of graphic "Pad", the height of graphic "Pad") - 20, round(sPinchFrom * pScale))) into sDotSize
   set the width of graphic "Dot" to sDotSize
   set the height of graphic "Dot" to sDotSize
   set the text of field "Said" to "A pinch:" && round(pScale * 100) & "%"
end psPlayPinch

command psPlayPinchEnd
   put empty into sPinchFrom
end psPlayPinchEnd

command psPlayLongPress pX, pY
   set the loc of graphic "Dot" to pX, pY
   set the text of field "Said" to "A long press at" && pX & comma & pY & "."
   mwVibrate 20
end psPlayLongPress
