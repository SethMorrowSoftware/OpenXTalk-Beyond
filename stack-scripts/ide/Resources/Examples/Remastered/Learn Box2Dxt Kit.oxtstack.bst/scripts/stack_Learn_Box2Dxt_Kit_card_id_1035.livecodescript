script "stack_Learn_Box2Dxt_Kit_card_id_1035"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Keys" (id 1035)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 05 Keyboard: playing with the arrow keys
-- A game reads the keyboard once a frame, so that holding a key makes
-- something keep going. b2kInputOn starts the Kit reading it. Then:
--
--    b2kKeyIsDown("left")      is the key held now?
--    b2kKeyPressed("space")    did it go down this frame?
--
-- Better still, give keys a meaning: b2kBindAxis "move", "left,a",
-- "right,d" makes an axis, and b2kAxis("move") is -1, 0 or 1. b2kBindAction
-- "jump", "up,w,space" makes an action, and b2kActionPressed("jump") is
-- true in the frame it starts. A player can then use either set of keys,
-- and you change them in one place.

local sHero, sJump, sIce

on labBuild
   local tIndex
   b2kInputOn
   b2kBindAxis "move", "left,a", "right,d"
   b2kBindAction "jump", "up,w,space"
   -- The hero: a graphic 34 wide and 60 high, with a capsule body (a
   -- taller-than-wide control makes a capsule that stands up), that
   -- never falls over
   create graphic "Hero"
   put it into sHero
   set the opaque of sHero to true
   set the backgroundColor of sHero to "251,146,60"
   set the rect of sHero to 323, 510, 357, 570
   labKeep sHero
   b2kAddCapsule sHero, true
   b2kSetFixedRotation sHero, true
   -- Platforms: boxes made static
   repeat for each line tIndex in "430,500" & return & "560,430" & return & "430,360" & return & "580,280"
      b2kSpawnBox item 1 of tIndex, item 2 of tIndex, 110, 14, "148,163,184"
      b2kSetStatic the result
   end repeat
   put 520 into sJump
   put false into sIce
end labBuild

-- Each frame: left and right set the hero's speed across; jump pushes it
-- up, when it is standing on something (going neither up nor down)
on labStep
   local tMove, tVelocity
   put b2kAxis("move") into tMove
   put b2kVelocity(sHero) into tVelocity
   b2kSetVelocity sHero, tMove * 220, item 2 of tVelocity
   if b2kActionPressed("jump") and abs(item 2 of tVelocity) < 5 then
      b2kPush sHero, 0, -sJump
   end if
   labSay "keys held:" && b2kKeysHeld() & "   move:" && tMove & "   jump:" && b2kActionIsDown("jump")
end labStep

-- The arrow keys belong to the game on this card: without this, the
-- window would take them to go to the next lesson. (The Kit reads the
-- keys by itself, each frame, so nothing more is needed here)
on arrowKey pKey
end arrowKey

on higher
   if sJump < 700 then
      put 760 into sJump
   else
      put 520 into sJump
   end if
end higher

-- Ice: no friction, so the hero slides
on ice
   put not sIce into sIce
   if sIce then
      b2kSetFriction sHero, 0
   else
      b2kSetFriction sHero, 0.6
   end if
end ice

on dropBoxes
   local tIndex
   repeat with tIndex = 1 to 4
      b2kSpawnBox 320 + random(320), 220, 34, 34, "56,189,248"
   end repeat
end dropBoxes

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "higher"
         return sJump > 700
      case "ice"
         return sIce
   end switch
   return false
end labLit
