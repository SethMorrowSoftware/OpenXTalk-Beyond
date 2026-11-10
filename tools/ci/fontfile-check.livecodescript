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
--
-- Then the fonts it loads must be the fonts it lists and measures (and so
-- draws, with the same Pango font map). Up to 0.2.7-rc.6.18 a font loaded
-- with `start using font file` on Linux was in neither: each load made a
-- fontconfig configuration with only that one file (so the load before it
-- was dropped), and Pango kept the configuration it first used (Pango
-- 1.48 and later), so the IDE's code font, Source Code Pro, was drawn in
-- the fallback face. The IDE's code font files (Regular, then Bold) and
-- the font file above (its icon font) are loaded in turn and unloaded, and
-- after each:
--
--   CODE <state> <listed>,<icons listed>,<narrow>,<wide>,<narrow bold>,<wide bold> <result>
--
-- <listed> is whether "Source Code Pro" is among the fontNames, <icons
-- listed> whether the icon font's family is; the widths are of ten i and
-- ten M in Source Code Pro, plain and bold, alike only in a monospaced
-- face, so alike only when Source Code Pro is what measures them.

constant kRounds = 10
constant kFonts = "DejaVu Sans,DejaVu Serif,DejaVu Sans Mono"
constant kStyles = "plain,bold,italic"
constant kSizes = "11,13,16"
constant kProbe = "OXTFontFileProbe"
constant kCodeFont = "Source Code Pro"
constant kCodeFiles = "SourceCodePro-Regular.ttf,SourceCodePro-Bold.ttf"

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

-- The fontNames and the widths a CODE line gives (see the top)
function codeProbe pIcons
   local tFonts, tLine, tStyle
   put the fontNames into tFonts
   put (kCodeFont is among the lines of tFonts) & comma & (pIcons is among the lines of tFonts) into tLine
   set the textFont of field "Code" of stack kProbe to kCodeFont
   set the textSize of field "Code" of stack kProbe to 13
   repeat for each item tStyle in "plain,bold"
      set the textStyle of field "Code" of stack kProbe to tStyle
      put comma & the formattedWidth of line 1 of field "Code" of stack kProbe after tLine
      put comma & the formattedWidth of line 2 of field "Code" of stack kProbe after tLine
   end repeat
   return tLine
end codeProbe

-- Load or unload a font file and log the CODE line after it
command codeStep pState, pAction, pFile, pIcons
   local tResult
   if pAction is "load" then
      start using font file pFile
   else
      stop using font file pFile
   end if
   put the result into tResult
   logLine "CODE" && pState && codeProbe(pIcons) && tResult
end codeStep

on runCheck
   local tFile, tResult, tCode, tIcons
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

      -- The fonts it loads are the fonts it lists and measures: the
      -- IDE's code font, Regular then Bold, then the icon font, as the
      -- IDE loads them; then each unloaded
      create field "Code"
      set the width of field "Code" to 2000
      set the dontWrap of field "Code" to true
      set the text of field "Code" to "iiiiiiiiii" & return & "MMMMMMMMMM"
      put $OXT_FONTFILE_CODE into tCode
      put $OXT_FONTFILE_ICONS into tIcons
      logLine "INFO code font folder" && tCode && "exists=" & (there is a folder tCode) && "icons=" & tIcons
      logLine "CODE before" && codeProbe(tIcons)
      codeStep "regular", "load", tCode & slash & item 1 of kCodeFiles, tIcons
      codeStep "bold", "load", tCode & slash & item 2 of kCodeFiles, tIcons
      codeStep "icons", "load", tFile, tIcons
      codeStep "no-regular", "unload", tCode & slash & item 1 of kCodeFiles, tIcons
      codeStep "no-bold", "unload", tCode & slash & item 2 of kCodeFiles, tIcons
      codeStep "after", "unload", tFile, tIcons
   catch tError
      logLine "ERROR" && line 1 of tError
   end try
   logLine "QUIT" && the milliseconds
   quit
end runCheck
