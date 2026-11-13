script "stack_Card_Navigator_button_id_1030"
-- Stack file: ide/Toolset/palettes/navigatorIDE.oxtstack
-- Object: stack "Card Navigator" > card (id 1002) > group "navbtns" (id 1016) > button "Show All" (id 1030)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mousedown
   put cd fld "stackName" into tStack
   try
      -- OXT-Beyond: each card in turn, a flip-book, and back to this one
      -- (OpenXTalkPaul, p=26111). "show all cards" is too fast to see, so
      -- one card at a time, each on the screen for about a fifteenth of
      -- a second, as an animation of 15 frames a second shows it
      put the defaultStack into tDefault
      set the defaultStack to tStack
      repeat the number of cards of stack tStack times
         show 1 card
         wait 66 milliseconds
      end repeat
      set the defaultStack to tDefault
   catch e
      if tDefault is not empty then set the defaultStack to tDefault
   end try
end mousedown

