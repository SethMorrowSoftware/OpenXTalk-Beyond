script "CoreInterfaceAnimatedGif"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- Animated GIFs: how their frames are put together (igif.cpp), and the
-- frameDurations and playRate of an image (0.2.8-dp.2).
--
-- The GIFs are a few pixels each, made by _animated-gif-fixtures.py next
-- to this file (run it with --check to see these copies are what it
-- makes). Palette: red, green, blue, black. A pixel reads as
-- "red,green,blue,alpha".

constant kGifHoles = "R0lGODlhAgABAIEAAP8AAAD/AAAA/wAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgABAAACAoQKACH5BAEAAAMALAAAAAACAAEAAAICXAoAIfkEABkAAAAsAAAAAAIAAQAAAgJMCgA7"
constant kGifRestorePrevious = "R0lGODlhAQADAIEAAP8AAAD/AAAA/wAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQEBQAAACwAAAAAAQADAAACAoQLACH5BAwFAAAALAAAAQABAAIAAAICTAoAIfkEBAUAAAAsAAAAAAEAAQAAAgJUAQA7"
constant kGifPastCanvas = "R0lGODlhAgABAIEAAP8AAAD/AAAA/wAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQEBQAAACwAAAAAAgABAAACAgQKACH5BAQFAAAALAEAAAACAAEAAAICjAoAOw=="

constant kGifFirstFrameClear = "R0lGODlhAwABAIEAAP8AAAD/AAAA/wAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQFBQADACwAAAAAAgABAAACAhwKACH5BAQFAAAALAAAAAADAAEAAAICjAsAOw=="
local sStack

private command _MakeImage pGif
   create invisible stack "AnimatedGifTest"
   put the short name of it into sStack
   set the defaultStack to sStack
   create image "G"
   set the text of image "G" to base64Decode(pGif)
   set the width of image "G" to the formattedWidth of image "G"
   set the height of image "G" to the formattedHeight of image "G"
end _MakeImage

private command _DeleteStack
   if sStack is not empty and there is a stack sStack then
      delete stack sStack
   end if
   put empty into sStack
end _DeleteStack

-- The pixels of frame pFrame of image "G", one a line
private function _Frame pFrame
   local tData, tAlpha, tOut
   set the currentFrame of image "G" to pFrame
   put the imageData of image "G" into tData
   put the alphaData of image "G" into tAlpha
   repeat with i = 0 to (the number of bytes of tAlpha) - 1
      put byteToNum(byte i * 4 + 2 of tData) & comma & \
            byteToNum(byte i * 4 + 3 of tData) & comma & \
            byteToNum(byte i * 4 + 4 of tData) & comma & \
            byteToNum(byte i + 1 of tAlpha) & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end _Frame

-------------------------------------------------------------------------------
-- How the frames are put together

on TestTransparentPixelsKeepWhatIsUnder
   -- No disposal given (what most GIF makers write): frame 2's transparent
   -- first pixel leaves frame 1's red there, as every browser shows it.
   -- Up to 0.2.8-dp.1 it punched a clear hole ("0,0,0,0").
   _MakeImage kGifHoles
   TestAssert "three frames", the frameCount of image "G" is 3
   TestAssert "frame 1", _Frame(1) is "255,0,0,255" & return & "0,0,255,255"
   TestAssert "frame 2 keeps frame 1's red under its transparent pixel", \
         _Frame(2) is "255,0,0,255" & return & "0,255,0,255"
   TestAssert "frame 3", _Frame(3) is "0,255,0,255" & return & "0,255,0,255"
   _DeleteStack
end TestTransparentPixelsKeepWhatIsUnder

on TestRestoreToPreviousOnATallCanvas
   -- Frame 2 (the lower two rows) is "restore to previous": frame 3 finds
   -- them red again. Up to 0.2.8-dp.1 the restore compared a height with a
   -- width and was skipped on a canvas taller than wide.
   _MakeImage kGifRestorePrevious
   TestAssert "frame 2 draws the lower rows", \
         _Frame(2) is "255,0,0,255" & return & "0,255,0,255" & return & "0,255,0,255"
   TestAssert "frame 3 finds them restored", \
         _Frame(3) is "0,0,255,255" & return & "255,0,0,255" & return & "255,0,0,255"
   _DeleteStack
end TestRestoreToPreviousOnATallCanvas

on TestFramePastTheCanvasIsClipped
   -- Frame 2 reaches one pixel past the canvas: the pixel on it is drawn.
   -- Up to 0.2.8-dp.1 such a frame was not drawn at all.
   _MakeImage kGifPastCanvas
   TestAssert "frame 2's pixel on the canvas", \
         _Frame(2) is "255,0,0,255" & return & "0,255,0,255"
   _DeleteStack
end TestFramePastTheCanvasIsClipped

on TestTheCanvasStartsClear
   -- The first frame covers two of three pixels, the first of them its
   -- transparent colour: both of the pixels it leaves are clear, not
   -- whatever was in the memory the canvas was made in.
   _MakeImage kGifFirstFrameClear
   TestAssert "frame 1", _Frame(1) is "0,0,0,0" & return & "255,0,0,255" & return & "0,0,0,0"
   TestAssert "frame 2", _Frame(2) is "0,255,0,255" & return & "0,255,0,255" & return & "0,255,0,255"
   _DeleteStack
end TestTheCanvasStartsClear

-------------------------------------------------------------------------------
-- frameDurations and playRate

on TestFrameDurationsFromTheFile
   _MakeImage kGifHoles
   TestAssert "a frame's delay in milliseconds, one a line", \
         the frameDurations of image "G" is "100" & return & "0" & return & "250"
   TestAssert "the playRate is 1", the playRate of image "G" is 1
   _DeleteStack
end TestFrameDurationsFromTheFile

on TestFrameDurationsOfAStillImage
   create invisible stack "AnimatedGifTest"
   put the short name of it into sStack
   set the defaultStack to sStack
   create image "G"
   TestAssert "an empty image has none", the frameDurations of image "G" is empty
   set the width of image "G" to 1
   set the height of image "G" to 1
   set the imageData of image "G" to numToByte(0) & numToByte(255) & numToByte(0) & numToByte(0)
   TestAssert "nor does a picture of one frame", the frameDurations of image "G" is empty
   set the frameDurations of image "G" to 40
   TestAssert "a still image takes the setting", the result is empty
   set the playRate of image "G" to 2
   TestAssert "and a playRate", the playRate of image "G" is 2
   _DeleteStack
end TestFrameDurationsOfAStillImage

on TestSetFrameDurations
   _MakeImage kGifHoles
   set the frameDurations of image "G" to "40" & return & return & "60.4"
   TestAssert "a set line wins, an empty line keeps the file's", \
         the frameDurations of image "G" is "40" & return & "0" & return & "60"
   set the frameDurations of image "G" to 70
   TestAssert "frames past the last line keep the file's", \
         the frameDurations of image "G" is "70" & return & "0" & return & "250"
   set the frameDurations of image "G" to " 5 " & return & "6" & return & "7" & return & "8" & return
   TestAssert "spaces trimmed, lines past the last frame left out", \
         the frameDurations of image "G" is "5" & return & "6" & return & "7"
   set the frameDurations of image "G" to empty
   TestAssert "empty puts back the file's", \
         the frameDurations of image "G" is "100" & return & "0" & return & "250"
   set the frameDurations of image "G" to "10" & return & "20" & return & "30"
   set the playRate of image "G" to 4
   TestAssert "the playRate does not change what frameDurations says", \
         the frameDurations of image "G" is "10" & return & "20" & return & "30"
   TestAssert "the frames are what they were", \
         _Frame(2) is "255,0,0,255" & return & "0,255,0,255"
   _DeleteStack
end TestSetFrameDurations

on TestBadFrameDurations
   _MakeImage kGifHoles
   TestAssertThrow "a word throws", "_SetFrameDurations", the long id of me, \
         "EE_IMAGE_BADFRAMEDURATIONS", "fast"
   TestAssertThrow "a negative number throws", "_SetFrameDurations", the long id of me, \
         "EE_IMAGE_BADFRAMEDURATIONS", "10" & return & "-1"
   TestAssert "and leaves the setting as it was", \
         the frameDurations of image "G" is "100" & return & "0" & return & "250"
   _DeleteStack
end TestBadFrameDurations

on _SetFrameDurations pValue
   set the frameDurations of image "G" of stack sStack to pValue
end _SetFrameDurations

on TestBadPlayRate
   _MakeImage kGifHoles
   TestAssertThrow "zero throws", "_SetPlayRate", the long id of me, \
         "EE_IMAGE_BADPLAYRATE", 0
   TestAssertThrow "a negative rate throws", "_SetPlayRate", the long id of me, \
         "EE_IMAGE_BADPLAYRATE", -1
   TestAssert "and leaves it as it was", the playRate of image "G" is 1
   set the playRate of image "G" to 0.5
   TestAssert "half speed", the playRate of image "G" is 0.5
   _DeleteStack
end TestBadPlayRate

on _SetPlayRate pValue
   set the playRate of image "G" of stack sStack to pValue
end _SetPlayRate

on TestCopyKeepsThePace
   _MakeImage kGifHoles
   set the frameDurations of image "G" to "11" & return & "22"
   set the playRate of image "G" to 3
   clone image "G"
   set the name of it to "C"
   TestAssert "a clone has the frameDurations", \
         the frameDurations of image "C" is "11" & return & "22" & return & "250"
   TestAssert "and the playRate", the playRate of image "C" is 3
   _DeleteStack
end TestCopyKeepsThePace

on TestOldStacksUnchanged
   -- Neither property is saved with the stack, nor among the properties
   -- (whose keys old scripts walk), so a stack saved here opens in an older
   -- engine as it was, and opens here at its file's own pace.
   local tPath, tProps
   _MakeImage kGifHoles
   set the frameDurations of image "G" to 33
   set the playRate of image "G" to 2
   put the properties of image "G" into tProps
   TestAssert "frameDurations is not among the properties", \
         "frameDurations" is not among the keys of tProps
   TestAssert "nor is the playRate", "playRate" is not among the keys of tProps
   put specialFolderPath("temporary") & slash & sStack & "-" & the milliseconds & ".livecode" into tPath
   save stack sStack as tPath
   delete stack sStack
   TestAssert "the stack is gone before it is opened again", there is not a stack sStack
   TestAssert "reopened, the frames keep the file's durations", \
         the frameDurations of image "G" of stack tPath is "100" & return & "0" & return & "250"
   TestAssert "at the file's pace", the playRate of image "G" of stack tPath is 1
   _DeleteStack
   delete file tPath
end TestOldStacksUnchanged
