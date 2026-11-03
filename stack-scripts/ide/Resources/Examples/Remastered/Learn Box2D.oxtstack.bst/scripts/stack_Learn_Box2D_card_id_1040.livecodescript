script "stack_Learn_Box2D_card_id_1040"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Dragging" (id 1040)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 10 Dragging: the mouse joint
-- A mouse joint pulls one body toward a target point, like a spring,
-- but never harder than the force you allow. Move the target each step
-- and the body follows the mouse; it still collides with everything.
-- Every lesson lets you drag; this card does it in its own script, so you
-- can read it (cOwnDrag tells the Lab to leave it to this card).
-- Joints also report the force they hold with: pull the chain hard and
-- a link that holds more than its limit is destroyed: it breaks.

local sWorld, sGround, sGrab, sHertz, sLinks, sLimit, sMost

on labBuild
   local tTop, tPrev, tLink, tJoint, tIndex, tWeight, tBox
   put b2NewWorld(0, -10, true, true) into sWorld
   put labWalls(sWorld) into sGround
   -- A chain of six links from the ceiling, and a weight at its end
   put b2NewBody(sWorld, 0, 1.8, 8.4, 0, false, false) into tTop
   get b2AddBox(tTop, 0.4, 0.08, 1, 0.5, 0)
   labShow tTop, "slate"
   put tTop into tPrev
   put empty into sLinks
   repeat with tIndex = 1 to 6
      put b2NewBody(sWorld, 2, 1.8, 8.4 - tIndex * 0.5 + 0.25, 0, false, false) into tLink
      get b2AddBox(tLink, 0.07, 0.25, 1, 0.5, 0)
      labShow tLink, "amber"
      if tIndex is 1 then
         put b2RevoluteJoint(sWorld, tPrev, tLink, 0, 0, 0, 0.25, false) into tJoint
      else
         put b2RevoluteJoint(sWorld, tPrev, tLink, 0, -0.25, 0, 0.25, false) into tJoint
      end if
      put tJoint & comma after sLinks
      put tLink into tPrev
   end repeat
   put b2NewBody(sWorld, 2, 1.8, 5.05, 0, false, false) into tWeight
   get b2AddCircle(tWeight, 0, 0, 0.35, 2, 0.5, 0.1)
   labShow tWeight, "violet"
   put b2RevoluteJoint(sWorld, tPrev, tWeight, 0, -0.25, 0, 0.3, false) into tJoint
   put tJoint & comma after sLinks
   -- Boxes on the floor, to drag about and stack
   repeat with tIndex = 1 to 5
      put b2NewBody(sWorld, 2, -3.5 + tIndex * 0.8, 0.35, 0, false, false) into tBox
      get b2AddBox(tBox, 0.3, 0.3, 1, 0.6, 0)
      labShow tBox, "sky"
   end repeat
   if sHertz is empty then
      put 5 into sHertz
   end if
   if sLimit is empty then
      put 150 into sLimit
   end if
   put 0 into sMost
   labStart sWorld
end labBuild

-- A click on a body: a mouse joint between the walls' static body and it,
-- its target where the click is. Its last number, the most force it may
-- pull with, is 1000 times the body's mass
on mouseDown pButton
   local tX, tY, tBody
   put labMouseX() into tX
   put labMouseY() into tY
   put b2BodyAtPoint(sWorld, tX, tY) into tBody
   if pButton is 1 and tBody is not 0 and b2BodyType(tBody) is 2 then
      put b2MouseJoint(sWorld, sGround, tBody, tX, tY, sHertz, 0.7, 1000 * b2BodyMass(tBody)) into sGrab
      b2SetAwake tBody, true
      labShowJoint sGrab
   end if
   pass mouseDown
end mouseDown

-- Each step: the target goes where the mouse is, until the button is let
-- go; and each link's force is checked against the limit
on labStep
   local tJoint, tForce, tLeft
   if sGrab is not empty then
      if the mouse is up then
         b2DestroyJoint sGrab
         put empty into sGrab
      else
         b2MouseSetTarget sGrab, labMouseX(), labMouseY()
      end if
   end if
   put 0 into tForce
   repeat for each item tJoint in sLinks
      put sqrt(b2JointConstraintForceX(tJoint) ^ 2 + b2JointConstraintForceY(tJoint) ^ 2) into tForce
      put max(sMost, tForce) into sMost
      if tForce > sLimit then
         b2DestroyJoint tJoint
      else
         put tJoint & comma after tLeft
      end if
   end repeat
   put tLeft into sLinks
   labSay "the most a link has held:" && round(sMost) && "N    links break above" && sLimit && "N    grab:" && sHertz && "hertz"
end labStep

-- The Soft grab and Firm grab buttons: the mouse joint's spring
on softGrab
   put 1.5 into sHertz
end softGrab

on firmGrab
   put 8 into sHertz
end firmGrab

-- The Weaker and Stronger buttons: the force a link breaks at
on weaker
   put max(40, sLimit - 40) into sLimit
end weaker

on stronger
   put sLimit + 80 into sLimit
end stronger

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "softGrab"
         return sHertz is 1.5
      case "firmGrab"
         return sHertz is 8
   end switch
   return false
end labLit
