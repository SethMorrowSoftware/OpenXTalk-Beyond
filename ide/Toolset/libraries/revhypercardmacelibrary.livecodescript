script "revHyperCardMACELibrary"
/*
OXT-Beyond: MACE 3:1 and 6:1 sounds of HyperCard stacks, decoded when
File > Import Stack imports the stack, into audio clips this engine
plays.

MACE (Macintosh Audio Compression/Expansion) is the compression of many
HyperCard stacks' 'snd ' resources. The engine's importer converts the
other sounds and logs these ("Not converting snd ... MACE 3:1
compression"); this library reads them from the stack's resource fork,
decodes them and adds them to the stack as audio clips, named as the
resources are, so that "play" finds them.

The decoder (revHyperCardDecodeMACE and its tables) is a port of
FFmpeg's libavcodec/mace.c to xTalk. It is used only here, in the IDE,
at import (and by the Stack Player, which carries this script): the
engine and standalones never contain it, and a stack keeps the decoded
clips, not this code.

MACE decoder
Copyright (c) 2002 Laszlo Torok <torokl@alpha.dfmk.hu>
Adapted to libavcodec by Francois Revol <revol@free.fr>
Ported to xTalk for OXT-Beyond, 2026.

This file, unlike the rest of OXT-Beyond, is free software that you can
redistribute and/or modify under the terms of the GNU Lesser General
Public License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

It is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with it; if not, write to the Free Software Foundation,
Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

-- The tables, read into arrays (numbered from 0, as in mace.c) the first
-- time a sound is decoded
local sTab1, sTab2, sTab3, sTab4

-- MACEtab1 and MACEtab3: how a code moves the step index
constant kTab1 = "-13,8,76,222,222,76,8,-13"
constant kTab3 = "-18,140,140,-18"
-- MACEtab2 (128 rows of 4) and MACEtab4 (128 rows of 2): the step sizes
constant kTab2 = "37,116,206,330,39,121,216,346,41,127,225,361,42,132,235,377,44,137,245,392,46,144,256,410,48,150,267,428,51,157,280,449,53,165,293,470,55,172,306,490,58,179,319,511,60,187,333,534,63,195,348,557,66,205,364,583,69,214,380,609,72,223,396,635,75,233,414,663,79,244,433,694,82,254,453,725,86,265,472,756,90,278,495,792,94,290,516,826,98,303,538,862,102,316,562,901,107,331,588,942,112,345,614,983,117,361,641,1027,122,377,670,1074,127,394,701,1123,133,411,732,1172,139,430,764,1224,145,449,799,1280,152,469,835,1337,159,490,872,1397,166,512,911,1459,173,535,951,1523,181,558,993,1590,189,584,1038,1663,197,610,1085,1738,206,637,1133,1815,215,665,1183,1895,225,695,1237,1980,235,726,1291,2068,246,759,1349,2161,257,792,1409,2257,268,828,1472,2357,280,865,1538,2463,293,903,1606,2572,306,944,1678,2688,319,986,1753,2807,334,1030,1832,2933,349,1076,1914,3065,364,1124,1999,3202,380,1174,2088,3344,398,1227,2182,3494,415,1281,2278,3649,434,1339,2380,3811,453,1398,2486,3982,473,1461,2598,4160,495,1526,2714,4346,517,1594,2835,4540,540,1665,2961,4741,564,1740,3093,4953,589,1818,3232,5175,615,1898,3375,5405,643,1984,3527,5647,671,2072,3683,5898,701,2164,3848,6161,733,2261,4020,6438,766,2362,4199,6724,800,2467,4386,7024,836,2578,4583,7339,873,2692,4786,7664,912,2813,5001,8008,952,2938,5223,8364,995,3070,5457,8739,1039,3207,5701,9129,1086,3350,5956,9537,1134,3499,6220,9960,1185,3655,6497,10404,1238,3818,6788,10869,1293,3989,7091,11355,1351,4166,7407,11861,1411,4352,7738,12390,1474,4547,8084,12946,1540,4750,8444,13522,1609,4962,8821,14126,1680,5183,9215,14756,1756,5415,9626,15415,1834,5657,10057,16104,1916,5909,10505,16822,2001,6173,10975,17574,2091,6448,11463,18356,2184,6736,11974,19175,2282,7037,12510,20032,2383,7351,13068,20926,2490,7679,13652,21861,2601,8021,14260,22834,2717,8380,14897,23854,2838,8753,15561,24918,2965,9144,16256,26031,3097,9553,16982,27193,3236,9979,17740,28407,3380,10424,18532,29675,3531,10890,19359,31000,3688,11375,20222,32382,3853,11883,21125,32767,4025,12414,22069,32767,4205,12967,23053,32767,4392,13546,24082,32767,4589,14151,25157,32767,4793,14783,26280,32767,5007,15442,27452,32767,5231,16132,28678,32767,5464,16851,29957,32767,5708,17603,31294,32767,5963,18389,32691,32767,6229,19210,32767,32767,6507,20067,32767,32767,6797,20963,32767,32767,7101,21899,32767,32767,7418,22876,32767,32767,7749,23897,32767,32767,8095,24964,32767,32767,8456,26078,32767,32767,8833,27242,32767,32767,9228,28457,32767,32767,9639,29727,32767,32767"
constant kTab4 = "64,216,67,226,70,236,74,246,77,257,80,268,84,280,88,294,92,307,96,321,100,334,104,350,109,365,114,382,119,399,124,416,130,434,136,454,142,475,148,495,155,519,162,541,169,564,176,590,185,617,193,644,201,673,210,703,220,735,230,767,240,801,251,838,262,876,274,914,286,955,299,997,312,1041,326,1089,341,1138,356,1188,372,1241,388,1297,406,1354,424,1415,443,1478,462,1544,483,1613,505,1684,527,1760,551,1838,576,1921,601,2007,628,2097,656,2190,686,2288,716,2389,748,2496,781,2607,816,2724,853,2846,891,2973,930,3104,972,3243,1016,3389,1061,3539,1108,3698,1158,3862,1209,4035,1264,4216,1320,4403,1379,4599,1441,4806,1505,5019,1572,5244,1642,5477,1715,5722,1792,5978,1872,6245,1955,6522,2043,6813,2134,7118,2229,7436,2329,7767,2432,8114,2541,8477,2655,8854,2773,9250,2897,9663,3026,10094,3162,10546,3303,11016,3450,11508,3604,12020,3765,12556,3933,13118,4108,13703,4292,14315,4483,14953,4683,15621,4892,16318,5111,17046,5339,17807,5577,18602,5826,19433,6086,20300,6358,21205,6642,22152,6938,23141,7248,24173,7571,25252,7909,26380,8262,27557,8631,28786,9016,30072,9419,31413,9839,32767,10278,32767,10737,32767,11216,32767,11717,32767,12240,32767,12786,32767,13356,32767,13953,32767,14576,32767,15226,32767,15906,32767,16615,32767"

-- The Unicode code points of MacRoman's characters 128 to 255 (as the
-- disk image library has them: textDecode's "MacRoman" is not available
-- on every platform)
constant kMacRoman = "196,197,199,201,209,214,220,225,224,226,228,227,229,231,233,232,234,235,237,236,238,239,241,243,242,244,246,245,250,249,251,252,8224,176,162,163,167,8226,182,223,174,169,8482,180,168,8800,198,216,8734,177,8804,8805,165,181,8706,8721,8719,960,8747,170,186,937,230,248,191,161,172,8730,402,8776,8710,171,187,8230,160,192,195,213,338,339,8211,8212,8220,8221,8216,8217,247,9674,255,376,8260,8364,8249,8250,64257,64258,8225,183,8218,8222,8240,194,202,193,203,200,205,206,207,204,211,212,63743,210,218,219,217,305,710,732,175,728,729,730,184,733,731,711"

-- 'snd ' as a resource type, and the formats of a compressed sound header
constant kSndType = "snd "
constant kMACE3 = "MAC3"
constant kMACE6 = "MAC6"

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   if the long id of me is not among the lines of the backScripts then
      insert the script of me into back
   end if
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if
   remove the script of me from back
end extensionFinalize

/*
Adds the MACE sounds of a HyperCard stack to the stack as audio clips.

pStack (String): The stack just imported from pPath.

pPath (String): The HyperCard file it was imported from: a MacBinary,
AppleSingle or AppleDouble file, or a data fork whose resource fork the
importer finds, in the importer's order: on a Mac the file's own
resource fork, then ._<name>, a Finder zip's __MACOSX/<path>/._<name>,
.AppleDouble/<name>, <name>.rsrc and .rsrc/<name>.

Returns (String): How many sounds were added, or empty with an error in
the result.

Description:
The importer converts a stack's other sounds itself and logs the MACE
ones it cannot. This finds those in the stack's resource fork, decodes
them and creates one audio clip for each, named as the resource is (or
"snd <id>" when it has no name), so that "play" in the stack's scripts
finds it. A clip of that name that the stack already has is left as it
is. The ids of the sounds added are kept in the stack's
uHyperCard["mace"], which the import summary reads.

File > Import Stack and the Stack Player call it after the import.

References: revHyperCardDecodeMACE (function)
*/
function revHyperCardConvertMACESounds pStack, pPath
   local tFork, tSounds, tId, tAdded, tClip, tTemp, tDone, tOldDefault, tError
   local tClips, i
   if word 1 of pStack is not "stack" then put the long id of stack pStack into pStack
   put _ResourceFork(pPath) into tFork
   if tFork is empty then return "no resource fork" for error
   put _MACESounds(tFork) into tSounds
   if the number of elements of tSounds is 0 then return 0 for value

   put 0 into tAdded
   repeat with i = 1 to the number of audioClips of pStack
      put the short name of audioClip i of pStack & return after tClips
   end repeat
   put the defaultStack into tOldDefault
   set the defaultStack to the short name of pStack
   repeat for each key tId in tSounds
      put tSounds[tId]["name"] into tClip
      if tClip is empty then put "snd" && tId into tClip
      -- by name, never "there is an audioClip": a HyperCard sound is
      -- often named "1", which that would read as a clip's number
      if tClip is among the lines of tClips then next repeat
      put specialFolderPath("temporary") & slash & "oxt-mace-" & tId & "-" & the milliseconds & ".wav" into tTemp
      try
         put _WAV(revHyperCardDecodeMACE(tSounds[tId]["data"], tSounds[tId]["channels"], tSounds[tId]["ratio"]), \
               tSounds[tId]["channels"], tSounds[tId]["rate"]) into url ("binfile:" & tTemp)
         import audioClip from file tTemp
         set the name of last audioClip of pStack to tClip
         put tClip & return after tClips
         add 1 to tAdded
         if tDone is not empty then put comma after tDone
         put tId after tDone
      catch tError
      end try
      delete file tTemp
   end repeat
   if tDone is not empty then set the uHyperCard["mace"] of pStack to tDone
   set the defaultStack to tOldDefault
   return tAdded for value
end revHyperCardConvertMACESounds

/*
Decodes MACE 3:1 or 6:1 samples.

pData (String): The compressed samples, as binary data: for MACE 3:1 two
bytes (six samples) per channel at a time, for MACE 6:1 one byte (six
samples), the channels' bytes one after the other.

pChannels (Number): 1 or 2.

pRatio (Number): 3 for MACE 3:1, 6 for MACE 6:1.

Returns (String): The samples as 16-bit signed little-endian binary data,
the channels interleaved, as a WAV file's data chunk holds them; the same
samples as FFmpeg's decoder gives.

References: revHyperCardConvertMACESounds (function)
*/
function revHyperCardDecodeMACE pData, pChannels, pRatio
   local tMace3, tBytes, tGroups, tChannel, tGroup, tByte, tCode, tPart, tValue
   local tStride, tRow, tCurrent, tIndex, tFactor, tPrev2, tPrevious, tLevel
   local tDelta, tOut, tSamples, tHigh, tSample, tCount, tResult
   _Tables
   put (pRatio is 3) into tMace3
   if tMace3 then put 2 into tBytes else put 1 into tBytes
   if pChannels is not 2 then put 1 into pChannels
   put the number of bytes of pData div (pChannels * tBytes) into tGroups

   repeat with tChannel = 1 to pChannels
      put 0 into tIndex
      put 0 into tFactor
      put 0 into tPrev2
      put 0 into tPrevious
      put 0 into tLevel
      put empty into tOut
      repeat with tGroup = 0 to tGroups - 1
         repeat with tByte = 1 to tBytes
            put byteToNum(byte (tGroup * pChannels * tBytes + (tChannel - 1) * tBytes + tByte) of pData) into tCode
            -- three codes a byte: 3, 2 and 3 bits, read from the low end
            -- for MACE 3:1 and from the high end for MACE 6:1
            repeat with tPart = 1 to 3
               if tPart is 2 then
                  put (tCode div 8) mod 4 into tValue
               else if (tPart is 1) is tMace3 then
                  put tCode mod 8 into tValue
               else
                  put tCode div 32 into tValue
               end if

               -- read_table: the step, then the step index moves
               if tPart is 2 then
                  put ((tIndex bitAnd 2032) div 16) * 2 into tRow
                  if tValue < 2 then
                     put sTab4[tRow + tValue] into tCurrent
                  else
                     put -1 - sTab4[tRow + 3 - tValue] into tCurrent
                  end if
                  put tIndex + sTab3[tValue] - (tIndex div 32) into tIndex
               else
                  put ((tIndex bitAnd 2032) div 16) * 4 into tRow
                  if tValue < 4 then
                     put sTab2[tRow + tValue] into tCurrent
                  else
                     put -1 - sTab2[tRow + 7 - tValue] into tCurrent
                  end if
                  put tIndex + sTab1[tValue] - (tIndex div 32) into tIndex
               end if
               if tIndex < 0 then put 0 into tIndex

               if tMace3 then
                  -- chomp3
                  put _Clip(tCurrent + tLevel) into tCurrent
                  put tCurrent - _Shift(tCurrent, 8) into tLevel
                  put _High(tCurrent) after tOut
               else
                  -- chomp6
                  if (tPrevious >= 0) is (tCurrent >= 0) then
                     put min(tFactor + 506, 32767) into tFactor
                  else if tFactor - 314 < -32768 then
                     put -32767 into tFactor
                  else
                     subtract 314 from tFactor
                  end if
                  put _Clip(tCurrent + tLevel) into tCurrent
                  put _Shift(tCurrent * tFactor, 32768) into tLevel
                  put _Shift(tCurrent, 2) into tCurrent
                  put _Shift(tPrev2 - tCurrent, 4) into tDelta
                  put _High(tPrevious + tPrev2 - tDelta) & _High(tPrevious + tCurrent + tDelta) after tOut
                  put tPrevious into tPrev2
                  put tCurrent into tPrevious
               end if
            end repeat
         end repeat
      end repeat
      put tOut into tSamples[tChannel]
   end repeat

   -- each sample's high byte, twice (mace.c's QT_8S_2_16S), the channels
   -- interleaved
   put the number of bytes of tSamples[1] into tCount
   if pChannels is 1 then
      repeat for each byte tHigh in tSamples[1]
         put tHigh & tHigh after tResult
      end repeat
   else
      repeat with tSample = 1 to tCount
         put byte tSample of tSamples[1] into tHigh
         put tHigh & tHigh after tResult
         put byte tSample of tSamples[2] into tHigh
         put tHigh & tHigh after tResult
      end repeat
   end if
   return tResult
end revHyperCardDecodeMACE

-- mace_broken_clip_int16: as av_clip_int16, but -32767 at the bottom
private function _Clip pValue
   if pValue > 32767 then return 32767
   if pValue < -32768 then return -32767
   return pValue
end _Clip

-- pValue >> n, rounded down as C's shift of a negative number is, for
-- pDivisor 2 ^ n
private function _Shift pValue, pDivisor
   if pValue >= 0 then return pValue div pDivisor
   return -((-pValue - 1) div pDivisor) - 1
end _Shift

-- Bits 8 to 15 of a sample, as one byte
private function _High pValue
   local tWord
   put pValue mod 65536 into tWord
   if tWord < 0 then add 65536 to tWord
   return numToByte(tWord div 256)
end _High

private command _Tables
   local tValue, tCount
   if sTab2 is an array then exit _Tables
   put 0 into tCount
   repeat for each item tValue in kTab1
      put tValue into sTab1[tCount]
      add 1 to tCount
   end repeat
   put 0 into tCount
   repeat for each item tValue in kTab2
      put tValue into sTab2[tCount]
      add 1 to tCount
   end repeat
   put 0 into tCount
   repeat for each item tValue in kTab3
      put tValue into sTab3[tCount]
      add 1 to tCount
   end repeat
   put 0 into tCount
   repeat for each item tValue in kTab4
      put tValue into sTab4[tCount]
      add 1 to tCount
   end repeat
end _Tables

-- A big-endian unsigned number of pLength bytes at byte pAt of pData
private function _Number pData, pAt, pLength
   local tNumber, i
   put 0 into tNumber
   repeat with i = pAt to pAt + pLength - 1
      put tNumber * 256 + byteToNum(byte i of pData) into tNumber
   end repeat
   return tNumber
end _Number

-- The resource fork of a HyperCard file, where the importer finds it
-- (MCHcstak::read and readsidecarresources in engine/src/hc.cpp), in its
-- order, so that both read the same fork: inside the file (MacBinary,
-- AppleSingle, AppleDouble); else, for a bare data fork, the file's own
-- fork on a Mac, ._Name, __MACOSX/<path>/._Name in each of the 8 folders
-- above it (a Finder zip unpacked anywhere), .AppleDouble/Name,
-- Name.rsrc and .rsrc/Name
private function _ResourceFork pPath
   local tFile, tFork, tFolder, tLeaf, tCandidate, tCandidates, tAbove, tBelow, tLevel
   if there is not a file pPath then return empty
   put url ("binfile:" & pPath) into tFile
   put _ForkOf(tFile) into tFork
   if tFork is not empty then return tFork

   set the itemDelimiter to slash
   put item -1 of pPath into tLeaf
   put item 1 to -2 of pPath into tFolder
   if tFolder is not empty then put slash after tFolder
   put pPath & "/..namedfork/rsrc" & return & tFolder & "._" & tLeaf & return into tCandidates
   put tFolder into tAbove
   repeat with tLevel = 1 to 8
      put tAbove & "__MACOSX/" & tBelow & "._" & tLeaf & return after tCandidates
      -- one folder up: tAbove ("/a/b/") gives its last folder ("b/") to
      -- the front of tBelow; a stack inside __MACOSX stops the search
      -- (a trailing slash makes no item of its own)
      if the number of items of tAbove < 2 or item -1 of tAbove is "__MACOSX" then exit repeat
      put item -1 of tAbove & slash before tBelow
      put item 1 to -2 of tAbove & slash into tAbove
   end repeat
   put tFolder & ".AppleDouble/" & tLeaf & return & pPath & ".rsrc" & return \
         & tFolder & ".rsrc/" & tLeaf after tCandidates
   set the itemDelimiter to comma

   repeat for each line tCandidate in tCandidates
      if there is not a file tCandidate then next repeat
      put url ("binfile:" & tCandidate) into tFile
      put _ForkOf(tFile) into tFork
      if tFork is not empty then return tFork
      -- a raw fork: its header's offsets fit the file
      if _IsFork(tFile) then return tFile
   end repeat
   return empty
end _ResourceFork

-- The resource fork inside a MacBinary, AppleSingle or AppleDouble file
private function _ForkOf pFile
   local tMagic, tEntries, i, tAt, tLength, tData
   if the number of bytes of pFile < 128 then return empty
   -- AppleSingle (0x00051600) and AppleDouble (0x00051607): entry 2
   put _Number(pFile, 1, 4) into tMagic
   if tMagic is 333312 or tMagic is 333319 then
      put _Number(pFile, 25, 2) into tEntries
      repeat with i = 0 to tEntries - 1
         if _Number(pFile, 27 + i * 12, 4) is 2 then
            put _Number(pFile, 31 + i * 12, 4) into tAt
            put _Number(pFile, 35 + i * 12, 4) into tLength
            return byte tAt + 1 to tAt + tLength of pFile
         end if
      end repeat
      return empty
   end if
   -- MacBinary: a zero byte, a name of 1 to 63 bytes, a zero at 74 and 82
   if byteToNum(byte 1 of pFile) is 0 and byteToNum(byte 75 of pFile) is 0 \
         and byteToNum(byte 2 of pFile) >= 1 and byteToNum(byte 2 of pFile) <= 63 then
      put _Number(pFile, 84, 4) into tData
      put _Number(pFile, 88, 4) into tLength
      put 128 + ((tData + 127) div 128) * 128 into tAt
      if tLength > 0 and tAt + tLength <= the number of bytes of pFile then
         return byte tAt + 1 to tAt + tLength of pFile
      end if
   end if
   return empty
end _ForkOf

-- Whether pData looks like a resource fork: its data and map lie inside it
private function _IsFork pData
   local tData, tMap, tDataLength, tMapLength
   if the number of bytes of pData < 16 then return false
   put _Number(pData, 1, 4) into tData
   put _Number(pData, 5, 4) into tMap
   put _Number(pData, 9, 4) into tDataLength
   put _Number(pData, 13, 4) into tMapLength
   return tMapLength >= 30 and tData + tDataLength <= the number of bytes of pData \
         and tMap + tMapLength <= the number of bytes of pData
end _IsFork

-- The MACE sounds of a resource fork, by id: their name, channels, rate
-- (samples a second), ratio (3 or 6) and compressed samples
private function _MACESounds pFork
   local tData, tMap, tTypes, tNames, tCount, i, tType, tRefs, tList, j
   local tRef, tId, tNameAt, tAt, tLength, tName, tSound, tSounds
   if not _IsFork(pFork) then return empty
   -- resource types are four bytes, compared exactly
   set the caseSensitive to true
   put _Number(pFork, 1, 4) into tData
   put _Number(pFork, 5, 4) into tMap
   put tMap + _Number(pFork, tMap + 25, 2) into tTypes
   put tMap + _Number(pFork, tMap + 27, 2) into tNames
   put _Number(pFork, tTypes + 1, 2) + 1 into tCount
   if tCount > 1000 then return empty
   repeat with i = 0 to tCount - 1
      put tTypes + 2 + i * 8 into tType
      if byte tType + 1 to tType + 4 of pFork is not kSndType then next repeat
      put _Number(pFork, tType + 5, 2) + 1 into tRefs
      put tTypes + _Number(pFork, tType + 7, 2) into tList
      repeat with j = 0 to tRefs - 1
         put tList + j * 12 into tRef
         put _Number(pFork, tRef + 1, 2) into tId
         if tId >= 32768 then subtract 65536 from tId
         put _Number(pFork, tRef + 3, 2) into tNameAt
         put tData + _Number(pFork, tRef + 6, 3) into tAt
         put _Number(pFork, tAt + 1, 4) into tLength
         if tAt + 4 + tLength > the number of bytes of pFork then next repeat
         put _Sound(byte tAt + 5 to tAt + 4 + tLength of pFork) into tSound
         if tSound is not an array then next repeat
         put empty into tName
         if tNameAt is not 65535 then
            put tNames + tNameAt into tNameAt
            put _PString(pFork, tNameAt) into tName
         end if
         put tName into tSound["name"]
         put tSound into tSounds[tId]
      end repeat
   end repeat
   return tSounds
end _MACESounds

-- The Pascal string (a length byte, then MacRoman text) at byte
-- pAt + 1 of pData
private function _PString pData, pAt
   local tText, tCode, i
   repeat with i = pAt + 2 to pAt + 1 + byteToNum(byte pAt + 1 of pData)
      put byteToNum(byte i of pData) into tCode
      if tCode < 128 then
         put numToCodepoint(tCode) after tText
      else
         put numToCodepoint(item tCode - 127 of kMacRoman) after tText
      end if
   end repeat
   return tText
end _PString

-- A 'snd ' resource whose sound is MACE: format 1 or 2, its first
-- command's second parameter the offset of a compressed sound header
-- (encode 0xFE). Inside Macintosh: Sound, 2-104 to 2-111, and the
-- importer's MCHcsnd::import.
private function _Sound pSnd
   local tType, tCommands, tHeader, tFormat, tCompression, tSound, tBase
   if the number of bytes of pSnd < 4 then return empty
   put _Number(pSnd, 1, 2) into tType
   if tType is 1 then
      put 4 + _Number(pSnd, 3, 2) * 6 into tCommands
   else if tType is 2 then
      put 4 into tCommands
   else
      return empty
   end if
   if tCommands + 10 > the number of bytes of pSnd then return empty
   put _Number(pSnd, tCommands + 7, 4) into tHeader
   if tHeader + 64 > the number of bytes of pSnd then return empty
   if byteToNum(byte tHeader + 21 of pSnd) is not 254 then return empty
   put byte tHeader + 41 to tHeader + 44 of pSnd into tFormat
   put _Number(pSnd, tHeader + 57, 2) into tCompression
   if tFormat is kMACE3 or tCompression is 3 then
      put 3 into tSound["ratio"]
   else if tFormat is kMACE6 or tCompression is 4 then
      put 6 into tSound["ratio"]
   else
      return empty
   end if
   put _Number(pSnd, tHeader + 5, 4) into tSound["channels"]
   if tSound["channels"] is not 2 then put 1 into tSound["channels"]
   -- the rate, as the importer reads it: the whole part of a fixed
   -- number, then moved by the base frequency (60, middle C, moves it
   -- by nothing)
   put _Number(pSnd, tHeader + 9, 2) into tSound["rate"]
   put byteToNum(byte tHeader + 22 of pSnd) into tBase
   if tBase is 0 then put 60 into tBase
   put round(tSound["rate"] / (1.05946309434 ^ (tBase - 60))) into tSound["rate"]
   if tSound["rate"] < 1 then put 22254 into tSound["rate"]
   put byte tHeader + 65 to -1 of pSnd into tSound["data"]
   return tSound
end _Sound

-- A WAV file of 16-bit samples
private function _WAV pSamples, pChannels, pRate
   local tLength
   put the number of bytes of pSamples into tLength
   return "RIFF" & _LE(tLength + 36, 4) & "WAVEfmt " & _LE(16, 4) & _LE(1, 2) & _LE(pChannels, 2) \
         & _LE(pRate, 4) & _LE(pRate * pChannels * 2, 4) & _LE(pChannels * 2, 2) & _LE(16, 2) \
         & "data" & _LE(tLength, 4) & pSamples
end _WAV

-- pNumber as pLength bytes, little-endian, as WAV files keep numbers
private function _LE pNumber, pLength
   local tBytes, i
   repeat with i = 1 to pLength
      put numToByte(pNumber mod 256) after tBytes
      put pNumber div 256 into pNumber
   end repeat
   return tBytes
end _LE
