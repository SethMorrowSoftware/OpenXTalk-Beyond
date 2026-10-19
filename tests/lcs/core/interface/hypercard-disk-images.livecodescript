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
-- behind an Apple partition map.

constant kSynthetic = "Old Disk:Stacks:Synthetic Stack"
constant kLost = "Old Disk:Stacks:More:Lost Type"

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
   TestAssert "a stack is not a disk image", not revHyperCardIsDiskImage(TestGetInputFile("hypercard/TestCardsBackgrounds.stack"))
   get revHyperCardImageStacks(TestGetInputFile("hypercard/TestCardsBackgrounds.stack"))
   TestAssert "no stacks listed", it is empty and the result is "no HFS volume in the file"
   get revHyperCardImageStacks(TestGetInputFile("hypercard/no such image"))
   TestAssert "a missing file", it is empty and the result is "no such file"
end TestHyperCardImageNotAnImage

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
