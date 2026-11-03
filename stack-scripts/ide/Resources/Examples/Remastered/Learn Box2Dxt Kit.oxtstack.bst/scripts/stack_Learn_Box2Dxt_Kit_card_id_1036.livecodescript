script "stack_Learn_Box2Dxt_Kit_card_id_1036"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Sprites" (id 1036)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 06 Sprite Sheets: many pictures in one image
-- A sprite sheet is one image with many small pictures in it: every pose
-- of a character, or every tile of a level. Games use them because one
-- image is quicker to load and easier to keep than fifty. The Kit cuts a
-- sheet into frames, each with a name, and a sprite is a picture on the
-- card that shows one frame at a time.
--
-- The two sheets here are images on this card, hidden: "AlienArt", the
-- green alien in its poses, and "TileArt", a grid of 64 by 64 tiles.
-- Both are Kenney's (https://kenney.nl), free to use (CC0).

-- The alien, its poses in order, the pose it shows, and the whole sheet
-- when "See the sheet" shows it
local sAlien, sPoses, sPose, sSheet

on labBuild
   local tIndex
   -- 1. A sheet with no grid (0 by 0), because the alien's pictures are
   --    not all the same size. Each one is named with where it is in the
   --    image: its left, its top, its width and its height, in pixels
   b2kSheetFromImage "alien", the long id of image "AlienArt", 0, 0
   b2kSheetAddFrame "alien", "stand", 69, 379, 66, 92
   b2kSheetAddFrame "alien", "walk1", 69, 193, 68, 93
   b2kSheetAddFrame "alien", "walk2", 0, 0, 70, 96
   b2kSheetAddFrame "alien", "jump", 69, 286, 67, 93
   b2kSheetAddFrame "alien", "duck", 0, 380, 69, 71
   b2kSheetAddFrame "alien", "hurt", 0, 288, 69, 92
   b2kSheetAddFrame "alien", "climb", 70, 0, 66, 92
   put "stand,walk1,walk2,jump,duck,hurt,climb" into sPoses
   put 1 into sPose
   -- 2. A sheet that IS a grid: squares of 64 by 64 pixels, with 1 pixel
   --    between them (the last two numbers: no border, a gap of 1). The
   --    Kit numbers the squares 1, 2, 3, ... across each row, then down
   b2kSheetFromImage "tiles", the long id of image "TileArt", 64, 64, empty, 0, 1
   -- 3. An animation: the two walk pictures, 6 a second, round and round
   b2kAnimDef "alien", "walk", "walk1,walk2", 6, true
   -- 4. The sprite: a picture on the card, showing the frame "stand", in
   --    the middle of the court. b2kAddBox gives it a body, so it falls,
   --    lands, and can be dragged
   b2kSpriteNew "alien", "stand", 475, 300
   put the result into sAlien
   b2kAddBox sAlien, true
   -- 5. A floor of tiles: sprites from the grid sheet (square 28 is a
   --    brown brick), each with a body that does not move (b2kAddStatic)
   repeat with tIndex = 0 to 5
      b2kSpriteNew "tiles", 28, 315 + tIndex * 64, 570
      b2kAddStatic the result
   end repeat
   put empty into sSheet
end labBuild

-- Each frame: what the alien shows, and how big that frame is
on labStep
   local tFrame
   if sSheet is not empty then
      exit labStep
   end if
   put b2kSpriteFrame(sAlien) into tFrame
   labSay "showing:" && tFrame & "   (" & item 1 of b2kSheetFrameSize("alien", tFrame) && "by" && item 2 of b2kSheetFrameSize("alien", tFrame) & " pixels)" & \
         "   alien sheet:" && b2kSheetFrames("alien") && "frames   tile sheet:" && b2kSheetFrames("tiles")
end labStep

-- Next picture: the next pose, by its name. b2kSpriteSetFrame stops an
-- animation that is playing
on nextPicture
   if sheetShown() then
      exit nextPicture
   end if
   put sPose mod the number of items of sPoses + 1 into sPose
   b2kSpriteSetFrame sAlien, item sPose of sPoses
end nextPicture

-- Walk: the animation made in labBuild
on walk
   if sheetShown() then
      exit walk
   end if
   b2kSpritePlay sAlien, "walk"
end walk

-- Flip: the same pictures, mirrored, so the alien faces the other way
on flipAlien
   if sheetShown() then
      exit flipAlien
   end if
   b2kSpriteFlipH sAlien, not b2kSpriteFlipped(sAlien)
end flipAlien

-- Drop a crate: square 10 of the tile sheet (wooden planks), with a box
-- body, from above the alien
on dropCrate
   if sheetShown() then
      exit dropCrate
   end if
   b2kSpriteNew "tiles", 10, random(300) + 320, 200
   b2kAddBox the result, true
end dropCrate

-- See the sheet: the whole alien sheet, smaller, with a line around each
-- frame named in labBuild, over the game. Again, to go back to it
on seeSheet
   local tPose, tRect, tObj, tScale, tLeft, tTop, tList
   if sSheet is not empty then
      put empty into sSheet
      labRestart
      exit seeSheet
   end if
   -- (the game's sprites go: Reset, or See the sheet again, makes them)
   b2kClear
   b2kPause
   put 0.7 into tScale
   put the left of graphic "Court" + 24 into tLeft
   put the top of graphic "Court" + 84 into tTop
   lock screen
   -- (a dark cover over the game, below the court's buttons)
   create graphic "sheet_cover"
   put it into tObj
   set the style of tObj to "rectangle"
   set the opaque of tObj to true
   set the lineSize of tObj to 0
   set the backgroundColor of tObj to "15,23,42"
   set the rect of tObj to the left of graphic "Court", the top of graphic "Court" + 40, \
         the right of graphic "Court", the bottom of graphic "Court"
   labKeep tObj
   create field "sheet_words"
   put it into tObj
   set the lockText of tObj to true
   set the showBorder of tObj to false
   set the opaque of tObj to false
   set the textColor of tObj to "226,232,240"
   set the textSize of tObj to 12
   set the rect of tObj to tLeft - 4, the top of graphic "Court" + 44, the right of graphic "Court" - 16, tTop - 4
   set the text of tObj to "The alien's sheet: one image of" && the formattedWidth of image "AlienArt" && "by" && \
         the formattedHeight of image "AlienArt" && "pixels. Each yellow box is a frame that labBuild named with b2kSheetAddFrame. " & \
         "Press See the sheet again to play."
   labKeep tObj
   clone image "AlienArt"
   put it into sSheet
   set the width of sSheet to round(the formattedWidth of image "AlienArt" * tScale)
   set the height of sSheet to round(the formattedHeight of image "AlienArt" * tScale)
   set the topLeft of sSheet to tLeft, tTop
   show sSheet
   labKeep sSheet
   repeat for each item tPose in sPoses
      put frameRect(tPose) into tRect
      create graphic ("sheet_" & tPose)
      put it into tObj
      set the style of tObj to "rectangle"
      set the opaque of tObj to false
      set the foregroundColor of tObj to "250,204,21"
      set the lineSize of tObj to 2
      set the rect of tObj to tLeft + round(item 1 of tRect * tScale), tTop + round(item 2 of tRect * tScale), \
            tLeft + round((item 1 of tRect + item 3 of tRect) * tScale), tTop + round((item 2 of tRect + item 4 of tRect) * tScale)
      labKeep tObj
      -- (its name in the box, and in the list to the right of the sheet,
      -- where it is and how big)
      create field ("sheet_tag_" & tPose)
      put it into tObj
      set the lockText of tObj to true
      set the showBorder of tObj to false
      set the opaque of tObj to true
      set the backgroundColor of tObj to "250,204,21"
      set the textColor of tObj to "15,23,42"
      set the textSize of tObj to 10
      set the margins of tObj to 1
      set the text of tObj to tPose
      set the rect of tObj to tLeft + round(item 1 of tRect * tScale) + 2, tTop + round(item 2 of tRect * tScale) + 2, \
            tLeft + round(item 1 of tRect * tScale) + 40, tTop + round(item 2 of tRect * tScale) + 16
      set the width of tObj to the formattedWidth of tObj + 2
      set the left of tObj to tLeft + round(item 1 of tRect * tScale) + 2
      labKeep tObj
      put tPose & tab & item 1 to 2 of tRect & tab & item 3 of tRect && "by" && item 4 of tRect & return after tList
   end repeat
   create field "sheet_list"
   put it into tObj
   set the lockText of tObj to true
   set the showBorder of tObj to false
   set the opaque of tObj to false
   set the textColor of tObj to "226,232,240"
   set the textSize of tObj to 11
   set the tabStops of tObj to "50,110"
   set the rect of tObj to tLeft + round(256 * tScale) + 24, tTop, the right of graphic "Court" - 10, tTop + 200
   set the text of tObj to "frame" & tab & "left, top" & tab & "size" & return & tList
   set the textStyle of line 1 of tObj to "bold"
   labKeep tObj
   unlock screen
end seeSheet

-- While the sheet shows, the game's sprites are gone: a button that
-- needs them says how to get them back instead
private function sheetShown
   if sSheet is empty then
      return false
   end if
   labSay "The sheet is showing: press See the sheet again to go back to the game.", true
   return true
end sheetShown

-- Where a frame is in the sheet: what labBuild gave b2kSheetAddFrame
-- (the Kit keeps it to itself, so the lesson keeps a copy to draw)
private function frameRect pPose
   switch pPose
      case "stand"
         return "69,379,66,92"
      case "walk1"
         return "69,193,68,93"
      case "walk2"
         return "0,0,70,96"
      case "jump"
         return "69,286,67,93"
      case "duck"
         return "0,380,69,71"
      case "hurt"
         return "0,288,69,92"
      default
         return "70,0,66,92"
   end switch
end frameRect

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "flipAlien"
         return b2kSpriteFlipped(sAlien)
      case "seeSheet"
         return sSheet is not empty
   end switch
   return false
end labLit
