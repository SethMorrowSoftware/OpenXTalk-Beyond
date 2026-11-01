script "OXTExampleQuickStart"
-- OXT-Beyond: builds "Quick Start Guide", the remaster of Terry Little's
-- Quick Start v1.5 (2024, GPL 3 or later), which is in
-- tools/examples/originals/Quick Start.oxtstack and stays there as he made
-- it.
--
-- His stack is six lessons for a first-time coder, a card each: the IDE
-- (the Tools palette, the menus, the Message Box, the inspectors), buttons
-- and fields, commands and functions, the Script Editor, the Dictionary
-- and the User Guide, and background groups. Each card has his notes in a
-- scrolling field ("Info"), the words of his narrator in a hidden one
-- ("Lesson"), a button that speaks them with revSpeak, a paragraph at each
-- click ("Narrator"), and the lesson's own buttons and fields to try.
--
-- The remaster keeps all of that, in the window every remastered example
-- has (builder.livecodescript). Each lesson is a wide card: the things to
-- try on a canvas at the left of the stage, the narrator under them, and
-- the notes at the right, where the scripts drawer opens over them. The
-- lesson's buttons and fields are real buttons and fields, as his were
-- (they are what the lessons are about), drawn flat. The notes and the
-- narrator are in two background groups, as his were, so their fields
-- have a text of their own on each card. The narrator still reads a
-- paragraph at each click; it now shows the words it reads, says how far
-- it is, has a Stop button, and says so kindly where there is no voice
-- (a computer without speech, or a browser with none): revSpeak is in a
-- try there.
--
-- His texts are read from his stack when the stack is built, and the few
-- words that this window changes are in lessonText, each with its reason.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kStageLeft = 256
constant kStageTop = 104
constant kStageRight = 1000
constant kStageBottom = 616
-- A lesson's stage: the things to try on a canvas at the left, and the
-- narrator under them; the notes from kSplit to the right, where the
-- scripts drawer opens over them
constant kSplit = 616
constant kPlayLeft = 280
constant kPlayRight = 592
constant kCanvasTop = 128
constant kCanvasBottom = 340
constant kNarratorTop = 352
constant kNarratorBottom = 592
-- The lessons' cards, in order (their names are Terry's)
constant kLessons = "Orientation,Buttons & Fields,Commands & Functions,Script Editor,Dictionary & User Guide,Background Group"

-- Terry's texts, read from his stack: each lesson's notes and narration,
-- by its number, and the texts of a few fields
local sTexts
-- The id of the image of the line that stands for his "====" rules in
-- the notes (buildNotes makes it)
local sRuleImage

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex
   exUseScripts the script of me
   -- (two icons Learn's kit does not have, from Lucide: a square to stop
   -- the narrator, and the lines of a voice on its disc)
   exAddIcon "square", "<rect width='18' height='18' x='3' y='3' rx='2'/>"
   exAddIcon "audio-lines", "<path d='M2 10v3'/><path d='M6 6v11'/><path d='M10 3v18'/><path d='M14 8v7'/>" & \
         "<path d='M18 5v13'/><path d='M22 10v3'/>"
   readOriginal
   put "Quick Start Guide" into tInfo["name"]
   put "after Terry Little, 2024" into tInfo["credit"]
   put "rocket" into tInfo["icon"]
   put lkColor("orange") into tInfo["accent"]
   put lkColor("flame") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Quick Start Guide|Terry Little's six lessons on the basics of OpenXTalk, for first-time coders.|rocket|front" & return & \
         "Orientation|Orientation|Your way around the IDE: the Tools palette, the Message Box and the inspectors.|compass|wide" & return & \
         "Buttons & Fields|Buttons & Fields|One button object, one field object, and the many kinds their properties make.|mouse-pointer-click|wide" & return & \
         "Commands & Functions|Commands & Functions|A command begins each line of code, and a function gives back a value.|square-terminal|wide" & return & \
         "Script Editor|Script Editor|Where you write the code that answers a click, and the way a message travels.|braces|wide" & return & \
         "Dictionary & User Guide|Dictionary & User Guide|Look up any word, choose with if-then-else, and keep values in containers.|book-open-text|wide" & return & \
         "Background Group|Background Group|Objects that appear on every card, as this window's sidebar does.|layers|wide" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   buildNotes
   buildNarration
   buildOrientation
   buildButtonsAndFields
   buildCommandsAndFunctions
   buildScriptEditor
   buildDictionary
   buildBackgroundGroup
   repeat with tIndex = 1 to the number of items of kLessons
      lessonTexts tIndex
      -- (the notes and the narrator above the lesson's own controls, so
      -- that the scripts panel offers the lesson's scripts first; exSave
      -- then puts the scripts drawer above them all)
      go card (item tIndex of kLessons)
      relayer group "Notes" to front of this card
      relayer group "Narration" to front of this card
   end repeat
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Quick Start Guide.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

-- Terry's texts, from his stack, which is read and then unloaded (its file
-- stays as it is): each lesson's notes ("Info") and narration ("Lesson"),
-- the list his Commands & Functions button made ("Display"), and the texts
-- of his fields to try
private command readOriginal
   local tRepo, tOriginal, tIndex
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put tRepo & "/tools/examples/originals/Quick Start.oxtstack" into tOriginal
   if there is no file tOriginal then
      throw "cannot find Terry Little's stack at " & tOriginal
   end if
   lock messages
   repeat with tIndex = 1 to 6
      put the text of field "Info" of card tIndex of stack tOriginal into sTexts[tIndex]["Info"]
      put the text of field "Lesson" of card tIndex of stack tOriginal into sTexts[tIndex]["Lesson"]
   end repeat
   put the text of field "Display" of card 3 of stack tOriginal into sTexts["Display"]
   -- (his list began with the engine's own "_internal", a name a beginner
   -- has no use for: it is left out, as his button now leaves it out, and
   -- the count says so)
   filter sTexts["Display"] without "_*"
   put the number of lines of sTexts["Display"] - 1 into word 1 of line 1 of sTexts["Display"]
   put the text of field "Field Test" of card 2 of stack tOriginal into sTexts["Field Test"]
   put the text of field "Forecast" of card 5 of stack tOriginal into sTexts["Forecast"]
   delete stack tOriginal
   unlock messages
end readOriginal

-- A lesson's notes or narration, as Terry wrote them, with what this window
-- changes in them
private function lessonText pIndex, pWhich
   local tText
   put sTexts[pIndex][pWhich] into tText
   if pIndex is 1 then
      -- (in his stack, button 3 was My First Button, after the two
      -- navigation buttons; here the button you make is button 2, after My
      -- First Button, which is what "do the same thing" means)
      textChange tText, "button 3 to", "button 2 to"
   end if
   if pIndex is 6 then
      -- (the navigation buttons and the title are in the sidebar and the
      -- header here, at the left, not in the upper left)
      textChange tText, "Title field in the upper left", "Title field at the left"
   end if
   return tText
end lessonText

private command textChange @pText, pFrom, pTo
   if pFrom is not in pText then
      throw "Terry Little's text no longer has " & quote & pFrom & quote
   end if
   replace pFrom with pTo in pText
end textChange

################################################################################
#
# The front page
#

-- What the lessons are, who they are for, a tile for each, and how a
-- lesson works
private command buildFront
   local tObj, tIndex, tLeft, tTop, tWidth, tSteps, tName, tSmaller
   go card "Start"
   exHero lkR(kStageLeft, kStageTop, kStageRight, 272), lkColor("flame") & "|" & lkColor("orange") & "|" & lkColor("rose"), \
         "TERRY LITTLE, 2024  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "Six lessons, from first click to first script", \
         "Terry Little's quick start for first-time coders: a tour of the IDE and of the language, from the Tools " & \
         "palette and the Message Box to the Script Editor, the Dictionary and background groups."
   exProgramTiles 288, 3, 60, 12
   -- (a title that comes near its tile's right, or is too long for it:
   -- every title a size smaller, so that the six match, and each keeps
   -- 20 points of the tile at its right before it loses letters)
   put false into tSmaller
   repeat with tIndex = 1 to 6
      put "tile" & tIndex & "_title" into tName
      if there is a field tName then
         if the last char of field tName is numToCodepoint(8230) or \
               the left of field tName + the formattedWidth of field tName > the right of field tName - 12 then
            put true into tSmaller
         end if
      end if
   end repeat
   repeat with tIndex = 1 to 6
      put "tile" & tIndex & "_title" into tName
      if tSmaller and there is a field tName then
         set the text of field tName to item tIndex of kLessons
         set the textSize of field tName to 13
         lkEllipsize the long id of field tName
      end if
   end repeat
   -- How a lesson works, in four steps
   put "mouse-pointer-click|Try it|Each lesson's own buttons and fields are on its stage, as Terry made them: click them and see." & return & \
         "book-open|Read the notes|His notes, at the right, go step by step. Do each Try It in the IDE, beside this window." & return & \
         "volume-2|Listen|Read it to me reads the lesson aloud, a paragraph at each click, and shows the words." & return & \
         "code|See the scripts|Scripts, at the top right, shows the script of each button and field: read it, change it, try it." into tSteps
   put 436 into tTop
   put (kStageRight - kStageLeft - 3 * 12) div 4 into tWidth
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put kStageLeft + (tIndex - 1) * (tWidth + 12) into tLeft
      put "step" & tIndex into tName
      get lkGroup(tName, lkR(tLeft, tTop, tLeft + tWidth, kStageBottom), empty)
      put exPanel(tName & "_bg", lkR(tLeft, tTop, tLeft + tWidth, kStageBottom), tName) into tObj
      put lkBox(tName & "_iconBg", lkR(tLeft + 16, tTop + 16, tLeft + 56, tTop + 56), \
            lkMix("255,255,255", lkColor("orange"), 0.12), 12, tName) into tObj
      get exIcon(tName & "_icon", item 1 of line tIndex of tSteps, lkColor("orange"), \
            lkR(tLeft + 26, tTop + 26, tLeft + 46, tTop + 46), tName)
      put lkLabel(tName & "_number", lkR(tLeft + 66, tTop + 18, tLeft + tWidth - 12, tTop + 32), \
            "STEP" && tIndex, 10, lkColor("orange"), tName) into tObj
      set the textStyle of tObj to "bold"
      put lkLabel(tName & "_title", lkR(tLeft + 66, tTop + 33, tLeft + tWidth - 4, tTop + 53), \
            item 2 of line tIndex of tSteps, 13, lkColor("ink"), tName) into tObj
      set the textStyle of tObj to "bold"
      lkEllipsize tObj
      put lkLabel(tName & "_text", lkR(tLeft + 16, tTop + 70, tLeft + tWidth - 14, kStageBottom - 10), \
            item 3 of line tIndex of tSteps, 13, lkColor("soft"), tName) into tObj
      set the fixedLineHeight of tObj to true
      set the textHeight of tObj to 18
   end repeat
   set the itemDelimiter to comma
end buildFront

################################################################################
#
# What every lesson has: the notes and the narrator, two backgrounds
#

-- The notes: Terry's field "Info", at the right of the stage, under a
-- word that says what it is. It scrolls with the wheel (the stack script),
-- with a slim thumb, as the scripts panel does; its text can be selected
-- and copied (the lessons ask you to copy code from it), not changed
private command buildNotes
   local tObj
   go card (item 1 of kLessons)
   get lkGroup("Notes", lkR(kSplit, kStageTop, kStageRight, kStageBottom), empty)
   set the backgroundBehavior of group "Notes" to true
   -- (the first control made in a group goes to its top left: this one
   -- is already there)
   get lkBox("notesAnchor", lkR(kSplit, kStageTop, kSplit + 1, kStageTop + 1), empty, 0, "Notes")
   put lkBox("notesRule", lkR(kSplit, kStageTop + 24, kSplit + 1, kStageBottom - 24), lkColor("line"), 0, "Notes") into tObj
   get exIcon("notesIcon", "book-open", lkColor("orange"), lkR(kSplit + 24, 124, kSplit + 40, 140), "Notes")
   put lkLabel("notesWord", lkR(kSplit + 48, 125, kStageRight - 24, 140), "LESSON NOTES", 11, lkColor("muted"), "Notes") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Info", lkR(kSplit + 12, 152, kStageRight - 14, kStageBottom - 12), empty, 14, "51,65,85", "Notes") into tObj
   set the rect of tObj to kSplit + 12, 148, kStageRight - 14, kStageBottom - 12
   set the margins of tObj to "12,4,14,12"
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the cThumb of tObj to "notesThumb"
   put lkBox("notesThumb", lkR(kStageRight - 9, 156, kStageRight - 5, 200), "203,213,225", 2, "Notes") into tObj
   hide tObj
   -- (his "====" rules, as a thin line: the notes show this image in
   -- their place, so each is still a line of the field)
   put lkDrawing("notesDivider", "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 120 12'>" & \
         "<rect x='0' y='5.5' width='120' height='1' fill='" & lkHex(lkColor("line")) & "'/></svg>", \
         lkR(kSplit + 24, 160, kSplit + 144, 172), "Notes") into tObj
   hide tObj
   put the short id of tObj into sRuleImage
   shareText "Notes", "Info"
   placeOnLessons "Notes"
end buildNotes

-- The narrator: Terry's button, which speaks his field "Lesson" a
-- paragraph at each click, on a card under the canvas, with his title of
-- the lesson, how far it has read, the words it is reading, and Stop. His
-- field "Lesson" stays hidden, as it was: Shift-click on Read it to me
-- shows it, to change the words, over the narrator's card
private command buildNarration
   local tObj, tWidth, tLeft
   go card (item 1 of kLessons)
   get lkGroup("Narration", lkR(kPlayLeft - 12, kNarratorTop - 12, kPlayRight + 12, kStageBottom - 4), empty)
   set the backgroundBehavior of group "Narration" to true
   get lkBox("narrationAnchor", lkR(kPlayLeft - 12, kNarratorTop - 12, kPlayLeft - 11, kNarratorTop - 11), empty, 0, "Narration")
   put exPanel("narrationCard", lkR(kPlayLeft, kNarratorTop, kPlayRight, kNarratorBottom), "Narration") into tObj
   -- (its disc: the lines of a voice, on the example's colours)
   put lkOval("narrationDisc", lkR(kPlayLeft + 16, kNarratorTop + 14, kPlayLeft + 54, kNarratorTop + 52), lkColor("orange"), "Narration") into tObj
   lkGradient tObj, lkColor("flame") & "|" & lkColor("orange") & "|" & lkColor("rose"), \
         (kPlayLeft + 16) & "," & (kNarratorTop + 14), (kPlayLeft + 54) & "," & (kNarratorTop + 52)
   lkGlow tObj, lkColor("orange"), 10, 70
   get exIcon("narrationDiscIcon", "audio-lines", "255,255,255", \
         lkR(kPlayLeft + 25, kNarratorTop + 23, kPlayLeft + 45, kNarratorTop + 43), "Narration")
   put lkLabel("Title", lkR(kPlayLeft + 66, kNarratorTop + 14, kPlayRight - 12, kNarratorTop + 33), empty, 14, lkColor("ink"), "Narration") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   put lkLabel("Progress", lkR(kPlayLeft + 66, kNarratorTop + 35, kPlayRight - 12, kNarratorTop + 51), empty, 11, lkColor("muted"), "Narration") into tObj
   set the dontWrap of tObj to true
   -- (what it says, in a balloon)
   put lkBox("narrationBalloon", lkR(kPlayLeft + 12, kNarratorTop + 62, kPlayRight - 12, kNarratorTop + 186), \
         lkMix("255,255,255", lkColor("orange"), 0.07), 12, "Narration") into tObj
   put lkLabel("Said", lkR(kPlayLeft + 22, kNarratorTop + 72, kPlayRight - 24, kNarratorTop + 180), empty, 12, lkColor("soft"), "Narration") into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 16
   set the cThumb of tObj to "saidThumb"
   put lkBox("saidThumb", lkR(kPlayRight - 19, kNarratorTop + 70, kPlayRight - 16, kNarratorTop + 110), \
         lkMix("255,255,255", lkColor("orange"), 0.4), 2, "Narration") into tObj
   hide tObj
   -- Read it to me (Terry's Narrator), and Stop
   put exButton("Narrator", kPlayLeft + 12, kNarratorTop + 198, 32, "Read it to me", "volume-2", "primary", lkColor("orange"), \
         "Narration", empty, 0) into tWidth
   set the script of group "Narrator" to exScript("Narrator")
   set the cLine of group "Narrator" to 1
   put kPlayLeft + 12 + tWidth + 8 into tLeft
   get exButton("Stop", tLeft, kNarratorTop + 198, 32, "Stop", "square", "ghost", lkColor("orange"), "Narration", empty, 0)
   set the script of group "Stop" to exScript("Stop")
   -- Terry's narration, hidden, over the narrator's card but its buttons
   put lkLabel("Lesson", lkR(kPlayLeft, kNarratorTop, kPlayRight, kNarratorTop + 188), empty, 13, lkColor("ink"), "Narration") into tObj
   set the rect of tObj to kPlayLeft, kNarratorTop, kPlayRight, kNarratorTop + 188
   set the opaque of tObj to true
   set the backgroundColor of tObj to lkDarkLiteral("255,255,255", "fill")
   set the showBorder of tObj to true
   set the threeD of tObj to false
   set the borderColor of tObj to lkColor("orange")
   set the borderWidth of tObj to 1
   set the margins of tObj to 12
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the cThumb of tObj to "lessonThumb"
   hide tObj
   put lkBox("lessonThumb", lkR(kPlayRight - 7, kNarratorTop + 8, kPlayRight - 4, kNarratorTop + 48), lkColor("muted"), 2, "Narration") into tObj
   hide tObj
   shareText "Narration", "Title,Progress,Lesson"
   placeOnLessons "Narration"
end buildNarration

-- A field made in a group has a text of its own on each card: those of a
-- background group that are the same on every card share theirs (a
-- button's label too), but for those named in pPerCard
private command shareText pGroup, pPerCard
   local tIndex, tObj
   repeat with tIndex = 1 to the number of controls of group pGroup
      put the long id of control tIndex of group pGroup into tObj
      if word 1 of tObj is "field" and the short name of tObj is not among the items of pPerCard then
         set the sharedText of tObj to true
      end if
   end repeat
end shareText

-- A background group, made on the first lesson's card, on the others too
private command placeOnLessons pGroup
   local tIndex
   repeat with tIndex = 2 to the number of items of kLessons
      place group pGroup of card (item 1 of kLessons) onto card (item tIndex of kLessons)
   end repeat
end placeOnLessons

-- Each lesson's own texts in the backgrounds' fields: Terry's notes, in
-- the look of Learn's pages; his narration; and his title of the lesson
private command lessonTexts pIndex
   local tName, tLesson
   put item pIndex of kLessons into tName
   set the htmlText of field "Info" of card tName to notesHtml(lessonText(pIndex, "Info"))
   put lessonText(pIndex, "Lesson") into tLesson
   set the text of field "Lesson" of card tName to tLesson
   set the text of field "Title" of card tName to "(" & pIndex & ")" && tName
   set the text of field "Progress" of card tName to the number of lines of tLesson && "paragraphs, one at each click"
end lessonTexts

################################################################################
#
# Terry's notes, in the look of Learn's pages
#

-- His notes as htmlText: the lesson's name large, his "o" headings with a
-- bullet in the accent, "Try It." in the accent, numbered steps hanging,
-- code in the code font on a tinted band, and his "====" rules thin lines. The
-- words are his, and each line stays a line, so that a script that counts
-- the lines of field "Info" (lesson 3 has you do it) counts his. The code
-- is in Source Code Pro, which the IDE has; the stack script puts it in
-- the font of the scripts panel where that is another
private function notesHtml pText
   local tHtml, tLine, tInk, tAccent, tSpaces, tIndent
   put lkColor("ink") into tInk
   put lkColor("orange") into tAccent
   set the caseSensitive to true
   repeat for each line tLine in pText
      if word 1 to -1 of tLine is empty then
         put "<p></p>" after tHtml
      else if tLine begins with "Welcome To" then
         put "<p>" & htmlFont(lkEscape(tLine), 12, tAccent, true) & "</p>" after tHtml
      else if matchText(tLine, "^Lesson [0-9]+:") then
         put "<p>" & htmlFont(lkEscape(tLine), 18, tInk, true) & "</p>" after tHtml
      else if char 1 to 3 of tLine is "===" then
         put "<p align=" & quote & "center" & quote & " spaceabove=" & quote & "4" & quote & "><img src=" & quote & sRuleImage & quote & "></p>" after tHtml
      else if char 1 to 2 of tLine is "o " then
         -- (his "o" was a bullet: it is one here)
         put "<p>" & htmlFont(numToCodepoint(8226), 15, tAccent, true) & \
               htmlFont(" " & lkEscape(char 3 to -1 of tLine), 15, tInk, true) & "</p>" after tHtml
      else if tLine is "Try It." then
         put "<p>" & htmlFont(lkEscape(tLine), 14, tAccent, true) & "</p>" after tHtml
      else if notesIsCode(tLine) then
         -- (a line too long for the notes goes on below itself, further
         -- in than its own indent, as in the scripts panel)
         put 0 into tSpaces
         repeat while char tSpaces + 1 of tLine is space
            add 1 to tSpaces
         end repeat
         put (tSpaces + 3) * 7 into tIndent
         put "<p bgcolor=" & quote & "#f1f5f9" & quote & " padding=" & quote & "3" & quote & " firstindent=" & quote & -tIndent & quote & \
               " leftindent=" & quote & tIndent & quote & " rightindent=" & quote & "6" & quote & "><font face=" & quote & "Source Code Pro" & quote & \
               " size=" & quote & "12" & quote & ">" & \
               notesCodeHtml(tLine) & "</font></p>" after tHtml
      else if matchText(tLine, "^[0-9]+\. ") then
         put "<p firstindent=" & quote & "-18" & quote & " leftindent=" & quote & "18" & quote & ">" & lkEscape(tLine) & "</p>" after tHtml
      else
         put "<p>" & lkEscape(tLine) & "</p>" after tHtml
      end if
   end repeat
   set the caseSensitive to false
   return tHtml
end notesHtml

-- A line of code in the notes: one that is indented, or that begins with
-- a word of the language, small, as code is written (his prose begins
-- with a capital); "put" and the like alone on a line are words to look
-- up in the Dictionary, and are code too
private function notesIsCode pLine
   set the caseSensitive to true
   if char 1 of pLine is space then
      return true
   end if
   return word 1 of pLine is among the items of "on,end,put,set,get,ask,answer,if,else"
end notesIsCode

-- Code, in colour on a light band: the first word of a line (a command, or
-- on and end), strings and comments
private function notesCodeHtml pLine
   local tOut, tPos, tLen, tStart, tFirst
   put the number of chars of pLine into tLen
   put 1 into tPos
   repeat while tPos <= tLen and char tPos of pLine is space
      put space after tOut
      add 1 to tPos
   end repeat
   put true into tFirst
   repeat while tPos <= tLen
      if char tPos of pLine is quote then
         put tPos into tStart
         add 1 to tPos
         repeat while tPos <= tLen and char tPos of pLine is not quote
            add 1 to tPos
         end repeat
         put htmlFont(lkEscape(char tStart to tPos of pLine), empty, "180,83,9", false) after tOut
         add 1 to tPos
      else if char tPos to tPos + 1 of pLine is "--" then
         put htmlFont(lkEscape(char tPos to tLen of pLine), empty, "100,116,139", false) after tOut
         exit repeat
      else if tFirst and char tPos of pLine is not space then
         put tPos into tStart
         repeat while tPos <= tLen and char tPos of pLine is not space
            add 1 to tPos
         end repeat
         put htmlFont(lkEscape(char tStart to tPos - 1 of pLine), empty, "124,58,237", false) after tOut
         put false into tFirst
      else
         put lkEscape(char tPos of pLine) after tOut
         add 1 to tPos
      end if
   end repeat
   return tOut
end notesCodeHtml

private function htmlFont pText, pSize, pColor, pBold
   local tOut
   put "<font" into tOut
   if pSize is not empty then
      put " size=" & quote & pSize & quote after tOut
   end if
   put " color=" & quote & lkHex(pColor) & quote & ">" & pText & "</font>" after tOut
   if pBold then
      put "<b>" & tOut & "</b>" into tOut
   end if
   return tOut
end htmlFont

################################################################################
#
# The lessons' cards: a canvas to try things on, and Terry's things on it
#

-- The canvas at the left of a lesson's stage: a rounded square, dotted
-- where there is room to play (pDots), with a word at its top that says
-- what it is for, and a hint at its foot
private command buildCanvas pWord, pHint, pDots
   local tObj, tBottom
   put kCanvasBottom - kCanvasTop - 10 into tBottom
   if pHint is not empty then
      -- (the hint's row has no dots: they would run through its words)
      subtract 32 from tBottom
   end if
   if not pDots then
      put 0 into tBottom
   end if
   put lkDrawing("Canvas", canvasSvg(kPlayRight - kPlayLeft, kCanvasBottom - kCanvasTop, tBottom), \
         lkR(kPlayLeft, kCanvasTop, kPlayRight, kCanvasBottom), empty) into tObj
   put lkLabel("canvasWord", lkR(kPlayLeft + 16, kCanvasTop + 13, kPlayRight - 16, kCanvasTop + 27), pWord, 11, lkColor("orange"), empty) into tObj
   set the textStyle of tObj to "bold"
   if pHint is not empty then
      put lkLabel("canvasHint", lkR(kPlayLeft + 16, kCanvasBottom - 30, kPlayRight - 16, kCanvasBottom - 12), pHint, 12, lkColor("muted"), empty) into tObj
      set the dontWrap of tObj to true
   end if
end buildCanvas

-- The canvas's drawing: its dots in rows from under its word down to
-- pDotsBottom (none for 0)
private function canvasSvg pWidth, pHeight, pDotsBottom
   local tSvg, tX, tY
   put "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 " & pWidth & " " & pHeight & "'>" & \
         "<rect x='0.5' y='0.5' width='" & (pWidth - 1) & "' height='" & (pHeight - 1) & "' rx='14' fill='#f8fafc' stroke='" & \
         lkHex(lkColor("line")) & "'/>" into tSvg
   repeat with tY = 42 to pDotsBottom step 16
      -- (a repeat with a step can go one step past its end: no dot below it)
      if tY > pDotsBottom then exit repeat
      repeat with tX = 18 to pWidth - 10 step 16
         put "<circle cx='" & tX & "' cy='" & tY & "' r='1.2' fill='#d5dde7'/>" after tSvg
      end repeat
   end repeat
   return tSvg & "</svg>"
end canvasSvg

-- One of a lesson's buttons: a real button, as Terry's was (the lessons
-- are about buttons), flat, in his orange, with a soft shadow
private function lessonButton pName, pRect
   local tObj
   create button pName
   put it into tObj
   set the style of tObj to "rectangle"
   set the showBorder of tObj to false
   set the opaque of tObj to true
   set the backgroundColor of tObj to lkColor("orange")
   set the hiliteColor of tObj to lkMix(lkColor("orange"), lkColor("ink"), 0.25)
   set the textColor of tObj to lkDarkLiteral("255,255,255", "ink")
   set the textSize of tObj to 14
   set the textStyle of tObj to "bold"
   set the traversalOn of tObj to false
   set the rect of tObj to pRect
   lkShadow tObj, 12, 4, 22
   return tObj
end lessonButton

-- One of a lesson's fields, as Terry's were: locked (a click runs its
-- script), flat, in a colour, with a soft shadow
private function lessonField pName, pRect, pText, pBack, pInk, pSize
   local tObj
   create field pName
   put it into tObj
   set the lockText of tObj to true
   set the traversalOn of tObj to false
   set the autoHilite of tObj to false
   set the showBorder of tObj to false
   set the showFocusBorder of tObj to false
   set the opaque of tObj to true
   set the backgroundColor of tObj to pBack
   set the textColor of tObj to pInk
   set the textSize of tObj to pSize
   set the rect of tObj to pRect
   set the text of tObj to pText
   lkShadow tObj, 12, 4, 16
   return tObj
end lessonField

-- (its text in the middle, up and down, as a button's label is)
private command middleText pObj
   local tSpace
   set the margins of pObj to "8,0,8,0"
   put max(0, (the height of pObj - the formattedHeight of pObj) div 2) into tSpace
   set the margins of pObj to "8," & tSpace & ",8,0"
end middleText

-- 1. Orientation: My First Button and My First Field
private command buildOrientation
   local tObj
   go card "Orientation"
   buildCanvas "TRY IT", "Drag a button here from the Tools palette.", true
   put lessonButton("My First Button", lkR(kPlayLeft + 16, kCanvasTop + 40, kPlayLeft + 216, kCanvasTop + 84)) into tObj
   set the script of tObj to exScript("Orientation/My First Button")
   -- (his field said its name on its second line, a line down to sit in
   -- the middle: here the margin puts it there)
   put lessonField("Field Test", lkR(kPlayLeft + 16, kCanvasTop + 98, kPlayLeft + 216, kCanvasTop + 142), \
         "My First Field", "187,247,208", "20,83,45", 14) into tObj
   set the textStyle of tObj to "bold"
   set the textAlign of tObj to "center"
   set the dontWrap of tObj to true
   middleText tObj
   set the script of tObj to exScript("Orientation/Field Test")
end buildOrientation

-- 2. Buttons & Fields: a radio buttons group that colours a field, and a
-- scrolling field, the lesson's two kinds of button and field
private command buildButtonsAndFields
   local tObj, tTop, tName
   go card "Buttons & Fields"
   buildCanvas "TRY IT", empty, true
   put kCanvasTop + 38 into tTop
   repeat for each item tName in "Red,Green,Blue"
      create button tName
      put it into tObj
      set the style of tObj to "radioButton"
      set the showBorder of tObj to false
      set the hiliteBorder of tObj to false
      set the traversalOn of tObj to false
      set the textSize of tObj to 14
      set the textColor of tObj to lkColor("ink")
      set the rect of tObj to kPlayLeft + 26, tTop, kPlayLeft + 116, tTop + 24
      add 28 to tTop
   end repeat
   -- (made as the lesson says: the buttons, then a group of them)
   group button "Red" and button "Green" and button "Blue"
   set the name of last group to "Colors"
   put the long id of group "Colors" into tObj
   set the radioBehavior of tObj to true
   set the showBorder of tObj to true
   set the threeD of tObj to false
   set the borderWidth of tObj to 1
   set the borderColor of tObj to "203,213,225"
   set the margins of tObj to 8
   -- (white, over the canvas's dots)
   set the backgroundColor of tObj to lkDarkLiteral("255,255,255", "fill")
   set the opaque of tObj to true
   set the hilite of button "Green" of tObj to true
   set the script of tObj to exScript("Buttons & Fields/Colors")
   put lessonField("Field Test", lkR(kPlayLeft + 140, kCanvasTop + 40, kPlayRight - 16, kCanvasTop + 132), \
         sTexts["Field Test"], "Green", empty, 14) into tObj
   set the rect of tObj to kPlayLeft + 140, the top of group "Colors", kPlayRight - 16, the bottom of group "Colors"
   set the margins of tObj to 10
   set the script of tObj to exScript("Buttons & Fields/Field Test")
   -- (the remaster's: a scrolling field, as the lesson's second Try It
   -- makes, to try before making one)
   create field "Scrolling Field"
   put it into tObj
   set the rect of tObj to kPlayLeft + 16, the bottom of group "Colors" + 12, kPlayRight - 16, kCanvasBottom - 12
   set the vScrollbar of tObj to true
   set the showBorder of tObj to true
   set the threeD of tObj to false
   set the borderWidth of tObj to 1
   set the borderColor of tObj to lkColor("line")
   set the showFocusBorder of tObj to false
   set the opaque of tObj to true
   set the backgroundColor of tObj to lkDarkLiteral("255,255,255", "fill")
   set the textSize of tObj to 12
   set the textColor of tObj to lkColor("soft")
   set the margins of tObj to "10,6,6,6"
   set the text of tObj to "A field with a vertical scrollbar: its vScrollbar property is true." & return & \
         "Its text is longer than the field can show, so drag the scrollbar, or roll the wheel over it, to read the rest." & return & \
         "Type in it too: it is not locked, so you can add more."
end buildButtonsAndFields

-- 3. Commands & Functions: the button that lists them, and the list
private command buildCommandsAndFunctions
   local tObj
   go card "Commands & Functions"
   buildCanvas "TRY IT", empty, true
   put lessonButton("Commands & Functions", lkR(kPlayLeft + 16, kCanvasTop + 36, kPlayRight - 16, kCanvasTop + 72)) into tObj
   set the script of tObj to exScript("Commands & Functions/Commands & Functions")
   -- (his list, as his button last made it; it can be selected and copied)
   put lessonField("Display", lkR(kPlayLeft + 16, kCanvasTop + 82, kPlayRight - 16, kCanvasBottom - 12), \
         sTexts["Display"], "255,255,255", lkColor("ink"), 12) into tObj
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 16
   set the margins of tObj to "12,6,12,6"
   set the showBorder of tObj to true
   set the threeD of tObj to false
   set the borderWidth of tObj to 1
   set the borderColor of tObj to lkColor("line")
   set the dropShadow of tObj to empty
   set the cThumb of tObj to "displayThumb"
   put lkBox("displayThumb", lkR(kPlayRight - 24, kCanvasTop + 90, kPlayRight - 20, kCanvasTop + 130), "203,213,225", 2, empty) into tObj
   hide tObj
end buildCommandsAndFunctions

-- 4. Script Editor: the Answer Command button, and room for yours
private command buildScriptEditor
   local tObj
   go card "Script Editor"
   buildCanvas "TRY IT", empty, true
   put lessonButton("Answer Command", lkR(kPlayLeft + 16, kCanvasTop + 40, kPlayLeft + 216, kCanvasTop + 84)) into tObj
   set the script of tObj to exScript("Script Editor/Answer Command")
   -- (where the button the lesson has you make can go)
   slotBox "Slot", "message-square-text", "Your Ask Command button", "Make it with the notes, then click it."
end buildScriptEditor

-- A place on the canvas for something to come, under the lesson's button:
-- a dashed box, with an icon at its top in the middle, and under it what
-- will be there (pTitle) and a line on it (pText). The same box and words
-- on each lesson that has one
private command slotBox pName, pIcon, pTitle, pText
   local tObj, tMid, tRect
   put lkR(kPlayLeft + 16, kCanvasTop + 100, kPlayRight - 16, kCanvasBottom - 16) into tRect
   put lkBox(pName, tRect, "255,255,255", 12, empty) into tObj
   lkBorder tObj, "203,213,225"
   set the lineSize of tObj to 2
   set the dashes of tObj to "7,6"
   put (item 1 of tRect + item 3 of tRect) div 2 into tMid
   get exIcon(pName & "Icon", pIcon, lkColor("muted"), lkR(tMid - 12, item 2 of tRect + 12, tMid + 12, item 2 of tRect + 36), empty)
   put lkLabel(pName & "Text", lkR(item 1 of tRect + 8, item 2 of tRect + 46, item 3 of tRect - 8, item 2 of tRect + 94), \
         pTitle & return & pText, 12, lkColor("muted"), empty, "center") into tObj
   set the textStyle of line 1 of tObj to "bold"
   set the textSize of line 1 of tObj to 13
end slotBox

-- 5. Dictionary & User Guide: If-Then-Else, and the forecast it writes
private command buildDictionary
   local tObj
   go card "Dictionary & User Guide"
   buildCanvas "TRY IT", empty, true
   put lessonButton("If-Then-Else", lkR(kPlayLeft + 16, kCanvasTop + 40, kPlayLeft + 216, kCanvasTop + 84)) into tObj
   set the script of tObj to exScript("Dictionary & User Guide/If-Then-Else")
   -- (where the forecast shows, while it is hidden)
   slotBox "ForecastSlot", "cloud-sun", "Your forecast shows here", "Click it, and it hides again."
   -- (as wide as the canvas, and tall enough for four lines: a long date
   -- in a wide font takes two)
   put lessonField("Forecast", lkR(kPlayLeft + 16, kCanvasTop + 96, kPlayRight - 16, kCanvasBottom - 12), \
         sTexts["Forecast"], "224,242,254", "12,74,110", 15) into tObj
   set the textStyle of tObj to "bold"
   set the textAlign of tObj to "center"
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 20
   set the margins of tObj to "8,20,8,0"
   set the script of tObj to exScript("Dictionary & User Guide/Forecast")
   hide tObj
end buildDictionary

-- 6. Background Group: nothing of Terry's to try here, so a picture of
-- what the lesson says, in this window: three of its cards, each with the
-- same sidebar, the group "Frame"
private command buildBackgroundGroup
   local tObj, tIndex, tLeft
   go card "Background Group"
   buildCanvas "IN THIS WINDOW", empty, false
   put lkDrawing("Cards", backgroundSvg(), lkR(kPlayLeft + 16, kCanvasTop + 36, kPlayRight - 16, kCanvasTop + 140), empty) into tObj
   repeat with tIndex = 1 to 3
      put kPlayLeft + 16 + (tIndex - 1) * 98 into tLeft
      put lkLabel("CardsWord" & tIndex, lkR(tLeft, kCanvasTop + 146, tLeft + 84, kCanvasTop + 160), "Card" && tIndex, 11, lkColor("muted"), empty, "center") into tObj
   end repeat
   put lkLabel("CardsText", lkR(kPlayLeft + 16, kCanvasTop + 168, kPlayRight - 16, kCanvasBottom - 10), \
         "The sidebar is one group, on every card: its backgroundBehavior is true.", \
         12, lkColor("soft"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 17
end buildBackgroundGroup

-- Three small cards of this window: the sidebar (the same on each, ringed
-- in the accent), and on each a different thing
private function backgroundSvg
   local tSvg, tIndex, tX, tAccent, tSide
   put lkHex(lkColor("orange")) into tAccent
   put lkHex(lkColor("side")) into tSide
   put "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 280 104'>" into tSvg
   repeat with tIndex = 0 to 2
      put tIndex * 98 into tX
      put "<rect x='" & tX + 1 & "' y='1' width='82' height='102' rx='8' fill='#ffffff' stroke='#cbd5e1'/>" after tSvg
      put "<path d='M" & tX + 9 & " 1h14v102h-14a8 8 0 0 1-8-8v-86a8 8 0 0 1 8-8z' fill='" & tSide & "'/>" after tSvg
      put "<rect x='" & tX + 6 & "' y='14' width='12' height='3' rx='1.5' fill='#94a3b8'/>" after tSvg
      put "<rect x='" & tX + 6 & "' y='" & 24 + tIndex * 10 & "' width='12' height='3' rx='1.5' fill='" & tAccent & "'/>" after tSvg
      put "<rect x='" & tX + 6 & "' y='54' width='12' height='3' rx='1.5' fill='#94a3b8'/>" after tSvg
      put "<rect x='" & tX + 6 & "' y='64' width='12' height='3' rx='1.5' fill='#94a3b8'/>" after tSvg
      put "<rect x='" & tX + 0.5 & "' y='0.5' width='24' height='103' rx='8.5' fill='none' stroke='" & tAccent & "' stroke-width='1.5'/>" after tSvg
      put "<rect x='" & tX + 32 & "' y='12' width='36' height='5' rx='2.5' fill='#0f172a'/>" after tSvg
      switch tIndex
         case 0
            put "<rect x='" & tX + 32 & "' y='30' width='40' height='16' rx='3' fill='" & tAccent & "'/>" after tSvg
            put "<rect x='" & tX + 32 & "' y='52' width='40' height='16' rx='3' fill='#bbf7d0'/>" after tSvg
            break
         case 1
            put "<circle cx='" & tX + 36 & "' cy='34' r='3' fill='#94a3b8'/><rect x='" & tX + 42 & "' y='32' width='22' height='4' rx='2' fill='#cbd5e1'/>" after tSvg
            put "<circle cx='" & tX + 36 & "' cy='44' r='3' fill='" & tAccent & "'/><rect x='" & tX + 42 & "' y='42' width='26' height='4' rx='2' fill='#cbd5e1'/>" after tSvg
            put "<rect x='" & tX + 32 & "' y='56' width='42' height='22' rx='3' fill='#4ade80'/>" after tSvg
            break
         default
            put "<rect x='" & tX + 32 & "' y='30' width='42' height='4' rx='2' fill='#cbd5e1'/>" after tSvg
            put "<rect x='" & tX + 32 & "' y='40' width='34' height='4' rx='2' fill='#cbd5e1'/>" after tSvg
            put "<rect x='" & tX + 32 & "' y='50' width='40' height='4' rx='2' fill='#cbd5e1'/>" after tSvg
            put "<rect x='" & tX + 32 & "' y='64' width='30' height='14' rx='3' fill='" & tAccent & "'/>" after tSvg
      end switch
   end repeat
   return tSvg & "</svg>"
end backgroundSvg

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Quick Start Guide: Terry Little's Quick Start v1.5, remastered for OXT-Beyond in 2026
--Quick Start v1.5, Terry Little (c)2024, All Rights Reserved
--This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
--as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--This program is distributed in the hope that it will be useful, but without any warranty; without even the implied warranty of
--merchantability or fitness for a particular purpose. See the GNU General Public License for more details. <http://www.gnu.org/licenses/>.

--Each lesson is a card: the things to try at the left of its stage, the narrator under them, and the
--notes at the right (the field "Info"). The notes and the narrator are the background groups "Notes"
--and "Narration", as Terry's were. The sidebar, the header, the stage and the scripts drawer are the
--groups "Frame", "Workbench" and "Scripts", which the script of the group "Frame" runs.
--His bar of buttons "<Prev" and " Next>" (go prev cd and go next cd, with a quick dissolve) is
--the sidebar here: its Back and Next, and the arrow keys, go from lesson to lesson. His field
--"Title" heads the narrator.

on preOpenCard
   if there is a fld "Title" then put "("& (the number of this cd - 1) &")"&& the short name of this cd into fld "Title"  --the front page is card 1, so lesson 1 is card 2
   if there is a fld "Info" then set the vScroll of fld "Info" to "0"  --top
   if there is a grp "Narrator" then set the cLine of grp "Narrator" to "1"  --start over, custom prop (the narrator is a group here)
   narratorReset  --(remaster) the narrator's words start over too
   notesCodeFont  --(remaster) the code in the notes, in the font of the scripts panel
   scrollStop  --(remaster) a scroll still going stops, so this lesson's notes stay at the top
   scrollThumbs  --(remaster) the thumbs that show how far down the notes are
end preOpenCard

--(remaster) The narrator: what it is about to read, the words it reads, and how far it is

command narratorReset
   local tError
   try
      revStopSpeech  --the last lesson's voice stops when another card opens
   catch tError  --no voice here, so nothing to stop
   end try
   if there is no fld "Said" or there is no fld "Lesson" then exit narratorReset
   set the textColor of fld "Said" to "71,85,105"  --(dark enough to read on the balloon's tint)
   put "Press Read it to me, and I will read this lesson to you, a paragraph at each click. " & \
         "Try each thing as I go." into fld "Said"
   set the vScroll of fld "Said" to 0
   put the number of lines of fld "Lesson" && "paragraphs, one at each click" into fld "Progress"
end narratorReset

command narratorShow pLine
   if there is no fld "Said" or there is no fld "Lesson" then exit narratorShow
   set the textColor of fld "Said" to "15,23,42"
   put word 1 to -1 of line pLine of fld "Lesson" into fld "Said"
   set the vScroll of fld "Said" to 0
   put "Paragraph" && pLine && "of" && the number of lines of fld "Lesson" into fld "Progress"
   scrollThumb the long id of fld "Said"
end narratorShow

command narratorNoVoice  --a computer, or a browser, that cannot speak
   if there is a fld "Progress" then
      put "  " & numToCodepoint(183) & "  no voice here" after fld "Progress"
   end if
end narratorNoVoice

command narratorStopped
   if there is a fld "Progress" and there is a grp "Narrator" then
      put "Stopped: paragraph" && the cLine of grp "Narrator" && "is next" into fld "Progress"
   end if
end narratorStopped

--(remaster) The code in the notes is in Source Code Pro, which the IDE has: where it has not got
--it, the code is in the font the scripts panel found for code

command notesCodeFont
   local tFont, tLine
   if there is no fld "Info" or there is no fld "codeText" then exit notesCodeFont
   if "Source Code Pro" is among the lines of the fontNames then exit notesCodeFont
   put the textFont of fld "codeText" into tFont
   if tFont is empty then exit notesCodeFont
   repeat with tLine = 1 to the number of lines of fld "Info"
      if the textFont of line tLine of fld "Info" is "Source Code Pro" then
         set the textFont of line tLine of fld "Info" to tFont
      end if
   end repeat
end notesCodeFont

--(remaster) The notes, the list of commands and the narrator's words scroll with the wheel, without a
--scrollbar, as the scripts panel does: a slim thumb beside each shows how far down it is, and can
--be dragged. A field that scrolls so names its thumb in its custom property cThumb.

local sGlideField, sGlideGoal, sDragField, sDragFrom, sDragScroll

on rawKeyDown pKey
   local tField
   if pKey is not 65308 and pKey is not 65309 then pass rawKeyDown
   put scrollFieldAt(the mouseLoc) into tField
   if tField is empty then pass rawKeyDown
   if pKey is 65308 then scrollBy tField, 48
   else scrollBy tField, -48
end rawKeyDown

command scrollBy pField, pAmount
   local tGoing
   put sGlideField is pField and sGlideGoal is not empty into tGoing
   if not tGoing then
      put pField into sGlideField
      put the vScroll of pField into sGlideGoal
   end if
   put max(0, min(sGlideGoal + pAmount, scrollRoom(pField))) into sGlideGoal
   if not tGoing then scrollGlide  --a glide already going goes on, to the new goal
end scrollBy

--one step of the scroll toward where the wheel is taking it
on scrollGlide
   local tNow, tStep
   if sGlideGoal is empty or sGlideField is empty or not exists(sGlideField) then exit scrollGlide
   put the vScroll of sGlideField into tNow
   put round((sGlideGoal - tNow) * 0.35) into tStep
   if abs(sGlideGoal - tNow) <= 1 or tStep is 0 then
      set the vScroll of sGlideField to sGlideGoal
      put empty into sGlideGoal
   else
      set the vScroll of sGlideField to tNow + tStep
      if the vScroll of sGlideField is tNow then
         put empty into sGlideGoal  --it goes no further: its text has changed under it
      else
         send "scrollGlide" to me in 16 milliseconds
      end if
   end if
   scrollThumb sGlideField
end scrollGlide

--a scroll still going, or a thumb still held, stops as another card opens: the notes are one
--field on every card, so a scroll left going would carry on down the next lesson's notes
command scrollStop
   put empty into sGlideGoal
   put empty into sGlideField
   put empty into sDragField
end scrollStop

--the field the pointer is over that scrolls, but under the scripts drawer
function scrollFieldAt pLoc
   local tName
   if there is a grp "Scripts" and the visible of grp "Scripts" and there is a grc "codeBg" then
      if pLoc is within the rect of grc "codeBg" then return empty
   end if
   repeat for each item tName in "Lesson,Info,Display,Said"
      if there is a fld tName then
         if the visible of fld tName and pLoc is within the rect of fld tName then
            return the long id of fld tName
         end if
      end if
   end repeat
   return empty
end scrollFieldAt

--how far down a field scrolls, as the engine has it: set further down than it goes, its vScroll
--stops at the bottom. (Its formattedHeight minus its height is a few pixels out: it counts a
--border the field does not show, and a glide toward it would never arrive.)
function scrollRoom pField
   local tNow, tRoom
   lock screen
   put the vScroll of pField into tNow
   set the vScroll of pField to the formattedHeight of pField + the height of pField
   put the vScroll of pField into tRoom
   set the vScroll of pField to tNow
   unlock screen
   return max(0, tRoom)
end scrollRoom

command scrollThumbs
   local tName
   repeat for each item tName in "Info,Display,Said,Lesson"
      if there is a fld tName then scrollThumb the long id of fld tName
   end repeat
end scrollThumbs

command scrollThumb pField
   local tThumb, tRoom, tTrack, tSize, tTop
   put the cThumb of pField into tThumb
   if tThumb is empty or there is no grc tThumb then exit scrollThumb
   put scrollRoom(pField) into tRoom
   if tRoom < 8 or not the visible of pField then
      hide grc tThumb
      exit scrollThumb
   end if
   put the height of pField - 16 into tTrack
   put max(24, round(tTrack * tTrack / (tTrack + tRoom))) into tSize
   put the top of pField + 8 + round((tTrack - tSize) * min(1, the vScroll of pField / tRoom)) into tTop
   set the rect of grc tThumb to item 1 of the rect of grc tThumb, tTop, item 3 of the rect of grc tThumb, tTop + tSize
   show grc tThumb
end scrollThumb

--the field a thumb is beside, on this card
function thumbField pThumb
   local tName
   repeat for each item tName in "Info,Display,Said,Lesson"
      if there is a fld tName then
         if the cThumb of fld tName is pThumb then return the long id of fld tName
      end if
   end repeat
   return empty
end thumbField

--a thumb, dragged: its field goes as far down as the thumb does
on mouseDown pButton
   local tField
   if pButton is 1 and word 1 of the name of the target is "graphic" then
      put thumbField(the short name of the target) into tField
      if tField is not empty then
         put tField into sDragField
         put item 2 of the mouseLoc into sDragFrom
         put the vScroll of tField into sDragScroll
         put empty into sGlideGoal
      end if
   end if
   pass mouseDown
end mouseDown

on mouseMove pX, pY
   local tTrack, tRoom
   if sDragField is empty then pass mouseMove
   if not exists(sDragField) then
      put empty into sDragField
      pass mouseMove
   end if
   put scrollRoom(sDragField) into tRoom
   put the height of sDragField - 16 - the height of grc (the cThumb of sDragField) into tTrack
   if tTrack > 0 then
      set the vScroll of sDragField to max(0, min(tRoom, sDragScroll + round((pY - sDragFrom) * tRoom / tTrack)))
      scrollThumb sDragField
   end if
   pass mouseMove
end mouseMove

on mouseUp pButton
   put empty into sDragField
   pass mouseUp
end mouseUp

on mouseRelease pButton
   put empty into sDragField
   pass mouseRelease
end mouseRelease

--a field's thumb, as the pointer comes to it (a script may have changed its text)
on mouseEnter
   local tObj
   put the long id of the target into tObj
   if word 1 of tObj is "field" then
      if the cThumb of tObj is not empty then scrollThumb tObj
   end if
   pass mouseEnter
end mouseEnter
@*/

/*@ Narrator
--lesson 1: 5:30, voice: microsoft david
on mouseUp  --speak text one line at a time
   local tLesson, tLine, tError
   if shiftKey() = "down" then  --edit fld
      set the visible of fld "Lesson" to not the visible of fld "Lesson"  --toggle show/hide
      scrollThumbs  --(remaster) its thumb, shown or hidden with it: see the stack script
      exit to top
   end if
   put fld "Lesson" into tLesson
   put the cLine of me into tLine  --custom prop for line count
   narratorShow tLine  --(remaster) the words of this line, in the balloon: see the stack script
   try  --(remaster) where there is no voice, the narrator says so, and its words are there to read
      revSetSpeechSpeed "165"  --1-300, 150=slow, 180=fast
      revSpeak line tLine of tLesson  --custom prop for line count
   catch tError
      narratorNoVoice
   end try
   if tLine >= number(lines in tLesson) then set the cLine of me to "1"  --start over
   else set the cLine of me to tLine + 1  --next line/paragraph
end mouseUp
@*/

/*@ Stop
on mouseUp  --(remaster) stop the narrator
   local tError
   try
      revStopSpeech
   catch tError  --no voice here, so nothing to stop
   end try
   narratorStopped  --see the stack script
end mouseUp
@*/

/*@ Orientation/My First Button
on mouseUp
   answer "Please follow the Try It lessons in the scrolling field." with "OK" titled "Orientation"
end mouseUp
@*/

/*@ Orientation/Field Test
on mouseUp
   answer "A locked field can receive a mouseUp message and act like a button." with "OK" titled "Orientation"
end mouseUp
@*/

/*@ Buttons & Fields/Colors
on mouseUp  --radio buttons group
   set the backColor of fld "Field Test" to the hilitedButtonName of me  --name of selected button
   --(remaster) and its text, in the color that reads best on that one
   if the hilitedButtonName of me is "Blue" then set the textColor of fld "Field Test" to "white"
   else set the textColor of fld "Field Test" to "black"
end mouseUp
@*/

/*@ Buttons & Fields/Field Test
on mouseUp
   answer "Object properties can be changed by the user with code." with "OK" titled "Buttons & Fields"
end mouseUp
@*/

/*@ Commands & Functions/Commands & Functions
on mouseUp  --display all commands or functions
   local tNames  --declare temporary container
   answer "Display all Commands or all Functions?" with "Cancel" or "Functions" or "Commands" titled "Display"
   if it = "Cancel" then exit to top  --stop executing code
   if it = "Commands" then
      put the commandNames into tNames
      filter tNames without "_*"  --(remaster) the engine's own names begin with "_": they are not for you
      put the number of lines in tNames && "Commands:" &cr& tNames into fld "Display"  --cr = carriage return
   else if it = "Functions" then
      put the functionNames into tNames
      filter tNames without "_*"  --(remaster) the same for functions
      put the number of lines in tNames && "Functions:" &cr& tNames into fld "Display"
   end if
end mouseUp
@*/

/*@ Script Editor/Answer Command
on mouseUp  --answer command
   answer "Please make a choice between Red or Green." with "Cancel" or "Green" or "Red" titled "Make A Choice"
   if it = "Cancel" then exit to top
   if it = "Red" then answer "You chose the Red button." with "OK" titled "Red Choice"
   else if it = "Green" then answer "Green was the button you chose." with "OK" titled "Green Choice"
end mouseUp
@*/

/*@ Dictionary & User Guide/If-Then-Else
on mouseUp  --if-then-else conditional structure
   answer info "What is the weather like today?" with "Cancel" or "Rainy" or "Cloudy" or "Sunny" titled "Weather"
   if it = "Cancel" then exit to top
   if it = "Rainy" then
      put the abbrev date &cr& "Weather Forecast" &cr& it into fld "Forecast"
   else if it = "Cloudy" then
      put the short date &cr& "Today's Weather" &cr& it into fld "Forecast"
   else if it = "Sunny" then
      put the long date &cr& "Today will be:" &cr& it into fld "Forecast"
   end if
   show fld "Forecast"
end mouseUp
@*/

/*@ Dictionary & User Guide/Forecast
on mouseUp  --hide
   lock screen for visual effect
   hide me
   unlock screen with visual effect "dissolve" fast to card  --quoted, for strict compilation mode
end mouseUp
@*/
