script "TestPluginSettingsReadOnly"
-- OXT-Beyond: Plugin Settings in an install for all users (README
-- limitation 11). A plugin's settings (its cREVLoadInfo) are saved by
-- saving the plugin's own stack, which a standard user cannot do in the
-- read-only program folder of such an install, so they were lost.
-- revIDESavePluginSettings (ide/Toolset/libraries/revidelibrary.8.livecodescript)
-- saves the stack as before, and only when that fails keeps the settings
-- in the user's preferences, from which revIDEApplyPluginSettings puts
-- them back into the stack when the IDE loads it. Where the stack can be
-- saved, nothing changes but that settings kept earlier are dropped.
--
-- The IDE library cannot be loaded by itself here (it has syntax only the
-- development engine compiles), so its handlers that these use are copied
-- from its file into a stack of their own, run with a stand-in for the
-- IDE's preferences stack and the other handlers of the IDE they call.

constant kPlugin = "TestPluginSettingsPlugin"
constant kStubs = "TestPluginSettingsStubs"
constant kSet = "cOXTPluginSettings"
constant kLib = "TestPluginSettingsLibrary"
constant kHandlers = "revIDEPluginSettingsSaved,revIDEApplyPluginSettings,revIDESavePluginSettings,revIDEGetPreferenceOfSet,revIDESetPreferenceOfSet"

local sFolder, sPath, sPrefsFound, sPrefsSet

-- The handlers pNames (and the constant kPluginSettingsSet) of the IDE
-- library's file, as a script
private function __LibraryHandlers pNames
   local tText, tScript, tIn, tName
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & \
         "/Toolset/libraries/revidelibrary.8.livecodescript"), "UTF-8") into tText
   -- A Windows checkout's file has CR LF line ends
   replace numToCodepoint(13) & numToCodepoint(10) with numToCodepoint(10) in tText
   put false into tIn
   repeat for each line tLine in tText
      if tIn then
         put tLine & return after tScript
         if word 1 of tLine is "end" and word 2 of tLine is tName then
            put false into tIn
         end if
      else if word 1 of tLine is "constant" and word 2 of tLine is "kPluginSettingsSet" then
         put tLine & return after tScript
      else if word 1 of tLine is among the items of "on,function,command" and \
            word 2 of tLine is among the items of pNames then
         put word 2 of tLine into tName
         put tLine & return after tScript
         put true into tIn
      end if
   end repeat
   return tScript
end __LibraryHandlers

on TestSetup
   TestSkipIfNot "ide"
   TestSkipIfNot "write"
   put there is a stack "revPreferences" into sPrefsFound
   if not sPrefsFound then
      create invisible stack "revPreferences"
   end if
   put the customProperties[kSet] of stack "revPreferences" into sPrefsSet
   set the customProperties[kSet] of stack "revPreferences" to empty
   create invisible stack kStubs
   set the script of stack kStubs to "on revInternal__SavePreferences" & return & \
         "end revInternal__SavePreferences" & return & \
         "on ideMessageSendWithParameters" & return & \
         "end ideMessageSendWithParameters" & return & \
         "function revIDEStackFileVersion pStackFile" & return & \
         "return the stackFileVersion" & return & \
         "end revIDEStackFileVersion"
   start using stack kStubs
   
   put specialFolderPath("temporary") & "/oxt-plugin-settings-" & the milliseconds into sFolder
   create folder sFolder
   -- The library's handlers, in a script-only stack (whose script is not
   -- limited as a script set by a standalone engine is)
   put textEncode("script " & quote & kLib & quote & return & \
         __LibraryHandlers(kHandlers), "UTF-8") into url ("binfile:" & sFolder & "/lib.livecodescript")
   get the long id of stack (sFolder & "/lib.livecodescript")
   put sFolder & "/" & kPlugin & ".livecode" into sPath
   create invisible stack kPlugin
   set the cREVLoadInfo["load"] of stack kPlugin to "chosen"
   set the cREVLoadInfo["mode"] of stack kPlugin to "palette"
   set the fileName of stack kPlugin to sPath
   save stack kPlugin
   delete stack kPlugin
end TestSetup

on TestTeardown
   if sPath is not empty and there is a folder sFolder then
      __MakeWritable
   end if
   if sPath is not empty and there is a file sPath then
      delete file sPath
   end if
   if sPath is not empty and there is a file (sPath & "~") then
      delete file (sPath & "~")
   end if
   if there is a stack kLib then
      delete stack kLib
   end if
   if sFolder is not empty and there is a file (sFolder & "/lib.livecodescript") then
      delete file (sFolder & "/lib.livecodescript")
   end if
   if sFolder is not empty and there is a folder sFolder then
      delete folder sFolder
   end if
   if there is a stack kPlugin then
      delete stack kPlugin
   end if
   if kStubs is among the lines of the stacksInUse then
      stop using stack kStubs
   end if
   if there is a stack kStubs then
      delete stack kStubs
   end if
   if there is a stack "revPreferences" then
      if sPrefsFound then
         set the customProperties[kSet] of stack "revPreferences" to sPrefsSet
      else
         delete stack "revPreferences"
      end if
   end if
end TestTeardown

private command __MakeReadOnly
   if the platform is "Win32" then
      get shell("attrib +r " & quote & revWindowsPath(sPath) & quote)
   else
      -- The folder too, as the program folder of an install for all
      -- users is: with only the file read-only, the engine's save
      -- (which renames the file to a backup and writes a new one) works
      -- where the platform lets it rename a read-only file, as macOS does
      get shell("chmod a-w " & quote & sPath & quote & " " & quote & sFolder & quote)
   end if
end __MakeReadOnly

private command __MakeWritable
   if the platform is "Win32" then
      get shell("attrib -r " & quote & revWindowsPath(sPath) & quote)
   else
      get shell("chmod u+w " & quote & sFolder & quote & " " & quote & sPath & quote)
   end if
end __MakeWritable

private function revWindowsPath pPath
   replace slash with backslash in pPath
   return pPath
end revWindowsPath

-- Whether this process can still write the plugin's file (as root can,
-- whatever its permissions)
private function __CanWrite
   open file sPath for update
   if the result is empty then
      close file sPath
      return true
   end if
   if the platform is not "Win32" then
      -- Nor a file of its own in the folder
      local tProbe
      put sFolder & "/probe" into tProbe
      open file tProbe for write
      if the result is empty then
         close file tProbe
         delete file tProbe
         return true
      end if
   end if
   return false
end __CanWrite

-- What the preferences keep for the plugin, or with pAll all they keep
private function __Saved pAll
   local tSet
   put the customProperties[kSet] of stack "revPreferences" into tSet
   if pAll then
      return tSet
   end if
   return tSet[sPath]
end __Saved

-- The plugin's settings as its file has them
private function __LoadInFile pKey
   if there is a stack kPlugin then
      delete stack kPlugin
   end if
   local tValue
   put the cREVLoadInfo[pKey] of stack sPath into tValue
   return tValue
end __LoadInFile

on TestLibraryHandlersFound
   -- Each handler the tests run was found in the library's file
   local tScript
   put __LibraryHandlers(kHandlers) into tScript
   repeat for each item tName in kHandlers
      TestAssert "the library has" && tName, ("end" && tName) is among the lines of tScript
   end repeat
end TestLibraryHandlersFound

on TestWritableStackIsSaved
   -- As before: the setting goes into the plugin's own file
   set the cREVLoadInfo["load"] of stack sPath to "startup"
   dispatch "revIDESavePluginSettings" to stack kLib with sPath
   TestAssert "a writable plugin's settings are saved in its stack", the result is empty
   TestAssert "nothing is kept in the preferences", __Saved(true) is empty
   TestAssert "the file has the new setting", __LoadInFile("load") is "startup"
end TestWritableStackIsSaved

on TestWritableStackDropsKeptSettings
   -- Settings kept while the file could not be saved go once it can be
   local tKept
   put "startup" into tKept["load"]
   local tSet
   put arrayEncode(tKept) into tSet[sPath]
   set the customProperties[kSet] of stack "revPreferences" to tSet
   set the cREVLoadInfo["load"] of stack sPath to "shutdown"
   dispatch "revIDESavePluginSettings" to stack kLib with sPath
   TestAssert "the stack is saved", the result is empty
   TestAssert "the kept settings are dropped", __Saved() is empty
   TestAssert "the file has the new setting", __LoadInFile("load") is "shutdown"
end TestWritableStackDropsKeptSettings

on TestNoKeptSettingsChangeNothing
   -- With nothing kept, applying leaves the stack's own settings alone
   get the long id of stack sPath
   dispatch "revIDEApplyPluginSettings" to stack kLib with sPath
   TestAssert "the stack's own setting stays", the cREVLoadInfo["load"] of stack sPath is "chosen"
   TestAssert "the stack's own mode stays", the cREVLoadInfo["mode"] of stack sPath is "palette"
end TestNoKeptSettingsChangeNothing

on TestReadOnlyStackKeepsSettings
   __MakeReadOnly
   if __CanWrite() then
      TestSkip "a read-only plugin's settings are kept", "this process can write a read-only file (root?)"
      exit TestReadOnlyStackKeepsSettings
   end if
   
   set the cREVLoadInfo["load"] of stack sPath to "startup"
   set the cREVLoadInfo["inMenu"] of stack sPath to true
   local tError, tResult
   try
      dispatch "revIDESavePluginSettings" to stack kLib with sPath
      put the result into tResult
   catch tError
   end try
   TestDiagnostic tError
   TestAssert "saving a read-only plugin's settings throws no error", tError is empty
   TestAssert "they are kept in the preferences", tResult is "preferences"
   
   local tKept
   if __Saved() is not empty then
      put arrayDecode(__Saved()) into tKept
   end if
   TestAssert "the preferences keep the new setting", tKept["load"] is "startup"
   TestAssert "the preferences keep the others", tKept["mode"] is "palette" and tKept["inMenu"] is true
   
   -- The file is unchanged; loaded again, the stack gets the kept settings
   TestAssert "the read-only file is unchanged", __LoadInFile("load") is "chosen"
   dispatch "revIDEApplyPluginSettings" to stack kLib with sPath
   TestAssert "the stack gets the kept setting", the cREVLoadInfo["load"] of stack sPath is "startup"
   TestAssert "and the others", the cREVLoadInfo["inMenu"] of stack sPath is true and \
         the cREVLoadInfo["mode"] of stack sPath is "palette"
end TestReadOnlyStackKeepsSettings
