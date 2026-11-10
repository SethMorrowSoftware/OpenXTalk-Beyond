script "CoreMultimediaAudioClipExport"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

/*
`export audioClip "x" to file "x.wav"` writes a clip back out as a sound
file with its header (WAV, AIFF or AU), and `export videoClip` the file a
video clip was imported from. Until OXT-Beyond 9.7.1 neither line
compiled ("export: missing 'to'"), and a clip's sound could be played but
never got back out. A WAV file of the engine's own layout (a 44-byte
header) comes back byte for byte; AIFF and AU are checked byte by byte
against what the formats say. The HyperCard importer's sounds are
exported in hypercard-import.livecodescript.
*/

-- pValue as pCount bytes, little-endian, two's complement
private function _LE pValue, pCount
   local tBytes, tValue
   put pValue into tValue
   if tValue < 0 then
      put tValue + 256 ^ pCount into tValue
   end if
   repeat pCount times
      put numToByte(tValue mod 256) after tBytes
      put tValue div 256 into tValue
   end repeat
   return tBytes
end _LE

-- pValue as pCount bytes, big-endian, two's complement
private function _BE pValue, pCount
   local tBytes, tValue
   put pValue into tValue
   if tValue < 0 then
      put tValue + 256 ^ pCount into tValue
   end if
   repeat pCount times
      put numToByte(tValue mod 256) before tBytes
      put tValue div 256 into tValue
   end repeat
   return tBytes
end _BE

private function _Hex pData
   local tHex
   get binaryDecode("H*", pData, tHex)
   return toUpper(tHex)
end _Hex

-- A WAV file as the engine writes one: a 44-byte header, then pData
private function _Wav pChannels, pBits, pRate, pData
   local tBlock, tSize
   put pChannels * pBits div 8 into tBlock
   put the number of bytes in pData into tSize
   return "RIFF" & _LE(36 + tSize, 4) & "WAVE" & "fmt " & _LE(16, 4) & _LE(1, 2) \
         & _LE(pChannels, 2) & _LE(pRate, 4) & _LE(pRate * tBlock, 4) & _LE(tBlock, 2) \
         & _LE(pBits, 2) & "data" & _LE(tSize, 4) & pData
end _Wav

-- pCount 16-bit samples, a ramp through negative and positive values
private function _Ramp16 pCount, pBigEndian
   local tData, tValue, i
   repeat with i = 0 to pCount - 1
      put (i * 331) mod 60000 - 30000 into tValue
      if pBigEndian then
         put _BE(tValue, 2) after tData
      else
         put _LE(tValue, 2) after tData
      end if
   end repeat
   return tData
end _Ramp16

private function _TempPath pName
   return the temporary folder & "/oxt-aclip-export-" & pName
end _TempPath

-- Imports pBytes as a sound file named pName, and returns the clip's name
private function _ImportBytes pName, pBytes
   local tPath
   put _TempPath(pName) into tPath
   put pBytes into URL ("binfile:" & tPath)
   import audioClip from file tPath
   delete file tPath
   return the short name of the last audioClip
end _ImportBytes

on TestExportAudioClipWaveIsTheFileImported
   local tWav, tClip, tOut, tPath
   put _Wav(1, 16, 8000, _Ramp16(200, false)) into tWav
   put _ImportBytes("ramp16.wav", tWav) into tClip

   export audioClip tClip to tOut
   TestAssert "wave, 16-bit mono: the export is the WAV file imported", _Hex(tOut) is _Hex(tWav)
   TestAssert "wave, 16-bit mono: the result is empty", the result is empty

   put empty into tOut
   export audioClip tClip to tOut as wave
   TestAssert "as wave: the same file", _Hex(tOut) is _Hex(tWav)

   put _TempPath("out.wav") into tPath
   export audioClip tClip to file tPath
   TestAssert "to file: the same file", _Hex(URL ("binfile:" & tPath)) is _Hex(tWav)
   delete file tPath

   -- ac is audioClip's synonym, here as elsewhere
   put empty into tOut
   export ac tClip to tOut
   TestAssert "ac: the same file", _Hex(tOut) is _Hex(tWav)

   delete audioClip tClip
end TestExportAudioClipWaveIsTheFileImported

on TestExportAudioClip8BitStereo
   local tData, tWav, tClip, tOut, i
   repeat with i = 0 to 299
      put numToByte(i mod 256) after tData
   end repeat
   put _Wav(2, 8, 11025, tData) into tWav
   put _ImportBytes("stereo8.wav", tWav) into tClip
   export audioClip tClip to tOut
   TestAssert "wave, 8-bit stereo: the export is the WAV file imported", _Hex(tOut) is _Hex(tWav)
   delete audioClip tClip
end TestExportAudioClip8BitStereo

on TestExportAudioClipAsAiff
   local tClip, tOut
   put _ImportBytes("aiff.wav", _Wav(1, 16, 8000, _Ramp16(200, false))) into tClip
   export audioClip tClip to tOut as aiff
   TestAssert "aiff: FORM", byte 1 to 4 of tOut is "FORM"
   TestAssert "aiff: the FORM's size", _Hex(byte 5 to 8 of tOut) is _Hex(_BE(the number of bytes in tOut - 8, 4))
   TestAssert "aiff: AIFF, COMM", byte 9 to 16 of tOut is "AIFFCOMM"
   TestAssert "aiff: COMM's size", _Hex(byte 17 to 20 of tOut) is "00000012"
   TestAssert "aiff: one channel", _Hex(byte 21 to 22 of tOut) is "0001"
   TestAssert "aiff: 200 frames", _Hex(byte 23 to 26 of tOut) is _Hex(_BE(200, 4))
   TestAssert "aiff: 16 bits", _Hex(byte 27 to 28 of tOut) is "0010"
   -- 8000 as an 80-bit extended number: 2^12 * 1.953125
   TestAssert "aiff: 8000 Hz", _Hex(byte 29 to 38 of tOut) is "400BFA00000000000000"
   TestAssert "aiff: SSND", byte 39 to 42 of tOut is "SSND"
   TestAssert "aiff: SSND's size", _Hex(byte 43 to 46 of tOut) is _Hex(_BE(408, 4))
   TestAssert "aiff: offset and block size 0", _Hex(byte 47 to 54 of tOut) is "0000000000000000"
   TestAssert "aiff: the samples, big-endian", _Hex(byte 55 to -1 of tOut) is _Hex(_Ramp16(200, true))
   delete audioClip tClip
end TestExportAudioClipAsAiff

on TestExportAudioClipAsAu
   local tClip, tOut, tBack, tWav
   put _Wav(2, 16, 22050, _Ramp16(300, false)) into tWav
   put _ImportBytes("au.wav", tWav) into tClip
   export audioClip tClip to tOut as ulaw
   TestAssert "au: .snd", byte 1 to 4 of tOut is ".snd"
   TestAssert "au: the header's size", _Hex(byte 5 to 8 of tOut) is _Hex(_BE(24, 4))
   TestAssert "au: the samples' size", _Hex(byte 9 to 12 of tOut) is _Hex(_BE(600, 4))
   TestAssert "au: 16-bit linear", _Hex(byte 13 to 16 of tOut) is _Hex(_BE(3, 4))
   TestAssert "au: 22050 Hz", _Hex(byte 17 to 20 of tOut) is _Hex(_BE(22050, 4))
   TestAssert "au: two channels", _Hex(byte 21 to 24 of tOut) is _Hex(_BE(2, 4))
   TestAssert "au: the samples, big-endian", _Hex(byte 25 to -1 of tOut) is _Hex(_Ramp16(300, true))
   delete audioClip tClip

   -- the AU file imports again, and comes back out as the WAV it began as
   put _ImportBytes("back.au", tOut) into tBack
   export audioClip tBack to tOut
   TestAssert "au: imported again, the same WAV", _Hex(tOut) is _Hex(tWav)
   delete audioClip tBack
end TestExportAudioClipAsAu

on TestExportAudioClipMulaw
   local tSamples, tAu, tClip, tOut
   put numToByte(255) & numToByte(0) & numToByte(127) & numToByte(128) into tSamples
   put ".snd" & _BE(24, 4) & _BE(4, 4) & _BE(1, 4) & _BE(8000, 4) & _BE(1, 4) & tSamples into tAu
   put _ImportBytes("mulaw.au", tAu) into tClip
   export audioClip tClip to tOut as ulaw
   TestAssert "mu-law: stays mu-law in AU, the file imported", _Hex(tOut) is _Hex(tAu)
   export audioClip tClip to tOut as wave
   -- G.711: 0xFF is 0, 0x00 -32124, 0x7F 0 and 0x80 32124
   TestAssert "mu-law: 16-bit in WAV", _Hex(tOut) is _Hex(_Wav(1, 16, 8000, _LE(0, 2) & _LE(-32124, 2) & _LE(0, 2) & _LE(32124, 2)))
   delete audioClip tClip
end TestExportAudioClipMulaw

on TestExportAudioClipByExtension
   local tClip, tPath, tName
   put _ImportBytes("ext.wav", _Wav(1, 16, 8000, _Ramp16(10, false))) into tClip
   repeat for each item tName in "a.wav,b.aif,c.AIFF,d.aifc,e.au,f.SND,g.txt,h"
      put _TempPath(tName) into tPath
      export audioClip tClip to file tPath
      switch char -4 to -1 of tName
         case ".aif"
         case "aiff"
         case "aifc"
            TestAssert "extension:" && tName && "is AIFF", byte 1 to 4 of URL ("binfile:" & tPath) is "FORM"
            break
         case "e.au"
         case ".snd"
            TestAssert "extension:" && tName && "is AU", byte 1 to 4 of URL ("binfile:" & tPath) is ".snd"
            break
         default
            TestAssert "extension:" && tName && "is WAV", byte 1 to 4 of URL ("binfile:" & tPath) is "RIFF"
      end switch
      delete file tPath
   end repeat
   -- as wins over the extension
   put _TempPath("as.aif") into tPath
   export audioClip tClip to file tPath as wave
   TestAssert "as wave beats .aif", byte 1 to 4 of URL ("binfile:" & tPath) is "RIFF"
   delete file tPath
   delete audioClip tClip
end TestExportAudioClipByExtension

on TestExportAudioClipNotASoundFormat
   local tClip, tOut
   put _ImportBytes("png.wav", _Wav(1, 16, 8000, _Ramp16(10, false))) into tClip
   put "untouched" into tOut
   export audioClip tClip to tOut as PNG
   TestAssert "as PNG: says why", the result is "export: an audioClip exports as wave, aiff or ulaw"
   TestAssert "as PNG: exports nothing", tOut is "untouched"
   delete audioClip tClip
end TestExportAudioClipNotASoundFormat

on TestExportVideoClip
   local tPath, tFile, tOut, tClip
   put TestGetInputFile("testBlankVideo.mpeg") into tPath
   put URL ("binfile:" & tPath) into tFile
   import videoClip from file tPath
   put the long id of the last videoClip into tClip
   export videoClip (the short name of the last videoClip) to tOut
   TestAssert "videoClip: the file imported", _Hex(tOut) is _Hex(tFile)
   put _TempPath("video.mpeg") into tPath
   export vc (the short name of the last videoClip) to file tPath
   TestAssert "videoClip to file: the file imported", _Hex(URL ("binfile:" & tPath)) is _Hex(tFile)
   delete file tPath
   put "untouched" into tOut
   export videoClip (the short name of the last videoClip) to tOut as wave
   TestAssert "videoClip as wave: says why", the result is "export: a videoClip exports as the file it was imported from"
   TestAssert "videoClip as wave: exports nothing", tOut is "untouched"
   delete tClip
end TestExportVideoClip

on TestExportOlderFormsCompileAsBefore
   -- "export audioClip to ..." with nothing after the word compiled
   -- before, and still does
   local tStack
   create invisible stack "OXT Export Compile"
   put the long id of it into tStack
   set the script of tStack to "on t" & return & "local v" & return & "export audioClip to v" & return & "end t"
   TestAssert "export audioClip to v compiles", the result is empty
   set the script of tStack to "on t" & return & "export audioClip " & quote & "x" & quote & " to file " & quote & "x.wav" & quote & " as aiff" & return & "end t"
   TestAssert "the new form compiles", the result is empty
   delete tStack
end TestExportOlderFormsCompileAsBefore
