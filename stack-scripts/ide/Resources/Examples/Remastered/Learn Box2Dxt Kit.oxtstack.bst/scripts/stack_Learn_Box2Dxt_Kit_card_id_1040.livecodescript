script "stack_Learn_Box2Dxt_Kit_card_id_1040"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Sound" (id 1040)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 10 Sound: beeps and tunes, made by the script
-- The Kit can make sounds without any sound files. b2kToneMake writes
-- one from a list of notes, given as frequencies in hertz (440 is the
-- A above middle C; 0 is a rest), how long each note lasts, how loud,
-- and the shape of the wave: "sine" is soft, "square" is a retro beep.
-- Then b2kSound plays it by its name. The engine plays one sound at a
-- time: a new one cuts the one that is playing.
--
-- The card plays a "tock" when two things hit each other hard: the Kit
-- sends the card b2kContact when two bodies start to touch.

local sLastTock, sMuted

on labBuild
   local tIndex
   -- 1. The sounds: a name, the notes, milliseconds each, loudness, wave
   b2kToneMake "coin", "988,1319", 70, 50, "square"
   b2kToneMake "jump", "392,523,659", 45, 50, "square"
   b2kToneMake "tock", "220", 35, 40, "sine"
   b2kToneMake "tune", "523,659,784,659,523,0,392,0", 140, 40, "sine"
   put false into sMuted
   b2kSoundMute false
   put 0 into sLastTock
   -- 2. Things to bump
   repeat with tIndex = 1 to 4
      b2kSpawnBall 320 + tIndex * 70, 250, 40, "250,204,21"
      b2kSetBounce the result, 0.7
   end repeat
end labBuild

on labStep
   if b2kSoundStatus() is empty then
      labSay "sound: working" & "   muted:" && sMuted
   else
      labSay "sound: off on this computer (" & b2kSoundStatus() & ")"
   end if
end labStep

-- The Kit sends this when two bodies start to touch (an empty control
-- is a wall). Not more than one tock every tenth of a second
on b2kContact pA, pB
   if the milliseconds - sLastTock > 100 then
      put the milliseconds into sLastTock
      b2kSound "tock"
   end if
end b2kContact

on coin
   b2kSound "coin"
end coin

on jumpAll
   local tBall
   b2kSound "jump"
   repeat for each line tBall in b2kOverlapMoving(270, 162, 680, 602)
      b2kPush tBall, 0, -500
   end repeat
end jumpAll

-- The tune plays round and round until Stop or another sound
on tune
   b2kSoundLoop "tune"
end tune

on stopSound
   b2kSoundStop
end stopSound

on muteSound
   put not sMuted into sMuted
   b2kSoundMute sMuted
end muteSound

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "muteSound"
         return sMuted
   end switch
   return false
end labLit
