script "oxt_ide_appearance_check"
-- Headless check of the IDE's appearance preferences (revidelibrary:
-- revIDEIsDark, revIDEApplyAppearance and the helpers around them, and the
-- first-install defaults of home.livecodescript).
--
-- Run it with a development engine, without the IDE, on any platform:
--
--    OXT_CHECK_ROOT=<layout> OXT-Beyond.exe -ui tools\ci\ide-appearance-check.livecodescript
--    OXT_CHECK_ROOT=<layout> LiveCode-Community -ui tools/ci/ide-appearance-check.livecodescript
--
-- tools/ci/ide-contrast-check.ps1 runs it after the contrast check, with
-- the same engine and layout. OXT_CHECK_ROOT is an installed layout or the
-- repository's ide folder (the folder with Toolset).
--
-- It loads the libraries the way the IDE does (messages locked, so no
-- library initialisation runs), makes a preferences stack in memory with
-- home's revInternal__ResetPreferences, and checks:
--    - the first-install defaults: cIDEAppearance and cStackAppearance
--      "light", cMakeRevMenuBarStandard true;
--    - Preferences > Appearance (revIDEPrefsAppearanceUI, on a stand-in
--      card): both option menus with their labels, on the stored
--      preferences, and made once when the card opens again;
--    - on an engine without the appearance properties (such as the release
--      engines before them): revIDEIsDark() follows the systemAppearance,
--      the View menu's Appearance items are disabled, and
--      revIDEApplyAppearance changes nothing, in particular sets no custom
--      property named stackAppearance on any stack;
--    - on an engine with them: with the IDE dark and the user's stacks
--      light, an IDE stack (named rev...) and the home stack get the
--      stackAppearance "dark", a user stack keeps "" and the appAppearance
--      is "light"; revIDEIsDark() becomes true, ideAppearanceChanged is
--      sent once, and the rows of the dataView lists (the Extension
--      Manager, the Project Browser) get their dark colour; "Same as the
--      IDE" gives the appAppearance the IDE's value; the systemAppearance
--      does not change. On Linux, where GTK decides every effective value,
--      only the stored values are checked;
--    - on any engine, the refresh after a change of the IDE's appearance
--      (the test override of revIDEIsDark stands for one) sends
--      ideAppearanceChanged once per change and gives the dataView rows
--      their colours in the new appearance; the refresh after the
--      system's setting changed (the front script's
--      systemAppearanceChanged) is sent once for several calls, and runs.
--
-- Output: one CHECK line per check ("CHECK <name> | ok" or
-- "CHECK <name> | FAILED <detail>"), INFO lines and a SUMMARY line.
-- Exit code: 0 when every check passed, 1 when one failed, 2 when the
-- check could not run.

global gREVAppearanceOverride

local sChecks, sFailed, sAppearanceMessages

on startup
   local tRoot, tHas, tMenu, tBefore, tRows, tSystem, tCore, tError
   set the lockMessages to true
   -- The IDE compiles its scripts without explicit variables
   set the explicitVariables to false
   put 0 into sChecks
   put 0 into sFailed
   put 0 into sAppearanceMessages

   put $OXT_CHECK_ROOT into tRoot
   replace "\" with "/" in tRoot
   if the last char of tRoot is "/" then delete the last char of tRoot
   write "INFO version=" & the version & " build=" & the buildNumber & " platform=" & the platform & return to stdout
   if tRoot is empty or there is not a folder (tRoot & "/Toolset") then
      fatal "OXT_CHECK_ROOT is not a layout with a Toolset folder: " & tRoot
   end if
   write "INFO root=" & tRoot & return to stdout

   try
      repeat for each item tRel in "Toolset/libraries/revinitialisationlibrary.livecodescript,Toolset/libraries/revcommonlibrary.livecodescript,Toolset/libraries/revidelibrary.8.livecodescript,Toolset/home.livecodescript"
         if there is not a file (tRoot & "/" & tRel) then throw "not found: " & tRoot & "/" & tRel
         start using stack (tRoot & "/" & tRel)
         write "INFO library " & tRel & return to stdout
      end repeat
      -- The preferences stack of a first install, as home makes it
      create invisible stack "revPreferences"
      set the defaultStack to the short name of this stack
      revInternal__ResetPreferences
   catch tError
      fatal oneLine(tError)
   end try
   -- IDE messages are dispatched from here on
   set the lockMessages to false

   check "default cIDEAppearance", the cIDEAppearance of stack "revPreferences" is "light", the cIDEAppearance of stack "revPreferences"
   check "default cStackAppearance", the cStackAppearance of stack "revPreferences" is "light", the cStackAppearance of stack "revPreferences"
   check "default cMakeRevMenuBarStandard", the cMakeRevMenuBarStandard of stack "revPreferences" is true, the cMakeRevMenuBarStandard of stack "revPreferences"
   check "unknown preference value is light", revIDEAppearancePreference("ide") is "light" and revIDEAppearancePreference("stacks") is "light", \
         revIDEAppearancePreference("ide") & "," & revIDEAppearancePreference("stacks")

   -- Preferences > Appearance: revPreferencesGUI is a binary stack whose
   -- card "Appearance" calls revIDEPrefsAppearanceUI in its preOpenCard; a
   -- stand-in card gets the same controls. The second call is the card
   -- opened again: the controls are updated, not made twice. The handler
   -- colours its note with revIDEColor("text_muted"), which comes from
   -- revCore's ideColorGet, so revCore's script is a backscript meanwhile
   -- (loaded with messages locked, as ide-contrast-check does). An error
   -- is a failed check: uncaught, the -ui engine would wait, not quit
   create invisible stack "oxtAppearanceCheckPrefs"
   set the name of card 1 of stack "oxtAppearanceCheckPrefs" to "Appearance"
   put tRoot & "/Toolset/palettes/revCore.8.livecode" into tCore
   try
      set the lockMessages to true
      insert the script of stack tCore into back
      revIDEPrefsAppearanceUI the long id of card "Appearance" of stack "oxtAppearanceCheckPrefs"
      revIDEPrefsAppearanceUI the long id of card "Appearance" of stack "oxtAppearanceCheckPrefs"
      put empty into tError
   catch tError
   end try
   try
      remove the script of stack tCore from back
   catch tIgnored
   end try
   set the lockMessages to false
   check "Preferences > Appearance: runs", tError is empty, tError
   check "Preferences > Appearance: IDE label", prefsText("oxtAppearance_ide_label") is "IDE appearance:", prefsText("oxtAppearance_ide_label")
   check "Preferences > Appearance: stacks label", prefsText("oxtAppearance_stacks_label") is "Your stacks:", prefsText("oxtAppearance_stacks_label")
   check "Preferences > Appearance: note", prefsText("oxtAppearance_note") is not empty and not (prefsText("oxtAppearance_note") begins with "(error"), prefsText("oxtAppearance_note")
   check "Preferences > Appearance: IDE menu on its preference", prefsMenuHistory("oxtAppearance_ide") is 1, prefsMenuHistory("oxtAppearance_ide")
   check "Preferences > Appearance: stacks menu on its preference", prefsMenuHistory("oxtAppearance_stacks") is 1, prefsMenuHistory("oxtAppearance_stacks")
   check "Preferences > Appearance: menus enabled as the engine allows", prefsEnabled("oxtAppearance_ide") is (revIDEEngineHasAppearance() and the platform is not "Linux"), \
         prefsEnabled("oxtAppearance_ide") && revIDEEngineHasAppearance() && the platform
   check "Preferences > Appearance: controls made once", the number of controls of card "Appearance" of stack "oxtAppearanceCheckPrefs" is 5, \
         the number of controls of card "Appearance" of stack "oxtAppearanceCheckPrefs"

   -- The stacks the IDE sorts: an IDE stack by its name, and a user stack
   create invisible stack "revAppearanceCheckIDE"
   create invisible stack "oxtAppearanceCheckUser"
   create invisible stack "oxtAppearanceCheckUserSub"
   set the mainStack of stack "oxtAppearanceCheckUserSub" to "oxtAppearanceCheckUser"
   revIDESubscribe "ideAppearanceChanged"

   put revIDEEngineHasAppearance() into tHas
   write "INFO engine has the appearance properties: " & tHas & return to stdout
   put the systemAppearance into tSystem

   if not tHas then
      -- As before the appearance properties: the system decides
      check "revIDEIsDark follows the systemAppearance", revIDEIsDark() is (tSystem is "dark"), revIDEIsDark() && tSystem
      put revIDEAppearanceMenu() into tMenu
      check "Appearance menu items disabled", menuItemsDisabled(tMenu), tMenu
      revIDESetAppearance "ide", "dark"
      revIDESetAppearance "stacks", "light"
      check "stored cIDEAppearance", the cIDEAppearance of stack "revPreferences" is "dark", the cIDEAppearance of stack "revPreferences"
      check "no stackAppearance custom property", noCustomAppearance(), the customKeys of stack "revAppearanceCheckIDE"
      check "revIDEIsDark unchanged by the preference", revIDEIsDark() is (tSystem is "dark"), revIDEIsDark()
      check "no ideAppearanceChanged", sAppearanceMessages is 0, sAppearanceMessages
   else
      -- The starting point: everything light, the refresh recorded
      revIDESetAppearance "ide", "light"
      revIDESetAppearance "stacks", "light"
      put 0 into sAppearanceMessages
      put revIDEColor("dataView_rowColor") into tRows
      check "IDE light: revIDEIsDark", revIDEIsDark() is false or the platform is "Linux", revIDEIsDark()

      revIDESetAppearance "ide", "dark"
      check "IDE dark: IDE stack", stackAppearanceOf("revAppearanceCheckIDE") is "dark", stackAppearanceOf("revAppearanceCheckIDE")
      check "IDE dark: home stack", stackAppearanceOf("home") is "dark", stackAppearanceOf("home")
      check "IDE dark: user stack", stackAppearanceOf("oxtAppearanceCheckUser") is empty, stackAppearanceOf("oxtAppearanceCheckUser")
      check "IDE dark: user substack", stackAppearanceOf("oxtAppearanceCheckUserSub") is empty, stackAppearanceOf("oxtAppearanceCheckUserSub")
      check "IDE dark: appAppearance", currentAppAppearance() is "light", currentAppAppearance()
      check "IDE dark: systemAppearance unchanged", the systemAppearance is tSystem, the systemAppearance
      put revIDEAppearanceMenu() into tMenu
      if the platform is "Linux" then
         check "Appearance menu items disabled on Linux", menuItemsDisabled(tMenu), tMenu
      else
         check "IDE dark: revIDEIsDark", revIDEIsDark() is true, revIDEIsDark()
         check "IDE dark: ideAppearanceChanged sent once", sAppearanceMessages is 1, sAppearanceMessages
         check "IDE dark: dataView rows dark", revIDEColor("dataView_rowColor") is not tRows, revIDEColor("dataView_rowColor")
         check "IDE dark: user stack light", effectiveOf("oxtAppearanceCheckUser") is "light", effectiveOf("oxtAppearanceCheckUser")
         check "Appearance menu: IDE Dark checked", tab & "!cIDE: Dark" is among the lines of tMenu, tMenu
         check "Appearance menu items enabled", not menuItemsDisabled(tMenu), tMenu
      end if

      revIDESetAppearance "stacks", "ide"
      check "stacks same as IDE: appAppearance", currentAppAppearance() is "dark", currentAppAppearance()
      check "stacks same as IDE: user stack", stackAppearanceOf("oxtAppearanceCheckUser") is empty, stackAppearanceOf("oxtAppearanceCheckUser")

      revIDESetAppearance "stacks", "light"
      revIDESetAppearance "ide", "light"
      check "IDE light again: IDE stack", stackAppearanceOf("revAppearanceCheckIDE") is "light", stackAppearanceOf("revAppearanceCheckIDE")
      check "IDE light again: appAppearance", currentAppAppearance() is "light", currentAppAppearance()
      if the platform is not "Linux" then
         check "IDE light again: revIDEIsDark", revIDEIsDark() is false, revIDEIsDark()
         check "IDE light again: ideAppearanceChanged sent twice in all", sAppearanceMessages is 2, sAppearanceMessages
         check "IDE light again: dataView rows light", revIDEColor("dataView_rowColor") is tRows, revIDEColor("dataView_rowColor")
      end if
   end if

   -- The refresh itself, on any engine: the test override stands for a
   -- change of the IDE's appearance (as "Follow the System" sees one when
   -- the system's setting changes)
   put 0 into sAppearanceMessages
   put revIDEColor("dataView_rowColor") into tRows
   put "dark" into gREVAppearanceOverride
   __revIDEAppearanceRefresh
   check "refresh to dark: ideAppearanceChanged sent once", sAppearanceMessages is 1, sAppearanceMessages
   check "refresh to dark: dataView rows dark", revIDEColor("dataView_rowColor") is not tRows, revIDEColor("dataView_rowColor")
   __revIDEAppearanceRefresh
   check "refresh without a change: nothing sent", sAppearanceMessages is 1, sAppearanceMessages
   put empty into gREVAppearanceOverride
   __revIDEAppearanceRefresh
   check "refresh back: ideAppearanceChanged sent again", sAppearanceMessages is 2, sAppearanceMessages
   check "refresh back: dataView rows as before", revIDEColor("dataView_rowColor") is tRows, revIDEColor("dataView_rowColor")

   -- The front script's systemAppearanceChanged: Windows sends the change
   -- several times, and the palettes are refreshed once, 100 ms later
   revIDEAppearanceRefreshSoon
   revIDEAppearanceRefreshSoon
   check "appearance refresh sent once", pendingRefreshes() is 1, the pendingMessages
   wait 300 milliseconds with messages
   check "appearance refresh ran", pendingRefreshes() is 0, the pendingMessages

   write "SUMMARY checks=" & sChecks & " failed=" & sFailed & " engine_appearance=" & tHas & return to stdout
   if sFailed > 0 then quit 1
   quit 0
end startup

on ideAppearanceChanged pIsDark
   add 1 to sAppearanceMessages
   write "INFO ideAppearanceChanged " & pIsDark & return to stdout
end ideAppearanceChanged

private command check pName, pPassed, pDetail
   add 1 to sChecks
   if pPassed is true then
      write "CHECK " & pName & " | ok" & return to stdout
   else
      add 1 to sFailed
      write "CHECK " & pName & " | FAILED (" & oneLine(pDetail) & ")" & return to stdout
   end if
end check

private command fatal pMessage
   write "FATAL " & pMessage & return to stdout
   quit 2
end fatal

private function oneLine pText
   replace crlf with " / " in pText
   replace return with " / " in pText
   replace numToCodepoint(13) with " / " in pText
   replace tab with " " in pText
   return pText
end oneLine

-- Every item of the Appearance submenu is disabled ("(" after the tab),
-- separators and the note line aside
private function menuItemsDisabled pMenu
   local tItems
   put 0 into tItems
   repeat for each line tLine in pMenu
      if tLine is tab & "-" then next repeat
      add 1 to tItems
      if char 2 of tLine is not "(" then return false
   end repeat
   return tItems >= 7
end menuItemsDisabled

-- No stack got a custom property named stackAppearance (an engine without
-- the property would set one on "set the stackAppearance")
private function noCustomAppearance
   repeat for each item tStack in "revAppearanceCheckIDE,oxtAppearanceCheckUser,home"
      if "stackAppearance" is among the lines of the customKeys of stack tStack then return false
   end repeat
   return true
end noCustomAppearance

-- How many refreshes of the IDE's appearance are pending
private function pendingRefreshes
   local tCount
   put 0 into tCount
   repeat for each line tMessage in the pendingMessages
      if item 3 of tMessage is "__revIDEAppearanceRefresh" then add 1 to tCount
   end repeat
   return tCount
end pendingRefreshes

-- The text of a field of the stand-in Preferences card
private function prefsText pField
   try
      return the text of field pField of card "Appearance" of stack "oxtAppearanceCheckPrefs"
   catch tError
      return "(error " & oneLine(tError) & ")"
   end try
end prefsText

-- The menuHistory of an option menu of the stand-in Preferences card
private function prefsMenuHistory pButton
   try
      return the menuHistory of button pButton of card "Appearance" of stack "oxtAppearanceCheckPrefs"
   catch tError
      return "(error " & oneLine(tError) & ")"
   end try
end prefsMenuHistory

-- The enabled of an option menu of the stand-in Preferences card
private function prefsEnabled pButton
   try
      return the enabled of button pButton of card "Appearance" of stack "oxtAppearanceCheckPrefs"
   catch tError
      return "(error " & oneLine(tError) & ")"
   end try
end prefsEnabled

private function stackAppearanceOf pStack
   local tValue
   try
      do "put the stackAppearance of stack pStack into tValue"
   catch tError
      return "(error " & oneLine(tError) & ")"
   end try
   return tValue
end stackAppearanceOf

private function effectiveOf pStack
   local tValue
   try
      do "put the effective stackAppearance of stack pStack into tValue"
   catch tError
      return "(error " & oneLine(tError) & ")"
   end try
   return tValue
end effectiveOf

-- Not named appAppearance: on an engine with the property that word is a
-- property token, so appAppearance() would parse as the property and the
-- script would not compile (and -ui would wait instead of quitting)
private function currentAppAppearance
   local tValue
   try
      do "put the appAppearance into tValue"
   catch tError
      return "(error " & oneLine(tError) & ")"
   end try
   return tValue
end currentAppAppearance
