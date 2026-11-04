script "OXTExampleSvgLab"
-- OXT-Beyond: builds "SVG Lab", an example made here, in the remasters'
-- look, to show what 0.2.7-rc.6.12 brought to SVG: the compile options
-- (styles, opacity, ids, clip, gradients), the IDE's Convert to Graphics,
-- the way back out (drawingSvgDecompile), and drawings made by script.
-- It is the lean desktop cousin of the web page tools/pages/games/svg-lab,
-- whose OXT-Beyond logo, as SVG with its words as paths, it shows: both
-- of the page's files, beyond-logo.svg and its template for every frame,
-- beyond-logo-live.svg, are read from there and kept in the stack.
--
-- Its cards: the logo, live (each frame is the logo's SVG with new
-- numbers in it, compiled again); Before and After (one SVG, compiled as
-- old stacks get it and with every option, either side of a line you
-- drag); Options (each option on and off, Convert to Graphics and Export
-- SVG); Zoom (the drawing against a bitmap of it); Recolor (decompile,
-- change the colours as text, compile); and a page on how it works. Every
-- card but the logo's works on an SVG of your own too (Open SVG).
--
-- The drawing library, which the IDE loads, does the work: where it is
-- not loaded, the cards say so. tools/examples/test-svg-lab.livecodescript
-- tests the built stack.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- The picture on the wide cards that have one, and the column beside it
constant kPicture = "272,120,752,600"
constant kSideLeft = 772
-- The words are measured here, but the IDE's font is wider than the
-- build's, by as much as a tenth (measured at 13 points): words get room
-- for a font this much narrower (fixLines)
constant kFontRoom = 0.88

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tPages
   exUseScripts the script of me
   exAddIcon "folder-up", "<path d='M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z'/>" & \
         "<path d='M12 10v6'/><path d='m9 13 3-3 3 3'/>"
   exAddIcon "download", "<path d='M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'/><polyline points='7 10 12 15 17 10'/><line x1='12' x2='12' y1='15' y2='3'/>"
   exAddIcon "zoom-in", "<circle cx='11' cy='11' r='8'/><line x1='21' x2='16.65' y1='21' y2='16.65'/><line x1='11' x2='11' y1='8' y2='14'/><line x1='8' x2='14' y1='11' y2='11'/>"
   exAddIcon "zoom-out", "<circle cx='11' cy='11' r='8'/><line x1='21' x2='16.65' y1='21' y2='16.65'/><line x1='8' x2='14' y1='11' y2='11'/>"
   exAddIcon "pause", "<rect x='14' y='4' width='4' height='16' rx='1'/><rect x='6' y='4' width='4' height='16' rx='1'/>"
   put "SVG Lab" into tInfo["name"]
   put "new in OXT-Beyond 0.2.7" into tInfo["credit"]
   put "wand-sparkles" into tInfo["icon"]
   put lkColor("orange") into tInfo["accent"]
   put lkColor("amber") into tInfo["accent2"]
   put "Part" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|SVG Lab|What OXT-Beyond does with SVG now, and the scripts that do it.|wand-sparkles|front" & return & \
         "Logo|Live Logo|The OXT-Beyond logo as SVG, written and compiled again every frame.|sparkles|wide" & return & \
         "Compare|Before and After|One SVG, compiled as old stacks get it and with every option. Drag the line.|split|wide" & return & \
         "Options|Options|Each compile option on and off, Convert to Graphics and Export SVG.|layers|wide" & return & \
         "Zoom|Zoom|A drawing stays sharp at any size; a bitmap of it does not.|search|wide" & return & \
         "Recolor|Recolor|Decompile, change the colours as text, compile again.|palette|wide" & return & \
         "How|How It Works|The calls, the options and where the IDE uses them.|book-open-text|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   setDrawings tStack
   exAddCards
   buildFront
   buildLogo
   buildCompare
   buildOptions
   buildZoom
   buildRecolor
   buildHow
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/SVG Lab.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

-- The logo and its template for every frame, from the web page's folder
private command setDrawings pStack
   local tFolder, tLogo, tLive
   set the itemDelimiter to slash
   put item 1 to -3 of the filename of me & "/pages/games/svg-lab" into tFolder
   set the itemDelimiter to comma
   put url ("file:" & tFolder & "/beyond-logo.svg") into tLogo
   put url ("file:" & tFolder & "/beyond-logo-live.svg") into tLive
   if tLogo is empty or "@SHINE@" is not in tLive then
      throw "no logo in " & tFolder
   end if
   set the cLogoSvg of pStack to tLogo
   set the cLogoLive of pStack to tLive
end setDrawings

################################################################################
#
# Drawing helpers
#

private function heading pName, pLeft, pTop, pRight, pText, pSize, pGroup
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + pSize + 10), pText, pSize, lkColor("ink"), pGroup) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   return tObj
end heading

-- Words, a paragraph a line, with room between them, as tall as they are;
-- returns their bottom
private function textBlock pName, pLeft, pTop, pRight, pText, pSize, pColor, pGroup
   local tObj, tIndex
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + 400), pText, pSize, pColor, pGroup) into tObj
   fixLines tObj
   repeat with tIndex = 1 to the number of lines of pText - 1
      set the spaceBelow of line tIndex of tObj to 10
   end repeat
   set the height of tObj to the formattedHeight of tObj + 4
   set the top of tObj to pTop - 4
   return the bottom of tObj
end textBlock

-- Breaks a label's lines where they would break in a font kFontRoom
-- narrower than the build's, with a line break that is not a new
-- paragraph (a vertical tab), so that they fit the IDE's wider font too
private command fixLines pObj
   local tRect, tRoom, tSource, tParagraph, tLine, tLines, tText
   put the rect of pObj into tRect
   put round(the width of pObj * kFontRoom) into tRoom
   put the text of pObj into tSource
   repeat for each line tParagraph in tSource
      put empty into tLines
      set the text of pObj to tParagraph
      set the width of pObj to tRoom
      repeat for each line tLine in the formattedText of pObj
         repeat while the last char of tLine is space
            delete the last char of tLine
         end repeat
         put tLine & numToCodepoint(11) after tLines
      end repeat
      delete the last char of tLines
      put tLines & return after tText
   end repeat
   delete the last char of tText
   set the rect of pObj to tRect
   set the text of pObj to tText
end fixLines

private command iconBadge pName, pIcon, pLeft, pTop, pSize, pColor, pGroup
   local tInset
   get lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), lkMix("255,255,255", pColor, 0.13), pSize div 3, pGroup)
   put (pSize - 20) div 2 into tInset
   get exIcon(pName & "_icon", pIcon, pColor, lkR(pLeft + tInset, pTop + tInset, pLeft + tInset + 20, pTop + tInset + 20), pGroup)
end iconBadge

-- A panel of rows, each an icon and a line or two, and an action of the
-- frame's if pActions has one for it
private command rowsPanel pName, pRect, pTitle, pRows, pColor, pActions
   local tL, tT, tR, tIndex, tRow, tTop, tObj, tGroup
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   get lkGroup(pName, pRect, empty)
   get exPanel(pName & "_bg", pRect, pName)
   put heading(pName & "_title", tL + 20, tT + 16, tR - 20, pTitle, 15, pName) into tObj
   set the itemDelimiter to "|"
   put 0 into tIndex
   repeat for each line tRow in pRows
      add 1 to tIndex
      put tT + 48 + (tIndex - 1) * 46 into tTop
      put pName & "_row" & tIndex into tGroup
      get lkGroup(tGroup, lkR(tL + 10, tTop - 5, tR - 10, tTop + 41), pName)
      get lkBox(tGroup & "_bg", lkR(tL + 10, tTop - 5, tR - 10, tTop + 41), "255,255,255", 12, tGroup)
      iconBadge tGroup & "_badge", item 1 of tRow, tL + 20, tTop, 36, pColor, tGroup
      put lkLabel(tGroup & "_text", lkR(tL + 68, tTop, tR - 22, tTop + 38), item 2 of tRow, 13, lkColor("soft"), tGroup) into tObj
      fixLines tObj
      set the height of tObj to the formattedHeight of tObj + 4
      set the top of tObj to tTop + 16 - (the formattedHeight of tObj) div 2
      if line tIndex of pActions is not empty then
         set the cRest of group tGroup to lkDarkLiteral("255,255,255", "fill")
         set the cLit of group tGroup to lkMix("255,255,255", pColor, 0.07)
         set the cAction of group tGroup to line tIndex of pActions
      end if
   end repeat
   set the itemDelimiter to comma
end rowsPanel

-- The dark box a picture sits on, so that a drawing with no background of
-- its own reads in the light look and the dark
private function courtBox pName, pRect
   local tObj
   put lkBox(pName, pRect, lkColor("side"), 14, empty) into tObj
   lkGradient tObj, "30,41,59|20,24,54|15,23,42", item 1 of pRect & "," & item 2 of pRect, item 1 of pRect & "," & item 4 of pRect
   return tObj
end courtBox

private function newPicture pName, pRect
   local tObj
   create image pName
   put it into tObj
   set the lockLoc of tObj to true
   set the rect of tObj to pRect
   return tObj
end newPicture

-- The status line under a card's side column
private function statusLine pName, pTop
   local tObj
   put lkLabel(pName, lkR(kSideLeft, pTop, kRight - 12, kBottom - 16), "", 12, lkColor("soft"), empty) into tObj
   return tObj
end statusLine

-- Open SVG and Logo, which set the SVG the card shows (the stack script's
-- svgOpenFile and svgUseLogo), at pTop on the side column
private function sourceButtons pTop
   local tWidth
   put exButton("Open SVG", kSideLeft, pTop, 34, "Open SVG", "folder-up", "primary", lkColor("orange"), empty, empty, 0) into tWidth
   set the script of group "Open SVG" to exScript("source/open")
   get exButton("Use Logo", kSideLeft + tWidth + 8, pTop, 34, "Logo", "sparkles", "ghost", lkColor("orange"), empty, empty, 0)
   set the script of group "Use Logo" to exScript("source/logo")
   return pTop + 34
end sourceButtons

################################################################################
#
# The cards
#

private command buildFront
   local tObj
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 272), lkColor("orange") & "|" & lkColor("amber"), \
         "NEW IN OXT-BEYOND 0.2.7  " & numToCodepoint(183) & "  SVG", \
         "SVG, drawn by xTalk", \
         "Style sheets, opacity, clip paths, gradients and awkward ids now come through, " & \
         "a drawing turns into graphics you can edit, and goes back out as SVG. Old stacks draw as they always did."
   -- (the logo, a drawing like the others, on the banner)
   put newPicture("hero_logo", "852,112,1012,272") into tObj
   set the text of tObj to drawingSvgCompile(the cLogoSvg of this stack, "all")
   set the rect of tObj to 836, 112, 988, 264
   exProgramTiles 288, 3, 58, 10
   rowsPanel "Try", lkR(kLeft, 422, 620, kBottom), "Try it", \
         "sparkles|Watch the logo: every frame is fresh SVG." & return & \
         "split|Drag the line between the old compile and the new." & return & \
         "folder-up|Open an SVG of your own on any card.", \
         lkColor("orange"), "go Logo" & return & "go Compare" & return & "go Options"
   rowsPanel "Learn", lkR(636, 422, kRight, kBottom), "What you will learn", \
         "layers|What each option of drawingSvgCompile does" & return & \
         "wand-sparkles|Convert to Graphics, and SVG back out" & return & \
         "code|Drawings written by script, a frame at a time", \
         lkColor("amber"), "go Options" & return & "go Options" & return & "go How"
end buildFront

private command buildLogo
   local tObj, tBottom
   go card "Logo"
   set the script of this card to exScript("Logo/card")
   get courtBox("Court", kPicture)
   put newPicture("Logo Live", lkR(282, 130, 742, 590)) into tObj
   set the text of tObj to drawingSvgCompile(the cLogoSvg of this stack, "all")
   get heading("SideTitle", kSideLeft, kTop + 16, kRight - 12, "Live SVG", 15, empty)
   put textBlock("SideText", kSideLeft, kTop + 50, kRight - 16, \
         "The rays turn, the glow breathes, sparks fly and a shine crosses the letters." & return & \
         "No video, no sprites: a script puts new numbers into the logo's SVG and compiles it again, every frame." & return & \
         "Open Scripts to read it.", 13, lkColor("soft"), empty) into tBottom
   get exButton("Pause", kSideLeft, tBottom + 18, 34, "Pause", "pause", "ghost", lkColor("orange"), empty, empty, 96)
   set the script of group "Pause" to exScript("Logo/pause")
   get statusLine("Status", tBottom + 70)
end buildLogo

private command buildCompare
   local tObj, tBottom
   go card "Compare"
   set the script of this card to exScript("Compare/card")
   get courtBox("Court", kPicture)
   get newPicture("After", lkR(282, 130, 742, 590))
   get lkGroup("Wipe", lkR(282, 130, 512, 590), empty)
   create image "Before" in group "Wipe"
   set the lockLoc of it to true
   set the rect of it to 282, 130, 742, 590
   create graphic "Split"
   put it into tObj
   set the style of tObj to "line"
   set the lineSize of tObj to 3
   set the foregroundColor of tObj to "255,255,255"
   set the points of tObj to "512,130" & return & "512,590"
   set the cSplit of this card to 512
   get heading("SideTitle", kSideLeft, kTop + 16, kRight - 12, "Old and new", 15, empty)
   put textBlock("SideText", kSideLeft, kTop + 50, kRight - 16, \
         "Left of the line: the SVG compiled with no options, as every old stack still gets it." & return & \
         "Right: the same SVG with " & quote & "all" & quote & ", as the IDE's import now does. Drag the line.", \
         13, lkColor("soft"), empty) into tBottom
   put sourceButtons(tBottom + 16) into tBottom
   get statusLine("Status", tBottom + 16)
end buildCompare

private command buildOptions
   local tObj, tTop, tName, tTip
   go card "Options"
   set the script of this card to exScript("Options/card")
   get courtBox("Court", kPicture)
   get newPicture("Work", lkR(282, 130, 742, 590))
   get heading("SideTitle", kSideLeft, kTop + 16, kRight - 12, "Compile options", 15, empty)
   put kTop + 50 into tTop
   repeat for each item tName in "styles,opacity,ids,clip,gradients"
      set the itemDelimiter to "|"
      put item itemOffset(tName, "styles|opacity|ids|clip|gradients") of \
            "Style sheets: type, class, id and * rules|Opacity of shapes and groups|Ids with - _ . or a leading digit|clip-path and clipPath|A radial focus at its centre" into tTip
      set the itemDelimiter to comma
      create button tName
      put it into tObj
      set the style of tObj to "checkbox"
      set the label of tObj to tName
      set the hilite of tObj to true
      set the textSize of tObj to 13
      set the textColor of tObj to lkColor("ink")
      set the traversalOn of tObj to false
      set the showFocusBorder of tObj to false
      set the showBorder of tObj to false
      set the borderWidth of tObj to 0
      set the hiliteBorder of tObj to false
      set the threeD of tObj to false
      set the opaque of tObj to false
      set the tooltip of tObj to tTip
      set the rect of tObj to kSideLeft, tTop, kSideLeft + 200, tTop + 22
      set the script of tObj to exScript("Options/option")
      add 26 to tTop
   end repeat
   put sourceButtons(tTop + 12) into tTop
   get exButton("Convert", kSideLeft, tTop + 10, 34, "Convert", "wand-sparkles", "ghost", lkColor("orange"), empty, empty, 0)
   set the script of group "Convert" to exScript("Options/convert")
   get exButton("Export", kSideLeft, tTop + 52, 34, "Export SVG", "download", "ghost", lkColor("orange"), empty, empty, 0)
   set the script of group "Export" to exScript("Options/export")
   get statusLine("Status", tTop + 102)
end buildOptions

private command buildZoom
   local tObj, tLeft
   go card "Zoom"
   set the script of this card to exScript("Zoom/card")
   get courtBox("VectorCourt", "272,160,622,600")
   get courtBox("BitmapCourt", "634,160,984,600")
   get lkGroup("VectorPanel", "276,164,618,596", empty)
   create image "Vector" in group "VectorPanel"
   set the script of it to exScript("Zoom/picture")
   get lkGroup("BitmapPanel", "638,164,980,596", empty)
   create image "Bitmap" in group "BitmapPanel"
   set the script of it to exScript("Zoom/picture")
   put kLeft + 16 into tLeft
   add exButton("Zoom In", tLeft, kTop + 12, 34, "Zoom in", "zoom-in", "primary", lkColor("orange"), empty, empty, 0) + 8 to tLeft
   set the script of group "Zoom In" to exScript("Zoom/in")
   add exButton("Zoom Out", tLeft, kTop + 12, 34, "Zoom out", "zoom-out", "ghost", lkColor("orange"), empty, empty, 0) + 8 to tLeft
   set the script of group "Zoom Out" to exScript("Zoom/out")
   put lkLabel("Status", lkR(tLeft + 8, kTop + 12, kRight - 16, kTop + 48), "", 12, lkColor("soft"), empty) into tObj
end buildZoom

private command buildRecolor
   local tObj, tLeft, tMode
   go card "Recolor"
   set the script of this card to exScript("Recolor/card")
   get courtBox("OriginalCourt", "272,160,622,510")
   get courtBox("RecoloredCourt", "634,160,984,510")
   get newPicture("Original", "283,171,611,499")
   get newPicture("Recolored", "645,171,973,499")
   put kLeft + 16 into tLeft
   repeat for each item tMode in "Hue,Greyscale,Sepia,Negative,Blueprint"
      add exButton("Mode " & tMode, tLeft, kTop + 12, 34, tMode, empty, "light", lkColor("orange"), empty, empty, 0) + 8 to tLeft
      set the script of group ("Mode " & tMode) to "on mouseUp" & return & "   recolorMode " & quote & tMode & quote & return & "end mouseUp"
   end repeat
   create scrollbar "Hue"
   put it into tObj
   set the style of tObj to "scale"
   set the startValue of tObj to 0
   set the endValue of tObj to 360
   set the thumbPosition of tObj to 150
   set the showValue of tObj to false
   set the rect of tObj to 272, 524, 984, 548
   set the script of tObj to exScript("Recolor/hue")
   put lkLabel("Status", lkR(272, 560, kRight - 16, kBottom - 16), "", 12, lkColor("soft"), empty) into tObj
end buildRecolor

private command buildHow
   local tBottom
   go card "How"
   get exPanel("Words", lkR(kLeft, kTop, kRight, kBottom), empty)
   get heading("WordsTitle", kLeft + 22, kTop + 18, kRight - 22, "The drawing library", 15, empty)
   put textBlock("Words1", kLeft + 22, kTop + 56, kRight - 30, \
         "drawingSvgCompile(tSvg, tOptions) and drawingSvgCompileFile(tPath, tOptions) make a drawing: set an image's text to it. " & \
         "With no options a drawing is byte for byte what it always was, so old stacks never change." & return & \
         "The options, a comma list or " & quote & "all" & quote & ": styles (style sheets), opacity, ids (url(#grad-1) and quoted ids), " & \
         "clip (clip-path and clipPath, nested too) and gradients (a radial gradient's focus at its centre)." & return & \
         "drawingDecode reads a drawing back into its shapes, drawingFlatten turns them into polygon points, and " & \
         "drawingSvgDecompile writes the drawing out as SVG again, clips and all." & return & \
         "In the IDE, File > Import As Control > Image File compiles an SVG with all, an image made from one has Convert to Graphics " & \
         "on its menu (revIDEConvertDrawingToGraphics in script), and Object > Copy Graphics as SVG Paths copies ovals and arcs as curves." & return & \
         "A drawing with a clip draws on OXT-Beyond 0.2.7-rc.6.12 and later. In a standalone, the compile needs the XML extension.", \
         13, lkColor("soft"), empty) into tBottom
end buildHow

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--SVG Lab: what OXT-Beyond 0.2.7 does with SVG, made for OXT-Beyond in 2026

--Each card's program is its card's script. What they share is here: the SVG the cards show,
--which is the OXT-Beyond logo (the stack's cLogoSvg) until you open one of your own.

-- The SVG the cards show
function svgCurrent
   if the cUserSvg of me is not empty then
      return the cUserSvg of me
   end if
   return the cLogoSvg of me
end svgCurrent

function svgCurrentName
   if the cUserName of me is not empty then
      return the cUserName of me
   end if
   return "The OXT-Beyond logo"
end svgCurrentName

-- Asks for an SVG file, and shows it from now on; false when none was chosen
function svgOpenFile
   local tPath, tText
   answer file "Open an SVG file:" with type "SVG files|svg"
   put it into tPath
   if tPath is empty then
      return false
   end if
   put textDecode(url ("binfile:" & tPath), "UTF-8") into tText
   if tText is empty then
      return false
   end if
   set the cUserSvg of me to tText
   set the itemDelimiter to slash
   set the cUserName of me to the last item of tPath
   return true
end svgOpenFile

command svgUseLogo
   set the cUserSvg of me to empty
   set the cUserName of me to empty
end svgUseLogo

-- pSvg compiled with pOptions ("all", a comma list, or empty for none). An error, or the
-- drawing library missing where this stack runs, goes into the result
function svgCompile pSvg, pOptions
   local tDrawing, tError
   try
      put drawingSvgCompile(pSvg, pOptions) into tDrawing
   catch tError
      return "The drawing library is not loaded here: open SVG Lab in OXT-Beyond's IDE." for error
   end try
   if the result is not empty then
      return "The SVG did not compile:" && line 1 of the result for error
   end if
   return tDrawing for value
end svgCompile
@*/

/*@ source/open
on mouseUp
   if svgOpenFile() then
      dispatch "svgRefresh" to this card
   end if
end mouseUp
@*/

/*@ source/logo
on mouseUp
   svgUseLogo
   dispatch "svgRefresh" to this card
end mouseUp
@*/

/*@ Logo/card
-- Every frame: the logo's SVG, with new numbers for the rays, the glow, the shine, the
-- electricity and the sparks, compiled and shown. The template is the stack's cLogoLive

local sRunning, sMessage, sFrames, sStart

on openCard
   logoStart
   pass openCard
end openCard

on closeCard
   logoStop
   pass closeCard
end closeCard

command logoStart
   if sRunning then
      exit logoStart
   end if
   put true into sRunning
   put 0 into sFrames
   put the milliseconds into sStart
   put "Pause" into field "Pause_label" of group "Pause"
   logoTick
end logoStart

command logoStop
   put false into sRunning
   if sMessage is not empty then
      cancel sMessage
   end if
   put empty into sMessage
   put "Play" into field "Pause_label" of group "Pause"
end logoStop

command logoToggle
   if sRunning then
      logoStop
   else
      logoStart
   end if
end logoToggle

on logoTick
   local tDrawing
   if not sRunning then
      exit logoTick
   end if
   put svgCompile(logoFrame(), "all") into tDrawing
   if the result is not empty then
      put the result into field "Status"
      logoStop
      exit logoTick
   end if
   set the text of image "Logo Live" to tDrawing
   add 1 to sFrames
   if sFrames mod 15 is 0 then
      put round(sFrames * 1000 / max(1, the milliseconds - sStart)) && "frames a second, each a fresh SVG." into field "Status"
   end if
   send "logoTick" to me in 20 milliseconds
   put the result into sMessage
end logoTick

function logoFrame
   local tSvg, tTime
   put the milliseconds / 1000 into tTime
   put the cLogoLive of this stack into tSvg
   replace "@RAYS@" with round(tTime * 8 mod 360, 1) in tSvg
   replace "@GLOW@" with round(0.34 + 0.14 * sin(tTime * 2.5), 2) in tSvg
   replace "@HALO@" with round(0.5 + 0.2 * sin(tTime * 7) + random(30) / 100, 2) in tSvg
   replace "@SHINE@" with round(tTime * 520 mod 1500 - 100) in tSvg
   replace "@ARCS@" with logoArc(705, 250, -1) & logoArc(790, 300, 1) in tSvg
   replace "@SPARKS@" with logoSparks(tTime) in tSvg
   return tSvg
end logoFrame

-- A jagged bolt of electricity, new every frame, leaving the logo's bolt
function logoArc pX, pY, pSide
   local tPoints, tIndex
   put pX & comma & pY into tPoints
   repeat with tIndex = 1 to 5
      add pSide * (14 + random(30)) to pX
      subtract random(44) - 8 from pY
      put space & pX & comma & pY after tPoints
   end repeat
   return "<polyline class='arc' stroke='#BFEFFF' stroke-width='5' fill='none' opacity='" & (random(6) + 3) / 10 & "' points='" & tPoints & "'/>"
end logoArc

-- Sparks that drift out from the bolt and fade
function logoSparks pTime
   local tIndex, tOut, tAge, tAngle, tDistance
   repeat with tIndex = 1 to 16
      put pTime / 2.4 + tIndex * 0.137 into tAge
      put tAge - trunc(tAge) into tAge
      put tIndex * 2.4 into tAngle
      put 60 + tAge * 300 into tDistance
      put "<circle cx='" & round(720 + tDistance * cos(tAngle)) & "' cy='" & round(270 + tDistance * sin(tAngle)) & \
            "' r='" & 3 + tIndex mod 5 & "' fill='#FFF4B0' opacity='" & round(1 - tAge, 2) & "'/>" after tOut
   end repeat
   return tOut
end logoSparks
@*/

/*@ Logo/pause
on mouseUp
   logoToggle
end mouseUp
@*/

/*@ Compare/card
-- The same SVG twice: with no options under the group "Wipe", which shows the left of the
-- line, and with every option beside it. Dragging moves the line

local sDragging

on openCard
   svgRefresh
   pass openCard
end openCard

command svgRefresh
   local tSvg, tOld, tNew
   put svgCurrent() into tSvg
   put svgCompile(tSvg) into tOld
   if the result is not empty then
      put the result into field "Status"
      exit svgRefresh
   end if
   put svgCompile(tSvg, "all") into tNew
   lock screen
   set the text of image "Before" to tOld
   set the text of image "After" to tNew
   compareTo the cSplit of me
   unlock screen
   put svgCurrentName() & ":" && the number of bytes of tOld && "bytes with no options," && \
         the number of bytes of tNew && "with all." into field "Status"
end svgRefresh

-- The line at pX, and the old compile left of it
command compareTo pX
   local tLeft, tRight
   put the left of image "After" into tLeft
   put the right of image "After" into tRight
   put max(tLeft + 1, min(tRight, round(pX))) into pX
   set the cSplit of me to pX
   set the rect of group "Wipe" to tLeft, the top of image "After", pX, the bottom of image "After"
   set the points of graphic "Split" to pX & comma & the top of image "After" & return & pX & comma & the bottom of image "After"
end compareTo

on mouseDown
   if within(image "After", the mouseLoc) or the long id of the target is the long id of graphic "Split" then
      put true into sDragging
      compareTo the mouseH
   end if
   pass mouseDown
end mouseDown

on mouseMove pX, pY
   if sDragging then
      compareTo pX
   end if
   pass mouseMove
end mouseMove

on mouseUp
   put false into sDragging
   pass mouseUp
end mouseUp

on mouseRelease
   put false into sDragging
   pass mouseRelease
end mouseRelease
@*/

/*@ Options/card
-- Compiles the SVG with the options ticked; Convert makes it into graphics (the IDE's
-- revIDEConvertDrawingToGraphics), and Export writes it out as SVG (drawingSvgDecompile)

constant kOptions = "styles,opacity,ids,clip,gradients"

on openCard
   svgRefresh
   pass openCard
end openCard

on closeCard
   -- (the graphics are made for the moment: the saved stack keeps none)
   optionsForget
   pass closeCard
end closeCard

-- The options ticked, as the compile takes them
function optionsList
   local tName, tList
   repeat for each item tName in kOptions
      if the hilite of button tName then
         put tName & comma after tList
      end if
   end repeat
   delete the last char of tList
   if the number of items of tList is the number of items of kOptions then
      return "all"
   end if
   return tList
end optionsList

command svgRefresh
   local tDrawing, tStart, tInfo, tOptions
   optionsForget
   put optionsList() into tOptions
   put the milliseconds into tStart
   put svgCompile(svgCurrent(), tOptions) into tDrawing
   if the result is not empty then
      put the result into field "Status"
      exit svgRefresh
   end if
   put the milliseconds - tStart into tStart
   set the text of image "Work" to tDrawing
   put drawingDecode(tDrawing) into tInfo
   put svgCurrentName() & ":" && the number of elements of tInfo["shapes"] && "shapes," && \
         the number of elements of tInfo["clips"] && "clips." & return & \
         "drawingSvgCompile(tSvg, " & quote & tOptions & quote & ") took" && tStart && "ms." into field "Status"
end svgRefresh

command optionsForget
   lock messages
   if there is a group "Work graphics" then
      delete group "Work graphics"
   end if
   unlock messages
   show image "Work"
end optionsForget

command optionsConvert
   local tGroup, tError
   if the environment is not "development" then
      put "Convert to Graphics is part of the IDE: open SVG Lab there." into field "Status"
      exit optionsConvert
   end if
   optionsForget
   put revIDEConvertDrawingToGraphics(the long id of image "Work") into tGroup
   put the result into tError
   if tError is not empty then
      put "Could not convert:" && tError into field "Status"
      exit optionsConvert
   end if
   hide image "Work"
   put "Made" && the number of graphics of tGroup && "polygon graphics, each with its colours, gradients and opacity." & \
         return & "Select one with the pointer tool to edit it; any change here compiles again." into field "Status"
end optionsConvert

command optionsExport
   local tSvg, tPath
   put drawingSvgDecompile(the text of image "Work") into tSvg
   if the result is not empty then
      put "Could not export:" && the result into field "Status"
      exit optionsExport
   end if
   ask file "Save the SVG as:" with "exported.svg"
   put it into tPath
   if tPath is empty then
      exit optionsExport
   end if
   put textEncode(tSvg, "UTF-8") into url ("binfile:" & tPath)
   if the result is not empty then
      put "Could not write the file:" && the result into field "Status"
      exit optionsExport
   end if
   put "drawingSvgDecompile wrote" && the number of bytes of tSvg && "bytes of SVG." into field "Status"
end optionsExport
@*/

/*@ Options/option
on mouseUp
   svgRefresh
end mouseUp
@*/

/*@ Options/convert
on mouseUp
   optionsConvert
end mouseUp
@*/

/*@ Options/export
on mouseUp
   optionsExport
end mouseUp
@*/

/*@ Zoom/card
-- The SVG as a drawing on the left, and as a 200 pixel bitmap of the same drawing on the
-- right, both zoomed by the same amount about the same spot

local sZoom, sFocusX, sFocusY

on openCard
   svgRefresh
   pass openCard
end openCard

command svgRefresh
   local tDrawing, tPng
   put svgCompile(svgCurrent(), "all") into tDrawing
   if the result is not empty then
      put the result into field "Status"
      exit svgRefresh
   end if
   lock screen
   set the text of image "Vector" to tDrawing
   set the rect of image "Vector" to 0, 0, 200, 200
   export snapshot from image "Vector" at size 200,200 to tPng as PNG
   set the text of image "Bitmap" to tPng
   set the resizeQuality of image "Bitmap" to "normal"
   set the cDrawingBytes of me to the number of bytes of tDrawing
   set the cPngBytes of me to the number of bytes of tPng
   put 0.5 into sFocusX
   put 0.5 into sFocusY
   if sZoom is empty then
      put 300 into sZoom
   end if
   zoomTo sZoom
   unlock screen
end svgRefresh

command zoomTo pPercent
   local tSize, tX, tY
   put max(100, min(1600, round(pPercent))) into sZoom
   put round(200 * sZoom / 100) into tSize
   put item 1 of the loc of group "VectorPanel" - round(tSize * sFocusX) into tX
   put item 2 of the loc of group "VectorPanel" - round(tSize * sFocusY) into tY
   set the rect of image "Vector" to tX, tY, tX + tSize, tY + tSize
   put item 1 of the loc of group "BitmapPanel" - round(tSize * sFocusX) into tX
   set the rect of image "Bitmap" to tX, tY, tX + tSize, tY + tSize
   put sZoom & "%: a" && the cDrawingBytes of me && "byte drawing, sharp at any size, beside a" && \
         the cPngBytes of me && "byte PNG of it. Click a picture to zoom in on that spot." into field "Status"
end zoomTo

command zoomBy pFactor
   zoomTo sZoom * pFactor
end zoomBy

-- A click on either picture puts that spot of both in the middle
command zoomFocus pImage
   put max(0, min(1, (the mouseH - the left of pImage) / the width of pImage)) into sFocusX
   put max(0, min(1, (the mouseV - the top of pImage) / the height of pImage)) into sFocusY
   zoomTo sZoom
end zoomFocus
@*/

/*@ Zoom/picture
on mouseUp
   zoomFocus the long id of me
end mouseUp
@*/

/*@ Zoom/in
on mouseUp
   zoomBy 2
end mouseUp
@*/

/*@ Zoom/out
on mouseUp
   zoomBy 0.5
end mouseUp
@*/

/*@ Recolor/card
-- A drawing keeps its colours as plain text once drawingSvgDecompile writes it out, so a
-- script can restyle any SVG: decompile, change the colours, compile again

local sSvg, sColors, sMode, sPending

on openCard
   svgRefresh
   pass openCard
end openCard

command svgRefresh
   local tDrawing, tToken
   put svgCompile(svgCurrent(), "all") into tDrawing
   if the result is not empty then
      put the result into field "Status"
      exit svgRefresh
   end if
   set the text of image "Original" to tDrawing
   put drawingSvgDecompile(tDrawing) into sSvg
   put empty into sColors
   set the itemDelimiter to quote
   repeat for each item tToken in sSvg
      if char 1 of tToken is "#" and the number of chars of tToken is 7 then
         put true into sColors[tToken]
      end if
   end repeat
   if sMode is empty then
      put "Hue" into sMode
   end if
   recolorNow
end svgRefresh

command recolorMode pMode
   put pMode into sMode
   recolorNow
end recolorMode

-- A drag sends many messages: only the last one recolours
command recolorSoon
   if sPending is not empty then
      cancel sPending
   end if
   send "recolorNow" to me in 60 milliseconds
   put the result into sPending
end recolorSoon

command recolorNow
   local tMap, tColor, tOut, tToken, tDrawing, tStart
   put empty into sPending
   put the milliseconds into tStart
   repeat for each key tColor in sColors
      put recolorColor(tColor, sMode, the thumbPosition of scrollbar "Hue") into tMap[tColor]
   end repeat
   set the itemDelimiter to quote
   repeat for each item tToken in sSvg
      if tMap[tToken] is not empty then
         put tMap[tToken] & quote after tOut
      else
         put tToken & quote after tOut
      end if
   end repeat
   delete the last char of tOut
   put svgCompile(tOut, "all") into tDrawing
   if the result is not empty then
      put the result into field "Status"
      exit recolorNow
   end if
   set the text of image "Recolored" to tDrawing
   put sMode & ":" && the number of elements of sColors && "colours changed in the decompiled SVG, compiled again in" && \
         the milliseconds - tStart && "ms. The slider turns the hue." into field "Status"
end recolorNow

function recolorColor pColor, pMode, pHue
   local tR, tG, tB, tA, tC, tS, tGrey
   put baseConvert(char 2 to 3 of pColor, 16, 10) into tR
   put baseConvert(char 4 to 5 of pColor, 16, 10) into tG
   put baseConvert(char 6 to 7 of pColor, 16, 10) into tB
   put 0.213 * tR + 0.715 * tG + 0.072 * tB into tGrey
   switch pMode
      case "Hue"
         put pHue * pi / 180 into tA
         put cos(tA) into tC
         put sin(tA) into tS
         return recolorHex((0.213 + tC * 0.787 - tS * 0.213) * tR + (0.715 - tC * 0.715 - tS * 0.715) * tG + (0.072 - tC * 0.072 + tS * 0.928) * tB, \
               (0.213 - tC * 0.213 + tS * 0.143) * tR + (0.715 + tC * 0.285 + tS * 0.140) * tG + (0.072 - tC * 0.072 - tS * 0.283) * tB, \
               (0.213 - tC * 0.213 - tS * 0.787) * tR + (0.715 - tC * 0.715 + tS * 0.715) * tG + (0.072 + tC * 0.928 + tS * 0.072) * tB)
      case "Greyscale"
         return recolorHex(tGrey, tGrey, tGrey)
      case "Sepia"
         return recolorHex(tGrey * 1.07, tGrey * 0.74, tGrey * 0.43)
      case "Negative"
         return recolorHex(255 - tR, 255 - tG, 255 - tB)
      case "Blueprint"
         return recolorHex(tGrey * 0.25, tGrey * 0.55, 90 + tGrey * 0.65)
   end switch
   return pColor
end recolorColor

function recolorHex pR, pG, pB
   return format("#%02x%02x%02x", max(0, min(255, round(pR))), max(0, min(255, round(pG))), max(0, min(255, round(pB))))
end recolorHex
@*/

/*@ Recolor/hue
on scrollbarDrag
   recolorSoon
end scrollbarDrag
@*/
