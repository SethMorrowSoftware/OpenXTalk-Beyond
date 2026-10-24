script "CoreInterfaceUseSystemWindowColor"
/*
OXT-Beyond: the global useSystemWindowColor. On macOS a stack with no
backgroundColor of its own is drawn in the system's window colour while
it is true, instead of white; it is false by default, so that stacks look
as they always did, and it changes nothing a script reads from a stack.
*/

on TestUseSystemWindowColorDefault
   TestAssert "the useSystemWindowColor is false by default", \
         the useSystemWindowColor is false
end TestUseSystemWindowColorDefault

on TestUseSystemWindowColorSet
   local tStack
   put "UseSystemWindowColor" & the milliseconds into tStack
   create invisible stack tStack
   set the backgroundColor of stack tStack to "10,20,30"

   set the useSystemWindowColor to true
   TestAssert "it can be set to true", the useSystemWindowColor is true
   TestAssert "a stack's own backgroundColor stays", \
         the backgroundColor of stack tStack is "10,20,30"
   TestAssert "a stack without one still has none", \
         the backgroundColor of card 1 of stack tStack is empty

   set the useSystemWindowColor to false
   TestAssert "it can be set back to false", the useSystemWindowColor is false

   set the useSystemWindowColor to "true"
   TestAssert "it takes a string true", the useSystemWindowColor is true
   set the useSystemWindowColor to false

   delete stack tStack
end TestUseSystemWindowColorSet

on TestUseSystemWindowColorNotABoolean
   local tError
   try
      set the useSystemWindowColor to "grey"
   catch tError
   end try
   TestAssert "a value that is not true or false is an error", tError is not empty
   TestAssert "and leaves it false", the useSystemWindowColor is false
end TestUseSystemWindowColorNotABoolean
