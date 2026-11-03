script "stack_Learn_Box2Dxt_Kit_card_id_1002"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Start" (id 1002)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- The front page: the tiles and the arrows are the window's. A click on
-- "Learn Box2D" opens that example, which is beside this one

on mouseUp
   if the long name of the target contains "group " & quote & "OtherStack" & quote then
      openOther
   else
      pass mouseUp
   end if
end mouseUp

command openOther
   local tPath
   set the itemDelimiter to slash
   put item 1 to -2 of the effective filename of this stack & "/Learn Box2D.oxtstack" into tPath
   set the itemDelimiter to comma
   if there is a file tPath then
      go stack tPath
   else if there is a stack "Learn Box2D" then
      go stack "Learn Box2D"
   else
      answer "Learn Box2D is with the other examples: open it from Home, under Examples."
   end if
end openOther
