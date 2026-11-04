script "stack_SVG_Lab_group_id_1198"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab" > card "Options" (id 1033) > group "Use Logo" (id 1198)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseUp
   svgUseLogo
   dispatch "svgRefresh" to this card
end mouseUp
