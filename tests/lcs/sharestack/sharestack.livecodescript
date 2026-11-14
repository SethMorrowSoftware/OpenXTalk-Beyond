script "TestShareStack"
-- OXT-Beyond: tests of File > Share Stack...
-- (ide/Toolset/palettes/share/revsharestack.livecodescript), which packs
-- a stack for the OXT Community Stacks: the rules it holds a stack and
-- its listing to, which are the gallery's (tools/listing.py and
-- tools/scan.py of oxt-community-stacks), the listing it writes, and the
-- package: one .zip holding stacks/<name>/<version>/ with the listing and
-- the stack's file, byte for byte. The window itself is run by the IDE
-- tour's step share-stack (tools/ci/ui-tour.livecodescript).

local sShare, sFolder, sFound

on TestSetup
   TestSkipIfNot "ide"
   put there is a stack "revShareStack" into sFound
   put TestGetIDERepositoryPath() & "/Toolset/palettes/share/revsharestack.livecodescript" into sShare
   get the short name of stack sShare
   put the tempName & "-sharestack" into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   local tFile
   if there is a stack "TestShareStackSample" then
      delete stack "TestShareStackSample"
   end if
   if sFolder is not empty and there is a folder sFolder then
      repeat for each line tFile in files(sFolder)
         delete file (sFolder & slash & tFile)
      end repeat
      delete folder sFolder
   end if
   if sFound is not true and there is a stack "revShareStack" then
      delete stack "revShareStack"
   end if
end TestTeardown

private function __Slug pTitle
   dispatch function "revShareStackSlug" to stack sShare with pTitle
   return the result
end __Slug

private function __Problems pInfo
   dispatch function "revShareStackProblems" to stack sShare with pInfo
   return the result
end __Problems

private function __Check pStack
   dispatch function "revShareStackCheck" to stack sShare with pStack
   return the result
end __Check

-- What an author might type, all of it in order
private function __Info
   local tInfo
   put "Beat Box" into tInfo["title"]
   put "A. Name" into tInfo["author"]
   put "A drum machine with sixteen steps. Click the squares to lay down a beat." into tInfo["about"]
   put "MIT" into tInfo["licence"]
   put "1.0" into tInfo["version"]
   put "Music, sound" into tInfo["tags"]
   return tInfo
end __Info

-- A stack with a button, saved in the test's folder under pFileName;
-- returns its long id
private function __Sample pFileName
   local tStack, tSaved
   if there is a stack "TestShareStackSample" then
      delete stack "TestShareStackSample"
   end if
   put the defaultStack into tSaved
   -- (TestLoadExternal leaves the external it loaded with the
   -- templateStack, and a stack with externals of its own is refused)
   reset the templateStack
   create invisible stack "TestShareStackSample"
   put the long id of it into tStack
   set the defaultStack to "TestShareStackSample"
   create button "Play"
   set the script of button "Play" to "on mouseUp" & return & "   beep" & return & "end mouseUp"
   set the defaultStack to tSaved
   if pFileName is not empty then
      set the filename of tStack to sFolder & slash & pFileName
      save tStack
   end if
   return tStack
end __Sample

-- The folder name is the gallery's: lower-case letters and digits with
-- single hyphens between them, 3 to 40 long (SLUG in tools/listing.py)
on TestSlug
   TestAssert "words become hyphens", __Slug("Beat Box") is "beat-box"
   TestAssert "marks go, and leave no hyphen at an end", __Slug("  Beat -- Box!  ") is "beat-box"
   TestAssert "digits stay", __Slug("2048") is "2048"
   TestAssert "letters with accents are left out", __Slug("Caf" & numToCodepoint(233) & " Stack") is "caf-stack"
   TestAssert "a short one is made long enough", __Slug("Go") is "go-stack"
   TestAssert "nothing usable makes stack", __Slug("!!") is "stack"
   TestAssert "at most 40, with no hyphen at the end", \
         __Slug("The quick brown fox jumps over the lazy dog every single morning") is "the-quick-brown-fox-jumps-over-the-lazy"
end TestSlug

on TestProblemsOfAGoodListing
   TestAssert "nothing is wrong with a listing in order", __Problems(__Info()) is empty
end TestProblemsOfAGoodListing

on TestProblems
   local tInfo, tVersion
   put __Info() into tInfo
   put "x" into tInfo["title"]
   TestAssert "a title of one letter", __Problems(tInfo) is "The title is too short (at least 2 letters)."

   put __Info() into tInfo
   put empty into tInfo["author"]
   TestAssert "no name", __Problems(tInfo) is "Your name is missing."

   put __Info() into tInfo
   put "See https://example.com for more of it" into tInfo["about"]
   TestAssert "a web address", __Problems(tInfo) is "What it does cannot have a web address in it."

   put __Info() into tInfo
   put "A <b>drum</b> machine" into tInfo["about"]
   TestAssert "an angle bracket", __Problems(tInfo) is "What it does cannot have < or > in it."

   put __Info() into tInfo
   put "Too short" into tInfo["about"]
   TestAssert "nine letters of what it does", __Problems(tInfo) is "What it does is too short (at least 10 letters)."

   put __Info() into tInfo
   put empty into tInfo["about"]
   repeat 601
      put "a" after tInfo["about"]
   end repeat
   TestAssert "what it does in 601 letters", __Problems(tInfo) is "What it does is too long (601 letters; at most 600)."

   put __Info() into tInfo
   put "Proprietary" into tInfo["licence"]
   TestAssert "a licence the gallery does not take", __Problems(tInfo) is "Choose how others may use your stack."

   put __Info() into tInfo
   repeat for each item tVersion in "1.a,.1,1.,1..2,1.2.3.4.5,v1,"
      put tVersion into tInfo["version"]
      TestAssert "the version" && quote & tVersion & quote && "is refused", \
            __Problems(tInfo) is "The version must be a number such as 1, 1.2 or 1.2.3."
   end repeat
   repeat for each item tVersion in "1,1.2,1.2.3,10.20.30.40"
      put tVersion into tInfo["version"]
      TestAssert "the version" && tVersion && "is taken", __Problems(tInfo) is empty
   end repeat

   put __Info() into tInfo
   put "music, Bad_Tag" into tInfo["tags"]
   TestAssert "a word with an underscore", line 1 of __Problems(tInfo) contains (quote & "bad_tag" & quote & " cannot be used")
   put "a, b, c, d, e, f" into tInfo["tags"]
   TestAssert "six words", __Problems(tInfo) is "At most five words to find it by."
   put "music, Music, MUSIC, drum machine, 8-bit" into tInfo["tags"]
   TestAssert "a word given twice counts once", __Problems(tInfo) is empty

   put empty into tInfo
   TestAssert "nothing typed: a line for each box, in the window's order", \
         __Problems(tInfo) is "The title is missing." & return & "Your name is missing." & return & \
         "What it does is missing." & return & "Choose how others may use your stack." & return & \
         "The version must be a number such as 1, 1.2 or 1.2.3."
end TestProblems

-- The licences are the gallery's (LICENCES in tools/listing.py), none
-- more and none fewer
on TestLicences
   local tLine, tIds, tInfo, tLicences
   dispatch function "revShareStackLicences" to stack sShare
   put the result into tLicences
   set the itemDelimiter to "|"
   repeat for each line tLine in tLicences
      put item 1 of tLine & comma after tIds
      TestAssert "the licence" && item 1 of tLine && "has a line for the menu and a short name", \
            the number of items of tLine is 3 and item 2 of tLine is not empty and item 3 of tLine is not empty
   end repeat
   set the itemDelimiter to comma
   delete the last char of tIds
   sort items of tIds
   TestAssert "the gallery's thirteen licences", tIds is \
         "Apache-2.0,BSD-2-Clause,BSD-3-Clause,CC-BY-4.0,CC-BY-SA-4.0,CC0-1.0,GPL-2.0-or-later,GPL-3.0-only," & \
         "GPL-3.0-or-later,LGPL-3.0-or-later,MIT,MPL-2.0,Unlicense"
   put __Info() into tInfo
   repeat for each item tLine in tIds
      put tLine into tInfo["licence"]
      TestAssert "a listing with" && tLine && "is in order", __Problems(tInfo) is empty
   end repeat
end TestLicences

on TestListing
   local tInfo, tJson, tArray
   put __Info() into tInfo
   put "  Beat   Box  " into tInfo["title"]
   put "A drum machine, " & quote & "sixteen" & quote & " steps." & return & "Back\slash and" & tab & "tab." into tInfo["about"]
   dispatch function "revShareStackListing" to stack sShare with tInfo, "Beat Box.oxtstack", "screenshot.png"
   put the result into tJson
   TestAssert "the title, with its spaces made one", tJson contains (quote & "title" & quote & ": " & quote & "Beat Box" & quote)
   TestAssert "the author", tJson contains (quote & "author" & quote & ": " & quote & "A. Name" & quote)
   TestAssert "quotes, backslashes, line ends and tabs are escaped", \
         tJson contains ("A drum machine, \" & quote & "sixteen\" & quote & " steps.\nBack\\slash and\ttab.")
   TestAssert "the stack's file", tJson contains (quote & "main" & quote & ": " & quote & "Beat Box.oxtstack" & quote)
   TestAssert "the picture", tJson contains (quote & "screenshot" & quote & ": " & quote & "screenshot.png" & quote)
   TestAssert "the words to find it by, lower-case", \
         tJson contains (quote & "tags" & quote & ": [" & quote & "music" & quote & ", " & quote & "sound" & quote & "]")
   TestAssert "one object, a line for each of the seven", the number of lines of tJson is 9 and \
         line 1 of tJson is "{" and line 9 of tJson is "}"

   put empty into tInfo["tags"]
   dispatch function "revShareStackListing" to stack sShare with tInfo, "Beat Box.oxtstack", empty
   put the result into tJson
   TestAssert "no picture, no screenshot", not (tJson contains "screenshot")
   TestAssert "no words, no tags", not (tJson contains "tags")
   TestAssert "and no comma left at the end", line -2 of tJson is ("  " & quote & "main" & quote & ": " & quote & "Beat Box.oxtstack" & quote)
end TestListing

-- What the gallery's checker refuses outright is said before anything
-- is asked
on TestCheck
   local tStack
   TestAssert "no stack", __Check(empty) begins with "There is no stack to share."
   put __Sample(empty) into tStack
   TestAssert "a stack that was never saved", __Check(tStack) begins with "Save your stack first"
   put __Sample("Beat Box.oxtstack") into tStack
   TestAssert "a saved stack can be shared", __Check(tStack) is empty
   TestAssert "a card of it stands for the stack", __Check(the long id of stack "TestShareStackSample") is empty
   set the externals of tStack to "mine.so"
   TestAssert "a stack that loads externals of its own", __Check(tStack) begins with "This stack loads externals of its own."
   put __Sample("Beat Box.txt") into tStack
   TestAssert "a file that does not end as a stack's", __Check(tStack) begins with "The stack's file must end in"
end TestCheck

on TestPack
   local tStack, tInfo, tZip, tItems, tFile, tPacked, tListing, tSecond
   TestLoadExternal "revzip"
   put __Sample("My Beat Box.oxtstack") into tStack
   put __Info() into tInfo
   dispatch "revShareStackPack" to stack sShare with tStack, tInfo, sFolder, "none"
   put the result into tZip
   TestDiagnostic "packed:" && tZip
   TestAssert "the package is named after the stack and its version", tZip is (sFolder & "/beat-box-1.0.zip")
   TestAssert "and is there", there is a file tZip

   revZipOpenArchive tZip, "read"
   put revZipEnumerateItems(tZip) into tItems
   TestAssert "it holds one folder, with the listing and the stack", the number of lines of tItems is 2 and \
         "stacks/beat-box/1.0/listing.json" is among the lines of tItems and \
         "stacks/beat-box/1.0/My Beat Box.oxtstack" is among the lines of tItems
   revZipExtractItemToVariable tZip, "stacks/beat-box/1.0/My Beat Box.oxtstack", "tPacked"
   revZipExtractItemToVariable tZip, "stacks/beat-box/1.0/listing.json", "tListing"
   revZipCloseArchive tZip
   put the effective filename of tStack into tFile
   TestAssert "the stack's file byte for byte", tPacked is url ("binfile:" & tFile) and tPacked is not empty
   TestAssert "the listing names the stack's file", \
         textDecode(tListing, "UTF-8") contains (quote & "main" & quote & ": " & quote & "My Beat Box.oxtstack" & quote)

   -- With a picture, and a second time: nothing is written over
   dispatch "revShareStackPack" to stack sShare with tStack, tInfo, sFolder, "not really a PNG"
   put the result into tSecond
   TestAssert "a second package gets a name of its own", tSecond is (sFolder & "/beat-box-1.0 2.zip")
   revZipOpenArchive tSecond, "read"
   put revZipEnumerateItems(tSecond) into tItems
   revZipExtractItemToVariable tSecond, "stacks/beat-box/1.0/listing.json", "tListing"
   revZipCloseArchive tSecond
   TestAssert "the picture is packed", "stacks/beat-box/1.0/screenshot.png" is among the lines of tItems
   TestAssert "and the listing names it", textDecode(tListing, "UTF-8") contains "screenshot.png"

   -- Refused, and nothing written
   put empty into tInfo["author"]
   dispatch "revShareStackPack" to stack sShare with tStack, tInfo, sFolder, "none"
   TestAssert "a listing that is not in order is not packed", the result is "error: Your name is missing."
   put __Info() into tInfo
   dispatch "revShareStackPack" to stack sShare with tStack, tInfo, sFolder & "/not-there", "none"
   TestAssert "nor is a package for a folder that is not there", the result begins with "error: There is no folder"
   TestAssert "two packages and the stack, no more", the number of lines of files(sFolder) is 3
end TestPack

-- A file name the gallery would refuse (NAME in tools/scan.py takes
-- letters, digits, spaces and a few marks) is made one it takes
on TestPackRenamesAnAwkwardFile
   local tStack, tInfo, tZip, tItems
   TestLoadExternal "revzip"
   put __Sample("#beat~box$.oxtstack") into tStack
   put __Info() into tInfo
   dispatch "revShareStackPack" to stack sShare with tStack, tInfo, sFolder, "none"
   put the result into tZip
   revZipOpenArchive tZip, "read"
   put revZipEnumerateItems(tZip) into tItems
   revZipCloseArchive tZip
   TestAssert "the marks are left out of the name in the package", \
         "stacks/beat-box/1.0/beatbox.oxtstack" is among the lines of tItems
end TestPackRenamesAnAwkwardFile
