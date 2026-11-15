script "revShareStack"
-- OXT-Beyond: File > Share Stack..., which packs a stack for the OXT
-- Community Stacks (github.com/SethMorrowSoftware/oxt-community-stacks),
-- the gallery of stacks that anybody can play in a web browser.
--
-- Most people who make stacks do not use GitHub, and the gallery takes a
-- stack as a folder in a pull request. This window asks the few things
-- the gallery shows (a title, the author's name, a sentence or two, a
-- licence), takes a picture of the stack, and writes one .zip to the
-- Desktop that holds the folder as the gallery wants it:
--
--    stacks/<name>/<version>/listing.json
--    stacks/<name>/<version>/<the stack's file>
--    stacks/<name>/<version>/screenshot.png
--
-- The author posts that file on the forum, and an admin of the gallery
-- gives it to the repository's tools/accept.py, which checks it again
-- from nothing. So what this window checks is a courtesy to the author,
-- who learns here and now what would be refused there; it is not what
-- keeps the gallery safe.
--
-- Nothing of the stack is changed and nothing is sent anywhere: the
-- stack's file is copied as it was last saved, and this window opens
-- nothing but itself. (revIDEActionShareStack, which shows it, opens the
-- forum in the browser when the user asks.)
--
-- It is drawn by revLearnKit, which is its behavior, as revKitDialog is.
-- It is a script-only stack, so it keeps no controls: this script builds
-- them each time it opens. Its name begins with "rev", so the IDE treats
-- it as one of its own windows.
--
-- The rules below are the gallery's (tools/listing.py and tools/scan.py
-- there). tools/ci/tests/test_share_stack.py holds this copy of them to
-- the values the gallery had when it was written, and
-- tests/lcs/sharestack runs them and the packing in the engine.

constant kWidth = 640
constant kHeroHeight = 104
constant kPad = 24
constant kButtonHeight = 34

-- The gallery's limits (tools/listing.py LENGTHS, tools/scan.py)
constant kTitleMin = 2
constant kTitleMax = 60
constant kAuthorMin = 2
constant kAuthorMax = 40
constant kAboutMin = 10
constant kAboutMax = 600
constant kSlugMin = 3
constant kSlugMax = 40
constant kMaxTags = 5
constant kMaxTagChars = 20
constant kMaxFileBytes = 26214400
constant kStackExtensions = "oxtstack,livecode,rev,livecodescript"

-- The stack being shared (the long id of its main stack), what the user
-- has typed, the folder the package goes to (empty: the Desktop), and
-- what the window closes with (the package's path, or empty)
local sStack, sInfo, sFolder, sResult
-- The picture of the stack, as PNG, and true when the box is ticked
local sPicture, sAgreed
-- True while the window is being built
local sBuilding

################################################################################
#
# The rules, which a script can ask without the window
#

-- The licences an author can choose, a line each: the gallery's name for
-- it (an SPDX identifier), what the menu says, and the short name the
-- window shows once it is chosen
function revShareStackLicences
   return "MIT|MIT: others may use it freely, and keep your name on it|MIT" & return & \
         "CC0-1.0|Public domain (CC0): others may do anything with it|Public domain (CC0)" & return & \
         "GPL-3.0-or-later|GPL 3 or later: others may use it, and share their changes the same way|GPL 3 or later" & return & \
         "Apache-2.0|Apache 2.0|Apache 2.0" & return & \
         "BSD-2-Clause|BSD 2-Clause|BSD 2-Clause" & return & \
         "BSD-3-Clause|BSD 3-Clause|BSD 3-Clause" & return & \
         "GPL-3.0-only|GPL 3|GPL 3" & return & \
         "GPL-2.0-or-later|GPL 2 or later|GPL 2 or later" & return & \
         "LGPL-3.0-or-later|LGPL 3 or later|LGPL 3 or later" & return & \
         "MPL-2.0|MPL 2.0|MPL 2.0" & return & \
         "CC-BY-4.0|CC BY 4.0|CC BY 4.0" & return & \
         "CC-BY-SA-4.0|CC BY-SA 4.0|CC BY-SA 4.0" & return & \
         "Unlicense|Public domain (Unlicense)|Public domain (Unlicense)"
end revShareStackLicences

-- The folder name the gallery gives a stack with this title: lower-case
-- letters and digits with single hyphens between them, 3 to 40 long
function revShareStackSlug pTitle
   local tSlug, tChar, tHyphen
   put true into tHyphen
   repeat for each char tChar in toLower(pTitle)
      if tChar is in "abcdefghijklmnopqrstuvwxyz0123456789" then
         put tChar after tSlug
         put false into tHyphen
      else if not tHyphen then
         put "-" after tSlug
         put true into tHyphen
      end if
   end repeat
   if the last char of tSlug is "-" then
      delete the last char of tSlug
   end if
   if the number of chars of tSlug > kSlugMax then
      put char 1 to kSlugMax of tSlug into tSlug
      if the last char of tSlug is "-" then
         delete the last char of tSlug
      end if
   end if
   if the number of chars of tSlug < kSlugMin then
      if tSlug is empty then
         put "stack" into tSlug
      else
         put "-stack" after tSlug
      end if
   end if
   return tSlug
end revShareStackSlug

-- Why the stack pStack cannot be shared as it is, in words for its
-- author, or empty when it can. These are the things the gallery's
-- checker refuses outright and the author can only mend in the stack.
function revShareStackCheck pStack
   local tMain, tFile, tExtension, tSize
   if pStack is empty or not exists(pStack) then
      return "There is no stack to share. Open your stack first."
   end if
   put ssMainStack(pStack) into tMain
   put the effective filename of tMain into tFile
   if tFile is empty or there is no file tFile then
      return "Save your stack first (File > Save). Share Stack packs the stack's file as it was last saved."
   end if
   if the password of tMain is not empty then
      return "This stack has a password. Everyone must be able to read a shared stack's scripts, so " & \
            "a stack with a password cannot be shared. Take the password off, save, and share again."
   end if
   if the externals of tMain is not empty then
      return "This stack loads externals of its own. Stacks in the gallery play in a web browser, which " & \
            "cannot load them, so the gallery does not take such a stack. The libraries that come with " & \
            "OXT-Beyond are fine."
   end if
   set the itemDelimiter to "."
   put toLower(the last item of tFile) into tExtension
   set the itemDelimiter to comma
   if tExtension is not among the items of kStackExtensions then
      return "The stack's file must end in .oxtstack, .livecode, .rev or .livecodescript. " & \
            "Save it under such a name (File > Save As) and share again."
   end if
   put ssFileSize(tFile) into tSize
   if tSize > kMaxFileBytes then
      return "The stack's file is bigger than 25 MB, the most the gallery takes."
   end if
   return empty
end revShareStackCheck

-- What is wrong with what the author typed, a line each, in the order
-- of the window's boxes; empty when all of it is in order. pInfo holds
-- "title", "author", "about", "licence", "version" and "tags" (words
-- with commas between them).
function revShareStackProblems pInfo
   local tProblems, tText, tCount, tTag, tLine, tFound
   put ssClean(pInfo["title"]) into tText
   put ssPlainProblem("The title", tText, kTitleMin, kTitleMax) into tLine
   if tLine is not empty then put tLine & return after tProblems
   put ssClean(pInfo["author"]) into tText
   put ssPlainProblem("Your name", tText, kAuthorMin, kAuthorMax) into tLine
   if tLine is not empty then put tLine & return after tProblems
   put word 1 to -1 of pInfo["about"] into tText
   put ssPlainProblem("What it does", tText, kAboutMin, kAboutMax) into tLine
   if tLine is not empty then put tLine & return after tProblems
   put false into tFound
   set the itemDelimiter to "|"
   repeat for each line tLine in revShareStackLicences()
      if item 1 of tLine is pInfo["licence"] then
         put true into tFound
      end if
   end repeat
   set the itemDelimiter to comma
   if not tFound then
      put "Choose how others may use your stack." & return after tProblems
   end if
   if not ssIsVersion(pInfo["version"]) then
      put "The version must be a number such as 1, 1.2 or 1.2.3." & return after tProblems
   end if
   put 0 into tCount
   repeat for each item tTag in ssTags(pInfo["tags"])
      add 1 to tCount
      if not ssIsTag(tTag) then
         put "A word to find it by can have letters, digits, spaces and hyphens only, and at most " & \
               kMaxTagChars & " of them: " & quote & tTag & quote & " cannot be used." & return after tProblems
      end if
   end repeat
   if tCount > kMaxTags then
      put "At most five words to find it by." & return after tProblems
   end if
   if the last char of tProblems is return then
      delete the last char of tProblems
   end if
   return tProblems
end revShareStackProblems

-- listing.json for pInfo and the names of the stack's file and of its
-- picture (empty for none): what the gallery shows for the stack
function revShareStackListing pInfo, pMain, pPicture
   local tJson, tTags, tTag
   put "{" & return into tJson
   put "  " & ssJson("title") & ": " & ssJson(ssClean(pInfo["title"])) & "," & return after tJson
   put "  " & ssJson("author") & ": " & ssJson(ssClean(pInfo["author"])) & "," & return after tJson
   put "  " & ssJson("description") & ": " & ssJson(word 1 to -1 of pInfo["about"]) & "," & return after tJson
   put "  " & ssJson("licence") & ": " & ssJson(pInfo["licence"]) & "," & return after tJson
   put "  " & ssJson("main") & ": " & ssJson(pMain) after tJson
   if pPicture is not empty then
      put "," & return & "  " & ssJson("screenshot") & ": " & ssJson(pPicture) after tJson
   end if
   repeat for each item tTag in ssTags(pInfo["tags"])
      if tTags is not empty then
         put ", " after tTags
      end if
      put ssJson(tTag) after tTags
   end repeat
   if tTags is not empty then
      put "," & return & "  " & ssJson("tags") & ": [" & tTags & "]" after tJson
   end if
   put return & "}" & return after tJson
   return tJson
end revShareStackListing

-- Packs the stack pStack with what pInfo says about it into a .zip in
-- the folder pFolder (when empty the Desktop, or where there is none the
-- documents folder, or the home folder). pPicture is a picture of
-- the stack as PNG; empty takes one of its current card, and "none"
-- packs none. Returns the package's path in the result, or "error: "
-- and why not.
command revShareStackPack pStack, pInfo, pFolder, pPicture
   local tProblem, tMain, tFile, tSlug, tVersion, tName, tBase, tWork, tZip, tError, tPictureName, tIndex, tPath
   put revShareStackCheck(pStack) into tProblem
   if tProblem is not empty then
      return "error:" && tProblem
   end if
   put revShareStackProblems(pInfo) into tProblem
   if tProblem is not empty then
      return "error:" && line 1 of tProblem
   end if
   put ssMainStack(pStack) into tMain
   put the effective filename of tMain into tFile
   put revShareStackSlug(pInfo["title"]) into tSlug
   put pInfo["version"] into tVersion
   put ssFileName(tFile, ssClean(pInfo["title"])) into tName
   if pFolder is empty then
      put ssFolder() into pFolder
   end if
   if there is no folder pFolder then
      return "error: There is no folder" && pFolder & "."
   end if
   if pPicture is empty then
      put ssSnapshot(tMain) into pPicture
   else if pPicture is "none" then
      put empty into pPicture
   end if
   if pPicture is not empty then
      put "screenshot.png" into tPictureName
   end if

   -- A name that is not taken: beat-box-1.0.zip, beat-box-1.0 2.zip, ...
   put tSlug & "-" & tVersion into tBase
   put pFolder & slash & tBase & ".zip" into tZip
   put 1 into tIndex
   repeat while there is a file tZip
      add 1 to tIndex
      put pFolder & slash & tBase && tIndex & ".zip" into tZip
   end repeat

   put the tempName & "-share" into tWork
   put "stacks/" & tSlug & "/" & tVersion & "/" into tPath
   try
      create folder tWork
      if there is no folder tWork then
         throw "the package could not be put together (no room for it in the temporary folder)"
      end if
      -- (the stack's file as it is on the disk, byte for byte)
      put url ("binfile:" & tFile) into url ("binfile:" & tWork & slash & "stack")
      if the result is not empty then
         throw "the stack's file could not be read (" & the result & ")"
      end if
      put textEncode(revShareStackListing(pInfo, tName, tPictureName), "UTF-8") into url ("binfile:" & tWork & slash & "listing.json")
      if pPicture is not empty then
         put pPicture into url ("binfile:" & tWork & slash & "screenshot.png")
      end if
      revZipOpenArchive tZip, "write"
      if the result is not empty then
         throw "the package could not be made in" && pFolder && "(" & the result & ")"
      end if
      revZipAddItemWithFile tZip, tPath & "listing.json", tWork & slash & "listing.json"
      if the result is not empty then throw "the package could not be written (" & the result & ")"
      revZipAddItemWithFile tZip, tPath & tName, tWork & slash & "stack"
      if the result is not empty then throw "the package could not be written (" & the result & ")"
      if pPicture is not empty then
         revZipAddItemWithFile tZip, tPath & "screenshot.png", tWork & slash & "screenshot.png"
         if the result is not empty then throw "the package could not be written (" & the result & ")"
      end if
      revZipCloseArchive tZip
      if the result is not empty then
         throw "the package could not be finished (" & the result & ")"
      end if
   catch tError
      -- (a half-made package is no use to anybody)
      try
         revZipCloseArchive tZip
      end try
      if there is a file tZip then
         delete file tZip
      end if
      ssRemoveWork tWork
      return "error: Sorry," && line 1 of tError & "."
   end try
   ssRemoveWork tWork
   if there is no file tZip then
      return "error: Sorry, the package could not be made in" && pFolder & "."
   end if
   return tZip
end revShareStackPack

-- Where a package goes when nobody says: the Desktop, where its author
-- finds it again
private function ssFolder
   local tWhich, tFolder
   repeat for each item tWhich in "desktop,documents,home"
      put specialFolderPath(tWhich) into tFolder
      if tFolder is not empty and there is a folder tFolder then
         return tFolder
      end if
   end repeat
   return empty
end ssFolder

-- The main stack of a stack, as a long id
private function ssMainStack pStack
   return the long id of stack (the mainStack of pStack)
end ssMainStack

private function ssFileSize pFile
   local tFolder, tName, tLine, tSize
   set the itemDelimiter to slash
   put the last item of pFile into tName
   put item 1 to -2 of pFile into tFolder
   set the itemDelimiter to comma
   put 0 into tSize
   repeat for each line tLine in files(tFolder, "detailed")
      if urlDecode(item 1 of tLine) is tName then
         put item 2 of tLine into tSize
         exit repeat
      end if
   end repeat
   return tSize
end ssFileSize

-- A line of text as the gallery keeps it: every run of spaces, tabs and
-- line ends made one space
private function ssClean pText
   local tOut, tWord
   replace tab with space in pText
   replace return with space in pText
   set the itemDelimiter to space
   repeat for each item tWord in pText
      if tWord is not empty then
         put tWord & space after tOut
      end if
   end repeat
   delete the last char of tOut
   return tOut
end ssClean

-- What is wrong with a line of plain text, or empty
private function ssPlainProblem pWhat, pText, pMin, pMax
   local tCount, tChar, tLower
   put the number of chars of pText into tCount
   if tCount is 0 then
      return pWhat && "is missing."
   end if
   repeat for each char tChar in pText
      if (codepointToNum(tChar) < 32 and tChar is not return) or codepointToNum(tChar) is 127 then
         return pWhat && "has a character that cannot be shown. Type it again, without pasting."
      end if
   end repeat
   if "<" is in pText or ">" is in pText then
      return pWhat && "cannot have < or > in it."
   end if
   put toLower(pText) into tLower
   if "http://" is in tLower or "https://" is in tLower or "ftp://" is in tLower or "www." is in tLower then
      return pWhat && "cannot have a web address in it."
   end if
   if tCount < pMin then
      return pWhat && "is too short (at least" && pMin && "letters)."
   end if
   if tCount > pMax then
      return pWhat && "is too long (" & tCount && "letters; at most" && pMax & ")."
   end if
   return empty
end ssPlainProblem

-- 1, 1.2, 1.2.3 or 1.2.3.4
private function ssIsVersion pVersion
   local tPart, tChar
   if pVersion is empty or the number of chars of pVersion > 20 then
      return false
   end if
   if the first char of pVersion is "." or the last char of pVersion is "." or ".." is in pVersion then
      return false
   end if
   set the itemDelimiter to "."
   if the number of items of pVersion > 4 then
      return false
   end if
   repeat for each item tPart in pVersion
      if tPart is empty then
         return false
      end if
      repeat for each char tChar in tPart
         if tChar is not in "0123456789" then
            return false
         end if
      end repeat
   end repeat
   return true
end ssIsVersion

-- The words to find a stack by, as the gallery keeps them: lower-case,
-- with commas between them, none twice
private function ssTags pTags
   local tOut, tTag
   replace return with comma in pTags
   repeat for each item tTag in toLower(pTags)
      put word 1 to -1 of tTag into tTag
      if tTag is empty or tTag is among the items of tOut then
         next repeat
      end if
      if tOut is not empty then
         put comma after tOut
      end if
      put tTag after tOut
   end repeat
   return tOut
end ssTags

-- Lower-case letters and digits, in words with one space or hyphen
-- between them
private function ssIsTag pTag
   local tChar, tBreak
   if pTag is empty or the number of chars of pTag > kMaxTagChars then
      return false
   end if
   put true into tBreak
   repeat for each char tChar in pTag
      if tChar is in "abcdefghijklmnopqrstuvwxyz0123456789" then
         put false into tBreak
      else if (tChar is space or tChar is "-") and not tBreak then
         put true into tBreak
      else
         return false
      end if
   end repeat
   return not tBreak
end ssIsTag

-- The name the stack's file has in the package: its own when the gallery
-- takes it (letters, digits, spaces and . _ - only, a letter or a digit
-- first), else one made from the title
private function ssFileName pFile, pTitle
   local tName, tExtension, tChar, tOut, tGood
   set the itemDelimiter to slash
   put the last item of pFile into tName
   set the itemDelimiter to "."
   put toLower(the last item of tName) into tExtension
   put item 1 to -2 of tName into tName
   set the itemDelimiter to comma
   put ssPlainName(tName) into tOut
   if tOut is empty then
      put ssPlainName(pTitle) into tOut
   end if
   if tOut is empty then
      put "Stack" into tOut
   end if
   return tOut & "." & tExtension
end ssFileName

private function ssPlainName pName
   local tOut, tChar
   repeat for each char tChar in pName
      if tChar is in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" then
         put tChar after tOut
      else if tChar is in " ._-" and tOut is not empty then
         put tChar after tOut
      end if
   end repeat
   put word 1 to -1 of tOut into tOut
   repeat while tOut is not empty and the last char of tOut is in "._-"
      delete the last char of tOut
   end repeat
   return char 1 to 80 of tOut
end ssPlainName

-- A JSON string
private function ssJson pText
   local tOut, tChar, tCode
   repeat for each char tChar in pText
      put codepointToNum(tChar) into tCode
      if tChar is quote then
         put "\" & quote after tOut
      else if tChar is "\" then
         put "\\" after tOut
      else if tCode is 10 or tCode is 13 then
         put "\n" after tOut
      else if tCode is 9 then
         put "\t" after tOut
      else if tCode < 32 or tCode is 127 then
         put space after tOut
      else
         put tChar after tOut
      end if
   end repeat
   return quote & tOut & quote
end ssJson

-- A picture of the stack's current card, as PNG, or empty when none
-- can be taken
private function ssSnapshot pMain
   local tPng
   try
      export snapshot from this card of pMain to tPng as PNG
   catch tPng
      return empty
   end try
   return tPng
end ssSnapshot

private command ssRemoveWork pFolder
   local tName
   if pFolder is empty or there is no folder pFolder then
      exit ssRemoveWork
   end if
   repeat for each item tName in "stack,listing.json,screenshot.png"
      if there is a file (pFolder & slash & tName) then
         delete file (pFolder & slash & tName)
      end if
   end repeat
   delete folder pFolder
end ssRemoveWork

################################################################################
#
# The window
#

-- Asks about the stack pStack and packs it into the folder pFolder (the
-- Desktop when empty). Returns the package's path in the result, empty
-- when the user closed the window without packing, or "error: " and why
-- the stack cannot be shared as it is. Throws when the window cannot
-- open.
command revShareStackShow pStack, pFolder
   local tProblem
   if the mode of me is not 0 then
      throw "the window is open already"
   end if
   put revShareStackCheck(pStack) into tProblem
   if tProblem is not empty then
      return "error:" && tProblem
   end if
   put ssMainStack(pStack) into sStack
   put pFolder into sFolder
   put empty into sResult
   put false into sAgreed
   put ssSnapshot(sStack) into sPicture
   put empty into sInfo
   put the label of sStack into sInfo["title"]
   if sInfo["title"] is empty then
      put the short name of sStack into sInfo["title"]
   end if
   put ssRemembered("author") into sInfo["author"]
   put ssRemembered("licence") into sInfo["licence"]
   if sInfo["licence"] is empty then
      put "MIT" into sInfo["licence"]
   end if
   put "1.0" into sInfo["version"]
   ssUseKit
   modal me
   return sResult
end revShareStackShow

on preOpenStack
   get lkReadAppearance()
   ssBuild
   ssPlace
   -- (a script-only stack is made invisible when it is loaded)
   show me
end preOpenStack

on openStack
   lkStartTicking
   lkEnter "side"
   lkFollowAppearance
   if there is a field "title" of me then
      select the text of field "title" of me
   end if
end openStack

on closeStack
   lkStopTicking
end closeStack

-- The desktop switched between light and dark (revLearnKit): built again
-- in the other colours, with what was typed
on lkAppearanceChanged
   if sBuilding or sStack is empty then
      exit lkAppearanceChanged
   end if
   ssRead
   ssBuild
end lkAppearanceChanged

-- Escape closes the window; nothing is packed
on rawKeyDown pKey
   if pKey is 65307 then
      put empty into sResult
      close me
   else
      pass rawKeyDown
   end if
end rawKeyDown

-- Return packs, except in the box of what the stack does, where it
-- starts a new line
on returnInField
   if the short name of the target is "about" then
      pass returnInField
   end if
   ssPack
end returnInField

on enterInField
   ssPack
end enterInField

-- (and when no box has the keyboard)
on returnKey
   ssPack
end returnKey

on enterKey
   ssPack
end enterKey

-- Tab goes to the next box, in the box of what the stack does too
on tabKey
   local tOrder, tName, tIndex
   put "title,author,version,about,tags" into tOrder
   put the short name of the focusedObject into tName
   put itemOffset(tName, tOrder) into tIndex
   if tIndex is 0 then
      pass tabKey
   end if
   if the shiftKey is down then
      subtract 1 from tIndex
      if tIndex < 1 then
         put the number of items of tOrder into tIndex
      end if
   else
      add 1 to tIndex
      if tIndex > the number of items of tOrder then
         put 1 into tIndex
      end if
   end if
   select the text of field (item tIndex of tOrder) of me
end tabKey

-- The count under the box of what the stack does
on textChanged
   if the short name of the target is "about" then
      ssCount
   end if
   pass textChanged
end textChanged

-- The licence chosen in the menu
on menuPick pWhich
   local tLine
   if the short name of the target is not "licenceMenu" then
      pass menuPick
   end if
   set the itemDelimiter to "|"
   repeat for each line tLine in revShareStackLicences()
      if item 2 of tLine is pWhich then
         put item 1 of tLine into sInfo["licence"]
         put item 3 of tLine into field "licence" of me
         exit repeat
      end if
   end repeat
end menuPick

on lkAction pAction
   switch pAction
      case "pack"
         ssPack
         break
      case "cancel"
         put empty into sResult
         close me
         break
      case "agree"
         put not sAgreed into sAgreed
         ssShowAgreed
         -- (what was in the way may have been this box)
         if sAgreed then
            put empty into field "problem" of me
         end if
         break
      case "licence"
         popup button "licenceMenu" of me at the left of graphic "licence_box" of me, the bottom of graphic "licence_box" of me + 2
         break
   end switch
end lkAction

-- The kit is this stack's behavior (see revLearnKit)
private command ssUseKit
   local tKit
   if the behavior of me is not empty then
      exit ssUseKit
   end if
   if there is no stack "revLearnKit" then
      put ssToolset() & "/palettes/learn/revlearnkit.livecodescript" into tKit
      if there is no file tKit then
         throw "no revLearnKit"
      end if
      -- (naming the file loads the stack)
      get the short name of stack tKit
   end if
   set the behavior of me to the long id of stack "revLearnKit"
end ssUseKit

-- The IDE's Toolset folder, from this stack's file
private function ssToolset
   set the itemDelimiter to slash
   return item 1 to -4 of the filename of me
end ssToolset

-- In the middle of the screen, a little above it
private command ssPlace
   local tScreen, tHeight
   put the screenRect into tScreen
   put the height of me into tHeight
   set the loc of me to (item 1 of tScreen + item 3 of tScreen) div 2, \
         max(item 2 of tScreen + tHeight div 2 + 30, (item 2 of tScreen + item 4 of tScreen) div 2 - 30)
end ssPlace

-- What the user last gave as their name and licence, kept with the
-- IDE's preferences so that the second stack takes less typing
private function ssRemembered pWhat
   local tValue
   try
      put revIDEGetPreference("ShareStack_" & pWhat) into tValue
   catch tValue
      return empty
   end try
   return tValue
end ssRemembered

private command ssRemember pWhat, pValue
   try
      revIDESetPreference "ShareStack_" & pWhat, pValue
   end try
end ssRemember

-- A box to type in, with its name above it; returns the field
private function ssBox pName, pLabel, pLeft, pTop, pRight, pHeight, pText
   local tObj
   get lkLabel(pName & "_label", lkR(pLeft, pTop, pRight, pTop + 18), pLabel, 12, lkColor("soft"), empty)
   put lkBox(pName & "_box", lkR(pLeft, pTop + 22, pRight, pTop + 22 + pHeight), lkColor("panel"), 10, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkInput(pName, lkR(pLeft + 12, pTop + 22 + 11, pRight - 10, pTop + 22 + pHeight - 4), pText, 14, empty) into tObj
   return tObj
end ssBox

private command ssBuild
   local tSaved, tObj, tTop, tLeft, tRight, tMid, tLine, tMenu, tShort, tLook, tWidth, tHeight, tPicture, tRect, tX
   put true into sBuilding
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   -- (the stack can still be in memory from the last time it opened, and
   -- the kit with it: it forgets the controls that are about to go)
   lkForget "side"
   repeat while the number of controls of this card > 0
      delete control 1 of this card
   end repeat
   set the label of me to "Share Stack"
   set the destroyStack of me to true
   set the resizable of me to false
   set the rect of me to 0, 0, kWidth, 400
   set the backgroundColor of me to lkColor("bg")
   put kPad - 6 into tLeft
   put kWidth - kPad + 6 into tRight

   -- The header
   put lkBox("heroBg", lkR(0, 0, kWidth, kHeroHeight), lkColor("side"), 0, empty) into tObj
   lkGradient tObj, lkColor("side") & "|" & lkMix(lkColor("side"), lkColor("violet"), 0.12) & "|" & \
         lkMix(lkColor("side"), lkColor("violet"), 0.3), "0,0", kWidth & "," & kHeroHeight
   put lkBox("heroMark", lkR(kPad, 26, kPad + 52, 78), lkColor("violet"), 26, empty) into tObj
   lkGradient tObj, lkMix(lkColor("violet"), "255,255,255", 0.2) & "|" & lkMix(lkColor("violet"), "15,23,42", 0.15), \
         kPad & ",26", (kPad + 52) & ",78"
   lkGlow tObj, lkColor("violet"), 16, 80
   get lkIcon("heroMarkIcon", "send", "255,255,255", lkR(kPad + 13, 39, kPad + 39, 65), empty)
   put lkLabel("heroTitle", lkR(kPad + 72, 26, kWidth - kPad, 54), "Share your stack", 21, "255,255,255", empty) into tObj
   put lkLabel("heroSub", lkR(kPad + 72, 58, kWidth - kPad, 78), \
         "Pack it for the OXT Community Stacks, where anyone can play it in a browser", 13, lkColor("sideInk"), empty) into tObj
   lkEllipsize tObj

   put kHeroHeight + 18 into tTop

   -- The title
   get ssBox("title", "Title", tLeft, tTop, tRight, 38, sInfo["title"])
   add 72 to tTop

   -- The author's name, and the version
   put tRight - 130 into tMid
   get ssBox("author", "Your name, as you want it shown", tLeft, tTop, tMid - 12, 38, sInfo["author"])
   get ssBox("version", "Version", tMid, tTop, tRight, 38, sInfo["version"])
   add 72 to tTop

   -- What it does
   put ssBox("about", "What does it do? A sentence or two.", tLeft, tTop, tRight, 84, sInfo["about"]) into tObj
   set the dontWrap of tObj to false
   set the textHeight of tObj to 19
   put lkLabel("aboutCount", lkR(tRight - 160, tTop, tRight, tTop + 18), empty, 12, lkColor("muted"), empty, "right") into tObj
   add 118 to tTop

   -- The licence, a box that opens a menu, and the words to find it by
   put tLeft + 250 into tMid
   get lkLabel("licence_label", lkR(tLeft, tTop, tMid, tTop + 18), "How may others use it?", 12, lkColor("soft"), empty)
   get lkGroup("licenceBox", lkR(tLeft, tTop + 22, tMid, tTop + 60), empty)
   put lkBox("licence_box", lkR(tLeft, tTop + 22, tMid, tTop + 60), lkColor("panel"), 10, "licenceBox") into tObj
   lkBorder tObj, lkColor("line")
   put ssLicenceShort(sInfo["licence"]) into tShort
   put lkLabel("licence", lkR(tLeft + 12, tTop + 33, tMid - 34, tTop + 55), tShort, 14, lkColor("ink"), "licenceBox") into tObj
   lkEllipsize tObj
   get lkIcon("licence_chevron", "chevron-right", lkColor("muted"), lkR(tMid - 28, tTop + 33, tMid - 12, tTop + 49), "licenceBox")
   put "licence_box" into tLook["bg"]
   put lkColor("panel") into tLook["bg0"]
   put lkTint(lkColor("violet"), 0.06) into tLook["bg1"]
   put lkColor("line") into tLook["line0"]
   put lkColor("violet") into tLook["line1"]
   lkLive "licenceBox", "side", "licence", tLook
   -- (the menu itself: a button nobody sees, popped up under the box)
   set the itemDelimiter to "|"
   repeat for each line tLine in revShareStackLicences()
      put item 2 of tLine & return after tMenu
      if item 1 of tLine is "GPL-3.0-or-later" then
         put "-" & return after tMenu
      end if
   end repeat
   set the itemDelimiter to comma
   delete the last char of tMenu
   create button "licenceMenu"
   set the style of it to "menu"
   set the menuMode of it to "popup"
   set the text of it to tMenu
   set the visible of it to false
   get ssBox("tags", "Words to find it by (optional)", tMid + 12, tTop, tRight, 38, sInfo["tags"])
   add 76 to tTop

   -- The picture, and the promise
   put lkBox("pictureBg", lkR(tLeft, tTop, tLeft + 150, tTop + 96), lkColor("panel"), 10, empty) into tObj
   lkBorder tObj, lkColor("line")
   if sPicture is not empty then
      create image "picture"
      put it into tPicture
      set the lockLoc of tPicture to false
      set the text of tPicture to sPicture
      put the formattedWidth of tPicture into tWidth
      put the formattedHeight of tPicture into tHeight
      if tWidth > 0 and tHeight > 0 then
         set the lockLoc of tPicture to true
         set the resizeQuality of tPicture to "best"
         put ssFit(tWidth, tHeight, 138, 84) into tRect
         set the width of tPicture to item 1 of tRect
         set the height of tPicture to item 2 of tRect
         set the loc of tPicture to tLeft + 75, tTop + 48
      else
         delete tPicture
      end if
   end if
   put lkLabel("pictureNote", lkR(tLeft + 166, tTop + 2, tRight, tTop + 44), \
         "A picture of your stack as it looks now goes with it. The stack's file is packed as it was last saved.", \
         12, lkColor("soft"), empty) into tObj
   set the textHeight of tObj to 17
   -- (the tick box)
   get lkGroup("agree", lkR(tLeft + 166, tTop + 54, tRight, tTop + 92), empty)
   put lkBox("agree_bg", lkR(tLeft + 166, tTop + 54, tRight, tTop + 92), lkColor("bg"), 8, "agree") into tObj
   put lkBox("agree_box", lkR(tLeft + 170, tTop + 63, tLeft + 190, tTop + 83), lkColor("panel"), 6, "agree") into tObj
   lkBorder tObj, lkColor("muted")
   get lkIcon("agree_tick", "check", "255,255,255", lkR(tLeft + 173, tTop + 66, tLeft + 187, tTop + 80), "agree")
   put lkLabel("agree_label", lkR(tLeft + 200, tTop + 64, tRight - 4, tTop + 84), \
         "I made this stack, or I have the right to share it.", 13, lkColor("ink"), "agree") into tObj
   put empty into tLook
   put "agree_bg" into tLook["bg"]
   put lkColor("bg") into tLook["bg0"]
   put lkTint(lkColor("violet"), 0.06) into tLook["bg1"]
   lkLive "agree", "side", "agree", tLook
   add 108 to tTop

   -- What is in the way, when Pack is pressed too soon
   put lkLabel("problem", lkR(tLeft, tTop, tRight, tTop + 36), empty, 13, lkColor("bad"), empty) into tObj
   set the textHeight of tObj to 17
   add 44 to tTop

   -- The foot
   put lkButton("packButton", 0, tTop, kButtonHeight, "Pack My Stack", "package", "primary", lkColor("violet"), empty, "pack", 150) into tWidth
   set the right of group "packButton" to tRight
   lkRestAt "packButton"
   put the left of group "packButton" - 10 into tX
   put lkButton("cancelButton", 0, tTop, kButtonHeight, "Cancel", empty, "ghost", lkColor("violet"), empty, "cancel", 90) into tWidth
   set the right of group "cancelButton" to tX
   lkRestAt "cancelButton"
   set the rect of me to 0, 0, kWidth, tTop + kButtonHeight + 20

   put false into sBuilding
   unlock messages
   unlock screen
   ssShowAgreed
   ssCount
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end ssBuild

-- The width and height of a picture pWidth by pHeight made to fit
-- pMaxWidth by pMaxHeight, never made bigger
private function ssFit pWidth, pHeight, pMaxWidth, pMaxHeight
   local tScale
   put min(1, pMaxWidth / pWidth, pMaxHeight / pHeight) into tScale
   return max(1, round(pWidth * tScale)) & comma & max(1, round(pHeight * tScale))
end ssFit

private function ssLicenceShort pLicence
   local tLine
   set the itemDelimiter to "|"
   repeat for each line tLine in revShareStackLicences()
      if item 1 of tLine is pLicence then
         return item 3 of tLine
      end if
   end repeat
   return "Choose one"
end ssLicenceShort

-- The tick box as it is: ticked or not
private command ssShowAgreed
   if there is no graphic "agree_box" of me then
      exit ssShowAgreed
   end if
   if sAgreed then
      set the backgroundColor of graphic "agree_box" of me to lkColor("violet")
      set the foregroundColor of graphic "agree_box" of me to lkColor("violet")
   else
      set the backgroundColor of graphic "agree_box" of me to lkColor("panel")
      set the foregroundColor of graphic "agree_box" of me to lkColor("muted")
   end if
   set the visible of control "agree_tick" of me to sAgreed
end ssShowAgreed

-- How much of the room for what the stack does is used
private command ssCount
   local tCount
   if there is no field "aboutCount" of me then
      exit ssCount
   end if
   put the number of chars of (word 1 to -1 of field "about" of me) into tCount
   put tCount && "of" && kAboutMax into field "aboutCount" of me
   if tCount > kAboutMax then
      set the textColor of field "aboutCount" of me to lkColor("bad")
   else
      set the textColor of field "aboutCount" of me to lkColor("muted")
   end if
end ssCount

-- What the boxes hold, into sInfo
private command ssRead
   local tName
   repeat for each item tName in "title,author,version,about,tags"
      if there is a field tName of me then
         put the text of field tName of me into sInfo[tName]
      end if
   end repeat
   put word 1 to -1 of sInfo["version"] into sInfo["version"]
end ssRead

-- Pack My Stack: says what is in the way, or packs and closes
private command ssPack
   local tProblems, tResult
   ssRead
   put revShareStackProblems(sInfo) into tProblems
   if tProblems is empty and not sAgreed then
      put "Tick the box to say the stack is yours to share." into tProblems
   end if
   if tProblems is not empty then
      put line 1 of tProblems into field "problem" of me
      exit ssPack
   end if
   put empty into field "problem" of me
   revShareStackPack sStack, sInfo, sFolder, sPicture
   put the result into tResult
   if tResult begins with "error:" then
      put word 2 to -1 of tResult into field "problem" of me
      exit ssPack
   end if
   ssRemember "author", ssClean(sInfo["author"])
   ssRemember "licence", sInfo["licence"]
   put tResult into sResult
   close me
end ssPack
