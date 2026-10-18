script "OXTExampleBalloonGame"
-- OXT-Beyond: builds "Balloon Game", the remaster of LiveCode Ltd's
-- balloon ("Balloon Adventure", 2013), the fourth sample of LiveCode
-- Community's Start Center, which is in
-- ide/Resources/Start Center/samples/sample_4/balloon.livecode and stays
-- there as its authors made it. LiveCode Community, and so the sample, is
-- free software under the GNU General Public License, version 3.
--
-- The sample is a little game in five cards, read like the pages of a
-- book: you give your name, take off along a path, collect points with
-- the arrow keys and fly past the birds to the end. A sixth card keeps the
-- pictures of its buttons. Its scripts teach as they go, in their
-- comments: the move command, arrowKey, a loop of send in time, intersect
-- and a sound. The remaster keeps those cards and their scripts, in the
-- window every remastered example has (builder.livecodescript): each
-- card's game is on the stage of a wide card, whose drawer shows its
-- scripts, and three pages show how the moving, the loop and the
-- collisions work. The original's pictures and its sound are copied from
-- it when this runs, the pictures at 744/1024 of their size: its cards
-- were 1024 by 768, and the stage is 744 across. What changed in the
-- scripts is where things go (a place on the original's card is a place
-- on the stage, by stageLoc in the stack script), what the window needs
-- (a card's preOpenCard passes the message on, and nothing goes on
-- moving when you leave its card), and a few of the original's mistakes,
-- each mended with a comment.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- The original's cards were 1024 by 768: on the stage, 744 across, its
-- pictures and its places are 744/1024 of their size
constant kScale = 0.7265625
-- The pictures on the pages: the stage at 332 across, and smaller still
constant kThumb = 0.32421875
constant kTiny = 0.11
-- A stack of our own, where the original's sound waits for the new stack
-- and its pictures are made smaller
constant kScratch = "OXTBalloonGameScratch"
-- The arrow buttons, and their rects on the original's card
constant kArrows = "up,838,580,928,664|right,910,619,999,708|down,842,681,926,761|left,766,628,851,712"
-- The words are measured here, but the IDE's font is wider than the
-- build's, by as much as a tenth (measured at 13 points): words get room
-- for a font this much narrower (fixLines, pill)
constant kFontRoom = 0.88

-- The original's pictures (PNG), by name, as the stack shows them
local sPicture
-- The points of the original's path, on its card
local sPath

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   exAddIcon "user", "<path d='M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/>"
   exAddIcon "route", "<circle cx='6' cy='19' r='3'/><path d='M9 19h8.5a3.5 3.5 0 0 0 0-7h-11a3.5 3.5 0 0 1 0-7H15'/>" & \
         "<circle cx='18' cy='5' r='3'/>"
   exAddIcon "coins", "<circle cx='8' cy='8' r='6'/><path d='M18.09 10.37A6 6 0 1 1 10.34 18'/><path d='M7 6h1v4'/>" & \
         "<path d='m16.71 13.88.7.71-2.82 2.82'/>"
   exAddIcon "bird", "<path d='M16 7h.01'/><path d='M3.4 18H12a8 8 0 0 0 8-8V7a4 4 0 0 0-7.28-2.3L2 20'/>" & \
         "<path d='m20 7 2 .5-2 .5'/><path d='M10 18v3'/><path d='M14 17.75V21'/><path d='M7 18a6 6 0 0 0 3.84-10.61'/>"
   exAddIcon "party-popper", "<path d='M5.8 11.3 2 22l10.7-3.79'/><path d='M4 3h.01'/><path d='M22 8h.01'/>" & \
         "<path d='M15 2h.01'/><path d='M22 20h.01'/>" & \
         "<path d='m22 2-2.24.75a2.9 2.9 0 0 0-1.96 3.12c.1.86-.57 1.63-1.45 1.63h-.38c-.86 0-1.6.6-1.76 1.44L14 10'/>" & \
         "<path d='m22 13-.82-.33c-.86-.34-1.82.2-1.98 1.11c-.11.7-.72 1.22-1.43 1.22H17'/>" & \
         "<path d='m11 2 .33.82c.34.86-.2 1.82-1.11 1.98C9.52 4.9 9 5.52 9 6.23V7'/>" & \
         "<path d='M11 13c1.93 1.93 2.83 4.17 2 5-.83.83-3.07-.07-5-2-1.93-1.93-2.83-4.17-2-5 .83-.83 3.07.07 5 2Z'/>"
   -- The original first: what the game needs is read from it, and it is
   -- unloaded, before the new stack is made
   readOriginal
   put "Balloon Game" into tInfo["name"]
   put "after LiveCode Ltd" into tInfo["credit"]
   put "gamepad-2" into tInfo["icon"]
   put lkColor("sky") into tInfo["accent"]
   put lkColor("indigo") into tInfo["accent2"]
   put "Page" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Home|Balloon Game|Fly a hot air balloon: take off, collect points and dodge the birds.|gamepad-2|front" & return & \
         "introduction|Start|Click START and tell the game your name.|user|wide" & return & \
         "page1|Take Off|Click the balloon, and it flies off along a path.|route|wide" & return & \
         "page2|Points|Collect 3000 points with the arrow keys, then fly off to the right.|coins|wide keys" & return & \
         "page3|Birds|Cross the sky with the arrow keys, and keep clear of the birds.|bird|wide keys" & return & \
         "page4|The End|You made it to the end of your balloon adventure.|party-popper|wide" & return & \
         "Moving|Moving|A picture moves along a path, or a step at a time with the arrow keys.|move|page" & return & \
         "Loop|Loop|One handler moves the ground and the birds, twenty times a second.|rotate-cw|page" & return & \
         "Collisions|Collide|The intersect function tells when two pictures touch: points to collect, birds to avoid.|zap|page" & return & \
         "images|Pictures|The game's buttons are pictures: one at rest, and one while you press.|image|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   -- (the runtime gives the stage its rect after a card's own preOpenCard,
   -- which places the game on it: every card with a stage is wide, so the
   -- stage is wide from the start)
   set the rect of graphic "Stage" of card "introduction" to kLeft, kTop, kRight, kBottom
   copy audioclip "hiscore.wav" of stack kScratch to stack "Balloon Game"
   -- (the pictures of the buttons first: the buttons name them)
   buildPictures
   buildHome
   buildIntroduction
   buildPage1
   buildPage2
   buildPage3
   buildPage4
   buildMoving
   buildLoop
   buildCollisions
   unlock messages
   delete stack kScratch
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Balloon Game.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

################################################################################
#
# The original's pictures, path and sound
#

-- Reads what the game needs from the original: its pictures, made smaller
-- for the stage, the points of its path, and its sound, which waits in a
-- stack of our own; then unloads it (from memory: its file is not touched)
private command readOriginal
   local tRepo, tOriginal, tName, tPng, tCompression
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put tRepo & "/ide/Resources/Start Center/samples/sample_4/balloon.livecode" into tOriginal
   if there is no stack tOriginal then
      throw "cannot find the original: " & tOriginal
   end if
   put the text of image "intro_background.png" of card "introduction" of stack tOriginal into tPng["intro"]
   put the text of image "background.png" of card "page1" of stack tOriginal into tPng["background"]
   put the text of image "foreground" of card "page1" of stack tOriginal into tPng["foreground"]
   put the text of image "balloon" of card "page1" of stack tOriginal into tPng["balloon"]
   put the text of image "points" of card "page2" of stack tOriginal into tPng["points"]
   put the text of image "bird1" of card "page3" of stack tOriginal into tPng["bird"]
   repeat for each item tName in "start,start_pressed,up,up_pressed,right,right_pressed,down,down_pressed,left,left_pressed"
      put the text of image (tName & ".png") of card "images" of stack tOriginal into tPng[tName]
   end repeat
   put the points of graphic "path" of card "page1" of stack tOriginal into sPath
   if there is a stack kScratch then
      delete stack kScratch
   end if
   create stack kScratch
   copy audioclip "hiscore.wav" of stack tOriginal to stack kScratch
   delete stack tOriginal
   -- Each picture as the game shows it, and smaller ones for the pages,
   -- kept as PNG (an opaque picture made from imageData would otherwise be
   -- kept in the engine's own RLE, which no picture's text takes)
   put the paintCompression into tCompression
   set the paintCompression to "png"
   put empty into sPicture
   repeat for each key tName in tPng
      put scaled(tPng[tName], kScale) into sPicture[tName]
   end repeat
   repeat for each item tName in "background,foreground,balloon,up,right,down,left"
      put scaled(tPng[tName], kThumb) into sPicture[tName & "Thumb"]
   end repeat
   put scaled(tPng["background"], kTiny) into sPicture["backgroundTiny"]
   put scaled(tPng["foreground"], kTiny) into sPicture["foregroundTiny"]
   put scaled(tPng["bird"], 0.44) into sPicture["birdSmall"]
   set the paintCompression to tCompression
end readOriginal

-- A picture (PNG) at pScale of its size: drawn smoothly at the new size in
-- the scratch stack, and read back
private function scaled pPng, pScale
   local tObj, tWidth, tHeight, tData, tAlpha, tOut
   create image in card 1 of stack kScratch
   put it into tObj
   set the text of tObj to pPng
   put max(1, round(the formattedWidth of tObj * pScale)) into tWidth
   put max(1, round(the formattedHeight of tObj * pScale)) into tHeight
   set the resizeQuality of tObj to "best"
   set the lockLoc of tObj to true
   set the width of tObj to tWidth
   set the height of tObj to tHeight
   put the imageData of tObj into tData
   put the alphaData of tObj into tAlpha
   delete tObj
   create image in card 1 of stack kScratch
   put it into tObj
   set the width of tObj to tWidth
   set the height of tObj to tHeight
   set the imageData of tObj to tData
   set the alphaData of tObj to tAlpha
   put the text of tObj into tOut
   delete tObj
   return tOut
end scaled

-- One of the pictures, its top left at pLeft,pTop
private function picture pName, pKey, pLeft, pTop, pGroup
   local tObj
   if pGroup is empty then
      create image pName
   else
      create image pName in group pGroup
   end if
   put it into tObj
   set the text of tObj to sPicture[pKey]
   set the topLeft of tObj to pLeft, pTop
   return tObj
end picture

-- Where a place on the original's card is on the stage of a game card:
-- the card's bottom is the stage's, and the top of the sky is cut off
private function gameX pX
   return kLeft + round(pX * kScale)
end gameX

private function gameY pY
   return kBottom - round((768 - pY) * kScale)
end gameY

-- On the first and last cards, whose pictures have their words at the
-- top, the card's top is the stage's, and the bottom of the ground is cut
private function introY pY
   return kTop + round(pY * kScale)
end introY

################################################################################
#
# Drawing helpers
#

-- The game's own part of a card: a group as big as the stage, which keeps
-- the game's pictures inside it, and rounds its corners (sceneEnd)
private command sceneBegin
   get lkGroup("Scene", lkR(kLeft, kTop, kRight, kBottom), empty)
   -- (the first control made in a group goes to its top left: this one is
   -- already there)
   get lkBox("SceneAnchor", lkR(kLeft, kTop, kLeft + 1, kTop + 1), empty, 0, "Scene")
end sceneBegin

private command sceneEnd
   lkCorners "SceneCorner", lkR(kLeft, kTop, kRight, kBottom), 18, lkColor("bg"), "Scene"
end sceneEnd

-- A small picture of the game in a group of its own, on a panel: pRect
-- shows its bottom, pLeft is where the original's card's left is
private command miniBegin pName, pRect
   get lkGroup(pName, pRect, empty)
   get lkBox(pName & "Anchor", lkR(item 1 of pRect, item 2 of pRect, item 1 of pRect + 1, item 2 of pRect + 1), empty, 0, pName)
end miniBegin

private command miniEnd pName, pRect, pRadius
   lkCorners pName & "Corner", pRect, pRadius, "255,255,255", pName
end miniEnd

-- The game's words, white and bold, with a soft shadow so that they read
-- on the sky
private function gameText pName, pRect, pText, pSize, pGroup
   local tObj
   put lkLabel(pName, pRect, pText, pSize, "255,255,255", pGroup, "center") into tObj
   set the textStyle of tObj to "bold"
   lkShadow tObj, 6, 1, 45
   return tObj
end gameText

-- One of the game's arrow buttons: its picture at rest, and another while
-- it is pressed, from the card "images"
private function arrowButton pName, pRect, pGroup
   local tObj
   create button pName in group pGroup
   put it into tObj
   set the style of tObj to "transparent"
   set the showName of tObj to false
   set the showBorder of tObj to false
   set the opaque of tObj to false
   set the autoHilite of tObj to true
   set the showFocusBorder of tObj to false
   set the traversalOn of tObj to false
   set the icon of tObj to the id of image (pName & ".png") of card "images"
   set the hiliteIcon of tObj to the id of image (pName & "_pressed.png") of card "images"
   set the rect of tObj to pRect
   set the script of tObj to exScript("arrow/" & pName)
   return tObj
end arrowButton

-- The four arrow buttons, where the original had them
private command arrowButtons pGroup
   local tArrow
   set the itemDelimiter to "|"
   repeat for each item tArrow in kArrows
      set the itemDelimiter to comma
      get arrowButton(item 1 of tArrow, lkR(gameX(item 2 of tArrow), gameY(item 3 of tArrow), \
            gameX(item 4 of tArrow), gameY(item 5 of tArrow)), pGroup)
      set the itemDelimiter to "|"
   end repeat
   set the itemDelimiter to comma
end arrowButtons

-- The title of the game, at the top of the stage
private command gameTitle
   get gameText("title", lkR(kLeft, kTop + 8, kRight, kTop + 46), "Balloon Adventure", 30, "Scene")
end gameTitle

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

-- Words on a dark pill, on a picture: from pX (pAlign "left"), ending at
-- pX ("right") or centred on it ("center"), its middle at pY
private function pill pName, pX, pY, pText, pAlign, pGroup
   local tLabel, tWidth, tLeft, tTop, tObj
   put lkLabel(pName & "_label", lkR(0, pY - 8, 600, pY + 8), pText, 11, "255,255,255", pGroup, "center") into tLabel
   set the textStyle of tLabel to "bold"
   set the dontWrap of tLabel to true
   -- (as wide as the words would be in a font kFontRoom narrower, and
   -- the words in the middle: in the IDE's wider font they still fit)
   put round(the formattedWidth of tLabel / kFontRoom) + 16 into tWidth
   if pAlign is "center" then
      put pX - tWidth div 2 into tLeft
   else if pAlign is "right" then
      put pX - tWidth into tLeft
   else
      put pX into tLeft
   end if
   -- (the words in the middle of the pill, up and down, as a button's are)
   put pY - (the formattedHeight of tLabel + 4) div 2 into tTop
   set the rect of tLabel to tLeft + 4, tTop, tLeft + tWidth - 4, tTop + the formattedHeight of tLabel + 8
   put lkBox(pName, lkR(tLeft, pY - 12, tLeft + tWidth, pY + 12), lkColor("side"), 12, pGroup) into tObj
   set the blendLevel of tObj to 25
   relayer tObj before tLabel
   return tObj
end pill

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

-- A dashed outline of a rect
private function outline pName, pRect, pColor, pGroup
   local tObj
   put lkBox(pName, pRect, empty, 0, pGroup) into tObj
   set the lineSize of tObj to 1
   set the foregroundColor of tObj to pColor
   set the dashes of tObj to "4,3"
   return tObj
end outline

-- A sky, as the game's is: deep blue at the top, pale at the horizon
private function skyColors
   return lkMix(lkColor("side"), lkColor("sky"), 0.45) & "|" & lkColor("sky") & "|" & lkMix(lkColor("sky"), "255,255,255", 0.72)
end skyColors

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

-- The front page: what this is, a tile for each page (the game's five,
-- then how it works), and how to play
private command buildHome
   local tObj
   go card "Home"
   exHero lkR(kLeft, kTop, kRight, 256), lkColor("indigo") & "|" & lkColor("sky"), \
         "LIVECODE LTD  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "Fly a balloon around the world", \
         "A little game, a card at a time: take off along a path, collect points with the arrow keys " & \
         "and dodge the birds. Then see how each part of it works."
   -- The balloon in the banner, risen from the bottom along a dashed path,
   -- and two birds
   get drawLine("hero_path", "842,254" & return & "862,252" & return & "882,248" & return & "900,243" & return & \
         "916,236" & return & "932,229", "255,255,255", 2, false, "3,6", "hero")
   set the blendLevel of it to 40
   -- (and a sparkle of the banner's that would be on its words, moved)
   set the loc of graphic "hero_star2" to 978, 240
   put picture("hero_balloon", "balloon", 904, 118, "hero") into tObj
   lkShadow tObj, 16, 6, 30
   get picture("hero_bird1", "birdSmall", 866, 128, "hero")
   get picture("hero_bird2", "birdSmall", 856, 170, "hero")
   set the blendLevel of it to 20
   exProgramTiles 270, 5, 60, 10
   rowsPanel "Play", lkR(kLeft, 414, 620, kBottom), "How to play", \
         "mouse-pointer-click|Click START, type your name, then click the balloon to take off." & return & \
         "keyboard|Steer with the arrow keys, or click the arrows on the stage." & return & \
         "coins|Collect 3000 points, then fly past the birds to the end.", \
         lkColor("sky"), empty
   rowsPanel "Learn", lkR(636, 414, kRight, kBottom), "What you will learn", \
         "move|Move a picture along a path, or a step a key" & return & \
         "rotate-cw|A game loop that sends itself again and again" & return & \
         "zap|Collisions with intersect, and a sound to cheer", \
         lkColor("indigo"), "go Moving" & return & "go Loop" & return & "go Collisions"
end buildHome

-- The start: the original's picture, with its name, and its START button
private command buildIntroduction
   local tObj
   go card "introduction"
   sceneBegin
   get picture("intro_background.png", "intro", kLeft, kTop, "Scene")
   create button "start" in group "Scene"
   put it into tObj
   set the style of tObj to "transparent"
   set the showName of tObj to false
   set the showBorder of tObj to false
   set the opaque of tObj to false
   set the autoHilite of tObj to true
   set the showFocusBorder of tObj to false
   set the traversalOn of tObj to false
   set the icon of tObj to the id of image "start.png" of card "images"
   set the hiliteIcon of tObj to the id of image "start_pressed.png" of card "images"
   set the rect of tObj to gameX(248), introY(353), gameX(776), introY(575)
   set the script of tObj to exScript("introduction/start")
   sceneEnd
end buildIntroduction

-- Take off: the balloon on the ground, and the path it flies along
private command buildPage1
   local tObj, tPoints, tPoint
   go card "page1"
   set the script of this card to exScript("page1/card")
   sceneBegin
   get picture("background.png", "background", kLeft, gameY(0), "Scene")
   put picture("foreground", "foreground", 0, 0, "Scene") into tObj
   set the loc of tObj to gameX(512), gameY(694)
   put picture("balloon", "balloon", 0, 0, "Scene") into tObj
   set the loc of tObj to gameX(85), gameY(655)
   set the script of tObj to exScript("page1/balloon")
   get gameText("story", lkR(gameX(51), gameY(127) + 8, gameX(973), gameY(281)), \
         "Hi, pilot. Your hot air balloon is about to take off on a round the world adventure." & return & return & \
         "Click on the balloon to take off.", 18, "Scene")
   gameTitle
   -- The path: a curve the balloon flies along, which nobody sees
   repeat for each line tPoint in sPath
      put gameX(item 1 of tPoint) & "," & gameY(item 2 of tPoint) & return after tPoints
   end repeat
   delete the last char of tPoints
   create graphic "path" in group "Scene"
   put it into tObj
   set the style of tObj to "curve"
   set the points of tObj to tPoints
   hide tObj
   sceneEnd
end buildPage1

-- Points: the ground in two pictures, the balloon, the points to collect,
-- the arrows; the score in the header
private command buildPage2
   local tObj
   go card "page2"
   set the script of this card to exScript("page2/card")
   sceneBegin
   get picture("background.png", "background", kLeft, gameY(0), "Scene")
   put picture("foreground1", "foreground", 0, 0, "Scene") into tObj
   set the loc of tObj to gameX(512), gameY(694)
   put picture("foreground2", "foreground", 0, 0, "Scene") into tObj
   set the topLeft of tObj to the topRight of image "foreground1"
   get picture("balloon", "balloon", kLeft, gameY(254), "Scene")
   gameTitle
   get gameText("story", lkR(gameX(53), gameY(129) + 8, gameX(975), gameY(240) + 8), \
         "Hi again, pilot. For this task you have to collect 3000 points to move on to the next level. " & \
         "Pilot your balloon around using the arrow keys to collect points.", 18, "Scene")
   put picture("points", "points", 0, 0, "Scene") into tObj
   set the loc of tObj to gameX(224), gameY(500)
   arrowButtons "Scene"
   sceneEnd
   -- The score, in the header (the original's was at the top right of
   -- its card)
   put lkLabel("ScoreLabel", "720,16,872,30", "POINTS", 11, lkColor("muted"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("score", "700,28,872,66", "0", 30, lkColor("amber"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
end buildPage2

-- Birds: the ground, the arrows, the balloon and three birds
private command buildPage3
   local tObj
   go card "page3"
   set the script of this card to exScript("page3/card")
   sceneBegin
   get picture("background.png", "background", kLeft, gameY(0), "Scene")
   put picture("foreground2", "foreground", 0, 0, "Scene") into tObj
   put picture("foreground1", "foreground", 0, 0, "Scene") into tObj
   set the loc of tObj to gameX(512), gameY(694)
   set the topLeft of image "foreground2" to the topRight of tObj
   arrowButtons "Scene"
   gameTitle
   get gameText("story", lkR(gameX(53), gameY(129) + 8, gameX(975), gameY(240) + 8), \
         "Hi again, pilot. For this task you have to move across the screen without colliding with any birds.", 18, "Scene")
   get picture("balloon", "balloon", kLeft, gameY(254), "Scene")
   put picture("bird1", "bird", 0, 0, "Scene") into tObj
   set the loc of tObj to gameX(1024), gameY(380)
   put picture("bird2", "bird", 0, 0, "Scene") into tObj
   set the loc of tObj to gameX(160), gameY(270)
   put picture("bird3", "bird", 0, 0, "Scene") into tObj
   set the loc of tObj to gameX(400), gameY(500)
   sceneEnd
end buildPage3

-- The end: the first card's picture, its words, and a way back to the start
private command buildPage4
   local tWidth
   go card "page4"
   set the script of this card to exScript("page4/card")
   sceneBegin
   get picture("intro_background.png", "intro", kLeft, kTop, "Scene")
   get gameText("story", lkR(gameX(46), introY(319), gameX(978), introY(589)), \
         "Congratulations pilot. You have reached the end of your balloon adventure.", 36, "Scene")
   sceneEnd
   put exButton("Play Again", 0, 548, 40, "Play again", "rotate-cw", "primary", lkColor("amber"), empty, empty, 0) into tWidth
   set the left of group "Play Again" to (kLeft + kRight - tWidth) div 2
   lkShadow the long id of graphic "Play Again_bg", 14, 4, 30
   set the script of group "Play Again" to exScript("page4/Play Again")
end buildPage4

-- Moving: the balloon on its path, and a step a key; and the code of both
private command buildMoving
   local tObj, tBottom, tPoint, tPoints, tIndex, tScene
   go card "Moving"
   -- Along a path: page1 in small, the path drawn, the balloon on it
   get exPanel("PathPanel", lkR(kLeft, kTop, 620, 352), empty)
   get heading("PathTitle", kLeft + 20, kTop + 18, 600, "Along a path", 15, empty)
   put lkR(kLeft + 16, kTop + 50, 604, kTop + 180) into tScene
   miniBegin "PathScene", tScene
   get picture("PathBackground", "backgroundThumb", item 1 of tScene, item 4 of tScene - round(768 * kThumb), "PathScene")
   put picture("PathGround", "foregroundThumb", 0, 0, "PathScene") into tObj
   set the bottomLeft of tObj to item 1 of tScene + round(-988 * kThumb), item 4 of tScene
   repeat for each line tPoint in sPath
      put thumbX(tScene, item 1 of tPoint) & "," & thumbY(tScene, item 2 of tPoint) & return after tPoints
   end repeat
   delete the last char of tPoints
   get drawLine("PathLine", tPoints, "255,255,255", 2, false, "4,5", "PathScene")
   set the blendLevel of it to 10
   -- (the balloon where it starts, and fainter where it is a third and
   -- three fifths of the way along)
   repeat for each item tIndex in "91,51"
      put line tIndex of sPath into tPoint
      put picture("PathGhost" & tIndex, "balloonThumb", 0, 0, "PathScene") into tObj
      set the loc of tObj to thumbX(tScene, item 1 of tPoint), thumbY(tScene, item 2 of tPoint)
      set the blendLevel of tObj to 100 - round(tIndex * 0.7)
   end repeat
   put picture("PathBalloon", "balloonThumb", 0, 0, "PathScene") into tObj
   set the loc of tObj to thumbX(tScene, 85), thumbY(tScene, 655)
   get pill("PathPill", item 1 of tScene + 28, item 2 of tScene + 16, "graphic " & quote & "path" & quote, "left", "PathScene")
   get pill("StopPill", item 3 of tScene - 10, item 4 of tScene - 56, "then moveStopped", "right", "PathScene")
   miniEnd "PathScene", tScene, 12
   put textBlock("PathText", kLeft + 20, item 4 of tScene + 14, 600, \
         "move takes the balloon along the points of a graphic you never see, in 3 seconds. " & \
         "When it is there, the engine sends moveStopped.", \
         12, lkColor("soft"), empty) into tBottom
   -- A step a key: page2 in small, the balloon, four ways to go and the
   -- four arrows
   get exPanel("KeysPanel", lkR(636, kTop, kRight, 352), empty)
   get heading("KeysTitle", 656, kTop + 18, 984, "A step a key", 15, empty)
   put lkR(652, kTop + 50, 984, kTop + 180) into tScene
   miniBegin "KeysScene", tScene
   get picture("KeysBackground", "backgroundThumb", item 1 of tScene, item 4 of tScene - round(768 * kThumb), "KeysScene")
   put picture("KeysGround", "foregroundThumb", 0, 0, "KeysScene") into tObj
   set the bottomLeft of tObj to item 1 of tScene + round(-988 * kThumb), item 4 of tScene
   put picture("KeysBalloon", "balloonThumb", 0, 0, "KeysScene") into tObj
   set the loc of tObj to 780, kTop + 104
   get drawLine("KeysUp", "780," & (kTop + 76) & return & "780," & (kTop + 60), "255,255,255", 2, true, empty, "KeysScene")
   get drawLine("KeysDown", "780," & (kTop + 132) & return & "780," & (kTop + 148), "255,255,255", 2, true, empty, "KeysScene")
   get drawLine("KeysLeft", "762," & (kTop + 104) & return & "740," & (kTop + 104), "255,255,255", 2, true, empty, "KeysScene")
   get drawLine("KeysRight", "798," & (kTop + 104) & return & "820," & (kTop + 104), "255,255,255", 2, true, empty, "KeysScene")
   miniArrows tScene
   get pill("KeysPill", item 1 of tScene + 12, item 2 of tScene + 22, "arrowKey " & quote & "up" & quote, "left", "KeysScene")
   miniEnd "KeysScene", tScene, 12
   put textBlock("KeysText", 656, item 4 of tScene + 14, 980, \
         "An arrow key, or a click on an arrow, sends arrowKey to the card with its direction. " & \
         "The card moves the balloon a step that way, if it is not at the edge.", \
         12, lkColor("soft"), empty) into tBottom
   get codeBox("MoveCode", lkR(kLeft, 368, kRight, kBottom), \
         "move and arrowKey, in the scripts of the cards " & quote & "page1" & quote & " and " & quote & "page2" & quote, \
         exScript("snippet/move"))
end buildMoving

-- Where a place on the original's card is in a small picture of it: its
-- bottom is the picture's
private function thumbX pScene, pX
   return item 1 of pScene + round(pX * kThumb)
end thumbX

private function thumbY pScene, pY
   return item 4 of pScene - round((768 - pY) * kThumb)
end thumbY

-- The game's four arrows, small, where the game has them
private command miniArrows pScene
   local tArrow, tObj
   set the itemDelimiter to "|"
   repeat for each item tArrow in kArrows
      set the itemDelimiter to comma
      put picture("Keys_" & item 1 of tArrow, item 1 of tArrow & "Thumb", 0, 0, "KeysScene") into tObj
      set the loc of tObj to (thumbX(pScene, item 2 of tArrow) + thumbX(pScene, item 4 of tArrow)) div 2, \
            (thumbY(pScene, item 3 of tArrow) + thumbY(pScene, item 5 of tArrow)) div 2
      set the itemDelimiter to "|"
   end repeat
   set the itemDelimiter to comma
end miniArrows

-- The loop: the stage, the two pictures of the ground under it, and how
-- they take turns; and the code that moves them
private command buildLoop
   local tObj, tX0, tWin, tGround, tTop, tBottom
   go card "Loop"
   get exPanel("Picture", lkR(kLeft, kTop, kRight, 334), empty)
   get heading("PictureTitle", kLeft + 22, kTop + 18, 980, "Two pictures of the ground, taking turns", 15, empty)
   put lkLabel("PictureText", lkR(kLeft + 22, kTop + 44, 980, kTop + 78), \
         "moveForeground moves both pictures to the left, then sends itself again in 50 milliseconds: twenty steps " & \
         "a second, until closeCard puts false into sMoving. On the Birds card it moves the birds too.", \
         12, lkColor("soft"), empty) into tObj
   fixLines tObj
   set the height of tObj to the formattedHeight of tObj + 4
   -- The original's card, 1024 across, at kTiny: where its 0 is, the
   -- stage's rect, and the ground's top
   put 407 into tX0
   put 268 into tBottom
   put lkR(tX0, tBottom - round(768 * kTiny), tX0 + round(1024 * kTiny), tBottom) into tWin
   put tBottom - round(149 * kTiny) into tGround
   -- (the ground off the stage is pale)
   put picture("Ground1", "foregroundTiny", tX0 + round(-988 * kTiny), tGround, empty) into tObj
   set the blendLevel of tObj to 55
   put picture("Ground2", "foregroundTiny", tX0 + round(2012 * kTiny), tGround, empty) into tObj
   set the blendLevel of tObj to 55
   -- (and on the stage, as it is)
   miniBegin "Window", tWin
   get picture("WindowSky", "backgroundTiny", tX0, item 2 of tWin, "Window")
   get picture("WindowGround1", "foregroundTiny", tX0 + round(-988 * kTiny), tGround, "Window")
   get picture("WindowGround2", "foregroundTiny", tX0 + round(2012 * kTiny), tGround, "Window")
   miniEnd "Window", tWin, 6
   put lkBox("WindowFrame", tWin, empty, 6, empty) into tObj
   set the lineSize of tObj to 2
   set the foregroundColor of tObj to lkColor("ink")
   get pill("WindowPill", item 1 of tWin - 10, (item 2 of tWin + item 4 of tWin) div 2 - 8, "the stage", "right", empty)
   put lkLabel("Ground1Label", lkR(tX0 + round(-988 * kTiny), tBottom + 6, tX0 + round(2012 * kTiny), tBottom + 22), \
         "foreground1", 11, lkColor("soft"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Ground2Label", lkR(tX0 + round(2012 * kTiny), tBottom + 6, tX0 + round(5012 * kTiny), tBottom + 22), \
         "foreground2", 11, lkColor("soft"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   -- Every step, to the left
   get drawLine("Step", "776," & (tGround - 26) & return & "700," & (tGround - 26), lkColor("sky"), 3, true, empty, empty)
   put lkLabel("StepLabel", lkR(786, tGround - 36, 990, tGround - 18), "4 pixels left, every 50 ms", 12, lkColor("sky"), empty) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   -- And the turn: the picture off the left goes to the right of the other
   put tBottom + 40 into tTop
   get drawLine("Turn", (tX0 + round(-988 * kTiny)) & "," & (tBottom + 26) & return & (tX0 + round(-988 * kTiny)) & "," & tTop & \
         return & (tX0 + round(5012 * kTiny)) & "," & tTop & return & (tX0 + round(5012 * kTiny)) & "," & (tBottom + 26), \
         lkColor("muted"), 2, true, "4,4", empty)
   get pill("TurnPill", tX0 + round(2012 * kTiny), tTop, "off the left of the stage? Then to the right of the other", "center", empty)
   get codeBox("LoopCode", lkR(kLeft, 350, kRight, kBottom), "moveForeground, in the script of the card " & quote & "page2" & quote, \
         exScript("snippet/loop"))
end buildLoop

-- Collisions: two pictures whose rects meet but whose pixels do not, and
-- two that touch; the words, the sound, and the code
private command buildCollisions
   local tObj, tBalloon, tBird, tScene, tStep, tWidth
   go card "Collisions"
   get exPanel("Picture", lkR(kLeft, kTop, kRight, 362), empty)
   get heading("PictureTitle", kLeft + 22, kTop + 18, 800, "Do they touch?", 15, empty)
   -- The sound the game plays, to hear
   put exButton("Play Sound", 0, kTop + 14, 32, "Play the sound", "volume-2", "light", lkColor("sky"), empty, empty, 0) into tWidth
   set the left of group "Play Sound" to kRight - 16 - tWidth
   lkBorder the long id of graphic "Play Sound_bg", lkColor("line")
   set the script of group "Play Sound" to exScript("Collisions/Play Sound")
   put lkLabel("PictureText", lkR(kLeft + 22, kTop + 46, 980, kTop + 82), \
         "Every picture is a rectangle, but most have see-through corners. With " & quote & "pixels" & quote & \
         ", intersect is true only where two pictures' pixels touch: on the Points card, that adds 1000 " & \
         "and plays hiscore.wav.", 12, lkColor("soft"), empty) into tObj
   fixLines tObj
   set the height of tObj to the formattedHeight of tObj + 4
   -- Near: the bird at the balloon's top right, as near as it can be
   -- without a pixel touching
   put lkR(kLeft + 16, kTop + 88, 620, 330) into tScene
   collisionScene "Near", tScene
   put picture("NearBalloon", "balloon", item 1 of tScene + 120, item 4 of tScene - 112, "Near") into tBalloon
   put picture("NearBird", "bird", 0, 0, "Near") into tBird
   repeat with tStep = 0 to 40
      set the bottomLeft of tBird to the right of tBalloon - 34 + tStep, the top of tBalloon + 34 - tStep
      if not intersect(tBalloon, tBird, "pixels") then
         exit repeat
      end if
   end repeat
   collisionMarks "Near", tBalloon, tBird
   miniEnd "Near", tScene, 12
   put lkLabel("NearText", lkR(item 1 of tScene, item 4 of tScene + 8, item 3 of tScene, item 4 of tScene + 24), \
         "The rects overlap, the pixels do not: false", 12, lkColor("ink"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   -- Hit: the bird on the balloon
   put lkR(636, kTop + 88, kRight - 16, 330) into tScene
   collisionScene "Hit", tScene
   put picture("HitBalloon", "balloon", item 1 of tScene + 120, item 4 of tScene - 112, "Hit") into tBalloon
   put picture("HitBird", "bird", 0, 0, "Hit") into tBird
   set the loc of tBird to the right of tBalloon - 4, the top of tBalloon + 34
   collisionMarks "Hit", tBalloon, tBird
   miniEnd "Hit", tScene, 12
   put lkLabel("HitText", lkR(item 1 of tScene, item 4 of tScene + 8, item 3 of tScene, item 4 of tScene + 24), \
         "The pixels touch: true, and the game is over", 12, lkColor("ink"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   get codeBox("CollideCode", lkR(kLeft, 378, kRight, kBottom), "intersect, in the scripts of the cards " & \
         quote & "page2" & quote & " and " & quote & "page3" & quote, exScript("snippet/collide"))
end buildCollisions

-- A small sky for the collisions: the game's own, from its middle
private command collisionScene pName, pRect
   miniBegin pName, pRect
   get picture(pName & "Sky", "background", item 1 of pRect - 150, item 2 of pRect - 230, pName)
end collisionScene

-- The rects of two pictures, dashed, and where they overlap
private command collisionMarks pName, pA, pB
   local tRect, tObj
   get outline(pName & "RectA", the rect of pA, "255,255,255", pName)
   get outline(pName & "RectB", the rect of pB, "255,255,255", pName)
   put max(the left of pA, the left of pB), max(the top of pA, the top of pB), \
         min(the right of pA, the right of pB), min(the bottom of pA, the bottom of pB) into tRect
   if item 1 of tRect < item 3 of tRect and item 2 of tRect < item 4 of tRect then
      put lkBox(pName & "Overlap", tRect, lkMix(lkColor("amber"), "255,255,255", 0.3), 0, pName) into tObj
      set the blendLevel of tObj to 60
      set the lineSize of tObj to 2
      set the foregroundColor of tObj to lkColor("amber")
   end if
end collisionMarks

-- The pictures of the game's buttons, as the original's last card has
-- them: the buttons show them by their ids
private command buildPictures
   local tObj, tSky, tName, tX, tCol, tMid, tBottom
   go card "images"
   -- START, at rest and pressed
   put lkR(kLeft, kTop, 664, kBottom) into tSky
   put lkBox("StartSky", tSky, lkColor("sky"), 16, empty) into tObj
   lkGradient tObj, skyColors(), kLeft & "," & kTop, kLeft & "," & kBottom
   lkShadow tObj, 16, 3, 14
   put (kLeft + 664) div 2 into tMid
   put picture("start.png", "start", 0, 0, empty) into tObj
   set the loc of tObj to tMid, kTop + 118
   get pill("StartPill", tMid, the bottom of tObj + 20, "start.png: the icon", "center", empty)
   put picture("start_pressed.png", "start_pressed", 0, 0, empty) into tObj
   set the loc of tObj to tMid, kTop + 340
   get pill("PressedPill", tMid, the bottom of tObj + 20, "start_pressed.png: the hiliteIcon, while you press", "center", empty)
   -- The arrows: a row at rest, and a row pressed
   put lkBox("ArrowSky", lkR(680, kTop, kRight, 330), lkColor("sky"), 16, empty) into tObj
   lkGradient tObj, skyColors(), "680," & kTop, "680,330"
   lkShadow tObj, 16, 3, 14
   put 0 into tCol
   repeat for each item tName in "up,right,down,left"
      add 1 to tCol
      put 680 + 16 + 36 + (tCol - 1) * 72 into tX
      put picture(tName & ".png", tName, 0, 0, empty) into tObj
      set the loc of tObj to tX, kTop + 52
      put picture(tName & "_pressed.png", tName & "_pressed", 0, 0, empty) into tObj
      set the loc of tObj to tX, kTop + 148
   end repeat
   put lkLabel("IconText", lkR(680, kTop + 86, kRight, kTop + 102), "the icons, at rest", 11, "255,255,255", empty, "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("HiliteText", lkR(680, kTop + 182, kRight, kTop + 198), "the hiliteIcons, while you press", 11, \
         "255,255,255", empty, "center") into tObj
   set the textStyle of tObj to "bold"
   -- The words
   get exPanel("Words", lkR(680, 346, kRight, kBottom), empty)
   get heading("WordsTitle", 700, 364, 984, "Buttons made of pictures", 16, empty)
   put textBlock("Words1", 700, 398, 980, \
         "Each of the game's buttons is transparent and shows no name: what you see is its icon, " & \
         "a picture on this card that it names by its id. While you press it, the button shows its hiliteIcon.", \
         13, lkColor("soft"), empty) into tBottom
   tipBox "Tip", lkR(696, 540, 984, 600), "Press an arrow on the Points card, and watch it change.", lkColor("sky")
end buildPictures

-- A tip: a light bulb and a line or two, on a tint of a colour
private command tipBox pName, pRect, pText, pColor
   local tObj, tL, tT, tR, tB, tMid
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   put item 4 of pRect into tB
   put (tT + tB) div 2 into tMid
   get lkBox(pName, pRect, lkMix("255,255,255", pColor, 0.08), 12, empty)
   get exIcon(pName & "Icon", "lightbulb", pColor, lkR(tL + 14, tMid - 10, tL + 34, tMid + 10), empty)
   put lkLabel(pName & "Text", lkR(tL + 46, tT + 8, tR - 12, tB - 6), pText, 12, lkColor("soft"), empty) into tObj
   fixLines tObj
   set the height of tObj to the formattedHeight of tObj + 4
   set the top of tObj to tMid - (the formattedHeight of tObj) div 2 - 2
end tipBox

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Balloon Game: LiveCode Ltd's balloon ("Balloon Adventure"), remastered for OXT-Beyond in 2026
--balloon 1.0.0.0, LiveCode Ltd (then RunRev Ltd), 2013, made with LiveCode 6.1.1: the fourth sample of
--LiveCode Community's Start Center, free software under the GNU General Public License, version 3

--The game is on the cards "introduction", "page1", "page2", "page3" and "page4", the original's cards,
--each of which goes on to the next when you have done its task. Their scripts, and their controls',
--are the original's. The sidebar, the header and the drawer of scripts are the groups "Frame",
--"Workbench" and "Scripts", which the script of the group "Frame" runs.

on preOpenStack
   global gName
   ## (remaster) The window's list goes to any card: until you give your name, you are a pilot
   if gName is empty then
      put "pilot" into gName
   end if
   codeFont
end preOpenStack

## (remaster) The original's cards were 1024 by 768 pixels. The game is on the stage now, 744 pixels
## across, so it is drawn at 744/1024 of its size, and a place on the original's card is a place on
## the stage: stageLoc(85,655) is where the original put 85,655. The stage is not as tall as the card
## would be, so the top of the sky is cut off, and the ground stays at the bottom
constant kScale = 0.7265625

function stageLoc pX, pY
   return stageX(pX) & comma & stageY(pY)
end stageLoc

function stageX pX
   return the left of graphic "Stage" + round(pX * kScale)
end stageX

function stageY pY
   return the bottom of graphic "Stage" - round((768 - pY) * kScale)
end stageY

## A distance on the original's card, on the stage: a step of 25 pixels there is 18 here
function stageSize pPixels
   return max(1, round(pPixels * kScale))
end stageSize

## (remaster) The game's handlers name its pictures, which the engine looks for on the card in front of
## the default stack. A message sent in time (moveForeground) or at the end of a move (moveStopped)
## may come while another window is in front, the Script Editor if you are reading a script: the
## handler calls this first, so that the names are this stack's. The result is the stack that was
## the default one, to put back
command useGameStack
   local tStack
   put the defaultStack into tStack
   set the defaultStack to the short name of me
   return tStack
end useGameStack

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
@*/

/*@ introduction/start
## The mouseUp message is sent by the engine when the user clicks and releases on a control
on mouseUp
   ## Use a global variable to store the user's name
   global gName

   ## The ask command displays a native dialog with a box the user can type into to answer
   ask "What is your name?"

   ## If the user does not cancel the dialog
   if the result is not "cancel" then
      ## Their answer is returned in the special variable "it"
      ## Put the answer into the global variable gName
      put it into gName
      ## (remaster) No name is no matter: the game calls you pilot
      if gName is empty then
         put "pilot" into gName
      end if
      ## Move to the next card
      go to the next card
   end if
end mouseUp
@*/

/*@ page1/card
## The preOpenCard message is sent before the card is made visible to the user
## Any layout can be done here and will not be visible
on preOpenCard
   ## Declare the global variable so it can be used
   global gName

   ## Reposition the controls
   ## (remaster) on the stage: stageLoc is in the script of the stack
   set the loc of image "balloon" to stageLoc(85,655)
   set the loc of image "foreground" to stageLoc(512,694)

   ## Put text into the field, using the gName variable to personalise the message
   put "Hi," && gName & ". Your hot air balloon is about to take off on a round the world adventure." & return & return & \
         "Click on the balloon to take off." into field "story"
   ## (remaster) The window lays the card out after this handler: it passes the message on
   pass preOpenCard
end preOpenCard

## (remaster) Leaving the card stops the balloon, or at the end of its path it would take you to the
## next card from wherever you went
on closeCard
   stop moving image "balloon"
end closeCard
@*/

/*@ page1/balloon
## The mouseUp message is sent by the engine when the user clicks and releases on a control
on mouseUp
   ## The move command moves an object smoothly along a path
   move image "balloon" to the points of graphic "path" in 3 seconds without waiting
end mouseUp

## The moveStopped message is sent when a "move" command finishes
on moveStopped
   ## (remaster) The move ends 3 seconds after the click, whichever window is in front then:
   ## useGameStack, in the script of the stack, makes the names below this stack's
   useGameStack
   ## Balloon has been piloted off the right side of the screen
   ## Position the balloon on the next card so it follows
   set the top of image "balloon" of card "page2" to the top of image "balloon" of this card
   ## (remaster) at the left of the stage, as the original's was at the left of its card, 0
   set the left of image "balloon" of card "page2" to the left of graphic "Stage"
   ## Go to the next card
   go next card
end moveStopped
@*/

/*@ page2/card
## The preOpenCard message is sent before the card is made visible to the user
## Any layout can be done here and will not be visible

## Use a script local variable to store whether the foreground should move
local sMoving

on preOpenCard
   ## Declare the global variable so it can be used
   global gName

   ## Reposition the controls
   ## (remaster) on the stage: stageLoc is in the script of the stack
   set the loc of image "foreground1" to stageLoc(512,694)
   set the topLeft of image "foreground2" to the topRight of image "foreground1"
   ## (remaster) The window's list can bring you straight here: a balloon that is not on the stage
   ## (it flew off to the right last time) starts again at the left
   if the left of image "balloon" >= the right of graphic "Stage" or the right of image "balloon" <= the left of graphic "Stage" then
      set the left of image "balloon" to the left of graphic "Stage"
   end if

   ## Set the score to 0
   put "0" into field "score"

   ## Put text into the field, using the gName variable to personalise the message
   ## (remaster) gName & ".": the original's && put a space before the full stop
   put "Hi again," && gName & ". For this task you have to collect 3000 points to move on to the next level. Pilot your balloon around using the arrow keys to collect points." into field "story"

   ## Display points to be collected
   showPoints

   ## Move the foreground to give the illusion of movement
   put true into sMoving
   moveForeground
   ## (remaster) The window lays the card out after this handler: it passes the message on
   pass preOpenCard
end preOpenCard

on closeCard
   put false into sMoving
end closeCard

## The arrowKey message is sent when an arrow key is pressed
## The direction is passed as a parameter
## (remaster) The edges are the stage's, and the steps are the original's, made smaller as the game
## is: stageSize(25) is 18 pixels
on arrowKey pDirection
   ## Depending on the direction reset the position of the balloon image
   ## Before moving the balloon check it will not go offscreen
   if pDirection is "down" then
      if the bottom of image "balloon" < (the bottom of graphic "Stage" - stageSize(5)) then
         set the bottom of image "balloon" to the bottom of image "balloon" + stageSize(25)
      end if
   else if pDirection is "up" then
      if the top of image "balloon" > the top of graphic "Stage" + stageSize(5) then
         set the top of image "balloon" to the top of image "balloon" - stageSize(25)
      end if
   else if pDirection is "left" then
      if the left of image "balloon" > the left of graphic "Stage" + stageSize(5) then
         set the left of image "balloon" to the left of image "balloon" - stageSize(25)
      end if
   else if pDirection is "right" then
      ## When moving right allow the balloon to go offscreen if the score has reached 3000
      if (the right of image "balloon" < the right of graphic "Stage") or (field "score" >= 3000) then
         set the right of image "balloon" to the right of image "balloon" + stageSize(25)
      end if
   end if

   ## Check to see if the balloon has collected a score object
   if field "score" < 3000 then
      checkForScore
   else
      ## 3000 has been scored
      ## Check if player has moved off right of the screen
      if the left of image "balloon" > the right of graphic "Stage" then
         put false into sMoving
         set the top of image "balloon" of card "page3" to the top of image "balloon" of this card
         set the left of image "balloon" of card "page3" to the left of graphic "Stage"
         go to next card
      end if
   end if
end arrowKey

on showPoints
   ## Use the random function to display the points image at a random point on screen
   ## (remaster) a random place on the original's card, 1024 by 768, on the stage
   set the loc of image "points" to stageLoc(random(1024), 250 + random(768 - 250))
end showPoints

on checkForScore
   local tError
   ## The intersect function tells you if 2 objects overlap/collide
   ## If the balloon and points image overlap
   if intersect(image "balloon",image "points","pixels") then
      ## Increase the score by 1000
      add 1000 to field "score"
      ## Play a sound
      ## (remaster) The original asked whether the platform was "mobile", which it never is (a phone's
      ## is "iphone" or "android"): on a phone, the environment is "mobile". A computer that cannot
      ## play the sound (a browser may not) plays on without it
      try
         if the environment is "mobile" then
            play (specialFolderPath("engine") & "/hiscore.wav")
         else
            play audioclip "hiscore.wav"
         end if
      catch tError
      end try

      ## Check if 3000 has been reached
      if field "score" = 3000 then
         ## If so display a new message
         ## (remaster) off the stage, at its top left: the original's was 0,0, its card's top left
         set the bottomRight image "points" to the topLeft of graphic "Stage"
         put "Congratulations. Now pilot your balloon off the right hand side of the screen." into field "story"
      else
         ## If not reposition the score image to be collected again
         showPoints
      end if
   end if
end checkForScore

on moveForeground
   local tStack
   ## There are 2 foreground images which connect together
   ## These are moved across the screen to create the illusion of movement
   ## (remaster) A message sent in time may come while another window is in front: useGameStack, in
   ## the script of the stack, makes the names below this stack's, and the last line puts back the
   ## stack that was
   useGameStack
   put the result into tStack
   lock screen
   if sMoving then
      set the left of image "foreground1" to the left of image "foreground1" - stageSize(5)
      set the left of image "foreground2" to the left of image "foreground2" - stageSize(5)

      ## When a foreground image moves completely off screen reset it on the right
      if the right of image "foreground1" < the left of graphic "Stage" then
         set the left of image "foreground1" to the right of image "foreground2"
      end if

      if the right of image "foreground2" < the left of graphic "Stage" then
         ## (remaster) to the right of foreground1: the original put it to the right of itself, over
         ## foreground1, and after a minute a gap opened in the ground
         set the left of image "foreground2" to the right of image "foreground1"
      end if
      send "moveForeground" to me in 50 milliseconds
   end if
   unlock screen
   set the defaultStack to tStack
end moveForeground
@*/

/*@ page3/card
## The preOpenCard message is sent before the card is made visible to the user
## Any layout can be done here and will not be visible

## Use a script local variable to store whether the foreground should move
local sMoving

on preOpenCard
   ## Declare the global variable so it can be used
   global gName

   ## Reposition the controls
   ## (remaster) on the stage: stageLoc is in the script of the stack
   set the loc of image "foreground1" to stageLoc(512,694)
   set the topLeft of image "foreground2" to the topRight of image "foreground1"
   set the loc of image "bird1" to stageLoc(1034,380)
   set the loc of image "bird2" to stageLoc(1250,270)
   set the loc of image "bird3" to stageLoc(1490,500)
   ## (remaster) The window's list can bring you straight here: a balloon that is not on the stage
   ## starts again at the left
   if the left of image "balloon" >= the right of graphic "Stage" or the right of image "balloon" <= the left of graphic "Stage" then
      set the left of image "balloon" to the left of graphic "Stage"
   end if

   ## Put text into the field, using the gName variable to personalise the message
   ## (remaster) gName & ".": the original's && put a space before the full stop
   put "Hi again," && gName & ". For this task you have to move across the screen without colliding with any birds." into field "story"

   ## Move the foreground to give the illusion of movement
   put true into sMoving
   moveForeground
   ## (remaster) The window lays the card out after this handler: it passes the message on
   pass preOpenCard
end preOpenCard

on closeCard
   put false into sMoving
end closeCard

## The arrowKey message is sent when an arrow key is pressed
## The direction is passed as a parameter
## (remaster) The edges are the stage's, and the steps are the original's, made smaller as the game
## is: stageSize(25) is 18 pixels
on arrowKey pDirection
   ## Depending on the direction reset the position of the balloon image
   ## Before moving the balloon check it will not go offscreen
   if pDirection is "down" then
      if the bottom of image "balloon" < (the bottom of graphic "Stage" - stageSize(5)) then
         set the bottom of image "balloon" to the bottom of image "balloon" + stageSize(25)
      end if
   else if pDirection is "up" then
      if the top of image "balloon" > the top of graphic "Stage" + stageSize(5) then
         set the top of image "balloon" to the top of image "balloon" - stageSize(25)
      end if
   else if pDirection is "left" then
      if the left of image "balloon" > the left of graphic "Stage" + stageSize(5) then
         set the left of image "balloon" to the left of image "balloon" - stageSize(25)
      end if
   else if pDirection is "right" then
      set the right of image "balloon" to the right of image "balloon" + stageSize(25)
   end if

   ## Check to see if the balloon has reached the right hand side
   if the left of image "balloon" > the right of graphic "Stage" then
      put false into sMoving
      go to next card
   end if
end arrowKey

on checkForCollision
   ## The intersect function tells you if 2 objects overlap/collide
   ## If the balloon and bird image overlap the game is over
   if intersect(image "balloon",image "bird1","pixels") or intersect(image "balloon",image "bird2","pixels") or intersect(image "balloon",image "bird3","pixels") then
      answer "Game Over"
      go to card "introduction"
   else
      send "moveForeground" to me in 50 milliseconds
   end if
end checkForCollision

on moveForeground
   local tStack
   ## There are 2 foreground images which connect together
   ## These are moved across the screen to create the illusion of movement

   ## Move the birds as if they are flying towards the left
   ## (remaster) A message sent in time may come while another window is in front: useGameStack, in
   ## the script of the stack, makes the names below this stack's, and the last line puts back the
   ## stack that was
   useGameStack
   put the result into tStack
   lock screen
   if sMoving then
      set the left of image "foreground1" to the left of image "foreground1" - stageSize(5)
      set the left of image "foreground2" to the left of image "foreground2" - stageSize(5)
      set the left of image "bird1" to the left of image "bird1" - stageSize(10)
      set the left of image "bird2" to the left of image "bird2" - stageSize(10)
      set the left of image "bird3" to the left of image "bird3" - stageSize(10)

      ## When a foreground image moves completely off screen reset it on the right
      if the right of image "foreground1" < the left of graphic "Stage" then
         set the left of image "foreground1" to the right of image "foreground2"
      end if

      if the right of image "foreground2" < the left of graphic "Stage" then
         ## (remaster) to the right of foreground1: the original put it to the right of itself, over
         ## foreground1, and after a minute a gap opened in the ground
         set the left of image "foreground2" to the right of image "foreground1"
      end if

      ## When a bird image moves completely off screen reset it on the right
      if the right of image "bird1" < the left of graphic "Stage" then
         set the loc of image "bird1" to stageLoc(1034,380)
      end if

      if the right of image "bird2" < the left of graphic "Stage" then
         set the loc of image "bird2" to stageLoc(1034,270)
      end if

      if the right of image "bird3" < the left of graphic "Stage" then
         set the loc of image "bird3" to stageLoc(1034,500)
      end if

      ## Check for collisions between the balloon and birds
      checkForCollision
   end if
   unlock screen
   set the defaultStack to tStack
end moveForeground
@*/

/*@ page4/card
on preOpenCard
   global gName
   put "Congratulations" && gName & ". You have reached the end of your balloon adventure." into field "story"
   ## (remaster) The window lays the card out after this handler: it passes the message on
   pass preOpenCard
end preOpenCard
@*/

/*@ page4/Play Again
## (remaster) Back to the start, to fly again
on mouseUp
   go to card "introduction"
end mouseUp
@*/

/*@ arrow/up
on mouseUp
   arrowKey "up"
end mouseUp
@*/

/*@ arrow/right
on mouseUp
   arrowKey "right"
end mouseUp
@*/

/*@ arrow/down
on mouseUp
   arrowKey "down"
end mouseUp
@*/

/*@ arrow/left
on mouseUp
   arrowKey "left"
end mouseUp
@*/

/*@ Collisions/Play Sound
## (remaster) The sound the game plays when you collect points: the audioclip "hiscore.wav", which is
## in this stack
on mouseUp
   local tError
   try
      play audioclip "hiscore.wav"
   catch tError
      ## (where it cannot be played, the button says so)
      put "No sound here" into field "Play Sound_label"
   end try
end mouseUp
@*/

/*@ snippet/move
-- the balloon's script, on the card "page1"
on mouseUp
   move image "balloon" to the points of graphic "path" in 3 seconds without waiting
end mouseUp

-- in arrowKey, in the script of the card "page2": the up key
else if pDirection is "up" then
   if the top of image "balloon" > the top of graphic "Stage" + stageSize(5) then
      set the top of image "balloon" to the top of image "balloon" - stageSize(25)
   end if
@*/

/*@ snippet/loop
on moveForeground
   lock screen
   if sMoving then
      set the left of image "foreground1" to the left of image "foreground1" - stageSize(5)
      set the left of image "foreground2" to the left of image "foreground2" - stageSize(5)
      if the right of image "foreground1" < the left of graphic "Stage" then
         set the left of image "foreground1" to the right of image "foreground2"
      end if
      send "moveForeground" to me in 50 milliseconds
   end if
   unlock screen
end moveForeground
@*/

/*@ snippet/collide
-- checkForScore, in the script of the card "page2"
if intersect(image "balloon",image "points","pixels") then
   add 1000 to field "score"
   play audioclip "hiscore.wav"
end if
-- checkForCollision, in the script of the card "page3"
if intersect(image "balloon",image "bird1","pixels") or ... then
   answer "Game Over"
   go to card "introduction"
end if
@*/
