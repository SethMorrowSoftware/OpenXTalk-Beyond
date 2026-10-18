script "revLearnKit"
-- OXT-Beyond: the look of the IDE's learning windows.
--
-- Learn (the lessons, the guides and the examples) is drawn with these
-- handlers, and the demos remastered in its look are too, so that what a
-- newcomer reads or runs to learn xTalk looks like one family: a dark
-- sidebar with a mark, a list of places and Back and Next; a header with
-- a title, a tagline and an accent colour; white panels on slate; code on
-- dark panels, in colour. The palette is read through lkColor, and the
-- icons are Lucide's (ISC licence, see THIRD-PARTY-NOTICES.md), drawn by
-- drawingSvgCompile. The handlers began as Home's (revWebHome).
--
-- A stack uses the kit as its behavior:
--
--    set the behavior of me to the long id of stack "revLearnKit"
--
-- and not as a library, so that its handlers are in that stack's message
-- path and no other: a user's stack that has a handler of the same name
-- never meets them. Its script locals are that stack's own.
--
-- What the kit does for its stack:
--  - builds controls: lkBox, lkLabel, lkGroup, lkIcon, lkButton and so on,
--    each taking a name, a rect and the group to make it in;
--  - lights things up: a group that lkLive registers lights up when the
--    pointer is over it, slides in when its scope (a page) opens with
--    lkEnter, and on a click sends its action to the stack as
--    "lkAction pAction";
--  - scrolls: lkScroller puts a slim thumb in place of a group's or a
--    field's scrollbar, which the wheel and a drag move, smoothly;
--  - keeps time: lkStartTicking sends lkTick about sixty times a second
--    (ten while another window is in front), which animates the lit
--    things and then sends lkFrame to the stack for its own animations;
--    lkNow and lkDt give the frame's time and the seconds since the last.
-- A timer handler runs whatever stack is in front, so each frame sets the
-- defaultStack to the kit's stack and puts it back.

constant kFrame = 16
constant kAwayFrame = 100
constant kTextInset = 4

-- The groups that light up when the pointer is over them and do something
-- when clicked, by name: what each one does and how it looks; the names
-- registered for each scope (a page, or "side" for what is always shown)
local sCfg, sLiveList, sHover, sHoverAmt, sEnterAmt
-- The scope in front, and the time it opened (its lit things slide in)
local sScope, sScopeStart
-- The pending frame, this frame's time, and the time since the last one
local sTick, sNow, sLastFrame, sDt
-- True while another window is in front: frames come ten times a second
local sAway
-- The font code is shown in ("-" for the default font)
local sFont
-- The thumbs lkScroller made, by name: each one's target, colour and
-- blend, where the wheel is taking the target and the scroll last set;
-- and the thumb being dragged
local sScroll, sDrag

################################################################################
#
# Time
#

command lkStartTicking
   lkStopTicking
   put the milliseconds into sLastFrame
   put sLastFrame into sNow
   send "lkTick" to me in kFrame milliseconds
   put the result into sTick
end lkStartTicking

command lkStopTicking
   if sTick is not empty then
      cancel sTick
      put empty into sTick
   end if
   if sHover is not empty then
      put empty into sHover
      unlock cursor
   end if
end lkStopTicking

-- One frame. A frame that fails is skipped, not shown as an error sixty
-- times a second.
on lkTick
   local tSaved, tError
   put empty into sTick
   if the mode of me is 0 then
      exit lkTick
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   put the milliseconds into sNow
   put min(0.1, max(0, (sNow - sLastFrame) / 1000)) into sDt
   put sNow into sLastFrame
   lock screen
   try
      lkScrollFrame
      lkLiveFrame
      dispatch "lkFrame" to me
   catch tError
   end try
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
   if sAway is true then
      send "lkTick" to me in kAwayFrame milliseconds
   else
      send "lkTick" to me in kFrame milliseconds
   end if
   put the result into sTick
end lkTick

function lkNow
   return sNow
end lkNow

function lkDt
   return sDt
end lkDt

function lkAway
   return sAway is true
end lkAway

on suspendStack
   put true into sAway
   -- (the pointer has gone to the other window, and no mouseMove says so)
   lkHoverOn empty
   pass suspendStack
end suspendStack

on resumeStack
   put false into sAway
   pass resumeStack
end resumeStack

################################################################################
#
# The look
#

-- The palette: the web tour's, and a few colours of the sidebar and the
-- code panels. Nothing else names a colour.
function lkColor pName
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
end lkColor

-- pFrom mixed with pTo: 0 is pFrom, 1 is pTo
function lkMix pFrom, pTo, pAmount
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
end lkMix

function lkHex pColor
   return "#" & format("%02x%02x%02x", item 1 of pColor, item 2 of pColor, item 3 of pColor)
end lkHex

-- A colour from its hue (0 to 360), saturation and lightness (0 to 1)
function lkHue pHue, pSat, pLight
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
end lkHue

-- Slow at the end, as things in the world come to rest
function lkEase pT
   if pT <= 0 then
      return 0
   end if
   if pT >= 1 then
      return 1
   end if
   return 1 - (1 - pT) ^ 3
end lkEase

-- The rect of a control is set from four numbers in lkButton, so lkGroup
-- and lkBox take a rect as items: these wrappers keep the calls short
function lkR pLeft, pTop, pRight, pBottom
   return pLeft & "," & pTop & "," & pRight & "," & pBottom
end lkR

################################################################################
#
# Building blocks
#

function lkBox pName, pRect, pColor, pRadius, pGroup
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
end lkBox

function lkOval pName, pRect, pColor, pGroup
   local tObj
   put lkBox(pName, pRect, pColor, 0, pGroup) into tObj
   set the style of tObj to "oval"
   return tObj
end lkOval

command lkBorder pObj, pColor
   set the lineSize of pObj to 1
   set the foregroundColor of pObj to pColor
end lkBorder

function lkLabel pName, pRect, pText, pSize, pColor, pGroup, pAlign
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
end lkLabel

-- A label kept to one line: if its text is too wide, it loses letters at
-- its end and gains an ellipsis
command lkEllipsize pObj
   local tText
   set the dontWrap of pObj to true
   if the formattedWidth of pObj <= the width of pObj then
      exit lkEllipsize
   end if
   put the text of pObj into tText
   repeat while the number of chars of tText > 1 and the formattedWidth of pObj > the width of pObj
      delete the last char of tText
      set the text of pObj to word 1 to -1 of tText & numToCodepoint(8230)
   end repeat
end lkEllipsize

-- A field the user types in, without a border of its own: it sits on a
-- rounded box
function lkInput pName, pRect, pText, pSize, pGroup
   local tObj
   put lkLabel(pName, pRect, pText, pSize, lkColor("ink"), pGroup) into tObj
   -- (a left margin too, or the caret at the start hides the first letter's edge)
   set the margins of tObj to "4," & kTextInset & ",4,0"
   set the left of tObj to item 1 of pRect - 4
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the autoTab of tObj to false
   return tObj
end lkInput

-- A code panel's text: the code font, a fixed line height
function lkCodeField pName, pRect, pSize, pLineHeight, pGroup
   local tObj
   put lkLabel(pName, pRect, empty, pSize, lkColor("codeInk"), pGroup) into tObj
   if lkCodeFont() is not empty then
      set the textFont of tObj to lkCodeFont()
   end if
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to pLineHeight
   return tObj
end lkCodeField

function lkGroup pName, pRect, pGroup
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
end lkGroup

-- An icon: Lucide's 24 by 24 drawing, stroked in a colour
function lkIcon pName, pIcon, pColor, pRect, pGroup
   local tObj
   if pGroup is empty then
      create image pName
   else
      create image pName in group pGroup
   end if
   put it into tObj
   lkIconInk tObj, pIcon, pColor
   set the lockLoc of tObj to true
   set the rect of tObj to pRect
   return tObj
end lkIcon

command lkIconInk pObj, pIcon, pColor
   local tHex, tSvg
   put lkHex(pColor) into tHex
   put "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" & tHex & \
         "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>" & \
         lkIconPaths(pIcon) & "</svg>" into tSvg
   replace "currentColor" with tHex in tSvg
   set the text of pObj to drawingSvgCompile(tSvg)
end lkIconInk

-- An image of a drawing
function lkDrawing pName, pSvg, pRect, pGroup
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
end lkDrawing

-- A linear gradient through pColors ("r,g,b|r,g,b|..."), from pFrom to pTo
command lkGradient pObj, pColors, pFrom, pTo
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
   lkGradientPoints pObj, pFrom, pTo
end lkGradient

command lkGradientPoints pObj, pFrom, pTo
   set the fillGradient["from"] of pObj to pFrom
   set the fillGradient["to"] of pObj to pTo
   set the fillGradient["via"] of pObj to \
         (item 1 of pFrom - (item 2 of pTo - item 2 of pFrom)) & "," & \
         (item 2 of pFrom + (item 1 of pTo - item 1 of pFrom))
end lkGradientPoints

-- A soft round light: pColor in the middle, fading to nothing
command lkGlowFill pObj, pColor, pAlpha
   set the fillGradient["type"] of pObj to "radial"
   set the fillGradient["ramp"] of pObj to "0.000," & pColor & "," & pAlpha & return & \
         "0.550," & pColor & "," & round(pAlpha / 3) & return & "1.000," & pColor & ",0"
   lkGlowCentre pObj
end lkGlowFill

command lkGlowCentre pObj
   local tLoc, tRadius
   put the loc of pObj into tLoc
   put the width of pObj div 2 into tRadius
   set the fillGradient["from"] of pObj to tLoc
   set the fillGradient["to"] of pObj to (item 1 of tLoc + tRadius) & "," & item 2 of tLoc
   set the fillGradient["via"] of pObj to item 1 of tLoc & "," & (item 2 of tLoc + tRadius)
end lkGlowCentre

command lkShadow pObj, pSize, pDistance, pOpacity
   set the dropShadow["color"] of pObj to "15,23,42"
   set the dropShadow["blendMode"] of pObj to "normal"
   set the dropShadow["angle"] of pObj to 90
   set the dropShadow["size"] of pObj to pSize
   set the dropShadow["distance"] of pObj to pDistance
   set the dropShadow["opacity"] of pObj to pOpacity
end lkShadow

command lkGlow pObj, pColor, pSize, pOpacity
   set the outerGlow["color"] of pObj to pColor
   set the outerGlow["blendMode"] of pObj to "normal"
   set the outerGlow["size"] of pObj to pSize
   set the outerGlow["opacity"] of pObj to pOpacity
end lkGlow

-- A group clips what it holds to a rectangle; these four corners, in the
-- colour behind it, round the rectangle off. Each reaches 2 pixels past
-- the rectangle, where the group clips it, so that no edge of it shows.
command lkCorners pPrefix, pRect, pRadius, pColor, pGroup
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
            put return & lkPastEdge(tPx, tPy, tX, tSx, tSy) after tPoints
         end if
         put return & tPx & "," & tPy after tPoints
         if tStep is 12 then
            put return & lkPastEdge(tPx, tPy, tX, tSx, tSy) after tPoints
         end if
      end repeat
      put return & (tX + 2 * tSx) & "," & (tY + 2 * tSy) after tPoints
      put lkBox(pPrefix & tCorner, pRect, pColor, 0, pGroup) into tObj
      set the style of tObj to "polygon"
      set the points of tObj to tPoints
   end repeat
end lkCorners

-- A point of a corner's arc that is on the rectangle's edge, 2 pixels out
function lkPastEdge pX, pY, pEdgeX, pSx, pSy
   if pX is pEdgeX then
      return (pX + 2 * pSx) & "," & pY
   end if
   return pX & "," & (pY + 2 * pSy)
end lkPastEdge

-- A four-pointed sparkle
function lkSparklePoints pX, pY, pSize
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
end lkSparklePoints

-- A star of pPoints points, turned by pTurn radians
function lkStarPoints pX, pY, pOuter, pInner, pPoints, pTurn
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
end lkStarPoints

-- The font code is shown in: Source Code Pro, which the IDE carries for
-- its Script Editor, or Droid Sans Mono, or else the default font
function lkCodeFont
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
end lkCodeFont

-- A group clips what it holds to its rect, a shadow or a glow included:
-- this widens group pName past its box by pPad (twice that below, where a
-- shadow falls), so the effect shows whole. Setting a group's rect moves
-- its controls with its top left, so they are moved back.
command lkRoom pName, pPad
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
end lkRoom

################################################################################
#
# Things that light up and do something
#

-- Makes a group a thing the pointer lights up and a click sets off.
-- pLook holds how it looks at rest and lit, as "bg", "bg0", "bg1",
-- "line0", "line1", "blend0", "blend1", "label", "ink0", "ink1", "lift",
-- "shadow" and "enter" (its turn to slide in when its page opens).
command lkLive pName, pPage, pAction, pLook
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
end lkLive

-- Draws a lit thing as it is: pName's hover and slide-in amounts
command lkApply pName
   local tH, tE, tBg, tTop, tLabel
   put lkEase(sHoverAmt[pName]) into tH
   put lkEase(sEnterAmt[pName]) into tE
   put sCfg[pName]["bg"] into tBg
   if tBg is not empty then
      if sCfg[pName]["bg0"] is not empty then
         set the backgroundColor of graphic tBg to lkMix(sCfg[pName]["bg0"], sCfg[pName]["bg1"], tH)
      end if
      if sCfg[pName]["line0"] is not empty then
         set the foregroundColor of graphic tBg to lkMix(sCfg[pName]["line0"], sCfg[pName]["line1"], tH)
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
      set the textColor of field tLabel to lkMix(sCfg[pName]["ink0"], sCfg[pName]["ink1"], tH)
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
end lkApply

-- The lit thing a control belongs to, if any
function lkLiveOf pObj
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
end lkLiveOf

command lkHoverOn pName
   if pName is sHover then
      exit lkHoverOn
   end if
   put pName into sHover
   if pName is empty then
      unlock cursor
   else
      lock cursor
      set the cursor to hand
   end if
end lkHoverOn

on mouseMove
   local tName
   if sDrag["name"] is not empty then
      lkScrollDrag
      exit mouseMove
   end if
   put lkLiveOf(the long id of the target) into tName
   lkHoverOn tName
   pass mouseMove
end mouseMove

-- A click on a lit thing sends its action to the stack
on mouseUp pButton
   local tName
   if sDrag["name"] is not empty then
      put empty into sDrag
   end if
   put lkLiveOf(the long id of the target) into tName
   if pButton is 1 and tName is not empty then
      dispatch "lkAction" to me with sCfg[tName]["action"]
   else
      pass mouseUp
   end if
end mouseUp

-- The scope pScope comes to the front: its lit things slide in, each in
-- its turn ("enter" in its look), and lose any light they had
command lkEnter pScope
   local tName
   put pScope into sScope
   put sNow into sScopeStart
   if sScopeStart is empty then
      put the milliseconds into sScopeStart
   end if
   repeat for each line tName in sLiveList[pScope]
      if sCfg[tName]["enter"] is not empty then
         put 0 into sEnterAmt[tName]
      end if
      put 0 into sHoverAmt[tName]
      lkApply tName
   end repeat
end lkEnter

-- Forgets the lit things of scope pScope, before its controls are deleted
command lkForget pScope
   local tName
   repeat for each line tName in sLiveList[pScope]
      delete variable sCfg[tName]
      delete variable sHoverAmt[tName]
      delete variable sEnterAmt[tName]
      if tName is sHover then
         lkHoverOn empty
      end if
   end repeat
   delete variable sLiveList[pScope]
end lkForget

-- Changes one part of a lit thing's look (its "ink0" when it is chosen,
-- say), and draws it
command lkSetLook pName, pKey, pValue
   put pValue into sCfg[pName][pKey]
   lkApply pName
end lkSetLook

function lkLook pName, pKey
   return sCfg[pName][pKey]
end lkLook

-- The top a lit thing rests at, after its group has moved
command lkRestAt pName
   if sCfg[pName]["action"] is not empty then
      put the top of group pName into sCfg[pName]["top"]
   end if
end lkRestAt

-- Lit things light up, and a scope's things slide in
private command lkLiveFrame
   local tName, tTarget, tChanged, tStep, tE
   if sHover is not empty and the mouseStack is not the short name of me then
      lkHoverOn empty
   end if
   put sDt / 0.16 into tStep
   repeat for each line tName in sLiveList["side"] & return & sLiveList[sScope]
      if tName is empty or sCfg[tName]["action"] is empty then
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
         put (sNow - sScopeStart - sCfg[tName]["enter"] * 55) / 420 into tE
         put max(0, min(1, tE)) into sEnterAmt[tName]
         put true into tChanged
      end if
      if tChanged then
         lkApply tName
      end if
   end repeat
end lkLiveFrame

################################################################################
#
# Scrollbars
#

-- A slim thumb over the right edge of a scrolling group or field (pTarget,
-- a long id), in place of its scrollbar, which looks like nothing else in
-- the kit. The wheel scrolls whichever thumb's target is under the
-- pointer, gliding there over a few frames; the thumb can be dragged; and
-- each frame puts it where its target's scroll is, however that changed.
-- pGroup is where the thumb is made: not in the target, or it would
-- scroll with it. pBlend is its blendLevel at rest.
command lkScroller pName, pTarget, pColor, pBlend, pGroup
   local tObj
   put lkBox(pName, lkR(0, 0, 6, 36), pColor, 3, pGroup) into tObj
   set the blendLevel of tObj to pBlend
   hide tObj
   put pTarget into sScroll[pName]["target"]
   put pBlend into sScroll[pName]["blend"]
   delete variable sScroll[pName]["goal"]
   set the vScrollbar of pTarget to false
   lkScrollSync pName
end lkScroller

-- How far a thumb's target scrolls, and how tall its window is
private function lkScrollRoom pTarget
   local tRoom
   put the formattedHeight of pTarget - the height of pTarget into tRoom
   if word 1 of pTarget is "field" then
      -- (a field's text has its margins above and below)
      add the topMargin of pTarget + the bottomMargin of pTarget to tRoom
   end if
   return max(0, tRoom)
end lkScrollRoom

-- Puts thumb pName where its target's scroll is, wider while the pointer
-- is near it or drags it, and hides it when there is nothing to scroll
command lkScrollSync pName
   local tTarget, tRect, tRoom, tShown, tHeight, tTop, tWidth, tNear, tNew, tBlend, tMouse
   put sScroll[pName]["target"] into tTarget
   if tTarget is empty or there is no tTarget or there is no graphic pName then
      exit lkScrollSync
   end if
   put the rect of tTarget into tRect
   put lkScrollRoom(tTarget) into tRoom
   if tRoom < 16 or not the visible of tTarget then
      if the visible of graphic pName then
         hide graphic pName
      end if
      exit lkScrollSync
   end if
   put item 4 of tRect - item 2 of tRect into tShown
   put max(36, round(tShown * tShown / (tShown + tRoom))) into tHeight
   put item 2 of tRect + 4 + round((tShown - 8 - tHeight) * max(0, min(1, the vScroll of tTarget / tRoom))) into tTop
   put the mouseLoc into tMouse
   put sDrag["name"] is pName or (item 1 of tMouse > item 3 of tRect - 18 and item 1 of tMouse < item 3 of tRect \
         and item 2 of tMouse > item 2 of tRect and item 2 of tMouse < item 4 of tRect) into tNear
   if tNear then
      put 9 into tWidth
      put max(0, sScroll[pName]["blend"] - 30) into tBlend
   else
      put 6 into tWidth
      put sScroll[pName]["blend"] into tBlend
   end if
   put (item 3 of tRect - 3 - tWidth) & comma & tTop & comma & (item 3 of tRect - 3) & comma & (tTop + tHeight) into tNew
   if the rect of graphic pName is not tNew then
      set the roundRadius of graphic pName to tWidth div 2
      set the rect of graphic pName to tNew
   end if
   if the blendLevel of graphic pName is not tBlend then
      set the blendLevel of graphic pName to tBlend
   end if
   if not the visible of graphic pName then
      show graphic pName
   end if
end lkScrollSync

-- Each frame: the wheel's glide, a drag that ended out of sight, and the
-- thumbs put where their targets are
private command lkScrollFrame
   local tName, tTarget, tNow, tGoal, tStep
   if sDrag["name"] is not empty and the mouse is up then
      put empty into sDrag
   end if
   repeat for each key tName in sScroll
      put sScroll[tName]["target"] into tTarget
      if tTarget is empty or there is no tTarget then
         next repeat
      end if
      if sScroll[tName]["goal"] is not empty then
         put the vScroll of tTarget into tNow
         if tNow is not sScroll[tName]["at"] then
            -- (something else scrolled it: the glide is over)
            delete variable sScroll[tName]["goal"]
         else
            put sScroll[tName]["goal"] into tGoal
            put (tGoal - tNow) * min(1, sDt * 16) into tStep
            if abs(tGoal - tNow) <= 1 then
               put tGoal into tNow
               delete variable sScroll[tName]["goal"]
            else if tStep > 0 then
               put tNow + max(1, round(tStep)) into tNow
            else
               put tNow + min(-1, round(tStep)) into tNow
            end if
            set the vScroll of tTarget to tNow
            put the vScroll of tTarget into sScroll[tName]["at"]
            if sScroll[tName]["at"] is not tNow then
               -- (the end of the target stopped it)
               delete variable sScroll[tName]["goal"]
            end if
         end if
      end if
      lkScrollSync tName
   end repeat
end lkScrollFrame

-- The wheel: the target under the pointer glides 40 pixels a notch
on rawKeyDown pKey
   local tName, tTarget, tGoal
   if pKey is not 65308 and pKey is not 65309 then
      pass rawKeyDown
   end if
   repeat for each key tName in sScroll
      put sScroll[tName]["target"] into tTarget
      if tTarget is empty or there is no tTarget or not the visible of tTarget then
         next repeat
      end if
      if the mouseLoc is not within the rect of tTarget then
         next repeat
      end if
      put sScroll[tName]["goal"] into tGoal
      if tGoal is empty then
         put the vScroll of tTarget into tGoal
      end if
      if pKey is 65308 then
         add 40 to tGoal
      else
         subtract 40 from tGoal
      end if
      put max(0, min(lkScrollRoom(tTarget), tGoal)) into sScroll[tName]["goal"]
      put the vScroll of tTarget into sScroll[tName]["at"]
      exit rawKeyDown
   end repeat
   pass rawKeyDown
end rawKeyDown

-- Dragging a thumb
on mouseDown pButton
   local tName
   if pButton is 1 and word 1 of the target is "graphic" then
      repeat for each key tName in sScroll
         if there is a graphic tName and the long id of the target is the long id of graphic tName then
            put tName into sDrag["name"]
            put item 2 of the mouseLoc into sDrag["from"]
            put the vScroll of sScroll[tName]["target"] into sDrag["scroll"]
            delete variable sScroll[tName]["goal"]
            exit mouseDown
         end if
      end repeat
   end if
   pass mouseDown
end mouseDown

private command lkScrollDrag
   local tName, tTarget, tRoom, tShown, tTravel
   put sDrag["name"] into tName
   put sScroll[tName]["target"] into tTarget
   if tTarget is empty or there is no tTarget or there is no graphic tName then
      put empty into sDrag
      exit lkScrollDrag
   end if
   put lkScrollRoom(tTarget) into tRoom
   put the height of tTarget - 8 - the height of graphic tName into tTravel
   if tTravel < 1 then
      exit lkScrollDrag
   end if
   set the vScroll of tTarget to max(0, min(tRoom, round(sDrag["scroll"] + (item 2 of the mouseLoc - sDrag["from"]) * tRoom / tTravel)))
   lkScrollSync tName
end lkScrollDrag

on mouseRelease pButton
   if sDrag["name"] is not empty then
      put empty into sDrag
   end if
   pass mouseRelease
end mouseRelease

################################################################################
#
# Buttons and the sidebar
#

-- A button: a rounded box with an icon and a label, lit as its style says
--    primary   filled with the accent
--    ghost     white, with a border
--    dark      for the sidebar and the dark panels
--    chip      a small tinted box, for a line of code
--    light     white on a coloured panel
function lkButton pName, pLeft, pTop, pHeight, pLabel, pIcon, pStyle, pAccent, pGroup, pAction, pMinWidth, pPage
   local tSize, tLabelWidth, tWidth, tIconSize, tGap, tX, tMid, tObj, tLook, tInk, tIconInk, tLabel, tPad, tTop
   put 14 into tSize
   put 16 into tIconSize
   put 16 into tPad
   if pStyle is "chip" then
      put 12 into tSize
      put 12 into tPad
   end if
   put lkGroup(pName, lkR(pLeft, pTop, pLeft + 10, pTop + pHeight), pGroup) into tObj
   put lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + 10, pTop + pHeight), empty, pHeight, pName) into tObj
   put lkLabel(pName & "_label", lkR(pLeft, pTop, pLeft + 600, pTop + pHeight), pLabel, tSize, "0,0,0", pName) into tLabel
   set the dontWrap of tLabel to true
   if pStyle is "chip" and lkCodeFont() is not empty then
      set the textFont of tLabel to lkCodeFont()
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
         put lkMix(pAccent, "255,255,255", 0.16) into tLook["bg1"]
         put "255,255,255" into tInk
         put tInk into tIconInk
         break
      case "ghost"
         put "255,255,255" into tLook["bg0"]
         put lkMix("255,255,255", pAccent, 0.08) into tLook["bg1"]
         put lkColor("line") into tLook["line0"]
         put pAccent into tLook["line1"]
         put lkColor("ink") into tLook["ink0"]
         put lkMix(pAccent, lkColor("ink"), 0.25) into tLook["ink1"]
         put tLook["ink0"] into tInk
         put pAccent into tIconInk
         break
      case "dark"
         put lkColor("side2") into tLook["bg0"]
         put lkColor("sideLine") into tLook["bg1"]
         put lkColor("sideLine") into tLook["line0"]
         put "100,116,139" into tLook["line1"]
         put lkColor("sideInk") into tLook["ink0"]
         put "255,255,255" into tLook["ink1"]
         put tLook["ink0"] into tInk
         put tInk into tIconInk
         break
      case "chip"
         put lkMix("255,255,255", pAccent, 0.09) into tLook["bg0"]
         put lkMix("255,255,255", pAccent, 0.2) into tLook["bg1"]
         put lkMix(pAccent, lkColor("ink"), 0.3) into tInk
         put tInk into tIconInk
         break
      case "light"
         put "255,255,255" into tLook["bg0"]
         put lkMix("255,255,255", pAccent, 0.14) into tLook["bg1"]
         put lkMix(pAccent, lkColor("ink"), 0.2) into tInk
         put pAccent into tIconInk
         break
   end switch
   set the backgroundColor of graphic (pName & "_bg") to tLook["bg0"]
   set the opaque of graphic (pName & "_bg") to true
   if tLook["line0"] is not empty then
      lkBorder the long id of graphic (pName & "_bg"), tLook["line0"]
   end if
   if pIcon is not empty then
      get lkIcon(pName & "_icon", pIcon, tIconInk, tX & "," & (tMid - 8) & "," & (tX + 16) & "," & (tMid + 8), pName)
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
   lkLive pName, pPage, pAction, tLook
   return tWidth
end lkButton

command lkNavItem pName, pTop, pHeight, pLabel, pIcon, pAction, pSize, pRight
   local tObj, tLook, tMid
   -- (pRight is the item's right edge: the sidebar's width less 10)
   if pRight is empty then
      put 190 into pRight
   end if
   put pTop + pHeight div 2 into tMid
   get lkGroup(pName, lkR(10, pTop, pRight, pTop + pHeight), empty)
   put lkBox(pName & "_bg", lkR(10, pTop, pRight, pTop + pHeight), lkColor("side2"), 18, pName) into tObj
   set the blendLevel of tObj to 100
   get lkIcon(pName & "_icon", pIcon, lkColor("sideInk"), lkR(24, tMid - 8, 40, tMid + 8), pName)
   put lkLabel(pName & "_label", lkR(50, tMid - 10, pRight - 2, tMid + 10), pLabel, pSize, lkColor("sideInk"), pName) into tObj
   set the dontWrap of tObj to true
   set the top of tObj to tMid - (the formattedHeight of tObj + kTextInset) div 2
   put pName & "_bg" into tLook["bg"]
   put 100 into tLook["blend0"]
   put 45 into tLook["blend1"]
   put pName & "_label" into tLook["label"]
   put lkColor("sideInk") into tLook["ink0"]
   put "255,255,255" into tLook["ink1"]
   lkLive pName, "side", pAction, tLook
end lkNavItem

################################################################################
#
# Code, in colour, and errors in words
#

-- htmlText for lines of xTalk: commands, the words between them, objects,
-- strings, numbers and comments each in their own colour
function lkCodeHtml pText
   local tHtml, tLine
   repeat for each line tLine in pText
      put "<p>" & lkCodeLineHtml(tLine) & "</p>" after tHtml
   end repeat
   return tHtml
end lkCodeHtml

function lkCodeLineHtml pLine
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
         put lkSpan(char tStart to tPos of pLine, "#fcd34d") after tOut
         add 1 to tPos
      else if tChar is "-" and char tNext of pLine is "-" then
         put lkSpan(char tPos to tLen of pLine, "#64748b") after tOut
         exit repeat
      else if lkIsWordChar(tChar) then
         put tPos into tStart
         repeat while tPos <= tLen and lkIsWordChar(char tPos of pLine)
            add 1 to tPos
         end repeat
         put char tStart to tPos - 1 of pLine into tWord
         put lkSpan(tWord, lkWordColor(tWord)) after tOut
      else
         put lkEscape(tChar) after tOut
         put tNext into tPos
      end if
   end repeat
   return tOut
end lkCodeLineHtml

function lkIsWordChar pChar
   return pChar is not empty and pChar is in "abcdefghijklmnopqrstuvwxyz0123456789_"
end lkIsWordChar

function lkWordColor pWord
   if pWord is a number then
      return "#fdba74"
   end if
   if pWord is among the items of "on,end,put,get,set,move,add,subtract,multiply,divide,send,dispatch,call,repeat,if,then,else,switch,case,break,default,try,catch,throw,answer,ask,create,delete,go,open,close,show,hide,lock,unlock,sort,filter,replace,convert,do,exit,pass,return,local,global,constant,cancel,launch,revSpeak,function,command,getprop,setprop,next,beep,play,wait,select,click,type,import,export,start,stop,read,write,save,visual,focus,choose,combine,split,insert,load,post,format" then
      return "#c4b5fd"
   end if
   if pWord is among the items of "the,of,to,into,in,with,without,waiting,messages,and,or,not,is,are,a,an,for,each,until,while,times,by,after,before,from,at,any,mod,div,as,among,contains,within" then
      return "#7dd3fc"
   end if
   if pWord is among the items of "field,fld,graphic,grc,button,btn,card,cd,stack,image,img,group,grp,player,widget,scrollbar,control,me,it,this,target,item,items,word,words,line,lines,char,chars,character,characters,url,file,folder,milliseconds,millisecs,ticks,seconds,second,secs" then
      return "#5eead4"
   end if
   if pWord is among the items of "true,false,empty,quote,space,tab,comma,cr,return,lf,slash,colon,pi,zero,one,two,three" then
      return "#f9a8d4"
   end if
   return "#e2e8f0"
end lkWordColor

function lkSpan pText, pColor
   return "<font color=" & quote & pColor & quote & ">" & lkEscape(pText) & "</font>"
end lkSpan

function lkEscape pText
   replace "&" with "&amp;" in pText
   replace "<" with "&lt;" in pText
   replace ">" with "&gt;" in pText
   return pText
end lkEscape

-- An error, in words: the engine's message for the first error it lists
function lkErrorText pError
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
end lkErrorText

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
function lkIconPaths pName
   switch pName
      case "house"
         return "<path d='M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8'/><path d='M3 10a2 2 0 0 1 .709-1.528l7-5.99" & \
               "9a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'/>"
      case "chevron-left"
         return "<path d='m15 18-6-6 6-6'/>"
      case "chevron-right"
         return "<path d='m9 18 6-6-6-6'/>"
      case "arrow-left"
         return "<path d='m12 19-7-7 7-7'/><path d='M19 12H5'/>"
      case "arrow-right"
         return "<path d='M5 12h14'/><path d='m12 5 7 7-7 7'/>"
      case "graduation-cap"
         return "<path d='M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.8" & \
               "32l8.57 3.908a2 2 0 0 0 1.66 0z'/><path d='M22 10v6'/><path d='M6 12.5V16a6 3 0 0 0 12 0v-3.5'/>"
      case "book-open-text"
         return "<path d='M12 7v14'/><path d='M16 12h2'/><path d='M16 8h2'/><path d='M3 18a1 1 0 0 1-1-1V4a1 1 0 " & \
               "0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 " & \
               "0-3-3z'/><path d='M6 12h2'/><path d='M6 8h2'/>"
      case "book-open"
         return "<path d='M12 7v14'/><path d='M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5" & \
               "a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z'/>"
      case "layers"
         return "<path d='M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-" & \
               "3.9a1 1 0 0 0 0-1.83z'/><path d='M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0" & \
               " 0 0 22 12'/><path d='M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17'" & \
               "/>"
      case "search"
         return "<circle cx='11' cy='11' r='8'/><path d='m21 21-4.3-4.3'/>"
      case "x"
         return "<path d='M18 6 6 18'/><path d='m6 6 12 12'/>"
      case "lightbulb"
         return "<path d='M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1." & \
               "3 1.5 1.5 2.5'/><path d='M9 18h6'/><path d='M10 22h4'/>"
      case "info"
         return "<circle cx='12' cy='12' r='10'/><path d='M12 16v-4'/><path d='M12 8h.01'/>"
      case "triangle-alert"
         return "<path d='m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3'/><path d='M12" & \
               " 9v4'/><path d='M12 17h.01'/>"
      case "star"
         return "<path d='M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53." & \
               "53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.61" & \
               "8-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-" & \
               ".611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z'/>"
      case "copy"
         return "<rect width='14' height='14' x='8' y='8' rx='2' ry='2'/><path d='M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9" & \
               "-2 2-2h10c1.1 0 2 .9 2 2'/>"
      case "check"
         return "<path d='M20 6 9 17l-5-5'/>"
      case "external-link"
         return "<path d='M15 3h6v6'/><path d='M10 14 21 3'/><path d='M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 " & \
               "2 0 0 1 2-2h6'/>"
      case "pencil"
         return "<path d='M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 " & \
               "0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z'/><path d='m15 5 4 4'/>"
      case "play"
         return "<polygon points='6 3 20 12 6 21 6 3'/>"
      case "file-text"
         return "<path d='M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z'/><path d='M14 2v4a2 2 0 0 0" & \
               " 2 2h4'/><path d='M10 9H8'/><path d='M16 13H8'/><path d='M16 17H8'/>"
      case "database"
         return "<ellipse cx='12' cy='5' rx='9' ry='3'/><path d='M3 5V19A9 3 0 0 0 21 19V5'/><path d='M3 12A9 3 0" & \
               " 0 0 21 12'/>"
      case "film"
         return "<rect width='18' height='18' x='3' y='3' rx='2'/><path d='M7 3v18'/><path d='M3 7.5h4'/><path d=" & \
               "'M3 12h18'/><path d='M3 16.5h4'/><path d='M17 3v18'/><path d='M17 7.5h4'/><path d='M17 16.5h4'/>"
      case "image"
         return "<rect width='18' height='18' x='3' y='3' rx='2' ry='2'/><circle cx='9' cy='9' r='2'/><path d='m2" & \
               "1 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21'/>"
      case "rss"
         return "<path d='M4 11a9 9 0 0 1 9 9'/><path d='M4 4a16 16 0 0 1 16 16'/><circle cx='5' cy='19' r='1'/>"
      case "archive"
         return "<rect width='20' height='5' x='2' y='3' rx='1'/><path d='M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V" & \
               "8'/><path d='M10 12h4'/>"
      case "table"
         return "<path d='M12 3v18'/><rect width='18' height='18' x='3' y='3' rx='2'/><path d='M3 9h18'/><path d=" & \
               "'M3 15h18'/>"
      case "type"
         return "<polyline points='4 7 4 4 20 4 20 7'/><line x1='9' x2='15' y1='20' y2='20'/><line x1='12' x2='12" & \
               "' y1='4' y2='20'/>"
      case "sparkles"
         return "<path d='M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.9" & \
               "37 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .9" & \
               "64L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z'/><path d='M20 3v4'/><path " & \
               "d='M22 5h-4'/><path d='M4 17v2'/><path d='M5 18H3'/>"
      case "code"
         return "<polyline points='16 18 22 12 16 6'/><polyline points='8 6 2 12 8 18'/>"
      case "square-terminal"
         return "<path d='m7 11 2-2-2-2'/><path d='M11 13h4'/><rect width='18' height='18' x='3' y='3' rx='2' ry=" & \
               "'2'/>"
      case "globe"
         return "<circle cx='12' cy='12' r='10'/><path d='M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20'/><path" & \
               " d='M2 12h20'/>"
      case "rocket"
         return "<path d='M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.0" & \
               "9z'/><path d='m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22." & \
               "35 0 0 1-4 2z'/><path d='M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0'/><path d='M12 15v5s3.03-.55 4-2" & \
               "c1.08-1.62 0-5 0-5'/>"
      case "orbit"
         return "<circle cx='12' cy='12' r='3'/><circle cx='19' cy='5' r='2'/><circle cx='5' cy='19' r='2'/><path" & \
               " d='M10.4 21.9a10 10 0 0 0 9.941-15.416'/><path d='M13.5 2.1a10 10 0 0 0-9.841 15.416'/>"
      case "palette"
         return "<circle cx='13.5' cy='6.5' r='.5' fill='currentColor'/><circle cx='17.5' cy='10.5' r='.5' fill='" & \
               "currentColor'/><circle cx='8.5' cy='7.5' r='.5' fill='currentColor'/><circle cx='6.5' cy='12.5' " & \
               "r='.5' fill='currentColor'/><path d='M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648" & \
               "-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.99" & \
               "6c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z'/>"
      case "clipboard-copy"
         return "<rect width='8' height='4' x='8' y='2' rx='1' ry='1'/><path d='M8 4H6a2 2 0 0 0-2 2v14a2 2 0 0 0" & \
               " 2 2h12a2 2 0 0 0 2-2v-2'/><path d='M16 4h2a2 2 0 0 1 2 2v4'/><path d='M21 14H11'/><path d='m15 " & \
               "10-4 4 4 4'/>"
      case "list-tree"
         return "<path d='M21 12h-8'/><path d='M21 6H8'/><path d='M21 18h-8'/><path d='M3 6v4c0 1.1.9 2 2 2h3'/><" & \
               "path d='M3 10v6c0 1.1.9 2 2 2h3'/>"
      case "folder-open"
         return "<path d='m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 " & \
               "0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2'/>"
      case "file-plus"
         return "<path d='M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z'/><path d='M14 2v4a2 2 0 0 0" & \
               " 2 2h4'/><path d='M9 15h6'/><path d='M12 18v-6'/>"
      case "volume-2"
         return "<path d='M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6" & \
               "a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z'/><path d='M16" & \
               " 9a5 5 0 0 1 0 6'/><path d='M19.364 18.364a9 9 0 0 0 0-12.728'/>"
      case "gamepad-2"
         return "<line x1='6' x2='10' y1='11' y2='11'/><line x1='8' x2='8' y1='9' y2='13'/><line x1='15' x2='15.0" & \
               "1' y1='12' y2='12'/><line x1='18' x2='18.01' y1='10' y2='10'/><path d='M17.32 5H6.68a4 4 0 0 0-3" & \
               ".978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.41" & \
               "4-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.6" & \
               "04-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z'/>"
      case "music"
         return "<path d='M9 18V5l12-2v13'/><circle cx='6' cy='18' r='3'/><circle cx='18' cy='16' r='3'/>"
      case "cloud-sun"
         return "<path d='M12 2v2'/><path d='m4.93 4.93 1.41 1.41'/><path d='M20 12h2'/><path d='m19.07 4.93-1.41" & \
               " 1.41'/><path d='M15.947 12.65a4 4 0 0 0-5.925-4.128'/><path d='M13 22H7a5 5 0 1 1 4.9-6H13a3 3 " & \
               "0 0 1 0 6Z'/>"
      case "piano"
         return "<path d='M18.5 8c-1.4 0-2.6-.8-3.2-2A6.87 6.87 0 0 0 2 9v11a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-8.5C" & \
               "22 9.6 20.4 8 18.5 8'/><path d='M2 14h20'/><path d='M6 14v4'/><path d='M10 14v4'/><path d='M14 1" & \
               "4v4'/><path d='M18 14v4'/>"
      case "bot"
         return "<path d='M12 8V4H8'/><rect width='16' height='12' x='4' y='8' rx='2'/><path d='M2 14h2'/><path d" & \
               "='M20 14h2'/><path d='M15 13v2'/><path d='M9 13v2'/>"
      case "qr-code"
         return "<rect width='5' height='5' x='3' y='3' rx='1'/><rect width='5' height='5' x='16' y='3' rx='1'/><" & \
               "rect width='5' height='5' x='3' y='16' rx='1'/><path d='M21 16h-3a2 2 0 0 0-2 2v3'/><path d='M21" & \
               " 21v.01'/><path d='M12 7v3a2 2 0 0 1-2 2H7'/><path d='M3 12h.01'/><path d='M12 3h.01'/><path d='" & \
               "M12 16v.01'/><path d='M16 12h1'/><path d='M21 12v.01'/><path d='M12 21v-1'/>"
      case "braces"
         return "<path d='M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5c0 1.1.9 2 2 2h1'/><path d='M16 21h" & \
               "1a2 2 0 0 0 2-2v-5c0-1.1.9-2 2-2a2 2 0 0 1-2-2V5a2 2 0 0 0-2-2h-1'/>"
      case "mouse-pointer-click"
         return "<path d='M14 4.1 12 6'/><path d='m5.1 8-2.9-.8'/><path d='m6 12-1.9 2'/><path d='M7.2 2.2 8 5.1'" & \
               "/><path d='M9.037 9.69a.498.498 0 0 1 .653-.653l11 4.5a.5.5 0 0 1-.074.949l-4.349 1.041a1 1 0 0 " & \
               "0-.74.739l-1.04 4.35a.5.5 0 0 1-.95.074z'/>"
      case "smartphone"
         return "<rect width='14' height='20' x='5' y='2' rx='2' ry='2'/><path d='M12 18h.01'/>"
      case "newspaper"
         return "<path d='M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-" & \
               "2-2v-9c0-1.1.9-2 2-2h2'/><path d='M18 14h-8'/><path d='M15 18h-5'/><path d='M10 6h8v4h-8V6Z'/>"
      case "library-big"
         return "<rect width='8' height='18' x='3' y='3' rx='1'/><path d='M7 3v18'/><path d='M20.4 18.9c.2.5-.1 1" & \
               ".1-.6 1.3l-1.9.7c-.5.2-1.1-.1-1.3-.6L11.1 5.1c-.2-.5.1-1.1.6-1.3l1.9-.7c.5-.2 1.1.1 1.3.6Z'/>"
      case "zap"
         return "<path d='M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 " & \
               "0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z'/>"
      case "trophy"
         return "<path d='M6 9H4.5a2.5 2.5 0 0 1 0-5H6'/><path d='M18 9h1.5a2.5 2.5 0 0 0 0-5H18'/><path d='M4 22" & \
               "h16'/><path d='M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22'/><path d='M14 14.66V1" & \
               "7c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22'/><path d='M18 2H6v7a6 6 0 0 0 12 0V2Z'/>"
      case "puzzle"
         return "<path d='M15.39 4.39a1 1 0 0 0 1.68-.474 2.5 2.5 0 1 1 3.014 3.015 1 1 0 0 0-.474 1.68l1.683 1.6" & \
               "82a2.414 2.414 0 0 1 0 3.414L19.61 15.39a1 1 0 0 1-1.68-.474 2.5 2.5 0 1 0-3.014 3.015 1 1 0 0 1" & \
               " .474 1.68l-1.683 1.682a2.414 2.414 0 0 1-3.414 0L8.61 19.61a1 1 0 0 0-1.68.474 2.5 2.5 0 1 1-3." & \
               "014-3.015 1 1 0 0 0 .474-1.68l-1.683-1.682a2.414 2.414 0 0 1 0-3.414L4.39 8.61a1 1 0 0 1 1.68.47" & \
               "4 2.5 2.5 0 1 0 3.014-3.015 1 1 0 0 1-.474-1.68l1.683-1.682a2.414 2.414 0 0 1 3.414 0z'/>"
      case "wand-sparkles"
         return "<path d='m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.2" & \
               "8a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72'/><path d='m14 7 3 3'/><path d='M5 6v4'/>" & \
               "<path d='M19 14v4'/><path d='M10 2v2'/><path d='M7 8H3'/><path d='M21 16h-4'/><path d='M11 3H9'/" & \
               ">"
      case "monitor-play"
         return "<path d='M10 7.75a.75.75 0 0 1 1.142-.638l3.664 2.249a.75.75 0 0 1 0 1.278l-3.664 2.25a.75.75 0 " & \
               "0 1-1.142-.64z'/><path d='M12 17v4'/><path d='M8 21h8'/><rect x='2' y='3' width='20' height='14'" & \
               " rx='2'/>"
      case "notebook-pen"
         return "<path d='M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4'/><path d='M2 6h4'/><pat" & \
               "h d='M2 10h4'/><path d='M2 14h4'/><path d='M2 18h4'/><path d='M21.378 5.626a1 1 0 1 0-3.004-3.00" & \
               "4l-5.01 5.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z'/>"
      case "compass"
         return "<path d='m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1." & \
               "265z'/><circle cx='12' cy='12' r='10'/>"
      case "scroll"
         return "<path d='M19 17V5a2 2 0 0 0-2-2H4'/><path d='M8 21h12a2 2 0 0 0 2-2v-1a1 1 0 0 0-1-1H11a1 1 0 0 " & \
               "0-1 1v1a2 2 0 1 1-4 0V5a2 2 0 1 0-4 0v2a1 1 0 0 0 1 1h3'/>"
      case "hard-drive"
         return "<line x1='22' x2='2' y1='12' y2='12'/><path d='M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v" & \
               "-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z'/><line x1='6' x2='6.01' y1='16' y2='1" & \
               "6'/><line x1='10' x2='10.01' y1='16' y2='16'/>"
      case "blocks"
         return "<rect width='7' height='7' x='14' y='3' rx='1'/><path d='M10 21V8a1 1 0 0 0-1-1H4a1 1 0 0 0-1 1v" & \
               "12a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-5a1 1 0 0 0-1-1H3'/>"
      case "layout-grid"
         return "<rect width='7' height='7' x='3' y='3' rx='1'/><rect width='7' height='7' x='14' y='3' rx='1'/><" & \
               "rect width='7' height='7' x='14' y='14' rx='1'/><rect width='7' height='7' x='3' y='14' rx='1'/>"
      case "sheet"
         return "<rect width='18' height='18' x='3' y='3' rx='2' ry='2'/><line x1='3' x2='21' y1='9' y2='9'/><lin" & \
               "e x1='3' x2='21' y1='15' y2='15'/><line x1='9' x2='9' y1='9' y2='21'/><line x1='15' x2='15' y1='" & \
               "9' y2='21'/>"
      case "folder-archive"
         return "<circle cx='15' cy='19' r='2'/><path d='M20.9 19.8A2 2 0 0 0 22 18V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 " & \
               "1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h5.1'/><path d='M15 11v-1'/><" & \
               "path d='M15 17v-2'/>"
      case "text-cursor-input"
         return "<path d='M5 4h1a3 3 0 0 1 3 3 3 3 0 0 1 3-3h1'/><path d='M13 20h-1a3 3 0 0 1-3-3 3 3 0 0 1-3 3H5" & \
               "'/><path d='M5 16H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h1'/><path d='M13 8h7a2 2 0 0 1 2 2v4a2 2 0 0 " & \
               "1-2 2h-7'/><path d='M9 7v10'/>"
      case "message-square-text"
         return "<path d='M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z'/><path d='M13 8H7'/><pat" & \
               "h d='M17 12H7'/>"
      case "heart"
         return "<path d='M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4." & \
               "5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z'/>"
      case "grid-2x2"
         return "<path d='M12 3v18'/><path d='M3 12h18'/><rect x='3' y='3' width='18' height='18' rx='2'/>"
      case "bug"
         return "<path d='m8 2 1.88 1.88'/><path d='M14.12 3.88 16 2'/><path d='M9 7.13v-1a3.003 3.003 0 1 1 6 0v" & \
               "1'/><path d='M12 20c-3.3 0-6-2.7-6-6v-3a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v3c0 3.3-2.7 6-6 6'/><path " & \
               "d='M12 20v-9'/><path d='M6.53 9C4.6 8.8 3 7.1 3 5'/><path d='M6 13H2'/><path d='M3 21c0-2.1 1.7-" & \
               "3.9 3.8-4'/><path d='M20.97 5c0 2.1-1.6 3.8-3.5 4'/><path d='M22 13h-4'/><path d='M17.2 17c2.1.1" & \
               " 3.8 1.9 3.8 4'/>"
      case "printer"
         return "<path d='M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2'/><path d='M" & \
               "6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6'/><rect x='6' y='14' width='12' height='8' rx='1'/>"
      case "package"
         return "<path d='M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A" & \
               "2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z'/><path d='M12 22V12'/><path d='m3.3 7 7.703 4.734a2 2 0 0 0 1" & \
               ".994 0L20.7 7'/><path d='m7.5 4.27 9 5.15'/>"
      case "map"
         return "<path d='M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894" & \
               "l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6." & \
               "618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z'/><path d='M15 5.764v15'/><path d='M9 3.2" & \
               "36v15'/>"
   end switch
   return empty
end lkIconPaths
