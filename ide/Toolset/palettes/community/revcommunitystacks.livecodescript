script "revCommunityStacks"
-- OXT-Beyond: File > Community Stacks..., the gallery of stacks that
-- people share (github.com/oxt-stacks/oxt-community-stacks), in the IDE.
--
-- The gallery is a web site, where every stack plays in a box that keeps
-- it away from the visitor's computer. This window lists the same stacks:
-- a sidebar with a search box and a line a stack, and a page for the
-- stack in front, with what it does, who made it and what its scripts
-- reach for. Play in Browser and Read Its Scripts open the gallery's own
-- pages. Get a Copy brings the stack's files to this computer, for
-- reading and for learning from.
--
-- A switch above the list shows the gallery's script libraries in place of
-- its stacks: a library has a page of what it gives a stack and what it
-- reaches for, Try the Demo and Read Its Script open the gallery's pages
-- for it, and Install installs it ("Libraries" below).
--
-- What it believes, and why:
--
--  * The list of stacks (index.json) is believed only when its signature
--    (index.sig) is good for the gallery's public key, kPublicKey below,
--    the line in signing-key.pub of the gallery's repository. The
--    signature is an Ed25519 one over the bytes of the list, checked by
--    SodiumXT's sxSignVerifyDetached before anything of the list is read.
--    A list with no signature, with a bad one, or one that cannot be
--    checked (no SodiumXT) is not shown: the window says why and offers
--    the gallery in the browser, where nothing needs believing.
--  * The signed list carries the SHA-256 and the size of every download
--    and of every file in it. A download that is not the listed bytes is
--    thrown away; a file in it that is not the listed bytes is not
--    written; a file the list does not name is never written at all.
--  * Every word of the list is still held to the gallery's own rules
--    before it is used (csCleanEntry): a name, a version, a path that is
--    not what the gallery's tools would write leaves that stack out. No
--    address is ever taken from the list: the window opens the gallery's
--    site and a path under it, and nothing else.
--
-- What it does not do: it is no sandbox. A copy that the user opens is a
-- stack like any other, and its scripts run as theirs do. So Get a Copy
-- says that first, opens the copy with the pointer tool and without
-- running its opening scripts (revCommunityStacksOpenToRead), and points
-- at the browser as the place to try a stack. revIDECommunityStacksGetCopy
-- in the IDE library asks and tells; this script only does.
--
-- It sends nothing but requests for the gallery's files, with no word
-- about the user or this computer in them.
--
-- It is drawn by revLearnKit, which is its behavior, as the Release
-- Notes window is. It is a script-only stack, so it keeps no controls:
-- this script builds them when it opens. Its name begins with "rev", so
-- the IDE treats it as one of its own windows.
--
-- tests/lcs/communitystacks runs the checking, the list's rules and the
-- unpacking in the engine; tools/ci/tests/test_community_stacks.py holds
-- the key and the address to the gallery's; and the IDE tour's step
-- community-stacks runs the window.

constant kSite = "https://oxt-stacks.github.io/oxt-community-stacks/"
-- The public half of the gallery's signing key (base64 of 32 bytes): the
-- one line of signing-key.pub in the gallery's repository
constant kPublicKey = "1CV25/gGPnbu3x57BfSyI8DKKvfUVUpvxJFN7YMZ+NA="
-- The list's format this script reads
constant kFormat = 1

-- The gallery's limits (tools/scan.py and tools/listing.py there)
constant kMaxIndexBytes = 4194304
constant kMaxDownloadBytes = 52428800
constant kMaxFileBytes = 26214400
constant kMaxFiles = 200
constant kMaxDepth = 5
constant kMaxStacks = 5000
-- A list of libraries is held to the same; and a library, to this many
-- handlers (the gallery sets no number: this is far past any library)
constant kMaxLibraries = 5000
constant kMaxHandlers = 5000
constant kStackExtensions = "oxtstack,livecode,rev,livecodescript"
-- Give up on the site after this many milliseconds without a byte
constant kTimeoutMilliseconds = 20000
-- The folder in Documents that copies go into
constant kCopiesFolder = "OXT Community Stacks"

constant kWidth = 920
constant kHeight = 640
constant kSide = 264
constant kHeaderHeight = 96
constant kFootHeight = 66
constant kPad = 32
constant kIndexLine = 30

-- The stacks of the list, by number, in the list's order (by title), and
-- how many; how many the list had that were left out; and why there is
-- no list, when there is none ("problem", and "unsigned" when it only
-- lacks its signature)
local sStacks, sCount, sLeftOut, sProblem
-- "loading", "list" or "problem"
local sState
-- The stack in front (its number), the search, and the stack each line
-- of the index stands for
local sPage, sSearch, sIndexMap
-- The site and the key this window was opened on (empty: the gallery's)
local sSite, sKey
-- True while a request is waiting for the site
local sBusy
-- What the window lists: "stacks" or "libraries"; and what the other one
-- showed, by its name, to come back to: "list" (sStacks), "count",
-- "leftOut", "problem", "state", "page" and "search"
local sMode, sKept

################################################################################
#
# The gallery's address and key
#

function revCommunityStacksSite
   return kSite
end revCommunityStacksSite

function revCommunityStacksPublicKey
   return kPublicKey
end revCommunityStacksPublicKey

################################################################################
#
# Believing the list
#

-- Empty when pSignature (the text of index.sig) is the gallery's
-- signature of the bytes pIndex; else a sentence that says why the list
-- is not believed. pPublicKey is the key to check with, the gallery's
-- when empty (a test checks with a key of its own).
function revCommunityStacksVerify pIndex, pSignature, pPublicKey
   local tKey, tSignature, tGood, tError
   if pPublicKey is empty then
      put kPublicKey into pPublicKey
   end if
   put csBase64(pPublicKey, 32) into tKey
   if tKey is empty then
      return "The key to check the gallery's list with is not a key."
   end if
   if pIndex is empty then
      return "The gallery's list is empty."
   end if
   put csBase64(word 1 to -1 of pSignature, 64) into tSignature
   if tSignature is empty then
      return "The gallery's list has a signature that is not one, so the list is not shown."
   end if
   put false into tGood
   try
      put sxSignVerifyDetached(tSignature, pIndex, tKey) into tGood
   catch tError
      return "This copy of OXT-Beyond cannot check the gallery's signature (its SodiumXT extension is not loaded), so the list is not shown."
   end try
   if tGood is not true then
      return "The gallery's list does not match its signature, so it is not shown."
   end if
   return empty
end revCommunityStacksVerify

-- The bytes of pText, base64 of exactly pBytes bytes; empty when it is
-- anything else
private function csBase64 pText, pBytes
   local tLength, tData, tError
   put ((pBytes + 2) div 3) * 4 into tLength
   if the number of chars of pText is not tLength then
      return empty
   end if
   if not matchText(pText, "\A[A-Za-z0-9+/]+={0,2}\z") then
      return empty
   end if
   try
      put base64Decode(pText) into tData
   catch tError
      return empty
   end try
   if the number of bytes of tData is not pBytes then
      return empty
   end if
   return tData
end csBase64

-- The SHA-256 of pData, as the list writes it: 64 hex digits
private function csSha256 pData
   local tHex
   get binaryDecode("H*", messageDigest(pData, "sha-256"), tHex)
   return toLower(tHex)
end csSha256

################################################################################
#
# Reading the list
#

-- The stacks of the list pIndex (the bytes of index.json, which the
-- caller has checked). Returns an array: "problem", a sentence, when the
-- list cannot be read at all; else "stacks", each stack by number as
-- csCleanEntry leaves it, "count", how many, and "leftOut", how many the
-- list had that broke the gallery's own rules and are not shown.
function revCommunityStacksParse pIndex
   local tOut, tData, tError, tRaw, tIndex, tEntry, tSeen, tTotal
   put 0 into tOut["count"]
   put 0 into tOut["leftOut"]
   if the number of bytes of pIndex > kMaxIndexBytes then
      put "The gallery's list is larger than a list of stacks should be." into tOut["problem"]
      return tOut
   end if
   try
      put JsonImport(textDecode(pIndex, "utf-8")) into tData
   catch tError
      put "The gallery's list could not be read." into tOut["problem"]
      return tOut
   end try
   if tData is not an array then
      put "The gallery's list could not be read." into tOut["problem"]
      return tOut
   end if
   if tData["format"] is not kFormat then
      put "The gallery's list is in a form that this copy of OXT-Beyond does not know. A newer OXT-Beyond may read it." into tOut["problem"]
      return tOut
   end if
   put tData["stacks"] into tRaw
   if tRaw is not an array then
      -- (a gallery with no stacks in it)
      return tOut
   end if
   put the number of elements of tRaw into tTotal
   if tTotal > kMaxStacks then
      put "The gallery's list is larger than a list of stacks should be." into tOut["problem"]
      return tOut
   end if
   repeat with tIndex = 1 to tTotal
      put csCleanEntry(tRaw[tIndex]) into tEntry
      if tEntry is not an array or tSeen[tEntry["slug"]] is true then
         add 1 to tOut["leftOut"]
         next repeat
      end if
      put true into tSeen[tEntry["slug"]]
      add 1 to tOut["count"]
      put tEntry into tOut["stacks"][tOut["count"]]
   end repeat
   return tOut
end revCommunityStacksParse

-- A stack of the list as this script uses it, or empty when anything of
-- it is not what the gallery's tools would have written: "slug",
-- "version", "title", "author", "description", "licence" (as shown),
-- "tags" and "uses" (a line each), "lines" (of script), "download",
-- "sha256", "size", "main", "files" (by number: "path", "sha256",
-- "size") and "fileCount"; and "page", "play" and "source", each a path
-- under the site or empty.
private function csCleanEntry pRaw
   local tEntry, tSlug, tVersion, tPrefix, tName, tValue, tLatest, tFiles, tIndex, tFile, tCount, tTotal, tHasMain, tSeen, tKey
   if pRaw is not an array then
      return empty
   end if
   set the caseSensitive to true

   put pRaw["slug"] into tSlug
   if not csIsText(tSlug) or the number of chars of tSlug < 3 or the number of chars of tSlug > 40 \
         or not matchText(tSlug, "\A[a-z0-9]+(-[a-z0-9]+)*\z") then
      return empty
   end if
   put pRaw["version"] into tVersion
   if not csIsVersion(tVersion) then
      return empty
   end if
   put tSlug into tEntry["slug"]
   put tVersion into tEntry["version"]

   put csWords(pRaw["title"], 2, 60) into tEntry["title"]
   put csWords(pRaw["author"], 2, 40) into tEntry["author"]
   put csWords(pRaw["description"], 10, 600) into tEntry["description"]
   if tEntry["title"] is empty or tEntry["author"] is empty or tEntry["description"] is empty then
      return empty
   end if
   put csLicence(pRaw["licence"]) into tEntry["licence"]
   if tEntry["licence"] is empty then
      return empty
   end if

   -- The words to find it by, and what its scripts reach for
   put empty into tEntry["tags"]
   if pRaw["tags"] is an array then
      repeat with tIndex = 1 to min(5, the number of elements of pRaw["tags"])
         put pRaw["tags"][tIndex] into tValue
         if csIsText(tValue) and the number of chars of tValue <= 20 \
               and matchText(tValue, "\A[a-z0-9]+([ -][a-z0-9]+)*\z") then
            put tValue & return after tEntry["tags"]
         end if
      end repeat
      delete the last char of tEntry["tags"]
   end if
   put empty into tEntry["uses"]
   if pRaw["uses"] is an array then
      repeat with tIndex = 1 to min(20, the number of elements of pRaw["uses"])
         put pRaw["uses"][tIndex] into tValue
         if not csIsText(tValue) or not matchText(tValue, "\A[a-z][a-z0-9-]{0,30}\z") then
            return empty
         end if
         put tValue & return after tEntry["uses"]
      end repeat
      delete the last char of tEntry["uses"]
   end if
   put empty into tEntry["lines"]
   if pRaw["script_lines"] is an integer and pRaw["script_lines"] >= 0 then
      put pRaw["script_lines"] into tEntry["lines"]
   end if

   -- The download: s/<slug>/<version>/<one name>.zip, its size and hash
   put "s/" & tSlug & "/" & tVersion & "/" into tPrefix
   put pRaw["download"] into tValue
   if not csIsText(tValue) or not (tValue begins with tPrefix) then
      return empty
   end if
   put char (the number of chars of tPrefix + 1) to -1 of tValue into tName
   if the number of chars of tName > 100 or not matchText(tName, "\A[A-Za-z0-9][A-Za-z0-9._-]*\.zip\z") then
      return empty
   end if
   put tValue into tEntry["download"]
   if not csIsHash(pRaw["sha256"]) then
      return empty
   end if
   put pRaw["sha256"] into tEntry["sha256"]
   if pRaw["size"] is not an integer or pRaw["size"] < 1 or pRaw["size"] > kMaxDownloadBytes then
      return empty
   end if
   put pRaw["size"] + 0 into tEntry["size"]

   -- The gallery's pages for it: under s/<slug>/, or not offered
   repeat for each item tKey in "page,play,source"
      put pRaw[tKey] into tValue
      if csIsText(tValue) and tValue begins with ("s/" & tSlug & "/") and the number of chars of tValue <= 200 \
            and matchText(tValue, "\A[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*\.html\z") then
         put tValue into tEntry[tKey]
      else
         put empty into tEntry[tKey]
      end if
   end repeat

   -- The files of the download: those of the newest version, which is
   -- the one the lines above are about
   if pRaw["versions"] is not an array or pRaw["versions"][1] is not an array then
      return empty
   end if
   put pRaw["versions"][1] into tLatest
   if tLatest["version"] is not tVersion or tLatest["sha256"] is not tEntry["sha256"] \
         or tLatest["download"] is not tEntry["download"] then
      return empty
   end if
   put tLatest["files"] into tFiles
   if tFiles is not an array then
      return empty
   end if
   put the number of elements of tFiles into tCount
   if tCount < 1 or tCount > kMaxFiles then
      return empty
   end if
   put pRaw["main"] into tEntry["main"]
   if not csIsText(tEntry["main"]) or tEntry["main"] contains "/" or not csIsStackFile(tEntry["main"]) then
      return empty
   end if
   put 0 into tTotal
   put false into tHasMain
   repeat with tIndex = 1 to tCount
      put tFiles[tIndex] into tFile
      if tFile is not an array or not csIsPath(tFile["path"]) or not csIsHash(tFile["sha256"]) \
            or tFile["size"] is not an integer or tFile["size"] < 0 or tFile["size"] > kMaxFileBytes then
         return empty
      end if
      -- (two names that differ only by case are one file on most disks)
      if tSeen[toLower(tFile["path"])] is true then
         return empty
      end if
      put true into tSeen[toLower(tFile["path"])]
      add tFile["size"] to tTotal
      if tFile["path"] is tEntry["main"] then
         put true into tHasMain
      end if
      put tFile["path"] into tEntry["files"][tIndex]["path"]
      put tFile["sha256"] into tEntry["files"][tIndex]["sha256"]
      put tFile["size"] + 0 into tEntry["files"][tIndex]["size"]
   end repeat
   if not tHasMain or tTotal > kMaxDownloadBytes then
      return empty
   end if
   put tCount into tEntry["fileCount"]
   return tEntry
end csCleanEntry

-- True for a value that is text and not an array
private function csIsText pValue
   return pValue is not an array and pValue is not empty
end csIsText

-- A line of the list for people to read: pText with every run of spaces,
-- tabs, returns and other control characters as one space, when it is
-- pMin to pMax characters; else empty
private function csWords pText, pMin, pMax
   local tOut, tChar, tCode, tSpace, tCount
   if not csIsText(pText) or the number of chars of pText > 4 * pMax then
      return empty
   end if
   put false into tSpace
   repeat for each char tChar in pText
      put codepointToNum(tChar) into tCode
      if tCode <= 32 or tCode is 127 or (tCode >= 128 and tCode <= 159) or tCode is 8232 or tCode is 8233 then
         put true into tSpace
         next repeat
      end if
      if tSpace and tOut is not empty then
         put space after tOut
      end if
      put false into tSpace
      put tChar after tOut
   end repeat
   put the number of chars of tOut into tCount
   if tCount < pMin or tCount > pMax then
      return empty
   end if
   return tOut
end csWords

-- A version as the gallery writes one: 1, 1.0, 2.3.1, 1.2.3.4
private function csIsVersion pVersion
   if not csIsText(pVersion) or the number of chars of pVersion > 20 then
      return false
   end if
   return matchText(pVersion, "\A[0-9]+(\.[0-9]+){0,3}\z")
end csIsVersion

private function csIsHash pHash
   if not csIsText(pHash) then
      return false
   end if
   set the caseSensitive to true
   return matchText(pHash, "\A[0-9a-f]{64}\z")
end csIsHash

-- The licences an author can choose in the gallery, as it shows them; a
-- licence it has added since is shown by its name
private function csLicence pLicence
   local tLine
   if not csIsText(pLicence) or not matchText(pLicence, "\A[A-Za-z0-9][A-Za-z0-9.+-]{0,39}\z") then
      return empty
   end if
   set the itemDelimiter to "|"
   repeat for each line tLine in csLicences()
      if item 1 of tLine is pLicence then
         return item 2 of tLine
      end if
   end repeat
   return pLicence
end csLicence

private function csLicences
   return "MIT|MIT" & return & \
         "Apache-2.0|Apache 2.0" & return & \
         "BSD-2-Clause|BSD 2-Clause" & return & \
         "BSD-3-Clause|BSD 3-Clause" & return & \
         "GPL-3.0-only|GPL 3" & return & \
         "GPL-3.0-or-later|GPL 3 or later" & return & \
         "GPL-2.0-or-later|GPL 2 or later" & return & \
         "LGPL-3.0-or-later|LGPL 3 or later" & return & \
         "MPL-2.0|MPL 2.0" & return & \
         "CC0-1.0|Public domain (CC0)" & return & \
         "CC-BY-4.0|CC BY 4.0" & return & \
         "CC-BY-SA-4.0|CC BY-SA 4.0" & return & \
         "Unlicense|Public domain (Unlicense)"
end csLicences

-- True for a file's path in a download as the gallery's checker allows
-- one: folders and a name, each beginning with a letter or a digit and
-- made of the characters it allows, none of them a name that Windows
-- keeps or that ends in a dot or a space. So never "..", never a path
-- from the root, never a drive, never a backslash.
private function csIsPath pPath
   local tPart, tBase
   if not csIsText(pPath) or the number of chars of pPath > 240 then
      return false
   end if
   set the itemDelimiter to "/"
   if the number of items of pPath > kMaxDepth or pPath ends with "/" then
      return false
   end if
   repeat for each item tPart in pPath
      if the number of chars of tPart > 100 or not matchText(tPart, "\A[A-Za-z0-9][A-Za-z0-9 ._()'&,+!-]*\z") then
         return false
      end if
      if tPart ends with "." or tPart ends with space then
         return false
      end if
      put tPart into tBase
      if tBase contains "." then
         put char 1 to (offset(".", tBase) - 1) of tBase into tBase
      end if
      if matchText(toUpper(tBase), "\A(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])\z") then
         return false
      end if
   end repeat
   return true
end csIsPath

-- True when pName ends as a stack's file does
private function csIsStackFile pName
   local tExtension
   set the itemDelimiter to "."
   if the number of items of pName < 2 then
      return false
   end if
   put toLower(the last item of pName) into tExtension
   set the itemDelimiter to comma
   return tExtension is among the items of kStackExtensions
end csIsStackFile

################################################################################
#
# Fetching
#

-- The site to fetch from: the gallery's when pSite is empty. A site is
-- an https address; a test gives a folder that holds the site's files.
-- Empty when pSite is neither.
private function csSite pSite
   if pSite is empty then
      return kSite
   end if
   if pSite begins with "https://" then
      if not (pSite ends with "/") then
         put "/" after pSite
      end if
      return pSite
   end if
   if not (pSite contains "://") and there is a folder pSite then
      if pSite ends with "/" then
         delete the last char of pSite
      end if
      return pSite & "/"
   end if
   return empty
end csSite

-- Fetches the file pPath of the site pSite (as csSite gives it) into
-- rData, at most pMaxBytes of it. Returns empty; "missing" when the site
-- has no such file; or a sentence that says why there is nothing.
private function csFetch pSite, pPath, pMaxBytes, @rData
   local tFile, tResult
   put empty into rData
   if pSite is empty then
      return "The gallery's address must begin with https://."
   end if
   if pSite begins with "https://" then
      revCommunityStacksHttpGet pSite & pPath, pMaxBytes
      put the result into tResult
      if tResult is an array then
         put tResult["data"] into rData
         return empty
      end if
      return tResult
   end if
   put pSite & pPath into tFile
   if there is no file tFile then
      return "missing"
   end if
   put url ("binfile:" & tFile) into rData
   if the result is not empty then
      put empty into rData
      return "The gallery's file could not be read."
   end if
   if the number of bytes of rData > pMaxBytes then
      put empty into rData
      return "The gallery sent more than it should have."
   end if
   return empty
end csFetch

-- Gets pUrl, at most pMaxBytes of it. The result is an array with the
-- bytes as "data"; or "missing" when the server has no such page; or a
-- sentence that says why there is no answer. It waits (with messages)
-- while bytes keep coming, and gives up kTimeoutMilliseconds after the
-- last one, so a server that stops answering cannot hold the IDE.
-- (A command of its own so that it can be run against any address when
-- it is tested; csSite decides which addresses the gallery is read from.)
command revCommunityStacksHttpGet pUrl, pMaxBytes
   local tOldHeaders, tOldTimeout, tStatus, tLast, tDeadline, tProblem, tData, tOut, tError
   put the httpHeaders into tOldHeaders
   put the socketTimeoutInterval into tOldTimeout
   set the httpHeaders to "User-Agent: OXT-Beyond" & return & "Connection: close"
   set the socketTimeoutInterval to kTimeoutMilliseconds
   put empty into tProblem
   try
      -- (never an answer kept from an earlier request)
      try
         unload url pUrl
      catch tError
      end try
      load url pUrl
      put the milliseconds + 2 * kTimeoutMilliseconds into tDeadline
      repeat
         put urlStatus(pUrl) into tStatus
         if item 1 of tStatus is among the items of "cached,error,timeout" then
            exit repeat
         end if
         if item 1 of tStatus is "loading" and item 2 of tStatus is a number and item 2 of tStatus > pMaxBytes then
            put "The gallery sent more than it should have." into tProblem
            exit repeat
         end if
         if tStatus is not tLast then
            put tStatus into tLast
            put the milliseconds + 2 * kTimeoutMilliseconds into tDeadline
         end if
         if the milliseconds > tDeadline then
            put "The gallery did not answer in time." into tProblem
            exit repeat
         end if
         wait 40 milliseconds with messages
      end repeat
      if tProblem is empty then
         switch item 1 of urlStatus(pUrl)
            case "cached"
               put url pUrl into tData
               break
            case "timeout"
               put "The gallery did not answer in time." into tProblem
               break
            default
               put libUrlErrorData(pUrl) into tProblem
               if word 1 of tProblem is "error" and word 2 of tProblem is "404" then
                  put "missing" into tProblem
               else if word 1 of tProblem is "error" and word 2 of tProblem is an integer then
                  put "The gallery's site answered with an error (" & word 2 of tProblem & ")." into tProblem
               else
                  put "The gallery could not be reached. Check the internet connection." into tProblem
               end if
         end switch
      end if
   catch tError
      put "The gallery could not be reached. Check the internet connection." into tProblem
   end try
   try
      unload url pUrl
   catch tError
   end try
   set the httpHeaders to tOldHeaders
   set the socketTimeoutInterval to tOldTimeout
   if tProblem is not empty then
      return tProblem
   end if
   if the number of bytes of tData > pMaxBytes then
      return "The gallery sent more than it should have."
   end if
   put tData into tOut["data"]
   return tOut
end revCommunityStacksHttpGet

-- The gallery's list, fetched, checked and read. Returns an array:
-- "stacks", "count" and "leftOut" as revCommunityStacksParse gives them;
-- or "problem", a sentence that says why there is no list, with
-- "unsigned" true when the list is there and only its signature is not.
-- pSite is the gallery's site when empty, and pPublicKey its key.
function revCommunityStacksLoad pSite, pPublicKey
   local tOut, tSite, tIndex, tSignature, tProblem
   put csSite(pSite) into tSite
   put csFetch(tSite, "index.json", kMaxIndexBytes, tIndex) into tProblem
   if tProblem is "missing" then
      put "The gallery has no list of stacks at its address." into tProblem
   end if
   if tProblem is not empty then
      put tProblem into tOut["problem"]
      return tOut
   end if
   put csFetch(tSite, "index.sig", 1024, tSignature) into tProblem
   if tProblem is "missing" then
      put true into tOut["unsigned"]
      put "The gallery's list is not signed yet, so this window cannot be sure it is the gallery's and does not show it." into tOut["problem"]
      return tOut
   end if
   if tProblem is not empty then
      put tProblem into tOut["problem"]
      return tOut
   end if
   put revCommunityStacksVerify(tIndex, tSignature, pPublicKey) into tProblem
   if tProblem is not empty then
      put tProblem into tOut["problem"]
      return tOut
   end if
   return revCommunityStacksParse(tIndex)
end revCommunityStacksLoad

################################################################################
#
# Libraries
#
-- The gallery also lists script libraries (libraries.json, signed as
-- index.json is, by the same key, in libraries.sig). A library is one
-- script-only stack that gives the user's own stacks new commands and
-- functions. It is not played: it is installed, as the Extension Manager
-- installs any extension, and it then runs as the user's own scripts do,
-- with no box around it. So the window shows what it holds (its handlers,
-- and the engine's messages it listens for) before anything is fetched,
-- and Install asks first (revIDECommunityLibraryInstall in the IDE
-- library).
--
-- The list is held to the gallery's rules as the stacks' list is
-- (csCleanLibrary), and the package is believed only when it is the bytes
-- that list names, as a copy of a stack is. The gallery makes every
-- package itself, from the text its checker read (tools/build_site.py
-- there, scan.library_package): the author's own files are never the
-- package.

-- The libraries of the list pList (the bytes of libraries.json, which the
-- caller has checked), as revCommunityStacksParse gives the stacks of
-- index.json: "problem"; or "libraries" by number as csCleanLibrary leaves
-- each, "count" and "leftOut".
function revCommunityLibrariesParse pList
   local tOut, tData, tError, tRaw, tIndex, tEntry, tSeen, tTotal
   put 0 into tOut["count"]
   put 0 into tOut["leftOut"]
   if the number of bytes of pList > kMaxIndexBytes then
      put "The gallery's list is larger than a list of libraries should be." into tOut["problem"]
      return tOut
   end if
   try
      put JsonImport(textDecode(pList, "utf-8")) into tData
   catch tError
      put "The gallery's list could not be read." into tOut["problem"]
      return tOut
   end try
   if tData is not an array then
      put "The gallery's list could not be read." into tOut["problem"]
      return tOut
   end if
   if tData["format"] is not kFormat then
      put "The gallery's list is in a form that this copy of OXT-Beyond does not know. A newer OXT-Beyond may read it." into tOut["problem"]
      return tOut
   end if
   put tData["libraries"] into tRaw
   if tRaw is not an array then
      return tOut
   end if
   put the number of elements of tRaw into tTotal
   if tTotal > kMaxLibraries then
      put "The gallery's list is larger than a list of libraries should be." into tOut["problem"]
      return tOut
   end if
   repeat with tIndex = 1 to tTotal
      put csCleanLibrary(tRaw[tIndex]) into tEntry
      -- (two libraries of one name could not both be installed)
      if tEntry is not an array or tSeen[tEntry["slug"]] is true or tSeen[":" & toLower(tEntry["name"])] is true then
         add 1 to tOut["leftOut"]
         next repeat
      end if
      put true into tSeen[tEntry["slug"]]
      put true into tSeen[":" & toLower(tEntry["name"])]
      add 1 to tOut["count"]
      put tEntry into tOut["libraries"][tOut["count"]]
   end repeat
   return tOut
end revCommunityLibrariesParse

-- A library of the list as this script uses it, or empty when anything
-- of it is not what the gallery's tools would have written. As a stack
-- of csCleanEntry ("slug", "version", "title", "author", "description",
-- "licence", "tags", "uses", "lines", "download", "sha256", "size",
-- "main", "files", "fileCount", "page", "source"), and "kind" "library";
-- "name", the name of its stack, which is the extension's name;
-- "handlers", a line each: command or function, a tab and its first
-- line; "messages", the engine's messages it handles, a line each;
-- "demo", the gallery's stack that shows it, and "play", the page that
-- plays that stack; and "find", the words its handlers add to a search.
private function csCleanLibrary pRaw
   local tEntry, tSlug, tVersion, tValue, tLatest, tFiles, tIndex, tFile, tCount, tTotal, tHasMain, tHasManifest, tSeen, tKey, tName, tKind, tText
   if pRaw is not an array then
      return empty
   end if
   set the caseSensitive to true

   put pRaw["slug"] into tSlug
   if not csIsText(tSlug) or the number of chars of tSlug < 3 or the number of chars of tSlug > 40 \
         or not matchText(tSlug, "\A[a-z0-9]+(-[a-z0-9]+)*\z") then
      return empty
   end if
   put pRaw["version"] into tVersion
   if not csIsVersion(tVersion) then
      return empty
   end if
   put "library" into tEntry["kind"]
   put tSlug into tEntry["slug"]
   put tVersion into tEntry["version"]
   put csWords(pRaw["title"], 2, 60) into tEntry["title"]
   put csWords(pRaw["author"], 2, 40) into tEntry["author"]
   put csWords(pRaw["description"], 10, 600) into tEntry["description"]
   if tEntry["title"] is empty or tEntry["author"] is empty or tEntry["description"] is empty then
      return empty
   end if
   -- (a library is built into other people's programs: only a licence
   -- that OXT-Beyond's GPL can take in)
   put csLibraryLicence(pRaw["licence"]) into tEntry["licence"]
   if tEntry["licence"] is empty then
      return empty
   end if

   put empty into tEntry["tags"]
   if pRaw["tags"] is an array then
      repeat with tIndex = 1 to min(5, the number of elements of pRaw["tags"])
         put pRaw["tags"][tIndex] into tValue
         if csIsText(tValue) and the number of chars of tValue <= 20 \
               and matchText(tValue, "\A[a-z0-9]+([ -][a-z0-9]+)*\z") then
            put tValue & return after tEntry["tags"]
         end if
      end repeat
      delete the last char of tEntry["tags"]
   end if
   put empty into tEntry["uses"]
   if pRaw["uses"] is an array then
      repeat with tIndex = 1 to min(20, the number of elements of pRaw["uses"])
         put pRaw["uses"][tIndex] into tValue
         if not csIsText(tValue) or not matchText(tValue, "\A[a-z][a-z0-9-]{0,30}\z") then
            return empty
         end if
         put tValue & return after tEntry["uses"]
      end repeat
      delete the last char of tEntry["uses"]
   end if
   -- (what the checker noted: script built as it runs, say)
   put empty into tEntry["notes"]
   if pRaw["notes"] is an array then
      repeat with tIndex = 1 to min(40, the number of elements of pRaw["notes"])
         put pRaw["notes"][tIndex] into tValue
         if csIsText(tValue) and matchText(tValue, "\A[a-z][a-z0-9-]{0,30}\z") then
            put tValue & return after tEntry["notes"]
         end if
      end repeat
      delete the last char of tEntry["notes"]
   end if
   put empty into tEntry["lines"]
   if pRaw["script_lines"] is an integer and pRaw["script_lines"] >= 0 then
      put pRaw["script_lines"] into tEntry["lines"]
   end if

   -- The name it is installed by: one the IDE does not keep for itself
   put pRaw["name"] into tName
   if not csIsLibraryName(tName) then
      return empty
   end if
   put tName into tEntry["name"]

   -- What it holds: the handlers other stacks can call, and the engine's
   -- messages it handles for every stack once it is installed
   -- (an empty list is read as empty, not as an array)
   if (pRaw["handlers"] is not an array and pRaw["handlers"] is not empty) \
         or the number of elements of pRaw["handlers"] > kMaxHandlers then
      return empty
   end if
   put empty into tEntry["handlers"]
   put empty into tEntry["find"]
   repeat with tIndex = 1 to the number of elements of pRaw["handlers"]
      put pRaw["handlers"][tIndex] into tValue
      if tValue is not an array then
         return empty
      end if
      put tValue["kind"] into tKind
      if tKind is not among the items of "command,function,getprop,setprop" \
            or not csIsHandlerName(tValue["name"]) then
         return empty
      end if
      put csWords(tValue["text"], 1, 300) into tText
      if tText is empty then
         put tKind && tValue["name"] into tText
      end if
      put tKind & tab & tText & return after tEntry["handlers"]
      put tValue["name"] & space after tEntry["find"]
   end repeat
   delete the last char of tEntry["handlers"]
   put tName && tEntry["find"] into tEntry["find"]
   put empty into tEntry["messages"]
   if pRaw["messages"] is not an array and pRaw["messages"] is not empty then
      return empty
   end if
   if pRaw["messages"] is an array then
      repeat with tIndex = 1 to min(200, the number of elements of pRaw["messages"])
         put pRaw["messages"][tIndex] into tValue
         if not csIsHandlerName(tValue) then
            return empty
         end if
         put tValue & return after tEntry["messages"]
      end repeat
      delete the last char of tEntry["messages"]
   end if

   -- The package: exactly l/<slug>/<version>/<slug>-<version>.lce, the
   -- name the gallery's builder gives it, its size and hash
   put pRaw["download"] into tValue
   if tValue is not ("l/" & tSlug & "/" & tVersion & "/" & tSlug & "-" & tVersion & ".lce") then
      return empty
   end if
   put tValue into tEntry["download"]
   if not csIsHash(pRaw["sha256"]) then
      return empty
   end if
   put pRaw["sha256"] into tEntry["sha256"]
   if pRaw["size"] is not an integer or pRaw["size"] < 1 or pRaw["size"] > kMaxDownloadBytes then
      return empty
   end if
   put pRaw["size"] + 0 into tEntry["size"]

   -- The gallery's pages for it: under l/<slug>/, or not offered; and its
   -- demo, a stack of the gallery, played on that stack's own page
   repeat for each item tKey in "page,source"
      put pRaw[tKey] into tValue
      if csIsText(tValue) and tValue begins with ("l/" & tSlug & "/") and the number of chars of tValue <= 200 \
            and matchText(tValue, "\A[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*\.html\z") then
         put tValue into tEntry[tKey]
      else
         put empty into tEntry[tKey]
      end if
   end repeat
   put empty into tEntry["demo"]
   put empty into tEntry["play"]
   put pRaw["demo"] into tValue
   if csIsText(tValue) and the number of chars of tValue >= 3 and the number of chars of tValue <= 40 \
         and matchText(tValue, "\A[a-z0-9]+(-[a-z0-9]+)*\z") then
      put tValue into tEntry["demo"]
      put "s/" & tValue & "/play.html" into tEntry["play"]
   end if

   -- The files of the package, those of the newest version
   if pRaw["versions"] is not an array or pRaw["versions"][1] is not an array then
      return empty
   end if
   put pRaw["versions"][1] into tLatest
   if tLatest["version"] is not tVersion or tLatest["sha256"] is not tEntry["sha256"] \
         or tLatest["download"] is not tEntry["download"] or tLatest["name"] is not tName then
      return empty
   end if
   put tLatest["files"] into tFiles
   if tFiles is not an array then
      return empty
   end if
   put the number of elements of tFiles into tCount
   if tCount < 2 or tCount > kMaxFiles then
      return empty
   end if
   put pRaw["main"] into tEntry["main"]
   if not csIsText(tEntry["main"]) or tEntry["main"] contains "/" or not (tEntry["main"] ends with ".livecodescript") then
      return empty
   end if
   put 0 into tTotal
   put false into tHasMain
   put false into tHasManifest
   repeat with tIndex = 1 to tCount
      put tFiles[tIndex] into tFile
      if tFile is not an array or not csIsPath(tFile["path"]) or not csIsHash(tFile["sha256"]) \
            or tFile["size"] is not an integer or tFile["size"] < 0 or tFile["size"] > kMaxFileBytes then
         return empty
      end if
      if tSeen[toLower(tFile["path"])] is true then
         return empty
      end if
      put true into tSeen[toLower(tFile["path"])]
      add tFile["size"] to tTotal
      if tFile["path"] is tEntry["main"] then
         put true into tHasMain
      end if
      if tFile["path"] is "manifest.xml" then
         put true into tHasManifest
      end if
      put tFile["path"] into tEntry["files"][tIndex]["path"]
      put tFile["sha256"] into tEntry["files"][tIndex]["sha256"]
      put tFile["size"] + 0 into tEntry["files"][tIndex]["size"]
   end repeat
   -- (the Extension Manager reads manifest.xml first)
   if not tHasMain or not tHasManifest or tEntry["files"][1]["path"] is not "manifest.xml" or tTotal > kMaxDownloadBytes then
      return empty
   end if
   put tCount into tEntry["fileCount"]
   return tEntry
end csCleanLibrary

-- A name a library may have: what the gallery's checker allows
-- (library_name_problem in tools/scan.py there), and never one that the
-- IDE, the engine or the xTalk Suite keeps for its own
private function csIsLibraryName pName
   if not csIsText(pName) or the number of chars of pName < 3 or the number of chars of pName > 60 \
         or not matchText(pName, "\A[A-Za-z][A-Za-z0-9]*([._-][A-Za-z0-9]+)*\z") then
      return false
   end if
   if csIsIDEName(pName) or toLower(pName) begins with "community.openxtalk." \
         or toLower(pName) is among the items of "home,ide,livecode,oxt,openxtalk,help,library,stack" then
      return false
   end if
   return true
end csIsLibraryName

-- A handler's or a message's name, as the engine takes one
private function csIsHandlerName pName
   return csIsText(pName) and the number of chars of pName <= 80 and matchText(pName, "\A[A-Za-z_][A-Za-z0-9_.]*\z")
end csIsHandlerName

-- The licences an author can choose for a library, as the gallery shows
-- them (LIBRARY_LICENCES in tools/listing.py there): GPL 3, and the ones
-- a program under GPL 3 can take in. Empty for any other.
private function csLibraryLicence pLicence
   local tLine
   if not csIsText(pLicence) then
      return empty
   end if
   set the caseSensitive to true
   set the itemDelimiter to "|"
   repeat for each line tLine in csLibraryLicences()
      if item 1 of tLine is pLicence then
         return item 2 of tLine
      end if
   end repeat
   return empty
end csLibraryLicence

private function csLibraryLicences
   return "GPL-3.0-only|GPL 3" & return & \
         "GPL-3.0-or-later|GPL 3 or later" & return & \
         "LGPL-3.0-only|LGPL 3" & return & \
         "LGPL-3.0-or-later|LGPL 3 or later" & return & \
         "Apache-2.0|Apache 2.0" & return & \
         "MIT|MIT" & return & \
         "BSD-2-Clause|BSD (2 clauses)" & return & \
         "BSD-3-Clause|BSD (3 clauses)"
end csLibraryLicences

-- The gallery's list of libraries, fetched, checked and read, as
-- revCommunityStacksLoad does the stacks': "libraries", "count" and
-- "leftOut"; or "problem" (and "unsigned"). A gallery that has no list of
-- libraries yet has none: count 0 and no problem.
function revCommunityLibrariesLoad pSite, pPublicKey
   local tOut, tSite, tList, tSignature, tProblem
   put csSite(pSite) into tSite
   put csFetch(tSite, "libraries.json", kMaxIndexBytes, tList) into tProblem
   if tProblem is "missing" then
      put 0 into tOut["count"]
      put 0 into tOut["leftOut"]
      return tOut
   end if
   if tProblem is not empty then
      put tProblem into tOut["problem"]
      return tOut
   end if
   put csFetch(tSite, "libraries.sig", 1024, tSignature) into tProblem
   if tProblem is "missing" then
      put true into tOut["unsigned"]
      put "The gallery's list of libraries is not signed yet, so this window cannot be sure it is the gallery's and does not show it." into tOut["problem"]
      return tOut
   end if
   if tProblem is not empty then
      put tProblem into tOut["problem"]
      return tOut
   end if
   put revCommunityStacksVerify(tList, tSignature, pPublicKey) into tProblem
   if tProblem is not empty then
      put tProblem into tOut["problem"]
      return tOut
   end if
   return revCommunityLibrariesParse(tList)
end revCommunityLibrariesLoad

-- Fetches the package of the library pEntry (as the list gives it) from
-- the site pSite (the gallery's when empty) into the folder pFolder (a
-- folder of the temporary folder when empty), checked: the package must
-- be the bytes the list names, every file the list names must be in it as
-- the list names it, and its manifest must name the library the list
-- does. Returns in the result the package's path, ready for
-- revIDEExtensionInstall, or "error: " and a sentence. Nothing is
-- installed here.
command revCommunityLibrariesGet pEntry, pFolder, pSite
   local tSite, tPackage, tProblem, tTemp, tIndex, tPath, tData, tFile, tError
   if pEntry is not an array or pEntry["kind"] is not "library" or pEntry["download"] is empty \
         or pEntry["fileCount"] is not an integer then
      return "error: That is not a library of the gallery."
   end if
   put csSite(pSite) into tSite
   put csFetch(tSite, pEntry["download"], pEntry["size"], tPackage) into tProblem
   if tProblem is "missing" then
      put "The gallery does not have this library's package any more. Its list may have changed: close this window and open it again." into tProblem
   end if
   if tProblem is not empty then
      return "error:" && tProblem
   end if
   if the number of bytes of tPackage is not pEntry["size"] or csSha256(tPackage) is not pEntry["sha256"] then
      return "error: The download is not the package the gallery lists, so it was thrown away. Nothing was installed."
   end if

   if pFolder is empty then
      put specialFolderPath("temporary") & "/OXT Community Libraries" into pFolder
   end if
   if pFolder ends with "/" then
      delete the last char of pFolder
   end if
   csMakeFolder pFolder
   if there is no folder pFolder then
      return "error: The folder for the download could not be made."
   end if
   -- (the Extension Manager takes a package by its file, which must end
   -- in .lce)
   put pFolder & "/" & pEntry["slug"] & "-" & pEntry["version"] & ".lce" into tFile
   put tPackage into url ("binfile:" & tFile)
   if the result is not empty then
      return "error: The download could not be kept."
   end if

   -- Every file the list names, as it names it
   put empty into tProblem
   put tFile into tTemp
   try
      revZipOpenArchive tTemp, "read"
      if the result begins with "ziperr" then
         put "The download could not be unpacked." into tProblem
      else
         repeat with tIndex = 1 to pEntry["fileCount"]
            put pEntry["files"][tIndex]["path"] into tPath
            put empty into tData
            revZipExtractItemToVariable tTemp, tPath, "tData"
            if the result begins with "ziperr" then
               put "The download does not hold the file" && tPath & "." into tProblem
               exit repeat
            end if
            if the number of bytes of tData is not pEntry["files"][tIndex]["size"] \
                  or csSha256(tData) is not pEntry["files"][tIndex]["sha256"] then
               put "The file" && tPath && "in the download is not the one the gallery lists." into tProblem
               exit repeat
            end if
            if tPath is "manifest.xml" and not (textDecode(tData, "utf-8") contains ("<name>" & pEntry["name"] & "</name>")) then
               put "The package names another library than the gallery's list does." into tProblem
               exit repeat
            end if
         end repeat
         revZipCloseArchive tTemp
      end if
   catch tError
      put "The download could not be unpacked." into tProblem
      try
         revZipCloseArchive tTemp
      catch tError
      end try
   end try
   if tProblem is not empty then
      delete file tFile
      return "error:" && tProblem && "Nothing was installed."
   end if
   return tFile
end revCommunityLibrariesGet

################################################################################
#
# Getting a copy
#

-- Brings the files of the stack pEntry (a stack as the list gives it) to
-- a folder of their own in pFolder (Documents/OXT Community Stacks when
-- empty), from the site pSite (the gallery's when empty). Returns in the
-- result the path of the stack's main file, or "error: " and a sentence.
--
-- The download must be the bytes the list names, and so must every file
-- taken out of it; nothing is written before all of it is checked, and
-- only the files the list names are written. A copy that is already
-- there, whole and unchanged, is used again. One that was changed is
-- left alone: the new copy gets a folder with a number.
command revCommunityStacksGet pEntry, pFolder, pSite
   local tSite, tZip, tProblem, tTemp, tIndex, tPath, tData, tFiles, tDest, tResult, tError
   if pEntry is not an array or pEntry["download"] is empty or pEntry["fileCount"] is not an integer then
      return "error: That is not a stack of the gallery."
   end if
   if pFolder is empty then
      put specialFolderPath("documents") & "/" & kCopiesFolder into pFolder
   end if
   put csDestination(pFolder, pEntry) into tDest
   if tDest["have"] is true then
      return tDest["folder"] & "/" & pEntry["main"]
   end if

   put csSite(pSite) into tSite
   put csFetch(tSite, pEntry["download"], pEntry["size"], tZip) into tProblem
   if tProblem is "missing" then
      put "The gallery does not have this stack's file any more. Its list may have changed: close this window and open it again." into tProblem
   end if
   if tProblem is not empty then
      return "error:" && tProblem
   end if
   if the number of bytes of tZip is not pEntry["size"] or csSha256(tZip) is not pEntry["sha256"] then
      return "error: The download is not the file the gallery lists, so it was thrown away. Nothing was kept."
   end if

   -- Out of the .zip, into memory, each file checked
   put the tempName & ".zip" into tTemp
   put tZip into url ("binfile:" & tTemp)
   if the result is not empty then
      return "error: The download could not be kept while it was unpacked."
   end if
   put empty into tProblem
   try
      revZipOpenArchive tTemp, "read"
      if the result begins with "ziperr" then
         put "The download could not be unpacked." into tProblem
      else
         repeat with tIndex = 1 to pEntry["fileCount"]
            put pEntry["files"][tIndex]["path"] into tPath
            put empty into tData
            revZipExtractItemToVariable tTemp, tPath, "tData"
            if the result begins with "ziperr" then
               put "The download does not hold the file" && tPath & "." into tProblem
               exit repeat
            end if
            if the number of bytes of tData is not pEntry["files"][tIndex]["size"] \
                  or csSha256(tData) is not pEntry["files"][tIndex]["sha256"] then
               put "The file" && tPath && "in the download is not the one the gallery lists, so nothing was kept." into tProblem
               exit repeat
            end if
            put tData into tFiles[tIndex]
         end repeat
         revZipCloseArchive tTemp
      end if
   catch tError
      put "The download could not be unpacked." into tProblem
      try
         revZipCloseArchive tTemp
      catch tError
      end try
   end try
   delete file tTemp
   if tProblem is not empty then
      return "error:" && tProblem
   end if

   -- And onto the disk
   put csWrite(tDest["folder"], pEntry, tFiles) into tProblem
   if tProblem is not empty then
      return "error:" && tProblem
   end if
   return tDest["folder"] & "/" & pEntry["main"]
end revCommunityStacksGet

-- Where the copy of pEntry goes in pFolder: "folder", and "have" true
-- when that folder holds the copy already, every file as the list names
-- it. <slug>-<version>, or with -2, -3... when a folder of that name is
-- there and is not such a copy (the user changed theirs, say).
private function csDestination pFolder, pEntry
   local tOut, tBase, tTry, tFolder
   if pFolder ends with "/" then
      delete the last char of pFolder
   end if
   put pFolder & "/" & pEntry["slug"] & "-" & pEntry["version"] into tBase
   repeat with tTry = 1 to 99
      if tTry is 1 then
         put tBase into tFolder
      else
         put tBase & "-" & tTry into tFolder
      end if
      put tFolder into tOut["folder"]
      if there is no folder tFolder and there is no file tFolder then
         put false into tOut["have"]
         return tOut
      end if
      if csIsCopy(tFolder, pEntry) then
         put true into tOut["have"]
         return tOut
      end if
   end repeat
   put false into tOut["have"]
   return tOut
end csDestination

-- True when pFolder holds every file of pEntry as the list names it
private function csIsCopy pFolder, pEntry
   local tIndex, tFile, tData
   repeat with tIndex = 1 to pEntry["fileCount"]
      put pFolder & "/" & pEntry["files"][tIndex]["path"] into tFile
      if there is no file tFile then
         return false
      end if
      put url ("binfile:" & tFile) into tData
      if the result is not empty or the number of bytes of tData is not pEntry["files"][tIndex]["size"] \
            or csSha256(tData) is not pEntry["files"][tIndex]["sha256"] then
         return false
      end if
   end repeat
   return true
end csIsCopy

-- Writes the files pFiles (by the number each has in pEntry) under
-- pFolder, which is made for them. Empty, or a sentence.
private function csWrite pFolder, pEntry, pFiles
   local tIndex, tPath, tPart, tAt
   if there is a folder pFolder or there is a file pFolder then
      return "There is something in the way of the copy's folder:" && pFolder
   end if
   csMakeFolder pFolder
   if there is no folder pFolder then
      return "The folder for the copy could not be made:" && pFolder
   end if
   set the itemDelimiter to "/"
   repeat with tIndex = 1 to pEntry["fileCount"]
      put pEntry["files"][tIndex]["path"] into tPath
      put pFolder into tAt
      repeat for each item tPart in (item 1 to -2 of tPath)
         put "/" & tPart after tAt
         if there is no folder tAt then
            create folder tAt
         end if
      end repeat
      put pFiles[tIndex] into url ("binfile:" & pFolder & "/" & tPath)
      if the result is not empty then
         return "A file of the copy could not be written:" && tPath
      end if
   end repeat
   return empty
end csWrite

-- Makes the folder pFolder and the folders it is in
private command csMakeFolder pFolder
   local tPart, tAt
   set the itemDelimiter to "/"
   put empty into tAt
   repeat for each item tPart in pFolder
      if tAt is empty and tPart is empty then
         -- (a path from the root)
         put "/" into tAt
         next repeat
      end if
      if tAt is empty or tAt is "/" then
         put tPart after tAt
      else
         put "/" & tPart after tAt
      end if
      if there is no folder tAt then
         create folder tAt
      end if
   end repeat
end csMakeFolder

-- Opens the stack file pFile for looking at: with the pointer tool, and
-- with messages locked while it opens, so that none of its opening
-- scripts run. Returns empty in the result, or "error: " and a sentence.
--
-- This runs nothing, and it promises nothing after: the stack is open in
-- the IDE as any stack is, and its scripts run once it is used. A stack
-- whose name is one the IDE keeps for its own windows is not opened: the
-- IDE would take it for a part of itself. Nor is one with a substack of
-- such a name.
--
-- A stack that draws what it shows when it opens (its openStack makes
-- its controls, or fills its cards) shows its cards bare when it is
-- opened this way: that is what not running it means. To see it run,
-- revCommunityStacksOpenToRun opens it (richmond62, openxtalk.org
-- p=26654: Puzzle Almanac, opened to look at, showed a bare card and its
-- sprites, and he could not play it in the IDE).
command revCommunityStacksOpenToRead pFile
   return csOpenCopy(pFile, false)
end revCommunityStacksOpenToRead

-- OXT-Beyond: opens the stack file pFile to run it, as File > Open opens
-- a stack: with the browse tool, and with its opening scripts running, as
-- the scripts of the user's own stacks run. Returns empty in the result,
-- or "error: " and a sentence. A stack the IDE would take for a part of
-- itself is not opened, as revCommunityStacksOpenToRead does not open it;
-- that is checked with messages locked, before any of it runs. An error
-- in the stack's own scripts as it opens is the stack's: the IDE shows it
-- as it shows any stack's (it is not caught here).
command revCommunityStacksOpenToRun pFile
   return csOpenCopy(pFile, true)
end revCommunityStacksOpenToRun

-- Opens the copy pFile: to run it when pRun is true, else to look at it
private function csOpenCopy pFile, pRun
   local tName, tResult, tError, tTaken, tKept, tSub, tGo
   if pFile is empty or there is no file pFile then
      return "error: The copy's file is not there:" && pFile
   end if
   try
      if pRun then
         revIDESetTool "browse"
      else
         revIDESetTool "pointer"
      end if
   catch tError
      if pRun then
         choose browse tool
      else
         choose pointer tool
      end if
   end try
   lock messages
   put empty into tResult
   put false into tGo
   try
      -- (naming the file loads the stack; nothing of it runs for that)
      put the short name of stack pFile into tName
      put the effective filename of stack tName is not pFile into tTaken
      if tTaken then
         put "A stack with the same name," && quote & tName & quote & ", is open already. Close it first." into tResult
      else
         if csIsIDEName(tName) then
            put tName into tKept
         else
            repeat for each line tSub in the substacks of stack tName
               if csIsIDEName(tSub) then
                  put tSub into tKept
                  exit repeat
               end if
            end repeat
         end if
      end if
      if tTaken then
         -- (said above)
      else if tKept is tName then
         delete stack tName
         put "This stack is named" && quote & tName & quote & ", a name the IDE keeps for its own windows, so it was not opened." into tResult
      else if tKept is not empty then
         delete stack tName
         put "This stack holds a stack named" && quote & tKept & quote & ", a name the IDE keeps for its own windows, so it was not opened." into tResult
      else if pRun then
         -- (opened below, with messages)
         put true into tGo
      else
         go stack pFile
         if the result is not empty then
            put "The copy could not be opened." into tResult
         end if
      end if
   catch tError
      put "The copy could not be opened." into tResult
   end try
   unlock messages
   if tGo then
      go stack pFile
      if the result is not empty then
         put "The copy could not be opened." into tResult
      end if
   end if
   if tResult is not empty then
      return "error:" && tResult
   end if
   return empty
end csOpenCopy

-- True for a stack name that the IDE takes for one of its own
private function csIsIDEName pName
   local tIs, tError
   put toLower(pName) into pName
   if pName begins with "rev" or pName begins with "com.livecode." or pName begins with "org.openxtalk." \
         or pName is among the items of "message box,answer dialog,ask dialog,home" then
      return true
   end if
   try
      put revIDEStackNameIsIDEStack(pName) into tIs
   catch tError
      put false into tIs
   end try
   return tIs is true
end csIsIDEName

################################################################################
#
# What the window says about a stack
#

-- What a stack reaches for, a line each: the words, a tab and what they
-- mean. The words are the gallery's (BADGES in tools/build_site.py).
function revCommunityStacksUsesWords pUses
   local tLine, tOut
   repeat for each line tLine in pUses
      switch tLine
         case "internet"
            put "Uses the internet" & tab & "It gets or sends information over the internet." & return after tOut
            break
         case "files"
            put "Opens or saves files" & tab & "It keeps things in files. In your browser these stay inside the page. A copy opened here uses real files on this computer." & return after tOut
            break
         case "javascript"
            put "Runs JavaScript" & tab & "It runs JavaScript in a page of its own, for example to make sound." & return after tOut
            break
         default
            put "Uses" && tLine & tab & "The gallery's checker marked it with this word." & return after tOut
      end switch
   end repeat
   delete the last char of tOut
   return tOut
end revCommunityStacksUsesWords

-- 37 KB, 1.5 MB
private function csSize pBytes
   if pBytes < 1048576 then
      return max(1, round(pBytes / 1024)) && "KB"
   end if
   return format("%.1f", pBytes / 1048576) && "MB"
end csSize

################################################################################
#
# Opening and closing the window
#

-- Opens the window, or brings it to the front. pSite and pPublicKey are
-- the gallery's when empty (the IDE tour opens it on a gallery of its
-- own, in a folder). pMode "libraries" opens it on the gallery's script
-- libraries; it lists the stacks otherwise.
command revCommunityStacksShow pSite, pPublicKey, pMode
   if pMode is not "libraries" then
      put "stacks" into pMode
   end if
   if the mode of me is 0 then
      put pSite into sSite
      put pPublicKey into sKey
      put empty into sPage
      put empty into sSearch
      put empty into sStacks
      put 0 into sCount
      put 0 into sLeftOut
      put empty into sProblem
      put "loading" into sState
      put false into sBusy
      put pMode into sMode
      put empty into sKept
      modeless me
   else
      go me
      csSwitch pMode
   end if
end revCommunityStacksShow

-- What the window lists: "stacks" or "libraries"
function revCommunityStacksMode
   return sMode
end revCommunityStacksMode

-- The stack in front, as the list gives it (empty when there is none),
-- and what the window is showing: "loading", "list" or "problem"
function revCommunityStacksShown
   if sState is "list" and sPage is an integer then
      return sStacks[sPage]
   end if
   return empty
end revCommunityStacksShown

function revCommunityStacksState
   return sState
end revCommunityStacksState

on preOpenStack
   local tSaved, tError
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   try
      csUseKit
      get lkReadAppearance()
      csBuild
      csSyncSwitch
      csPlace
      csRender
      -- (a script-only stack is made invisible when it is loaded)
      show me
   catch tError
      csRestore tSaved
      throw tError
   end try
   csRestore tSaved
end preOpenStack

private command csRestore pSaved
   if pSaved is not empty and there is a stack pSaved then
      set the defaultStack to pSaved
   end if
end csRestore

on openStack
   lkStartTicking
   lkEnter "side"
   lkFollowAppearance
   if sState is "loading" then
      send "csLoadList" to me in 60 milliseconds
   end if
end openStack

on closeStack
   lkStopTicking
end closeStack

-- The desktop switched between light and dark (revLearnKit): built again
-- in the other colours, showing what it showed
on lkAppearanceChanged
   local tIdxScroll
   if there is no field "page" of me then
      exit lkAppearanceChanged
   end if
   put the vScroll of field "idx" of me into tIdxScroll
   lock screen
   lkClear
   csBuild
   csSyncSwitch
   put sSearch into field "search" of me
   csFillIndex
   csRender
   set the vScroll of field "idx" of me to tIdxScroll
   lkScrollSync "idxThumb"
   lkEnter "side"
   unlock screen
end lkAppearanceChanged

-- Escape closes it
on rawKeyDown pKey
   if pKey is 65307 then
      close me
   else
      pass rawKeyDown
   end if
end rawKeyDown

-- The arrow keys go from one stack to the next (the search box keeps its
-- own; and so does a field in another window)
on arrowKey pKey
   if word 1 of the name of the target is "field" and the short name of the target is not "idx" then
      pass arrowKey
   end if
   switch pKey
      case "up"
      case "left"
         csStep -1
         break
      case "down"
      case "right"
         csStep 1
         break
      default
         pass arrowKey
   end switch
end arrowKey

-- The kit is this stack's behavior (see revLearnKit)
private command csUseKit
   local tKit
   if the behavior of me is not empty then
      exit csUseKit
   end if
   if there is no stack "revLearnKit" then
      put csToolset() & "/palettes/learn/revlearnkit.livecodescript" into tKit
      if there is no file tKit then
         throw "no revLearnKit"
      end if
      -- (naming the file loads the stack)
      get the short name of stack tKit
   end if
   set the behavior of me to the long id of stack "revLearnKit"
end csUseKit

-- The IDE's Toolset folder, from this stack's file
private function csToolset
   set the itemDelimiter to slash
   return item 1 to -4 of the filename of me
end csToolset

-- In the middle of the screen, a little above it
private command csPlace
   local tScreen
   put the screenRect into tScreen
   set the rect of me to 0, 0, kWidth, kHeight
   set the loc of me to (item 1 of tScreen + item 3 of tScreen) div 2, \
         max(item 2 of tScreen + kHeight div 2 + 30, (item 2 of tScreen + item 4 of tScreen) div 2 - 20)
end csPlace

################################################################################
#
# The list, from the site
#

-- Fetches the list and shows it, or why there is none
on csLoadList
   local tOut
   if sBusy is true or the mode of me is 0 then
      exit csLoadList
   end if
   put true into sBusy
   put "loading" into sState
   csRender
   if sMode is "libraries" then
      put revCommunityLibrariesLoad(sSite, sKey) into tOut
   else
      put revCommunityStacksLoad(sSite, sKey) into tOut
   end if
   put false into sBusy
   -- (the window may have been closed while the site was answering)
   if the mode of me is 0 then
      exit csLoadList
   end if
   csTakeList tOut
end csLoadList

-- Shows what revCommunityStacksLoad returned
private command csTakeList pOut
   local tSaved
   put empty into sStacks
   put 0 into sCount
   put 0 into sLeftOut
   put empty into sProblem
   if pOut["problem"] is not empty then
      put pOut into sProblem
      put "problem" into sState
   else
      if sMode is "libraries" then
         put pOut["libraries"] into sStacks
      else
         put pOut["stacks"] into sStacks
      end if
      put pOut["count"] into sCount
      put pOut["leftOut"] into sLeftOut
      put "list" into sState
      if sCount > 0 then
         put 1 into sPage
      else
         put empty into sPage
      end if
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   csFillIndex
   csRender
   unlock screen
   csRestore tSaved
end csTakeList

-- Lists the stacks (pMode "stacks") or the libraries ("libraries"). What
-- the other one showed is kept, and shown again when it is switched back
-- to; a list not asked for yet is asked for now.
private command csSwitch pMode
   local tSaved
   if pMode is not "libraries" then
      put "stacks" into pMode
   end if
   if pMode is sMode or sBusy is true or there is no field "page" of me then
      exit csSwitch
   end if
   put sStacks into sKept[sMode]["list"]
   put sCount into sKept[sMode]["count"]
   put sLeftOut into sKept[sMode]["leftOut"]
   put sProblem into sKept[sMode]["problem"]
   put sState into sKept[sMode]["state"]
   put sPage into sKept[sMode]["page"]
   put sSearch into sKept[sMode]["search"]
   put pMode into sMode
   if sKept[pMode]["state"] is among the items of "list,problem" then
      put sKept[pMode]["list"] into sStacks
      put sKept[pMode]["count"] into sCount
      put sKept[pMode]["leftOut"] into sLeftOut
      put sKept[pMode]["problem"] into sProblem
      put sKept[pMode]["state"] into sState
      put sKept[pMode]["page"] into sPage
      put sKept[pMode]["search"] into sSearch
   else
      put empty into sStacks
      put 0 into sCount
      put 0 into sLeftOut
      put empty into sProblem
      put "loading" into sState
      put empty into sPage
      put empty into sSearch
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   put sSearch into field "search"
   csSyncSwitch
   csFillIndex
   csRender
   set the vScroll of field "idx" to 0
   csSyncIndex
   unlock screen
   csRestore tSaved
   if sState is "loading" then
      send "csLoadList" to me in 20 milliseconds
   end if
end csSwitch

-- The switch shows which list is in front, and the search box says what
-- it searches
private command csSyncSwitch
   local tName, tOn
   repeat for each item tName in "modeStacks,modeLibraries"
      put (tName is "modeLibraries") is (sMode is "libraries") into tOn
      if tOn then
         lkSetLook tName, "bg0", lkMix(lkColor("side2"), lkColor("violet"), 0.45)
         lkSetLook tName, "bg1", lkMix(lkColor("side2"), lkColor("violet"), 0.55)
         lkSetLook tName, "ink0", "255,255,255"
      else
         lkSetLook tName, "bg0", lkColor("side2")
         lkSetLook tName, "bg1", lkColor("sideLine")
         lkSetLook tName, "ink0", lkColor("sideInk")
      end if
      lkApply tName
   end repeat
   put "Search the" && csNoun(2) into field "searchHint" of me
end csSyncSwitch

-- "stack" or "stacks", "library" or "libraries": what the window lists,
-- pCount of them
private function csNoun pCount
   if sMode is "libraries" then
      if pCount is 1 then
         return "library"
      end if
      return "libraries"
   end if
   if pCount is 1 then
      return "stack"
   end if
   return "stacks"
end csNoun

################################################################################
#
# Building the window
#

private command csBuild
   local tSaved, tObj
   if there is a field "page" of me then
      exit csBuild
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   set the label of me to "Community Stacks"
   set the resizable of me to false
   set the destroyStack of me to true
   set the rect of me to 0, 0, kWidth, kHeight
   set the backgroundColor of me to lkColor("bg")
   csBuildSide
   csBuildHeader

   -- The page
   put lkBox("pageBg", lkR(kSide + kPad - 8, kHeaderHeight + 4, kWidth - kPad + 8, kHeight - kFootHeight), \
         lkColor("panel"), 16, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel("page", lkR(kSide + kPad + 8, kHeaderHeight + 18, kWidth - kPad - 18, kHeight - kFootHeight - 12), \
         empty, 14, lkColor("soft"), empty) into tObj
   set the textHeight of tObj to 21
   set the vScrollbar of tObj to true
   set the rightMargin of tObj to 14
   -- (the last line of a long page comes wholly into view)
   lkPageEnd tObj
   if lkDark() then
      lkScroller "pageThumb", tObj, "148,163,184", 45, empty
   else
      lkScroller "pageThumb", tObj, "100,116,139", 45, empty
   end if
   lkScroller "idxThumb", the long id of field "idx", "255,255,255", 70, empty

   -- The foot: what to do with the stack in front, or about no list
   get lkButton("play", kSide + kPad - 8, kHeight - kFootHeight + 16, 34, "Play in Browser", "play", "primary", \
         lkColor("violet"), empty, "play", 0)
   get lkButton("scripts", the right of group "play" + 10, kHeight - kFootHeight + 16, 34, "Read Its Scripts", "book-open", "ghost", \
         lkColor("violet"), empty, "scripts", 0)
   get lkButton("copy", 0, kHeight - kFootHeight + 16, 34, "Get a Copy", "copy", "ghost", \
         lkColor("violet"), empty, "copy", 0)
   set the right of group "copy" to kWidth - kPad + 8
   lkRestAt "copy"
   get lkButton("again", kSide + kPad - 8, kHeight - kFootHeight + 16, 34, "Try Again", "rotate-cw", "primary", \
         lkColor("violet"), empty, "again", 0)
   -- (and what to do with a library in front)
   get lkButton("demo", kSide + kPad - 8, kHeight - kFootHeight + 16, 34, "Try the Demo", "play", "primary", \
         lkColor("violet"), empty, "demo", 0)
   get lkButton("script", the right of group "demo" + 10, kHeight - kFootHeight + 16, 34, "Read Its Script", "book-open", \
         "ghost", lkColor("violet"), empty, "script", 0)
   get lkButton("install", 0, kHeight - kFootHeight + 16, 34, "Install", "package", "ghost", \
         lkColor("violet"), empty, "install", 0)
   set the right of group "install" to kWidth - kPad + 8
   lkRestAt "install"
   unlock messages
   unlock screen
   csRestore tSaved
end csBuild

private command csBuildSide
   local tObj
   put lkBox("sideBg", lkR(0, 0, kSide, kHeight), lkColor("side"), 0, empty) into tObj
   lkGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", "0," & kHeight
   -- The mark
   put lkBox("sideMark", "20,22,56,58", lkColor("violet"), 22, empty) into tObj
   lkGradient tObj, "139,92,246|219,39,119", "20,22", "56,58"
   lkGlow tObj, "139,92,246", 16, 110
   get lkIcon("sideMarkIcon", "users", "255,255,255", "28,30,48,50", empty)
   get lkLabel("sideTitle", lkR(66, 21, kSide - 8, 45), "Community Stacks", 18, "255,255,255", empty)
   put lkLabel("sideSub", lkR(66, 45, kSide - 8, 61), "Made and shared by people like you", 11, lkColor("muted"), empty) into tObj
   -- One line, whole, whatever the system's font. With a wide one (DejaVu
   -- Sans, the only font of some Linux systems) these words need more than
   -- the label's width at size 11: they went on to a second line, and the
   -- label's bottom cut "you". There they are drawn a size smaller
   set the dontWrap of tObj to true
   repeat while the formattedWidth of tObj > the width of tObj and the textSize of tObj > 9
      set the textSize of tObj to the textSize of tObj - 1
   end repeat

   -- Search
   put lkBox("searchBg", lkR(14, 80, kSide - 14, 114), lkColor("side2"), 17, empty) into tObj
   lkBorder tObj, lkColor("sideLine")
   get lkIcon("searchIcon", "search", lkColor("muted"), "27,89,43,105", empty)
   get lkLabel("searchHint", lkR(52, 88, kSide - 44, 106), "Search the stacks", 13, "100,116,139", empty)
   set the dontWrap of field "searchHint" to true
   put lkInput("search", lkR(52, 88, kSide - 44, 106), empty, 13, empty) into tObj
   set the textColor of tObj to "255,255,255"
   set the hiliteColor of tObj to lkColor("sideLine")
   get lkGroup("searchClear", lkR(kSide - 42, 85, kSide - 18, 109), empty)
   get lkBox("searchClear_bg", lkR(kSide - 42, 85, kSide - 18, 109), lkColor("sideLine"), 12, "searchClear")
   get lkIcon("searchClear_icon", "x", lkColor("sideInk"), lkR(kSide - 37, 90, kSide - 23, 104), "searchClear")
   csLiveFade "searchClear", "clear"
   hide group "searchClear"

   -- Stacks or libraries
   get lkButton("modeStacks", 14, 124, 30, "Stacks", "layers", "dark", lkColor("violet"), empty, "mode-stacks", \
         (kSide - 36) div 2)
   get lkButton("modeLibraries", kSide - 14 - (kSide - 36) div 2, 124, 30, "Libraries", "library-big", "dark", \
         lkColor("violet"), empty, "mode-libraries", (kSide - 36) div 2)

   -- The index: a stack a line
   put lkLabel("idx", lkR(8, 164, kSide - 8, kHeight - 54), empty, 14, lkColor("sideInk"), empty) into tObj
   set the autoHilite of tObj to true
   lkSelectedInk tObj, "255,255,255"
   set the dontWrap of tObj to true
   -- (lines whose last one scrolls wholly into view; csFillIndex sets
   -- their names in the middle of them)
   lkListLines tObj, kIndexLine, 12
   set the threeDHilite of tObj to false
   set the hiliteColor of tObj to lkMix(lkColor("side2"), lkColor("violet"), 0.45)

   get lkLabel("navCount", lkR(0, kHeight - 42, kSide, kHeight - 26), empty, 12, lkColor("muted"), empty, "center")
end csBuildSide

-- A small thing that lights up by showing its box more
private command csLiveFade pName, pAction
   local tLook
   put pName & "_bg" into tLook["bg"]
   put 60 into tLook["blend0"]
   put 0 into tLook["blend1"]
   set the blendLevel of graphic (pName & "_bg") to 60
   lkLive pName, "side", pAction, tLook
end csLiveFade

private command csBuildHeader
   local tObj
   put lkLabel("hdrTitle", lkR(kSide + kPad, 16, kWidth - 210, 50), empty, 26, lkColor("ink"), empty) into tObj
   set the dontWrap of tObj to true
   put lkLabel("hdrTag", lkR(kSide + kPad, 52, kWidth - 210, 70), empty, 13, lkColor("soft"), empty) into tObj
   set the dontWrap of tObj to true
   put lkBox("hdrLine", lkR(kSide + kPad, 78, kSide + kPad + 56, 81), lkAccentInk(lkColor("violet")), 3, empty) into tObj
   get lkButton("site", 0, 24, 32, "Open the Gallery", "external-link", "ghost", lkColor("violet"), \
         empty, "site", 0)
   set the right of group "site" to kWidth - kPad + 8
   lkRestAt "site"
end csBuildHeader

################################################################################
#
# The sidebar
#

private command csSyncSearch
   if field "search" is empty then
      show field "searchHint"
      hide group "searchClear"
   else
      hide field "searchHint"
      show group "searchClear"
   end if
end csSyncSearch

-- True when the stack pIndex has every word of pTerm somewhere in its
-- title, its author, what it does or the words to find it by
private function csMatches pIndex, pTerm
   local tText, tWord
   put sStacks[pIndex]["title"] && sStacks[pIndex]["author"] && sStacks[pIndex]["description"] && \
         sStacks[pIndex]["tags"] && sStacks[pIndex]["find"] into tText
   repeat for each word tWord in pTerm
      if not (tText contains tWord) then
         return false
      end if
   end repeat
   return true
end csMatches

-- The index: every stack, or those the search finds
private command csFillIndex
   local tHtml, tCount, tIndex, tTerm
   put empty into sIndexMap
   put word 1 to -1 of sSearch into tTerm
   put 0 into tCount
   if sState is "list" then
      repeat with tIndex = 1 to sCount
         if tTerm is not empty and not csMatches(tIndex, tTerm) then
            next repeat
         end if
         add 1 to tCount
         put tIndex into sIndexMap[tCount]
         put "<p>" & lkEscape(sStacks[tIndex]["title"]) & "</p>" after tHtml
      end repeat
   end if
   lock screen
   set the htmlText of field "idx" to tHtml
   -- (each name in the middle of its line, and so of the hilite)
   lkListCentre the long id of field "idx"
   csSyncSearch
   if sState is "loading" then
      put empty into field "navCount"
   else if sState is "problem" then
      put "No list" into field "navCount"
   else if tTerm is not empty then
      if tCount is 0 then
         put "Nothing found" into field "navCount"
      else
         put tCount && csNoun(tCount) && "found" into field "navCount"
      end if
   else
      put sCount && csNoun(sCount) into field "navCount"
   end if
   unlock screen
   csSyncIndex
end csFillIndex

-- The index marks the stack in front, and scrolls to it
private command csSyncIndex
   local tLine, tTop
   put csIndexOf(sPage) into tLine
   if tLine is empty then
      set the hilitedLine of field "idx" to empty
   else
      set the hilitedLine of field "idx" to tLine
      put (tLine - 1) * kIndexLine into tTop
      if tTop < the vScroll of field "idx" or tTop + kIndexLine > the vScroll of field "idx" + the height of field "idx" - 8 then
         set the vScroll of field "idx" to max(0, tTop - (the height of field "idx" div 2) + kIndexLine)
      end if
   end if
   lkScrollSync "idxThumb"
end csSyncIndex

private function csIndexOf pPage
   local tKey
   if pPage is empty then
      return empty
   end if
   repeat for each key tKey in sIndexMap
      if sIndexMap[tKey] is pPage then
         return tKey
      end if
   end repeat
   return empty
end csIndexOf

on mouseUp pButton
   local tLine
   if word 1 of the name of the target is "field" and the short name of the target is "idx" then
      if pButton is 1 then
         put the hilitedLine of field "idx" of me into tLine
         if tLine is empty or sIndexMap[tLine] is empty then
            csSyncIndex
         else
            csGo sIndexMap[tLine]
         end if
      end if
      exit mouseUp
   end if
   pass mouseUp
end mouseUp

on textChanged
   if the short name of the target is "search" then
      put the text of field "search" of me into sSearch
      csFillIndex
      -- (the first stack found, when the one in front is not among them)
      if sState is "list" and csIndexOf(sPage) is empty and sIndexMap[1] is not empty then
         put sIndexMap[1] into sPage
         csSyncIndex
         csRender
      end if
   end if
   pass textChanged
end textChanged

on returnInField
   if the short name of the target is "search" then
      if sIndexMap[1] is not empty then
         csGo sIndexMap[1]
      end if
      exit returnInField
   end if
   pass returnInField
end returnInField

on enterInField
   if the short name of the target is "search" then
      returnInField
      exit enterInField
   end if
   pass enterInField
end enterInField

################################################################################
#
# What a click does
#

on lkAction pAction
   switch pAction
      case "clear"
         put empty into field "search" of me
         put empty into sSearch
         csFillIndex
         break
      case "site"
         if sMode is "libraries" then
            csLaunch "libraries.html"
         else
            csLaunch empty
         end if
         break
      case "mode-stacks"
         csSwitch "stacks"
         break
      case "mode-libraries"
         csSwitch "libraries"
         break
      case "demo"
         if sState is "list" and sPage is an integer then
            csLaunch sStacks[sPage]["play"]
         end if
         break
      case "script"
         if sState is "list" and sPage is an integer then
            csLaunch sStacks[sPage]["source"]
         end if
         break
      case "install"
         csInstall
         break
      case "again"
         csLoadList
         break
      case "play"
         if sState is "list" and sPage is an integer then
            csLaunch sStacks[sPage]["play"]
         end if
         break
      case "scripts"
         if sState is "list" and sPage is an integer then
            csLaunch sStacks[sPage]["source"]
         end if
         break
      case "copy"
         csGetCopy
         break
   end switch
end lkAction

-- Opens the gallery's site in the browser, or the page pPath of it (a
-- path of the list, which csCleanEntry held to the site's own). Nothing
-- but the site is ever opened: a window that was opened on a folder (a
-- test's gallery) opens nothing.
private command csLaunch pPath
   local tSite, tError
   put csSite(sSite) into tSite
   if not (tSite begins with "https://") then
      exit csLaunch
   end if
   try
      launch url (tSite & pPath)
   catch tError
   end try
end csLaunch

-- Get a Copy: the IDE asks, fetches and tells (revIDECommunityStacksGetCopy)
private command csGetCopy
   local tError
   if sState is not "list" or sPage is not an integer or sBusy is true then
      exit csGetCopy
   end if
   put true into sBusy
   try
      revIDECommunityStacksGetCopy sStacks[sPage], sSite
   catch tError
   end try
   put false into sBusy
end csGetCopy

-- Install: the IDE asks, fetches, installs and tells
-- (revIDECommunityLibraryInstall); the page then says it is installed
private command csInstall
   local tError
   if sMode is not "libraries" or sState is not "list" or sPage is not an integer or sBusy is true then
      exit csInstall
   end if
   put true into sBusy
   try
      revIDECommunityLibraryInstall sStacks[sPage], sSite
   catch tError
   end try
   put false into sBusy
   if the mode of me is not 0 then
      csRender
   end if
end csInstall

-- Goes to a stack of the list, by its number
private command csGo pPage
   local tSaved
   if pPage is empty or pPage is sPage then
      csSyncIndex
      exit csGo
   end if
   put pPage into sPage
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen for visual effect in rect lkR(kSide, 0, the width of me, the height of me)
   csRender
   csSyncIndex
   unlock screen with visual effect "dissolve" very fast
   csRestore tSaved
end csGo

-- The stack above (-1) or below (1) in the index
private command csStep pBy
   local tLine
   put csIndexOf(sPage) into tLine
   if tLine is empty then
      put 1 into tLine
   else
      add pBy to tLine
   end if
   if sIndexMap[tLine] is not empty then
      csGo sIndexMap[tLine]
   end if
end csStep

################################################################################
#
# The page
#

private command csRender
   local tSaved, tHtml, tEntry, tList, tLibraries
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   put sState is "list" and sPage is an integer and sStacks[sPage] is an array into tList
   put sMode is "libraries" into tLibraries
   if tList then
      put sStacks[sPage] into tEntry
      put tEntry["title"] into field "hdrTitle"
      put csTagLine(tEntry) into field "hdrTag"
      if tLibraries then
         put csLibraryHtml(tEntry) into tHtml
      else
         put csEntryHtml(tEntry) into tHtml
      end if
   else if sState is "loading" then
      put "Community Stacks" into field "hdrTitle"
      put "Asking the gallery for its list of" && csNoun(2) into field "hdrTag"
      put "<p>One moment.</p>" into tHtml
   else if sState is "problem" then
      put "Community Stacks" into field "hdrTitle"
      put "The list of" && csNoun(2) && "is not shown" into field "hdrTag"
      put csProblemHtml() into tHtml
   else if tLibraries then
      put "Community Stacks" into field "hdrTitle"
      put "The gallery has no libraries yet" into field "hdrTag"
      put "<p>When somebody shares a script library, it is listed here, ready to install. The gallery's page Share a Library says how to share one of yours.</p>" into tHtml
   else
      put "Community Stacks" into field "hdrTitle"
      put "The gallery has no stacks yet" into field "hdrTag"
      put "<p>When somebody shares a stack, it is listed here. File &gt; Share Stack... packs one of yours for the gallery.</p>" into tHtml
   end if
   set the htmlText of field "page" to tHtml
   set the vScroll of field "page" to 0
   lkScrollSync "pageThumb"
   lkEllipsize the long id of field "hdrTitle"
   lkEllipsize the long id of field "hdrTag"
   -- The buttons that fit what is shown
   set the visible of group "play" to tList and not tLibraries and tEntry["play"] is not empty
   set the visible of group "scripts" to tList and not tLibraries and tEntry["source"] is not empty
   set the visible of group "copy" to tList and not tLibraries
   set the visible of group "demo" to tList and tLibraries and tEntry["play"] is not empty
   set the visible of group "script" to tList and tLibraries and tEntry["source"] is not empty
   set the visible of group "install" to tList and tLibraries
   set the visible of group "again" to sState is "problem"
   if tList and tLibraries and tEntry["play"] is empty then
      set the left of group "script" to kSide + kPad - 8
   else
      set the left of group "script" to the right of group "demo" + 10
   end if
   lkRestAt "script"
   if tList and tEntry["play"] is empty then
      set the left of group "scripts" to kSide + kPad - 8
   else
      set the left of group "scripts" to the right of group "play" + 10
   end if
   lkRestAt "scripts"
   unlock screen
   csRestore tSaved
end csRender

-- "by A. Name, Version 1.0, MIT, 37 KB", with a raised dot between them
private function csTagLine pEntry
   local tDot
   put "  " & numToCodepoint(0x00B7) & "  " into tDot
   return "by" && pEntry["author"] & tDot & "Version" && pEntry["version"] & tDot & pEntry["licence"] & tDot & csSize(pEntry["size"])
end csTagLine

-- The page of a stack: what it does, what it reaches for, its words
private function csEntryHtml pEntry
   local tHtml, tLine, tInk, tSoft, tUses, tTags, tTag
   put lkHex(lkColor("ink")) into tInk
   put lkHex(lkColor("muted")) into tSoft
   put "<p><font size=" & quote & "16" & quote & " color=" & quote & tInk & quote & ">" & lkEscape(pEntry["description"]) & "</font></p>" into tHtml
   put "<p></p>" after tHtml
   put "<p><font color=" & quote & tInk & quote & "><b>What its scripts reach for</b></font></p>" after tHtml
   put revCommunityStacksUsesWords(pEntry["uses"]) into tUses
   if tUses is empty then
      put "<p>The gallery's checker found nothing in it that reaches outside the stack.</p>" after tHtml
   else
      set the itemDelimiter to tab
      repeat for each line tLine in tUses
         put "<p>" & numToCodepoint(0x2022) && "<font color=" & quote & tInk & quote & ">" & lkEscape(item 1 of tLine) & ".</font>" && \
               lkEscape(item 2 of tLine) & "</p>" after tHtml
      end repeat
      set the itemDelimiter to comma
   end if
   put "<p></p>" after tHtml
   put "<p><font color=" & quote & tInk & quote & "><b>Trying it</b></font></p>" after tHtml
   put "<p>Play in Browser opens it on the gallery's site, in a box that keeps it away from your computer. That is the safe way to try any stack.</p>" after tHtml
   put "<p>Get a Copy brings its file here, checked against the gallery's signed list, so that you can read how it is made and learn from it.</p>" after tHtml
   if pEntry["lines"] is not empty or pEntry["tags"] is not empty then
      put "<p></p>" after tHtml
   end if
   if pEntry["lines"] is not empty then
      if pEntry["lines"] is 1 then
         put "<p><font color=" & quote & tSoft & quote & ">1 line of script</font></p>" after tHtml
      else
         put "<p><font color=" & quote & tSoft & quote & ">" & pEntry["lines"] && "lines of script</font></p>" after tHtml
      end if
   end if
   if pEntry["tags"] is not empty then
      repeat for each line tTag in pEntry["tags"]
         put tTag & ", " after tTags
      end repeat
      delete char -2 to -1 of tTags
      put "<p><font color=" & quote & tSoft & quote & ">Found by: " & lkEscape(tTags) & "</font></p>" after tHtml
   end if
   return tHtml
end csEntryHtml

-- What a library reaches for, a line each: the words, a tab and what
-- they mean, as the gallery's page for it says them (LIBRARY_BADGES and
-- library_page in tools/build_site.py there). pEntry is a library of the
-- list.
function revCommunityLibrariesUsesWords pEntry
   local tLine, tOut, tMessages, tCount
   repeat for each line tLine in pEntry["uses"]
      switch tLine
         case "internet"
            put "Uses the internet" & tab & "It gets or sends information over the internet." & return after tOut
            break
         case "files"
            put "Opens or saves files" & tab & "It reads or writes files on this computer." & return after tOut
            break
         case "javascript"
            put "Runs JavaScript" & tab & "It runs JavaScript in a page of its own." & return after tOut
            break
         default
            put "Uses" && tLine & tab & "The gallery's checker marked it with this word." & return after tOut
      end switch
   end repeat
   if pEntry["messages"] is not empty then
      put 0 into tCount
      repeat for each line tLine in pEntry["messages"]
         add 1 to tCount
         if tCount > 20 then
            exit repeat
         end if
         put tLine & ", " after tMessages
      end repeat
      delete char -2 to -1 of tMessages
      put "Listens to every stack" & tab & "It handles messages that the engine sends (" & tMessages & \
            "), and gets them from every stack while it is installed." & return after tOut
   end if
   repeat for each line tLine in pEntry["notes"]
      if tLine is among the items of "do,send,value,set-script,could-fetch-script" then
         put "Builds script as it runs" & tab & "The checker cannot follow script that is put together while a program runs, so these words may say less than the library does." & return after tOut
         exit repeat
      end if
   end repeat
   delete the last char of tOut
   return tOut
end revCommunityLibrariesUsesWords

-- The version of the library named pName that is installed in this IDE,
-- or empty
private function csInstalledVersion pName
   local tStatus, tVersion, tError
   try
      put revIDEExtensionProperty(pName, "status") into tStatus
      put revIDEExtensionProperty(pName, "version") into tVersion
   catch tError
      return empty
   end try
   if tStatus is "installed" then
      return tVersion
   end if
   return empty
end csInstalledVersion

-- The page of a library: what it does, what it gives a stack, what it
-- reaches for, and what installing it means
private function csLibraryHtml pEntry
   local tHtml, tLine, tInk, tSoft, tUses, tTags, tTag, tCount, tInstalled
   put lkHex(lkColor("ink")) into tInk
   put lkHex(lkColor("muted")) into tSoft
   put "<p><font size=" & quote & "16" & quote & " color=" & quote & tInk & quote & ">" & lkEscape(pEntry["description"]) & "</font></p>" into tHtml
   put csInstalledVersion(pEntry["name"]) into tInstalled
   if tInstalled is not empty then
      put "<p></p>" after tHtml
      if tInstalled is pEntry["version"] then
         put "<p><font color=" & quote & tInk & quote & "><b>Installed.</b></font> Its commands and functions are ready for your stacks. The Extension Manager lists it, and uninstalls it.</p>" after tHtml
      else
         put "<p><font color=" & quote & tInk & quote & "><b>Version " & lkEscape(tInstalled) & " is installed.</b></font> Install puts this version in its place.</p>" after tHtml
      end if
   end if
   put "<p></p>" after tHtml
   put "<p><font color=" & quote & tInk & quote & "><b>What it gives your stacks</b></font></p>" after tHtml
   put 0 into tCount
   set the itemDelimiter to tab
   repeat for each line tLine in pEntry["handlers"]
      add 1 to tCount
      if tCount > 40 then
         exit repeat
      end if
      put "<p>" & numToCodepoint(0x2022) && "<font color=" & quote & tInk & quote & ">" & lkEscape(item 2 of tLine) & "</font></p>" after tHtml
   end repeat
   set the itemDelimiter to comma
   if the number of lines of pEntry["handlers"] > 40 then
      put "<p>And" && the number of lines of pEntry["handlers"] - 40 && "more. Read Its Script shows them all.</p>" after tHtml
   end if
   put "<p></p>" after tHtml
   put "<p><font color=" & quote & tInk & quote & "><b>What it reaches for</b></font></p>" after tHtml
   put revCommunityLibrariesUsesWords(pEntry) into tUses
   if tUses is empty then
      put "<p>The gallery's checker found no internet and no files in it.</p>" after tHtml
   else
      set the itemDelimiter to tab
      repeat for each line tLine in tUses
         put "<p>" & numToCodepoint(0x2022) && "<font color=" & quote & tInk & quote & ">" & lkEscape(item 1 of tLine) & ".</font>" && \
               lkEscape(item 2 of tLine) & "</p>" after tHtml
      end repeat
      set the itemDelimiter to comma
   end if
   put "<p></p>" after tHtml
   put "<p><font color=" & quote & tInk & quote & "><b>Installing it</b></font></p>" after tHtml
   put "<p>A library is not played: Install adds it to OXT-Beyond, as the Extension Manager adds any extension, and it loads each time OXT-Beyond starts. Its commands and functions are then there for every stack you open.</p>" after tHtml
   put "<p>It runs on this computer as your own scripts do, with no box around it. The gallery's checker and a person read every line of it before it was listed, and Read Its Script shows them to you. Install libraries only from people you trust.</p>" after tHtml
   if pEntry["play"] is not empty then
      put "<p>Try the Demo plays a stack that uses it, on the gallery's site, in a box that keeps it away from your computer.</p>" after tHtml
   end if
   if pEntry["lines"] is not empty or pEntry["tags"] is not empty then
      put "<p></p>" after tHtml
   end if
   if pEntry["lines"] is not empty then
      if pEntry["lines"] is 1 then
         put "<p><font color=" & quote & tSoft & quote & ">1 line of script</font></p>" after tHtml
      else
         put "<p><font color=" & quote & tSoft & quote & ">" & pEntry["lines"] && "lines of script</font></p>" after tHtml
      end if
   end if
   if pEntry["tags"] is not empty then
      repeat for each line tTag in pEntry["tags"]
         put tTag & ", " after tTags
      end repeat
      delete char -2 to -1 of tTags
      put "<p><font color=" & quote & tSoft & quote & ">Found by: " & lkEscape(tTags) & "</font></p>" after tHtml
   end if
   return tHtml
end csLibraryHtml

-- Why there is no list, and what to do
private function csProblemHtml
   local tHtml, tInk
   put lkHex(lkColor("ink")) into tInk
   put "<p><font size=" & quote & "16" & quote & " color=" & quote & tInk & quote & ">" & lkEscape(sProblem["problem"]) & "</font></p>" into tHtml
   put "<p></p>" after tHtml
   if sProblem["unsigned"] is true then
      put "<p>Nothing is wrong on your side. The gallery signs its list so that this window can tell the real list from a copy somebody changed, and the list at its address has no signature yet.</p>" after tHtml
      put "<p></p>" after tHtml
   end if
   if sMode is "libraries" then
      put "<p>Every library of the gallery can still be read on its site: press Open the Gallery.</p>" after tHtml
   else
      put "<p>Every stack of the gallery can still be played in your browser: press Open the Gallery.</p>" after tHtml
   end if
   return tHtml
end csProblemHtml
