script "stack_Learn_Box2D_card_id_1037"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Springs" (id 1037)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 07 Rods, Springs and Welds
-- A distance joint keeps two points a length apart:
--    as it is   a rigid rod
--    a spring   it stretches and pulls back (b2DistanceEnableSpring)
--    a range    a rope: any length up to the longest (b2DistanceSetLengthRange)
-- A weld joint glues two bodies so that they move as one; with a
-- stiffness, it bends and springs back (b2WeldSetStiffness).

local sWorld, sSpring, sWeight, sHertz, sWelds, sBendy

on labBuild
   local tCeiling, tA, tB, tRope, tBall, tWall, tPrev, tPlank, tIndex, tWeld
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   put b2NewBody(sWorld, 0, 0, 8.4, 0, false, false) into tCeiling
   get b2AddBox(tCeiling, 4.1, 0.1, 1, 0.5, 0)
   labShow tCeiling, "slate"
   -- A spring: a box hung 2.2 metres below the ceiling, 1.5 times a
   -- second (hertz), with a little damping (0.1)
   put b2NewBody(sWorld, 2, -2.8, 5.5, 0, false, false) into sWeight
   get b2AddBox(sWeight, 0.35, 0.35, 1, 0.5, 0.1)
   labShow sWeight, "amber"
   put b2DistanceJoint(sWorld, tCeiling, sWeight, -2.8, -0.1, 0, 0.35, 2.2, false) into sSpring
   put 1.5 into sHertz
   b2DistanceEnableSpring sSpring, true, sHertz, 0.1
   labShowJoint sSpring
   -- A rod: two balls kept 1.3 metres apart, thrown in the air
   put b2NewBody(sWorld, 2, -0.9, 6, 0, false, false) into tA
   get b2AddCircle(tA, 0, 0, 0.25, 1, 0.5, 0.2)
   put b2NewBody(sWorld, 2, 0.3, 6.5, 0, false, false) into tB
   get b2AddCircle(tB, 0, 0, 0.25, 1, 0.5, 0.2)
   labShow tA, "sky"
   labShow tB, "sky"
   labShowJoint b2DistanceJoint(sWorld, tA, tB, 0, 0, 0, 0, 1.3, false)
   b2ApplyAngularImpulse tA, 0.5, true
   -- A rope: a ball that may hang up to 2.5 metres below the ceiling,
   -- and swing anywhere nearer. A spring of 0 hertz pulls not at all; the
   -- range does the work
   put b2NewBody(sWorld, 2, 0.8, 7.6, 0, false, false) into tBall
   get b2AddCircle(tBall, 0, 0, 0.3, 1, 0.5, 0.2)
   labShow tBall, "rose"
   put b2DistanceJoint(sWorld, tCeiling, tBall, 0.6, -0.1, 0, 0, 2.5, false) into tRope
   b2DistanceEnableSpring tRope, true, 0, 0
   b2DistanceSetLengthRange tRope, 0, 2.5
   labShowJoint tRope
   -- A diving board: four planks out from the wall at the right, each
   -- welded to the one before it
   put b2NewBody(sWorld, 0, 3.8, 2.4, 0, false, false) into tWall
   get b2AddBox(tWall, 0.3, 0.5, 1, 0.5, 0)
   labShow tWall, "slate"
   put tWall into tPrev
   put empty into sWelds
   repeat with tIndex = 1 to 4
      put b2NewBody(sWorld, 2, 3.5 - tIndex * 0.5 + 0.25, 2.6, 0, false, false) into tPlank
      get b2AddBox(tPlank, 0.25, 0.07, 1, 0.6, 0)
      labShow tPlank, "teal"
      if tIndex is 1 then
         put b2WeldJoint(sWorld, tPrev, tPlank, -0.3, 0.2, 0.25, 0, 0, false) into tWeld
      else
         put b2WeldJoint(sWorld, tPrev, tPlank, -0.25, 0, 0.25, 0, 0, false) into tWeld
      end if
      put tWeld & comma after sWelds
      put tPlank into tPrev
   end repeat
   put true into sBendy
   setBoard
   labStart sWorld
end labBuild

-- The board's welds: bendy (an angular spring of 2 hertz) or rigid (0)
private command setBoard
   local tWeld
   repeat for each item tWeld in sWelds
      if sBendy then
         b2WeldSetStiffness tWeld, 0, 0, 2, 0.3
      else
         b2WeldSetStiffness tWeld, 0, 0, 0, 0
      end if
      b2JointWakeBodies tWeld
   end repeat
end setBoard

-- The Stiffer and Softer buttons: the spring's hertz
on stiffer
   put min(8, sHertz * 1.5) into sHertz
   b2DistanceEnableSpring sSpring, true, sHertz, 0.1
   b2JointWakeBodies sSpring
end stiffer

on softer
   put max(0.4, sHertz / 1.5) into sHertz
   b2DistanceEnableSpring sSpring, true, sHertz, 0.1
   b2JointWakeBodies sSpring
end softer

-- The Pull down button
on pullWeight
   b2ApplyImpulse sWeight, 0, -6 * b2BodyMass(sWeight), true
end pullWeight

-- The Drop on board button: a heavy ball onto the end of the board
on dropOnBoard
   local tBody
   put b2NewBody(sWorld, 2, 1.9, 6, 0, false, false) into tBody
   get b2AddCircle(tBody, 0, 0, 0.3, 3, 0.5, 0.1)
   labShow tBody, "violet"
end dropOnBoard

-- The Rigid board button: bendy, then rigid, then bendy again
on toggleBoard
   put not sBendy into sBendy
   setBoard
end toggleBoard

private function boardName
   if sBendy then
      return "bendy"
   end if
   return "rigid"
end boardName

on labStep
   labSay "spring" && labNum(sHertz, 1) && "hertz: rest 2.2 m, now" && \
         labNum(b2DistanceCurrentLength(sSpring), 2) && "m    board:" && boardName()
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "toggleBoard"
         return not sBendy
   end switch
   return false
end labLit
