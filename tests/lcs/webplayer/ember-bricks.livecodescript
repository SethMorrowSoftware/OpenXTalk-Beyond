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
-- the test says what the rival does with ebDuelReceive.

constant kStack = "Ember Bricks"
constant kCard = "Game"

local sSave

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
   local tLevels, tSounds, tFiles, tFile, tMissing, tSettings, tHandlers
   put url ("binfile:" & TestGetEngineRepositoryPath() & "/tools/web-player/ember-bricks/levels.txt") into tLevels
   TestAssert "the levels are read", tLevels is not empty
   TestAssert "the stack has the levels as their file has them", textDecode(tLevels, "UTF-8") is the cLevels of stack kStack
   put the customProperties["cSounds"] of stack kStack into tSounds
   put files(TestGetEngineRepositoryPath() & "/tools/web-player/ember-bricks/sounds") into tFiles
   filter tFiles with "*.wav"
   repeat for each line tFile in tFiles
      set the itemDelimiter to "."
      if char 1 to 4 of tSounds[item 1 of tFile] is not "RIFF" then
         put item 1 of tFile & space after tMissing
      end if
      set the itemDelimiter to comma
   end repeat
   TestAssert "every sound is in the stack, a WAV" && tMissing, tMissing is empty and the number of lines of tFiles is 27
   TestAssert "and no other", the number of elements of tSounds is 27
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
-- the HUD beside it (pWide) or over it, every screen's buttons on the
-- window and apart, every word whole
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
   if pWide then
      TestAssert tAt && "the HUD is beside the arena", st("wide") is true
   else
      TestAssert tAt && "the HUD is over the arena", st("wide") is false
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

on TestTheScreensFitAPhoneOnItsSide
   checkLayout 844, 390, true
   checkLayout 568, 320, true
   TestAssert "the score is beside the arena", item 3 of rectOf("Score") <= item 1 of st("arena")
end TestTheScreensFitAPhoneOnItsSide

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
   local tSdp, tCode, tSpaced, i
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
end TestACodeCarriesADescription

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
