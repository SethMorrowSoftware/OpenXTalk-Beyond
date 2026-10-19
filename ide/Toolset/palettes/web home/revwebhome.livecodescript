script "revWebHome"
-- OXT-Beyond: Home, the IDE's welcome stack.
--
-- In the spirit of HyperCard's Home stack: the window that shows what a
-- stack can do with live demos, and leads to everything else (a new
-- stack, the lessons, the examples, the Dictionary). Help > Welcome to
-- OXT-Beyond opens it: in the web IDE through revWebIDELibrary
-- (revWebIDEShowHome), which also opens it at startup unless the user
-- turned that off, and on the desktop through revMenubar (tOpenHome),
-- which opens it at startup only when the user turned that on (it opened
-- nothing at startup before). Where a page speaks of the browser, the
-- desktop has its own words (hmOnWeb).
--
-- The window can be resized. The sidebar runs down its left side, with
-- its foot at the bottom, and the pages keep their own size, in the middle
-- of the room on its right (hmLayout). Every page is built and animated in
-- the coordinates of a 1024 by 640 window; sOX and sOY are how far the
-- pages are from there, and the few things a frame places by number add
-- them.
--
-- Home has the look of the web tour (the Stack Player's "OXT-Beyond on
-- the Web"), so that the stacks a newcomer meets look like one family: a
-- dark sidebar of pages with Back and Next, a header with each page's
-- title, tagline and accent colour, white panels on slate, a status line,
-- and one palette, read through hmColor. The icons are Lucide's (ISC
-- licence, see THIRD-PARTY-NOTICES.md), drawn by drawingSvgCompile.
--
-- It is a script-only stack, so it keeps no controls: this script builds
-- them when it opens, on one card. Each page is a group, and moving
-- between pages pushes the content area as the tour's cards do. One timer
-- (hmTick) draws every animation while Home is open: each frame sets the
-- defaultStack to Home and then puts it back, so that neither the IDE nor
-- the user's stacks see it change. Its name begins with "rev", so the IDE
-- treats it as one of its own windows.

constant kWidth = 1024
constant kHeight = 640
constant kSide = 200
constant kPages = "home,speak,move,draw,web,app"
constant kFrame = 16
constant kAwayFrame = 100
constant kPool = 120
constant kStage = "224,96,1000,452"
constant kTextInset = 4

-- The page in front, and the time it opened (its controls slide in)
local sPage, sPageStart
-- The pending frame, this frame's time, and the time since the last one
local sTick, sNow, sLastFrame, sDt
-- True while another window is in front: Home then draws ten frames a
-- second, not sixty, and leaves the browser to the window in use
local sAway
-- The groups that light up when the pointer is over them and do something
-- when clicked, by name: what each one does and how it looks
local sCfg, sLiveList, sHover, sHoverAmt, sEnterAmt
-- The sidebar's highlight, sliding to the page in front
local sNavY, sNavTarget
-- The font code is shown in ("-" for the default font)
local sFont
-- Each page's own state
local sHero, sSpeak, sMove, sDraw, sWeb, sApp
-- The Move page's balls
local sBx, sBy, sBvx, sBvy, sBr, sBlife, sBage, sBhue, sBshown, sBcolor, sBkind
local sFpsFrames, sFpsStart, sFps
local sTipAt, sTipIndex
-- How far the pages are from where a 1024 by 640 window has them, and the
-- window's size they were laid out for
local sOX, sOY, sLaidW, sLaidH

################################################################################
#
# Opening and closing
#

on preOpenStack
   hmBuild
   hmPlace
   -- (a script-only stack is made invisible when it is loaded)
   show me
end preOpenStack

on openStack
   put empty into sPage
   hmGoPage "home"
   hmStartTicking
end openStack

on suspendStack
   put true into sAway
   -- (the pointer has gone to the other window, and no mouseMove says so)
   hmHoverOn empty
   pass suspendStack
end suspendStack

on resumeStack
   put false into sAway
   pass resumeStack
end resumeStack

on closeStack
   hmStopTicking
   if sHover is not empty then
      put empty into sHover
      unlock cursor
   end if
end closeStack

on resizeStack pWidth, pHeight
   hmLayout pWidth, pHeight
   pass resizeStack
end resizeStack

-- True in the web IDE, where Home speaks of the browser
private function hmOnWeb
   return the platform is "HTML5"
end hmOnWeb

-- pWeb in the web IDE, pDesktop on the desktop
private function hmPick pWeb, pDesktop
   if hmOnWeb() then
      return pWeb
   end if
   return pDesktop
end hmPick

-- The room the pages are in, right of the sidebar
private function hmContentRect
   return kSide & ",0," & the width of me & "," & the height of me
end hmContentRect

-- The stage of the Move page, where the window has it
private function hmStageRect
   return (224 + sOX) & "," & (96 + sOY) & "," & (1000 + sOX) & "," & (452 + sOY)
end hmStageRect

-- Lays Home out for a window pWidth by pHeight: the sidebar as tall as
-- the window, its foot at the bottom, and the pages and the header in the
-- middle of the room on the right. Things are moved by how far they are
-- from where they were, so it can run as often as the window changes.
private command hmLayout pWidth, pHeight
   local tSaved, tOX, tOY, tDX, tDY, tFoot, tPage, tName, tGroups
   if there is not a group "pg_home" of me then
      exit hmLayout
   end if
   if sLaidW is empty then
      put kWidth into sLaidW
      put kHeight into sLaidH
      put 0 into sOX
      put 0 into sOY
   end if
   put max(0, (pWidth - kWidth) div 2) into tOX
   put max(0, (pHeight - kHeight) div 2) into tOY
   put tOX - sOX into tDX
   put tOY - sOY into tDY
   put pHeight - sLaidH into tFoot
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   -- The sidebar
   set the rect of graphic "sideBg" to 0, 0, kSide, pHeight
   hmGradientPoints the long id of graphic "sideBg", "0,0", "0," & pHeight
   if tFoot is not 0 then
      repeat for each item tName in "startup,back,next"
         set the top of group tName to the top of group tName + tFoot
         if sCfg[tName]["top"] is not empty then
            add tFoot to sCfg[tName]["top"]
         end if
      end repeat
      repeat for each item tName in "navCount,navKeys"
         set the top of field tName to the top of field tName + tFoot
      end repeat
   end if
   -- The pages, the header and the status line
   if tDX is not 0 or tDY is not 0 then
      repeat for each item tPage in kPages
         put "pg_" & tPage & comma after tGroups
      end repeat
      repeat for each item tName in tGroups & "hdr"
         set the topLeft of group tName to the left of group tName + tDX, the top of group tName + tDY
      end repeat
      set the topLeft of field "hdrStatus" to the left of field "hdrStatus" + tDX, the top of field "hdrStatus" + tDY
      -- (a lit thing that slides in or lifts is put at its own top)
      repeat for each item tPage in kPages
         repeat for each line tName in sLiveList[tPage]
            if sCfg[tName]["top"] is not empty then
               add tDY to sCfg[tName]["top"]
            end if
         end repeat
      end repeat
      -- (the line the Speak page offers names a place on its stage)
      if field "spkInput" is hmSpeakFirstTry() then
         add tDX to sOX
         add tDY to sOY
         put hmSpeakFirstTry() into field "spkInput"
         subtract tDX from sOX
         subtract tDY from sOY
      end if
   end if
   put tOX into sOX
   put tOY into sOY
   put pWidth into sLaidW
   put pHeight into sLaidH
   unlock messages
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end hmLayout

-- Below the menu bar, in the middle of the page
private command hmPlace
   local tScreen, tTop, tError
   put the screenRect into tScreen
   put item 2 of tScreen + 40 into tTop
   if there is a stack "revMenubar" and the visible of stack "revMenubar" then
      put max(tTop, the bottom of stack "revMenubar" + 44) into tTop
   end if
   if tTop + the height of me > item 4 of tScreen then
      put max(item 2 of tScreen + 31, item 4 of tScreen - the height of me) into tTop
   end if
   set the topLeft of me to max(item 1 of tScreen, (item 1 of tScreen + item 3 of tScreen - the width of me) div 2), tTop
   if there is a stack "revWebIDELibrary" then
      try
         revWebIDEKeepOnPage the long id of me, empty, true
      catch tError
      end try
   end if
end hmPlace

private command hmStartTicking
   hmStopTicking
   put the milliseconds into sLastFrame
   put sLastFrame into sFpsStart
   put 0 into sFpsFrames
   send "hmTick" to me in kFrame milliseconds
   put the result into sTick
end hmStartTicking

private command hmStopTicking
   if sTick is not empty then
      cancel sTick
      put empty into sTick
   end if
end hmStopTicking

-- One frame of every animation. A timer handler runs whatever stack is in
-- front, so the frame sets the defaultStack to Home, and puts it back.
-- A frame that fails is skipped, not shown as an error sixty times a
-- second.
on hmTick
   local tSaved, tError
   put empty into sTick
   if the mode of me is 0 then
      exit hmTick
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   put the milliseconds into sNow
   put min(0.1, max(0, (sNow - sLastFrame) / 1000)) into sDt
   put sNow into sLastFrame
   lock screen
   try
      hmFrame
   catch tError
   end try
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
   if sAway is true then
      send "hmTick" to me in kAwayFrame milliseconds
   else
      send "hmTick" to me in kFrame milliseconds
   end if
   put the result into sTick
end hmTick

################################################################################
#
# The look
#

-- The palette: the web tour's, and a few colours of the sidebar and the
-- code panels. Nothing else names a colour.
private function hmColor pName
   switch pName
      case "bg"
         return "241,245,249"
      case "panel"
         return "255,255,255"
      case "line"
         return "226,232,240"
      case "ink"
         return "15,23,42"
      case "soft"
         return "71,85,105"
      case "muted"
         return "148,163,184"
      case "side"
         return "15,23,42"
      case "side2"
         return "30,41,59"
      case "sideLine"
         return "51,65,85"
      case "sideInk"
         return "203,213,225"
      case "code"
         return "15,23,42"
      case "codeInk"
         return "226,232,240"
      case "indigo"
         return "79,70,229"
      case "violet"
         return "124,58,237"
      case "teal"
         return "13,148,136"
      case "sky"
         return "2,132,199"
      case "amber"
         return "217,119,6"
      case "rose"
         return "225,29,72"
      case "orange"
         return "234,88,12"
      case "emerald"
         return "5,150,105"
      case "pink"
         return "219,39,119"
      case "flame"
         return "255,139,0"
      case "ok"
         return "22,163,74"
      case "warn"
         return "180,83,9"
      case "bad"
         return "220,38,38"
   end switch
   return "15,23,42"
end hmColor

-- Each page's title, tagline, accent and icon
private function hmPageInfo pPage, pWhat
   local tInfo
   switch pPage
      case "home"
         if hmOnWeb() then
            put "Home|Welcome to OXT-Beyond, in your browser|indigo|house" into tInfo
         else
            put "Home|Welcome to OXT-Beyond|indigo|house" into tInfo
         end if
         break
      case "speak"
         put "Speak xTalk|Scripts read like English, and every line runs the moment it is typed.|violet|square-terminal" into tInfo
         break
      case "move"
         put "Make it move|A timer, a little maths, and the engine redraws at full speed.|orange|orbit" into tInfo
         break
      case "draw"
         put "Draw and dazzle|Gradients, shadows, glows, SVG and widgets, all drawn live.|teal|palette" into tInfo
         break
      case "web"
         if hmOnWeb() then
            put "The web is yours|A stack in a browser can speak, make QR codes, run JavaScript and open the web.|sky|globe" into tInfo
         else
            put "Beyond the card|A stack can speak, make QR codes, ask the computer about itself and open the web.|sky|globe" into tInfo
         end if
         break
      case "app"
         if hmOnWeb() then
            put "Your first app|Draw it, script it, run it, share it: all in this page.|emerald|rocket" into tInfo
         else
            put "Your first app|Draw it, script it, run it, share it: all in this window.|emerald|rocket" into tInfo
         end if
         break
   end switch
   set the itemDelimiter to "|"
   switch pWhat
      case "title"
         return item 1 of tInfo
      case "tagline"
         return item 2 of tInfo
      case "accent"
         return hmColor(item 3 of tInfo)
      case "icon"
         return item 4 of tInfo
   end switch
   return empty
end hmPageInfo

private function hmNavLabel pPage
   switch pPage
      case "home"
         return "Home"
      case "speak"
         return "Speak xTalk"
      case "move"
         return "Make it move"
      case "draw"
         return "Draw and dazzle"
      case "web"
         if hmOnWeb() then
            return "The web is yours"
         end if
         return "Beyond the card"
      case "app"
         return "Your first app"
   end switch
end hmNavLabel

-- pFrom mixed with pTo: 0 is pFrom, 1 is pTo
private function hmMix pFrom, pTo, pAmount
   local tOut, tItem
   if pAmount <= 0 then
      return pFrom
   end if
   if pAmount >= 1 then
      return pTo
   end if
   repeat with tItem = 1 to 3
      put round(item tItem of pFrom + (item tItem of pTo - item tItem of pFrom) * pAmount) into item tItem of tOut
   end repeat
   return tOut
end hmMix

private function hmHex pColor
   return "#" & format("%02x%02x%02x", item 1 of pColor, item 2 of pColor, item 3 of pColor)
end hmHex

-- A colour from its hue (0 to 360), saturation and lightness (0 to 1)
private function hmHue pHue, pSat, pLight
   local tH, tC, tX, tM, tR, tG, tB
   put pHue mod 360 into tH
   if tH < 0 then
      add 360 to tH
   end if
   put (1 - abs(2 * pLight - 1)) * pSat into tC
   put tC * (1 - abs((tH / 60) mod 2 - 1)) into tX
   put pLight - tC / 2 into tM
   switch trunc(tH / 60)
      case 0
         put tC into tR
         put tX into tG
         put 0 into tB
         break
      case 1
         put tX into tR
         put tC into tG
         put 0 into tB
         break
      case 2
         put 0 into tR
         put tC into tG
         put tX into tB
         break
      case 3
         put 0 into tR
         put tX into tG
         put tC into tB
         break
      case 4
         put tX into tR
         put 0 into tG
         put tC into tB
         break
      default
         put tC into tR
         put 0 into tG
         put tX into tB
   end switch
   return round((tR + tM) * 255) & "," & round((tG + tM) * 255) & "," & round((tB + tM) * 255)
end hmHue

-- Slow at the end, as things in the world come to rest
private function hmEase pT
   if pT <= 0 then
      return 0
   end if
   if pT >= 1 then
      return 1
   end if
   return 1 - (1 - pT) ^ 3
end hmEase

################################################################################
#
# Building blocks
#

private function hmBox pName, pRect, pColor, pRadius, pGroup
   local tObj
   if pGroup is empty then
      create graphic pName
   else
      create graphic pName in group pGroup
   end if
   put it into tObj
   if pRadius is empty or pRadius is 0 then
      set the style of tObj to "rectangle"
   else
      set the style of tObj to "roundrect"
      set the roundRadius of tObj to pRadius
   end if
   set the lineSize of tObj to 0
   set the antialiased of tObj to true
   if pColor is empty then
      set the opaque of tObj to false
   else
      set the opaque of tObj to true
      set the backgroundColor of tObj to pColor
   end if
   set the rect of tObj to pRect
   return tObj
end hmBox

private function hmOval pName, pRect, pColor, pGroup
   local tObj
   put hmBox(pName, pRect, pColor, 0, pGroup) into tObj
   set the style of tObj to "oval"
   return tObj
end hmOval

private command hmBorder pObj, pColor
   set the lineSize of pObj to 1
   set the foregroundColor of pObj to pColor
end hmBorder

private function hmLabel pName, pRect, pText, pSize, pColor, pGroup, pAlign
   local tObj
   if pGroup is empty then
      create field pName
   else
      create field pName in group pGroup
   end if
   put it into tObj
   set the lockText of tObj to true
   set the traversalOn of tObj to false
   set the autoHilite of tObj to false
   set the opaque of tObj to false
   set the showBorder of tObj to false
   set the showFocusBorder of tObj to false
   -- (a field clips its text to its rect, and the default font's tallest
   -- letters reach above a line's top: a top margin keeps them whole, and
   -- the rect moves up by as much, so the text stays where pRect puts it)
   set the margins of tObj to "0," & kTextInset & ",0,0"
   set the dontWrap of tObj to false
   set the textSize of tObj to pSize
   set the textColor of tObj to pColor
   if pAlign is not empty then
      set the textAlign of tObj to pAlign
   end if
   set the rect of tObj to item 1 of pRect, item 2 of pRect - kTextInset, item 3 of pRect, item 4 of pRect
   set the text of tObj to pText
   return tObj
end hmLabel

-- A field the user types in, without a border of its own: it sits on a
-- rounded box
private function hmInput pName, pRect, pText, pSize, pGroup
   local tObj
   put hmLabel(pName, pRect, pText, pSize, hmColor("ink"), pGroup) into tObj
   -- (a left margin too, or the caret at the start hides the first letter's edge)
   set the margins of tObj to "4," & kTextInset & ",4,0"
   set the left of tObj to item 1 of pRect - 4
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the autoTab of tObj to false
   return tObj
end hmInput

-- A code panel's text: the code font, a fixed line height
private function hmCodeField pName, pRect, pSize, pLineHeight, pGroup
   local tObj
   put hmLabel(pName, pRect, empty, pSize, hmColor("codeInk"), pGroup) into tObj
   if hmCodeFont() is not empty then
      set the textFont of tObj to hmCodeFont()
   end if
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to pLineHeight
   return tObj
end hmCodeField

private function hmGroup pName, pRect, pGroup
   local tObj
   if pGroup is empty then
      create group pName
   else
      create group pName in group pGroup
   end if
   put it into tObj
   set the margins of tObj to 0
   set the showBorder of tObj to false
   set the lockLoc of tObj to true
   set the rect of tObj to pRect
   return tObj
end hmGroup

-- An icon: Lucide's 24 by 24 drawing, stroked in a colour
private function hmIcon pName, pIcon, pColor, pRect, pGroup
   local tObj
   if pGroup is empty then
      create image pName
   else
      create image pName in group pGroup
   end if
   put it into tObj
   hmIconInk tObj, pIcon, pColor
   set the lockLoc of tObj to true
   set the rect of tObj to pRect
   return tObj
end hmIcon

private command hmIconInk pObj, pIcon, pColor
   local tHex, tSvg
   put hmHex(pColor) into tHex
   put "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" & tHex & \
         "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>" & \
         hmIconPaths(pIcon) & "</svg>" into tSvg
   replace "currentColor" with tHex in tSvg
   set the text of pObj to drawingSvgCompile(tSvg)
end hmIconInk

-- An image of a drawing
private function hmDrawing pName, pSvg, pRect, pGroup
   local tObj
   if pGroup is empty then
      create image pName
   else
      create image pName in group pGroup
   end if
   put it into tObj
   set the text of tObj to drawingSvgCompile(pSvg)
   set the lockLoc of tObj to true
   set the rect of tObj to pRect
   return tObj
end hmDrawing

-- A linear gradient through pColors ("r,g,b|r,g,b|..."), from pFrom to pTo
private command hmGradient pObj, pColors, pFrom, pTo
   local tRamp, tCount, tIndex
   set the itemDelimiter to "|"
   put the number of items of pColors into tCount
   repeat with tIndex = 1 to tCount
      put format("%.3f", (tIndex - 1) / (tCount - 1)) & "," & item tIndex of pColors & return after tRamp
   end repeat
   set the itemDelimiter to comma
   delete the last char of tRamp
   set the fillGradient["type"] of pObj to "linear"
   set the fillGradient["ramp"] of pObj to tRamp
   hmGradientPoints pObj, pFrom, pTo
end hmGradient

private command hmGradientPoints pObj, pFrom, pTo
   set the fillGradient["from"] of pObj to pFrom
   set the fillGradient["to"] of pObj to pTo
   set the fillGradient["via"] of pObj to \
         (item 1 of pFrom - (item 2 of pTo - item 2 of pFrom)) & "," & \
         (item 2 of pFrom + (item 1 of pTo - item 1 of pFrom))
end hmGradientPoints

-- A soft round light: pColor in the middle, fading to nothing
private command hmGlowFill pObj, pColor, pAlpha
   set the fillGradient["type"] of pObj to "radial"
   set the fillGradient["ramp"] of pObj to "0.000," & pColor & "," & pAlpha & return & \
         "0.550," & pColor & "," & round(pAlpha / 3) & return & "1.000," & pColor & ",0"
   hmGlowCentre pObj
end hmGlowFill

private command hmGlowCentre pObj
   local tLoc, tRadius
   put the loc of pObj into tLoc
   put the width of pObj div 2 into tRadius
   set the fillGradient["from"] of pObj to tLoc
   set the fillGradient["to"] of pObj to (item 1 of tLoc + tRadius) & "," & item 2 of tLoc
   set the fillGradient["via"] of pObj to item 1 of tLoc & "," & (item 2 of tLoc + tRadius)
end hmGlowCentre

private command hmShadow pObj, pSize, pDistance, pOpacity
   set the dropShadow["color"] of pObj to "15,23,42"
   set the dropShadow["blendMode"] of pObj to "normal"
   set the dropShadow["angle"] of pObj to 90
   set the dropShadow["size"] of pObj to pSize
   set the dropShadow["distance"] of pObj to pDistance
   set the dropShadow["opacity"] of pObj to pOpacity
end hmShadow

private command hmGlow pObj, pColor, pSize, pOpacity
   set the outerGlow["color"] of pObj to pColor
   set the outerGlow["blendMode"] of pObj to "normal"
   set the outerGlow["size"] of pObj to pSize
   set the outerGlow["opacity"] of pObj to pOpacity
end hmGlow

-- A group clips what it holds to a rectangle; these four corners, in the
-- colour behind it, round the rectangle off. Each reaches 2 pixels past
-- the rectangle, where the group clips it, so that no edge of it shows.
private command hmCorners pPrefix, pRect, pRadius, pColor, pGroup
   local tCorner, tX, tY, tSx, tSy, tCx, tCy, tStart, tPoints, tStep, tAngle, tPx, tPy, tObj
   repeat with tCorner = 1 to 4
      switch tCorner
         case 1
            put item 1 of pRect into tX
            put item 2 of pRect into tY
            put -1 into tSx
            put -1 into tSy
            put 180 into tStart
            break
         case 2
            put item 3 of pRect into tX
            put item 2 of pRect into tY
            put 1 into tSx
            put -1 into tSy
            put 270 into tStart
            break
         case 3
            put item 3 of pRect into tX
            put item 4 of pRect into tY
            put 1 into tSx
            put 1 into tSy
            put 0 into tStart
            break
         default
            put item 1 of pRect into tX
            put item 4 of pRect into tY
            put -1 into tSx
            put 1 into tSy
            put 90 into tStart
      end switch
      put tX - tSx * pRadius into tCx
      put tY - tSy * pRadius into tCy
      put (tX + 2 * tSx) & "," & (tY + 2 * tSy) into tPoints
      repeat with tStep = 0 to 12
         put (tStart + tStep * 90 / 12) * pi / 180 into tAngle
         put round(tCx + pRadius * cos(tAngle)) into tPx
         put round(tCy + pRadius * sin(tAngle)) into tPy
         -- (the arc's two ends are on the rectangle: the polygon goes out
         -- past it before the first and after the last)
         if tStep is 0 then
            put return & hmPastEdge(tPx, tPy, tX, tSx, tSy) after tPoints
         end if
         put return & tPx & "," & tPy after tPoints
         if tStep is 12 then
            put return & hmPastEdge(tPx, tPy, tX, tSx, tSy) after tPoints
         end if
      end repeat
      put return & (tX + 2 * tSx) & "," & (tY + 2 * tSy) after tPoints
      put hmBox(pPrefix & tCorner, pRect, pColor, 0, pGroup) into tObj
      set the style of tObj to "polygon"
      set the points of tObj to tPoints
   end repeat
end hmCorners

-- A point of a corner's arc that is on the rectangle's edge, 2 pixels out
private function hmPastEdge pX, pY, pEdgeX, pSx, pSy
   if pX is pEdgeX then
      return (pX + 2 * pSx) & "," & pY
   end if
   return pX & "," & (pY + 2 * pSy)
end hmPastEdge

-- A four-pointed sparkle
private function hmSparklePoints pX, pY, pSize
   local tPoints, tStep, tAngle, tRadius
   repeat with tStep = 0 to 8
      put tStep * pi / 4 - pi / 2 into tAngle
      if tStep mod 2 is 0 then
         put pSize into tRadius
      else
         put pSize * 0.28 into tRadius
      end if
      put round(pX + tRadius * cos(tAngle)) & "," & round(pY + tRadius * sin(tAngle)) & return after tPoints
   end repeat
   delete the last char of tPoints
   return tPoints
end hmSparklePoints

-- A star of pPoints points, turned by pTurn radians
private function hmStarPoints pX, pY, pOuter, pInner, pPoints, pTurn
   local tPoints, tStep, tAngle, tRadius
   repeat with tStep = 0 to pPoints * 2
      put pTurn + tStep * pi / pPoints - pi / 2 into tAngle
      if tStep mod 2 is 0 then
         put pOuter into tRadius
      else
         put pInner into tRadius
      end if
      put round(pX + tRadius * cos(tAngle)) & "," & round(pY + tRadius * sin(tAngle)) & return after tPoints
   end repeat
   delete the last char of tPoints
   return tPoints
end hmStarPoints

-- The font code is shown in: Source Code Pro, which the IDE carries for
-- its Script Editor, or Droid Sans Mono, or else the default font
private function hmCodeFont
   local tError
   if sFont is empty then
      put "-" into sFont
      if "Source Code Pro" is not among the lines of the fontNames then
         try
            start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
         catch tError
         end try
      end if
      if "Source Code Pro" is among the lines of the fontNames then
         put "Source Code Pro" into sFont
      else
         -- (the web engine cannot load Source Code Pro's files, and it can
         -- load Droid Sans Mono, which the Dictionary's viewer carries)
         try
            start using font file (revIDESpecialFolderPath("IDE") & \
                  "/Documentation/html_viewer/resources/data/api/DroidSansMono.ttf")
         catch tError
         end try
         if "Droid Sans Mono" is among the lines of the fontNames then
            put "Droid Sans Mono" into sFont
         end if
      end if
   end if
   if sFont is "-" then
      return empty
   end if
   return sFont
end hmCodeFont

################################################################################
#
# Things that light up and do something
#

-- Makes a group a thing the pointer lights up and a click sets off.
-- pLook holds how it looks at rest and lit, as "bg", "bg0", "bg1",
-- "line0", "line1", "blend0", "blend1", "label", "ink0", "ink1", "lift",
-- "shadow" and "enter" (its turn to slide in when its page opens).
private command hmLive pName, pPage, pAction, pLook
   local tKey
   repeat for each key tKey in pLook
      put pLook[tKey] into sCfg[pName][tKey]
   end repeat
   put pAction into sCfg[pName]["action"]
   put pPage into sCfg[pName]["page"]
   put the top of group pName into sCfg[pName]["top"]
   put 0 into sHoverAmt[pName]
   put 1 into sEnterAmt[pName]
   if sLiveList[pPage] is empty then
      put pName into sLiveList[pPage]
   else
      put return & pName after sLiveList[pPage]
   end if
end hmLive

-- Draws a lit thing as it is: pName's hover and slide-in amounts
private command hmApply pName
   local tH, tE, tBg, tTop, tLabel
   put hmEase(sHoverAmt[pName]) into tH
   put hmEase(sEnterAmt[pName]) into tE
   put sCfg[pName]["bg"] into tBg
   if tBg is not empty then
      if sCfg[pName]["bg0"] is not empty then
         set the backgroundColor of graphic tBg to hmMix(sCfg[pName]["bg0"], sCfg[pName]["bg1"], tH)
      end if
      if sCfg[pName]["line0"] is not empty then
         set the foregroundColor of graphic tBg to hmMix(sCfg[pName]["line0"], sCfg[pName]["line1"], tH)
      end if
      if sCfg[pName]["blend0"] is not empty then
         set the blendLevel of graphic tBg to round(sCfg[pName]["blend0"] + (sCfg[pName]["blend1"] - sCfg[pName]["blend0"]) * tH)
      end if
      if sCfg[pName]["shadow"] is true then
         set the dropShadow["size"] of graphic tBg to round(10 + 14 * tH)
         set the dropShadow["distance"] of graphic tBg to round(2 + 6 * tH)
         set the dropShadow["opacity"] of graphic tBg to round(26 + 34 * tH)
      end if
   end if
   put sCfg[pName]["label"] into tLabel
   if tLabel is not empty and sCfg[pName]["ink0"] is not empty then
      set the textColor of field tLabel to hmMix(sCfg[pName]["ink0"], sCfg[pName]["ink1"], tH)
   end if
   if sCfg[pName]["lift"] is not empty or sCfg[pName]["enter"] is not empty then
      put sCfg[pName]["top"] into tTop
      if sCfg[pName]["enter"] is not empty then
         add round(16 * (1 - tE)) to tTop
         set the blendLevel of group pName to round(100 * (1 - tE))
      end if
      if sCfg[pName]["lift"] is not empty then
         subtract round(sCfg[pName]["lift"] * tH) from tTop
      end if
      set the top of group pName to tTop
   end if
end hmApply

-- The lit thing a control belongs to, if any
private function hmLiveOf pObj
   local tName
   repeat 8 times
      if pObj is empty or word 1 of pObj is "card" or word 1 of pObj is "stack" then
         return empty
      end if
      if word 1 of pObj is "group" then
         put the short name of pObj into tName
         if sCfg[tName]["action"] is not empty then
            return tName
         end if
      end if
      put the long owner of pObj into pObj
   end repeat
   return empty
end hmLiveOf

private command hmHoverOn pName
   if pName is sHover then
      exit hmHoverOn
   end if
   put pName into sHover
   if pName is empty then
      unlock cursor
   else
      lock cursor
      set the cursor to hand
   end if
end hmHoverOn

on mouseMove
   local tName
   put hmLiveOf(the long id of the target) into tName
   hmHoverOn tName
   pass mouseMove
end mouseMove

on mouseDown pButton
   if pButton is 1 and sPage is "move" and the short name of the target begins with "mv" and \
         hmLiveOf(the long id of the target) is empty and \
         the mouseLoc is within hmStageRect() then
      hmMoveClick the mouseH - sOX, the mouseV - sOY
   end if
   pass mouseDown
end mouseDown

on mouseUp pButton
   local tName
   put hmLiveOf(the long id of the target) into tName
   if pButton is 1 and tName is not empty then
      hmDo sCfg[tName]["action"]
   else
      pass mouseUp
   end if
end mouseUp

on arrowKey pKey
   -- (a field of Home's that has the focus keeps its arrow keys; a field
   -- in another window, the Message Box's say, does not stop paging)
   if word 1 of the name of the target is "field" then
      pass arrowKey
   end if
   switch pKey
      case "left"
         hmGoPage "prev"
         break
      case "right"
         hmGoPage "next"
         break
      default
         pass arrowKey
   end switch
end arrowKey

on returnInField
   switch the short name of the target
      case "spkInput"
         hmSpeakTry
         break
      case "webSay"
         hmWebSay
         break
      case "webQRText"
         hmWebQR
         break
      default
         pass returnInField
   end switch
end returnInField

on enterInField
   returnInField
end enterInField

on textChanged
   if the short name of the target is "webQRText" then
      put the milliseconds + 350 into sWeb["qrDue"]
   end if
   pass textChanged
end textChanged

-- What a lit thing does
private command hmDo pAction
   local tArg
   put word 2 to -1 of pAction into tArg
   switch word 1 of pAction
      case "page"
         hmGoPage tArg
         break
      case "ide"
         hmIde tArg
         break
      case "startup"
         hmToggleStartup
         break
      case "run"
         hmSpeakTry
         break
      case "chip"
         hmSpeakChip tArg
         break
      case "mode"
         hmMoveMode tArg
         break
      case "remix"
         hmRemix
         break
      case "fx"
         hmDrawFx tArg
         break
      case "web"
         hmWebDo tArg
         break
      case "make"
         hmMakeFirstApp
         break
   end switch
end hmDo

-- The IDE's own commands, as its menus and toolbar run them
private command hmIde pWhat
   local tError
   try
      switch pWhat
         case "new"
            revIDEActionNewMainstack "default"
            break
         case "open"
            revIDEActionOpenStack
            break
         case "lessons"
            send "tOpenNewGuides" to stack "revMenubar"
            break
         case "examples"
            send "tOpenDemos" to stack "revMenubar"
            break
         case "dictionary"
            send "tNewDictionaryDisplay" to stack "revMenubar"
            break
      end switch
   catch tError
      hmStatus "That could not open:" && hmErrorText(tError), "bad"
   end try
end hmIde

-- The status line, at the foot of the page: ok, warn, bad, or a note
private command hmStatus pText, pKind
   local tColor
   switch pKind
      case "ok"
      case "warn"
      case "bad"
         put hmColor(pKind) into tColor
         break
      default
         put hmColor("soft") into tColor
   end switch
   set the textColor of field "hdrStatus" of me to tColor
   put pText into field "hdrStatus" of me
   put sNow + 9000 into sTipAt
end hmStatus

-- An error, in words: the engine's message for the first error it lists
private function hmErrorText pError
   local tLine, tNumber, tText, tColon
   -- (an error Home throws itself is already words)
   if item 1 of line 1 of pError is not an integer and line 1 of pError is not empty then
      return line 1 of pError
   end if
   repeat for each line tLine in pError
      put item 1 of tLine into tNumber
      if tNumber is an integer and tNumber > 0 then
         put line tNumber of the scriptExecutionErrors into tText
         if tText is not empty then
            put offset(":", tText) into tColon
            if tColon > 0 then
               delete char 1 to tColon of tText
               put word 1 to -1 of tText into tText
            end if
            if tText is not empty then
               return tText
            end if
         end if
      end if
   end repeat
   return "that is not a line of xTalk yet"
end hmErrorText

################################################################################
#
# Show at startup
#

-- The web IDE opens Home at startup unless the user turned it off
-- (cWebHomeAtStartup); the desktop IDE only when the user turned it on
-- (cHomeAtStartup), as it opened nothing at startup before Home
private function hmShowAtStartup
   local tValue, tError
   try
      if hmOnWeb() then
         put revIDEGetPreference("cWebHomeAtStartup") is not false into tValue
      else
         put revIDEGetPreference("cHomeAtStartup") is true into tValue
      end if
   catch tError
      put hmOnWeb() into tValue
   end try
   return tValue
end hmShowAtStartup

private command hmToggleStartup
   local tError
   try
      if hmOnWeb() then
         revIDESetPreference "cWebHomeAtStartup", not hmShowAtStartup()
      else
         revIDESetPreference "cHomeAtStartup", not hmShowAtStartup()
      end if
   catch tError
   end try
   hmSyncStartup
   if hmShowAtStartup() and hmOnWeb() then
      hmStatus "Home will open each time the web IDE starts.", "ok"
   else if hmShowAtStartup() then
      hmStatus "Home will open each time OXT-Beyond starts.", "ok"
   else
      hmStatus "Home will not open at startup: Help > Welcome to OXT-Beyond brings it back.", "note"
   end if
end hmToggleStartup

private command hmSyncStartup
   if hmShowAtStartup() then
      set the backgroundColor of graphic "startTrack" to hmColor("emerald")
      set the left of graphic "startKnob" to 36
   else
      set the backgroundColor of graphic "startTrack" to hmColor("sideLine")
      set the left of graphic "startKnob" to 22
   end if
end hmSyncStartup

################################################################################
#
# Building Home
#

private command hmBuild
   local tSaved, tPage
   if there is a group "pg_home" of me then
      exit hmBuild
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   set the label of me to "Welcome to OXT-Beyond"
   set the destroyStack of me to true
   set the rect of me to 0,0,kWidth,kHeight
   -- (larger, the pages stay their size, in the middle: hmLayout)
   set the resizable of me to true
   set the minWidth of me to kWidth
   set the minHeight of me to kHeight
   put empty into sLaidW
   set the backgroundColor of me to hmColor("bg")
   -- (the desktop's recent stacks are links: hmRecentStacks)
   set the linkColor of me to hmColor("emerald")
   set the linkHiliteColor of me to hmColor("teal")
   set the linkVisitedColor of me to hmColor("emerald")
   set the underlineLinks of me to false
   put empty into sCfg
   put empty into sLiveList
   hmBuildSide
   repeat for each item tPage in kPages
      get hmGroup("pg_" & tPage, kSide & ",0," & kWidth & "," & kHeight, empty)
      hide group ("pg_" & tPage)
   end repeat
   hmBuildHome
   hmBuildSpeak
   hmBuildMove
   hmBuildDraw
   hmBuildWeb
   hmBuildApp
   hmBuildHeader
   unlock messages
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end hmBuild

-- A button: a rounded box with an icon and a label, lit as its style says
--    primary   filled with the accent
--    ghost     white, with a border
--    dark      for the sidebar and the dark panels
--    chip      a small tinted box, for a line of code
--    light     white on a coloured panel
private function hmButton pName, pLeft, pTop, pHeight, pLabel, pIcon, pStyle, pAccent, pGroup, pAction, pMinWidth, pPage
   local tSize, tLabelWidth, tWidth, tIconSize, tGap, tX, tMid, tObj, tLook, tInk, tIconInk, tLabel, tPad, tTop
   put 14 into tSize
   put 16 into tIconSize
   put 16 into tPad
   if pStyle is "chip" then
      put 12 into tSize
      put 12 into tPad
   end if
   put hmGroup(pName, hmR(pLeft, pTop, pLeft + 10, pTop + pHeight), pGroup) into tObj
   put hmBox(pName & "_bg", hmR(pLeft, pTop, pLeft + 10, pTop + pHeight), empty, pHeight, pName) into tObj
   put hmLabel(pName & "_label", hmR(pLeft, pTop, pLeft + 600, pTop + pHeight), pLabel, tSize, "0,0,0", pName) into tLabel
   set the dontWrap of tLabel to true
   if pStyle is "chip" and hmCodeFont() is not empty then
      set the textFont of tLabel to hmCodeFont()
   end if
   put the formattedWidth of tLabel into tLabelWidth
   if pIcon is empty then
      put 0 into tGap
      put 0 into tIconSize
   else
      put 8 into tGap
   end if
   put max(pMinWidth, tLabelWidth + tIconSize + tGap + 2 * tPad) into tWidth
   set the rect of group pName to pLeft, pTop, pLeft + tWidth, pTop + pHeight
   set the rect of graphic (pName & "_bg") to pLeft, pTop, pLeft + tWidth, pTop + pHeight
   put pLeft + (tWidth - tLabelWidth - tIconSize - tGap) div 2 into tX
   put pTop + pHeight div 2 into tMid
   switch pStyle
      case "primary"
         put pAccent into tLook["bg0"]
         put hmMix(pAccent, "255,255,255", 0.16) into tLook["bg1"]
         put "255,255,255" into tInk
         put tInk into tIconInk
         break
      case "ghost"
         put "255,255,255" into tLook["bg0"]
         put hmMix("255,255,255", pAccent, 0.08) into tLook["bg1"]
         put hmColor("line") into tLook["line0"]
         put pAccent into tLook["line1"]
         put hmColor("ink") into tLook["ink0"]
         put hmMix(pAccent, hmColor("ink"), 0.25) into tLook["ink1"]
         put tLook["ink0"] into tInk
         put pAccent into tIconInk
         break
      case "dark"
         put hmColor("side2") into tLook["bg0"]
         put hmColor("sideLine") into tLook["bg1"]
         put hmColor("sideLine") into tLook["line0"]
         put "100,116,139" into tLook["line1"]
         put hmColor("sideInk") into tLook["ink0"]
         put "255,255,255" into tLook["ink1"]
         put tLook["ink0"] into tInk
         put tInk into tIconInk
         break
      case "chip"
         put hmMix("255,255,255", pAccent, 0.09) into tLook["bg0"]
         put hmMix("255,255,255", pAccent, 0.2) into tLook["bg1"]
         put hmMix(pAccent, hmColor("ink"), 0.3) into tInk
         put tInk into tIconInk
         break
      case "light"
         put "255,255,255" into tLook["bg0"]
         put hmMix("255,255,255", pAccent, 0.14) into tLook["bg1"]
         put hmMix(pAccent, hmColor("ink"), 0.2) into tInk
         put pAccent into tIconInk
         break
   end switch
   set the backgroundColor of graphic (pName & "_bg") to tLook["bg0"]
   set the opaque of graphic (pName & "_bg") to true
   if tLook["line0"] is not empty then
      hmBorder the long id of graphic (pName & "_bg"), tLook["line0"]
   end if
   if pIcon is not empty then
      get hmIcon(pName & "_icon", pIcon, tIconInk, tX & "," & (tMid - 8) & "," & (tX + 16) & "," & (tMid + 8), pName)
   end if
   set the textColor of tLabel to tInk
   put tMid - (the formattedHeight of tLabel + kTextInset) div 2 into tTop
   -- (taller than its text by a few pixels, so that no descender is cut)
   set the rect of tLabel to tX + tIconSize + tGap, tTop, \
         tX + tIconSize + tGap + tLabelWidth + 4, tTop + the formattedHeight of tLabel + kTextInset + 4
   put pName & "_bg" into tLook["bg"]
   put pName & "_label" into tLook["label"]
   if pPage is empty then
      put "side" into pPage
   end if
   hmLive pName, pPage, pAction, tLook
   return tWidth
end hmButton

-- The rect of a control is set from four numbers in hmButton, so hmGroup
-- and hmBox take a rect as items: these wrappers keep the calls short
private function hmR pLeft, pTop, pRight, pBottom
   return pLeft & "," & pTop & "," & pRight & "," & pBottom
end hmR

-- A group clips what it holds to its rect, a shadow or a glow included:
-- this widens group pName past its box by pPad (twice that below, where a
-- shadow falls), so the effect shows whole. Setting a group's rect moves
-- its controls with its top left, so they are moved back.
private command hmRoom pName, pPad
   local tRect, tIndex, tLoc
   put the rect of graphic (pName & "_bg") of group pName into tRect
   set the rect of group pName to item 1 of tRect - pPad, item 2 of tRect - pPad, \
         item 3 of tRect + pPad, item 4 of tRect + 2 * pPad
   repeat with tIndex = 1 to the number of controls of group pName
      put the loc of control tIndex of group pName into tLoc
      set the loc of control tIndex of group pName to item 1 of tLoc + pPad, item 2 of tLoc + pPad
   end repeat
   if sCfg[pName]["top"] is not empty then
      put the top of group pName into sCfg[pName]["top"]
   end if
end hmRoom

################################################################################
#
# The sidebar
#

private command hmBuildSide
   local tObj, tY, tPage, tLook
   put hmBox("sideBg", "0,0,200,640", hmColor("side"), 0, empty) into tObj
   hmGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", "0,640"
   -- The mark: the toolbar's stack icon on the web IDE's colours
   put hmBox("sideMark", "20,22,56,58", hmColor("flame"), 22, empty) into tObj
   hmGradient tObj, "255,139,0|236,72,153", "20,22", "56,58"
   hmGlow tObj, "255,139,0", 16, 110
   get hmIcon("sideMarkIcon", "layers", "255,255,255", "28,30,48,50", empty)
   get hmLabel("sideTitle", "66,21,200,45", "OXT-Beyond", 19, "255,255,255", empty)
   if hmOnWeb() then
      get hmLabel("sideSub", "66,45,200,61", "Home, in your browser", 11, hmColor("muted"), empty)
   else
      get hmLabel("sideSub", "66,45,200,61", "Home", 11, hmColor("muted"), empty)
   end if

   put hmBox("navHi", "10,84,190,118", hmColor("side2"), 18, empty) into tObj
   hmBorder tObj, hmColor("sideLine")
   put hmBox("navBar", "10,92,14,110", hmColor("indigo"), 4, empty) into tObj
   put 84 into tY
   put tY into sNavY
   repeat for each item tPage in kPages
      hmNavItem "nav_" & tPage, tY, 34, hmNavLabel(tPage), hmPageInfo(tPage, "icon"), "page" && tPage, 14
      add 38 to tY
   end repeat

   get hmLabel("sideExplore", "22,330,190,344", "EXPLORE", 10, "100,116,139", empty)
   hmNavItem "nav_lessons", 348, 30, "Lessons", "graduation-cap", "ide lessons", 13
   hmNavItem "nav_examples", 380, 30, "Examples", "layers", "ide examples", 13
   hmNavItem "nav_dictionary", 412, 30, "Dictionary", "book-open-text", "ide dictionary", 13

   -- Show at startup: a switch
   get hmGroup("startup", "14,470,190,500", empty)
   put hmBox("startup_bg", "14,470,190,500", hmColor("side2"), 14, "startup") into tObj
   put hmBox("startTrack", "20,477,52,493", hmColor("emerald"), 16, "startup") into tObj
   put hmOval("startKnob", "36,479,48,491", "255,255,255", "startup") into tObj
   get hmLabel("startup_label", "60,477,188,495", "Show Home at startup", 12, hmColor("sideInk"), "startup")
   put "startup_bg" into tLook["bg"]
   put 100 into tLook["blend0"]
   put 40 into tLook["blend1"]
   put "startup_label" into tLook["label"]
   put hmColor("sideInk") into tLook["ink0"]
   put "255,255,255" into tLook["ink1"]
   hmLive "startup", "side", "startup", tLook
   hmSyncStartup

   get hmButton("back", 14, 510, 32, "Back", "chevron-left", "dark", empty, empty, "page prev", 82)
   get hmButton("next", 104, 510, 32, "Next", "chevron-right", "dark", empty, empty, "page next", 82)
   get hmLabel("navCount", "0,556,200,572", "Page 1 of 6", 12, hmColor("muted"), empty, "center")
   get hmLabel("navKeys", "0,573,200,589", "or use the arrow keys", 11, "100,116,139", empty, "center")
end hmBuildSide

private command hmNavItem pName, pTop, pHeight, pLabel, pIcon, pAction, pSize
   local tObj, tLook, tMid
   put pTop + pHeight div 2 into tMid
   get hmGroup(pName, hmR(10, pTop, 190, pTop + pHeight), empty)
   put hmBox(pName & "_bg", hmR(10, pTop, 190, pTop + pHeight), hmColor("side2"), 18, pName) into tObj
   set the blendLevel of tObj to 100
   get hmIcon(pName & "_icon", pIcon, hmColor("sideInk"), hmR(24, tMid - 8, 40, tMid + 8), pName)
   put hmLabel(pName & "_label", hmR(50, tMid - 10, 188, tMid + 10), pLabel, pSize, hmColor("sideInk"), pName) into tObj
   set the dontWrap of tObj to true
   set the top of tObj to tMid - (the formattedHeight of tObj + kTextInset) div 2
   put pName & "_bg" into tLook["bg"]
   put 100 into tLook["blend0"]
   put 45 into tLook["blend1"]
   put pName & "_label" into tLook["label"]
   put hmColor("sideInk") into tLook["ink0"]
   put "255,255,255" into tLook["ink1"]
   hmLive pName, "side", pAction, tLook
end hmNavItem

################################################################################
#
# The header and the status line
#

private command hmBuildHeader
   local tObj
   get hmGroup("hdr", "200,0,1024,90", empty)
   get hmLabel("hdrTitle", "224,14,1000,50", empty, 26, hmColor("ink"), "hdr")
   get hmLabel("hdrTag", "224,52,1000,70", empty, 13, hmColor("soft"), "hdr")
   put hmBox("hdrLine", "224,76,280,79", hmColor("indigo"), 3, "hdr") into tObj
   get hmLabel("hdrStatus", "224,606,1000,624", empty, 12, hmColor("soft"), empty)
end hmBuildHeader

-- Moves to a page: next pushes left, back pushes right, a jump dissolves.
-- Only the content area moves; the sidebar stays put.
private command hmGoPage pWhere
   local tOld, tIndex, tCount, tEffect, tPage, tOther
   put sPage into tOld
   put the number of items of kPages into tCount
   put itemOffset(sPage, kPages) into tIndex
   switch pWhere
      case "next"
         put "push left" into tEffect
         put item (tIndex mod tCount) + 1 of kPages into tPage
         break
      case "prev"
         put "push right" into tEffect
         put item ((tIndex + tCount - 2) mod tCount) + 1 of kPages into tPage
         break
      default
         put "dissolve" into tEffect
         put pWhere into tPage
   end switch
   if tPage is empty or tPage is not among the items of kPages or tPage is tOld then
      exit hmGoPage
   end if
   if tOld is empty then
      -- (Home opening: the page shown when it last closed is put away)
      lock screen
      repeat for each item tOther in kPages
         hide group ("pg_" & tOther)
      end repeat
   else
      lock screen for visual effect in rect hmContentRect()
      hide group ("pg_" & tOld)
      hmPageStop tOld
   end if
   put tPage into sPage
   show group ("pg_" & tPage)
   hmSyncChrome
   hmPageStart tPage
   if tOld is empty then
      unlock screen
   else
      unlock screen with visual effect tEffect very fast
   end if
   put the milliseconds into sPageStart
   focus on nothing
end hmGoPage

-- The sidebar marks the page in front, and the header shows its title,
-- tagline and accent
private command hmSyncChrome
   local tAccent, tPage, tName
   put hmPageInfo(sPage, "accent") into tAccent
   if sPage is "home" then
      hide group "hdr"
   else
      show group "hdr"
      put hmPageInfo(sPage, "title") into field "hdrTitle"
      put hmPageInfo(sPage, "tagline") into field "hdrTag"
      set the backgroundColor of graphic "hdrLine" to tAccent
   end if
   set the backgroundColor of graphic "navBar" to tAccent
   hmGlow the long id of graphic "navBar", tAccent, 10, 160
   repeat for each item tPage in kPages
      put "nav_" & tPage into tName
      if tPage is sPage then
         put "255,255,255" into sCfg[tName]["ink0"]
         hmIconInk the long id of image (tName & "_icon"), hmPageInfo(tPage, "icon"), hmMix(tAccent, "255,255,255", 0.35)
         put the top of group tName into sNavTarget
      else
         put hmColor("sideInk") into sCfg[tName]["ink0"]
         hmIconInk the long id of image (tName & "_icon"), hmPageInfo(tPage, "icon"), hmColor("sideInk")
      end if
      hmApply tName
   end repeat
   put "Page" && itemOffset(sPage, kPages) && "of" && the number of items of kPages into field "navCount"
   put empty into field "hdrStatus"
   put 0 into sTipAt
end hmSyncChrome

private command hmPageStart pPage
   local tName
   repeat for each line tName in sLiveList[pPage]
      if sCfg[tName]["enter"] is not empty then
         put 0 into sEnterAmt[tName]
      end if
      put 0 into sHoverAmt[tName]
      hmApply tName
   end repeat
   switch pPage
      case "home"
         hmHomeStart
         break
      case "speak"
         hmSpeakStart
         break
      case "move"
         hmMoveStart
         break
      case "draw"
         hmDrawStart
         break
      case "web"
         hmWebStart
         break
      case "app"
         hmAppStart
         break
   end switch
end hmPageStart

private command hmPageStop pPage
   if pPage is "move" then
      hmMoveStop
   end if
end hmPageStop

################################################################################
#
# One frame
#

private command hmFrame
   local tName, tTarget, tChanged, tStep, tE
   -- frames a second, for the Move page
   add 1 to sFpsFrames
   if sNow - sFpsStart >= 1000 then
      put round(sFpsFrames * 1000 / (sNow - sFpsStart)) into sFps
      put 0 into sFpsFrames
      put sNow into sFpsStart
   end if
   -- The pointer has left Home
   if sHover is not empty and the mouseStack is not the short name of me then
      hmHoverOn empty
   end if
   -- The sidebar's highlight slides to the page in front
   if sNavTarget is not empty and abs(sNavY - sNavTarget) > 0.5 then
      put sNavY + (sNavTarget - sNavY) * min(1, sDt * 14) into sNavY
      set the top of graphic "navHi" to round(sNavY)
      set the top of graphic "navBar" to round(sNavY) + 8
   else if sNavTarget is not empty and sNavY is not sNavTarget then
      put sNavTarget into sNavY
      set the top of graphic "navHi" to sNavY
      set the top of graphic "navBar" to sNavY + 8
   end if
   -- Lit things light up, and a page's things slide in
   put sDt / 0.16 into tStep
   repeat for each line tName in sLiveList["side"] & return & sLiveList[sPage]
      if tName is empty then
         next repeat
      end if
      put false into tChanged
      if tName is sHover then
         put 1 into tTarget
      else
         put 0 into tTarget
      end if
      if sHoverAmt[tName] < tTarget then
         put min(tTarget, sHoverAmt[tName] + tStep) into sHoverAmt[tName]
         put true into tChanged
      else if sHoverAmt[tName] > tTarget then
         put max(tTarget, sHoverAmt[tName] - tStep) into sHoverAmt[tName]
         put true into tChanged
      end if
      if sEnterAmt[tName] < 1 then
         put (sNow - sPageStart - sCfg[tName]["enter"] * 55) / 420 into tE
         put max(0, min(1, tE)) into sEnterAmt[tName]
         put true into tChanged
      end if
      if tChanged then
         hmApply tName
      end if
   end repeat
   switch sPage
      case "home"
         hmHomeFrame
         break
      case "speak"
         hmSpeakFrame
         break
      case "move"
         hmMoveFrame
         break
      case "draw"
         hmDrawFrame
         break
      case "web"
         hmWebFrame
         break
      case "app"
         hmAppFrame
         break
   end switch
end hmFrame

################################################################################
#
# Code, in colour
#

-- htmlText for lines of xTalk: commands, the words between them, objects,
-- strings, numbers and comments each in their own colour
private function hmCodeHtml pText
   local tHtml, tLine
   repeat for each line tLine in pText
      put "<p>" & hmCodeLineHtml(tLine) & "</p>" after tHtml
   end repeat
   return tHtml
end hmCodeHtml

private function hmCodeLineHtml pLine
   local tOut, tPos, tLen, tChar, tStart, tWord, tNext
   put the number of chars of pLine into tLen
   put 1 into tPos
   repeat while tPos <= tLen
      put char tPos of pLine into tChar
      put tPos + 1 into tNext
      if tChar is quote then
         put tPos into tStart
         put tNext into tPos
         repeat while tPos <= tLen and char tPos of pLine is not quote
            add 1 to tPos
         end repeat
         put hmSpan(char tStart to tPos of pLine, "#fcd34d") after tOut
         add 1 to tPos
      else if tChar is "-" and char tNext of pLine is "-" then
         put hmSpan(char tPos to tLen of pLine, "#64748b") after tOut
         exit repeat
      else if hmIsWordChar(tChar) then
         put tPos into tStart
         repeat while tPos <= tLen and hmIsWordChar(char tPos of pLine)
            add 1 to tPos
         end repeat
         put char tStart to tPos - 1 of pLine into tWord
         put hmSpan(tWord, hmWordColor(tWord)) after tOut
      else
         put hmEscape(tChar) after tOut
         put tNext into tPos
      end if
   end repeat
   return tOut
end hmCodeLineHtml

private function hmIsWordChar pChar
   return pChar is not empty and pChar is in "abcdefghijklmnopqrstuvwxyz0123456789_"
end hmIsWordChar

private function hmWordColor pWord
   if pWord is a number then
      return "#fdba74"
   end if
   if pWord is among the items of "on,end,put,set,move,add,subtract,multiply,divide,send,repeat,if,then,else,answer,ask,create,go,show,hide,lock,unlock,sort,do,exit,pass,return,local,cancel,launch,revSpeak,function,command,next,beep,play" then
      return "#c4b5fd"
   end if
   if pWord is among the items of "the,of,to,into,in,with,without,waiting,and,or,not,is,for,each,until,while,times,by,after,before,from,at,any,mod,div" then
      return "#7dd3fc"
   end if
   if pWord is among the items of "field,graphic,button,card,stack,image,me,it,this,item,items,word,words,line,lines,char,chars,url,milliseconds,seconds,second" then
      return "#5eead4"
   end if
   return "#e2e8f0"
end hmWordColor

private function hmSpan pText, pColor
   return "<font color=" & quote & pColor & quote & ">" & hmEscape(pText) & "</font>"
end hmSpan

private function hmEscape pText
   replace "&" with "&amp;" in pText
   replace "<" with "&lt;" in pText
   replace ">" with "&gt;" in pText
   return pText
end hmEscape

################################################################################
#
# Home
#

private command hmBuildHome
   local tObj, tIndex, tX, tY, tPage, tColor, tColors, tSvg, tLook

   -- The hero: a living gradient, drifting lights and a stack of cards
   get hmGroup("hero", "224,20,1000,292", "pg_home")
   -- (larger than the group, which clips it: no edge of it shows)
   put hmBox("heroBg", "220,16,1004,296", hmColor("indigo"), 0, "hero") into tObj
   hmGradient tObj, "67,56,202|124,58,237|219,39,119|249,115,22", "224,20", "1000,292"
   put "255,255,255|251,146,60|56,189,248|244,114,182" into tColors
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put item tIndex of tColors into tColor
      put hmOval("heroOrb" & tIndex, "300,60,500,260", "255,255,255", "hero") into tObj
      hmGlowFill tObj, tColor, 150
   end repeat
   set the itemDelimiter to comma
   repeat with tIndex = 1 to 7
      put hmBox("heroSpark" & tIndex, "0,0,10,10", "255,255,255", 0, "hero") into tObj
      set the style of tObj to "polygon"
   end repeat
   hmHeroSparkles

   put hmBox("heroPillBg", "246,40,472,66", "255,255,255", 26, "hero") into tObj
   set the blendLevel of tObj to 78
   get hmIcon("heroPillIcon", "sparkles", "255,255,255", "257,46,271,60", "hero")
   if hmOnWeb() then
      put hmLabel("heroPill", "278,46,470,64", "The IDE, now in your browser", 12, "255,255,255", "hero") into tObj
   else
      put hmLabel("heroPill", "278,46,470,64", "Free, open and yours", 12, "255,255,255", "hero") into tObj
   end if
   -- (its words centred on the pill, and the pill as wide as they are,
   -- in whichever font the engine has)
   set the top of tObj to 53 - (the formattedHeight of tObj + kTextInset) div 2
   set the rect of graphic "heroPillBg" to 246, 40, 278 + the formattedWidth of tObj + 14, 66
   put hmLabel("heroTitle", "244,70,740,136", "OXT-Beyond", 54, "255,255,255", "hero") into tObj
   set the textStyle of tObj to "bold"
   if hmOnWeb() then
      get hmLabel("heroSub", "246,138,730,184", \
            "Make apps with an English-like language, right here in your browser." & return & \
            "Nothing to install, and every example on these pages is live.", 15, "238,242,255", "hero")
   else
      get hmLabel("heroSub", "246,138,730,184", \
            "Make desktop and web apps in an English-like language." & return & \
            "Every example on these pages is live: try them.", 15, "238,242,255", "hero")
   end if

   -- A Message Box that types
   put hmBox("heroTerm", "246,196,720,266", hmColor("code"), 16, "hero") into tObj
   set the blendLevel of tObj to 22
   get hmOval("heroDot1", "262,208,270,216", "248,113,113", "hero")
   get hmOval("heroDot2", "275,208,283,216", "251,191,36", "hero")
   get hmOval("heroDot3", "288,208,296,216", "52,211,153", "hero")
   get hmLabel("heroTermTitle", "304,205,700,219", "Message Box", 11, hmColor("muted"), "hero")
   put hmCodeField("heroCode", "262,228,712,252", 15, 22, "hero") into tObj
   set the dontWrap of tObj to true
   get hmBox("heroCaret", "262,230,264,250", hmColor("flame"), 0, "hero")

   -- A stack of cards, HyperCard's own picture of a stack
   put "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 240 210'><defs>" & \
         "<linearGradient id='orb' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#fb923c'/><stop offset='1' stop-color='#ec4899'/></linearGradient>" & \
         "<linearGradient id='bar' x1='0' y1='0' x2='1' y2='0'><stop offset='0' stop-color='#6366f1'/><stop offset='1' stop-color='#8b5cf6'/></linearGradient>" & \
         "</defs>" & \
         "<rect x='46' y='20' width='164' height='124' rx='16' fill='#ffffff' fill-opacity='0.16' transform='rotate(-11 128 82)'/>" & \
         "<rect x='38' y='32' width='170' height='128' rx='16' fill='#ffffff' fill-opacity='0.32' transform='rotate(-5 123 96)'/>" & \
         "<rect x='28' y='44' width='184' height='136' rx='16' fill='#ffffff'/>" & \
         "<path d='M28 60a16 16 0 0 1 16-16h152a16 16 0 0 1 16 16v10h-184z' fill='#eef2ff'/>" & \
         "<circle cx='44' cy='58' r='4' fill='#f87171'/><circle cx='56' cy='58' r='4' fill='#fbbf24'/><circle cx='68' cy='58' r='4' fill='#34d399'/>" & \
         "<rect x='44' y='86' width='78' height='24' rx='12' fill='url(#bar)'/>" & \
         "<rect x='58' y='96' width='50' height='4' rx='2' fill='#ffffff'/>" & \
         "<circle cx='170' cy='102' r='24' fill='url(#orb)'/>" & \
         "<rect x='44' y='124' width='96' height='7' rx='3.5' fill='#cbd5e1'/>" & \
         "<rect x='44' y='139' width='120' height='7' rx='3.5' fill='#e2e8f0'/>" & \
         "<rect x='44' y='154' width='76' height='7' rx='3.5' fill='#e2e8f0'/>" & \
         "<rect x='150' y='146' width='8' height='18' rx='2' fill='#14b8a6'/>" & \
         "<rect x='162' y='138' width='8' height='26' rx='2' fill='#0ea5e9'/>" & \
         "<rect x='174' y='130' width='8' height='34' rx='2' fill='#6366f1'/>" & \
         "<rect x='186' y='142' width='8' height='22' rx='2' fill='#ec4899'/>" & \
         "<path d='M112 100l0 22l6-6l5 11l4-2l-5-10l8 0z' fill='#0f172a' stroke='#ffffff' stroke-width='1.5' stroke-linejoin='round'/>" & \
         "</svg>" into tSvg
   get hmDrawing("heroArt", tSvg, "748,44,988,254", "hero")
   hmCorners "heroCorner", "224,20,1000,292", 24, hmColor("bg"), "hero"

   -- Where to go: one tile for each page, and the lessons
   put 0 into tIndex
   repeat for each item tPage in "speak,move,draw,web,app,lessons"
      put 224 + (tIndex mod 3) * 264 into tX
      put 308 + (tIndex div 3) * 96 into tY
      add 1 to tIndex
      hmTile tPage, tX, tY, tIndex
   end repeat

   get hmLabel("homeJump", "224,508,600,526", "Jump right in", 13, hmColor("soft"), "pg_home")
   put 224 into tX
   add 10 + hmButton("pill_new", tX, 532, 38, "New stack", "file-plus", "primary", hmColor("indigo"), "pg_home", "ide new", 0, "home") to tX
   add 10 + hmButton("pill_open", tX, 532, 38, "Open a stack", "folder-open", "ghost", hmColor("indigo"), "pg_home", "ide open", 0, "home") to tX
   add 10 + hmButton("pill_examples", tX, 532, 38, "Examples", "layers", "ghost", hmColor("indigo"), "pg_home", "ide examples", 0, "home") to tX
   add 10 + hmButton("pill_dictionary", tX, 532, 38, "Dictionary", "book-open-text", "ghost", hmColor("indigo"), "pg_home", "ide dictionary", 0, "home") to tX
   hmGlow the long id of graphic "pill_new_bg", hmColor("indigo"), 12, 90
   hmRoom "pill_new", 14
   put 7 into tIndex
   repeat for each item tPage in "pill_new,pill_open,pill_examples,pill_dictionary"
      put tIndex into sCfg[tPage]["enter"]
      add 1 to tIndex
   end repeat
end hmBuildHome

private command hmHeroSparkles
   local tIndex, tSpots
   put "742 64,972 96,956 236,760 214,870 34,990 170,650 92" into tSpots
   repeat with tIndex = 1 to 7
      set the points of graphic ("heroSpark" & tIndex) to \
            hmSparklePoints(word 1 of item tIndex of tSpots, word 2 of item tIndex of tSpots, 4 + tIndex mod 3 * 2)
   end repeat
end hmHeroSparkles

private command hmTile pPage, pX, pY, pIndex
   local tName, tObj, tAccent, tTitle, tText, tIcon, tAction, tLook
   put "tile_" & pPage into tName
   if pPage is "lessons" then
      put hmColor("amber") into tAccent
      put "Lessons" into tTitle
      put "graduation-cap" into tIcon
      put "ide lessons" into tAction
   else
      put hmPageInfo(pPage, "accent") into tAccent
      put hmNavLabel(pPage) into tTitle
      put hmPageInfo(pPage, "icon") into tIcon
      put "page" && pPage into tAction
   end if
   switch pPage
      case "speak"
         put "Type a line of English-like code and watch it run." into tText
         break
      case "move"
         put "Bounce, orbit, wave and fireworks, at full speed." into tText
         break
      case "draw"
         put "Gradients, glows, SVG and widgets, drawn live." into tText
         break
      case "web"
         if hmOnWeb() then
            put "Speech, QR codes, JavaScript and links." into tText
         else
            put "Speech, QR codes, your computer and links." into tText
         end if
         break
      case "app"
         put "Make a working app in a minute, then change it." into tText
         break
      case "lessons"
         put "Step by step, from your first card to a game." into tText
         break
   end switch
   get hmGroup(tName, hmR(pX, pY, pX + 248, pY + 84), "pg_home")
   put hmBox(tName & "_bg", hmR(pX, pY, pX + 248, pY + 84), "255,255,255", 18, tName) into tObj
   hmBorder tObj, hmColor("line")
   hmShadow tObj, 10, 2, 26
   put hmBox(tName & "_chip", hmR(pX + 16, pY + 20, pX + 60, pY + 64), hmMix("255,255,255", tAccent, 0.12), 14, tName) into tObj
   get hmIcon(tName & "_icon", tIcon, tAccent, hmR(pX + 27, pY + 31, pX + 49, pY + 53), tName)
   get hmLabel(tName & "_title", hmR(pX + 74, pY + 17, pX + 240, pY + 37), tTitle, 15, hmColor("ink"), tName)
   get hmLabel(tName & "_text", hmR(pX + 74, pY + 39, pX + 236, pY + 75), tText, 12, hmColor("soft"), tName)
   put tName & "_bg" into tLook["bg"]
   put hmColor("line") into tLook["line0"]
   put tAccent into tLook["line1"]
   put 4 into tLook["lift"]
   put true into tLook["shadow"]
   put pIndex into tLook["enter"]
   hmLive tName, "home", tAction, tLook
   hmRoom tName, 14
end hmTile

private command hmHomeStart
   put 1 into sHero["line"]
   put "type" into sHero["phase"]
   put the milliseconds into sHero["at"]
   put -1 into sHero["shown"]
   put 0 into sTipIndex
   put 0 into sTipAt
end hmHomeStart

private function hmHeroLines
   return "put " & quote & "Hello, world!" & quote & " into field " & quote & "Greeting" & quote & return & \
         "move graphic " & quote & "Ball" & quote & " to 300,200 in 1 second" & return & \
         "set the backgroundColor of this card to " & quote & "gold" & quote & return & \
         "repeat with i = 1 to 10" & return & \
         "answer " & quote & hmPick("I made this in a browser!", "I made this myself!") & quote & return & \
         "put the number of words in " & quote & "xTalk reads like English" & quote & return & \
         "sort lines of field " & quote & "Names" & quote & return & \
         "revSpeak " & quote & "Welcome home" & quote
end hmHeroLines

private command hmHomeFrame
   local tT, tA, tIndex, tX, tY, tR, tLine, tCount, tLen, tShown, tTip, tTipLine
   put sNow / 1000 into tT
   -- The gradient turns slowly
   put 0.35 * tT into tA
   hmGradientPoints the long id of graphic "heroBg", round(612 + sOX + 430 * cos(tA)) & "," & round(156 + sOY + 150 * sin(tA)), \
         round(612 + sOX - 430 * cos(tA)) & "," & round(156 + sOY - 150 * sin(tA))
   -- The lights drift
   repeat with tIndex = 1 to 4
      put 70 + tIndex * 18 into tR
      put 612 + sOX + (300 - tIndex * 30) * sin(tT * (0.21 + tIndex * 0.07) + tIndex * 1.7) into tX
      put 156 + sOY + (90 - tIndex * 8) * cos(tT * (0.17 + tIndex * 0.05) + tIndex * 2.3) into tY
      set the rect of graphic ("heroOrb" & tIndex) to round(tX - tR), round(tY - tR), round(tX + tR), round(tY + tR)
      hmGlowCentre the long id of graphic ("heroOrb" & tIndex)
   end repeat
   -- The stack of cards floats, and sparkles twinkle round it
   set the top of image "heroArt" to 44 + sOY + round(7 * sin(tT * 1.6))
   repeat with tIndex = 1 to 7
      set the blendLevel of graphic ("heroSpark" & tIndex) to round(100 * (0.5 + 0.5 * sin(tT * (1.6 + tIndex * 0.23) + tIndex * 1.9)))
   end repeat
   -- The Message Box types a line, shows it, and wipes it
   put line sHero["line"] of hmHeroLines() into tLine
   put the number of chars of tLine into tLen
   switch sHero["phase"]
      case "type"
         put min(tLen, (sNow - sHero["at"]) div 40) into tCount
         if tCount >= tLen then
            put "hold" into sHero["phase"]
            put sNow into sHero["at"]
         end if
         break
      case "hold"
         put tLen into tCount
         if sNow - sHero["at"] > 2000 then
            put "wipe" into sHero["phase"]
            put sNow into sHero["at"]
         end if
         break
      default
         put max(0, tLen - (sNow - sHero["at"]) div 10) into tCount
         if tCount is 0 then
            put sHero["line"] mod the number of lines of hmHeroLines() + 1 into sHero["line"]
            put "type" into sHero["phase"]
            put sNow + 250 into sHero["at"]
         end if
   end switch
   if tCount is not sHero["shown"] then
      put tCount into sHero["shown"]
      set the htmlText of field "heroCode" to hmCodeHtml(char 1 to tCount of tLine)
      set the left of graphic "heroCaret" to the left of field "heroCode" + the formattedWidth of field "heroCode" + 2
   end if
   set the visible of graphic "heroCaret" to sHero["phase"] is not "hold" or (sNow div 480) mod 2 is 0
   -- A tip at the foot of the page, now and then
   if sNow > sTipAt then
      add 1 to sTipIndex
      put (sTipIndex - 1) mod 5 + 1 into tTipLine
      put line tTipLine of \
            ("Tip: the arrow keys page through Home." & return & \
            hmPick("Tip: stacks you save stay in this browser; File > Download Stack gives you a copy.", \
            "Tip: File > Standalone Application Settings turns a stack into an app.") & return & \
            "Tip: the Message Box, in the toolbar, runs any line of xTalk you type." & return & \
            "Tip: Help > Welcome to OXT-Beyond brings you back to Home." & return & \
            "Tip: the Dictionary explains every word of the language, with examples.") into tTip
      set the textColor of field "hdrStatus" to hmColor("soft")
      put tTip into field "hdrStatus"
      put sNow + 7000 into sTipAt
   end if
end hmHomeFrame

################################################################################
#
# Speak xTalk
#

-- The lines the demo types: the code, then what it shows
-- The line the Speak page offers to run first: it moves the ball to the
-- right of the stage, where the window has it
private function hmSpeakFirstTry
   return "move graphic " & quote & "Ball" & quote & " to" && (700 + sOX) & "," & (236 + sOY) && "in 1 second"
end hmSpeakFirstTry

private function hmSpeakLines
   local tLines
   put "put '" & hmPick("Hello from your browser!", "Hello from your stack!") & "' into field 'Greeting'|put puts text anywhere: in a field, a variable, or the Message Box." & return & \
         "set the textColor of field 'Greeting' to 'purple'|Everything has properties you can set: colour, size, font, position." & return & \
         "move graphic 'Ball' to" && (930 + sOX) & "," & (236 + sOY) && "in 1 second without waiting|move glides an object across the card, while the script carries on." & return & \
         "set the angle of graphic 'Gem' to 30|A regular polygon turns when you set its angle." & return & \
         "set the backgroundColor of graphic 'Box' to 'gold'|Colours have names, or you can give red, green and blue: 255,200,0." & return & \
         "set the blendLevel of graphic 'Ball' to 60|blendLevel makes an object see-through: 0 is solid, 100 is invisible." & return & \
         "put toUpper('xtalk reads like English') into field 'Greeting'|Functions such as toUpper change text, numbers and dates." & return & \
         "put the number of words in 'one two three four' into field 'Greeting'|Words, items, lines and characters are part of the language: chunks." & return & \
         "put the long date into field 'Greeting'|The date and the time are always one word away." into tLines
   replace "'" with quote in tLines
   return tLines
end hmSpeakLines

private command hmBuildSpeak
   local tObj, tX, tIndex, tChip
   -- The Message Box
   put hmBox("spkCodeBg", "224,92,604,392", hmColor("code"), 22, "pg_speak") into tObj
   hmShadow tObj, 18, 6, 50
   get hmOval("spkDot1", "240,108,248,116", "248,113,113", "pg_speak")
   get hmOval("spkDot2", "253,108,261,116", "251,191,36", "pg_speak")
   get hmOval("spkDot3", "266,108,274,116", "52,211,153", "pg_speak")
   get hmLabel("spkCodeTitle", "284,104,500,120", "Message Box", 11, hmColor("muted"), "pg_speak")
   put hmOval("spkLive", "538,109,546,117", "52,211,153", "pg_speak") into tObj
   hmGlow tObj, "52,211,153", 8, 160
   get hmLabel("spkLiveLabel", "552,104,600,120", "live", 11, hmColor("muted"), "pg_speak")
   get hmCodeField("spkLines", "240,128,592,382", 13, 22, "pg_speak")
   get hmBox("spkCaret", "240,131,242,147", hmColor("flame"), 0, "pg_speak")

   -- The card the lines change
   put hmBox("spkStageBg", "620,92,1000,392", "255,255,255", 22, "pg_speak") into tObj
   hmBorder tObj, hmColor("line")
   hmShadow tObj, 12, 3, 30
   get hmLabel("spkStageTitle", "636,104,900,120", "What the lines do, live", 11, hmColor("muted"), "pg_speak")
   get hmLabel("Greeting", "636,132,984,206", empty, 24, hmColor("ink"), "pg_speak", "center")
   get hmBox("spkFloor", "636,354,984,356", hmColor("line"), 0, "pg_speak")
   put hmOval("Ball", "656,288,704,336", hmColor("orange"), "pg_speak") into tObj
   put hmBox("Box", "760,282,840,348", hmColor("teal"), 20, "pg_speak") into tObj
   put hmBox("Gem", "884,280,950,346", hmColor("violet"), 0, "pg_speak") into tObj
   set the style of tObj to "regular"
   set the polySides of tObj to 6

   -- What the line in front does
   put hmBox("spkWhyBg", "224,404,1000,452", "255,255,255", 18, "pg_speak") into tObj
   hmBorder tObj, hmColor("line")
   get hmIcon("spkWhyIcon", "sparkles", hmColor("violet"), "240,418,260,438", "pg_speak")
   get hmLabel("spkWhy", "272,420,988,440", empty, 13, hmColor("soft"), "pg_speak")

   -- Your turn
   put hmBox("spkTryBg", "224,464,1000,596", "255,255,255", 22, "pg_speak") into tObj
   hmBorder tObj, hmColor("line")
   get hmLabel("spkTryTitle", "240,476,800,496", "Your turn: type a line, then press Run or Return", 15, hmColor("ink"), "pg_speak")
   put hmBox("spkInputBg", "240,504,870,540", "248,250,252", 14, "pg_speak") into tObj
   hmBorder tObj, hmColor("line")
   put hmInput("spkInput", "254,512,860,534", hmSpeakFirstTry(), 14, "pg_speak") into tObj
   if hmCodeFont() is not empty then
      set the textFont of tObj to hmCodeFont()
   end if
   get hmButton("spkRun", 882, 504, 36, "Run", "play", "primary", hmColor("violet"), "pg_speak", "run", 102, "speak")
   get hmLabel("spkTryLabel", "240,558,280,574", "Try:", 12, hmColor("muted"), "pg_speak")
   put 272 into tX
   put 1 into tIndex
   repeat for each line tChip in hmSpeakChips()
      add 8 + hmButton("spkChip" & tIndex, tX, 552, 28, tChip, empty, "chip", hmColor("violet"), "pg_speak", "chip" && tIndex, 0, "speak") to tX
      add 1 to tIndex
   end repeat
end hmBuildSpeak

private function hmSpeakChips
   return "put 6 * 7 into field " & quote & "Greeting" & quote & return & \
         "set the angle of graphic " & quote & "Gem" & quote & " to 15" & return & \
         "hide graphic " & quote & "Box" & quote
end hmSpeakChips

private command hmSpeakStart
   hmSpeakReset
   put 1 into sSpeak["line"]
   put "type" into sSpeak["phase"]
   put the milliseconds + 300 into sSpeak["at"]
   put empty into sSpeak["done"]
   put -1 into sSpeak["shown"]
   put 0 into sSpeak["pause"]
   put 0 into sSpeak["flash"]
   put empty into field "spkLines"
   put "Watch the Message Box" into field "Greeting"
   put "Each line on the left runs as soon as it is typed." into field "spkWhy"
end hmSpeakStart

-- The card as it was
private command hmSpeakReset
   set the rect of graphic "Ball" to 656 + sOX, 288 + sOY, 704 + sOX, 336 + sOY
   set the blendLevel of graphic "Ball" to 0
   set the backgroundColor of graphic "Ball" to hmColor("orange")
   set the backgroundColor of graphic "Box" to hmColor("teal")
   set the angle of graphic "Gem" to 0
   set the textColor of field "Greeting" to hmColor("ink")
   show graphic "Box"
end hmSpeakReset

private command hmSpeakFrame
   local tLine, tCode, tWhy, tLen, tCount, tLines, tRect, tError, tLineNumber
   -- The dot by "live" breathes
   set the blendLevel of graphic "spkLive" to round(40 * (0.5 + 0.5 * sin(sNow / 300)))
   hmSpeakSyncChip
   -- A line just run lights the card's border
   if sNow - sSpeak["flash"] < 900 then
      set the foregroundColor of graphic "spkStageBg" to hmMix(hmColor("violet"), hmColor("line"), (sNow - sSpeak["flash"]) / 900)
   end if
   if sNow < sSpeak["pause"] then
      -- (the user's own line is showing: the demo's caret waits out of sight)
      hide graphic "spkCaret"
      exit hmSpeakFrame
   end if
   if sNow < sSpeak["at"] then
      set the visible of graphic "spkCaret" to (sNow div 480) mod 2 is 0
      exit hmSpeakFrame
   end if
   set the itemDelimiter to "|"
   put line sSpeak["line"] of hmSpeakLines() into tLine
   put item 1 of tLine into tCode
   put item 2 of tLine into tWhy
   set the itemDelimiter to comma
   put the number of chars of tCode into tLen
   switch sSpeak["phase"]
      case "type"
         put min(tLen, (sNow - sSpeak["at"]) div 32) into tCount
         if tCount is not sSpeak["shown"] then
            put tCount into sSpeak["shown"]
            put sSpeak["done"] into tLines
            if tLines is not empty then
               put return after tLines
            end if
            put char 1 to tCount of tCode after tLines
            set the htmlText of field "spkLines" to hmCodeHtml(tLines)
            if tCount > 0 then
               put the number of lines of tLines into tLineNumber
               put the formattedRect of char tCount of line tLineNumber of field "spkLines" into tRect
               set the rect of graphic "spkCaret" to item 3 of tRect + 1, item 2 of tRect + 2, item 3 of tRect + 3, item 4 of tRect - 2
               show graphic "spkCaret"
            end if
         end if
         if tCount >= tLen then
            -- Run it, as the Message Box would
            try
               do tCode
            catch tError
            end try
            put tWhy into field "spkWhy"
            put sNow into sSpeak["flash"]
            put "rest" into sSpeak["phase"]
            put sNow into sSpeak["at"]
            if sSpeak["done"] is empty then
               put tCode into sSpeak["done"]
            else
               put return & tCode after sSpeak["done"]
            end if
            if the number of lines of sSpeak["done"] > 7 then
               delete line 1 of sSpeak["done"]
            end if
         end if
         break
      case "rest"
         set the visible of graphic "spkCaret" to (sNow div 480) mod 2 is 0
         if sNow - sSpeak["at"] > 1800 then
            put -1 into sSpeak["shown"]
            if sSpeak["line"] < the number of lines of hmSpeakLines() then
               add 1 to sSpeak["line"]
               put "type" into sSpeak["phase"]
            else
               put "again" into sSpeak["phase"]
            end if
            put sNow into sSpeak["at"]
         end if
         break
      default
         if sNow - sSpeak["at"] > 1500 then
            hmSpeakStart
         end if
   end switch
end hmSpeakFrame

-- Runs the user's line, as the Message Box does, and stops the demo for a
-- while so that they see what it did
private command hmSpeakTry
   local tCode, tError
   put word 1 to -1 of field "spkInput" into tCode
   if tCode is empty then
      hmStatus "Type a line of xTalk first, such as: put 1 + 1 into field " & quote & "Greeting" & quote, "warn"
      exit hmSpeakTry
   end if
   put sNow + 9000 into sSpeak["pause"]
   if sSpeak["done"] is empty then
      put tCode into sSpeak["done"]
   else
      put return & tCode after sSpeak["done"]
   end if
   if the number of lines of sSpeak["done"] > 7 then
      delete line 1 of sSpeak["done"]
   end if
   set the htmlText of field "spkLines" to hmCodeHtml(sSpeak["done"])
   put -1 into sSpeak["shown"]
   put "rest" into sSpeak["phase"]
   put sNow + 9000 into sSpeak["at"]
   try
      do tCode
      put the milliseconds into sSpeak["flash"]
      put "You ran your own line. Change it and run it again, or try another." into field "spkWhy"
      hmStatus "It ran.", "ok"
   catch tError
      put "Not quite:" && hmErrorText(tError) & ". Check the spelling and the quotes." into field "spkWhy"
      hmStatus "That line did not run.", "bad"
   end try
end hmSpeakTry

-- A chip runs the line it shows
private command hmSpeakChip pIndex
   put field ("spkChip" & pIndex & "_label") into field "spkInput"
   hmSpeakTry
end hmSpeakChip

-- The last chip hides the Box, or shows it again once it is hidden
-- ("hide" and "show" are as wide in the code font, so the chip keeps its size)
private command hmSpeakSyncChip
   local tLine
   if the visible of graphic "Box" then
      put "hide" into tLine
   else
      put "show" into tLine
   end if
   put " graphic " & quote & "Box" & quote after tLine
   if field "spkChip3_label" is not tLine then
      put tLine into field "spkChip3_label"
   end if
end hmSpeakSyncChip

################################################################################
#
# Make it move
#

private command hmBuildMove
   local tObj, tSvg, tX, tY, tIndex, tMode, tLook
   get hmGroup("mvStage", kStage, "pg_move")
   put hmBox("mvStageBg", "220,92,1004,456", hmColor("code"), 0, "mvStage") into tObj
   hmGradient tObj, "11,15,35|30,27,75", "224,96", "224,452"
   -- A faint grid of dots
   put "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 776 356'>" into tSvg
   repeat with tY = 14 to 356 step 28
      repeat with tX = 14 to 776 step 28
         put "<circle cx='" & tX & "' cy='" & tY & "' r='1.2' fill='#ffffff' fill-opacity='0.09'/>" after tSvg
      end repeat
   end repeat
   put "</svg>" after tSvg
   get hmDrawing("mvGrid", tSvg, kStage, "mvStage")
   put hmOval("mvSun", "586,248,638,300", "253,224,71", "mvStage") into tObj
   hmGlow tObj, "251,146,60", 40, 220
   hide tObj
   repeat with tIndex = 1 to kPool
      put hmOval("mvB" & tIndex, "0,0,10,10", "255,255,255", "mvStage") into tObj
      hide tObj
   end repeat
   put hmLabel("mvFps", "240,106,600,122", empty, 12, hmColor("muted"), "mvStage") into tObj
   if hmCodeFont() is not empty then
      set the textFont of tObj to hmCodeFont()
   end if
   get hmLabel("mvHint", "240,426,700,442", "Click anywhere on the stage to add more.", 12, "148,163,184", "mvStage")
   put 984 into tX
   repeat for each item tMode in "fireworks,wave,orbit,bounce"
      put hmModeButton(tMode, tX) into tX
   end repeat
   hmCorners "mvCorner", kStage, 22, hmColor("bg"), "mvStage"

   -- The code
   put hmBox("mvCodeBg", "224,464,700,596", hmColor("code"), 22, "pg_move") into tObj
   get hmLabel("mvCodeTitle", "240,474,690,490", empty, 11, hmColor("muted"), "pg_move")
   get hmCodeField("mvCode", "240,494,692,590", 12, 16, "pg_move")
   -- How it works, and a stack of your own
   put hmBox("mvInfoBg", "716,464,1000,596", "255,255,255", 22, "pg_move") into tObj
   hmBorder tObj, hmColor("line")
   get hmLabel("mvInfo", "732,476,988,544", \
         "One handler moves every ball, then asks to be run again in 16 milliseconds: about 60 frames a second, and the IDE never waits for it.", \
         12, hmColor("soft"), "pg_move")
   get hmButton("mvRemix", 732, 552, 34, "Open Bounce as a stack", "wand-sparkles", "primary", hmColor("orange"), "pg_move", "remix", 252, "move")
end hmBuildMove

-- A mode button, right to left from pRight; returns where the next ends
private function hmModeButton pMode, pRight
   local tWidth, tName, tLook
   put "mvMode_" & pMode into tName
   put hmButton(tName, 0, 106, 28, toUpper(char 1 of pMode) & char 2 to -1 of pMode, empty, "dark", empty, "mvStage", "mode" && pMode, 0, "move") into tWidth
   set the left of group tName to pRight - tWidth
   put the top of group tName into sCfg[tName]["top"]
   return pRight - tWidth - 8
end hmModeButton

private command hmMoveStart
   if sMove["mode"] is empty then
      put "bounce" into sMove["mode"]
   end if
   hmMoveMode sMove["mode"]
end hmMoveStart

private command hmMoveStop
   local tIndex
   repeat with tIndex = 1 to kPool
      if sBshown[tIndex] is true then
         hide graphic ("mvB" & tIndex)
         put false into sBshown[tIndex]
      end if
   end repeat
end hmMoveStop

private command hmMoveMode pMode
   local tIndex, tName, tMode
   put pMode into sMove["mode"]
   put 0 into sMove["boost"]
   put sNow into sMove["next"]
   -- The buttons show the mode
   repeat for each item tMode in "bounce,orbit,wave,fireworks"
      put "mvMode_" & tMode into tName
      if tMode is pMode then
         put hmColor("orange") into sCfg[tName]["bg0"]
         put hmMix(hmColor("orange"), "255,255,255", 0.15) into sCfg[tName]["bg1"]
         put hmColor("orange") into sCfg[tName]["line0"]
         put "255,255,255" into sCfg[tName]["ink0"]
      else
         put hmColor("side2") into sCfg[tName]["bg0"]
         put hmColor("sideLine") into sCfg[tName]["bg1"]
         put hmColor("sideLine") into sCfg[tName]["line0"]
         put hmColor("sideInk") into sCfg[tName]["ink0"]
      end if
      hmApply tName
   end repeat
   repeat with tIndex = 1 to kPool
      put 0 into sBlife[tIndex]
   end repeat
   set the visible of graphic "mvSun" to pMode is "orbit"
   switch pMode
      case "bounce"
         repeat with tIndex = 1 to 44
            hmBall tIndex, 260 + random(700), 120 + random(160), random(500) - 250, -random(200), 7 + random(10), random(360)
         end repeat
         break
      case "orbit"
         repeat with tIndex = 1 to 96
            hmBall tIndex, 0, 0, 0, 0, 3 + random(5), 0
            put 30 + random(150) into sBvx[tIndex]
            put random(628) / 100 into sBvy[tIndex]
            put 190 + sBvx[tIndex] into sBhue[tIndex]
         end repeat
         break
      case "wave"
         repeat with tIndex = 1 to 80
            hmBall tIndex, 0, 0, 0, 0, 7, 0
         end repeat
         break
      case "fireworks"
         break
   end switch
   put "The heart of" && toUpper(char 1 of pMode) & char 2 to -1 of pMode into field "mvCodeTitle"
   set the htmlText of field "mvCode" to hmCodeHtml(hmMoveCode(pMode))
end hmMoveMode

-- Brings ball pIndex to life
private command hmBall pIndex, pX, pY, pVX, pVY, pR, pHue
   put pX into sBx[pIndex]
   put pY into sBy[pIndex]
   put pVX into sBvx[pIndex]
   put pVY into sBvy[pIndex]
   put pR into sBr[pIndex]
   put pHue into sBhue[pIndex]
   put 1 into sBlife[pIndex]
   put 0 into sBage[pIndex]
   put empty into sBkind[pIndex]
end hmBall

-- A ball not in use, or the oldest
private function hmFreeBall
   local tIndex, tOldest, tAge
   put 1 into tOldest
   put -1 into tAge
   repeat with tIndex = 1 to kPool
      if sBlife[tIndex] <= 0 then
         return tIndex
      end if
      if sBage[tIndex] > tAge then
         put sBage[tIndex] into tAge
         put tIndex into tOldest
      end if
   end repeat
   return tOldest
end hmFreeBall

private function hmMoveCode pMode
   local tCode
   switch pMode
      case "bounce"
         put "repeat with i = 1 to the number of graphics" & return & \
               "   add 15 to sVY[i] -- gravity pulls it down" & return & \
               "   add sVY[i] / 60 to sY[i]" & return & \
               "   if sY[i] > 440 then put -sVY[i] * 0.9 into sVY[i]" & return & \
               "   set the loc of graphic i to sX[i], sY[i]" & return & \
               "end repeat" into tCode
         break
      case "orbit"
         put "repeat with i = 1 to the number of graphics" & return & \
               "   add sSpeed[i] to sAngle[i] -- round it goes" & return & \
               "   put 612 + sRadius[i] * cos(sAngle[i]) into tX" & return & \
               "   put 274 + sRadius[i] * sin(sAngle[i]) / 3 into tY" & return & \
               "   set the loc of graphic i to tX, tY" & return & \
               "end repeat" into tCode
         break
      case "wave"
         put "repeat with i = 1 to 40" & return & \
               "   put sin(the milliseconds / 400 + i / 5) into tWave" & return & \
               "   set the loc of graphic i to 240 + i * 18, 274 + 90 * tWave" & return & \
               "   set the loc of graphic (i + 40) to 240 + i * 18, 274 - 90 * tWave" & return & \
               "end repeat" & return & \
               "send " & quote & "moveBalls" & quote & " to me in 16 milliseconds" into tCode
         break
      case "fireworks"
         put "repeat for each key i in sSparks" & return & \
               "   add 4 to sVY[i] -- sparks fall" & return & \
               "   set the loc of graphic i to sX[i] + sVX[i], sY[i] + sVY[i]" & return & \
               "   add 3 to sFade[i] -- and fade" & return & \
               "   set the blendLevel of graphic i to sFade[i]" & return & \
               "end repeat" into tCode
         break
   end switch
   return tCode
end hmMoveCode

private command hmMoveClick pX, pY
   local tIndex, tCount, tBall, tAngle, tSpeed, tHue
   switch sMove["mode"]
      case "bounce"
         repeat 8 times
            put hmFreeBall() into tBall
            hmBall tBall, pX, pY, random(600) - 300, -200 - random(400), 7 + random(10), random(360)
         end repeat
         break
      case "orbit"
         repeat 12 times
            put hmFreeBall() into tBall
            hmBall tBall, 0, 0, 0, 0, 3 + random(5), 0
            put max(30, min(190, abs(pX - 612) / 1.9)) + random(20) - 10 into sBvx[tBall]
            put random(628) / 100 into sBvy[tBall]
            put random(360) into sBhue[tBall]
         end repeat
         break
      case "wave"
         put 1 into sMove["boost"]
         add 60 to sMove["hue"]
         break
      case "fireworks"
         hmBurst pX, pY, random(360)
         break
   end switch
end hmMoveClick

-- A firework bursts at pX,pY in one colour: a flash, a ring of sparks
-- and a scatter inside it
private command hmBurst pX, pY, pHue
   local tBall, tAngle, tSpeed, tIndex
   put hmFreeBall() into tBall
   hmBall tBall, pX, pY, 0, 0, 8, pHue
   put "flash" into sBkind[tBall]
   put 0.4 into sBlife[tBall]
   repeat with tIndex = 1 to 40
      put hmFreeBall() into tBall
      put tIndex * 0.157 + random(8) / 100 into tAngle
      if tIndex mod 2 is 0 then
         put 170 + random(40) into tSpeed
      else
         put 40 + random(140) into tSpeed
      end if
      hmBall tBall, pX, pY, tSpeed * cos(tAngle), tSpeed * sin(tAngle), 3, pHue + random(40) - 20
      put 1.2 + random(70) / 100 into sBlife[tBall]
   end repeat
end hmBurst

private command hmMoveFrame
   local tIndex, tLeft, tTop, tRight, tBottom, tT, tCount, tX, tY, tR, tColor, tBlend, tDepth, tWave, tAmp, tBall, tHue
   put 230 into tLeft
   put 102 into tTop
   put 994 into tRight
   put 446 into tBottom
   put sNow / 1000 into tT
   put 0 into tCount
   switch sMove["mode"]
      case "bounce"
         repeat with tIndex = 1 to kPool
            if sBlife[tIndex] <= 0 then
               next repeat
            end if
            add 1 to tCount
            add sDt to sBage[tIndex]
            add 900 * sDt to sBvy[tIndex]
            add sBvx[tIndex] * sDt to sBx[tIndex]
            add sBvy[tIndex] * sDt to sBy[tIndex]
            put sBr[tIndex] into tR
            if sBx[tIndex] - tR < tLeft then
               put tLeft + tR into sBx[tIndex]
               put abs(sBvx[tIndex]) * 0.95 into sBvx[tIndex]
            else if sBx[tIndex] + tR > tRight then
               put tRight - tR into sBx[tIndex]
               put -abs(sBvx[tIndex]) * 0.95 into sBvx[tIndex]
            end if
            if sBy[tIndex] + tR > tBottom then
               put tBottom - tR into sBy[tIndex]
               put -abs(sBvy[tIndex]) * 0.86 into sBvy[tIndex]
               if abs(sBvy[tIndex]) < 160 then
                  put -(420 + random(260)) into sBvy[tIndex]
               end if
            else if sBy[tIndex] - tR < tTop then
               put tTop + tR into sBy[tIndex]
               put abs(sBvy[tIndex]) into sBvy[tIndex]
            end if
            hmDrawBall tIndex, sBx[tIndex], sBy[tIndex], tR, hmHue(sBhue[tIndex], 0.85, 0.62), 0
         end repeat
         break
      case "orbit"
         repeat with tIndex = 1 to kPool
            if sBlife[tIndex] <= 0 then
               next repeat
            end if
            add 1 to tCount
            add sDt to sBage[tIndex]
            add sDt * 34 / sqrt(sBvx[tIndex]) to sBvy[tIndex]
            put sin(sBvy[tIndex]) into tDepth
            put 612 + 1.9 * sBvx[tIndex] * cos(sBvy[tIndex]) into tX
            put 274 + 0.55 * sBvx[tIndex] * tDepth into tY
            put sBr[tIndex] * (1 + 0.45 * tDepth) into tR
            hmDrawBall tIndex, tX, tY, tR, hmHue(sBhue[tIndex] + tT * 20, 0.9, 0.65), round(30 - 30 * tDepth)
         end repeat
         set the rect of graphic "mvSun" to round(612 + sOX - 26 - 2 * sin(tT * 3)), round(274 + sOY - 26 - 2 * sin(tT * 3)), \
               round(612 + sOX + 26 + 2 * sin(tT * 3)), round(274 + sOY + 26 + 2 * sin(tT * 3))
         break
      case "wave"
         put max(0, sMove["boost"] - sDt * 0.8) into sMove["boost"]
         put 80 * (1 + 0.7 * sMove["boost"]) into tAmp
         repeat with tIndex = 1 to 80
            put (tIndex - 1) mod 40 into tX
            put sin(tT * 2.4 + tX / 4.2) into tWave
            put 0.5 + 0.5 * cos(tT * 2.4 + tX / 4.2) into tDepth
            if tIndex > 40 then
               put -tWave into tWave
               put 1 - tDepth into tDepth
            end if
            add 1 to tCount
            put sMove["hue"] + tX * 7 + tT * 30 into tHue
            if tIndex > 40 then
               add 140 to tHue
            end if
            hmDrawBall tIndex, 260 + tX * 18.6, 274 + tAmp * tWave, 4 + 6 * tDepth, hmHue(tHue, 0.9, 0.62), round(55 - 55 * tDepth)
         end repeat
         break
      case "fireworks"
         if sNow > sMove["next"] then
            put sNow + 650 + random(700) into sMove["next"]
            put hmFreeBall() into tBall
            -- (fast enough to burst between a third and three quarters of the way up)
            hmBall tBall, 300 + random(620), tBottom, random(80) - 40, -(280 + random(110)), 4, random(360)
            put "rocket" into sBkind[tBall]
            put 9 into sBlife[tBall]
         end if
         repeat with tIndex = 1 to kPool
            if sBlife[tIndex] <= 0 then
               next repeat
            end if
            add 1 to tCount
            add sDt to sBage[tIndex]
            if sBkind[tIndex] is "rocket" then
               add 260 * sDt to sBvy[tIndex]
               add sBvx[tIndex] * sDt to sBx[tIndex]
               add sBvy[tIndex] * sDt to sBy[tIndex]
               if sBvy[tIndex] > -60 then
                  put 0 into sBlife[tIndex]
                  put empty into sBkind[tIndex]
                  hide graphic ("mvB" & tIndex)
                  put false into sBshown[tIndex]
                  hmBurst sBx[tIndex], sBy[tIndex], sBhue[tIndex]
               else
                  hmDrawBall tIndex, sBx[tIndex], sBy[tIndex], 3, "255,237,213", 0
                  -- an ember now and then, left behind
                  if random(3) is 1 then
                     put hmFreeBall() into tBall
                     hmBall tBall, sBx[tIndex] + random(5) - 3, sBy[tIndex] + 4, 0, 30, 2, 30
                     put "ember" into sBkind[tBall]
                     put 0.45 into sBlife[tBall]
                  end if
               end if
            else if sBkind[tIndex] is "flash" then
               if sBage[tIndex] >= sBlife[tIndex] then
                  put 0 into sBlife[tIndex]
                  put empty into sBkind[tIndex]
                  hide graphic ("mvB" & tIndex)
                  put false into sBshown[tIndex]
               else
                  put sBage[tIndex] / sBlife[tIndex] into tBlend
                  hmDrawBall tIndex, sBx[tIndex], sBy[tIndex], 8 + 34 * hmEase(tBlend), hmHue(sBhue[tIndex], 1, 0.9), round(55 + 45 * tBlend)
               end if
            else
               add 150 * sDt to sBvy[tIndex]
               put sBvx[tIndex] * (1 - sDt * 1.2) into sBvx[tIndex]
               add sBvx[tIndex] * sDt to sBx[tIndex]
               add sBvy[tIndex] * sDt to sBy[tIndex]
               if sBage[tIndex] >= sBlife[tIndex] then
                  put 0 into sBlife[tIndex]
                  hide graphic ("mvB" & tIndex)
                  put false into sBshown[tIndex]
               else
                  put sBage[tIndex] / sBlife[tIndex] into tBlend
                  if sBkind[tIndex] is "ember" then
                     hmDrawBall tIndex, sBx[tIndex], sBy[tIndex], 1.5, "253,186,116", round(100 * tBlend)
                  else
                     -- (bright and big at first, then smaller, and twinkling as they go)
                     put round(100 * tBlend ^ 2) into tBlend
                     if tBlend > 30 and random(4) is 1 then
                        put 90 into tBlend
                     end if
                     hmDrawBall tIndex, sBx[tIndex], sBy[tIndex], 4.5 - 2.5 * sBage[tIndex] / sBlife[tIndex], \
                           hmHue(sBhue[tIndex], 0.95, 0.62 + 0.28 * (1 - sBage[tIndex] / sBlife[tIndex])), tBlend
                  end if
               end if
            end if
         end repeat
         break
   end switch
   -- Balls no longer in use
   repeat with tIndex = 1 to kPool
      if sBlife[tIndex] <= 0 and sBshown[tIndex] is true then
         hide graphic ("mvB" & tIndex)
         put false into sBshown[tIndex]
      end if
   end repeat
   if sFps is not empty then
      put sFps && "frames a second   " & tCount && "balls" into field "mvFps"
   end if
end hmMoveFrame

-- (the balls move in the coordinates of a 1024 by 640 window: each is
-- drawn where the window has the stage)
private command hmDrawBall pIndex, pX, pY, pR, pColor, pBlend
   local tName
   put "mvB" & pIndex into tName
   add sOX to pX
   add sOY to pY
   set the rect of graphic tName to round(pX - pR), round(pY - pR), round(pX + pR), round(pY + pR)
   if sBcolor[pIndex] is not pColor then
      set the backgroundColor of graphic tName to pColor
      put pColor into sBcolor[pIndex]
   end if
   set the blendLevel of graphic tName to max(0, min(100, pBlend))
   if sBshown[pIndex] is not true then
      show graphic tName
      put true into sBshown[pIndex]
   end if
end hmDrawBall

-- Bounce, as a stack of the user's own: one card script to read and change
private command hmRemix
   local tName, tNumber, tScript, tSaved, tError
   put "Bouncing Balls" into tName
   put 1 into tNumber
   repeat while there is a stack tName
      add 1 to tNumber
      put "Bouncing Balls" && tNumber into tName
   end repeat
   put "-- Bouncing balls, made by Home. Click to add more: change anything," & return & \
         "-- then click the card again." & return & \
         "local sX, sY, sVX, sVY, sR, sCount, sTimer" & return & \
         return & \
         "on startBalls" & return & \
         "   set the defaultStack to the short name of the owner of me" & return & \
         "   repeat 24 times" & return & \
         "      makeBall random(the width of me), 60" & return & \
         "   end repeat" & return & \
         "   moveBalls" & return & \
         "end startBalls" & return & \
         return & \
         "on mouseDown" & return & \
         "   repeat 6 times" & return & \
         "      makeBall the mouseH, the mouseV" & return & \
         "   end repeat" & return & \
         "end mouseDown" & return & \
         return & \
         "on makeBall pX, pY" & return & \
         "   add 1 to sCount" & return & \
         "   create graphic (" & quote & "Ball" & quote & " && sCount)" & return & \
         "   set the style of it to " & quote & "oval" & quote & return & \
         "   set the opaque of it to true" & return & \
         "   set the lineSize of it to 0" & return & \
         "   set the backgroundColor of it to any item of " & quote & "orange,gold,hotpink,violet,turquoise,deepskyblue" & quote & return & \
         "   put 6 + random(12) into sR[sCount]" & return & \
         "   put pX into sX[sCount]" & return & \
         "   put pY into sY[sCount]" & return & \
         "   put random(600) - 300 into sVX[sCount]" & return & \
         "   put -random(400) into sVY[sCount]" & return & \
         "end makeBall" & return & \
         return & \
         "on moveBalls" & return & \
         "   lock screen" & return & \
         "   repeat with i = 1 to sCount" & return & \
         "      add 15 to sVY[i] -- gravity" & return & \
         "      add sVX[i] / 60 to sX[i]" & return & \
         "      add sVY[i] / 60 to sY[i]" & return & \
         "      if sY[i] + sR[i] > the height of me then" & return & \
         "         put the height of me - sR[i] into sY[i]" & return & \
         "         put -abs(sVY[i]) * 0.9 into sVY[i]" & return & \
         "      end if" & return & \
         "      if sX[i] < sR[i] or sX[i] > the width of me - sR[i] then" & return & \
         "         put -sVX[i] into sVX[i]" & return & \
         "      end if" & return & \
         "      set the rect of graphic (" & quote & "Ball" & quote & " && i) of me to \" & return & \
         "            sX[i] - sR[i], sY[i] - sR[i], sX[i] + sR[i], sY[i] + sR[i]" & return & \
         "   end repeat" & return & \
         "   unlock screen" & return & \
         "   send " & quote & "moveBalls" & quote & " to me in 16 milliseconds" & return & \
         "   put the result into sTimer" & return & \
         "end moveBalls" & return & \
         return & \
         "on closeCard" & return & \
         "   if sTimer is not empty then cancel sTimer" & return & \
         "end closeCard" into tScript
   put the defaultStack into tSaved
   try
      create stack tName
      set the width of stack tName to 640
      set the height of stack tName to 400
      set the backgroundColor of card 1 of stack tName to "15,23,42"
      set the script of card 1 of stack tName to tScript
      if the result is not empty then
         -- (a script that does not compile is set all the same, silently)
         throw "its script has an error on line" && item 2 of line 1 of the result
      end if
      set the loc of stack tName to the loc of me
      set the defaultStack to tName
      choose browse tool
      send "startBalls" to card 1 of stack tName
      hmStatus "Made the stack" && quote & tName & quote & ": its card script is the whole demo. Choose the Edit tool to change it.", "ok"
   catch tError
      hmStatus "That stack could not be made:" && hmErrorText(tError), "bad"
   end try
end hmRemix

################################################################################
#
# Draw and dazzle
#

private command hmBuildDraw
   local tObj, tSvg, tIndex, tX, tFx, tLook, tName
   -- An SVG scene, slowly zooming
   get hmGroup("drArt", "224,92,604,372", "pg_draw")
   put "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 380 280'><defs>" & \
         "<linearGradient id='sky' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#1e1b4b'/><stop offset='0.45' stop-color='#6d28d9'/><stop offset='0.78' stop-color='#db2777'/><stop offset='1' stop-color='#fb923c'/></linearGradient>" & \
         "<radialGradient id='sun' cx='0.5' cy='0.5' r='0.5'><stop offset='0' stop-color='#fef3c7'/><stop offset='0.6' stop-color='#fcd34d'/><stop offset='1' stop-color='#f97316'/></radialGradient>" & \
         "<linearGradient id='sea' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#3b0764'/><stop offset='1' stop-color='#0f172a'/></linearGradient>" & \
         "</defs><rect width='380' height='280' fill='url(#sky)'/>" into tSvg
   repeat for each item tX in "34 26,80 58,122 20,170 44,236 16,278 52,330 30,356 70,60 96,300 92,206 74,14 64"
      put "<circle cx='" & word 1 of tX & "' cy='" & word 2 of tX & "' r='1.4' fill='#ffffff' fill-opacity='0.85'/>" after tSvg
   end repeat
   put "<circle cx='190' cy='172' r='78' fill='#fde68a' fill-opacity='0.16'/>" & \
         "<circle cx='190' cy='172' r='56' fill='url(#sun)'/>" & \
         "<path d='M0 214L46 176L84 198L136 148L188 202L240 162L290 194L338 158L380 186L380 280L0 280Z' fill='#4c1d95'/>" & \
         "<path d='M0 238L70 198L128 230L196 188L262 234L320 206L380 228L380 280L0 280Z' fill='#2e1065'/>" & \
         "<rect y='240' width='380' height='40' fill='url(#sea)'/>" & \
         "<path d='M190 240L0 280M190 240L95 280M190 240L285 280M190 240L380 280M0 252H380M0 266H380' stroke='#f472b6' stroke-opacity='0.35' stroke-width='1'/>" & \
         "<rect x='150' y='246' width='80' height='3' rx='1.5' fill='#fcd34d' fill-opacity='0.75'/>" & \
         "<rect x='162' y='256' width='56' height='3' rx='1.5' fill='#fcd34d' fill-opacity='0.55'/>" & \
         "<rect x='174' y='266' width='32' height='3' rx='1.5' fill='#fcd34d' fill-opacity='0.4'/>" & \
         "</svg>" after tSvg
   get hmDrawing("drArtImg", tSvg, "205,78,623,386", "drArt")
   put hmBox("drArtShade", "224,312,604,372", "15,23,42", 0, "drArt") into tObj
   set the fillGradient["type"] of tObj to "linear"
   -- (dark enough under the caption that the sea's lines do not run
   -- through its letters)
   set the fillGradient["ramp"] of tObj to "0.000,15,23,42,0" & return & "0.450,15,23,42,170" & return & "1.000,15,23,42,235"
   hmGradientPoints tObj, "224,312", "224,372"
   get hmLabel("drArtCap", "240,344,600,360", "An SVG scene, made into a drawing by drawingSvgCompile", 12, "255,255,255", "drArt")
   hmCorners "drCorner", "224,92,604,372", 22, hmColor("bg"), "drArt"

   -- Effects
   put hmBox("drFxBg", "620,92,1000,372", "255,255,255", 22, "pg_draw") into tObj
   hmBorder tObj, hmColor("line")
   hmShadow tObj, 12, 3, 30
   repeat with tIndex = 1 to 24
      put hmOval("drW" & tIndex, "652,134,772,254", hmHue((tIndex - 1) * 15, 0.85, 0.58), "pg_draw") into tObj
      set the arcAngle of tObj to 16
      set the startAngle of tObj to (tIndex - 1) * 15
   end repeat
   get hmOval("drWHole", "684,166,740,222", "255,255,255", "pg_draw")
   get hmLabel("drWheelCap", "640,264,784,280", "24 arcs, turning", 11, hmColor("muted"), "pg_draw", "center")
   put hmBox("drStar", "826,134,950,258", hmColor("teal"), 0, "pg_draw") into tObj
   set the style of tObj to "polygon"
   set the points of tObj to hmStarPoints(888, 198, 62, 26, 5, 0)
   get hmLabel("drStarCap", "816,264,960,280", "one polygon, with effects", 11, hmColor("muted"), "pg_draw", "center")
   put hmBox("drCodeBg", "636,290,984,316", hmColor("code"), 10, "pg_draw") into tObj
   put hmCodeField("drCode", "648,297,980,313", 11, 16, "pg_draw") into tObj
   set the dontWrap of tObj to true
   put 636 into tX
   repeat for each item tFx in "gradient,shadow,glow,spin"
      put "drFx_" & tFx into tName
      add 8 + hmButton(tName, tX, 326, 30, toUpper(char 1 of tFx) & char 2 to -1 of tFx, empty, "ghost", hmColor("teal"), "pg_draw", "fx" && tFx, 76, "draw") to tX
   end repeat

   -- Widgets
   repeat with tIndex = 1 to 4
      put 224 + (tIndex - 1) * 198 into tX
      put hmBox("drP" & tIndex, hmR(tX, 388, tX + 182, 596), "255,255,255", 22, "pg_draw") into tObj
      hmBorder tObj, hmColor("line")
   end repeat
   try
      create widget "drClock" as "com.livecode.widget.clock" in group "pg_draw"
      set the rect of widget "drClock" to 255,400,375,520
   catch tName
   end try
   try
      create widget "drGraph" as "com.livecode.widget.linegraph" in group "pg_draw"
      set the rect of widget "drGraph" to 432,404,598,528
      set the graphColors of widget "drGraph" to "13,148,136,255"
   catch tName
   end try
   try
      create widget "drIcon" as "com.livecode.widget.svgpath" in group "pg_draw"
      set the rect of widget "drIcon" to 671,410,751,490
      set the iconPresetName of widget "drIcon" to "star"
   catch tName
   end try
   repeat with tIndex = 1 to 5
      put hmOval("drD" & tIndex, "853,404,965,516", hmColor(item tIndex of "indigo,teal,orange,pink,sky"), "pg_draw") into tObj
      set the arcAngle of tObj to 72
      set the startAngle of tObj to (tIndex - 1) * 72
   end repeat
   get hmOval("drDHole", "877,428,941,492", "255,255,255", "pg_draw")
   get hmLabel("drDNum", "877,450,941,470", empty, 15, hmColor("ink"), "pg_draw", "center")
   hmWidgetCaption 224, "Clock", "com.livecode.widget.clock"
   hmWidgetCaption 422, "Line graph", "com.livecode.widget.linegraph"
   hmWidgetCaption 620, "SVG icon", "com.livecode.widget.svgpath"
   hmWidgetCaption 818, "Donut", "five graphics, arcAngle"
end hmBuildDraw

private command hmWidgetCaption pX, pTitle, pKind
   get hmLabel("drCap" & pX, hmR(pX + 16, 540, pX + 170, 560), pTitle, 14, hmColor("ink"), "pg_draw")
   get hmLabel("drKind" & pX, hmR(pX + 16, 562, pX + 176, 578), pKind, 10, hmColor("muted"), "pg_draw")
end hmWidgetCaption

private command hmDrawStart
   local tFx
   if sDraw["fx"] is empty then
      put "gradient,shadow" into sDraw["fx"]
      put 0 into sDraw["turn"]
      put "50" into sDraw["walk"]
      put "22,18,26,14,20" into sDraw["donut"]
      put sDraw["donut"] into sDraw["donutTo"]
   end if
   repeat for each item tFx in "gradient,shadow,glow,spin"
      hmDrawFxShow tFx
   end repeat
   put 0 into sDraw["graphAt"]
   put 0 into sDraw["donutAt"]
   put 0 into sDraw["iconAt"]
   put 0 into sDraw["icon"]
   put "set the fillGradient of graphic " & quote & "Star" & quote & " to tRamp" into sDraw["code"]
   set the htmlText of field "drCode" to hmCodeHtml("-- click an effect to switch it on or off")
end hmDrawStart

-- Switches an effect of the star on or off, and shows the line that does it
private command hmDrawFx pFx
   local tCode
   if pFx is among the items of sDraw["fx"] then
      delete item itemOffset(pFx, sDraw["fx"]) of sDraw["fx"]
   else if sDraw["fx"] is empty then
      put pFx into sDraw["fx"]
   else
      put comma & pFx after sDraw["fx"]
   end if
   hmDrawFxShow pFx
   switch pFx
      case "gradient"
         if pFx is among the items of sDraw["fx"] then
            put "set the fillGradient[" & quote & "type" & quote & "] of graphic " & quote & "Star" & quote & " to " & quote & "linear" & quote into tCode
         else
            put "set the fillGradient of graphic " & quote & "Star" & quote & " to empty" into tCode
         end if
         break
      case "shadow"
         if pFx is among the items of sDraw["fx"] then
            put "set the dropShadow[" & quote & "size" & quote & "] of graphic " & quote & "Star" & quote & " to 18" into tCode
         else
            put "set the dropShadow of graphic " & quote & "Star" & quote & " to empty" into tCode
         end if
         break
      case "glow"
         if pFx is among the items of sDraw["fx"] then
            put "set the outerGlow[" & quote & "size" & quote & "] of graphic " & quote & "Star" & quote & " to 26" into tCode
         else
            put "set the outerGlow of graphic " & quote & "Star" & quote & " to empty" into tCode
         end if
         break
      case "spin"
         if pFx is among the items of sDraw["fx"] then
            put "set the points of graphic " & quote & "Star" & quote & " to spun(tTurn)" into tCode
         else
            put "-- the star stays still" into tCode
         end if
         break
   end switch
   set the htmlText of field "drCode" to hmCodeHtml(tCode)
end hmDrawFx

-- The star and the effect's button, as the effect is
private command hmDrawFxShow pFx
   local tOn, tName
   put pFx is among the items of sDraw["fx"] into tOn
   switch pFx
      case "gradient"
         if tOn then
            hmGradient the long id of graphic "drStar", "45,212,191|2,132,199|124,58,237", (826 + sOX) & "," & (136 + sOY), (950 + sOX) & "," & (260 + sOY)
         else
            set the fillGradient of graphic "drStar" to empty
            set the backgroundColor of graphic "drStar" to hmColor("teal")
         end if
         break
      case "shadow"
         if tOn then
            hmShadow the long id of graphic "drStar", 18, 8, 90
         else
            set the dropShadow of graphic "drStar" to empty
         end if
         break
      case "glow"
         if tOn then
            hmGlow the long id of graphic "drStar", "250,204,21", 26, 200
         else
            set the outerGlow of graphic "drStar" to empty
         end if
         break
   end switch
   put "drFx_" & pFx into tName
   if tOn then
      put hmColor("teal") into sCfg[tName]["bg0"]
      put hmMix(hmColor("teal"), "255,255,255", 0.15) into sCfg[tName]["bg1"]
      put hmColor("teal") into sCfg[tName]["line0"]
      put hmColor("teal") into sCfg[tName]["line1"]
      put "255,255,255" into sCfg[tName]["ink0"]
      put "255,255,255" into sCfg[tName]["ink1"]
   else
      put "255,255,255" into sCfg[tName]["bg0"]
      put hmMix("255,255,255", hmColor("teal"), 0.08) into sCfg[tName]["bg1"]
      put hmColor("line") into sCfg[tName]["line0"]
      put hmColor("teal") into sCfg[tName]["line1"]
      put hmColor("ink") into sCfg[tName]["ink0"]
      put hmMix(hmColor("teal"), hmColor("ink"), 0.25) into sCfg[tName]["ink1"]
   end if
   hmApply tName
end hmDrawFxShow

private command hmDrawFrame
   local tT, tIndex, tTurn, tZoom, tW, tH, tCx, tCy, tData, tValue, tTotal, tStart, tAngle, tBig, tPresets
   put sNow / 1000 into tT
   -- The wheel turns
   put round(tT * 40) mod 360 into tTurn
   repeat with tIndex = 1 to 24
      set the startAngle of graphic ("drW" & tIndex) to ((tIndex - 1) * 15 + tTurn) mod 360
   end repeat
   -- The star spins
   if "spin" is among the items of sDraw["fx"] then
      add sDt * 1.4 to sDraw["turn"]
      set the points of graphic "drStar" to hmStarPoints(888 + sOX, 198 + sOY, 62, 26, 5, sDraw["turn"])
   end if
   -- The scene drifts and zooms
   put 1.1 + 0.06 * sin(tT * 0.45) into tZoom
   put round(380 * tZoom) into tW
   put round(280 * tZoom) into tH
   put 414 + sOX + 5 * sin(tT * 0.3) into tCx
   put 232 + sOY + 4 * cos(tT * 0.37) into tCy
   set the rect of image "drArtImg" to round(tCx - tW / 2), round(tCy - tH / 2), round(tCx - tW / 2) + tW, round(tCy - tH / 2) + tH
   -- The graph walks
   if sNow > sDraw["graphAt"] and there is a widget "drGraph" then
      put sNow + 420 into sDraw["graphAt"]
      put max(5, min(95, item -1 of sDraw["walk"] + random(25) - 13)) into tValue
      put comma & tValue after sDraw["walk"]
      if the number of items of sDraw["walk"] > 14 then
         delete item 1 of sDraw["walk"]
      end if
      repeat with tIndex = 1 to the number of items of sDraw["walk"]
         put tIndex & comma & item tIndex of sDraw["walk"] & return after tData
      end repeat
      delete the last char of tData
      set the graphData of widget "drGraph" to tData
   end if
   -- The icon changes
   if sNow > sDraw["iconAt"] and there is a widget "drIcon" then
      put sNow + 1300 into sDraw["iconAt"]
      put "star,heart,bell,music,rocket,camera,cloud,bolt,gift,trophy,magic,globe,leaf" into tPresets
      put sDraw["icon"] mod the number of items of tPresets + 1 into sDraw["icon"]
      set the iconPresetName of widget "drIcon" to item sDraw["icon"] of tPresets
      set the foregroundColor of widget "drIcon" to hmHue(sDraw["icon"] * 47, 0.8, 0.5)
   end if
   -- The donut eases to new numbers
   if sNow > sDraw["donutAt"] then
      put sNow + 1800 into sDraw["donutAt"]
      put empty into sDraw["donutTo"]
      repeat 5 times
         put 6 + random(30) & comma after sDraw["donutTo"]
      end repeat
      delete the last char of sDraw["donutTo"]
   end if
   put 0 into tTotal
   repeat with tIndex = 1 to 5
      put item tIndex of sDraw["donut"] + (item tIndex of sDraw["donutTo"] - item tIndex of sDraw["donut"]) * min(1, sDt * 4) into item tIndex of sDraw["donut"]
      add item tIndex of sDraw["donut"] to tTotal
   end repeat
   put 90 into tStart
   put 0 into tBig
   repeat with tIndex = 1 to 5
      put round(360 * item tIndex of sDraw["donut"] / tTotal) into tAngle
      if tIndex is 5 then
         put 450 - tStart into tAngle
      end if
      set the startAngle of graphic ("drD" & tIndex) to tStart mod 360
      set the arcAngle of graphic ("drD" & tIndex) to max(1, tAngle)
      add tAngle to tStart
      put max(tBig, item tIndex of sDraw["donut"] / tTotal) into tBig
   end repeat
   put round(100 * tBig) & "%" into field "drDNum"
end hmDrawFrame

################################################################################
#
# The web is yours
#

private command hmBuildWeb
   local tX, tY, tObj, tIndex, tLook
   -- Speak
   put 224 into tX
   put 92 into tY
   hmWebCard "webCard1", tX, tY, "violet", "volume-2", "Speak", "revSpeak", \
         hmPick("Your stack reads text aloud, in the voices this browser has.", "Your stack reads text aloud, in this computer's voices.")
   put hmBox("webSayBg", hmR(tX + 16, tY + 108, tX + 232, tY + 140), "248,250,252", 12, "pg_web") into tObj
   hmBorder tObj, hmColor("line")
   get hmInput("webSay", hmR(tX + 26, tY + 114, tX + 224, tY + 136), hmPick("Hello! I am a stack, in a web page.", "Hello! I am a stack, on your computer."), 13, "pg_web")
   repeat with tIndex = 1 to 9
      get hmBox("webWave" & tIndex, hmR(tX + 72 + tIndex * 10, tY + 166, tX + 78 + tIndex * 10, tY + 170), hmColor("violet"), 6, "pg_web")
   end repeat
   get hmButton("webSayBtn", tX + 16, tY + 196, 34, "Say it", "volume-2", "primary", hmColor("violet"), "pg_web", "web say", 216, "web")

   -- A QR code
   put 488 into tX
   hmWebCard "webCard2", tX, tY, "teal", "qr-code", "QR code", "qrCreate", \
         hmPick("A QR code of any text, made by the stack. Scan this page's address.", "A QR code of any text, made by the stack. Scan it with a phone.")
   put hmBox("webQRBg", hmR(tX + 78, tY + 98, tX + 170, tY + 190), "255,255,255", 10, "pg_web") into tObj
   hmBorder tObj, hmColor("line")
   create image "webQR" in group "pg_web"
   set the rect of image "webQR" to tX + 84, tY + 104, tX + 164, tY + 184
   put hmBox("webQRTextBg", hmR(tX + 16, tY + 196, tX + 232, tY + 230), "248,250,252", 12, "pg_web") into tObj
   hmBorder tObj, hmColor("line")
   get hmInput("webQRText", hmR(tX + 26, tY + 203, tX + 224, tY + 223), empty, 12, "pg_web")

   -- JavaScript
   put 752 into tX
   if hmOnWeb() then
      hmWebCard "webCard3", tX, tY, "sky", "braces", "Ask the browser", "do ... as JavaScript", \
            "One line of JavaScript, run by the stack, tells it about this browser."
      get hmLabel("webFactKeys", hmR(tX + 16, tY + 102, tX + 100, tY + 192), \
            "Language" & return & "Screen" & return & "Time zone" & return & "Theme" & return & "CPU cores", 12, hmColor("muted"), "pg_web")
   else
      hmWebCard "webCard3", tX, tY, "sky", "square-terminal", "Ask the computer", "the platform, the screenRect", \
            "A few words of xTalk tell the stack about the computer it runs on."
      get hmLabel("webFactKeys", hmR(tX + 16, tY + 102, tX + 100, tY + 192), \
            "Platform" & return & "System" & return & "Screen" & return & "Processor" & return & "Engine", 12, hmColor("muted"), "pg_web")
   end if
   put hmLabel("webFactValues", hmR(tX + 100, tY + 102, tX + 236, tY + 192), empty, 12, hmColor("ink"), "pg_web") into tObj
   set the dontWrap of tObj to true
   set the fixedLineHeight of field "webFactKeys" to true
   set the textHeight of field "webFactKeys" to 18
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 18
   get hmButton("webJsBtn", tX + 16, tY + 196, 34, "Ask again", "braces", "primary", hmColor("sky"), "pg_web", "web js", 216, "web")

   -- A link
   put 224 into tX
   put 352 into tY
   hmWebCard "webCard4", tX, tY, "indigo", "external-link", "Open the web", "launch url", \
         hmPick("launch url opens any address in a new tab of this browser.", "launch url opens any address in your web browser.")
   put hmBox("webTabBg", hmR(tX + 16, tY + 112, tX + 232, tY + 178), "248,250,252", 12, "pg_web") into tObj
   hmBorder tObj, hmColor("line")
   get hmOval("webTabDot1", hmR(tX + 28, tY + 124, tX + 36, tY + 132), "248,113,113", "pg_web")
   get hmOval("webTabDot2", hmR(tX + 40, tY + 124, tX + 48, tY + 132), "251,191,36", "pg_web")
   get hmOval("webTabDot3", hmR(tX + 52, tY + 124, tX + 60, tY + 132), "52,211,153", "pg_web")
   put hmBox("webTabUrl", hmR(tX + 28, tY + 140, tX + 220, tY + 166), "255,255,255", 10, "pg_web") into tObj
   hmBorder tObj, hmColor("line")
   get hmIcon("webTabIcon", "globe", hmColor("indigo"), hmR(tX + 36, tY + 146, tX + 50, tY + 160), "pg_web")
   put hmLabel("webTabText", hmR(tX + 56, tY + 145, tX + 216, tY + 161), "OXT-Beyond on GitHub", 12, hmColor("soft"), "pg_web") into tObj
   set the dontWrap of tObj to true
   get hmButton("webLinkBtn", tX + 16, tY + 196, 34, "Visit OXT-Beyond", "external-link", "primary", hmColor("indigo"), "pg_web", "web link", 216, "web")

   -- The clipboard
   put 488 into tX
   hmWebCard "webCard5", tX, tY, "amber", "clipboard-copy", "Copy and paste", "the clipboardData", \
         "Copy this line, paste it into the Message Box and press Return."
   put hmBox("webClipBg", hmR(tX + 16, tY + 112, tX + 232, tY + 178), hmColor("code"), 12, "pg_web") into tObj
   put hmCodeField("webClip", hmR(tX + 28, tY + 122, tX + 224, tY + 170), 12, 18, "pg_web") into tObj
   set the htmlText of tObj to hmCodeHtml(hmWebClipLine())
   get hmButton("webCopyBtn", tX + 16, tY + 196, 34, "Copy this line", "clipboard-copy", "primary", hmColor("amber"), "pg_web", "web copy", 216, "web")

   -- The user's stacks
   put 752 into tX
   if hmOnWeb() then
      hmWebCard "webCard6", tX, tY, "emerald", "hard-drive", "Your stacks", "Save and Download Stack", \
            "Stacks you save stay in this browser, even after you close the page."
   else
      hmWebCard "webCard6", tX, tY, "emerald", "hard-drive", "Your stacks", "File > Open Recent File", \
            "The stacks you opened last, ready to open again."
   end if
   get hmLabel("webCount", hmR(tX + 16, tY + 102, tX + 76, tY + 146), "0", 36, hmColor("emerald"), "pg_web")
   get hmLabel("webCountLabel", hmR(tX + 76, tY + 124, tX + 236, tY + 142), "stacks saved here", 13, hmColor("soft"), "pg_web")
   put hmLabel("webStackNames", hmR(tX + 16, tY + 150, tX + 236, tY + 190), empty, 11, hmColor("muted"), "pg_web") into tObj
   get hmButton("webOpenBtn", tX + 16, tY + 196, 34, "Open a stack", "folder-open", "primary", hmColor("emerald"), "pg_web", "web open", 216, "web")
end hmBuildWeb

private function hmWebClipLine
   -- (short enough to fit the box on one line)
   return "answer " & quote & hmPick("Hello, web IDE!", "Hello, OXT-Beyond!") & quote
end hmWebClipLine

private command hmWebCard pName, pX, pY, pAccent, pIcon, pTitle, pTag, pText
   local tObj, tAccent
   put hmColor(pAccent) into tAccent
   put hmBox(pName, hmR(pX, pY, pX + 248, pY + 244), "255,255,255", 22, "pg_web") into tObj
   hmBorder tObj, hmColor("line")
   hmShadow tObj, 12, 3, 28
   get hmBox(pName & "_chip", hmR(pX + 16, pY + 16, pX + 54, pY + 54), hmMix("255,255,255", tAccent, 0.12), 14, "pg_web")
   get hmIcon(pName & "_icon", pIcon, tAccent, hmR(pX + 25, pY + 25, pX + 45, pY + 45), "pg_web")
   get hmLabel(pName & "_title", hmR(pX + 64, pY + 15, pX + 240, pY + 35), pTitle, 16, hmColor("ink"), "pg_web")
   put hmLabel(pName & "_tag", hmR(pX + 64, pY + 37, pX + 240, pY + 53), pTag, 11, tAccent, "pg_web") into tObj
   if hmCodeFont() is not empty then
      set the textFont of tObj to hmCodeFont()
   end if
   get hmLabel(pName & "_text", hmR(pX + 16, pY + 64, pX + 234, pY + 100), pText, 12, hmColor("soft"), "pg_web")
end hmWebCard

private command hmWebStart
   if field "webQRText" is empty then
      put hmPageAddress() into field "webQRText"
   end if
   hmWebQR
   hmWebFacts
   hmWebCountStacks
   put 0 into sWeb["sayUntil"]
end hmWebStart

-- The address of this page, as the browser has it
private function hmPageAddress
   local tAddress, tError
   if the platform is "HTML5" then
      try
         do "window.location.href" as "JavaScript"
         put the result into tAddress
      catch tError
      end try
   end if
   if tAddress is empty then
      put "https://github.com/SethMorrowSoftware/OpenXTalk-Beyond" into tAddress
   end if
   return tAddress
end hmPageAddress

private command hmWebQR
   local tText, tError, tSize, tScale
   put empty into sWeb["qrDue"]
   put field "webQRText" into tText
   if tText is empty then
      put " " into tText
   end if
   try
      qrCreate "webQR", tText, "M", 1
      put the width of image "webQR" into tSize
      put max(1, 80 div tSize) into tScale
      if tScale > 1 then
         qrCreate "webQR", tText, "M", tScale
      end if
      put the width of image "webQR" into tSize
      set the loc of image "webQR" to 488 + 124 + sOX, 92 + 144 + sOY
      set the resizeQuality of image "webQR" to "normal"
   catch tError
      hmStatus "The QR code could not be made:" && hmErrorText(tError), "bad"
   end try
end hmWebQR

private command hmWebFacts
   local tFacts, tError
   if the platform is "HTML5" then
      try
         do "[navigator.language, screen.width + ' x ' + screen.height, " & \
               "Intl.DateTimeFormat().resolvedOptions().timeZone, " & \
               "window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light', " & \
               "String(navigator.hardwareConcurrency || '?')].join('\n')" as "JavaScript"
         put the result into tFacts
      catch tError
      end try
   end if
   if tFacts is empty and not hmOnWeb() then
      try
         put the platform & return & the systemVersion & return & \
               (item 3 of the screenRect - item 1 of the screenRect) && "x" && (item 4 of the screenRect - item 2 of the screenRect) & return & \
               the processor & return & the version into tFacts
      catch tError
      end try
   end if
   if tFacts is empty then
      put "(a browser has these)" into tFacts
   end if
   put tFacts into field "webFactValues"
end hmWebFacts

private command hmWebCountStacks
   local tFiles, tFile, tCount, tNames, tError
   put 0 into tCount
   if not hmOnWeb() then
      hmRecentStacks
      exit hmWebCountStacks
   end if
   try
      put files(revWebIDEStacksFolder()) into tFiles
   catch tError
   end try
   repeat for each line tFile in tFiles
      set the itemDelimiter to "."
      if item -1 of tFile is among the items of "livecode,oxtstack,rev,livecodescript,oxtscript,stack" then
         add 1 to tCount
         if tCount <= 3 then
            put item 1 to -2 of tFile & return after tNames
         end if
      end if
      set the itemDelimiter to comma
   end repeat
   put tCount into field "webCount"
   if tCount is 1 then
      put "stack saved here" into field "webCountLabel"
   else
      put "stacks saved here" into field "webCountLabel"
   end if
   -- (the words follow the number, however wide it is)
   set the left of field "webCountLabel" to the left of field "webCount" + the formattedWidth of field "webCount" + 6
   if tCount is 0 then
      put "None yet: your first app makes one in a click." into field "webStackNames"
   else
      replace return with ", " in tNames
      put char 1 to -3 of tNames into field "webStackNames"
   end if
end hmWebCountStacks

-- On the desktop, the card of the user's stacks shows the stacks opened
-- last (File > Open Recent File), and a click on one opens it
private command hmRecentStacks
   local tRecent, tCount, tIndex, tHtml, tError
   try
      put revIDERecentStacks() into tRecent
   catch tError
   end try
   put 0 into tCount
   repeat with tIndex = 1 to the number of elements of tRecent
      if there is a file tRecent[tIndex]["filename"] then
         add 1 to tCount
         if tCount <= 3 then
            put "<p><a href=" & quote & replaceText(hmEscape(tRecent[tIndex]["filename"]), quote, "&quot;") & quote & ">" & \
                  hmEscape(tRecent[tIndex]["label"]) & "</a></p>" after tHtml
         end if
      end if
   end repeat
   put tCount into field "webCount"
   if tCount is 1 then
      put "recent stack" into field "webCountLabel"
   else
      put "recent stacks" into field "webCountLabel"
   end if
   set the left of field "webCountLabel" to the left of field "webCount" + the formattedWidth of field "webCount" + 6
   if tCount is 0 then
      put "None yet: the stacks you open show here." into field "webStackNames"
   else
      set the htmlText of field "webStackNames" to tHtml
   end if
end hmRecentStacks

on linkClicked pLink
   local tError
   if the short name of the target is not "webStackNames" then
      pass linkClicked
   end if
   if there is not a file pLink then
      hmStatus "That stack is no longer where it was.", "warn"
      exit linkClicked
   end if
   try
      revIDEOpenStack pLink
   catch tError
      hmStatus "That stack could not open:" && hmErrorText(tError), "bad"
   end try
end linkClicked

private command hmWebDo pWhat
   local tError
   switch pWhat
      case "say"
         hmWebSay
         break
      case "js"
         hmWebFacts
         hmStatus hmPick("Asked the browser again.", "Asked the computer again."), "ok"
         break
      case "link"
         try
            launch url "https://github.com/SethMorrowSoftware/OpenXTalk-Beyond"
            hmStatus hmPick("Opened in a new tab (if the browser blocked it, allow pop-ups for this page).", "Opened in your web browser."), "ok"
         catch tError
            hmStatus "The link could not open:" && hmErrorText(tError), "bad"
         end try
         break
      case "copy"
         try
            set the clipboardData["text"] to hmWebClipLine()
            hmStatus "Copied. Now open the Message Box, paste the line and press Return.", "ok"
         catch tError
            hmStatus hmPick("This browser would not let the page copy:", "The line could not be copied:") && hmErrorText(tError), "bad"
         end try
         break
      case "open"
         hmIde "open"
         break
   end switch
end hmWebDo

private command hmWebSay
   local tError
   try
      revSpeak field "webSay"
      put sNow + 2600 into sWeb["sayUntil"]
      if the number of lines of revSpeechVoices() is 0 then
         hmStatus hmPick("Speaking with the browser's voice (if you hear nothing, this browser has no voices yet).", \
               "Speaking with the computer's voice (if you hear nothing, it has no voices installed)."), "ok"
      else
         hmStatus "Speaking with one of" && the number of lines of revSpeechVoices() && "voices.", "ok"
      end if
   catch tError
      hmStatus hmPick("This browser could not speak:", "This computer could not speak:") && hmErrorText(tError), "bad"
   end try
end hmWebSay

private command hmWebFrame
   local tIndex, tH, tX, tT
   if sWeb["qrDue"] is not empty and sNow > sWeb["qrDue"] then
      hmWebQR
   end if
   put sNow / 1000 into tT
   repeat with tIndex = 1 to 9
      if sNow < sWeb["sayUntil"] then
         put 4 + round(26 * abs(sin(tT * 9 + tIndex * 0.9)) * abs(sin(tT * 3.1 + tIndex))) into tH
      else
         put 4 + round(3 * (0.5 + 0.5 * sin(tT * 2 + tIndex * 0.6))) into tH
      end if
      put the left of graphic ("webWave" & tIndex) into tX
      set the rect of graphic ("webWave" & tIndex) to tX, 92 + sOY + 168 - tH div 2, tX + 6, 92 + sOY + 168 - tH div 2 + tH
   end repeat
end hmWebFrame

################################################################################
#
# Your first app
#

private command hmBuildApp
   local tObj, tIndex, tCx, tSteps, tStep
   put hmBox("apStepsBg", "224,92,1000,300", "255,255,255", 22, "pg_app") into tObj
   hmBorder tObj, hmColor("line")
   hmShadow tObj, 12, 3, 30
   get hmBox("apTrack", "321,150,903,154", hmColor("line"), 4, "pg_app")
   put hmBox("apProgress", "321,150,323,154", hmColor("emerald"), 4, "pg_app") into tObj
   put "Draw|mouse-pointer-click|Drag a button and a field from the Tools palette onto a card." & return & \
         "Script|code|Edit the button's script: on mouseUp, say what happens." & return & \
         "Run|play|Choose the Run tool and click. Your app works at once." & return & \
         hmPick("Share|share-2|Save it in this browser, or Download Stack to keep a copy.", \
         "Share|share-2|Save it, or make it an app with Standalone Application Settings.") into tSteps
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put line tIndex of tSteps into tStep
      put 321 + (tIndex - 1) * 194 into tCx
      put hmOval("apNode" & tIndex, hmR(tCx - 30, 122, tCx + 30, 182), hmColor("emerald"), "pg_app") into tObj
      hmGradient tObj, "16,185,129|13,148,136", (tCx - 30) & ",122", (tCx + 30) & ",182"
      get hmIcon("apIcon" & tIndex, item 2 of tStep, "255,255,255", hmR(tCx - 13, 139, tCx + 13, 165), "pg_app")
      put hmOval("apBadge" & tIndex, hmR(tCx + 16, 118, tCx + 38, 140), "255,255,255", "pg_app") into tObj
      hmBorder tObj, hmColor("emerald")
      put hmLabel("apBadgeNum" & tIndex, hmR(tCx + 16, 124, tCx + 38, 140), tIndex, 11, hmColor("emerald"), "pg_app", "center") into tObj
      set the textStyle of tObj to "bold"
      get hmLabel("apTitle" & tIndex, hmR(tCx - 92, 194, tCx + 92, 214), item 1 of tStep, 15, hmColor("ink"), "pg_app", "center")
      get hmLabel("apText" & tIndex, hmR(tCx - 88, 218, tCx + 88, 262), item 3 of tStep, 12, hmColor("soft"), "pg_app", "center")
   end repeat
   set the itemDelimiter to comma
   put hmOval("apDot", "315,146,327,158", "255,255,255", "pg_app") into tObj
   hmBorder tObj, hmColor("emerald")
   hmGlow tObj, "16,185,129", 14, 220

   put hmBox("apCodeBg", "224,316,600,596", hmColor("code"), 22, "pg_app") into tObj
   hmShadow tObj, 18, 6, 50
   get hmLabel("apCodeTitle", "240,330,590,346", "The Say hello button's script: the whole app", 11, hmColor("muted"), "pg_app")
   put hmCodeField("apCode", "240,356,592,500", 13, 24, "pg_app") into tObj
   set the htmlText of tObj to hmCodeHtml(hmFirstAppScript())
   get hmLabel("apCodeNote", "240,520,588,584", \
         "A field for your name, a button, and these lines. Every word is in the Dictionary, with examples.", \
         12, hmColor("muted"), "pg_app")

   get hmGroup("apCta", "616,316,1000,596", "pg_app")
   put hmBox("apCtaBg", "612,312,1004,600", hmColor("emerald"), 0, "apCta") into tObj
   hmGradient tObj, "5,150,105|13,148,136|2,132,199", "616,316", "1000,596"
   put hmOval("apCtaRing1", "860,276,1060,476", "255,255,255", "apCta") into tObj
   set the blendLevel of tObj to 88
   put hmOval("apCtaRing2", "920,236,1100,416", "255,255,255", "apCta") into tObj
   set the blendLevel of tObj to 90
   get hmLabel("apCtaTitle", "640,338,980,372", "Make your first app", 24, "255,255,255", "apCta")
   get hmLabel("apCtaText", "640,378,980,440", \
         "Home makes a stack with a field and a button, and switches to the Run tool. Type your name and click Say hello.", \
         13, "236,253,245", "apCta")
   get hmButton("apMake", 640, 452, 44, "Make my first app", "wand-sparkles", "light", hmColor("emerald"), "apCta", "make", 220, "app")
   hmGlow the long id of graphic "apMake_bg", "255,255,255", 12, 150
   hmRoom "apMake", 14
   get hmLabel("apCtaNote", "640,512,984,584", \
         hmPick("Then File > Save keeps it in this browser, and File > Download Stack gives you a copy to share.", \
         "Then File > Save keeps it, and File > Standalone Application Settings turns it into an app to share."), \
         12, "209,250,229", "apCta")
   hmCorners "apCorner", "616,316,1000,596", 22, hmColor("bg"), "apCta"
end hmBuildApp

private function hmFirstAppScript
   local tScript
   put "on mouseUp" & return & \
         "   put 'Hello,' && field 'Name' & '!' \" & return & \
         "         into field 'Greeting'" & return & \
         "   set the textColor of field 'Greeting' to \" & return & \
         "         any item of 'red,blue,purple,orange'" & return & \
         "end mouseUp" into tScript
   replace "'" with quote in tScript
   return tScript
end hmFirstAppScript

private command hmAppStart
   put 0 into sApp["lit"]
end hmAppStart

private command hmAppFrame
   local tT, tP, tX, tIndex, tCx, tLit
   put (sNow mod 6000) / 6000 into tP
   put hmEase(min(1, tP / 0.8)) into tP
   put round(321 + 582 * tP) into tX
   set the rect of graphic "apProgress" to 321 + sOX, 150 + sOY, max(323, tX) + sOX, 154 + sOY
   set the loc of graphic "apDot" to tX + sOX, 152 + sOY
   put 0 into tLit
   repeat with tIndex = 1 to 4
      put 321 + (tIndex - 1) * 194 into tCx
      if tX >= tCx - 4 then
         put tIndex into tLit
      end if
   end repeat
   if tLit is not sApp["lit"] then
      repeat with tIndex = 1 to 4
         if tIndex <= tLit then
            hmGlow the long id of graphic ("apNode" & tIndex), "16,185,129", 18, 170
         else
            set the outerGlow of graphic ("apNode" & tIndex) to empty
         end if
      end repeat
      put tLit into sApp["lit"]
   end if
   put sNow / 1000 into tT
   set the outerGlow["size"] of graphic "apMake_bg" to round(10 + 8 * (0.5 + 0.5 * sin(tT * 3)))
end hmAppFrame

-- Makes the stack "My First App": a field for a name, a Say hello button
-- with the script on this page, and a field it greets in. Then the Run
-- tool, so that it works at once.
private command hmMakeFirstApp
   local tName, tNumber, tObj, tError
   put "My First App" into tName
   put 1 into tNumber
   repeat while there is a stack tName
      add 1 to tNumber
      put "My First App" && tNumber into tName
   end repeat
   try
      create stack tName
      set the defaultStack to tName
      set the width of stack tName to 460
      set the height of stack tName to 300
      set the backgroundColor of card 1 of stack tName to "248,250,252"
      create field "Title"
      put it into tObj
      set the rect of tObj to 24,18,436,52
      set the textSize of tObj to 22
      set the lockText of tObj to true
      set the showBorder of tObj to false
      set the opaque of tObj to false
      set the traversalOn of tObj to false
      set the text of tObj to "My First App"
      create field "Label"
      put it into tObj
      set the rect of tObj to 24,64,300,84
      set the lockText of tObj to true
      set the showBorder of tObj to false
      set the opaque of tObj to false
      set the traversalOn of tObj to false
      set the text of tObj to "Your name"
      create field "Name"
      put it into tObj
      set the rect of tObj to 24,86,300,114
      set the textSize of tObj to 14
      set the text of tObj to "Ada"
      create button "Say hello"
      put it into tObj
      set the rect of tObj to 316,84,436,116
      set the script of tObj to hmFirstAppScript()
      if the result is not empty then
         throw "its script has an error on line" && item 2 of line 1 of the result
      end if
      create field "Greeting"
      put it into tObj
      set the rect of tObj to 24,140,436,200
      set the textSize of tObj to 24
      set the lockText of tObj to true
      set the showBorder of tObj to false
      set the opaque of tObj to false
      set the traversalOn of tObj to false
      create field "Hint"
      put it into tObj
      set the rect of tObj to 24,232,436,284
      set the lockText of tObj to true
      set the showBorder of tObj to false
      set the opaque of tObj to false
      set the traversalOn of tObj to false
      set the textColor of tObj to "100,116,139"
      set the text of tObj to "Type a name and click Say hello. To change the app, choose the Edit tool, click the button, then click Script in the toolbar."
      set the loc of stack tName to the loc of me
      choose browse tool
      hmStatus "Made" && quote & tName & quote & ". Type a name in it and click Say hello.", "ok"
   catch tError
      hmStatus "The stack could not be made:" && hmErrorText(tError), "bad"
   end try
end hmMakeFirstApp

################################################################################
#
# Icons
#

-- Lucide's icons (lucide-static 0.469.0), the inside of each icon's <svg>,
-- under Lucide's licence:
--
-- ISC License
--
-- Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as
-- part of Feather (MIT). All other copyright (c) for Lucide are held by
-- Lucide Contributors 2022.
--
-- Permission to use, copy, modify, and/or distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
-- ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
-- ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
-- OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
private function hmIconPaths pName
   switch pName
      case "house"
         return "<path d='M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8'/><path d='M3 10a2 2 0 0 1 .709-1.528l" & \
               "7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'/>"
      case "square-terminal"
         return "<path d='m7 11 2-2-2-2'/><path d='M11 13h4'/><rect width='18' height='18' x='3' y='3' rx='" & \
               "2' ry='2'/>"
      case "orbit"
         return "<circle cx='12' cy='12' r='3'/><circle cx='19' cy='5' r='2'/><circle cx='5' cy='19' r='2'/" & \
               "><path d='M10.4 21.9a10 10 0 0 0 9.941-15.416'/><path d='M13.5 2.1a10 10 0 0 0-9.841 15.41" & \
               "6'/>"
      case "palette"
         return "<circle cx='13.5' cy='6.5' r='.5' fill='currentColor'/><circle cx='17.5' cy='10.5' r='.5' " & \
               "fill='currentColor'/><circle cx='8.5' cy='7.5' r='.5' fill='currentColor'/><circle cx='6.5" & \
               "' cy='12.5' r='.5' fill='currentColor'/><path d='M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 " & \
               "0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.6" & \
               "4 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z'/>"
      case "globe"
         return "<circle cx='12' cy='12' r='10'/><path d='M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20'/" & \
               "><path d='M2 12h20'/>"
      case "rocket"
         return "<path d='M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2" & \
               ".91-.09z'/><path d='m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 " & \
               "11a22.35 22.35 0 0 1-4 2z'/><path d='M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0'/><path d='M12" & \
               " 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5'/>"
      case "graduation-cap"
         return "<path d='M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0" & \
               " 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z'/><path d='M22 10v6'/><path d='M6 12.5V16a6 3 0 0 0 " & \
               "12 0v-3.5'/>"
      case "file-plus"
         return "<path d='M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z'/><path d='M14 2v4a2 2" & \
               " 0 0 0 2 2h4'/><path d='M9 15h6'/><path d='M12 18v-6'/>"
      case "folder-open"
         return "<path d='m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H" & \
               "4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1" & \
               " 2 2v2'/>"
      case "book-open-text"
         return "<path d='M12 7v14'/><path d='M16 12h2'/><path d='M16 8h2'/><path d='M3 18a1 1 0 0 1-1-1V4a" & \
               "1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-" & \
               "3 3 3 3 0 0 0-3-3z'/><path d='M6 12h2'/><path d='M6 8h2'/>"
      case "layers"
         return "<path d='M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0" & \
               "l8.58-3.9a1 1 0 0 0 0-1.83z'/><path d='M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8." & \
               "58-3.9A1 1 0 0 0 22 12'/><path d='M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3." & \
               "9A1 1 0 0 0 22 17'/>"
      case "volume-2"
         return "<path d='M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0" & \
               "-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z'/>" & \
               "<path d='M16 9a5 5 0 0 1 0 6'/><path d='M19.364 18.364a9 9 0 0 0 0-12.728'/>"
      case "qr-code"
         return "<rect width='5' height='5' x='3' y='3' rx='1'/><rect width='5' height='5' x='16' y='3' rx=" & \
               "'1'/><rect width='5' height='5' x='3' y='16' rx='1'/><path d='M21 16h-3a2 2 0 0 0-2 2v3'/>" & \
               "<path d='M21 21v.01'/><path d='M12 7v3a2 2 0 0 1-2 2H7'/><path d='M3 12h.01'/><path d='M12" & \
               " 3h.01'/><path d='M12 16v.01'/><path d='M16 12h1'/><path d='M21 12v.01'/><path d='M12 21v-" & \
               "1'/>"
      case "braces"
         return "<path d='M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5c0 1.1.9 2 2 2h1'/><path d='M" & \
               "16 21h1a2 2 0 0 0 2-2v-5c0-1.1.9-2 2-2a2 2 0 0 1-2-2V5a2 2 0 0 0-2-2h-1'/>"
      case "external-link"
         return "<path d='M15 3h6v6'/><path d='M10 14 21 3'/><path d='M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-" & \
               "2V8a2 2 0 0 1 2-2h6'/>"
      case "clipboard-copy"
         return "<rect width='8' height='4' x='8' y='2' rx='1' ry='1'/><path d='M8 4H6a2 2 0 0 0-2 2v14a2 2" & \
               " 0 0 0 2 2h12a2 2 0 0 0 2-2v-2'/><path d='M16 4h2a2 2 0 0 1 2 2v4'/><path d='M21 14H11'/><" & \
               "path d='m15 10-4 4 4 4'/>"
      case "hard-drive"
         return "<line x1='22' x2='2' y1='12' y2='12'/><path d='M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 " & \
               "0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z'/><line x1='6' x2='6.01' y" & \
               "1='16' y2='16'/><line x1='10' x2='10.01' y1='16' y2='16'/>"
      case "mouse-pointer-click"
         return "<path d='M14 4.1 12 6'/><path d='m5.1 8-2.9-.8'/><path d='m6 12-1.9 2'/><path d='M7.2 2.2 " & \
               "8 5.1'/><path d='M9.037 9.69a.498.498 0 0 1 .653-.653l11 4.5a.5.5 0 0 1-.074.949l-4.349 1." & \
               "041a1 1 0 0 0-.74.739l-1.04 4.35a.5.5 0 0 1-.95.074z'/>"
      case "code"
         return "<polyline points='16 18 22 12 16 6'/><polyline points='8 6 2 12 8 18'/>"
      case "play"
         return "<polygon points='6 3 20 12 6 21 6 3'/>"
      case "share-2"
         return "<circle cx='18' cy='5' r='3'/><circle cx='6' cy='12' r='3'/><circle cx='18' cy='19' r='3'/" & \
               "><line x1='8.59' x2='15.42' y1='13.51' y2='17.49'/><line x1='15.41' x2='8.59' y1='6.51' y2" & \
               "='10.49'/>"
      case "sparkles"
         return "<path d='M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0" & \
               " 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5." & \
               "5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z'/><path d" & \
               "='M20 3v4'/><path d='M22 5h-4'/><path d='M4 17v2'/><path d='M5 18H3'/>"
      case "wand-sparkles"
         return "<path d='m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1." & \
               "28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72'/><path d='m14 7 3 3'/><path " & \
               "d='M5 6v4'/><path d='M19 14v4'/><path d='M10 2v2'/><path d='M7 8H3'/><path d='M21 16h-4'/>" & \
               "<path d='M11 3H9'/>"
      case "chevron-left"
         return "<path d='m15 18-6-6 6-6'/>"
      case "chevron-right"
         return "<path d='m9 18 6-6-6-6'/>"
   end switch
   return empty
end hmIconPaths
