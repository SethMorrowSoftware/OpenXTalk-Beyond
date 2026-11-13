script "Nova Rescue"
-- Nova Rescue: a space game for a phone, made with OXT-Beyond and the
-- Mobile Web library. Built by tools/web-player/nova-rescue.livecodescript
-- in OXT-Beyond's repository, from this script; its pictures, sounds and
-- font are Kenney's (kenney.nl), CC0.
--
-- You fly a rescue cutter up through a dying star system: astronauts
-- drift down among meteors and raiders, and flying over one rescues it.
-- Rescues in a row raise a streak that multiplies their score; one that
-- drifts away starts it again. A sector ends when its crew is rescued,
-- every fourth with a mothership, and the run ends when the hull is gone.
--
-- How it is made:
--   one card, "Space": the play area is a column down the middle (the
--     whole width on a phone held upright, a portrait column in a wide
--     window, with the HUD at its sides, which cover what leaves the
--     column), and every screen (Title, Howto, Paused, Over, Settings)
--     is a group over it
--   one loop: nrFrame, sent again after every frame, moves everything by
--     the time since the last one, so the game runs at the same speed at
--     25 frames a second as at 60
--   sprites: a fixed set of buttons for each kind of thing that flies,
--     each showing a picture of the "Art" card as its icon. They are
--     shown and hidden, never created while the game plays. Where each
--     one is, how fast it goes and how much it can take are kept here, in
--     an array for each kind (sRock[3]["x"] ...); the buttons only show it
--   coordinates are the card's, in points; speeds are in points a second
--     for a screen 760 points high, times sU (the screen's height over
--     760), so a short screen is crossed in the same time as a tall one
--   messages from a finger: the browser makes the first finger the mouse,
--     so a drag is mouseDown, the mouseLoc every frame, and mouseUp
--
-- For the tests (tests/lcs/webplayer/nova-rescue.livecodescript), the
-- clock can be taken out of the loop's hands: nrTestBegin stops the loop
-- and fixes the random seed, nrTestStep moves the game on by so many
-- seconds, nrState says how things are, and nrTestPut puts a thing where
-- a test wants it.

constant kFont = "KenVector Future"
constant kAmber = "#FFB52E"
constant kDark = "#2A1A05"
constant kInk = "#FFFFFF"
constant kMuted = "#B9B2E0"
constant kGood = "#7CF29A"
constant kBad = "#FF5D73"
constant kSaveName = "nova-rescue.txt"
-- the ship: a shot every kFireEvery seconds; after a hit, kSafeFor
-- seconds when nothing can hit it; how long twin lasers and a shield
-- last; how far it goes for a finger's point (a little more, so that a
-- thumb crosses the screen without leaving it); its speed on the keys;
-- and how near a thing must come to hit it
constant kFireEvery = 0.2
constant kSafeFor = 1.6
constant kTwinFor = 12
constant kShieldFor = 8
constant kDragGain = 1.3
constant kKeySpeed = 380
constant kShipRadius = 15
constant kMaxStreak = 5
constant kMaxHull = 3
-- the tilt: how far the phone may lean from where it was held (in g,
-- along the screen) and the ship not move, for the hand's own sway; how
-- far for its top speed, and that speed (faster than the keys: a lean
-- passes through the slower speeds first); and how long, as a run
-- begins or goes on or the screen turns, the ship holds still while
-- the phone settles in the hand
constant kTiltDead = 0.05
constant kTiltFull = 0.3
constant kTiltTop = 500
constant kTiltSettle = 0.25

-- whether the Mobile Web library is there; the screen showing (title,
-- howto, play, pause, dying, over, settings); where Settings and How to
-- play go back to; the loop's next message; whether a test holds the
-- clock; the time of the last frame, in milliseconds
local sLibrary, sMode, sBack, sHowtoThen, sLoop, sManual, sLast
-- the frames shown in the last second, and since when
local sFps, sFrames, sFpsFrom
-- sClock runs in every screen (the banner, the flash, the title's
-- ship); sNow only while a run plays, and every time of the game is
-- one of it
local sClock, sNow
-- the play column (left,top,right,bottom), the unit of speed, whether the
-- HUD is at the column's sides, where the HUD ends, where the ship may
-- go (left,top,right,bottom), the title's ship, the sector bar and the
-- mothership's
local sPlay, sU, sSideHud, sHudBottom, sShipBounds, sAttract, sBar, sBossBar
-- the controls' ids (sId["Rock"][3], sId["Ship"]), how many of each
-- kind there are, and the pictures: sPic[name] is an image's id,
-- sSize[name] its width,height
local sId, sCount, sPic, sSize
-- the ship
local sShipX, sShipY, sHull, sSafeUntil, sTwinUntil, sShieldUntil, sShieldUp, sNextShot, sShipShown, sFlame
-- a finger on the screen, and where it was at the last frame
local sDragging, sDragFrom
-- the tilt: whether the sensor runs, which way gravity points, the last
-- reading along the screen (its right, its up), the reading the ship
-- holds still at, and until when that follows the phone (nrTiltZero);
-- which way up the screen is (nrScreenAngle), and a test's for it
local sTiltOn, sTiltSign, sTiltX, sTiltY, sTiltZero, sTiltSettle, sTiltAngle, sTestAngle
-- the run
local sScore, sStreak, sSector, sRescued, sRescuedRun, sStarsRun, sLostRun, sBossCount
-- what comes next: the next astronaut, meteor or raider, and ufo; the
-- phase (empty, "warn" before a mothership, "boss" while it fights, and
-- "calm" between sectors) and when it ends; whether a test stopped the
-- spawning; when the run's last screen comes
local sNextPod, sNextHazard, sNextUfo, sPhase, sPhaseAt, sNoSpawn, sOverAt
-- the things that fly, by kind: each sRock[i] (and the others) is an
-- array, with "on" whether it is in play
local sLaser, sBolt, sRock, sFoe, sPod, sPower, sFx, sPop, sStar, sBoss
-- the stars' speed and the speed they are heading for (fast between
-- sectors), the banner, the flash, and the score counting up at the end
local sStarSpeed, sStarTarget, sBannerUntil, sBannerWarn, sFlashUntil, sCountT
-- what the HUD shows now, so that it is changed only when it changes
local sHud
-- kept between visits: the best score, the stars, the settings, whether
-- How to play was seen, and the number of runs
local sBest, sStars, sSound, sBuzz, sControl, sSeenHowto, sPlays
-- another file for them (the tests'), and how the sounds play: "web"
-- (the browser's Web Audio, many at once), "desktop" (the engine's play,
-- one at a time) or "none"
local sSaveFile, sAudio, sAudioDir
-- whether KenVector Future was loaded, and how long a frame's script
-- took, in milliseconds (an average)
local sFontLoaded, sWork, sDraw

----------------------------------------------------------------------
-- Opening and closing

on preOpenStack
   nrInit
end preOpenStack

on closeStack
   nrStopLoop
   put "closed" into sMode
   if sLibrary then
      try
         if sTiltOn then
            mwStopSensor "acceleration"
         end if
         if mwIsWeb() then
            mwKeepAwake false
         end if
         mwStop
      end try
   end if
end closeStack

on resizeStack
   nrResized
   pass resizeStack
end resizeStack

command nrInit
   local tError
   set the defaultStack to the short name of me
   put false into sManual
   put empty into sLoop
   put empty into sSaveFile
   put false into sTiltOn
   put 0 into sTiltSettle
   put 0 into sTiltAngle
   put empty into sTestAngle
   put false into sNoSpawn
   put 0 into sClock
   put 0 into sNow
   put 0 into sFps
   put 0 into sWork
   put 0 into sFrames
   put the milliseconds into sFpsFrom
   nrFindControls
   nrLoadFont
   nrLoad
   -- the library is in OXT-Beyond 0.2.7 and later; without it the game
   -- is a window that plays with the mouse and the keys. No gestures:
   -- the game reads the finger as the mouse
   put true into sLibrary
   try
      mwStart the short name of me, "none"
   catch tError
      put false into sLibrary
   end try
   nrAudioStart
   nrWatchPage
   nrClearWorld
   put empty into sPlay
   nrLayout
   nrGoTitle
end nrInit

-- The ids of the controls and the pictures, once: the loop asks for a
-- control by its id, which is quicker than by its name
private command nrFindControls
   local tKind, i, tImage
   put empty into sId
   put empty into sCount
   repeat for each item tKind in "Laser,Bolt,Rock,Foe,Pod,Power,Fx,Pop,Star,Ring,Hull"
      put 0 into i
      repeat while there is a control (tKind && (i + 1))
         add 1 to i
         put the id of control (tKind && i) into sId[tKind][i]
      end repeat
      put i into sCount[tKind]
   end repeat
   repeat for each item tKind in "Ship,Flame,Cracks,Shield,Boss"
      put the id of control tKind into sId[tKind]
   end repeat
   put empty into sPic
   put empty into sSize
   repeat with i = 1 to the number of images of card "Art" of me
      put the long id of image i of card "Art" of me into tImage
      put the id of tImage into sPic[the short name of tImage]
      put the width of tImage, the height of tImage into sSize[the short name of tImage]
   end repeat
end nrFindControls

-- KenVector Future, from the stack, for the titles, the HUD and the
-- buttons (without it, the stack's own font)
private command nrLoadFont
   local tData, tFile
   if sFontLoaded is true or kFont is among the lines of the fontNames then
      exit nrLoadFont
   end if
   put the cFont of me into tData
   if tData is empty then
      exit nrLoadFont
   end if
   put specialFolderPath("temporary") & "/nova-rescue-kenvector-future.ttf" into tFile
   try
      put tData into url ("binfile:" & tFile)
      start using font file tFile
      put the result is empty into sFontLoaded
   end try
end nrLoadFont

----------------------------------------------------------------------
-- Kept between visits. In a browser, the documents folder is the page's
-- own storage, kept between visits; on a desktop, a folder for this game.

private function nrSavePath
   local tFolder
   if sSaveFile is not empty then
      return sSaveFile
   end if
   if the platform is "HTML5" then
      put specialFolderPath("documents") into tFolder
   else
      put specialFolderPath("temporary") & "/oxt-nova-rescue" into tFolder
   end if
   if there is not a folder tFolder then
      create folder tFolder
   end if
   return tFolder & "/" & kSaveName
end nrSavePath

command nrLoad
   local tText, tLine, tKey, tValue
   put 0 into sBest
   put 0 into sStars
   put 0 into sPlays
   put true into sSound
   put true into sBuzz
   put "drag" into sControl
   put false into sSeenHowto
   try
      put url ("file:" & nrSavePath()) into tText
   end try
   set the itemDelimiter to "="
   repeat for each line tLine in tText
      put item 1 of tLine into tKey
      put item 2 of tLine into tValue
      switch tKey
         case "best"
         case "stars"
         case "plays"
            if tValue is an integer and tValue >= 0 then
               do "put tValue into s" & tKey
            end if
            break
         case "sound"
            put tValue is not "false" into sSound
            break
         case "buzz"
            put tValue is not "false" into sBuzz
            break
         case "control"
            if tValue is "tilt" then
               put "tilt" into sControl
            end if
            break
         case "howto"
            put tValue is "true" into sSeenHowto
            break
      end switch
   end repeat
   set the itemDelimiter to comma
end nrLoad

command nrSave
   local tText
   put "best=" & sBest & return & "stars=" & sStars & return & "plays=" & sPlays & return & \
         "sound=" & sSound & return & "buzz=" & sBuzz & return & "control=" & sControl & return & \
         "howto=" & sSeenHowto & return into tText
   try
      put tText into url ("file:" & nrSavePath())
   end try
end nrSave

----------------------------------------------------------------------
-- Sound. The engine plays one sound at a time, in a browser too, and a
-- shooter makes many at once: in a browser they go to its Web Audio,
-- which mixes them. The page may only make a sound once it has been
-- touched (or clicked, or a key pressed), so the first touch wakes it.

private command nrAudioStart
   local tSounds, tName, tData
   put "none" into sAudio
   put the customProperties["cSounds"] of me into tSounds
   if the keys of tSounds is empty then
      exit nrAudioStart
   end if
   if the platform is "HTML5" then
      try
         do nrAudioScript() as "JavaScript"
         repeat for each key tName in tSounds
            put base64Encode(tSounds[tName]) into tData
            replace return with empty in tData
            do "window.nrAudio.add('" & tName & "','" & tData & "');" as "JavaScript"
         end repeat
         put "web" into sAudio
      end try
   else
      -- written to files when the first sound plays
      put "desktop" into sAudio
      put empty into sAudioDir
   end if
end nrAudioStart

-- The mixer, made once a page: nrAudio.add(name, base64 of a WAV),
-- nrAudio.play(name, volume). The same sound is not started twice in
-- 45 milliseconds (a meteor and the laser that broke it both say boom).
private function nrAudioScript
   return "(function(){if(window.nrAudio)return;" & \
         "var C=window.AudioContext||window.webkitAudioContext;" & \
         "var A=window.nrAudio={c:null,raw:{},buf:{},last:{}};" & \
         "A.decode=function(n){var c=A.c;if(!c||A.buf[n]||!A.raw[n])return;A.buf[n]='wait';" & \
         "var s=atob(A.raw[n]),u=new Uint8Array(s.length);for(var i=0;i<s.length;i++)u[i]=s.charCodeAt(i);" & \
         "var ok=function(b){A.buf[n]=b;},no=function(){A.buf[n]=null;};" & \
         "try{var p=c.decodeAudioData(u.buffer,ok,no);if(p&&p.catch)p.catch(no);}catch(e){no();}};" & \
         "A.add=function(n,d){A.raw[n]=d;A.decode(n);};" & \
         "A.unlock=function(){if(!C)return;if(!A.c){try{A.c=new C();}catch(e){return;}}" & \
         "if(A.c.state==='suspended')A.c.resume();for(var n in A.raw)A.decode(n);};" & \
         "['touchend','pointerup','mousedown','keydown'].forEach(function(e){window.addEventListener(e,A.unlock,true);});" & \
         "A.play=function(n,v){var c=A.c,b=A.buf[n];if(!c||c.state!=='running'||!b||b==='wait')return;" & \
         "var t=c.currentTime;if(A.last[n]&&t-A.last[n]<0.045)return;A.last[n]=t;" & \
         "var s=c.createBufferSource(),g=c.createGain();s.buffer=b;g.gain.value=v;" & \
         "s.connect(g);g.connect(c.destination);s.start(0);};})();"
end nrAudioScript

command nrSound pName, pVolume
   local tSounds, tName
   if sSound is not true then
      exit nrSound
   end if
   if sAudio is "web" then
      try
         do "window.nrAudio.play('" & pName & "'," & pVolume & ");" as "JavaScript"
      end try
   else if sAudio is "desktop" then
      -- (one sound at a time: the lasers would stop every other sound)
      if pName is "shoot" or pName is "enemy-shot" then
         exit nrSound
      end if
      try
         if sAudioDir is empty then
            put specialFolderPath("temporary") & "/oxt-nova-rescue-sounds" into sAudioDir
            if there is not a folder sAudioDir then
               create folder sAudioDir
            end if
            put the customProperties["cSounds"] of me into tSounds
            repeat for each key tName in tSounds
               put tSounds[tName] into url ("binfile:" & sAudioDir & "/" & tName & ".wav")
            end repeat
         end if
         play (sAudioDir & "/" & pName & ".wav")
      catch tName
         put "none" into sAudio
      end try
   end if
end nrSound

-- A buzz, on a phone that can (not an iPhone)
private command nrBuzz pMilliseconds
   if sBuzz is not true or not sLibrary then
      exit nrBuzz
   end if
   try
      mwVibrate pMilliseconds
   end try
end nrBuzz

-- The screen kept on while a run plays (in a page served over https)
private command nrKeepAwake pOn
   if not sLibrary then
      exit nrKeepAwake
   end if
   try
      if mwIsWeb() then
         mwKeepAwake pOn
      end if
   end try
end nrKeepAwake

-- The page tells the stack when it is hidden (another app, another tab,
-- the phone locked), through nrPageHidden, one of the stack's
-- cJavascriptHandlers: a run never plays on behind it. (The loop also
-- pauses a run that it finds was not given a frame for half a second.)
private command nrWatchPage
   if the platform is not "HTML5" then
      exit nrWatchPage
   end if
   try
      do "(function(){if(window.nrPageWatch)return;window.nrPageWatch=1;" & \
            "document.addEventListener('visibilitychange',function(){if(!document.hidden)return;" & \
            "try{var s=document.liveCode.findStackWithName('" & the short name of me & "');" & \
            "if(s&&s.nrPageHidden)s.nrPageHidden();}catch(e){}});})();" as "JavaScript"
   end try
end nrWatchPage

on nrPageHidden
   set the defaultStack to the short name of me
   if sMode is "play" then
      nrPause
   end if
end nrPageHidden

----------------------------------------------------------------------
-- The loop

private command nrSchedule
   if sManual or sLoop is not empty or sMode is "pause" or sMode is "closed" then
      exit nrSchedule
   end if
   if sMode is "play" or sMode is "dying" then
      send "nrFrame" to me in 10 milliseconds
   else
      -- the screens move little: fewer frames, less battery
      send "nrFrame" to me in 30 milliseconds
   end if
   put the result into sLoop
end nrSchedule

private command nrStopLoop
   if sLoop is not empty then
      cancel sLoop
      put empty into sLoop
   end if
end nrStopLoop

on nrFrame
   local tNow, tDt
   put empty into sLoop
   if sManual or sMode is "closed" then
      exit nrFrame
   end if
   set the defaultStack to the short name of me
   put the milliseconds into tNow
   put (tNow - sLast) / 1000 into tDt
   put tNow into sLast
   if tDt > 0.5 and sMode is "play" then
      -- no frame for half a second: the page was hidden, or the
      -- computer slept
      nrPause
      exit nrFrame
   end if
   add 1 to sFrames
   if tNow - sFpsFrom >= 1000 then
      put round(sFrames * 1000 / (tNow - sFpsFrom)) into sFps
      put 0 into sFrames
      put tNow into sFpsFrom
   end if
   lock screen
   nrAdvance max(0, min(tDt, 0.05))
   put sWork * 0.95 + (the milliseconds - tNow) * 0.05 into sWork
   put the milliseconds into tNow
   unlock screen
   put sDraw * 0.95 + (the milliseconds - tNow) * 0.05 into sDraw
   nrSchedule
end nrFrame

-- The game, pDt seconds on
command nrAdvance pDt
   add pDt to sClock
   switch sMode
      case "play"
         add pDt to sNow
         nrPlayStep pDt, true
         break
      case "dying"
         add pDt to sNow
         nrPlayStep pDt, false
         if sNow >= sOverAt then
            nrShowOver
         end if
         break
      case "title"
         nrMoveStars pDt
         nrAttract
         break
      case "over"
         nrCountUp pDt
         break
   end switch
   nrMoveFx pDt
   if sBannerUntil is a number then
      nrBannerStep
   end if
   if sFlashUntil is a number and sClock >= sFlashUntil then
      set the visible of graphic "Flash" to false
      put empty into sFlashUntil
   end if
end nrAdvance

private command nrPlayStep pDt, pAlive
   nrMoveStars pDt
   if pAlive then
      nrSteer pDt
      nrFire
      nrSpawn
   end if
   nrMoveLasers pDt
   nrMoveRocks pDt, pAlive
   nrMoveFoes pDt, pAlive
   nrMoveBoss pDt, pAlive
   nrMoveBolts pDt, pAlive
   nrMovePods pDt, pAlive
   nrMovePowers pDt, pAlive
   if sMode is "play" then
      nrShowShip
      nrSectorFlow
   end if
   nrHud
end nrPlayStep

----------------------------------------------------------------------
-- Screens

command nrShowScreen pName
   lock screen
   set the visible of group "Title" to (pName is "title")
   set the visible of group "Howto" to (pName is "howto")
   set the visible of group "Paused" to (pName is "pause")
   set the visible of group "Over" to (pName is "over")
   set the visible of group "Settings" to (pName is "settings")
   set the visible of graphic "Shade" to (pName is among the items of "howto,pause,over,settings")
   set the visible of group "HUD" to (pName is among the items of "play,pause,over") or \
         (pName is "settings" and sBack is "pause")
   nrShowClip
   unlock screen
end nrShowScreen

-- The covers of the column's sides, over every sprite, in a window wider
-- than the column while a run is on the screen (with the HUD): what
-- leaves the column goes behind them. Not on the title, whose ship
-- stands over the left side of a phone on its side.
private command nrShowClip
   local tOn
   put the visible of group "HUD" and item 1 of sPlay > 0 into tOn
   set the visible of graphic "Clip Left" to tOn
   set the visible of graphic "Clip Right" to tOn
end nrShowClip

command nrGoTitle
   put "title" into sMode
   put false into sDragging
   nrKeepAwake false
   nrClearWorld
   put item 1 of sAttract into sShipX
   put item 2 of sAttract into sShipY
   set the icon of button id sId["Ship"] to sPic["ship"]
   set the visible of button id sId["Ship"] to true
   set the visible of button id sId["Flame"] to true
   nrAttract
   set the text of field "Records" to "BEST" && nrCommas(sBest) & "     STARS" && sStars
   nrShowScreen "title"
   put the milliseconds into sLast
   nrSchedule
end nrGoTitle

-- The ship on the title, rising and falling
private command nrAttract
   local tX, tY
   put item 1 of sAttract into tX
   put item 2 of sAttract + round(6 * sin(sClock * 2.2)) into tY
   set the loc of button id sId["Ship"] to tX, tY
   set the loc of button id sId["Flame"] to tX, tY + 30
   nrFlicker
end nrAttract

-- The flame, one picture then the other (changed only when it changes)
private command nrFlicker
   local tPicture
   if trunc(sClock * 16) mod 2 is 0 then
      put "flame1" into tPicture
   else
      put "flame2" into tPicture
   end if
   if tPicture is not sFlame then
      set the icon of button id sId["Flame"] to sPic[tPicture]
      put tPicture into sFlame
   end if
end nrFlicker

command nrPressPlay
   if not sSeenHowto then
      put "play" into sHowtoThen
      nrShowHowto
   else
      nrNewRun
   end if
end nrPressPlay

private command nrShowHowto
   put "howto" into sMode
   if sHowtoThen is "play" then
      set the label of button "Howto Go" to "PLAY"
   else
      set the label of button "Howto Go" to "GOT IT"
   end if
   nrShowScreen "howto"
end nrShowHowto

private command nrShowSettings pFrom
   put pFrom into sBack
   put "settings" into sMode
   set the text of field "Settings Note" to empty
   nrSettingsLook
   nrShowScreen "settings"
end nrShowSettings

private command nrSettingsBack
   if sBack is "pause" then
      put "pause" into sMode
      nrShowScreen "pause"
   else
      nrGoTitle
   end if
end nrSettingsBack

private command nrSettingsLook
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
   if sControl is "tilt" then
      set the label of button "Controls" to "CONTROLS: TILT"
   else
      set the label of button "Controls" to "CONTROLS: DRAG"
   end if
   put false into tFull
   if sLibrary then
      try
         put mwIsFullScreen() into tFull
      end try
   end if
   if tFull is true then
      set the label of button "Full" to "FULL SCREEN: ON"
   else
      set the label of button "Full" to "FULL SCREEN: OFF"
   end if
end nrSettingsLook

private command nrSettingsNote pText
   set the text of field "Settings Note" to pText
end nrSettingsNote

-- A button of the screens, pressed (pDown) or let go
command nrButtonLook pName, pDown
   local tShape
   put pName && "Shape" into tShape
   if there is not a graphic tShape then
      exit nrButtonLook
   end if
   if pDown then
      set the backgroundColor of graphic tShape to the cDown of graphic tShape
   else
      set the backgroundColor of graphic tShape to the cUp of graphic tShape
   end if
end nrButtonLook

-- What each button of the screens does
command nrPress pName
   local tResult
   set the defaultStack to the short name of me
   nrSound "click", 0.5
   switch pName
      case "Play"
         nrPressPlay
         break
      case "Howto Open"
         put "title" into sHowtoThen
         nrShowHowto
         break
      case "Howto Go"
         if not sSeenHowto then
            put true into sSeenHowto
            nrSave
         end if
         if sHowtoThen is "play" then
            nrNewRun
         else
            nrGoTitle
         end if
         break
      case "Settings Open"
         nrShowSettings "title"
         break
      case "Pause"
         nrPause
         break
      case "Resume"
         nrResume
         break
      case "Restart"
      case "Again"
         nrNewRun
         break
      case "Pause Settings"
         nrShowSettings "pause"
         break
      case "Pause Home"
      case "Over Home"
         nrGoTitle
         break
      case "Settings Back"
         nrSettingsBack
         break
      case "Sound"
         put not sSound into sSound
         nrSave
         nrSettingsLook
         nrSound "click", 0.5
         break
      case "Buzz"
         put not sBuzz into sBuzz
         nrSave
         nrSettingsLook
         nrBuzz 40
         break
      case "Controls"
         if sControl is "tilt" then
            put "drag" into sControl
            nrSettingsNote "Slide a finger anywhere to fly."
         else
            -- the sensor is asked for here, from a tap, as an iPhone
            -- wants
            nrTiltStart
            put the result into tResult
            if tResult is empty then
               put "tilt" into sControl
               nrSettingsNote "Lean the phone to fly; a finger still works."
            else
               nrSettingsNote "This phone or browser has no tilt to read."
            end if
         end if
         nrSave
         nrSettingsLook
         break
      case "Full"
         if sLibrary then
            try
               mwFullScreen not mwIsFullScreen()
               put the result into tResult
            catch tResult
            end try
            if tResult is not empty then
               nrSettingsNote "This browser cannot hide its bars. On an iPhone, add the page to the home screen."
            end if
         end if
         nrSettingsLook
         break
   end switch
end nrPress

-- The keys: P or Escape pauses and goes on, Space or Return plays
on rawKeyDown pKey
   set the defaultStack to the short name of me
   switch pKey
      case 112
      case 80
      case 65307
         if sMode is "play" then
            nrPause
         else if sMode is "pause" then
            nrResume
         else
            pass rawKeyDown
         end if
         break
      case 32
      case 65293
      case 65421
         if sMode is "title" then
            nrPress "Play"
         else if sMode is "over" then
            nrPress "Again"
         else if sMode is "pause" then
            nrPress "Resume"
         else if sMode is "howto" then
            nrPress "Howto Go"
         else if sMode is not "play" then
            pass rawKeyDown
         end if
         break
      default
         pass rawKeyDown
   end switch
end rawKeyDown

-- (the arrows steer, read every frame: they do not change the card)
on arrowKey pDirection
end arrowKey

-- A finger (or the mouse) down anywhere but on a button: in a run, the
-- ship moves as it moves
on mouseDown
   nrFingerDown
end mouseDown

on mouseDoubleDown
   nrFingerDown
end mouseDoubleDown

on mouseUp
   put false into sDragging
end mouseUp

on mouseDoubleUp
   put false into sDragging
end mouseDoubleUp

on mouseRelease
   put false into sDragging
end mouseRelease

private command nrFingerDown
   set the defaultStack to the short name of me
   if sMode is "play" then
      put true into sDragging
      put the mouseLoc into sDragFrom
   end if
end nrFingerDown

----------------------------------------------------------------------
-- A run

command nrNewRun
   set the defaultStack to the short name of me
   nrClearWorld
   put 0 into sScore
   put 1 into sStreak
   put 1 into sSector
   put 0 into sRescued
   put 0 into sRescuedRun
   put 0 into sStarsRun
   put 0 into sLostRun
   put 0 into sBossCount
   put kMaxHull into sHull
   put 0 into sNow
   put -10 into sSafeUntil
   put -10 into sTwinUntil
   put -10 into sShieldUntil
   put false into sShieldUp
   put 0.4 into sNextShot
   put 1.2 into sNextPod
   put 1.8 into sNextHazard
   -- (no ufo in the first sector)
   put 1000000 into sNextUfo
   put empty into sPhase
   nrTiltZero
   put false into sDragging
   put (item 1 of sPlay + item 3 of sPlay) / 2 into sShipX
   put item 4 of sShipBounds - 20 into sShipY
   put empty into sHud
   put empty into sShipShown
   put 1 into sStarTarget
   put "play" into sMode
   nrShowScreen "play"
   set the visible of button id sId["Ship"] to true
   set the visible of button id sId["Flame"] to true
   nrShipLook
   nrShowShip
   nrHud
   nrBossBar false
   nrBanner "SECTOR 1", "RESCUE" && nrQuota() && "CREW", 2, false
   nrSound "start", 0.5
   nrKeepAwake true
   if sControl is "tilt" then
      nrTiltStart
   end if
   put the milliseconds into sLast
   nrSchedule
end nrNewRun

command nrPause
   if sMode is not "play" then
      exit nrPause
   end if
   put "pause" into sMode
   put false into sDragging
   nrStopLoop
   nrKeepAwake false
   nrShowScreen "pause"
end nrPause

command nrResume
   if sMode is not "pause" then
      exit nrResume
   end if
   put "play" into sMode
   put false into sDragging
   nrShowScreen "play"
   nrKeepAwake true
   if sControl is "tilt" then
      nrTiltStart
      nrTiltZero
   end if
   put the milliseconds into sLast
   nrSchedule
end nrResume

-- Everything that flies, put away
command nrClearWorld
   local tKind, i
   repeat for each item tKind in "Laser,Bolt,Rock,Foe,Pod,Power,Fx,Pop"
      repeat with i = 1 to sCount[tKind]
         nrOff tKind, i
      end repeat
   end repeat
   put empty into sBoss
   put false into sBoss["on"]
   repeat for each item tKind in "Boss,Cracks,Shield"
      set the visible of button id sId[tKind] to false
   end repeat
   set the visible of graphic "Flash" to false
   put empty into sFlashUntil
   set the visible of group "Banner" to false
   put empty into sBannerUntil
   nrBossBar false
end nrClearWorld

-- The crew a sector needs, and whether it ends with a mothership
private function nrQuota
   return 4 + sSector
end nrQuota

private function nrBossSector
   return sSector mod 4 is 0
end nrBossSector

-- How much faster things come in later sectors
private function nrPace
   return min(1.6, 1 + 0.05 * (sSector - 1))
end nrPace

private function nrRand pFrom, pTo
   return pFrom + (pTo - pFrom) * (random(1000001) - 1) / 1000000
end nrRand

function nrCommas pNumber
   local tDigits, tOut
   put round(pNumber) into tDigits
   repeat while the number of chars of tDigits > 3
      put comma & char -3 to -1 of tDigits before tOut
      delete char -3 to -1 of tDigits
   end repeat
   return tDigits & tOut
end nrCommas

----------------------------------------------------------------------
-- The ship

private command nrSteer pDt
   local tLoc, tKeys, tVX, tVY, tB
   if sDragging then
      put the mouseLoc into tLoc
      add (item 1 of tLoc - item 1 of sDragFrom) * kDragGain to sShipX
      add (item 2 of tLoc - item 2 of sDragFrom) * kDragGain to sShipY
      put tLoc into sDragFrom
   end if
   put the keysDown into tKeys
   if tKeys is not empty then
      put 0 into tVX
      put 0 into tVY
      if 65361 is among the items of tKeys or 97 is among the items of tKeys or 65 is among the items of tKeys then
         subtract 1 from tVX
      end if
      if 65363 is among the items of tKeys or 100 is among the items of tKeys or 68 is among the items of tKeys then
         add 1 to tVX
      end if
      if 65362 is among the items of tKeys or 119 is among the items of tKeys or 87 is among the items of tKeys then
         subtract 1 from tVY
      end if
      if 65364 is among the items of tKeys or 115 is among the items of tKeys or 83 is among the items of tKeys then
         add 1 to tVY
      end if
      add tVX * kKeySpeed * sU * pDt to sShipX
      add tVY * kKeySpeed * sU * pDt to sShipY
   end if
   -- the tilt: how far the phone leans from where it was held as the
   -- run began, or went on, or the screen turned (until 2026-11-11 the
   -- ship flew 80 points a second for a whole g of lean, about 21 for a
   -- lean of 15 degrees, and the smallest lean moved it: a ship that
   -- drifted, and crawled where it was steered)
   if sControl is "tilt" and sTiltOn and sTiltX is a number and sTiltY is a number then
      if sTiltZero is empty or sNow < sTiltSettle then
         put sTiltX, sTiltY into sTiltZero
      end if
      add nrTiltSpeed(-sTiltSign * (sTiltX - item 1 of sTiltZero)) * sU * pDt to sShipX
      add nrTiltSpeed(sTiltSign * (sTiltY - item 2 of sTiltZero)) * sU * pDt to sShipY
   end if
   put sShipBounds into tB
   put max(item 1 of tB, min(item 3 of tB, sShipX)) into sShipX
   put max(item 2 of tB, min(item 4 of tB, sShipY)) into sShipY
end nrSteer

private command nrFire
   if sNow < sNextShot then
      exit nrFire
   end if
   put sNow + kFireEvery into sNextShot
   if sNow < sTwinUntil then
      nrLaser sShipX - 16, sShipY - 4
      nrLaser sShipX + 16, sShipY - 4
   else
      nrLaser sShipX, sShipY - 22
   end if
   nrSound "shoot", 0.2
end nrFire

private command nrLaser pX, pY
   local i
   put nrFree("Laser") into i
   if i is 0 then
      exit nrLaser
   end if
   put true into sLaser[i]["on"]
   put pX into sLaser[i]["x"]
   put pY into sLaser[i]["y"]
   set the loc of button id sId["Laser"][i] to round(pX), round(pY)
   set the visible of button id sId["Laser"][i] to true
end nrLaser

-- The ship where it is, blinking while nothing can hit it, its flame,
-- its cracks and its shield
private command nrShowShip
   local tX, tY, tShow, tShield
   put round(sShipX) into tX
   put round(sShipY) into tY
   put not (sNow < sSafeUntil and trunc(sNow * 12) mod 2 is 0) into tShow
   if tShow is not sShipShown then
      set the visible of button id sId["Ship"] to tShow
      set the visible of button id sId["Flame"] to tShow
      set the visible of button id sId["Cracks"] to tShow and sHull < kMaxHull
      put tShow into sShipShown
   end if
   set the loc of button id sId["Ship"] to tX, tY
   set the loc of button id sId["Flame"] to tX, tY + 30
   if sHull < kMaxHull then
      set the loc of button id sId["Cracks"] to tX, tY
   end if
   nrFlicker
   -- the shield, blinking in its last second and a half
   put sNow < sShieldUntil and not (sShieldUntil - sNow < 1.5 and trunc(sNow * 8) mod 2 is 0) into tShield
   if tShield is not the visible of button id sId["Shield"] then
      set the visible of button id sId["Shield"] to tShield
   end if
   if tShield then
      set the loc of button id sId["Shield"] to tX, tY
   end if
   if sShieldUp and sNow >= sShieldUntil then
      put false into sShieldUp
      nrSound "shield-down", 0.5
   end if
end nrShowShip

-- The cracks for the hull left
private command nrShipLook
   if sHull >= kMaxHull then
      set the visible of button id sId["Cracks"] to false
   else
      if sHull is 2 then
         set the icon of button id sId["Cracks"] to sPic["ship-damage1"]
      else
         set the icon of button id sId["Cracks"] to sPic["ship-damage3"]
      end if
      set the visible of button id sId["Cracks"] to sShipShown is not false
   end if
end nrShipLook

-- Something reached the ship: "shield" (it took it), "safe" (the ship
-- was blinking, or is gone) or "hit" (a hull point less)
private function nrShipTakes
   if sMode is not "play" then
      return "safe"
   end if
   if sNow < sShieldUntil then
      return "shield"
   end if
   if sNow < sSafeUntil then
      return "safe"
   end if
   subtract 1 from sHull
   put sNow + kSafeFor into sSafeUntil
   nrSound "hit", 0.6
   nrBuzz 90
   nrFlashOn kBad, 0.12
   nrShipLook
   if sHull <= 0 then
      nrDie
   end if
   return "hit"
end nrShipTakes

private function nrTouchesShip pX, pY, pRadius
   local tDX, tDY
   put pX - sShipX into tDX
   put pY - sShipY - 2 into tDY
   return tDX * tDX + tDY * tDY < (pRadius + kShipRadius) * (pRadius + kShipRadius)
end nrTouchesShip

private command nrDie
   local tKind
   put "dying" into sMode
   put false into sDragging
   repeat for each item tKind in "Ship,Flame,Cracks,Shield"
      set the visible of button id sId[tKind] to false
   end repeat
   nrBoom sShipX, sShipY, "big"
   nrFx "laser-hit,smoke2,smoke3", 0.08, sShipX + 14, sShipY - 10, 0, 0, 0.2
   nrFx "laser-hit,smoke2,smoke3", 0.08, sShipX - 12, sShipY + 8, 0, 0, 0.35
   nrBuzz 260
   put sNow + 1.8 into sOverAt
   nrKeepAwake false
end nrDie

private command nrShowOver
   local tNew
   put "over" into sMode
   put sScore > sBest into tNew
   if tNew then
      put sScore into sBest
   end if
   add sStarsRun to sStars
   add 1 to sPlays
   nrSave
   put 0 into sCountT
   set the text of field "Final" to 0
   if tNew and sScore > 0 then
      set the text of field "Best Note" to "NEW BEST!"
      set the textColor of field "Best Note" to kGood
      nrSound "best", 0.6
   else
      set the text of field "Best Note" to "BEST" && nrCommas(sBest)
      set the textColor of field "Best Note" to kMuted
      nrSound "game-over", 0.6
   end if
   set the text of field "Stats" to "SECTOR" && sSector & "     RESCUED" && sRescuedRun & return & \
         "STARS +" & sStarsRun & "     ALL STARS" && sStars
   set the visible of group "Banner" to false
   put empty into sBannerUntil
   nrShowScreen "over"
end nrShowOver

-- The final score counting up
private command nrCountUp pDt
   if sCountT is not a number or sCountT >= 1 then
      exit nrCountUp
   end if
   add pDt to sCountT
   set the text of field "Final" to nrCommas(sScore * min(1, sCountT / 0.9))
end nrCountUp

----------------------------------------------------------------------
-- What comes, and when

private command nrSpawn
   local tPods
   if sNoSpawn or sPhase is "calm" or sPhase is "warn" then
      exit nrSpawn
   end if
   if sPhase is "boss" then
      -- a meteor now and then while the mothership fights
      if sNow >= sNextHazard then
         nrSpawnRock "med"
         put sNow + nrRand(2.4, 3.4) into sNextHazard
      end if
      exit nrSpawn
   end if
   if sNow >= sNextPod then
      put nrActive("Pod") into tPods
      if tPods < 2 and sRescued + tPods < nrQuota() then
         nrSpawnPod
      end if
      put sNow + nrRand(3.0, 4.0) into sNextPod
   end if
   if sNow >= sNextHazard then
      nrSpawnHazard
      put sNow + max(0.45, 1.2 / (1 + 0.1 * (sSector - 1))) * nrRand(0.75, 1.25) into sNextHazard
   end if
   if sNow >= sNextUfo then
      nrSpawnFoe "ufo"
      put 1000000 into sNextUfo
   end if
end nrSpawn

private command nrSpawnHazard
   local tRocks, tRoll, tGunships, i, tX
   if sSector is 1 then
      put 62 into tRocks
   else if sSector is 2 then
      put 48 into tRocks
   else
      put 40 into tRocks
   end if
   if random(100) <= tRocks then
      if random(100) <= 55 then
         nrSpawnRock "big"
      else
         nrSpawnRock "med"
      end if
      exit nrSpawnHazard
   end if
   put random(100) into tRoll
   put 0 into tGunships
   repeat with i = 1 to sCount["Foe"]
      if sFoe[i]["on"] and sFoe[i]["kind"] is "gunship" then
         add 1 to tGunships
      end if
   end repeat
   if sSector >= 3 and tRoll <= 30 and (tGunships is 0 or (sSector >= 5 and tGunships < 2)) then
      nrSpawnFoe "gunship"
   else if sSector >= 2 and tRoll <= 65 then
      nrSpawnFoe "weaver"
   else if sSector >= 3 and random(3) is 1 then
      -- three scouts in a line
      put nrRand(item 1 of sPlay + 80, item 3 of sPlay - 80) into tX
      nrSpawnFoe "scout", tX - 44, item 2 of sPlay - 60
      nrSpawnFoe "scout", tX, item 2 of sPlay - 30
      nrSpawnFoe "scout", tX + 44, item 2 of sPlay - 60
   else
      nrSpawnFoe "scout"
   end if
end nrSpawnHazard

-- A meteor (pSize: big, med or small), where it is asked for or at the
-- top, falling as fast as it is asked or as its size falls
command nrSpawnRock pSize, pX, pY, pVX, pVY
   local i, tPic
   put nrFree("Rock") into i
   if i is 0 then
      exit nrSpawnRock
   end if
   if pX is empty then
      put nrRand(item 1 of sPlay + 30, item 3 of sPlay - 30) into pX
      put item 2 of sPlay - 40 into pY
   end if
   if pVY is empty then
      if pSize is "big" then
         put nrRand(-28, 28) * sU into pVX
         put nrRand(70, 105) * sU * nrPace() into pVY
      else
         put nrRand(-42, 42) * sU into pVX
         put nrRand(90, 135) * sU * nrPace() into pVY
      end if
   end if
   put "meteor-" & pSize & random(3) into tPic
   put empty into sRock[i]
   put true into sRock[i]["on"]
   put pSize into sRock[i]["size"]
   put pX into sRock[i]["x"]
   put pY into sRock[i]["y"]
   put pVX into sRock[i]["vx"]
   put pVY into sRock[i]["vy"]
   switch pSize
      case "big"
         put 3 into sRock[i]["hp"]
         put 23 into sRock[i]["r"]
         break
      case "med"
         put 2 into sRock[i]["hp"]
         put 12 into sRock[i]["r"]
         break
      default
         put 1 into sRock[i]["hp"]
         put 8 into sRock[i]["r"]
   end switch
   nrSprite sId["Rock"][i], tPic, pX, pY
end nrSpawnRock

-- A raider: scout, weaver, gunship or ufo
command nrSpawnFoe pKind, pX, pY
   local i, tF, tL, tR
   put nrFree("Foe") into i
   if i is 0 then
      exit nrSpawnFoe
   end if
   put item 1 of sPlay into tL
   put item 3 of sPlay into tR
   put pKind into tF["kind"]
   put true into tF["on"]
   put 0 into tF["age"]
   if pY is empty then
      put item 2 of sPlay - 30 into pY
   end if
   switch pKind
      case "scout"
         if pX is empty then
            put nrRand(tL + 30, tR - 30) into pX
         end if
         put 205 * sU * nrPace() into tF["vy"]
         put 1 into tF["hp"]
         put 19 into tF["r"]
         put 100 into tF["points"]
         break
      case "weaver"
         if pX is empty then
            put nrRand(tL + 76, tR - 76) into pX
         end if
         put pX into tF["base"]
         put random(628) / 100 into tF["phase"]
         put 105 * sU * nrPace() into tF["vy"]
         put 2 into tF["hp"]
         put 20 into tF["r"]
         put 150 into tF["points"]
         break
      case "gunship"
         if pX is empty then
            put nrRand(tL + 40, tR - 40) into pX
         end if
         put 130 * sU into tF["vy"]
         put sHudBottom + 40 + nrRand(10, 80) * sU into tF["stop"]
         if random(2) is 1 then
            put 80 * sU into tF["vx"]
         else
            put -80 * sU into tF["vx"]
         end if
         put sNow + 1.1 into tF["fire"]
         put sNow + 8.5 into tF["leave"]
         put 3 into tF["hp"]
         put 21 into tF["r"]
         put 200 into tF["points"]
         break
      case "ufo"
         if random(2) is 1 then
            put tL - 24 into pX
            put 118 * sU into tF["vx"]
         else
            put tR + 24 into pX
            put -118 * sU into tF["vx"]
         end if
         put sHudBottom + 60 + nrRand(0, 60) * sU into pY
         put pY into tF["base"]
         put 4 into tF["hp"]
         put 22 into tF["r"]
         put 300 into tF["points"]
         break
   end switch
   put pX into tF["x"]
   put pY into tF["y"]
   put tF into sFoe[i]
   nrSprite sId["Foe"][i], pKind, pX, pY
end nrSpawnFoe

-- An astronaut drifting down
command nrSpawnPod pX, pY, pVY
   local i
   put nrFree("Pod") into i
   if i is 0 then
      exit nrSpawnPod
   end if
   if pX is empty then
      put nrRand(item 1 of sPlay + 40, item 3 of sPlay - 40) into pX
      put item 2 of sPlay - 30 into pY
   end if
   if pVY is empty then
      put nrRand(72, 92) * sU into pVY
   end if
   put empty into sPod[i]
   put true into sPod[i]["on"]
   put pX into sPod[i]["base"]
   put pX into sPod[i]["x"]
   put pY into sPod[i]["y"]
   put pVY into sPod[i]["vy"]
   put random(628) / 100 into sPod[i]["age"]
   put 1 into sPod[i]["frame"]
   nrSprite sId["Pod"][i], "astronaut1", pX, pY
   set the visible of graphic id sId["Ring"][i] to true
end nrSpawnPod

-- A power-up (twin, shield, repair or star)
command nrSpawnPower pKind, pX, pY
   local i
   put nrFree("Power") into i
   if i is 0 then
      exit nrSpawnPower
   end if
   put empty into sPower[i]
   put true into sPower[i]["on"]
   put pKind into sPower[i]["kind"]
   put pX into sPower[i]["x"]
   put pY into sPower[i]["y"]
   if pKind is "star" then
      nrSprite sId["Power"][i], "star", pX, pY
   else
      nrSprite sId["Power"][i], "power-" & pKind, pX, pY
   end if
end nrSpawnPower

-- A power-up, pChance times in a hundred
private command nrDrop pX, pY, pChance
   local tRoll
   if random(100) > pChance then
      exit nrDrop
   end if
   put random(100) into tRoll
   if tRoll <= 35 then
      nrSpawnPower "twin", pX, pY
   else if tRoll <= 60 then
      nrSpawnPower "shield", pX, pY
   else if tRoll <= 80 and sHull < kMaxHull then
      nrSpawnPower "repair", pX, pY
   else
      nrSpawnPower "star", pX, pY
   end if
end nrDrop

-- A shot of a raider, at pSpeed toward the ship (straight down if the
-- ship is beside it or above it)
private command nrAimedShot pX, pY, pPicture, pSpeed
   local tDX, tDY, tLength
   put sShipX - pX into tDX
   put sShipY - pY into tDY
   if tDY < 60 then
      put 0 into tDX
      put 1 into tDY
   end if
   put sqrt(tDX * tDX + tDY * tDY) into tLength
   nrEnemyShot pX, pY, tDX / tLength * pSpeed * sU, tDY / tLength * pSpeed * sU, pPicture
end nrAimedShot

command nrEnemyShot pX, pY, pVX, pVY, pPicture
   local i
   put nrFree("Bolt") into i
   if i is 0 then
      exit nrEnemyShot
   end if
   put empty into sBolt[i]
   put true into sBolt[i]["on"]
   put pX into sBolt[i]["x"]
   put pY into sBolt[i]["y"]
   put pVX into sBolt[i]["vx"]
   put pVY into sBolt[i]["vy"]
   if pPicture is "missile" then
      put 6 into sBolt[i]["r"]
   else
      put 5 into sBolt[i]["r"]
   end if
   nrSprite sId["Bolt"][i], pPicture, pX, pY
   nrSound "enemy-shot", 0.22
end nrEnemyShot

----------------------------------------------------------------------
-- What flies, a frame on

private command nrMoveLasers pDt
   local i, tX, tY, tStep, tTop
   put 860 * sU * pDt into tStep
   put item 2 of sPlay - 40 into tTop
   repeat with i = 1 to sCount["Laser"]
      if not sLaser[i]["on"] then
         next repeat
      end if
      put sLaser[i]["x"] into tX
      put sLaser[i]["y"] - tStep into tY
      put tY into sLaser[i]["y"]
      if tY < tTop then
         nrOff "Laser", i
      else if nrLaserHits(tX, tY - 16, tY - 16 + tStep) then
         -- (its tip, from where it was to where it is: a fast laser on
         -- a slow frame would otherwise go through a small meteor)
         nrOff "Laser", i
      else
         set the loc of button id sId["Laser"][i] to round(tX), round(tY)
      end if
   end repeat
end nrMoveLasers

-- Whether a laser's tip, at pX between pTop and pBottom, hit something
-- (and if it did, the hit)
private function nrLaserHits pX, pTop, pBottom
   local i, tR, tY, tVisible
   put item 2 of sPlay - 8 into tVisible
   repeat with i = 1 to sCount["Rock"]
      if sRock[i]["on"] then
         put sRock[i]["r"] + 3 into tR
         put sRock[i]["y"] into tY
         if abs(sRock[i]["x"] - pX) < tR and tY + tR >= pTop and tY - tR <= pBottom and tY > tVisible then
            nrHitRock i, pX, tY + tR * 0.6
            return true
         end if
      end if
   end repeat
   repeat with i = 1 to sCount["Foe"]
      if sFoe[i]["on"] then
         put sFoe[i]["r"] + 3 into tR
         put sFoe[i]["y"] into tY
         if abs(sFoe[i]["x"] - pX) < tR and tY + tR >= pTop and tY - tR <= pBottom and tY > tVisible then
            nrHitFoe i, pX, tY + tR * 0.6
            return true
         end if
      end if
   end repeat
   if sBoss["on"] and sBoss["y"] > tVisible then
      put sBoss["y"] into tY
      if abs(sBoss["x"] - pX) < 58 and tY + 40 >= pTop and tY - 50 <= pBottom then
         nrHitBoss pX, tY + 34
         return true
      end if
   end if
   return false
end nrLaserHits

private command nrMoveRocks pDt, pAlive
   local i, tE, tL, tR, tBottom, tTook
   put item 1 of sPlay into tL
   put item 3 of sPlay into tR
   put item 4 of sPlay into tBottom
   repeat with i = 1 to sCount["Rock"]
      if not sRock[i]["on"] then
         next repeat
      end if
      put sRock[i] into tE
      add tE["vx"] * pDt to tE["x"]
      add tE["vy"] * pDt to tE["y"]
      put tE into sRock[i]
      if tE["y"] > tBottom + 50 or tE["x"] < tL - 60 or tE["x"] > tR + 60 then
         nrOff "Rock", i
      else if pAlive and nrTouchesShip(tE["x"], tE["y"], tE["r"]) then
         put nrShipTakes() into tTook
         if tTook is "shield" then
            nrBreakRock i, true
         else if tTook is "hit" then
            nrBreakRock i, false
         else
            set the loc of button id sId["Rock"][i] to round(tE["x"]), round(tE["y"])
         end if
      else
         set the loc of button id sId["Rock"][i] to round(tE["x"]), round(tE["y"])
      end if
   end repeat
end nrMoveRocks

private command nrHitRock i, pX, pY
   subtract 1 from sRock[i]["hp"]
   if sRock[i]["hp"] > 0 then
      nrFx "laser-hit", 0.05, pX, pY, 0, 0, 0
      exit nrHitRock
   end if
   nrBreakRock i, true
end nrHitRock

-- A meteor broken: by lasers or the shield it scores and splits in two
-- (pSplits); against the hull it is only gone
private command nrBreakRock i, pSplits
   local tE, tSide
   put sRock[i] into tE
   nrOff "Rock", i
   switch tE["size"]
      case "big"
         nrBoom tE["x"], tE["y"], "medium"
         if pSplits then
            add 50 to sScore
            put nrRand(55, 85) * sU into tSide
            nrSpawnRock "med", tE["x"] - 10, tE["y"], -tSide, tE["vy"] * 0.9
            nrSpawnRock "med", tE["x"] + 10, tE["y"], tSide, tE["vy"] * 0.9
         end if
         break
      case "med"
         nrBoom tE["x"], tE["y"], "small"
         if pSplits then
            add 30 to sScore
            put nrRand(60, 95) * sU into tSide
            nrSpawnRock "small", tE["x"] - 6, tE["y"], -tSide, tE["vy"]
            nrSpawnRock "small", tE["x"] + 6, tE["y"], tSide, tE["vy"]
         end if
         break
      default
         nrBoom tE["x"], tE["y"], "small"
         if pSplits then
            add 20 to sScore
         end if
   end switch
end nrBreakRock

private command nrMoveFoes pDt, pAlive
   local i, tE, tL, tR, tBottom, tTook, tDX
   put item 1 of sPlay into tL
   put item 3 of sPlay into tR
   put item 4 of sPlay into tBottom
   repeat with i = 1 to sCount["Foe"]
      if not sFoe[i]["on"] then
         next repeat
      end if
      put sFoe[i] into tE
      add pDt to tE["age"]
      switch tE["kind"]
         case "scout"
            -- it dives, and leans toward the ship
            put sShipX - tE["x"] into tDX
            add max(-70, min(70, tDX)) * 0.9 * sU * pDt to tE["x"]
            add tE["vy"] * pDt to tE["y"]
            break
         case "weaver"
            add tE["vy"] * pDt to tE["y"]
            put tE["base"] + 64 * sin(tE["phase"] + tE["age"] * 2.6) into tE["x"]
            break
         case "gunship"
            -- down to its place, from side to side firing, then away
            if sNow >= tE["leave"] then
               add 150 * sU * pDt to tE["y"]
            else if tE["y"] < tE["stop"] then
               add tE["vy"] * pDt to tE["y"]
            else
               add tE["vx"] * pDt to tE["x"]
               if tE["x"] < tL + 34 then
                  put abs(tE["vx"]) into tE["vx"]
               else if tE["x"] > tR - 34 then
                  put -abs(tE["vx"]) into tE["vx"]
               end if
               if pAlive and sNow >= tE["fire"] then
                  nrAimedShot tE["x"], tE["y"] + 22, "bolt", 215
                  put sNow + nrRand(1.6, 2.3) into tE["fire"]
               end if
            end if
            break
         case "ufo"
            add tE["vx"] * pDt to tE["x"]
            put tE["base"] + 14 * sin(tE["age"] * 3) into tE["y"]
            break
      end switch
      put tE into sFoe[i]
      if tE["y"] > tBottom + 50 or tE["x"] < tL - 70 or tE["x"] > tR + 70 then
         nrOff "Foe", i
      else if pAlive and nrTouchesShip(tE["x"], tE["y"], tE["r"]) then
         put nrShipTakes() into tTook
         if tTook is "shield" then
            nrKillFoe i, true
         else if tTook is "hit" then
            nrKillFoe i, false
         else
            set the loc of button id sId["Foe"][i] to round(tE["x"]), round(tE["y"])
         end if
      else
         set the loc of button id sId["Foe"][i] to round(tE["x"]), round(tE["y"])
      end if
   end repeat
end nrMoveFoes

private command nrHitFoe i, pX, pY
   subtract 1 from sFoe[i]["hp"]
   if sFoe[i]["hp"] > 0 then
      nrFx "laser-hit", 0.05, pX, pY, 0, 0, 0
      exit nrHitFoe
   end if
   nrKillFoe i, true
end nrHitFoe

-- A raider gone: shot (pScores), or into the hull
private command nrKillFoe i, pScores
   local tE
   put sFoe[i] into tE
   nrOff "Foe", i
   if tE["kind"] is "gunship" or tE["kind"] is "ufo" then
      nrBoom tE["x"], tE["y"], "big"
   else
      nrBoom tE["x"], tE["y"], "medium"
   end if
   if not pScores then
      exit nrKillFoe
   end if
   add tE["points"] to sScore
   if tE["kind"] is "ufo" then
      nrPop "+" & tE["points"], tE["x"], tE["y"] - 24, kAmber
      nrDrop tE["x"], tE["y"], 100
   else
      if tE["kind"] is "gunship" then
         nrPop "+" & tE["points"], tE["x"], tE["y"] - 24, kAmber
      end if
      nrDrop tE["x"], tE["y"], 12
   end if
end nrKillFoe

private command nrMoveBolts pDt, pAlive
   local i, tE, tL, tR, tTop, tBottom, tTook
   put item 1 of sPlay into tL
   put item 3 of sPlay into tR
   put item 2 of sPlay into tTop
   put item 4 of sPlay into tBottom
   repeat with i = 1 to sCount["Bolt"]
      if not sBolt[i]["on"] then
         next repeat
      end if
      put sBolt[i] into tE
      add tE["vx"] * pDt to tE["x"]
      add tE["vy"] * pDt to tE["y"]
      put tE into sBolt[i]
      if tE["y"] > tBottom + 30 or tE["y"] < tTop - 60 or tE["x"] < tL - 30 or tE["x"] > tR + 30 then
         nrOff "Bolt", i
      else if pAlive and nrTouchesShip(tE["x"], tE["y"], tE["r"]) then
         put nrShipTakes() into tTook
         if tTook is "safe" then
            set the loc of button id sId["Bolt"][i] to round(tE["x"]), round(tE["y"])
         else
            nrOff "Bolt", i
            nrFx "bolt-hit", 0.06, tE["x"], tE["y"], 0, 0, 0
         end if
      else
         set the loc of button id sId["Bolt"][i] to round(tE["x"]), round(tE["y"])
      end if
   end repeat
end nrMoveBolts

-- The astronauts drift down, swaying, waving (three pictures), each in
-- its ring; one the ship reaches is rescued, one that falls off the
-- bottom is lost
private command nrMovePods pDt, pAlive
   local i, tE, tBottom, tFrame, tRing
   put item 4 of sPlay into tBottom
   repeat with i = 1 to sCount["Pod"]
      if not sPod[i]["on"] then
         next repeat
      end if
      put sPod[i] into tE
      add tE["vy"] * pDt to tE["y"]
      add pDt to tE["age"]
      put tE["base"] + 12 * sin(tE["age"] * 1.6) into tE["x"]
      put tE into sPod[i]
      if pAlive and nrTouchesShip(tE["x"], tE["y"], 22) then
         nrRescue i
      else if tE["y"] > tBottom + 30 then
         nrLost i
      else
         put 1 + trunc(tE["age"] / 0.28) mod 3 into tFrame
         if tFrame is not tE["frame"] then
            set the icon of button id sId["Pod"][i] to sPic["astronaut" & tFrame]
            put tFrame into sPod[i]["frame"]
         end if
         set the loc of button id sId["Pod"][i] to round(tE["x"]), round(tE["y"])
         put 25 + round(3 * sin(tE["age"] * 5)) into tRing
         set the rect of graphic id sId["Ring"][i] to round(tE["x"]) - tRing, round(tE["y"]) - tRing, \
               round(tE["x"]) + tRing, round(tE["y"]) + tRing
      end if
   end repeat
end nrMovePods

private command nrRescue i
   local tPoints
   put 250 * sStreak into tPoints
   add tPoints to sScore
   nrPop "+" & nrCommas(tPoints), sPod[i]["x"], sPod[i]["y"] - 26, kGood
   if sStreak < kMaxStreak then
      add 1 to sStreak
   end if
   add 1 to sRescued
   add 1 to sRescuedRun
   nrOff "Pod", i
   nrSound "rescue", 0.5
   if sRescued >= nrQuota() and sPhase is empty then
      nrQuotaMet
   end if
end nrRescue

private command nrLost i
   local tX
   put sPod[i]["x"] into tX
   nrOff "Pod", i
   add 1 to sLostRun
   if sStreak > 1 then
      nrPop "BONUS LOST", tX, item 4 of sPlay - 70, kBad
   else
      nrPop "CREW LOST", tX, item 4 of sPlay - 70, kBad
   end if
   put 1 into sStreak
   nrSound "shield-down", 0.4
end nrLost

private command nrMovePowers pDt, pAlive
   local i, tY, tBottom
   put item 4 of sPlay into tBottom
   repeat with i = 1 to sCount["Power"]
      if not sPower[i]["on"] then
         next repeat
      end if
      put sPower[i]["y"] + 85 * sU * pDt into tY
      put tY into sPower[i]["y"]
      if pAlive and nrTouchesShip(sPower[i]["x"], tY, 16) then
         nrPowerUp i
      else if tY > tBottom + 30 then
         nrOff "Power", i
      else
         set the loc of button id sId["Power"][i] to round(sPower[i]["x"]), round(tY)
      end if
   end repeat
end nrMovePowers

private command nrPowerUp i
   local tX, tY
   put sPower[i]["x"] into tX
   put sPower[i]["y"] - 26 into tY
   switch sPower[i]["kind"]
      case "twin"
         put sNow + kTwinFor into sTwinUntil
         nrPop "TWIN LASER", tX, tY, kAmber
         nrSound "power", 0.5
         break
      case "shield"
         put sNow + kShieldFor into sShieldUntil
         put true into sShieldUp
         nrPop "SHIELD", tX, tY, kGood
         nrSound "shield-up", 0.5
         break
      case "repair"
         if sHull < kMaxHull then
            add 1 to sHull
            nrShipLook
            nrPop "REPAIR", tX, tY, kGood
         else
            add 500 to sScore
            nrPop "+500", tX, tY, kAmber
         end if
         nrSound "power", 0.5
         break
      case "star"
         add 1 to sStarsRun
         add 100 to sScore
         nrPop "+1 STAR", tX, tY, kAmber
         nrSound "power", 0.5
         break
   end switch
   nrOff "Power", i
end nrPowerUp

----------------------------------------------------------------------
-- Sectors and the mothership

private command nrQuotaMet
   if nrBossSector() then
      put "warn" into sPhase
      put sNow + 2.6 into sPhaseAt
      nrBanner "WARNING", "MOTHERSHIP INBOUND", 2.6, true
      nrSound "warning", 0.6
   else
      nrSectorClear
   end if
end nrQuotaMet

private command nrSectorClear
   local tBonus
   put 500 * sSector + 100 * sHull into tBonus
   add tBonus to sScore
   add 1 to sStarsRun
   nrBanner "SECTOR" && sSector && "CLEAR", "+" & nrCommas(tBonus) & "   +1 STAR", 2.6, false
   nrSound "clear", 0.6
   put "calm" into sPhase
   put sNow + 3.2 into sPhaseAt
   -- the stars rush by between sectors
   put 5 into sStarTarget
end nrSectorClear

private command nrSectorFlow
   if sPhase is "warn" and sNow >= sPhaseAt then
      put "boss" into sPhase
      nrBossStart
   else if sPhase is "calm" and sNow >= sPhaseAt then
      add 1 to sSector
      put 0 into sRescued
      put empty into sPhase
      put 1 into sStarTarget
      put sNow + 1 into sNextPod
      put sNow + 1.4 into sNextHazard
      if sSector >= 2 then
         put sNow + nrRand(12, 30) into sNextUfo
      end if
      if nrBossSector() then
         nrBanner "SECTOR" && sSector, "RESCUE" && nrQuota() && "CREW, THEN THE MOTHERSHIP", 2.2, false
      else
         nrBanner "SECTOR" && sSector, "RESCUE" && nrQuota() && "CREW", 2, false
      end if
   end if
end nrSectorFlow

private command nrBossStart
   add 1 to sBossCount
   put empty into sBoss
   put true into sBoss["on"]
   put "enter" into sBoss["stage"]
   put (item 1 of sPlay + item 3 of sPlay) / 2 into sBoss["x"]
   put item 2 of sPlay - 70 into sBoss["y"]
   put sHudBottom + 110 * sU into sBoss["home"]
   put 70 * sU into sBoss["vx"]
   put 60 + 25 * (sBossCount - 1) into sBoss["hp"]
   put sBoss["hp"] into sBoss["max"]
   put sNow + 3.2 into sBoss["fire"]
   put sNow + 4.6 into sBoss["missile"]
   put sNow + 6 into sBoss["launch"]
   nrSprite sId["Boss"], "mothership", sBoss["x"], sBoss["y"]
   nrBossBar true
end nrBossStart

private command nrMoveBoss pDt, pAlive
   local tX, tY, tAngle, tDX, tDY, tTook, tL, tR
   if not sBoss["on"] then
      exit nrMoveBoss
   end if
   put sBoss["x"] into tX
   put sBoss["y"] into tY
   if sBoss["stage"] is "enter" then
      add 75 * sU * pDt to tY
      if tY >= sBoss["home"] then
         put "fight" into sBoss["stage"]
      end if
   else
      put item 1 of sPlay + 80 into tL
      put item 3 of sPlay - 80 into tR
      add sBoss["vx"] * pDt to tX
      if tX < tL then
         put abs(sBoss["vx"]) into sBoss["vx"]
      else if tX > tR then
         put -abs(sBoss["vx"]) into sBoss["vx"]
      end if
      put sBoss["home"] + 8 * sin(sNow * 1.3) into tY
      if pAlive then
         -- a fan of five bolts, more often as it weakens
         if sNow >= sBoss["fire"] then
            repeat with tAngle = -36 to 36 step 18
               nrEnemyShot tX, tY + 50, sin(tAngle * pi / 180) * 185 * sU, cos(tAngle * pi / 180) * 185 * sU, "bolt"
            end repeat
            put sNow + 1.5 + 0.9 * sBoss["hp"] / sBoss["max"] into sBoss["fire"]
         end if
         if sNow >= sBoss["missile"] then
            nrAimedShot tX, tY + 56, "missile", 165
            put sNow + 3.2 into sBoss["missile"]
         end if
         if sNow >= sBoss["launch"] then
            nrSpawnFoe "scout", tX - 50, tY + 30
            put sNow + 5.5 into sBoss["launch"]
         end if
      end if
   end if
   put tX into sBoss["x"]
   put tY into sBoss["y"]
   set the loc of button id sId["Boss"] to round(tX), round(tY)
   if pAlive then
      put (sShipX - tX) / 64 into tDX
      put (sShipY - tY) / 52 into tDY
      if tDX * tDX + tDY * tDY < 1 then
         put nrShipTakes() into tTook
      end if
   end if
end nrMoveBoss

private command nrHitBoss pX, pY
   subtract 1 from sBoss["hp"]
   nrFx "laser-hit", 0.05, pX, pY, 0, 0, 0
   nrBossBar true
   if sBoss["hp"] <= 0 then
      nrKillBoss
   end if
end nrHitBoss

private command nrKillBoss
   local tX, tY, i
   put sBoss["x"] into tX
   put sBoss["y"] into tY
   put false into sBoss["on"]
   set the visible of button id sId["Boss"] to false
   nrBossBar false
   repeat with i = 0 to 5
      nrFx "laser-hit,smoke2,smoke3,smoke3", 0.08, tX + nrRand(-50, 50), tY + nrRand(-36, 36), 0, 0, i * 0.12
   end repeat
   nrSparks tX, tY, 5
   nrFlashOn "#FFFFFF", 0.16
   nrSound "big-boom", 0.8
   nrBuzz 160
   add 2000 to sScore
   add 3 to sStarsRun
   nrPop "+2,000   +3 STARS", tX, tY, kAmber
   nrSectorClear
end nrKillBoss

private command nrBossBar pShow
   local tW
   set the visible of field "Boss Label" to pShow
   set the visible of graphic "Boss Back" to pShow
   set the visible of graphic "Boss Fill" to pShow and sBoss["hp"] > 0
   if pShow and sBoss["hp"] > 0 then
      put round((item 3 of sBossBar - item 1 of sBossBar) * sBoss["hp"] / sBoss["max"]) into tW
      set the rect of graphic "Boss Fill" to item 1 of sBossBar, item 2 of sBossBar, \
            item 1 of sBossBar + max(1, tW), item 4 of sBossBar
   end if
end nrBossBar

----------------------------------------------------------------------
-- The stars, the explosions, the floating words, the banner, the flash

private command nrMoveStars pDt
   local i, tY, tTop, tBottom, tSpeed
   put item 2 of sPlay - 4 into tTop
   put item 4 of sPlay + 4 into tBottom
   if sMode is "title" then
      put 0.5 into tSpeed
   else
      put sStarSpeed + (sStarTarget - sStarSpeed) * min(1, pDt * 2.5) into sStarSpeed
      put sStarSpeed into tSpeed
   end if
   multiply tSpeed by sU * pDt
   repeat with i = 1 to sCount["Star"]
      put sStar[i]["y"] + sStar[i]["v"] * tSpeed into tY
      if tY > tBottom then
         put tTop into tY
         put nrRand(item 1 of sPlay + 2, item 3 of sPlay - 2) into sStar[i]["x"]
      end if
      put tY into sStar[i]["y"]
      set the loc of graphic id sId["Star"][i] to round(sStar[i]["x"]), round(tY)
   end repeat
end nrMoveStars

-- The stars, anywhere in the column
private command nrScatterStars
   local i, tSize
   repeat with i = 1 to sCount["Star"]
      put nrRand(item 1 of sPlay + 2, item 3 of sPlay - 2) into sStar[i]["x"]
      put nrRand(item 2 of sPlay, item 4 of sPlay) into sStar[i]["y"]
      -- three layers: the nearer, the faster, the bigger
      put 20 + 22 * (i mod 3) + random(10) into sStar[i]["v"]
      if i mod 3 is 2 then
         put 3 into tSize
      else
         put 2 into tSize
      end if
      set the rect of graphic id sId["Star"][i] to 0, 0, tSize, tSize
      set the loc of graphic id sId["Star"][i] to round(sStar[i]["x"]), round(sStar[i]["y"])
   end repeat
   if sStarSpeed is not a number then
      put 1 into sStarSpeed
      put 1 into sStarTarget
   end if
end nrScatterStars

-- An effect: pictures one after another (pFrames, pTime seconds each),
-- moving at pVX,pVY, after pDelay seconds
command nrFx pFrames, pTime, pX, pY, pVX, pVY, pDelay
   local i
   put nrFree("Fx") into i
   if i is 0 then
      exit nrFx
   end if
   put empty into sFx[i]
   put true into sFx[i]["on"]
   put pFrames into sFx[i]["frames"]
   put pTime into sFx[i]["time"]
   put -pDelay into sFx[i]["t"]
   put pX into sFx[i]["x"]
   put pY into sFx[i]["y"]
   put pVX into sFx[i]["vx"]
   put pVY into sFx[i]["vy"]
   put 0 into sFx[i]["shown"]
end nrFx

private command nrBoom pX, pY, pSize
   switch pSize
      case "small"
         nrFx "laser-hit,smoke1,smoke2", 0.06, pX, pY, 0, 0, 0
         nrSparks pX, pY, 2
         nrSound "boom", 0.3
         break
      case "medium"
         nrFx "laser-hit,smoke1,smoke2,smoke3", 0.065, pX, pY, 0, 0, 0
         nrSparks pX, pY, 3
         nrSound "boom", 0.45
         break
      default
         nrFx "laser-hit,smoke2,smoke3,smoke3", 0.075, pX, pY, 0, 0, 0
         nrFx "smoke1,smoke2,smoke3", 0.07, pX - 18, pY + 10, 0, 0, 0.08
         nrFx "smoke1,smoke2,smoke3", 0.07, pX + 16, pY - 12, 0, 0, 0.14
         nrSparks pX, pY, 4
         nrSound "big-boom", 0.6
   end switch
end nrBoom

private command nrSparks pX, pY, pCount
   local tAngle, tSpeed
   repeat pCount times
      put random(360) * pi / 180 into tAngle
      put nrRand(90, 170) into tSpeed
      nrFx "spark1,spark2,spark3", 0.09, pX, pY, cos(tAngle) * tSpeed, sin(tAngle) * tSpeed, 0
   end repeat
end nrSparks

private command nrMoveFx pDt
   local i, tE, tFrame
   repeat with i = 1 to sCount["Fx"]
      if not sFx[i]["on"] then
         next repeat
      end if
      put sFx[i] into tE
      add pDt to tE["t"]
      if tE["t"] < 0 then
         put tE into sFx[i]
         next repeat
      end if
      add tE["vx"] * pDt to tE["x"]
      add tE["vy"] * pDt to tE["y"]
      put trunc(tE["t"] / tE["time"]) + 1 into tFrame
      if tFrame > the number of items of tE["frames"] then
         nrOff "Fx", i
         next repeat
      end if
      if tFrame is not tE["shown"] then
         nrSprite sId["Fx"][i], item tFrame of tE["frames"], tE["x"], tE["y"]
         put tFrame into tE["shown"]
      else if tE["vx"] is not 0 or tE["vy"] is not 0 then
         set the loc of button id sId["Fx"][i] to round(tE["x"]), round(tE["y"])
      end if
      put tE into sFx[i]
   end repeat
   repeat with i = 1 to sCount["Pop"]
      if not sPop[i]["on"] then
         next repeat
      end if
      add pDt to sPop[i]["t"]
      if sPop[i]["t"] > 0.9 then
         nrOff "Pop", i
      else
         subtract 40 * pDt from sPop[i]["y"]
         set the loc of field id sId["Pop"][i] to round(sPop[i]["x"]), round(sPop[i]["y"])
      end if
   end repeat
end nrMoveFx

-- Words that float up from where something happened
command nrPop pText, pX, pY, pColor
   local i, tOldest
   put nrFree("Pop") into i
   if i is 0 then
      -- (all in use: the oldest goes)
      put 1 into i
      repeat with tOldest = 2 to sCount["Pop"]
         if sPop[tOldest]["t"] > sPop[i]["t"] then
            put tOldest into i
         end if
      end repeat
   end if
   put max(item 1 of sPlay + 90, min(item 3 of sPlay - 90, pX)) into pX
   put empty into sPop[i]
   put true into sPop[i]["on"]
   put 0 into sPop[i]["t"]
   put pX into sPop[i]["x"]
   put pY into sPop[i]["y"]
   set the text of field id sId["Pop"][i] to pText
   set the textColor of field id sId["Pop"][i] to pColor
   set the rect of field id sId["Pop"][i] to 0, 0, 180, 22
   set the loc of field id sId["Pop"][i] to round(pX), round(pY)
   set the visible of field id sId["Pop"][i] to true
end nrPop

command nrBanner pText, pSub, pFor, pWarning
   set the text of field "Banner Text" to pText
   set the text of field "Banner Sub" to pSub
   if pWarning then
      set the textColor of field "Banner Text" to kDark
      set the textColor of field "Banner Sub" to kDark
   else
      set the textColor of field "Banner Text" to kInk
      set the textColor of field "Banner Sub" to kAmber
   end if
   set the visible of graphic "Stripe" to pWarning
   set the visible of group "Banner" to true
   put pWarning into sBannerWarn
   put sClock + pFor into sBannerUntil
end nrBanner

private command nrBannerStep
   if sClock >= sBannerUntil then
      set the visible of group "Banner" to false
      put empty into sBannerUntil
   else if sBannerWarn then
      -- a warning blinks
      set the visible of group "Banner" to trunc(sClock * 4) mod 2 is 0
   end if
end nrBannerStep

private command nrFlashOn pColor, pFor
   set the backgroundColor of graphic "Flash" to pColor
   set the visible of graphic "Flash" to true
   put sClock + pFor into sFlashUntil
end nrFlashOn

----------------------------------------------------------------------
-- The sprites

-- A sprite shown with a picture, its middle at pX,pY
private command nrSprite pId, pPicture, pX, pY
   local tW, tH, tL, tT
   put item 1 of sSize[pPicture] into tW
   put item 2 of sSize[pPicture] into tH
   put round(pX - tW / 2) into tL
   put round(pY - tH / 2) into tT
   set the icon of button id pId to sPic[pPicture]
   set the rect of button id pId to tL, tT, tL + tW, tT + tH
   set the visible of button id pId to true
end nrSprite

-- One of a kind put away
private command nrOff pKind, i
   switch pKind
      case "Laser"
         put false into sLaser[i]["on"]
         break
      case "Bolt"
         put false into sBolt[i]["on"]
         break
      case "Rock"
         put false into sRock[i]["on"]
         break
      case "Foe"
         put false into sFoe[i]["on"]
         break
      case "Pod"
         put false into sPod[i]["on"]
         set the visible of graphic id sId["Ring"][i] to false
         break
      case "Power"
         put false into sPower[i]["on"]
         break
      case "Fx"
         put false into sFx[i]["on"]
         break
      case "Pop"
         put false into sPop[i]["on"]
         break
   end switch
   set the visible of control id sId[pKind][i] to false
end nrOff

-- The first of a kind not in use, or 0
private function nrFree pKind
   local tPool, i
   put nrPool(pKind) into tPool
   repeat with i = 1 to sCount[pKind]
      if not tPool[i]["on"] then
         return i
      end if
   end repeat
   return 0
end nrFree

-- How many of a kind are in use
function nrActive pKind
   local tPool, i, tCount
   put nrPool(pKind) into tPool
   put 0 into tCount
   repeat with i = 1 to sCount[pKind]
      if tPool[i]["on"] then
         add 1 to tCount
      end if
   end repeat
   return tCount
end nrActive

private function nrPool pKind
   switch pKind
      case "Laser"
         return sLaser
      case "Bolt"
         return sBolt
      case "Rock"
         return sRock
      case "Foe"
         return sFoe
      case "Pod"
         return sPod
      case "Power"
         return sPower
      case "Fx"
         return sFx
      case "Pop"
         return sPop
   end switch
   return empty
end nrPool

----------------------------------------------------------------------
-- The HUD

private command nrHud
   local tCrew, tW, i
   if sScore is not sHud["score"] then
      set the text of field "Score" to nrCommas(sScore)
      put sScore into sHud["score"]
   end if
   if sStreak is not sHud["streak"] then
      set the text of field "Streak" to "x" & sStreak
      if sStreak >= kMaxStreak then
         set the textColor of field "Streak" to kGood
      else
         set the textColor of field "Streak" to kAmber
      end if
      put sStreak into sHud["streak"]
   end if
   if sSector is not sHud["sector"] then
      set the text of field "Sector" to "SECTOR" && sSector
      put sSector into sHud["sector"]
   end if
   put min(sRescued, nrQuota()) & "/" & nrQuota() into tCrew
   if tCrew is not sHud["crew"] then
      set the text of field "Crew" to tCrew
      put round((item 3 of sBar - item 1 of sBar) * min(1, sRescued / nrQuota())) into tW
      if tW > 0 then
         set the rect of graphic "Bar Fill" to item 1 of sBar, item 2 of sBar, item 1 of sBar + tW, item 4 of sBar
      end if
      set the visible of graphic "Bar Fill" to tW > 0
      put tCrew into sHud["crew"]
   end if
   if sHull is not sHud["hull"] then
      repeat with i = 1 to sCount["Hull"]
         if i <= sHull then
            set the blendLevel of button id sId["Hull"][i] to 0
         else
            set the blendLevel of button id sId["Hull"][i] to 75
         end if
      end repeat
      put sHull into sHud["hull"]
   end if
end nrHud

----------------------------------------------------------------------
-- The tilt

private command nrTiltStart
   local tError
   if not sLibrary then
      return "no library"
   end if
   if sTiltOn then
      return empty
   end if
   try
      mwStartSensor "acceleration"
   catch tError
      return "no sensor"
   end try
   if the result is not empty then
      return the result
   end if
   put true into sTiltOn
   put empty into sTiltSign
   nrTiltZero
   return empty
end nrTiltStart

-- The ship held still where the phone is from its next reading, for a
-- moment (kTiltSettle), and the tilt read along the screen's way up now
-- (a reading from before may have been read along another)
private command nrTiltZero
   put nrScreenAngle() into sTiltAngle
   put empty into sTiltX
   put empty into sTiltY
   put empty into sTiltZero
   put sNow + kTiltSettle into sTiltSettle
end nrTiltZero

-- The window changed: if the screen turned with the phone, the tilt is
-- read along its new way up, from where the phone is now
private command nrTiltTurned
   if sTiltOn and nrScreenAngle() is not sTiltAngle then
      nrTiltZero
   end if
end nrTiltTurned

-- How fast the ship flies (points a second, before sU) for a lean of
-- pLean (in g): not at all inside kTiltDead, then faster with the lean,
-- to kTiltTop at kTiltFull and on
private function nrTiltSpeed pLean
   local tFar
   put (abs(pLean) - kTiltDead) / (kTiltFull - kTiltDead) into tFar
   if tFar <= 0 then
      return 0
   end if
   if pLean < 0 then
      return -kTiltTop * min(1, tFar)
   end if
   return kTiltTop * min(1, tFar)
end nrTiltSpeed

-- Which way up the screen is, from the way the phone is made to be
-- held: 0; 90, the phone turned a quarter to the left (anticlockwise);
-- -90, to the right; 180. A test's (nrTestTilt), else the browser's
-- (an iPhone's window.orientation, which these numbers are, else the
-- Screen Orientation API's angle, 270 for -90); 0 off the web
private function nrScreenAngle
   local tAngle
   if sTestAngle is a number then
      put sTestAngle into tAngle
   else if the platform is "HTML5" then
      try
         do "(function(){if(typeof window.orientation==='number')return window.orientation;" & \
               "var o=screen.orientation;return o&&typeof o.angle==='number'?o.angle:0;})()" as "JavaScript"
         put the result into tAngle
      end try
   end if
   if tAngle is not a number then
      return 0
   end if
   switch round(tAngle)
      case 90
      case -270
         return 90
      case -90
      case 270
         return -90
      case 180
      case -180
         return 180
   end switch
   return 0
end nrScreenAngle

-- A reading, in g: the push that holds the phone up against gravity,
-- along the phone (x across it, y up it, as it is made to be held, z
-- out of the screen). The ship flies along the screen, which the
-- browser turns with the phone: the reading is turned with it
on accelerationChanged pX, pY, pZ
   local tRight, tUp
   if pX is not a number or pY is not a number or pZ is not a number then
      exit accelerationChanged
   end if
   switch sTiltAngle
      case 90
         put -pY into tRight
         put pX into tUp
         break
      case -90
         put pY into tRight
         put -pX into tUp
         break
      case 180
         put -pX into tRight
         put -pY into tUp
         break
      default
         put pX into tRight
         put pY into tUp
   end switch
   -- browsers do not agree which way the push points: the first
   -- reading, with the phone held up or lying flat, says
   if sTiltSign is empty then
      if abs(tUp) > abs(pZ) then
         put tUp into sTiltSign
      else
         put pZ into sTiltSign
      end if
      if sTiltSign < 0 then
         put -1 into sTiltSign
      else
         put 1 into sTiltSign
      end if
   end if
   put tRight into sTiltX
   put tUp into sTiltY
end accelerationChanged

-- The Mobile Web library's word that the phone turned (resizeStack
-- comes too, and may come first)
on orientationChanged
   nrTiltTurned
   pass orientationChanged
end orientationChanged

on trackingError pSensor, pError
   if pSensor is "acceleration" then
      put false into sTiltOn
      put "drag" into sControl
      if sMode is "settings" then
         nrSettingsLook
         nrSettingsNote "The tilt cannot be read:" && pError
      end if
   end if
end trackingError

----------------------------------------------------------------------
-- Layout: every control in its place for the window's size, out of the
-- notch and the home bar

on nrResized
   local tOld, tShift, tKind, i
   set the defaultStack to the short name of me
   put sPlay into tOld
   nrLayout
   nrTiltTurned
   if tOld is empty or sMode is "title" then
      exit nrResized
   end if
   -- a run goes on in the new column: everything moves with it
   put item 1 of sPlay - item 1 of tOld into tShift
   if tShift is not 0 then
      add tShift to sShipX
      repeat with i = 1 to sCount["Laser"]
         add tShift to sLaser[i]["x"]
      end repeat
      repeat with i = 1 to sCount["Bolt"]
         add tShift to sBolt[i]["x"]
      end repeat
      repeat with i = 1 to sCount["Rock"]
         add tShift to sRock[i]["x"]
      end repeat
      repeat with i = 1 to sCount["Foe"]
         add tShift to sFoe[i]["x"]
         -- a weaver's base is the x it weaves about; a ufo's is the y it
         -- bobs about, which a column moved sideways leaves as it was
         if sFoe[i]["kind"] is "weaver" then
            add tShift to sFoe[i]["base"]
         end if
      end repeat
      repeat with i = 1 to sCount["Pod"]
         add tShift to sPod[i]["x"]
         add tShift to sPod[i]["base"]
      end repeat
      repeat with i = 1 to sCount["Power"]
         add tShift to sPower[i]["x"]
      end repeat
      if sBoss["on"] then
         add tShift to sBoss["x"]
      end if
   end if
   put max(item 1 of sShipBounds, min(item 3 of sShipBounds, sShipX)) into sShipX
   put max(item 2 of sShipBounds, min(item 4 of sShipBounds, sShipY)) into sShipY
   lock screen
   nrDrawAll
   unlock screen
   -- a phone turned in the middle of a run: a moment to hold it again;
   -- but not one flown by its tilt, where a lean far enough turns the
   -- screen, and the run goes on (nrTiltTurned has read the tilt along
   -- the new way up). Until 2026-11-11 that paused too
   if sMode is "play" and not (sControl is "tilt" and sTiltOn) then
      if abs((item 3 of tOld - item 1 of tOld) - (item 3 of sPlay - item 1 of sPlay)) > 60 or \
            abs(item 4 of tOld - item 4 of sPlay) > 60 then
         nrPause
      end if
   end if
end nrResized

-- Every thing in play drawn where it is (after the column moved, with
-- the game paused, when no frame will)
private command nrDrawAll
   local i
   repeat with i = 1 to sCount["Laser"]
      if sLaser[i]["on"] then
         set the loc of button id sId["Laser"][i] to round(sLaser[i]["x"]), round(sLaser[i]["y"])
      end if
   end repeat
   repeat with i = 1 to sCount["Bolt"]
      if sBolt[i]["on"] then
         set the loc of button id sId["Bolt"][i] to round(sBolt[i]["x"]), round(sBolt[i]["y"])
      end if
   end repeat
   repeat with i = 1 to sCount["Rock"]
      if sRock[i]["on"] then
         set the loc of button id sId["Rock"][i] to round(sRock[i]["x"]), round(sRock[i]["y"])
      end if
   end repeat
   repeat with i = 1 to sCount["Foe"]
      if sFoe[i]["on"] then
         set the loc of button id sId["Foe"][i] to round(sFoe[i]["x"]), round(sFoe[i]["y"])
      end if
   end repeat
   repeat with i = 1 to sCount["Pod"]
      if sPod[i]["on"] then
         set the loc of button id sId["Pod"][i] to round(sPod[i]["x"]), round(sPod[i]["y"])
         set the loc of graphic id sId["Ring"][i] to round(sPod[i]["x"]), round(sPod[i]["y"])
      end if
   end repeat
   repeat with i = 1 to sCount["Power"]
      if sPower[i]["on"] then
         set the loc of button id sId["Power"][i] to round(sPower[i]["x"]), round(sPower[i]["y"])
      end if
   end repeat
   if sBoss["on"] then
      set the loc of button id sId["Boss"] to round(sBoss["x"]), round(sBoss["y"])
   end if
   if sMode is "play" or sMode is "pause" then
      nrShowShip
      -- the crew's bar in its new place (nrLayoutHud forgot the old)
      nrHud
   end if
end nrDrawAll

-- The part of the screen under a notch, a rounded corner or the home bar:
-- the library's safe-area insets, 0 without it
private function nrInset pSide
   local tView
   if not sLibrary then
      return 0
   end if
   try
      put mwViewport() into tView
   end try
   if tView[pSide] is not a number then
      return 0
   end if
   return max(0, tView[pSide])
end nrInset

command nrLayout
   local tW, tH, tTop, tBottom, tLeft, tRight, tColW, tL, tR
   set the defaultStack to the short name of me
   lock screen
   put the width of me into tW
   put the height of me into tH
   put nrInset("top") into tTop
   put nrInset("bottom") into tBottom
   put nrInset("left") into tLeft
   put nrInset("right") into tRight
   -- the column: the whole width of a phone held upright; in a wider
   -- window, a portrait column in the middle
   if tW >= tH * 0.8 then
      put min(tW, max(300, min(520, round(tH * 0.72)))) into tColW
   else
      put tW into tColW
   end if
   put (tW - tColW) div 2 into tL
   put tL + tColW into tR
   put tL, 0, tR, tH into sPlay
   put max(0.5, min(1.35, tH / 760)) into sU
   put tL >= 150 into sSideHud
   if tL > 0 then
      set the rect of graphic "Dim Left" to 0, 0, tL, tH
      set the rect of graphic "Dim Right" to tR, 0, tW, tH
      set the points of graphic "Edge Left" to tL & comma & 0 & return & tL & comma & tH
      set the points of graphic "Edge Right" to tR & comma & 0 & return & tR & comma & tH
      -- the covers, up to the edges' lines, which stay in sight (each
      -- line is drawn over the pixels from x - 1 to x + 1 of its x)
      set the rect of graphic "Clip Left" to 0, 0, max(0, tL - 1), tH
      set the rect of graphic "Clip Right" to min(tW, tR + 2), 0, tW, tH
   end if
   repeat for each item tL in "Dim Left,Dim Right,Edge Left,Edge Right"
      set the visible of graphic tL to item 1 of sPlay > 0
   end repeat
   nrShowClip
   put item 1 of sPlay into tL
   nrLayoutHud tW, tH, tTop, tLeft, tRight
   -- where the ship may go: in the column, under the HUD, over the home bar
   put tL + 30, sHudBottom + 60, tR - 30, tH - tBottom - 36 into sShipBounds
   nrLayoutBanner
   set the rect of graphic "Shade" to 0, 0, tW, tH
   set the rect of graphic "Flash" to tL, 0, tR, tH
   nrLayoutTitle tW, tH, tTop, tBottom
   nrLayoutPanels tW, tH, tTop, tBottom
   nrScatterStars
   unlock screen
end nrLayout

-- The HUD: over the top of the column, or at its sides when they are
-- wide enough
private command nrLayoutHud pW, pH, pTop, pLeft, pRight
   local tL, tR, tT, tX, tRightX, tPause, i, tY, tWidth
   put item 1 of sPlay into tL
   put item 3 of sPlay into tR
   put pTop + 12 into tT
   if sSideHud then
      put max(18, pLeft + 18) into tX
      put tL - 18 into tWidth
      put pW - max(18, pRight + 18) into tRightX
      set the rect of field "Score" to tX, tT, tWidth, tT + 30
      set the rect of field "Sector" to tX, tT + 40, tWidth, tT + 56
      put tX, tT + 61, tX + min(110, tWidth - tX - 50), tT + 67 into sBar
      set the rect of field "Crew" to item 3 of sBar + 8, tT + 56, tWidth, tT + 72
      set the textAlign of field "Streak" to "left"
      set the textAlign of field "Streak Label" to "left"
      set the rect of field "Streak Label" to tX, tT + 80, tWidth, tT + 98
      set the rect of field "Streak" to tX, tT + 98, tWidth, tT + 124
      put tRightX - 44, tT, tRightX, tT + 44 into tPause
      put tRightX - 3 * 26 + 4 into tY
      repeat with i = 1 to sCount["Hull"]
         set the rect of button id sId["Hull"][i] to tY + (i - 1) * 26, tT + 56, tY + (i - 1) * 26 + 22, tT + 73
      end repeat
      put pTop + 8 into sHudBottom
   else
      put tL + max(14, pLeft + 10) into tX
      put tR - max(14, pRight + 10) into tRightX
      set the rect of field "Score" to tX, tT - 2, tX + 190, tT + 28
      set the rect of field "Sector" to tX, tT + 32, tX + 110, tT + 46
      put tX, tT + 51, tX + 96, tT + 57 into sBar
      set the rect of field "Crew" to tX + 104, tT + 46, tX + 160, tT + 62
      put tRightX - 42, tT, tRightX, tT + 42 into tPause
      set the textAlign of field "Streak" to "right"
      set the textAlign of field "Streak Label" to "right"
      set the rect of field "Streak" to tRightX - 42 - 100, tT + 2, tRightX - 52, tT + 26
      -- (taller than its letters: a field cuts off what reaches its
      -- bottom, and a browser's font sits lower than a desktop's)
      set the rect of field "Streak Label" to tRightX - 42 - 100, tT + 26, tRightX - 52, tT + 44
      put tRightX - 3 * 26 + 4 into tY
      repeat with i = 1 to sCount["Hull"]
         set the rect of button id sId["Hull"][i] to tY + (i - 1) * 26, tT + 50, tY + (i - 1) * 26 + 22, tT + 67
      end repeat
      put tT + 68 into sHudBottom
   end if
   set the rect of graphic "Bar Back" to sBar
   -- (drawn again, for its new place, by nrHud)
   put empty into sHud["crew"]
   nrPlaceButton "Pause", tPause
   set the rect of graphic "Pause Bar 1" to item 1 of tPause + 15, item 2 of tPause + 13, \
         item 1 of tPause + 20, item 4 of tPause - 13
   set the rect of graphic "Pause Bar 2" to item 3 of tPause - 20, item 2 of tPause + 13, \
         item 3 of tPause - 15, item 4 of tPause - 13
   -- the mothership's health, under the HUD
   set the rect of field "Boss Label" to tL + 40, sHudBottom + 6, tR - 40, sHudBottom + 20
   put tL + 50, sHudBottom + 24, tR - 50, sHudBottom + 31 into sBossBar
   set the rect of graphic "Boss Back" to sBossBar
   if sBoss["on"] then
      nrBossBar true
   end if
end nrLayoutHud

private command nrLayoutBanner
   local tL, tR, tY
   put item 1 of sPlay into tL
   put item 3 of sPlay into tR
   put round(item 4 of sPlay * 0.36) into tY
   set the rect of graphic "Stripe" to tL, tY - 34, tR, tY + 46
   set the rect of field "Banner Text" to tL + 8, tY - 22, tR - 8, tY + 14
   set the rect of field "Banner Sub" to tL + 8, tY + 16, tR - 8, tY + 36
end nrLayoutBanner

-- The title: the name, the ship rising and falling, and the buttons; on
-- a phone on its side, the name on the left and the buttons on the right
private command nrLayoutTitle pW, pH, pTop, pBottom
   local tCX, tY, tBW, tBottom, tSide, tTag
   put pH - pBottom - 22 into tBottom
   put pW >= pH * 1.3 and pH < 620 into tSide
   if tSide then
      put round(pW * 0.3) into tCX
      put pTop + max(16, round((pH - pTop - pBottom - 250) / 2)) into tY
   else
      put (item 1 of sPlay + item 3 of sPlay) div 2 into tCX
      put pTop + round((pH - pTop - pBottom) * 0.08) into tY
   end if
   set the loc of button "Logo Nova" to tCX, tY + 32
   set the rect of field "Logo Rescue" to tCX - 180, tY + 64, tCX + 180, tY + 96
   set the points of graphic "Logo Line" to (tCX - 84) & comma & (tY + 106) & return & (tCX + 84) & comma & (tY + 106)
   put min(320, (item 3 of sPlay - item 1 of sPlay) - 40) into tTag
   if tSide then
      put min(320, round(pW * 0.5) - 40) into tTag
   end if
   set the width of field "Tagline" to tTag
   set the rect of field "Tagline" to tCX - tTag div 2, tY + 118, tCX - tTag div 2 + tTag, \
         tY + 118 + the formattedHeight of field "Tagline"
   if tSide then
      -- the buttons on the right half, in the middle of the height
      put round(pW * 0.72) into tCX
      put min(300, round(pW * 0.4)) into tBW
      put pTop + round((pH - pTop - pBottom - 214) / 2) into tY
      nrPlaceButton "Play", tCX - tBW div 2, tY, tCX + tBW div 2, tY + 58
      nrPlaceButton "Howto Open", tCX - tBW div 2, tY + 70, tCX + tBW div 2, tY + 116
      nrPlaceButton "Settings Open", tCX - tBW div 2, tY + 126, tCX + tBW div 2, tY + 172
      set the rect of field "Records" to tCX - 180, tY + 188, tCX + 180, tY + 206
      put round(pW * 0.3), the bottom of field "Tagline" + 50 into sAttract
   else
      put min(290, (item 3 of sPlay - item 1 of sPlay) - 60) into tBW
      set the rect of field "Records" to tCX - 180, tBottom - 18, tCX + 180, tBottom
      nrPlaceButton "Settings Open", tCX - tBW div 2, tBottom - 76, tCX + tBW div 2, tBottom - 30
      nrPlaceButton "Howto Open", tCX - tBW div 2, tBottom - 132, tCX + tBW div 2, tBottom - 86
      nrPlaceButton "Play", tCX - tBW div 2, tBottom - 204, tCX + tBW div 2, tBottom - 144
      put tCX, round((the bottom of field "Tagline" + tBottom - 204) / 2) into sAttract
   end if
   if sMode is "title" then
      put item 1 of sAttract into sShipX
      put item 2 of sAttract into sShipY
      nrAttract
   end if
end nrLayoutTitle

-- The panels, in the middle of the window
private command nrLayoutPanels pW, pH, pTop, pBottom
   local tCX, tPW, tL, tR, tY, tT, tTall, tCompact, tBH, i, tName, tGap, tCredits
   put pW div 2 into tCX
   put min(pW - 32, 360) into tPW
   put tCX - tPW div 2 into tL
   put tL + tPW into tR
   put pH - pTop - pBottom - 24 into tTall
   put tTall < 480 into tCompact
   if tCompact then
      put 42 into tBH
      put 10 into tGap
   else
      put 50 into tBH
      put 12 into tGap
   end if

   -- Paused: the word and four buttons
   put pTop + 12 + max(0, (tTall - (82 + 4 * tBH + 3 * tGap + 26)) div 2) into tT
   set the rect of field "Paused Title" to tL + 20, tT + 22, tR - 20, tT + 54
   put tT + 74 into tY
   repeat for each item tName in "Resume,Restart,Pause Settings,Pause Home"
      nrPlaceButton tName, tL + 28, tY, tR - 28, tY + tBH
      add tBH + tGap to tY
   end repeat
   nrPlacePanel "Paused", tL, tT, tR, tY - tGap + 26

   -- Over: what the run was worth, and two buttons
   put pTop + 12 + max(0, (tTall - (196 + 2 * tBH + tGap + 26)) div 2) into tT
   set the rect of field "Over Title" to tL + 20, tT + 20, tR - 20, tT + 48
   set the rect of field "Final" to tL + 10, tT + 54, tR - 10, tT + 104
   set the rect of field "Best Note" to tL + 20, tT + 108, tR - 20, tT + 128
   set the rect of field "Stats" to tL + 16, tT + 138, tR - 16, tT + 176
   put tT + 196 into tY
   nrPlaceButton "Again", tL + 28, tY, tR - 28, tY + tBH + 6
   add tBH + 6 + tGap to tY
   nrPlaceButton "Over Home", tL + 28, tY, tR - 28, tY + tBH
   add tBH to tY
   nrPlacePanel "Over", tL, tT, tR, tY + 26

   -- Settings: four switches, a note, who made the pictures, and Back
   set the visible of button "Full" to sLibrary and the platform is "HTML5"
   set the visible of graphic "Full Shape" to the visible of button "Full"
   set the visible of field "Credits" to not tCompact
   put 0 into tCredits
   if not tCompact then
      put 56 into tCredits
   end if
   put pTop + 12 + max(0, (tTall - (70 + 4 * (tBH - 4) + 3 * tGap + 30 + tCredits + tBH + 40)) div 2) into tT
   set the rect of field "Settings Title" to tL + 20, tT + 20, tR - 20, tT + 48
   put tT + 66 into tY
   repeat for each item tName in "Sound,Buzz,Controls,Full"
      if the visible of button tName then
         nrPlaceButton tName, tL + 28, tY, tR - 28, tY + tBH - 4
         add tBH - 4 + tGap to tY
      end if
   end repeat
   set the width of field "Settings Note" to tR - tL - 48
   set the rect of field "Settings Note" to tL + 24, tY, tR - 24, tY + 34
   add 38 to tY
   if not tCompact then
      set the width of field "Credits" to tR - tL - 48
      set the rect of field "Credits" to tL + 24, tY, tR - 24, tY + the formattedHeight of field "Credits"
      add the formattedHeight of field "Credits" + 16 to tY
   end if
   nrPlaceButton "Settings Back", tL + 28, tY, tR - 28, tY + tBH
   add tBH to tY
   nrPlacePanel "Settings", tL, tT, tR, tY + 26

   nrLayoutHowto pW, pH, pTop, pBottom
end nrLayoutPanels

-- How to play: four rows, a picture and its words; in two columns on a
-- wide, short screen
private command nrLayoutHowto pW, pH, pTop, pBottom
   local tCX, tPW, tL, tR, tT, tY, i, tTwo, tColL, tColW, tTextL, tRowH, tTall, tTop2, tBottom, tSize
   put pH - pTop - pBottom - 24 into tTall
   put pW >= 600 and tTall < 560 into tTwo
   put pW div 2 into tCX
   if tTwo then
      put min(pW - 32, 700) into tPW
   else
      put min(pW - 32, 380) into tPW
   end if
   put tCX - tPW div 2 into tL
   put tL + tPW into tR
   -- the words a size smaller if the rows would not fit
   repeat for each item tSize in "14,13,12"
      repeat with i = 1 to 4
         set the textSize of field ("Howto Text" && i) to tSize
      end repeat
      put nrHowtoRows(tL, tR, 0, tTwo) into tBottom
      if tBottom + 40 + 56 + 50 <= tTall then
         exit repeat
      end if
   end repeat
   put pTop + 12 + max(0, (tTall - (tBottom + 40 + 56 + 50)) div 2) into tT
   set the rect of field "Howto Title" to tL + 20, tT + 20, tR - 20, tT + 46
   put nrHowtoRows(tL, tR, tT + 62, tTwo) into tY
   nrPlaceButton "Howto Go", tCX - 120, tY + 12, tCX + 120, tY + 68
   nrPlacePanel "Howto", tL, tT, tR, tY + 92
end nrLayoutHowto

-- The rows of How to play from pTop; returns where they end
private function nrHowtoRows pL, pR, pTop, pTwo
   local i, tColL, tColR, tY, tTextL, tBottom, tStartY
   put pTop into tY
   put pTop into tStartY
   put pTop into tBottom
   repeat with i = 1 to 4
      if pTwo then
         if i mod 2 is 1 then
            put pL + 20 into tColL
            put (pL + pR) div 2 - 10 into tColR
            if i is 3 then
               put tBottom + 14 into tY
               put tY into tStartY
            end if
         else
            put (pL + pR) div 2 + 10 into tColL
            put pR - 20 into tColR
            put tStartY into tY
         end if
      else
         put pL + 20 into tColL
         put pR - 20 into tColR
      end if
      put tColL + 58 into tTextL
      set the loc of button ("Howto Icon" && i) to tColL + 26, tY + 26
      set the rect of field ("Howto Head" && i) to tTextL, tY, tColR, tY + 16
      set the width of field ("Howto Text" && i) to tColR - tTextL
      set the rect of field ("Howto Text" && i) to tTextL, tY + 20, tColR, \
            tY + 20 + the formattedHeight of field ("Howto Text" && i)
      put max(tBottom, max(tY + 52, the bottom of field ("Howto Text" && i))) into tBottom
      put tBottom + 14 into tY
   end repeat
   return tBottom
end nrHowtoRows

-- A button's shape for its place: two corners cut. The place is
-- left, top, right, bottom, or one rect
private command nrPlaceButton pName, pL, pT, pR, pB
   local tCut, tRect
   if pT is empty then
      put pL into tRect
   else
      put pL, pT, pR, pB into tRect
   end if
   put min(12, (item 4 of tRect - item 2 of tRect) div 4) into tCut
   set the rect of button pName to tRect
   set the points of graphic (pName && "Shape") to nrCutPoints(tRect, tCut)
end nrPlaceButton

-- A panel's glass, and its brackets at the two corners not cut
private command nrPlacePanel pName, pL, pT, pR, pB
   set the points of graphic (pName && "Glass") to nrCutPoints((pL, pT, pR, pB), 18)
   set the points of graphic (pName && "Trim") to (pR - 40) & comma & (pT - 5) & return & (pR + 5) & comma & (pT - 5) & return & \
         (pR + 5) & comma & (pT + 40) & return & return & (pL + 40) & comma & (pB + 5) & return & \
         (pL - 5) & comma & (pB + 5) & return & (pL - 5) & comma & (pB - 40)
end nrPlacePanel

private function nrCutPoints pRect, pCut
   local tL, tT, tR, tB
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   put item 4 of pRect into tB
   return (tL + pCut) & comma & tT & return & tR & comma & tT & return & \
         tR & comma & (tB - pCut) & return & (tR - pCut) & comma & tB & return & \
         tL & comma & tB & return & tL & comma & (tT + pCut) & return & (tL + pCut) & comma & tT
end nrCutPoints

----------------------------------------------------------------------
-- For the tests: the clock in the test's hands

-- No loop, no sound, no buzz, a fixed seed, and the saved things in
-- pSaveFile
command nrTestBegin pSeed, pSaveFile
   set the defaultStack to the short name of me
   put true into sManual
   nrStopLoop
   if pSeed is a number then
      set the randomSeed to pSeed
   end if
   put pSaveFile into sSaveFile
   nrLoad
   put false into sSound
   put false into sBuzz
   put false into sNoSpawn
end nrTestBegin

-- The game, pSeconds on, a sixtieth of a second at a time
command nrTestStep pSeconds
   set the defaultStack to the short name of me
   lock screen
   repeat while pSeconds > 0.0001
      nrAdvance min(pSeconds, 1/60)
      subtract 1/60 from pSeconds
   end repeat
   unlock screen
end nrTestStep

-- Whether new things come by themselves
command nrTestSpawning pOn
   put pOn is not true into sNoSpawn
end nrTestSpawning

-- A thing where a test wants it: pod, big, med, small, scout, weaver,
-- gunship, ufo, twin, shield, repair, star, bolt; things that fall do so
-- at pSpeed points a second (0 if empty)
command nrTestPut pKind, pX, pY, pSpeed
   set the defaultStack to the short name of me
   if pSpeed is empty then
      put 0 into pSpeed
   end if
   switch pKind
      case "pod"
         nrSpawnPod pX, pY, pSpeed
         break
      case "big"
      case "med"
      case "small"
         nrSpawnRock pKind, pX, pY, 0, pSpeed
         break
      case "scout"
      case "weaver"
      case "gunship"
      case "ufo"
         nrSpawnFoe pKind, pX, pY
         break
      case "twin"
      case "shield"
      case "repair"
      case "star"
         nrSpawnPower pKind, pX, pY
         break
      case "bolt"
         nrEnemyShot pX, pY, 0, pSpeed, "bolt"
         break
   end switch
end nrTestPut

-- The tilt on, without a sensor (the test sends accelerationChanged
-- itself), and the screen pAngle degrees from upright (nrScreenAngle;
-- nrTestSet "angle" turns it later)
command nrTestTilt pAngle
   set the defaultStack to the short name of me
   put pAngle into sTestAngle
   put "tilt" into sControl
   put true into sTiltOn
   put empty into sTiltSign
   nrTiltZero
end nrTestTilt

-- The ship where a test wants it
command nrTestShip pX, pY
   put pX into sShipX
   put pY into sShipY
end nrTestShip

-- A number of the run: sector, hull, streak, rescued, score, bosshp;
-- or angle, the screen's for the tilt (nrTestTilt)
command nrTestSet pName, pValue
   switch pName
      case "angle"
         put pValue into sTestAngle
         break
      case "sector"
         put pValue into sSector
         break
      case "hull"
         put pValue into sHull
         nrShipLook
         break
      case "streak"
         put pValue into sStreak
         break
      case "rescued"
         put pValue into sRescued
         break
      case "score"
         put pValue into sScore
         break
      case "bosshp"
         put pValue into sBoss["hp"]
         break
   end switch
end nrTestSet

-- How things are, a line each: name:value. One of the stack's
-- cJavascriptHandlers, so a page can ask it too (the check of the game's
-- page on the web site, tools/pages/check_nova_rescue_page.py)
function nrState
   local tOut, tKind
   put "mode:" & sMode & return & "score:" & sScore & return & "streak:" & sStreak & return & \
         "sector:" & sSector & return & "rescued:" & sRescued & return & "quota:" & nrQuota() & return & \
         "hull:" & sHull & return & "phase:" & sPhase & return & "now:" & sNow & return & \
         "shipx:" & round(sShipX) & return & "shipy:" & round(sShipY) & return & \
         "safe:" & (sNow < sSafeUntil) & return & "twin:" & (sNow < sTwinUntil) & return & \
         "shield:" & (sNow < sShieldUntil) & return & "best:" & sBest & return & "stars:" & sStars & return & \
         "starsrun:" & sStarsRun & return & "lost:" & sLostRun & return & "saved:" & sRescuedRun & return & \
         "boss:" & sBoss["on"] & return & "bosshp:" & sBoss["hp"] & return & \
         "bossx:" & round(sBoss["x"]) & return & "bossy:" & round(sBoss["y"]) & return & "fps:" & sFps & return & \
         "column:" & sPlay & return & "bounds:" & sShipBounds & return & "sound:" & sSound & return & \
         "control:" & sControl & return & "howto:" & sSeenHowto & return & "library:" & sLibrary & return & \
         "audio:" & sAudio & return & "font:" & sFontLoaded & return & "work:" & round(sWork, 2) & return & "draw:" & round(sDraw, 2) into tOut
   repeat for each item tKind in "Laser,Bolt,Rock,Foe,Pod,Power,Fx,Pop"
      put return & toLower(tKind) & "s:" & nrActive(tKind) after tOut
   end repeat
   return tOut
end nrState
