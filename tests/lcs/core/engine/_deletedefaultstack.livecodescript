script "_deleteDefaultStack"
/*
Run by deletedefaultstack.livecodescript in an engine of its own, with -ui,
so that no stack window is open and there is no top stack. It deletes the
default stack and then uses the default stack; with the argument "go" it
opens the stack with go before deleting it. It writes the default stack
after the delete, and whether there is such a stack, to a file in the
temporary folder; an engine that crashes writes nothing.
*/

on startup
   local tFile, tDefault
   put specialFolderPath("temporary") & "/oxt-delete-default-stack.txt" into tFile
   create invisible stack "OXTDeleteDefault"
   if "go" is among the lines of the commandArguments then
      go stack "OXTDeleteDefault"
   else
      set the defaultStack to "OXTDeleteDefault"
   end if
   delete stack "OXTDeleteDefault"
   put the defaultStack into tDefault
   put tDefault & return & (there is a stack tDefault) & return & \
         (the short name of this stack) into url ("file:" & tFile)
   quit 0
end startup
