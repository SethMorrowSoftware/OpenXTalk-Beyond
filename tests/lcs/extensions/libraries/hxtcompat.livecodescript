script "TestHyperXTalkCompatibilityLibrary"
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

-- The HyperXTalk compatibility library (org.openxtalk.library.hxtcompat)
-- as a script uses it: iff, quotedPrintableEncode, quotedPrintableDecode
-- and microseconds() with its other names, and that a script's own
-- handler of one of these names still comes first. This script has none
-- of its own, so that its calls reach the library.

on TestSetup
   TestSkipIfNot "lcb"
   TestLoadExtension "org.openxtalk.library.hxtcompat"
end TestSetup

on TestIff
   TestAssert "true gives the first value", iff(true, "yes", "no") is "yes"
   TestAssert "false gives the second value", iff(false, "yes", "no") is "no"
   TestAssert "a condition", iff(1 + 1 is 2, "right", "wrong") is "right"
   TestAssert "true in any case", iff("TRUE", 1, 2) is 1
   TestAssert "a number stays a number", iff(true, 3, 4) + 1 is 4
   TestAssert "empty", iff(false, "x", empty) is empty

   local tArray, tResult
   put "one" into tArray[1]
   put iff(true, tArray, "none") into tResult
   TestAssert "an array stays an array", tResult is an array and tResult[1] is "one"

   TestAssert "in an expression", "1 item" && iff(2 is 1, "is", "are") is "1 item are"
end TestIff

on TestIffNeedsTrueOrFalse
   TestAssertThrow "a condition that is neither true nor false throws", \
         "IffWithBadCondition", the long id of me, "EE_INVOKE_TYPEERROR"
end TestIffNeedsTrueOrFalse

on IffWithBadCondition
   get iff("yes", 1, 2)
end IffWithBadCondition

on TestIffBothValuesWorkedOut
   -- as with any handler, both values are worked out before the call
   global gIffCalls
   put 0 into gIffCalls
   get iff(true, countCall(), countCall())
   TestAssert "both values are worked out", gIffCalls is 2
end TestIffBothValuesWorkedOut

private function countCall
   global gIffCalls
   add 1 to gIffCalls
   return gIffCalls
end countCall

on TestQuotedPrintableEncode
   TestAssert "plain text stays", quotedPrintableEncode("Hello, world!") is "Hello, world!"
   TestAssert "= is encoded", quotedPrintableEncode("a=b") is "a=3Db"
   TestAssert "a space inside a line stays", quotedPrintableEncode("a b") is "a b"
   TestAssert "a space at the end is encoded", quotedPrintableEncode("a ") is "a=20"
   TestAssert "a tab at the end is encoded", quotedPrintableEncode("a" & tab) is "a=09"
   TestAssert "a space before a line break is encoded", \
         quotedPrintableEncode("a " & crlf & "b") is "a=20" & crlf & "b"
   TestAssert "line breaks stay", quotedPrintableEncode("a" & crlf & "b" & lf & "c") is \
         "a" & crlf & "b" & lf & "c"
   TestAssert "other control characters are encoded", quotedPrintableEncode(numToByte(0) & numToByte(27)) is "=00=1B"
   TestAssert "bytes above 126 are encoded, in upper case", \
         quotedPrintableEncode(numToByte(127) & numToByte(255)) is "=7F=FF"
   TestAssert "UTF-8", quotedPrintableEncode(textEncode(cafe(), "UTF-8")) is "caf=C3=A9"
   TestAssert "empty", quotedPrintableEncode(empty) is empty
end TestQuotedPrintableEncode

on TestQuotedPrintableLineLength
   local tText, tEncoded
   repeat 100 times
      put "a" after tText
   end repeat
   put quotedPrintableEncode(tText) into tEncoded
   TestAssert "a long line is broken", tEncoded is (char 1 to 75 of tText) & "=" & crlf & (char 76 to 100 of tText)
   TestAssert "76 characters and no more", longestLine(tEncoded) is 76

   -- exactly 76 characters fit on a line, when it is the last
   put char 1 to 76 of tText into tText
   TestAssert "a line of 76 characters stays", quotedPrintableEncode(tText) is tText

   -- an encoded byte is never split by a soft line break
   put empty into tText
   repeat 30 times
      put numToByte(255) after tText
   end repeat
   put quotedPrintableEncode(tText) into tEncoded
   -- (76 characters, and the CR of the soft line break)
   TestAssert "encoded bytes are kept whole", line 1 of tEncoded ends with "=FF=" & cr and \
         the number of chars of line 1 of tEncoded is 77
   TestAssert "and the lines are no longer than 76", longestLine(tEncoded) <= 76
end TestQuotedPrintableLineLength

-- The length of the longest line, without its CR and soft line break's
-- line feed
private function longestLine pText
   local tLongest
   put 0 into tLongest
   replace crlf with lf in pText
   repeat for each line tLine in pText
      put max(tLongest, the number of chars of tLine) into tLongest
   end repeat
   return tLongest
end longestLine

on TestQuotedPrintableRoundTrip
   local tData, tEncoded, tText
   set the caseSensitive to true
   -- every byte, several times over, with line breaks among them
   repeat with i = 0 to 1023
      put numToByte(i mod 256) after tData
   end repeat
   put quotedPrintableEncode(tData) into tEncoded
   TestAssert "every byte round-trips", quotedPrintableDecode(tEncoded) is tData
   TestAssert "the encoded lines are no longer than 76", longestLine(tEncoded) <= 76
   TestAssert "the encoding is ASCII", not matchText(tEncoded, "[^\x09\x0A\x0D\x20-\x7E]")

   -- "Gruesse aus Koeln - Tokyo", in German, with an em dash and in Japanese
   put "Gr" & numToCodepoint(252) & numToCodepoint(223) & "e aus K" & numToCodepoint(246) & "ln " & \
         numToCodepoint(8212) && numToCodepoint(26481) & numToCodepoint(20140) into tText
   put textEncode(tText, "UTF-8") into tData
   TestAssert "UTF-8 text round-trips", \
         textDecode(quotedPrintableDecode(quotedPrintableEncode(tData)), "UTF-8") is tText
   set the caseSensitive to false
end TestQuotedPrintableRoundTrip

-- "cafe" with an acute accent, written so that this file stays ASCII
private function cafe
   return "caf" & numToCodepoint(233)
end cafe

on TestQuotedPrintableDecode
   TestAssert "plain text stays", quotedPrintableDecode("Hello") is "Hello"
   TestAssert "=XX becomes its byte", quotedPrintableDecode("a=3Db") is "a=b"
   TestAssert "lower case hexadecimal", quotedPrintableDecode("caf=c3=a9") is textEncode(cafe(), "UTF-8")
   TestAssert "a soft line break (CR LF) is left out", quotedPrintableDecode("ab=" & crlf & "cd") is "abcd"
   TestAssert "a soft line break (LF) is left out", quotedPrintableDecode("ab=" & lf & "cd") is "abcd"
   TestAssert "a hard line break stays", quotedPrintableDecode("ab" & crlf & "cd") is "ab" & crlf & "cd"
   TestAssert "an = that starts nothing stays", quotedPrintableDecode("a=zz") is "a=zz"
   TestAssert "an = at the end stays", quotedPrintableDecode("a=") is "a="
   TestAssert "an = and one digit at the end stay", quotedPrintableDecode("a=4") is "a=4"
   TestAssert "empty", quotedPrintableDecode(empty) is empty
end TestQuotedPrintableDecode

on TestMicrosecondsCall
   local tMsBefore, tUs, tMsAfter
   put the milliseconds into tMsBefore
   put microseconds() into tUs
   put the milliseconds into tMsAfter
   TestAssert "microseconds() is a whole number", tUs is an integer
   -- (see tests/lcs/core/datetime/microseconds.livecodescript for the minute)
   TestAssert "microseconds() counts from the same time as the milliseconds", \
         tUs >= (tMsBefore - 60000) * 1000 and tUs <= (tMsAfter + 60000) * 1000
   TestAssert "microseconds() and the microseconds agree", the microseconds - tUs < 60000000
   TestAssert "microsecs()", microsecs() >= tUs
   TestAssert "microsecond()", microsecond() >= tUs
   TestAssert "microsec()", microsec() >= tUs
end TestMicrosecondsCall

on TestOwnHandlersComeFirst
   -- a stack with its own handlers of these names
   local tStack, tScript
   create invisible stack "HxtCompatOwnHandlers"
   put the long id of it into tStack
   put "function iff pCondition, pTrue, pFalse" & return & \
         "return " & quote & "mine" & quote & return & \
         "end iff" & return & \
         "function quotedPrintableEncode pText" & return & \
         "return " & quote & "mine too" & quote & return & \
         "end quotedPrintableEncode" & return & \
         "function microseconds" & return & \
         "return 42" & return & \
         "end microseconds" into tScript
   set the script of tStack to tScript
   TestAssert "the stack's iff", value("iff(true, 1, 2)", tStack) is "mine"
   TestAssert "the stack's quotedPrintableEncode", value("quotedPrintableEncode(" & quote & "a=b" & quote & ")", tStack) is "mine too"
   TestAssert "the stack's microseconds", value("microseconds()", tStack) is 42
   TestAssert "the library's where the stack has none", value("microsec()", tStack) is an integer
   delete stack "HxtCompatOwnHandlers"
end TestOwnHandlersComeFirst
