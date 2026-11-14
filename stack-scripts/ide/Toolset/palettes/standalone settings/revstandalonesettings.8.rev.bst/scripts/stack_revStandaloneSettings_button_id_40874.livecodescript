script "stack_revStandaloneSettings_button_id_40874"
-- Stack file: ide/Toolset/palettes/standalone settings/revstandalonesettings.8.rev
-- Object: stack "revStandaloneSettings" > card "Android" (id 2060) > group "Android Settings" (id 2072) > group "Requirements and Restrictions" (id 2255) > button "Target Android Version" (id 40874)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on menuPick pItemName
   -- OXT-Beyond: the API the package targets, its manifest's
   -- targetSdkVersion: "Default" stores no pin (the "android,target sdk"
   -- setting empty), and the builder targets the newest API when the
   -- runtime's Java layer is ready for it, else API 33, as before; "API
   -- 36" and the like pin that API (androidTargetAPI in
   -- ide-support/revsaveasandroidstandalone.livecodescript)
   if pItemName is "Default" then
      storeSetting "target sdk", empty
   else
      storeSetting "target sdk", word 2 of pItemName
   end if
end menuPick

-- OXT-Beyond: the card fills this menu and sets its choice from the
-- stack's settings (updateTargetAPIMenu in
-- revstandalonesettingsandroidbehavior.livecodescript); the minimum
-- version's list, which this copy's script made, is not this menu's
on updateSettings pAPI
end updateSettings
