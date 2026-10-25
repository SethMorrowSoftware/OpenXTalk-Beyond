script "oxt_menu_backdrop"
-- The Mac IDE with the backdrop on, a menu of its menu bar and real clicks,
-- run inside the real IDE by tools/ci/mac_menu_backdrop.py, which names
-- this file on the command line (the engine opens it once the IDE has
-- started), makes the clicks itself, with real mouse events, and reads the
-- window server's order of the IDE's windows after each. The forum's
-- report on 0.2.7-rc.6.4 (tperry2x, macOS Sonoma on Apple silicon): "If
-- you click the menu, then click the actual backdrop, seems to be a
-- program freeze (loop?)", the Menubar palette gone and nothing else
-- drawn, until a force quit. A click on the backdrop brought it in front
-- of every window of the IDE but its palettes.
--
-- Once the IDE has started this turns the backdrop on as View > Backdrop
-- does (revIDEToggle), and leaves the rest of the IDE as a user has it
-- (Preferences' "hide the IDE's windows when the desktop is clicked" too,
-- which the IDE tour turns off). From then on it writes beat.txt beside
-- this file every 250 milliseconds: the time, the Menubar palette's
-- visible, the backdrop, the defaultStack, the first of the windows and
-- the pending messages. A pending message writes it, so the beat stops
-- while the engine does not answer: in a handler that never ends, a call
-- that waits, or a menu that is still open. A frontscript logs the
-- messages of the menus, the backdrop and the windows' focus as they come,
-- and passes each.
--
-- It reads command.txt beside this file at each beat: a line of script
-- that it runs with "do" (the driver turns the backdrop off with it, or
-- off and on again with mbResetBackdrop), and then deletes. Its lines go
-- into menu-backdrop.txt beside this file:
--    STARTED
--    INFO <key> <value>
--    ERROR <a script error, its lines joined with " | ">
--    MSG <the milliseconds> <message> <target>
--    DID <command> -> <result>
--    POINT <x>,<y>    a point of the backdrop, in the working screenRect,
--                     that no window covers
--    READY
-- The script leaves the IDE running; tools/ci/mac_menu_backdrop.py ends it.

local sFolder, sStarted

on openStack
   if sStarted is not true then
      put true into sStarted
      set the itemDelimiter to slash
      put item 1 to -2 of the effective filename of me into sFolder
      set the itemDelimiter to comma
      -- out of the way of the IDE's windows
      hide stack "oxt_menu_backdrop"
      send "mbWhenStarted 0" to me in 1 second
   end if
   pass openStack
end openStack

-- Waits until the IDE has finished starting (home.livecodescript sets the
-- cREVLaunching of stack "Home" while it opens its palettes), then a
-- little more for their deferred messages
on mbWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then put the cREVLaunching of stack "Home" into tLaunching
   if tLaunching is true and pTries < 120 then
      send "mbWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "mbRun" to me in 3 seconds
   end if
end mbWhenStarted

on mbRun
   local tError, tStack
   mbRecord "STARTED"
   mbRecord "INFO platform" && the platform && the systemVersion && the processor
   mbRecord "INFO version" && the version && the buildNumber
   mbRecord "INFO screenRect" && the screenRect
   mbRecord "INFO working screenRect" && the working screenRect
   mbCatchErrors
   try
      mbRecord "INFO cDesktopClickToHide" && the cDesktopClickToHide of stack "revPreferences"
      mbRecord "INFO menubar" && the menubar
      if the backdrop is "none" then revIDEToggle "Backdrop"
      mbRecord "INFO backdrop" && the backdrop
   catch tError
      mbRecord "ERROR" && mbJoin(tError)
   end try
   mbInsertLogger
   send "mbBeat" to me in 250 milliseconds
   -- the IDE's windows where the backdrop put them, and the messages
   -- turning it on sent
   wait 1500 milliseconds with messages
   repeat for each line tStack in the openStacks
      if there is a stack tStack and the visible of stack tStack then
         mbRecord "INFO window" && tStack && "mode" && the mode of stack tStack && "rect" && \
               the effective rect of stack tStack
      end if
   end repeat
   mbRecord "POINT" && mbBackdropPoint()
   mbRecord "READY"
end mbRun

-- A point of the working screenRect (so off the menu bar and the Dock)
-- that no open window covers, from the bottom right corner, at least 20
-- pixels from every window and from the edges, or empty
function mbBackdropPoint
   local tWorking, tRects, tFree, tStack, tX, tY, tRect
   put the working screenRect into tWorking
   repeat for each line tStack in the openStacks
      if there is a stack tStack and the visible of stack tStack then
         put the effective rect of stack tStack & return after tRects
      end if
   end repeat
   repeat with tY = item 4 of tWorking - 40 down to item 2 of tWorking + 40 step -30
      repeat with tX = item 3 of tWorking - 40 down to item 1 of tWorking + 40 step -30
         put true into tFree
         repeat for each line tRect in tRects
            if tRect is empty then next repeat
            if tX >= item 1 of tRect - 20 and tX <= item 3 of tRect + 20 and \
                  tY >= item 2 of tRect - 20 and tY <= item 4 of tRect + 20 then
               put false into tFree
               exit repeat
            end if
         end repeat
         if tFree then return tX & "," & tY
      end repeat
   end repeat
   return empty
end mbBackdropPoint

on mbBeat
   local tLine, tCommand, tResult, tError
   send "mbBeat" to me in 250 milliseconds
   put the milliseconds into tLine
   try
      put tab & "menubar-visible=" & (there is a stack "revMenubar" and the visible of stack "revMenubar") after tLine
      put tab & "backdrop=" & the backdrop after tLine
      put tab & "defaultStack=" & the defaultStack after tLine
      put tab & "windows=" & mbFrontWindows() after tLine
      put tab & "pending=" & mbPendingNames() after tLine
   catch tError
      put tab & "error=" & mbJoin(tError) after tLine
   end try
   put textEncode(tLine & lf, "UTF-8") into URL ("binfile:" & sFolder & "/beat.txt")
   if there is a file (sFolder & "/command.txt") then
      put textDecode(URL ("binfile:" & sFolder & "/command.txt"), "UTF-8") into tCommand
      delete file (sFolder & "/command.txt")
      put line 1 of tCommand into tCommand
      try
         do tCommand
         put the result into tResult
      catch tError
         put "error" && mbJoin(tError) into tResult
      end try
      mbRecord "DID" && tCommand && "->" && tResult
   end if
end mbBeat

-- The first three windows of the app, front to back, by the engine's own
-- list (the windows: their stacks' names; the backdrop is not one)
function mbFrontWindows
   local tNames, tWindow
   repeat for each line tWindow in line 1 to 3 of the windows
      put tWindow & "|" after tNames
   end repeat
   return char 1 to -2 of tNames
end mbFrontWindows

-- The backdrop turned off and on again, which orders it behind the IDE's
-- windows as turning it on does
command mbResetBackdrop
   local tBackdrop
   put the backdrop into tBackdrop
   if tBackdrop is "none" then exit mbResetBackdrop
   set the backdrop to "none"
   set the backdrop to tBackdrop
end mbResetBackdrop

-- The names of the pending messages, other than the beat's
function mbPendingNames
   local tNames, tMessage
   repeat for each line tMessage in the pendingMessages
      if item 3 of tMessage is "mbBeat" then next repeat
      put item 3 of tMessage & " " after tNames
   end repeat
   return word 1 to -1 of tNames
end mbPendingNames

-- A frontscript that writes a MSG line for each message of the menus, the
-- backdrop, the windows' focus and the IDE's own handlers for them, and
-- passes it
command mbInsertLogger
   local tScript, tDefault, tError, tMessage
   repeat for each item tMessage in "mouseDownInBackdrop,mouseUpInBackdrop,suspendStack,resumeStack," & \
         "moveStack,menuPick,mouseDown,mouseUp,mouseRelease,hSwitchedAway,hSwitchedBack,fIDEWindows," & \
         "hCheckMacUp,unIconifyStack,iconifyStack,revIDEStackBelowMenuBar,revMenubarBuildMenus," & \
         "suspend,resume,closeStackRequest"
      put "on" && tMessage & return & \
            "   mbLogMessage" && quote & tMessage & quote & return & \
            "   pass" && tMessage & return & \
            "end" && tMessage & return after tScript
   end repeat
   put "on mbLogMessage pMessage" & return & \
         "   dispatch " & quote & "mbLog" & quote & " to stack " & quote & "oxt_menu_backdrop" & quote & \
         " with pMessage, the long id of the target" & return & \
         "end mbLogMessage" & return after tScript
   try
      put the defaultStack into tDefault
      set the defaultStack to "oxt_menu_backdrop"
      lock messages
      create invisible button "oxt_menu_backdrop_logger"
      set the script of it to tScript
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      mbRecord "INFO logging messages:" && mbJoin(tError)
   end try
end mbInsertLogger

on mbLog pMessage, pTarget
   mbRecord "MSG" && the milliseconds && pMessage && pTarget
end mbLog

-- Errors in the IDE's scripts go to the log, not to the IDE's error dialog
command mbCatchErrors
   local tError, tDefault
   try
      put the defaultStack into tDefault
      set the defaultStack to "oxt_menu_backdrop"
      lock messages
      create invisible button "oxt_menu_backdrop_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "mbScriptError" & quote & " to stack " & quote & "oxt_menu_backdrop" & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      mbRecord "INFO catching errors:" && mbJoin(tError)
   end try
end mbCatchErrors

on mbScriptError pError
   mbRecord "ERROR" && mbJoin(pError)
end mbScriptError

command mbRecord pLine
   put textEncode(pLine & lf, "UTF-8") after URL ("binfile:" & sFolder & "/menu-backdrop.txt")
end mbRecord

function mbJoin pText
   replace return with " | " in pText
   return pText
end mbJoin
