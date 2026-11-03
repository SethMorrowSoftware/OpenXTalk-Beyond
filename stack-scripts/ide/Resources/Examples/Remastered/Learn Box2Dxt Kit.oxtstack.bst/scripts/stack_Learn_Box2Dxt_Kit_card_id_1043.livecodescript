script "stack_Learn_Box2Dxt_Kit_card_id_1043"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Reference" (id 1043)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- Every handler in the Kit: type to find one, click it to read about it.
-- The words are kept in two custom properties of this card, made when
-- the stack was built: cRef holds each handler's usage, what it does
-- and its details, and cUsedIn the lessons that call it.

on openCard
   refFilter
   pass openCard
end openCard

-- Each letter typed in the search box narrows the list
on textChanged
   if the short name of the target is "RefFind" then
      refFilter
   end if
   pass textChanged
end textChanged

on mouseUp
   if the short name of the target is "RefList" and the clickLine is not empty then
      set the hilitedLine of field "RefList" to word 2 of the clickLine
      refExplain the value of the clickLine
   end if
   pass mouseUp
end mouseUp

-- The wheel scrolls the list and the words (65308 down, 65309 up)
on rawKeyDown pKey
   local tField, tStep
   if pKey is 65308 or pKey is 65309 then
      repeat for each item tField in "RefList,RefDoc"
         if the mouseLoc is within the rect of field tField then
            put 54 into tStep
            if pKey is 65309 then
               put -tStep into tStep
            end if
            set the vScroll of field tField to max(0, the vScroll of field tField + tStep)
         end if
      end repeat
      exit rawKeyDown
   end if
   pass rawKeyDown
end rawKeyDown

-- Up and down choose in the list, while you type; the other arrow keys
-- go to the next or last card, unless you are typing
on arrowKey pKey
   local tLine
   if pKey is "up" or pKey is "down" then
      put the hilitedLine of field "RefList" into tLine
      if tLine is empty then
         put 0 into tLine
      end if
      if pKey is "down" then
         put min(tLine + 1, the number of lines of field "RefList") into tLine
      else
         put max(tLine - 1, 1) into tLine
      end if
      if tLine > 0 then
         set the hilitedLine of field "RefList" to tLine
         refExplain line tLine of field "RefList"
      end if
   else if the selectedField is empty then
      pass arrowKey
   end if
end arrowKey

-- The handlers whose name or words have what is in the search box
command refFilter
   local tRef, tFind, tName, tShown, tCount
   put the cRef of this card into tRef
   put field "RefFind" into tFind
   repeat for each line tName in the cNames of this card
      if tFind is empty or tFind is in tName or tFind is in tRef[tName] then
         put tName & return after tShown
         add 1 to tCount
      end if
   end repeat
   delete the last char of tShown
   put tShown into field "RefList"
   put max(0, tCount) && "of" && the number of lines of the cNames of this card && "handlers" into field "RefCount"
end refFilter

-- One handler: how to call it, what it does, its details, and which
-- lessons call it
command refExplain pName
   local tRef, tUsed, tDoc, tText
   put the cRef of this card into tRef
   put the cUsedIn of this card into tUsed
   put tRef[pName] into tDoc
   if tDoc is empty then
      exit refExplain
   end if
   set the itemDelimiter to "|"
   put item 1 of tDoc & return & item 2 of tDoc & return & return & item 3 to -1 of tDoc into tText
   set the itemDelimiter to comma
   replace "\n" with return in tText
   if tUsed[pName] is not empty then
      put return & return & "In the lessons:" && tUsed[pName] after tText
   end if
   put tText into field "RefDoc"
   set the textStyle of line 1 of field "RefDoc" to "bold"
   set the textFont of line 1 of field "RefDoc" to "Courier"
   set the vScroll of field "RefDoc" to 0
end refExplain
