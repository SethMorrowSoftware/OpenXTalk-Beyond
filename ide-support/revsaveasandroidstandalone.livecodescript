script "revSaveAsAndroidStandalone"
################################################################################

local sJavaRoot

-- OXT-Beyond: the exit status of the last command doShellCommand ran
local sShellStatus

################################################################################

command revSaveAsMobileStandalone pStack, pApkFile, pTarget, pSettings
   local tPath
   put the cMobileSupport["android.sdk"] of stack "revPreferences" into tPath
   
   if tPath is empty then
      throw revIDELocalise("In order to build Android standalones" & \ 
            " you need to choose the location of your Android development SDK" & \
            " in Preferences -> Mobile Support")
   end if
   if not revIDEDeployAndroidIsValidSDK(tPath) then
      -- OXT-Beyond: and what it lacks
      throw revIDELocalise("The chosen folder in Preferences -> Mobile Support" & \
            " is not a valid Android SDK. Please ensure you have installed it correctly," & \
            " and enabled support for") && revIDEDeployAndroidRequiredSDK() & ":" && checkSDK(tPath)
   end if
   
   local tTargetType
   if pTarget contains "build" then
      put "android release" into tTargetType
   else
      put "android test" into tTargetType
   end if
   
   try
      put the cMobileSupport["android.jdk"] of stack "revPreferences" into sJavaRoot
      dispatch "savingMobileStandalone" to stack pStack with tTargetType, pApkFile
   end try
   
   try
      revSaveAsMobileStandaloneMain pStack, pApkFile, pTarget, pSettings
   catch tError
   end try
   
   try
      if tError is not empty then
         put empty into pApkFile
      end if
      dispatch "mobileStandaloneSaved" to stack pStack with tTargetType, pApkFile
   end try
   
   if tError is not empty then
      throw tError
   end if
end revSaveAsMobileStandalone

private function pathIsRelative pPath
   if pPath is empty then throw "empty path"
   if pPath begins with "/" then return false
   if char 2 of pPath is ":" then return false
   
   return true
end pathIsRelative

// Modern APK assembly: copy asset archive as base, then add classes.dex and native libs via zip
-- OXT-Beyond: with revZip, which the builder already uses for the assets,
-- instead of the zip and sh programs, which Windows does not have. The files
-- are the ones zip added: classes.dex at the top, and every file under the
-- build's lib folder at its path there (lib/<abi>/*.so, and the jar files of
-- AAR libraries next to them); zip's entries for the folders themselves are
-- not added, as Android needs none. Each step's result is checked: zip's
-- were not, so a machine without zip made a package with no code in it.
-- Returns empty, or what went wrong.
private command buildAPK pUnalignedApkFile, pAssetArchive, pClassesFile, pLibsBuildFolder
   -- Copy asset archive as base APK
   put url ("binfile:" & pAssetArchive) into url ("binfile:" & pUnalignedApkFile)
   if the result is not empty then
      return "could not copy" && pAssetArchive & ":" && the result
   end if
   
   revZipOpenArchive pUnalignedApkFile, "update"
   if the result is not empty then
      return "could not open" && pUnalignedApkFile & ":" && the result
   end if
   
   local tError, tFiles, tFile
   -- Add classes.dex at root
   revZipAddItemWithFile pUnalignedApkFile, "classes.dex", pClassesFile
   if the result is not empty then
      put "could not add classes.dex:" && the result into tError
   end if
   
   -- Add native libs if present
   if tError is empty and there is a folder pLibsBuildFolder then
      put filesUnder(pLibsBuildFolder, empty) into tFiles
      repeat for each line tFile in tFiles
         revZipAddItemWithFile pUnalignedApkFile, "lib/" & tFile, pLibsBuildFolder & slash & tFile
         if the result is not empty then
            put "could not add lib/" & tFile & ":" && the result into tError
            exit repeat
         end if
      end repeat
   end if
   
   revZipCloseArchive pUnalignedApkFile
   if tError is empty and the result is not empty then
      put "could not write" && pUnalignedApkFile & ":" && the result into tError
   end if
   return tError
end buildAPK

-- OXT-Beyond: the files under pFolder, at any depth, as paths relative to it
-- with slashes, in sorted order; with pSuffix, only the files whose names end
-- with it. It does what "find" did for the builder, on every platform (on
-- Windows, find.exe searches text in files, and its error message became
-- d8's input).
private function filesUnder pFolder, pSuffix
   local tList
   filesUnderInto pFolder, empty, pSuffix, tList
   if the last char of tList is return then
      delete the last char of tList
   end if
   sort lines of tList
   return tList
end filesUnder

private command filesUnderInto pFolder, pPrefix, pSuffix, @xList
   local tFile, tSub
   repeat for each line tFile in files(pFolder)
      if pSuffix is empty or tFile ends with pSuffix then
         put pPrefix & tFile & return after xList
      end if
   end repeat
   repeat for each line tSub in folders(pFolder)
      if tSub is "." or tSub is ".." then
         next repeat
      end if
      filesUnderInto pFolder & slash & tSub, pPrefix & tSub & slash, pSuffix, xList
   end repeat
end filesUnderInto

private function updateMinimumAPI pVersionSet, pLimit
   local tLimitType
   if pVersionSet < pLimit then
      put "lowest" into tLimitType
   else
      put "highest" into tLimitType
   end if
   
   answer "The minimum Android API is currently set to" && \
         pVersionSet && \
         "but the" && tLimitType & " Android API available from OXT-Beyond's engine" && the version && \
         "is" && pLimit & "." & LF & \
         "Do you want to update the minimum Android API to" && pLimit & "?" \
         with "No" or "Yes" \
         titled "Minimum Android API error"
   
   return (it is "Yes")
end updateMinimumAPI

private function badAndroidApiMessage
   return "Not a valid Android API"
end badAndroidApiMessage

private function __ArchABI pArch
   switch pArch
      case "armv6"
         return "armeabi"
      case "armv7"
         return "armeabi-v7a"
      case "arm64"
         return "arm64-v8a"
      case "x86"
      case "x86_64"
         return pArch
   end switch
end __ArchABI

constant kAndroidExternals = "revzip revxml dbsqlite dbmysql dbodbc dbpostgresql revpdfprinter"

private command revSaveAsMobileStandaloneMain pStack, pApkFile, pTarget, pSettings
   local tArchABIs, tArchs
   repeat for each item tItem in revSBPlatformArchitectures("Android")
      if pSettings["android",tItem] then
         put true into tArchABIs[__ArchABI(tItem)]
         put true into tArchs[tItem]
      end if
   end repeat
   if the number of elements of tArchABIs is 0 then
      put true into tArchABIs["armeabi-v7a"]
      put true into tArchs["armv7"]
   end if
   -- OXT-Beyond: Google Play refuses an app that ships a 32-bit ABI without
   -- its 64-bit partner. The build itself is unchanged: an older stack still
   -- builds exactly the ABIs it asked for, and the warning says what to tick.
   if pTarget contains "build" then
      androidWarnMissing64Bit tArchABIs
   end if
   combine tArchABIs by comma as set
   combine tArchs by comma as set
   
   dispatch "revIDEDeployAndroidInitialize" to stack "revDeployLibrary"
   
   -- If we're searching for inclusions, do it here 
   local tConfirm, tResult
   put true into tConfirm
   if pSettings["inclusions"] is "search" then 
      put false into tConfirm
      -- search for inclusions when building for simulator
      if pTarget contains "test" then
         revSBSearchForInclusions pStack, pSettings
      end if
      
   end if
   
   -- Make sure all dependencies are included
   revSBUpdateForDependencies "android", tArchs, , pSettings
   revSBEnsurePerExtensionSettings "android", pSettings
   put the result into tResult
   if tResult is not empty then
      throw tResult
   end if
   
   -- Manually remove built-in implementations from detected script library inclusions
   revSBRemoveInclusions pStack, "android", tConfirm, pSettings
   
   -- Make sure old-style keys are retained, and updated with new information
   -- from inclusions pane of standalone settings GUI
   revSBConvertSettingsForPlatform pSettings, "android"
   
   -- Compute the base folder
   local tBaseFolder
   set the itemDelimiter to slash
   put item 1 to -2 of the effective filename of stack pStack into tBaseFolder
   set the itemDelimiter to comma
   
   -- OXT-Beyond: the runtime this build takes everything of the runtime's
   -- from (the engines and externals, the Java layer, the manifest and the
   -- files beside them): 9.6.3's, as before, or the engine built here when
   -- the stack asks for it (androidRuntimeFolder)
   local tRuntime
   put androidRuntimeFolder(pTarget, pSettings) into tRuntime
   
   -- Fetch the various options we need to initially build the app-bundle
   local tName, tVersionName, tVersionCode, tExternals, tDrivers, tIcon, tSplash, tKey, tUnsigned, tStatusBarIcon
   put pSettings["name"] into tName
   put pSettings["android,icon"] into tIcon
   put pSettings["android,key"] into tKey
   
   if pSettings["android,label"] is empty then
      put tName into pSettings["android,label"]
   end if
   if pSettings["android,identifier"] is empty then
      put "com.yourcompany.yourapp" into pSettings["android,identifier"]
   end if
   if pSettings["android,version name"] is empty then
      put "1.0.0" into pSettings["android,version name"]
   end if
   if pSettings["android,version code"] is empty then
      put "1" into pSettings["android,version code"]
   end if
   if pSettings["android,initial orientation"] is empty then
      put "portrait" into pSettings["android,initial orientation"]
   end if
   if pSettings["android,status bar hidden"] is empty then
      put "false" into pSettings["android,status bar hidden"]
   end if
   
   // SN-2015-05-13: [[ AndroidVersions ]] Make sure that the minimum version is
   // the minimum version that we can use.
   local tMinimumVersion, tMaximumVersion
   put item 1 of revIDEDeployAndroidGetApisList() into tMinimumVersion
   put last item of revIDEDeployAndroidGetApisList() into tMaximumVersion
   
   if pSettings["android,minimum version"] is empty then
      put tMinimumVersion into pSettings["android,minimum version"]
   else if pSettings["android,minimum version"] < tMinimumVersion then
      // In case the minimum version is still 2.2 (for instance), we warn the user
      //  that we want to update it, before doing so.
      if updateMinimumAPI(pSettings["android,minimum version"], tMinimumVersion) then
         put tMinimumVersion into pSettings["android,minimum version"]
      else
         throw badAndroidAPIMessage()
      end if
   else if pSettings["android,minimum version"] > tMaximumVersion then
      if updateMinimumAPI(pSettings["android,minimum version"], tMaximumVersion) then
         put tMaximumVersion into pSettings["android,minimum version"]
      else
         throw badAndroidAPIMessage()
      end if
   end if
   
   put pSettings["android,statusBarIcon"] into tStatusBarIcon
   if tStatusBarIcon is empty then
      // put default sb icon path into tStatusBarIcon
      // SN-2015-01-22: [[ Bug 13213 ]] If mapFilePath returns empty, an error will be triggered
      // line 629.
      put mapFilePath(tRuntime & slash & "notify_icon.png") into tStatusBarIcon
   end if
   
   switch pSettings["android,signing"]
      case "sign with my key"
         put true into tUnsigned
         break
      case "sign for development only"
         put false into tUnsigned
         put empty into tKey
         break;
      case "do not sign"
         put true into tUnsigned
         put empty into tKey
         break;
      default
         put true into tUnsigned
         break;
   end switch
   
   -- OXT-Beyond: an App Bundle beside the package, when the stack asks for
   -- one; never for Test (see androidBuildBundle)
   local tBundleFile, tUnsignedBundleFile
   if pTarget contains "build" and pSettings["android,app bundle"] is true then
      put androidBundlePath(pApkFile) into tBundleFile
      if there is a file tBundleFile then
         delete file tBundleFile
      end if
   end if
   
   -- Compute the icon path
   if tIcon is not empty and pathIsRelative(tIcon) then
      put tBaseFolder & slash before tIcon
   end if
   
   -- OXT-Beyond: the adaptive icon, when the stack asks for one (its
   -- images found and its colour read before the build starts)
   local tAdaptiveIcon
   put androidAdaptiveIcon(pSettings, tBaseFolder) into tAdaptiveIcon
   
   -- Compute the key path
   if tKey is not empty and pathIsRelative(tKey) then
      put tBaseFolder & slash before tKey
   end if
   
   -- Compute the status bar icon path
   if tStatusBarIcon is not empty and pathIsRelative(tStatusBarIcon) then
      put tBaseFolder & slash before tStatusBarIcon
   end if
   
   -- Compute the externals list (includes drivers on Android)
   repeat for each word tExternal in kAndroidExternals
      if pSettings["android,include" && tExternal] then
         if tExternal begins with "db" then 
            if "revdb" is not among the lines of tExternals then
               put "revdb" & return after tExternals
            end if
            put tExternal & return after tExternals
         else if tExternal is among the words of "revpdfprinter" then
            put tExternal & return after tDrivers
         else
            put tExternal & return after tExternals
         end if
      end if
   end repeat
   delete the last char of tExternals
   delete the last char of tDrivers
   
   -- Compute the stackfiles list
   lock messages
   local tStackFiles
   revSBRelativeStackFilesList pStack, tStackFiles
   unlock messages
   
   -- Make sure the app-bundle isn't already there
   if there is a file pApkFile then
      delete file pApkFile
      if there is a file pApkFile then
         throw "unable to remove existing apk"
      end if
   end if
   
   try
      ------- Create the build folder
      local tBuildFolder, tResBuildFolder, tDrawableResBuildFolder, tLayoutResBuildFolder
      local tLibsBuildFolder, tClassesBuildFolder, tXMLResBuildFolder
      put tempName() into tBuildFolder
      create folder tBuildFolder
      if the platform is "win32" then
         put shortFilePath(tBuildFolder) into tBuildFolder
      end if
      
      put tBuildFolder & slash & "classes_app" into tClassesBuildFolder
      put tBuildFolder & slash & "lib" into tLibsBuildFolder
      
      put tBuildFolder & slash & "res-build/res" into tResBuildFolder
      put tResBuildFolder & slash & "drawable" into tDrawableResBuildFolder
      put tResBuildFolder & slash & "layout" into tLayoutResBuildFolder
      put tResBuildFolder & slash & "xml" into tXMLResBuildFolder
      create folder tClassesBuildFolder
      create folder tLibsBuildFolder
      
      local tArchLibsBuildFolders
      repeat for each item tArch in tArchABIs
         put tLibsBuildFolder & slash & tArch into tArchLibsBuildFolders[tArch]
         create folder tArchLibsBuildFolders[tArch]
         if there is not folder tArchLibsBuildFolders[tArch] then
            throw "could not create build folders"
         end if
      end repeat
      
      revSBEnsureFolder tResBuildFolder
      if there is no folder tDrawableResBuildFolder then
         create folder tDrawableResBuildFolder
      end if
      if there is no folder tLayoutResBuildFolder then
         create folder tLayoutResBuildFolder
      end if
      if there is no folder tXMLResBuildFolder then
         create folder tXMLResBuildFolder
      end if
      if there is no folder tBuildFolder or there is no folder tClassesBuildFolder or \
            there is no folder tLibsBuildFolder or \
            there is no folder tResBuildFolder or there is no folder tDrawableResBuildFolder  or \
            there is no folder tLayoutResBuildFolder or there is no folder tXMLResBuildFolder then
         throw "could not create build folders"
      end if
      
      if the platform is "win32" then
         put shortFilePath(tBuildFolder) into tBuildFolder
      end if
      
      -------- Unpack all the files used by the externals
      local tManifestFile, tManifest
      
      revStandaloneProgress "Integrating externals..."
      
      if tExternals is not empty then
         put return after tExternals
      end if
      set the itemDelimiter to "."
      
      local tResolvedFileData
      revSBUpdateSettingsForExtensions "android", pSettings
      revSBResolveCopyFilesList tBaseFolder, "android", pSettings, tResolvedFileData
      
      addPlayServiceAARsToSettings pSettings
      expandAARsAndComputeSettings tBuildFolder, pSettings
      
      repeat for each element tFile in tResolvedFileData
         -- Add to list of manifests to merge
         if tFile["name"] is "AndroidManifest.xml" then
            appendToStringList tFile["resolved"], pSettings["androidManifests"]
            next repeat
         end if
         
         -- Only look for lcext files.
         switch the last item of tFile["name"]
            case "lcext"
               if there is no file tFile["resolved"] then
                  throw "could not find referenced external -" && tFile["resolved"]
               end if
               if addExternalFromFile(tFile["resolved"], tClassesBuildFolder, tArchLibsBuildFolders) then
                  -- Add the external to the list to load
                  put char 1 to -7 of tFile["name"] & return after tExternals
               end if
               break
            case "lcextd"
               if there is no folder tFile["resolved"] then
                  throw "could not find referenced external -" && tFile["resolved"]
               end if
               if addExternalFromFolder(tFile["resolved"], tClassesBuildFolder, tArchLibsBuildFolders) then
                  -- Add the external to the list to load
                  put char 1 to -8 of tFile["name"] & return after tExternals
               end if
               break
         end switch 
         
      end repeat
      delete the last char of tExternals
      set the itemDelimiter to comma
      
      -------- Create the Manifest
      revStandaloneProgress "Writing manifest..."
      
      if tManifestFile is empty then
         put tBuildFolder & slash & "AndroidManifest.xml" into tManifestFile
      end if
      
      if tManifest is empty then
         put url ("binfile:" & mapFilePath(tRuntime & slash & "Manifest.xml")) into tManifest
      end if
      // SN-2015-01-22: [[ Bug 13213 ]] Throw an error in case an error occurred
      if the result is not empty then
         throw "Cannot find the template Manifest"
      end if
      local tEscapedLabel
      put escapeLabel(pSettings["android,label"]) into tEscapedLabel
      replace "${LABEL}" with textEncode(tEscapedLabel, "utf-8") in tManifest
      replace "${NAME}" with ".mblandroid" in tManifest
      replace "${IDENTIFIER}" with pSettings["android,identifier"] in tManifest
      replace "${VERSION_NAME}" with pSettings["android,version name"] in tManifest
      replace "${VERSION_CODE}" with pSettings["android,version code"] in tManifest
      if there is a file tIcon or tAdaptiveIcon is an array then
         replace "${ICON}" with "android:icon=" & quote & "@drawable/icon" & quote in tManifest
      else
         replace "${ICON}" with empty in tManifest
      end if
      
      if pSettings["android,status bar hidden"] then
         replace "${THEME}" with "@android:style/Theme.NoTitleBar.Fullscreen" in tManifest
      else
         replace "${THEME}" with "@android:style/Theme.NoTitleBar" in tManifest
      end if
      
      local tInitialOrientation
      put pSettings["android,initial orientation"] into tInitialOrientation
      if tInitialOrientation is "landscape" then
         put "sensorLandscape" into tInitialOrientation
      end if
      replace "${ORIENTATION}" with tInitialOrientation in tManifest
      
      replace "${MIN_SDK_VERSION}" with pSettings["android,minimum version"] in tManifest
      local tTargetAPI
      put androidTargetAPI(pSettings, tRuntime) into tTargetAPI
      replace "${TARGET_SDK_VERSION}" with tTargetAPI in tManifest
      
      local tUsesFeature, tUsesPermission, tFeatures, tPermissions, tAd
      repeat for each key tFeature in pSettings["android,device capabilities"]
         put "  <uses-feature android:name="&quote&"android."&tFeature&quote&" android:required="&quote&"${REQUIRED}"&quote&" />" into tUsesFeature
         replace "${REQUIRED}" with pSettings["android,device capabilities"][tFeature] in tUsesFeature
         put tUsesFeature & return after tFeatures
      end repeat
      repeat for each key tPermission in pSettings["android,capability permissions"]
         put "  <uses-permission android:name="&quote&"android.permission."&tPermission&quote&" />" into tUsesPermission
         put tUsesPermission & return after tPermissions
      end repeat
      repeat for each key tPermission in pSettings["android,application permissions"]
         if tPermission is "AD" then
            put true into tAd
            put "  <uses-permission android:name="&quote&"android.permission.ACCESS_NETWORK_STATE"&quote&"/>" & return into tUsesPermission
            put "  <uses-permission android:name="&quote&"android.permission.READ_PHONE_STATE"&quote&" />" after tUsesPermission
         else
            put "  <uses-permission android:name="&quote&"android.permission."&tPermission&quote&" />" into tUsesPermission
         end if
         put tUsesPermission & return after tPermissions
      end repeat
      
      replace "${USES_FEATURE}" with tFeatures in tManifest
      --replace "${USES_PERMISSION}" with tPermissions in tManifest
      
      local tService, tReceiver
      -- MW-2017-06-13: add generic service
      put "<service android:enabled=" & quote & "true" & quote && "android:name=" & quote & ".mblandroidservice" & quote && "android:exported=" & quote & "false" & quote & "/>" & return after tService
      
      -- IM-2012-02-28: need barebones receiver for local notifications
      put "<receiver android:name="&quote&"AppReceiver"&quote&" android:exported="&quote&"false"&quote&">" into tReceiver
      --      if tBilling then
      --         -- create service & receiver sections for billing support
      --         put "<service android:name="&quote&"AppService"&quote&" />" into tService
      --         put "<intent-filter>" & return after tReceiver
      --         repeat for each item tMsgName in "IN_APP_NOTIFY,RESPONSE_CODE,PURCHASE_STATE_CHANGED"
      --            put "<action android:name="&quote&"com.android.vending.billing."&tMsgName&quote&" />" & return after tReceiver
      --         end repeat
      --         put "</intent-filter>" after tReceiver
      --      else
      --         put empty into tService
      --      end if
      put "</receiver>" after tReceiver
      
      -- PM-2014-03-17: [[ In App Purchasing Updates ]] Include new store setting in manifest.
      if pSettings["android,inAppPurchasing"] then
         get pSettings["android,billingProvider"]
         if it is "Google" then
            put "  <uses-permission android:name="&quote&"com.android.vending.BILLING"&quote&" />" & return after tPermissions
         end if
         if it is "Samsung" then
            put "  <uses-permission android:name="&quote&"com.sec.android.iap.permission.BILLING"&quote&" />" & return after tPermissions
         end if
         if it is "Amazon" and revLicenseType() is "commercial" then
            local tAmazonReceiver
            put "<receiver android:name="&quote&"com.amazon.inapp.purchasing.ResponseReceiver"&quote&">" into tAmazonReceiver
            put "<intent-filter>" & return after tAmazonReceiver
            put "<action android:name="&quote&"com.amazon.inapp.purchasing.NOTIFY"&quote&" " & return after tAmazonReceiver
            put "android:permission ="&quote&"com.amazon.inapp.purchasing.Permission.NOTIFY"&quote&"  />" & return after tAmazonReceiver
            put "</intent-filter>" after tAmazonReceiver
            put "</receiver>" after tAmazonReceiver
            put tAmazonReceiver after tReceiver
         end if
      end if
      
      local tNFCIntentFilter
      if pSettings["android,nfc"] then
         put "<intent-filter>" & return & \
               "<action android:name=" & quote & "android.nfc.action.TECH_DISCOVERED" & quote & " />" & return & \
               "</intent-filter>" & return & \
               "<meta-data android:name=" & quote & "android.nfc.action.TECH_DISCOVERED" & quote & \
               " android:resource=" & quote & "@xml/nfc_tech_filter" & quote & " />" & return into tNFCIntentFilter
         
         put "<uses-permission android:name=" & quote & "android.permission.NFC" & quote & " />" & return after tPermissions
      end if
      replace "${NFC_FILTER}" with tNFCIntentFilter in tManifest
      
      replace "${SERVICE}" with tService in tManifest
      replace "${RECEIVER}" with tReceiver in tManifest
      replace "${USES_PERMISSION}" with tPermissions in tManifest
      
      if tAd is true then
         replace "${AD_ACTIVITY}" with "<activity android:name=" & quote & "com.inneractive.api.ads.InneractiveFullScreenView" & quote & "></activity>" in tManifest
      else
         replace "${AD_ACTIVITY}" with empty in tManifest
      end if
      
      local tInstallLocation
      switch pSettings["android,installLocation"]
         case "Internal Storage Only"
         case empty
            put empty into tInstallLocation
            break
         case "Allow External Storage"
            put "android:installLocation="&quote&"auto"&quote into tInstallLocation
            break
         case "Prefer External Storage"
            put "android:installLocation="&quote&"preferExternal"&quote into tInstallLocation
            break
      end switch
      replace "${INSTALL_LOCATION}" with tInstallLocation in tManifest
      
      local tCustomUrlFilter
      if pSettings["android,customUrlScheme"] is not empty then
         put "<intent-filter>" & \
               "<action android:name="&quote&"android.intent.action.VIEW"&quote&" />" & \
               "<category android:name="&quote&"android.intent.category.DEFAULT"&quote&" />" & \
               "<category android:name="&quote&"android.intent.category.BROWSABLE"&quote&" />" & \
               "<data android:scheme="&quote&pSettings["android,customUrlScheme"]&quote&" />" & \
               "</intent-filter>" into tCustomUrlFilter
      else
         put empty into tCustomUrlFilter
      end if
      replace "${CUSTOM_URL_FILTER}" with tCustomUrlFilter in tManifest
      
      local tPushPermissions
      local tPushReceiver
      if pSettings["android,pushSenderID"] is not empty then
         put "<permission android:name="&quote&pSettings["android,identifier"]&".permission.C2D_MESSAGE"&quote&" android:protectionLevel="&quote&"signature"&quote&" />" & \
               "<uses-permission android:name="&quote&pSettings["android,identifier"]&".permission.C2D_MESSAGE"&quote&" />" & \
               "<uses-permission android:name="&quote&"com.google.android.c2dm.permission.RECEIVE"&quote&" />" into tPushPermissions
         
         -- OXT-Beyond: Android 12 and newer refuse to install an app whose
         -- receiver has an intent-filter and no android:exported. The push
         -- messages come from outside the app, so "true" is the value the
         -- older Androids used by default; the SEND permission still guards it.
         put "<receiver android:name="&quote&"PushReceiver"&quote&" android:exported="&quote&"true"&quote&" android:permission="&quote&"com.google.android.c2dm.permission.SEND"&quote&">" & \
               "<intent-filter>" & \
               "<action android:name="&quote&"com.google.android.c2dm.intent.RECEIVE"&quote&" />" & \
               "<category android:name="&quote&pSettings["android,identifier"]&quote&" />" & \
               "</intent-filter>" & \
               "<intent-filter>" & \
               "<action android:name="&quote&"com.google.android.c2dm.intent.REGISTRATION"&quote&" />" & \
               "<category android:name="&quote&pSettings["android,identifier"]&quote&" />" & \
               "</intent-filter>" & \
               "</receiver>" into tPushReceiver
      else
         put empty into tPushPermissions
         put empty into tPushReceiver
      end if
      replace "${PUSH_PERMISSIONS}" with tPushPermissions in tManifest
      replace "${PUSH_RECEIVER}" with tPushReceiver in tManifest
      // Add the file provider to the manifest
      local tProvider
      put "<provider " & return into tProvider
      put "      android:name=" & quote & pSettings["android,identifier"] & ".AppProvider" & quote & return after tProvider
      put "      android:authorities=" & quote & pSettings["android,identifier"] & ".fileprovider" & quote & return after tProvider
      put "      android:exported=" & quote & "false" & quote & return after tProvider
      put "      android:grantUriPermissions=" & quote & "true" & quote & " >" & return after tProvider
      // Add meta-data tag
      put "      <meta-data" & return after tProvider
      put "            android:name=" & quote & "android.support.FILE_PROVIDER_PATHS" & quote & return after tProvider
      put "            android:resource=" & quote & "@xml/file_provider_paths" & quote & " />" & return after tProvider
      put "    </provider>" & return after tProvider
      
      replace "${PROVIDER}" with tProvider in tManifest
      
      // SN-2015-09-24: [[ Bug 15875 ]] Add the screenSize configChanges value for API > 12
      //  Otherwise the app restarts on orientation change.
      // OXT-Beyond: and the other changes the app goes on through
      //  (androidConfigChanges)
      local tConfigChangesProp
      put androidConfigChanges() into tConfigChangesProp
      replace "${CONFIG_CHANGES}" with tConfigChangesProp in tManifest
      
      // SN-2015-09-30: [[ Bug 10267 ]] Hardware Acceleration option added
      local tHardwareAccelerated
      if pSettings["android,hardware accelerated"] then
         put "true" into tHardwareAccelerated
      else
         put "false" into tHardwareAccelerated
      end if
      replace "${HARDWARE_ACCELERATED}" with tHardwareAccelerated in tManifest
      
      // Allow http connections
      local tAllowHttpConnections, tHasInternetPermission
      if the keys of pSettings["android,application permissions"] contains "Internet" then
         put "true" into tHasInternetPermission
      end if
      if pSettings["android,allow http"] and tHasInternetPermission then
         put "android:usesCleartextTraffic=" & quote & "true" & quote into tAllowHttpConnections
      else
         put empty into tAllowHttpConnections
      end if
      replace "${ALLOW_HTTP_CONNECTIONS}" with tAllowHttpConnections in tManifest
      
      put androidKeepLargeScreenLayout(tManifest, tTargetAPI) into tManifest
      put androidDeclareRelaunch(tManifest, tRuntime) into tManifest
      put androidAskForEdgeToEdge(tManifest, pSettings, tRuntime) into tManifest
      
      put tManifest into url ("binfile:" & tManifestFile)
      
      local tAdditional
      repeat for each line tManifest in pSettings["androidManifests"]
         appendToList tManifest, tAdditional
      end repeat
      put androidCreateAppManifest(tManifestFile, tAdditional) \
            into url ("binfile:" & tManifestFile)
      if the result is not empty then
         throw "could not create manifest"
      end if
      
      -- OXT-Beyond: an extension's manifest can add a component that Android
      -- 12 and newer will not install (an intent-filter and no
      -- android:exported). Whether it should be exported is the extension's
      -- call, so the manifest is left as it is and the build names it.
      repeat for each line tComponent in androidComponentsWithoutExported(androidManifestToArray(tManifestFile))
         revStandaloneAddWarning "Android: the" && tComponent && \
               "in the app's manifest has an intent-filter and no android:exported," && \
               "so Android 12 and newer will refuse to install the app;" && \
               "the extension that adds it needs to set android:exported"
      end repeat
      
      -------- Build the Classes
      revStandaloneProgress "Building classes..."
      
      -- MW-2012-07-05: Make sure we record all classes we build so we can clean up.
      local tCompiledClassFilePath, tBuiltClassFiles
      put empty into tBuiltClassFiles
      put pSettings["android,identifier"] into tCompiledClassFilePath
      replace "." with "/" in tCompiledClassFilePath
      
      local tLiveCodeClassesFile
      put tBuildFolder & slash & "LiveCode.jar" into tLiveCodeClassesFile
      put url ("binfile:" & mapFilePath(tRuntime & slash & "Classes")) into url ("binfile:" & tLiveCodeClassesFile)
      if the result is not empty then
         throw "could not prepare LiveCode classes"
      end if
      
      local tClassPath
      if the platform is "win32" then
         put pathToRootClasses() & ";" & tLiveCodeClassesFile & ";" & tClassesBuildFolder & ";" into tClassPath
      else
         put pathToRootClasses() & ":" & tLiveCodeClassesFile & ":" & tClassesBuildFolder into tClassPath
      end if
      
      -- MW-2017-06-13: compile the renamed service class
      local tClass, tClassFile
      put tBuildFolder & slash & "classes_app/mblandroidservice.java" into tClassFile
      put "package" && pSettings["android,identifier"] & ";" & return into tClass
      put "import com.runrev.android.LiveCodeService;" & return after tClass
      put "public class mblandroidservice extends LiveCodeService {}" & return after tClass
      put tClass into url ("binfile:" & tClassFile)
      if the result is not empty then
         throw "could not create billing support class"
      end if
      put tClassFile & return after tBuiltClassFiles
      executeShellCommand pathToJavaC(), "-target 8 -source 8 -Xlint:none -d", tClassesBuildFolder, "-cp", tClassPath, tClassFile
      if the result is not empty then
         throw "could not compile service support class"
      end if
      put tBuildFolder & slash & "classes_app/" & tCompiledClassFilePath & "/mblandroidservice.class" & return after tBuiltClassFiles
      
      put tBuildFolder & slash  & "classes_app/mblandroid.java" into tClassFile
      put "package" && pSettings["android,identifier"] & ";" & return into tClass
      put "import com.runrev.android.LiveCodeActivity; import java.lang.reflect.*;" & return after tClass
      put "public class mblandroid extends LiveCodeActivity {public Class getServiceClass() {return mblandroidservice.class;}}" & return after tClass
      put tClass into url ("binfile:" & tClassFile)
      if the result is not empty then
         throw "could not create activity class"
      end if
      put tClassFile & return after tBuiltClassFiles
      executeShellCommand pathToJavaC(), "-target 8 -source 8 -Xlint:none -d", tClassesBuildFolder, "-cp", tClassPath, tClassFile
      if the result is not empty then
         throw "could not compile application class"
      end if
      put tBuildFolder & slash & "classes_app/" & tCompiledClassFilePath & "/mblandroid.class" & return after tBuiltClassFiles
      
      -- IM-2012-02-28: need barebones receiver for local notifications
      // build receiver class
      put tBuildFolder & slash & "classes_app/AppReceiver.java" into tClassFile
      put "package" && pSettings["android,identifier"] & ";" & return into tClass
      put "import com.runrev.android.EngineReceiver;" & return after tClass
      put "public class AppReceiver extends EngineReceiver {}" & return after tClass
      put tClass into url ("binfile:" & tClassFile)
      if the result is not empty then
         throw "could not create billing support class"
      end if
      put tClassFile & return after tBuiltClassFiles
      
      executeShellCommand pathToJavaC(), "-target 8 -source 8 -Xlint:none -d", tClassesBuildFolder, "-cp", tClassPath, tClassFile
      if the result is not empty then
         throw "could not compile billing support class"
      end if
      put tBuildFolder & slash & "classes_app/" & tCompiledClassFilePath & "/AppReceiver.class" & return after tBuiltClassFiles
      
      -- IM-2011-10-26: Generate and compile billing service & receiver classes
      --      if tBilling then
      --         local tBillingClass, tBillingClassFile
      
      --         // build service class
      --         put tBuildFolder & slash & "classes_app/AppService.java" into tBillingClassFile
      --         put "package" && pSettings["android,identifier"] & ";" & return into tBillingClass
      --         put "import com.runrev.android.billing.BillingService;" & return after tBillingClass
      --         put "public class AppService extends BillingService {}" & return after tBillingClass
      --         put tBillingClass into url ("binfile:" & tBillingClassFile)
      --         if the result is not empty then
      --            throw "could not create billing support class"
      --         end if
      --         put tBillingClassFile & return after tBuiltClassFiles
      
      --         executeShellCommand pathToJavaC(), "-target 1.5 -source 1.5 -Xlint:none -d", tClassesBuildFolder, "-cp", tClassPath, tBillingClassFile
      --         if the result is not empty then
      --            throw "could not compile billing support class"
      --         end if
      --         put tBuildFolder & slash & "classes_app/" & tCompiledClassFilePath & "/AppService.class" & return after tBuiltClassFiles
      --      end if
      
      // IM-2012-02-24: Generate push notification listener class
      if pSettings["android,pushSenderID"] is not empty then
         local tPushReceiverClass, tPushReceiverClassFile
         put tBuildFolder & slash & "classes_app/PushReceiver.java" into tPushReceiverClassFile
         
         put "package" && pSettings["android,identifier"] & ";" & return into tPushReceiverClass
         put "import com.runrev.android.*;" & return after tPushReceiverClass
         put "public class PushReceiver extends com.runrev.android.PushReceiver {}" & return after tPushReceiverClass
         put tPushReceiverClass into url ("binfile:" & tPushReceiverClassFile)
         if the result is not empty then
            throw "could not create push notification support class"
         end if
         put tPushReceiverClassFile & return after tBuiltClassFiles
         
         executeShellCommand pathToJavac(), "-target 8 -source 8 -Xlint:none -d", tClassesBuildFolder, "-cp", tClassPath, tPushReceiverClassFile
         if the result is not empty then
            throw "could not compile push notification support class"
         end if
         put tBuildFolder & slash & "classes_app/" & tCompiledClassFilePath & "/PushReceiver.class" & return after tBuiltClassFiles
      end if
      
      // Generate app content provider class
      local tProviderClass, tProviderClassFile
      put tBuildFolder & slash & "classes_app/AppProvider.java" into tProviderClassFile
      
      put "package" && pSettings["android,identifier"] & ";" & return into tProviderClass
      put "import com.runrev.android.*;" & return after tProviderClass
      put "public class AppProvider extends com.runrev.android.AppProvider {}" & return after tProviderClass
      
      put tProviderClass into url ("binfile:" & tProviderClassFile)
      if the result is not empty then
         throw "could not create app content provider"
      end if
      put tProviderClassFile & return after tBuiltClassFiles
      
      executeShellCommand pathToJavac(), "-target 8 -source 8 -Xlint:none -d", tClassesBuildFolder, "-cp", tClassPath, tProviderClassFile
      if the result is not empty then
         throw "could not compile app content provider" & return & the result
      end if
      put tBuildFolder & slash & "classes_app/" & tCompiledClassFilePath & "/AppProvider.class" & return after tBuiltClassFiles
      
      set the itemdel to slash
      local tJarCount
      repeat for each line tJarFile in pSettings["jarFiles"]
         -- use numeric jar file names as they might have the same
         -- source name
         add 1 to tJarCount
         local tTargetFile
         put tLibsBuildFolder & slash & tJarCount & ".jar" into tTargetFile
         put url ("binfile:" & tJarFile) into url ("binfile:" & tTargetFile)
      end repeat
      
      -- MW-2012-07-05: Record all asset files that are copied into /tmp
      local tAssetFiles
      put empty into tAssetFiles
      
      local tAssetArchive
      put tBuildFolder & slash & "lcandroid.ap_" into tAssetArchive
      if there is a file tAssetArchive then
         delete file tAssetArchive
      end if
      
      local tLayoutXML
      put mapFilePath(tRuntime & slash & "livecode_inputcontrol.xml") into tLayoutXML
      put url ("binfile:" & tLayoutXML) into url ("binfile:" & tLayoutResBuildFolder & slash & "livecode_inputcontrol.xml")
      if the result is not empty then
         throw "could not copy layout file '" & tLayoutXML & "'"
      end if
      put tLayoutResBuildFolder & slash & "livecode_inputcontrol.xml" & return after tAssetFiles
      
      local tNFCTechFilter
      put mapFilePath(tRuntime & slash & "nfc_tech_filter.xml") into tNFCTechFilter
      put url ("binfile:" & tNFCTechFilter) into url ("binfile:" & tXMLResBuildFolder & slash & "nfc_tech_filter.xml")
      if the result is not empty then
         throw "could not copy NFC tech filter file '" & tNFCTechFilter & "'"
      end if
      put tXMLResBuildFolder & slash & "nfc_tech_filter.xml" & return after tAssetFiles
      
      
      local tFileProviderPaths
      put mapFilePath(tRuntime & slash & "file_provider_paths.xml") into tFileProviderPaths
      put url ("binfile:" & tFileProviderPaths) into url ("binfile:" & tXMLResBuildFolder & slash & "file_provider_paths.xml")
      if the result is not empty then
         throw "could not copy file provider paths file '" & tFileProviderPaths & "'"
      end if
      put tXMLResBuildFolder & slash & "file_provider_paths.xml" & return after tAssetFiles
      
      if there is a file tIcon then
         put url ("binfile:" & tIcon) into url ("binfile:" & tDrawableResBuildFolder & slash & "icon.png")
         if the result is not empty then
            throw "could not copy icon '" & tIcon & "'"
         end if
         put tDrawableResBuildFolder & slash & "icon.png" & return after tAssetFiles
      else if tAdaptiveIcon is an array then
         -- before Android 8.0, which has no adaptive icons: its foreground
         put url ("binfile:" & tAdaptiveIcon["foreground"]) into url ("binfile:" & tDrawableResBuildFolder & slash & "icon.png")
         if the result is not empty then
            throw "could not copy icon '" & tAdaptiveIcon["foreground"] & "'"
         end if
         put tDrawableResBuildFolder & slash & "icon.png" & return after tAssetFiles
      end if
      if tAdaptiveIcon is an array then
         androidAddAdaptiveIcon tAdaptiveIcon, tResBuildFolder
      end if
      
      if there is a file tStatusBarIcon then
         put url ("binfile:" & tStatusBarIcon) into url ("binfile:" & tDrawableResBuildFolder & slash & "notify_icon.png")
         if the result is not empty then
            throw "could not copy icon '" & tStatusBarIcon & "'"
         end if
         put tDrawableResBuildFolder & slash & "notify_icon.png" & return after tAssetFiles
      end if
      
      local tResourceClasses
      generateResourceClasses tBuildFolder, tResBuildFolder, \
            tManifestFile, pSettings, tResourceClasses
      if the result is not empty then
         throw "could not build R.java" & return & the result
      end if
      if tResourceClasses is not empty then
         local tParams
         put "-target 1.5 -source 1.5 -Xlint:none -d" into tParams
         split tParams by space
         appendToList tClassesBuildFolder, tParams
         appendToList "-cp", tParams
         appendToList tClassPath, tParams
         repeat for each line tRClass in tResourceClasses
            appendToList tRClass, tParams
         end repeat
         executeShellCommandWithParams pathToJavac(), tParams
         if the result is not empty then
            throw "could not compile resource class" & return & the result
         end if
         -- Add to list of files to delete
      end if
      
      local tClassesFile
      put tBuildFolder & slash & "classes.dex" into tClassesFile
      local tDexOutFolder
      put tBuildFolder & slash & "dexout" into tDexOutFolder
      create folder tDexOutFolder
      
      local tDexParams
      appendToList "--output", tDexParams
      appendToList tDexOutFolder, tDexParams
      appendToList "--lib", tDexParams
      appendToList pathToRootClasses(), tDexParams
      -- d8 does not accept directories; enumerate .class files
      -- OXT-Beyond: listed by the engine, not with find (see filesUnder)
      local tClassFiles
      put filesUnder(tClassesBuildFolder, ".class") into tClassFiles
      repeat for each line tFile in tClassFiles
         if tFile is not empty then
            appendToList tClassesBuildFolder & slash & tFile, tDexParams
         end if
      end repeat
      appendToList tLiveCodeClassesFile, tDexParams
      repeat for each line tFile in files(tLibsBuildFolder)
         if tFile ends with ".jar" then
            appendToList (tLibsBuildFolder & slash & tFile), tDexParams
         end if
      end repeat
      executeShellCommandWithParams pathToDex(), tDexParams
      
      if there is not a file (tDexOutFolder & slash & "classes.dex") then
         throw "could not encode class bundle:" && the result
      end if
      
      put url ("binfile:" & tDexOutFolder & slash & "classes.dex") into url ("binfile:" & tClassesFile)
      delete file (tDexOutFolder & slash & "classes.dex")
      if there is a folder tDexOutFolder then delete folder tDexOutFolder
      
      ------- Compile the Standalone
      revStandaloneProgress "Building executable..."
      
      put tExternals into pSettings["externals"]
      
      if pSettings["android,library"] is empty then
         put "revsecurity:./librevsecurity" into pSettings["android,library"]
      else
         put return & "revsecurity:./librevsecurity" after pSettings["android,library"]
      end if
      repeat for each line tEntry in tExternals
         put return & tEntry & ":" & "./lib" & tEntry after pSettings["android,library"]
      end repeat
      repeat for each line tEntry in tDrivers
         put return & tEntry & ":" & "./lib" & tEntry after pSettings["android,library"]
      end repeat
      
      -- OXT-Beyond: an extension with native code for some of the chosen ABIs
      -- and not others fails on the devices that pick the ABI it lacks
      if pTarget contains "build" then
         androidWarnMissingExtensionCode tArchs, pSettings["extension_code_resources"]
      end if
      
      set the itemDelimiter to comma
      repeat for each item tArch in tArchs
         local tArchCodeResources
         filter pSettings["extension_code_resources"] \
               with ("*code/" & tArch & "-android*") into tArchCodeResources
         
         repeat for each line tLib in tArchCodeResources
            local tSourceFile, tSourceName
            set the itemdelimiter to slash
            put item -1 of tLib into tSourceFile
            set the itemDelimiter to "."
            put item 1 to -2 of tSourceFile into tSourceName
            set the itemDelimiter to comma
            
            if not(tSourceFile begins with "lib") then
               put "lib" before tSourceFile
            end if
            
            put url ("binfile:" & tLib) into \
                  url ("binfile:" & tArchLibsBuildFolders[__ArchABI(tArch)] & slash & tSourceFile)
            
            if (tSourceName & ":./" & tSourceFile) is not among the lines of pSettings["android,library"] then
               put return & tSourceName & ":./" & tSourceFile after pSettings["android,library"]
            end if
         end repeat
      end repeat
      
      local tDeploy
      -- Update the deploy params with script library and extension inclusions
      revSBUpdateDeployParams pStack, "android", pSettings, tDeploy
      
      -- Stackfile to use
      put the effective filename of stack pStack into tDeploy["stackfile"]
      
      -- Splash to use (if non-commercial)
      if line 3 of the revLicenseInfo is among the words of "Educational Personal" then
         -- MW-2011-03-17: Make sure absolute paths work correctly
         if pSettings["android,splash"] is not empty and pathIsRelative(pSettings["android,splash"]) then
            put tBaseFolder & slash & pSettings["android,splash"] into tDeploy["splash"]
         else
            put pSettings["android,splash"] into tDeploy["splash"]
         end if
      end if

      repeat for each key tArch in tArchLibsBuildFolders
         -- Engine to use
         put mapFilePath(tRuntime & slash & tArch & slash & "Standalone") into tDeploy["engine"]
         // SN-2015-01-22: [[ Bug 13213 ]] Throw an error in case an error occurred
         if there is no file tDeploy["engine"] then
            throw "Could not find standalone engine"
         end if
         
         -- Output file to create
         put tArchLibsBuildFolders[tArch] & slash & "librevandroid.so" into tDeploy["output"]
         
         _internal deploy android tDeploy
         if the result is not empty then
            throw the result
         end if
      end repeat
      
      -------- Assembling Assets
      revStandaloneProgress "Assembling assets..."
      
      -- Make sure we include the res folders for each aar when packaging
      local tAarResFolderOpts
      put empty into tAarResFolderOpts
      repeat with x = 1 to the number of lines in pSettings["aarFiles"]
         local tAarResFolder
         put tBuildFolder & slash & x & "/res" into tAarResFolder
         if there is a folder tAarResFolder then
            put "-S" && quote & tAarResFolder & quote & space after tAarResFolderOpts
         end if
      end repeat      
      
      local tAaptResult
      if there is a folder tResBuildFolder then
         executeShellCommand pathToAapt(), "package", "-f", "-M", tManifestFile, \
               "-I", pathToRootClasses(),"-F", tAssetArchive, "-S", tResBuildFolder, \
               tAarResFolderOpts, "--auto-add-overlay"
      else
         executeShellCommand pathToAapt(), "package", "-f", "-M", tManifestFile, \
               "-I", pathToRootClasses(),"-F", tAssetArchive, \
               tAarResFolderOpts, "--auto-add-overlay"
      end if
      put the result into tAaptResult
      processAaptResult tAaptResult
      if tAaptResult is not empty then
         throw "could not generate package manifest"
      end if
      
      revZipOpenArchive tAssetArchive, "update"
      if the result is not empty then
         throw "could not open asset archive"
      end if
      
      addAssetsToArchive tResolvedFileData, tBaseFolder, tAssetArchive
      
      revZipCloseArchive tAssetArchive
      if the result is not empty then
         throw "asset archive creation failed"
      end if
      
      ------- Prepare the Package
      revStandaloneProgress "Preparing package..."
      
      local tUnalignedApkFile
      put tBuildFolder & slash & "lcandroid-unaligned.apk" into tUnalignedApkFile
      if there is a file tUnalignedApkFile then
         delete file tUnalignedApkFile
      end if
      
      repeat for each key tArch in tArchLibsBuildFolders
         -- MM-2014-01-29: [[ OpenSSL ]] Include the revsecurity library.
         if pSettings["android,include revsecurity"] then
            put url ("binfile:" & mapFilePath(tRuntime & slash & tArch & slash & "revsecurity")) \
                  into url ("binfile:" & tArchLibsBuildFolders[tArch] & slash & "librevsecurity.so")
            
            // SN-2015-01-22: [[ Bug 13213 ]] Throw an error in case an error occurred
            if the result is not empty then
               throw "Could not find revsecurity library"
            end if
         end if
         
         -- Copy across the externals into the libs folder
         repeat for each line tEntry in tExternals
            -- Only copy across an external from the Runtime folder if we haven't
            -- already copied from a lcext.
            if there is a file (tArchLibsBuildFolders[tArch] & slash & "lib" & tEntry & ".so") then
               next repeat
            end if
            put url ("binfile:" & mapFilePath(tRuntime & slash & tArch & slash & tEntry)) \
                  into url ("binfile:" & tArchLibsBuildFolders[tArch] & slash & "lib" & tEntry & ".so")
            // SN-2015-01-22: [[ Bug 13213 ]] Throw an error in case an error occurred
            if the result is not empty then
               throw "Could not find " & tEntry && "library"
            end if
         end repeat
         
         -- Copy across any other driver libraries into the libs folder
         repeat for each line tEntry in tDrivers
            -- Only copy across the library if it's not already there
            if there is a file (tArchLibsBuildFolders[tArch] & slash & "lib" & tEntry & ".so") then
               next repeat
            end if
            put url ("binfile:" & mapFilePath(tRuntime & slash & tArch & slash & tEntry)) \
                  into url ("binfile:" & tArchLibsBuildFolders[tArch] & slash & "lib" & tEntry & ".so")
            if the result is not empty then
               throw "Could not find " & tEntry && "library"
            end if
         end repeat
      end repeat

      -- OXT-Beyond: which key signs the package. As with LiveCode's ApkBuilder,
      -- which signed with the debug key unless told not to (-u): Test builds
      -- and builds "for development only" with the debug key; builds with a
      -- keystore chosen ("sign with my key") with that keystore; the rest
      -- ("do not sign", or no keystore chosen) not at all. When ApkBuilder
      -- left the SDK, the zip assembly below replaced it and signed nothing,
      -- so Test builds could not be installed.
      local tSigning
      if pTarget contains "build" and tUnsigned then
         if tKey is not empty then
            put "key" into tSigning
         else
            put "none" into tSigning
            if pSettings["android,signing"] is "sign with my key" then
               revStandaloneAddWarning "Android: no keystore is chosen in the Android standalone settings, so the package is not signed, and Android will not install it"
            end if
         end if
      else
         put "debug" into tSigning
      end if
      -- OXT-Beyond: the App Bundle is signed as the package is, and Google
      -- Play takes it only signed with the app's upload key
      if tBundleFile is not empty and tSigning is "debug" then
         revStandaloneAddWarning "Android: the App Bundle is signed with the debug key (" & quote & \
               "Sign for development only" & quote & "); Google Play takes it only signed with your upload key (" & \
               quote & "Sign with my key" & quote & ")"
      else if tBundleFile is not empty and tSigning is "none" then
         revStandaloneAddWarning "Android: the App Bundle is not signed; Google Play takes it only signed with your" && \
               "upload key (" & quote & "Sign with my key" & quote & ")"
      end if
      
      -- Build the APK
      // IM-2013-05-21: [[ BZ 10904 ]] call our own internal function instead of (removed) apkbuilder script
      buildAPK tUnalignedApkFile, tAssetArchive, tClassesFile, tLibsBuildFolder
      if the result is not empty then
         throw "apk preparation failed:" && the result
      end if
      
      -- OXT-Beyond: the App Bundle, from the package's files before
      -- zipalign and signing
      if tBundleFile is not empty then
         revStandaloneProgress "Making the App Bundle..."
         put tBuildFolder & slash & "lcandroid-unsigned.aab" into tUnsignedBundleFile
         androidBuildBundle tUnalignedApkFile, tUnsignedBundleFile, tBuildFolder, androidBundletoolForBuild()
      end if
      
      -- OXT-Beyond: zipalign first, then sign. A v2 or v3 signature (which
      -- Android needs for apps that target API 30 or newer) covers the whole
      -- file, and zipalign rewrites the file, so signing first and aligning
      -- after left only the old JAR signature, and Android refused the
      -- package. zipalign -p also aligns uncompressed native libraries to
      -- pages (the libraries here are compressed, so it changes nothing yet).
      revStandaloneProgress "Finalizing package..."
      
      local tAlignedApkFile
      if tSigning is "none" then
         put pApkFile into tAlignedApkFile
      else
         put tBuildFolder & slash & "lcandroid-aligned.apk" into tAlignedApkFile
      end if
      executeShellCommand pathToZipAlign(), "-f", "-p", "4", tUnalignedApkFile, tAlignedApkFile
      if (sShellStatus is not empty and sShellStatus is not 0) or there is no file tAlignedApkFile then
         throw "apk finalization failed: zipalign made no package -" && the result
      end if
      
      ------- Signing the Package
      if tSigning is not "none" then
         revStandaloneProgress "Signing package..."
         
         local tKeystoreAlias, tKeystorePassword, tPrivateKeyPassword
         if tSigning is "debug" then
            -- The SDK's debug keystore, made as Android Studio makes it when
            -- it is missing
            put pathToDebugKeystore() into tKey
            ensureDebugKeystore tKey
            put "androiddebugkey" into tKeystoreAlias
            put "android" into tKeystorePassword
            put "android" into tPrivateKeyPassword
         else
            -- OXT-Beyond: pathIsRelative, as where the key's path is made
            -- absolute above: this check took a Windows path (C:/...) for a
            -- relative one and put the stack's folder before it a second
            -- time, so on Windows a keystore was never found
            if pathIsRelative(tKey) then
               put tBaseFolder & slash before tKey
            end if
            
            if there is no file tKey then
               throw "could not file keystore '" & tKey & "'"
            end if
            
            ask "Please provide the keystore alias to use"
            if it is empty then
               throw "no keystore alias provided for keystore"
            end if
            put it into tKeystoreAlias
            
            ask password clear "Please provide the keystore password"
            if it is empty then
               throw "no password provided for keystore"
            end if
            put it into tKeystorePassword
            
            ask password clear "Please provide the private key password"
            if it is empty then
               throw "no password provided for private key"
            end if
            put it into tPrivateKeyPassword
         end if
         
         -- apksigner, which the SDK check makes sure of (every build-tools
         -- release with d8 has it). The SHA1 jarsigner fallback went with
         -- this change: it could only run with build-tools older than
         -- 24.0.3, which have no d8 either, and it made the JAR signature
         -- alone, which Android refuses for API 30 and newer. The passwords
         -- reach apksigner through the environment, not the command line,
         -- which the builder writes to stderr.
         if there is no file pathToApkSigner() then
            throw "signing failed - the Android SDK has no apksigner; install the Android SDK Build-Tools 28 or newer"
         end if
         put tKeystorePassword into $OXT_ANDROID_KS_PASS
         put tPrivateKeyPassword into $OXT_ANDROID_KEY_PASS
         executeShellCommand pathToApkSigner(), "sign", "--ks", tKey, "--ks-pass", "env:OXT_ANDROID_KS_PASS", \
               "--key-pass", "env:OXT_ANDROID_KEY_PASS", "--ks-key-alias", tKeystoreAlias, \
               "--out", pApkFile, tAlignedApkFile
         put the result into tResult
         put empty into $OXT_ANDROID_KS_PASS
         put empty into $OXT_ANDROID_KEY_PASS
         -- apksigner 30 and newer also write a v4 signature beside the
         -- package (<package>.idsig), for adb's incremental install only;
         -- the builder makes one file, as before
         if there is a file (pApkFile & ".idsig") then
            delete file (pApkFile & ".idsig")
         end if
         if (sShellStatus is not empty and sShellStatus is not 0) or there is no file pApkFile then
            throw "signing failed -" && tResult
         end if
         
         -- The signature must be one Android accepts
         executeShellCommand pathToApkSigner(), "verify", pApkFile
         put the result into tResult
         if sShellStatus is not empty and sShellStatus is not 0 then
            delete file pApkFile
            throw "signing failed - apksigner does not accept the signed package:" && tResult
         end if
         
         -- OXT-Beyond: the App Bundle, with the same key and passwords
         if tBundleFile is not empty then
            revStandaloneProgress "Signing the App Bundle..."
            put tKeystorePassword into $OXT_ANDROID_KS_PASS
            put tPrivateKeyPassword into $OXT_ANDROID_KEY_PASS
            androidSignBundle tUnsignedBundleFile, tBundleFile, tKey, tKeystoreAlias
            put the result into tResult
            put empty into $OXT_ANDROID_KS_PASS
            put empty into $OXT_ANDROID_KEY_PASS
            if tResult is not empty then
               throw tResult
            end if
         end if
      else if tBundleFile is not empty then
         put url ("binfile:" & tUnsignedBundleFile) into url ("binfile:" & tBundleFile)
         if the result is not empty then
            throw "could not write the App Bundle" && tBundleFile & ":" && the result
         end if
      end if
   catch tError
   end try
   
   if there is a file tUnalignedApkFile then delete file tUnalignedApkFile
   if tUnsignedBundleFile is not empty and there is a file tUnsignedBundleFile then delete file tUnsignedBundleFile
   if tAlignedApkFile is not pApkFile and there is a file tAlignedApkFile then delete file tAlignedApkFile
   if there is a file tAssetArchive then delete file tAssetArchive
   if there is a file tLiveCodeClassesFile then delete file tLiveCodeClassesFile
   
   repeat for each element tFolder in tArchLibsBuildFolders
      repeat for each line tFile in files(tFolder)
         delete file (tFolder & slash & tFile)
      end repeat
      if there is a folder tFolder then delete folder tFolder
   end repeat
   
   set the itemDelimiter to slash
   repeat for each line tJarFile in pSettings["jarFiles"]
      if there is a file (tLibsBuildFolder & slash & item -1 of tJarFile) then 
         delete file (tLibsBuildFolder & slash & item -1 of tJarFile)
      end if
   end repeat
   if there is a folder tLibsBuildFolder then delete folder tLibsBuildFolder
   if there is a file tClassesFile then delete file tClassesFile
   repeat for each line tClassFile in tBuiltClassFiles
      if there is a file tClassFile then delete file tClassFile
   end repeat
   repeat while there is a folder (tBuildFolder & slash & "classes_app" & slash & tCompiledClassFilePath)
      delete folder (tBuildFolder & slash & "classes_app" & slash & tCompiledClassFilePath)
      if the result is not empty then
         exit repeat
      end if
      delete the last item of tCompiledClassFilePath
   end repeat
   set the itemDelimiter to comma
   repeat for each line tFIle in tAssetFiles
      if there is a file tFile then delete file tFile
   end repeat
   if there is a folder tLayoutResBuildFolder then delete folder tLayoutResBuildFolder
   if there is a folder tDrawableResBuildFolder then delete folder tDrawableResBuildFolder
   if there is a folder tResBuildFolder then delete folder tResBuildFolder
   if there is a file tManifestFile then delete file tManifestFile
   if there is a folder tClassesBuildFolder then delete folder tClassesBuildFolder
   if there is a folder tBuildFolder then delete folder tBuildFolder
   
   if tError is not empty then
      throw tError
   end if
end revSaveAsMobileStandaloneMain

################################################################################

private function escapeLabel pLabel
   replace "&" with "&amp;" in pLabel
   replace "@" with "\@" in pLabel
   replace "?" with "\?" in pLabel
   replace "<" with "&lt;" in pLabel
   replace ">" with "&gt;" in pLabel
   replace "'" with "\'" in pLabel
   replace quote with "\" & quote in pLabel
   return pLabel
end escapeLabel
   
private command processAaptResult @xResult   
   -- MW-2012-07-04: On Linux, 'aapt' can complain about libz version info
   --   so we delete that line from the result before checking for an error.
   if line 1 of xResult contains "no version information available" then
      delete line 1 of xResult
   end if
   // SN-2014-10-27: [[ Bug 13800 ]] libpng 1.6+ raises a warning for the PNG files having embedded sRGB profile
   if line 1 of xResult contains "iCCP: Not recognizing known sRGB profile that has been edited" then
      delete line 1 of xResult
   end if
end processAaptResult

private command generateResourceClasses pBuildFolder, pResBuildFolder, \
   pManifest, @xSettings, @rGenerated
   if xSettings["aarFiles"] is empty then
      return empty
   end if
   
   local tOutputFolder, tAaptResult, tManifest
   put pBuildFolder & slash & "gen" into tOutputFolder
   revSBEnsureFolder tOutputFolder
   -- at the moment we just generate resource classes for each included aar
   repeat with x = 1 to the number of lines in xSettings["aarFiles"]
      put pBuildFolder & "/" & x & "/AndroidManifest.xml" into tManifest
      executeShellCommand pathToAapt(), "package", "-f", "-M", tManifest, \
            "-I", pathToRootClasses(), "-S", pBuildFolder & slash & x & "/res", "-J", \
            tOutputFolder & "/", "-m"
      put the result into tAaptResult
      processAaptResult tAaptResult
      if tAaptResult is not empty then
         return tAaptResult
      end if
   end repeat
   local tGenerated
   put revSBEnumerateFolder(tOutputFolder) into tGenerated
   filter tGenerated with "*/R.java"
   if tGenerated is not empty then
      repeat for each line tLine in tGenerated
         if rGenerated is empty then
            put tOutputFolder & slash &tLine into rGenerated
         else
            put return & tOutputFolder & slash & tLine after rGenerated
         end if
      end repeat
   end if
   return empty
end generateResourceClasses

private command appendToStringList pValue, @xList
   if xList is empty then
      put pValue into xList
   else
      put return & pValue after xList
   end if
end appendToStringList

private command addPlayServiceAARsToSettings  @xSettingsA
   local tPlayServicesPath
   put pathToPlayServices() into tPlayServicesPath
   
   repeat for each line tPlayService in xSettingsA["android,play dependencies"]
      local tPlayVersion
      set the itemDel to "-"
      put the last item of tPlayService into tPlayVersion
      delete the last item of tPlayService
      set the itemDel to comma
      
      local tPlayServiceAARPath
      put tPlayServicesPath & slash & \
            "play-services-" & tPlayService & slash & \
            tPlayVersion & slash & \
            "play-services-" & tPlayService & "-" & tPlayVersion & ".aar" \
            into tPlayServiceAARPath
      if there is not a file tPlayServiceAARPath then
         throw "unable to locate play service dependency" && tPlayService && "version" && tPlayVersion
      end if
      
      appendToStringList tPlayServiceAARPath, xSettingsA["aarFiles"]
   end repeat
end addPlayServiceAARsToSettings

private command expandAARsAndComputeSettings tBuildFolder, @xSettingsA
   local tCount, tDefaultFolder
   put the folder into tDefaultFolder
   repeat for each line tAAR in xSettingsA["aarFiles"]
      local tExtractFolder, tExtractCmd, tExtractedFiles
      add 1 to tCount
      put tBuildFolder & slash & tCount \
            into tExtractFolder
      revSBEnsureFolder tExtractFolder
      set the folder to tExtractFolder
      executeShellCommand pathToJar(), "xf", tAAR
      updateSettingsForExtractedAAR tExtractFolder, xSettingsA
   end repeat
   set the folder to tDefaultFolder
end expandAARsAndComputeSettings
   
constant kSupportedAARFiles = "AndroidManifest.xml,classes.jar,R.txt"   
constant kSupportedAARFolders = "res"
private command updateSettingsForExtractedAAR pFolder, @xSettingsA
   local tExtractedItem
   repeat for each item tItem in kSupportedAARFiles
      put pFolder & slash & tItem into tExtractedItem
      if there is not a file tExtractedItem then
         next repeat
      end if
      switch tItem
         case "AndroidManifest.xml"
            appendToStringList tExtractedItem, xSettingsA["androidManifests"]
            break
         case "classes.jar"
            appendToStringList tExtractedItem, xSettingsA["jarFiles"]
            break
         case "R.txt"
            -- Don't need to do anything with this
            break
      end switch
   end repeat
   repeat for each item tItem in kSupportedAARFolders
      put pFolder & slash & tItem into tExtractedItem
      if there is not a folder tExtractedItem then
         next repeat
      end if     
      switch tItem
         case "res"
            -- don't need to do anything with this- our call to aapt
            -- deals with including the res files in the APK
            break
      end switch
   end repeat
end updateSettingsForExtractedAAR

private command addAssetsToArchive pFileData, pBaseFolder, pArchive
   local tDeviceConfig, tConfigFile, tCustomConfigFile, tFonts
   
   put mapFIlePath(revMobileRuntimeFolder() & slash & "lc_device_config.txt") into tConfigFile
   if there is not a file tConfigFile then
      put empty into tConfigFile
   end if
   
   repeat for each element tFile in pFileData
      if there is a file tFile["resolved"] then
         if tConfigFile is not empty and tFile["name"] ends with "lc_device_config.txt" then
            // need to merge config files
            put tFile["resolved"] into tCustomConfigFile
         else if revSBFileIsFontFile(tFile["name"]) then
            -- MM-2012-03-07: [[ Custom fonts ]] If any fonts are found, add to the list so that they are handled correctly
            put tFile["resolved"] & return after tFonts
         else if tFile["name"] ends with ".lcext" or tFile["name"] ends with ".dylib" then
            -- MW-2012-07-05: [[ Externals ]] If an 'lcext' file or dylib file is found then we ignore it.
         else if tFile["name"] ends with "AndroidManifest.xml" then
            -- MW-2015-04-24: [[ TemplateAppMetadata ]] If an template manifest is found then we ignore it.
         else
            revZipAddUncompressedItemWithFile pArchive, "assets/" & tFile["name"], tFile["resolved"]
         end if
      else if there is a folder tFile["resolved"] then
         if not (tFile["resolved"] ends with ".lcextd") then
            addAssetsFromFolderToArchive tFile["resolved"], "assets" & slash & tFile["name"], pArchive, tFonts
         end if
      else
         throw "could not find referenced asset to include -" && tFile["resolved"]
      end if
   end repeat
   
   if tCustomConfigFile is empty then
      if tConfigFile is not empty then
         revZipAddUncompressedItemWithFile pArchive, "assets/lc_device_config.txt", tConfigFile
      end if
   else
      put url ("binfile:" & tConfigFile) & return into tDeviceConfig
      put url ("binfile:" & tCustomConfigFile) after tDeviceConfig
      revZipAddUncompressedItemWithData pArchive, "assets/lc_device_config.txt", "tDeviceConfig"
   end if
   
   -- MM-2012-03-07: [[ Custom fonts ]] Add any fonts found to the assets/fonts folder
   set the itemDel to slash
   repeat for each line tFont in tFonts
      if tFont is not empty then
         revZipAddUncompressedItemWithFile pArchive, "assets/fonts/" & item -1 of tFont, tFont
      end if
   end repeat
   set the itemDel to comma   
end addAssetsToArchive

private command addAssetsFromFolderToArchive pFolder, pBaseName, pArchive, @pFonts
   set the itemDelimiter to slash
   
   -- Ignore any .svn folders
   if the last item of pFolder is ".svn" then
      exit addAssetsFromFolderToArchive
   end if

   if char -1 of pFolder is slash then
      delete char -1 of pFolder
   end if
   
   local tOldFolder
   put the folder into tOldFolder
   set the folder to pFolder
   if the folder is not pFolder then
      throw "could not descend into referenced asset folder -" && pFolder
   end if
   
   repeat for each line tFile in the files
      if revSBFileIsFontFile(tFile) then
         -- MM-2012-03-07: [[ Custom fonts ]] If any fonts are found, add to the list so that they are handled correctly
         put the folder & slash & tFile & return after pFonts
      else if tFile ends with ".lcext" or tFile ends with ".dylib" then
         -- MW-2012-07-05: [[ Externals ]] If an 'lcext' file or dylib file is found then we ignore it.
      else
         revZipAddUncompressedItemWithFile pArchive, pBaseName & slash & tFile, the folder & slash & tFile
      end if
   end repeat
   
   repeat for each line tFolder in the folders
      if tFolder is ".." then
         next repeat
      end if
      
      addAssetsFromFolderToArchive pFolder & slash & tFolder, pBaseName & slash & tFolder, pArchive, pFonts
   end repeat
   
   set the folder to tOldFolder
end addAssetsFromFolderToArchive

################################################################################

private function fileIsZipArchive pFile
   open file pFile for binary read
   if the result is empty then
      read from file pFile for 4 bytes
      close file pFile
   end if
   if it is empty then
      throw "could not open external -" && pFile
   end if
   
   return byte 1 of it is "P" and byte 2 of it is "K" and byte 3 of it is numToChar(3) and byte 4 of it is numToChar(4)
end fileIsZipArchive

-- MERG-2013-09-05: [[ Bug 11152 ]]  Change to function - returns true if external was successfully
--   extracted.
private function addExternalFromFile pExternal, pClassesFolder, pArchLibsFolders
   -- If the file is not a zip archive then there is nothing to do.
   if not fileIsZipArchive(pExternal) then
      exit addExternalFromFile
   end if
   
   -- Get the name of the external.
   local tExternalName
   set the itemDelimiter to slash
   get the last item of pExternal
   set the itemDelimiter to "."
   put the first item of it into tExternalName
   set the itemDelimiter to slash
   
   -- Compute the class / lib names.
   local tClassesFile, tLibFileA
   put pClassesFolder & slash & "lib" & tExternalName & ".jar" into tClassesFile
   
   -- Otherwise open the archive and check for appropriate android components
   revZipOpenArchive pExternal, "read"
   if the result is empty then
      
      -- MERG-2015-10-14: [[ ThirdpartyLibs ]] Add support for thirdparty librares
      local tZipItems
      put revZipEnumerateItems(pExternal) into tZipItems
      filter tZipItems with "Android/*"
      
      local tZipItemsFiltered
      filter tZipItems with regex pattern ".*(\.jar|Classes)$" into tZipItemsFiltered
      repeat for each line tZipItem in tZipItemsFiltered
         if tZipItem ends with ".jar" then
            revZipExtractItemToFile pExternal, tZipItem, \
                  pClassesFolder & slash & the last item of tZipItem 
         else 
            # will be Classes file
            revZipExtractItemToFile pExternal, tZipItem, tClassesFile
         end if
      end repeat
      
      repeat for each key tArch in pArchLibsFolders
         local tPattern
         put "^Android/(?:External-" & tArch & "|lib.+" & tArch & "\.so)$" into tPattern
         filter tZipItems with regex pattern tPattern into tZipItemsFiltered
         put pArchLibsFolders[tArch] & slash & "lib" & tExternalName & ".so" into tLibFileA[tArch]
         
         repeat for each line tZipItem in tZipItemsFiltered
            if tZipItem ends with ".so" then
               revZipExtractItemToFile pExternal, tZipItem, \
                     pArchLibsFolders[tArch] & slash & the last item of tZipItem 
            else 
               # will be External-<Arch> file
               revZipExtractItemToFile pExternal, tZipItem, tLibFileA[tArch]
            end if
         end repeat
      end repeat
      
      revZipCloseArchive pExternal
   end if
   
   if there is a file tClassesFile then
      repeat for each key tArch in pArchLibsFolders
         if there is no file tLibFileA[tArch] then
            throw "android external contains classes but no library for " & tArch
         end if
      end repeat
   end if
   
   return tLibFileA is an array
end addExternalFromFile

private function addExternalFromFolder pExternal, pClassesFolder, pArchLibsFolders
   -- Get the name of the external.
   local tExternalName
   set the itemDelimiter to slash
   get the last item of pExternal
   set the itemDelimiter to "."
   put the first item of it into tExternalName
   set the itemDelimiter to slash
   
   -- Compute the class / lib names.
   local tClassesFile, tLibFileA
   put pClassesFolder & slash & "lib" & tExternalName & ".jar" into tClassesFile
   
   local tItems
   put files(pExternal & "/Android") into tItems
   
   local tItemsFiltered
   filter tItems with regex pattern ".*(\.jar|Classes)$" into tItemsFiltered
   repeat for each line tItem in tItemsFiltered
      if tItem ends with ".jar" then
         revSBCopyFile pExternal & "/Android/" & tItem, \
               pClassesFolder & slash & the last item of tItem 
      else 
         # will be Classes file
         revSBCopyFile pExternal & "/Android/" & tItem, \
               tClassesFile
      end if
   end repeat
   
   repeat for each key tArch in pArchLibsFolders
      local tPattern
      put "^(?:External-" & tArch & "|lib.+" & tArch & "\.so)$" into tPattern
      filter tItems with regex pattern tPattern into tItemsFiltered
      put pArchLibsFolders[tArch] & slash & "lib" & tExternalName & ".so" into tLibFileA[tArch]
      repeat for each line tItem in tItemsFiltered
         if tItem ends with ".so" then
            revSBCopyFile pExternal & "/Android/" & tItem, \
                  pClassesFolder & slash & the last item of tItem 
         else 
            # will be External-<Arch> file
            revSBCopyFile pExternal & "/Android/" & tItem, \
                  tLibFileA[tArch]
         end if
      end repeat
   end repeat
   
   if there is a file tClassesFile then
      repeat for each key tArch in pArchLibsFolders
         if there is no file tLibFileA[tArch] then
            throw "android external contains classes but no library for " & tArch
         end if
      end repeat
   end if
   
   return tLibFileA is an array
end addExternalFromFolder

################################################################################

function revMobileRuntimeFolder pTarget
   local tOverridePath, tUserPath
   
   // IM-2013-12-16: [[ Bug 11594 ]] Check override is not empty to avoid accidentally detecting "/Android" path
   if revOverrideRuntimePath() is not empty then
      put revOverrideRuntimePath() & slash & "Android" into tOverridePath
      if there is a folder tOverridePath then
         return tOverridePath
      end if
   end if
   
   // IM-2013-12-16: [[ Bug 11594 ]] Check override is not empty to avoid accidentally detecting "/Android" path
   if revEnvironmentUserRuntimePath() is not empty then
      put revEnvironmentUserRuntimePath() & slash & "Android" into tUserPath
      if there is a folder tUserPath then
         return tUserPath
      end if
   end if
   
   return revEnvironmentRuntimePath() & slash & "Android"
end revMobileRuntimeFolder

-- OXT-Beyond: the Android runtime a build takes its engines and the rest
-- from. The stack's "android,engine" setting picks it: empty or "9.6.3"
-- (the default) is LiveCode Community 9.6.3's engine, Runtime/Android, as
-- before; "beyond" is the engine built from OXT-Beyond's own source with
-- a current NDK (a preview), which the runtimes carry beside it as a whole
-- runtime of its own, Runtime/Android/Beyond (its engine and externals for
-- each architecture, and its Java layer, manifest and the files beside
-- them, as tools/ci/build-android.sh lays them out). A stack that asks for
-- that engine of runtimes without it is not built with the other one: the
-- build stops and says so, as it does for any other value
function androidRuntimeFolder pTarget, pSettings
   local tRuntime
   put revMobileRuntimeFolder(pTarget) into tRuntime
   switch pSettings["android,engine"]
      case empty
      case "9.6.3"
         return tRuntime
      case "beyond"
         if there is not a folder (tRuntime & slash & "Beyond") then
            throw "The stack asks for OXT-Beyond's own Android engine (android,engine is beyond), and these runtimes do not have it:" && tRuntime & slash & "Beyond"
         end if
         return tRuntime & slash & "Beyond"
      default
         throw "Unknown Android engine" && quote & pSettings["android,engine"] & quote && "(android,engine): it is empty or 9.6.3 for LiveCode 9.6.3's, or beyond for OXT-Beyond's own"
   end switch
end androidRuntimeFolder

################################################################################

private command executeAdbCommand pCommand
   local tAdb
   put pathToAdb() into tAdb
   if tAdb is empty or there is not a file tAdb then
      exit executeAdbCommand
   end if
   
   get doShellCommand(tAdb, pCommand)
   
   return it
end executeAdbCommand

private command appendToList pValue, @xList
   get the number of elements in xList
   put pValue into xList[it + 1]
end appendToList

private command prependToList pValue, @xList
   insertIntoList pValue, xList, 1
end prependToList

private command insertIntoList pValue, @xList, pAt
   local tNewList
   repeat with x = the number of elements in xList down to 1
      if x >= pAt then
         put xList[x] into tNewList[x+1]
      else
         put xList[x] into tNewList[x]
      end if
   end repeat
   put pValue into tNewList[pAt]
   put tNewList into xList
end insertIntoList
   
private command executeShellCommand
   local tArray
   repeat with i = 2 to the paramCount
      appendToList param(i), tArray
   end repeat
   
   executeShellCommandWithParams param(1), tArray
   return the result
end executeShellCommand

private command executeShellCommandWithParams pCommand, pParamArray
   local tShell
   repeat for each element tParam in pParamArray
      if tParam contains space and not (tParam begins with "-") then
         put quote & tParam & quote into tParam
      end if   
      put tParam & space after tShell
   end repeat
   
   get doShellCommand(pCommand, tShell)
   
   return it
end executeShellCommandWithParams

private function doShellCommand pCommand, pArguments
   --makeBuildLogEntry "Executing command:" && pCommand && pArguments
   
   local tCommandPath
   set the itemDelimiter to slash
   put item 1 to -2 of pCommand into tCommandPath
   if the platform is "win32" then
      put shortFilePath(tCommandPath) into tCommandPath
   end if
   
   local tOldPath
   put $PATH into tOldPath
   if the platform is "win32" then
      replace slash with backslash in tCommandPath
      put tCommandPath & ";" & sJavaRoot & "\bin" & ";" before $PATH
   else if the platform is "macos" then
      put tCommandPath & ":" before $PATH
   else if the platform is "linux" then
      put tCommandPath & ":" & sJavaRoot & "/bin" & ":" before $PATH
   end if
   
   -- OXT-Beyond: and JAVA_HOME, which the SDK's scripts read before the
   -- PATH, names that JDK too when it is at least as new (see
   -- androidJavaHomeFor)
   local tOldJavaHome, tJavaHome, tSetJavaHome
   put $JAVA_HOME into tOldJavaHome
   put androidJavaHomeFor(sJavaRoot, tOldJavaHome) into tJavaHome
   put tJavaHome is not tOldJavaHome into tSetJavaHome
   if tSetJavaHome then
      if the platform is "win32" then
         replace slash with backslash in tJavaHome
      end if
      put tJavaHome into $JAVA_HOME
   end if
   
   set the hideConsoleWindows to true
   write item -1 of pCommand && pArguments & return to stderr
   get shell(item -1 of pCommand && pArguments)
   -- OXT-Beyond: the command's exit status (empty for 0), for the steps
   -- that print nothing on success and something else on failure
   put the result into sShellStatus
   
   put tOldPath into $PATH
   if tSetJavaHome then
      put tOldJavaHome into $JAVA_HOME
   end if
   
   return it
end doShellCommand

################################################################################

constant kDeployLibrary = "revDeployLibraryAndroid"
private function targetSDKVersion
   dispatch function "deployTargetSdkVersion" to stack kDeployLibrary
   return the result
end targetSDKVersion

private function newestTargetSDKVersion
   dispatch function "deployNewestTargetSdkVersion" to stack kDeployLibrary
   return the result
end newestTargetSDKVersion

-- OXT-Beyond: the API a package targets, its manifest's targetSdkVersion,
-- which decides how Android treats the app (Google Play takes only the
-- newest). A stack may pin one, "android,target sdk", from the API the
-- builder has always targeted (33) to the newest it knows (36), as for a
-- package that is not for Google Play; a pin outside that is an error.
-- Otherwise it is the newest when the runtime's Java layer is ready for
-- it, and 33, as before, when it is not (androidJavaLayerIsReady)
function androidTargetAPI pSettings, pRuntimeFolder
   local tPin
   put pSettings["android,target sdk"] into tPin
   if tPin is not empty then
      if tPin is not an integer or tPin < targetSDKVersion() or tPin > newestTargetSDKVersion() then
         throw "the stack's Android target API (" & tPin & ") is not one the builder can make: from" && \
               targetSDKVersion() && "to" && newestTargetSDKVersion()
      end if
      return tPin + 0
   end if
   if androidJavaLayerIsReady(pRuntimeFolder) then
      return newestTargetSDKVersion()
   end if
   return targetSDKVersion()
end androidTargetAPI

-- OXT-Beyond: whether the runtime's Java layer (its Classes jar) is ready
-- for the newest target: it sends the back callback to the stack's backKey
-- (Android 16 calls nothing else for an app that targets 36) and keeps the
-- stack out of the system bars (Android 15 and newer draw an app that
-- targets 35 edge to edge). LiveCode Community 9.6.3's layer, which the
-- runtimes carried until the layer was built from OXT-Beyond's source, has
-- neither, and throws on its PendingIntents at target 31 and newer. A jar
-- keeps its entries' names as they are, so the names are looked for in it
constant kJavaLayerReady = "com/runrev/android/LiveCodeActivity$BackCallback.class,com/runrev/android/LiveCodeActivity$SystemBarsPadding.class"
function androidJavaLayerIsReady pRuntimeFolder
   return androidJavaLayerHas(pRuntimeFolder, kJavaLayerReady)
end androidJavaLayerIsReady

-- OXT-Beyond: Android 16 and newer ignore an app's orientation and its
-- resizability on large screens (600 dp wide and more) once it targets
-- API 36. This property keeps them, as the stack's settings give them,
-- until an app targets 37 (the engine does not yet lay a stack out again
-- for every size and rotation a tablet may give it). Below 36 the manifest
-- is left as it was
constant kRestrictedResizability = "android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"
function androidKeepLargeScreenLayout pManifest, pTargetAPI
   if pTargetAPI < 36 then
      return pManifest
   end if
   local tProperty
   put "  <property android:name=" & quote & kRestrictedResizability & quote && \
         "android:value=" & quote & "true" & quote && "/>" & return into tProperty
   if pManifest contains "</application>" then
      replace "</application>" with tProperty & "  </application>" in pManifest
   end if
   return pManifest
end androidKeepLargeScreenLayout

-- OXT-Beyond: the configuration changes the app's activity goes on
-- through (its manifest's android:configChanges), where Android would
-- otherwise end it and make it again. The engine runs once in a process
-- (com.runrev.android.RelaunchActivity says why): made again in the same
-- process, it stopped there on Android 11 and newer, for an app that
-- targets API 30 or newer (which the builder always makes), as soon as the
-- user changed the font size, the language or the bold text setting,
-- attached a keyboard, or resized the app's window.
--
-- LiveCode's four, as before: the keyboard shown or hidden, a rotation,
-- night mode (which the engine passes on as systemAppearanceChanged) and
-- the screen's size (the stack is resized, as for a rotation). Then those
-- that come with a window resized (smallestScreenSize, screenLayout, as
-- Android asks of an app that handles screenSize), and those that change
-- nothing the engine has read: the font size and weight (the engine draws
-- its own text, at the sizes the stack gives), the language and its
-- direction (the engine asks for them as it needs them), a keyboard or
-- navigation device attached, the touch screen, the display's colour
-- mode, and the SIM's country and network.
--
-- Not the screen's density (the display size setting): the engine reads it
-- as it starts, so the app starts again for it (RelaunchActivity), in a
-- new process, as for a change no value can name (the theme overlays that
-- Android 12 and newer make of the wallpaper). Every value is one that
-- Android 12L's attributes know (API 32), below the oldest target (33)
constant kConfigChanges = "keyboardHidden|orientation|uiMode|screenSize|smallestScreenSize|screenLayout|fontScale|fontWeightAdjustment|locale|layoutDirection|keyboard|navigation|touchscreen|colorMode|mcc|mnc"
function androidConfigChanges
   return kConfigChanges
end androidConfigChanges

-- OXT-Beyond: the activity that starts the app again in a new process
-- (com.runrev.android.RelaunchActivity), declared in a process of its own
-- where the runtime's Java layer has it (LiveCode Community 9.6.3's has
-- not; the app's activity then starts the engine again as before). It has
-- no intent filter, so no other app can start it
constant kRelaunchClass = "com/runrev/android/RelaunchActivity.class"
function androidDeclareRelaunch pManifest, pRuntimeFolder
   if not androidJavaLayerHas(pRuntimeFolder, kRelaunchClass) then
      return pManifest
   end if
   local tActivity
   put "  <activity android:name=" & quote & "com.runrev.android.RelaunchActivity" & quote & return & \
         "      android:process=" & quote & ":relaunch" & quote & return & \
         "      android:theme=" & quote & "@android:style/Theme.Translucent.NoTitleBar" & quote & return & \
         "      android:excludeFromRecents=" & quote & "true" & quote & return & \
         "      android:noHistory=" & quote & "true" & quote & return & \
         "      android:exported=" & quote & "false" & quote && "/>" & return into tActivity
   if pManifest contains "</application>" then
      replace "</application>" with tActivity & "  </application>" in pManifest
   end if
   return pManifest
end androidDeclareRelaunch

-- OXT-Beyond: an adaptive launcher icon, which Android 8.0 and newer draw
-- in the launcher's own shape (a circle, a squircle, a rounded square) and
-- move in its animations: a foreground image over a background colour,
-- each a layer of 108 by 108 dp of which the launcher shows the middle 72
-- (a circle 66 dp across always), so the foreground keeps what matters in
-- its middle two thirds, with clear space around it. With a monochrome
-- image too it is a themed icon on Android 13 and newer, which the
-- launcher tints with the wallpaper's colours when the user turns themed
-- icons on (only the image's alpha counts: a white shape on clear space).
-- The standalone settings:
--    "android,adaptive icon"             the foreground, a PNG file (a path
--                                        relative to the stack's folder, or
--                                        a full path): 432 by 432 pixels
--                                        draws it sharp on every screen
--    "android,adaptive icon background"  "#RRGGBB", "#AARRGGBB" or "r,g,b";
--                                        white when empty
--    "android,themed icon"               the monochrome image, a PNG file
--                                        (needs the foreground)
-- The adaptive icon takes the name of the icon ("@drawable/icon", for
-- Android 8.0 and newer only: drawable-anydpi-v26), so the manifest names
-- the same icon as before; the stack's icon ("android,icon") stays the one
-- older Android shows, or the foreground when the stack has none. A stack
-- that names no foreground is built as before. Returns the array that
-- androidAddAdaptiveIcon takes (foreground, monochrome: the files;
-- background: the colour as #AARRGGBB), or empty
constant kAdaptiveIcon = "android,adaptive icon"
constant kAdaptiveIconBackground = "android,adaptive icon background"
constant kThemedIcon = "android,themed icon"
function androidAdaptiveIcon pSettings, pBaseFolder
   local tIcon, tKey, tPath
   if pSettings[kAdaptiveIcon] is empty then
      if pSettings[kThemedIcon] is not empty then
         throw "a themed icon is the monochrome layer of an adaptive icon: name its foreground image too" && \
               "(the" && quote & kAdaptiveIcon & quote && "standalone setting)"
      end if
      return empty
   end if
   repeat for each item tKey in "foreground,monochrome"
      if tKey is "foreground" then
         put pSettings[kAdaptiveIcon] into tPath
      else
         put pSettings[kThemedIcon] into tPath
      end if
      if tPath is empty then
         put empty into tIcon[tKey]
         next repeat
      end if
      if pathIsRelative(tPath) then
         put pBaseFolder & slash before tPath
      end if
      if there is no file tPath then
         throw "the adaptive icon's" && tKey && "image is not there:" && tPath
      end if
      if byte 1 to 8 of url ("binfile:" & tPath) is not \
            numToByte(137) & "PNG" & numToByte(13) & numToByte(10) & numToByte(26) & numToByte(10) then
         throw "the adaptive icon's" && tKey && "image is not a PNG file:" && tPath
      end if
      put tPath into tIcon[tKey]
   end repeat
   put androidIconColour(pSettings[kAdaptiveIconBackground]) into tIcon["background"]
   return tIcon
end androidAdaptiveIcon

-- A colour of the standalone settings as Android's resources write it
-- (#AARRGGBB): "#RRGGBB", "#AARRGGBB" or "r,g,b" (each 0 to 255); white
-- when empty. Anything else stops the build, saying what it takes
function androidIconColour pColour
   local tHex, tPart
   put word 1 to -1 of pColour into pColour
   if pColour is empty then
      return "#FFFFFFFF"
   end if
   if char 1 of pColour is "#" then
      put toUpper(char 2 to -1 of pColour) into tHex
      if tHex is not empty and matchText(tHex, "^([0-9A-F]{6}|[0-9A-F]{8})$") then
         if the number of chars of tHex is 6 then
            put "FF" before tHex
         end if
         return "#" & tHex
      end if
   else if the number of items of pColour is 3 then
      put "#FF" into tHex
      repeat for each item tPart in pColour
         put word 1 to -1 of tPart into tPart
         if tPart is not an integer or tPart < 0 or tPart > 255 then
            put empty into tHex
            exit repeat
         end if
         put format("%02X", tPart) after tHex
      end repeat
      if tHex is not empty then
         return tHex
      end if
   end if
   throw "the adaptive icon's background colour" && quote & pColour & quote && \
         "is not one the build can read: give it as #RRGGBB, #AARRGGBB or r,g,b"
end androidIconColour

-- The adaptive icon's resource (drawable-anydpi-v26/icon.xml): the
-- background colour (a colour resource, values/oxt_icon_background.xml),
-- the foreground and, when there is one, the monochrome image
-- (drawable-nodpi: each drawn at the layer's size, not scaled for the
-- screen's density first)
function androidAdaptiveIconXML pIcon
   local tXML
   put "<?xml version=" & quote & "1.0" & quote && "encoding=" & quote & "utf-8" & quote & "?>" & lf & \
         "<adaptive-icon xmlns:android=" & quote & "http://schemas.android.com/apk/res/android" & quote & ">" & lf & \
         "    <background android:drawable=" & quote & "@color/oxt_icon_background" & quote & "/>" & lf & \
         "    <foreground android:drawable=" & quote & "@drawable/icon_foreground" & quote & "/>" & lf into tXML
   if pIcon["monochrome"] is not empty then
      put "    <monochrome android:drawable=" & quote & "@drawable/icon_monochrome" & quote & "/>" & lf after tXML
   end if
   put "</adaptive-icon>" & lf after tXML
   return tXML
end androidAdaptiveIconXML

function androidAdaptiveIconColourXML pIcon
   return "<?xml version=" & quote & "1.0" & quote && "encoding=" & quote & "utf-8" & quote & "?>" & lf & \
         "<resources>" & lf & \
         "    <color name=" & quote & "oxt_icon_background" & quote & ">" & pIcon["background"] & "</color>" & lf & \
         "</resources>" & lf
end androidAdaptiveIconColourXML

-- Writes the adaptive icon's resources (androidAdaptiveIcon's array) into
-- the package's res folder
command androidAddAdaptiveIcon pIcon, pResFolder
   local tFolder, tKey
   repeat for each item tFolder in "drawable-nodpi,drawable-anydpi-v26,values"
      if there is no folder (pResFolder & slash & tFolder) then
         create folder (pResFolder & slash & tFolder)
      end if
      if there is no folder (pResFolder & slash & tFolder) then
         throw "could not create the folder" && pResFolder & slash & tFolder
      end if
   end repeat
   repeat for each item tKey in "foreground,monochrome"
      if pIcon[tKey] is empty then
         next repeat
      end if
      put url ("binfile:" & pIcon[tKey]) into url ("binfile:" & pResFolder & "/drawable-nodpi/icon_" & tKey & ".png")
      if the result is not empty then
         throw "could not copy the adaptive icon's" && tKey && "image '" & pIcon[tKey] & "'"
      end if
   end repeat
   put textEncode(androidAdaptiveIconXML(pIcon), "UTF-8") into url ("binfile:" & pResFolder & "/drawable-anydpi-v26/icon.xml")
   if the result is not empty then
      throw "could not write the adaptive icon:" && the result
   end if
   put textEncode(androidAdaptiveIconColourXML(pIcon), "UTF-8") into url ("binfile:" & pResFolder & "/values/oxt_icon_background.xml")
   if the result is not empty then
      throw "could not write the adaptive icon's background colour:" && the result
   end if
end androidAddAdaptiveIcon

-- OXT-Beyond: a stack whose "android,edge to edge" standalone setting is
-- true (the Android card's "Edge to edge" box) is drawn edge to edge, on
-- Android 11 and newer: under the see-through status and navigation bars
-- and into the display's cutout, the keyboard still resizing it. The
-- manifest asks the Java layer for it with this meta-data of the
-- application (LiveCodeActivity.asksForEdgeToEdge), which a layer without
-- drawEdgeToEdge (LiveCode Community 9.6.3's, and the runtimes' before
-- it) would not read, so the build stops there instead of making an app
-- that is not what the stack asks for. Any other stack's manifest is left
-- as it was
constant kEdgeToEdge = "com.runrev.android.EDGE_TO_EDGE"
constant kEdgeToEdgeClass = "com/runrev/android/LiveCodeActivity$EdgeToEdge.class"
function androidAskForEdgeToEdge pManifest, pSettings, pRuntimeFolder
   if pSettings["android,edge to edge"] is not true then
      return pManifest
   end if
   if not androidJavaLayerHas(pRuntimeFolder, kEdgeToEdgeClass) then
      throw "the stack asks to be drawn edge to edge (android,edge to edge), and the Android runtime's Java" && \
            "layer cannot draw it so: update the runtimes, or untick Edge to edge on the Android card"
   end if
   local tMetaData
   put "  <meta-data android:name=" & quote & kEdgeToEdge & quote && \
         "android:value=" & quote & "true" & quote && "/>" & return into tMetaData
   if pManifest contains "</application>" then
      replace "</application>" with tMetaData & "  </application>" in pManifest
   end if
   return pManifest
end androidAskForEdgeToEdge

-- OXT-Beyond: whether the runtime's Java layer (its Classes jar) has each
-- of the class files pClasses (a list of items), by their names, which a
-- jar keeps as they are
function androidJavaLayerHas pRuntimeFolder, pClasses
   local tJar
   put mapFilePath(pRuntimeFolder & slash & "Classes") into tJar
   if there is no file tJar then
      return false
   end if
   put url ("binfile:" & tJar) into tJar
   repeat for each item tEntry in pClasses
      if byteOffset(textEncode(tEntry, "UTF-8"), tJar) is 0 then
         return false
      end if
   end repeat
   return true
end androidJavaLayerHas

################################################################################
-- OXT-Beyond: the Android App Bundle (.aab), which Google Play takes for new
-- apps and updates and makes each device's packages from. A stack whose
-- "android,app bundle" standalone setting is true gets one beside its
-- package (androidBundlePath), from the same build: the package is made
-- and signed as before, the bundle is made from its files before zipalign
-- (androidBuildBundle) and signed with the same key (androidSignBundle).
-- Test builds never make one, and a stack without the setting builds as
-- before.
--
-- Google's bundletool makes the bundle. It is a Java program, which the
-- JDK the builder already uses runs: this version, downloaded once into
-- the IDE's cache folder and checked against its SHA-256 each time it is
-- used (androidBundletool). For a machine without the internet, the
-- cMobileSupport["android.bundletool"] of stack "revPreferences" can name
-- a copy, or this file can be put in the cache folder by hand.
constant kBundletoolVersion = "1.18.3"
constant kBundletoolURL = "https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar"
constant kBundletoolSHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
-- How many times a download that fails is tried, 2 seconds apart: with
-- libURL, then with the JDK's own HTTP client, and so on in turn
constant kBundletoolTries = 3

-- The App Bundle beside the package pApkFile: its name with .aab for .apk
function androidBundlePath pApkFile
   if pApkFile ends with ".apk" then
      delete char -4 to -1 of pApkFile
   end if
   return pApkFile & ".aab"
end androidBundlePath

-- Where the builder keeps the bundletool it downloads
function androidBundletoolCacheFile
   return revEnvironmentUserCachePath() & "/Android/bundletool-all-" & kBundletoolVersion & ".jar"
end androidBundletoolCacheFile

-- The bundletool a build runs (androidBundletool, with the Preferences'
-- copy, this version and the build's JDK)
function androidBundletoolForBuild
   return androidBundletool(the cMobileSupport["android.bundletool"] of stack "revPreferences", \
         androidBundletoolCacheFile(), kBundletoolURL, kBundletoolSHA256, pathToJava())
end androidBundletoolForBuild

-- The bundletool jar to run: pPreference as it is, when it names one;
-- otherwise pCacheFile when its SHA-256 is pSHA256, after downloading it
-- from pURL when it is missing or not that file, with libURL and, when
-- pJava names the JDK's java, with that too (androidDownloadWithJava).
-- Throws, saying what to do, when there is none. (Parameters, not the
-- constants, so that tools/ci/android-check.livecodescript can try every
-- case.)
function androidBundletool pPreference, pCacheFile, pURL, pSHA256, pJava
   if pPreference is not empty then
      if there is no file pPreference then
         throw "the cMobileSupport[" & quote & "android.bundletool" & quote & "] of stack " & quote & \
               "revPreferences" & quote && "names" && pPreference & ", and there is no such file"
      end if
      return pPreference
   end if
   if there is a file pCacheFile then
      if androidFileSHA256(pCacheFile) is pSHA256 then
         return pCacheFile
      end if
      -- not the file this builder takes (a download cut short, or another
      -- version): downloaded again
      delete file pCacheFile
   end if

   local tData, tResult, tError, tTimeout, tHex, tFolder, tTries, tPart, tJavaResult
   revStandaloneProgress "Downloading Google's bundletool, which makes the App Bundle (once)..."
   put the socketTimeoutInterval into tTimeout
   -- libURL gives up on a server that sends nothing for this long
   set the socketTimeoutInterval to 60000
   -- and a download that fails is tried again, 2 seconds later, up to
   -- kBundletoolTries times, with the JDK's own HTTP client when there is
   -- one, and libURL, in turn. libURL's download of this file from GitHub's
   -- release assets stalled (its "socket timeout") once on the Android
   -- builder check's Linux runner (run 42315551744), and three times in a
   -- row on its macOS runner (run 42321580394), where gh had just
   -- downloaded the release from that host in seconds. (The pause lets
   -- messages through, as libURL's own waits do.)
   put specialFolderPath("temporary") & "/oxt-bundletool-" & the milliseconds & ".part" into tPart
   put 0 into tTries
   repeat kBundletoolTries times
      add 1 to tTries
      if tTries > 1 then
         wait 2 seconds with messages
         revStandaloneProgress "Downloading Google's bundletool again (try" && tTries && "of" && kBundletoolTries & ")..."
      end if
      put empty into tData
      put empty into tResult
      if tTries mod 2 is 0 and pJava is not empty then
         put androidDownloadWithJava(pJava, pURL, tPart) into tResult
         put tResult into tJavaResult
         if tResult is empty then
            put url ("binfile:" & tPart) into tData
         end if
         if there is a file tPart then
            delete file tPart
         end if
      else
         try
            put url pURL into tData
            put the result into tResult
         catch tError
            put tError into tResult
         end try
      end if
      if tResult is empty and tData is empty then
         put "nothing came" into tResult
      end if
      if tResult is empty then
         exit repeat
      end if
   end repeat
   set the socketTimeoutInterval to tTimeout
   if tResult is not empty then
      -- (and what the JDK said, when libURL had the last try)
      if tJavaResult is not empty and tJavaResult is not tResult then
         put "; and" && tJavaResult after tResult
      end if
      put " (tried" && tTries && "times)" after tResult
   end if
   if tResult is empty then
      get binaryDecode("H*", messageDigest(tData, "SHA-256"), tHex)
      if tHex is not pSHA256 then
         put "it is not the file this builder takes (its SHA-256 is" && tHex & ", not" && pSHA256 & ")" into tResult
      end if
   end if
   if tResult is not empty then
      throw "could not download bundletool, which makes the App Bundle, from" && pURL & ":" && tResult & \
            ". Download that file and put it at" && pCacheFile & ", or name a bundletool jar in the" && \
            "cMobileSupport[" & quote & "android.bundletool" & quote & "] of stack " & quote & "revPreferences" & quote
   end if
   set the itemDelimiter to slash
   put item 1 to -2 of pCacheFile into tFolder
   set the itemDelimiter to comma
   revSBEnsureFolder tFolder
   put tData into url ("binfile:" & pCacheFile)
   if the result is not empty then
      throw "could not keep bundletool at" && pCacheFile & ":" && the result
   end if
   return pCacheFile
end androidBundletool

-- The SHA-256 of a file, in lower case hex
function androidFileSHA256 pFile
   local tHex
   get binaryDecode("H*", messageDigest(url ("binfile:" & pFile), "SHA-256"), tHex)
   return tHex
end androidFileSHA256

-- Downloads pURL into the file pFile with the JDK whose java is pJava,
-- through its own HTTP client: it follows redirects, uses the system's
-- proxy settings, and gives up on a server that sends nothing for 60
-- seconds (androidDownloadJavaSource, which java runs as it is, from a
-- file in the temporary folder). Returns empty, or what went wrong
function androidDownloadWithJava pJava, pURL, pFile
   local tSource, tOutput, tStatus
   put specialFolderPath("temporary") & "/oxt-download-" & the milliseconds & ".java" into tSource
   put textEncode(androidDownloadJavaSource(), "UTF-8") into url ("binfile:" & tSource)
   if the result is not empty then
      return "could not write" && tSource & ":" && the result
   end if
   if there is a file pFile then
      delete file pFile
   end if
   executeShellCommand pJava, "-Djava.net.useSystemProxies=true", tSource, pURL, pFile
   put the result into tOutput
   put sShellStatus into tStatus
   delete file tSource
   if (tStatus is not empty and tStatus is not 0) or there is no file pFile then
      if there is a file pFile then
         delete file pFile
      end if
      return "the JDK could not download it:" && androidToolError(tOutput)
   end if
   return empty
end androidDownloadWithJava

-- The Java program androidDownloadWithJava runs: java <its file> <URL>
-- <file>. Any failure prints one line that starts "Error:" and exits 1
function androidDownloadJavaSource
   local tLines
   put "import java.io.IOException;" & lf & \
         "import java.io.InputStream;" & lf & \
         "import java.net.HttpURLConnection;" & lf & \
         "import java.net.URL;" & lf & \
         "import java.net.URLConnection;" & lf & \
         "import java.nio.file.Files;" & lf & \
         "import java.nio.file.Paths;" & lf & \
         "import java.nio.file.StandardCopyOption;" & lf & \
         "public class OxtDownload {" & lf & \
         "  public static void main(String[] args) {" & lf & \
         "    try {" & lf & \
         "      URLConnection connection = new URL(args[0]).openConnection();" & lf & \
         "      connection.setConnectTimeout(60000);" & lf & \
         "      connection.setReadTimeout(60000);" & lf & \
         "      if (connection instanceof HttpURLConnection) {" & lf & \
         "        HttpURLConnection http = (HttpURLConnection) connection;" & lf & \
         "        if (http.getResponseCode() != 200) {" & lf & \
         "          throw new IOException(http.getResponseCode() + " & quote & " " & quote & \
         " + http.getResponseMessage() + " & quote & " from " & quote & " + http.getURL());" & lf & \
         "        }" & lf & \
         "      }" & lf & \
         "      try (InputStream in = connection.getInputStream()) {" & lf & \
         "        Files.copy(in, Paths.get(args[1]), StandardCopyOption.REPLACE_EXISTING);" & lf & \
         "      }" & lf & \
         "    } catch (Exception e) {" & lf & \
         "      System.err.println(" & quote & "Error: " & quote & " + e);" & lf & \
         "      System.exit(1);" & lf & \
         "    }" & lf & \
         "  }" & lf & \
         "}" & lf into tLines
   return tLines
end androidDownloadJavaSource

-- Where a file of the package aapt2 convert made goes in the bundle's base
-- module, or empty for one the bundle leaves out. bundletool takes the
-- manifest and the code each in a folder of its own, resources.pb, res/,
-- assets/ and lib/ as they are, and the other files of the package's top
-- level under root/. The jar files of AAR libraries, which the builder
-- puts at the top of lib/ (their classes are in classes.dex, and Android
-- never reads them), are left out: bundletool takes nothing under lib/ but
-- native libraries, in a folder for each ABI.
function androidBundleModulePath pPath
   if pPath is "AndroidManifest.xml" then
      return "manifest/AndroidManifest.xml"
   end if
   if pPath is "resources.pb" or pPath begins with "res/" or pPath begins with "assets/" then
      return pPath
   end if
   set the itemDelimiter to slash
   if pPath begins with "lib/" then
      if the number of items of pPath < 3 then
         return empty
      end if
      return pPath
   end if
   if the number of items of pPath is 1 and pPath begins with "classes" and pPath ends with ".dex" then
      return "dex/" & pPath
   end if
   return "root/" & pPath
end androidBundleModulePath

-- bundletool's settings for the bundle (its BundleConfig.json). The engine
-- loads externals from the app's native library folder and opens the
-- stack's files at their place in the installed package (Engine.java's
-- getLibraryPath and getAssetFileStartOffset), as with the .apk: so the
-- native libraries stay compressed, for Android to extract when it
-- installs the app, as before (bundletool otherwise leaves them in the
-- package, where the engine does not look), and the files under assets/
-- stay stored, as addAssetsToArchive stores them.
function androidBundleConfig
   return "{" & lf & \
         "  " & quote & "optimizations" & quote & ": {" & lf & \
         "    " & quote & "uncompressNativeLibraries" & quote & ": { " & quote & "enabled" & quote & ": false }" & lf & \
         "  }," & lf & \
         "  " & quote & "compression" & quote & ": {" & lf & \
         "    " & quote & "uncompressedGlob" & quote & ": [ " & quote & "assets/**" & quote & " ]" & lf & \
         "  }" & lf & \
         "}" & lf
end androidBundleConfig

-- The lines of a tool's output that say what went wrong (bundletool's
-- error comes before its Java stack trace), or its last lines
private function androidToolError pOutput
   local tLines
   filter lines of pOutput with "*Error*" into tLines
   if tLines is empty then
      put line -3 to -1 of pOutput into tLines
   end if
   replace return with " " in tLines
   return tLines
end androidToolError

-- Makes the App Bundle pBundleFile, unsigned, from the package pApkFile (as
-- buildAPK made it, before zipalign and signing), with the bundletool jar
-- pBundletool: aapt2 turns the package's manifest and resources into the
-- form a bundle holds (aapt2 convert), its files go into a base module
-- (androidBundleModulePath), and bundletool makes the bundle of that
-- (build-bundle, with androidBundleConfig). Its files in pBuildFolder are
-- deleted again. Throws what went wrong
private command androidBuildBundle pApkFile, pBundleFile, pBuildFolder, pBundletool
   local tProtoFile, tModuleFile, tConfigFile, tResult, tError, tItems, tItem, tPath, tData
   put pBuildFolder & slash & "lcandroid-proto.apk" into tProtoFile
   put pBuildFolder & slash & "base.zip" into tModuleFile
   put pBuildFolder & slash & "BundleConfig.json" into tConfigFile
   try
      if there is no file pathToAapt2() then
         throw "the App Bundle needs aapt2, and the Android SDK's build-tools have none (" & pathToAapt2() & \
               "): install the Android SDK Build-Tools again"
      end if
      executeShellCommand pathToAapt2(), "convert", "--output-format", "proto", "-o", tProtoFile, pApkFile
      put the result into tResult
      if (sShellStatus is not empty and sShellStatus is not 0) or there is no file tProtoFile then
         throw "aapt2 could not convert the package for the App Bundle:" && androidToolError(tResult)
      end if

      -- the base module, every file stored (bundletool compresses the bundle)
      revZipOpenArchive tProtoFile, "read"
      if the result is not empty then
         throw "could not open" && tProtoFile & ":" && the result
      end if
      put revZipEnumerateItems(tProtoFile) into tItems
      revZipOpenArchive tModuleFile, "write"
      if the result is not empty then
         put "could not make" && tModuleFile & ":" && the result into tError
      end if
      repeat for each line tItem in tItems
         if tError is not empty then
            exit repeat
         end if
         if tItem is empty or tItem ends with slash then
            next repeat
         end if
         put androidBundleModulePath(tItem) into tPath
         if tPath is empty then
            next repeat
         end if
         put empty into tData
         revZipExtractItemToVariable tProtoFile, tItem, "tData"
         if the result is not empty then
            put "could not read" && tItem && "from the package:" && the result into tError
            exit repeat
         end if
         revZipAddUncompressedItemWithData tModuleFile, tPath, "tData"
         if the result is not empty then
            put "could not add" && tPath && "to the base module:" && the result into tError
         end if
      end repeat
      put empty into tData
      revZipCloseArchive tProtoFile
      revZipCloseArchive tModuleFile
      if tError is empty and the result is not empty then
         put "could not write" && tModuleFile & ":" && the result into tError
      end if
      if tError is not empty then
         throw tError
      end if

      put textEncode(androidBundleConfig(), "UTF-8") into url ("binfile:" & tConfigFile)
      if there is a file pBundleFile then
         delete file pBundleFile
      end if
      executeShellCommand pathToJava(), "-jar", pBundletool, "build-bundle", "--modules", tModuleFile, \
            "--config", tConfigFile, "--output", pBundleFile
      put the result into tResult
      if (sShellStatus is not empty and sShellStatus is not 0) or there is no file pBundleFile then
         throw "bundletool could not make the App Bundle:" && androidToolError(tResult)
      end if
   catch tError
   end try
   if there is a file tProtoFile then delete file tProtoFile
   if there is a file tModuleFile then delete file tModuleFile
   if there is a file tConfigFile then delete file tConfigFile
   if tError is not empty then
      if there is a file pBundleFile then delete file pBundleFile
      throw tError
   end if
end androidBuildBundle

-- Signs the App Bundle pUnsignedFile into pBundleFile with the key pAlias
-- of pKeystore, whose passwords are in $OXT_ANDROID_KS_PASS and
-- $OXT_ANDROID_KEY_PASS, as the package's are. A bundle carries a JAR
-- signature, which Google Play checks against the app's upload key; the
-- JDK's jarsigner makes it (apksigner signs only packages). jarsigner says
-- what it found in English for the check below (it answers 0 for a file
-- with no signature too, and -strict refuses a self-signed key, which an
-- upload key is). Returns empty, or what went wrong
private command androidSignBundle pUnsignedFile, pBundleFile, pKeystore, pAlias
   local tResult
   if there is no file pathToJarSigner() then
      return "signing the App Bundle failed - the JDK has no jarsigner (" & pathToJarSigner() & ")"
   end if
   if there is a file pBundleFile then
      delete file pBundleFile
   end if
   executeShellCommand pathToJarSigner(), "-J-Duser.language=en", "-keystore", pKeystore, \
         "-storepass:env", "OXT_ANDROID_KS_PASS", "-keypass:env", "OXT_ANDROID_KEY_PASS", \
         "-signedjar", pBundleFile, pUnsignedFile, pAlias
   put the result into tResult
   if (sShellStatus is not empty and sShellStatus is not 0) or there is no file pBundleFile then
      return "signing the App Bundle failed -" && androidToolError(tResult)
   end if
   executeShellCommand pathToJarSigner(), "-J-Duser.language=en", "-verify", pBundleFile
   put the result into tResult
   if (sShellStatus is not empty and sShellStatus is not 0) or not (tResult contains "jar verified") then
      delete file pBundleFile
      return "signing the App Bundle failed - jarsigner does not verify the signed bundle:" && androidToolError(tResult)
   end if
   return empty
end androidSignBundle

private function pathToRootClasses pRoot
   dispatch function "pathToRootClasses" to stack kDeployLibrary with pRoot
   return the result
end pathToRootClasses

private function pathToSDKClasses pRoot
   dispatch function "pathToSDKClasses" to stack kDeployLibrary with pRoot
   return the result
end pathToSDKClasses

private function pathToCommonClasses pRoot
   dispatch function "pathToCommonClasses" to stack kDeployLibrary with pRoot
   return the result
end pathToCommonClasses

private function pathToAapt pRoot
   dispatch function "pathToAapt" to stack kDeployLibrary with pRoot
   return the result
end pathToAapt

private function pathToAapt2 pRoot
   dispatch function "pathToAapt2" to stack kDeployLibrary with pRoot
   return the result
end pathToAapt2

private function pathToAdb pRoot
   dispatch function "pathToAdb" to stack kDeployLibrary with pRoot
   return the result
end pathToAdb

private function pathToZipAlign pRoot
   dispatch function "pathToZipAlign" to stack kDeployLibrary with pRoot
   return the result
end pathToZipAlign

// SN-2015-07-02: [[ GypifiedAndroid ]] Get the right folder for android binaries
private function pathToRepoAndroidBinaries pArch
   local tBuild
   if revEnvironmentBinariesPath() contains "/Debug" then
      put "Debug" into tBuild
   else
      put "Release" into tBuild
   end if
   return revEnvironmentRepositoryPath() & "/build-android-" & pArch & "/livecode/out/" & tBuild
end pathToRepoAndroidBinaries

private function pathToDex pRoot
   dispatch function "pathToDex" to stack kDeployLibrary with pRoot
   return the result
end pathToDex

private function pathToJavaC pRoot
   dispatch function "pathToJavaC" to stack kDeployLibrary with pRoot
   return the result
end pathToJavaC

private function pathToJava pRoot
   dispatch function "pathToJava" to stack kDeployLibrary with pRoot
   return the result
end pathToJava

private function pathToJarSigner pRoot
   dispatch function "pathToJarSigner" to stack kDeployLibrary with pRoot
   return the result
end pathToJarSigner

private function pathToApkSigner pRoot
   dispatch function "pathToApkSigner" to stack kDeployLibrary with pRoot
   return the result
end pathToApkSigner

private function pathToKeytool pRoot
   dispatch function "pathToKeytool" to stack kDeployLibrary with pRoot
   return the result
end pathToKeytool

private function pathToDebugKeystore
   dispatch function "deployDebugKeystore" to stack kDeployLibrary
   return the result
end pathToDebugKeystore

private function checkSDK pRoot
   dispatch function "deployCheckSDK" to stack kDeployLibrary with pRoot
   return the result
end checkSDK

-- OXT-Beyond: makes the SDK's debug keystore when it is missing, with the
-- name, passwords and certificate the Android SDK's tools give it
-- (androiddebugkey, android, android, CN=Android Debug,O=Android,C=US), so
-- that it is the same keystore Android Studio would make there
private command ensureDebugKeystore pKeystore
   if there is a file pKeystore then
      exit ensureDebugKeystore
   end if
   local tFolder
   set the itemDelimiter to slash
   put item 1 to -2 of pKeystore into tFolder
   set the itemDelimiter to comma
   if there is no folder tFolder then
      revSBEnsureFolder tFolder
   end if
   executeShellCommand pathToKeytool(), "-genkeypair", "-keystore", pKeystore, \
         "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey", \
         "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", \
         "-dname", "CN=Android Debug,O=Android,C=US"
   if there is no file pKeystore then
      throw "could not make the debug keystore" && pKeystore && "with keytool:" && the result
   end if
end ensureDebugKeystore

private function pathToJar pRoot
   dispatch function "pathToJar" to stack kDeployLibrary with pRoot
   return the result
end pathToJar

private function pathToPlayServices pRoot
   dispatch function "pathToPlayServices" to stack kDeployLibrary with pRoot
   return the result
end pathToPlayServices

################################################################################

-- MW-2013-06-13: [[ CloneAndRun ]] Map a file path from where the sb expects them to be to local
--   files in the build folder.
function mapFilePath pPath
   if revEnvironmentIsInstalled() then
      // SN-2015-01-19: [[ Bug 13213 ]] Linux filepaths are case-sensitive.
      //   so we try to caselessly match the targetted file, with the actual files.
      set the itemDelimiter to slash
      
      // Get the list of files in the targetted directory
      local tOldFolder, tFiles
      put the defaultFolder into tOldFolder
      set the defaultFolder to item 1 to -2 of pPath
      
      put the files into tFiles
      set the defaultFolder to tOldFolder
      
      local tLineOffset
      put lineOffset(last item of pPath, tFiles) into tLineOffset
      
      // We return empty if we can't find the specified file
      // That will allow us to throw an error in such a case.
      if tLineOffset is 0 then
         return empty
      else
         put line tLineOffset of tFiles into item -1 of pPath
      end if
      return pPath
   end if
   
   local tPath
   local tBinariesFolder, tComponent, tSuffix
   local tArch, tFoundArch
   repeat for each item tItem in revSBPlatformArchitectures("Android")
      if pPath contains ("/" & __ArchABI(tItem) & "/") then
         put tItem into tArch
      end if

      if tFoundArch is empty and \
            there is a folder pathToRepoAndroidBinaries(tItem) then
         put tItem into tFoundArch
      end if
   end repeat

   if tArch is empty then
      put tFoundArch into tArch
   end if

   put pathToRepoAndroidBinaries(tArch) into tBinariesFolder
   
   // SN-2015-07-02: [[ GypifiedAndroid ]] Throw an error if there is
   //  not the expected build folder
   if there is no folder tBinariesFolder then
      throw "Error: Android binaries folder" && tBinariesFolder && "could not be found"
   end if
   
   set the itemDelimiter to slash
   put the last item of pPath into tComponent
   
   if the editionType is "community" then
      put "Community" into tSuffix
   else
      put "Commercial" into tSuffix
   end if
   
   switch tComponent
      case "notify_icon.png"
         put merge("[[tBinariesFolder]]/notify_icon.png") into tPath
         break
      case "Manifest.xml"
         put merge("[[tBinariesFolder]]/Manifest.xml") into tPath
         break
      case "nfc_tech_filter.xml"
         put merge("[[tBinariesFolder]]/nfc_tech_filter.xml") into tPath
         break
      case "file_provider_paths.xml"
         put merge("[[tBinariesFolder]]/file_provider_paths.xml") into tPath
         break
      case "livecode_inputcontrol.xml"
         put merge("[[tBinariesFolder]]/livecode_inputcontrol.xml") into tPath
         break
      case "Classes"
         put merge("[[tBinariesFolder]]/Classes-[[tSuffix]]") into tPath
         break
      case "Standalone"
         put merge("[[tBinariesFolder]]/Standalone-[[tSuffix]]") into tPath
         break
      case "revzip"
         put merge("[[tBinariesFolder]]/RevZip") into tPath
         break
      case "revdb"
         put merge("[[tBinariesFolder]]/RevDb") into tPath
         break
      case "revxml"
         put merge("[[tBinariesFolder]]/RevXml") into tPath
         break
      case "dbsqlite"
         put merge("[[tBinariesFolder]]/DbSqlite") into tPath
         break
      case "dbmysql"
         put merge("[[tBinariesFolder]]/DbMysql") into tPath
         break
      case "revsecurity"
         put merge("[[tBinariesFolder]]/RevSecurity") into tPath
         break
      case "revpdfprinter"
         put merge("[[tBinariesFolder]]/RevPdfPrinter") into tPath
         break
      default
         put pPath into tPath
         break
   end switch
   
   return tPath
end mapFilePath

################################################################################

function androidCreateAppManifest pMainManifest, pAdditionalManifestsA
   local tMainArrayA, tAdditionalArraysA
   put androidManifestToArray(pMainManifest) into tMainArrayA
   repeat for each element tManifest in pAdditionalManifestsA
      appendToList androidManifestToArray(tManifest), tAdditionalArraysA
   end repeat
   
   MergeManifestArrays tMainArrayA, tAdditionalArraysA
   return ConvertArrayToXML(tMainArrayA, "utf-8")
end androidCreateAppManifest

command MergeManifestArrays @xManifestArrayA, pAdditionalsA
   -- Warning: at the moment we only support merging of
   -- features, permissions, and application metadata
   repeat for each element tAdditionalA in pAdditionalsA
      -- everything we're interested in comes under the 
      -- manifest root node.
      MergeManifestArray xManifestArrayA[1]["@children"], tAdditionalA[1]["@children"]
   end repeat
end MergeManifestArrays

private function FindIndex pArray, pName
   repeat for each key tIndex in pArray
      if pArray[tIndex]["@name"] is pName then
         return tIndex
      end if
   end repeat
   throw "no index found for" && pName
end FindIndex

private function FindEndOfBlockIndex pArray
   local tIndex
   repeat for each key tIndex in pArray
      if pArray[tIndex]["@children"] is not empty then
         exit repeat
      end if
   end repeat
   return tIndex
end FindEndOfBlockIndex

command MergeManifestArray @xManifestArrayA, pAdditionalsA
   -- Find the index of the end of this block and insert new items
   -- before it
   local tEndOfBlock
   put FindEndOfBlockIndex(xManifestArrayA) into tEndOfBlock
   repeat for each key tIndex in pAdditionalsA
      local tData
      put pAdditionalsA[tIndex] into tData
      switch tData["@name"] 
         case "application"
            -- Find the index of the application sub-array
            local tAppIndex
            put FindIndex(xManifestArrayA, "application") into tAppIndex
            MergeManifestArray xManifestArrayA[tAppIndex]["@children"], \
                  tData["@children"]
            break
         case "uses-sdk"
            -- ensure the maximum min sdk is used
            -- Find the index of the uses-sdk element
            local tUsesSDKIndex
            put FindIndex(xManifestArrayA, "uses-sdk") into tUsesSDKIndex
            local tExisting, tNew
            put xManifestArrayA[tUsesSDKIndex]["@attributes"]["android:minSDKVersion"] \
                  into tExisting
            put tData["@attributes"]["android:minSDKVersion"] into tNew
            put max(tExisting, tNew) into \
                  xManifestArrayA[tUsesSDKIndex]["@attributes"]["android:minSDKVersion"]
            break
         case "activity"
            local tActivityIndex
            put FindIndex(xManifestArrayA, "activity") into tActivityIndex
            local tExistingA, tNewA
            put xManifestArrayA[tActivityIndex]["@attributes"] \
                  into tExistingA
            put tData["@attributes"] into tNewA
            repeat for each line tKey in the keys of tNewA
               // do not merge the "theme", "name" and "exported" attributes
               if tKey is "android:theme" or tKey is "android:name" or tKey is "android:exported" then
                  next repeat
               end if
               put tNewA[tKey] into tExistingA[tKey]
            end repeat
            put tExistingA into xManifestArrayA[tActivityIndex]["@attributes"]
            if tData["@children"] is an array then
               MergeManifestArray xManifestArrayA[tActivityIndex]["@children"], \
                     tData["@children"]
            end if
            break
         default
            insertIntoList tData, xManifestArrayA, tEndOfBlock
            add 1 to tEndOfBlock
            break
      end switch
   end repeat
end MergeManifestArray

function androidManifestToArray pManifestFile
   local tXML
   put url("binfile:" & pManifestFile) into tXML
   return ConvertXMLToArray(tXML, "utf-8", true, "")
end androidManifestToArray

-- OXT-Beyond: the activities, activity-aliases, services and receivers of a
-- manifest (as androidManifestToArray returns it) that have an intent-filter
-- and no android:exported, one per line as "<kind> <name>". Apps that target
-- Android 12 (API 31) or newer cannot be installed with any of them.
function androidComponentsWithoutExported pManifestA
   local tList
   repeat for each element tNodeA in pManifestA[1]["@children"]
      if tNodeA["@name"] is not "application" then
         next repeat
      end if
      repeat for each element tComponentA in tNodeA["@children"]
         if tComponentA["@name"] is not among the items of "activity,activity-alias,service,receiver" then
            next repeat
         end if
         if "android:exported" is among the lines of the keys of tComponentA["@attributes"] then
            next repeat
         end if
         local tHasFilter
         put false into tHasFilter
         repeat for each element tChildA in tComponentA["@children"]
            if tChildA["@name"] is "intent-filter" then
               put true into tHasFilter
               exit repeat
            end if
         end repeat
         if tHasFilter then
            put tComponentA["@name"] && tComponentA["@attributes"]["android:name"] & return after tList
         end if
      end repeat
   end repeat
   delete the last char of tList
   return tList
end androidComponentsWithoutExported

-- OXT-Beyond: Google Play refuses an app whose native code includes a 32-bit
-- ABI without its 64-bit partner (armv7 needs arm64, x86 needs x86_64).
-- pArchABIsA is keyed by ABI folder name. Warns, never changes the build.
command androidWarnMissing64Bit pArchABIsA
   if pArchABIsA["armeabi-v7a"] and not pArchABIsA["arm64-v8a"] then
      revStandaloneAddWarning "Android: the app is built for armv7 and not arm64," && \
            "and Google Play only accepts it with its 64-bit build;" && \
            "tick arm64 in the Android standalone settings"
   end if
   if pArchABIsA["x86"] and not pArchABIsA["x86_64"] then
      revStandaloneAddWarning "Android: the app is built for x86 and not x86_64," && \
            "and Google Play only accepts it with its 64-bit build;" && \
            "tick x86_64 in the Android standalone settings"
   end if
end androidWarnMissing64Bit

-- OXT-Beyond: an extension's native code lives in <extension>/code/<arch>-android/.
-- When an extension has code for some of the chosen architectures (pArchs,
-- comma separated) and not others, the app fails on the devices that pick an
-- architecture it lacks. pCodeResources is the list of code files the
-- standalone settings collected. Warns, never changes the build.
command androidWarnMissingExtensionCode pArchs, pCodeResources
   -- The settings list code only for the chosen architectures, so an
   -- extension with no code for any of them is not seen here.
   local tHasA, tExtension, tItem
   set the itemDelimiter to slash
   repeat for each line tFile in pCodeResources
      -- the last "code" folder: the path above it may hold another
      repeat with tItem = the number of items of tFile down to 2
         if item tItem of tFile ends with "-android" and item (tItem - 1) of tFile is "code" then
            put item 1 to (tItem - 2) of tFile into tExtension
            put true into tHasA[tExtension][char 1 to -9 of item tItem of tFile]
            exit repeat
         end if
      end repeat
   end repeat
   
   set the itemDelimiter to comma
   repeat for each key tExtension in tHasA
      local tMissing
      put empty into tMissing
      repeat for each item tArch in pArchs
         if not tHasA[tExtension][tArch] then
            put tArch & ", " after tMissing
         end if
      end repeat
      if tMissing is not empty then
         delete char -2 to -1 of tMissing
         set the itemDelimiter to slash
         revStandaloneAddWarning "Android: the extension" && item -1 of tExtension && \
               "has no native code for" && tMissing & \
               ", so the app will fail on devices that use it;" && \
               "untick it in the Android standalone settings or update the extension"
         set the itemDelimiter to comma
      end if
   end repeat
end androidWarnMissingExtensionCode

-- OXT-Beyond: the JAVA_HOME that the SDK's d8 and apksigner get. They are
-- scripts that start the java of JAVA_HOME when it is set (the .bat files
-- of Windows and the shell scripts alike), and otherwise the first java on
-- the PATH, where doShellCommand puts the JDK chosen in Preferences first.
-- A JAVA_HOME left at an older Java than that JDK defeated it: on GitHub's
-- Windows runners (JAVA_HOME at Java 8, Preferences at JDK 17) d8 failed
-- with "UnsupportedClassVersionError: com/android/tools/r8/D8 has been
-- compiled by a more recent version of the Java Runtime". The JDK of
-- Preferences, pJdk, takes JAVA_HOME's place only when it is at least as
-- new as the one pJavaHome names, by the JAVA_VERSION of their release
-- files, so no script gets an older Java than it did before. An unset
-- JAVA_HOME, or one whose version cannot be read, is left as it is.
function androidJavaHomeFor pJdk, pJavaHome
   if pJdk is empty or pJavaHome is empty then
      return pJavaHome
   end if
   local tJdkVersion, tHomeVersion
   put javaMajorVersion(pJdk) into tJdkVersion
   put javaMajorVersion(pJavaHome) into tHomeVersion
   if tJdkVersion is empty or tHomeVersion is empty then
      return pJavaHome
   end if
   if tJdkVersion >= tHomeVersion then
      return pJdk
   end if
   return pJavaHome
end androidJavaHomeFor

-- The major version of the JDK at pRoot, from its release file
-- (JAVA_VERSION="17.0.20" is 17, JAVA_VERSION="1.8.0_462" is 8), or empty
private function javaMajorVersion pRoot
   local tFile, tText, tVersion, tLine, i
   put pRoot into tFile
   replace backslash with slash in tFile
   put "/release" after tFile
   if there is no file tFile then
      return empty
   end if
   put url ("file:" & tFile) into tText
   replace numToChar(13) with empty in tText
   repeat for each line tLine in tText
      if tLine begins with "JAVA_VERSION=" then
         put char 14 to -1 of tLine into tVersion
         exit repeat
      end if
   end repeat
   replace quote with empty in tVersion
   set the itemDelimiter to "."
   if item 1 of tVersion is "1" then
      put item 2 of tVersion into tVersion
   else
      put item 1 of tVersion into tVersion
   end if
   set the itemDelimiter to comma
   -- "21-ea" and the like
   repeat with i = 1 to the number of chars of tVersion
      if char i of tVersion is not in "0123456789" then
         delete char i to -1 of tVersion
         exit repeat
      end if
   end repeat
   if tVersion is empty or tVersion is not an integer then
      return empty
   end if
   return tVersion
end javaMajorVersion

/*
Handlers for converting XML text to LiveCode arrays and vice versa. 
Based on an implementation by Trevor DeVore of Blue Mango Learning Systems.
*/

/**
Converts an XML tree into a LiveCode multi-dimensional array.

Parameters:
pXML: The xml to convert.
pStoreEncodedAs: 
Encoding to use. Must be a value that can be passed to textEncode. Default is "utf-8".
*/
function ConvertXMLToArray pXML, pStoreEncodedAs
   local theArray,theResult,theRootNode,theTreeID
   local theXMLEncoding, tVersion
   
   ## Create an XML tree from XML text
   put revCreateXMLTreeWithNamespaces(pXML, true, true, false) into theTreeID
   
   if theTreeID is an integer then
      ## Determine the encoding of the XML, default to UTF-8
      put matchText(pXML, "<?xml (.)encoding=" & quote & "([^" & quote & "])", tVersion, theXMLEncoding) into theResult
      if theXMLEncoding is empty then put "utf-8" into theXMLEncoding
      
      ## Now convert to array. 
      ## The 1st dimension has one key which is the name of the root node.
      put revXMLRootNode(theTreeID) into theRootNode
      if theRootNode is not empty and not(theRootNode begins with "xmlerr,") then
         put ConvertXMLNodeToArray(theTreeID, theRootNode, theXMLEncoding, pStoreEncodedAs) \
               into theArray[1]
         put theRootNode into theArray[1]["@name"]
      end if
      
      revDeleteXMLTree theTreeID
   end if
   
   return theArray
end ConvertXMLToArray


/**
Converts a revXML created XML Tree to an array.
Parameters:
pXMLTree: The xml tree id.
pStoreEncodedAs: See docs for ConvertXMLToArray.

Description:
See docs for ConvertXMLToArray.
*/
function ConvertXMLTreeToArray pXMLTree, pStoreEncodedAs
   return ConvertXMLToArray(revXMLText(pXMLTree), pStoreEncodedAs)
end ConvertXMLTreeToArray


/**
Converts a multi-dimensional array to an XML tree.
Parameters:
pArray: The array to convert.
pArrayEncoding: Encoding used in the array. Must be a value that can be passed to textDecode.
pStoreEncodedAs: Encoding to use. Must be a value that can be passed to textEncode. Default is "utf-8".

Description:
The array should be keyed numerically, in order of appearance of nodes.
pArray[1] is assumend to be the root node in the XML tree.
each node is an array with three possible keys, 
- @name (required): The name of the node
- @attributes: The attributes of the node, stored as an array of 
  name/value pairs
- @children: A numerically keyed array of child nodes
- @value: The text value of the node
Returns: Text of the XML represented by the array, or error message.
*/
function ConvertArrayToXML pArray, pArrayEncoding, pStoreEncodedAs
   local theError,theRootNode,theXML,theXMLTree
   
   ## if pArrayEncoding is empty then current platform encoding is assumed
   if pStoreEncodedAs is empty then put "UTF-8" into pStoreEncodedAs
   
   ## Create XML for root node. Note that we take extra steps in order to support
   ## converting an array that only represents part of a tree rather than the entire tree.
   ## In this case there may be multiple nodes at the root level.
   put pArray[1]["@name"] into theRootNode 
   put "<" & theRootNode & "/>" into theXML
   
   local tEncoding
   ## Create XML needed to create tree
   put format("<?xml version=\"1.0\" encoding=\"%s\"?>", \
         pStoreEncodedAs) into tEncoding
   put tEncoding before theXML
   put revCreateXMLTreeWithNamespaces(theXML, true, true, false) into theXMLTree
   
   if theXMLTree is an integer then
      ## Loop over all nodes at root level
      ## Create tree using helper function
      local tName
      repeat for each element tNode in pArray
         put tNode["@name"] into tName
         replace space with "-" in tName
         ConvertArrayDimensionToXML tNode, theXMLTree, slash & tName, \
               tName, pArrayEncoding, pStoreEncodedAs
         put the result into theError
         
         if theError is not empty then exit repeat
      end repeat
      
      if theError is not empty then
         ## something went wrong, clean bad tree
         revDeleteXMLTree theXMLTree
      end if
   else
      put theXMLTree into theError
   end if
   
   if theError is not empty then
      return theError for error
   else
      return tEncoding & return & \
            revXMLText(theXMLTree, theRootNode, true) \
            for value
   end if
end ConvertArrayToXML
 
private command ConvertArrayDimensionToXML pArray, pTreeID, pNode, pName, pArrayEncoding, pStoreEncodedAs
   local theError,theKey,theKeys,tName
   put pName into tName
   repeat for each key tKey in pArray
      if tKey is "@name" then next repeat
      ## Look for attributes. These will be added as attributes to pNode.
      if tKey is "@attributes" or tKey is "@attr" then
         repeat for each key theKey in pArray[tKey]
            local theAttr
            put theKey into theAttr
            replace space with "-" in theAttr
            
            revSetXMLAttribute pTreeID, pNode, theAttr, \
                  EncodeString(pArray[tKey][theKey], \
                  pArrayEncoding, pStoreEncodedAs)
            if the result begins with "xmlerr," then 
               put the result && "(setting attribute" && theKey && "for node" && pNode & ")" into theError
            end if
            
            if theError is not empty then exit repeat
         end repeat
         
      else if tKey is "@value" then
         ## This XML tree is using complex structure. Node is the value of the parent node
         revPutIntoXMLNode pTreeID, pNode, EncodeString(pArray[tKey], pArrayEncoding, pStoreEncodedAs)
         if the result begins with "xmlerr," then
            put the result && "(adding child node" && tName && "to node" && pNode & ")" into theError
         end if
         
      else if tKey is "@children" then
         local tCounts
         repeat for each element tChildNode in pArray[tKey]
            add 1 to tCounts[tChildNode["@name"]]
            ## Node has children. Add node to XML tree then call self recursivly to create children nodes. 
            revAddXMLNode pTreeID, pNode, tChildNode["@name"], empty
            if the result begins with "xmlerr," then
               put the result && "(adding node" && tName & ")" into theError
            end if
            
            if theError is empty then
               ConvertArrayDimensionToXML tChildNode, pTreeID, \
                     pNode & slash & tChildNode["@name"] & "[" & tCounts[tChildNode["@name"]] & "]", \
                     tChildNode["@name"], pArrayEncoding, pStoreEncodedAs
               put the result into theError
            end if
         end repeat
      else
         ## Node has no children but possibly a value. Create node and add value (which may be empty).
         revAddXMLNode pTreeID, pNode, tKey, \
               EncodeString(pArray[tKey], pArrayEncoding, pStoreEncodedAs)
         if the result begins with "xmlerr," then
            put the result && "(adding child node" && tKey && "to node" && pNode & ")" into theError
         end if
      end if
      if theError is not empty then exit repeat
   end repeat
   
   return theError
end ConvertArrayDimensionToXML
 
private function ConvertXMLNodeToArray pTreeID, pNode, pXMLTreeEncoding, pStoreEncodedAs
   local theArrayA,theAttributes,theChildNode,theKey
   
   ## Look for attributes of the node. Store as array in "@attributes" key
   put revXMLAttributes(pTreeID, pNode, tab, cr) into theAttributes
   if theAttributes is not empty then
      put EncodeString(theAttributes, pXMLTreeEncoding, pStoreEncodedAs) into theAttributes
      split theAttributes by cr and tab -- create array
      put theAttributes into theArrayA["@attributes"]
   end if
   
   ## Look for children nodes. 
   set the itemDelimiter to slash
   put revXMLFirstChild(pTreeID, pNode) into theChildNode
   if theChildNode is empty or theChildNode begins with "xmlerr," then
      local theValue
      put EncodeString(revXMLNodeContents(pTreeID, pNode), pXMLTreeEncoding, pStoreEncodedAs) into theValue
      if word 1 to -1 of theValue is empty and the keys of theArrayA is not empty then
         ## Empty node that has attributes
         return theArrayA
         ## Force value into @value
         put theValue into theArrayA["@value"]
         return theArrayA
      end if
   else
      ## Child nodes were found. Recursively call self and store result in array.
      set the wholeMatches to true
      local tIndex
      repeat while theChildNode is not empty and not (theChildNode begins with "xmlerr,")
         add 1 to tIndex
         put the last item of theChildNode into theKey
         set the itemdelimiter to "["
         if the number of items in theKey > 1 then
            put item 1 to -2 of theKey into theKey
         end if    
         set the itemdelimiter to slash
         put ConvertXMLNodeToArray(pTreeID, theChildNode, pXMLTreeEncoding, pStoreEncodedAs) into theArrayA["@children"][tIndex]
         put theKey into theArrayA["@children"][tIndex]["@name"]
         put revXMLNextSibling(pTreeID, theChildNode) into theChildNode
      end repeat
      
      return theArrayA
   end if
end ConvertXMLNodeToArray
 
private function EncodeString pString, pInEncoding, pOutEncoding
   if pInEncoding is pOutEncoding then
      return pString
   end if
   
   if pInEncoding is not empty then
      -- if pOutEncoding is empty then pString will be converted to the current platform encoding
      put textDecode(pString, pInEncoding) into pString
   end if
   
   if pOutEncoding is not empty then
      -- if pInEncoding is empty then pString is assumed to be in the current platform encoding
      put textEncode(pString, pOutEncoding) into pString
   end if
   
   return pString
end EncodeString
