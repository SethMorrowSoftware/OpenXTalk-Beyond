script "CoreInterfaceHyperCardMACE"
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

-- OXT-Beyond: the MACE sounds of HyperCard stacks, decoded at import by
-- the IDE's revHyperCardMACELibrary
-- (ide/Toolset/libraries/revhypercardmacelibrary.livecodescript).

on TestSetup
   TestSkipIfNot "ide"
   start using stack (TestGetIDERepositoryPath() & "/Toolset/libraries/revhypercardmacelibrary.livecodescript")
end TestSetup

-- pCount bytes of a fixed sequence (x := (75x + 74) mod 65537, a byte
-- of each x), so that the vectors below need no data of their own
private function _Bytes pSeed, pCount
   local tBytes, i
   repeat with i = 1 to pCount
      put (pSeed * 75 + 74) mod 65537 into pSeed
      put numToByte(pSeed mod 256) after tBytes
   end repeat
   return tBytes
end _Bytes

private function _Hex pData
   local tHex
   get binaryDecode("H*", pData, tHex)
   return tHex
end _Hex

on TestHyperCardMACEDecoder
   -- the MD5 of what FFmpeg 6.1.1's MACE decoder gives for the same
   -- 600 bytes in an AIFF-C file (ffmpeg -i x.aifc -f s16le), seed,
   -- channels and ratio as in each line: the samples run over the whole
   -- 16-bit range, clipping included
   local tCase, tOut
   repeat for each line tCase in "1,1,3,3600,06a6db9e8aa974486d222aa24e5c4cf1" & return & \
         "2,2,3,3600,9880b444271cc59eda72a5f8fd6af111" & return & \
         "3,1,6,7200,d82e53ced4d893ff4dc836f56aa32e9e" & return & \
         "4,2,6,7200,2226b455d78b5ca00ccd05f9373b7e1b"
      put revHyperCardDecodeMACE(_Bytes(item 1 of tCase, 600), item 2 of tCase, item 3 of tCase) into tOut
      TestAssert "MACE" && item 3 of tCase & ":1," && item 2 of tCase && "channel(s): length", \
            the number of bytes of tOut is item 4 of tCase
      TestAssert "MACE" && item 3 of tCase & ":1," && item 2 of tCase && "channel(s): FFmpeg's samples", \
            _Hex(md5Digest(tOut)) is item 5 of tCase
   end repeat
   TestAssert "no data, no samples", revHyperCardDecodeMACE(empty, 1, 3) is empty
end TestHyperCardMACEDecoder

-- A resource fork with three resources: 'snd ' 9001 "Boing" (MACE 3:1,
-- mono, 600 bytes of _Bytes(1)), 'snd ' 9002 "1" (MACE 6:1, its first
-- 120 bytes: HyperCard stacks often number their sounds so) and 'STR '
-- 128
private function _Fork
   return base64Decode("AAABAAAABIcAAAOHAAAAXAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" & \
         "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" & \
         "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" & \
         "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" & \
         "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAqwAAQABAAUAAACA" & \
         "AAGAUQAAAAAAFAAAAAAAAAABVu5dGAAAAAAAAAAA/jwAAAEsQA2t3RdF0XRdGAAAAABNQUMz" & \
         "AAAAAAAAAAAAAAAAAAMAAAAAAAiV8dmc0/NfAYCt7uwsIKKY0CpSNc55pwMSbKh4O20um5jJ" & \
         "7vSqzo1nTgR1WP/J8z44qZc+VSjfevzn3Ji5YsjHioS0vzh0DhxMb5nvLTowElva/Ppak02c" & \
         "57Oq9IlddXmyMD+pnnmztN9nPJzqjwnbOkJ65qPy6BKPC1/aABgJ2c0Sh46x7zGaLreq4jdC" & \
         "dsn0rGic7zBY31jbUJzUYY/12aDxoqWB9k3J8ijI3lIOIgQtZ1H2RAr13ivP3H7qmd5ITiS6" & \
         "kFjbZgyfpr8o/VEETZYZhRJNjyB35Rw0ey/sX+TVhR27DLw7eC/oQTWPBacbMrVA0PIvBDze" & \
         "DQ5D4nVIRr18b86Ovw4uiBrOW7qL4m33eGc3U1u0AAQzHhDEptP/uA5SLVHLvDWUkYZVCh7i" & \
         "YXKLAC6PFNyI6+aHtO81t939KljXHH3EnOgh2ufiUHgwKpGUXpdCiUfvP6K721HItPYZVkDp" & \
         "VMn6YyZqUfpiuTteoW+2hOVBGwGMHGuI8bO1TZYv9dyRwFObli/fbMd7I2dyfcvC1uOUo+7g" & \
         "0xPQGW5KwyHcgfHYWoOUkHDlQNmyLU7a7YOee03DZ0mPBulrkYTRa2BFPjyw1rqQbkswUc/a" & \
         "5NoR/PXlJd0Jr0U9JkELdWA6J389JelMTEx4WO121z+I6xJnSXmWHyZgUK25TZpNpCIRNvN2" & \
         "nSqHqIC4GxlqFqQRF9oe2aF0QmMfGYOkHZzHhOJlvBrbN2Yb//IN46WeSrZwD4Zes6tiuVHO" & \
         "bLTnuAryLqx9tPpMdVCu+5z5HDW9f0stdXAAAADMAAEAAQAFAAAAgAABgFEAAAAAABQAAAAA" & \
         "AAAAAVbuXRgAAAAAAAAAAP48AAAAeEANrd0XRdF0XRgAAAAATUFDNgAAAAAAAAAAAAAAAAAE" & \
         "AAAAAAAIlfHZnNPzXwGAre7sLCCimNAqUjXOeacDEmyoeDttLpuYye70qs6NZ04EdVj/yfM+" & \
         "OKmXPlUo33r859yYuWLIx4qEtL84dA4cTG+Z7y06MBJb2vz6WpNNnOezqvSJXXV5sjA/qZ55" & \
         "s7TfZzyc6o8J2zpCeuaj8ugSAAAAAwJoaQAAAQAAAASHAAADhwAAAFwAAAAAAAAAAAAcAFIA" & \
         "AXNuZCAAAQASU1RSIAAAACojKQAAAAAAAAAAAAAjKgAGAAACsAAAAAAAgAAIAAADgAAAAAAF" & \
         "Qm9pbmcBMQF4")
end _Fork

private command _Close pStack
   lock messages
   if there is a stack pStack then delete stack pStack
   unlock messages
end _Close

on TestHyperCardMACEConvert
   local tFolder, tStack, tPath, tBinary, tCount, tResult
   put specialFolderPath("temporary") & "/oxt-mace-test-" & the milliseconds into tFolder
   create folder tFolder
   put tFolder & "/Stack" into tPath
   put "data fork" into url ("binfile:" & tPath)
   put _Fork() into url ("binfile:" & tPath & ".rsrc")

   create invisible stack "MACETest"
   put the long id of stack "MACETest" into tStack
   TestAssert "the fork beside the file: two sounds", revHyperCardConvertMACESounds(tStack, tPath) is 2
   TestAssert "a clip named as the resource", there is an audioClip "Boing" of tStack
   TestAssert "a clip named with a number", the short name of audioClip 1 of tStack is "1" \
         or the short name of audioClip 2 of tStack is "1"
   TestAssert "only the sounds", the number of audioClips of tStack is 2
   TestAssert "the ids are kept for the summary", \
         "9001" is among the items of the uHyperCard["mace"] of tStack and \
         "9002" is among the items of the uHyperCard["mace"] of tStack
   TestAssert "a second time adds nothing", revHyperCardConvertMACESounds(tStack, tPath) is 0
   TestAssert "the clips are not doubled", the number of audioClips of tStack is 2
   _Close "MACETest"

   -- a MacBinary file: a 128-byte header, no data fork, the fork
   repeat 128
      put numToByte(0) after tBinary
   end repeat
   put numToByte(5) & "Stack" into byte 2 to 7 of tBinary
   put binaryEncode("N", the number of bytes of _Fork()) into byte 88 to 91 of tBinary
   put _Fork() after tBinary
   put tBinary into url ("binfile:" & tFolder & "/Stack.bin")
   create invisible stack "MACETest"
   put the long id of stack "MACETest" into tStack
   TestAssert "a MacBinary file's fork", revHyperCardConvertMACESounds(tStack, tFolder & "/Stack.bin") is 2
   _Close "MACETest"

   -- no fork at all
   delete file (tPath & ".rsrc")
   create invisible stack "MACETest"
   put the long id of stack "MACETest" into tStack
   put revHyperCardConvertMACESounds(tStack, tPath) into tCount
   put the result into tResult
   TestAssert "no fork: empty", tCount is empty
   TestAssert "no fork: the result says so", tResult is not empty
   TestAssert "no fork: no clips", the number of audioClips of tStack is 0
   _Close "MACETest"

   delete file tPath
   delete file (tFolder & "/Stack.bin")
   delete folder tFolder
end TestHyperCardMACEConvert
