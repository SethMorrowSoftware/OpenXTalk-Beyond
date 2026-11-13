script "_sigterm"
/*
Run by sigterm.livecodescript in an engine of its own: it writes what
happens to the file named by OXT_SIGTERM_LOG, one word per line, while
the test sends it a TERM signal. OXT_SIGTERM_MODE "refuse" makes its
shutDownRequest refuse to quit (no pass).
*/

local sLog

on startup
   put $OXT_SIGTERM_LOG into sLog
   _sigtermLog "ready"
   -- Busy, with no wait and no message, for four seconds: the test sends
   -- the TERM signal in this time
   local tEnd
   put the milliseconds + 4000 into tEnd
   repeat until the milliseconds > tEnd
   end repeat
   _sigtermLog "busydone"
   -- Kept alive by this message; it quits on its own if nothing else does
   send "_sigtermGiveUp" to me in 8 seconds
end startup

on shutDownRequest
   _sigtermLog "shutDownRequest"
   if $OXT_SIGTERM_MODE is "refuse" then
      send "_sigtermStillRunning" to me in 1 second
      exit shutDownRequest
   end if
   pass shutDownRequest
end shutDownRequest

on shutDown
   _sigtermLog "shutDown"
end shutDown

on _sigtermStillRunning
   _sigtermLog "stillrunning"
   quit 0
end _sigtermStillRunning

on _sigtermGiveUp
   _sigtermLog "gaveup"
   quit 3
end _sigtermGiveUp

private command _sigtermLog pWord
   open file sLog for append
   write pWord & return to file sLog
   close file sLog
end _sigtermLog
