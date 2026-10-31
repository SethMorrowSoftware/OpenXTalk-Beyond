script "oxt_theme_probe"
-- For a probe only, removed before its pull request merges: the engine
-- headless (-ui), a frontscript for systemAppearanceChanged, the switch
-- posted as the IDE tour posts it, and a wait with messages

global gSeen

on startup
   local tWaited
   put empty into gSeen
   insert the script of me into front
   put "BEFORE" && the systemAppearance
   get shell("defaults write -g AppleInterfaceStyle Dark")
   get shell("osascript -l JavaScript -e " & quote & \
         "ObjC.import('Foundation'); $.NSDistributedNotificationCenter.defaultCenter" & \
         ".postNotificationNameObjectUserInfoDeliverImmediately('AppleInterfaceThemeChangedNotification'," & \
         " null, null, true)" & quote)
   put "OSASCRIPT [" & it & "]"
   put 0 into tWaited
   repeat while gSeen is empty and tWaited < 5000
      wait 250 milliseconds with messages
      add 250 to tWaited
   end repeat
   put "SEEN [" & gSeen & "] after" && tWaited && "now" && the systemAppearance
   get shell("defaults delete -g AppleInterfaceStyle 2>/dev/null; true")
   quit 0
end startup

on systemAppearanceChanged
   put the systemAppearance & comma after gSeen
   pass systemAppearanceChanged
end systemAppearanceChanged
