script "oxtBeyondUpdater"
-- OXT-Beyond: update checks.
--
-- Asks GitHub for the newest release of OXT-Beyond, compares its tag
-- (v<major>.<minor>.<patch>[-<pre-release>]) with the version in the IDE's
-- .version file, and tells the user when a newer release exists, with a
-- button that opens the release page in the browser. It never downloads or
-- installs anything and needs no administrator rights. It only contacts
-- api.github.com; it never contacts the OpenXTalk Lite update servers.
--
-- Which release counts: GitHub's "latest release" of the repository when its
-- tag is a v-prefixed version. The repository also publishes releases that are
-- not OXT-Beyond versions (build prerequisites and runtime files, with tags
-- such as prebuilts-v1 or runtimes-1.15); when the latest release is one of
-- those, or there is none, the check reads the list of releases and takes the
-- highest v-prefixed version that is not a draft. Pre-releases (-alpha, -beta,
-- -rc, ...) are only offered to users who already run a pre-release: for them
-- the check always reads the list of releases too (GitHub's latest release is
-- never a pre-release) and takes the highest version of both.
--
-- Only one check runs at a time: a check started while another one is still
-- waiting for GitHub returns the status "busy" at once.
--
-- The IDE loads this library at startup (revInternal__InitialiseLibraries in
-- home.livecodescript). It inserts itself as a front script, which makes its
-- commands available everywhere and lets it answer the update messages of the
-- Preferences window's "Automatic Updates" card (a binary stack still wired to
-- OpenXTalk Lite's updater, see "Messages from the Preferences window" below).
--
-- Public handlers:
--    oxtBeyondCheckForUpdates [pInteractive]
--       Help > Check for Updates. With pInteractive true (the default) it
--       always reports the result; with false it only speaks up when a newer
--       release exists.
--    oxtBeyondAutoCheckForUpdates
--       The automatic check. Does nothing unless the "useAutomaticUpdates"
--       preference (cUseAutoUpdates, off by default) is on, and checks at most
--       once a day (or week or month if cUseAutoUpdatesInterval says so).
--    oxtBeyondLatestRelease()
--       Checks without any user interface and returns an array: status
--       ("update", "current", "newer", "norelease", "busy" or "error"),
--       current, latest, tag, name, url, notes, error.
--    oxtBeyondCompareVersions(pA, pB)
--       -1, 0 or 1 as version pA is lower than, equal to or higher than pB
--       (semantic versioning order), or empty if either is not a version.
--    oxtBeyondParseRelease(pJSON), oxtBeyondParseReleaseList(pJSON)
--       The fields the check uses from a GitHub release object, or from each
--       release in a list (keys 1, 2, ...).

constant kLatestReleaseApiUrl = "https://api.github.com/repos/SethMorrowSoftware/OpenXTalk-Beyond/releases/latest"
constant kReleaseListApiUrl = "https://api.github.com/repos/SethMorrowSoftware/OpenXTalk-Beyond/releases?per_page=30"
constant kReleasesPageUrl = "https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases"
constant kDialogTitle = "OXT-Beyond Updates"
constant kProductName = "OXT-Beyond"
-- Give up on the server after this many milliseconds without data.
constant kTimeoutMilliseconds = 15000
-- How much of the release notes to show.
constant kExcerptLines = 12
constant kExcerptChars = 700

local sParseError
-- True while oxtBeyondLatestRelease is waiting for GitHub. The requests of two
-- overlapping checks would share libURL's state for the same URL (and the
-- global httpHeaders), so a second check does not start one of its own.
local sChecking

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   -- Mark this stack as part of the IDE even when it is loaded on demand.
   set the _ideoverride of me to true
   if the long id of me is not among the lines of the frontScripts then
      insert the script of me into front
   end if
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if
   remove the script of me from front
end extensionFinalize

--------------------------------------------------------------------------------
-- Checking

command oxtBeyondCheckForUpdates pInteractive
   if pInteractive is empty then put true into pInteractive
   local tInfo
   if pInteractive then set the cursor to watch
   put oxtBeyondLatestRelease() into tInfo
   oxtbRecordCheck tInfo

   switch tInfo["status"]
      case "update"
         oxtbShowUpdate tInfo
         break
      case "current"
         if pInteractive then
            answer information "You have the latest release of" && kProductName && "(" & tInfo["current"] & ")." titled kDialogTitle
         end if
         break
      case "newer"
         if pInteractive then
            answer information "This copy of" && kProductName && "(" & tInfo["current"] & ") is newer than the latest release (" & tInfo["latest"] & ")." titled kDialogTitle
         end if
         break
      case "norelease"
         if pInteractive then
            answer information "No" && kProductName && "release has been published yet." with "Open Releases Page" or "OK" titled kDialogTitle
            if it is "Open Releases Page" then launch url kReleasesPageUrl
         end if
         break
      case "busy"
         if pInteractive then
            answer information "A check for updates is already running. Please try again in a moment." titled kDialogTitle
         end if
         break
      default
         if pInteractive then
            answer warning "Could not check for updates." & return & return & tInfo["error"] with "Open Releases Page" or "OK" titled kDialogTitle
            if it is "Open Releases Page" then launch url kReleasesPageUrl
         end if
         break
   end switch
end oxtBeyondCheckForUpdates

command oxtBeyondAutoCheckForUpdates
   if not oxtbPreferencesAvailable() then exit oxtBeyondAutoCheckForUpdates
   if the cUseAutoUpdates of stack "revPreferences" is not true then exit oxtBeyondAutoCheckForUpdates

   local tInterval, tLast
   switch the cUseAutoUpdatesInterval of stack "revPreferences"
      case "Weekly"
         put 7 * 86400 into tInterval
         break
      case "Monthly"
         put 28 * 86400 into tInterval
         break
      default
         put 86400 into tInterval
         break
   end switch
   put the tAutoUpdatesLastChecked of stack "revPreferences" into tLast
   if tLast is a number and the seconds - tLast < tInterval then exit oxtBeyondAutoCheckForUpdates

   oxtBeyondCheckForUpdates false
end oxtBeyondAutoCheckForUpdates

function oxtBeyondLatestRelease
   local tInfo
   if sChecking is true then
      put oxtbCurrentVersion() into tInfo["current"]
      put kReleasesPageUrl into tInfo["url"]
      put "busy" into tInfo["status"]
      return tInfo
   end if
   put true into sChecking
   try
      put oxtbLatestRelease() into tInfo
   catch tError
      put false into sChecking
      throw tError
   end try
   put false into sChecking
   return tInfo
end oxtBeyondLatestRelease

private function oxtbLatestRelease
   local tInfo, tBody, tStatus, tHeaders, tError, tRelease, tList, tBest, tCompare, tAllowPre
   put oxtbCurrentVersion() into tInfo["current"]
   put kReleasesPageUrl into tInfo["url"]
   -- Someone running a pre-release is also told about newer pre-releases.
   put oxtbParseVersion(tInfo["current"]) into tRelease
   put tRelease["pre"] is not empty into tAllowPre
   put empty into tRelease

   -- 1. The repository's latest release.
   oxtbHttpGet kLatestReleaseApiUrl, tStatus, tBody, tHeaders, tError
   if tError is empty then put oxtbStatusError(tStatus, tHeaders, "200,404") into tError
   if tError is not empty then return oxtbFailed(tInfo, tError)
   if tStatus is 200 then
      put oxtBeyondParseRelease(tBody) into tRelease
      if sParseError is not empty then return oxtbFailed(tInfo, oxtbUnreadable())
      if oxtbIsProductRelease(tRelease, tAllowPre) then put tRelease into tBest
   end if

   -- 2. The highest version in the list of releases: when the latest release
   --    is not an OXT-Beyond version, and always for someone running a
   --    pre-release, because GitHub's latest release is never a pre-release.
   if tBest is empty or tAllowPre then
      oxtbHttpGet kReleaseListApiUrl, tStatus, tBody, tHeaders, tError
      if tError is empty then put oxtbStatusError(tStatus, tHeaders, "200") into tError
      if tError is empty then
         put oxtBeyondParseReleaseList(tBody) into tList
         if sParseError is not empty then put oxtbUnreadable() into tError
      end if
      if tError is not empty then
         -- Without the list, a pre-release user still gets the answer of step 1.
         if tBest is empty then return oxtbFailed(tInfo, tError)
         put empty into tList
      end if
      repeat with i = 1 to the number of elements of tList
         put tList[i] into tRelease
         if not oxtbIsProductRelease(tRelease, tAllowPre) then next repeat
         if tBest is empty then
            put tRelease into tBest
         else if oxtBeyondCompareVersions(tRelease["tag"], tBest["tag"]) > 0 then
            put tRelease into tBest
         end if
      end repeat
   end if

   if tBest is empty then
      put "norelease" into tInfo["status"]
      return tInfo
   end if

   put tBest["tag"] into tInfo["tag"]
   put tBest["name"] into tInfo["name"]
   put tBest["notes"] into tInfo["notes"]
   put oxtbStripV(tBest["tag"]) into tInfo["latest"]
   -- Only open pages of this project's releases.
   if tBest["url"] begins with (kReleasesPageUrl & "/") then
      put tBest["url"] into tInfo["url"]
   end if

   put oxtBeyondCompareVersions(tInfo["latest"], tInfo["current"]) into tCompare
   if tCompare is empty then
      return oxtbFailed(tInfo, "This copy's version (" & tInfo["current"] & ") is not a version number.")
   else if tCompare > 0 then
      put "update" into tInfo["status"]
   else if tCompare < 0 then
      put "newer" into tInfo["status"]
   else
      put "current" into tInfo["status"]
   end if
   return tInfo
end oxtbLatestRelease

-- A release of OXT-Beyond itself: tag v<version>, not a draft, and not a
-- pre-release unless pAllowPre.
private function oxtbIsProductRelease pRelease, pAllowPre
   if pRelease is not an array then return false
   if char 1 of pRelease["tag"] is not "v" then return false
   if oxtbParseVersion(pRelease["tag"]) is not an array then return false
   if pRelease["draft"] then return false
   if pRelease["prerelease"] and not pAllowPre then return false
   return true
end oxtbIsProductRelease

private function oxtbStatusError pStatus, pHeaders, pAccepted
   if pStatus is among the items of pAccepted then return empty
   if pStatus is 429 or (pStatus is 403 and oxtbHeader(pHeaders, "x-ratelimit-remaining") is "0") then
      return "GitHub's limit on requests from this network has been reached. Try again later."
   end if
   return "The update server answered with HTTP status" && pStatus & "."
end oxtbStatusError

private function oxtbFailed pInfo, pError
   put "error" into pInfo["status"]
   put pError into pInfo["error"]
   return pInfo
end oxtbFailed

private function oxtbUnreadable
   return "The update server's answer could not be read (" & sParseError & ")."
end oxtbUnreadable

private command oxtbShowUpdate pInfo
   local tPrompt, tExcerpt, tName
   put kProductName && pInfo["latest"] && "is available. You have" && pInfo["current"] & "." into tPrompt
   -- The release job titles releases "OXT-Beyond <version>", which the first
   -- line already says; only show a name that says more than that.
   put oxtbTrim(pInfo["name"]) into tName
   if tName is not empty and oxtbStripV(tName) is not pInfo["latest"] \
         and tName is not (kProductName && pInfo["latest"]) \
         and tName is not (kProductName && "v" & pInfo["latest"]) then
      put return & oxtbNoTags(tName) after tPrompt
   end if
   put oxtbNotesExcerpt(pInfo["notes"]) into tExcerpt
   if tExcerpt is not empty then
      put return & return & tExcerpt after tPrompt
   end if
   put return & return & "The release page has the downloads and the full notes." after tPrompt
   answer information tPrompt with "Open Release Page" or "Later" titled kDialogTitle
   if it is "Open Release Page" then
      launch url pInfo["url"]
   end if
end oxtbShowUpdate

private command oxtbRecordCheck pInfo
   if pInfo["status"] is among the items of "error,busy" then exit oxtbRecordCheck
   if not oxtbPreferencesAvailable() then exit oxtbRecordCheck
   set the tAutoUpdatesLastChecked of stack "revPreferences" to the seconds
   oxtbShowLastCheck
end oxtbRecordCheck

-- Show the time of the last successful check on the Preferences window's
-- "Automatic Updates" card, when that window is open (the card has a field
-- for it that OpenXTalk Lite's updater used to fill in).
private command oxtbShowLastCheck
   local tLast
   try
      if "revPreferencesGUI" is not among the lines of the openStacks then exit oxtbShowLastCheck
      put the tAutoUpdatesLastChecked of stack "revPreferences" into tLast
      if tLast is a number then
         convert tLast to short date and short time
      else
         put "not checked" into tLast
      end if
      put "Last checked for updates:" & return & tLast into field "tlastchecked" of card "Automatic Updates" of stack "revPreferencesGUI"
   end try
end oxtbShowLastCheck

private function oxtbPreferencesAvailable
   try
      return there is a stack "revPreferences"
   catch tError
      return false
   end try
end oxtbPreferencesAvailable

--------------------------------------------------------------------------------
-- Messages from the Preferences window
--
-- The "Automatic Updates" card of revPreferencesGUI.rev (a binary stack, not
-- changed yet) opens OpenXTalk Lite's updates.livecode, which downloads and
-- installs files from openxtalk.net. While this library is a front script it
-- receives those messages first and handles them itself, so that stack is
-- never opened: "Check now" runs this check, and opening the card shows when
-- this library last checked instead of starting a check (the automatic check
-- runs once at IDE startup).

on tCheckForUpdates
   if not oxtbIsPreferencesUpdatesCard(the long id of the target) then pass tCheckForUpdates
   oxtBeyondCheckForUpdates true
end tCheckForUpdates

on tCheckForUpdatesVis
   if not oxtbIsPreferencesUpdatesCard(the long id of the target) then pass tCheckForUpdatesVis
   oxtBeyondCheckForUpdates true
end tCheckForUpdatesVis

on tAutoUpdatesHook
   if not oxtbIsPreferencesUpdatesCard(the long id of the target) then pass tAutoUpdatesHook
   -- Sent when the card opens: show when this library last checked.
   oxtbShowLastCheck
end tAutoUpdatesHook

on tLastAutomaticUpdateCheck
   if not oxtbIsPreferencesUpdatesCard(the long id of the target) then pass tLastAutomaticUpdateCheck
end tLastAutomaticUpdateCheck

private function oxtbIsPreferencesUpdatesCard pTarget
   try
      return word 1 of pTarget is "card" \
            and the short name of pTarget is "Automatic Updates" \
            and the short name of the owner of pTarget is "revPreferencesGUI"
   catch tError
      return false
   end try
end oxtbIsPreferencesUpdatesCard

--------------------------------------------------------------------------------
-- HTTP

-- rStatus is the HTTP status when the server answered; otherwise rError says
-- why there was no answer.
--
-- The request is started with "load url" and waited for with a deadline, so a
-- server or connection that stops responding cannot block the IDE's handler
-- for good. "Connection: close" makes each request use a new connection:
-- libURL can stall when it reuses a kept-alive connection to api.github.com.
private command oxtbHttpGet pUrl, @rStatus, @rBody, @rHeaders, @rError
   local tOldHeaders, tOldTimeout, tData, tResult, tDeadline
   put empty into rStatus
   put empty into rBody
   put empty into rHeaders
   put empty into rError
   
   put the httpHeaders into tOldHeaders
   put the socketTimeoutInterval into tOldTimeout
   set the httpHeaders to "Accept: application/vnd.github+json" & return &          "X-GitHub-Api-Version: 2022-11-28" & return &          "User-Agent:" && kProductName & "/" & oxtbCurrentVersion() & return &          "Connection: close"
   set the socketTimeoutInterval to kTimeoutMilliseconds
   try
      load url pUrl
      put the milliseconds + 2 * kTimeoutMilliseconds into tDeadline
      wait until oxtbLoadFinished(pUrl) or the milliseconds > tDeadline with messages
      switch item 1 of urlStatus(pUrl)
         case "cached"
            put url pUrl into tData
            put empty into tResult
            break
         case "error"
            put libUrlErrorData(pUrl) into tResult
            if tResult is empty then put "error" into tResult
            break
         case "timeout"
            put "error timeout" into tResult
            break
         default
            put "error timeout (no answer within" && (2 * kTimeoutMilliseconds) div 1000 && "seconds)" into tResult
            break
      end switch
   catch tError
      put "error" && tError into tResult
   end try
   try
      unload url pUrl
   end try
   set the httpHeaders to tOldHeaders
   set the socketTimeoutInterval to tOldTimeout

   -- An empty result means success; an HTTP error answer gives
   -- "error <status> <reason>". Anything else means there was no answer.
   if tResult is empty then
      put 200 into rStatus
   else if word 1 of tResult is "error" and word 2 of tResult is an integer \
         and the number of chars of word 2 of tResult is 3 then
      put word 2 of tResult into rStatus
   else
      if tResult contains "timeout" then
         put "The update server did not answer in time." into rError
      else
         put "The update server could not be reached. Check the internet connection." into rError
      end if
      put return & "(" & oxtbOneLine(tResult) & ")" after rError
      return empty
   end if

   -- The headers of this answer (only read when there was one, as libURL
   -- keeps the last headers it received).
   try
      put libUrlLastRhHeaders() into rHeaders
   catch tError
      put empty into rHeaders
   end try
   replace numToCodepoint(13) with empty in rHeaders

   try
      put textDecode(tData, "utf-8") into rBody
   catch tError
      put tData into rBody
   end try
end oxtbHttpGet

private function oxtbLoadFinished pUrl
   return item 1 of urlStatus(pUrl) is among the items of "cached,error,timeout"
end oxtbLoadFinished

private function oxtbHeader pHeaders, pName
   repeat for each line tLine in pHeaders
      if tLine begins with (pName & ":") then
         return oxtbTrim(char (the number of chars of pName) + 2 to -1 of tLine)
      end if
   end repeat
   return empty
end oxtbHeader

--------------------------------------------------------------------------------
-- Versions

private function oxtbCurrentVersion
   -- .version is in the IDE root folder, two levels above Toolset/libraries.
   local tPath, tText
   set the itemDelimiter to slash
   put item 1 to -4 of the effective filename of me & "/.version" into tPath
   set the itemDelimiter to comma
   if there is no file tPath then return empty
   put url ("binfile:" & tPath) into tText
   if tText is empty then return empty
   try
      put textDecode(tText, "utf-8") into tText
   end try
   -- Drop a byte order mark and surrounding white space.
   if codepointToNum(codepoint 1 of tText) is 0xFEFF then delete codepoint 1 of tText
   replace numToCodepoint(13) with empty in tText
   return oxtbTrim(line 1 of tText)
end oxtbCurrentVersion

private function oxtbStripV pTag
   put oxtbTrim(pTag) into pTag
   if char 1 of pTag is "v" then delete char 1 of pTag
   return pTag
end oxtbStripV

-- An array with keys 1, 2, 3 (numbers) and "pre" (pre-release identifiers,
-- dot separated), or empty if pVersion is not a version.
private function oxtbParseVersion pVersion
   local tMain, tPre, tResult, tCount
   put oxtbStripV(pVersion) into pVersion
   if pVersion is empty then return empty
   -- Build metadata does not affect the order.
   set the itemDelimiter to "+"
   put item 1 of pVersion into pVersion
   set the itemDelimiter to "-"
   put item 1 of pVersion into tMain
   put item 2 to -1 of pVersion into tPre
   if pVersion contains "-" and tPre is empty then return empty
   set the itemDelimiter to "."
   put the number of items of tMain into tCount
   if tCount < 1 or tCount > 3 or char -1 of tMain is "." then return empty
   repeat with i = 1 to 3
      if i > tCount then
         put 0 into tResult[i]
      else if item i of tMain is an integer and item i of tMain >= 0 and item i of tMain is not empty then
         put item i of tMain + 0 into tResult[i]
      else
         return empty
      end if
   end repeat
   put tPre into tResult["pre"]
   return tResult
end oxtbParseVersion

function oxtBeyondCompareVersions pA, pB
   local tA, tB, tCountA, tCountB, tX, tY
   put oxtbParseVersion(pA) into tA
   put oxtbParseVersion(pB) into tB
   if tA is not an array or tB is not an array then return empty
   repeat with i = 1 to 3
      if tA[i] < tB[i] then return -1
      if tA[i] > tB[i] then return 1
   end repeat
   -- A version without a pre-release part comes after one with it.
   if tA["pre"] is empty and tB["pre"] is empty then return 0
   if tA["pre"] is empty then return 1
   if tB["pre"] is empty then return -1
   set the itemDelimiter to "."
   put the number of items of tA["pre"] into tCountA
   put the number of items of tB["pre"] into tCountB
   set the caseSensitive to true
   repeat with i = 1 to max(tCountA, tCountB)
      if i > tCountA then return -1
      if i > tCountB then return 1
      put item i of tA["pre"] into tX
      put item i of tB["pre"] into tY
      if tX is an integer and tY is an integer then
         if tX + 0 < tY + 0 then
            return -1
         else if tX + 0 > tY + 0 then
            return 1
         end if
      else if tX is an integer then
         return -1
      else if tY is an integer then
         return 1
      else if tX is not tY then
         -- Compare identifiers character by character (ASCII order).
         repeat with j = 1 to min(the number of codeunits of tX, the number of codeunits of tY)
            if codepointToNum(codeunit j of tX) < codepointToNum(codeunit j of tY) then return -1
            if codepointToNum(codeunit j of tX) > codepointToNum(codeunit j of tY) then return 1
         end repeat
         if the number of codeunits of tX < the number of codeunits of tY then return -1
         return 1
      end if
   end repeat
   return 0
end oxtBeyondCompareVersions

--------------------------------------------------------------------------------
-- Release notes

private function oxtbNotesExcerpt pNotes
   local tOut, tLines, tLastEmpty, tTruncated
   replace numToCodepoint(13) with empty in pNotes
   put 0 into tLines
   put true into tLastEmpty
   put false into tTruncated
   repeat for each line tLine in pNotes
      put oxtbTrim(tLine) into tLine
      -- Markdown headings: show the text without the # marks.
      repeat while char 1 of tLine is "#"
         delete char 1 of tLine
      end repeat
      put oxtbTrim(tLine) into tLine
      if tLine is empty then
         if tLastEmpty then next repeat
         put true into tLastEmpty
      else
         put false into tLastEmpty
      end if
      if tLines >= kExcerptLines then
         put true into tTruncated
         exit repeat
      end if
      put tLine & return after tOut
      add 1 to tLines
   end repeat
   put oxtbTrim(tOut) into tOut
   if the number of chars of tOut > kExcerptChars then
      put char 1 to kExcerptChars of tOut into tOut
      put true into tTruncated
   end if
   if tTruncated and tOut is not empty then put " ..." after tOut
   return oxtbNoTags(tOut)
end oxtbNotesExcerpt

-- The answer dialog shows a prompt that contains tags as HTML. Text from
-- GitHub (release name and notes) is shown as text: < and > become the
-- similar-looking single angle quotation marks.
private function oxtbNoTags pText
   replace "<" with numToCodepoint(0x2039) in pText
   replace ">" with numToCodepoint(0x203A) in pText
   return pText
end oxtbNoTags

--------------------------------------------------------------------------------
-- JSON
--
-- A small reader for GitHub's release objects: it returns the members of an
-- object whose values are strings (decoded) or numbers, true, false and null
-- (as their text), and skips nested objects and arrays. It is enough for the
-- release fields used here and does not depend on the JSON extension being
-- loaded. sParseError says what was wrong when the text could not be read.

function oxtBeyondParseRelease pJSON
   local tPos, tMembers
   put empty into sParseError
   put 1 into tPos
   oxtbJsonSkipSpace pJSON, tPos, the number of codeunits of pJSON
   put oxtbJsonObject(pJSON, tPos, the number of codeunits of pJSON) into tMembers
   if sParseError is not empty then return empty
   return oxtbReleaseFields(tMembers)
end oxtBeyondParseRelease

function oxtBeyondParseReleaseList pJSON
   local tLen, tPos, tList, tCount, tChar
   put empty into sParseError
   put the number of codeunits of pJSON into tLen
   put 1 into tPos
   oxtbJsonSkipSpace pJSON, tPos, tLen
   if tPos > tLen or codeunit tPos of pJSON is not "[" then
      return oxtbJsonFail("not a JSON array")
   end if
   add 1 to tPos
   put 0 into tCount
   oxtbJsonSkipSpace pJSON, tPos, tLen
   if tPos <= tLen and codeunit tPos of pJSON is "]" then return tList
   repeat
      if tPos > tLen then return oxtbJsonFail("unexpected end")
      if codeunit tPos of pJSON is "{" then
         add 1 to tCount
         put oxtbReleaseFields(oxtbJsonObject(pJSON, tPos, tLen)) into tList[tCount]
      else
         oxtbJsonSkipValue pJSON, tPos, tLen
      end if
      if sParseError is not empty then return empty
      oxtbJsonSkipSpace pJSON, tPos, tLen
      if tPos > tLen then return oxtbJsonFail("unexpected end")
      put codeunit tPos of pJSON into tChar
      add 1 to tPos
      if tChar is "]" then exit repeat
      if tChar is not comma then return oxtbJsonFail("expected ',' or ']'")
      oxtbJsonSkipSpace pJSON, tPos, tLen
   end repeat
   return tList
end oxtBeyondParseReleaseList

private function oxtbReleaseFields pMembers
   local tRelease
   put pMembers["tag_name"] into tRelease["tag"]
   put pMembers["name"] into tRelease["name"]
   put pMembers["html_url"] into tRelease["url"]
   put pMembers["body"] into tRelease["notes"]
   put pMembers["prerelease"] is "true" into tRelease["prerelease"]
   put pMembers["draft"] is "true" into tRelease["draft"]
   return tRelease
end oxtbReleaseFields

-- pPos is at the opening {; afterwards it is just after the closing }.
private function oxtbJsonObject pText, @pPos, pLen
   local tKey, tValue, tResult, tChar, tStart
   if pPos > pLen or codeunit pPos of pText is not "{" then
      return oxtbJsonFail("not a JSON object")
   end if
   add 1 to pPos
   oxtbJsonSkipSpace pText, pPos, pLen
   if pPos <= pLen and codeunit pPos of pText is "}" then
      add 1 to pPos
      return tResult
   end if
   repeat
      if pPos > pLen or codeunit pPos of pText is not quote then
         return oxtbJsonFail("expected a member name")
      end if
      put oxtbJsonString(pText, pPos, pLen) into tKey
      if sParseError is not empty then return empty
      oxtbJsonSkipSpace pText, pPos, pLen
      if pPos > pLen or codeunit pPos of pText is not ":" then
         return oxtbJsonFail("expected ':'")
      end if
      add 1 to pPos
      oxtbJsonSkipSpace pText, pPos, pLen
      if pPos > pLen then return oxtbJsonFail("value missing")
      put codeunit pPos of pText into tChar
      if tChar is quote then
         put oxtbJsonString(pText, pPos, pLen) into tValue
      else if tChar is "{" or tChar is "[" then
         oxtbJsonSkipNested pText, pPos, pLen
         put empty into tValue
      else
         put oxtbJsonLiteral(pText, pPos, pLen) into tValue
      end if
      if sParseError is not empty then return empty
      put tValue into tResult[tKey]
      oxtbJsonSkipSpace pText, pPos, pLen
      if pPos > pLen then return oxtbJsonFail("unexpected end")
      put codeunit pPos of pText into tChar
      add 1 to pPos
      if tChar is "}" then exit repeat
      if tChar is not comma then return oxtbJsonFail("expected ',' or '}'")
      oxtbJsonSkipSpace pText, pPos, pLen
   end repeat
   return tResult
end oxtbJsonObject

-- A number, true, false or null, as its text.
private function oxtbJsonLiteral pText, @pPos, pLen
   local tStart, tChar
   put pPos into tStart
   repeat while pPos <= pLen
      put codeunit pPos of pText into tChar
      if tChar is comma or tChar is "}" or tChar is "]" or tChar is space \
            or tChar is tab or tChar is return or codepointToNum(tChar) is 13 then
         exit repeat
      end if
      add 1 to pPos
   end repeat
   if pPos = tStart then return oxtbJsonFail("value missing")
   return codeunit tStart to pPos - 1 of pText
end oxtbJsonLiteral

private command oxtbJsonSkipValue pText, @pPos, pLen
   local tChar
   put codeunit pPos of pText into tChar
   if tChar is quote then
      get oxtbJsonString(pText, pPos, pLen)
   else if tChar is "{" or tChar is "[" then
      oxtbJsonSkipNested pText, pPos, pLen
   else
      get oxtbJsonLiteral(pText, pPos, pLen)
   end if
end oxtbJsonSkipValue

private function oxtbJsonFail pMessage
   put pMessage into sParseError
   return empty
end oxtbJsonFail

private command oxtbJsonSkipSpace pText, @pPos, pLen
   local tCode
   repeat while pPos <= pLen
      put codepointToNum(codeunit pPos of pText) into tCode
      if tCode is not among the items of "32,9,10,13" then exit repeat
      add 1 to pPos
   end repeat
end oxtbJsonSkipSpace

-- pPos is at the opening quote; afterwards it is just after the closing one.
private function oxtbJsonString pText, @pPos, pLen
   local tOut, tChar, tStart, tCode, tLow
   add 1 to pPos
   repeat while pPos <= pLen
      put codeunit pPos of pText into tChar
      if tChar is quote then
         add 1 to pPos
         return tOut
      else if tChar is "\" then
         add 1 to pPos
         if pPos > pLen then exit repeat
         put codepointToNum(codeunit pPos of pText) into tCode
         switch tCode
            case 34 -- "
            case 92 -- \
            case 47 -- /
               put numToCodepoint(tCode) after tOut
               break
            case 98 -- b
               put numToCodepoint(8) after tOut
               break
            case 102 -- f
               put numToCodepoint(12) after tOut
               break
            case 110 -- n
               put numToCodepoint(10) after tOut
               break
            case 114 -- r
               put numToCodepoint(13) after tOut
               break
            case 116 -- t
               put numToCodepoint(9) after tOut
               break
            case 117 -- u
               put oxtbJsonHex4(pText, pPos + 1, pLen) into tCode
               if tCode is empty then return oxtbJsonFail("bad \u escape")
               add 4 to pPos
               if tCode >= 0xD800 and tCode <= 0xDBFF then
                  -- A UTF-16 surrogate pair: a high and a low escape together
                  if pPos + 6 <= pLen and codeunit pPos + 1 of pText is "\" \
                        and codepointToNum(codeunit pPos + 2 of pText) is 117 then
                     put oxtbJsonHex4(pText, pPos + 3, pLen) into tLow
                     if tLow is not empty and tLow >= 0xDC00 and tLow <= 0xDFFF then
                        put 0x10000 + (tCode - 0xD800) * 0x400 + (tLow - 0xDC00) into tCode
                        add 6 to pPos
                     else
                        put 0xFFFD into tCode
                     end if
                  else
                     put 0xFFFD into tCode
                  end if
               else if tCode >= 0xDC00 and tCode <= 0xDFFF then
                  put 0xFFFD into tCode
               end if
               put numToCodepoint(tCode) after tOut
               break
            default
               return oxtbJsonFail("bad escape")
         end switch
         add 1 to pPos
      else
         -- A run of plain characters up to the next quote or backslash.
         put pPos into tStart
         repeat while pPos <= pLen
            put codeunit pPos of pText into tChar
            if tChar is quote or tChar is "\" then exit repeat
            add 1 to pPos
         end repeat
         put codeunit tStart to pPos - 1 of pText after tOut
      end if
   end repeat
   return oxtbJsonFail("unterminated string")
end oxtbJsonString

private function oxtbJsonHex4 pText, pStart, pLen
   local tHex
   if pStart + 3 > pLen then return empty
   put codeunit pStart to pStart + 3 of pText into tHex
   if not matchText(tHex, "^[0-9A-Fa-f]{4}$") then return empty
   return baseConvert(tHex, 16, 10)
end oxtbJsonHex4

-- pPos is at the opening { or [; afterwards it is just after the matching one.
private command oxtbJsonSkipNested pText, @pPos, pLen
   local tDepth, tChar
   put 0 into tDepth
   repeat while pPos <= pLen
      put codeunit pPos of pText into tChar
      if tChar is quote then
         get oxtbJsonString(pText, pPos, pLen)
         if sParseError is not empty then exit oxtbJsonSkipNested
         next repeat
      end if
      if tChar is "{" or tChar is "[" then
         add 1 to tDepth
      else if tChar is "}" or tChar is "]" then
         subtract 1 from tDepth
         if tDepth is 0 then
            add 1 to pPos
            exit oxtbJsonSkipNested
         end if
      end if
      add 1 to pPos
   end repeat
   get oxtbJsonFail("unterminated object or array")
end oxtbJsonSkipNested

--------------------------------------------------------------------------------
-- Text

private function oxtbTrim pText
   local tStart, tEnd
   put 1 into tStart
   put the number of chars of pText into tEnd
   repeat while tStart <= tEnd and char tStart of pText is among the items of (space & comma & tab & comma & return)
      add 1 to tStart
   end repeat
   repeat while tEnd >= tStart and char tEnd of pText is among the items of (space & comma & tab & comma & return)
      subtract 1 from tEnd
   end repeat
   if tStart > tEnd then return empty
   return char tStart to tEnd of pText
end oxtbTrim

private function oxtbOneLine pText
   replace numToCodepoint(13) with empty in pText
   replace return with space in pText
   return oxtbTrim(pText)
end oxtbOneLine
