script "stack_Learn_Box2Dxt_Kit_card_id_1037"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Anim" (id 1037)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 07 Animation and GIFs: pictures that move by themselves
-- An animation is a list of frames from a sheet, shown one after the
-- other: b2kAnimDef names it, says how many frames a second, and whether
-- it goes round and round (loops) or plays once. b2kSpritePlay starts it
-- on a sprite. When one that plays once ends, the Kit can send you a
-- message (b2kSpriteOnFinish), so that you know when to do the next thing.
--
-- An animated GIF is simpler: the engine plays it by itself.
-- b2kSpriteFromGIF puts one on the card from a GIF file.
--
-- Sheets can come from files too. b2kSheetLoadAtlas reads a PNG and an
-- XML file that names each picture in it (Kenney's packs come that way).
-- This lesson writes its own picture and XML to files, to show how.

-- The alien, the GIF, how fast the alien animates, and what last finished
local sAlien, sGif, sFps, sFinished

on labBuild
   local tPath
   -- 1. The alien's sheet, as on Sprite Sheets: a name for each picture
   b2kSheetFromImage "alien", the long id of image "AlienArt", 0, 0
   b2kSheetAddFrame "alien", "stand", 69, 379, 66, 92
   b2kSheetAddFrame "alien", "walk1", 69, 193, 68, 93
   b2kSheetAddFrame "alien", "walk2", 0, 0, 70, 96
   b2kSheetAddFrame "alien", "jump", 69, 286, 67, 93
   b2kSheetAddFrame "alien", "duck", 0, 380, 69, 71
   b2kSheetAddFrame "alien", "hurt", 0, 288, 69, 92
   -- 2. Three animations: the name of the sheet, a name for the
   --    animation, its frames, frames a second, and true to loop
   b2kAnimDef "alien", "walk", "walk1,walk2", 6, true
   b2kAnimDef "alien", "hop", "duck,jump,jump,jump,stand", 8, false
   b2kAnimDef "alien", "ouch", "hurt,hurt,hurt,stand", 6, false
   -- 3. The alien, walking. When "hop" or "ouch" ends, the Kit sends
   --    alienDone (below)
   b2kSpriteNew "alien", "stand", 400, 400
   put the result into sAlien
   b2kAddBox sAlien, true
   b2kSpritePlay sAlien, "walk"
   b2kSpriteOnFinish sAlien, "alienDone"
   put 6 into sFps
   put empty into sFinished
   -- 4. A GIF, from a file: the lesson writes the GIF that is in this
   --    stack (image "WalkGif") to one first. It falls too: a GIF is an
   --    image, and b2kAddBox works on images
   put specialFolderPath("temporary") & "/learn-kit-walk.gif" into tPath
   put the text of image "WalkGif" into URL ("binfile:" & tPath)
   b2kSpriteFromGIF tPath, 580, 400
   put the result into sGif
   b2kAddBox sGif, true
end labBuild

-- Each frame: what the alien is playing, and the frame it shows
on labStep
   labSay "alien: playing" && quote & b2kSpriteAnim(sAlien) & quote && "at" && sFps && "frames a second, showing" && \
         b2kSpriteFrame(sAlien) & "   GIF: picture" && the currentFrame of sGif & sFinished
end labStep

-- The Kit sends this when an animation that does not loop has ended:
-- the sprite, and the animation's name. Then the alien walks again
on alienDone pSprite, pAnim
   put "   (" & pAnim && "finished)" into sFinished
   b2kSpritePlay pSprite, "walk"
end alienDone

on hop
   b2kSpritePlay sAlien, "hop"
   b2kPush sAlien, 0, -380
end hop

on ouch
   b2kSpritePlay sAlien, "ouch"
end ouch

-- Faster: the same animation, at a speed of your choosing (b2kSpriteFPS)
on faster
   if sFps < 24 then
      put sFps * 2 into sFps
   else
      put 3 into sFps
   end if
   b2kSpriteFPS sAlien, sFps
end faster

-- Stop and go: b2kSpriteStop holds the frame it is on; b2kSpritePlay
-- goes on. It works on the GIF too
on stopGo
   if b2kSpriteAnim(sAlien) is empty then
      b2kSpritePlay sAlien, "walk"
      b2kSpritePlay sGif
   else
      b2kSpriteStop sAlien
      b2kSpriteStop sGif
   end if
end stopGo

-- From files: the alien's picture as a PNG file, and an XML file that
-- names each frame in it, the way Kenney's packs do. b2kSheetLoadAtlas
-- reads both, and the frames are called by the names in the XML
on fromFiles
   local tFolder, tXml, tFrame, tCount
   put specialFolderPath("temporary") into tFolder
   put the text of image "AlienArt" into URL ("binfile:" & tFolder & "/learn-kit-alien.png")
   put "<TextureAtlas imagePath=" & quote & "learn-kit-alien.png" & quote & ">" & return into tXml
   repeat for each line tFrame in "climb,70,0,66,92" & return & "swim,0,96,70,92" & return & "jump,69,286,67,93"
      put "  <SubTexture name=" & quote & item 1 of tFrame & quote && \
            "x=" & quote & item 2 of tFrame & quote && "y=" & quote & item 3 of tFrame & quote && \
            "width=" & quote & item 4 of tFrame & quote && "height=" & quote & item 5 of tFrame & quote & "/>" & return after tXml
   end repeat
   put "</TextureAtlas>" & return after tXml
   put tXml into URL ("file:" & tFolder & "/learn-kit-alien.xml")
   b2kSheetLoadAtlas "fromfiles", tFolder & "/learn-kit-alien.png", tFolder & "/learn-kit-alien.xml"
   put the result into tCount
   -- A sprite of each frame the XML named, dropped from above
   repeat for each line tFrame in b2kSheetFrameNames("fromfiles")
      b2kSpriteNew "fromfiles", tFrame, 300 + random(350), 250
      b2kAddBox the result, true
   end repeat
   put "   (read" && tCount && "frames from a PNG and an XML file)" into sFinished
end fromFiles

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "stopGo"
         return b2kSpriteAnim(sAlien) is empty
   end switch
   return false
end labLit
