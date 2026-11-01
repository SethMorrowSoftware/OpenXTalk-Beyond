script "TestDrawingLibrary"
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

-- The drawing library's SVG compiler and the reading of drawings back
-- (OXT-Beyond): compile options (style sheets, opacity), polygons of 32
-- points or more, drawingDecode, drawingFlatten and drawingSvgDecompile.
-- What the compiler made before, it must still make: the compatibility
-- tests compare whole drawings with the bytes the library made before
-- these changes (their MD5s, taken from 0.2.7-rc.6.11's library)

on TestSetup
   TestLoadExternal "revxml"
   local tLib
   put TestGetEngineRepositoryPath() & "/extensions/script-libraries/drawing/drawing.livecodescript" into tLib
   start using stack tLib
   -- the library loads its SVG specification when the IDE initializes it
   -- as an extension, which a test does not
   send "extensionInitialize" to stack tLib
end TestSetup

private function _Svg pBody, pSize
   if pSize is empty then put "100" into pSize
   return "<svg xmlns=" & quote & "http://www.w3.org/2000/svg" & quote && "width=" & quote & pSize & quote && \
         "height=" & quote & pSize & quote & ">" & pBody & "</svg>"
end _Svg

private function _Md5 pData
   local tHex
   get binaryDecode("H*", md5Digest(pData), tHex)
   return tHex
end _Md5

private function _Shape pDrawing, pIndex
   local tDecoded
   put drawingDecode(pDrawing) into tDecoded
   return tDecoded["shapes"][pIndex]
end _Shape

-- (an element of a function's result is not script: these take one)
private function _ShapeKey pDrawing, pIndex, pKey, pSubKey
   local tShape
   put _Shape(pDrawing, pIndex) into tShape
   if pSubKey is empty then return tShape[pKey]
   return tShape[pKey][pSubKey]
end _ShapeKey

private function _FlatShape pDrawing, pTolerance
   local tFlat
   if pTolerance is empty then
      put drawingFlatten(pDrawing) into tFlat
   else
      put drawingFlatten(pDrawing, pTolerance) into tFlat
   end if
   return tFlat["shapes"][1]
end _FlatShape

private function _FlatPoints pDrawing, pTolerance
   local tShape
   put _FlatShape(pDrawing, pTolerance) into tShape
   return tShape["points"]
end _FlatPoints

private function _Near pA, pB
   return abs(pA - pB) < 0.01
end _Near

-------------------------------------------------------------------------------
-- Compatibility: no options compiles what it always did
-------------------------------------------------------------------------------

on TestCompileUnchanged
   -- each SVG, and the MD5 of the drawing the rc.6.11 library compiled
   -- from it (a style sheet and an opacity among them, which the compiler
   -- leaves out unless asked)
   local tCases, tLine, tSvg
   put "rect|<rect x='1' y='2' width='30' height='20' fill='#ff0000' stroke='blue' stroke-width='2'/>|492832daa13b77fccaec0d5538932250" & return after tCases
   put "path|<path d='M10 10 C 20 0 30 20 40 10 S 60 0 70 10 Q 80 20 90 10 T 95 30 A 10 5 30 1 0 50 50 Z' fill='green'/>|b9eba98f0fa14dce6100163d16dac40b" & return after tCases
   put "style|<style>.a{fill:#00ff00}</style><rect class='a' width='10' height='10'/>|c2922044dac958d26fd6f88ff1201d32" & return after tCases
   put "opacity|<rect width='10' height='10' fill='#ff0000' opacity='0.5'/>|e609cc041fc5939ab78a923e183de3f7" & return after tCases
   set the itemDelimiter to "|"
   repeat for each line tLine in tCases
      if item 2 of tLine contains "<rect width='10'" or item 2 of tLine contains "class='a'" then
         put _Svg(item 2 of tLine, 10) into tSvg
      else
         put _Svg(item 2 of tLine) into tSvg
      end if
      TestAssert "no options:" && item 1 of tLine && "compiles as before", \
            _Md5(drawingSvgCompile(tSvg)) is item 3 of tLine
   end repeat
end TestCompileUnchanged

on TestUnknownOptionIgnored
   local tSvg
   put _Svg("<rect width='10' height='10' fill='#ff0000'/>", 10) into tSvg
   TestAssert "an unknown option changes nothing", \
         drawingSvgCompile(tSvg, "no-such-option") is drawingSvgCompile(tSvg)
   TestAssert "an empty option list changes nothing", \
         drawingSvgCompile(tSvg, empty) is drawingSvgCompile(tSvg)
end TestUnknownOptionIgnored

-------------------------------------------------------------------------------
-- Polygons of 32 points or more
-------------------------------------------------------------------------------

private function _CirclePoints pCount
   local tPoints, tIndex
   repeat with tIndex = 0 to pCount - 1
      put round(50 + 40 * cos(2 * pi * tIndex / pCount), 2) & comma & \
            round(50 + 40 * sin(2 * pi * tIndex / pCount), 2) & space after tPoints
   end repeat
   return word 1 to -1 of tPoints
end _CirclePoints

on TestLongPolygonIsAPath
   local tShape, tCount
   repeat for each item tCount in "31,32,40,100"
      put _Shape(drawingSvgCompile(_Svg("<polygon fill='red' points='" & _CirclePoints(tCount) & "'/>")), 1) into tShape
      if tCount < 32 then
         TestAssert "a polygon of" && tCount && "points stays a polygon", tShape["type"] is "polygon"
      else
         TestAssert "a polygon of" && tCount && "points is written as a path", tShape["type"] is "path"
         TestAssert "the path of" && tCount && "points is closed", word -1 of tShape["d"] is "Z"
         TestAssert "the path of" && tCount && "points has every point", \
               the number of elements in tShape["commands"] is tCount + 1
      end if
   end repeat
   put _Shape(drawingSvgCompile(_Svg("<polyline fill='none' stroke='red' points='" & _CirclePoints(50) & "'/>")), 1) into tShape
   TestAssert "a long polyline is a path", tShape["type"] is "path"
   TestAssert "a long polyline's path is open", word -1 of tShape["d"] is not "Z"
end TestLongPolygonIsAPath

on TestLongPolygonKeepsLaterShapes
   local tDecoded
   put drawingDecode(drawingSvgCompile(_Svg("<polygon fill='red' points='" & _CirclePoints(40) & "'/>" & \
         "<rect width='10' height='10' fill='blue'/>"))) into tDecoded
   TestAssert "the shape after a long polygon is still there", \
         tDecoded["shapes"][2]["type"] is "rect" and tDecoded["shapes"][2]["fill"]["color"] is "0,0,1,1"
end TestLongPolygonKeepsLaterShapes

-------------------------------------------------------------------------------
-- Style sheets
-------------------------------------------------------------------------------

private function _FillOf pBody, pIndex
   if pIndex is empty then put 1 into pIndex
   return _ShapeKey(drawingSvgCompile(_Svg(pBody), "styles"), pIndex, "fill", "color")
end _FillOf

on TestStyleSheetClass
   TestAssert "a class rule fills", \
         _FillOf("<style>.a{fill:#ff0000}</style><rect class='a' width='10' height='10'/>") is "1,0,0,1"
   TestAssert "an Illustrator style sheet", \
         _FillOf("<defs><style>.cls-1{fill:#0000ff;}.cls-2{fill:#00ff00;}</style></defs><rect class='cls-2' width='10' height='10'/>") is "0,1,0,1"
   TestAssert "a style sheet in CDATA", \
         _FillOf("<style><![CDATA[ .a { fill: #ff0000 } ]]></style><rect class='a' width='10' height='10'/>") is "1,0,0,1"
   TestAssert "two classes on one element", \
         _FillOf("<style>.a{fill:#ff0000}.b{stroke:#0000ff}</style><rect class='a b' width='10' height='10'/>") is "1,0,0,1"
   TestAssert "a rule for two classes needs both", \
         _FillOf("<style>.a.b{fill:#ff0000}</style><rect class='a' width='10' height='10'/>") is "0,0,0,1"
   TestAssert "a type rule", \
         _FillOf("<style>rect{fill:#ff0000}</style><rect width='10' height='10'/>") is "1,0,0,1"
   TestAssert "a type rule for another type", \
         _FillOf("<style>circle{fill:#ff0000}</style><rect width='10' height='10'/>") is "0,0,0,1"
   TestAssert "a list of selectors", \
         _FillOf("<style>circle, .a {fill:#ff0000}</style><rect class='a' width='10' height='10'/>") is "1,0,0,1"
   TestAssert "a comment is ignored", \
         _FillOf("<style>/* .a{fill:#00ff00} */ .a{fill:#ff0000}</style><rect class='a' width='10' height='10'/>") is "1,0,0,1"
end TestStyleSheetClass

on TestStyleSheetCascade
   TestAssert "an id beats a class", \
         _FillOf("<style>#x{fill:#00ff00} .a{fill:#ff0000}</style><rect id='x' class='a' width='10' height='10'/>") is "0,1,0,1"
   TestAssert "a class beats a type", \
         _FillOf("<style>.a{fill:#00ff00} rect{fill:#ff0000}</style><rect class='a' width='10' height='10'/>") is "0,1,0,1"
   TestAssert "the later of two equal rules wins", \
         _FillOf("<style>.a{fill:#00ff00} .a{fill:#ff0000}</style><rect class='a' width='10' height='10'/>") is "1,0,0,1"
   TestAssert "an inline style beats the style sheet", \
         _FillOf("<style>.a{fill:#00ff00}</style><rect class='a' style='fill:#ff0000' width='10' height='10'/>") is "1,0,0,1"
   TestAssert "the style sheet beats an attribute", \
         _FillOf("<style>.a{fill:#ff0000}</style><rect class='a' fill='#00ff00' width='10' height='10'/>") is "1,0,0,1"
   TestAssert "a group's class is inherited", \
         _FillOf("<style>.a{fill:#ff0000}</style><g class='a'><rect width='10' height='10'/></g>") is "1,0,0,1"
end TestStyleSheetCascade

on TestStyleSheetLeavesOut
   TestAssert "a descendant selector is left out", \
         _FillOf("<style>g .a{fill:#ff0000}</style><g><rect class='a' width='10' height='10'/></g>") is "0,0,0,1"
   TestAssert "a pseudo-class is left out", \
         _FillOf("<style>.a:hover{fill:#ff0000}</style><rect class='a' width='10' height='10'/>") is "0,0,0,1"
   TestAssert "an @media block is left out, the rest kept", \
         _FillOf("<style>@media print{.a{fill:#00ff00}} .b{fill:#ff0000}</style><rect class='a b' width='10' height='10'/>") is "1,0,0,1"
   TestAssert "without the option the style sheet is left out", \
         _ShapeKey(drawingSvgCompile(_Svg("<style>.a{fill:#ff0000}</style><rect class='a' width='10' height='10'/>")), 1, "fill", "color") is "0,0,0,1"
end TestStyleSheetLeavesOut

-------------------------------------------------------------------------------
-- Opacity
-------------------------------------------------------------------------------

private function _OpacityOf pBody, pIndex, pWhich
   if pIndex is empty then put 1 into pIndex
   if pWhich is empty then put "fill-opacity" into pWhich
   return _ShapeKey(drawingSvgCompile(_Svg(pBody), "opacity,styles"), pIndex, pWhich)
end _OpacityOf

on TestOpacity
   TestAssert "an opacity attribute", _Near(_OpacityOf("<rect width='10' height='10' fill='red' opacity='0.5'/>"), 0.5)
   TestAssert "it applies to the line too", _Near(_OpacityOf("<rect width='10' height='10' fill='red' stroke='blue' opacity='0.5'/>", 1, "stroke-opacity"), 0.5)
   TestAssert "an opacity in a style", _Near(_OpacityOf("<rect width='10' height='10' fill='red' style='opacity:0.25'/>"), 0.25)
   TestAssert "an opacity from a style sheet", _Near(_OpacityOf("<style>.a{opacity:0.4}</style><rect class='a' width='10' height='10' fill='red'/>"), 0.4)
   TestAssert "an opacity as a percentage", _Near(_OpacityOf("<rect width='10' height='10' fill='red' opacity='50%'/>"), 0.5)
   TestAssert "times the fill opacity", _Near(_OpacityOf("<rect width='10' height='10' fill='red' fill-opacity='0.5' opacity='0.5'/>"), 0.25)
   TestAssert "a group's times its shapes'", _Near(_OpacityOf("<g opacity='0.5'><g opacity='0.5'><rect width='10' height='10' fill='red'/></g></g>"), 0.25)
   TestAssert "a group's only below it", _Near(_OpacityOf("<g opacity='0.5'><rect width='10' height='10' fill='red'/></g><rect width='10' height='10' fill='red'/>", 2), 1)
   TestAssert "out of range is clamped", _Near(_OpacityOf("<rect width='10' height='10' fill='red' opacity='3'/>"), 1)
   TestAssert "without the option opacity is left out", \
         _Near(_ShapeKey(drawingSvgCompile(_Svg("<rect width='10' height='10' fill='red' opacity='0.5'/>")), 1, "fill-opacity"), 1)
end TestOpacity

-------------------------------------------------------------------------------
-- References and paths as drawing programs and minifiers write them
-------------------------------------------------------------------------------

on TestIdReferences
   local tId, tSvg
   repeat for each item tId in "grad-1,grad_1,a.b,1st"
      put _Svg("<defs><linearGradient id='" & tId & "'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs>" & \
            "<rect width='10' height='10' fill='url(#" & tId & ")'/>", 10) into tSvg
      TestAssert "ids: a gradient with the id" && tId, _ShapeKey(drawingSvgCompile(tSvg, "ids"), 1, "fill", "type") is "linear"
   end repeat
   put _Svg("<defs><linearGradient id='g-1'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs>" & \
         "<rect width='10' height='10' fill=" & quote & "url('#g-1')" & quote & "/>", 10) into tSvg
   TestAssert "ids: a quoted reference", _ShapeKey(drawingSvgCompile(tSvg, "ids"), 1, "fill", "type") is "linear"
   put _Svg("<defs><linearGradient id='g-1'><stop offset='0' stop-color='red'/></linearGradient></defs>" & \
         "<rect width='10' height='10' fill='url(#g-1) blue'/>", 10) into tSvg
   TestAssert "ids: a reference with a fallback", _ShapeKey(drawingSvgCompile(tSvg, "ids"), 1, "fill", "type") is "linear"
   put _Svg("<defs><linearGradient id='g-1'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs>" & \
         "<rect width='10' height='10' fill='url(#g-1)'/>", 10) into tSvg
   TestAssert "ids: all includes ids", _ShapeKey(drawingSvgCompile(tSvg, "all"), 1, "fill", "type") is "linear"
   TestAssert "ids: without the option, as before", _ShapeKey(drawingSvgCompile(tSvg), 1, "fill", "type") is not "linear"
end TestIdReferences

on TestGradientFocalDefault
   local tSvg, tShape
   -- a radial gradient centred off 50% with no fx or fy: SVG puts the focal
   -- point at the centre, a plain radial gradient (Noto's emoji hair)
   put _Svg("<defs><radialGradient id='r' cx='20' cy='70' r='30' gradientUnits='userSpaceOnUse'>" & \
         "<stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs>" & \
         "<rect width='100' height='100' fill='url(#r)'/>") into tSvg
   TestAssert "gradients: the focal point defaults to the centre", _ShapeKey(drawingSvgCompile(tSvg, "gradients"), 1, "fill", "type") is "radial"
   TestAssert "gradients: all includes it", _ShapeKey(drawingSvgCompile(tSvg, "all"), 1, "fill", "type") is "radial"
   TestAssert "gradients: without the option, as before", _ShapeKey(drawingSvgCompile(tSvg), 1, "fill", "type") is "conical"
   -- an fx given is kept, and one given on the gradient an href names is inherited
   put _Svg("<defs><radialGradient id='b' fx='30'/><radialGradient id='r' href='#b' cx='20' cy='70' r='30' gradientUnits='userSpaceOnUse'>" & \
         "<stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs>" & \
         "<rect width='100' height='100' fill='url(#r)'/>") into tSvg
   put _Shape(drawingSvgCompile(tSvg, "gradients"), 1) into tShape
   TestAssert "gradients: an inherited fx is kept", tShape["fill"]["type"] is "conical" and _Near(tShape["fill"]["fx"], 1/3) and _Near(tShape["fill"]["fy"], 0)
end TestGradientFocalDefault

on TestMinifiedArcFlags
   local tDrawing
   -- an arc's two flags written together with the number after them, as
   -- svgo and most exporters write them: the engine's path reader refused
   -- it, which failed the whole SVG
   put drawingSvgCompile(_Svg("<path d='M10 50a40 40 0 1150 0z' fill='red'/>")) into tDrawing
   TestAssert "flags together: compiles", the result is empty and tDrawing begins with "LCD"
   TestAssert "flags together: read as two flags", _ShapeKey(tDrawing, 1, "d") is "M10 50 A40 40 0 1 1 60 50 Z"
   put drawingSvgCompile(_Svg("<path d='M0-12A6 6 0 000 0a6 6 0 010 12 12 12 0 010-24z' fill='blue'/>")) into tDrawing
   TestAssert "flags together: a run of arcs", _ShapeKey(tDrawing, 1, "d") is "M0 -12 A6 6 0 0 0 0 0 A6 6 0 0 1 0 12 A12 12 0 0 1 0 -12 Z"
end TestMinifiedArcFlags

on TestFailureDoesNotStick
   local tGood
   -- up to 0.2.7-rc.6.11 the engine kept the error of a path it could not
   -- read, and every SVG compiled after it failed too, until a restart
   put drawingSvgCompile(_Svg("<rect width='10' height='10' fill='red'/>", 10)) into tGood
   get drawingSvgCompile(_Svg("<path d='M10 50a40 40 0 1150 0z' fill='red'/>"))
   get drawingSvgCompile(_Svg("<path d='M 10 10 L' fill='red'/>"))
   get drawingSvgCompile(_Svg("<rect width='10' height='10' fill='red'/>", 10))
   TestAssert "a compile after a bad path still works", it is tGood and the result is empty
end TestFailureDoesNotStick

-------------------------------------------------------------------------------
-- Drawn, as the engine draws them
-------------------------------------------------------------------------------

-- The colour (r,g,b) at pX,pY of pDrawing shown pSize by pSize
private function _PixelAt pDrawing, pX, pY, pSize
   local tData, tOffset
   if pSize is empty then put 100 into pSize
   create image "drawing"
   set the rect of image "drawing" to 0, 0, pSize, pSize
   set the text of image "drawing" to pDrawing
   import snapshot from image "drawing"
   put the imageData of it into tData
   delete it
   delete image "drawing"
   put (pY * pSize + pX) * 4 into tOffset
   return byteToNum(byte tOffset + 2 of tData) & comma & byteToNum(byte tOffset + 3 of tData) & comma & \
         byteToNum(byte tOffset + 4 of tData)
end _PixelAt

private function _IsColor pColor, pR, pG, pB
   return abs(item 1 of pColor - pR) < 40 and abs(item 2 of pColor - pG) < 40 and abs(item 3 of pColor - pB) < 40
end _IsColor

on TestDrawHalfCircleArcs
   local tDrawing
   -- the Korean flag's taegeuk: arcs whose ends are a diameter apart. The
   -- engine's arc lost its centre to rounding (sqrt of a tiny negative)
   -- and drew a sliver. With SVG's sweep flags the big half is on the
   -- LEFT, with a small bulge into the right below the centre and a small
   -- bite out of the left above it (the points checked against cairosvg)
   put drawingSvgCompile("<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='-25 -25 50 50'>" & \
         "<path fill='#0000ff' d='M0-12A6 6 0 000 0a6 6 0 010 12 12 12 0 010-24z'/></svg>") into tDrawing
   TestAssert "half circle arcs: the big half drawn", _IsColor(_PixelAt(tDrawing, 30, 50), 0, 0, 255)
   TestAssert "half circle arcs: the small bulge drawn", _IsColor(_PixelAt(tDrawing, 55, 62), 0, 0, 255)
   TestAssert "half circle arcs: the right half empty", not _IsColor(_PixelAt(tDrawing, 70, 50), 0, 0, 255)
   TestAssert "half circle arcs: the small bite empty", not _IsColor(_PixelAt(tDrawing, 55, 38), 0, 0, 255)
end TestDrawHalfCircleArcs

on TestDrawGradientById
   local tDrawing
   put drawingSvgCompile(_Svg("<defs><linearGradient id='g-1'><stop offset='0' stop-color='#ff0000'/><stop offset='1' stop-color='#ff0000'/></linearGradient></defs>" & \
         "<rect width='100' height='100' fill='url(#g-1)'/>"), "all") into tDrawing
   TestAssert "a gradient referred to by a hyphenated id is drawn", _IsColor(_PixelAt(tDrawing, 50, 50), 255, 0, 0)
end TestDrawGradientById

on TestDrawLongPolygon
   local tDrawing
   put drawingSvgCompile(_Svg("<polygon fill='#ff0000' points='" & _CirclePoints(40) & "'/><rect width='10' height='10' fill='#0000ff'/>")) into tDrawing
   TestAssert "a 40 point polygon is drawn", _IsColor(_PixelAt(tDrawing, 50, 50), 255, 0, 0)
   TestAssert "and the shape after it", _IsColor(_PixelAt(tDrawing, 5, 5), 0, 0, 255)
end TestDrawLongPolygon

-------------------------------------------------------------------------------
-- Clip paths
-------------------------------------------------------------------------------

private function _ClipSvg
   return _Svg("<defs><clipPath id='c-1'><rect x='0' y='0' width='50' height='50'/></clipPath></defs>" & \
         "<g transform='translate(10 0)'><rect width='100' height='100' fill='#ff0000' clip-path='url(#c-1)'/></g>" & \
         "<rect x='90' y='90' width='10' height='10' fill='#0000ff'/>")
end _ClipSvg

on TestClipCompiles
   local tDrawing, tDecoded
   put drawingSvgCompile(_ClipSvg(), "clip") into tDrawing
   TestAssert "clip: compiles", the result is empty and tDrawing begins with "LCD"
   put drawingDecode(tDrawing) into tDecoded
   TestAssert "clip: one clip path", the number of elements in tDecoded["clips"] is 1
   TestAssert "clip: its shape", tDecoded["clips"][1]["shapes"][1]["type"] is "rect" and tDecoded["clips"][1]["shapes"][1]["width"] is 50
   TestAssert "clip: in the element's coordinates", tDecoded["clips"][1]["shapes"][1]["transform"] is "1,0,0,1,10,0"
   TestAssert "clip: two shapes drawn", the number of elements in tDecoded["shapes"] is 2
   TestAssert "clip: the first under the clip", tDecoded["shapes"][1]["clip"] is 1
   TestAssert "clip: the second not", tDecoded["shapes"][2]["clip"] is empty
   TestAssert "clip: the state after it", tDecoded["shapes"][2]["transform"] is empty and tDecoded["shapes"][2]["fill"]["color"] is "0,0,1,1"
end TestClipCompiles

on TestClipForms
   local tSvg, tDecoded
   -- in a style, on a group, a quoted reference, nested, and a use of a clipped element
   put _Svg("<clipPath id='a'><circle cx='50' cy='50' r='40'/></clipPath><clipPath id='b'><rect width='50' height='100'/></clipPath>" & \
         "<g style='clip-path:url(" & quote & "#a" & quote & ")'><rect id='r' width='100' height='100' fill='red' clip-path='url(#b)'/></g>" & \
         "<use href='#r' x='0' y='0'/>") into tSvg
   put drawingDecode(drawingSvgCompile(tSvg, "clip")) into tDecoded
   TestAssert "clip forms: compiles", the result is empty
   TestAssert "clip forms: nested clips, outermost first", tDecoded["shapes"][1]["clip"] is "1,2"
   TestAssert "clip forms: a use of a clipped element is clipped", tDecoded["shapes"][2]["clip"] is 3
   -- a clip path that is missing leaves the element unclipped; an empty one hides it
   put drawingDecode(drawingSvgCompile(_Svg("<rect width='10' height='10' clip-path='url(#nothing)'/>"), "clip")) into tDecoded
   TestAssert "clip forms: missing clip path", the number of elements in tDecoded["shapes"] is 1 and tDecoded["shapes"][1]["clip"] is empty
   put drawingDecode(drawingSvgCompile(_Svg("<clipPath id='e'></clipPath><rect width='10' height='10' clip-path='url(#e)'/>"), "clip")) into tDecoded
   TestAssert "clip forms: empty clip path hides", the number of elements in tDecoded["shapes"] is 0
end TestClipForms

on TestClipWithoutOption
   TestAssert "clip: without the option, as before", drawingSvgCompile(_ClipSvg()) is drawingSvgCompile(_ClipSvg(), "styles")
   TestAssert "clip: all includes clip", drawingSvgCompile(_ClipSvg(), "all") is drawingSvgCompile(_ClipSvg(), "clip,styles,opacity,ids")
end TestClipWithoutOption

on TestClipFlatten
   local tFlat
   put drawingFlatten(drawingSvgCompile(_ClipSvg(), "clip")) into tFlat
   TestAssert "clip: flattened clip shape", line 1 of tFlat["clips"][1]["shapes"][1]["points"] is "10,0"
   TestAssert "clip: flattened shape keeps its clip", tFlat["shapes"][1]["clip"] is 1
end TestClipFlatten

on TestDrawClip
   local tDrawing
   put drawingSvgCompile(_ClipSvg(), "clip") into tDrawing
   TestAssert "clip drawn: inside", _IsColor(_PixelAt(tDrawing, 30, 25), 255, 0, 0)
   TestAssert "clip drawn: outside is not red", not _IsColor(_PixelAt(tDrawing, 75, 75), 255, 0, 0)
   TestAssert "clip drawn: left of the clip is not red", not _IsColor(_PixelAt(tDrawing, 5, 25), 255, 0, 0)
   TestAssert "clip drawn: the shape after it", _IsColor(_PixelAt(tDrawing, 95, 95), 0, 0, 255)
end TestDrawClip

on TestDrawSmoothQuadratics
   local tDrawing
   -- a T after a T reflects the control point of the curve before it; the
   -- engine forgot it after the first T and drew a straight line
   put drawingSvgCompile("<svg xmlns='http://www.w3.org/2000/svg' width='150' height='150'>" & \
         "<path fill='#0000ff' d='M0 50 Q25 0 50 50 T100 50 T150 50 Z'/></svg>") into tDrawing
   TestAssert "T after T: the third bulge drawn", _IsColor(_PixelAt(tDrawing, 125, 35, 150), 0, 0, 255)
   TestAssert "T after T: the first bulge drawn", _IsColor(_PixelAt(tDrawing, 25, 35, 150), 0, 0, 255)
end TestDrawSmoothQuadratics

-------------------------------------------------------------------------------
-- drawingDecode
-------------------------------------------------------------------------------

on TestDecodeShapes
   local tDecoded, tShape
   put drawingDecode(drawingSvgCompile(_Svg("<rect x='1' y='2' width='30' height='20' rx='3'/>" & \
         "<circle cx='5' cy='6' r='7'/><ellipse cx='1' cy='2' rx='3' ry='4'/>" & \
         "<line x1='1' y1='2' x2='3' y2='4' stroke='black'/><polyline points='1,2 3,4 5,6'/>" & \
         "<polygon points='1,2 3,4 5,6'/><path d='m 10 10 l 5 0 h 5 v 5 z'/>", 200))) into tDecoded
   TestAssert "decode: no error", the result is empty
   TestAssert "decode: size", tDecoded["width"] is 200 and tDecoded["height"] is 200
   TestAssert "decode: seven shapes", the number of elements in tDecoded["shapes"] is 7
   put tDecoded["shapes"][1] into tShape
   TestAssert "decode: rounded rect", tShape["type"] is "rect" and tShape["x"] is 1 and tShape["y"] is 2 \
         and tShape["width"] is 30 and tShape["height"] is 20 and tShape["rx"] is 3 and tShape["ry"] is 3
   put tDecoded["shapes"][2] into tShape
   TestAssert "decode: circle", tShape["type"] is "circle" and tShape["cx"] is 5 and tShape["cy"] is 6 and tShape["r"] is 7
   put tDecoded["shapes"][3] into tShape
   TestAssert "decode: ellipse", tShape["type"] is "ellipse" and tShape["rx"] is 3 and tShape["ry"] is 4
   put tDecoded["shapes"][4] into tShape
   TestAssert "decode: line", tShape["type"] is "line" and tShape["x2"] is 3 and tShape["y2"] is 4
   TestAssert "decode: polyline", tDecoded["shapes"][5]["points"] is "1,2 3,4 5,6"
   TestAssert "decode: polygon", tDecoded["shapes"][6]["type"] is "polygon" and tDecoded["shapes"][6]["points"] is "1,2 3,4 5,6"
   TestAssert "decode: relative path made absolute", tDecoded["shapes"][7]["d"] is "M10 10 L15 10 H20 V15 Z"
end TestDecodeShapes

on TestDecodeState
   local tShape
   put _Shape(drawingSvgCompile(_Svg("<rect width='10' height='10' fill='#ff8000' fill-opacity='0.5' fill-rule='evenodd' " & \
         "stroke='#0000ff' stroke-width='3' stroke-linejoin='round' stroke-linecap='square' stroke-dasharray='4 2' " & \
         "stroke-dashoffset='1' stroke-miterlimit='7' transform='translate(5 6) scale(2)'/>")), 1) into tShape
   TestAssert "decode: fill", tShape["fill"]["type"] is "color" and tShape["fill"]["color"] is "1,0.502,0,1"
   TestAssert "decode: fill opacity", tShape["fill-opacity"] is 0.5
   TestAssert "decode: fill rule", tShape["fill-rule"] is "evenodd"
   TestAssert "decode: stroke", tShape["stroke"]["color"] is "0,0,1,1" and tShape["stroke-width"] is 3
   TestAssert "decode: join and cap", tShape["stroke-linejoin"] is "round" and tShape["stroke-linecap"] is "square"
   TestAssert "decode: dashes", tShape["stroke-dasharray"] is "4,2" and tShape["stroke-dashoffset"] is 1
   TestAssert "decode: miter limit", tShape["stroke-miterlimit"] is 7
   TestAssert "decode: transform", tShape["transform"] is "2,0,0,2,5,6"
end TestDecodeState

on TestDecodeGradient
   local tShape
   put _Shape(drawingSvgCompile(_Svg("<linearGradient id='g' spreadMethod='reflect'><stop offset='0' stop-color='red'/>" & \
         "<stop offset='1' stop-color='blue' stop-opacity='0.5'/></linearGradient>" & \
         "<rect width='10' height='10' fill='url(#g)'/>")), 1) into tShape
   TestAssert "decode: linear gradient", tShape["fill"]["type"] is "linear"
   TestAssert "decode: spread", tShape["fill"]["spread"] is "reflect"
   TestAssert "decode: stops", tShape["fill"]["stops"] is ("0,1,0,0,1" & return & "1,0,0,1,0.5")
   TestAssert "decode: gradient transform", the number of items of tShape["fill"]["transform"] is 6
end TestDecodeGradient

on TestDecodeNotADrawing
   get drawingDecode("not a drawing at all")
   TestAssert "decode: not a drawing is an error", it is empty and the result is not empty
   get drawingDecode(empty)
   TestAssert "decode: empty is an error", it is empty and the result is not empty
end TestDecodeNotADrawing

-------------------------------------------------------------------------------
-- drawingFlatten
-------------------------------------------------------------------------------

on TestFlattenCircle
   local tFlat, tLine, tWorst, tDist
   put drawingFlatten(drawingSvgCompile(_Svg("<circle cx='50' cy='50' r='40' fill='red'/>")), 0.25) into tFlat
   TestAssert "flatten: no error", the result is empty
   TestAssert "flatten: closed", line 1 of tFlat["shapes"][1]["points"] is line -1 of tFlat["shapes"][1]["points"]
   put 0 into tWorst
   repeat for each line tLine in tFlat["shapes"][1]["points"]
      put abs(sqrt((item 1 of tLine - 50) ^ 2 + (item 2 of tLine - 50) ^ 2) - 40) into tDist
      put max(tWorst, tDist) into tWorst
   end repeat
   TestAssert "flatten: every point on the circle", tWorst < 0.01
   TestAssert "flatten: enough points for the tolerance", the number of lines of tFlat["shapes"][1]["points"] >= 30
   TestAssert "flatten: fewer for a looser tolerance", \
         the number of lines of _FlatPoints(drawingSvgCompile(_Svg("<circle cx='50' cy='50' r='40'/>")), 2) \
         < the number of lines of tFlat["shapes"][1]["points"]
end TestFlattenCircle

on TestFlattenRuns
   local tPoints
   put _FlatPoints(drawingSvgCompile(_Svg("<path fill-rule='evenodd' d='M0 0 H10 V10 H0 Z M2 2 H8 V8 H2 Z'/>"))) into tPoints
   TestAssert "flatten: two runs, an empty line between", \
         tPoints is ("0,0" & return & "10,0" & return & "10,10" & return & "0,10" & return & "0,0" & return & return & \
         "2,2" & return & "8,2" & return & "8,8" & return & "2,8" & return & "2,2")
end TestFlattenRuns

on TestFlattenTransform
   local tShape
   put _FlatShape(drawingSvgCompile(_Svg("<rect width='10' height='10' stroke='red' stroke-width='2' transform='translate(5 5) scale(3)'/>"))) into tShape
   TestAssert "flatten: transformed", line 1 of tShape["points"] is "5,5" and line 3 of tShape["points"] is "35,35"
   TestAssert "flatten: stroke width scaled", _Near(tShape["stroke-width"], 6)
end TestFlattenTransform

on TestFlattenCurves
   local tPoints, tLine, tOk
   -- a cubic from 0,0 to 100,0 whose controls are both at 50,100 peaks at
   -- 75 (three quarters of the controls' height)
   put _FlatPoints(drawingSvgCompile(_Svg("<path d='M0 0 C50 100 50 100 100 0' fill='none' stroke='black'/>", 200)), 0.1) into tPoints
   TestAssert "flatten: cubic ends", line 1 of tPoints is "0,0" and line -1 of tPoints is "100,0"
   -- the flattened peak is within the tolerance of the curve's, and no
   -- point is above it (the steps need not land on t = 0.5)
   put 0 into tOk
   repeat for each line tLine in tPoints
      put max(tOk, item 2 of tLine) into tOk
   end repeat
   TestAssert "flatten: cubic's peak", tOk <= 75.0001 and tOk >= 74.9
   -- a half circle arc of radius 10 from 0,10 to 20,10
   put _FlatPoints(drawingSvgCompile(_Svg("<path d='M0 10 A10 10 0 0 1 20 10' fill='none' stroke='black'/>")), 0.1) into tPoints
   TestAssert "flatten: arc ends", line 1 of tPoints is "0,10" and line -1 of tPoints is "20,10"
   put true into tOk
   repeat for each line tLine in tPoints
      if abs(sqrt((item 1 of tLine - 10) ^ 2 + (item 2 of tLine - 10) ^ 2) - 10) > 0.01 or item 2 of tLine > 10.001 then
         put false into tOk
      end if
   end repeat
   TestAssert "flatten: arc on its circle, above its chord", tOk
end TestFlattenCurves

-------------------------------------------------------------------------------
-- drawingSvgDecompile
-------------------------------------------------------------------------------

on TestDecompileRoundTrip
   local tSvg, tDrawing, tBack, tA, tB, tIndex, tKey, tSame
   put _Svg("<style>.a{fill:#ff0000}</style><g opacity='0.5'><rect class='a' x='1' y='2' width='30' height='20' rx='3' stroke='blue' stroke-dasharray='2 1'/></g>" & \
         "<linearGradient id='g'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient>" & \
         "<ellipse cx='50' cy='50' rx='20' ry='10' fill='url(#g)' transform='rotate(30)'/>" & \
         "<path d='M10 10 C20 0 30 20 40 10 S60 0 70 10 Q80 20 90 10 T95 30 A10 5 30 1 0 50 50 Z' fill='green' fill-rule='evenodd'/>" & \
         "<polygon points='" & _CirclePoints(40) & "' fill='none' stroke='black' stroke-linejoin='round'/>", 200) into tSvg
   put drawingSvgCompile(tSvg, "styles,opacity") into tDrawing
   put drawingSvgDecompile(tDrawing) into tBack
   TestAssert "decompile: no error", the result is empty
   TestAssert "decompile: an SVG", tBack begins with "<svg" and tBack contains "</svg>"
   put drawingDecode(tDrawing) into tA
   put drawingDecode(drawingSvgCompile(tBack)) into tB
   TestAssert "decompile: compiles to as many shapes", the number of elements in tA["shapes"] is the number of elements in tB["shapes"]
   put true into tSame
   repeat with tIndex = 1 to the number of elements in tA["shapes"]
      repeat for each item tKey in "type,fill-opacity,fill-rule,stroke-opacity,stroke-width,stroke-linejoin,stroke-dasharray,d,points"
         if tA["shapes"][tIndex][tKey] is not tB["shapes"][tIndex][tKey] then
            TestDiagnostic "shape" && tIndex && tKey & ":" && tA["shapes"][tIndex][tKey] && "/" && tB["shapes"][tIndex][tKey]
            put false into tSame
         end if
      end repeat
      if tA["shapes"][tIndex]["fill"]["color"] is not tB["shapes"][tIndex]["fill"]["color"] then
         TestDiagnostic "shape" && tIndex && "fill:" && tA["shapes"][tIndex]["fill"]["color"] && "/" && tB["shapes"][tIndex]["fill"]["color"]
         put false into tSame
      end if
   end repeat
   TestAssert "decompile: compiles to the same shapes", tSame
end TestDecompileRoundTrip

on TestDecompileNotADrawing
   get drawingSvgDecompile("nonsense")
   TestAssert "decompile: not a drawing is an error", it is empty and the result is not empty
end TestDecompileNotADrawing
