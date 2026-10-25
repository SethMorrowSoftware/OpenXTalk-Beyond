script "CorePrinting"
/*
Copyright (C) 2018 LiveCode Ltd.

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

on TestPDFPrinter
   TestSkipIfNot "external", "revpdfprinter"
   
   local tFile, tStack
   put TestGetTestBuildFolder() & slash & "test.pdf" into tFile
   create stack
   put it into tStack
   open printing to pdf tFile
   print card 1 of tStack
   close printing
   TestAssert "print stack to pdf", there is a file tFile
end TestPDFPrinter

-- OXT-Beyond: a card with text and a filled graphic must print as more than
-- a blank card does, with the text's font in the PDF (on 0.2.7-rc.6.4, a
-- PDF printed on macOS 12 came out white, openxtalk.org, October 2026).
-- On Linux a blank card's PDF is about 1 KB, and this card's about 3.6 KB.
on TestPDFPrinterDrawsTheCard
   TestSkipIfNot "external", "revpdfprinter"

   local tBlank, tDrawn, tStack, tBlankSize, tDrawnSize
   put TestGetTestBuildFolder() & slash & "test-blank.pdf" into tBlank
   put TestGetTestBuildFolder() & slash & "test-drawn.pdf" into tDrawn
   create stack
   put it into tStack
   set the defaultStack to the short name of tStack

   open printing to pdf tBlank
   print card 1 of tStack
   close printing

   create field "Words"
   set the rect of field "Words" to 20, 20, 300, 80
   set the text of field "Words" to "Printed by the engine's tests"
   create graphic "Box"
   set the style of graphic "Box" to "rectangle"
   set the filled of graphic "Box" to true
   set the backgroundColor of graphic "Box" to "red"
   set the rect of graphic "Box" to 20, 100, 120, 160
   open printing to pdf tDrawn
   print card 1 of tStack
   close printing

   TestAssert "a blank card printed to pdf", there is a file tBlank
   TestAssert "a card with text printed to pdf", there is a file tDrawn
   put the number of bytes of URL ("binfile:" & tBlank) into tBlankSize
   put the number of bytes of URL ("binfile:" & tDrawn) into tDrawnSize
   TestDiagnostic "pdf of a blank card:" && tBlankSize && "bytes; with text and a graphic:" && tDrawnSize
   TestAssert "a card with text prints more than a blank card", tDrawnSize > tBlankSize + 1000
   TestAssert "the pdf of a card with text has its font", URL ("binfile:" & tDrawn) contains "/Font"
end TestPDFPrinterDrawsTheCard

command _TestOpenPrintingBadDest
   local tFile
   put TestGetTestBuildFolder() & slash & "test" into tFile
   open printing to baddest tFile
end _TestOpenPrintingBadDest

on TestOpenPrintingBadDest
   TestAssertThrow "open printing to bad dest throws", \
      _TestOpenPrintingBadDest, the long id of me, \
      EE_PRINT_UNKNOWNDST
end TestOpenPrintingBadDest