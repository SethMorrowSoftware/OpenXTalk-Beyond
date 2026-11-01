script "revHub"
-- OXT-Beyond Home: one window for the IDE's welcome, its lessons and its
-- examples.
--
-- Before Home there were three windows that a newcomer met one after the
-- other, each with a sidebar of its own: Home (palettes/web home, the
-- welcome and a tour of live demos), the xTalk Academy (palettes/academy,
-- the course in coding) and Learn (palettes/learn, the how-to lessons,
-- the guides and the examples). This window holds all three, with one
-- sidebar of five places:
--
--    home       Home's welcome and its tour (revWebHome)
--    academy    the xTalk Academy's courses (revAcademy)
--    howto      Learn's lessons, short how-tos (revLearn)
--    guides     Learn's guides (revLearn)
--    examples   Learn's gallery of examples (revLearn)
--
-- The three stacks are not copied here. Each place is drawn by the stack
-- that always drew it, used as this stack's behavior (and the Academy and
-- Learn have revLearnKit as theirs, so the chain is this stack, the place's
-- stack, the kit). A behavior's script locals belong to the object that
-- uses it, and its "me" is that object, so each stack draws into this
-- window just as it drew into its own, and a new place starts afresh.
-- Going to a place of another stack takes the old one's controls away and
-- puts the new stack in as the behavior (hbSwap). A stack hosted here
-- knows it by the cHubPlaces of me, and then draws this window's sidebar
-- (lkHubHead in the kit, hmHubHead in Home) and leaves the window's size
-- and title to this script.
--
-- Each stack still opens on its own, as before, when its file is opened
-- (the web IDE's site, and a test, do). The IDE's ways in (Help, the
-- toolbar, revLearnShow, revAcademyShow, revWebIDEShowHome) come here
-- (revHubShow).
--
-- The hosted stack is told what happens through four messages, which a
-- stack handles only when it is hosted:
--    revHubAttach pPlace, pPage   build the window's controls
--    revHubStart pPlace, pPage    the window is up: start its timers and
--                                 show the page
--    revHubNavigate pPlace, pPage go to a place it draws, or a page of it
--    revHubDetach                 stop its timers, keep what it keeps
--
-- It is a script-only stack, so it keeps no controls, and its name begins
-- with "rev", so the IDE treats it as one of its own windows.

constant kWidth = 1280
constant kHeight = 800
-- (Home's pages are 776 wide, right of a 248 sidebar; the Academy's
-- three columns need 1000; and the smallest screens are 1024 wide)
constant kMinWidth = 1024
constant kMinHeight = 640

-- The place in front, the stack that draws it, the page asked for each
-- place, where hbPlace put the window, and the pending swap
local sPlace, sModule, sPages, sPlaced, sPending

################################################################################
#
# Places
#

-- The five places, in the sidebar's order: key, label, icon and accent.
-- The hosted stacks read them from the cHubPlaces of me.
private function hbPlaces
   return "home|Home|house|indigo" & return & \
         "academy|Academy|graduation-cap|emerald" & return & \
         "howto|How-to|lightbulb|violet" & return & \
         "guides|Guides|book-open-text|sky" & return & \
         "examples|Examples|layers|orange"
end hbPlaces

-- The place a name stands for: a place's key, or a name the IDE used for
-- one before Home (Learn's sections, Help's items, the old palettes). An
-- unknown name is Home's welcome.
function revHubPlace pName
   switch toLower(word 1 to -1 of pName)
      case "academy"
      case "xtalk academy"
      case "tutorials"
      case "tutorial"
         return "academy"
      case "howto"
      case "how-to"
      case "lessons"
         return "howto"
      case "guides"
         return "guides"
      case "examples"
      case "demos"
      case "sample stacks"
         return "examples"
      default
         return "home"
   end switch
end revHubPlace

-- A place that the stack pModule draws: pPlace if it draws it, else its
-- first
private function hbPlaceOf pModule, pPlace
   local tLine
   if hbModule(pPlace) is pModule then
      return pPlace
   end if
   set the itemDelimiter to "|"
   repeat for each line tLine in hbPlaces()
      if hbModule(item 1 of tLine) is pModule then
         return item 1 of tLine
      end if
   end repeat
   return "home"
end hbPlaceOf

-- The stack that draws a place, and its file in the Toolset
private function hbModule pPlace
   switch pPlace
      case "home"
         return "revWebHome"
      case "academy"
         return "revAcademy"
      default
         return "revLearn"
   end switch
end hbModule

private function hbModuleFile pModule
   local tToolset
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tToolset
   switch pModule
      case "revWebHome"
         return tToolset & "/palettes/web home/revwebhome.livecodescript"
      case "revAcademy"
         return tToolset & "/palettes/academy/revacademy.livecodescript"
      case "revLearnKit"
         return tToolset & "/palettes/learn/revlearnkit.livecodescript"
      default
         return tToolset & "/palettes/learn/revlearn.livecodescript"
   end switch
end hbModuleFile

-- The place in front and the stack that draws it, for tests and for the
-- IDE (empty while the window is closed)
function revHubCurrent
   if the mode of me is 0 then
      return empty
   end if
   return sPlace & comma & sModule
end revHubCurrent

################################################################################
#
# Opening, going places, closing
#

-- Opens Home at a place (any name revHubPlace knows) and a page of it, or
-- brings it to the front and goes there
command revHubShow pPlace, pPage
   put revHubPlace(pPlace) into pPlace
   if the mode of me is 0 then
      put pPlace into sPlace
      put pPage into sPages[pPlace]
      modeless me
   else
      go me
      revHubGo pPlace, pPage
   end if
end revHubShow

-- Goes to a place, and a page of it. A place of the stack in front is a
-- step within it; another stack's place is a swap, which waits for the
-- handler that asked for it to end, because it takes away the controls
-- (and the behavior) that handler may be running in.
command revHubGo pPlace, pPage
   put revHubPlace(pPlace) into pPlace
   if the mode of me is 0 then
      revHubShow pPlace, pPage
      exit revHubGo
   end if
   put pPage into sPages[pPlace]
   if hbModule(pPlace) is sModule then
      put pPlace into sPlace
      set the cHubPlace of me to pPlace
      dispatch "revHubNavigate" to me with pPlace, pPage
      exit revHubGo
   end if
   if sPending is not empty then
      cancel sPending
   end if
   send "hbSwap" && quote & pPlace & quote to me in 0 milliseconds
   put the result into sPending
end revHubGo

on preOpenStack
   local tSaved
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   set the label of me to "OXT-Beyond Home"
   set the resizable of me to true
   set the minWidth of me to kMinWidth
   set the minHeight of me to kMinHeight
   set the destroyStack of me to true
   set the cHubPlaces of me to hbPlaces()
   if sPlace is empty then
      put "home" into sPlace
   end if
   -- (closed, the window can stay in memory with the last place's
   -- controls and behavior: each opening starts from none)
   hbClear
   hbPlace
   hbAttach sPlace, sPages[sPlace]
   -- (a script-only stack is made invisible when it is loaded)
   show me
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
   -- (not passed: the hosted stack's own preOpenStack would place and
   -- build a window of its own)
end preOpenStack

on openStack
   dispatch "revHubStart" to me with sPlace, sPages[sPlace]
   -- (on Linux a resizable window can open at its minimum size, whatever
   -- its rect was: once it is up, it goes where hbPlace put it)
   send "hbKeepPlace" to me in 250 milliseconds
end openStack

on hbKeepPlace
   if the mode of me is 0 or sPlaced is empty then
      exit hbKeepPlace
   end if
   if the rect of me is not sPlaced then
      set the rect of me to sPlaced
   end if
end hbKeepPlace

on closeStack
   if sPending is not empty then
      cancel sPending
      put empty into sPending
   end if
   dispatch "revHubDetach" to me
   -- (and whatever the place left waiting: closed, nothing runs here)
   hbCancelMessages
   -- (and, once the handler that closed it is done, no place: the stack
   -- that drew the last one may be running it)
   send "hbClearClosed" to me in 0 milliseconds
   -- (not passed, as preOpenStack is not)
end closeStack

on hbClearClosed
   if the mode of me is 0 then
      hbClear
   end if
end hbClearClosed

-- The swap revHubGo asked for
on hbSwap pPlace
   local tSaved, tRect
   put empty into sPending
   if the mode of me is 0 then
      exit hbSwap
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   put the rect of me into tRect
   lock screen for visual effect
   dispatch "revHubDetach" to me
   hbClear
   put pPlace into sPlace
   hbAttach pPlace, sPages[pPlace]
   -- (a stack's build may set the window's size: this one keeps its own)
   if the rect of me is not tRect then
      set the rect of me to tRect
   end if
   dispatch "revHubStart" to me with pPlace, sPages[pPlace]
   unlock screen with visual effect "dissolve" very fast
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end hbSwap

-- No place: no controls, no behavior, and no message waiting for one
private command hbClear
   local tError
   hbCancelMessages
   lock messages
   repeat while the number of controls of this card of me > 0
      delete control 1 of this card of me
   end repeat
   unlock messages
   -- (a behavior whose script is running cannot be changed: when the
   -- stack that drew the last place opens this window again, from one of
   -- its own handlers (revLearnShow), it stays, and hbAttach keeps it if
   -- it draws the new place too)
   try
      set the behavior of me to empty
   catch tError
   end try
   put empty into sModule
end hbClear

-- Puts in the stack that draws pPlace, as this stack's behavior, and has
-- it build the window
private command hbAttach pPlace, pPage
   local tModule, tPlace, tError
   put hbModule(pPlace) into tModule
   hbLoad tModule
   if tModule is not "revWebHome" and the behavior of stack tModule is empty then
      hbLoad "revLearnKit"
      set the behavior of stack tModule to the long id of stack "revLearnKit"
   end if
   if the behavior of me is not the long id of stack tModule then
      try
         set the behavior of me to the long id of stack tModule
      catch tError
         -- (the old one is running, as hbClear says: it draws its own
         -- place for now, and the swap waits for it to finish)
         put the short name of the behavior of me into tModule
         put hbPlaceOf(tModule, pPlace) into tPlace
         send "hbSwap" && quote & pPlace & quote to me in 0 milliseconds
         put the result into sPending
         put tPlace into pPlace
         put pPlace into sPlace
      end try
   end if
   set the cHubPlace of me to pPlace
   put tModule into sModule
   dispatch "revHubAttach" to me with pPlace, pPage
end hbAttach

-- Loads a stack, by its file, unless it is in memory
private command hbLoad pModule
   if there is a stack pModule then
      exit hbLoad
   end if
   -- (naming the file loads the stack, without opening it)
   get the short name of stack hbModuleFile(pModule)
end hbLoad

-- The old place's timers, gone with it: every message waiting for this
-- stack is cancelled
private command hbCancelMessages
   local tLine, tMe
   put the long id of me into tMe
   repeat for each line tLine in the pendingMessages
      if item 4 to -1 of tLine is tMe then
         cancel item 1 of tLine
      end if
   end repeat
end hbCancelMessages

-- Below the menu bar, as large as the screen allows
private command hbPlace
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
end hbPlace

################################################################################
#
# The sidebar's places
#

-- A click on one of the places (lkHubHead and hmHubHead make them with
-- the action "hub <place>"): the kit's stacks send it as lkAction, and
-- Home calls revHubGo
on lkAction pAction
   if word 1 of pAction is "hub" then
      revHubGo word 2 of pAction
      exit lkAction
   end if
   pass lkAction
end lkAction
