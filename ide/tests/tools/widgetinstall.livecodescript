script "IDEToolsWidgetInstall"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- OXT-Beyond: a widget installed or uninstalled shows, or goes, in the
-- Tools palette at once, in either look (bwmilby, forum, 2026-11-07). The
-- palette's subscription to ideExtensionsChanged was commented out, so
-- only a switch of look or a restart showed it. The Spinner, which no
-- test uses, is unloaded and loaded again as the Extension Manager's
-- uninstall and install do. The IDE tour's step tools-widget-install
-- checks the same on every platform, with a snapshot.

constant kWidget = "com.livecode.widget.spinner"
constant kLibrary = "com.livecode.library.diff"
-- A widget written and compiled here, as the Extension Builder does
constant kBuilt = "org.openxtalk.test.palettewidget"

-- The look, and the classic look's Show Sections setting (revTools_show)
-- as each test found them
local sLook, sShow

on TestSetup
   put revIDEGetPreference("revTools_look") into sLook
   put revIDEGetPreference("revTools_show") into sShow
   revIDEOpenPalette "tools"
   __Settle
end TestSetup

on TestTeardown
   if revIDEExtensionProperty(kBuilt, "status") is not empty then
      revIDEExtensionUninstall kBuilt
   end if
   if revIDEExtensionProperty(kWidget, "status") is not "installed" then
      revIDEExtensionReload kWidget
   end if
   if revIDEExtensionProperty(kLibrary, "status") is "unloaded" then
      revIDEExtensionReload kLibrary
   end if
   __Settle
   if revIDEGetPreference("revTools_look") is not sLook then
      revIDESetPreference "revTools_look", sLook
   end if
   if sShow is not empty and revIDEGetPreference("revTools_show") is not sShow then
      revIDESetPreference "revTools_show", sShow
   end if
   if there is not a stack "revTools" or the mode of stack "revTools" is 0 then
      revIDEOpenPalette "tools"
   end if
   __Settle
end TestTeardown

-- Waits for the extension library's batch of changes, and the
-- ideExtensionsChanged it sends, to be over (at most 10 seconds)
private command __Settle
   local tLine, tWaiting
   repeat 100 times
      wait 100 milliseconds with messages
      put false into tWaiting
      repeat for each line tLine in the pendingMessages
         if item 3 of tLine is among the items of "doExtensionsChanged,doExtensionsChangedBatch" then
            put true into tWaiting
         end if
      end repeat
      if not tWaiting then exit repeat
   end repeat
   wait 100 milliseconds with messages
end __Settle

-- The long id of the palette's control named pName, or empty
private function __Tile pName
   local tCard, i
   if there is not a stack "revTools" then return empty
   put the long id of card 1 of stack "revTools" into tCard
   repeat with i = 1 to the number of controls of tCard
      if the short name of control i of tCard is pName then return the long id of control i of tCard
   end repeat
   return empty
end __Tile

-- The classic look shows widgets only when its Show Sections setting
-- lists them, and a fresh profile's does not (Home's default is
-- classic,graphictools,runedit,graphic,paint): the tests show them, and
-- TestTeardown gives the setting back
private command __SetLook pLook
   local tShow
   if revIDEGetPreference("revTools_look") is not pLook then
      revIDESetPreference "revTools_look", pLook
      __Settle
   end if
   put revIDEGetPreference("revTools_show") into tShow
   if pLook is "classic" and tShow is not empty and "widget" is not among the items of tShow then
      revIDESetPreference "revTools_show", "widget," & tShow
      __Settle
   end if
end __SetLook

-- The tile a look gives the widget, named by its id in either look
private command __CheckLook pLook, pTile
   if revIDEExtensionProperty(kWidget, "status") is not "installed" then
      TestSkip pLook && "look: the Spinner", "it is not loaded"
      exit __CheckLook
   end if
   __SetLook pLook
   TestAssert pLook && "look: the Spinner is on the palette to start with", __Tile(pTile) is not empty

   revIDEExtensionUnload kWidget
   __Settle
   TestAssert pLook && "look: a widget uninstalled goes from the palette at once", __Tile(pTile) is empty

   revIDEExtensionReload kWidget
   __Settle
   TestDiagnostic pLook && "look: reloaded," && revIDEExtensionProperty(kWidget, "status") && \
         revIDEExtensionProperty(kWidget, "error")
   TestAssert pLook && "look: the Spinner loads again", revIDEExtensionProperty(kWidget, "status") is "installed"
   TestAssert pLook && "look: a widget installed shows on the palette at once", __Tile(pTile) is not empty
end __CheckLook

on TestModernLook
   dispatch function "tmIsModern" to stack "revTools"
   if it is not "handled" then
      TestSkip "modern look", "this palette has no modern look"
      exit TestModernLook
   end if
   __CheckLook "modern", kWidget
end TestModernLook

on TestClassicLook
   __CheckLook "classic", kWidget
end TestClassicLook

-- A palette closed and opened again shows what changed while it was
-- closed (it hears nothing then)
on TestWhileClosed
   if revIDEExtensionProperty(kWidget, "status") is not "installed" then
      TestSkip "while closed", "the Spinner is not loaded"
      exit TestWhileClosed
   end if
   __SetLook "classic"
   close stack "revTools"
   revIDEExtensionUnload kWidget
   __Settle
   revIDEOpenPalette "tools"
   __Settle
   TestAssert "a widget uninstalled while the palette was closed is gone when it opens", __Tile(kWidget) is empty

   close stack "revTools"
   revIDEExtensionReload kWidget
   __Settle
   revIDEOpenPalette "tools"
   __Settle
   TestAssert "a widget installed while the palette was closed is there when it opens", __Tile(kWidget) is not empty
end TestWhileClosed

-- Nothing that changes no widget makes the palette again: a library
-- loaded again leaves the very same tile
on TestLibraryLeavesPalette
   local tBefore
   if revIDEExtensionProperty(kLibrary, "status") is not "installed" then
      TestSkip "a library loaded again", kLibrary && "is not loaded"
      exit TestLibraryLeavesPalette
   end if
   __SetLook "classic"
   put __Tile(kWidget) into tBefore
   revIDEExtensionUnload kLibrary
   revIDEExtensionReload kLibrary
   __Settle
   TestAssert "a library loaded again leaves the palette as it was", \
         tBefore is not empty and __Tile(kWidget) is tBefore
   dispatch function "toolsWidgetsChanged" to stack "revTools"
   TestAssert "and the palette knows its widgets are those it shows", the result is false
end TestLibraryLeavesPalette

-- The test widget's folder, compiled as the Extension Builder compiles a
-- folder it opens (revIDEDeveloperExtension), or empty when it did not
-- compile (an IDE with no lc-compile beside it)
private function __BuiltWidgetFolder
   local tFolder, tSource, tDetails, tError
   put specialFolderPath("temporary") & "/oxt_test_palettewidget" into tFolder
   if there is not a folder tFolder then create folder tFolder
   put "widget" && kBuilt & return & \
         "use com.livecode.canvas" & return & \
         "use com.livecode.widget" & return & \
         "metadata title is " & quote & "Palette Test Widget" & quote & return & \
         "metadata author is " & quote & "OXT-Beyond tests" & quote & return & \
         "metadata version is " & quote & "1.0.0" & quote & return & \
         "metadata svgicon is " & quote & "M0,0L10,0L10,10L0,10Z" & quote & return & \
         "public handler OnPaint()" & return & \
         "   fill rectangle [0, 0, 10, 10] on this canvas" & return & \
         "end handler" & return & \
         "end widget" & return into tSource
   put textEncode(tSource, "UTF-8") into URL ("binfile:" & tFolder & "/palettewidget.lcb")
   try
      put revIDEDeveloperExtension(tFolder) into tDetails
   catch tError
      return empty
   end try
   if there is not a file (tFolder & "/manifest.xml") then return empty
   if there is not a file (tFolder & slash & revIDEExtensionBytecodeFilename(true)) and \
         there is not a file (tFolder & "/module.lcm") then return empty
   return tFolder
end __BuiltWidgetFolder

-- Brian's own way (bwmilby, forum, 2026-11-07): the Extension Builder's
-- Install button (revIDEDeveloperExtensionInstall) and the Extension
-- Manager's Uninstall (revIDEExtensionUninstall), in each look
on TestBuilderInstallManagerUninstall
   local tFolder, tLook, tTile, tTry
   put __BuiltWidgetFolder() into tFolder
   if tFolder is empty then
      TestSkip "Extension Builder install", "the test widget did not compile (no lc-compile?)"
      exit TestBuilderInstallManagerUninstall
   end if
   local tHasModern
   dispatch function "tmIsModern" to stack "revTools"
   put it is "handled" into tHasModern
   put kBuilt into tTile
   repeat for each item tLook in "modern,classic"
      if tLook is "modern" and not tHasModern then next repeat
      __SetLook tLook
      revIDEDeveloperExtensionInstall tFolder
      repeat with tTry = 1 to 50
         if revIDEExtensionProperty(kBuilt, "status") is "installed" then exit repeat
         wait 100 milliseconds with messages
      end repeat
      __Settle
      TestAssert tLook && "look: the Extension Builder's Install installs it", \
            revIDEExtensionProperty(kBuilt, "status") is "installed"
      TestAssert tLook && "look: a widget installed from the Extension Builder shows on the palette at once", \
            __Tile(tTile) is not empty
      revIDEExtensionUninstall kBuilt
      __Settle
      TestAssert tLook && "look: a widget uninstalled in the Extension Manager goes from the palette at once", \
            __Tile(tTile) is empty
   end repeat
end TestBuilderInstallManagerUninstall
