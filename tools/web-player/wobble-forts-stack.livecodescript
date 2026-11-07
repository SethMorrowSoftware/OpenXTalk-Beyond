script "Wobble Forts"
-- Wobble Forts: a physics game for a phone or a window, made with
-- OXT-Beyond, Box2D (through the xTalk Suite's Box2Dxt) and the Mobile
-- Web library. Built by tools/web-player/wobble-forts.livecodescript in
-- OXT-Beyond's repository, from this script and wobble-forts/levels.txt;
-- its pictures, sounds and font are Kenney's (kenney.nl), CC0.
--
-- The Bloops, round and cheerful, are flung from a launcher at the
-- wobbly forts of the Grumps, square and sulking. Pull a Bloop back,
-- aim along the dots and let go: the blocks are real bodies of Box2D,
-- so a fort leans, slides and tumbles as wood, glass, stone and metal
-- would. A block that is hit hard enough chips, cracks and breaks; a
-- crate of TNT goes off. A level is cleared when every Grump is popped,
-- with one to three stars for the Bloops left over. Fifteen levels in
-- three lands; no clock, one shot at a time.
--
-- How it is made:
--   one card, "Fort": the world (sky, hills, ground, the launcher and the
--     pieces) fills the window, drawn at a scale that fits the level's
--     1600 x 900 units in it (sV), its ground at the bottom; every
--     screen (Title, Map, Howto, Paused, Clear, Fail, Notice) is a group
--     over it
--   units: a block is 70 units across, and 70 units are a metre of the
--     physics (kM); the world's y grows downwards, as the card's does,
--     and Box2D's gravity points that way
--   one loop: wfFrame, sent again after every frame, steps the physics
--     by fixed steps of 1/60 of a second (at most kMaxSteps a frame, so
--     a slow phone plays a little slower, never jumps), then draws the
--     bodies that moved (b2BodiesUpdate: one call for all of them) and
--     the puffs
--   sprites: a fixed set of images, each given a picture of the "Art"
--     card (its text) when it is used, then turned (its angle) and fitted
--     to a rect (lockLoc): never created while the game plays
--   damage: Box2D's hit events (b2ContactHitSpeed), each taking from the
--     two pieces it touched as much as it was fast, more for the lighter
--     one; a piece shows its chipped and cracked pictures as it weakens
--   messages from a finger: the browser makes the first finger the mouse,
--     so a pull is mouseDown, the mouseLoc every frame, and mouseUp
--
-- For the tests (tests/lcs/webplayer/wobble-forts.livecodescript), the
-- clock can be taken out of the loop's hands: wfTestBegin stops the loop
-- and fixes the random seed, wfTestStep moves the game on by so many
-- seconds, wfTestShoot launches a Bloop as a finger would, wfState says
-- how things are.

constant kFont = "Kenney Future Narrow"
constant kInk = "#3B2410"
constant kEdge = "#6B4423"
constant kWhite = "#FFFFFF"
constant kGold = "#FFCC33"
constant kSaveName = "wobble-forts.txt"
-- the world: units to a metre, its size, the ground's top, the launcher
-- (where a Bloop sits in it) and the farthest a finger pulls it
constant kM = 70
constant kWorldW = 1600
constant kWorldH = 900
constant kGroundY = 790
constant kAnchorX = 290
constant kAnchorY = 600
constant kPull = 130
-- the physics: gravity (m/s/s), the fastest launch (m/s), the step, the
-- most steps a frame, the Bloop's radius (m), and how long a shot may go
-- on before the game calls it settled
constant kGravity = 10
constant kLaunchSpeed = 16
constant kStep = 0.0166667
constant kMaxSteps = 3
constant kBloopRadius = 0.48
constant kShotMax = 14
-- the lands: their names, skies and ground
constant kLands = "MEADOW,DUNES,SHROOM HOLLOW"
constant kSkies = "sky-meadow,sky-dunes,sky-shroom"
constant kGrounds = "ground-grass,ground-sand,ground-dirt"
constant kDecos = "bush,cactus,rock"
constant kLevelsPerLand = 5

-- whether the Mobile Web library is there; whether Box2D is; the screen
-- showing (title, map, howto, aim, fly, pause, clear, fail, notice);
-- what How to play goes back to; the loop's next message; whether a
-- test holds the clock; the time of the last frame, in milliseconds
local sLibrary, sPhysics, sMode, sHowtoThen, sLoop, sManual, sLast
-- the frames shown in the last second, and since when; how long a
-- frame's script took (the physics, and the drawing), in milliseconds
local sFps, sFrames, sFpsFrom, sWork, sDraw, sStepMs
-- sClock runs in every screen; sNow while a level plays
local sClock, sNow
-- the world on the screen: its scale (points a unit), where its 0,0 is,
-- the size of the HUD and its buttons (sU), and the window's insets
local sV, sOX, sOY, sU, sInsetT, sInsetL, sInsetR, sInsetB
-- the controls' ids (sId["Piece"][3]) and how many of each pool; the
-- pictures: sPic[name] is an image of card "Art", sSize[name] its size
local sId, sCount, sSize
-- the levels: sLevels[n]["name"], ["land"], ["bloops"], ["hint"],
-- ["pieces"]; how many
local sLevels, sLevelCount
-- the level playing: its number, its Bloops still to come, its score,
-- the Grumps left, the shot (its time, its last hit, the Bloop flying
-- and whether its trick was used), the pieces that broke this shot
local sLevel, sQueue, sScore, sGrumps, sShotT, sLastHit, sFlyer, sTrickUsed, sShots
-- the Box2D world, and each piece: sP*[i] its kind (block, grump, boss,
-- bloop), material, shape, width and height (units), health and full
-- health, body, the sprite it is drawn by, where it is (units) and its
-- angle (radians); sBodyPiece[body] the piece of a body
local sWorld, sPN, sPKind, sPMat, sPShape, sPW, sPH, sPHP, sPMax, sPBody, sPSprite, sPX, sPY, sPA, sPAlive, sPLook, sPColor
local sBodyPiece, sPFree
-- what a sprite shows and how it was last drawn: its picture, angle and
-- rect, so that nothing is set that did not change
local sSprPic, sSprAngle, sSprRect
-- the pieces to break and the bangs to set off after the hits of a step
local sBreak, sBangs
-- the aim: whether a finger pulls, where it went down, the pull (units)
local sAiming, sAimFrom, sPullX, sPullY
-- the puffs, debris and sparkles: sFx[i]["on"], ...; the floating scores
local sFx, sPop, sPopNext
-- the trail of the last shot: its dots' places, and when the next is due
local sTrail, sTrailCount, sTrailAt
-- the clear screen: when it opened, the stars, the Bloops left to count
local sClearAt, sClearStars, sClearSpare, sClearShown, sEndAt, sEndKind
-- the map's land; the shake of a bang; the flash
local sMapLand, sShakeUntil, sFlashUntil
-- kept between visits: each level's stars and best score, the settings,
-- whether How to play was seen
local sStars, sBest, sSound, sSeenHowto
-- another file for them (the tests'), and how the sounds play: "web"
-- (the browser's Web Audio, many at once), "desktop" (the engine's play,
-- one at a time) or "none"
local sSaveFile, sAudio, sAudioDir, sFontLoaded
-- the HUD as shown, so that it is changed only when it changes
local sHud
-- more of the level: the ground's body, each piece's shape, mass and
-- place after it settled; the pieces moved this frame; the Bloops in the
-- air and their speed before a step; the Bloop waiting in the launcher,
-- and when it hopped in; when the hint goes; whether the screen is kept on
local sGroundBody, sPShapeId, sPMass, sPStart, sDirty, sFlyers, sFlyVX, sFlyVY, sPunch
local sLoaded, sLoadAt, sHintUntil, sAwake, sWeb, sArtId, sSprOn, sSoundBudget, sPauseFrom, sClearBase, sClearNew

----------------------------------------------------------------------
-- Opening and closing

on preOpenStack
   wfInit
end preOpenStack

on closeStack
   wfStopLoop
   put "closed" into sMode
   wfFreeWorld
   if sLibrary then
      try
         if mwIsWeb() then
            mwKeepAwake false
         end if
         mwStop
      end try
   end if
end closeStack

on resizeStack
   wfResized
   pass resizeStack
end resizeStack

command wfInit
   local tError
   set the defaultStack to the short name of me
   put false into sManual
   put empty into sLoop
   put empty into sSaveFile
   put 0 into sWorld
   put 0 into sClock
   put 0 into sNow
   put 0 into sFps
   put 0 into sWork
   put 0 into sDraw
   put 0 into sStepMs
   put 0 into sFrames
   put 0 into sShakeUntil
   put empty into sFlashUntil
   put 1 into sMapLand
   put the milliseconds into sFpsFrom
   wfFindControls
   wfLoadFont
   wfReadLevels
   wfLoad
   -- the library is in OXT-Beyond 0.2.7 and later; without it the game
   -- is a window that plays with the mouse
   put true into sLibrary
   try
      mwStart the short name of me, "none"
   catch tError
      put false into sLibrary
   end try
   put false into sWeb
   if sLibrary then
      try
         put mwIsWeb() is true into sWeb
      end try
   end if
   put wfHasBox2D() into sPhysics
   wfAudioStart
   wfWatchPage
   wfLayout
   if sPhysics then
      wfGoTitle
   else
      wfShowNotice
   end if
end wfInit

-- True when Box2Dxt answers: built into the web engine; on a desktop,
-- an extension that may not be loaded
function wfHasBox2D
   local tVersion
   try
      put b2Version() into tVersion
   catch tVersion
      return false
   end try
   return tVersion is a number and tVersion >= 4
end wfHasBox2D

-- The ids of the controls and the sizes of the pictures, once: the loop
-- asks for a control by its id, which is quicker than by its name
private command wfFindControls
   local tKind, i, tImage
   put empty into sId
   put empty into sCount
   repeat for each item tKind in "Piece,Fx,Pop,Aim,Trail,Ground,Deco,Queue"
      put 0 into i
      repeat while there is a control (tKind && (i + 1)) of card "Fort" of me
         add 1 to i
         put the id of control (tKind && i) of card "Fort" of me into sId[tKind][i]
      end repeat
      put i into sCount[tKind]
   end repeat
   repeat for each item tKind in "Sky,Post,Fork,Loaded,Band Back,Band Front,Dirt,Flash"
      put the id of control tKind of card "Fort" of me into sId[tKind]
   end repeat
   put empty into sSize
   repeat with i = 1 to the number of images of card "Art" of me
      put the long id of image i of card "Art" of me into tImage
      put the cSize of tImage into sSize[the short name of tImage]
   put the id of tImage into sArtId[the short name of tImage]
   end repeat
   put empty into sSprPic
   put empty into sSprAngle
   put empty into sSprRect
   put empty into sSprOn
end wfFindControls

-- Kenney Future Narrow, from the stack (without it, the stack's own font)
private command wfLoadFont
   local tData, tFile
   if sFontLoaded is true or kFont is among the lines of the fontNames then
      exit wfLoadFont
   end if
   put the cFont of me into tData
   if tData is empty then
      exit wfLoadFont
   end if
   put specialFolderPath("temporary") & "/wobble-forts-kenney-future-narrow.ttf" into tFile
   try
      put tData into url ("binfile:" & tFile)
      start using font file tFile
      put the result is empty into sFontLoaded
   end try
end wfLoadFont

----------------------------------------------------------------------
-- The levels: wobble-forts/levels.txt, kept in the stack as cLevels.
-- A level is a block of lines:
--   level <name>
--   land <1 to 3>
--   bloops <colour> <colour> ...      (yellow, blue, pink, green, beige)
--   hint <words shown as it opens>    (optional)
--   <kind> <x> <bottom> [<angle>]     (one line a piece)
--   end
-- A piece's kind is <material>-<shape> (wood, glass, stone, metal, tnt;
-- cube, plank, beam, post, pillar, slab, ball), grump-<colour> or
-- boss-<colour>; x is its middle and bottom how high its lowest edge is
-- above the ground, in units; angle (degrees) turns it about its middle.

command wfReadLevels
   local tLine, tWord, n
   put empty into sLevels
   put 0 into n
   repeat for each line tLine in the cLevels of me
      put word 1 to -1 of tLine into tLine
      if tLine is empty or char 1 of tLine is "#" then
         next repeat
      end if
      put word 1 of tLine into tWord
      switch tWord
         case "level"
            add 1 to n
            put word 2 to -1 of tLine into sLevels[n]["name"]
            put 1 into sLevels[n]["land"]
            put empty into sLevels[n]["pieces"]
            put empty into sLevels[n]["hint"]
            break
         case "land"
            put word 2 of tLine into sLevels[n]["land"]
            break
         case "bloops"
            put word 2 to -1 of tLine into sLevels[n]["bloops"]
            break
         case "hint"
            put word 2 to -1 of tLine into sLevels[n]["hint"]
            break
         case "end"
            break
         default
            if n > 0 then
               put tLine & return after sLevels[n]["pieces"]
            end if
      end switch
   end repeat
   put n into sLevelCount
end wfReadLevels

----------------------------------------------------------------------
-- Kept between visits. In a browser, the documents folder is the page's
-- own storage, kept between visits; on a desktop, a folder for this game.

private function wfSavePath
   local tFolder
   if sSaveFile is not empty then
      return sSaveFile
   end if
   if the platform is "HTML5" then
      put specialFolderPath("documents") into tFolder
   else
      put specialFolderPath("temporary") & "/oxt-wobble-forts" into tFolder
   end if
   if there is not a folder tFolder then
      create folder tFolder
   end if
   return tFolder & "/" & kSaveName
end wfSavePath

command wfLoad
   local tText, tLine, tKey, tValue, n
   put empty into sStars
   put empty into sBest
   put true into sSound
   put false into sSeenHowto
   try
      put url ("file:" & wfSavePath()) into tText
   end try
   set the itemDelimiter to "="
   repeat for each line tLine in tText
      put item 1 of tLine into tKey
      put item 2 of tLine into tValue
      if tKey begins with "level" then
         put char 6 to -1 of tKey into n
         set the itemDelimiter to comma
         if n is an integer and n >= 1 and n <= sLevelCount and \
               item 1 of tValue is an integer and item 1 of tValue >= 0 and item 1 of tValue <= 3 and \
               item 2 of tValue is an integer and item 2 of tValue >= 0 then
            put item 1 of tValue into sStars[n]
            put item 2 of tValue into sBest[n]
         end if
         set the itemDelimiter to "="
      else if tKey is "sound" then
         put tValue is not "false" into sSound
      else if tKey is "howto" then
         put tValue is "true" into sSeenHowto
      end if
   end repeat
   set the itemDelimiter to comma
end wfLoad

command wfSave
   local tText, n
   put "sound=" & sSound & return & "howto=" & sSeenHowto & return into tText
   repeat with n = 1 to sLevelCount
      if sStars[n] is an integer and sStars[n] > 0 then
         put "level" & n & "=" & sStars[n] & comma & sBest[n] & return after tText
      end if
   end repeat
   try
      put tText into url ("file:" & wfSavePath())
   end try
end wfSave

-- A level can be played when it is the first, or the one before it was
-- cleared
function wfUnlocked pLevel
   if pLevel is 1 then
      return true
   end if
   return sStars[pLevel - 1] is an integer and sStars[pLevel - 1] > 0
end wfUnlocked

-- The first fort not yet cleared that is open (or, all cleared, the
-- first of the land the map shows): Space or Return on the map plays it
function wfNextLevel
   local n
   repeat with n = 1 to sLevelCount
      if wfUnlocked(n) and not (sStars[n] is an integer and sStars[n] > 0) then
         return n
      end if
   end repeat
   return max(1, min(sLevelCount, (sMapLand - 1) * kLevelsPerLand + 1))
end wfNextLevel

function wfTotalStars
   local n, tTotal
   put 0 into tTotal
   repeat with n = 1 to sLevelCount
      if sStars[n] is an integer then
         add sStars[n] to tTotal
      end if
   end repeat
   return tTotal
end wfTotalStars

----------------------------------------------------------------------
-- Sound. The engine plays one sound at a time, in a browser too, and a
-- fort falling makes many at once: in a browser they go to its Web
-- Audio, which mixes them. The page may only make a sound once it has
-- been touched (or clicked, or a key pressed), so the first touch wakes it.

private command wfAudioStart
   local tSounds, tName, tData
   put "none" into sAudio
   put the customProperties["cSounds"] of me into tSounds
   if the keys of tSounds is empty then
      exit wfAudioStart
   end if
   if the platform is "HTML5" then
      try
         do wfAudioScript() as "JavaScript"
         repeat for each key tName in tSounds
            put base64Encode(tSounds[tName]) into tData
            replace return with empty in tData
            do "window.wfAudio.add('" & tName & "','" & tData & "');" as "JavaScript"
         end repeat
         put "web" into sAudio
      end try
   else
      -- written to files when the first sound plays
      put "desktop" into sAudio
      put empty into sAudioDir
   end if
end wfAudioStart

-- The mixer, made once a page: wfAudio.add(name, base64 of a WAV),
-- wfAudio.play(name, volume, rate). The same sound is not started twice
-- in 60 milliseconds (a falling wall would say wood twenty times at once)
private function wfAudioScript
   return "(function(){if(window.wfAudio)return;" & \
         "var C=window.AudioContext||window.webkitAudioContext;" & \
         "var A=window.wfAudio={c:null,raw:{},buf:{},last:{}};" & \
         "A.decode=function(n){var c=A.c;if(!c||A.buf[n]||!A.raw[n])return;A.buf[n]='wait';" & \
         "var s=atob(A.raw[n]),u=new Uint8Array(s.length);for(var i=0;i<s.length;i++)u[i]=s.charCodeAt(i);" & \
         "var ok=function(b){A.buf[n]=b;},no=function(){A.buf[n]=null;};" & \
         "try{var p=c.decodeAudioData(u.buffer,ok,no);if(p&&p.catch)p.catch(no);}catch(e){no();}};" & \
         "A.add=function(n,d){A.raw[n]=d;A.decode(n);};" & \
         "A.unlock=function(){if(!C)return;if(!A.c){try{A.c=new C();}catch(e){return;}}" & \
         "if(A.c.state==='suspended')A.c.resume();for(var n in A.raw)A.decode(n);};" & \
         "['touchend','pointerup','mousedown','keydown'].forEach(function(e){window.addEventListener(e,A.unlock,true);});" & \
         "A.play=function(n,v,r){var c=A.c,b=A.buf[n];if(!c||c.state!=='running'||!b||b==='wait')return;" & \
         "var t=c.currentTime;if(A.last[n]&&t-A.last[n]<0.06)return;A.last[n]=t;" & \
         "var s=c.createBufferSource(),g=c.createGain();s.buffer=b;g.gain.value=v;if(r)s.playbackRate.value=r;" & \
         "s.connect(g);g.connect(c.destination);s.start(0);};})();"
end wfAudioScript

-- A sound at a volume (0 to 1) and, in a browser, a speed (1 as it is:
-- a small piece's knock a little higher than a big one's)
command wfSound pName, pVolume, pRate
   local tSounds, tName
   if sSound is not true or sManual then
      exit wfSound
   end if
   if pRate is not a number then
      put 1 into pRate
   end if
   if sAudio is "web" then
      try
         do "window.wfAudio.play('" & pName & "'," & (round(pVolume * 100) / 100) & "," & (round(pRate * 100) / 100) & ");" as "JavaScript"
      end try
   else if sAudio is "desktop" then
      -- (one sound at a time: only the ones worth hearing)
      if pName is among the items of "wood,glass,stone,metal,thud,grump" then
         exit wfSound
      end if
      try
         if sAudioDir is empty then
            put specialFolderPath("temporary") & "/oxt-wobble-forts-sounds" into sAudioDir
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
end wfSound

-- A buzz, on a phone that can (not an iPhone)
private command wfBuzz pMilliseconds
   if not sLibrary or not sSound then
      exit wfBuzz
   end if
   try
      mwVibrate pMilliseconds
   end try
end wfBuzz

-- The page tells the stack when it is hidden (another app, another tab,
-- the phone locked), through wfPageHidden, one of the stack's
-- cJavascriptHandlers: a level never plays on behind it
private command wfWatchPage
   if the platform is not "HTML5" then
      exit wfWatchPage
   end if
   try
      do "(function(){if(window.wfPageWatch)return;window.wfPageWatch=1;" & \
            "document.addEventListener('visibilitychange',function(){if(!document.hidden)return;" & \
            "try{var s=document.liveCode.findStackWithName('" & the short name of me & "');" & \
            "if(s&&s.wfPageHidden)s.wfPageHidden();}catch(e){}});})();" as "JavaScript"
   end try
end wfWatchPage

on wfPageHidden
   set the defaultStack to the short name of me
   if sMode is "aim" or sMode is "fly" then
      wfPause
   end if
end wfPageHidden

----------------------------------------------------------------------
-- The loop

private command wfSchedule
   if sManual or sLoop is not empty or sMode is "pause" or sMode is "closed" or sMode is "notice" then
      exit wfSchedule
   end if
   if sMode is among the items of "aim,fly,clear,fail" then
      send "wfFrame" to me in 10 milliseconds
   else
      -- the screens move little: fewer frames, less battery
      send "wfFrame" to me in 30 milliseconds
   end if
   put the result into sLoop
end wfSchedule

private command wfStopLoop
   if sLoop is not empty then
      cancel sLoop
      put empty into sLoop
   end if
end wfStopLoop

on wfFrame
   local tNow, tDt
   put empty into sLoop
   if sManual or sMode is "closed" then
      exit wfFrame
   end if
   set the defaultStack to the short name of me
   put the milliseconds into tNow
   put (tNow - sLast) / 1000 into tDt
   put tNow into sLast
   if tDt > 0.5 and (sMode is "fly" or sMode is "aim") then
      -- no frame for half a second: the page was hidden, or the
      -- computer slept
      wfPause
      exit wfFrame
   end if
   add 1 to sFrames
   if tNow - sFpsFrom >= 1000 then
      put round(sFrames * 1000 / (tNow - sFpsFrom)) into sFps
      put 0 into sFrames
      put tNow into sFpsFrom
   end if
   lock screen
   wfAdvance max(0, min(tDt, 0.1))
   put sWork * 0.95 + (the milliseconds - tNow) * 0.05 into sWork
   put the milliseconds into tNow
   unlock screen
   put sDraw * 0.95 + (the milliseconds - tNow) * 0.05 into sDraw
   wfSchedule
end wfFrame

-- The game, pDt seconds on
command wfAdvance pDt
   local tSteps, tFrom
   add pDt to sClock
   -- at most a few knocks a frame: a falling wall is not twenty sounds
   put 4 into sSoundBudget
   switch sMode
      case "aim"
      case "fly"
      case "clear"
      case "fail"
         add pDt to sNow
         -- the physics, in fixed steps: as many as the time asks, at most
         -- kMaxSteps (a slow phone plays a little slower, never jumps)
         put min(kMaxSteps, max(1, round(pDt / kStep))) into tSteps
         put the milliseconds into tFrom
         repeat tSteps
            wfPhysicsStep true
         end repeat
         put sStepMs * 0.9 + (the milliseconds - tFrom) * 0.1 into sStepMs
         wfDrawPieces
         if sMode is "aim" then
            wfAimStep
         else if sMode is "fly" then
            wfFlyStep pDt
         else if sMode is "clear" then
            wfClearStep
         end if
         wfEndStep
         wfHud
         break
      case "title"
         wfTitleStep
         break
   end switch
   wfMoveFx pDt
   if sFlashUntil is a number and sClock >= sFlashUntil then
      set the visible of graphic id sId["Flash"] to false
      put empty into sFlashUntil
   end if
end wfAdvance

----------------------------------------------------------------------
-- Screens

command wfShowScreen pName
   lock screen
   set the visible of group "Title" to (pName is "title")
   set the visible of group "Map" to (pName is "map")
   set the visible of group "Howto" to (pName is "howto")
   set the visible of group "Paused" to (pName is "pause")
   set the visible of group "Clear" to (pName is "clear")
   set the visible of group "Fail" to (pName is "fail")
   set the visible of group "Notice" to (pName is "notice")
   set the visible of graphic "Shade" to (pName is among the items of "map,howto,pause,clear,fail,notice")
   set the visible of group "HUD" to (pName is among the items of "aim,fly,pause,clear,fail")
   unlock screen
end wfShowScreen

-- The title, over the first level's fort
command wfGoTitle
   wfStopAim
   put "title" into sMode
   wfKeepAwake false
   if sPhysics and (sLevel is not 1 or sWorld is 0 or sShots > 0) then
      wfStartLevel 1, false
   end if
   put "title" into sMode
   wfTitleLook
   wfShowScreen "title"
   put the milliseconds into sLast
   wfSchedule
end wfGoTitle

private command wfTitleLook
   local tStars
   put wfTotalStars() into tStars
   if tStars > 0 then
      set the text of field "Records" to "STARS" && tStars && "/" && sLevelCount * 3
   else
      set the text of field "Records" to empty
   end if
   wfSoundLook
end wfTitleLook

-- The title's words wobble, as the forts do
private command wfTitleStep
   wfTurnSprite the long id of image "Logo Wobble", round(4 * sin(sClock * 2.1))
   wfTurnSprite the long id of image "Logo Forts", round(-4 * sin(sClock * 2.1 + 0.9))
end wfTitleStep

-- An image of a screen turned by pDegrees about its middle, at the size
-- the layout gave it (its cBox)
private command wfTurnSprite pImage, pDegrees
   local tBox, tW, tH, tX, tY, tR, tHW, tHH
   put the cBox of pImage into tBox
   if tBox is empty then
      exit wfTurnSprite
   end if
   if the cAngle of pImage is pDegrees then
      exit wfTurnSprite
   end if
   set the cAngle of pImage to pDegrees
   put item 3 of tBox - item 1 of tBox into tW
   put item 4 of tBox - item 2 of tBox into tH
   put (item 1 of tBox + item 3 of tBox) / 2 into tX
   put (item 2 of tBox + item 4 of tBox) / 2 into tY
   put pDegrees * pi / 180 into tR
   put (abs(tW * cos(tR)) + abs(tH * sin(tR))) / 2 into tHW
   put (abs(tW * sin(tR)) + abs(tH * cos(tR))) / 2 into tHH
   set the angle of pImage to pDegrees
   set the rect of pImage to round(tX - tHW), round(tY - tHH), round(tX + tHW), round(tY + tHH)
end wfTurnSprite

-- The levels of a land
command wfShowMap pLand
   local tFirst, i, n, k, tStars, tOpen
   if pLand is an integer then
      put max(1, min(3, pLand)) into sMapLand
   end if
   wfStopAim
   put "map" into sMode
   set the text of field "Map Title" to item sMapLand of kLands
   put (sMapLand - 1) * kLevelsPerLand into tFirst
   put 0 into tStars
   repeat with n = tFirst + 1 to tFirst + kLevelsPerLand
      if sStars[n] is an integer then
         add sStars[n] to tStars
      end if
   end repeat
   set the text of field "Map Sub" to "LAND" && sMapLand && "OF 3  -  " & tStars && "/" && kLevelsPerLand * 3 && "STARS"
   set the text of field "Map Stars" to wfTotalStars()
   repeat with i = 1 to kLevelsPerLand
      put tFirst + i into n
      put wfUnlocked(n) into tOpen
      set the visible of field ("Tile" && i && "Label") to tOpen
      set the text of field ("Tile" && i && "Label") to sMapLand & "-" & i
      set the visible of image ("Tile" && i && "Lock") to not tOpen
      if tOpen then
         set the backgroundColor of graphic ("Tile" && i && "Face") to "#FFCC33"
         set the cUp of graphic ("Tile" && i && "Face") to "#FFCC33"
      else
         set the backgroundColor of graphic ("Tile" && i && "Face") to "#D9CBB0"
         set the cUp of graphic ("Tile" && i && "Face") to "#D9CBB0"
      end if
      repeat with k = 1 to 3
         set the visible of image ("Tile" && i && "Star" && k) to tOpen
         if sStars[n] is an integer and sStars[n] >= k then
            wfPicture the long id of image ("Tile" && i && "Star" && k), "star-gold"
         else
            wfPicture the long id of image ("Tile" && i && "Star" && k), "star-silver"
         end if
      end repeat
   end repeat
   set the visible of button "Map Prev" to sMapLand > 1
   set the visible of graphic "Map Prev Face" to sMapLand > 1
   set the visible of graphic "Map Prev Lip" to sMapLand > 1
   set the visible of image "Map Prev Icon" to sMapLand > 1
   set the visible of button "Map Next" to sMapLand < 3
   set the visible of graphic "Map Next Face" to sMapLand < 3
   set the visible of graphic "Map Next Lip" to sMapLand < 3
   set the visible of image "Map Next Icon" to sMapLand < 3
   -- the land's sky behind the panel
   if sPhysics and (sLevel is empty or sShots > 0 or sLevel is not tFirst + 1) then
      wfStartLevel tFirst + 1, false
      put "map" into sMode
   end if
   wfShowScreen "map"
   put the milliseconds into sLast
   wfSchedule
end wfShowMap

-- The land a level is in (1 to 3)
function wfLandOf pLevel
   if pLevel is not an integer or pLevel < 1 or pLevel > sLevelCount then
      return 1
   end if
   return max(1, min(3, sLevels[pLevel]["land"]))
end wfLandOf

----------------------------------------------------------------------
-- A level: its world, its pieces, its Bloops

-- A level made and shown; pPlay, played (else only shown, behind the
-- title or the map)
command wfStartLevel pLevel, pPlay
   local tLine, tLand, i
   set the defaultStack to the short name of me
   if pLevel is not an integer or pLevel < 1 or pLevel > sLevelCount then
      put 1 into pLevel
   end if
   wfStopAim
   wfFreeWorld
   put pLevel into sLevel
   put wfLandOf(pLevel) into tLand
   lock screen
   repeat with i = 1 to sCount["Fx"]
      put false into sFx[i]["on"]
      wfHideSprite sId["Fx"][i]
   end repeat
   repeat with i = 1 to sCount["Pop"]
      put empty into sPop[i]
      set the visible of field id sId["Pop"][i] to false
   end repeat
   repeat with i = 1 to sCount["Trail"]
      set the visible of graphic id sId["Trail"][i] to false
   end repeat
   put 0 into sTrailCount
   put empty into sTrail
   wfSceneLook tLand
   -- the world: gravity down the screen, bodies that sleep, and the
   -- quick ones kept from passing through others
   put b2NewWorld(0, kGravity, true, true) into sWorld
   b2SetHitEventThreshold sWorld, 1
   put b2NewStaticBody(sWorld, kWorldW / 2 / kM, (kGroundY + 300) / kM) into sGroundBody
   b2ShapeDefEnableHitEvents true
   get b2AddBox(sGroundBody, 4000 / kM, 300 / kM, 1, 0.8, 0)
   repeat for each line tLine in sLevels[pLevel]["pieces"]
      if word 2 of tLine is a number and word 3 of tLine is a number then
         wfAddPiece word 1 of tLine, word 2 of tLine, word 3 of tLine, word 4 of tLine
      end if
   end repeat
   -- a moment for the fort to settle, unseen and harmless
   repeat 30
      wfPhysicsStep false
   end repeat
   put empty into sBreak
   put empty into sPStart
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true then
         put sPX[i], sPY[i] into sPStart[i]
      end if
   end repeat
   put 0 into sScore
   put 0 into sShots
   put 0 into sNow
   put 0 into sShotT
   put 0 into sLastHit
   put 0 into sFlyer
   put empty into sFlyers
   put empty into sEndKind
   put empty into sEndAt
   put sLevels[pLevel]["bloops"] into sQueue
   put empty into sLoaded
   put -10 into sLoadAt
   put 0 into sGrumps
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true and (sPKind[i] is "grump" or sPKind[i] is "boss") then
         add 1 to sGrumps
      end if
   end repeat
   wfLoadNext
   put -10 into sLoadAt
   put empty into sHud
   wfDrawAll
   if pPlay then
      put "aim" into sMode
      if sLevels[pLevel]["hint"] is not empty then
         set the text of field "Hint" to sLevels[pLevel]["hint"]
         put 5 into sHintUntil
      else
         put 0 into sHintUntil
      end if
      wfHud
   end if
   unlock screen
end wfStartLevel

-- The world freed, its sprites hidden
command wfFreeWorld
   local i
   if sWorld is an integer and sWorld > 0 then
      try
         b2DestroyWorld sWorld
      end try
   end if
   put 0 into sWorld
   put empty into sBodyPiece
   put empty into sDirty
   put empty into sBreak
   put empty into sBangs
   put empty into sPunch
   repeat with i = 1 to sCount["Piece"]
      put false into sPAlive[i]
      if sId["Piece"][i] is not empty then
         wfHideSprite sId["Piece"][i]
      end if
   end repeat
end wfFreeWorld

-- The sky, the ground and the scenery of a land
private command wfSceneLook pLand
   local i, tPic
   put item pLand of kSkies into tPic
   wfDrawPicture sId["Sky"], tPic
   repeat with i = 1 to sCount["Ground"]
      wfDrawPicture sId["Ground"][i], item pLand of kGrounds
   end repeat
   if pLand is 3 then
      set the backgroundColor of graphic id sId["Dirt"] to "#808F90"
   else
      set the backgroundColor of graphic id sId["Dirt"] to "#8E6032"
   end if
   repeat with i = 1 to sCount["Deco"]
      if i mod 3 is 0 then
         put "rock" into tPic
      else
         put item pLand of kDecos into tPic
      end if
      wfDrawPicture sId["Deco"][i], tPic
   end repeat
end wfSceneLook

-- A piece of a level line: its kind, its middle (x) and how high its
-- bottom is above the ground, turned by pAngle degrees (clockwise)
command wfAddPiece pKind, pX, pBottom, pAngle
   local tW, tH, tR
   if pAngle is not a number then
      put 0 into pAngle
   end if
   put wfKindSize(pKind) into tW
   if tW is empty then
      return 0
   end if
   put item 2 of tW into tH
   put item 1 of tW into tW
   put pAngle * pi / 180 into tR
   wfMakePiece pKind, pX, kGroundY - pBottom - (abs(tW * sin(tR)) + abs(tH * cos(tR))) / 2, tR
   return the result
end wfAddPiece

-- The size of a kind of piece, in units: width,height (empty if none)
private function wfKindSize pKind
   local tMat, tShape
   set the itemDelimiter to "-"
   put item 1 of pKind into tMat
   put item 2 of pKind into tShape
   set the itemDelimiter to comma
   switch tMat
      case "grump"
         return "70,70"
      case "boss"
         return "84,84"
      case "bloop"
         return (kBloopRadius * kM * 2) & comma & (kBloopRadius * kM * 2)
      default
         return sSize[tMat & "-" & tShape & "-whole"]
   end switch
end wfKindSize

-- A piece made at pX,pY (its middle, in units), turned pAngle radians;
-- returns its number (0 when no sprite is free)
command wfMakePiece pKind, pX, pY, pAngle
   local i, tMat, tShape, tW, tH, tBody, tShape2, tDensity, tFriction, tBounce, tHP
   put 0 into i
   repeat with tW = 1 to sCount["Piece"]
      if sPAlive[tW] is not true then
         put tW into i
         exit repeat
      end if
   end repeat
   if i is 0 then
      return 0
   end if
   put wfKindSize(pKind) into tW
   put item 2 of tW into tH
   put item 1 of tW into tW
   set the itemDelimiter to "-"
   put item 1 of pKind into tMat
   put item 2 of pKind into tShape
   set the itemDelimiter to comma
   switch tMat
      case "grump"
      case "boss"
      case "bloop"
         put tMat into sPKind[i]
         put tShape into sPColor[i]
         break
      default
         put "block" into sPKind[i]
         put empty into sPColor[i]
   end switch
   put tMat into sPMat[i]
   put tShape into sPShape[i]
   put tW into sPW[i]
   put tH into sPH[i]
   -- density (kg a square metre), friction, bounce and health
   switch tMat
      case "wood"
         put "0.7,0.7,0.1,7" into tHP
         break
      case "glass"
         put "0.8,0.4,0.05,3" into tHP
         break
      case "stone"
         put "2,0.8,0.05,14" into tHP
         break
      case "metal"
         put "3,0.5,0.05,40" into tHP
         break
      case "tnt"
         put "0.9,0.6,0.1,3" into tHP
         break
      case "grump"
         put "0.6,0.7,0.2,4" into tHP
         break
      case "boss"
         put "0.9,0.7,0.2,12" into tHP
         break
      default
         put "3,0.6,0.3,1000" into tHP
   end switch
   put item 1 of tHP into tDensity
   put item 2 of tHP into tFriction
   put item 3 of tHP into tBounce
   -- a big block is harder to break than a small one
   put item 4 of tHP * sqrt(tW * tH / (kM * kM)) into sPMax[i]
   put sPMax[i] into sPHP[i]
   put b2NewDynamicBody(sWorld, pX / kM, pY / kM) into tBody
   if pAngle is not 0 then
      b2SetTransform tBody, pX / kM, pY / kM, pAngle
   end if
   b2ShapeDefEnableHitEvents true
   if tMat is "bloop" or tShape is "ball" then
      put b2AddCircle(tBody, 0, 0, tW / 2 / kM, tDensity, tFriction, tBounce) into tShape2
      -- a ball rolls to a stop, not for ever
      b2SetAngularDamping tBody, 1.5
   else
      put b2AddBox(tBody, tW / 2 / kM, tH / 2 / kM, tDensity, tFriction, tBounce) into tShape2
   end if
   put tShape2 into sPShapeId[i]
   put tBody into sPBody[i]
   put i into sBodyPiece[tBody]
   put b2BodyMass(tBody) into sPMass[i]
   put pX into sPX[i]
   put pY into sPY[i]
   put pAngle into sPA[i]
   put true into sPAlive[i]
   put empty into sPLook[i]
   put true into sDirty[i]
   return i
end wfMakePiece

-- A piece taken out of the world, without a sound or a score
private command wfRemovePiece i
   if sPAlive[i] is not true then
      exit wfRemovePiece
   end if
   put false into sPAlive[i]
   delete variable sBodyPiece[sPBody[i]]
   delete variable sDirty[i]
   try
      b2DestroyBody sPBody[i]
   end try
   wfHideSprite sId["Piece"][i]
end wfRemovePiece

-- The picture a piece shows: a block chips and cracks as it weakens
private function wfPiecePic i
   local tLook
   switch sPKind[i]
      case "block"
         if sPHP[i] > sPMax[i] * 0.66 then
            put "whole" into tLook
         else if sPHP[i] > sPMax[i] * 0.33 then
            put "chipped" into tLook
         else
            put "cracked" into tLook
         end if
         return sPMat[i] & "-" & sPShape[i] & "-" & tLook
      default
         return sPKind[i] & "-" & sPColor[i]
   end switch
end wfPiecePic

----------------------------------------------------------------------
-- The physics: one fixed step, its hits, what broke and what went bang

command wfPhysicsStep pDamage
   local n, i, tV, tA, tB, tP, tList, tBody
   if sWorld is not an integer or sWorld <= 0 then
      exit wfPhysicsStep
   end if
   -- the Bloops in the air, as fast as they were: one that breaks what
   -- it hits goes on through it
   repeat for each item tP in sFlyers
      if sPAlive[tP] is true then
         put b2BodyVX(sPBody[tP]) into sFlyVX[tP]
         put b2BodyVY(sPBody[tP]) into sFlyVY[tP]
      end if
   end repeat
   put empty into sPunch
   b2Step sWorld, kStep, 4
   get b2ContactsUpdate(sWorld)
   put b2ContactHitCount() into n
   repeat with i = 1 to n
      put b2ContactHitSpeed(i) into tV
      put sBodyPiece[b2ContactHitBodyA(i)] into tA
      put sBodyPiece[b2ContactHitBodyB(i)] into tB
      if tA is empty and tB is empty then
         next repeat
      end if
      if pDamage then
         wfHitSound tA, tB, tV
         wfHurt tA, tB, tV
         wfHurt tB, tA, tV
         if tV > 2 then
            put sNow into sLastHit
         end if
      end if
   end repeat
   put b2BodiesUpdate(sWorld) into n
   repeat with i = 1 to n
      put sBodyPiece[b2BodyMoveBody(i)] into tP
      if tP is not empty then
         put b2BodyMoveX(i) * kM into sPX[tP]
         put b2BodyMoveY(i) * kM into sPY[tP]
         put b2BodyMoveAngle(i) into sPA[tP]
         put true into sDirty[tP]
         -- off the world: gone
         if sPY[tP] > kWorldH + 300 or sPX[tP] < -500 or sPX[tP] > kWorldW + 500 then
            put "gone" into sBreak[tP]
         end if
      end if
   end repeat
   -- what broke (a bang may break more: those break in the next step)
   if sBreak is not empty then
      put sBreak into tList
      put empty into sBreak
      repeat for each key tP in tList
         wfBreak tP, tList[tP]
      end repeat
      -- a Bloop that broke what it hit keeps some of its speed
      repeat for each key tP in sPunch
         if sPAlive[tP] is true and sFlyVX[tP] is a number then
            put sPBody[tP] into tBody
            b2SetVelocity tBody, sFlyVX[tP] * sPunch[tP], sFlyVY[tP] * sPunch[tP]
         end if
      end repeat
   end if
end wfPhysicsStep

-- A hit's harm to piece pP, by pOther (empty: the ground), at pV metres
-- a second: as much as it was fast, more when the other is heavier
private command wfHurt pP, pOther, pV
   local tRatio, tD, tKeep
   if pP is empty or sPAlive[pP] is not true or sPKind[pP] is "bloop" or pV < 1.5 then
      exit wfHurt
   end if
   if pOther is empty then
      put 2 into tRatio
   else
      put max(0.25, min(4, sPMass[pOther] / max(0.05, sPMass[pP]))) into tRatio
   end if
   put (pV - 1) * sqrt(tRatio) into tD
   subtract tD from sPHP[pP]
   if sPHP[pP] <= 0 then
      put "broke" into sBreak[pP]
      if pOther is not empty and sPKind[pOther] is "bloop" then
         switch sPMat[pP]
            case "glass"
               put 0.85 into tKeep
               break
            case "wood"
               put 0.6 into tKeep
               break
            case "stone"
               put 0.35 into tKeep
               break
            case "metal"
               put 0 into tKeep
               break
            default
               put 0.7 into tKeep
         end switch
         if tKeep > 0 and (sPunch[pOther] is not a number or sPunch[pOther] > tKeep) then
            put tKeep into sPunch[pOther]
         end if
      end if
   else
      put true into sDirty[pP]
   end if
end wfHurt

-- The knock of a hit: the material of what was hit, as loud as it was fast
private command wfHitSound pA, pB, pV
   local tP, tName
   if pV < 2 or sSoundBudget <= 0 then
      exit wfHitSound
   end if
   subtract 1 from sSoundBudget
   if pA is empty then
      put pB into tP
   else if pB is empty then
      put pA into tP
   else if sPKind[pA] is "bloop" then
      put pB into tP
   else
      put pA into tP
   end if
   switch sPKind[tP]
      case "grump"
      case "boss"
         put "grump" into tName
         break
      case "bloop"
         put "thud" into tName
         break
      default
         if sPMat[tP] is "tnt" then
            put "wood" into tName
         else
            put sPMat[tP] into tName
         end if
   end switch
   wfSound tName, min(1, 0.2 + pV / 12), 0.9 + random(20) / 100
end wfHitSound

-- A piece broken (pWhy "broke") or fallen off the world ("gone"): its
-- sound, its puff and debris, its points
command wfBreak i, pWhy
   local tX, tY, tPoints, k, tPic
   if sPAlive[i] is not true then
      exit wfBreak
   end if
   put sPX[i] into tX
   put sPY[i] into tY
   wfRemovePiece i
   switch sPKind[i]
      case "grump"
      case "boss"
         if sPKind[i] is "boss" then
            put 2500 into tPoints
         else
            put 1000 into tPoints
         end if
         subtract 1 from sGrumps
         if pWhy is not "gone" then
            wfFx "puff", tX, tY, 1.1, 0, -20, 0.8, 0, 0.6, 0
            wfFx "sparkle", tX, tY, 0.7, 0, 0, -0.6, 90, 0.5, 0
            wfSound "pop", 0.9, 0.9 + random(20) / 100
            wfSound "grump", 0.6, 1
         end if
         wfBuzz 25
         break
      case "bloop"
         put 0 into tPoints
         if pWhy is not "gone" then
            wfFx "puff", tX, tY, 0.9, 0, -20, 0.8, 0, 0.5, 0
         end if
         break
      default
         switch sPMat[i]
            case "glass"
               put 50 into tPoints
               break
            case "stone"
               put 150 into tPoints
               break
            case "metal"
               put 250 into tPoints
               break
            case "tnt"
               put 200 into tPoints
               break
            default
               put 100 into tPoints
         end switch
         if pWhy is not "gone" then
            repeat with k = 1 to min(4, 2 + round(sPW[i] * sPH[i] / 9800))
               put "debris-" & sPMat[i] & random(3) into tPic
               wfFx tPic, tX + random(40) - 20, tY + random(30) - 15, 0.45, random(240) - 120, -150 - random(150), 0, random(400) - 200, 0.9, 700
            end repeat
            wfFx "puff2", tX, tY, 0.8, 0, -10, 0.6, 0, 0.45, 0
            if sPMat[i] is "tnt" then
               wfBang tX, tY, 1.8, 6, 14
            else if sPMat[i] is "metal" then
               wfSound "metal", 0.9, 0.8
            else
               wfSound sPMat[i] & "-break", 0.8, 0.9 + random(20) / 100
            end if
         end if
   end switch
   if tPoints > 0 then
      add tPoints to sScore
      if pWhy is not "gone" then
         wfPopText tPoints, tX, tY - 30, tPoints >= 1000
      end if
   end if
end wfBreak

-- A bang at pX,pY (units): bodies thrown out to pRadius metres (and as
-- far again, weaker), each piece near it hurt by up to pHurt; a strength
-- of pPush
command wfBang pX, pY, pRadius, pPush, pHurt
   local i, tD, tReach
   if sWorld is not an integer or sWorld <= 0 then
      exit wfBang
   end if
   b2WorldExplode sWorld, pX / kM, pY / kM, pRadius, pRadius, pPush
   put pRadius + 0.6 into tReach
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true and sPKind[i] is not "bloop" then
         put sqrt((sPX[i] - pX) ^ 2 + (sPY[i] - pY) ^ 2) / kM into tD
         if tD < tReach then
            subtract pHurt * (1 - tD / tReach) from sPHP[i]
            if sPHP[i] <= 0 then
               put "broke" into sBreak[i]
            else
               put true into sDirty[i]
            end if
         end if
      end if
   end repeat
   wfFx "ring", pX, pY, 1, 0, 0, 5, 0, 0.4, 0
   wfFx "flash", pX, pY, 2.2, 0, 0, 2, 0, 0.25, 0
   repeat with i = 1 to 3
      wfFx "puff", pX + random(80) - 40, pY + random(60) - 30, 1.2, random(120) - 60, -40 - random(60), 0.7, 0, 0.8, 0
   end repeat
   wfSound "boom", 1, 0.9 + random(20) / 100
   wfFlash
   wfBuzz 60
   put sNow into sLastHit
end wfBang

----------------------------------------------------------------------
-- Drawing. A sprite is drawn at a place of the world (units), at a size
-- (units) and turned by degrees (clockwise): its picture, angle and rect
-- are set only when they change

command wfDrawSprite pId, pPic, pX, pY, pW, pH, pDeg
   local tDeg, tR, tW, tH, tHW, tHH, tCX, tCY, tRect
   put round(pDeg) mod 360 into tDeg
   if tDeg < 0 then
      add 360 to tDeg
   end if
   if sSprPic[pId] is not pPic then
      if sArtId[pPic] is empty then
         exit wfDrawSprite
      end if
      set the text of image id pId to the text of image id sArtId[pPic] of card "Art"
      put pPic into sSprPic[pId]
      put empty into sSprAngle[pId]
      put empty into sSprRect[pId]
   end if
   if sSprAngle[pId] is not tDeg then
      -- an image turns the other way (anticlockwise) from the world
      set the angle of image id pId to (360 - tDeg) mod 360
      put tDeg into sSprAngle[pId]
      put empty into sSprRect[pId]
   end if
   put pW * sV into tW
   put pH * sV into tH
   put tDeg * pi / 180 into tR
   put (abs(tW * cos(tR)) + abs(tH * sin(tR))) / 2 into tHW
   put (abs(tW * sin(tR)) + abs(tH * cos(tR))) / 2 into tHH
   put sOX + pX * sV into tCX
   put sOY + pY * sV into tCY
   put round(tCX - tHW), round(tCY - tHH), max(round(tCX - tHW) + 1, round(tCX + tHW)), max(round(tCY - tHH) + 1, round(tCY + tHH)) into tRect
   if sSprRect[pId] is not tRect then
      set the rect of image id pId to tRect
      put tRect into sSprRect[pId]
   end if
   if sSprOn[pId] is not true then
      set the visible of image id pId to true
      put true into sSprOn[pId]
   end if
end wfDrawSprite

command wfHideSprite pId
   if sSprOn[pId] is not false then
      set the visible of image id pId to false
      put false into sSprOn[pId]
   end if
end wfHideSprite

-- A sprite's picture only (the scenery: placed by wfLayout)
private command wfDrawPicture pId, pPic
   if sSprPic[pId] is not pPic and sArtId[pPic] is not empty then
      set the text of image id pId to the text of image id sArtId[pPic] of card "Art"
      put pPic into sSprPic[pId]
      put empty into sSprAngle[pId]
      put empty into sSprRect[pId]
   end if
end wfDrawPicture

-- An image of a screen given a picture of card "Art" (its rect kept)
command wfPicture pImage, pName
   if the cPicture of pImage is pName or sArtId[pName] is empty then
      exit wfPicture
   end if
   set the text of pImage to the text of image id sArtId[pName] of card "Art"
   set the cPicture of pImage to pName
end wfPicture

-- The pieces that moved or changed
command wfDrawPieces
   local i
   repeat for each key i in sDirty
      if sPAlive[i] is true then
         wfDrawSprite sId["Piece"][i], wfPiecePic(i), sPX[i], sPY[i], sPW[i], sPH[i], sPA[i] * 180 / pi
      end if
   end repeat
   put empty into sDirty
end wfDrawPieces

-- Everything of the world where it is (after the window changed)
command wfDrawAll
   local i
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true then
         put true into sDirty[i]
      end if
   end repeat
   wfDrawPieces
   wfDrawLauncher
   wfDrawQueue
   wfDrawTrail
   wfDrawAim
   wfDrawFx
end wfDrawAll

-- The launcher: its post and crossbar, the bands and the Bloop in it
private command wfDrawLauncher
   local tX, tY, tF, tTop, tBand, tPull, tLen
   put kAnchorY - 62 into tTop
   wfDrawSprite sId["Post"], "wood-pillar-whole", kAnchorX, (tTop + kGroundY) / 2, 30, kGroundY - tTop + 10, 0
   wfDrawSprite sId["Fork"], "wood-plank-whole", kAnchorX, tTop, 120, 28, 0
   put max(2, round(8 * sV)) into tBand
   set the lineSize of graphic id sId["Band Back"] to tBand
   set the lineSize of graphic id sId["Band Front"] to tBand
   if sLoaded is empty then
      wfHideSprite sId["Loaded"]
      set the points of graphic id sId["Band Back"] to wfScreenPoint(kAnchorX - 52, tTop) & return & wfScreenPoint(kAnchorX + 52, tTop)
      set the visible of graphic id sId["Band Back"] to true
      set the visible of graphic id sId["Band Front"] to false
      exit wfDrawLauncher
   end if
   -- hopping in from the queue
   put min(1, max(0, (sNow - sLoadAt) / 0.4)) into tF
   if tF < 1 then
      put wfQueueX(1) + (kAnchorX - wfQueueX(1)) * tF into tX
      put (kGroundY - 25) + (kAnchorY - kGroundY + 25) * tF - 160 * sin(tF * pi) into tY
   else
      put kAnchorX + sPullX into tX
      put kAnchorY + sPullY into tY
   end if
   wfDrawSprite sId["Loaded"], "bloop-" & sLoaded, tX, tY, kBloopRadius * kM * 2, kBloopRadius * kM * 2, 0
   if tF < 1 then
      put kAnchorX into tX
      put kAnchorY into tY
   else
      -- the bands hold the Bloop at its back
      put sqrt(sPullX ^ 2 + sPullY ^ 2) into tLen
      if tLen > 1 then
         add sPullX / tLen * 26 to tX
         add sPullY / tLen * 26 to tY
      else
         add 20 to tY
      end if
   end if
   set the points of graphic id sId["Band Back"] to wfScreenPoint(kAnchorX + 52, tTop) & return & wfScreenPoint(tX, tY)
   set the points of graphic id sId["Band Front"] to wfScreenPoint(kAnchorX - 52, tTop) & return & wfScreenPoint(tX, tY)
   set the visible of graphic id sId["Band Back"] to true
   set the visible of graphic id sId["Band Front"] to true
end wfDrawLauncher

private function wfScreenPoint pX, pY
   return round(sOX + pX * sV) & comma & round(sOY + pY * sV)
end wfScreenPoint

-- Where the Bloops wait: in a row behind the launcher
private function wfQueueX pSlot
   return kAnchorX - 92 - (pSlot - 1) * 52
end wfQueueX

private command wfDrawQueue
   local k, tColor
   repeat with k = 1 to sCount["Queue"]
      put word k of sQueue into tColor
      if tColor is empty then
         wfHideSprite sId["Queue"][k]
      else
         wfDrawSprite sId["Queue"][k], "bloop-" & tColor, wfQueueX(k), kGroundY - 25, 50, 50, 0
      end if
   end repeat
end wfDrawQueue

-- The next Bloop into the launcher; the last shot's Bloops taken away
private command wfLoadNext
   local i
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true and sPKind[i] is "bloop" then
         wfFx "puff", sPX[i], sPY[i], 0.8, 0, -20, 0.6, 0, 0.45, 0
         wfRemovePiece i
      end if
   end repeat
   put empty into sFlyers
   put 0 into sFlyer
   put 0 into sPullX
   put 0 into sPullY
   if sQueue is empty then
      put empty into sLoaded
   else
      put word 1 of sQueue into sLoaded
      delete word 1 of sQueue
      put sNow into sLoadAt
   end if
   wfDrawQueue
   wfDrawLauncher
end wfLoadNext

----------------------------------------------------------------------
-- Aiming and the shot

-- A finger down: in aim, it pulls the Bloop (from anywhere); in a shot,
-- it does the Bloop's trick
private command wfFingerDown
   set the defaultStack to the short name of me
   if sMode is "aim" then
      if sLoaded is not empty and sNow - sLoadAt >= 0.4 and sEndKind is empty then
         put true into sAiming
         put the mouseLoc into sAimFrom
         put 0 into sPullX
         put 0 into sPullY
         wfSound "stretch", 0.5, 1
      end if
   else if sMode is "fly" then
      wfTrick
   end if
end wfFingerDown

private command wfFingerUp
   set the defaultStack to the short name of me
   if sAiming then
      put false into sAiming
      if sMode is "aim" then
         wfLaunch sPullX, sPullY
      end if
   end if
end wfFingerUp

-- The pull, from the finger, every frame of the aim
private command wfAimStep
   local tLoc, tDX, tDY, tLen
   if sAiming and not sManual then
      put the mouseLoc into tLoc
      put (item 1 of tLoc - item 1 of sAimFrom) / sV into tDX
      put (item 2 of tLoc - item 2 of sAimFrom) / sV into tDY
      put sqrt(tDX ^ 2 + tDY ^ 2) into tLen
      if tLen > kPull then
         put tDX * kPull / tLen into tDX
         put tDY * kPull / tLen into tDY
      end if
      put tDX into sPullX
      put tDY into sPullY
   end if
   if sLoaded is not empty then
      wfDrawLauncher
   end if
   wfDrawAim
end wfAimStep

-- The dots of the aim: where the Bloop would go for its first half second
private command wfDrawAim
   local k, tVX, tVY, tX, tY, tT, tS, tShow
   put sAiming and sMode is "aim" and sqrt(sPullX ^ 2 + sPullY ^ 2) >= 18 into tShow
   if tShow then
      put -sPullX / kPull * kLaunchSpeed into tVX
      put -sPullY / kPull * kLaunchSpeed into tVY
   end if
   repeat with k = 1 to sCount["Aim"]
      if tShow then
         put k * 0.045 into tT
         put (kAnchorX + sPullX) / kM + tVX * tT into tX
         put (kAnchorY + sPullY) / kM + tVY * tT + kGravity / 2 * tT * tT into tY
         if tY * kM > kGroundY then
            put false into tShow
         end if
      end if
      if tShow then
         put max(2, (16 - k * 0.6) * sV / 2) into tS
         put tX * kM * sV + sOX into tX
         put tY * kM * sV + sOY into tY
         set the rect of graphic id sId["Aim"][k] to round(tX - tS), round(tY - tS), round(tX + tS), round(tY + tS)
         set the visible of graphic id sId["Aim"][k] to true
      else
         set the visible of graphic id sId["Aim"][k] to false
      end if
   end repeat
end wfDrawAim

command wfStopAim
   local k
   put false into sAiming
   put 0 into sPullX
   put 0 into sPullY
   if sCount["Aim"] is an integer then
      repeat with k = 1 to sCount["Aim"]
         set the visible of graphic id sId["Aim"][k] to false
      end repeat
   end if
end wfStopAim

-- The Bloop let go, pulled by pPullX,pPullY units (a short pull is no shot)
command wfLaunch pPullX, pPullY
   local i, tLen, k
   if sMode is not "aim" or sLoaded is empty or sEndKind is not empty then
      exit wfLaunch
   end if
   put sqrt(pPullX ^ 2 + pPullY ^ 2) into tLen
   if tLen < 18 then
      wfStopAim
      wfDrawLauncher
      exit wfLaunch
   end if
   if tLen > kPull then
      put pPullX * kPull / tLen into pPullX
      put pPullY * kPull / tLen into pPullY
   end if
   wfMakePiece "bloop-" & sLoaded, kAnchorX + pPullX, kAnchorY + pPullY, 0
   put the result into i
   if i is not an integer or i <= 0 then
      exit wfLaunch
   end if
   b2SetBullet sPBody[i], true
   b2SetVelocity sPBody[i], -pPullX / kPull * kLaunchSpeed, -pPullY / kPull * kLaunchSpeed
   put i into sFlyer
   put i into sFlyers
   put false into sTrickUsed
   put sNow into sShotT
   put sNow into sLastHit
   add 1 to sShots
   put empty into sLoaded
   put 0 into sHintUntil
   wfStopAim
   wfDrawLauncher
   repeat with k = 1 to sCount["Trail"]
      set the visible of graphic id sId["Trail"][k] to false
   end repeat
   put 0 into sTrailCount
   put empty into sTrail
   put sNow into sTrailAt
   put "fly" into sMode
   wfSound "launch", 0.8, 1
   wfDrawPieces
end wfLaunch

-- The shot in the air: its trail, and whether it is over
private command wfFlyStep pDt
   local tT, tAwake
   put sNow - sShotT into tT
   if sPAlive[sFlyer] is true and sNow >= sTrailAt and sTrailCount < sCount["Trail"] and tT < 5 then
      add 1 to sTrailCount
      put round(sPX[sFlyer]), round(sPY[sFlyer]), 5 + (sTrailCount mod 2) * 3 into sTrail[sTrailCount]
      wfDrawTrailDot sTrailCount
      put sNow + 0.06 into sTrailAt
   end if
   put b2AwakeBodyCount(sWorld) into tAwake
   if (tAwake is 0 and tT > 0.5) or tT > kShotMax or (tT > 4 and sNow - sLastHit > 3) then
      wfShotDone
   end if
end wfFlyStep

private command wfShotDone
   put "aim" into sMode
   put 0 into sFlyer
   wfLoadNext
end wfShotDone

private command wfDrawTrailDot k
   local tX, tY, tS
   put item 3 of sTrail[k] * sV into tS
   put sOX + item 1 of sTrail[k] * sV into tX
   put sOY + item 2 of sTrail[k] * sV into tY
   set the rect of graphic id sId["Trail"][k] to round(tX - tS), round(tY - tS), round(tX + tS) + 1, round(tY + tS) + 1
   set the visible of graphic id sId["Trail"][k] to true
end wfDrawTrailDot

private command wfDrawTrail
   local k
   repeat with k = 1 to sTrailCount
      wfDrawTrailDot k
   end repeat
end wfDrawTrail

-- A tap while a Bloop flies: its trick, once. Zip (blue) dashes, Trio
-- (pink) splits in three, Thud (green) drops like a stone, Boom (beige)
-- goes bang; the yellow Bloop has none
command wfTrick
   local tBody, tVX, tVY, tX, tY, k, i, tA, tSpeed, tNX, tNY
   if sMode is not "fly" or sTrickUsed or sPAlive[sFlyer] is not true then
      exit wfTrick
   end if
   if sPColor[sFlyer] is "yellow" then
      exit wfTrick
   end if
   put true into sTrickUsed
   put sPBody[sFlyer] into tBody
   put b2BodyVX(tBody) into tVX
   put b2BodyVY(tBody) into tVY
   put sPX[sFlyer] into tX
   put sPY[sFlyer] into tY
   switch sPColor[sFlyer]
      case "blue"
         b2SetVelocity tBody, tVX * 1.8, tVY * 1.8
         wfFx "sparkle", tX, tY, 0.8, 0, 0, -1, 180, 0.4, 0
         wfFx "puff2", tX, tY, 0.6, -tVX * 10, -tVY * 10, 0.8, 0, 0.4, 0
         wfSound "dash", 0.8, 1
         break
      case "pink"
         put sqrt(tVX ^ 2 + tVY ^ 2) into tSpeed
         if tSpeed < 0.5 then
            put false into sTrickUsed
            exit wfTrick
         end if
         put -tVY / tSpeed into tNX
         put tVX / tSpeed into tNY
         repeat for each item k in "-1,1"
            put atan2(tVY, tVX) + k * 0.2 into tA
            wfMakePiece "bloop-pink", tX + tNX * 72 * k, tY + tNY * 72 * k, 0
            put the result into i
            if i is an integer and i > 0 then
               b2SetBullet sPBody[i], true
               b2SetVelocity sPBody[i], tSpeed * cos(tA), tSpeed * sin(tA)
               put comma & i after sFlyers
            end if
         end repeat
         wfFx "sparkle", tX, tY, 0.9, 0, 0, -1, 180, 0.4, 0
         wfSound "split", 0.8, 1
         break
      case "green"
         b2SetShapeDensity sPShapeId[sFlyer], 9
         b2ApplyMassFromShapes tBody
         put b2BodyMass(tBody) into sPMass[sFlyer]
         b2SetVelocity tBody, tVX * 0.25, max(tVY, 0) + 22
         wfFx "puff2", tX, tY, 0.7, 0, -30, 0.8, 0, 0.4, 0
         wfSound "slam", 0.9, 1
         break
      case "beige"
         wfRemovePiece sFlyer
         wfBang tX, tY, 2.2, 5, 20
         break
   end switch
end wfTrick

----------------------------------------------------------------------
-- Puffs, debris, sparkles and the scores that float up

-- A puff: its picture, place (units), size (times the picture's), speed
-- (units a second), growth (sizes a second), spin (degrees a second),
-- life (seconds) and fall (units a second a second). It fades as it goes
command wfFx pPic, pX, pY, pScale, pVX, pVY, pGrow, pSpin, pLife, pFall
   local i, k, tOldest
   put 0 into i
   put 0 into tOldest
   repeat with k = 1 to sCount["Fx"]
      if sFx[k]["on"] is not true then
         put k into i
         exit repeat
      end if
      if tOldest is 0 or sFx[k]["t"] > sFx[tOldest]["t"] then
         put k into tOldest
      end if
   end repeat
   if i is 0 then
      put tOldest into i
   end if
   if i is 0 or sSize[pPic] is empty then
      exit wfFx
   end if
   put true into sFx[i]["on"]
   put pPic into sFx[i]["pic"]
   put pX into sFx[i]["x"]
   put pY into sFx[i]["y"]
   put pScale into sFx[i]["s"]
   put pVX into sFx[i]["vx"]
   put pVY into sFx[i]["vy"]
   put pGrow into sFx[i]["grow"]
   put pSpin into sFx[i]["spin"]
   put random(360) into sFx[i]["a"]
   if pSpin is 0 then
      put 0 into sFx[i]["a"]
   end if
   put pLife into sFx[i]["life"]
   put pFall into sFx[i]["fall"]
   put 0 into sFx[i]["t"]
   put -1 into sFx[i]["blend"]
   wfDrawFxOne i
end wfFx

private command wfDrawFxOne i
   local tBlend
   wfDrawSprite sId["Fx"][i], sFx[i]["pic"], sFx[i]["x"], sFx[i]["y"], \
         item 1 of sSize[sFx[i]["pic"]] * sFx[i]["s"], item 2 of sSize[sFx[i]["pic"]] * sFx[i]["s"], sFx[i]["a"]
   put round(max(0, min(100, 100 * (sFx[i]["t"] / sFx[i]["life"]) ^ 2))) into tBlend
   if tBlend is not sFx[i]["blend"] then
      set the blendLevel of image id sId["Fx"][i] to tBlend
      put tBlend into sFx[i]["blend"]
   end if
end wfDrawFxOne

private command wfDrawFx
   local i
   repeat with i = 1 to sCount["Fx"]
      if sFx[i]["on"] is true then
         wfDrawFxOne i
      end if
   end repeat
   repeat with i = 1 to sCount["Pop"]
      if sPop[i] is not empty then
         wfDrawPop i
      end if
   end repeat
end wfDrawFx

command wfMoveFx pDt
   local i
   repeat with i = 1 to sCount["Fx"]
      if sFx[i]["on"] is true then
         add pDt to sFx[i]["t"]
         if sFx[i]["t"] >= sFx[i]["life"] then
            put false into sFx[i]["on"]
            wfHideSprite sId["Fx"][i]
         else
            add sFx[i]["fall"] * pDt to sFx[i]["vy"]
            add sFx[i]["vx"] * pDt to sFx[i]["x"]
            add sFx[i]["vy"] * pDt to sFx[i]["y"]
            put max(0.05, sFx[i]["s"] + sFx[i]["grow"] * pDt) into sFx[i]["s"]
            add sFx[i]["spin"] * pDt to sFx[i]["a"]
            wfDrawFxOne i
         end if
      end if
   end repeat
   repeat with i = 1 to sCount["Pop"]
      if sPop[i] is not empty then
         add pDt to sPop[i]["t"]
         if sPop[i]["t"] >= 1.1 then
            put empty into sPop[i]
            set the visible of field id sId["Pop"][i] to false
         else
            subtract 50 * pDt from sPop[i]["y"]
            wfDrawPop i
         end if
      end if
   end repeat
end wfMoveFx

-- Points floating up from where they were won
command wfPopText pPoints, pX, pY, pBig
   local i
   add 1 to sPopNext
   if sPopNext > sCount["Pop"] then
      put 1 into sPopNext
   end if
   put sPopNext into i
   put pX into sPop[i]["x"]
   put pY into sPop[i]["y"]
   put 0 into sPop[i]["t"]
   if pBig then
      set the textSize of field id sId["Pop"][i] to max(10, round(30 * sV * 1.6))
      set the textColor of field id sId["Pop"][i] to kGold
   else
      set the textSize of field id sId["Pop"][i] to max(9, round(22 * sV * 1.6))
      set the textColor of field id sId["Pop"][i] to kWhite
   end if
   set the text of field id sId["Pop"][i] to pPoints
   set the visible of field id sId["Pop"][i] to true
   wfDrawPop i
end wfPopText

private command wfDrawPop i
   local tX, tY, tH
   put sOX + sPop[i]["x"] * sV into tX
   put sOY + sPop[i]["y"] * sV into tY
   put the textSize of field id sId["Pop"][i] * 1.4 into tH
   set the rect of field id sId["Pop"][i] to round(tX - 120), round(tY - tH / 2), round(tX + 120), round(tY + tH / 2)
end wfDrawPop

command wfFlash
   set the visible of graphic id sId["Flash"] to true
   put sClock + 0.08 into sFlashUntil
end wfFlash

----------------------------------------------------------------------
-- The end of a level: every Grump popped, or no Bloops left

private command wfEndStep
   if sMode is not "aim" and sMode is not "fly" then
      exit wfEndStep
   end if
   if sEndKind is empty then
      if sGrumps <= 0 then
         put "clear" into sEndKind
         put sNow + 1.6 into sEndAt
         wfStopAim
      else if sMode is "aim" and sLoaded is empty and sQueue is empty then
         put "fail" into sEndKind
         put sNow + 1.2 into sEndAt
      end if
   else if sNow >= sEndAt then
      if sGrumps <= 0 then
         wfShowClear
      else
         wfShowFail
      end if
   end if
end wfEndStep

-- Every Grump popped: the Bloops to spare counted, the stars given
command wfShowClear
   local tSpare, tStars, k
   wfStopAim
   put "clear" into sMode
   put the number of words of sQueue into tSpare
   if sLoaded is not empty then
      add 1 to tSpare
   end if
   put tSpare into sClearSpare
   put 1 + min(2, tSpare) into tStars
   put tStars into sClearStars
   put sScore into sClearBase
   add tSpare * 1500 to sScore
   put sNow into sClearAt
   put 0 into sClearShown
   -- kept now (the counting is only a show)
   put sBest[sLevel] is not an integer or sScore > sBest[sLevel] into sClearNew
   if sClearNew then
      put sScore into sBest[sLevel]
   end if
   if sStars[sLevel] is not an integer or tStars > sStars[sLevel] then
      put tStars into sStars[sLevel]
   end if
   wfSave
   repeat with k = 1 to 3
      wfPicture the long id of image ("Clear Star" && k), "star-silver"
   end repeat
   set the text of field "Clear Score" to wfCommas(sClearBase)
   set the text of field "Clear Best" to empty
   if sLevel < sLevelCount then
      set the text of field "Clear Next Label" to "ONWARD"
   else
      set the text of field "Clear Next Label" to "LEVELS"
   end if
   if sLevel mod kLevelsPerLand is 0 and sLevel < sLevelCount then
      set the text of field "Clear Title" to "LAND CLEARED!"
   else
      set the text of field "Clear Title" to "FORT DOWN!"
   end if
   wfShowScreen "clear"
   wfKeepAwake false
   wfSound "clear", 0.9, 1
end wfShowClear

-- The counting and the stars, one at a time
private command wfClearStep
   local tE, tDue, k
   put sNow - sClearAt into tE
   -- each Bloop to spare: 1,500 points
   put max(0, min(sClearSpare, trunc((tE - 0.6) / 0.4) + 1)) into tDue
   if tE < 0.6 then
      put 0 into tDue
   end if
   repeat while sClearShown < tDue
      add 1 to sClearShown
      set the text of field "Clear Score" to wfCommas(sClearBase + sClearShown * 1500)
      if sLoaded is not empty then
         wfFx "puff", kAnchorX, kAnchorY, 0.8, 0, -20, 0.6, 0, 0.45, 0
         wfPopText 1500, kAnchorX, kAnchorY - 50, true
         put empty into sLoaded
         wfDrawLauncher
      else
         wfFx "puff", wfQueueX(the number of words of sQueue), kGroundY - 29, 0.8, 0, -20, 0.6, 0, 0.45, 0
         wfPopText 1500, wfQueueX(the number of words of sQueue), kGroundY - 80, true
         delete word -1 of sQueue
         wfDrawQueue
      end if
      wfSound "pop", 0.8, 1 + sClearShown / 10
   end repeat
   -- then the stars
   put 0.9 + sClearSpare * 0.4 into tDue
   repeat with k = 1 to sClearStars
      if sClearShown is sClearSpare + k - 1 and tE >= tDue + (k - 1) * 0.45 then
         add 1 to sClearShown
         wfPicture the long id of image ("Clear Star" && k), "star-gold"
         wfSound "star" & k, 0.9, 1
         wfBuzz 20
      end if
   end repeat
   if sClearShown is sClearSpare + sClearStars then
      add 1 to sClearShown
      if sClearNew then
         set the text of field "Clear Best" to "NEW BEST!"
         wfSound "unlock", 0.8, 1
      else
         set the text of field "Clear Best" to "BEST" && wfCommas(sBest[sLevel])
      end if
   end if
end wfClearStep

-- No Bloops left, and a Grump still standing
command wfShowFail
   local i, tColor
   wfStopAim
   put "fail" into sMode
   put "green" into tColor
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true and sPKind[i] is "grump" then
         put sPColor[i] into tColor
         exit repeat
      end if
   end repeat
   wfPicture the long id of image "Fail Grump", "grump-" & tColor
   if sGrumps is 1 then
      set the text of field "Fail Text" to "One Grump held on. Try another way in!"
   else
      set the text of field "Fail Text" to sGrumps && "Grumps held on. Try another way in!"
   end if
   wfShowScreen "fail"
   wfKeepAwake false
   wfSound "fail", 0.8, 1
end wfShowFail

----------------------------------------------------------------------
-- The HUD

private command wfHud
   local tName
   put wfCommas(sScore) into tName
   if sHud["score"] is not tName then
      set the text of field "Score" to tName
      put tName into sHud["score"]
   end if
   put "LEVEL" && wfLandOf(sLevel) & "-" & ((sLevel - 1) mod kLevelsPerLand + 1) into tName
   if sHud["name"] is not tName then
      set the text of field "Level Name" to tName
      put tName into sHud["name"]
   end if
   put sNow < sHintUntil into tName
   if sHud["hint"] is not tName then
      set the visible of field "Hint" to tName
      put tName into sHud["hint"]
   end if
end wfHud

function wfCommas pNumber
   local tOut
   put round(pNumber) into pNumber
   repeat while pNumber >= 1000
      put comma & format("%03d", pNumber mod 1000) & tOut into tOut
      put pNumber div 1000 into pNumber
   end repeat
   return pNumber & tOut
end wfCommas

----------------------------------------------------------------------
-- Playing, pausing, the screens' buttons

-- A level played from its start
command wfPlay pLevel
   set the defaultStack to the short name of me
   if not sPhysics then
      exit wfPlay
   end if
   wfStartLevel pLevel, true
   wfShowScreen "aim"
   wfKeepAwake true
   wfSound "start", 0.7, 1
   put the milliseconds into sLast
   wfSchedule
end wfPlay

command wfPause
   set the defaultStack to the short name of me
   if sMode is not "aim" and sMode is not "fly" then
      exit wfPause
   end if
   put sMode into sPauseFrom
   wfStopAim
   if sLoaded is not empty then
      wfDrawLauncher
   end if
   put "pause" into sMode
   wfStopLoop
   wfSoundLook
   wfShowScreen "pause"
   wfKeepAwake false
end wfPause

command wfResume
   set the defaultStack to the short name of me
   if sMode is not "pause" then
      exit wfResume
   end if
   put sPauseFrom into sMode
   wfShowScreen sMode
   wfKeepAwake true
   put the milliseconds into sLast
   wfSchedule
end wfResume

private command wfShowHowto pThen
   put pThen into sHowtoThen
   wfStopAim
   put "howto" into sMode
   wfShowScreen "howto"
   put the milliseconds into sLast
   wfSchedule
end wfShowHowto

command wfShowNotice
   wfStopLoop
   put "notice" into sMode
   wfShowScreen "notice"
end wfShowNotice

-- The screen kept on while a level plays (in a page served over https)
private command wfKeepAwake pOn
   if not sLibrary or sAwake is pOn then
      exit wfKeepAwake
   end if
   put pOn into sAwake
   try
      if mwIsWeb() then
         mwKeepAwake pOn
      end if
   end try
end wfKeepAwake

-- The sound buttons' icons, and the full screen button's
private command wfSoundLook
   local tPic
   if sSound then
      put "icon-audio-on" into tPic
   else
      put "icon-audio-off" into tPic
   end if
   wfPicture the long id of image "Title Sound Icon", tPic
   wfPicture the long id of image "Pause Sound Icon", tPic
   put false into tPic
   if sLibrary and sWeb then
      try
         put mwIsFullScreen() into tPic
      end try
   end if
   if tPic is true then
      wfPicture the long id of image "Title Full Icon", "icon-smaller"
   else
      wfPicture the long id of image "Title Full Icon", "icon-larger"
   end if
end wfSoundLook

-- A button of the screens, pressed (pDown) or let go
command wfButtonLook pName, pDown
   local tFace
   put pName && "Face" into tFace
   if there is not a graphic tFace then
      exit wfButtonLook
   end if
   if pDown then
      set the backgroundColor of graphic tFace to the cDown of graphic tFace
   else
      set the backgroundColor of graphic tFace to the cUp of graphic tFace
   end if
end wfButtonLook

-- What each button of the screens does
command wfPress pName
   local tLevel, tResult
   set the defaultStack to the short name of me
   wfSound "click", 0.5, 1
   if pName begins with "Tile " then
      put (sMapLand - 1) * kLevelsPerLand + word 2 of pName into tLevel
      if wfUnlocked(tLevel) then
         wfPlay tLevel
      else
         wfBuzz 30
      end if
      exit wfPress
   end if
   switch pName
      case "Play"
         if not sSeenHowto then
            wfShowHowto "map"
         else
            put 1 into tLevel
            repeat while tLevel < sLevelCount and wfUnlocked(tLevel + 1)
               add 1 to tLevel
            end repeat
            wfShowMap wfLandOf(tLevel)
         end if
         break
      case "Title Howto"
         wfShowHowto "title"
         break
      case "Howto Go"
         if not sSeenHowto then
            put true into sSeenHowto
            wfSave
         end if
         if sHowtoThen is "map" then
            wfShowMap 1
         else
            wfGoTitle
         end if
         break
      case "Title Sound"
      case "Pause Sound"
         put not sSound into sSound
         wfSave
         wfSoundLook
         wfSound "click", 0.5, 1
         break
      case "Title Full"
         if sLibrary then
            try
               mwFullScreen not mwIsFullScreen()
               put the result into tResult
            catch tResult
            end try
         end if
         wfSoundLook
         break
      case "Map Prev"
         wfShowMap sMapLand - 1
         break
      case "Map Next"
         wfShowMap sMapLand + 1
         break
      case "Map Home"
         wfGoTitle
         break
      case "Pause"
         wfPause
         break
      case "Resume"
         wfResume
         break
      case "Pause Restart"
      case "Clear Replay"
      case "Fail Retry"
         wfPlay sLevel
         break
      case "Pause Levels"
      case "Clear Levels"
      case "Fail Levels"
         wfShowMap wfLandOf(sLevel)
         break
      case "Clear Next"
         if sLevel < sLevelCount then
            wfPlay sLevel + 1
         else
            wfShowMap 3
         end if
         break
   end switch
end wfPress

-- The keys: P or Escape pauses and goes on, R plays the level again,
-- Space or Return goes on from a screen
on rawKeyDown pKey
   set the defaultStack to the short name of me
   switch pKey
      case 112
      case 80
      case 65307
         if sMode is "aim" or sMode is "fly" then
            wfPause
         else if sMode is "pause" then
            wfResume
         else
            pass rawKeyDown
         end if
         break
      case 114
      case 82
         if sMode is among the items of "aim,fly,pause,clear,fail" then
            wfPlay sLevel
         else
            pass rawKeyDown
         end if
         break
      case 32
      case 65293
      case 65421
         switch sMode
            case "title"
               wfPress "Play"
               break
            case "howto"
               wfPress "Howto Go"
               break
            case "map"
               -- (the keys alone play: the next fort to clear)
               wfPlay wfNextLevel()
               break
            case "pause"
               wfPress "Resume"
               break
            case "clear"
               wfPress "Clear Next"
               break
            case "fail"
               wfPress "Fail Retry"
               break
            case "fly"
               wfTrick
               break
            default
               pass rawKeyDown
         end switch
         break
      default
         pass rawKeyDown
   end switch
end rawKeyDown

-- A finger (or the mouse) down anywhere but on a button
on mouseDown
   wfFingerDown
end mouseDown

on mouseDoubleDown
   wfFingerDown
end mouseDoubleDown

on mouseUp
   wfFingerUp
end mouseUp

on mouseDoubleUp
   wfFingerUp
end mouseDoubleUp

on mouseRelease
   wfFingerUp
end mouseRelease

----------------------------------------------------------------------
-- Layout: every control in its place for the window's size, out of the
-- notch and the home bar

command wfResized
   set the defaultStack to the short name of me
   wfLayout
end wfResized

-- The part of the screen under a notch, a rounded corner or the home bar:
-- the library's safe-area insets, 0 without it
private function wfInset pSide
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
end wfInset

command wfLayout
   local tW, tH
   set the defaultStack to the short name of me
   lock screen
   put the width of me into tW
   put the height of me into tH
   put wfInset("top") into sInsetT
   put wfInset("bottom") into sInsetB
   put wfInset("left") into sInsetL
   put wfInset("right") into sInsetR
   -- the world: the part of its 1600 x 900 units that is played on
   -- (from the Bloops waiting to the far side of the forts, 1440 across)
   -- in the window, its ground at the bottom
   put min(tW / 1440, tH / kWorldH) into sV
   put tW / 2 - 820 * sV into sOX
   put tH - kWorldH * sV into sOY
   -- the HUD and the screens: a point is sU points (on a phone held
   -- upright, as much as its width allows)
   put max(0.6, min(1.5, min(tW / 430, tH / 520))) into sU
   wfLayoutScene tW, tH
   set the rect of graphic "Shade" to 0, 0, tW, tH
   set the rect of graphic id sId["Flash"] to 0, 0, tW, tH
   wfLayoutHud tW, tH
   wfLayoutTitle tW, tH
   wfLayoutMap tW, tH
   wfLayoutHowto tW, tH
   wfLayoutPaused tW, tH
   wfLayoutClear tW, tH
   wfLayoutFail tW, tH
   wfLayoutNotice tW, tH
   wfDrawAll
   unlock screen
end wfLayout

-- The sky, the ground across the window and the scenery
private command wfLayoutScene pW, pH
   local tSkyW, tGround, i, tLeft, tX, tS, tDecos
   put sOY + kGroundY * sV into tGround
   put max(pW, kWorldW * sV) into tSkyW
   set the rect of image id sId["Sky"] to 0, round(tGround + 30 * sV - tSkyW / 2), round(tSkyW), round(tGround + 30 * sV)
   set the visible of image id sId["Sky"] to true
   put -sOX / sV into tLeft
   repeat with i = 1 to sCount["Ground"]
      put trunc(tLeft / 70) * 70 - 70 + (i - 1) * 70 into tX
      if sOX + tX * sV > pW then
         set the visible of image id sId["Ground"][i] to false
      else
         set the rect of image id sId["Ground"][i] to round(sOX + tX * sV), round(tGround), round(sOX + (tX + 70) * sV) + 1, round(tGround + 70 * sV) + 1
         set the visible of image id sId["Ground"][i] to true
      end if
   end repeat
   set the rect of graphic id sId["Dirt"] to 0, round(tGround + 70 * sV), pW, pH
   set the visible of graphic id sId["Dirt"] to true
   -- the scenery: x and size, along the ground behind the launcher and
   -- the forts
   put "40,64 160,50 560,70 720,48 880,60 1440,56 1560,72 -160,60 1700,64 1840,50" into tDecos
   repeat with i = 1 to sCount["Deco"]
      put word i of tDecos into tX
      if tX is empty then
         set the visible of image id sId["Deco"][i] to false
         next repeat
      end if
      put item 2 of tX into tS
      put item 1 of tX into tX
      set the rect of image id sId["Deco"][i] to round(sOX + (tX - tS / 2) * sV), round(tGround - tS * sV + 4 * sV), round(sOX + (tX + tS / 2) * sV), round(tGround + 4 * sV)
      set the visible of image id sId["Deco"][i] to true
   end repeat
end wfLayoutScene

-- A label: its size (points times sU), its rect from pL to pR with its
-- top at pT; returns its bottom
private function wfPlaceLabel pName, pSize, pL, pT, pR
   local tH
   set the textSize of field pName to max(9, round(pSize * sU))
   if the dontWrap of field pName then
      -- a line of one size, 4 points to spare above and below it (in
      -- its margins, so the line stays where it is): with none, a small
      -- size's tops were cut off in a browser (SCORE)
      put the textSize of field pName * 1.3 into tH
      set the margins of field pName to "0,4,0,4"
      set the rect of field pName to round(pL), round(pT) - 4, round(pR), round(pT + tH) + 4
      return round(pT + tH)
   end if
   set the rect of field pName to pL, pT, pR, pT + 100
   put the formattedHeight of field pName into tH
   set the rect of field pName to round(pL), round(pT), round(pR), round(pT + tH)
   return round(pT + tH)
end wfPlaceLabel

-- A button's lip, face, icon or label and its tap area
private command wfPlaceButton pName, pL, pT, pR, pB
   local tLip, tH, tS, tCX, tCY, tFH
   put round(pL) into pL
   put round(pT) into pT
   put round(pR) into pR
   put round(pB) into pB
   put pB - pT into tH
   put max(3, round(5 * sU)) into tLip
   set the rect of graphic (pName && "Lip") to pL, pT + tLip, pR, pB + tLip
   set the rect of graphic (pName && "Face") to pL, pT, pR, pB
   set the roundRadius of graphic (pName && "Lip") to round(min(tH, pR - pL) * 0.3)
   set the roundRadius of graphic (pName && "Face") to round(min(tH, pR - pL) * 0.3)
   put (pL + pR) / 2 into tCX
   put (pT + pB) / 2 into tCY
   if there is an image (pName && "Icon") then
      put round(tH * 0.62) into tS
      set the rect of image (pName && "Icon") to round(tCX - tS / 2), round(tCY - tS / 2), round(tCX - tS / 2) + tS, round(tCY - tS / 2) + tS
   end if
   if there is a field (pName && "Label") then
      set the textSize of field (pName && "Label") to max(10, round(tH * 0.42))
      put round(the textSize of field (pName && "Label") * 1.3) into tFH
      set the rect of field (pName && "Label") to pL, round(tCY - tFH / 2), pR, round(tCY - tFH / 2) + tFH
   end if
   set the rect of button pName to pL, pT, pR, pB + tLip
end wfPlaceButton

-- A panel's card and its shadow
private command wfPlacePanel pName, pL, pT, pR, pB
   set the rect of graphic (pName && "Shadow") to round(pL), round(pT + 8 * sU), round(pR), round(pB + 8 * sU)
   set the rect of graphic (pName && "Card") to round(pL), round(pT), round(pR), round(pB)
   set the roundRadius of graphic (pName && "Shadow") to round(22 * sU)
   set the roundRadius of graphic (pName && "Card") to round(22 * sU)
   set the lineSize of graphic (pName && "Card") to max(2, round(4 * sU))
end wfPlacePanel

-- An image of a screen at a size (points), in its middle at pX,pY
private command wfPlaceImage pName, pX, pY, pW, pH
   set the rect of image pName to round(pX - pW / 2), round(pY - pH / 2), round(pX - pW / 2) + round(pW), round(pY - pH / 2) + round(pH)
end wfPlaceImage

-- The panel's size for the window: as wide as pWant points, never wider
-- than the window, in its middle; returns left,right
private function wfPanelSpan pW, pWant
   local tWidth
   put min(pW - 24 - sInsetL - sInsetR, pWant * sU) into tWidth
   return round((pW - tWidth) / 2), round((pW + tWidth) / 2)
end wfPanelSpan

private command wfLayoutHud pW, pH
   local tT, tL, tR, tS
   put sInsetT + round(10 * sU) into tT
   put sInsetL + round(12 * sU) into tL
   put pW - sInsetR - round(14 * sU) into tR
   put round(46 * sU) into tS
   wfPlaceButton "Pause", tL, tT, tL + tS, tT + tS
   get wfPlaceLabel("Level Name", 18, tL + tS + 12 * sU, tT + tS / 2 - 12 * sU, tL + tS + 260 * sU)
   get wfPlaceLabel("Score Label", 11, tR - 260 * sU, tT + 2 * sU, tR)
   get wfPlaceLabel("Score", 28, tR - 260 * sU, tT + 17 * sU, tR)
   -- the hint under the HUD, across the window when it is narrow
   if pW < 700 then
      get wfPlaceLabel("Hint", 16, sInsetL + 16, tT + tS + 30 * sU, pW - sInsetR - 16)
   else
      get wfPlaceLabel("Hint", 16, max(tL + tS + 140 * sU, pW / 2 - 300 * sU), tT + tS + 14 * sU, min(tR - 140 * sU, pW / 2 + 300 * sU))
   end if
end wfLayoutHud

private command wfLayoutTitle pW, pH
   local tCX, tL, tY, tLogo, tW1, tH1, tW2, tH2, tS, tGap
   put pW / 2 into tCX
   put min(1.7 * sU, (pW - 40) / 300) into tLogo
   put 274 * tLogo into tW1
   put 65 * tLogo into tH1
   put 220 * tLogo into tW2
   put 65 * tLogo into tH2
   put sInsetT + max(16, 34 * sU) into tY
   wfPlaceImage "Logo Wobble", tCX, tY + tH1 / 2, tW1, tH1
   set the cBox of image "Logo Wobble" to the rect of image "Logo Wobble"
   set the cAngle of image "Logo Wobble" to empty
   wfPlaceImage "Logo Forts", tCX, tY + tH1 + tH2 / 2 - 6 * tLogo, tW2, tH2
   set the cBox of image "Logo Forts" to the rect of image "Logo Forts"
   set the cAngle of image "Logo Forts" to empty
   put tY + tH1 + tH2 + 10 * sU into tY
   put wfPlaceLabel("Tagline", 16, tCX - min(pW / 2 - 20, 300 * sU), tY, tCX + min(pW / 2 - 20, 300 * sU)) into tY
   put round(64 * sU) into tS
   put tY + 18 * sU into tY
   wfPlaceButton "Play", tCX - 110 * sU, tY, tCX + 110 * sU, tY + tS
   put tY + tS + 18 * sU into tY
   put round(50 * sU) into tS
   put round(16 * sU) into tGap
   if sLibrary and sWeb then
      put tCX - tS * 1.5 - tGap into tL
      set the visible of button "Title Full" to true
      set the visible of graphic "Title Full Face" to true
      set the visible of graphic "Title Full Lip" to true
      set the visible of image "Title Full Icon" to true
      wfPlaceButton "Title Full", tL + 2 * (tS + tGap), tY, tL + 2 * (tS + tGap) + tS, tY + tS
   else
      put tCX - tS - tGap / 2 into tL
      set the visible of button "Title Full" to false
      set the visible of graphic "Title Full Face" to false
      set the visible of graphic "Title Full Lip" to false
      set the visible of image "Title Full Icon" to false
   end if
   wfPlaceButton "Title Howto", tL, tY, tL + tS, tY + tS
   wfPlaceButton "Title Sound", tL + tS + tGap, tY, tL + tS + tGap + tS, tY + tS
   -- the stars won, and on a phone held upright the hint to turn it,
   -- under the buttons (the world is below them)
   put tY + tS + 16 * sU into tY
   put wfPlaceLabel("Records", 15, 20, tY, pW - 20) + 8 * sU into tY
   set the visible of field "Turn Hint" to pH > pW
   if pH > pW then
      get wfPlaceLabel("Turn Hint", 14, 24, tY, pW - 24)
   end if
end wfLayoutTitle

private command wfLayoutMap pW, pH
   local tSpan, tL, tR, tT, tY, tTile, tGap, i, k, tX, tStar, tS, tB, tPad
   put wfPanelSpan(pW, 620) into tSpan
   put item 1 of tSpan into tL
   put item 2 of tSpan into tR
   put round(18 * sU) into tPad
   put round(12 * sU) into tGap
   put min(round(86 * sU), trunc((tR - tL - 2 * tPad - 4 * tGap) / 5)) into tTile
   put round(52 * sU) into tS
   -- the panel's height, to sit it in the middle
   put tPad + 34 * sU + 22 * sU + 12 * sU + tTile + tTile * 0.3 + 18 * sU + tS + tPad into tB
   put max(sInsetT + 8, round((pH - tB) / 2)) into tT
   wfPlacePanel "Map", tL, tT, tR, tT + tB
   put wfPlaceLabel("Map Title", 26, tL, tT + tPad, tR) into tY
   put wfPlaceLabel("Map Sub", 15, tL, tY + 2 * sU, tR) + 12 * sU into tY
   put round((tL + tR) / 2 - (5 * tTile + 4 * tGap) / 2) into tX
   put round(tTile * 0.3) into tStar
   repeat with i = 1 to 5
      wfPlaceButton "Tile" && i, tX, tY, tX + tTile, tY + tTile
      wfPlaceImage "Tile" && i && "Lock", tX + tTile / 2, tY + tTile / 2, tTile * 0.5, tTile * 0.5
      repeat with k = 1 to 3
         wfPlaceImage "Tile" && i && "Star" && k, tX + tTile / 2 + (k - 2) * tStar, tY + tTile + tStar * 0.5 + 6 * sU, tStar, tStar
      end repeat
      add tTile + tGap to tX
   end repeat
   put tY + tTile + tTile * 0.3 + 18 * sU into tY
   wfPlaceButton "Map Home", tL + tPad, tY, tL + tPad + tS, tY + tS
   wfPlaceButton "Map Next", tR - tPad - tS, tY, tR - tPad, tY + tS
   wfPlaceButton "Map Prev", tR - tPad - 2 * tS - tGap, tY, tR - tPad - tS - tGap, tY + tS
   get wfPlaceLabel("Map Stars", 18, tL + tPad + tS + tGap, tY + tS / 2 - 12 * sU, (tL + tR) / 2 - 2 * sU)
   wfPlaceImage "Map Star", (tL + tR) / 2 + 16 * sU, tY + tS / 2, 28 * sU, 28 * sU
end wfLayoutMap

private command wfLayoutHowto pW, pH
   local tSpan, tL, tR, tT, tY, i, tPad, tIcon, tB, tTop
   put wfPanelSpan(pW, 620) into tSpan
   put item 1 of tSpan into tL
   put item 2 of tSpan into tR
   put round(18 * sU) into tPad
   put round(54 * sU) into tIcon
   -- measured from 0, then moved to the middle
   put 0 into tTop
   put wfPlaceLabel("Howto Title", 24, tL, tTop + tPad, tR) + 10 * sU into tY
   repeat with i = 1 to 3
      get wfPlaceLabel("Howto Text" && i, 15, tL + tPad + tIcon + 14 * sU, tY, tR - tPad)
      put max(it, tY + tIcon) + 10 * sU into tY
   end repeat
   put tY + 62 * sU + tPad into tB
   put max(sInsetT + 8, round((pH - tB) / 2)) into tT
   put wfPlaceLabel("Howto Title", 24, tL, tT + tPad, tR) + 10 * sU into tY
   repeat with i = 1 to 3
      get wfPlaceLabel("Howto Text" && i, 15, tL + tPad + tIcon + 14 * sU, tY, tR - tPad)
      wfPlaceImage "Howto Icon" && i, tL + tPad + tIcon / 2, max(tY + tIcon / 2, (tY + it) / 2), tIcon, tIcon
      put max(it, tY + tIcon) + 10 * sU into tY
   end repeat
   wfPlaceButton "Howto Go", (tL + tR) / 2 - 100 * sU, tY + 4 * sU, (tL + tR) / 2 + 100 * sU, tY + 56 * sU
   wfPlacePanel "Howto", tL, tT, tR, tT + tB
end wfLayoutHowto

private command wfLayoutPaused pW, pH
   local tSpan, tL, tR, tT, tY, tS, tGap, tB, tX
   put wfPanelSpan(pW, 360) into tSpan
   put item 1 of tSpan into tL
   put item 2 of tSpan into tR
   put round(52 * sU) into tS
   put round(16 * sU) into tGap
   put 20 * sU + 36 * sU + 16 * sU + 60 * sU + 20 * sU + tS + 24 * sU into tB
   put max(sInsetT + 8, round((pH - tB) / 2)) into tT
   wfPlacePanel "Paused", tL, tT, tR, tT + tB
   put wfPlaceLabel("Paused Title", 26, tL, tT + 20 * sU, tR) + 16 * sU into tY
   wfPlaceButton "Resume", (tL + tR) / 2 - 100 * sU, tY, (tL + tR) / 2 + 100 * sU, tY + 58 * sU
   put tY + 60 * sU + 20 * sU into tY
   put (tL + tR) / 2 - tS * 1.5 - tGap into tX
   wfPlaceButton "Pause Levels", tX, tY, tX + tS, tY + tS
   wfPlaceButton "Pause Restart", tX + tS + tGap, tY, tX + 2 * tS + tGap, tY + tS
   wfPlaceButton "Pause Sound", tX + 2 * (tS + tGap), tY, tX + 3 * tS + 2 * tGap, tY + tS
end wfLayoutPaused

private command wfLayoutClear pW, pH
   local tSpan, tL, tR, tT, tY, tS, tGap, tB, tX, tStar, tCX
   put wfPanelSpan(pW, 420) into tSpan
   put item 1 of tSpan into tL
   put item 2 of tSpan into tR
   put (tL + tR) / 2 into tCX
   put round(54 * sU) into tS
   put round(14 * sU) into tGap
   put round(min(76 * sU, pH / 7)) into tStar
   put 18 * sU + 38 * sU + tStar * 1.2 + 10 * sU + 40 * sU + 20 * sU + 16 * sU + tS + 22 * sU into tB
   put max(sInsetT + 8, round((pH - tB) / 2)) into tT
   wfPlacePanel "Clear", tL, tT, tR, tT + tB
   put wfPlaceLabel("Clear Title", 28, tL, tT + 18 * sU, tR) + 4 * sU into tY
   wfPlaceImage "Clear Star 1", tCX - tStar * 1.1, tY + tStar * 0.7, tStar, tStar
   wfPlaceImage "Clear Star 2", tCX, tY + tStar * 0.55, tStar * 1.2, tStar * 1.2
   wfPlaceImage "Clear Star 3", tCX + tStar * 1.1, tY + tStar * 0.7, tStar, tStar
   put tY + tStar * 1.2 + 10 * sU into tY
   put wfPlaceLabel("Clear Score", 30, tL, tY, tR) into tY
   put wfPlaceLabel("Clear Best", 15, tL, tY + 2 * sU, tR) + 14 * sU into tY
   put tCX - (2 * tS + 150 * sU + 2 * tGap) / 2 into tX
   wfPlaceButton "Clear Levels", tX, tY, tX + tS, tY + tS
   wfPlaceButton "Clear Replay", tX + tS + tGap, tY, tX + 2 * tS + tGap, tY + tS
   wfPlaceButton "Clear Next", tX + 2 * (tS + tGap), tY, tX + 2 * (tS + tGap) + 150 * sU, tY + tS
end wfLayoutClear

private command wfLayoutFail pW, pH
   local tSpan, tL, tR, tT, tY, tS, tGap, tB, tX, tCX
   put wfPanelSpan(pW, 420) into tSpan
   put item 1 of tSpan into tL
   put item 2 of tSpan into tR
   put (tL + tR) / 2 into tCX
   put round(54 * sU) into tS
   put round(14 * sU) into tGap
   -- measured, then placed
   put wfPlaceLabel("Fail Text", 15, tL + 20 * sU, 0, tR - 20 * sU) into tY
   put 18 * sU + 34 * sU + 8 * sU + 64 * sU + 8 * sU + tY + 18 * sU + tS + 22 * sU into tB
   put max(sInsetT + 8, round((pH - tB) / 2)) into tT
   wfPlacePanel "Fail", tL, tT, tR, tT + tB
   put wfPlaceLabel("Fail Title", 26, tL, tT + 18 * sU, tR) + 8 * sU into tY
   wfPlaceImage "Fail Grump", tCX, tY + 32 * sU, 64 * sU, 64 * sU
   put tY + 72 * sU into tY
   put wfPlaceLabel("Fail Text", 15, tL + 20 * sU, tY, tR - 20 * sU) + 18 * sU into tY
   put tCX - (tS + 180 * sU + tGap) / 2 into tX
   wfPlaceButton "Fail Levels", tX, tY, tX + tS, tY + tS
   wfPlaceButton "Fail Retry", tX + tS + tGap, tY, tX + tS + tGap + 180 * sU, tY + tS
end wfLayoutFail

private command wfLayoutNotice pW, pH
   local tSpan, tL, tR, tT, tY, tB
   put wfPanelSpan(pW, 460) into tSpan
   put item 1 of tSpan into tL
   put item 2 of tSpan into tR
   put wfPlaceLabel("Notice Text", 15, tL + 22 * sU, 0, tR - 22 * sU) into tY
   put 20 * sU + 30 * sU + 10 * sU + tY + 24 * sU into tB
   put max(sInsetT + 8, round((pH - tB) / 2)) into tT
   wfPlacePanel "Notice", tL, tT, tR, tT + tB
   put wfPlaceLabel("Notice Title", 22, tL, tT + 20 * sU, tR) + 10 * sU into tY
   get wfPlaceLabel("Notice Text", 15, tL + 22 * sU, tY, tR - 22 * sU)
end wfLayoutNotice

----------------------------------------------------------------------
-- For the tests: the clock in the test's hands

-- No loop, no sound, no buzz, a fixed seed, and the saved things in
-- pSaveFile
command wfTestBegin pSeed, pSaveFile
   set the defaultStack to the short name of me
   put true into sManual
   wfStopLoop
   if pSeed is a number then
      set the randomSeed to pSeed
   end if
   put pSaveFile into sSaveFile
   wfLoad
   put false into sSound
end wfTestBegin

-- The game, pSeconds on, a sixtieth of a second at a time
command wfTestStep pSeconds
   set the defaultStack to the short name of me
   lock screen
   repeat while pSeconds > 0.0001
      wfAdvance min(pSeconds, 1/60)
      subtract 1/60 from pSeconds
   end repeat
   unlock screen
end wfTestStep

-- A shot as a finger would make it: the Bloop pulled by pPullX,pPullY
-- units and let go (once it has hopped into the launcher)
command wfTestShoot pPullX, pPullY
   set the defaultStack to the short name of me
   if sMode is "aim" and sLoaded is not empty and sNow - sLoadAt < 0.4 then
      put sNow - 0.4 into sLoadAt
   end if
   wfLaunch pPullX, pPullY
end wfTestShoot

command wfTestTap
   set the defaultStack to the short name of me
   wfTrick
end wfTestTap

-- Every Grump popped (to reach the clear screen without aiming)
command wfTestPopGrumps
   local i
   set the defaultStack to the short name of me
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true and (sPKind[i] is "grump" or sPKind[i] is "boss") then
         wfBreak i, "broke"
      end if
   end repeat
end wfTestPopGrumps

-- How far the pieces have moved since the level settled, at most (units)
function wfDrift
   local i, tMax, tD
   put 0 into tMax
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true and sPStart[i] is not empty and sPKind[i] is not "bloop" then
         put sqrt((sPX[i] - item 1 of sPStart[i]) ^ 2 + (sPY[i] - item 2 of sPStart[i]) ^ 2) into tD
         put max(tMax, tD) into tMax
      end if
   end repeat
   return tMax
end wfDrift

-- How things are, a line each: name:value. One of the stack's
-- cJavascriptHandlers, so a page can ask it too (the check of the game's
-- page on the web site, tools/pages/check_wobble_forts_page.py)
function wfState
   local tOut, i, tPieces, tBloops, tAwake
   put 0 into tPieces
   put 0 into tBloops
   repeat with i = 1 to sCount["Piece"]
      if sPAlive[i] is true then
         if sPKind[i] is "bloop" then
            add 1 to tBloops
         else
            add 1 to tPieces
         end if
      end if
   end repeat
   put 0 into tAwake
   if sWorld is an integer and sWorld > 0 then
      put b2AwakeBodyCount(sWorld) into tAwake
   end if
   put "mode:" & sMode & return & "level:" & sLevel & return & "levels:" & sLevelCount & return & \
         "score:" & sScore & return & "grumps:" & sGrumps & return & "queue:" & sQueue & return & \
         "loaded:" & sLoaded & return & "shots:" & sShots & return & "pieces:" & tPieces & return & \
         "bloops:" & tBloops & return & "awake:" & tAwake & return & "now:" & round(sNow, 2) & return & \
         "drift:" & round(wfDrift(), 1) & return & "end:" & sEndKind & return & \
         "stars:" & wfTotalStars() & return & "levelstars:" & sStars[sLevel] & return & "best:" & sBest[sLevel] & return & \
         "physics:" & sPhysics & return & "library:" & sLibrary & return & "audio:" & sAudio & return & \
         "font:" & sFontLoaded & return & "sound:" & sSound & return & "howto:" & sSeenHowto & return & \
         "map:" & sMapLand & return & "view:" & round(sV, 3) & return & "fps:" & sFps & return & \
         "work:" & round(sWork, 2) & return & "draw:" & round(sDraw, 2) & return & "step:" & round(sStepMs, 2) & return & \
         "window:" & the width of this stack & comma & the height of this stack into tOut
   if sFlyer is an integer and sPAlive[sFlyer] is true then
      put return & "flyer:" & round(sPX[sFlyer]) & comma & round(sPY[sFlyer]) after tOut
   else
      put return & "flyer:" after tOut
   end if
   return tOut
end wfState
