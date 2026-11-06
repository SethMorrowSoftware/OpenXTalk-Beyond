script "TestPhoneStarterGestures"
-- OXT-Beyond: the Phone Starter's Gestures card (the committed
-- tools/web-player/stacks/Phone Starter.oxtstack, built by
-- tools/web-player/phone-starter.livecodescript), on a desktop engine.
-- The Mobile Web library sends the pad pinchStart pX, pY, then pinch
-- pScale, pX, pY as the fingers move, then pinchEnd; here the test sends
-- them to the dot, as the library does, and they come up to the "Play"
-- group's script, as on a phone.
--
-- A pinch once walked the dot up and to the left until it left the pad
-- (0.2.7-rc.6.16): the dot was sized by setting its width and height,
-- which keep its centre only to the nearest pixel, the odd half always up
-- and to the left, once for every move of the fingers. The dot now keeps
-- its centre through any number of sizes, follows the point between the
-- fingers when they move together, and stays on the pad.
-- tools/ci/mobile_web_check.py does the same with real touches in a
-- phone's browser.

constant kStack = "Phone Starter"

on TestSetup
   local tFile
   put TestGetEngineRepositoryPath() & "/tools/web-player/stacks/Phone Starter.oxtstack" into tFile
   go stack tFile
   go card "Gestures" of stack kStack
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
end TestTeardown

private function dotLoc
   return the loc of graphic "Dot" of card "Gestures" of stack kStack
end dotLoc

private function dotWidth
   return the width of graphic "Dot" of card "Gestures" of stack kStack
end dotWidth

private command pinchStart pX, pY
   dispatch "pinchStart" to graphic "Dot" of card "Gestures" of stack kStack with pX, pY
end pinchStart

private command pinchTo pScale, pX, pY
   dispatch "pinch" to graphic "Dot" of card "Gestures" of stack kStack with pScale, pX, pY
end pinchTo

private command pinchEnd pScale
   dispatch "pinchEnd" to graphic "Dot" of card "Gestures" of stack kStack with pScale
end pinchEnd

-- whether the dot is wholly on the pad
private function onPad
   local tDot, tPad
   put the rect of graphic "Dot" of card "Gestures" of stack kStack into tDot
   put the rect of graphic "Pad" of card "Gestures" of stack kStack into tPad
   return item 1 of tDot >= item 1 of tPad and item 2 of tDot >= item 2 of tPad and \
         item 3 of tDot <= item 3 of tPad and item 4 of tDot <= item 4 of tPad
end onPad

on TestTheDotStartsInTheMiddleOfThePad
   TestAssert "the dot is in the middle of the pad", \
         dotLoc() is the loc of graphic "Pad" of card "Gestures" of stack kStack
   TestAssert "and on it", onPad()
end TestTheDotStartsInTheMiddleOfThePad

-- Fingers that spread and close again without moving: the size changes
-- (odd and even), the centre never does
on TestAPinchKeepsTheDotWhereItIs
   local tLoc, tX, tY, tScale, tMoved, tSizes
   put dotLoc() into tLoc
   put item 1 of tLoc into tX
   put item 2 of tLoc into tY
   put false into tMoved
   pinchStart tX, tY
   repeat for each item tScale in "1.01,1.03,1.07,1.11,1.13,1.19,1.23,1.29,1.31,1.37,1.41,1.29,1.17,1.03,0.97,0.91,0.83,0.79,0.71,0.67,0.61,0.73,0.89,1.01"
      pinchTo tScale, tX, tY
      put dotWidth() & comma after tSizes
      if dotLoc() is not tLoc then put true into tMoved
   end repeat
   pinchEnd 1.01
   TestAssert "the pinch sized the dot", the number of items of tSizes is 24 and item 11 of tSizes > 120 and item 21 of tSizes < 120
   TestAssert "and it never moved", not tMoved
   TestAssert "it is where it was", dotLoc() is tLoc
   -- many pinches, one after another (the drift was one pixel up and to
   -- the left for each odd size)
   repeat 20 times
      pinchStart tX, tY
      pinchTo 1.13, tX, tY
      pinchTo 1.27, tX, tY
      pinchEnd 1.27
      pinchStart tX, tY
      pinchTo 0.91, tX, tY
      pinchTo 0.79, tX, tY
      pinchEnd 0.79
   end repeat
   TestAssert "twenty pinches leave it where it was", dotLoc() is tLoc
   TestAssert "on the pad", onPad()
end TestAPinchKeepsTheDotWhereItIs

-- Two fingers moving together move the dot with them, by as far as the
-- point between them moved since the pinch began
on TestTwoFingersMoveTheDot
   local tLoc, tX, tY
   put dotLoc() into tLoc
   put item 1 of tLoc into tX
   put item 2 of tLoc into tY
   -- (the fingers need not be over the dot's middle)
   pinchStart tX + 10, tY - 5
   pinchTo 1, tX + 10 + 15, tY - 5 + 10
   TestAssert "the dot moves with the fingers", dotLoc() is (tX + 15) & comma & (tY + 10)
   pinchTo 1.2, tX + 10 - 25, tY - 5 + 30
   TestAssert "and keeps moving with them as they spread", dotLoc() is (tX - 25) & comma & (tY + 30)
   TestAssert "while it grows", dotWidth() is 144
   pinchEnd 1.2
   TestAssert "it stays where they left it", dotLoc() is (tX - 25) & comma & (tY + 30)
   -- the next pinch starts from there
   pinchStart tX, tY
   pinchTo 1, tX + 5, tY + 5
   TestAssert "the next pinch moves it from where it is", dotLoc() is (tX - 20) & comma & (tY + 35)
   pinchEnd 1
end TestTwoFingersMoveTheDot

-- However far the fingers go, the dot stays on the pad
on TestTheDotStaysOnThePad
   local tLoc, tX, tY, tPad
   put dotLoc() into tLoc
   put item 1 of tLoc into tX
   put item 2 of tLoc into tY
   put the rect of graphic "Pad" of card "Gestures" of stack kStack into tPad
   pinchStart tX, tY
   pinchTo 1, tX - 5000, tY - 5000
   TestAssert "up and to the left: on the pad", onPad()
   TestAssert "in its corner", item 1 of the rect of graphic "Dot" of card "Gestures" of stack kStack is item 1 of tPad \
         and item 2 of the rect of graphic "Dot" of card "Gestures" of stack kStack is item 2 of tPad
   pinchTo 1.5, tX + 5000, tY + 5000
   TestAssert "down and to the right, bigger: on the pad", onPad()
   pinchEnd 1.5
end TestTheDotStaysOnThePad

-- A pinch with no point between the fingers (pinch pScale alone, as a
-- script may send it) still sizes the dot round its centre
on TestAPinchWithoutAPoint
   local tLoc
   put dotLoc() into tLoc
   dispatch "pinchStart" to graphic "Dot" of card "Gestures" of stack kStack
   dispatch "pinch" to graphic "Dot" of card "Gestures" of stack kStack with 1.31
   TestAssert "the dot grows", dotWidth() is 157
   dispatch "pinch" to graphic "Dot" of card "Gestures" of stack kStack with 0.67
   TestAssert "and shrinks", dotWidth() is 80
   dispatch "pinchEnd" to graphic "Dot" of card "Gestures" of stack kStack with 0.67
   TestAssert "where it was", dotLoc() is tLoc
end TestAPinchWithoutAPoint

-- A pinch that was never begun (pinch with no pinchStart) does nothing
on TestAPinchNotBegun
   local tLoc
   put dotLoc() into tLoc
   pinchTo 2, 10, 10
   TestAssert "the dot is as it was", dotLoc() is tLoc and dotWidth() is 120
end TestAPinchNotBegun

-- When the stack is laid out again (it turns), the dot goes back to the
-- middle of the pad, at the size it had
on TestALayoutPutsTheDotInTheMiddle
   local tLoc
   put dotLoc() into tLoc
   pinchStart item 1 of tLoc, item 2 of tLoc
   pinchTo 1.1, item 1 of tLoc + 40, item 2 of tLoc + 40
   pinchEnd 1.1
   dispatch "psLayout" to stack kStack
   TestAssert "in the middle of the pad", dotLoc() is the loc of graphic "Pad" of card "Gestures" of stack kStack
   TestAssert "at its size", dotWidth() is 132
end TestALayoutPutsTheDotInTheMiddle
