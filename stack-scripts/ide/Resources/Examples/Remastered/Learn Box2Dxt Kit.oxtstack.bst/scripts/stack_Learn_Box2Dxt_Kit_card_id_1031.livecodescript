script "stack_Learn_Box2Dxt_Kit_card_id_1031"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Quick" (id 1031)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 01 Quick Start: a world in a few lines
-- The Kit's world is like Box2D's (Learn Box2D shows it), but you talk to
-- it in pixels: a ball 60 pixels across, at 400, 260 on the card. The
-- Kit turns that into metres for Box2D, and moves the ball's graphic to
-- where Box2D says it is, 60 times a second.
--
-- The Lab has made the world for this court and started it. On a card
-- of your own, one line does that for the whole card:
--
--    on openCard
--       b2kQuickStart
--       b2kSpawnBall 200, 80, 50
--    end openCard
--    on mouseDown
--       get b2kGrab(the mouseH, the mouseV)
--    end mouseDown
--    on mouseUp
--       b2kRelease
--    end mouseUp
--    on closeCard
--       b2kStop
--    end closeCard

-- The colours the shapes are made in, a line each
local sColors

on labBuild
   put "251,146,60" & return & "56,189,248" & return & "167,139,250" & return & \
         "52,211,153" & return & "244,114,182" & return & "250,204,21" into sColors
   -- A ball, 60 pixels across, its middle at 400, 260
   b2kSpawnBall 400, 260, 60, line 1 of sColors
   -- A box, 80 wide and 50 high
   b2kSpawnBox 520, 240, 80, 50, line 2 of sColors
   -- A capsule (a pill), 90 long and 30 thick
   b2kSpawnCapsule 470, 320, 90, 30, line 3 of sColors
end labBuild

on labStep
   labSay "bodies:" && b2kBodyCount() & "   still moving:" && b2kAwakeCount()
end labStep

on addBall
   b2kSpawnBall 300 + random(350), 230, 30 + random(40), any line of sColors
end addBall

on addBox
   b2kSpawnBox 300 + random(350), 230, 30 + random(60), 30 + random(40), any line of sColors
end addBox

on addCapsule
   b2kSpawnCapsule 300 + random(350), 230, 60 + random(60), 24 + random(16), any line of sColors
end addCapsule

-- Rain: ten of them, of every kind
on rain
   local tIndex
   repeat with tIndex = 1 to 10
      switch tIndex mod 3
         case 0
            addBall
            break
         case 1
            addBox
            break
         default
            addCapsule
      end switch
   end repeat
end rain

-- Clear: everything that moves goes; the walls stay
on clearAll
   b2kClear
end clearAll
