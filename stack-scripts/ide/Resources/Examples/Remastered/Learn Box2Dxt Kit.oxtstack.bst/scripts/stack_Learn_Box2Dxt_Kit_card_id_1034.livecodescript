script "stack_Learn_Box2Dxt_Kit_card_id_1034"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Joints" (id 1034)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 04 Joints: hinges, ropes, sliders and wheels
-- A joint ties two bodies together, or one body to the world:
--
--    b2kHinge   a pin they turn about (a door, a pendulum)
--    b2kRope    a fixed distance between their middles, springy with b2kSpring
--    b2kSlider  a line one slides along (a lift, a piston)
--    b2kWheel   a wheel on a sprung axle
--    b2kWeld    glued
--
-- A joint is invisible: this card draws a line for each, each frame.
-- Joints with a motor (b2kMotor, b2kSliderMotor, b2kWheelMotor) turn or
-- move by themselves, at a speed you give, with as much force as you allow.

local sPendulum, sMill, sMillJoint, sMillSpeed, sHook, sWeight, sRope, sLift, sLiftJoint
local sCart, sWheels, sWheelJoints, sLines, sDirection

on labBuild
   local tObj
   -- A pendulum: a ball pinned to the world (empty) at 330, 250
   b2kSpawnBall 410, 330, 36, "251,146,60"
   put the result into sPendulum
   b2kHinge sPendulum, empty, 330, 250
   -- A windmill: a long box pinned at its middle, with a motor
   b2kSpawnBox 580, 330, 150, 14, "167,139,250"
   put the result into sMill
   b2kHinge sMill, empty, 580, 330
   put the result into sMillJoint
   put 90 into sMillSpeed
   b2kMotor sMillJoint, sMillSpeed, 5000
   -- A rope: a hook that never moves, and a weight on a rope from it
   create graphic "Hook"
   put it into sHook
   set the style of sHook to "oval"
   set the opaque of sHook to true
   set the backgroundColor of sHook to "148,163,184"
   set the rect of sHook to 445, 245, 455, 255
   labKeep sHook
   b2kAddStatic sHook
   b2kSpawnBox 450, 370, 40, 40, "56,189,248"
   put the result into sWeight
   b2kRope sHook, sWeight
   put the result into sRope
   -- A lift: a platform that slides up and down (90 degrees), with a motor
   b2kSpawnBox 640, 520, 70, 12, "52,211,153"
   put the result into sLift
   b2kSlider sLift, empty, 90
   put the result into sLiftJoint
   b2kSliderLimit sLiftJoint, -150, 60
   -- A cart: a box with two wheels on sprung axles
   b2kSpawnBox 360, 515, 110, 22, "244,114,182"
   put the result into sCart
   put empty into sWheels
   put empty into sDirection
   put empty into sWheelJoints
   repeat for each item tObj in "325,395"
      b2kSpawnBall tObj, 530, 30, "71,85,105"
      put the result & return after sWheels
      b2kWheel sCart, the result, tObj, 530
      put the result & return after sWheelJoints
      -- (a firm spring: 6 bounces a second, settling quickly)
      b2kWheelSpring line -1 of sWheelJoints, 6, 0.7
   end repeat
   -- The lines that show the pendulum's rod and the rope
   put empty into sLines
   repeat for each item tObj in "rod,rope"
      create graphic ("joint_" & tObj)
      set the style of it to "line"
      set the foregroundColor of it to "226,232,240"
      set the lineSize of it to 2
      labKeep it
      put the long id of it into sLines[tObj]
   end repeat
end labBuild

-- Each frame: the lines, and the numbers
on labStep
   set the points of sLines["rod"] to "330,250" & return & b2kPosition(sPendulum)
   if sRope is not empty then
      set the points of sLines["rope"] to "450,250" & return & b2kPosition(sWeight)
   end if
   labSay "windmill" && (round(b2kHingeAngle(sMillJoint)) mod 360 + 360) mod 360 & numToCodepoint(176) && \
         "  lift" && round(b2kSliderPos(sLiftJoint)) && "px   rope" && ropeWords() && "   cart" && round(b2kSpeed(sCart)) && "px/s"
end labStep

private function ropeWords
   if sRope is empty then
      return "cut"
   end if
   return round(b2kRopeLength(sRope)) && "px"
end ropeWords

on faster
   if abs(sMillSpeed) < 700 then
      put sMillSpeed * 2 into sMillSpeed
   end if
   b2kMotor sMillJoint, sMillSpeed, 5000
end faster

on reverse
   put -sMillSpeed into sMillSpeed
   b2kMotor sMillJoint, sMillSpeed, 5000
end reverse

-- Lift: up and then down, 120 pixels a second. (A body that has stopped
-- is asleep, and a motor does not wake it: b2kSetVelocity does)
on liftUp
   b2kSetVelocity sLift, 0, 0
   if b2kSliderPos(sLiftJoint) > -100 then
      b2kSliderMotor sLiftJoint, -120, 2000
   else
      b2kSliderMotor sLiftJoint, 120, 2000
   end if
end liftUp

-- Springy: the rope stretches, 2 times a second, a little damped
on springy
   if sRope is not empty then
      b2kSpring sRope, 2, 0.1
   end if
end springy

on cutRope
   if sRope is not empty then
      b2kRemoveJoint sRope
      put empty into sRope
      set the points of sLines["rope"] to empty
   end if
end cutRope

-- Drive: both wheels turn, 600 degrees a second, to the right; Drive
-- again goes back to the left
on drive
   local tJoint
   if sDirection is 1 then
      put -1 into sDirection
   else
      put 1 into sDirection
   end if
   -- (the cart and its wheels may be asleep: setting a speed wakes them)
   b2kSetVelocity sCart, 0, 0
   repeat for each line tJoint in sWheels
      b2kSetVelocity tJoint, 0, 0
   end repeat
   repeat for each line tJoint in sWheelJoints
      b2kWheelMotor tJoint, -600 * sDirection, 400
   end repeat
end drive

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "reverse"
         return sMillSpeed < 0
   end switch
   return false
end labLit
