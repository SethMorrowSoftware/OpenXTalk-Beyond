script "CoreFieldBidiIsolates"
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

-- Text in which a PDI (U+2069 POP DIRECTIONAL ISOLATE) comes after an
-- isolate that an earlier PDI closed crashed the engine as soon as a field
-- laid it out, on every platform: the bidi algorithm of libfoundation
-- (foundation-bidi.cpp, rule X6a) never counted the closed isolate off, so
-- the next PDI popped its directional stack below its first entry.
-- tperry2x pasted ">>> " FSI PDI PDI " <<<" into a new field (openxtalk.org,
-- October 2026; OXT Lite and LiveCode Community do the same). Each string
-- below must go into a field in each text direction, be laid out, and come
-- back as it went in. On 0.2.7-rc.6.4 the first one ends the engine with
-- signal 11.

-- The string of words pSpec: LRI, RLI, FSI, PDI, LRE, RLE, LRO, RLO and
-- PDF are those characters, HEBREW is two Hebrew letters, SPACE a space,
-- and any other word is itself
private function bidiText pSpec
   local tText
   repeat for each word tWord in pSpec
      switch tWord
         case "LRI"
            put numToCodepoint(0x2066) after tText
            break
         case "RLI"
            put numToCodepoint(0x2067) after tText
            break
         case "FSI"
            put numToCodepoint(0x2068) after tText
            break
         case "PDI"
            put numToCodepoint(0x2069) after tText
            break
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
         case "HEBREW"
            put numToCodepoint(0x05D0) & numToCodepoint(0x05D1) after tText
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

-- Puts pText into a new field in each text direction and checks that it is
-- laid out and reads back unchanged
private command checkInField pWhat, pText
   local tDirection
   create stack "BidiIsolates"
   set the defaultStack to "BidiIsolates"
   create field "Text"
   set the width of field "Text" to 300
   repeat for each item tDirection in "auto,ltr,rtl"
      set the textDirection of field "Text" to tDirection
      set the text of field "Text" to pText
      TestAssert pWhat && "(" & tDirection & ") reads back", \
            the text of field "Text" is pText
      TestAssert pWhat && "(" & tDirection & ") is laid out", \
            the formattedWidth of field "Text" > 0
   end repeat
   -- and typed in after other text, as a paste would put it
   set the textDirection of field "Text" to "auto"
   put "x" into field "Text"
   put pText after char 1 of field "Text"
   TestAssert pWhat && "(after a char) reads back", \
         the text of field "Text" is "x" & pText
   TestAssert pWhat && "(after a char) is laid out", \
         the formattedWidth of field "Text" > 0
   delete stack "BidiIsolates"
end checkInField

on TestTheForumString
   checkInField "the forum's string", \
         ">>> " & numToCodepoint(0x2068) & numToCodepoint(0x2069) & numToCodepoint(0x2069) & " <<<"
end TestTheForumString

on TestPDIAfterAClosedIsolate
   local tSpec
   repeat for each line tSpec in \
         "a LRI b PDI c PDI d" & return & \
         "RLI HEBREW PDI PDI" & return & \
         "FSI HEBREW PDI SPACE PDI SPACE a" & return & \
         "LRI a PDI LRI b PDI PDI PDI c" & return & \
         "LRI LRI a PDI PDI PDI" & return & \
         "LRI x PDI RLE y PDI z" & return & \
         "LRI x PDI LRO y PDI PDF z" & return & \
         "RLI x PDI RLE LRE y PDI PDF PDF z"
      checkInField tSpec, bidiText(tSpec)
   end repeat
end TestPDIAfterAClosedIsolate

-- What did not crash before, as it was: an isolate closed by its PDI, a PDI
-- with no isolate before it, and an isolate that nothing closes
on TestIsolatesThatDidNotCrash
   local tSpec
   repeat for each line tSpec in \
         ">>> FSI a PDI <<<" & return & \
         "a PDI b" & return & \
         "PDI PDI" & return & \
         "LRI a RLI HEBREW PDI b PDI c" & return & \
         "RLI HEBREW" & return & \
         "RLE a PDF PDF b"
      checkInField tSpec, bidiText(tSpec)
   end repeat
end TestIsolatesThatDidNotCrash
