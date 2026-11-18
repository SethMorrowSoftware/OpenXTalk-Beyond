script "stack_Bookshelf_field_id_1224"
-- Stack file: ide/Resources/Examples/Remastered/Bookshelf.oxtstack
-- Object: stack "Bookshelf" > card "Book Data" (id 1032) > field "Search Term" (id 1224)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on returnInField
   ## This message is sent when the retun key is pressed
   ## By handling it here we "trap" it meaning there cannot be multiple lines in the field
   ## Call searchBooks so the list is filtered when return is pressed
   searchBooks
end returnInField

on enterInField
   ## As with return but for enter
   searchBooks
end enterInField

-- (remaster) and as you type
on textChanged
   searchBooks
end textChanged
