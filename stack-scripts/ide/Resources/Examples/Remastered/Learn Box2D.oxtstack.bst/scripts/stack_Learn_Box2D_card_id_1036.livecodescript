script "stack_Learn_Box2D_card_id_1036"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Hinges" (id 1036)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 06 Hinges: the revolute joint
-- A joint ties two bodies together. A revolute joint pins them at one
-- point and lets them turn about it, as a hinge or an axle does. Each
-- body has its own anchor, in its own frame: the two anchors are the
-- same point in the world. The joint can have
--    a motor   that turns it at a speed, with a torque it may not pass
--    a limit   two angles it may not turn beyond

local sWorld, sSwing, sBob, sMill, sFlap, sSpeed

on labBuild
   local tPivot, tHub, tBlades, tFlapHub, tFlap
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- A pendulum: a static pivot, and a ball 1.8 metres to its right. The
   -- pivot's anchor is its middle; the ball's is 1.8 metres to ITS left
   put b2NewBody(sWorld, 0, -2.4, 7.6, 0, false, false) into tPivot
   get b2AddCircle(tPivot, 0, 0, 0.08, 1, 0.5, 0)
   labShow tPivot, "slate"
   put b2NewBody(sWorld, 2, -0.6, 7.6, 0, false, false) into sBob
   get b2AddCircle(sBob, 0, 0, 0.35, 2, 0.5, 0.2)
   labShow sBob, "sky"
   put b2RevoluteJoint(sWorld, tPivot, sBob, 0, 0, -1.8, 0, false) into sSwing
   labShowJoint sSwing
   -- A windmill: a cross of two boxes on one body, on a hub, turned by
   -- the joint's motor at 1.5 radians a second, with up to 400 N m
   put b2NewBody(sWorld, 0, 1.6, 4.2, 0, false, false) into tHub
   get b2AddCircle(tHub, 0, 0, 0.12, 1, 0.5, 0)
   put b2NewBody(sWorld, 2, 1.6, 4.2, 0, false, false) into tBlades
   get b2AddBox(tBlades, 1.5, 0.1, 1, 0.5, 0.1)
   b2PolyBegin
   b2PolyAddPoint -0.1, -1.5
   b2PolyAddPoint 0.1, -1.5
   b2PolyAddPoint 0.1, 1.5
   b2PolyAddPoint -0.1, 1.5
   get b2AddPolygon(tBlades, 1, 0.5, 0.1)
   labShow tBlades, "violet"
   labShow tHub, "slate"
   put b2RevoluteJoint(sWorld, tHub, tBlades, 0, 0, 0, 0, false) into sMill
   put 1.5 into sSpeed
   b2RevoluteEnableMotor sMill, true, sSpeed, 400
   -- A flap with a limit: it may turn from -0.6 to 0.3 radians (about
   -- -34 to 17 degrees), and no further
   put b2NewBody(sWorld, 0, -3.4, 2.2, 0, false, false) into tFlapHub
   get b2AddCircle(tFlapHub, 0, 0, 0.08, 1, 0.5, 0)
   put b2NewBody(sWorld, 2, -2.6, 2.2, 0, false, false) into tFlap
   get b2AddBox(tFlap, 0.8, 0.08, 1, 0.6, 0)
   labShow tFlap, "amber"
   labShow tFlapHub, "slate"
   put b2RevoluteJoint(sWorld, tFlapHub, tFlap, 0, 0, -0.8, 0, false) into sFlap
   b2RevoluteEnableLimit sFlap, true, -0.6, 0.3
   dropBalls
   labStart sWorld
end labBuild

-- The Push button: an impulse to the pendulum's ball
on pushSwing
   b2ApplyImpulse sBob, 6 * b2BodyMass(sBob), 0, true
end pushSwing

-- The Faster button: the motor's speed, up to 6 radians a second
on fasterMotor
   if abs(sSpeed) < 6 then
      put sSpeed * 1.5 into sSpeed
   end if
   b2RevoluteEnableMotor sMill, true, sSpeed, 400
end fasterMotor

-- The Reverse button
on reverseMotor
   put -sSpeed into sSpeed
   b2RevoluteSetMotorSpeed sMill, sSpeed
   b2JointWakeBodies sMill
end reverseMotor

-- The Motor button (on and off): off, the windmill turns only when pushed
on toggleMotor
   b2RevoluteEnableMotor sMill, not b2RevoluteIsMotorEnabled(sMill), sSpeed, 400
   b2JointWakeBodies sMill
end toggleMotor

-- The Drop balls button
on dropBalls
   local tIndex, tBody
   repeat with tIndex = 1 to 4
      put b2NewBody(sWorld, 2, random(60) / 10 - 3, 8.4, 0, false, false) into tBody
      get b2AddCircle(tBody, 0, 0, 0.22, 1, 0.4, 0.3)
      labShow tBody, "lime"
   end repeat
end dropBalls

on labStep
   labSay "pendulum" && round(b2RevoluteAngle(sSwing) * 180 / pi) & "  windmill:" && \
         labNum(b2RevoluteMotorSpeed(sMill), 1) && "rad/s," && round(b2RevoluteMotorTorque(sMill)) && "N m" & \
         "  flap" && round(b2RevoluteAngle(sFlap) * 180 / pi) && "(limit -34 to 17)"
end labStep
