script "stack_Learn_Box2D_card_id_1035"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Forces" (id 1035)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 05 Forces & Motion
-- You move a dynamic body by pushing it, or by telling it how fast to go:
--    b2ApplyForce          a push that lasts: give it every step
--    b2ApplyImpulse        a kick, all at once
--    b2ApplyTorque, b2ApplyAngularImpulse   the same, for turning
--    b2ApplyImpulseAt      a kick at a point: off the middle, it turns too
--    b2SetVelocity         a speed, at once, whatever the body weighs
-- A force in newtons moves 1 kilogram faster by 1 m/s every second.

local sWorld, sBall, sBox, sBalloon, sWind

on labBuild
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   put b2NewBody(sWorld, 2, -2, 0.4, 0, false, false) into sBall
   get b2AddCircle(sBall, 0, 0, 0.4, 1, 0.5, 0.3)
   labShow sBall, "sky"
   put b2NewBody(sWorld, 2, 1.5, 0.5, 0, false, false) into sBox
   get b2AddBox(sBox, 0.5, 0.5, 1, 0.6, 0.1)
   labShow sBox, "amber"
   -- A balloon: a body that gravity pulls up a little (a gravity scale
   -- below 0) and the air slows (linear damping)
   put b2NewBody(sWorld, 2, 3.2, 1, 0, false, false) into sBalloon
   get b2AddCircle(sBalloon, 0, 0, 0.35, 0.3, 0.3, 0.5)
   b2SetGravityScale sBalloon, -0.25
   b2SetLinearDamping sBalloon, 1.5
   labShow sBalloon, "rose"
   put false into sWind
   labStart sWorld
end labBuild

-- The Kick up button: an impulse up. An impulse changes a body's speed
-- by impulse / mass, so the ball's mass makes the kick the same for any
-- size of ball
on kickUp
   b2ApplyImpulse sBall, 0, 7 * b2BodyMass(sBall), true
end kickUp

-- The Wind button: a force to the right, which labStep gives every step
on toggleWind
   put not sWind into sWind
end toggleWind

-- The Spin button: an angular impulse turns the box
on spinBox
   b2ApplyAngularImpulse sBox, 2 * b2BodyMass(sBox), true
end spinBox

-- The Flip button: an impulse up, at the box's right side, so it turns
-- as it rises
on flipBox
   b2ApplyImpulseAt sBox, 0, 5 * b2BodyMass(sBox), b2BodyX(sBox) + 0.45, b2BodyY(sBox), true
end flipBox

-- The Throw button: a velocity, set: up and to the left, in m/s
on throwBall
   b2SetVelocity sBall, -4, 8
end throwBall

on labStep
   if sWind then
      -- (a force lasts one step: to keep pushing, push every step)
      b2ApplyForce sBall, 12, 0, true
      b2ApplyForce sBox, 12, 0, true
      b2ApplyForce sBalloon, 4, 0, true
   end if
   labSay "ball: speed" && labNum(sqrt(b2BodyVX(sBall) ^ 2 + b2BodyVY(sBall) ^ 2), 1) && "m/s" & \
         "    box: turning" && round(b2BodyAngularVelocity(sBox) * 180 / pi) && "degrees/s" & \
         "    wind:" && sWind
end labStep
