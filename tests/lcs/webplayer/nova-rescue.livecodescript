script "TestNovaRescue"
-- OXT-Beyond: the Nova Rescue game (the committed
-- tools/web-player/stacks/Nova Rescue.oxtstack, built by
-- tools/web-player/nova-rescue.livecodescript from
-- tools/web-player/nova-rescue-stack.livecodescript), on a desktop engine.
--
-- The game's clock is in the test's hands: nrTestBegin stops its loop,
-- fixes the random seed and keeps what it saves in a file of the test's
-- own; nrTestStep moves the game on, a sixtieth of a second at a time;
-- nrTestPut puts an astronaut, a meteor, a raider, a power-up or an
-- enemy bolt where the test wants it, and nrState says how things are.
-- The buttons are pressed through nrPress, as their scripts do.
-- tools/ci/nova_rescue_check.py plays it with real touches in a phone's
-- browser.

constant kStack = "Nova Rescue"

local sSave

on TestSetup
   local tFile
   put specialFolderPath("temporary") & "/nova-rescue-test-" & the milliseconds & ".txt" into sSave
   if there is a file sSave then
      delete file sSave
   end if
   put TestGetEngineRepositoryPath() & "/tools/web-player/stacks/Nova Rescue.oxtstack" into tFile
   go stack tFile
   game "nrTestBegin", 7, sSave
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
   if sSave is not empty and there is a file sSave then
      delete file sSave
   end if
end TestTeardown

----------------------------------------------------------------------
-- Helpers

private command game pHandler, p1, p2, p3, p4
   dispatch pHandler to stack kStack with p1, p2, p3, p4
end game

-- One value of the game's nrState
private function st pKey
   local tState
   dispatch function "nrState" to stack kStack
   put the result into tState
   split tState by return and ":"
   return tState[pKey]
end st

private command step pSeconds
   game "nrTestStep", pSeconds
end step

private command press pButton
   game "nrPress", pButton
end press

private command put1 pKind, pX, pY, pSpeed
   game "nrTestPut", pKind, pX, pY, pSpeed
end put1

-- Something right on the ship
private command putOnShip pKind
   put1 pKind, st("shipx"), st("shipy"), 0
end putOnShip

-- A run, with nothing coming but what the test puts there
private command newRun
   game "nrNewRun"
   game "nrTestSpawning", false
end newRun

private function fieldText pName
   return the text of field pName of card "Space" of stack kStack
end fieldText

private function shown pGroup
   return the visible of group pGroup of card "Space" of stack kStack
end shown

private function saved
   local tText
   put url ("file:" & sSave) into tText
   return tText
end saved

-- Whether rect pInner is wholly in rect pOuter
private function isInside pInner, pOuter
   return item 1 of pInner >= item 1 of pOuter and item 2 of pInner >= item 2 of pOuter and \
         item 3 of pInner <= item 3 of pOuter and item 4 of pInner <= item 4 of pOuter
end isInside

private function overlap pA, pB
   return item 1 of pA < item 3 of pB and item 1 of pB < item 3 of pA and \
         item 2 of pA < item 4 of pB and item 2 of pB < item 4 of pA
end overlap

-- The window at pWidth x pHeight, laid out again
private command windowSize pWidth, pHeight
   set the rect of stack kStack to 0, 0, pWidth, pHeight
   game "nrResized"
end windowSize

----------------------------------------------------------------------
-- Opening

on TestTheGameOpensOnItsTitle
   TestAssert "the mode is the title", st("mode") is "title"
   TestAssert "the title screen is shown", shown("Title")
   TestAssert "the HUD is not", not shown("HUD")
   TestAssert "nor the other screens", not shown("Howto") and not shown("Paused") and \
         not shown("Over") and not shown("Settings")
   TestAssert "the ship is on the title", the visible of button "Ship" of card "Space" of stack kStack
   TestAssert "under the logo, a picture", the icon of button "Logo Nova" of card "Space" of stack kStack is \
         the id of image "logo-nova" of card "Art" of stack kStack
   game "nrGoTitle"
   TestAssert "nothing saved yet: no records", fieldText("Records") is "BEST 0     STARS 0"
end TestTheGameOpensOnItsTitle

-- What the builder put in the stack: every picture of the art list on
-- the Art card, every sound, the font
on TestEverythingTheGameNeedsIsInTheStack
   local tList, tLine, tMissing, tSounds, tScript, tAt, tName, tCount
   put url ("file:" & TestGetEngineRepositoryPath() & "/tools/web-player/nova-rescue/art/art.txt") into tList
   TestAssert "the art list is read", tList is not empty
   set the itemDelimiter to tab
   repeat for each line tLine in tList
      if tLine is empty or char 1 of tLine is "#" then
         next repeat
      end if
      if there is not an image (item 1 of tLine) of card "Art" of stack kStack then
         put item 1 of tLine & space after tMissing
      end if
   end repeat
   set the itemDelimiter to comma
   TestAssert "every picture is on the Art card" && tMissing, tMissing is empty
   -- every sound the game plays (nrSound "<name>", ... in its script)
   put the customProperties["cSounds"] of stack kStack into tSounds
   put empty into tMissing
   put 0 into tCount
   put the script of stack kStack into tScript
   repeat while tScript contains "nrSound" & space & quote
      put offset("nrSound" & space & quote, tScript) into tAt
      delete char 1 to tAt + 8 of tScript
      put char 1 to offset(quote, tScript) - 1 of tScript into tName
      add 1 to tCount
      if tSounds[tName] is empty then
         put tName & space after tMissing
      end if
   end repeat
   TestAssert "the game plays sounds", tCount > 10
   TestAssert "and every one is in the stack" && tMissing, tMissing is empty
   TestAssert "the font is in the stack", the cFont of stack kStack is not empty
end TestEverythingTheGameNeedsIsInTheStack

----------------------------------------------------------------------
-- The screens

on TestHowToPlayComesBeforeTheFirstRunOnly
   press "Play"
   TestAssert "the first Play shows how to play", st("mode") is "howto" and shown("Howto")
   TestAssert "its button plays", the label of button "Howto Go" of card "Space" of stack kStack is "PLAY"
   press "Howto Go"
   TestAssert "and then a run begins", st("mode") is "play" and shown("HUD")
   TestAssert "it is saved as seen", "howto=true" is among the lines of saved()
   press "Pause"
   press "Pause Home"
   TestAssert "home goes to the title", st("mode") is "title" and shown("Title")
   press "Play"
   TestAssert "the next Play plays at once", st("mode") is "play"
end TestHowToPlayComesBeforeTheFirstRunOnly

on TestHowToPlayFromTheTitleGoesBack
   press "Howto Open"
   TestAssert "how to play is shown", st("mode") is "howto"
   TestAssert "its button goes back", the label of button "Howto Go" of card "Space" of stack kStack is "GOT IT"
   press "Howto Go"
   TestAssert "to the title", st("mode") is "title"
end TestHowToPlayFromTheTitleGoesBack

on TestTheKeysPlayAndPause
   dispatch "rawKeyDown" to card "Space" of stack kStack with 32
   TestAssert "Space plays (how to play first)", st("mode") is "howto"
   dispatch "rawKeyDown" to card "Space" of stack kStack with 32
   TestAssert "and again begins the run", st("mode") is "play"
   dispatch "rawKeyDown" to card "Space" of stack kStack with 112
   TestAssert "P pauses", st("mode") is "pause" and shown("Paused")
   dispatch "rawKeyDown" to card "Space" of stack kStack with 65307
   TestAssert "Escape goes on", st("mode") is "play" and not shown("Paused")
end TestTheKeysPlayAndPause

on TestAPauseStopsTheClock
   local tNow
   newRun
   step 1
   put st("now") into tNow
   TestAssert "the run's clock went on", abs(tNow - 1) < 0.01
   press "Pause"
   TestAssert "Pause pauses", st("mode") is "pause" and shown("Paused")
   step 2
   TestAssert "nothing moves while it is paused", st("now") is tNow
   press "Resume"
   TestAssert "Resume goes on", st("mode") is "play" and not shown("Paused")
   step 0.5
   TestAssert "from where it was", abs(st("now") - tNow - 0.5) < 0.01
end TestAPauseStopsTheClock

on TestTheSettings
   press "Settings Open"
   TestAssert "the settings are shown", st("mode") is "settings" and shown("Settings")
   press "Controls"
   TestAssert "no tilt on a desktop: the controls stay drag", st("control") is "drag" and \
         the label of button "Controls" of card "Space" of stack kStack is "CONTROLS: DRAG"
   TestAssert "and a note says why", fieldText("Settings Note") contains "no tilt"
   TestAssert "a window has no full screen switch", not the visible of button "Full" of card "Space" of stack kStack
   press "Settings Back"
   TestAssert "Done goes back to the title", st("mode") is "title"
   newRun
   press "Pause"
   press "Pause Settings"
   TestAssert "settings from the pause", st("mode") is "settings" and shown("HUD")
   press "Settings Back"
   TestAssert "go back to the pause", st("mode") is "pause" and shown("Paused")
end TestTheSettings

----------------------------------------------------------------------
-- Rescues

on TestARescueScoresAndRaisesTheStreak
   newRun
   TestAssert "a run begins with no score and a streak of one", st("score") is 0 and st("streak") is 1
   putOnShip "pod"
   step 1/60
   TestAssert "the astronaut is rescued", st("rescued") is 1 and st("pods") is 0
   TestAssert "for 250", st("score") is 250
   TestAssert "the streak is two", st("streak") is 2
   putOnShip "pod"
   step 1/60
   TestAssert "the next is worth twice as much", st("score") is 750 and st("streak") is 3
   step 0.1
   TestAssert "the HUD shows the score", fieldText("Score") is "750"
   TestAssert "the streak", fieldText("Streak") is "x3"
   TestAssert "and the crew", fieldText("Crew") is "2/5"
end TestARescueScoresAndRaisesTheStreak

on TestTheStreakStopsAtFive
   newRun
   game "nrTestSet", "streak", 5
   putOnShip "pod"
   step 1/60
   TestAssert "five times 250", st("score") is 1250
   TestAssert "and the streak stays five", st("streak") is 5
end TestTheStreakStopsAtFive

on TestAnAstronautLostEndsTheStreak
   local tColumn
   newRun
   game "nrTestSet", "streak", 3
   put st("column") into tColumn
   -- far from the ship, about to fall off the bottom
   put1 "pod", item 1 of tColumn + 50, item 4 of tColumn + 20, 200
   step 0.3
   TestAssert "the astronaut is lost", st("pods") is 0 and st("lost") is 1
   TestAssert "the streak begins again", st("streak") is 1
   TestAssert "nothing was rescued", st("rescued") is 0 and st("score") is 0
   TestAssert "the player is told", st("pops") >= 1
end TestAnAstronautLostEndsTheStreak

----------------------------------------------------------------------
-- Hits

on TestAHitCostsAHullPointThenTheShipIsSafe
   newRun
   putOnShip "bolt"
   step 1/60
   TestAssert "a bolt costs a hull point", st("hull") is 2
   TestAssert "the bolt is gone", st("bolts") is 0
   TestAssert "the ship is safe for a moment", st("safe") is true
   -- a bolt passing through while it is safe
   put1 "bolt", st("shipx"), st("shipy"), 300
   step 0.1
   TestAssert "costs nothing", st("hull") is 2
   step 1.6
   TestAssert "the moment passes", st("safe") is false
   TestAssert "the HUD shows two hull points", \
         the blendLevel of button "Hull 2" of card "Space" of stack kStack is 0 and \
         the blendLevel of button "Hull 3" of card "Space" of stack kStack is 75
end TestAHitCostsAHullPointThenTheShipIsSafe

on TestAMeteorIntoTheHull
   newRun
   putOnShip "big"
   step 1/60
   TestAssert "a meteor costs a hull point", st("hull") is 2
   TestAssert "and is gone, unscored", st("rocks") is 0 and st("score") is 0
end TestAMeteorIntoTheHull

on TestTheLastHullPointEndsTheRun
   newRun
   game "nrTestSet", "hull", 1
   game "nrTestSet", "score", 1234
   putOnShip "bolt"
   step 1/60
   TestAssert "the ship is lost", st("mode") is "dying"
   TestAssert "and hidden", not the visible of button "Ship" of card "Space" of stack kStack
   step 2
   TestAssert "then the run is over", st("mode") is "over" and shown("Over")
   TestAssert "a new best", st("best") is 1234 and fieldText("Best Note") is "NEW BEST!"
   step 1
   TestAssert "the score counted up", fieldText("Final") is "1,234"
   TestAssert "the best is saved", "best=1234" is among the lines of saved()
   TestAssert "and the run counted", "plays=1" is among the lines of saved()
   press "Again"
   TestAssert "Again begins a new run", st("mode") is "play" and st("score") is 0 and st("hull") is 3
end TestTheLastHullPointEndsTheRun

on TestTheBestIsKeptBetweenVisits
   put "best=5000" & return & "stars=7" & return & "plays=3" & return & "howto=true" & return into url ("file:" & sSave)
   game "nrTestBegin", 7, sSave
   game "nrGoTitle"
   TestAssert "the saved best and stars are read", st("best") is 5000 and st("stars") is 7
   TestAssert "and shown on the title", fieldText("Records") is "BEST 5,000     STARS 7"
   press "Play"
   TestAssert "how to play was seen: Play plays", st("mode") is "play"
   game "nrTestSet", "hull", 1
   game "nrTestSet", "score", 300
   putOnShip "bolt"
   step 2
   TestAssert "a lower score", st("mode") is "over" and st("best") is 5000
   TestAssert "names the best", fieldText("Best Note") is "BEST 5,000"
   TestAssert "which is still saved", "best=5000" is among the lines of saved() and \
         "plays=4" is among the lines of saved()
end TestTheBestIsKeptBetweenVisits

on TestASavedFileThatMakesNoSense
   put "best=lots" & return & "stars=-4" & return & "control=sideways" & return & "nonsense" & return into url ("file:" & sSave)
   game "nrTestBegin", 7, sSave
   TestAssert "is read as nothing saved", st("best") is 0 and st("stars") is 0 and st("control") is "drag"
end TestASavedFileThatMakesNoSense

----------------------------------------------------------------------
-- Lasers

on TestLasersBreakABigMeteorInTwo
   local tShipX, tShipY, i
   newRun
   put st("shipx") into tShipX
   put st("shipy") into tShipY
   put1 "big", tShipX, tShipY - 260, 0
   repeat with i = 1 to 240
      step 1/60
      if st("score") is not 0 then
         exit repeat
      end if
   end repeat
   TestAssert "the lasers broke it, for 50", st("score") is 50
   TestAssert "into two meteors", st("rocks") is 2
   TestAssert "after three hits (it took a while)", i > 50
end TestLasersBreakABigMeteorInTwo

on TestLasersBringDownARaider
   local i
   newRun
   -- a scout, diving straight at the ship
   put1 "scout", st("shipx"), 160
   repeat with i = 1 to 120
      step 1/60
      if st("foes") is 0 then
         exit repeat
      end if
   end repeat
   TestAssert "the scout is down", st("foes") is 0
   TestAssert "for 100", st("score") is 100
   TestAssert "before it reached the ship", st("hull") is 3
end TestLasersBringDownARaider

----------------------------------------------------------------------
-- Power-ups

on TestPowerUps
   local tScore
   newRun
   putOnShip "twin"
   step 1/60
   TestAssert "twin lasers", st("twin") is true and st("powers") is 0
   putOnShip "shield"
   step 1/60
   TestAssert "a shield", st("shield") is true
   putOnShip "bolt"
   step 1/60
   TestAssert "the shield takes a bolt", st("hull") is 3 and st("bolts") is 0
   game "nrTestSet", "hull", 2
   putOnShip "repair"
   step 1/60
   TestAssert "a repair mends the hull", st("hull") is 3
   put st("score") into tScore
   putOnShip "repair"
   step 1/60
   TestAssert "on a whole hull it scores 500", st("score") is tScore + 500
   put st("score") into tScore
   putOnShip "star"
   step 1/60
   TestAssert "a star", st("starsrun") is 1 and st("score") is tScore + 100
   step 12
   TestAssert "the twin lasers and the shield run out", st("twin") is false and st("shield") is false
end TestPowerUps

----------------------------------------------------------------------
-- Sectors

on TestASectorEndsWhenItsCrewIsRescued
   newRun
   TestAssert "the first sector needs five", st("quota") is 5
   game "nrTestSet", "rescued", 4
   putOnShip "pod"
   step 1/60
   TestAssert "the fifth clears the sector", st("phase") is "calm"
   TestAssert "the score: 250, then 500 for the sector and 100 a hull point", st("score") is 250 + 500 + 300
   TestAssert "and a star", st("starsrun") is 1
   TestAssert "the banner says so", fieldText("Banner Text") is "SECTOR 1 CLEAR" and \
         fieldText("Banner Sub") is "+800   +1 STAR"
   step 3.3
   TestAssert "then the next sector", st("sector") is 2 and st("rescued") is 0 and st("phase") is empty
   TestAssert "needs six", st("quota") is 6 and fieldText("Banner Sub") is "RESCUE 6 CREW"
   TestAssert "the HUD shows it", fieldText("Sector") is "SECTOR 2" and fieldText("Crew") is "0/6"
end TestASectorEndsWhenItsCrewIsRescued

on TestTheFourthSectorEndsWithAMothership
   local i
   newRun
   game "nrTestSet", "sector", 4
   game "nrTestSet", "rescued", 7
   putOnShip "pod"
   step 1/60
   TestAssert "the crew rescued, a warning", st("phase") is "warn" and fieldText("Banner Text") is "WARNING"
   step 2.7
   TestAssert "then the mothership", st("phase") is "boss" and st("boss") is true and st("bosshp") is 60
   TestAssert "with its bar", the visible of field "Boss Label" of card "Space" of stack kStack
   putOnShip "shield"
   step 1/60
   game "nrTestSet", "bosshp", 1
   repeat with i = 1 to 480
      game "nrTestShip", st("bossx"), st("shipy")
      step 1/60
      if st("boss") is false then
         exit repeat
      end if
   end repeat
   TestAssert "the lasers bring it down", st("boss") is false
   TestAssert "the sector is clear", st("phase") is "calm" and fieldText("Banner Text") is "SECTOR 4 CLEAR"
   TestAssert "the score: 2000 for it, 250 for the rescue, 2300 for the sector", st("score") >= 4550
   TestAssert "three stars for it and one for the sector", st("starsrun") is 4
   TestAssert "the bar is gone", not the visible of field "Boss Label" of card "Space" of stack kStack
end TestTheFourthSectorEndsWithAMothership

----------------------------------------------------------------------
-- Layout

-- Every button of every screen on the window and clear of the others,
-- the HUD on it, the ship's bounds in the column
private command checkLayout pWidth, pHeight
   local tCard, tColumn, tScreen, tGroup, tRects, tName, tRect, tOther, tBad, tField, tLines, i, j
   windowSize pWidth, pHeight
   if the width of stack kStack is not pWidth or the height of stack kStack is not pHeight then
      TestSkip "at" && pWidth & "x" & pHeight, "the window could not be made that size here"
      exit checkLayout
   end if
   put 0, 0, pWidth, pHeight into tCard
   put st("column") into tColumn
   TestAssert "at" && pWidth & "x" & pHeight & ": the column is on the window", isInside(tColumn, tCard)
   TestAssert "at" && pWidth & "x" & pHeight & ": the ship stays in it", isInside(st("bounds"), tColumn)
   repeat for each item tName in "Score,Sector,Crew,Streak,Pause"
      if not isInside(the rect of control tName of card "Space" of stack kStack, tCard) then
         put tName & space after tBad
      end if
   end repeat
   TestAssert "at" && pWidth & "x" & pHeight & ": the HUD is on the window" && tBad, tBad is empty
   -- the words of the screens show every line whole: a field as tall
   -- as its formattedHeight with no margins cut off the tops of its
   -- first line and the tails of its last (seen on Windows and in a
   -- browser)
   put empty into tBad
   repeat for each item tName in "Tagline,Howto Text 1,Howto Text 2,Howto Text 3,Howto Text 4,Credits"
      put the long id of field tName of card "Space" of stack kStack into tField
      if not the visible of tField then
         next repeat
      end if
      put the number of lines of the formattedText of tField into tLines
      if the height of tField < tLines * the effective textHeight of tField then
         put tName && "is shorter than its" && tLines && "lines;" after tBad
      end if
      if item 2 of the margins of tField < 4 or item -1 of the margins of tField < 4 then
         put tName && "has no room above or below its lines;" after tBad
      end if
   end repeat
   TestAssert "at" && pWidth & "x" & pHeight & ": the words show whole" && tBad, tBad is empty
   repeat for each item tScreen in "Title,Howto,Paused,Over,Settings"
      put empty into tRects
      put empty into tBad
      put the long id of group tScreen of card "Space" of stack kStack into tGroup
      repeat with i = 1 to the number of buttons of tGroup
         put the short name of button i of tGroup into tName
         -- (the face of each button over its shape; the ones a window
         -- does not show, Full Screen, left out)
         if there is a graphic (tName && "Shape") of card "Space" of stack kStack and \
               the visible of button i of tGroup then
            put the rect of button i of tGroup into tRect
            if not isInside(tRect, tCard) then
               put tName && "off the window;" after tBad
            end if
            if item 4 of tRect - item 2 of tRect < 34 then
               put tName && "too small to tap;" after tBad
            end if
            put tName & tab & tRect & return after tRects
         end if
      end repeat
      set the itemDelimiter to tab
      repeat with i = 1 to the number of lines of tRects
         repeat with j = i + 1 to the number of lines of tRects
            if overlap(item 2 of line i of tRects, item 2 of line j of tRects) then
               put item 1 of line i of tRects && "on" && item 1 of line j of tRects & ";" after tBad
            end if
         end repeat
      end repeat
      set the itemDelimiter to comma
      TestAssert "at" && pWidth & "x" & pHeight & ":" && tScreen && "has its buttons on the window, apart" && tBad, \
            tBad is empty and tRects is not empty
   end repeat
end checkLayout

on TestTheScreensFitAPhone
   checkLayout 390, 760
   checkLayout 320, 568
end TestTheScreensFitAPhone

on TestTheScreensFitAPhoneOnItsSide
   checkLayout 844, 390
   TestAssert "the HUD is beside the column", \
         item 3 of the rect of field "Score" of card "Space" of stack kStack <= item 1 of st("column")
end TestTheScreensFitAPhoneOnItsSide

on TestTheScreensFitAWindow
   checkLayout 1024, 700
   checkLayout 768, 1024
end TestTheScreensFitAWindow

-- A phone turned in the middle of a run: everything moves with the
-- column, and the run waits
on TestTurningThePhonePausesTheRun
   local tColumn, tShipX, tShift, tNear
   windowSize 390, 760
   if the width of stack kStack is not 390 then
      TestSkip "turning the phone", "the window could not be made that size here"
      exit TestTurningThePhonePausesTheRun
   end if
   newRun
   putOnShip "pod"
   put1 "big", st("shipx") - 100, 300, 0
   step 1/60
   put st("column") into tColumn
   put st("shipx") into tShipX
   windowSize 844, 390
   if the width of stack kStack is not 844 then
      TestSkip "turning the phone", "the window could not be made that size here"
      exit TestTurningThePhonePausesTheRun
   end if
   put item 1 of st("column") - item 1 of tColumn into tShift
   TestAssert "the column moved", tShift > 0
   TestAssert "the run is paused", st("mode") is "pause" and shown("Paused")
   TestAssert "the ship moved with it", abs(st("shipx") - tShipX - tShift) <= 1
   TestAssert "and is still on the window", isInside(st("bounds"), st("column"))
   put item 1 of st("column") - 60, -60, item 3 of st("column") + 60, 450 into tNear
   TestAssert "the meteor too", isInside(the rect of button "Rock 1" of card "Space" of stack kStack, tNear)
   TestAssert "the crew's bar is filled from its new place", \
         item 1 of the rect of graphic "Bar Fill" of card "Space" of stack kStack is \
         item 1 of the rect of graphic "Bar Back" of card "Space" of stack kStack
end TestTurningThePhonePausesTheRun

-- After the turn, raiders go on from where they were: a weaver weaves
-- about an x, which moves with the column, and a ufo bobs about a y,
-- which a column moved sideways leaves as it was (until 2026-11-07 it
-- moved the ufo down by as much as the column moved across)
on TestTurningThePhoneKeepsTheRaidersCourses
   local tColumn, tShift, tWeaver, tUfo, tNow
   windowSize 390, 760
   if the width of stack kStack is not 390 then
      TestSkip "turning the phone", "the window could not be made that size here"
      exit TestTurningThePhoneKeepsTheRaidersCourses
   end if
   newRun
   put1 "weaver", 195, 200
   put1 "ufo"
   step 1/60
   TestAssert "a weaver and a ufo", st("foes") is 2
   put st("column") into tColumn
   put the loc of button "Foe 1" of card "Space" of stack kStack into tWeaver
   put the loc of button "Foe 2" of card "Space" of stack kStack into tUfo
   windowSize 844, 390
   if the width of stack kStack is not 844 then
      TestSkip "turning the phone", "the window could not be made that size here"
      exit TestTurningThePhoneKeepsTheRaidersCourses
   end if
   put item 1 of st("column") - item 1 of tColumn into tShift
   TestAssert "the column moved", tShift > 0
   press "Resume"
   step 1/60
   put the loc of button "Foe 1" of card "Space" of stack kStack into tNow
   TestAssert "the weaver goes on across with the column", \
         abs(item 1 of tNow - item 1 of tWeaver - tShift) <= 4 and abs(item 2 of tNow - item 2 of tWeaver) <= 4
   put the loc of button "Foe 2" of card "Space" of stack kStack into tNow
   TestAssert "the ufo goes on across with the column", abs(item 1 of tNow - item 1 of tUfo - tShift) <= 4
   TestAssert "and at the height it was", abs(item 2 of tNow - item 2 of tUfo) <= 4
end TestTurningThePhoneKeepsTheRaidersCourses

----------------------------------------------------------------------
-- Numbers

on TestNumbersWithCommas
   local tCase, tOut
   repeat for each line tCase in "0 0" & return & "7 7" & return & "999 999" & return & \
         "1000 1,000" & return & "16000 16,000" & return & "250000 250,000" & return & \
         "1234567 1,234,567" & return & "99.6 100"
      dispatch function "nrCommas" to stack kStack with word 1 of tCase
      put the result into tOut
      TestAssert "commas:" && word 1 of tCase && "is" && word 2 of tCase, tOut is word 2 of tCase
   end repeat
end TestNumbersWithCommas
