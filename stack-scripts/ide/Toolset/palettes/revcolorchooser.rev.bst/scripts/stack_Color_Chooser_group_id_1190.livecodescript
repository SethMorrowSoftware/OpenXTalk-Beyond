script "stack_Color_Chooser_group_id_1190"
-- Stack file: ide/Toolset/palettes/revcolorchooser.rev
-- Object: stack "Color Chooser" > card (id 1001) > group "Name" (id 1190)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on resetControls
  put getcolor(true) into field "Color Name"
  get the short name of button (the hilitedButton of group "Index") of group "Index"
  set the disabled of button "Clear" to it is "Pen" or it is "Brush"
end resetControls
