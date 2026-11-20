script "TestKitDialog"
-- OXT-Beyond: tests of the IDE's own dialog in the look of Learn
-- (ide/Toolset/palettes/kitdialog/revkitdialog.livecodescript). A field
-- wraps only at a space, so a path with none, wider than the dialog's
-- panel of text, ran past the panel's right edge and was cut off: "Your
-- copy is ready" of File > Community Stacks and "Your stack is packed" of
-- File > Share Stack say where the file is, and on a Mac that was in
-- /private/var/folders/... . revKitDialogFitWords, which the dialog calls
-- on its panel, breaks such a word onto lines that fit.

-- Whether the stack was in memory before the test, which leaves it so
local sFound
-- The field the tests fill, made as the dialog's panel is, in a stack of
-- the test's own
constant kField = "TestKitDialogPanel"
constant kStack = "TestKitDialogSample"

-- A Mac's folder for a copy, as the IDE tour's said it (24c9)
constant kMacPath = "/private/var/folders/2s/vty41l455yv698g4xkgfv7z00000gn/T/TemporaryItems/oxt_tour_share_1795133388634"

on TestSetup
   TestSkipIfNot "ide"
   put there is a stack "revKitDialog" into sFound
   get the long id of stack (TestGetIDERepositoryPath() & "/Toolset/palettes/kitdialog/revkitdialog.livecodescript")
   if there is a stack kStack then
      delete stack kStack
   end if
   create stack kStack
   set the defaultStack to kStack
   -- As the dialog makes its panel of text (kdBuild, with revLearnKit's
   -- lkLabel): as wide as at the dialog's narrowest, 13 point, lines 19
   -- high, no margin at the sides, wrapped
   create field kField
   set the margins of field kField of stack kStack to "0,4,0,0"
   set the dontWrap of field kField of stack kStack to false
   set the textSize of field kField of stack kStack to 13
   set the textHeight of field kField of stack kStack to 19
   set the rect of field kField of stack kStack to 32, 200, 558, 500
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
   if sFound is not true and there is a stack "revKitDialog" then
      delete stack "revKitDialog"
   end if
end TestTeardown

-- The widest of the field's words, in pixels
private function __Widest
   local tWidest, tLine, tWord
   put 0 into tWidest
   repeat with tLine = 1 to the number of lines of field kField of stack kStack
      repeat with tWord = 1 to the number of words of line tLine of field kField of stack kStack
         put max(tWidest, the formattedWidth of word tWord of line tLine of field kField of stack kStack) into tWidest
      end repeat
   end repeat
   return tWidest
end __Widest

-- The room a word has: the field's width less its margins
private function __Room
   return the width of field kField of stack kStack - the leftMargin of field kField of stack kStack - the rightMargin of field kField of stack kStack
end __Room

-- The field's text without its returns, and a text without its returns
private function __Joined
   return __Without(the text of field kField of stack kStack)
end __Joined

private function __Without pText
   replace return with empty in pText
   return pText
end __Without

private command __Fit pText
   set the text of field kField of stack kStack to pText
   dispatch "revKitDialogFitWords" to stack "revKitDialog" with the long id of field kField of stack kStack
end __Fit

on TestAPathWiderThanThePanelFits
   local tText
   put "It is in" && kMacPath & ", and it is exactly the file that the gallery lists." into tText
   set the text of field kField of stack kStack to tText
   TestDiagnostic "the path is" && the formattedWidth of word 4 of field kField of stack kStack && "pixels, the panel" && __Room()
   TestAssert "the path is wider than the panel (else this tests nothing)", \
         the formattedWidth of word 4 of field kField of stack kStack > __Room()
   __Fit tText
   TestDiagnostic the text of field kField of stack kStack
   TestAssert "every word fits the panel", __Widest() <= __Room()
   TestAssert "nothing is taken out or added but the returns", \
         __Joined() is tText
   TestAssert "the path is broken after a slash", \
         char -1 of line 1 of field kField of stack kStack is "/"
   -- (the words after the path fit, so none of them is broken)
   TestAssert "the words after the path are as they were", \
         line -1 of field kField of stack kStack ends with ", and it is exactly the file that the gallery lists."
end TestAPathWiderThanThePanelFits

on TestAWordWithNoSlashFits
   local tText, tWord
   repeat 120 times
      put "m" after tWord
   end repeat
   put "Before" && tWord && "after" into tText
   set the text of field kField of stack kStack to tText
   TestAssert "the word is wider than the panel", __Widest() > __Room()
   __Fit tText
   TestAssert "every piece fits the panel", __Widest() <= __Room()
   TestAssert "nothing is taken out or added but the returns", \
         __Joined() is tText
end TestAWordWithNoSlashFits

on TestTextThatFitsIsLeftAsItIs
   local tText
   put "Once it is open it is a stack like any other of yours: its scripts run when you choose the browse tool and use it." & return & return & \
         "It is in /Users/sam/Documents/OXT-Beyond, and it is exactly the file that the gallery lists." into tText
   __Fit tText
   TestAssert "the text is as it was", the text of field kField of stack kStack is tText
end TestTextThatFitsIsLeftAsItIs

on TestEachLineOfManyIsFitted
   local tText
   put "The file a.zip is in" && kMacPath & "." & return & return & \
         "To share it:" & return & \
         "- Copy" && kMacPath & "/a.zip to a post." into tText
   __Fit tText
   TestAssert "every word of every line fits the panel", __Widest() <= __Room()
   TestAssert "nothing is taken out or added but the returns", \
         __Joined() is __Without(tText)
end TestEachLineOfManyIsFitted
