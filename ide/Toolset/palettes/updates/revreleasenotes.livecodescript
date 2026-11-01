script "revReleaseNotes"
-- OXT-Beyond: the Release Notes window, in the look of Home, Learn and the
-- About window.
--
-- Help > Release Notes and the About windows' Release Notes buttons send
-- tOpenReleaseNotes to the Preferences' Automatic Updates card, which
-- opens it (tools/oxt/ide-stack-patches/revpreferencesgui-release-notes.txt):
-- a dark sidebar with a search box and every release, newest first; and a
-- page for the release in front, with what it adds in words, from the
-- README's notes for it, and every change it brought, from CHANGELOG.md.
-- The last line of the list is the history before OXT-Beyond 0.0.2, from
-- HISTORY.md. It opens on the release of this copy of the IDE.
--
-- Those three files are the repository's own: packaging copies them into
-- palettes/updates/notes (tools/oxt/package.py, RELEASE_NOTES), and in a
-- source tree they are read from the repository's root, so the window
-- always shows the changelog of the IDE it is part of and needs no
-- network. A file that is missing leaves its part out.
--
-- The classic window (ReleaseNotes.oxtstack, OpenXTalk Lite's update
-- history) stays as it was: Classic notes opens it, and so does Help >
-- Release Notes with the Option (Alt) key down or when this window cannot
-- open. This window changes no file.
--
-- It opens at 920 by 640, as it always has, and can be made larger, never
-- smaller: rnLayout stretches the page and the index to the window and
-- keeps the buttons at its edges.
--
-- It is a script-only stack, so it keeps no controls: this script builds
-- them when it opens, and draws each page anew. It is drawn by
-- revLearnKit, which is its behavior. Its name begins with "rev", so the
-- IDE treats it as one of its own windows.

constant kWidth = 920
constant kHeight = 640
constant kSide = 236
constant kHeaderHeight = 96
constant kFootHeight = 66
constant kPad = 32
constant kIndexLine = 28
constant kTextInset = 4
-- The widest the page's lines are, however wide the window
constant kMeasure = 860
-- Room at the page's right for its scroll thumb
constant kThumbRoom = 14
constant kRepoUrl = "https://github.com/SethMorrowSoftware/OpenXTalk-Beyond"

-- The releases of CHANGELOG.md, newest first, by number: each one's
-- "version", "date", "pre" (true for a pre-release) and "items" (its
-- changes, a line each); and how many there are
local sRel, sRelCount
-- The README's notes, by version: each one's "title" and "body"
local sNotes
-- HISTORY.md, without its title
local sHistory
-- The release in front (its number), or "history"
local sPage
-- The search text, and the page each line of the index stands for
local sSearch, sIndexMap
-- The version of this copy of the IDE
local sRunning

################################################################################
#
# Opening and closing
#

-- Opens the window, or brings it to the front
command revReleaseNotesShow
   if the mode of me is 0 then
      put empty into sPage
      put empty into sSearch
      modeless me
   else
      go me
   end if
end revReleaseNotesShow

on preOpenStack
   local tSaved, tError
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   try
      rnOpen
   catch tError
      -- (the IDE's defaultStack is put back on the way out, whatever
      -- happens: tOpenReleaseNotes then opens the classic window)
      rnRestore tSaved
      throw tError
   end try
   rnRestore tSaved
end preOpenStack

private command rnRestore pSaved
   if pSaved is not empty and there is a stack pSaved then
      set the defaultStack to pSaved
   end if
end rnRestore

private command rnOpen
   rnUseKit
   -- (light or dark, as the desktop is: lkAppearanceChanged)
   get lkReadAppearance()
   rnLoad
   rnBuild
   rnPlace
   if sPage is empty then
      put rnFindRelease(sRunning) into sPage
      if sPage is empty and sRelCount > 0 then
         put 1 into sPage
      end if
   end if
   put sSearch into field "search"
   rnSyncSearch
   rnFillIndex
   rnRender
   -- (a script-only stack is made invisible when it is loaded)
   show me
end rnOpen

on openStack
   lkStartTicking
   lkEnter "side"
   lkFollowAppearance
end openStack

-- The desktop switched between light and dark (revLearnKit): the window
-- is built again in the other colours, at its size, showing the release
-- it showed, scrolled where it was, with the search as it was
on lkAppearanceChanged
   local tRect, tScroll, tIdxScroll
   if there is no field "page" of me then
      exit lkAppearanceChanged
   end if
   put the rect of me into tRect
   put the vScroll of field "page" of me into tScroll
   put the vScroll of field "idx" of me into tIdxScroll
   lock screen
   lkClear
   rnBuild
   set the rect of me to tRect
   rnLayout
   put sSearch into field "search"
   rnSyncSearch
   rnFillIndex
   rnRender
   set the vScroll of field "idx" of me to tIdxScroll
   set the vScroll of field "page" of me to tScroll
   lkScrollSync "idxThumb"
   lkScrollSync "pageThumb"
   lkEnter "side"
   unlock screen
end lkAppearanceChanged

on closeStack
   lkStopTicking
end closeStack

on resizeStack
   rnLayout
   pass resizeStack
end resizeStack

-- Escape closes it
on rawKeyDown pKey
   if pKey is 65307 then
      close me
   else
      pass rawKeyDown
   end if
end rawKeyDown

-- The arrow keys go from one release to the next (the search box keeps
-- its own; and so does a field in another window, the Message Box's say)
on arrowKey pKey
   if word 1 of the name of the target is "field" and the short name of the target is not "idx" then
      pass arrowKey
   end if
   switch pKey
      case "up"
      case "left"
         rnStep -1
         break
      case "down"
      case "right"
         rnStep 1
         break
      default
         pass arrowKey
   end switch
end arrowKey

-- The kit is this stack's behavior (see revLearnKit)
private command rnUseKit
   local tKit
   if the behavior of me is not empty then
      exit rnUseKit
   end if
   if there is no stack "revLearnKit" then
      put rnToolset() & "/palettes/learn/revlearnkit.livecodescript" into tKit
      -- (naming the file loads the stack)
      get the short name of stack tKit
   end if
   set the behavior of me to the long id of stack "revLearnKit"
end rnUseKit

-- The IDE's Toolset folder and its own folder (where .version is), from
-- this stack's file: the same in a source tree, an installed IDE and the
-- web IDE
private function rnToolset
   set the itemDelimiter to slash
   return item 1 to -4 of the filename of me
end rnToolset

private function rnRoot
   set the itemDelimiter to slash
   return item 1 to -5 of the filename of me
end rnRoot

-- In the middle of the screen, a little above it
private command rnPlace
   local tScreen, tError
   put the screenRect into tScreen
   set the rect of me to 0, 0, kWidth, kHeight
   set the loc of me to (item 1 of tScreen + item 3 of tScreen) div 2, \
         max(item 2 of tScreen + kHeight div 2 + 30, (item 2 of tScreen + item 4 of tScreen) div 2 - 20)
   if there is a stack "revWebIDELibrary" then
      try
         revWebIDEKeepOnPage the long id of me, empty, true
      catch tError
      end try
   end if
   rnLayout
end rnPlace

################################################################################
#
# Reading the notes
#

-- A notes file: packaging's copy (palettes/updates/notes), or, in a
-- source tree, the repository's own beside ide/ (a folder with an engine
-- folder too, so that an installed IDE never reads a stranger's file of
-- the same name from the folder it is installed in)
private function rnFile pName
   local tPath
   put rnToolset() & "/palettes/updates/notes/" & pName into tPath
   if there is a file tPath then
      return tPath
   end if
   set the itemDelimiter to slash
   put rnRoot() into tPath
   if the last item of tPath is "ide" then
      put item 1 to -2 of tPath into tPath
      if there is a folder (tPath & "/engine") and there is a file (tPath & "/" & pName) then
         return tPath & "/" & pName
      end if
   end if
   return empty
end rnFile

private function rnReadFile pName
   local tPath, tText, tError
   put rnFile(pName) into tPath
   if tPath is empty then
      return empty
   end if
   try
      put textDecode(url ("binfile:" & tPath), "utf-8") into tText
   catch tError
      return empty
   end try
   replace numToCodepoint(13) & numToCodepoint(10) with return in tText
   replace numToCodepoint(13) with return in tText
   return tText
end rnReadFile

private command rnLoad
   local tText, tLine, tCount, tIndex, tRest, tVersion, tIn, tBody, tTitle, tPos, tFile
   put empty into sRel
   put 0 into sRelCount
   put empty into sNotes
   put empty into sHistory
   put empty into sRunning
   put rnRoot() & "/.version" into tFile
   if there is a file tFile then
      put word 1 to -1 of line 1 of textDecode(url ("binfile:" & tFile), "utf-8") into sRunning
   end if

   -- CHANGELOG.md: "## <version> (<date>[, pre-release])", then a line
   -- "- " each change
   put rnReadFile("CHANGELOG.md") into tText
   put 0 into tCount
   repeat for each line tLine in tText
      if tLine begins with "## " then
         add 1 to tCount
         put word 2 of tLine into sRel[tCount]["version"]
         put word 3 to -1 of tLine into tRest
         if char 1 of tRest is "(" then
            delete char 1 of tRest
         end if
         if the last char of tRest is ")" then
            delete the last char of tRest
         end if
         put word 1 to -1 of item 1 of tRest into sRel[tCount]["date"]
         put tRest contains "pre-release" into sRel[tCount]["pre"]
         put empty into sRel[tCount]["items"]
      else if tCount > 0 and tLine begins with "- " then
         put char 3 to -1 of tLine & return after sRel[tCount]["items"]
      else if tCount > 0 and tLine begins with "  " and word 1 of tLine is not empty \
            and sRel[tCount]["items"] is not empty then
         -- (a change written over more than one line)
         delete the last char of sRel[tCount]["items"]
         put space & word 1 to -1 of tLine & return after sRel[tCount]["items"]
      end if
   end repeat
   repeat with tIndex = 1 to tCount
      if the last char of sRel[tIndex]["items"] is return then
         delete the last char of sRel[tIndex]["items"]
      end if
   end repeat
   put tCount into sRelCount

   -- The README's notes: "#### <version>: <title>", up to the next heading
   -- of that level or above
   put rnReadFile("README.md") into tText
   put false into tIn
   repeat for each line tLine in tText
      if tLine begins with "#" and (tLine begins with "#### " or not (tLine begins with "#####")) \
            and word 1 of tLine is among the items of "#,##,###,####" then
         if tIn then
            rnKeepNotes tVersion, tTitle, tBody
         end if
         put false into tIn
         if tLine begins with "#### " then
            put word 2 of tLine into tVersion
            if the last char of tVersion is ":" then
               delete the last char of tVersion
               put offset(":", tLine) into tPos
               put word 1 to -1 of (char (tPos + 1) to -1 of tLine) into tTitle
               put empty into tBody
               put true into tIn
            end if
         end if
      else if tIn then
         put tLine & return after tBody
      end if
   end repeat
   if tIn then
      rnKeepNotes tVersion, tTitle, tBody
   end if

   -- HISTORY.md, without its title
   put rnReadFile("HISTORY.md") into tText
   if line 1 of tText begins with "# " then
      delete line 1 of tText
   end if
   put tText into sHistory
end rnLoad

private command rnKeepNotes pVersion, pTitle, pBody
   if pVersion is empty or sNotes[pVersion]["title"] is not empty then
      exit rnKeepNotes
   end if
   put pTitle into sNotes[pVersion]["title"]
   put pBody into sNotes[pVersion]["body"]
end rnKeepNotes

-- The number of the release pVersion, if the changelog has it
private function rnFindRelease pVersion
   local tIndex
   if pVersion is empty then
      return empty
   end if
   repeat with tIndex = 1 to sRelCount
      if sRel[tIndex]["version"] is pVersion then
         return tIndex
      end if
   end repeat
   return empty
end rnFindRelease

-- "2026-10-19" as "19 October 2026", or as "19 Oct" (pShort)
private function rnDate pDate, pShort
   local tMonths, tMonth, tYear, tDay
   set the itemDelimiter to "-"
   if the number of items of pDate is not 3 or item 2 of pDate is not an integer \
         or item 3 of pDate is not an integer then
      return pDate
   end if
   put item 1 of pDate into tYear
   put item 2 of pDate + 0 into tMonth
   put item 3 of pDate + 0 into tDay
   put "January,February,March,April,May,June,July,August,September,October,November,December" into tMonths
   set the itemDelimiter to comma
   if tMonth < 1 or tMonth > 12 then
      return pDate
   end if
   put item tMonth of tMonths into tMonth
   if pShort then
      return tDay && char 1 to 3 of tMonth
   end if
   return tDay && tMonth && tYear
end rnDate

################################################################################
#
# Building the window
#

private command rnBuild
   local tSaved, tObj
   if there is a field "page" of me then
      exit rnBuild
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   set the label of me to "Release Notes"
   -- (no smaller than it opens: what it shows is laid out for that)
   set the resizable of me to true
   set the minWidth of me to kWidth
   set the minHeight of me to kHeight
   set the destroyStack of me to true
   set the rect of me to 0, 0, kWidth, kHeight
   set the backgroundColor of me to lkColor("bg")
   set the linkColor of me to lkAccentInk(lkColor("violet"))
   set the linkHiliteColor of me to lkAccentInk(lkColor("pink"))
   set the linkVisitedColor of me to lkAccentInk(lkColor("violet"))
   set the underlineLinks of me to false
   rnBuildSide
   rnBuildHeader

   -- The page
   put lkBox("pageBg", lkR(kSide + kPad - 8, kHeaderHeight + 4, kWidth - kPad + 8, kHeight - kFootHeight), \
         lkColor("panel"), 16, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel("page", lkR(kSide + kPad + 8, kHeaderHeight + 18, kWidth - kPad - 18, kHeight - kFootHeight - 12), \
         empty, 13, lkColor("soft"), empty) into tObj
   set the textHeight of tObj to 19
   set the vScrollbar of tObj to true
   if lkDark() then
      lkScroller "pageThumb", tObj, "148,163,184", 45, empty
   else
      lkScroller "pageThumb", tObj, "100,116,139", 45, empty
   end if
   lkScroller "idxThumb", the long id of field "idx", "255,255,255", 70, empty

   -- The foot
   get lkButton("classic", kSide + kPad - 8, kHeight - kFootHeight + 16, 34, "Classic notes", "book-open", "ghost", \
         lkColor("violet"), empty, "classic", 0)
   get lkButton("close", kWidth - kPad + 8 - 110, kHeight - kFootHeight + 16, 34, "Close", empty, "primary", \
         lkColor("violet"), empty, "close", 110)
   unlock messages
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end rnBuild

-- Puts what rnBuild made where the window's size wants it: the sidebar
-- and the page as tall as the window, the page as wide, and the buttons
-- at its edges (each where rnBuild puts it at 920 by 640)
private command rnLayout
   local tW, tH, tSaved
   if there is no field "page" of me then
      exit rnLayout
   end if
   put the width of me into tW
   put the height of me into tH
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   set the rect of graphic "sideBg" to 0, 0, kSide, tH
   lkGradientPoints the long id of graphic "sideBg", "0,0", "0," & tH
   rnStretch the long id of field "idx", kSide - 8, tH - 54
   set the top of field "navCount" to tH - 42 - kTextInset
   rnStretch the long id of field "hdrTitle", tW - 200, empty
   rnStretch the long id of field "hdrTag", tW - 200, empty
   set the left of group "github" to tW - kPad - 134
   lkRestAt "github"
   rnStretch the long id of graphic "pageBg", tW - kPad + 8, tH - kFootHeight
   rnStretch the long id of field "page", tW - kPad - 18, tH - kFootHeight - 12
   rnMeasure the long id of field "page"
   set the top of group "classic" to tH - kFootHeight + 16
   lkRestAt "classic"
   set the topLeft of group "close" to tW - kPad + 8 - 110, tH - kFootHeight + 16
   lkRestAt "close"
   lkScrollSync "pageThumb"
   lkScrollSync "idxThumb"
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end rnLayout

-- Keeps field pObj's lines no wider than kMeasure, from its left (under
-- the header's text), and clear of its scroll thumb
private command rnMeasure pObj
   set the leftMargin of pObj to 0
   set the rightMargin of pObj to max(kThumbRoom, the width of pObj - kMeasure)
end rnMeasure

-- Moves pObj's right and bottom edges (empty keeps one), not its top left
private command rnStretch pObj, pRight, pBottom
   local tRect
   put the rect of pObj into tRect
   if pRight is not empty then
      put pRight into item 3 of tRect
   end if
   if pBottom is not empty then
      put pBottom into item 4 of tRect
   end if
   set the rect of pObj to tRect
end rnStretch

private command rnBuildSide
   local tObj
   put lkBox("sideBg", lkR(0, 0, kSide, kHeight), lkColor("side"), 0, empty) into tObj
   lkGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", "0," & kHeight
   -- The mark
   put lkBox("sideMark", "20,22,56,58", lkColor("flame"), 22, empty) into tObj
   lkGradient tObj, "255,139,0|219,39,119", "20,22", "56,58"
   lkGlow tObj, "255,139,0", 16, 110
   get lkIcon("sideMarkIcon", "newspaper", "255,255,255", "28,30,48,50", empty)
   get lkLabel("sideTitle", lkR(66, 21, kSide - 8, 45), "Release notes", 19, "255,255,255", empty)
   get lkLabel("sideSub", lkR(66, 45, kSide - 8, 61), "Every change, by release", 11, lkColor("muted"), empty)

   -- Search
   put lkBox("searchBg", lkR(14, 80, kSide - 14, 114), lkColor("side2"), 17, empty) into tObj
   lkBorder tObj, lkColor("sideLine")
   get lkIcon("searchIcon", "search", lkColor("muted"), "27,89,43,105", empty)
   get lkLabel("searchHint", lkR(52, 88, kSide - 44, 106), "Search the changes", 13, "100,116,139", empty)
   set the dontWrap of field "searchHint" to true
   put lkInput("search", lkR(52, 88, kSide - 44, 106), empty, 13, empty) into tObj
   set the textColor of tObj to "255,255,255"
   set the hiliteColor of tObj to lkColor("sideLine")
   get lkGroup("searchClear", lkR(kSide - 42, 85, kSide - 18, 109), empty)
   get lkBox("searchClear_bg", lkR(kSide - 42, 85, kSide - 18, 109), lkColor("sideLine"), 12, "searchClear")
   get lkIcon("searchClear_icon", "x", lkColor("sideInk"), lkR(kSide - 37, 90, kSide - 23, 104), "searchClear")
   rnLiveFade "searchClear", "clear"
   hide group "searchClear"

   -- The index: a release a line
   put lkLabel("idx", lkR(8, 126, kSide - 8, kHeight - 54), empty, 13, lkColor("sideInk"), empty) into tObj
   set the listBehavior of tObj to true
   set the autoHilite of tObj to true
   -- (its selected line white on the hilite, in the dark appearance too)
   lkSelectedInk tObj, "255,255,255"
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to kIndexLine
   set the margins of tObj to "8,2,2,2"
   set the threeDHilite of tObj to false
   set the tabStops of tObj to "20,148"
   set the hiliteColor of tObj to lkMix(lkColor("side2"), lkColor("violet"), 0.45)

   get lkLabel("navCount", lkR(0, kHeight - 42, kSide, kHeight - 26), empty, 12, lkColor("muted"), empty, "center")
end rnBuildSide

-- A small thing that lights up by showing its box more
private command rnLiveFade pName, pAction
   local tLook
   put pName & "_bg" into tLook["bg"]
   put 60 into tLook["blend0"]
   put 0 into tLook["blend1"]
   set the blendLevel of graphic (pName & "_bg") to 60
   lkLive pName, "side", pAction, tLook
end rnLiveFade

private command rnBuildHeader
   local tObj
   put lkLabel("hdrTitle", lkR(kSide + kPad, 16, kWidth - 200, 50), empty, 26, lkColor("ink"), empty) into tObj
   set the dontWrap of tObj to true
   put lkLabel("hdrTag", lkR(kSide + kPad, 52, kWidth - 200, 70), empty, 13, lkColor("soft"), empty) into tObj
   set the dontWrap of tObj to true
   put lkBox("hdrLine", lkR(kSide + kPad, 78, kSide + kPad + 56, 81), lkAccentInk(lkColor("violet")), 3, empty) into tObj
   get lkButton("github", kWidth - kPad - 134, 24, 32, "On GitHub", "external-link", "ghost", lkColor("violet"), \
         empty, "github", 134)
end rnBuildHeader

################################################################################
#
# The sidebar
#

-- The search box's hint shows while it is empty, its clear button while
-- it is not
private command rnSyncSearch
   if field "search" is empty then
      show field "searchHint"
      hide group "searchClear"
   else
      hide field "searchHint"
      show group "searchClear"
   end if
end rnSyncSearch

-- How many of release pIndex's changes (and its notes' title and text)
-- have pTerm
private function rnMatches pIndex, pTerm
   local tCount, tLine, tVersion
   put 0 into tCount
   repeat for each line tLine in sRel[pIndex]["items"]
      if tLine contains pTerm then
         add 1 to tCount
      end if
   end repeat
   put sRel[pIndex]["version"] into tVersion
   if sNotes[tVersion]["title"] contains pTerm or sNotes[tVersion]["body"] contains pTerm then
      add 1 to tCount
   end if
   return tCount
end rnMatches

-- The index: every release, or those the search finds, and the history
private command rnFillIndex
   local tHtml, tCount, tIndex, tTerm, tFound, tVersion, tMark, tInk, tMatches, tTotal
   put empty into sIndexMap
   put word 1 to -1 of sSearch into tTerm
   put 0 into tCount
   put 0 into tTotal
   repeat with tIndex = 1 to sRelCount
      put empty into tMatches
      if tTerm is not empty then
         put rnMatches(tIndex, tTerm) into tFound
         if tFound is 0 then
            next repeat
         end if
         add tFound to tTotal
         put tFound into tMatches
      end if
      add 1 to tCount
      put tIndex into sIndexMap[tCount]
      put sRel[tIndex]["version"] into tVersion
      if tVersion is sRunning then
         put "<font color=" & quote & lkHex(lkColor("emerald")) & quote & ">" & numToCodepoint(9679) & "</font>" into tMark
      else if not sRel[tIndex]["pre"] then
         put "<font color=" & quote & "#fbbf24" & quote & ">" & numToCodepoint(9733) & "</font>" into tMark
      else
         put empty into tMark
      end if
      if sRel[tIndex]["pre"] then
         put lkEscape(tVersion) into tInk
      else
         put "<font color=" & quote & "#ffffff" & quote & "><b>" & lkEscape(tVersion) & "</b></font>" into tInk
      end if
      if tMatches is empty then
         put rnDate(sRel[tIndex]["date"], true) into tMatches
      end if
      put "<p>" & tMark & tab & tInk & tab & "<font color=" & quote & "#64748b" & quote & ">" & \
            lkEscape(tMatches) & "</font></p>" after tHtml
   end repeat
   if tTerm is empty and sHistory is not empty then
      add 1 to tCount
      put "history" into sIndexMap[tCount]
      put "<p><font color=" & quote & "#64748b" & quote & ">" & numToCodepoint(8617) & "</font>" & tab & \
            "<font color=" & quote & "#94a3b8" & quote & "><i>Before 0.0.2</i></font></p>" after tHtml
   end if
   lock screen
   set the htmlText of field "idx" to tHtml
   unlock screen
   if tTerm is not empty then
      if tCount is 0 then
         put "Nothing found" into field "navCount"
      else if tCount is 1 then
         put "Found in 1 release" into field "navCount"
      else
         put "Found in" && tCount && "releases" into field "navCount"
      end if
   else if sRelCount is 0 then
      put "No changelog in this copy" into field "navCount"
   else if sRelCount is 1 then
      put "1 release" into field "navCount"
   else
      put sRelCount && "releases" into field "navCount"
   end if
   rnSyncIndex
end rnFillIndex

-- The index marks the page in front, and scrolls to it
private command rnSyncIndex
   local tLine, tKey, tTop
   put empty into tLine
   repeat for each key tKey in sIndexMap
      if sIndexMap[tKey] is sPage then
         put tKey into tLine
         exit repeat
      end if
   end repeat
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
end rnSyncIndex

on mouseUp pButton
   if word 1 of the name of the target is "field" and the short name of the target is "idx" then
      if pButton is 1 then
         rnIndexClick
      end if
      exit mouseUp
   end if
   pass mouseUp
end mouseUp

private command rnIndexClick
   local tLine
   put the hilitedLine of field "idx" into tLine
   if tLine is empty or sIndexMap[tLine] is empty then
      rnSyncIndex
      exit rnIndexClick
   end if
   rnGo sIndexMap[tLine]
end rnIndexClick

on textChanged
   if the short name of the target is "search" then
      put the text of field "search" into sSearch
      rnSyncSearch
      rnFillIndex
      -- (the first release found, when the one in front has none of it)
      if word 1 to -1 of sSearch is not empty and sIndexMap[1] is not empty \
            and rnIndexOf(sPage) is empty then
         put sIndexMap[1] into sPage
         rnSyncIndex
      end if
      rnRender
   end if
   pass textChanged
end textChanged

private function rnIndexOf pPage
   local tKey
   repeat for each key tKey in sIndexMap
      if sIndexMap[tKey] is pPage then
         return tKey
      end if
   end repeat
   return empty
end rnIndexOf

on returnInField
   if the short name of the target is "search" then
      if sIndexMap[1] is not empty then
         rnGo sIndexMap[1]
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
         put empty into field "search"
         put empty into sSearch
         rnSyncSearch
         rnFillIndex
         rnRender
         break
      case "github"
         rnOpenGitHub
         break
      case "classic"
         rnOpenClassic
         break
      case "close"
         close me
         break
   end switch
end lkAction

-- Goes to a page: a release's number, or "history"
private command rnGo pPage
   local tSaved
   if pPage is empty or pPage is sPage then
      rnSyncIndex
      exit rnGo
   end if
   put pPage into sPage
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen for visual effect in rect lkR(kSide, 0, the width of me, the height of me)
   rnRender
   rnSyncIndex
   unlock screen with visual effect "dissolve" very fast
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end rnGo

-- The page above (-1) or below (1) in the index
private command rnStep pBy
   local tLine
   put rnIndexOf(sPage) into tLine
   if tLine is empty then
      put 1 into tLine
   else
      add pBy to tLine
   end if
   if sIndexMap[tLine] is not empty then
      rnGo sIndexMap[tLine]
   end if
end rnStep

-- The release in front on GitHub (its tag's page), or HISTORY.md there
private command rnOpenGitHub
   local tUrl, tError
   if sPage is "history" then
      put kRepoUrl & "/blob/main/HISTORY.md" into tUrl
   else if sPage is an integer and sRel[sPage]["version"] is not empty then
      put kRepoUrl & "/releases/tag/v" & sRel[sPage]["version"] into tUrl
   else
      put kRepoUrl & "/releases" into tUrl
   end if
   try
      launch url tUrl
   catch tError
   end try
end rnOpenGitHub

-- OpenXTalk Lite's update history, in its own window, as before
private command rnOpenClassic
   local tPath, tError
   put rnToolset() & "/palettes/updates/ReleaseNotes.oxtstack" into tPath
   if there is no file tPath then
      exit rnOpenClassic
   end if
   try
      open stack tPath
   catch tError
   end try
end rnOpenClassic

on linkClicked pLink
   local tError
   if pLink begins with "rel:" then
      rnGo rnFindRelease(char 5 to -1 of pLink)
      exit linkClicked
   end if
   try
      if pLink contains "://" then
         launch url pLink
      end if
   catch tError
   end try
end linkClicked

################################################################################
#
# The page
#

private command rnRender
   local tSaved, tHtml, tTerm
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   put word 1 to -1 of sSearch into tTerm
   lock screen
   if sPage is "history" then
      put "Before 0.0.2" into field "hdrTitle"
      put "LiveCode Community, OpenXTalk Lite, and how OXT-Beyond began" into field "hdrTag"
      put rnBlocksHtml(sHistory, "HISTORY.md", empty) into tHtml
   else if sPage is an integer and sRel[sPage]["version"] is not empty then
      put sRel[sPage]["version"] into field "hdrTitle"
      put rnTagLine(sPage) into field "hdrTag"
      put rnReleaseHtml(sPage, tTerm) into tHtml
   else
      put "Release notes" into field "hdrTitle"
      put empty into field "hdrTag"
      put rnMissingHtml(tTerm) into tHtml
   end if
   set the htmlText of field "page" to tHtml
   set the vScroll of field "page" to 0
   lkScrollSync "pageThumb"
   lkEllipsize the long id of field "hdrTag"
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end rnRender

-- "19 October 2026, Pre-release, 16 changes", the dots between them
private function rnTagLine pIndex
   local tLine, tCount, tDot
   put "  " & numToCodepoint(0x00B7) & "  " into tDot
   put rnDate(sRel[pIndex]["date"], false) into tLine
   if sRel[pIndex]["pre"] then
      put tDot & "Pre-release" after tLine
   else
      put tDot & "Release" after tLine
   end if
   put the number of lines of sRel[pIndex]["items"] into tCount
   if tCount is 1 then
      put tDot & "1 change" after tLine
   else
      put tDot & tCount && "changes" after tLine
   end if
   if sRel[pIndex]["version"] is sRunning then
      put tDot & "your version" after tLine
   end if
   return tLine
end rnTagLine

private function rnReleaseHtml pIndex, pTerm
   local tHtml, tVersion, tTitle, tLine, tPr, tBody, tBullet
   put sRel[pIndex]["version"] into tVersion
   if sNotes[tVersion]["title"] is not empty then
      put sNotes[tVersion]["title"] into tTitle
      put toUpper(char 1 of tTitle) into char 1 of tTitle
      put rnHeadingHtml(tTitle, 17, lkAccentInk(lkColor("violet")), pTerm) after tHtml
      put rnBlocksHtml(sNotes[tVersion]["body"], "README.md", pTerm) after tHtml
      put "<p></p>" & rnHeadingHtml("Every change", 15, lkColor("ink"), empty) after tHtml
   end if
   put "<p><font size=" & quote & "12" & quote & " color=" & quote & lkHex(lkColor("muted")) & quote & ">" & \
         "A line a commit, in the order they were merged; the number is the pull request that brought it in." & \
         "</font></p>" after tHtml
   put rnBulletOpen(0) & numToCodepoint(8226) into tBullet
   repeat for each line tLine in sRel[pIndex]["items"]
      put empty into tPr
      -- (" (#123)" at the end: a link to the pull request)
      if matchText(tLine, "^(.*\S)\s*\(#([0-9]+)\)\s*$", tBody, tPr) then
         put tBody into tLine
      end if
      put tBullet & tab & rnInline(tLine, "README.md", pTerm) after tHtml
      if tPr is not empty then
         put "  <a href=" & quote & kRepoUrl & "/pull/" & tPr & quote & ">#" & tPr & "</a>" after tHtml
      end if
      put "</p>" after tHtml
   end repeat
   if sRel[pIndex]["items"] is empty then
      put "<p>The changelog lists no changes for this release.</p>" after tHtml
   end if
   return tHtml
end rnReleaseHtml

private function rnMissingHtml pTerm
   if pTerm is not empty and sRelCount > 0 then
      return "<p>Nothing in the changelog has " & numToCodepoint(0x201C) & lkEscape(pTerm) & numToCodepoint(0x201D) & ".</p>"
   end if
   return "<p>The changelog is not in this copy of the IDE. Every release and its changes are on " & \
         "<a href=" & quote & kRepoUrl & "/releases" & quote & ">GitHub</a>, and Classic notes " & \
         "shows OpenXTalk Lite's update history.</p>"
end rnMissingHtml

private function rnHeadingHtml pText, pSize, pColor, pTerm
   return "<p spacebelow=" & quote & "4" & quote & "><font size=" & quote & pSize & quote & " color=" & quote & \
         lkHex(pColor) & quote & "><b>" & rnInline(pText, "README.md", pTerm) & "</b></font></p>"
end rnHeadingHtml

-- A list item's paragraph, its bullet hanging in the margin
private function rnBulletOpen pDepth
   local tLeft
   put 18 + 18 * pDepth into tLeft
   return "<p leftindent=" & quote & tLeft & quote & " firstindent=" & quote & "-14" & quote & \
         " tabstops=" & quote & tLeft & quote & " spacebelow=" & quote & "3" & quote & ">"
end rnBulletOpen

-- Markdown as htmlText: headings, paragraphs, lists, quotes, tables and
-- code blocks (pDoc is the file its relative links are relative to)
private function rnBlocksHtml pText, pDoc, pTerm
   local tHtml, tLine, tPara, tKind, tDepth, tFence, tLevel, tIndent, tMark, tCode
   put false into tFence
   put empty into tPara
   put empty into tKind
   repeat for each line tLine in pText
      if word 1 of tLine begins with "```" then
         put rnFlush(tKind, tPara, tDepth, pDoc, pTerm) after tHtml
         put empty into tKind
         put not tFence into tFence
         next repeat
      end if
      if tFence then
         put "<p leftindent=" & quote & "12" & quote & "><font face=" & quote & rnCodeFont() & quote & " color=" & \
               quote & lkHex(lkColor("ink")) & quote & ">" & lkEscape(tLine) & "</font></p>" after tHtml
         next repeat
      end if
      if word 1 of tLine is empty then
         put rnFlush(tKind, tPara, tDepth, pDoc, pTerm) after tHtml
         put empty into tKind
         next repeat
      end if
      put 0 into tIndent
      repeat while char tIndent + 1 of tLine is space
         add 1 to tIndent
      end repeat
      put word 1 of tLine into tMark
      if char 1 of tLine is "#" and tMark is among the items of "#,##,###,####,#####,######" then
         put rnFlush(tKind, tPara, tDepth, pDoc, pTerm) after tHtml
         put empty into tKind
         put the number of chars of tMark into tLevel
         if tHtml is not empty then
            put "<p></p>" after tHtml
         end if
         if tLevel <= 2 then
            put rnHeadingHtml(word 2 to -1 of tLine, 17, lkAccentInk(lkColor("violet")), pTerm) after tHtml
         else
            put rnHeadingHtml(word 2 to -1 of tLine, 14, lkColor("ink"), pTerm) after tHtml
         end if
      else if tMark is among the items of "-,*,+" or (the last char of tMark is "." and char 1 to -2 of tMark is an integer) then
         put rnFlush(tKind, tPara, tDepth, pDoc, pTerm) after tHtml
         put "item" into tKind
         put min(2, tIndent div 2) into tDepth
         if tMark is among the items of "-,*,+" then
            put empty into tCode
         else
            put tMark into tCode
         end if
         put tCode & numToCodepoint(1) & word 2 to -1 of tLine into tPara
      else if char 1 of tLine is "|" then
         put rnFlush(tKind, tPara, tDepth, pDoc, pTerm) after tHtml
         put empty into tKind
         -- (a table: its rows as they are written, but for the line under
         -- its head)
         if not matchText(tLine, "^\s*\|[\s:|-]+\|\s*$") then
            put "<p><font face=" & quote & rnCodeFont() & quote & " size=" & quote & "11" & quote & ">" & \
                  lkEscape(word 1 to -1 of tLine) & "</font></p>" after tHtml
         end if
      else if char 1 of tLine is ">" then
         if tKind is not "quote" then
            put rnFlush(tKind, tPara, tDepth, pDoc, pTerm) after tHtml
            put "quote" into tKind
            put empty into tPara
         end if
         put space & word 1 to -1 of (char (offset(">", tLine) + 1) to -1 of tLine) after tPara
      else if tKind is "item" or tKind is "para" or tKind is "quote" then
         -- (the paragraph or the list item goes on)
         put space & word 1 to -1 of tLine after tPara
      else
         put "para" into tKind
         put word 1 to -1 of tLine into tPara
      end if
   end repeat
   put rnFlush(tKind, tPara, tDepth, pDoc, pTerm) after tHtml
   return tHtml
end rnBlocksHtml

-- The htmlText of a paragraph, a list item or a quote that has ended
private function rnFlush pKind, pPara, pDepth, pDoc, pTerm
   local tMark, tText
   switch pKind
      case "para"
         return "<p spacebelow=" & quote & "8" & quote & ">" & rnInline(pPara, pDoc, pTerm) & "</p>"
      case "quote"
         return "<p leftindent=" & quote & "14" & quote & " spacebelow=" & quote & "8" & quote & "><i>" & \
               rnInline(word 1 to -1 of pPara, pDoc, pTerm) & "</i></p>"
      case "item"
         set the itemDelimiter to numToCodepoint(1)
         put item 1 of pPara into tMark
         put item 2 to -1 of pPara into tText
         if tMark is empty then
            if pDepth is 0 then
               put numToCodepoint(8226) into tMark
            else
               put numToCodepoint(9702) into tMark
            end if
         end if
         return rnBulletOpen(pDepth) & tMark & tab & rnInline(tText, pDoc, pTerm) & "</p>"
   end switch
   return empty
end rnFlush

-- Markdown within a line as htmlText: `code`, **bold**, *italic*,
-- [links](...) and plain text, the search term marked
private function rnInline pText, pDoc, pTerm
   local tOut, tRun, tPos, tLen, tChar, tEnd, tRest, tLabel, tUrl, tClose
   put the number of chars of pText into tLen
   put 1 into tPos
   repeat while tPos <= tLen
      put char tPos of pText into tChar
      put char tPos + 1 to tLen of pText into tRest
      if tChar is "`" then
         put offset("`", tRest) into tEnd
         if tEnd > 1 then
            put rnPlain(tRun, pTerm) after tOut
            put empty into tRun
            put "<font face=" & quote & rnCodeFont() & quote & " color=" & quote & lkHex(lkColor("ink")) & quote & \
                  " bgcolor=" & quote & rnCodeBack() & quote & ">" & lkEscape(char 1 to tEnd - 1 of tRest) & "</font>" after tOut
            add tEnd + 1 to tPos
            next repeat
         end if
      else if tChar is "*" and char 1 of tRest is "*" then
         put offset("**", char 2 to -1 of tRest) into tEnd
         if tEnd > 1 then
            put rnPlain(tRun, pTerm) after tOut
            put empty into tRun
            put "<b>" & rnInline(char 2 to tEnd of tRest, pDoc, pTerm) & "</b>" after tOut
            add tEnd + 3 to tPos
            next repeat
         end if
      else if tChar is "*" and char 1 of tRest is not space and char 1 of tRest is not empty then
         put offset("*", tRest) into tEnd
         if tEnd > 1 then
            put rnPlain(tRun, pTerm) after tOut
            put empty into tRun
            put "<i>" & rnInline(char 1 to tEnd - 1 of tRest, pDoc, pTerm) & "</i>" after tOut
            add tEnd + 1 to tPos
            next repeat
         end if
      else if tChar is "[" then
         put offset("](", tRest) into tEnd
         if tEnd > 1 then
            put offset(")", char tEnd + 2 to -1 of tRest) into tClose
            if tClose > 0 then
               put char 1 to tEnd - 1 of tRest into tLabel
               put char tEnd + 2 to tEnd + tClose of tRest into tUrl
               put rnPlain(tRun, pTerm) after tOut
               put empty into tRun
               put "<a href=" & quote & rnAttr(rnUrl(tUrl, pDoc)) & quote & ">" & rnInline(tLabel, pDoc, pTerm) & "</a>" after tOut
               add tEnd + tClose + 2 to tPos
               next repeat
            end if
         end if
      end if
      put tChar after tRun
      add 1 to tPos
   end repeat
   put rnPlain(tRun, pTerm) after tOut
   return tOut
end rnInline

-- Plain text, escaped, with the search term (not by case) marked
private function rnPlain pText, pTerm
   local tOut, tAt, tLen
   if pText is empty then
      return empty
   end if
   if pTerm is empty then
      return lkEscape(pText)
   end if
   put the number of chars of pTerm into tLen
   repeat
      put offset(pTerm, pText) into tAt
      if tAt is 0 then
         exit repeat
      end if
      put lkEscape(char 1 to tAt - 1 of pText) & "<font bgcolor=" & quote & rnMarkBack() & quote & ">" & \
            lkEscape(char tAt to tAt + tLen - 1 of pText) & "</font>" after tOut
      delete char 1 to tAt + tLen - 1 of pText
   end repeat
   return tOut & lkEscape(pText)
end rnPlain

-- Behind `code` on the page: a pale slate, and in the dark a slate a
-- little lighter than the panel, under the white ink
private function rnCodeBack
   if lkDark() then
      return lkHex(lkColor("line"))
   end if
   return "#eef2f7"
end rnCodeBack

-- Behind a word the search found: pale amber, and in the dark a deep
-- amber, under the white text
private function rnMarkBack
   if lkDark() then
      return "#92400e"
   end if
   return "#fde68a"
end rnMarkBack

-- A link of the repository's markdown, as a web address: its own files
-- and their headings are on GitHub
private function rnUrl pUrl, pDoc
   put word 1 of pUrl into pUrl
   if pUrl contains "://" or pUrl begins with "mailto:" then
      return pUrl
   end if
   if pUrl begins with "#" then
      return kRepoUrl & "/blob/main/" & pDoc & pUrl
   end if
   if pUrl begins with "./" then
      delete char 1 to 2 of pUrl
   end if
   return kRepoUrl & "/blob/main/" & pUrl
end rnUrl

private function rnAttr pText
   return lkEscape(pText)
end rnAttr

private function rnCodeFont
   local tFont
   put lkCodeFont() into tFont
   if tFont is empty then
      return "Courier New"
   end if
   return tFont
end rnCodeFont
