script "TestWobbleForts"
-- OXT-Beyond: the Wobble Forts game (the committed
-- tools/web-player/stacks/Wobble Forts.oxtstack, built by
-- tools/web-player/wobble-forts.livecodescript from
-- tools/web-player/wobble-forts-stack.livecodescript and
-- wobble-forts/levels.txt), on a desktop engine.
--
-- The game plays on Box2D, through the xTalk Suite's Box2Dxt, which the
-- Stack Player's web engine has built in. A desktop engine has it only
-- as an extension: set OXT_BOX2DXT to Box2Dxt's folder (its module.lcm
-- and its library), a folder with it in, or an installed IDE's folder,
-- and these tests load it (loadBox2D);
-- without it the tests of play are skipped, and the game is checked
-- opening on its notice. tools/ci/wobble_forts_check.py plays it with
-- real touches in a phone's browser, Box2D and all.
--
-- The game's clock is in the test's hands: wfTestBegin stops its loop and
-- keeps what it saves in a file of the test's own; wfTestStep moves the
-- game on a sixtieth of a second at a time; wfTestShoot pulls a Bloop
-- back and lets it go as a finger would, wfTestTap does its trick, and
-- wfState says how things are. The buttons are pressed through wfPress,
-- as their scripts do.

constant kStack = "Wobble Forts"

local sSave

on TestSetup
   local tFile
   loadBox2D
   put specialFolderPath("temporary") & "/wobble-forts-test-" & the milliseconds & ".txt" into sSave
   if there is a file sSave then
      delete file sSave
   end if
   put TestGetEngineRepositoryPath() & "/tools/web-player/stacks/Wobble Forts.oxtstack" into tFile
   go stack tFile
   game "wfTestBegin", 7, sSave
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
   if sSave is not empty and there is a file sSave then
      delete file sSave
   end if
end TestTeardown

-- Box2Dxt from OXT_BOX2DXT, once (an engine that has it already, or no
-- such folder: nothing to do). The folder is the extension's own (its
-- module.lcm, and its library beside it or in code/<platform>/, as
-- tools/oxt/xtalk_extensions.py builds it), or one with the extension's
-- folder in it, or an installed IDE's (its Extensions folder)
private command loadBox2D
   local tRoot, tFolder, tTry, tLib, tPick, tError
   try
      get b2Version()
      exit loadBox2D
   catch tError
   end try
   put $OXT_BOX2DXT into tRoot
   if tRoot is empty then
      exit loadBox2D
   end if
   repeat for each item tTry in ",/org.openxtalk.box2dxt,/Extensions/org.openxtalk.box2dxt"
      if there is a file (tRoot & tTry & "/module.lcm") then
         put tRoot & tTry into tFolder
         exit repeat
      end if
   end repeat
   if tFolder is empty then
      exit loadBox2D
   end if
   switch the platform
      case "Win32"
         put "box2dxt.dll" into tLib
         break
      case "MacOS"
         put "box2dxt.dylib" into tLib
         break
      default
         put "box2dxt.so" into tLib
   end switch
   if there is a file (tFolder & "/" & tLib) then
      set the revLibraryMapping["box2dxt"] to tFolder & "/" & tLib
   else
      -- code/<processor>-<platform>/ (x86_64-linux), or the one there is
      -- (universal-mac)
      -- (the mapping is only set: an engine without one throws on reading it)
      repeat for each line tTry in folders(tFolder & "/code")
         if there is a file (tFolder & "/code/" & tTry & "/" & tLib) then
            if tPick is empty or (tTry begins with (the processor & "-")) then
               put tFolder & "/code/" & tTry & "/" & tLib into tPick
            end if
         end if
      end repeat
      if tPick is not empty then
         set the revLibraryMapping["box2dxt"] to tPick
      end if
   end if
   try
      load extension from file (tFolder & "/module.lcm") with resource path tFolder
   end try
end loadBox2D

----------------------------------------------------------------------
-- Helpers

private command game pHandler, p1, p2, p3
   dispatch pHandler to stack kStack with p1, p2, p3
end game

-- One value of the game's wfState
private function st pKey
   local tState
   dispatch function "wfState" to stack kStack
   put the result into tState
   split tState by return and ":"
   return tState[pKey]
end st

private function physics
   return st("physics") is true
end physics

private command step pSeconds
   game "wfTestStep", pSeconds
end step

private command press pButton
   game "wfPress", pButton
end press

private function fieldText pName
   return the text of field pName of card "Fort" of stack kStack
end fieldText

private function shown pGroup
   return the visible of group pGroup of card "Fort" of stack kStack
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

private command windowSize pWidth, pHeight
   set the rect of stack kStack to 0, 0, pWidth, pHeight
   game "wfResized"
end windowSize

-- The game on, until the shot in the air is over (at most pSeconds)
private command untilAim pSeconds
   repeat pSeconds * 4 times
      if st("mode") is not "fly" then
         exit repeat
      end if
      step 0.25
   end repeat
end untilAim

-- A level played, its Bloop in the launcher
private command playLevel pLevel
   game "wfPlay", pLevel
   step 0.5
end playLevel

-- A key pressed (its keysym: 32 Space, 65293 Return, 80 P, 114 r)
private command key pKey
   game "rawKeyDown", pKey
end key

-- Skipped, and false, without Box2D
private function needBox2D pWhat
   if physics() then
      return true
   end if
   TestSkip pWhat, "no Box2D here: set OXT_BOX2DXT to a folder with Box2Dxt's module.lcm and library"
   return false
end needBox2D

----------------------------------------------------------------------
-- What is in the stack

-- Every picture of the art list on the Art card, every sound the game
-- plays, the font and the fifteen levels
on TestEverythingTheGameNeedsIsInTheStack
   local tList, tLine, tMissing, tSounds, tScript, tAt, tName, tCount
   put url ("file:" & TestGetEngineRepositoryPath() & "/tools/web-player/wobble-forts/art/art.txt") into tList
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
   -- every sound the game names (wfSound "<name>", ...)
   put the customProperties["cSounds"] of stack kStack into tSounds
   put empty into tMissing
   put 0 into tCount
   put the script of stack kStack into tScript
   repeat while tScript contains "wfSound" & space & quote
      put offset("wfSound" & space & quote, tScript) into tAt
      delete char 1 to tAt + 8 of tScript
      put char 1 to offset(quote, tScript) - 1 of tScript into tName
      add 1 to tCount
      -- (a name made as it plays, "star" & k, is checked below)
      if char offset(quote, tScript) + 1 to offset(quote, tScript) + 2 of tScript is " &" then
         next repeat
      end if
      if tSounds[tName] is empty then
         put tName & space after tMissing
      end if
   end repeat
   TestAssert "the game plays sounds", tCount > 15
   TestAssert "and every one is in the stack" && tMissing, tMissing is empty
   put empty into tMissing
   -- and the ones it makes of a material: wood, wood-break, ...
   repeat for each item tName in "wood,glass,stone,metal,wood-break,glass-break,stone-break,star1,star2,star3"
      if tSounds[tName] is empty then
         put tName & space after tMissing
      end if
   end repeat
   TestAssert "and the knocks and breaks of each material" && tMissing, tMissing is empty
   TestAssert "the font is in the stack", the cFont of stack kStack is not empty
   TestAssert "fifteen levels", st("levels") is 15
end TestEverythingTheGameNeedsIsInTheStack

-- Every level of cLevels makes sense: a land, Bloops of the five
-- colours, pieces of kinds there are pictures of, a Grump at least
on TestEveryLevelReads
   local tLevels, tLine, tBad, n, tGrumps, tKind, tColor, tLand
   put the cLevels of stack kStack into tLevels
   put 0 into n
   repeat for each line tLine in tLevels
      put word 1 to -1 of tLine into tLine
      if tLine is empty or char 1 of tLine is "#" then
         next repeat
      end if
      switch word 1 of tLine
         case "level"
            add 1 to n
            put 0 into tGrumps
            put empty into tLand
            break
         case "land"
            put word 2 of tLine into tLand
            if tLand is not among the items of "1,2,3" then
               put "level" && n && "is in land" && tLand & ";" after tBad
            end if
            break
         case "bloops"
            if the number of words of tLine < 2 or the number of words of tLine > 7 then
               put "level" && n && "has" && the number of words of tLine - 1 && "Bloops;" after tBad
            end if
            repeat with tKind = 2 to the number of words of tLine
               if word tKind of tLine is not among the items of "yellow,blue,pink,green,beige" then
                  put "level" && n && "has a" && word tKind of tLine && "Bloop;" after tBad
               end if
            end repeat
            break
         case "hint"
            break
         case "end"
            if tGrumps is 0 then
               put "level" && n && "has no Grump;" after tBad
            end if
            break
         default
            put word 1 of tLine into tKind
            if tKind begins with "grump-" or tKind begins with "boss-" then
               add 1 to tGrumps
               put tKind into tColor
            else
               put tKind & "-whole" into tColor
            end if
            if there is not an image tColor of card "Art" of stack kStack then
               put "level" && n && "has a" && tKind & ";" after tBad
            end if
            if word 2 of tLine is not a number or word 3 of tLine is not a number or word 3 of tLine < 0 then
               put "level" && n && "has a piece at" && word 2 to 3 of tLine & ";" after tBad
            end if
      end switch
   end repeat
   TestAssert "fifteen levels" && n, n is 15
   TestAssert "each makes sense" && tBad, tBad is empty
end TestEveryLevelReads

----------------------------------------------------------------------
-- Opening

on TestTheGameOpensOnItsTitleOrItsNotice
   if physics() then
      TestAssert "with Box2D: the title", st("mode") is "title" and shown("Title")
      TestAssert "over the first level's fort", st("level") is 1 and st("pieces") > 0 and st("grumps") > 0
      TestAssert "no notice", not shown("Notice")
   else
      TestAssert "without Box2D: the notice", st("mode") is "notice" and shown("Notice")
      TestAssert "and not the title", not shown("Title")
      TestAssert "which says why", fieldText("Notice Text") contains "Box2Dxt"
   end if
   TestAssert "the HUD is not shown", not shown("HUD")
   TestAssert "nor the other screens", not shown("Map") and not shown("Howto") and \
         not shown("Paused") and not shown("Clear") and not shown("Fail")
end TestTheGameOpensOnItsTitleOrItsNotice

on TestHowToPlayComesBeforeTheFirstMapOnly
   if not needBox2D("how to play, then the map") then
      exit TestHowToPlayComesBeforeTheFirstMapOnly
   end if
   press "Play"
   TestAssert "the first Play shows how to play", st("mode") is "howto" and shown("Howto")
   press "Howto Go"
   TestAssert "then the map of the first land", st("mode") is "map" and shown("Map") and st("map") is 1
   TestAssert "it is saved as seen", "howto=true" is among the lines of saved()
   press "Map Home"
   TestAssert "home goes to the title", st("mode") is "title"
   press "Play"
   TestAssert "the next Play goes to the map at once", st("mode") is "map"
   press "Title Howto"
end TestHowToPlayComesBeforeTheFirstMapOnly

on TestTheMapOpensOnlyWhatWasCleared
   if not needBox2D("the map") then
      exit TestTheMapOpensOnlyWhatWasCleared
   end if
   game "wfShowMap", 1
   TestAssert "the first level is open", the visible of field "Tile 1 Label" of card "Fort" of stack kStack
   TestAssert "the second is locked", the visible of image "Tile 2 Lock" of card "Fort" of stack kStack
   press "Tile 2"
   TestAssert "and a locked one does not play", st("mode") is "map"
   press "Map Next"
   TestAssert "the arrow shows the next land", st("map") is 2 and fieldText("Map Title") is "DUNES"
   press "Map Next"
   TestAssert "and the last", st("map") is 3 and not the visible of button "Map Next" of card "Fort" of stack kStack
   press "Map Prev"
   press "Map Prev"
   TestAssert "and back", st("map") is 1 and not the visible of button "Map Prev" of card "Fort" of stack kStack
   press "Tile 1"
   TestAssert "the first level plays", st("mode") is "aim" and st("level") is 1 and shown("HUD")
end TestTheMapOpensOnlyWhatWasCleared

----------------------------------------------------------------------
-- Play

-- Each level, left alone, stands still: no piece slides, none falls,
-- and the world goes to sleep
on TestEveryLevelStandsStill
   local n, tBad
   if not needBox2D("the levels standing") then
      exit TestEveryLevelStandsStill
   end if
   repeat with n = 1 to st("levels")
      game "wfPlay", n
      step 4
      if st("drift") > 3 then
         put "level" && n && "moved" && st("drift") && "units;" after tBad
      end if
      if st("awake") is not 0 then
         put "level" && n && "is still moving;" after tBad
      end if
      if st("score") is not 0 or st("mode") is not "aim" then
         put "level" && n && "broke by itself;" after tBad
      end if
   end repeat
   TestAssert "every level stands" && tBad, tBad is empty
end TestEveryLevelStandsStill

on TestAShotFliesAndTheNextBloopComes
   local tQueue
   if not needBox2D("a shot") then
      exit TestAShotFliesAndTheNextBloopComes
   end if
   playLevel 1
   put st("queue") into tQueue
   TestAssert "a Bloop is in the launcher", st("loaded") is "yellow"
   game "wfTestShoot", -6, 4
   TestAssert "a short pull is no shot", st("mode") is "aim" and st("shots") is 0
   -- (a lob that falls short of the fort)
   game "wfTestShoot", -20, 128
   TestAssert "a long one is", st("mode") is "fly" and st("shots") is 1 and st("bloops") is 1
   step 0.5
   TestAssert "the Bloop flies up and to the right", item 1 of st("flyer") > 290 and item 2 of st("flyer") < 500
   untilAim 20
   TestAssert "the shot ends", st("mode") is "aim" or st("mode") is "clear"
   step 0.5
   TestAssert "the next Bloop is in the launcher", st("loaded") is word 1 of tQueue
   TestAssert "and the last one is gone", st("bloops") is 0
end TestAShotFliesAndTheNextBloopComes

-- Every Grump popped: the Bloops left are counted, the stars given and
-- kept, the next level opened
on TestPoppingEveryGrumpClearsTheFort
   if not needBox2D("a fort cleared") then
      exit TestPoppingEveryGrumpClearsTheFort
   end if
   playLevel 1
   game "wfTestPopGrumps"
   TestAssert "no Grumps left", st("grumps") is 0
   TestAssert "a thousand points a Grump", st("score") is 2000
   step 2
   TestAssert "the fort is down", st("mode") is "clear" and shown("Clear")
   TestAssert "three Bloops left: three stars", st("levelstars") is 3
   TestAssert "and fifteen hundred points each", st("score") is 6500 and st("best") is 6500
   TestAssert "kept", "level1=3,6500" is among the lines of saved()
   step 5
   TestAssert "the score is counted up", fieldText("Clear Score") is "6,500"
   TestAssert "a new best", fieldText("Clear Best") is "NEW BEST!"
   TestAssert "the stars are gold", the cPicture of image "Clear Star 3" of card "Fort" of stack kStack is "star-gold"
   press "Clear Next"
   TestAssert "Next plays the next level", st("mode") is "aim" and st("level") is 2
   press "Pause"
   press "Pause Levels"
   TestAssert "which is open on the map", not the visible of image "Tile 2 Lock" of card "Fort" of stack kStack
   key 32
   TestAssert "where Space plays the next fort to clear", st("mode") is "aim" and st("level") is 2
end TestPoppingEveryGrumpClearsTheFort

-- The keys alone play, from the title to a fort (a page on a computer
-- gives the game the keys at once: tools/pages/check_wobble_forts_page.py)
on TestTheKeysAlonePlay
   if not needBox2D("the keys") then
      exit TestTheKeysAlonePlay
   end if
   key 32
   TestAssert "Space on the title shows how to play", st("mode") is "howto"
   key 65293
   TestAssert "Return then shows the map", st("mode") is "map"
   key 32
   TestAssert "and Space plays the first fort", st("mode") is "aim" and st("level") is 1
   step 0.5
   key 80
   TestAssert "P pauses", st("mode") is "pause"
   key 32
   TestAssert "Space plays on", st("mode") is "aim"
   game "wfTestShoot", 0, -120
   step 0.3
   key 114
   TestAssert "r plays the fort again", st("mode") is "aim" and st("shots") is 0
end TestTheKeysAlonePlay

-- Bloops sent into the ground: no Grump popped, and no Bloops left
on TestOutOfBloops
   if not needBox2D("out of Bloops") then
      exit TestOutOfBloops
   end if
   playLevel 1
   repeat 3
      game "wfTestShoot", 0, -120
      untilAim 20
      step 0.5
   end repeat
   step 2
   TestAssert "the level is lost", st("mode") is "fail" and shown("Fail")
   TestAssert "saying how many Grumps held on", fieldText("Fail Text") begins with "2 Grumps"
   TestAssert "and nothing is kept", st("levelstars") is empty
   press "Fail Retry"
   TestAssert "try again plays it again", st("mode") is "aim" and st("shots") is 0 and st("grumps") is 2
end TestOutOfBloops

-- The tricks: Zip (blue) dashes, Trio (pink) splits in three, Thud
-- (green) drops, Boom (beige) goes bang; yellow has none. Level 4 has
-- yellow, blue, pink; level 9 yellow, blue, green, beige
on TestTheTricks
   local tX, tY
   if not needBox2D("the tricks") then
      exit TestTheTricks
   end if
   -- a lob, high over the forts, each time: where it is 0.6 s on
   playLevel 4
   game "wfTestShoot", -60, 120
   step 0.3
   game "wfTestTap"
   step 0.3
   put item 1 of st("flyer") into tX
   TestAssert "yellow: no trick", st("bloops") is 1 and tX > 400
   untilAim 20
   step 0.5
   game "wfTestShoot", -60, 120
   step 0.3
   game "wfTestTap"
   step 0.3
   TestAssert "blue dashes: further on" && item 1 of st("flyer") && "than" && tX, item 1 of st("flyer") > tX + 20
   untilAim 20
   step 0.5
   game "wfTestShoot", -60, 120
   step 0.3
   game "wfTestTap"
   TestAssert "pink splits in three", st("bloops") is 3
   game "wfTestTap"
   TestAssert "once", st("bloops") is 3
   playLevel 9
   game "wfTestShoot", -60, 120
   untilAim 20
   step 0.5
   game "wfTestShoot", -60, 120
   untilAim 20
   step 0.5
   TestAssert "level 9: green next", st("loaded") is "green"
   game "wfTestShoot", -60, 120
   step 0.3
   put item 2 of st("flyer") into tY
   game "wfTestTap"
   step 0.2
   TestAssert "green drops", item 2 of st("flyer") > tY + 40
   untilAim 20
   step 0.5
   TestAssert "beige next", st("loaded") is "beige"
   game "wfTestShoot", -60, 120
   step 0.3
   game "wfTestTap"
   TestAssert "beige goes bang, and is gone", st("bloops") is 0
end TestTheTricks

on TestAPauseStopsTheClock
   local tNow
   if not needBox2D("a pause") then
      exit TestAPauseStopsTheClock
   end if
   playLevel 1
   game "wfTestShoot", -120, 40
   step 0.2
   press "Pause"
   TestAssert "paused", st("mode") is "pause" and shown("Paused")
   put st("now") into tNow
   step 1
   TestAssert "the clock waits", st("now") is tNow
   press "Resume"
   TestAssert "and goes on", st("mode") is "fly" and not shown("Paused")
   dispatch "rawKeyDown" to card "Fort" of stack kStack with 112
   TestAssert "P pauses", st("mode") is "pause"
   dispatch "rawKeyDown" to card "Fort" of stack kStack with 65307
   TestAssert "Escape goes on", st("mode") is "fly"
   dispatch "rawKeyDown" to card "Fort" of stack kStack with 114
   TestAssert "R plays it again", st("mode") is "aim" and st("shots") is 0
end TestAPauseStopsTheClock

-- The physics keeps the clock's pace whatever the screen's: frames of
-- a hundredth step 3 times in 5, a sixtieth once, a twentieth 3 times,
-- and a frame of a tenth at most kMaxSteps (3), the rest forgiven
on TestThePhysicsKeepsTheClocksPace
   local tFrom, tFrame, tSteps, tWant, tBad
   if not needBox2D("the physics' pace") then
      exit TestThePhysicsKeepsTheClocksPace
   end if
   playLevel 1
   repeat for each item tFrame in "0.01,0.0166667,0.05,0.1"
      put st("steps") into tFrom
      game "wfTestStep", 1, tFrame
      put st("steps") - tFrom into tSteps
      if tFrame is 0.1 then
         put 30 into tWant
      else
         put 60 into tWant
      end if
      if abs(tSteps - tWant) > 1 then
         put "frames of" && tFrame & ":" && tSteps && "steps, not" && tWant & ";" after tBad
      end if
   end repeat
   TestAssert "a second of frames is a second of physics" && tBad, tBad is empty
end TestThePhysicsKeepsTheClocksPace

----------------------------------------------------------------------
-- Kept between visits

on TestASavedFileThatMakesNoSense
   put "level1=3,9000" & return & "level2=9,1" & return & "level99=2,5" & return & "levelx=1,1" & return & \
         "level3=2" & return & "sound=false" & return & "howto=true" & return & "nonsense" into url ("file:" & sSave)
   game "wfLoad"
   TestAssert "a good level is read", st("stars") is 3
   TestAssert "the sound setting is", st("sound") is false
   TestAssert "and how to play seen", st("howto") is true
   dispatch function "wfUnlocked" to stack kStack with 2
   TestAssert "level 2 is open", the result is true
   dispatch function "wfUnlocked" to stack kStack with 3
   TestAssert "level 3 is not (level 2's line made no sense)", the result is false
end TestASavedFileThatMakesNoSense

----------------------------------------------------------------------
-- Layout

-- Every button of every screen on the window, big enough and clear of
-- the others; the HUD on the window; the words whole
private command checkLayout pWidth, pHeight
   local tCard, tScreen, tGroup, tRects, tName, tRect, tBad, tField, tLines, i, j
   windowSize pWidth, pHeight
   if the width of stack kStack is not pWidth or the height of stack kStack is not pHeight then
      TestSkip "at" && pWidth & "x" & pHeight, "the window could not be made that size here"
      exit checkLayout
   end if
   put 0, 0, pWidth, pHeight into tCard
   repeat for each item tName in "Score,Level Name,Pause"
      if not isInside(the rect of control tName of card "Fort" of stack kStack, tCard) then
         put tName & space after tBad
      end if
   end repeat
   TestAssert "at" && pWidth & "x" & pHeight & ": the HUD is on the window" && tBad, tBad is empty
   put empty into tBad
   repeat for each item tName in "Tagline,Howto Text 1,Howto Text 2,Howto Text 3,Fail Text,Notice Text"
      put the long id of field tName of card "Fort" of stack kStack into tField
      put the number of lines of the formattedText of tField into tLines
      if the height of tField < tLines * the effective textHeight of tField then
         put tName && "is shorter than its" && tLines && "lines;" after tBad
      end if
   end repeat
   TestAssert "at" && pWidth & "x" & pHeight & ": the words show whole" && tBad, tBad is empty
   repeat for each item tScreen in "Title,Map,Howto,Paused,Clear,Fail"
      put empty into tRects
      put empty into tBad
      put the long id of group tScreen of card "Fort" of stack kStack into tGroup
      repeat with i = 1 to the number of buttons of tGroup
         put the short name of button i of tGroup into tName
         if the visible of button i of tGroup then
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
      if there is a graphic (tScreen && "Card") of tGroup and \
            not isInside(the rect of graphic (tScreen && "Card") of tGroup, tCard) then
         put "its panel is off the window;" after tBad
      end if
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
   checkLayout 360, 640
end TestTheScreensFitAPhone

on TestTheScreensFitAPhoneOnItsSide
   checkLayout 844, 390
   checkLayout 667, 375
end TestTheScreensFitAPhoneOnItsSide

on TestTheScreensFitAWindow
   checkLayout 960, 540
   checkLayout 1280, 800
end TestTheScreensFitAWindow

-- The world fills the window across its played part, its ground at the
-- bottom; a level is drawn in it
on TestTheWorldFitsTheWindow
   local tRect
   windowSize 960, 540
   if the width of stack kStack is not 960 then
      TestSkip "the world", "the window could not be made that size here"
      exit TestTheWorldFitsTheWindow
   end if
   TestAssert "the scale", st("view") is 0.6
   TestAssert "the ground across the window", the visible of image "Ground 1" of card "Fort" of stack kStack and \
         item 4 of the rect of graphic "Dirt" of card "Fort" of stack kStack is 540
   if physics() then
      put the rect of image "Piece 1" of card "Fort" of stack kStack into tRect
      TestAssert "a piece of the fort is on the window", the visible of image "Piece 1" of card "Fort" of stack kStack and \
            isInside(tRect, "0,0,960,540")
   end if
end TestTheWorldFitsTheWindow

----------------------------------------------------------------------
-- Numbers

on TestNumbersWithCommas
   local tCase, tOut
   repeat for each line tCase in "0 0" & return & "7 7" & return & "999 999" & return & \
         "1000 1,000" & return & "16000 16,000" & return & "250000 250,000" & return & \
         "1234567 1,234,567" & return & "99.6 100"
      dispatch function "wfCommas" to stack kStack with word 1 of tCase
      put the result into tOut
      TestAssert "commas:" && word 1 of tCase && "is" && word 2 of tCase, tOut is word 2 of tCase
   end repeat
end TestNumbersWithCommas
