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

local sFolder

on TestSetup
   put specialFolderPath("temporary") & slash & "oxt-ide-open-stack-" & \
         the milliseconds into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   local tStack
   repeat for each item tStack in kSubscriber & comma & kOpened & comma & kSample
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
