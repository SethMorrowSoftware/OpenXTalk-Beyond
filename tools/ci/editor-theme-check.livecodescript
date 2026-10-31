script "editor-theme-check"
-- Run with a development engine and -ui. Uses isolated preference stubs;
-- no user preferences are loaded or written.
local sDark, sPrefs, sFailed
on startup
   create invisible stack "revPreferences"
   create invisible stack "revSETemplate"
   local tRoot
   put the filename of me into tRoot
   set the itemDelimiter to slash
   delete item -3 to -1 of tRoot
   start using stack (tRoot & "/ide/Toolset/palettes/script editor/behaviors/revseutilities.livecodescript")
   put false into sDark
   sePrefInit
   check sePrefGet("editor,backgroundcolor"), "255,255,255", "light background"
   check sePrefGet("editor,textcolor"), "0,0,0", "light text"
   check (sePrefGet("colorization,config") contains "class identifier none 0,0,0"), true, "light syntax"
   put true into sDark
   sePrefInit
   check sePrefGet("editor,backgroundcolor"), "30,30,30", "dark background"
   check sePrefGet("editor,textcolor"), "238,238,238", "dark text"
   check sePrefGet("editor,debugBackgroundcolor"), "30,30,30", "dark debugger background"
   check (sePrefGet("colorization,config") contains "class identifier none 238,238,238"), true, "dark syntax"
   put "12,34,56" into sPrefs["cScriptEditor,editor,backgroundcolor"]
   sePrefInit
   check sePrefGet("editor,backgroundcolor"), "12,34,56", "keep custom background"
   check sePrefGet("colorization,scheme"), "default", "keep light scheme preference"
   put "oxt lite dark" into sPrefs["cScriptEditor,colorization,schemedark"]
   sePrefInit
   local tExpected
   seColorizationLoadScheme "oxt lite dark", tExpected
   check sePrefGet("colorization,config"), tExpected["colorization,config"], "honor schemedark"
   put false into sDark
   sePrefInit
   check (sePrefGet("colorization,config") contains "class identifier none 0,0,0"), true, "restore light scheme"
   -- Saving the mode must stay readable by older builds and plugins.
   sePrefSet "editor,backgroundcolor", "default"
   sePrefSet "editor,debugBackgroundcolor", "default"
   sePrefSave
   check sPrefs["cScriptEditor,editor,backgroundcolor"], empty, "save compatible editor default"
   check sPrefs["cScriptEditor,editor,debugBackgroundcolor"], empty, "save compatible debugger default"
   sePrefInit
   check sePrefGet("editor,backgroundcolor"), "255,255,255", "reload empty as light default"
   sePrefSet "editor,backgroundcolor", "12,34,56"
   sePrefSave
   check sPrefs["cScriptEditor,editor,backgroundcolor"], "12,34,56", "save explicit RGB unchanged"

   -- Early Beyond builds (0.2.1 to 0.2.3) saved a second, dark scheme
   -- whose default, One Dark Pro, no longer exists. A name the editor
   -- does not know loaded no colours, and the engine drew every word
   -- black: black on black in dark mode, with Vibrant ignored
   -- (tperry2x, openxtalk.org p=25776).
   local tVibrant, tDarkMode
   seColorizationLoadScheme "vibrant", tVibrant
   seColorizationLoadScheme "dark mode", tDarkMode
   put true into sDark
   put "vibrant" into sPrefs["cScriptEditor,colorization,scheme"]
   put "0,0,0" into sPrefs["cScriptEditor,editor,backgroundcolor"]
   put "one dark pro" into sPrefs["cScriptEditor,colorization,schemedark"]
   sePrefInit
   check sePrefGet("colorization,config"), tVibrant["colorization,config"], "a removed dark scheme does not overrule vibrant"
   put empty into sPrefs["cScriptEditor,editor,backgroundcolor"]
   sePrefInit
   check sePrefGet("colorization,config"), tDarkMode["colorization,config"], "a removed dark scheme falls back to dark mode"
   -- A scheme name the editor does not know loads readable colours for
   -- the background it is on, and the saved name is kept.
   put "one dark pro" into sPrefs["cScriptEditor,colorization,scheme"]
   put empty into sPrefs["cScriptEditor,colorization,schemedark"]
   put "0,0,0" into sPrefs["cScriptEditor,editor,backgroundcolor"]
   sePrefInit
   check sePrefGet("colorization,config"), tDarkMode["colorization,config"], "an unknown scheme on a dark background"
   put false into sDark
   put "255,255,255" into sPrefs["cScriptEditor,editor,backgroundcolor"]
   sePrefInit
   check (sePrefGet("colorization,config") contains "class identifier none 0,0,0"), true, "an unknown scheme on a light background"
   check sePrefGet("colorization,scheme"), "one dark pro", "keep an unknown scheme's saved name"
   put true into sDark
   put empty into sPrefs["cScriptEditor,editor,backgroundcolor"]
   sePrefInit
   check sePrefGet("colorization,config"), tDarkMode["colorization,config"], "an unknown scheme following a dark appearance"
   put "default" into sPrefs["cScriptEditor,colorization,scheme"]
   put "12,34,56" into sPrefs["cScriptEditor,editor,backgroundcolor"]
   put false into sDark

   -- Model the real message path: utilities are the editor's behavior,
   -- never a global library for Preferences. A fresh Preferences card and
   -- the Follow menu must work without access to sePrefInit/sePrefGet.
   stop using stack (tRoot & "/ide/Toolset/palettes/script editor/behaviors/revseutilities.livecodescript")
   create invisible stack "revNewScriptEditor"
   set the behavior of stack "revNewScriptEditor" to the long id of stack "revseutilities"
   get the short name of stack (tRoot & "/ide/Toolset/palettes/revpreferencesgui.rev")
   dispatch "sePrefInit" to stack "revPreferencesGUI"
   check it, "unhandled", "utilities are outside Preferences message path"
   revIDESetPreference "cScriptEditor,editor,backgroundcolor", empty
   revIDESetPreference "cScriptEditor,editor,debugBackgroundcolor", empty
   revIDESetPreference "cScriptEditor,colorization,schemedark", empty
   put true into sDark
   dispatch "update" to group "Script Editor" of card "Script Editor" of stack "revPreferencesGUI"
   check the cColor of button "Background Color" of card "Script Editor" of stack "revPreferencesGUI", "30,30,30", "fresh Preferences resolves dark background"
   dispatch "menuPick" to button "Colorization Scheme" of card "Script Editor" of stack "revPreferencesGUI" with "Follow System Appearance"
   check sPrefs["cScriptEditor,editor,backgroundcolor"], empty, "Follow menu saves compatible mode"
   check sPrefs["cScriptEditor,editor,debugBackgroundcolor"], empty, "Follow menu resets debugger mode"
   check the cColor of button "Debug Background Color" of card "Script Editor" of stack "revPreferencesGUI", "30,30,30", "Follow menu resolves debugger swatch"
   put false into sDark
   dispatch "update" to group "Script Editor" of card "Script Editor" of stack "revPreferencesGUI"
   check the cColor of button "Background Color" of card "Script Editor" of stack "revPreferencesGUI", "255,255,255", "Preferences resolves light background"
   revIDESetPreference "cScriptEditor,editor,backgroundcolor", "12,34,56"
   dispatch "update" to group "Script Editor" of card "Script Editor" of stack "revPreferencesGUI"
   check the cColor of button "Background Color" of card "Script Editor" of stack "revPreferencesGUI", "12,34,56", "Preferences preserves explicit RGB"
   -- A scheme picked from the menu is the one shown in light and dark, so
   -- picking it clears the dark scheme an early build saved (p=25776).
   revIDESetPreference "cScriptEditor,colorization,schemedark", "dark mode"
   put true into sDark
   dispatch "menuPick" to button "Colorization Scheme" of card "Script Editor" of stack "revPreferencesGUI" with "vibrant"
   check sPrefs["cScriptEditor,colorization,scheme"], "vibrant", "menu picks vibrant"
   check sPrefs["cScriptEditor,colorization,schemedark"], empty, "picking a scheme clears the old dark scheme"
   check sPrefs["cScriptEditor,editor,backgroundcolor"], "0,0,0", "vibrant's background"
   dispatch "sePrefInit" to stack "revNewScriptEditor"
   dispatch function "sePrefGet" to stack "revNewScriptEditor" with "colorization,config"
   check the result, tVibrant["colorization,config"], "the editor shows vibrant in dark mode after the pick"
   -- The Custom popup makes Custom the scheme the same way.
   revIDESetPreference "cScriptEditor,colorization,schemedark", "dark mode"
   dispatch "defaultAll" to graphic id 1012 of card id 1002 of stack "CustomScriptCol"
   check it, "handled", "Custom popup's defaultAll"
   check sPrefs["cScriptEditor,colorization,scheme"], "Custom", "Custom popup makes Custom the scheme"
   check sPrefs["cScriptEditor,colorization,schemedark"], empty, "Custom clears the old dark scheme"
   put false into sDark
   revIDESetPreference "cScriptEditor,colorization,scheme", "default"
   revIDESetPreference "cScriptEditor,editor,backgroundcolor", "12,34,56"
   revIDESetPreference "cScriptEditor,editor,debugBackgroundcolor", "12,34,56"
   -- Suppress only the popup's UI in memory; exercise its real menuPick.
   local tMenu, tScript, tStart
   put the long id of button "Colorization Scheme" of card "Script Editor" of stack "revPreferencesGUI" into tMenu
   put the script of tMenu into tScript
   put offset("on doCustomPopup", tScript) into tStart
   delete char tStart to -1 of tScript
   put "on doCustomPopup" & return & "end doCustomPopup" after tScript
   set the script of tMenu to tScript
   dispatch "menuPick" to tMenu with "Custom"
   check sPrefs["cScriptEditor,editor,backgroundcolor"], "12,34,56", "opening Custom preserves background"
   check sPrefs["cScriptEditor,colorization,scheme"], "default", "opening Custom preserves active scheme"
   if sFailed then quit 1
   write "PASS editor theme preferences" & return to stdout
   quit
end startup
function revIDEAppearanceIsDark
   return sDark
end revIDEAppearanceIsDark
function revIDEGetPreference pKey
   return sPrefs[pKey]
end revIDEGetPreference
command check pActual, pExpected, pName
   if pActual is not pExpected then
      write "FAIL " & pName & ": " & pActual & return to stdout
      put true into sFailed
   end if
end check

command revIDESetPreference pKey, pValue
   put pValue into sPrefs[pKey]
   set the pKey of stack "revPreferences" to pValue
end revIDESetPreference
function revScriptEditorMain
   return the long id of stack "revNewScriptEditor"
end revScriptEditorMain
function revListScriptEditors
   return empty
end revListScriptEditors
