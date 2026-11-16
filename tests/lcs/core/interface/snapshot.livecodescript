script "CoreInterfaceSnapshot"
-- Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
-- (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
-- Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

/*
Copyright (C) 2015 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

on _TestImportScreenSnapshotFromRectHandler
    import snapshot from rectangle 100,100,500,400
    
    TestAssert "long id of new image is long id of it",  the long id of it is the long id of the last image
    TestAssertBroken "long id of image is it", it is the long id of the last image
end _TestImportScreenSnapshotFromRectHandler

on TestImportScreenSnapshotFromRectNoUI
   TestSkipIf "ui"
   TestSkipIf "platform", "HTML5"
   TestAssertThrow "should now throw an error", "_TestImportScreenSnapshotFromRectHandler",\
        the long id of me, "EE_SNAPSHOT_FAILED"
end TestImportScreenSnapshotFromRectNoUI

on TestImportScreenSnapshotFromRectUI
    TestSkipIfNot "ui"
    TestSkipIf "environment", "server"
    TestSkipIf "platform", "HTML5"

    _TestImportScreenSnapshotFromRectHandler
end TestImportScreenSnapshotFromRectUI

on _TestImportSnapshotFromStackHandler
    create stack "Untitled 1"

    import snapshot from window the windowId of stack "Untitled 1"
    TestAssert "long id of new image is long id of it",  the long id of it is the long id of the last image
    TestAssertBroken "long id of image is it", it is the long id of the last image
end _TestImportSnapshotFromStackHandler

on TestImportSnapshotFromStack
    if the environment is not "command line" then
        return "SKIP TEST"
    end if
    TestAssertThrow "should now throw an error", "_TestImportSnapshotFromStackHandler",\
        the long id of me, "EE_SNAPSHOT_FAILED"
end TestImportSnapshotFromStack

on TestImportSnapshotFromObject
    create button "b1"

    import snapshot from button "b1"

    TestAssert "long id of new image is long id of it",  the long id of it is the long id of the last image
    TestAssert "long id of image is it", it is the long id of the last image
end TestImportSnapshotFromObject

on TestImportSnapshotFromRectOfObject
   create field "field 1"
   set the rect of field "field 1" to 0,0,100,100
   
   import snapshot from rectangle 0,0,100,100 of field "field 1"
   TestAssert "long id of new image is long id of it",  the long id of it is the long id of the last image
   TestAssert "long id of image is it", it is the long id of the last image
end TestImportSnapshotFromRectOfObject


-- A group whose snapshot would take more than 4 GiB (here about 40,000
-- pixels square) used to crash the engine: the bitmap's size wrapped round
-- to a small buffer that drawing then wrote far past. Now the export and
-- the import throw instead.
private command _TestMakeHugeGroup
   -- The test stack is not open, so the images are made in the group
   -- rather than selected and grouped.
   create group "huge"
   create image "huge 1" in group "huge"
   set the rect of image "huge 1" to -20000,-20000,-19900,-19900
   create image "huge 2" in group "huge"
   set the rect of image "huge 2" to 19900,19900,20000,20000
end _TestMakeHugeGroup

on _TestExportHugeGroupHandler
   local tData
   export snapshot from group "huge" to tData as PNG
end _TestExportHugeGroupHandler

on _TestImportHugeGroupHandler
   import snapshot from group "huge"
end _TestImportHugeGroupHandler

on TestSnapshotOfHugeGroup
   _TestMakeHugeGroup
   TestAssert "the group is too big for a 4 GiB bitmap", \
         the width of group "huge" * the height of group "huge" > 2 ^ 30
   TestAssertThrow "export snapshot of a huge group throws", \
         "_TestExportHugeGroupHandler", the long id of me, "EE_SNAPSHOT_TOOBIG"
   TestAssertThrow "import snapshot of a huge group throws", \
         "_TestImportHugeGroupHandler", the long id of me, "EE_SNAPSHOT_TOOBIG"
end TestSnapshotOfHugeGroup

-- Ordinary exports of a group of images, in each format, to a variable
-- and to a file, as forum users do. They run on every platform the
-- engine tests run on, so a crash or a wrong size in the snapshot or an
-- encoder shows up there.

-- An image pWidth by pHeight of one opaque colour (pRGB is "r,g,b").
private command _TestMakeSolidImage pName, pWidth, pHeight, pRGB, pGroup
   local tPixel, tData
   put numToByte(255) & numToByte(item 1 of pRGB) & \
         numToByte(item 2 of pRGB) & numToByte(item 3 of pRGB) into tPixel
   repeat pWidth * pHeight times
      put tPixel after tData
   end repeat
   if pGroup is empty then
      create image pName
   else
      create image pName in group pGroup
   end if
   set the width of image pName to pWidth
   set the height of image pName to pHeight
   set the imageData of image pName to tData
end _TestMakeSolidImage

-- A group of three images side by side, 300 by 100: red, green, and a
-- blue one turned by 30 degrees and drawn with the best resize quality.
private command _TestMakeImageGroup
   create group "mixed"
   _TestMakeSolidImage "red", 100, 100, "255,0,0", "mixed"
   set the topLeft of image "red" to 0,0
   _TestMakeSolidImage "green", 100, 100, "0,255,0", "mixed"
   set the topLeft of image "green" to 100,0
   _TestMakeSolidImage "blue", 60, 60, "0,0,255", "mixed"
   set the resizeQuality of image "blue" to "best"
   set the angle of image "blue" to 30
   set the loc of image "blue" to 250,50
end _TestMakeImageGroup

-- The width and height of the image held in pData.
private function _TestImageSize pData
   local tSize
   create image "probe"
   set the text of image "probe" to pData
   put the formattedWidth of image "probe" & "," & the formattedHeight of image "probe" into tSize
   delete image "probe"
   return tSize
end _TestImageSize

on TestExportSnapshotOfGroupToVariable
   local tData, tGroupSize
   _TestMakeImageGroup
   put the width of group "mixed" & "," & the height of group "mixed" into tGroupSize

   export snapshot from group "mixed" to tData as PNG
   TestAssert "PNG starts with the PNG signature", \
         byte 1 to 8 of tData is (numToByte(137) & "PNG" & numToByte(13) & numToByte(10) & numToByte(26) & numToByte(10))
   TestAssert "PNG is the size of the group", _TestImageSize(tData) is tGroupSize

   export snapshot from group "mixed" to tData as JPEG
   TestAssert "JPEG starts with the JPEG signature", \
         byte 1 to 3 of tData is (numToByte(255) & numToByte(216) & numToByte(255))
   TestAssert "JPEG is the size of the group", _TestImageSize(tData) is tGroupSize

   export snapshot from group "mixed" to tData as GIF
   TestAssert "GIF starts with the GIF signature", byte 1 to 3 of tData is "GIF"
   TestAssert "GIF is the size of the group", _TestImageSize(tData) is tGroupSize

   export snapshot from group "mixed" to tData as BMP
   TestAssert "BMP starts with the BMP signature", byte 1 to 2 of tData is "BM"
end TestExportSnapshotOfGroupToVariable

on TestExportSnapshotOfGroupColors
   local tData
   _TestMakeImageGroup
   export snapshot from group "mixed" to tData as PNG

   create image "check"
   set the text of image "check" to tData
   put the imageData of image "check" into tData
   -- The pixel at x, y (from 0) starts at byte (y * width + x) * 4 + 1:
   -- 0 or alpha, then red, green and blue.
   local tWidth, tOffset
   put the formattedWidth of image "check" into tWidth
   put (50 * tWidth + 50) * 4 into tOffset
   TestAssert "the red image is red", \
         byteToNum(byte tOffset + 2 of tData) > 200 and byteToNum(byte tOffset + 3 of tData) < 50
   put (50 * tWidth + 150) * 4 into tOffset
   TestAssert "the green image is green", \
         byteToNum(byte tOffset + 3 of tData) > 200 and byteToNum(byte tOffset + 2 of tData) < 50
   put (50 * tWidth + 250 - the left of group "mixed") * 4 into tOffset
   TestAssert "the turned blue image is blue at its centre", \
         byteToNum(byte tOffset + 4 of tData) > 200 and byteToNum(byte tOffset + 2 of tData) < 50
end TestExportSnapshotOfGroupColors

on TestExportSnapshotOfGroupToFile
   local tGroupSize, tPath, tData, tFormat
   _TestMakeImageGroup
   put the width of group "mixed" & "," & the height of group "mixed" into tGroupSize

   repeat for each item tFormat in "PNG,JPEG,GIF"
      put the tempName into tPath
      -- The format after "as" is a keyword, not an expression.
      switch tFormat
         case "PNG"
            export snapshot from group "mixed" to file tPath as PNG
            break
         case "JPEG"
            export snapshot from group "mixed" to file tPath as JPEG
            break
         case "GIF"
            export snapshot from group "mixed" to file tPath as GIF
            break
      end switch
      TestAssert tFormat && "file is written", there is a file tPath
      put url ("binfile:" & tPath) into tData
      TestAssert tFormat && "file is the size of the group", _TestImageSize(tData) is tGroupSize
      delete file tPath
   end repeat
end TestExportSnapshotOfGroupToFile

on TestExportSnapshotOfGroupWithEffectsAtSize
   local tData
   _TestMakeImageGroup
   set the dropShadow["color"] of image "red" to "0,0,0"

   export snapshot from group "mixed" with effects to tData as PNG
   TestAssert "with effects makes an image", _TestImageSize(tData) is not "0,0"

   export snapshot from group "mixed" at size 150,50 to tData as PNG
   TestAssert "at size makes an image of that size", _TestImageSize(tData) is "150,50"

   export snapshot from rect 0,0,100,100 of group "mixed" to tData as PNG
   TestAssert "a rect of the group makes an image of that size", _TestImageSize(tData) is "100,100"
end TestExportSnapshotOfGroupWithEffectsAtSize

-- Without "snapshot", export takes an image. A group there (as in
-- 'export group "x" to file "x.png" as PNG') was treated as an image and
-- crashed the engine; a field exported nothing without an error. Now any
-- object that is not an image exports nothing, without an error (so
-- scripts that ran before still run), and the result says why.
on TestExportGroupWithoutSnapshot
   local tData, tPath
   _TestMakeImageGroup

   put "unchanged" into tData
   export group "mixed" to tData as PNG
   TestAssert "export of a group to a variable sets the result", \
         the result is "export: selected object is not an image"
   TestAssert "export of a group leaves the variable alone", tData is "unchanged"

   put the tempName into tPath
   export group "mixed" to file tPath as PNG
   TestAssert "export of a group to a file sets the result", \
         the result is "export: selected object is not an image"
   TestAssert "export of a group writes no file", there is not a file tPath

   create field "text"
   export field "text" to tData as PNG
   TestAssert "export of a field sets the result", \
         the result is "export: selected object is not an image"
   TestAssert "export of a field leaves the variable alone", tData is "unchanged"

   export image "red" to tData as PNG
   TestAssert "export of an image still works", _TestImageSize(tData) is "100,100"
   TestAssert "export of an image leaves the result empty", the result is empty

   -- no handler call between the two exports, since entering one (TestAssert)
   -- empties the result by itself
   local tResult
   export group "mixed" to tData as PNG
   export image "red" to tData as PNG
   put the result into tResult
   TestAssert "an export after a failed one clears the result", tResult is empty
end TestExportGroupWithoutSnapshot
