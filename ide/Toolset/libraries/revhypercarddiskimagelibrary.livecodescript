script "revHyperCardDiskImageLibrary"
-- OXT-Beyond: HyperCard stacks inside Mac disk images.
--
-- Most HyperCard stacks that survive are on disk images: floppy images
-- (raw or DiskCopy 4.2), and CD images whose HFS volume sits behind an
-- Apple partition map, often beside an ISO 9660 one (Toast's hybrid
-- CDs). Other systems cannot open those volumes, and a stack copied off
-- one by other means loses its resource fork. This library reads plain
-- HFS (not HFS+) itself: it lists the stacks on a volume and copies one
-- out, its data fork as <name> and its resource fork beside it as
-- <name>.rsrc, which the HyperCard importer reads as the stack's fork.
--
-- Read only: nothing here writes to the image. Every number on an HFS
-- volume is big-endian; offsets in the comments are from the start of
-- the structure named. References: Inside Macintosh: Files (1992),
-- chapter 2, "Data Organization on Volumes", and Inside Macintosh:
-- Devices, chapter 3 (the partition map).

-- What was read of the last image, so that listing and then extracting
-- from it reads its catalog once: the image's path and modification
-- date, the volume's offset in the image, its allocation block size and
-- first allocation block (in bytes), the catalog's and the extents
-- tree's extents, the extents tree's records, and the catalog's files
-- and folders
local sImage, sImageStamp
local sVolume
local sDirs, sFiles, sOverflow

constant kSector = 512

-- The Unicode code points of MacRoman's characters 128 to 255
constant kMacRoman = "196,197,199,201,209,214,220,225,224,226,228,227,229,231,233,232,234,235,237,236,238,239,241,243,242,244,246,245,250,249,251,252,8224,176,162,163,167,8226,182,223,174,169,8482,180,168,8800,198,216,8734,177,8804,8805,165,181,8706,8721,8719,960,8747,170,186,937,230,248,191,161,172,8730,402,8776,8710,171,187,8230,160,192,195,213,338,339,8211,8212,8220,8221,8216,8217,247,9674,255,376,8260,8364,8249,8250,64257,64258,8225,183,8218,8222,8240,194,202,193,203,200,205,206,207,204,211,212,63743,210,218,219,217,305,710,732,175,728,729,730,184,733,731,711"

-- The IDE loads this library at startup (revInternal__LoadLibrary, which
-- sends extensionInitialize); without these handlers it was loaded but
-- never put in the message path, so File > Import Stack could not call it
-- and stopped without a word
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
Lists the HyperCard stacks on the HFS volume in a disk image.

pImage (String): The path of the disk image: a raw HFS volume, a
DiskCopy 4.2 image, or a disk or CD image with an Apple partition map.

Returns (String): One line per stack, in the order of the volume's
catalog: the stack's HFS path (the volume name, then each folder, then
the file, separated by colons), a tab, the size of its data fork, a tab,
and the size of its resource fork. Empty with an error in the result
when the file holds no HFS volume.

Description:
A stack is a file of type STAK, or a file whose data fork starts as a
HyperCard stack does, whatever its type. Names are converted from
MacRoman.
*/
function revHyperCardImageStacks pImage
   local tError, tList, tFile
   put __hciLoad(pImage) into tError
   if tError is not empty then return tError for error
   repeat for each line tFile in sFiles["order"]
      if not __hciIsStack(tFile) then next repeat
      put __hciPath(sFiles[tFile]["parent"], sFiles[tFile]["name"]) & tab & \
            sFiles[tFile]["datasize"] & tab & sFiles[tFile]["rsrcsize"] & return after tList
   end repeat
   delete the last char of tList
   return tList for value
end revHyperCardImageStacks

/*
Tells whether a file is a disk image with an HFS volume on it.

pImage (String): The path of the file.

Returns (Boolean): True if the file is a raw HFS volume, a DiskCopy 4.2
image of one, or an image with an Apple partition map that holds one.
*/
function revHyperCardIsDiskImage pImage
   return __hciFindVolume(pImage) is a number
end revHyperCardIsDiskImage

/*
Copies a stack out of a disk image, with its resource fork.

pImage (String): The path of the disk image.

pStackPath (String): The stack's HFS path, as <revHyperCardImageStacks>
lists it.

pFolder (String): The folder to copy the stack into. It must exist.

Returns (String): The path of the copied data fork; the resource fork,
if the file has one, is beside it with ".rsrc" added to its name. Empty
with an error in the result if the image or the file cannot be read.

Description:
The copy is named after the file on the volume, with any slash or colon
replaced by a hyphen. A file of that name in pFolder is replaced.
*/
function revHyperCardImageExtract pImage, pStackPath, pFolder
   local tError, tEach, tFile, tData, tName, tPath
   put __hciLoad(pImage) into tError
   if tError is not empty then return tError for error
   repeat for each line tEach in sFiles["order"]
      if __hciPath(sFiles[tEach]["parent"], sFiles[tEach]["name"]) is pStackPath then
         put tEach into tFile
         exit repeat
      end if
   end repeat
   if tFile is empty then return "no such file on the volume:" && pStackPath for error
   put sFiles[tFile]["name"] into tName
   replace slash with "-" in tName
   replace colon with "-" in tName
   if pFolder ends with slash then delete the last char of pFolder
   put pFolder & slash & tName into tPath

   put __hciReadFork(pImage, tFile, "data") into tData
   put the result into tError
   if tError is not empty then return tError for error
   put tData into url ("binfile:" & tPath)
   put the result into tError
   if tError is not empty then return "could not write" && tPath & ":" && tError for error
   if sFiles[tFile]["rsrcsize"] > 0 then
      put __hciReadFork(pImage, tFile, "rsrc") into tData
      put the result into tError
      if tError is not empty then return tError for error
      put tData into url ("binfile:" & tPath & ".rsrc")
      put the result into tError
      if tError is not empty then return "could not write" && tPath & ".rsrc:" && tError for error
   end if
   return tPath for value
end revHyperCardImageExtract

/*
Asks which stack of a disk image to import.

pImage (String): The path of the disk image.

Returns (String): The HFS path of the stack chosen, as
<revHyperCardImageStacks> lists it, or empty if none was (Cancel, or no
stack on the volume, which the dialog says). An error in the result if
the image cannot be read.

Description:
A modal dialog lists the stacks with their folders; typing in the box
above the list narrows it to the paths that contain what was typed.
*/
function revHyperCardImageChoose pImage
   local tList, tError, tStack, tChosen
   put revHyperCardImageStacks(pImage) into tList
   put the result into tError
   if tError is not empty then return tError for error
   if tList is empty then
      answer information "There are no HyperCard stacks on this disk image."
      return empty for value
   end if
   put revHyperCardImageChooser(pImage, tList) into tStack
   modal stack tStack
   put the cChosen of stack tStack into tChosen
   delete stack tStack
   return tChosen for value
end revHyperCardImageChoose

/*
Makes the dialog <revHyperCardImageChoose> shows.

pImage (String): The path of the disk image, which the dialog names.

pList (String): The stacks, as <revHyperCardImageStacks> lists them.

Returns (String): The long id of the dialog, an invisible stack, which
the caller deletes. Once it has closed, its cChosen property is the HFS
path of the stack chosen, or empty.

Description:
The dialog is made by script, so that it needs no stack file: a search
box, the list, Import and Cancel.
*/
function revHyperCardImageChooser pImage, pList
   local tStack, tLines, tLine, tDefault
   put "revHyperCardImageChooser" into tStack
   put the defaultStack into tDefault
   if there is a stack tStack then delete stack tStack
   lock messages
   create invisible stack tStack
   set the title of stack tStack to "Import a HyperCard Stack"
   set the rect of stack tStack to 0,0,560,420
   set the resizable of stack tStack to false
   set the defaultStack to tStack
   -- the list shows each stack's path without the sizes
   set the itemDelimiter to tab
   put empty into tLines
   repeat for each line tLine in pList
      put item 1 of tLine & return after tLines
   end repeat
   delete the last char of tLines
   set the cAll of stack tStack to tLines
   set the cChosen of stack tStack to empty

   create field "Label"
   set the rect of field "Label" to 16,12,544,32
   set the lockText of field "Label" to true
   set the opaque of field "Label" to false
   set the showBorder of field "Label" to false
   set the traversalOn of field "Label" to false
   set the text of field "Label" to "The stacks on" && quote & __hciLeaf(pImage) & quote & ":"

   create field "Search"
   set the rect of field "Search" to 16,36,544,60
   set the script of field "Search" to __hciScript( \
         "on textChanged" & return & \
         "   local tLines" & return & \
         "   put the cAll of this stack into tLines" & return & \
         "   if me is not empty then filter lines of tLines with `*` & me & `*`" & return & \
         "   set the text of field `List` to tLines" & return & \
         "   if tLines is not empty then set the hilitedLine of field `List` to 1" & return & \
         "end textChanged")

   create field "List"
   set the rect of field "List" to 16,68,544,368
   set the listBehavior of field "List" to true
   set the lockText of field "List" to true
   set the multipleHilites of field "List" to false
   set the vScrollbar of field "List" to true
   set the dontWrap of field "List" to true
   set the text of field "List" to tLines
   set the hilitedLine of field "List" to 1
   set the script of field "List" to __hciScript( \
         "on mouseDoubleUp" & return & \
         "   if the hilitedLine of me is not empty then send `mouseUp` to button `Import`" & return & \
         "end mouseDoubleUp")

   create button "Cancel"
   set the rect of button "Cancel" to 352,380,444,404
   set the script of button "Cancel" to __hciScript( \
         "on mouseUp" & return & \
         "   set the cChosen of this stack to empty" & return & \
         "   close this stack" & return & \
         "end mouseUp")

   create button "Import"
   set the rect of button "Import" to 452,380,544,404
   set the default of button "Import" to true
   set the script of button "Import" to __hciScript( \
         "on mouseUp" & return & \
         "   if the hilitedLine of field `List` is empty then exit mouseUp" & return & \
         "   set the cChosen of this stack to line (the hilitedLine of field `List`) of field `List`" & return & \
         "   close this stack" & return & \
         "end mouseUp")
   unlock messages
   set the defaultStack to tDefault
   return the long id of stack tStack
end revHyperCardImageChooser

-- A script for the dialog, written with ` for each quote
private function __hciScript pScript
   replace "`" with quote in pScript
   return pScript
end __hciScript

private function __hciLeaf pPath
   set the itemDelimiter to slash
   return item -1 of pPath
end __hciLeaf

--------------------------------------------------------------------------------
-- Reading the image

private function __hciRead pImage, pOffset, pLength
   local tData
   open file pImage for binary read
   if the result is not empty then return empty
   -- "at" counts from 1
   read from file pImage at pOffset + 1 for pLength
   put it into tData
   close file pImage
   return tData
end __hciRead

private function __hciU16 pData, pOffset
   local tValue
   get binaryDecode("m", byte pOffset + 1 to pOffset + 2 of pData, tValue)
   return tValue
end __hciU16

private function __hciU32 pData, pOffset
   local tValue
   get binaryDecode("M", byte pOffset + 1 to pOffset + 4 of pData, tValue)
   return tValue
end __hciU32

-- A Pascal string (a length byte, then MacRoman text), converted here:
-- textDecode's "MacRoman" is not available on every platform
private function __hciPString pData, pOffset
   local tLength, tText, tCode
   put byteToNum(byte pOffset + 1 of pData) into tLength
   repeat with i = pOffset + 2 to pOffset + 1 + tLength
      put byteToNum(byte i of pData) into tCode
      if tCode < 128 then
         put numToCodepoint(tCode) after tText
      else
         put numToCodepoint(item tCode - 127 of kMacRoman) after tText
      end if
   end repeat
   return tText
end __hciPString

-- The byte offset of the HFS volume in the image (its first sector, two
-- before the master directory block), or an error
private function __hciFindVolume pImage
   local tHeader, tBlockSize, tEntries, tEntry, tAt
   if there is not a file pImage then return "no such file"
   -- a raw volume: the master directory block's signature, "BD", at 1024
   put __hciRead(pImage, 0, 2048) into tHeader
   if byte 1025 to 1026 of tHeader is "BD" then return 0
   -- DiskCopy 4.2: an 84-byte header, then the volume; its last word is
   -- 0x0100
   if byteToNum(byte 83 of tHeader) is 1 and byteToNum(byte 84 of tHeader) is 0 then
      if byte 84 + 1025 to 84 + 1026 of __hciRead(pImage, 0, 84 + 2048) is "BD" then return 84
   end if
   -- an Apple partition map: the driver descriptor ("ER") in block 0,
   -- then one entry ("PM") per block from block 1, each naming its type,
   -- first block and length
   if byte 1 to 2 of tHeader is "ER" then
      put __hciU16(tHeader, 2) into tBlockSize
      if tBlockSize is 0 then put kSector into tBlockSize
      -- the map's entries are 512 bytes apart whatever the block size
      put kSector into tAt
      put 1 into tEntries
      repeat with tEntry = 1 to 256
         if tEntry > tEntries then exit repeat
         put __hciRead(pImage, tEntry * kSector, kSector) into tHeader
         if byte 1 to 2 of tHeader is not "PM" then exit repeat
         put __hciU32(tHeader, 4) into tEntries
         if byte 49 to 57 of tHeader is "Apple_HFS" then
            -- the first block, in 512-byte blocks on the images seen (CDs
            -- included), else in the driver descriptor's
            put __hciU32(tHeader, 8) * kSector into tAt
            if byte 1025 to 1026 of __hciRead(pImage, tAt, 2048) is "BD" then return tAt
            put __hciU32(tHeader, 8) * tBlockSize into tAt
            if byte 1025 to 1026 of __hciRead(pImage, tAt, 2048) is "BD" then return tAt
         end if
      end repeat
   end if
   if byte 1025 to 1026 of tHeader is "H+" or byte 1025 to 1026 of tHeader is "HX" then
      return "an HFS+ volume, which this library does not read"
   end if
   return "no HFS volume in the file"
end __hciFindVolume

-- Read the volume's catalog and extents tree into the script locals,
-- unless they are of this image as it is now. Returns empty or an error.
private function __hciLoad pImage
   local tStamp, tAt, tMdb, tError
   set the itemDelimiter to slash
   put files(item 1 to -2 of pImage, "detailed") into tStamp
   filter lines of tStamp with urlEncode(item -1 of pImage) & ",*"
   if pImage is sImage and tStamp is sImageStamp and sFiles is an array then return empty

   put empty into sImage
   put empty into sVolume
   put empty into sDirs
   put empty into sFiles
   put empty into sOverflow
   put __hciFindVolume(pImage) into tAt
   if tAt is not a number then return tAt

   -- the master directory block, two sectors into the volume
   put __hciRead(pImage, tAt + 1024, kSector) into tMdb
   put tAt into sVolume["offset"]
   -- drAlBlkSiz at 20, drAlBlSt (in sectors) at 28, drXTFlSize and
   -- drXTExtRec at 130 and 134, drCTFlSize and drCTExtRec at 146 and 150
   put __hciU32(tMdb, 20) into sVolume["blocksize"]
   put __hciU16(tMdb, 28) * kSector into sVolume["firstblock"]
   if sVolume["blocksize"] is 0 or sVolume["blocksize"] mod kSector is not 0 then
      return "the volume's allocation block size is not usable"
   end if
   put __hciExtents(tMdb, 134) into sVolume["extentsextents"]
   put __hciU32(tMdb, 130) into sVolume["extentssize"]
   put __hciExtents(tMdb, 150) into sVolume["catalogextents"]
   put __hciU32(tMdb, 146) into sVolume["catalogsize"]

   -- the extents tree first: the catalog itself can need it
   put __hciReadTree(pImage, sVolume["extentsextents"], sVolume["extentssize"], "extents") into tError
   if tError is empty then
      put __hciOverflowExtents(4, "data", sVolume["catalogextents"]) into sVolume["catalogextents"]
      put __hciReadTree(pImage, sVolume["catalogextents"], sVolume["catalogsize"], "catalog") into tError
   end if
   if tError is not empty then
      put empty into sFiles
      return tError
   end if
   put pImage into sImage
   put tStamp into sImageStamp
   return empty
end __hciLoad

-- An extent record: three (first allocation block, number of blocks)
-- pairs, as lines "first,count"; empty extents left out
private function __hciExtents pData, pOffset
   local tList, tCount
   repeat with i = 0 to 2
      put __hciU16(pData, pOffset + i * 4 + 2) into tCount
      if tCount is 0 then next repeat
      put __hciU16(pData, pOffset + i * 4) & comma & tCount & return after tList
   end repeat
   delete the last char of tList
   return tList
end __hciExtents

-- A file's extents with those the extents tree holds for it after the
-- first three (records keyed by the fork and the file's block number
-- each starts at)
private function __hciOverflowExtents pFileID, pFork, pExtents
   local tBlocks, tExtent, tMore
   put 0 into tBlocks
   repeat for each line tExtent in pExtents
      add item 2 of tExtent to tBlocks
   end repeat
   repeat forever
      put sOverflow[pFileID & comma & pFork & comma & tBlocks] into tMore
      if tMore is empty then exit repeat
      repeat for each line tExtent in tMore
         put return & tExtent after pExtents
         add item 2 of tExtent to tBlocks
      end repeat
   end repeat
   if char 1 of pExtents is return then delete char 1 of pExtents
   return pExtents
end __hciOverflowExtents

-- pLength bytes from pOffset in a file stored in pExtents
private function __hciReadExtents pImage, pExtents, pOffset, pLength
   local tData, tExtent, tStart, tBytes, tFrom, tCount
   put 0 into tStart
   repeat for each line tExtent in pExtents
      if pLength <= 0 then exit repeat
      put item 2 of tExtent * sVolume["blocksize"] into tBytes
      if pOffset < tStart + tBytes then
         put pOffset - tStart into tFrom
         put min(tBytes - tFrom, pLength) into tCount
         put __hciRead(pImage, sVolume["offset"] + sVolume["firstblock"] + \
               item 1 of tExtent * sVolume["blocksize"] + tFrom, tCount) after tData
         add tCount to pOffset
         subtract tCount from pLength
      end if
      add tBytes to tStart
   end repeat
   return tData
end __hciReadExtents

-- Walk a B-tree's leaf nodes, from the first through each node's
-- forward link, and keep their records: the extents tree's in sOverflow,
-- the catalog's in sDirs and sFiles. Returns empty or an error.
private function __hciReadTree pImage, pExtents, pSize, pWhich
   local tHeader, tNodeSize, tNode, tData, tCount, tSeen, tRecord, tOffset, tNext
   if pExtents is empty or pSize is 0 then
      if pWhich is "extents" then return empty
      return "the volume has no catalog"
   end if
   -- the header node: its node descriptor (14 bytes), then the header
   -- record: depth, root, leaf record count, first leaf (at 10), last
   -- leaf, node size (at 18)
   put __hciReadExtents(pImage, pExtents, 0, kSector) into tHeader
   put __hciU16(tHeader, 14 + 18) into tNodeSize
   if tNodeSize < kSector or tNodeSize > 32768 then return "the" && pWhich && "tree is damaged"
   put __hciU32(tHeader, 14 + 10) into tNode
   put 0 into tSeen
   repeat while tNode is not 0
      add 1 to tSeen
      if tNode * tNodeSize >= pSize or tSeen > pSize div tNodeSize then
         return "the" && pWhich && "tree is damaged"
      end if
      put __hciReadExtents(pImage, pExtents, tNode * tNodeSize, tNodeSize) into tData
      if length(tData) < tNodeSize then return "the image ends inside the" && pWhich && "tree"
      -- a leaf's kind is -1 (byte 8 of the descriptor)
      if byteToNum(byte 9 of tData) is not 255 then return "the" && pWhich && "tree is damaged"
      put __hciU32(tData, 0) into tNext
      put __hciU16(tData, 10) into tCount
      -- the records' offsets, from the end of the node backwards
      repeat with tRecord = 0 to tCount - 1
         put __hciU16(tData, tNodeSize - 2 - tRecord * 2) into tOffset
         if tOffset < 14 or tOffset >= tNodeSize then next repeat
         if pWhich is "extents" then
            __hciExtentsRecord tData, tOffset
         else
            __hciCatalogRecord tData, tOffset
         end if
      end repeat
      put tNext into tNode
   end repeat
   if pWhich is "catalog" then
      -- the files' forks can need the extents tree too
      repeat for each line tRecord in sFiles["order"]
         put __hciOverflowExtents(sFiles[tRecord]["id"], "data", sFiles[tRecord]["dataextents"]) into sFiles[tRecord]["dataextents"]
         put __hciOverflowExtents(sFiles[tRecord]["id"], "rsrc", sFiles[tRecord]["rsrcextents"]) into sFiles[tRecord]["rsrcextents"]
      end repeat
   end if
   return empty
end __hciReadTree

-- An extents tree record: the key (its length, the fork type: 0 data,
-- 255 resource, the file's id, the file block the extents start at),
-- then an extent record
private command __hciExtentsRecord pNode, pOffset
   local tKeyLength, tFork, tFileID, tStart
   put byteToNum(byte pOffset + 1 of pNode) into tKeyLength
   if tKeyLength < 7 then exit __hciExtentsRecord
   if byteToNum(byte pOffset + 2 of pNode) is 255 then put "rsrc" into tFork else put "data" into tFork
   put __hciU32(pNode, pOffset + 2) into tFileID
   put __hciU16(pNode, pOffset + 6) into tStart
   put __hciExtents(pNode, pOffset + 1 + tKeyLength + (1 + tKeyLength) mod 2) into sOverflow[tFileID & comma & tFork & comma & tStart]
end __hciExtentsRecord

-- A catalog record: the key (its length, a reserved byte, the parent
-- folder's id, the name), padded to an even length, then the record,
-- whose first byte is its kind: 1 a folder, 2 a file (3 and 4 are
-- threads, not needed here)
private command __hciCatalogRecord pNode, pOffset
   local tKeyLength, tParent, tName, tAt, tID
   put byteToNum(byte pOffset + 1 of pNode) into tKeyLength
   if tKeyLength < 6 then exit __hciCatalogRecord
   put __hciU32(pNode, pOffset + 2) into tParent
   put __hciPString(pNode, pOffset + 6) into tName
   put pOffset + 1 + tKeyLength into tAt
   if tAt mod 2 is 1 then add 1 to tAt
   switch byteToNum(byte tAt + 1 of pNode)
      case 1
         -- dirDirID at 6
         put __hciU32(pNode, tAt + 6) into tID
         put tParent into sDirs[tID]["parent"]
         put tName into sDirs[tID]["name"]
         break
      case 2
         -- filUsrWds (Finder info: type, creator...) at 4, filFlNum at
         -- 20, filLgLen at 26, filRLgLen at 36, filExtRec at 74,
         -- filRExtRec at 86
         put __hciU32(pNode, tAt + 20) into tID
         put tID & return after sFiles["order"]
         put tParent into sFiles[tID]["parent"]
         put tName into sFiles[tID]["name"]
         put tID into sFiles[tID]["id"]
         put byte tAt + 5 to tAt + 8 of pNode into sFiles[tID]["type"]
         put byte tAt + 9 to tAt + 12 of pNode into sFiles[tID]["creator"]
         put __hciU32(pNode, tAt + 26) into sFiles[tID]["datasize"]
         put __hciU32(pNode, tAt + 36) into sFiles[tID]["rsrcsize"]
         put __hciExtents(pNode, tAt + 74) into sFiles[tID]["dataextents"]
         put __hciExtents(pNode, tAt + 86) into sFiles[tID]["rsrcextents"]
         break
   end switch
end __hciCatalogRecord

-- The HFS path of a file: the volume (the root folder, id 2, whose
-- parent is 1), each folder, the file, separated by colons
private function __hciPath pParent, pName
   local tPath, tSeen
   put pName into tPath
   put 0 into tSeen
   repeat while pParent is not 1 and sDirs[pParent] is an array and tSeen < 100
      put sDirs[pParent]["name"] & colon before tPath
      put sDirs[pParent]["parent"] into pParent
      add 1 to tSeen
   end repeat
   return tPath
end __hciPath

private function __hciIsStack pFile
   if sFiles[pFile]["type"] is "STAK" then return true
   -- a stack whose type was lost: the first block of a HyperCard data
   -- fork is its STAK block
   if sFiles[pFile]["datasize"] < 8 then return false
   return byte 5 to 8 of __hciReadExtents(sImage, sFiles[pFile]["dataextents"], 0, 8) is "STAK"
end __hciIsStack

-- A fork's bytes; an error in the result if the image ends before it does
private function __hciReadFork pImage, pFile, pFork
   local tData, tSize
   put sFiles[pFile][pFork & "size"] into tSize
   put __hciReadExtents(pImage, sFiles[pFile][pFork & "extents"], 0, tSize) into tData
   if length(tData) is not tSize then return "the image ends inside" && sFiles[pFile]["name"] for error
   return tData for value
end __hciReadFork
