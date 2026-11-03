script "OXTExampleBuilder"
-- OXT-Beyond: what every remastered example is built with.
--
-- build-examples.livecodescript starts using this script and Learn's kit
-- (ide/Toolset/palettes/learn/revlearnkit.livecodescript), then each
-- example's own builder calls the handlers here to make its stack: the
-- window (exNewStack), its cards (exAddCards), the letters, buttons and
-- panels on them, and at the end a check of every script (exCheck) and
-- the save (exSave). The stack it makes needs neither: what the kit
-- draws is saved in the stack as graphics, fields and images, and the
-- window's script is frame-runtime.livecodescript, which becomes the
-- script of the group "Frame".
--
-- Every example is one window, 1024 by 640 (a 720p screen holds it with
-- its title bar): a sidebar of its cards, a header with each card's title
-- and tagline, and below the header the card's content, 744 by 512. Each
-- card is one of four kinds:
--
--    front    a front page: what the example is and who made it. It has
--             a star in the sidebar's list, not a number
--    page     a page of words or pictures, numbered, without a stage
--    program  the stage, where the program runs (344 by 512), and beside
--             it the panel of the scripts of the things on the card
--    wide     the stage across the content (744 by 512), and the scripts
--             in a drawer over its right side, which the header's Scripts
--             button opens and Escape shuts
--
-- and the word "keys" after the kind says that the card's arrow keys play
-- its program (they go to the next card on the others). The stage is the
-- graphic "Stage" of the group "Workbench", and the panel is the group
-- "Scripts": both are backgrounds, on the program and wide cards. The
-- window's own controls have names that begin with "frame", "code" or
-- "stage" (but "Stage"), so that a program's controls can be named as its
-- author named them.
--
-- The scripts that go into the stack are in its builder's own script, in
-- blocks that begin with a line "/*@ <key>" and end with a line "@*/",
-- so that they read as they will in the stack, quotes and all; exScript
-- gives a block's text by its key.

constant kWidth = 1024
constant kHeight = 640
constant kSide = 232
-- The header's text, and the content below it
constant kLeft = 256
constant kRight = 1000
constant kTop = 104
constant kBottom = 616
-- The stage, on a program card and on a wide card, and the scripts panel
constant kStage = "256,104,600,616"
constant kStageWide = "256,104,1000,616"
constant kPanel = "616,104,1000,616"
constant kTextInset = 4
-- The letters of the code font (12 pixels) in a line of the scripts panel
constant kCodeRoom = 47

-- The example: its name and colours, and its cards, from exNewStack
local sInfo
-- The script blocks of the builder in use, by key
local sScripts
-- Icons that Learn's kit does not have, from exAddIcon, by name
local sIcons

################################################################################
#
# The window
#

-- Makes the stack and its first card, with the sidebar and the header.
-- pInfo holds:
--    name      the stack's name, and its window's title
--    credit    a line under the name in the sidebar (who made it)
--    icon      the kit's icon on the sidebar's mark
--    accent    the example's colour (r,g,b), and accent2, the mark's
--              gradient's other end
--    cards     a line per card: name|title|tagline|icon|kind, where kind
--              is "front", "page", "program" or "wide", with "keys" after
--              it for a card whose arrow keys play its program
--    noun      what the numbered cards are ("Program"), and nouns, its
--              plural if it is not the noun and an s
--    script    the key of the stack script's block
function exNewStack pInfo
   local tName, tObj
   put pInfo into sInfo
   put pInfo["name"] into tName
   if there is a stack tName then
      delete stack tName
   end if
   create stack tName
   set the defaultStack to tName
   set the rect of stack tName to 120, 80, 120 + kWidth, 80 + kHeight
   set the label of stack tName to tName
   set the resizable of stack tName to false
   set the backgroundColor of stack tName to lkColor("bg")
   -- (every word is sized here as the build draws it, in Helvetica at 12.
   -- Left empty, the stack's font would be its platform's own when it
   -- opens, the IDE's Sans at 13 on Linux, and words sized here would not
   -- fit. Windows draws Helvetica as Arial, and Linux as Nimbus Sans or
   -- Liberation Sans, all with Helvetica's widths)
   set the textFont of stack tName to "Helvetica"
   set the textSize of stack tName to 12
   set the script of stack tName to exScript(pInfo["script"])
   set the name of card 1 of stack tName to exCardInfo(1, "name")
   exBuildFrame
   exBuildFocus
   return the long id of stack tName
end exNewStack

-- An item of a line of the cards' table
function exCardInfo pIndex, pWhat
   local tLine
   put line pIndex of sInfo["cards"] into tLine
   set the itemDelimiter to "|"
   switch pWhat
      case "name"
         return item 1 of tLine
      case "title"
         return item 2 of tLine
      case "tagline"
         return item 3 of tLine
      case "icon"
         return item 4 of tLine
      case "kind"
         return item 5 of tLine
      case "layout"
         -- (a kind of "keys" alone is a program card)
         if word 1 of item 5 of tLine is among the words of "front page program wide" then
            return word 1 of item 5 of tLine
         end if
         return "program"
      case "keys"
         return "keys" is among the words of item 5 of tLine
   end switch
   return empty
end exCardInfo

-- A card's number in the sidebar's list: front cards have none, and the
-- others are numbered from 1
function exCardNumber pIndex
   local tIndex, tNumber
   if exCardInfo(pIndex, "layout") is "front" then
      return empty
   end if
   put 0 into tNumber
   repeat with tIndex = 1 to pIndex
      if exCardInfo(tIndex, "layout") is not "front" then
         add 1 to tNumber
      end if
   end repeat
   return tNumber
end exCardNumber

-- How many cards are numbered
function exNumbered
   local tIndex, tNumber
   put 0 into tNumber
   repeat with tIndex = 1 to the number of lines of sInfo["cards"]
      if exCardInfo(tIndex, "layout") is not "front" then
         add 1 to tNumber
      end if
   end repeat
   return tNumber
end exNumbered

-- The sidebar and the header, in the group "Frame", a background
private command exBuildFrame
   local tObj, tIndex, tHtml, tCount, tNumber, tNames
   get lkGroup("Frame", lkR(0, 0, kWidth, kHeight), empty)
   set the backgroundBehavior of group "Frame" to true
   put lkBox("frameSide", lkR(0, 0, kSide, kHeight), lkColor("side"), 0, "Frame") into tObj
   lkGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", "0," & kHeight
   -- The mark: the example's icon on its colours, its name, who made it
   put lkBox("frameMark", "20,22,56,58", sInfo["accent"], 22, "Frame") into tObj
   lkGradient tObj, sInfo["accent2"] & "|" & sInfo["accent"], "20,22", "56,58"
   lkGlow tObj, sInfo["accent"], 16, 110
   get exIcon("frameMarkIcon", sInfo["icon"], "255,255,255", "28,30,48,50", "Frame")
   put lkLabel("frameName", lkR(66, 21, kSide - 8, 45), sInfo["name"], 18, "255,255,255", "Frame") into tObj
   set the textStyle of tObj to "bold"
   lkEllipsize tObj
   put lkLabel("frameCredit", lkR(66, 45, kSide - 8, 61), sInfo["credit"], 11, lkColor("muted"), "Frame") into tObj
   lkEllipsize tObj

   -- The cards, in a list: a front page has a star, the others numbers
   put the number of lines of sInfo["cards"] into tCount
   repeat with tIndex = 1 to tCount
      if exCardInfo(tIndex, "layout") is "front" then
         put numToCodepoint(9733) into tNumber
      else
         put format("%02d", exCardNumber(tIndex)) into tNumber
      end if
      put "<p><font color=" & quote & "#64748b" & quote & ">" & tNumber & "</font>" & tab & \
            lkEscape(exCardInfo(tIndex, "title")) & "</p>" after tHtml
   end repeat
   -- (the card in front has a pill behind its line, which the runtime
   -- moves, and a bar of the accent at the pill's left)
   put lkBox("frameHi", lkR(8, 84, kSide - 8, 112), lkMix(lkColor("side2"), sInfo["accent"], 0.4), 10, "Frame") into tObj
   put lkBox("frameBar", lkR(8, 90, 12, 106), sInfo["accent"], 2, "Frame") into tObj
   lkGlow tObj, sInfo["accent"], 10, 160
   put lkLabel("frameList", lkR(8, 84, kSide - 8, 84 + 30 * tCount), empty, 13, lkColor("sideInk"), "Frame") into tObj
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 30
   set the margins of tObj to "10,2,2,2"
   set the tabStops of tObj to 34
   set the htmlText of tObj to tHtml
   -- (and the cards' names, a line each in the list's order, for the
   -- runtime: a card the user adds, as a lesson can ask, moves the
   -- numbers of the cards after it, not their names)
   repeat with tIndex = 1 to tCount
      put exCardInfo(tIndex, "name") & return after tNames
   end repeat
   delete the last char of tNames
   set the cFrameCards of group "Frame" to tNames

   -- Back and Next, and where you are
   get exButton("frameBack", 14, kHeight - 104, 32, "Back", "chevron-left", "dark", empty, "Frame", "back", 98)
   get exButton("frameNext", kSide - 112, kHeight - 104, 32, "Next", "chevron-right", "dark", empty, "Frame", "next", 98)
   put lkLabel("frameCount", lkR(0, kHeight - 60, kSide, kHeight - 44), empty, 12, lkColor("muted"), "Frame", "center") into tObj
   set the sharedText of tObj to false
   put lkLabel("frameHint", lkR(0, kHeight - 43, kSide, kHeight - 27), empty, 11, "148,163,184", "Frame", "center") into tObj
   set the sharedText of tObj to false

   -- The header: each card's own title and tagline
   put lkLabel("frameTitle", lkR(kLeft, 16, kRight - 220, 52), empty, 26, lkColor("ink"), "Frame") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   set the sharedText of tObj to false
   put lkLabel("frameTagline", lkR(kLeft, 54, kRight - 140, 72), empty, 13, lkColor("soft"), "Frame") into tObj
   set the dontWrap of tObj to true
   set the sharedText of tObj to false
   get lkBox("frameLine", lkR(kLeft, 80, kLeft + 56, 83), sInfo["accent"], 3, "Frame")
   -- The Scripts button, which a wide card shows: it opens the drawer
   get exButton("frameScripts", kRight - 120, 24, 34, "Scripts", "code", "ghost", sInfo["accent"], "Frame", "scripts", 0)
   set the right of group "frameScripts" to kRight
   set the cShut of group "frameScripts" to the cRest of group "frameScripts"
   set the cOpen of group "frameScripts" to lkMix("255,255,255", sInfo["accent"], 0.16)
   hide group "frameScripts"

   exShareText "Frame", "frameCount,frameHint,frameTitle,frameTagline"
   set the script of group "Frame" to exRuntimeScript()
   set the cAccent of group "Frame" to sInfo["accent"]
   -- (the part of the window that slides from card to card)
   set the cContent of group "Frame" to kSide & ",0," & kWidth & "," & kHeight
end exBuildFrame

-- The group "Focus", a background with a graphic in it that takes the
-- keys when a card opens. Left to itself, the engine gives them to the
-- card's first field that takes typing, and the IDE counts a field opened
-- for typing as a change to the stack: a card with a box to type in would
-- ask to be saved when the window closed, with nothing typed. (A click in
-- the box still opens it for typing, and Tab goes to it.) Neither has a
-- script, so a key goes on to the card, then to the frame, as it does
-- when nothing has the focus; and both are off the card, where no click
-- finds them
private command exBuildFocus
   local tObj
   get lkGroup("Focus", "-20,-20,-10,-10", empty)
   set the backgroundBehavior of group "Focus" to true
   set the traversalOn of group "Focus" to true
   put lkBox("frameFocus", "-20,-20,-10,-10", empty, 0, "Focus") into tObj
   set the showFocusBorder of tObj to false
   set the traversalOn of tObj to true
end exBuildFocus

-- The stage, in the group "Workbench", a background on the program and
-- wide cards; the runtime gives it its rect for the card in front, from
-- the group's custom properties cNarrow and cWide
private command exBuildWorkbench
   local tObj
   get lkGroup("Workbench", lkR(kLeft - 16, kTop - 12, kRight + 16, kBottom + 20), empty)
   set the backgroundBehavior of group "Workbench" to true
   -- (the first control made in a group goes to its top left: this one
   -- is already there)
   get lkBox("stageAnchor", lkR(kLeft - 16, kTop - 12, kLeft - 15, kTop - 11), empty, 0, "Workbench")
   put lkBox("Stage", kStage, "255,255,255", 18, "Workbench") into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 18, 4, 12
   set the cNarrow of group "Workbench" to kStage
   set the cWide of group "Workbench" to kStageWide
end exBuildWorkbench

-- The scripts panel, in the group "Scripts", a background on the program
-- and wide cards: three dots, what it shows, chips for the scripts, the
-- code, and Edit and Copy. Beside the stage of a program card, and over
-- the stage of a wide card, as a drawer
private command exBuildScripts
   local tObj, tLeft, tTop, tRight, tBottom, tIndex
   put item 1 of kPanel into tLeft
   put item 2 of kPanel into tTop
   put item 3 of kPanel into tRight
   put item 4 of kPanel into tBottom
   get lkGroup("Scripts", lkR(tLeft - 16, tTop - 12, tRight + 16, tBottom + 20), empty)
   set the backgroundBehavior of group "Scripts" to true
   get lkBox("codeAnchor", lkR(tLeft - 16, tTop - 12, tLeft - 15, tTop - 11), empty, 0, "Scripts")
   put lkBox("codeBg", kPanel, lkColor("code"), 18, "Scripts") into tObj
   lkShadow tObj, 18, 6, 30
   get lkOval("codeDot1", lkR(tLeft + 18, tTop + 17, tLeft + 28, tTop + 27), "248,113,113", "Scripts")
   get lkOval("codeDot2", lkR(tLeft + 34, tTop + 17, tLeft + 44, tTop + 27), "251,191,36", "Scripts")
   get lkOval("codeDot3", lkR(tLeft + 50, tTop + 17, tLeft + 60, tTop + 27), "52,211,153", "Scripts")
   put lkLabel("codeCaption", lkR(tLeft + 72, tTop + 15, tRight - 16, tTop + 31), "Scripts on this card", 11, "148,163,184", "Scripts") into tObj
   -- (in the middle of the dots, up and down, as a button's label is)
   exMiddle tObj, tTop + 22
   repeat with tIndex = 1 to 5
      exChip "codeChip" & tIndex, tLeft + 16 + (tIndex - 1) * 70, tTop + 42
   end repeat
   set the cChipRest of group "Scripts" to lkColor("side2")
   set the cChipInk of group "Scripts" to lkColor("sideInk")
   put lkLabel("codeRef", lkR(tLeft + 18, tTop + 80, tRight - 16, tTop + 96), empty, 11, "148,163,184", "Scripts") into tObj
   set the dontWrap of tObj to true
   put lkLabel("codeText", lkR(tLeft + 10, tTop + 104, tRight - 12, tBottom - 56), empty, 12, lkColor("codeInk"), "Scripts") into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 18
   -- (a line too long for the panel goes on below, indented)
   set the margins of tObj to "8," & kTextInset & ",8,4"
   set the lockText of tObj to true
   put lkBox("codeThumb", lkR(tRight - 9, tTop + 104, tRight - 4, tTop + 140), "100,116,139", 3, "Scripts") into tObj
   set the blendLevel of tObj to 40
   hide tObj
   -- Edit and Copy
   get exButton("codeEdit", tLeft + 16, tBottom - 44, 30, "Edit script", "pencil", "dark", empty, "Scripts", "edit", 0)
   get exButton("codeCopy", tLeft + 136, tBottom - 44, 30, "Copy", "copy", "dark", empty, "Scripts", "copy", 0)
   set the left of group "codeCopy" to the right of group "codeEdit" + 8
   exShareText "Scripts", empty
end exBuildScripts

-- Moves the label pObj (an lkLabel of one line) up or down so that its
-- letters are in the middle of pMiddle, as a button's label is: for a
-- number in a circle, a caption beside a window's dots, a word in a pill.
-- (An lkLabel's text sits at the top of its rect, so a rect centred on a
-- shape puts the letters above its middle.)
command exMiddle pObj, pMiddle
   set the top of pObj to pMiddle - (the formattedHeight of pObj + kTextInset) div 2
end exMiddle

-- A field made in a group has text of its own on each card: these are
-- the same on every card, but for those named in pPerCard
private command exShareText pGroup, pPerCard
   local tIndex, tObj
   repeat with tIndex = 1 to the number of controls of group pGroup
      put the long id of control tIndex of group pGroup into tObj
      if word 1 of tObj is "field" and the short name of tObj is not among the items of pPerCard then
         set the sharedText of tObj to true
      end if
   end repeat
end exShareText

-- A chip in the scripts panel: the runtime gives it its label and width
private command exChip pName, pLeft, pTop
   local tObj
   get lkGroup(pName, lkR(pLeft, pTop, pLeft + 62, pTop + 26), "Scripts")
   put lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + 62, pTop + 26), lkColor("side2"), 13, pName) into tObj
   put lkLabel(pName & "_label", lkR(pLeft + 12, pTop + 4, pLeft + 300, pTop + 22), "chip", 12, lkColor("sideInk"), pName) into tObj
   set the dontWrap of tObj to true
   set the width of tObj to the formattedWidth of tObj + 4
   set the cRest of group pName to lkColor("side2")
   set the cLit of group pName to lkColor("sideLine")
   set the cAction of group pName to "chip" && char 9 to -1 of pName
   hide group pName
end exChip

-- The script of the group "Frame": frame-runtime.livecodescript, without
-- its first line (the script-only stack's name)
private function exRuntimeScript
   local tPath, tText
   set the itemDelimiter to slash
   put item 1 to -2 of the filename of stack "OXTExampleBuilder" & "/frame-runtime.livecodescript" into tPath
   put url ("file:" & tPath) into tText
   if tText is empty then
      throw "cannot read " & tPath
   end if
   delete line 1 of tText
   return tText
end exRuntimeScript

-- Makes the other cards, after the first, each with the frame; places
-- the stage and the scripts panel on the program and wide cards; and puts
-- each card's title, tagline, count and hint into the frame's fields on
-- it. Each card's kind goes into its custom property cLayout, for the
-- runtime
command exAddCards
   local tCount, tIndex, tName, tNoun, tNouns, tFirst, tLayout, tNumbered
   put the number of lines of sInfo["cards"] into tCount
   put sInfo["noun"] into tNoun
   put sInfo["nouns"] into tNouns
   if tNouns is empty then
      put tNoun & "s" into tNouns
   end if
   repeat with tIndex = 2 to tCount
      go card (tIndex - 1)
      create card exCardInfo(tIndex, "name")
   end repeat
   -- (the stage and the panel are made on the first card that has them,
   -- and placed on the others)
   put empty into tFirst
   repeat with tIndex = 1 to tCount
      put exCardInfo(tIndex, "layout") into tLayout
      if tLayout is not "program" and tLayout is not "wide" then
         next repeat
      end if
      if tFirst is empty then
         put tIndex into tFirst
         go card tIndex
         exBuildWorkbench
         exBuildScripts
      else
         place group "Workbench" of card tFirst onto card tIndex
         place group "Scripts" of card tFirst onto card tIndex
      end if
   end repeat
   put exNumbered() into tNumbered
   repeat with tIndex = 1 to tCount
      put exCardInfo(tIndex, "name") into tName
      put exCardInfo(tIndex, "layout") into tLayout
      set the cLayout of card tName to tLayout
      put exCardInfo(tIndex, "title") into field "frameTitle" of card tName
      put exCardInfo(tIndex, "tagline") into field "frameTagline" of card tName
      if tLayout is not "front" then
         put tNoun && exCardNumber(tIndex) && "of" && tNumbered into field "frameCount" of card tName
      else if tNumbered is 1 then
         put "1" && tolower(tNoun) into field "frameCount" of card tName
      else
         put tNumbered && tolower(tNouns) into field "frameCount" of card tName
      end if
      if exCardInfo(tIndex, "keys") then
         put "the arrow keys play this card" into field "frameHint" of card tName
      else
         put "or use the arrow keys" into field "frameHint" of card tName
      end if
   end repeat
   go card 1
end exAddCards

################################################################################
#
# What goes on the cards
#

-- A button: a rounded box with an icon and a label, that lights up when
-- the pointer is over it. pAction is what the frame does when it is
-- clicked (the frame's cAction); with no action, the group's own script
-- does it. Returns its width.
function exButton pName, pLeft, pTop, pHeight, pLabel, pIcon, pStyle, pAccent, pGroup, pAction, pMinWidth
   local tSize, tLabel, tLabelWidth, tIconSize, tGap, tWidth, tX, tMid, tObj, tRest, tLit, tLine, tInk, tIconInk, tTop
   put 14 into tSize
   if pStyle is "chip" then
      put 12 into tSize
   end if
   get lkGroup(pName, lkR(pLeft, pTop, pLeft + 10, pTop + pHeight), pGroup)
   put lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + 10, pTop + pHeight), "255,255,255", pHeight, pName) into tObj
   put lkLabel(pName & "_label", lkR(pLeft, pTop, pLeft + 600, pTop + pHeight), pLabel, tSize, "0,0,0", pName) into tLabel
   set the dontWrap of tLabel to true
   put the formattedWidth of tLabel into tLabelWidth
   if pIcon is empty then
      put 0 into tIconSize
      put 0 into tGap
   else
      put 16 into tIconSize
      put 8 into tGap
   end if
   put max(pMinWidth, tLabelWidth + tIconSize + tGap + 32) into tWidth
   set the rect of group pName to pLeft, pTop, pLeft + tWidth, pTop + pHeight
   set the rect of tObj to pLeft, pTop, pLeft + tWidth, pTop + pHeight
   switch pStyle
      case "primary"
         put pAccent into tRest
         put lkMix(pAccent, "255,255,255", 0.16) into tLit
         put "255,255,255" into tInk
         put tInk into tIconInk
         break
      case "ghost"
         put lkDarkLiteral("255,255,255", "fill") into tRest
         put lkMix("255,255,255", pAccent, 0.08) into tLit
         put lkColor("line") into tLine
         put lkColor("ink") into tInk
         put pAccent into tIconInk
         break
      case "light"
         put lkDarkLiteral("255,255,255", "fill") into tRest
         put lkMix("255,255,255", pAccent, 0.14) into tLit
         put lkMix(pAccent, lkColor("ink"), 0.2) into tInk
         put pAccent into tIconInk
         break
      default
         -- "dark", on the sidebar and the scripts panel
         put lkColor("side2") into tRest
         put lkColor("sideLine") into tLit
         put lkColor("sideLine") into tLine
         put lkColor("sideInk") into tInk
         put tInk into tIconInk
   end switch
   set the backgroundColor of tObj to tRest
   if tLine is not empty then
      lkBorder tObj, tLine
   end if
   put pLeft + (tWidth - tLabelWidth - tIconSize - tGap) div 2 into tX
   put pTop + pHeight div 2 into tMid
   if pIcon is not empty then
      get exIcon(pName & "_icon", pIcon, tIconInk, tX & "," & (tMid - 8) & "," & (tX + 16) & "," & (tMid + 8), pName)
   end if
   set the textColor of tLabel to tInk
   put tMid - (the formattedHeight of tLabel + kTextInset) div 2 into tTop
   set the rect of tLabel to tX + tIconSize + tGap, tTop, \
         tX + tIconSize + tGap + tLabelWidth + 4, tTop + the formattedHeight of tLabel + kTextInset + 4
   set the cRest of group pName to tRest
   set the cLit of group pName to tLit
   if pAction is not empty then
      set the cAction of group pName to pAction
   end if
   return tWidth
end exButton

-- A letter: a square tile in a colour, with its letter in white. Its
-- colour is kept in its custom property cColor, for a program that puts
-- it back
function exLetter pName, pLetter, pLeft, pTop, pColor
   local tObj, tSpace
   create field pName
   put it into tObj
   set the lockText of tObj to true
   set the traversalOn of tObj to false
   set the autoHilite of tObj to false
   set the showFocusBorder of tObj to false
   set the showBorder of tObj to false
   set the opaque of tObj to true
   set the backgroundColor of tObj to pColor
   set the cColor of tObj to pColor
   set the textColor of tObj to lkDarkLiteral("255,255,255", "ink")
   set the textSize of tObj to 34
   set the textStyle of tObj to "bold"
   set the textAlign of tObj to "center"
   set the dontWrap of tObj to true
   set the margins of tObj to 0
   set the text of tObj to pLetter
   set the rect of tObj to pLeft, pTop, pLeft + 60, pTop + 64
   -- (the letter in the middle of the tile, up and down)
   put max(0, (64 - the formattedHeight of tObj) div 2) into tSpace
   set the margins of tObj to "0," & tSpace & ",0,0"
   set the rect of tObj to pLeft, pTop, pLeft + 60, pTop + 64
   set the cStartLoc of tObj to the loc of tObj
   lkShadow tObj, 14, 5, 35
   return tObj
end exLetter

-- A white panel on the content, with a soft shadow
function exPanel pName, pRect, pGroup
   local tObj
   put lkBox(pName, pRect, "255,255,255", 16, pGroup) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 16, 3, 10
   return tObj
end exPanel

-- The front page's banner: the example's colours, soft lights and
-- sparkles, a word above the title, the title and a paragraph
command exHero pRect, pColors, pEyebrow, pTitle, pText
   local tObj, tBg, tIndex, tLeft, tTop, tRight, tBottom, tW, tH, tSize, tStars, tTitleRight, tTextRight, tX, tY, tFrom
   put item 1 of pRect into tLeft
   put item 2 of pRect into tTop
   put item 3 of pRect into tRight
   put item 4 of pRect into tBottom
   put tRight - tLeft into tW
   put tBottom - tTop into tH
   get lkGroup("hero", pRect, empty)
   put lkBox("hero_bg", pRect, lkColor("indigo"), 22, "hero") into tBg
   lkGradient tBg, pColors, tLeft & "," & tTop, tRight & "," & tBottom
   repeat with tIndex = 1 to 4
      put item tIndex of "240,170,200,130" into tSize
      put lkOval("hero_glow" & tIndex, lkR(0, 0, tSize, tSize), "255,255,255", "hero") into tObj
      lkGlowFill tObj, "255,255,255", item tIndex of "70,55,60,45"
      set the blendLevel of tObj to 40
      set the loc of tObj to round(tLeft + tW * item tIndex of "0.74,0.92,0.55,0.12"), \
            round(tTop + tH * item tIndex of "0.18,0.9,1.0,0.05")
      lkGlowCentre tObj
   end repeat
   repeat with tIndex = 1 to 6
      put lkBox("hero_star" & tIndex, lkR(0, 0, 10, 10), "255,255,255", 0, "hero") into tObj
      set the style of tObj to "polygon"
      set the points of tObj to lkSparklePoints(0, 0, item tIndex of "9,6,11,5,7,8")
      set the blendLevel of tObj to item tIndex of "25,50,35,60,30,45"
      set the loc of tObj to round(tLeft + tW * item tIndex of "0.66,0.72,0.82,0.9,0.95,0.78"), \
            round(tTop + tH * item tIndex of "0.26,0.66,0.34,0.72,0.2,0.86")
      put tObj into tStars[tIndex]
   end repeat
   put lkLabel("hero_eyebrow", lkR(tLeft + 32, tTop + 28, tRight - 32, tTop + 44), pEyebrow, 11, "255,255,255", "hero") into tObj
   set the textStyle of tObj to "bold"
   set the blendLevel of tObj to 25
   put lkLabel("hero_title", lkR(tLeft + 32, tTop + 50, tRight - 32, tTop + 88), pTitle, 28, "255,255,255", "hero") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   put tLeft + 32 + measureText(pTitle, tObj) into tTitleRight
   put lkLabel("hero_text", lkR(tLeft + 32, tTop + 94, tLeft + min(tW - 64, 560) + 32, tBottom - 16), pText, 14, "255,255,255", "hero") into tObj
   set the blendLevel of tObj to 8
   put the right of tObj into tTextRight
   -- (a sparkle on the title or on the paragraph would sit on a letter:
   -- those move to the right of the words, where there is room beside
   -- the others, or are hidden)
   repeat with tIndex = 1 to 6
      put item 1 of the loc of tStars[tIndex] into tX
      put item 2 of the loc of tStars[tIndex] into tY
      put 0 into tFrom
      if tY > tTop + 88 and tX < tTextRight + 12 then
         put tTextRight + 24 into tFrom
      else if tY > tTop + 40 and tX < tTitleRight + 14 then
         put tTitleRight + 22 into tFrom
      end if
      if tFrom > 0 then
         hide tStars[tIndex]
         repeat with tX = tFrom to tRight - 16 step 26
            if exHeroClear(tStars, tX, tY) then
               set the loc of tStars[tIndex] to tX, tY
               show tStars[tIndex]
               exit repeat
            end if
         end repeat
      end if
   end repeat
end exHero

-- Whether a sparkle at pX,pY is 24 pixels or more from the hero's other
-- sparkles that show
private function exHeroClear pStars, pX, pY
   local tStar
   repeat for each element tStar in pStars
      if the visible of tStar and abs(item 1 of the loc of tStar - pX) < 24 \
            and abs(item 2 of the loc of tStar - pY) < 24 then
         return false
      end if
   end repeat
   return true
end exHeroClear

-- A tile on the front page for each numbered card: its icon on a tint
-- of the accent, its number and its title; a click goes to its card
command exProgramTiles pTop, pColumns, pHeight, pGap
   local tCount, tWidth, tIndex, tSlot, tCol, tRow, tX, tY, tName, tObj, tAccent
   put sInfo["accent"] into tAccent
   put the number of lines of sInfo["cards"] into tCount
   put (kRight - kLeft - (pColumns - 1) * pGap) div pColumns into tWidth
   put 0 into tSlot
   repeat with tIndex = 1 to tCount
      if exCardInfo(tIndex, "layout") is "front" then
         next repeat
      end if
      add 1 to tSlot
      put (tSlot - 1) mod pColumns into tCol
      put (tSlot - 1) div pColumns into tRow
      put kLeft + tCol * (tWidth + pGap) into tX
      put pTop + tRow * (pHeight + pGap) into tY
      put "tile" & tSlot into tName
      get lkGroup(tName, lkR(tX, tY, tX + tWidth, tY + pHeight), empty)
      put lkBox(tName & "_bg", lkR(tX, tY, tX + tWidth, tY + pHeight), "255,255,255", 14, tName) into tObj
      lkBorder tObj, lkColor("line")
      lkShadow tObj, 10, 2, 8
      put lkBox(tName & "_iconBg", lkR(tX + 12, tY + 12, tX + 52, tY + pHeight - 12), lkMix("255,255,255", tAccent, 0.12), 12, tName) into tObj
      get exIcon(tName & "_icon", exCardInfo(tIndex, "icon"), tAccent, lkR(tX + 22, tY + pHeight div 2 - 10, tX + 42, tY + pHeight div 2 + 10), tName)
      put lkLabel(tName & "_number", lkR(tX + 64, tY + 13, tX + tWidth - 8, tY + 27), format("%02d", tSlot), 11, exTileNumberInk(), tName) into tObj
      set the textStyle of tObj to "bold"
      put lkLabel(tName & "_title", lkR(tX + 64, tY + 29, tX + tWidth - 8, tY + 49), exCardInfo(tIndex, "title"), 14, lkColor("ink"), tName) into tObj
      set the textStyle of tObj to "bold"
      lkEllipsize tObj
      set the cRest of group tName to lkDarkLiteral("255,255,255", "fill")
      set the cLit of group tName to lkMix("255,255,255", tAccent, 0.07)
      set the cAction of group tName to "go" && exCardInfo(tIndex, "name")
   end repeat
end exProgramTiles

-- A tile's number: the page's muted grey in the dark, where it reads, and
-- a darker grey on the light tile, where that one does not (2.6 to 1)
private function exTileNumberInk
   if lkDark() then
      return lkColor("muted")
   end if
   return "100,116,139"
end exTileNumberInk

################################################################################
#
# Icons
#

-- Adds an icon that Learn's kit does not have, for exIcon and so for
-- exButton, exProgramTiles and the sidebar's mark (after exUseScripts,
-- and before exNewStack for the mark): pPaths is what goes
-- inside a Lucide icon's <svg> element (its paths, circles and lines,
-- as lucide-static's file of it has them), drawn 24 by 24.
--
-- The icons the builders add are Lucide's (lucide-static 0.469.0), as
-- the kit's are, under Lucide's licence:
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
command exAddIcon pName, pPaths
   put pPaths into sIcons[pName]
end exAddIcon

-- An icon, as lkIcon draws it: from the icons added with exAddIcon, or
-- else from the kit's
function exIcon pName, pIcon, pColor, pRect, pGroup
   local tHex, tSvg
   if pIcon is not among the keys of sIcons then
      return lkIcon(pName, pIcon, pColor, pRect, pGroup)
   end if
   put lkHex(pColor) into tHex
   put "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" & tHex & \
         "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>" & \
         sIcons[pIcon] & "</svg>" into tSvg
   replace "currentColor" with tHex in tSvg
   return lkDrawing(pName, tSvg, pRect, pGroup)
end exIcon

################################################################################
#
# Scripts
#

-- Reads the script blocks of a builder's script into sScripts. Each
-- builder calls it first, so it forgets the last builder's icons too
command exUseScripts pText
   local tKey, tLine, tBlock, tIn
   put empty into sScripts
   put empty into sIcons
   put false into tIn
   repeat for each line tLine in pText
      if not tIn and word 1 of tLine is "/*@" then
         put word 2 to -1 of tLine into tKey
         put empty into tBlock
         put true into tIn
      else if tIn and word 1 to -1 of tLine is "@*/" then
         if the last char of tBlock is return then
            delete the last char of tBlock
         end if
         put tBlock into sScripts[tKey]
         put false into tIn
      else if tIn then
         put tLine & return after tBlock
      end if
   end repeat
end exUseScripts

function exScript pKey
   if pKey is not among the keys of sScripts then
      throw "no script block " & quote & pKey & quote
   end if
   return sScripts[pKey]
end exScript

-- Compiles the script of every object of a stack, with variables to be
-- declared (the IDE's "strict compilation mode"), and returns a line for
-- each that does not compile
function exCheck pStack
   local tErrors, tScratch, tCard, tCtl, tObj
   create stack "exCheckScratch"
   create button "scratch" in card 1 of stack "exCheckScratch"
   put it into tScratch
   set the explicitVariables to true
   put exCheckOne(tScratch, the long id of stack pStack) after tErrors
   repeat with tCard = 1 to the number of cards of stack pStack
      put exCheckOne(tScratch, the long id of card tCard of stack pStack) after tErrors
      repeat with tCtl = 1 to the number of controls of card tCard of stack pStack
         put exCheckOne(tScratch, the long id of control tCtl of card tCard of stack pStack) after tErrors
      end repeat
   end repeat
   set the explicitVariables to false
   delete stack "exCheckScratch"
   return tErrors
end exCheck

private function exCheckOne pScratch, pObj
   local tResult
   if the script of pObj is empty then
      return empty
   end if
   set the script of pScratch to the script of pObj
   put the result into tResult
   set the script of pScratch to empty
   if tResult is empty then
      return empty
   end if
   return the name of pObj && "line" && item 2 of line 1 of tResult & ":" && \
         line (item 1 of line 1 of tResult) of the scriptParsingErrors && \
         "(near" && item 4 to -1 of line 1 of tResult & ")" & return
end exCheckOne

-- Warns, with a line "WARN" on stdout, of each word of a card's or a
-- control's script that the scripts panel cannot wrap: its field breaks a
-- line only at a space, so a longer word runs out of sight. (The window's
-- own groups are left out: the panel does not show their scripts.)
command exWarnLongWords pStack
   local tCard, tCtl, tObj, tLine
   repeat with tCard = 1 to the number of cards of stack pStack
      put the long id of card tCard of stack pStack into tObj
      repeat for each line tLine in exLongWords(the script of tObj)
         write "WARN" && the name of tObj && tLine & return to stdout
      end repeat
      repeat with tCtl = 1 to the number of controls of card tCard of stack pStack
         put the long id of control tCtl of card tCard of stack pStack into tObj
         if exInFrame(tObj) then
            next repeat
         end if
         repeat for each line tLine in exLongWords(the script of tObj)
            write "WARN" && the name of tObj && "of card" && tCard && tLine & return to stdout
         end repeat
      end repeat
   end repeat
end exWarnLongWords

-- Is it one of the window's own groups, Frame, Workbench and Scripts (and
-- a Learn stack's Learn), or in one?
private function exInFrame pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if word 1 of tObj is "group" and the short name of tObj is among the items of "Frame,Workbench,Scripts,Learn" then
         return true
      end if
      put the long owner of tObj into tObj
   end repeat
   return false
end exInFrame

-- The words of a script longer than their room in the panel, as lines
-- "line <n>: <word>". A line of the panel holds kCodeRoom letters of the
-- code font; a line's first word has that less its indent, and a word
-- after it 3 less again, as the line may go on below
private function exLongWords pScript
   local tLine, tNumber, tIndent, tWord, tFirst, tRoom, tOut
   put 0 into tNumber
   set the itemDelimiter to space
   repeat for each line tLine in pScript
      add 1 to tNumber
      put 0 into tIndent
      repeat while char tIndent + 1 of tLine is space
         add 1 to tIndent
      end repeat
      put true into tFirst
      repeat for each item tWord in char tIndent + 1 to -1 of tLine
         if tWord is empty then
            next repeat
         end if
         if tFirst then
            put kCodeRoom - tIndent into tRoom
         else
            put kCodeRoom - tIndent - 3 into tRoom
         end if
         if the number of chars of tWord > tRoom then
            put "line" && tNumber & ":" && tWord & return after tOut
         end if
         put false into tFirst
      end repeat
   end repeat
   set the itemDelimiter to comma
   return tOut
end exLongWords

-- Warns, with a line "WARN web" on stdout, of each field or button whose
-- words fit in the build's Helvetica but not in Droid Sans: a browser has
-- no other font (the web engine's fonts are those of
-- engine/rsrc/emscripten-standalone-template), and draws every font of a
-- stack in it. The build's engine can measure Droid Sans only when it is
-- installed where it looks for fonts (on Linux, ~/.fonts). (A field is
-- measured on its card, open: elsewhere its words measure nothing)
command exWarnWebFit pStack
   local tCard, tIndex, tObj
   if "Droid Sans" is not among the lines of the fontNames then
      write "NOTE Droid Sans, the web's font, is not installed: no word is checked for the web" & return to stdout
      exit exWarnWebFit
   end if
   lock messages
   repeat with tCard = 1 to the number of cards of stack pStack
      go card tCard of stack pStack
      repeat with tIndex = 1 to the number of fields of card tCard of stack pStack
         put the long id of field tIndex of card tCard of stack pStack into tObj
         -- (a field that scrolls has more words than room on purpose)
         if the text of tObj is not empty and not the vScrollbar of tObj and not the hScrollbar of tObj then
            exWebFitOne tObj, tCard, line 1 of the text of tObj
         end if
      end repeat
      repeat with tIndex = 1 to the number of buttons of card tCard of stack pStack
         put the long id of button tIndex of card tCard of stack pStack into tObj
         if the showName of tObj and the label of tObj is not empty then
            exWebFitOne tObj, tCard, the label of tObj
         else if the showName of tObj and the short name of tObj is not empty then
            exWebFitOne tObj, tCard, the short name of tObj
         end if
      end repeat
   end repeat
   unlock messages
end exWarnWebFit

private command exWebFitOne pObj, pCard, pWords
   local tFont, tFit, tWeb
   put the textFont of pObj into tFont
   put exNeeds(pObj) into tFit
   set the textFont of pObj to "Droid Sans"
   put exNeeds(pObj) into tWeb
   set the textFont of pObj to tFont
   if item 1 of tWeb > item 2 of tFit and item 1 of tFit <= item 2 of tFit then
      write "WARN web" && the name of pObj && "of card" && pCard & ":" && item 1 of tWeb && \
            "needed," && item 2 of tFit && "there:" && pWords & return to stdout
   end if
end exWebFitOne

-- What a field's or a button's words need, and the room it has: across,
-- for a line that does not wrap, and down for one that does
private function exNeeds pObj
   if word 1 of pObj is "button" or the dontWrap of pObj then
      return the formattedWidth of pObj & comma & the width of pObj
   end if
   return the formattedHeight of pObj & comma & the height of pObj
end exNeeds

-- Saves the stack, on its first card. The scripts panel goes in front of
-- what each card has, so that a wide card's drawer covers its stage
command exSave pStack, pPath
   local tFolder, tCard
   exWarnLongWords pStack
   set the itemDelimiter to slash
   put item 1 to -2 of pPath into tFolder
   set the itemDelimiter to comma
   if there is no folder tFolder then
      create folder tFolder
   end if
   -- (a background is relayered on the card in front: named on another
   -- card, the one in front is moved to that card)
   lock messages
   repeat with tCard = 1 to the number of cards of stack pStack
      go card tCard of stack pStack
      if there is a group "Scripts" then
         relayer group "Scripts" to front of this card
      end if
   end repeat
   exWarnWebFit pStack
   go card 1 of stack pStack
   unlock messages
   save stack pStack as pPath
   if the result is not empty then
      throw "cannot save " & pPath & ": " & the result
   end if
end exSave

################################################################################
#
# Learn stacks: lessons in an extension OXT-Beyond has built in
#
# A "Learn <extension>" example (learn-sodiumxt and the others) teaches one
# of the xTalk Suite's extensions, a card a lesson. Its cards are "page"
# cards of the window above, and on each the group "Learn" (exLearnKit), a
# background whose script is learn-runtime.livecodescript, shows one of
# three halves, by the card's custom property cLearn:
#
#    front      the front page's status panel: whether the extension is
#               loaded, and its version (the stack's cProbe, an expression
#               such as "sxVersion()", gives it)
#    lesson     "In plain words", the calls the lesson makes, its script
#               in the code panel with Run, Copy and Reset, and the field
#               "Result" that the script writes to
#    reference  every handler of the extension, searchable, each with its
#               page
#
# A lesson's words, script and expected result are blocks of its builder:
# "<card>/words" (paragraphs, a blank line between; a line that begins
# "- " is a point of a list; `code` and **bold**), "<card>/try" (the
# script, a mouseUp handler that puts its answer into field "Result") and
# "<card>/expect" (a regular expression the field "Result" must match once
# the script has run, which the tests check). The pages of the reference
# are the IDE's Dictionary's (exLearnDocs reads them from the install the
# build runs in), with links to the other handlers they name and to the
# lessons that use each one.

-- Where the halves go, on the content of a card (kLeft..kRight, kTop..kBottom)
constant kLearnWords = "256,104,540,388"
constant kLearnCalls = "256,398,540,486"
constant kLearnOut = "256,496,540,616"
constant kLearnCode = "552,104,1000,616"
-- The letters a line of a lesson's script may have: the code panel holds
-- 58 of the code font at 11 pixels (7 pixels a letter, as Linux draws
-- them), and a longer line would go on below itself
constant kLearnCodeRoom = 58
constant kLearnStatus = "823,492,1000,616"

-- The Dictionary's entries of the extension, by the handler's name in lower
-- case (the entry, as JSONImport reads it), the names in their order, the
-- library each came from, and the lessons that use each, by name in lower
-- case (lines of card names)
local sLearnDocs, sLearnNames, sLearnUsedIn
-- What does not fit, a line each, for the build to say all at once
local sLearnProblems

-- Reads the Dictionary's entries of the libraries pLibraries (their ids,
-- comma separated, such as "org.openxtalk.library.sodium"), from the
-- install the build runs in (or the one in OXT_INSTALL)
command exLearnDocs pLibraries
   local tInstall, tFolder, tLibrary, tText, tEntries, tIndex, tEntry, tKey, tNames, tMain
   put $OXT_INSTALL into tInstall
   if tInstall is empty then
      put the engine folder into tInstall
   end if
   put tInstall & "/Documentation/html_viewer/resources/data/api_extensions/livecode_script" into tFolder
   exLearnJson tInstall
   put empty into sLearnDocs
   put empty into sLearnNames
   put empty into sLearnUsedIn
   put empty into sLearnProblems
   repeat for each item tLibrary in pLibraries
      put url ("file:" & tFolder & "/" & tLibrary & ".js") into tText
      if tText is empty then
         throw "no Dictionary entries for " & tLibrary & " in " & tFolder
      end if
      put JSONImport("[" & textDecode(textEncode(tText, "native"), "utf-8") & "]") into tEntries
      put empty into tNames
      repeat with tIndex = 1 to the number of elements of tEntries
         put tEntries[tIndex] into tEntry
         if tEntry["type"] is "library" then
            next repeat
         end if
         put tolower(tEntry["display name"]) into tKey
         put tLibrary into tEntry["from"]
         put tEntry into sLearnDocs[tKey]
         put tEntry["display name"] & return after tNames
      end repeat
      sort lines of tNames
      put tNames after sLearnNames
   end repeat
   delete the last char of sLearnNames
   if sLearnNames is empty then
      throw "no handlers in " & pLibraries
   end if
end exLearnDocs

-- JSONImport, from the install's JSON library, unless it is loaded
private command exLearnJson pInstall
   local tFolder
   if "com.livecode.library.json" is among the lines of the loadedExtensions then
      exit exLearnJson
   end if
   put pInstall & "/Extensions/com.livecode.library.json" into tFolder
   load extension from file (tFolder & "/module.lcm") with resource path tFolder
   if the result is not empty then
      throw "cannot load the JSON library: " & the result
   end if
end exLearnJson

-- The accent as words and links are drawn in it: lighter on the dark
-- page, where the accent itself is too dark to read; on either, as far
-- from the page as text must be to be read (exLearnReadable)
function exLearnInk
   if lkDark() then
      return exLearnInkDark()
   end if
   return exLearnAccent()
end exLearnInk

-- The accent the lessons' words, links and buttons are in on the light
-- page: the extension's own, darkened as much as it takes for its words on
-- white, and white words on it (the Run button), to be read
function exLearnAccent
   return exLearnReadable(sInfo["accent"], "255,255,255")
end exLearnAccent

-- The accent of words and links on the dark page (the lesson's panel)
function exLearnInkDark
   return exLearnReadable(lkMix(sInfo["accent"], "255,255,255", 0.45), exLearnPanelDark())
end exLearnInkDark

-- The dark panel the lessons' words are on, whichever look is building
private function exLearnPanelDark
   return "30,41,59"
end exLearnPanelDark

-- The colour pInk ("r,g,b"), moved towards black on a light pBg or white
-- on a dark one, in small steps, until the two are 4.5 to 1 apart (the
-- WCAG's ratio for text; 4.6 here, for rounding): unchanged if it already
-- is. Every colour of a word that the Learn kit chooses goes through this
function exLearnReadable pInk, pBg
   local tToward, tStep, tMixed, tIndex
   if exLearnLuminance(pBg) > 0.18 then
      put "0,0,0" into tToward
   else
      put "255,255,255" into tToward
   end if
   put pInk into tMixed
   repeat with tStep = 1 to 20
      if exLearnContrast(tMixed, pBg) >= 4.6 then
         exit repeat
      end if
      put empty into tMixed
      repeat with tIndex = 1 to 3
         put round(item tIndex of pInk + (item tIndex of tToward - item tIndex of pInk) * tStep / 20) & comma after tMixed
      end repeat
      delete the last char of tMixed
   end repeat
   return tMixed
end exLearnReadable

-- How far apart two colours are to the eye, as the WCAG has it: 1 (the
-- same) to 21 (black and white)
function exLearnContrast pFirst, pSecond
   local tLumA, tLumB
   put exLearnLuminance(pFirst) into tLumA
   put exLearnLuminance(pSecond) into tLumB
   return (max(tLumA, tLumB) + 0.05) / (min(tLumA, tLumB) + 0.05)
end exLearnContrast

-- A colour's relative luminance (the WCAG's): 0 black to 1 white
function exLearnLuminance pColor
   local tSum, tChannel, tIndex
   put 0 into tSum
   repeat with tIndex = 1 to 3
      put (item tIndex of pColor) / 255 into tChannel
      if tChannel <= 0.03928 then
         put tChannel / 12.92 into tChannel
      else
         put ((tChannel + 0.055) / 1.055) ^ 2.4 into tChannel
      end if
      add tChannel * item tIndex of "0.2126,0.7152,0.0722" to tSum
   end repeat
   return tSum
end exLearnLuminance

-- The grey of the lessons' and the pages' small words (CALLS, a page's
-- headings): readable on white, and on the dark panel (learn-runtime puts
-- the dark one in the pages, which are built once, for the light one)
constant kLearnGreyLight = "#64748b"
constant kLearnGreyDark = "#94a3b8"
function exLearnGrey
   if lkDark() then
      return kLearnGreyDark
   end if
   return kLearnGreyLight
end exLearnGrey

-- The group "Learn", with its three halves, on the card pCard (where it
-- is made: the front page) and placed on the cards pOthers (the lessons and
-- the Reference card)
--    pName   the extension's name, as the lessons say it
--    pProbe  an expression that gives its version, empty if it is not loaded
--    pLoad   how a test loads it without the IDE, a line each: "lcb|<folder in
--            the install's Extensions>|<native library's name>" or
--            "lcs|<folder>", in the order they load
command exLearnKit pCard, pOthers, pName, pProbe, pLoad
   local tObj, tAccent, tName, tL, tT, tR, tB, tWidth
   put exLearnAccent() into tAccent
   go card pCard
   get lkGroup("Learn", lkR(kLeft - 16, kTop - 12, kRight + 16, kBottom + 20), empty)
   set the backgroundBehavior of group "Learn" to true
   get lkBox("learnAnchor", lkR(kLeft - 16, kTop - 12, kLeft - 15, kTop - 11), empty, 0, "Learn")

   -- The front page's status panel
   get lkGroup("frontPart", kLearnStatus, "Learn")
   get exPanel("learnStatusBg", kLearnStatus, "frontPart")
   put item 1 of kLearnStatus into tL
   put item 2 of kLearnStatus into tT
   put item 3 of kLearnStatus into tR
   put item 4 of kLearnStatus into tB
   get lkBox("learnStatusIconBg", lkR(tL + 16, tT + 16, tL + 52, tT + 52), lkMix("255,255,255", tAccent, 0.13), 12, "frontPart")
   get exIcon("learnStatusIcon", "check", tAccent, lkR(tL + 24, tT + 24, tL + 44, tT + 44), "frontPart")
   put lkLabel("learnStatus", lkR(tL + 16, tT + 62, tR - 14, tB - 8), empty, 12, lkColor("soft"), "frontPart") into tObj

   -- A lesson
   get lkGroup("lessonPart", lkR(kLeft - 16, kTop - 12, kRight + 16, kBottom + 20), "Learn")
   get lkBox("lessonAnchor", lkR(kLeft - 16, kTop - 12, kLeft - 15, kTop - 11), empty, 0, "lessonPart")
   exLearnHead "lessonWordsHead", kLearnWords, "IN PLAIN WORDS", empty
   put lkLabel("lessonWords", lkR(item 1 of kLearnWords + 16, item 2 of kLearnWords + 32, item 3 of kLearnWords - 14, item 4 of kLearnWords - 10), \
         empty, 13, lkColor("text"), "lessonPart") into tObj
   -- (the calls, after the word CALLS, a link each)
   get exPanel("lessonCallsBg", kLearnCalls, "lessonPart")
   put lkLabel("lessonCalls", lkR(item 1 of kLearnCalls + 16, item 2 of kLearnCalls + 8, item 3 of kLearnCalls - 12, item 4 of kLearnCalls - 2), \
         empty, 12, exLearnInk(), "lessonPart") into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 17
   -- The result, in the code's colours
   put item 1 of kLearnOut into tL
   put item 2 of kLearnOut into tT
   put item 3 of kLearnOut into tR
   put item 4 of kLearnOut into tB
   put lkBox("lessonOutBg", kLearnOut, lkColor("code"), 16, "lessonPart") into tObj
   lkShadow tObj, 16, 4, 20
   put lkLabel("lessonOutHead", lkR(tL + 16, tT + 12, tR - 16, tT + 26), "RESULT", 11, "148,163,184", "lessonPart") into tObj
   set the textStyle of tObj to "bold"
   put lkCodeField("Result", lkR(tL + 10, tT + 32, tR - 10, tB - 8), 11, 16, "lessonPart") into tObj
   set the margins of tObj to "6,4,6,4"
   -- The script, in the code panel
   put item 1 of kLearnCode into tL
   put item 2 of kLearnCode into tT
   put item 3 of kLearnCode into tR
   put item 4 of kLearnCode into tB
   put lkBox("lessonCodeBg", kLearnCode, lkColor("code"), 18, "lessonPart") into tObj
   lkShadow tObj, 18, 6, 30
   get lkOval("lessonDot1", lkR(tL + 18, tT + 17, tL + 28, tT + 27), "248,113,113", "lessonPart")
   get lkOval("lessonDot2", lkR(tL + 34, tT + 17, tL + 44, tT + 27), "251,191,36", "lessonPart")
   get lkOval("lessonDot3", lkR(tL + 50, tT + 17, tL + 60, tT + 27), "52,211,153", "lessonPart")
   put lkLabel("lessonCodeHead", lkR(tL + 72, tT + 15, tR - 16, tT + 31), \
         "Try this script: change it, then press Run", 11, "148,163,184", "lessonPart") into tObj
   exMiddle tObj, tT + 22
   put lkCodeField("lessonScript", lkR(tL + 10, tT + 42, tR - 10, tB - 58), 11, 17, "lessonPart") into tObj
   set the margins of tObj to "8,4,8,4"
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   -- (a label of the kit's does not hilite: left so, a click in the
   -- script would not open it for typing)
   set the autoHilite of tObj to true
   set the autoTab of tObj to false
   get exButton("lessonRun", tL + 16, tB - 46, 32, "Run", "play", "primary", tAccent, "lessonPart", empty, 92)
   set the cLearnDo of group "lessonRun" to "run"
   get exButton("lessonCopy", tL + 116, tB - 46, 32, "Copy", "copy", "dark", empty, "lessonPart", empty, 0)
   set the left of group "lessonCopy" to the right of group "lessonRun" + 8
   set the cLearnDo of group "lessonCopy" to "copy"
   get exButton("lessonReset", tL + 216, tB - 46, 32, "Reset", "undo-2", "dark", empty, "lessonPart", empty, 0)
   set the right of group "lessonReset" to tR - 16
   set the cLearnDo of group "lessonReset" to "reset"
   -- (the button Run gives the script to, off the card)
   create button "lessonTry" in group "lessonPart"
   set the rect of it to -40, -40, -30, -30
   set the visible of it to false
   -- The page of a call, over the script
   get lkGroup("lessonSheet", kLearnCode, "lessonPart")
   put lkBox("lessonSheetBg", kLearnCode, "255,255,255", 18, "lessonSheet") into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 18, 6, 24
   put lkLabel("sheetText", lkR(tL + 20, tT + 14, tR - 16, tB - 58), empty, 13, lkColor("text"), "lessonSheet") into tObj
   -- (room above the page's title, which is larger)
   set the margins of tObj to "0,10,0,0"
   get exButton("lessonBack", tL + 16, tB - 46, 32, "Back to the script", "arrow-left", "light", tAccent, "lessonSheet", empty, 0)
   -- (its words in the accent the lessons' words are in, which reads on
   -- the panel in either look)
   set the textColor of field "lessonBack_label" to exLearnInk()
   set the cLearnDo of group "lessonBack" to "back"

   -- The Reference card
   get lkGroup("refPart", lkR(kLeft - 16, kTop - 12, kRight + 16, kBottom + 20), "Learn")
   get lkBox("refAnchor", lkR(kLeft - 16, kTop - 12, kLeft - 15, kTop - 11), empty, 0, "refPart")
   put lkBox("refSearchBg", lkR(256, 104, item 3 of kLearnWords, 140), "255,255,255", 10, "refPart") into tObj
   lkBorder tObj, lkColor("line")
   get exIcon("refSearchIcon", "search", lkColor("muted"), lkR(268, 113, 286, 131), "refPart")
   put lkInput("refSearch", lkR(294, 113, item 3 of kLearnWords - 10, 133), empty, 13, "refPart") into tObj
   get exPanel("refListBg", lkR(256, 152, item 3 of kLearnWords, 616), "refPart")
   put lkLabel("refList", lkR(262, 160, item 3 of kLearnWords - 6, 608), empty, 13, lkColor("ink"), "refPart") into tObj
   set the listBehavior of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 22
   set the hiliteColor of tObj to lkMix("255,255,255", tAccent, 0.18)
   set the margins of tObj to "8,4,4,4"
   lkSelectedInk tObj, lkColor("ink")
   -- (it scrolls with the wheel; the thumb at its right says how far)
   put lkBox("refThumb", lkR(item 3 of kLearnWords - 9, 160, item 3 of kLearnWords - 4, 200), "148,163,184", 3, "refPart") into tObj
   set the blendLevel of tObj to 40
   get exPanel("refTextBg", kLearnCode, "refPart")
   put lkLabel("refText", lkR(item 1 of kLearnCode + 20, item 2 of kLearnCode + 18, item 3 of kLearnCode - 16, item 4 of kLearnCode - 12), \
         empty, 13, lkColor("text"), "refPart") into tObj
   set the margins of tObj to "0,10,0,0"

   -- Each card's own words, and the rest the same on every card
   exShareText "Learn", empty
   repeat for each item tName in "lessonWords,lessonCalls,lessonScript,Result"
      set the sharedText of field tName to false
   end repeat
   set the script of group "Learn" to exLearnRuntimeScript()
   -- (the links, the calls and the names in the pages, in the accent: the
   -- runtime sets the stack's link colours, light or dark, from these, and
   -- puts the dark one in the pages for the light one)
   set the cInk of this stack to lkHex(tAccent)
   set the cInkDark of this stack to lkHex(exLearnInkDark())
   set the cGrey of this stack to kLearnGreyLight
   set the cGreyDark of this stack to kLearnGreyDark
   set the underlineLinks of this stack to false
   set the cProbe of this stack to pProbe
   set the cExtension of this stack to pName
   set the cLoad of this stack to pLoad
   set the cLearn of this card to "front"
   repeat for each item tName in pOthers
      place group "Learn" of card pCard onto card tName
   end repeat
end exLearnKit

-- A panel's eyebrow, and what it says in a lighter colour after it
private command exLearnHead pName, pRect, pText, pAfter
   local tObj, tL, tT
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   get exPanel(pName & "Bg", pRect, "lessonPart")
   put lkLabel(pName, lkR(tL + 16, tT + 14, item 3 of pRect - 16, tT + 28), pText, 11, exLearnInk(), "lessonPart") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   set the rect of tObj to tL + 16, the top of tObj, tL + 20 + the formattedWidth of tObj, the bottom of tObj
   if pAfter is not empty then
      put lkLabel(pName & "After", lkR(the right of tObj + 6, tT + 14, item 3 of pRect - 16, tT + 28), \
            numToCodepoint(183) && pAfter, 11, lkColor("muted"), "lessonPart") into tObj
      set the dontWrap of tObj to true
   end if
end exLearnHead

-- The script of the group "Learn": learn-runtime.livecodescript, without
-- its first line
private function exLearnRuntimeScript
   local tPath, tText
   set the itemDelimiter to slash
   put item 1 to -2 of the filename of stack "OXTExampleBuilder" & "/learn-runtime.livecodescript" into tPath
   set the itemDelimiter to comma
   put url ("file:" & tPath) into tText
   if tText is empty then
      throw "cannot read " & tPath
   end if
   delete line 1 of tText
   return tText
end exLearnRuntimeScript

-- A lesson: the card pCard's words, script, calls and expected result,
-- from the builder's blocks "<card>/words", "<card>/try" and "<card>/expect"
command exLearnLesson pCard
   local tScript, tCalls, tCall, tHtml
   put exScript(pCard & "/try") into tScript
   repeat for each line tCall in tScript
      if the number of chars of tCall > kLearnCodeRoom then
         put "a line of the script of " & pCard & " is longer than " & kLearnCodeRoom & " letters: " & tCall & return after sLearnProblems
      end if
   end repeat
   go card pCard
   set the cLearn of this card to "lesson"
   set the cScript of this card to tScript
   set the cExpect of this card to exScript(pCard & "/expect")
   set the htmlText of field "lessonWords" to exLearnHtml(exScript(pCard & "/words"))
   if the formattedHeight of field "lessonWords" > the height of field "lessonWords" then
      put "the words of " & pCard & " do not fit: " & the formattedHeight of field "lessonWords" & " pixels for " & the height of field "lessonWords" & return after sLearnProblems
   end if
   put exLearnCallsOf(tScript) into tCalls
   if tCalls is empty then
      throw "the script of " & pCard & " calls nothing of the extension"
   end if
   repeat for each line tCall in tCalls
      put "<a>" & tCall & "</a>" & "&nbsp; " after tHtml
      if sLearnUsedIn[tolower(tCall)] is empty then
         put pCard into sLearnUsedIn[tolower(tCall)]
      else if pCard is not among the lines of sLearnUsedIn[tolower(tCall)] then
         put return & pCard after sLearnUsedIn[tolower(tCall)]
      end if
   end repeat
   set the htmlText of field "lessonCalls" to "<p><font color=" & quote & exLearnGrey() & quote & "><b>CALLS</b></font>&nbsp;&nbsp; " & \
         tHtml & "<font color=" & quote & exLearnGrey() & quote & ">(click one)</font></p>"
   -- (without the hint, if it takes a line more)
   if the formattedHeight of field "lessonCalls" > the height of field "lessonCalls" then
      set the htmlText of field "lessonCalls" to "<p><font color=" & quote & exLearnGrey() & quote & "><b>CALLS</b></font>&nbsp;&nbsp; " & tHtml & "</p>"
   end if
   if the formattedHeight of field "lessonCalls" > the height of field "lessonCalls" then
      put "the calls of " & pCard & " do not fit: " & the formattedHeight of field "lessonCalls" & " pixels for " & the height of field "lessonCalls" & return after sLearnProblems
   end if
   -- (in colour once the card opens: the colours would weigh more than
   -- the script)
   put tScript into field "lessonScript"
   -- (all of it in sight, above the buttons, without scrolling)
   if the formattedHeight of field "lessonScript" > the height of field "lessonScript" then
      put "the script of " & pCard & " is too long: " & the number of lines of tScript & " lines, " & \
            the formattedHeight of field "lessonScript" & " pixels for " & the height of field "lessonScript" & return after sLearnProblems
   end if
   put "Press Run to see what this script does." into field "Result"
   set the textColor of field "Result" to "148,163,184"
end exLearnLesson

-- The handlers of the extension a script calls, a line each, in the order
-- it first calls them
function exLearnCallsOf pScript
   local tWord, tOut, tChar, tLine
   repeat for each line tLine in pScript
      -- (not in a comment)
      if offset("--", tLine) > 0 then
         put char 1 to offset("--", tLine) - 1 of tLine into tLine
      end if
      repeat for each char tChar in "(),&" & quote
         replace tChar with space in tLine
      end repeat
      repeat for each word tWord in tLine
         if sLearnDocs[tolower(tWord)] is an array and sLearnDocs[tolower(tWord)]["display name"] is not among the lines of tOut then
            put sLearnDocs[tolower(tWord)]["display name"] & return after tOut
         end if
      end repeat
   end repeat
   delete the last char of tOut
   return tOut
end exLearnCallsOf

-- A lesson's words as htmlText: paragraphs (a blank line between them,
-- which becomes a little space below the paragraph, not a whole line), a
-- line beginning "- " a point of a list, `code` in the accent and **bold**
function exLearnHtml pText
   local tBlocks, tCount, tLine, tHtml, tIndex, tGap
   put 0 into tCount
   put false into tGap
   repeat for each line tLine in pText
      if word 1 to -1 of tLine is empty then
         put true into tGap
      else if char 1 to 2 of tLine is "- " or tCount is 0 or tGap or tBlocks[tCount]["bullet"] then
         if tGap and tCount > 0 then
            put true into tBlocks[tCount]["gap"]
         end if
         add 1 to tCount
         put char 1 to 2 of tLine is "- " into tBlocks[tCount]["bullet"]
         if tBlocks[tCount]["bullet"] then
            delete char 1 to 2 of tLine
            put word 1 to -1 of tLine into tBlocks[tCount]["text"]
         else
            put word 1 to -1 of tLine into tBlocks[tCount]["text"]
         end if
         put false into tGap
      else
         put space & word 1 to -1 of tLine after tBlocks[tCount]["text"]
      end if
   end repeat
   repeat with tIndex = 1 to tCount
      if tBlocks[tIndex]["gap"] then
         put "<p spacebelow=" & quote & "8" & quote & ">" after tHtml
      else
         put "<p>" after tHtml
      end if
      if tBlocks[tIndex]["bullet"] then
         put numToCodepoint(8226) & "&nbsp;" after tHtml
      end if
      put exLearnInline(tBlocks[tIndex]["text"]) & "</p>" after tHtml
   end repeat
   return tHtml
end exLearnHtml

private function exLearnInline pText
   local tOut, tParts, tIndex
   put lkEscape(pText) into pText
   -- `code`, in the accent
   set the itemDelimiter to "`"
   repeat with tIndex = 1 to the number of items of pText
      if tIndex mod 2 is 0 then
         put "<b><font color=" & quote & lkHex(exLearnInk()) & quote & ">" & item tIndex of pText & "</font></b>" after tOut
      else
         put item tIndex of pText after tOut
      end if
   end repeat
   -- **bold**
   put tOut into pText
   put empty into tOut
   set the lineDelimiter to numToCodepoint(1)
   replace "**" with numToCodepoint(1) in pText
   repeat with tIndex = 1 to the number of lines of pText
      if tIndex mod 2 is 0 then
         put "<b>" & line tIndex of pText & "</b>" after tOut
      else
         put line tIndex of pText after tOut
      end if
   end repeat
   set the lineDelimiter to return
   set the itemDelimiter to comma
   return tOut
end exLearnInline

-- The Reference card pCard, and every page of the reference, into the
-- stack's cDocsZ; after the lessons, so that each page names the lessons
-- that use its handler
command exLearnReference pCard
   local tDocs, tName, tKey
   if sLearnProblems is not empty then
      throw "the lessons do not fit:" & return & sLearnProblems
   end if
   repeat for each line tName in sLearnNames
      put tolower(tName) into tKey
      put exLearnPage(sLearnDocs[tKey], sLearnUsedIn[tKey]) into tDocs[tKey]
   end repeat
   -- (compressed: the pages are three quarters of what such a stack would
   -- weigh, and they shrink to a fifth)
   set the cDocsZ of this stack to compress(arrayEncode(tDocs))
   set the cDocNames of this stack to sLearnNames
   go card pCard
   set the cLearn of this card to "reference"
   set the htmlText of field "refText" to tDocs[tolower(line 1 of sLearnNames)]
   put sLearnNames into field "refList"
   set the hilitedLine of field "refList" to 1
end exLearnReference

-- A handler's page of the reference, as htmlText: its name, its syntax,
-- what it does, its parameters and what it returns, the Dictionary's
-- example and description (the names of other handlers in them links),
-- and the lessons that use it. Its words take the field's colour, and the
-- rest is in the accent or a grey that reads in light and dark alike
private function exLearnPage pEntry, pLessons
   local tHtml, tAccent, tGrey, tParam, tIndex, tLine, tKind, tExample, tLesson
   put lkHex(exLearnAccent()) into tAccent
   put kLearnGreyLight into tGrey
   put "<p><font size=" & quote & "20" & quote & "><b>" & lkEscape(pEntry["display name"]) & "</b></font></p>" after tHtml
   put line 1 of pEntry["syntax"][1] into tLine
   replace "<" with empty in tLine
   replace ">" with empty in tLine
   replace "," with ", " in tLine
   put "<p><font color=" & quote & tAccent & quote & "><b>" & lkEscape(tLine) & "</b></font></p><p></p>" after tHtml
   put "<p>" & exLearnLinks(pEntry["summary"]) & "</p>" after tHtml
   if pEntry["parameters"] is an array then
      put "<p></p><p><font color=" & quote & tGrey & quote & "><b>PARAMETERS</b></font></p>" after tHtml
      repeat with tIndex = 1 to the number of elements of pEntry["parameters"]
         put pEntry["parameters"][tIndex] into tParam
         put "<p><b>" & lkEscape(tParam["name"]) & "</b>&nbsp;&nbsp;" & exLearnLinks(tParam["description"]) & "</p>" after tHtml
      end repeat
   end if
   if pEntry["value"] is an array then
      put "<p></p><p><font color=" & quote & tGrey & quote & "><b>RETURNS</b></font></p>" after tHtml
      put "<p>" & exLearnLinks(pEntry["value"][1]["description"]) & "</p>" after tHtml
   end if
   if pEntry["examples"] is an array then
      put "<p></p><p><font color=" & quote & tGrey & quote & "><b>EXAMPLE</b></font></p>" after tHtml
      repeat for each line tLine in pEntry["examples"][1]["script"]
         put "<p><font color=" & quote & tAccent & quote & ">" & exLearnSpaces(lkEscape(tLine)) & "</font></p>" after tHtml
      end repeat
   end if
   if pEntry["description"] is not empty and pEntry["description"] is not pEntry["summary"] then
      put "<p></p><p><font color=" & quote & tGrey & quote & "><b>MORE</b></font></p>" after tHtml
      put "<p>" & exLearnLinks(exLearnUnwrap(pEntry["description"])) & "</p>" after tHtml
   end if
   if pLessons is not empty then
      put "<p></p><p><font color=" & quote & tGrey & quote & "><b>SHOWN IN</b></font></p><p>" after tHtml
      repeat for each line tLesson in pLessons
         put "<a href=" & quote & "card:" & lkEscape(tLesson) & quote & ">" & lkEscape(exLearnTitleOf(tLesson)) & "</a>&nbsp;&nbsp;&nbsp; " after tHtml
      end repeat
      put "</p>" after tHtml
   end if
   return tHtml
end exLearnPage

-- The title of the card pName, from the cards' table
private function exLearnTitleOf pName
   local tIndex
   repeat with tIndex = 1 to the number of lines of sInfo["cards"]
      if exCardInfo(tIndex, "name") is pName then
         return exCardInfo(tIndex, "title")
      end if
   end repeat
   return pName
end exLearnTitleOf

-- The Dictionary's text, its lines joined back into paragraphs (a blank
-- line between them)
private function exLearnUnwrap pText
   local tOut, tLine
   repeat for each line tLine in pText
      if word 1 to -1 of tLine is empty then
         put "</p><p></p><p>" after tOut
      else if tOut is empty or char -3 to -1 of tOut is "<p>" then
         put word 1 to -1 of tLine after tOut
      else
         put space & word 1 to -1 of tLine after tOut
      end if
   end repeat
   return tOut
end exLearnUnwrap

-- Text with the Dictionary's links (a name in angle brackets) as links;
-- the rest escaped. (A name in brackets that is not one of the handlers
-- loses its brackets, as the Dictionary shows it)
private function exLearnLinks pText
   local tOut, tStart, tEnd, tName
   repeat
      put offset("<", pText) into tStart
      put offset(">", pText, tStart) into tEnd
      if tStart is 0 or tEnd is 0 then
         exit repeat
      end if
      put char tStart + 1 to tStart + tEnd - 1 of pText into tName
      put lkEscape(char 1 to tStart - 1 of pText) after tOut
      if sLearnDocs[tolower(tName)] is an array then
         put "<a>" & lkEscape(tName) & "</a>" after tOut
      else
         put lkEscape(tName) after tOut
      end if
      delete char 1 to tStart + tEnd of pText
   end repeat
   put lkEscape(pText) after tOut
   return tOut
end exLearnLinks

-- Leading spaces kept, in htmlText
private function exLearnSpaces pText
   local tCount, tOut
   put 0 into tCount
   repeat while char tCount + 1 of pText is space
      add 1 to tCount
      put "&nbsp;" after tOut
   end repeat
   return tOut & char tCount + 1 to -1 of pText
end exLearnSpaces

-- The front page: the banner, a tile for each card after it, and a row of
-- three tips (pTips: icon|text, a line each) with the status panel at its
-- end. A tile says its card's name, which is short; the sidebar says its
-- title
command exLearnFront pEyebrow, pTitle, pText, pTips
   local tIndex, tWidth, tLeft, tCount
   go card 1
   -- (in colours white words read on, and those words not see-through:
   -- a lesson's words are for reading first)
   exHero lkR(kLeft, kTop, kRight, 252), exLearnAccent() & "|" & exLearnReadable(sInfo["accent2"], "255,255,255"), pEyebrow, pTitle, pText
   set the blendLevel of field "hero_eyebrow" to 0
   set the blendLevel of field "hero_text" to 0
   exProgramTiles 264, 4, 48, 8
   put the number of lines of sInfo["cards"] - 1 into tCount
   repeat with tIndex = 1 to tCount
      put exCardInfo(tIndex + 1, "name") into field ("tile" & tIndex & "_title")
      if the formattedWidth of field ("tile" & tIndex & "_title") > the width of field ("tile" & tIndex & "_title") then
         throw "the tile of " & exCardInfo(tIndex + 1, "name") & " is too narrow for its name"
      end if
   end repeat
   put (kRight - kLeft - 3 * 12) div 4 into tWidth
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 3
      put kLeft + (tIndex - 1) * (tWidth + 12) into tLeft
      exLearnTip "Tip" & tIndex, lkR(tLeft, 492, tLeft + tWidth, kBottom), item 1 of line tIndex of pTips, item 2 of line tIndex of pTips
   end repeat
   set the itemDelimiter to comma
end exLearnFront

private command exLearnTip pName, pRect, pIcon, pText
   local tObj, tL, tT
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   get exPanel(pName, pRect, empty)
   get lkBox(pName & "_iconBg", lkR(tL + 16, tT + 16, tL + 52, tT + 52), lkMix("255,255,255", sInfo["accent"], 0.13), 12, empty)
   get exIcon(pName & "_icon", pIcon, sInfo["accent"], lkR(tL + 24, tT + 24, tL + 44, tT + 44), empty)
   put lkLabel(pName & "_text", lkR(tL + 16, tT + 62, item 3 of pRect - 12, item 4 of pRect - 6), pText, 12, lkColor("soft"), empty) into tObj
   if the formattedHeight of tObj > the height of tObj then
      throw "the tip " & pName & " does not fit: " & pText
   end if
end exLearnTip
