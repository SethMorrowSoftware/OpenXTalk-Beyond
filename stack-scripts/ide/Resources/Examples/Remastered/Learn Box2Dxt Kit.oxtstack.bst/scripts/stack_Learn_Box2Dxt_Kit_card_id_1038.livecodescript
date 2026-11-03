script "stack_Learn_Box2Dxt_Kit_card_id_1038"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Player" (id 1038)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 08 A Player: a character that runs, jumps, climbs and swims
-- Most games have one character that the player moves. The Kit has a
-- controller for it that does what platform games do: run and jump
-- with the arrow keys, a jump that goes higher while you hold the key,
-- ladders, water, and being hurt. It picks the animation for you, and
-- turns the character to face the way it runs.
--
--    b2kPlayerMake     makes the character: a body, and a sprite on it
--    b2kPlayerAnims    which animation is for standing, running, ...
--    b2kPlayerSet      its knobs: how fast, how high, ...
--    b2kPlayerAddLadder and b2kPlayerAddWater: places on the card
--
-- The arrow keys move it, Up or Space jumps, Down ducks. On a ladder,
-- Up and Down climb.

local sPlayer, sDouble, sFast

on labBuild
   local tObj
   -- 1. The alien's sheet again, under its own name, and smaller
   b2kSheetFromImage "hero", the long id of image "AlienArt", 0, 0
   b2kSheetAddFrame "hero", "stand", 69, 379, 66, 92
   b2kSheetAddFrame "hero", "walk1", 69, 193, 68, 93
   b2kSheetAddFrame "hero", "walk2", 0, 0, 70, 96
   b2kSheetAddFrame "hero", "jump", 69, 286, 67, 93
   b2kSheetAddFrame "hero", "duck", 0, 380, 69, 71
   b2kSheetAddFrame "hero", "hurt", 0, 288, 69, 92
   b2kSheetAddFrame "hero", "climb", 70, 0, 66, 92
   b2kSheetAddFrame "hero", "climb2", 135, 380, 66, 91
   b2kSheetAddFrame "hero", "swim", 0, 96, 70, 92
   b2kSheetScale "hero", 0.6
   b2kAnimDef "hero", "idle", "stand", 1, true
   b2kAnimDef "hero", "run", "walk1,walk2", 8, true
   b2kAnimDef "hero", "jump", "jump", 1, true
   b2kAnimDef "hero", "duck", "duck", 1, true
   b2kAnimDef "hero", "climb", "climb,climb2", 6, true
   b2kAnimDef "hero", "hurt", "hurt", 1, true
   b2kAnimDef "hero", "swim", "swim,jump", 4, true
   -- 2. The level: a pool on the left, a platform, and a ladder up to a
   --    high ledge on the right
   labArea "Pool", "56,189,248", 280, 520, 410, 602
   b2kPlayerAddWater 280, 510, 410, 602
   b2kSpawnBox 495, 470, 150, 16, "148,163,184"
   b2kSetStatic the result
   labArea "Ladder", "180,120,60", 578, 300, 604, 602
   b2kPlayerAddLadder 578, 290, 604, 602
   b2kSpawnBox 642, 316, 72, 16, "148,163,184"
   b2kSetStatic the result
   -- 3. The player: 30 wide and 54 high, with the "hero" sheet on it,
   --    and the animation for each thing it does
   b2kPlayerMake 470, 420, 30, 54, "hero"
   put the result into sPlayer
   b2kPlayerAnims "idle", "run", "jump", "jump", empty, "duck", "climb", "hurt", "swim"
   put false into sDouble
   put false into sFast
end labBuild

-- Each frame: what the controller says the player is doing
on labStep
   local tFacing
   if b2kPlayerFacing() is 1 then
      put "right" into tFacing
   else
      put "left" into tFacing
   end if
   labSay "doing:" && b2kPlayerState() & "   on the ground:" && b2kPlayerOnGround() & "   facing:" && \
         tFacing & "   in water:" && b2kPlayerInWater() & "   on a ladder:" && b2kPlayerInLadder()
end labStep

-- The arrow keys belong to the game on this card, not to the window
on arrowKey pKey
end arrowKey

-- A painted area for a zone (a zone itself is invisible): the pool's
-- water, see-through, and the ladder
private command labArea pName, pColor, pLeft, pTop, pRight, pBottom
   local tObj
   create graphic pName
   put it into tObj
   set the style of tObj to "rectangle"
   set the opaque of tObj to true
   set the lineSize of tObj to 0
   set the backgroundColor of tObj to pColor
   set the blendLevel of tObj to 55
   set the rect of tObj to pLeft, pTop, pRight, pBottom
   labKeep tObj
end labArea

-- Double jump: one more jump in the air (the airJumps knob)
on doubleJump
   put not sDouble into sDouble
   if sDouble then
      b2kPlayerSet "airJumps", 1
   else
      b2kPlayerSet "airJumps", empty
   end if
end doubleJump

-- Faster: run at 340 pixels a second, not 220
on runFaster
   put not sFast into sFast
   if sFast then
      b2kPlayerSet "moveSpeed", 340
   else
      b2kPlayerSet "moveSpeed", empty
   end if
end runFaster

-- Ouch: a hit from the right; the player pops away from it
on hurtPlayer
   b2kPlayerHurt item 1 of b2kPosition(sPlayer) + 40
end hurtPlayer

on startAgain
   b2kPlayerRespawn 470, 420
end startAgain

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "doubleJump"
         return sDouble
      case "runFaster"
         return sFast
   end switch
   return false
end labLit
