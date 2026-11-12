script "stack_revPreferencesGUI_card_id_1254"
-- Stack file: ide/Toolset/palettes/revpreferencesgui.rev
-- Object: stack "revPreferencesGUI" > card "Mobile Support" (id 1254)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on preOpenCard
   
   -- PM-2015-02-06: [[ Bug 14422 ]] Removed OSX 10.6 support
   if the platform is not "macos" or revIDEDeployIOSSanitizeSystemVersion() < 100700  then
      set the enabled of group "iOS SDKs" to false
      put empty into field "iOS SDKs"
      set the backgroundColor of graphic "SDK Status" to "gray"
      set the tooltip of graphic "SDK Status" to empty
   else
      set the enabled of group "iOS SDKs" to true      
      put the cMobileSupport["ios.sdks"] of stack "revPreferences" into field "iOS SDKs"
      updateSimulators
      updateSDKs
   end if
   
   -- always show the button to choose a JDK
   set the visible of button "ChooseJDK" to true -- was previously: (the platform is "linux") -- tperry 6-10,2024
   
   set the enabled of group "Android SDK" to true
   put the cMobileSupport["android.sdk"] of stack "revPreferences" into field "Android SDK"
   updateJDK
end preOpenCard

command setIOSSDK pValue
   get the cMobileSupport["ios.sdks"] of stack "revPreferences"
   if pValue is not among the lines of it then
      if it is not empty then
         put return after it
      end if
      put pValue after it
      set the cMobileSupport["ios.sdks"] of stack "revPreferences" to it
      put it into field "iOS SDKs"
      revIDEDeployIOSUpdateSDKs
      updateSimulators
      updateSDKs
   end if
end setIOSSDK

command removeIOSSDK pValues
   set the wholeMatches to true
   get the cMobileSupport["ios.sdks"] of stack "revPreferences"
   repeat for each line tValue in pValues
      if tValue is among the lines of it then
         delete line lineoffset(tValue, it) of it
      end if
   end repeat
   set the cMobileSupport["ios.sdks"] of stack "revPreferences" to it
   put it into field "iOS SDKs"
   revIDEDeployIOSUpdateSDKs
   updateSimulators
   updateSDKs
end removeIOSSDK

command updateSimulators
   get revIDEDeployIOSGetSimulatorVersions()
   if it is empty then
      get "(none)"
   else
      replace return with comma & space in it
   end if
   put "Available simulators: " & it into field "Simulator List"
end updateSimulators

command updateSDKs
   local tTooltip, tAvailableSDKs, tValid
   
   dispatch function "deployCheckLatestSDKIsInstalled" to stack "revDeployLibraryIOS" with tTooltip, tAvailableSDKs
   
   put the result into tValid
   if tValid then
      set the backgroundColor of graphic "SDK Status" to "green"
   else
      set the backgroundColor of graphic "SDK Status" to "red"
   end if
   
   set the tooltip of graphic "SDK Status" to tTooltip   
   put "Available device SDKs: " & tAvailableSDKs into field "SDK List"
end updateSDKs

command setAndroidSDK pValue
   set the cMobileSupport["android.sdk"] of stack "revPreferences" to pValue
   put pValue into field "Android SDK"
   revIDEDeployAndroidInitialize
   updateJDK
end setAndroidSDK

command setJDK pValue
   set the cMobileSupport["android.jdk"] of stack "revPreferences" to pValue
   put pValue into field "JDK Path"
   revIDEDeployAndroidInitialize
   updateJDK
end setJDK

command updateJDK
   get revIDEDeployAndroidGetJDK()
   put it into tJDK
   if tJDK is empty then get "(none)"
   -- OXT-Beyond: no JDK found. The builder's Android tools need JDK 17 (it named Java 8's installers)
   if tJDK is empty then
      put "No JDK found. Install JDK 17, or choose one with the ... button." into cd fld "fmobtip"
      show cd fld "fmobtip"
   end if
   
   -- not empty, we have a JDK
   if tJDK is not empty then hide cd fld "fmobtip"
   
   if the platform is "macos" then
      set the itemDelimiter to slash
      delete item -2 to -1 of tJDK
   end if
   
   put "JDK Path:" && tJDK into field "JDK Path"
end updateJDK
