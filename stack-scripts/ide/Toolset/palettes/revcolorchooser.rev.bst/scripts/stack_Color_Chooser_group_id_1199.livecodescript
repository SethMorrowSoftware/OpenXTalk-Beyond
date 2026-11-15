script "stack_Color_Chooser_group_id_1199"
-- Stack file: ide/Toolset/palettes/revcolorchooser.rev
-- Object: stack "Color Chooser" > card (id 1001) > group "Index" (id 1199)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseUp
  send "resetcontrols" to group the selectedText of button "Chooser Type"
end mouseUp
