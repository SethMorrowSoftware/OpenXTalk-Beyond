script "OXTFontFileCheck"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- Run by tools/ci/fontfile_check.py, which starts this standalone engine
-- on its own X server. `start using font file` and `stop using font file`
-- make the engine load every font again (MCFontRemap, engine/src/font.cpp):
-- the old ones are freed and the new ones are made, often at the addresses
-- of other freed ones. The width of a piece of text is kept in a cache
-- (libgraphics/src/context.cpp) under the font's address, so up to
-- 0.2.7-rc.6.12 a font could be measured with another font's widths: bold
-- text with the plain font's, narrower, so the words of a bold run were
-- drawn against each other ("Threewindowsforonewelcome"). The IDE loads a
-- font file as Home and Learn open, so its release notes and dialogs on
-- Linux showed it.
--
-- One field, its line measured in three DejaVu fonts, three styles and
-- three sizes; then kRounds times the font file loaded and unloaded, the
-- line measured again after each. Each line written to $OXT_FONTFILE_LOG:
--
--   BASE <widths>                  before any font file
--   LOADED <round> <widths> <result of start using font file>
--   UNLOADED <round> <widths> <result of stop using font file>
--
-- The widths are comma-separated, in the order of kFonts, kStyles and
-- kSizes. The Python script decides what passes: every width as BASE.

constant kRounds = 10
constant kFonts = "DejaVu Sans,DejaVu Serif,DejaVu Sans Mono"
constant kStyles = "plain,bold,italic"
constant kSizes = "11,13,16"
constant kProbe = "OXTFontFileProbe"

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_FONTFILE_LOG)
end logLine

on openStack
   send "runCheck" to me in 200 milliseconds
end openStack

function probeWidths
   local tWidths
   repeat for each item tFont in kFonts
      repeat for each item tStyle in kStyles
         repeat for each item tSize in kSizes
            set the textFont of field "Probe" of stack kProbe to tFont
            set the textStyle of field "Probe" of stack kProbe to tStyle
            set the textSize of field "Probe" of stack kProbe to tSize
            put the formattedWidth of line 1 of field "Probe" of stack kProbe & comma after tWidths
         end repeat
      end repeat
   end repeat
   delete the last char of tWidths
   return tWidths
end probeWidths

on runCheck
   local tFile, tResult
   logLine "INFO platform=" & the platform & " version=" & the version & " processor=" & the processor
   try
      create invisible stack kProbe
      set the defaultStack to kProbe
      create field "Probe"
      set the width of field "Probe" to 2000
      set the dontWrap of field "Probe" to true
      set the text of field "Probe" to "An engine that still said OXT. Three windows for one welcome."
      logLine "BASE" && probeWidths()

      put $OXT_FONTFILE_FONT into tFile
      logLine "INFO font file" && tFile && "exists=" & (there is a file tFile)
      repeat with tRound = 1 to kRounds
         start using font file tFile
         put the result into tResult
         logLine "LOADED" && tRound && probeWidths() && tResult
         stop using font file tFile
         put the result into tResult
         logLine "UNLOADED" && tRound && probeWidths() && tResult
      end repeat
   catch tError
      logLine "ERROR" && line 1 of tError
   end try
   logLine "QUIT" && the milliseconds
   quit
end runCheck
