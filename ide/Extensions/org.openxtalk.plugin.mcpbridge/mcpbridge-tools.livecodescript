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
-- It needs no IDE: the engine tests in tests/lcs/mcpbridge load it, the
-- assistant's core and build library, and a stand-in asker, the same way.
--
-- Public handlers:
--    mcbServerStart(pAssistantFolder, pAsker, pInfoFile)   the port, or throws
--    mcbServerStop                       closes the sockets, deletes the file
--    mcbServerPort(), mcbServerClients() while it runs
--    mcbInfoFilePath()                   where the MCP server looks for the file
--    mcbHandleLine(pLine)                one request, its answer (a line of JSON)
--    mcbCallTool(pTool, pArguments)      one tool, as an array ("text",
--                                        "error", "image", "imageType")
--    mcbToolNames()                      the tools, one per line
--    mcbUndoLast()                       the newest change still applied, undone
--    mcbDesktopConfigText(pOld, pName, pServerPath)  Claude desktop's
--                                        config with the bridge's entry added

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
-- The tools, in the order the MCP server lists them (mcp/server.js has
-- their descriptions and schemas)
constant kTools = "xtalk_guide,list_stacks,ide_context,read_stack,read_script,search_scripts,look_at_card,lookup_dictionary,check_code,make_changes,edit_script,run_code,save_stack,list_changes,undo_changes,debug_state"
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

-- The token a request must carry; empty while the server is not running,
-- when every request is refused
local sToken
-- The port listened on, the open client sockets (one per line), the file
-- the port and token are written to, the folder of the assistant's files,
-- and the object that asks the user (its mcbConfirm)
local sPort, sClients, sInfoFile, sAssistantFolder, sAsker
-- True when this loaded the assistant's libraries (and so unloads them)
local sLoadedCore, sLoadedBuild
-- True while a tool runs
local sBusy
-- The socket of the request being answered: a question to the user is
-- answered after the server gave up waiting (and closed it) only with
-- nothing done (mcbAsk)
local sRequestSocket
-- The Dictionary's entry names, read once (lookup_dictionary's suggestions)
local sDictionaryNames

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
   put false into sBusy
   mcbStopErrorHook
   put empty into sInfoFile
   put empty into sAsker
   -- The assistant's libraries go with the bridge unless the assistant is
   -- on: whichever loaded them, as a turned-off assistant leaves them, and
   -- its journal, to the bridge
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
end mcbServerStop

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
   put pSocket & return after sClients
   read from socket pSocket until numToChar(10) with message "mcbLineRead"
end mcbConnection

on mcbLineRead pSocket, pData
   local tReply, tError
   if pSocket is not among the lines of sClients then
      exit mcbLineRead
   end if
   if the number of bytes of pData > kMaxRequestBytes then
      mcbDropClient pSocket
      exit mcbLineRead
   end if
   put pSocket into sRequestSocket
   try
      put mcbHandleLine(textDecode(pData, "UTF-8")) into tReply
   catch tError
      put mcbRefusal("null", "The bridge failed:" && line 1 of tError) into tReply
   end try
   put empty into sRequestSocket
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
   local tRequest, tError, tId, tMethod, tArguments, tResult, tReply
   -- Stopped: nothing is read, and the assistant's libraries, which read
   -- JSON, may be gone
   if sToken is empty then
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
   if sToken is empty or xtaJsonType(xtaJsonMember(tRequest, "token")) is not "string" \
         or not mcbIsToken(xtaJsonText(xtaJsonMember(tRequest, "token"))) then
      return mcbRefusal(tId, "The token is not the bridge's. Turn the bridge off and on again in " & mcbHostName() & ", then try again.")
   end if
   put xtaJsonText(xtaJsonMember(tRequest, "method")) into tMethod
   if tMethod is "hello" then
      return "{" & mcbJsonString("id") & ":" & tId & "," & mcbJsonString("ok") & ":true," & \
            mcbJsonString("protocol") & ":" & kProtocol & "," & \
            mcbJsonString("engine") & ":" & mcbJsonString(the version) & "," & \
            mcbJsonString("tools") & ":" & mcbJsonString(kTools) & "}"
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
   -- One tool at a time: while one waits (for the user to answer a
   -- question here, or for a run), the engine still reads the sockets, and
   -- a second call, from another Claude app or after a reconnect, would
   -- start on the same journal
   if sBusy is true then
      return mcbRefusal(tId, mcbHostName() & " is still busy with an earlier request (it may be waiting for the user to answer a question in " & mcbHostName() & ", " & \
            "or running code). Try again once that is done.")
   end if
   put true into sBusy
   try
      put mcbCallTool(xtaJsonText(xtaJsonMember(tRequest, "tool")), tArguments) into tResult
   catch tError
      put false into sBusy
      throw tError
   end try
   put false into sBusy
   put "{" & mcbJsonString("id") & ":" & tId & "," & mcbJsonString("ok") & ":true," & \
         mcbJsonString("isError") & ":" & (tResult["error"] is true) & "," & \
         mcbJsonString("text") & ":" & mcbJsonString(tResult["text"]) into tReply
   if tResult["image"] is not empty then
      put "," & mcbJsonString("image") & ":" & mcbJsonString(tResult["image"]) & "," & \
            mcbJsonString("imageType") & ":" & mcbJsonString(tResult["imageType"]) after tReply
   end if
   return tReply & "}"
end mcbHandleLine

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
   local tResult, tError
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
            return mcbToolMakeChanges(pArguments)
         case "run_code"
            return mcbToolRunCode(pArguments)
         case "save_stack"
            return mcbToolSaveStack(mcbArg(pArguments, "stack"))
         case "list_changes"
            return mcbToolListChanges()
         case "undo_changes"
            return mcbToolUndo(mcbArg(pArguments, "entry"))
         case "debug_state"
            return mcbToolDebugState()
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

-- Asks the user (the plugin's dialog); true when they said yes. With no
-- asker (the bridge started without one), false.
private function mcbAsk pTitle, pDetail, pYes
   local tAnswer, tError
   if sAsker is empty or there is not a sAsker then
      return false
   end if
   if the number of chars of pDetail > kMaxAskChars then
      put char 1 to kMaxAskChars of pDetail & return & "... (" & the number of chars of pDetail - kMaxAskChars && \
            "more characters, not shown here)" into pDetail
   end if
   try
      dispatch function "mcbConfirm" to sAsker with pTitle, pDetail, pYes
      put the result into tAnswer
   catch tError
      put false into tAnswer
   end try
   -- The server gives up on a call after a while (server.js, 10 minutes)
   -- and closes the connection; Claude was told so and may send it again.
   -- A yes after that would run (or save, or undo) what nobody is waiting
   -- for, maybe twice: it does nothing, and the user is told why.
   if tAnswer is true and sRequestSocket is not empty and sRequestSocket is not among the lines of sClients then
      try
         dispatch "mcbTooLate" to sAsker
      catch tError
      end try
      return false
   end if
   return tAnswer is true
end mcbAsk

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
   local tWork, tText, tTop, tLine, tObject, tList, tEditor, tError, tState, tLast
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
      end if
   catch tError
   end try
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
      return mcbResult(xtaStackOutline(mcbMainStackOf(tStack)), false)
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

-- An object as the user would name it: its type, name and id
private function mcbObjectLabel pObject
   local tType
   put word 1 of the name of pObject into tType
   if tType is "stack" then
      return "the stack" && quote & the short name of pObject & quote
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
-- time. The sandbox is a hidden stack in this same engine, so its code can
-- do whatever the IDE can; and xtaRiskScan reads the code's text, which
-- code can always word so that it is not seen ("the shell of", a "do" of
-- text it builds, a handler the code calls), so it only says what the
-- code seems to use. In the xTalk Assistant the user reads the code in
-- its window before Run; through the bridge, Claude's app may have been
-- told to allow every call, so this question is the user's only look.
private function mcbToolRunCode pArguments
   local tRun, tRisks, tTitle, tDetail, tRan, tText
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
   put tRun["label"] & "." && "It can do anything " & mcbHostName() & " can: run it only if you know what it does." & return & return after tDetail
   put tRun["code"] after tDetail
   if tRun["handlers"] is not empty then
      put return & return & "With these handlers:" & return & tRun["handlers"] after tDetail
   end if
   -- The question shows the user the whole of what would run, or nothing
   -- runs: mcbAsk cuts a longer text, and Run then ran code the user could
   -- not read
   if the number of chars of tDetail > kMaxAskChars then
      return mcbResult("Nothing ran: the code and its handlers are too long for the user to read in the question " & mcbHostName() & \
            " asks before a run (" & the number of chars of tDetail && "characters with the question; at most" && kMaxAskChars & "). " & \
            "Run shorter code: put long handlers into the stack's script with make_changes first, then run a short call to them.", true)
   end if
   if not mcbAsk(tTitle, tDetail, "Run") then
      return mcbResult("Nothing ran: the user did not allow the run. Ask them what they would like instead; do not send the same code again.", true)
   end if
   put xtaRunCode(tRun) into tRan
   if tRan["ran"] is not true and tRan["text"] is empty then
      return mcbResult("Nothing ran:" && tRan["error"], true)
   end if
   put tRan["text"] into tText
   if tRan["entry"] is not empty then
      put return & "This is change" && tRan["entry"] & "; undo_changes takes the stack back to before the run." after tText
   end if
   return mcbResult(tText, tRan["ok"] is not true)
end mcbToolRunCode

-- Saves a stack (its main stack, with its substacks) to its file, after
-- the user says yes in OXT-Beyond, every time
private function mcbToolSaveStack pStackName
   local tTarget, tMain, tName, tFile, tDetail, tDone, tError
   put mcbTarget(pStackName) into tTarget
   if tTarget["problem"] is not empty then
      return mcbResult("Nothing was saved:" && tTarget["problem"], true)
   end if
   put mcbMainStackOf(tTarget["stack"]) into tMain
   put the short name of tMain into tName
   put the effective filename of tMain into tFile
   if tFile is empty then
      put "It has never been saved: you choose where, in the dialog that comes next." into tDetail
   else
      put "It is saved to its file, with its substacks:" & return & tFile into tDetail
   end if
   put return & return & "Saving cannot be undone." after tDetail
   if not mcbAsk("Claude asks to save the stack" && quote & tName & quote & ".", tDetail, "Save") then
      return mcbResult("The user chose not to save the stack" && quote & tName & quote & ", and nothing was saved. Do not ask again unless they ask you to.", true)
   end if
   try
      revIDEActionSaveStack tMain
      put the result into tDone
   catch tError
      -- Without the IDE (the tests): the engine's own save, which needs a
      -- file
      put empty into tDone
      if tFile is empty then
         put "the stack has no file" into tDone
      else
         save tMain
         put the result into tDone
      end if
   end try
   put the effective filename of tMain into tFile
   if tDone is "Cancelled" then
      return mcbResult("The user cancelled saving the stack" && quote & tName & quote & ", and nothing was saved.", true)
   end if
   if tDone is not empty or tFile is empty or there is not a file tFile then
      return mcbResult("The stack" && quote & tName & quote && "was not saved:" && line 1 of tDone, true)
   end if
   return mcbResult("Saved the stack" && quote & tName & quote && "to" && tFile & ".", false)
end mcbToolSaveStack

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
