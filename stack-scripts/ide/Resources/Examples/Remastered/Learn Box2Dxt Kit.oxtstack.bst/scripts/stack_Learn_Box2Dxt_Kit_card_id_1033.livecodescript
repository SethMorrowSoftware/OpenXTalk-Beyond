script "stack_Learn_Box2Dxt_Kit_card_id_1033"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Moves" (id 1033)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 03 Pushes and Spins: making things move
-- There are three ways to make a body go, and they feel different:
--
--    b2kPush       adds to its speed, in pixels a second, whatever it weighs
--    b2kImpulse    a kick: the same kick moves a heavy body less
--    b2kSetVelocity  sets its speed outright
--
-- and b2kSpin sets how fast it turns, in degrees a second. b2kExplode
-- kicks everything near a point away from it. The surface a body has
-- matters too: b2kSetBounce (how bouncy) and b2kSetFriction (how grippy).
-- Up is NEGATIVE y on the card: a push of 0, -450 goes up.

local sBall, sBoxes, sBouncy, sMoon

on labBuild
   local tRow, tCol
   -- The ball you move
   b2kSpawnBall 330, 500, 50, "251,146,60"
   put the result into sBall
   -- A tower of boxes
   put empty into sBoxes
   repeat with tRow = 0 to 4
      repeat with tCol = 0 to 1
         b2kSpawnBox 560 + tCol * 44, 580 - tRow * 42, 40, 40, "56,189,248"
         put the result & return after sBoxes
      end repeat
   end repeat
   put false into sBouncy
   put false into sMoon
end labBuild

on labStep
   local tVelocity
   put b2kVelocity(sBall) into tVelocity
   labSay "ball: speed" && round(b2kSpeed(sBall)) && "px/s   velocity" && round(item 1 of tVelocity) & "," & round(item 2 of tVelocity) && \
         "   turning" && round(b2kSpinRate(sBall)) && "deg/s"
end labStep

-- Jump: 450 pixels a second more, upward
on jump
   b2kPush sBall, 0, -450
end jump

-- Kick: the same kick for every box; the bottom ones are held by the rest
on kick
   local tBox
   repeat for each line tBox in sBoxes
      b2kImpulse tBox, -60, -40
   end repeat
end kick

on spin
   b2kSpin sBall, 900
end spin

-- Boom: a blast at the court's floor, 220 pixels wide
on boom
   b2kExplode 475, 600, 220, 1200
end boom

on bouncy
   put not sBouncy into sBouncy
   if sBouncy then
      b2kSetBounce sBall, 0.9
   else
      b2kSetBounce sBall, 0.1
   end if
end bouncy

-- Moon: a sixth of the gravity
on moon
   put not sMoon into sMoon
   if sMoon then
      b2kSetGravity 0, -1.6
   else
      b2kSetGravity 0, -10
   end if
end moon

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "bouncy"
         return sBouncy
      case "moon"
         return sMoon
   end switch
   return false
end labLit
