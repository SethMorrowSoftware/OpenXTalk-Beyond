script "revStandaloneSettingsAndroidBehavior"
on preOpenCard
   send hUpdateHeights to stack "revStandaloneSettings" in 10 milliseconds
   
   initialize
   -- OXT-Beyond: on to the stack's preOpenCard, which sizes the window
   -- for this card and names it in the title, as the other cards do
   pass preOpenCard
end preOpenCard


on initialize
   local tSettings
   put getSettings() into tSettings
   local tEnabled = false
   repeat for each item tItem in revSBPlatformArchitectures("Android")
      set the hilite of button ("Android" && tItem) of group "Android targets" of me to tSettings["Android",tItem] is true
      if tSettings["Android",tItem] then
         put true into tEnabled
      end if
   end repeat
   
   -- OXT-Beyond: a stack with Android on and no architecture saved gets
   -- arm64 beside armv7, because Google Play refuses an app without its
   -- 64-bit build and newer phones run no 32-bit code. Only this card's
   -- first pick changes: a stack that saved its architectures keeps them,
   -- and the builder still falls back to armv7 alone for one that never
   -- opened this card.
   if not tEnabled and tSettings["android"] is true then
      set the hilite of button "Android armv7" of group "Android targets" of me to true
      put true into tSettings["Android,armv7"]
      set the hilite of button "Android arm64" of group "Android targets" of me to true
      put true into tSettings["Android,arm64"]
      setSettings tSettings
   end if
   
   -- PM-2014-03-17: [[ In App Purchasing Updates ]] Port over old style in app purchasing permissions.
   if "BILLING" is among the keys of tSettings["android,application permissions"] then
      put tSettings["android,application permissions"]["BILLING"] into tSettings["android,inAppPurchasing"]
      delete variable tSettings["android,application permissions"]["BILLING"]
      setSettings tSettings
   end if
   
   -- PM-2014-03-19: [[ In App Purchasing Updates ]]  We don't support the amazon store in community.
   if revLicenseType() is not "commercial" \
         and revLicenseType() is not "professional" \
         and tSettings["android,billingProvider"] is "Amazon" then
      put "Google" into tSettings["android,billingProvider"]
      setSettings tSettings
   end if
   
   -- PM-2015-01-06: [[ In App Purchasing Updates ]] Init the billingProvider to Google on first launch, if no billing provider is set
   storeSetting "billingProvider", computeDefault(tSettings["android,billingProvider"], "Google")
   
   updateSettings
   updateAndroidSettingState
   
end initialize

on updateSettings
   local tSettings
   put getSettings() into tSettings
   
   --put computeDefault(tSettings["android,label"], tSettings["name"]) into field "Label"
   
   set the text of field "Label" to computeDefault(tSettings["android,label"], tSettings["name"])
   
   put computeDefault(tSettings["android,identifier"], "com.yourcompany.yourapp") into field "Identifier"
   put computeDefault(tSettings["android,version name"], "1.0.0") into field "Version Name"
   put computeDefault(tSettings["android,version code"], "1") into field "Version Code"
   put computeDefault(tSettings["android,key"], empty) into field "Key"
   put computeDefault(tSettings["android,icon"], empty) into field "Icon"
   put computeDefault(tSettings["android,splash"], empty) into field "Splash"
   put computeDefault(tSettings["android,customUrlScheme"], empty) into field "Custom URL Scheme"
   put computeDefault(tSettings["android,statusBarIcon"], empty) into field "Status Bar Icon"
   put computeDefault(tSettings["android,pushSenderID"], empty) into field "Push Sender ID"
   
   // IM-2012-03-05: initialize min version menu
   // SN-2015-05-13: [[ AndroidVersions ]] Make the Android versions changeable from
   //  a script-only stack
   dispatch "updateSettings" to button "Minimum Android Version" with computeDefault(tSettings["android,minimum version"], item 1 of revIDEDeployAndroidGetAPIsList())
   
   local tSigning
   put computeDefault(tSettings["android,signing"], "Sign with my key") into tSigning
   set the label of button "Signing" to tSigning
   set the enabled of group "key group" to (tSigning is "Sign with my key")
   
   local tInstallLocation
   put computeDefault(tSettings["android,installLocation"], "Internal Storage Only") into tInstallLocation
   set the label of button "Install Location" to tInstallLocation
   
   local tInitialOrientation
   put computeDefault(tSettings["android,initial orientation"], "Portrait") into tInitialOrientation
   set the label of button "Initial Orientation" to tInitialOrientation
   
   local tStatusbarHidden
   put computeDefault(tSettings["android,status bar hidden"], "false") into tStatusbarHidden
   set the hilitedButtonName of group "status bar" to tStatusbarHidden
   
   local tHardwareAccelerated
   put computeDefault(tSettings["android,hardware accelerated"], false) into tHardwareAccelerated
   set the hilited of button "Hardware Accelerated" to tHardwareAccelerated
   
   local tNFC
   put computeDefault(tSettings["android,nfc"], false) into tNFC
   set the hilited of button "NFC Tag Reading" to tNFC
   
   -- OXT-Beyond: the "App Bundle" box at the end of the build targets' row
   -- (tools/oxt/ide-stack-patches/android-card-app-bundle-1.txt): the
   -- "android,app bundle" setting, with which the Android builder makes an
   -- Android App Bundle (.aab) beside the package. A stack without it has
   -- none, and the box is not ticked.
   if there is a button "App Bundle" of group "Android targets" of me then
      set the hilited of button "App Bundle" of group "Android targets" of me to \
            (tSettings["android,app bundle"] is true)
   end if
   
   -- OXT-Beyond: the "OXT-Beyond engine" box ("Beyond Engine",
   -- tools/oxt/ide-stack-patches/android-card-engine-1.txt): the
   -- "android,engine" setting, with which the Android builder takes
   -- OXT-Beyond's own engine (beyond) instead of LiveCode 9.6.3's (empty or
   -- 9.6.3, the default). The box is ticked only for beyond.
   if there is a button "Beyond Engine" of group "Android targets" of me then
      set the hilited of button "Beyond Engine" of group "Android targets" of me to \
            (tSettings["android,engine"] is "beyond")
   end if
   
   -- OXT-Beyond: the "Edge to edge" box at the end of the Status Bar row
   -- ("Edge To Edge", tools/oxt/ide-stack-patches/
   -- android-card-status-bar-edge-1.txt): the "android,edge to edge"
   -- setting, with which an app is drawn edge to edge on Android 11 and
   -- newer. A stack without it is laid out as before, and the box is not
   -- ticked.
   if there is a button "Edge To Edge" of group "Android targets" of me then
      set the hilited of button "Edge To Edge" of group "Android targets" of me to \
            (tSettings["android,edge to edge"] is true)
   end if
   
   -- OXT-Beyond: the Android card of this IDE has no such button (and its
   -- Android build no such setting): setting it stopped the card's update
   -- with an error
   local tAllowHttpConnections
   if there is a button "Allow Http Connections" then
      put computeDefault(tSettings["android,allow http"], false) into tAllowHttpConnections
      set the hilited of button "Allow Http Connections" to tAllowHttpConnections
   end if

   repeat with i = 1 to the number of groups of group "device capabilities"
      get tSettings["android,device capabilities"][the short name of group i of group "Device Capabilities"]
      if it is "true" then
         get 1
      else if it is "false" then
         get 2
      else
         get 3
      end if
      set the hilite of button it of group i of group "Device Capabilities" to true
   end repeat
   
   repeat with i = 1 to the number of buttons of group "permissions"
      #get tSettings["android,application permissions"][the short name of button i of group "permissions"]
      #set the hilite of button i of group "permissions" to (it is true)
      get the short name of button i of group "permissions"
      set the hilite of button i of group "permissions" to computeDefault(tSettings["android,application permissions"][it], false)
   end repeat
   
   updateInAppPurchaseSettings
end updateSettings

on updateAndroidSettingState
   local tSettings
   put getSettings() into tSettings
   local tEnabled = false
   repeat for each item tItem in revSBPlatformArchitectures("Android")
      if tSettings["Android",tItem] then
         put true into tEnabled
      end if
   end repeat
   set the enabled of group "Android Settings" of me to tEnabled
   -- OXT-Beyond: the "App Bundle" box is an option of the Android build, as
   -- the settings below are: it can be ticked once an architecture is
   if there is a button "App Bundle" of group "Android targets" of me then
      set the enabled of button "App Bundle" of group "Android targets" of me to tEnabled
   end if
   -- and so is the engine the build takes
   if there is a button "Beyond Engine" of group "Android targets" of me then
      set the enabled of button "Beyond Engine" of group "Android targets" of me to tEnabled
   end if
   -- and so is whether the app is drawn edge to edge
   if there is a button "Edge To Edge" of group "Android targets" of me then
      set the enabled of button "Edge To Edge" of group "Android targets" of me to tEnabled
   end if
   set the visible of button "Androidchecked" to tEnabled
   set the opaque of button "Androidchecked" to false
   
   -- splash screen is not supported in Indy and Business editions
   if revLicenseType() is "commercial" \
         or revLicenseType() is "professional" then
      set the enabled of button "Splash Chooser" of group "Android Settings" of me to false
   end if
end updateAndroidSettingState

on updateAndroidArch pArch, pBuild
   local tSettingsA, tEngine, tError
   put getSettings() into tSettingsA
   
   -- OXT-Beyond: a stack set up for Android now, with this tick, is built
   -- with OXT-Beyond's own engine when the runtimes carry it, and the
   -- "OXT-Beyond engine" box shows it ticked; every stack set up for
   -- Android before, or that names an engine, keeps what it has
   -- (androidEngineOnFirstTarget in the Android builder, from the settings
   -- as they were before this tick). Without the builder it keeps it too
   put tSettingsA["android,engine"] into tEngine
   if pBuild is true then
      try
         put androidEngineOnFirstTarget(tSettingsA) into tEngine
      catch tError
         put tSettingsA["android,engine"] into tEngine
      end try
   end if
   if tEngine is not tSettingsA["android,engine"] then
      put tEngine into tSettingsA["android,engine"]
   end if

   put pBuild into tSettingsA["Android",pArch]
   
   local tEnabled = false
   repeat for each item tItem in revSBPlatformArchitectures("Android")
      if tSettingsA["Android",tItem] then
         put true into tEnabled
         exit repeat
      end if
   end repeat
   put tEnabled into tSettingsA["Android"]
   setSettings tSettingsA
   
   -- OXT-Beyond: and the engine box shows the engine the stack has now
   if there is a button "Beyond Engine" of group "Android targets" of me then
      set the hilited of button "Beyond Engine" of group "Android targets" of me to \
            (tSettingsA["android,engine"] is "beyond")
   end if

   if tEnabled then
      buildForEnabled "android"
   end if
   
   revSetEdit
   updateAndroidSettingState
end updateAndroidArch

-- PM-2014-03-17: [[ In App Purchasing Updates ]] Updated UI to support new store types.
on updateInAppPurchaseSettings
   local tSettings
   put getSettings() into tSettings
   
   lock screen
   set the hilite of button "In App Purchasing" of group "In App Purchasing" to computeDefault(tSettings["android,inAppPurchasing"], false)
   set the hilite of button computeDefault(tSettings["android,billingProvider"], "Google") of group "Store" of group "In App Purchasing" to true
   put computeDefault(tSettings["android,storeKey"], empty) into field "Store Key" of group "Google" of group "In App Purchasing"
   put computeDefault(tSettings["android,samsungItemGroupId"], empty) into field "Item Group Id" of group "Samsung" of group "In App Purchasing"
   
   get computeDefault(tSettings["android,samsungIapMode"], 0)
   if it is -1 then
      set the hilite of button "Test Failure" of group "Samsung" of group "In App Purchasing" to true
   else if it is 0 then
      set the hilite of button "Production" of group "Samsung" of group "In App Purchasing" to true
   else if it is 1 then
      set the hilite of button "Test Success" of group "Samsung" of group "In App Purchasing" to true
   end if
   
   if the hilite of of button "In App Purchasing" of group "In App Purchasing" then
      set the enabled of group "Store" of group "In App Purchasing" to true
      set the visible of group "Samsung" of group "In App Purchasing"  to the  hilite of button "Samsung"  of group "Store" of group "In App Purchasing"
      set the visible of group "Google" of group "In App Purchasing"  to the  hilite of button "Google"  of group "Store" of group "In App Purchasing"
   else
      set the visible of group "Samsung" of group "In App Purchasing"  to false
      set the visible of group "Google" of group "In App Purchasing"  to false
      set the enabled of group "Store" of group "In App Purchasing" to false
   end if
   
   set the visible of button "Amazon" of group "Store" of group "In App Purchasing" to (revLicenseType() is "commercial" or revLicenseType() is "professional")
   
   unlock screen
end updateInAppPurchaseSettings

on storeSetting pName, pValue
   // Check identifier
   if pName is "identifier" then
      if not validateIdentifier(pValue) then
         answer error "Invalid Android identifier. The identifier can contain any number of items seperated by a '.' character. Each item must only contain letters 'a-z', numbers '0-9' and the following special characters '_'. No item can be numerical only. For example com.runrev.app_1 is valid while com.runrev.app.1 is invalid."
         send "selectIdentifier" to me in 0 milliseconds
         exit storeSetting
      end if
   end if
   
   setSetting "android," & pName, pValue
end storeSetting

function fetchSetting pName
   return getSetting("android," & pName)
end fetchSetting

on clearSetting pName
   storeSetting pName, empty
   updateSettings
end clearSetting

command chooseImageFile pType
   local tRelativeFile
   put selectImageFile() into tRelativeFile
   
   if tRelativeFile is not empty then
      storeSetting pType, tRelativeFile
      updateSettings
   end if
end chooseImageFile

command chooseKeyStoreFile pType
   local tRelativeFile
   put selectKeyStoreFile() into tRelativeFile
   
   if tRelativeFile is not empty then
      storeSetting pType, tRelativeFile
      updateSettings
   end if
end chooseKeyStoreFile

on selectIdentifier
   select after field "identifier"
end selectIdentifier

on closeCard
   local tIdentifier
   get getSettings()
   put it["android", "identifier"] into tIdentifier
   
   if not androidIdentifierValid() then
      go to card "Android"
   end if
   
end closeCard

