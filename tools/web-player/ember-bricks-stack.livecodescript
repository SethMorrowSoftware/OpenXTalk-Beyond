script "Ember Bricks"
-- Ember Bricks: a brick-breaking game for a phone, a browser and a
-- desktop, made with OXT-Beyond. Built by
-- tools/web-player/ember-bricks.livecodescript in OXT-Beyond's repository,
-- from this script and the levels beside it; its sounds were made for it
-- (ember-bricks/make_assets.py) and its font is Atkinson Hyperlegible
-- (SIL Open Font License).
--
-- A ball, a paddle and a wall of bricks, and what this game adds to
-- them: the heat. Every brick broken heats the ball, and a hot ball is
-- worth up to five times as much; a ball that waits, or is lost, cools.
-- Some bricks drop sparks to catch (a wider paddle, more balls, a
-- fireball, bolts, a net) and dark ones to let fall. There are 24
-- levels, which come round again faster, and a duel for two over the
-- internet: each on their own wall, each seeing the other's, and a hot
-- streak on one side is trouble on the other. The two find each other
-- in a lobby (who is online, a challenge, a quick match, a room for a
-- friend), or swap two codes where there is none.
--
-- How it is made:
--   one card, "Game". The arena is 320 units wide and 480 high whatever
--     the window: everything in it (the ball, the paddle, the bricks'
--     grid of 10 by 14) is kept in those units and drawn times sS, the
--     points a unit takes, so the game plays the same on a phone held
--     upright (the HUD over the arena, room for a thumb under it), on one
--     on its side and in a desktop's window (the HUD at the arena's
--     sides). ebLayout places every control for the window's size
--   one loop: ebFrame, sent again after every frame, moves everything by
--     the time since the last one, so the game runs at the same speed at
--     25 frames a second as at 60. A ball moves in steps of at most 4
--     units, so it never passes through a brick
--   graphics, not pictures: a fixed set for each kind of thing, made by
--     the builder, shown and hidden, never created while the game plays.
--     What each is doing is kept here, in an array for each kind
--     (sBall[2]["x"] ...); the graphics only show it
--   messages from a finger: the browser and a phone make the first finger
--     the mouse, so a drag is mouseDown, the mouseLoc every frame, and
--     mouseUp
--
-- For the tests (tests/lcs/webplayer/ember-bricks.livecodescript), the
-- clock can be taken out of the loop's hands: ebTestBegin stops the loop
-- and fixes the random seed, ebTestStep moves the game on by so many
-- seconds, ebState says how things are, and ebTestLevel, ebTestBall and
-- ebTestDrop put things where a test wants them.

constant kFont = "Atkinson Hyperlegible"
constant kAmber = "#FFB52E"
constant kEmber = "#FF7A3D"
constant kInk = "#FFF6EC"
constant kDark = "#2A1606"
constant kMuted = "#C7B3A1"
constant kDim = "#6B5A50"
constant kGood = "#7CF29A"
constant kBad = "#FF5D73"
constant kCool = "#5CD6FF"
constant kPanel = "#2A1D18"
constant kBallColor = "#FFF3D6"
constant kSaveName = "ember-bricks.txt"

-- The arena, in units: its size, the bricks' grid (its top, and its
-- bottom, 14 rows down), the ball's radius, the paddle (its top, how
-- thick it is, and how wide: as it starts, with the wide spark, with the
-- dark one), and where the net is
constant kArenaW = 320
constant kArenaH = 480
constant kCols = 10
constant kRows = 14
constant kCells = 140
constant kCellW = 32
constant kCellH = 16
constant kGridTop = 48
constant kGridBottom = 272
constant kBallR = 5
constant kPadTop = 435
constant kPadH = 10
constant kPadNormal = 56
constant kPadWide = 86
constant kPadSmall = 38
constant kNetY = 468
-- the ball: the steepest it leaves the paddle's end (degrees from
-- straight up); its speed in units a second, at level 1, for each level
-- more, and at most; how much faster every 6 hits of the paddle, and at
-- most (times the level's speed)
constant kMaxAngle = 62
constant kSpeedBase = 235
constant kSpeedStep = 5
constant kSpeedMax = 330
constant kSpeedUp = 1.03
constant kSpeedTop = 1.25
-- the paddle on the keys (units a second), and how far it goes for a
-- finger's point (more, so that a thumb crosses the arena easily)
constant kKeySpeed = 420
constant kDragGain = 1.5
-- what falls and flies: a spark's speed and radius, a bolt's speed, and
-- the time between two bolts
constant kDropSpeed = 95
constant kDropR = 9
constant kBoltSpeed = 520
constant kBoltEvery = 0.32
-- how long each spark works, in seconds
constant kWideFor = 14
constant kSmallFor = 10
constant kBlazeFor = 7
constant kChillFor = 10
constant kFastFor = 8
constant kGripFor = 14
constant kBoltsFor = 9
-- a run: lives at the start and at most, the score that earns one more;
-- the heat: its most, the points of it for each step of the bonus, how
-- long it lasts without a brick, and how fast it then cools
constant kStartLives = 3
constant kMaxLives = 5
constant kLifeEvery = 20000
constant kMaxHeat = 16
constant kHeatStep = 4
constant kHeatHold = 2.2
constant kHeatCool = 0.6
-- the duel: its length in seconds, what a lost ball costs, and how long
-- before the next one
constant kDuelFor = 180
constant kDuelLoss = 150
constant kDuelWait = 1.2
-- its link: the version the two must share, the first letters of a
-- code, the public STUN server that tells each player its address as the
-- internet sees it, the seconds between two pictures of an arena, the
-- seconds of silence after which the rival is gone, how long the ways to
-- reach a player are waited for, and how long a code may take to make
-- and a link to open
constant kDuelVersion = 1
constant kDuelCode = "EB1"
-- (and the most characters a description in one can be)
constant kDuelMost = 60000
constant kDuelIce = "stun:stun.l.google.com:19302"
constant kDuelSend = 0.1
constant kDuelQuiet = 8
constant kDuelGather = 5
constant kDuelMakeFor = 25
constant kDuelLinkFor = 35
-- the lobby (see "The online lobby", below): the version its players
-- must share; the relays it is on when the stack names no others (its
-- cRelays); the kinds of its two messages (one that says who is here, one
-- to a single player), both of the kinds a relay passes on and is not
-- meant to keep; the seconds between two of a player's "I am here", how long one
-- stands, and how long one stands that says "in a duel"; how old by this
-- machine's clock a message may be and still be news (some relays keep
-- for a few minutes what they pass on, and give it to a newcomer; the two
-- minutes allow for clocks that disagree); how long a relay
-- is waited for (and the lobby is kept with none open); when a relay
-- that went is asked again, and when if it was the last (soon: well
-- before the lobby is given up), how many times, and how long one must
-- have stayed for its times to be counted afresh; how long a frame must
-- have been in coming for the page to have slept (which is no time a
-- relay was waited for); how long a challenge is waited for its answer
-- and a link for its opening;
-- how long a quick match leaves alone a player who would not link; the
-- rows of players the lobby shows, and on a phone on its side; and the
-- letters of a room's code (none that looks like another)
constant kNetVersion = 1
constant kNetRelays = "wss://nos.lol,wss://relay.damus.io,wss://nostr.mom"
constant kNetKindWho = 21043
constant kNetKindTell = 21044
constant kNetBeat = 20
constant kNetStale = 50
constant kNetOld = 120
constant kNetOpenFor = 12
constant kNetRetry = 15
constant kNetRetrySoon = 3
constant kNetTries = 3
constant kNetSteady = 60
constant kNetSlept = 2
constant kNetAskFor = 30
constant kNetLinkFor = 30
constant kNetAgain = 8
constant kNetRows = 5
constant kNetRowsShort = 3
constant kNetLetters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
constant kNetCodeLength = 6

-- whether the Mobile Web library is there; the screen showing (title,
-- howto, settings, levels, play, pause, clear, over, lobby, result);
-- where Settings and How to play go back to; the loop's next message;
-- whether a test holds the clock; the time of the last frame, in
-- milliseconds
local sLibrary, sMode, sBack, sHowtoThen, sLoop, sManual, sLast
-- the frames shown in the last second, and since when; how long a
-- frame's script took and how long its drawing, in milliseconds
local sFps, sFrames, sFpsFrom, sWork, sDraw
-- sClock runs in every screen (the banner, the floating words, the
-- embers); sNow only while a level plays, and every time of the game is
-- one of it
local sClock, sNow
-- where the game runs ("web", "mobile" or "desktop") and what points at
-- it ("touch" or "mouse")
local sPlatform, sPointer
-- the window: its size, the scale of the words (1 on a phone 390 points
-- wide), whether the HUD is at the arena's sides, the arena's left and
-- top and the points a unit takes, its rect, and what a notch or a bar
-- covers at each edge
local sW, sH, sUI, sWide, sAX, sAY, sS, sArena, sInT, sInB, sInL, sInR
-- the size the stack was built with, and how many frames have asked
-- whether the page has room for it (ebFitPage)
local sOwnW, sOwnH, sFitAsked
-- the controls' ids (sId["Ball"][3], sId["Paddle"]), how many of each
-- kind there are, the controls with words and the size of them, and
-- whether the arena is on the screen
local sId, sCount, sSized, sWorld
-- the levels (sLevels[3]["name"], ["rows"]) and how many
local sLevels, sLevelCount
-- the bricks, by cell (1 to 140, row by row): its kind (empty for none)
-- and the hits it still takes; how many are left to break; the look of
-- each kind; bombs' blasts on their way (the time of each, by cell)
local sBK, sBH, sRemaining, sLook, sBlast
-- the paddle: its middle, its width now and the width it is growing or
-- shrinking to, its look; a finger on the screen and where it was at the
-- last frame; where the mouse was
local sPadX, sPadW, sPadTarget, sPadLook, sDragging, sDragFrom, sMouseLast
-- the things that fly, by kind: each sBall[i] (and the others) is an
-- array, with "on" whether it is in play
local sBall, sDrop, sBolt, sSpark, sPop, sMote
-- the ball being moved: where it is and which way it goes (ebFlyBall and
-- the handlers it calls work on these)
local sX, sY, sDX, sDY
-- the run: the score, the lives, the level and the one the run began at,
-- the phase of the level ("serve", "live", "lost", "cleared", "dead")
-- and when it ends, the ball's speed and the level's, the paddle's hits,
-- the score of the next life, the level's seconds, and for the last
-- screen the bricks broken and the hottest the ball was
local sScore, sLives, sLevel, sStartLevel, sPhase, sPhaseAt, sSpeed, sLevelSpeed, sPadHits
local sNextLife, sLevelTime, sBricksRun, sTopHeat, sBrickAt
-- the heat, when it was last fed, and the bonus it gives (1 to 5)
local sHeat, sHeatAt, sMult
-- the sparks at work: the paddle's size ("normal", "wide", "small") and
-- until when; the ball's pace (1, slower, faster) and until when; the
-- fireball, the grip and the bolts, until when; the next bolt; the net
local sSize, sSizeUntil, sTempo, sTempoUntil, sBlazeUntil, sGripUntil, sBoltsUntil, sNextBolt, sNet
-- whether the balls look on fire; bricks broken since the last spark
-- fell; whether a test stopped them falling by chance
local sBlazeOn, sSinceDrop, sNoDrops
-- the banner, the flash, the score counting up at the end, and when
-- each sound last played
local sBannerUntil, sFlashUntil, sCountT, sCountTo, sSoundAt
-- what the HUD shows now, so that it is changed only when it changes
local sHud
-- kept between visits: the best score, the highest level open, the
-- settings, whether How to play was seen, and the number of runs (and
-- the name the player has in the lobby: sName, below)
local sBest, sUnlocked, sSound, sBuzz, sEffects, sSeenHowto, sPlays
-- another file for them (the tests'), how the sounds play ("web": the
-- browser's Web Audio, many at once; "files": the engine's play, or a
-- phone's channels; "none"), where their files are, the phone's next
-- channel, and whether the font was loaded
local sSaveFile, sAudio, sAudioDir, sChannel, sFontLoaded
-- the heat's bar and each chip's place, as the layout left them; a
-- test's insets; the rival's arena in a duel (its left, its top and the
-- points a unit takes there)
local sHeatBar, sChipRect, sFakeInsets, sRX, sRY, sRS
-- the duel (see "The duel", below): whether a match is on, the lobby's
-- step, the link and the match (sNet2["peer"], ["left"], ...), whether
-- DataChannelXT is here ("yes" or "no") and was used, and how far along
-- the list of levels a match's first wall is
local sDuel, sLobby, sNet2, sRtc, sRtcUsed, sShift
-- the lobby (see "The online lobby", below): whether NostrXT is here
-- ("yes" or "no"); the player's name, kept between visits; the code of a
-- friend's room that the page was opened with; relays in place of
-- kNetRelays (a test's); the lobby itself while the player is online
-- (sLob["on"], ["who"], ["room"], ...); whether a match that ends goes
-- back to it; and what a test's lobby would have sent
local sNostr, sName, sInvite, sRelays, sLob, sNetBack, sNetSent, sKey, sSeen, sSeenCount, sSaid
-- The table of the sum a code carries (ebDuelSum)
local sCrc

----------------------------------------------------------------------
-- Opening and closing

on preOpenStack
   ebInit
end preOpenStack

on closeStack
   ebStopLoop
   ebNetStop
   ebDuelClose
   put "closed" into sMode
   ebKeepAwake false
   if sLibrary then
      try
         mwStop
      end try
   end if
end closeStack

on resizeStack
   ebResized
   pass resizeStack
end resizeStack

-- Return in a field of the lobby is the step's main button: the name's
-- goes online, a room's code goes to the room. (In the box of a code to
-- paste it is a line break, as before.)
on returnInField
   set the defaultStack to the short name of me
   if sMode is "lobby" and sLobby is "start" then
      ebPress "Net Go"
   else if sMode is "lobby" and sLobby is "room-take" then
      ebPress "Code Go"
   else
      pass returnInField
   end if
end returnInField

on enterInField
   set the defaultStack to the short name of me
   if sMode is "lobby" and sLobby is "start" then
      ebPress "Net Go"
   else if sMode is "lobby" and sLobby is "room-take" then
      ebPress "Code Go"
   else
      pass enterInField
   end if
end enterInField

-- A phone that turns says so too; the stack has its new size by then
on orientationChanged
   ebResized
end orientationChanged

-- Another app in front, on a phone: the ball waits
on suspendStack
   ebPageHidden
   pass suspendStack
end suspendStack

-- Android's back button and gesture: out of a level to its pause, out of
-- a screen to the title, and from the title out of the game
on backKey
   set the defaultStack to the short name of me
   switch sMode
      case "play"
         ebPause
         break
      case "pause"
         ebResume
         break
      case "title"
         pass backKey
         break
      case "settings"
         ebSettingsBack
         break
      case "lobby"
      case "result"
         ebDuelLeave
         break
      default
         ebGoTitle
   end switch
end backKey

command ebInit
   local tError
   set the defaultStack to the short name of me
   put false into sManual
   put empty into sLoop
   put empty into sSaveFile
   put false into sNoDrops
   put false into sDuel
   put empty into sNet2
   put empty into sLobby
   put empty into sLob
   put false into sNetBack
   put empty into sInvite
   put empty into sRelays
   put 0 into sShift
   put false into sWorld
   put 0 into sClock
   put 0 into sNow
   put 0 into sFps
   put 0 into sWork
   put 0 into sDraw
   put 0 into sFrames
   put 0 into sChannel
   put empty into sSoundAt
   put the milliseconds into sFpsFrom
   put "title" into sMode
   if the platform is "HTML5" then
      put "web" into sPlatform
   else if the environment is "mobile" then
      put "mobile" into sPlatform
   else
      put "desktop" into sPlatform
   end if
   ebFindControls
   ebLoadFonts
   ebReadLevels
   ebMakeLooks
   ebLoad
   -- the library is in OXT-Beyond 0.2.7 and later; without it the game
   -- is a window that plays with the mouse and the keys. No gestures:
   -- the game reads the finger as the mouse
   -- (not the size the stack has now: the Stack Player opens it in its
   -- own window, and gives it its size after this)
   put item 1 of the cWindow of me into sOwnW
   put item 2 of the cWindow of me into sOwnH
   put 0 into sFitAsked
   put true into sLibrary
   try
      mwStart the short name of me, "none"
   catch tError
      put false into sLibrary
   end try
   put "mouse" into sPointer
   if sPlatform is "mobile" then
      put "touch" into sPointer
      try
         mobileSetAllowedOrientations "portrait,portrait upside down,landscape left,landscape right"
      end try
   else if sPlatform is "web" and sLibrary then
      try
         if mwPointer() is "touch" then
            put "touch" into sPointer
         end if
      end try
   end if
   ebAudioStart
   ebWatchPage
   lock screen
   ebResetRun
   ebShowWorld false
   put empty into sArena
   ebLayout
   ebGoTitle
   ebNetInvited
   unlock screen
end ebInit

-- The ids of the controls, once: the loop asks for a control by its id,
-- which is quicker than by its name. And every control with words, with
-- the size of them in a window 390 points wide (its cSize)
private command ebFindControls
   local tKind, i, tSize, tName
   put empty into sId
   put empty into sCount
   repeat for each item tKind in "Brick,Ball,Drop,Bolt,Spark,Pop,Mote,Life,Rival Brick,Rival Ball"
      put 0 into i
      repeat while there is a control (tKind && (i + 1))
         add 1 to i
         put the id of control (tKind && i) into sId[tKind][i]
      end repeat
      put i into sCount[tKind]
   end repeat
   put 0 into i
   repeat while there is a graphic ("Chip" && (i + 1) && "Back")
      add 1 to i
      put the id of graphic ("Chip" && i && "Back") into sId["Chip Back"][i]
      put the id of graphic ("Chip" && i && "Fill") into sId["Chip Fill"][i]
      put the id of field ("Chip" && i && "Text") into sId["Chip Text"][i]
   end repeat
   put i into sCount["Chip"]
   repeat for each item tName in "Arena,Walls,Net,Paddle,Cannon 1,Cannon 2,Hint,Flash,Score,Stage,Stage Name,Heat Text,Heat Back,Heat Fill,Clock,Rival Arena,Rival Paddle,Rival Name,Rival Score"
      put the id of control tName into sId[tName]
   end repeat
   put empty into sSized
   repeat with i = 1 to the number of controls
      put the cSize of control i into tSize
      if tSize is a number then
         put tSize into sSized[the id of control i]
      end if
   end repeat
end ebFindControls

-- Atkinson Hyperlegible, from the stack (without it, the stack's own
-- font): its two faces, regular and bold
private command ebLoadFonts
   local tData, tFile, tFace
   if sFontLoaded is true then
      exit ebLoadFonts
   end if
   repeat for each item tFace in "Regular,Bold"
      if tFace is "Regular" then
         put the cFontRegular of me into tData
      else
         put the cFontBold of me into tData
      end if
      if tData is empty then
         next repeat
      end if
      put specialFolderPath("temporary") & "/ember-bricks-atkinson-" & toLower(tFace) & ".ttf" into tFile
      try
         put tData into url ("binfile:" & tFile)
         start using font file tFile
         if the result is empty then
            put true into sFontLoaded
         end if
      end try
   end repeat
   if sFontLoaded is not true then
      put kFont is among the lines of the fontNames into sFontLoaded
   end if
end ebLoadFonts

-- The levels, from the stack's cLevels (levels.txt as it is): a line
-- "= Name", then the level's rows
private command ebReadLevels
   local tLine, tCount
   put empty into sLevels
   put 0 into tCount
   repeat for each line tLine in the cLevels of me
      if char 1 of tLine is "#" then
         next repeat
      end if
      if char 1 to 2 of tLine is "= " then
         add 1 to tCount
         put word 2 to -1 of tLine into sLevels[tCount]["name"]
         put empty into sLevels[tCount]["rows"]
      else if word 1 of tLine is not empty and tCount > 0 then
         put word 1 of tLine & return after sLevels[tCount]["rows"]
      end if
   end repeat
   put tCount into sLevelCount
end ebReadLevels

-- How each kind of brick looks: its colour (and the gradient made of
-- it, light over dark), its rim and the colour of that, and its mark.
-- 1 to 7 are the colours; M1, M2 and M3 a tough or armoured brick with
-- that many hits to go (the lighter, the nearer to breaking); X steel,
-- B a bomb, E an ember
private command ebMakeLooks
   local i, tColors
   put empty into sLook
   put "#FF5D5D,#FF9F43,#FFD166,#6EE7A0,#5CD6FF,#6C8CFF,#B388FF" into tColors
   repeat with i = 1 to 7
      ebLook i, item i of tColors, 0, kDark, empty
   end repeat
   ebLook "M1", "#CDD6E4", 1, "#F6F8FC", empty
   ebLook "M2", "#8C9AB8", 1, "#DCE3EE", empty
   ebLook "M3", "#5B6B8C", 1, "#B4C0D6", empty
   ebLook "X", "#3B4350", 2, "#7C8696", empty
   ebLook "B", "#34140F", 2, kEmber, "*"
   ebLook "E", "#FFD98A", 0, kDark, "+"
end ebMakeLooks

private command ebLook pCode, pColor, pLine, pInk, pMark
   put pColor into sLook[pCode]["color"]
   put ebRamp(pColor) into sLook[pCode]["ramp"]
   put pLine into sLook[pCode]["line"]
   put pInk into sLook[pCode]["ink"]
   put pMark into sLook[pCode]["mark"]
end ebLook

-- A gradient's colours for a brick of pColor: lighter at its top, darker
-- at its bottom
private function ebRamp pColor
   local tR, tG, tB
   put baseConvert(char 2 to 3 of pColor, 16, 10) into tR
   put baseConvert(char 4 to 5 of pColor, 16, 10) into tG
   put baseConvert(char 6 to 7 of pColor, 16, 10) into tB
   return "0.00000," & ebMix(tR, 255, 0.45) & comma & ebMix(tG, 255, 0.45) & comma & ebMix(tB, 255, 0.45) & return & \
         "0.45000," & tR & comma & tG & comma & tB & return & \
         "1.00000," & ebMix(tR, 0, 0.3) & comma & ebMix(tG, 0, 0.3) & comma & ebMix(tB, 0, 0.3)
end ebRamp

private function ebMix pFrom, pTo, pShare
   return round(pFrom + (pTo - pFrom) * pShare)
end ebMix

----------------------------------------------------------------------
-- Kept between visits. In a browser, the documents folder is the page's
-- own storage; on a phone, the app's; on a desktop, a folder for this
-- game where the system keeps such things.

private function ebSavePath
   local tFolder, tBase
   if sSaveFile is not empty then
      return sSaveFile
   end if
   if sPlatform is not "desktop" then
      return specialFolderPath("documents") & "/" & kSaveName
   end if
   try
      if the platform is "Win32" then
         put specialFolderPath("support") into tBase
      else if the platform is "MacOS" then
         put specialFolderPath("preferences") into tBase
      else
         put specialFolderPath("home") & "/.config" into tBase
         if there is not a folder tBase then
            create folder tBase
         end if
      end if
      if tBase is not empty then
         put tBase & "/oxt-ember-bricks" into tFolder
         if there is not a folder tFolder then
            create folder tFolder
         end if
      end if
   end try
   if tFolder is empty or there is not a folder tFolder then
      put specialFolderPath("temporary") & "/oxt-ember-bricks" into tFolder
      if there is not a folder tFolder then
         create folder tFolder
      end if
   end if
   return tFolder & "/" & kSaveName
end ebSavePath

command ebLoad
   local tText, tLine, tKey, tValue
   put 0 into sBest
   put 1 into sUnlocked
   put 0 into sPlays
   put true into sSound
   put true into sBuzz
   put "full" into sEffects
   put false into sSeenHowto
   put empty into sName
   try
      put url ("file:" & ebSavePath()) into tText
   end try
   set the itemDelimiter to "="
   repeat for each line tLine in tText
      put item 1 of tLine into tKey
      put item 2 of tLine into tValue
      switch tKey
         case "best"
            if tValue is an integer then
               put max(0, tValue) into sBest
            end if
            break
         case "plays"
            if tValue is an integer then
               put max(0, tValue) into sPlays
            end if
            break
         case "unlocked"
            if tValue is an integer then
               put max(1, min(sLevelCount, tValue)) into sUnlocked
            end if
            break
         case "sound"
            put tValue is not "false" into sSound
            break
         case "buzz"
            put tValue is not "false" into sBuzz
            break
         case "effects"
            if tValue is "lite" then
               put "lite" into sEffects
            end if
            break
         case "howto"
            put tValue is "true" into sSeenHowto
            break
         case "name"
            put ebNetName(tValue) into sName
            break
      end switch
   end repeat
   set the itemDelimiter to comma
end ebLoad

command ebSave
   local tText
   put "best=" & sBest & return & "unlocked=" & sUnlocked & return & "plays=" & sPlays & return & \
         "sound=" & sSound & return & "buzz=" & sBuzz & return & "effects=" & sEffects & return & \
         "howto=" & sSeenHowto & return into tText
   if sName is not empty then
      put "name=" & sName & return after tText
   end if
   try
      put tText into url ("file:" & ebSavePath())
   end try
end ebSave

----------------------------------------------------------------------
-- Sound. The engine plays one sound at a time, in a browser too, and a
-- wall of bricks makes many at once: in a browser they go to its Web
-- Audio, which mixes them, and on a phone to four channels in turn. A
-- page may only make a sound once it has been touched (or clicked, or a
-- key pressed), so the first touch wakes it.

private command ebAudioStart
   local tSounds, tName, tData
   put "none" into sAudio
   put the customProperties["cSounds"] of me into tSounds
   if the keys of tSounds is empty then
      exit ebAudioStart
   end if
   if sPlatform is "web" then
      try
         do ebAudioScript() as "JavaScript"
         repeat for each key tName in tSounds
            put base64Encode(tSounds[tName]) into tData
            replace return with empty in tData
            do "window.ebAudio.add('" & tName & "','" & tData & "');" as "JavaScript"
         end repeat
         put "web" into sAudio
      end try
   else
      -- written to files when the first sound plays
      put "files" into sAudio
      put empty into sAudioDir
   end if
end ebAudioStart

-- The mixer, made once a page: ebAudio.add(name, base64 of a WAV),
-- ebAudio.play(name, volume). The same sound is not started twice in 40
-- milliseconds (two balls on two bricks say one click).
private function ebAudioScript
   return "(function(){if(window.ebAudio)return;" & \
         "var C=window.AudioContext||window.webkitAudioContext;" & \
         "var A=window.ebAudio={c:null,raw:{},buf:{},last:{}};" & \
         "A.decode=function(n){var c=A.c;if(!c||A.buf[n]||!A.raw[n])return;A.buf[n]='wait';" & \
         "var s=atob(A.raw[n]),u=new Uint8Array(s.length);for(var i=0;i<s.length;i++)u[i]=s.charCodeAt(i);" & \
         "var ok=function(b){A.buf[n]=b;},no=function(){A.buf[n]=null;};" & \
         "try{var p=c.decodeAudioData(u.buffer,ok,no);if(p&&p.catch)p.catch(no);}catch(e){no();}};" & \
         "A.add=function(n,d){A.raw[n]=d;A.decode(n);};" & \
         "A.unlock=function(){if(!C)return;if(!A.c){try{A.c=new C();}catch(e){return;}}" & \
         "if(A.c.state==='suspended')A.c.resume();for(var n in A.raw)A.decode(n);};" & \
         "['touchend','pointerup','mousedown','keydown'].forEach(function(e){window.addEventListener(e,A.unlock,true);});" & \
         "A.play=function(n,v){var c=A.c,b=A.buf[n];if(!c||c.state!=='running'||!b||b==='wait')return;" & \
         "var t=c.currentTime;if(A.last[n]&&t-A.last[n]<0.04)return;A.last[n]=t;" & \
         "var s=c.createBufferSource(),g=c.createGain();s.buffer=b;g.gain.value=v;" & \
         "s.connect(g);g.connect(c.destination);s.start(0);};})();"
end ebAudioScript

command ebSound pName, pVolume
   local tSounds, tName
   if sSound is not true or sAudio is "none" then
      exit ebSound
   end if
   -- (not the same sound twice in a frame or two: each is a call out of
   -- the engine)
   if sSoundAt[pName] is a number then
      if sClock - sSoundAt[pName] < 0.04 and sClock >= sSoundAt[pName] then
         exit ebSound
      end if
   end if
   put sClock into sSoundAt[pName]
   if sAudio is "web" then
      try
         do "window.ebAudio.play('" & pName & "'," & pVolume & ");" as "JavaScript"
      end try
      exit ebSound
   end if
   -- (a desktop plays one sound at a time: the walls' ticks would stop
   -- every other sound)
   if sPlatform is "desktop" and pName is "wall" then
      exit ebSound
   end if
   try
      if sAudioDir is empty then
         put specialFolderPath("temporary") & "/oxt-ember-bricks-sounds" into sAudioDir
         if there is not a folder sAudioDir then
            create folder sAudioDir
         end if
         put the customProperties["cSounds"] of me into tSounds
         repeat for each key tName in tSounds
            put tSounds[tName] into url ("binfile:" & sAudioDir & "/" & tName & ".wav")
         end repeat
      end if
      if sPlatform is "mobile" then
         put sChannel mod 4 + 1 into sChannel
         mobilePlaySoundOnChannel (sAudioDir & "/" & pName & ".wav"), ("eb" & sChannel), "now"
      else
         play (sAudioDir & "/" & pName & ".wav")
      end if
   catch tName
      put "none" into sAudio
   end try
end ebSound

-- A buzz, on a phone that can (not an iPhone's browser)
private command ebBuzz pMilliseconds
   if sBuzz is not true then
      exit ebBuzz
   end if
   try
      if sPlatform is "mobile" then
         mobileVibrate 1
      else if sLibrary then
         mwVibrate pMilliseconds
      end if
   end try
end ebBuzz

-- The screen kept on while a level plays (in a browser, in a page served
-- over https)
private command ebKeepAwake pOn
   try
      if sPlatform is "mobile" then
         if pOn then
            mobileLockIdleTimer
         else
            mobileUnlockIdleTimer
         end if
      else if sPlatform is "web" and sLibrary then
         mwKeepAwake pOn
      end if
   end try
end ebKeepAwake

-- The page tells the stack when it is hidden (another app, another tab,
-- the phone locked), through ebPageHidden, one of the stack's
-- cJavascriptHandlers: a ball never flies on behind it. (The loop also
-- pauses a level that it finds was not given a frame for half a second.)
private command ebWatchPage
   if sPlatform is not "web" then
      exit ebWatchPage
   end if
   try
      do "(function(){if(window.ebPageWatch)return;window.ebPageWatch=1;" & \
            "document.addEventListener('visibilitychange',function(){if(!document.hidden)return;" & \
            "try{var s=document.liveCode.findStackWithName('" & the short name of me & "');" & \
            "if(s&&s.ebPageHidden)s.ebPageHidden();}catch(e){}});})();" as "JavaScript"
   end try
end ebWatchPage

on ebPageHidden
   set the defaultStack to the short name of me
   if sMode is "play" then
      ebPause
   end if
end ebPageHidden

-- On a desktop's page the Stack Player shows a stack at its own size,
-- whatever the browser window's. (Only a phone's page, or one opened
-- with ?fill=yes, is the stack's: the Mobile Web library keeps the stack
-- as big as that one, and marks it.) A window smaller than the stack
-- would cut the game off at its edges, so the game, which lays itself
-- out for any size, takes the window's size while that is the smaller,
-- and the size it was built with again when there is room. Asked in the
-- first frames and then once a second.
private command ebFitPage
   local tSize, tW, tH, tRect, tError
   if sPlatform is not "web" or sOwnW is not a number or sOwnH is not a number then
      exit ebFitPage
   end if
   try
      do "document.documentElement.getAttribute('data-mobile-web-filled')?'':(window.innerWidth+','+window.innerHeight)" as "JavaScript"
      put the result into tSize
   catch tError
      exit ebFitPage
   end try
   if the number of items of tSize is not 2 then
      exit ebFitPage
   end if
   if item 1 of tSize is not a number or item 2 of tSize is not a number then
      exit ebFitPage
   end if
   put max(320, min(sOwnW, round(item 1 of tSize))) into tW
   put max(320, min(sOwnH, round(item 2 of tSize))) into tH
   if tW is the width of me and tH is the height of me then
      exit ebFitPage
   end if
   put the rect of me into tRect
   set the rect of me to item 1 of tRect, item 2 of tRect, item 1 of tRect + tW, item 2 of tRect + tH
   if sW is a number and (sW is not the width of me or sH is not the height of me) then
      ebResized
   end if
end ebFitPage

----------------------------------------------------------------------
-- The loop
--
-- The engine draws the window again after every statement that changed
-- what it shows, unless the screen is locked; and on a phone each
-- drawing waits for the screen's next frame, a sixtieth of a second. A
-- level begun with the screen unlocked was a hundred drawings and more
-- (each brick as it appeared, each ember as it went): well over a second
-- with nothing to do but watch, where a desktop shows nothing of it. So
-- whatever comes into the game locks the screen for what it changes, and
-- there is one drawing of it: a frame (ebFrame), a button (ebPress), a
-- key or Android's back button (through ebPause, ebResume, ebLaunch,
-- ebGoTitle and ebDuelLeave), what was pasted (ebPasted), a window of
-- another size (ebLayout), and the tests' hands on the game. A lock
-- inside a lock only counts, so each of these can call the others.
-- tools/ci/tests/test_ember_bricks.py holds the game to it.

private command ebSchedule
   if sManual or sLoop is not empty or sMode is "closed" then
      exit ebSchedule
   end if
   if sMode is "pause" and not sDuel then
      exit ebSchedule
   end if
   if sMode is "play" or sDuel then
      send "ebFrame" to me in 10 milliseconds
   else
      -- the screens move little: fewer frames, less battery
      send "ebFrame" to me in 30 milliseconds
   end if
   put the result into sLoop
end ebSchedule

private command ebStopLoop
   if sLoop is not empty then
      cancel sLoop
      put empty into sLoop
   end if
end ebStopLoop

on ebFrame
   local tNow, tDt
   put empty into sLoop
   if sManual or sMode is "closed" then
      exit ebFrame
   end if
   set the defaultStack to the short name of me
   put the milliseconds into tNow
   put (tNow - sLast) / 1000 into tDt
   put tNow into sLast
   if tDt > 0.5 and sMode is "play" and not sDuel then
      -- no frame for half a second: the page was hidden, or the
      -- computer slept
      ebPause
      exit ebFrame
   end if
   add 1 to sFrames
   if tNow - sFpsFrom >= 1000 then
      put round(sFrames * 1000 / (tNow - sFpsFrom)) into sFps
      put 0 into sFrames
      put tNow into sFpsFrom
      ebFitPage
   else if sFitAsked < 3 then
      -- (and at once as the game opens)
      add 1 to sFitAsked
      ebFitPage
   end if
   lock screen
   ebAdvance max(0, min(tDt, 0.05)), tDt
   put sWork * 0.95 + (the milliseconds - tNow) * 0.05 into sWork
   put the milliseconds into tNow
   unlock screen
   put sDraw * 0.95 + (the milliseconds - tNow) * 0.05 into sDraw
   ebSchedule
end ebFrame

-- The game, pDt seconds on. pReal is the time that really passed (a
-- duel's clock runs on it: a slow frame costs no time of the match)
command ebAdvance pDt, pReal
   if pReal is empty then
      put pDt into pReal
   end if
   add pDt to sClock
   if sNet2["on"] is true then
      ebDuelStep pReal
   end if
   if sLob["on"] is true then
      ebNetStep pReal
   end if
   switch sMode
      case "play"
         add pDt to sNow
         ebPlayStep pDt
         break
      case "pause"
         if sDuel then
            -- (a duel does not wait)
            add pDt to sNow
            ebPlayStep pDt
         end if
         break
      case "over"
      case "clear"
         ebCountUp pDt
         break
   end switch
   if not sWorld then
      ebMoveMotes pDt
   end if
   ebMoveSparks pDt
   ebMovePops pDt
   if sBannerUntil is a number then
      if sClock >= sBannerUntil then
         set the visible of group "Banner" to false
         put empty into sBannerUntil
      end if
   end if
   if sFlashUntil is a number then
      if sClock >= sFlashUntil then
         set the visible of graphic id sId["Flash"] to false
         put empty into sFlashUntil
      end if
   end if
end ebAdvance

-- A level, pDt seconds on
private command ebPlayStep pDt
   ebSteer pDt
   switch sPhase
      case "serve"
      case "live"
         if sPhase is "live" then
            add pDt to sLevelTime
         end if
         ebEffects pDt
         ebMoveBalls pDt
         ebMoveDrops pDt
         ebMoveBolts pDt
         ebBlasts
         if sRemaining <= 0 and sPhase is not "lost" and sPhase is not "dead" and the keys of sBlast is empty then
            ebLevelCleared
         end if
         break
      case "lost"
         ebMoveDrops pDt
         ebBlasts
         if sNow >= sPhaseAt then
            ebServe
         end if
         break
      case "cleared"
         if sNow >= sPhaseAt then
            if sDuel then
               ebStartLevel sLevel + 1
            else
               ebShowClear
            end if
         end if
         break
      case "dead"
         if sNow >= sPhaseAt then
            ebShowOver
         end if
         break
   end switch
   ebDrawPaddle
   ebHud
end ebPlayStep

----------------------------------------------------------------------
-- Screens

command ebShowScreen pName
   local tPanel
   lock screen
   put pName is among the items of "howto,settings,levels,pause,clear,over,lobby,result" into tPanel
   set the visible of group "Title" to (pName is "title")
   set the visible of group "Howto" to (pName is "howto")
   set the visible of group "Settings" to (pName is "settings")
   set the visible of group "Levels" to (pName is "levels")
   set the visible of group "Paused" to (pName is "pause")
   set the visible of group "Clear" to (pName is "clear")
   set the visible of group "Over" to (pName is "over")
   set the visible of group "Lobby" to (pName is "lobby")
   set the visible of group "Result" to (pName is "result")
   set the visible of graphic "Shade" to (tPanel and sWorld)
   set the visible of group "HUD" to sWorld
   set the visible of group "Rival" to (sWorld and sDuel)
   if pName is not "play" then
      set the visible of field id sId["Hint"] to false
   end if
   unlock screen
end ebShowScreen

-- The arena on the screen, or (pOn false) everything of it put away and
-- the embers drifting instead
command ebShowWorld pOn
   local i
   put pOn into sWorld
   set the visible of graphic id sId["Arena"] to pOn
   set the visible of graphic id sId["Walls"] to pOn
   if not pOn then
      ebClearThings
      repeat with i = 1 to kCells
         put empty into sBK[i]
         set the visible of graphic id sId["Brick"][i] to false
      end repeat
      set the visible of graphic id sId["Paddle"] to false
      set the visible of field id sId["Hint"] to false
      set the visible of group "Banner" to false
      put empty into sBannerUntil
   end if
   repeat with i = 1 to sCount["Mote"]
      set the visible of graphic id sId["Mote"][i] to not pOn
   end repeat
end ebShowWorld

command ebGoTitle
   lock screen
   put "title" into sMode
   put false into sDragging
   ebKeepAwake false
   ebShowWorld false
   set the text of field "Records" to ebRecords()
   ebShowScreen "title"
   unlock screen
   put the milliseconds into sLast
   ebSchedule
end ebGoTitle

private function ebRecords
   if sBest > 0 then
      return "BEST" && ebCommas(sBest) & "     LEVEL" && sUnlocked && "OF" && sLevelCount
   end if
   return sLevelCount && "LEVELS"
end ebRecords

command ebPressPlay
   if not sSeenHowto then
      put "play" into sHowtoThen
      ebShowHowto
   else
      ebNewRun 1
   end if
end ebPressPlay

private command ebShowHowto
   put "howto" into sMode
   if sHowtoThen is "play" then
      set the label of button "Howto Go" to "PLAY"
   else
      set the label of button "Howto Go" to "GOT IT"
   end if
   ebShowScreen "howto"
end ebShowHowto

private command ebShowSettings pFrom
   put pFrom into sBack
   put "settings" into sMode
   set the text of field "Settings Note" to empty
   ebSettingsLook
   ebShowScreen "settings"
end ebShowSettings

command ebSettingsBack
   if sBack is "pause" then
      put "pause" into sMode
      ebShowScreen "pause"
   else
      ebGoTitle
   end if
end ebSettingsBack

private command ebSettingsLook
   local tFull
   if sSound then
      set the label of button "Sound" to "SOUND: ON"
   else
      set the label of button "Sound" to "SOUND: OFF"
   end if
   if sBuzz then
      set the label of button "Buzz" to "BUZZ: ON"
   else
      set the label of button "Buzz" to "BUZZ: OFF"
   end if
   if sEffects is "lite" then
      set the label of button "Effects" to "EFFECTS: LITE"
   else
      set the label of button "Effects" to "EFFECTS: FULL"
   end if
   put false into tFull
   if sPlatform is "web" and sLibrary then
      try
         put mwIsFullScreen() into tFull
      end try
   else if sPlatform is "desktop" then
      put the fullscreen of me into tFull
   end if
   if tFull is true then
      set the label of button "Full" to "FULL SCREEN: ON"
   else
      set the label of button "Full" to "FULL SCREEN: OFF"
   end if
end ebSettingsLook

-- The levels: those reached can be played, the others are dim
private command ebShowLevels
   local i
   put "levels" into sMode
   repeat with i = 1 to sLevelCount
      if i <= sUnlocked then
         set the textColor of button ("Level" && i) to kInk
         set the foregroundColor of graphic ("Level" && i && "Shape") to "#8A5A3C"
      else
         set the textColor of button ("Level" && i) to kDim
         set the foregroundColor of graphic ("Level" && i && "Shape") to "#3D2B22"
      end if
   end repeat
   if sUnlocked >= sLevelCount then
      set the text of field "Levels Note" to "Every level is open."
   else
      set the text of field "Levels Note" to "Clear a level to open the next."
   end if
   ebShowScreen "levels"
end ebShowLevels

-- A button of the screens, pressed (pDown) or let go
command ebButtonLook pName, pDown
   local tShape
   put pName && "Shape" into tShape
   if there is not a graphic tShape then
      exit ebButtonLook
   end if
   if pDown then
      set the backgroundColor of graphic tShape to the cDown of graphic tShape
   else
      set the backgroundColor of graphic tShape to the cUp of graphic tShape
   end if
end ebButtonLook

-- A button of the screens is pressed: what it does, and one drawing of
-- all that it changed
command ebPress pName
   set the defaultStack to the short name of me
   ebSound "click", 0.5
   lock screen
   ebPressed pName
   unlock screen
end ebPress

-- What each button of the screens does
private command ebPressed pName
   local tResult, tLevel
   if word 1 of pName is "Level" and word 2 of pName is an integer then
      put word 2 of pName into tLevel
      if tLevel <= sUnlocked then
         ebNewRun tLevel
      else
         set the text of field "Levels Note" to "Clear level" && sUnlocked && "to go on."
      end if
      exit ebPressed
   end if
   -- (a player in the lobby's list)
   if word 1 of pName is "Who" and word 2 of pName is an integer then
      ebNetChallenge word 2 of pName
      exit ebPressed
   end if
   switch pName
      case "Play"
         ebPressPlay
         break
      case "Levels Open"
         ebShowLevels
         break
      case "Levels Back"
         ebGoTitle
         break
      case "Howto Open"
         put "title" into sHowtoThen
         ebShowHowto
         break
      case "Howto Go"
         if not sSeenHowto then
            put true into sSeenHowto
            ebSave
         end if
         if sHowtoThen is "play" then
            ebNewRun 1
         else
            ebGoTitle
         end if
         break
      case "Settings Open"
         ebShowSettings "title"
         break
      case "Pause"
         ebPause
         break
      case "Resume"
         ebResume
         break
      case "Restart"
      case "Again"
         ebNewRun sStartLevel
         break
      case "Pause Settings"
         ebShowSettings "pause"
         break
      case "Pause Home"
         if sDuel then
            ebDuelLeave
         else
            ebGoTitle
         end if
         break
      case "Over Home"
         ebGoTitle
         break
      case "Next"
         ebNextLevel
         break
      case "Settings Back"
         ebSettingsBack
         break
      case "Sound"
         put not sSound into sSound
         ebSave
         ebSettingsLook
         ebSound "click", 0.5
         break
      case "Buzz"
         put not sBuzz into sBuzz
         ebSave
         ebSettingsLook
         ebBuzz 40
         break
      case "Effects"
         if sEffects is "lite" then
            put "full" into sEffects
            set the text of field "Settings Note" to "Bricks with a sheen, and more sparks off them."
         else
            put "lite" into sEffects
            set the text of field "Settings Note" to "Plain bricks and fewer sparks: easier on a slow phone."
         end if
         ebSave
         ebSettingsLook
         ebBrickLooks
         break
      case "Full"
         ebToggleFull
         ebSettingsLook
         break
      case "Duel Open"
         ebDuelOpen
         break
      case "Host"
      case "Join"
      case "Code Copy"
      case "Code Paste"
      case "Code Go"
      case "Lobby Back"
      case "Rematch"
      case "Result Home"
      case "Net Go"
      case "Codes Open"
      case "Quick"
      case "Friend"
      case "Accept"
      case "Decline"
         ebDuelPress pName
         break
   end switch
end ebPressed

-- The whole screen: a browser's, or a desktop's (a phone's app has it)
private command ebToggleFull
   local tResult
   if sPlatform is "web" then
      if sLibrary then
         try
            mwFullScreen not mwIsFullScreen()
            put the result into tResult
         catch tResult
         end try
         if tResult is not empty then
            set the text of field "Settings Note" to "This browser cannot hide its bars. On an iPhone, add the page to the home screen."
         end if
      end if
   else if sPlatform is "desktop" then
      set the fullscreen of me to not the fullscreen of me
   else
      set the text of field "Settings Note" to "The game already has the whole screen."
   end if
end ebToggleFull

-- The keys: P or Escape pauses and goes on; Space or Return sends the
-- ball off, or presses the screen's main button
on rawKeyDown pKey
   set the defaultStack to the short name of me
   -- (typing in the lobby's field is typing)
   if sMode is "lobby" and word 1 of the focusedObject is "field" then
      pass rawKeyDown
   end if
   switch pKey
      case 112
      case 80
      case 65307
         if sMode is "play" then
            ebPause
         else if sMode is "pause" then
            ebResume
         else
            pass rawKeyDown
         end if
         break
      case 32
      case 65293
      case 65421
         switch sMode
            case "title"
               ebPress "Play"
               break
            case "over"
               ebPress "Again"
               break
            case "clear"
               ebPress "Next"
               break
            case "pause"
               ebPress "Resume"
               break
            case "howto"
               ebPress "Howto Go"
               break
            case "play"
               ebLaunch
               break
            default
               pass rawKeyDown
         end switch
         break
      default
         pass rawKeyDown
   end switch
end rawKeyDown

-- (the arrows move the paddle, read every frame: they do not change the
-- card)
on arrowKey pDirection
end arrowKey

-- A finger (or the mouse) down anywhere but on a button: in a level, the
-- paddle moves as it moves, and letting go sends a waiting ball off
on mouseDown
   ebFingerDown
end mouseDown

on mouseDoubleDown
   ebFingerDown
end mouseDoubleDown

on mouseUp
   ebFingerUp
end mouseUp

on mouseDoubleUp
   ebFingerUp
end mouseDoubleUp

on mouseRelease
   ebFingerUp
end mouseRelease

private command ebFingerDown
   set the defaultStack to the short name of me
   if sMode is "play" then
      put true into sDragging
      put the mouseLoc into sDragFrom
   end if
end ebFingerDown

private command ebFingerUp
   set the defaultStack to the short name of me
   if sDragging and sMode is "play" then
      put false into sDragging
      ebLaunch
   end if
   put false into sDragging
end ebFingerUp

----------------------------------------------------------------------
-- A run, and its levels

-- Nothing of a run left over (before the first, and for the tests)
private command ebResetRun
   put 0 into sScore
   put kStartLives into sLives
   put 1 into sLevel
   put 1 into sStartLevel
   put empty into sPhase
   put 0 into sPhaseAt
   put kSpeedBase into sSpeed
   put kSpeedBase into sLevelSpeed
   put kLifeEvery into sNextLife
   put 0 into sLevelTime
   put 0 into sBricksRun
   put 1 into sTopHeat
   put 0 into sBrickAt
   put 0 into sRemaining
   put empty into sBlast
   put empty into sHud
   put kArenaW / 2 into sPadX
   put kPadNormal into sPadW
   put kPadNormal into sPadTarget
   put empty into sPadLook
   put false into sDragging
   put empty into sMouseLast
   put empty into sBannerUntil
   put empty into sFlashUntil
   put empty into sCountT
   ebResetEffects
end ebResetRun

-- A run from level pLevel: three lives, no score
command ebNewRun pLevel
   set the defaultStack to the short name of me
   if pLevel is not an integer or pLevel < 1 then
      put 1 into pLevel
   end if
   ebStopLoop
   -- (one drawing of the arena and its wall, not one of each brick)
   lock screen
   ebResetRun
   put pLevel into sStartLevel
   put 0 into sNow
   add 1 to sPlays
   if not sDuel then
      ebSave
   end if
   put "play" into sMode
   ebShowWorld true
   ebStartLevel pLevel
   ebShowScreen "play"
   -- (the run's first picture is its own: no frame has drawn it yet)
   ebDrawAll
   unlock screen
   ebKeepAwake true
   put the milliseconds into sLast
   ebSchedule
end ebNewRun

-- Level pLevel begins: its bricks, a ball on the paddle
command ebStartLevel pLevel
   local tIndex, tLap
   lock screen
   put pLevel into sLevel
   ebClearThings
   ebResetEffects
   ebLoadLevel
   put ebLevelIndex() into tIndex
   put (sLevel - 1) div sLevelCount into tLap
   put min(kSpeedMax, kSpeedBase + kSpeedStep * ((sLevel - 1) mod sLevelCount)) * (1 + 0.08 * tLap) into sLevelSpeed
   put 0 into sLevelTime
   put sNow into sBrickAt
   put empty into sHud
   ebServe
   if sDuel then
      ebBanner "WALL" && sLevel, sLevels[tIndex]["name"], 1.2
   else if tLap > 0 then
      ebBanner "LEVEL" && sLevel, sLevels[tIndex]["name"] & ", faster", 1.8
   else
      ebBanner "LEVEL" && sLevel, sLevels[tIndex]["name"], 1.8
   end if
   unlock screen
end ebStartLevel

-- Which of the levels the one being played is: they come round again
-- after the last, and a duel begins anywhere in them (sShift)
private function ebLevelIndex
   return (sLevel - 1 + sShift) mod sLevelCount + 1
end ebLevelIndex

-- The level's bricks, from its rows. The second time round and after,
-- some of the plain ones are tough
private command ebLoadLevel
   local tIndex, tLap, tRows, tRow, tCol, tCell, tCode, tLine
   put ebLevelIndex() into tIndex
   put (sLevel - 1) div sLevelCount into tLap
   put sLevels[tIndex]["rows"] into tRows
   put empty into sBK
   put empty into sBH
   put empty into sBlast
   put 0 into sRemaining
   put 0 into tRow
   repeat for each line tLine in tRows
      add 1 to tRow
      if tRow > kRows then
         exit repeat
      end if
      repeat with tCol = 1 to kCols
         put char tCol of tLine into tCode
         if tCode is empty or tCode is "." then
            next repeat
         end if
         if tLap > 0 and tCode is a number then
            if random(100) <= min(60, 20 * tLap) then
               put "T" into tCode
            end if
         end if
         ebPutBrick (tRow - 1) * kCols + tCol, tCode
      end repeat
   end repeat
   ebBrickLooks
end ebLoadLevel

-- A brick of kind pCode in a cell (not drawn: ebBrickLook does that)
private command ebPutBrick pCell, pCode
   if sBK[pCell] is not empty and sBK[pCell] is not "X" then
      subtract 1 from sRemaining
   end if
   put pCode into sBK[pCell]
   switch pCode
      case "T"
         put 2 into sBH[pCell]
         break
      case "U"
         put 3 into sBH[pCell]
         break
      default
         put 1 into sBH[pCell]
   end switch
   if pCode is not "X" then
      add 1 to sRemaining
   end if
end ebPutBrick

-- Every brick as it is now
command ebBrickLooks
   local i
   repeat with i = 1 to kCells
      ebBrickLook i
   end repeat
end ebBrickLooks

-- A brick's graphic as its cell is: hidden, or with its kind's colours
private command ebBrickLook pCell
   local tCode, tId, tRect, tGradient
   put sId["Brick"][pCell] into tId
   put sBK[pCell] into tCode
   if tCode is empty then
      set the visible of graphic id tId to false
      exit ebBrickLook
   end if
   if tCode is "T" or tCode is "U" then
      put "M" & sBH[pCell] into tCode
   end if
   put the rect of graphic id tId into tRect
   if sEffects is "lite" then
      set the fillGradient of graphic id tId to empty
      set the backgroundColor of graphic id tId to sLook[tCode]["color"]
   else
      put "linear" into tGradient["type"]
      put sLook[tCode]["ramp"] into tGradient["ramp"]
      put (item 1 of tRect + item 3 of tRect) div 2, item 2 of tRect into tGradient["from"]
      put (item 1 of tRect + item 3 of tRect) div 2, item 4 of tRect into tGradient["to"]
      put item 3 of tRect, item 2 of tRect into tGradient["via"]
      set the fillGradient of graphic id tId to tGradient
   end if
   set the lineSize of graphic id tId to sLook[tCode]["line"]
   set the foregroundColor of graphic id tId to sLook[tCode]["ink"]
   if sLook[tCode]["mark"] is empty then
      set the showName of graphic id tId to false
   else
      set the label of graphic id tId to sLook[tCode]["mark"]
      set the showName of graphic id tId to true
   end if
   set the visible of graphic id tId to true
end ebBrickLook

-- A ball on the paddle, waiting to be sent off
private command ebServe
   local tOff
   ebClearKind "Ball"
   put "serve" into sPhase
   put sLevelSpeed into sSpeed
   put 0 into sPadHits
   -- (a little off the paddle's middle, so that it leaves at a slant)
   if random(2) is 1 then
      put 5 into tOff
   else
      put -5 into tOff
   end if
   ebNewBall sPadX + tOff, kPadTop - kBallR, 0, -1, tOff
   if sDuel then
      -- (a duel does not wait for a ball to be sent off)
      put sNow + 1.5 into sBall[1]["until"]
   end if
   if sPointer is "touch" then
      set the text of field id sId["Hint"] to "SLIDE, THEN LET GO"
   else
      set the text of field id sId["Hint"] to "CLICK OR PRESS SPACE"
   end if
   set the visible of field id sId["Hint"] to true
end ebServe

-- Every ball waiting on the paddle is sent off
command ebLaunch
   local i, tAny
   if sMode is not "play" and not (sDuel and sMode is "pause") then
      exit ebLaunch
   end if
   if sPhase is not "serve" and sPhase is not "live" then
      exit ebLaunch
   end if
   -- (a duel's first ball waits for the count of three, as its clock
   -- does: sent off before it, a player would have those seconds more
   -- than a rival who waited)
   if sDuel and sNet2["wait"] > 0 then
      exit ebLaunch
   end if
   put false into tAny
   lock screen
   repeat with i = 1 to sCount["Ball"]
      if sBall[i]["on"] then
         if sBall[i]["stuck"] then
            ebLaunchBall i
            put true into tAny
         end if
      end if
   end repeat
   unlock screen
   if tAny then
      ebSound "launch", 0.6
   end if
end ebLaunch

-- A ball leaves the paddle, at the slant of where it sat on it
private command ebLaunchBall i
   local tOff, tAngle
   put sBall[i]["off"] / (sPadW / 2) into tOff
   put max(-1, min(1, tOff)) into tOff
   if abs(tOff) < 0.12 then
      if tOff < 0 then
         put -0.12 into tOff
      else
         put 0.12 into tOff
      end if
   end if
   put tOff * kMaxAngle * pi / 180 into tAngle
   put sin(tAngle) into sBall[i]["dx"]
   put - cos(tAngle) into sBall[i]["dy"]
   put false into sBall[i]["stuck"]
   put empty into sBall[i]["until"]
   if sPhase is "serve" then
      put "live" into sPhase
      put sNow into sBrickAt
      set the visible of field id sId["Hint"] to false
   end if
end ebLaunchBall

-- The last ball went past the paddle
private command ebLoseLife
   ebSound "lost", 0.7
   ebBuzz 120
   ebFlash kBad, 0.18
   ebClearKind "Drop"
   ebClearKind "Bolt"
   ebResetEffects
   if sDuel then
      -- a duel has no lives: a lost ball costs points, and a moment
      put max(0, sScore - kDuelLoss) into sScore
      ebPop "-" & kDuelLoss, sPadX, kPadTop - 30, kBad
      put "lost" into sPhase
      put sNow + kDuelWait into sPhaseAt
      exit ebLoseLife
   end if
   subtract 1 from sLives
   if sLives <= 0 then
      put "dead" into sPhase
      put sNow + 1 into sPhaseAt
   else
      put "lost" into sPhase
      put sNow + 0.8 into sPhaseAt
   end if
end ebLoseLife

-- The last brick broke
private command ebLevelCleared
   put "cleared" into sPhase
   put sNow + 1.3 into sPhaseAt
   ebClearKind "Ball"
   ebClearKind "Drop"
   ebClearKind "Bolt"
   set the visible of field id sId["Hint"] to false
   ebSound "clear", 0.7
   ebBuzz 60
   ebBurst sPadX, kPadTop - 6, kAmber, 10
   if sDuel then
      -- on to the next wall at once, with a bonus
      ebScore 300 + 20 * sLevel, true
      ebBanner "WALL DOWN", "+" & (300 + 20 * sLevel), 1.2
      exit ebLevelCleared
   end if
   ebBanner "LEVEL CLEAR", empty, 1.3
   if sLevel < sLevelCount and sLevel + 1 > sUnlocked then
      put sLevel + 1 into sUnlocked
      ebSave
   end if
end ebLevelCleared

-- What the level was worth, on its panel
private command ebShowClear
   local tIndex, tClear, tLives, tTime, tTotal
   put ebLevelIndex() into tIndex
   put 250 + 50 * min(sLevel, 30) into tClear
   put 100 * sLives into tLives
   put max(0, 600 - 5 * round(sLevelTime)) into tTime
   put tClear + tLives + tTime into tTotal
   put sScore into sCountT
   add tTotal to sScore
   put sScore into sCountTo
   if sScore >= sNextLife then
      ebExtraLife
   end if
   put "clear" into sMode
   set the text of field "Clear Name" to "LEVEL" && sLevel & ":" && toUpper(sLevels[tIndex]["name"])
   set the text of field "Clear Lines" to "Wall down" & return & "Lives left" & return & "Quick work"
   set the text of field "Clear Values" to "+" & tClear & return & "+" & tLives & return & "+" & tTime
   set the text of field "Clear Total" to ebCommas(sCountT)
   ebKeepAwake false
   ebHud
   ebShowScreen "clear"
end ebShowClear

command ebNextLevel
   if sMode is not "clear" then
      exit ebNextLevel
   end if
   put "play" into sMode
   put empty into sCountT
   lock screen
   ebStartLevel sLevel + 1
   ebShowScreen "play"
   unlock screen
   ebKeepAwake true
   put the milliseconds into sLast
   ebSchedule
end ebNextLevel

-- The run's last screen
private command ebShowOver
   local tIndex
   put ebLevelIndex() into tIndex
   put "over" into sMode
   ebKeepAwake false
   ebClearThings
   put 0 into sCountT
   put sScore into sCountTo
   set the text of field "Final" to "0"
   if sScore > sBest then
      put sScore into sBest
      set the text of field "Best Note" to "NEW BEST!"
      ebSound "best", 0.7
   else
      set the text of field "Best Note" to "BEST" && ebCommas(sBest)
      ebSound "over", 0.7
   end if
   ebSave
   set the text of field "Stats" to "Reached level" && sLevel & "," && sLevels[tIndex]["name"] & return & \
         sBricksRun && "bricks broken, heat up to x" & sTopHeat
   ebShowScreen "over"
end ebShowOver

-- The score counts up on the last screen and the level's
private command ebCountUp pDt
   local tField
   if sCountT is not a number or sCountTo is not a number then
      exit ebCountUp
   end if
   if sMode is "over" then
      put "Final" into tField
   else
      put "Clear Total" into tField
   end if
   if sCountT >= sCountTo then
      exit ebCountUp
   end if
   put min(sCountTo, sCountT + max(7, (sCountTo - sCountT) * 4 * pDt)) into sCountT
   set the text of field tField to ebCommas(sCountT)
end ebCountUp

command ebPause
   if sMode is not "play" then
      exit ebPause
   end if
   put "pause" into sMode
   put false into sDragging
   lock screen
   if sDuel then
      -- a duel goes on behind the panel: it is the way out of it
      set the visible of graphic "Restart Shape" to false
      set the visible of button "Restart" to false
      set the visible of graphic "Pause Settings Shape" to false
      set the visible of button "Pause Settings" to false
      set the label of button "Pause Home" to "LEAVE THE DUEL"
      set the text of field "Paused Title" to "STILL PLAYING"
   else
      ebStopLoop
      ebKeepAwake false
      set the visible of graphic "Restart Shape" to true
      set the visible of button "Restart" to true
      set the visible of graphic "Pause Settings Shape" to true
      set the visible of button "Pause Settings" to true
      set the label of button "Pause Home" to "HOME"
      set the text of field "Paused Title" to "PAUSED"
   end if
   ebShowScreen "pause"
   unlock screen
end ebPause

command ebResume
   if sMode is not "pause" then
      exit ebResume
   end if
   put "play" into sMode
   put false into sDragging
   put empty into sMouseLast
   lock screen
   ebShowScreen "play"
   if sPhase is "serve" and not (sDuel and sNet2["wait"] > 0) then
      set the visible of field id sId["Hint"] to true
   end if
   unlock screen
   ebKeepAwake true
   put the milliseconds into sLast
   ebSchedule
end ebResume

-- Everything that flies, put away
command ebClearThings
   local tKind
   repeat for each item tKind in "Ball,Drop,Bolt,Spark,Pop"
      ebClearKind tKind
   end repeat
   put empty into sBlast
   set the visible of graphic id sId["Flash"] to false
   put empty into sFlashUntil
   set the visible of graphic id sId["Net"] to false
   set the visible of graphic id sId["Cannon 1"] to false
   set the visible of graphic id sId["Cannon 2"] to false
end ebClearThings

private command ebClearKind pKind
   local i, tType
   if pKind is "Pop" then
      put "field" into tType
   else
      put "graphic" into tType
   end if
   repeat with i = 1 to sCount[pKind]
      switch pKind
         case "Ball"
            put false into sBall[i]["on"]
            break
         case "Drop"
            put false into sDrop[i]["on"]
            break
         case "Bolt"
            put false into sBolt[i]["on"]
            break
         case "Spark"
            put false into sSpark[i]["on"]
            break
         case "Pop"
            put false into sPop[i]["on"]
            break
      end switch
      set the visible of control id sId[pKind][i] to false
   end repeat
end ebClearKind

-- No spark at work: the paddle its own size, the ball its own pace
private command ebResetEffects
   put "normal" into sSize
   put 0 into sSizeUntil
   put kPadNormal into sPadTarget
   put 1 into sTempo
   put 0 into sTempoUntil
   put 0 into sBlazeUntil
   put 0 into sGripUntil
   put 0 into sBoltsUntil
   put 0 into sNextBolt
   put false into sNet
   put 0 into sHeat
   put 0 into sHeatAt
   put 1 into sMult
   put 0 into sSinceDrop
   if sId["Net"] is not empty then
      set the visible of graphic id sId["Net"] to false
      set the visible of graphic id sId["Cannon 1"] to false
      set the visible of graphic id sId["Cannon 2"] to false
      ebBallLooks false
   end if
end ebResetEffects

private function ebRand pFrom, pTo
   return pFrom + (pTo - pFrom) * (random(1000001) - 1) / 1000000
end ebRand

function ebCommas pNumber
   local tDigits, tOut
   put round(pNumber) into tDigits
   repeat while the number of chars of tDigits > 3
      put comma & char -3 to -1 of tDigits before tOut
      delete char -3 to -1 of tDigits
   end repeat
   return tDigits & tOut
end ebCommas

----------------------------------------------------------------------
-- The paddle

-- A finger slides it (from anywhere on the screen: it moves as far as
-- the finger does, and a little more), a mouse points at where it goes,
-- and the arrow keys, or A and D, push it
private command ebSteer pDt
   local tLoc, tKeys, tHalf
   if not sManual then
      put the mouseLoc into tLoc
      if sPointer is "touch" then
         if sDragging then
            add (item 1 of tLoc - item 1 of sDragFrom) * kDragGain / sS to sPadX
            put tLoc into sDragFrom
         end if
      else if tLoc is not sMouseLast then
         if sMouseLast is not empty then
            put (item 1 of tLoc - sAX) / sS into sPadX
         end if
         put tLoc into sMouseLast
      end if
      put the keysDown into tKeys
      if tKeys is not empty then
         if 65361 is among the items of tKeys or 97 is among the items of tKeys or 65 is among the items of tKeys then
            subtract kKeySpeed * pDt from sPadX
         end if
         if 65363 is among the items of tKeys or 100 is among the items of tKeys or 68 is among the items of tKeys then
            add kKeySpeed * pDt to sPadX
         end if
      end if
   end if
   put sPadW / 2 into tHalf
   put max(tHalf, min(kArenaW - tHalf, sPadX)) into sPadX
end ebSteer

-- The paddle where it is and as wide as it is; green while it grips; its
-- cannons while it has bolts
private command ebDrawPaddle
   local tRect, tLook, tGradient, tOn, tTop, tW
   put round(sAX + (sPadX - sPadW / 2) * sS), round(sAY + kPadTop * sS), \
         round(sAX + (sPadX + sPadW / 2) * sS), round(sAY + (kPadTop + kPadH) * sS) into tRect
   if sNow < sGripUntil then
      put kGood into tLook
   else
      put kAmber into tLook
   end if
   put tLook & sEffects & sPadTarget into tLook
   if tRect is not sHud["pad"] or tLook is not sPadLook then
      set the rect of graphic id sId["Paddle"] to tRect
      put tRect into sHud["pad"]
   end if
   if tLook is not sPadLook and sPadW is sPadTarget then
      -- (once it has stopped growing or shrinking: its gradient is laid
      -- over the size it has)
      put tLook into sPadLook
      if sEffects is "lite" then
         set the fillGradient of graphic id sId["Paddle"] to empty
         set the backgroundColor of graphic id sId["Paddle"] to char 1 to 7 of tLook
      else
         put "linear" into tGradient["type"]
         put ebRamp(char 1 to 7 of tLook) into tGradient["ramp"]
         put (item 1 of tRect + item 3 of tRect) div 2, item 2 of tRect into tGradient["from"]
         put (item 1 of tRect + item 3 of tRect) div 2, item 4 of tRect into tGradient["to"]
         put item 3 of tRect, item 2 of tRect into tGradient["via"]
         set the fillGradient of graphic id sId["Paddle"] to tGradient
      end if
   end if
   if not the visible of graphic id sId["Paddle"] then
      set the visible of graphic id sId["Paddle"] to true
   end if
   put sNow < sBoltsUntil into tOn
   if tOn then
      put max(2, round(4 * sS)) into tW
      put item 2 of tRect - max(2, round(5 * sS)) into tTop
      set the rect of graphic id sId["Cannon 1"] to item 1 of tRect + tW, tTop, item 1 of tRect + 2 * tW, item 2 of tRect
      set the rect of graphic id sId["Cannon 2"] to item 3 of tRect - 2 * tW, tTop, item 3 of tRect - tW, item 2 of tRect
   end if
   if tOn is not sHud["cannons"] then
      put tOn into sHud["cannons"]
      set the visible of graphic id sId["Cannon 1"] to tOn
      set the visible of graphic id sId["Cannon 2"] to tOn
   end if
end ebDrawPaddle

----------------------------------------------------------------------
-- The sparks at work, and the heat

private command ebEffects pDt
   local tBlaze, i
   if sSize is not "normal" and sNow >= sSizeUntil then
      put "normal" into sSize
      put kPadNormal into sPadTarget
   end if
   if sPadW < sPadTarget then
      put min(sPadTarget, sPadW + 160 * pDt) into sPadW
   else if sPadW > sPadTarget then
      put max(sPadTarget, sPadW - 160 * pDt) into sPadW
   end if
   if sTempo is not 1 and sNow >= sTempoUntil then
      put 1 into sTempo
   end if
   put sNow < sBlazeUntil into tBlaze
   if tBlaze is not sBlazeOn then
      ebBallLooks tBlaze
   end if
   -- the heat cools when no brick feeds it
   if sHeat > 0 and sNow - sHeatAt > kHeatHold then
      subtract 1 from sHeat
      put sNow - kHeatHold + kHeatCool into sHeatAt
      put 1 + min(4, sHeat div kHeatStep) into sMult
   end if
   -- the bolts, two at a time from the paddle's ends
   if sNow < sBoltsUntil and sPhase is "live" and sNow >= sNextBolt then
      put sNow + kBoltEvery into sNextBolt
      ebNewBolt sPadX - sPadW / 2 + 6, kPadTop - 4
      ebNewBolt sPadX + sPadW / 2 - 6, kPadTop - 4
      ebSound "laser", 0.25
   end if
end ebEffects

-- The balls on fire (pOn) or as they are
private command ebBallLooks pOn
   local i, tColor
   put pOn into sBlazeOn
   if pOn then
      put kEmber into tColor
   else
      put kBallColor into tColor
   end if
   repeat with i = 1 to sCount["Ball"]
      set the backgroundColor of graphic id sId["Ball"][i] to tColor
   end repeat
end ebBallLooks

-- A brick broke: the ball is hotter
private command ebHeatUp
   local tMult
   put min(kMaxHeat, sHeat + 1) into sHeat
   put sNow into sHeatAt
   put 1 + min(4, sHeat div kHeatStep) into tMult
   if tMult > sMult then
      put tMult into sMult
      ebSound "heat", 0.5
      ebPop "HEAT x" & tMult, sPadX, kPadTop - 26, kAmber
      if tMult > sTopHeat then
         put tMult into sTopHeat
      end if
      if sDuel then
         ebDuelHeat tMult
      end if
   end if
end ebHeatUp

-- pPoints more, times the heat's bonus (or as they are, pFlat); and a
-- life for every kLifeEvery of them
private command ebScore pPoints, pFlat
   if pFlat is true then
      add pPoints to sScore
   else
      add pPoints * sMult to sScore
   end if
   if sScore >= sNextLife and not sDuel then
      ebExtraLife
   end if
end ebScore

private command ebExtraLife
   repeat while sScore >= sNextLife
      add kLifeEvery to sNextLife
      if sLives < kMaxLives then
         add 1 to sLives
         ebSound "life", 0.7
         ebPop "EXTRA LIFE", kArenaW / 2, 300, kGood
      end if
   end repeat
end ebExtraLife

----------------------------------------------------------------------
-- The balls

-- The first of a kind that is not in play (0 if all are)
private function ebFree pKind
   local i
   repeat with i = 1 to sCount[pKind]
      switch pKind
         case "Ball"
            if sBall[i]["on"] is not true then
               return i
            end if
            break
         case "Drop"
            if sDrop[i]["on"] is not true then
               return i
            end if
            break
         case "Bolt"
            if sBolt[i]["on"] is not true then
               return i
            end if
            break
         case "Spark"
            if sSpark[i]["on"] is not true then
               return i
            end if
            break
         case "Pop"
            if sPop[i]["on"] is not true then
               return i
            end if
            break
      end switch
   end repeat
   return 0
end ebFree

function ebActive pKind
   local i, tCount
   put 0 into tCount
   repeat with i = 1 to sCount[pKind]
      switch pKind
         case "Ball"
            if sBall[i]["on"] then
               add 1 to tCount
            end if
            break
         case "Drop"
            if sDrop[i]["on"] then
               add 1 to tCount
            end if
            break
         case "Bolt"
            if sBolt[i]["on"] then
               add 1 to tCount
            end if
            break
         case "Spark"
            if sSpark[i]["on"] then
               add 1 to tCount
            end if
            break
         case "Pop"
            if sPop[i]["on"] then
               add 1 to tCount
            end if
            break
      end switch
   end repeat
   return tCount
end ebActive

-- A ball at pX,pY going pDX,pDY (made a direction of length 1); with
-- pOff, it sits on the paddle that far from its middle. The result is
-- the ball's number, 0 when every ball is in play
command ebNewBall pX, pY, pDX, pDY, pOff
   local i, tLength
   put ebFree("Ball") into i
   if i is 0 then
      return 0
   end if
   put sqrt(pDX * pDX + pDY * pDY) into tLength
   if tLength < 0.0001 then
      put 0 into pDX
      put -1 into pDY
      put 1 into tLength
   end if
   put empty into sBall[i]
   put true into sBall[i]["on"]
   put pX into sBall[i]["x"]
   put pY into sBall[i]["y"]
   put pDX / tLength into sBall[i]["dx"]
   put pDY / tLength into sBall[i]["dy"]
   put pOff is a number into sBall[i]["stuck"]
   put pOff into sBall[i]["off"]
   ebDrawBall i
   set the visible of graphic id sId["Ball"][i] to true
   return i
end ebNewBall

private command ebDrawBall i
   set the loc of graphic id sId["Ball"][i] to round(sAX + sBall[i]["x"] * sS), round(sAY + sBall[i]["y"] * sS)
end ebDrawBall

private command ebMoveBalls pDt
   local i, tDist, tAny, tHalf
   put sSpeed * sTempo * pDt into tDist
   put false into tAny
   repeat with i = 1 to sCount["Ball"]
      if sBall[i]["on"] is not true then
         next repeat
      end if
      if sBall[i]["stuck"] then
         -- on the paddle, where it landed on it
         put sPadW / 2 into tHalf
         put max(- tHalf, min(tHalf, sBall[i]["off"])) into sBall[i]["off"]
         put sPadX + sBall[i]["off"] into sBall[i]["x"]
         put kPadTop - kBallR into sBall[i]["y"]
         if sBall[i]["until"] is a number then
            if sNow >= sBall[i]["until"] then
               ebLaunchBall i
               ebSound "launch", 0.5
            end if
         end if
      else
         ebFlyBall i, tDist
      end if
      if sBall[i]["on"] then
         put true into tAny
         ebDrawBall i
      end if
   end repeat
   if not tAny and (sPhase is "serve" or sPhase is "live") then
      ebLoseLife
   end if
end ebMoveBalls

-- A ball pDist units on, in steps of at most 4, off the walls, the
-- paddle, the net and the bricks
private command ebFlyBall i, pDist
   local tSteps, tStep, tGone
   put sBall[i]["x"] into sX
   put sBall[i]["y"] into sY
   put sBall[i]["dx"] into sDX
   put sBall[i]["dy"] into sDY
   put pDist div 4 + 1 into tSteps
   put pDist / tSteps into tStep
   put false into tGone
   repeat tSteps times
      add sDX * tStep to sX
      add sDY * tStep to sY
      if sX < kBallR then
         put kBallR into sX
         put abs(sDX) into sDX
         ebSound "wall", 0.3
      else if sX > kArenaW - kBallR then
         put kArenaW - kBallR into sX
         put - abs(sDX) into sDX
         ebSound "wall", 0.3
      end if
      if sY < kBallR then
         put kBallR into sY
         put abs(sDY) into sDY
         ebSound "wall", 0.3
         ebUnstick
      end if
      if sDY > 0 then
         if sY + kBallR >= kPadTop and sY <= kPadTop + 7 then
            if abs(sX - sPadX) <= sPadW / 2 + kBallR then
               ebPaddleBounce i
               if sBall[i]["stuck"] then
                  exit repeat
               end if
            end if
         end if
         if sNet and sDY > 0 and sY + kBallR >= kNetY then
            -- the net throws it back, once
            put kNetY - kBallR into sY
            put - abs(sDY) into sDY
            put false into sNet
            set the visible of graphic id sId["Net"] to false
            ebSound "shield", 0.6
            ebBurst sX, kNetY, kCool, 6
         end if
         if sY - kBallR > kArenaH then
            put true into tGone
            exit repeat
         end if
      end if
      if sY - kBallR < kGridBottom and sY + kBallR > kGridTop then
         ebBallBricks
      end if
   end repeat
   put sX into sBall[i]["x"]
   put sY into sBall[i]["y"]
   put sDX into sBall[i]["dx"]
   put sDY into sBall[i]["dy"]
   if tGone then
      put false into sBall[i]["on"]
      set the visible of graphic id sId["Ball"][i] to false
   else if sBlazeOn and sEffects is not "lite" then
      if random(3) is 1 then
         ebSpark sX, sY, ebRand(-20, 20), ebRand(10, 50), 0.3, kEmber
      end if
   end if
end ebFlyBall

-- Off the paddle: straight up from its middle, steeper towards its ends
private command ebPaddleBounce i
   local tOff, tAngle
   put (sX - sPadX) / (sPadW / 2) into tOff
   put max(-1, min(1, tOff)) into tOff
   put tOff * kMaxAngle * pi / 180 into tAngle
   put sin(tAngle) into sDX
   put - cos(tAngle) into sDY
   put kPadTop - kBallR into sY
   ebUnstick
   add 1 to sPadHits
   if sPadHits mod 6 is 0 then
      put min(sLevelSpeed * kSpeedTop, sSpeed * kSpeedUp) into sSpeed
   end if
   ebSound "paddle", 0.6
   if sNow < sGripUntil then
      -- it holds the ball, for a while or until it is sent off
      put true into sBall[i]["stuck"]
      put sX - sPadX into sBall[i]["off"]
      put sNow + 2.5 into sBall[i]["until"]
   end if
end ebPaddleBounce

-- A ball that has broken nothing for 12 seconds is going round in a
-- ring (between steel and a wall, say): its way is turned a little
private command ebUnstick
   local tAngle, tDX
   if sNow - sBrickAt < 12 then
      exit ebUnstick
   end if
   put ebRand(-0.3, 0.3) into tAngle
   put sDX * cos(tAngle) - sDY * sin(tAngle) into tDX
   put sDX * sin(tAngle) + sDY * cos(tAngle) into sDY
   put tDX into sDX
   ebSteepen
end ebUnstick

-- No ball goes nearly level for long: it would take an age to come down
private command ebSteepen
   if abs(sDY) >= 0.22 then
      exit ebSteepen
   end if
   if sDY < 0 then
      put -0.22 into sDY
   else
      put 0.22 into sDY
   end if
   if sDX < 0 then
      put - sqrt(1 - sDY * sDY) into sDX
   else
      put sqrt(1 - sDY * sDY) into sDX
   end if
end ebSteepen

-- The ball (sX,sY) against the bricks its edge reaches: it hits the
-- nearest, and leaves it by the side it came to (on fire, it goes
-- through everything but steel)
private command ebBallBricks
   local tC0, tC1, tR0, tR1, tC, tR, tCell, tL, tT, tNX, tNY, tD2, tBest
   local tHit, tHX, tHY, tHL, tHT, tLeft, tRight, tTop, tBottom, tLeast
   put max(1, (sX - kBallR) div kCellW + 1) into tC0
   put min(kCols, (sX + kBallR) div kCellW + 1) into tC1
   put max(1, (sY - kBallR - kGridTop) div kCellH + 1) into tR0
   put min(kRows, (sY + kBallR - kGridTop) div kCellH + 1) into tR1
   put kBallR * kBallR into tBest
   put 0 into tHit
   repeat with tR = tR0 to tR1
      repeat with tC = tC0 to tC1
         put (tR - 1) * kCols + tC into tCell
         if sBK[tCell] is empty then
            next repeat
         end if
         put (tC - 1) * kCellW into tL
         put kGridTop + (tR - 1) * kCellH into tT
         put max(tL, min(sX, tL + kCellW)) into tNX
         put max(tT, min(sY, tT + kCellH)) into tNY
         put (sX - tNX) * (sX - tNX) + (sY - tNY) * (sY - tNY) into tD2
         if tD2 < tBest then
            put tD2 into tBest
            put tCell into tHit
            put sX - tNX into tHX
            put sY - tNY into tHY
            put tL into tHL
            put tT into tHT
         end if
      end repeat
   end repeat
   if tHit is 0 then
      exit ebBallBricks
   end if
   if sBlazeOn and sBK[tHit] is not "X" then
      ebHitBrick tHit, "blaze"
      exit ebBallBricks
   end if
   if tHX is 0 and tHY is 0 then
      -- the ball's middle is in the brick: out by the nearest side
      put sX - tHL into tLeft
      put tHL + kCellW - sX into tRight
      put sY - tHT into tTop
      put tHT + kCellH - sY into tBottom
      put min(tLeft, tRight, tTop, tBottom) into tLeast
      if tLeast is tTop then
         put tHT - kBallR into sY
         put - abs(sDY) into sDY
      else if tLeast is tBottom then
         put tHT + kCellH + kBallR into sY
         put abs(sDY) into sDY
      else if tLeast is tLeft then
         put tHL - kBallR into sX
         put - abs(sDX) into sDX
      else
         put tHL + kCellW + kBallR into sX
         put abs(sDX) into sDX
      end if
   else if abs(tHX) > abs(tHY) then
      if tHX > 0 then
         put tHL + kCellW + kBallR into sX
         put abs(sDX) into sDX
      else
         put tHL - kBallR into sX
         put - abs(sDX) into sDX
      end if
   else
      if tHY > 0 then
         put tHT + kCellH + kBallR into sY
         put abs(sDY) into sDY
      else
         put tHT - kBallR into sY
         put - abs(sDY) into sDY
      end if
   end if
   ebSteepen
   ebHitBrick tHit, "ball"
end ebBallBricks

----------------------------------------------------------------------
-- The bricks

-- A brick is hit: by a ball, a ball on fire ("blaze"), a bolt, or a
-- bomb's blast. Steel takes only the blast; a tough or armoured brick
-- takes a ball or a bolt for each of its hits
command ebHitBrick pCell, pHow
   local tKind, tX, tY, tPoints, tColor, tN, tRow, tCol, tDR, tDC
   put sBK[pCell] into tKind
   if tKind is empty then
      exit ebHitBrick
   end if
   put (pCell - 1) mod kCols + 1 into tCol
   put (pCell - 1) div kCols + 1 into tRow
   put (tCol - 0.5) * kCellW into tX
   put kGridTop + (tRow - 0.5) * kCellH into tY
   if tKind is "X" and pHow is not "blast" then
      ebSound "steel", 0.5
      if pHow is "ball" then
         ebSpark tX, tY, ebRand(-40, 40), ebRand(-60, -10), 0.25, "#C9D2E0"
      end if
      exit ebHitBrick
   end if
   if (tKind is "T" or tKind is "U") and (pHow is "ball" or pHow is "bolt") then
      subtract 1 from sBH[pCell]
      if sBH[pCell] > 0 then
         ebBrickLook pCell
         ebSound "tough", 0.6
         ebScore 5
         put sNow into sBrickAt
         ebSpark tX, tY, ebRand(-40, 40), ebRand(-60, -10), 0.25, "#DCE3EE"
         exit ebHitBrick
      end if
   end if
   -- it breaks
   put empty into sBK[pCell]
   set the visible of graphic id sId["Brick"][pCell] to false
   put sNow into sBrickAt
   if tKind is not "X" then
      subtract 1 from sRemaining
   end if
   add 1 to sBricksRun
   ebHeatUp
   switch tKind
      case "T"
         put 20 into tPoints
         put "#CDD6E4" into tColor
         break
      case "U"
         put 30 into tPoints
         put "#8C9AB8" into tColor
         break
      case "X"
         put 15 into tPoints
         put "#7C8696" into tColor
         break
      case "B"
         put 15 into tPoints
         put kEmber into tColor
         break
      case "E"
         put 25 into tPoints
         put "#FFD98A" into tColor
         break
      default
         put 10 into tPoints
         put sLook[tKind]["color"] into tColor
   end switch
   ebScore tPoints
   ebBurst tX, tY, tColor, 5
   if tKind is "B" then
      -- the eight around it go with it, a moment later, and their bombs
      -- in turn
      ebSound "bomb", 0.8
      ebBuzz 60
      ebBurst tX, tY, kAmber, 6
      repeat with tDR = -1 to 1
         repeat with tDC = -1 to 1
            if tRow + tDR < 1 or tRow + tDR > kRows or tCol + tDC < 1 or tCol + tDC > kCols then
               next repeat
            end if
            put (tRow + tDR - 1) * kCols + tCol + tDC into tN
            if tN is not pCell and sBK[tN] is not empty and sBlast[tN] is empty then
               put sNow + 0.07 into sBlast[tN]
            end if
         end repeat
      end repeat
   else
      ebSound "brick-" & sMult, 0.55
   end if
   if tKind is "E" then
      ebNewDrop ebPickDrop(true), tX, tY
   else if tKind is not "X" and not sNoDrops then
      -- about one brick in eight drops a spark, and never more than
      -- nine go by without one
      add 1 to sSinceDrop
      if random(100) <= 12 or sSinceDrop >= 9 then
         if ebActive("Drop") < 4 then
            put 0 into sSinceDrop
            ebNewDrop ebPickDrop(false), tX, tY
         end if
      end if
   end if
end ebHitBrick

-- The bombs' blasts whose moment has come
private command ebBlasts
   local tCell, tDue
   if the keys of sBlast is empty then
      exit ebBlasts
   end if
   repeat for each key tCell in sBlast
      if sBlast[tCell] <= sNow then
         put tCell & comma after tDue
      end if
   end repeat
   repeat for each item tCell in tDue
      delete variable sBlast[tCell]
      ebHitBrick tCell, "blast"
   end repeat
end ebBlasts

----------------------------------------------------------------------
-- The falling sparks

-- Which spark falls: one worth catching (pGood), or by chance one of
-- the dark ones too, from level 3 on
private function ebPickDrop pGood
   local tTable, tLine, tTotal, tPick
   put "wide 16" & return & "split 14" & return & "blaze 8" & return & "chill 10" & return & \
         "grip 9" & return & "bolts 10" & return & "net 10" into tTable
   if not sDuel then
      put return & "life 3" after tTable
   end if
   if not pGood and (sLevel >= 3 or sDuel) then
      put return & "small 8" & return & "fast 8" after tTable
   end if
   put 0 into tTotal
   repeat for each line tLine in tTable
      add word 2 of tLine to tTotal
   end repeat
   put random(tTotal) into tPick
   repeat for each line tLine in tTable
      subtract word 2 of tLine from tPick
      if tPick <= 0 then
         return word 1 of tLine
      end if
   end repeat
   return "wide"
end ebPickDrop

-- A spark of a kind, falling from pX,pY: a bright one with its letter,
-- or a dark one with a red ring
command ebNewDrop pKind, pX, pY
   local i, tId, tLabel, tColor, tInk
   put ebFree("Drop") into i
   if i is 0 then
      exit ebNewDrop
   end if
   put kDark into tInk
   switch pKind
      case "wide"
         put "W" into tLabel
         put kAmber into tColor
         break
      case "split"
         put "S" into tLabel
         put kCool into tColor
         break
      case "blaze"
         put "F" into tLabel
         put kEmber into tColor
         break
      case "chill"
         put "C" into tLabel
         put "#A9DCFF" into tColor
         break
      case "grip"
         put "G" into tLabel
         put kGood into tColor
         break
      case "bolts"
         put "B" into tLabel
         put "#FFE08A" into tColor
         break
      case "net"
         put "N" into tLabel
         put "#5EEAD4" into tColor
         break
      case "life"
         put "+" into tLabel
         put "#FF9FBF" into tColor
         break
      case "small"
         put "><" into tLabel
         put "#3A1016" into tColor
         put kBad into tInk
         break
      case "fast"
         put ">>" into tLabel
         put "#3A1016" into tColor
         put kBad into tInk
         break
      default
         exit ebNewDrop
   end switch
   put empty into sDrop[i]
   put true into sDrop[i]["on"]
   put pKind into sDrop[i]["kind"]
   put pX into sDrop[i]["x"]
   put pY into sDrop[i]["y"]
   put sId["Drop"][i] into tId
   set the label of graphic id tId to tLabel
   set the backgroundColor of graphic id tId to tColor
   set the foregroundColor of graphic id tId to tInk
   set the loc of graphic id tId to round(sAX + pX * sS), round(sAY + pY * sS)
   set the visible of graphic id tId to true
end ebNewDrop

private command ebMoveDrops pDt
   local i, tY
   repeat with i = 1 to sCount["Drop"]
      if sDrop[i]["on"] is not true then
         next repeat
      end if
      add kDropSpeed * pDt to sDrop[i]["y"]
      put sDrop[i]["y"] into tY
      if tY + kDropR >= kPadTop and tY - kDropR <= kPadTop + kPadH and (sPhase is "serve" or sPhase is "live") then
         if abs(sDrop[i]["x"] - sPadX) <= sPadW / 2 + kDropR then
            put false into sDrop[i]["on"]
            set the visible of graphic id sId["Drop"][i] to false
            ebCatch sDrop[i]["kind"]
            next repeat
         end if
      end if
      if tY - kDropR > kArenaH then
         put false into sDrop[i]["on"]
         set the visible of graphic id sId["Drop"][i] to false
         next repeat
      end if
      set the loc of graphic id sId["Drop"][i] to round(sAX + sDrop[i]["x"] * sS), round(sAY + tY * sS)
   end repeat
end ebMoveDrops

-- The paddle caught a spark: what each kind does
command ebCatch pKind
   local tWord, tGood
   put true into tGood
   switch pKind
      case "wide"
         put "wide" into sSize
         put sNow + kWideFor into sSizeUntil
         put kPadWide into sPadTarget
         put "WIDE" into tWord
         break
      case "small"
         put "small" into sSize
         put sNow + kSmallFor into sSizeUntil
         put kPadSmall into sPadTarget
         put "SHRUNK!" into tWord
         put false into tGood
         break
      case "split"
         ebSplit
         put "SPLIT" into tWord
         break
      case "blaze"
         put sNow + kBlazeFor into sBlazeUntil
         ebBallLooks true
         put "FIREBALL" into tWord
         break
      case "chill"
         put 0.72 into sTempo
         put sNow + kChillFor into sTempoUntil
         put "SLOW" into tWord
         break
      case "fast"
         put 1.3 into sTempo
         put sNow + kFastFor into sTempoUntil
         put "FAST!" into tWord
         put false into tGood
         break
      case "grip"
         put sNow + kGripFor into sGripUntil
         put "GRIP" into tWord
         break
      case "bolts"
         put sNow + kBoltsFor into sBoltsUntil
         put sNow + 0.2 into sNextBolt
         put "BOLTS" into tWord
         break
      case "net"
         put true into sNet
         set the visible of graphic id sId["Net"] to true
         put "NET" into tWord
         break
      case "life"
         if sLives < kMaxLives then
            add 1 to sLives
            put "LIFE" into tWord
         else
            ebScore 500, true
            put "+500" into tWord
         end if
         break
      default
         exit ebCatch
   end switch
   if tGood then
      ebScore 50, true
      ebPop tWord, sPadX, kPadTop - 26, kGood
      if pKind is "life" then
         ebSound "life", 0.7
      else if pKind is "blaze" then
         ebSound "blaze", 0.6
      else if pKind is "net" then
         ebSound "shield", 0.6
      else
         ebSound "power", 0.6
      end if
   else
      ebPop tWord, sPadX, kPadTop - 26, kBad
      ebSound "hazard", 0.6
      ebBuzz 80
   end if
end ebCatch

-- Two more balls for each in play, a little to each side of its way (a
-- ball waiting on the paddle stays, and its two go straight off)
private command ebSplit
   local i, tList, tDX, tDY, tAngle, tSign, tNew
   repeat with i = 1 to sCount["Ball"]
      if sBall[i]["on"] then
         put i & comma after tList
      end if
   end repeat
   repeat for each item i in tList
      if sBall[i]["stuck"] then
         put 0 into tDX
         put -1 into tDY
      else
         put sBall[i]["dx"] into tDX
         put sBall[i]["dy"] into tDY
      end if
      repeat for each item tSign in "-1,1"
         put 0.42 * tSign into tAngle
         put tDX * cos(tAngle) - tDY * sin(tAngle) into sDX
         put tDX * sin(tAngle) + tDY * cos(tAngle) into sDY
         ebSteepen
         ebNewBall sBall[i]["x"], sBall[i]["y"], sDX, sDY
      end repeat
   end repeat
   if sPhase is "serve" then
      put "live" into sPhase
      put sNow into sBrickAt
   end if
end ebSplit

----------------------------------------------------------------------
-- The bolts

private command ebNewBolt pX, pY
   local i
   put ebFree("Bolt") into i
   if i is 0 then
      exit ebNewBolt
   end if
   put true into sBolt[i]["on"]
   put pX into sBolt[i]["x"]
   put pY into sBolt[i]["y"]
   set the loc of graphic id sId["Bolt"][i] to round(sAX + pX * sS), round(sAY + pY * sS)
   set the visible of graphic id sId["Bolt"][i] to true
end ebNewBolt

private command ebMoveBolts pDt
   local i, tY, tCell, tRow, tLeft, tSteps
   repeat with i = 1 to sCount["Bolt"]
      if sBolt[i]["on"] is not true then
         next repeat
      end if
      -- (in steps of at most a brick's height, so that it passes none)
      put kBoltSpeed * pDt into tLeft
      put tLeft div 12 + 1 into tSteps
      repeat tSteps times
         subtract tLeft / tSteps from sBolt[i]["y"]
         put sBolt[i]["y"] into tY
         if tY < 0 then
            put false into sBolt[i]["on"]
            exit repeat
         end if
         if tY >= kGridTop and tY < kGridBottom then
            put (tY - kGridTop) div kCellH + 1 into tRow
            put (tRow - 1) * kCols + max(1, min(kCols, sBolt[i]["x"] div kCellW + 1)) into tCell
            if sBK[tCell] is not empty then
               put false into sBolt[i]["on"]
               ebHitBrick tCell, "bolt"
               exit repeat
            end if
         end if
      end repeat
      if sBolt[i]["on"] then
         set the loc of graphic id sId["Bolt"][i] to round(sAX + sBolt[i]["x"] * sS), round(sAY + sBolt[i]["y"] * sS)
      else
         set the visible of graphic id sId["Bolt"][i] to false
      end if
   end repeat
end ebMoveBolts

----------------------------------------------------------------------
-- The bits of a broken brick, the floating words, the banner, the flash
-- and the embers behind the screens

-- pCount bits from pX,pY (fewer with the effects on "lite")
private command ebBurst pX, pY, pColor, pCount
   if sEffects is "lite" then
      put min(2, pCount) into pCount
   end if
   repeat pCount times
      ebSpark pX + ebRand(-10, 10), pY + ebRand(-4, 4), ebRand(-110, 110), ebRand(-150, 30), ebRand(0.3, 0.55), pColor
   end repeat
end ebBurst

-- One bit, in units and units a second, for pLife seconds
private command ebSpark pX, pY, pVX, pVY, pLife, pColor
   local i
   put ebFree("Spark") into i
   if i is 0 then
      exit ebSpark
   end if
   put true into sSpark[i]["on"]
   put pX into sSpark[i]["x"]
   put pY into sSpark[i]["y"]
   put pVX into sSpark[i]["vx"]
   put pVY into sSpark[i]["vy"]
   put pLife into sSpark[i]["life"]
   set the backgroundColor of graphic id sId["Spark"][i] to pColor
   set the loc of graphic id sId["Spark"][i] to round(sAX + pX * sS), round(sAY + pY * sS)
   set the visible of graphic id sId["Spark"][i] to true
end ebSpark

private command ebMoveSparks pDt
   local i
   repeat with i = 1 to sCount["Spark"]
      if sSpark[i]["on"] is not true then
         next repeat
      end if
      subtract pDt from sSpark[i]["life"]
      if sSpark[i]["life"] <= 0 then
         put false into sSpark[i]["on"]
         set the visible of graphic id sId["Spark"][i] to false
         next repeat
      end if
      add 420 * pDt to sSpark[i]["vy"]
      add sSpark[i]["vx"] * pDt to sSpark[i]["x"]
      add sSpark[i]["vy"] * pDt to sSpark[i]["y"]
      set the loc of graphic id sId["Spark"][i] to round(sAX + sSpark[i]["x"] * sS), round(sAY + sSpark[i]["y"] * sS)
   end repeat
end ebMoveSparks

-- Words that rise from pX,pY (in units) and go
command ebPop pText, pX, pY, pColor
   local i, tOldest, tId, tHalf
   put ebFree("Pop") into i
   if i is 0 then
      -- (all in use: the oldest goes)
      put 1 into i
      repeat with tOldest = 2 to sCount["Pop"]
         if sPop[tOldest]["t"] > sPop[i]["t"] then
            put tOldest into i
         end if
      end repeat
   end if
   put round(70 * sUI) into tHalf
   put empty into sPop[i]
   put true into sPop[i]["on"]
   put 0 into sPop[i]["t"]
   put max(item 1 of sArena + tHalf, min(item 3 of sArena - tHalf, round(sAX + pX * sS))) into sPop[i]["x"]
   put round(sAY + pY * sS) into sPop[i]["y"]
   put sId["Pop"][i] into tId
   set the text of field id tId to pText
   set the textColor of field id tId to pColor
   set the rect of field id tId to 0, 0, 2 * tHalf, round(22 * sUI)
   set the loc of field id tId to sPop[i]["x"], sPop[i]["y"]
   set the visible of field id tId to true
end ebPop

private command ebMovePops pDt
   local i
   repeat with i = 1 to sCount["Pop"]
      if sPop[i]["on"] is not true then
         next repeat
      end if
      add pDt to sPop[i]["t"]
      if sPop[i]["t"] >= 0.9 then
         put false into sPop[i]["on"]
         set the visible of field id sId["Pop"][i] to false
         next repeat
      end if
      set the loc of field id sId["Pop"][i] to sPop[i]["x"], round(sPop[i]["y"] - 34 * sUI * sPop[i]["t"])
   end repeat
end ebMovePops

command ebBanner pText, pSub, pFor
   set the text of field "Banner Text" to pText
   set the text of field "Banner Sub" to pSub
   set the visible of group "Banner" to true
   put sClock + pFor into sBannerUntil
end ebBanner

private command ebFlash pColor, pFor
   set the backgroundColor of graphic id sId["Flash"] to pColor
   set the visible of graphic id sId["Flash"] to true
   put sClock + pFor into sFlashUntil
end ebFlash

-- The embers that drift up behind the title and its screens
private command ebScatterMotes
   local i, tSize
   repeat with i = 1 to sCount["Mote"]
      put ebRand(0, sW) into sMote[i]["x"]
      put ebRand(0, sH) into sMote[i]["y"]
      put ebRand(14, 46) * sUI into sMote[i]["v"]
      put ebRand(0, 6.28) into sMote[i]["p"]
      put max(2, round(ebRand(2, 6) * sUI)) into tSize
      set the rect of graphic id sId["Mote"][i] to 0, 0, tSize, tSize
      set the loc of graphic id sId["Mote"][i] to round(sMote[i]["x"]), round(sMote[i]["y"])
   end repeat
end ebScatterMotes

private command ebMoveMotes pDt
   local i
   repeat with i = 1 to sCount["Mote"]
      subtract sMote[i]["v"] * pDt from sMote[i]["y"]
      if sMote[i]["y"] < -8 then
         put sH + 8 into sMote[i]["y"]
         put ebRand(0, sW) into sMote[i]["x"]
      end if
      set the loc of graphic id sId["Mote"][i] to round(sMote[i]["x"] + 10 * sUI * sin(sClock * 0.9 + sMote[i]["p"])), round(sMote[i]["y"])
   end repeat
end ebMoveMotes

----------------------------------------------------------------------
-- The HUD: changed only where what it shows has changed

private command ebHud
   local i, tIndex, tShare, tWidth, tColor, tKey, tList, tLine, tName, tRect, tBad
   if sScore is not sHud["score"] then
      put sScore into sHud["score"]
      set the text of field id sId["Score"] to ebCommas(sScore)
   end if
   if sLevel is not sHud["level"] then
      put sLevel into sHud["level"]
      put ebLevelIndex() into tIndex
      if sDuel then
         set the text of field id sId["Stage"] to "WALL" && sLevel
      else
         set the text of field id sId["Stage"] to "LEVEL" && sLevel
      end if
      set the text of field id sId["Stage Name"] to sLevels[tIndex]["name"]
   end if
   if sLives is not sHud["lives"] then
      put sLives into sHud["lives"]
      repeat with i = 1 to sCount["Life"]
         set the visible of graphic id sId["Life"][i] to (i <= sLives and not sDuel)
      end repeat
   end if
   -- the heat: its bonus, and how near the next step of it is
   if sMult >= 5 then
      put 1 into tShare
   else
      put (sHeat mod kHeatStep) / kHeatStep into tShare
   end if
   put item 1 of sHeatBar + round((item 3 of sHeatBar - item 1 of sHeatBar) * tShare) into tWidth
   put sMult & ":" & tWidth into tKey
   if tKey is not sHud["heat"] then
      if sMult is not char 1 of sHud["heat"] then
         put item sMult of "#8A6A55,#FFB52E,#FF7A3D,#FF5D5D,#FFF3D6" into tColor
         set the text of field id sId["Heat Text"] to "HEAT x" & sMult
         set the textColor of field id sId["Heat Text"] to tColor
         set the backgroundColor of graphic id sId["Heat Fill"] to tColor
      end if
      put tKey into sHud["heat"]
      set the rect of graphic id sId["Heat Fill"] to item 1 of sHeatBar, item 2 of sHeatBar, max(item 1 of sHeatBar, tWidth), item 4 of sHeatBar
   end if
   -- a chip for each spark at work: its name, and the time it has left
   if sSize is "wide" then
      put "WIDE" && (sSizeUntil - sNow) / kWideFor & return after tList
   else if sSize is "small" then
      put "SMALL" && (sSizeUntil - sNow) / kSmallFor && "bad" & return after tList
   end if
   if sTempo < 1 then
      put "SLOW" && (sTempoUntil - sNow) / kChillFor & return after tList
   else if sTempo > 1 then
      put "FAST" && (sTempoUntil - sNow) / kFastFor && "bad" & return after tList
   end if
   if sNow < sBlazeUntil then
      put "FIRE" && (sBlazeUntil - sNow) / kBlazeFor & return after tList
   end if
   if sNow < sGripUntil then
      put "GRIP" && (sGripUntil - sNow) / kGripFor & return after tList
   end if
   if sNow < sBoltsUntil then
      put "BOLTS" && (sBoltsUntil - sNow) / kBoltsFor & return after tList
   end if
   if sNet then
      put "NET 1" & return after tList
   end if
   repeat with i = 1 to sCount["Chip"]
      put line i of tList into tLine
      put word 1 of tLine into tName
      -- (kept with a mark before it: nothing kept, after a new level or
      -- a new layout, is not the same as no chip shown)
      if ("=" & tName) is not sHud["chip" & i] then
         put "=" & tName into sHud["chip" & i]
         put empty into sHud["chipw" & i]
         set the visible of graphic id sId["Chip Back"][i] to tName is not empty
         set the visible of graphic id sId["Chip Fill"][i] to tName is not empty
         set the visible of field id sId["Chip Text"][i] to tName is not empty
         if tName is not empty then
            put word 3 of tLine is "bad" into tBad
            set the text of field id sId["Chip Text"][i] to tName
            if tBad then
               set the textColor of field id sId["Chip Text"][i] to kBad
               set the backgroundColor of graphic id sId["Chip Fill"][i] to kBad
            else
               set the textColor of field id sId["Chip Text"][i] to kInk
               set the backgroundColor of graphic id sId["Chip Fill"][i] to kAmber
            end if
         end if
      end if
      if tName is not empty then
         put sChipRect[i] into tRect
         put round((item 3 of tRect - item 1 of tRect - 8) * max(0, min(1, word 2 of tLine))) into tWidth
         if tWidth is not sHud["chipw" & i] then
            put tWidth into sHud["chipw" & i]
            set the rect of graphic id sId["Chip Fill"][i] to item 1 of tRect + 4, item 4 of tRect - 5, item 1 of tRect + 4 + tWidth, item 4 of tRect - 2
         end if
      end if
   end repeat
end ebHud

----------------------------------------------------------------------
-- Layout: every control in its place for the window's size, out of the
-- notch and the home bar

command ebResized
   local tOldW, tOldH
   set the defaultStack to the short name of me
   put sW into tOldW
   put sH into tOldH
   ebLayout
   -- a phone turned in the middle of a level: a moment to hold it again
   if sMode is "play" and not sDuel and tOldW is a number then
      if abs(tOldW - sW) > 60 or abs(tOldH - sH) > 60 then
         ebPause
      end if
   end if
end ebResized

-- The part of the screen under a notch, a rounded corner, the status bar
-- or the home bar, at each edge: in a browser the library's safe-area
-- insets, on a phone what the working screen leaves of the whole one
private command ebMeasure
   local tView, tScreen, tWork
   put 0 into sInT
   put 0 into sInB
   put 0 into sInL
   put 0 into sInR
   if the number of items of sFakeInsets is 4 then
      put item 1 of sFakeInsets into sInT
      put item 2 of sFakeInsets into sInB
      put item 3 of sFakeInsets into sInL
      put item 4 of sFakeInsets into sInR
   else if sPlatform is "web" then
      if sLibrary then
         try
            put mwViewport() into tView
            if tView["top"] is a number then
               put max(0, tView["top"]) into sInT
            end if
            if tView["bottom"] is a number then
               put max(0, tView["bottom"]) into sInB
            end if
            if tView["left"] is a number then
               put max(0, tView["left"]) into sInL
            end if
            if tView["right"] is a number then
               put max(0, tView["right"]) into sInR
            end if
         end try
      end if
   else if sPlatform is "mobile" then
      try
         put the screenRect into tScreen
         put the effective working screenRect into tWork
         put max(0, item 2 of tWork - item 2 of tScreen) into sInT
         put max(0, item 4 of tScreen - item 4 of tWork) into sInB
         put max(0, item 1 of tWork - item 1 of tScreen) into sInL
         put max(0, item 3 of tScreen - item 3 of tWork) into sInR
         -- (the keyboard, when it shows, is not the navigation bar)
         if sInB > 64 then
            put 0 into sInB
         end if
      end try
   end if
end ebMeasure

-- pN points of a window 390 wide, in this one
private function ebU pN
   return round(pN * sUI)
end ebU

command ebLayout
   local tArenaH, tArenaW, tHudH, tAvailW, tAvailH, i, tId, tCol, tRow, tSize, tRadius, tL, tT, tR, tB, tHintY
   set the defaultStack to the short name of me
   lock screen
   put the width of me into sW
   put the height of me into sH
   ebMeasure
   put max(0.8, min(1.4, min(sW / 390, sH / 640))) into sUI
   -- the arena as tall as the window when that leaves room for the HUD
   -- at its sides (a desktop's window, a phone on its side); else under
   -- the HUD, as wide as the window, with what is left under it for a
   -- thumb
   put sH - sInT - sInB - 16 into tArenaH
   put tArenaH * kArenaW / kArenaH into tArenaW
   put (sW - sInL - sInR - tArenaW >= 272 * sUI) into sWide
   if sWide then
      put tArenaH / kArenaH into sS
      put sInL + round((sW - sInL - sInR - tArenaW) / 2) into sAX
      put sInT + 8 into sAY
   else
      if sDuel then
         put ebU(118) into tHudH
      else
         put ebU(74) into tHudH
      end if
      put sW - sInL - sInR - 4 into tAvailW
      put sH - sInT - sInB - tHudH - 4 into tAvailH
      put max(0.2, min(tAvailW / kArenaW, tAvailH / kArenaH)) into sS
      put sInL + round((sW - sInL - sInR - kArenaW * sS) / 2) into sAX
      put sInT + tHudH into sAY
   end if
   put sAX into tL
   put sAY into tT
   put round(sAX + kArenaW * sS) into tR
   put round(sAY + kArenaH * sS) into tB
   put tL, tT, tR, tB into sArena
   set the rect of graphic id sId["Arena"] to sArena
   set the points of graphic id sId["Walls"] to (tL - 1) & comma & tB & return & (tL - 1) & comma & (tT - 1) & return & \
         tR & comma & (tT - 1) & return & tR & comma & tB
   set the rect of graphic id sId["Flash"] to sArena
   set the rect of graphic id sId["Net"] to tL, round(sAY + kNetY * sS), tR, round(sAY + kNetY * sS) + max(2, round(3 * sS))
   -- (the hint under the banner, which a small arena brings near it)
   put max(round(sAY + 392 * sS), round(sAY + 340 * sS) + ebU(52)) into tHintY
   set the rect of field id sId["Hint"] to tL, tHintY - ebU(12), tR, tHintY + ebU(12)
   set the rect of graphic "Shade" to 0, 0, sW, sH
   -- the words, at this window's size
   repeat for each key tId in sSized
      set the textSize of control id tId to max(9, round(sSized[tId] * sUI))
   end repeat
   -- the sizes of the things that fly
   put max(4, round(2 * kBallR * sS)) into tSize
   repeat with i = 1 to sCount["Ball"]
      set the rect of graphic id sId["Ball"][i] to 0, 0, tSize, tSize
   end repeat
   put max(8, round(2 * kDropR * sS)) into tSize
   repeat with i = 1 to sCount["Drop"]
      set the rect of graphic id sId["Drop"][i] to 0, 0, tSize, tSize
      set the textSize of graphic id sId["Drop"][i] to max(8, round(10 * sS))
   end repeat
   repeat with i = 1 to sCount["Bolt"]
      set the rect of graphic id sId["Bolt"][i] to 0, 0, max(2, round(2 * sS)), max(4, round(8 * sS))
   end repeat
   put max(2, round(3 * sS)) into tSize
   repeat with i = 1 to sCount["Spark"]
      set the rect of graphic id sId["Spark"][i] to 0, 0, tSize, tSize
   end repeat
   set the roundRadius of graphic id sId["Paddle"] to max(2, round(kPadH * sS))
   -- the bricks, each in its cell with a little of the arena round it
   put max(2, round(4 * sS)) into tRadius
   put max(8, round(11 * sS)) into tSize
   repeat with i = 1 to kCells
      put (i - 1) mod kCols into tCol
      put (i - 1) div kCols into tRow
      put sId["Brick"][i] into tId
      set the rect of graphic id tId to round(sAX + (tCol * kCellW + 1) * sS), round(sAY + (kGridTop + tRow * kCellH + 1) * sS), \
            round(sAX + ((tCol + 1) * kCellW - 1) * sS), round(sAY + (kGridTop + (tRow + 1) * kCellH - 1) * sS)
      set the roundRadius of graphic id tId to tRadius
      set the textSize of graphic id tId to tSize
   end repeat
   put empty into sHud
   put empty into sPadLook
   ebBrickLooks
   ebLayoutHud
   ebLayoutRival
   ebLayoutBanner
   put sInL into tL
   put sInT into tT
   put sW - sInR into tR
   put sH - sInB into tB
   ebLayoutTitle tL, tT, tR, tB
   ebLayoutHowto tL, tT, tR, tB
   ebLayoutSettings tL, tT, tR, tB
   ebLayoutLevels tL, tT, tR, tB
   ebLayoutPaused tL, tT, tR, tB
   ebLayoutClear tL, tT, tR, tB
   ebLayoutOver tL, tT, tR, tB
   ebLayoutLobby tL, tT, tR, tB
   ebLayoutResult tL, tT, tR, tB
   ebScatterMotes
   ebDrawAll
   unlock screen
end ebLayout

-- Every thing in play drawn where it is (after the arena moved or
-- changed its size, when no frame may come to do it)
private command ebDrawAll
   local i
   repeat with i = 1 to sCount["Ball"]
      if sBall[i]["on"] then
         ebDrawBall i
      end if
   end repeat
   repeat with i = 1 to sCount["Drop"]
      if sDrop[i]["on"] then
         set the loc of graphic id sId["Drop"][i] to round(sAX + sDrop[i]["x"] * sS), round(sAY + sDrop[i]["y"] * sS)
      end if
   end repeat
   repeat with i = 1 to sCount["Bolt"]
      if sBolt[i]["on"] then
         set the loc of graphic id sId["Bolt"][i] to round(sAX + sBolt[i]["x"] * sS), round(sAY + sBolt[i]["y"] * sS)
      end if
   end repeat
   if sWorld then
      ebDrawPaddle
      ebHud
      if sDuel then
         ebDuelDraw true
      end if
   end if
end ebDrawAll

-- The HUD: over the arena (the score, the heat, the lives and the pause
-- button, and under them the level and the chips), or at its sides when
-- they are wide enough
private command ebLayoutHud
   local tL, tR, tT, tX, tY, i, tD, tGap, tBarW, tChipW, tCX, tMini
   if sWide then
      -- a column beside the arena, not at the far edge of a wide window
      put item 1 of sArena - ebU(18) into tR
      put max(sInL + ebU(12), tR - ebU(150)) into tL
      put item 2 of sArena + ebU(4) into tT
      put min(ebU(130), tR - tL) into tBarW
      set the rect of field "Score Label" to tL, tT, tR, tT + ebU(16)
      set the rect of field id sId["Score"] to tL, tT + ebU(16), tR, tT + ebU(50)
      set the rect of field "Best" to tL, tT + ebU(52), tR, tT + ebU(70)
      set the rect of field id sId["Stage"] to tL, tT + ebU(86), tR, tT + ebU(104)
      set the rect of field id sId["Stage Name"] to tL, tT + ebU(104), tR, tT + ebU(122)
      put ebU(11) into tD
      put ebU(5) into tGap
      repeat with i = 1 to sCount["Life"]
         put tL + (i - 1) * (tD + tGap) into tX
         set the rect of graphic id sId["Life"][i] to tX, tT + ebU(134), tX + tD, tT + ebU(134) + tD
      end repeat
      set the textAlign of field id sId["Heat Text"] to "left"
      set the rect of field id sId["Heat Text"] to tL, tT + ebU(158), tL + tBarW, tT + ebU(176)
      put tL, tT + ebU(180), tL + tBarW, tT + ebU(188) into sHeatBar
      repeat with i = 1 to sCount["Chip"]
         put tT + ebU(204) + (i - 1) * ebU(32) into tY
         put tL, tY, tL + tBarW, tY + ebU(26) into sChipRect[i]
      end repeat
      -- at the arena's right: the pause button, and in a duel the clock
      put item 3 of sArena + ebU(18) into tL
      put sW - sInR - ebU(12) into tR
      ebPlaceButton "Pause", tL, tT, tL + ebU(40), tT + ebU(40)
      set the rect of field id sId["Clock"] to tL + ebU(52), tT + ebU(4), max(tL + ebU(62), min(tR, tL + ebU(150))), tT + ebU(36)
      set the textAlign of field id sId["Clock"] to "left"
      set the visible of field "Score Label" to true
      set the visible of field "Best" to true
      set the visible of field id sId["Stage Name"] to true
   else
      put sInL + ebU(12) into tL
      put sW - sInR - ebU(12) into tR
      put sInT + ebU(6) into tT
      set the rect of field id sId["Score"] to tL, tT, tL + ebU(130), tT + ebU(34)
      set the visible of field "Score Label" to false
      set the visible of field "Best" to false
      set the textAlign of field id sId["Heat Text"] to "center"
      set the textAlign of field id sId["Clock"] to "center"
      put ebU(10) into tD
      put ebU(4) into tGap
      put ebU(42) into tChipW
      if sDuel then
         -- a duel: the rival's arena at the right, the clock and the
         -- pause button in the middle, the heat under the score
         put ebU(100) * kArenaW / kArenaH into tMini
         put (tL + ebU(130) + tR - tMini - ebU(8)) div 2 into tCX
         set the rect of field id sId["Clock"] to tCX - ebU(46), tT + ebU(2), tCX + ebU(46), tT + ebU(32)
         ebPlaceButton "Pause", tCX - ebU(17), tT + ebU(36), tCX + ebU(17), tT + ebU(70)
         set the textAlign of field id sId["Heat Text"] to "left"
         set the rect of field id sId["Heat Text"] to tL, tT + ebU(36), tL + ebU(100), tT + ebU(53)
         put tL, tT + ebU(56), tL + ebU(100), tT + ebU(62) into sHeatBar
         set the rect of field id sId["Stage"] to tL, tT + ebU(67), tL + ebU(70), tT + ebU(85)
         set the visible of field id sId["Stage Name"] to false
         repeat with i = 1 to sCount["Chip"]
            put tL + (i - 1) * (tChipW + tGap) into tX
            put tX, tT + ebU(88), tX + tChipW, tT + ebU(110) into sChipRect[i]
         end repeat
      else
         ebPlaceButton "Pause", tR - ebU(36), tT, tR, tT + ebU(36)
         put tR - ebU(46) - sCount["Life"] * tD - (sCount["Life"] - 1) * tGap into tX
         put (tL + ebU(136) + tX - ebU(8)) div 2 into tCX
         put min(ebU(110), tX - ebU(8) - tL - ebU(136)) into tBarW
         repeat with i = 1 to sCount["Life"]
            set the rect of graphic id sId["Life"][i] to tX, tT + ebU(13), tX + tD, tT + ebU(13) + tD
            add tD + tGap to tX
         end repeat
         set the rect of field id sId["Heat Text"] to tCX - tBarW div 2, tT + ebU(1), tCX + tBarW div 2, tT + ebU(19)
         put tCX - tBarW div 2, tT + ebU(23), tCX + tBarW div 2, tT + ebU(30) into sHeatBar
         set the rect of field id sId["Stage"] to tL, tT + ebU(45), tL + ebU(68), tT + ebU(63)
         set the rect of field id sId["Stage Name"] to tL + ebU(70), tT + ebU(45), tL + ebU(190), tT + ebU(63)
         set the visible of field id sId["Stage Name"] to true
         repeat with i = 1 to sCount["Chip"]
            put tR - (i - 1) * (tChipW + tGap) into tX
            put tX - tChipW, tT + ebU(42), tX, tT + ebU(64) into sChipRect[i]
         end repeat
      end if
   end if
   set the visible of field id sId["Clock"] to sDuel is true
   set the rect of graphic id sId["Heat Back"] to sHeatBar
   set the text of field "Best" to "BEST" && ebCommas(sBest)
   repeat with i = 1 to sCount["Chip"]
      set the rect of graphic id sId["Chip Back"][i] to sChipRect[i]
      set the rect of field id sId["Chip Text"][i] to item 1 of sChipRect[i], item 2 of sChipRect[i] + ebU(2), \
            item 3 of sChipRect[i], item 4 of sChipRect[i] - 5
   end repeat
end ebLayoutHud

-- The rival's arena in a duel: at the right of a wide window, under the
-- pause button; at the top right of a narrow one, small
private command ebLayoutRival
   local tL, tR, tT, tB, i, tCol, tRow, tSize, tMini
   if not sDuel then
      exit ebLayoutRival
   end if
   if sWide then
      put item 3 of sArena + ebU(18) into tL
      put sW - sInR - ebU(12) into tR
      put item 2 of sArena + ebU(78) into tT
      put item 4 of sArena into tB
      put max(0.1, min((tR - tL) / kArenaW, (tB - tT) / kArenaH, sS * 0.7)) into sRS
      put tL into sRX
      put tT into sRY
      set the textAlign of field id sId["Rival Name"] to "left"
      set the rect of field id sId["Rival Name"] to tL, tT - ebU(22), tL + ebU(70), tT - ebU(4)
      set the rect of field id sId["Rival Score"] to tL + ebU(70), tT - ebU(22), max(tL + ebU(80), round(tL + kArenaW * sRS)), tT - ebU(4)
   else
      put sW - sInR - ebU(12) into tR
      put sInT + ebU(8) into tT
      put ebU(100) / kArenaH into sRS
      put round(tR - kArenaW * sRS) into sRX
      put tT into sRY
      set the textAlign of field id sId["Rival Name"] to "right"
      set the rect of field id sId["Rival Name"] to sRX - ebU(98), tT + ebU(72), sRX - ebU(8), tT + ebU(88)
      set the rect of field id sId["Rival Score"] to sRX - ebU(98), tT + ebU(88), sRX - ebU(8), tT + ebU(106)
   end if
   set the rect of graphic id sId["Rival Arena"] to sRX - 1, sRY - 1, round(sRX + kArenaW * sRS) + 1, round(sRY + kArenaH * sRS) + 1
   repeat with i = 1 to kCells
      put (i - 1) mod kCols into tCol
      put (i - 1) div kCols into tRow
      set the rect of graphic id sId["Rival Brick"][i] to round(sRX + tCol * kCellW * sRS), round(sRY + (kGridTop + tRow * kCellH) * sRS), \
            max(round(sRX + tCol * kCellW * sRS) + 1, round(sRX + (tCol + 1) * kCellW * sRS) - 1), \
            max(round(sRY + (kGridTop + tRow * kCellH) * sRS) + 1, round(sRY + (kGridTop + (tRow + 1) * kCellH) * sRS) - 1)
   end repeat
   put max(3, round(2 * kBallR * sRS)) into tSize
   repeat with i = 1 to sCount["Rival Ball"]
      set the rect of graphic id sId["Rival Ball"][i] to 0, 0, tSize, tSize
   end repeat
end ebLayoutRival

private command ebLayoutBanner
   local tL, tR, tY
   put item 1 of sArena into tL
   put item 3 of sArena into tR
   put round(sAY + 340 * sS) into tY
   set the rect of graphic "Banner Back" to tL, tY - ebU(40), tR, tY + ebU(38)
   set the rect of field "Banner Text" to tL, tY - ebU(34), tR, tY + ebU(4)
   set the rect of field "Banner Sub" to tL, tY + ebU(8), tR, tY + ebU(30)
end ebLayoutBanner

-- A button of the screens, its shape under it
private command ebPlaceButton pName, pL, pT, pR, pB
   set the rect of button pName to pL, pT, pR, pB
   set the rect of graphic (pName && "Shape") to pL, pT, pR, pB
   set the roundRadius of graphic (pName && "Shape") to min(ebU(14), max(4, (pB - pT) div 2))
   if pName is "Pause" then
      -- its two bars
      set the rect of graphic "Pause Bar 1" to (pL + pR) div 2 - ebU(6), (pT + pB) div 2 - ebU(7), \
            (pL + pR) div 2 - ebU(2), (pT + pB) div 2 + ebU(7)
      set the rect of graphic "Pause Bar 2" to (pL + pR) div 2 + ebU(2), (pT + pB) div 2 - ebU(7), \
            (pL + pR) div 2 + ebU(6), (pT + pB) div 2 + ebU(7)
   end if
end ebPlaceButton

-- A panel pW wide and pH high in the middle of the screen's safe part
-- (pL,pT,pR,pB): its glass and its ember bar. The result is its rect
private function ebPlacePanel pName, pW, pH, pL, pT, pR, pB
   local tL, tT, tCX
   put min(pW, pR - pL - 16) into pW
   put pL + (pR - pL - pW) div 2 into tL
   put max(pT + 4, pT + (pB - pT - pH) div 2) into tT
   put tL + pW div 2 into tCX
   set the rect of graphic (pName && "Glass") to tL, tT, tL + pW, tT + pH
   set the roundRadius of graphic (pName && "Glass") to ebU(18)
   set the rect of graphic (pName && "Trim") to tCX - ebU(22), tT + ebU(10), tCX + ebU(22), tT + ebU(13)
   return tL, tT, tL + pW, tT + pH
end ebPlacePanel

-- Whether a screen is laid out in two columns: a phone on its side
private function ebShort pT, pB
   return sW > sH and pB - pT < ebU(540)
end ebShort

private command ebLayoutTitle pL, pT, pR, pB
   local tTwo, tColW, tCX, tY, tTagH, tLogoH, tButtonsH, tHalf, tL, tR
   put ebShort(pT, pB) into tTwo
   if tTwo then
      put min((pR - pL) div 2 - 32, ebU(340)) into tColW
   else
      put min(pR - pL - 32, ebU(340)) into tColW
   end if
   set the rect of field "Tagline" to 0, 0, tColW, 100
   put the formattedHeight of field "Tagline" into tTagH
   put ebU(70 + 34 + 12 + 3 + 12) + tTagH into tLogoH
   put ebU(56 + 10 + 46 + 10 + 46 + 14 + 20) into tButtonsH
   -- the logo
   if tTwo then
      put pL + (pR - pL) div 4 into tCX
      put pT + (pB - pT - tLogoH) div 2 into tY
   else
      put (pL + pR) div 2 into tCX
      put max(pT + 8, pT + (pB - pT - tLogoH - ebU(26) - tButtonsH) div 2) into tY
   end if
   set the rect of field "Logo Ember" to tCX - tColW div 2, tY, tCX + tColW div 2, tY + ebU(70)
   set the rect of field "Logo Bricks" to tCX - tColW div 2, tY + ebU(70), tCX + tColW div 2, tY + ebU(104)
   set the rect of graphic "Logo Line" to tCX - ebU(60), tY + ebU(116), tCX + ebU(60), tY + ebU(119)
   set the rect of field "Tagline" to tCX - tColW div 2, tY + ebU(131), tCX + tColW div 2, tY + ebU(131) + tTagH
   -- the buttons: Play, and four smaller ones two by two
   if tTwo then
      put pL + 3 * (pR - pL) div 4 into tCX
      put pT + (pB - pT - tButtonsH) div 2 into tY
   else
      put tY + tLogoH + ebU(26) into tY
   end if
   put tCX - tColW div 2 into tL
   put tCX + tColW div 2 into tR
   put (tColW - ebU(10)) div 2 into tHalf
   ebPlaceButton "Play", tL, tY, tR, tY + ebU(56)
   add ebU(66) to tY
   ebPlaceButton "Levels Open", tL, tY, tL + tHalf, tY + ebU(46)
   ebPlaceButton "Duel Open", tR - tHalf, tY, tR, tY + ebU(46)
   add ebU(56) to tY
   ebPlaceButton "Howto Open", tL, tY, tL + tHalf, tY + ebU(46)
   ebPlaceButton "Settings Open", tR - tHalf, tY, tR, tY + ebU(46)
   add ebU(60) to tY
   set the rect of field "Records" to tL, tY, tR, tY + ebU(20)
end ebLayoutTitle

-- How to play: four rows, a picture and its words; two by two on a
-- phone on its side
private command ebLayoutHowto pL, pT, pR, pB
   local tTwo, tW, tH, tRect, tL, tT, tR, i, tColW, tTextW, tX, tY, tRowH, tHeights, tIcon, tPair
   put ebShort(pT, pB) into tTwo
   if tTwo then
      put min(pR - pL - 16, ebU(660)) into tW
      put (tW - ebU(60)) div 2 into tColW
   else
      put min(pR - pL - 16, ebU(360)) into tW
      put tW - ebU(40) into tColW
   end if
   put ebU(40) into tIcon
   put tColW - tIcon - ebU(10) into tTextW
   repeat with i = 1 to 4
      set the rect of field ("Howto Text" && i) to 0, 0, tTextW, 100
      put ebU(20) + the formattedHeight of field ("Howto Text" && i) into tHeights[i]
   end repeat
   if tTwo then
      put max(tHeights[1], tHeights[2]) + max(tHeights[3], tHeights[4]) + ebU(10) into tRowH
   else
      put tHeights[1] + tHeights[2] + tHeights[3] + tHeights[4] + ebU(30) into tRowH
   end if
   put ebU(24 + 30 + 10) + tRowH + ebU(12 + 50 + 18) into tH
   put ebPlacePanel("Howto", tW, tH, pL, pT, pR, pB) into tRect
   put item 1 of tRect into tL
   put item 2 of tRect into tT
   put item 3 of tRect into tR
   set the rect of field "Howto Title" to tL, tT + ebU(24), tR, tT + ebU(54)
   put tT + ebU(64) into tY
   repeat with i = 1 to 4
      if tTwo and i mod 2 is 0 then
         put tL + ebU(20) + tColW + ebU(20) into tX
      else
         put tL + ebU(20) into tX
      end if
      ebPlaceHowtoIcon i, tX, tY, tIcon
      set the rect of field ("Howto Head" && i) to tX + tIcon + ebU(10), tY, tX + tIcon + ebU(10) + tTextW, tY + ebU(19)
      set the rect of field ("Howto Text" && i) to tX + tIcon + ebU(10), tY + ebU(18), tX + tIcon + ebU(10) + tTextW, tY + tHeights[i]
      if tTwo then
         if i mod 2 is 0 then
            add max(tHeights[i - 1], tHeights[i]) + ebU(10) to tY
         end if
      else
         add tHeights[i] + ebU(10) to tY
      end if
   end repeat
   ebPlaceButton "Howto Go", tL + ebU(20), item 4 of tRect - ebU(68), tR - ebU(20), item 4 of tRect - ebU(18)
end ebLayoutHowto

-- The picture of a row of How to play, in a square of pSize at pX,pY: a
-- paddle, a brick, a spark, a dark spark
private command ebPlaceHowtoIcon i, pX, pY, pSize
   local tName, tCY
   put "Howto Icon" && i into tName
   put pY + pSize div 2 into tCY
   switch i
      case 1
         set the rect of graphic tName to pX, tCY - ebU(5), pX + pSize, tCY + ebU(5)
         break
      case 2
         set the rect of graphic tName to pX + ebU(3), tCY - ebU(9), pX + pSize - ebU(3), tCY + ebU(9)
         break
      default
         set the rect of graphic tName to pX + ebU(8), tCY - ebU(12), pX + ebU(32), tCY + ebU(12)
   end switch
end ebPlaceHowtoIcon

private command ebLayoutSettings pL, pT, pR, pB
   local tW, tH, tRect, tL, tT, tR, tY, tHalf, tCredH
   put min(pR - pL - 16, ebU(350)) into tW
   set the rect of field "Credits" to 0, 0, tW - ebU(40), 100
   put the formattedHeight of field "Credits" into tCredH
   put ebU(24 + 34 + 12 + 98 + 8 + 40 + 4) + tCredH + ebU(12 + 50 + 18) into tH
   put ebPlacePanel("Settings", tW, tH, pL, pT, pR, pB) into tRect
   put item 1 of tRect + ebU(20) into tL
   put item 2 of tRect into tT
   put item 3 of tRect - ebU(20) into tR
   put (tR - tL - ebU(10)) div 2 into tHalf
   set the rect of field "Settings Title" to tL, tT + ebU(24), tR, tT + ebU(58)
   put tT + ebU(70) into tY
   ebPlaceButton "Sound", tL, tY, tL + tHalf, tY + ebU(44)
   ebPlaceButton "Buzz", tR - tHalf, tY, tR, tY + ebU(44)
   add ebU(54) to tY
   ebPlaceButton "Effects", tL, tY, tL + tHalf, tY + ebU(44)
   ebPlaceButton "Full", tR - tHalf, tY, tR, tY + ebU(44)
   add ebU(52) to tY
   set the rect of field "Settings Note" to tL, tY, tR, tY + ebU(40)
   add ebU(44) to tY
   set the rect of field "Credits" to tL, tY, tR, tY + tCredH
   ebPlaceButton "Settings Back", tL, item 4 of tRect - ebU(68), tR, item 4 of tRect - ebU(18)
end ebLayoutSettings

-- The levels: four in a row, or eight on a phone on its side
private command ebLayoutLevels pL, pT, pR, pB
   local tTwo, tCols, tRows, tW, tH, tRect, tL, tT, tR, tBW, tBH, i, tX, tY, tGap
   put ebShort(pT, pB) into tTwo
   if tTwo then
      put 8 into tCols
      put min(pR - pL - 16, ebU(580)) into tW
      put ebU(36) into tBH
   else
      put 4 into tCols
      put min(pR - pL - 16, ebU(330)) into tW
      put ebU(40) into tBH
   end if
   put (sLevelCount + tCols - 1) div tCols into tRows
   put ebU(8) into tGap
   put (tW - ebU(40) - (tCols - 1) * tGap) div tCols into tBW
   put ebU(24 + 34 + 10) + tRows * (tBH + tGap) + ebU(22 + 10 + 48 + 18) into tH
   put ebPlacePanel("Levels", tW, tH, pL, pT, pR, pB) into tRect
   put item 1 of tRect + ebU(20) into tL
   put item 2 of tRect into tT
   put item 3 of tRect - ebU(20) into tR
   set the rect of field "Levels Title" to tL, tT + ebU(24), tR, tT + ebU(58)
   repeat with i = 1 to sLevelCount
      put tL + ((i - 1) mod tCols) * (tBW + tGap) into tX
      put tT + ebU(68) + ((i - 1) div tCols) * (tBH + tGap) into tY
      ebPlaceButton "Level" && i, tX, tY, tX + tBW, tY + tBH
   end repeat
   put tT + ebU(68) + tRows * (tBH + tGap) into tY
   set the rect of field "Levels Note" to tL, tY, tR, tY + ebU(26)
   ebPlaceButton "Levels Back", tL, item 4 of tRect - ebU(66), tR, item 4 of tRect - ebU(18)
end ebLayoutLevels

-- The pause's panel: Resume and three buttons under it, or in a duel
-- (which has no restart and does not wait for the settings) only the
-- way out
private command ebLayoutPaused pL, pT, pR, pB
   local tRect, tL, tT, tR, tY, tName, tList
   if sDuel then
      put "Pause Home" into tList
   else
      put "Restart,Pause Settings,Pause Home" into tList
   end if
   put ebPlacePanel("Paused", ebU(290), ebU(24 + 34 + 12 + 52 + 54 * the number of items of tList + 18), pL, pT, pR, pB) into tRect
   put item 1 of tRect + ebU(20) into tL
   put item 2 of tRect into tT
   put item 3 of tRect - ebU(20) into tR
   set the rect of field "Paused Title" to tL, tT + ebU(24), tR, tT + ebU(58)
   put tT + ebU(70) into tY
   ebPlaceButton "Resume", tL, tY, tR, tY + ebU(52)
   add ebU(62) to tY
   repeat for each item tName in tList
      ebPlaceButton tName, tL, tY, tR, tY + ebU(44)
      add ebU(54) to tY
   end repeat
end ebLayoutPaused

private command ebLayoutClear pL, pT, pR, pB
   local tRect, tL, tT, tR, tY, tCX
   put ebPlacePanel("Clear", ebU(300), ebU(24 + 34 + 4 + 20 + 14 + 66 + 8 + 46 + 14 + 52 + 20), pL, pT, pR, pB) into tRect
   put item 1 of tRect + ebU(20) into tL
   put item 2 of tRect into tT
   put item 3 of tRect - ebU(20) into tR
   put (tL + tR) div 2 into tCX
   set the rect of field "Clear Title" to tL, tT + ebU(24), tR, tT + ebU(58)
   set the rect of field "Clear Name" to tL, tT + ebU(62), tR, tT + ebU(82)
   put tT + ebU(96) into tY
   set the rect of field "Clear Lines" to tL + ebU(14), tY, tCX + ebU(30), tY + ebU(66)
   set the rect of field "Clear Values" to tCX + ebU(30), tY, tR - ebU(14), tY + ebU(66)
   add ebU(74) to tY
   set the rect of field "Clear Total" to tL, tY, tR, tY + ebU(46)
   ebPlaceButton "Next", tL, item 4 of tRect - ebU(72), tR, item 4 of tRect - ebU(20)
end ebLayoutClear

private command ebLayoutOver pL, pT, pR, pB
   local tRect, tL, tT, tR, tY
   put ebPlacePanel("Over", ebU(310), ebU(24 + 30 + 6 + 52 + 4 + 20 + 8 + 40 + 14 + 52 + 10 + 44 + 20), pL, pT, pR, pB) into tRect
   put item 1 of tRect + ebU(20) into tL
   put item 2 of tRect into tT
   put item 3 of tRect - ebU(20) into tR
   set the rect of field "Over Title" to tL, tT + ebU(24), tR, tT + ebU(54)
   set the rect of field "Final" to tL, tT + ebU(60), tR, tT + ebU(112)
   set the rect of field "Best Note" to tL, tT + ebU(116), tR, tT + ebU(136)
   set the rect of field "Stats" to tL, tT + ebU(144), tR, tT + ebU(184)
   put tT + ebU(198) into tY
   ebPlaceButton "Again", tL, tY, tR, tY + ebU(52)
   ebPlaceButton "Over Home", tL, tY + ebU(62), tR, tY + ebU(106)
end ebLayoutOver

-- The lobby, for its step (ebLobbyKind): a name and Go online over Play
-- by code; the players who are online, with Quick match and Play a
-- friend; a challenge, with Accept; its words, with Host and Join; a code
-- to send, with Copy; a place for a code, with Paste; or a line while
-- something is made. A phone on its side has the name, and the players,
-- beside the buttons
private command ebLayoutLobby pL, pT, pR, pB
   local tW, tH, tRect, tL, tT, tR, tY, tTextH, tKind, tName, tBoxH, tGo, tShow
   local tTwo, tMost, tNoteH, tMid, tBackT, tRowT, tRowR, tOwn, i, tRoom
   put ebLobbyKind() into tKind
   put ((tKind is "start" or tKind is "list") and ebShort(pT, pB)) into tTwo
   if tTwo then
      put min(pR - pL - 16, ebU(620)) into tW
   else
      put min(pR - pL - 16, ebU(380)) into tW
   end if
   -- (the host's first step goes on to the second, and a room's to a
   -- friend's; the answer only waits)
   put (tKind is "take" or sLobby is "host-invite" or sLobby is "room") into tGo
   set the rect of field "Lobby Text" to 0, 0, tW - ebU(40), 100
   put the formattedHeight of field "Lobby Text" into tTextH
   put ebU(38) into tNoteH
   -- a room's code is six letters, large, in the middle of a box a line
   -- high; a code of the swap fills a taller one, small
   put (sLobby is "room" or sLobby is "room-take") into tRoom
   if tRoom then
      set the textSize of field "Code" to max(9, ebU(24))
      set the textAlign of field "Code" to "center"
      set the textStyle of field "Code" to "bold"
   else
      set the textSize of field "Code" to max(9, ebU(11))
      set the textAlign of field "Code" to "left"
      set the textStyle of field "Code" to "plain"
   end if
   if tRoom or ebShort(pT, pB) then
      put ebU(56) into tBoxH
   else
      put ebU(92) into tBoxH
   end if
   put ebNetRowsMost() into tMost
   switch tKind
      case "start"
         -- (what going online shows is said whole, whatever lines it takes)
         if tTwo then
            set the rect of field "Lobby Note" to 0, 0, (tW - ebU(60)) div 2, 100
         else
            set the rect of field "Lobby Note" to 0, 0, tW - ebU(40), 100
         end if
         put max(ebU(38), the formattedHeight of field "Lobby Note") into tNoteH
         if tTwo then
            put ebU(64) + max(ebU(24 + 48) + tNoteH, ebU(52 + 8 + 44 + 8 + 40)) + ebU(18) into tH
         else
            put ebU(64) + tTextH + ebU(10 + 24 + 48 + 60 + 52) + tNoteH + ebU(6 + 40 + 18) into tH
         end if
         break
      case "list"
         if tTwo then
            put ebU(64 + 26) + tMost * ebU(46) + ebU(4 + 38 + 18) into tH
         else
            put ebU(64 + 26) + tMost * ebU(46) + ebU(4 + 62 + 52 + 38 + 6 + 40 + 18) into tH
         end if
         break
      case "asked"
         put ebU(64) + tTextH + ebU(12 + 62 + 52 + 38 + 18) into tH
         break
      case "choose"
         put ebU(64) + tTextH + ebU(12 + 52 + 10 + 44 + 8 + 38 + 6 + 40 + 18) into tH
         break
      case "send"
      case "take"
         put ebU(64 + 26) + tBoxH + ebU(8 + 48 + 8 + 38 + 6 + 40 + 18) into tH
         if tGo then
            add ebU(44 + 8) to tH
         end if
         break
      case "busy"
         put ebU(64 + 34 + 38 + 6 + 40 + 18) into tH
         break
      default
         put ebU(64) + tTextH + ebU(14 + 40 + 18) into tH
   end switch
   put ebPlacePanel("Lobby", tW, tH, pL, pT, pR, pB) into tRect
   put item 1 of tRect + ebU(20) into tL
   put item 2 of tRect into tT
   put item 3 of tRect - ebU(20) into tR
   put (tL + tR) div 2 into tMid
   put item 4 of tRect - ebU(58) into tBackT
   set the rect of field "Lobby Title" to tL, tT + ebU(24), tR, tT + ebU(58)
   put tT + ebU(64) into tY
   set the rect of field "Lobby Text" to tL, tY, tR, tY + tTextH
   -- (the name's step and the players' place their note and Back
   -- themselves: beside the rest on a phone on its side)
   put false into tOwn
   switch tKind
      case "start"
         put true into tOwn
         set the textAlign of field "Lobby Step" to "left"
         if tTwo then
            set the rect of field "Lobby Step" to tL, tY + ebU(2), tMid - ebU(10), tY + ebU(22)
            ebPlaceTyped "Name", "Name Back", tL, tY + ebU(24), tMid - ebU(10), tY + ebU(64), true
            set the rect of field "Lobby Note" to tL, tY + ebU(72), tMid - ebU(10), tY + ebU(72) + tNoteH
            ebPlaceButton "Net Go", tMid + ebU(10), tY, tR, tY + ebU(52)
            ebPlaceButton "Codes Open", tMid + ebU(10), tY + ebU(60), tR, tY + ebU(104)
            ebPlaceButton "Lobby Back", tMid + ebU(10), tY + ebU(112), tR, tY + ebU(152)
         else
            add tTextH + ebU(10) to tY
            set the rect of field "Lobby Step" to tL, tY + ebU(2), tR, tY + ebU(22)
            add ebU(24) to tY
            ebPlaceTyped "Name", "Name Back", tL, tY, tR, tY + ebU(40), true
            add ebU(48) to tY
            ebPlaceButton "Net Go", tL, tY, tR, tY + ebU(52)
            add ebU(60) to tY
            ebPlaceButton "Codes Open", tL, tY, tR, tY + ebU(44)
            add ebU(52) to tY
            set the rect of field "Lobby Note" to tL, tY, tR, tY + tNoteH
            ebPlaceButton "Lobby Back", tL, tBackT, tR, tBackT + ebU(40)
         end if
         break
      case "list"
         put true into tOwn
         set the textAlign of field "Lobby Step" to "left"
         if tTwo then
            put tMid - ebU(10) into tRowR
         else
            put tR into tRowR
         end if
         set the rect of field "Lobby Step" to tL, tY + ebU(2), tRowR, tY + ebU(22)
         put tY + ebU(26) into tRowT
         repeat with i = 1 to tMost
            ebPlaceButton "Who" && i, tL, tRowT + (i - 1) * ebU(46), tRowR, tRowT + (i - 1) * ebU(46) + ebU(40)
         end repeat
         -- (and, in its place, each row's words)
         ebNetRowsLook
         -- (with nobody there, the words say so where the players would be)
         set the rect of field "Lobby Text" to tL, tRowT + ebU(8), tRowR, tRowT + tMost * ebU(46) - ebU(8)
         if tTwo then
            ebPlaceButton "Quick", tMid + ebU(10), tY, tR, tY + ebU(48)
            ebPlaceButton "Friend", tMid + ebU(10), tY + ebU(56), tR, tY + ebU(96)
            ebPlaceButton "Lobby Back", tMid + ebU(10), tY + ebU(104), tR, tY + ebU(144)
            put tRowT + tMost * ebU(46) + ebU(4) into tY
         else
            put tRowT + tMost * ebU(46) + ebU(4) into tY
            ebPlaceButton "Quick", tL, tY, tR, tY + ebU(52)
            add ebU(62) to tY
            ebPlaceButton "Friend", tL, tY, tR, tY + ebU(44)
            add ebU(52) to tY
            ebPlaceButton "Lobby Back", tL, tBackT, tR, tBackT + ebU(40)
         end if
         set the rect of field "Lobby Note" to tL, tY, tR, tY + tNoteH
         break
      case "asked"
         add tTextH + ebU(12) to tY
         ebPlaceButton "Accept", tL, tY, tR, tY + ebU(52)
         add ebU(62) to tY
         ebPlaceButton "Decline", tL, tY, tR, tY + ebU(44)
         add ebU(52) to tY
         break
      case "choose"
         add tTextH + ebU(12) to tY
         ebPlaceButton "Host", tL, tY, tR, tY + ebU(52)
         add ebU(62) to tY
         ebPlaceButton "Join", tL, tY, tR, tY + ebU(44)
         add ebU(52) to tY
         break
      case "send"
      case "take"
         set the textAlign of field "Lobby Step" to "left"
         set the rect of field "Lobby Step" to tL, tY + ebU(2), tR, tY + ebU(22)
         add ebU(26) to tY
         ebPlaceTyped "Code", "Code Back", tL, tY, tR, tY + tBoxH, tRoom
         add tBoxH + ebU(8) to tY
         if tKind is "send" then
            ebPlaceButton "Code Copy", tL, tY, tR, tY + ebU(48)
         else
            ebPlaceButton "Code Paste", tL, tY, tR, tY + ebU(48)
         end if
         add ebU(56) to tY
         if tGo then
            ebPlaceButton "Code Go", tL, tY, tR, tY + ebU(44)
            add ebU(52) to tY
         end if
         break
      case "busy"
         set the textAlign of field "Lobby Step" to "center"
         set the rect of field "Lobby Step" to tL, tY + ebU(6), tR, tY + ebU(26)
         add ebU(34) to tY
         break
      default
         add tTextH + ebU(14) to tY
   end switch
   if not tOwn then
      set the rect of field "Lobby Note" to tL, tY, tR, tY + ebU(38)
      ebPlaceButton "Lobby Back", tL, tBackT, tR, tBackT + ebU(40)
   end if
   put (tKind is "choose" or tKind is "none" or tKind is "asked") into tShow
   if tKind is "start" and not tTwo then
      put true into tShow
   else if tKind is "list" and sLob["rows"] is empty then
      put true into tShow
   end if
   set the visible of field "Lobby Text" to tShow
   set the visible of field "Lobby Step" to (tKind is among the items of "send,take,busy,start,list")
   set the visible of field "Lobby Note" to (tKind is not "none")
   set the visible of field "Code" to (tKind is "send" or tKind is "take")
   set the visible of graphic "Code Back" to (tKind is "send" or tKind is "take")
   set the visible of field "Name" to (tKind is "start")
   set the visible of graphic "Name Back" to (tKind is "start")
   repeat for each item tName in "Host,Join,Code Copy,Code Paste,Code Go,Net Go,Codes Open,Quick,Friend,Accept,Decline,Lobby Back"
      switch tName
         case "Host"
         case "Join"
            put (tKind is "choose") into tShow
            break
         case "Code Copy"
            put (tKind is "send") into tShow
            break
         case "Code Paste"
            put (tKind is "take") into tShow
            break
         case "Net Go"
         case "Codes Open"
            put (tKind is "start") into tShow
            break
         case "Quick"
         case "Friend"
            put (tKind is "list") into tShow
            break
         case "Accept"
         case "Decline"
            put (tKind is "asked") into tShow
            break
         case "Lobby Back"
            -- (a challenge is left by its Not now)
            put (tKind is not "asked") into tShow
            break
         default
            put tGo into tShow
      end switch
      set the visible of button tName to tShow
      set the visible of graphic (tName && "Shape") to tShow
   end repeat
   repeat with i = 1 to kNetRows
      put (tKind is "list" and i <= tMost and line i of sLob["rows"] is not empty) into tShow
      set the visible of button ("Who" && i) to tShow
      set the visible of graphic ("Who" && i && "Shape") to tShow
   end repeat
end ebLayoutLobby

-- A field for typing over its box: all of the box, or (pOne) a line in
-- the middle of its height
private command ebPlaceTyped pField, pBox, pL, pT, pR, pB, pOne
   local tHigh, tTop
   set the rect of graphic pBox to pL, pT, pR, pB
   if pOne is true then
      put max(the formattedHeight of field pField, the effective textHeight of field pField + 12) into tHigh
      put min(pB - pT - 4, tHigh) into tHigh
      put (pT + pB - tHigh) div 2 into tTop
      set the rect of field pField to pL + 2, tTop, pR - 2, tTop + tHigh
   else
      set the rect of field pField to pL + 2, pT + 2, pR - 2, pB - 2
   end if
end ebPlaceTyped

-- A duel's result: who won, the two scores, a line, and Rematch over
-- Leave (only Leave when the rival is gone)
private command ebLayoutResult pL, pT, pR, pB
   local tRect, tL, tT, tR, tY, tGone, tH
   put sNet2["gone"] is true into tGone
   put ebU(24 + 38 + 8 + 28 + 28 + 8 + 40 + 12 + 44 + 20) into tH
   if not tGone then
      add ebU(52 + 10) to tH
   end if
   put ebPlacePanel("Result", ebU(320), tH, pL, pT, pR, pB) into tRect
   put item 1 of tRect + ebU(20) into tL
   put item 2 of tRect into tT
   put item 3 of tRect - ebU(20) into tR
   set the rect of field "Result Title" to tL, tT + ebU(24), tR, tT + ebU(62)
   set the rect of field "Result You" to tL, tT + ebU(70), tR, tT + ebU(98)
   set the rect of field "Result Them" to tL, tT + ebU(98), tR, tT + ebU(126)
   set the rect of field "Result Note" to tL, tT + ebU(134), tR, tT + ebU(174)
   put tT + ebU(186) into tY
   if not tGone then
      ebPlaceButton "Rematch", tL, tY, tR, tY + ebU(52)
      add ebU(62) to tY
   end if
   ebPlaceButton "Result Home", tL, tY, tR, tY + ebU(44)
end ebLayoutResult

----------------------------------------------------------------------
-- The duel
--
-- Two players, each at a wall of their own, for three minutes: most
-- points wins. Each sees the other's arena, small, beside their own. A
-- lost ball costs points and a moment, not a life; a wall cleared is a
-- bonus and the next wall at once; and the heat is a weapon: as it
-- reaches x3, x4 and x5 the rival gets a fast ball, a small paddle, a
-- row of bricks more.
--
-- The two are linked by DataChannelXT, peer to peer (WebRTC's data
-- channels: libdatachannel on a desktop, the browser's own in a page),
-- with no server of the game's. What each needs to find the other (its
-- "description", with the ways to reach it) goes between them through
-- the lobby, in a second or two (see "The online lobby", below); or,
-- where there is no lobby, the players carry it themselves, as two
-- codes: the host's invite to the guest, the guest's answer back, in any
-- message. A code is good for a minute or so, because the guest's side
-- starts to look for the host as its answer is made, and gives up when
-- no one comes: that wait is what the lobby is there to take away. A
-- public STUN server (kDuelIce) tells each its address as the internet
-- sees it; nothing of the game goes through it. Where DataChannelXT is
-- not (an Android app, for now), the lobby says so.
--
-- Over the link go lines of text, a letter and what it says:
--   H 1          hello, each to the other as the link opens: the version
--   S 4071       the host: a match begins (the number picks its first
--                wall)
--   T 1250,3,2,160,56|120,300;44,81|..11TT....(140 places)
--                my arena, ten times a second: the score, the wall, the
--                heat's bonus, the paddle's middle and width; the balls;
--                the bricks, a place each
--   A fast       an attack: fast, small or junk
--   E 4310       my clock ran out: my last score
--   R            I want a rematch
--   B            I am leaving
-- The pictures (T) go by a channel of their own that never waits for a
-- lost one; the rest by one that loses nothing. What comes from the
-- rival is read as a stranger's: every number checked, every place of
-- the bricks one of the kinds or none.

-- Whether a link can be made here: DataChannelXT answers
function ebDuelCan
   local tVersion, tError
   if sRtc is empty then
      put "no" into sRtc
      try
         put dcLibraryVersion() into tVersion
         if tVersion is not empty then
            put "yes" into sRtc
         end if
      catch tError
      end try
   end if
   return sRtc is "yes"
end ebDuelCan

-- The title's button: the lobby
command ebDuelOpen
   set the defaultStack to the short name of me
   lock screen
   ebDuelDrop
   ebNetStop
   put false into sDuel
   put "lobby" into sMode
   if not ebDuelCan() then
      put "none" into sLobby
   else if ebNetCan() then
      -- (the lobby's first step: a name, and Go online)
      put "start" into sLobby
      ebNetNameShow
   else
      put "choose" into sLobby
   end if
   ebLobbyLook empty
   ebShowScreen "lobby"
   unlock screen
end ebDuelOpen

-- The lobby's and the result's buttons
command ebDuelPress pName
   set the defaultStack to the short name of me
   switch pName
      case "Host"
         ebDuelHost
         break
      case "Join"
         if sLobby is "choose" then
            put "join-invite" into sLobby
            set the text of field "Code" to empty
            ebLobbyLook empty
         end if
         break
      case "Code Copy"
         ebLobbyCopy
         break
      case "Code Paste"
         ebLobbyPaste
         break
      case "Code Go"
         ebLobbyGo
         break
      case "Lobby Back"
      case "Result Home"
         ebDuelLeave
         break
      case "Rematch"
         ebDuelRematch
         break
      case "Net Go"
         ebNetGo
         break
      case "Codes Open"
         if sLobby is "start" then
            put "choose" into sLobby
            ebLobbyLook empty
         end if
         break
      case "Quick"
         ebNetQuick
         break
      case "Friend"
         ebNetFriend
         break
      case "Accept"
         ebNetAccept
         break
      case "Decline"
         ebNetDecline
         break
   end switch
end ebDuelPress

-- What the lobby's step shows: "start" (a name, Go online and Play by
-- code), "list" (the players who are online), "asked" (a challenge, to
-- accept or not), "choose" (its words, Host and Join), "send" (a code to
-- copy), "take" (a place to paste one), "busy" (a line while something is
-- made), or "none" (no duel here)
private function ebLobbyKind
   switch sLobby
      case "start"
         return "start"
      case "online"
         return "list"
      case "asked"
         return "asked"
      case "choose"
         return "choose"
      case "host-invite"
      case "join-answer"
      case "room"
         return "send"
      case "host-answer"
      case "join-invite"
      case "room-take"
         return "take"
      case "host-make"
      case "join-make"
      case "linking"
      case "linked"
      case "net-wait"
      case "quick"
      case "asking"
      case "net-link"
      case "room-in"
         return "busy"
   end switch
   return "none"
end ebLobbyKind

-- The lobby's words and buttons for its step, and pNote under them (or
-- the step's own)
private command ebLobbyLook pNote
   local tText, tStep, tNote, tGo, tCopy, tTake, tRival
   lock screen
   put false into tTake
   put toUpper(sLob["rival"]) into tRival
   switch sLobby
      case "start"
         if sInvite is empty then
            put "Three minutes, a wall each, and most points wins. Build your heat and your rival gets trouble." into tText
            set the label of button "Net Go" to "GO ONLINE"
         else
            put "A friend waits for you in room" && sInvite & ". Three minutes, a wall each, and most points wins." into tText
            set the label of button "Net Go" to "JOIN YOUR FRIEND"
         end if
         put "YOUR NAME" into tStep
         put "Going online shows this name to the other players. The lobby is on public Nostr relays, which see your internet address." into tNote
         break
      case "net-wait"
         put "FINDING THE LOBBY..." into tStep
         put "A moment." into tNote
         break
      case "online"
         if sLob["count"] > 0 then
            put "IN THE LOBBY:" && sLob["count"] into tStep
            put "You are" && sName & ". Tap a player to challenge them." into tNote
         else
            put "THE LOBBY" into tStep
            put "No one else is here yet. Play a friend, or wait: players are listed as they arrive." into tText
            put "You are" && sName & "." into tNote
         end if
         if sLob["said"] is not empty and sLob["clock"] < sLob["saidUntil"] then
            put sLob["said"] into tNote
         end if
         break
      case "quick"
         put "LOOKING FOR A RIVAL..." into tStep
         put "The first player who wants a quick match is yours." into tNote
         break
      case "asking"
         put "CHALLENGING" && tRival & "..." into tStep
         put "Waiting for an answer." into tNote
         break
      case "asked"
         put tRival && "challenges you to a duel." into tText
         put "Three minutes, a wall each, and most points wins." into tNote
         break
      case "net-link"
         put "CONNECTING TO" && tRival & "..." into tStep
         put "This can take a few seconds." into tNote
         break
      case "room"
         put "YOUR ROOM" into tStep
         if sPlatform is "web" then
            put "COPY THE LINK" into tCopy
            put "Send the link to a friend. The duel starts when they open it." into tNote
         else
            put "COPY THE CODE" into tCopy
            put "Send the code to a friend. The duel starts when they join." into tNote
         end if
         put "I HAVE A CODE" into tGo
         break
      case "room-take"
         put "A FRIEND'S ROOM" into tStep
         put "JOIN THE ROOM" into tGo
         put "Type or paste the code your friend sent." into tNote
         put true into tTake
         break
      case "room-in"
         put "ROOM" && sLob["code"] into tStep
         put "Waiting for your friend to arrive." into tNote
         break
      case "choose"
         put "Three minutes, a wall each, and most points wins. Build your heat and your rival gets trouble." & return & return & \
               "One of you hosts and sends an invite. The other joins with it and sends an answer back." into tText
         break
      case "host-make"
         put "MAKING YOUR INVITE..." into tStep
         put "A moment." into tNote
         break
      case "host-invite"
         put "STEP 1 OF 2: SEND THIS INVITE" into tStep
         put "COPY THE INVITE" into tCopy
         put "NEXT" into tGo
         put "Send it to your rival in any message, then go on." into tNote
         break
      case "host-answer"
         put "STEP 2 OF 2: THE ANSWER" into tStep
         put "CONNECT" into tGo
         put "Paste the answer your rival sent back." into tNote
         put true into tTake
         break
      case "join-invite"
         put "STEP 1 OF 2: THE INVITE" into tStep
         put "MAKE MY ANSWER" into tGo
         put "Paste the invite your rival sent." into tNote
         put true into tTake
         break
      case "join-make"
         put "MAKING YOUR ANSWER..." into tStep
         put "A moment." into tNote
         break
      case "join-answer"
         put "STEP 2 OF 2: SEND THIS ANSWER BACK" into tStep
         put "COPY THE ANSWER" into tCopy
         put "The duel starts when your rival pastes it. Be quick: it lasts a minute or so." into tNote
         break
      case "linking"
         put "CONNECTING..." into tStep
         put "This can take a few seconds." into tNote
         break
      case "linked"
         put "CONNECTED" into tStep
         put "Here we go." into tNote
         break
      default
         put "A duel links two players directly, over the internet. This copy of the game cannot make that link: play in a browser, or in OXT-Beyond on a desktop." into tText
   end switch
   if tCopy is not empty and sPlatform is "web" and sPointer is "touch" then
      -- (a phone's share sheet)
      put "SEND" && word 2 to -1 of tCopy into tCopy
   end if
   if pNote is not empty then
      put pNote into tNote
   end if
   set the text of field "Lobby Text" to tText
   set the text of field "Lobby Step" to tStep
   set the text of field "Lobby Note" to tNote
   if tCopy is not empty then
      set the label of button "Code Copy" to tCopy
   end if
   if tGo is not empty then
      set the label of button "Code Go" to tGo
   end if
   -- a code to send is not typed over; a place for one is, and the name
   set the lockText of field "Code" to not tTake
   set the traversalOn of field "Code" to tTake
   set the lockText of field "Name" to (sLobby is not "start")
   set the traversalOn of field "Name" to (sLobby is "start")
   if not tTake and sLobby is not "start" then
      try
         focus on nothing
      end try
   end if
   ebLayoutLobby sInL, sInT, sW - sInR, sH - sInB
   unlock screen
end ebLobbyLook

-- A peer for a link: a host's, with its two channels, or a guest's,
-- which takes the host's description (pSdp). Empty when it is made; else
-- why not ("refused": the description could not be read), and nothing is
-- left of it
private function ebDuelPeer pRole, pSdp
   local tPeer, tChan, tResult, tWhy, tError
   ebDuelDrop
   put empty into tWhy
   try
      put dcCreatePeer(kDuelIce) into tPeer
      if tPeer is not a number or tPeer <= 0 then
         put "no peer" into tWhy
      else
         put true into sRtcUsed
         put tPeer into sNet2["peer"]
         if pRole is "host" then
            put dcCreateChannel(tPeer, "eb") into tChan
            if tChan is not a number or tChan <= 0 then
               put "no channel" into tWhy
            else
               put tChan into sNet2["chan"]
               -- (the pictures: out of order, and never sent again)
               put dcCreateChannelEx(tPeer, "ebs", empty, true, 0, -1, false, -1) into sNet2["fast"]
            end if
         else
            put dcSetRemoteDescription(tPeer, pSdp, "offer") into tResult
            if tResult is not a number or tResult < 0 then
               put "refused" into tWhy
            end if
         end if
      end if
   catch tError
      put "error" into tWhy
   end try
   if tWhy is not empty then
      ebDuelDrop
      return tWhy
   end if
   put true into sNet2["on"]
   put pRole into sNet2["role"]
   put sClock into sNet2["since"]
   return empty
end ebDuelPeer

-- Host: a peer, its two channels, and (when the ways to reach it are
-- found: ebDuelMakeCode) the invite
private command ebDuelHost
   local tWhy
   if sLobby is not "choose" then
      exit ebDuelHost
   end if
   put ebDuelPeer("host", empty) into tWhy
   if tWhy is not empty then
      ebLobbyLook "Could not start a link here." && ebDuelWhy()
      exit ebDuelHost
   end if
   put "host-make" into sLobby
   ebLobbyLook empty
end ebDuelHost

-- Join: a peer that takes the host's invite and (ebDuelMakeCode) makes
-- the answer to it
private command ebDuelJoin pSdp
   local tWhy
   put ebDuelPeer("guest", pSdp) into tWhy
   if tWhy is "refused" then
      ebLobbyLook "That invite could not be read. Ask your rival for a new one."
      exit ebDuelJoin
   end if
   if tWhy is not empty then
      ebLobbyLook "Could not start a link here." && ebDuelWhy()
      exit ebDuelJoin
   end if
   put "join-make" into sLobby
   ebLobbyLook empty
end ebDuelJoin

-- What DataChannelXT says went wrong, in a line (or nothing)
private function ebDuelWhy
   local tWhy, tError
   try
      put line 1 of dcLastError() into tWhy
   catch tError
      put empty into tWhy
   end try
   if the length of tWhy > 90 then
      put char 1 to 90 of tWhy into tWhy
   end if
   return tWhy
end ebDuelWhy

-- While a code is made: when the peer has found the ways to reach it
-- (or, on a network that holds that up, after some seconds with what it
-- has), its description becomes the code; or, in the lobby, goes to the
-- rival through it
private command ebDuelMakeCode
   local tPeer, tDone, tSdp, tKind, tError
   put sNet2["peer"] into tPeer
   put sNet2["gathered"] is true into tDone
   if not tDone then
      try
         put dcGatheringState(tPeer) is 2 into tDone
      catch tError
      end try
   end if
   if not tDone and sNet2["described"] is true and sClock - sNet2["since"] > kDuelGather then
      put true into tDone
   end if
   if tDone then
      try
         put dcLocalDescription(tPeer) into tSdp
      catch tError
         put empty into tSdp
      end try
   end if
   if tSdp is empty then
      if sClock - sNet2["since"] > kDuelMakeFor then
         if sNet2["via"] is "net" then
            ebDuelGone "Could not start a link here." && ebDuelWhy()
         else
            ebDuelGone "Could not make a code here: the link did not start." && ebDuelWhy()
         end if
      end if
      exit ebDuelMakeCode
   end if
   if sNet2["via"] is "net" then
      -- (a link made in the lobby: the description goes through it)
      ebNetDescribed tSdp
      exit ebDuelMakeCode
   end if
   if sNet2["role"] is "host" then
      put "O" into tKind
      put "host-invite" into sLobby
   else
      put "A" into tKind
      put "join-answer" into sLobby
   end if
   put ebDuelEncode(tKind, tSdp) into sNet2["code"]
   set the text of field "Code" to ebDuelLines(sNet2["code"])
   ebLobbyLook empty
end ebDuelMakeCode

-- A code in lines of forty, for its box (a field breaks a line only at
-- a space, and a code has none). Copy takes the code itself; and one
-- pasted with line breaks in it is read all the same
private function ebDuelLines pCode
   local tOut, i
   repeat with i = 1 to the length of pCode step 40
      put char i to i + 39 of pCode & return after tOut
   end repeat
   delete last char of tOut
   return tOut
end ebDuelLines

-- A description as a code: "EB1", O for an invite or A for an answer,
-- how it is packed (z: compressed; r: as it is), a colon, and it in the
-- base64 that a link can carry (- and _ for + and /, no = at its end)
function ebDuelEncode pKind, pSdp
   local tData, tHow, tError
   put "r" into tHow
   put textEncode(pSdp, "UTF-8") into tData
   try
      put compress(tData) into tData
      put "z" into tHow
   catch tError
      put textEncode(pSdp, "UTF-8") into tData
      put "r" into tHow
   end try
   put base64Encode(tData) into tData
   replace return with empty in tData
   replace numToChar(13) with empty in tData
   replace "+" with "-" in tData
   replace "/" with "_" in tData
   replace "=" with empty in tData
   return kDuelCode & pKind & tHow & ":" & tData
end ebDuelEncode

-- The description in a code of kind pKind (O or A); or, when it is not
-- one, "!" and why, for the lobby to say
function ebDuelDecode pCode, pKind
   local tKind, tHow, tData, tSdp, tError
   replace return with empty in pCode
   replace numToChar(13) with empty in pCode
   replace space with empty in pCode
   replace tab with empty in pCode
   if pCode is empty then
      return "!Paste the code first."
   end if
   if the length of pCode > 24000 or char 1 to (the length of kDuelCode) of pCode is not kDuelCode then
      return "!That is not a code of this game. Copy all of it, from EB1 to its end."
   end if
   put char (the length of kDuelCode + 1) of pCode into tKind
   put char (the length of kDuelCode + 2) of pCode into tHow
   if char (the length of kDuelCode + 3) of pCode is not ":" or tKind is not among the items of "O,A" then
      return "!That is not a code of this game. Copy all of it, from EB1 to its end."
   end if
   if tKind is not pKind then
      if pKind is "O" then
         return "!That is an answer. Paste the invite your rival sent."
      end if
      return "!That is an invite. Paste the answer your rival sent back."
   end if
   put char (the length of kDuelCode + 4) to -1 of pCode into tData
   replace "-" with "+" in tData
   replace "_" with "/" in tData
   repeat while the length of tData mod 4 is not 0
      put "=" after tData
   end repeat
   put empty into tSdp
   try
      put base64Decode(tData) into tData
      if tHow is "z" then
         put ebDuelUnpack(tData) into tData
      end if
      put textDecode(tData, "UTF-8") into tSdp
   catch tError
      put empty into tSdp
   end try
   if tSdp is empty or the length of tSdp > kDuelMost or "v=0" is not in tSdp then
      return "!That code is not whole. Copy all of it and paste it again."
   end if
   return tSdp
end ebDuelDecode

-- What compress packed into pData; empty when pData is not all of it.
-- The last four bytes of what compress makes say how long the thing it
-- packed was, and the four before them are a sum of it (a CRC-32). The
-- engine's decompress makes room for the whole of that length before it
-- reads a byte, whatever the length is: half a code, as a message cut it
-- or a finger copied it, ends anywhere, and the half in the game's own
-- test had it make room for 1,208,859,709 bytes, which a desktop
-- survives and a phone does not (Android stopped the game). So the
-- length is read here first, and nothing that says it is longer than a
-- description can be is unpacked at all; and what was unpacked is the
-- description only when its sum is the one the code carries
private function ebDuelUnpack pData
   local tLength, tText
   if the number of bytes of pData < 18 then
      return empty
   end if
   put ebDuelNumber(byte -4 to -1 of pData) into tLength
   if tLength < 1 or tLength > kDuelMost then
      return empty
   end if
   put decompress(pData) into tText
   if the number of bytes of tText is not tLength then
      return empty
   end if
   if ebDuelSum(tText) is not ebDuelNumber(byte -8 to -5 of pData) then
      return empty
   end if
   return tText
end ebDuelUnpack

-- Four bytes as the number they are, the smallest part first
private function ebDuelNumber pBytes
   local tNumber, i
   put 0 into tNumber
   repeat with i = 4 down to 1
      put tNumber * 256 + byteToNum(byte i of pBytes) into tNumber
   end repeat
   return tNumber
end ebDuelNumber

-- The sum of pData that compress puts after what it packed: its CRC-32
-- (the table of it is made the first time)
private function ebDuelSum pData
   local tSum, tByte, tValue, i
   if sCrc is empty then
      repeat with i = 0 to 255
         put i into tValue
         repeat 8 times
            if tValue mod 2 is 1 then
               put 3988292384 bitXor (tValue div 2) into tValue
            else
               put tValue div 2 into tValue
            end if
         end repeat
         put tValue into sCrc[i]
      end repeat
   end if
   put 4294967295 into tSum
   repeat for each byte tByte in pData
      put sCrc[(tSum bitXor byteToNum(tByte)) mod 256] bitXor (tSum div 256) into tSum
   end repeat
   return tSum bitXor 4294967295
end ebDuelSum

-- Copy (or, on a phone in a browser, the share sheet): the code on its
-- way to the rival
private command ebLobbyCopy
   local tCode, tResult, tError
   if sLobby is "room" then
      put ebNetInvite() into tCode
   else
      put sNet2["code"] into tCode
   end if
   if tCode is empty or ebLobbyKind() is not "send" then
      exit ebLobbyCopy
   end if
   if sPlatform is "web" and sLibrary and sPointer is "touch" then
      put "not supported" into tResult
      try
         mwShare tCode, empty, "Ember Bricks"
         put the result into tResult
      catch tError
         put "not supported" into tResult
      end try
      if tResult is empty then
         set the text of field "Lobby Note" to "Sent? Then go on."
         exit ebLobbyCopy
      end if
      if tResult is "copied" then
         set the text of field "Lobby Note" to "Copied. Send it to your rival in any message."
         exit ebLobbyCopy
      end if
   end if
   try
      set the clipboardData["text"] to tCode
      set the text of field "Lobby Note" to "Copied. Send it to your rival in any message."
   catch tError
      set the text of field "Lobby Note" to "Could not copy it. Select the code in the box and copy it."
   end try
end ebLobbyCopy

-- Paste: what the clipboard holds, into the box, and on. A page reads
-- the clipboard only when asked from a click, and answers later (through
-- ebPasted, one of the stack's cJavascriptHandlers)
private command ebLobbyPaste
   local tText, tError
   if ebLobbyKind() is not "take" then
      exit ebLobbyPaste
   end if
   if sPlatform is "web" then
      try
         do "(function(){var s=null;try{s=document.liveCode.findStackWithName('" & the short name of me & "');}catch(e){}" & \
               "var give=function(t){try{if(s&&s.ebPasted)s.ebPasted(String(t||''));}catch(e){}};" & \
               "if(navigator.clipboard&&navigator.clipboard.readText){" & \
               "navigator.clipboard.readText().then(give,function(){give('');});}else{give('');}})();" as "JavaScript"
      catch tError
         ebPasted empty
      end try
   else
      try
         put the clipboardData["text"] into tText
      catch tError
         put empty into tText
      end try
      ebPasted tText
   end if
end ebLobbyPaste

-- What was pasted (empty when the clipboard could not be read): a
-- browser gives it later, from outside any press
command ebPasted pText
   set the defaultStack to the short name of me
   lock screen
   ebTakePasted pText
   unlock screen
end ebPasted

private command ebTakePasted pText
   if sMode is not "lobby" or ebLobbyKind() is not "take" then
      exit ebTakePasted
   end if
   if pText is empty then
      set the text of field "Lobby Note" to "Nothing to paste. Copy your rival's code, or click the box and paste into it."
      exit ebTakePasted
   end if
   if the length of pText > 24000 then
      put char 1 to 24000 of pText into pText
   end if
   replace return with empty in pText
   replace numToChar(13) with empty in pText
   replace space with empty in pText
   set the text of field "Code" to ebDuelLines(pText)
   ebLobbyGo
end ebTakePasted

-- The step's main button
private command ebLobbyGo
   local tSdp, tResult, tError
   switch sLobby
      case "host-invite"
         put "host-answer" into sLobby
         set the text of field "Code" to empty
         ebLobbyLook empty
         break
      case "host-answer"
         put ebDuelDecode(the text of field "Code", "A") into tSdp
         if char 1 of tSdp is "!" then
            set the text of field "Lobby Note" to char 2 to -1 of tSdp
            exit ebLobbyGo
         end if
         put -1 into tResult
         try
            put dcSetRemoteDescription(sNet2["peer"], tSdp, "answer") into tResult
         catch tError
            put -1 into tResult
         end try
         if tResult is not a number or tResult < 0 then
            set the text of field "Lobby Note" to "That answer could not be used. Ask your rival to join again."
            exit ebLobbyGo
         end if
         put sClock into sNet2["since"]
         put "linking" into sLobby
         ebLobbyLook empty
         break
      case "join-invite"
         put ebDuelDecode(the text of field "Code", "O") into tSdp
         if char 1 of tSdp is "!" then
            set the text of field "Lobby Note" to char 2 to -1 of tSdp
            exit ebLobbyGo
         end if
         ebDuelJoin tSdp
         break
      case "room"
         put "room-take" into sLobby
         set the text of field "Code" to empty
         ebLobbyLook empty
         break
      case "room-take"
         ebNetJoin the text of field "Code"
         break
   end switch
end ebLobbyGo

-- Out: of a step of the lobby to the one before it, of the lobby or a
-- match to the title; and of a match that began in the lobby, back to the
-- lobby
command ebDuelLeave
   local tOut, tBack
   set the defaultStack to the short name of me
   lock screen
   put true into tOut
   if sMode is "lobby" then
      put false into tOut
      switch sLobby
         case "start"
         case "none"
         case empty
            put true into tOut
            break
         case "choose"
            if ebNetCan() then
               put "start" into sLobby
               ebNetNameShow
               ebLobbyLook empty
            else
               put true into tOut
            end if
            break
         case "net-wait"
         case "online"
            ebNetStop "gone"
            put "start" into sLobby
            ebNetNameShow
            ebLobbyLook empty
            break
         case "quick"
            ebNetHome empty, "online"
            break
         case "room"
         case "room-take"
         case "room-in"
            put empty into sInvite
            ebNetRoom empty
            ebNetHome empty, "online"
            break
         case "asking"
            ebNetTell sLob["ask"]["pk"], "D" && sLob["ask"]["id"] && "cancel"
            ebNetHome empty
            break
         case "asked"
            ebNetDecline
            break
         case "net-link"
            ebNetTell sLob["link"]["pk"], "D" && sLob["link"]["id"] && "cancel"
            ebDuelDrop
            ebNetHome empty
            break
         default
            -- (a step of the codes, or a link just made)
            ebDuelDrop
            if ebNetIn() then
               ebNetHome empty
            else
               put "choose" into sLobby
               ebLobbyLook empty
            end if
      end switch
   end if
   if tOut then
      put (sNetBack is true and sMode is not "lobby") into tBack
      put false into sNetBack
      ebDuelSend "B"
      ebDuelDrop
      ebNetStop "gone"
      put empty into sLobby
      if sDuel then
         put false into sDuel
         put 0 into sShift
         ebLayout
      end if
      ebGoTitle
      if tBack then
         -- (a match that began in the lobby: back there, and online)
         ebDuelOpen
         if sLobby is "start" then
            ebNetStart
         end if
      end if
   end if
   unlock screen
end ebDuelLeave

-- The stack closes: the link too, and DataChannelXT's threads if the
-- game started them
command ebDuelClose
   local tError
   ebDuelDrop
   put false into sDuel
   if sRtcUsed is true then
      put false into sRtcUsed
      try
         dcCleanup
      catch tError
      end try
   end if
end ebDuelClose

-- The peer and everything of the link, gone
private command ebDuelDrop
   local tPeer, tError
   put sNet2["peer"] into tPeer
   if tPeer is a number then
      if tPeer > 0 then
         try
            dcFreePeer tPeer
         catch tError
         end try
      end if
   end if
   put empty into sNet2
end ebDuelDrop

-- The link broke, or never opened, or the rival left: a match ends on
-- its result, the lobby goes back to its first step, and says why
private command ebDuelGone pWhy
   local tPeer, tError
   if sDuel then
      put true into sNet2["gone"]
      put pWhy into sNet2["why"]
      put sNet2["peer"] into tPeer
      put empty into sNet2["peer"]
      put false into sNet2["open"]
      put false into sNet2["fastOpen"]
      if tPeer is a number and not sNet2["fake"] then
         try
            dcFreePeer tPeer
         catch tError
         end try
      end if
      if sNet2["stage"] is "play" then
         ebDuelEnd
      else
         ebDuelResultLook
      end if
   else
      ebDuelDrop
      if sMode is "lobby" then
         if ebNetIn() then
            -- (and a quick match leaves this player alone for a while)
            ebNetNotNow sLob["link"]["pk"]
            ebNetHome pWhy
         else
            put "choose" into sLobby
            ebLobbyLook pWhy
         end if
      end if
   end if
end ebDuelGone

-- A line to the rival: by the channel that loses nothing, or (pFast) by
-- the pictures' own when it is open
private command ebDuelSend pText, pFast
   local tChan, tResult, tError
   if sNet2["on"] is not true then
      exit ebDuelSend
   end if
   if sNet2["fake"] then
      -- (a test's duel: what would be sent is kept for it to read)
      if char 1 of pText is "T" then
         put pText into sNet2["picture"]
      else
         put pText & return after sNet2["sent"]
      end if
      exit ebDuelSend
   end if
   if sNet2["open"] is not true then
      exit ebDuelSend
   end if
   put sNet2["chan"] into tChan
   if pFast is true and sNet2["fastOpen"] is true then
      put sNet2["fast"] into tChan
   end if
   try
      put dcSendText(tChan, pText) into tResult
   catch tError
   end try
end ebDuelSend

-- Every frame while a link is on: what DataChannelXT has to say, the
-- lobby's waits, and a match's clock and pictures
private command ebDuelStep pReal
   local tEvents, tEvent, tError
   if sNet2["fake"] is not true then
      put empty into tEvents
      try
         put dcPoll() into tEvents
      catch tError
         put empty into tEvents
      end try
      if tEvents is an array then
         repeat for each element tEvent in tEvents
            ebDuelEvent tEvent
            if sNet2["on"] is not true then
               exit ebDuelStep
            end if
         end repeat
      end if
   end if
   switch sLobby
      case "host-make"
      case "join-make"
         ebDuelMakeCode
         break
      case "linking"
         if sClock - sNet2["since"] > kDuelLinkFor then
            ebDuelGone "No link could be made. A code lasts only a minute or so, and some networks block a direct link. Try again."
         end if
         break
      case "net-link"
         if sNet2["told"] is not true and sNet2["fake"] is not true then
            ebDuelMakeCode
         end if
         if sLobby is "net-link" and sClock - sNet2["began"] > kNetLinkFor then
            ebDuelGone ebNetNoLink()
         end if
         break
   end switch
   if sNet2["on"] is not true or not sDuel then
      exit ebDuelStep
   end if
   if sNet2["stage"] is "play" then
      -- the clock, after the count that starts a match
      if sNet2["wait"] > 0 then
         subtract pReal from sNet2["wait"]
      else
         subtract pReal from sNet2["left"]
      end if
      ebDuelClock
      add pReal to sNet2["sinceSend"]
      if sNet2["sinceSend"] >= kDuelSend then
         put 0 into sNet2["sinceSend"]
         ebDuelSend "T" && ebDuelPicture(), true
      end if
      add pReal to sNet2["quiet"]
      if sNet2["left"] <= 0 then
         ebDuelEnd
      else if sNet2["quiet"] > kDuelQuiet and sNet2["fake"] is not true then
         ebDuelGone "The link to your rival was lost."
      end if
      ebDuelDraw false
   else if sNet2["stage"] is "result" then
      -- the rival's last score may be a moment behind mine
      if sNet2["theirFinal"] is empty and sNet2["gone"] is not true then
         add pReal to sNet2["resultWait"]
         if sNet2["resultWait"] > 4 then
            put sNet2["their"]["score"] + 0 into sNet2["theirFinal"]
            ebDuelResultLook
         end if
      end if
      ebDuelDraw false
   end if
end ebDuelStep

-- One thing DataChannelXT has to say (it says every peer's: only this
-- game's are heard)
private command ebDuelEvent pEvent
   local tName, tMine
   put pEvent["name"] into tName
   put pEvent["peer"] is sNet2["peer"] into tMine
   switch tName
      case "dcLocalDescriptionReady"
         if tMine then
            put true into sNet2["described"]
         end if
         break
      case "dcGatheringStateChange"
         if tMine and pEvent["state"] is 2 then
            put true into sNet2["gathered"]
         end if
         break
      case "dcStateChange"
         -- (4: failed; 5: closed)
         if tMine and (pEvent["state"] is 4 or pEvent["state"] is 5) then
            if sDuel then
               ebDuelGone "The link to your rival was lost."
            else if sLobby is "net-link" then
               ebDuelGone ebNetNoLink()
            else if sLobby is "join-answer" then
               ebDuelGone "The answer was not used in time, or a network blocks the link. Join again with a new invite."
            else
               ebDuelGone "No link could be made. A code lasts only a minute or so, and some networks block a direct link. Try again."
            end if
         end if
         break
      case "dcChannelIncoming"
         if tMine then
            if pEvent["label"] is "eb" then
               put pEvent["channel"] into sNet2["chan"]
            else if pEvent["label"] is "ebs" then
               put pEvent["channel"] into sNet2["fast"]
            end if
         end if
         break
      case "dcChannelOpen"
         if pEvent["channel"] is sNet2["chan"] and sNet2["chan"] is not empty then
            put true into sNet2["open"]
            ebDuelSend "H" && kDuelVersion
            if sMode is "lobby" then
               put "linked" into sLobby
               ebLobbyLook empty
               ebSound "join", 0.6
            end if
         else if pEvent["channel"] is sNet2["fast"] and sNet2["fast"] is not empty then
            put true into sNet2["fastOpen"]
         end if
         break
      case "dcChannelClosed"
         if pEvent["channel"] is sNet2["chan"] and sNet2["chan"] is not empty then
            if sNet2["open"] is true then
               ebDuelGone "Your rival left the duel."
            end if
         else if pEvent["channel"] is sNet2["fast"] and sNet2["fast"] is not empty then
            put false into sNet2["fastOpen"]
         end if
         break
      case "dcMessage"
         if sNet2["chan"] is empty then
            break
         end if
         if pEvent["channel"] is sNet2["chan"] or pEvent["channel"] is sNet2["fast"] then
            ebDuelReceive pEvent["text"]
         end if
         break
   end switch
end ebDuelEvent

-- A line from the rival (the tests hand one in too)
command ebDuelReceive pText
   local tKind, tRest
   if sNet2["on"] is not true or pText is empty or the length of pText > 2000 then
      exit ebDuelReceive
   end if
   put 0 into sNet2["quiet"]
   put char 1 of pText into tKind
   put char 3 to -1 of pText into tRest
   switch tKind
      case "H"
         if word 1 of tRest is not kDuelVersion then
            ebDuelSend "B"
            ebDuelGone "Your rival has another version of the game. Both of you need the same."
            exit ebDuelReceive
         end if
         if sNet2["role"] is "host" and sNet2["hello"] is not true then
            put true into sNet2["hello"]
            ebDuelHostStart
         end if
         put true into sNet2["hello"]
         break
      case "S"
         if sNet2["role"] is "guest" and tRest is an integer then
            if not sDuel or sNet2["stage"] is "result" then
               ebDuelBegin tRest
            end if
         end if
         break
      case "T"
         if sDuel then
            ebDuelTheirs tRest
         end if
         break
      case "A"
         if sDuel and sNet2["stage"] is "play" then
            ebDuelHit word 1 of tRest
         end if
         break
      case "E"
         if sDuel and tRest is a number then
            put max(0, min(99999999, round(tRest))) into sNet2["theirFinal"]
            put sNet2["theirFinal"] into sNet2["their"]["score"]
            if sNet2["stage"] is "result" then
               ebDuelResultLook
            end if
         end if
         break
      case "R"
         if sDuel then
            put true into sNet2["theirRematch"]
            ebDuelRematchCheck
         end if
         break
      case "B"
         ebDuelGone "Your rival left the duel."
         break
   end switch
end ebDuelReceive

-- The host begins a match: a number for the first wall, to the guest,
-- and off
private command ebDuelHostStart
   local tSeed
   put random(9000) + 999 into tSeed
   ebDuelSend "S" && tSeed
   ebDuelBegin tSeed
end ebDuelHostStart

-- A match begins, here as at the rival's: wall 1 (which of the levels
-- it is, pSeed says), no score, three minutes on the clock after a count
-- of three
private command ebDuelBegin pSeed
   local i, tSub
   put true into sDuel
   if ebNetIn() then
      ebNetBegun
   end if
   put empty into sLobby
   put "play" into sNet2["stage"]
   put kDuelFor into sNet2["left"]
   put 3 into sNet2["wait"]
   put 0 into sNet2["sinceSend"]
   put 0 into sNet2["quiet"]
   put 0 into sNet2["resultWait"]
   put empty into sNet2["their"]
   put empty into sNet2["theirFinal"]
   put empty into sNet2["myFinal"]
   put empty into sNet2["myRematch"]
   put empty into sNet2["theirRematch"]
   put empty into sNet2["drawn"]
   put empty into sNet2["clock"]
   -- (one of the first twelve levels: the later ones are a slow start)
   put abs(pSeed) mod min(12, sLevelCount) into sShift
   lock screen
   ebLayout
   ebNewRun 1
   -- (the first ball waits for the count, and no click or key sends it
   -- off before: ebLaunch; so nothing says to click)
   repeat with i = 1 to sCount["Ball"]
      if sBall[i]["on"] and sBall[i]["stuck"] then
         put sNow + 3 into sBall[i]["until"]
      end if
   end repeat
   set the visible of field id sId["Hint"] to false
   set the text of field id sId["Rival Score"] to "0"
   put "Three minutes. Most points wins." into tSub
   if sNet2["name"] is not empty then
      put "You against" && sNet2["name"] & ". Most points wins." into tSub
   end if
   ebBanner "GET READY", tSub, 2.6
   ebSound "go", 0.7
   ebDuelClock
   ebDuelDraw true
   unlock screen
end ebDuelBegin

-- The clock, when its second changes; red, and ticking, for its last ten
private command ebDuelClock
   local tLeft, tText
   put max(0, sNet2["left"]) into tLeft
   if tLeft is not an integer then
      put trunc(tLeft) + 1 into tLeft
   end if
   if tLeft is sNet2["clock"] then
      exit ebDuelClock
   end if
   put tLeft into sNet2["clock"]
   put tLeft mod 60 into tText
   if tText < 10 then
      put "0" before tText
   end if
   put (tLeft div 60) & ":" before tText
   set the text of field id sId["Clock"] to tText
   if tLeft <= 10 then
      set the textColor of field id sId["Clock"] to kBad
      if tLeft > 0 and sNet2["wait"] <= 0 then
         ebSound "tick", 0.5
      end if
   else
      set the textColor of field id sId["Clock"] to kInk
   end if
end ebDuelClock

-- My arena, for the rival: the score, the wall, the heat's bonus, the
-- paddle; the balls; the bricks
private function ebDuelPicture
   local tOut, tBalls, tBricks, tCount, i
   put round(sScore) & comma & sLevel & comma & sMult & comma & round(sPadX) & comma & round(sPadW) into tOut
   put 0 into tCount
   repeat with i = 1 to sCount["Ball"]
      if sBall[i]["on"] then
         add 1 to tCount
         put round(sBall[i]["x"]) & comma & round(sBall[i]["y"]) & ";" after tBalls
         if tCount >= sCount["Rival Ball"] then
            exit repeat
         end if
      end if
   end repeat
   repeat with i = 1 to kCells
      if sBK[i] is empty then
         put "." after tBricks
      else
         put char 1 of sBK[i] after tBricks
      end if
   end repeat
   return tOut & "|" & tBalls & "|" & tBricks
end ebDuelPicture

-- The rival's arena, from a picture of it
private command ebDuelTheirs pText
   local tHead, tBalls, tBricks, tList, tBall, i
   set the itemDelimiter to "|"
   put item 1 of pText into tHead
   put item 2 of pText into tBalls
   put item 3 of pText into tBricks
   set the itemDelimiter to comma
   if the number of items of tHead is not 5 then
      exit ebDuelTheirs
   end if
   repeat with i = 1 to 5
      if item i of tHead is not a number then
         exit ebDuelTheirs
      end if
   end repeat
   if sNet2["theirFinal"] is empty then
      put max(0, min(99999999, round(item 1 of tHead))) into sNet2["their"]["score"]
   end if
   put max(1, min(9999, round(item 2 of tHead))) into sNet2["their"]["wall"]
   put max(1, min(5, round(item 3 of tHead))) into sNet2["their"]["mult"]
   -- (a paddle no wider than half the arena, and all of it in the arena)
   put max(10, min(kArenaW / 2, round(item 5 of tHead))) into sNet2["their"]["padw"]
   put max(sNet2["their"]["padw"] / 2, min(kArenaW - sNet2["their"]["padw"] / 2, round(item 4 of tHead))) into sNet2["their"]["padx"]
   if the length of tBricks is kCells then
      put tBricks into sNet2["their"]["bricks"]
   end if
   put empty into tList
   set the itemDelimiter to ";"
   repeat with i = 1 to min(sCount["Rival Ball"], the number of items of tBalls)
      put item i of tBalls into tBall
      set the itemDelimiter to comma
      if the number of items of tBall is 2 and item 1 of tBall is a number and item 2 of tBall is a number then
         put max(0, min(kArenaW, round(item 1 of tBall))) & comma & max(0, min(kArenaH, round(item 2 of tBall))) & return after tList
      end if
      set the itemDelimiter to ";"
   end repeat
   set the itemDelimiter to comma
   put tList into sNet2["their"]["balls"]
end ebDuelTheirs

-- The rival's arena on the screen: what changed of it since it was last
-- drawn (or, pAll, all of it: the window changed)
private command ebDuelDraw pAll
   local tBricks, tWas, tCode, tLook, i, tX, tW, tY, tKey, tBalls, tBall
   if not sDuel or not sWorld then
      exit ebDuelDraw
   end if
   if pAll is true then
      put empty into sNet2["drawn"]
   end if
   -- the bricks
   put sNet2["their"]["bricks"] into tBricks
   put sNet2["drawn"]["bricks"] into tWas
   if tBricks is not tWas or tWas is empty then
      repeat with i = 1 to kCells
         put char i of tBricks into tCode
         if tCode is empty then
            put "." into tCode
         end if
         if tCode is char i of tWas then
            next repeat
         end if
         if tCode is "." then
            set the visible of graphic id sId["Rival Brick"][i] to false
            next repeat
         end if
         put tCode into tLook
         if tCode is "T" then
            put "M2" into tLook
         else if tCode is "U" then
            put "M3" into tLook
         end if
         if sLook[tLook]["color"] is empty then
            put 1 into tLook
         end if
         set the backgroundColor of graphic id sId["Rival Brick"][i] to sLook[tLook]["color"]
         set the visible of graphic id sId["Rival Brick"][i] to true
      end repeat
      if tBricks is empty then
         -- (140 places of nothing, so that it is not drawn again)
         repeat with i = 1 to kCells
            put "." after tBricks
         end repeat
      end if
      put tBricks into sNet2["drawn"]["bricks"]
   end if
   -- the paddle
   put sNet2["their"]["padx"] into tX
   put sNet2["their"]["padw"] into tW
   if tX is not a number then
      put kArenaW / 2 into tX
      put kPadNormal into tW
   end if
   put tX & comma & tW into tKey
   if tKey is not sNet2["drawn"]["pad"] then
      put tKey into sNet2["drawn"]["pad"]
      put round(sRY + kPadTop * sRS) into tY
      set the rect of graphic id sId["Rival Paddle"] to round(sRX + (tX - tW / 2) * sRS), tY, \
            max(round(sRX + (tX - tW / 2) * sRS) + 3, round(sRX + (tX + tW / 2) * sRS)), max(tY + 2, round(sRY + (kPadTop + kPadH) * sRS))
   end if
   -- the balls
   put sNet2["their"]["balls"] into tBalls
   if tBalls is not sNet2["drawn"]["balls"] or pAll is true then
      put tBalls into sNet2["drawn"]["balls"]
      repeat with i = 1 to sCount["Rival Ball"]
         put line i of tBalls into tBall
         if tBall is empty then
            set the visible of graphic id sId["Rival Ball"][i] to false
         else
            set the loc of graphic id sId["Rival Ball"][i] to round(sRX + item 1 of tBall * sRS), round(sRY + item 2 of tBall * sRS)
            set the visible of graphic id sId["Rival Ball"][i] to true
         end if
      end repeat
   end if
   -- the score, and the heat's bonus beside the name
   put sNet2["their"]["score"] + 0 into tKey
   if tKey is not sNet2["drawn"]["score"] then
      put tKey into sNet2["drawn"]["score"]
      set the text of field id sId["Rival Score"] to ebCommas(tKey)
   end if
   put sNet2["their"]["mult"] into tKey
   if tKey is not sNet2["drawn"]["mult"] then
      put tKey into sNet2["drawn"]["mult"]
      if tKey > 1 then
         set the text of field id sId["Rival Name"] to "RIVAL x" & tKey
      else
         set the text of field id sId["Rival Name"] to "RIVAL"
      end if
   end if
end ebDuelDraw

-- My heat reached a new bonus: at x3, x4 and x5 the rival gets trouble
private command ebDuelHeat pMult
   local tKind, tWord
   if sNet2["stage"] is not "play" then
      exit ebDuelHeat
   end if
   switch pMult
      case 3
         put "fast" into tKind
         put "A FAST BALL" into tWord
         break
      case 4
         put "small" into tKind
         put "A SMALL PADDLE" into tWord
         break
      case 5
         put "junk" into tKind
         put "MORE BRICKS" into tWord
         break
   end switch
   if tKind is empty then
      exit ebDuelHeat
   end if
   ebDuelSend "A" && tKind
   ebPop "SENT:" && tWord, kArenaW / 2, 300, kCool
   ebSound "attack", 0.6
end ebDuelHeat

-- Trouble from the rival: a ball that flies faster, a paddle that
-- shrinks, a row of bricks more
private command ebDuelHit pKind
   switch pKind
      case "fast"
         ebCatch "fast"
         ebBanner "FROM YOUR RIVAL", "A fast ball", 1.2
         break
      case "small"
         ebCatch "small"
         ebBanner "FROM YOUR RIVAL", "A small paddle", 1.2
         break
      case "junk"
         ebDuelJunk
         ebBanner "FROM YOUR RIVAL", "More bricks", 1.2
         ebSound "hazard", 0.6
         ebBuzz 80
         break
      default
         exit ebDuelHit
   end switch
   ebFlash kBad, 0.12
end ebDuelHit

-- A row of tough bricks on top of the wall, which moves a row down for
-- it (when its last row is free: else the new ones fill the gaps of the
-- top row)
private command ebDuelJunk
   local tCol, tCell, tFull, tGap, tBlast
   put false into tFull
   repeat with tCol = 1 to kCols
      if sBK[(kRows - 1) * kCols + tCol] is not empty then
         put true into tFull
      end if
   end repeat
   if not tFull then
      repeat with tCell = kCells down to kCols + 1
         put sBK[tCell - kCols] into sBK[tCell]
         put sBH[tCell - kCols] into sBH[tCell]
      end repeat
      repeat with tCol = 1 to kCols
         put empty into sBK[tCol]
         put empty into sBH[tCol]
      end repeat
      -- (a bomb's blast on its way goes down with its brick)
      repeat for each key tCell in sBlast
         if tCell + kCols <= kCells then
            put sBlast[tCell] into tBlast[tCell + kCols]
         end if
      end repeat
      put tBlast into sBlast
   end if
   put random(kCols) into tGap
   repeat with tCol = 1 to kCols
      if tCol is tGap or sBK[tCol] is not empty then
         next repeat
      end if
      put "T" into sBK[tCol]
      put 2 into sBH[tCol]
   end repeat
   put 0 into sRemaining
   repeat with tCell = 1 to kCells
      if sBK[tCell] is not empty and sBK[tCell] is not "X" then
         add 1 to sRemaining
      end if
   end repeat
   ebBrickLooks
end ebDuelJunk

-- My clock ran out (or the rival is gone): my last score to the rival,
-- and the result
private command ebDuelEnd
   if sNet2["stage"] is not "play" then
      exit ebDuelEnd
   end if
   put "result" into sNet2["stage"]
   put 0 into sNet2["left"]
   put round(sScore) into sNet2["myFinal"]
   put 0 into sNet2["resultWait"]
   ebDuelSend "E" && sNet2["myFinal"]
   ebDuelClock
   put "result" into sMode
   put false into sDragging
   ebClearThings
   set the visible of field id sId["Hint"] to false
   set the visible of group "Banner" to false
   put empty into sBannerUntil
   ebKeepAwake false
   ebHud
   ebDuelResultLook
   ebShowScreen "result"
end ebDuelEnd

-- The result's words: who won, the two scores, and what the rematch
-- waits for
private command ebDuelResultLook
   local tMine, tTheirs, tNote, tGone, tKnown, tSound
   if sNet2["stage"] is not "result" then
      exit ebDuelResultLook
   end if
   put sNet2["myFinal"] + 0 into tMine
   put sNet2["gone"] is true into tGone
   put sNet2["theirFinal"] is not empty into tKnown
   if tKnown then
      put sNet2["theirFinal"] + 0 into tTheirs
   else
      put sNet2["their"]["score"] + 0 into tTheirs
   end if
   set the text of field "Result You" to "YOU   " & ebCommas(tMine)
   if sNet2["name"] is empty then
      set the text of field "Result Them" to "RIVAL   " & ebCommas(tTheirs)
   else
      -- (a rival met in the lobby has a name)
      set the text of field "Result Them" to toUpper(char 1 to 10 of sNet2["name"]) & "   " & ebCommas(tTheirs)
   end if
   if tGone and not tKnown then
      set the text of field "Result Title" to "RIVAL LEFT"
      set the textColor of field "Result Title" to kAmber
      put sNet2["why"] into tNote
   else if not tKnown then
      set the text of field "Result Title" to "TIME!"
      set the textColor of field "Result Title" to kInk
      put "Waiting for your rival's last points..." into tNote
   else
      if tMine > tTheirs then
         set the text of field "Result Title" to "YOU WIN"
         set the textColor of field "Result Title" to kGood
         put "best" into tSound
      else if tMine < tTheirs then
         set the text of field "Result Title" to "RIVAL WINS"
         set the textColor of field "Result Title" to kBad
         put "over" into tSound
      else
         set the text of field "Result Title" to "A DRAW"
         set the textColor of field "Result Title" to kAmber
         put "clear" into tSound
      end if
      if sNet2["said"] is not true then
         put true into sNet2["said"]
         ebSound tSound, 0.7
      end if
      if tGone then
         put sNet2["why"] into tNote
      else if sNet2["myRematch"] is true then
         put "Waiting for your rival..." into tNote
      else if sNet2["theirRematch"] is true then
         put "Your rival wants a rematch." into tNote
      end if
   end if
   set the text of field "Result Note" to tNote
   -- (no rematch with a rival who is gone)
   set the visible of button "Rematch" to not tGone
   set the visible of graphic "Rematch Shape" to not tGone
   ebLayoutResult sInL, sInT, sW - sInR, sH - sInB
end ebDuelResultLook

-- Rematch: when both want one, the host begins it
private command ebDuelRematch
   if not sDuel or sNet2["stage"] is not "result" or sNet2["gone"] is true or sNet2["myRematch"] is true then
      exit ebDuelRematch
   end if
   put true into sNet2["myRematch"]
   ebDuelSend "R"
   ebDuelResultLook
   ebDuelRematchCheck
end ebDuelRematch

private command ebDuelRematchCheck
   if sNet2["stage"] is not "result" then
      exit ebDuelRematchCheck
   end if
   if sNet2["myRematch"] is true and sNet2["theirRematch"] is true then
      if sNet2["role"] is "host" then
         put false into sNet2["said"]
         ebDuelHostStart
      end if
   else
      ebDuelResultLook
   end if
end ebDuelRematchCheck

----------------------------------------------------------------------
-- The online lobby
--
-- Where two players find each other, so that neither carries a code:
-- who is online, a challenge to one of them, a quick match with the
-- first who wants one, and a room for a friend, by a link or six
-- letters. It needs no server of the game's. The players meet on public
-- Nostr relays (kNetRelays, or the stack's cRelays), through NostrXT and
-- its relay library, which OXT-Beyond carries: a relay passes on the
-- small signed messages its visitors send, to those who asked for them.
-- Each player has a key made for the visit, and under it sends two
-- kinds of message, both of the kinds a relay passes on and is not meant
-- to keep (some hold them a few minutes, and give them to whoever asks:
-- ebNetFresh):
--
--   who is here (kNetKindWho), tagged with the room, every twenty
--     seconds and whenever it changes:
--       EB|1|free|50|0|Lucky Flint
--     the lobby's version, what the player is doing (free; quick, for a
--     quick match; busy; duel; gone), the seconds it stands for, whether
--     it asks the others to say theirs at once (a newcomer's does), and
--     the name
--   a word to one player (kNetKindTell), tagged with that player's key
--     and sealed so that only that player reads it (NIP-44):
--       L1 C K7MQ2XAB            I challenge you
--       L1 D K7MQ2XAB no         not now (or busy, cancel, failed)
--       L1 O K7MQ2XAB EB1Oz:...  my description: the invite of the codes
--       L1 A K7MQ2XAB EB1Az:...  and the answer to it
--
-- A challenge accepted is answered with the accepter's description; the
-- challenger sends its own back, and the link opens as it does for two
-- codes, a second or two after. In a quick match, and in a room, there
-- is no challenge: of two players who want a match, the one whose key
-- sorts first sends its description to the other. The game then leaves
-- the relays (saying "in a duel"), and comes back to them when the match
-- is left.
--
-- What comes from the relays is read as a stranger's: a name is cut to
-- sixteen plain characters, a description is checked as a code is, and
-- only a description from the player this one is dealing with (or, in a
-- quick match, from anyone who wants one) starts a link. Going online is
-- the player's choice, on a step that says what it shows; nothing is
-- sent before.
--
-- NostrXT's relay library tells the top stack what the relays say, or
-- the one object that asked it to (nxrInit), which another stack's chat
-- may be. So the game asks for nothing, and hears through a button of
-- its own whose script it puts at the back of the message path
-- (ebNetEar), which hands on what is for the game. It closes only the
-- relays it opened (never nxrShutdown, which closes every stack's).

-- Whether there is a lobby here: NostrXT answers, and can sign and seal
function ebNetCan
   local tCaps, tVersion, tError
   if sNostr is empty then
      put "no" into sNostr
      try
         put nxProbeCapabilities() into tCaps
         put nxrVersion() into tVersion
         if tCaps["canSign"] is true and tCaps["canNip44Cipher"] is true and tVersion is not empty then
            put "yes" into sNostr
         end if
      catch tError
      end try
   end if
   return sNostr is "yes"
end ebNetCan

-- Whether the player is in the lobby (and not on the way out of it)
private function ebNetIn
   return sLob["on"] is true and sLob["leaving"] is not true
end ebNetIn

-- How many relays are open
private function ebNetOpen
   local tRelay, tCount
   put 0 into tCount
   repeat for each key tRelay in sLob["relay"]
      if sLob["relay"][tRelay] is "open" then
         add 1 to tCount
      end if
   end repeat
   return tCount
end ebNetOpen

-- Whether two keys or ids are the same, as text (two that look like
-- numbers are never compared as numbers)
private function ebSame pA, pB
   return ("x" & pA) is ("x" & pB)
end ebSame

-- A name as the lobby shows it: at most sixteen characters, letters
-- (western Europe's too), digits, spaces and - _ . ' ! Anything else is
-- left out; empty when nothing is left
function ebNetName pText
   local tOut, tChar, tCode, tOk
   repeat for each codepoint tChar in pText
      put codepointToNum(tChar) into tCode
      put false into tOk
      if tCode >= 48 and tCode <= 57 then
         put true into tOk
      else if tCode >= 65 and tCode <= 90 then
         put true into tOk
      else if tCode >= 97 and tCode <= 122 then
         put true into tOk
      else if tCode >= 192 and tCode <= 591 and tCode is not 215 and tCode is not 247 then
         put true into tOk
      else if tCode is among the items of "32,33,39,45,46,95" then
         put true into tOk
      end if
      if tOk then
         put tChar after tOut
      end if
      if the length of tOut >= 48 then
         exit repeat
      end if
   end repeat
   -- (one space at a time, and none at its ends)
   repeat while "  " is in tOut
      replace "  " with " " in tOut
   end repeat
   put word 1 to -1 of tOut into tOut
   put char 1 to 16 of tOut into tOut
   return word 1 to -1 of tOut
end ebNetName

-- A name for a player who has given none
private function ebNetMadeName
   local tName
   put any item of "Swift,Lucky,Bold,Sunny,Quick,Bright,Brave,Merry,Keen,Jolly,Nimble,Plucky" into tName
   return tName && any item of "Spark,Ember,Flame,Comet,Blaze,Flint,Cinder,Flare,Torch,Fuse,Kiln,Wick"
end ebNetMadeName

-- The name in its field: the one kept, or one made up for a first visit
private command ebNetNameShow
   if sName is empty then
      put ebNetMadeName() into sName
   end if
   set the text of field "Name" to sName
end ebNetNameShow

-- The name of a player of the room
private function ebNetNameOf pPk
   if sLob["who"][pPk]["name"] is not empty then
      return sLob["who"][pPk]["name"]
   end if
   return "A player"
end ebNetNameOf

-- pLength letters by chance: a room's code, or the id of a challenge
private function ebNetMake pLength
   local tOut
   repeat pLength times
      put any char of kNetLetters after tOut
   end repeat
   return tOut
end ebNetMake

-- Whether pId could be the id of a challenge
private function ebNetIsId pId
   local tChar
   if the length of pId < 6 or the length of pId > 16 then
      return false
   end if
   repeat for each char tChar in pId
      if tChar is not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" then
         return false
      end if
   end repeat
   return true
end ebNetIsId

-- A room's code out of what was typed or pasted: the code itself, or the
-- link that carries it (...duel=K7M2QX). Its six letters, or empty when
-- it is not one
function ebNetCode pText
   local tOffset, tOut, tChar
   if the length of pText > 4000 then
      return empty
   end if
   -- (a message breaks a link into lines, and so does the box it is
   -- pasted into)
   replace return with empty in pText
   replace numToChar(13) with empty in pText
   replace tab with empty in pText
   replace space with empty in pText
   put offset("duel=", pText) into tOffset
   if tOffset > 0 then
      put char tOffset + 5 to -1 of pText into pText
      put offset("&", pText) into tOffset
      if tOffset > 0 then
         put char 1 to tOffset - 1 of pText into pText
      end if
      put offset("#", pText) into tOffset
      if tOffset > 0 then
         put char 1 to tOffset - 1 of pText into pText
      end if
   end if
   if the length of pText > 40 then
      return empty
   end if
   put toUpper(pText) into pText
   repeat for each char tChar in pText
      if tChar is in kNetLetters then
         put tChar after tOut
      else if tChar is not "-" then
         return empty
      end if
   end repeat
   if the length of tOut is not kNetCodeLength then
      return empty
   end if
   return tOut
end ebNetCode

-- What a friend is sent: in a page, its address with the room in it (and
-- in the Stack Player's, with the game); anywhere else, the room's code
private function ebNetInvite
   local tLink, tError
   if sPlatform is "web" then
      try
         do "(function(){try{var u=new URL(location.href),q=u.searchParams;q.set('duel','" & sLob["code"] & "');" & \
               "if(window.oxtPlayer&&!q.get('play')&&!q.get('stack'))q.set('play','" & the short name of me & "');" & \
               "return u.toString();}catch(e){return '';}})()" as "JavaScript"
         put the result into tLink
      catch tError
         put empty into tLink
      end try
      if tLink begins with "http" then
         return tLink
      end if
   end if
   return sLob["code"]
end ebNetInvite

-- The page was opened with a friend's room in its address: the lobby,
-- ready to go there
private command ebNetInvited
   local tCode, tError
   if sPlatform is not "web" then
      exit ebNetInvited
   end if
   try
      do "(function(){try{return new URLSearchParams(location.search).get('duel')||'';}catch(e){return '';}})()" as "JavaScript"
      put the result into tCode
   catch tError
      put empty into tCode
   end try
   put ebNetCode(tCode) into tCode
   if tCode is empty then
      exit ebNetInvited
   end if
   if not ebDuelCan() or not ebNetCan() then
      exit ebNetInvited
   end if
   put tCode into sInvite
   ebDuelOpen
end ebNetInvited

-- The relays: a test's, the stack's own (its cRelays), or the lobby's
private function ebNetRelays
   local tList
   put sRelays into tList
   if tList is empty then
      put the cRelays of me into tList
   end if
   if tList is empty then
      put kNetRelays into tList
   end if
   replace return with comma in tList
   replace space with empty in tList
   return tList
end ebNetRelays

-- Go online: the name as typed, kept for the next visit, and the lobby
private command ebNetGo
   local tName
   if sLobby is not "start" then
      exit ebNetGo
   end if
   put ebNetName(the text of field "Name") into tName
   if tName is empty then
      put ebNetMadeName() into tName
   end if
   put tName into sName
   set the text of field "Name" to sName
   ebSave
   ebNetStart
end ebNetGo

-- Online: a key for the visit, the game's ear in the message path, and a
-- line to each relay. The lobby opens when the first of them answers
-- (ebNetHeard)
private command ebNetStart
   local tSk, tPk, tUrl, tCount, tError
   ebNetStop
   -- (one key for the whole visit: a player who comes back from a match
   -- is the one the others saw go into it)
   put empty into tPk
   try
      if sKey is empty then
         put nxKeyGenerate() into sKey
      end if
      put sKey into tSk
      put nxKeyPublic(tSk) into tPk
   catch tError
      put empty into tPk
   end try
   if the length of tPk is not 64 then
      ebLobbyLook "Could not go online here. Play by code."
      exit ebNetStart
   end if
   put empty into sLob
   put true into sLob["on"]
   put tSk into sLob["sk"]
   put tPk into sLob["pk"]
   put 0 into sLob["clock"]
   put 0 into sLob["alone"]
   put "free" into sLob["state"]
   ebNetRoomName sInvite
   ebNetEar true
   put 0 into tCount
   repeat for each item tUrl in ebNetRelays()
      if ebNetDial(tUrl) then
         add 1 to tCount
      end if
   end repeat
   if tCount is 0 then
      ebNetStop
      ebLobbyLook "The lobby cannot be reached. Check your connection, or play by code."
      exit ebNetStart
   end if
   put "net-wait" into sLobby
   ebLobbyLook empty
end ebNetStart

-- A line to a relay; false when none could be begun
private function ebNetDial pUrl
   local tRelay, tError
   if pUrl is empty then
      return false
   end if
   if sLob["fake"] is true then
      -- (a test's lobby: a relay that is none, for the test to open or
      -- to lose, ebNetRelay)
      add 1 to sLob["lines"]
      put "test-" & sLob["lines"] into tRelay
      put "wait" into sLob["relay"][tRelay]
      put pUrl into sLob["url"][tRelay]
      return true
   end if
   try
      nxrConnect pUrl
      put the result into tRelay
      if tRelay is an integer then
         nxrSetCallback tRelay, "ebRelayCall"
         put "wait" into sLob["relay"][tRelay]
         put pUrl into sLob["url"][tRelay]
         return true
      end if
   catch tError
   end try
   return false
end ebNetDial

-- The game's ear: a button whose script, at the back of the message
-- path, hands the relays' words on to the game whichever stack is on top
-- (see the section's words). Put there while online, and taken away
private command ebNetEar pOn
   local tEar, tError
   try
      put the long id of button "Relay Ear" into tEar
      if pOn then
         if tEar is not among the lines of the backScripts then
            insert the script of button "Relay Ear" into back
         end if
      else if tEar is among the lines of the backScripts then
         remove the script of button "Relay Ear" from back
      end if
   catch tError
   end try
end ebNetEar

-- Offline. With pSay ("gone"; or "duel", as a match begins) the others
-- are told first, and the relays are left a moment later, when that has
-- gone out (ebNetStep); with nothing, at once
private command ebNetStop pSay
   local tRelays, tRelay, tError
   if sLob["on"] is not true then
      put empty into sLob
      exit ebNetStop
   end if
   if pSay is not empty and sLob["leaving"] is not true then
      put pSay into sLob["state"]
      ebNetSay false
      if sLob["fake"] is not true and ebNetOpen() > 0 then
         put true into sLob["leaving"]
         put sLob["clock"] + 1.5 into sLob["leaveAt"]
         exit ebNetStop
      end if
   end if
   -- (nothing of the lobby is left before its relays are closed: closing
   -- one says so, to an ear that is gone)
   put the keys of sLob["relay"] into tRelays
   if sLob["fake"] is true then
      put empty into tRelays
   end if
   put empty into sLob
   ebNetEar false
   repeat for each line tRelay in tRelays
      try
         nxrDisconnect tRelay
      catch tError
      end try
   end repeat
end ebNetStop

-- What a relay says, through the game's ear: it opened, it has a
-- message, or it is gone
on ebNetHeard pRelay, pKind, pOne, pTwo
   if sLob["on"] is not true or sLob["relay"][pRelay] is empty then
      exit ebNetHeard
   end if
   set the defaultStack to the short name of me
   lock screen
   switch pKind
      case "open"
         ebNetOpened pRelay
         break
      case "event"
         if sLob["leaving"] is not true then
            ebNetEvent pTwo
         end if
         break
      case "error"
      case "disconnected"
         ebNetLost pRelay
         break
   end switch
   unlock screen
end ebNetHeard

-- A relay opened: it is asked for the room, and told that I am here. The
-- first to open is the lobby (or the room of a friend's link)
private command ebNetOpened pRelay
   put "open" into sLob["relay"][pRelay]
   put sLob["clock"] into sLob["since"][pRelay]
   put empty into sLob["alone"]
   ebNetListen pRelay
   if sLob["leaving"] is true then
      exit ebNetOpened
   end if
   if sLobby is "net-wait" then
      if sLob["code"] is empty then
         put "online" into sLobby
         put "free" into sLob["state"]
      else
         put "room-in" into sLobby
         put "quick" into sLob["state"]
      end if
      ebNetSay true
      ebSound "join", 0.5
      ebLobbyLook empty
   else
      ebNetSay false
   end if
end ebNetOpened

-- A relay is gone: it is asked again (ebNetStep) in a while, or soon if
-- none is left open, since with none left for too long there is no lobby
-- (ebNetNone) and the asking has to come before that. A relay is asked a
-- few times and no more (one that answers and hangs up is not asked for
-- ever), counted afresh once it has stayed a while
private command ebNetLost pRelay
   local tUrl, tSoon, tUrls, tOther
   put sLob["url"][pRelay] into tUrl
   if tUrl is not empty and sLob["since"][pRelay] is a number then
      if sLob["clock"] - sLob["since"][pRelay] >= kNetSteady then
         put 0 into sLob["tries"][tUrl]
      end if
   end if
   delete variable sLob["relay"][pRelay]
   delete variable sLob["url"][pRelay]
   delete variable sLob["since"][pRelay]
   if sLob["leaving"] is true then
      exit ebNetLost
   end if
   if tUrl is not empty and sLob["tries"][tUrl] < kNetTries then
      add 1 to sLob["tries"][tUrl]
      put sLob["clock"] + kNetRetry into sLob["again"][tUrl]
   end if
   if ebNetOpen() is 0 then
      if sLob["alone"] is not a number then
         put sLob["clock"] into sLob["alone"]
      end if
      -- (none is open: whichever is to be asked again is asked soon)
      put sLob["clock"] + kNetRetrySoon into tSoon
      put the keys of sLob["again"] into tUrls
      repeat for each line tOther in tUrls
         if sLob["again"][tOther] > tSoon then
            put tSoon into sLob["again"][tOther]
         end if
      end repeat
   end if
end ebNetLost

-- No relay answers: no lobby, and its first step says so. (A link being
-- made goes on: its descriptions may have gone both ways already.)
private command ebNetNone
   local tWas
   put sLobby into tWas
   ebNetStop
   if sMode is "lobby" and tWas is not "net-link" and tWas is not "linked" then
      put "start" into sLobby
      ebNetNameShow
      ebLobbyLook "The lobby cannot be reached. Check your connection, or play by code."
   end if
end ebNetNone

-- A relay is asked for the room's "who is here", and for the words to me
private command ebNetListen pRelay
   local tWho, tMe, tError
   if sLob["fake"] is true then
      exit ebNetListen
   end if
   try
      -- (only what is said from now on: nothing a relay has kept, by its
      -- count, nor anything made before a while ago, by its date)
      put kNetKindWho into tWho["kinds"]
      put sLob["room"] into tWho["#t"]
      put 0 into tWho["limit"]
      put the seconds - kNetOld into tWho["since"]
      nxrSubscribe pRelay, "eb-who", nxFilterBuild(tWho)
      put kNetKindTell into tMe["kinds"]
      put sLob["pk"] into tMe["#p"]
      put 0 into tMe["limit"]
      put the seconds - kNetOld into tMe["since"]
      nxrSubscribe pRelay, "eb-me", nxFilterBuild(tMe)
   catch tError
   end try
end ebNetListen

-- The room's tag for a code (a friend's room), or with none the lobby's
private command ebNetRoomName pCode
   put pCode into sLob["code"]
   if pCode is empty then
      put "ember-bricks-lobby-" & kNetVersion into sLob["room"]
   else
      put "ember-bricks-room-" & kNetVersion & "-" & pCode into sLob["room"]
   end if
end ebNetRoomName

-- Into a room (a friend's, by its code), or with none back to the
-- lobby's own: gone from the one, and listening to the other
private command ebNetRoom pCode
   local tRelay, tWas
   if not ebNetIn() or ebSame(pCode, sLob["code"]) then
      exit ebNetRoom
   end if
   put sLob["state"] into tWas
   put "gone" into sLob["state"]
   ebNetSay false
   put tWas into sLob["state"]
   ebNetRoomName pCode
   put empty into sLob["who"]
   put empty into sLob["rows"]
   put 0 into sLob["count"]
   put empty into sLob["tried"]
   -- (new to the room: the next "I am here" asks who else is)
   put true into sLob["hello"]
   repeat for each key tRelay in sLob["relay"]
      if sLob["relay"][tRelay] is "open" then
         ebNetListen tRelay
      end if
   end repeat
end ebNetRoom

-- A message from a relay, its signature checked by NostrXT: once only
-- in a visit (each relay has it, and one that keeps what it passes on has
-- it again when I come back from a match), not my own, and news
-- (ebNetFresh)
private command ebNetEvent pJson
   local tEvent, tId, tPk, tText, tError
   put empty into tEvent
   try
      put nxEventFromJson(pJson) into tEvent
   catch tError
   end try
   if tEvent is not an array then
      exit ebNetEvent
   end if
   put tEvent["id"] into tId
   put tEvent["pubkey"] into tPk
   if the length of tId is not 64 or the length of tPk is not 64 then
      exit ebNetEvent
   end if
   if sSeen[tId] is true then
      exit ebNetEvent
   end if
   if sSeenCount > 500 then
      put empty into sSeen
      put 0 into sSeenCount
   end if
   put true into sSeen[tId]
   add 1 to sSeenCount
   if ebSame(tPk, sLob["pk"]) then
      exit ebNetEvent
   end if
   if not ebNetFresh(tEvent["kind"], tPk, tEvent["created_at"]) then
      exit ebNetEvent
   end if
   if tEvent["kind"] is kNetKindWho then
      if nxTagFirst(tEvent, "t") is sLob["room"] then
         ebNetWho tPk, tEvent["content"]
      end if
   else if tEvent["kind"] is kNetKindTell then
      if ebSame(nxTagFirst(tEvent, "p"), sLob["pk"]) then
         put empty into tText
         try
            put nxNip44Decrypt(sLob["sk"], tPk, tEvent["content"]) into tText
         catch tError
            put empty into tText
         end try
         if tText is not empty then
            ebNetSignal tPk, tText
         end if
      end if
   end if
end ebNetEvent

-- Whether a message is news, by the second it was made in (pAt). A relay
-- may keep for some minutes what it passes on and give a newcomer what it
-- has, the newest first, and each relay passes a message on in its own
-- time. So one made long ago by this machine's clock is the past, and so
-- is a player's "I am here" that comes after a newer one of theirs (the
-- newer one may have said "gone")
private function ebNetFresh pKind, pPk, pAt
   if pAt is not an integer then
      return false
   end if
   if the seconds - pAt > kNetOld then
      return false
   end if
   if pKind is kNetKindWho then
      if sLob["at"][pPk] is a number and pAt < sLob["at"][pPk] then
         return false
      end if
      -- (no more remembered than a crowd of strangers could fill)
      if the number of elements of sLob["at"] > 2000 then
         put empty into sLob["at"]
      end if
      put pAt into sLob["at"][pPk]
   end if
   return true
end ebNetFresh

-- A player says "I am here" (see the section's words): into the room's
-- list, or out of it. A newcomer's asks for mine, which goes a moment
-- later (not everyone's at once)
private command ebNetWho pPk, pContent
   local tState, tTtl, tHello, tName, tNew, tVersion, tMark
   set the itemDelimiter to "|"
   put item 1 of pContent into tMark
   put item 2 of pContent into tVersion
   put item 3 of pContent into tState
   put item 4 of pContent into tTtl
   put (item 5 of pContent is "1") into tHello
   put ebNetName(item 6 to -1 of pContent) into tName
   set the itemDelimiter to comma
   if tMark is not "EB" or tVersion is not kNetVersion then
      exit ebNetWho
   end if
   if tState is not among the items of "free,quick,busy,duel,gone" then
      exit ebNetWho
   end if
   put (sLob["who"][pPk] is not an array) into tNew
   if tState is "gone" then
      if not tNew then
         delete variable sLob["who"][pPk]
         put true into sLob["dirty"]
      end if
      exit ebNetWho
   end if
   -- (a room has no more players than a list can hold)
   if tNew and the number of elements of sLob["who"] >= 200 then
      exit ebNetWho
   end if
   if tTtl is not an integer then
      put kNetStale into tTtl
   end if
   put max(5, min(600, tTtl)) into tTtl
   if tName is empty then
      put "Player" into tName
   end if
   if tNew or sLob["who"][pPk]["name"] is not tName or sLob["who"][pPk]["state"] is not tState then
      put true into sLob["dirty"]
   end if
   put tName into sLob["who"][pPk]["name"]
   put tState into sLob["who"][pPk]["state"]
   put tTtl into sLob["who"][pPk]["ttl"]
   put sLob["clock"] into sLob["who"][pPk]["seen"]
   -- (a challenge, or a link, can come before its sender's "I am here":
   -- the name it was shown without is put right)
   if sLob["rival"] is not tName then
      if sLobby is "asked" and ebSame(sLob["ask"]["pk"], pPk) then
         put tName into sLob["rival"]
         ebLobbyLook empty
      else if sLobby is "net-link" and ebSame(sLob["link"]["pk"], pPk) then
         put tName into sLob["rival"]
         put tName into sNet2["name"]
         ebLobbyLook empty
      end if
   end if
   -- (a newcomer takes nothing a relay kept: it has what was said since
   -- it began to listen, and nothing of mine from before)
   if tHello and sLob["answerAt"] is not a number then
      put sLob["clock"] + 0.2 + random(10) / 10 into sLob["answerAt"]
   end if
end ebNetWho

-- A word to me from a player (see the section's words)
private command ebNetSignal pPk, pText
   local tKind, tId, tRest, tMine, tSdp
   if the length of pText > 30000 or word 1 of pText is not ("L" & kNetVersion) then
      exit ebNetSignal
   end if
   put word 2 of pText into tKind
   put word 3 of pText into tId
   put word 4 to -1 of pText into tRest
   if not ebNetIsId(tId) then
      exit ebNetSignal
   end if
   switch tKind
      case "C"
         if sLobby is "online" then
            put empty into sLob["ask"]
            put pPk into sLob["ask"]["pk"]
            put tId into sLob["ask"]["id"]
            put sLob["clock"] into sLob["ask"]["since"]
            put ebNetNameOf(pPk) into sLob["rival"]
            put "asked" into sLobby
            put "busy" into sLob["state"]
            ebNetSay false
            ebSound "join", 0.6
            ebLobbyLook empty
         else if sLobby is "quick" then
            -- (looking for anyone: this one will do)
            ebNetLink pPk, tId, "host", empty
         else
            ebNetTell pPk, "D" && tId && "busy"
         end if
         break
      case "D"
         if sLobby is "asking" and ebSame(sLob["ask"]["pk"], pPk) and ebSame(sLob["ask"]["id"], tId) then
            if word 1 of tRest is "busy" then
               ebNetHome sLob["rival"] && "is busy."
            else
               ebNetHome sLob["rival"] && "said not now."
            end if
         else if sLobby is "asked" and ebSame(sLob["ask"]["pk"], pPk) and ebSame(sLob["ask"]["id"], tId) then
            ebNetHome sLob["rival"] && "took the challenge back."
         else if sLobby is "net-link" and ebSame(sLob["link"]["pk"], pPk) and ebSame(sLob["link"]["id"], tId) then
            ebDuelDrop
            ebNetNotNow pPk
            ebNetHome sLob["rival"] && "is busy."
         end if
         break
      case "O"
         put false into tMine
         if sLobby is "asking" then
            put (ebSame(sLob["ask"]["pk"], pPk) and ebSame(sLob["ask"]["id"], tId)) into tMine
         else if sLobby is "quick" then
            put true into tMine
         else if sLobby is among the items of "room,room-in,room-take" then
            -- (in a room, from one who is in it)
            put (sLob["who"][pPk] is an array) into tMine
         end if
         if not tMine then
            ebNetTell pPk, "D" && tId && "busy"
            break
         end if
         put ebDuelDecode(word 1 of tRest, "O") into tSdp
         if char 1 of tSdp is "!" then
            ebNetTell pPk, "D" && tId && "failed"
            if sLobby is "asking" then
               ebNetHome "What" && sLob["rival"] && "sent could not be read."
            end if
            break
         end if
         ebNetLink pPk, tId, "guest", tSdp
         break
      case "A"
         if sLobby is "net-link" and sNet2["role"] is "host" and sNet2["answered"] is not true then
            if ebSame(sLob["link"]["pk"], pPk) and ebSame(sLob["link"]["id"], tId) then
               ebNetAnswered word 1 of tRest
            end if
         end if
         break
   end switch
end ebNetSignal

-- "I am here", to the room (pHello: and who else is?)
private command ebNetSay pHello
   local tText, tTtl, tFlag
   put kNetStale into tTtl
   if sLob["state"] is "duel" then
      put kDuelFor + 30 into tTtl
   end if
   put 0 into tFlag
   if pHello is true or sLob["hello"] is true then
      put 1 into tFlag
   end if
   put false into sLob["hello"]
   put "EB|" & kNetVersion & "|" & sLob["state"] & "|" & tTtl & "|" & tFlag & "|" & sName into tText
   put sLob["clock"] into sLob["beat"]
   if sLob["fake"] is true then
      -- (a test's lobby: what would be sent is kept for it to read)
      put "who" && tText & return after sNetSent
      exit ebNetSay
   end if
   ebNetPublish kNetKindWho, "t" & tab & sLob["room"], tText
end ebNetSay

-- A word to one player, sealed for them
private command ebNetTell pPk, pText
   local tSealed, tError
   if pPk is empty or sLob["on"] is not true then
      exit ebNetTell
   end if
   if sLob["fake"] is true then
      put "tell" && pPk && pText & return after sNetSent
      exit ebNetTell
   end if
   put empty into tSealed
   try
      put nxNip44Encrypt(sLob["sk"], pPk, "L" & kNetVersion && pText) into tSealed
   catch tError
      put empty into tSealed
   end try
   if tSealed is empty then
      exit ebNetTell
   end if
   ebNetPublish kNetKindTell, "p" & tab & pPk, tSealed
end ebNetTell

-- A message of a kind, with a tag, signed with the visit's key, to every
-- relay that is open. Each has its count in the visit as a second tag: a
-- message is known by what it says and the second it was made in, and a
-- relay passes on only the first of two it takes for the same (an "I am
-- here" said again within a second, to a second newcomer, went nowhere)
private command ebNetPublish pKind, pTag, pContent
   local tEvent, tRelay, tError
   add 1 to sSaid
   try
      put nxEventBuild(pKind, pContent, nxTagsFromText(pTag & return & "seq" & tab & sSaid), empty) into tEvent
      put nxEventSign(tEvent, sLob["sk"], empty) into tEvent
      if tEvent is an array then
         repeat for each key tRelay in sLob["relay"]
            if sLob["relay"][tRelay] is "open" then
               nxrPublish tRelay, tEvent
            end if
         end repeat
      end if
   catch tError
   end try
end ebNetPublish

-- Every frame while online: the lobby's clock, a relay to ask again, "I
-- am here", who has gone quiet, the waits that run out, and a rival for
-- a quick match
private command ebNetStep pReal
   local tPk, tGone, tUrl, tDue
   add pReal to sLob["clock"]
   -- (a frame long in coming: the page was hidden or the phone slept,
   -- its relays went meanwhile, and whether that is heard before this
   -- frame or after it, the time asleep is none that a relay was waited
   -- for. The relays are asked again now, and waited for from now)
   if pReal > kNetSlept and sLob["alone"] is a number then
      add pReal to sLob["alone"]
   end if
   if sLob["leaving"] is true then
      if sLob["clock"] >= sLob["leaveAt"] then
         ebNetStop
      end if
      exit ebNetStep
   end if
   -- (a test's lobby has relays only if the test gave it some)
   if sLob["fake"] is not true or sLob["wired"] is true then
      if sLob["alone"] is a number then
         if sLob["clock"] - sLob["alone"] > kNetOpenFor then
            ebNetNone
            exit ebNetStep
         end if
      end if
      repeat for each key tUrl in sLob["again"]
         if sLob["clock"] >= sLob["again"][tUrl] then
            put tUrl & return after tDue
         end if
      end repeat
      repeat for each line tUrl in tDue
         delete variable sLob["again"][tUrl]
         get ebNetDial(tUrl)
      end repeat
      if ebNetOpen() is 0 then
         exit ebNetStep
      end if
   end if
   if sLob["clock"] - sLob["beat"] >= kNetBeat then
      ebNetSay false
   else if sLob["answerAt"] is a number then
      if sLob["clock"] >= sLob["answerAt"] then
         put empty into sLob["answerAt"]
         ebNetSay false
      end if
   end if
   repeat for each key tPk in sLob["who"]
      if sLob["clock"] - sLob["who"][tPk]["seen"] > sLob["who"][tPk]["ttl"] then
         put tPk & return after tGone
      end if
   end repeat
   repeat for each line tPk in tGone
      delete variable sLob["who"][tPk]
      put true into sLob["dirty"]
   end repeat
   switch sLobby
      case "asking"
         if sLob["clock"] - sLob["ask"]["since"] > kNetAskFor then
            ebNetTell sLob["ask"]["pk"], "D" && sLob["ask"]["id"] && "cancel"
            ebNetHome sLob["rival"] && "did not answer."
         end if
         break
      case "asked"
         if sLob["clock"] - sLob["ask"]["since"] > kNetAskFor + 5 then
            ebNetHome "The challenge from" && sLob["rival"] && "ran out."
         end if
         break
      case "quick"
      case "room"
      case "room-in"
         ebNetMatch
         break
   end switch
   if sLobby is "online" then
      if sLob["dirty"] is true then
         ebNetList
         ebLobbyLook empty
      else if sLob["said"] is not empty and sLob["clock"] >= sLob["saidUntil"] then
         -- (a line said for a while gives way to the step's own)
         put empty into sLob["said"]
         ebLobbyLook empty
      end if
   end if
end ebNetStep

-- A quick match, or a room: of the players who want a match too, the
-- first by key; and of the two of us, the one whose key sorts first
-- sends its description (the other waits for it)
private command ebNetMatch
   local tPk, tList, tPick, tPair
   if sLob["matchAt"] is a number then
      if sLob["clock"] < sLob["matchAt"] then
         exit ebNetMatch
      end if
   end if
   put sLob["clock"] + 0.5 into sLob["matchAt"]
   repeat for each key tPk in sLob["who"]
      if sLob["who"][tPk]["state"] is not "quick" then
         next repeat
      end if
      if sLob["tried"][tPk] is a number then
         if sLob["clock"] < sLob["tried"][tPk] then
            next repeat
         end if
      end if
      put tPk & return after tList
   end repeat
   if tList is empty then
      exit ebNetMatch
   end if
   delete last char of tList
   sort lines of tList
   put line 1 of tList into tPick
   put sLob["pk"] & return & tPick into tPair
   sort lines of tPair
   if ebSame(line 1 of tPair, sLob["pk"]) then
      ebNetLink tPick, ebNetMake(8), "host", empty
   end if
end ebNetMatch

-- A quick match leaves a player alone for a while: one who was busy, or
-- to whom no link could be made
private command ebNetNotNow pPk
   if pPk is not empty and sLob["on"] is true then
      put sLob["clock"] + kNetAgain into sLob["tried"][pPk]
   end if
end ebNetNotNow

-- How many players the list shows: fewer on a phone on its side
private function ebNetRowsMost
   if ebShort(sInT, sH - sInB) then
      return kNetRowsShort
   end if
   return kNetRows
end ebNetRowsMost

-- The players the list shows: those who can be challenged first, then by
-- name, as many as it has rows
private command ebNetList
   local tPk, tRank, tSort, tLine, tRows
   put false into sLob["dirty"]
   repeat for each key tPk in sLob["who"]
      switch sLob["who"][tPk]["state"]
         case "quick"
            put 1 into tRank
            break
         case "free"
            put 2 into tRank
            break
         case "busy"
            put 3 into tRank
            break
         default
            put 4 into tRank
      end switch
      put tRank & tab & toUpper(sLob["who"][tPk]["name"]) & tab & tPk & return after tSort
   end repeat
   delete last char of tSort
   sort lines of tSort
   put the number of lines of tSort into sLob["count"]
   set the itemDelimiter to tab
   repeat for each line tLine in line 1 to kNetRows of tSort
      put item 3 of tLine & return after tRows
   end repeat
   set the itemDelimiter to comma
   delete last char of tRows
   put tRows into sLob["rows"]
end ebNetList

-- Each row of the list, when it has its place: the player's name, and
-- what they are doing; dim when they cannot be challenged now. A long
-- name in a narrow row is cut short, never what the player is doing
private command ebNetRowsLook
   local i, tPk, tName, tDoing, tCan, tButton, tWide
   repeat with i = 1 to kNetRows
      put line i of sLob["rows"] into tPk
      if tPk is empty then
         next repeat
      end if
      put toUpper(sLob["who"][tPk]["name"]) into tName
      put true into tCan
      put empty into tDoing
      switch sLob["who"][tPk]["state"]
         case "quick"
            put "  -  QUICK MATCH" into tDoing
            break
         case "busy"
            put "  -  BUSY" into tDoing
            put false into tCan
            break
         case "duel"
            put "  -  IN A DUEL" into tDoing
            put false into tCan
            break
      end switch
      put the long id of button ("Who" && i) into tButton
      put the width of tButton - ebU(16) into tWide
      set the label of tButton to tName & tDoing
      repeat while the formattedWidth of tButton > tWide and the length of tName > 3
         delete last char of tName
         set the label of tButton to tName & ".." & tDoing
      end repeat
      if tCan then
         set the textColor of tButton to kInk
         set the foregroundColor of graphic ("Who" && i && "Shape") to "#8A5A3C"
      else
         set the textColor of tButton to kDim
         set the foregroundColor of graphic ("Who" && i && "Shape") to "#3D2B22"
      end if
   end repeat
end ebNetRowsLook

-- The players the list shows, for the checks: each a name, "=" and what
-- they are doing, with "|" between them
private function ebNetShown
   local tOut, tPk
   repeat for each line tPk in sLob["rows"]
      put sLob["who"][tPk]["name"] & "=" & sLob["who"][tPk]["state"] & "|" after tOut
   end repeat
   delete last char of tOut
   return tOut
end ebNetShown

-- A line under the list, for a while
private command ebNetSaid pText
   put pText into sLob["said"]
   put sLob["clock"] + 8 into sLob["saidUntil"]
   ebLobbyLook empty
end ebNetSaid

-- A row of the list is tapped: a challenge to that player (or, to one
-- who wants a quick match, the match)
private command ebNetChallenge pRow
   local tPk, tState, tId
   if sLobby is not "online" then
      exit ebNetChallenge
   end if
   put line pRow of sLob["rows"] into tPk
   if tPk is empty or sLob["who"][tPk] is not an array then
      exit ebNetChallenge
   end if
   put sLob["who"][tPk]["state"] into tState
   put ebNetNameOf(tPk) into sLob["rival"]
   switch tState
      case "duel"
         ebNetSaid sLob["rival"] && "is in a duel."
         break
      case "busy"
         ebNetSaid sLob["rival"] && "is busy."
         break
      case "quick"
         ebNetLink tPk, ebNetMake(8), "host", empty
         break
      default
         put ebNetMake(8) into tId
         put empty into sLob["ask"]
         put tPk into sLob["ask"]["pk"]
         put tId into sLob["ask"]["id"]
         put sLob["clock"] into sLob["ask"]["since"]
         ebNetTell tPk, "C" && tId
         put "asking" into sLobby
         put "busy" into sLob["state"]
         ebNetSay false
         ebLobbyLook empty
   end switch
end ebNetChallenge

-- A challenge accepted: the link, as its host
private command ebNetAccept
   if sLobby is not "asked" then
      exit ebNetAccept
   end if
   ebNetLink sLob["ask"]["pk"], sLob["ask"]["id"], "host", empty
end ebNetAccept

-- A challenge refused
private command ebNetDecline
   if sLobby is not "asked" then
      exit ebNetDecline
   end if
   ebNetTell sLob["ask"]["pk"], "D" && sLob["ask"]["id"] && "no"
   ebNetHome empty
end ebNetDecline

-- Quick match: the first player who wants one too (ebNetMatch)
private command ebNetQuick
   if sLobby is not "online" then
      exit ebNetQuick
   end if
   put "quick" into sLobby
   put "quick" into sLob["state"]
   put empty into sLob["matchAt"]
   ebNetSay false
   ebLobbyLook empty
end ebNetQuick

-- Play a friend: a room of this player's own, and its code to send
private command ebNetFriend
   if sLobby is not "online" then
      exit ebNetFriend
   end if
   ebNetRoom ebNetMake(kNetCodeLength)
   put "room" into sLobby
   put "quick" into sLob["state"]
   put empty into sLob["matchAt"]
   set the text of field "Code" to sLob["code"]
   ebNetSay true
   ebLobbyLook empty
end ebNetFriend

-- A friend's room, by the code or the link typed or pasted
private command ebNetJoin pText
   local tCode
   if sLobby is not "room-take" then
      exit ebNetJoin
   end if
   put ebNetCode(pText) into tCode
   if tCode is empty then
      set the text of field "Lobby Note" to "That is not a room's code: six letters and numbers, or the link your friend sent."
      exit ebNetJoin
   end if
   ebNetRoom tCode
   put "room-in" into sLobby
   put "quick" into sLob["state"]
   put empty into sLob["matchAt"]
   ebNetSay true
   ebLobbyLook empty
end ebNetJoin

-- Back to where the player waits: the list of players, a quick match or
-- a room (pTo; or with none, where a link was begun from), and a line to
-- say why
private command ebNetHome pNote, pTo
   if pTo is empty then
      put sLob["from"] into pTo
   end if
   if pTo is not among the items of "quick,room,room-in" then
      put "online" into pTo
   end if
   put empty into sLob["from"]
   put empty into sLob["ask"]
   put empty into sLob["link"]
   put pTo into sLobby
   if pTo is "online" then
      put "free" into sLob["state"]
      put pNote into sLob["said"]
      put sLob["clock"] + 8 into sLob["saidUntil"]
      ebNetList
   else
      put "quick" into sLob["state"]
      put empty into sLob["matchAt"]
   end if
   if pTo is "room" then
      set the text of field "Code" to sLob["code"]
   end if
   ebNetSay false
   ebLobbyLook pNote
end ebNetHome

-- Why no link was made, for the lobby to say
private function ebNetNoLink
   return "No link could be made with" && sLob["rival"] & ". Some networks block a direct link."
end ebNetNoLink

-- A link with a player of the lobby: as its host, whose description goes
-- to them when it is made (ebNetDescribed), or as its guest, with theirs
-- (pSdp), whose answer goes back
private command ebNetLink pPk, pId, pRole, pSdp
   local tWhy, tFrom
   put sLobby into tFrom
   if tFrom is "room-take" then
      put "room" into tFrom
   end if
   if tFrom is not among the items of "quick,room,room-in" then
      put "online" into tFrom
   end if
   put tFrom into sLob["from"]
   put ebNetNameOf(pPk) into sLob["rival"]
   put empty into sLob["ask"]
   put empty into sLob["link"]
   put pPk into sLob["link"]["pk"]
   put pId into sLob["link"]["id"]
   if sLob["fake"] is true then
      -- (a test's lobby: no peer, and a description that is a word)
      ebDuelDrop
      put true into sNet2["on"]
      put true into sNet2["fake"]
      put true into sNet2["open"]
      put pRole into sNet2["role"]
      put sClock into sNet2["since"]
   else
      put ebDuelPeer(pRole, pSdp) into tWhy
      if tWhy is not empty then
         ebNetTell pPk, "D" && pId && "failed"
         ebNetNotNow pPk
         ebNetHome "Could not start a link here." && ebDuelWhy()
         exit ebNetLink
      end if
   end if
   put "net" into sNet2["via"]
   put sClock into sNet2["began"]
   put sLob["rival"] into sNet2["name"]
   put "net-link" into sLobby
   put "busy" into sLob["state"]
   ebNetSay false
   ebLobbyLook empty
   if sLob["fake"] is true then
      ebNetDescribed "v=0" & return & "s=" & pRole
   end if
end ebNetLink

-- My description is made (ebDuelMakeCode): to the rival, as the code it
-- would be, through the lobby
private command ebNetDescribed pSdp
   put true into sNet2["told"]
   if sNet2["role"] is "host" then
      ebNetTell sLob["link"]["pk"], "O" && sLob["link"]["id"] && ebDuelEncode("O", pSdp)
   else
      ebNetTell sLob["link"]["pk"], "A" && sLob["link"]["id"] && ebDuelEncode("A", pSdp)
   end if
end ebNetDescribed

-- The rival's answer to my description: the link can open
private command ebNetAnswered pCode
   local tSdp, tResult, tError
   put ebDuelDecode(pCode, "A") into tSdp
   put -1 into tResult
   if char 1 of tSdp is not "!" then
      if sNet2["fake"] is true then
         put 0 into tResult
      else
         try
            put dcSetRemoteDescription(sNet2["peer"], tSdp, "answer") into tResult
         catch tError
            put -1 into tResult
         end try
      end if
   end if
   if tResult is not a number or tResult < 0 then
      ebNetTell sLob["link"]["pk"], "D" && sLob["link"]["id"] && "failed"
      ebDuelGone ebNetNoLink()
      exit ebNetAnswered
   end if
   put true into sNet2["answered"]
end ebNetAnswered

-- A match begins: the lobby is told ("in a duel", for as long as one
-- lasts) and left; leaving the match comes back to it (ebDuelLeave)
private command ebNetBegun
   put true into sNetBack
   -- (a friend's link has done its work: after the match, the lobby)
   put empty into sInvite
   ebNetStop "duel"
end ebNetBegun

----------------------------------------------------------------------
-- For the tests: the clock in the test's hands

-- No loop, no sound, no buzz, no pointer, a fixed seed, and the saved
-- things in pSaveFile
command ebTestBegin pSeed, pSaveFile
   set the defaultStack to the short name of me
   put true into sManual
   ebStopLoop
   if pSeed is a number then
      set the randomSeed to pSeed
   end if
   put pSaveFile into sSaveFile
   ebLoad
   put false into sSound
   put false into sBuzz
   put false into sNoDrops
   -- (and no duel left over from the test before, nor its lobby)
   ebDuelDrop
   ebNetStop
   put empty into sNetSent
   put empty into sSeen
   put 0 into sSeenCount
   put empty into sInvite
   put empty into sRelays
   -- (a test has no lobby unless it asks for one: ebTestSet "nostr")
   put "no" into sNostr
   put false into sNetBack
   put empty into sLobby
   put 0 into sShift
   if sDuel then
      put false into sDuel
      ebLayout
   end if
end ebTestBegin

-- A duel with nobody at its other end: what would be sent is kept
-- (ebDuelSent), and the test says what the rival does (ebDuelReceive)
command ebTestDuel pSeed
   set the defaultStack to the short name of me
   ebDuelDrop
   put true into sNet2["on"]
   put true into sNet2["fake"]
   put true into sNet2["open"]
   put "host" into sNet2["role"]
   ebDuelBegin pSeed
end ebTestDuel

-- The lines a test's duel would have sent since this was last asked;
-- or, with "picture", the last picture of the arena
function ebDuelSent pWhat
   local tSent
   if pWhat is "picture" then
      return sNet2["picture"]
   end if
   put sNet2["sent"] into tSent
   put empty into sNet2["sent"]
   return tSent
end ebDuelSent

-- The lobby with no relay behind it, and this player in it under the key
-- pPk and the name pName: what would be sent is kept (ebNetSent), and the
-- test says what the other players do (ebNetHear)
command ebTestNet pPk, pName
   set the defaultStack to the short name of me
   lock screen
   ebDuelDrop
   ebNetStop
   put false into sDuel
   put "lobby" into sMode
   put empty into sNetSent
   put ebNetName(pName) into sName
   put empty into sLob
   put true into sLob["on"]
   put true into sLob["fake"]
   put pPk into sLob["pk"]
   put 0 into sLob["clock"]
   -- (as the first relay to open does: the lobby, or the room of a
   -- friend's link)
   ebNetRoomName sInvite
   if sInvite is empty then
      put "online" into sLobby
      put "free" into sLob["state"]
   else
      put "room-in" into sLobby
      put "quick" into sLob["state"]
   end if
   ebNetSay true
   ebLobbyLook empty
   ebShowScreen "lobby"
   unlock screen
end ebTestNet

-- What a test's lobby would have sent since this was last asked, a line
-- each: "who" and the words of an "I am here", or "tell", the key of the
-- player it is for, and the words
function ebNetSent
   local tSent
   put sNetSent into tSent
   put empty into sNetSent
   return tSent
end ebNetSent

-- What a player of a test's lobby says, as a relay would bring it: with
-- "who" the words of an "I am here", with "tell" the words to me
command ebNetHear pPk, pWhat, pText, pAgo
   set the defaultStack to the short name of me
   if sLob["on"] is true then
      -- (with pAgo, a message made that many seconds ago, as a relay
      -- that kept it would give it: it has to be news)
      if pAgo is a number then
         if pWhat is "who" then
            if not ebNetFresh(kNetKindWho, pPk, the seconds - pAgo) then
               exit ebNetHear
            end if
         else if not ebNetFresh(kNetKindTell, pPk, the seconds - pAgo) then
            exit ebNetHear
         end if
      end if
      lock screen
      if pWhat is "who" then
         ebNetWho pPk, pText
      else
         ebNetSignal pPk, pText
      end if
      unlock screen
   end if
end ebNetHear

-- A relay of a test's lobby, by its address: asked for as GO ONLINE asks
-- for one (pKind "dial"), or what the one now asked for or open says, as
-- NostrXT's relay library would say it ("open", "error", "disconnected")
command ebNetRelay pUrl, pKind
   local tRelay, tFound
   set the defaultStack to the short name of me
   if sLob["fake"] is not true then
      exit ebNetRelay
   end if
   if pKind is "dial" then
      put true into sLob["wired"]
      get ebNetDial(pUrl)
      exit ebNetRelay
   end if
   put empty into tFound
   repeat for each key tRelay in sLob["url"]
      if sLob["url"][tRelay] is pUrl then
         put tRelay into tFound
      end if
   end repeat
   if tFound is not empty then
      ebNetHeard tFound, pKind
   end if
end ebNetRelay

-- The relays of a test's lobby, a line each in the order of their
-- addresses: the address, and "wait" (asked for) or "open"
function ebNetLines
   local tRelay, tOut
   repeat for each key tRelay in sLob["relay"]
      put sLob["url"][tRelay] && sLob["relay"][tRelay] & return after tOut
   end repeat
   delete the last char of tOut
   sort lines of tOut
   return tOut
end ebNetLines

-- The game, pSeconds on, a sixtieth of a second at a time
command ebTestStep pSeconds
   set the defaultStack to the short name of me
   lock screen
   repeat while pSeconds > 0.0001
      ebAdvance min(pSeconds, 1/60)
      subtract 1/60 from pSeconds
   end repeat
   unlock screen
end ebTestStep

-- One frame that was pSeconds in coming, as when the page was hidden or
-- the phone slept
command ebTestSlept pSeconds
   set the defaultStack to the short name of me
   lock screen
   ebAdvance 0.05, pSeconds
   unlock screen
end ebTestSlept

-- A wall of a test's own in place of the level's: its rows, top first,
-- each of ten places as in levels.txt. A ball waits on the paddle
command ebTestLevel pRows
   local tRow, tCol, tLine, tCode, i
   set the defaultStack to the short name of me
   lock screen
   ebClearThings
   ebResetEffects
   repeat with i = 1 to kCells
      put empty into sBK[i]
   end repeat
   put empty into sBH
   put 0 into sRemaining
   put 0 into tRow
   repeat for each line tLine in pRows
      add 1 to tRow
      repeat with tCol = 1 to kCols
         put char tCol of tLine into tCode
         if tCode is not empty and tCode is not "." then
            ebPutBrick (tRow - 1) * kCols + tCol, tCode
         end if
      end repeat
   end repeat
   ebBrickLooks
   put sNow into sBrickAt
   ebServe
   unlock screen
end ebTestLevel

-- A ball in flight at pX,pY (units of the arena), going pDX,pDY, in
-- place of every other (or, with pKeep, beside them)
command ebTestBall pX, pY, pDX, pDY, pKeep
   set the defaultStack to the short name of me
   lock screen
   if pKeep is not true then
      ebClearKind "Ball"
   end if
   ebNewBall pX, pY, pDX, pDY
   put "live" into sPhase
   put sNow into sBrickAt
   set the visible of field id sId["Hint"] to false
   unlock screen
end ebTestBall

-- The paddle's middle where a test wants it
command ebTestPaddle pX
   put pX into sPadX
   lock screen
   ebSteer 0
   unlock screen
end ebTestPaddle

-- A spark of a kind falling from pX,pY (wide, small, split, blaze,
-- chill, fast, grip, bolts, net, life)
command ebTestDrop pKind, pX, pY
   set the defaultStack to the short name of me
   lock screen
   ebNewDrop pKind, pX, pY
   unlock screen
end ebTestDrop

-- A thing of the run: lives, score, heat, level, speed; drops (whether
-- sparks fall by chance); insets (top,bottom,left,right, as a notch and
-- a home bar would cover) and pointer (touch or mouse), each laid out
-- for at once; left (a duel's seconds); rtc (whether a link can be made:
-- yes or no); nostr (whether there is a lobby: yes or no); relays (the
-- lobby's, in place of its own); invite (a friend's room, as the page's
-- address would name it)
command ebTestSet pName, pValue
   set the defaultStack to the short name of me
   switch pName
      case "lives"
         put pValue into sLives
         break
      case "score"
         put pValue into sScore
         break
      case "heat"
         put pValue into sHeat
         put sNow into sHeatAt
         put 1 + min(4, sHeat div kHeatStep) into sMult
         break
      case "level"
         put pValue into sLevel
         break
      case "speed"
         put pValue into sSpeed
         put pValue into sLevelSpeed
         break
      case "drops"
         put pValue is not true into sNoDrops
         break
      case "insets"
         put pValue into sFakeInsets
         ebLayout
         break
      case "pointer"
         put pValue into sPointer
         break
      case "unlocked"
         put pValue into sUnlocked
         break
      case "left"
         put pValue into sNet2["left"]
         put 0 into sNet2["wait"]
         break
      case "rtc"
         put pValue into sRtc
         break
      case "nostr"
         put pValue into sNostr
         break
      case "relays"
         put pValue into sRelays
         break
      case "invite"
         put ebNetCode(pValue) into sInvite
         break
   end switch
end ebTestSet

-- The brick in a place of the grid: its kind and the hits it still
-- takes ("T2", "31", "X1"), empty for none
function ebBrick pCol, pRow
   local tCell
   put (pRow - 1) * kCols + pCol into tCell
   if sBK[tCell] is empty then
      return empty
   end if
   return sBK[tCell] & sBH[tCell]
end ebBrick

-- The rect of a control of the game by its name, for the checks that
-- press it or look at where it is
function ebRectOf pName
   if there is a control pName then
      return the rect of control pName
   end if
   return empty
end ebRectOf

-- How things are, a line each: name:value. One of the stack's
-- cJavascriptHandlers, so a page can ask it too (the checks that play
-- the game in a browser)
function ebState
   local tOut, tKind, i, tBall
   -- (a line or two at a time: one long statement is an expression as
   -- deep as it is long, and a phone's browser has little stack for it)
   put "mode:" & sMode & return & "phase:" & sPhase & return & "score:" & sScore & return into tOut
   put "lives:" & sLives & return & "level:" & sLevel & return & "heat:" & sHeat & return after tOut
   put "mult:" & sMult & return & "bricks:" & sRemaining & return & "now:" & sNow & return after tOut
   put "padx:" & round(sPadX, 2) & return & "padw:" & round(sPadW, 2) & return & "size:" & sSize & return after tOut
   put "pace:" & sTempo & return & "blaze:" & (sNow < sBlazeUntil) & return & "grip:" & (sNow < sGripUntil) & return after tOut
   put "bolting:" & (sNow < sBoltsUntil) & return & "net:" & sNet & return & "speed:" & round(sSpeed, 2) & return after tOut
   put "best:" & sBest & return & "unlocked:" & sUnlocked & return & "levels:" & sLevelCount & return after tOut
   put "plays:" & sPlays & return & "fps:" & sFps & return & "arena:" & sArena & return after tOut
   put "scale:" & round(sS, 4) & return & "ui:" & round(sUI, 3) & return & "wide:" & sWide & return after tOut
   put "insets:" & sInT & comma & sInB & comma & sInL & comma & sInR & return & "window:" & sW & comma & sH & return after tOut
   put "platform:" & sPlatform & return & "pointer:" & sPointer & return & "sound:" & sSound & return after tOut
   put "buzz:" & sBuzz & return & "effects:" & sEffects & return & "howto:" & sSeenHowto & return after tOut
   put "library:" & sLibrary & return & "audio:" & sAudio & return & "font:" & sFontLoaded & return after tOut
   put "duel:" & sDuel & return & "lobby:" & sLobby & return & "stage:" & sNet2["stage"] & return after tOut
   put "left:" & sNet2["left"] & return & "rival:" & sNet2["their"]["score"] & return after tOut
   put "link:" & (sNet2["open"] is true) & return & "rtc:" & sRtc & return & "shift:" & sShift & return after tOut
   put "code:" & sNet2["code"] & return after tOut
   -- the online lobby: whether there is one, whether the player is in it,
   -- under what name and key, in which room, how many relays are open,
   -- what the player is doing, the rival, and the players the list shows
   put "nostr:" & sNostr & return & "online:" & ebNetIn() & return & "name:" & sName & return after tOut
   put "pk:" & sLob["pk"] & return & "room:" & sLob["code"] & return & "relays:" & ebNetOpen() & return after tOut
   put "doing:" & sLob["state"] & return & "foe:" & sLob["rival"] & return & "invite:" & sInvite & return after tOut
   put "who:" & ebNetShown() & return & "back:" & (sNetBack is true) & return after tOut
   put "work:" & round(sWork, 2) & return & "draw:" & round(sDraw, 2) after tOut
   repeat for each item tKind in "Ball,Drop,Bolt,Spark,Pop"
      put return & toLower(tKind) & "s:" & ebActive(tKind) after tOut
   end repeat
   -- the first ball in play: where it is, which way it goes, whether it
   -- waits on the paddle
   put empty into tBall
   repeat with i = 1 to sCount["Ball"]
      if sBall[i]["on"] then
         put round(sBall[i]["x"], 2) & comma & round(sBall[i]["y"], 2) & comma & round(sBall[i]["dx"], 4) & comma & \
               round(sBall[i]["dy"], 4) & comma & sBall[i]["stuck"] into tBall
         exit repeat
      end if
   end repeat
   put return & "ball:" & tBall after tOut
   return tOut
end ebState
