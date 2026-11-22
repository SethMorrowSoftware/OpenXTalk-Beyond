script "CoreNetworkDatagram"
/*
Copyright (C) 2026 Seth Morrow.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

/*
A datagram listener ("accept datagram connections on port N with message
M") lists a socket named "host:port" for each sender it hears, sharing the
listener's descriptor, so that a script can answer a sender from the
listener's port with "write ... to socket "host:port"" (MCSocket::readsome,
engine/src/opensslsocket.cpp).

When the listener closed, LiveCode (and OXT-Beyond up to 0.2.8-dp.2.1)
left those names listed holding the closed descriptor's number: off
Windows the socket thread then put that number into every select(), which
failed at once, so one engine thread used a whole processor core until
quit; a write to the name went through whatever had been given that number
since; and at quit the sockets were freed while that thread still read
them. The names are still listed after their listener closes, as they
were (scripts and test suites look for them), but they are never polled
and never written through, and a listener that hears the sender again
takes the name over.

The ports are fixed (4760x) because "accept datagram connections on port
0" does not say which port it was given.
*/

local sHeard, sReplies

on TestSetup
   if the platform is "HTML5" then
      return "SKIP datagram sockets are unavailable on HTML5"
   end if
   put empty into sHeard
   put empty into sReplies
end TestSetup

on TestTeardown
   __CloseAll
end TestTeardown

-- The listener's message: the sender's name, the datagram, the listener
on dgHeard pSender, pData, pListener
   put pSender & tab & pData & tab & pListener & return after sHeard
end dgHeard

-- The sending socket's read message, for the datagrams answered to it
on dgReply pSocket, pData
   put pData & return after sReplies
end dgReply

private command __CloseAll
   repeat for each line tSocket in the openSockets
      close socket tSocket
   end repeat
end __CloseAll

-- Waits up to pTimeout milliseconds (by default five seconds), handling
-- messages, for pText to be among the lines of sReplies, or (pHeard true)
-- for a datagram reading pText to have been heard
private function __waitFor pText, pHeard, pTimeout
   if pTimeout is empty then
      put 5000 into pTimeout
   end if
   local tStart
   put the milliseconds into tStart
   repeat while the milliseconds - tStart < pTimeout
      if pHeard then
         set the itemDelimiter to tab
         repeat for each line tLine in sHeard
            if item 2 of tLine is pText then
               return true
            end if
         end repeat
      else if pText is among the lines of sReplies then
         return true
      end if
      wait 20 milliseconds with messages
   end repeat
   return false
end __waitFor

-- The name the listener gave the sender of the last datagram it heard
private function __lastSender
   set the itemDelimiter to tab
   return item 1 of line -1 of sHeard
end __lastSender

-- Listens on pPort, sends one datagram (pText) to it from a new socket, and
-- answers the name of that sender as the listener lists it
private function __hearOne pPort, pText
   accept datagram connections on port pPort with message "dgHeard"
   if the result is not empty then
      return empty
   end if
   open datagram socket to "127.0.0.1:" & pPort
   -- a datagram socket's read with a message sends it each datagram the
   -- socket is answered with
   read from socket ("127.0.0.1:" & pPort) with message "dgReply"
   write pText to socket ("127.0.0.1:" & pPort)
   if not __waitFor(pText, true) then
      return empty
   end if
   return __lastSender()
end __hearOne

-- The processor time this engine has used, in clock ticks (Linux only)
private function __cpuTicks
   local tStat
   put shell("cat /proc/" & the processID & "/stat") into tStat
   -- the second field is the program's name in brackets, which may hold
   -- spaces: count from after it
   put char offset(")", tStat) + 2 to -1 of tStat into tStat
   -- utime and stime are fields 14 and 15, so 12 and 13 after the name
   return word 12 of tStat + word 13 of tStat
end __cpuTicks

-- Unchanged from LiveCode: the listener lists the sender's name, and a
-- write to that name answers the sender from the listener's port
on TestDatagramSenderIsListedAndAnswered
   local tSender
   put __hearOne(47601, "ping") into tSender
   TestAssert "a datagram listener hears a sender", tSender is not empty
   TestAssert "the sender's name is listed", tSender is among the lines of the openSockets

   write "pong" to socket tSender
   TestAssert "writing to the sender's name succeeds", the result is empty
   TestAssert "the sender hears the answer", __waitFor("pong", false)
end TestDatagramSenderIsListedAndAnswered

-- Unchanged from LiveCode: the sender's name stays listed after its
-- listener closes, until it is closed itself
on TestDatagramSenderNameOutlivesItsListener
   local tSender
   put __hearOne(47602, "ping") into tSender
   TestAssert "a datagram listener hears a sender", tSender is not empty

   close socket 47602
   wait 100 milliseconds with messages
   TestAssert "the listener is gone", 47602 is not among the lines of the openSockets
   TestAssert "the sender's name is still listed", tSender is among the lines of the openSockets

   close socket tSender
   TestAssert "closing the sender's name removes it", tSender is not among the lines of the openSockets
end TestDatagramSenderNameOutlivesItsListener

-- A write to a sender's name after its listener closed fails, and never
-- goes out through another socket that was given the closed descriptor's
-- number. (LiveCode sent it through the new listener here.)
on TestDatagramWriteAfterListenerClosedFails
   local tSender
   put __hearOne(47603, "ping") into tSender
   TestAssert "a datagram listener hears a sender", tSender is not empty

   close socket 47603
   wait 100 milliseconds with messages
   -- the system is likely to give this listener the closed one's number
   accept datagram connections on port 47604 with message "dgHeard"
   TestAssert "a second listener opens", the result is empty

   write "stray" to socket tSender
   TestAssert "writing to the name of a closed listener's sender fails", \
      the result is "error sending datagram"
   TestAssert "the datagram is not sent through another socket", \
      not __waitFor("stray", false, 1000)
end TestDatagramWriteAfterListenerClosedFails

-- A listener opened again on the port hears the sender again and answers
-- it through the name that was left listed
on TestDatagramReopenedListenerAnswersTheSenderAgain
   local tSender
   put __hearOne(47605, "ping") into tSender
   TestAssert "a datagram listener hears a sender", tSender is not empty

   close socket 47605
   wait 100 milliseconds with messages
   accept datagram connections on port 47605 with message "dgHeard"
   TestAssert "the listener opens again", the result is empty

   write "ping again" to socket ("127.0.0.1:47605")
   TestAssert "the new listener hears the sender", __waitFor("ping again", true)
   TestAssert "under the same name", __lastSender() is tSender
   TestAssert "which is listed once", \
      the number of lines of the openSockets is the number of lines of \
      __unique(the openSockets)

   write "pong" to socket tSender
   TestAssert "writing to the sender's name succeeds", the result is empty
   TestAssert "the sender hears the answer", __waitFor("pong", false)
end TestDatagramReopenedListenerAnswersTheSenderAgain

private function __unique pLines
   local tSeen
   repeat for each line tLine in pLines
      put true into tSeen[tLine]
   end repeat
   return the keys of tSeen
end __unique

-- The engine idles after a listener that heard a sender has closed.
-- LiveCode's socket thread spun a whole core from then until quit.
on TestDatagramClosedListenerLeavesTheEngineIdle
   TestSkipIfNot "platform", "linux"

   local tSender
   put __hearOne(47606, "ping") into tSender
   TestAssert "a datagram listener hears a sender", tSender is not empty

   -- Measured from before the close: shell() opens descriptors, and one
   -- given the closed listener's number would stop the spin it measures
   local tBefore, tUsed
   put __cpuTicks() into tBefore
   close socket 47606
   -- closing a socket does not wake the socket thread from the select()
   -- it waits in; a read does, and makes it gather its descriptors again
   read from socket ("127.0.0.1:47606") with message "dgReply"
   wait 1 second with messages
   put __cpuTicks() - tBefore into tUsed
   -- a spinning thread uses about 100 ticks a second; an idle engine
   -- almost none
   TestDiagnostic "processor ticks used in one idle second:" && tUsed
   TestAssert "the engine idles after the listener closes", tUsed < 50
end TestDatagramClosedListenerLeavesTheEngineIdle
