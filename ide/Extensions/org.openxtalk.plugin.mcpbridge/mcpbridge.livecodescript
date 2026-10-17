script "org.openxtalk.plugin.mcpbridge"
-- OXT-Beyond: the xTalk MCP Bridge, which lets Claude, in the Claude
-- desktop app or Claude Code, signed in with the user's own Claude plan
-- (Free, Pro, Max, Team or Enterprise), read and build the stacks open in
-- this IDE: their cards, controls and scripts, new stacks, code run in a
-- sandbox, all with the xTalk Assistant's tools.
--
-- Why a bridge. The xTalk Assistant talks to a model with an API key the
-- user pastes; a Claude plan cannot be used that way, because Anthropic lets
-- no program but its own sign in to a Claude account (its terms for Claude
-- Code and the Agent SDK). So the bridge turns it around: the user adds
-- OXT-Beyond to Claude's own app as an MCP server (mcp/server.js in this
-- folder, which that app starts and signs nothing in), and the server asks
-- this IDE, over a socket only this computer reaches, to do what Claude
-- asks for. The plan pays for the model; this IDE holds no key, account or
-- password, and sends nothing to the internet. It is an addition beside the
-- assistant, which stays as it is: either, both or neither can be on.
--
-- Off by default. The IDE loads this stack as it loads every extension,
-- and while the bridge is off that is all that happens: nothing listens,
-- nothing is loaded. The only thing it adds is the "xTalk MCP Bridge" item
-- of Development > Plugins (revmenubar.livecodescript), which asks the user
-- before turning it on. Once on, it stays on from one session to the next
-- (it starts a moment after the IDE does) until the user turns it off from
-- the same item. Set the environment variable OXTBEYOND_MCP_BRIDGE to "off"
-- to keep it off for good.
--
-- Files: this stack (the plugin's lifecycle, its dialogs, and the
-- functions the bridge asks: mcbConfirm, mcbEditorStack and
-- mcbEditorContext), mcpbridge-errors.livecodescript (notes the errors the
-- IDE shows the user, for ide_context),
-- mcpbridge-tools.livecodescript (the socket and the tools, tested by
-- tests/lcs/mcpbridge), mcp/server.js (the MCP server, tested by
-- tools/ci/tests/test_mcp_bridge_server.py) and mcp/manifest.json (what
-- makes it a Claude desktop extension, a .mcpb file the setup dialog
-- saves). The tools come from the xTalk Assistant's folder
-- (org.openxtalk.plugin.xtalkassistant), its core and build library and
-- its guide.
--
-- Public handlers (all reached with dispatch):
--    mcpBridgeMenuPick           Development > Plugins > xTalk MCP Bridge
--    mcbIsEnabled()
--    mcbConfirm(pTitle, pDetail, pYes), mcbTooLate, mcbEditorStack(),
--    mcbEditorContext()          (the bridge's)

constant kTitle = "xTalk MCP Bridge"
constant kTools = "org.openxtalk.plugin.mcpbridge-tools"
constant kAssistantFolderName = "org.openxtalk.plugin.xtalkassistant"
-- Where a package of the bridge keeps its copy of the assistant's files
-- (mcbAssistantFolder)
constant kBundledAssistantFolder = "xtalkassistant"
-- Preferences (custom properties of the revPreferences stack)
constant kPrefEnabled = "cMcpBridge,enabled"
-- The name Claude's apps show for the server (mcbServerName: a package of
-- the bridge in another xTalk's IDE gives that IDE's own)
constant kServerName = "oxt-beyond"
-- What a package of this plugin for another xTalk's IDE carries
-- (tools/plugins); OXT-Beyond's own copy has no such file
constant kCompat = "org.openxtalk.plugin.mcpbridge-compat"
-- Where in the user's ~/.oxt-beyond folder a package keeps the copy of the
-- MCP server that Claude runs (mcbServerPath)
constant kStableServerFile = "mcp/server.js"

-- Why the bridge could not start when it last tried, for the menu item
local sStartProblem

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   -- Part of the IDE, not of the user's work
   set the _ideoverride of me to true
   -- In another xTalk's IDE (LiveCode Community 9 and the IDEs built on
   -- it), a package of this plugin (tools/plugins) carries a stack that
   -- gives it the menu item and the Script Editor handlers that IDE lacks.
   -- OXT-Beyond's own copy has no such file, so this does nothing here.
   mcbStartCompat
   -- Turned on in an earlier session: started once the IDE is up
   if mcbIsEnabled() then
      send "mcbAutoStart" to me in 2 seconds
   end if
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if
   mcbStop
   mcbStopCompat
end extensionFinalize

on mcbAutoStart
   if not mcbIsEnabled() then
      exit mcbAutoStart
   end if
   put mcbStart() into sStartProblem
end mcbAutoStart

--------------------------------------------------------------------------------
-- On and off

function mcbIsEnabled
   if mcbIsLockedOff() then
      return false
   end if
   return revIDEGetPreference(kPrefEnabled) is true
end mcbIsEnabled

private function mcbIsLockedOff
   return toLower($OXTBEYOND_MCP_BRIDGE) is among the items of "off,0,false,no"
end mcbIsLockedOff

command mcpBridgeMenuPick
   local tProblem, tPort, tClients, tText
   if mcbIsLockedOff() then
      answer information "The xTalk MCP Bridge is turned off on this computer (by the environment variable OXTBEYOND_MCP_BRIDGE)." titled kTitle
      exit mcpBridgeMenuPick
   end if
   if not mcbIsEnabled() then
      answer question "The xTalk MCP Bridge lets Claude, in the Claude desktop app or in Claude Code, work on the stacks you have open here: read them, build cards, controls, scripts and new stacks, and try code. It uses your own Claude plan (Free, Pro, Max, Team or Enterprise): you sign in to Claude's app as usual, and this IDE needs no API key." & return & return & \
            "Turning it on starts a connection that only programs on this computer can reach, with a key that is kept in a file only you can read, and " & mcbHostName() & " sends nothing to the internet. Then you add " & mcbHostName() & " to Claude once (the next window shows how)." & return & return & \
            "Claude's app asks you before it uses each tool. Here you are asked before any code Claude sends runs (you see the code), and before a stack is saved; everything else Claude changes can be undone from this menu item." \
            with "Cancel" or "Turn On" titled kTitle
      if it is not "Turn On" then
         exit mcpBridgeMenuPick
      end if
      put mcbStart() into tProblem
      if tProblem is not empty then
         answer error "The bridge could not start:" && tProblem titled kTitle
         exit mcpBridgeMenuPick
      end if
      revIDESetPreference kPrefEnabled, true
      mcbSetupDialog
      exit mcpBridgeMenuPick
   end if
   -- On: started at launch, or not when that failed
   if mcbPort() is empty then
      put mcbStart() into sStartProblem
   end if
   put mcbPort() into tPort
   if tPort is empty then
      answer error "The xTalk MCP Bridge is on but could not start:" && sStartProblem with "Turn Off" or "Close" titled kTitle
      if it is "Turn Off" then
         mcbTurnOff
      end if
      exit mcpBridgeMenuPick
   end if
   put mcbClients() into tClients
   if tClients is 0 then
      put "The xTalk MCP Bridge is on. Claude is not connected yet: in Claude's app, ask it to do something with " & mcbHostName() & "." into tText
   else
      put "The xTalk MCP Bridge is on, and Claude is connected." into tText
   end if
   put return & return & "Undo Last Change takes back the newest change Claude made to a stack, or the newest run of its code on one." after tText
   answer information tText with "Turn Off" or "Undo Last Change" or "Claude Setup..." or "Close" titled kTitle
   switch it
      case "Turn Off"
         mcbTurnOff
         break
      case "Undo Last Change"
         mcbUndoLastChange
         break
      case "Claude Setup..."
         mcbSetupDialog
         break
   end switch
end mcpBridgeMenuPick

private command mcbTurnOff
   answer question "Turn the xTalk MCP Bridge off? Claude can no longer reach " & mcbHostName() & ", and what it changed can no longer be undone from here (it stays as it is). You can turn it on again from Development > Plugins." \
         with "Cancel" or "Turn Off" titled kTitle
   if it is not "Turn Off" then
      exit mcbTurnOff
   end if
   revIDESetPreference kPrefEnabled, false
   mcbStop
end mcbTurnOff

private command mcbUndoLastChange
   local tUndone
   put mcbUndoLast() into tUndone
   answer information tUndone["text"] titled kTitle
end mcbUndoLastChange

-- Loads the bridge's library and starts it; empty, or why it could not
private function mcbStart
   local tFolder, tError
   put mcbPluginFolder() into tFolder
   try
      if there is not a stack kTools then
         get the short name of stack (tFolder & "/mcpbridge-tools.livecodescript")
      end if
      if not mcbToolsInUse() then
         start using stack kTools
      end if
      set the _ideoverride of stack kTools to true
      get mcbServerStart(mcbAssistantFolder(), the long id of me, empty)
   catch tError
      return line 1 of tError
   end try
   return empty
end mcbStart

private command mcbStop
   local tError
   if mcbToolsInUse() then
      try
         mcbServerStop
      catch tError
      end try
      stop using stack kTools
   end if
   put empty into sStartProblem
end mcbStop

private function mcbToolsInUse
   local tLine
   if there is not a stack kTools then
      return false
   end if
   repeat for each line tLine in the stacksInUse
      if there is a stack tLine and the long id of stack tLine is the long id of stack kTools then
         return true
      end if
   end repeat
   return false
end mcbToolsInUse

private function mcbPort
   if not mcbToolsInUse() then
      return empty
   end if
   return mcbServerPort()
end mcbPort

private function mcbClients
   if not mcbToolsInUse() then
      return 0
   end if
   return mcbServerClients()
end mcbClients

private function mcbPluginFolder
   set the itemDelimiter to slash
   return item 1 to -2 of the effective filename of me
end mcbPluginFolder

-- The xTalk Assistant's folder, beside this one. A package of the bridge
-- for another xTalk's IDE (tools/plugins) is installed in a folder of its
-- own, named with its version, so it carries the assistant's core, build
-- library and guide in a folder inside its own (kBundledAssistantFolder);
-- that one is used only when there is no assistant beside the bridge, as
-- there always is in OXT-Beyond.
private function mcbAssistantFolder
   local tBeside
   set the itemDelimiter to slash
   put item 1 to -2 of mcbPluginFolder() & slash & kAssistantFolderName into tBeside
   if there is not a folder tBeside and there is a folder (mcbPluginFolder() & slash & kBundledAssistantFolder) then
      return mcbPluginFolder() & slash & kBundledAssistantFolder
   end if
   return tBeside
end mcbAssistantFolder

--------------------------------------------------------------------------------
-- Setting Claude up

private command mcbSetupDialog
   local tText
   put "Add " & mcbHostName() & " to Claude once, in the app you use:" & return & return & \
         "Claude desktop app: press Save Desktop Extension..., then in Claude choose Settings > Extensions > Advanced settings > Install Extension... and choose the file it saved (opening the file works only where Windows or macOS knows it is Claude's). Claude's app runs it with its own Node.js; you install nothing else." & return & return & \
         "Or press Add to Claude Desktop, which adds " & mcbHostName() & " to the Claude desktop app's settings file for you. That way needs Node.js (nodejs.org)." & return & return & \
         "Claude Code: press Copy Claude Code Command and paste it into a terminal. It needs Node.js 16 or later." & return & return & \
         "Then sign in to Claude with your own account, as usual, and ask it to work on your stack. This IDE must be open with the bridge on." into tText
   answer information tText with "Save Desktop Extension..." or "Add to Claude Desktop" or "Copy Claude Code Command" or "Close" titled kTitle
   switch it
      case "Save Desktop Extension..."
         mcbSaveDesktopExtension
         break
      case "Add to Claude Desktop"
         mcbAddToClaudeDesktop
         break
      case "Copy Claude Code Command"
         set the clipboardData["text"] to mcbClaudeCodeCommand()
         answer information "The command is on the clipboard: paste it into a terminal (Ctrl+V, or Command-V on a Mac), then start Claude Code (claude) and ask it to work on your stack. It reads:" & return & return & mcbClaudeCodeCommand() titled kTitle
         break
   end switch
end mcbSetupDialog

-- Where the Claude desktop app keeps its settings file
private function mcbClaudeConfigPath
   local tFolder
   switch the platform
      case "Win32"
         put $APPDATA into tFolder
         replace backslash with slash in tFolder
         return tFolder & "/Claude/claude_desktop_config.json"
      case "MacOS"
         return specialFolderPath("home") & "/Library/Application Support/Claude/claude_desktop_config.json"
      default
         put $XDG_CONFIG_HOME into tFolder
         if tFolder is empty then
            put specialFolderPath("home") & "/.config" into tFolder
         end if
         return tFolder & "/Claude/claude_desktop_config.json"
   end switch
end mcbClaudeConfigPath

-- The path as the platform writes it, for the user to read
private function mcbNativePath pPath
   if the platform is "Win32" then
      replace slash with backslash in pPath
   end if
   return pPath
end mcbNativePath

-- True when a program named node can be found on the PATH, or on a Mac
-- where its installers put it: an app opened from the Finder or the Dock
-- has the system's PATH, without /usr/local/bin (nodejs.org's installer)
-- or /opt/homebrew/bin (Homebrew), and the bridge said Node.js was not
-- installed when it was
private function mcbHasNode
   local tOut, tResult, tHide, tFile
   if the platform is "MacOS" then
      repeat for each item tFile in "/usr/local/bin/node,/opt/homebrew/bin/node,/opt/local/bin/node"
         if there is a file tFile then
            return true
         end if
      end repeat
   end if
   put the hideConsoleWindows into tHide
   set the hideConsoleWindows to true
   if the platform is "Win32" then
      put shell("where node") into tOut
   else
      put shell("command -v node") into tOut
   end if
   put the result into tResult
   set the hideConsoleWindows to tHide
   return tResult is 0 and word 1 to -1 of tOut is not empty
end mcbHasNode

-- Adds OXT-Beyond's entry to the Claude desktop app's settings file, after
-- the user says yes, keeping the rest of the file as it was and a copy of
-- it beside it. When the file cannot be read as JSON, the whole entry goes
-- on the clipboard for the user to put in by hand.
private command mcbAddToClaudeDesktop
   local tPath, tFolder, tOld, tData, tMerged, tNote, tProblem, tError
   put mcbClaudeConfigPath() into tPath
   if not mcbHasNode() then
      put return & return & "Node.js does not seem to be installed (no node program was found). Install it from nodejs.org first, or use Save Desktop Extension..., which needs none." into tNote
   end if
   answer question "Add " & mcbHostName() & " to the Claude desktop app's settings file?" & return & return & mcbNativePath(tPath) & return & return & \
         "Its other settings stay as they are, and a copy of the file is kept beside it as claude_desktop_config.json.bak. Claude runs the bridge's server with Node.js." & tNote \
         with "Cancel" or "Add" titled kTitle
   if it is not "Add" then
      exit mcbAddToClaudeDesktop
   end if
   if there is a file tPath then
      put url ("binfile:" & tPath) into tData
      put textDecode(tData, "UTF-8") into tOld
      -- A byte order mark some editors write
      if char 1 of tOld is numToCodepoint(65279) then
         delete char 1 of tOld
      end if
   end if
   try
      put mcbDesktopConfigText(tOld, mcbServerName(), mcbServerPath(), mcbBridgeFile()) into tMerged
   catch tError
      put line 1 of tError into tMerged["problem"]
   end try
   if tMerged["problem"] is not empty then
      set the clipboardData["text"] to mcbDesktopConfig()
      answer error "The settings file could not be changed:" && tMerged["problem"] & "." & return & return & \
            mcbHostName() & "'s entry is on the clipboard. In Claude, open Settings > Developer > Edit Config, paste it (Ctrl+V) inside " & quote & "mcpServers" & quote & \
            ", save, and quit and reopen Claude." titled kTitle
      exit mcbAddToClaudeDesktop
   end if
   set the itemDelimiter to slash
   put item 1 to -2 of tPath into tFolder
   if there is not a folder tFolder then
      create folder tFolder
   end if
   if tData is not empty then
      put tData into url ("binfile:" & tPath & ".bak")
   end if
   put textEncode(tMerged["text"], "UTF-8") into url ("binfile:" & tPath)
   put the result into tProblem
   if tProblem is not empty then
      set the clipboardData["text"] to tMerged["text"]
      answer error "The settings file could not be written (" & tProblem & "). What it should hold is on the clipboard: in Claude, open Settings > Developer > Edit Config, replace the text with it (Ctrl+V), save, and quit and reopen Claude." titled kTitle
      exit mcbAddToClaudeDesktop
   end if
   answer information "Added. Now quit the Claude desktop app completely and open it again: closing its window is not enough (on Windows, right-click its icon by the clock and choose Quit; on a Mac, Claude > Quit Claude)." & return & return & \
         "Then ask Claude to list your " & mcbHostName() & " stacks. If it cannot, Claude's log of the server is in its logs folder (Settings > Developer shows it), as mcp-server-" & mcbServerName() & ".log." titled kTitle
end mcbAddToClaudeDesktop

-- The server's file, in the form of the platform's paths. A package of
-- the bridge for another xTalk's IDE is installed in a folder named with
-- its version, which the next version replaces, so there Claude is given
-- a copy that outlives an upgrade (the compatibility stack's
-- xtpcStableCopy); OXT-Beyond's own copy has no compatibility stack, and
-- its path is given as it is.
private function mcbServerPath
   local tPath, tCopy
   put mcbPluginFolder() & "/mcp/server.js" into tPath
   if there is a stack kCompat then
      dispatch function "xtpcStableCopy" to stack kCompat with tPath, kStableServerFile, false
      put the result into tCopy
      if it is "handled" and tCopy is not empty then
         put tCopy into tPath
      end if
   end if
   if the platform is "Win32" then
      replace slash with backslash in tPath
   end if
   return tPath
end mcbServerPath

-- The name Claude's apps give the server: "oxt-beyond", or in a package
-- of the bridge for another xTalk's IDE that IDE's (its compatibility
-- stack's xtpcServerName), so that two IDEs bridged on one computer are
-- two servers
private function mcbServerName
   local tName
   if there is a stack kCompat then
      dispatch function "xtpcServerName" to stack kCompat
      put the result into tName
      if it is "handled" and tName is not empty then
         return tName
      end if
   end if
   return kServerName
end mcbServerName

-- The file the server is told to read the port and token from
-- (OXT_MCP_BRIDGE_FILE), in the form of the platform's paths: in a package
-- for another xTalk's IDE, that IDE's own (xtpcBridgeFile, which the
-- bridge writes: mcbInfoFilePath); empty in OXT-Beyond, whose server reads
-- its own ~/.oxt-beyond/mcp-bridge.json unasked
private function mcbBridgeFile
   local tFile
   if there is a stack kCompat then
      dispatch function "xtpcBridgeFile" to stack kCompat
      put the result into tFile
      if it is not "handled" then
         put empty into tFile
      end if
   end if
   if the platform is "Win32" then
      replace slash with backslash in tFile
   end if
   return tFile
end mcbBridgeFile

private function mcbClaudeCodeCommand
   local tEnv
   if mcbBridgeFile() is not empty then
      put " -e" && quote & "OXT_MCP_BRIDGE_FILE=" & mcbBridgeFile() & quote into tEnv
   end if
   return "claude mcp add --scope user" && mcbServerName() & tEnv && "-- node" && quote & mcbServerPath() & quote
end mcbClaudeCodeCommand

private function mcbDesktopConfig
   local tPath, tFile, tEnv
   put mcbServerPath() into tPath
   replace backslash with backslash & backslash in tPath
   replace quote with backslash & quote in tPath
   put mcbBridgeFile() into tFile
   if tFile is not empty then
      replace backslash with backslash & backslash in tFile
      replace quote with backslash & quote in tFile
      put "," & return & "  " & quote & "env" & quote & ": {" & quote & "OXT_MCP_BRIDGE_FILE" & quote & ": " & quote & tFile & quote & "}" into tEnv
   end if
   return quote & mcbServerName() & quote & ": {" & return & \
         "  " & quote & "command" & quote & ": " & quote & "node" & quote & "," & return & \
         "  " & quote & "args" & quote & ": [" & quote & tPath & quote & "]" & tEnv & return & "}"
end mcbDesktopConfig

-- A Claude desktop extension (.mcpb): a zip of the manifest and the
-- server, which Claude's app installs and runs with its own Node.js
private command mcbSaveDesktopExtension
   local tFile, tArchive, tProblem, tError, tManifest
   ask file "Save the Claude desktop extension as:" with (mcbHostName() & ".mcpb")
   if it is empty then
      exit mcbSaveDesktopExtension
   end if
   put it into tFile
   if not (tFile ends with ".mcpb") then
      put ".mcpb" after tFile
   end if
   if there is a file tFile then
      delete file tFile
   end if
   put mcbDesktopManifest() into tManifest
   if tManifest["problem"] is not empty then
      answer error "The extension could not be saved:" && tManifest["problem"] titled kTitle
      exit mcbSaveDesktopExtension
   end if
   try
      revZipOpenArchive tFile, "write"
      put the result into tProblem
      if tProblem is empty then
         revZipAddItemWithFile tFile, "manifest.json", tManifest["file"]
         put the result into tProblem
      end if
      if tProblem is empty then
         revZipAddItemWithFile tFile, "server.js", mcbPluginFolder() & "/mcp/server.js"
         put the result into tProblem
      end if
      revZipCloseArchive tFile
      if tProblem is empty then
         put the result into tProblem
      end if
   catch tError
      put "the zip library is not available (" & line 1 of tError & ")" into tProblem
   end try
   if tManifest["temporary"] then
      delete file tManifest["file"]
   end if
   if tProblem is not empty then
      answer error "The extension could not be saved:" && tProblem & return & return & \
            "Add to Claude Desktop sets Claude up another way." titled kTitle
      exit mcbSaveDesktopExtension
   end if
   answer information "Saved" && mcbNativePath(tFile) & "." & return & return & \
         "In the Claude desktop app, choose Settings > Extensions > Advanced settings > Install Extension..., choose this file, and turn the extension on. (Opening the file itself works only where the system knows it is Claude's.)" titled kTitle
end mcbSaveDesktopExtension

-- The manifest.json the desktop extension takes: the bridge's own
-- (mcp/manifest.json); or, in a package for another xTalk's IDE, a copy in
-- the temporary folder with that IDE's server name, its name to show, and
-- the bridge file its server reads (mcbServerName, mcbBridgeFile). An array
-- with "file" and "temporary" (true for the copy), or "problem".
private function mcbDesktopManifest
   local tResult, tText, tFile, tCopy, tOld
   put mcbPluginFolder() & "/mcp/manifest.json" into tResult["file"]
   put false into tResult["temporary"]
   put mcbBridgeFile() into tFile
   if tFile is empty then
      return tResult
   end if
   put textDecode(url ("binfile:" & tResult["file"]), "UTF-8") into tText
   -- "name" of the server, not of a tool, and only as written
   set the caseSensitive to true
   replace backslash with backslash & backslash in tFile
   replace quote with backslash & quote in tFile
   repeat for each item tOld in "name,display_name,args"
      if not (tText contains mcbManifestLine(tOld)) then
         put "its manifest has no" && mcbManifestLine(tOld) into tResult["problem"]
         return tResult
      end if
   end repeat
   replace mcbManifestLine("name") with quote & "name" & quote & ": " & quote & mcbServerName() & quote in tText
   replace mcbManifestLine("display_name") with quote & "display_name" & quote & ": " & quote & mcbHostName() & quote in tText
   replace mcbManifestLine("args") with mcbManifestLine("args") & "," & return & \
         "      " & quote & "env" & quote & ": {" & quote & "OXT_MCP_BRIDGE_FILE" & quote & ": " & quote & tFile & quote & "}" in tText
   put specialFolderPath("temporary") & "/mcpbridge-manifest-" & the milliseconds & ".json" into tCopy
   put textEncode(tText, "UTF-8") into url ("binfile:" & tCopy)
   if the result is not empty then
      put "the manifest could not be written to" && tCopy && "(" & the result & ")" into tResult["problem"]
      return tResult
   end if
   put tCopy into tResult["file"]
   put true into tResult["temporary"]
   return tResult
end mcbDesktopManifest

-- A line of mcp/manifest.json as the bridge's own reads, which a package
-- for another xTalk's IDE changes (mcbDesktopManifest;
-- tools/ci/tests/test_plugin_packages.py checks the manifest has them)
private function mcbManifestLine pKey
   switch pKey
      case "name"
         return quote & "name" & quote & ": " & quote & kServerName & quote
      case "display_name"
         return quote & "display_name" & quote & ": " & quote & "OXT-Beyond" & quote
      case "args"
         return quote & "args" & quote & ": [" & quote & "${__dirname}/server.js" & quote & "]"
   end switch
   return empty
end mcbManifestLine

--------------------------------------------------------------------------------
-- What the bridge asks

-- Asks the user before what cannot be undone; true when they said yes
function mcbConfirm pTitle, pDetail, pYes
   answer question pTitle & return & return & pDetail with "Cancel" or pYes titled kTitle
   return it is pYes
end mcbConfirm

-- The stack of the script open in the Script Editor, or empty
-- The user said yes to a question after Claude's app stopped waiting for
-- the answer (mcbAsk): nothing was done
on mcbTooLate
   answer information "Claude stopped waiting for this answer, so nothing was done. Ask Claude again if you still want it." titled kTitle
end mcbTooLate

function mcbEditorStack
   local tEditor, tObject, tError
   try
      put revTopMostScriptEditor() into tEditor
      if tEditor is empty or there is not a tEditor then
         return empty
      end if
      dispatch "revSEGetCurrentObject" to tEditor
      put the result into tObject
      if tObject is empty or there is not a tObject then
         return empty
      end if
      return revIDEStackOfObject(tObject)
   catch tError
      return empty
   end try
end mcbEditorStack

-- The script open in the topmost Script Editor: an array with "object"
-- (its long id), "line" (the line the caret was last on, or empty) and
-- "unapplied" (true when the editor holds changes not yet applied), or
-- empty when no script is open
function mcbEditorContext
   local tEditor, tObject, tContext, tLine, tError
   try
      put revTopMostScriptEditor() into tEditor
      if tEditor is empty or there is not a tEditor then
         return empty
      end if
      dispatch "revSEGetCurrentObject" to tEditor
      put the result into tObject
      if tObject is empty or there is not a tObject then
         return empty
      end if
      put the long id of tObject into tContext["object"]
      dispatch function "revSEGetLastSelectedLine" to tEditor
      put the result into tContext["line"]
      -- The objects whose scripts the user changed and has not applied
      put false into tContext["unapplied"]
      dispatch "revSEGetModifiedObjects" to tEditor
      repeat for each line tLine in the result
         if there is a tLine then
            if the long id of tLine is tContext["object"] then
               put true into tContext["unapplied"]
            end if
         end if
      end repeat
   catch tError
      return empty
   end try
   return tContext
end mcbEditorContext

--------------------------------------------------------------------------------
-- In another xTalk's IDE

-- Loads the package's compatibility stack (mcpbridge-compat.livecodescript),
-- when this copy of the plugin has one, and starts it; it does nothing on
-- an IDE whose menu bar and Script Editor know the plugin already
private command mcbStartCompat
   local tFile, tError
   put mcbPluginFolder() & "/mcpbridge-compat.livecodescript" into tFile
   if there is not a file tFile then
      exit mcbStartCompat
   end if
   try
      if there is not a stack kCompat then
         get the short name of stack tFile
      end if
      if not (the long id of stack kCompat is among the lines of mcbCompatInUse()) then
         start using stack kCompat
      end if
      set the _ideoverride of stack kCompat to true
      dispatch "xtpcStart" to stack kCompat
      -- A copy of the MCP server that Claude was given before an upgrade
      -- is brought up to this version's
      dispatch function "xtpcStableCopy" to stack kCompat with mcbPluginFolder() & "/mcp/server.js", kStableServerFile, true
   catch tError
   end try
end mcbStartCompat

private command mcbStopCompat
   local tError
   if there is not a stack kCompat then
      exit mcbStopCompat
   end if
   try
      dispatch "xtpcStop" to stack kCompat
      if the long id of stack kCompat is among the lines of mcbCompatInUse() then
         stop using stack kCompat
      end if
      delete stack kCompat
   catch tError
   end try
end mcbStopCompat

private function mcbCompatInUse
   local tList, tName
   repeat for each line tName in the stacksInUse
      if there is a stack tName then
         put the long id of stack tName & return after tList
      end if
   end repeat
   return tList
end mcbCompatInUse

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
