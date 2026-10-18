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
   get exButton("frameBack", 14, kHeight - 104, 32, "Back", "chevron-left", "dark", empty, "Frame", "prev", 98)
   get exButton("frameNext", kSide - 112, kHeight - 104, 32, "Next", "chevron-right", "dark", empty, "Frame", "next", 98)
   put lkLabel("frameCount", lkR(0, kHeight - 60, kSide, kHeight - 44), empty, 12, lkColor("muted"), "Frame", "center") into tObj
   set the sharedText of tObj to false
   put lkLabel("frameHint", lkR(0, kHeight - 43, kSide, kHeight - 27), empty, 11, "100,116,139", "Frame", "center") into tObj
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
   put lkLabel("codeCaption", lkR(tLeft + 72, tTop + 15, tRight - 16, tTop + 31), "Scripts on this card", 11, "100,116,139", "Scripts") into tObj
   -- (in the middle of the dots, up and down, as a button's label is)
   set the top of tObj to tTop + 22 - (the formattedHeight of tObj + kTextInset) div 2
   repeat with tIndex = 1 to 5
      exChip "codeChip" & tIndex, tLeft + 16 + (tIndex - 1) * 70, tTop + 42
   end repeat
   set the cChipRest of group "Scripts" to lkColor("side2")
   set the cChipInk of group "Scripts" to lkColor("sideInk")
   put lkLabel("codeRef", lkR(tLeft + 18, tTop + 80, tRight - 16, tTop + 96), empty, 11, "100,116,139", "Scripts") into tObj
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
         put "255,255,255" into tRest
         put lkMix("255,255,255", pAccent, 0.08) into tLit
         put lkColor("line") into tLine
         put lkColor("ink") into tInk
         put pAccent into tIconInk
         break
      case "light"
         put "255,255,255" into tRest
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
   set the textColor of tObj to "255,255,255"
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
      put lkLabel(tName & "_number", lkR(tX + 64, tY + 13, tX + tWidth - 8, tY + 27), format("%02d", tSlot), 11, lkColor("muted"), tName) into tObj
      set the textStyle of tObj to "bold"
      put lkLabel(tName & "_title", lkR(tX + 64, tY + 29, tX + tWidth - 8, tY + 49), exCardInfo(tIndex, "title"), 14, lkColor("ink"), tName) into tObj
      set the textStyle of tObj to "bold"
      lkEllipsize tObj
      set the cRest of group tName to "255,255,255"
      set the cLit of group tName to lkMix("255,255,255", tAccent, 0.07)
      set the cAction of group tName to "go" && exCardInfo(tIndex, "name")
   end repeat
end exProgramTiles

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

-- Is it one of the window's own groups, Frame, Workbench and Scripts, or
-- in one?
private function exInFrame pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if word 1 of tObj is "group" and the short name of tObj is among the items of "Frame,Workbench,Scripts" then
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
