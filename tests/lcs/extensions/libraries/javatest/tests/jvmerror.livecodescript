script "JavaTestJVMErrorLibrary"
-- OXT-Beyond: the error a script gets when no Java can be started says
-- where the engine looked and what it tried
-- (libfoundation/src/foundation-java-private.cpp). It said only "Could not
-- initialise Java Runtime Environment", which stays its first words.
--
-- Java starts once per process and reads JAVA_HOME and the library path
-- then, so each case runs _jvmerror.livecodescript in an engine of its own
-- with the environment it needs.

local sModule

on TestSetup
   TestSkipIfNot "lcb"
   TestSkipIfNot "jvm"
   TestSkipIfNot "shell"
   put TestGetBuiltBytecodeFile("../javatest") into sModule
end TestSetup

-- What the stack wrote when run with the environment variables pEnv
-- (shell assignments, "NAME=value ...") put before the engine
private function __RunWithEnv pEnv
   local tEnginePath, tStack
   set the itemDelimiter to ":"
   put item 2 to -1 of the address into tEnginePath
   put the effective filename of me into tStack
   set the itemDelimiter to slash
   put "_jvmerror.livecodescript" into item -1 of tStack
   local tCommand
   put format("env %s \"%s\" -ui \"%s\" \"%s\"", pEnv, tEnginePath, tStack, sModule) into tCommand
   local tOutput
   put shell(tCommand) into tOutput
   TestDiagnostic tCommand
   TestDiagnostic tOutput
   return tOutput
end __RunWithEnv

-- Whether the dynamic linker finds libjvm.so by its name with an empty
-- library path, in its cache (a JDK the system registered there)
private function __CacheHasLibJVM
   if the platform is not "Linux" then
      return false
   end if
   repeat for each line tLine in shell("/sbin/ldconfig -p")
      if word 1 of tLine is "libjvm.so" then
         return true
      end if
   end repeat
   return false
end __CacheHasLibJVM

on TestErrorNamesWhatWasTried
   if __CacheHasLibJVM() then
      TestSkip "the error names what was tried", "the linker's cache has libjvm.so, so Java loads by its name"
      exit TestErrorNamesWhatWasTried
   end if
   local tHome, tOutput
   put "/nonexistent-oxt-java-home" into tHome
   put __RunWithEnv("LD_LIBRARY_PATH= JAVA_HOME=" & tHome) into tOutput
   TestAssert "the error starts as it did", \
         "Could not initialise Java Runtime Environment" is in tOutput
   TestAssert "the error names JAVA_HOME's folder", tHome is in tOutput
   TestAssert "the error says a path was not there", "not there" is in tOutput
   if the platform is "Linux" then
      TestAssert "the error names the JDK 9+ library it tried", \
            (tHome & "/lib/server/libjvm.so") is in tOutput
      TestAssert "the error names the library looked for by name", \
            "libjvm.so (by name" is in tOutput
   else
      TestAssert "the error names the libjli it tried", \
            (tHome & "/lib/libjli.dylib") is in tOutput
      TestAssert "the error names the libjvm it tried", \
            (tHome & "/lib/server/libjvm.dylib") is in tOutput
   end if
end TestErrorNamesWhatWasTried

on TestErrorWithoutJavaHome
   if __CacheHasLibJVM() and the platform is "Linux" then
      TestSkip "the error says JAVA_HOME is not set", "the linker's cache has libjvm.so, so Java loads by its name"
      exit TestErrorWithoutJavaHome
   end if
   local tOutput
   put __RunWithEnv("-u JAVA_HOME LD_LIBRARY_PATH=") into tOutput
   TestAssert "the error starts as it did", \
         "Could not initialise Java Runtime Environment" is in tOutput
   TestAssert "the error says JAVA_HOME is not set", "JAVA_HOME is not set" is in tOutput
end TestErrorWithoutJavaHome

on TestJavaHomeOnLinux
   -- On Linux a JDK named by JAVA_HOME is found with an empty library
   -- path; Java was looked for by its name alone, and did not start
   TestSkipIfNot "platform", "Linux"
   local tHome
   put $JAVA_HOME into tHome
   if tHome is empty then
      -- <home>/bin/javac, as TestEnsureJVM finds it
      put word 1 to -1 of shell("/usr/bin/env readlink -f /usr/bin/javac") into tHome
      set the itemDelimiter to slash
      if tHome ends with "/bin/javac" then
         delete item -2 to -1 of tHome
      else
         put empty into tHome
      end if
   end if
   if tHome is empty or there is not a file (tHome & "/lib/server/libjvm.so") then
      TestSkip "a JDK named by JAVA_HOME loads", "no JDK 9 or later found"
      exit TestJavaHomeOnLinux
   end if
   local tJar
   set the itemDelimiter to slash
   put item 1 to -3 of the effective filename of me & "/code/jvm/TestJar.jar" into tJar
   local tOutput
   put __RunWithEnv("LD_LIBRARY_PATH= JAVA_HOME=" & quote & tHome & quote && \
         "CLASSPATH=" & quote & tJar & quote) into tOutput
   -- What the engine said, in the result's own line, so that a failure
   -- shows why without the log
   local tSaid
   put word 1 to -1 of tOutput into tSaid
   replace return with " | " in tSaid
   if the number of chars of tSaid > 600 then
      put char 1 to 600 of tSaid into tSaid
   end if
   TestAssert "a JDK named by JAVA_HOME loads (" & tSaid & ")", "no error" is in tOutput
end TestJavaHomeOnLinux
