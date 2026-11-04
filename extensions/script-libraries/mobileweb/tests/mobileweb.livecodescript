script "TestMobileWebLibrary"
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

-- The Mobile Web library on a desktop engine: what each handler answers
-- off the web, that a stack gets the library's messages only after
-- mwStart and only those it asked for, and that it changes nothing for a
-- stack that does not start it. What it does in a phone's browser,
-- tools/ci/mobile_web_check.py checks in the web engine.

local sLib

on TestSetup
   put TestGetEngineRepositoryPath() & "/extensions/script-libraries/mobileweb/mobileweb.livecodescript" into sLib
   start using stack sLib
   create stack "MobileWebTest"
   set the rect of stack "MobileWebTest" to 100, 100, 500, 400
   -- the card writes down each of the library's messages that it gets
   -- (a ~ stands for a quote)
   local tScript
   put "global gGot" & return & \
         "on swipe p" & return & "   put ~swipe ~ & p & return after gGot" & return & "end swipe" & return & \
         "on pinchStart pX, pY" & return & "   put ~pinchstart ~ & pX & comma & pY & return after gGot" & return & "end pinchStart" & return & \
         "on pinch pS, pX, pY" & return & "   put ~pinch ~ & pS & comma & pX & comma & pY & return after gGot" & return & "end pinch" & return & \
         "on pinchEnd pS" & return & "   put ~pinchend ~ & pS & return after gGot" & return & "end pinchEnd" & return & \
         "on longPress pX, pY" & return & "   put ~longpress ~ & pX & comma & pY & return after gGot" & return & "end longPress" & return & \
         "on orientationChanged" & return & "   put ~orientation~ & return after gGot" & return & "end orientationChanged" & return & \
         "on keyboardActivated" & return & "   put ~keyboard up~ & return after gGot" & return & "end keyboardActivated" & return & \
         "on keyboardDeactivated" & return & "   put ~keyboard down~ & return after gGot" & return & "end keyboardDeactivated" into tScript
   replace "~" with quote in tScript
   set the script of card 1 of stack "MobileWebTest" to tScript
   -- a button that takes swipes and passes pinches on to the card, as a
   -- mouse message is passed
   put "global gGot" & return & \
         "on swipe p" & return & "   put ~button swipe ~ & p & return after gGot" & return & "end swipe" & return & \
         "on pinchStart pX, pY" & return & "   put ~button pinchstart~ & return after gGot" & return & "   pass pinchStart" & return & "end pinchStart" & return & \
         "on pinchEnd pS" & return & "   put ~button pinchend~ & return after gGot" & return & "   pass pinchEnd" & return & "end pinchEnd" into tScript
   replace "~" with quote in tScript
   create button "Pad" in card 1 of stack "MobileWebTest"
   set the rect of button "Pad" of card 1 of stack "MobileWebTest" to 250, 150, 350, 250
   set the script of button "Pad" of card 1 of stack "MobileWebTest" to tScript
   create field "Long" in card 1 of stack "MobileWebTest"
   set the rect of field "Long" of card 1 of stack "MobileWebTest" to 10, 10, 200, 100
   repeat with i = 1 to 50
      put "Line" && i & return after field "Long" of card 1 of stack "MobileWebTest"
   end repeat
end TestSetup

on TestTearDown
   send "mwStop" to stack sLib
   if there is a stack "MobileWebTest" then
      delete stack "MobileWebTest"
   end if
   stop using stack sLib
end TestTearDown

private function _Got
   global gGot
   return gGot
end _Got

private command _ClearGot
   global gGot
   put empty into gGot
end _ClearGot

private command _FromBrowser pKind, p1, p2, p3
   dispatch "mwFromBrowser" to stack sLib with pKind, p1, p2, p3
end _FromBrowser

on TestOffTheWeb
   TestAssert "not the web on a desktop", mwIsWeb() is false
   TestAssert "no touch screen on a desktop", mwIsTouchScreen() is false
   TestAssert "not installed on a desktop", mwIsInstalled() is false
   TestAssert "no long press on a desktop", mwLongPressed() is false
   TestAssert "no drag before mwDragScroll", mwDragMoved() is false
   mwVibrate 30
   TestAssert "no buzz on a desktop", the result is false
end TestOffTheWeb

on TestViewportOffTheWeb
   local tView, tRect
   put mwViewport() into tView
   put the screenRect into tRect
   TestAssert "the viewport has its eight keys", \
         the number of lines of the keys of tView is 8
   TestAssert "width of the screen", tView["width"] is item 3 of tRect - item 1 of tRect
   TestAssert "height of the screen", tView["height"] is item 4 of tRect - item 2 of tRect
   TestAssert "no keyboard", tView["keyboard"] is 0
   TestAssert "no insets", tView["top"] is 0 and tView["right"] is 0 and \
         tView["bottom"] is 0 and tView["left"] is 0
   TestAssert "an orientation", tView["orientation"] is among the items of "portrait,landscape"
end TestViewportOffTheWeb

on TestStartChecksItsParameters
   local tScreen
   mwStart "No Such Stack Here"
   TestAssert "an unknown stack is refused", the result begins with "no such stack"
   mwStart "MobileWebTest", "swipe,twirl"
   TestAssert "an unknown gesture is refused", the result is "unknown gesture: twirl"
   mwStart "MobileWebTest", "swipe, pinch"
   TestAssert "known gestures are taken", the result is empty
   mwStart "MobileWebTest"
   TestAssert "no gestures named means all", the result is empty
   mwStart "MobileWebTest", "none"
   TestAssert "none is taken", the result is empty
   mwStart "MobileWebTest", empty, "stretch"
   TestAssert "an unknown screen is refused", the result is "unknown screen: stretch"
   repeat for each item tScreen in "fill,fit,none"
      mwStart "MobileWebTest", empty, tScreen
      TestAssert "the screen" && tScreen && "is taken", the result is empty
   end repeat
   TestAssert "the stack keeps its rect on a desktop", the rect of stack "MobileWebTest" is "100,100,500,400"
end TestStartChecksItsParameters

on TestFillAndFitChangeNothingOffTheWeb
   local tRect
   put the rect of stack "MobileWebTest" into tRect
   mwFillScreen "MobileWebTest"
   TestAssert "fill: no error", the result is empty
   TestAssert "fill: the stack keeps its rect", the rect of stack "MobileWebTest" is tRect
   mwFitStack "MobileWebTest"
   TestAssert "fit: no error", the result is empty
   TestAssert "fit: the stack is not made fullscreen", the fullscreen of stack "MobileWebTest" is false
   TestAssert "fit: the stack keeps its rect", the rect of stack "MobileWebTest" is tRect
   mwFitStack "MobileWebTest", "stretchy"
   TestAssert "fit: an unknown mode is refused", the result is "unknown mode: stretchy"
   mwFillScreen "No Such Stack Here"
   TestAssert "fill: an unknown stack is refused", the result begins with "no such stack"
end TestFillAndFitChangeNothingOffTheWeb

on TestVibrateChecksItsDuration
   mwVibrate 0
   TestAssert "zero ms is refused", the result is false
   mwVibrate 6000
   TestAssert "over 5 s is refused", the result is false
   mwVibrate "abc"
   TestAssert "not a number is refused", the result is false
end TestVibrateChecksItsDuration

on TestNoMessagesBeforeStart
   _ClearGot
   _FromBrowser "swipe", "left"
   _FromBrowser "longpress", 10, 20
   _FromBrowser "viewport", "390,664,0,47,0,34,0,portrait"
   _FromBrowser "viewport", "664,390,300,0,47,21,47,landscape"
   TestAssert "nothing is sent before mwStart", _Got() is empty
   TestAssert "and a viewport report changes no stack", the rect of stack "MobileWebTest" is "100,100,500,400"
end TestNoMessagesBeforeStart

on TestMessagesAfterStart
   mwStart "MobileWebTest"
   _ClearGot
   _FromBrowser "swipe", "left", 380, 20
   _FromBrowser "pinchstart", 100, 120
   _FromBrowser "pinch", 1.5, 101, 122
   _FromBrowser "pinchend", 1.5
   _FromBrowser "longpress", 10, 380
   TestAssert "the card gets each gesture over no control, with its values", _Got() is \
         "swipe left" & return & \
         "pinchstart 100,120" & return & \
         "pinch 1.5,101,122" & return & \
         "pinchend 1.5" & return & \
         "longpress 10,380" & return
   _ClearGot
   _FromBrowser "twirl", 1
   TestAssert "an unknown kind sends nothing", _Got() is empty
end TestMessagesAfterStart

on TestGesturesGoToTheControlUnderTheFinger
   mwStart "MobileWebTest"
   _ClearGot
   _FromBrowser "swipe", "up", 300, 200
   TestAssert "a swipe that began on the button goes to the button, which keeps it", \
         _Got() is "button swipe up" & return
   _ClearGot
   _FromBrowser "pinchstart", 300, 200
   _FromBrowser "pinch", 2, 360, 300
   _FromBrowser "pinchend", 2
   TestAssert "a pinch that began over the button goes to it, and on to the card when it passes", \
         _Got() is "button pinchstart" & return & "pinchstart 300,200" & return & \
         "pinch 2,360,300" & return & "button pinchend" & return & "pinchend 2" & return
end TestGesturesGoToTheControlUnderTheFinger

on TestOrientationAndKeyboard
   mwStart "MobileWebTest"
   _ClearGot
   _FromBrowser "viewport", "390,664,0,47,0,34,0,portrait"
   TestAssert "the first report sends nothing", _Got() is empty
   _FromBrowser "viewport", "390,364,300,47,0,34,0,portrait"
   TestAssert "the keyboard comes up", _Got() is "keyboard up" & return
   _ClearGot
   _FromBrowser "viewport", "390,330,334,47,0,34,0,portrait"
   TestAssert "the keyboard grows", _Got() is "keyboard up" & return
   _ClearGot
   _FromBrowser "viewport", "390,664,0,47,0,34,0,portrait"
   TestAssert "the keyboard goes away", _Got() is "keyboard down" & return
   _ClearGot
   _FromBrowser "viewport", "664,390,0,0,47,21,47,landscape"
   TestAssert "the phone turns", _Got() is "orientation" & return
   _ClearGot
   _FromBrowser "viewport", "664,390,0,0,47,21,47,landscape"
   TestAssert "the same again sends nothing", _Got() is empty
end TestOrientationAndKeyboard

on TestNoMessagesAfterStop
   mwStart "MobileWebTest"
   mwStop
   _ClearGot
   _FromBrowser "swipe", "left"
   TestAssert "nothing is sent after mwStop", _Got() is empty
end TestNoMessagesAfterStop

on TestNoMessagesWhenTheStackHasGone
   mwStart "MobileWebTest"
   delete stack "MobileWebTest"
   _FromBrowser "swipe", "left"
   TestAssert "a message for a stack that has gone is dropped", _Got() is empty
end TestNoMessagesWhenTheStackHasGone

on TestDragScroll
   local tField
   put the long id of field "Long" of card 1 of stack "MobileWebTest" into tField
   set the vScroll of tField to 30
   mwDragScroll tField
   TestAssert "no error", the result is empty
   TestAssert "a press that does not move scrolls nothing", the vScroll of tField is 30
   TestAssert "and is not a drag that moved", mwDragMoved() is false
   mwDragScroll "field" && quote & "Nowhere" & quote && "of stack" && quote & "MobileWebTest" & quote
   TestAssert "an object that is not there is refused", the result begins with "no such object"
end TestDragScroll
