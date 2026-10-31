script "revStandaloneSettingsMacBehavior"
on preOpenCard   
   local tStandaloneSettingsA
   put getSettings() into tStandaloneSettingsA
   
   -- MM-2014-03-21: [[ PPC Support Dropped ]] Remove any references to Universal or PPC builds in standalone settings
   --   and replace with Intel.
   
   if tStandaloneSettingsA["MacOSX"] then
      delete variable tStandaloneSettingsA["MacOSX"]
      put true into tStandaloneSettingsA["MacOSX x86-64"]
   end if
   
   if tStandaloneSettingsA["MacOSX PowerPC-32"] then
      delete variable tStandaloneSettingsA["MacOSX x86-64"]
      put true into tStandaloneSettingsA["MacOSX x86-32"]
   end if
   
   
   -- tperry 25-09-2025
   -- add support for ARM64 universal builds
   -- only available when building on MacOS
   put the platform into myplat
   --put "mac" into myplat -- for testing mac build options when dev'ing on other OS's
   
   enable btn "MacOS-IntelArmUniversal"
   enable btn "MacOSX x86-64"
   
   if myplat contains "mac" then
      put "true" into isMac
      put the systemversion into myAccSys
      replace "." with return in myAccSys
      if word 1 of line 1 of myAccSys is "12" or line 1 of myAccSys >11 then
         enable btn "MacOS-IntelArmUniversal"
         disable btn "MacOSX x86-32"
         put false into tStandaloneSettingsA["MacOSX x86-32"] -- turn this off (depreciated)
         set the hilite of btn "MacOSX x86-32" to false
         send mouseup to group "Flavors" of card "OS X" of this stack
         set the tooltip of btn "MacOSX x86-32" to "Disabled, as OXT-Beyond has no 32-bit Mac engine to build with."
         show btn "compatnote"
         hide btn "compat2"
         
      else
         enable btn "MacOS-IntelArmUniversal"
         -- OXT-Beyond: disabled here too, as there is no 32-bit Mac engine to
         -- build with. A stack still set to 32-bit Intel keeps its setting,
         -- which the box shows, and the standalone builder builds it for
         -- 64-bit Intel Macs instead (revSBRemove32BitMacFromSettings in
         -- revsblibrary)
         disable btn "MacOSX x86-32"
         set the tooltip of btn "MacOSX x86-32" to "Disabled, as OXT-Beyond has no 32-bit Mac engine to build with."
         hide btn "compatnote"
         show btn "compat2"
         
         if tStandaloneSettingsA["MacOSX x86-32"] then
            set the hilite of btn "MacOSX x86-32" to true
         else
            set the hilite of btn "MacOSX x86-32" to false
         end if
      end if
      set the enabled of group "OSX" to true
   else
      
      -- we aren't on a mac, so it's pointless trying this (no lipo cmd)
      put "false" into isMac
      disable btn "MacOS-IntelArmUniversal"
      -- OXT-Beyond: nor is there a 32-bit Mac engine, as its tooltip says
      -- here too
      disable btn "MacOSX x86-32"
      set the tooltip of btn "MacOSX x86-32" to "Disabled, as OXT-Beyond has no 32-bit Mac engine to build with."
      disable btn "MacOSX x86-64"
      -- OXT-Beyond: the stack's Mac targets are shown as they are, and kept.
      -- The boxes cannot be changed here, and the group "Flavors" is not
      -- sent mouseUp, which stores the boxes as the stack's targets: it was,
      -- with every box off, so a stack set up on a Mac lost all its Mac
      -- targets when this card was only looked at on Linux or Windows
      if tStandaloneSettingsA["MacOSX x64-ARM64"] is true then
         set the hilite of btn "MacOS-IntelArmUniversal" to true
         set the hilite of btn "MacOSX x86-64" to false
         set the hilite of btn "MacOSX x86-32" to false
      else
         set the hilite of btn "MacOS-IntelArmUniversal" to false
         set the hilite of btn "MacOSX x86-64" to (tStandaloneSettingsA["MacOSX x86-64"] is true)
         set the hilite of btn "MacOSX x86-32" to (tStandaloneSettingsA["MacOSX x86-32"] is true)
      end if
      set the enabled of group "OSX" to false
      
      -- OXT-Beyond: on to the stack's preOpenCard, which names this card in
      -- the window's title, as on a Mac (exit left the previous card's name)
      pass preOpenCard
      
   end if
   
   set the hilite of btn "MacOS-IntelArmUniversal" to isMac
   
   if tStandaloneSettingsA["MacOSX x64-ARM64"] then
      put true into tStandaloneSettingsA["MacOSX x64-ARM64"]
   else
      put false into tStandaloneSettingsA["MacOSX x64-ARM64"]
   end if
   
   
   --put computeDefault(tStandaloneSettingsA[OSX], true)
   
   setSettings tStandaloneSettingsA
   
   set the enabled of group "OSX" to false
   
   local tHiliteArch
   repeat with x = 1 to the number of buttons of group "Flavors"
      local tTag
      put the cSettingTag of button x of group "Flavors" into tTag
      // PM-2016-04-01: Using a stack created with LC < 8 has empty cSettingTag for button MacOSX x86_64
      put computeDefault(tStandaloneSettingsA[tTag], false) into tHiliteArch
      set the hilite of button x of group "Flavors" to tHiliteArch
      if the hilite of button x of group "Flavors" is true then
         set the enabled of group "OSX" to true
      end if
   end repeat
   
   put tStandaloneSettingsA["OSX,appicon"] into fld "appicon"
   put tStandaloneSettingsA["OSX,smallappicon"] into fld "smallappicon"
   put tStandaloneSettingsA["OSX,signature"] into fld "signature"
   put tStandaloneSettingsA["OSX,identifier"] into fld "identifier"
   put tStandaloneSettingsA["OSX,documentType"] into fld "documentType"
   put tStandaloneSettingsA["OSX,iconFile"] into fld "iconFile"
   put tStandaloneSettingsA["OSX,documenticonFile"] into fld "documenticonFile"
   put tStandaloneSettingsA["OSX,name"] into fld "name"
   put tStandaloneSettingsA["OSX,documentExtension"] into fld "documentExtension"
   put tStandaloneSettingsA["OSX,shortVersion"] into fld "shortVersion"
   put tStandaloneSettingsA["OSX,info"] into fld "info"
   put tStandaloneSettingsA["OSX,longVersion"] into fld "longVersion"
   put tStandaloneSettingsA["OSX,copyright"] into fld "copyright"
   put tStandaloneSettingsA["OSX,plist"] into fld "plist"
   
   local tSize
   put the cSize of this cd into tSize
   if tStandaloneSettingsA["OSX,plist"] = "" then
      hide group "choose"
      show group "enter"
      set the hilitedButtonName of group "plist" to "enter"
      #MJVH ~ 1208/22/05/2006
      put the cSize of group "enter" into item 2 of tSize
   else
      show group "choose"
      hide group "enter"
      set the hilitedButtonName of group "plist" to "choose"
      put the cSize of group "enter" into item 2 of tSize
   end if
   --set the cSize of this cd to tSize
   
   if the cRevStandaloneSettings["MacOSX x64-ARM64"] of stack (the cRevTargetStack of this stack) is true then
      -- we had selected arm build
      -- turn off the other two MacOS build options
      set the hilite of button "MacOSX x86-32" to false
      set the hilite of button "MacOSX x86-64" to false
      set the hilite of button "MacOS-IntelArmUniversal" to true
      set the visible of button "OSXchecked" of group "checks" of stack "revStandaloneSettings" to true
      set the enabled of button "OS X" of group "cards" to true
      set the enabled of group "OSX" to true
   end if
   fixUItheme
   pass preOpenCard
end preOpenCard


on fixUItheme
   -- appearance correction due to engine shortcomings
end fixUItheme


