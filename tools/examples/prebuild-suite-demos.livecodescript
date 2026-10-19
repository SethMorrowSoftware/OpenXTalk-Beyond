script "OXTPrebuildSuiteDemos"
-- OXT-Beyond: makes the xTalk Suite demos in
-- ide/Resources/Examples/xTalk Suite ready to use (tools/examples/README.md,
-- "xTalk Suite demos").
--
-- No Cloud Quick Share and Torrent Client build their windows from their
-- stack scripts when they open, and a stack that has never been built
-- shows that happening. This builds each one once, by its own build
-- handler, so the saved stack opens with its window already there: the
-- build handlers see the version tag they stamp and do nothing on open.
-- It also gives all three demos a card script that puts the window in
-- the middle of the screen each time it opens. The stack scripts, the
-- suite's files, are not changed.
--
-- Run it in the IDE of an installed OXT-Beyond, from a checkout, on a
-- machine with a display (not -ui: the build measures text to place it):
--
--    <install>/oxt-beyond tools/examples/prebuild-suite-demos.livecodescript
--
-- It saves the three stacks in place in the 7.0 stack format, writes a
-- line for each to prebuild-suite-demos.log beside this file, and quits.
-- Run it on a stack whose window is already built and only the card
-- script is set again.

constant kDemos = "No Cloud Quick Share,Torrent Client,Box2D Platformer"

on openStack
   local tRepo, tFolder, tLogFile, tLog, tDemo, tStack, tName, tError
   set the itemDelimiter to slash
   put item 1 to -2 of the filename of me & "/prebuild-suite-demos.log" into tLogFile
   put item 1 to -4 of the filename of me into tRepo
   put tRepo & "/ide/Resources/Examples/xTalk Suite" into tFolder
   set the itemDelimiter to comma
   repeat for each item tDemo in kDemos
      put tFolder & "/" & tDemo & ".oxtstack" into tStack
      -- messages stay locked: the stacks must not start their sessions,
      -- self-checks or games while they are built
      lock messages
      try
         put the short name of stack tStack into tName
         set the defaultStack to tName
         prebuildDemo tDemo, tName
         set the script of card 1 of stack tName to demoCardScript(tDemo)
         set the stackFileVersion to "7.0"
         save stack tName
         put tDemo & ": " & the number of controls of card 1 of stack tName \
               & " controls, saved" & return after tLog
      catch tError
         put tDemo & ": FAILED " & tError & return after tLog
      end try
      unlock messages
   end repeat
   put tLog into url ("file:" & tLogFile)
   quit 0
end openStack

command prebuildDemo pDemo, pName
   switch pDemo
      case "No Cloud Quick Share"
         dispatch "qsBuild" to stack pName
         break
      case "Torrent Client"
         dispatch "tcPrefLoad" to stack pName
         dispatch "tcBuildUI" to stack pName
         -- the build fills in this machine's download folder; the card
         -- script puts the opening machine's in instead
         put empty into field "tcSavePath" of card 1 of stack pName
         break
      default
         -- Box2D Platformer is saved built (README.md says how)
         break
   end switch
end prebuildDemo

-- The card script of each demo. It runs once per open, in preOpenCard:
-- after preOpenStack, so the window has its size, and before the window
-- is shown. Torrent Client's also applies what tcBuildUI applies to a
-- new build from the settings tcPrefLoad reads in preOpenStack (the
-- remembered height, download folder and upload cap), which the build
-- no longer gets to do once the window is saved.
function demoCardScript pDemo
   local tScript
   put "local sCentered" & return & return & "on preOpenCard" & return \
         & "   if sCentered is not true then" & return \
         & "      put true into sCentered" & return into tScript
   if pDemo is "Torrent Client" then
      put "      if the uHeight of this stack is a number and the uHeight of this stack >= 500 then" & return \
            & "         set the height of this stack to (the uHeight of this stack)" & return \
            & "      end if" & return \
            & "      if the uSavePath of this stack is not empty then" & return \
            & "         put the uSavePath of this stack into field " & quote & "tcSavePath" & quote & return \
            & "      else" & return \
            & "         put tcDefaultSavePath() into field " & quote & "tcSavePath" & quote & return \
            & "      end if" & return \
            & "      if the uUpLimit of this stack is not empty then" & return \
            & "         put the uUpLimit of this stack into field " & quote & "tcUpLimit" & quote & return \
            & "      else" & return \
            & "         put " & quote & "0" & quote & " into field " & quote & "tcUpLimit" & quote & return \
            & "      end if" & return after tScript
   end if
   put "      set the loc of this stack to the screenLoc" & return \
         & "   end if" & return \
         & "   pass preOpenCard" & return \
         & "end preOpenCard" & return & return \
         & "on closeStack" & return \
         & "   put empty into sCentered" & return \
         & "   pass closeStack" & return \
         & "end closeStack" & return after tScript
   return tScript
end demoCardScript
