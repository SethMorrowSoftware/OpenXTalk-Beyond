script "stack_SVG_Lab_group_id_1181"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab" > card "Compare" (id 1032) > group "Use Logo" (id 1181)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseUp
   svgUseLogo
   dispatch "svgRefresh" to this card
end mouseUp
