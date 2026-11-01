script "CoreInterfaceHyperCardDiskImages"
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

-- OXT-Beyond: HyperCard stacks on Mac disk images, read by the IDE's
-- revHyperCardDiskImageLibrary
-- (ide/Toolset/libraries/revhypercarddiskimagelibrary.livecodescript).
-- The images, in lcs-input-files/hypercard/forks, are written by
-- make-forks.py there: one HFS volume, raw, as a DiskCopy 4.2 image and
-- behind an Apple partition map. The tests make the other kinds from
-- them: MacBinary copies, .dmg files and HFS+ volumes.

constant kSynthetic = "Old Disk:Stacks:Synthetic Stack"
constant kLost = "Old Disk:Stacks:More:Lost Type"

-- How many files _Write has written, which names each one
local sWritten

-- How the dialog revHyperCardImageChoose shows was open when
-- _AnswerChooser answered it
local sChooser

on TestSetup
   TestSkipIfNot "ide"
   start using stack (TestGetIDERepositoryPath() & "/Toolset/libraries/revhypercarddiskimagelibrary.livecodescript")
end TestSetup

private function _NewFolder pName
   local tFolder
   put the temporary folder & "/hcimage-" & pName & "-" & the milliseconds into tFolder
   create folder tFolder
   return tFolder
end _NewFolder

private command _DeleteFolder pFolder
   local tFile
   repeat for each line tFile in files(pFolder)
      delete file (pFolder & slash & tFile)
   end repeat
   delete folder pFolder
end _DeleteFolder

private function _Image pName
   return TestGetInputFile("hypercard/forks/" & pName)
end _Image

private function _Bytes pName
   return url ("binfile:" & _Image(pName))
end _Bytes

private function _Zeros pCount
   local tZeros
   repeat pCount times
      put numToByte(0) after tZeros
   end repeat
   return tZeros
end _Zeros

-- pData written to a file of its own in the temporary folder
private function _Write pName, pData
   local tFile
   add 1 to sWritten
   put the temporary folder & "/hcimage-" & the milliseconds & "-" & sWritten & "-" & pName into tFile
   put pData into url ("binfile:" & tFile)
   return tFile
end _Write

-- pData as the data fork of a MacBinary file of type pType, named pName:
-- a 128-byte header (the name, the type and creator, the forks' lengths),
-- then the fork, padded to 128 bytes
private function _MacBinary pName, pType, pData
   local tFile
   put numToByte(0) & numToByte(the number of bytes of pName) & pName into tFile
   put _Zeros(65 - the number of bytes of tFile) & pType & "????" after tFile
   put _Zeros(83 - the number of bytes of tFile) & binaryEncode("NN", the number of bytes of pData, 0) after tFile
   put _Zeros(128 - the number of bytes of tFile) & pData after tFile
   return tFile & _Zeros((128 - the number of bytes of pData mod 128) mod 128)
end _MacBinary

-- An Apple partition map entry: a map of pCount entries, the partition's
-- first block and length (in 512-byte blocks), its name and type
private function _MapEntry pCount, pStart, pLength, pName, pType
   local tEntry
   put "PM" & binaryEncode("nNNN", 0, pCount, pStart, pLength) into tEntry
   put pName & _Zeros(32 - the number of bytes of pName) after tEntry
   put pType & _Zeros(32 - the number of bytes of pType) after tEntry
   return tEntry & _Zeros(512 - the number of bytes of tEntry)
end _MapEntry

on TestHyperCardImageLoadedByIDE
   -- the IDE loads its libraries by sending extensionInitialize
   -- (revInternal__LoadLibrary); the library must then be in the message
   -- path, or File > Import Stack cannot call it
   local tLib
   put the long id of stack "revHyperCardDiskImageLibrary" into tLib
   send "extensionInitialize" to stack "revHyperCardDiskImageLibrary"
   TestAssert "extensionInitialize puts the library in the backScripts", tLib is among the lines of the backScripts
   send "extensionFinalize" to stack "revHyperCardDiskImageLibrary"
   TestAssert "extensionFinalize takes it out", tLib is not among the lines of the backScripts
end TestHyperCardImageLoadedByIDE

on TestHyperCardImageList
   local tImage, tList
   repeat for each item tImage in "Stacks.hfs,Stacks.dc42,Stacks.apm"
      TestAssert tImage & ": a disk image", revHyperCardIsDiskImage(_Image(tImage))
      put revHyperCardImageStacks(_Image(tImage)) into tList
      TestAssert tImage & ": no error", the result is empty
      TestAssert tImage & ": two stacks", the number of lines of tList is 2
      -- path, data fork size, resource fork size
      TestAssert tImage & ": a stack with its fork", (kSynthetic & tab & 8192 & tab & 2747) is among the lines of tList
      TestAssert tImage & ": a stack by its first block", (kLost & tab & 8192 & tab & 0) is among the lines of tList
      TestAssert tImage & ": not a text file", "Read Me" is not in tList
   end repeat
end TestHyperCardImageList

on TestHyperCardImageNotAnImage
   local tImage
   TestAssert "a stack is not a disk image", not revHyperCardIsDiskImage(TestGetInputFile("hypercard/TestCardsBackgrounds.stack"))
   get revHyperCardImageStacks(TestGetInputFile("hypercard/TestCardsBackgrounds.stack"))
   TestAssert "no stacks listed", it is empty and the result is "no HFS volume in the file"
   TestAssert "a stack: no image problem", revHyperCardImageProblem(TestGetInputFile("hypercard/TestCardsBackgrounds.stack")) is empty
   get revHyperCardImageStacks(TestGetInputFile("hypercard/no such image"))
   TestAssert "a missing file", it is empty and the result is "no such file"
   TestAssert "a missing file: no image problem", revHyperCardImageProblem(TestGetInputFile("hypercard/no such image")) is empty
   repeat for each item tImage in "Stacks.hfs,Stacks.dc42,Stacks.apm"
      TestAssert tImage & ": no problem", revHyperCardImageProblem(_Image(tImage)) is empty
   end repeat
end TestHyperCardImageNotAnImage

on TestHyperCardImageMacBinary
   -- a MacBinary copy of an image, as Mac archives kept DiskCopy images, is
   -- read in place
   local tImage, tFile, tList, tFolder, tPath
   repeat for each item tImage in "Stacks.hfs,Stacks.dc42,Stacks.apm"
      put _Write("image.bin", _MacBinary("Old Disk.image", "dImg", _Bytes(tImage))) into tFile
      TestAssert tImage & " in MacBinary: a disk image", revHyperCardIsDiskImage(tFile)
      put revHyperCardImageStacks(tFile) into tList
      TestAssert tImage & " in MacBinary: no error", the result is empty
      TestAssert tImage & " in MacBinary: a stack with its fork", (kSynthetic & tab & 8192 & tab & 2747) is among the lines of tList
      TestAssert tImage & " in MacBinary: a stack by its first block", (kLost & tab & 8192 & tab & 0) is among the lines of tList
      if tImage is "Stacks.apm" then
         put _NewFolder("macbinary") into tFolder
         put revHyperCardImageExtract(tFile, kSynthetic, tFolder) into tPath
         TestAssert "MacBinary extract: the data fork", url ("binfile:" & tPath) is url ("binfile:" & TestGetInputFile("hypercard/TestCardsBackgrounds.stack"))
         TestAssert "MacBinary extract: the resource fork", url ("binfile:" & tPath & ".rsrc") is _Bytes("Synthetic.rsrc")
         _DeleteFolder tFolder
      end if
      delete file tFile
   end repeat
   -- a MacBinary copy of a stack is the HyperCard importer's, whatever its
   -- data fork holds
   put _Write("stack.bin", _MacBinary("Old Disk", "STAK", _Bytes("Stacks.hfs"))) into tFile
   TestAssert "a stack in MacBinary: not a disk image", not revHyperCardIsDiskImage(tFile)
   TestAssert "a stack in MacBinary: no image problem", revHyperCardImageProblem(tFile) is empty
   delete file tFile
end TestHyperCardImageMacBinary

on TestHyperCardImageHFSPlus
   -- HFS+ volumes are not read, and the library says so: raw, inside the
   -- HFS volume Mac OS 8.1 to 9 wrapped one in (its master directory block
   -- names it at 124), and behind a partition map
   local tData, tFiles, tFile, tKind
   put "an HFS+ volume, which this library does not read" into tKind
   put _Zeros(1024) & "H+" & binaryEncode("n", 4) & _Zeros(3068) into tData
   put _Write("plus.hfs", tData) & return into tFiles
   put _Write("plusx.hfs", _Zeros(1024) & "HX" & binaryEncode("n", 5) & _Zeros(3068)) & return after tFiles
   put _Bytes("Stacks.hfs") into tData
   put "H+" into byte 1024 + 125 to 1024 + 126 of tData
   put _Write("wrapped.hfs", tData) & return after tFiles
   put _Bytes("Stacks.apm") into tData
   put "H+" into byte 64 * 512 + 1025 to 64 * 512 + 1026 of tData
   put _Write("plus.apm", tData) after tFiles
   repeat for each line tFile in tFiles
      TestAssert tFile & ": not a disk image it reads", not revHyperCardIsDiskImage(tFile)
      TestAssert tFile & ": said so", revHyperCardImageProblem(tFile) is tKind
      get revHyperCardImageStacks(tFile)
      TestAssert tFile & ": no stacks listed", it is empty and the result is tKind
      delete file tFile
   end repeat
   -- an HFS partition after an HFS+ one is read: the map's entries are
   -- blocks 1 to 3, the HFS+ volume blocks 8 to 63, the HFS one from 64
   put _Bytes("Stacks.apm") into tData
   put _MapEntry(3, 1, 3, "Apple", "Apple_partition_map") & _MapEntry(3, 8, 56, "New Disk", "Apple_HFS") &          _MapEntry(3, 64, (the number of bytes of tData - 64 * 512) div 512, "Old Disk", "Apple_HFS")          into byte 513 to 2048 of tData
   put "H+" into byte 8 * 512 + 1025 to 8 * 512 + 1026 of tData
   put _Write("two.apm", tData) into tFile
   TestAssert "HFS+ then HFS: a disk image", revHyperCardIsDiskImage(tFile)
   get revHyperCardImageStacks(tFile)
   TestAssert "HFS+ then HFS: the HFS volume's stacks", the result is empty and the number of lines of it is 2
   TestAssert "HFS+ then HFS: no problem", revHyperCardImageProblem(tFile) is empty
   delete file tFile
end TestHyperCardImageHFSPlus

on TestHyperCardImageDmg
   -- a .dmg (UDIF) ends with a "koly" block: a read/write one, the raw
   -- image before it, is read; a compressed one is not, and said so
   local tKoly, tImage, tFile, tList
   put "koly" & binaryEncode("NNN", 4, 512, 1) into tKoly
   put _Zeros(512 - the number of bytes of tKoly) after tKoly
   repeat for each item tImage in "Stacks.hfs,Stacks.apm"
      put _Write("rw.dmg", _Bytes(tImage) & tKoly) into tFile
      TestAssert tImage & " as a read/write dmg: a disk image", revHyperCardIsDiskImage(tFile)
      put revHyperCardImageStacks(tFile) into tList
      TestAssert tImage & " as a read/write dmg: two stacks", the result is empty and the number of lines of tList is 2
      TestAssert tImage & " as a read/write dmg: no problem", revHyperCardImageProblem(tFile) is empty
      delete file tFile
   end repeat
   put _Write("zlib.dmg", compress(_Bytes("Stacks.apm")) & tKoly) into tFile
   TestAssert "compressed dmg: not a disk image it reads", not revHyperCardIsDiskImage(tFile)
   TestAssert "compressed dmg: said so", revHyperCardImageProblem(tFile) begins with "a compressed disk image (a .dmg), which this library does not read"
   delete file tFile
   -- a file too short for the block
   put _Write("short.dmg", "koly") into tFile
   TestAssert "a short file: no problem", revHyperCardImageProblem(tFile) is empty
   delete file tFile
end TestHyperCardImageDmg

on TestHyperCardImageExtract
   local tFolder, tPath
   put _NewFolder("extract") into tFolder
   put revHyperCardImageExtract(_Image("Stacks.apm"), kSynthetic, tFolder) into tPath
   TestAssert "extract: no error", the result is empty
   TestAssert "extract: named after the file", tPath is tFolder & "/Synthetic Stack"
   -- both forks were cut into runs, the resource fork's last in the
   -- extents tree
   TestAssert "extract: the data fork", url ("binfile:" & tPath) is url ("binfile:" & TestGetInputFile("hypercard/TestCardsBackgrounds.stack"))
   TestAssert "extract: the resource fork", url ("binfile:" & tPath & ".rsrc") is url ("binfile:" & _Image("Synthetic.rsrc"))
   get revHyperCardImageExtract(_Image("Stacks.apm"), "Old Disk:Nothing", tFolder)
   TestAssert "extract: a file the volume does not have", it is empty and the result begins with "no such file"
   _DeleteFolder tFolder
end TestHyperCardImageExtract

on TestHyperCardImageFolder
   -- a folder's folders, then its files with their types and creators,
   -- for the HyperCard Library's Files
   local tImage, tList
   repeat for each item tImage in "Stacks.hfs,Stacks.dc42,Stacks.apm"
      put revHyperCardImageFolder(_Image(tImage), "Old Disk") into tList
      TestAssert tImage & ": the top folder, no error", the result is empty
      TestAssert tImage & ": the top folder's folder, then its file", tList is "Stacks" & tab & "folder" & return & "Read Me" & tab & "file" & tab & "TEXT" & tab & "ttxt"
      put revHyperCardImageFolder(_Image(tImage), "old disk:STACKS:") into tList
      TestAssert tImage & ": a folder, its case aside, a colon at its end", tList is "More" & tab & "folder" & return & "Synthetic Stack" & tab & "file" & tab & "STAK" & tab & "WILD"
      put revHyperCardImageFolder(_Image(tImage), "Old Disk:Stacks:More") into tList
      TestAssert tImage & ": a folder with no folder in it", tList is "Lost Type" & tab & "file" & tab & "????" & tab & "????"
   end repeat
   get revHyperCardImageFolder(_Image("Stacks.hfs"), "Old Disk:Nothing")
   TestAssert "a folder the volume does not have", it is empty and the result begins with "no such folder"
   get revHyperCardImageFolder(_Image("Stacks.hfs"), "Other Disk")
   TestAssert "another volume's name", it is empty and the result begins with "no such folder"
   get revHyperCardImageFolder(_Image("Stacks.hfs"), "Old Disk:Read Me")
   TestAssert "a file, not a folder", it is empty and the result begins with "no such folder"
end TestHyperCardImageFolder

on TestHyperCardImageReadFork
   -- a fork read in place, for the HyperCard Library's ResText
   local tData
   put revHyperCardImageReadFork(_Image("Stacks.apm"), kSynthetic, "resource") into tData
   TestAssert "read fork: no error", the result is empty
   TestAssert "read fork: the resource fork, in runs and in the extents tree", tData is _Bytes("Synthetic.rsrc")
   put revHyperCardImageReadFork(_Image("Stacks.dc42"), "Old Disk:Read Me", "data") into tData
   TestAssert "read fork: a data fork", the result is empty and tData is "An old disk." & numToByte(13)
   put revHyperCardImageReadFork(_Image("Stacks.hfs"), kLost, "resource") into tData
   TestAssert "read fork: a file with no resource fork, empty and no error", the result is empty and tData is empty
   get revHyperCardImageReadFork(_Image("Stacks.hfs"), "Old Disk:Nothing", "data")
   TestAssert "read fork: a file the volume does not have", it is empty and the result begins with "no such file"
   get revHyperCardImageReadFork(_Image("Stacks.hfs"), kSynthetic, "rsrc")
   TestAssert "read fork: a fork that is neither", it is empty and the result is not empty
end TestHyperCardImageReadFork

on TestHyperCardImageImport
   -- a stack copied out of an image imports with its fork
   local tFolder, tPath, tError
   put _NewFolder("import") into tFolder
   put revHyperCardImageExtract(_Image("Stacks.dc42"), kSynthetic, tFolder) into tPath
   lock messages
   try
      import stack from file tPath
   catch tError
   end try
   unlock messages
   TestAssert "import: no error", tError is empty and there is a stack "Synthetic Stack"
   TestAssert "import: the fork's icon", the short name of image id 128 of stack "Synthetic Stack" is "Synth Icon"
   TestAssert "import: the fork's sound", there is an audioClip "Synth Beep" of stack "Synthetic Stack"
   lock messages
   delete stack "Synthetic Stack"
   unlock messages
   _DeleteFolder tFolder
end TestHyperCardImageImport

on TestHyperCardImageChooser
   -- the dialog File > Import Stack > HyperCard Stack... shows for an image
   local tList, tDialog
   put revHyperCardImageStacks(_Image("Stacks.hfs")) into tList
   put revHyperCardImageChooser(_Image("Stacks.hfs"), tList) into tDialog
   TestAssert "chooser: the paths", the text of field "List" of tDialog is kSynthetic & return & kLost
   put "lost" into field "Search" of tDialog
   send "textChanged" to field "Search" of tDialog
   TestAssert "chooser: narrowed by the search", the text of field "List" of tDialog is kLost
   send "mouseUp" to button "Import" of tDialog
   TestAssert "chooser: the stack chosen", the cChosen of tDialog is kLost
   delete tDialog
end TestHyperCardImageChooser

on TestHyperCardImageChoose
   -- The dialog waits to be answered, here by a message sent while it is
   -- open. It came back at once with nothing chosen, because modal does
   -- not wait for an invisible stack, so File > Import Stack did nothing
   -- with a disk image.
   local tChosen, tError, tAnswer, tSafety
   repeat for each item tButton in "Import,Cancel"
      put empty into sChooser
      send "_AnswerChooser" && quote & tButton & quote to me in 200 milliseconds
      put the result into tAnswer
      -- if the first answer does not close the dialog, this one does,
      -- and says so
      send "_AnswerChooser" && quote & "Cancel" & quote to me in 10 seconds
      put the result into tSafety
      put revHyperCardImageChoose(_Image("Stacks.dc42")) into tChosen
      put the result into tError
      cancel tAnswer
      cancel tSafety
      TestDiagnostic tButton & ":" && sChooser
      TestAssert "choose, " & tButton & ": the dialog was open and modal when answered", \
            sChooser is tButton & ": mode 5, visible true"
      if tButton is "Import" then
         TestAssert "choose, Import: the stack chosen", tChosen is kSynthetic and tError is empty
      else
         TestAssert "choose, Cancel: nothing chosen", tChosen is empty and tError is empty
      end if
      TestAssert "choose, " & tButton & ": the dialog is gone", there is not a stack "revHyperCardImageChooser"
   end repeat
end TestHyperCardImageChoose

-- Answers the dialog revHyperCardImageChoose shows with the button named,
-- noting how the dialog was open in sChooser
on _AnswerChooser pButton
   if there is not a stack "revHyperCardImageChooser" then exit _AnswerChooser
   put pButton & ": mode" && the mode of stack "revHyperCardImageChooser" & \
         ", visible" && the visible of stack "revHyperCardImageChooser" after sChooser
   send "mouseUp" to button pButton of stack "revHyperCardImageChooser"
end _AnswerChooser
