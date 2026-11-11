script "stack_Card_Navigator_button_id_1029"
-- Stack file: ide/Toolset/palettes/navigatorIDE.oxtstack
-- Object: stack "Card Navigator" > card (id 1002) > group "navbtns" (id 1016) > button "Clone Card" (id 1029)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mousedown
   put cd fld "stackName" into tStack
   try
      -- OXT-Beyond: a copy of the card in front, after it (OpenXTalkPaul,
      -- p=26111): a flip-book animation is made card by card this way
      -- The engine will not clone a card while the default stack is one
      -- that cannot be changed, as this window is (a click makes it the
      -- default), so the shown stack is the default for the copy
      put the defaultStack into tDefault
      set the defaultStack to tStack
      clone card id (the short id of this card of stack tStack) of stack tStack
      set the defaultStack to tDefault
   catch e
      if tDefault is not empty then set the defaultStack to tDefault
   end try
end mousedown

