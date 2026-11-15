script "stack_Color_Chooser_button_id_1187"
-- Stack file: ide/Toolset/palettes/colchooser.livecode
-- Object: stack "Color Chooser" > card (id 1001) > button "Chooser Type" (id 1187)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on menuPick newgroup, oldgroup
  hide group oldgroup
  send "resetcontrols" to group newgroup
  show group newgroup
end menuPick
