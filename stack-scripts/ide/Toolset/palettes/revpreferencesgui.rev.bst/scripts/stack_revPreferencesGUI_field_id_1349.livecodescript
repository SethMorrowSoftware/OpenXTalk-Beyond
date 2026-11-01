script "stack_revPreferencesGUI_field_id_1349"
-- Stack file: ide/Toolset/palettes/revpreferencesgui.rev
-- Object: stack "revPreferencesGUI" > card "General" (id 1002) > group "Navigation" (id 1003) > field "Menu" (id 1349)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseDown   
  sectionChange
end mouseDown  

on selectionChanged
  sectionChange
end selectionChanged

on sectionChange
   go card word 1 to -1 of line (the hilitedLine of me) of me
   focus on me
   updPrefPath
end sectionChange


on updPrefPath
   -- tperry 11-02-2026
   -- show where the prefs are being stored
   put the long name of stack "revPreferences" into myPrefsLoc
   if word 1 of myPrefsLoc is "stack" then delete word 1 of myPrefsLoc
   if char 1 of myPrefsLoc is QUOTE then delete char 1 of myPrefsLoc
   if last char of myPrefsLoc is QUOTE then delete last char of myPrefsLoc
   put "preferences are saved in:" & return & myPrefsLoc into field "prefloc" of group "Navigation" of stack "revPreferencesGUI"
   -- OXT-Beyond: a path wider than the field (most on Windows, where
   -- the user's name is part of it) ran off the window's edge
   prefPathFit myPrefsLoc
end updPrefPath

-- OXT-Beyond: folders in the middle of the path give way to "..." until
-- it fits in the field, and the tooltip holds the whole path
on prefPathFit pPath
   local tRoom, tShown
   set the tooltip of field "prefloc" of group "Navigation" of stack "revPreferencesGUI" to pPath
   put the width of field "prefloc" of group "Navigation" of stack "revPreferencesGUI" into tRoom
   subtract 2 * item 1 of the margins of field "prefloc" of group "Navigation" of stack "revPreferencesGUI" + 4 from tRoom
   put pPath into tShown
   put tShown into line 2 of field "prefloc" of group "Navigation" of stack "revPreferencesGUI"
   set the itemDelimiter to "/"
   repeat while the formattedWidth of line 2 of field "prefloc" of group "Navigation" of stack "revPreferencesGUI" > tRoom and the number of items of tShown > 3
      if item 2 of tShown is "..." then
         delete item 3 of tShown
      else
         put "..." into item 2 of tShown
      end if
      put tShown into line 2 of field "prefloc" of group "Navigation" of stack "revPreferencesGUI"
   end repeat
end prefPathFit
