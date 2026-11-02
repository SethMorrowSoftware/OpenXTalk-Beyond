script "OXTTestLearnBox2D"
-- OXT-Beyond: runs every lesson of the built "Learn Box2D" on a real
-- engine with Box2Dxt loaded, and fails if one does not run.
--
--    <install>/OXT-Beyond -ui tools/examples/test-learn-box2d.livecodescript
--
-- (on Linux, under xvfb-run where there is no display). It opens
-- ide/Resources/Examples/Remastered/Learn Box2D.oxtstack, or the stack in
-- OXT_LEARN_BOX2D, loads Box2Dxt from the install it runs in (or the one
-- in OXT_INSTALL), and on each lesson card:
--
--    lets the world run for three seconds
--    presses each of the card's buttons, as a click does, and lets the
--    world run after each
--    checks that the line under the court does not say the lesson
--    stopped with an error, that the world is drawn (it has bodies), and
--    that every body is in the court (and, on Terrain, on the hills)
--    after a fresh Reset, that a button does what the lesson says it
--    does, read from the line under the court (the block of checks at
--    the end of this script)
--
-- It writes a line for each card, PASS or FAIL, and ends with "DONE"
-- (exit code 0) or "FAILED <how many>" (exit code 1). With
-- OXT_LEARN_BOX2D_SNAPS set to a folder, it saves a picture of each card
-- there after its buttons.

on startup
   local tStack, tInstall, tError, tFails, tCard
   set the itemDelimiter to slash
   put $OXT_LEARN_BOX2D into tStack
   if tStack is empty then
      put item 1 to -4 of the filename of me & "/ide/Resources/Examples/Remastered/Learn Box2D.oxtstack" into tStack
   end if
   put $OXT_INSTALL into tInstall
   if tInstall is empty then
      put the engine folder into tInstall
   end if
   set the itemDelimiter to comma
   try
      loadBox2D tInstall
      go stack tStack
      put 0 into tFails
      repeat with tCard = 2 to the number of cards of stack tStack
         if not testCard(tStack, tCard) then
            add 1 to tFails
         end if
      end repeat
      go card 1 of stack tStack
   catch tError
      write "FAILED" && tError & return to stdout
      quit 1
   end try
   if tFails > 0 then
      write "FAILED" && tFails & return to stdout
      quit 1
   end if
   write "DONE" & return to stdout
   quit 0
end startup

-- Box2Dxt, as the IDE loads it: its module, with its folder for the
-- native library, mapped by path (the engine finds a foreign library by
-- its bare name only beside a stack, or by revLibraryMapping)
private command loadBox2D pInstall
   local tFolder, tLibrary
   put pInstall & "/Extensions/org.openxtalk.box2dxt" into tFolder
   if there is no folder tFolder then
      throw "no Box2Dxt in " & pInstall
   end if
   switch the platform
      case "Linux"
         put tFolder & "/code/x86_64-linux/box2dxt.so" into tLibrary
         break
      case "Win32"
         put tFolder & "/code/x86_64-win32/box2dxt.dll" into tLibrary
         break
      default
         put tFolder & "/code/universal-mac/box2dxt.dylib" into tLibrary
   end switch
   set the revLibraryMapping["box2dxt"] to tLibrary
   load extension from file (tFolder & "/module.lcm") with resource path tFolder
   if b2Version() is not 4 then
      throw "Box2Dxt answers version " & b2Version()
   end if
end loadBox2D

-- One lesson: true if it runs
private function testCard pStack, pCard
   local tName, tWhy, tCount, tButtons, tDo, tObj, tSnaps
   go card pCard of stack pStack
   put the short name of this card into tName
   waitRun 3000
   put problem() into tWhy
   if tWhy is empty then
      put wherever(tName) into tWhy
   end if
   if tWhy is empty and countBodies() < 2 then
      put "only" && countBodies() && "bodies drawn" into tWhy
   end if
   -- Each button, as a click on it runs it
   repeat with tCount = 1 to the number of groups of this card
      put the long id of group tCount of this card into tObj
      if the cDo of tObj is not empty and the short name of tObj begins with "Do" then
         put the cDo of tObj & comma after tButtons
      end if
   end repeat
   repeat for each item tDo in tButtons
      if tWhy is not empty then
         exit repeat
      end if
      dispatch "labRun" to this card with tDo
      waitRun 500
      put problem() into tWhy
      if tWhy is not empty then
         put tWhy && "(after" && tDo & ")" into tWhy
      end if
   end repeat
   -- Step and Pause, then Reset
   if tWhy is empty then
      dispatch "labRun" to this card with "labStepButton"
      dispatch "labRun" to this card with "labTogglePause"
      waitRun 300
      dispatch "labRun" to this card with "labRestart"
      waitRun 500
      put problem() into tWhy
   end if
   if tWhy is empty then
      put checks(tName) into tWhy
   end if
   put $OXT_LEARN_BOX2D_SNAPS into tSnaps
   if tSnaps is not empty then
      export snapshot from this card to file (tSnaps & "/" & format("%02d", pCard - 1) & "-" & tName & ".png") as PNG
   end if
   if tWhy is empty then
      write "PASS" && tName && "(" & field "Readout" & ")" & return to stdout
      return true
   end if
   write "FAIL" && tName & ":" && tWhy & return to stdout
   return false
end testCard

private command waitRun pMs
   wait pMs milliseconds with messages
end waitRun

-- What is wrong with the card in front, or empty
private function problem
   local tSaid
   put field "Readout" into tSaid
   if tSaid begins with "Stopped" or tSaid begins with "Box2D is not loaded" then
      return tSaid
   end if
   return empty
end problem

-- The graphics the Lab drew, in its group "Bodies" (but the box that
-- keeps the group)
private function countBodies
   return the number of graphics of group "Bodies" - 1
end countBodies

-- Where the card's bodies are: a problem if one is not in the court, and
-- for the lessons that ask more, kChecks
private function wherever pCard
   local tBody, tX, tY, tLow
   put 99 into tLow
   repeat for each item tBody in value("labBodies()", the long id of this card)
      put b2BodyX(tBody) into tX
      put b2BodyY(tBody) into tY
      if not (tX is a number and tY is a number) or abs(tX) > 4.2 or tY < -0.05 or tY > 30 then
         return "a body is out of the court, at" && tX & "," && tY
      end if
      if b2BodyType(tBody) is 2 then
         put min(tLow, tY) into tLow
      end if
   end repeat
   -- (the hills of Terrain are a chain: a body that fell through it
   -- would lie on the floor below, under 0.5 metres up)
   if pCard is "Terrain" and tLow < 0.5 then
      return "a body fell through the chain, to" && tLow && "m"
   end if
   return empty
end wherever

-- The checks of what buttons do: a line each, card|button's handler|
-- milliseconds to let it run|a word of the line under the court|> or <|
-- a number. The number after that word must be more (or less) than it.
-- Each card's checks start from a Reset
private function checks pCard
   local tLine, tSaid, tNumber, tWhy, tFirst
   put true into tFirst
   set the itemDelimiter to "|"
   repeat for each line tLine in "World|changeGravity|400|gravity|>|7" & return & \
         "Forces|throwBall|150|speed|>|3" & return & \
         "Hinges|fasterMotor|600|windmill:|>|2" & return & \
         "Springs|softer|400|spring|<|1.2" & return & \
         "Sliders|liftUp|2500|lift:|>|1.5" & return & \
         "Wheels|driveRight|2000|speed|>|0.5" & return & \
         "Contacts|dropFive|3000|began:|>|4" & return & \
         "Terrain|dropTen|3000|bodies|>|21"
      if item 1 of tLine is not pCard then
         next repeat
      end if
      if tFirst then
         dispatch "labRun" to this card with "labRestart"
         waitRun 1500
         put false into tFirst
      end if
      dispatch "labRun" to this card with item 2 of tLine
      waitRun item 3 of tLine
      put field "Readout" into tSaid
      put afterWord(tSaid, item 4 of tLine) into tNumber
      if tNumber is not a number then
         put "after" && item 2 of tLine & ", no number after" && quote & item 4 of tLine & quote && "in:" && tSaid into tWhy
      else if item 5 of tLine is ">" and not (tNumber > item 6 of tLine) then
         put "after" && item 2 of tLine & "," && item 4 of tLine && tNumber && "is not over" && item 6 of tLine into tWhy
      else if item 5 of tLine is "<" and not (tNumber < item 6 of tLine) then
         put "after" && item 2 of tLine & "," && item 4 of tLine && tNumber && "is not under" && item 6 of tLine into tWhy
      end if
      if tWhy is empty then
         put problem() into tWhy
      end if
      if tWhy is not empty then
         exit repeat
      end if
      write "  ok" && pCard && item 2 of tLine && "->" && item 4 of tLine && tNumber & return to stdout
   end repeat
   set the itemDelimiter to comma
   return tWhy
end checks

-- The number after a word in a line (with a comma or a bracket after it
-- taken off)
private function afterWord pText, pWord
   local tIndex, tWord
   repeat with tIndex = 1 to the number of words of pText
      if word tIndex of pText is pWord then
         put word tIndex + 1 of pText into tWord
         replace comma with empty in tWord
         replace "(" with empty in tWord
         return tWord
      end if
   end repeat
   return empty
end afterWord
