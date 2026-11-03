script "stack_Learn_Box2D_card_id_1038"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Sliders" (id 1038)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 08 Sliders: the prismatic joint
-- A prismatic joint lets one body slide along a line (an axis) on
-- another, and not turn: a lift in its shaft, a piston, a drawer. Like a
-- hinge, it can have a limit (how far it slides) and a motor (how fast,
-- with a force it may not pass); it can also have a spring.

local sWorld, sLift, sLiftJoint, sRam, sRamJoint, sLiftMove

on labBuild
   local tShaft, tBase, tIndex
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- The lift: a platform on a static base, sliding on the axis 0,1 (up),
   -- from 0 to 5.5 metres above where it starts
   put b2NewBody(sWorld, 0, -2.6, 0, 0, false, false) into tShaft
   put b2NewBody(sWorld, 2, -2.6, 0.4, 0, false, false) into sLift
   get b2AddBox(sLift, 0.9, 0.1, 2, 0.8, 0)
   labShow sLift, "violet"
   put b2PrismaticJoint(sWorld, tShaft, sLift, 0, 0.4, 0, 0, 0, 1, 0, false) into sLiftJoint
   b2PrismaticEnableLimit sLiftJoint, true, 0, 5.5
   b2PrismaticEnableMotor sLiftJoint, true, 0, 3000
   put "stop" into sLiftMove
   -- The piston: a ram that slides along the floor (axis 1,0), held back
   -- by a spring
   put b2NewBody(sWorld, 0, 0.4, 0, 0, false, false) into tBase
   get b2AddBox(tBase, 0.15, 0.6, 1, 0.5, 0)
   labShow tBase, "slate"
   put b2NewBody(sWorld, 2, 0.95, 0.3, 0, false, false) into sRam
   get b2AddBox(sRam, 0.4, 0.28, 2, 0.2, 0)
   labShow sRam, "amber"
   put b2PrismaticJoint(sWorld, tBase, sRam, 0.55, 0.3, 0, 0, 1, 0, 0, false) into sRamJoint
   b2PrismaticEnableLimit sRamJoint, true, 0, 2
   b2PrismaticEnableSpring sRamJoint, true
   b2PrismaticSetSpringHertz sRamJoint, 2
   b2PrismaticSetSpringDamping sRamJoint, 0.3
   repeat with tIndex = 1 to 3
      loadBoxes
   end repeat
   labStart sWorld
end labBuild

-- The Up, Stop and Down buttons: the motor's speed, in metres a second
on liftUp
   put "up" into sLiftMove
   b2PrismaticSetMotorSpeed sLiftJoint, 1.2
   b2JointWakeBodies sLiftJoint
end liftUp

on liftStop
   put "stop" into sLiftMove
   b2PrismaticSetMotorSpeed sLiftJoint, 0
end liftStop

on liftDown
   put "down" into sLiftMove
   b2PrismaticSetMotorSpeed sLiftJoint, -1.2
   b2JointWakeBodies sLiftJoint
end liftDown

-- The Fire button: a kick to the ram; the spring brings it back
on firePiston
   local tBall
   put b2NewBody(sWorld, 2, 2, 0.3, 0, false, false) into tBall
   get b2AddCircle(tBall, 0, 0, 0.3, 1, 0.3, 0.3)
   labShow tBall, "lime"
   b2ApplyImpulse sRam, 9 * b2BodyMass(sRam), 0, true
end firePiston

-- The Load boxes button: a box onto the lift
on loadBoxes
   local tBody
   put b2NewBody(sWorld, 2, -2.6 + (random(10) - 5) / 10, 7, 0, false, false) into tBody
   get b2AddBox(tBody, 0.25, 0.25, 1, 0.6, 0)
   labShow tBody, "sky"
end loadBoxes

on labStep
   -- (at either end, the motor stops: the limit holds it there)
   labSay "lift:" && labNum(b2PrismaticTranslation(sLiftJoint), 2) && "m up, at" && \
         labNum(b2PrismaticSpeed(sLiftJoint), 1) && "m/s, motor force" && round(b2PrismaticMotorForce(sLiftJoint)) && "N" & \
         "    ram:" && labNum(b2PrismaticTranslation(sRamJoint), 2) && "m"
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "liftUp"
         return sLiftMove is "up"
      case "liftStop"
         return sLiftMove is not "up" and sLiftMove is not "down"
      case "liftDown"
         return sLiftMove is "down"
   end switch
   return false
end labLit
