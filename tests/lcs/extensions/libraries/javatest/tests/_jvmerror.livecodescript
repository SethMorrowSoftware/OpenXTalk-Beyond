script "JavaTestJVMError"
-- OXT-Beyond: run by jvmerror.livecodescript in an engine of its own,
-- with JAVA_HOME and the library path that test chose: loads the javatest
-- library ($2, its compiled module), calls its Java binding, which starts
-- Java, and writes what it threw (or "no error") to standard output. Java
-- starts once per process, so this cannot run in the test's own engine.

on startup
   local tError, tResult
   try
      load extension from data url ("binfile:" & $2)
      put the result into tResult
      if tResult is not empty then
         write "load failed:" && tResult && $2 & return to stdout
         quit 1
      end if
      get DoTest()
   catch tError
   end try
   if tError is empty then
      write "no error" & return to stdout
   else
      write tError & return to stdout
   end if
   quit 0
end startup
