script "stack_Learn_Box2Dxt_Kit_card_id_1041"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Contacts" (id 1041)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 11 Contacts and Sensors: who touched what
-- Games need to know when things touch: the ball hit the target, the
-- player reached the coin. After each frame the Kit sends the card:
--
--    b2kContact pA, pB         two bodies started touching
--    b2kSensorEnter pS, pV     something came into a sensor
--
-- A sensor (b2kAddSensor) is a body that nothing bumps into: it only
-- notices. Coins and finish lines are sensors.
--
-- Layers decide what bumps into what. Layers are numbered 1, 2, 4, 8 and
-- so on, and every body starts on layer 1. b2kSetCategory puts a body on
-- a layer; b2kSetMask says which layers it bumps into. The boxes here are
-- on layer 2. The ghost balls bump into layer 1 only: the walls and the
-- other balls, but not the boxes. (The Kit can name layers too, as
-- b2kSetCategory tSlime, "enemies" does: see the Reference.)

local sTouches, sCoins, sGot, sTaken, sBoxes, sLayer

on labBuild
   local tIndex, tObj
   put 0 into sTouches
   put 2 into sLayer
   put 0 into sGot
   put empty into sTaken
   -- 1. Coins: yellow circles that are sensors
   put empty into sCoins
   repeat with tIndex = 1 to 5
      create graphic ("coin" & tIndex)
      put it into tObj
      set the style of tObj to "oval"
      set the opaque of tObj to true
      set the lineSize of tObj to 0
      set the backgroundColor of tObj to "250,204,21"
      set the rect of tObj to 280 + tIndex * 62, 420, 304 + tIndex * 62, 444
      labKeep tObj
      b2kAddSensor tObj, "ball"
      put tObj & return after sCoins
   end repeat
   -- 2. Boxes, on layer 2
   put empty into sBoxes
   repeat with tIndex = 0 to 3
      b2kSpawnBox 360 + tIndex * 80, 560, 50, 50, "56,189,248"
      put the result & return after sBoxes
      b2kSetCategory line -1 of sBoxes, 2
   end repeat
end labBuild

-- Two bodies started touching: count it
on b2kContact pA, pB
   add 1 to sTouches
end b2kContact

-- Something came into a sensor: if the sensor is a coin, it is taken.
-- (The coin goes in labStep: a control is not deleted while the Kit is
-- telling us about it)
on b2kSensorEnter pSensor, pVisitor
   if pSensor is among the lines of sCoins and pSensor is not among the lines of sTaken then
      put pSensor & return after sTaken
      add 1 to sGot
   end if
end b2kSensorEnter

on labStep
   local tCoin
   repeat for each line tCoin in sTaken
      if there is tCoin then
         b2kRemove tCoin
         delete tCoin
      end if
   end repeat
   put empty into sTaken
   labSay "touches so far:" && sTouches & "   touching this frame:" && b2kContactCount() & "   coins:" && sGot && "of 5"
end labStep

-- Drop balls: ordinary ones, which land on the boxes and take coins
on dropBalls
   local tIndex
   repeat with tIndex = 1 to 4
      b2kSpawnBall 320 + random(320), 230, 28, "251,146,60"
   end repeat
end dropBalls

-- Ghosts: balls whose mask is layer 1 only, so they fall through the
-- boxes, which are not on it
on ghosts
   local tIndex
   repeat with tIndex = 1 to 4
      b2kSpawnBall 340 + random(300), 230, 28, "196,181,253"
      b2kSetMask the result, 1
   end repeat
end ghosts

-- Solid boxes: the boxes on layer 1, so ghosts land on them too; again,
-- back on layer 2
on boxesSolid
   local tBox
   if sLayer is 1 then
      put 2 into sLayer
   else
      put 1 into sLayer
   end if
   repeat for each line tBox in sBoxes
      b2kSetCategory tBox, sLayer
   end repeat
end boxesSolid

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "boxesSolid"
         return sLayer is 1
   end switch
   return false
end labLit
