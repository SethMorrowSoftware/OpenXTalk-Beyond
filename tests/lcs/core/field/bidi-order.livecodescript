script "CoreFieldBidiOrder"
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

-- How a field splits text that mixes left-to-right and right-to-left
-- letters into direction levels, as the Unicode bidirectional algorithm
-- (UAX #9) and ICU, which every other program uses, split it. The levels
-- decide the order in which the text is laid out (rule L2). The bidi code
-- of libfoundation (foundation-bidi.cpp) got them wrong in six ways, each
-- of which a test below shows on 0.2.7-rc.6.6:
--
--   rule W5      a "$", "%" or "#" made everything up to the last number
--                after it a number (a Hebrew word between "$100" and
--                "$200" came out reversed), and one after a number stayed
--                a neutral ("50%" came out "%50" in right-to-left text);
--   rule X1      in a right-to-left paragraph, the text after a closed
--                embedding or isolate went to the level of left-to-right
--                text (stam66, openxtalk.org, October 2026);
--   section 5.2  invisible controls and BNs (ZWNJ, the soft hyphen) kept
--                a level of their own, which split a word with one in it
--                into pieces laid out in the wrong order, and an embedding
--                with nothing, or only a BN, in it split the text around
--                it;
--   rule X10     the text either side of an isolate was not one sequence,
--                so an isolate changed how the text around it went.
--
-- A script cannot read a char's level, and in right-to-left text the
-- formattedLeft of a char is not where the char is drawn, so each test
-- reads the runs of the field's styledText: the field starts a new run
-- wherever the level changes (MCBlock::sameatts), so the number of
-- codepoints in each run, in the order of the text, is the split into
-- levels. An invisible control is in the run of the char before it (or of
-- the first, at the start), as section 5.2 and rule L1 put it.

-- The string of words pSpec: LRE, RLE, LRO, RLO, PDF, LRI, RLI, PDI, SHY
-- (soft hyphen), ZWJ and ZWNJ are those characters, ALEF, BET, GIMEL,
-- DALET, VAV, HET, YOD, MEM and RESH Hebrew letters, ARBEH, ARTEH Arabic
-- letters (beh, teh), SPACE a space, and any other word is itself
private function bidiText pSpec
   local tText
   repeat for each word tWord in pSpec
      switch tWord
         case "LRE"
            put numToCodepoint(0x202A) after tText
            break
         case "RLE"
            put numToCodepoint(0x202B) after tText
            break
         case "PDF"
            put numToCodepoint(0x202C) after tText
            break
         case "LRO"
            put numToCodepoint(0x202D) after tText
            break
         case "RLO"
            put numToCodepoint(0x202E) after tText
            break
         case "LRI"
            put numToCodepoint(0x2066) after tText
            break
         case "RLI"
            put numToCodepoint(0x2067) after tText
            break
         case "PDI"
            put numToCodepoint(0x2069) after tText
            break
         case "SHY"
            put numToCodepoint(0x00AD) after tText
            break
         case "ZWJ"
            put numToCodepoint(0x200D) after tText
            break
         case "ZWNJ"
            put numToCodepoint(0x200C) after tText
            break
         case "ALEF"
            put numToCodepoint(0x05D0) after tText
            break
         case "BET"
            put numToCodepoint(0x05D1) after tText
            break
         case "GIMEL"
            put numToCodepoint(0x05D2) after tText
            break
         case "DALET"
            put numToCodepoint(0x05D3) after tText
            break
         case "VAV"
            put numToCodepoint(0x05D5) after tText
            break
         case "HET"
            put numToCodepoint(0x05D7) after tText
            break
         case "YOD"
            put numToCodepoint(0x05D9) after tText
            break
         case "MEM"
            put numToCodepoint(0x05DE) after tText
            break
         case "RESH"
            put numToCodepoint(0x05E8) after tText
            break
         case "ARBEH"
            put numToCodepoint(0x0628) after tText
            break
         case "ARTEH"
            put numToCodepoint(0x062A) after tText
            break
         case "SPACE"
            put space after tText
            break
         default
            put tWord after tText
      end switch
   end repeat
   return tText
end bidiText

private command bidiSetUp
   create stack "BidiOrder"
   set the defaultStack to "BidiOrder"
   create field "Text"
   set the width of field "Text" to 600
   set the dontWrap of field "Text" to true
end bidiSetUp

private command bidiTearDown
   delete stack "BidiOrder"
end bidiTearDown

-- Puts pText into field "Text" with the textDirection pDirection, and
-- asserts that the field splits it into the runs pRuns: the number of
-- codepoints in each, in the order of the text ("2,3")
private command assertRuns pWhat, pDirection, pText, pRuns
   local tStyled, tRun, tRuns
   set the textDirection of field "Text" to pDirection
   set the text of field "Text" to pText
   put the styledText of field "Text" into tStyled
   repeat with tRun = 1 to the number of elements of tStyled[1]["runs"]
      if tRuns is not empty then
         put comma after tRuns
      end if
      put the number of codepoints of tStyled[1]["runs"][tRun]["text"] after tRuns
   end repeat
   TestAssert pWhat && "(" & pDirection & ")", tRuns is pRuns
   if tRuns is not pRuns then
      TestDiagnostic pWhat && "(" & pDirection & "): runs" && tRuns & ", not" && pRuns
   end if
end assertRuns

-- Rule W5: only the "$" next to a number goes with it. The Hebrew word
-- between "$1" and "2" was put with the numbers, in one run of 7, and laid
-- out left to right, as part of a number
on TestTerminatorBeforeANumberAndAWord
   local tDirection, tText
   bidiSetUp
   -- ALEF " $1 " BET GIMEL " 2": "<alef> " "$1" " <bet><gimel> " "2"
   put bidiText("ALEF SPACE $1 SPACE BET GIMEL SPACE 2") into tText
   repeat for each item tDirection in "auto,rtl,ltr"
      assertRuns "a word between $1 and 2", tDirection, tText, "2,2,4,1"
   end repeat
   -- "<price> $100 <or> $200": each price a run, and each word
   put bidiText("MEM HET YOD RESH SPACE $100 SPACE ALEF VAV SPACE $200") into tText
   repeat for each item tDirection in "auto,rtl,ltr"
      assertRuns "two prices with a word between them", tDirection, tText, "5,4,4,4"
   end repeat
   bidiTearDown
end TestTerminatorBeforeANumberAndAWord

-- Rule W5: a "%" after a number goes with it. In right-to-left text it was
-- a run of its own, laid out on the other side of the number ("%50")
on TestTerminatorAfterANumber
   local tDirection
   bidiSetUp
   repeat for each item tDirection in "auto,rtl,ltr"
      -- ALEF " 50%": "<alef> " "50%"
      assertRuns "a Hebrew word and 50%", tDirection, bidiText("ALEF SPACE 50%"), "2,3"
      -- "abc 50%" is all one run, left to right, in a right-to-left
      -- paragraph too
      assertRuns "a Latin word and 50%", tDirection, "abc 50%", "7"
   end repeat
   bidiTearDown
end TestTerminatorAfterANumber

-- Rule X1: in a right-to-left paragraph the text after a closed embedding
-- goes back to the paragraph's level. "b" and GIMEL went to the level of
-- left-to-right text, in one run, and GIMEL came out on the right of ALEF.
-- In a left-to-right paragraph the letters were laid out as they should
-- be, and only the runs the RLE and the PDF are in change (section 5.2)
on TestTextAfterAClosedEmbedding
   local tText, tDirection
   bidiSetUp
   -- RLE, ALEF and the PDF after it, "b", GIMEL
   put bidiText("RLE ALEF PDF b GIMEL") into tText
   repeat for each item tDirection in "auto,rtl,ltr"
      assertRuns "after an embedding", tDirection, tText, "1,2,1,1"
   end repeat
   -- stam66's example
   put bidiText("RLE ALEF PDF b") into tText
   repeat for each item tDirection in "auto,rtl,ltr"
      assertRuns "stam66's example", tDirection, tText, "1,2,1"
   end repeat
   bidiTearDown
end TestTextAfterAClosedEmbedding

-- Rule X1, after an isolate: "b" at the level of left-to-right text in a
-- right-to-left paragraph, GIMEL at the paragraph's. They were in one run.
-- (auto finds "b" first, skipping the isolate, so it is left to right
-- here, and was right)
on TestTextAfterAClosedIsolate
   local tText, tDirection
   bidiSetUp
   put bidiText("RLI ALEF PDI b GIMEL") into tText
   assertRuns "after an isolate", "rtl", tText, "1,1,1,1,1"
   repeat for each item tDirection in "auto,ltr"
      assertRuns "after an isolate", tDirection, tText, "1,1,2,1"
   end repeat
   bidiTearDown
end TestTextAfterAClosedIsolate

-- Section 5.2: a soft hyphen in a Hebrew word in left-to-right text has the
-- word's level. With a level of its own it split the word into three runs,
-- and the second half came out on the right of the first
on TestSoftHyphenInAWord
   local tText, tDirection
   bidiSetUp
   -- "ab " ALEF BET SHY GIMEL DALET: "ab " and the word
   put bidiText("ab SPACE ALEF BET SHY GIMEL DALET") into tText
   repeat for each item tDirection in "auto,ltr"
      assertRuns "a word with a soft hyphen", tDirection, tText, "3,5"
   end repeat
   assertRuns "a word with a soft hyphen", "rtl", tText, "2,6"
   bidiTearDown
end TestSoftHyphenInAWord

-- Section 5.2: the same with a ZWNJ in a Persian word: "ab " MEEM
-- FARSI-YEH ZWNJ KHAH WAW
on TestZWNJInAWord
   local tText, tDirection
   bidiSetUp
   put "ab " & numToCodepoint(0x0645) & numToCodepoint(0x06CC) & numToCodepoint(0x200C) & \
         numToCodepoint(0x062E) & numToCodepoint(0x0648) into tText
   repeat for each item tDirection in "auto,ltr"
      assertRuns "a word with a ZWNJ", tDirection, tText, "3,5"
   end repeat
   assertRuns "a word with a ZWNJ", "rtl", tText, "2,6"
   bidiTearDown
end TestZWNJInAWord

-- Rule X10: the text either side of an isolate is one sequence, so the
-- isolate is a neutral to it, like any other: "1" after an Arabic letter
-- is an Arabic number whether an isolate or "==" is between them. In a
-- left-to-right paragraph it was a European number, and the isolate and
-- the "1" went left to right, on the right of the letter
on TestIsolateBetweenAWordAndANumber
   local tDirection
   bidiSetUp
   repeat for each item tDirection in "auto,rtl"
      assertRuns "an isolate between a word and a number", tDirection, \
            bidiText("ARBEH RLI GIMEL PDI 1"), "2,1,1,1"
   end repeat
   assertRuns "an isolate between a word and a number", "ltr", \
         bidiText("ARBEH RLI GIMEL PDI 1"), "4,1"
   repeat for each item tDirection in "auto,rtl,ltr"
      assertRuns "neutrals between a word and a number", tDirection, \
            bidiText("ARBEH == 1"), "3,1"
   end repeat
   bidiTearDown
end TestIsolateBetweenAWordAndANumber

-- Section 5.2: an embedding with nothing in it changes nothing. Its two
-- controls split the text, so that "0" was not seen to follow the Arabic
-- letter
on TestEmptyEmbedding
   local tDirection
   bidiSetUp
   repeat for each item tDirection in "auto,rtl,ltr"
      assertRuns "an empty embedding", tDirection, bidiText("ARTEH ## LRE PDF 0"), "5,1"
      assertRuns "no embedding", tDirection, bidiText("ARTEH ##0"), "3,1"
   end repeat
   bidiTearDown
end TestEmptyEmbedding

-- Rule X10: nor does an embedding with only a BN in it. The BN's level
-- split the text, so that "3" was not seen to follow the Arabic letter
-- and "%" went with it ("3%"), as it does not without the embedding
on TestEmbeddingWithOnlyABN
   local tDirection
   bidiSetUp
   repeat for each item tDirection in "auto,rtl,ltr"
      assertRuns "an override with a soft hyphen in it", tDirection, \
            bidiText("ARBEH RLO SHY PDF 3%"), "4,1,1"
      assertRuns "an override with a ZWJ in it", tDirection, \
            bidiText("ARBEH LRO ZWJ PDF 3%"), "4,1,1"
      assertRuns "no override", tDirection, bidiText("ARBEH 3%"), "1,1,1"
   end repeat
   bidiTearDown
end TestEmbeddingWithOnlyABN

-- Left-to-right text is laid out as it was. In a right-to-left paragraph,
-- the soft hyphen and the "%" were each a run of their own
on TestLeftToRightText
   local tDirection
   bidiSetUp
   repeat for each item tDirection in "auto,rtl,ltr"
      assertRuns "left-to-right text", tDirection, "a $1 bc 2", "9"
      assertRuns "left-to-right text with a soft hyphen", tDirection, \
            bidiText("ab SHY cd SPACE 50%"), "9"
   end repeat
   bidiTearDown
end TestLeftToRightText
