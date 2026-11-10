script "CoreNetworkWebSocket"
/*
Copyright (C) 2026 OXT-Beyond contributors.

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
The web engine's sockets over WebSocket (engine/src/em-osspec-network.cpp
and em-socket.js): "open socket to" a ws:// URL. The server that
tools/ci/web_tests.py serves the tests from has a WebSocket echo at
/websocket-echo (web_check.make_server): it sends each message back, and
closes for "please close" and drops the connection for "please drop".
On the desktop, sockets are TCP, and these tests are skipped.
*/

local sEvents

private function __echoURL
   do "location.host" as "JavaScript"
   return "ws://" & the result & "/websocket-echo"
end __echoURL

-- Waits up to five seconds for pEvent to be among the lines of sEvents
private function __waitFor pEvent
   local tStart
   put the milliseconds into tStart
   repeat while the milliseconds - tStart < 5000
      if pEvent is among the lines of sEvents then
         return true
      end if
      wait 20 milliseconds with messages
   end repeat
   return false
end __waitFor

on wsOpened pSocket
   put "opened" && pSocket & return after sEvents
end wsOpened

on wsRead pSocket, pData
   put "read" && pData & return after sEvents
end wsRead

on wsWritten pSocket
   put "written" && pSocket & return after sEvents
end wsWritten

on socketClosed pSocket
   put "closed" && pSocket & return after sEvents
end socketClosed

on socketError pSocket, pError
   put "error" && pSocket && pError & return after sEvents
end socketError

on TestSetup
   if the platform is not "HTML5" then
      return "SKIP sockets over WebSocket are the web engine's"
   end if
   put empty into sEvents
end TestSetup

on TestOtherNamesAsBefore
   -- a host and port: a page cannot open a TCP socket, as before
   open socket to "localhost:80"
   TestAssert "host:port not supported", the result is "not supported"
   TestAssert "host:port not open", "localhost:80" is not among the lines of the openSockets
   open datagram socket to "ws://localhost/x"
   TestAssert "datagram not supported", the result is "not supported"
end TestOtherNamesAsBefore

on TestReadAndWrite
   local tSocket
   put __echoURL() into tSocket

   open socket to tSocket
   TestAssert "opens", the result is empty
   TestAssert "is open", tSocket is among the lines of the openSockets

   write "hello" & return to socket tSocket
   TestAssert "writes", the result is empty
   read from socket tSocket until return
   TestAssert "reads a line", it is "hello" & return

   -- bytes that are not UTF-8: a binary message, back as it was
   write numToByte(0) & numToByte(255) & numToByte(7) to socket tSocket
   read from socket tSocket for 3 chars
   TestAssert "binary back", byteToNum(byte 1 of it) is 0 and byteToNum(byte 2 of it) is 255 and byteToNum(byte 3 of it) is 7

   -- UTF-8: a text message
   write textEncode("h" & numToCodepoint(233) & "llo" & return, "UTF-8") to socket tSocket
   read from socket tSocket until return
   TestAssert "UTF-8 back", textDecode(it, "UTF-8") is "h" & numToCodepoint(233) & "llo" & return

   -- two messages read as one stream, a count at a time
   write "abc" to socket tSocket
   write "def" to socket tSocket
   read from socket tSocket for 4 chars
   TestAssert "a count across messages", it is "abcd"
   read from socket tSocket for 2 chars
   TestAssert "the rest", it is "ef"

   close socket tSocket
   TestAssert "closes", the result is empty
   TestAssert "is closed", tSocket is not among the lines of the openSockets
end TestReadAndWrite

on TestMessages
   local tSocket
   put __echoURL() & "|messages" into tSocket

   open socket to tSocket with message "wsOpened"
   TestAssert "opens without waiting", the result is empty
   TestAssert "opened message", __waitFor("opened" && tSocket)

   read from socket tSocket until return with message "wsRead"
   write "async" & return to socket tSocket with message "wsWritten"
   TestAssert "written message", __waitFor("written" && tSocket)
   TestAssert "read message", __waitFor("read async")

   -- the server closes: socketClosed
   write "please close" to socket tSocket
   TestAssert "socketClosed", __waitFor("closed" && tSocket)
   wait 100 milliseconds with messages
   TestAssert "gone when closed", tSocket is not among the lines of the openSockets
end TestMessages

on TestServerGoesAway
   local tSocket
   put __echoURL() & "|drop" into tSocket
   open socket to tSocket
   TestAssert "opens", the result is empty
   write "please drop" to socket tSocket
   TestAssert "socketError", __waitFor("error" && tSocket && "connection lost")
end TestServerGoesAway

on TestCannotConnect
   -- nothing listens on port 1
   open socket to "ws://127.0.0.1:1/"
   TestAssert "can't connect", the result is "can't connect to host"
   TestAssert "not open", "ws://127.0.0.1:1/" is not among the lines of the openSockets

   open socket to "ws://127.0.0.1:1/|async" with message "wsOpened"
   TestAssert "socketError for one opened with a message", \
         __waitFor("error ws://127.0.0.1:1/|async can't connect to host")
   TestAssert "never opened", "opened ws://127.0.0.1:1/|async" is not among the lines of sEvents
end TestCannotConnect
