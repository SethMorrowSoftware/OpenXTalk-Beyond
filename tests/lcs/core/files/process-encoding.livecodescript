script "CoreFilesProcessEncoding"
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

/*
The bytes "write ... to process" sends, in each mode a process can be
opened in. Until rc.6.15 the engine encoded the text twice over
(MCFilesProcessWriteEncoding in engine/src/exec-files.cpp says how), so on
Linux text and binary writes went out as UTF-16, on macOS binary data went
out UTF-8 encoded, and "UTF-8" went out as UTF-16LE everywhere.

On Linux and macOS the bytes are read back exactly: through od, which
prints each byte it is given in hex, to a file, once the engine closes
its input (writing numToChar(4) to a process in text mode does that), and
through cat for binary mode, which has no end-of-input character. Windows has
neither tool, so there cmd.exe has to run what it was sent.
*/

constant kTimeout = 10

-- The hex of the bytes od was sent by "write pText & numToChar(4)" to a
-- process opened for pEncoding text update (empty: plain "text").
--
-- od writes to a file, not back to the engine: "read from process" decodes
-- what it reads in the process's encoding too, so od's ASCII read back
-- through a UTF-16 process would be garbled. The script od runs in takes
-- its paths from the arguments, because the engine splits a process's
-- name at spaces without quoting.
private function __BytesSentInTextMode pEncoding, pText
   local tFolder, tScript, tOutFile, tProcess, tOutput, tTry
   put the tempName into tFolder
   create folder tFolder
   put tFolder & "/od.sh" into tScript
   put tFolder & "/out.txt" into tOutFile
   put "od -An -tx1 -v > " & quote & "$1" & quote & LF into url ("binfile:" & tScript)
   put "/bin/sh" && tScript && tOutFile into tProcess
   if pEncoding is empty then
      open process tProcess for text write
   else
      open process tProcess for pEncoding text write
   end if
   write pText & numToChar(4) to process tProcess
   -- The engine closed od's input at numToChar(4); od writes its few lines
   -- in one go when it ends.
   repeat with tTry = 1 to kTimeout * 10
      put url ("binfile:" & tOutFile) into tOutput
      if tOutput ends with LF then exit repeat
      wait 100 millisecs with messages
   end repeat
   close process tProcess
   delete file tOutFile
   delete file tScript
   delete folder tFolder
   replace space with empty in tOutput
   replace LF with empty in tOutput
   replace CR with empty in tOutput
   return toLower(tOutput)
end __BytesSentInTextMode

private function __Hex pBytes
   local tHex
   get binaryDecode("H*", pBytes, tHex)
   return toLower(tHex)
end __Hex

-- Text with characters the encodings tell apart: ASCII, one from Latin-1
-- and one beyond it.
private function __SampleText
   return "Ab" & numToCodepoint(233) & numToCodepoint(0x20AC) & "z"
end __SampleText

on TestWriteToProcessText
   TestSkipIfNot "platform", "MacOS,Linux"

   -- Text, and native text, go out in the platform's native charset, as the
   -- dictionary says (ISO-8859-1 on Linux). On macOS they go out as UTF-8,
   -- as they have since LiveCode 7, so that scripts keep working.
   local tText, tExpected
   put "Ab" & numToCodepoint(233) & LF into tText
   if the platform is "MacOS" then
      put __Hex(textEncode(tText, "UTF-8")) into tExpected
   else
      put __Hex(textEncode(tText, "native")) into tExpected
   end if

   TestAssert "text writes" && tExpected, __BytesSentInTextMode(empty, tText) is tExpected
   TestAssert "native text writes" && tExpected, __BytesSentInTextMode("native", tText) is tExpected
end TestWriteToProcessText

on TestWriteToProcessUnicodeEncodings
   TestSkipIfNot "platform", "MacOS,Linux"

   local tText, tEncoding, tExpected, tSent
   put __SampleText() into tText
   repeat for each item tEncoding in "UTF-8,UTF-16,UTF-16LE,UTF-16BE"
      put __Hex(textEncode(tText, tEncoding)) into tExpected
      put __BytesSentInTextMode(tEncoding, tText) into tSent
      TestDiagnostic tEncoding & ": sent" && tSent
      TestAssert tEncoding && "text writes" && tExpected, tSent is tExpected
   end repeat
end TestWriteToProcessUnicodeEncodings

on TestWriteToProcessTextLineEndings
   TestSkipIfNot "platform", "MacOS,Linux"

   -- Text mode still turns return into the platform's line feed, and still
   -- stops at numToChar(4) and closes the process's input there.
   TestAssert "CR becomes LF", __BytesSentInTextMode(empty, "a" & CR & "b") is "610a62"
   TestAssert "UTF-8 text: CR becomes LF", \
         __BytesSentInTextMode("UTF-8", "a" & CR & "b") is "610a62"
end TestWriteToProcessTextLineEndings

on TestWriteToProcessBinary
   TestSkipIfNot "platform", "MacOS,Linux"

   -- Binary mode sends the bytes as they are, on every platform.
   local tProcess, tBytes
   put "/bin/cat" into tProcess
   put numToByte(0) & numToByte(200) & numToByte(255) & "AB" & numToByte(13) into tBytes
   open process tProcess for binary update
   write tBytes to process tProcess
   read from process tProcess for 6 bytes in kTimeout seconds
   TestDiagnostic "binary: cat returned" && __Hex(it)
   TestAssert "binary writes the bytes as they are", __Hex(it) is "00c8ff41420d"
   close process tProcess
end TestWriteToProcessBinary

on TestWriteToProcessWindows
   TestSkipIfNot "platform", "Win32"

   -- cmd.exe runs a command it was sent in UTF-8 (UTF-16LE before
   -- rc.6.15, which it could not read), in binary, and in text (which was
   -- right on Windows before too).
   local tMode, tProcess, tOutput
   put "cmd.exe" into tProcess
   repeat for each item tMode in "text,UTF-8,binary"
      put empty into tOutput
      switch tMode
         case "text"
            open process tProcess for text update
            break
         case "binary"
            open process tProcess for binary update
            break
         default
            open process tProcess for tMode text update
      end switch
      if tMode is "binary" then
         write "echo foo" & tMode & CR & LF to process tProcess
      else
         write "echo foo" & tMode & return to process tProcess
      end if
      read from process tProcess until ("foo" & tMode) in kTimeout seconds
      read from process tProcess until ("foo" & tMode) in kTimeout seconds
      put it into tOutput
      TestDiagnostic tMode & ": cmd.exe printed" && tOutput
      TestAssert tMode && "write is run by cmd.exe", tOutput ends with ("foo" & tMode)
      close process tProcess
   end repeat
end TestWriteToProcessWindows
