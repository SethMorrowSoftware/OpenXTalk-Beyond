script "revHyperCardLibrary"
-- OXT-Beyond: the end of an imported HyperCard stack's message path.
--
-- revHyperCardFixScripts (revhypercardscriptlibrary.livecodescript) puts
-- this script in the substack "HyperCard Library (<the stack's name>)" of
-- a stack imported with File > Import Stack and makes that substack the
-- stack's behavior, so that it comes after the stack's own script, where
-- HyperCard's Home stack and HyperCard itself were. The scripts it rewrites call these
-- handlers for the parts of HyperCard this engine does not have. A
-- stack's own handler of the same name comes first, as in HyperCard.
--
-- What each does here, rather than in HyperCard, is said beside it.

-- A menu choice: HyperCard sent doMenu for each one, to the stack's
-- handlers first. In a stack imported without HyperCard's message order
-- (its hyperTalkCompatible false) no handler can be called doMenu: a
-- stack's "on doMenu" handler is called hcDoMenu after the import, and
-- each doMenu of its scripts is an hcDoMenu (rule T15), so that this one
-- comes after the stack's own. pMenu is the menu's name, when the script
-- gave it ("doMenu "Paste Button", "Edit""), and pWithout "without dialog".
on hcDoMenu pItem, pMenu, pWithout
   hcMenuChoice pItem, pMenu, pWithout
   return the result
end hcDoMenu

-- HyperCard's menu items, by the names HyperCard gave them, with or
-- without their "...", in any case: what a doMenu that no handler of the
-- stack takes does. hcDoMenu calls this; in a stack with HyperCard's
-- message order, where doMenu is a message and keeps its name, the "on
-- doMenu" of the substack "HyperCard Menus (<the stack's name>)", this
-- library's behavior, does. Each item does what it did in HyperCard as
-- nearly as this engine can:
--
-- File: New Stack..., Open Stack... (a HyperCard stack is imported as
-- "go" imports one), Close Stack, Save a Copy..., Delete Stack... (asked
-- first, "without dialog" too, whenever it would delete a file), Page
-- Setup..., Print Card, Print Stack..., Print Field... (the selected
-- field), Quit HyperCard (in the IDE the stack is closed rather than the
-- IDE quit: a stack that quit as it opened closed the IDE, with no word
-- about unsaved work; a standalone quits); Compact Stack and Convert
-- Stack... have nothing to do here.
-- Edit: Undo; Cut, Copy, Paste and Clear, alone or of Text, Button,
-- Field, Picture or Card, for what is selected; New Card, Delete Card,
-- Background (editing the background, or the card again).
-- Go: Back, Home, Help, Recent, First, Prev, Next, Last, Find... (asks
-- what to find), Message (shows the message box, or hides it).
-- Objects: New Button (named "New Button", as HyperCard named it), New
-- Field, New Background (a card with a background of its own), Bring
-- Closer, Send Farther, and Button Info... to Stack Info..., which show
-- the object in the IDE's inspector.
-- Style and Font: Plain, Bold, Italic, Underline, Condense, Extend,
-- Group, a font's name and a size, for the selected text, else the
-- selected buttons and fields; a style the text has already is taken off.
-- Paint: Select All with a paint tool takes the picture of the card (of
-- the background, while it is edited), which Cut, Copy and Clear Picture,
-- Flip Horizontal and Flip Vertical then act on.
--
-- An item of a menu the stack made sends its menu message, as HyperCard
-- did. Any other item leaves "doMenu "<item>" not implemented" in the
-- result, as this engine's doMenu does; an item that stops with an error
-- leaves the error in the result, and the script goes on, as it did
-- after this engine's doMenu.
on hcMenuChoice pItem, pMenu, pWithout
   local tMessage, tKey, tError, tStack, tObjects
   put hcMenuMessage(pItem) into tMessage
   if tMessage is not empty then
      _HCSendMenuMessage tMessage
      return the result
   end if
   put _HCMenuKey(pItem) into tKey
   try
      switch tKey
         -- File
         case "new stack"
            return _HCNewStack(pWithout)
         case "open stack"
         case "open stack in new window"
            answer file "Open which stack?"
            if it is empty then return "Cancel"
            put _HCOpenStack(it) into tStack
            if tStack is empty then return "No such stack"
            if tKey is "open stack" then
               go tStack
            else
               go tStack in a new window
            end if
            return the result
         case "close stack"
            close this stack
            return empty
         case "save a copy"
            return _HCSaveACopy()
         case "compact stack"
         case "convert stack"
            -- (the stack is in this engine's format already, and compact
            -- has nothing to do here)
            return empty
         case "delete stack"
            return _HCDeleteStack(pWithout)
         case "page setup"
            answer page setup
            return empty
         case "print card"
            print this card
            return empty
         case "print stack"
            print this stack
            return empty
         case "print field"
            put _HCSelected("field") into tObjects
            if tObjects is empty then return "No field is selected"
            PrintField line 1 of tObjects
            return the result
         case "quit hypercard"
         case "quit"
            if the environment is "development" then
               close this stack
            else
               quit
            end if
            return empty
         -- Edit
         case "undo"
            undo
            return empty
         case "cut"
         case "copy"
         case "clear"
            return _HCEdit(tKey, empty)
         case "cut text"
         case "copy text"
         case "clear text"
         case "cut button"
         case "copy button"
         case "clear button"
         case "cut field"
         case "copy field"
         case "clear field"
         case "cut picture"
         case "copy picture"
         case "clear picture"
            return _HCEdit(word 1 of tKey, word 2 of tKey)
         case "paste"
         case "paste text"
         case "paste button"
         case "paste field"
         case "paste card"
         case "paste picture"
            paste
            return the result
         case "new card"
            create card
            return empty
         case "delete card"
            delete this card
            return empty
         case "cut card"
            cut this card
            return the result
         case "copy card"
            copy this card
            return the result
         case "background"
            set the editBackground to not the editBackground
            return empty
         -- Go
         case "back"
            go back
            return the result
         case "home"
            hcGoHome
            return the result
         case "help"
            help
            return empty
         case "recent"
            go recent card
            return the result
         case "first"
         case "prev"
         case "previous"
         case "next"
         case "last"
            do "go to" && tKey && "card"
            return the result
         case "find"
            ask "Find:"
            if it is empty then return empty
            find it
            return the result
         case "message"
            if there is not a stack "Message Box" then return empty
            if the visible of stack "Message Box" then
               hide message box
            else
               show message box
            end if
            return empty
         -- Objects
         case "button info"
         case "field info"
         case "card info"
         case "bkgnd info"
         case "background info"
         case "stack info"
            return _HCInfo(word 1 of tKey, pItem)
         case "bring closer"
            return _HCLayer(1)
         case "send farther"
            return _HCLayer(-1)
         case "new button"
            -- (this engine's doMenu makes one with no name)
            create button "New Button"
            return empty
         case "new field"
            create field
            return empty
         case "new background"
            return _HCNewBackground()
         -- Style
         case "plain"
         case "bold"
         case "italic"
         case "underline"
         case "outline"
         case "shadow"
         case "condense"
         case "extend"
         case "group"
            return _HCStyle(tKey)
         -- Paint
         case "select all"
            return _HCSelectAll()
         case "flip horizontal"
         case "flip vertical"
            return _HCFlip(word 2 of tKey)
         case "keep"
            -- (what is painted here is kept as it is painted)
            return empty
      end switch
      -- the Style menu's sizes, and the Font menu's fonts
      if tKey is an integer and tKey >= 1 and tKey <= 127 then
         return _HCTextProperty("textSize", tKey)
      end if
      if _HCFont(pItem) is not empty then
         return _HCTextProperty("textFont", _HCFont(pItem))
      end if
   catch tError
      return "doMenu" && quote & pItem & quote && "failed:" && line 1 of tError
   end try
   return "doMenu" && quote & pItem & quote && "not implemented"
end hcMenuChoice

-- The name of a menu item as hcMenuChoice knows it: in lower case, its
-- words one space apart, without the "..." (or the "…") after it
private function _HCMenuKey pItem
   local tKey
   put toLower(pItem) into tKey
   replace numToCodepoint(160) with space in tKey
   replace numToCodepoint(8230) with "..." in tKey
   replace tab with space in tKey
   repeat while "  " is in tKey
      replace "  " with space in tKey
   end repeat
   put word 1 to -1 of tKey into tKey
   repeat while char -1 of tKey is "."
      delete char -1 of tKey
   end repeat
   return word 1 to -1 of tKey
end _HCMenuKey

-- The selected objects, one long id a line; with pType ("button",
-- "field") those of that type only
private function _HCSelected pType
   local tObject, tList
   repeat for each line tObject in the selectedObjects
      if pType is empty or word 1 of tObject is pType then put tObject & return after tList
   end repeat
   delete the last char of tList
   return tList
end _HCSelected

-- Whether the selectedChunk is text, not an insertion point ("char 6 to
-- 5 of field 1")
private function _HCHasText pChunk
   return word 1 of pChunk is "char" and word 2 of pChunk is an integer \
         and word 4 of pChunk is an integer and word 2 of pChunk <= word 4 of pChunk
end _HCHasText

-- Cut, Copy and Clear (pVerb) of the picture "Select All" took, of the
-- selected text, or of the selected buttons and fields (pWhat: "text",
-- "button", "field", "picture", or empty for what is selected)
private function _HCEdit pVerb, pWhat
   local tChunk, tObjects, tObject, tPicture
   put _HCSelectedPicture() into tPicture
   if pWhat is "picture" or (pWhat is empty and tPicture is not empty) then
      if tPicture is empty then
         -- (a selection made with this engine's paint tools)
         if pVerb is "copy" then copy
         if pVerb is "cut" then cut
         return empty
      end if
      if pVerb is among the words of "copy cut" then copy tPicture
      if pVerb is among the words of "cut clear" then set the text of tPicture to empty
      return empty
   end if
   put the selectedChunk into tChunk
   if pWhat is "text" or (pWhat is empty and _HCHasText(tChunk)) then
      if pVerb is "copy" then copy
      if pVerb is "cut" then cut
      if pVerb is "clear" and _HCHasText(tChunk) then do "delete" && tChunk
      return empty
   end if
   put _HCSelected(pWhat) into tObjects
   if tObjects is empty then
      -- (nothing of that kind selected: what this engine's own command
      -- does with the selection)
      if pVerb is "copy" then copy
      if pVerb is "cut" then cut
      return empty
   end if
   if pVerb is "clear" then
      repeat for each line tObject in tObjects
         delete tObject
      end repeat
      return empty
   end if
   if the number of lines of tObjects > 1 then
      -- (all of the selection, as the Edit menu takes it)
      if pVerb is "copy" then
         copy
      else
         cut
      end if
   else if pVerb is "copy" then
      copy tObjects
   else
      cut tObjects
   end if
   return the result
end _HCEdit

-- The picture Select All took: its card's long id, then its image's
local sHCPicture

-- Whether a paint tool is chosen
private function _HCPaintTool
   return word 1 of the tool is among the words of \
         "select lasso pencil brush eraser spray line rectangle rect roundrect round oval curve polygon regular text bucket dropper"
end _HCPaintTool

-- The picture of this card (of its background, while it is edited): the
-- image the import made of it, which has no name. Empty if it has none
private function _HCPictureOfCard
   local tCard, tOwner, i, tImage
   put the long id of this card into tCard
   put tCard into tOwner
   if the editBackground and the number of backgrounds of tCard > 0 then
      put the long id of background 1 of tCard into tOwner
   end if
   repeat with i = 1 to the number of images of tOwner
      put the long id of image i of tOwner into tImage
      if the long id of the owner of tImage is tOwner and the short name of tImage ends with "image id" && the id of tImage then
         return tImage
      end if
   end repeat
   return empty
end _HCPictureOfCard

-- Select All: with a paint tool, the picture of the card; with the
-- browse tool, the text of the field being edited
private function _HCSelectAll
   if _HCPaintTool() then
      put the long id of this card & return & _HCPictureOfCard() into sHCPicture
      return empty
   end if
   if the selectedField is not empty then do "select text of" && the selectedField
   return empty
end _HCSelectAll

-- The picture Select All took, while a paint tool is chosen and its card
-- is this card: its image's long id, or empty
private function _HCSelectedPicture
   if not _HCPaintTool() or line 1 of sHCPicture is not the long id of this card then return empty
   if line 2 of sHCPicture is empty or not exists(line 2 of sHCPicture) then return empty
   return line 2 of sHCPicture
end _HCSelectedPicture

-- Flip Horizontal, Flip Vertical of the picture Select All took
private function _HCFlip pDirection
   local tPicture
   put _HCSelectedPicture() into tPicture
   if tPicture is not empty then do "flip" && tPicture && pDirection
   return empty
end _HCFlip

-- Button Info... to Stack Info...: the object in the IDE's inspector
private function _HCInfo pWhat, pItem
   local tObject, tCard
   switch pWhat
      case "button"
      case "field"
         put line 1 of _HCSelected(pWhat) into tObject
         break
      case "card"
         put the long id of this card into tObject
         break
      case "bkgnd"
      case "background"
         put the long id of this card into tCard
         if the number of backgrounds of tCard > 0 then put the long id of background 1 of tCard into tObject
         break
      case "stack"
         put the long id of this stack into tObject
         break
   end switch
   if tObject is empty then return empty
   -- (a standalone has no inspector)
   if the environment is "development" then
      dispatch "revIDEInspectObjects" with tObject
      if it is "handled" then return empty
   end if
   return "doMenu" && quote & pItem & quote && "not implemented"
end _HCInfo

-- Bring Closer (pBy 1) and Send Farther (-1): the selected object a layer
-- up or down
private function _HCLayer pBy
   local tObject
   put line 1 of the selectedObjects into tObject
   if tObject is empty or the layer of tObject + pBy < 1 then return empty
   set the layer of tObject to the layer of tObject + pBy
   return empty
end _HCLayer

-- New Background: a card after this one with a background of its own (a
-- new card here gets the backgrounds of the card it follows)
private function _HCNewBackground
   local tGroup, tCard
   create card
   put the long id of this card into tCard
   repeat while the number of backgrounds of tCard > 0
      remove group id (the id of background 1 of tCard) from this card
   end repeat
   create group
   put it into tGroup
   set the backgroundBehavior of tGroup to true
   return empty
end _HCNewBackground

-- The selected text, else the selected buttons and fields: what the Style
-- and Font menus changed. A chunk or long ids, one a line
private function _HCTextTargets
   local tChunk, tObject, tList
   put the selectedChunk into tChunk
   if _HCHasText(tChunk) then return tChunk
   repeat for each line tObject in the selectedObjects
      if word 1 of tObject is among the words of "button field" then put tObject & return after tList
   end repeat
   delete the last char of tList
   return tList
end _HCTextTargets

-- A style of the Style menu (in HyperCard's words), on or off: Plain takes
-- every style off; a style the text has already is taken off; outline and
-- shadow, which this engine does not have, do nothing
private function _HCStyle pStyle
   local tStyle, tTarget, tStyles
   put hcTextStyle(pStyle) into tStyle
   if tStyle is "plain" and pStyle is not "plain" then return empty
   repeat for each line tTarget in _HCTextTargets()
      if tStyle is "plain" then
         put "plain" into tStyles
      else
         do "put the textStyle of" && tTarget && "into tStyles"
         if tStyle is among the items of tStyles then
            delete item itemOffset(tStyle, tStyles) of tStyles
         else if tStyles is empty or tStyles is among the words of "plain mixed" then
            put tStyle into tStyles
         else
            put comma & tStyle after tStyles
         end if
         if tStyles is empty then put "plain" into tStyles
      end if
      do "set the textStyle of" && tTarget && "to tStyles"
   end repeat
   return empty
end _HCStyle

-- A font or a size from the Font and Style menus, for the selected text
-- or the selected buttons and fields
private function _HCTextProperty pProperty, pValue
   local tTarget
   repeat for each line tTarget in _HCTextTargets()
      do "set the" && pProperty && "of" && tTarget && "to pValue"
   end repeat
   return empty
end _HCTextProperty

-- The fonts of the Macs HyperCard ran on, which a stack's menu choices
-- name whether or not this computer has them
constant kHCFonts = "Chicago,Geneva,Monaco,New York,Times,Helvetica,Courier,Palatino,Symbol,Zapf Dingbats,Zapf Chancery,Avant Garde,Bookman,New Century Schlbk,Helvetica Narrow,Venice,London,Athens,San Francisco,Los Angeles,Cairo,Toronto,Mobile,Charcoal"

-- pItem as a font's name: one this computer has, or one of HyperCard's
-- Macs; else empty
private function _HCFont pItem
   put word 1 to -1 of pItem into pItem
   if pItem is empty then return empty
   if pItem is among the lines of the fontNames or pItem is among the items of kHCFonts then return pItem
   return empty
end _HCFont

-- New Stack...: a stack of this one's size, saved where the user says,
-- and gone to; "without dialog", one called "Untitled", not saved
private function _HCNewStack pWithout
   local tWidth, tHeight, tPath, tName, tStack
   put the width of this stack into tWidth
   put the height of this stack into tHeight
   put "Untitled" into tName
   if pWithout is not "without dialog" then
      ask file "New stack name:" with "Untitled"
      if it is empty then return "Cancel"
      put it into tPath
      set the itemDelimiter to slash
      put the last item of tPath into tName
   end if
   create stack tName
   put it into tStack
   set the width of tStack to tWidth
   set the height of tStack to tHeight
   if tPath is not empty then save tStack as tPath
   go tStack
   return the result
end _HCNewStack

-- Save a Copy...: the stack (its mainstack, with every substack) saved to
-- the file the user names; the stack itself is still where it was
private function _HCSaveACopy
   local tStack, tFile, tPath, tResult
   put the long id of stack (the mainStack of this stack) into tStack
   ask file "Save a copy of the stack as:" with (the short name of tStack && "Copy")
   if it is empty then return "Cancel"
   put it into tPath
   put the fileName of tStack into tFile
   save tStack as tPath
   put the result into tResult
   set the fileName of tStack to tFile
   return tResult
end _HCSaveACopy

-- Delete Stack...: the stack is closed and gone from memory, and its file
-- deleted. It asks first ("without dialog" too, whenever a file would be
-- deleted: a HyperCard script's say-so is not the user's); a stack
-- imported and not saved yet has no file of its own
private function _HCDeleteStack pWithout
   local tStack, tFile
   put the long id of stack (the mainStack of this stack) into tStack
   put the fileName of tStack into tFile
   if tFile is not empty then
      answer warning "Delete the stack" && quote & the short name of tStack & quote && "and its file?" & return & tFile with "Cancel" or "Delete"
      if it is not "Delete" then
         return "Cancel"
      end if
   else if pWithout is not "without dialog" then
      answer warning "Delete the stack" && quote & the short name of tStack & quote & "?" with "Cancel" or "Delete"
      if it is not "Delete" then
         return "Cancel"
      end if
   end if
   if tFile is not empty and there is a file tFile then delete file tFile
   set the destroyStack of tStack to true
   close tStack
   return empty
end _HCDeleteStack

-- The stack in the file pPath, for Open Stack...: a HyperCard stack is
-- imported as "go" imports one (_HCImport), with its scripts fixed
private function _HCOpenStack pPath
   local tStack, tWasLocked
   put the lockMessages into tWasLocked
   lock messages
   try
      put the long id of stack pPath into tStack
   catch tError
      put empty into tStack
   end try
   set the lockMessages to tWasLocked
   if tStack is empty then return empty
   if the HCStack of tStack and the behavior of tStack is empty then return _HCImport(pPath)
   return tStack
end _HCOpenStack

-- HyperCard's version, which scripts compare with numbers ("the version
-- < 2"): that of HyperCard 2.4.1, the last
function hcVersion
   return "2.4.1"
end hcVersion

-- the heapSpace: the memory HyperCard had free, which stacks checked
-- before they ran (Gems of Hubble quits under 1321000). This engine's
-- heapSpace is 1000000 always; 16 MB passes those checks
function hcHeapSpace
   return 16777216
end hcHeapSpace

-- HyperCard's long version, as HyperCard 2.4.1 gave it
function hcLongVersion
   return "02418000"
end hcLongVersion

-- The Mac that the systemVersion and the externals that ask about the
-- Mac (SysEnv, SysEnvirons, MacType) describe: System 7.5.5, of
-- HyperCard 2.4's years, on a model none of those externals knows by
-- name, with a 68040 and its math coprocessor, Color QuickDraw, an
-- Apple Extended Keyboard and no AppleTalk. Stacks check for System 7
-- or later, and for a 68030 or later (Doctor Who's "if DWcpu >= 68030")
constant kHCSystem = "7.5.5"

-- the systemVersion (rule T10): the System's version as HyperCard 2.2's
-- code makes it, the major version, a period, then the minor and bug-fix
-- digits ("7.55" for 7.5.5), which scripts compare with numbers ("if the
-- systemVersion < 7 then", Finder Cleaner's). This engine's is the
-- host's ("NT 10.0", "14.5.0"), which such a comparison takes as text:
-- on macOS "14.5.0" is less than 7
function hcSystemVersion
   set the itemDelimiter to "."
   return item 1 of kHCSystem & "." & item 2 of kHCSystem & item 3 of kHCSystem
end hcSystemVersion

-- the version of a stack (rule T55): in HyperCard five items, the
-- versions of HyperCard that made the stack, last compacted it, first
-- changed it after that and last changed it, each as the long version
-- gives one, and the seconds when it was last changed. The import keeps
-- none of them, so each version is HyperCard's as this library gives it
-- (hcLongVersion), and the seconds are now. pStack, the stack's long id,
-- is one the script found, as HyperCard's "can't find stack" stopped it
-- where it found none
function hcStackVersion pStack
   local tVersion
   put hcLongVersion() into tVersion
   return tVersion & comma & tVersion & comma & tVersion & comma & tVersion & comma & the seconds
end hcStackVersion

-- Whether HyperCard was in the background (MultiFinder): never here
function hcSuspended
   return false
end hcSuspended

-- HyperCard's userLevel, 1 (browsing) to 5 (scripting), which scripts
-- compare and show ("if the userLevel is 5", HyperCard's Home stack's
-- arrow at its button "UserLevel 5"): this engine's is 8 until a script
-- sets it, more than any of HyperCard's, so it is 5, the level at which
-- everything could be done. What a script set is given back
function hcUserLevel
   if the userLevel is a number and the userLevel > 5 then return 5
   return the userLevel
end hcUserLevel

-- HyperCard's global properties that this engine has not (rule T64:
-- "set the dialingTime to 600", "put the language into oldlanguage"):
-- what a script set, else HyperCard's own value. They change nothing
-- here: no modem is dialed for the dialingTime (in ticks) and the
-- dialingVolume to time and sound, scripts read in English whatever the
-- language, and the watchers and the script editor and debugger
-- (HyperCard's XCMDs for them, named by these) are the IDE's
local sHCProperties

function hcProperty pName
   if pName is among the keys of sHCProperties then return sHCProperties[pName]
   switch pName
      case "dialingTime"
         return 180
      case "dialingVolume"
         return 7
      case "language"
         return "English"
      case "messageWatcher"
         return "MessageWatcher"
      case "variableWatcher"
         return "VariableWatcher"
      case "scriptEditor"
      case "debugger"
         return "ScriptEditor"
   end switch
   return empty
end hcProperty

on hcSetProperty pName, pValue
   put pValue into sHCProperties[pName]
end hcSetProperty

-- HyperCard's name (rule T29): "HyperCard", or with pForm "long" its
-- path as HyperCard gave it, a Mac path with colons. Scripts take the
-- folder from it and add a stack's name, so it is put in the folder the
-- stack was imported from (on its disk image, the folder there), where
-- "go" finds the stacks beside it by their names
function hcHyperCardName pForm
   local tSet, tFolder
   if pForm is not "long" then
      return "HyperCard"
   end if
   put the customProperties["uHyperCard"] of me into tSet
   if tSet["imagepath"] is not empty then
      set the itemDelimiter to ":"
      put item 1 to -2 of tSet["imagepath"] into tFolder
   else if tSet["file"] is not empty then
      set the itemDelimiter to slash
      put item 1 to -2 of tSet["file"] into tFolder
      replace slash with ":" in tFolder
      if char 1 of tFolder is ":" then
         delete char 1 of tFolder
      end if
   else
      put "HyperCard" into tFolder
   end if
   return tFolder & ":HyperCard"
end hcHyperCardName

-- send message to HyperCard (rule T29): the message's built-in handler,
-- passing the stack's own; "doMenu Copy Text", the item not in quotes,
-- as HyperCard read it, and the menu's name after a comma and "without
-- dialog" after them ("doMenu "Paste Card", "Edit" without dialog")
on hcSendToHyperCard pMessage
   local tItem, tMenu, tWithout, tRest, tAt
   if word 1 of pMessage is "doMenu" then
      put word 2 to -1 of pMessage into tItem
      if word -2 to -1 of tItem is "without dialog" then
         put "without dialog" into tWithout
         put word 1 to -3 of tItem into tItem
      end if
      if char 1 of tItem is quote then
         put char 2 to -1 of tItem into tRest
         put offset(quote, tRest) into tAt
         if tAt is 0 then
            put tRest into tItem
         else
            put char 1 to tAt - 1 of tRest into tItem
            put char tAt + 1 to -1 of tRest into tMenu
            put word 1 to -1 of tMenu into tMenu
         end if
         if char 1 of tMenu is comma then
            delete char 1 of tMenu
         else
            put empty into tMenu
         end if
      else if comma is in tItem then
         put item 2 to -1 of tItem into tMenu
         put item 1 of tItem into tItem
      end if
      put word 1 to -1 of tItem into tItem
      put word 1 to -1 of tMenu into tMenu
      if char 1 of tMenu is quote then delete char 1 of tMenu
      if char -1 of tMenu is quote then delete char -1 of tMenu
      -- (HyperCard's own menu items: not doMenu, which in a stack with
      -- HyperCard's message order would reach the stack's handlers again)
      hcMenuChoice tItem, tMenu, tWithout
      return the result
   end if
   -- (help: HyperCard's own Help stack, not a handler of the stack's,
   -- which "do" would reach first)
   if word 1 to -1 of pMessage is "help" then
      hcHelp
      return the result
   end if
   try
      do pMessage
   catch tError
      return "Can't understand" && pMessage
   end try
   return the result
end hcSendToHyperCard

-- reset menubar put HyperCard's own menus back, as they were before the
-- stack's scripts changed them: here, the library's (rule T22)
on hcResetMenubar
   _HCMenusInit true
end hcResetMenubar

-- go home: HyperCard's Home stack, if one was imported (in the IDE a
-- stack called "home" is the IDE's own, which is not it); in the web
-- Stack Player, the player's library, which is its home; else a Home
-- stack beside this one, found as hcStackName finds any stack
on hcGoHome
   local tStack
   global gHyperCardHome
   if _HCIsHyperCardStack("Home") then
      go stack "Home"
      return the result
   end if
   if gHyperCardHome is not empty and exists(gHyperCardHome) then
      send "playerGoHome" to gHyperCardHome in 0 milliseconds
      return empty
   end if
   put hcStackName("Home") into tStack
   if tStack is not empty then
      go stack tStack
      return the result
   end if
   return "Can't find the Home stack"
end hcGoHome

/*
HyperCard's Home stack, for a script that names it other than to go there
(rule T45: "set the script of stack "Home" to tScript", "the long name of
stack Home", "send startUp to stack home"): HyperCard's Home if one was
imported, else the library's stand-in, an invisible stack "HyperCard
Home" made the first time, with this library as its behavior so that a
message sent to it reaches the library's getHomeInfo and the others.
Here a stack called "home" is the IDE's own: a stack that installed its
handlers into Home's script, or locked Home, would change the IDE's. The
stand-in keeps them instead, for as long as the IDE runs, though not in
every stack's message path as HyperCard's Home was
*/
function hcHome
   local tDefault, tLocked, tBehavior, tWas
   if _HCIsHyperCardStack("Home") then return the long name of stack "Home"
   if there is not a stack "HyperCard Home" then
      put the defaultStack into tDefault
      put the lockMessages into tLocked
      lock messages
      get _HCNewHiddenStack("HyperCard Home")
      set the lockMessages to tLocked
      set the defaultStack to tDefault
   end if
   -- (and again when the stack whose library it was has gone)
   put the behavior of me into tBehavior
   put the behavior of stack "HyperCard Home" into tWas
   if tBehavior is not empty and exists(tBehavior) and (tWas is empty or not exists(tWas)) then
      set the behavior of stack "HyperCard Home" to tBehavior
   end if
   return the long name of stack "HyperCard Home"
end hcHome

-- HyperCard 2's Home stack had handlers other stacks called, as they
-- were in every user's message path (a CD's stacks call getHomeInfo in
-- 47 stacks, lastHCItem in 11, setUserLevelFive in 9). With no Home
-- stack here, these stand in for them; a stack's own comes first.

-- getHomeInfo: the Home stack read the user's name and search paths into
-- these globals (Stacks and Documents are hc_Stacks and hc_Documents in
-- the rewritten scripts, rule T2). The name is the system's user; the
-- paths stay as they are
on getHomeInfo
   global hc_Stacks, Applications, hc_Documents, UserName
   if UserName is empty then
      put $USER into UserName
      if UserName is empty then put $USERNAME into UserName
   end if
   return empty
end getHomeInfo

on setUserLevelFive
   global SvLvl
   put the userLevel into SvLvl
   set the userLevel to 5
end setUserLevelFive

on restoreUserLevel
   global SvLvl
   if SvLvl is a number then set the userLevel to SvLvl
end restoreUserLevel

on allowInterruption
   set the cantAbort of this stack to false
end allowInterruption

on disallowInterruption
   set the cantAbort of this stack to true
end disallowInterruption

-- A statement that the import left out of a handler because it does not
-- compile here (rule T39), after the then or the else of an if, where a
-- statement has to be: it does nothing, and the handler goes on, as it
-- does past a line left out whole (a comment). pStatement is the
-- statement as it was
on hcLeftOut pStatement
end hcLeftOut

-- the part of pText after the last pDelim, all of it with none
function lastHCItem pDelim, pText
   local tAt
   if pDelim is empty then return pText
   repeat
      put offset(pDelim, pText) into tAt
      if tAt is 0 then exit repeat
      delete char 1 to tAt + the number of chars of pDelim - 1 of pText
   end repeat
   return pText
end lastHCItem

-- the fonts the Home stack checked for and warned of: shown here in
-- another face when the system lacks them, which the import summary says
function checkHCFont pFont, pSizes
   if pFont is among the lines of the fontNames then return empty
   return pFont && pSizes & return
end checkHCFont

on checkForMissingFonts
   return empty
end checkForMissingFonts

-- debug sound off, debug pureQuickDraw true...: HyperCard 2's debug
-- options (rule T35), which have nothing to set here
on hcDebug pOptions
   return empty
end hcDebug

-- Externals stacks called most that this script can do (a CD's stacks:
-- SetVolume in 26, GetVolume in 18, Trim in 12): a stack's own XCMD or
-- XFCN of the name is not run here, so these stand in for it

-- the sound volume, 0 to 7 as the Macintosh's, from this engine's
-- playLoudness (0 to 100)
function GetVolume
   return round(the playLoudness * 7 / 100)
end GetVolume

on SetVolume pLevel
   if pLevel is not a number then return empty
   set the playLoudness to max(0, min(100, round(pLevel * 100 / 7)))
end SetVolume

-- whether the system has the font (FontExists in 19 stacks of the CD);
-- any size of a font it has is drawn here
function FontExists pFont, pSize
   return pFont is among the lines of the fontNames
end FontExists

-- the name of the window in front (FrontWindow, 12 stacks)
function FrontWindow
   return the short name of the topStack
end FrontWindow

-- the text without the spaces and tabs at its start and end
function Trim pText
   repeat while pText is not empty and (char 1 of pText is space or char 1 of pText is tab)
      delete char 1 of pText
   end repeat
   repeat while pText is not empty and (char -1 of pText is space or char -1 of pText is tab)
      delete char -1 of pText
   end repeat
   return pText
end Trim

----------------------------------------------------------------------
-- go to a stack that is not open
--
-- HyperCard looked for a stack that was not open in the folders it knew
-- of, then asked "Where is ...?"; if the stack could not be found, "go"
-- put "No such card" in the result and the script went on. Here "go" to
-- a stack it cannot find stops the script with an error, and a stack
-- that "go" finds in a HyperCard file is imported without its scripts
-- fixed. So the import rewrites each "go" that names a stack (rule T16)
-- as "do hcGo(...)": the stack is found by hcStackName first, and the
-- statement is run with the stack in the variable tHCStack.

local sHCAsked

-- The statements "do" runs for a "go" to a stack: pStatement, the "go"
-- with the stack expression replaced by tHCStack; pStack, that
-- expression. A stack that cannot be found leaves "No such card" in the
-- result, as in HyperCard, rather than an error
function hcGo pStatement, pStack
   return "put hcStackName(" & pStack & ") into tHCStack" & return & \
         "if tHCStack is empty then" & return & \
         "put (" & pStack & ") into tHCStack" & return & \
         "try" & return & pStatement & return & "catch tHCError" & return & "end try" & return & \
         "else" & return & pStatement & return & "end if"
end hcGo

/*
go to a destination given by an expression (rule T25): pDest, its value;
pWindow, what followed it ("in a new window"). What "go" here takes (a
card's description, a stack that is open) it goes to; else a stack found
as hcGo finds one; else it leaves "No such card" in the result, as
HyperCard did, where "go" here stops with an error
*/
on hcGoTo pDest, pWindow
   local tStack
   if _HCLastPart(pDest) is "Home" then
      hcGoHome
      return the result
   end if
   try
      do "go to pDest" && pWindow
      return the result
   catch tError
   end try
   if word 1 of pDest is among the words of "card cd background bkgnd bg stack" then return "No such card"
   put hcStackName(pDest) into tStack
   if tStack is empty then return "No such card"
   try
      do "go to stack tStack" && pWindow
      return the result
   catch tError
   end try
   return "No such card"
end hcGoTo

/*
go to a background without a card (rule T69: "go to bkgnd "Game"", "go bg
i", "go next bkgnd"), which HyperCard went to the first card of, leaving
"No such card" in the result when there was no such background. Here a
"go" to a background without a card stays on the card it is on (and then
counts only that background's cards until a "go" names a card), and one to
"card 1" of a background that is not there goes to the stack's first
card. pHow is how pWhich names the background: "id", or "name" for its
name or number; or pHow is the ordinal that names it ("next", "last",
"this"...). The backgrounds are those of this stack, the stack a "go"
without one goes in
*/
on hcGoBackground pHow, pWhich
   local tCount, tNumber
   switch pHow
      case "id"
         if there is not a background id pWhich then return "No such card"
         go to card 1 of background id pWhich
         return the result
      case "name"
         if there is not a background pWhich then return "No such card"
         go to card 1 of background pWhich
         return the result
      case "this"
      case "next"
      case "prev"
      case "previous"
         -- (from this card's background: this engine crashes going to
         -- the next or the previous background from a card with none)
         if not (there is this background) then return "No such card"
         do "go to card 1 of" && pHow && "background"
         return the result
      default
         -- (by number: this engine counts only this card's groups for the
         -- last, the middle and any background)
         put the number of backgrounds into tCount
         switch pHow
            case "last"
               put tCount into tNumber
               break
            case "middle"
            case "mid"
               put tCount div 2 + 1 into tNumber
               break
            case "any"
               if tCount > 0 then put random(tCount) into tNumber
               break
            default
               put wordOffset(pHow, "first second third fourth fifth sixth seventh eighth ninth tenth") into tNumber
         end switch
         if tNumber is empty or tNumber < 1 or tNumber > tCount then return "No such card"
         go to card 1 of background tNumber
         return the result
   end switch
end hcGoBackground

/*
The stack "go" should go to for pStack, which HyperCard may have named
by its HFS path ("Disk:Stacks:Name"): pStack itself when there is such a
stack; else a HyperCard stack of that name beside the file this stack was
imported from (or in the disk image it came from), imported with its
scripts fixed; else, in the IDE, the file the user gives when asked
"Where is ...?", as HyperCard asked (once a name). Empty if none.
*/
function hcStackName pStack
   return _HCFindStack(pStack, true, false)
end hcStackName

-- hcStackName's stack, with "Where is ...?" asked when pAsk is true, and
-- with pNear only beside this stack or at the path pStack, not anywhere
-- on its disk image (_HCFindSibling)
private function _HCFindStack pStack, pAsk, pNear
   local tName, tFile, tStack
   if pStack is empty then return empty
   put _HCLastPart(pStack) into tName
   if tName is "Home" and not _HCIsHyperCardStack("Home") then
      -- (the IDE's stack "home" is not HyperCard's)
      put empty into tStack
   else if there is a stack pStack then
      return pStack
   else if tName is not pStack and there is a stack tName then
      return tName
   end if
   put _HCFindSibling(pStack, tName, pNear) into tFile
   if tFile is empty and pAsk then put _HCWhereIs(tName) into tFile
   if tFile is empty then return empty
   put _HCImport(tFile) into tStack
   if tStack is empty then return empty
   if tName is not "Home" and there is a stack pStack then return pStack
   return tStack
end _HCFindStack

/*
Whether there is the stack pStack (rule T65: "if there is a stack "Audio
Help" then"): one that is open or in memory, as "there is a stack" here
says; else, as HyperCard looked for a stack that was not open, a
HyperCard stack of that name beside the file this stack was imported
from, or in its folder on the disk image it came from, or at the HFS
path pStack (from that folder when it begins with a colon, ":Support
Files:Pictoid XCMD"), which is imported, with its scripts fixed, as a
"go" imports one; nothing is asked. True when the stack is then one
that "stack pStack" names here, so that what the script does with it
next finds it: by its name, not by an HFS path (a "go" or a "send" to
the stack of that name finds the stack imported). Home is the IDE's, as
it was
*/
function hcThereIsStack pStack
   if pStack is empty then return false
   if there is a stack pStack then return true
   if _HCLastPart(pStack) is "Home" then return false
   get _HCFindStack(pStack, false, true)
   return there is a stack pStack
end hcThereIsStack

/*
The stack a "send" names (rule T65: "send "startSound" to stack "Audio
Help""), as "stack" takes it: pStack itself where there is such a stack,
or where none is found, as the send stopped here; else the stack found
as hcStackName finds the stack of a "go", without asking where it is,
imported with its scripts fixed (HyperCard sent the message to a stack
that was not open, found where it looked for one). Home is the IDE's,
as it was
*/
function hcSendStack pStack
   local tStack
   if pStack is empty or there is a stack pStack or _HCLastPart(pStack) is "Home" then return pStack
   put _HCFindStack(pStack, false, false) into tStack
   if tStack is empty then return pStack
   return tStack
end hcSendStack

-- Whether the stack of that name is one imported from HyperCard
private function _HCIsHyperCardStack pName
   if there is not a stack pName then return false
   return "uHyperCard" is among the lines of the customPropertySets of stack pName
end _HCIsHyperCardStack

-- The last part of a path, HFS (colons) or not (slashes)
private function _HCLastPart pPath
   if char -1 of pPath is ":" then delete char -1 of pPath
   set the itemDelimiter to ":"
   put the last item of pPath into pPath
   set the itemDelimiter to slash
   return the last item of pPath
end _HCLastPart

-- A HyperCard stack named pName (or at the HFS path pStack; from this
-- stack's folder where it begins with a colon, ":Support Files:Pictoid
-- XCMD", each colon more going up a folder, "::Stacks:Index") beside the
-- file this stack was imported from, or on the disk image it came from:
-- the path of a copy that can be imported, or empty. On the disk image,
-- else a stack of that name anywhere on it, as a person would answer
-- "Where is ...?", unless pNear: only where HyperCard looked without
-- asking. Of several, the one nearest this stack, whose folder has the
-- most of this stack's folders, from the disk down, as the copy that
-- came with it is (LabUse, in "Lab Logger 1.02:Logger:Usage", goes to
-- "Lab Logger 1.02:Logger:Logger", not to the Logger of version 1.0,
-- which is first on the disk and has not the fields it reads there); of
-- copies as near, the first on the disk, which was the one taken. A
-- Home is the first on the disk, as it was: HyperCard never asked where
-- Home was, and went to the one it used, not one that came with a stack
private function _HCFindSibling pStack, pName, pNear
   local tSet, tFolder, tFile, tStacks, tLine, tPath, tHFSFolder, tAny, tRelative, tUp, tSub
   local tStackFolder, tShared, tAnyShared
   put the customProperties["uHyperCard"] of me into tSet
   put 0 into tUp
   if char 1 of pStack is ":" then
      put char 2 to -1 of pStack into tRelative
      repeat while char 1 of tRelative is ":"
         add 1 to tUp
         delete char 1 of tRelative
      end repeat
      if char -1 of tRelative is ":" then delete char -1 of tRelative
   end if
   if tSet["file"] is not empty then
      set the itemDelimiter to slash
      put item 1 to -2 of tSet["file"] into tFolder
      if tRelative is not empty then
         if tUp > 0 then put item 1 to -(tUp + 1) of tFolder into tFolder
         set the itemDelimiter to ":"
         if the number of items of tRelative > 1 then
            put item 1 to -2 of tRelative into tSub
            replace ":" with slash in tSub
            put tFolder & slash & tSub into tFolder
         end if
      end if
      repeat for each line tFile in files(tFolder)
         if char 1 to 2 of tFile is "._" or tFile ends with ".rsrc" then next repeat
         set the itemDelimiter to "."
         if tFile is pName or (the number of items of tFile > 1 and item 1 to -2 of tFile is pName) then
            return tFolder & slash & tFile
         end if
      end repeat
   end if
   if tSet["image"] is empty or there is not a file tSet["image"] then return empty
   try
      put revHyperCardImageStacks(tSet["image"]) into tStacks
   catch tError
      -- (the disk image library is the IDE's, and the Stack Player's)
      return empty
   end try
   set the itemDelimiter to ":"
   put item 1 to -2 of tSet["imagepath"] into tStackFolder
   put tStackFolder into tHFSFolder
   if tRelative is not empty then
      if tUp > 0 then put item 1 to -(tUp + 1) of tHFSFolder into tHFSFolder
      put tHFSFolder & ":" & item 1 to -2 of tRelative into tHFSFolder
      if char -1 of tHFSFolder is ":" then delete char -1 of tHFSFolder
   end if
   put -1 into tAnyShared
   repeat for each line tLine in tStacks
      set the itemDelimiter to tab
      put item 1 of tLine into tLine
      set the itemDelimiter to ":"
      if tLine is pStack or tLine is (tHFSFolder & ":" & pName) then
         put tLine into tPath
         exit repeat
      end if
      if the last item of tLine is pName then
         if pName is "Home" then
            put 0 into tShared
         else
            put _HCFoldersShared(item 1 to -2 of tLine, tStackFolder) into tShared
         end if
         if tShared > tAnyShared then
            put tLine into tAny
            put tShared into tAnyShared
         end if
      end if
   end repeat
   if tPath is empty and not pNear then put tAny into tPath
   if tPath is empty then return empty
   put the temporary folder & "/oxt-hypercard-" & the milliseconds into tFolder
   create folder tFolder
   put revHyperCardImageExtract(tSet["image"], tPath, tFolder) into tFile
   if the result is not empty then return empty
   -- (the copy goes once the stack is imported: _HCImport)
   return tFile & return & tSet["image"] & return & tPath
end _HCFindSibling

-- How many folders the HFS paths of two folders have in common from the
-- disk down ("Disk:A:B" and "Disk:A:C" have 2, the disk and A), names
-- compared as HFS compared them, case aside
private function _HCFoldersShared pOne, pTwo
   local tCount, i
   set the itemDelimiter to ":"
   put min(the number of items of pOne, the number of items of pTwo) into tCount
   repeat with i = 1 to tCount
      if item i of pOne is not item i of pTwo then return i - 1
   end repeat
   return tCount
end _HCFoldersShared

-- "Where is ...?", as HyperCard asked, in the IDE only, once a name
private function _HCWhereIs pName
   if the environment is not "development" then return empty
   if sHCAsked[pName] then return empty
   put true into sHCAsked[pName]
   answer file "Where is" && pName & "?"
   if the result is "Cancel" then return empty
   return it
end _HCWhereIs

-- Import the HyperCard stack in the file on line 1 of pFile (lines 2 and
-- 3: the disk image it was copied from, and its HFS path there, the copy
-- then deleted), with messages locked and its scripts fixed: the long id
-- of the stack, or empty
private function _HCImport pFile
   local tStack, tWasLocked, tPath, tFolder, tEach
   put line 1 of pFile into tPath
   put the lockMessages into tWasLocked
   lock messages
   try
      put the long id of stack tPath into tStack
   catch tError
      put empty into tStack
   end try
   if tStack is not empty then
      -- this engine's stack names have no commas: the name it gives
      if the short name of tStack contains comma then
         set the name of tStack to the short name of tStack
         put the long id of stack (the short name of tStack) into tStack
      end if
      if line 2 of pFile is empty then
         set the uHyperCard["file"] of tStack to tPath
      else
         set the uHyperCard["image"] of tStack to line 2 of pFile
         set the uHyperCard["imagepath"] of tStack to line 3 of pFile
         -- a name Windows refuses for a file was copied out under
         -- another (revHyperCardImageExtract): the stack gets its own
         if the platform is "Win32" then
            set the itemDelimiter to colon
            put the last item of line 3 of pFile into tEach
            replace slash with "-" in tEach
            replace comma with "_" in tEach
            if the short name of tStack is not tEach then
               set the name of tStack to tEach
               put the long id of stack tEach into tStack
            end if
         end if
      end if
      -- HyperCard's message order, as the stack it is gone to from has it
      -- (before its scripts are fixed, which compile them)
      try
         if the hyperTalkCompatible of stack (the mainStack of this stack) is true then
            set the hyperTalkCompatible of tStack to true
         end if
      catch tError
      end try
      try
         -- (the IDE's, and the Stack Player's)
         get revHyperCardFixScripts(tStack)
      catch tError
      end try
   end if
   set the lockMessages to tWasLocked
   if line 2 of pFile is not empty then
      set the itemDelimiter to slash
      put item 1 to -2 of tPath into tFolder
      repeat for each line tEach in files(tFolder)
         delete file (tFolder & slash & tEach)
      end repeat
      delete folder tFolder
   end if
   return tStack
end _HCImport

-- palette "Name", "h,v": open the palette (the importer makes each PLTE
-- resource a substack of that name) with its top left at h,v from the
-- card window's, where HyperCard put it (rule T46)
on hcPalette pName, pLocation
   if there is not a stack pName then return "Can't find palette" && pName
   palette stack pName
   if pLocation is not empty then set the topLeft of stack pName to _HCPlace("loc", pLocation, false)
   return empty
end hcPalette

-- open report printing: HyperCard's report templates are not imported
on hcOpenReportPrinting pWith
   return "Report printing is not supported"
end hcOpenReportPrinting

-- dial ... with modem: there is no modem to dial
on hcDial pNumber, pModemCommands
   return "dial with modem is not supported"
end hcDial

-- dial without a modem: HyperCard played the number's touch tones
-- through the speaker; here the call reaches the library by its name and
-- does nothing but say so in the result
on dial pNumber
   return "dial is not supported"
end dial

/*
answer program (rule T67): HyperCard 2.1's choice of a program on another
Macintosh, to send messages to, from the list its PPC Browser showed
under the prompt pPrompt; the choice went into it, and nothing when the
choice was cancelled. Here no program can be chosen: the prompt is shown
with a word that says so and a Cancel button, and the value is empty,
which the rewritten statement ("get hcAnswerProgram(...)") puts into it,
as HyperCard's cancelled choice did
*/
function hcAnswerProgram pPrompt
   local tText
   put "No program on another computer can be chosen here." into tText
   if pPrompt is not empty then put pPrompt & return & return before tText
   answer tText with "Cancel"
   return empty
end hcAnswerProgram

/*
ask password (rule T73): HyperCard put into it, not the reply, the number
it made from the reply (hcPasswordNumber), which scripts kept and
compared a later reply's with; when the dialog was cancelled, nothing,
and "Cancel" in the result. pIt is the caller's it
*/
on hcAskPassword @pIt, pPrompt, pDefault
   ask password clear pPrompt with pDefault
   if the result is "Cancel" then
      put empty into pIt
      return "Cancel"
   end if
   put hcPasswordNumber(it) into pIt
   return empty
end hcAskPassword

-- The codes HyperCard's ask password took a reply's letters to: a capital
-- to its small letter (65 to 90, by adding 32) and, from 128 on, as each
-- pair here has it, a letter with an accent to its letter without one
-- (HyperCard 2.2's own table, its code segment 42)
constant kHCPasswordFolds = "128,97 129,97 130,99 131,101 132,110 133,111 134,117 135,97 136,97 137,97 138,97 139,97 140,97 141,99 142,101 143,101 144,101 145,101 146,105 147,105 148,105 149,105 150,110 151,111 152,111 153,111 154,111 155,111 156,117 157,117 158,117 159,117 174,97 175,111 187,97 188,111 190,97 191,111 197,5 203,97 204,97 205,111 206,111 207,111 216,121 217,121 229,97 230,101 231,97 232,101 233,101 234,105 235,105 236,105 237,105 238,111 239,111 241,111 242,117 243,117 244,117"

/*
The number HyperCard's ask password gave for the reply pText (rule T73),
as HyperCard 2.2's code makes it: the reply in Mac Roman, at most 255
characters, its letters small and without accents (kHCPasswordFolds); a
seed of its first code (from -128 to 127) and its length; then, for each
bit of the reply from the first code's highest on, the next seed of
QuickDraw's Random (_HCRandom), added to the number when the bit is set.
An empty reply, or a sum of 0, gave 1114205292, "Bill" in four bytes.
The numbers stacks keep come out so: "journal" 1342878572 (If Monks Had
Macs' Journal), "secret" 1309466871 (Lab Logger), "debyehuckel"
3246591934 (BufferStack), an empty reply 1114205292 (Jerome's Journal)
*/
function hcPasswordNumber pText
   local tFolds, tPair, tCodes, tCount, tSeed, tSum, tBit, i
   repeat for each word tPair in kHCPasswordFolds
      put item 2 of tPair into tFolds[item 1 of tPair]
   end repeat
   put _HCMacCodes(pText, false) into tCodes
   put the number of elements of tCodes into tCount
   if tCount = 0 then return 1114205292
   repeat with i = 1 to tCount
      if tCodes[i] >= 65 and tCodes[i] <= 90 then
         add 32 to tCodes[i]
      else if tFolds[tCodes[i]] is not empty then
         put tFolds[tCodes[i]] into tCodes[i]
      end if
   end repeat
   put tCodes[1] + tCount into tSeed
   if tCodes[1] >= 128 then subtract 256 from tSeed
   if tSeed < 0 then add 4294967296 to tSeed
   put 0 into tSum
   repeat with i = 1 to tCount
      repeat with tBit = 7 down to 0
         put _HCRandom(tSeed) into tSeed
         if tCodes[i] div (2 ^ tBit) mod 2 = 1 then put (tSum + tSeed) mod 4294967296 into tSum
      end repeat
   end repeat
   if tSum = 0 then return 1114205292
   return tSum
end hcPasswordNumber

-- QuickDraw's Random: the seed after pSeed (from 0 to 4294967295),
-- (pSeed * 16807) mod 2147483647 in the steps of its 68000 code (Apple's
-- published source, Util.a), which give that for a seed from 1 to
-- 2147483646 and their own for one a reply's first code made negative
private function _HCRandom pSeed
   local tLow, tHigh
   put (pSeed mod 65536) * 16807 into tLow
   put (pSeed div 65536) * 16807 + tLow div 65536 into tHigh
   put (tLow mod 65536) - 2147483647 + (tHigh mod 32768) * 65536 + (2 * tHigh) div 65536 into pSeed
   if pSeed < 0 then add 2147483647 to pSeed
   return pSeed
end _HCRandom

-- The Unicode code points of Mac Roman's characters 128 to 255
constant kHCMacRoman = "196 197 199 201 209 214 220 225 224 226 228 227 229 231 233 232 234 235 237 236 238 239 241 243 242 244 246 245 250 249 251 252 8224 176 162 163 167 8226 182 223 174 169 8482 180 168 8800 198 216 8734 177 8804 8805 165 181 8706 8721 8719 960 8747 170 186 937 230 248 191 161 172 8730 402 8776 8710 171 187 8230 160 192 195 213 338 339 8211 8212 8220 8221 8216 8217 247 9674 255 376 8260 8364 8249 8250 64257 64258 8225 183 8218 8222 8240 194 202 193 203 200 205 206 207 204 211 212 63743 210 218 219 217 305 710 732 175 728 729 730 184 733 731 711"

-- The Mac Roman codes of the characters of pText, at most 255 (a Pascal
-- string's), in an array from 1: 63, a question mark, for a character
-- Mac Roman does not have. pUpper: small letters in capitals, as the
-- Toolbox's UprString made them, a to z and those with accents to code
-- 216 that Mac Roman has a capital of
private function _HCMacCodes pText, pUpper
   local tMac, tCodes, tCount, tPoint, tCode, tUpper, i
   put 127 into i
   repeat for each word tCode in kHCMacRoman
      add 1 to i
      put i into tMac[tCode]
   end repeat
   put 0 into tCount
   repeat for each codepoint tPoint in normalizeText(pText, "NFC")
      if tCount = 255 then exit repeat
      put codepointToNum(tPoint) into tCode
      if tCode >= 128 then
         put tMac[tCode] into tCode
         if tCode is empty then put 63 into tCode
      end if
      if pUpper and tCode >= 97 and tCode <= 122 then
         subtract 32 from tCode
      else if pUpper and tCode >= 128 and tCode <= 216 then
         put toUpper(tPoint) into tUpper
         if the number of codepoints of tUpper is 1 and tMac[codepointToNum(tUpper)] is not empty then
            put tMac[codepointToNum(tUpper)] into tCode
         end if
      end if
      add 1 to tCount
      put tCode into tCodes[tCount]
   end repeat
   return tCodes
end _HCMacCodes

-- start using and stop using a stack (rule T23), found as hcStackName
-- finds the stack of a "go": a library stack beside this one, or on its
-- disk image; one that cannot be found leaves the result set, where this
-- engine stopped with an error
on hcStartUsing pStack
   local tStack
   put hcStackName(pStack) into tStack
   if tStack is empty then return "Can't find stack" && pStack
   if word 1 of tStack is "stack" then
      start using tStack
   else
      start using stack tStack
   end if
   return empty
end hcStartUsing

on hcStopUsing pStack
   if there is not a stack pStack then return "Can't find stack" && pStack
   stop using stack pStack
   return empty
end hcStopUsing

----------------------------------------------------------------------
-- open an application (rule T40)
--
-- HyperCard's "open" launched an application, with a document when the
-- script named one ("open "My Letter" with "TeachText""). It asked "Where
-- is ...?" when it could not find the application, and when it could not
-- open it left "Couldn't open that application." in the result, which
-- scripts test, and the script went on. Here an "open" of anything but a
-- file, printing, a process or a socket is a "go", which stops the script
-- with an error; the import rewrites it as hcOpen.

-- The applications the user said where to find when asked, by name, for
-- as long as the library is open
local sHCApplications

/*
open pApplication, or pDocument with pApplication, as HyperCard did (rule
T40): the application is pApplication itself when there is such a file
(or, on a Mac, such an application's bundle), else one of that name in a
Mac's Applications folders, else the file the user gives when asked
"Where is ...?" (in the IDE, once a name, as for a stack). The document
is pDocument, or a file of that name beside this stack's file or the
HyperCard file it was imported from. Leaves "Couldn't open that
application." in the result when there is no application to launch or
it cannot be launched; an application already running counts as opened,
as HyperCard brought it to the front
*/
on hcOpen pApplication, pDocument
   local tApplication, tDocument, tResult
   put _HCApplication(pApplication) into tApplication
   if tApplication is empty then return "Couldn't open that application."
   if pDocument is not empty then put _HCDocument(pDocument) into tDocument
   put _HCLaunch(tApplication, tDocument) into tResult
   if tResult is not empty and tResult is not "process is already open" then return "Couldn't open that application."
   return empty
end hcOpen

-- The application pName names, as hcOpen finds it, or empty. HyperCard
-- named one by its HFS path ("Disk:Apps:TeachText") or by its name
private function _HCApplication pName
   local tName, tFolder, tPath
   if pName is empty then return empty
   if there is a file pName or (pName ends with ".app" and there is a folder pName) then return pName
   put _HCLastPart(pName) into tName
   if tName is empty then return empty
   if sHCApplications[tName] is not empty then return sHCApplications[tName]
   if the platform is "MacOS" then
      repeat for each item tFolder in "/Applications,/System/Applications," & specialFolderPath("home") & "/Applications"
         put tFolder & slash & tName into tPath
         if not (tPath ends with ".app") then put ".app" after tPath
         if there is a folder tPath then return tPath
      end repeat
   end if
   put _HCWhereIs(tName) into tPath
   if tPath is empty then return empty
   put tPath into sHCApplications[tName]
   return tPath
end _HCApplication

-- The document pDocument names, as hcOpen finds it: pDocument as it is
-- when there is no such file beside the stack either
private function _HCDocument pDocument
   local tName, tSet, tFolders, tFolder
   if there is a file pDocument or there is a folder pDocument then return pDocument
   put _HCLastPart(pDocument) into tName
   put the customProperties["uHyperCard"] of me into tSet
   set the itemDelimiter to slash
   put item 1 to -2 of (the effective filename of me) into tFolders
   put return & item 1 to -2 of tSet["file"] after tFolders
   repeat for each line tFolder in tFolders
      if tFolder is not empty and there is a file (tFolder & slash & tName) then return tFolder & slash & tName
   end repeat
   return pDocument
end _HCDocument

-- launch, in a handler of its own so that the result is launch's (on
-- Linux it is empty even when there was nothing to launch, which is why
-- _HCApplication finds the file first)
private function _HCLaunch pApplication, pDocument
   try
      if pDocument is empty then
         launch pApplication
      else
         launch pDocument with pApplication
      end if
   catch tError
      -- (a player that cannot start a process: the web's, a phone's)
      return "can't launch"
   end try
   return the result
end _HCLaunch

----------------------------------------------------------------------
-- HyperCard 2.2's menus (rules T22 and T48)
--
-- A HyperCard stack made its own menus with "create menu", "put ... into
-- menu ... with menuMsgs", "enable menuItem" and "set the checkMark of
-- menuItem", and read them back: "there is a menu", "the menus", "the
-- number of menuItems of menu", "menuItem 2 of menu", "menu "Font"". An
-- imported stack has no menu bar here, and this engine's "menu" names a
-- button of the IDE's menu bar, or stops the script with an error where
-- there is none. Those statements and values come here instead (rules
-- T22 and T48), and the menus are kept as the scripts make them: what a
-- script puts in a menu, checks, disables or renames reads back as it
-- was, and a doMenu of an item with a menu message sends that message.
-- The menus start as HyperCard 2.2's menu bar was at the scripting user
-- level, with the browse tool (_HCMenusInit), and "reset menubar" puts
-- them back so. The menus are not shown: verified statically and by the
-- importer's tests; the stack has no menu bar to show them in.

-- The menus: for each (by its name in lower case) ["name"], ["enabled"]
-- and ["count"], and for each item by number [n]["name"], [n]["enabled"],
-- [n]["checkmark"], [n]["menumessage"]...; sHCMenuOrder, their names one
-- a line in the menu bar's order; sHCMenusMade, whether they are made
local sHCMenus, sHCMenuOrder, sHCMenusMade

-- The items of HyperCard 2.2's menus, "-" a line between two and "..."
-- the ellipsis HyperCard wrote (_HCMenusInit). The Tools menu is a
-- palette of tools, which no script read as items, and the Font menu
-- lists the fonts here (_HCFontNames)
constant kHCAppleMenu = "About HyperCard..."
constant kHCFileMenu = "New Stack...,Open Stack...,Close Stack,Save a Copy...,-,Compact Stack,Protect Stack...,Delete Stack...,-,Page Setup...,Print Field...,Print Card,Print Stack...,Print Report...,-,Quit HyperCard"
constant kHCEditMenu = "Undo,-,Cut,Copy,Paste,Clear,-,New Card,Delete Card,Cut Card,Copy Card,-,Text Style...,Background,Icon...,Audio..."
constant kHCGoMenu = "Back,Home,Help,Recent,-,First,Prev,Next,Last,-,Find...,Message,Scroll,Next Window"
constant kHCObjectsMenu = "Button Info...,Field Info...,Card Info...,Bkgnd Info...,Stack Info...,-,Bring Closer,Send Farther,-,New Button,New Field,New Background"
constant kHCStyleMenu = "Plain,Bold,Italic,Underline,Outline,Shadow,Condense,Extend,Group,-,9,10,12,14,18,24,Other..."

-- The words that name a menu item by its place ("third menuItem of menu
-- 2"), besides "last" and "middle"
constant kHCMenuOrdinals = "first second third fourth fifth sixth seventh eighth ninth tenth"

on hcCreateMenu pMenu
   get _HCMenu(pMenu, true)
   return empty
end hcCreateMenu

-- delete menu pMenu, by its name or its number
on hcDeleteMenu pMenu
   local tKey, tOrder, tLine
   put _HCMenu(pMenu, false) into tKey
   if not _HCMenuExists(tKey) then return "Can't find menu" && pMenu
   delete variable sHCMenus[tKey]
   repeat for each line tLine in sHCMenuOrder
      if toLower(tLine) is not tKey then put tLine & return after tOrder
   end repeat
   delete the last char of tOrder
   put tOrder into sHCMenuOrder
   return empty
end hcDeleteMenu

-- put pItems into (after, before) menu pMenu [with menuMsgs pMessages];
-- put pItems into, after or before menuItem pItem of menu pMenu. The
-- items are separated by returns, else by commas; "-" is a line between
-- items
on hcPutIntoMenu pItems, pPreposition, pMenu, pMessages, pItem
   local tKey, tCount, tLine, i, tAt, tOld, tMessage
   put _HCMenu(pMenu, true) into tKey
   if return is in pItems then
      set the itemDelimiter to return
   end if
   put the number of items of pItems into tCount
   put sHCMenus[tKey]["count"] into tOld
   if pItem is not empty then
      put _HCMenuItemNumber(tKey, pItem) into tAt
      if tAt is 0 then return "Can't find menu item" && pItem
      if pPreposition is "into" then
         put item 1 of pItems into sHCMenus[tKey][tAt]["name"]
         -- (with menuMsg X: the item's message too)
         if pMessages is not empty then put word 1 to -1 of pMessages into sHCMenus[tKey][tAt]["menumessage"]
         return empty
      end if
      -- after or before the item: the new items go there
      if pPreposition is "before" then
         subtract 1 from tAt
      end if
   else if pPreposition is "into" then
      repeat with i = 1 to tOld
         delete variable sHCMenus[tKey][i]
      end repeat
      put 0 into tOld
      put 0 into tAt
   else if pPreposition is "before" then
      put 0 into tAt
   else
      put tOld into tAt
   end if
   -- the items after them move down
   repeat with i = tOld down to tAt + 1
      put sHCMenus[tKey][i] into sHCMenus[tKey][i + tCount]
   end repeat
   repeat with i = 1 to tCount
      put item i of pItems into tLine
      delete variable sHCMenus[tKey][tAt + i]
      put tLine into sHCMenus[tKey][tAt + i]["name"]
      put true into sHCMenus[tKey][tAt + i]["enabled"]
      put false into sHCMenus[tKey][tAt + i]["checkmark"]
   end repeat
   put tOld + tCount into sHCMenus[tKey]["count"]
   -- the menu messages, one per item, separated as the items are
   set the itemDelimiter to comma
   if return is in pMessages then set the itemDelimiter to return
   repeat with i = 1 to tCount
      put item i of pMessages into tMessage
      put word 1 to -1 of tMessage into sHCMenus[tKey][tAt + i]["menumessage"]
   end repeat
   return empty
end hcPutIntoMenu

-- enable and disable menu pMenu, or menuItem pItem of it
on hcEnableMenu pEnabled, pMenu, pItem
   local tKey, tAt
   put _HCMenu(pMenu, true) into tKey
   if pItem is empty then
      put pEnabled into sHCMenus[tKey]["enabled"]
      return empty
   end if
   put _HCMenuItemNumber(tKey, pItem) into tAt
   if tAt is 0 then return "Can't find menu item" && pItem
   put pEnabled into sHCMenus[tKey][tAt]["enabled"]
   return empty
end hcEnableMenu

-- set the pProperty of menuItem pItem of menu pMenu (of menu pMenu, if
-- pItem is empty) to pValue
on hcSetMenuItem pProperty, pMenu, pItem, pValue
   local tKey, tAt
   put _HCMenu(pMenu, true) into tKey
   put _HCMenuProperty(pProperty) into pProperty
   if pItem is empty then
      -- (a menu's new name, by which it is found from now on)
      if pProperty is "name" then return _HCRenameMenu(tKey, pValue)
      put pValue into sHCMenus[tKey][pProperty]
      return empty
   end if
   put _HCMenuItemNumber(tKey, pItem) into tAt
   if tAt is 0 then return "Can't find menu item" && pItem
   put pValue into sHCMenus[tKey][tAt][pProperty]
   return empty
end hcSetMenuItem

-- the pProperty of menuItem pItem of menu pMenu, as a script set it, or
-- HyperCard's default (enabled, no checkmark, plain); with pItem empty,
-- of menu pMenu (its name, whether it is enabled)
function hcMenuItem pProperty, pMenu, pItem
   local tKey, tAt, tValue
   put _HCMenu(pMenu, false) into tKey
   put _HCMenuProperty(pProperty) into pProperty
   if pItem is empty then
      if not _HCMenuExists(tKey) then return empty
      put sHCMenus[tKey][pProperty] into tValue
      if tValue is empty and pProperty is "enabled" then return true
      return tValue
   end if
   put _HCMenuItemNumber(tKey, pItem) into tAt
   if tAt is not 0 then put sHCMenus[tKey][tAt][pProperty] into tValue
   if tValue is empty then
      switch pProperty
         case "enabled"
            return true
         case "checkmark"
            return false
         case "textstyle"
            return "plain"
         case "name"
            -- (an item that is not there, by its name)
            if tAt is 0 and pItem is not an integer and pItem is not among the words of kHCMenuOrdinals \
                  and pItem is not among the words of "last middle" then
               return pItem
            end if
      end switch
   end if
   return tValue
end hcMenuItem

on hcDeleteMenuItem pMenu, pItem
   local tKey, tAt, i, tCount
   put _HCMenu(pMenu, false) into tKey
   put _HCMenuItemNumber(tKey, pItem) into tAt
   if tAt is 0 then return "Can't find menu item" && pItem
   put sHCMenus[tKey]["count"] into tCount
   repeat with i = tAt to tCount - 1
      put sHCMenus[tKey][i + 1] into sHCMenus[tKey][i]
   end repeat
   delete variable sHCMenus[tKey][tCount]
   put tCount - 1 into sHCMenus[tKey]["count"]
   return empty
end hcDeleteMenuItem

-- the menus: their names, one a line, in the menu bar's order
function hcMenus
   _HCMenusInit
   return sHCMenuOrder
end hcMenus

-- the number of menus
function hcMenuCount
   _HCMenusInit
   return the number of lines of sHCMenuOrder
end hcMenuCount

-- the number of menuItems of menu pMenu (0 if there is no such menu)
function hcMenuItemCount pMenu
   local tKey
   put _HCMenu(pMenu, false) into tKey
   if not _HCMenuExists(tKey) then return 0
   return sHCMenus[tKey]["count"]
end hcMenuItemCount

-- menu pMenu as a value: the names of its items, one a line ("put menu
-- "Font" into tFonts")
function hcMenuText pMenu
   local tKey, tText, i
   put _HCMenu(pMenu, false) into tKey
   repeat with i = 1 to sHCMenus[tKey]["count"]
      put sHCMenus[tKey][i]["name"] & return after tText
   end repeat
   delete the last char of tText
   return tText
end hcMenuText

-- there is a menu pMenu; there is a menuItem pItem of menu pMenu
function hcThereIsMenu pMenu, pItem
   local tKey
   put _HCMenu(pMenu, false) into tKey
   if not _HCMenuExists(tKey) then return false
   if the paramCount < 2 then return true
   return _HCMenuItemNumber(tKey, pItem) is not 0
end hcThereIsMenu

-- The menu message of a menu item, by its name, or empty (hcDoMenu sends
-- it, as HyperCard did): that of the first item of the name that has one
function hcMenuMessage pItem
   local tMenu, tKey, i, tBase
   if not sHCMenusMade then return empty
   put _HCMenuItemBase(pItem) into tBase
   repeat for each line tMenu in sHCMenuOrder
      put toLower(tMenu) into tKey
      repeat with i = 1 to sHCMenus[tKey]["count"]
         if sHCMenus[tKey][i]["menumessage"] is not empty \
               and (sHCMenus[tKey][i]["name"] is pItem or _HCMenuItemBase(sHCMenus[tKey][i]["name"]) is tBase) then
            return sHCMenus[tKey][i]["menumessage"]
         end if
      end repeat
   end repeat
   return empty
end hcMenuMessage

-- HyperCard's commands that this engine has too, which a menu message
-- can be (_HCSendMenuMessage)
constant kHCMenuCommands = "add answer ask beep choose click close convert create delete disable divide drag edit enable export find get go hide import lock mark multiply open palette play pop print push put read reply request reset save select send set show sort start stop subtract type unlock unmark visual wait write"

-- Sends pMessage, the menu message of an item chosen, to this card, as
-- HyperCard did. A handler of the stack's takes it, with its parameters
-- as send gives them ("doImport single"). One of HyperCard's commands
-- with parameters ("go to card id 90024", "hide field 1", "show fld
-- "Notes"") runs as it was written, as HyperCard ran a command of its own
-- that no handler took: send would hand it to the engine with its
-- parameters evaluated first, and hide the field named by the text of
-- field 1. A doMenu goes to the stack's doMenu handlers, called hcDoMenu
-- in a stack imported without HyperCard's message order (rule T15)
private command _HCSendMenuMessage pMessage
   local tName
   put word 1 of pMessage into tName
   if tName is "doMenu" then
      if the hyperTalkCompatible of stack (the mainStack of this stack) is not true then
         put "hcDoMenu" into word 1 of pMessage
      end if
   else if word 2 of pMessage is not empty and tName is among the words of kHCMenuCommands then
      do pMessage
      return the result
   end if
   send pMessage to this card
   return the result
end _HCSendMenuMessage

-- Makes the menus as HyperCard 2.2's menu bar had them at the scripting
-- user level, with the browse tool, the first time a script reads or
-- changes one; and again with pReset (reset menubar), the stack's own
-- menus and changes gone
private command _HCMenusInit pReset
   if sHCMenusMade and pReset is not true then exit _HCMenusInit
   put true into sHCMenusMade
   put empty into sHCMenus
   put empty into sHCMenuOrder
   _HCMenuMake "Apple", kHCAppleMenu
   _HCMenuMake "File", kHCFileMenu
   _HCMenuMake "Edit", kHCEditMenu
   _HCMenuMake "Go", kHCGoMenu
   _HCMenuMake "Tools", empty
   _HCMenuMake "Objects", kHCObjectsMenu
   _HCMenuMake "Font", _HCFontNames()
   _HCMenuMake "Style", kHCStyleMenu
end _HCMenusInit

-- One of HyperCard's menus, its items pItems ("..." the ellipsis)
private command _HCMenuMake pName, pItems
   replace "..." with numToCodepoint(8230) in pItems
   get _HCMenu(pName, true)
   if pItems is not empty then hcPutIntoMenu pItems, "into", pName, empty, empty
end _HCMenuMake

-- The fonts here, one a line in order, as HyperCard's Font menu listed
-- the Mac's: not the vertical forms Windows lists ("@MS Gothic"), nor
-- the fonts a system keeps to itself (".SF NS")
private function _HCFontNames
   local tFonts, tFont, tList, tLast
   put the fontNames into tFonts
   sort lines of tFonts
   repeat for each line tFont in tFonts
      if tFont is empty or char 1 of tFont is "@" or char 1 of tFont is "." or tFont is tLast then next repeat
      put tFont & return after tList
      put tFont into tLast
   end repeat
   delete the last char of tList
   return tList
end _HCFontNames

-- The key of pMenu in sHCMenus: the menu by its name, or by its number
-- in the menu bar ("menu 3" is Edit, as in HyperCard); the menu made if
-- pCreate and it is not there yet
private function _HCMenu pMenu, pCreate
   local tKey
   _HCMenusInit
   if pMenu is an integer and pMenu >= 1 and pMenu <= the number of lines of sHCMenuOrder then
      return toLower(line pMenu of sHCMenuOrder)
   end if
   put toLower(pMenu) into tKey
   if pCreate and pMenu is not empty and not _HCMenuExists(tKey) then
      put pMenu into sHCMenus[tKey]["name"]
      put true into sHCMenus[tKey]["enabled"]
      put 0 into sHCMenus[tKey]["count"]
      if sHCMenuOrder is empty then
         put pMenu into sHCMenuOrder
      else
         put return & pMenu after sHCMenuOrder
      end if
   end if
   return tKey
end _HCMenu

-- Whether there is a menu of the key pKey
private function _HCMenuExists pKey
   return pKey is not empty and sHCMenus[pKey]["name"] is not empty
end _HCMenuExists

-- set the name of menu ... to pName: the menu of the key pKey renamed,
-- unless another menu has the name
private function _HCRenameMenu pKey, pName
   local tNew, tOrder, tLine
   put toLower(pName) into tNew
   if tNew is not pKey then
      if pName is empty or _HCMenuExists(tNew) then return "Can't rename menu" && sHCMenus[pKey]["name"]
      put sHCMenus[pKey] into sHCMenus[tNew]
      delete variable sHCMenus[pKey]
   end if
   put pName into sHCMenus[tNew]["name"]
   repeat for each line tLine in sHCMenuOrder
      if toLower(tLine) is pKey then put pName into tLine
      put tLine & return after tOrder
   end repeat
   delete the last char of tOrder
   put tOrder into sHCMenuOrder
   return empty
end _HCRenameMenu

-- The number of an item of a menu, by its number, its name (with or
-- without its "...", or the ellipsis) or its place ("last", "first" ...
-- "tenth", "middle", when no item has that name), 0 if there is none
private function _HCMenuItemNumber pKey, pItem
   local i, tCount, tBase
   put sHCMenus[pKey]["count"] into tCount
   if tCount is not an integer then return 0
   if pItem is an integer then
      if pItem >= 1 and pItem <= tCount then return pItem
      return 0
   end if
   if pItem is empty then return 0
   put _HCMenuItemBase(pItem) into tBase
   repeat with i = 1 to tCount
      if sHCMenus[pKey][i]["name"] is pItem or _HCMenuItemBase(sHCMenus[pKey][i]["name"]) is tBase then return i
   end repeat
   if pItem is among the words of kHCMenuOrdinals then
      put wordOffset(pItem, kHCMenuOrdinals) into i
   else if pItem is "last" then
      put tCount into i
   else if pItem is "middle" then
      put (tCount + 1) div 2 into i
   else
      return 0
   end if
   if i >= 1 and i <= tCount then return i
   return 0
end _HCMenuItemNumber

-- A menu item's name without the "..." or the ellipsis after it, as
-- HyperCard took either
private function _HCMenuItemBase pName
   if pName ends with "..." then return char 1 to -4 of pName
   if char -1 of pName is numToCodepoint(8230) then return char 1 to -2 of pName
   return pName
end _HCMenuItemBase

private function _HCMenuProperty pProperty
   switch pProperty
      case "cmdchar"
         return "commandchar"
      case "menumsg"
         return "menumessage"
   end switch
   return toLower(pProperty)
end _HCMenuProperty

-- set the cursor to ... (rule T17): this engine's number for HyperCard's
-- cursor numbers (1 iBeam, 2 cross, 3 plus, 4 watch) and names, and the
-- image id of one of the stack's own cursors (its CURS resources, which
-- the import makes images of the group "HC cursors") by name. A cursor
-- that is none of these gives empty: the default cursor, where this
-- engine stopped with an error
function hcCursor pCursor
   local tGroup, i
   if pCursor is an integer then
      if pCursor >= 1 and pCursor <= 4 then return item pCursor of "9,7,13,14"
      if pCursor <= 29 then return pCursor
      -- a CURS resource with no image here (a copy of the stack without
      -- its resource fork) gives empty too, where the set stopped
      if there is an image id pCursor then return pCursor
      if there is an image id pCursor of stack (the mainStack of me) then return pCursor
      return empty
   end if
   put word 1 to -1 of pCursor into pCursor
   if pCursor is among the items of "none,busy,cross,ibeam,plus,watch,help,hand,arrow" then
      return item itemOffset(pCursor, "none,busy,cross,ibeam,plus,watch,help,hand,arrow") of "0,6,7,9,13,14,15,28,29"
   end if
   put "HC cursors" into tGroup
   if there is a background tGroup of me then
      repeat with i = 1 to the number of images of background tGroup of me
         if the short name of image i of background tGroup of me is pCursor then
            return the id of image i of background tGroup of me
         end if
      end repeat
   end if
   return empty
end hcCursor

/*
IdleCursor cursor (22 stacks), the XCMD: the cursor shown while no
handler runs, which HyperCard set back to its own, the hand, after each
one, as this engine sets back its own. The cursor is one set cursor
takes (hcCursor), the stack's own among them ("look", "Clade1");
"Hand", which the external's documentation gives for putting
HyperCard's back, puts back the one there was, and so do "none" and a
cursor that is not here. Here it is the defaultCursor, which every
window shows, the IDE's too: so the stack's is shown only while the
mouse is over one of the stack's windows (its own, or a palette's), and
the one there was (the browse cursor the IDE's preferences chose) comes
back as the mouse leaves them and when the stack closes or is deleted.
The library cannot see a stack go (most of these stacks' own closeStack
keeps the message from coming here, and a stack that goes as it closes
is deleted with messages locked), so a hidden stack it makes, which
outlives them, watches every stack with such a cursor five times a
second and puts back the one there was (kHCIdleCursorKeeper)
*/
constant kHCIdleCursorKeeper = "revHyperCardIdleCursor"

on IdleCursor pCursor
   local tCursor, tStack
   put word 1 to -1 of pCursor into pCursor
   if pCursor is not "hand" then put hcCursor(pCursor) into tCursor
   if tCursor is 0 then put empty into tCursor
   if tCursor is not empty then _HCIdleCursorKeeper
   if there is a stack kHCIdleCursorKeeper then
      put the long id of me into tStack
      dispatch "hcIdleCursorSet" to stack kHCIdleCursorKeeper with tStack, tCursor
   end if
   return empty
end IdleCursor

-- Sent by the keeper while the mouse is over one of the stack's windows:
-- the stack's cursor, set here so that its id is looked for among the
-- stack's images first, not those of another stack with the same id
on hcIdleCursorShow pCursor
   local tError
   try
      set the defaultCursor to pCursor
   catch tError
      -- (the stack's image is gone)
   end try
end hcIdleCursorShow

-- The keeper of IdleCursor's cursors, made the first time a stack has
-- one: a stack that is never opened, which outlives the stacks it
-- watches, with a name the IDE takes for one of its own (not listed with
-- the user's stacks, nor asked about as the IDE quits)
private command _HCIdleCursorKeeper
   local tDefault
   if there is a stack kHCIdleCursorKeeper then exit _HCIdleCursorKeeper
   put the defaultStack into tDefault
   lock messages
   get _HCNewHiddenStack(kHCIdleCursorKeeper)
   set the script of stack kHCIdleCursorKeeper to _HCIdleCursorKeeperScript()
   close stack kHCIdleCursorKeeper
   unlock messages
   set the defaultStack to tDefault
end _HCIdleCursorKeeper

-- The keeper's script. It shows the cursor of the stack the mouse is
-- over (its mainstack's), by asking that stack to (hcIdleCursorShow),
-- and puts back the one there was once the mouse is over no such stack,
-- or the stack has closed or gone: only over a cursor it showed, never
-- over one the IDE has set since. It keeps the one there was from the
-- first cursor it shows to the last, so that the mouse can go from one
-- such stack to another
private function _HCIdleCursorKeeperScript
   return "-- OXT-Beyond: IdleCursor's keeper (the HyperCard Library). sStacks: the" & return & \
         "-- stacks (long ids) with a cursor of their own, and the cursor; sWas: the" & return & \
         "-- defaultCursor before the first one shown; sShown: the one shown" & return & \
         "local sStacks, sWas, sShown, sWatching" & return & \
         "on hcIdleCursorSet pStack, pCursor" & return & \
         "   if pCursor is empty then" & return & \
         "      delete variable sStacks[pStack]" & return & \
         "   else" & return & \
         "      put pCursor into sStacks[pStack]" & return & \
         "   end if" & return & \
         "   idleCursorUpdate" & return & \
         "   if sStacks is not empty and sWatching is not true then" & return & \
         "      put true into sWatching" & return & \
         "      send " & quote & "hcIdleCursorWatch" & quote & " to me in 200 milliseconds" & return & \
         "   end if" & return & \
         "end hcIdleCursorSet" & return & \
         "on hcIdleCursorWatch" & return & \
         "   idleCursorUpdate" & return & \
         "   if sStacks is empty then" & return & \
         "      put false into sWatching" & return & \
         "   else" & return & \
         "      send " & quote & "hcIdleCursorWatch" & quote & " to me in 200 milliseconds" & return & \
         "   end if" & return & \
         "end hcIdleCursorWatch" & return & \
         "private command idleCursorUpdate" & return & \
         "   local tMouse, tStack, tOver, tError" & return & \
         "   try" & return & \
         "      put the mouseStack into tMouse" & return & \
         "      if tMouse is not empty then put the mainStack of stack tMouse into tMouse" & return & \
         "   catch tError" & return & \
         "      put empty into tMouse" & return & \
         "   end try" & return & \
         "   repeat for each key tStack in sStacks" & return & \
         "      if not exists(tStack) then" & return & \
         "         delete variable sStacks[tStack]" & return & \
         "      else if the mode of tStack is 0 then" & return & \
         "         delete variable sStacks[tStack]" & return & \
         "      else if tMouse is not empty and tMouse is the short name of tStack then" & return & \
         "         put tStack into tOver" & return & \
         "      end if" & return & \
         "   end repeat" & return & \
         "   if tOver is not empty then" & return & \
         "      if the defaultCursor is sStacks[tOver] then exit idleCursorUpdate" & return & \
         "      if sShown is empty then put the defaultCursor into sWas" & return & \
         "      dispatch " & quote & "hcIdleCursorShow" & quote & " to tOver with sStacks[tOver]" & return & \
         "      -- (a block: an else on the next line would be this if's)" & return & \
         "      if the defaultCursor is sStacks[tOver] then" & return & \
         "         put sStacks[tOver] into sShown" & return & \
         "      end if" & return & \
         "   else if sShown is not empty then" & return & \
         "      if the defaultCursor is sShown then" & return & \
         "         try" & return & \
         "            set the defaultCursor to sWas" & return & \
         "         catch tError" & return & \
         "            set the defaultCursor to 0" & return & \
         "         end try" & return & \
         "      end if" & return & \
         "      put empty into sShown" & return & \
         "   end if" & return & \
         "end idleCursorUpdate"
end _HCIdleCursorKeeperScript

-- set the rect of this card (rule T32): HyperCard 2.2 resized the card,
-- and with it the card window; here the stack's window takes the size
on hcSetCardRect pRect
   local i
   repeat with i = 2 to paramCount()
      put comma & param(i) after pRect
   end repeat
   if the number of items of pRect is not 4 then return "Invalid card size"
   repeat for each item i in pRect
      if i is not an integer then return "Invalid card size"
   end repeat
   set the width of this stack to item 3 of pRect - item 1 of pRect
   set the height of this stack to item 4 of pRect - item 2 of pRect
   return empty
end hcSetCardRect

-- A text style as HyperCard named it (rule T32): condense and extend are
-- condensed and expanded here, group is this engine's group (link), and
-- outline and shadow, which this engine does not have, are left out
function hcTextStyle
   local i, tStyles, tStyle, tOut
   repeat with i = 1 to paramCount()
      put param(i) & comma after tStyles
   end repeat
   repeat for each item tStyle in tStyles
      put word 1 to -1 of tStyle into tStyle
      if tStyle is "condense" then put "condensed" into tStyle
      if tStyle is "extend" then put "expanded" into tStyle
      if tStyle is empty or tStyle is among the words of "outline shadow" then next repeat
      put tStyle & comma after tOut
   end repeat
   delete the last char of tOut
   if tOut is empty then return "plain"
   return tOut
end hcTextStyle

/*
The paint text (rule T53): HyperCard's textFont, textSize, textHeight,
textStyle and textAlign of the text its text tool painted, set and read
with no object ("set textSize to 9", "the textHeight div 2"). This
engine paints no text with its text tool: it reads them as empty and
stops a script that sets the textStyle or the textAlign, where its
textFont, textSize and textHeight set so do nothing. They are kept here
as a script set them, by name, as the library keeps HyperCard's windows
and message box; one not set is as HyperCard's "reset paint" left it
(its reference: Geneva, 12, plain and left, and a textHeight of the
textSize and a third of it, 16)
*/
local sHCPaintText

-- HyperCard's text styles in the order of their flags (the Mac's, then
-- its own group), the order it gave a list back in whatever order it was
-- set in, as it kept the flags (scripts compare the textStyle with
-- "outline,condense" and "bold,underline,condense")
constant kHCPaintTextStyles = "bold italic underline outline shadow condense extend group"

-- set the textFont, the textSize, the textHeight, the textStyle or the
-- textAlign with no object (rule T53), kept for hcPaintText: a list of
-- styles ("bold,italic") comes as several parameters, and a textSize set
-- takes the textHeight back to its default, which follows the size. A
-- value HyperCard would have refused is kept as it is, as no script
-- stops here for it
on hcSetPaintText pProperty, pValue
   local i
   if pProperty is "textStyle" then
      repeat with i = 3 to paramCount()
         put comma & param(i) after pValue
      end repeat
      put _HCStyleList(pValue) into pValue
   else if pProperty is "textAlign" then
      put toLower(word 1 to -1 of pValue) into pValue
   end if
   put pValue into sHCPaintText[pProperty]
   if pProperty is "textSize" then put empty into sHCPaintText["textHeight"]
end hcSetPaintText

-- A list of text styles as HyperCard kept one it was set to (rules T53
-- and T72): each style once, in HyperCard's order, those it had not
-- after them, and plain, which is no style, when there is none
private function _HCStyleList pValue
   local tStyle, tStyles, tOthers, tList
   repeat for each item tStyle in pValue
      put word 1 to -1 of tStyle into tStyle
      if tStyle is among the words of kHCPaintTextStyles then
         put true into tStyles[tStyle]
      else if tStyle is not "plain" and tStyle is not empty then
         put comma & tStyle after tOthers
      end if
   end repeat
   repeat for each word tStyle in kHCPaintTextStyles
      if tStyles[tStyle] then put comma & tStyle after tList
   end repeat
   put tOthers after tList
   delete char 1 of tList
   if tList is empty then return "plain"
   return tList
end _HCStyleList

-- the textFont, the textSize, the textHeight, the textStyle or the
-- textAlign read with no object (rule T53): as hcSetPaintText kept it,
-- else HyperCard's default
function hcPaintText pProperty
   local tSize
   if sHCPaintText[pProperty] is not empty then return sHCPaintText[pProperty]
   switch pProperty
      case "textFont"
         return "Geneva"
      case "textSize"
         return 12
      case "textHeight"
         put hcPaintText("textSize") into tSize
         if tSize is not a number then return 16
         return tSize + tSize div 3
      case "textStyle"
         return "plain"
      case "textAlign"
         return "left"
   end switch
   return empty
end hcPaintText

-- reset paint (rule T53): HyperCard's took the paint text back to its
-- defaults with the rest, which this engine's reset paint, with no
-- paint text, leaves. HyperCard's never failed; this engine's sets the
-- rest all the same, and then stops the script where it cannot find the
-- brushes' images, which the IDE keeps in revIcons ("brush: can't find
-- image" in a standalone)
on hcResetPaint
   local tError
   put empty into sHCPaintText
   try
      reset paint
   catch tError
   end try
end hcResetPaint

/*
print of an expression (rule T71): HyperCard printed the text of any
expression ("print it", "print allHelp", "print "Index" & return &
temp"), with no dialog, in the print text below, inside the
printMargins, on as many pages as the text took. This engine prints
cards: it stops at such a print, which names none ("error in object
expression"), and does not compile one of strings joined with "&". The
text goes in a field the width of
the page inside the margins, on the card of a hidden stack as tall as
the page inside them, and the card is printed once for each page of the
field (its pageHeights), scrolled to that page. The engine lays out each
on a page of its own, as the card fills one, and after what a script
printed on the page before. Printing is opened and closed around the
pages, unless a script has it open already ("open printing", "print
printdump", "close printing", PowerNotes'): then they go in that job,
with no open and close of their own, which would end a job printing to
a PDF there and then. The result is printing's ("printing failed" where
there is no printer to print on)
*/
on hcPrint pText
   local tDefault, tLocked, tStack, tResult, tError
   put the defaultStack into tDefault
   put the lockMessages into tLocked
   -- (named here, so that it is deleted however far the printing got)
   put "revHyperCardPrint" && the milliseconds into tStack
   lock messages
   try
      _HCPrintStack tStack, pText
      put _HCPrintPages(tStack) into tResult
   catch tError
      put "printing failed" into tResult
   end try
   if there is a stack tStack then
      delete stack tStack
   end if
   set the defaultStack to tDefault
   set the lockMessages to tLocked
   return tResult
end hcPrint

-- The hidden stack pStack hcPrint prints, the size of the page inside
-- the printMargins, with pText in its field in the print text (a value
-- this engine refuses is HyperCard's default). The field shows nothing
-- but the text, from the card's left and top, which are the margins': a
-- field draws its first line a little above and to the left of its
-- margins (2 points and 6 on Linux), so its margins are what puts that
-- line's top left at the card's. Its bottom margin is its top one, so
-- that its formattedHeight reaches the last line's bottom: a field
-- scrolls no further than that, and the last page scrolls to it
private command _HCPrintStack pStack, pText
   local tMargins, tPaper, tWidth, tHeight, tSize, tStyle, tAlign, tError, tLeft, tTop
   put the printMargins into tMargins
   put the printPaperRectangle into tPaper
   put max(72, item 3 of tPaper - item 1 of tPaper - item 1 of tMargins - item 3 of tMargins) into tWidth
   put max(72, item 4 of tPaper - item 2 of tPaper - item 2 of tMargins - item 4 of tMargins) into tHeight
   get _HCNewHiddenStack(pStack)
   set the defaultStack to pStack
   -- (text laid out as it prints, as the IDE's revPrintText lays out its
   -- own)
   if the printerName is not "pdf" then
      set the formatForPrinting of stack pStack to true
   end if
   set the backColor of stack pStack to "white"
   set the width of stack pStack to tWidth
   set the height of stack pStack to tHeight
   create field "Text"
   set the showBorder of field "Text" to false
   set the borderWidth of field "Text" to 0
   set the opaque of field "Text" to false
   set the threeD of field "Text" to false
   set the showFocusBorder of field "Text" to false
   set the margins of field "Text" to 0
   set the lockText of field "Text" to true
   set the dontWrap of field "Text" to false
   set the rect of field "Text" to 0, 0, tWidth, tHeight
   set the textFont of field "Text" to hcPrintText("printTextFont")
   put hcPrintText("printTextSize") into tSize
   if tSize is not a number or tSize < 1 then put 10 into tSize
   set the textSize of field "Text" to tSize
   get hcPrintText("printTextHeight")
   if it is not a number or it < 1 then put tSize + tSize div 3 into it
   set the fixedLineHeight of field "Text" to true
   set the textHeight of field "Text" to it
   put hcTextStyle(hcPrintText("printTextStyle")) into tStyle
   try
      set the textStyle of field "Text" to tStyle
   catch tError
   end try
   set the text of field "Text" to "X"
   get the formattedRect of line 1 of field "Text"
   put max(0, 0 - item 1 of it) into tLeft
   put max(0, 0 - item 2 of it) into tTop
   set the margins of field "Text" to tLeft, tTop, tLeft, tTop
   put hcPrintText("printTextAlign") into tAlign
   if tAlign is not among the words of "left center right" then put "left" into tAlign
   set the textAlign of field "Text" to tAlign
   -- (empty lines at the end print nothing, and a page of them none)
   repeat while the last char of pText is return
      delete the last char of pText
   end repeat
   set the text of field "Text" to pText
end _HCPrintStack

-- Print the field of pStack (_HCPrintStack's, the defaultStack), a page
-- at a time: the field as tall as the page's text, scrolled to it. A job
-- is open while the printPageNumber is not empty
private function _HCPrintPages pStack
   local tHeights, tPage, tScroll, tWidth, tOpen, tResult
   put the pageHeights of field "Text" into tHeights
   put the width of field "Text" into tWidth
   put 0 into tScroll
   put the printPageNumber is empty into tOpen
   if tOpen then
      open printing
   end if
   repeat for each line tPage in tHeights
      set the rect of field "Text" to 0, 0, tWidth, tPage
      set the vScroll of field "Text" to tScroll
      print this card
      put the result into tResult
      add tPage to tScroll
   end repeat
   if tOpen then
      close printing
      put the result into tResult
   end if
   return tResult
end _HCPrintPages

/*
print <document> with <application> (rule T71): HyperCard had the
application print the document ("print temp with "teachText"", a file of
text the script had just written; "print thisFile with TeachText"). A
document of text is printed here as print prints an expression: its
text, in the print text, where TeachText printed it in its own. Any
other, which only its application can print, is not printed, and leaves
"Couldn't print that document." in the result, as a document that is not
there does. The document is found as "open" finds one (_HCDocument)
*/
on hcPrintDocument pDocument, pApplication
   local tPath, tText
   put _HCDocument(pDocument) into tPath
   if there is not a file tPath then return "Couldn't print that document."
   put URL ("file:" & tPath) into tText
   if numToChar(0) is in tText then return "Couldn't print that document."
   hcPrint tText
   return the result
end hcPrintDocument

/*
The print text (rule T72): HyperCard's printTextFont, printTextSize,
printTextHeight, printTextStyle and printTextAlign, which print of an
expression printed in (hcPrint). This engine keeps none of them: it sets
them to nothing and reads them as empty. They are kept here as a script
set them, by name, as the paint text is (rule T53); one not set is as
HyperCard had it (its reference: Geneva, 10, a printTextHeight of 13,
plain and left). The printTextHeight follows a printTextSize a script
sets until a script sets it, as the paint text's does: 13 is 10 and a
third of it, and stacks set the size alone (Book Reporter's Guild's 16)
*/
local sHCPrintText

-- set the printTextFont, the printTextSize, the printTextHeight, the
-- printTextStyle or the printTextAlign (rule T72), kept for hcPrintText
-- and hcPrint: a list of styles ("bold,italic") comes as several
-- parameters, and a printTextSize set takes the printTextHeight back to
-- its default, which follows the size
on hcSetPrintText pProperty, pValue
   local i
   if pProperty is "printTextStyle" then
      repeat with i = 3 to paramCount()
         put comma & param(i) after pValue
      end repeat
      put _HCStyleList(pValue) into pValue
   else if pProperty is "printTextAlign" then
      put toLower(word 1 to -1 of pValue) into pValue
   end if
   put pValue into sHCPrintText[pProperty]
   if pProperty is "printTextSize" then put empty into sHCPrintText["printTextHeight"]
end hcSetPrintText

-- the printTextFont, the printTextSize, the printTextHeight, the
-- printTextStyle or the printTextAlign read (rule T72): as
-- hcSetPrintText kept it, else HyperCard's default
function hcPrintText pProperty
   local tSize
   if sHCPrintText[pProperty] is not empty then return sHCPrintText[pProperty]
   switch pProperty
      case "printTextFont"
         return "Geneva"
      case "printTextSize"
         return 10
      case "printTextHeight"
         put hcPrintText("printTextSize") into tSize
         if tSize is not a number then return 13
         return tSize + tSize div 3
      case "printTextStyle"
         return "plain"
      case "printTextAlign"
         return "left"
   end switch
   return empty
end hcPrintText

-- reset printing (rule T72): HyperCard's took the print text back to its
-- defaults with the rest, as this engine's takes its own settings back
-- (the printMargins among them). In a script's own "open printing", this
-- engine's cancels the job, and the pages printed with it: there the
-- print text alone goes back
on hcResetPrinting
   put empty into sHCPrintText
   if the printPageNumber is empty then
      reset printing
   end if
end hcResetPrinting

-- sort the cards of a background (rule T54): HyperCard sorted the cards
-- of one background among the places they had and left the stack's
-- other cards where they were. This engine sorts the cards of a stack,
-- or its marked cards, and refuses a background, so the rule writes
-- "hcSortBegin the long id of <the background>, <marked>; sort marked
-- cards ... by ...; hcSortEnd": hcSortBegin marks the background's cards
-- of the stack the sort sorts (with pMarked, those of them that are
-- marked) and keeps its order and marks, the engine's sort puts the
-- marked cards in their order, by the script's own expression, and
-- hcSortEnd puts them in the places the background's cards had, the
-- other cards where they were, and the marks as they were.
-- The engine's sort takes the cards from the current card round, so
-- hcSortBegin starts it on the first card: cards whose keys are equal
-- keep the stack's order. It ends on the first card, with closeCard and
-- openCard if that is another card (messages unlocked), and so does
-- this; the screen and messages stay locked from hcSortBegin to
-- hcSortEnd, so no other card sees a message, and no window comes
-- forward (the stack's currentCard, not "go")
local sHCSort

on hcSortBegin pBackground, pMarked
   local tStack, tBackground, tId
   put the long id of stack (the defaultStack) into tStack
   put the short id of pBackground into tBackground
   put empty into sHCSort
   put tStack into sHCSort["stack"]
   put the cardIDs of tStack into sHCSort["order"]
   put the short id of this card of tStack into sHCSort["card"]
   put the lockMessages into sHCSort["lock"]
   lock screen
   lock messages
   repeat for each line tId in sHCSort["order"]
      put the mark of card id tId of tStack into sHCSort["marked"][tId]
      if tBackground is among the lines of the backgroundIDs of card id tId of tStack \
            and (pMarked is not true or sHCSort["marked"][tId]) then
         put true into sHCSort["sorted"][tId]
         set the mark of card id tId of tStack to true
      else
         set the mark of card id tId of tStack to false
      end if
   end repeat
   set the currentCard of tStack to 1
end hcSortBegin

on hcSortEnd
   local tStack, tId, tSorted, tOrder, i
   if sHCSort["stack"] is empty then exit hcSortEnd
   put sHCSort["stack"] into tStack
   if not exists(tStack) then
      set the lockMessages to sHCSort["lock"]
      unlock screen
      put empty into sHCSort
      exit hcSortEnd
   end if
   -- the background's cards in their new order, in the places they had
   repeat for each line tId in the cardIDs of tStack
      if sHCSort["sorted"][tId] then put tId & return after tSorted
   end repeat
   put 0 into i
   repeat for each line tId in sHCSort["order"]
      if sHCSort["sorted"][tId] then
         add 1 to i
         put line i of tSorted & return after tOrder
      else
         put tId & return after tOrder
      end if
   end repeat
   put 0 into i
   repeat for each line tId in tOrder
      add 1 to i
      if there is a card id tId of tStack and the number of card id tId of tStack is not i then
         set the number of card id tId of tStack to i
      end if
   end repeat
   repeat for each line tId in sHCSort["order"]
      if there is a card id tId of tStack then set the mark of card id tId of tStack to sHCSort["marked"][tId]
   end repeat
   -- back to the card the sort began on, quietly, then to the first
   if there is a card id sHCSort["card"] of tStack then
      set the currentCard of tStack to the number of card id sHCSort["card"] of tStack
   end if
   set the lockMessages to sHCSort["lock"]
   set the currentCard of tStack to 1
   unlock screen
   put empty into sHCSort
end hcSortEnd

-- find in the marked cards (rule T58): HyperCard's "find ... of marked
-- cards" searched the marked cards alone. This engine's find has no such
-- form, but passes over a card or a field whose dontSearch is true, so
-- the rule writes "hcFindMarkedBegin; find ...; hcFindMarkedEnd the
-- result": hcFindMarkedBegin sets the dontSearch of each card of the
-- stack that is not marked, the engine's find searches the others, by
-- the script's own form and text, and hcFindMarkedEnd sets back what
-- hcFindMarkedBegin set and gives back the find's result ("not found",
-- or empty when it found the text), which the script reads after it.
-- The engine's find in a field searches it on every card, a card's
-- dontSearch or not, so a find in a field ("find string x in bkgnd
-- field "alpha pool" of marked cards") is written "hcFindMarkedBegin the
-- long id of bkgnd field "alpha pool"; find string x; ...": on the
-- marked cards, hcFindMarkedBegin sets the dontSearch of the fields that
-- are not one of that name, of a background if it is (of the card if
-- not), so that the find searches that field alone, as HyperCard did.
-- Only what was not set already is set, and set back; a find that
-- stopped the script before hcFindMarkedEnd has it set back by the next
-- hcFindMarkedBegin
local sHCFindMarked

on hcFindMarkedBegin pField
   local tStack, tId, tName, tKind, i, tField
   _HCFindMarkedRestore
   put the long id of stack (the defaultStack) into tStack
   put tStack into sHCFindMarked["stack"]
   if pField is not empty then
      put the short name of pField into tName
      put word 1 of the long id of the owner of pField into tKind
   end if
   repeat for each line tId in the cardIDs of tStack
      if not the mark of card id tId of tStack then
         if not the dontSearch of card id tId of tStack then
            set the dontSearch of card id tId of tStack to true
            put true into sHCFindMarked["cards"][tId]
         end if
         next repeat
      end if
      if pField is empty then next repeat
      repeat with i = 1 to the number of fields of card id tId of tStack
         put the short id of field i of card id tId of tStack into tField
         if sHCFindMarked["fields"][tField] is not empty or the dontSearch of field i of card id tId of tStack then next repeat
         if the short name of field i of card id tId of tStack is tName \
               and word 1 of the long id of the owner of field i of card id tId of tStack is tKind then
            next repeat
         end if
         set the dontSearch of field i of card id tId of tStack to true
         put tId into sHCFindMarked["fields"][tField]
      end repeat
   end repeat
end hcFindMarkedBegin

on hcFindMarkedEnd pResult
   _HCFindMarkedRestore
   return pResult
end hcFindMarkedEnd

private command _HCFindMarkedRestore
   local tStack, tId, tField
   put sHCFindMarked["stack"] into tStack
   if tStack is not empty and exists(tStack) then
      repeat for each key tId in sHCFindMarked["cards"]
         if there is a card id tId of tStack then set the dontSearch of card id tId of tStack to false
      end repeat
      repeat for each key tField in sHCFindMarked["fields"]
         put sHCFindMarked["fields"][tField] into tId
         if there is a field id tField of card id tId of tStack then
            set the dontSearch of field id tField of card id tId of tStack to false
         end if
      end repeat
   end if
   put empty into sHCFindMarked
end _HCFindMarkedRestore

-- choose tool N (rule T30): HyperCard's tools by their numbers in the
-- tools palette (1 browse to 18 polygon), or by a name with or without
-- "tool" after it; this engine's "choose tool x" stops with an error
-- whatever x is. A tool that is none of these leaves the tool as it was
-- and "No such tool" in the result
on hcChooseTool pTool
   local tNames
   put "browse,button,field,select,lasso,pencil,brush,eraser,line,spray can,rectangle,round rectangle,bucket,oval,curve,text,regular polygon,polygon" into tNames
   put toLower(word 1 to -1 of pTool) into pTool
   if word -1 of pTool is "tool" then put word 1 to -2 of pTool into pTool
   if pTool is an integer and pTool >= 1 and pTool <= 18 then put item pTool of tNames into pTool
   if pTool is "btn" then put "button" into pTool
   if pTool is "fld" then put "field" into pTool
   if pTool is "spray" then put "spray can" into pTool
   if pTool is among the items of tNames or pTool is "pointer" then
      choose (pTool && "tool")
      return empty
   end if
   return "No such tool"
end hcChooseTool

-- tabKey, arrowKey, returnKey, enterKey, returnInField, enterInField and
-- functionKey as commands (rule T18): HyperCard sent the message to the
-- current card, and did what the key did if no handler took it. Here
-- the message goes to this card the same way, and what the key did is
-- below; a handler of the message that sends it again gets the key's
-- action, not its own message (HyperCard would have looped)
local sHCInKey
-- (and the result the handler that took the message left)
local sHCKeyResult

on hcTabKey
   if _HCKeyHandled("tabKey") then exit hcTabKey
   _HCNextField
end hcTabKey

on hcArrowKey pDirection
   if _HCKeyHandled("arrowKey", pDirection) then exit hcArrowKey
   switch pDirection
      case "left"
         go prev card
         break
      case "right"
         go next card
         break
      case "up"
         go forth
         break
      case "down"
         go back
         break
   end switch
end hcArrowKey

on hcReturnKey
   get _HCKeyHandled("returnKey")
end hcReturnKey

on hcEnterKey
   get _HCKeyHandled("enterKey")
end hcEnterKey

on hcReturnInField
   if _HCKeyHandled("returnInField") then exit hcReturnInField
   if the selectedField is not empty then put return into the selection
end hcReturnInField

on hcEnterInField
   if _HCKeyHandled("enterInField") then exit hcEnterInField
   select empty
end hcEnterInField

on hcFunctionKey pKey
   if _HCKeyHandled("functionKey", pKey) then exit hcFunctionKey
   -- F1 to F4: undo, cut, copy, paste
   try
      switch pKey
         case 1
            undo
            break
         case 2
            cut
            break
         case 3
            copy
            break
         case 4
            paste
            break
      end switch
   catch tError
   end try
end hcFunctionKey

-- help as a command (rule T18): HyperCard sent the message from the
-- object whose script ran it, as any command, and went to its Help
-- stack if no handler took it (Home's Help button, the Help menu's
-- item). Here the message goes from that object, pObject, the same way
-- (a stack's own "on help" takes it, and "pass help" goes on), and then
-- to a stack "HyperCard Help" found as a "go" finds one, without asking
-- where it is. None found leaves "No such card" in the result, as a "go"
-- does, where this engine stopped with "can't find handler" (10 stacks
-- of the corpus call help with no handler of their own). With no pObject
-- it is HyperCard's own handler ("send help to HyperCard", rule T29).
-- The library has no handler of help itself, so the message this engine
-- sends for the F1 and Help keys goes where it went
on hcHelp pObject
   local tStack
   if pObject is not empty then
      if _HCKeyHandled("help", empty, pObject) then return sHCKeyResult
   end if
   put _HCFindStack("HyperCard Help", false, false) into tStack
   if tStack is empty then return "No such card"
   if word 1 of tStack is "stack" then
      go to tStack
   else
      go to stack tStack
   end if
   return the result
end hcHelp

-- quit as a command (rule T70): HyperCard had no quit command but sent
-- the message quit as it quit, and a script that called quit sent that
-- message as any command: a stack's own "on quit" took it (Preschool
-- Primer's QUIT buttons, whose stack's "on quit" chooses Quit
-- HyperCard; rule T1 names that handler hc_quit, as this engine takes no
-- handler called quit), and HyperCard let it go if no handler did (NAIC
-- Stack's "if it is "Cancel" then quit", Universal Card Copier's "quit
-- mouseUp" after an error). This engine's quit quits at once, in the IDE
-- the IDE itself, past the stack's handler. Here the message goes from
-- the object whose script ran it, pObject, with pParameter if the script
-- gave one, and ends there if no handler takes it
on hcQuit pObject, pParameter
   if the paramCount > 1 then
      dispatch "hc_quit" to pObject with pParameter
   else
      dispatch "hc_quit" to pObject
   end if
end hcQuit

-- (pTarget: the object the message goes to, this card if it is empty)
private function _HCKeyHandled pMessage, pParameter, pTarget
   local tHandled
   if sHCInKey[pMessage] then return false
   put true into sHCInKey[pMessage]
   try
      if pTarget is not empty then
         dispatch pMessage to pTarget
      else if pParameter is empty then
         dispatch pMessage to this card
      else
         dispatch pMessage to this card with pParameter
      end if
      put the result into sHCKeyResult
      put it into tHandled
   catch tError
      put false into sHCInKey[pMessage]
      throw tError
   end try
   put false into sHCInKey[pMessage]
   return tHandled is "handled"
end _HCKeyHandled

-- The next field of this card that can be typed in, after the one being
-- typed in, its text selected
private command _HCNextField
   local tCount, tStart, i, tField
   put the number of fields of this card into tCount
   if tCount = 0 then exit _HCNextField
   put 0 into tStart
   if word 1 of the selectedField is "field" then put the number of the selectedField into tStart
   repeat with i = 1 to tCount
      put ((tStart + i - 1) mod tCount) + 1 into tField
      if the visible of field tField of this card and not the lockText of field tField of this card then
         select text of field tField of this card
         exit _HCNextField
      end if
   end repeat
end _HCNextField

-- flash n: the screen inverted and back n times (3 if n is left out), as
-- HyperCard did it. Here the card window is inverted, by a graphic made
-- for the purpose and deleted after
on flash pTimes
   local tGraphic, tWasLocked
   if pTimes is not an integer then put 3 into pTimes
   put the lockMessages into tWasLocked
   lock messages
   try
      create graphic "HC Flash"
      put the long id of it into tGraphic
      set the style of tGraphic to "rectangle"
      set the opaque of tGraphic to true
      set the lineSize of tGraphic to 0
      set the backgroundColor of tGraphic to "white"
      set the ink of tGraphic to "blendDifference"
      set the rect of tGraphic to 0, 0, the width of this card, the height of this card
      set the visible of tGraphic to false
      repeat pTimes times
         set the visible of tGraphic to true
         wait 3 ticks
         set the visible of tGraphic to false
         wait 3 ticks
      end repeat
   catch tError
   end try
   if tGraphic is not empty and exists(tGraphic) then delete tGraphic
   set the lockMessages to tWasLocked
end flash

-- show and hide card picture, background picture (rule T19): the paint
-- of the card or of its background, which the import makes an image
-- with no name, the first on the card or in the background
on hcShowPicture pWhich, pShow, pObject
   local tOwner, tImage
   put _HCPictureOwner(pWhich, pObject) into tOwner
   if tOwner is empty then return "No background picture"
   put _HCPictureIn(tOwner) into tImage
   if tImage is not empty then set the visible of tImage to (pShow is true)
   return empty
end hcShowPicture

-- the showPict of a card or a background (rule T52): whether its
-- picture, as hcShowPicture finds it, is shown; true where it has none,
-- as for a new card in HyperCard
function hcShowPict pWhich, pObject
   local tOwner, tImage
   put _HCPictureOwner(pWhich, pObject) into tOwner
   if tOwner is not empty then put _HCPictureIn(tOwner) into tImage
   if tImage is empty then return true
   return the visible of tImage
end hcShowPict

-- The card or background whose picture hcShowPicture and hcShowPict
-- take: pObject (this card if empty), or with pWhich "background" the
-- background of the card pObject. Empty if that card has none. (This
-- engine counts no backgrounds of a card, and its "background 1 of"
-- a card is the stack's first: the card's are its backgroundIDs)
private function _HCPictureOwner pWhich, pObject
   local tId
   if pObject is empty then put the long id of this card into pObject
   if pWhich is "background" and word 1 of the long name of pObject is "card" then
      put line 1 of the backgroundIDs of pObject into tId
      if tId is empty then return empty
      return the long id of background id tId of pObject
   end if
   return pObject
end _HCPictureOwner

-- The picture of the card or background pOwner: the image with no name
-- the import made of its paint, the first in it. Empty if it has none
private function _HCPictureIn pOwner
   local i, tImage
   repeat with i = 1 to the number of images of pOwner
      put the long id of image i of pOwner into tImage
      -- (an image with no name is called by its id)
      if the long id of the owner of tImage is the long id of pOwner and the short name of tImage ends with "image id" && the id of tImage then
         return tImage
      end if
   end repeat
   return empty
end _HCPictureIn

-- HyperCard's own windows, which this engine does not have: their
-- properties as scripts set them (rule T28), and whether they are shown
constant kHCOwnWindows = "tool,tools,pattern,patterns,scroll,fatbits,navigator,variable watcher,message watcher"
local sHCWindows

-- One of HyperCard's own windows by one name whatever a script called
-- it ("Tools", "tool"), or empty for another window
private function _HCOwnWindow pName
   put toLower(pName) into pName
   if pName is not among the items of kHCOwnWindows then return empty
   if pName is among the words of "tools patterns" then delete the last char of pName
   return pName
end _HCOwnWindow

/*
Where HyperCard put its windows (rule T46). A card window's location was
its top left on the screen; every other window's (the message box, a
palette, a picture, an external's window) was its top left from the card
window's top left, as were its rect, top, left, bottom and right, and its
globalLoc and globalRect were its place on the screen. Here a stack is
placed on the screen, and its loc is its centre. The stacks that stand
for such windows here: the palettes the import makes from PLTE resources
(each script begins with this line), the picture command's windows and
the Promptoid's
*/
constant kHCPaletteFirstLine = "-- HyperCard palette (PLTE resource), made by the HyperCard importer"
constant kHCPlaces = "loc,rect,topleft,bottomright,top,left,bottom,right"

private function _HCCardRelative pStack
   if the uHyperCard["picture"] of pStack is true or the uHyperCard["promptoid"] of pStack is true then return true
   try
      return line 1 of the script of pStack is kHCPaletteFirstLine
   catch tError
      -- (a stack whose script is not to be read is none of them)
      return false
   end try
end _HCCardRelative

-- A window's place (pProp: a point, a rectangle or one side) from
-- HyperCard's, from the card window's top left, to the screen, or back
-- (pBack). The card window is this stack's, or the window of the stack
-- whose library this is when this stack is a palette or a picture
private function _HCPlace pProp, pValue, pBack
   local tOrigin, tH, tV, i
   if _HCCardRelative(the long id of this stack) then
      put the topLeft of me into tOrigin
   else
      put the topLeft of this stack into tOrigin
   end if
   put item 1 of tOrigin into tH
   put item 2 of tOrigin into tV
   if pBack then
      put -tH into tH
      put -tV into tV
   end if
   switch pProp
      case "loc"
      case "topleft"
      case "bottomright"
         if the number of items of pValue is not 2 or item 1 of pValue is not a number or item 2 of pValue is not a number then return pValue
         return (item 1 of pValue + tH) & comma & (item 2 of pValue + tV)
      case "rect"
         if the number of items of pValue is not 4 then return pValue
         repeat with i = 1 to 4
            if item i of pValue is not a number then return pValue
         end repeat
         return (item 1 of pValue + tH) & comma & (item 2 of pValue + tV) & comma & (item 3 of pValue + tH) & comma & (item 4 of pValue + tV)
      case "left"
      case "right"
         if pValue is not a number then return pValue
         return pValue + tH
      case "top"
      case "bottom"
         if pValue is not a number then return pValue
         return pValue + tV
   end switch
   return pValue
end _HCPlace

-- show, hide and close window (rule T21): a window that is a stack here
-- (a palette the import made, a picture the picture command opened, or
-- any stack), the message box, and HyperCard's own windows, which are
-- not here (the tool, pattern, scroll, FatBits and navigator windows,
-- the watchers): left alone, as an error here would stop the script,
-- but shown or hidden as far as hcWindowProperty("visible", ...) reads.
-- The card window (rule T46) is the window of this stack. At a place,
-- the window's top left goes there, where HyperCard put it (see
-- _HCPlace)
on hcWindow pVerb, pName, pLocation
   local i, tWindow
   -- (a location written h,v comes as two parameters)
   repeat with i = 4 to paramCount()
      put comma & param(i) after pLocation
   end repeat
   if pName is among the items of "message,msg,message box,message window" then
      if pVerb is not "show" then
         hide message box
         return empty
      end if
      show message box
      if pLocation is not empty then hcSetMessageBox "loc", pLocation
      return empty
   end if
   put _HCOwnWindow(pName) into tWindow
   if tWindow is not empty then
      put (pVerb is "show") into sHCWindows[tWindow]["visible"]
      if pVerb is "show" and pLocation is not empty then put pLocation into sHCWindows[tWindow]["loc"]
      return empty
   end if
   if pName is "card window" then
      switch pVerb
         case "show"
            if pLocation is not empty then set the topLeft of this stack to pLocation
            show this stack
            break
         case "hide"
            hide this stack
            break
         case "close"
            close this stack
            break
      end switch
      return empty
   end if
   if there is not a stack pName then return "Can't find window" && pName
   switch pVerb
      case "show"
         if pLocation is not empty then
            if _HCCardRelative(the long id of stack pName) then put _HCPlace("loc", pLocation, false) into pLocation
            set the topLeft of stack pName to pLocation
         end if
         if the mode of stack pName is 0 then
            -- (a hidden stack opens hidden)
            set the visible of stack pName to true
            if the uHyperCard["picture"] of stack pName is true then
               _HCPictureWindow pName
            else
               palette stack pName
            end if
         else
            show stack pName
         end if
         break
      case "hide"
         hide stack pName
         break
      case "close"
         if the uHyperCard["picture"] of stack pName is true then
            delete stack pName
         else
            close stack pName
         end if
         break
   end switch
   return empty
end hcWindow

-- picture name, type, style, visible, depth, floating (hcPicture after
-- the import, rule T18: a handler called "picture" here stops every
-- function of its script being found): HyperCard's picture command, a
-- window that shows a picture. The picture is the
-- stack's PICT resource of that name (type "resource": the import made
-- each one an image of the group "HC Pictures") or a file of that name
-- beside the file the stack was imported from (type "file", in a format
-- this engine reads); the window is a stack of that name, which show,
-- hide and close window act on. The style and depth are not kept
on hcPicture pName, pType, pStyle, pVisible, pDepth, pFloating
   local tDefault, tTitle, tSource, tFile, tStack, tSet, i
   if pType is empty then put "file" into pType
   put pName into tTitle
   if char -1 of tTitle is ":" then delete char -1 of tTitle
   set the itemDelimiter to ":"
   put the last item of tTitle into tTitle
   set the itemDelimiter to comma
   if pType is not among the items of "resource,file" then
      return "Can't show a picture from" && pType
   end if
   if pType is "resource" and there is a background "HC Pictures" of me then
      repeat with i = 1 to the number of images of background "HC Pictures" of me
         if the short name of image i of background "HC Pictures" of me is tTitle then
            put the long id of image i of background "HC Pictures" of me into tSource
            exit repeat
         end if
      end repeat
   end if
   if pType is "file" then
      put the customProperties["uHyperCard"] of me into tSet
      set the itemDelimiter to slash
      if tSet["file"] is not empty then put item 1 to -2 of tSet["file"] & slash & tTitle into tFile
      if tFile is not empty and there is not a file tFile then put empty into tFile
   end if
   if tSource is empty and tFile is empty then
      return "Can't find picture" && pName
   end if
   put the defaultStack into tDefault
   if there is a stack tTitle and the uHyperCard["picture"] of stack tTitle is true then
      delete stack tTitle
   end if
   get _HCNewHiddenStack(tTitle)
   put the long id of it into tStack
   set the uHyperCard["picture"] of tStack to true
   set the title of tStack to tTitle
   set the defaultStack to the short name of tStack
   create image "Picture"
   if tFile is not empty then
      set the filename of image "Picture" to tFile
   else
      set the text of image "Picture" to the text of tSource
   end if
   set the topLeft of image "Picture" to 0,0
   set the width of tStack to max(the formattedWidth of image "Picture", 32)
   set the height of tStack to max(the formattedHeight of image "Picture", 32)
   set the defaultStack to tDefault
   if pVisible is not false then
      _HCReadyToShow tStack
      if pFloating is true then
         palette stack tTitle
      else
         _HCPictureWindow tTitle
      end if
      set the defaultStack to tDefault
   end if
   -- (closed, the window is gone, as in HyperCard)
   set the destroyStack of tStack to true
   return empty
end hcPicture

-- Readies pStack, a window the library made hidden so that it was not
-- seen being made, to be shown by the modal, palette or topLevel that
-- opens it next. Made, it opened hidden, and a hidden stack opens hidden:
-- a dialog that is not seen and is not waited for (the list dialogs gave
-- back what Cancel gives, at once), a palette or picture never seen. It
-- is closed, with no message sent, and made visible, so that it opens
-- shown, as the window asked for
private command _HCReadyToShow pStack
   local tLocked
   put the lockMessages into tLocked
   lock messages
   close pStack
   set the lockMessages to tLocked
   set the visible of pStack to true
end _HCReadyToShow

-- A new invisible stack named pName, for one of the library's windows,
-- as "create invisible stack" makes it, with what create puts into "it"
-- returned. It is made with the recent cards locked: create opens a
-- stack, and the card it opened on was the most recent card, where a
-- stack's "go back", or its "pop card" after a "push recent card", went
-- next. HyperCard's own windows were never cards to go back to. (A new
-- stack is not one with HyperCard's order, whose cards lockRecent lets
-- through)
private function _HCNewHiddenStack pName
   local tRecent
   put the lockRecent into tRecent
   set the lockRecent to true
   create invisible stack pName
   set the lockRecent to tRecent
   return it
end _HCNewHiddenStack

-- topLevel stack pName, a picture window, with the recent cards locked,
-- as _HCNewHiddenStack makes it: a window opened as a document is
-- otherwise the most recent card
private command _HCPictureWindow pName
   local tRecent
   put the lockRecent into tRecent
   set the lockRecent to true
   topLevel stack pName
   set the lockRecent to tRecent
end _HCPictureWindow

/*
set the P of window W to V (rule T26), for the properties of HyperCard's
picture and palette windows that this engine's windows do not have:
scale (-5 to 5, the picture shown at 2 to that power) and scroll (the
point of the picture at the window's top left) of a picture window;
hilitedButton (its number, 0 for none) of a palette; globalLoc and
globalRect, the window's place on the screen. The card window ("card
window") always shows the whole card here, so its scroll is left as it
is, as are zoom and dithering. A window that is not open leaves "No
such window" in the result, as HyperCard said, rather than an error
*/
-- the visible (or another property) of one of HyperCard's own windows:
-- what a script set, or false for the visible of one never shown. The
-- place of a window that is a stack here (rule T46): where HyperCard had
-- it (see _HCPlace); its globalLoc and globalRect, its place on the
-- screen. A window that is not open has no place
function hcWindowProperty pProp, pWindow
   local tWindow, tStack
   if pProp is "location" then put "loc" into pProp
   if pProp is "rectangle" then put "rect" into pProp
   put _HCOwnWindow(pWindow) into tWindow
   if tWindow is empty and there is a stack pWindow then
      put the long id of stack pWindow into tStack
      if pProp is "globalloc" then return the topLeft of tStack
      if pProp is "globalrect" then return the rect of tStack
      if pProp is among the items of kHCPlaces then
         if _HCCardRelative(tStack) then return _HCPlace(pProp, _HCStackPlace(pProp, tStack), true)
         return _HCStackPlace(pProp, tStack)
      end if
   end if
   if tWindow is empty then put pWindow into tWindow
   if sHCWindows[tWindow][pProp] is empty and pProp is "visible" then return false
   return sHCWindows[tWindow][pProp]
end hcWindowProperty

-- The place pProp (one of kHCPlaces) of a stack, its top left for loc
private function _HCStackPlace pProp, pStack
   switch pProp
      case "loc"
      case "topleft"
         return the topLeft of pStack
      case "rect"
         return the rect of pStack
      case "bottomright"
         return the bottomRight of pStack
      case "top"
         return the top of pStack
      case "left"
         return the left of pStack
      case "bottom"
         return the bottom of pStack
      case "right"
         return the right of pStack
   end switch
   return empty
end _HCStackPlace

private command _HCSetStackPlace pProp, pStack, pValue
   switch pProp
      case "loc"
      case "topleft"
         set the topLeft of pStack to pValue
         break
      case "rect"
         set the rect of pStack to pValue
         break
      case "bottomright"
         set the bottomRight of pStack to pValue
         break
      case "top"
         set the top of pStack to pValue
         break
      case "left"
         set the left of pStack to pValue
         break
      case "bottom"
         set the bottom of pStack to pValue
         break
      case "right"
         set the right of pStack to pValue
         break
   end switch
end _HCSetStackPlace

on hcSetWindow pProp, pWindow, pValue
   local tStack, tImage, i, tWindow
   -- (a point or a rect not in quotes comes as more than one parameter)
   repeat with i = 4 to paramCount()
      put comma & param(i) after pValue
   end repeat
   if pProp is "location" then put "loc" into pProp
   if pProp is "rectangle" then put "rect" into pProp
   if pWindow is "card window" then return empty
   put _HCOwnWindow(pWindow) into tWindow
   if tWindow is not empty then
      put pValue into sHCWindows[tWindow][pProp]
      return empty
   end if
   if there is not a stack pWindow then return "No such window"
   put the long id of stack pWindow into tStack
   -- (T46: a window's place, where HyperCard put it)
   if pProp is among the items of kHCPlaces then
      if _HCCardRelative(tStack) then put _HCPlace(pProp, pValue, false) into pValue
      _HCSetStackPlace pProp, tStack, pValue
      return empty
   end if
   if there is an image "Picture" of card 1 of tStack then
      put the long id of image "Picture" of card 1 of tStack into tImage
   end if
   switch pProp
      case "scale"
         if tImage is empty or pValue is not an integer then return empty
         put max(-5, min(5, pValue)) into pValue
         lock screen
         set the width of tImage to max(1, round(the formattedWidth of tImage * 2 ^ pValue))
         set the height of tImage to max(1, round(the formattedHeight of tImage * 2 ^ pValue))
         set the topLeft of tImage to 0,0
         unlock screen
         break
      case "scroll"
         if tImage is empty or item 1 of pValue is not a number or item 2 of pValue is not a number then return empty
         set the topLeft of tImage to -(item 1 of pValue), -(item 2 of pValue)
         break
      case "hilitedbutton"
         repeat with i = 1 to the number of buttons of card 1 of tStack
            set the hilite of button i of card 1 of tStack to (i = pValue)
         end repeat
         break
      case "globalloc"
         set the topLeft of tStack to pValue
         break
      case "globalrect"
         set the rect of tStack to pValue
         break
   end switch
   return empty
end hcSetWindow

/*
The properties of the message box (rule T28): "the visible of msg" and
"set the loc of the message box to ..." name the message box's text
here, and stop with an error. In the IDE they are those of its Message
Box; where there is none (the Stack Player), the values a script set
read back, and the message box is not visible. Its place is where
HyperCard had it, its location its top left from the card window's
(rule T46: see _HCPlace)
*/
local sHCMessageBox

function hcMessageBox pProp
   local tValue
   if pProp is "location" then put "loc" into pProp
   if pProp is "rectangle" then put "rect" into pProp
   if there is a stack "Message Box" then
      try
         if pProp is among the items of kHCPlaces then
            return _HCPlace(pProp, _HCStackPlace(pProp, the long id of stack "Message Box"), true)
         end if
         do "put the" && pProp && "of stack" && quote & "Message Box" & quote && "into tValue"
         return tValue
      catch tError
      end try
   end if
   if pProp is "visible" and sHCMessageBox["visible"] is empty then return false
   return sHCMessageBox[pProp]
end hcMessageBox

on hcSetMessageBox pProp, pValue
   local i
   -- (a point or a rect not in quotes comes as more than one parameter)
   repeat with i = 3 to paramCount()
      put comma & param(i) after pValue
   end repeat
   if pProp is "location" then put "loc" into pProp
   if pProp is "rectangle" then put "rect" into pProp
   put pValue into sHCMessageBox[pProp]
   if there is not a stack "Message Box" then return empty
   try
      if pProp is "visible" then
         if pValue is true then
            show message box
         else
            hide message box
         end if
      else if pProp is among the items of kHCPlaces then
         _HCSetStackPlace pProp, the long id of stack "Message Box", _HCPlace(pProp, pValue, false)
      else
         do "set the" && pProp && "of stack" && quote & "Message Box" & quote && "to pValue"
      end if
   catch tError
   end try
   return empty
end hcSetMessageBox

----------------------------------------------------------------------
-- Stand-ins for the externals stacks call most
--
-- An XCMD or XFCN is 68k code, which this engine cannot run; a call to
-- one that the stack carried comes here instead. These are the externals
-- the most stacks of a 2,186-stack corpus call from script, each written
-- from the way those stacks call it and from the externals' own
-- documentation, so the less common forms of a call may differ. The
-- dialogs and menus are this engine's; an external with no counterpart
-- here (a dialog builder, a resource copier) does nothing and says so in
-- the result, which is where an XCMD put its error.

local sHCMenuCount
local sHCBalloons
local sHCPopUp

-- FileName([type, ...] [, prompt]): the path of a file the user picks
-- (Standard File's open dialog), or empty if they cancel. File types
-- are four characters; anything longer is taken as the prompt
function FileName
   local tParams, i
   repeat with i = 1 to paramCount()
      put param(i) & return after tParams
   end repeat
   return _HCFileName(tParams)
end FileName

-- fileName(...) after the import (rule T20; this engine reads
-- "fileName(" as the property, here as in value()): FileName, above
function hcX_FileName
   local tParams, i
   repeat with i = 1 to paramCount()
      put param(i) & return after tParams
   end repeat
   return _HCFileName(tParams)
end hcX_FileName

private function _HCFileName pParams
   local tPrompt, tParam
   put "Choose a file:" into tPrompt
   repeat for each line tParam in pParams
      if the number of chars of tParam > 4 then put tParam into tPrompt
   end repeat
   answer file tPrompt
   if the result is "Cancel" then return empty
   return it
end _HCFileName

-- StandardFile(mode[, file types...][, default name]), the XFCN: the path
-- of a file the user picks, or empty if they cancel. A mode that begins
-- "put" is the save dialog (its default name the second parameter),
-- any other the open dialog; a prompt follows the mode after a colon
-- ("get:Open which stack?")
function StandardFile pMode, pDefault
   local tPrompt
   set the itemDelimiter to colon
   put item 2 to -1 of pMode into tPrompt
   if word 1 of item 1 of pMode is "put" then
      if tPrompt is empty then put "Save as:" into tPrompt
      ask file tPrompt with pDefault
   else
      if tPrompt is empty then put "Choose a file:" into tPrompt
      answer file tPrompt
   end if
   if the result is "Cancel" then return empty
   return it
end StandardFile

-- SelectFile([file types,] [prompt]), the XFCN: the path of a file the
-- user picks, or empty if they cancel
function SelectFile
   local tParams, i
   repeat with i = 1 to paramCount()
      put param(i) & return after tParams
   end repeat
   return _HCFileName(tParams)
end SelectFile

-- SelectDir([prompt]), the XFCN: the path of a folder the user picks, or
-- empty if they cancel
function SelectDir pPrompt
   if pPrompt is empty then put "Choose a folder:" into pPrompt
   answer folder pPrompt
   if the result is "Cancel" then return empty
   return it
end SelectDir

-- MultiFinder(), the XFCN: whether the Mac ran more than one application
-- at once, which every system here does
function MultiFinder
   return true
end MultiFinder

-- CapsLock(), the XFCN: whether the caps lock key is down
function CapsLock
   return the capsLockKey is down
end CapsLock

-- FileExists(path[, options]), the XFCN: whether there is such a file or
-- folder (a path here, not a Mac path with colons)
function FileExists pPath
   if pPath is empty then return false
   return there is a file pPath or there is a folder pPath
end FileExists

/*
Files([folder[, types[, what]]]) (6 stacks), Guy de Picciotto's XFCN: the
names of the files in a folder, one a line, with types (a list of file
types, "STAK,TEXT") only the files of those types. Called as hcX_Files:
this engine reads "files(" as its function (rule T13). The folder is an
HFS path ("Old Disk:Stacks"; ":Data", from the stack's folder; a name
alone, in it), or a path here; where it is empty or there is no such
folder, the "default directory": the stack's folder, which is on the
disk image it came from where it came from one, else the folder of its
file. The external's card ("Files 1.1") gives what as 1 files only,
the default, 2 files and folders and 3 folders only; but its own List
script asks with 0 for the files and 2 for the folders it goes into,
and the Star Trek guides ask with "STAK" and 3 for the stacks beside
them, which work only as 2 folders only and 3 files and folders, so
that is what they are here (a folder's name has no colon after it).
A file on a disk image has its type; a file here, the type in its
MacBinary header, else STAK for a HyperCard stack and TEXT for a .txt
file. Folders, then files, each in the order of the disk's catalog (by
name, here). Empty if there is no folder to list, as the external gave
on an error
*/
function hcX_Files pPath, pTypes, pWhat
   local tWhere, tList, tLine, tOut, tFolders, tFiles, tType, tName
   put _HCFilesFolder(pPath) into tWhere
   if tWhere is empty then return empty
   set the itemDelimiter to tab
   if item 1 of tWhere is "image" then
      try
         put revHyperCardImageFolder(item 2 of tWhere, item 3 of tWhere) into tList
      catch tError
         -- (the disk image library is the IDE's, and the Stack Player's)
         return empty
      end try
   else
      put _HCLocalFolder(item 2 of tWhere) into tList
   end if
   if pWhat is 2 then
      put true into tFolders
   else if pWhat is 3 then
      put true into tFolders
      put true into tFiles
   else
      put true into tFiles
   end if
   repeat for each line tLine in tList
      set the itemDelimiter to tab
      put item 1 of tLine into tName
      if item 2 of tLine is "folder" then
         if tFolders then put tName & return after tOut
         next repeat
      end if
      if not tFiles then next repeat
      put item 3 of tLine into tType
      if word 1 to -1 of pTypes is not empty then
         if not _HCTypeAmong(tType, pTypes) then next repeat
      end if
      put tName & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end hcX_Files

-- Whether the file type pType is one of the list pTypes, each four
-- characters, the case significant, as Mac file types were ("STAK,TXT"
-- names "TXT ")
private function _HCTypeAmong pType, pTypes
   local tEach
   set the caseSensitive to true
   set the itemDelimiter to comma
   repeat for each item tEach in pTypes
      put char 1 to 4 of (tEach & "    ") into tEach
      if tEach is pType then return true
   end repeat
   return false
end _HCTypeAmong

-- The folder an external of Files' kind lists: "image", a tab, the disk
-- image and a tab and the folder's HFS path on it; or "local" and a tab
-- and its path here; or empty if there is none (Files above)
private function _HCFilesFolder pPath
   local tSet, tImage, tHFS, tUp, tRelative, tFolder, tLocal, tAbsolute
   put the customProperties["uHyperCard"] of me into tSet
   if tSet["image"] is not empty and there is a file tSet["image"] and tSet["imagepath"] is not empty then
      put tSet["image"] into tImage
      set the itemDelimiter to colon
      put item 1 to -2 of tSet["imagepath"] into tHFS
   end if
   set the itemDelimiter to slash
   put item 1 to -2 of (the effective filename of me) into tLocal
   if tLocal is empty then put item 1 to -2 of tSet["file"] into tLocal
   put word 1 to -1 of pPath into pPath
   if pPath is not empty then
      if slash is in pPath or backslash is in pPath then
         if there is a folder pPath then
            return "local" & tab & pPath
         end if
      else
         -- from the stack's folder: ":Data", "::Stacks" (each colon more
         -- a folder up), or a name alone
         put 0 into tUp
         -- (from the disk: "Old Disk:Stacks", and "Old Disk:" a disk)
         put char 1 of pPath is not colon and colon is in pPath into tAbsolute
         if not tAbsolute then
            put pPath into tRelative
            if char 1 of tRelative is colon then delete char 1 of tRelative
            repeat while char 1 of tRelative is colon
               add 1 to tUp
               delete char 1 of tRelative
            end repeat
            if char -1 of tRelative is colon then
               delete char -1 of tRelative
            end if
         else if char -1 of pPath is colon then
            delete char -1 of pPath
         end if
         set the itemDelimiter to colon
         if tImage is not empty then
            if tAbsolute then
               put pPath into tFolder
            else
               put item 1 to -(tUp + 1) of tHFS into tFolder
               if tRelative is not empty then put colon & tRelative after tFolder
            end if
            if tFolder is not empty and _HCImageHasFolder(tImage, tFolder) then
               return "image" & tab & tImage & tab & tFolder
            end if
         end if
         if tLocal is not empty then
            if tAbsolute then
               -- "Users:me:Stacks", the path here with colons, as the
               -- long name of HyperCard gives one (hcHyperCardName)
               put pPath into tFolder
               replace colon with slash in tFolder
               -- (a drive's, "C::Users:me", is "C:/Users/me")
               if the platform is not "Win32" then
                  put slash before tFolder
               else if char 2 to 3 of pPath is "::" then
                  put char 1 of pPath & ":/" & char 4 to -1 of tFolder into tFolder
               end if
            else
               set the itemDelimiter to slash
               put item 1 to -(tUp + 1) of tLocal into tFolder
               if tRelative is not empty then
                  replace colon with slash in tRelative
                  put slash & tRelative after tFolder
               end if
            end if
            if there is a folder tFolder then return "local" & tab & tFolder
         end if
      end if
   end if
   if tImage is not empty and tHFS is not empty then return "image" & tab & tImage & tab & tHFS
   if tLocal is not empty and there is a folder tLocal then return "local" & tab & tLocal
   return empty
end _HCFilesFolder

-- Whether a disk image has the folder at the HFS path pFolder
private function _HCImageHasFolder pImage, pFolder
   try
      get revHyperCardImageFolder(pImage, pFolder)
   catch tError
      return false
   end try
   return the result is empty
end _HCImageHasFolder

-- A folder here, listed as revHyperCardImageFolder lists one on a disk
-- image: a line per folder, then per file, by name; a file's type the
-- one in its MacBinary header, else STAK for a HyperCard stack and TEXT
-- for a .txt file. What a Mac would not have shown is left out: names
-- that begin with a dot (the "._" copies of resource forks, "..") and a
-- resource fork copied out beside its file (".rsrc")
private function _HCLocalFolder pFolder
   local tList, tEach, tOut, tNames
   put folders(pFolder) into tNames
   sort lines of tNames
   repeat for each line tEach in tNames
      if char 1 of tEach is "." then next repeat
      put tEach & tab & "folder" & return after tOut
   end repeat
   put files(pFolder) into tNames
   sort lines of tNames
   repeat for each line tEach in tNames
      if char 1 of tEach is "." or tEach ends with ".rsrc" then next repeat
      put tEach & tab & "file" & tab & _HCLocalType(pFolder & slash & tEach) & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end _HCLocalFolder

-- A file's Mac type here (_HCLocalFolder): "????" where it has none
private function _HCLocalType pFile
   local tHeader
   open file pFile for binary read
   if the result is not empty then return "????"
   read from file pFile for 128
   put it into tHeader
   close file pFile
   if _HCIsMacBinary(tHeader) then return byte 66 to 69 of tHeader
   if byte 5 to 8 of tHeader is "STAK" then return "STAK"
   set the itemDelimiter to "."
   if the number of items of pFile > 1 and item -1 of pFile is among the items of "txt.text" then return "TEXT"
   return "????"
end _HCLocalType

-- Whether pHeader, a file's first 128 bytes, is a MacBinary header: a
-- zero byte, the length of the name (1 to 63), zero bytes at 74 and 82,
-- and forks no longer than a resource fork's offsets reach
private function _HCIsMacBinary pHeader
   local tData, tRsrc
   if the number of bytes of pHeader < 128 then return false
   -- (a stack's data fork begins with a zero byte too, then its STAK
   -- block's size and name)
   if byte 5 to 8 of pHeader is "STAK" then return false
   if byteToNum(byte 1 of pHeader) is not 0 or byteToNum(byte 75 of pHeader) is not 0 or byteToNum(byte 83 of pHeader) is not 0 then return false
   if byteToNum(byte 2 of pHeader) < 1 or byteToNum(byte 2 of pHeader) > 63 then return false
   get binaryDecode("NN", byte 84 to 91 of pHeader, tData, tRsrc)
   return tData < 2^31 and tRsrc < 2^24
end _HCIsMacBinary

/*
ResText(type, id or name[, ...]) (4 stacks), Frederic Rinaldi's XFCN:
the text of one of the stack's resources (SonnetFolio's sonnets, each a
TEXT resource "Sn 1" to "Sn 154"), as its card ("ResText 2.3")
describes it. The parameters after the first two can come in any order
(the order was <fileName>, <stripCtrl> before 2.0): "#n", the nth
string of an STR# resource; "hex", the bytes in hexadecimal; true or
false, whether to replace control characters with "[<code>]", which it
does unless told not to; "DontResolveAlias", which changes nothing
here; and any other, the file whose resource fork is read: a name alone
in the stack's folder, an HFS path, or a path here ("all", the whole
chain from the stack to the System file: the stack's own here). A name
is found as the Resource Manager found one, case aside. The text is
read as Mac text (MacRoman), its returns as returns; with false the
bytes are given as they are, each a character whose charToNum is the
byte (SeqSimPresenter's tables of numbers from 1 to 255). An STR#
resource gives its strings one a line, an STR its string and the bytes
after it on a second line. The stack's resource fork is the one it was
imported with: on the disk image it came from, else in its MacBinary
or AppleSingle file, or beside it as Name.rsrc, ._Name (AppleDouble)
or Name/..namedfork/rsrc (macOS). Errors are the external's, given as
its value: "Error : Resource not found", "Error : No resource fork"...
*/
function ResText pType, pResource
   local tStrip, tHex, tItem, tFile, tParam, tFork, tData, i, tCount, tAt, tOut, tLength
   put true into tStrip
   repeat with i = 3 to the paramCount
      put word 1 to -1 of param(i) into tParam
      if tParam is empty or tParam is "DontResolveAlias" then next repeat
      if tParam is "hex" then
         put true into tHex
      else if tParam is among the items of "true,false" then
         put tParam into tStrip
      else if char 1 of tParam is "#" then
         put char 2 to -1 of tParam into tItem
         if tItem is not an integer or tItem < 1 then
            return "Error : Incorrect STR# item number"
         end if
      else if tParam is not "all" then
         put tParam into tFile
      end if
   end repeat
   if pType is empty or pResource is empty then return "Error : Missing or empty parameter(s)"
   if the number of chars of pType > 4 then return "Error : Bad resource type"
   put char 1 to 4 of (pType & "    ") into pType
   put _HCResourceFork(tFile) into tFork
   if tFork begins with "Error :" then return tFork
   put _HCResource(tFork, pType, pResource) into tData
   if tData is false then return "Error : Resource not found"
   if tHex then return _HCHex(tData)
   if pType is "STR#" then
      if the number of bytes of tData < 2 then return empty
      put byteToNum(byte 1 of tData) * 256 + byteToNum(byte 2 of tData) into tCount
      if tItem is not empty and tItem > tCount then return "Error : Index is out of range"
      put 3 into tAt
      repeat with i = 1 to tCount
         if tAt > the number of bytes of tData then exit repeat
         put byteToNum(byte tAt of tData) into tLength
         if tItem is empty or tItem is i then
            put _HCResText(byte tAt + 1 to tAt + tLength of tData, tStrip) & return after tOut
         end if
         add tLength + 1 to tAt
      end repeat
      delete the last char of tOut
      return tOut
   end if
   if pType is "STR " then
      if the number of bytes of tData < 1 then return empty
      put byteToNum(byte 1 of tData) into tLength
      return _HCResText(byte 2 to tLength + 1 of tData, tStrip) & return & _HCResText(byte tLength + 2 to -1 of tData, tStrip)
   end if
   return _HCResText(tData, tStrip)
end ResText

-- Bytes in hexadecimal, two capital digits each (ResText's "hex")
private function _HCHex pData
   local tHex
   get binaryDecode("H*", pData, tHex)
   return toUpper(tHex)
end _HCHex

-- A resource's bytes as ResText gives them: Mac text with its returns as
-- returns, the other characters before space but tab as "[<code>]"
-- with pStrip; else the bytes as they are
private function _HCResText pData, pStrip
   local tText, tOut, tChar, tCode
   if pStrip is false then return pData
   put _HCFromMacRoman(pData) into tText
   replace numToCodepoint(13) & numToCodepoint(10) with return in tText
   replace numToCodepoint(13) with return in tText
   repeat for each char tChar in tText
      put codepointToNum(tChar) into tCode
      if tCode < 32 and tChar is not return and tChar is not tab then
         put "[" & tCode & "]" after tOut
      else
         put tChar after tOut
      end if
   end repeat
   return tOut
end _HCResText

-- Mac text (MacRoman bytes) as text here (this engine has no MacRoman
-- for textDecode)
private function _HCFromMacRoman pData
   local tText, tByte, tCode
   repeat for each byte tByte in pData
      put byteToNum(tByte) into tCode
      if tCode < 128 then
         put numToCodepoint(tCode) after tText
      else
         put numToCodepoint(word tCode - 127 of kHCMacRoman) after tText
      end if
   end repeat
   return tText
end _HCFromMacRoman

-- The data of the resource of type pType and id or name pResource in the
-- resource fork pFork, or false. A fork's numbers are big-endian: its
-- header gives where its data and map begin; the map, where its type
-- list and name list begin (at 24 and 26); the type list, a count less
-- one, then per type its four characters, its count less one and where
-- its references begin, from the type list; a reference (12 bytes), the
-- id, where its name is in the name list (-1 for none), and the
-- resource's place in the data (3 bytes after a byte of attributes),
-- where its length (4 bytes) comes before it. Inside Macintosh: More
-- Macintosh Toolbox (1993), "Resource Manager", "Resource File Format"
private function _HCResource pFork, pType, pResource
   local tData, tMap, tTypes, tNames, tCount, i, j, tAt, tRefs, tRef, tN, tID, tName, tNameAt, tOffset, tLength
   if the number of bytes of pFork < 16 then return false
   get binaryDecode("NN", byte 1 to 8 of pFork, tData, tMap)
   if tMap + 30 > the number of bytes of pFork then return false
   get binaryDecode("nn", byte tMap + 25 to tMap + 28 of pFork, tTypes, tNames)
   add tMap to tTypes
   add tMap to tNames
   get binaryDecode("n", byte tTypes + 1 to tTypes + 2 of pFork, tCount)
   if tCount is 65535 then return false
   set the caseSensitive to true
   repeat with i = 0 to tCount
      put tTypes + 2 + i * 8 into tAt
      if byte tAt + 1 to tAt + 4 of pFork is not pType then next repeat
      get binaryDecode("nn", byte tAt + 5 to tAt + 8 of pFork, tN, tRefs)
      set the caseSensitive to false
      repeat with j = 0 to tN
         put tTypes + tRefs + j * 12 into tRef
         get binaryDecode("nn", byte tRef + 1 to tRef + 4 of pFork, tID, tNameAt)
         if tID > 32767 then subtract 65536 from tID
         if pResource is an integer then
            if tID is not pResource then
               next repeat
            end if
         else
            if tNameAt is 65535 then next repeat
            put byte tNames + tNameAt + 2 to tNames + tNameAt + 1 + byteToNum(byte tNames + tNameAt + 1 of pFork) of pFork into tName
            if _HCFromMacRoman(tName) is not pResource then next repeat
         end if
         put byteToNum(byte tRef + 6 of pFork) * 65536 + byteToNum(byte tRef + 7 of pFork) * 256 + byteToNum(byte tRef + 8 of pFork) into tOffset
         add tData to tOffset
         get binaryDecode("N", byte tOffset + 1 to tOffset + 4 of pFork, tLength)
         return byte tOffset + 5 to tOffset + 4 + tLength of pFork
      end repeat
      return false
   end repeat
   return false
end _HCResource

-- The resource fork ResText reads: the stack's (pFile empty), or that of
-- the file pFile, a name alone in the stack's folder, an HFS path or a
-- path here; else the external's error. The last one read is kept, as
-- a script reads many resources of one fork (SonnetFolio, its sonnets)
local sHCForkSource, sHCFork

private function _HCResourceFork pFile
   local tSet, tSource, tFork, tFolder, tWhere
   put the customProperties["uHyperCard"] of me into tSet
   if pFile is empty then
      if tSet["image"] is not empty and tSet["imagepath"] is not empty then
         put "image" & tab & tSet["image"] & tab & tSet["imagepath"] into tSource
      else if tSet["file"] is not empty then
         put "local" & tab & tSet["file"] into tSource
      else if the effective filename of me is not empty then
         put "local" & tab & the effective filename of me into tSource
      else
         return "Error : No resource fork"
      end if
   else if slash is in pFile or backslash is in pFile then
      put "local" & tab & pFile into tSource
   else
      -- the folder Files lists for it, and the file's name in it
      set the itemDelimiter to colon
      if colon is in pFile then
         put _HCFilesFolder(item 1 to -2 of pFile & colon) into tWhere
      else
         put _HCFilesFolder(empty) into tWhere
      end if
      put the last item of pFile into pFile
      set the itemDelimiter to tab
      if item 1 of tWhere is "image" then
         put "image" & tab & item 2 of tWhere & tab & item 3 of tWhere & colon & pFile into tSource
      else if item 1 of tWhere is "local" then
         put "local" & tab & item 2 of tWhere & slash & pFile into tSource
      else
         return "Error : File not found"
      end if
   end if
   if tSource is sHCForkSource then return sHCFork
   set the itemDelimiter to tab
   if item 1 of tSource is "image" then
      try
         put revHyperCardImageReadFork(item 2 of tSource, item 3 of tSource, "resource") into tFork
      catch tError
         return "Error : File not found"
      end try
      if the result is not empty then
         return "Error : File not found"
      end if
   else
      if there is not a file item 2 of tSource then return "Error : File not found"
      put _HCLocalFork(item 2 of tSource) into tFork
   end if
   if tFork is empty then return "Error : No resource fork"
   put tSource into sHCForkSource
   put tFork into sHCFork
   return tFork
end _HCResourceFork

-- The resource fork of the file pFile here, where it was kept (the
-- import reads the same places: MCHcstak::readresourcefile), or empty
private function _HCLocalFork pFile
   local tData, tFolder, tName, tLength, tFork, tEach
   put url ("binfile:" & pFile) into tData
   if _HCIsMacBinary(byte 1 to 128 of tData) then
      get binaryDecode("NN", byte 84 to 91 of tData, tLength, tFork)
      if tFork is 0 then return empty
      return byte 129 + ((tLength + 127) div 128) * 128 to 128 + ((tLength + 127) div 128) * 128 + tFork of tData
   end if
   put _HCAppleFork(tData) into tFork
   if tFork is not empty then return tFork
   set the itemDelimiter to slash
   put item 1 to -2 of pFile into tFolder
   put item -1 of pFile into tName
   set the itemDelimiter to comma
   repeat for each item tEach in "rsrc,._,namedfork"
      switch tEach
         case "rsrc"
            put url ("binfile:" & pFile & ".rsrc") into tData
            break
         case "._"
            put url ("binfile:" & tFolder & slash & "._" & tName) into tData
            break
         case "namedfork"
            if the platform is not "MacOS" then next repeat
            put url ("binfile:" & pFile & "/..namedfork/rsrc") into tData
            break
      end switch
      if tData is empty then next repeat
      put _HCAppleFork(tData) into tFork
      if tFork is empty then put tData into tFork
      if _HCIsFork(tFork) then return tFork
   end repeat
   return empty
end _HCLocalFork

-- Whether pData can be a resource fork: its header's data and map within
-- it, the map long enough for its type and name lists' offsets
private function _HCIsFork pData
   local tData, tMap, tDataLength, tMapLength
   if the number of bytes of pData < 16 then return false
   get binaryDecode("NNNN", byte 1 to 16 of pData, tData, tMap, tDataLength, tMapLength)
   return tMapLength >= 30 and tData + tDataLength <= the number of bytes of pData and tMap + tMapLength <= the number of bytes of pData
end _HCIsFork

-- The resource fork (entry 2) of an AppleSingle (magic 0x00051600) or
-- AppleDouble (0x00051607) file: after the magic and the version, 16
-- bytes, then the count of entries, each an id, an offset and a
-- length; else empty
private function _HCAppleFork pData
   local tMagic, tCount, i, tID, tOffset, tLength
   if the number of bytes of pData < 26 then return empty
   get binaryDecode("N", byte 1 to 4 of pData, tMagic)
   if tMagic is not 333312 and tMagic is not 333319 then return empty
   get binaryDecode("n", byte 25 to 26 of pData, tCount)
   repeat with i = 0 to tCount - 1
      get binaryDecode("NNN", byte 27 + i * 12 to 38 + i * 12 of pData, tID, tOffset, tLength)
      if tID is 2 then return byte tOffset + 1 to tOffset + tLength of pData
   end repeat
   return empty
end _HCAppleFork

/*
SystemPath("noDialog:" & errorGlobal) (4 stacks), the XFCN of Apple's
Support Tools Development Group (Eric Carlson, 1990): the path of the
System Folder, a Mac path with a colon at its end, on the disk that the
long name of HyperCard names (hcHyperCardName), as SysEnvirons puts
the systemFolder. BGC's stacks add "Extensions:QuickTime" and a trademark sign to it, and
find no QuickTime there, which is so: its XCMDs are not here
*/
function SystemPath
   set the itemDelimiter to colon
   return item 1 of hcHyperCardName("long") & ":System Folder:"
end SystemPath

/*
FindFolder([folder[, create]]) (3 stacks), Frederic Rinaldi's XFCN: the
path of the System Folder, or of one of the folders the System kept
(its card, "FindFolder 1.3"), on the disk SystemPath names, a colon at
its end: a letter (A Apple Menu Items, C Control Panels, D the desktop,
E Extensions, F Fonts, I Startup Items, M PrintMonitor Documents, N and
T the Trash, P Preferences, S the System Folder, the default, U
Shutdown Items, Y Temporary Items), or its type ("amnu", "ctrl",
"desk", "extn", "font", "strt", "prnt", "empt", "trsh", "pref",
"macs", "shdf", "temp", and "apps", "docs" and "root" at the top of the
disk); anything longer, by its first letter ("system folder"). Nothing
is made: the folders are named, as a Mac had them. Another gives
"Error : Folder not found"
*/
function FindFolder pFolder
   local tDisk, tTypes, tNames
   set the itemDelimiter to colon
   put item 1 of hcHyperCardName("long") into tDisk
   set the itemDelimiter to comma
   put word 1 to -1 of pFolder into pFolder
   if pFolder is empty then put "S" into pFolder
   if the number of chars of pFolder is not 4 then put char 1 of pFolder into pFolder
   put "A,C,D,E,F,I,M,N,P,S,T,U,Y" into tTypes
   if the number of chars of pFolder is 1 and pFolder is among the items of tTypes then
      put item itemOffset(pFolder, tTypes) of "amnu,ctrl,desk,extn,font,strt,prnt,empt,pref,macs,trsh,shdf,temp" into pFolder
   end if
   switch pFolder
      case "macs"
         return tDisk & ":System Folder:"
      case "desk"
         return tDisk & ":Desktop Folder:"
      case "trsh"
      case "empt"
         return tDisk & ":Trash:"
      case "temp"
         return tDisk & ":Temporary Items:"
      case "apps"
         return tDisk & ":Applications:"
      case "docs"
         return tDisk & ":Documents:"
      case "root"
         return tDisk & ":"
   end switch
   put "amnu,ctrl,extn,font,strt,prnt,pref,shdf" into tTypes
   put "Apple Menu Items,Control Panels,Extensions,Fonts,Startup Items,PrintMonitor Documents,Preferences,Shutdown Items" into tNames
   if pFolder is among the items of tTypes then
      return tDisk & ":System Folder:" & item itemOffset(pFolder, tTypes) of tNames & ":"
   end if
   return "Error : Folder not found"
end FindFolder

-- inKey(), the XFCN: the character of a key being held down, or empty if
-- none, which scripts read in a loop ("if inKey() is space then exit
-- repeat")
function inKey
   local tKey
   repeat for each item tKey in the keysDown
      if tKey is an integer and tKey >= 32 and tKey < 127 then return numToChar(tKey)
      if tKey is 65293 then return return
   end repeat
   return empty
end inKey

-- HyperCard's own messages, sent by a script to an object with no handler
-- for them ("send mouseUp to bg btn 3", "send tabKey to this card", "send
-- startUp to stack "Home"" when Home is the stand-in, hcHome): HyperCard
-- took them at the end of the path; this engine stops with "can't find
-- handler". Here they end, as they did, and go on to the engine as they
-- would
on mouseUp
   pass mouseUp
end mouseUp

on mouseDown
   pass mouseDown
end mouseDown

on openCard
   pass openCard
end openCard

on closeCard
   pass closeCard
end closeCard

on openBackground
   pass openBackground
end openBackground

on closeBackground
   pass closeBackground
end closeBackground

on openStack
   pass openStack
end openStack

on closeStack
   pass closeStack
end closeStack

on tabKey
   pass tabKey
end tabKey

on returnKey
   pass returnKey
end returnKey

on enterKey
   pass enterKey
end enterKey

on startUp
   pass startUp
end startUp

-- The rest of the messages that rule T35 sends when a script calls one
-- alone, as a command ("idle" in Script Printer's and Script Manager's
-- handlers, "resume", "resumeStack", "newCard"), or that a script sends
-- itself ("send "idle" to me", QTPlay): the same. A handler here does not
-- make this engine send any of them more often: it sends idle,
-- mouseWithin and mouseStillDown to an object only for a handler of its
-- own script or of its own behavior, and this library is the stack's
-- behavior
on idle
   pass idle
end idle

on resume
   pass resume
end resume

on suspend
   pass suspend
end suspend

on resumeStack
   pass resumeStack
end resumeStack

on suspendStack
   pass suspendStack
end suspendStack

on openField
   pass openField
end openField

on closeField
   pass closeField
end closeField

on exitField
   pass exitField
end exitField

on mouseStillDown
   pass mouseStillDown
end mouseStillDown

on mouseEnter
   pass mouseEnter
end mouseEnter

on mouseLeave
   pass mouseLeave
end mouseLeave

on mouseWithin
   pass mouseWithin
end mouseWithin

on newCard
   pass newCard
end newCard

on newBackground
   pass newBackground
end newBackground

on newStack
   pass newStack
end newStack

-- splashDialog id, seconds, ...: a splash screen while the stack starts,
-- from a resource that is not imported; nothing is shown
on splashDialog
   return empty
end splashDialog

-- NewFileName(prompt, default name): the path the user gives a new file
-- (Standard File's save dialog), or empty if they cancel
function NewFileName pPrompt, pDefault
   if pPrompt is empty then put "Save as:" into pPrompt
   ask file pPrompt with pDefault
   if the result is "Cancel" then return empty
   return it
end NewFileName

-- PutFile(prompt, default name): the same save dialog
function PutFile pPrompt, pDefault
   return NewFileName(pPrompt, pDefault)
end PutFile

-- PopUpMenu(items, checked item, top, left): a popup menu of the items
-- (separated by semicolons, else by returns, else by commas) with its top
-- left at left,top; the number of the item chosen, 0 if none
function PopUpMenu pItems, pChecked, pTop, pLeft
   local tItems, tChosen
   put hcPopUpItems(pItems) into tItems
   put _HCPopUp(_HCMenuText(tItems, pChecked), pTop, pLeft) into tChosen
   if tChosen is empty then return 0
   return _HCLineOf(tChosen, tItems)
end PopUpMenu

-- HPopUpMenu(menus, checked item, top, left): a popup menu with one
-- line per entry, and on a line with commas the first item the entry and
-- the rest its submenu; "line,item" of the choice (item 0 for an entry
-- with no submenu), 0 if none
function HPopUpMenu pMenus, pChecked, pTop, pLeft
   local tText, tLine, tChosen, i
   repeat for each line tLine in pMenus
      put item 1 of tLine & return after tText
      repeat with i = 2 to the number of items of tLine
         put tab & item i of tLine & return after tText
      end repeat
   end repeat
   delete the last char of tText
   put _HCPopUp(tText, pTop, pLeft) into tChosen
   if tChosen is empty then return 0
   return hcHPopUpChoice(pMenus, tChosen)
end HPopUpMenu

-- "line,item" of an HPopUpMenu choice, as the popup gives it ("entry" or
-- "entry|subitem"), 0 if it is not one of pMenus
function hcHPopUpChoice pMenus, pChosen
   local tItem, tLineNumber, tItemNumber, i
   set the itemDelimiter to "|"
   put item 1 of pChosen into tItem
   put item 2 of pChosen into pChosen
   set the itemDelimiter to comma
   repeat with i = 1 to the number of lines of pMenus
      if item 1 of line i of pMenus is tItem then
         put i into tLineNumber
         exit repeat
      end if
   end repeat
   if tLineNumber is empty then return 0
   put 0 into tItemNumber
   if pChosen is not empty then
      repeat with i = 2 to the number of items of line tLineNumber of pMenus
         if item i of line tLineNumber of pMenus is pChosen then
            put i - 1 into tItemNumber
            exit repeat
         end if
      end repeat
   end if
   return tLineNumber & comma & tItemNumber
end hcHPopUpChoice

-- The items of a PopUpMenu list, one per line
function hcPopUpItems pItems
   if ";" is in pItems then
      replace ";" with return in pItems
   else if return is not in pItems then
      replace comma with return in pItems
   end if
   return pItems
end hcPopUpItems

-- XScrollBox(mode, prompt, list): the user picks a line of the list;
-- "line number,line" of it, empty if they cancel
function XScrollBox pMode, pPrompt, pList
   local tLine
   put hcChooseLine(pPrompt, pList) into tLine
   if tLine is empty then return empty
   return tLine & comma & line tLine of pList
end XScrollBox

-- ShowList(list, prompt, ...): the user picks a line of the list; the
-- button ("OK" or "Cancel") on line 1 and the line picked on line 2.
-- When the second argument is a delimiter, the prompt is the third
function ShowList pList, pPrompt
   local tLine
   if pPrompt is among the items of (return & comma & ";,") or pPrompt is tab then put param(3) into pPrompt
   put hcChooseLine(pPrompt, pList) into tLine
   if tLine is empty then return "Cancel"
   return "OK" & return & line tLine of pList
end ShowList

-- DoList button, button, list, one: the user picks a line of the list;
-- the result is "button,line" ("Cancel," if they cancel). DoList 999,
-- list, ... takes the list second
on DoList pButton, pCancel, pList
   local tLine
   if pButton is a number then
      put pCancel into pList
      put "OK" into pButton
      put "Cancel" into pCancel
   end if
   put hcChooseLine(empty, pList) into tLine
   if tLine is empty then return pCancel & comma
   return pButton & comma & line tLine of pList
end DoList

-- PrintField "field description": prints the field's text
on PrintField pField
   local tField
   try
      put the long id of pField into tField
   catch tError
      try
         put value("the long id of" && pField) into tField
      catch tError
         return "Can't find" && pField
      end try
   end try
   try
      revPrintField tField
   catch tError
      return "Printing is not available"
   end try
   return empty
end PrintField

-- Speak text / Talk text, rate, pitch: speech, where this engine has it
on Speak pText
   return _HCSpeak(pText)
end Speak

on Talk pText
   return _HCSpeak(pText)
end Talk

-- SpeakString text and Say text, the speech XCMDs stacks carried (The
-- Haunted House speaks with SpeakString): the same
on SpeakString pText
   return _HCSpeak(pText)
end SpeakString

on Say pText
   return _HCSpeak(pText)
end Say

-- HCBalloon text: a balloon for the object the message came to, here its
-- tooltip. HCBalloon "on", "off" and "query" turn balloons on and off and
-- give back whether they are on
on HCBalloon pText
   if sHCBalloons is empty then put true into sHCBalloons
   switch pText
      case "on"
         put true into sHCBalloons
         return empty
      case "off"
         put false into sHCBalloons
         return empty
      case "query"
         return sHCBalloons
   end switch
   if sHCBalloons then set the toolTip of the target to pText
   return empty
end HCBalloon

/*
FullBalloons action [, content [, tipLoc] [, hotRect] [, tipPosition]]
(17 stacks), Frederic Rinaldi's XCMD: Balloon Help, which is on or off
for HCBalloon and FullBalloons alike, a tooltip here as for HCBalloon.
"On" and "Off" turn it on and off; "isOn" leaves whether it is on in the
result, and "isShowing" whether the mouse is in the object of the last
balloon shown (stacks ask it as the mouse moves, and send mouseEnter to
the object again when it is not). "showDirect" shows the text given and
"showField" the text of the field named ("cd fld 1"), as the tooltip of
the object the message came to; "remove" takes the last one away, and
"Off" every one shown. A tooltip shows at the mouse and goes when the
mouse leaves its object, so the tip's place and the hot rectangle are
not needed. The PICT, STR and TEXT resources of "showPICT", "showSTR",
"showSTR#" and "showTEXT" are not imported: "Error : Resource not found"
*/
local sHCBalloonShown, sHCBalloonLast, sHCBalloonCard

on FullBalloons pAction, pContent
   local tText, tObject, tError
   if sHCBalloons is empty then put true into sHCBalloons
   put word 1 to -1 of pAction into pAction
   switch pAction
      case "on"
         put true into sHCBalloons
         return empty
      case "off"
         put false into sHCBalloons
         _HCRemoveBalloons
         return empty
      case "isOn"
         return sHCBalloons
      case "isShowing"
         return _HCBalloonShowing()
      case "remove"
         _HCRemoveBalloon sHCBalloonLast
         put empty into sHCBalloonLast
         return empty
      case "!"
         return "FullBalloons 1.1 by Frederic Rinaldi"
      case "?"
         return "FullBalloons <action>[,<balloon content>[,<tipLoc>][,<hotRect>][,<tipPosition>]]"
      case "showDirect"
         if pContent is empty then return "Error : Missing balloon content parameter"
         put pContent into tText
         break
      case "showField"
         if pContent is empty then return "Error : Missing balloon content parameter"
         try
            do "put the text of" && pContent && "into tText"
         catch tError
            return "Error : Bad field descriptor"
         end try
         break
      case "showPICT"
      case "showSTR"
      case "showSTR#"
      case "showTEXT"
         return "Error : Resource not found"
      default
         if pAction is empty then return "Error : Missing or empty parameter"
         return "Error : Bad action parameter"
   end switch
   if not sHCBalloons then return empty
   put the long id of the target into tObject
   try
      set the toolTip of tObject to tText
   catch tError
      -- (a card or a stack has no tooltip)
      return empty
   end try
   put tObject into sHCBalloonLast
   put the long id of this card into sHCBalloonCard
   put true into sHCBalloonShown[tObject]
   return empty
end FullBalloons

-- Whether the mouse is in the object of the last balloon shown, on the
-- card it was shown on
private function _HCBalloonShowing
   if sHCBalloons is not true or sHCBalloonLast is empty then return false
   try
      if not exists(sHCBalloonLast) or the toolTip of sHCBalloonLast is empty then return false
      if the long id of this card is not sHCBalloonCard then return false
      return the mouseLoc is within the rect of sHCBalloonLast
   catch tError
      return false
   end try
end _HCBalloonShowing

private command _HCRemoveBalloon pObject
   try
      if pObject is not empty and exists(pObject) then set the toolTip of pObject to empty
   catch tError
   end try
   delete variable sHCBalloonShown[pObject]
end _HCRemoveBalloon

private command _HCRemoveBalloons
   local tObject
   repeat for each key tObject in sHCBalloonShown
      _HCRemoveBalloon tObject
   end repeat
   put empty into sHCBalloonLast
end _HCRemoveBalloons

-- ColorizeHC: colour drawn over the card, which this engine does with
-- its own colours (the importer keeps AddColor's as a colour layer)
on ColorizeHC
   return empty
end ColorizeHC

-- cHCcolorize and cHCunColorize: the handlers of "Colorizing HyperCard",
-- which a stack that used it called from a shared stack of its own; the
-- colours are the importer's colour layer here, so nothing to do (a stack
-- with these handlers in its own script still runs its own)
on cHCcolorize
   return empty
end cHCcolorize

on cHCunColorize
   return empty
end cHCunColorize

-- volume(level) and SndVolume(level), the XFCNs: the sound volume, 0 to
-- 7, as the Mac's control panel had it. The level is kept, so a script
-- that saves the old level and puts it back sees what it set; the
-- engine's own volume is left alone
local sHCVolume

function volume pLevel
   return _HCVolume(pLevel)
end volume

function SndVolume pLevel
   return _HCVolume(pLevel)
end SndVolume

private function _HCVolume pLevel
   local tOld
   if sHCVolume is empty then put 7 into sHCVolume
   put sHCVolume into tOld
   if pLevel is an integer and pLevel >= 0 and pLevel <= 7 then put pLevel into sHCVolume
   return tOld
end _HCVolume

-- objectExists(description), the XFCN: whether there is such an object
-- ("bg button " & quote & "Next" & quote)
function objectExists pObject
   local tExists
   try
      do "put there is a" && pObject && "into tExists"
   catch tError
      return false
   end try
   return tExists is true
end objectExists

-- MaxDepth(): the deepest colour of the screens
function MaxDepth
   return the screenDepth
end MaxDepth

-- Promptoid message: a small window with the message, which scripts
-- close as the window "Promptoid"
on Promptoid pMessage
   local tDefault
   put the defaultStack into tDefault
   if there is a stack "Promptoid" and the uHyperCard["promptoid"] of stack "Promptoid" is not true then
      -- the stack's own window of that name: left alone
      return "There is already a window called Promptoid"
   end if
   if there is not a stack "Promptoid" then
      get _HCNewHiddenStack("Promptoid")
      set the uHyperCard["promptoid"] of it to true
      set the width of it to 320
      set the height of it to 60
      set the defaultStack to "Promptoid"
      create field "Message"
      set the rect of it to 10,10,310,50
      set the lockText of it to true
      set the defaultStack to tDefault
      _HCReadyToShow the long id of stack "Promptoid"
      -- (closed, the window is gone)
      set the destroyStack of stack "Promptoid" to true
   end if
   put pMessage into field "Message" of stack "Promptoid"
   -- (shown again, if a script hid it)
   set the visible of stack "Promptoid" to true
   palette stack "Promptoid"
   set the defaultStack to tDefault
   return empty
end Promptoid

-- NewMenu(title, items...), DeleteMenu(menu), ShowMenu menu: menus added
-- to HyperCard's menu bar, which this engine's menus do not take yet.
-- NewMenu gives back a number for DeleteMenu, as the external did
function NewMenu
   add 1 to sHCMenuCount
   return sHCMenuCount
end NewMenu

function DeleteMenu pMenu
   return empty
end DeleteMenu

on DeleteMenu pMenu
   return "HyperCard menus are not supported yet"
end DeleteMenu

on ShowMenu pMenu
   return "HyperCard menus are not supported yet"
end ShowMenu

function ShowMenu pMenu
   return empty
end ShowMenu

/*
About [first item [, second item]] (21 stacks), Jay Hodgdon's XCMD: the
first item of the Apple menu ("About HyperCard...") and a second below
it, which a stack names for itself as it opens and, with no parameters,
puts back as it closes. This engine's menus do not take them yet (as
NewMenu), so it does nothing. Two stacks call an external of the same
name with more parameters, which Hodgdon's refuses, to show the texts in
a dialog: Logo 2.1.1's help (the name of a DLOG resource, a title and
the text) and AnimationStack's credits, a line each. The resource is not
imported, so an answer dialog shows the texts
*/
on About
   local tText, i
   if the paramCount <= 2 then return empty
   repeat with i = 1 to the paramCount
      if i is 1 and param(1) ends with "DLOG" then next repeat
      if tText is not empty then put return after tText
      put param(i) after tText
   end repeat
   if tText is not empty then answer tText
   return empty
end About

-- Externals with nothing like them here: they do nothing, and say so
on Dialoger
   return "The Dialoger external is not supported"
end Dialoger

function Dialoger
   return empty
end Dialoger

on ShowDialog
   return "The ShowDialog external is not supported"
end ShowDialog

on ResCopy
   return "ResCopy is not supported: resources are not copied"
end ResCopy

function Search
   return empty
end Search

-- popUp (called hcX_popUp after the import, since popup is a command
-- here): the Home stack's popup cards, which are not imported
on hcX_popUp
   return "popUp is not supported"
end hcX_popUp

-- The externals stacks call most for text and lists, and their dialogs:
-- each does what its documentation says it did (the number of stacks of
-- the corpus that call it is given). A call of one whose name this engine
-- reads as one of its commands ("replace(", "sort(", "find(") is renamed
-- hcX_<name> by the import (rule T47)

-- LowerToUpper(text) (72 stacks): the text in capitals
function LowerToUpper pText
   return toUpper(pText)
end LowerToUpper

-- ChangeCase(text, form[, sentence endings]) (5 stacks): Steve Maller's
-- XFCN, the form a number (1 capitals, 2 lower case, 3 a capital at the
-- start of each sentence, 4 at the start of each word), or Ben Lawson's,
-- the form a word whose first letter is enough (upper, lower, sentence,
-- title, flip or reverse, random; upper when it is left out). Only the
-- letters A to Z change, as in both
function ChangeCase pText, pForm, pEndings
   local tForm
   if pText is "?" then return "ChangeCase(Container,<Case>,<SentenceEndings>)"
   if pText is "!" then return "ChangeCase XFCN"
   put _HCCaseForm(pForm) into tForm
   if tForm is empty then return "Error: conversion form specified in param 2 not recognized."
   return _HCChangeCase(pText, tForm, pEndings)
end ChangeCase

private function _HCCaseForm pForm
   put word 1 to -1 of pForm into pForm
   switch
      case pForm is empty or pForm is "1"
         return "upper"
      case pForm is "2"
         return "lower"
      case pForm is "3"
         return "sentence"
      case pForm is "4"
         return "title"
      case pForm is "reverse"
         return "flip"
   end switch
   switch char 1 of pForm
      case "u"
         return "upper"
      case "l"
         return "lower"
      case "s"
         return "sentence"
      case "t"
         return "title"
      case "f"
         return "flip"
      case "r"
         return "random"
   end switch
   return empty
end _HCCaseForm

-- pText with its letters A to Z in the form pForm (_HCCaseForm). A word
-- starts after anything but a letter or an apostrophe; a sentence at the
-- start of the text, after a return, and after one of pEndings (by
-- default . ! and ?) that white space follows
private function _HCChangeCase pText, pForm, pEndings
   local tOut, tChar, tNum, tStart, tEnded
   if pEndings is empty then put ".!?" into pEndings
   put true into tStart
   put false into tEnded
   repeat for each char tChar in pText
      put charToNum(tChar) into tNum
      if (tNum >= 65 and tNum <= 90) or (tNum >= 97 and tNum <= 122) then
         switch pForm
            case "upper"
               put toUpper(tChar) after tOut
               break
            case "lower"
               put toLower(tChar) after tOut
               break
            case "flip"
               if tNum <= 90 then
                  put toLower(tChar) after tOut
               else
                  put toUpper(tChar) after tOut
               end if
               break
            case "random"
               if random(2) = 1 then
                  put toUpper(tChar) after tOut
               else
                  put toLower(tChar) after tOut
               end if
               break
            default
               if tStart then
                  put toUpper(tChar) after tOut
               else
                  put toLower(tChar) after tOut
               end if
         end switch
         put false into tStart
         put false into tEnded
         next repeat
      end if
      put tChar after tOut
      if pForm is "title" then
         put tChar is not "'" into tStart
      else if pForm is "sentence" then
         if tChar is return or (tEnded and (tChar is space or tChar is tab)) then
            put true into tStart
         else if tChar is among the chars of pEndings then
            put true into tEnded
         else if tChar is not space and tChar is not tab then
            put false into tEnded
         end if
      end if
   end repeat
   return tOut
end _HCChangeCase

-- Quoted(text) (3 stacks): the text in quotes
function Quoted pText
   return quote & pText & quote
end Quoted

-- Strip(characters, text) (4 stacks): the text without any of the
-- characters, a capital and a small letter being two ("1234567890."
-- leaves what is not a number)
function Strip pChars, pText
   local tChar
   set the caseSensitive to true
   repeat for each char tChar in pChars
      replace tChar with empty in pText
   end repeat
   return pText
end Strip

/*
Replace(...) (10 stacks; called hcX_Replace after the import, rule T47),
the XFCNs of that name, which take their arguments in one of two orders:
(old, new, text) in most stacks (Jon's XFCNs, Debate Coach, DataMinder,
the DNA Translator, Import/Export Tools), the old string replaced with
case counting; and (text, old, new[, case counts]), Dartmouth's, case
not counting unless the fourth is true. With four, the order is
Dartmouth's; with three, see hcReplaceTextFirst
*/
function hcX_Replace p1, p2, p3, p4
   local tText, tOld, tNew
   if paramCount() < 3 then return empty
   if paramCount() > 3 or hcReplaceTextFirst(p1, p2, p3) then
      put p1 into tText
      put p2 into tOld
      put p3 into tNew
      set the caseSensitive to (p4 is true)
   else
      put p3 into tText
      put p1 into tOld
      put p2 into tNew
      set the caseSensitive to true
   end if
   if tOld is empty then return tText
   replace tOld with tNew in tText
   return tText
end hcX_Replace

-- Whether a Replace with three arguments takes the text first: the text
-- is the one the old string is in (the first is in the last: the text is
-- last), or, when neither is, the longer of the first and the last; and
-- an empty string is never the one replaced
function hcReplaceTextFirst p1, p2, p3
   set the caseSensitive to true
   if p1 is not empty and p1 is in p3 then return false
   if p2 is empty then return false
   if p1 is empty then return true
   return the number of chars of p1 > the number of chars of p3
end hcReplaceTextFirst

-- FullReplace(text, string[, replacement[, all[, start]]]) (13 stacks),
-- Frederic Rinaldi's XFCN: the text with the string replaced (left out
-- when there is no replacement), case not counting; every one unless all
-- is false, from the character start on (1 when it is left out)
function FullReplace pText, pSearch, pReplace, pAll, pStart
   local tDone, tAt, tOut, tLength
   if paramCount() = 1 and pText is "?" then return "FullReplace (<input>,<search pattern>[,<replace pattern>[,<all>[,<offset>]]])"
   if paramCount() = 1 and pText is "!" then return "FullReplace 1.1 by Frederic Rinaldi"
   if paramCount() < 2 then return "Error : Missing parameter(s)"
   if pAll is empty then put true into pAll
   if pAll is not among the items of "true,false" then return "Error : Param #4 must be boolean"
   if pStart is empty then put 1 into pStart
   if pStart is not an integer or pStart < 1 then return "Error : Param #5 must be > 0"
   if pSearch is empty then return pText
   put the number of chars of pSearch into tLength
   put pStart - 1 into tDone
   put char 1 to tDone of pText into tOut
   repeat
      put offset(pSearch, pText, tDone) into tAt
      if tAt is 0 then exit repeat
      put char tDone + 1 to tDone + tAt - 1 of pText & pReplace after tOut
      add tAt + tLength - 1 to tDone
      if pAll is false then exit repeat
   end repeat
   return tOut & char tDone + 1 to -1 of pText
end FullReplace

-- FullFind(text, string[, exactly[, all[, case[, start[, items]]]]])
-- (16 stacks), Frederic Rinaldi's XFCN: where the string is in the text,
-- as "X,Y,Z,T" (the number of its first character in the text, its line,
-- the number of that character in the line, and its item there), the
-- first time or, when all is true, every time, a line each; empty if it
-- is not there. A whole word unless exactly is false; case not counting
-- unless case is true; after the character start (0 when it is left
-- out); and only in the items of each line that items lists, when it is
-- given. Version 3's form is read too: after the string, in any order,
-- "m=" and letters (A all, C case, E a whole word, B the beginning of a
-- word, D accents, which here always count), "o=" the first character
-- searched, "i=" the items, "s=" the item separator
function FullFind pText, pString
   local tExact, tBeginning, tAll, tCase, tSkip, tItems, tSeparator, tParam, tValue, i
   if paramCount() = 1 and pText is "?" then return "FullFind(<container>,<pattern>[,<exactly>[,<all>[,<case sens.>[,<start>[,<item(s)>]]]]])"
   if paramCount() = 1 and pText is "!" then return "FullFind 1.4 by Frederic Rinaldi"
   if paramCount() < 2 then return "Error : Missing parameter(s)"
   put false into tBeginning
   put comma into tSeparator
   put param(3) into tParam
   if char 2 of tParam is "=" and char 1 of tParam is among the chars of "mois" then
      put false into tExact
      put false into tAll
      put false into tCase
      put 0 into tSkip
      repeat with i = 3 to paramCount()
         put param(i) into tParam
         put char 3 to -1 of tParam into tValue
         switch char 1 to 2 of tParam
            case "m="
               put "A" is in tValue into tAll
               put "C" is in tValue into tCase
               put "E" is in tValue into tExact
               put "B" is in tValue into tBeginning
               break
            case "o="
               if tValue is not an integer then return "Error : Incorrect param #" & i
               if tValue < 0 then return "Error : offset must be >= 0"
               put max(0, tValue - 1) into tSkip
               break
            case "i="
               put tValue into tItems
               break
            case "s="
               if the number of chars of tValue is not 1 then return "Error : Incorrect param #" & i
               put tValue into tSeparator
               break
            default
               return "Error : Incorrect param #" & i
         end switch
      end repeat
   else
      put _HCTrueFalse(param(3), true) into tExact
      if tExact is empty then return "Error : Param 3 must be true|false"
      put _HCTrueFalse(param(4), false) into tAll
      if tAll is empty then return "Error : Param 4 must be true|false"
      put _HCTrueFalse(param(5), false) into tCase
      if tCase is empty then return "Error : Param 5 must be true|false"
      put param(6) into tSkip
      if tSkip is empty then put 0 into tSkip
      if tSkip is not an integer or tSkip < 0 then return "Error : Param 6 must be a positive integer"
      put param(7) into tItems
   end if
   repeat for each item tValue in tItems
      if tValue is not an integer or tValue < 1 then return "Error : Param 7 must be an integer > 0"
   end repeat
   return _HCFullFind(pText, pString, tExact, tBeginning, tAll, tCase, tSkip, tItems, tSeparator)
end FullFind

-- pValue as true or false, pDefault when it is empty, and empty when it
-- is neither
private function _HCTrueFalse pValue, pDefault
   if pValue is empty then return pDefault
   if pValue is among the items of "true,false" then return pValue is true
   return empty
end _HCTrueFalse

-- Where pString is in pText, for FullFind: from the character after
-- pSkip, a whole word (pExact) or the beginning of one (pBeginning),
-- case counting when pCase is true, in one of the items pItems (between
-- pSeparator) of its line when there are any; the first or, when pAll is
-- true, every one (none overlapping), a line "X,Y,Z,T" each
private function _HCFullFind pText, pString, pExact, pBeginning, pAll, pCase, pSkip, pItems, pSeparator
   local tLength, tAt, tEnd, tLine, tLineStart, tCounted, tReturn, tItem, tOut
   if pString is empty then return empty
   set the caseSensitive to pCase
   put the number of chars of pString into tLength
   put 1 into tLine
   put 1 into tLineStart
   put 0 into tCounted
   repeat
      put offset(pString, pText, pSkip) into tAt
      if tAt is 0 then exit repeat
      add pSkip to tAt
      put tAt + tLength - 1 into tEnd
      put tAt into pSkip
      -- (a letter or digit on both sides of either end makes it part of
      -- a longer word)
      if (pExact or pBeginning) and _HCWordChar(char tAt - 1 of pText) and _HCWordChar(char 1 of pString) then next repeat
      if pExact and _HCWordChar(char tEnd + 1 of pText) and _HCWordChar(char -1 of pString) then next repeat
      -- its line, from the returns before it
      repeat
         put offset(return, pText, tCounted) into tReturn
         if tReturn is 0 or tCounted + tReturn >= tAt then exit repeat
         add tReturn to tCounted
         add 1 to tLine
         put tCounted + 1 into tLineStart
      end repeat
      set the itemDelimiter to pSeparator
      put the number of items of (char tLineStart to tAt - 1 of pText & "x") into tItem
      set the itemDelimiter to comma
      if pItems is not empty then
         if tItem is not among the items of pItems then next repeat
         if pSeparator is in pString or return is in pString then next repeat
      end if
      put tAt & comma & tLine & comma & tAt - tLineStart + 1 & comma & tItem & return after tOut
      if not pAll then exit repeat
      put tEnd into pSkip
   end repeat
   delete the last char of tOut
   return tOut
end _HCFullFind

-- Whether pChar is a letter or a digit, which a word is made of
private function _HCWordChar pChar
   set the caseSensitive to true
   return pChar is among the chars of "0123456789" or toUpper(pChar) is not toLower(pChar)
end _HCWordChar

-- SortLines(text[, order]) (6 stacks): the lines of the text in
-- alphabetical order, case not counting; descending when the order
-- begins with "D"
function SortLines pText, pOrder
   if char 1 of pOrder is "D" then
      sort lines of pText descending
   else
      sort lines of pText ascending
   end if
   return pText
end SortLines

-- SortItems(text[, lines[, order]]) (8 stacks): the items of the text
-- (between commas or returns; the empty ones left out) in alphabetical
-- order, case not counting, between commas, or one a line when lines is
-- true; descending when the order begins with "D"
function SortItems pText, pLines, pOrder
   local tItem, tList
   replace return with comma in pText
   repeat for each item tItem in pText
      if tItem is not empty then put tItem & return after tList
   end repeat
   delete the last char of tList
   if char 1 of pOrder is "D" then
      sort lines of tList descending
   else
      sort lines of tList ascending
   end if
   if pLines is not true then replace return with comma in tList
   return tList
end SortItems

-- Sort(text[, type]) (6 stacks; called hcX_Sort after the import, rule
-- T47), Boojum's XFCN: the lines of the text sorted, by the number each
-- begins with (0 if none) when the type begins with "n", else in
-- alphabetical order, case not counting (empty lines first)
function hcX_Sort pText, pType
   if char 1 of pType is "n" then
      sort lines of pText numeric by _HCLeadingNumber(each)
   else
      sort lines of pText ascending
   end if
   return pText
end hcX_Sort

private function _HCLeadingNumber pText
   local tNumber
   if matchText(pText, "^[ \t]*(-?[0-9]*\.?[0-9]+)", tNumber) then return tNumber + 0
   return 0
end _HCLeadingNumber

-- Find(text, string[, after line[, after item]]) (called hcX_Find after
-- the import, rule T47), Boojum's XFCN: "line,item" of the first item of
-- the text that is the string, case not counting, or that has it in it
-- when the string begins with "<" (which is not part of it); 0 if there
-- is none. The search begins on the line after the one given, or after
-- the item given of that line
function hcX_Find pText, pString, pAfterLine, pAfterItem
   local tPart, tLine, tItem, tLineNumber, tItemNumber
   put char 1 of pString is "<" into tPart
   if tPart then delete char 1 of pString
   if pAfterLine is not an integer then put 0 into pAfterLine
   if pAfterItem is not an integer then put 0 into pAfterItem
   put 0 into tLineNumber
   repeat for each line tLine in pText
      add 1 to tLineNumber
      if tLineNumber < pAfterLine or (tLineNumber = pAfterLine and pAfterItem <= 0) then next repeat
      put 0 into tItemNumber
      repeat for each item tItem in tLine
         add 1 to tItemNumber
         if tLineNumber = pAfterLine and tItemNumber <= pAfterItem then next repeat
         if (tPart and pString is in tItem) or (not tPart and tItem is pString) then
            return tLineNumber & comma & tItemNumber
         end if
      end repeat
   end repeat
   return 0
end hcX_Find

/*
FullSort(text[, option, ...][, list]) (19 stacks), Frederic Rinaldi's
XFCN: the lines of the text (its items, when it has commas and no
return) sorted, and the global FullSortList the number each had before,
in their new order. The options come in any order and any case:
"l=" (or "s=") the separator, a character or space, return, tab or
quote; "i=" the item delimiter of "c=item"; "t=" by what: a (character
codes, capitals first: the default), u (case not counting), i (as this
system orders text), n (the number in it), d (the date in it, month/day/
year), t (the time in it, hours:minutes); "d=" a (ascending, the
default), d (descending), r (random) or l (in the order the list gives,
numbers between commas, or else the order of the sort before, from
FullSortList, to sort a second list as the first); and "c=" the part of
each to sort by ("item 2", "word 1 to 5", "char 3 to *"). What has no
number, date or time to sort by goes last
*/
function FullSort pText
   global FullSortList
   local tParam, tType, tDirection, tChunk, tSep, tItemSep, tList, tTrail, i
   local tEntry, tEntries, tCount, tKeys, tOrder, tWithout, tUsed, tOut
   if paramCount() = 0 then return "Error : Missing input parameter"
   put "a" into tType
   put "a" into tDirection
   put comma into tItemSep
   repeat with i = 2 to paramCount()
      put param(i) into tParam
      if char 2 of tParam is "=" then
         switch char 1 of tParam
            case "l"
            case "s"
               put _HCSeparator(char 3 to -1 of tParam) into tSep
               break
            case "i"
               put _HCSeparator(char 3 to -1 of tParam) into tItemSep
               break
            case "t"
               put toLower(char 3 of tParam) into tType
               if tType is empty or tType is not among the chars of "andtiu" then return "Error : Char following " & quote & "t=" & quote & " must be [a,n,d,i,u]"
               break
            case "d"
               put toLower(char 3 of tParam) into tDirection
               if tDirection is empty or tDirection is not among the chars of "adrl" then return "Error : Char following " & quote & "d=" & quote & " must be [a,d,r,l]"
               break
            case "c"
               put char 3 to -1 of tParam into tChunk
               put word 1 to -1 of tChunk into tChunk
               if word 1 of tChunk is not among the words of "char character word item" then return "Error : " & quote & "c=" & quote & " param must be followed by [char,word,item]"
               if word 2 of tChunk is not an integer or word 2 of tChunk < 1 then return "Error : " & quote & "c=" & word 1 of tChunk & quote & " must be followed by a positive integer"
               break
            default
               return "Error : First char of param 2..n must be [t,d,c,s]"
         end switch
      else if tParam is not empty then
         put tParam into tList
      end if
   end repeat

   -- the entries: between returns, else between commas
   if tSep is empty then
      if return is in pText then
         put return into tSep
      else if comma is in pText then
         put comma into tSep
      else
         put return into tSep
      end if
   end if
   if pText is not empty and char -1 of pText is tSep then
      put tSep into tTrail
      delete char -1 of pText
   end if
   set the itemDelimiter to tSep
   put 0 into tCount
   repeat for each item tEntry in pText
      add 1 to tCount
      put tEntry into tEntries[tCount]
      put _HCSortKey(_HCChunkOf(tEntry, tChunk, tItemSep), tType) into tKeys[tCount]
   end repeat
   set the itemDelimiter to comma

   -- their order
   put empty into tOrder
   switch tDirection
      case "l"
         if tList is empty then put FullSortList into tList
         repeat for each item tEntry in tList
            put word 1 to -1 of tEntry into tEntry
            if tEntry is an integer and tEntry >= 1 and tEntry <= tCount and not tUsed[tEntry] then
               put true into tUsed[tEntry]
               put tEntry & return after tOrder
            end if
         end repeat
         repeat with i = 1 to tCount
            if not tUsed[i] then put i & return after tOrder
         end repeat
         break
      default
         repeat with i = 1 to tCount
            if tType is among the chars of "ndt" and tKeys[i] is empty then
               put i & return after tWithout
            else
               put i & return after tOrder
            end if
         end repeat
         delete the last char of tOrder
         if tDirection is "r" then
            sort lines of tOrder by random(1000000)
         else if tType is among the chars of "ndt" then
            if tDirection is "d" then
               sort lines of tOrder descending numeric by tKeys[each]
            else
               sort lines of tOrder ascending numeric by tKeys[each]
            end if
         else
            set the caseSensitive to (tType is "a")
            if tType is "i" then
               if tDirection is "d" then
                  sort lines of tOrder descending international by tKeys[each]
               else
                  sort lines of tOrder ascending international by tKeys[each]
               end if
            else if tDirection is "d" then
               sort lines of tOrder descending text by tKeys[each]
            else
               sort lines of tOrder ascending text by tKeys[each]
            end if
            set the caseSensitive to false
         end if
         if tOrder is not empty then put return after tOrder
         put tWithout after tOrder
   end switch
   delete the last char of tOrder

   repeat for each line i in tOrder
      put tEntries[i] & tSep after tOut
   end repeat
   delete the last char of tOut
   replace return with comma in tOrder
   put tOrder into FullSortList
   return tOut & tTrail
end FullSort

-- The character a FullSort option names: space, return, tab, quote or
-- comma by its name, else the option's first character
private function _HCSeparator pName
   if pName is among the words of "space return tab quote comma" then
      return value(pName)
   end if
   return char 1 of pName
end _HCSeparator

-- The part pChunk ("item 2", "word 1 to 5", "char 3 to *") of pEntry, all
-- of it with none
private function _HCChunkOf pEntry, pChunk, pItemSep
   local tFrom, tTo
   if pChunk is empty then return pEntry
   put word 2 of pChunk into tFrom
   put tFrom into tTo
   if word 3 of pChunk is "to" then
      put word 4 of pChunk into tTo
      if tTo is "*" then put -1 into tTo
   end if
   if tTo is not an integer then put tFrom into tTo
   switch word 1 of pChunk
      case "word"
         return word tFrom to tTo of pEntry
      case "item"
         set the itemDelimiter to pItemSep
         return item tFrom to tTo of pEntry
   end switch
   return char tFrom to tTo of pEntry
end _HCChunkOf

-- What FullSort sorts pText by for the type pType: for n, the first
-- number in it; d, the first date (month/day/year) as year, month and
-- day in one number; t, the first time in seconds from midnight; empty
-- for none. For the others, the text
private function _HCSortKey pText, pType
   local tA, tB, tC, tD, tDate
   switch pType
      case "n"
         if matchText(pText, "(-?[0-9]*\.?[0-9]+)", tA) then return tA + 0
         return empty
      case "d"
         if not matchText(pText, "([0-9]{1,2})/([0-9]{1,2})/([0-9]{2,4})", tA, tB, tC) then return empty
         put tA & "/" & tB & "/" & tC into tDate
         convert tDate to dateItems
         if the result is not empty then return empty
         return item 1 of tDate * 10000 + item 2 of tDate * 100 + item 3 of tDate
      case "t"
         if not matchText(pText, "([0-9]{1,2}):([0-9]{2})(?::([0-9]{2}))?[ ]*([AaPp][Mm])?", tA, tB, tC, tD) then return empty
         if tD is not empty then
            if tA = 12 then put 0 into tA
            if char 1 of tD is "p" then add 12 to tA
         end if
         return tA * 3600 + tB * 60 + tC
   end switch
   return pText
end _HCSortKey

-- IsRunning(application) (16 stacks): whether the application is open,
-- which a stack asked before it opened one (none is, here)
function IsRunning pApplication
   return false
end IsRunning

-- ChangeFileType(file, type, creator) (21 stacks): the Macintosh's type
-- and creator of a file, which files here do not have; nothing is
-- changed, and no error
function ChangeFileType pFile, pType, pCreator
   return empty
end ChangeFileType

-- SetFInfo file, "t=type", "c=creator" [, "m=date", "e=date"] (23
-- stacks), Frederic Rinaldi's XCMD: the same, with the dates the file
-- was changed and made, which are the system's here; nothing is
-- changed, and no error
on SetFInfo pFile
   return empty
end SetFInfo

-- FontName() (4 stacks, in their openStack), Guy de Picciotto's XFCN:
-- the fonts there are, separated by commas, as the stacks read them
-- ("put item it of fonts" after a PopUpMenu of them, Stack Analyzer)
function FontName
   local tFonts
   put the fontNames into tFonts
   replace return with comma in tFonts
   return tFonts
end FontName

-- available(type[, name[, file]]) (7 stacks), Nigel Perry's XFCN: the
-- names of the resources of a type that are open, one a line, or with a
-- name whether there is one of that name ("if not available(font,
-- "Palatino") then"). "font" or "fonts": the fonts there are; "soun" or
-- "sounds": the stack's sounds, which play names; "type" or "types":
-- the types of the stack's resources; "pict", "curs", "icon" or a type
-- of four characters ("Xdna", its case significant): the names of the
-- stack's resources of that type, from the import's list of its
-- resource fork. A file's (the third parameter) are not read here: none
function available pType, pName, pFile
   local tList
   if pFile is empty then put _HCAvailable(pType) into tList
   if the paramCount < 2 or pName is empty then return tList
   return pName is among the lines of tList
end available

private function _HCAvailable pType
   local tSet, tLine, tList, tTypes, tSeen, i
   if pType is among the words of "font fonts" then return the fontNames
   if pType is among the words of "soun sounds" then
      repeat with i = 1 to the number of audioClips of me
         put the short name of audioClip i of me & return after tList
      end repeat
      delete the last char of tList
      return tList
   end if
   put pType is among the words of "type types" into tTypes
   switch pType
      case "pict"
      case "pictures"
         put "PICT" into pType
         break
      case "curs"
      case "cursors"
         put "CURS" into pType
         break
      case "icon"
      case "icons"
         put "ICON" into pType
         break
   end switch
   put the customProperties["uHyperCard"] of me into tSet
   set the itemDelimiter to tab
   set the caseSensitive to true
   repeat for each line tLine in tSet["resources"]
      if tTypes then
         if tSeen[item 1 of tLine] is empty then
            put true into tSeen[item 1 of tLine]
            put item 1 of tLine & return after tList
         end if
      else if item 1 of tLine is pType and item 4 of tLine is not empty then
         put item 4 of tLine & return after tList
      end if
   end repeat
   delete the last char of tList
   return tList
end _HCAvailable

-- IsFile(path) (6 stacks), Frederic Rinaldi's XFCN: whether there is
-- such a file, a name alone in the stack's folder (a path here, not a
-- Mac path with colons)
function IsFile pPath
   if pPath is empty then return false
   return there is a file _HCBesideStack(pPath)
end IsFile

-- FileIsOpen(path) (8 stacks), Frederic Rinaldi's XFCN: whether open
-- file opened the file and close file has not closed it, a name alone
-- in the stack's folder ("if fileIsOpen(exportFile) is true then close
-- file exportFile", HyperBibTeX)
function FileIsOpen pPath
   if pPath is empty then return "Error : Missing or empty parameter"
   return pPath is among the lines of the openFiles or _HCBesideStack(pPath) is among the lines of the openFiles
end FileIsOpen

-- A file's name alone, as Rinaldi's externals took it: the file of that
-- name in the folder of the stack (where it is now, else where it was
-- imported from); a path as it is
private function _HCBesideStack pPath
   local tFolder, tSet
   if slash is in pPath then return pPath
   set the itemDelimiter to slash
   put item 1 to -2 of (the effective filename of me) into tFolder
   if tFolder is empty then
      put the customProperties["uHyperCard"] of me into tSet
      put item 1 to -2 of tSet["file"] into tFolder
   end if
   if tFolder is empty then return pPath
   return tFolder & slash & pPath
end _HCBesideStack

-- translit(from, to, text) (8 stacks), Nigel Perry's XFCN: the text
-- with each character of from in it changed to the character of to at
-- the same place ("translit("ATGC", "TACG", primer)", a sequence's
-- complement), to the last of to past its end, and taken out when to is
-- empty ("translit("m", "", units)"). The case of a character counts.
-- As the stacks use it: a backslash before from means every character
-- but its own ("length(translit("\Aa", "", seq))", the number of A's),
-- and from "\t" alone is a tab ("translit("\t", ",", header)"), "\r"
-- a return, the end of a line, and "\n" a line feed, which ended no
-- line in HyperCard's text: here, where a return is a line feed, a
-- carriage return
function translit pFrom, pTo, pText
   local tExcept, tOut, tChar, tAt
   set the caseSensitive to true
   switch pFrom
      case "\t"
         put tab into pFrom
         break
      case "\r"
         put return into pFrom
         break
      case "\n"
         put numToChar(13) into pFrom
         break
      default
         if char 1 of pFrom is "\" then
            put true into tExcept
            delete char 1 of pFrom
         end if
   end switch
   repeat for each char tChar in pText
      put offset(tChar, pFrom) into tAt
      if tExcept is true then
         if tAt > 0 then
            put tChar after tOut
         else if pTo is not empty then
            put char -1 of pTo after tOut
         end if
      else if tAt = 0 then
         put tChar after tOut
      else if pTo is not empty then
         put char min(tAt, the number of chars of pTo) of pTo after tOut
      end if
   end repeat
   return tOut
end translit

/*
Password([prompt[, caseSensitive]]) (7 stacks), Kevin Calhoun's XFCN of
Dartmouth College, whose Pascal source is in the Dartmouth XCMD's stack:
asks for a password, with the prompt or "Please enter your password:",
the reply hidden as it is typed, and gives "Cancel" when the dialog is
cancelled, else a number made from the reply (its Encrypt): the sum of
its codes (Mac Roman), then ten times that times 16381, plus 17, mod
32761, plus 1; 0 for an empty reply. The reply is in capitals first,
unless caseSensitive is true. Archivist keeps the number of the password
a user set and compares a later reply's with it, so the number is the
external's. Its first version (1684 bytes, by the import's list of the
stack's resources: HyperFTP, HyperGCG, Mews) gave the reply as typed, and
nothing when cancelled, which those stacks send to a server. Called as
hcX_Password: this engine reads "password(" as its property (rule T13)
*/
function hcX_Password pPrompt, pCaseSensitive
   local tSet, tLine, tFirst, tCodes, tSum, i
   if the paramCount < 1 then put "Please enter your password:" into pPrompt
   put the customProperties["uHyperCard"] of me into tSet
   set the itemDelimiter to tab
   repeat for each line tLine in tSet["resources"]
      if item 1 of tLine is "XFCN" and item 4 of tLine is "Password" and item 3 of tLine is 1684 then put true into tFirst
   end repeat
   ask password clear pPrompt
   if the result is "Cancel" then
      if tFirst then return empty
      return "Cancel"
   end if
   if tFirst then return char 1 to 255 of it
   put _HCMacCodes(it, not (the paramCount > 1 and pCaseSensitive is true)) into tCodes
   put 0 into tSum
   repeat with i = 1 to the number of elements of tCodes
      add tCodes[i] to tSum
   end repeat
   if the number of elements of tCodes > 0 then
      repeat 10 times
         put (tSum * 16381 + 17) mod 32761 + 1 into tSum
      end repeat
   end if
   return tSum
end hcX_Password

/*
SysEnv() (6 stacks), the XFCN: the Mac that kHCSystem describes as its
SysEnvirons record, a line of its model ("unknown", one the external
does not know), System, processor, whether it has a math coprocessor and
Color QuickDraw (true or false), keyboard, AppleTalk driver's version (0,
none) and System's volume reference number, between commas, then a line
of the main screen's depth and "Color" (or "B&W"). Read from the
external's code (2722 bytes, 5 of the stacks): the minor version of the
System is its digit times 16 there ("7.80.5" for 7.5.5), and stacks
read the first character of it ("if char 1 of theSystem contains "7"",
Doctor Who's) or the depth ("if item 1 of line 2 of mySys > 1", The
Critical Eye's); with a parameter it gives "SysEnv expects no
parameters." Its other version (2330 bytes, one stack, which no script
calls) said "processor unknown" for a 68040
*/
function SysEnv
   local tSystem
   if the paramCount > 0 then return "SysEnv expects no parameters."
   set the itemDelimiter to "."
   put item 1 of kHCSystem & "." & (item 2 of kHCSystem) * 16 into tSystem
   if item 3 of kHCSystem > 0 then put "." & item 3 of kHCSystem after tSystem
   return "unknown," & tSystem & ",Motorola 68040,true,true,Apple Extended keyboard,0,-1" & return & MaxDepth() & ",Color"
end SysEnv

/*
SysEnvirons(n) (2 stacks), the XFCN: field n of the Mac's SysEnvirons
record, as the external gives it (read from its code, 1448 bytes) for
the Mac that kHCSystem describes: 1 the record's version (1), 2 the
model (0, one the System does not know), 3 the System in four hex
digits ("0755"), 4 the processor (5, a 68040), 5 and 6 whether it has a
math coprocessor and Color QuickDraw (true), 7 the keyboard (4, an
Apple Extended Keyboard), 8 the AppleTalk driver's version (0, none)
and 9 the System's volume reference number (-1); any other parameter as
it is. Stack Starter adds to its FastMac for a coprocessor ("if
SysEnvirons(5) then add 1 to FastMac")
*/
function SysEnvirons pWhich
   local tSystem
   if pWhich is not an integer or pWhich < 1 or pWhich > 9 then return pWhich
   set the itemDelimiter to "."
   put char -2 to -1 of ("0" & item 1 of kHCSystem) & item 2 of kHCSystem & item 3 of kHCSystem into tSystem
   set the itemDelimiter to comma
   return item pWhich of ("1,0," & tSystem & ",5,true,true,4,0,-1")
end SysEnvirons

/*
SysEnvirons (13 stacks), Jon Pugh's XCMD: the Mac's SysEnvirons record
in globals, as text, for the Mac that kHCSystem describes: machineType
its model, systemVersion its System ("7.5.5"), processor ("68040"),
hasFPU and hasColorQD (true), atDrvrVersNum the AppleTalk driver's
version (0, none), keyBoardType ("Extended ADB Keyboard") and
systemFolder the System Folder's path, a Mac path on the disk of
HyperCard (hcHyperCardName). Read from the external's code: the model is
"Unknown Machine" (3486 bytes, 11 of the stacks, CoinMaster's), one it
does not know; its later version (3190 bytes) gives the System's name
for the model, and the System had none for one it did not know. A
script's globals systemVersion, processor and keyBoardType are named
hc_systemVersion, hc_processor and hc_keyBoardType after the import (rule
T2: this engine refuses those names for variables), and so they are here
*/
on SysEnvirons
   global machineType, hc_systemVersion, hc_processor, hasFPU, hasColorQD
   global atDrvrVersNum, hc_keyBoardType, systemFolder
   local tSet, tLine
   put "Unknown Machine" into machineType
   put the customProperties["uHyperCard"] of me into tSet
   set the itemDelimiter to tab
   repeat for each line tLine in tSet["resources"]
      if item 1 of tLine is "XCMD" and item 4 of tLine is "SysEnvirons" and item 3 of tLine is 3190 then put empty into machineType
   end repeat
   put kHCSystem into hc_systemVersion
   put "68040" into hc_processor
   put true into hasFPU
   put true into hasColorQD
   put 0 into atDrvrVersNum
   put "Extended ADB Keyboard" into hc_keyBoardType
   set the itemDelimiter to ":"
   put item 1 of hcHyperCardName("long") & ":System Folder:" into systemFolder
end SysEnvirons

/*
MacType() (12 stacks), Frederic Rinaldi's XFCN: the Mac that kHCSystem
describes, its model, System, processor, whether it has a math
coprocessor and Color QuickDraw, and its keyboard, between commas, as
version 1.3 gives them (read from its code, 2704 bytes, 9 of the
stacks): "Unknown CPU", a model it cannot name, "7.5.5", "MC68040",
true, true, "Apple Extended keyboard". "?" gives its syntax, "!" its
version and "=" what it gives. Stacks take the System from item 2 ("get
item 2 of MacType()", then "if it < 7.0", GetDInfo's) or the model from
item 1. Its versions 2.x (3 stacks) add the memory and the clock speed
and name the model, processor and keyboard more briefly ("Quadra 950",
"68040", "Extended ADB", by their documentation), with the System the
same
*/
function MacType pWhich
   if the paramCount = 1 then
      switch pWhich
         case "?"
            return "MacType()"
         case "!"
            return "Version 1.3," && numToCodepoint(169) && "Frederic RINALDI 1989,1990,1991"
         case "="
            return "<CPU>,<System>,<Processor>,<HasFPU>,<HasColorQD>,<keyboard>"
      end switch
   end if
   return "Unknown CPU," & kHCSystem & ",MC68040,true,true,Apple Extended keyboard"
end MacType

/*
DialogDisplay(id, button 1, button 2, button 3, text 1, ..., text 4,
outline) (15 stacks), the XFCN: the stack's DLOG resource id as a dialog,
the buttons and texts given in its items; the number of the button
clicked. The resource is not imported, so the dialog is an answer dialog
with the texts given, one a line, and the buttons given (button 1 the
default, OK if none is); with no text and no button there is nothing to
show, and nothing is shown: empty
*/
function DialogDisplay pID, pButton1, pButton2, pButton3, pText1, pText2, pText3, pText4
   local tText, tButtons, tNames, i
   repeat with i = 5 to 8
      if param(i) is not empty then put param(i) & return after tText
   end repeat
   delete the last char of tText
   repeat with i = 2 to 4
      if param(i) is not empty then
         put i - 1 into tButtons[the number of elements of tButtons + 1]
         put param(i) & return after tNames
      end if
   end repeat
   if tText is empty and tNames is empty then return empty
   switch the number of elements of tButtons
      case 0
         answer tText
         return 1
      case 1
         answer tText with line 1 of tNames
         break
      case 2
         answer tText with line 2 of tNames or line 1 of tNames
         break
      default
         answer tText with line 3 of tNames or line 2 of tNames or line 1 of tNames
   end switch
   repeat with i = 1 to the number of elements of tButtons
      if line i of tNames is it then return tButtons[i]
   end repeat
   return empty
end DialogDisplay

/*
ListSelect(mode, list[, ...]) (29 stacks), Frederic Rinaldi's XFCN: the
user picks from the list (its lines, or its items when it has no return)
in a dialog; the items picked, or their numbers in the list, between
separators, empty if they cancel. The global ListSelectExit holds the
name of the button that closed it. The mode is 0 or No (nothing to
pick), 1 or One, 2 or Con (a run of them), 3 or Dis (any of them),
after "*" to show the list sorted, and before "#" for numbers. The rest
come in any order (hcListSelectOptions)
*/
function ListSelect pMode, pList
   global ListSelectExit
   local tParams, tOptions, tEntries, tCount, tEntry, tShown, tLine, tChosen, tOut, i
   if paramCount() = 1 and pMode is "?" then return "ListSelect(<mode>,<list>[,s=#[,#]][,NoDoubleClick][,prompt][,OK][,Cancel][,loc|rect][,sep][,DLOG ID][,font[,size]])"
   if paramCount() = 1 and pMode is "!" then return "ListSelect 4.8 by Frederic Rinaldi"
   if paramCount() < 2 then return "Error : Missing Parameter(s)"
   repeat with i = 3 to paramCount()
      put param(i) into tParams[i - 2]
   end repeat
   put hcListSelectOptions(pMode, tParams) into tOptions
   if tOptions["error"] is not empty then return tOptions["error"]

   if return is in pList then set the itemDelimiter to return
   put 0 into tCount
   repeat for each item tEntry in pList
      add 1 to tCount
      put tEntry into tEntries[tCount]
      put tCount & return after tShown
   end repeat
   set the itemDelimiter to comma
   delete the last char of tShown
   if tOptions["sorted"] then sort lines of tShown by tEntries[each]
   repeat for each line i in tShown
      put tEntries[i] & return after tOptions["list"]
   end repeat
   delete the last char of tOptions["list"]

   put _HCListDialog(tOptions) into tChosen
   put line 2 of tChosen into ListSelectExit
   if line 3 of tChosen is not "ok" or tOptions["mode"] = 0 then return empty
   repeat for each item tLine in line 1 of tChosen
      put line tLine of tShown into i
      if tOptions["numbers"] then
         put i & tOptions["separator"] after tOut
      else
         put tEntries[i] & tOptions["separator"] after tOut
      end if
   end repeat
   delete the last char of tOut
   return tOut
end ListSelect

/*
What ListSelect's mode and the parameters after its list ask for, in any
order: "s=" and the lines picked at first (1 when it is left out, s=0
none); "NoDoubleClick"; a place, "left,top", or a rect; a separator, one
character or return or tab; a DLOG resource's id, a number, which is not
imported; a font, "name,size"; and the rest are the prompt, the OK
button's name and the Cancel button's, an empty one hiding it, and the
font's name. Returns ["mode"] (0 to 3), ["sorted"], ["numbers"],
["select"], ["double"], ["topLeft"], ["rect"], ["separator"],
["prompt"], ["ok"], ["cancel"], ["font"] and ["size"], or ["error"]
*/
function hcListSelectOptions pMode, pParams
   local tOptions, tParam, tStrings, i
   put word 1 to -1 of pMode into pMode
   put char 1 of pMode is "*" into tOptions["sorted"]
   if tOptions["sorted"] then delete char 1 of pMode
   put char -1 of pMode is "#" into tOptions["numbers"]
   if tOptions["numbers"] then delete char -1 of pMode
   switch
      case pMode is "0" or char 1 of pMode is "N"
         put 0 into tOptions["mode"]
         break
      case pMode is "1" or char 1 of pMode is "O"
         put 1 into tOptions["mode"]
         break
      case pMode is "2" or char 1 of pMode is "C"
         put 2 into tOptions["mode"]
         break
      case pMode is "3" or char 1 of pMode is "D"
         put 3 into tOptions["mode"]
         break
      default
         put "Error : Bad Mode Parameter" into tOptions["error"]
         return tOptions
   end switch
   put 1 into tOptions["select"]
   put true into tOptions["double"]
   put comma into tOptions["separator"]
   put "OK" into tOptions["ok"]
   put "Cancel" into tOptions["cancel"]
   put 0 into tStrings
   repeat with i = 1 to the number of elements of pParams
      put pParams[i] into tParam
      switch
         case char 1 to 2 of tParam is "s="
            put char 3 to -1 of tParam into tOptions["select"]
            break
         case tParam is "NoDoubleClick"
            put false into tOptions["double"]
            break
         case tParam is an integer
            -- (a DLOG resource's id)
            break
         case _HCIntegers(tParam, 2)
            put tParam into tOptions["topLeft"]
            break
         case _HCIntegers(tParam, 4)
            put tParam into tOptions["rect"]
            break
         case the number of chars of tParam is 1
            put tParam into tOptions["separator"]
            break
         case tParam is "return" or tParam is "tab"
            put value(tParam) into tOptions["separator"]
            break
         case the number of items of tParam is 2 and item 2 of tParam is an integer and item 1 of tParam is not empty
            put item 1 of tParam into tOptions["font"]
            put item 2 of tParam into tOptions["size"]
            break
         default
            add 1 to tStrings
            switch tStrings
               case 1
                  put tParam into tOptions["prompt"]
                  break
               case 2
                  put tParam into tOptions["ok"]
                  break
               case 3
                  put tParam into tOptions["cancel"]
                  break
               case 4
                  put tParam into tOptions["font"]
                  break
            end switch
      end switch
   end repeat
   return tOptions
end hcListSelectOptions

-- Whether pText is pCount integers between commas
private function _HCIntegers pText, pCount
   local tItem
   if the number of items of pText is not pCount or char -1 of pText is comma then return false
   repeat for each item tItem in pText
      if word 1 to -1 of tItem is not an integer then return false
   end repeat
   return true
end _HCIntegers

/*
The dialog of ListSelect, its options as hcListSelectOptions gives them
and pOptions["list"] the lines shown: the numbers of the lines picked on
line 1, the name of the button that closed it on line 2 and on line 3
"ok" or "cancel" (empty if it was closed otherwise). A double click is
OK, unless the options say not; so are Return and Enter, and Escape is
Cancel. Its place is the card window's centre, or the place given, from
the card window's top left (rule T46)
*/
private function _HCListDialog pOptions
   local tDefault, tName, tStack, tWidth, tHeight, tTop, tOut, tRect
   put the defaultStack into tDefault
   -- (a name of its own, so that no stack of the user's is touched; kept
   -- until its choice is read)
   put "HyperCard List " & the milliseconds into tName
   get _HCNewHiddenStack(tName)
   put the long id of it into tStack
   set the title of tStack to "Choose"
   set the defaultStack to tName
   -- (a dialog opens centred on the card window, but where its own
   -- preOpenStack puts it; and a list's hilites, lost as its stack
   -- closes, are set there too, _HCReadyToShow closing it)
   set the script of this card to "on preOpenStack" & return & \
         "if the uTopLeft of the owner of me is not empty then set the topLeft of the owner of me to the uTopLeft of the owner of me" & return & \
         "try" & return & "set the hilitedLines of field " & quote & "List" & quote & " of me to the uHilited of the owner of me" & return & \
         "catch tError" & return & "end try" & return & \
         "pass preOpenStack" & return & "end preOpenStack" & return & "on escapeKey" & return & \
         "send " & quote & "mouseUp" & quote & " to button " & quote & "Cancel" & quote & " of me" & return & \
         "end escapeKey"
   put 10 into tTop
   if pOptions["prompt"] is not empty then
      create field "Prompt"
      set the lockText of it to true
      set the borderWidth of it to 0
      set the opaque of it to false
      set the threeD of it to false
      put pOptions["prompt"] into field "Prompt"
      put 34 into tTop
   end if
   create field "List"
   set the lockText of it to true
   set the dontWrap of it to true
   set the vScrollbar of it to true
   if pOptions["font"] is among the lines of the fontNames then set the textFont of it to pOptions["font"]
   if pOptions["size"] is an integer and pOptions["size"] > 0 then set the textSize of it to pOptions["size"]
   put pOptions["list"] into field "List"
   if pOptions["mode"] > 0 then
      set the listBehavior of it to true
      set the multipleHilites of it to (pOptions["mode"] > 1)
      set the nonContiguousHilites of it to (pOptions["mode"] = 3)
      if pOptions["select"] is not 0 and pOptions["select"] is not empty then
         if pOptions["mode"] = 1 then put item 1 of pOptions["select"] into pOptions["select"]
         set the uHilited of tStack to pOptions["select"]
      end if
      if pOptions["double"] then
         set the script of it to "on mouseDoubleUp" & return & \
               "send " & quote & "mouseUp" & quote & " to button " & quote & "OK" & quote & " of the owner of me" & return & \
               "end mouseDoubleUp"
      end if
   end if
   put max(300, min(600, the formattedWidth of field "List" + 40)) into tWidth
   put 300 into tHeight
   if pOptions["rect"] is not empty then
      put pOptions["rect"] into tRect
      if item 3 of tRect - item 1 of tRect >= 160 and item 4 of tRect - item 2 of tRect >= 120 then
         put item 3 of tRect - item 1 of tRect into tWidth
         put item 4 of tRect - item 2 of tRect into tHeight
      end if
   end if
   set the width of tStack to tWidth
   set the height of tStack to tHeight
   if there is a field "Prompt" then set the rect of field "Prompt" to 10, 8, tWidth - 10, 32
   set the rect of field "List" to 10, tTop, tWidth - 10, tHeight - 44
   -- (both buttons are made, an empty name hiding one: a double click
   -- and Return are still OK, and Escape Cancel)
   create button "OK"
   set the label of it to pOptions["ok"]
   set the visible of it to (pOptions["ok"] is not empty)
   set the rect of it to tWidth - 100, tHeight - 36, tWidth - 10, tHeight - 10
   set the default of it to true
   set the script of it to "on mouseUp" & return & \
         "set the uChosen of the owner of the owner of me to the hilitedLines of field " & quote & "List" & quote & " of the owner of me" & return & \
         "set the uButton of the owner of the owner of me to the label of me" & return & \
         "set the uHow of the owner of the owner of me to " & quote & "ok" & quote & return & \
         "close stack (the short name of the owner of the owner of me)" & return & "end mouseUp"
   create button "Cancel"
   set the label of it to pOptions["cancel"]
   set the visible of it to (pOptions["cancel"] is not empty)
   if pOptions["ok"] is empty then
      set the rect of it to tWidth - 100, tHeight - 36, tWidth - 10, tHeight - 10
   else
      set the rect of it to tWidth - 200, tHeight - 36, tWidth - 110, tHeight - 10
   end if
   set the script of it to "on mouseUp" & return & \
         "set the uButton of the owner of the owner of me to the label of me" & return & \
         "set the uHow of the owner of the owner of me to " & quote & "cancel" & quote & return & \
         "close stack (the short name of the owner of the owner of me)" & return & "end mouseUp"
   set the defaultStack to tDefault
   if pOptions["rect"] is not empty then
      set the uTopLeft of tStack to _HCPlace("topleft", item 1 to 2 of pOptions["rect"], false)
   else if pOptions["topLeft"] is not empty then
      set the uTopLeft of tStack to _HCPlace("topleft", pOptions["topLeft"], false)
   end if
   _HCReadyToShow tStack
   modal stack tName
   if exists(tStack) then
      put the uChosen of tStack & return & the uButton of tStack & return & the uHow of tStack into tOut
      delete stack tName
   end if
   return tOut
end _HCListDialog

-- The line of pList the user picks in a list dialog, or empty if they
-- cancel
function hcChooseLine pPrompt, pList
   local tDefault, tLine, tName, tStack
   if pList is empty then return empty
   put the defaultStack into tDefault
   -- (a name of its own, so that no stack of the user's is touched; kept
   -- until its choice is read)
   put "HyperCard List " & the milliseconds into tName
   get _HCNewHiddenStack(tName)
   put the long id of it into tStack
   set the title of tStack to "Choose"
   set the width of tStack to 360
   set the height of tStack to 300
   set the defaultStack to tName
   -- (its first line hilited as it opens: a list's hilites are lost as
   -- its stack closes, which _HCReadyToShow does)
   set the script of this card to "on preOpenStack" & return & "set the hilitedLine of field " & quote & "List" & quote & " of me to 1" & return & \
         "pass preOpenStack" & return & "end preOpenStack"
   create field "Prompt"
   set the rect of it to 10,10,350,34
   set the lockText of it to true
   put pPrompt into field "Prompt"
   create field "List"
   set the rect of it to 10,40,350,250
   set the listBehavior of it to true
   set the lockText of it to true
   set the vScrollbar of it to true
   put pList into field "List"
   create button "OK"
   set the rect of it to 270,262,350,288
   set the default of it to true
   set the script of it to "on mouseUp" & return & "set the uChosen of the owner of the owner of me to the hilitedLine of field " & quote & "List" & quote & " of the owner of me" & return & "close stack (the short name of the owner of the owner of me)" & return & "end mouseUp"
   create button "Cancel"
   set the rect of it to 180,262,260,288
   set the script of it to "on mouseUp" & return & "close stack (the short name of the owner of the owner of me)" & return & "end mouseUp"
   set the defaultStack to tDefault
   _HCReadyToShow tStack
   modal stack tName
   if exists(tStack) then
      put the uChosen of tStack into tLine
      delete stack tName
   end if
   return tLine
end hcChooseLine

private function _HCMenuText pItems, pChecked
   if pChecked is an integer and abs(pChecked) > 0 and abs(pChecked) <= the number of lines of pItems then
      put "!c" before line abs(pChecked) of pItems
   end if
   return pItems
end _HCMenuText

private function _HCLineOf pChosen, pItems
   local tLine, i
   put 0 into i
   repeat for each line tLine in pItems
      add 1 to i
      if tLine is pChosen or (char 1 to 2 of tLine is "!c" and char 3 to -1 of tLine is pChosen) then return i
   end repeat
   return 0
end _HCLineOf

-- Shows pText as a popup menu with its top left at pLeft,pTop (the mouse
-- if they are left out); the item chosen, or empty
private function _HCPopUp pText, pTop, pLeft
   local tDefault, tChosen
   put the defaultStack into tDefault
   if sHCPopUp is empty or not exists(sHCPopUp) then
      -- (a name of its own, so that no stack of the user's is touched)
      get _HCNewHiddenStack("HyperCard Popup " & the milliseconds)
      put the long id of it into sHCPopUp
      set the defaultStack to the short name of sHCPopUp
      create button "Menu"
      set the style of it to "menu"
      set the menuMode of it to "popup"
      set the menuMouseButton of it to 0
      set the script of it to "on menuPick pItem" & return & "set the uChosen of me to pItem" & return & "end menuPick"
      set the defaultStack to tDefault
   end if
   set the text of button "Menu" of sHCPopUp to pText
   set the uChosen of button "Menu" of sHCPopUp to empty
   if pTop is an integer and pLeft is an integer then
      popup button "Menu" of sHCPopUp at pLeft, pTop
   else
      popup button "Menu" of sHCPopUp
   end if
   put the uChosen of button "Menu" of sHCPopUp into tChosen
   return tChosen
end _HCPopUp

-- The text _HCSpeak last spoke, for hcSpeech
local sHCSpeechText

-- In a browser (the Stack Player) by the page's speech synthesis, else
-- by revSpeak. The text is kept for hcSpeech
private function _HCSpeak pText
   put pText into sHCSpeechText
   if the platform is "web" then
      try
         do "window.speechSynthesis.speak(new SpeechSynthesisUtterance(" & _HCJavaScriptString(pText) & "))" as "javascript"
      catch tError
         return "Speech is not available"
      end try
      return empty
   end if
   try
      revSpeak pText
   catch tError
      return "Speech is not available"
   end try
   return the result
end _HCSpeak

-- HyperCard 2.2's speech functions and stop speech (rule T61), by
-- revSpeech, which speaks in the browser too: the text being spoken, or
-- "done" when none is (the speech); the voices, one a line, empty where
-- there is no speech (the voices). "stop speech" stops what is being
-- spoken
function hcSpeech
   local tSpeaking
   put false into tSpeaking
   try
      put revIsSpeaking() is true into tSpeaking
   catch tError
   end try
   if tSpeaking then return sHCSpeechText
   return "done"
end hcSpeech

function hcVoices
   local tVoices
   try
      put revSpeechVoices() into tVoices
   catch tError
   end try
   return tVoices
end hcVoices

on hcStopSpeech
   try
      revStopSpeech
   catch tError
   end try
end hcStopSpeech

-- pText as a JavaScript string literal. (Its carriage returns are
-- numToCodepoint(13): this library runs in the imported stack, where
-- numToChar(13) is the return, as in HyperCard)
private function _HCJavaScriptString pText
   replace "\" with "\\" in pText
   replace quote with "\" & quote in pText
   replace return with "\n" in pText
   replace numToCodepoint(13) with "\r" in pText
   return quote & pText & quote
end _HCJavaScriptString
