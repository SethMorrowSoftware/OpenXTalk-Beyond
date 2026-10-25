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

-- OXT-Beyond: a PDF with more than one link must print. On 0.2.7-rc.6.4
-- the second link of a document crashed the engine with signal 11 at the
-- end of its page, whether it was a second print link (to the same URL
-- or another), a link on a later page or a field's second link text
-- (tperry2x, openxtalk.org, October 2026): the PDF printer's cairo kept
-- 8 bytes of each URL's action and read the rest of it from memory past
-- them. Each link is an annotation (/Subtype /Link) of the PDF, and each
-- URL one action (/S /URI) that every link to it shares.
on TestPDFPrinterLinks
   TestSkipIfNot "external", "revpdfprinter"

   local tFile, tStack, tData
   put TestGetTestBuildFolder() & slash & "test-links.pdf" into tFile
   create stack
   put it into tStack
   set the defaultStack to the short name of tStack

   open printing to pdf tFile
   print link to url "https://openxtalk.org/" with rect 10, 10, 200, 40
   print link to url "https://openxtalk.org/" with rect 10, 50, 200, 80
   print link to url "https://github.com/" with rect 10, 90, 200, 120
   print card 1 of tStack
   print break
   print link to url "https://openxtalk.org/" with rect 10, 10, 200, 40
   print card 1 of tStack
   close printing

   TestAssert "a pdf with four links printed", there is a file tFile
   put URL ("binfile:" & tFile) into tData
   TestDiagnostic "pdf with four links:" && the number of bytes of tData && "bytes"
   TestAssert "the pdf has its four links", _TestCountOf("/Subtype /Link", tData) is 4
   TestAssert "the pdf has one action for each of its two urls", _TestCountOf("/S /URI", tData) is 2
   TestAssert "the pdf links to its first url", tData contains "(https://openxtalk.org/)"
   TestAssert "the pdf links to its second url", tData contains "(https://github.com/)"
end TestPDFPrinterLinks

on TestPDFPrinterFieldLinks
   TestSkipIfNot "external", "revpdfprinter"

   local tFile, tStack, tData
   put TestGetTestBuildFolder() & slash & "test-field-links.pdf" into tFile
   create stack
   put it into tStack
   set the defaultStack to the short name of tStack

   create field "Links"
   set the rect of field "Links" to 20, 20, 380, 80
   set the text of field "Links" to "GitHub and OpenXTalk"
   set the textStyle of word 1 of field "Links" to "link"
   set the linkText of word 1 of field "Links" to "https://github.com/"
   set the textStyle of word 3 of field "Links" to "link"
   set the linkText of word 3 of field "Links" to "https://openxtalk.org/"
   open printing to pdf tFile
   print card 1 of tStack
   close printing

   TestAssert "a card with a field of two links printed to pdf", there is a file tFile
   put URL ("binfile:" & tFile) into tData
   TestAssert "the pdf has the field's two links", _TestCountOf("/Subtype /Link", tData) is 2
   TestAssert "the pdf has an action for each of the field's urls", _TestCountOf("/S /URI", tData) is 2
end TestPDFPrinterFieldLinks

private function _TestCountOf pNeedle, pData
   local tCount, tSkip, tFound
   put 0 into tCount
   put 0 into tSkip
   repeat
      put offset(pNeedle, pData, tSkip) into tFound
      if tFound is 0 then exit repeat
      add 1 to tCount
      add tFound to tSkip
   end repeat
   return tCount
end _TestCountOf

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