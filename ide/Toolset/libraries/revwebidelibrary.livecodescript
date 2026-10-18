script "revWebIDELibrary"
-- OXT-Beyond: the IDE in a web browser.
--
-- The web IDE (tools/web-ide) is this IDE, run in a web page by the
-- development engine built for the web (engine.gyp's development-web).
-- Home loads this library only there (revEnvironmentIsWeb), and the
-- IDE's own scripts call it only after asking revEnvironmentIsWeb(), so
-- nothing here runs in the desktop IDE.
--
-- What is different in a browser:
--
-- Files. The engine's file system is in the page. Its home folder ("~")
-- is kept in the browser's storage between visits, and the user's stacks
-- are kept in its Documents folder: Save and Save As write there. A file
-- the user picks with Open Stack arrives in the uploads folder, which the
-- page does not keep, so it is moved into Documents first (under a name no
-- stack there has), and saving it keeps it. A file written into the
-- downloads folder goes to the user as a download: File > Download Stack
-- gives the user a copy of the stack that way.
--
-- Menus. What a browser cannot do is left out of the IDE's menus
-- (revWebIDEMenu, from revMenubar's modifyMenu): building desktop and
-- mobile standalones and their simulators, the Extension Builder (it
-- compiles with lc-compile, a program), quitting (closing the page does),
-- update checks (the page is the latest web IDE), and the guides that the
-- page does not carry.
--
-- The menu bar spans the top of the page, and follows the page's width
-- (revWebIDEFitMenubar). It is the page's header, as a web application's
-- is: one light surface for the menus and the toolbar, whose flat icons
-- (revMenubar's images-web) show a toggle that is on in the accent colour
-- of the page. The edition's upgrade button, which the desktop's menu bar
-- (cut off after Sample Stacks) never shows either, is hidden. On a page
-- too narrow for the toolbar's labels, the toolbar shows its icons only,
-- each with its label as its tooltip (revWebIDEFitToolbar), rather than
-- cutting its last buttons off at the page's edge.
--
-- Windows. No window manager keeps the IDE's palettes on the screen, so
-- revIDEEnsureOnscreen keeps them on the page, and a stack the user opens
-- is kept below the menu bar, as the desktop engine keeps it
-- (revWebIDEKeepOnPage). When the page changes size (full screen and
-- back), every window is brought back onto it (revWebIDEKeepWindowsOnPage):
-- the user's stacks are only moved, never resized.
--
-- Home. The web IDE opens with Home (palettes/web home), a welcome stack
-- in the spirit of HyperCard's, which shows what a stack can do in a
-- browser and leads to the lessons, the examples and the Dictionary. Its
-- "Show Home at startup" switch keeps the preference cWebHomeAtStartup
-- (empty, as in a new profile, means show it), and Help > Welcome to
-- OXT-Beyond opens it again.
--
-- Public handlers:
--    revWebIDEMenu(pMenuName, pMenu)
--       The text of one of the IDE's menus as the web IDE shows it.
--    revWebIDEStacksFolder()
--       The folder the user's stacks are kept in (Documents in the home
--       folder), made if it is not there.
--    revWebIDEKeepFile(pPath)
--       Moves a file the user picked into the stacks folder and returns
--       its new path; any other path is returned as it is.
--    revWebIDESavePath(pPath)
--       Where Save As saves to, for the path ask file answered.
--    revWebIDEDownloadStack pStackID
--       Gives the user a copy of a stack's file as a download.
--    revWebIDEFitMenubar
--       Spans the menu bar across the top of the page.
--    revWebIDEFitToolbar
--       Shows the toolbar's labels only when the page has room for them.
--    revWebIDEKeepOnPage pStack [, pArea [, pMoveOnly]]
--       Keeps a window on the page, below the menu bar.
--    revWebIDEKeepWindowsOnPage
--       Keeps every open window on the page.
--    revWebIDEShowHome
--       Opens Home, or brings it to the front.
--    revWebIDEStartupHome
--       Opens Home when the IDE has started, unless the user said not to.

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   -- Part of the IDE even though it is loaded on demand
   set the _ideoverride of me to true
   if the long id of me is not among the lines of the backScripts then
      insert the script of me into back
   end if
   revIDESubscribe "ideDesktopChanged"
   revIDESubscribe "ideOpenStack"
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if
   revIDEUnsubscribe "ideDesktopChanged"
   revIDEUnsubscribe "ideOpenStack"
   remove the script of me from back
end extensionFinalize

################################################################################
#
# Menus
#

/*
The text of one of the IDE's menus as the web IDE shows it: the items of
what a browser cannot do left out, with their submenus, File's Download
Stack added after Save As, and Help's Welcome to OXT-Beyond added first.

pMenuName (String): The name of the menu (File, Edit, Tools, ...).

pMenu (String): The menu's text as revMenubar builds it.

Returns (String): The menu's text for the web.
*/
function revWebIDEMenu pMenuName, pMenu
   local tLeaveOut
   switch pMenuName
      case "File"
         put "Standalone Application Settings...,Save as Standalone Application...," & \
               "Quit,Exit" into tLeaveOut
         break
      case "Tools"
         put "Extension Builder" into tLeaveOut
         break
      case "Development"
         put "Test,Test Target" into tLeaveOut
         break
      case "Help"
         put "Guides,Release Notes,Check for Updates" into tLeaveOut
         break
   end switch
   if tLeaveOut is not empty then
      put __webMenuLeaveOut(pMenu, tLeaveOut) into pMenu
   end if
   if pMenuName is "File" then
      put __webMenuAddDownload(pMenu) into pMenu
   end if
   if pMenuName is "Help" then
      -- (revMenubarHelpMenuPick picks it)
      put "Welcome to OXT-Beyond" & return & "-" & return before pMenu
   end if
   return pMenu
end revWebIDEMenu

-- The name of a menu item as its menu's pick handler sees it: without its
-- submenu tabs, its disabled and check marks, its "&" and its shortcut
private function __webMenuItemName pLine
   local tName
   put pLine into tName
   repeat while char 1 of tName is tab
      delete char 1 of tName
   end repeat
   repeat
      if char 1 of tName is "(" then
         delete char 1 of tName
      else if char 1 of tName is "!" and char 2 of tName is among the items of "c,n,r,u" then
         delete char 1 to 2 of tName
      else
         exit repeat
      end if
   end repeat
   set the itemDelimiter to "/"
   put item 1 of tName into tName
   replace "&" with empty in tName
   return tName
end __webMenuItemName

private function __webMenuDepth pLine
   local tDepth
   put 0 into tDepth
   repeat while char tDepth + 1 of pLine is tab
      add 1 to tDepth
   end repeat
   return tDepth
end __webMenuDepth

-- Leaves out the items named, with their submenus, and then any divider
-- that is first or last, or follows another; the text ends with a return,
-- as modifyMenu leaves it
private function __webMenuLeaveOut pMenu, pNames
   local tKept, tSkipDepth, tDepth, tLine
   put -1 into tSkipDepth
   repeat for each line tLine in pMenu
      put __webMenuDepth(tLine) into tDepth
      if tSkipDepth >= 0 and tDepth > tSkipDepth then
         next repeat
      end if
      put -1 into tSkipDepth
      if __webMenuItemName(tLine) is among the items of pNames then
         put tDepth into tSkipDepth
         next repeat
      end if
      put tLine & return after tKept
   end repeat

   local tTidy, tLastWasDivider, tPending
   put true into tLastWasDivider
   repeat for each line tLine in tKept
      if tLine is "-" then
         -- (a divider goes in only once an item follows it)
         if not tLastWasDivider then
            put true into tPending
         end if
         put true into tLastWasDivider
         next repeat
      end if
      if tPending and __webMenuDepth(tLine) is 0 then
         put "-" & return after tTidy
         put false into tPending
      end if
      if __webMenuDepth(tLine) is 0 then
         put false into tLastWasDivider
      end if
      put tLine & return after tTidy
   end repeat
   return tTidy
end __webMenuLeaveOut

-- File > Download Stack, after Save As (revMenubarFileMenuPick picks it)
private function __webMenuAddDownload pMenu
   local tCanDownload, tItem, tLineNumber
   put the mode of the topStack is 1 and not revIDEStackIsIDEStack(the topStack) into tCanDownload
   if tCanDownload then
      put "Download Stack" into tItem
   else
      put "(Download Stack" into tItem
   end if
   repeat with tLineNumber = 1 to the number of lines of pMenu
      if __webMenuItemName(line tLineNumber of pMenu) is "Save As..." then
         put return & tItem after line tLineNumber of pMenu
         return pMenu
      end if
   end repeat
   return pMenu
end __webMenuAddDownload

################################################################################
#
# Files
#

/*
The folder the web IDE keeps the user's stacks in: Documents, in the
engine's home folder, which the browser keeps between visits.

Returns (String): The folder's path.
*/
function revWebIDEStacksFolder
   local tFolder
   put specialFolderPath("documents") into tFolder
   if tFolder is empty then
      -- (the engine answers only for a folder that is there)
      put specialFolderPath("home") & "/Documents" into tFolder
      create folder tFolder
   end if
   return tFolder
end revWebIDEStacksFolder

/*
Moves a file the user picked (answer file copies it into the uploads
folder, which the page does not keep) into the stacks folder, under a
name that no file there has: a stack with the same name as one kept
there becomes "<name> 2", "<name> 3" and so on.

pPath (String): The path answer file returned.

Returns (String): The file's new path; a path outside the uploads folder,
or a file that could not be moved, as it was.
*/
function revWebIDEKeepFile pPath
   local tUploads
   put specialFolderPath("uploads") into tUploads
   if tUploads is empty or not (pPath begins with tUploads & slash) then
      return pPath
   end if

   local tName, tFolder, tPath, tBase, tExtension, tNumber
   set the itemDelimiter to slash
   put item -1 of pPath into tName
   put revWebIDEStacksFolder() into tFolder
   put tFolder & slash & tName into tPath
   if there is a file tPath then
      set the itemDelimiter to "."
      if the number of items of tName > 1 then
         put "." & item -1 of tName into tExtension
         put item 1 to -2 of tName into tBase
      else
         put tName into tBase
      end if
      put 2 into tNumber
      repeat while there is a file tPath
         put tFolder & slash & tBase && tNumber & tExtension into tPath
         add 1 to tNumber
      end repeat
   end if

   rename file pPath to tPath
   if there is not a file tPath then
      return pPath
   end if
   return tPath
end revWebIDEKeepFile

/*
Where Save As saves a stack in the web IDE: ask file answers a path in
the downloads folder (writing a file there gives it to the user), and
the stack is kept in the stacks folder instead, under the name the user
typed. File > Download Stack gives the user a copy.

pPath (String): The path ask file answered.

Returns (String): The path to save to.
*/
function revWebIDESavePath pPath
   local tDownloads
   put specialFolderPath("downloads") into tDownloads
   if pPath is empty or tDownloads is empty or not (pPath begins with tDownloads & slash) then
      return pPath
   end if
   set the itemDelimiter to slash
   return revWebIDEStacksFolder() & slash & item -1 of pPath
end revWebIDESavePath

/*
Gives the user a copy of a stack's file as a download (File > Download
Stack). The stack is saved first, as File > Save does (a stack that was
never saved is saved into the stacks folder under a name the user
chooses), and its file is then written into the downloads folder, which
gives it to the user.

pStackID (String): The long id of the stack (or a substack of it).
*/
command revWebIDEDownloadStack pStackID
   local tMainStack, tPath
   put the long id of stack (the mainStack of pStackID) into tMainStack
   revIDEActionSaveStack tMainStack
   if the result is "Cancelled" then
      exit revWebIDEDownloadStack
   end if
   put the effective filename of tMainStack into tPath
   if tPath is empty or there is not a file tPath then
      exit revWebIDEDownloadStack
   end if

   local tDownloads, tData
   put specialFolderPath("downloads") into tDownloads
   if tDownloads is empty then
      put "/downloads" into tDownloads
      create folder tDownloads
   end if
   put URL ("binfile:" & tPath) into tData
   set the itemDelimiter to slash
   put tData into URL ("binfile:" & tDownloads & slash & item -1 of tPath)
   if the result is not empty then
      answer error "The stack could not be downloaded:" && the result
   end if
end revWebIDEDownloadStack

################################################################################
#
# The menu bar
#

-- The header's colours: its surface (the page's light text colour, which
-- the active window's title bar fades to), the menus' text, and the
-- toolbar's labels, the ink of its icons
constant kHeaderColor = "244,246,248"
constant kMenuTextColor = "23,32,42"
constant kToolbarTextColor = "59,69,84"

-- The room the page's full screen button takes at the right end of the
-- header (index.html's #fullscreen: 34 pixels wide, 14 from the edge)
constant kFullscreenRoom = 56

-- The right of the toolbar's last button, as laid out with its labels
local sToolbarRight
-- True while revWebIDEFitToolbar lays the toolbar out again
local sFittingToolbar

/*
Spans the menu bar across the top of the page, as a web application's
is: from the left edge to the right one, with its toolbar where it is,
and gives it the look of the page's header.
*/
command revWebIDEFitMenubar
   if there is not a stack "revMenubar" then
      exit revWebIDEFitMenubar
   end if
   local tScreen, tMenus
   put the screenRect into tScreen
   lock screen
   lock messages
   set the rect of stack "revMenubar" to item 1 of tScreen, item 2 of tScreen, \
         item 3 of tScreen, item 2 of tScreen + the height of stack "revMenubar"
   -- The row of menus and the line under it, as revMenubar's layoutMenu
   -- sets them for the toolbar's width
   put the long id of group "revMenuBar" of card 1 of stack "revMenubar" into tMenus
   set the width of tMenus to the width of stack "revMenubar"
   set the left of tMenus to 0
   if there is a button "Divider" of tMenus then
      set the width of button "Divider" of tMenus to the width of stack "revMenubar"
      set the left of button "Divider" of tMenus to 0
   end if
   styleMenubar
   unlock messages
   -- Once whatever laid the toolbar out has finished (revMenubar's
   -- preOpenStack moves buttons after its layoutMenu)
   if sFittingToolbar is not true and \
         "revWebIDEFitToolbar" is not in the pendingMessages then
      send "revWebIDEFitToolbar" to me in 0 milliseconds
   end if
   unlock screen
end revWebIDEFitMenubar

/*
Shows the toolbar's labels only when the page has room for them: on a
page too narrow for the toolbar with its labels (and the page's full
screen button after it), the toolbar shows its icons only, closer
together, with each label as its button's tooltip; on a page wide enough
again, it shows the labels, laid out as before. Only a toolbar that the
preferences show with icons and labels changes, and the preferences stay
as they are.
*/
command revWebIDEFitToolbar
   local tStack, tToolbar, tShowNames, tFits, tIndex, tButton
   if sFittingToolbar is true or there is not a stack "revMenubar" then
      exit revWebIDEFitToolbar
   end if
   if revIDEGetPreference("cToolbarIcons") is false or \
         revIDEGetPreference("cToolbarText") is false then
      exit revWebIDEFitToolbar
   end if
   put the long id of stack "revMenubar" into tStack
   if there is not a group "toolbar" of card 1 of tStack then
      exit revWebIDEFitToolbar
   end if
   put the long id of group "toolbar" of card 1 of tStack into tToolbar
   if there is not a button "Errors" of tToolbar or \
         there is not a button "Dictionary" of tToolbar then
      exit revWebIDEFitToolbar
   end if
   -- The width it needs is measured while it shows its labels
   put the showName of button "Errors" of tToolbar into tShowNames
   if tShowNames then
      put __webToolbarRight(tToolbar) into sToolbarRight
   end if
   put sToolbarRight + kFullscreenRoom <= \
         item 3 of the screenRect - item 1 of the screenRect into tFits
   if tFits and tShowNames then
      exit revWebIDEFitToolbar
   end if
   lock screen
   lock messages
   if tFits is not tShowNames then
      repeat with tIndex = 1 to the number of buttons of tToolbar
         put the long id of button tIndex of tToolbar into tButton
         set the showName of tButton to tFits
         if tFits then
            if the toolTip of tButton is the label of tButton then
               set the toolTip of tButton to empty
            end if
         else if the toolTip of tButton is empty then
            set the toolTip of tButton to the label of tButton
         end if
      end repeat
   end if
   if not tFits then
      -- Packed again whenever it is laid out, as the IDE lays it out for
      -- its labels (the width of a button is its label's, shown or not)
      __webPackToolbar tToolbar
      unlock messages
      unlock screen
      exit revWebIDEFitToolbar
   end if
   unlock messages
   -- Laid out for the labels as revMenubar's preOpenStack lays it out:
   -- Dictionary after Errors, and Sample Stacks after Dictionary
   -- (tMenuBar_AdjustWDSize)
   put true into sFittingToolbar
   dispatch "layoutMenu" to tStack
   set the topLeft of button "Dictionary" of tToolbar to \
         the left of button "Errors" of tToolbar + 80, \
         the top of button "Errors" of tToolbar
   dispatch "tMenuBar_AdjustWDSize" to tStack
   put false into sFittingToolbar
   unlock screen
end revWebIDEFitToolbar

-- The toolbar's buttons and dividers that are shown, packed from its
-- left in the order they are in, each button as wide as its icon needs
-- and each divider in revMenubar's padding (kPadding)
constant kIconButtonWidth = 44
constant kToolbarPadding = 10

private command __webPackToolbar pToolbar
   local tControls, tIndex, tControl, tLine, tLeft, tDividerLeft, tRect
   set the itemDelimiter to tab
   repeat with tIndex = 1 to the number of controls of pToolbar
      put the long id of control tIndex of pToolbar into tControl
      if the visible of tControl and (word 1 of tControl is "button" or \
            the short name of tControl begins with "Divide") then
         put the left of tControl & tab & tControl & return after tControls
      end if
   end repeat
   sort lines of tControls numeric by item 1 of each
   put item 1 of line 1 of tControls into tLeft
   repeat for each line tLine in tControls
      put item 2 of tLine into tControl
      if word 1 of tControl is "button" then
         put tLeft & comma & the top of tControl & comma & \
               (tLeft + kIconButtonWidth) & comma & the bottom of tControl into tRect
         add kIconButtonWidth to tLeft
      else
         -- A divider keeps its width, in the middle of its padding
         put tLeft + (kToolbarPadding - the width of tControl) div 2 into tDividerLeft
         put tDividerLeft & comma & the top of tControl & comma & \
               (tDividerLeft + the width of tControl) & comma & \
               the bottom of tControl into tRect
         add kToolbarPadding to tLeft
      end if
      if the rect of tControl is not tRect then
         set the rect of tControl to tRect
      end if
   end repeat
end __webPackToolbar

-- The right of the toolbar's last button shown
private function __webToolbarRight pToolbar
   local tRight, tControl
   put 0 into tRight
   repeat with tControl = 1 to the number of buttons of pToolbar
      if the visible of button tControl of pToolbar then
         put max(tRight, the right of button tControl of pToolbar) into tRight
      end if
   end repeat
   return tRight
end __webToolbarRight

-- One surface for the menus and the toolbar (the menus otherwise sit on
-- a white strip of their own), and nothing after the toolbar's last
-- button: revMenubar's layoutMenu lays out the edition's upgrade button
-- and the dividers around the buttons it hides (Tutorials, Resources,
-- Test) there, which the desktop never shows because it cuts the menu
-- bar off after Sample Stacks (tMenuBar_AdjustWDSize). Each property is
-- set only when it differs, as this runs on every layout.
private command styleMenubar
   local tStack, tToolbar, tRight, tControl
   put the long id of stack "revMenubar" into tStack
   if the backColor of tStack is not kHeaderColor then
      set the backColor of tStack to kHeaderColor
   end if
   if the textColor of group "revMenuBar" of card 1 of tStack is not kMenuTextColor then
      set the textColor of group "revMenuBar" of card 1 of tStack to kMenuTextColor
   end if
   if there is not a group "toolbar" of card 1 of tStack then
      exit styleMenubar
   end if
   put the long id of group "toolbar" of card 1 of tStack into tToolbar
   if the textColor of tToolbar is not kToolbarTextColor then
      set the textColor of tToolbar to kToolbarTextColor
   end if
   if there is a group "upgrade" of card 1 of tStack then
      hide group "upgrade" of card 1 of tStack
   end if
   -- Every divider beyond the last button shown
   put __webToolbarRight(tToolbar) into tRight
   repeat with tControl = 1 to the number of images of tToolbar
      if the short name of image tControl of tToolbar begins with "Divide" \
            and the left of image tControl of tToolbar > tRight then
         hide image tControl of tToolbar
      end if
   end repeat
end styleMenubar

################################################################################
#
# Windows
#

/*
Keeps a window on the page, as a desktop's window manager keeps it on the
screen: a resizable window wider or taller than the page is made narrower
or shorter, as far as its minimum size lets it, and then the window is
moved onto the page. A window that is still too wide keeps its left edge
on the page, and one too tall its title bar.

pStack (String): The name of the stack, or its long id.

pArea (String): The rect of the page to keep it in; by default the page
below the menu bar.

pMoveOnly (Boolean): True to move the window and never resize it.
*/
command revWebIDEKeepOnPage pStack, pArea, pMoveOnly
   local tStack
   if there is a stack pStack then
      put the long id of stack pStack into tStack
   else if pStack begins with "stack " and exists(pStack) then
      put the long id of pStack into tStack
   else
      exit revWebIDEKeepOnPage
   end if
   if the short name of tStack is "revMenubar" then
      exit revWebIDEKeepOnPage
   end if

   local tPage, tTitleBar, tWidth, tHeight, tResizable
   if pArea is empty then
      put the screenRect into tPage
      if there is a stack "revMenubar" and the visible of stack "revMenubar" then
         put max(item 2 of tPage, the bottom of stack "revMenubar") into item 2 of tPage
      end if
   else
      put pArea into tPage
   end if
   -- The title bar the page draws above the stack, as the web engine
   -- decides it (MCStack::sethints in engine/src/em-stack.cpp, and
   -- engine/src/em-dc.js): none when the decorations leave out the title
   -- (a window shape does) or the stack is fullscreen, 23 pixels high
   -- with its border for a palette, 31 for the others. (The effective
   -- rect cannot tell: until the window has opened, as when a palette is
   -- placed before it opens or in its openStack, it is the stack's rect
   -- or nothing.)
   local tDecorations, tMode
   put the decorations of tStack into tDecorations
   put the mode of tStack into tMode
   if the fullscreen of tStack or \
         (tDecorations is not "default" and "title" is not among the items of tDecorations) then
      put 0 into tTitleBar
   else if tMode is 4 or (tMode is 0 and the style of tStack is "palette") then
      put 23 into tTitleBar
   else
      put 31 into tTitleBar
   end if
   put item 3 of tPage - item 1 of tPage into tWidth
   put item 4 of tPage - item 2 of tPage - tTitleBar into tHeight
   put the resizable of tStack into tResizable

   lock screen
   if pMoveOnly is true then
      put false into tResizable
   end if
   if tResizable and the width of tStack > tWidth then
      set the width of tStack to max(tWidth, the minWidth of tStack)
   end if
   if tResizable and the height of tStack > tHeight then
      set the height of tStack to max(tHeight, the minHeight of tStack)
   end if
   if the right of tStack > item 3 of tPage then
      set the right of tStack to item 3 of tPage
   end if
   if the left of tStack < item 1 of tPage then
      set the left of tStack to item 1 of tPage
   end if
   if the bottom of tStack > item 4 of tPage then
      set the bottom of tStack to item 4 of tPage
   end if
   if the top of tStack - tTitleBar < item 2 of tPage then
      set the top of tStack to item 2 of tPage + tTitleBar
   end if
   unlock screen
end revWebIDEKeepOnPage

-- A stack the user opens (not an IDE stack: revFrontScript publishes
-- ideOpenStack only for theirs) is kept in the windowBoundingRect, below
-- the menu bar, as the desktop engine keeps a stack it opens there
-- (MCScreenDC::platform_boundrect, which the web engine does not have)
on ideOpenStack pCard
   local tStack
   put the long id of the owner of pCard into tStack
   -- (windows, not dialogs or menus: the desktop centres a dialog)
   if the mode of tStack is among the items of "1,2,3,4" then
      revWebIDEKeepOnPage tStack, the windowBoundingRect
   end if
end ideOpenStack

/*
Keeps every open window on the page, as a desktop's window manager keeps
them on the screen when it changes: the IDE's windows as
revIDEEnsureOnscreen keeps a palette, and the user's stacks in the
windowBoundingRect, as they open (ideOpenStack), but only moved, so that
leaving full screen does not change a stack's size.
*/
command revWebIDEKeepWindowsOnPage
   local tName, tStack
   repeat for each line tName in the openStacks
      if tName is "revMenubar" or there is not a stack tName then
         next repeat
      end if
      put the long id of stack tName into tStack
      -- (windows and dialogs, not menus, nor a stack that fills the page)
      if not the visible of tStack or the fullscreen of tStack or \
            the mode of tStack is not among the items of "1,2,3,4,5" then
         next repeat
      end if
      if revIDEStackIsIDEStack(tStack) then
         revWebIDEKeepOnPage tStack
      else
         revWebIDEKeepOnPage tStack, the windowBoundingRect, true
      end if
   end repeat
end revWebIDEKeepWindowsOnPage

-- The page changed size (the engine tells once it has settled). The
-- palettes keep themselves on it (revPaletteBehavior); the windows that do
-- not, a stack of the user's or a dialog, are kept once they have, and
-- once the windowBoundingRect follows the menu bar (revIDELibrary).
on ideDesktopChanged
   revWebIDEFitMenubar
   send "revWebIDEKeepWindowsOnPage" to me in 0 milliseconds
   pass ideDesktopChanged
end ideDesktopChanged

################################################################################
#
# Home
#

/*
Opens Home, the web IDE's welcome stack, or brings it to the front: what
Help > Welcome to OXT-Beyond does.
*/
command revWebIDEShowHome
   local tPath
   if "revWebHome" is among the lines of the openStacks then
      go stack "revWebHome"
      exit revWebIDEShowHome
   end if
   if there is a stack "revWebHome" then
      modeless stack "revWebHome"
      exit revWebIDEShowHome
   end if
   put revIDESpecialFolderPath("Toolset") & "/palettes/web home/revwebhome.livecodescript" into tPath
   if there is a file tPath then
      modeless stack tPath
   end if
end revWebIDEShowHome

/*
Opens Home once the IDE has started (tCloseSplashFully, in the IDE's own
home.livecodescript, sends it), unless the user turned Home's "Show Home
at startup" switch off.
*/
command revWebIDEStartupHome
   if revIDEGetPreference("cWebHomeAtStartup") is false then
      exit revWebIDEStartupHome
   end if
   revWebIDEShowHome
end revWebIDEStartupHome
