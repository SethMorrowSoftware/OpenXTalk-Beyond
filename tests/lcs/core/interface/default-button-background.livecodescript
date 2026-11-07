script "CoreInterfaceDefaultButtonBackground"
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
OXT-Beyond: on macOS a default button (a standard button whose default is
true) is drawn in the accent colour with a white label while the app is
active. In the background the theme draws it as a plain button, as the
Mac does (engine/src/buttondraw.cpp, drawstandardbutton:
WTHEME_STATE_SUPPRESSDEFAULT), but its label stayed white, so after a
script launched another app every default button was blank, white on
white (Skids, openxtalk.org p=26152). Its label is white only while the
app is active now; in the background it has the label's own colour, as
any other button has.

The test puts the engine in the background by bringing the Finder to the
front (launch, as the report's script launched its app), so it acts on
the desktop of the computer it runs on: tools/ci/run_engine_tests.py
lists it among the INTRUSIVE tests, which run in CI or with
--desktop-tests. Then it takes a snapshot of a default button. Its face
says whether the app is in the background: grey (its red, green and blue
within 24 of each other) when the theme draws the button plain, the
accent colour while the app is active. The suspend message alone cannot
say it: an app that was never active gets none. When the face is still
the accent colour the test is skipped, with the reason, rather than
passed, since an active default button's white label shows whether or
not the bug is there. In the background it asks whether the label can
be seen on the face: the colour farthest from the face's within the
middle of the button, where "OK" is drawn, must differ from it by 200 or
more (red, green and blue added; a black label on a white face is 765
apart, the accent colour's white label on its blue about 390, and a
white label on a white face under 30).
*/

on TestDefaultButtonLabelInTheBackground
   local tStack, tImage, tWidth, tHeight, tFace, tFarthest, tX, tY, tLaunched, tSuspended
   TestSkipIfNot "platform", "MacOS"
   TestSkipIfNot "ui"
   TestSkipIfNot "wait"
   put "DefaultButtonBackground" & the milliseconds into tStack
   create stack tStack
   set the defaultStack to tStack
   -- the engine sends suspend to the default stack's card when the app
   -- goes into the background, and resume when it comes back
   set the script of card 1 of stack tStack to \
         "on suspend" & return & \
         "   set the cSuspended of me to true" & return & \
         "   pass suspend" & return & \
         "end suspend" & return & \
         "on resume" & return & \
         "   set the cSuspended of me to false" & return & \
         "   pass resume" & return & \
         "end resume"
   create button "OK"
   set the style of button "OK" to "standard"
   set the rect of button "OK" to 20,20,120,41
   set the default of button "OK" to true
   go stack tStack
   set the defaultStack to tStack

   launch "/System/Library/CoreServices/Finder.app"
   put the result into tLaunched
   repeat 50 times
      if the cSuspended of card 1 of stack tStack is true then
         put true into tSuspended
         exit repeat
      end if
      wait 100 milliseconds with messages
   end repeat
   if tSuspended is true then
      put "the app went into the background (suspend)" into tSuspended
   else
      put "no suspend in 5 seconds (the result of launch:" && tLaunched & ")" into tSuspended
   end if
   TestDiagnostic tSuspended

   import snapshot from button "OK" of stack tStack
   put the width of the last image into tWidth
   put the height of the last image into tHeight
   put the imageData of the last image into tImage
   delete the last image
   TestAssert "the snapshot has a pixel for each point", \
         the number of bytes in tImage is 4 * tWidth * tHeight and tWidth > 0

   -- the face, left of the label, halfway down
   put __Pixel(tImage, tWidth, tWidth div 6, tHeight div 2) into tFace
   if max(item 1 of tFace, item 2 of tFace, item 3 of tFace) - \
         min(item 1 of tFace, item 2 of tFace, item 3 of tFace) > 24 then
      TestSkip "a default button's label can be seen on its face in the background", \
            "the app could not be put in the background: the default button's face is" && \
            tFace & ", the accent colour (" & tSuspended & ")"
      delete stack tStack
      exit TestDefaultButtonLabelInTheBackground
   end if
   put 0 into tFarthest
   repeat with tY = tHeight div 4 to (3 * tHeight) div 4
      repeat with tX = (35 * tWidth) div 100 to (65 * tWidth) div 100
         put max(tFarthest, __Apart(__Pixel(tImage, tWidth, tX, tY), tFace)) into tFarthest
      end repeat
   end repeat
   TestDiagnostic "the systemAppearance" && the systemAppearance & ": the face" && tFace & \
         ", the label's colour farthest from it" && tFarthest & " apart"
   TestAssert "a default button's label can be seen on its face in the background", tFarthest >= 200
   delete stack tStack
end TestDefaultButtonLabelInTheBackground

-- The colour ("r,g,b") of the pixel at pX, pY (from 0) of pImage, the
-- imageData of an image pWidth pixels wide: 4 bytes a pixel, the first
-- unused
private function __Pixel pImage, pWidth, pX, pY
   local tByte
   put 4 * (pY * pWidth + pX) into tByte
   return byteToNum(byte tByte + 2 of pImage) & comma & \
         byteToNum(byte tByte + 3 of pImage) & comma & \
         byteToNum(byte tByte + 4 of pImage)
end __Pixel

-- How far apart the colours pA and pB ("r,g,b") are: their red, green and
-- blue differences added
private function __Apart pA, pB
   return abs(item 1 of pA - item 1 of pB) + abs(item 2 of pA - item 2 of pB) + \
         abs(item 3 of pA - item 3 of pB)
end __Apart
