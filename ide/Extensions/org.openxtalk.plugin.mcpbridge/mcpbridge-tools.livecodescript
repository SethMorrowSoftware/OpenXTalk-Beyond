script "org.openxtalk.plugin.mcpbridge-tools"
-- OXT-Beyond: the OXT side of the xTalk MCP Bridge, which lets Claude, in
-- the Claude desktop app or Claude Code, signed in with the user's own
-- Claude plan, read and build the stacks open in this IDE.
--
-- Anthropic lets no other program sign in to a Claude account or use a
-- Claude plan's credentials, so the bridge turns it around: Claude's own
-- apps run a small MCP server (mcp/server.js, in this folder), and that
-- server asks this IDE to do what Claude asks for, over a TCP socket that
-- only this computer can reach. The plan pays for the model; nothing here
-- holds a key, an account or a password, and nothing here talks to the
-- internet.
--
-- The socket. mcbServerStart listens on a port the system picks, on
-- 127.0.0.1 only (the defaultNetworkInterface, set for the accept and put
-- back at once), refuses a connection from any other address, and writes
-- the port and a token of 32 random hex digits to a file in the user's
-- home folder (mcbInfoFilePath), which the MCP server reads. Each request
-- is one line of JSON, UTF-8, ending with a line feed:
--    {"id":1,"token":"...","method":"hello"}
--    {"id":2,"token":"...","method":"call","tool":"read_stack","arguments":{...}}
-- and each answer is one line too:
--    {"id":2,"ok":true,"isError":false,"text":"...","image":"<base64>","imageType":"image/png"}
--    {"id":2,"ok":false,"error":"..."}       (no tool ran: a bad request)
-- A request without the token is refused without being read further.
-- mcbServerStop closes the sockets and deletes the file.
--
-- The web IDE's link. In a browser tab (the web IDE, tools/web-ide) the
-- engine has no sockets and the home folder is the browser's storage, so
-- the MCP server cannot find this IDE or dial it. There the server, started
-- with --web, listens on the user's computer instead, and the tab connects
-- out to it (the plugin's main stack and its mcp/web-link.js). mcbLinkStart
-- readies the same tools with no socket, port, file or token, and the
-- plugin hands each request line that comes from the tab to mcbLinkHandle,
-- which answers it as mcbHandleLine does, without the token: only the
-- user's own browser, on a page the server allows, reaches it.
-- mcbLinkLost says the tab's connection closed or was made again, so that
-- a question still open from before it is answered with nothing done, as
-- after the server gave up on a socket. mcbLinkStop ends it as
-- mcbServerStop does. The server and the link are never on together.
--
-- The tools are the xTalk Assistant's (ide/Extensions/
-- org.openxtalk.plugin.xtalkassistant), taken from its core and its build
-- library, which this loads from that folder without turning the assistant
-- on: the same checked batches of changes, all or nothing and undoable,
-- the same runs in a sandbox or after a checkpoint, the same compile
-- check, outline and Dictionary. The bridge's own: read_script and
-- edit_script read and change a long script in parts, search_scripts
-- finds text in every script of a stack, ide_context says what the user
-- has in front of them (the selection, the Script Editor, the last error,
-- noted by mcpbridge-errors.livecodescript while the bridge is on), and
-- the guide is bridge-guide.md around the language sections of the
-- assistant's. What the user is asked differs. Claude's
-- apps ask the user before each tool the first time (and, unless the user
-- says always, every time), so this asks only about what cannot be taken
-- back: every run of code (it runs in this engine, with the IDE's reach;
-- the assistant's xtaRiskScan reads its text, which code can always word
-- past, so it only names what the code seems to use), saving a stack to
-- its file, and undoing what the user has changed since. The plugin's main stack does
-- the asking (mcbConfirm, through the asker given to mcbServerStart); with
-- no asker, those are refused. Everything else applied can be undone with
-- the tool undo_changes or from the plugin's menu entry, until the bridge
-- is turned off.
--
-- Unless the user says otherwise. mcbSetUnasked true (the plugin's "Stop
-- Asking", which it keeps as a preference and gives again each time it
-- starts the bridge) lets runs of code and saves go ahead without the
-- question: still only with an asker there (the user's IDE, not a bare
-- engine), and each one noted with its code in a log beside the bridge's
-- file (mcbUnaskedLogPath), so the user can read afterwards what ran. It is
-- off until set, and stopping the server or the link puts it off again.
-- Claude can ask for it with the tool set_asking, which shows the user the
-- same warning first (mcbAsk: it is never let through unasked) and can put
-- asking back on with no question; the environment variable
-- OXTBEYOND_MCP_BRIDGE_ASK=always refuses it here too.
-- Undoing what the user changed since is asked about all the same: that
-- is the user's own work, and Claude cannot know what it was worth.
--
-- Four more of the bridge's own, for long work the user is not at the
-- desk for (each says more where it is written): set_script_from_file sets
-- a script from a file on this computer (a harness of megabytes does not
-- fit a call), after the same kind of question; wait_until waits for a
-- stack or a property of a control to be as Claude says, with no code run;
-- set_quiet turns the engine's sounds off and back on; restart_ide quits
-- this IDE and starts it again.
--
-- What keeps a slow answer from doing harm. Each call's line carries
-- "until", the time (the milliseconds, by this computer's clock) after
-- which the server no longer waits for it: a call read after that (the
-- engine was held up in a dialog of the system's, or in a script) is
-- refused with nothing done, like a yes that came too late (mcbAsk).
--
-- Which server.js. Beside the bridge's file this writes a second one
-- (mcbWriteServerPointer) that names the server.js of this folder. The
-- server Claude's app starts may be a copy saved in a desktop extension
-- months ago; it reads that file and serves from the one installed now,
-- so updating OXT-Beyond updates the server too.
--
-- It needs no IDE: the engine tests in tests/lcs/mcpbridge load it, the
-- assistant's core and build library, and a stand-in asker, the same way.
--
-- Public handlers:
--    mcbServerStart(pAssistantFolder, pAsker, pInfoFile)   the port, or throws
--    mcbServerStop                       closes the sockets, deletes the file
--    mcbServerPort(), mcbServerClients() while it runs
--    mcbInfoFilePath()                   where the MCP server looks for the file
--    mcbHandleLine(pLine)                one request, its answer (a line of JSON)
--    mcbLinkStart(pAssistantFolder, pAsker)   the web IDE's link: the tools
--                                        without a socket (true), or throws
--    mcbLinkHandle(pLine)                one request from the link, its answer
--    mcbLinkLost                         the link's connection closed or changed
--    mcbLinkStop                         ends the link
--    mcbLinkIsOn()                       true while the link is on
--    mcbCallTool(pTool, pArguments)      one tool, as an array ("text",
--                                        "error", "image", "imageType")
--    mcbToolNames()                      the tools, one per line
--    mcbUndoLast()                       the newest change still applied, undone
--    mcbDesktopConfigText(pOld, pName, pServerPath)  Claude desktop's
--                                        config with the bridge's entry added
--    mcbSetUnasked pOn, mcbIsUnasked()   runs and saves without asking
--    mcbUnaskedLogPath()                 where those are noted
--    mcbRelaunchScript(pPlatform, pStart, pPid, pWait)   the script that
--                                        waits for a process to end and then
--                                        starts the IDE (restart_ide)

-- What the answer to "hello" calls this end of the protocol; the MCP
-- server refuses a version it does not know
constant kProtocol = 1
-- The assistant's libraries, by their stack names
constant kCore = "org.openxtalk.plugin.xtalkassistant-core"
constant kBuild = "org.openxtalk.plugin.xtalkassistant-build"
constant kGuideFile = "xtalk-guide.md"
-- The longest request line read, in bytes: a batch of 100 changes with
-- their scripts fits many times over
constant kMaxRequestBytes = 8000000
-- The longest side of a picture of a card, in pixels (as the assistant's)
constant kPictureSide = 1024
-- The most text of a detail the user is asked about (the code of a run)
constant kMaxAskChars = 3000
-- The log of runs and saves done without asking (mcbSetUnasked), beside
-- the bridge's file, and how long it may grow before its older half goes
constant kUnaskedLogFile = "mcp-bridge-unasked.log"
constant kMaxUnaskedLogChars = 2000000
-- The most code a run may have when the asker shows it whole on a panel
-- that scrolls (OXT-Beyond's question, mcbShowsLongCode): kMaxAskChars
-- still holds where the question is answer's, which cuts it
constant kMaxAskLongChars = 20000
-- The tools, in the order the MCP server lists them (mcp/server.js has
-- their descriptions and schemas)
constant kTools = "xtalk_guide,list_stacks,ide_context,read_stack,read_script,search_scripts,look_at_card,lookup_dictionary,check_code,make_changes,edit_script,run_code,save_stack,list_changes,undo_changes,debug_state,stop_paused_script,answer_dialog,import_hypercard,set_asking,close_stack,set_script_from_file,wait_until,set_quiet,restart_ide"
-- The tools that answer while another call is still being carried out
-- (sBusy): they are for what holds that call up, a script paused in the
-- debugger or a dialog a stack opened, so they never wait for it. They
-- start nothing that another call could be in the middle of.
constant kUnblockingTools = "stop_paused_script,answer_dialog"
-- The dialogs answer_dialog answers that are the IDE's own stacks: those
-- answer and ask open for a script of the user's
constant kAnswerDialogs = "Answer Dialog,Ask Dialog"
-- The most characters of a dialog's text that the status gives
constant kDialogTextChars = 600
-- The most text of a script read_script gives at once (read_stack gives
-- 24,000 characters of a script, then says how many lines it left out)
constant kScriptReadChars = 20000
-- What the assistant's core puts after a text it cut (xtaCut): a script
-- sent back with it was copied from a cut one
constant kCutMark = "more lines left out)"
-- The bridge's guide (sections 1, 6 and 7, for Claude through the bridge)
-- and the line in it where sections 2 to 5 of the assistant's go
constant kBridgeGuideFile = "bridge-guide.md"
constant kGuideSections = "<!-- the xTalk Assistant's guide, sections 2 to 5 -->"
-- The error hook (mcpbridge-errors.livecodescript), by its stack name
constant kErrorHook = "org.openxtalk.plugin.mcpbridge-errors"
-- The stack a picture with the controls' ids is drawn in, deleted after
constant kOverlayStack = "org.openxtalk.plugin.mcpbridge-overlay"
-- The most objects read_stack reads at once, and matches search_scripts gives
constant kMaxReadIds = 20
constant kMaxSearchMatches = 100
-- The most characters of a line search_scripts shows
constant kSearchLineChars = 160
-- The most names lookup_dictionary suggests for a term with no entry
constant kNearestEntries = 8
-- set_script_from_file: the most bytes of a file (as a request's), and
-- how much of its text the question shows where the question is answer's
-- (OXT-Beyond's panel shows kMaxAskLongChars)
constant kMaxScriptFileBytes = 8000000
constant kFileAskChars = 2000
-- wait_until: the longest it waits, in seconds (server.js's
-- WAIT_UNTIL_MAX_S: less than the 40 seconds after which the server
-- answers a call early), how long when Claude gives none, how often it
-- looks, in milliseconds, and the most of a value it gives back
constant kWaitUntilMax = 30
constant kWaitUntilDefault = 20
constant kWaitUntilLook = 100
constant kWaitValueChars = 400
-- set_quiet: the note of what the loudness was, beside the bridge's file
constant kQuietFile = "mcp-bridge-quiet.txt"
-- What the name of the file that tells the MCP server where this IDE's
-- server.js is ends with, after the bridge file's name without its .json
-- (server.js's serverPointerPath)
constant kServerPointerEnd = "-server.json"
-- restart_ide: how long its script waits for this IDE to have quit, in
-- seconds, before it gives up (the user cancelled the quit)
constant kRestartWaitSeconds = 120

-- The token a request must carry; empty while the server is not running,
-- when every request is refused
local sToken
-- The port listened on, the open client sockets (one per line), the file
-- the port and token are written to, the folder of the assistant's files,
-- and the object that asks the user (its mcbConfirm)
local sPort, sClients, sInfoFile, sAssistantFolder, sAsker
-- True when this loaded the assistant's libraries (and so unloads them)
local sLoadedCore, sLoadedBuild
-- True while a tool runs; the tool, and when it began (the seconds)
local sBusy, sBusyTool, sBusySince
-- What the user is being asked now (the title of the question), and since
-- when, empty while nothing is asked: what a status, and a call refused
-- as busy, are told the bridge waits for
local sWaiting, sWaitingSince
-- The socket of the request being answered: a question to the user is
-- answered after the server gave up waiting (and closed it) only with
-- nothing done (mcbAsk)
local sRequestSocket
-- The Dictionary's entry names, read once (lookup_dictionary's suggestions)
local sDictionaryNames
-- True while the web IDE's link is on (mcbLinkStart); the count of its
-- connections closed or made again (mcbLinkLost); and that count when the
-- request being answered came, empty while none from the link is: a
-- question to the user answered after the connection it came on has gone
-- is answered only with nothing done (mcbAsk)
local sLink, sLinkGeneration, sLinkRequest
-- True while the user lets runs and saves go ahead without asking
-- (mcbSetUnasked); off until set, and again when the bridge stops
local sUnasked
-- The main stacks Claude's calls brought into memory (made with
-- make_changes, made by a run, imported), by name, while the bridge is on:
-- close_stack closes one never saved without asking
local sMadeStacks
-- What the loudness was before set_quiet put it to 0 ("play", "beep");
-- empty while the bridge has not quieted the engine
local sQuiet

--------------------------------------------------------------------------------
-- The server

-- Starts listening. pAssistantFolder is the xTalk Assistant's folder
-- (its core, build library and guide); pAsker the long id of the object
-- whose mcbConfirm function asks the user, empty to refuse what must be
-- asked; pInfoFile where to write the port and token, empty for
-- mcbInfoFilePath(). Returns the port; throws when it cannot listen.
function mcbServerStart pAssistantFolder, pAsker, pInfoFile
   local tOldInterface, tPort, tError, tProblem, tHex
   if sPort is not empty then
      return sPort
   end if
   if sLink is true then
      throw "The bridge's web link is on; it and the server are never on together."
   end if
   put pAssistantFolder into sAssistantFolder
   put pAsker into sAsker
   put false into sBusy
   mcbEnsureParts
   mcbDeleteOldCheckpoints
   mcbStartErrorHook
   get binaryDecode("H*", randomBytes(16), tHex)
   put tHex into sToken
   -- Only this computer: the engine binds the accepting socket to the
   -- defaultNetworkInterface, which is put back at once so that the
   -- user's own sockets are not bound to it
   put the defaultNetworkInterface into tOldInterface
   set the defaultNetworkInterface to "127.0.0.1"
   try
      accept connections on port 0 with message "mcbConnection"
      put it into tPort
      put the result into tProblem
   catch tError
      put tError into tProblem
   end try
   set the defaultNetworkInterface to tOldInterface
   if tProblem is not empty or tPort is not an integer or tPort <= 0 then
      put empty into sToken
      throw "The bridge could not listen on a port of this computer:" && line 1 of tProblem
   end if
   put tPort into sPort
   put empty into sClients
   if pInfoFile is empty then
      put mcbInfoFilePath() into sInfoFile
   else
      put pInfoFile into sInfoFile
   end if
   put mcbWriteInfoFile() into tProblem
   if tProblem is not empty then
      mcbServerStop
      throw tProblem
   end if
   mcbWriteServerPointer
   mcbQuietRecover
   return sPort
end mcbServerStart

-- Stops listening, closes every client's socket and deletes the file. The
-- assistant's libraries are unloaded only when this loaded them and the
-- assistant is not on; with them goes the journal, so what was applied can
-- no longer be undone.
command mcbServerStop
   local tSocket, tError
   repeat for each line tSocket in sClients
      try
         close socket tSocket
      catch tError
      end try
   end repeat
   put empty into sClients
   if sPort is not empty then
      try
         close socket sPort
      catch tError
      end try
   end if
   put empty into sPort
   -- The file goes only while it is this IDE's: another OXT-Beyond turned
   -- on since has written its own there, and keeps it
   if sInfoFile is not empty and there is a file sInfoFile and sToken is not empty then
      if mcbJsonString(sToken) is in textDecode(url ("binfile:" & sInfoFile), "UTF-8") then
         delete file sInfoFile
      end if
   end if
   put empty into sToken
   -- While the file's place is still known: its note is beside it
   mcbQuietOff
   put empty into sInfoFile
   mcbStopParts
end mcbServerStop

-- What stopping the server and stopping the link share: the error hook,
-- the asker and the assistant's libraries go. The assistant's libraries go
-- with the bridge unless the assistant is on: whichever loaded them, as a
-- turned-off assistant leaves them, and its journal, to the bridge.
private command mcbStopParts
   local tError
   -- The engine's sounds are the user's again (the web IDE's link ends here)
   mcbQuietOff
   put false into sUnasked
   put empty into sMadeStacks
   put false into sBusy
   put empty into sBusyTool
   put empty into sWaiting
   mcbStopErrorHook
   put empty into sAsker
   if not mcbAssistantOn() then
      if there is a stack kBuild and mcbInUse(kBuild) then
         try
            xtaBuildCleanup
         catch tError
         end try
         stop using stack kBuild
      end if
      if there is a stack kCore and mcbInUse(kCore) then
         try
            xtaCheckCleanup
         catch tError
         end try
         stop using stack kCore
      end if
   end if
   put false into sLoadedBuild
   put false into sLoadedCore
end mcbStopParts

--------------------------------------------------------------------------------
-- The web IDE's link

-- Readies the tools for the web IDE's link (see the top of this script):
-- the assistant's libraries, the error hook and the asker, as
-- mcbServerStart does, with no socket, file or token. Returns true; throws
-- when the assistant's files cannot be loaded or the server is on.
function mcbLinkStart pAssistantFolder, pAsker
   local tError
   if sLink is true then
      return true
   end if
   if sPort is not empty then
      throw "The bridge's server is on; it and the web link are never on together."
   end if
   put pAssistantFolder into sAssistantFolder
   put pAsker into sAsker
   put false into sBusy
   try
      mcbEnsureParts
   catch tError
      put empty into sAsker
      throw tError
   end try
   mcbDeleteOldCheckpoints
   mcbStartErrorHook
   put true into sLink
   if sLinkGeneration is not an integer then
      put 0 into sLinkGeneration
   end if
   put empty into sLinkRequest
   return true
end mcbLinkStart

-- Ends the link: what was applied can no longer be undone, as after
-- mcbServerStop
command mcbLinkStop
   if sLink is not true then
      exit mcbLinkStop
   end if
   put false into sLink
   mcbLinkLost
   put empty into sLinkRequest
   mcbStopParts
end mcbLinkStop

function mcbLinkIsOn
   return sLink is true
end mcbLinkIsOn

-- The link's connection closed, or a new one was made (the tab
-- reconnected, or the server was started again): an answer to a request
-- that came before reaches no one
command mcbLinkLost
   if sLinkGeneration is not an integer then
      put 0 into sLinkGeneration
   end if
   add 1 to sLinkGeneration
end mcbLinkLost

-- One request line from the link, answered as mcbHandleLine answers one
-- from a socket, without the token. The plugin keeps taking requests from
-- the tab while a tool asks the user, so this can be called again before
-- an earlier call returns (the later one is then told the bridge is busy);
-- each puts back the request it found.
function mcbLinkHandle pLine
   local tReply, tError, tOuter
   if sLink is not true then
      return mcbRefusal("null", "The bridge is turned off in " & mcbHostName() & ".")
   end if
   if the number of bytes of textEncode(pLine, "UTF-8") > kMaxRequestBytes then
      return mcbRefusal("null", "The request is too long.")
   end if
   put sLinkRequest into tOuter
   put sLinkGeneration into sLinkRequest
   try
      put mcbAnswerLine(pLine, true) into tReply
   catch tError
      put mcbRefusal("null", "The bridge failed:" && line 1 of tError) into tReply
   end try
   put tOuter into sLinkRequest
   return tReply
end mcbLinkHandle

-- Puts the error hook in the front of the message path, where it notes
-- each error the IDE shows the user (for ide_context) and passes it on
private command mcbStartErrorHook
   local tFile, tError
   try
      if there is not a stack kErrorHook then
         put mcbFolder() & "/mcpbridge-errors.livecodescript" into tFile
         if there is not a file tFile then
            exit mcbStartErrorHook
         end if
         get the short name of stack tFile
         set the _ideoverride of stack kErrorHook to true
      end if
      if not (the long id of stack kErrorHook is among the lines of the frontScripts) then
         insert the script of stack kErrorHook into front
      end if
   catch tError
   end try
end mcbStartErrorHook

-- Takes the error hook out of the message path, and forgets the errors
private command mcbStopErrorHook
   local tError
   try
      if there is not a stack kErrorHook then
         exit mcbStopErrorHook
      end if
      if the long id of stack kErrorHook is among the lines of the frontScripts then
         remove the script of stack kErrorHook from front
      end if
      delete stack kErrorHook
   catch tError
   end try
end mcbStopErrorHook

-- The folder this script's file is in (the plugin's)
private function mcbFolder
   local tFile
   put the effective filename of me into tFile
   set the itemDelimiter to "/"
   return item 1 to -2 of tFile
end mcbFolder

function mcbServerPort
   return sPort
end mcbServerPort

-- How many clients (MCP servers) are connected
function mcbServerClients
   return the number of lines of sClients
end mcbServerClients

-- The file the MCP server reads the port and token from:
-- .oxt-beyond/mcp-bridge.json in the user's home folder (USERPROFILE on
-- Windows, HOME elsewhere), as Node's os.homedir() finds it. A package of
-- the bridge in another xTalk's IDE (tools/plugins) writes the file its
-- compatibility stack names instead (xtpcBridgeFile), one per IDE, and
-- Claude is told it; OXT-Beyond's own copy has no such stack.
function mcbInfoFilePath
   local tHome, tFile
   if there is a stack "org.openxtalk.plugin.mcpbridge-compat" then
      dispatch function "xtpcBridgeFile" to stack "org.openxtalk.plugin.mcpbridge-compat"
      put the result into tFile
      if it is "handled" and tFile is not empty then
         return tFile
      end if
   end if
   if the platform is "Win32" then
      put $USERPROFILE into tHome
      replace backslash with slash in tHome
   else
      put $HOME into tHome
   end if
   if tHome is empty then
      put specialFolderPath("home") into tHome
   end if
   return tHome & "/.oxt-beyond/mcp-bridge.json"
end mcbInfoFilePath

-- Writes the port, the token and this process's id (with which the MCP
-- server tells a file left by an IDE that has gone from one that is on);
-- empty, or why it could not
private function mcbWriteInfoFile
   local tFolder, tJson
   set the itemDelimiter to slash
   put item 1 to -2 of sInfoFile into tFolder
   if there is not a folder tFolder then
      create folder tFolder
      if there is not a folder tFolder then
         return "The bridge could not make the folder" && tFolder & "."
      end if
      mcbOwnerOnly tFolder, "700"
   end if
   put "{" & mcbJsonString("protocol") & ":" & kProtocol & "," & \
         mcbJsonString("port") & ":" & sPort & "," & \
         mcbJsonString("token") & ":" & mcbJsonString(sToken) & "," & \
         mcbJsonString("pid") & ":" & the processID & "," & \
         mcbJsonString("engine") & ":" & mcbJsonString(the version) & "}" & numToChar(10) into tJson
   -- Only the user may read the token, where the system lets that be said:
   -- the file is made empty and closed to others before the token goes in,
   -- since a new file takes the umask (often readable by all)
   put empty into url ("binfile:" & sInfoFile)
   if the result is not empty then
      return "The bridge could not write" && sInfoFile & ":" && the result
   end if
   mcbOwnerOnly sInfoFile, "600"
   put textEncode(tJson, "UTF-8") into url ("binfile:" & sInfoFile)
   if the result is not empty then
      return "The bridge could not write" && sInfoFile & ":" && the result
   end if
   return empty
end mcbWriteInfoFile

-- Tells the MCP server where this IDE's own server.js is, in a file beside
-- the bridge's (see "Which server.js" at the top). It stays when the
-- bridge is turned off, since the server reads it before it looks for the
-- bridge, and is written only when it would change. A bridge that cannot
-- write it goes on: the server then serves from its own file, as before.
private command mcbWriteServerPointer
   local tServer, tFile, tJson, tError
   put mcbFolder() & "/mcp/server.js" into tServer
   if sInfoFile is empty or there is not a file tServer then
      exit mcbWriteServerPointer
   end if
   put sInfoFile into tFile
   if tFile ends with ".json" then
      delete char -5 to -1 of tFile
   end if
   put kServerPointerEnd after tFile
   put "{" & mcbJsonString("server") & ":" & mcbJsonString(tServer) & "}" & numToChar(10) into tJson
   try
      if there is a file tFile then
         set the caseSensitive to true
         if textDecode(url ("binfile:" & tFile), "UTF-8") is tJson then
            exit mcbWriteServerPointer
         end if
      end if
      put textEncode(tJson, "UTF-8") into url ("binfile:" & tFile)
   catch tError
   end try
end mcbWriteServerPointer

-- Lets only the user read (and write) pPath, off Windows (where a file in
-- the user's own folder is theirs already)
private command mcbOwnerOnly pPath, pMode
   if the platform is not "Win32" then
      get shell("chmod" && pMode && quote & pPath & quote)
   end if
end mcbOwnerOnly

-- The xTalk Assistant's checkpoints (copies of the user's stacks, taken
-- before a run on one) are deleted when it, or this bridge, is turned off;
-- an IDE that quit without that, or crashed, leaves them in the temporary
-- folder. Those more than a day old are deleted here.
private command mcbDeleteOldCheckpoints
   local tTemp, tFolder, tMade, tFile, tError
   put specialFolderPath("temporary") into tTemp
   if tTemp is empty or there is not a folder tTemp then
      exit mcbDeleteOldCheckpoints
   end if
   repeat for each line tFolder in folders(tTemp)
      if not matchText(tFolder, "^xtalkassistant-([0-9]+)-[0-9]+$", tMade) then
         next repeat
      end if
      if the seconds - tMade < 86400 then
         next repeat
      end if
      try
         repeat for each line tFile in files(tTemp & "/" & tFolder)
            delete file (tTemp & "/" & tFolder & "/" & tFile)
         end repeat
         delete folder (tTemp & "/" & tFolder)
      catch tError
      end try
   end repeat
end mcbDeleteOldCheckpoints

on mcbConnection pSocket
   local tHost
   set the itemDelimiter to ":"
   put item 1 of pSocket into tHost
   -- Bound to 127.0.0.1, so nothing else should reach it; refused anyway
   if tHost is not "127.0.0.1" or sToken is empty then
      close socket pSocket
      exit mcbConnection
   end if
   -- Once: Windows names a connection by a number it gives again after one
   -- has closed, and a line twice here was a client counted twice
   if pSocket is not among the lines of sClients then
      put pSocket & return after sClients
   end if
   read from socket pSocket until numToChar(10) with message "mcbLineRead"
end mcbConnection

on mcbLineRead pSocket, pData
   local tReply, tError, tOuter
   if pSocket is not among the lines of sClients then
      exit mcbLineRead
   end if
   if the number of bytes of pData > kMaxRequestBytes then
      mcbDropClient pSocket
      exit mcbLineRead
   end if
   -- A request read while an earlier one waits (a status, a call refused
   -- as busy) is answered inside that wait: the earlier one's socket is
   -- put back after, so that its question still knows when the server
   -- gave up on it (mcbAsk)
   put sRequestSocket into tOuter
   put pSocket into sRequestSocket
   try
      put mcbHandleLine(textDecode(pData, "UTF-8")) into tReply
   catch tError
      put mcbRefusal("null", "The bridge failed:" && line 1 of tError) into tReply
   end try
   put tOuter into sRequestSocket
   -- The server may have been stopped while the tool ran (or asked)
   if pSocket is not among the lines of sClients then
      exit mcbLineRead
   end if
   write textEncode(tReply & numToChar(10), "UTF-8") to socket pSocket
   if pSocket is among the lines of sClients then
      read from socket pSocket until numToChar(10) with message "mcbLineRead"
   end if
end mcbLineRead

private command mcbDropClient pSocket
   local tError
   filter sClients without pSocket
   try
      close socket pSocket
   catch tError
   end try
end mcbDropClient

-- Quitting: the file and the checkpoints go, as when the bridge is
-- turned off (it is on again at the next launch, with a new port and token)
on shutdown
   local tError
   if sPort is not empty then
      try
         mcbServerStop
      catch tError
      end try
   end if
   pass shutdown
end shutdown

-- The engine sends these to the object that accepted the socket; this
-- stack is also a library, so the messages of every other object's sockets
-- pass through here too, and go on
on socketClosed pSocket
   if pSocket is among the lines of sClients then
      filter sClients without pSocket
   else
      pass socketClosed
   end if
end socketClosed

on socketError pSocket, pError
   if pSocket is among the lines of sClients then
      mcbDropClient pSocket
   else
      pass socketError
   end if
end socketError

on socketTimeout pSocket
   -- A client waits as long as it likes between requests. The read stays
   -- pending through the timeout (the engine sends this once and goes on
   -- reading), so it is not started again: a second read would take the
   -- next request too, and they would pile up.
   if pSocket is among the lines of sClients then
      exit socketTimeout
   else
      pass socketTimeout
   end if
end socketTimeout

--------------------------------------------------------------------------------
-- Requests

-- One request line, answered: a line of JSON (without its line feed)
function mcbHandleLine pLine
   return mcbAnswerLine(pLine, false)
end mcbHandleLine

-- One request line, answered. pFromLink is true for a line from the web
-- IDE's link (mcbLinkHandle), which carries no token; false for one from
-- a socket, which must carry the server's.
private function mcbAnswerLine pLine, pFromLink
   local tRequest, tError, tId, tMethod, tArguments, tResult, tReply, tTool, tUntil
   -- Stopped: nothing is read, and the assistant's libraries, which read
   -- JSON, may be gone
   if pFromLink is true then
      if sLink is not true then
         return mcbRefusal("null", "The bridge is turned off in " & mcbHostName() & ".")
      end if
   else if sToken is empty then
      return mcbRefusal("null", "The bridge is turned off in " & mcbHostName() & ".")
   end if
   try
      put xtaJsonParse(pLine) into tRequest
   catch tError
      return mcbRefusal("null", "The request is not JSON.")
   end try
   if xtaJsonType(tRequest) is not "object" then
      return mcbRefusal("null", "The request is not a JSON object.")
   end if
   -- The id goes back as it came: a number or a string
   put xtaJsonRaw(pLine, xtaJsonMember(tRequest, "id")) into tId
   if tId is empty then
      put "null" into tId
   end if
   if pFromLink is not true and (sToken is empty or xtaJsonType(xtaJsonMember(tRequest, "token")) is not "string" \
         or not mcbIsToken(xtaJsonText(xtaJsonMember(tRequest, "token")))) then
      return mcbRefusal(tId, "The token is not the bridge's. Turn the bridge off and on again in " & mcbHostName() & ", then try again.")
   end if
   put xtaJsonText(xtaJsonMember(tRequest, "method")) into tMethod
   if tMethod is "hello" then
      return "{" & mcbJsonString("id") & ":" & tId & "," & mcbJsonString("ok") & ":true," & \
            mcbJsonString("protocol") & ":" & kProtocol & "," & \
            mcbJsonString("engine") & ":" & mcbJsonString(the version) & "," & \
            mcbJsonString("tools") & ":" & mcbJsonString(kTools) & "}"
   end if
   -- What the bridge is doing or waiting for, answered at once, even while
   -- a tool runs (the MCP server asks it while a call takes long, over a
   -- connection of its own, to tell Claude why)
   -- "asking" is whether that is the user's answer to a question of the
   -- bridge's (a run, a save, an undo): the server then answers the call
   -- that waits for it early, and keeps its result (pending_result)
   if tMethod is "status" then
      return "{" & mcbJsonString("id") & ":" & tId & "," & mcbJsonString("ok") & ":true," & \
            mcbJsonString("busy") & ":" & (sBusy is true) & "," & \
            mcbJsonString("asking") & ":" & (sWaiting is not empty) & "," & \
            mcbJsonString("text") & ":" & mcbJsonString(mcbStatusText()) & "}"
   end if
   if tMethod is not "call" then
      return mcbRefusal(tId, "There is no method" && quote & tMethod & quote & ".")
   end if
   put xtaJsonMember(tRequest, "arguments") into tArguments
   if xtaJsonType(tArguments) is "missing" or xtaJsonType(tArguments) is "null" then
      put xtaJsonParse("{}") into tArguments
   end if
   if xtaJsonType(tArguments) is not "object" then
      return mcbRefusal(tId, "The arguments are not a JSON object.")
   end if
   -- A call the server no longer waits for ("until", see the top): it was
   -- told this IDE did not answer, and Claude may have sent the call again
   put xtaJsonText(xtaJsonMember(tRequest, "until")) into tUntil
   if tUntil is a number and the milliseconds > tUntil then
      return mcbRefusal(tId, "This call reached " & mcbHostName() & " after Claude's app had stopped waiting for it, so nothing was done.")
   end if
   -- One tool at a time: while one waits (for the user to answer a
   -- question here, or for a run), the engine still reads the sockets, and
   -- a second call, from another Claude app or after a reconnect, would
   -- start on the same journal
   put xtaJsonText(xtaJsonMember(tRequest, "tool")) into tTool
   if sBusy is true and tTool is among the items of kUnblockingTools then
      -- What holds the earlier call up is what this one is for
      put mcbCallTool(tTool, tArguments) into tResult
   else
      if sBusy is true then
         return mcbRefusal(tId, mcbHostName() & " is still busy with an earlier request (it may be waiting for the user to answer a question in " & mcbHostName() & ", " & \
               "or running code). Try again once that is done." & return & mcbStatusText())
      end if
      put true into sBusy
      put tTool into sBusyTool
      put the seconds into sBusySince
      try
         put mcbCallTool(tTool, tArguments) into tResult
      catch tError
         put false into sBusy
         put empty into sBusyTool
         throw tError
      end try
      put false into sBusy
      put empty into sBusyTool
   end if
   put "{" & mcbJsonString("id") & ":" & tId & "," & mcbJsonString("ok") & ":true," & \
         mcbJsonString("isError") & ":" & (tResult["error"] is true) & "," & \
         mcbJsonString("text") & ":" & mcbJsonString(tResult["text"]) into tReply
   if tResult["image"] is not empty then
      put "," & mcbJsonString("image") & ":" & mcbJsonString(tResult["image"]) & "," & \
            mcbJsonString("imageType") & ":" & mcbJsonString(tResult["imageType"]) after tReply
   end if
   return tReply & "}"
end mcbAnswerLine

-- True when pText is the token. "is" compares two numbers as numbers
-- ("2e999" is "2E999", and two long runs of digits can be equal as
-- numbers) and text without regard to case: a letter before each makes
-- both text, and the caseSensitive, which is this handler's own, makes the
-- case count.
private function mcbIsToken pText
   set the caseSensitive to true
   return ("t" & pText) is ("t" & sToken)
end mcbIsToken

private function mcbRefusal pId, pText
   return "{" & mcbJsonString("id") & ":" & pId & "," & mcbJsonString("ok") & ":false," & \
         mcbJsonString("error") & ":" & mcbJsonString(pText) & "}"
end mcbRefusal

-- pText as a JSON string, with its quotes, as the assistant's core writes
-- one (xtaJsonString); here so that a refusal needs no library
private function mcbJsonString pText
   local tOut, tCode, tHex
   put pText into tOut
   replace numToChar(92) with numToChar(92) & numToChar(92) in tOut
   replace quote with numToChar(92) & quote in tOut
   replace numToChar(10) with numToChar(92) & "n" in tOut
   replace numToChar(13) with numToChar(92) & "r" in tOut
   replace numToChar(9) with numToChar(92) & "t" in tOut
   repeat with tCode = 0 to 31
      if tCode is 9 or tCode is 10 or tCode is 13 then
         next repeat
      end if
      if numToChar(tCode) is in tOut then
         put toLower(baseConvert(tCode, 10, 16)) into tHex
         if the number of chars of tHex < 2 then
            put "0" before tHex
         end if
         replace numToChar(tCode) with numToChar(92) & "u00" & tHex in tOut
      end if
   end repeat
   return quote & tOut & quote
end mcbJsonString

function mcbToolNames
   local tNames
   put kTools into tNames
   replace comma with return in tNames
   return tNames
end mcbToolNames

-- Carries out one tool. pArguments is a parsed JSON object (xtaJsonParse).
-- Returns an array with "text" and "error" (true when the tool could not
-- do it), and for a picture "image" (base64) and "imageType".
function mcbCallTool pTool, pArguments
   local tResult, tError, tBefore
   try
      mcbEnsureParts
   catch tError
      return mcbFailed(tError)
   end try
   try
      switch pTool
         case "xtalk_guide"
            return mcbToolGuide()
         case "list_stacks"
            return mcbToolListStacks()
         case "ide_context"
            return mcbToolContext()
         case "read_stack"
            return mcbToolReadStack(pArguments)
         case "read_script"
            return mcbToolReadScript(pArguments)
         case "search_scripts"
            return mcbToolSearchScripts(pArguments)
         case "edit_script"
            return mcbToolEditScript(pArguments)
         case "look_at_card"
            return mcbToolLookAtCard(pArguments)
         case "lookup_dictionary"
            return mcbToolDictionary(mcbArg(pArguments, "term"))
         case "check_code"
            return mcbToolCheck(mcbArg(pArguments, "code"))
         case "make_changes"
            put mcbMainStackNames() into tBefore
            put mcbToolMakeChanges(pArguments) into tResult
            mcbNoteMadeStacks tBefore
            return tResult
         case "run_code"
            put mcbMainStackNames() into tBefore
            put mcbToolRunCode(pArguments) into tResult
            mcbNoteMadeStacks tBefore
            return tResult
         case "save_stack"
            return mcbToolSaveStack(mcbArg(pArguments, "stack"), mcbArg(pArguments, "file"), mcbArg(pArguments, "name"))
         case "close_stack"
            return mcbToolCloseStack(mcbArg(pArguments, "stack"))
         case "list_changes"
            return mcbToolListChanges()
         case "undo_changes"
            return mcbToolUndo(mcbArg(pArguments, "entry"))
         case "debug_state"
            return mcbToolDebugState()
         case "stop_paused_script"
            return mcbToolStopPaused()
         case "answer_dialog"
            return mcbToolAnswerDialog(pArguments)
         case "import_hypercard"
            put mcbMainStackNames() into tBefore
            put mcbToolImportHyperCard(pArguments) into tResult
            mcbNoteMadeStacks tBefore
            return tResult
         case "set_asking"
            return mcbToolSetAsking(mcbArg(pArguments, "ask"))
         case "set_script_from_file"
            return mcbToolSetScriptFromFile(pArguments)
         case "wait_until"
            return mcbToolWaitUntil(pArguments)
         case "set_quiet"
            return mcbToolSetQuiet(mcbArg(pArguments, "quiet"))
         case "restart_ide"
            return mcbToolRestart()
      end switch
   catch tError
      return mcbFailed(tError)
   end try
   put "There is no tool named" && quote & pTool & quote & ". The tools are:" && kTools & "." into tResult["text"]
   put true into tResult["error"]
   return tResult
end mcbCallTool

private function mcbFailed pError
   local tResult
   put "The bridge failed in " & mcbHostName() & ":" && line 1 of pError into tResult["text"]
   put true into tResult["error"]
   return tResult
end mcbFailed

private function mcbArg pArguments, pName
   return xtaJsonText(xtaJsonMember(pArguments, pName))
end mcbArg

private function mcbResult pText, pIsError
   local tResult
   put pText into tResult["text"]
   put (pIsError is true) into tResult["error"]
   return tResult
end mcbResult

--------------------------------------------------------------------------------
-- Claude desktop's config

-- The text of Claude desktop's claude_desktop_config.json with the entry
-- pName under "mcpServers" that runs node with the server pServerPath,
-- given the file's text now (pOld, empty for no file): every other entry
-- and setting is kept as it was written, an older entry of that name is
-- replaced. With pBridgeFile, the entry tells the server that file in
-- OXT_MCP_BRIDGE_FILE (a package of the bridge in another xTalk's IDE;
-- empty, as OXT-Beyond's own bridge gives it, leaves the server's own).
-- An array with "text", or "problem" when pOld is not a JSON object (the
-- file is then left to the user).
function mcbDesktopConfigText pOld, pName, pServerPath, pBridgeFile
   local tResult, tEntry, tRoot, tServers, tIndex, tName, tText, tError, tParts
   mcbEnsureParts
   put mcbJsonString(pName) & ": {" & return & \
         "      " & mcbJsonString("command") & ": " & mcbJsonString("node") & "," & return & \
         "      " & mcbJsonString("args") & ": [" & mcbJsonString(pServerPath) & "]" into tEntry
   if pBridgeFile is not empty then
      put "," & return & "      " & mcbJsonString("env") & ": {" & mcbJsonString("OXT_MCP_BRIDGE_FILE") & ": " & \
            mcbJsonString(pBridgeFile) & "}" after tEntry
   end if
   put return & "    }" after tEntry
   if word 1 to -1 of pOld is empty then
      put "{" & return & "  " & mcbJsonString("mcpServers") & ": {" & return & "    " & tEntry & return & "  }" & return & "}" & return into tResult["text"]
      return tResult
   end if
   try
      put xtaJsonParse(pOld) into tRoot
   catch tError
      put "it is not JSON that can be read (" & line 1 of tError & ")" into tResult["problem"]
      return tResult
   end try
   if xtaJsonType(tRoot) is not "object" then
      put "it does not hold a JSON object" into tResult["problem"]
      return tResult
   end if
   put xtaJsonMember(tRoot, "mcpServers") into tServers
   if xtaJsonType(tServers) is not "missing" and xtaJsonType(tServers) is not "object" then
      put "its mcpServers is not an object" into tResult["problem"]
      return tResult
   end if
   -- The servers already there, bar an older entry of this name
   put empty into tParts
   repeat with tIndex = 1 to xtaJsonCount(tServers)
      put tServers["names"][tIndex] into tName
      if mcbSameName(tName, pName) then
         next repeat
      end if
      put "    " & mcbJsonString(tName) & ": " & xtaJsonRaw(pOld, tServers["members"][tName]) & "," & return after tParts
   end repeat
   put "  " & mcbJsonString("mcpServers") & ": {" & return & tParts & "    " & tEntry & return & "  }" into tServers
   -- The other settings as they were, mcpServers where it was (else last)
   put "{" & return into tText
   put empty into tParts
   repeat with tIndex = 1 to xtaJsonCount(tRoot)
      put tRoot["names"][tIndex] into tName
      if mcbSameName(tName, "mcpServers") then
         put tServers & "," & return after tText
         put "done" into tParts
      else
         put "  " & mcbJsonString(tName) & ": " & xtaJsonRaw(pOld, tRoot["members"][tName]) & "," & return after tText
      end if
   end repeat
   if tParts is empty then
      put tServers & "," & return after tText
   end if
   delete char -2 of tText
   put "}" & return after tText
   put tText into tResult["text"]
   return tResult
end mcbDesktopConfigText

-- Two JSON member names compared as text whose case counts
private function mcbSameName pA, pB
   set the caseSensitive to true
   return ("n" & pA) is ("n" & pB)
end mcbSameName

--------------------------------------------------------------------------------
-- The assistant's libraries

-- Loads the assistant's core and build library from its folder when they
-- are not in use: the assistant unloads them when it is turned off, while
-- the bridge may still be on
command mcbEnsureParts
   if not mcbInUse(kCore) then
      if there is not a stack kCore then
         if sAssistantFolder is empty or there is not a file (sAssistantFolder & "/xtalkassistant-core.livecodescript") then
            throw "the xTalk Assistant's files are not in" && sAssistantFolder
         end if
         get the short name of stack (sAssistantFolder & "/xtalkassistant-core.livecodescript")
      end if
      start using stack kCore
      set the _ideoverride of stack kCore to true
      put true into sLoadedCore
   end if
   if not mcbInUse(kBuild) then
      if there is not a stack kBuild then
         if sAssistantFolder is empty or there is not a file (sAssistantFolder & "/xtalkassistant-build.livecodescript") then
            throw "the xTalk Assistant's files are not in" && sAssistantFolder
         end if
         get the short name of stack (sAssistantFolder & "/xtalkassistant-build.livecodescript")
      end if
      start using stack kBuild
      set the _ideoverride of stack kBuild to true
      put true into sLoadedBuild
   end if
end mcbEnsureParts

private function mcbInUse pName
   local tLine
   if there is not a stack pName then
      return false
   end if
   repeat for each line tLine in the stacksInUse
      if there is a stack tLine and the long id of stack tLine is the long id of stack pName then
         return true
      end if
   end repeat
   return false
end mcbInUse

-- True while the xTalk Assistant is turned on (it then keeps its
-- libraries, and their journal, for itself)
private function mcbAssistantOn
   local tOn, tError
   put false into tOn
   if there is a stack "org.openxtalk.plugin.xtalkassistant" then
      try
         dispatch function "xtaIsEnabled" to stack "org.openxtalk.plugin.xtalkassistant"
         put (the result is true) into tOn
      catch tError
      end try
   end if
   return tOn
end mcbAssistantOn

--------------------------------------------------------------------------------
-- Asking the user

-- Lets runs of code and saves go ahead without asking the user (pOn true),
-- or asks again (anything else). The plugin's "Stop Asking" sets it each
-- time it starts the bridge; stopping the server or the link puts it off.
command mcbSetUnasked pOn
   put pOn is true and not mcbAskIsLocked() into sUnasked
end mcbSetUnasked

-- True when this computer keeps the question for good
-- (OXTBEYOND_MCP_BRIDGE_ASK=always)
private function mcbAskIsLocked
   return toLower($OXTBEYOND_MCP_BRIDGE_ASK) is "always"
end mcbAskIsLocked

-- set_asking: pAsk true puts the question before runs and saves back on,
-- at once; false asks the user, with what it gives away, whether to stop
-- asking. That question is asked even while asking is off (mcbAsk, not
-- mcbAllow), so Claude cannot turn its own questions off. The asker is
-- told the choice (mcbUnaskedChanged), which OXT-Beyond keeps as its
-- preference, as its menu's Stop Asking and Ask Me Again do.
private function mcbToolSetAsking pAsk
   local tDetail
   if pAsk is true then
      mcbSetUnasked false
      mcbTellUnasked false
      return mcbResult(mcbHostName() & " asks the user again before each run of code and each save.", false)
   end if
   if pAsk is not false then
      return mcbResult("ask is true (ask before runs and saves) or false (ask the user whether to stop asking).", true)
   end if
   if mcbIsUnasked() then
      return mcbResult("The user already lets runs and saves go ahead without asking.", false)
   end if
   -- The web IDE always asks (the menu offers no Stop Asking there)
   if sLink is true then
      return mcbResult("The web IDE always asks before runs and saves: it cannot be turned off there.", true)
   end if
   if mcbAskIsLocked() then
      return mcbResult("This computer keeps asking before runs and saves for good (OXTBEYOND_MCP_BRIDGE_ASK is always): it cannot be turned off from here.", true)
   end if
   put "Claude's code would run, and stacks be saved, without a window asking you first, until you choose Ask Me Again in " & \
         "Development > Plugins > xTalk MCP Bridge or turn the bridge off." & return & return & \
         "Code Claude runs can do anything " & mcbHostName() & " can: read, change and delete your files, run programs, and reach the internet. " & \
         "You will not see it before it runs, and Claude can be misled by what it reads into running code you would not want. " & \
         "Each run and save is written down, with its code, in:" & return & mcbUnaskedLogPath() into tDetail
   if not mcbAsk("Claude asks to stop asking you before its runs and saves.", tDetail, "Stop Asking") then
      return mcbResult("The user chose to keep being asked before runs and saves. Do not ask again unless they ask you to.", true)
   end if
   mcbSetUnasked true
   mcbTellUnasked true
   return mcbResult("The user lets runs and saves go ahead without asking. Each is written in a log they can read. " & \
         "Run only what the task needs.", false)
end mcbToolSetAsking

-- Tells the asker the user's choice about asking (OXT-Beyond keeps it as
-- a preference); an asker without the handler (a package of the bridge in
-- another xTalk's IDE, the tests' stand-in) keeps nothing
private command mcbTellUnasked pOn
   local tError
   if sAsker is not empty and there is a sAsker then
      try
         dispatch "mcbUnaskedChanged" to sAsker with pOn
      catch tError
      end try
   end if
end mcbTellUnasked

function mcbIsUnasked
   return sUnasked is true
end mcbIsUnasked

-- Where runs and saves done without asking are noted: beside the bridge's
-- file (mcbInfoFilePath, or the one given to mcbServerStart)
function mcbUnaskedLogPath
   local tFile
   if sInfoFile is not empty then
      put sInfoFile into tFile
   else
      put mcbInfoFilePath() into tFile
   end if
   set the itemDelimiter to slash
   return item 1 to -2 of tFile & slash & kUnaskedLogFile
end mcbUnaskedLogPath

-- True when what Claude asks for (a run, a save) may go ahead: without a
-- question while the user lets it (mcbSetUnasked), noted in the log; else
-- as the user answers (mcbAsk). Never without an asker: a bridge started
-- with none refuses, as it always did.
private function mcbAllow pTitle, pDetail, pYes, pParts
   if sUnasked is true and sAsker is not empty and there is a sAsker then
      mcbNoteUnasked pTitle, pDetail
      return true
   end if
   return mcbAsk(pTitle, pDetail, pYes, pParts)
end mcbAllow

-- Adds what went ahead without asking to the log, with the time, for the
-- user to read later. The log is only the user's to read, as the bridge's
-- file is; once longer than kMaxUnaskedLogChars its older half goes. A log
-- that cannot be written does not stop the run: the user chose not to be
-- asked, and the run's own record (list_changes, undo) is unchanged.
private command mcbNoteUnasked pTitle, pDetail
   local tFile, tFolder, tOld, tEntry, tError
   put mcbUnaskedLogPath() into tFile
   set the itemDelimiter to slash
   put item 1 to -2 of tFile into tFolder
   try
      if there is not a folder tFolder then
         create folder tFolder
         mcbOwnerOnly tFolder, "700"
      end if
      if there is a file tFile then
         put textDecode(url ("binfile:" & tFile), "UTF-8") into tOld
      else
         put empty into url ("binfile:" & tFile)
         mcbOwnerOnly tFile, "600"
      end if
      if the number of chars of tOld > kMaxUnaskedLogChars then
         put char (the number of chars of tOld div 2) to -1 of tOld into tOld
      end if
      put "== " & the internet date & ":" && pTitle & numToChar(10) & pDetail & numToChar(10) & numToChar(10) into tEntry
      replace return with numToChar(10) in tEntry
      put textEncode(tOld & tEntry, "UTF-8") into url ("binfile:" & tFile)
   catch tError
   end try
end mcbNoteUnasked

-- Asks the user (the plugin's dialog); true when they said yes. With no
-- asker (the bridge started without one), false. pParts, when given, is
-- pDetail in its parts, for an asker that shows them apart (OXT-Beyond's
-- shows the code in colour): "prose", "code" and "handlers"
private function mcbAsk pTitle, pDetail, pYes, pParts
   local tAnswer, tError, tOuter
   if sAsker is empty or there is not a sAsker then
      return false
   end if
   if the number of chars of pDetail > kMaxAskChars then
      put char 1 to kMaxAskChars of pDetail & return & "... (" & the number of chars of pDetail - kMaxAskChars && \
            "more characters, not shown here)" into pDetail
   end if
   -- What a status says while the question is open (an outer question,
   -- which cannot be, would be put back)
   put sWaiting into tOuter[1]
   put sWaitingSince into tOuter[2]
   put pTitle into sWaiting
   put the seconds into sWaitingSince
   try
      dispatch function "mcbConfirm" to sAsker with pTitle, pDetail, pYes, pParts
      put the result into tAnswer
   catch tError
      put false into tAnswer
   end try
   put tOuter[1] into sWaiting
   put tOuter[2] into sWaitingSince
   -- The server gives up on a call after a while (server.js, 10 minutes)
   -- and closes the connection; Claude was told so and may send it again.
   -- A yes after that would run (or save, or undo) what nobody is waiting
   -- for, maybe twice: it does nothing, and the user is told why.
   -- The same for the web IDE's link, whose connection closed or was made
   -- again while the user was asked (mcbLinkLost)
   -- The user is told once this call is over: told while it went on, the
   -- notice held the bridge busy until they closed it, and every call
   -- after it was refused
   if tAnswer is true and ((sRequestSocket is not empty and sRequestSocket is not among the lines of sClients) \
         or (sLinkRequest is not empty and sLinkRequest is not sLinkGeneration)) then
      try
         send "mcbTooLate" to sAsker in 0 milliseconds
      catch tError
      end try
      return false
   end if
   return tAnswer is true
end mcbAsk

-- True when the asker shows a run's code whole, on a panel that scrolls
-- (OXT-Beyond's mcbShowsLongCode), so that it may be longer than
-- kMaxAskChars; false for an asker that has no such function (a package of
-- the bridge in another xTalk's IDE, the tests' stand-in)
private function mcbShowsLongCode
   local tShows, tError
   if sAsker is empty or there is not a sAsker then
      return false
   end if
   put false into tShows
   try
      dispatch function "mcbShowsLongCode" to sAsker
      if it is "handled" then
         put (the result is true) into tShows
      end if
   catch tError
      put false into tShows
   end try
   return tShows
end mcbShowsLongCode

-- The stack of the script open in the Script Editor, from the asker (the
-- IDE's), or empty
private function mcbEditorStack
   local tStack, tError
   if sAsker is empty or there is not a sAsker then
      return empty
   end if
   try
      dispatch function "mcbEditorStack" to sAsker
      put the result into tStack
   catch tError
      put empty into tStack
   end try
   if tStack is empty or there is not a tStack then
      return empty
   end if
   return tStack
end mcbEditorStack

--------------------------------------------------------------------------------
-- Stacks

-- The main stack the user is working on, a long id, or empty: that of the
-- script open in the Script Editor, else the frontmost open stack that is
-- the user's, as the assistant finds it
private function mcbWorkStack
   local tStack, tName
   put mcbEditorStack() into tStack
   if tStack is empty then
      put the topStack into tStack
      if tStack is empty or there is not a tStack or mcbIsIDEStack(tStack) then
         put empty into tStack
         repeat for each line tName in the openStacks
            if there is a stack tName then
               if the visible of stack tName and not mcbIsIDEStack(the long id of stack tName) then
                  put the long id of stack tName into tStack
                  exit repeat
               end if
            end if
         end repeat
      end if
   end if
   if tStack is empty or there is not a tStack or mcbIsIDEStack(tStack) then
      return empty
   end if
   return mcbMainStackOf(the long id of tStack)
end mcbWorkStack

-- As the assistant's build library has it: the IDE's stacks, the plugins'
-- (and so this bridge's), the dialogs, and their substacks
private function mcbIsIDEStack pStack
   local tName
   put the short name of pStack into tName
   if tName begins with "rev" or tName begins with "com.livecode." or tName begins with "org.openxtalk." then
      return true
   end if
   if tName is among the items of "Message Box,Answer Dialog,Ask Dialog,Home" then
      return true
   end if
   if the _ideoverride of pStack is true then
      return true
   end if
   -- In the web IDE, the IDE's files are under /boot (its bundle, which
   -- the engine unpacks there) and the user's never are: a plugin there
   -- that does not set _ideoverride is the IDE's too
   if the platform is "HTML5" and the owner of pStack is empty and the effective filename of pStack begins with "/boot/" then
      return true
   end if
   if the owner of pStack is not empty then
      return mcbIsIDEStack(the long id of the owner of pStack)
   end if
   return false
end mcbIsIDEStack

private function mcbMainStackOf pStack
   if the owner of pStack is empty then
      return the long id of pStack
   end if
   return the long id of the owner of pStack
end mcbMainStackOf

-- The stack a tool names (a main stack, a substack of the one the user
-- works on, or any stack of theirs open), else the one they work on: an
-- array with "stack" (a long id) or "problem"
private function mcbTarget pName
   return xtaTargetStack(pName, mcbWorkStack())
end mcbTarget

--------------------------------------------------------------------------------
-- The tools that read

private function mcbToolGuide
   local tBridge, tGuide, tAt, tEnd, tText
   put xtaReadGuide(mcbFolder() & "/" & kBridgeGuideFile) into tBridge
   put xtaReadGuide(sAssistantFolder & "/" & kGuideFile) into tGuide
   if tBridge is empty or not (kGuideSections is in tBridge) then
      -- Without the bridge's guide, the assistant's, with what reads
      -- differently through the bridge first
      if tGuide is empty then
         put xtaSystemPrompt() into tGuide
      end if
      put "How to write xTalk Script for " & mcbHostName() & ". It was written for the xTalk Assistant, the IDE's own chat window, and " & \
            "through this bridge some of it reads differently: there is no assistant window, Insert button or memory here; " & \
            "make_changes and edit_script change the stack as soon as the user allows the tool in this app; run_code asks the " & \
            "user in " & mcbHostName() & " before every run." & return & return & tGuide into tText
      return mcbResult(tText, false)
   end if
   -- Sections 2 to 5 of the assistant's guide (the language, objects,
   -- this engine, house style) go where the bridge's guide says
   put offset(return & "## 2.", tGuide) into tAt
   put offset(return & "## 6.", tGuide) into tEnd
   if tAt > 0 and tEnd > tAt then
      put char tAt + 1 to tEnd - 1 of tGuide into tText
   else
      put "## 2. The language" & return & return & xtaSystemPrompt() into tText
   end if
   replace kGuideSections with word 1 to -1 of tText in tBridge
   return mcbResult(tBridge, false)
end mcbToolGuide

private function mcbToolListStacks
   local tWork, tName, tStack, tText, tCount, tFile, tSub, tSubs, tLine, tPassword, tError
   put mcbWorkStack() into tWork
   put 0 into tCount
   repeat for each line tName in the mainStacks
      if there is not a stack tName then
         next repeat
      end if
      put the long id of stack tName into tStack
      if mcbIsIDEStack(tStack) then
         next repeat
      end if
      add 1 to tCount
      put "- stack" && quote & the short name of tStack & quote into tLine
      put the effective filename of tStack into tFile
      if tFile is empty then
         put ", never saved" after tLine
      else
         put ", file" && tFile after tLine
      end if
      put "," && the number of cards of tStack && "card(s)" after tLine
      if not the visible of tStack or tStack is not among the lines of mcbOpenLongIds() then
         put ", not open in a window" after tLine
      end if
      put "protected" into tPassword
      try
         put the password of tStack into tPassword
      catch tError
      end try
      if tPassword is not empty then
         put ", password-protected (not read or changed)" after tLine
      end if
      if tStack is tWork then
         put ", the one the user is working on" after tLine
      end if
      put empty into tSubs
      repeat for each line tSub in the substacks of tStack
         put quote & tSub & quote & ", " after tSubs
      end repeat
      if tSubs is not empty then
         delete char -2 to -1 of tSubs
         put ", substacks:" && tSubs after tLine
      end if
      put tLine & return after tText
   end repeat
   if tCount is 0 then
      return mcbResult("The user has no stack of their own open in " & mcbHostName() & ". make_changes can create one (a batch that begins with a change of kind stack).", false)
   end if
   put "The user's stacks open in " & mcbHostName() & ":" & return before tText
   delete the last char of tText
   return mcbResult(tText, false)
end mcbToolListStacks

-- What the user has in front of them in the IDE: the stack they work on
-- and its card, what is selected, the script open in the Script Editor
-- (and the caret's line, and whether it holds changes not yet applied),
-- the last error the IDE showed them, and a script paused in the debugger
private function mcbToolContext
   local tWork, tText, tTop, tLine, tObject, tList, tEditor, tError, tState, tLast, tDialog
   put mcbWorkStack() into tWork
   if tWork is empty then
      put "The user has no stack of their own open in " & mcbHostName() & "." into tText
   else
      put "The user is working on the stack" && quote & the short name of tWork & quote & "." into tText
      put the topStack into tTop
      if tTop is not empty and there is a tTop then
         put the long id of tTop into tTop
         if not mcbIsIDEStack(tTop) then
            put return & "In front:" && mcbObjectLabel(tTop) & ", on" && mcbObjectLabel(the long id of this card of tTop) & "." after tText
         end if
      end if
   end if

   repeat for each line tLine in the selectedObjects
      try
         if there is not a tLine then
            next repeat
         end if
         put the long id of tLine into tObject
         if mcbIsIDEStack(mcbStackOfObject(tObject)) then
            next repeat
         end if
         put "- " & mcbObjectLabel(tObject) && "of stack" && quote & the short name of mcbStackOfObject(tObject) & quote & return after tList
      catch tError
      end try
   end repeat
   if tList is empty then
      put return & "Nothing is selected." after tText
   else
      put return & "Selected (with the pointer tool):" & return & char 1 to -2 of tList after tText
   end if

   put mcbEditorNow() into tEditor
   if tEditor["object"] is empty or there is not a tEditor["object"] then
      put return & "No script is open in the Script Editor." after tText
   else if mcbIsIDEStack(mcbStackOfObject(tEditor["object"])) then
      put return & "The Script Editor shows a script of the IDE's own." after tText
   else
      put return & "The Script Editor shows the script of" && mcbObjectLabel(tEditor["object"]) && "of stack" && \
            quote & the short name of mcbStackOfObject(tEditor["object"]) & quote after tText
      if tEditor["line"] is an integer then
         put ", with the caret on line" && tEditor["line"] after tText
      end if
      put "." after tText
      if tEditor["unapplied"] is true then
         put " It holds changes the user has not applied: ask them to apply or revert them before you change that script " & \
               "(read_script reads the script as it was last applied)." after tText
      end if
   end if

   put mcbLastError() into tLast
   if tLast is empty then
      put return & "The IDE has shown the user no error since the bridge was turned on." after tText
   else
      put return & tLast after tText
   end if

   try
      put xtaDebugState() into tState
      if tState["paused"] is true then
         put return & "A script is paused in the debugger: debug_state reads where, and its variables." after tText
         -- Where, at once, and what it holds up
         put return & mcbPausedText() && "Code run now waits while it is paused: the user presses Run or Stop in the Script Editor, " & \
               "or stop_paused_script stops it." after tText
      end if
   catch tError
   end try
   put mcbFrontDialog() into tDialog
   if tDialog is not empty then
      put return & mcbDialogText(tDialog) after tText
   end if
   -- Whether a run or a save will wait for the user: when they are away,
   -- Claude says so before it sends one
   if mcbIsUnasked() and sAsker is not empty and there is a sAsker then
      put return & "Runs of code and saves go ahead without asking the user (they chose Stop Asking); each is written in a log." after tText
   else
      put return & mcbHostName() & " asks the user before each run of code and each save, and the call waits for their answer." after tText
   end if
   if sQuiet is an array then
      put return & "The engine's sounds are off (set_quiet): set_quiet with quiet false puts them back." after tText
   end if
   return mcbResult(tText, false)
end mcbToolContext

-- The script open in the Script Editor, from the asker (the IDE's): an
-- array with "object", "line" and "unapplied", or empty
private function mcbEditorNow
   local tContext, tError
   if sAsker is empty or there is not a sAsker then
      return empty
   end if
   try
      dispatch function "mcbEditorContext" to sAsker
      if it is "handled" then
         put the result into tContext
      end if
   catch tError
      put empty into tContext
   end try
   if tContext is not an array then
      return empty
   end if
   return tContext
end mcbEditorNow

-- The newest error the error hook noted in a script of the user's (not
-- one of the IDE's), as text for Claude: the engine's messages, then the
-- lines of the script around the error when it can be read; or empty
private function mcbLastError
   local tErrors, tIndex, tFound, tWhere, tObject, tStack, tName, tScript, tExcerpt, tError, tText
   if there is not a stack kErrorHook then
      return empty
   end if
   try
      dispatch function "mcbErrorHookErrors" to stack kErrorHook
      put the result into tErrors
   catch tError
      return empty
   end try
   put false into tFound
   repeat with tIndex = the number of elements of tErrors down to 1
      put xtaErrorWhere(tErrors[tIndex]["trace"]) into tWhere
      put tWhere["object"] into tObject
      if tObject is empty then
         put tErrors[tIndex]["target"] into tObject
      end if
      put empty into tStack
      try
         if tObject is not empty and there is a tObject then
            put mcbStackOfObject(the long id of tObject) into tStack
         end if
      catch tError
         put empty into tStack
      end try
      if tStack is not empty then
         if mcbIsIDEStack(tStack) then
            next repeat
         end if
      else if mcbNamesIDEStack(tObject) then
         -- Gone, or never an object (the IDE's temporary stacks, a
         -- behavior's): one of the IDE's by its name is not the user's
         next repeat
      end if
      put true into tFound
      exit repeat
   end repeat
   if not tFound then
      return empty
   end if
   if tStack is empty then
      -- The object is gone: the error as it was reported
      put tObject into tName
   else
      put the name of tObject && "of stack" && quote & the short name of tStack & quote into tName
   end if
   put "The last error the IDE showed the user, in" && tName && "(" & the seconds - tErrors[tIndex]["seconds"] && \
         "seconds ago), as the engine reported it:" & return & xtaErrorText(tErrors[tIndex]["trace"]) into tText
   if tStack is not empty and tWhere["line"] is not empty then
      try
         put mcbScriptOf(tObject) into tScript
      catch tError
         put empty into tScript
      end try
      put xtaScriptExcerpt(tScript, tWhere["line"]) into tExcerpt
      if tExcerpt is not empty then
         put return & "The script of" && tName & ", around line" && tWhere["line"] & ":" & return & tExcerpt after tText
      end if
   end if
   return tText
end mcbLastError

-- True when pObject, a reference to an object that is not there, names a
-- stack of the IDE's: by the names mcbIsIDEStack knows them by, or by a
-- file in the IDE's folders
private function mcbNamesIDEStack pObject
   local tName
   repeat for each item tName in "rev,com.livecode.,org.openxtalk.,Message Box,Answer Dialog,Ask Dialog,Home"
      if pObject contains ("stack" && quote & tName) then
         return true
      end if
   end repeat
   -- A main stack of the IDE's is named by its file, in the IDE's folders
   repeat for each item tName in "/Toolset/,/Plugins/,/Extensions/org.openxtalk.,/Extensions/com.livecode."
      if pObject contains tName then
         return true
      end if
   end repeat
   return false
end mcbNamesIDEStack

-- The stack an object is in (itself for a stack), from its long id
private function mcbStackOfObject pObject
   local tAt
   if word 1 of pObject is "stack" then
      return pObject
   end if
   put offset(" of stack ", pObject) into tAt
   if tAt is 0 then
      return empty
   end if
   return char tAt + 4 to -1 of pObject
end mcbStackOfObject

private function mcbOpenLongIds
   local tName, tList
   repeat for each line tName in the openStacks
      if there is a stack tName then
         put the long id of stack tName & return after tList
      end if
   end repeat
   return tList
end mcbOpenLongIds

-- An outline of a main stack and its substacks; with an id, that card or
-- control; with details, the stack's own properties, cards and script
-- An outline of a main stack and its substacks; with id (or ids, several),
-- those cards or controls; with details, the stack's own properties,
-- cards and script. An object's properties are those a new one of its
-- type would not have, unless all_properties.
private function mcbToolReadStack pArguments
   local tTarget, tStack, tObject, tLean, tIds, tNode, tIndex, tId, tText, tMissing, tCount
   put mcbTarget(mcbArg(pArguments, "stack")) into tTarget
   if tTarget["problem"] is not empty then
      return mcbResult(tTarget["problem"] && "list_stacks names the user's stacks.", true)
   end if
   put tTarget["stack"] into tStack
   put mcbArg(pArguments, "all_properties") is not "true" into tLean
   put word 1 to -1 of mcbArg(pArguments, "id") into tId
   if tId is not empty then
      put tId & return into tIds
   end if
   put xtaJsonMember(pArguments, "ids") into tNode
   repeat with tIndex = 1 to xtaJsonCount(tNode)
      put word 1 to -1 of xtaJsonText(xtaJsonItem(tNode, tIndex)) & return after tIds
   end repeat
   if tIds is empty then
      if mcbArg(pArguments, "details") is "true" then
         return mcbResult(mcbWithScriptHint(xtaObjectText(tStack, tLean)), false)
      end if
      return mcbResult(xtaStackOutline(mcbMainStackOf(tStack)) & mcbClipsText(mcbMainStackOf(tStack)), false)
   end if
   if the number of lines of tIds > kMaxReadIds then
      return mcbResult("read_stack reads at most" && kMaxReadIds && "objects at once.", true)
   end if
   put 0 into tCount
   repeat for each line tId in tIds
      if tId is not an integer then
         return mcbResult("An id is a whole number, as the outline gives it.", true)
      end if
      put empty into tObject
      if there is a card id tId of tStack then
         put the long id of card id tId of tStack into tObject
      else if there is a control id tId of tStack then
         put the long id of control id tId of tStack into tObject
      else if there is an audioClip id tId of tStack or there is a videoClip id tId of tStack then
         -- Not controls: what the engine says of them
         add 1 to tCount
         if tText is not empty then
            put return & return after tText
         end if
         put mcbClipText(tStack, tId) after tText
         next repeat
      end if
      if tObject is empty then
         put tId & ", " after tMissing
         next repeat
      end if
      add 1 to tCount
      if tText is not empty then
         put return & return after tText
      end if
      put xtaObjectText(tObject, tLean) after tText
   end repeat
   if tMissing is not empty then
      delete char -2 to -1 of tMissing
      if tText is not empty then
         put return & return after tText
      end if
      put "The stack" && quote & the short name of tStack & quote && "has no card or control with the id" && tMissing & \
            ". Ids repeat from stack to stack: name the substack it is in as stack." after tText
   end if
   return mcbResult(mcbWithScriptHint(tText), tCount is 0)
end mcbToolReadStack

-- An object's text, and when its script was cut, how to read the rest and
-- change it without sending it back whole
-- The sounds and videos kept in a main stack and its substacks (they are
-- not controls, so the outline has none), a line each, after a blank
-- line, or empty when there are none
private function mcbClipsText pMain
   local tText, tStacks, tStack, tIndex
   put pMain & return into tStacks
   repeat for each line tStack in the substacks of pMain
      put the long id of stack tStack of pMain & return after tStacks
   end repeat
   repeat for each line tStack in tStacks
      repeat with tIndex = 1 to the number of audioClips of tStack
         put "- " & mcbClipLine(tStack, "audioClip", tIndex) & return after tText
      end repeat
      repeat with tIndex = 1 to the number of videoClips of tStack
         put "- " & mcbClipLine(tStack, "videoClip", tIndex) & return after tText
      end repeat
   end repeat
   if tText is empty then
      return empty
   end if
   return return & return & "Sounds and videos kept in the stack (read_stack with an id gives more):" & return & char 1 to -2 of tText
end mcbClipsText

-- One sound or video of pStack, the pIndex'th of its kind: its kind,
-- name, id, size and the stack it is in
private function mcbClipLine pStack, pKind, pIndex
   local tClip
   if pKind is "audioClip" then
      put the long id of audioClip pIndex of pStack into tClip
      return "audioclip" && quote & the short name of tClip & quote && "(id" && the id of tClip & "," && the size of tClip && "bytes) in stack" && quote & the short name of pStack & quote
   end if
   put the long id of videoClip pIndex of pStack into tClip
   return "videoclip" && quote & the short name of tClip & quote && "(id" && the id of tClip & "," && the size of tClip && "bytes) in stack" && quote & the short name of pStack & quote
end mcbClipLine

-- A sound or video of pStack by its id: what the engine says of it
private function mcbClipText pStack, pId
   local tClip, tText
   -- The engine keeps an imported sound as its samples, not the file it
   -- came from, so the properties are all it can say of one
   if there is an audioClip id pId of pStack then
      put the long id of audioClip id pId of pStack into tClip
      put "audioclip" && quote & the short name of tClip & quote && "(id" && pId & ")" & return into tText
      put "size:" && the size of tClip && "bytes" & return after tText
      put "playLoudness:" && the playLoudness of tClip & return after tText
      put "playDestination:" && the playDestination of tClip after tText
      return tText
   end if
   put the long id of videoClip id pId of pStack into tClip
   put "videoclip" && quote & the short name of tClip & quote && "(id" && pId & ")" & return into tText
   put "size:" && the size of tClip && "bytes" & return after tText
   put "frameRate:" && the frameRate of tClip & return after tText
   put "scale:" && the scale of tClip & return after tText
   put "dontRefresh:" && the dontRefresh of tClip after tText
   return tText
end mcbClipText

private function mcbWithScriptHint pText
   if kCutMark is in pText then
      put return & return & "The script was cut. read_script reads it all, in parts, with line numbers and its handlers; " & \
            "edit_script changes one handler or a range of lines. Do not send a cut script back with make_changes." after pText
   end if
   return pText
end mcbWithScriptHint

-- A picture of a card as it looks now, as the assistant takes it
-- A picture of a card as it looks now, as the assistant takes it, or of
-- one control of it (id); with labels, each control's id drawn on it
private function mcbToolLookAtCard pArguments
   local tTarget, tStack, tCard, tCardId, tId, tObject, tLabel, tWidth, tHeight, tScale, tSize, tData, tError, tResult, tLabels
   put mcbTarget(mcbArg(pArguments, "stack")) into tTarget
   if tTarget["problem"] is not empty then
      return mcbResult(tTarget["problem"], true)
   end if
   put tTarget["stack"] into tStack
   put word 1 to -1 of mcbArg(pArguments, "card") into tCardId
   put word 1 to -1 of mcbArg(pArguments, "id") into tId
   put mcbArg(pArguments, "labels") is "true" into tLabels
   if tCardId is empty then
      put the long id of this card of tStack into tCard
   else if tCardId is an integer and there is a card id tCardId of tStack then
      put the long id of card id tCardId of tStack into tCard
   else
      return mcbResult("The stack" && quote & the short name of tStack & quote && "has no card with the id" && tCardId & ".", true)
   end if
   if tId is not empty then
      if tId is not an integer or there is not a control id tId of tStack then
         return mcbResult("The stack" && quote & the short name of tStack & quote && "has no control with the id" && tId & ".", true)
      end if
      put the long id of control id tId of tStack into tObject
      put mcbObjectLabel(tObject) into tLabel
      put the width of tObject into tWidth
      put the height of tObject into tHeight
   else
      put tCard into tObject
      put the name of tCard into tLabel
      if char 1 of word 2 of tLabel is quote then
         put "card" && quote & the short name of tCard & quote && "(id" && the short id of tCard & ")" into tLabel
      end if
      put the width of tStack into tWidth
      put the height of tStack into tHeight
   end if
   put 1 into tScale
   if max(tWidth, tHeight) > kPictureSide then
      put kPictureSide / max(tWidth, tHeight) into tScale
   end if
   put max(1, round(tWidth * tScale)) & comma & max(1, round(tHeight * tScale)) into tSize
   try
      export snapshot from tObject at size tSize to tData as PNG
   catch tError
      put empty into tData
   end try
   if tData is empty then
      return mcbResult("The picture of" && tLabel && "could not be taken.", true)
   end if
   if tLabels and tId is empty then
      put mcbWithIds(tData, tCard, tScale, tSize) into tData
   end if
   put base64Encode(tData) into tResult["image"]
   replace return with empty in tResult["image"]
   put "image/png" into tResult["imageType"]
   put "A picture of" && tLabel && "of the stack" && quote & the short name of tStack & quote & ", as it looks now:" && \
         tWidth && "by" && tHeight && "pixels" into tResult["text"]
   if tScale < 1 then
      put ", shown at" && item 1 of tSize && "by" && item 2 of tSize after tResult["text"]
   end if
   if tLabels and tId is empty then
      put ", each visible control outlined in red with its id in a yellow box at its top left" after tResult["text"]
   end if
   put "." after tResult["text"]
   put false into tResult["error"]
   return tResult
end mcbToolLookAtCard

-- The picture pData of the card pCard (taken at pScale, pSize), with each
-- visible control outlined and its id at its top left: drawn in a hidden
-- stack of the bridge's own, deleted after, so that nothing of the user's
-- is touched. The picture as it was when it cannot be drawn.
private function mcbWithIds pData, pCard, pScale, pSize
   local tOldDefault, tIndex, tControl, tRect, tItem, tData, tError, tStack
   put the defaultStack into tOldDefault
   lock screen
   lock messages
   try
      if there is a stack kOverlayStack then
         delete stack kOverlayStack
      end if
      create invisible stack kOverlayStack
      put the long id of stack kOverlayStack into tStack
      set the _ideoverride of tStack to true
      set the defaultStack to kOverlayStack
      set the rect of tStack to 0, 0, item 1 of pSize, item 2 of pSize
      create image "Card" in card 1 of tStack
      set the text of image "Card" of tStack to pData
      set the rect of image "Card" of tStack to 0, 0, item 1 of pSize, item 2 of pSize
      repeat with tIndex = 1 to the number of controls of pCard
         put the long id of control tIndex of pCard into tControl
         if not the visible of tControl then
            next repeat
         end if
         put the rect of tControl into tRect
         repeat with tItem = 1 to 4
            put round(item tItem of tRect * pScale) into item tItem of tRect
         end repeat
         create graphic in card 1 of tStack
         set the style of last graphic of card 1 of tStack to "rectangle"
         set the opaque of last graphic of card 1 of tStack to false
         set the lineSize of last graphic of card 1 of tStack to 1
         set the foregroundColor of last graphic of card 1 of tStack to "255,0,0"
         set the rect of last graphic of card 1 of tStack to tRect
         create field in card 1 of tStack
         set the text of last field of card 1 of tStack to the short id of tControl
         set the textSize of last field of card 1 of tStack to 10
         set the textColor of last field of card 1 of tStack to "0,0,0"
         set the opaque of last field of card 1 of tStack to true
         set the backgroundColor of last field of card 1 of tStack to "255,255,128"
         set the showBorder of last field of card 1 of tStack to false
         set the margins of last field of card 1 of tStack to 1
         set the width of last field of card 1 of tStack to the formattedWidth of last field of card 1 of tStack
         set the height of last field of card 1 of tStack to the formattedHeight of last field of card 1 of tStack
         set the topLeft of last field of card 1 of tStack to item 1 to 2 of tRect
      end repeat
      export snapshot from card 1 of tStack at size pSize to tData as PNG
   catch tError
      put empty into tData
   end try
   if there is a stack kOverlayStack then
      delete stack kOverlayStack
   end if
   unlock messages
   if tOldDefault is not empty and there is a stack tOldDefault then
      set the defaultStack to tOldDefault
   end if
   unlock screen
   if tData is empty then
      return pData
   end if
   return tData
end mcbWithIds

private function mcbToolDictionary pTerm
   local tTerm, tEntries, tError, tNear, tText
   put word 1 to -1 of pTerm into tTerm
   if tTerm is empty then
      return mcbResult("Give the term to look up.", true)
   end if
   try
      put ideDocsFetchLCSData(tTerm) into tEntries
      if the number of elements of tEntries is 0 and word 1 of tTerm is "the" and the number of words of tTerm > 1 then
         put word 2 to -1 of tTerm into tTerm
         put ideDocsFetchLCSData(tTerm) into tEntries
      end if
   catch tError
      return mcbResult("The Dictionary cannot be read here.", true)
   end try
   put xtaDictionaryText(tTerm, tEntries) into tText
   if the number of elements of tEntries is 0 then
      put xtaNearest(tTerm, mcbDictionaryNames(), kNearestEntries) into tNear
      if tNear is not empty then
         replace return with ", " in tNear
         put return & "The entries with the nearest names:" && tNear & "." after tText
      end if
   end if
   return mcbResult(tText, false)
end mcbToolDictionary

-- The names of the xTalk Script entries of the Dictionary, one per line,
-- read once from the IDE's documentation database (empty when it cannot
-- be read)
private function mcbDictionaryNames
   local tConnection, tNames, tEntries, tIndex, tError
   if sDictionaryNames is not empty then
      return sDictionaryNames
   end if
   try
      ideDocsInitialize
      put the result into tConnection
      if tConnection is an integer then
         put revDataFromQuery(tab, return, tConnection, \
               "SELECT DISTINCT entry_name FROM dictionary_data WHERE library_name = 'LiveCode Script'") into tNames
         if tNames begins with "revdberr" then
            put empty into tNames
         end if
      end if
   catch tError
      put empty into tNames
   end try
   if tNames is empty then
      try
         put ideDocsFetchLCSEntries() into tEntries
         repeat with tIndex = 1 to the number of elements of tEntries
            put tEntries[tIndex]["display name"] & return after tNames
         end repeat
      catch tError
         put empty into tNames
      end try
   end if
   put tNames into sDictionaryNames
   return tNames
end mcbDictionaryNames

private function mcbToolCheck pCode
   local tCheck, tText, tLine
   if word 1 to -1 of pCode is empty then
      return mcbResult("Give the code to check.", true)
   end if
   put xtaCheckScript(pCode, empty) into tCheck
   if tCheck["ok"] is true then
      return mcbResult("The code compiles on " & mcbHostName() & "'s engine. That is not the same as doing what was asked.", false)
   end if
   put "The code does not compile on " & mcbHostName() & "'s engine:" into tText
   repeat for each line tLine in tCheck["issues"]
      put return & "- " & tLine after tText
   end repeat
   return mcbResult(tText, false)
end mcbToolCheck

private function mcbToolDebugState
   local tState
   put xtaDebugState() into tState
   if tState["paused"] is not true then
      return mcbResult(tState["text"] && "To pause a script, the user sets a breakpoint (a click left of a line in the Script Editor) and runs the script, " & \
            "or turns on Script Debug Mode (Development menu) and lets it stop at an error.", false)
   end if
   return mcbResult(tState["text"], false)
end mcbToolDebugState

--------------------------------------------------------------------------------
-- Scripts, in parts
--
-- read_stack gives the first 24,000 characters of a script, and a batch of
-- make_changes sets a whole script: a long one could not be read whole,
-- and one sent back as read would lose what was cut. read_script reads a
-- script in parts, with line numbers and where each handler is, and
-- edit_script changes one handler, or a range of lines that must still
-- read as Claude read them, then sets the whole script through a batch
-- like any other (checked, compiled, journaled, undone by undo_changes).

-- The object a tool names in pStackName: pId empty or "stack" for that
-- stack, else the id of a card or control of it. An array with "object"
-- (a long id) and "label", or "problem".
private function mcbScriptObject pStackName, pId
   local tTarget, tStack, tResult
   put mcbTarget(pStackName) into tTarget
   if tTarget["problem"] is not empty then
      put tTarget["problem"] && "list_stacks names the user's stacks." into tResult["problem"]
      return tResult
   end if
   put tTarget["stack"] into tStack
   put word 1 to -1 of pId into pId
   if pId is empty or pId is "stack" then
      put tStack into tResult["object"]
   else if pId is not an integer then
      put "An id is a whole number, as read_stack gives it (or stack, for the stack's own script)." into tResult["problem"]
      return tResult
   else if there is a card id pId of tStack then
      put the long id of card id pId of tStack into tResult["object"]
   else if there is a control id pId of tStack then
      put the long id of control id pId of tStack into tResult["object"]
   else
      put "The stack" && quote & the short name of tStack & quote && "has no card or control with the id" && pId & \
            ". Ids repeat from stack to stack: name the substack it is in as stack." into tResult["problem"]
      return tResult
   end if
   put mcbObjectLabel(tResult["object"]) into tResult["label"]
   return tResult
end mcbScriptObject

-- An object as the user would name it: its type, name and id. A stack
-- whose hcAddressing is true (every stack imported from HyperCard) names
-- its controls as HyperCard did, "card button" or "bkgnd field": the
-- type is then the second word, and a background's control is called so
private function mcbObjectLabel pObject
   local tName, tType
   put the name of pObject into tName
   put word 1 of tName into tType
   if tType is "stack" then
      return "the stack" && quote & the short name of pObject & quote
   end if
   if tType is among the items of "card,bkgnd,background" and char 1 of word 2 of tName is not quote and word 2 of tName is not "id" then
      if tType is "card" then
         put word 2 of tName into tType
      else
         put "background" && word 2 of tName into tType
      end if
   else if tType is "bkgnd" then
      put "background" into tType
   end if
   return "the" && tType && quote & the short name of pObject & quote && "(id" && the short id of pObject & ")"
end mcbObjectLabel

-- The script of pObject, or throws (a password-protected stack's cannot
-- be read)
private function mcbScriptOf pObject
   local tScript
   put the script of pObject into tScript
   replace crlf with return in tScript
   replace numToChar(13) with return in tScript
   return tScript
end mcbScriptOf

-- The handlers of a script, one per line: kind (on, command, function,
-- getprop, setprop, before, after; "private" before it), tab, name, tab,
-- first line, tab, last line. Read from the text, so that a script that
-- does not compile has them too: a handler begins at a line whose first
-- word is its kind and ends at "end" and its name.
private function mcbHandlers pScript
   local tLineNo, tLine, tKind, tName, tStart, tList, tWords
   put 0 into tLineNo
   repeat for each line tLine in pScript
      add 1 to tLineNo
      put word 1 to -1 of tLine into tWords
      if tName is empty then
         if matchText(tWords, "(?i)^((?:private\s+)?(?:on|command|function|getprop|setprop|before|after))\s+([^\s(]+)", tKind, tName) then
            put tLineNo into tStart
            put toLower(tKind) into tKind
            replace tab with space in tKind
         end if
      else if toLower(word 1 of tWords) is "end" and toLower(word 2 of tWords) is toLower(tName) then
         put tKind & tab & tName & tab & tStart & tab & tLineNo & return after tList
         put empty into tName
      end if
   end repeat
   if tName is not empty then
      -- Never ended: to the end of the script
      put tKind & tab & tName & tab & tStart & tab & tLineNo & return after tList
   end if
   if tList is not empty then
      delete the last char of tList
   end if
   return tList
end mcbHandlers

-- The lines of pHandlers named pName (any kind), one per line
private function mcbHandlersNamed pHandlers, pName
   local tLine, tFound
   set the itemDelimiter to tab
   repeat for each line tLine in pHandlers
      if toLower(item 2 of tLine) is toLower(pName) then
         put tLine & return after tFound
      end if
   end repeat
   if tFound is not empty then
      delete the last char of tFound
   end if
   return tFound
end mcbHandlersNamed

-- Lines pFrom to pTo of pScript, each after its number
private function mcbNumbered pScript, pFrom, pTo
   local tOut, tLineNo
   repeat with tLineNo = pFrom to pTo
      put tLineNo & ":" && line tLineNo of pScript & return after tOut
   end repeat
   return tOut
end mcbNumbered

private function mcbToolReadScript pArguments
   local tFound, tObject, tScript, tError, tHandlers, tTotal, tFrom, tTo, tName, tMatches, tLine, tText, tChars, tLineNo, tKinds
   put mcbScriptObject(mcbArg(pArguments, "stack"), mcbArg(pArguments, "id")) into tFound
   if tFound["problem"] is not empty then
      return mcbResult(tFound["problem"], true)
   end if
   put tFound["object"] into tObject
   try
      put mcbScriptOf(tObject) into tScript
   catch tError
      return mcbResult("The script of" && tFound["label"] && "cannot be read (its stack is password-protected).", true)
   end try
   if tScript is empty then
      return mcbResult(tFound["label"] && "has no script.", false)
   end if
   put the number of lines of tScript into tTotal
   put mcbHandlers(tScript) into tHandlers
   set the itemDelimiter to tab
   put word 1 to -1 of mcbArg(pArguments, "handler") into tName
   if tName is not empty then
      put mcbHandlersNamed(tHandlers, tName) into tMatches
      if tMatches is empty then
         return mcbResult("The script of" && tFound["label"] && "has no handler named" && quote & tName & quote & ". Its handlers:" & return & \
               mcbHandlerIndex(tHandlers), true)
      end if
      put "The script of" && tFound["label"] & "," && tTotal && "lines; the handler" && tName & ":" & return into tText
      repeat for each line tLine in tMatches
         put mcbNumbered(tScript, item 3 of tLine, item 4 of tLine) after tText
      end repeat
      delete the last char of tText
      return mcbResult(tText, false)
   end if
   put mcbArg(pArguments, "from_line") into tFrom
   put mcbArg(pArguments, "to_line") into tTo
   if tFrom is empty then
      put 1 into tFrom
   end if
   if tTo is empty then
      put tTotal into tTo
   end if
   if tFrom is not an integer or tTo is not an integer or tFrom < 1 or tTo < tFrom then
      return mcbResult("from_line and to_line are line numbers, from 1, with to_line not before from_line.", true)
   end if
   if tFrom > tTotal then
      return mcbResult("The script of" && tFound["label"] && "has" && tTotal && "lines.", true)
   end if
   put min(tTo, tTotal) into tTo
   -- At most kScriptReadChars at once, whole lines (one line at least)
   put 0 into tChars
   repeat with tLineNo = tFrom to tTo
      add the number of chars of line tLineNo of tScript + 8 to tChars
      if tChars > kScriptReadChars and tLineNo > tFrom then
         put tLineNo - 1 into tTo
         exit repeat
      end if
   end repeat
   put "The script of" && tFound["label"] & "," && tTotal && "lines." into tText
   if tFrom is 1 and tHandlers is not empty then
      put return & "Its handlers:" & return & mcbHandlerIndex(tHandlers) after tText
   end if
   put return & "Lines" && tFrom && "to" && tTo & ":" & return & mcbNumbered(tScript, tFrom, tTo) after tText
   delete the last char of tText
   if tTo < tTotal then
      put return & "(" & tTotal - tTo && "more lines: read on with from_line" && tTo + 1 & ".)" after tText
   end if
   return mcbResult(tText, false)
end mcbToolReadScript

-- The handlers, one per line, for Claude: "on mouseUp, lines 3 to 9"
private function mcbHandlerIndex pHandlers
   local tLine, tOut
   set the itemDelimiter to tab
   repeat for each line tLine in pHandlers
      put "- " & item 1 of tLine && item 2 of tLine & ", lines" && item 3 of tLine && "to" && item 4 of tLine & return after tOut
   end repeat
   if tOut is empty then
      return "(none)"
   end if
   delete the last char of tOut
   return tOut
end mcbHandlerIndex

-- Finds pArguments' text (or with regex, a pattern) in the scripts of the
-- user's stacks: that stack's main stack and its substacks, or every
-- stack of the user's open when none is named. Each line found with its
-- object, line number and the handler it is in; case is ignored.
private function mcbToolSearchScripts pArguments
   local tText, tRegex, tTarget, tStacks, tStack, tName, tObjects, tObject, tSeen, tList, tError, tLine, \
         tFound, tCount, tShown, tOut, tLocked, tCard, tCtl
   put mcbArg(pArguments, "text") into tText
   if tText is empty then
      return mcbResult("Give the text to find.", true)
   end if
   put mcbArg(pArguments, "regex") is "true" into tRegex
   if tRegex then
      if char 1 to 2 of tText is not "(?" then
         put "(?i)" & tText into tText
      end if
      try
         get matchText("", tText)
      catch tError
         return mcbResult("The regular expression cannot be read:" && line 1 of tError, true)
      end try
   end if
   if word 1 to -1 of mcbArg(pArguments, "stack") is empty then
      repeat for each line tName in the mainStacks
         if there is a stack tName then
            if not mcbIsIDEStack(the long id of stack tName) then
               put the long id of stack tName & return after tStacks
            end if
         end if
      end repeat
      if tStacks is empty then
         return mcbResult("The user has no stack of their own open in " & mcbHostName() & ".", true)
      end if
   else
      put mcbTarget(mcbArg(pArguments, "stack")) into tTarget
      if tTarget["problem"] is not empty then
         return mcbResult(tTarget["problem"] && "list_stacks names the user's stacks.", true)
      end if
      put mcbMainStackOf(tTarget["stack"]) & return into tStacks
   end if
   -- Every object with a script: each stack, its cards, their controls
   repeat for each line tStack in tStacks
      put tStack & return after tObjects
      repeat for each line tName in the substacks of tStack
         put the long id of stack tName of tStack & return after tObjects
      end repeat
   end repeat
   put 0 into tCount
   put 0 into tShown
   repeat for each line tStack in tObjects
      if word 1 of tStack is not "stack" then
         next repeat
      end if
      put tStack & return into tList
      repeat with tCard = 1 to the number of cards of tStack
         put the long id of card tCard of tStack & return after tList
         repeat with tCtl = 1 to the number of controls of card tCard of tStack
            put the long id of control tCtl of card tCard of tStack & return after tList
         end repeat
      end repeat
      repeat for each line tObject in tList
         if tSeen[tObject] is true then
            next repeat
         end if
         put true into tSeen[tObject]
         try
            put mcbScriptSearched(tObject, tText, tRegex) into tFound
         catch tError
            put quote & the short name of tStack & quote & ", " after tLocked
            exit repeat
         end try
         repeat for each line tLine in tFound
            add 1 to tCount
            if tShown < kMaxSearchMatches then
               add 1 to tShown
               put "- " & mcbObjectLabel(tObject) after tOut
               if word 1 of tObject is not "stack" then
                  put " of stack" && quote & the short name of mcbStackOfObject(tObject) & quote after tOut
               end if
               put ", " & tLine & return after tOut
            end if
         end repeat
      end repeat
   end repeat
   if tCount is 0 then
      put "No script contains" && quote & mcbArg(pArguments, "text") & quote & "." into tOut
   else
      put "Found in" && tCount && "lines (the handler each is in after its number):" & return before tOut
      delete the last char of tOut
      if tCount > tShown then
         put return & "(" & tCount - tShown && "more lines found: search for something narrower.)" after tOut
      end if
   end if
   if tLocked is not empty then
      put return & "Not searched (password-protected):" && char 1 to -3 of tLocked & "." after tOut
   end if
   return mcbResult(tOut, false)
end mcbToolSearchScripts

-- The lines of pObject's script holding pText (a regular expression when
-- pRegex), one per line: "line N (in on mouseUp): the line"; a line
-- that begins the handler named pText says "defines it". Throws for a
-- password-protected stack.
private function mcbScriptSearched pObject, pText, pRegex
   local tScript, tHandlers, tLineNo, tLine, tOut, tHandler, tIn, tHit
   put mcbScriptOf(pObject) into tScript
   if tScript is empty then
      return empty
   end if
   if not pRegex and not (pText is in tScript) then
      return empty
   end if
   put mcbHandlers(tScript) into tHandlers
   set the itemDelimiter to tab
   put 0 into tLineNo
   repeat for each line tLine in tScript
      add 1 to tLineNo
      if pRegex then
         put matchText(tLine, pText) into tHit
      else
         put pText is in tLine into tHit
      end if
      if not tHit then
         next repeat
      end if
      put empty into tIn
      repeat for each line tHandler in tHandlers
         if tLineNo >= item 3 of tHandler and tLineNo <= item 4 of tHandler then
            put " (in" && item 1 of tHandler && item 2 of tHandler into tIn
            if tLineNo is item 3 of tHandler and toLower(item 2 of tHandler) is toLower(word 1 to -1 of pText) then
               put ", defines it" after tIn
            end if
            put ")" after tIn
            exit repeat
         end if
      end repeat
      put word 1 to -1 of tLine into tLine
      if the number of chars of tLine > kSearchLineChars then
         put char 1 to kSearchLineChars of tLine & "..." into tLine
      end if
      put "line" && tLineNo & tIn & ":" && tLine & return after tOut
   end repeat
   return tOut
end mcbScriptSearched

-- Changes part of a script: the handler named (replaced by code, which is
-- that handler whole; added at the end when the script has none of that
-- name; or deleted with delete), or lines from_line to to_line (replaced
-- by code, when they still read as old_text). The whole script is then
-- set by a batch of one change, as make_changes sets one.
private function mcbToolEditScript pArguments
   local tFound, tObject, tScript, tError, tHandlers, tName, tMatches, tCode, tDelete, tFrom, tTo, tOld, tNew, tTotal, tCodeHandlers
   local tWhat, tBatch, tPlan, tApplied, tId, tCurrent
   put mcbScriptObject(mcbArg(pArguments, "stack"), mcbArg(pArguments, "id")) into tFound
   if tFound["problem"] is not empty then
      return mcbResult("Nothing was changed:" && tFound["problem"], true)
   end if
   put tFound["object"] into tObject
   try
      put mcbScriptOf(tObject) into tScript
   catch tError
      return mcbResult("Nothing was changed: the script of" && tFound["label"] && "cannot be read (its stack is password-protected).", true)
   end try
   put the number of lines of tScript into tTotal
   put xtaJsonText(xtaJsonMember(pArguments, "code")) into tCode
   replace crlf with return in tCode
   replace numToChar(13) with return in tCode
   if the last char of tCode is return then
      delete the last char of tCode
   end if
   put (mcbArg(pArguments, "delete") is true) into tDelete
   put word 1 to -1 of mcbArg(pArguments, "handler") into tName
   set the itemDelimiter to tab
   if tName is not empty then
      put mcbHandlers(tScript) into tHandlers
      put mcbHandlersNamed(tHandlers, tName) into tMatches
      if the number of lines of tMatches > 1 then
         return mcbResult("Nothing was changed: the script of" && tFound["label"] && "has more than one handler named" && quote & tName & quote & \
               " (" & mcbHandlerIndex(tMatches) & "). Change one by its lines: from_line, to_line and old_text.", true)
      end if
      if tDelete then
         if tMatches is empty then
            return mcbResult("Nothing was changed: the script of" && tFound["label"] && "has no handler named" && quote & tName & quote & ".", true)
         end if
         put item 3 of tMatches into tFrom
         put item 4 of tMatches into tTo
         -- An empty line after it goes with it
         if tTo < tTotal and word 1 to -1 of line tTo + 1 of tScript is empty then
            add 1 to tTo
         end if
         put mcbScriptWithout(tScript, tFrom, tTo) into tNew
         put "Deleted the handler" && tName && "from the script of" && tFound["label"] into tWhat
      else
         if word 1 to -1 of tCode is empty then
            return mcbResult("Nothing was changed: give the handler's new text as code (the whole handler, from its first line to its end line), " & \
                  "or delete: true to delete it.", true)
         end if
         put mcbHandlers(tCode) into tCodeHandlers
         if the number of lines of tCodeHandlers is not 1 or toLower(item 2 of tCodeHandlers) is not toLower(tName) \
               or item 3 of tCodeHandlers is not 1 or item 4 of tCodeHandlers is not the number of lines of tCode then
            return mcbResult("Nothing was changed: code must be the one handler" && tName & ", whole, from its first line to its end line, and nothing else. " & \
                  "To add other handlers, edit them one at a time; to change other lines, use from_line, to_line and old_text.", true)
         end if
         if tMatches is empty then
            if tScript is empty then
               put tCode into tNew
            else
               put tScript into tNew
               if word 1 to -1 of line -1 of tNew is not empty then
                  put return after tNew
               end if
               put return & tCode after tNew
            end if
            put "Added the handler" && tName && "to the script of" && tFound["label"] into tWhat
         else
            put mcbScriptReplacing(tScript, item 3 of tMatches, item 4 of tMatches, tCode) into tNew
            put "Replaced the handler" && tName && "in the script of" && tFound["label"] into tWhat
         end if
      end if
   else
      put mcbArg(pArguments, "from_line") into tFrom
      put mcbArg(pArguments, "to_line") into tTo
      if tFrom is empty and tTo is empty then
         return mcbResult("Nothing was changed: name the handler, or give from_line, to_line and old_text.", true)
      end if
      if tFrom is not an integer or tTo is not an integer or tFrom < 1 or tTo < tFrom or tTo > tTotal then
         return mcbResult("Nothing was changed: from_line and to_line are line numbers of the script (it has" && tTotal && \
               "lines), with to_line not before from_line.", true)
      end if
      if xtaJsonType(xtaJsonMember(pArguments, "old_text")) is not "string" then
         return mcbResult("Nothing was changed: give old_text, lines" && tFrom && "to" && tTo && "as you read them (without their numbers), " & \
               "so that a script changed since is not changed in the wrong place.", true)
      end if
      put xtaJsonText(xtaJsonMember(pArguments, "old_text")) into tOld
      replace crlf with return in tOld
      replace numToChar(13) with return in tOld
      if the last char of tOld is return then
         delete the last char of tOld
      end if
      put line tFrom to tTo of tScript into tCurrent
      if not mcbSameText(tOld, tCurrent) then
         return mcbResult("Nothing was changed: lines" && tFrom && "to" && tTo && "of the script of" && tFound["label"] && \
               "do not read as old_text (the script changed, or the lines are not those). They read:" & return & \
               mcbNumbered(tScript, tFrom, tTo) & "Read the script again (read_script) and send the edit again.", true)
      end if
      if tDelete or xtaJsonType(xtaJsonMember(pArguments, "code")) is not "string" then
         if not tDelete then
            return mcbResult("Nothing was changed: give the new lines as code (an empty string deletes the lines), or delete: true.", true)
         end if
         put empty into tCode
      end if
      if tCode is empty then
         put mcbScriptWithout(tScript, tFrom, tTo) into tNew
         put "Deleted lines" && tFrom && "to" && tTo && "of the script of" && tFound["label"] into tWhat
      else
         put mcbScriptReplacing(tScript, tFrom, tTo, tCode) into tNew
         put "Replaced lines" && tFrom && "to" && tTo && "of the script of" && tFound["label"] && "with" && \
               the number of lines of tCode && "line(s)" into tWhat
      end if
   end if

   -- The whole script, set by a batch of one change: checked and compiled
   -- first, then made and journaled as make_changes makes a change
   if word 1 of the name of tObject is "stack" then
      put mcbJsonString("stack") into tId
   else
      put the short id of tObject into tId
   end if
   put "{" & mcbJsonString("stack") & ":" & mcbJsonString(mcbArg(pArguments, "stack")) & "," & \
         mcbJsonString("changes") & ":[{" & mcbJsonString("action") & ":" & mcbJsonString("set") & "," & \
         mcbJsonString("object") & ":" & tId & "," & mcbJsonString("script") & ":" & mcbJsonString(tNew) & "}]}" into tBatch
   put xtaBuildPlan(xtaJsonParse(tBatch), mcbWorkStack()) into tPlan
   if tPlan["ok"] is not true then
      return mcbResult("Nothing was changed: with this edit, the script would have mistakes (line numbers are those of the whole script after the edit):" & \
            return & tPlan["problems"], true)
   end if
   put xtaBuildApply(tPlan) into tApplied
   if tApplied["ok"] is not true then
      return mcbResult(tApplied["error"], true)
   end if
   return mcbResult(tWhat & ". The script now has" && the number of lines of tNew && "lines (line numbers after the edit have moved: read again before another edit by lines)." & \
         return & "This is change" && tApplied["entry"] & "; undo_changes takes it back.", false)
end mcbToolEditScript

-- pScript without lines pFrom to pTo
private function mcbScriptWithout pScript, pFrom, pTo
   local tBefore, tAfter
   if pFrom > 1 then
      put line 1 to pFrom - 1 of pScript into tBefore
   end if
   if pTo < the number of lines of pScript then
      put line pTo + 1 to -1 of pScript into tAfter
   end if
   if tBefore is empty then
      return tAfter
   end if
   if tAfter is empty then
      return tBefore
   end if
   return tBefore & return & tAfter
end mcbScriptWithout

-- pScript with lines pFrom to pTo replaced by pCode
private function mcbScriptReplacing pScript, pFrom, pTo, pCode
   local tOut
   if pFrom > 1 then
      put line 1 to pFrom - 1 of pScript & return into tOut
   end if
   put pCode after tOut
   if pTo < the number of lines of pScript then
      put return & line pTo + 1 to -1 of pScript after tOut
   end if
   return tOut
end mcbScriptReplacing

-- Two texts the same, line for line, but for spaces at the ends of lines,
-- and with case counted
private function mcbSameText pA, pB
   local tLine, tA, tB
   set the caseSensitive to true
   repeat for each line tLine in pA
      put mcbTrimEnd(tLine) & return after tA
   end repeat
   repeat for each line tLine in pB
      put mcbTrimEnd(tLine) & return after tB
   end repeat
   return ("t" & tA) is ("t" & tB)
end mcbSameText

private function mcbTrimEnd pLine
   repeat while the number of chars of pLine > 0 and (the last char of pLine is space or the last char of pLine is tab)
      delete the last char of pLine
   end repeat
   return pLine
end mcbTrimEnd

--------------------------------------------------------------------------------
-- The tools that change, run and save

-- A batch of changes, checked (a mistake goes back with nothing changed),
-- then made whole or not at all, and journaled for undo_changes
private function mcbToolMakeChanges pArguments
   local tPlan, tApplied, tText, tChange, tMoved
   -- A script copied from a cut read would put the cut one in place of the
   -- whole
   repeat for each element tChange in mcbChangesOf(pArguments)
      if kCutMark is in xtaJsonText(xtaJsonMember(tChange, "script")) then
         return mcbResult("Nothing was changed: a script in the batch ends as read_stack cut it (" & quote & "..." && kCutMark & quote & \
               "), and would replace the whole script with that part. Use edit_script to change part of a long script.", true)
      end if
   end repeat
   put xtaBuildPlan(pArguments, mcbWorkStack()) into tPlan
   if tPlan["ok"] is not true then
      return mcbResult("Nothing was changed: the batch has mistakes. Correct them, then send the whole batch again." & return & tPlan["problems"], true)
   end if
   put xtaBuildApply(tPlan) into tApplied
   if tApplied["ok"] is not true then
      return mcbResult(tApplied["error"], true)
   end if
   put tApplied["text"] into tText
   -- A new stack whose rect put part of its window off the screen (0,0,...
   -- hides its title bar above it) is moved whole onto the screen
   if tPlan["newStack"] is true and there is a stack tPlan["name"] then
      xtaKeepOnScreen the long id of stack tPlan["name"], false
      put the result into tMoved
      if tMoved is not empty then
         put return & "Its window was moved to" && tMoved & ", so that all of it, its title bar too, is on the screen." after tText
      end if
   end if
   put return & "This is change" && tApplied["entry"] & "; undo_changes takes it back." after tText
   return mcbResult(tText, false)
end mcbToolMakeChanges

-- The changes of a batch, as parsed JSON objects (empty when there are
-- none, or they are not a list: xtaBuildPlan says so)
private function mcbChangesOf pArguments
   local tChanges, tList, tIndex
   put xtaJsonMember(pArguments, "changes") into tChanges
   if xtaJsonType(tChanges) is not "array" then
      return empty
   end if
   repeat with tIndex = 1 to xtaJsonCount(tChanges)
      put xtaJsonItem(tChanges, tIndex) into tList[tIndex]
   end repeat
   return tList
end mcbChangesOf

-- Code run in a sandbox or on the user's stack (after a checkpoint, which
-- undo_changes goes back to), after the user says yes in OXT-Beyond, every
-- time (unless they chose not to be asked: mcbAllow). The sandbox is a hidden stack in this same engine, so its code can
-- do whatever the IDE can; and xtaRiskScan reads the code's text, which
-- code can always word so that it is not seen ("the shell of", a "do" of
-- text it builds, a handler the code calls), so it only says what the
-- code seems to use. In the xTalk Assistant the user reads the code in
-- its window before Run; through the bridge, Claude's app may have been
-- told to allow every call, so this question is the user's only look.
private function mcbToolRunCode pArguments
   local tRun, tRisks, tTitle, tDetail, tRan, tText, tParts, tLong, tMax, tPaused
   put xtaRunPlan(pArguments, mcbWorkStack()) into tRun
   if tRun["ok"] is not true then
      return mcbResult("Nothing ran:" && tRun["problems"], true)
   end if
   put "Claude asks to run code." into tTitle
   if tRun["risks"] is not empty then
      put tRun["risks"] into tRisks
      replace return with ", " in tRisks
      put "It seems to use" && tRisks & ", and what it does there cannot be undone." & return into tDetail
   end if
   put tRun["label"] & "." && "It can do anything " & mcbHostName() & " can: run it only if you know what it does." after tDetail
   put tDetail into tParts["prose"]
   put mcbShowsLongCode() into tLong
   put tRun["code"] into tParts["code"]
   put tRun["handlers"] into tParts["handlers"]
   put return & return & tRun["code"] after tDetail
   if tRun["handlers"] is not empty then
      put return & return & "With these handlers:" & return & tRun["handlers"] after tDetail
   end if
   -- The question shows the user the whole of what would run, or nothing
   -- runs: mcbAsk cuts a longer text, and Run then ran code the user could
   -- not read. OXT-Beyond's question shows the code whole on a panel that
   -- scrolls (mcbShowsLongCode), so there it may be longer; where the
   -- question is answer's it may not
   if tLong then
      put kMaxAskLongChars into tMax
   else
      put kMaxAskChars into tMax
   end if
   -- Not asked (mcbSetUnasked), it is shown to nobody: the log keeps it whole
   if mcbIsUnasked() and sAsker is not empty and there is a sAsker then
      put empty into tMax
   end if
   if tMax is not empty and the number of chars of tDetail > tMax then
      return mcbResult("Nothing ran: the code and its handlers are too long for the user to read in the question " & mcbHostName() & \
            " asks before a run (" & the number of chars of tDetail && "characters with the question; at most" && tMax & "). " & \
            "Run shorter code: put long handlers into the stack's script with make_changes first, then run a short call to them.", true)
   end if
   if the number of chars of tDetail > kMaxAskChars then
      -- The asker refuses it if it can only ask with answer after all
      put true into tParts["long"]
   end if
   -- A script paused in the debugger: the user is told before they allow
   -- the run, and Claude with its result
   put mcbPausedText() into tPaused
   if tPaused is not empty then
      put return & "Note:" && tPaused after tParts["prose"]
      put return & "Note:" && tPaused before tDetail
   end if
   if not mcbAllow(tTitle, tDetail, "Run", tParts) then
      return mcbResult("Nothing ran: the user did not allow the run. Ask them what they would like instead; do not send the same code again.", true)
   end if
   put xtaRunCode(tRun) into tRan
   if tRan["ran"] is not true and tRan["text"] is empty then
      return mcbResult("Nothing ran:" && tRan["error"], true)
   end if
   put tRan["text"] into tText
   if tPaused is not empty then
      put return & tPaused && "(It was paused before this run.)" after tText
   end if
   if tRan["entry"] is not empty then
      put return & "This is change" && tRan["entry"] & "; undo_changes takes the stack back to before the run." after tText
   end if
   return mcbResult(tText, tRan["ok"] is not true)
end mcbToolRunCode

-- Saves a stack (its main stack, with its substacks) to its file, after
-- the user says yes in OXT-Beyond, every time (unless they chose not to be
-- asked: mcbAllow). With pFile, as that file (Save As, with no dialog: a
-- stack never saved otherwise waited on a file dialog of the system's,
-- which Claude cannot answer and during which the engine reads no socket)
private function mcbToolSaveStack pStackName, pFile, pNewName
   local tTarget, tMain, tName, tFile, tDetail, tDone, tError, tAs, tTitle, tProblem, tOldName
   put mcbTarget(pStackName) into tTarget
   if tTarget["problem"] is not empty then
      return mcbResult("Nothing was saved:" && tTarget["problem"], true)
   end if
   put mcbMainStackOf(tTarget["stack"]) into tMain
   put the short name of tMain into tName
   put the effective filename of tMain into tFile
   put "Claude asks to save the stack" && quote & tName & quote & "." into tTitle
   if pNewName is not empty and pNewName is not tName then
      put mcbNewNameProblem(pNewName, tFile) into tProblem
      if tProblem is not empty then
         return mcbResult("Nothing was saved:" && tProblem, true)
      end if
   else
      put empty into pNewName
   end if
   if pFile is not empty then
      put mcbSaveAsFile(pFile, tMain) into tAs
      if tAs["problem"] is not empty then
         return mcbResult("Nothing was saved:" && tAs["problem"], true)
      end if
      put tAs["file"] into tAs
   end if
   if tAs is not empty and not mcbSamePath(tAs, tFile) then
      put "Claude asks to save the stack" && quote & tName & quote && "as a new file." into tTitle
      put "It is saved, with its substacks, as:" & return & tAs & return & "and keeps that file from then on." into tDetail
      if tFile is not empty then
         put return & "Its file until now stays as it was:" & return & tFile after tDetail
      end if
   else if tFile is empty then
      put "It has never been saved: you choose where, in the dialog that comes next." into tDetail
   else
      put "It is saved to its file, with its substacks:" & return & tFile into tDetail
   end if
   if pNewName is not empty then
      put return & "It is named" && quote & pNewName & quote && "first (it is" && quote & tName & quote && "now)." after tDetail
   end if
   put return & return & "Saving cannot be undone." after tDetail
   if not mcbAllow(tTitle, tDetail, "Save") then
      return mcbResult("The user chose not to save the stack" && quote & tName & quote & ", and nothing was saved. Do not ask again unless they ask you to.", true)
   end if
   -- Named first, with the journal following (undo still finds what it
   -- made), and named back if it is not saved after all
   if pNewName is not empty then
      put tName into tOldName
      put xtaBuildRenameStack(tMain, pNewName) into tProblem
      if tProblem is not empty then
         return mcbResult("Nothing was saved: the stack could not be named" && quote & pNewName & quote & ":" && tProblem, true)
      end if
      put the long id of stack pNewName into tMain
      put pNewName into tName
      mcbRenameMade tOldName, pNewName
   end if
   try
      if tAs is not empty and not mcbSamePath(tAs, tFile) then
         revIDESaveStackAs tMain, tAs
      else
         revIDEActionSaveStack tMain
      end if
      put the result into tDone
   catch tError
      -- Without the IDE (the tests): the engine's own save, which needs a
      -- file
      put empty into tDone
      if tAs is not empty then
         save tMain as tAs
         put the result into tDone
      else if tFile is empty then
         put "the stack has no file" into tDone
      else
         save tMain
         put the result into tDone
      end if
   end try
   put the effective filename of tMain into tFile
   if tDone is "Cancelled" or tDone is not empty or tFile is empty or there is not a file tFile or (tAs is not empty and not mcbSamePath(tFile, tAs)) then
      if tOldName is not empty and there is a tMain then
         get xtaBuildRenameStack(tMain, tOldName)
         mcbRenameMade pNewName, tOldName
         put tOldName into tName
      end if
   end if
   if tDone is "Cancelled" then
      return mcbResult("The user cancelled saving the stack" && quote & tName & quote & ", and nothing was saved.", true)
   end if
   if tDone is not empty or tFile is empty or there is not a file tFile or (tAs is not empty and not mcbSamePath(tFile, tAs)) then
      return mcbResult("The stack" && quote & tName & quote && "was not saved:" && line 1 of tDone, true)
   end if
   return mcbResult("Saved the stack" && quote & tName & quote && "to" && tFile & ".", false)
end mcbToolSaveStack

-- Why pName cannot be the new name of a stack, or empty: only a stack
-- never saved is named (other stacks and scripts may know a saved one by
-- its name), never as another open stack or the IDE's
private function mcbNewNameProblem pName, pFile
   if pFile is not empty then
      return "only a stack never saved is named by save_stack; this one has a file (" & pFile & "). Ask the user to rename it in the Property Inspector."
   end if
   if pName contains quote or pName contains return or the number of chars of word 1 to -1 of pName is 0 then
      return "a stack's name has no quotes or line breaks, and is not empty."
   end if
   if there is a stack pName then
      return "a stack named" && quote & pName & quote && "is open already."
   end if
   if pName begins with "rev" or pName begins with "com.livecode." or pName begins with "org.openxtalk." \
         or pName is among the items of "Message Box,Answer Dialog,Ask Dialog,Home" then
      return quote & pName & quote && "is a name of the IDE's own stacks."
   end if
   return empty
end mcbNewNameProblem

--------------------------------------------------------------------------------
-- The stacks Claude made, and closing a stack

-- The names of the main stacks in memory, one per line
private function mcbMainStackNames
   return the mainStacks
end mcbMainStackNames

-- Notes the user's main stacks in memory now that were not before (one
-- name per line in pBefore) as Claude's (close_stack)
private command mcbNoteMadeStacks pBefore
   local tName
   repeat for each line tName in the mainStacks
      if tName is not among the lines of pBefore and there is a stack tName then
         if not mcbIsIDEStack(the long id of stack tName) then
            put true into sMadeStacks[tName]
         end if
      end if
   end repeat
end mcbNoteMadeStacks

private command mcbRenameMade pOld, pNew
   if sMadeStacks[pOld] is true then
      delete variable sMadeStacks[pOld]
      put true into sMadeStacks[pNew]
   end if
end mcbRenameMade

-- True when the IDE has the stack as changed since it was last saved; a
-- stack never saved counts as changed
private function mcbHasUnsavedChanges pStack
   local tEdited, tError, tName, tNames
   if the effective filename of pStack is empty then
      return true
   end if
   -- The IDE marks the stack an object is in, so a substack's changes are
   -- its own: the main stack and each substack are asked about
   put the short name of pStack & return & the substacks of pStack into tNames
   repeat for each line tName in tNames
      if tName is empty then
         next repeat
      end if
      try
         put revIDEStackIsEdited(tName) into tEdited
      catch tError
         -- Without the IDE (the tests): not known, so taken as changed
         return true
      end try
      if tEdited is true then
         return true
      end if
   end repeat
   return false
end mcbHasUnsavedChanges

-- Closes a main stack of the user's (with its substacks) and takes it out
-- of memory, with messages locked so that none of its handlers runs (a
-- closeStack that asks to save, for one). One that Claude's calls brought
-- in and that was never saved goes without a question, with a copy kept in
-- the temporary folder; any other is asked about (and, when it has changes
-- not saved, always, even with asking off: they are lost)
private function mcbToolCloseStack pStackName
   local tTarget, tMain, tName, tFile, tMade, tDetail, tLoses, tCopy, tError, tAllowed
   if pStackName is empty then
      return mcbResult("Nothing was closed: name the stack to close (list_stacks names them).", true)
   end if
   put mcbTarget(pStackName) into tTarget
   if tTarget["problem"] is not empty then
      return mcbResult("Nothing was closed:" && tTarget["problem"], true)
   end if
   put mcbMainStackOf(tTarget["stack"]) into tMain
   put the short name of tMain into tName
   put the effective filename of tMain into tFile
   put (sMadeStacks[tName] is true and tFile is empty) into tMade
   if not tMade then
      put mcbHasUnsavedChanges(tMain) into tLoses
      if tFile is empty then
         put "It has never been saved, so all of it is lost." into tDetail
      else if tLoses then
         put "Changes made since it was last saved are lost. Its file stays as it was saved:" & return & tFile into tDetail
      else
         put "Its file stays as it is, and it can be opened again from there:" & return & tFile into tDetail
      end if
      put "It is closed, with its substacks, and taken out of memory." & return & return before tDetail
      if tLoses then
         put mcbAsk("Claude asks to close the stack" && quote & tName & quote & ".", tDetail, "Close") into tAllowed
      else
         put mcbAllow("Claude asks to close the stack" && quote & tName & quote & ".", tDetail, "Close") into tAllowed
      end if
      if not tAllowed then
         return mcbResult("The user chose to keep the stack" && quote & tName & quote && "open. Do not ask again unless they ask you to.", true)
      end if
   else
      -- A copy, in case the user wanted it after all
      put specialFolderPath("temporary") & "/oxt-mcp-closed-" & the seconds & "-" & random(100000) & ".oxtstack" into tCopy
      try
         lock messages
         save tMain as tCopy
         unlock messages
      catch tError
         unlock messages
         put empty into tCopy
      end try
   end if
   try
      lock messages
      delete tMain
      unlock messages
   catch tError
      unlock messages
      return mcbResult("The stack" && quote & tName & quote && "was not closed:" && line 1 of tError, true)
   end try
   if sMadeStacks[tName] is true then
      delete variable sMadeStacks[tName]
   end if
   if tMade then
      if tCopy is not empty and there is a file tCopy then
         return mcbResult("Closed the stack" && quote & tName & quote & ", which your calls made and nobody saved. A copy is in" && tCopy & \
               ", in case the user wants it back.", false)
      end if
      return mcbResult("Closed the stack" && quote & tName & quote & ", which your calls made and nobody saved.", false)
   end if
   return mcbResult("Closed the stack" && quote & tName & quote & ".", false)
end mcbToolCloseStack

-- The file save_stack saves pStack as, from the path Claude gave: an array
-- with "file" (a full path with slashes, and a stack file's extension), or
-- "problem". It replaces no file but the stack's own: a path Claude was
-- misled into giving, or got wrong, takes nothing the user has.
private function mcbSaveAsFile pPath, pStack
   local tResult, tPath, tFolder, tLower, tExtension, tFound
   put pPath into tPath
   replace backslash with slash in tPath
   if not (char 1 of tPath is slash or matchText(tPath, "^[A-Za-z]:/")) then
      put "the file must be a full path, such as" && quote & "C:/Users/me/Documents/My Stack.oxtstack" & quote && "or" && \
            quote & "/home/me/My Stack.oxtstack" & quote & "." into tResult["problem"]
      return tResult
   end if
   if char -1 of tPath is slash then
      put "the file" && quote & pPath & quote && "names a folder, not a file." into tResult["problem"]
      return tResult
   end if
   put toLower(tPath) into tLower
   put false into tFound
   repeat for each item tExtension in ".oxtstack,.livecode,.rev,.livecodescript"
      if tLower ends with tExtension then
         put true into tFound
      end if
   end repeat
   if not tFound then
      if the scriptOnly of pStack then
         put ".livecodescript" after tPath
      else
         put ".oxtstack" after tPath
      end if
   end if
   set the itemDelimiter to slash
   put item 1 to -2 of tPath into tFolder
   if tFolder is empty then
      put slash into tFolder
   end if
   if there is not a folder tFolder then
      put "there is no folder" && quote & tFolder & quote & ". Save in a folder that exists." into tResult["problem"]
      return tResult
   end if
   if there is a folder tPath then
      put quote & tPath & quote && "is a folder." into tResult["problem"]
      return tResult
   end if
   if there is a file tPath and not mcbSamePath(tPath, the effective filename of pStack) then
      put "there is already a file" && quote & tPath & quote & ", and save_stack does not replace it. Choose another name, " & \
            "or ask the user to save over it themselves." into tResult["problem"]
      return tResult
   end if
   put tPath into tResult["file"]
   return tResult
end mcbSaveAsFile

-- True when two paths name the same file: without regard to case where
-- the system's files have none (Windows, macOS), with it elsewhere
private function mcbSamePath pA, pB
   if pA is empty or pB is empty then
      return false
   end if
   replace backslash with slash in pA
   replace backslash with slash in pB
   set the caseSensitive to (the platform is not "Win32" and the platform is not "MacOS")
   return ("p" & pA) is ("p" & pB)
end mcbSamePath

private function mcbToolListChanges
   local tEntries, tIndex, tText
   put xtaBuildEntries() into tEntries
   repeat with tIndex = 1 to the number of elements of tEntries
      put tEntries[tIndex]["number"] & ":" && tEntries[tIndex]["summary"] && "(" & tEntries[tIndex]["state"] & ")" & return after tText
   end repeat
   if tText is empty then
      return mcbResult("Nothing has been changed or run on a stack since the bridge was turned on.", false)
   end if
   delete the last char of tText
   return mcbResult("What was changed or run on the user's stacks, oldest first:" & return & tText, false)
end mcbToolListChanges

-- Undoes a change (pEntry, or the newest still applied) and every later one
-- on the same stack, newest first. When the user changed something since,
-- they are asked in OXT-Beyond first.
private function mcbToolUndo pEntry
   local tUndone
   put mcbUndo(pEntry, true, false) into tUndone
   return mcbResult(tUndone["text"], tUndone["ok"] is not true)
end mcbToolUndo

-- The newest change still applied, undone (the plugin's menu); the
-- user is asked only when they changed something since. Its text is for
-- the user, not the model.
function mcbUndoLast
   local tUndone
   put mcbUndo(empty, true, true) into tUndone
   return tUndone
end mcbUndoLast

-- pForUser: the text is for the user (the plugin's menu), not the model
private function mcbUndo pEntry, pAsk, pForUser
   local tEntries, tIndex, tUndone, tResult
   put xtaBuildEntries() into tEntries
   if pEntry is empty then
      repeat with tIndex = the number of elements of tEntries down to 1
         if tEntries[tIndex]["state"] is "applied" then
            put tEntries[tIndex]["number"] into pEntry
            exit repeat
         end if
      end repeat
      if pEntry is empty then
         put false into tResult["ok"]
         put "There is nothing to undo." into tResult["text"]
         return tResult
      end if
   end if
   if pEntry is not an integer then
      put false into tResult["ok"]
      put "An entry is a whole number, as list_changes gives it." into tResult["text"]
      return tResult
   end if
   -- A number list_changes never gave was answered "That was undone
   -- already."
   if pEntry < 1 or pEntry > the number of elements of tEntries then
      put false into tResult["ok"]
      put "There is no change" && pEntry & ": list_changes gives the numbers of the changes there are." into tResult["text"]
      return tResult
   end if
   put xtaBuildUndo(pEntry, false) into tUndone
   if tUndone["ok"] is not true and tUndone["changed"] is not empty then
      if not pAsk or not mcbAsk("Undo what Claude changed?", "Since then, this was changed:" & return & tUndone["changed"] & return & return & \
            "Undoing puts it back as it was before Claude's change.", "Undo") then
         put false into tResult["ok"]
         if pForUser then
            put "Nothing was undone." into tResult["text"]
         else
            put "Nothing was undone: the user changed what it would take back since (" & tUndone["changed"] & "), and did not let it be undone." \
                  into tResult["text"]
         end if
         return tResult
      end if
      put xtaBuildUndo(pEntry, true) into tUndone
   end if
   -- Undone, but some of it could not be put back: the entries are undone
   -- (a second try is refused), so this is not "Nothing was undone"
   if tUndone["ok"] is not true and tUndone["undone"] is not empty then
      put false into tResult["ok"]
      if pForUser then
         put tUndone["summary"] & ", but some of it could not be put back:" & return & tUndone["error"] into tResult["text"]
      else
         put tUndone["summary"] & ", but some of it could not be put back:" && tUndone["error"] & \
               " Read the stack again: it may be only partly as it was before. The change cannot be undone again." into tResult["text"]
      end if
      return tResult
   end if
   if tUndone["ok"] is not true then
      put false into tResult["ok"]
      if pForUser then
         put "It could not be undone:" && tUndone["error"] into tResult["text"]
      else
         put "Nothing was undone:" && tUndone["error"] into tResult["text"]
      end if
      return tResult
   end if
   put true into tResult["ok"]
   if pForUser then
      put tUndone["summary"] & ": the stack is as it was before Claude changed it." into tResult["text"]
   else
      put tUndone["summary"] & ". The stack is as it was before: read it again before changing it." into tResult["text"]
   end if
   return tResult
end mcbUndo

--------------------------------------------------------------------------------
-- A script from a file, waiting, quiet, and a restart

-- set_script_from_file: the whole script of a stack, a card or a control
-- becomes the text of a file on this computer, for a script too long to
-- send in a call (a test harness of megabytes). Claude's app shows the
-- user only the file's path, so OXT-Beyond's question shows the path, the
-- size, the SHA-256 of the file's bytes and the text (its beginning, when
-- it is long): asked unless the user chose not to be (mcbAllow), and then
-- noted in the log with the same. What was read for the question is what
-- is set, whatever the file holds a moment later. The script is taken
-- when the engine takes it (xtaBuildPlan's pCompileOnly): it is somebody's
-- script, not code Claude has just written, and old scripts use names they
-- do not declare. It is set as edit_script sets one, by a batch of one
-- change, journaled, which undo_changes takes back.
private function mcbToolSetScriptFromFile pArguments
   local tFile, tFound, tObject, tOld, tError, tData, tBytes, tHex, tScript, tNamed, tWhere, tTitle, tProse, tDetail, tParts
   local tMax, tId, tBatch, tPlan, tApplied, tText
   if sLink is true then
      return mcbResult("Nothing was changed: the web IDE cannot read the files of this computer. Send the script with make_changes or edit_script.", true)
   end if
   put word 1 to -1 of mcbArg(pArguments, "file") into tFile
   if the platform is "Win32" then
      replace backslash with slash in tFile
   end if
   if tFile is empty then
      return mcbResult("Nothing was changed: give the file, by its full path on this computer.", true)
   end if
   if there is not a file tFile then
      return mcbResult("Nothing was changed: there is no file" && tFile && "(give its full path).", true)
   end if
   put mcbScriptObject(mcbArg(pArguments, "stack"), mcbArg(pArguments, "id")) into tFound
   if tFound["problem"] is not empty then
      return mcbResult("Nothing was changed:" && tFound["problem"], true)
   end if
   put tFound["object"] into tObject
   try
      put mcbScriptOf(tObject) into tOld
   catch tError
      return mcbResult("Nothing was changed: the script of" && tFound["label"] && "cannot be read (its stack is password-protected).", true)
   end try
   put url ("binfile:" & tFile) into tData
   if the result is not empty then
      return mcbResult("Nothing was changed: the file" && tFile && "could not be read:" && the result, true)
   end if
   put the number of bytes of tData into tBytes
   if tBytes is 0 then
      return mcbResult("Nothing was changed: the file" && tFile && "is empty. (To empty a script, set it to nothing with make_changes.)", true)
   end if
   if tBytes > kMaxScriptFileBytes then
      return mcbResult("Nothing was changed: the file" && tFile && "has" && tBytes && "bytes, and a script from a file has" && \
            kMaxScriptFileBytes && "at most.", true)
   end if
   get binaryDecode("H*", messageDigest(tData, "SHA-256"), tHex)
   -- Text, as UTF-8: a byte of zero is in no script (a stack's own file, a
   -- picture, UTF-16)
   if byteOffset(numToByte(0), tData) > 0 then
      return mcbResult("Nothing was changed: the file" && tFile && "is not a text file of UTF-8 (a script, as a .livecodescript file holds it). " & \
            "A stack's file is opened, not set as a script.", true)
   end if
   if byte 1 to 3 of tData is (numToByte(239) & numToByte(187) & numToByte(191)) then
      delete byte 1 to 3 of tData
   end if
   put textDecode(tData, "UTF-8") into tScript
   replace crlf with return in tScript
   replace numToChar(13) with return in tScript
   -- A script-only stack's file names its stack on its first line, which
   -- is not code: emptied, not deleted, so that the lines keep the numbers
   -- they have in the file
   if word 1 of line 1 of tScript is "script" and char 1 of word 2 of line 1 of tScript is quote then
      put line 1 of tScript into tNamed
      put empty into line 1 of tScript
   end if
   if kCutMark is in line -3 to -1 of tScript then
      return mcbResult("Nothing was changed: the file ends as read_stack cut a script (" & quote & "..." && kCutMark & quote & \
            "), so it holds only part of one.", true)
   end if

   put tFound["label"] into tWhere
   if word 1 of the name of tObject is not "stack" then
      put " of stack" && quote & the short name of mcbStackOfObject(tObject) & quote after tWhere
   end if
   put "Claude asks to set a script from a file." into tTitle
   put "The script of" && tWhere && "would become the text of this file:" & return & tFile & return & \
         the number of lines of tScript && "lines," && tBytes && "bytes, SHA-256" && tHex & return & \
         "It replaces the script there now (" & the number of lines of tOld && "lines). Its handlers answer messages as soon as it is set, " & \
         "and can do anything " & mcbHostName() & " can: allow it only if you know the file." into tProse
   put tProse into tParts["prose"]
   if mcbShowsLongCode() then
      put kMaxAskLongChars into tMax
   else
      put kFileAskChars into tMax
   end if
   put mcbBeginning(tScript, tMax) into tParts["code"]
   put tProse & return & return & mcbBeginning(tScript, kFileAskChars) into tDetail
   if not mcbAllow(tTitle, tDetail, "Set Script", tParts) then
      return mcbResult("Nothing was changed: the user did not allow the script to be set from the file. Ask them what they would like instead.", true)
   end if

   if word 1 of the name of tObject is "stack" then
      put mcbJsonString("stack") into tId
   else
      put the short id of tObject into tId
   end if
   -- The batch is parsed with no script, and the script put into it after:
   -- megabytes of script are not written as JSON and read back
   put "{" & mcbJsonString("stack") & ":" & mcbJsonString(mcbArg(pArguments, "stack")) & "," & \
         mcbJsonString("changes") & ":[{" & mcbJsonString("action") & ":" & mcbJsonString("set") & "," & \
         mcbJsonString("object") & ":" & tId & "," & mcbJsonString("script") & ":" & mcbJsonString("-") & "}]}" into tBatch
   put xtaJsonParse(tBatch) into tBatch
   put tScript into tBatch["members"]["changes"]["items"][1]["members"]["script"]["value"]
   put xtaBuildPlan(tBatch, mcbWorkStack(), true) into tPlan
   if tPlan["ok"] is not true then
      return mcbResult("Nothing was changed: the file's text does not compile as a script (the lines are the file's):" & return & tPlan["problems"], true)
   end if
   put xtaBuildApply(tPlan) into tApplied
   if tApplied["ok"] is not true then
      return mcbResult(tApplied["error"], true)
   end if
   put "Set the script of" && tWhere && "from" && tFile && "(" & the number of lines of tScript && "lines, SHA-256" && tHex & ")." into tText
   if tNamed is not empty then
      put return & "Its first line (" & tNamed & ") names a script-only stack and is not code: it was left empty, so the lines keep the file's numbers." after tText
   end if
   put return & "Nothing ran. A handler such as openStack runs when the stack is next opened, or when you call it with run_code." after tText
   put return & "This is change" && tApplied["entry"] & "; undo_changes takes it back." after tText
   return mcbResult(tText, false)
end mcbToolSetScriptFromFile

-- The first pMax characters of pText, saying how many more there are
private function mcbBeginning pText, pMax
   if the number of chars of pText <= pMax then
      return pText
   end if
   return char 1 to pMax of pText & return & "... (" & the number of chars of pText - pMax && "more characters, not shown here: the file has them)"
end mcbBeginning

-- wait_until: waits until a stack, card or control is there (or gone), or
-- until a property of it contains, lacks or is a text, and says which
-- happened. For what goes on by itself after a call ended: a test run
-- started from openStack that fills a report field. Before it, that was a
-- run_code again and again, each one a question for the user; this runs
-- no code of Claude's (the property is one word, read with the messages
-- locked, so that no getProp handler runs either), so it is not asked
-- about. The stack's own messages and timers go on while it waits (wait
-- with messages). It waits kWaitUntilMax seconds at most: Claude's app
-- gives up on a call after about a minute, and calls again to wait longer.
private function mcbToolWaitUntil pArguments
   local tName, tModes, tMode, tNeedle, tProperty, tTimeout, tStart, tEnd, tLook, tSeconds, tText, tType
   repeat for each item tName in "contains,lacks,equals,exists"
      put xtaJsonType(xtaJsonMember(pArguments, tName)) into tType
      if tType is not "missing" and tType is not "null" then
         put tName & comma after tModes
      end if
   end repeat
   delete the last char of tModes
   if the number of items of tModes is not 1 then
      return mcbResult("Give one of contains, lacks or equals (a text the property is compared with) or exists (true or false), and only one.", true)
   end if
   put tModes into tMode
   put xtaJsonText(xtaJsonMember(pArguments, tMode)) into tNeedle
   if tMode is "exists" then
      if tNeedle is not true and tNeedle is not false then
         return mcbResult("exists is true (wait until it is there) or false (wait until it is gone).", true)
      end if
   else if tMode is not "equals" and tNeedle is empty then
      return mcbResult("Give the text to look for in" && tMode & ".", true)
   end if
   put word 1 to -1 of mcbArg(pArguments, "property") into tProperty
   if tProperty is not empty and not matchText(tProperty, "^[A-Za-z][A-Za-z0-9_]*$") then
      return mcbResult("A property is one word (text, label, hilite, visible, or a custom property's name), not" && quote & tProperty & quote & ".", true)
   end if
   put mcbArg(pArguments, "timeout_seconds") into tTimeout
   if tTimeout is empty then
      put kWaitUntilDefault into tTimeout
   end if
   if tTimeout is not a number or tTimeout < 0 then
      return mcbResult("timeout_seconds is a number of seconds, at most" && kWaitUntilMax & ".", true)
   end if
   put min(tTimeout, kWaitUntilMax) into tTimeout
   put the milliseconds into tStart
   put tStart + tTimeout * 1000 into tEnd
   repeat
      put mcbWaitLook(mcbArg(pArguments, "stack"), mcbArg(pArguments, "id"), tMode, tNeedle, tProperty) into tLook
      if tLook["problem"] is not empty then
         return mcbResult(tLook["problem"], true)
      end if
      if tLook["so"] is true or the milliseconds >= tEnd then
         exit repeat
      end if
      wait kWaitUntilLook milliseconds with messages
   end repeat
   put (the milliseconds - tStart) div 1000 into tSeconds
   if tLook["so"] is true then
      put "It is so, after" && tSeconds && "seconds:" && tLook["what"] & "." into tText
   else
      put "Not yet, after" && tSeconds && "seconds:" && tLook["what"] & "." into tText
      if tLook["missing"] is not empty then
         put space & tLook["missing"] after tText
      end if
      put " Call wait_until again to keep waiting." after tText
   end if
   if tLook["read"] is true then
      if the number of chars of tLook["value"] > kWaitValueChars then
         put return & "It ends:" & return & "..." & char -kWaitValueChars to -1 of tLook["value"] after tText
      else if tLook["value"] is empty then
         put return & "It is empty." after tText
      else
         put return & "It is:" & return & tLook["value"] after tText
      end if
   end if
   return mcbResult(tText, false)
end mcbToolWaitUntil

-- One look for wait_until: an array with "so" (true when it is as asked),
-- "what" (what was asked, or how it is, in words), "read" and "value" (the
-- property, when one was read), "missing" (why nothing could be read yet: a
-- stack not open, an id not there, which a wait may still bring), or
-- "problem" (what no wait mends)
private function mcbWaitLook pStackName, pId, pMode, pNeedle, pProperty
   local tLook, tTarget, tStack, tObject, tValue, tError, tProperty, tOldLock, tNamed, tSo
   put false into tLook["so"]
   put word 1 to -1 of pId into pId
   if pId is "stack" then
      put empty into pId
   end if
   if pId is not empty and pId is not an integer then
      put "An id is a whole number, as read_stack gives it (none for the stack itself)." into tLook["problem"]
      return tLook
   end if
   put mcbTarget(pStackName) into tTarget
   if tTarget["problem"] is not empty then
      put tTarget["problem"] into tLook["missing"]
      if word 1 to -1 of pStackName is empty then
         put "the stack the user works on" into tNamed
      else
         put "the stack" && quote & word 1 to -1 of pStackName & quote into tNamed
      end if
   else
      put tTarget["stack"] into tStack
      if pId is empty then
         put tStack into tObject
      else if there is a card id pId of tStack then
         put the long id of card id pId of tStack into tObject
      else if there is a control id pId of tStack then
         put the long id of control id pId of tStack into tObject
      else
         put "The stack" && quote & the short name of tStack & quote && "has no card or control with the id" && pId & "." into tLook["missing"]
         put "the card or control with the id" && pId && "of stack" && quote & the short name of tStack & quote into tNamed
      end if
      if tObject is not empty then
         put mcbObjectLabel(tObject) into tNamed
         if pId is not empty then
            put " of stack" && quote & the short name of tStack & quote after tNamed
         end if
      end if
   end if
   if pMode is "exists" then
      put ((tObject is not empty) is (pNeedle is true)) into tLook["so"]
      if tObject is not empty then
         put tNamed && "is there" into tLook["what"]
         put empty into tLook["missing"]
      else
         put tNamed && "is not there" into tLook["what"]
      end if
      return tLook
   end if
   put pProperty into tProperty
   if tProperty is empty then
      put "text" into tProperty
      if tObject is not empty then
         if word 1 of the name of tObject is "button" or word 2 of the name of tObject is "button" then
            put "label" into tProperty
         end if
      end if
   end if
   if tObject is empty then
      put "the" && tProperty && "of" && tNamed && "cannot be read yet" into tLook["what"]
      return tLook
   end if
   -- The property, by its name: a custom property's getProp handler does
   -- not run (the messages are locked), and neither does anything else
   put the lockMessages into tOldLock
   lock messages
   try
      do "put the" && tProperty && "of tObject into tValue"
      -- A button with no label shows its name
      if pProperty is empty and tProperty is "label" and tValue is empty then
         put the short name of tObject into tValue
      end if
   catch tError
      set the lockMessages to tOldLock
      put "The" && tProperty && "of" && tNamed && "cannot be read (it has no such property, or its stack is password-protected)." into tLook["problem"]
      return tLook
   end try
   set the lockMessages to tOldLock
   put true into tLook["read"]
   put tValue into tLook["value"]
   set the caseSensitive to false
   switch pMode
      case "contains"
         put (pNeedle is in tValue) into tSo
         if tSo then
            put "the" && tProperty && "of" && tNamed && "contains" && quote & pNeedle & quote into tLook["what"]
         else
            put "the" && tProperty && "of" && tNamed && "does not contain" && quote & pNeedle & quote into tLook["what"]
         end if
         break
      case "lacks"
         put (pNeedle is not in tValue) into tSo
         if tSo then
            put "the" && tProperty && "of" && tNamed && "does not contain" && quote & pNeedle & quote into tLook["what"]
         else
            put "the" && tProperty && "of" && tNamed && "still contains" && quote & pNeedle & quote into tLook["what"]
         end if
         break
      default
         -- As text, not as numbers, and but for the spaces and empty
         -- lines around it
         put (("t" & word 1 to -1 of tValue) is ("t" & word 1 to -1 of pNeedle)) into tSo
         if tSo then
            put "the" && tProperty && "of" && tNamed && "is" && quote & pNeedle & quote into tLook["what"]
         else
            put "the" && tProperty && "of" && tNamed && "is not" && quote & pNeedle & quote into tLook["what"]
         end if
   end switch
   put tSo into tLook["so"]
   return tLook
end mcbWaitLook

-- set_quiet: the engine's sounds off (the playLoudness 0, and the
-- beepLoudness where the engine has one) and back to what they were, for
-- sweeps and test runs of stacks that play sounds. It is the engine's own
-- loudness that is set, never the system's mixer by another road: on
-- Windows the playLoudness is this application's, on a Mac and on Linux it
-- is the computer's or the sound device's (the tool's description says
-- so). What it was is kept here and in a note beside the bridge's file, so
-- that an IDE that quit or crashed while quiet puts it back when its
-- bridge next starts (mcbQuietRecover): Windows remembers an
-- application's loudness from one launch to the next. Turning the bridge
-- off puts it back too (mcbStopParts). Not asked about: it runs nothing
-- and changes nothing of the user's work.
private function mcbToolSetQuiet pQuiet
   local tText
   if pQuiet is true then
      if sQuiet is an array then
         return mcbResult("The engine's sounds are already off. set_quiet with quiet false puts them back.", false)
      end if
      mcbQuietOn
      put "The engine's sounds are off: the playLoudness is 0 (it was" && sQuiet["play"] & "). set_quiet with quiet false puts it back, " & \
            "and so does turning the bridge off." into tText
      switch the platform
         case "MacOS"
            put return & "On a Mac the playLoudness is the computer's own volume: everything on it is silent until then, so tell the user. A beep may still sound." after tText
            break
         case "Linux"
            put return & "On Linux the playLoudness is the sound device's volume, which other programs share: tell the user." after tText
            break
         case "Win32"
            put return & "A beep, which is a sound of Windows, still sounds." after tText
            break
      end switch
      return mcbResult(tText, false)
   end if
   if pQuiet is not false then
      return mcbResult("quiet is true (the engine's sounds off) or false (back to what they were).", true)
   end if
   if sQuiet is not an array then
      return mcbResult("The bridge had not turned the engine's sounds off: the playLoudness is" && the playLoudness & ".", false)
   end if
   mcbQuietOff
   return mcbResult("The engine's sounds are back: the playLoudness is" && the playLoudness & ".", false)
end mcbToolSetQuiet

private command mcbQuietOn
   local tWas, tError
   put the playLoudness into tWas["play"]
   try
      put the beepLoudness into tWas["beep"]
   catch tError
      put empty into tWas["beep"]
   end try
   mcbQuietNote tWas
   set the playLoudness to 0
   if tWas["beep"] is an integer then
      try
         set the beepLoudness to 0
      catch tError
      end try
   end if
   put tWas into sQuiet
end mcbQuietOn

-- Puts the loudness back to what it was before set_quiet, where it is
-- still 0: the user may have set it since, and that stays
private command mcbQuietOff
   local tWas
   if sQuiet is not an array then
      exit mcbQuietOff
   end if
   put sQuiet into tWas
   put empty into sQuiet
   mcbQuietRestore tWas
   mcbQuietNote empty
end mcbQuietOff

private command mcbQuietRestore pWas
   local tError
   try
      if pWas["play"] is an integer and pWas["play"] > 0 and the playLoudness is 0 then
         set the playLoudness to pWas["play"]
      end if
      if pWas["beep"] is an integer and pWas["beep"] > 0 and the beepLoudness is 0 then
         set the beepLoudness to pWas["beep"]
      end if
   catch tError
   end try
end mcbQuietRestore

-- The note of what the loudness was, beside the bridge's file (none for
-- the web IDE's link, whose files are the browser's): written while quiet,
-- deleted when it is put back
private function mcbQuietNotePath
   local tFile
   if sInfoFile is empty then
      return empty
   end if
   put sInfoFile into tFile
   set the itemDelimiter to slash
   return item 1 to -2 of tFile & slash & kQuietFile
end mcbQuietNotePath

private command mcbQuietNote pWas
   local tFile, tError
   put mcbQuietNotePath() into tFile
   if tFile is empty then
      exit mcbQuietNote
   end if
   try
      if pWas is an array then
         put textEncode("play=" & pWas["play"] & numToChar(10) & "beep=" & pWas["beep"] & numToChar(10), "UTF-8") into url ("binfile:" & tFile)
      else if there is a file tFile then
         delete file tFile
      end if
   catch tError
   end try
end mcbQuietNote

-- An IDE that quit or crashed while quiet left its note: the loudness is
-- put back as the bridge starts
private command mcbQuietRecover
   local tFile, tText, tLine, tWas, tError
   put mcbQuietNotePath() into tFile
   if tFile is empty or there is not a file tFile then
      exit mcbQuietRecover
   end if
   try
      put textDecode(url ("binfile:" & tFile), "UTF-8") into tText
      set the itemDelimiter to "="
      repeat for each line tLine in tText
         if item 1 of tLine is "play" or item 1 of tLine is "beep" then
            put item 2 of tLine into tWas[item 1 of tLine]
         end if
      end repeat
      mcbQuietRestore tWas
      delete file tFile
   catch tError
   end try
end mcbQuietRecover

-- restart_ide: quits this IDE and starts it again, for a run that needs a
-- fresh engine or an IDE that misbehaves. The asker says how this IDE is
-- started (mcbRestartCommand: OXT-Beyond's main stack knows its own
-- application; with no such function, or none it can give, this refuses)
-- and quits it as the user's Quit does (mcbQuitForRestart), which asks
-- about stacks not saved and can be cancelled. Between the two, a small
-- script of the system's shell (mcbRelaunchScript) is left running: it
-- waits until this process has gone, then starts the IDE, and gives up
-- when the IDE is still there after kRestartWaitSeconds (the user
-- cancelled the quit). Asked about unless the user chose not to be
-- (mcbAllow): a run of code can quit the IDE already.
private function mcbToolRestart
   local tStart, tDetail, tScript, tFile, tOldHide, tProblem, tError, tCommand
   if sLink is true then
      return mcbResult("The web IDE cannot be restarted from here: ask the user to reload its page.", true)
   end if
   put mcbRestartCommand() into tStart
   if tStart is empty then
      return mcbResult(mcbHostName() & " cannot be restarted from here. Ask the user to quit it and start it again.", true)
   end if
   put mcbHostName() & " would quit and start again. It asks you first about stacks with changes you have not saved, as Quit does. " & \
         "The stacks open now are not opened again." into tDetail
   if not mcbAllow("Claude asks to restart " & mcbHostName() & ".", tDetail, "Restart") then
      return mcbResult("Nothing was done: the user did not allow the restart.", true)
   end if
   put mcbRelaunchScript(the platform, tStart, the processID, kRestartWaitSeconds) into tScript
   put specialFolderPath("temporary") & "/oxt-beyond-restart-" & the processID into tFile
   if the platform is "Win32" then
      put ".cmd" after tFile
      put tFile into tCommand
      replace slash with backslash in tCommand
      put "cmd.exe /c" && quote & tCommand & quote into tCommand
   else
      put ".sh" after tFile
      put "/bin/sh" && quote & tFile & quote into tCommand
   end if
   put textEncode(tScript, "UTF-8") into url ("binfile:" & tFile)
   if the result is not empty then
      return mcbResult("Nothing was done: the script that starts " & mcbHostName() & " again could not be written (" & the result & ").", true)
   end if
   -- No window for it, and no pipe to it: the engine ends, as it quits,
   -- the processes it reads from or writes to, and leaves this one
   put the hideConsoleWindows into tOldHide
   set the hideConsoleWindows to true
   try
      open process tCommand for neither
      put the result into tProblem
   catch tError
      put line 1 of tError into tProblem
   end try
   set the hideConsoleWindows to tOldHide
   if tProblem is not empty then
      delete file tFile
      return mcbResult("Nothing was done: the script that starts " & mcbHostName() & " again could not be started (" & tProblem & ").", true)
   end if
   -- After this call's answer has gone to the server
   send "mcbQuitForRestart" to sAsker in 600 milliseconds
   return mcbResult(mcbHostName() & " is quitting, and starts again once it has quit. If the user cancels the quit (for a stack not saved), " & \
         "it stays open as it is and is not started again.", false)
end mcbToolRestart

-- How the asker starts its IDE, a line of the system's shell, or empty
private function mcbRestartCommand
   local tStart, tError
   if sAsker is empty or there is not a sAsker then
      return empty
   end if
   try
      dispatch function "mcbRestartCommand" to sAsker
      if it is "handled" then
         put the result into tStart
      end if
   catch tError
      put empty into tStart
   end try
   return line 1 of tStart
end mcbRestartCommand

-- The script that waits for the process pPid to end and then runs pStart
-- (a line of that shell which starts the IDE and does not wait for it),
-- for pPlatform: a .cmd file's text on "Win32" (with its line ends), a sh
-- script's elsewhere. It looks once a second, pWait times at most, and
-- starts nothing when the process is still there then. It deletes its own
-- file. On Windows the process is looked for with tasklist, whose CSV
-- form has the id between quotes, and a second is a ping of this computer
-- (timeout needs a console's input, which this has not). On Unix a
-- process that ended and that its parent has not asked about (a zombie)
-- still answers kill -0, so ps is asked too.
function mcbRelaunchScript pPlatform, pStart, pPid, pWait
   local tScript
   if pPlatform is "Win32" then
      put "@echo off" & return & \
            "chcp 65001 >nul" & return & \
            "set /a n=0" & return & \
            ":wait" & return & \
            "tasklist /FI " & quote & "PID eq" && pPid & quote & " /FO CSV /NH 2>nul | find " & quote & quote & quote & pPid & quote & quote & quote & " >nul" & return & \
            "if errorlevel 1 goto gone" & return & \
            "set /a n+=1" & return & \
            "if %n% GEQ" && pWait && "goto done" & return & \
            "ping -n 2 127.0.0.1 >nul" & return & \
            "goto wait" & return & \
            ":gone" & return & \
            pStart & return & \
            ":done" & return & \
            "del " & quote & "%~f0" & quote & " & exit" & return into tScript
      replace return with crlf in tScript
      return tScript
   end if
   put "#!/bin/sh" & return & \
         "there() {" & return & \
         "   kill -0" && pPid && "2>/dev/null || return 1" & return & \
         "   case " & quote & "$(ps -o stat= -p" && pPid && "2>/dev/null)" & quote & " in *Z*) return 1 ;; esac" & return & \
         "   return 0" & return & \
         "}" & return & \
         "n=0" & return & \
         "while there; do" & return & \
         "   n=$((n + 1))" & return & \
         "   if [ " & quote & "$n" & quote & " -ge" && pWait && "]; then" & return & \
         "      rm -f " & quote & "$0" & quote & return & \
         "      exit 0" & return & \
         "   fi" & return & \
         "   sleep 1" & return & \
         "done" & return & \
         "rm -f " & quote & "$0" & quote & return & \
         pStart & return into tScript
   return tScript
end mcbRelaunchScript

--------------------------------------------------------------------------------
-- What holds the IDE up
--
-- A call can wait without the bridge being able to say why: for the user
-- to answer the IDE's question before a run (whose window may be behind
-- others), for a script paused in the debugger, or for a dialog a stack
-- opened (answer, ask, a modal stack of its own). The engine still reads
-- the sockets while it waits, so a status (the method, which the MCP
-- server asks over a connection of its own while a call takes long) and a
-- call refused as busy say which; stop_paused_script and answer_dialog end
-- the last two, and answer while another call waits (kUnblockingTools).

-- What the bridge is doing and what holds it up, as text for Claude
private function mcbStatusText
   local tText, tBlockers
   if sWaiting is not empty then
      put mcbHostName() & " is waiting for the user to answer its question" && quote & sWaiting & quote && \
            "(asked" && the seconds - sWaitingSince && "seconds ago). Its window may be behind other windows: " & \
            "ask the user to look for it in " & mcbHostName() & " and answer it." into tText
   else if sBusy is true then
      put mcbHostName() & " is carrying out" && sBusyTool && "(for" && the seconds - sBusySince && "seconds)." into tText
   else
      put mcbHostName() & " is not busy with a call of the bridge." into tText
   end if
   put mcbBlockersText() into tBlockers
   if tBlockers is not empty then
      put return & tBlockers after tText
   end if
   return tText
end mcbStatusText

-- A script paused in the debugger and the dialog open, a line each, or
-- empty
private function mcbBlockersText
   local tText, tPaused, tDialog
   put mcbPausedText() into tPaused
   if tPaused is not empty then
      put tPaused && "While it is paused, the code it runs waits: the user presses Run or Stop in the Script Editor, " & \
            "or stop_paused_script stops it." & return after tText
   end if
   put mcbFrontDialog() into tDialog
   if tDialog is not empty then
      put mcbDialogText(tDialog) & return after tText
   end if
   if tText is not empty then
      delete the last char of tText
   end if
   return tText
end mcbBlockersText

-- Where a script of the user's is paused in the debugger, as a sentence,
-- or empty when none is
private function mcbPausedText
   local tState, tError
   try
      put xtaDebugState() into tState
   catch tError
      return empty
   end try
   if tState["paused"] is not true then
      return empty
   end if
   return "A script of the user's is paused in the debugger, at line" && tState["line"] && "of the handler" && tState["handler"] && \
         "in" && mcbLabelOf(tState["object"]) & "."
end mcbPausedText

-- mcbObjectLabel of an object that may be gone (then its reference as it
-- was given)
private function mcbLabelOf pObject
   local tError
   try
      if pObject is not empty and there is a pObject then
         return mcbObjectLabel(the long id of pObject)
      end if
   catch tError
   end try
   return pObject
end mcbLabelOf

-- The dialog in front, or empty: an array with "stack" (its long id),
-- "mine" (true when it is the bridge's own question to the user), "user"
-- (true when a script of the user's opened it: the only kind answer_dialog
-- answers) and "caller" (that handler and its object, when known). A
-- dialog is a stack open as modal or as a sheet, the first the openStacks
-- lists, which is the one in front. The file dialogs of the system (answer
-- file, and the engine's "Where is ...?") are not stacks, and while one is
-- open the engine reads no socket: no call is answered then at all.
private function mcbFrontDialog
   local tName, tStack, tDialog, tCaller
   repeat for each line tName in the openStacks
      if there is not a stack tName then
         next repeat
      end if
      put the long id of stack tName into tStack
      if the mode of tStack is among the items of "5,6" and the visible of tStack then
         put tStack into tDialog["stack"]
         exit repeat
      end if
   end repeat
   if tDialog["stack"] is empty then
      return empty
   end if
   put (sWaiting is not empty) into tDialog["mine"]
   put mcbDialogCaller() into tCaller
   put tCaller["label"] into tDialog["caller"]
   -- Opened by a script of the user's: the handler that called it is
   -- theirs, and the dialog is theirs too, or the IDE's answer or ask
   put false into tDialog["user"]
   if not tDialog["mine"] and tCaller["user"] is true then
      if not mcbIsIDEStack(tDialog["stack"]) or the short name of tDialog["stack"] is among the items of kAnswerDialogs then
         put true into tDialog["user"]
      end if
   end if
   return tDialog
end mcbFrontDialog

-- The handler that opened the dialog in front: the one that ran when the
-- engine began the wait that this call came in through, which is just
-- before this call's first handler in the executionContexts (oldest
-- first): mcbLineRead for a socket, the plugin's mcbWebPoll for the web
-- IDE's link. An array with "label" and "user" (true when its object is
-- the user's), or empty when the call did not come in through a wait.
private function mcbDialogCaller
   local tContexts, tIndex, tEntry, tContext, tResult, tError
   put the executionContexts into tContexts
   put 0 into tEntry
   repeat with tIndex = the number of lines of tContexts down to 2
      put mcbParseContext(line tIndex of tContexts) into tContext
      if tContext["handler"] is among the items of "mcbLineRead,mcbWebPoll" then
         put tIndex into tEntry
         exit repeat
      end if
   end repeat
   if tEntry < 2 then
      return empty
   end if
   put mcbParseContext(line tEntry - 1 of tContexts) into tContext
   put false into tResult["user"]
   try
      if tContext["object"] is not empty and there is a tContext["object"] then
         put tContext["handler"] && "in" && mcbObjectLabel(the long id of tContext["object"]) into tResult["label"]
         put not mcbIsIDEStack(mcbStackOfObject(the long id of tContext["object"])) into tResult["user"]
      end if
   catch tError
      put false into tResult["user"]
   end try
   return tResult
end mcbDialogCaller

-- One line of the executionContexts: "object" (which may have commas in
-- it), "handler" and "line", the line being the first item after the
-- second that is a whole number, as the IDE's debugger reads it
private function mcbParseContext pLine
   local tContext, tIndex, tItem
   put 0 into tIndex
   repeat for each item tItem in pLine
      add 1 to tIndex
      if tIndex > 2 and tItem is an integer then
         put item 1 to tIndex - 2 of pLine into tContext["object"]
         put item tIndex - 1 of pLine into tContext["handler"]
         put tItem into tContext["line"]
         exit repeat
      end if
   end repeat
   return tContext
end mcbParseContext

-- The dialog as a sentence for Claude: its title, its text, its buttons,
-- who opened it, and whether answer_dialog can answer it
private function mcbDialogText pDialog
   local tStack, tText, tFields, tButtons, tTitle
   put pDialog["stack"] into tStack
   if pDialog["mine"] then
      return "The dialog in front is " & mcbHostName() & "'s own question to the user, which only they answer."
   end if
   put the title of tStack into tTitle
   if word 1 to -1 of tTitle is empty then
      put the short name of tStack into tTitle
   end if
   put "A dialog is open in front of the user, titled" && quote & word 1 to -1 of tTitle & quote into tText
   if pDialog["caller"] is not empty then
      put ", opened by" && pDialog["caller"] after tText
   end if
   put "." after tText
   mcbDialogParts tStack, tFields, tButtons
   if tFields is not empty then
      put " It says:" && quote & tFields & quote & "." after tText
   end if
   if tButtons is not empty then
      put " Its buttons:" && tButtons & "." after tText
   end if
   if pDialog["user"] then
      put " Everything else waits until it is answered: the user answers it, or answer_dialog presses one of its buttons." after tText
   else
      put " It is the IDE's own, or it is not known what opened it: everything else waits until the user answers it." after tText
   end if
   return tText
end mcbDialogText

-- The text a dialog shows (its visible fields, joined, cut to
-- kDialogTextChars) and its buttons (each label in quotes, comma
-- separated): those visible and on its card. The IDE's answer dialog
-- keeps the buttons it does not use, moved off the card.
private command mcbDialogParts pStack, @rFields, @rButtons
   local tCard, tIndex, tControl, tLabel, tRect
   put empty into rFields
   put empty into rButtons
   put the long id of this card of pStack into tCard
   put the rect of tCard into tRect
   repeat with tIndex = 1 to the number of controls of tCard
      put the long id of control tIndex of tCard into tControl
      if not the visible of tControl or not mcbOnCard(tControl, tRect) then
         next repeat
      end if
      if word 1 of the name of tControl is "field" then
         if word 1 to -1 of the text of tControl is not empty then
            if rFields is not empty then
               put " / " after rFields
            end if
            put word 1 to -1 of the text of tControl after rFields
         end if
      else if word 1 of the name of tControl is "button" and the showName of tControl then
         put mcbButtonLabel(tControl) into tLabel
         if tLabel is not empty then
            put quote & tLabel & quote & ", " after rButtons
         end if
      end if
   end repeat
   replace return with " " in rFields
   if the number of chars of rFields > kDialogTextChars then
      put char 1 to kDialogTextChars of rFields & "..." into rFields
   end if
   if rButtons is not empty then
      delete char -2 to -1 of rButtons
   end if
end mcbDialogParts

private function mcbOnCard pControl, pRect
   return item 3 of the rect of pControl > item 1 of pRect and item 1 of the rect of pControl < item 3 of pRect \
         and item 4 of the rect of pControl > item 2 of pRect and item 2 of the rect of pControl < item 4 of pRect
end mcbOnCard

private function mcbButtonLabel pButton
   if the label of pButton is not empty then
      return the label of pButton
   end if
   return the short name of pButton
end mcbButtonLabel

-- Stops the script paused in the debugger, as Stop in the Script Editor
-- does: the IDE's (the asker's mcbStopDebugger), else the debugger
-- library's own revDebuggerStop
private function mcbToolStopPaused
   local tWhere, tDone, tError
   put mcbPausedText() into tWhere
   if tWhere is empty then
      return mcbResult("No script of the user's is paused in the debugger: there is nothing to stop.", false)
   end if
   put false into tDone
   if sAsker is not empty and there is a sAsker then
      try
         dispatch function "mcbStopDebugger" to sAsker
         put (it is "handled" and the result is true) into tDone
      catch tError
         put false into tDone
      end try
   end if
   if not tDone then
      try
         revDebuggerStop
         put true into tDone
      catch tError
         put false into tDone
      end try
   end if
   if not tDone then
      return mcbResult("The paused script could not be stopped here. Ask the user to press Stop in the Script Editor.", true)
   end if
   return mcbResult(tWhere && "It is stopped, as Stop in the Script Editor stops it: the rest of that handler, and of the handlers that called it, " & \
         "does not run. What it did before the line it was paused at stays done.", false)
end mcbToolStopPaused

-- Presses a button of the dialog in front, when a script of the user's
-- opened it (mcbFrontDialog): button, its label as the status gives it;
-- text, for an ask dialog, what is typed into its field first. Never the
-- bridge's own question, nor a dialog of the IDE's.
private function mcbToolAnswerDialog pArguments
   local tDialog, tWanted, tText, tCard, tIndex, tControl, tButton, tField, tRect, tFields, tButtons
   put mcbFrontDialog() into tDialog
   if tDialog is empty then
      return mcbResult("No dialog is open in " & mcbHostName() & ". (The system's file dialogs, and the engine's " & quote & "Where is" & quote & \
            " dialog, cannot be seen here: while one is open, no call is answered at all.)", true)
   end if
   if not tDialog["user"] then
      return mcbResult("Nothing was pressed:" && mcbDialogText(tDialog), true)
   end if
   put word 1 to -1 of mcbArg(pArguments, "button") into tWanted
   mcbDialogParts tDialog["stack"], tFields, tButtons
   put the long id of this card of tDialog["stack"] into tCard
   put the rect of tCard into tRect
   repeat with tIndex = 1 to the number of controls of tCard
      put the long id of control tIndex of tCard into tControl
      if not the visible of tControl or not mcbOnCard(tControl, tRect) then
         next repeat
      end if
      if word 1 of the name of tControl is "button" and the showName of tControl and tButton is empty then
         if mcbButtonLabel(tControl) is tWanted then
            put tControl into tButton
         end if
      else if word 1 of the name of tControl is "field" and not the lockText of tControl and tField is empty then
         put tControl into tField
      end if
   end repeat
   if tButton is empty then
      return mcbResult("Nothing was pressed: the dialog has no button" && quote & tWanted & quote & ". Its buttons:" && tButtons & ".", true)
   end if
   if xtaJsonType(xtaJsonMember(pArguments, "text")) is "string" then
      if tField is empty then
         return mcbResult("Nothing was pressed: the dialog has no field to type text into.", true)
      end if
      put mcbArg(pArguments, "text") into tText
      set the text of tField to tText
   end if
   -- As a click does: the IDE's answer and ask dialogs take mouseUp, on
   -- the button or on their card, and close
   send "mouseUp" to tButton
   return mcbResult("Pressed" && quote & tWanted & quote && "in the dialog" && quote & word 1 to -1 of the title of tDialog["stack"] & quote & \
         ". The script that opened it goes on once this call has been answered.", false)
end mcbToolAnswerDialog

--------------------------------------------------------------------------------
-- HyperCard

-- Lists the stacks on a Mac disk image (list), or imports a HyperCard
-- stack, from its file or from a disk image (file and stack_path), as File
-- > Import Stack does: with messages locked, so that none of its scripts
-- runs. The stack is open in the IDE afterwards, not saved. The summary of
-- the import is the IDE's (revHyperCardImportSummary).
private function mcbToolImportHyperCard pArguments
   local tFile, tStackPath, tList, tError, tLine, tFound, tBefore, tName, tStack, tSummary, tText, tIsImage, tDone, tProblem
   put mcbArg(pArguments, "file") into tFile
   if the platform is "Win32" then
      replace backslash with slash in tFile
   end if
   if word 1 to -1 of tFile is empty then
      return mcbResult("Give the file: a HyperCard stack (or a MacBinary or BinHex copy of one), or a Mac disk image of stacks.", true)
   end if
   if there is not a file tFile then
      return mcbResult("There is no file" && tFile & ".", true)
   end if
   put mcbStackPathArg(pArguments) into tStackPath
   try
      put revHyperCardIsDiskImage(tFile) into tIsImage
   catch tError
      return mcbResult("HyperCard stacks cannot be imported here: the IDE's HyperCard libraries are not loaded.", true)
   end try
   -- A disk image the library knows but does not read (an HFS+ volume, a
   -- compressed .dmg), which is not "not a disk image"
   if tIsImage is not true then
      try
         put revHyperCardImageProblem(tFile) into tProblem
      catch tError
      end try
   end if
   if tIsImage is true then
      put revHyperCardImageStacks(tFile) into tList
      put the result into tError
      if tError is not empty then
         return mcbResult("The disk image cannot be read:" && tError, true)
      end if
      if mcbArg(pArguments, "list") is "true" or tStackPath is empty then
         if tList is empty then
            return mcbResult("The disk image" && tFile && "holds no HyperCard stack.", false)
         end if
         put "The HyperCard stacks on the disk image" && tFile & ", as stack_path (data fork, resource fork, in bytes):" into tText
         set the itemDelimiter to tab
         repeat for each line tLine in tList
            put return & "-" && item 1 of tLine && "(" & item 2 of tLine & "," && item 3 of tLine & ")" after tText
         end repeat
         if mcbArg(pArguments, "list") is not "true" then
            put return & "Nothing was imported: give one of them as stack_path." after tText
         end if
         return mcbResult(tText, false)
      end if
      set the itemDelimiter to tab
      put false into tFound
      repeat for each line tLine in tList
         if item 1 of tLine is tStackPath then
            put true into tFound
            exit repeat
         end if
      end repeat
      if not tFound then
         return mcbResult("The disk image has no stack" && quote & tStackPath & quote & ". list: true lists them.", true)
      end if
   else if tProblem is not empty and not mcbIsHyperCardFile(tFile) then
      return mcbResult("The disk image cannot be read:" && tProblem, true)
   else if mcbArg(pArguments, "list") is "true" then
      return mcbResult(tFile && "is not a Mac disk image (an HFS volume): import it as a stack, without list.", true)
   else if not mcbIsHyperCardFile(tFile) then
      return mcbResult(tFile && "is not a HyperCard stack, or a MacBinary or BinHex copy of one, or a Mac disk image.", true)
   end if
   -- The stack the import opens is the main stack that was not there
   repeat for each line tName in the mainStacks
      if there is a stack tName then
         put true into tBefore[the long id of stack tName]
      end if
   end repeat
   try
      if tIsImage is true then
         revIDEImportHyperCardFromDiskImage tFile, tStackPath
      else
         revIDEImportHyperCardStack tFile
      end if
      put the result into tError
   catch tError
      put "the import failed:" && line 1 of tError into tError
   end try
   repeat for each line tName in the mainStacks
      if there is a stack tName then
         if tBefore[the long id of stack tName] is not true then
            put the long id of stack tName into tStack
            exit repeat
         end if
      end if
   end repeat
   if tStack is empty then
      if tError is empty then
         put "no new stack opened (a stack of that name may be open already)" into tError
      end if
      return mcbResult("Nothing was imported:" && tError, true)
   end if
   try
      put revHyperCardImportSummary(tStack, the hcImportStat) into tSummary
   catch tError
      put empty into tSummary
   end try
   put "Imported" && quote & the short name of tStack & quote && "from" && tFile into tText
   if tIsImage is true then
      put "," && tStackPath after tText
   end if
   put ", with messages locked (none of its scripts ran). It is open in " & mcbHostName() & ", not saved: save_stack saves it where the user chooses." after tText
   if tSummary is not empty then
      put return & return & "The import's summary:" & return & tSummary after tText
   end if
   return mcbResult(tText, false)
end mcbToolImportHyperCard

private function mcbStackPathArg pArguments
   return word 1 to -1 of mcbArg(pArguments, "stack_path")
end mcbStackPathArg

-- True when the file begins as a HyperCard stack does, or a MacBinary,
-- AppleSingle or BinHex copy of one, as the IDE's import tells
private function mcbIsHyperCardFile pFile
   local tHeader
   open file pFile for binary read
   if the result is not empty then
      return false
   end if
   read from file pFile for 256
   put it into tHeader
   close file pFile
   if byte 5 to 8 of tHeader is "STAK" then
      return true
   end if
   if byte 1 to 4 of tHeader is (numToByte(0) & numToByte(5) & numToByte(22) & numToByte(0)) then
      return true
   end if
   if byteToNum(byte 1 of tHeader) is 0 and byteToNum(byte 75 of tHeader) is 0 and byteToNum(byte 83 of tHeader) is 0 then
      return byte 66 to 69 of tHeader is "STAK"
   end if
   return "BinHex" is in tHeader
end mcbIsHyperCardFile

-- The IDE's name, where the user or the model reads it: "OXT-Beyond", or,
-- in a package of the plugin installed in another xTalk's IDE, the name
-- its compatibility stack gives (tools/plugins/plugin-compat.livecodescript.in)
private function mcbHostName
   local tStack, tName
   repeat for each item tStack in "org.openxtalk.plugin.xtalkassistant-compat,org.openxtalk.plugin.mcpbridge-compat"
      if there is a stack tStack then
         dispatch function "xtpcHostName" to stack tStack
         put the result into tName
         if it is "handled" and tName is not empty then
            return tName
         end if
      end if
   end repeat
   return "OXT-Beyond"
end mcbHostName
