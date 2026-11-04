script "Phone Starter"
-- Phone Starter: a stack made for phones, with the Mobile Web library.
-- Built by tools/web-player/phone-starter.livecodescript in OXT-Beyond's
-- repository; to make your own, save a copy of it and change it.
--
-- Every control is placed by psLayout, from the size of the stack: change
-- the stack's size (a phone that turns, a window that is resized) and it
-- lays itself out again.

constant kTabs = "Home,List,Form,Gestures"
constant kAccent = "#4F46E5"
constant kQuiet = "#6B6F86"

-- whether the Mobile Web library is there, and how far the form is moved
-- up for the keyboard
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
   if sLibrary then
      mwFillScreen the short name of me
   end if
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

-- The part of the screen under a notch or the home bar: the library's
-- safe-area insets, 0 without it
private function psInset pSide
   local tView
   if not sLibrary then return 0
   put mwViewport() into tView
   return max(0, tView[pSide])
end psInset

-- Every control in its place, for the stack's size
command psLayout
   local tW, tH, tTop, tBottom, tTabH, tX, tTabW, tName, i, tContent
   lock screen
   put the width of me into tW
   put the height of me into tH
   put 56 + psInset("top") into tTop
   put 60 + psInset("bottom") into tTabH
   put tH - tTabH into tBottom
   set the rect of graphic "Header Back" to 0, 0, tW, tTop
   set the rect of field "Title" to 16, tTop - 46, tW - 16, tTop - 10
   set the text of field "Title" to the short name of this card
   set the rect of graphic "Tabs Back" to 0, tBottom, tW, tH
   set the points of graphic "Tabs Line" to 0, tBottom & return & tW, tBottom
   put tW / the number of items of kTabs into tTabW
   put 0 into i
   repeat for each item tName in kTabs
      set the rect of button ("Tab" && tName) to round(i * tTabW), tBottom + 1, round((i + 1) * tTabW), tBottom + 60
      if tName is the short name of this card then
         set the textColor of button ("Tab" && tName) to kAccent
      else
         set the textColor of button ("Tab" && tName) to kQuiet
      end if
      add 1 to i
   end repeat
   put 0, tTop, tW, tBottom into tContent
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

private command psLayoutHome pRect
   local tW
   put item 3 of pRect into tW
   set the width of field "Welcome" to tW - 40
   set the height of field "Welcome" to the formattedHeight of field "Welcome"
   set the topLeft of field "Welcome" to 20, item 2 of pRect + 20
   set the rect of button "Buzz" to 20, the bottom of field "Welcome" + 16, tW - 20, the bottom of field "Welcome" + 68
   psShowScreen
   set the rect of field "Screen" to 20, the bottom of button "Buzz" + 16, tW - 20, the bottom of button "Buzz" + 120
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
   set the rect of field "Picked" to 16, item 2 of pRect + 8, item 3 of pRect - 16, item 2 of pRect + 40
   set the rect of field "Items" to 0, item 2 of pRect + 48, item 3 of pRect, item 4 of pRect
end psLayoutList

private command psLayoutForm pRect
   local tY, tW, tName
   put item 2 of pRect + 20 - sFormShift into tY
   put item 3 of pRect into tW
   repeat for each item tName in "Name,Email,Notes"
      set the rect of field (tName && "Label") to 20, tY, tW - 20, tY + 24
      if tName is "Notes" then
         set the rect of field tName to 20, tY + 26, tW - 20, tY + 146
      else
         set the rect of field tName to 20, tY + 26, tW - 20, tY + 74
      end if
      put the bottom of field tName + 14 into tY
   end repeat
   set the rect of button "Save" to 20, tY + 6, tW - 20, tY + 58
   set the rect of field "Saved" to 20, tY + 66, tW - 20, tY + 96
end psLayoutForm

private command psLayoutGestures pRect
   local tW
   put item 3 of pRect into tW
   set the rect of field "Said" to 20, item 2 of pRect + 12, tW - 20, item 2 of pRect + 72
   set the rect of graphic "Pad" to 20, item 2 of pRect + 80, tW - 20, item 4 of pRect - 20
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

-- The library's messages ----------------------------------------------

-- The phone turned, or the keyboard came up or went: on the Form card,
-- the form moves up so that the field being typed in stays above the
-- keyboard
on mwViewportChanged pWidth, pHeight, pKeyboard
   local tFocus, tLimit, tWas
   -- where the field would be without the shift, against the top of the
   -- keyboard
   put sFormShift into tWas
   put 0 into sFormShift
   if pKeyboard > 0 and the short name of this card is "Form" then
      put the focusedObject into tFocus
      put the height of me - pKeyboard - 12 into tLimit
      if word 1 of tFocus is "field" and the bottom of tFocus + tWas > tLimit then
         put the bottom of tFocus + tWas - tLimit into sFormShift
      end if
   end if
   psLayout
end mwViewportChanged

on mwSwipe pDirection
   local tIndex
   if the short name of this card is "Gestures" then
      set the text of field "Said" to "A swipe" && pDirection & "."
      exit mwSwipe
   end if
   put itemOffset(the short name of this card, kTabs) into tIndex
   if pDirection is "left" and tIndex < the number of items of kTabs then
      psGoTab item tIndex + 1 of kTabs
   else if pDirection is "right" and tIndex > 1 then
      psGoTab item tIndex - 1 of kTabs
   end if
end mwSwipe

on mwPinchStart pX, pY
   put sDotSize into sPinchFrom
end mwPinchStart

on mwPinch pScale, pX, pY
   if the short name of this card is not "Gestures" then exit mwPinch
   put max(40, min(the width of graphic "Pad" - 20, round(sPinchFrom * pScale))) into sDotSize
   set the width of graphic "Dot" to sDotSize
   set the height of graphic "Dot" to sDotSize
   set the text of field "Said" to "A pinch:" && round(pScale * 100) & "%"
end mwPinch

on mwPinchEnd pScale
   put empty into sPinchFrom
end mwPinchEnd

on mwLongPress pX, pY
   if the short name of this card is not "Gestures" then exit mwLongPress
   if (pX & comma & pY) is not within the rect of graphic "Pad" then exit mwLongPress
   set the loc of graphic "Dot" to pX, pY
   set the text of field "Said" to "A long press at" && pX & comma & pY & "."
   mwVibrate 20
end mwLongPress
