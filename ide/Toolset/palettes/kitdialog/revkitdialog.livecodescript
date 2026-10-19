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
--    text        what it says: a paragraph a line, "- " before a bullet,
--                an empty line between paragraphs
--    detail      text shown under it in a code panel (a command to copy)
--    choices     things to choose, each a tile with an icon and a line
--                that says what it does: a line each, as
--                value|title|icon|text
--    buttons     the buttons at the foot, a line each, the last one the
--                default (Return presses it), as answer's last button is
--    cancel      what Escape, or closing the window, chooses (empty when
--                not given)
--    peek        the path of a file: a Peek button shows its text in the
--                panel, as the classic warning before opening a stack did
--
-- and it returns, in the result, the value of the choice or the label of
-- the button the user pressed, as the "it" of the answer it stands for, so
-- that a caller's switch on it is the one it had. The dialog is modal: the
-- handler that dispatched returns when it closes.
--
-- It is a script-only stack, so it keeps no controls: this script builds
-- them each time it opens. Its name begins with "rev", so the IDE treats it
-- as one of its own windows.

constant kWidth = 600
constant kHeroHeight = 104
constant kPad = 24
constant kFootHeight = 64
constant kButtonHeight = 34
-- The tallest the panel of text grows before it scrolls
constant kMaxPanel = 300
constant kMinPanel = 44
constant kPeekHeight = 300
-- The most of a peeked file that is shown
constant kPeekChars = 200000

-- What the caller asked for, and what the user chose
local sSpec, sChoice
-- The buttons and choices, by number
local sButtons, sChoices
-- True while the panel shows the peeked file
local sPeeking

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
   kdUseKit
   modal me
   return sChoice
end revKitDialogAsk

on preOpenStack
   kdBuild
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

private command kdBuild
   local tSaved, tTone, tObj, tTop, tHeight, tIndex, tTitle, tX
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
   set the resizable of me to false
   set the destroyStack of me to true
   set the rect of me to 0, 0, kWidth, 400
   set the backgroundColor of me to lkColor("bg")
   set the linkColor of me to lkColor("violet")
   set the linkHiliteColor of me to lkColor("pink")
   set the linkVisitedColor of me to lkColor("violet")
   set the underlineLinks of me to false

   -- The header
   put lkBox("heroBg", lkR(0, 0, kWidth, kHeroHeight), lkColor("side"), 0, empty) into tObj
   lkGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", kWidth & "," & kHeroHeight
   put lkBox("heroMark", lkR(kPad, 26, kPad + 52, 78), lkColor(tTone), 26, empty) into tObj
   lkGradient tObj, lkMix(lkColor(tTone), "255,255,255", 0.2) & "|" & lkMix(lkColor(tTone), lkColor("ink"), 0.15), \
         kPad & ",26", (kPad + 52) & ",78"
   lkGlow tObj, lkColor(tTone), 16, 80
   if sSpec["icon"] is not empty then
      get lkIcon("heroMarkIcon", sSpec["icon"], "255,255,255", lkR(kPad + 13, 39, kPad + 39, 65), empty)
   end if
   put kPad + 72 into tX
   if sSpec["subheading"] is empty then
      put lkLabel("heroTitle", lkR(tX, 38, kWidth - kPad, 66), sSpec["heading"], 21, "255,255,255", empty) into tObj
   else
      put lkLabel("heroTitle", lkR(tX, 26, kWidth - kPad, 54), sSpec["heading"], 21, "255,255,255", empty) into tObj
      put lkLabel("heroSub", lkR(tX, 58, kWidth - kPad, 78), sSpec["subheading"], 13, lkColor("sideInk"), empty) into tObj
      lkEllipsize tObj
   end if
   lkEllipsize the long id of field "heroTitle"

   put kHeroHeight + 18 into tTop

   -- The panel of text, as tall as its text up to kMaxPanel
   if sSpec["text"] is not empty or sSpec["peek"] is not empty then
      put lkBox("panelBg", lkR(kPad - 6, tTop, kWidth - kPad + 6, tTop + 100), lkColor("panel"), 14, empty) into tObj
      lkBorder tObj, lkColor("line")
      put lkLabel("panel", lkR(kPad + 8, tTop + 12, kWidth - kPad - 18, tTop + 88), empty, 13, lkColor("soft"), empty) into tObj
      set the textHeight of tObj to 19
      set the htmlText of tObj to kdTextHtml(sSpec["text"])
      put max(kMinPanel, min(kMaxPanel, the formattedHeight of tObj + 5)) into tHeight
      if sSpec["peek"] is not empty then
         -- (room for the file, without the window growing when it shows)
         put max(tHeight, kPeekHeight - 24) into tHeight
      end if
      set the rect of tObj to item 1 of the rect of tObj, tTop + 8, item 3 of the rect of tObj, tTop + 8 + tHeight
      set the rect of graphic "panelBg" to kPad - 6, tTop, kWidth - kPad + 6, tTop + tHeight + 20
      set the vScrollbar of tObj to true
      lkScroller "panelThumb", tObj, "100,116,139", 45, empty
      put tTop + tHeight + 20 + 14 into tTop
   end if

   -- The code panel, as tall as its text up to kMaxPanel, and all of its
   -- text there to scroll to
   if sSpec["detail"] is not empty then
      put lkBox("detailBg", lkR(kPad - 6, tTop, kWidth - kPad + 6, tTop + 60), lkColor("code"), 12, empty) into tObj
      put lkCodeField("detail", lkR(kPad + 8, tTop + 12, kWidth - kPad - 18, tTop + 50), 12, 18, empty) into tObj
      set the dontWrap of tObj to false
      set the text of tObj to sSpec["detail"]
      put max(18, min(kMaxPanel, the formattedHeight of tObj + 4)) into tHeight
      set the rect of tObj to item 1 of the rect of tObj, tTop + 8, item 3 of the rect of tObj, tTop + 8 + tHeight
      set the rect of graphic "detailBg" to kPad - 6, tTop, kWidth - kPad + 6, tTop + tHeight + 20
      set the vScrollbar of tObj to true
      lkScroller "detailThumb", tObj, "203,213,225", 55, empty
      put tTop + tHeight + 20 + 14 into tTop
   end if

   -- The choices, a tile each
   repeat with tIndex = 1 to the number of lines of sChoices
      put kdChoice(tIndex, line tIndex of sChoices, tTop, tTone) into tTop
      add 10 to tTop
   end repeat

   -- The foot
   put max(tTop + 6, kHeroHeight + 60) into tTop
   kdButtons tTop, tTone
   set the rect of me to 0, 0, kWidth, the bottom of group ("button" & the number of lines of sButtons) + 20
   unlock messages
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end kdBuild

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
   get lkGroup(tName, lkR(kPad - 6, pTop, kWidth - kPad + 6, pTop + 60), empty)
   put lkBox(tName & "_bg", lkR(kPad - 6, pTop, kWidth - kPad + 6, pTop + 60), lkColor("panel"), 14, tName) into tObj
   lkBorder tObj, lkColor("line")
   put lkBox(tName & "_iconBg", lkR(kPad + 8, pTop + 12, kPad + 44, pTop + 48), lkMix("255,255,255", tAccent, 0.12), 18, tName) into tObj
   if tIcon is not empty then
      get lkIcon(tName & "_icon", tIcon, tAccent, lkR(kPad + 16, pTop + 20, kPad + 36, pTop + 40), tName)
   end if
   put lkLabel(tName & "_label", lkR(kPad + 58, pTop + 10, kWidth - kPad - 8, pTop + 30), tTitle, 14, lkColor("ink"), tName) into tObj
   set the textStyle of tObj to "bold"
   lkEllipsize tObj
   put lkLabel(tName & "_text", lkR(kPad + 58, pTop + 32, kWidth - kPad - 8, pTop + 50), tText, 12, lkColor("soft"), tName) into tObj
   set the textHeight of tObj to 17
   -- (taller than its text by a few pixels, so that no descender of its
   -- last line is cut)
   set the height of tObj to the formattedHeight of tObj + 5
   set the top of tObj to pTop + 32 - 4
   put max(pTop + 60, the bottom of tObj + 10) into tBottom
   set the rect of graphic (tName & "_bg") to kPad - 6, pTop, kWidth - kPad + 6, tBottom
   set the rect of group tName to kPad - 6, pTop, kWidth - kPad + 6, tBottom
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
   put kWidth - kPad + 6 into tRight
   repeat with tIndex = tCount down to 1
      if tRight - tWidths[tIndex] < tLeftEdge and tRight < kWidth - kPad + 6 then
         add 1 to tRows
         put kWidth - kPad + 6 into tRight
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

-- Peek: the file's text in the panel, as the classic warning showed it in
-- a window of its own, read as data and never run; a second press shows
-- the message again. A binary stack's file is mostly not text, so only
-- its runs of printable characters are shown, which is where its scripts
-- are.
private command kdPeek
   local tSaved, tFile, tData
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   if sPeeking then
      put false into sPeeking
      set the textFont of field "panel" to empty
      set the textSize of field "panel" to 13
      set the textHeight of field "panel" to 19
      set the textColor of field "panel" to lkColor("soft")
      set the htmlText of field "panel" to kdTextHtml(sSpec["text"])
      set the backgroundColor of graphic "panelBg" to lkColor("panel")
      set the foregroundColor of graphic "panelBg" to lkColor("line")
      put "Peek" into field "peek_label"
   else
      put sSpec["peek"] into tFile
      if there is no file tFile then
         put kdTextHtml("The stack's file is no longer where it was:" & return & tFile) into tData
         set the htmlText of field "panel" to tData
      else
         put true into sPeeking
         put url ("binfile:" & tFile) into tData
         put char 1 to kPeekChars of kdReadable(tData) into tData
         if lkCodeFont() is not empty then
            set the textFont of field "panel" to lkCodeFont()
         end if
         set the textSize of field "panel" to 12
         set the textHeight of field "panel" to 17
         set the textColor of field "panel" to lkColor("codeInk")
         set the text of field "panel" to tData
         set the backgroundColor of graphic "panelBg" to lkColor("code")
         set the foregroundColor of graphic "panelBg" to lkColor("code")
         put "Back" into field "peek_label"
      end if
   end if
   set the vScroll of field "panel" to 0
   lkScrollSync "panelThumb"
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
      else if tCode is 10 or tCode is 13 then
         if the number of chars of tRun >= 4 then
            put tRun & return after tOut
         end if
         put empty into tRun
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
