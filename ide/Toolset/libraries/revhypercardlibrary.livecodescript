script "revHyperCardLibrary"
-- OXT-Beyond: the end of an imported HyperCard stack's message path.
--
-- revHyperCardFixScripts (revhypercardscriptlibrary.livecodescript) puts
-- this script in the substack "HyperCard Library" of a stack imported
-- with File > Import Stack and makes that substack the stack's behavior,
-- so that it comes after the stack's own script, where HyperCard's Home
-- stack and HyperCard itself were. The scripts it rewrites call these
-- handlers for the parts of HyperCard this engine does not have. A
-- stack's own handler of the same name comes first, as in HyperCard.
--
-- What each does here, rather than in HyperCard, is said beside it.

-- A menu choice: HyperCard sent doMenu for each one, and a stack's
-- "on doMenu" handler is called hcDoMenu after the import (no handler here
-- can be called doMenu). A choice that reaches here does what the
-- engine's doMenu command does with it.
on hcDoMenu pItem, pMenu
   doMenu pItem
   return the result
end hcDoMenu

-- HyperCard's version, which scripts compare with numbers ("the version
-- < 2"): that of HyperCard 2.4.1, the last
function hcVersion
   return "2.4.1"
end hcVersion

-- HyperCard's long version, as HyperCard 2.4.1 gave it
function hcLongVersion
   return "02418000"
end hcLongVersion

-- Whether HyperCard was in the background (MultiFinder): never here
function hcSuspended
   return false
end hcSuspended

-- reset menubar put HyperCard's own menus back; there are none here
on hcResetMenubar
end hcResetMenubar

-- go home: the Home stack, if one is open or can be found by name, as
-- HyperCard's was in every stack's path
on hcGoHome
   if there is a stack "Home" then
      go stack "Home"
      return the result
   end if
   return "Can't find the Home stack"
end hcGoHome

-- palette "Name", "h,v": open the palette (the importer makes each PLTE
-- resource a substack of that name) with its top left at h,v
on hcPalette pName, pLocation
   if there is not a stack pName then return "Can't find palette" && pName
   palette stack pName
   if pLocation is not empty then set the topLeft of stack pName to pLocation
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

-- put ... into menu ... with menuMsg: HyperCard 2.2's menus, which this
-- engine's menus do not take yet
on hcPutIntoMenu pItems, pPreposition, pMenu, pMessages
   return "HyperCard menus are not supported yet"
end hcPutIntoMenu

-- create menu, delete menu: HyperCard 2.2's menus, as above
on hcCreateMenu pMenu
   return "HyperCard menus are not supported yet"
end hcCreateMenu

on hcDeleteMenu pMenu
   return "HyperCard menus are not supported yet"
end hcDeleteMenu

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
   local tPrompt, i
   put "Choose a file:" into tPrompt
   repeat with i = 1 to paramCount()
      if (the number of chars of param(i)) > 4 then put param(i) into tPrompt
   end repeat
   answer file tPrompt
   if the result is "Cancel" then return empty
   return it
end FileName

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

-- ColorizeHC: colour drawn over the card, which this engine does with
-- its own colours (the importer keeps AddColor's as a colour layer)
on ColorizeHC
   return empty
end ColorizeHC

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
      create invisible stack "Promptoid"
      set the uHyperCard["promptoid"] of it to true
      set the destroyStack of it to true
      set the width of it to 320
      set the height of it to 60
      set the defaultStack to "Promptoid"
      create field "Message"
      set the rect of it to 10,10,310,50
      set the lockText of it to true
      set the defaultStack to tDefault
   end if
   put pMessage into field "Message" of stack "Promptoid"
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

-- The line of pList the user picks in a list dialog, or empty if they
-- cancel
function hcChooseLine pPrompt, pList
   local tDefault, tLine, tName, tStack
   if pList is empty then return empty
   put the defaultStack into tDefault
   -- (a name of its own, so that no stack of the user's is touched; kept
   -- until its choice is read)
   put "HyperCard List " & the milliseconds into tName
   create invisible stack tName
   put the long id of it into tStack
   set the title of tStack to "Choose"
   set the width of tStack to 360
   set the height of tStack to 300
   set the defaultStack to tName
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
   set the hilitedLine of field "List" to 1
   create button "OK"
   set the rect of it to 270,262,350,288
   set the default of it to true
   set the script of it to "on mouseUp" & return & "set the uChosen of the owner of the owner of me to the hilitedLine of field " & quote & "List" & quote & " of the owner of me" & return & "close stack (the short name of the owner of the owner of me)" & return & "end mouseUp"
   create button "Cancel"
   set the rect of it to 180,262,260,288
   set the script of it to "on mouseUp" & return & "close stack (the short name of the owner of the owner of me)" & return & "end mouseUp"
   set the defaultStack to tDefault
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
      create invisible stack ("HyperCard Popup " & the milliseconds)
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

private function _HCSpeak pText
   try
      revSpeak pText
   catch tError
      return "Speech is not available"
   end try
   return the result
end _HCSpeak
