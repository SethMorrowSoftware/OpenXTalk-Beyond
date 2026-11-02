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
--    fits the code panel without going on below itself, and Run gives a
--    result that matches the lesson's cExpect, every line of which fits
--    the field "Result"; it does twice, and each call in the lesson's list
--    opens its page of the reference
--    on one lesson: Copy puts the script on the clipboard; an edit, then
--    Reset, puts the lesson's own script back; a script that does not
--    compile, and one that stops, say so in the field "Result" and where
--    the Reference card: it lists every handler of the extension, each
--    has a page, every link in a page goes to a handler or a card, and a
--    search finds a handler by a word of its page
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
   go card 1 of stack tStack
end testStack

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
