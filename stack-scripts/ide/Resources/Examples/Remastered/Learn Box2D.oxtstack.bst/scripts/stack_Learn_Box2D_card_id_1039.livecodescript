script "stack_Learn_Box2D_card_id_1039"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Wheels" (id 1039)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 09 Wheels: the wheel joint
-- A wheel joint is made for vehicles. The wheel turns freely on its
-- axle, as on a hinge, and the axle slides up and down on a spring, as
-- in a slider: that is the suspension. Its motor drives the wheel; at a
-- speed of 0, the motor holds it, which is a brake.
-- Drive with the left and right arrow keys, or the buttons.

local sWorld, sCar, sWheels, sDrive, sKeyAt, sHertz

on labBuild
   local tBumps, tRamp, tWheel, tJoint, tX
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- Bumps on the floor: circles, half sunk; and a ramp at the right
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tBumps
   get b2AddCircle(tBumps, -0.6, -0.1, 0.3, 1, 0.8, 0)
   get b2AddCircle(tBumps, 0.2, -0.15, 0.3, 1, 0.8, 0)
   get b2AddCircle(tBumps, 0.9, -0.1, 0.25, 1, 0.8, 0)
   labShow tBumps, "slate"
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tRamp
   b2PolyBegin
   b2PolyAddPoint 1.9, 0
   b2PolyAddPoint 4.1, 0
   b2PolyAddPoint 4.1, 1.2
   get b2AddPolygon(tRamp, 1, 0.8, 0)
   labShow tRamp, "slate"
   -- The car's body
   put b2NewBody(sWorld, 2, -2.6, 1, 0, false, false) into sCar
   b2PolyBegin
   b2PolyAddPoint -0.85, -0.15
   b2PolyAddPoint 0.85, -0.15
   b2PolyAddPoint 0.7, 0.15
   b2PolyAddPoint 0.15, 0.45
   b2PolyAddPoint -0.55, 0.45
   b2PolyAddPoint -0.85, 0.15
   get b2AddPolygon(sCar, 1, 0.5, 0)
   labShow sCar, "rose"
   -- Two wheels. Each joint's anchor on the car is where the wheel's
   -- middle is; its axis is 0,1, the way the suspension moves
   put 4 into sHertz
   put empty into sWheels
   repeat for each item tX in "-0.55,0.55"
      put b2NewBody(sWorld, 2, -2.6 + tX, 0.5, 0, false, false) into tWheel
      get b2AddCircle(tWheel, 0, 0, 0.3, 1, 1.2, 0)
      labShow tWheel, "white"
      put b2WheelJoint(sWorld, sCar, tWheel, tX, -0.5, 0, 0, 0, 1, false) into tJoint
      b2WheelEnableSpring tJoint, true, sHertz, 0.7
      b2WheelEnableMotor tJoint, true, 0, 12
      labShowJoint tJoint
      put tJoint & comma after sWheels
   end repeat
   put 0 into sDrive
   labStart sWorld
end labBuild

-- Sets both wheels' motors: pDirection 1 is right, -1 left, 0 the brake
private command drive pDirection
   local tJoint
   put pDirection into sDrive
   repeat for each item tJoint in sWheels
      -- (a wheel rolling to the right turns clockwise: a minus speed)
      b2WheelEnableMotor tJoint, true, -12 * pDirection, 12
      b2JointWakeBodies tJoint
   end repeat
end drive

-- The buttons
on driveLeft
   drive -1
end driveLeft

on brake
   drive 0
end brake

on driveRight
   drive 1
end driveRight

-- The Softer and Stiffer buttons: the suspension's springs
on softer
   put max(1, sHertz / 1.5) into sHertz
   springs
end softer

on stiffer
   put min(12, sHertz * 1.5) into sHertz
   springs
end stiffer

private command springs
   local tJoint
   repeat for each item tJoint in sWheels
      b2WheelEnableSpring tJoint, true, sHertz, 0.7
      b2JointWakeBodies tJoint
   end repeat
end springs

-- The arrow keys drive while they are held: each key sent again while
-- held keeps it going; when they stop, labStep brakes
on arrowKey pKey
   if pKey is "left" then
      drive -1
      put the milliseconds into sKeyAt
   else if pKey is "right" then
      drive 1
      put the milliseconds into sKeyAt
   else
      pass arrowKey
   end if
end arrowKey

on labStep
   if sKeyAt is not empty and the milliseconds - sKeyAt > 600 then
      put empty into sKeyAt
      drive 0
   end if
   labSay "speed" && labNum(b2BodyVX(sCar), 1) && "m/s    motor torque" && \
         labNum(b2WheelMotorTorque(item 1 of sWheels), 1) && "N m    springs" && labNum(sHertz, 1) && "hertz"
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "driveRight"
         return sDrive is 1
      case "brake"
         return sDrive is 0
      case "driveLeft"
         return sDrive is -1
   end switch
   return false
end labLit
