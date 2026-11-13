script "OXTTLSWriteCheck"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- Run by tools/ci/tls_write_check.py, which starts this standalone engine
-- headless (-ui) next to a TLS server of its own on this machine, named in
-- $OXT_TLSWRITE_HOST ("127.0.0.1:<port>"). The engine is the client:
--
--   1. It opens a secure socket (without verification: the server's
--      certificate is made for the check) and writes HELLO, blocking, so
--      the handshake is over and the server has the line.
--   2. It asks to read 5 bytes (read ... with message) and waits. The
--      server sends only the first bytes of the record that holds WORLD,
--      so the engine's SSL_read ends wanting more (SSL_ERROR_WANT_READ):
--      the state a TLS 1.3 session ticket left the engine in, after the
--      handshake of a Go server such as Caddy, in issue #461.
--   3. It writes REQ2 (blocking). The server sends the rest of the record
--      only once it has REQ2. Up to 0.2.7 the engine held every write back
--      while a read wanted more, so REQ2 never left: the write timed out,
--      and so did libURL's request in the issue.
--   4. It waits for WORLD.
--
-- Each line written to $OXT_TLSWRITE_LOG; the Python script decides what
-- passes:
--
--   OPEN <the result>
--   HELLO <the result of the write>
--   REQ2 <the result of the write> <milliseconds it took>
--   READ <what the read gave>
--   ERROR <message>
--   QUIT

local sLog, sSocket, sRead

on startup
   try
      tlsCheckRun
   catch tError
      tlsLog "ERROR" && line 1 of tError
   end try
   tlsLog "QUIT"
   quit 0
end startup

on tlsCheckRun
   local tStart
   put $OXT_TLSWRITE_LOG into sLog
   put $OXT_TLSWRITE_HOST into sSocket
   set the socketTimeoutInterval to 4000
   open secure socket to sSocket without verification
   tlsLog "OPEN" && the result
   write "HELLO" & crlf to socket sSocket
   tlsLog "HELLO" && the result
   put empty into sRead
   read from socket sSocket for 5 with message "tlsCheckGot"
   -- Long enough for the server's first bytes of WORLD to come and the
   -- engine to try to read them
   wait 1000 milliseconds with messages
   put the milliseconds into tStart
   write "REQ2" & crlf to socket sSocket
   tlsLog "REQ2" && the result && (the milliseconds - tStart)
   repeat with i = 1 to 60
      if sRead is not empty then exit repeat
      wait 100 milliseconds with messages
   end repeat
   tlsLog "READ" && sRead
   close socket sSocket
end tlsCheckRun

on tlsCheckGot pSocket, pData
   put pData into sRead
end tlsCheckGot

on socketError pSocket, pError
   tlsLog "ERROR socketError" && pError
end socketError

on tlsLog pLine
   if sLog is empty then
      write pLine & cr to stdout
   else
      open file sLog for append
      write pLine & cr to file sLog
      close file sLog
   end if
end tlsLog
