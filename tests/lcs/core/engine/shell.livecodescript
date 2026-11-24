script "CoreEngineShell"
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

/*
shell() gives the whole output of its command while other children of
the engine end around it. On Linux the engine's SIGCHLD handler checks
the engine's processes (waitpid), which can change errno; a signal that
came between shell()'s read() and its errno check could make a "try
again" look like a failure and end the read early, and the server's
wait for more output looked at errno after a poll that had succeeded
and could spin there at 100% CPU (HyperXTalk's fix, by Stam
Kapetanakis). The results are the ones shell() always gave: the output
in full, and an empty result for a command that succeeds.
*/

on TestShellGivesWholeOutputWhileChildrenEnd
   TestSkipIf "platform", "Win32"
   TestSkipIfNot "shell"

   local tCommand, tOut, tWhole
   -- Background children end while the command is still writing, so
   -- SIGCHLD comes in the middle of the read.
   put "for i in 1 2 3 4 5; do (sleep 0.0$i; exit 0) & done; " & \
         "printf a; sleep 0.03; printf b; sleep 0.03; printf c; wait" into tCommand
   put 0 into tWhole
   repeat with i = 1 to 20
      put shell(tCommand) into tOut
      if tOut is "abc" then add 1 to tWhole
   end repeat
   TestAssert "shell() gave the whole output 20 times out of 20 (" & tWhole & ")", tWhole is 20
end TestShellGivesWholeOutputWhileChildrenEnd

on TestShellOutputOfACommandThatFails
   TestSkipIf "platform", "Win32"
   TestSkipIfNot "shell"

   get shell("printf out; exit 3")
   TestAssert "the output of a command that fails", it is "out"
   get shell("printf out")
   TestAssert "the result is empty for a command that succeeds", the result is empty
end TestShellOutputOfACommandThatFails
