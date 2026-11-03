script "OXTTestLearnBox2DxtKit"
-- OXT-Beyond: runs every lesson of the built "Learn Box2Dxt Kit" on a real
-- engine with Box2Dxt and its Kit loaded, and fails if one does not run.
--
--    <install>/OXT-Beyond -ui tools/examples/test-learn-box2dxt-kit.livecodescript
--
-- (on Linux, under xvfb-run where there is no display). It opens
-- ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack, or the
-- stack in OXT_LEARN_KIT, and loads Box2Dxt and the Box2Dxt Kit from the
-- install it runs in (or the one in OXT_INSTALL). On each lesson card it:
--
--    lets the game run for two seconds
--    presses each of the card's buttons, as a click does, checks that
--    its light is right (a switch lit while its card says it is on, any
--    other button lit for a moment), and lets the
--    game run after each
--    runs the lines on the card's Code tab, as Run does
--    presses Step, Pause and Reset
--    checks that the line at the court's top never says the lesson
--    stopped, or that the lines did, that something moves, and that
--    everything that moves is in the court
--    after a fresh Reset, checks that a button does what the lesson says
--    it does, read from the line at the court's top (kChecks, below)
--
-- On the Reference card, a search must narrow the list and a handler
-- must explain itself. It writes a line for each card, PASS or FAIL, and
-- ends with "DONE" (exit code 0) or "FAILED <how many>" (exit code 1).
-- With OXT_LEARN_KIT_SNAPS set to a folder, it saves a picture of each
-- card there.

on startup
   local tStack, tInstall, tError, tFails, tCard
   set the itemDelimiter to slash
   put $OXT_LEARN_KIT into tStack
   if tStack is empty then
      put item 1 to -4 of the filename of me & "/ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack" into tStack
   end if
   put $OXT_INSTALL into tInstall
   if tInstall is empty then
      put the engine folder into tInstall
   end if
   set the itemDelimiter to comma
   try
      loadKit tInstall
      go stack tStack
      put 0 into tFails
      repeat with tCard = 2 to the number of cards of stack tStack
         go card tCard of stack tStack
         if the short name of this card is "Reference" then
            if not testReference() then
               add 1 to tFails
            end if
         else if not testCard(tStack, tCard) then
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

-- Box2Dxt, as the IDE loads it (its module, with its native library
-- mapped by path), then the Kit, a script library
private command loadKit pInstall
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
   if there is no file (pInstall & "/Extensions/box2dxt-kit/box2dxt-kit.livecodescript") then
      throw "no Box2Dxt Kit in " & pInstall
   end if
   start using stack (pInstall & "/Extensions/box2dxt-kit/box2dxt-kit.livecodescript")
   if b2kVersion() is not 4 then
      throw "the Kit answers version " & b2kVersion()
   end if
end loadKit

-- One lesson: true if it runs
private function testCard pStack, pCard
   local tName, tWhy, tCount, tButtons, tDo, tObj, tSnaps, tSaid
   put the short name of this card into tName
   waitRun 2000
   put problem() into tWhy
   if tWhy is empty then
      put wherever() into tWhy
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
      put lights(tDo) into tWhy
      if tWhy is empty then
         waitRun 400
         put problem() into tWhy
      end if
      if tWhy is not empty then
         put tWhy && "(after" && tDo & ")" into tWhy
      end if
   end repeat
   -- The Code tab's lines, as Run runs them
   if tWhy is empty then
      dispatch "labRun" to this card with "labRunCode"
      put field "Readout" into tSaid
      if tSaid is not "Ran your lines." then
         put "the Code tab's lines did not run:" && tSaid into tWhy
      end if
      waitRun 500
   end if
   -- Step and Pause, then Reset
   if tWhy is empty then
      dispatch "labRun" to this card with "labStepButton"
      dispatch "labRun" to this card with "labTogglePause"
      waitRun 300
      dispatch "labRun" to this card with "labRestart"
      waitRun 800
      put problem() into tWhy
   end if
   if tWhy is empty then
      put wherever() into tWhy
   end if
   if tWhy is empty then
      put checks(tName) into tWhy
   end if
   put $OXT_LEARN_KIT_SNAPS into tSnaps
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

-- The Reference card: every handler listed, a search narrows the list,
-- and a handler explains itself
private function testReference
   local tAll, tWhy
   put the number of lines of field "RefList" into tAll
   if tAll < 300 then
      put "only" && tAll && "handlers listed" into tWhy
   end if
   if tWhy is empty then
      put "sound" into field "RefFind"
      dispatch "refFilter" to this card
      if the number of lines of field "RefList" < 5 or the number of lines of field "RefList" >= tAll then
         put "a search for sound lists" && the number of lines of field "RefList" && "handlers" into tWhy
      end if
   end if
   if tWhy is empty then
      dispatch "refExplain" to this card with "b2kSpawnBall"
      if not (field "RefDoc" contains "b2kSpawnBall screenX") or not (field "RefDoc" contains "In the lessons:") then
         put "b2kSpawnBall does not explain itself:" && line 1 of field "RefDoc" into tWhy
      end if
   end if
   put empty into field "RefFind"
   dispatch "refFilter" to this card
   if tWhy is empty then
      write "PASS Reference (" & tAll && "handlers)" & return to stdout
      return true
   end if
   write "FAIL Reference:" && tWhy & return to stdout
   return false
end testReference

private command waitRun pMs
   wait pMs milliseconds with messages
end waitRun

-- The buttons' lights, just after the button pDo ran: a switch is lit
-- when its card's labLit says it is on, and out when not; any other
-- button that ran is lit for a moment. Empty when they are right
private function lights pDo
   local tCount, tObj, tLit, tOn
   repeat with tCount = 1 to the number of groups of this card
      put the long id of group tCount of this card into tObj
      if not (the short name of tObj begins with "Do") or the cDo of tObj is empty then
         next repeat
      end if
      if there is no graphic (the short name of tObj & "_lit") of tObj then
         return "the button" && the cDo of tObj && "has no light"
      end if
      put the visible of graphic (the short name of tObj & "_lit") of tObj into tLit
      if the cSwitch of tObj is true then
         dispatch function "labLit" to this card with the cDo of tObj
         put (the result is true) into tOn
         if tLit is not tOn then
            return "the switch" && the cDo of tObj && "is" && word (1 + (tLit is true)) of "out lit" && \
                  "but its card says it is" && word (1 + (tOn is true)) of "off on"
         end if
      else if the cDo of tObj is pDo and not tLit then
         return "the button" && pDo && "did not light up when it ran"
      end if
   end repeat
   return empty
end lights

-- What is wrong with the card in front, or empty
private function problem
   local tSaid
   put field "Readout" into tSaid
   if tSaid begins with "Stopped" or tSaid begins with "The Box2Dxt Kit is not loaded" or \
         tSaid begins with "Your lines stopped" or tSaid begins with "The camera did not start" then
      return tSaid
   end if
   return empty
end problem

-- Something moves, and everything that moves is in the court (with a
-- little room for one that is touching a wall). With the camera on
-- (the Camera lesson), places are in its world, 1600 by 378 pixels
private function wherever
   local tAll, tIn
   put b2kOverlapMoving(-100000, -100000, 100000, 100000) into tAll
   if tAll is empty then
      return "nothing moves"
   end if
   if b2kCamIsOn() then
      put b2kOverlapMoving(-20, -420, 1620, 400) into tIn
   else
      put b2kOverlapMoving(250, 140, 700, 620) into tIn
   end if
   if the number of lines of tIn < the number of lines of tAll then
      return the number of lines of tAll - the number of lines of tIn && "of" && the number of lines of tAll && \
            "moving bodies are out of the court"
   end if
   return empty
end wherever

-- The checks of what buttons do: a line each, card|button's handler|
-- milliseconds to let it run|a word of the line at the court's top|> or <|
-- a number. The number after that word must be more (or less) than it.
-- Each card's checks start from a Reset
private function checks pCard
   local tLine, tSaid, tNumber, tWhy, tFirst
   put true into tFirst
   set the itemDelimiter to "|"
   repeat for each line tLine in "Quick|rain|1500|bodies:|>|12" & return & \
         "Moves|jump|300|speed|>|150" & return & \
         "Joints|liftUp|1500|lift|<|-50" & return & \
         "Joints|drive|1500|cart|>|40" & return & \
         "Sprites|dropCrate|300|sheet:|>|6" & return & \
         "Anim|fromFiles|500|(read|>|2" & return & \
         "Contacts|dropBalls|3000|far:|>|3" & return & \
         "Camera|autoRun|2500|x|>|300"
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
