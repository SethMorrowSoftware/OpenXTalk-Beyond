script "stack_Learn_Box2D_card_id_1033"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Shapes" (id 1033)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 03 Shapes
-- A shape gives a body its form, and the stuff it is made of. One body
-- can have many shapes, which then move as one. Each kind has its own
-- handler; the last three numbers are always density, friction and
-- bounce (restitution).

local sWorld, sLast

on labBuild
   local tRamp, tBump
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- Segments: lines with no inside, best on static bodies. Two make a
   -- ramp on the left
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tRamp
   get b2AddSegment(tRamp, -4.1, 3, -1.6, 1.4, 0.6, 0)
   get b2AddSegment(tRamp, -1.6, 1.4, -0.6, 1.4, 0.6, 0)
   labShow tRamp, "slate"
   -- A static triangle: a polygon, built a point at a time
   put b2NewBody(sWorld, 0, 2.4, 0, 0, false, false) into tBump
   b2PolyBegin
   b2PolyAddPoint -1, 0
   b2PolyAddPoint 1, 0
   b2PolyAddPoint 0, 0.9
   get b2AddPolygon(tBump, 1, 0.6, 0)
   labShow tBump, "slate"
   addCircle
   addBox
   addCapsule
   addPolygon
   labStart sWorld
end labBuild

-- A new dynamic body, high up, for the buttons below
private function newBody
   return b2NewBody(sWorld, 2, random(60) / 10 - 3, 8, random(314) / 100, false, false)
end newBody

-- The Circle button: a circle's middle (around the body) and radius
on addCircle
   put newBody() into sLast
   get b2AddCircle(sLast, 0, 0, 0.35, 1, 0.3, 0.3)
   labShow sLast, "sky"
end addCircle

-- The Box button: half its width, half its height
on addBox
   put newBody() into sLast
   get b2AddBox(sLast, 0.5, 0.25, 1, 0.5, 0.1)
   labShow sLast, "amber"
end addBox

-- The Capsule button: a line between two points, made fat by a radius
on addCapsule
   put newBody() into sLast
   get b2AddCapsule(sLast, -0.35, 0, 0.35, 0, 0.2, 1, 0.5, 0.1)
   labShow sLast, "teal"
end addCapsule

-- The Polygon button: 3 to 7 points around the body's middle. Box2D
-- makes a convex polygon of them (no dents), of 8 points at most
on addPolygon
   local tCount, tIndex, tAngle
   put newBody() into sLast
   put 2 + random(5) into tCount
   b2PolyBegin
   repeat with tIndex = 1 to tCount
      put tIndex * 2 * pi / tCount into tAngle
      b2PolyAddPoint 0.45 * cos(tAngle), 0.45 * sin(tAngle)
   end repeat
   get b2AddPolygon(sLast, 1, 0.5, 0.1)
   labShow sLast, "rose"
end addPolygon

-- The Two in one button: a hammer, a box and a circle on one body
on addHammer
   put newBody() into sLast
   get b2AddBox(sLast, 0.08, 0.5, 1, 0.5, 0.1)
   get b2AddCircle(sLast, 0, 0.55, 0.22, 4, 0.5, 0.1)
   labShow sLast, "lime"
end addHammer

-- Each step: the newest body's shapes, by their type numbers
on labStep
   local tCount, tIndex, tTypes
   put b2BodyShapeCount(sLast) into tCount
   repeat with tIndex = 1 to tCount
      put item (b2ShapeType(b2BodyShapeAt(tIndex)) + 1) of "circle,capsule,segment,polygon,chain" & " " after tTypes
   end repeat
   labSay "the newest body has" && tCount && "shape(s):" && tTypes & "  mass" && labNum(b2BodyMass(sLast), 2) && "kg"
end labStep
