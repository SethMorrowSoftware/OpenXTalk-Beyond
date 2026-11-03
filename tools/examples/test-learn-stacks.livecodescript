script "OXTTestLearnStacks"
-- OXT-Beyond: runs every lesson of the built "Learn" stacks of the xTalk
-- Suite's extensions (Learn SodiumXT and the others that
-- builder.livecodescript's exLearn handlers make) on a real engine, with
-- each stack's extension loaded, and fails if one does not do what it
-- says.
--
--    <install>/OXT-Beyond -ui tools/examples/test-learn-stacks.livecodescript
--
-- (on Linux, under xvfb-run where there is no display). It tests the
-- stacks named in OXT_LEARN_STACKS (paths, comma separated), or else every
-- ide/Resources/Examples/Remastered/Learn *.oxtstack whose front card is a
-- Learn stack's (Learn Box2D has a test of its own), and loads each
-- stack's extensions from the install it runs in (or the one in
-- OXT_INSTALL), as the stack's custom property cLoad says. For each:
--
--    the front page says that the extension is loaded
--    on each lesson: the script shown is the lesson's, every line of it
--    fits the code panel without going on below itself, all of it fits
--    the panel without scrolling, and Run gives a
--    result that matches the lesson's cExpect, every line of which fits
--    the field "Result" and all of it without scrolling; it does twice,
--    and each call in the lesson's list
--    opens its page of the reference
--    on one lesson: Copy puts the script on the clipboard; an edit, then
--    Reset, puts the lesson's own script back; a script that does not
--    compile, and one that stops, say so in the field "Result" and where
--    the Reference card: it lists every handler of the extension, each
--    has a page, every link in a page goes to a handler or a card, and a
--    search finds a handler by a word of its page
--    the sidebar, on every card: the pill that marks where you are is
--    on that card's own line, and only that line's title is white
--    in the light look and the dark: every colour of every word the group
--    "Learn" shows (its lesson, a page of the reference, the Reference
--    card) is 4.5 to 1 or more from the colour under it, the WCAG's ratio
--    for text that has to be read
--
-- With OXT_LEARN_NOLOAD set, it loads no extension, and checks instead that
-- the front page and Run say that the extension is not loaded, as they do
-- where it is not installed.
--
-- It writes a line for each check that fails, a line PASS or FAIL for each
-- stack, and ends with "DONE" (exit code 0) or "FAILED <how many>" (exit
-- code 1). With OXT_LEARN_SNAPS set to a folder, it saves a picture of each
-- card there after its lesson has run.

-- The failures of the stack being tested
local sFails
-- Whether the stack is to be in its dark look (revIDEAppearanceIsDark, as
-- the stacks ask the IDE, answers it while this script is in the back)
local sTestDark

on startup
   local tStacks, tInstall, tStack, tError, tFailed, tRepo
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put $OXT_INSTALL into tInstall
   if tInstall is empty then
      put the engine folder into tInstall
   end if
   put $OXT_LEARN_STACKS into tStacks
   if tStacks is empty then
      put learnStacksIn(tRepo & "/ide/Resources/Examples/Remastered") into tStacks
   end if
   if tStacks is empty then
      write "FAILED no Learn stacks to test" & return to stdout
      quit 1
   end if
   put 0 into tFailed
   -- (the stacks ask the IDE whether the desktop is dark: this answers)
   put false into sTestDark
   insert the script of me into back
   repeat for each item tStack in tStacks
      put empty into sFails
      try
         testStack tStack, tInstall
      catch tError
         replace return with " | " in tError
         fail "stopped:" && tError
      end try
      if sFails is empty then
         write "PASS" && tStack & return to stdout
      else
         write "FAIL" && tStack & return to stdout
         add 1 to tFailed
      end if
   end repeat
   if tFailed > 0 then
      write "FAILED" && tFailed & return to stdout
      quit 1
   end if
   write "DONE" & return to stdout
   quit 0
end startup

-- The Learn stacks in a folder, but Learn Box2D
private function learnStacksIn pFolder
   local tFiles, tFile, tOut
   put files(pFolder) into tFiles
   repeat for each line tFile in tFiles
      if tFile begins with "Learn " and tFile ends with ".oxtstack" and tFile is not "Learn Box2D.oxtstack" then
         put pFolder & "/" & tFile & comma after tOut
      end if
   end repeat
   delete the last char of tOut
   return tOut
end learnStacksIn

private command fail pWhat
   put pWhat & return after sFails
   write "  FAIL" && pWhat & return to stdout
end fail

private command check pOk, pWhat
   if pOk is not true then
      fail pWhat
   end if
end check

################################################################################

private command testStack pPath, pInstall
   local tStack, tCard, tLesson, tLoaded
   if there is no file pPath then
      throw "no stack " & pPath
   end if
   put $OXT_LEARN_NOLOAD is empty into tLoaded
   if tLoaded then
      loadExtensions the cLoad of stack pPath, pInstall
   end if
   go stack pPath
   put the short name of stack pPath into tStack
   write "STACK" && tStack & return to stdout
   check the cLearn of card 1 of stack tStack is "front", "card 1 is not a Learn stack's front page"
   -- The front page
   go card 1 of stack tStack
   pump 100
   if tLoaded then
      check field "learnStatus" of card 1 of stack tStack contains "is loaded", \
            "the front page says: " & field "learnStatus" of card 1 of stack tStack
   else
      check field "learnStatus" of card 1 of stack tStack contains "is not loaded", \
            "the front page says, with nothing loaded: " & field "learnStatus" of card 1 of stack tStack
   end if
   snap tStack, 1
   put empty into tLesson
   repeat with tCard = 2 to the number of cards of stack tStack
      switch the cLearn of card tCard of stack tStack
         case "lesson"
            if tLoaded then
               testLesson tStack, tCard
            else
               testNotLoaded tStack, tCard
            end if
            if tLesson is empty then
               put tCard into tLesson
            end if
            break
         case "reference"
            testReference tStack, tCard
            break
         default
            fail "card" && tCard && "is neither a lesson nor the Reference"
      end switch
   end repeat
   if tLoaded and tLesson is not empty then
      testButtons tStack, tLesson
   end if
   testSidebar tStack
   testReadable tStack, tLesson, "dark"
   testReadable tStack, tLesson, "light"
   go card 1 of stack tStack
end testStack

-- The desktop's look as the stacks see it: see sTestDark
function revIDEAppearanceIsDark
   return sTestDark is true
end revIDEAppearanceIsDark

-- Loads the extensions as the stack's cLoad says, from the install
private command loadExtensions pLoad, pInstall
   local tLine, tFolder, tLibrary
   set the itemDelimiter to "|"
   repeat for each line tLine in pLoad
      put pInstall & "/Extensions/" & item 2 of tLine into tFolder
      if there is no folder tFolder then
         throw "no " & item 2 of tLine & " in " & pInstall & "/Extensions"
      end if
      if item 1 of tLine is "lcb" then
         switch the platform
            case "Linux"
               put tFolder & "/code/x86_64-linux/" & item 3 of tLine & ".so" into tLibrary
               break
            case "Win32"
               put tFolder & "/code/x86_64-win32/" & item 3 of tLine & ".dll" into tLibrary
               break
            default
               put tFolder & "/code/universal-mac/" & item 3 of tLine & ".dylib" into tLibrary
         end switch
         set the revLibraryMapping[item 3 of tLine] to tLibrary
         load extension from file (tFolder & "/module.lcm") with resource path tFolder
      else
         -- (a script library: its stack, as the IDE starts using it)
         start using stack (tFolder & "/" & item 3 of tLine)
      end if
   end repeat
   set the itemDelimiter to comma
end loadExtensions

-- Lets the engine draw, and run what it was sent
private command pump pMilliseconds
   wait pMilliseconds milliseconds with messages
end pump

private command snap pStack, pCard
   local tFolder
   put $OXT_LEARN_SNAPS into tFolder
   if tFolder is empty then
      exit snap
   end if
   if there is no folder tFolder then
      create folder tFolder
   end if
   export snapshot from card pCard of stack pStack to file (tFolder & "/" & pStack & "-" & format("%02d", pCard) & ".png") as PNG
end snap

################################################################################
#
# A lesson
#

private command testLesson pStack, pCard
   local tName, tGroup, tExpect, tRun, tCall, tCalls
   go card pCard of stack pStack
   pump 50
   put the short name of this card into tName
   put the long id of group "Learn" of card pCard of stack pStack into tGroup
   put the cExpect of this card into tExpect
   check tExpect is not empty, tName & ": no expected result (cExpect)"
   check the text of field "lessonScript" of tGroup is the cScript of this card, \
         tName & ": the script shown is not the lesson's"
   checkFits tName, the long id of field "lessonScript" of tGroup, "a line of the script"
   check the formattedHeight of field "lessonScript" of tGroup <= the height of field "lessonScript" of tGroup, \
         tName & ": the script is taller than its panel (" & the formattedHeight of field "lessonScript" of tGroup & \
         " pixels for " & the height of field "lessonScript" of tGroup & ")"
   check the visible of group "lessonPart" of tGroup and not the visible of group "refPart" of tGroup, \
         tName & ": the lesson's half of the Learn group does not show"
   repeat with tRun = 1 to 2
      dispatch "learnRun" to tGroup
      pump 20
      check matchText(the text of field "Result" of tGroup, tExpect), \
            tName & ", run" && tRun & ": the result" && quote & the text of field "Result" of tGroup & quote && \
            "does not match" && tExpect
   end repeat
   checkFits tName, the long id of field "Result" of tGroup, "a line of the result"
   check the formattedHeight of field "Result" of tGroup <= the height of field "Result" of tGroup, \
         tName & ": the result is taller than its panel (" & the formattedHeight of field "Result" of tGroup & \
         " pixels for " & the height of field "Result" of tGroup & ")"
   snap pStack, pCard
   -- Each call in the list opens its page
   put the text of field "lessonCalls" of tGroup into tCalls
   check word 1 of tCalls is "CALLS", tName & ": the calls do not start with CALLS"
   repeat for each word tCall in tCalls
      if tCall is "CALLS" or "(" is in tCall or ")" is in tCall then
         next repeat
      end if
      dispatch "learnExplain" to tGroup with tCall
      check the visible of group "lessonSheet" of tGroup, tName & ": " & tCall & " opens no page"
      check the text of field "sheetText" of tGroup begins with tCall, \
            tName & ": the page of " & tCall & " is not its own: " & line 1 of the text of field "sheetText" of tGroup
      dispatch "learnSheet" to tGroup with false
   end repeat
   check not the visible of group "lessonSheet" of tGroup, tName & ": Back to the script leaves the page open"
end testLesson

-- Every line of the field pField fits it, without going on below itself
private command checkFits pName, pField, pWhat
   local tLine, tRoom
   -- the margins are one number for all four sides, or four
   if the number of items of the margins of pField is 1 then
      put the width of pField - 2 * the margins of pField - 4 into tRoom
   else
      put the width of pField - item 1 of the margins of pField - item 3 of the margins of pField - 4 into tRoom
   end if
   repeat with tLine = 1 to the number of lines of pField
      if the formattedWidth of line tLine of pField > tRoom then
         fail pName & ": " & pWhat & " is too wide (" & the formattedWidth of line tLine of pField & \
               " pixels for " & tRoom & "): " & line tLine of pField
      end if
   end repeat
end checkFits

-- Copy, Reset, and a script that does not compile or that stops
private command testButtons pStack, pCard
   local tGroup, tName, tScript
   go card pCard of stack pStack
   pump 50
   put the short name of this card into tName
   put the long id of group "Learn" of card pCard of stack pStack into tGroup
   put the cScript of this card into tScript
   -- Copy
   -- (a sentinel, not empty: setting it to empty can throw "can't set property")
   set the clipboardData["text"] to "(nothing copied yet)"
   dispatch "learnCopy" to tGroup
   check the clipboardData["text"] is tScript, tName & ": Copy did not put the script on the clipboard"
   check field "Result" of tGroup contains "Paste it into the script of a button", tName & ": Copy does not say how to use it"
   -- An edit, then Reset
   put "on mouseUp" & return & "   put 6 * 7 into field " & quote & "Result" & quote & return & "end mouseUp" into field "lessonScript" of tGroup
   dispatch "learnRun" to tGroup
   check field "Result" of tGroup is 42, tName & ": an edited script did not run: " & field "Result" of tGroup
   dispatch "learnReset" to tGroup
   check the text of field "lessonScript" of tGroup is tScript, tName & ": Reset did not put the lesson's script back"
   -- A script that does not compile
   put "on mouseUp" & return & "   put into" & return & "end mouseUp" into field "lessonScript" of tGroup
   dispatch "learnRun" to tGroup
   check field "Result" of tGroup contains "does not compile, at line 2", \
         tName & ": a script that does not compile says: " & field "Result" of tGroup
   -- A script that stops
   put "on mouseUp" & return & "   local tA" & return & "   put 1 into tA" & return & \
         "   put tA + " & quote & "x" & quote & " into tA" & return & "end mouseUp" into field "lessonScript" of tGroup
   dispatch "learnRun" to tGroup
   check field "Result" of tGroup contains "stopped at line 4", \
         tName & ": a script that stops says: " & field "Result" of tGroup
   -- A script that puts nothing into the field
   put "on mouseUp" & return & "end mouseUp" into field "lessonScript" of tGroup
   dispatch "learnRun" to tGroup
   check field "Result" of tGroup contains "put nothing into field", \
         tName & ": a script that shows nothing says: " & field "Result" of tGroup
   dispatch "learnReset" to tGroup
   check the text of field "lessonScript" of tGroup is tScript, tName & ": Reset did not put the lesson's script back"
end testButtons

-- Without the extension, a lesson says so
private command testNotLoaded pStack, pCard
   local tGroup
   go card pCard of stack pStack
   pump 20
   put the long id of group "Learn" of card pCard of stack pStack into tGroup
   dispatch "learnRun" to tGroup
   check field "Result" of tGroup contains "is not loaded", \
         the short name of this card & ": with nothing loaded, Run says: " & field "Result" of tGroup
end testNotLoaded

################################################################################
#
# The Reference card
#

private command testReference pStack, pCard
   local tGroup, tNames, tName, tDocs, tKey, tPage, tLinks, tLink, tCount, tFound
   go card pCard of stack pStack
   pump 50
   put the long id of group "Learn" of card pCard of stack pStack into tGroup
   check the visible of group "refPart" of tGroup and not the visible of group "lessonPart" of tGroup, \
         "Reference: the reference's half of the Learn group does not show"
   put the cDocNames of stack pStack into tNames
   check the number of lines of tNames > 0, "Reference: no handlers"
   check the text of field "refList" of tGroup is tNames, "Reference: the list is not every handler"
   check field "refText" of tGroup is not empty, "Reference: no page shows"
   dispatch function "learnDocs" to tGroup
   put the result into tDocs
   check the number of lines of the keys of tDocs is the number of lines of tNames, \
         "Reference:" && the number of lines of the keys of tDocs && "pages for" && the number of lines of tNames && "handlers"
   put 0 into tCount
   repeat for each line tName in tNames
      put tolower(tName) into tKey
      put tDocs[tKey] into tPage
      check tPage is not empty, "Reference: " & tName & " has no page"
      -- (every link goes somewhere)
      repeat for each item tLink in pageLinks(tPage)
         add 1 to tCount
         if tLink begins with "card:" then
            check there is a card (char 6 to -1 of tLink) of stack pStack, "Reference: the page of " & tName & " links to no card " & tLink
         else
            check tDocs[tolower(tLink)] is not empty, "Reference: the page of " & tName & " links to no handler " & tLink
         end if
      end repeat
   end repeat
   write "  " & the number of lines of tNames && "pages," && tCount && "links" & return to stdout
   -- A click on a name in the list shows its page
   dispatch "refChoose" to tGroup with 2
   check the text of field "refText" of tGroup begins with line 2 of tNames, "Reference: the second line does not show its page"
   -- A search keeps the names whose page has the words, and clears again
   put line 3 of tNames into tName
   put tName into field "refSearch" of tGroup
   dispatch "refFill" to tGroup
   set the wholeMatches to true
   check tName is among the lines of the text of field "refList" of tGroup and \
         the number of lines of field "refList" of tGroup < the number of lines of tNames, \
         "Reference: a search for " & tName & " gives: " & line 1 to 3 of field "refList" of tGroup
   check line 1 of field "refText" of tGroup is among the lines of the text of field "refList" of tGroup, \
         "Reference: after a search, the page shown is not one it found: " & line 1 of field "refText" of tGroup
   put "zzqqxx" into field "refSearch" of tGroup
   dispatch "refFill" to tGroup
   check field "refList" of tGroup begins with "Nothing matches", "Reference: a search that finds nothing says: " & line 1 of field "refList" of tGroup
   put empty into field "refSearch" of tGroup
   dispatch "refFill" to tGroup
   check the text of field "refList" of tGroup is tNames, "Reference: an empty search does not list every handler again"
   -- A link followed from a page shows the linked page
   dispatch "refShow" to tGroup with the last line of tNames
   check the text of field "refText" of tGroup begins with the last line of tNames, "Reference: refShow does not show the page"
   snap pStack, pCard
end testReference

################################################################################
#
# The sidebar: where you are
#

-- On each card, the sidebar marks that card and no other: the pill
-- (graphic "frameHi") is on the card's own line of the list (the card's
-- name is that line of the frame's cFrameCards), and that line's title is
-- the only one in white
private command testSidebar pStack
   local tCard, tName, tFrame, tLine, tMid, tRect, tIndex, tTab, tWhite
   repeat with tCard = 1 to the number of cards of stack pStack
      go card tCard of stack pStack
      pump 20
      put the short name of card tCard of stack pStack into tName
      -- (the window's card: the frame's list has a text on each card, and
      -- names in a chunk read the card shown)
      put the long id of group "Frame" of card tCard of stack pStack into tFrame
      set the wholeMatches to true
      put lineOffset(tName, the cFrameCards of tFrame) into tLine
      check tLine > 0, tName & ": not in the sidebar's list of cards"
      if tLine is 0 then
         next repeat
      end if
      put the formattedRect of line tLine of field "frameList" of group "Frame" into tRect
      put item 2 of the loc of graphic "frameHi" of tFrame into tMid
      check tMid >= item 2 of tRect and tMid <= item 4 of tRect + 10, \
            tName & ": the sidebar's pill (middle " & tMid & ") is not on its line " & tLine & " (" & tRect & ")"
      put empty into tWhite
      repeat with tIndex = 1 to the number of lines of field "frameList" of group "Frame"
         put offset(tab, line tIndex of field "frameList" of group "Frame") into tTab
         if the textColor of char tTab + 1 of line tIndex of field "frameList" of group "Frame" is "255,255,255" then
            put tIndex & comma after tWhite
         end if
      end repeat
      check tWhite is tLine & comma, tName & ": the sidebar's white titles are on lines " & tWhite & " not " & tLine
   end repeat
end testSidebar

################################################################################
#
# Words that can be read
#

-- In the look pLook ("light" or "dark"): every word of the group "Learn" on
-- each card, and on the lesson pLesson the first call's page, is far
-- enough in colour from what is under it
private command testReadable pStack, pLesson, pLook
   local tCard, tGroup, tCount
   put pLook is "dark" into sTestDark
   put 0 into tCount
   repeat with tCard = 1 to the number of cards of stack pStack
      -- (the look changes as a card opens, as it does for a user)
      go card tCard of stack pStack
      pump 20
      if tCard is 1 then
         check the uLook of stack pStack is pLook or (pLook is "light" and the uLook of stack pStack is empty), \
               "the stack is not in its " & pLook & " look: " & the uLook of stack pStack
      end if
      if there is no group "Learn" of card tCard of stack pStack then
         next repeat
      end if
      put the long id of group "Learn" of card tCard of stack pStack into tGroup
      if tCard is pLesson then
         dispatch "learnRun" to tGroup
         pump 20
      end if
      add readableFields(tGroup, pLook) to tCount
      if tCard is pLesson then
         dispatch "learnExplain" to tGroup with word 2 of field "lessonCalls" of tGroup
         add readableFields(tGroup, pLook) to tCount
         dispatch "learnSheet" to tGroup with false
      end if
   end repeat
   write "  " & pLook & ":" && tCount && "colours of words checked" & return to stdout
   put false into sTestDark
end testReadable

-- Checks each field of the group pGroup that shows words; how many
-- colours it checked
private function readableFields pGroup, pLook
   local tIndex, tField, tBack, tInk, tCount, tRatio
   put 0 into tCount
   repeat with tIndex = 1 to the number of fields of pGroup
      put the long id of field tIndex of pGroup into tField
      if the text of tField is empty or not readableShown(tField) then
         next repeat
      end if
      put readableUnder(tField) into tBack
      repeat for each line tInk in readableInks(tField)
         put readableContrast(tInk, tBack) into tRatio
         add 1 to tCount
         check tRatio >= 4.5, pLook & ", " & the short name of this card & ", " & the short name of tField & ": " & \
               tInk && "on" && tBack && "is" && format("%.2f", tRatio) && "to 1 (" & char 1 to 30 of line 1 of the text of tField & ")"
      end repeat
   end repeat
   return tCount
end readableFields

-- Whether the control pObj shows: it and every group it is in visible
private function readableShown pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card"
      if not the visible of tObj then
         return false
      end if
      put the long owner of tObj into tObj
   end repeat
   return true
end readableShown

-- Every colour the words of the field pField are in, "r,g,b" a line: its
-- own, each its runs set, and the stack's link colour if it has a link
private function readableInks pField
   local tOut, tHtml, tAt, tColor
   put readableRgb(the effective textColor of pField) & return into tOut
   put the htmlText of pField into tHtml
   if tHtml contains "<a" or "link" is among the items of the textStyle of pField then
      -- (the stack's, which the card shown is of, else the engine's)
      if the linkColor of this stack is not empty then
         put readableRgb(the linkColor of this stack) & return after tOut
      else
         put readableRgb(the linkColor) & return after tOut
      end if
   end if
   repeat
      -- (" color=": a run's colour, and not its bgcolor)
      put offset(" color=" & quote, tHtml) into tAt
      if tAt is 0 then
         exit repeat
      end if
      delete char 1 to tAt + 7 of tHtml
      put readableRgb(char 1 to offset(quote, tHtml) - 1 of tHtml) into tColor
      if tColor is not among the lines of tOut then
         put tColor & return after tOut
      end if
   end repeat
   delete the last char of tOut
   return tOut
end readableInks

-- The colour under the middle of the control pObj: its own if it is a
-- field with one, else the topmost filled graphic or field below it (in
-- its group, then that group's, out to the card's colour). A gradient
-- counts as its first colour
private function readableUnder pObj
   local tBelow, tOwner, tIndex, tCtl, tLoc, tBest, tBestLayer
   if word 1 of pObj is "field" and the opaque of pObj and the backgroundColor of pObj is not empty then
      return readableRgb(the backgroundColor of pObj)
   end if
   put the loc of pObj into tLoc
   put pObj into tBelow
   repeat while word 1 of tBelow is not "card"
      put the long owner of tBelow into tOwner
      put empty into tBest
      put 0 into tBestLayer
      repeat with tIndex = 1 to the number of controls of tOwner
         put the long id of control tIndex of tOwner into tCtl
         if the long owner of tCtl is not tOwner or the layer of tCtl >= the layer of tBelow or the layer of tCtl <= tBestLayer then
            next repeat
         end if
         if not the visible of tCtl or not (tLoc is within the rect of tCtl) then
            next repeat
         end if
         if word 1 of tCtl is "graphic" and the fillGradient["ramp"] of tCtl is not empty then
            put item 2 to 4 of line 1 of the fillGradient["ramp"] of tCtl into tBest
            put the layer of tCtl into tBestLayer
         else if word 1 of tCtl is "graphic" and the filled of tCtl and the backgroundColor of tCtl is not empty then
            put the backgroundColor of tCtl into tBest
            put the layer of tCtl into tBestLayer
         else if word 1 of tCtl is "field" and the opaque of tCtl and the backgroundColor of tCtl is not empty then
            put the backgroundColor of tCtl into tBest
            put the layer of tCtl into tBestLayer
         end if
      end repeat
      if tBest is not empty then
         return readableRgb(tBest)
      end if
      put tOwner into tBelow
   end repeat
   return readableRgb(the effective backgroundColor of tBelow)
end readableUnder

-- "r,g,b" of a colour given as that or as #rrggbb
private function readableRgb pColor
   if pColor begins with "#" then
      return baseConvert(char 2 to 3 of pColor, 16, 10) & comma & baseConvert(char 4 to 5 of pColor, 16, 10) & comma & \
            baseConvert(char 6 to 7 of pColor, 16, 10)
   end if
   return item 1 to 3 of pColor
end readableRgb

-- The WCAG's contrast of two colours ("r,g,b"): 1 to 21
private function readableContrast pFirst, pSecond
   local tLumA, tLumB
   put readableLuminance(pFirst) into tLumA
   put readableLuminance(pSecond) into tLumB
   return (max(tLumA, tLumB) + 0.05) / (min(tLumA, tLumB) + 0.05)
end readableContrast

private function readableLuminance pColor
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
end readableLuminance

-- The links of a page of htmlText: what each <a> names, its href or its text
private function pageLinks pHtml
   local tOut, tStart, tEnd, tTag, tHref
   repeat
      put offset("<a", pHtml) into tStart
      if tStart is 0 then
         exit repeat
      end if
      delete char 1 to tStart - 1 of pHtml
      put offset(">", pHtml) into tEnd
      put char 1 to tEnd of pHtml into tTag
      delete char 1 to tEnd of pHtml
      if tTag contains "href=" then
         put tTag into tHref
         delete char 1 to offset("href=", tHref) + 5 of tHref
         put char 1 to offset(quote, tHref) - 1 of tHref & comma after tOut
      else
         put char 1 to offset("</a>", pHtml) - 1 of pHtml & comma after tOut
      end if
   end repeat
   delete the last char of tOut
   replace "&amp;" with "&" in tOut
   return tOut
end pageLinks
