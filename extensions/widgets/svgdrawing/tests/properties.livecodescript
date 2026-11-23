script "SvgDrawingWidgetProperties"
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

-- The SVG Drawing widget (org.openxtalk.widget.svgdrawing): it shows a
-- whole SVG, each shape in its own colours, from SVG text (compiled by the
-- drawing library) or from a drawing compiled already; it keeps its
-- proportions or stretches, gives currentColor its foregroundColor, and a
-- saved stack shows its picture without the drawing library.
--
-- The pictures are checked by their pixels: the widget's snapshot, read
-- back through an image's imageData (4 bytes a pixel: alpha, red, green,
-- blue).

local sLib

on TestSetup
   TestLoadExternal "revxml"
   put TestGetEngineRepositoryPath() & "/extensions/script-libraries/drawing/drawing.livecodescript" into sLib
   start using stack sLib
   -- the library loads its SVG specification when the IDE initializes it
   -- as an extension, which a test does not
   send "extensionInitialize" to stack sLib

   TestLoadExtension "org.openxtalk.widget.svgdrawing"

   create stack "SvgDrawingTest"
   set the defaultStack to "SvgDrawingTest"
   set the rect of stack "SvgDrawingTest" to 100,100,400,300
   create widget "Drawing" as "org.openxtalk.widget.svgdrawing"
   set the rect of widget "Drawing" to 0,0,100,100
end TestSetup

on TestTeardown
   if there is a stack "SvgDrawingTest" then
      delete stack "SvgDrawingTest"
   end if
end TestTeardown

----------

-- The test runner sends TestSetup and each test separately, and the
-- defaultStack TestSetup set does not last into the test
private command _UseTestStack
   set the defaultStack to "SvgDrawingTest"
end _UseTestStack

-- A 100 by 100 SVG: the left half red; on the right a blue circle with a
-- green stroke
private function _ThreeColourSvg
   return _Svg("<rect x='0' y='0' width='50' height='100' fill='#ff0000'/>" & \
         "<circle cx='75' cy='50' r='20' fill='#0000ff' stroke='#00ff00' stroke-width='6'/>")
end _ThreeColourSvg

private function _Svg pBody
   local tSvg
   put "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='0 0 100 100'>" & \
         pBody & "</svg>" into tSvg
   replace "'" with quote in tSvg
   return tSvg
end _Svg

private function _Compile pSvg
   local tDrawing
   put drawingSvgCompile(pSvg, "all") into tDrawing
   TestAssert "the test's SVG compiles", the result is empty
   return tDrawing
end _Compile

-- "a,r,g,b" of the pixel at pX,pY of the widget's snapshot
private function _Pixel pX, pY
   local tSnapshot, tData, tOffset
   _UseTestStack
   export snapshot from widget "Drawing" to tSnapshot as PNG
   if there is an image "SvgDrawingPixels" then
      delete image "SvgDrawingPixels"
   end if
   create invisible image "SvgDrawingPixels"
   set the text of image "SvgDrawingPixels" to tSnapshot
   put the imageData of image "SvgDrawingPixels" into tData
   put (pY * the width of image "SvgDrawingPixels" + pX) * 4 into tOffset
   return byteToNum(byte tOffset + 1 of tData) & comma & \
         byteToNum(byte tOffset + 2 of tData) & comma & \
         byteToNum(byte tOffset + 3 of tData) & comma & \
         byteToNum(byte tOffset + 4 of tData)
end _Pixel

-- "r,g,b" of the pixel
private function _Colour pX, pY
   return item 2 to 4 of _Pixel(pX, pY)
end _Colour

-- True if nothing is drawn at the pixel
private function _Clear pX, pY
   return item 1 of _Pixel(pX, pY) is 0
end _Clear

----------

on TestDefaults
   _UseTestStack
   TestAssert "a new widget has no SVG text", the svgText of widget "Drawing" is empty
   TestAssert "a new widget has no drawing", the drawing of widget "Drawing" is empty
   TestAssert "a new widget keeps proportions", the maintainAspectRatio of widget "Drawing" is true
   TestAssert "a new widget's formattedWidth is 0", the formattedWidth of widget "Drawing" is 0
   TestAssert "a new widget's formattedHeight is 0", the formattedHeight of widget "Drawing" is 0
   TestAssert "a new widget draws nothing", _Clear(50, 50)
end TestDefaults

on TestDrawingShowsEveryColour
   _UseTestStack
   set the drawing of widget "Drawing" to _Compile(_ThreeColourSvg())
   TestAssert "the rect is red", _Colour(10, 50) is "255,0,0"
   TestAssert "the circle is blue", _Colour(75, 50) is "0,0,255"
   TestAssert "the circle's stroke is green", _Colour(75, 31) is "0,255,0"
   TestAssert "outside the shapes nothing is drawn", _Clear(95, 95)
end TestDrawingShowsEveryColour

on TestSvgTextCompiles
   _UseTestStack
   local tSvg
   put _ThreeColourSvg() into tSvg
   set the svgText of widget "Drawing" to tSvg
   TestAssert "the svgText is the text set", the svgText of widget "Drawing" is tSvg
   TestAssert "the drawing is the compiled SVG", \
         the drawing of widget "Drawing" is _Compile(tSvg)
   TestAssert "the rect is red", _Colour(10, 50) is "255,0,0"
   TestAssert "the circle is blue", _Colour(75, 50) is "0,0,255"
end TestSvgTextCompiles

on _TestSetSvgText pText
   _UseTestStack
   set the svgText of widget "Drawing" to pText
end _TestSetSvgText

on TestSvgTextThatDoesNotCompile
   _UseTestStack
   set the svgText of widget "Drawing" to _ThreeColourSvg()
   TestAssertThrow "an SVG that does not compile throws", "_TestSetSvgText", \
         the long id of me, "EE_EXTENSION_ERROR_DOMAIN", "<html><body/></html>"
   TestAssert "the widget keeps its SVG text", the svgText of widget "Drawing" is _ThreeColourSvg()
   TestAssert "the widget keeps its picture", _Colour(10, 50) is "255,0,0"
end TestSvgTextThatDoesNotCompile

on _TestSetDrawing pValue
   _UseTestStack
   set the drawing of widget "Drawing" to pValue
end _TestSetDrawing

on TestDrawingThatIsNotOne
   _UseTestStack
   TestAssertThrow "text that is not a drawing throws", "_TestSetDrawing", \
         the long id of me, "EE_EXTENSION_ERROR_DOMAIN", "not a drawing"
   TestAssertThrow "PNG data throws", "_TestSetDrawing", \
         the long id of me, "EE_EXTENSION_ERROR_DOMAIN", \
         numToByte(137) & "PNG" & numToByte(13) & numToByte(10) & numToByte(26) & numToByte(10)
   TestAssertThrow "a drawing's first bytes alone throw", "_TestSetDrawing", \
         the long id of me, "EE_EXTENSION_ERROR_DOMAIN", "LCD" & numToByte(0)
end TestDrawingThatIsNotOne

on TestEmptyClears
   _UseTestStack
   set the svgText of widget "Drawing" to _ThreeColourSvg()
   set the svgText of widget "Drawing" to empty
   TestAssert "empty svgText clears the drawing", the drawing of widget "Drawing" is empty
   TestAssert "empty svgText clears the picture", _Clear(10, 50)

   set the drawing of widget "Drawing" to _Compile(_ThreeColourSvg())
   set the drawing of widget "Drawing" to empty
   TestAssert "empty drawing clears the picture", _Clear(10, 50)
   TestAssert "empty drawing gives formattedWidth 0", the formattedWidth of widget "Drawing" is 0
end TestEmptyClears

on TestSettingDrawingClearsSvgText
   _UseTestStack
   set the svgText of widget "Drawing" to _ThreeColourSvg()
   set the drawing of widget "Drawing" to _Compile(_Svg("<rect width='100' height='100' fill='#0000ff'/>"))
   TestAssert "setting the drawing empties the svgText", the svgText of widget "Drawing" is empty
   TestAssert "the new drawing is shown", _Colour(10, 50) is "0,0,255"
end TestSettingDrawingClearsSvgText

on TestFormattedSize
   _UseTestStack
   set the drawing of widget "Drawing" to _Compile(_ThreeColourSvg())
   TestAssert "formattedWidth is the SVG's width", the formattedWidth of widget "Drawing" is 100
   TestAssert "formattedHeight is the SVG's height", the formattedHeight of widget "Drawing" is 100
end TestFormattedSize

on TestMaintainAspectRatio
   _UseTestStack
   set the drawing of widget "Drawing" to _Compile(_ThreeColourSvg())
   set the rect of widget "Drawing" to 0,0,200,100

   -- kept: the 100 by 100 picture is centred, from x 50 to 150
   TestAssert "kept: nothing left of the picture", _Clear(10, 50)
   TestAssert "kept: the rect starts at x 50", _Colour(60, 50) is "255,0,0"
   TestAssert "kept: the rect reaches x 100", _Colour(95, 50) is "255,0,0"
   TestAssert "kept: the circle is drawn at its own size, centred at x 125", _Colour(125, 50) is "0,0,255"
   TestAssert "kept: nothing right of the picture", _Clear(190, 50)

   -- kept in a tall widget: the picture is centred from y 50 to 150
   set the rect of widget "Drawing" to 0,0,100,200
   TestAssert "kept, tall: nothing above the picture", _Clear(25, 25)
   TestAssert "kept, tall: the rect reaches y 145", _Colour(25, 145) is "255,0,0"
   TestAssert "kept, tall: nothing below the picture", _Clear(25, 175)
   set the rect of widget "Drawing" to 0,0,200,100

   -- stretched: the rect is the widget's left half
   set the maintainAspectRatio of widget "Drawing" to false
   TestAssert "the property is false", the maintainAspectRatio of widget "Drawing" is false
   TestAssert "stretched: the rect reaches the left edge", _Colour(10, 50) is "255,0,0"
   TestAssert "stretched: the rect fills the left half", _Colour(90, 50) is "255,0,0"
   TestAssert "stretched: the circle is in the right half", _Colour(150, 50) is "0,0,255"
end TestMaintainAspectRatio

on TestCurrentColor
   _UseTestStack
   set the drawing of widget "Drawing" to \
         _Compile(_Svg("<rect width='50' height='100' fill='currentColor'/>" & \
         "<rect x='50' width='50' height='100' fill='#ff0000'/>"))
   set the foregroundColor of widget "Drawing" to 0,128,0
   TestAssert "currentColor is the foregroundColor", _Colour(10, 50) is "0,128,0"
   TestAssert "a colour of its own is kept", _Colour(90, 50) is "255,0,0"

   set the foregroundColor of widget "Drawing" to 0,0,255
   TestAssert "currentColor follows the foregroundColor", _Colour(10, 50) is "0,0,255"
end TestCurrentColor

on TestSavedStackShowsWithoutTheLibrary
   _UseTestStack
   local tFile, tSvg
   put _ThreeColourSvg() into tSvg
   set the svgText of widget "Drawing" to tSvg
   set the maintainAspectRatio of widget "Drawing" to false
   put specialFolderPath("temporary") & "/svgdrawing-test-" & the milliseconds & ".oxtstack" into tFile
   save stack "SvgDrawingTest" as tFile
   delete stack "SvgDrawingTest"

   -- Take the drawing library away: a saved widget must not need it
   remove the script of stack sLib from back
   stop using stack sLib
   delete stack sLib

   go invisible stack tFile
   set the defaultStack to "SvgDrawingTest"
   TestAssert "the saved svgText comes back", the svgText of widget "Drawing" is tSvg
   TestAssert "the saved maintainAspectRatio comes back", \
         the maintainAspectRatio of widget "Drawing" is false
   TestAssert "the saved picture is drawn: red", _Colour(10, 50) is "255,0,0"
   TestAssert "the saved picture is drawn: blue", _Colour(75, 50) is "0,0,255"
   TestAssertThrow "without the library, setting svgText throws", "_TestSetSvgText", \
         the long id of me, "EE_EXTENSION_ERROR_DOMAIN", tSvg
   TestAssert "and the picture is kept", _Colour(10, 50) is "255,0,0"

   delete file tFile
end TestSavedStackShowsWithoutTheLibrary
