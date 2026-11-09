script "stack_revStandaloneSettings_group_id_31523"
-- Stack file: ide/Toolset/palettes/standalone settings/revstandalonesettings.8.rev
-- Object: stack "revStandaloneSettings" > card "Android" (id 2060) > group "Android Targets" (id 31523)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseUp
   -- OXT-Beyond: the "OXT-Beyond engine (preview)" box ("Beyond Engine")
   -- is no architecture: ticked, the package is built with OXT-Beyond's
   -- own Android engine ("android,engine" is beyond), else with LiveCode
   -- 9.6.3's (empty, the default)
   if word 1 of the target is "button" and the short name of the target is "Beyond Engine" then
      if the hilite of the target then
         storeSetting "engine", "beyond"
      else
         storeSetting "engine", empty
      end if
      exit mouseUp
   end if
   if word 1 of the target is not "button" then
      exit mouseUp
   end if
   
   local tTarget
   put the short name of the target into tTarget
   -- OXT-Beyond: "App Bundle" is no architecture: it asks the build for
   -- an Android App Bundle (.aab) beside the package
   if tTarget is "App Bundle" then
      storeSetting "app bundle", the hilite of the target
      exit mouseUp
   end if
   updateAndroidArch word 2 of tTarget, the hilite of the target
end mouseUp
