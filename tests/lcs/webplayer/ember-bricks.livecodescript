script "TestEmberBricks"
-- OXT-Beyond: the Ember Bricks game (the committed
-- tools/web-player/stacks/Ember Bricks.oxtstack, built by
-- tools/web-player/ember-bricks.livecodescript from
-- tools/web-player/ember-bricks-stack.livecodescript), on a desktop engine.
--
-- The game's clock is in the test's hands: ebTestBegin stops its loop,
-- fixes the random seed and keeps what it saves in a file of the test's
-- own; ebTestStep moves the game on, a sixtieth of a second at a time;
-- ebTestLevel puts a wall of the test's own in the arena, ebTestBall a
-- ball in flight, ebTestPaddle the paddle, ebTestDrop a falling spark,
-- and ebState says how things are. The buttons are pressed through
-- ebPress, as their scripts do. A duel is played with nobody at its other
-- end (ebTestDuel): what the game would send is read with ebDuelSent, and
-- the test says what the rival does with ebDuelReceive. The online lobby
-- is played with no relay behind it (ebTestNet): what it would send is
-- read with ebNetSent, and the test says what the other players do with
-- ebNetHear.

constant kStack = "Ember Bricks"
constant kCard = "Game"

local sSave, sSent

on TestSetup
   local tFile
   put specialFolderPath("temporary") & "/ember-bricks-test-" & the milliseconds & ".txt" into sSave
   if there is a file sSave then
      delete file sSave
   end if
   put TestGetEngineRepositoryPath() & "/tools/web-player/stacks/Ember Bricks.oxtstack" into tFile
   go stack tFile
   game "ebTestBegin", 7, sSave
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
   -- (the engine has one cursor and one tool for every test: none
   -- begins with what another left)
   set the lockCursor to false
   choose browse tool
   if sSave is not empty and there is a file sSave then
      delete file sSave
   end if
end TestTeardown

----------------------------------------------------------------------
-- Helpers

private command game pHandler, p1, p2, p3, p4, p5
   dispatch pHandler to stack kStack with p1, p2, p3, p4, p5
end game

private function gameSays pFunction, p1, p2
   dispatch function pFunction to stack kStack with p1, p2
   return the result
end gameSays

-- One value of the game's ebState
private function st pKey
   local tState, tLine
   put gameSays("ebState") into tState
   set the itemDelimiter to ":"
   repeat for each line tLine in tState
      if item 1 of tLine is pKey then
         return item 2 to -1 of tLine
      end if
   end repeat
   return "no such key"
end st

-- The first ball in play: its x (1), y (2), dx (3), dy (4), and whether
-- it waits on the paddle (5)
private function ball pItem
   return item pItem of st("ball")
end ball

private command step pSeconds
   game "ebTestStep", pSeconds
end step

private command press pButton
   game "ebPress", pButton
end press

private function fieldText pName
   return the text of field pName of card kCard of stack kStack
end fieldText

private function shown pGroup
   return the visible of group pGroup of card kCard of stack kStack
end shown

private function saved
   local tText
   put url ("file:" & sSave) into tText
   return tText
end saved

-- A run from level 1 with no spark falling by chance
private command newRun pLevel
   if pLevel is empty then
      put 1 into pLevel
   end if
   game "ebNewRun", pLevel
   game "ebTestSet", "drops", false
end newRun

-- The rows of a wall with a brick in each of the places pBricks names,
-- as "column,row,kind" with ";" between them
private function wall pBricks
   local tRows, tBrick, i
   repeat with i = 1 to 14
      put ".........." into line i of tRows
   end repeat
   set the itemDelimiter to ";"
   repeat for each item tBrick in pBricks
      set the itemDelimiter to comma
      put item 3 of tBrick into char (item 1 of tBrick) of line (item 2 of tBrick) of tRows
      set the itemDelimiter to ";"
   end repeat
   set the itemDelimiter to comma
   return tRows
end wall

-- A run at a wall of the test's own. A brick in the last place of the
-- grid (pKeep, the default) keeps the level from being cleared
private command newWall pBricks, pKeep
   newRun
   if pKeep is not false then
      if pBricks is empty then
         put "10,14,1" into pBricks
      else
         put ";10,14,1" after pBricks
      end if
   end if
   game "ebTestLevel", wall(pBricks)
end newWall

-- The brick in a column and row: its kind and the hits it takes
private function brick pCol, pRow
   return gameSays("ebBrick", pCol, pRow)
end brick

-- A ball straight up into the brick in pCol, pRow, and the game on until
-- it has hit it
private command hit pCol, pRow
   game "ebTestBall", (pCol - 0.5) * 32, 48 + pRow * 16 + 40, 0, -1
   step 0.4
end hit

-- A ball lost: past the paddle, which is at the other side
private command loseBall
   game "ebTestPaddle", 290
   game "ebTestBall", 20, 470, 0, 1
   step 0.2
end loseBall

-- The window at pWidth x pHeight, laid out again
private command windowSize pWidth, pHeight
   set the rect of stack kStack to 0, 0, pWidth, pHeight
   game "ebResized"
end windowSize

-- Whether rect pInner is wholly in rect pOuter
private function isInside pInner, pOuter
   return item 1 of pInner >= item 1 of pOuter and item 2 of pInner >= item 2 of pOuter and \
         item 3 of pInner <= item 3 of pOuter and item 4 of pInner <= item 4 of pOuter
end isInside

private function overlap pA, pB
   return item 1 of pA < item 3 of pB and item 1 of pB < item 3 of pA and \
         item 2 of pA < item 4 of pB and item 2 of pB < item 4 of pA
end overlap

private function rectOf pName
   return the rect of control pName of card kCard of stack kStack
end rectOf

-- How many of the rival's bricks a duel shows
private function rivalBricks
   local i, tCount
   put 0 into tCount
   repeat with i = 1 to 140
      if the visible of graphic ("Rival Brick" && i) of card kCard of stack kStack then
         add 1 to tCount
      end if
   end repeat
   return tCount
end rivalBricks

-- The middle of the arena, in the window's points
private function arenaMiddle
   local tArena
   put st("arena") into tArena
   return (item 1 of tArena + item 3 of tArena) div 2 & comma & (item 2 of tArena + item 4 of tArena) div 2
end arenaMiddle

-- The test's mouse at a point of the window (empty: not over it), and
-- the frame that sees it there
private command mouseAt pLoc
   game "ebTestSet", "mouse", pLoc
   step 1/60
end mouseAt

-- Whether the game has hidden the mouse's pointer and holds the
-- engine's cursor to keep it so; and whether it has not, and does not
private function pointerHidden
   return st("hidden") is true and the lockCursor is true
end pointerHidden

private function pointerShown
   return st("hidden") is false and the lockCursor is false
end pointerShown

-- Whether the game runs where it hides no pointer at all: on a phone or
-- a tablet (ebPointerHides), where a level is played with a finger.
-- A test of the hidden pointer is skipped there and says so, and
-- TestAPhoneOrATabletHidesNoPointer says what the game does there: with
-- LiveCode 9.6.3's engine and with OXT-Beyond's, the tests run in an
-- Android standalone too (tools/ci/android_tests.py)
private function noPointerToHide pWhat
   if st("platform") is not "mobile" then
      return false
   end if
   TestSkip pWhat, "on a phone or a tablet the game hides no pointer"
   return true
end noPointerToHide

----------------------------------------------------------------------
-- Opening

on TestTheGameOpensOnItsTitle
   TestAssert "the mode is the title", st("mode") is "title"
   TestAssert "the title screen is shown", shown("Title")
   TestAssert "the HUD is not", not shown("HUD")
   TestAssert "nor the other screens", not shown("Howto") and not shown("Paused") and not shown("Over") and \
         not shown("Settings") and not shown("Levels") and not shown("Clear") and not shown("Lobby") and not shown("Result")
   TestAssert "nor the arena", not the visible of graphic "Arena" of card kCard of stack kStack
   game "ebGoTitle"
   TestAssert "nothing saved yet: the title counts the levels", fieldText("Records") is "24 LEVELS"
   TestAssert "the first level is open and no other", st("unlocked") is 1 and st("best") is 0
end TestTheGameOpensOnItsTitle

-- What the builder put in the stack: the levels as their file has them,
-- every sound, the font, and what a page and an Android package ask for
on TestEverythingTheGameNeedsIsInTheStack
   local tLevels, tSounds, tFolder, tFiles, tFile, tMissing, tSettings, tHandlers
   put url ("binfile:" & TestGetEngineRepositoryPath() & "/tools/web-player/ember-bricks/levels.txt") into tLevels
   TestAssert "the levels are read", tLevels is not empty
   -- (a checkout on Windows gives the file CRLF line ends: the builder
   -- reads it as text, which takes them for line ends, and so does this)
   put textDecode(tLevels, "UTF-8") into tLevels
   replace numToChar(13) with empty in tLevels
   TestAssert "the stack has the levels as their file has them", tLevels is the cLevels of stack kStack
   put the customProperties["cSounds"] of stack kStack into tSounds
   repeat for each key tFile in tSounds
      if char 1 to 4 of tSounds[tFile] is not "RIFF" then
         put tFile & space after tMissing
      end if
   end repeat
   TestAssert "the stack has 27 sounds, each a WAV" && tMissing, tMissing is empty and the number of elements of tSounds is 27
   -- and they are the sounds of the game's folder. (The tests that run in
   -- the web engine have the files a test names, and no folder:
   -- tools/ci/web_tests.py. There the names have nothing to be compared
   -- with, and the line above is what is tested)
   put TestGetEngineRepositoryPath() & "/tools/web-player/ember-bricks/sounds" into tFolder
   if there is a folder tFolder or not TestIsInStandalone() then
      put files(tFolder) into tFiles
      filter tFiles with "*.wav"
      put empty into tMissing
      set the itemDelimiter to "."
      repeat for each line tFile in tFiles
         if tSounds[item 1 of tFile] is empty then
            put item 1 of tFile & space after tMissing
         end if
      end repeat
      set the itemDelimiter to comma
      TestAssert "every sound of the game's folder is in the stack, and no other" && tMissing, \
            tMissing is empty and the number of lines of tFiles is 27
   else
      TestSkip "every sound of the game's folder is in the stack", "this run's tests have no folder of the sounds"
   end if
   TestAssert "the font's two faces", the length of the cFontRegular of stack kStack > 10000 and \
         the length of the cFontBold of stack kStack > 10000
   put the cJavascriptHandlers of stack kStack into tHandlers
   TestAssert "a page may call what the game's page script calls", "ebPageHidden" is among the lines of tHandlers and \
         "ebPasted" is among the lines of tHandlers and "ebState" is among the lines of tHandlers
   TestAssert "the size the stack was built with", the cWindow of stack kStack is "900,640"
   put the customProperties["cRevStandaloneSettings"] of stack kStack into tSettings
   TestAssert "an Android package: OXT-Beyond's engine, edge to edge", tSettings["android,engine"] is "beyond" and \
         tSettings["android,edge to edge"] is true
   TestAssert "the stack can be made any size", the resizable of stack kStack and the minWidth of stack kStack <= 320 and \
         the minHeight of stack kStack <= 320
end TestEverythingTheGameNeedsIsInTheStack

on TestEveryLevelCanBePlayed
   local i, tBad
   TestAssert "twenty-four levels", st("levels") is 24
   repeat with i = 1 to 24
      newRun i
      if st("level") is not i or st("bricks") < 10 or st("phase") is not "serve" then
         put i & space after tBad
      end if
   end repeat
   TestAssert "each has a wall to break, and a ball waiting" && tBad, tBad is empty
end TestEveryLevelCanBePlayed

----------------------------------------------------------------------
-- The screens

on TestHowToPlayComesBeforeTheFirstRunOnly
   press "Play"
   TestAssert "the first Play shows how to play", st("mode") is "howto" and shown("Howto")
   press "Howto Go"
   TestAssert "which goes on to the run", st("mode") is "play" and st("level") is 1 and shown("HUD")
   TestAssert "and is remembered", "howto=true" is among the lines of saved()
   game "ebGoTitle"
   press "Play"
   TestAssert "the next Play plays", st("mode") is "play"
end TestHowToPlayComesBeforeTheFirstRunOnly

on TestHowToPlayFromTheTitleGoesBack
   press "Howto Open"
   TestAssert "how to play", st("mode") is "howto"
   press "Howto Go"
   TestAssert "back to the title", st("mode") is "title" and shown("Title")
end TestHowToPlayFromTheTitleGoesBack

on TestTheLevelsScreenOpensOnlyWhatWasReached
   press "Levels Open"
   TestAssert "the levels", st("mode") is "levels" and shown("Levels")
   press "Level 3"
   TestAssert "a level not reached does not open", st("mode") is "levels"
   TestAssert "and says what to do", fieldText("Levels Note") is "Clear level 1 to go on."
   game "ebTestSet", "unlocked", 3
   press "Level 3"
   TestAssert "one that was reached does", st("mode") is "play" and st("level") is 3
   game "ebGoTitle"
   press "Levels Open"
   press "Levels Back"
   TestAssert "Back goes to the title", st("mode") is "title"
end TestTheLevelsScreenOpensOnlyWhatWasReached

on TestTheSettings
   game "ebTestBegin", 7, sSave
   press "Settings Open"
   TestAssert "the settings", st("mode") is "settings" and shown("Settings")
   TestAssert "the tests begin with no sound", st("sound") is false
   press "Sound"
   TestAssert "Sound turns it on", st("sound") is true and the label of button "Sound" of card kCard of stack kStack is "SOUND: ON"
   TestAssert "and it is saved", "sound=true" is among the lines of saved()
   press "Effects"
   TestAssert "Effects goes to lite", st("effects") is "lite" and "effects=lite" is among the lines of saved()
   press "Effects"
   TestAssert "and back", st("effects") is "full"
   press "Buzz"
   TestAssert "Buzz turns on", st("buzz") is true
   press "Settings Back"
   TestAssert "Done goes back to the title", st("mode") is "title"
   newRun
   press "Pause"
   press "Pause Settings"
   TestAssert "the settings from a pause", st("mode") is "settings"
   press "Settings Back"
   TestAssert "go back to the pause", st("mode") is "pause" and shown("Paused")
end TestTheSettings

on TestTheKeysPlayAndPause
   put "howto=true" & return into url ("file:" & sSave)
   game "ebTestBegin", 7, sSave
   dispatch "rawKeyDown" to stack kStack with 32
   TestAssert "Space on the title plays", st("mode") is "play" and st("phase") is "serve"
   dispatch "rawKeyDown" to stack kStack with 32
   TestAssert "Space sends the ball off", st("phase") is "live" and ball(5) is false
   dispatch "rawKeyDown" to stack kStack with 112
   TestAssert "P pauses", st("mode") is "pause"
   dispatch "rawKeyDown" to stack kStack with 65307
   TestAssert "Escape goes on", st("mode") is "play"
   dispatch "rawKeyDown" to stack kStack with 65307
   dispatch "rawKeyDown" to stack kStack with 32
   TestAssert "and Space does from a pause", st("mode") is "play"
end TestTheKeysPlayAndPause

on TestAPauseStopsTheClock
   local tNow, tBall
   newWall
   game "ebTestBall", 160, 300, 0.3, -1
   step 0.2
   press "Pause"
   put st("now") into tNow
   put st("ball") into tBall
   step 2
   TestAssert "the game's clock waits", st("now") is tNow
   TestAssert "and the ball", st("ball") is tBall
   TestAssert "the pause has its four buttons", the visible of button "Restart" of card kCard of stack kStack and \
         the visible of button "Pause Settings" of card kCard of stack kStack and fieldText("Paused Title") is "PAUSED"
   press "Resume"
   step 0.2
   TestAssert "Resume goes on", st("mode") is "play" and st("now") > tNow and st("ball") is not tBall
   press "Pause"
   press "Restart"
   TestAssert "Restart begins the run again", st("mode") is "play" and st("score") is 0 and st("phase") is "serve"
   press "Pause"
   press "Pause Home"
   TestAssert "Home leaves it", st("mode") is "title" and not shown("HUD")
end TestAPauseStopsTheClock

on TestThePageHiddenPausesALevel
   newRun
   game "ebPageHidden"
   TestAssert "another tab, another app: the level waits", st("mode") is "pause"
   game "ebGoTitle"
   game "ebPageHidden"
   TestAssert "a screen has nothing to pause", st("mode") is "title"
end TestThePageHiddenPausesALevel

----------------------------------------------------------------------
-- The ball, the paddle and the walls

on TestTheBallWaitsOnThePaddleUntilSentOff
   newRun
   TestAssert "a run begins with three lives and no score", st("lives") is 3 and st("score") is 0
   TestAssert "and a ball on the paddle", st("phase") is "serve" and st("balls") is 1 and ball(5) is true
   step 1
   TestAssert "which waits", st("phase") is "serve" and ball(5) is true
   game "ebTestPaddle", 100
   step 0.1
   TestAssert "and goes where the paddle goes", abs(ball(1) - 100) <= 6 and ball(2) is 430
   game "ebLaunch"
   TestAssert "sent off, it goes up", st("phase") is "live" and ball(5) is false and ball(4) < 0
   step 0.2
   TestAssert "and flies", ball(2) < 400
end TestTheBallWaitsOnThePaddleUntilSentOff

on TestTheBallBouncesOffTheWallsAndTheTop
   newWall
   game "ebTestBall", 20, 380, -1, -0.4
   step 0.15
   TestAssert "off the left wall", ball(3) > 0 and ball(1) >= 5
   game "ebTestBall", 300, 380, 1, -0.4
   step 0.15
   TestAssert "off the right wall", ball(3) < 0 and ball(1) <= 315
   game "ebTestBall", 160, 25, 0.3, -1
   step 0.15
   TestAssert "off the top", ball(4) > 0 and ball(2) >= 5
end TestTheBallBouncesOffTheWallsAndTheTop

on TestThePaddleSendsTheBallByWhereItLands
   newWall
   game "ebTestPaddle", 160
   game "ebTestBall", 160, 405, 0, 1
   step 0.2
   TestAssert "from its middle, straight up", ball(4) < -0.99 and abs(ball(3)) < 0.01
   game "ebTestBall", 182, 405, 0, 1
   step 0.2
   TestAssert "from its right, to the right", ball(4) < 0 and ball(3) > 0.5
   game "ebTestBall", 138, 405, 0, 1
   step 0.2
   TestAssert "from its left, to the left", ball(4) < 0 and ball(3) < -0.5
   game "ebTestBall", 60, 405, 0, 1
   step 0.5
   TestAssert "and past it, the ball is lost", st("phase") is "lost"
end TestThePaddleSendsTheBallByWhereItLands

on TestTheBallSpeedsUpOnThePaddle
   local i
   newWall
   game "ebTestPaddle", 160
   TestAssert "the first level's speed", st("speed") is 235
   repeat with i = 1 to 6
      game "ebTestBall", 160, 415, 0, 1
      step 0.15
   end repeat
   TestAssert "six hits of the paddle: a little faster", st("speed") is 242.05
   repeat with i = 1 to 90
      game "ebTestBall", 160, 415, 0, 1
      step 0.15
   end repeat
   TestAssert "but never more than a quarter faster", st("speed") is 293.75
end TestTheBallSpeedsUpOnThePaddle

----------------------------------------------------------------------
-- The bricks

on TestABrickBreaksAndScores
   newWall "5,5,3"
   TestAssert "the brick is there", brick(5, 5) is "31" and st("bricks") is 2
   TestAssert "its graphic too", the visible of graphic "Brick 45" of card kCard of stack kStack
   hit 5, 5
   TestAssert "the ball breaks it", brick(5, 5) is empty and st("bricks") is 1
   TestAssert "its graphic is put away", not the visible of graphic "Brick 45" of card kCard of stack kStack
   TestAssert "for ten points", st("score") is 10
   TestAssert "and bounces", ball(4) > 0
end TestABrickBreaksAndScores

on TestAToughBrickTakesTwoHitsAndAnArmouredOneThree
   newWall "5,5,T;7,5,U"
   hit 5, 5
   TestAssert "a tough brick, hit once", brick(5, 5) is "T1" and st("score") is 5 and st("bricks") is 3
   hit 5, 5
   TestAssert "and twice", brick(5, 5) is empty and st("score") is 25 and st("bricks") is 2
   hit 7, 5
   hit 7, 5
   TestAssert "an armoured one, hit twice", brick(7, 5) is "U1" and st("score") is 35
   hit 7, 5
   TestAssert "and three times", brick(7, 5) is empty and st("score") is 65
end TestAToughBrickTakesTwoHitsAndAnArmouredOneThree

on TestSteelDoesNotBreak
   newWall "5,5,X"
   TestAssert "steel is not counted among the bricks to break", st("bricks") is 1
   hit 5, 5
   hit 5, 5
   hit 5, 5
   TestAssert "and the ball leaves it whole", brick(5, 5) is "X1" and st("score") is 0 and st("bricks") is 1
end TestSteelDoesNotBreak

on TestABombTakesItsNeighbours
   newWall "4,4,1;5,4,2;6,4,3;4,5,4;5,5,B;6,5,5;4,6,6;5,6,7;6,6,1;8,5,X;9,5,B"
   TestAssert "nine bricks, a bomb apart from them, and the one that keeps the level", st("bricks") is 11
   hit 5, 6
   TestAssert "the ball breaks the brick under the bomb", brick(5, 6) is empty and brick(5, 5) is "B1"
   hit 5, 5
   step 0.3
   TestAssert "the bomb goes, and the bricks round it with it", brick(5, 5) is empty and brick(4, 4) is empty and \
         brick(6, 4) is empty and brick(4, 6) is empty and brick(6, 6) is empty and brick(4, 5) is empty and brick(6, 5) is empty
   TestAssert "the ones further off stay", brick(8, 5) is "X1" and brick(9, 5) is "B1"
   -- the brick under it 10, the bomb 15, a third brick 10, then four of
   -- 10 at twice (the heat's second step) and two at three times
   TestAssert "each scored, the later ones for more as the heat rises", st("score") is 10 + 15 + 10 + 4 * 20 + 2 * 30
   TestAssert "the heat is up", st("mult") is 3 and st("heat") is 9
   hit 9, 5
   step 0.3
   TestAssert "a bomb's blast breaks steel too", brick(9, 5) is empty and brick(8, 5) is empty
   TestAssert "which was never among the bricks to break", st("bricks") is 1
end TestABombTakesItsNeighbours

on TestAnEmberBrickAlwaysDropsASpark
   newWall "5,5,E"
   TestAssert "no spark falls by chance in these tests", st("drops") is 0
   hit 5, 5
   TestAssert "the ember brick breaks, for 25", brick(5, 5) is empty and st("score") is 25
   TestAssert "and a spark falls from it", st("drops") is 1
end TestAnEmberBrickAlwaysDropsASpark

on TestTheHeatMultipliesAndCools
   newWall "5,5,1;6,5,1"
   game "ebTestSet", "heat", 7
   TestAssert "seven bricks hot: the second step of the bonus", st("mult") is 2
   hit 5, 5
   TestAssert "the eighth brick is worth three times", st("heat") is 8 and st("mult") is 3 and st("score") is 30
   -- with the ball waiting, nothing feeds the heat
   newWall "5,5,1"
   game "ebTestSet", "heat", 8
   step 2
   TestAssert "the heat holds for two seconds", st("heat") is 8 and st("mult") is 3
   step 2
   TestAssert "then cools", st("heat") < 8 and st("heat") > 0
   step 8
   TestAssert "to nothing", st("heat") is 0 and st("mult") is 1
end TestTheHeatMultipliesAndCools

on TestTheHeatStopsAtFiveTimes
   newWall "5,5,1"
   game "ebTestSet", "heat", 16
   TestAssert "five times at the most", st("mult") is 5
   hit 5, 5
   TestAssert "and the heat no higher", st("heat") is 16 and st("mult") is 5 and st("score") is 50
end TestTheHeatStopsAtFiveTimes

----------------------------------------------------------------------
-- The sparks

on TestASparkIsCaughtByThePaddleOnly
   newWall
   game "ebTestPaddle", 160
   game "ebTestDrop", "wide", 160, 400
   TestAssert "a spark falls", st("drops") is 1
   step 0.5
   TestAssert "the paddle catches it, for 50", st("drops") is 0 and st("size") is "wide" and st("score") is 50
   step 1
   TestAssert "and grows", st("padw") is 86
   game "ebTestDrop", "small", 20, 400
   step 1.5
   TestAssert "one that falls beside the paddle is gone, and does nothing", st("drops") is 0 and st("size") is "wide" and st("score") is 50
   step 14
   TestAssert "the wide paddle lasts fourteen seconds", st("size") is "normal" and st("padw") is 56
end TestASparkIsCaughtByThePaddleOnly

on TestTheSmallPaddleAndTheFastBall
   newWall
   game "ebCatch", "small"
   step 1
   TestAssert "a dark spark shrinks the paddle, for no points", st("size") is "small" and st("padw") is 38 and st("score") is 0
   step 10
   TestAssert "for ten seconds", st("size") is "normal"
   game "ebCatch", "fast"
   TestAssert "another speeds the ball", st("pace") is 1.3
   step 8.1
   TestAssert "for eight", st("pace") is 1
   game "ebCatch", "chill"
   TestAssert "a bright one slows it", st("pace") is 0.72 and st("score") is 50
end TestTheSmallPaddleAndTheFastBall

on TestSplitMakesThreeBallsOfOne
   newWall
   game "ebTestBall", 160, 300, 0, -1
   game "ebCatch", "split"
   TestAssert "three balls", st("balls") is 3
   game "ebCatch", "split"
   TestAssert "and of three, as many as there are (eight)", st("balls") is 8
end TestSplitMakesThreeBallsOfOne

on TestOnlyTheLastBallLostCostsALife
   newWall
   game "ebTestPaddle", 290
   game "ebTestBall", 160, 200, 0, -1
   game "ebTestBall", 20, 470, 0, 1, true
   TestAssert "two balls", st("balls") is 2
   step 0.2
   TestAssert "one lost: the other plays on", st("balls") is 1 and st("phase") is "live" and st("lives") is 3
end TestOnlyTheLastBallLostCostsALife

on TestTheFireballGoesThroughBricks
   newWall "5,5,T;5,4,U;5,3,1;7,5,X"
   game "ebCatch", "blaze"
   TestAssert "the fireball", st("blaze") is true
   game "ebTestBall", 144, 190, 0, -1
   step 0.5
   TestAssert "breaks a tough brick and an armoured one at a touch, and goes on", brick(5, 5) is empty and \
         brick(5, 4) is empty and brick(5, 3) is empty
   game "ebTestBall", 208, 190, 0, -1
   step 0.3
   TestAssert "steel stops it all the same", brick(7, 5) is "X1" and ball(4) > 0
   step 7
   TestAssert "it burns for seven seconds", st("blaze") is false
end TestTheFireballGoesThroughBricks

on TestThePaddleThatGrips
   newWall
   game "ebTestPaddle", 160
   game "ebCatch", "grip"
   TestAssert "the grip", st("grip") is true
   game "ebTestBall", 170, 415, 0, 1
   step 0.2
   TestAssert "the ball stays on the paddle, where it landed", ball(5) is true and abs(ball(1) - 170) < 1
   game "ebTestPaddle", 100
   step 0.1
   TestAssert "and goes with it", abs(ball(1) - 110) < 1
   game "ebLaunch"
   TestAssert "until it is sent off", ball(5) is false and ball(4) < 0 and ball(3) > 0
   game "ebTestBall", 100, 415, 0, 1
   step 0.2
   TestAssert "held again", ball(5) is true
   step 3
   TestAssert "it leaves by itself after a while", ball(5) is false
end TestThePaddleThatGrips

on TestBoltsBreakBricks
   newWall "5,5,1;5,4,T"
   game "ebTestPaddle", 119
   -- (a ball that goes straight up and down over the paddle's middle,
   -- where there is no brick: bolts fly only while a ball is in play)
   game "ebTestBall", 119, 300, 0, -1
   game "ebCatch", "bolts"
   TestAssert "the bolts", st("bolting") is true
   step 0.3
   TestAssert "fly from the paddle's ends", st("bolts") >= 2
   step 0.7
   -- (the paddle's right end, 6 in from it, is under column 5)
   TestAssert "and break the brick over one", brick(5, 5) is empty
   step 1
   TestAssert "a tough brick takes two", brick(5, 4) is empty
   step 9
   TestAssert "for nine seconds", st("bolting") is false and st("bolts") is 0
end TestBoltsBreakBricks

on TestTheNetThrowsOneBallBack
   newWall
   game "ebCatch", "net"
   TestAssert "the net", st("net") is true and the visible of graphic "Net" of card kCard of stack kStack
   game "ebTestPaddle", 290
   game "ebTestBall", 20, 440, 0, 1
   step 0.2
   TestAssert "a ball past the paddle comes back", st("phase") is "live" and st("balls") is 1 and ball(4) < 0
   TestAssert "once", st("net") is false and not the visible of graphic "Net" of card kCard of stack kStack
   game "ebTestBall", 20, 440, 0, 1
   step 0.3
   TestAssert "the next is lost", st("phase") is "lost"
end TestTheNetThrowsOneBallBack

on TestAChipForEachSparkAtWork
   local tOne, tTwo
   put the long id of field "Chip 1 Text" of card kCard of stack kStack into tOne
   put the long id of field "Chip 2 Text" of card kCard of stack kStack into tTwo
   newWall
   step 0.1
   TestAssert "no chip with no spark at work", not the visible of tOne
   game "ebCatch", "wide"
   step 0.1
   TestAssert "a chip names the spark at work", the visible of tOne and the text of tOne is "WIDE" and not the visible of tTwo
   game "ebCatch", "bolts"
   step 0.1
   TestAssert "one for each", the visible of tTwo and the text of tTwo is "BOLTS"
   -- (the HUD forgets what it showed when a level begins: a chip left
   -- on the screen then stayed, for a spark that was gone)
   game "ebStartLevel", 2
   step 0.1
   TestAssert "a new level takes the sparks, and their chips with them", st("size") is "normal" and \
         not the visible of tOne and not the visible of tTwo
   game "ebCatch", "grip"
   step 0.1
   TestAssert "a chip again", the visible of tOne and the text of tOne is "GRIP"
   newRun
   step 0.1
   TestAssert "a new run takes it too", not the visible of tOne
end TestAChipForEachSparkAtWork

on TestALifeSpark
   newWall
   game "ebCatch", "life"
   TestAssert "a life more", st("lives") is 4
   game "ebTestSet", "lives", 5
   game "ebCatch", "life"
   TestAssert "five at the most: then it is points", st("lives") is 5 and st("score") is 50 + 550
end TestALifeSpark

----------------------------------------------------------------------
-- Lives, levels and what is kept

on TestALostBallCostsALife
   newWall
   game "ebCatch", "wide"
   game "ebTestSet", "heat", 9
   loseBall
   TestAssert "the ball is lost", st("phase") is "lost" and st("balls") is 0
   TestAssert "a life with it", st("lives") is 2
   TestAssert "and the heat, and what the sparks gave", st("heat") is 0 and st("mult") is 1 and st("size") is "normal"
   step 1
   TestAssert "another ball waits on the paddle", st("phase") is "serve" and ball(5) is true
end TestALostBallCostsALife

on TestTheLastLifeEndsTheRun
   newWall "5,5,1"
   hit 5, 5
   game "ebTestSet", "lives", 1
   loseBall
   TestAssert "the last life", st("lives") is 0 and st("phase") is "dead"
   step 1.2
   TestAssert "the run is over", st("mode") is "over" and shown("Over")
   step 2
   TestAssert "its score counted up", fieldText("Final") is "10"
   TestAssert "a first score is the best", fieldText("Best Note") is "NEW BEST!" and st("best") is 10
   TestAssert "and kept", "best=10" is among the lines of saved()
   TestAssert "with what the run did", line 2 of fieldText("Stats") is "1 bricks broken, heat up to x1"
   press "Again"
   TestAssert "Play again begins a run", st("mode") is "play" and st("score") is 0 and st("lives") is 3
   game "ebTestSet", "lives", 1
   loseBall
   step 1.2
   press "Over Home"
   TestAssert "Home goes to the title, which shows the best", st("mode") is "title" and fieldText("Records") is "BEST 10     LEVEL 1 OF 24"
end TestTheLastLifeEndsTheRun

on TestClearingALevel
   newWall "5,5,1", false
   hit 5, 5
   TestAssert "the last brick broken", st("bricks") is 0
   step 0.1
   TestAssert "the level is cleared", st("phase") is "cleared" and st("balls") is 0
   step 1.4
   TestAssert "its panel", st("mode") is "clear" and shown("Clear")
   TestAssert "names the level", fieldText("Clear Name") is "LEVEL 1: FIRST SPARKS"
   -- the wall 300 (250 and 50 a level), each life 100, and 600 less 5 a
   -- second of the level
   TestAssert "and what it was worth", fieldText("Clear Values") is "+300" & return & "+300" & return & "+600"
   TestAssert "which is added", st("score") is 10 + 1200
   step 3
   TestAssert "the total counts up", fieldText("Clear Total") is "1,210"
   TestAssert "the next level is open, and kept", st("unlocked") is 2 and "unlocked=2" is among the lines of saved()
   press "Next"
   TestAssert "Next goes on", st("mode") is "play" and st("level") is 2 and st("phase") is "serve" and st("score") is 1210
   TestAssert "with the next level's wall", st("bricks") > 20
end TestClearingALevel

on TestALifeForEveryTwentyThousand
   newWall "5,5,1"
   game "ebTestSet", "score", 19995
   hit 5, 5
   TestAssert "twenty thousand points: a life", st("score") is 20005 and st("lives") is 4
end TestALifeForEveryTwentyThousand

on TestTheLevelsComeRoundAgainFaster
   newRun 24
   TestAssert "the last level's ball is the fastest", st("speed") is 330
   newRun 25
   TestAssert "after it the first comes again, a little faster", st("level") is 25 and st("speed") is 253.8
   TestAssert "with its wall", st("bricks") > 20
end TestTheLevelsComeRoundAgainFaster

on TestWhatIsKeptBetweenVisits
   put "best=5000" & return & "unlocked=7" & return & "plays=3" & return & "sound=false" & return & \
         "effects=lite" & return & "howto=true" & return into url ("file:" & sSave)
   game "ebTestBegin", 7, sSave
   game "ebGoTitle"
   TestAssert "the best, the levels reached and the settings are read", st("best") is 5000 and st("unlocked") is 7 and \
         st("effects") is "lite" and st("howto") is true
   TestAssert "and shown on the title", fieldText("Records") is "BEST 5,000     LEVEL 7 OF 24"
   press "Play"
   TestAssert "how to play was seen: Play plays", st("mode") is "play"
   TestAssert "a run is counted", "plays=4" is among the lines of saved()
   game "ebTestSet", "lives", 1
   game "ebTestSet", "score", 300
   loseBall
   step 1.2
   TestAssert "a lower score", st("mode") is "over" and st("best") is 5000
   TestAssert "names the best", fieldText("Best Note") is "BEST 5,000"
   TestAssert "which is still kept", "best=5000" is among the lines of saved()
end TestWhatIsKeptBetweenVisits

on TestASavedFileThatMakesNoSense
   put "best=lots" & return & "unlocked=99" & return & "plays=-4" & return & "effects=sideways" & return & "nonsense" & return into url ("file:" & sSave)
   game "ebTestBegin", 7, sSave
   TestAssert "is read as nothing saved", st("best") is 0 and st("plays") is 0 and st("effects") is "full"
   TestAssert "and never opens a level there is not", st("unlocked") is 24
end TestASavedFileThatMakesNoSense

on TestNumbersWithCommas
   TestAssert "none under a thousand", gameSays("ebCommas", 0) is "0" and gameSays("ebCommas", 999) is "999"
   TestAssert "one from a thousand", gameSays("ebCommas", 1000) is "1,000" and gameSays("ebCommas", 20005) is "20,005"
   TestAssert "two from a million", gameSays("ebCommas", 1234567) is "1,234,567"
end TestNumbersWithCommas

----------------------------------------------------------------------
-- Any window: a phone, a phone on its side, a desktop

-- Everything in its place at pWidth x pHeight: the arena on the window,
-- the HUD beside it (pWide) or over it (with pWide empty, where the game
-- put it), every screen's buttons on the window and apart, every word
-- whole
private command checkLayout pWidth, pHeight, pWide
   local tCard, tArena, tName, tBad, tScreen, tGroup, tRects, tRect, tField, tLines, i, j, tAt
   put "at" && pWidth & "x" & pHeight & ":" into tAt
   windowSize pWidth, pHeight
   if the width of stack kStack is not pWidth or the height of stack kStack is not pHeight then
      TestSkip tAt && "the layout", "the window could not be made that size here"
      exit checkLayout
   end if
   newRun
   put 0, 0, pWidth, pHeight into tCard
   put st("arena") into tArena
   TestAssert tAt && "the arena is on the window", isInside(tArena, tCard)
   TestAssert tAt && "two units wide for three high (320 by 480)", \
         abs((item 3 of tArena - item 1 of tArena) * 480 - (item 4 of tArena - item 2 of tArena) * 320) <= 480
   if pWide is true then
      TestAssert tAt && "the HUD is beside the arena", st("wide") is true
   else if pWide is false then
      TestAssert tAt && "the HUD is over the arena", st("wide") is false
   end if
   if st("wide") is true then
      TestAssert tAt && "beside the arena, the score is left of it", item 3 of rectOf("Score") <= item 1 of tArena
   else
      TestAssert tAt && "over the arena, the score is above it", item 4 of rectOf("Score") <= item 2 of tArena
   end if
   repeat for each item tName in "Score,Stage,Heat Text,Pause"
      put rectOf(tName) into tRect
      if not isInside(tRect, tCard) or overlap(tRect, tArena) then
         put tName & space after tBad
      end if
   end repeat
   TestAssert tAt && "the HUD is on the window, off the arena" && tBad, tBad is empty
   TestAssert tAt && "the pause button can be tapped", the height of button "Pause" of card kCard of stack kStack >= 28
   TestAssert tAt && "the bricks are in the arena", isInside(rectOf("Brick 1"), tArena) and isInside(rectOf("Brick 140"), tArena)
   TestAssert tAt && "the paddle too", isInside(rectOf("Paddle"), tArena)
   -- every line of the screens' words whole
   put empty into tBad
   repeat for each item tName in "Tagline,Howto Text 1,Howto Text 2,Howto Text 3,Howto Text 4,Credits,Lobby Text"
      put the long id of field tName of card kCard of stack kStack into tField
      put the number of lines of the formattedText of tField into tLines
      if the height of tField < tLines * the effective textHeight of tField then
         put tName && "is shorter than its" && tLines && "lines;" after tBad
      end if
      if not isInside(the rect of tField, tCard) then
         put tName && "off the window;" after tBad
      end if
   end repeat
   TestAssert tAt && "the words show whole" && tBad, tBad is empty
   game "ebTestSet", "rtc", "yes"
   game "ebGoTitle"
   press "Duel Open"
   repeat for each item tScreen in "Title,Howto,Settings,Levels,Paused,Clear,Over,Lobby,Result"
      put empty into tRects
      put empty into tBad
      put the long id of group tScreen of card kCard of stack kStack into tGroup
      -- (the title has no panel: it is the window)
      if tScreen is not "Title" then
         if not isInside(the rect of graphic (tScreen && "Glass") of tGroup, tCard) then
            put "its panel off the window;" after tBad
         end if
      end if
      repeat with i = 1 to the number of buttons of tGroup
         put the short name of button i of tGroup into tName
         if there is a graphic (tName && "Shape") of card kCard of stack kStack and the visible of button i of tGroup then
            put the rect of button i of tGroup into tRect
            if not isInside(tRect, tCard) then
               put tName && "off the window;" after tBad
            end if
            if item 4 of tRect - item 2 of tRect < 28 or item 3 of tRect - item 1 of tRect < 28 then
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
      TestAssert tAt && tScreen && "has its buttons on the window, apart" && tBad, tBad is empty and tRects is not empty
   end repeat
   game "ebGoTitle"
end checkLayout

on TestTheScreensFitAPhone
   checkLayout 390, 760, false
   checkLayout 320, 480, false
   checkLayout 430, 932, false
end TestTheScreensFitAPhone

-- (Where the score is, beside the arena or over it, is asked in
-- checkLayout, of a window that was made the size. It was asked here once
-- more, after both, of whatever window there was: a phone's own app has
-- the screen it has, checkLayout said twice that it could not look, and
-- the line failed on an upright screen whose score was over its arena, as
-- it should be.)
on TestTheScreensFitAPhoneOnItsSide
   checkLayout 844, 390, true
   checkLayout 568, 320, true
end TestTheScreensFitAPhoneOnItsSide

-- The window as it is: on a desktop the one the stack was built with, and
-- in a phone's app the phone's screen, which no test can make another
-- size. There this is the test that looks at the game on a phone
on TestTheScreensFitTheScreenTheyAreOn
   checkLayout the width of stack kStack, the height of stack kStack, empty
end TestTheScreensFitTheScreenTheyAreOn

on TestTheScreensFitAWindow
   checkLayout 900, 640, true
   checkLayout 1920, 1080, true
   checkLayout 768, 1024, false
end TestTheScreensFitAWindow

on TestTheGameKeepsOutOfTheNotchAndTheHomeBar
   local tArena
   windowSize 390, 844
   if the width of stack kStack is not 390 then
      TestSkip "the insets", "the window could not be made that size here"
      exit TestTheGameKeepsOutOfTheNotchAndTheHomeBar
   end if
   newRun
   game "ebTestSet", "insets", "47,34,0,0"
   put st("arena") into tArena
   TestAssert "a notch at the top, a home bar at the bottom", st("insets") is "47,34,0,0"
   TestAssert "the HUD is under the notch", item 2 of rectOf("Score") >= 47 and item 2 of rectOf("Pause") >= 47
   TestAssert "the arena is over the home bar", item 4 of tArena <= 844 - 34
   windowSize 844, 390
   game "ebResume"
   game "ebTestSet", "insets", "0,21,47,47"
   put st("arena") into tArena
   TestAssert "on its side: the notch at the left or the right", item 1 of rectOf("Score") >= 47 and \
         item 3 of rectOf("Pause") <= 844 - 47 and item 4 of tArena <= 390 - 21
end TestTheGameKeepsOutOfTheNotchAndTheHomeBar

on TestTurningThePhonePausesALevelAndKeepsItsBall
   local tBall, tArena, tLoc
   windowSize 390, 760
   if the width of stack kStack is not 390 then
      TestSkip "turning the phone", "the window could not be made that size here"
      exit TestTurningThePhonePausesALevelAndKeepsItsBall
   end if
   newWall "5,5,3"
   game "ebTestBall", 100, 300, 0.2, -1
   step 0.1
   put st("ball") into tBall
   windowSize 760, 390
   TestAssert "the level waits", st("mode") is "pause"
   TestAssert "the ball is where it was in the arena", st("ball") is tBall
   put st("arena") into tArena
   put the loc of graphic "Ball 1" of card kCard of stack kStack into tLoc
   TestAssert "and drawn there in the arena's new place", \
         abs(item 1 of tLoc - (item 1 of tArena + item 1 of tBall * st("scale"))) <= 1 and \
         abs(item 2 of tLoc - (item 2 of tArena + item 2 of tBall * st("scale"))) <= 1
   TestAssert "the bricks too", isInside(rectOf("Brick 45"), tArena) and the visible of graphic "Brick 45" of card kCard of stack kStack
   press "Resume"
   step 0.1
   TestAssert "Resume goes on", st("mode") is "play" and st("ball") is not tBall
end TestTurningThePhonePausesALevelAndKeepsItsBall

----------------------------------------------------------------------
-- The mouse's pointer

-- Over the arena, while a level is played, the pointer is in the ball's
-- way and points at nothing: it is hidden there, and nowhere else
on TestThePointerIsHiddenOverTheArenaWhileALevelIsPlayed
   local tPause
   if noPointerToHide("the pointer over the arena") then
      exit TestThePointerIsHiddenOverTheArenaWhileALevelIsPlayed
   end if
   game "ebTestSet", "pointer", "mouse"
   mouseAt arenaMiddle()
   TestAssert "on the title the pointer shows, wherever it is", st("mode") is "title" and pointerShown()
   newRun
   step 1/60
   TestAssert "a level played with the mouse over the arena: the pointer is hidden", st("mode") is "play" and pointerHidden()
   put rectOf("Pause") into tPause
   mouseAt (item 1 of tPause + 5) & comma & (item 2 of tPause + 5)
   TestAssert "over the pause button, beside the arena, it shows", pointerShown()
   mouseAt arenaMiddle()
   TestAssert "back over the arena it is hidden again", pointerHidden()
   mouseAt empty
   TestAssert "out of the window it shows", pointerShown()
   mouseAt arenaMiddle()
   -- (a pause stops the frames: the pointer is back with none after it)
   press "Pause"
   TestAssert "a pause shows it at once, where it is", st("mode") is "pause" and pointerShown()
   press "Resume"
   step 1/60
   TestAssert "and the level going on hides it", st("mode") is "play" and pointerHidden()
   game "ebGoTitle"
   TestAssert "the title shows it at once", st("mode") is "title" and pointerShown()
end TestThePointerIsHiddenOverTheArenaWhileALevelIsPlayed

on TestThePointerShowsWhenALevelEnds
   if noPointerToHide("the pointer when a level ends") then
      exit TestThePointerShowsWhenALevelEnds
   end if
   game "ebTestSet", "pointer", "mouse"
   newWall "5,5,1", false
   mouseAt arenaMiddle()
   TestAssert "hidden while the level is played", pointerHidden()
   hit 5, 5
   step 1.5
   TestAssert "a level cleared: its panel has buttons, and the pointer", st("mode") is "clear" and pointerShown()
   press "Next"
   step 1/60
   TestAssert "the next level hides it again", st("mode") is "play" and pointerHidden()
   game "ebTestSet", "lives", 1
   loseBall
   step 1.2
   TestAssert "the run over: the pointer shows", st("mode") is "over" and pointerShown()
end TestThePointerShowsWhenALevelEnds

on TestAFingerHasNoPointerToHide
   game "ebTestSet", "pointer", "touch"
   newRun
   mouseAt arenaMiddle()
   TestAssert "a level played by touch: the engine's cursor is left as it is", st("mode") is "play" and pointerShown()
end TestAFingerHasNoPointerToHide

-- In a phone's or a tablet's app the game hides no pointer, whatever it
-- is told of a mouse: the engine has no pointer of its own to hide there
-- (a mouse's is the system's), and the other tests of the pointer are
-- skipped there. This one runs everywhere: on a desktop and in a page the
-- game is told that it is in such an app, and told back after, so that
-- what the game does there is tested on every run of the tests, not only
-- in the Android job
on TestAPhoneOrATabletHidesNoPointer
   local tPlatform
   put st("platform") into tPlatform
   if tPlatform is not "mobile" then
      game "ebTestSet", "platform", "mobile"
   end if
   TestAssert "the game is in a phone's or a tablet's app", st("platform") is "mobile"
   game "ebTestSet", "pointer", "mouse"
   newRun
   mouseAt arenaMiddle()
   TestAssert "a level played, a mouse over the arena: the engine's cursor is left as it is", st("mode") is "play" and pointerShown()
   press "Pause"
   TestAssert "and on a pause", st("mode") is "pause" and pointerShown()
   game "ebGoTitle"
   TestAssert "and on the title", st("mode") is "title" and pointerShown()
   game "ebTestSet", "platform", tPlatform
   TestAssert "the game is where it was again", st("platform") is tPlatform
end TestAPhoneOrATabletHidesNoPointer

-- The IDE's other tools (the pointer tool to move a control, say) need
-- their pointer over the arena too
on TestThePointerShowsWithAToolThatDoesNotPlay
   if noPointerToHide("the pointer with another tool") then
      exit TestThePointerShowsWithAToolThatDoesNotPlay
   end if
   game "ebTestSet", "pointer", "mouse"
   newRun
   mouseAt arenaMiddle()
   TestAssert "hidden with the tool that plays", pointerHidden()
   choose pointer tool
   step 1/60
   TestAssert "with the IDE's pointer tool it shows", pointerShown()
   choose browse tool
   step 1/60
   TestAssert "and with the browse tool again it is hidden", pointerHidden()
   game "ebGoTitle"
end TestThePointerShowsWithAToolThatDoesNotPlay

-- The engine has one cursor for all its windows: the game does not take
-- one that another script holds, and takes its own back
on TestACursorAnotherScriptHoldsIsLeftAlone
   if noPointerToHide("a cursor another script holds") then
      exit TestACursorAnotherScriptHoldsIsLeftAlone
   end if
   game "ebTestSet", "pointer", "mouse"
   newRun
   set the lockCursor to true
   mouseAt arenaMiddle()
   TestAssert "a cursor another script has locked is not the game's to hide", st("hidden") is false and the lockCursor is true
   mouseAt empty
   TestAssert "nor to let go", the lockCursor is true
   set the lockCursor to false
   mouseAt arenaMiddle()
   TestAssert "once it is free, the game hides the pointer", pointerHidden()
   -- (another script takes the cursor for a moment, and lets it go)
   set the lockCursor to false
   step 1/60
   TestAssert "let go by another script, it is hidden again by the next frame", pointerHidden()
   game "ebGoTitle"
   TestAssert "and given back by the game", pointerShown()
end TestACursorAnotherScriptHoldsIsLeftAlone

-- A hidden pointer is hidden in every window of the engine, so it does
-- not outlive the frames that hide it: a script that stopped or the
-- debugger leaves nobody without one
on TestAPointerIsNotLeftHiddenWhenTheFramesStop
   if noPointerToHide("the pointer when the frames stop") then
      exit TestAPointerIsNotLeftHiddenWhenTheFramesStop
   end if
   game "ebTestSet", "pointer", "mouse"
   newRun
   mouseAt arenaMiddle()
   TestAssert "hidden while the frames come", pointerHidden()
   -- (a test's game has no loop, and no watch but the one sent here,
   -- which then asks again by itself as a game's does)
   dispatch "ebPointerWatch" to stack kStack
   TestAssert "the watch leaves it hidden while they do", pointerHidden()
   wait 900 milliseconds with messages
   TestAssert "with no frame for most of a second, the pointer shows", st("mode") is "play" and pointerShown()
   step 1/60
   TestAssert "and the next frame hides it again", pointerHidden()
   game "ebGoTitle"
end TestAPointerIsNotLeftHiddenWhenTheFramesStop

on TestClosingTheGameGivesThePointerBack
   if noPointerToHide("the pointer when the game closes") then
      exit TestClosingTheGameGivesThePointerBack
   end if
   game "ebTestSet", "pointer", "mouse"
   newRun
   mouseAt arenaMiddle()
   TestAssert "hidden while the level is played", pointerHidden()
   close stack kStack
   TestAssert "the game closed: the engine's cursor is free", the lockCursor is false
end TestClosingTheGameGivesThePointerBack

----------------------------------------------------------------------
-- The duel: its lobby and its codes

on TestNoDuelWhereThereIsNoLink
   -- (this engine runs with no extension: DataChannelXT is not here)
   press "Duel Open"
   TestAssert "the lobby", st("mode") is "lobby" and shown("Lobby")
   TestAssert "says a duel cannot be played here", st("lobby") is "none" and st("rtc") is "no" and \
         "cannot make that link" is in fieldText("Lobby Text")
   TestAssert "and offers none", not the visible of button "Host" of card kCard of stack kStack and \
         not the visible of button "Join" of card kCard of stack kStack
   press "Lobby Back"
   TestAssert "Back goes to the title", st("mode") is "title"
end TestNoDuelWhereThereIsNoLink

on TestTheLobbysSteps
   local tInvite, tAnswer
   game "ebTestSet", "rtc", "yes"
   press "Duel Open"
   TestAssert "Host and Join", st("lobby") is "choose" and the visible of button "Host" of card kCard of stack kStack and \
         the visible of button "Join" of card kCard of stack kStack
   press "Host"
   TestAssert "with no link to be made, Host says so and stays", st("lobby") is "choose" and \
         fieldText("Lobby Note") begins with "Could not start a link here."
   press "Join"
   TestAssert "Join asks for the invite", st("lobby") is "join-invite" and fieldText("Lobby Step") is "STEP 1 OF 2: THE INVITE"
   TestAssert "with a place to paste it", the visible of field "Code" of card kCard of stack kStack and \
         not the lockText of field "Code" of card kCard of stack kStack and \
         the visible of button "Code Paste" of card kCard of stack kStack and not the visible of button "Code Copy" of card kCard of stack kStack
   game "ebPasted", empty
   TestAssert "nothing to paste", fieldText("Lobby Note") begins with "Nothing to paste."
   game "ebPasted", "hello there"
   TestAssert "something that is no code", fieldText("Lobby Note") begins with "That is not a code of this game."
   put gameSays("ebDuelEncode", "A", "v=0" & return & "s=-") into tAnswer
   game "ebPasted", tAnswer
   TestAssert "an answer where the invite goes", st("lobby") is "join-invite" and \
         fieldText("Lobby Note") is "That is an answer. Paste the invite your rival sent."
   put gameSays("ebDuelEncode", "O", "v=0" & return & "s=-") into tInvite
   game "ebPasted", char 1 to 30 of tInvite
   TestAssert "half an invite", fieldText("Lobby Note") begins with "That code is not whole."
   game "ebPasted", tInvite
   TestAssert "a whole one is taken (and, with no link to be made, goes no further)", st("lobby") is "join-invite" and \
         fieldText("Lobby Note") begins with "Could not start a link here."
   press "Lobby Back"
   TestAssert "Back from a step goes to the lobby's first", st("mode") is "lobby" and st("lobby") is "choose"
   press "Lobby Back"
   TestAssert "and from there to the title", st("mode") is "title"
end TestTheLobbysSteps

on TestACodeCarriesADescription
   local tSdp, tCode, tSpaced, i, tBad, tWrong, tGot, tRefused
   put "v=0" & numToChar(13) & numToChar(10) & "o=- 4611731400430051336 2 IN IP4 127.0.0.1" & numToChar(13) & numToChar(10) & \
         "a=candidate:1 1 UDP 2122317823 192.168.1.20 51234 typ host" & numToChar(13) & numToChar(10) & \
         "a=fingerprint:sha-256 4A:AD:B9:B1:3F:82:18:3B:54:02:12:DF:3E:5D:49:6B:19:E5:7C:AB:4A:AD:B9:B1:3F:82:18:3B:54:02:12:DF" & \
         numToChar(13) & numToChar(10) into tSdp
   put gameSays("ebDuelEncode", "O", tSdp) into tCode
   TestAssert "an invite begins EB1O", char 1 to 4 of tCode is "EB1O" and char 6 of tCode is ":"
   TestAssert "and is one word a message will not break", matchText(tCode, "^[A-Za-z0-9:_-]+$")
   TestAssert "it gives the description back, to the byte", gameSays("ebDuelDecode", tCode, "O") is tSdp
   repeat with i = 1 to the length of tCode step 17
      put char i to i + 16 of tCode & return & space after tSpaced
   end repeat
   TestAssert "broken into lines by a message, too", gameSays("ebDuelDecode", tSpaced, "O") is tSdp
   TestAssert "an answer begins EB1A", char 1 to 4 of gameSays("ebDuelEncode", "A", tSdp) is "EB1A"
   TestAssert "an invite is not an answer", char 1 of gameSays("ebDuelDecode", tCode, "A") is "!"
   TestAssert "nor is half of one an invite", char 1 of gameSays("ebDuelDecode", char 1 to 40 of tCode, "O") is "!"
   TestAssert "nor nonsense", char 1 of gameSays("ebDuelDecode", "EB1Oz:!!!!", "O") is "!" and \
         char 1 of gameSays("ebDuelDecode", "hello", "O") is "!" and char 1 of gameSays("ebDuelDecode", empty, "O") is "!"
   TestAssert "nor a code that is not a description", char 1 of gameSays("ebDuelDecode", gameSays("ebDuelEncode", "O", "hello"), "O") is "!"
   -- A code cut short, wherever a message or a finger cut it. The
   -- engine's decompress makes room for as many bytes as the last four of
   -- what it is given say, before it reads the rest, so the game must not
   -- hand it a piece of a code: the half above had it make room for
   -- 1,208,859,709 bytes, and Android stopped the game there
   put empty into tBad
   repeat with i = 7 to the length of tCode - 1
      if char 1 of gameSays("ebDuelDecode", char 1 to i of tCode, "O") is not "!" then
         put i & space after tBad
      end if
   end repeat
   TestAssert "cut anywhere, it is not a code" && tBad, tBad is empty
   -- and one character of it wrong (after the fourteen that hold nothing
   -- of the description): the code carries a sum of what was packed, and
   -- what it unpacks to is the description or nothing. (Nothing, but for
   -- a character whose change changes no byte of it)
   put empty into tBad
   put 0 into tRefused
   repeat with i = 21 to the length of tCode - 2 step 3
      put tCode into tWrong
      if char i of tWrong is "A" then
         put "B" into char i of tWrong
      else
         put "A" into char i of tWrong
      end if
      put gameSays("ebDuelDecode", tWrong, "O") into tGot
      if char 1 of tGot is "!" then
         add 1 to tRefused
      else if tGot is not tSdp then
         put i & space after tBad
      end if
   end repeat
   TestAssert "with a character wrong, it is never taken for another description" && tBad, tBad is empty and tRefused > 50
end TestACodeCarriesADescription

----------------------------------------------------------------------
-- The duel: its online lobby
--
-- The lobby is played with no relay behind it (ebTestNet): what the game
-- would send to the relays is read with ebNetSent, and the test says what
-- the other players do with ebNetHear, as a relay would bring it. (This
-- engine runs with no extension: NostrXT is not here, and a test says
-- that there is a lobby, with ebTestSet "nostr".)

-- A key of the lobby's for a player: sixty-four characters, pChar first
-- (never a number, whatever pChar is)
private function pkOf pChar
   local tKey
   put pChar into tKey
   repeat 63 times
      put "f" after tKey
   end repeat
   return tKey
end pkOf

-- This player in the lobby as pName, under the key that begins with 5
private command lobbyAs pName
   game "ebTestSet", "rtc", "yes"
   game "ebTestSet", "nostr", "yes"
   game "ebTestNet", pkOf("5"), pName
end lobbyAs

-- A player (the key that begins with pChar) says "I am here": what they
-- are doing, their name, and whether they ask who else is (1 or 0)
private command hears pChar, pState, pName, pHello
   game "ebNetHear", pkOf(pChar), "who", "EB|1|" & pState & "|50|" & pHello & "|" & pName
end hears

-- A word to me from that player
private command told pChar, pText
   game "ebNetHear", pkOf(pChar), "tell", "L1" && pText
end told

-- What the lobby sent since this was last asked, in sSent; and of it, the
-- last words to the player whose key begins with pChar (empty for none)
private function toldTo pChar
   local tLine, tFound
   put gameSays("ebNetSent") into sSent
   repeat for each line tLine in sSent
      if word 1 of tLine is "tell" and word 2 of tLine is pkOf(pChar) then
         put word 3 to -1 of tLine into tFound
      end if
   end repeat
   return tFound
end toldTo

private function isShown pControl
   return the visible of control pControl of card kCard of stack kStack
end isShown

-- A description as one player's game sends it to the other's
private function described pKind
   return gameSays("ebDuelEncode", pKind, "v=0" & return & "s=-")
end described

on TestTheLobbyOpensOnANameWhereThereIsOne
   game "ebTestSet", "rtc", "yes"
   game "ebTestSet", "nostr", "yes"
   press "Duel Open"
   TestAssert "the lobby's first step is a name", st("lobby") is "start" and isShown("Name") and \
         not the lockText of field "Name" of card kCard of stack kStack
   TestAssert "one is made up for a first visit", the number of words of fieldText("Name") is 2 and st("name") is fieldText("Name")
   TestAssert "with Go online over Play by code", isShown("Net Go") and isShown("Codes Open") and \
         the label of button "Net Go" of card kCard of stack kStack is "GO ONLINE" and not isShown("Host") and not isShown("Join")
   TestAssert "it says what going online shows, and to whom", "shows this name to the other players" is in fieldText("Lobby Note") and \
         "public Nostr relays" is in fieldText("Lobby Note") and "your internet address" is in fieldText("Lobby Note")
   TestAssert "and nothing is sent before the player says so", st("online") is false and gameSays("ebNetSent") is empty and st("pk") is empty
   press "Codes Open"
   TestAssert "Play by code is the swap of two codes, as it was", st("lobby") is "choose" and isShown("Host") and isShown("Join") and \
         not isShown("Name") and not isShown("Net Go")
   press "Lobby Back"
   TestAssert "Back from there is the name again", st("lobby") is "start" and isShown("Name")
   press "Lobby Back"
   TestAssert "and from there the title", st("mode") is "title"
end TestTheLobbyOpensOnANameWhereThereIsOne

on TestGoingOnlineKeepsTheNameAndSaysWhenItCannot
   game "ebTestSet", "rtc", "yes"
   game "ebTestSet", "nostr", "yes"
   -- (no relay is asked, were NostrXT here after all: nothing listens there)
   game "ebTestSet", "relays", "ws://127.0.0.1:9"
   press "Duel Open"
   set the text of field "Name" of card kCard of stack kStack to "  Ada <of> the   Kiln  "
   press "Net Go"
   TestAssert "the name is the one typed, made plain", st("name") is "Ada of the Kiln" and fieldText("Name") is "Ada of the Kiln"
   TestAssert "and is kept for the next visit", "name=Ada of the Kiln" is among the lines of saved()
   -- (this engine has no NostrXT: no key can be made)
   TestAssert "where no key can be made the lobby says so, and stays", st("lobby") is "start" and st("online") is false and \
         fieldText("Lobby Note") is "Could not go online here. Play by code."
   game "ebTestBegin", 7, sSave
   TestAssert "the next visit has the name", st("name") is "Ada of the Kiln"
   game "ebTestSet", "rtc", "yes"
   game "ebTestSet", "nostr", "yes"
   press "Duel Open"
   TestAssert "in its field", fieldText("Name") is "Ada of the Kiln"
   set the text of field "Name" of card kCard of stack kStack to "<>"
   press "Net Go"
   TestAssert "a name of nothing plain is one made up", the number of words of st("name") is 2 and st("name") is not "Ada of the Kiln"
end TestGoingOnlineKeepsTheNameAndSaysWhenItCannot

on TestANameIsPlainAndShort
   local tLong
   TestAssert "a name as typed", gameSays("ebNetName", "Ada") is "Ada"
   TestAssert "one space at a time, and none at its ends", gameSays("ebNetName", "  Ada    of   Kiln ") is "Ada of Kiln"
   TestAssert "nothing a page or a list could take for its own", gameSays("ebNetName", "<b>Bo</b>|x" & return & "y" & tab & "z,=" & quote) is "bBobxyz"
   put "Abcdefghijklmnopqrstuvwxyz0123456789" into tLong
   TestAssert "sixteen characters at most", gameSays("ebNetName", tLong) is "Abcdefghijklmnop"
   TestAssert "with no space left at its end", gameSays("ebNetName", "Abcdefghijklmno pqrs") is "Abcdefghijklmno"
   TestAssert "a letter with an accent stays", gameSays("ebNetName", "Zo" & numToCodepoint(235)) is "Zo" & numToCodepoint(235)
   TestAssert "a picture does not", gameSays("ebNetName", "Zo" & numToCodepoint(128512) & "e") is "Zoe"
   TestAssert "nothing plain is no name", gameSays("ebNetName", "<<>>") is empty and gameSays("ebNetName", empty) is empty
end TestANameIsPlainAndShort

on TestARoomsCode
   TestAssert "six letters and numbers", gameSays("ebNetCode", "K7M2QX") is "K7M2QX"
   TestAssert "typed small", gameSays("ebNetCode", "k7m2qx") is "K7M2QX"
   TestAssert "with a space or a dash in it", gameSays("ebNetCode", " K7M 2QX" & return) is "K7M2QX" and gameSays("ebNetCode", "K7M-2QX") is "K7M2QX"
   TestAssert "or the link that carries it", gameSays("ebNetCode", "https://example.org/play/?play=Ember%20Bricks&duel=K7M2QX") is "K7M2QX"
   TestAssert "with more after it", gameSays("ebNetCode", "https://example.org/?duel=k7m2qx&x=1#top") is "K7M2QX"
   TestAssert "five are not a code, nor seven", gameSays("ebNetCode", "K7M2Q") is empty and gameSays("ebNetCode", "K7M2QXA") is empty
   -- (no I, O, 0 or 1: they are read for each other)
   TestAssert "nor a letter no code has", gameSays("ebNetCode", "K7M2Q0") is empty and gameSays("ebNetCode", "K7M2QI") is empty
   TestAssert "nor anything else", gameSays("ebNetCode", "hello!") is empty and gameSays("ebNetCode", empty) is empty and \
         gameSays("ebNetCode", "https://example.org/?duel=") is empty
end TestARoomsCode

on TestThePlayersInTheLobby
   local tSent
   lobbyAs "Ada"
   put gameSays("ebNetSent") into tSent
   TestAssert "online, in the lobby", st("mode") is "lobby" and st("lobby") is "online" and st("online") is true and st("room") is empty
   TestAssert "the others are told, and asked who they are", tSent is "who EB|1|free|50|1|Ada" & return
   TestAssert "with nobody there the lobby says so", fieldText("Lobby Step") is "THE LOBBY" and isShown("Lobby Text") and \
         fieldText("Lobby Text") begins with "No one else is here yet." and not isShown("Who 1")
   TestAssert "and has Quick match and Play a friend", isShown("Quick") and isShown("Friend") and not isShown("Net Go") and \
         the lockText of field "Name" of card kCard of stack kStack
   hears "a", "free", "Bo", 1
   hears "b", "quick", "Cy", 0
   hears "c", "busy", "Di", 0
   hears "d", "duel", "Ed", 0
   step 0.1
   TestAssert "the players, those who can be played first", st("who") is "Cy=quick|Bo=free|Di=busy|Ed=duel"
   TestAssert "are counted", fieldText("Lobby Step") is "IN THE LOBBY: 4" and fieldText("Lobby Note") is "You are Ada. Tap a player to challenge them."
   TestAssert "a row each, with what they are doing", the label of button "Who 1" of card kCard of stack kStack is "CY  -  QUICK MATCH" and \
         the label of button "Who 2" of card kCard of stack kStack is "BO" and \
         the label of button "Who 3" of card kCard of stack kStack is "DI  -  BUSY" and \
         the label of button "Who 4" of card kCard of stack kStack is "ED  -  IN A DUEL"
   TestAssert "and no row for nobody", isShown("Who 4") and not isShown("Who 5") and not isShown("Lobby Text")
   -- (a relay keeps nothing: a newcomer has not heard me)
   get gameSays("ebNetSent")
   step 1.5
   TestAssert "a newcomer who asks is answered", gameSays("ebNetSent") is "who EB|1|free|50|0|Ada" & return
   press "Who 3"
   TestAssert "a busy player is not challenged", st("lobby") is "online" and fieldText("Lobby Note") is "Di is busy." and \
         gameSays("ebNetSent") is empty
   press "Who 4"
   TestAssert "nor one in a duel", st("lobby") is "online" and fieldText("Lobby Note") is "Ed is in a duel."
   hears "a", "gone", "Bo", 0
   step 0.1
   TestAssert "a player who leaves is off the list", st("who") is "Cy=quick|Di=busy|Ed=duel" and fieldText("Lobby Step") is "IN THE LOBBY: 3"
   hears "e", "free", "<i>Zed</i>|x", 0
   hears "f", "dancing", "No", 0
   game "ebNetHear", pkOf("g"), "who", "EB|2|free|50|0|Newer"
   game "ebNetHear", pkOf("h"), "who", "hello there"
   game "ebNetHear", pkOf("i"), "who", "EB|1|free|50|0|"
   step 0.1
   TestAssert "a stranger's name is made plain, and one with none is Player", \
         st("who") is "Cy=quick|iZedix=free|Player=free|Di=busy|Ed=duel"
   get gameSays("ebNetSent")
   step 49.7
   TestAssert "I say that I am here every twenty seconds", gameSays("ebNetSent") is "who EB|1|free|50|0|Ada" & return & "who EB|1|free|50|0|Ada" & return
   step 1
   TestAssert "and a player not heard for as long as they said is gone", st("who") is empty and fieldText("Lobby Step") is "THE LOBBY"
   press "Lobby Back"
   TestAssert "Back leaves the lobby, and says so", st("lobby") is "start" and st("online") is false and \
         gameSays("ebNetSent") is "who EB|1|gone|50|0|Ada" & return
   TestAssert "to the name, which can be changed again", isShown("Name") and fieldText("Name") is "Ada" and \
         not the lockText of field "Name" of card kCard of stack kStack
end TestThePlayersInTheLobby

on TestAChallengeSentAndAccepted
   local tTold, tId
   lobbyAs "Ada"
   hears "a", "free", "Bo", 0
   step 0.1
   get gameSays("ebNetSent")
   press "Who 1"
   put toldTo("a") into tTold
   put word 2 of tTold into tId
   TestAssert "a tap on a player challenges them", st("lobby") is "asking" and word 1 of tTold is "C" and the length of tId is 8 and \
         the number of words of tTold is 2
   TestAssert "the lobby says whom", fieldText("Lobby Step") is "CHALLENGING BO..." and st("foe") is "Bo" and not isShown("Who 1")
   TestAssert "and the others see that I am busy", "who EB|1|busy|50|0|Ada" is among the lines of sSent
   -- (their yes is their description, as the invite of the codes is)
   told "a", "O" && tId && described("O")
   put toldTo("a") into tTold
   TestAssert "accepted: their description comes, and mine goes back as the answer to it", st("lobby") is "net-link" and \
         word 1 of tTold is "A" and word 2 of tTold is tId and char 1 to 4 of word 3 of tTold is "EB1A"
   TestAssert "a guest's", gameSays("ebDuelDecode", word 3 of tTold, "A") is "v=0" & return & "s=guest"
   TestAssert "the lobby says that the link is being made", fieldText("Lobby Step") is "CONNECTING TO BO..."
   -- the link opens, and the host's number for the first wall comes
   game "ebDuelReceive", "S 4071"
   TestAssert "the match begins", st("duel") is true and st("mode") is "play" and st("shift") is 3
   TestAssert "against a rival with a name", fieldText("Banner Sub") is "You against Bo. Most points wins."
   TestAssert "the lobby is told, and left", gameSays("ebNetSent") is "who EB|1|duel|210|0|Ada" & return and st("online") is false
   game "ebTestSet", "left", 0.5
   step 1
   game "ebDuelReceive", "E 250"
   TestAssert "the result names them too", st("mode") is "result" and fieldText("Result Them") is "BO   250"
   press "Result Home"
   -- (and online again, where that can be done: not in this engine)
   TestAssert "leaving the match comes back to the lobby", st("mode") is "lobby" and st("lobby") is "start" and st("duel") is false
end TestAChallengeSentAndAccepted

on TestAChallengeRefusedOrNeverAnswered
   local tTold, tId
   lobbyAs "Ada"
   hears "a", "free", "Bo", 0
   hears "b", "free", "Cy", 0
   step 0.1
   press "Who 1"
   put word 2 of toldTo("a") into tId
   told "b", "D" && tId && "no"
   told "a", "D ZZZZZZZZ no"
   TestAssert "a no from another player, or to another challenge, is nothing", st("lobby") is "asking"
   told "a", "D" && tId && "no"
   TestAssert "not now", st("lobby") is "online" and fieldText("Lobby Note") is "Bo said not now."
   TestAssert "and I can be challenged again", "who EB|1|free|50|0|Ada" is among the lines of gameSays("ebNetSent")
   press "Who 1"
   put word 2 of toldTo("a") into tId
   told "a", "D" && tId && "busy"
   TestAssert "busy", st("lobby") is "online" and fieldText("Lobby Note") is "Bo is busy."
   press "Who 1"
   put word 2 of toldTo("a") into tId
   step 29
   TestAssert "a challenge waits half a minute", st("lobby") is "asking"
   step 2
   TestAssert "and no longer", st("lobby") is "online" and fieldText("Lobby Note") is "Bo did not answer."
   TestAssert "they are told it is off", toldTo("a") is "D" && tId && "cancel"
   step 9
   TestAssert "what the lobby said gives way to its own line", fieldText("Lobby Note") is "You are Ada. Tap a player to challenge them."
   press "Who 1"
   put word 2 of toldTo("a") into tId
   press "Lobby Back"
   TestAssert "Back takes a challenge back", st("lobby") is "online" and toldTo("a") is "D" && tId && "cancel"
   press "Who 1"
   put word 2 of toldTo("a") into tId
   told "a", "O" && tId && "EB1Oz:nonsense"
   TestAssert "a description that cannot be read ends it", st("lobby") is "online" and toldTo("a") is "D" && tId && "failed" and \
         fieldText("Lobby Note") is "What Bo sent could not be read."
   told "b", "O ABCDEFGH" && described("O")
   TestAssert "and a description nobody asked for starts nothing", st("lobby") is "online" and toldTo("b") is "D ABCDEFGH busy"
end TestAChallengeRefusedOrNeverAnswered

on TestAChallengeReceived
   local tTold
   lobbyAs "Ada"
   hears "a", "free", "Bo", 0
   step 0.1
   get gameSays("ebNetSent")
   told "a", "C ABCDEFGH"
   TestAssert "a challenge", st("lobby") is "asked" and fieldText("Lobby Text") is "BO challenges you to a duel." and st("foe") is "Bo"
   TestAssert "to accept or not", isShown("Accept") and isShown("Decline") and not isShown("Lobby Back") and not isShown("Who 1")
   TestAssert "meanwhile I am busy", gameSays("ebNetSent") is "who EB|1|busy|50|0|Ada" & return
   told "b", "C ZZZZZZZZ"
   TestAssert "and a second challenger is told so", st("lobby") is "asked" and st("foe") is "Bo" and toldTo("b") is "D ZZZZZZZZ busy"
   press "Decline"
   TestAssert "Not now says no", st("lobby") is "online" and toldTo("a") is "D ABCDEFGH no" and \
         "who EB|1|free|50|0|Ada" is among the lines of sSent
   told "a", "C ABCDEFGH"
   told "a", "D ABCDEFGH cancel"
   TestAssert "a challenge taken back", st("lobby") is "online" and fieldText("Lobby Note") is "Bo took the challenge back."
   told "a", "C ABCDEFGH"
   step 34
   TestAssert "a challenge waits a little longer than its sender does", st("lobby") is "asked"
   step 2
   TestAssert "and then runs out", st("lobby") is "online" and fieldText("Lobby Note") is "The challenge from Bo ran out."
   told "z", "C ABCDEFGH"
   TestAssert "a challenger the list has not seen has no name yet", st("lobby") is "asked" and \
         fieldText("Lobby Text") is "A PLAYER challenges you to a duel."
   hears "z", "busy", "Zed", 0
   TestAssert "and has one as soon as it says who it is", st("lobby") is "asked" and st("foe") is "Zed" and \
         fieldText("Lobby Text") is "ZED challenges you to a duel."
   press "Decline"
   told "a", "C abc"
   told "a", "C"
   game "ebNetHear", pkOf("a"), "tell", "L2 C ABCDEFGH"
   game "ebNetHear", pkOf("a"), "tell", "hello"
   TestAssert "nonsense is no challenge", st("lobby") is "online"
   get gameSays("ebNetSent")
   told "a", "C ABCDEFGH"
   press "Accept"
   put toldTo("a") into tTold
   TestAssert "accepted: my description goes to them, as the invite of the codes", st("lobby") is "net-link" and \
         word 1 to 2 of tTold is "O ABCDEFGH" and char 1 to 4 of word 3 of tTold is "EB1O"
   TestAssert "a host's", gameSays("ebDuelDecode", word 3 of tTold, "O") is "v=0" & return & "s=host"
   told "b", "A ABCDEFGH" && described("A")
   told "a", "A ZZZZZZZZ" && described("A")
   TestAssert "an answer from another player, or to another challenge, is not theirs", st("lobby") is "net-link"
   told "a", "A ABCDEFGH" && described("A")
   -- the link opens: their game says hello, and mine, the host's, begins
   game "ebDuelReceive", "H 1"
   TestAssert "their answer comes, the link opens and the match begins", st("duel") is true and st("mode") is "play" and \
         word 1 of line 1 of gameSays("ebDuelSent") is "S"
   TestAssert "against Bo", fieldText("Banner Sub") is "You against Bo. Most points wins."
end TestAChallengeReceived

-- Some relays keep for a few minutes what they pass on, and give it to
-- whoever asks, the newest first: ebNetHear's fourth word is how many
-- seconds ago a message was made
on TestWhatARelayKeptIsThePast
   lobbyAs "Ada"
   game "ebNetHear", pkOf("a"), "who", "EB|1|free|50|0|Bo", 400
   step 0.1
   TestAssert "an I am here made minutes ago lists nobody", st("who") is empty
   game "ebNetHear", pkOf("a"), "who", "EB|1|free|50|0|Bo", 10
   step 0.1
   TestAssert "one made a moment ago does", st("who") is "Bo=free"
   game "ebNetHear", pkOf("a"), "who", "EB|1|busy|50|0|Bo", 40
   step 0.1
   TestAssert "an older one that comes after it changes nothing", st("who") is "Bo=free"
   game "ebNetHear", pkOf("a"), "who", "EB|1|quick|50|0|Bo", 10
   step 0.1
   TestAssert "one of the same second does, in the order it comes", st("who") is "Bo=quick"
   game "ebNetHear", pkOf("a"), "who", "EB|1|gone|50|0|Bo", 5
   game "ebNetHear", pkOf("a"), "who", "EB|1|free|50|0|Bo", 8
   step 0.1
   TestAssert "a player who left is not back by what was said before", st("who") is empty
   game "ebNetHear", pkOf("a"), "who", "EB|1|free|50|0|Bo", 0
   step 0.1
   TestAssert "and is by what is said now", st("who") is "Bo=free"
   game "ebNetHear", pkOf("b"), "who", "EB|1|free|50|0|Cy", -30
   step 0.1
   TestAssert "a player whose clock is ahead is listed too", st("who") is "Bo=free|Cy=free"
   game "ebNetHear", pkOf("a"), "tell", "L1 C ABCDEFGH", 400
   TestAssert "a challenge made minutes ago is no challenge", st("lobby") is "online"
   game "ebNetHear", pkOf("a"), "tell", "L1 C ABCDEFGH", 3
   TestAssert "one made now is", st("lobby") is "asked" and st("foe") is "Bo"
end TestWhatARelayKeptIsThePast

-- A relay that goes is asked again: in a while if another is open, soon
-- if none is, so that a moment without the network is not the end of the
-- lobby. The test's lobby is given relays (ebNetRelay), which the test
-- opens and loses as NostrXT's relay library would say; ebNetLines is
-- what the game has asked for or has open
private command relay pUrl, pKind
   game "ebNetRelay", pUrl, pKind
end relay

-- (of a line that broke the library says both)
private command loses pUrl
   game "ebNetRelay", pUrl, "error"
   game "ebNetRelay", pUrl, "disconnected"
end loses

on TestARelayThatGoesIsAskedAgain
   lobbyAs "Ada"
   relay "wss://one", "dial"
   relay "wss://two", "dial"
   TestAssert "a relay asked for is waited for", gameSays("ebNetLines") is "wss://one wait" & return & "wss://two wait" and st("relays") is 0
   relay "wss://one", "open"
   relay "wss://two", "open"
   TestAssert "and opens", gameSays("ebNetLines") is "wss://one open" & return & "wss://two open" and st("relays") is 2

   loses "wss://one"
   step 14
   TestAssert "one of two goes: it is not asked again at once", gameSays("ebNetLines") is "wss://two open" and st("lobby") is "online"
   step 2
   TestAssert "but in a while", gameSays("ebNetLines") is "wss://one wait" & return & "wss://two open"
   get gameSays("ebNetSent")
   relay "wss://one", "open"
   TestAssert "it opens: it is told that I am here", st("relays") is 2 and gameSays("ebNetSent") is "who EB|1|free|50|0|Ada" & return

   loses "wss://one"
   step 5
   loses "wss://two"
   TestAssert "both go: none is open, and the lobby is kept", st("relays") is 0 and gameSays("ebNetLines") is empty and \
         st("lobby") is "online" and st("online") is true
   step 2
   TestAssert "they are not asked again at once", gameSays("ebNetLines") is empty
   step 2
   TestAssert "but soon, the one that went first too", gameSays("ebNetLines") is "wss://one wait" & return & "wss://two wait"
   step 6
   TestAssert "the lobby is kept while they are waited for", st("lobby") is "online" and st("online") is true
   relay "wss://two", "open"
   step 30
   TestAssert "one answers: the lobby goes on", st("lobby") is "online" and st("online") is true and st("relays") is 1

   -- (the first goes for the third time, the second for the second)
   loses "wss://one"
   loses "wss://two"
   step 4
   TestAssert "both go again: both are asked again", gameSays("ebNetLines") is "wss://one wait" & return & "wss://two wait"
   loses "wss://one"
   loses "wss://two"
   step 4
   TestAssert "a relay that went three times is asked no more", gameSays("ebNetLines") is "wss://two wait" and st("online") is true
   loses "wss://two"
   step 3
   TestAssert "with none open the lobby is kept twelve seconds", st("lobby") is "online" and st("online") is true
   step 2
   TestAssert "and no longer: its first step says so", st("online") is false and st("lobby") is "start" and st("mode") is "lobby" and \
         fieldText("Lobby Note") is "The lobby cannot be reached. Check your connection, or play by code."
end TestARelayThatGoesIsAskedAgain

-- A phone that slept, or a page that was hidden: its relays went
-- meanwhile, which the game may hear before the first frame after or
-- after it. (ebTestSlept is one frame that was so many seconds in
-- coming.)
on TestAPageThatSleptHasNotWaitedForARelay
   lobbyAs "Ada"
   relay "wss://one", "dial"
   relay "wss://one", "open"
   step 5
   loses "wss://one"
   game "ebTestSlept", 90
   TestAssert "the relay went, and a frame comes a minute and a half later: the lobby is kept, and the relay asked again", \
         st("online") is true and st("lobby") is "online" and gameSays("ebNetLines") is "wss://one wait"
   step 11
   TestAssert "it is waited for from then", st("online") is true and st("lobby") is "online"
   relay "wss://one", "open"
   step 5
   TestAssert "and opens: the lobby goes on", st("online") is true and st("relays") is 1

   game "ebTestSlept", 90
   loses "wss://one"
   step 4
   TestAssert "the frame first, and then the relay is heard to have gone: asked again soon", \
         st("online") is true and gameSays("ebNetLines") is "wss://one wait"
   loses "wss://one"
   game "ebTestSlept", 1.5
   step 4
   loses "wss://one"
   step 8
   TestAssert "a slow frame is not a sleep: the lobby is given up twelve seconds after its last relay", \
         st("online") is false and st("lobby") is "start"
end TestAPageThatSleptHasNotWaitedForARelay

on TestARelayThatStayedIsAskedAfresh
   local tAsked
   lobbyAs "Ada"
   relay "wss://one", "dial"
   relay "wss://one", "open"
   put 0 into tAsked
   repeat 5 times
      step 61
      loses "wss://one"
      step 4
      if gameSays("ebNetLines") is "wss://one wait" then
         add 1 to tAsked
      end if
      relay "wss://one", "open"
   end repeat
   TestAssert "a relay that stayed a minute each time is asked again every time it goes", tAsked is 5 and st("relays") is 1 and \
         st("lobby") is "online"
   lobbyAs "Ada"
   relay "wss://one", "dial"
   relay "wss://one", "open"
   put 0 into tAsked
   repeat 4 times
      loses "wss://one"
      step 4
      if gameSays("ebNetLines") is "wss://one wait" then
         add 1 to tAsked
      end if
      relay "wss://one", "open"
   end repeat
   TestAssert "one that answers and hangs up is asked three times, not for ever", tAsked is 3 and st("relays") is 0
end TestARelayThatStayedIsAskedAfresh

on TestALinkThatIsNeverMade
   lobbyAs "Ada"
   hears "a", "free", "Bo", 0
   step 0.1
   told "a", "C ABCDEFGH"
   press "Accept"
   get gameSays("ebNetSent")
   step 29
   TestAssert "a link has half a minute", st("lobby") is "net-link"
   step 2
   TestAssert "and with none made the lobby says why, and is the lobby again", st("lobby") is "online" and \
         fieldText("Lobby Note") is "No link could be made with Bo. Some networks block a direct link."
   TestAssert "where I can be challenged again", "who EB|1|free|50|0|Ada" is among the lines of gameSays("ebNetSent")
   told "a", "C ABCDEFGH"
   press "Accept"
   told "a", "D ABCDEFGH cancel"
   TestAssert "a link the other gives up", st("lobby") is "online" and fieldText("Lobby Note") is "Bo is busy."
   told "a", "C ABCDEFGH"
   press "Accept"
   get gameSays("ebNetSent")
   press "Lobby Back"
   TestAssert "Back gives it up, and says so", st("lobby") is "online" and toldTo("a") is "D ABCDEFGH cancel"
   told "a", "C ABCDEFGH"
   press "Accept"
   get gameSays("ebNetSent")
   told "a", "A ABCDEFGH EB1Az:nonsense"
   TestAssert "an answer that cannot be read ends it", st("lobby") is "online" and toldTo("a") is "D ABCDEFGH failed"
end TestALinkThatIsNeverMade

on TestAQuickMatch
   local tTold, tId
   lobbyAs "Ada"
   get gameSays("ebNetSent")
   press "Quick"
   TestAssert "Quick match looks for anyone who wants one", st("lobby") is "quick" and fieldText("Lobby Step") is "LOOKING FOR A RIVAL..." and \
         gameSays("ebNetSent") is "who EB|1|quick|50|0|Ada" & return
   hears "a", "free", "Bo", 0
   step 1
   TestAssert "a player who does not is left alone", st("lobby") is "quick" and gameSays("ebNetSent") is empty
   -- (my key begins with 5, and theirs with 1: theirs sorts first)
   hears "1", "quick", "Cy", 0
   step 2
   TestAssert "of two who want a match, the one whose key sorts first sends its description: not me", st("lobby") is "quick" and \
         gameSays("ebNetSent") is empty
   told "1", "O QQQQQQQQ" && described("O")
   put toldTo("1") into tTold
   TestAssert "theirs comes, and my answer goes back", st("lobby") is "net-link" and word 1 to 2 of tTold is "A QQQQQQQQ" and st("foe") is "Cy"
   TestAssert "meanwhile I am busy", "who EB|1|busy|50|0|Ada" is among the lines of sSent
   told "1", "D QQQQQQQQ cancel"
   TestAssert "when they give up, the search goes on", st("lobby") is "quick" and "who EB|1|quick|50|0|Ada" is among the lines of gameSays("ebNetSent")
   hears "1", "gone", "Cy", 0
   -- (and theirs begins with a: mine sorts first)
   hears "a", "quick", "Bo", 0
   step 1
   put toldTo("a") into tTold
   put word 2 of tTold into tId
   TestAssert "with a rival whose key sorts after mine, I send mine", st("lobby") is "net-link" and word 1 of tTold is "O" and \
         the length of tId is 8 and gameSays("ebDuelDecode", word 3 of tTold, "O") is "v=0" & return & "s=host"
   told "a", "D" && tId && "busy"
   TestAssert "a rival who is busy after all", st("lobby") is "quick"
   get gameSays("ebNetSent")
   step 6
   TestAssert "is left alone for a while", st("lobby") is "quick" and toldTo("a") is empty
   step 3
   put toldTo("a") into tTold
   TestAssert "and then asked again", st("lobby") is "net-link" and word 1 of tTold is "O"
   told "a", "A" && word 2 of tTold && described("A")
   game "ebDuelReceive", "H 1"
   TestAssert "their answer, the link, and the match", st("duel") is true and fieldText("Banner Sub") is "You against Bo. Most points wins."
end TestAQuickMatch

on TestAQuickMatchIsLeftByBack
   lobbyAs "Ada"
   press "Quick"
   get gameSays("ebNetSent")
   press "Lobby Back"
   TestAssert "Back from a quick match is the lobby's list", st("lobby") is "online" and gameSays("ebNetSent") is "who EB|1|free|50|0|Ada" & return
   hears "a", "quick", "Bo", 0
   step 1
   TestAssert "where nobody is matched by chance", st("lobby") is "online" and st("who") is "Bo=quick"
   get gameSays("ebNetSent")
   press "Who 1"
   TestAssert "a tap on a player who wants a quick match is the match", st("lobby") is "net-link" and word 1 of toldTo("a") is "O"
end TestAQuickMatchIsLeftByBack

on TestARoomForAFriend
   local tCode, tTold
   lobbyAs "Ada"
   hears "a", "free", "Bo", 0
   step 0.1
   get gameSays("ebNetSent")
   press "Friend"
   put st("room") into tCode
   TestAssert "Play a friend makes a room", st("lobby") is "room" and the length of tCode is 6 and gameSays("ebNetCode", tCode) is tCode
   -- (in a page it is the link with the code in it that is sent)
   TestAssert "with its code to send", fieldText("Lobby Step") is "YOUR ROOM" and fieldText("Code") is tCode and isShown("Code Copy") and \
         the lockText of field "Code" of card kCard of stack kStack and \
         word -1 of the label of button "Code Copy" of card kCard of stack kStack is among the items of "CODE,LINK"
   TestAssert "the lobby is left for it, and the room asked who is there", gameSays("ebNetSent") is "who EB|1|gone|50|0|Ada" & return & \
         "who EB|1|quick|50|1|Ada" & return
   TestAssert "nobody of the lobby is in the room", st("who") is empty
   -- (the friend's key begins with a: mine sorts first)
   hears "a", "quick", "Bo", 1
   step 1
   put toldTo("a") into tTold
   TestAssert "the friend arrives, and the link is made at once", st("lobby") is "net-link" and word 1 of tTold is "O" and st("foe") is "Bo"
   told "a", "D" && word 2 of tTold && "failed"
   TestAssert "a link that fails comes back to the room", st("lobby") is "room" and fieldText("Code") is tCode
   press "Lobby Back"
   TestAssert "Back from the room is the lobby", st("lobby") is "online" and st("room") is empty and \
         "who EB|1|free|50|1|Ada" is among the lines of gameSays("ebNetSent")
end TestARoomForAFriend

on TestAFriendsRoomByItsCode
   local tTold
   lobbyAs "Ada"
   press "Friend"
   press "Code Go"
   TestAssert "I have a code: a place to type it", st("lobby") is "room-take" and fieldText("Lobby Step") is "A FRIEND'S ROOM" and \
         fieldText("Code") is empty and not the lockText of field "Code" of card kCard of stack kStack and isShown("Code Paste")
   game "ebPasted", "hello"
   TestAssert "what is no code is refused", st("lobby") is "room-take" and fieldText("Lobby Note") begins with "That is not a room's code"
   get gameSays("ebNetSent")
   game "ebPasted", "https://example.org/play/?play=Ember%20Bricks&duel=k7m2qx"
   TestAssert "a code, or the link with it, is the friend's room", st("lobby") is "room-in" and st("room") is "K7M2QX" and \
         fieldText("Lobby Step") is "ROOM K7M2QX"
   TestAssert "my own room is left for it", "who EB|1|quick|50|1|Ada" is among the lines of gameSays("ebNetSent")
   -- (the friend's key begins with 1: theirs sorts first, and theirs comes)
   hears "1", "quick", "Bo", 0
   step 1
   told "1", "O QQQQQQQQ" && described("O")
   put toldTo("1") into tTold
   TestAssert "the friend's description comes, and my answer goes back", st("lobby") is "net-link" and word 1 to 2 of tTold is "A QQQQQQQQ"
   told "1", "D QQQQQQQQ failed"
   TestAssert "a link that fails comes back to the room", st("lobby") is "room-in" and st("room") is "K7M2QX"
   told "z", "O ZZZZZZZZ" && described("O")
   TestAssert "a description from one who is not in the room starts nothing", st("lobby") is "room-in" and toldTo("z") is "D ZZZZZZZZ busy"
   press "Lobby Back"
   TestAssert "Back is the lobby", st("lobby") is "online" and st("room") is empty
end TestAFriendsRoomByItsCode

on TestAFriendsLink
   game "ebTestSet", "rtc", "yes"
   game "ebTestSet", "nostr", "yes"
   game "ebTestSet", "invite", "https://example.org/play/?play=Ember%20Bricks&duel=K7M2QX"
   press "Duel Open"
   TestAssert "a page opened by a friend's link says so", st("lobby") is "start" and st("invite") is "K7M2QX" and \
         fieldText("Lobby Text") begins with "A friend waits for you in room K7M2QX." and \
         the label of button "Net Go" of card kCard of stack kStack is "JOIN YOUR FRIEND"
   -- (online: the first relay to open is the friend's room)
   game "ebTestNet", pkOf("5"), "Ada"
   TestAssert "online is the friend's room", st("lobby") is "room-in" and st("room") is "K7M2QX" and \
         gameSays("ebNetSent") is "who EB|1|quick|50|1|Ada" & return
   hears "1", "quick", "Bo", 0
   told "1", "O QQQQQQQQ" && described("O")
   game "ebDuelReceive", "S 7"
   TestAssert "and the match with them", st("duel") is true and fieldText("Banner Sub") is "You against Bo. Most points wins."
   TestAssert "the link has done its work", st("invite") is empty
end TestAFriendsLink

-- The lobby's panel on the window, its buttons on the window, big enough
-- to tap and apart, and its words whole, off the buttons and each other
private command checkLobby pAt
   local tCard, tGroup, tBad, tRects, tRect, tName, tField, tLines, i, j, tPanel
   put the rect of card kCard of stack kStack into tCard
   put the long id of group "Lobby" of card kCard of stack kStack into tGroup
   put the rect of graphic "Lobby Glass" of tGroup into tPanel
   if not isInside(tPanel, tCard) then
      put "its panel off the window;" after tBad
   end if
   repeat with i = 1 to the number of buttons of tGroup
      put the short name of button i of tGroup into tName
      if the visible of button i of tGroup then
         put the rect of button i of tGroup into tRect
         if not isInside(tRect, tPanel) then
            put tName && "off the panel;" after tBad
         end if
         if item 4 of tRect - item 2 of tRect < 28 or item 3 of tRect - item 1 of tRect < 28 then
            put tName && "too small to tap;" after tBad
         end if
         if the rect of graphic (tName && "Shape") of tGroup is not tRect or not the visible of graphic (tName && "Shape") of tGroup then
            put tName && "is not on its shape;" after tBad
         end if
         if the formattedWidth of button i of tGroup > item 3 of tRect - item 1 of tRect then
            put tName && "is narrower than its words;" after tBad
         end if
         put tName & tab & tRect & return after tRects
      end if
   end repeat
   repeat with i = 1 to the number of fields of tGroup
      put the long id of field i of tGroup into tField
      put the short name of tField into tName
      if the visible of tField then
         put the rect of tField into tRect
         if not isInside(tRect, tPanel) then
            put tName && "off the panel;" after tBad
         end if
         put the number of lines of the formattedText of tField into tLines
         if the height of tField < tLines * the effective textHeight of tField then
            put tName && "is shorter than its" && tLines && "lines;" after tBad
         end if
         if the dontWrap of tField and the formattedWidth of tField > the width of tField then
            put tName && "is narrower than its words;" after tBad
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
   TestAssert pAt && "has its buttons and its words on the panel, apart" && tBad, tBad is empty and tRects is not empty
end checkLobby

on TestTheLobbyFitsAPhoneAndAWindow
   local tSize, tWidth, tAt, i
   repeat for each item tSize in "390x760,320x480,430x932,844x390,568x320,900x640,768x1024,1920x1080"
      set the itemDelimiter to "x"
      put item 1 of tSize into tWidth
      windowSize tWidth, item 2 of tSize
      set the itemDelimiter to comma
      if the width of stack kStack is not tWidth then
         TestSkip "the lobby at" && tSize, "the window could not be made that size here"
         next repeat
      end if
      put "the lobby at" && tSize & ":" into tAt
      game "ebTestSet", "rtc", "yes"
      game "ebTestSet", "nostr", "yes"
      game "ebGoTitle"
      press "Duel Open"
      checkLobby tAt && "the name"
      game "ebTestSet", "invite", "K7M2QX"
      press "Lobby Back"
      press "Duel Open"
      checkLobby tAt && "the name, for a friend's link"
      game "ebTestSet", "invite", empty
      press "Codes Open"
      checkLobby tAt && "play by code"
      lobbyAs "Ada of the Kilns"
      checkLobby tAt && "nobody there"
      repeat with i = 1 to 7
         hears char i of "abcdefg", item i of "quick,busy,busy,duel,duel,duel,free", "Wwwwwwwwwwww W" & i, 0
      end repeat
      step 0.1
      checkLobby tAt && "the players"
      TestAssert tAt && "the players: as many rows as there is room for", isShown("Who 3") and st("who") is not empty
      press "Who 3"
      checkLobby tAt && "a line about a player"
      press "Quick"
      checkLobby tAt && "a quick match"
      press "Lobby Back"
      press "Friend"
      checkLobby tAt && "a room"
      press "Code Go"
      checkLobby tAt && "a friend's code"
      game "ebPasted", "hello"
      checkLobby tAt && "a code refused"
      press "Lobby Back"
      told "a", "C ABCDEFGH"
      checkLobby tAt && "a challenge"
      press "Accept"
      checkLobby tAt && "a link being made"
      press "Lobby Back"
      press "Lobby Back"
      press "Lobby Back"
      TestAssert tAt && "and out", st("mode") is "title"
   end repeat
end TestTheLobbyFitsAPhoneAndAWindow

----------------------------------------------------------------------
-- The duel: a match

on TestADuelBegins
   game "ebTestDuel", 4071
   TestAssert "a match", st("duel") is true and st("mode") is "play" and st("stage") is "play"
   TestAssert "three minutes", st("left") is 180 and fieldText("Clock") is "3:00"
   -- (4071 mod 12 is 3: the fourth level)
   TestAssert "its first wall is one of the first twelve levels, by the host's number", st("shift") is 3 and \
         st("level") is 1 and fieldText("Stage") is "WALL 1" and fieldText("Stage Name") is "Two Chimneys"
   TestAssert "the rival's arena is shown", shown("Rival") and the visible of field "Clock" of card kCard of stack kStack
   TestAssert "no lives are", not the visible of graphic "Life 1" of card kCard of stack kStack
   step 2
   TestAssert "the clock waits for the count of three, and the ball", st("left") is 180 and st("phase") is "serve"
   step 1.5
   TestAssert "then both go", st("left") < 180 and st("left") > 179 and st("phase") is "live"
   step 1
   TestAssert "the clock shows it", fieldText("Clock") is "2:59"
end TestADuelBegins

on TestADuelsFirstBallWaitsForTheCount
   game "ebTestDuel", 1
   game "ebTestSet", "drops", false
   step 1
   game "ebLaunch"
   TestAssert "a click before the count of three is over sends no ball off", st("phase") is "serve" and ball(5) is true
   TestAssert "and nothing says to click", not the visible of field "Hint" of card kCard of stack kStack
   game "ebPause"
   game "ebResume"
   TestAssert "nor after a pause", not the visible of field "Hint" of card kCard of stack kStack
   step 1
   game "ebLaunch"
   TestAssert "nor does a second click, and the clock has not begun", st("phase") is "serve" and st("left") is 180
   step 1.5
   TestAssert "the count over, the ball goes by itself", st("phase") is "live" and st("left") < 180
   loseBall
   step 1.3
   TestAssert "the next ball waits a moment", st("phase") is "serve" and ball(5) is true
   game "ebLaunch"
   TestAssert "and a click sends that one off", st("phase") is "live" and ball(5) is false
end TestADuelsFirstBallWaitsForTheCount

on TestADuelsLostBallCostsPointsNotALife
   game "ebTestDuel", 1
   game "ebTestSet", "drops", false
   step 3.5
   game "ebTestSet", "score", 400
   loseBall
   TestAssert "a ball lost costs 150", st("score") is 250 and st("phase") is "lost"
   TestAssert "and no life", st("lives") is 3 and st("mode") is "play"
   step 1.3
   TestAssert "the next ball waits a moment", st("phase") is "serve"
   step 1.6
   TestAssert "and goes by itself", st("phase") is "live"
   game "ebTestSet", "score", 100
   loseBall
   TestAssert "the score never goes under nothing", st("score") is 0
end TestADuelsLostBallCostsPointsNotALife

on TestADuelsWallClearedIsTheNextAtOnce
   game "ebTestDuel", 0
   game "ebTestSet", "drops", false
   step 3.5
   game "ebTestLevel", wall("5,5,1")
   hit 5, 5
   step 0.1
   -- the brick 10, the wall 300 and 20 for its number
   TestAssert "a wall down: a bonus", st("phase") is "cleared" and st("score") is 10 + 320
   step 1.4
   TestAssert "and the next wall, with no panel between", st("mode") is "play" and st("level") is 2 and \
         st("phase") is "serve" and not shown("Clear") and fieldText("Stage") is "WALL 2"
   TestAssert "no level is opened by it", st("unlocked") is 1
end TestADuelsWallClearedIsTheNextAtOnce

on TestHeatSendsTheRivalTrouble
   local tSent
   game "ebTestDuel", 0
   game "ebTestSet", "drops", false
   step 3.5
   put gameSays("ebDuelSent") into tSent
   game "ebTestLevel", wall("3,5,1;5,5,1;7,5,1;9,5,1;1,5,1")
   game "ebTestSet", "heat", 3
   hit 3, 5
   TestAssert "the heat's second step sends nothing", st("mult") is 2 and gameSays("ebDuelSent") is empty
   game "ebTestSet", "heat", 7
   hit 5, 5
   TestAssert "its third, a fast ball", st("mult") is 3 and gameSays("ebDuelSent") is "A fast" & return
   game "ebTestSet", "heat", 11
   hit 7, 5
   TestAssert "its fourth, a small paddle", st("mult") is 4 and gameSays("ebDuelSent") is "A small" & return
   game "ebTestSet", "heat", 15
   hit 9, 5
   TestAssert "its fifth, more bricks", st("mult") is 5 and gameSays("ebDuelSent") is "A junk" & return
   hit 1, 5
   TestAssert "and nothing more while it stays there", st("mult") is 5 and gameSays("ebDuelSent") is empty
end TestHeatSendsTheRivalTrouble

on TestTroubleFromTheRival
   local tBricks
   game "ebTestDuel", 0
   step 3.5
   game "ebDuelReceive", "A fast"
   TestAssert "a fast ball", st("pace") is 1.3
   game "ebDuelReceive", "A small"
   TestAssert "a small paddle", st("size") is "small"
   game "ebTestLevel", wall("5,5,3;6,5,T;7,7,B")
   put st("bricks") into tBricks
   game "ebDuelReceive", "A junk"
   TestAssert "more bricks: the wall goes a row down", brick(5, 5) is empty and brick(5, 6) is "31" and \
         brick(6, 6) is "T2" and brick(7, 8) is "B1"
   TestAssert "under a row of tough ones with a gap", st("bricks") is tBricks + 9
   game "ebTestLevel", wall("5,14,3;6,1,2")
   game "ebDuelReceive", "A junk"
   TestAssert "a wall that reaches the last row stays, and the top row is filled", brick(5, 14) is "31" and \
         brick(6, 1) is "21" and brick(6, 2) is empty and st("bricks") >= 2 + 8
   game "ebDuelReceive", "A nonsense"
   TestAssert "what is no trouble is nothing", st("mode") is "play"
end TestTroubleFromTheRival

on TestThePictureOfAnArena
   local tPicture, tParts
   game "ebTestDuel", 2
   game "ebTestSet", "drops", false
   step 3.5
   game "ebTestLevel", wall("5,5,3;6,5,T;7,7,B;8,8,X")
   hit 5, 5
   put gameSays("ebDuelSent", "picture") into tPicture
   TestAssert "ten times a second, a picture of my arena", char 1 to 2 of tPicture is "T "
   set the itemDelimiter to "|"
   put the number of items of tPicture into tParts
   TestAssert "the score, the wall, the heat, the paddle", item 1 of tPicture is "T 10,1,1," & round(st("padx")) & ",56"
   TestAssert "the ball", the number of items of item 2 of tPicture is 1 and item 2 of tPicture ends with ";"
   TestAssert "and a place for each of the 140 bricks", tParts is 3 and the length of item 3 of tPicture is 140 and \
         char 46 of item 3 of tPicture is "T" and char 67 of item 3 of tPicture is "B" and char 78 of item 3 of tPicture is "X" and \
         char 45 of item 3 of tPicture is "."
   set the itemDelimiter to comma
   -- the rival plays as I do
   game "ebDuelReceive", tPicture
   step 0.1
   TestAssert "a rival's picture is drawn: the score", st("rival") is 10 and fieldText("Rival Score") is "10"
   TestAssert "the bricks", rivalBricks() is 3 and the visible of graphic "Rival Brick 46" of card kCard of stack kStack and \
         not the visible of graphic "Rival Brick 45" of card kCard of stack kStack
   TestAssert "the ball", the visible of graphic "Rival Ball 1" of card kCard of stack kStack and \
         not the visible of graphic "Rival Ball 2" of card kCard of stack kStack
   TestAssert "in the rival's arena", isInside(rectOf("Rival Brick 46"), rectOf("Rival Arena")) and \
         isInside(rectOf("Rival Paddle"), rectOf("Rival Arena"))
   game "ebDuelReceive", "T 1250,3,4,200,86||" & item 3 of tPicture
   step 0.1
   TestAssert "the heat's bonus is beside the rival's name", fieldText("Rival Name") is "RIVAL x4" and fieldText("Rival Score") is "1,250"
end TestThePictureOfAnArena

on TestNonsenseFromTheRivalIsNothing
   local tLong, i
   game "ebTestDuel", 2
   step 3.5
   game "ebDuelReceive", "T 10,1,1,160,56||"
   step 0.1
   repeat with i = 1 to 400
      put "nonsense " after tLong
   end repeat
   game "ebDuelReceive", "T many,1,1,160,56||"
   game "ebDuelReceive", "T 99"
   game "ebDuelReceive", "T 500,1,1,160,56|a,b;1;2,3,4|short"
   game "ebDuelReceive", "E many"
   game "ebDuelReceive", "S 12"
   game "ebDuelReceive", "Z"
   game "ebDuelReceive", "T " & tLong
   game "ebDuelReceive", empty
   step 0.1
   TestAssert "the match goes on", st("mode") is "play" and st("stage") is "play" and st("duel") is true
   TestAssert "a picture with a score that is no number changes nothing", st("rival") is 500
   TestAssert "nor do bricks that are not 140, or balls that are no places", rivalBricks() is 0 and \
         not the visible of graphic "Rival Ball 1" of card kCard of stack kStack
   game "ebDuelReceive", "T 99999999999,1,9,9999,9999||"
   step 0.1
   TestAssert "numbers out of all measure are brought in", st("rival") is 99999999 and fieldText("Rival Name") is "RIVAL x5" and \
         isInside(rectOf("Rival Paddle"), rectOf("Rival Arena"))
end TestNonsenseFromTheRivalIsNothing

on TestTheClockRunsOutAndTheResult
   local tSent, tMine
   game "ebTestDuel", 2
   step 3.5
   game "ebTestSet", "score", 400
   game "ebDuelReceive", "T 90,1,1,160,56||"
   put gameSays("ebDuelSent") into tSent
   game "ebTestSet", "left", 12
   step 2.5
   TestAssert "the last ten seconds show", fieldText("Clock") is "0:10"
   game "ebTestSet", "left", 0.5
   step 1
   TestAssert "time: the result", st("mode") is "result" and st("stage") is "result" and shown("Result")
   -- (the 400, and whatever the ball broke of the wall since)
   put st("score") into tMine
   TestAssert "my last score goes to the rival", tMine >= 400 and tMine < 1000 and ("E" && tMine) is among the lines of gameSays("ebDuelSent")
   TestAssert "the result waits for the rival's", fieldText("Result Title") is "TIME!" and fieldText("Result You") is ("YOU   " & tMine) and \
         fieldText("Result Them") is "RIVAL   90"
   game "ebDuelReceive", "E 120"
   TestAssert "which decides it", fieldText("Result Title") is "YOU WIN" and fieldText("Result Them") is "RIVAL   120"
   TestAssert "a duel's score is no best of the game", st("best") is 0
   press "Rematch"
   TestAssert "Rematch asks the rival", gameSays("ebDuelSent") is "R" & return and st("mode") is "result" and \
         fieldText("Result Note") is "Waiting for your rival..."
   game "ebDuelReceive", "R"
   TestAssert "who wants one too: a new match", st("mode") is "play" and st("stage") is "play" and st("left") is 180 and st("score") is 0
   TestAssert "which the host begins", char 1 to 2 of gameSays("ebDuelSent") is "S "
end TestTheClockRunsOutAndTheResult

on TestTheResultWhenTheRivalWinsOrItIsADraw
   game "ebTestDuel", 2
   step 3.5
   game "ebTestSet", "score", 400
   game "ebDuelReceive", "E 900"
   game "ebTestSet", "left", 0.1
   step 0.5
   TestAssert "the rival's score was there first", st("mode") is "result" and fieldText("Result Title") is "RIVAL WINS"
   game "ebDuelReceive", "R"
   TestAssert "the rival asks for a rematch", fieldText("Result Note") is "Your rival wants a rematch." and st("mode") is "result"
   press "Rematch"
   TestAssert "and gets it", st("mode") is "play" and st("left") is 180
   step 3.5
   game "ebTestSet", "score", 70
   game "ebDuelReceive", "E 70"
   game "ebTestSet", "left", 0.1
   step 0.5
   TestAssert "the same score is a draw", fieldText("Result Title") is "A DRAW"
end TestTheResultWhenTheRivalWinsOrItIsADraw

on TestTheRivalsLastScoreNeverComes
   game "ebTestDuel", 2
   step 3.5
   game "ebDuelReceive", "T 250,1,1,160,56||"
   game "ebTestSet", "left", 0.1
   step 0.5
   TestAssert "the result waits", fieldText("Result Title") is "TIME!"
   step 5
   TestAssert "but not for ever: the last score seen decides", fieldText("Result Title") is "RIVAL WINS" and fieldText("Result Them") is "RIVAL   250"
end TestTheRivalsLastScoreNeverComes

on TestTheRivalLeaves
   local tArena
   put st("arena") into tArena
   game "ebTestDuel", 2
   step 3.5
   game "ebDuelReceive", "B"
   TestAssert "the rival gone: the match ends", st("mode") is "result" and fieldText("Result Title") is "RIVAL LEFT" and \
         fieldText("Result Note") is "Your rival left the duel."
   TestAssert "with no rematch to ask for", not the visible of button "Rematch" of card kCard of stack kStack
   press "Result Home"
   TestAssert "Leave goes to the title", st("mode") is "title" and st("duel") is false and not shown("Rival")
   newRun
   TestAssert "and a run after it is a run: lives, levels, the whole arena", st("lives") is 3 and st("shift") is 0 and \
         fieldText("Stage") is "LEVEL 1" and the visible of graphic "Life 1" of card kCard of stack kStack and st("arena") is tArena
end TestTheRivalLeaves

on TestLeavingADuel
   local tNow
   game "ebTestDuel", 2
   step 3.5
   press "Pause"
   TestAssert "a duel's pause", st("mode") is "pause" and fieldText("Paused Title") is "STILL PLAYING"
   TestAssert "has no restart", not the visible of button "Restart" of card kCard of stack kStack and \
         the label of button "Pause Home" of card kCard of stack kStack is "LEAVE THE DUEL"
   put st("now") into tNow
   step 1
   TestAssert "and the match goes on behind it", st("now") > tNow and st("left") < 179
   press "Resume"
   TestAssert "Resume", st("mode") is "play"
   press "Pause"
   get gameSays("ebDuelSent")
   press "Pause Home"
   TestAssert "leaving goes to the title", st("mode") is "title" and st("duel") is false
   newRun
   press "Pause"
   TestAssert "a run's pause has its buttons again", fieldText("Paused Title") is "PAUSED" and \
         the visible of button "Restart" of card kCard of stack kStack and the label of button "Pause Home" of card kCard of stack kStack is "HOME"
end TestLeavingADuel

on TestADuelFitsAPhoneAndAWindow
   local tSize, tArena, tCard, tName, tBad
   repeat for each item tSize in "390x760,320x480,844x390,900x640"
      set the itemDelimiter to "x"
      windowSize item 1 of tSize, item 2 of tSize
      put 0, 0, item 1 of tSize, item 2 of tSize into tCard
      set the itemDelimiter to comma
      if the width of stack kStack is not item 3 of tCard then
         TestSkip "a duel at" && tSize, "the window could not be made that size here"
         next repeat
      end if
      game "ebTestDuel", 2
      step 0.5
      put st("arena") into tArena
      put empty into tBad
      repeat for each item tName in "Score,Clock,Pause,Heat Text,Rival Arena,Rival Score"
         if not isInside(rectOf(tName), tCard) or overlap(rectOf(tName), tArena) then
            put tName & space after tBad
         end if
      end repeat
      TestAssert "a duel at" && tSize & ": the HUD and the rival's arena are on the window, off mine" && tBad, \
            tBad is empty and isInside(tArena, tCard)
      TestAssert "a duel at" && tSize & ": the rival's arena can be seen", the height of graphic "Rival Arena" of card kCard of stack kStack >= 70
      press "Pause"
      press "Pause Home"
   end repeat
end TestADuelFitsAPhoneAndAWindow
