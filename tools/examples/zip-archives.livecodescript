script "OXTExampleZipArchives"
-- OXT-Beyond: builds "Zip Archives", the remaster of two of OpenXTalk
-- Lite's demos, Zip Build Demo and Zip Extract Demo, which are in
-- ide/Resources/Examples/Zip Build Demo.oxtstack and
-- ide/Resources/Examples/Zip Extract Demo.oxtstack and stay there as their
-- author made them. Who made them is not recorded: their standalone
-- settings name them Zip Build Sampler and Zip Extract Sampler, version
-- 1.0.0.0, "2006  All rights reserved worldwide", the year the zip library
-- (revZip, "Revolution Zip") came to Revolution 2.7.3.
--
-- Each demo was a card with a list: drop files on the first, and it makes
-- a zip of them; drop a zip on the second, and it lists what the zip
-- holds. The remaster keeps both programs and their comments, as two
-- cards of one stack, in the window every remastered example has
-- (builder.livecodescript): "Make an Archive" and "Look Inside", with a
-- page about the zip library after them. What each demo's stack script
-- did, its card's script does now (the demos named their card "Main"; the
-- scripts name it "me"). What the remaster adds is marked "(remaster)" in
-- the scripts: buttons that choose files, an archive and a folder, since
-- dropping does not work everywhere (in a browser tab, for one); each
-- file's and item's name and size in the lists; taking the files out of
-- an archive; a line that says what happened; and words, not script
-- errors, where the zip library is not loaded. In a browser (the web
-- IDE), the archive made and the files taken out download.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- A program card's stage, and the room inside it
constant kStageRight = 600
constant kInLeft = 272
constant kInRight = 584
-- The list on the two program cards: its box, and the field inside it
constant kListTop = 146

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   addIcons
   put "Zip Archives" into tInfo["name"]
   put "from OpenXTalk Lite's demos" into tInfo["credit"]
   put "folder-archive" into tInfo["icon"]
   put lkColor("emerald") into tInfo["accent"]
   put lkColor("teal") into tInfo["accent2"]
   put "Card" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Zip Archives|Pack files into a zip, look inside one, and take its files out.|folder-archive|front" & return & \
         "Make an Archive|Make an Archive|Drop files on the list, or add them, then make a zip of them.|package-plus|program" & return & \
         "Look Inside|Look Inside|Drop a zip on the list, or choose one, to see what it holds.|package-open|program" & return & \
         "About revZip|About revZip|The zip library in a page: what each command these programs use does.|book-open-text|page" into tInfo["cards"]
   codeFontForBuild
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   buildMake
   buildLook
   buildAbout
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Zip Archives.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

-- Icons the kit does not have, from Lucide (ISC licence)
private command addIcons
   exAddIcon "file", "<path d='M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z'/><path d='M14 2v4a2 2 0 0 0 2 2h4'/>"
   exAddIcon "folder", "<path d='M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z'/>"
   exAddIcon "package-plus", "<path d='M16 16h6'/><path d='M19 13v6'/>" & \
         "<path d='M21 10V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l2-1.14'/>" & \
         "<path d='m7.5 4.27 9 5.15'/><polyline points='3.29 7 12 12 20.71 7'/><line x1='12' x2='12' y1='22' y2='12'/>"
   exAddIcon "package-open", "<path d='M12 22v-9'/>" & \
         "<path d='M15.17 2.21a1.67 1.67 0 0 1 1.63 0L21 4.57a1.93 1.93 0 0 1 0 3.36L8.82 14.79a1.655 1.655 0 0 1-1.64 0L3 12.43a1.93 1.93 0 0 1 0-3.36z'/>" & \
         "<path d='M20 13v3.87a2.06 2.06 0 0 1-1.11 1.83l-6 3.08a1.93 1.93 0 0 1-1.78 0l-6-3.08A2.06 2.06 0 0 1 4 16.87V13'/>" & \
         "<path d='M21 12.43a1.93 1.93 0 0 0 0-3.36L8.83 2.2a1.64 1.64 0 0 0-1.63 0L3 4.57a1.93 1.93 0 0 0 0 3.36l12.18 6.86a1.636 1.636 0 0 0 1.63 0z'/>"
   exAddIcon "folder-down", "<path d='M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z'/>" & \
         "<path d='M12 10v6'/><path d='m15 13-3 3-3-3'/>"
   exAddIcon "circle-check", "<circle cx='12' cy='12' r='10'/><path d='m9 12 2 2 4-4'/>"
   exAddIcon "circle-alert", "<circle cx='12' cy='12' r='10'/><line x1='12' x2='12' y1='8' y2='12'/><line x1='12' x2='12.01' y1='16' y2='16'/>"
end addIcons

-- The code on the page is in Source Code Pro where the computer has it,
-- or else in a monospaced font: the card's script sets it when the card
-- opens. The engine here loads Source Code Pro where it can (not on
-- Linux), so that what is measured is measured in a code font
private command codeFontForBuild
   local tFile, tError
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me & "/ide/Toolset/resources/supporting_files/fonts/SourceCodePro-Regular.ttf" into tFile
   set the itemDelimiter to comma
   if "Source Code Pro" is among the lines of the fontNames or there is no file tFile then
      exit codeFontForBuild
   end if
   try
      start using font file tFile
   catch tError
   end try
end codeFontForBuild

################################################################################
#
# Drawing helpers
#

-- A label as tall as its text; returns its bottom
private function textBlock pName, pLeft, pTop, pRight, pText, pSize, pColor, pGroup
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + 400), pText, pSize, pColor, pGroup) into tObj
   set the height of tObj to the formattedHeight of tObj + 4
   set the top of tObj to pTop - 4
   return the bottom of tObj - 4
end textBlock

-- A heading, bold
private function heading pName, pLeft, pTop, pRight, pText, pSize, pGroup
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + pSize + 10), pText, pSize, lkColor("ink"), pGroup) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   return tObj
end heading

-- A small word in capitals, above a list or a value
private function caption pName, pRect, pText, pAlign, pGroup
   local tObj
   put lkLabel(pName, pRect, pText, 11, lkColor("muted"), pGroup, pAlign) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   return tObj
end caption

-- An icon on a tint of a colour, in a rounded square
private command iconBadge pName, pIcon, pLeft, pTop, pSize, pColor, pGroup
   local tInset
   get lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), lkMix("255,255,255", pColor, 0.13), pSize div 3, pGroup)
   put (pSize - 20) div 2 into tInset
   get exIcon(pName & "_icon", pIcon, pColor, lkR(pLeft + tInset, pTop + tInset, pLeft + tInset + 20, pTop + tInset + 20), pGroup)
end iconBadge

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
      if line tIndex of pActions is not empty then
         -- (room at the right for a chevron)
         -- (the item delimiter is | here)
         set the rect of tObj to tL + 68, the top of tObj, tR - 44, the bottom of tObj
      end if
      -- (one line or two, in the middle of the row; 4 more at the bottom
      -- keeps the last line's descenders whole)
      set the height of tObj to the formattedHeight of tObj + 4
      set the top of tObj to tTop + 18 - (the formattedHeight of tObj + 4) div 2
      if line tIndex of pActions is not empty then
         get exIcon(tGroup & "_go", "chevron-right", lkColor("muted"), lkR(tR - 34, tTop + 10, tR - 18, tTop + 26), tGroup)
         set the cRest of group tGroup to "255,255,255"
         set the cLit of group tGroup to lkMix("255,255,255", pColor, 0.07)
         set the cAction of group tGroup to line tIndex of pActions
      end if
   end repeat
   set the itemDelimiter to comma
end rowsPanel

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
   set the cCode of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 17
   set the margins of tObj to "8,4,8,4"
   codeInto tObj, pCode
   return tObj
end codeBox

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
   -- (a letter's width in the font the page will show the code in: a
   -- monospaced one, which the card's script sets when it opens)
   if "DejaVu Sans Mono" is among the lines of the fontNames then
      set the textFont of pField to "DejaVu Sans Mono"
   end if
   put measureText("abcdefghijklmnopqrstuvwxyz", pField) / 26 into tCharWidth
   set the textFont of pField to "Source Code Pro"
   if tCharWidth is not a number or tCharWidth <= 0 then
      put 7 into tCharWidth
   end if
   repeat with tIndex = 1 to tCount
      set the leftIndent of line tIndex of pField to round((tIndent[tIndex] + 3) * tCharWidth)
      set the firstIndent of line tIndex of pField to -round(3 * tCharWidth)
   end repeat
end codeInto

-- A panel of steps, each a number, a command in the code's font and a
-- line of words under it
private command stepsPanel pName, pRect, pTitle, pIcon, pSteps, pColor
   local tL, tT, tR, tIndex, tStep, tTop, tObj
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   get lkGroup(pName, pRect, empty)
   get exPanel(pName & "_bg", pRect, pName)
   iconBadge pName & "_badge", pIcon, tL + 20, tT + 16, 32, pColor, pName
   put heading(pName & "_title", tL + 62, tT + 22, tR - 20, pTitle, 16, pName) into tObj
   set the itemDelimiter to "|"
   put 0 into tIndex
   repeat for each line tStep in pSteps
      add 1 to tIndex
      put tT + 62 + (tIndex - 1) * 46 into tTop
      put lkOval(pName & "_n" & tIndex, lkR(tL + 20, tTop + 1, tL + 42, tTop + 23), lkMix("255,255,255", pColor, 0.14), pName) into tObj
      put lkLabel(pName & "_nl" & tIndex, lkR(tL + 20, tTop + 4, tL + 42, tTop + 20), tIndex, 11, pColor, pName, "center") into tObj
      set the textStyle of tObj to "bold"
      -- (a command in a monospaced font is wide: it may come near the
      -- panel's right)
      put lkLabel(pName & "_code" & tIndex, lkR(tL + 52, tTop + 2, tR - 6, tTop + 20), item 1 of tStep, 11, \
            lkMix(pColor, lkColor("ink"), 0.25), pName) into tObj
      set the textFont of tObj to "Source Code Pro"
      set the cCode of tObj to true
      set the textStyle of tObj to "bold"
      set the dontWrap of tObj to true
      put lkLabel(pName & "_text" & tIndex, lkR(tL + 52, tTop + 22, tR - 14, tTop + 40), item 2 of tStep, 12, lkColor("soft"), pName) into tObj
      set the dontWrap of tObj to true
   end repeat
   set the itemDelimiter to comma
end stepsPanel

-- The list on a program card: a box, the label that says what to drop
-- (behind the list, which is see-through, as in the demos), the list
-- itself, and the icons its rows show
private command listBox pBottom, pText, pHint, pIcon, pListBehavior
   local tObj, tLabel, tIcon, tMid
   put lkBox("ListBox", lkR(kInLeft, kListTop, kInRight, pBottom), "248,250,252", 14, empty) into tObj
   lkBorder tObj, lkColor("muted")
   set the dashes of tObj to "6,4"
   -- The rows' icons, out of sight: the list shows them by their ids
   put exIcon("FileIcon", "file", lkColor("muted"), lkR(kInLeft + 8, kListTop + 8, kInLeft + 24, kListTop + 24), empty) into tIcon
   hide tIcon
   put exIcon("FolderIcon", "folder", lkMix(lkColor("muted"), lkColor("amber"), 0.6), lkR(kInLeft + 28, kListTop + 8, kInLeft + 44, kListTop + 24), empty) into tIcon
   hide tIcon
   put exIcon("DropIcon", pIcon, lkMix(lkColor("emerald"), "255,255,255", 0.25), lkR(kInLeft + 48, kListTop + 8, kInLeft + 84, kListTop + 44), empty) into tIcon
   hide tIcon
   -- The label: an icon, what to drop, and the button to use instead
   put lkLabel("Label", lkR(kInLeft + 8, kListTop, kInRight - 8, pBottom), empty, 12, lkColor("soft"), empty, "center") into tLabel
   set the htmlText of tLabel to "<p>.</p><p><b><font size=" & quote & "15" & quote & " color=" & quote & "#0f172a" & quote & ">" & \
         pText & "</font></b></p><p>" & pHint & "</p>"
   set the fixedLineHeight of tLabel to false
   set the imageSource of char 1 of line 1 of tLabel to the id of image "DropIcon"
   set the spaceAbove of line 2 of tLabel to 10
   set the spaceAbove of line 3 of tLabel to 2
   -- (in the middle of the box, up and down)
   put (kListTop + pBottom) div 2 into tMid
   set the height of tLabel to the formattedHeight of tLabel + 8
   set the top of tLabel to tMid - (the height of tLabel) div 2
   -- The list, in front of the label
   create field "Files"
   put it into tObj
   set the rect of tObj to kInLeft + 2, kListTop + 2, kInRight - 2, pBottom - 2
   set the lockText of tObj to true
   -- (no keyboard focus: a list with it takes the arrow keys, which go
   -- from page to page, and when its card opens the engine gives it the
   -- focus and lights its first line, which Take files out would then
   -- take as chosen. A click still chooses lines)
   set the traversalOn of tObj to false
   set the listBehavior of tObj to pListBehavior
   set the multipleHilites of tObj to pListBehavior
   set the autoHilite of tObj to pListBehavior
   set the opaque of tObj to false
   set the showBorder of tObj to false
   set the showFocusBorder of tObj to false
   set the threeD of tObj to false
   set the borderWidth of tObj to 1
   set the borderColor of tObj to lkColor("line")
   set the dontWrap of tObj to true
   set the textSize of tObj to 13
   set the textColor of tObj to lkColor("ink")
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 32
   set the margins of tObj to "10,6,8,6"
   set the scrollbarWidth of tObj to 12
   -- (the name, then the size at the right; what follows is out of sight)
   set the tabStops of tObj to "176,266,4000,8000"
   set the tabAlign of tObj to "left,right,right,right"
   set the hiliteColor of tObj to lkMix("255,255,255", lkColor("emerald"), 0.16)
   set the vScrollbar of tObj to false
end listBox

-- The line under the buttons that says what happened, with an icon for
-- each kind of news, and a button pButton at its right (hidden) if given
private command statusBox pText, pButton, pButtonLabel, pButtonIcon, pAction
   local tObj, tWidth
   get lkGroup("Status", lkR(kInLeft, 554, kInRight, 600), empty)
   put lkBox("StatusBox", lkR(kInLeft, 554, kInRight, 600), "248,250,252", 12, "Status") into tObj
   lkBorder tObj, lkColor("line")
   put exIcon("StatusTip", "lightbulb", lkColor("muted"), lkR(kInLeft + 14, 569, kInLeft + 30, 585), "Status") into tObj
   put exIcon("StatusOk", "circle-check", lkColor("ok"), lkR(kInLeft + 14, 569, kInLeft + 30, 585), "Status") into tObj
   hide tObj
   put exIcon("StatusProblem", "circle-alert", lkColor("bad"), lkR(kInLeft + 14, 569, kInLeft + 30, 585), "Status") into tObj
   hide tObj
   put lkLabel("StatusText", lkR(kInLeft + 40, 560, kInRight - 12, 596), pText, 12, lkColor("soft"), "Status") into tObj
   statusMiddle tObj
   if pButton is not empty then
      put exButton(pButton, kInLeft, 563, 28, pButtonLabel, pButtonIcon, "light", lkColor("emerald"), "Status", pAction, 0) into tWidth
      set the right of group pButton to kInRight - 9
      hide group pButton
   end if
end statusBox

-- The status line's words, in the middle of its box, up and down
private command statusMiddle pField
   local tHeight
   put the formattedHeight of pField into tHeight
   set the rect of pField to item 1 of the rect of pField, 577 - tHeight div 2, item 3 of the rect of pField, 577 - tHeight div 2 + tHeight
end statusMiddle

-- The header's right, free on a program card: a count, and what it counts
private command headerCount pWord
   local tObj
   put caption("CountLabel", "860,16,1000,30", pWord, "right", empty) into tObj
   put lkLabel("Count", "840,28,1000,66", "0", 30, lkColor("emerald"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
end headerCount

################################################################################
#
# The cards
#

-- The front page: what this is, a tile for each card, what to try, and
-- what it teaches
private command buildFront
   local tObj, tIndex, tX, tY
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 272), lkColor("emerald") & "|" & lkColor("teal") & "|" & lkColor("sky"), \
         "FROM OPENXTALK LITE'S DEMOS  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "Pack files into a zip, and look inside one", \
         "Two small programs that use the zip library: one makes an archive of the files you give it, " & \
         "the other shows what an archive holds and takes its files out."
   -- Files flying into a box, at the banner's right
   repeat with tIndex = 1 to 3
      put item tIndex of "872,906,940" into tX
      put item tIndex of "128,118,132" into tY
      put lkBox("hero_card" & tIndex, lkR(tX, tY, tX + 34, tY + 42), "255,255,255", 7, "hero") into tObj
      set the blendLevel of tObj to item tIndex of "30,10,20"
      lkShadow tObj, 10, 3, 20
      get exIcon("hero_file" & tIndex, "file-text", lkColor("teal"), lkR(tX + 7, tY + 11, tX + 27, tY + 31), "hero")
      set the blendLevel of it to item tIndex of "30,10,20"
   end repeat
   get lineGraphic("hero_path", "923,166" & return & "923,190", "255,255,255", 2, true, "3,5", "hero")
   set the blendLevel of it to 30
   put lkBox("hero_box", lkR(896, 196, 950, 250), "255,255,255", 14, "hero") into tObj
   lkShadow tObj, 14, 4, 25
   get exIcon("hero_boxIcon", "package", lkColor("emerald"), lkR(907, 207, 939, 239), "hero")
   -- (the sparkles, around the files and the box: off the words, and off
   -- the pictures)
   repeat with tIndex = 1 to 6
      set the loc of graphic ("hero_star" & tIndex) of group "hero" to \
            item tIndex of "760,790,868,985,848,976", item tIndex of "124,244,236,192,126,236"
      show graphic ("hero_star" & tIndex) of group "hero"
   end repeat
   exProgramTiles 288, 3, 60, 12
   -- What to try, and what it teaches
   rowsPanel "Try", lkR(kLeft, 364, 620, kBottom), "Try it", \
         "file-plus|Drop files on the list, or add them, then make a zip of them." & return & \
         "package-open|Drop a zip on the other list to see what it holds, and how small." & return & \
         "folder-down|Take the files out: the ones you select, or all of them." & return & \
         "globe|In a browser, the zip you make and the files you take out download.", \
         lkColor("emerald"), empty
   rowsPanel "Learn", lkR(636, 364, kRight, kBottom), "What you will learn", \
         "package-plus|Make a zip: open it, add files, close it" & return & \
         "list-tree|Read a zip: its items, their sizes and dates" & return & \
         "mouse-pointer-click|Drag and drop: dragEnter and dragDrop" & return & \
         "book-open-text|Every revZip command, on one page", \
         lkColor("teal"), "go Make an Archive" & return & "go Look Inside" & return & "go Make an Archive" & return & "go About revZip"
end buildFront

-- A line, an arrow if pArrow
private function lineGraphic pName, pPoints, pColor, pSize, pArrow, pDashes, pGroup
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
end lineGraphic

-- Make an Archive: Zip Build Demo's list and buttons, and its program in
-- the card's script
private command buildMake
   local tObj, tWidth
   go card "Make an Archive"
   set the script of this card to exScript("Make an Archive/card")
   headerCount "FILES"
   put caption("ListCaption", lkR(kInLeft + 2, 122, 420, 138), "FILES TO PACK", "left", empty) into tObj
   put lkLabel("ListSummary", lkR(400, 121, kInRight - 2, 139), empty, 12, lkColor("soft"), empty, "right") into tObj
   set the dontWrap of tObj to true
   listBox 446, "Drag files to add to the archive", "or add them with the button below", "package-plus", false
   set the script of field "Files" to exScript("Make an Archive/Files")
   -- The buttons: the demo's Create and Clear, and Add, which asks for files
   put exButton("Add", kInLeft, 460, 36, "Add files", "file-plus", "ghost", lkColor("emerald"), empty, empty, 0) into tWidth
   set the script of group "Add" to exScript("Make an Archive/Add")
   put exButton("Clear", kInLeft + tWidth + 8, 460, 36, "Clear", "x", "ghost", lkColor("emerald"), empty, empty, 0) into tWidth
   set the script of group "Clear" to exScript("Make an Archive/Clear")
   put exButton("Create", kInLeft, 504, 38, "Create archive", "package-plus", "primary", lkColor("emerald"), empty, empty, kInRight - kInLeft) into tWidth
   set the script of group "Create" to exScript("Make an Archive/Create")
   statusBox "Add the files you want to pack, then make one zip of them all.", "Look", "Look inside", "package-open", "go Look Inside"
end buildMake

-- Look Inside: Zip Extract Demo's list and button, and its program in the
-- card's script
private command buildLook
   local tObj, tWidth
   go card "Look Inside"
   set the script of this card to exScript("Look Inside/card")
   headerCount "ITEMS"
   put caption("ArchiveName", lkR(kInLeft + 2, 122, 440, 138), "NO ARCHIVE OPEN", "left", empty) into tObj
   put lkLabel("ArchiveSummary", lkR(400, 121, kInRight - 2, 139), empty, 12, lkColor("soft"), empty, "right") into tObj
   set the dontWrap of tObj to true
   listBox 418, "Drag an archive to view its contents", "or choose one with the button below", "package-open", true
   set the script of field "Files" to exScript("Look Inside/Files")
   -- What the item chosen is
   put lkLabel("Details", lkR(kInLeft + 4, 428, kInRight - 4, 446), empty, 12, lkColor("soft"), empty) into tObj
   set the dontWrap of tObj to true
   -- The buttons: the demo's Clear, Open, which asks for an archive, and
   -- Extract, which takes its files out
   put exButton("Open", kInLeft, 460, 36, "Choose a zip", "folder-open", "ghost", lkColor("emerald"), empty, empty, 0) into tWidth
   set the script of group "Open" to exScript("Look Inside/Open")
   put exButton("Clear", kInLeft + tWidth + 8, 460, 36, "Clear", "x", "ghost", lkColor("emerald"), empty, empty, 0) into tWidth
   set the script of group "Clear" to exScript("Look Inside/Clear")
   put exButton("Extract", kInLeft, 504, 38, "Take files out", "folder-down", "primary", lkColor("emerald"), empty, empty, kInRight - kInLeft) into tWidth
   set the script of group "Extract" to exScript("Look Inside/Extract")
   statusBox "Select the items to take out, or none to take them all.", empty, empty, empty, empty
end buildLook

-- About revZip: the commands the two programs use, in the order they use
-- them, and the heart of archiveCreate
private command buildAbout
   local tObj
   go card "About revZip"
   set the script of this card to exScript("About revZip/card")
   stepsPanel "MakeSteps", lkR(kLeft, kTop, 620, 400), "Making a zip", "package-plus", \
         "revZipOpenArchive tZip, " & quote & "write" & quote & "|Starts a new zip, if no file has its name yet." & return & \
         "revZipAddItemWithFile tZip, tName, tFile|Puts a file in, under the name it has inside." & return & \
         "revZipCloseArchive tZip|Writes the zip to disk: the work is done here." & return & \
         "the result|Empty if all went well, or ziperr and why." & return & \
         "revZipAddItemWithData tZip, tName, tData|Puts in what a variable holds, not a file.", \
         lkColor("emerald")
   stepsPanel "ReadSteps", lkR(636, kTop, kRight, 400), "Reading a zip", "package-open", \
         "revZipOpenArchive tZip, " & quote & "read" & quote & "|Opens a zip that is there, to read it." & return & \
         "revZipEnumerateItems(tZip)|The names of the items in it, a line each." & return & \
         "revZipDescribeItem(tZip, tItem)|index, crc, size, date, packed size, method" & return & \
         "revZipExtractItemToFile tZip, tItem, tFile|Takes an item out. Its folder must be there." & return & \
         "revZipCloseArchive tZip|Lets the zip go, when you are done with it.", \
         lkColor("teal")
   get codeBox("CreateCode", lkR(kLeft, 416, kRight, kBottom), "archiveCreate, in the script of card " & quote & "Make an Archive" & quote, \
         "revZipOpenArchive pArchive, " & quote & "write" & quote & return & \
         "if the result is not empty then" & return & \
         "   answer " & quote & "Couldn't create archive, try another name" & quote & return & \
         "   exit archiveCreate" & return & \
         "end if" & return & \
         "repeat for each line tFile in pFilelist" & return & \
         "   revZipAddItemWithFile pArchive, nameFile(tFile), tFile" & return & \
         "end repeat" & return & \
         "revZipCloseArchive pArchive  -- this writes the zip file to disk: check the result")
end buildAbout

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Zip Archives: Zip Build Demo and Zip Extract Demo, from OpenXTalk Lite's demos, remastered together for OXT-Beyond in 2026
--Zip Build Sampler and Zip Extract Sampler, version 1.0.0.0: "2006  All rights reserved worldwide" (their standalone settings)

--Each demo is a card now: Zip Build Demo is "Make an Archive", and Zip Extract Demo is "Look Inside".
--What each demo's stack script did, its card's script does; this script starts them both, as the
--demos' stack scripts did, and holds what the remaster added for both cards. The sidebar, the header
--and the panel of scripts are the groups "Frame", "Workbench" and "Scripts", which the script of the
--group "Frame" runs.

on preOpenStack
   -- Initialise the stack, putting empty into the files
   -- list and making sure the instruction field is visible
   -- (remaster: on both cards, which were the demos' card "Main")
   set the text of field "Files" of card "Make an Archive" of me to empty
   set the blendLevel of field "Label" of card "Make an Archive" of me to 0
   set the text of field "Files" of card "Look Inside" of me to empty
   set the blendLevel of field "Label" of card "Look Inside" of me to 0
end preOpenStack

-- (remaster) True if the zip library, revZip, is loaded. The IDE loads it,
-- and the web engine has it built in; without it, its commands would stop
-- the program with an error
function zipLoaded
   local tError
   try
      get revZipOpenArchives()
   catch tError
      return false
   end try
   return true
end zipLoaded

-- (remaster) The size of a file, in bytes, from the detailed list of the
-- files in its folder
function fileSize pPath
   local tFolder, tName, tLine
   set the itemDelimiter to slash
   put item 1 to -2 of pPath into tFolder
   put item -1 of pPath into tName
   if char 1 of pPath is slash and tFolder is empty then put slash into tFolder
   if tFolder is empty then put the defaultFolder into tFolder
   set the itemDelimiter to comma
   repeat for each line tLine in files(tFolder, "detailed")
      if urlDecode(item 1 of tLine) is tName then return item 2 of tLine
   end repeat
   return 0
end fileSize

-- (remaster) A size in words: 18 bytes, 4.2 KB, 12 KB, 1.5 MB
function sizeText pBytes
   if pBytes is not a number then return empty
   if pBytes is 1 then return "1 byte"
   if pBytes < 1024 then return pBytes && "bytes"
   if pBytes < 10 * 1024 then return format("%.1f KB", pBytes / 1024)
   if pBytes < 1024 * 1024 then return round(pBytes / 1024) && "KB"
   if pBytes < 1024 * 1024 * 1024 then return format("%.1f MB", pBytes / (1024 * 1024))
   return format("%.1f GB", pBytes / (1024 * 1024 * 1024))
end sizeText

-- (remaster) "1 file", "3 files"
function plural pCount, pWord
   if pCount is 1 then return "1" && pWord
   return pCount && pWord & "s"
end plural

-- (remaster) pText, shortened at its end with an ellipsis if it is wider
-- than pWidth in pField's font
function nameFit pText, pWidth, pField
   local tText, tTry
   if measureText(pText, pField) <= pWidth then return pText
   put pText into tText
   repeat while the number of chars of tText > 1
      delete the last char of tText
      put tText & numToCodepoint(8230) into tTry
      if measureText(tTry, pField) <= pWidth then exit repeat
   end repeat
   return tText & numToCodepoint(8230)
end nameFit

-- (remaster) The look of a card's list: an icon at the start of each row
-- (a folder's, for a row whose last item ends with a slash), its size in a
-- softer colour, and a scroll bar if the rows do not fit. An empty list
-- has a dashed edge, where files are dropped
command listLook
   local tField, tCount, tIndex, tLine
   put the long id of field "Files" of this card of me into tField
   put the number of lines of the text of tField into tCount
   set the itemDelimiter to tab
   repeat with tIndex = 1 to tCount
      put line tIndex of the text of tField into tLine
      if the last char of item -1 of tLine is slash then
         set the imageSource of char 1 of line tIndex of tField to the id of image "FolderIcon" of this card of me
      else
         set the imageSource of char 1 of line tIndex of tField to the id of image "FileIcon" of this card of me
      end if
      -- (colours of their own: a row chosen keeps them, on a light green)
      set the textColor of line tIndex of tField to "15,23,42"
      set the textColor of item 2 of line tIndex of tField to "100,116,139"
   end repeat
   set the itemDelimiter to comma
   set the vScrollbar of tField to the formattedHeight of tField > the height of tField
   if tCount is 0 then
      set the dashes of graphic "ListBox" of this card of me to "6,4"
      set the foregroundColor of graphic "ListBox" of this card of me to "148,163,184"
   else
      set the dashes of graphic "ListBox" of this card of me to empty
      set the foregroundColor of graphic "ListBox" of this card of me to "226,232,240"
   end if
end listLook

-- (remaster) The count in the header, at its right
command countShow pCount
   set the text of field "Count" of this card of me to pCount
end countShow

-- (remaster) The line under the buttons says what happened: pKind is "ok",
-- "problem" or "tip". With pLook, its button (on Make an Archive, Look
-- inside) shows too
command statusShow pKind, pText, pLook
   local tCard, tBack, tLine, tInk, tRect
   put the long id of this card of me into tCard
   switch pKind
      case "ok"
         put "240,253,244" into tBack
         put "187,247,208" into tLine
         put "21,128,61" into tInk
         break
      case "problem"
         put "254,242,242" into tBack
         put "254,202,202" into tLine
         put "185,28,28" into tInk
         break
      default
         put "248,250,252" into tBack
         put "226,232,240" into tLine
         put "71,85,105" into tInk
   end switch
   lock screen
   set the backgroundColor of graphic "StatusBox" of tCard to tBack
   set the foregroundColor of graphic "StatusBox" of tCard to tLine
   set the visible of image "StatusOk" of tCard to pKind is "ok"
   set the visible of image "StatusProblem" of tCard to pKind is "problem"
   set the visible of image "StatusTip" of tCard to pKind is not "ok" and pKind is not "problem"
   if there is a group "Look" of tCard then
      set the visible of group "Look" of tCard to pLook is true
   end if
   -- (the words end before the Look inside button, when it shows)
   put the rect of field "StatusText" of tCard into tRect
   if pLook is true then
      put the left of group "Look" of tCard - 8 into item 3 of tRect
   else
      put the right of graphic "StatusBox" of tCard - 12 into item 3 of tRect
   end if
   set the rect of field "StatusText" of tCard to tRect
   set the textColor of field "StatusText" of tCard to tInk
   set the text of field "StatusText" of tCard to pText
   -- (one line or two, in the middle of the box: smaller letters for more)
   set the textSize of field "StatusText" of tCard to 12
   if the formattedHeight of field "StatusText" of tCard > 44 then
      set the textSize of field "StatusText" of tCard to 11
   end if
   -- (4 more at the bottom keeps the last line's tails whole: the IDE's
   -- letters reach further down than the line's height says)
   set the height of field "StatusText" of tCard to the formattedHeight of field "StatusText" of tCard + 4
   set the loc of field "StatusText" of tCard to item 1 of the loc of field "StatusText" of tCard, item 2 of the loc of graphic "StatusBox" of tCard
   unlock screen
end statusShow
@*/

/*@ Make an Archive/card
-- Make an Archive: the program of Zip Build
-- Demo. These handlers were its stack
-- script, and named its card "Main"; the
-- demo is this card now, and they name it
-- "me". What the remaster added is marked
-- (remaster).

on preOpenCard
   if not zipLoaded() then
      -- (remaster) say so at once if the zip library is not loaded here
      statusShow "problem", "The zip library, revZip, is not loaded here, so this card cannot make an archive."
   else if the text of field "Files" of me is empty then
      -- (remaster) an empty list, as the stack opens: nothing to count yet
      filesSummary
      statusShow "tip", "Add the files you want to pack, then make one zip of them all."
   end if
   pass preOpenCard
end preOpenCard

on archiveCreate pArchive, pFilelist
   -- It is useful to keep track of the contents of the result
   -- global property when using external library commands
   local tResult
   local tFile -- (remaster) declared, for strict compilation

   -- Check that the list of files to include is not empty
   -- (remaster: this check came after the archive was opened, and left
   -- it open; it comes first now. And "choosen" was a typo)
   if pFilelist is empty then
      answer "No files chosen!"
      statusShow "tip", "Add some files first: drop them on the list, or use Add files."
      exit archiveCreate
   end if

   -- Open the archive for write, this will fail if the
   -- archive already exists
   revZipOpenArchive pArchive, "write"
   put the result into tResult

   if tResult is not empty then
      -- The archive cannot be created.
      answer "Couldn't create archive, try another name"
      statusShow "problem", "Couldn't make" && nameFile(pArchive) & ":" && item 2 to -1 of tResult & ". Try another name."
      exit archiveCreate
   end if

   -- Loop through the files and add them to the archive.
   -- Note that the name of each file in the archive is the
   -- the last part of the file's name. This is returned by
   -- the nameFile() function, further down this script
   repeat for each line tFile in pFilelist
      revZipAddItemWithFile pArchive, nameFile(tFile), tFile
   end repeat

   -- Now close the archive. This will write the zip file
   -- to disk.
   revZipCloseArchive pArchive
   put the result into tResult

   -- As a lot of the work is done on closing the archive,
   -- it is worth checking the result at this stage to make
   -- sure no errors have ocurred.
   if tResult is not empty then
      answer "There was an error writing the archive, the zip library returned: " & tResult
      statusShow "problem", "The zip library could not write" && nameFile(pArchive) & ":" && item 2 to -1 of tResult & "."
      exit archiveCreate
   end if

   -- (remaster) say what was made
   archiveMade pArchive, pFilelist
end archiveCreate

function filesList
   local tFiles, tFormattedFiles
   local tLine, tPath -- (remaster) declared, for strict compilation

   -- Get the list of files that the user has dragged onto the field
   put the text of field "Files" of me into tFiles

   -- We are going to format the list of files, by going through them
   -- one by one and putting all the good ones into a new variable.
   -- In this case, all the lines that are files and exist are kept,
   -- folders and anything else are discarded.
   -- (remaster: a line of the list shows a file's name and size, and
   -- its path is the line's last item, after a tab, out of sight)
   set the itemDelimiter to tab
   repeat for each line tLine in tFiles
      put item -1 of tLine into tPath
      if there is a folder tPath then next repeat
      if there is a file tPath then put tPath & return after tFormattedFiles
   end repeat

   -- Remove the trailing return character
   delete the last char of tFormattedFiles

   -- Return the formatted list of files
   return tFormattedFiles
end filesList

-- Given an absoute file path, returns the name of the file
function nameFile pPath
   set the itemDelimiter to slash
   return item -1 of pPath
end nameFile

-- Shows the instruction label with a simple visual effect.
-- This could easily be changed to use one of Revolution's
-- build in visual effects, including quicktime or a MacOS X
-- core image effect.
on labelShow
   local x -- (remaster) declared, for strict compilation
   if the blendLevel of field "Label" of me is 0 then
      exit labelShow
   end if
   repeat with x=100 down to 0 step -2
      set the blendLevel of field "Label" of me to x
   end repeat
end labelShow

-- Hides the instruction label.
on labelHide
   local x -- (remaster) declared, for strict compilation
   if the blendLevel of field "Label" of me is 100 then
      exit labelHide
   end if
   repeat with x=0 to 100 step 2
      set the blendLevel of field "Label" of me to x
   end repeat
end labelHide

-- (remaster) Adds files to the list, a line each: its name, its size, and
-- after them its path, out of sight. A file the list has already, or a
-- folder, is left out
command filesAdd pFiles
   local tFile, tNew, tCount
   set the itemDelimiter to tab
   put 0 into tCount
   repeat for each line tFile in pFiles
      -- (Linux can give a dropped file as a file:// address, whose
      -- special characters are %-coded; a + in it is a +)
      if tFile begins with "file://" then
         delete char 1 to 7 of tFile
         replace "+" with "%2B" in tFile
         put urlDecode(tFile) into tFile
      end if
      if tFile is empty or there is not a file tFile then next repeat
      if (tab & tFile & return) is in (the text of field "Files" of me & return & tNew) then next repeat
      put "  " & nameFit(nameFile(tFile), 150, the long id of field "Files" of me) & tab & sizeText(fileSize(tFile)) & tab & tFile & return after tNew
      add 1 to tCount
   end repeat
   delete the last char of tNew
   if tNew is empty then
      if the text of field "Files" of me is empty then labelShow
      exit filesAdd
   end if
   lock screen
   labelHide
   if the text of field "Files" of me is empty then
      put tNew into field "Files" of me
   else
      put return & tNew after field "Files" of me
   end if
   listLook
   filesSummary
   statusShow "tip", plural(the number of lines of the text of field "Files" of me, "file") && \
         "ready. Create archive packs them into one zip."
   unlock screen
end filesAdd

-- (remaster) How many files the list has, and their size all together
command filesSummary
   local tFiles, tFile, tTotal, tCount
   put filesList() into tFiles
   put 0 into tTotal
   put 0 into tCount
   repeat for each line tFile in tFiles
      add fileSize(tFile) to tTotal
      add 1 to tCount
   end repeat
   countShow tCount
   if tCount is 0 then
      set the text of field "ListSummary" of me to empty
   else
      set the text of field "ListSummary" of me to plural(tCount, "file") && numToCodepoint(183) && sizeText(tTotal)
   end if
   listLook
end filesSummary

-- (remaster) Says what was made. In a browser, a file the engine writes
-- in the downloads folder downloads; the zip library writes the archive
-- itself, so it is written again here, through the engine
command archiveMade pArchive, pFiles
   local tName, tCount
   -- (a long name is shortened: the words share the line with a button)
   put nameFit(nameFile(pArchive), 100, the long id of field "StatusText" of me) into tName
   put the number of lines of pFiles into tCount
   if the platform is "HTML5" then
      put url ("binfile:" & pArchive) into url ("binfile:" & pArchive)
      statusShow "ok", "Made" && tName & ": see your downloads.", true
   else
      statusShow "ok", "Made" && tName & ":" && plural(tCount, "file") & "," && sizeText(fileSize(pArchive)) & ".", true
   end if
   -- (Look inside shows it)
   set the cJustMade of card "Look Inside" of this stack to pArchive
end archiveMade
@*/

/*@ Make an Archive/Files
on dragEnter
   -- This will hold the list of files/folders the user
   -- has dragged onto the field
   local tData
   local tLine -- (remaster) declared, for strict compilation

   -- Get the drag data we need, and exit straight
   -- away if it is empty
   put the dragData["files"] into tData
   if tData is empty then exit dragEnter

   -- Only allow files for simplicity. It would be
   -- easy to allow the user to drag folders on too.
   repeat for each line tLine in tData
      if there is a folder tLine then exit dragEnter
   end repeat

   -- At this stage, the drop is going to be accepted,
   -- so hide the instruction label and accept the drop.
   labelHide
   set the acceptDrop to true

end dragEnter

on dragDrop
   local tData

   -- Grab the list of the files that the user is dragging
   put the dragData["files"] into tData

   -- Put them into the field, making sure there is
   -- one file per line and no empty lines
   -- (remaster: filesAdd, in the card's script, does it now, and puts
   -- each file's name and size in its line)
   filesAdd tData

end dragDrop

on dragLeave
   -- This message is sent if the user decides not to drop the object
   -- This handler just makes the instruction label reappear if appropriate
   if the text of me is empty then labelShow
end dragLeave
@*/

/*@ Make an Archive/Add
on mouseUp
   -- (remaster) Dropping files does not work everywhere (in a browser
   -- tab, for one), so this button asks for them instead
   local tFiles
   answer files "Choose the files to add to the archive"
   put it into tFiles
   if tFiles is empty then exit mouseUp
   labelHide
   filesAdd tFiles
end mouseUp
@*/

/*@ Make an Archive/Clear
on mouseUp
   -- Clear the files list and show the instruction label
   put empty into field "Files"
   labelShow
   -- (remaster) and the count, and what the card says
   filesSummary
   statusShow "tip", "Add the files you want to pack, then make one zip of them all."
end mouseUp
@*/

/*@ Make an Archive/Create
on mouseUp
   -- This will hold the path of the archive to create
   local tArchive

   -- (remaster) say so, and stop, if the zip library is not loaded here
   if not zipLoaded() then
      statusShow "problem", "The zip library, revZip, is not loaded here, so this card cannot make an archive."
      exit mouseUp
   end if

   -- Find out where the user would like to save their archive
   -- (remaster: with a name to start from)
   ask file "Please choose the name of the archive" with "Archive.zip"
   put it into tArchive

   -- Only continue if they have chosen a name
   if tArchive is empty then exit mouseUp

   -- (remaster) a name that does not end in .zip gets it
   if char -4 to -1 of tArchive is not ".zip" then put ".zip" after tArchive

   -- Create the archive (see the card's script, which was the stack script)
   -- filesList is a function there that returns a
   -- list of the all the files in the files list that can
   -- be added to the archive.
   archiveCreate tArchive, filesList()

end mouseUp
@*/

/*@ Look Inside/card
-- Look Inside: the program of Zip Extract
-- Demo. These handlers were its stack
-- script, and named its card "Main"; the
-- demo is this card now, and they name it
-- "me". What the remaster added is marked
-- (remaster).

-- (remaster) The archive shown, and each of
-- its items' details, by name
local sArchive, sDetails

on preOpenCard
   local tArchive
   if not zipLoaded() then
      -- (remaster) say so at once if the zip library is not loaded here
      statusShow "problem", "The zip library, revZip, is not loaded here, so this card cannot open an archive."
   else if the cJustMade of me is not empty then
      -- (remaster) the archive Make an Archive has just made
      put the cJustMade of me into tArchive
      set the cJustMade of me to empty
      labelHide
      archiveShow tArchive
   else if sArchive is empty then
      -- (remaster) no archive shown, as the stack opens
      archiveForget
      statusShow "tip", "Select the items to take out, or none to take them all."
   else
      -- (remaster) the items selected are let go when the card closes:
      -- the line under the list says so again
      itemDetails
   end if
   pass preOpenCard
end preOpenCard

function archiveReturnContents pArchive
   local tResult, tItems
   if there is no file pArchive then return empty

   -- We need to open the archive first before
   -- we do anything. The archive only needs to be opened
   -- for reading, as we are not going to change it.
   revZipOpenArchive pArchive, "read"
   put the result into tResult

   -- Check the archive has opened correctly
   if tResult is not empty then
      answer "Error opening archive. The zip library answered: " & tResult
      return empty
   end if

   put revZipEnumerateItems(pArchive) into tItems
   return tItems

end archiveReturnContents

-- Given an absolute folder path, returns the name of the folder
function nameFolder pPath
   set the itemDelimiter to slash
   return item -1 of pPath
end nameFolder

-- Given an absoute file path, returns the name of the file
function nameFile pPath
   set the itemDelimiter to slash
   return item -1 of pPath
end nameFile

-- Shows the instruction label with a simple visual effect.
-- This could easily be changed to use one of Revolution's
-- build in visual effects, including quicktime or a MacOS X
-- core image effect.
on labelShow
   local x -- (remaster) declared, for strict compilation
   if the blendLevel of field "Label" of me is 0 then
      exit labelShow
   end if
   repeat with x=100 down to 0 step -2
      set the blendLevel of field "Label" of me to x
   end repeat
end labelShow

-- Hides the instruction label.
on labelHide
   local x -- (remaster) declared, for strict compilation
   if the blendLevel of field "Label" of me is 100 then
      exit labelHide
   end if
   repeat with x=0 to 100 step 2
      set the blendLevel of field "Label" of me to x
   end repeat
end labelHide

-- (remaster) Shows what an archive holds: a line for each item, its name,
-- its size, and after them its name again, out of sight. The archive is
-- open after archiveReturnContents (the demo left it so), so each item's
-- details are read here, and then it is closed
command archiveShow pArchive
   local tItems, tItem, tInfo, tLines, tTotal, tSize, tCount
   put empty into sDetails
   put archiveReturnContents(pArchive) into tItems
   if tItems is empty then
      archiveForget
      if there is not a file pArchive then
         statusShow "problem", "There is no file" && nameFile(pArchive) & "."
      else if pArchive is among the lines of revZipOpenArchives() then
         revZipCloseArchive pArchive
         statusShow "tip", nameFile(pArchive) && "is empty: it holds no files."
      else
         statusShow "problem", nameFile(pArchive) && "is not a zip archive this library can read."
      end if
      labelShow
      exit archiveShow
   end if
   put 0 into tTotal
   put 0 into tCount
   repeat for each line tItem in tItems
      if tItem is empty then next repeat
      -- index, crc, size, time, packed size and method
      put revZipDescribeItem(pArchive, tItem) into tInfo
      put tInfo into sDetails[tItem]
      add item 3 of tInfo to tTotal
      if the last char of tItem is slash then
         put "  " & nameFit(tItem, 150, the long id of field "Files" of me) & tab & tab & tab & tItem & return after tLines
      else
         add 1 to tCount
         put "  " & nameFit(tItem, 150, the long id of field "Files" of me) & tab & sizeText(item 3 of tInfo) & tab & tab & tItem & return after tLines
      end if
   end repeat
   revZipCloseArchive pArchive
   delete the last char of tLines
   put pArchive into sArchive
   lock screen
   put tLines into field "Files" of me
   set the vScroll of field "Files" of me to 0
   listLook
   countShow tCount
   set the text of field "ArchiveName" of me to nameFit(toUpper(nameFile(pArchive)), 170, the long id of field "ArchiveName" of me)
   set the text of field "ArchiveSummary" of me to plural(tCount, "file") && numToCodepoint(183) && sizeText(tTotal)
   itemDetails
   put fileSize(pArchive) into tSize
   if tSize > 0 and tSize < tTotal then
      statusShow "ok", "Opened" && nameFile(pArchive) & ":" && sizeText(tTotal) && "of files, packed into" && sizeText(tSize) & "."
   else
      statusShow "ok", "Opened" && nameFile(pArchive) & ":" && plural(tCount, "file") & "," && sizeText(tTotal) & "."
   end if
   unlock screen
end archiveShow

-- (remaster) Forgets the archive shown
command archiveForget
   put empty into sArchive
   put empty into sDetails
   put empty into field "Files" of me
   listLook
   countShow 0
   set the text of field "ArchiveName" of me to "NO ARCHIVE OPEN"
   set the text of field "ArchiveSummary" of me to empty
   set the text of field "Details" of me to empty
end archiveForget

-- (remaster) The archive shown, for the buttons
function archiveShown
   return sArchive
end archiveShown

-- (remaster) The names of the items chosen in the list, or of them all if
-- none is chosen
function itemsChosen
   local tLines, tLine, tText, tItem, tName, tSeen, tOut
   set the caseSensitive to true
   put the text of field "Files" of me into tText
   put the hilitedLines of field "Files" of me into tLines
   if tLines is empty then
      repeat with tLine = 1 to the number of lines of tText
         put tLine & comma after tLines
      end repeat
   end if
   repeat for each item tLine in tLines
      set the itemDelimiter to tab
      put item -1 of line tLine of tText into tItem
      set the itemDelimiter to comma
      if tItem is empty or tSeen[tItem] is true then next repeat
      put true into tSeen[tItem]
      put tItem & return after tOut
      -- a folder chosen brings out what is in it too
      if the last char of tItem is slash then
         repeat for each key tName in sDetails
            if char 1 to (the number of chars of tItem) of tName is tItem and tSeen[tName] is not true then
               put true into tSeen[tName]
               put tName & return after tOut
            end if
         end repeat
      end if
   end repeat
   delete the last char of tOut
   return tOut
end itemsChosen

-- (remaster) Says what the item chosen is: its size, how small the zip
-- made it, and its date
command itemDetails
   local tLines, tItem, tInfo, tText, tDate
   put the hilitedLines of field "Files" of me into tLines
   if sArchive is empty then
      put empty into tText
   else if tLines is empty then
      put "Nothing selected: Take files out takes them all." into tText
   else if the number of items of tLines > 1 then
      put the number of items of tLines && "items selected." into tText
   else
      set the itemDelimiter to tab
      put item -1 of line (item 1 of tLines) of the text of field "Files" of me into tItem
      set the itemDelimiter to comma
      put sDetails[tItem] into tInfo
      put item 4 of tInfo into tDate
      convert tDate from seconds to dateItems
      if the last char of tItem is slash then
         put "A folder: what is in it comes out with it." into tText
      else
         if item 6 of tInfo is "deflate" then
            put sizeText(item 3 of tInfo) & ", packed into" && sizeText(item 5 of tInfo) into tText
         else
            put sizeText(item 3 of tInfo) & ", stored as it is" into tText
         end if
         put "  " & numToCodepoint(183) & "  " & item 3 of tDate && line (item 2 of tDate) of the abbreviated monthNames && \
               item 1 of tDate & "," && format("%02d:%02d", item 4 of tDate, item 5 of tDate) after tText
      end if
   end if
   set the text of field "Details" of me to tText
end itemDetails

-- (remaster) Takes items out of an archive, into a new folder in pFolder
-- named after the archive. An item whose name would put it outside that
-- folder stays in (see itemSafe). In a browser, each file goes to the
-- downloads folder, and so downloads
command archiveExtract pArchive, pItems, pFolder
   local tResult, tTarget, tItem, tFile, tData, tCount, tFolders, tLeft, tFailed
   if the platform is "HTML5" then
      put pFolder into tTarget
   else
      put folderNew(pFolder, nameFile(pArchive)) into tTarget
      if tTarget is empty then
         statusShow "problem", "Couldn't make a folder for the files in" && nameFolder(pFolder) & "."
         exit archiveExtract
      end if
   end if
   revZipOpenArchive pArchive, "read"
   put the result into tResult
   if tResult is not empty then
      statusShow "problem", "Couldn't open" && nameFile(pArchive) & ":" && item 2 to -1 of tResult & "."
      exit archiveExtract
   end if
   put 0 into tCount
   put 0 into tFolders
   put 0 into tLeft
   put 0 into tFailed
   repeat for each line tItem in pItems
      if tItem is empty then next repeat
      if not itemSafe(tItem) then
         add 1 to tLeft
         next repeat
      end if
      if the last char of tItem is slash then
         if the platform is not "HTML5" then
            folderMake tTarget & slash & char 1 to -2 of tItem
            add 1 to tFolders
         end if
         next repeat
      end if
      if the platform is "HTML5" then
         revZipExtractItemToVariable pArchive, tItem, "tData"
         if the result is empty then
            put tData into url ("binfile:" & tTarget & slash & nameFile(tItem))
         end if
      else
         put tTarget & slash & tItem into tFile
         set the itemDelimiter to slash
         folderMake item 1 to -2 of tFile
         set the itemDelimiter to comma
         revZipExtractItemToFile pArchive, tItem, tFile
      end if
      if the result is empty then
         add 1 to tCount
      else
         add 1 to tFailed
      end if
   end repeat
   revZipCloseArchive pArchive
   if tCount is 0 and tFolders is 0 then
      -- nothing came out: the new folder goes again (it is empty)
      if the platform is not "HTML5" then delete folder tTarget
      put "Nothing came out of" && nameFile(pArchive) & "." into tResult
   else if tCount is 0 then
      put "Took" && plural(tFolders, "empty folder") && "out, into the folder" && nameFolder(tTarget) & "." into tResult
   else if the platform is "HTML5" then
      put "Took" && plural(tCount, "file") && "out: see your downloads." into tResult
   else
      put "Took" && plural(tCount, "file") && "out, into the folder" && nameFolder(tTarget) & "." into tResult
   end if
   if tLeft is 1 then
      put " 1 stayed in: its name leads out of the folder." after tResult
   else if tLeft > 1 then
      put space & tLeft && "stayed in: their names lead out of the folder." after tResult
   end if
   if tFailed > 0 then
      put space & plural(tFailed, "item") && "could not be taken out." after tResult
   end if
   if tCount is 0 and tFolders is 0 then
      statusShow "problem", tResult
   else
      statusShow "ok", tResult
   end if
end archiveExtract

-- (remaster) Makes a new folder in pFolder for an archive's files: the
-- archive's name without .zip, and a number after it if that is taken.
-- Empty if it cannot be made
function folderNew pFolder, pName
   local tName, tPath, tNumber
   put pName into tName
   if char -4 to -1 of tName is ".zip" then delete char -4 to -1 of tName
   if tName is empty then put "Archive" into tName
   put pFolder & slash & tName into tPath
   put 1 into tNumber
   repeat while there is a folder tPath or there is a file tPath
      add 1 to tNumber
      put pFolder & slash & tName && tNumber into tPath
   end repeat
   create folder tPath
   if there is not a folder tPath then return empty
   return tPath
end folderNew

-- (remaster) Makes a folder, and the folders it is in, if they are not
-- there yet
command folderMake pPath
   local tIndex, tPath
   set the itemDelimiter to slash
   repeat with tIndex = 1 to the number of items of pPath
      put item 1 to tIndex of pPath into tPath
      if tPath is empty or there is a folder tPath then next repeat
      create folder tPath
   end repeat
end folderMake

-- (remaster) False for an item whose name would put it outside the folder
-- it is taken out into: one that begins with a slash, or climbs out with ..
-- (Windows reads a backslash in a path as a slash)
function itemSafe pItem
   local tPart
   replace backslash with slash in pItem
   if char 1 of pItem is slash then return false
   set the itemDelimiter to slash
   repeat for each item tPart in pItem
      if tPart is ".." then return false
   end repeat
   return true
end itemSafe
@*/

/*@ Look Inside/Files
on dragEnter
   -- This will hold the list of files/folders the user
   -- has dragged onto the field
   local tData

   -- Get the drag data we need, and exit straight
   -- away if it is empty
   put the dragData["files"] into tData
   if tData is empty then exit dragEnter

   -- We can only accept one archive at a time.
   if the number of lines of tData > 1 then exit dragEnter

   -- The file has to be a zip archive, check its extension
   local tFilename
   put line 1 of tData into tFilename
   set the itemDelimiter to "."
   if item -1 of tFilename is not "zip" then exit dragEnter

   -- At this stage, the drop is going to be accepted,
   -- so hide the instruction label and accept the drop.
   labelHide
   set the acceptDrop to true

end dragEnter

on dragDrop
   local tFile
   put the dragData["files"] into tFile
   -- (remaster: archiveShow, in the card's script, puts each item's
   -- name and size in the list, from archiveReturnContents. The engine
   -- can end the list of files with a return: the file is its line 1)
   archiveShow line 1 of tFile
end dragDrop

on dragLeave
   -- This message is sent if the user decides not to drop the object
   -- This handler just makes the instruction label reappear if appropriate
   if the text of me is empty then labelShow
end dragLeave

-- (remaster) A click on an item says what it is
on selectionChanged
   itemDetails
end selectionChanged
@*/

/*@ Look Inside/Open
on mouseUp
   -- (remaster) Dropping a file does not work everywhere (in a browser
   -- tab, for one), so this button asks for an archive instead
   local tArchive
   if not zipLoaded() then
      statusShow "problem", "The zip library, revZip, is not loaded here, so this card cannot open an archive."
      exit mouseUp
   end if
   answer file "Choose a zip archive to look inside" with type "Zip archives|zip|"
   put it into tArchive
   if tArchive is empty then exit mouseUp
   labelHide
   archiveShow tArchive
end mouseUp
@*/

/*@ Look Inside/Clear
on mouseUp
   -- Clear the file list and show the instruction label
   put empty into field "Files"
   labelShow
   -- (remaster) and forget the archive
   archiveForget
   statusShow "tip", "Select the items to take out, or none to take them all."
end mouseUp
@*/

/*@ Look Inside/Extract
on mouseUp
   -- (remaster) Takes the items selected in the list out of the archive,
   -- or all of them if none is selected, into a folder you choose. A
   -- browser cannot give a page a folder: there, the files download
   local tFolder
   if archiveShown() is empty then
      statusShow "tip", "Drop a zip on the list, or choose one, first."
      exit mouseUp
   end if
   if the platform is "HTML5" then
      put specialFolderPath("downloads") into tFolder
   else
      answer folder "Choose the folder to take the files out into"
      put it into tFolder
      if tFolder is empty then exit mouseUp
   end if
   archiveExtract archiveShown(), itemsChosen(), tFolder
end mouseUp
@*/

/*@ About revZip/card
-- The code on this page is in a code font:
-- Source Code Pro, which the IDE carries for
-- its Script Editor, or else the first
-- monospaced font the computer has, as in
-- the panel of scripts. The fields of code
-- have a custom property, cCode, that says so
on preOpenCard
   local tError, tFont, tIndex
   if the environment is "development" and \
         "Source Code Pro" is not among the lines of the fontNames then
      try
         start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
      catch tError
      end try
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then
         repeat with tIndex = 1 to the number of controls of me
            if the cCode of control tIndex of me is true then
               set the textFont of control tIndex of me to tFont
            end if
         end repeat
         exit repeat
      end if
   end repeat
   pass preOpenCard
end preOpenCard
@*/
