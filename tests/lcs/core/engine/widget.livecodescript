script "CoreEngineWidgets"
/*
Copyright (C) 2016 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

//////////

on TestSetup
   TestSkipIfNot "lcb"
   
   TestLoadAuxiliaryExtension "_widget"
   TestLoadAuxiliaryExtension "_widget_support"
   TestLoadAuxiliaryExtension "_widgetthrow"
end TestSetup

//////////

on TestWidgetBindErrorsDontEscape
   create stack "WidgetBindErrorTest"
   set the defaultStack to "WidgetBindErrorTest"

   local tArray
   put "foo" into tArray["$kind"]
   put empty into tArray["$state"]
   import widget from array tArray

   local tErrorIsPending
   try
      put TestWidget_MCErrorIsPending() into tErrorIsPending
   catch tError
      put true into tErrorIsPending
   end try

   TestAssert "no error lingers after widget bind failure", not tErrorIsPending

   delete stack "WidgetBindErrorTest"
end TestWidgetBindErrorsDontEscape

//////////

private command _DoTestWidgetScriptObjectAccess pMode
   set the testMode of widget "Test" to pMode

   export widget "Test" to array tVar

   TestAssertErrorDialog "no script access allowed for" && pMode, \ 
       "EE_EXTENSION_ERROR_DOMAIN"
end _DoTestWidgetScriptObjectAccess

on TestWidgetScriptObjectAccess
   create stack "WidgetScriptAccessTest"
   set the defaultStack to "WidgetScriptAccessTest"

   create widget "Test" as "com.livecode.lcs_tests.core.widget"
   set the behavior of it to the long id of me

   repeat for each item tMode in "resolve,get,set,send,post,execute"
      _DoTestWidgetScriptObjectAccess tMode
   end repeat

   delete stack "WidgetScriptAccessTest"
end TestWidgetScriptObjectAccess

on TestWidgetThrowInOnCreate
   create stack "WidgetThrowOnSaveTest"
   set the defaultStack to "WidgetThrowOnSaveTest"
   
   create widget "Test" as "com.livecode.lcs_tests.core.widgetthrow"

   TestAssertErrorDialog "error dialog when widget throws in OnCreate", \
      "EE_EXTENSION_ERROR_DOMAIN"

   delete stack "WidgetThrowOnSaveTest"
end TestWidgetThrowInOnCreate

on TestWidgetRetainRep
   create stack "WidgetRetainRepTest"
   set the defaultStack to "WidgetRetainRepTest"

   local tWidget
   put "com.livecode.lcs_tests.core.widget_save" into tWidget["$kind"]
   put uuid() into tWidget["$state"]["info"]
   import widget from array tWidget

   local tOut
   export widget 1 to array tOut
   TestAssert "Rep retained in export on failed bind", tOut["$state"]["info"] is tWidget["$state"]["info"]
   
   local tPath
   put the tempName into tPath
   save stack "WidgetRetainRepTest" as tPath
   delete stack "WidgetRetainRepTest"
   
   TestLoadAuxiliaryExtension "_widget_save"
   
   go stack tPath
   
   local tInfo
   put the savedInfo of widget 1 of stack "WidgetRetainRepTest" into tInfo
   TestAssert "Rep retained in save on failed bind", tInfo is tWidget["$state"]["info"]
   
   delete stack "WidgetRetainRepTest"
   delete file tPath
end TestWidgetRetainRep

on TestWidgetDeleteUndo
   -- ensure the extension is not already loaded
   if "com.livecode.lcs_tests.core.widget_save" is \
            among the lines of the loadedExtensions then
      unload extension "com.livecode.lcs_tests.core.widget_save"
   end if

   create stack "WidgetDeleteUndo"
   set the defaultStack to "WidgetDeleteUndo"

   local tWidget
   put "com.livecode.lcs_tests.core.widget_save" into tWidget["$kind"]
   put uuid() into tWidget["$state"]["info"]
   import widget from array tWidget

   select widget 1
   delete
   undo

   local tOut
   export widget 1 to array tOut
   TestAssert "Undo on deleted unbound extension retains rep", tOut["$state"]["info"] is tWidget["$state"]["info"]
   
   select widget 1
   delete

   TestLoadAuxiliaryExtension "_widget_save"
   undo
   TestAssert "Undo on deleted unbound extension rebinds and retains rep", the savedInfo of widget 1 is tWidget["$state"]["info"]
   
   select widget 1
   delete
   undo -- replace
   TestAssert "Undo on deleted bound extension rebinds and retains rep", the savedInfo of widget 1 is tWidget["$state"]["info"]
   
   undo -- delete
   undo -- replace
   TestAssert "Undo delete/replace on deleted bound extension rebinds and retains rep", the savedInfo of widget 1 is tWidget["$state"]["info"]
   
   delete stack "WidgetDeleteUndo"
end TestWidgetDeleteUndo

on TestExportWidgetOfKindNotLoaded
   create stack "WidgetNotLoadedExportTest"
   set the defaultStack to "WidgetNotLoadedExportTest"

   -- A widget whose kind is not loaded has no implementation, and one
   -- made by script has no saved state either: exporting it crashed.
   create widget "Test" as "com.livecode.lcs_tests.core.notloaded"

   local tArray
   export widget "Test" to array tArray
   TestAssert "export of a widget whose kind is not loaded keeps its kind", \
         tArray["$kind"] is "com.livecode.lcs_tests.core.notloaded"
   TestAssert "export of a widget whose kind is not loaded has no state", \
         tArray["$state"] is empty

   delete stack "WidgetNotLoadedExportTest"
end TestExportWidgetOfKindNotLoaded

on TestWidgetLoadedDarkKeepsCardControls
   -- The appAppearance makes a stack dark on Windows and macOS; on Linux
   -- the GTK theme decides, and there is none without a user interface
   if the platform is "Linux" then
      TestSkip "a widget in a group loaded in a dark stack", "the GTK theme decides the appearance on Linux"
      exit TestWidgetLoadedDarkKeepsCardControls
   end if

   TestLoadAuxiliaryExtension "_widget_font"

   -- A widget that looks up its font when it is created, in a group with
   -- a control after it, and a control after the group
   create stack "WidgetDarkLoadTest"
   set the defaultStack to "WidgetDarkLoadTest"
   create button "Before"
   create widget "Font" as "com.livecode.lcs_tests.core.widget_font"
   create button "After"
   group button "Before" and widget "Font" and button "After"
   create button "Last"
   TestAssert "the stack has its controls before it is saved", \
         the number of controls of card 1 of stack "WidgetDarkLoadTest" is 5

   local tPath
   put the tempName into tPath
   save stack "WidgetDarkLoadTest" as tPath
   delete stack "WidgetDarkLoadTest"

   -- Loaded dark: the widget's font was looked up while the card's other
   -- controls were not loaded yet, through the group's controls, which
   -- counted the card's layers and took every control it could not find
   -- off the card (MCGroup::getcontrols, MCCard::clean)
   local tAppearance
   put the appAppearance into tAppearance
   set the appAppearance to "dark"
   local tCount
   put the number of controls of card 1 of stack tPath into tCount
   set the appAppearance to tAppearance
   TestAssert "a group with a widget, loaded dark, keeps the card's controls", tCount is 5
   local tSize
   put the fontSizeAtCreate of widget "Font" of stack "WidgetDarkLoadTest" into tSize
   TestAssert "the widget looked up its font when it was loaded", tSize is a number and tSize > 0

   delete stack "WidgetDarkLoadTest"
   delete file tPath
end TestWidgetLoadedDarkKeepsCardControls
