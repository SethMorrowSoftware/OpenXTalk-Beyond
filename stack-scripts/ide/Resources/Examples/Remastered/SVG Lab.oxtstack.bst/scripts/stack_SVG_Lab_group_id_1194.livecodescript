script "stack_SVG_Lab_group_id_1194"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab" > card "Options" (id 1033) > group "Open SVG" (id 1194)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseUp
   if svgOpenFile() then
      dispatch "svgRefresh" to this card
   end if
end mouseUp
