script "revKitDialog"
-- OXT-Beyond: a dialog of the IDE's own, in the look of Learn, Home and the
-- About window, for the places the IDE asked the user something with
-- answer: the update check (oxtBeyondUpdater), the xTalk MCP Bridge's
-- item of Development > Plugins, and the warning before a stack opens
-- (revIDEActionOpenStack). It is drawn by revLearnKit, which is its
-- behavior.
--
-- It is not answer, and answer is not changed: a user's stack that calls
-- answer gets the dialog it always got. Each caller tries this dialog
-- first and falls back to the answer it used before (or the classic
-- window) with the Option (Alt) key down, in the web IDE, when this file
-- is not there (a plugin package installed in another xTalk), or when the
-- dialog cannot open, so nothing a caller does depends on it.
--
-- A caller dispatches revKitDialogAsk to this file with an array:
--
--    title       the window's title
--    heading     the line in large type in the header
--    subheading  the line under it
--    icon        the header mark's icon (a name of revLearnKit's icons)
--    tone        the mark's colour, a name of lkColor ("violet" when empty)
--    callout     a paragraph to heed, above the text, on Learn's tinted
--                panel with an icon and a word (calloutKind: "caution",
--                the default, "note", "tip" or "important")
--    text        what it says: a paragraph a line, "- " before a bullet,
--                an empty line between paragraphs
--    code        xTalk, shown on Learn's code panel in Learn's colours,
--                with a Copy button; moreCode, more of it on a second
--                panel, under the line moreCodeLabel
--    detail      text shown on a code panel as it is, with a Copy button
--                (a command for a terminal); detailKind names it on the
--                panel ("Text" when empty)
--    choices     things to choose, each a tile with an icon and a line
--                that says what it does: a line each, as
--                value|title|icon|text
--    buttons     the buttons at the foot, a line each, the last one the
--                default (Return presses it), as answer's last button is
--    cancel      what Escape, or closing the window, chooses (empty when
--                not given)
--    peek        the path of a file: a Peek button shows its text, in
--                Learn's colours, on a code panel in place of the text, as
--                the classic warning before opening a stack showed it in a
--                window of its own
--
-- and it returns, in the result, the value of the choice or the label of
-- the button the user pressed, as the "it" of the answer it stands for, so
-- that a caller's switch on it is the one it had. The dialog is modal: the
-- handler that dispatched returns when it closes.
--
-- It is a script-only stack, so it keeps no controls: this script builds
-- them each time it opens. Its name begins with "rev", so the IDE treats it
-- as one of its own windows.

-- The width it opens at, and the narrowest it can be made
constant kWidth = 600
constant kHeroHeight = 104
constant kPad = 24
constant kButtonHeight = 34
-- The tallest the panel of text grows before it scrolls
constant kMaxPanel = 300
constant kMinPanel = 44
constant kPeekHeight = 300
-- The most of a peeked file that is shown, and the most of it in colour
-- (colouring is a word at a time, in script)
constant kPeekChars = 200000
constant kColourChars = 40000
-- A code panel's head: its dots, the word that names it and Copy
constant kCodeHead = 40
-- The longest word a code panel shows on one line (kdPlainHtml)
constant kBreakChars = 56

-- What the caller asked for, and what the user chose
local sSpec, sChoice
-- The buttons and choices, by number
local sButtons, sChoices
-- True while the panel shows the peeked file
local sPeeking
-- The text each code panel's Copy copies, by the panel's name
local sCopy
-- The window can be made bigger: wider, everything is laid out again to
-- its width; taller, the height it gains (sExtra) goes to the first panel
-- that scrolls, the text or the code, so that more of it shows. sNatural
-- is its height with nothing gained, and sBuilding stops a rebuild from
-- answering the resize it makes
local sWidth, sExtra, sNatural, sBuilding

################################################################################
#
# Opening and closing
#

-- Shows the dialog for pSpec (see the top) and returns what was chosen,
-- or throws when it cannot open, which tells the caller to fall back
command revKitDialogAsk pSpec
   if the mode of me is not 0 then
      throw "the dialog is open already"
   end if
   put pSpec into sSpec
   put sSpec["cancel"] into sChoice
   put false into sPeeking
   put empty into sCopy
   put kWidth into sWidth
   put 0 into sExtra
   put false into sBuilding
   kdUseKit
   modal me
   return sChoice
end revKitDialogAsk

on preOpenStack
   kdBuild true
   kdPlace
   -- (a script-only stack is made invisible when it is loaded)
   show me
end preOpenStack

on openStack
   lkStartTicking
   lkEnter "side"
end openStack

on closeStack
   lkStopTicking
end closeStack

-- Laid out again for its new size (see sWidth), in place: what the panel
-- showed, the text or the peeked file, and where it was scrolled to stay
on resizeStack pWidth, pHeight
   local tPeeking, tScroll, tField
   if sBuilding or sSpec is empty then
      pass resizeStack
   end if
   put sPeeking into tPeeking
   if tPeeking then
      put "peekFile_code" into tField
   else
      put "panel" into tField
   end if
   if there is a field tField of me then
      put the vScroll of field tField of me into tScroll
   end if
   put max(kWidth, pWidth) into sWidth
   put max(0, pHeight - sNatural) into sExtra
   put false into sPeeking
   kdBuild false
   if tPeeking then
      kdPeek
   end if
   if tScroll is not empty and there is a field tField of me then
      set the vScroll of field tField of me to tScroll
      if tPeeking then
         lkScrollSync "peekFile_thumb"
      else
         lkScrollSync "panelThumb"
      end if
   end if
   pass resizeStack
end resizeStack

on returnKey
   kdPress the number of lines of sButtons
end returnKey

on enterKey
   kdPress the number of lines of sButtons
end enterKey

-- Escape chooses what closing the window does
on rawKeyDown pKey
   if pKey is 65307 then
      put sSpec["cancel"] into sChoice
      close me
   else
      pass rawKeyDown
   end if
end rawKeyDown

-- The kit is this stack's behavior (see revLearnKit)
private command kdUseKit
   local tKit
   if the behavior of me is not empty then
      exit kdUseKit
   end if
   if there is no stack "revLearnKit" then
      put kdToolset() & "/palettes/learn/revlearnkit.livecodescript" into tKit
      if there is no file tKit then
         throw "no revLearnKit"
      end if
      -- (naming the file loads the stack)
      get the short name of stack tKit
   end if
   set the behavior of me to the long id of stack "revLearnKit"
end kdUseKit

-- The IDE's Toolset folder, from this stack's file
private function kdToolset
   set the itemDelimiter to slash
   return item 1 to -4 of the filename of me
end kdToolset

-- In the middle of the screen, a little above it
private command kdPlace
   local tScreen, tHeight
   put the screenRect into tScreen
   put the height of me into tHeight
   set the loc of me to (item 1 of tScreen + item 3 of tScreen) div 2, \
         max(item 2 of tScreen + tHeight div 2 + 30, (item 2 of tScreen + item 4 of tScreen) div 2 - 30)
end kdPlace

################################################################################
#
# Building
#

-- pSize is true when the window takes the size of what it shows (when it
-- opens), false when it keeps the size the user made it
private command kdBuild pSize
   local tSaved, tTone, tObj, tTop, tHeight, tIndex, tTitle, tX, tRect, tGrow
   put true into sBuilding
   -- (the first panel that scrolls takes the height gained)
   put sExtra into tGrow
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   -- (the stack can still be in memory from the last time it opened, and
   -- the kit with it: it forgets the controls that are about to go)
   lkForget "side"
   repeat while the number of controls of this card > 0
      delete control 1 of this card
   end repeat
   put sSpec["buttons"] into sButtons
   if sButtons is empty then
      put "OK" into sButtons
   end if
   put sSpec["choices"] into sChoices
   put sSpec["tone"] into tTone
   if tTone is empty then
      put "violet" into tTone
   end if
   put sSpec["title"] into tTitle
   if tTitle is empty then
      put sSpec["heading"] into tTitle
   end if
   set the label of me to tTitle
   set the destroyStack of me to true
   if pSize then
      set the rect of me to 0, 0, sWidth, 400
   end if
   set the backgroundColor of me to lkColor("bg")
   set the linkColor of me to lkColor("violet")
   set the linkHiliteColor of me to lkColor("pink")
   set the linkVisitedColor of me to lkColor("violet")
   set the underlineLinks of me to false

   -- The header
   put lkBox("heroBg", lkR(0, 0, sWidth, kHeroHeight), lkColor("side"), 0, empty) into tObj
   lkGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", sWidth & "," & kHeroHeight
   put lkBox("heroMark", lkR(kPad, 26, kPad + 52, 78), lkColor(tTone), 26, empty) into tObj
   lkGradient tObj, lkMix(lkColor(tTone), "255,255,255", 0.2) & "|" & lkMix(lkColor(tTone), lkColor("ink"), 0.15), \
         kPad & ",26", (kPad + 52) & ",78"
   lkGlow tObj, lkColor(tTone), 16, 80
   if sSpec["icon"] is not empty then
      get lkIcon("heroMarkIcon", sSpec["icon"], "255,255,255", lkR(kPad + 13, 39, kPad + 39, 65), empty)
   end if
   put kPad + 72 into tX
   if sSpec["subheading"] is empty then
      put lkLabel("heroTitle", lkR(tX, 38, sWidth - kPad, 66), sSpec["heading"], 21, "255,255,255", empty) into tObj
   else
      put lkLabel("heroTitle", lkR(tX, 26, sWidth - kPad, 54), sSpec["heading"], 21, "255,255,255", empty) into tObj
      put lkLabel("heroSub", lkR(tX, 58, sWidth - kPad, 78), sSpec["subheading"], 13, lkColor("sideInk"), empty) into tObj
      lkEllipsize tObj
   end if
   lkEllipsize the long id of field "heroTitle"

   put kHeroHeight + 18 into tTop

   -- What to heed, on Learn's tinted panel
   if sSpec["callout"] is not empty then
      put kdCallout(tTop) + 14 into tTop
   end if

   -- The panel of text, as tall as its text up to kMaxPanel
   if sSpec["text"] is not empty or sSpec["peek"] is not empty then
      put lkBox("panelBg", lkR(kPad - 6, tTop, sWidth - kPad + 6, tTop + 100), lkColor("panel"), 14, empty) into tObj
      lkBorder tObj, lkColor("line")
      put lkLabel("panel", lkR(kPad + 8, tTop + 12, sWidth - kPad - 18, tTop + 88), empty, 13, lkColor("soft"), empty) into tObj
      set the textHeight of tObj to 19
      set the htmlText of tObj to kdTextHtml(sSpec["text"])
      put max(kMinPanel, min(kMaxPanel, the formattedHeight of tObj + 5)) into tHeight
      if sSpec["peek"] is not empty then
         -- (room for the file, without the window growing when it shows)
         put max(tHeight, kPeekHeight - 24) into tHeight
      end if
      add tGrow to tHeight
      put 0 into tGrow
      set the rect of tObj to item 1 of the rect of tObj, tTop + 8, item 3 of the rect of tObj, tTop + 8 + tHeight
      set the rect of graphic "panelBg" to kPad - 6, tTop, sWidth - kPad + 6, tTop + tHeight + 20
      set the vScrollbar of tObj to true
      lkScroller "panelThumb", tObj, "100,116,139", 45, empty
      put tTop + tHeight + 20 + 14 into tTop
   end if

   -- xTalk, in Learn's colours
   if sSpec["code"] is not empty then
      put kdCodeBlock("code", tTop, "xTalk", lkCodeHtml(sSpec["code"]), sSpec["code"], kMaxPanel, tGrow) + 14 into tTop
      put 0 into tGrow
   end if
   if sSpec["moreCode"] is not empty then
      if sSpec["moreCodeLabel"] is not empty then
         put lkLabel("moreLabel", lkR(kPad - 4, tTop - 4, sWidth - kPad, tTop + 14), sSpec["moreCodeLabel"], 13, lkColor("ink"), empty) into tObj
         set the textStyle of tObj to "bold"
         add 22 to tTop
      end if
      put kdCodeBlock("more", tTop, "xTalk", lkCodeHtml(sSpec["moreCode"]), sSpec["moreCode"], 200, 0) + 14 into tTop
   end if

   -- Text as it is, on a code panel
   if sSpec["detail"] is not empty then
      put sSpec["detailKind"] into tObj
      if tObj is empty then
         put "Text" into tObj
      end if
      put kdCodeBlock("detail", tTop, tObj, kdPlainHtml(sSpec["detail"]), sSpec["detail"], kMaxPanel, tGrow) + 14 into tTop
      put 0 into tGrow
   end if

   -- The choices, a tile each
   repeat with tIndex = 1 to the number of lines of sChoices
      put kdChoice(tIndex, line tIndex of sChoices, tTop, tTone) into tTop
      add 10 to tTop
   end repeat

   -- The foot
   put max(tTop + 6, kHeroHeight + 60) into tTop
   kdButtons tTop, tTone
   if pSize then
      put the bottom of group ("button" & the number of lines of sButtons) + 20 into sNatural
      set the rect of me to 0, 0, sWidth, sNatural
      -- (with no panel to take the height, it can only be made wider)
      set the minWidth of me to kWidth
      set the minHeight of me to sNatural
      if sSpec["text"] & sSpec["peek"] & sSpec["code"] & sSpec["detail"] is not empty then
         set the maxHeight of me to 65535
      else
         set the maxHeight of me to sNatural
      end if
      set the resizable of me to true
   end if
   put false into sBuilding
   unlock messages
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end kdBuild

-- What to heed: Learn's callout, a panel tinted with its colour, a bar at
-- its left, an icon and a word for what it is; returns its bottom
private function kdCallout pTop
   local tAccent, tIcon, tWord, tBox, tBar, tObj
   switch sSpec["calloutKind"]
      case "tip"
         put lkColor("emerald") into tAccent
         put "lightbulb" into tIcon
         put "Tip" into tWord
         break
      case "note"
         put lkColor("sky") into tAccent
         put "info" into tIcon
         put "Note" into tWord
         break
      case "important"
         put lkColor("violet") into tAccent
         put "star" into tIcon
         put "Important" into tWord
         break
      default
         put lkColor("rose") into tAccent
         put "triangle-alert" into tIcon
         put "Caution" into tWord
   end switch
   put lkBox("callBg", lkR(kPad - 6, pTop, sWidth - kPad + 6, pTop + 60), lkMix("255,255,255", tAccent, 0.07), 12, empty) into tBox
   lkBorder tBox, lkMix("255,255,255", tAccent, 0.3)
   put lkBox("callBar", lkR(kPad - 6, pTop, kPad - 2, pTop + 60), tAccent, 0, empty) into tBar
   get lkIcon("callIcon", tIcon, tAccent, lkR(kPad + 10, pTop + 13, kPad + 28, pTop + 31), empty)
   put lkLabel("callWord", lkR(kPad + 38, pTop + 13, sWidth - kPad, pTop + 31), tWord, 13, lkMix(tAccent, lkColor("ink"), 0.3), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("callText", lkR(kPad + 38, pTop + 36, sWidth - kPad - 6, pTop + 56), sSpec["callout"], 13, \
         lkMix(tAccent, lkColor("ink"), 0.55), empty) into tObj
   set the textHeight of tObj to 19
   set the height of tObj to the formattedHeight of tObj + 5
   set the top of tObj to pTop + 36 - 4
   set the rect of tBox to kPad - 6, pTop, sWidth - kPad + 6, the bottom of tObj + 10
   -- (the bar runs down the panel's left, inside its rounded corners)
   set the rect of tBar to kPad - 5, pTop + 10, kPad - 2, the bottom of tObj
   return the bottom of tBox
end kdCallout

-- A code panel as Learn draws one: dark, with three dots, a word for what
-- it holds and Copy, and the text in the code font, which scrolls when it
-- is taller than pMax; pHtml is what it shows, pText what Copy copies,
-- and pGrow the height it takes beyond that (see sExtra). The panel is
-- group pName; returns its bottom
private function kdCodeBlock pName, pTop, pKind, pHtml, pText, pMax, pGrow
   local tBox, tObj, tWidth, tHeight, tLeft, tRight
   put kPad - 6 into tLeft
   put sWidth - kPad + 6 into tRight
   get lkGroup(pName, lkR(tLeft, pTop, tRight, pTop + 100), empty)
   put lkBox(pName & "_bg", lkR(tLeft, pTop, tRight, pTop + 100), lkColor("code"), 14, pName) into tBox
   get lkOval(pName & "_d1", lkR(tLeft + 16, pTop + 14, tLeft + 26, pTop + 24), "248,113,113", pName)
   get lkOval(pName & "_d2", lkR(tLeft + 32, pTop + 14, tLeft + 42, pTop + 24), "251,191,36", pName)
   get lkOval(pName & "_d3", lkR(tLeft + 48, pTop + 14, tLeft + 58, pTop + 24), "52,211,153", pName)
   put lkLabel(pName & "_kind", lkR(tLeft + 70, pTop + 11, tLeft + 260, pTop + 27), pKind, 11, "100,116,139", pName) into tObj
   -- (the word on the line of the dots)
   set the height of tObj to the formattedHeight of tObj
   set the top of tObj to pTop + 19 - the formattedHeight of tObj div 2
   -- (wide enough for "Copied")
   put lkButton(pName & "_copy", tLeft, pTop + 7, 26, "Copy", "copy", "dark", empty, pName, "copy:" & pName, 96) into tWidth
   set the left of group (pName & "_copy") to tRight - tWidth - 10
   lkRestAt pName & "_copy"
   put pText into sCopy[pName]
   put lkCodeField(pName & "_code", lkR(tLeft + 20, pTop + kCodeHead, tRight - 20, pTop + 60), 13, 20, pName) into tObj
   set the dontWrap of tObj to false
   set the htmlText of tObj to pHtml
   put max(20, min(pMax, the formattedHeight of tObj + 5)) + pGrow into tHeight
   set the rect of tObj to tLeft + 20, pTop + kCodeHead - 4, tRight - 20, pTop + kCodeHead - 4 + tHeight
   set the vScrollbar of tObj to true
   lkScroller pName & "_thumb", tObj, "203,213,225", 55, pName
   set the rect of tBox to tLeft, pTop, tRight, the bottom of tObj + 12
   set the rect of group pName to the rect of tBox
   return the bottom of tBox
end kdCodeBlock

-- Text shown as it is, in the code panel's ink. A field wraps only at a
-- space, so a word too long for the panel (a path) is shown on lines of
-- its own, broken after a slash where it can be; Copy copies it whole
private function kdPlainHtml pText
   local tHtml, tLine, tWord, tOut
   replace numToCodepoint(13) with empty in pText
   repeat for each line tLine in pText
      put empty into tOut
      repeat for each word tWord in tLine
         if tOut is not empty then
            put space after tOut
         end if
         put kdBreakWord(tWord) after tOut
      end repeat
      if word 1 to -1 of tLine is empty then
         put tLine into tOut
      else
         -- (the line keeps its indent)
         put char 1 to offset(word 1 of tLine, tLine) - 1 of tLine before tOut
      end if
      repeat for each line tWord in tOut
         put "<p>" & lkEscape(tWord) & "</p>" after tHtml
      end repeat
   end repeat
   return tHtml
end kdPlainHtml

-- A word cut into lines of at most kBreakChars characters (more as the
-- window is made wider, a character to 8 pixels), each after the last
-- slash in it where there is one
private function kdBreakWord pWord
   local tOut, tPart, tAt, tMost
   put kBreakChars + (sWidth - kWidth) div 8 into tMost
   repeat while the number of chars of pWord > tMost
      put char 1 to tMost of pWord into tPart
      put kdLastOffset("/", tPart) into tAt
      if tAt < tMost div 2 then
         put tMost into tAt
      end if
      put char 1 to tAt of pWord & return after tOut
      delete char 1 to tAt of pWord
   end repeat
   return tOut & pWord
end kdBreakWord

private function kdLastOffset pFind, pText
   local tFrom, tFound
   put 0 into tFrom
   repeat
      put offset(pFind, pText, tFrom) into tFound
      if tFound is 0 then
         exit repeat
      end if
      add tFound to tFrom
   end repeat
   return tFrom
end kdLastOffset

-- A choice: a tile with an icon and what it does, lit as the pointer goes
-- over it; returns the tile's bottom
private function kdChoice pIndex, pLine, pTop, pTone
   local tName, tTitle, tIcon, tText, tObj, tLook, tBottom, tAccent
   set the itemDelimiter to "|"
   put item 2 of pLine into tTitle
   put item 3 of pLine into tIcon
   put item 4 to -1 of pLine into tText
   set the itemDelimiter to comma
   put lkColor(pTone) into tAccent
   put "choice" & pIndex into tName
   get lkGroup(tName, lkR(kPad - 6, pTop, sWidth - kPad + 6, pTop + 60), empty)
   put lkBox(tName & "_bg", lkR(kPad - 6, pTop, sWidth - kPad + 6, pTop + 60), lkColor("panel"), 14, tName) into tObj
   lkBorder tObj, lkColor("line")
   put lkBox(tName & "_iconBg", lkR(kPad + 8, pTop + 12, kPad + 44, pTop + 48), lkMix("255,255,255", tAccent, 0.12), 18, tName) into tObj
   if tIcon is not empty then
      get lkIcon(tName & "_icon", tIcon, tAccent, lkR(kPad + 16, pTop + 20, kPad + 36, pTop + 40), tName)
   end if
   put lkLabel(tName & "_label", lkR(kPad + 58, pTop + 10, sWidth - kPad - 8, pTop + 30), tTitle, 14, lkColor("ink"), tName) into tObj
   set the textStyle of tObj to "bold"
   lkEllipsize tObj
   put lkLabel(tName & "_text", lkR(kPad + 58, pTop + 32, sWidth - kPad - 8, pTop + 50), tText, 12, lkColor("soft"), tName) into tObj
   set the textHeight of tObj to 17
   -- (taller than its text by a few pixels, so that no descender of its
   -- last line is cut)
   set the height of tObj to the formattedHeight of tObj + 5
   set the top of tObj to pTop + 32 - 4
   put max(pTop + 60, the bottom of tObj + 10) into tBottom
   set the rect of graphic (tName & "_bg") to kPad - 6, pTop, sWidth - kPad + 6, tBottom
   set the rect of group tName to kPad - 6, pTop, sWidth - kPad + 6, tBottom
   put tName & "_bg" into tLook["bg"]
   put lkColor("panel") into tLook["bg0"]
   put lkMix("255,255,255", tAccent, 0.06) into tLook["bg1"]
   put lkColor("line") into tLook["line0"]
   put tAccent into tLook["line1"]
   put tName & "_label" into tLook["label"]
   put lkColor("ink") into tLook["ink0"]
   put lkMix(tAccent, lkColor("ink"), 0.25) into tLook["ink1"]
   put pIndex into tLook["enter"]
   lkLive tName, "side", "c:" & pIndex, tLook
   return tBottom
end kdChoice

-- The buttons, right-aligned, the last one filled with the accent; a
-- second row above when one is too narrow for them, and Peek at the left
private command kdButtons pTop, pTone
   local tIndex, tCount, tWidths, tRight, tRows, tRow, tLeftEdge, tTop
   put the number of lines of sButtons into tCount
   put kPad - 6 into tLeftEdge
   if sSpec["peek"] is not empty then
      get lkButton("peek", tLeftEdge, pTop, kButtonHeight, "Peek", "search", "ghost", lkColor(pTone), empty, "peek", 96)
      put the right of group "peek" + 10 into tLeftEdge
   end if
   -- Made where they go, then moved into place from the right
   repeat with tIndex = 1 to tCount
      if tIndex is tCount then
         put lkButton("button" & tIndex, 0, pTop, kButtonHeight, line tIndex of sButtons, empty, \
               "primary", lkColor(pTone), empty, "b:" & tIndex, 110) into tWidths[tIndex]
      else
         put lkButton("button" & tIndex, 0, pTop, kButtonHeight, line tIndex of sButtons, empty, \
               "ghost", lkColor(pTone), empty, "b:" & tIndex, 90) into tWidths[tIndex]
      end if
   end repeat
   -- Rows from the bottom one up, each filled from the right
   put 1 into tRows
   put sWidth - kPad + 6 into tRight
   repeat with tIndex = tCount down to 1
      if tRight - tWidths[tIndex] < tLeftEdge and tRight < sWidth - kPad + 6 then
         add 1 to tRows
         put sWidth - kPad + 6 into tRight
      end if
      put tRows into tRow[tIndex]
      set the right of group ("button" & tIndex) to tRight
      put tRight - tWidths[tIndex] - 10 into tRight
   end repeat
   repeat with tIndex = 1 to tCount
      put pTop + (tRows - tRow[tIndex]) * (kButtonHeight + 10) into tTop
      set the top of group ("button" & tIndex) to tTop
      lkRestAt "button" & tIndex
   end repeat
   if sSpec["peek"] is not empty then
      set the top of group "peek" to pTop + (tRows - 1) * (kButtonHeight + 10)
      lkRestAt "peek"
   end if
end kdButtons

-- What the dialog says, as htmlText: a paragraph a line, a bullet for
-- "- ", and a heading for a line that ends with a colon
private function kdTextHtml pText
   local tHtml, tLine
   replace numToCodepoint(13) with empty in pText
   repeat for each line tLine in pText
      if tLine begins with "- " then
         put "<p>" & numToCodepoint(8226) & "  " & lkEscape(char 3 to -1 of tLine) & "</p>" after tHtml
      else if tLine is not empty and the last char of tLine is ":" and the number of words of tLine <= 8 then
         put "<p><font color=" & quote & lkHex(lkColor("ink")) & quote & "><b>" & lkEscape(tLine) & "</b></font></p>" after tHtml
      else
         put "<p>" & lkEscape(tLine) & "</p>" after tHtml
      end if
   end repeat
   return tHtml
end kdTextHtml

################################################################################
#
# What it does
#

on lkAction pAction
   switch
      case pAction begins with "b:"
         kdPress char 3 to -1 of pAction
         break
      case pAction begins with "c:"
         set the itemDelimiter to "|"
         put item 1 of line (char 3 to -1 of pAction) of sChoices into sChoice
         set the itemDelimiter to comma
         close me
         break
      case pAction begins with "copy:"
         kdCopy char 6 to -1 of pAction
         break
      case pAction is "peek"
         kdPeek
         break
   end switch
end lkAction

private command kdPress pIndex
   if pIndex < 1 or pIndex > the number of lines of sButtons then
      exit kdPress
   end if
   put line pIndex of sButtons into sChoice
   close me
end kdPress

-- A code panel's Copy: its text on the clipboard, and "Copied" on the
-- button for a moment, as Learn's code panels do
private command kdCopy pName
   set the clipboardData["text"] to sCopy[pName]
   kdCopyLabel pName, "Copied"
   send "kdCopyDone" && quote & pName & quote to me in 1500 milliseconds
end kdCopy

on kdCopyDone pName
   if the mode of me is not 0 then
      kdCopyLabel pName, "Copy"
   end if
end kdCopyDone

-- A Copy button's word, with its icon and word kept in its middle
private command kdCopyLabel pName, pText
   local tLabel, tIcon, tBg, tWidth
   put pName & "_copy_label" into tLabel
   put pName & "_copy_icon" into tIcon
   put pName & "_copy_bg" into tBg
   if there is no field tLabel of me or there is no control tIcon of me or there is no graphic tBg of me then
      exit kdCopyLabel
   end if
   put pText into field tLabel of me
   set the width of field tLabel of me to the formattedWidth of field tLabel of me + 4
   put the right of field tLabel of me - the left of control tIcon of me into tWidth
   set the left of control tIcon of me to (the left of graphic tBg of me + the right of graphic tBg of me - tWidth) div 2
   set the left of field tLabel of me to the right of control tIcon of me + 8
end kdCopyLabel

-- Peek: the file's text on a code panel in place of the text, in Learn's
-- colours, as the classic warning showed it in a window of its own, read
-- as data and never run; a second press shows the text again. A binary
-- stack's file is mostly not text, so only its runs of printable
-- characters are shown, which is where its scripts are.
private command kdPeek
   local tSaved, tFile, tData, tHtml, tRect
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   if not sPeeking and there is no group "peekFile" then
      put sSpec["peek"] into tFile
      if there is no file tFile then
         put "The stack's file is no longer where it was:" & return & tFile into tData
         put kdPlainHtml(tData) into tHtml
      else
         put url ("binfile:" & tFile) into tData
         put char 1 to kPeekChars of kdReadable(tData) into tData
         put lkCodeHtml(char 1 to kColourChars of tData) into tHtml
         if the number of chars of tData > kColourChars then
            put kdPlainHtml(char kColourChars + 1 to -1 of tData) after tHtml
         end if
      end if
      put the rect of graphic "panelBg" into tRect
      get kdCodeBlock("peekFile", item 2 of tRect, "Scripts", tHtml, tData, item 4 of tRect - item 2 of tRect - kCodeHead - 8, 0)
   end if
   put not sPeeking into sPeeking
   set the visible of group "peekFile" to sPeeking
   set the visible of graphic "panelBg" to not sPeeking
   set the visible of field "panel" to not sPeeking
   if sPeeking then
      put "Back" into field "peek_label"
      set the vScroll of field "peekFile_code" to 0
      lkScrollSync "peekFile_thumb"
   else
      put "Peek" into field "peek_label"
      lkScrollSync "panelThumb"
   end if
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end kdPeek

-- The text of a file read as binary: as it is when it is text (a
-- script-only stack), else its runs of at least four printable
-- characters, a run a line
private function kdReadable pData
   local tOut, tRun, tChar, tCode, tCount
   put 0 into tCount
   repeat for each byte tChar in byte 1 to 4096 of pData
      put byteToNum(tChar) into tCode
      if tCode is 0 or (tCode < 32 and tCode is not among the items of "9,10,13") then
         add 1 to tCount
      end if
   end repeat
   if tCount = 0 then
      put textDecode(pData, "utf-8") into tOut
      replace numToCodepoint(13) & numToCodepoint(10) with return in tOut
      replace numToCodepoint(13) with return in tOut
      return tOut
   end if
   repeat for each byte tChar in pData
      put byteToNum(tChar) into tCode
      if (tCode >= 32 and tCode < 127) or tCode is 9 then
         put tChar after tRun
      else
         if the number of chars of tRun >= 4 then
            put tRun & return after tOut
         end if
         put empty into tRun
      end if
      if the number of chars of tOut > kPeekChars then
         exit repeat
      end if
   end repeat
   if the number of chars of tRun >= 4 then
      put tRun after tOut
   end if
   return tOut
end kdReadable
