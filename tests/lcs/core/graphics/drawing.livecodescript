script "CoreGraphicsDrawing"
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

-- Drawings (an image whose text is a compiled SVG, "LCD") with a count of
-- 64 or more in their opcodes: a polygon or polyline of 32 points or more.
-- The drawing library writes a count 7 bits at a time, least significant
-- first, with 0x80 meaning more follow; up to 0.2.7-rc.6.11 the engine
-- read it most significant first with 0x40 meaning more, so a polygon of
-- 32 to 63 points drew nothing and lost every shape after it. These are
-- built byte by byte, as the library before it wrote such polygons as
-- paths still writes them, so they keep testing the engine's reader

-- A drawing 100 by 100: a red polygon of pPoints points (a circle of
-- radius 40 about the centre), then a blue 10 by 10 square at 0,0
private function _Drawing pPoints
   local tScalars, tOpcodes, tIndex, tCount
   -- red
   put binaryEncode("ffff", 1, 0, 0, 1) into tScalars
   repeat with tIndex = 0 to pPoints - 1
      put binaryEncode("ff", 50 + 40 * cos(2 * pi * tIndex / pPoints), \
            50 + 40 * sin(2 * pi * tIndex / pPoints)) after tScalars
   end repeat
   -- blue, and the square
   put binaryEncode("ffff", 0, 0, 1, 1) after tScalars
   put binaryEncode("ffff", 0, 0, 10, 10) after tScalars

   -- fill paint solid, polygon with the count of its scalars, fill paint
   -- solid, rectangle, end
   put numToByte(2) & numToByte(1) & numToByte(19) into tOpcodes
   put pPoints * 2 into tCount
   repeat while tCount >= 128
      put numToByte(128 + tCount mod 128) after tOpcodes
      put tCount div 128 into tCount
   end repeat
   put numToByte(tCount) after tOpcodes
   put numToByte(2) & numToByte(1) & numToByte(13) & numToByte(0) after tOpcodes

   return "LCD" & numToByte(0) & binaryEncode("ff", 100, 100) & \
         binaryEncode("I", the number of bytes of tScalars div 4) & tScalars & \
         binaryEncode("I", the number of bytes of tOpcodes) & tOpcodes
end _Drawing

-- The colour (r,g,b) at pX,pY of the drawing pDrawing shown 100 by 100
private function _PixelAt pDrawing, pX, pY
   local tData, tOffset, tColor
   create image "drawing"
   set the rect of image "drawing" to 0,0,100,100
   set the text of image "drawing" to pDrawing
   import snapshot from image "drawing"
   put the imageData of it into tData
   delete it
   delete image "drawing"
   -- imageData is 4 bytes a pixel, the first unused, then red, green, blue
   put (pY * 100 + pX) * 4 into tOffset
   put byteToNum(byte tOffset + 2 of tData) & comma & byteToNum(byte tOffset + 3 of tData) & comma & \
         byteToNum(byte tOffset + 4 of tData) into tColor
   return tColor
end _PixelAt

private function _IsRed pColor
   return item 1 of pColor > 200 and item 2 of pColor < 60 and item 3 of pColor < 60
end _IsRed

private function _IsBlue pColor
   return item 1 of pColor < 60 and item 2 of pColor < 60 and item 3 of pColor > 200
end _IsBlue

on TestDrawingPolygonCounts
   local tPoints, tDrawing
   -- 20 and 31 points have a count under 64, which both readers read
   -- alike; 32 and 40 have one byte at 64 or more; 70 and 100 two bytes
   repeat for each item tPoints in "20,31,32,40,70,100"
      put _Drawing(tPoints) into tDrawing
      TestAssert "a polygon of" && tPoints && "points is drawn", _IsRed(_PixelAt(tDrawing, 50, 50))
      TestAssert "the shape after a polygon of" && tPoints && "points is drawn", _IsBlue(_PixelAt(tDrawing, 5, 5))
   end repeat
end TestDrawingPolygonCounts

on TestDrawingCountOverflow
   local tDrawing, tColor
   -- a count of more than four 7-bit groups is refused as a whole: the
   -- drawing draws nothing rather than reading past its opcodes
   put "LCD" & numToByte(0) & binaryEncode("ff", 100, 100) & binaryEncode("I", 4) & \
         binaryEncode("ffff", 1, 0, 0, 1) & binaryEncode("I", 9) & \
         numToByte(2) & numToByte(1) & numToByte(19) & numToByte(255) & numToByte(255) & \
         numToByte(255) & numToByte(255) & numToByte(255) & numToByte(1) into tDrawing
   put _PixelAt(tDrawing, 50, 50) into tColor
   TestAssert "an overlong count draws nothing", not _IsRed(tColor)
end TestDrawingCountOverflow
