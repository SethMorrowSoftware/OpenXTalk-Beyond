script "CoreInterfaceWebDesktopFonts"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

/*
The web engine draws the desktop font names (Arial, Helvetica, Geneva,
Times, Courier and the rest of the table in engine/src/em-font.cpp) in
the metric-compatible family that stands in for them, when the standalone
has that family: the Web pane's "Desktop fonts" setting puts Arimo, Tinos
and Cousine into it. Here the test loads Arimo itself, with "start using
font file", so the standalone that tools/ci/web_tests.py builds needs no
setting: the path below is how that script knows to copy the file in.
Without the family, nothing changes (text draws in Droid Sans, as before).
*/

constant kText = "The quick brown fox jumps over the lazy dog 0123456789"

private function __widthIn pFont
   set the textFont of field "Probe" to pFont
   return the formattedWidth of field "Probe"
end __widthIn

on TestWebDesktopFontStandIns
   if the platform is not "HTML5" then
      TestSkip "desktop names stand in for Arimo", "only the web engine maps font names"
      exit TestWebDesktopFontStandIns
   end if

   local tFile
   put TestGetEngineRepositoryPath() & "/engine/rsrc/emscripten-desktop-fonts/Arimo-Regular.ttf" into tFile
   TestAssert "the test has Arimo", there is a file tFile

   -- the standalone has no Arimo of its own: without it, no stand-ins
   TestAssert "no Arial before Arimo is loaded", "Arial" is not among the lines of the fontNames
   TestAssert "no Geneva before Arimo is loaded", "Geneva" is not among the lines of the fontNames

   create stack "WebDesktopFonts"
   set the defaultStack to "WebDesktopFonts"
   create field "Probe"
   set the dontWrap of field "Probe" to true
   set the textSize of field "Probe" to 20
   set the text of field "Probe" to kText

   local tArialBefore
   put __widthIn("Arial") into tArialBefore

   start using font file tFile
   TestAssert "Arimo loads", the result is empty

   TestAssert "Arimo is listed", "Arimo" is among the lines of the fontNames
   TestAssert "Arial is listed with Arimo loaded", "Arial" is among the lines of the fontNames
   TestAssert "Helvetica is listed with Arimo loaded", "Helvetica" is among the lines of the fontNames
   TestAssert "Geneva is listed with Arimo loaded", "Geneva" is among the lines of the fontNames
   -- Times stands in for Tinos, which is not loaded
   TestAssert "Times is not listed without Tinos", "Times" is not among the lines of the fontNames
   TestAssert "Arial has Arimo's styles", "plain" is among the lines of fontStyles("Arial", 0)

   local tArimo, tArial, tHelvetica
   put __widthIn("Arimo") into tArimo
   put __widthIn("Arial") into tArial
   put __widthIn("Helvetica") into tHelvetica
   TestDiagnostic "widths: Arial before" && tArialBefore & ", Arimo" && tArimo & ", Arial" && tArial & ", Helvetica" && tHelvetica
   TestAssert "Arial draws in Arimo", tArial is tArimo
   TestAssert "Helvetica draws in Arimo", tHelvetica is tArimo
   TestAssert "Arial no longer draws in Droid Sans", tArial is not tArialBefore

   stop using font file tFile
   TestAssert "Arial leaves with Arimo", "Arial" is not among the lines of the fontNames
   TestAssert "Arial draws as before once Arimo is gone", __widthIn("Arial") is tArialBefore

   delete stack "WebDesktopFonts"
end TestWebDesktopFontStandIns
