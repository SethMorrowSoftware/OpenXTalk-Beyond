script "OXTExampleBouncingBalls"
-- OXT-Beyond: builds "Bouncing Balls", the remaster of LiveCode Ltd's Balls
-- (2011), the first sample of LiveCode Community's Start Center, which is
-- in ide/Resources/Start Center/samples/sample_1/Balls.livecode and stays
-- there as its authors made it. LiveCode Community, and so the sample, is
-- free software under the GNU General Public License, version 3.
--
-- The sample makes twenty balls and bounces them around its card: each
-- ball is a graphic whose behavior is the button "bounce", the Bounce
-- Behavior, which pulls it down with gravity, slows it with friction,
-- bounces it off the edges and lets the mouse throw it; one loop on the
-- card moves them all. The remaster keeps those scripts and their
-- comments, in the window every remastered example has
-- (builder.livecodescript): the balls bounce on the stage of a wide card,
-- whose drawer shows the scripts, and three pages explain the behavior,
-- the vectors and the loop. What changed in the scripts is where the
-- balls go (the original's card was 1024 by 768: the edges are now the
-- court's, the dark part of the stage), and what the window needs: the
-- loop stops when the card closes, and works in its own stack. The
-- original's mistakes are mended where they show, each with a comment.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- The court, where the balls bounce: the stage of the wide card, below
-- its buttons
constant kCourt = "270,166,986,602"
-- The balls' colours, bright ones (the light and dark of each are mixed
-- from it)
constant kBallColors = "251,113,133|251,146,60|252,211,77|163,230,53|52,211,153|34,211,238|56,189,248|129,140,248|167,139,250|232,121,249|244,114,182|248,113,113"
-- The words are measured here, but the IDE's font is wider than the
-- build's, by as much as a tenth (measured at 13 points): words get room
-- for a font this much narrower (fixLines, vectorTag)
constant kFontRoom = 0.88

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   exAddIcon "circle-plus", "<circle cx='12' cy='12' r='10'/><path d='M8 12h8'/><path d='M12 8v8'/>"
   exAddIcon "eraser", "<path d='m7 21-4.3-4.3c-1-1-1-2.5 0-3.4l9.6-9.6c1-1 2.5-1 3.4 0l5.6 5.6c1 1 1 2.5 0 3.4L13 21'/>" & \
         "<path d='M22 21H7'/><path d='m5 11 9 9'/>"
   exAddIcon "vibrate", "<path d='m2 8 2 2-2 2 2 2-2 2'/><path d='m22 8-2 2 2 2-2 2 2 2'/><rect width='8' height='14' x='8' y='5' rx='1'/>"
   exAddIcon "hand", "<path d='M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2'/><path d='M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2'/>" & \
         "<path d='M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8'/>" & \
         "<path d='M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15'/>"
   exAddIcon "share-2", "<circle cx='18' cy='5' r='3'/><circle cx='6' cy='12' r='3'/><circle cx='18' cy='19' r='3'/>" & \
         "<line x1='8.59' x2='15.42' y1='13.51' y2='17.49'/><line x1='15.41' x2='8.59' y1='6.51' y2='10.49'/>"
   exAddIcon "timer", "<line x1='10' x2='14' y1='2' y2='2'/><line x1='12' x2='15' y1='14' y2='11'/><circle cx='12' cy='14' r='8'/>"
   exAddIcon "circle-dot", "<circle cx='12' cy='12' r='10'/><circle cx='12' cy='12' r='1'/>"
   exAddIcon "move-down-right", "<path d='M19 13V19H13'/><path d='M5 5L19 19'/>"
   put "Bouncing Balls" into tInfo["name"]
   put "after LiveCode Ltd" into tInfo["credit"]
   put "orbit" into tInfo["icon"]
   put lkColor("orange") into tInfo["accent"]
   put lkColor("pink") into tInfo["accent2"]
   put "Part" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Bouncing Balls|Balls that bounce with gravity and friction, each moved by one behavior.|orbit|front" & return & \
         "Main|Bounce|Click the stage for a ball, or drag a ball and let go to throw it.|circle-dot|wide" & return & \
         "Behavior|Behavior|One script, in one button, moves every ball on the stage.|share-2|page" & return & \
         "Vectors|Vectors|A ball's motion is two numbers: how far it goes across and down in a step.|move-down-right|page" & return & \
         "Loop|The Loop|One handler moves every ball, forty times a second, and keeps time.|timer|page" & return & \
         "Render|Drawing|Accelerated rendering draws again only where the balls have moved.|zap|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   buildMain
   buildBehavior
   buildVectors
   buildLoop
   buildRender
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Bouncing Balls.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

-- A script block whose script has comments of the /* kind: in this file
-- their ends are written *\/, since the first end would end the block too
private function blockScript pKey
   local tScript
   put exScript(pKey) into tScript
   replace ("*" & "\/") with ("*" & "/") in tScript
   return tScript
end blockScript

################################################################################
#
# Drawing helpers
#

-- A ball as the program draws one: a colour of kBallColors, lit from its
-- top left
private function ball pName, pLeft, pTop, pSize, pIndex, pGroup
   local tObj, tBase
   set the itemDelimiter to "|"
   put item ((pIndex - 1) mod the number of items of kBallColors) + 1 of kBallColors into tBase
   set the itemDelimiter to comma
   put lkOval(pName, lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), tBase, pGroup) into tObj
   ballLook tObj, tBase
   return tObj
end ball

-- The look of a ball of colour pBase: a light near its top left, its colour,
-- and a darker edge and rim
private command ballLook pObj, pBase
   local tSize, tL, tT
   put the width of pObj into tSize
   put the left of pObj into tL
   put the top of pObj into tT
   set the lineSize of pObj to 2
   set the foregroundColor of pObj to ballDark(pBase)
   set the fillGradient["type"] of pObj to "radial"
   set the fillGradient["ramp"] of pObj to "0.00," & ballLight(pBase) & return & "0.50," & pBase & return & "1.00," & ballDark(pBase)
   set the fillGradient["from"] of pObj to (tL + tSize div 3) & "," & (tT + tSize div 3)
   set the fillGradient["to"] of pObj to (tL + tSize + tSize div 6) & "," & (tT + tSize div 3)
   set the fillGradient["via"] of pObj to (tL + tSize div 3) & "," & (tT + tSize + tSize div 6)
end ballLook

private function ballLight pBase
   return lkMix(pBase, "255,255,255", 0.6)
end ballLight

private function ballDark pBase
   return lkMix(pBase, "15,23,42", 0.45)
end ballDark

-- The palette the program picks its balls' colours from: a line for each,
-- light|colour|dark
private function ballPalette
   local tBase, tOut
   set the itemDelimiter to "|"
   repeat for each item tBase in kBallColors
      put ballLight(tBase) & "|" & tBase & "|" & ballDark(tBase) & return after tOut
   end repeat
   set the itemDelimiter to comma
   delete the last char of tOut
   return tOut
end ballPalette

-- Words, a paragraph a line, with room between them, as tall as they are
-- (and their last line's tails); returns their bottom
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
-- paragraph (a vertical tab): its words keep these lines, and fit them,
-- in the IDE's wider font too, and its height is right in both
private command fixLines pObj
   local tRect, tRoom, tSource, tParagraph, tLine, tLines, tText, tCount, tWidth, tMended
   put the rect of pObj into tRect
   put round(the width of pObj * kFontRoom) into tRoom
   put the text of pObj into tSource
   repeat for each line tParagraph in tSource
      put empty into tLines
      set the text of pObj to tParagraph
      set the width of pObj to tRoom
      put the number of lines of the formattedText of pObj into tCount
      -- (a word or two alone on the last line looks lost: the lines get a
      -- little narrower, as many as they were, until it has company)
      if tCount > 1 and the number of words of line -1 of the formattedText of pObj < 3 then
         put false into tMended
         put tRoom into tWidth
         repeat while tWidth > tRoom * 0.75 and not tMended
            subtract 2 from tWidth
            set the width of pObj to tWidth
            if the number of lines of the formattedText of pObj > tCount then
               exit repeat
            end if
            put the number of words of line -1 of the formattedText of pObj >= 3 into tMended
         end repeat
         if not tMended then
            -- (no narrower lines mend it: as they were)
            set the width of pObj to tRoom
         end if
      end if
      repeat for each line tLine in the formattedText of pObj
         -- (a line that wraps ends with the space it wraps at)
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

-- A heading, bold
private function heading pName, pLeft, pTop, pRight, pText, pSize, pGroup
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + pSize + 10), pText, pSize, lkColor("ink"), pGroup) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   return tObj
end heading

-- An icon on a tint of a colour, in a rounded square
private command iconBadge pName, pIcon, pLeft, pTop, pSize, pColor, pGroup
   local tInset
   get lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), lkMix("255,255,255", pColor, 0.13), pSize div 3, pGroup)
   put (pSize - 20) div 2 into tInset
   get exIcon(pName & "_icon", pIcon, pColor, lkR(pLeft + tInset, pTop + tInset, pLeft + tInset + 20, pTop + tInset + 20), pGroup)
end iconBadge

-- A tip: a light bulb and a line or two, on a tint of the accent
private command tipBox pName, pRect, pText
   local tObj, tL, tT, tR, tB, tMid
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   put item 4 of pRect into tB
   put (tT + tB) div 2 into tMid
   get lkBox(pName, pRect, lkMix("255,255,255", lkColor("orange"), 0.08), 12, empty)
   get exIcon(pName & "Icon", "lightbulb", lkColor("orange"), lkR(tL + 14, tMid - 10, tL + 34, tMid + 10), empty)
   put lkLabel(pName & "Text", lkR(tL + 46, tT + 8, tR - 12, tB - 6), pText, 12, lkColor("soft"), empty) into tObj
   fixLines tObj
   set the height of tObj to the formattedHeight of tObj + 4
   set the top of tObj to tMid - (the formattedHeight of tObj) div 2 - 2
end tipBox

-- A line, an arrow if pArrow
private function drawLine pName, pPoints, pColor, pSize, pArrow, pDashes, pGroup
   local tObj
   if pGroup is empty then
      create graphic pName
   else
      create graphic pName in group pGroup
   end if
   put it into tObj
   set the style of tObj to "line"
   set the points of tObj to pPoints
   set the lineSize of tObj to pSize
   set the foregroundColor of tObj to pColor
   set the antialiased of tObj to true
   set the capStyle of tObj to "round"
   if pArrow then
      set the endArrow of tObj to true
      set the arrowSize of tObj to 3
   end if
   if pDashes is not empty then
      set the dashes of tObj to pDashes
   end if
   return tObj
end drawLine

-- A dark panel of code, like the window's scripts panel: three dots, what
-- it shows, and the code in colour, each line in from the left as far as
-- its own indent
private function codeBox pName, pRect, pCaption, pCode
   local tObj, tL, tT, tR, tB
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   put item 4 of pRect into tB
   put lkBox(pName, pRect, lkColor("code"), 16, empty) into tObj
   lkShadow tObj, 16, 4, 18
   get lkOval(pName & "_dot1", lkR(tL + 16, tT + 15, tL + 25, tT + 24), "248,113,113", empty)
   get lkOval(pName & "_dot2", lkR(tL + 31, tT + 15, tL + 40, tT + 24), "251,191,36", empty)
   get lkOval(pName & "_dot3", lkR(tL + 46, tT + 15, tL + 55, tT + 24), "52,211,153", empty)
   put lkLabel(pName & "_caption", lkR(tL + 66, tT + 12, tR - 14, tT + 28), pCaption, 11, "100,116,139", empty) into tObj
   set the dontWrap of tObj to true
   put lkLabel(pName & "_code", lkR(tL + 6, tT + 36, tR - 8, tB - 8), empty, 12, lkColor("codeInk"), empty) into tObj
   set the textFont of tObj to "Source Code Pro"
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 18
   set the margins of tObj to "8,4,8,4"
   -- (the stack script puts the code in another monospaced font where
   -- there is no Source Code Pro)
   set the cCode of tObj to true
   codeInto tObj, pCode
   return tObj
end codeBox

-- Code in colour, a line a paragraph, each in from the left as far as its
-- own indent, and a long line's next lines further in
private command codeInto pField, pCode
   local tHtml, tLine, tCount, tSpaces, tIndent, tIndex, tCharWidth
   put 0 into tCount
   repeat for each line tLine in pCode
      add 1 to tCount
      put 0 into tSpaces
      repeat while char tSpaces + 1 of tLine is space
         add 1 to tSpaces
      end repeat
      put tSpaces into tIndent[tCount]
      put "<p>" & lkCodeLineHtml(char tSpaces + 1 to -1 of tLine) & "</p>" after tHtml
   end repeat
   set the htmlText of pField to tHtml
   -- (a monospaced font's letters are 0.6 of its size across: Source Code
   -- Pro's, Droid Sans Mono's and DejaVu Sans Mono's; measured, the font
   -- the build has would answer for another)
   put 0.6 * the textSize of pField into tCharWidth
   repeat with tIndex = 1 to tCount
      set the leftIndent of line tIndex of pField to round((tIndent[tIndex] + 3) * tCharWidth)
      set the firstIndent of line tIndex of pField to -round(3 * tCharWidth)
   end repeat
end codeInto

-- A panel of rows, each an icon and a line or two of words; with pActions
-- (a line for each row), a row is a button that goes to a card
private command rowsPanel pName, pRect, pTitle, pRows, pColor, pActions
   local tL, tT, tR, tB, tIndex, tRow, tTop, tObj, tGroup
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   put item 4 of pRect into tB
   get lkGroup(pName, pRect, empty)
   get exPanel(pName & "_bg", pRect, pName)
   put heading(pName & "_title", tL + 20, tT + 18, tR - 20, pTitle, 15, pName) into tObj
   set the itemDelimiter to "|"
   put 0 into tIndex
   repeat for each line tRow in pRows
      add 1 to tIndex
      put tT + 52 + (tIndex - 1) * 48 into tTop
      put pName & "_row" & tIndex into tGroup
      get lkGroup(tGroup, lkR(tL + 10, tTop - 6, tR - 10, tTop + 42), pName)
      get lkBox(tGroup & "_bg", lkR(tL + 10, tTop - 6, tR - 10, tTop + 42), "255,255,255", 12, tGroup)
      iconBadge tGroup & "_badge", item 1 of tRow, tL + 20, tTop, 36, pColor, tGroup
      put lkLabel(tGroup & "_text", lkR(tL + 68, tTop, tR - 22, tTop + 38), item 2 of tRow, 13, lkColor("soft"), tGroup) into tObj
      -- (one line or two, in the middle of the row, and room for the
      -- last line's tails)
      fixLines tObj
      set the height of tObj to the formattedHeight of tObj + 4
      set the top of tObj to tTop + 16 - (the formattedHeight of tObj) div 2
      if line tIndex of pActions is not empty then
         set the cRest of group tGroup to "255,255,255"
         set the cLit of group tGroup to lkMix("255,255,255", pColor, 0.07)
         set the cAction of group tGroup to line tIndex of pActions
      end if
   end repeat
   set the itemDelimiter to comma
end rowsPanel

################################################################################
#
# The cards
#

-- The front page: what this is, a tile for each part, and what to try
private command buildFront
   local tObj, tIndex, tSizes, tX, tY
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 272), lkColor("orange") & "|" & lkColor("pink"), \
         "LIVECODE LTD  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "Balls that bounce, fall and fly", \
         "Every ball is a graphic with one shared behavior: gravity pulls it down, friction slows it, " & \
         "and the edges bounce it back. Click for more balls, or grab one and throw it."
   -- Balls in the banner, falling along a dashed arc to rest at its right
   get drawLine("hero_arc", "838,214" & return & "872,144" & return & "910,116" & return & "948,118" & return & \
         "980,152" & return & "992,206", "255,255,255", 2, false, "3,6", "hero")
   set the blendLevel of it to 45
   put "872,144" & return & "910,116" & return & "948,118" & return & "980,152" into tSizes
   repeat with tIndex = 1 to 4
      put item 1 of line tIndex of tSizes into tX
      put item 2 of line tIndex of tSizes into tY
      get ball("hero_trail" & tIndex, tX - 7, tY - 7, 14, 8, "hero")
      set the blendLevel of it to 80 - tIndex * 12
   end repeat
   get ball("hero_ball1", 900, 200, 56, 2, "hero")
   lkShadow it, 14, 4, 30
   get ball("hero_ball2", 862, 226, 30, 7, "hero")
   lkShadow it, 10, 3, 30
   get ball("hero_ball3", 958, 222, 34, 5, "hero")
   lkShadow it, 10, 3, 30
   get ball("hero_ball4", 976, 196, 22, 11, "hero")
   lkShadow it, 8, 2, 30
   -- (and a sparkle of the banner's that would be on its words, in a
   -- wider font than the build's, moved)
   set the loc of graphic "hero_star2" to 806, 128
   exProgramTiles 288, 5, 60, 10
   -- What to try, and what it teaches
   rowsPanel "Try", lkR(kLeft, 364, 620, kBottom), "Try it", \
         "mouse-pointer-click|Click the stage: a new ball drops in where you click." & return & \
         "hand|Drag a ball and let go: it flies off the way you threw it." & return & \
         "vibrate|Simulate Shake gives every ball a push in a new direction." & return & \
         "circle-plus|Create Balls asks how many to make, and Clear Balls takes them away.", \
         lkColor("orange"), empty
   rowsPanel "Learn", lkR(636, 364, kRight, kBottom), "What you will learn", \
         "share-2|One behavior that moves many objects, each in its own way" & return & \
         "move-down-right|Vectors: gravity, friction and a bounce, in two numbers" & return & \
         "timer|A loop that keeps time, with send in milliseconds" & return & \
         "zap|Drawing with lock screen, layerMode and accelerated rendering", \
         lkColor("pink"), "go Behavior" & return & "go Vectors" & return & "go Loop" & return & "go Render"
end buildFront

-- The program: the court on the stage, the buttons above it, and the
-- button "bounce", whose script is every ball's behavior
private command buildMain
   local tObj, tLeft, tWidth, tCourt
   go card "Main"
   set the script of this card to blockScript("Main/card")
   set the cPalette of this card to ballPalette()
   -- (first, so that its chip comes after the card's)
   create button "bounce"
   put it into tObj
   set the label of tObj to "Bounce Behavior"
   set the rect of tObj to kLeft + 16, kTop + 14, kLeft + 160, kTop + 46
   set the script of tObj to exScript("Main/bounce")
   hide tObj
   -- The court: the balls bounce inside it
   put kCourt into tCourt
   put lkBox("Court", tCourt, lkColor("side"), 14, empty) into tObj
   lkGradient tObj, "30,41,59|20,24,54|15,23,42", item 1 of tCourt & "," & item 2 of tCourt, item 1 of tCourt & "," & item 4 of tCourt
   put lkLabel("Hint", lkR(item 1 of tCourt + 18, item 4 of tCourt - 32, item 3 of tCourt - 18, item 4 of tCourt - 12), \
         "Click for a ball  " & numToCodepoint(183) & "  drag a ball and let go to throw it", 12, "100,116,139", empty) into tObj
   set the dontWrap of tObj to true
   -- The buttons, restyled, above the court
   put kLeft + 14 into tLeft
   put exButton("Create Balls", tLeft, kTop + 14, 34, "Create Balls", "circle-plus", "primary", lkColor("orange"), empty, empty, 0) into tWidth
   set the script of group "Create Balls" to exScript("Main/Create Balls")
   add tWidth + 10 to tLeft
   put exButton("Clear Balls", tLeft, kTop + 14, 34, "Clear Balls", "eraser", "ghost", lkColor("orange"), empty, empty, 0) into tWidth
   set the script of group "Clear Balls" to exScript("Main/Clear Balls")
   add tWidth + 10 to tLeft
   put exButton("Simulate Shake", tLeft, kTop + 14, 34, "Simulate Shake", "vibrate", "ghost", lkColor("orange"), empty, empty, 0) into tWidth
   set the script of group "Simulate Shake" to exScript("Main/Simulate Shake")
   -- The original's checkbox, whose hilite the stack script reads, as a
   -- switch: a track and a knob under the button, which shows its name
   put lkBox("SwitchTrack", lkR(kRight - 220, kTop + 21, kRight - 184, kTop + 41), lkColor("orange"), 10, empty) into tObj
   put lkOval("SwitchKnob", lkR(kRight - 202, kTop + 23, kRight - 186, kTop + 39), "255,255,255", empty) into tObj
   lkShadow tObj, 4, 1, 30
   create button "toggleGraphics"
   put it into tObj
   set the style of tObj to "transparent"
   set the showName of tObj to true
   set the label of tObj to "Accelerated rendering"
   set the textAlign of tObj to "left"
   set the textSize of tObj to 13
   set the textColor of tObj to lkColor("soft")
   set the autoHilite of tObj to false
   set the hiliteFill of tObj to false
   set the hiliteBorder of tObj to false
   set the showFocusBorder of tObj to false
   set the traversalOn of tObj to false
   set the hilite of tObj to true
   -- (room for its name in a wider font than the build's, as the IDE's is)
   set the rect of tObj to kRight - 224, kTop + 14, kRight - 10, kTop + 48
   set the leftMargin of tObj to 48
   set the cOn of tObj to lkColor("orange")
   set the cOff of tObj to "203,213,225"
   set the script of tObj to exScript("Main/toggleGraphics")
   -- How many balls there are, in the header
   put lkLabel("CountLabel", "740,16,872,30", "BALLS", 11, lkColor("muted"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Count", "720,28,872,66", "0", 30, lkColor("orange"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
end buildMain

-- One behavior, many balls: the words, a picture of the button and five
-- balls that use its script, and the code on either side of it
private command buildBehavior
   local tObj, tBottom, tIndex, tBall, tBalls, tX, tSize
   go card "Behavior"
   -- The words
   get exPanel("Words", lkR(kLeft, kTop, 696, 424), empty)
   get heading("WordsTitle", kLeft + 22, kTop + 20, 680, "One script, many balls", 18, empty)
   put textBlock("Words1", kLeft + 22, kTop + 60, 674, \
         "A ball has no script of its own: its behavior is the button " & quote & "bounce" & quote & \
         ", the Bounce Behavior. Messages sent to the ball (init, bounceBall, a click) run that " & \
         "button's script, and in it, me is the ball." & return & \
         "Each ball keeps its own copy of the script's local variables: its vector, its size, its edges " & \
         "and whether it is being dragged. So twenty balls share one script, and move twenty ways." & return & \
         "The behavior also gives each ball a property, uVector, which Simulate Shake sets.", \
         13, lkColor("soft"), empty) into tBottom
   -- Where to read all of it
   tipBox "Tip", lkR(kLeft + 16, 360, 680, 408), "On the Bounce card, open Scripts and choose bounce: " & \
         "the whole behavior is there, with its comments."
   -- The picture: the button, and five balls that use its script, each
   -- with a vector of its own
   get exPanel("Picture", lkR(712, kTop, kRight, 424), empty)
   get lkBox("Button", lkR(744, kTop + 24, 968, kTop + 84), lkColor("code"), 14, empty)
   lkShadow it, 14, 4, 22
   get exIcon("ButtonIcon", "code", lkMix(lkColor("orange"), "255,255,255", 0.25), lkR(764, kTop + 44, 784, kTop + 64), empty)
   put lkLabel("ButtonName", lkR(798, kTop + 35, 964, kTop + 53), "button " & quote & "bounce" & quote, 13, "255,255,255", empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("ButtonLabel", lkR(798, kTop + 55, 964, kTop + 73), "the Bounce Behavior", 12, lkColor("muted"), empty) into tObj
   -- (a ball a line: its middle across, its size and its vector)
   put "742,32,-7,3" & return & "799,38,5,-8" & return & "856,44,2,9" & return & "913,38,8,4" & return & "970,32,-6,-5" into tBalls
   repeat with tIndex = 1 to 5
      put line tIndex of tBalls into tBall
      put item 1 of tBall into tX
      put item 2 of tBall into tSize
      get drawLine("Link" & tIndex, "856," & (kTop + 86) & return & tX & "," & (296 - tSize div 2 - 8), \
            lkMix("255,255,255", lkColor("orange"), 0.55), 2, true, "4,5", empty)
      get ball("Ball" & tIndex, tX - tSize div 2, 296 - tSize div 2, tSize, tIndex * 2 + 1, empty)
      lkShadow it, 10, 3, 25
      put lkLabel("Vector" & tIndex, lkR(tX - 30, 324, tX + 30, 340), item 3 of tBall & "," & item 4 of tBall, \
            11, lkColor("muted"), empty, "center") into tObj
   end repeat
   put lkLabel("PictureNote", lkR(724, 360, 988, 376), "five balls, one script, five vectors", 11, lkColor("muted"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("PictureCaption", lkR(724, 384, 988, 402), "behavior: the long id of button " & quote & "bounce" & quote, \
         12, lkColor("soft"), empty, "center") into tObj
   -- The code
   get codeBox("MakeCode", lkR(kLeft, 440, 696, kBottom), "createBall, in the script of the card " & quote & "Main" & quote, \
         "create graphic" & return & \
         "set the behavior of it to the long id of button " & quote & "bounce" & quote & return & \
         "set the layerMode of it to " & quote & "dynamic" & quote & return & \
         "set the loc of it to the mouseloc" & return & \
         "-- its size, shape and colour" & return & \
         "send " & quote & "init" & quote & " to it")
   get codeBox("PropCode", lkR(712, 440, kRight, kBottom), "uVector, in the Bounce Behavior", \
         "getProp uVector" & return & \
         "   return sVector" & return & \
         "end uVector" & return & \
         return & \
         "setProp uVector pX, pY" & return & \
         "   put (pX,pY) into sVector" & return & \
         "end uVector")
end buildBehavior

-- Vectors: a thrown ball, step by step as the behavior moves it, with its
-- vector where it is thrown, at the top and at the floor; the words, and
-- the code that falls and bounces
private command buildVectors
   local tObj, tBottom, tCourt, tX, tY, tVx, tVy, tStep, tSize, tFloor, tCx, tCy, tTagged, tTag, tShown
   go card "Vectors"
   get exPanel("Picture", lkR(kLeft, kTop, kRight, 356), empty)
   put lkR(kLeft + 14, kTop + 14, kRight - 14, 342) into tCourt
   put lkBox("Court", tCourt, lkColor("side"), 12, empty) into tObj
   lkGradient tObj, "30,41,59|20,24,54|15,23,42", item 1 of tCourt & "," & item 2 of tCourt, item 1 of tCourt & "," & item 4 of tCourt
   -- What the two numbers are
   put lkLabel("Key1", lkR(item 3 of tCourt - 380, item 2 of tCourt + 14, item 3 of tCourt - 18, item 2 of tCourt + 30), \
         "the first number: across, + is to the right", 11, "253,186,116", empty, "right") into tObj
   put lkLabel("Key2", lkR(item 3 of tCourt - 380, item 2 of tCourt + 32, item 3 of tCourt - 18, item 2 of tCourt + 48), \
         "the second number: down, + is down and - is up", 11, "103,232,249", empty, "right") into tObj
   -- The ball, thrown from the bottom left with a vector of 9,-15, step by
   -- step as bounceBall moves it (gravity 1, friction 0.01, a bounce 2):
   -- a dot at each step, and the ball where it is thrown, at the top and
   -- at the floor, with its vector
   put 26 into tSize
   put item 4 of tCourt - 4 into tFloor
   put item 1 of tCourt + 34 into tX
   put tFloor - tSize into tY
   put 9 into tVx
   put -15 into tVy
   put "0,15,31,72" into tTagged
   repeat with tStep = 0 to 72
      put round(tX) + tSize div 2 into tCx
      put round(tY) + tSize div 2 into tCy
      if tStep is among the items of tTagged then
         -- (drawn after the dots, over them)
         put (tCx, tCy, tVx, tVy) into tShown[tStep]
      else
         -- (a dot where the ball is at each step: far apart where it is
         -- fast, close together where it is slow)
         get lkOval("Step" & tStep, lkR(tCx - 3, tCy - 3, tCx + 3, tCy + 3), "255,255,255", empty)
         set the blendLevel of it to 35
      end if
      -- the next step, as bounceBall takes it: down (y), then across (x)
      add tVy to tY
      if tY + tSize > tFloor then
         put tFloor - tSize into tY
         put min(0, -1 * tVy + 2) into tVy
      else
         add 1 to tVy
      end if
      add tVx to tX
      subtract 0.01 from tVx
   end repeat
   repeat for each item tStep in tTagged
      put item 1 of tShown[tStep] into tCx
      put item 2 of tShown[tStep] into tCy
      put item 3 of tShown[tStep] into tVx
      put item 4 of tShown[tStep] into tVy
      get ball("Shown" & tStep, tCx - tSize div 2, tCy - tSize div 2, tSize, 2, empty)
      lkShadow it, 10, 3, 35
      if tStep is 72 then
         next repeat
      end if
      if tVy is 0 then
         put "the top:" && vectorText(tVx, tVy) into tTag
         get drawLine("Arrow" & tStep, tCx & "," & tCy & return & round(tCx + 3 * tVx) & "," & tCy, "255,255,255", 2, true, empty, empty)
         get vectorTag("Tag" & tStep, tCx, tCy - 48, tTag, "center")
      else if tVy < 0 then
         put "thrown:" && vectorText(tVx, tVy) into tTag
         get drawLine("Arrow" & tStep, tCx & "," & tCy & return & round(tCx + 3 * tVx) & "," & round(tCy + 3 * tVy), "255,255,255", 2, true, empty, empty)
         get vectorTag("Tag" & tStep, tCx + 22, tCy, tTag, "left")
      else
         -- (at the floor: the vector it comes down with, and the one the
         -- next step gives it)
         put "the floor:" && vectorText(tVx, tVy) && numToCodepoint(8594) && vectorText(tVx - 0.01, -1 * tVy + 2) into tTag
         get drawLine("Arrow" & tStep, tCx & "," & tCy & return & round(tCx + 3 * tVx) & "," & round(tCy + 3 * (-1 * tVy + 2)), "255,255,255", 2, true, empty, empty)
         get vectorTag("Tag" & tStep, tCx + 30, tCy, tTag, "left")
      end if
   end repeat
   -- The words
   get exPanel("Words", lkR(kLeft, 372, 556, kBottom), empty)
   get heading("WordsTitle", kLeft + 20, 390, 540, "Two numbers a step", 16, empty)
   put textBlock("Words1", kLeft + 20, 424, 536, \
         "A ball's motion is its vector: how far it moves across and down in one step of the loop. " & \
         "9,-15 is 9 to the right and 15 up." & return & \
         "Each step, gravity adds 1 to the second number and friction takes 0.01 off the first. " & \
         "At the floor the ball turns back, 2 slower: 16 down becomes 14 up.", 13, lkColor("soft"), empty) into tBottom
   get codeBox("FallCode", lkR(572, 372, kRight, kBottom), "bounceBall, in the Bounce Behavior: up and down", \
         "put the top of me + item 2 of sVector into tTop" & return & \
         "if tTop < sTop then  -- the top edge" & return & \
         "   ..." & return & \
         "else if sHeight + tTop > sBottom then  -- the floor" & return & \
         "   put sBottom - sHeight into tTop" & return & \
         "   put min(0, -1 * item 2 of sVector \" & return & \
         "         + kBounceEffect) into item 2 sVector" & return & \
         "else  -- in the air" & return & \
         "   add kGravityEffect to item 2 of sVector" & return & \
         "end if")
end buildVectors

-- A vector as the page shows it: to two places at most
private function vectorText pX, pY
   return (round(pX * 100) / 100) & "," & (round(pY * 100) / 100)
end vectorText

-- A tag on the court: words on a pill, beside (pAlign "left": starting
-- at pX) or over (centred on pX) a point, its middle at pY
private function vectorTag pName, pX, pY, pText, pAlign
   local tLabel, tWidth, tLeft, tObj
   put lkLabel(pName & "_label", lkR(0, pY - 8, 400, pY + 8), pText, 11, "255,255,255", empty, "center") into tLabel
   set the textStyle of tLabel to "bold"
   set the dontWrap of tLabel to true
   -- (as wide as the words would be in a font kFontRoom narrower, and
   -- the words in the middle: in the IDE's wider font they still fit)
   put round(the formattedWidth of tLabel / kFontRoom) + 16 into tWidth
   if pAlign is "center" then
      put pX - tWidth div 2 into tLeft
   else
      put pX into tLeft
   end if
   set the width of tLabel to tWidth - 8
   set the left of tLabel to tLeft + 4
   put lkBox(pName, lkR(tLeft, pY - 12, tLeft + tWidth, pY + 12), "255,255,255", 12, empty) into tObj
   set the blendLevel of tObj to 84
   relayer tObj before tLabel
   return tObj
end vectorTag

-- The loop: a time line of five steps, one of them slow, and the code
-- that moves the balls and sends the next step
private command buildLoop
   local tObj, tBottom, tAxis, tX0, tScale, tSteps, tStep, tStart, tWork, tNext, tLabel, tIndex, tX, tX1, tColor, tMid
   go card "Loop"
   get exPanel("Picture", lkR(kLeft, kTop, kRight, 344), empty)
   get heading("PictureTitle", kLeft + 22, kTop + 18, 900, "A step every 25 milliseconds", 15, empty)
   put lkLabel("PictureText", lkR(kLeft + 22, kTop + 44, 980, kTop + 60), \
         "A bar is a step at work, an arrow its wait for the next, and a tick the time a step is due.", 12, lkColor("soft"), empty) into tObj
   -- The time line: 0 to 150 milliseconds
   put 300 into tX0
   put 4.3 into tScale
   put 296 into tAxis
   get drawLine("Axis", tX0 & "," & tAxis & return & (tX0 + round(150 * tScale)) & "," & tAxis, lkColor("muted"), 2, false, empty, empty)
   repeat with tIndex = 0 to 6
      put tX0 + round(tIndex * 25 * tScale) into tX
      if tIndex is 3 then
         put lkColor("rose") into tColor
      else
         put lkColor("muted") into tColor
      end if
      get drawLine("Tick" & tIndex, tX & "," & (tAxis - 6) & return & tX & "," & (tAxis + 6), tColor, 2, false, empty, empty)
      put lkLabel("TickLabel" & tIndex, lkR(tX - 30, tAxis + 12, tX + 30, tAxis + 28), (tIndex * 25) & " ms", 11, tColor, empty, "center") into tObj
   end repeat
   put tX0 + round(75 * tScale) into tX
   put lkLabel("Missed", lkR(tX - 80, tAxis + 28, tX + 80, tAxis + 44), "missed: moved at 105", 11, lkColor("rose"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   -- The steps: when each starts, how long it works, the wait it sends,
   -- and what it says
   put "0,6,19,waits 19|25,5,20,waits 20|50,55,0,30 late: the next comes at once|105,6,14,moves twice and waits 14|125,6,19,waits 19" into tSteps
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 5
      put item tIndex of tSteps into tStep
      set the itemDelimiter to comma
      put item 1 of tStep into tStart
      put item 2 of tStep into tWork
      put item 3 of tStep into tNext
      put item 4 of tStep into tLabel
      if tWork > 25 then
         put lkColor("rose") into tColor
      else
         put lkColor("orange") into tColor
      end if
      put tX0 + round(tStart * tScale) into tX1
      put tX0 + round((tStart + tWork) * tScale) into tX
      put lkBox("Step" & tIndex, lkR(tX1, tAxis - 44, tX, tAxis - 20), tColor, 6, empty) into tObj
      lkShadow tObj, 8, 2, 25
      if tWork > 25 then
         put lkLabel("SlowLabel", lkR(tX1, tAxis - 36, tX, tAxis - 20), tWork & " ms of work", 11, "255,255,255", empty, "center") into tObj
         set the textStyle of tObj to "bold"
      end if
      if tIndex is 4 then
         -- (the step after the slow one moves the balls twice: two bars)
         put lkBox("Step4b", lkR(tX1, tAxis - 72, tX, tAxis - 48), lkColor("pink"), 6, empty) into tObj
         lkShadow tObj, 8, 2, 25
      end if
      if tNext > 0 then
         get drawLine("Wait" & tIndex, (tX + 4) & "," & (tAxis - 32) & return & (tX + round(tNext * tScale) - 4) & "," & (tAxis - 32), \
               lkColor("muted"), 2, true, "3,4", empty)
      end if
      put (tX1 + tX + round(tNext * tScale)) div 2 into tMid
      put lkLabel("StepLabel" & tIndex, lkR(tMid - 90, tAxis - 100, tMid + 90, tAxis - 84), tLabel, 11, lkColor("soft"), empty, "center") into tObj
      if tWork > 25 then
         set the textColor of tObj to lkColor("rose")
         set the textStyle of tObj to "bold"
      end if
      set the itemDelimiter to "|"
   end repeat
   set the itemDelimiter to comma
   -- The words
   get exPanel("Words", lkR(kLeft, 360, 576, kBottom), empty)
   get heading("WordsTitle", kLeft + 20, 378, 560, "One loop for every ball", 16, empty)
   put textBlock("Words1", kLeft + 20, 410, 556, \
         "bounceBalls makes the balls that clicks and Create Balls asked for, sends bounceBall to " & \
         "every ball, and sends itself again. It works between lock screen and unlock screen, so " & \
         "the window is drawn once a step, not once a ball." & return & \
         "It keeps time: a step that took 6 milliseconds waits 19. After a slow step it moves the " & \
         "balls twice, so that they keep their speed. It stops when you leave the card.", \
         13, lkColor("soft"), empty) into tBottom
   get codeBox("LoopCode", lkR(592, 360, kRight, kBottom), "bounceBalls, in the script of the card " & quote & "Main" & quote, \
         "lock screen" & return & \
         "repeat tReps times" & return & \
         "   repeat for each item tObject in sObjects" & return & \
         "      send " & quote & "bounceBall" & quote & " to tObject" & return & \
         "   end repeat" & return & \
         "end repeat" & return & \
         "unlock screen" & return & \
         "get kBouncePollRate - (the milliseconds \" & return & \
         "      - tStartTime) - pTimeMissed" & return & \
         "send " & quote & "bounceBalls" & quote & " && max(0, it * -1) \" & return & \
         "      to me in max(0, it) milliseconds")
end buildLoop

-- Rendering: the stage in tiles, those that balls have moved over drawn
-- again and the rest kept; the words, and the code that turns it on
private command buildRender
   local tObj, tBottom, tSize, tL, tT, tCol, tRow, tRect, tBalls, tBall, tIndex, tHit, tR, tCourt, tOld, tNew
   local tX, tY, tDx, tDy, tLength, tReach
   go card "Render"
   get exPanel("Picture", lkR(kLeft, kTop, 620, 392), empty)
   get heading("PictureTitle", kLeft + 22, kTop + 18, 600, "The stage, in tiles", 15, empty)
   -- The court, 7 tiles across and 4 down
   put 46 into tSize
   put 277 into tL
   put 154 into tT
   put lkR(tL - 5, tT - 5, tL + 7 * tSize + 5, tT + 4 * tSize + 5) into tCourt
   put lkBox("Court", tCourt, lkColor("side"), 12, empty) into tObj
   lkGradient tObj, "30,41,59|20,24,54|15,23,42", item 1 of tCourt & "," & item 2 of tCourt, item 1 of tCourt & "," & item 4 of tCourt
   -- Three balls, each where it was and where it is now (a line each:
   -- the rect it was in, the rect it is in)
   put "292,162,326,196,330,190,364,224" & return & "420,270,460,310,462,252,502,292" & return & \
         "548,200,576,228,524,236,552,264" into tBalls
   repeat with tRow = 0 to 3
      repeat with tCol = 0 to 6
         put lkR(tL + tCol * tSize + 2, tT + tRow * tSize + 2, tL + (tCol + 1) * tSize - 2, tT + (tRow + 1) * tSize - 2) into tRect
         put false into tHit
         repeat for each line tBall in tBalls
            if overlaps(tRect, item 1 to 4 of tBall) or overlaps(tRect, item 5 to 8 of tBall) then
               put true into tHit
            end if
         end repeat
         put lkBox("Tile" & tRow & tCol, tRect, "51,65,85", 6, empty) into tObj
         if tHit then
            set the backgroundColor of tObj to lkMix("15,23,42", lkColor("orange"), 0.42)
            lkBorder tObj, lkColor("orange")
         else
            set the blendLevel of tObj to 55
         end if
      end repeat
   end repeat
   put 0 into tIndex
   repeat for each line tBall in tBalls
      add 1 to tIndex
      put item 1 to 4 of tBall into tOld
      put item 5 to 8 of tBall into tNew
      get ball("Was" & tIndex, item 1 of tOld, item 2 of tOld, item 3 of tOld - item 1 of tOld, tIndex * 3, empty)
      set the blendLevel of it to 60
      set the lineSize of it to 0
      -- (an arrow from where it was to the edge of where it is)
      put (item 1 of tOld + item 3 of tOld) / 2 into tX
      put (item 2 of tOld + item 4 of tOld) / 2 into tY
      put (item 1 of tNew + item 3 of tNew) / 2 - tX into tDx
      put (item 2 of tNew + item 4 of tNew) / 2 - tY into tDy
      put sqrt(tDx * tDx + tDy * tDy) into tLength
      put 1 - ((item 3 of tNew - item 1 of tNew) / 2 + 3) / tLength into tReach
      get drawLine("Move" & tIndex, round(tX) & "," & round(tY) & return & round(tX + tDx * tReach) & "," & round(tY + tDy * tReach), \
            "255,255,255", 2, true, "3,3", empty)
      set the blendLevel of it to 20
      get ball("Is" & tIndex, item 1 of tNew, item 2 of tNew, item 3 of tNew - item 1 of tNew, tIndex * 3, empty)
      lkShadow it, 8, 2, 35
   end repeat
   -- What the colours mean
   put item 4 of tCourt + 16 into tR
   get lkBox("KeyNew", lkR(tL, tR, tL + 14, tR + 14), lkMix("15,23,42", lkColor("orange"), 0.42), 4, empty)
   lkBorder it, lkColor("orange")
   put lkLabel("KeyNewLabel", lkR(tL + 22, tR, tL + 170, tR + 16), "drawn again this step", 12, lkColor("soft"), empty) into tObj
   get lkBox("KeyOld", lkR(tL + 176, tR, tL + 190, tR + 14), "51,65,85", 4, empty)
   put lkLabel("KeyOldLabel", lkR(tL + 198, tR, tL + 330, tR + 16), "kept as it was", 12, lkColor("soft"), empty) into tObj
   -- The words
   get exPanel("Words", lkR(636, kTop, kRight, 392), empty)
   get heading("WordsTitle", 658, kTop + 20, 984, "Draw only what moves", 16, empty)
   put textBlock("Words1", 658, kTop + 54, 980, \
         "With accelerated rendering on, the window keeps its picture of the card in tiles. Each step, " & \
         "it draws again only the tiles that a ball has left or entered, and keeps the rest." & return & \
         "That is why createBall sets each ball's layerMode to dynamic: it tells the window that the " & \
         "ball moves, so that it is drawn on its own, over the tiles.", \
         13, lkColor("soft"), empty) into tBottom
   tipBox "Tip", lkR(650, 320, 986, 376), "The switch on the Bounce card turns it on and off: " & \
         "try both ways with a hundred balls."
   get codeBox("RenderCode", lkR(kLeft, 408, kRight, kBottom), "accelerated rendering, on and off", \
         "-- in the script of the stack: the switch on the Bounce card calls it" & return & \
         "on graphicsToggle" & return & \
         "   set the acceleratedrendering of me to \" & return & \
         "         the hilited of button " & quote & "toggleGraphics" & quote & " of card " & quote & "Main" & quote & " of me" & return & \
         "end graphicsToggle" & return & \
         return & \
         "-- in createBall, in the script of the card " & quote & "Main" & quote & return & \
         "set the layerMode of it to " & quote & "dynamic" & quote)
end buildRender

-- Whether two rects overlap
private function overlaps pA, pB
   return item 1 of pA < item 3 of pB and item 1 of pB < item 3 of pA and \
         item 2 of pA < item 4 of pB and item 2 of pB < item 4 of pA
end overlaps

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Bouncing Balls: LiveCode Ltd's Balls ("Bouncing balls"), remastered for OXT-Beyond in 2026
--Balls 1.0.0.0, LiveCode Ltd (then RunRev Ltd), 2011: the first sample of LiveCode Community's Start Center,
--free software under the GNU General Public License, version 3

--The program is on the card "Main": the script of the card is the main loop, and the script of the
--button "bounce" (Bounce Behavior) is every ball's behavior. The sidebar, the header and the drawer of
--scripts are the groups "Frame", "Workbench" and "Scripts", which the script of the group "Frame" runs.

on preOpenStack
   ## Turn on acceleratedRendering
   ## (remaster) The checkbox is on the card "Main", and is a switch: it shows that it is on
   set the hilited of button "toggleGraphics" of card "Main" of me to true
   dispatch "showSwitch" to button "toggleGraphics" of card "Main" of me
   graphicsToggle
   set the randomSeed to 109871234
   if the environment is "mobile" then
      ## (remaster) The original hid group 1, its Simulate Shake and Bounce Behavior buttons: a phone
      ## shakes for real. Group 1 is the window's sidebar now, so the button is named
      set the visible of group "Simulate Shake" of card "Main" of me to false
      mobileSetAllowedOrientations "portrait,portrait upside down,landscape left,landscape right"
   end if
   if the platform is "iphone" then
      iphoneUseDeviceResolution true
   end if
   codeFont
end preOpenStack

## (remaster) The code on the pages is in Source Code Pro, which the IDE has. Where the fontNames
## have not got it (the web IDE, and Linux, which leaves out a font loaded from a file), it is in the
## first monospaced font there is, as the scripts in the drawer are
command codeFont
   local tError, tFont, tCard, tField
   if the environment is "development" then
      ## The IDE keeps Source Code Pro for its Script Editor, and Droid Sans Mono for its Dictionary
      try
         if "Source Code Pro" is not among the lines of the fontNames then
            start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
         end if
      catch tError
      end try
      try
         if "Source Code Pro" is not among the lines of the fontNames and \
               "Droid Sans Mono" is not among the lines of the fontNames then
            start using font file (revIDESpecialFolderPath("IDE") & "/Documentation/html_viewer/resources/data/api/DroidSansMono.ttf")
         end if
      catch tError
      end try
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then
         repeat with tCard = 1 to the number of cards of me
            repeat with tField = 1 to the number of fields of card tCard of me
               if the cCode of field tField of card tCard of me is true and \
                     the textFont of field tField of card tCard of me is not tFont then
                  set the textFont of field tField of card tCard of me to tFont
               end if
            end repeat
         end repeat
         exit repeat
      end if
   end repeat
end codeFont

## Toggle between the compositor being on or off.
## This is the important part of the new accelerated graphics.  Using the compositor
## will mean that the stack's background is split up into tiles and cached.
## The "dynamic" balls will bounce around the screen, obscuring tiles.  Only the
## obscured tiles will be redrawn.  When the ball leaves a tile, the cached
## tile will be redrawn again, but this time using the cached information.

## On MacOS we use the CoreGraphics compositor, on iOS the OpenGL compositor.
## On all other platforms we use the software compositor.

## Play around the compositor settings to see how they effect performance
## on your platform.
on graphicsToggle
   set the acceleratedrendering of me to the hilited of button "toggleGraphics" of card "Main" of me
end graphicsToggle
@*/

/*@ Main/card
############################################
## Constants
############################################

## How often in milliseconds the location of the balls are updated
constant kBouncePollRate = 25

############################################
## Variables
############################################
## List of the balls (comma separated list of control ids)
local sObjects

## How many balls will be created in the next loop
local sCreateCount

## Whether existing balls should be cleared in the next loop
local sClearBalls

## (remaster) The next step of the main loop, waiting to be sent: closeCard cancels it
local sLoop

############################################
## Main loop
############################################
/* All the calculations, creating and moving of the balls takes place in this loop.  Using a single loop
like this means we can manage all redraws within a single screen update rather than a screen update for
each ball that moves and each ball we want to create.

Note the use of lock screen.  Though we are potentially moving and creating several balls within this loop,
since it is all performed while the screen is locked, only one redraw will be made.

Our loop will be called every kBouncePollRate milliseconds.  We make sure this is consistent by taking into
account the time the loop takes to execute.  Say for example we want to redraw every 25 milliseconds
and the loop itself takes 5 milliseconds, we must then perform the next redraw in 20 milliseconds.  This
is worked out dynamically by calculating the time each loop takes to execute and adjusting the send time accordingly.

If the loop takes greater than the poll rate to run, we call the next loop instantly, telling it how much longer
it took.  This overrun time is taken into account when sending the next loop.  For example, if the previous
loop overran by 5 milliseconds, we must dispatch the next loop 5 milliseconds earlier than we would normally do.

If the overrun is greater than the poll rate, then we must perform multiple repetitions.  For example, if the previous
loop overran by 30 milliseconds, we know that we have missed out a redraw entirely.   To accommodate this, we must perform
 two repetitions of the main loop.  That is, we move the balls two frames, but only redraw once, effectively dropping
 a frame.  This keeps the speed of the balls consistent, even if the hardware can't keep up. *\/

on openCard
   ## Cause the main loop to be started when the card is opened
   clearBalls
   send "bounceBalls 0" to me in 0 seconds
   put the result into sLoop  --(remaster) so that closeCard can stop it

   ## For demonstration create and agitate balls
   send "newBalls 20" to me in 0 seconds
   send "shakeBalls" to me in 200 milliseconds
end openCard

## (remaster) The main loop stops when the card closes, and the balls go: the stack has other
## cards now, and the original's loop ran for as long as the stack was open
on closeCard
   local tObject
   if sLoop is not empty then
      cancel sLoop
      put empty into sLoop
   end if
   lock screen
   repeat for each item tObject in sObjects
      if exists(tObject) then
         delete tObject
      end if
   end repeat
   put empty into sObjects
   put 0 into sCreateCount
   put false into sClearBalls
   showCount
   unlock screen
end closeCard

on bounceBalls pTimeMissed
   ## Log the start time of this loop (so we can calculate how long it takes).
   ## If the previous loop overran by more than the poll rate, we need to perform
   ## extra reps in this loop.  Calculate how many (how many frames have been missed).

   local tStartTime, tReps, tObject, tStack
   put the milliseconds into tStartTime
   if pTimeMissed > kBouncePollRate then
      ## (remaster) The frames missed, and this one: the original moved the balls
      ## pTimeMissed div kBouncePollRate times, one too few for the two reps above
      put 1 + pTimeMissed div kBouncePollRate into tReps
      subtract (tReps - 1) * kBouncePollRate from pTimeMissed
   else
      put 1 into tReps
   end if

   ## (remaster) A message sent in time runs in whatever stack is the defaultStack then, the
   ## Script Editor's if you are editing a script: this loop makes balls in its own stack, and
   ## puts the defaultStack back when it is done
   put the defaultStack into tStack
   set the defaultStack to the short name of the owner of me

   ## Create any new balls required and then move all the active balls.  If we missed frames
   ## then make sure we move the balls the required number of extra times to accommodate
   ## the missed frames.
   lock screen
   if sClearBalls then
      repeat for each item tObject in sObjects
         delete tObject
      end repeat
      put empty into sObjects
      put false into sClearBalls
      showCount
   else
      repeat while sCreateCount > 0
         createBall
         subtract 1 from sCreateCount
      end repeat
      repeat tReps times
         repeat for each item tObject in sObjects
            send "bounceBall" to tObject
         end repeat
      end repeat
   end if
   ## (remaster) The drawer of scripts, when it is open, stays in front of the balls
   if the visible of group "Scripts" then
      relayer group "Scripts" to front of this card
   end if
   unlock screen
   if tStack is not empty and there is a stack tStack then
      set the defaultStack to tStack
   end if

   ## Work out how long this loop took and based on this value, call the next loop.
   ## If this loop overran, make sure to tell the next loop.

   get kBouncePollRate - (the milliseconds - tStartTime) - pTimeMissed
   send "bounceBalls" && max(0, it * -1) to me in max(0, it) milliseconds
   put the result into sLoop  --(remaster) so that closeCard can stop the loop
end bounceBalls

############################################
## Ball create/edit/delete handlers
############################################
/*Create a new circle of a random size and set its behavior.  The code in button
bounce defines the behavior of the ball, from how it interacts with the user (dragging) to
how it is to bounce around the screen.

The important point to note here is the setting of the layerMode of the new graphic to "dynamic".
This tells the compositor that the location of this control will be changing regularly and to
adjust its caching routines accordingly.*\/

on createBall
   local tSize, tColors
   put max(10, random(100)) into tSize

   create graphic
   set the behavior of it to the long id of button "bounce"
   set the layerMode of it to "dynamic"
   set the loc of it to the mouseloc
   ## (remaster) A ball made while the pointer is off the stage starts in the middle of it
   if the mouseloc is not within the rect of graphic "Court" then
      set the loc of it to the loc of graphic "Court"
   end if
   set the width of it to tSize
   set the height of it to tSize
   set the style of it to "oval"
   set the opaque of it to true
   set the linesize of it to 2
   ## (remaster) A bright colour, lit from the top left so that the ball looks round, and a rim of
   ## its own dark. The original took any colour: set the backgroundColor of it to any word of the colorNames
   put any line of the cPalette of me into tColors  --light|colour|dark, a custom property of this card
   set the itemDelimiter to "|"
   set the backgroundColor of it to item 2 of tColors
   set the foregroundColor of it to item 3 of tColors
   set the fillGradient["type"] of it to "radial"
   set the fillGradient["ramp"] of it to "0.00," & item 1 of tColors & return & "0.50," & item 2 of tColors & return & "1.00," & item 3 of tColors
   set the itemDelimiter to comma
   set the fillGradient["from"] of it to (the left of it + tSize div 3, the top of it + tSize div 3)
   set the fillGradient["to"] of it to (the right of it + tSize div 6, the top of it + tSize div 3)
   set the fillGradient["via"] of it to (the left of it + tSize div 3, the bottom of it + tSize div 6)
   send "init" to it
   if sObjects is not empty then
      put comma after sObjects
   end if
   put it after sObjects
   showCount
end createBall

## Simulate a shake.  Here, we just tell the balls to move in a random direction.
## The actual movement of the balls will be taken care of in the main loop.

on shakeBalls
   local tObject
   repeat for each item tObject in sObjects
      set the uVector of tObject to (35 - random(70), 35 - random(70))
   end repeat
end shakeBalls

## Remove all the balls.  Like creating new balls, we just set a flag so that
## the clear happens in the next main loop.

on clearBalls
   put true into sClearBalls
end clearBalls

on newBalls pCount
   add pCount to sCreateCount
end newBalls

## (remaster) How many balls there are, in the header
on showCount
   put the number of items of sObjects into field "Count"
end showCount

############################################
## User interaction handlers
############################################

## When the user clicks (or touches), create a new ball.  Rather than create the ball directly here, we increment
## the count and create the ball in the main loop.
## (remaster) Only a click on the stage makes a ball: the sidebar, the header and the drawer of scripts
## are on this card too. The click goes on to the window, which shows the script of what was clicked

on mouseDown
   if the mouseloc is within the rect of graphic "Court" and not (the visible of group "Scripts" and the mouseloc is within the rect of group "Scripts") then
      add 1 to sCreateCount
   end if
   pass mouseDown
end mouseDown

on motionStart
   shakeBalls
end motionStart
@*/

/*@ Main/bounce
############################################
## Constants
############################################

constant kGravityEffect  = 1      -- how many units the ball's y vector component will gain per frame because of gravity
constant kBounceEffect   = 2      -- how many units the ball's vector will lose if it hits the edge of the stage
constant kFrictionEffect = 0.01   -- how many units the ball's x vector component will lose per frame because of friction

############################################
## Variables
############################################

local sVector               -- vector defining the ball's current motion
local sDragging             -- if we are currently dragging the ball
local sLastDragLoc          -- the last location of the ball by way of a drag
local sCurrentDragLoc       -- the next location of the ball by way of a drag

############################################
## Properties
############################################

## Get and set the ball's vector.

## The ball's vector defines the x and y components of its motion.  For example
## a vector of -5,10 means that in a frame it will move 5 pixels left and 10
## pixels down.

getProp uVector
   return sVector
end uVector

setProp uVector pX, pY
   put (pX,pY) into sVector
end uVector

local sWidth, sHeight
## (remaster) The edges the ball bounces off: the court's, the dark part of the stage. The original's
## were the card's: local sCardWidth, sCardHeight, with 0 for its top and left
local sLeft, sTop, sRight, sBottom

on init
   put the width of me into sWidth
   put the height of me into sHeight
   put the left of graphic "Court" into sLeft
   put the top of graphic "Court" into sTop
   put the right of graphic "Court" into sRight
   put the bottom of graphic "Court" into sBottom
end init

############################################
## Main bounce routine
############################################

on bounceBall
   ## If the user is dragging the ball, move the ball to the location of the user's
   ## mouse (or finger) and don't perform any bounce calculations.

   if sDragging and sCurrentDragLoc is not empty then
      set the loc of me to sCurrentDragLoc
      exit bounceBall
   end if

   ## Work out the ball's next y location.  Add the y component of the vector to
   ## the ball's y location (we use the top).  If the ball is touching the top or
   ## the bottom of the stage, reverse the direction of the ball (multiply the
   ## y component of the vector by -1) and remove kBounceEffect units.

   ## If it is mid air, just add the effects of gravity.

   local tTop
   put the top of me + item 2 of sVector into tTop
   if tTop < sTop then
      put sTop into tTop
      put max(0, -1 * item 2 of sVector  - kBounceEffect) into item 2 sVector
   else if sHeight + tTop > sBottom then
      put sBottom - sHeight into tTop
      put min(0, -1 * item 2 of  sVector + kBounceEffect) into item 2 sVector
   else
      add kGravityEffect to item 2 of sVector
   end if

   ## Do the same for the x location (we use the left), checking to see if the
   ## ball is touching the sides.  This time, instead of gravity, we take into account
   ## friction.  Unlike gravity, friction isn't in a constant direction.  Instead,
   ## it applies in the opposite direction the ball is travelling.

   local tLeft
   put the left of me + item 1 of sVector into tLeft
   if tLeft < sLeft then
      put sLeft into tLeft
      put max(0, -1 * item 1 of sVector  - kBounceEffect) into item 1 sVector
   else if tLeft + sWidth > sRight then
      put sRight  - sWidth into tLeft
      put min(0, -1 * item 1 of sVector  + kBounceEffect) into item 1 sVector
   else
      if item 1 of sVector > 0 then
         subtract kFrictionEffect from item 1 of sVector
      else if item 1 of sVector < 0 then
         add kFrictionEffect to item 1 of sVector
      end if
   end if

   ## We now know the ball's new location.
   set the topLeft of me to (tLeft,tTop)
end bounceBall

############################################
## Drag handling
############################################

## The user has clicked, flag that we are dragging, stopping all bounce
## activity in the main loop.
on mouseDown
   put empty into sCurrentDragLoc
   put empty into sLastDragLoc
   put true into sDragging
   set the layer of me to top
end mouseDown

## The user want to move the ball, so store its new location, to be updated in
## the main bounce loop.

## Updating the ball's location in the main bounce loop means that all redraws
## are carried out in the single location (within a lock screen).

on mouseMove pX, pY
   if sDragging and (pX,pY) is not sCurrentDragLoc then
      ## (remaster) The pointer may go past the stage: the ball stops at its edges
      put max(sLeft + sWidth div 2, min(sRight - sWidth + sWidth div 2, pX)) into pX
      put max(sTop + sHeight div 2, min(sBottom - sHeight + sHeight div 2, pY)) into pY
      put sCurrentDragLoc into sLastDragLoc
      put (pX,pY) into sCurrentDragLoc
   end if
end mouseMove

## The user has released.  Launch the ball based on the amount the ball last moved.
## Do this by setting the x and y components of the ball's vector based on how much the user
## has moved the ball in the x and y directions.

## Not very smart.  Should really use a time based system.
on mouseUp
   ## (remaster) After a single move, the last place is the place it started from: the
   ## original threw the ball as far as the pointer was from the card's top left
   if sLastDragLoc is empty then
      put sCurrentDragLoc into sLastDragLoc
   end if
   put (item 1 of sCurrentDragLoc - item 1 of sLastDragLoc, item 2 of sCurrentDragLoc - item 2 of sLastDragLoc) into sVector
   put false into sDragging
end mouseUp

on mouseRelease
   mouseUp
end mouseRelease

############################################
## Drag handling for mobile (including multitouch)
############################################

## Just map touch events to their matching mouse events.  This allows for multi-touch
## handling, allowing the users to drag and throw more than one ball.
on touchStart
   mouseDown
end touchStart

on touchMove pID, pX, pY
   mouseMove pX, pY
end touchMove

on touchEnd
   mouseUp
end touchEnd

on touchRelease
   mouseUp
end touchRelease
@*/

/*@ Main/Create Balls
on mouseUp
   ask "How Many Balls?" with 10  --(remaster) with a number to start from
   if it is a number then
      newBalls it
      ## (remaster) New balls start in one place and would fall as one: a shake, as when the card opens,
      ## sends them their own ways
      send "shakeBalls" to this card in 200 milliseconds
   end if
end mouseUp

on mouseDown

end mouseDown
@*/

/*@ Main/Clear Balls
on mouseUp
   clearBalls
end mouseUp

on mouseDown

end mouseDown
@*/

/*@ Main/Simulate Shake
on mouseUp
   shakeBalls
end mouseUp

on mouseDown

end mouseDown
@*/

/*@ Main/toggleGraphics
## (remaster) The original's checkbox had no script, so a click on it changed nothing. It is a
## switch now: a click turns it, and the stack script's graphicsToggle turns accelerated rendering
## on or off to match
on mouseUp
   set the hilite of me to not the hilite of me
   showSwitch
   graphicsToggle
end mouseUp

## The switch shows the button's hilite: on, its knob is at the right and its track is orange
on showSwitch
   if the hilite of me then
      set the backgroundColor of graphic "SwitchTrack" of the owner of me to the cOn of me
      set the right of graphic "SwitchKnob" of the owner of me to the right of graphic "SwitchTrack" of the owner of me - 2
   else
      set the backgroundColor of graphic "SwitchTrack" of the owner of me to the cOff of me
      set the left of graphic "SwitchKnob" of the owner of me to the left of graphic "SwitchTrack" of the owner of me + 2
   end if
end showSwitch
@*/
