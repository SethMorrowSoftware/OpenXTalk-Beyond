script "IdeLibraryIdeOpenStack"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

-- OXT-Beyond: ideOpenStack sent to a subscriber that has no handler for it
-- (as OXT Lite's functions and DevGuides subscribe) travels the message
-- path into the IDE's libraries. The extension library's ideOpenStack,
-- which waits for a sample stack to open, read `the long id of stack ""`
-- when none was opening, so every stack open came back from the IDE's
-- message sender as an error (caught, so nobody saw it).

-- (not the name of this script's own stack, which a test cannot delete)
constant kSubscriber = "OXTIdeOpenStackSubscriber"
constant kOpened = "OXTIdeOpenStackOpened"
constant kSample = "OXTIdeOpenStackSample"
constant kProbe = "OXTIdeOpenStackProbe"

local sFolder

on TestSetup
   put specialFolderPath("temporary") & slash & "oxt-ide-open-stack-" & \
         the milliseconds into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   local tStack
   repeat for each item tStack in kSubscriber & comma & kOpened & comma & kSample & comma & kProbe
      if tStack is among the lines of the mainStacks then
         revIDEUnsubscribeAll the long id of stack tStack
         revIDESetUnedited tStack
         delete stack tStack
      end if
   end repeat
   if there is a file (sFolder & slash & kSample & ".oxtstack") then
      delete file (sFolder & slash & kSample & ".oxtstack")
   end if
   delete folder sFolder
end TestTeardown

on TestIdeOpenStackSubscriberWithoutHandler
   local tParams, tResult
   create invisible stack kSubscriber
   create invisible stack kOpened
   -- Subscribe as the stack kSubscriber, which has no script at all
   dispatch "revIDESubscribe" to stack kSubscriber with "ideOpenStack"

   put the long id of card 1 of stack kOpened into tParams[1]
   ideMessageSendWithParameters "ideOpenStack", empty, tParams
   put the result into tResult

   TestDiagnostic tResult
   TestAssert "ideOpenStack to a subscriber with no handler for it is sent" && \
         "without an error", tResult is empty
end TestIdeOpenStackSubscriberWithoutHandler

-- What the handler is for, unchanged: an extension's sample stack opened
-- through revIDEExtensionLaunchSampleStack loses its filename once it is
-- open, so that saving it asks where, and a second launch opens the stack
-- already in memory
on TestIdeOpenStackSampleStackStillHandled
   local tFile
   put sFolder & slash & kSample & ".oxtstack" into tFile
   create invisible stack kSample
   save stack kSample as tFile
   delete stack kSample
   TestAssert "the sample stack is not in memory before it is launched", \
         kSample is not among the lines of the mainStacks

   revIDEExtensionLaunchSampleStack tFile
   wait 500 milliseconds with messages
   TestAssert "a launched sample stack is open", \
         kSample is among the lines of the mainStacks
   TestAssert "a launched sample stack has no filename", \
         the filename of stack kSample is empty

   revIDEExtensionLaunchSampleStack tFile
   wait 200 milliseconds with messages
   TestAssert "a second launch keeps the stack already open (no filename)", \
         the filename of stack kSample is empty
end TestIdeOpenStackSampleStackStillHandled

-- OXT-Beyond: every subscriber is told the long id that a launched sample
-- stack keeps. Its filename was cleared while the IDE told its subscribers
-- that it had opened, by the long id it had at its openStack, which names
-- its file: a subscriber told after that, such as the Project Browser
-- (which keeps listening once it has been opened, even closed), asked the
-- engine about that long id, the engine read the file again for a stack of
-- that name already open, and the IDE asked "A stack with the same name as
-- the one you are trying to load is already open" (the full IDE tests hung
-- on it). The probe here records the long id it is told and the sample's
-- own at that moment, by name, which never reads a file. And a launch
-- unsubscribes nobody: the extension library's unsubscribe removed
-- whichever subscriber the message had come through (OXT Lite's
-- functions), not the library
on TestIdeOpenStackSampleStackTellsSubscribersItsOwnLongId
   local tFile, tBefore, tAfter, tTold, tGone, tLine
   put sFolder & slash & kSample & ".oxtstack" into tFile
   create invisible stack kSample
   save stack kSample as tFile
   delete stack kSample

   -- First a subscriber with no handler, through which the message
   -- reaches the extension library, then the probe
   create invisible stack kSubscriber
   dispatch "revIDESubscribe" to stack kSubscriber with "ideOpenStack"
   create invisible stack kProbe
   set the script of stack kProbe to \
         "on ideOpenStack pCard" & return & \
         "   if pCard contains " & quote & kSample & quote & " then" & return & \
         "      set the cTold of me to pCard" & return & \
         "      set the cOwnThen of me to the long id of stack " & quote & kSample & quote & return & \
         "   end if" & return & \
         "end ideOpenStack"
   dispatch "revIDESubscribe" to stack kProbe with "ideOpenStack"
   put revIDESubscribedObjects("ideOpenStack") into tBefore

   revIDEExtensionLaunchSampleStack tFile
   wait 500 milliseconds with messages
   put revIDESubscribedObjects("ideOpenStack") into tAfter

   TestAssert "a launched sample stack is open", \
         kSample is among the lines of the mainStacks
   TestAssert "a launched sample stack has no filename", \
         the filename of stack kSample is empty
   put the cTold of stack kProbe into tTold
   TestDiagnostic "told" && tTold & ", the stack's own" && the cOwnThen of stack kProbe
   TestAssert "a subscriber is told that the sample stack opened", tTold is not empty
   TestAssert "a subscriber is told the long id the sample stack has", \
         tTold is not empty and word -2 to -1 of tTold is the cOwnThen of stack kProbe
   TestAssert "the sample stack's long id names no file", \
         word -2 to -1 of tTold is "stack" && quote & kSample & quote

   repeat for each line tLine in tBefore
      if tLine is not among the lines of tAfter then
         put tLine & return after tGone
      end if
   end repeat
   TestDiagnostic "unsubscribed by the launch:" && tGone
   TestAssert "a launch unsubscribes nobody", tGone is empty
end TestIdeOpenStackSampleStackTellsSubscribersItsOwnLongId
