script "CoreEngineExtensionsAsyncNative"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- What an extension with native code has for work off the main thread
-- (engine/src/async.cpp, the MCAsyncNative functions): a function of its
-- native code called on another thread, with a message when it has
-- returned, and a wake, which a thread of its own signals when it has
-- something for the script, and which comes to the script as a message.
--
-- The extension here is _async_native.lcb, which binds to those functions
-- as any extension would. It has no native code of its own to call, so the
-- function it has called on another thread is the engine's signal function:
-- each call made in these tests is a wake signalled from another thread,
-- which is the very thing a native library's thread does. The threads and
-- the locks have their own checks without the engine
-- (tools/ci/async_core_check.py: native-calls, wakes).
--
-- Every wait is "with messages", since that is where the messages arrive,
-- and ends as soon as they have: the time limits are for a broken build.

-- The wake messages that came, by wake: how many
local sWoken
-- The calls that ended, by job: "<result>,<error>,<code>"
local sCalled
-- Every wake the test made, to delete when it is over
local sWakes

constant kWaitSeconds = 30

-- The name of _async_native.lcb's library
constant kModule = "com.livecode.lcs_tests.core.extensions.async_native"

on TestSetup
   -- Once a test has loaded the module it stays loaded where the tests
   -- share one engine (in a browser, tools/ci/web_tests.py), and loading
   -- it again would fail
   if kModule is not among the lines of the loadedExtensions then
      TestLoadAuxiliaryExtension "_async_native"
   end if
   put empty into sWoken
   put empty into sCalled
   put empty into sWakes
end TestSetup

on TestTearDown
   repeat for each line tWake in sWakes
      get TestAsyncNativeWakeDelete(tWake)
   end repeat
end TestTearDown

on nativeWoke pWake
   add 1 to sWoken[pWake]
end nativeWoke

on nativeCalled pJob, pResult, pError, pCode
   put pResult & comma & pError & comma & pCode into sCalled[pJob]
end nativeCalled

private function makeWake
   local tWake
   put TestAsyncNativeWakeCreate("nativeWoke") into tWake
   put tWake & return after sWakes
   return tWake
end makeWake

private command waitForCalls pCount
   local tUntil
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while the number of elements of sCalled < pCount and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
end waitForCalls

private command waitForWake pWake
   local tUntil
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while sWoken[pWake] is empty and the milliseconds < tUntil
      wait 5 milliseconds with messages
   end repeat
end waitForWake

-- A wake signalled from another thread reaches the script as a message, and
-- the call that signalled it ends with one
on TestWakeFromAnotherThread
   local tWake, tJob
   put makeWake() into tWake
   TestAssert "a wake has a number", tWake is an integer and tWake > 0

   put TestAsyncNativeWakeSignalOnAThread(tWake, "nativeCalled") into tJob
   TestAssert "a native call is a job with a number", tJob is an integer and tJob > 0
   waitForCalls 1
   waitForWake tWake
   TestAssert "the call ends with a message, with no result and no error", \
         sCalled[tJob] is ",,0"
   TestAssert "and the wake it signalled on its thread sends the wake's message", \
         sWoken[tWake] is 1

   -- Again: a wake is not used up
   put empty into sWoken
   put empty into sCalled
   put TestAsyncNativeWakeSignalOnAThread(tWake, "nativeCalled") into tJob
   waitForCalls 1
   waitForWake tWake
   TestAssert "a wake can be signalled again", sWoken[tWake] is 1
end TestWakeFromAnotherThread

-- However many signals come before the engine looks, the script has one
-- message: the native code's own queue says how much there is to fetch
on TestSignalsBecomeOneMessage
   local tWake, tOther
   put makeWake() into tWake
   put makeWake() into tOther
   TestAssert "two wakes have two numbers", tWake is not tOther

   repeat 25
      TestAsyncNativeWakeSignal tWake
   end repeat
   TestAssert "no message is sent while the handler runs", sWoken[tWake] is empty
   waitForWake tWake
   wait 50 milliseconds with messages
   TestAssert "many signals before the engine looks are one message", sWoken[tWake] is 1
   TestAssert "and no other wake's", sWoken[tOther] is empty

   TestAsyncNativeWakeSignal tOther
   TestAsyncNativeWakeSignal tWake
   waitForWake tOther
   wait 50 milliseconds with messages
   TestAssert "each wake that was signalled has its own message", \
         sWoken[tWake] is 2 and sWoken[tOther] is 1
end TestSignalsBecomeOneMessage

-- Many threads signalling at once: every call ends once, and the wake's
-- message comes at least once and no more often than it was signalled
on TestManyThreadsSignal
   local tWake, tJobs
   put makeWake() into tWake
   repeat 40
      put TestAsyncNativeWakeSignalOnAThread(tWake, "nativeCalled") & return after tJobs
   end repeat
   waitForCalls 40
   waitForWake tWake
   wait 50 milliseconds with messages

   local tAll
   put true into tAll
   repeat for each line tJob in tJobs
      if sCalled[tJob] is not ",,0" then
         put false into tAll
      end if
   end repeat
   TestAssert "forty calls each end once, with no error", \
         tAll and the number of elements of sCalled is 40
   TestAssert "forty calls have forty numbers", \
         the number of lines of tJobs is 40 and the number of elements of sCalled is 40
   TestDiagnostic "forty signals from the threads came as" && sWoken[tWake] && "messages"
   TestAssert "and the wake's message came, no more often than it was signalled", \
         sWoken[tWake] >= 1 and sWoken[tWake] <= 40
end TestManyThreadsSignal

-- A wake that is deleted sends nothing more, and its number is no wake
on TestDeletedWake
   local tWake, tJob
   put makeWake() into tWake
   TestAsyncNativeWakeSignal tWake
   TestAssert "a wake is deleted", TestAsyncNativeWakeDelete(tWake)
   wait 100 milliseconds with messages
   TestAssert "a signal that had not become a message when the wake was deleted never does", \
         sWoken[tWake] is empty
   TestAssert "a wake is deleted once", not TestAsyncNativeWakeDelete(tWake)
   TestAssert "and there is no wake 0 to delete", not TestAsyncNativeWakeDelete(0)
   TestAssert "nor has it a context", TestAsyncNativeNoWakeHasNoContext()

   -- Native code that still has the number does no harm with it, on the
   -- main thread or on another
   TestAsyncNativeWakeSignal tWake
   TestAsyncNativeWakeSignal 0
   put TestAsyncNativeWakeSignalOnAThread(tWake, "nativeCalled") into tJob
   waitForCalls 1
   wait 100 milliseconds with messages
   TestAssert "signalling a deleted wake does nothing, and harms nothing", \
         sCalled[tJob] is ",,0" and sWoken[tWake] is empty

   -- A new wake is not the old one
   local tNew
   put makeWake() into tNew
   TestAssert "a new wake has a number the deleted one never had", tNew is not tWake
   TestAsyncNativeWakeSignal tWake
   wait 100 milliseconds with messages
   TestAssert "so the old number does not signal the new wake", sWoken[tNew] is empty
   TestAsyncNativeWakeSignal tNew
   waitForWake tNew
   TestAssert "which works", sWoken[tNew] is 1
end TestDeletedWake

-- The message goes to the object whose script made the wake; when that
-- object is deleted its wake goes with it
on TestWakeOfADeletedObject
   local tStack, tWake
   create invisible stack "AsyncNativeOwner" & the milliseconds
   put it into tStack
   set the script of tStack to \
         "local sCount" & return & \
         "on ownerMakesWake" & return & \
         "   return TestAsyncNativeWakeCreate(" & quote & "ownerWoke" & quote & ")" & return & \
         "end ownerMakesWake" & return & \
         "on ownerWoke pWake" & return & \
         "   add 1 to sCount" & return & \
         "end ownerWoke" & return & \
         "function ownerCount" & return & \
         "   return sCount" & return & \
         "end ownerCount"
   dispatch "ownerMakesWake" to tStack
   put the result into tWake
   put tWake & return after sWakes
   TestAssert "an object's script makes a wake", tWake is an integer and tWake > 0

   TestAsyncNativeWakeSignal tWake
   local tUntil, tCount
   put the milliseconds + kWaitSeconds * 1000 into tUntil
   repeat while the milliseconds < tUntil
      dispatch function "ownerCount" to tStack
      put the result into tCount
      if tCount is not empty then
         exit repeat
      end if
      wait 5 milliseconds with messages
   end repeat
   TestAssert "and is the object the wake's message is sent to", \
         tCount is 1 and sWoken[tWake] is empty

   delete tStack
   TestAsyncNativeWakeSignal tWake
   wait 100 milliseconds with messages
   TestAssert "a wake whose object has been deleted is gone at its next signal", \
         not TestAsyncNativeWakeDelete(tWake)
end TestWakeOfADeletedObject

-- A call that waits for a thread can be cancelled; one that has been made
-- has nothing left to cancel
on TestCallIsAJob
   local tWake, tJob
   put makeWake() into tWake
   put TestAsyncNativeWakeSignalOnAThread(tWake, "nativeCalled") into tJob
   waitForCalls 1
   TestAssert "a call that is over cannot be cancelled", not TestAsyncNativeCancel(tJob)
end TestCallIsAJob

on TestWrongCalls
   TestAssertThrow "a call of no function is refused", \
         "CallNothing", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   TestAssertThrow "a call with no message to send is refused", \
         "CallWithNoMessage", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   TestAssertThrow "a wake with no message to send is refused", \
         "WakeWithNoMessage", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   wait 50 milliseconds with messages
   TestAssert "and none of them sent anything", \
         sCalled is empty and sWoken is empty
end TestWrongCalls

on CallNothing
   get TestAsyncNativeCallNothing("nativeCalled")
end CallNothing

on CallWithNoMessage
   local tWake
   put makeWake() into tWake
   get TestAsyncNativeWakeSignalOnAThread(tWake, empty)
end CallWithNoMessage

on WakeWithNoMessage
   get TestAsyncNativeWakeCreate(empty)
end WakeWithNoMessage
