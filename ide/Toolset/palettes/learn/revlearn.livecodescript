script "revLearn"
-- OXT-Beyond: Learn, one window for the lessons, the guides and the
-- examples.
--
-- It is a place of OXT-Beyond Home (palettes/home/revhub.livecodescript):
-- the Help menu's How-to, Guides and Examples open Home there, and Home
-- hosts this stack as its window's behavior (the How-to, Guides and
-- Examples places; see "Hosted in Home" below). Opened on its own, as its
-- file can be, it is its own window as before. It has the look of Home and the web
-- tour, drawn by revLearnKit, which is its behavior: a dark sidebar with
-- the three places, a search box, an index and Back and Next; a header
-- with the page's title; and the page.
--
-- The lessons and the guides are Tom Perry's stacks, userguides.oxtstack
-- and allguides.oxtstack in palettes/userguides: a card a page, whose
-- text is in field "tLayout", in a little markup of his (<b>, <bu>, <u>,
-- <i>, <ln>, <code>, <tip>, <note>, <important>, <caution>, <img>,
-- <rimg>), which the classic stacks draw with tLayout's mouseLeave
-- handler. Learn reads a page from its stack each time it shows it, and
-- draws it in its own look. It never changes or saves those stacks, so a
-- page edited the classic way (shift-click the icon at the top left of
-- the classic window) shows here as it is, and Classic view opens the
-- page in its own stack. A stack Learn loaded, it takes out of memory
-- again when it closes, unless it is open.
--
-- The examples are the stacks the gallery lists (leExampleTable), with
-- who made each, from the stacks' own notes and THIRD-PARTY-NOTICES.md,
-- and the Stack Player's (tools/web-player/stacks), which packaging puts
-- in Resources/Examples/Showcase. A stack that is not in this copy of the
-- IDE is left out. An example Learn opened, it takes out of memory once
-- it is closed.
--
-- It is a script-only stack, so it keeps no controls: this script builds
-- them when it opens, and draws each page anew. The things on a page that
-- light up when the pointer is over them change colour only (they never
-- move), because the page scrolls. Its name begins with "rev", so the IDE
-- treats it as one of its own windows.

constant kSections = "lessons,guides,examples"
constant kSide = 248
constant kWidth = 1180
constant kHeight = 760
constant kMinWidth = 980
constant kMinHeight = 620
constant kHeaderHeight = 92
constant kPad = 40
constant kColumn = 760
constant kWide = 1060
constant kIndexLine = 26
constant kTextInset = 4

-- The place in front ("lessons", "guides" or "examples"), and by place:
-- the page in front (a card's number; the example last gone to), the
-- search text, the stack the pages are read from, whether Learn loaded
-- it, the pages' names, and each page's text once a search wanted it
local sSection, sPage, sSearch, sPath, sLoaded, sTitles, sTexts
-- The page each line of the index stands for
local sIndexMap
-- The text of each code block on the page in front, for Copy
local sCode
-- The window's size, the page's column (its left and width) and where
-- the next thing goes on the page
local sWidth, sHeight, sX, sColW, sY
-- The sidebar's highlight, sliding to the place in front
local sNavY, sNavTarget
-- The hero's lights, and when the toast goes
local sHero, sToastUntil
-- The examples: their table, and the top of each one's card in the
-- gallery at vScroll 0, and the gallery's search, pending; and the files
-- of the examples Learn opened
local sExamples, sCardTop, sSearchDue, sOpened
-- A relayout after a resize, pending; and where lePlace put the window
local sRelayout, sPlaced

################################################################################
#
# Opening and closing
#

-- Opens Learn at pSection (and, for the lessons and guides, page pPage),
-- or brings it to the front there
command revLearnShow pSection, pPage
   if pSection is not among the items of kSections then
      put "lessons" into pSection
   end if
   -- (OXT-Beyond Home, when the IDE has it, is where Learn opens now)
   -- (the stack's own kit may not be its behavior yet: the property is
   -- read, not lkHosted)
   if the cHubPlaces of me is empty and leOpenInHome(pSection, pPage) then
      exit revLearnShow
   end if
   if the mode of me is 0 then
      put pSection into sSection
      put pPage into sPage[pSection]
      modeless me
   else
      go me
      leShowSection pSection, pPage
   end if
end revLearnShow

on preOpenStack
   leUseKit
   -- (light or dark, as the desktop is: lkAppearanceChanged)
   get lkReadAppearance()
   leBuild
   lePlace
   -- (a script-only stack is made invisible when it is loaded)
   show me
end preOpenStack

on openStack
   lkStartTicking
   lkFollowAppearance
   if sSection is empty then
      put "lessons" into sSection
   end if
   leShowSection sSection, sPage[sSection]
   -- (on Linux a resizable window can open at its minimum size, whatever
   -- its rect was: once it is up, it goes where lePlace put it)
   send "leKeepPlace" to me in 250 milliseconds
end openStack

on leKeepPlace
   if the mode of me is 0 or sPlaced is empty then
      exit leKeepPlace
   end if
   if the rect of me is not sPlaced then
      set the rect of me to sPlaced
   end if
end leKeepPlace

-- Whether the IDE counts a stack, or one of its substacks, as changed
-- since it was saved. Learn takes no such stack out of memory: the IDE
-- asks about its changes when it quits, as File > Close and Remove From
-- Memory would ask before it took the stack out
private function leEdited pStack
   local tName
   if there is no stack "revIDELibrary" then
      return false
   end if
   repeat for each line tName in (the short name of pStack) & return & (the substacks of pStack)
      if tName is empty then
         next repeat
      end if
      dispatch function "revIDEStackIsEdited" to stack "revIDELibrary" with tName
      if the result is true then
         return true
      end if
   end repeat
   return false
end leEdited

on closeStack
   lkStopTicking
   if sRelayout is not empty then
      cancel sRelayout
      put empty into sRelayout
   end if
   leUnload
end closeStack

on resizeStack
   if the width of me is sWidth and the height of me is sHeight then
      pass resizeStack
   end if
   leLayout
   -- (the page's text wraps to its width: it is drawn again once the
   -- window stops changing size)
   if sRelayout is not empty then
      cancel sRelayout
   end if
   send "leRelayout" to me in 120 milliseconds
   put the result into sRelayout
   pass resizeStack
end resizeStack

-- The desktop switched between light and dark (revLearnKit): the window
-- is built again in the other colours, at its size, on the page it shows,
-- scrolled where it was (leSyncSide puts back what the search box held)
on lkAppearanceChanged
   local tRect, tScroll
   put the rect of me into tRect
   put the vScroll of group "body" of me into tScroll
   lock screen
   lkClear
   leBuild
   set the rect of me to tRect
   leLayout
   leShowSection sSection, sPage[sSection]
   set the vScroll of group "body" of me to tScroll
   unlock screen
end lkAppearanceChanged

on leRelayout
   put empty into sRelayout
   if the mode of me is 0 then
      exit leRelayout
   end if
   leRender
end leRelayout

-- The kit is this stack's behavior (see revLearnKit)
private command leUseKit
   local tKit
   if the behavior of me is not empty then
      exit leUseKit
   end if
   if there is no stack "revLearnKit" then
      put leFolder() & "/revlearnkit.livecodescript" into tKit
      -- (naming the file loads the stack)
      get the short name of stack tKit
   end if
   set the behavior of me to the long id of stack "revLearnKit"
end leUseKit

-- This stack's folder, the IDE's Toolset folder and the IDE's own folder
-- (where Resources is), from this stack's file: the same in a source
-- tree, an installed IDE and the web IDE
-- (hosted in Home, "me" is Home's window, whose file is elsewhere: the
-- file is this script's own stack's, revLearn)
private function leFolder
   set the itemDelimiter to slash
   return item 1 to -2 of the filename of stack "revLearn"
end leFolder

private function leToolset
   set the itemDelimiter to slash
   return item 1 to -4 of the filename of stack "revLearn"
end leToolset

private function leRoot
   set the itemDelimiter to slash
   return item 1 to -5 of the filename of stack "revLearn"
end leRoot

-- Below the menu bar, as large as the screen allows
private command lePlace
   local tScreen, tTop, tWidth, tHeight, tError
   put the screenRect into tScreen
   put item 2 of tScreen + 40 into tTop
   if there is a stack "revMenubar" and the visible of stack "revMenubar" then
      put max(tTop, the bottom of stack "revMenubar" + 44) into tTop
   end if
   put min(kWidth, item 3 of tScreen - item 1 of tScreen - 40) into tWidth
   put min(kHeight, item 4 of tScreen - tTop - 20) into tHeight
   put max(kMinWidth, tWidth) into tWidth
   put max(kMinHeight, tHeight) into tHeight
   if tTop + tHeight > item 4 of tScreen then
      put max(item 2 of tScreen + 31, item 4 of tScreen - tHeight) into tTop
   end if
   set the rect of me to 0, 0, tWidth, tHeight
   set the topLeft of me to max(item 1 of tScreen, (item 1 of tScreen + item 3 of tScreen - tWidth) div 2), tTop
   put the rect of me into sPlaced
   if there is a stack "revWebIDELibrary" then
      try
         revWebIDEKeepOnPage the long id of me, empty, true
      catch tError
      end try
   end if
   leLayout
end lePlace

-- Takes out of memory the stacks Learn loaded, unless they are open or
-- hold changes not saved (leEdited)
private command leUnload
   local tSection, tName, tError
   repeat for each item tSection in "lessons,guides"
      if sLoaded[tSection] is not true then
         next repeat
      end if
      put false into sLoaded[tSection]
      put leSectionInfo(tSection, "stack") into tName
      if tName is among the lines of the mainStacks and tName is not among the lines of the openStacks \
            and not leEdited(the long id of stack tName) then
         try
            -- (deleting a main stack takes it out of memory: its file
            -- stays as it is)
            delete stack tName
         catch tError
         end try
      end if
   end repeat
end leUnload

################################################################################
#
# Hosted in Home
#
-- OXT-Beyond Home (palettes/home/revhub.livecodescript) uses this stack as
-- its window's behavior for three of its places: How-to (the section
-- "lessons"), Guides and Examples. It sends these four messages, and the
-- window's own preOpenStack, openStack and closeStack never reach this
-- script (Home keeps them), so these do what those do here, but for the
-- window's place and size, which are Home's.

-- The section a place of Home's stands for, and the other way about
private function leSectionOf pPlace
   if pPlace is "howto" then
      return "lessons"
   end if
   if pPlace is among the items of kSections then
      return pPlace
   end if
   return "lessons"
end leSectionOf

private function lePlaceOf pSection
   if pSection is "lessons" then
      return "howto"
   end if
   return pSection
end lePlaceOf

-- How far down the sidebar's search and index are: below Home's five
-- places when hosted, where the three sections' list was otherwise
private function leSideShift
   if lkHosted() then
      return 62
   end if
   return 0
end leSideShift

-- Opens Home at the place a section is, if the IDE has Home; false when it
-- does not, or it failed
private function leOpenInHome pSection, pPage
   local tPath, tError
   put leToolset() & "/palettes/home/revhub.livecodescript" into tPath
   if there is no file tPath then
      return false
   end if
   try
      dispatch "revHubShow" to stack tPath with lePlaceOf(pSection), pPage
   catch tError
      return false
   end try
   return it is "handled"
end leOpenInHome

on revHubAttach pPlace, pPage
   local tSection
   put leSectionOf(pPlace) into tSection
   put tSection into sSection
   put pPage into sPage[tSection]
   leUseKit
   get lkReadAppearance()
   leBuild
   leLayout
end revHubAttach

on revHubStart pPlace, pPage
   lkStartTicking
   lkFollowAppearance
   leShowSection sSection, sPage[sSection]
end revHubStart

on revHubNavigate pPlace, pPage
   local tSection
   put leSectionOf(pPlace) into tSection
   if tSection is sSection and pPage is empty then
      exit revHubNavigate
   end if
   leShowSection tSection, pPage
end revHubNavigate

on revHubDetach
   lkStopTicking
   if sRelayout is not empty then
      cancel sRelayout
      put empty into sRelayout
   end if
   leUnload
end revHubDetach

################################################################################
#
# The three places
#

-- A place's name, icon, accent colour, the stack its pages come from, the
-- word for one of its pages, and who made it
private function leSectionInfo pSection, pWhat
   local tInfo
   switch pSection
      case "lessons"
         put "How-to|lightbulb|violet|userguides|Lesson|Lessons edited by Terry Little from LiveCode's " & \
               "community lessons, with lessons by Paul McClernan, collected by Tom Perry." into tInfo
         break
      case "guides"
         put "Guides|book-open-text|sky|allguides|Page|LiveCode's user guide (GPLv3), debranded for " & \
               "OpenXTalk and collected by Tom Perry." into tInfo
         break
      default
         put "Examples|layers|orange||Example|" into tInfo
   end switch
   set the itemDelimiter to "|"
   switch pWhat
      case "label"
         return item 1 of tInfo
      case "icon"
         return item 2 of tInfo
      case "accent"
         return lkColor(item 3 of tInfo)
      case "stack"
         return item 4 of tInfo
      case "unit"
         return item 5 of tInfo
      case "credit"
         return item 6 of tInfo
   end switch
   return empty
end leSectionInfo

-- Shows a place, at page pPage (its last one when empty)
command leShowSection pSection, pPage
   local tSaved
   if pSection is not among the items of kSections then
      exit leShowSection
   end if
   put pSection into sSection
   if lkHosted() then
      set the cHubPlace of me to lePlaceOf(pSection)
   end if
   if pSection is not "examples" then
      leLoad pSection
   end if
   if pPage is empty then
      put sPage[pSection] into pPage
   end if
   if pPage is empty or pPage is not an integer or pPage < 1 then
      put 1 into pPage
   end if
   if pSection is not "examples" and pPage > the number of lines of sTitles[pSection] then
      put 1 into pPage
   end if
   put pPage into sPage[pSection]
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen for visual effect in rect lkR(kSide, 0, sWidth, sHeight)
   leSyncSide
   leRender
   unlock screen with visual effect "dissolve" very fast
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end leShowSection

-- Loads the stack a place's pages come from, and reads their names
private command leLoad pSection
   local tPath, tName, tCount, tIndex, tTitles, tError
   put leToolset() & "/palettes/userguides/" & leSectionInfo(pSection, "stack") & ".oxtstack" into tPath
   put tPath into sPath[pSection]
   put empty into sTitles[pSection]
   if there is no file tPath then
      exit leLoad
   end if
   put leSectionInfo(pSection, "stack") into tName
   if sLoaded[pSection] is not true and tName is not among the lines of the mainStacks then
      put true into sLoaded[pSection]
   end if
   try
      -- (naming the file loads the stack, without opening it)
      put the number of cards of stack tPath into tCount
      repeat with tIndex = 1 to tCount
         put the short name of card tIndex of stack tPath & return after tTitles
      end repeat
      delete the last char of tTitles
   catch tError
      put empty into tTitles
   end try
   put tTitles into sTitles[pSection]
end leLoad

-- The text of a page, as its stack keeps it
private function leRead pSection, pPage
   local tText, tError
   try
      put the text of field "tLayout" of card pPage of stack sPath[pSection] into tText
   catch tError
      put empty into tText
   end try
   return tText
end leRead

-- A page's title: its card's name, without the spaces that indent it in
-- the guides' index
private function leTitle pSection, pPage
   local tTitle
   put word 1 to -1 of line pPage of sTitles[pSection] into tTitle
   -- (the guides were debranded from "LiveCode Script" to "XTalk Script")
   set the caseSensitive to true
   replace "XTalk" with "xTalk" in tTitle
   return tTitle
end leTitle

-- How deep a guides page is: its card's name is indented three spaces a
-- level
private function leLevel pSection, pPage
   local tName, tSpaces
   put line pPage of sTitles[pSection] into tName
   put 0 into tSpaces
   repeat while char tSpaces + 1 of tName is space
      add 1 to tSpaces
   end repeat
   return tSpaces div 3
end leLevel

-- The page named pName, if there is one (names are compared without
-- their indent, and not by case)
private function leFindPage pSection, pName
   local tIndex, tLine
   put word 1 to -1 of pName into pName
   put 0 into tIndex
   repeat for each line tLine in sTitles[pSection]
      add 1 to tIndex
      if word 1 to -1 of tLine is pName then
         return tIndex
      end if
   end repeat
   return empty
end leFindPage

################################################################################
#
# Building the window
#

private command leBuild
   local tSaved
   if there is a group "body" of me then
      exit leBuild
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   -- (hosted in Home, the window's title and size are Home's)
   if not lkHosted() then
      set the label of me to "Learn OXT-Beyond"
      set the resizable of me to true
      set the minWidth of me to kMinWidth
      set the minHeight of me to kMinHeight
      set the destroyStack of me to true
      set the rect of me to 0, 0, kWidth, kHeight
   end if
   set the backgroundColor of me to lkColor("bg")
   leBuildSide
   leBuildHeader
   get lkGroup("body", lkR(kSide, kHeaderHeight, kWidth, kHeight), empty)
   -- (the kit's slim thumbs, in place of the scrollbars)
   if lkDark() then
      lkScroller "bodyThumb", the long id of group "body", "148,163,184", 45, empty
   else
      lkScroller "bodyThumb", the long id of group "body", "100,116,139", 45, empty
   end if
   lkScroller "idxThumb", the long id of field "idx", "255,255,255", 70, empty
   leBuildToast
   unlock messages
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end leBuild

private command leBuildSide
   local tObj, tY, tSection
   put lkBox("sideBg", lkR(0, 0, kSide, kHeight), lkColor("side"), 0, empty) into tObj
   lkGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", "0," & kHeight
   if lkHosted() then
      -- Home's mark and its five places, of which the three sections are
      -- three; the search and the index go below them (leSideShift)
      get lkHubHead(kSide)
      put 84 into sNavY
   else
      -- The mark
      put lkBox("sideMark", "20,22,56,58", lkColor("violet"), 22, empty) into tObj
      lkGradient tObj, "124,58,237|219,39,119", "20,22", "56,58"
      lkGlow tObj, "168,85,247", 16, 110
      get lkIcon("sideMarkIcon", "graduation-cap", "255,255,255", "28,30,48,50", empty)
      get lkLabel("sideTitle", lkR(66, 21, kSide - 8, 45), "Learn", 19, "255,255,255", empty)
      get lkLabel("sideSub", lkR(66, 45, kSide - 8, 61), "Lessons, guides and examples", 11, lkColor("sideMuted"), empty)

      -- The three places
      put lkBox("navHi", lkR(10, 84, kSide - 10, 116), lkColor("side2"), 16, empty) into tObj
      lkBorder tObj, lkColor("sideLine")
      put lkBox("navBar", "10,91,14,109", lkColor("violet"), 4, empty) into tObj
      put 84 into tY
      put tY into sNavY
      repeat for each item tSection in kSections
         lkNavItem "nav_" & tSection, tY, 32, leSectionInfo(tSection, "label"), \
               leSectionInfo(tSection, "icon"), "section" && tSection, 14, kSide - 10
         add 36 to tY
      end repeat
   end if

   -- Search
   put leSideShift() into tY
   put lkBox("searchBg", lkR(14, 204 + tY, kSide - 14, 238 + tY), lkColor("side2"), 17, empty) into tObj
   lkBorder tObj, lkColor("sideLine")
   get lkIcon("searchIcon", "search", lkColor("sideMuted"), lkR(27, 213 + tY, 43, 229 + tY), empty)
   get lkLabel("searchHint", lkR(52, 212 + tY, kSide - 44, 230 + tY), "Search", 13, lkColor("sideMuted"), empty)
   set the dontWrap of field "searchHint" to true
   put lkInput("search", lkR(52, 212 + tY, kSide - 44, 230 + tY), empty, 13, empty) into tObj
   set the textColor of tObj to "255,255,255"
   set the hiliteColor of tObj to lkColor("sideLine")
   get lkGroup("searchClear", lkR(kSide - 42, 209 + tY, kSide - 18, 233 + tY), empty)
   get lkBox("searchClear_bg", lkR(kSide - 42, 209 + tY, kSide - 18, 233 + tY), lkColor("sideLine"), 12, "searchClear")
   get lkIcon("searchClear_icon", "x", lkColor("sideInk"), lkR(kSide - 37, 214 + tY, kSide - 23, 228 + tY), "searchClear")
   leLiveFade "searchClear", "clear"
   hide group "searchClear"

   -- The index
   put lkLabel("idx", lkR(8, 250 + tY, kSide - 8, kHeight - 116), empty, 13, lkColor("sideInk"), empty) into tObj
   set the listBehavior of tObj to true
   set the autoHilite of tObj to true
   -- (its selected line white on the hilite, in the dark appearance too)
   lkSelectedInk tObj, "255,255,255"
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to kIndexLine
   set the margins of tObj to "8,2,2,2"
   set the threeDHilite of tObj to false
   set the tabStops of tObj to 34

   -- Back, Next, and where you are
   get lkButton("back", 14, kHeight - 104, 32, "Back", "chevron-left", "dark", empty, empty, "go prev", 106)
   get lkButton("next", kSide - 120, kHeight - 104, 32, "Next", "chevron-right", "dark", empty, empty, "go next", 106)
   get lkLabel("navCount", lkR(0, kHeight - 60, kSide, kHeight - 44), empty, 12, lkColor("sideMuted"), empty, "center")
   get lkLabel("navKeys", lkR(0, kHeight - 43, kSide, kHeight - 27), "or use the arrow keys", 11, lkColor("sideMuted"), empty, "center")
end leBuildSide

-- A small thing that lights up by showing its box more
private command leLiveFade pName, pAction
   local tLook
   put pName & "_bg" into tLook["bg"]
   put 60 into tLook["blend0"]
   put 0 into tLook["blend1"]
   set the blendLevel of graphic (pName & "_bg") to 60
   lkLive pName, "side", pAction, tLook
end leLiveFade

private command leBuildHeader
   local tObj
   get lkGroup("hdr", lkR(kSide, 0, kWidth, kHeaderHeight), empty)
   put lkLabel("hdrTitle", lkR(kSide + kPad, 16, kWidth - 220, 52), empty, 26, lkColor("ink"), "hdr") into tObj
   set the dontWrap of tObj to true
   put lkLabel("hdrTag", lkR(kSide + kPad, 54, kWidth - 220, 72), empty, 13, lkColor("soft"), "hdr") into tObj
   set the dontWrap of tObj to true
   put lkBox("hdrLine", lkR(kSide + kPad, 78, kSide + kPad + 56, 81), lkColor("violet"), 3, "hdr") into tObj
   get lkButton("classic", kWidth - kPad - 150, 24, 32, "Classic view", "book-open", "ghost", lkColor("violet"), "hdr", "classic", 0, "side")
end leBuildHeader

-- A dark pill at the foot of the page, for a word on what just happened
private command leBuildToast
   local tObj
   get lkGroup("toast", lkR(0, 0, 400, 40), empty)
   put lkBox("toast_bg", lkR(0, 0, 400, 40), lkColor("side"), 20, "toast") into tObj
   lkShadow tObj, 18, 6, 40
   get lkIcon("toast_icon", "check", lkColor("emerald"), "16,12,32,28", "toast")
   put lkLabel("toast_label", "42,11,390,29", empty, 13, "255,255,255", "toast") into tObj
   set the dontWrap of tObj to true
   hide group "toast"
end leBuildToast

-- Places what moves with the window's size
private command leLayout
   local tW, tH, tObj, tSaved
   put the width of me into tW
   put the height of me into tH
   put tW into sWidth
   put tH into sHeight
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   set the rect of graphic "sideBg" to 0, 0, kSide, tH
   lkGradientPoints the long id of graphic "sideBg", "0,0", "0," & tH
   set the rect of field "idx" to 8, 246 + leSideShift(), kSide - 8, tH - 116
   set the top of group "back" to tH - 104
   lkRestAt "back"
   set the top of group "next" to tH - 104
   lkRestAt "next"
   set the top of field "navCount" to tH - 60 - kTextInset
   set the top of field "navKeys" to tH - 43 - kTextInset
   -- the column, in the middle of the page when the window is wide
   leColumn false
   set the rect of group "hdr" to kSide, 0, tW, kHeaderHeight
   -- (by rect: setting a width keeps the centre, which moved the left
   -- off the column whenever the window was narrower than kWidth)
   set the rect of field "hdrTitle" to sX, the top of field "hdrTitle", tW - 210, the bottom of field "hdrTitle"
   set the rect of field "hdrTag" to sX, the top of field "hdrTag", tW - 210, the bottom of field "hdrTag"
   set the left of graphic "hdrLine" to sX
   set the right of group "classic" to tW - kPad
   lkRestAt "classic"
   if the visible of group "hdr" then
      set the rect of group "body" to kSide, kHeaderHeight, tW, tH
   else
      set the rect of group "body" to kSide, 0, tW, tH
   end if
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end leLayout

-- The page's column: its left (sX) and width (sColW), narrower for
-- reading than for the galleries
private command leColumn pWide
   local tRoom
   put sWidth - kSide - 2 * kPad into tRoom
   if pWide then
      put min(kWide, tRoom) into sColW
   else
      put min(kColumn, tRoom) into sColW
   end if
   put kSide + kPad + (tRoom - sColW) div 2 into sX
end leColumn

################################################################################
#
# The sidebar
#

-- The sidebar shows the place in front: its tab lit, its accent, its
-- search and its index
private command leSyncSide
   local tAccent, tSection, tName
   put leSectionInfo(sSection, "accent") into tAccent
   if lkHosted() then
      -- (Home's places: this section's is lit)
      put lkHubSync(tAccent) into sNavTarget
   end if
   repeat for each item tSection in kSections
      put "nav_" & tSection into tName
      if there is not a group tName then
         next repeat
      end if
      if tSection is sSection then
         lkSetLook tName, "ink0", "255,255,255"
         lkIconInk the long id of image (tName & "_icon"), leSectionInfo(tSection, "icon"), lkMix(tAccent, "255,255,255", 0.35)
         put the top of group tName into sNavTarget
      else
         lkSetLook tName, "ink0", lkColor("sideInk")
         lkIconInk the long id of image (tName & "_icon"), leSectionInfo(tSection, "icon"), lkColor("sideInk")
      end if
   end repeat
   set the backgroundColor of graphic "navBar" to tAccent
   lkGlow the long id of graphic "navBar", tAccent, 10, 160
   set the hiliteColor of field "idx" to lkMix(lkColor("side2"), tAccent, 0.45)
   set the backgroundColor of graphic "hdrLine" to tAccent
   set the linkColor of me to lkAccentInk(tAccent)
   set the linkHiliteColor of me to lkAccentText(tAccent, 0.3)
   set the linkVisitedColor of me to lkAccentInk(tAccent)
   put "Search the" && toLower(leSectionInfo(sSection, "label")) into field "searchHint"
   put sSearch[sSection] into field "search"
   leSyncSearch
   leFillIndex
end leSyncSide

-- The search box's hint shows while it is empty, its clear button while
-- it is not
private command leSyncSearch
   if field "search" is empty then
      show field "searchHint"
      hide group "searchClear"
   else
      hide field "searchHint"
      show group "searchClear"
   end if
end leSyncSearch

-- The index: every page, or those the search finds
private command leFillIndex
   local tHtml, tLine, tCount, tIndex, tTerm, tLevel, tNumber, tLevels, tMatched
   put empty into sIndexMap
   put word 1 to -1 of sSearch[sSection] into tTerm
   put 0 into tCount
   if sSection is "examples" then
      leFillExamplesIndex tTerm
      exit leFillIndex
   end if
   put 0 into tIndex
   repeat for each line tLine in sTitles[sSection]
      add 1 to tIndex
      -- (a search finds pages: the first page, the contents, lists them all)
      if tTerm is not empty and (tIndex is 1 or not leMatches(tIndex, tTerm)) then
         next repeat
      end if
      add 1 to tCount
      put tIndex into sIndexMap[tCount]
      put 0 into tLevels[tCount]
      if sSection is "lessons" then
         if tIndex is 1 then
            put "<p><font color=" & quote & "#94a3b8" & quote & ">&#9733;</font>" & tab & "Start here</p>" after tHtml
         else if tIndex is 2 then
            put "<p><font color=" & quote & "#94a3b8" & quote & ">&#8226;</font>" & tab & lkEscape(leTitle(sSection, tIndex)) & "</p>" after tHtml
         else
            put format("%02d", tIndex - 2) into tNumber
            put "<p><font color=" & quote & "#94a3b8" & quote & ">" & tNumber & "</font>" & tab & lkEscape(leTitle(sSection, tIndex)) & "</p>" after tHtml
         end if
      else
         put leLevel(sSection, tIndex) into tLevel
         put tLevel into tLevels[tCount]
         if tIndex is 1 then
            put "<p><b>Start here</b></p>" after tHtml
         else if tLevel is 0 then
            put "<p><font color=" & quote & "#ffffff" & quote & "><b>" & lkEscape(leTitle(sSection, tIndex)) & "</b></font></p>" after tHtml
         else if tLevel is 1 then
            put "<p>" & lkEscape(leTitle(sSection, tIndex)) & "</p>" after tHtml
         else
            put "<p><font color=" & quote & "#cbd5e1" & quote & ">" & lkEscape(leTitle(sSection, tIndex)) & "</font></p>" after tHtml
         end if
      end if
   end repeat
   lock screen
   set the htmlText of field "idx" to tHtml
   if sSection is "guides" and tTerm is empty then
      repeat with tIndex = 1 to tCount
         if tLevels[tIndex] > 0 then
            set the leftIndent of line tIndex of field "idx" to 14 * tLevels[tIndex]
         end if
      end repeat
   end if
   leFitIndex
   unlock screen
   leSyncIndex
   if tTerm is not empty then
      if tCount is 1 then
         put "1 page found" into tMatched
      else
         put tCount && "pages found" into tMatched
      end if
      put tMatched into field "navCount"
   end if
end leFillIndex

-- A line of the index too long for the sidebar ends in an ellipsis, not
-- at the sidebar's edge (the page itself shows the whole title)
private command leFitIndex
   local tRoom, tLine, tMax
   -- the field's margins, and the scroller's thumb at its right
   put the width of field "idx" - 8 - 2 - 12 into tRoom
   repeat with tLine = 1 to the number of lines of field "idx"
      put tRoom - the leftIndent of line tLine of field "idx" into tMax
      if the formattedWidth of line tLine of field "idx" <= tMax then
         next repeat
      end if
      repeat while the formattedWidth of line tLine of field "idx" > tMax \
            and the number of chars of line tLine of field "idx" > 6
         delete the last char of line tLine of field "idx"
      end repeat
      delete the last char of line tLine of field "idx"
      repeat while the last char of line tLine of field "idx" is space
         delete the last char of line tLine of field "idx"
      end repeat
      put numToCodepoint(8230) after line tLine of field "idx"
   end repeat
end leFitIndex

-- The index marks the page in front, and scrolls to it
private command leSyncIndex
   local tLine, tKey, tCount, tTop
   put empty into tLine
   repeat for each key tKey in sIndexMap
      if sIndexMap[tKey] is sPage[sSection] then
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
   if word 1 to -1 of sSearch[sSection] is empty then
      put the number of lines of sTitles[sSection] into tCount
      if sSection is "examples" then
         put the number of lines of leExampleKeys() && "examples" into field "navCount"
      else if tCount is 0 then
         put "Not in this copy of the IDE" into field "navCount"
      else if sPage[sSection] is 1 then
         if sSection is "lessons" then
            put tCount - 2 && "lessons, and a foreword" into field "navCount"
         else
            put tCount - 1 && "pages" into field "navCount"
         end if
      else if sSection is "lessons" and sPage[sSection] > 2 then
         put "Lesson" && sPage[sSection] - 2 && "of" && tCount - 2 into field "navCount"
      else
         put leSectionInfo(sSection, "unit") && sPage[sSection] - 1 && "of" && tCount - 1 into field "navCount"
      end if
   end if
end leSyncIndex

-- Whether page pPage has pTerm in its title or its text
private function leMatches pPage, pTerm
   if leTitle(sSection, pPage) contains pTerm then
      return true
   end if
   if sTexts[sSection][pPage] is empty then
      put leRead(sSection, pPage) into sTexts[sSection][pPage]
      if sTexts[sSection][pPage] is empty then
         put space into sTexts[sSection][pPage]
      end if
   end if
   return sTexts[sSection][pPage] contains pTerm
end leMatches

on mouseUp pButton
   if word 1 of the name of the target is "field" and the short name of the target is "idx" then
      if pButton is 1 then
         leIndexClick
      end if
      exit mouseUp
   end if
   pass mouseUp
end mouseUp

private command leIndexClick
   local tLine, tTarget
   put the hilitedLine of field "idx" into tLine
   if tLine is empty then
      exit leIndexClick
   end if
   put sIndexMap[tLine] into tTarget
   if tTarget is empty then
      leSyncIndex
      exit leIndexClick
   end if
   if sSection is "examples" then
      leJumpTo tTarget
   else
      leGo tTarget
   end if
end leIndexClick

on textChanged
   if the short name of the target is "search" then
      put the text of field "search" into sSearch[sSection]
      leSyncSearch
      if sSection is "examples" then
         -- (the gallery is drawn again when the typing stops)
         if sSearchDue is not empty then
            cancel sSearchDue
         end if
         send "leSearchExamples" to me in 260 milliseconds
         put the result into sSearchDue
      else
         leFillIndex
      end if
   end if
   pass textChanged
end textChanged

on leSearchExamples
   local tSaved
   put empty into sSearchDue
   if the mode of me is 0 then
      exit leSearchExamples
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   leFillIndex
   leRender
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end leSearchExamples

on returnInField
   if the short name of the target is "search" then
      -- the first page found
      if sSection is not "examples" and sIndexMap[1] is not empty then
         leGo sIndexMap[1]
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

on arrowKey pKey
   -- (the search box keeps its arrow keys; and so does a field in another
   -- window, the Message Box's say)
   if word 1 of the name of the target is "field" then
      pass arrowKey
   end if
   switch pKey
      case "left"
         leGo "prev"
         break
      case "right"
         leGo "next"
         break
      default
         pass arrowKey
   end switch
end arrowKey

################################################################################
#
# What a click does
#

on lkAction pAction
   local tArg
   put word 2 to -1 of pAction into tArg
   switch word 1 of pAction
      case "section"
         if tArg is not sSection then
            leShowSection tArg
         end if
         break
      case "go"
         leGo tArg
         break
      case "copy"
         leCopy tArg
         break
      case "classic"
         leClassic
         break
      case "open"
         leOpenExample tArg, false
         break
      case "original"
         leOpenExample tArg, true
         break
      case "jump"
         leJumpTo tArg
         break
      case "pdf"
         leOpenGuidePdf
         break
      case "academy"
         leOpenAcademy
         break
      case "clear"
         put empty into field "search"
         put empty into sSearch[sSection]
         leSyncSearch
         if sSection is "examples" then
            leSearchExamples
         else
            leFillIndex
         end if
         break
   end switch
end lkAction

-- The xTalk Academy (palettes/academy), the course in coding for
-- beginners that the lessons' first page points to
private command leOpenAcademy
   local tPath
   if lkHosted() then
      revHubGo "academy"
      exit leOpenAcademy
   end if
   put leToolset() & "/palettes/academy/revacademy.livecodescript" into tPath
   if there is no file tPath then
      exit leOpenAcademy
   end if
   dispatch "revAcademyShow" to stack tPath
end leOpenAcademy

-- Goes to a page: next pushes left, back pushes right, a jump dissolves
command leGo pWhere
   local tCount, tPage, tEffect, tSaved
   if sSection is "examples" then
      leStepExample pWhere
      exit leGo
   end if
   put the number of lines of sTitles[sSection] into tCount
   put sPage[sSection] into tPage
   switch pWhere
      case "next"
         put "push left" into tEffect
         add 1 to tPage
         break
      case "prev"
         put "push right" into tEffect
         subtract 1 from tPage
         break
      default
         put "dissolve" into tEffect
         put pWhere into tPage
   end switch
   if tPage is not an integer or tPage < 1 or tPage > tCount or tPage is sPage[sSection] then
      exit leGo
   end if
   put tPage into sPage[sSection]
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen for visual effect in rect lkR(kSide, 0, sWidth, sHeight)
   leRender
   leSyncIndex
   unlock screen with visual effect tEffect very fast
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end leGo

on linkClicked pLink
   leFollow pLink
end linkClicked

-- A link on a page: another page, a web page, or a file of the guides'
-- (linked_files)
private command leFollow pLink
   local tPage, tError
   try
      if pLink begins with "doc:" then
         launch document (char 5 to -1 of pLink)
         exit leFollow
      end if
      if pLink contains "://" then
         launch url pLink
         exit leFollow
      end if
      if pLink begins with "www." then
         launch url ("https://" & pLink)
         exit leFollow
      end if
   catch tError
      leToast "That could not open:" && lkErrorText(tError), "bad"
      exit leFollow
   end try
   put leFindPage(sSection, pLink) into tPage
   if tPage is empty then
      leToast "There is no page called" && quote & pLink & quote && "here.", "warn"
   else
      leGo tPage
   end if
end leFollow

private command leCopy pIndex
   if sCode[pIndex] is empty then
      exit leCopy
   end if
   set the clipboardData["text"] to sCode[pIndex]
   leToast "Copied: paste it into a script, or into the Message Box to run it.", "ok"
end leCopy

-- The page in front, in its own stack
private command leClassic
   local tError
   if sSection is "examples" or sPath[sSection] is empty then
      exit leClassic
   end if
   try
      go card sPage[sSection] of stack sPath[sSection]
   catch tError
      leToast "The classic stack could not open:" && lkErrorText(tError), "bad"
   end try
end leClassic

-- A word at the foot of the page for a moment: ok, warn or bad
private command leToast pText, pKind
   local tColor, tIcon, tWidth, tLeft, tTop, tSaved
   -- (an example that stops on an error as it opens leaves its own stack
   -- the default one, where the toast's controls are not)
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   switch pKind
      case "warn"
         put lkColor("amber") into tColor
         put "triangle-alert" into tIcon
         break
      case "bad"
         put lkColor("rose") into tColor
         put "triangle-alert" into tIcon
         break
      default
         put lkMix(lkColor("emerald"), "255,255,255", 0.2) into tColor
         put "check" into tIcon
   end switch
   lock screen
   put pText into field "toast_label"
   lkIconInk the long id of image "toast_icon", tIcon, tColor
   put the formattedWidth of field "toast_label" + 62 into tWidth
   put kSide + (sWidth - kSide - tWidth) div 2 into tLeft
   put sHeight - 64 into tTop
   set the rect of group "toast" to tLeft, tTop, tLeft + tWidth, tTop + 40
   set the rect of graphic "toast_bg" to tLeft, tTop, tLeft + tWidth, tTop + 40
   set the topLeft of image "toast_icon" to tLeft + 16, tTop + 12
   set the rect of field "toast_label" to tLeft + 42, tTop + 11 - kTextInset, tLeft + tWidth - 10, tTop + 31
   show group "toast"
   unlock screen
   put lkNow() + 2600 into sToastUntil
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end leToast

################################################################################
#
# One frame
#

on lkFrame
   local tY
   -- The sidebar's highlight slides to the place in front
   if sNavTarget is not empty and abs(sNavY - sNavTarget) > 0.5 then
      put sNavY + (sNavTarget - sNavY) * min(1, lkDt() * 14) into sNavY
      put round(sNavY) into tY
      set the top of graphic "navHi" to tY
      set the top of graphic "navBar" to tY + 7
   else if sNavTarget is not empty and sNavY is not sNavTarget then
      put sNavTarget into sNavY
      set the top of graphic "navHi" to sNavY
      set the top of graphic "navBar" to sNavY + 7
   end if
   if sToastUntil is not empty and lkNow() > sToastUntil then
      put empty into sToastUntil
      hide group "toast"
   end if
   leHeroFrame
end lkFrame

################################################################################
#
# Drawing a page
#

-- Draws the page in front anew
command leRender
   local tSaved
   if the mode of me is 0 and not the visible of me then
      exit leRender
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   lkForget "page"
   if there is a group "page" then
      delete group "page"
   end if
   -- (the new page is laid out at the body's top: a scroll left over
   -- from the last one would push it down by as much)
   set the vScroll of group "body" to 0
   put empty into sCode
   put empty into sHero
   put empty into sCardTop
   if sSection is "examples" then
      leRenderGallery
   else if sTitles[sSection] is empty then
      leRenderMissing
   else if sPage[sSection] is 1 then
      leRenderLanding
   else
      leRenderPage
   end if
   set the vScroll of group "body" to 0
   unlock messages
   unlock screen
   lkEnter "page"
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end leRender

-- The header: a page's title and tagline, or none (a landing page)
private command leHeader pTitle, pTag
   local tSize
   if pTitle is empty then
      hide group "hdr"
      set the rect of group "body" to kSide, 0, sWidth, sHeight
      exit leHeader
   end if
   show group "hdr"
   set the rect of group "body" to kSide, kHeaderHeight, sWidth, sHeight
   put pTitle into field "hdrTitle"
   -- (a long title is set smaller, to stay on one line)
   put 26 into tSize
   set the textSize of field "hdrTitle" to tSize
   repeat while tSize > 17 and the formattedWidth of field "hdrTitle" > the width of field "hdrTitle"
      subtract 2 from tSize
      set the textSize of field "hdrTitle" to tSize
   end repeat
   put pTag into field "hdrTag"
   if sSection is "examples" or sTitles[sSection] is empty then
      hide group "classic"
   else
      show group "classic"
   end if
end leHeader

-- The page's group, in the body, and the column it is laid out in
private command leBeginPage pWide
   local tObj
   leColumn pWide
   put lkGroup("page", the rect of group "body", "body") into tObj
   set the lockLoc of tObj to false
   -- (the first control made in an empty group is moved to the group's
   -- top left: this one is there already, and holds the page's top)
   get lkBox("p_top", lkR(kSide, the top of group "body", kSide + 1, the top of group "body" + 1), empty, 0, "page")
   put the top of group "body" + 30 into sY
end leBeginPage

-- Room below the last thing on the page
private command leEndPage
   get lkBox("p_end", lkR(sX, sY, sX + 1, sY + 48), empty, 0, "page")
end leEndPage

-- A field of htmlText at sY, the column's width, as tall as its text
private function leHtmlField pName, pLeft, pWidth, pHtml, pSize, pColor
   local tObj
   put lkLabel(pName, lkR(pLeft, sY, pLeft + pWidth, sY + 20), empty, pSize, pColor, "page") into tObj
   set the htmlText of tObj to pHtml
   leFit tObj
   return tObj
end leHtmlField

-- A field made as tall as its text, its top kept
private command leFit pObj
   local tRect
   put the rect of pObj into tRect
   set the rect of pObj to item 1 of tRect, item 2 of tRect, item 3 of tRect, \
         item 2 of tRect + the formattedHeight of pObj + kTextInset + 2
end leFit

-- When the stack a place's pages come from is missing: what it is, where
-- it would be, and (for the guides) the same guide as a PDF. The web IDE
-- leaves the guides' stack out of its download, which it would make far
-- larger.
private command leRenderMissing
   local tAccent, tTop, tObj, tText, tLabel
   put leSectionInfo(sSection, "accent") into tAccent
   put toLower(leSectionInfo(sSection, "label")) into tLabel
   leHeader leSectionInfo(sSection, "label"), "Not in this copy of the IDE"
   leBeginPage false
   put sY into tTop
   put lkBox("p_missBg", lkR(sX, tTop, sX + sColW, tTop + 200), lkColor("panel"), 16, "page") into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 10, 2, 26
   get lkBox("p_missTile", lkR(sX + 28, tTop + 28, sX + 76, tTop + 76), lkTint(tAccent, 0.12), 14, "page")
   get lkIcon("p_missIcon", leSectionInfo(sSection, "icon"), lkAccentInk(tAccent), lkR(sX + 40, tTop + 40, sX + 64, tTop + 64), "page")
   put lkLabel("p_missTitle", lkR(sX + 96, tTop + 30, sX + sColW - 28, tTop + 56), "The" && tLabel && "are not here", 20, lkColor("ink"), "page") into tObj
   set the textStyle of tObj to "bold"
   -- (in plain words on the web, where leaving it out is the design and
   -- the file's name means nothing to the reader)
   if sSection is "guides" and the platform is "HTML5" then
      put "The web IDE leaves them out to keep its download small. The same guide is in the User Guide PDF." into tText
   else
      put "This copy of the IDE does not have the stack they are kept in:" && leSectionInfo(sSection, "stack") & \
            ".oxtstack, in the Toolset's palettes/userguides folder." into tText
      if sSection is "guides" then
         put " The same guide is in the User Guide PDF." after tText
      end if
   end if
   put tTop + 62 into sY
   put leHtmlField("p_missText", sX + 96, sColW - 124, "<p>" & lkEscape(tText) & "</p>", 14, lkColor("soft")) into tObj
   put the bottom of tObj + 18 into sY
   if sSection is "guides" then
      get lkButton("p_missPdf", sX + 96, sY, 36, "Open the User Guide PDF", "file-text", "primary", tAccent, "page", "pdf", 0, "page")
      add 36 + 18 to sY
   end if
   set the rect of graphic "p_missBg" to sX, tTop, sX + sColW, sY + 10
   add 40 to sY
   leEndPage
end leRenderMissing

################################################################################
#
# A page of the lessons or the guides
#

private command leRenderPage
   local tPage, tText, tTitle, tEyebrow, tBlocks, tIndex
   put sPage[sSection] into tPage
   put leTitle(sSection, tPage) into tTitle
   put leRead(sSection, tPage) into tText
   put leTrimTop(tText, tTitle) into tText
   put line 1 of tText into tEyebrow
   delete line 1 of tText
   leHeader tTitle, leTagline(tPage, tEyebrow, tText)
   leBeginPage false
   put leBlocks(tText) into tBlocks
   repeat with tIndex = 1 to tBlocks["count"]
      switch tBlocks[tIndex]["kind"]
         case "text"
            leTextBlock tIndex, tBlocks[tIndex]["lines"]
            break
         case "code"
            leCodeBlock tIndex, tBlocks[tIndex]["lines"]
            break
         case "image"
            leImageBlock tIndex, tBlocks[tIndex]["lines"], tPage
            break
         default
            leCallout tIndex, tBlocks[tIndex]["kind"], tBlocks[tIndex]["lines"]
      end switch
   end repeat
   lePageFoot tPage
   leEndPage
end leRenderPage

-- A page's text begins with what the header shows: "Lesson 3" (an
-- eyebrow, which the tagline shows) and the title again. These go, and
-- the eyebrow comes back as the first line.
private function leTrimTop pText, pTitle
   local tLine, tPlain, tEyebrow, tSeen
   put 0 into tSeen
   repeat while pText is not empty and tSeen < 2
      put line 1 of pText into tLine
      put leStripTags(tLine) into tPlain
      if word 1 to -1 of tPlain is empty then
         delete line 1 of pText
         next repeat
      end if
      add 1 to tSeen
      if tSeen is 1 and tLine contains "<bu>" and word 1 of tPlain is "Lesson" then
         put word 1 to -1 of tPlain into tEyebrow
         delete line 1 of pText
         next repeat
      end if
      if (tLine contains "<b>" or tLine contains "<bu>") and word 1 to -1 of tPlain is pTitle then
         delete line 1 of pText
      end if
      exit repeat
   end repeat
   return tEyebrow & return & pText
end leTrimTop

-- The header's tagline: the lesson's number or the guide's chapter, and
-- how long the page takes to read
private function leTagline pPage, pEyebrow, pText
   local tTag, tIndex, tLevel, tParent, tMinutes
   if sSection is "lessons" then
      if pEyebrow is not empty then
         put pEyebrow into tTag
      else
         put "Lessons" into tTag
      end if
   else
      put leLevel(sSection, pPage) into tLevel
      put empty into tTag
      repeat with tIndex = pPage - 1 down to 2
         if leLevel(sSection, tIndex) < tLevel then
            put leLevel(sSection, tIndex) into tLevel
            if tTag is empty then
               put leTitle(sSection, tIndex) into tTag
            else
               put leTitle(sSection, tIndex) && "/" && tTag into tTag
            end if
            if tLevel is 0 then
               exit repeat
            end if
         end if
      end repeat
      if tTag is empty then
         put "The guide" into tTag
      end if
   end if
   put max(1, round(the number of words of leStripTags(pText) / 200)) into tMinutes
   return tTag && "  " & numToCodepoint(183) & "  " & tMinutes && "min read"
end leTagline

private function leStripTags pText
   local tTag
   repeat for each item tTag in "<bu>,<b>,<u>,<i>,<ln>,<code>,</code>,<tip>,</tip>,<note>,</note>,<important>,</important>,<caution>,</caution>"
      replace tTag with empty in pText
   end repeat
   return pText
end leStripTags

-- The blocks of a page, from its markup: tBlocks[n]["kind"] is "text",
-- "code", "tip", "note", "important", "caution" or "image", and
-- tBlocks[n]["lines"] its lines (the tags of a text line stay, for
-- leLineHtml; the lines that open and close a block go, as in the
-- classic stacks)
private function leBlocks pText
   local tBlocks, tCount, tMode, tLine, tKind, tTag
   put 0 into tCount
   put "text" into tMode
   repeat for each line tLine in pText
      if tMode is not "text" then
         if tLine contains ("</" & tMode & ">") then
            put "text" into tMode
         else
            put tLine & return after tBlocks[tCount]["lines"]
         end if
         next repeat
      end if
      put empty into tKind
      repeat for each item tTag in "code,tip,note,important,caution"
         if tLine contains ("<" & tTag & ">") then
            put tTag into tKind
            exit repeat
         end if
      end repeat
      if tKind is not empty then
         add 1 to tCount
         put tKind into tBlocks[tCount]["kind"]
         put tKind into tMode
         next repeat
      end if
      if tLine contains "<img" or tLine contains "<rimg" then
         add 1 to tCount
         put "image" into tBlocks[tCount]["kind"]
         put tLine into tBlocks[tCount]["lines"]
         next repeat
      end if
      if tCount is 0 or tBlocks[tCount]["kind"] is not "text" then
         add 1 to tCount
         put "text" into tBlocks[tCount]["kind"]
      end if
      put tLine & return after tBlocks[tCount]["lines"]
   end repeat
   put tCount into tBlocks["count"]
   return tBlocks
end leBlocks

-- A run of text: headings, paragraphs, lists and links in one field
private command leTextBlock pIndex, pLines
   local tHtml, tLine, tKind, tKinds, tGaps, tCount, tGap, tObj, tN, tLines
   put 0 into tCount
   put false into tGap
   put pLines into tLines
   split tLines by return
   repeat with tN = 1 to the number of lines of pLines
      put leLineHtml(tLines[tN], tKind) into tLine
      if tKind is "para" and leIsLostHeading(tLines[tN], tLines[tN + 1]) then
         put leLineHtml("<bu>" & tLines[tN], tKind) into tLine
      end if
      if tKind is "blank" then
         put true into tGap
         next repeat
      end if
      if tLine is empty then
         next repeat
      end if
      add 1 to tCount
      put tLine after tHtml
      put tKind into tKinds[tCount]
      put tGap into tGaps[tCount]
      put false into tGap
   end repeat
   if tCount is 0 then
      exit leTextBlock
   end if
   put leHtmlField("p_t" & pIndex, sX, sColW, tHtml, 15, lkColor("text")) into tObj
   repeat with tN = 1 to tCount
      switch tKinds[tN]
         case "heading"
            if tN > 1 then
               set the spaceAbove of line tN of tObj to 18
            end if
            set the spaceBelow of line tN of tObj to 4
            break
         case "sub"
            if tN > 1 then
               set the spaceAbove of line tN of tObj to 14
            end if
            set the spaceBelow of line tN of tObj to 2
            break
         case "bullet"
            set the leftIndent of line tN of tObj to 22
            set the firstIndent of line tN of tObj to -14
            if tGaps[tN] and tN > 1 then
               set the spaceAbove of line tN of tObj to 8
            else
               set the spaceAbove of line tN of tObj to 3
            end if
            break
         default
            if tN > 1 then
               if tGaps[tN] then
                  set the spaceAbove of line tN of tObj to 12
               else
                  set the spaceAbove of line tN of tObj to 3
               end if
            end if
      end switch
   end repeat
   leFit tObj
   add the height of tObj + 14 to sY
end leTextBlock

-- A plain line that was a heading before the guide became plain text: a
-- few words, a capital first, no stop at the end, and a gap after it
private function leIsLostHeading pLine, pNext
   if pLine contains "<" or word 1 to -1 of pNext is not empty then
      return false
   end if
   put word 1 to -1 of pLine into pLine
   if the number of words of pLine > 6 or the number of chars of pLine > 48 then
      return false
   end if
   if char -1 of pLine is among the chars of ".:;,!?)" & quote then
      return false
   end if
   return codepointToNum(char 1 of pLine) >= 65 and codepointToNum(char 1 of pLine) <= 90
end leIsLostHeading

-- One line of text as htmlText, and what kind it is (rKind): "blank",
-- "heading", "sub", "bullet", "link", "nav" (a Previous or Next Page
-- link, which the page's foot does instead) or "para"
private function leLineHtml pLine, @rKind
   local tBold, tUnder, tItalic, tLink, tText, tTarget, tAccent
   put pLine contains "<b>" or pLine contains "<bu>" into tBold
   put pLine contains "<u>" or pLine contains "<bu>" into tUnder
   put pLine contains "<i>" into tItalic
   put pLine contains "<ln>" into tLink
   put leStripTags(pLine) into tText
   replace "&TAB" with tab in tText
   put leSectionInfo(sSection, "accent") into tAccent
   if word 1 to -1 of tText is empty then
      put "blank" into rKind
      return empty
   end if
   if tLink then
      if tText contains "(next)" or tText contains "(prev)" then
         put "nav" into rKind
         return empty
      end if
      -- (the way back to the contents is the sidebar's first line)
      if word 1 to -1 of tText is leTitle(sSection, 1) then
         put "nav" into rKind
         return empty
      end if
      put word 1 to -1 of tText into tText
      if tText contains "tDocPath" then
         replace "tDocPath/" with empty in tText
         replace "tDocPath" with empty in tText
         put word 1 to -1 of tText into tText
         put "doc:" & leRoot() & "/Documentation/linked_files/" & tText into tTarget
      else
         put tText into tTarget
      end if
      put "link" into rKind
      return "<p><a href=" & quote & lkEscape(tTarget) & quote & "><font color=" & quote & \
            lkHex(tAccent) & quote & ">" & lkEscape(tText) & "</font></a></p>"
   end if
   put word 1 to -1 of tText into tText
   if tBold and tUnder then
      put "sub" into rKind
      return "<p><font size=" & quote & "16" & quote & " color=" & quote & lkHex(lkAccentText(tAccent, 0.25)) & \
            quote & "><b>" & lkEscape(tText) & "</b></font></p>"
   end if
   if tBold then
      put "heading" into rKind
      return "<p><font size=" & quote & "19" & quote & " color=" & quote & lkHex(lkColor("ink")) & quote & "><b>" & \
            lkEscape(tText) & "</b></font></p>"
   end if
   if char 1 to 2 of tText is among the items of "o ,* ,- " then
      put "bullet" into rKind
      return "<p><font color=" & quote & lkHex(tAccent) & quote & ">&#8226;</font>" & tab & lkEscape(word 2 to -1 of tText) & "</p>"
   end if
   -- (a figure's caption: "Figure 40 - Image, Graphic and Player objects")
   if word 1 of tText is "Figure" and word 2 of tText is an integer then
      put "caption" into rKind
      return "<p><font size=" & quote & "13" & quote & " color=" & quote & lkHex(lkColor("soft")) & quote & ">" & \
            lkEscape(tText) & "</font></p>"
   end if
   put "para" into rKind
   if tItalic then
      return "<p><i><font color=" & quote & lkHex(lkAccentInk("67,56,202")) & quote & ">" & lkEscape(tText) & "</font></i></p>"
   end if
   if tUnder then
      return "<p><u>" & lkEscape(tText) & "</u></p>"
   end if
   return "<p>" & lkEscape(tText) & "</p>"
end leLineHtml

-- Code, on a dark panel, in colour, with a Copy button
private command leCodeBlock pIndex, pLines
   local tCode, tIndent, tLine, tSpaces, tBox, tObj, tTop, tName, tWidth
   -- (the lines lose the indent they all share, and the blank lines at
   -- either end; "--!DEL" is the classic stacks' way to keep a "--" plain)
   replace "--!DEL" with empty in pLines
   put 1000 into tIndent
   repeat for each line tLine in pLines
      if word 1 to -1 of tLine is empty then
         next repeat
      end if
      put 0 into tSpaces
      repeat while char tSpaces + 1 of tLine is space
         add 1 to tSpaces
      end repeat
      put min(tIndent, tSpaces) into tIndent
   end repeat
   if tIndent is 1000 then
      exit leCodeBlock
   end if
   repeat for each line tLine in pLines
      put char tIndent + 1 to -1 of tLine & return after tCode
   end repeat
   repeat while tCode is not empty and word 1 to -1 of line 1 of tCode is empty
      delete line 1 of tCode
   end repeat
   repeat while tCode is not empty and word 1 to -1 of the last line of tCode is empty
      delete the last line of tCode
   end repeat
   put tCode into sCode[pIndex]
   put "p_c" & pIndex into tName
   put sY + 4 into tTop
   put lkBox(tName & "_bg", lkR(sX, tTop, sX + sColW, tTop + 60), lkColor("code"), 14, "page") into tBox
   get lkOval(tName & "_d1", lkR(sX + 16, tTop + 14, sX + 26, tTop + 24), "248,113,113", "page")
   get lkOval(tName & "_d2", lkR(sX + 32, tTop + 14, sX + 42, tTop + 24), "251,191,36", "page")
   get lkOval(tName & "_d3", lkR(sX + 48, tTop + 14, sX + 58, tTop + 24), "52,211,153", "page")
   put lkLabel(tName & "_kind", lkR(sX + 70, tTop + 11, sX + 200, tTop + 27), "xTalk", 11, "148,163,184", "page") into tObj
   leCenterIn tObj, tTop + 9, tTop + 29
   put lkButton(tName & "_copy", sX, tTop + 7, 26, "Copy", "copy", "dark", empty, "page", "copy" && pIndex, 0, "page") into tWidth
   set the left of group (tName & "_copy") to sX + sColW - tWidth - 10
   put lkCodeField(tName & "_code", lkR(sX + 20, tTop + 42, sX + sColW - 20, tTop + 60), 13, 20, "page") into tObj
   set the dontWrap of tObj to false
   set the htmlText of tObj to lkCodeHtml(tCode)
   leFit tObj
   set the rect of tBox to sX, tTop, sX + sColW, the bottom of tObj + 14
   put the bottom of tBox + 18 into sY
end leCodeBlock

-- A tip, a note, an important point or a caution: a tinted panel with an
-- icon and a word for what it is
private command leCallout pIndex, pKind, pLines
   local tAccent, tIcon, tWord, tName, tBox, tBar, tObj, tHtml, tLine, tKind, tTop, tFirst, tAt, tEnd
   switch pKind
      case "tip"
         put lkColor("emerald") into tAccent
         put "lightbulb" into tIcon
         put "Tip" into tWord
         break
      case "note"
         put lkColor("sky") into tAccent
         put "info" into tIcon
         put "Note" into tWord
         break
      case "important"
         put lkColor("violet") into tAccent
         put "star" into tIcon
         put "Important" into tWord
         break
      default
         put lkColor("rose") into tAccent
         put "triangle-alert" into tIcon
         put "Caution" into tWord
   end switch
   put true into tFirst
   repeat for each line tLine in pLines
      -- (the panel says what it is: a first line's own "Note:" goes)
      if tFirst and word 1 to -1 of leStripTags(tLine) is not empty then
         put false into tFirst
         if word 1 of leStripTags(tLine) is (tWord & ":") then
            put offset(tWord & ":", tLine) into tAt
            put tAt + the number of chars of tWord into tEnd
            delete char tAt to tEnd of tLine
         end if
      end if
      put leLineHtml(tLine, tKind) into tLine
      if tLine is not empty then
         put tLine after tHtml
      end if
   end repeat
   if tHtml is empty then
      exit leCallout
   end if
   put "p_n" & pIndex into tName
   put sY + 2 into tTop
   put lkBox(tName & "_bg", lkR(sX, tTop, sX + sColW, tTop + 60), lkTint(tAccent, 0.07), 12, "page") into tBox
   lkBorder tBox, lkTint(tAccent, 0.3)
   put lkBox(tName & "_bar", lkR(sX, tTop, sX + 4, tTop + 60), tAccent, 0, "page") into tBar
   get lkIcon(tName & "_icon", tIcon, lkAccentInk(tAccent), lkR(sX + 18, tTop + 15, sX + 36, tTop + 33), "page")
   get lkLabel(tName & "_word", lkR(sX + 46, tTop + 15, sX + 200, tTop + 33), tWord, 13, lkAccentText(tAccent, 0.3), "page")
   set the textStyle of field (tName & "_word") to "bold"
   put tTop + 38 into sY
   put leHtmlField(tName & "_text", sX + 46, sColW - 66, tHtml, 14, lkAccentText(tAccent, 0.55)) into tObj
   set the rect of tBox to sX, tTop, sX + sColW, the bottom of tObj + 14
   -- (the bar runs down the panel's left, inside its rounded corners)
   set the rect of tBar to sX + 1, tTop + 10, sX + 4, the bottom of tObj + 4
   put the bottom of tBox + 18 into sY
end leCallout

-- An image of the page's own card (<img "name">) or another card's
-- (<rimg "name":card>), copied onto the page and made to fit
private command leImageBlock pIndex, pLine, pPage
   local tName, tCard, tFrom, tSrc, tObj, tWidth, tHeight, tScale, tBox, tError
   set the itemDelimiter to quote
   put item 2 of pLine into tName
   put item 3 of pLine into tCard
   set the itemDelimiter to comma
   if tCard begins with ":" then
      delete char 1 of tCard
      put offset(">", tCard) into tFrom
      if tFrom > 0 then
         delete char tFrom to -1 of tCard
      end if
   else
      put empty into tCard
   end if
   if tName is empty then
      exit leImageBlock
   end if
   try
      if tCard is not empty and there is an image tName of card tCard of stack sPath[sSection] then
         put the long id of image tName of card tCard of stack sPath[sSection] into tSrc
      else if there is an image tName of card pPage of stack sPath[sSection] then
         put the long id of image tName of card pPage of stack sPath[sSection] into tSrc
      end if
   catch tError
      put empty into tSrc
   end try
   if tSrc is empty then
      exit leImageBlock
   end if
   put lkBox("p_i" & pIndex & "_bg", lkR(sX, sY, sX + 20, sY + 20), lkColor("panel"), 12, "page") into tBox
   lkBorder tBox, lkColor("line")
   create image ("p_i" & pIndex) in group "page"
   put it into tObj
   try
      if the text of tSrc is not empty then
         set the text of tObj to the text of tSrc
      else
         set the fileName of tObj to the fileName of tSrc
      end if
   catch tError
      delete tObj
      delete tBox
      exit leImageBlock
   end try
   put the formattedWidth of tObj into tWidth
   put the formattedHeight of tObj into tHeight
   if tWidth < 1 or tHeight < 1 then
      put the width of tSrc into tWidth
      put the height of tSrc into tHeight
   end if
   put min(1, (sColW - 24) / tWidth, 560 / tHeight) into tScale
   put round(tWidth * tScale) into tWidth
   put round(tHeight * tScale) into tHeight
   set the resizeQuality of tObj to "good"
   set the lockLoc of tObj to true
   set the rect of tObj to sX + 12, sY + 12, sX + 12 + tWidth, sY + 12 + tHeight
   set the rect of tBox to sX, sY, sX + tWidth + 24, sY + tHeight + 24
   put the bottom of tBox + 18 into sY
end leImageBlock

-- The foot of a page: the pages before and after it, and who made them
private command lePageFoot pPage
   local tCount, tWidth, tObj
   put the number of lines of sTitles[sSection] into tCount
   add 14 to sY
   put (sColW - 16) div 2 into tWidth
   if pPage > 1 then
      leFootCard "p_prev", sX, tWidth, "Previous", leFootTitle(pPage - 1), "go prev", "arrow-left"
   end if
   if pPage < tCount then
      leFootCard "p_next", sX + sColW - tWidth, tWidth, "Next", leFootTitle(pPage + 1), "go next", "arrow-right"
   end if
   add 86 to sY
   put leHtmlField("p_credit", sX, sColW, "<p>" & lkEscape(leSectionInfo(sSection, "credit")) & "</p>", 12, lkColor("muted")) into tObj
   add the height of tObj + 4 to sY
end lePageFoot

private function leFootTitle pPage
   if pPage is 1 then
      return "Start here"
   end if
   if sSection is "lessons" and pPage > 2 then
      return pPage - 2 & ". " & leTitle(sSection, pPage)
   end if
   return leTitle(sSection, pPage)
end leFootTitle

-- A card that goes to another page, lit when the pointer is over it
private command leFootCard pName, pLeft, pWidth, pWord, pTitle, pAction, pIcon
   local tObj, tLook, tAccent, tRight
   put leSectionInfo(sSection, "accent") into tAccent
   put pLeft + pWidth into tRight
   get lkGroup(pName, lkR(pLeft - 12, sY - 12, tRight + 12, sY + 88), "page")
   put lkBox(pName & "_bg", lkR(pLeft, sY, tRight, sY + 68), lkColor("panel"), 14, pName) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 10, 2, 26
   if pIcon is "arrow-left" then
      get lkIcon(pName & "_icon", pIcon, lkAccentInk(tAccent), lkR(pLeft + 18, sY + 25, pLeft + 36, sY + 43), pName)
      put lkLabel(pName & "_word", lkR(pLeft + 48, sY + 14, tRight - 16, sY + 30), pWord, 12, lkColor("muted"), pName) into tObj
      put lkLabel(pName & "_label", lkR(pLeft + 48, sY + 33, tRight - 16, sY + 54), pTitle, 15, lkColor("ink"), pName) into tObj
   else
      get lkIcon(pName & "_icon", pIcon, lkAccentInk(tAccent), lkR(tRight - 36, sY + 25, tRight - 18, sY + 43), pName)
      put lkLabel(pName & "_word", lkR(pLeft + 16, sY + 14, tRight - 48, sY + 30), pWord, 12, lkColor("muted"), pName, "right") into tObj
      put lkLabel(pName & "_label", lkR(pLeft + 16, sY + 33, tRight - 48, sY + 54), pTitle, 15, lkColor("ink"), pName, "right") into tObj
   end if
   set the textStyle of tObj to "bold"
   lkEllipsize tObj
   put pName & "_bg" into tLook["bg"]
   put lkColor("panel") into tLook["bg0"]
   put lkTint(tAccent, 0.06) into tLook["bg1"]
   put lkColor("line") into tLook["line0"]
   put tAccent into tLook["line1"]
   put true into tLook["shadow"]
   lkLive pName, "page", pAction, tLook
end leFootCard

################################################################################
#
# The first page of the lessons and of the guides
#

private command leRenderLanding
   leHeader empty
   leBeginPage true
   if sSection is "lessons" then
      -- (the lessons are how-tos: a course in coding is the Academy's)
      leHero "HOW-TO", "Everyday tasks, one idea at a time", \
            the number of lines of sTitles[sSection] - 2 && "short lessons, each with code you can copy: from your first button to arrays, SQLite, sockets and widgets.", \
            leSectionInfo(sSection, "credit"), "124,58,237|219,39,119|249,115,22", \
            "Start with lesson 1|go 3|play", "Read the foreword|go 2|book-open", \
            "New to coding? Try the Academy|academy|graduation-cap"
      leLessonTiles
   else
      leHero "GUIDES", "The xTalk guide", \
            "Everything about the language and the IDE in" && the number of lines of sTitles[sSection] - 1 && \
            "pages: scripts and messages, every kind of object, the Data Grid, databases, debugging, and building the engine yourself.", \
            leSectionInfo(sSection, "credit"), "2,132,199|79,70,229|124,58,237", \
            "Start reading|go 2|play", empty
      leChapterTiles
   end if
   leEndPage
end leRenderLanding

-- The big banner at the top of a first page: a gradient, lights that
-- float over it, and its words laid out from the top down (it is as tall
-- as they need)
private command leHero pEyebrow, pTitle, pText, pCredit, pColors, pButton1, pButton2, pButton3
   local tTop, tBottom, tObj, tBg, tIndex, tLeft, tRight, tX, tSize, tY, tButton, tName, tWidth
   put sY - 6 into tTop
   put sX + 40 into tLeft
   put sX + sColW - 40 into tRight
   get lkGroup("p_hero", lkR(sX, tTop, sX + sColW, tTop + 250), "page")
   put lkBox("p_heroBg", lkR(sX, tTop, sX + sColW, tTop + 250), lkColor("indigo"), 22, "p_hero") into tBg
   put pColors into sHero["colors"]
   -- lights: soft round glows, and sparkles
   repeat with tIndex = 1 to 4
      put item tIndex of "260,180,220,140" into tSize
      put lkOval("p_heroGlow" & tIndex, lkR(0, 0, tSize, tSize), "255,255,255", "p_hero") into tObj
      lkGlowFill tObj, "255,255,255", item tIndex of "70,55,60,45"
      set the blendLevel of tObj to 40
   end repeat
   repeat with tIndex = 1 to 6
      put lkBox("p_heroStar" & tIndex, lkR(0, 0, 10, 10), "255,255,255", 0, "p_hero") into tObj
      set the style of tObj to "polygon"
      set the points of tObj to lkSparklePoints(0, 0, item tIndex of "9,6,11,5,7,8")
      set the blendLevel of tObj to 30
   end repeat
   put lkLabel("p_heroEyebrow", lkR(tLeft, tTop + 34, tRight, tTop + 50), pEyebrow, 12, "255,255,255", "p_hero") into tObj
   set the textStyle of tObj to "bold"
   set the blendLevel of tObj to 25
   put lkLabel("p_heroTitle", lkR(tLeft, tTop + 56, tRight, tTop + 98), pTitle, 34, "255,255,255", "p_hero") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   -- (a smaller size where the column is too narrow for it on one line)
   repeat while the formattedWidth of tObj > tRight - tLeft and the textSize of tObj > 20
      set the textSize of tObj to the textSize of tObj - 2
   end repeat
   put tTop + 106 into tY
   put lkLabel("p_heroText", lkR(tLeft, tY, min(tRight, tLeft + 700), tY + 40), pText, 15, "255,255,255", "p_hero") into tObj
   leFit tObj
   set the blendLevel of tObj to 8
   put the bottom of tObj + 20 into tY
   put tLeft into tX
   -- The buttons go in a row, and one that would pass the right edge
   -- starts the next row: on a 1024 by 768 screen the third ("New to
   -- coding? Try the Academy") was cut off by the banner
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 3
      put param(5 + tIndex) into tButton
      if tButton is empty then
         next repeat
      end if
      put "p_heroB" & tIndex into tName
      put lkButton(tName, tX, tY, 38, item 1 of tButton, item 3 of tButton, "light", \
            leSectionInfo(sSection, "accent"), "p_hero", item 2 of tButton, 0, "page") into tWidth
      if tX > tLeft and tX + tWidth > tRight then
         add 38 + 12 to tY
         put tLeft into tX
         set the topLeft of group tName to tX, tY
      end if
      add tWidth + 12 to tX
   end repeat
   set the itemDelimiter to comma
   if tX > tLeft then
      add 38 + 22 to tY
   end if
   put lkLabel("p_heroCredit", lkR(tLeft, tY, tRight, tY + 16), pCredit, 12, "255,255,255", "p_hero") into tObj
   leFit tObj
   set the blendLevel of tObj to 30
   put the bottom of tObj + 26 into tBottom
   -- (the group's top left stays where it is, so nothing in it moves)
   set the rect of group "p_hero" to sX, tTop, sX + sColW, tBottom
   set the rect of tBg to sX, tTop, sX + sColW, tBottom
   lkGradient tBg, pColors, sX & "," & tTop, (sX + sColW) & "," & tBottom
   -- (its words and buttons, which its sparkles keep off)
   put lkTextZones(tBg, "p_heroEyebrow,p_heroTitle,p_heroText,p_heroCredit", "p_heroB1,p_heroB2,p_heroB3") into sHero["zones"]
   put lkNow() into sHero["start"]
   put tBottom + 30 into sY
   leHeroFrame
end leHero

-- The hero's lights drift; their places are worked out from the hero's
-- rect each frame, so that they move with the page when it scrolls
private command leHeroFrame
   local tRect, tW, tH, tT, tIndex, tX, tY, tObj
   if sHero["start"] is empty or there is no graphic "p_heroBg" then
      exit leHeroFrame
   end if
   put the rect of graphic "p_heroBg" into tRect
   put item 3 of tRect - item 1 of tRect into tW
   put item 4 of tRect - item 2 of tRect into tH
   put (lkNow() - sHero["start"]) / 1000 into tT
   repeat with tIndex = 1 to 4
      put item 1 of tRect + tW * (item tIndex of "0.72,0.9,0.55,0.18") + 60 * sin(tT * (0.35 + tIndex * 0.07) + tIndex * 1.7) into tX
      put item 2 of tRect + tH * (item tIndex of "0.2,0.85,0.95,0.1") + 30 * cos(tT * (0.3 + tIndex * 0.05) + tIndex) into tY
      set the loc of graphic ("p_heroGlow" & tIndex) to round(tX), round(tY)
   end repeat
   repeat with tIndex = 1 to 6
      put "p_heroStar" & tIndex into tObj
      put item 1 of tRect + tW * (item tIndex of "0.62,0.7,0.8,0.88,0.94,0.76") into tX
      put item 2 of tRect + tH * (item tIndex of "0.22,0.62,0.3,0.7,0.18,0.86") + 6 * sin(tT * 1.3 + tIndex) into tY
      set the loc of graphic tObj to round(tX), round(tY)
      set the blendLevel of graphic tObj to round(30 + 45 * (0.5 + 0.5 * sin(tT * 2.2 + tIndex * 1.9)))
      -- (none on the hero's words or buttons)
      set the visible of graphic tObj to not lkInZones(sHero["zones"], round(tX) - item 1 of tRect, round(tY) - item 2 of tRect, 8)
   end repeat
end leHeroFrame

-- A heading on a first page, with a line under it
private command leSectionHeading pName, pTitle, pText
   local tObj
   put lkLabel(pName, lkR(sX, sY, sX + sColW, sY + 28), pTitle, 20, lkColor("ink"), "page") into tObj
   set the textStyle of tObj to "bold"
   add 30 to sY
   if pText is not empty then
      put lkLabel(pName & "_text", lkR(sX, sY, sX + sColW, sY + 20), pText, 13, lkColor("soft"), "page") into tObj
      leFit tObj
      add the height of tObj + 4 to sY
   end if
   add 12 to sY
end leSectionHeading

-- Every lesson, as a tile with its number
private command leLessonTiles
   local tCols, tGap, tWidth, tHeight, tIndex, tCol, tX, tName, tObj, tLook, tAccent, tNumber, tCount
   put leSectionInfo(sSection, "accent") into tAccent
   put the number of lines of sTitles[sSection] into tCount
   leSectionHeading "p_allHead", "All" && tCount - 2 && "lessons", "Each one stands on its own: pick any of them, or go in order with Next."
   if sColW >= 900 then
      put 3 into tCols
   else
      put 2 into tCols
   end if
   put 12 into tGap
   put (sColW - (tCols - 1) * tGap) div tCols into tWidth
   put 62 into tHeight
   put 0 into tCol
   repeat with tIndex = 3 to tCount
      put sX + tCol * (tWidth + tGap) into tX
      put "p_tile" & tIndex into tName
      get lkGroup(tName, lkR(tX - 2, sY - 2, tX + tWidth + 2, sY + tHeight + 2), "page")
      put lkBox(tName & "_bg", lkR(tX, sY, tX + tWidth, sY + tHeight), lkColor("panel"), 12, tName) into tObj
      lkBorder tObj, lkColor("line")
      put lkOval(tName & "_badge", lkR(tX + 14, sY + 15, tX + 46, sY + 47), lkTint(tAccent, 0.12), tName) into tObj
      put tIndex - 2 into tNumber
      put lkLabel(tName & "_num", lkR(tX + 14, sY + 22, tX + 46, sY + 40), tNumber, 13, lkAccentText(tAccent, 0.2), tName, "center") into tObj
      set the textStyle of tObj to "bold"
      leCenterIn tObj, sY + 15, sY + 47
      put lkLabel(tName & "_label", lkR(tX + 58, sY + 12, tX + tWidth - 12, sY + tHeight - 6), leTitle(sSection, tIndex), 14, lkColor("ink"), tName) into tObj
      leCenterIn tObj, sY, sY + tHeight
      put tName & "_bg" into tLook["bg"]
      put lkColor("panel") into tLook["bg0"]
      put lkTint(tAccent, 0.07) into tLook["bg1"]
      put lkColor("line") into tLook["line0"]
      put tAccent into tLook["line1"]
      put tName & "_label" into tLook["label"]
      put lkColor("ink") into tLook["ink0"]
      put lkAccentText(tAccent, 0.35) into tLook["ink1"]
      lkLive tName, "page", "go" && tIndex, tLook
      add 1 to tCol
      if tCol is tCols then
         put 0 into tCol
         add tHeight + tGap to sY
      end if
   end repeat
   if tCol > 0 then
      add tHeight + tGap to sY
   end if
end leLessonTiles

-- A label's text in the middle of a band, top to bottom
private command leCenterIn pObj, pTop, pBottom
   local tHeight
   put min(the formattedHeight of pObj, pBottom - pTop) into tHeight
   set the rect of pObj to item 1 of the rect of pObj, (pTop + pBottom - tHeight) div 2 - kTextInset div 2, \
         item 3 of the rect of pObj, (pTop + pBottom + tHeight) div 2 + kTextInset
end leCenterIn

-- The guide's chapters, as tiles with how many pages each has
private command leChapterTiles
   local tCols, tGap, tWidth, tHeight, tIndex, tCol, tX, tName, tObj, tLook, tAccent, tCount, tPages, tFirst, tSub, tChapters, tChapter
   local tSubTitle
   put leSectionInfo(sSection, "accent") into tAccent
   put the number of lines of sTitles[sSection] into tCount
   -- each chapter, and its pages
   repeat with tIndex = 2 to tCount
      if leLevel(sSection, tIndex) is 0 then
         put tIndex & return after tChapters
      else if tChapters is not empty then
         add 1 to tPages[the last line of tChapters]
         if leLevel(sSection, tIndex) is 1 and the number of lines of tSub[the last line of tChapters] < 3 then
            put leTitle(sSection, tIndex) & return after tSub[the last line of tChapters]
         end if
      end if
   end repeat
   leSectionHeading "p_allHead", "Chapters", "The guide in order: each chapter opens with its own pages, and the search finds a word in any of them."
   if sColW >= 900 then
      put 3 into tCols
   else
      put 2 into tCols
   end if
   put 14 into tGap
   put (sColW - (tCols - 1) * tGap) div tCols into tWidth
   put 112 into tHeight
   put 0 into tCol
   repeat for each line tChapter in tChapters
      put sX + tCol * (tWidth + tGap) into tX
      put "p_tile" & tChapter into tName
      get lkGroup(tName, lkR(tX - 2, sY - 2, tX + tWidth + 2, sY + tHeight + 2), "page")
      put lkBox(tName & "_bg", lkR(tX, sY, tX + tWidth, sY + tHeight), lkColor("panel"), 14, tName) into tObj
      lkBorder tObj, lkColor("line")
      put lkBox(tName & "_tint", lkR(tX + 16, sY + 16, tX + 52, sY + 52), lkTint(tAccent, 0.12), 10, tName) into tObj
      get lkIcon(tName & "_icon", leChapterIcon(leTitle(sSection, tChapter)), lkAccentInk(tAccent), lkR(tX + 25, sY + 25, tX + 43, sY + 43), tName)
      put lkLabel(tName & "_label", lkR(tX + 64, sY + 16, tX + tWidth - 14, sY + 36), leTitle(sSection, tChapter), 15, lkColor("ink"), tName) into tObj
      set the textStyle of tObj to "bold"
      lkEllipsize tObj
      if tPages[tChapter] is empty then
         put "One page" into tFirst
      else
         put tPages[tChapter] + 1 && "pages" into tFirst
      end if
      put lkLabel(tName & "_count", lkR(tX + 64, sY + 37, tX + tWidth - 14, sY + 53), tFirst, 12, lkAccentInk(tAccent), tName) into tObj
      put lkLabel(tName & "_sub", lkR(tX + 16, sY + 62, tX + tWidth - 14, sY + tHeight - 10), empty, 12, lkColor("soft"), tName) into tObj
      -- (its first pages, as many as two lines hold)
      put empty into tFirst
      repeat for each line tSubTitle in tSub[tChapter]
         if tFirst is empty then
            put tSubTitle into field (tName & "_sub")
         else
            put tFirst & "  " & numToCodepoint(183) & "  " & tSubTitle into field (tName & "_sub")
         end if
         if the formattedHeight of tObj > 40 then
            put tFirst into field (tName & "_sub")
            exit repeat
         end if
         put field (tName & "_sub") into tFirst
      end repeat
      put tName & "_bg" into tLook["bg"]
      put lkColor("panel") into tLook["bg0"]
      put lkTint(tAccent, 0.06) into tLook["bg1"]
      put lkColor("line") into tLook["line0"]
      put tAccent into tLook["line1"]
      put true into tLook["shadow"]
      lkShadow the long id of graphic (tName & "_bg"), 10, 2, 26
      lkLive tName, "page", "go" && tChapter, tLook
      add 1 to tCol
      if tCol is tCols then
         put 0 into tCol
         add tHeight + tGap to sY
      end if
   end repeat
   if tCol > 0 then
      add tHeight + tGap to sY
   end if
end leChapterTiles

private function leChapterIcon pTitle
   if pTitle contains "Script" or pTitle contains "Language" then
      return "code"
   end if
   if pTitle contains "User Interface" then
      return "layout-grid"
   end if
   if pTitle contains "Data Grid" then
      return "table"
   end if
   if pTitle contains "Debug" then
      return "bug"
   end if
   if pTitle contains "Print" then
      return "printer"
   end if
   if pTitle contains "Text" then
      return "type"
   end if
   if pTitle contains "Transferring" then
      return "globe"
   end if
   if pTitle contains "Database" then
      return "database"
   end if
   if pTitle contains "Media" then
      return "film"
   end if
   if pTitle contains "IDE" then
      return "square-terminal"
   end if
   if pTitle contains "Deploying" then
      return "rocket"
   end if
   if pTitle begins with "build-" then
      return "hard-drive"
   end if
   if pTitle contains "Extending" then
      return "puzzle"
   end if
   if pTitle contains "Builder" then
      return "blocks"
   end if
   if pTitle contains "C++" then
      return "braces"
   end if
   if pTitle contains "Widget" then
      return "sparkles"
   end if
   if pTitle contains "Release" or pTitle contains "Documentation" then
      return "scroll"
   end if
   return "book-open"
end leChapterIcon

################################################################################
#
# The examples
#

-- Every example the gallery knows: its file (from the IDE's folder), its
-- title, what it shows, who made it, its group, icon, accent, and a few
-- words to find it by. Who made each is what the stack itself says (its
-- script's first lines) and THIRD-PARTY-NOTICES.md; where neither names
-- anyone, the card says so. Then, for an example remade in Learn's look
-- (tools/examples), the remaster's file and its title: the gallery opens
-- the remaster, and lists the original under Classic when it is there
-- (the originals are not installed since 0.2.7-rc.6.12: tools/examples/
-- originals keeps them for the builders). Two originals remade as one
-- remaster both name it, and after its title say what it does.
private function leExampleTable
   local tTable
   put "Resources/Examples/Quick Start.oxtstack|Quick Start|Six first lessons, read aloud by a narrator: the Tools palette, " & \
         "buttons and fields, commands, the Script Editor, the Dictionary and groups.|Terry Little, 2024|start|rocket|violet|" & \
         "beginner tour speech narrator|Resources/Examples/Remastered/Quick Start Guide.oxtstack|Quick Start Guide" & return after tTable
   put "Resources/Examples/Animate Letter.oxtstack|Animate Letter|One letter, a dozen small programs: change its colour, " & \
         "move it, spin it, make it jump and dance, keep score and tell a story.|Terry Little, 2022|start|type|pink|" & \
         "animation move spin game|Resources/Examples/Remastered/Animate a Letter.oxtstack|Animate a Letter" & return after tTable
   put "Resources/Examples/Data Grid Tour.oxtstack|Data Grid Tour|A guided tour of the Data Grid: tables and forms, built " & \
         "step by step, with the template and behavior that draw each row.|LiveCode Ltd, debranded for OpenXTalk at LiveCode's request|tours|table|sky|" & \
         "datagrid table form|Resources/Examples/Remastered/A Data Grid Tour.oxtstack|A Data Grid Tour" & return after tTable
   put "Resources/Examples/SQLite Tour.oxtstack|SQLite Tour|A tour of databases: connect to SQLite, make tables, " & \
         "add, view, update and delete rows, join tables, and store binary data.|LiveCode Ltd, debranded for OpenXTalk at LiveCode's request|tours|database|indigo|" & \
         "sqlite database sql revdb|Resources/Examples/Remastered/A Tour of SQLite.oxtstack|A Tour of SQLite" & return after tTable
   put "Resources/Examples/DataGrid Table.oxtstack|DataGrid Table|Five short lessons on the Data Grid table: edit one by " & \
         "hand and with code, add a column, make your own, paste one, and compare a field made into a table.|Terry Little, 2022|tours|sheet|teal|" & \
         "datagrid table field|Resources/Examples/Remastered/Data Grid Tables.oxtstack|Data Grid Tables" & return after tTable
   put "Resources/Examples/SQLite Book Library.oxtstack|SQLite Book Library|A small catalogue of books in SQLite, shown in " & \
         "a Data Grid: list them, search them, add and delete them.|In OpenXTalk Lite's demo set; its author is not recorded|apps|library-big|emerald|" & \
         "sqlite datagrid books database|Resources/Examples/Remastered/SQLite Books.oxtstack|SQLite Books" & return after tTable
   put "Resources/Examples/RSS Demo.oxtstack|RSS Demo|Reads a news feed from the web and shows what it holds.|" & \
         "Via theotherbassist, 2016, in OpenXTalk Lite's demo set|apps|rss|orange|internet url xml feed|" & \
         "Resources/Examples/Remastered/RSS Reader.oxtstack|RSS Reader" & return after tTable
   put "Resources/Examples/Scroll Image.oxtstack|Scroll Image|A picture larger than its window, in a group that scrolls.|" & \
         "In OpenXTalk Lite's demo set; its author is not recorded|apps|image|sky|image group scroll|" & \
         "Resources/Examples/Remastered/Scroll an Image.oxtstack|Scroll an Image" & return after tTable
   put "Resources/Examples/Video Player.oxtstack|Video Player|Chooses a video file and plays it in a player.|" & \
         "Added in OpenXTalk Lite 1.15; its author is not recorded|apps|film|rose|video player media|" & \
         "Resources/Examples/Remastered/Play a Video.oxtstack|Play a Video" & return after tTable
   put "Resources/Examples/Zip Build Demo.oxtstack|Zip Build|Packs files into a zip archive with revZip.|" & \
         "In OpenXTalk Lite's demo set; its author is not recorded|apps|archive|amber|zip revzip archive files|" & \
         "Resources/Examples/Remastered/Zip Archives.oxtstack|Zip Archives|" & \
         "Packs files into a zip archive, and looks inside one: what it holds, and taking its files out." & return after tTable
   put "Resources/Examples/Zip Extract Demo.oxtstack|Zip Extract|Lists what a zip archive holds and takes its files out.|" & \
         "In OpenXTalk Lite's demo set; its author is not recorded|apps|folder-archive|amber|zip revzip archive files|" & \
         "Resources/Examples/Remastered/Zip Archives.oxtstack|Zip Archives|" & \
         "Packs files into a zip archive, and looks inside one: what it holds, and taking its files out." & return after tTable
   put "Resources/Start Center/samples/sample_1/Balls.livecode|Bouncing Balls|Balls that bounce, with gravity and friction, " & \
         "each moved by one shared behavior.|LiveCode Ltd, from LiveCode Community's Start Center|samples|orbit|orange|" & \
         "animation behavior graphics physics|Resources/Examples/Remastered/Bouncing Balls.oxtstack|Bouncing Balls" & return after tTable
   put "Resources/Start Center/samples/sample_2/BookLibrary.livecode|Book Library|Make, fill, search and update an " & \
         "SQLite database of books.|LiveCode Ltd, from LiveCode Community's Start Center|samples|book-open|emerald|" & \
         "sqlite database books|Resources/Examples/Remastered/Bookshelf.oxtstack|Bookshelf" & return after tTable
   put "Resources/Start Center/samples/sample_4/balloon.livecode|Balloon Game|A small game, and a book about how it is " & \
         "made: animation, sound, a game loop and collisions.|LiveCode Ltd, from LiveCode Community's Start Center|samples|gamepad-2|rose|" & \
         "game animation sound loop|Resources/Examples/Remastered/Balloon Game.oxtstack|Balloon Game" & return after tTable
   -- The Stack Player's stacks, when this copy of the IDE has them
   put leShowcaseTable() after tTable
   return tTable
end leExampleTable

-- The Stack Player's stacks (tools/web-player/stacks): the three whole
-- stacks it features, under "Made for the web", and its small samples. An
-- installed IDE and the web IDE have them in Resources/Examples/Showcase
-- (tools/oxt/package.py and tools/web-ide/build_site.py put them there);
-- a source tree has them where the player's own build reads them. They
-- come in the player's order, then any the list does not know yet
private function leShowcaseTable
   local tFolder, tFiles, tFile, tNames, tName, tInfo, tTable
   put leShowcaseFolder() into tFolder
   if tFolder is empty then
      return empty
   end if
   put files(leRoot() & "/" & tFolder) into tFiles
   filter tFiles with "*.oxtstack"
   sort lines of tFiles
   -- (the player's own course and its tour of the web are Home's Academy
   -- and Home's tour, so the gallery leaves them out, as packaging does:
   -- tools/oxt/package.py SHOWCASE_LEFT_OUT)
   repeat for each item tName in "OXT-Beyond on the Web,Learn xTalk"
      filter tFiles without (tName & ".oxtstack")
   end repeat
   repeat for each item tName in "xTalk Primer,Fireworks,Live Weather," & \
         "Web Audio Piano,Neon Snake,QR Studio,Talking Robot,2048,Quake Map,Beat Box,Kanban Board," & \
         "Markdown Notes,UI Gallery,Photo Lab"
      if (tName & ".oxtstack") is among the lines of tFiles then
         put tName & return after tNames
      end if
   end repeat
   repeat for each line tFile in tFiles
      put char 1 to -10 of tFile into tName
      if tName is not among the lines of tNames then
         put tName & return after tNames
      end if
   end repeat
   set the itemDelimiter to "|"
   repeat for each line tName in tNames
      put leShowcaseInfo(tName) into tInfo
      put tFolder & "/" & tName & ".oxtstack|" & tName & "|" & item 2 of tInfo & "|" & \
            "Made for OXT-Beyond's Stack Player, 2026|" & item 1 of tInfo & "|" & item 3 of tInfo & "|" & \
            item 4 of tInfo & "|" & item 5 of tInfo & " web browser" & return after tTable
   end repeat
   set the itemDelimiter to comma
   return tTable
end leShowcaseTable

-- Where the Stack Player's stacks are, from leRoot(), or empty
private function leShowcaseFolder
   if there is a folder (leRoot() & "/Resources/Examples/Showcase") then
      return "Resources/Examples/Showcase"
   end if
   if there is a folder (leRoot() & "/../tools/web-player/stacks") then
      return "../tools/web-player/stacks"
   end if
   return empty
end leShowcaseFolder

-- A Stack Player stack's group, what it shows, icon, accent and tags (the
-- player's own words for it, from tools/web-player/build_player.py).
-- Sound, speech and Photo Lab's pixels are the browser's, so those samples
-- say where they work: in the web IDE, and the Stack Player
private function leShowcaseInfo pName
   switch pName
      case "OXT-Beyond on the Web"
         return "web|A live tour of what a stack can do in a web page: dialogs, files, the internet, " & \
               "JavaScript, sound and speech, drawing, SQLite and encryption.|globe|indigo|tour javascript"
      case "Learn xTalk"
         return "web|A playful first course: ten lessons with code you run and change, and a challenge " & \
               "on each to earn a star.|graduation-cap|violet|lessons beginners"
      case "xTalk Primer"
         return "web|A home stack of examples: buttons and menus, fields and text, graphics and timers, " & \
               "lists and data, each with a short script to read.|notebook-pen|teal|examples scripts"
      case "Fireworks"
         return "small|Click the sky: hundreds of sparks, each a graphic moved by script, sixty times " & \
               "a second.|sparkles|orange|animation graphics"
      case "Live Weather"
         return "small|Today and the week ahead for any place, fetched from open-meteo.com with put url " & \
               "and drawn as a chart.|cloud-sun|sky|internet json chart"
      case "Web Audio Piano"
         return "small|Two octaves to play with the mouse or the keyboard. Each note is made by the " & \
               "browser, through do as JavaScript, so it plays in a browser.|piano|violet|sound javascript"
      case "Neon Snake"
         return "small|The classic game on a timer loop: steer with the arrow keys, and try to beat " & \
               "your best score.|gamepad-2|emerald|game keyboard"
      case "QR Studio"
         return "small|Type a link, a Wi-Fi network or a contact and get a QR code your phone can scan, " & \
               "then save it as a picture.|qr-code|indigo|qr-code image"
      case "Talking Robot"
         return "small|A robot that says what you type in the browser's own voices, lights up each word " & \
               "as it speaks, and watches your mouse. It talks in a browser.|bot|teal|speech javascript"
      case "2048"
         return "small|Slide and join the tiles to reach 2048, with animated moves, an undo and your " & \
               "best score.|grid-2x2|amber|game animation"
      case "Quake Map"
         return "small|The world's earthquakes, live from the USGS: fetched with put url and drawn on " & \
               "a map you can explore.|map|rose|live-data map"
      case "Beat Box"
         return "small|A 16-step drum machine: drums made by Web Audio, kept in time by the browser, " & \
               "and your beat saved for next time. It plays in a browser.|music|pink|music web-audio"
      case "Kanban Board"
         return "small|Drag cards between three columns while the others slide out of the way; add, " & \
               "tag, edit and bin them, and the board is kept for next time.|layout-grid|sky|drag animation"
      case "Markdown Notes"
         return "small|Write Markdown on the left and see it styled on the right as you type, tick " & \
               "boxes in the preview, and save a note as Markdown or a web page.|file-text|emerald|markdown text"
      case "UI Gallery"
         return "small|Modern controls drawn with graphics and a little script: switches, sliders, a " & \
               "segmented control, a progress ring, toasts, a sheet and a dark theme.|mouse-pointer-click|violet|controls themes"
      case "Photo Lab"
         return "small|Open a photo of your own, pick a look, adjust it and download it at full size. " & \
               "The browser does the pixel work, so it runs in a browser.|image|pink|photos javascript"
   end switch
   return "small|A small sample made for the Stack Player: open it, then read its scripts.|layers|indigo|sample"
end leShowcaseInfo

-- The groups of examples, in order: key, title and a line about them
private function leExampleGroups
   -- (OXT-Beyond Home's gallery: the classic originals, LiveCode's mobile
   -- examples and template and the xTalk Suite's apps are not installed
   -- since 0.2.7-rc.6.12, and the Stack Player's own course and tour are
   -- the Academy and Home's tour)
   return "start|Start here|Two stacks that teach as they go: open one and follow it." & return & \
         "web|Made for the web|The Stack Player's home stack of examples: buttons and menus, fields and " & \
         "text, graphics and timers, lists and data, each with a short script to read." & return & \
         "small|Small samples|Also from the Stack Player: games, music, live data, speech, notes and modern " & \
         "controls, each small enough to read in one sitting." & return & \
         "tours|Tours|Guided tours of the Data Grid and of SQLite, a card at a time." & return & \
         "apps|Small apps to take apart|Each does one thing, in a few short scripts: open one, then read its scripts." & return & \
         "samples|Samples, remade|Three of LiveCode Community's samples in Home's look: a game, bouncing balls and a database of books."
end leExampleGroups

-- The numbers (in leExampleTable) of the examples that are here, and that
-- the search finds. Two originals remade as one remaster are one example,
-- the first of them, unless pAll is true: Classic lists every original
private function leExampleKeys pAll
   local tLine, tIndex, tKeys, tTerm, tFile, tListed
   if sExamples is empty then
      put leExampleTable() into sExamples
   end if
   put word 1 to -1 of sSearch["examples"] into tTerm
   put 0 into tIndex
   set the itemDelimiter to "|"
   repeat for each line tLine in sExamples
      add 1 to tIndex
      put leRoot() & "/" & item 1 of tLine into tFile
      if there is no file tFile and (item 9 of tLine is empty or there is no file (leRoot() & "/" & item 9 of tLine)) then
         next repeat
      end if
      if tTerm is not empty and not (tLine contains tTerm) then
         next repeat
      end if
      if pAll is not true and item 9 of tLine is not empty and there is a file (leRoot() & "/" & item 9 of tLine) then
         if tListed[item 9 of tLine] is true then
            next repeat
         end if
         put true into tListed[item 9 of tLine]
      end if
      put tIndex & return after tKeys
   end repeat
   set the itemDelimiter to comma
   delete the last char of tKeys
   return tKeys
end leExampleKeys

private function leExample pIndex, pWhat
   local tLine
   if sExamples is empty then
      put leExampleTable() into sExamples
   end if
   put line pIndex of sExamples into tLine
   set the itemDelimiter to "|"
   switch pWhat
      case "file"
         return leRoot() & "/" & item 1 of tLine
      case "remaster"
         if item 9 of tLine is empty or there is no file (leRoot() & "/" & item 9 of tLine) then
            return empty
         end if
         return leRoot() & "/" & item 9 of tLine
      case "title"
         -- (a remaster's own title, when this copy of the IDE has it)
         if item 10 of tLine is not empty and there is a file (leRoot() & "/" & item 9 of tLine) then
            return item 10 of tLine
         end if
         return item 2 of tLine
      case "classicTitle"
         return item 2 of tLine
      case "text"
         -- (a remaster of two originals says what it does itself)
         if item 11 of tLine is not empty and there is a file (leRoot() & "/" & item 9 of tLine) then
            return item 11 of tLine
         end if
         return item 3 of tLine
      case "credit"
         return item 4 of tLine
      case "group"
         return item 5 of tLine
      case "icon"
         return item 6 of tLine
      case "accent"
         return lkColor(item 7 of tLine)
      case "tags"
         return item 8 of tLine
   end switch
   return empty
end leExample

-- The examples' index: their groups, and their titles under them
private command leFillExamplesIndex pTerm
   local tKeys, tGroup, tKey, tHtml, tCount, tGroups
   put leExampleKeys() into tKeys
   put leExampleGroups() into tGroups
   put 0 into tCount
   set the itemDelimiter to "|"
   repeat for each line tGroup in tGroups
      put empty into tHtml["items"]
      repeat for each line tKey in tKeys
         if leExample(tKey, "group") is item 1 of tGroup then
            put tKey & return after tHtml["items"]
         end if
      end repeat
      if tHtml["items"] is empty then
         next repeat
      end if
      add 1 to tCount
      put "group" && item 1 of tGroup into sIndexMap[tCount]
      put "<p><font color=" & quote & "#ffffff" & quote & "><b>" & lkEscape(item 2 of tGroup) & "</b></font></p>" after tHtml["all"]
      repeat for each line tKey in tHtml["items"]
         add 1 to tCount
         put tKey into sIndexMap[tCount]
         put "<p>" & lkEscape(leExample(tKey, "title")) & "</p>" after tHtml["all"]
      end repeat
   end repeat
   set the itemDelimiter to comma
   -- the originals of the remasters: a heading, which goes to them
   if leClassicKeys(leExampleKeys(true)) is not empty then
      add 1 to tCount
      put "group classic" into sIndexMap[tCount]
      put "<p><font color=" & quote & "#ffffff" & quote & "><b>Classic</b></font></p>" after tHtml["all"]
   end if
   lock screen
   set the htmlText of field "idx" to tHtml["all"]
   repeat with tCount = 1 to the number of lines of field "idx"
      if word 1 of sIndexMap[tCount] is not "group" then
         set the leftIndent of line tCount of field "idx" to 14
      end if
   end repeat
   leFitIndex
   unlock screen
   leSyncIndex
   if pTerm is not empty then
      put the number of lines of tKeys && "found" into field "navCount"
      if tKeys is empty then
         put "None found" into field "navCount"
      end if
   end if
end leFillExamplesIndex

-- The gallery: a hero, then each group's cards
private command leRenderGallery
   local tKeys, tGroups, tGroup, tKey, tItems, tCols, tGap, tWidth, tHeight, tCol, tX, tCount, tObj
   leHeader empty
   leBeginPage true
   put leExampleKeys() into tKeys
   leHero "EXAMPLES", "Open it, run it, take it apart", \
         "Stacks to learn from: first lessons, guided tours, small apps that each do one thing, and what a stack can do in a browser. Every one is yours to open, run and change.", \
         "Each card says who made the stack. A remastered one shows its scripts beside it, in colour; in the others, choose Object > Stack Script, or any control's script, to read how it works.", \
         "234,88,12|219,39,119|124,58,237", empty, empty
   if tKeys is empty then
      put leHtmlField("p_none", sX, sColW, "<p>No example has" && quote & lkEscape(sSearch["examples"]) & quote && "in it.</p>", 15, lkColor("soft")) into tObj
      add the height of tObj + 20 to sY
      leEndPage
      exit leRenderGallery
   end if
   if sColW >= 940 then
      put 3 into tCols
   else
      put 2 into tCols
   end if
   put 18 into tGap
   put (sColW - (tCols - 1) * tGap) div tCols into tWidth
   put 270 into tHeight
   put leExampleGroups() into tGroups
   set the itemDelimiter to "|"
   repeat for each line tGroup in tGroups
      put empty into tItems
      repeat for each line tKey in tKeys
         if leExample(tKey, "group") is item 1 of tGroup then
            put tKey & return after tItems
         end if
      end repeat
      if tItems is empty then
         next repeat
      end if
      put sY into sCardTop["group" && item 1 of tGroup]
      leSectionHeading "p_head_" & item 1 of tGroup, item 2 of tGroup, item 3 of tGroup
      put 0 into tCol
      repeat for each line tKey in tItems
         put sX + tCol * (tWidth + tGap) into tX
         put sY into sCardTop[tKey]
         leExampleCard tKey, tX, sY, tWidth, tHeight
         add 1 to tCol
         if tCol is tCols then
            put 0 into tCol
            add tHeight + tGap to sY
         end if
      end repeat
      if tCol > 0 then
         add tHeight + tGap to sY
      end if
      add 16 to sY
   end repeat
   set the itemDelimiter to comma
   -- Classic: the originals of the remasters, as their authors made them
   put leClassicKeys(leExampleKeys(true)) into tItems
   if tItems is not empty then
      put sY into sCardTop["group classic"]
      leSectionHeading "p_head_classic", "Classic", \
            "The examples above that were remade in Learn's look, as their authors made them. Each opens as it always has."
      put tCols + 1 into tCols
      put (sColW - (tCols - 1) * tGap) div tCols into tWidth
      put 0 into tCol
      repeat for each line tKey in tItems
         put sX + tCol * (tWidth + tGap) into tX
         put sY into sCardTop["classic" && tKey]
         leClassicCard tKey, tX, sY, tWidth, 128
         add 1 to tCol
         if tCol is tCols then
            put 0 into tCol
            add 128 + tGap to sY
         end if
      end repeat
      if tCol > 0 then
         add 128 + tGap to sY
      end if
      add 16 to sY
   end if
   leEndPage
end leRenderGallery

-- The examples (of pKeys) that this copy of the IDE has both remade and
-- as they were
private function leClassicKeys pKeys
   local tKey, tKeys
   repeat for each line tKey in pKeys
      if leExample(tKey, "remaster") is not empty and there is a file leExample(tKey, "file") then
         put tKey & return after tKeys
      end if
   end repeat
   delete the last char of tKeys
   return tKeys
end leClassicKeys

-- An original's card, under Classic: its icon, its title, who made it, and
-- Open, which opens the stack as its author made it
private command leClassicCard pKey, pLeft, pTop, pWidth, pHeight
   local tName, tAccent, tObj, tRight, tBottom, tLook, tWidth
   put "p_cl" & pKey into tName
   put leExample(pKey, "accent") into tAccent
   put pLeft + pWidth into tRight
   put pTop + pHeight into tBottom
   get lkGroup(tName, lkR(pLeft - 12, pTop - 12, tRight + 12, tBottom + 18), "page")
   put lkBox(tName & "_bg", lkR(pLeft, pTop, tRight, tBottom), lkColor("panel"), 14, tName) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 6, 2, 18
   put lkBox(tName & "_tile", lkR(pLeft + 16, pTop + 16, pLeft + 56, pTop + 56), lkTint(tAccent, 0.14), 12, tName) into tObj
   get lkIcon(tName & "_icon", leExample(pKey, "icon"), lkAccentInk(tAccent), lkR(pLeft + 26, pTop + 26, pLeft + 46, pTop + 46), tName)
   put lkLabel(tName & "_title", lkR(pLeft + 68, pTop + 16, tRight - 16, pTop + 36), leExample(pKey, "classicTitle"), 15, lkColor("ink"), tName) into tObj
   set the textStyle of tObj to "bold"
   lkEllipsize tObj
   put lkLabel(tName & "_credit", lkR(pLeft + 68, pTop + 38, tRight - 16, pTop + 54), leExample(pKey, "credit"), 12, lkColor("soft"), tName) into tObj
   lkEllipsize tObj
   put lkButton(tName & "_open", pLeft + 16, tBottom - 46, 30, "Open the original", "play", "ghost", tAccent, tName, "original" && pKey, 0, "page") into tWidth
   put tName & "_bg" into tLook["bg"]
   put lkColor("line") into tLook["line0"]
   put tAccent into tLook["line1"]
   put true into tLook["shadow"]
   lkLive tName, "page", "original" && pKey, tLook
end leClassicCard

-- An example's card: a banner in its colour with its icon, its title, who
-- made it, what it shows, and Open
private command leExampleCard pKey, pLeft, pTop, pWidth, pHeight
   local tName, tAccent, tObj, tRight, tBottom, tLook, tTag, tX, tTags, tWidth
   put "p_ex" & pKey into tName
   put leExample(pKey, "accent") into tAccent
   put pLeft + pWidth into tRight
   put pTop + pHeight into tBottom
   get lkGroup(tName, lkR(pLeft - 14, pTop - 14, tRight + 14, tBottom + 22), "page")
   put lkBox(tName & "_bg", lkR(pLeft, pTop, tRight, tBottom), lkColor("panel"), 16, tName) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 10, 2, 26
   -- the banner: inside the card's border, rounded at the top, and square
   -- where it meets the card (the white below covers its lower corners)
   put lkBox(tName & "_banner", lkR(pLeft + 1, pTop + 1, tRight - 1, pTop + 120), tAccent, 15, tName) into tObj
   lkGradient tObj, tAccent & "|" & lkMix(tAccent, "255,255,255", 0.35), pLeft & "," & pTop, tRight & "," & (pTop + 96)
   get lkBox(tName & "_seam", lkR(pLeft + 1, pTop + 96, tRight - 1, pTop + 122), lkColor("panel"), 0, tName)
   put lkOval(tName & "_glow", lkR(tRight - 150, pTop - 50, tRight + 10, pTop + 110), "255,255,255", tName) into tObj
   lkGlowFill tObj, "255,255,255", 70
   put lkBox(tName & "_tile", lkR(pLeft + 20, pTop + 20, pLeft + 76, pTop + 76), "255,255,255", 16, tName) into tObj
   set the blendLevel of tObj to 78
   get lkIcon(tName & "_icon", leExample(pKey, "icon"), "255,255,255", lkR(pLeft + 32, pTop + 32, pLeft + 64, pTop + 64), tName)
   put lkLabel(tName & "_title", lkR(pLeft + 20, pTop + 108, tRight - 20, pTop + 132), leExample(pKey, "title"), 17, lkColor("ink"), tName) into tObj
   set the textStyle of tObj to "bold"
   lkEllipsize tObj
   put lkLabel(tName & "_credit", lkR(pLeft + 20, pTop + 134, tRight - 20, pTop + 150), leExample(pKey, "credit"), 12, lkAccentText(tAccent, 0.35), tName) into tObj
   leFit tObj
   put lkLabel(tName & "_text", lkR(pLeft + 20, the bottom of tObj + 6, tRight - 20, tBottom - 52), leExample(pKey, "text"), 13, lkColor("soft"), tName) into tObj
   -- its first two tags, as chips (a remaster's first says so)
   put pLeft + 20 into tX
   put leExample(pKey, "tags") into tTags
   if leExample(pKey, "remaster") is not empty then
      put "remastered" & space before tTags
   end if
   repeat with tTag = 1 to min(2, the number of words of tTags)
      put lkBox(tName & "_chip" & tTag, lkR(tX, tBottom - 38, tX + 10, tBottom - 16), lkTint(tAccent, 0.1), 11, tName) into tObj
      put lkLabel(tName & "_chipText" & tTag, lkR(tX + 10, tBottom - 36, tX + 200, tBottom - 18), word tTag of tTags, 11, lkAccentText(tAccent, 0.3), tName) into tObj
      set the dontWrap of tObj to true
      put the formattedWidth of tObj + 4 into tWidth
      set the width of tObj to tWidth
      set the left of tObj to tX + 10
      set the rect of graphic (tName & "_chip" & tTag) to tX, tBottom - 38, tX + tWidth + 18, tBottom - 16
      leCenterIn tObj, tBottom - 38, tBottom - 16
      add tWidth + 26 to tX
   end repeat
   put lkButton(tName & "_open", tRight - 100, tBottom - 44, 32, "Open", "play", "primary", tAccent, tName, "open" && pKey, 84, "page") into tWidth
   set the left of group (tName & "_open") to tRight - tWidth - 16
   put tName & "_bg" into tLook["bg"]
   put lkColor("line") into tLook["line0"]
   put tAccent into tLook["line1"]
   put true into tLook["shadow"]
   lkLive tName, "page", "open" && pKey, tLook
end leExampleCard

-- The User Guide PDF, as Help > User Guide PDF opens it
private command leOpenGuidePdf
   local tError
   try
      revIDELaunchResource "User Guide"
   catch tError
      leToast "The User Guide PDF could not be opened.", "bad"
   end try
end leOpenGuidePdf

-- Opens an example, as the user would: its remaster when there is one,
-- or (pOriginal) the stack as its author made it
private command leOpenExample pKey, pOriginal
   local tFile, tError, tFresh, tOpen, tTitle
   put leExample(pKey, "remaster") into tFile
   if pOriginal or tFile is empty then
      put leExample(pKey, "file") into tFile
   end if
   if there is no file tFile then
      leToast "That stack is not in this copy of the IDE.", "warn"
      exit leOpenExample
   end if
   lePutAway
   -- (an example that is in memory already, open or not, may hold changes
   -- of the user's own: Learn neither counts it unchanged nor takes it
   -- out of memory, unless Learn opened it before)
   put true into tFresh
   repeat for each line tOpen in the mainStacks
      if the effective filename of stack tOpen is tFile then
         put false into tFresh
         exit repeat
      end if
   end repeat
   try
      -- (an example is opened to be run: with the Pointer tool, which the
      -- IDE starts with, its buttons would not answer a click)
      choose browse tool
      go stack tFile
      if tFresh and tFile is not among the lines of sOpened then
         put tFile & return after sOpened
      end if
      -- (the IDE counts the field that a window gives the focus to as a
      -- change, so closing an original that was only looked at asks to
      -- save it, as it always has: Learn leaves that to the IDE, since it
      -- cannot tell that change from one the user made. A remaster gives
      -- the focus to no field, tools/examples/README.md)
   catch tError
      -- (named as the card names the stack that failed: the original's
      -- own title, when it was the original)
      if pOriginal then
         put leExample(pKey, "classicTitle") into tTitle
      else
         put leExample(pKey, "title") into tTitle
      end if
      leToast tTitle && "could not open:" && lkErrorText(tError), "bad"
   end try
end leOpenExample

-- The examples Learn opened that are closed now, their windows and their
-- substacks', are taken out of memory, as File > Close and Remove From
-- Memory would, unless they hold changes not saved (leEdited). A closed
-- stack stays in memory, and the IDE stops on a warning when a stack
-- loads with the name of one there, a substack's too: two examples that
-- share the name of a substack would stop on it
private command lePutAway
   local tFile, tOpen, tStack, tBusy, tSub, tKeep, tError
   repeat for each line tFile in sOpened
      put empty into tStack
      repeat for each line tOpen in the mainStacks
         if the effective filename of stack tOpen is tFile then
            put the long id of stack tOpen into tStack
            exit repeat
         end if
      end repeat
      if tStack is empty then
         next repeat
      end if
      put the mode of tStack is not 0 into tBusy
      repeat for each line tSub in the substacks of tStack
         if the mode of stack tSub of tStack is not 0 then
            put true into tBusy
         end if
      end repeat
      if tBusy or leEdited(tStack) then
         put tFile & return after tKeep
         next repeat
      end if
      try
         delete tStack
      catch tError
         put tFile & return after tKeep
      end try
   end repeat
   put tKeep into sOpened
end lePutAway

-- Scrolls the gallery to an example's card, or a group's heading
private command leJumpTo pKey
   local tTop
   put sCardTop[pKey] into tTop
   if tTop is empty then
      exit leJumpTo
   end if
   put pKey into sPage["examples"]
   leSyncIndex
   set the vScroll of group "body" to max(0, tTop - the top of group "body" - 24)
end leJumpTo

-- Next and Back in the gallery go from card to card
private command leStepExample pWhere
   local tKeys, tAt, tIndex
   put leExampleKeys() into tKeys
   if tKeys is empty then
      exit leStepExample
   end if
   put lineOffset(sPage["examples"], tKeys) into tAt
   -- (lineOffset matches part of a line: check it is the whole line)
   if tAt > 0 and line tAt of tKeys is not sPage["examples"] then
      put 0 into tAt
      repeat with tIndex = 1 to the number of lines of tKeys
         if line tIndex of tKeys is sPage["examples"] then
            put tIndex into tAt
            exit repeat
         end if
      end repeat
   end if
   switch pWhere
      case "next"
         put min(the number of lines of tKeys, tAt + 1) into tAt
         break
      case "prev"
         put max(1, tAt - 1) into tAt
         break
      default
         exit leStepExample
   end switch
   leJumpTo line tAt of tKeys
end leStepExample
