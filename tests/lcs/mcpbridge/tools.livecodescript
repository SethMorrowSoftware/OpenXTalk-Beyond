script "TestMcpBridgeTools"
-- OXT-Beyond: tests of the OXT side of the xTalk MCP Bridge
-- (ide/Extensions/org.openxtalk.plugin.mcpbridge/mcpbridge-tools.livecodescript),
-- loaded with the xTalk Assistant's core and build library as the plugin
-- loads them, with a stand-in for the IDE handlers they tell and for the
-- plugin's main stack, which asks the user: that the server listens on
-- 127.0.0.1, writes its port and token and deletes them when it stops,
-- that a request without the token is refused, that the tools read, build,
-- run and undo through the requests the MCP server sends, that code runs
-- only when the user says yes (every run), that a long script is read in
-- parts and edited by handler or by lines, and that a real socket gets its
-- answer. And the web IDE's link (mcbLinkStart): the same tools without a
-- socket or token, never on with the server, asking before a run, and a
-- yes given after its connection was lost doing nothing.

constant kTools = "org.openxtalk.plugin.mcpbridge-tools"
constant kUserStack = "mcbTestUserStack"

local sInfoFile, sReply

on TestSetup
   local tFolder, tStub, tName
   -- Every test talks to the bridge's server
   TestSkipIfNot "sockets"
   put TestGetIDERepositoryPath() & "/Extensions/org.openxtalk.plugin.mcpbridge" into tFolder
   start using stack (tFolder & "/mcpbridge-tools.livecodescript")
   -- The IDE's handlers the assistant's build library calls, and the
   -- plugin's two functions the bridge asks: mcbConfirm answers as
   -- mcbTestSetAnswer says, and records what it was asked
   put "local sAnswer, sAsked" & return & \
         "on ideMessageSend pMessage, pTarget" & return & "end ideMessageSend" & return & \
         "on revIDESetEdited pStack" & return & "end revIDESetEdited" & return & \
         "on mcbTestSetAnswer pAnswer" & return & "put pAnswer into sAnswer" & return & "end mcbTestSetAnswer" & return & \
         "function mcbConfirm pTitle, pDetail, pYes" & return & "put pTitle & return after sAsked" & return & \
         "if sAnswer is " & quote & "lose" & quote & " then" & return & "mcbLinkLost" & return & "return true" & return & "end if" & return & \
         "return sAnswer" & return & "end mcbConfirm" & return & \
         "on mcbTooLate" & return & "put " & quote & "too late" & quote & " & return after sAsked" & return & "end mcbTooLate" & return & \
         "function mcbEditorStack" & return & "return empty" & return & "end mcbEditorStack" & return & \
         "function mcbTestAsked" & return & "return sAsked" & return & "end mcbTestAsked" & return into tStub
   create invisible stack "mcbTestIDE"
   set the script of stack "mcbTestIDE" to tStub
   start using stack "mcbTestIDE"
   -- The test runner's stacks and this stand-in are not the user's, as
   -- the IDE's own stacks are not
   repeat for each line tName in the mainStacks
      if there is a stack tName then
         set the _ideoverride of stack tName to true
      end if
   end repeat
   put specialFolderPath("temporary") & "/mcbtest-" & the milliseconds & "/mcp-bridge.json" into sInfoFile
end TestSetup

on TestTeardown
   if the long id of stack kTools is among the lines of TestStacksInUse() then
      mcbServerStop
      mcbLinkStop
   end if
end TestTeardown

private function TestStacksInUse
   local tList, tName
   repeat for each line tName in the stacksInUse
      if there is a stack tName then
         put the long id of stack tName & return after tList
      end if
   end repeat
   return tList
end TestStacksInUse

private command TestStart
   local tPort
   put mcbServerStart(TestGetIDERepositoryPath() & "/Extensions/org.openxtalk.plugin.xtalkassistant", \
         the long id of stack "mcbTestIDE", sInfoFile) into tPort
end TestStart

private function TestToken
   local tInfo
   put xtaJsonParse(textDecode(url ("binfile:" & sInfoFile), "UTF-8")) into tInfo
   return xtaJsonText(xtaJsonMember(tInfo, "token"))
end TestToken

-- A call as the MCP server sends it, answered: the parsed answer
private function TestCall pTool, pArgumentsJson
   local tLine
   if pArgumentsJson is empty then
      put "{}" into pArgumentsJson
   end if
   replace "`" with quote in pArgumentsJson
   put "{" & quote & "id" & quote & ":7," & quote & "token" & quote & ":" & quote & TestToken() & quote & "," & \
         quote & "method" & quote & ":" & quote & "call" & quote & "," & quote & "tool" & quote & ":" & quote & pTool & quote & "," & \
         quote & "arguments" & quote & ":" & pArgumentsJson & "}" into tLine
   return xtaJsonParse(mcbHandleLine(tLine))
end TestCall

private function TestText pReply
   return xtaJsonText(xtaJsonMember(pReply, "text"))
end TestText

private function TestIsError pReply
   return xtaJsonText(xtaJsonMember(pReply, "isError")) is "true"
end TestIsError

private function TestUserStack
   local tStack
   create stack kUserStack
   put the long id of stack kUserStack into tStack
   set the rect of tStack to "100,100,500,400"
   set the name of card 1 of tStack to "Main"
   create button "Go" in card 1 of tStack
   go stack kUserStack
   return tStack
end TestUserStack

--------------------------------------------------------------------------------

on TestServerWritesAndDeletesItsFile
   local tInfo, tPort
   TestStart
   put mcbServerPort() into tPort
   TestAssert "it listens on a port", tPort is an integer and tPort > 0
   TestAssert "it wrote its file", there is a file sInfoFile
   put xtaJsonParse(textDecode(url ("binfile:" & sInfoFile), "UTF-8")) into tInfo
   TestAssert "the file has the port", xtaJsonText(xtaJsonMember(tInfo, "port")) is tPort
   TestAssert "the file has a token of 32 hex digits", \
         matchText(xtaJsonText(xtaJsonMember(tInfo, "token")), "^[0-9a-f]{32}$")
   TestAssert "the file has the protocol", xtaJsonText(xtaJsonMember(tInfo, "protocol")) is 1
   mcbServerStop
   TestAssert "stopping deletes the file", there is not a file sInfoFile
   TestAssert "stopping forgets the port", mcbServerPort() is empty
end TestServerWritesAndDeletesItsFile

on TestRefusesARequestWithoutTheToken
   local tReply
   TestStart
   put xtaJsonParse(mcbHandleLine("{" & quote & "id" & quote & ":1," & quote & "method" & quote & ":" & quote & "hello" & quote & "}")) into tReply
   TestAssert "no token", xtaJsonText(xtaJsonMember(tReply, "ok")) is "false"
   put xtaJsonParse(mcbHandleLine("{" & quote & "id" & quote & ":2," & quote & "token" & quote & ":" & quote & "0123" & quote & "," & \
         quote & "method" & quote & ":" & quote & "call" & quote & "," & quote & "tool" & quote & ":" & quote & "list_stacks" & quote & "}")) into tReply
   TestAssert "a wrong token", xtaJsonText(xtaJsonMember(tReply, "ok")) is "false" and xtaJsonText(xtaJsonMember(tReply, "error")) contains "token"
   TestAssert "the id comes back", xtaJsonText(xtaJsonMember(tReply, "id")) is 2
   put xtaJsonParse(mcbHandleLine("not json")) into tReply
   TestAssert "not JSON", xtaJsonText(xtaJsonMember(tReply, "ok")) is "false"
   mcbServerStop
   -- The assistant's libraries, which this loaded, are gone with it: the
   -- refusal is read as text
   put mcbHandleLine("{" & quote & "id" & quote & ":3," & quote & "token" & quote & ":" & quote & quote & "," & \
         quote & "method" & quote & ":" & quote & "hello" & quote & "}") into tReply
   TestAssert "nothing is answered once stopped", tReply contains (quote & "ok" & quote & ":false") and tReply contains "turned off"
end TestRefusesARequestWithoutTheToken

on TestHello
   local tReply
   TestStart
   put xtaJsonParse(mcbHandleLine("{" & quote & "id" & quote & ":" & quote & "a" & quote & "," & quote & "token" & quote & ":" & quote & TestToken() & quote & "," & \
         quote & "method" & quote & ":" & quote & "hello" & quote & "}")) into tReply
   TestAssert "hello", xtaJsonText(xtaJsonMember(tReply, "ok")) is "true"
   TestAssert "a string id comes back", xtaJsonText(xtaJsonMember(tReply, "id")) is "a"
   TestAssert "the protocol", xtaJsonText(xtaJsonMember(tReply, "protocol")) is 1
   TestAssert "the tools", xtaJsonText(xtaJsonMember(tReply, "tools")) contains "make_changes"
end TestHello

on TestReadingTools
   local tReply
   TestStart
   put TestCall("list_stacks") into tReply
   TestAssert "no stacks of the user's yet", not TestIsError(tReply) and TestText(tReply) contains "no stack of their own"
   get TestUserStack()
   put TestCall("list_stacks") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "the user's stack is listed", TestText(tReply) contains kUserStack
   TestAssert "the bridge's own stacks are not", not (TestText(tReply) contains "mcpbridge") and not (TestText(tReply) contains "mcbTestIDE")
   put TestCall("read_stack", "{`stack`:`" & kUserStack & "`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "an outline", not TestIsError(tReply) and TestText(tReply) contains "Go"
   put TestCall("read_stack", "{`stack`:`nowhere`}") into tReply
   TestAssert "a stack that is not open", TestIsError(tReply)
   put TestCall("check_code", "{`code`:`put 1 into x`}") into tReply
   TestAssert "code that compiles", not TestIsError(tReply) and TestText(tReply) contains "compiles"
   put TestCall("check_code", "{`code`:`put 1 intoo x`}") into tReply
   TestAssert "code that does not", TestText(tReply) contains "does not compile"
   put TestCall("xtalk_guide") into tReply
   TestAssert "the guide", not TestIsError(tReply) and TestText(tReply) contains "xTalk"
   put TestCall("look_at_card", "{`stack`:`" & kUserStack & "`}") into tReply
   TestAssert "a picture of the card", not TestIsError(tReply) and xtaJsonText(xtaJsonMember(tReply, "imageType")) is "image/png" \
         and xtaJsonText(xtaJsonMember(tReply, "image")) is not empty
   put TestCall("no_such_tool") into tReply
   TestAssert "a tool there is not", TestIsError(tReply) and TestText(tReply) contains "no tool"
end TestReadingTools

on TestChangesAndUndo
   local tReply, tStack
   TestStart
   put TestUserStack() into tStack
   put TestCall("make_changes", "{`stack`:`" & kUserStack & "`,`changes`:[{`action`:`create`,`kind`:`button`,`name`:`Added`," & \
         "`script`:`on mouseUp\n  beep\nend mouseUp`}]}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "the change is made", not TestIsError(tReply) and there is a button "Added" of tStack
   TestAssert "it says how to undo it", TestText(tReply) contains "undo_changes"
   put TestCall("make_changes", "{`stack`:`" & kUserStack & "`,`changes`:[{`action`:`create`,`kind`:`button`,`properties`:{`lable`:`x`}}]}") into tReply
   TestAssert "a mistake changes nothing", TestIsError(tReply) and TestText(tReply) contains "Nothing was changed"
   put TestCall("make_changes", "{`stack`:`mcbTestIDE`,`changes`:[{`action`:`create`,`kind`:`button`}]}") into tReply
   TestAssert "the IDE's stacks are not changed", TestIsError(tReply)
   put TestCall("list_changes") into tReply
   TestAssert "the change is listed", TestText(tReply) contains "1:"
   put TestCall("undo_changes") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "undone", not TestIsError(tReply) and there is not a button "Added" of tStack
   put TestCall("undo_changes") into tReply
   TestAssert "nothing more to undo", TestIsError(tReply)
   put TestCall("undo_changes", "{`entry`:99}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "a change there never was is not called undone already", TestIsError(tReply) \
         and TestText(tReply) contains "There is no change 99" and not (TestText(tReply) contains "already")
end TestChangesAndUndo

-- Code longer than the question before a run shows in full does not run:
-- the user would have allowed code they could not read
on TestARunTooLongToShowIsRefused
   local tStack, tReply, tCode
   TestStart
   put TestUserStack() into tStack
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with true
   put "set the cLong of this stack to 1" into tCode
   repeat 100
      put "\nset the cLong of this stack to the cLong of this stack + 1" after tCode
   end repeat
   put TestCall("run_code", "{`where`:`stack`,`stack`:`" & kUserStack & "`,`code`:`" & tCode & "`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "refused, with what to do instead", TestIsError(tReply) and TestText(tReply) contains "too long for the user to read" \
         and TestText(tReply) contains "make_changes"
   TestAssert "and nothing ran", the cLong of tStack is empty
end TestARunTooLongToShowIsRefused

on TestUndoAsksWhenTheUserChangedIt
   local tReply, tStack
   TestStart
   put TestUserStack() into tStack
   put TestCall("make_changes", "{`stack`:`" & kUserStack & "`,`changes`:[{`action`:`set`,`object`:`stack`,`properties`:{`title`:`Before`}}]}") into tReply
   TestAssert "the change is made", not TestIsError(tReply)
   set the title of tStack to "The user's"
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with false
   put TestCall("undo_changes") into tReply
   TestAssert "the user is asked, says no, and nothing is undone", TestIsError(tReply) and the title of tStack is "The user's" \
         and mcbTestAsked() contains "Undo"
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with true
   put TestCall("undo_changes") into tReply
   TestAssert "says yes, and it is undone", not TestIsError(tReply) and the title of tStack is empty
end TestUndoAsksWhenTheUserChangedIt

on TestRunsAndWhatTheUserIsAsked
   local tReply, tFile
   TestStart
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with false
   put TestCall("run_code", "{`code`:`put 6 * 7`}") into tReply
   TestAssert "every run is asked about, and refused, does not run", TestIsError(tReply) and not (TestText(tReply) contains "42") \
         and mcbTestAsked() contains "run code"
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with true
   put TestCall("run_code", "{`code`:`put 6 * 7`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "allowed, a run in the sandbox", not TestIsError(tReply) and TestText(tReply) contains "42"
   put specialFolderPath("temporary") & "/mcbtest-nothing-" & the milliseconds into tFile
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with false
   put TestCall("run_code", "{`code`:`put \`x\` into url (\`file:" & tFile & "\`)`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "code that writes a file is asked about, and refused, does not run", TestIsError(tReply) \
         and mcbTestAsked() contains "run code" and there is not a file tFile
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with true
   put TestCall("run_code", "{`code`:`put \`x\` into url (\`file:" & tFile & "\`)`}") into tReply
   TestAssert "allowed, it runs", not TestIsError(tReply) and there is a file tFile
   delete file tFile
end TestRunsAndWhatTheUserIsAsked

-- Code worded so that a reading of its text does not see what it does
-- (here "the shell of", which xtaRiskScan does not know) is asked about
-- all the same
on TestCodeTheScanMissesIsAskedAbout
   local tReply
   TestStart
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with false
   put TestCall("run_code", "{`code`:`get the shell of \`echo mcbtest\``}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "asked, refused, it does not run", TestIsError(tReply) and TestText(tReply) contains "Nothing ran" \
         and mcbTestAsked() contains "run code"
end TestCodeTheScanMissesIsAskedAbout

-- The token is text: the same letters in another case, or a number equal
-- to it as a number, is not it
on TestTheTokenIsComparedAsText
   local tToken, tReply
   TestStart
   put TestToken() into tToken
   TestAssert "there is a token", tToken is not empty
   -- is ignores case here, so ask matchText whether there is a letter
   if matchText(tToken, "[a-z]") then
      put xtaJsonParse(mcbHandleLine("{" & quote & "id" & quote & ":3," & quote & "token" & quote & ":" & quote & toUpper(tToken) & quote & "," & \
            quote & "method" & quote & ":" & quote & "hello" & quote & "}")) into tReply
      TestAssert "the token in capitals is refused", xtaJsonText(xtaJsonMember(tReply, "ok")) is "false"
   end if
   put xtaJsonParse(mcbHandleLine("{" & quote & "id" & quote & ":4," & quote & "token" & quote & ":" & quote & "0" & tToken & quote & "," & \
         quote & "method" & quote & ":" & quote & "hello" & quote & "}")) into tReply
   TestAssert "the token with a 0 before it is refused", xtaJsonText(xtaJsonMember(tReply, "ok")) is "false"
end TestTheTokenIsComparedAsText

-- The file names this process, is the user's alone (off Windows), and is
-- left alone when another IDE has written its own there since
on TestTheFileNamesThisProcessAndIsKeptByItsOwner
   local tInfo, tMode, tOther
   TestStart
   put xtaJsonParse(textDecode(url ("binfile:" & sInfoFile), "UTF-8")) into tInfo
   TestAssert "the file has this process's id", xtaJsonText(xtaJsonMember(tInfo, "pid")) is the processID
   if the platform is "Linux" then
      put word 1 of shell("stat -c %a" && quote & sInfoFile & quote) into tMode
   else if the platform is "MacOS" then
      put word 1 of shell("stat -f %Lp" && quote & sInfoFile & quote) into tMode
   end if
   if tMode is not empty then
      TestAssert "only the user can read it", tMode is "600"
   end if
   put "{" & quote & "protocol" & quote & ":1," & quote & "port" & quote & ":1," & quote & "token" & quote & ":" & quote & "another" & quote & "}" into tOther
   put textEncode(tOther, "UTF-8") into url ("binfile:" & sInfoFile)
   mcbServerStop
   TestAssert "another IDE's file is kept", there is a file sInfoFile
   delete file sInfoFile
end TestTheFileNamesThisProcessAndIsKeptByItsOwner

-- A script too long for read_stack: read in parts, with line numbers and
-- its handlers, and one handler by name
on TestALongScriptIsReadInParts
   local tStack, tScript, tIndex, tReply, tId
   TestStart
   put TestUserStack() into tStack
   repeat with tIndex = 1 to 600
      put "on h" & tIndex & return & "  put" && tIndex && "into tValue -- a comment long enough that 600 of these pass the read_stack cut" & return & "end h" & tIndex & return after tScript
   end repeat
   set the script of button "Go" of tStack to tScript
   put the short id of button "Go" of tStack into tId
   put TestCall("read_stack", "{`stack`:`" & kUserStack & "`,`id`:" & tId & "}") into tReply
   TestAssert "read_stack cuts it, and says how to read the rest", TestText(tReply) contains "more lines left out" and TestText(tReply) contains "read_script"
   put TestCall("read_script", "{`stack`:`" & kUserStack & "`,`id`:" & tId & "}") into tReply
   TestAssert "the first part, numbered, with the handlers", not TestIsError(tReply) and TestText(tReply) contains "1: on h1" \
         and TestText(tReply) contains "- on h600, lines 1798 to 1800" and TestText(tReply) contains "read on with from_line"
   put TestCall("read_script", "{`stack`:`" & kUserStack & "`,`id`:" & tId & ",`from_line`:1795}") into tReply
   TestAssert "the rest", TestText(tReply) contains "1800: end h600" and not (TestText(tReply) contains "read on")
   put TestCall("read_script", "{`stack`:`" & kUserStack & "`,`id`:" & tId & ",`handler`:`H300`}") into tReply
   TestAssert "one handler", TestText(tReply) contains "898: on h300" and TestText(tReply) contains "900: end h300" \
         and not (TestText(tReply) contains "901:")
   put TestCall("make_changes", "{`stack`:`" & kUserStack & "`,`changes`:[{`action`:`set`,`object`:" & tId & \
         ",`script`:`on h1\nend h1\n... (10 more lines left out)`}]}") into tReply
   TestAssert "a cut script is not sent back", TestIsError(tReply) and the number of lines of the script of button "Go" of tStack is 1800
end TestALongScriptIsReadInParts

-- edit_script: a handler replaced, added and deleted, lines replaced only
-- when they read as old_text, a mistake changing nothing, and undo
on TestEditScript
   local tStack, tReply, tId, tCall
   TestStart
   put TestUserStack() into tStack
   set the script of button "Go" of tStack to "on mouseUp" & return & "  beep" & return & "end mouseUp" & return & return & \
         "function twice pX" & return & "  return pX * 2" & return & "end twice"
   put the short id of button "Go" of tStack into tId
   put "{`stack`:`" & kUserStack & "`,`id`:" & tId & "," into tCall
   put TestCall("edit_script", tCall & "`handler`:`twice`,`code`:`function twice pX\n  return pX + pX\nend twice`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "a handler replaced, the rest kept", not TestIsError(tReply) and the script of button "Go" of tStack contains "pX + pX" \
         and line 2 of the script of button "Go" of tStack is "  beep"
   put TestCall("edit_script", tCall & "`handler`:`mouseDown`,`code`:`on mouseDown\n  beep 2\nend mouseDown`}") into tReply
   TestAssert "a handler added at the end", not TestIsError(tReply) and line -3 of the script of button "Go" of tStack is "on mouseDown"
   put TestCall("edit_script", tCall & "`handler`:`mouseUp`,`code`:`on mouseUp\n  put into\nend mouseUp`}") into tReply
   TestAssert "a script that would not compile changes nothing", TestIsError(tReply) and line 2 of the script of button "Go" of tStack is "  beep"
   put TestCall("edit_script", tCall & "`handler`:`mouseUp`,`code`:`on mouseDown\nend mouseDown`}") into tReply
   TestAssert "code that is another handler is refused", TestIsError(tReply)
   put TestCall("edit_script", tCall & "`from_line`:2,`to_line`:2,`old_text`:`  beep 3`,`code`:`  beep 4`}") into tReply
   TestAssert "lines that do not read as old_text are not changed", TestIsError(tReply) and line 2 of the script of button "Go" of tStack is "  beep"
   put TestCall("edit_script", tCall & "`from_line`:2,`to_line`:2,`old_text`:`  beep`,`code`:`  beep 4`}") into tReply
   TestAssert "lines replaced", not TestIsError(tReply) and line 2 of the script of button "Go" of tStack is "  beep 4"
   put TestCall("edit_script", tCall & "`handler`:`twice`,`delete`:true}") into tReply
   TestAssert "a handler deleted", not TestIsError(tReply) and not (the script of button "Go" of tStack contains "twice")
   put TestCall("undo_changes", "{`entry`:1}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "undo puts the script back", not TestIsError(tReply) and the script of button "Go" of tStack contains "return pX * 2" \
         and line 2 of the script of button "Go" of tStack is "  beep"
end TestEditScript

-- check_code gives each problem on a line of its own
on TestCheckCodeGivesOneProblemALine
   local tReply, tLine, tCount
   TestStart
   put TestCall("check_code", "{`code`:`put 1\non x\n  put into\nend x`}") into tReply
   TestDiagnostic TestText(tReply)
   repeat for each line tLine in TestText(tReply)
      if tLine begins with "- " then
         add 1 to tCount
      end if
   end repeat
   TestAssert "two problems, two lines", tCount is 2
end TestCheckCodeGivesOneProblemALine

-- What the user has in front of them: the stack, the selection, the last
-- error the IDE showed them (noted by the bridge's own error hook)
on TestIdeContext
   local tStack, tReply
   TestStart
   put TestUserStack() into tStack
   put TestCall("ide_context") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "the stack the user works on", not TestIsError(tReply) and TestText(tReply) contains ("working on the stack" && quote & kUserStack & quote)
   TestAssert "no error yet", TestText(tReply) contains "no error since the bridge was turned on"
   TestAssert "the hook is in the message path", the long id of stack "org.openxtalk.plugin.mcpbridge-errors" is among the lines of the frontScripts
   -- As the engine sends it on its way to the IDE's debugger
   dispatch "traceError" to button "Go" of tStack with "mouseUp", 4, 7, "219,4,7,frobnicate"
   put TestCall("ide_context") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "the error, and where", TestText(tReply) contains "The last error the IDE showed the user" and TestText(tReply) contains "Go"
   mcbServerStop
   TestAssert "the hook is taken out", there is not a stack "org.openxtalk.plugin.mcpbridge-errors"
end TestIdeContext

on TestSearchScripts
   local tStack, tReply
   TestStart
   put TestUserStack() into tStack
   set the script of button "Go" of tStack to "on mouseUp" & return & "  doThing 1" & return & "end mouseUp" & return & return & \
         "on doThing pCount" & return & "  beep" & return & "end doThing"
   set the script of card 1 of tStack to "on openCard" & return & "  doThing 2" & return & "end openCard"
   put TestCall("search_scripts", "{`text`:`doThing`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "every line, with its handler", not TestIsError(tReply) and TestText(tReply) contains "line 2 (in on mouseUp): doThing 1" \
         and TestText(tReply) contains "line 5 (in on doThing, defines it)" and TestText(tReply) contains "line 2 (in on openCard): doThing 2"
   TestAssert "four lines", TestText(tReply) contains "Found in 4 lines"
   put TestCall("search_scripts", "{`stack`:`" & kUserStack & "`,`text`:`^\\s*BEEP$`,`regex`:true}") into tReply
   TestAssert "a pattern, whatever the case", TestText(tReply) contains "line 6 (in on doThing): beep"
   put TestCall("search_scripts", "{`text`:`(`,`regex`:true}") into tReply
   TestAssert "a pattern that cannot be read", TestIsError(tReply)
   put TestCall("search_scripts", "{`text`:`nowhere at all`}") into tReply
   TestAssert "nothing found", not TestIsError(tReply) and TestText(tReply) contains "No script contains"
end TestSearchScripts

on TestReadStackIsLeanAndReadsSeveral
   local tStack, tReply, tGo, tCard
   TestStart
   put TestUserStack() into tStack
   set the cNote of button "Go" of tStack to "hello"
   put the short id of button "Go" of tStack into tGo
   put the short id of card 1 of tStack into tCard
   put TestCall("read_stack", "{`stack`:`" & kUserStack & "`,`ids`:[" & tGo & "," & tCard & ",99999]}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "both, and the one there is not", not TestIsError(tReply) and TestText(tReply) contains ("button" && quote & "Go" & quote) \
         and TestText(tReply) contains ("card" && quote & "Main" & quote) and TestText(tReply) contains "no card or control with the id 99999"
   TestAssert "custom values, not the defaults", TestText(tReply) contains "cNote: hello" and TestText(tReply) contains "that a new button does not have"
   put TestCall("read_stack", "{`stack`:`" & kUserStack & "`,`id`:" & tGo & ",`all_properties`:true}") into tReply
   TestAssert "every property when asked", TestText(tReply) contains "Properties (those with a short value):"
end TestReadStackIsLeanAndReadsSeveral

on TestLookAtCardWithIds
   local tStack, tReply, tPlain
   TestStart
   put TestUserStack() into tStack
   put TestCall("look_at_card", "{`stack`:`" & kUserStack & "`}") into tReply
   put xtaJsonText(xtaJsonMember(tReply, "image")) into tPlain
   put TestCall("look_at_card", "{`stack`:`" & kUserStack & "`,`labels`:true}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "a picture with the ids drawn", not TestIsError(tReply) and TestText(tReply) contains "with its id" \
         and xtaJsonText(xtaJsonMember(tReply, "image")) is not empty and xtaJsonText(xtaJsonMember(tReply, "image")) is not tPlain
   TestAssert "the stack it was drawn in is gone", there is not a stack "org.openxtalk.plugin.mcpbridge-overlay"
   put TestCall("look_at_card", "{`stack`:`" & kUserStack & "`,`id`:" & the short id of button "Go" of tStack & "}") into tReply
   TestAssert "one control", not TestIsError(tReply) and TestText(tReply) contains ("button" && quote & "Go" & quote)
end TestLookAtCardWithIds

on TestARunThatChangesNothingKeepsNoCheckpoint
   local tStack, tReply
   TestStart
   put TestUserStack() into tStack
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with true
   put TestCall("run_code", "{`where`:`stack`,`stack`:`" & kUserStack & "`,`code`:`put the short name of this stack`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "it ran, and says there is nothing to undo", not TestIsError(tReply) and TestText(tReply) contains "nothing to undo" \
         and not (TestText(tReply) contains "This is change")
   put TestCall("run_code", "{`where`:`stack`,`stack`:`" & kUserStack & "`,`code`:`set the cMark of this stack to 1`}") into tReply
   TestAssert "one that changes it can be undone", TestText(tReply) contains "This is change 1"
end TestARunThatChangesNothingKeepsNoCheckpoint

on TestAMisspeltPropertyGetsTheNearest
   local tReply
   TestStart
   get TestUserStack()
   put TestCall("make_changes", "{`stack`:`" & kUserStack & "`,`changes`:[{`action`:`set`,`object`:`stack`,`properties`:{`titel`:`x`}}]}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "the nearest names", TestIsError(tReply) and TestText(tReply) contains "the nearest properties are" and TestText(tReply) contains "title"
end TestAMisspeltPropertyGetsTheNearest

on TestTheGuideIsTheBridges
   local tReply
   TestStart
   put TestCall("xtalk_guide") into tReply
   TestAssert "its own sections, and the assistant's on the language", TestText(tReply) contains "## 7. Your tools" \
         and TestText(tReply) contains "## 2." and TestText(tReply) contains "## 5." and not (TestText(tReply) contains "<!--") \
         and not (TestText(tReply) contains "Insert Code")
end TestTheGuideIsTheBridges

-- Claude desktop's settings file, with the bridge's entry added and the
-- rest kept as it was written
on TestDesktopConfig
   local tOld, tNew, tParsed
   TestStart
   put mcbDesktopConfigText(empty, "oxt-beyond", "C:\OXT\server.js") into tNew
   put xtaJsonParse(tNew["text"]) into tParsed
   TestAssert "a new file", tNew["problem"] is empty and \
         xtaJsonText(xtaJsonItem(xtaJsonGet(tParsed, "mcpServers/oxt-beyond/args"), 1)) is "C:\OXT\server.js"
   put "{" & quote & "mcpServers" & quote & ": {" & quote & "other" & quote & ": {" & quote & "command" & quote & ": " & quote & "x" & quote & "}," & \
         quote & "oxt-beyond" & quote & ": {" & quote & "command" & quote & ": " & quote & "old" & quote & "}}, " & \
         quote & "globalShortcut" & quote & ": " & quote & "Ctrl+Space" & quote & "}" into tOld
   put mcbDesktopConfigText(tOld, "oxt-beyond", "/opt/server.js") into tNew
   TestDiagnostic tNew["text"]
   put xtaJsonParse(tNew["text"]) into tParsed
   TestAssert "the other server and setting are kept", xtaJsonText(xtaJsonGet(tParsed, "mcpServers/other/command")) is "x" \
         and xtaJsonText(xtaJsonMember(tParsed, "globalShortcut")) is "Ctrl+Space"
   TestAssert "the older entry is replaced", xtaJsonText(xtaJsonGet(tParsed, "mcpServers/oxt-beyond/command")) is "node" \
         and xtaJsonCount(xtaJsonMember(tParsed, "mcpServers")) is 2
   put mcbDesktopConfigText("{" & quote & "theme" & quote & ": 1}", "oxt-beyond", "/opt/server.js") into tNew
   TestAssert "mcpServers added to a file without it", xtaJsonText(xtaJsonGet(xtaJsonParse(tNew["text"]), "mcpServers/oxt-beyond/command")) is "node"
   put mcbDesktopConfigText("{" & quote & "a" & quote & ": ", "oxt-beyond", "/opt/server.js") into tNew
   TestAssert "a broken file is left alone", tNew["problem"] is not empty and tNew["text"] is empty
   -- A package of the bridge in another xTalk's IDE names its bridge file
   put mcbDesktopConfigText(empty, "livecode", "/opt/server.js", "/home/me/.oxt-beyond/mcp-bridge-livecode.json") into tNew
   TestDiagnostic tNew["text"]
   put xtaJsonParse(tNew["text"]) into tParsed
   TestAssert "the bridge file in the entry's env", tNew["problem"] is empty and \
         xtaJsonText(xtaJsonGet(tParsed, "mcpServers/livecode/env/OXT_MCP_BRIDGE_FILE")) is "/home/me/.oxt-beyond/mcp-bridge-livecode.json" \
         and xtaJsonText(xtaJsonGet(tParsed, "mcpServers/livecode/command")) is "node"
   put mcbDesktopConfigText(empty, "oxt-beyond", "/opt/server.js") into tNew
   TestAssert "no env without one", not (tNew["text"] contains "env")
end TestDesktopConfig

on TestSaveIsAskedAbout
   local tReply, tStack, tFile
   TestStart
   put TestUserStack() into tStack
   put specialFolderPath("temporary") & "/mcbtest-" & the milliseconds & ".livecode" into tFile
   set the fileName of tStack to tFile
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with false
   put TestCall("save_stack", "{`stack`:`" & kUserStack & "`}") into tReply
   TestAssert "refused, nothing is saved", TestIsError(tReply) and there is not a file tFile
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with true
   put TestCall("save_stack", "{`stack`:`" & kUserStack & "`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "allowed, it is saved", not TestIsError(tReply) and there is a file tFile
   if there is a file tFile then
      delete file tFile
   end if
end TestSaveIsAskedAbout

-- A real socket from this engine to the bridge in it: the request goes
-- out, the answer comes back as one line
on TestOverASocket
   local tSocket, tStart
   TestStart
   put "127.0.0.1:" & mcbServerPort() into tSocket
   open socket to tSocket
   write textEncode("{" & quote & "id" & quote & ":5," & quote & "token" & quote & ":" & quote & TestToken() & quote & "," & \
         quote & "method" & quote & ":" & quote & "hello" & quote & "}" & numToChar(10), "UTF-8") to socket tSocket
   put empty into sReply
   read from socket tSocket until numToChar(10) with message "TestReplyRead"
   put the milliseconds into tStart
   repeat while sReply is empty and the milliseconds - tStart < 10000
      wait 20 milliseconds with messages
   end repeat
   TestDiagnostic sReply
   TestAssert "one line comes back", the last char of sReply is numToChar(10)
   TestAssert "it is the answer", xtaJsonText(xtaJsonMember(xtaJsonParse(line 1 of textDecode(sReply, "UTF-8")), "ok")) is "true"
   TestAssert "one client", mcbServerClients() is 1
   close socket tSocket
end TestOverASocket

on TestReplyRead pSocket, pData
   put pData into sReply
end TestReplyRead

--------------------------------------------------------------------------------
-- The web IDE's link

private command TestStartLink
   get mcbLinkStart(TestGetIDERepositoryPath() & "/Extensions/org.openxtalk.plugin.xtalkassistant", \
         the long id of stack "mcbTestIDE")
end TestStartLink

-- A call as the web IDE's page hands it on: no token
private function TestLinkCall pTool, pArgumentsJson
   if pArgumentsJson is empty then
      put "{}" into pArgumentsJson
   end if
   replace "`" with quote in pArgumentsJson
   return xtaJsonParse(mcbLinkHandle("{" & quote & "id" & quote & ":9," & quote & "method" & quote & ":" & quote & "call" & quote & "," & \
         quote & "tool" & quote & ":" & quote & pTool & quote & "," & quote & "arguments" & quote & ":" & pArgumentsJson & "}"))
end TestLinkCall

on TestTheLinkAnswersWithoutAToken
   local tReply, tStack
   TestStartLink
   TestAssert "it is on", mcbLinkIsOn()
   TestAssert "no port, no file", mcbServerPort() is empty and there is not a file sInfoFile
   put xtaJsonParse(mcbLinkHandle("{" & quote & "id" & quote & ":1," & quote & "method" & quote & ":" & quote & "hello" & quote & "}")) into tReply
   TestAssert "hello, with no token", xtaJsonText(xtaJsonMember(tReply, "ok")) is "true" \
         and xtaJsonText(xtaJsonMember(tReply, "protocol")) is 1 and xtaJsonText(xtaJsonMember(tReply, "id")) is 1
   put TestUserStack() into tStack
   put TestLinkCall("make_changes", "{`stack`:`" & kUserStack & "`,`changes`:[{`action`:`create`,`kind`:`button`,`name`:`Added`}]}") into tReply
   TestDiagnostic xtaJsonText(xtaJsonMember(tReply, "text"))
   TestAssert "a change is made", not TestIsError(tReply) and there is a button "Added" of tStack
   put TestLinkCall("list_stacks") into tReply
   TestAssert "a reading tool", not TestIsError(tReply) and TestText(tReply) contains kUserStack
   put xtaJsonParse(mcbHandleLine("{" & quote & "id" & quote & ":2," & quote & "method" & quote & ":" & quote & "hello" & quote & "}")) into tReply
   TestAssert "a line from a socket still needs a token", xtaJsonText(xtaJsonMember(tReply, "ok")) is "false"
   put xtaJsonParse(mcbLinkHandle("not json")) into tReply
   TestAssert "not JSON", xtaJsonText(xtaJsonMember(tReply, "ok")) is "false"
   mcbLinkStop
   TestAssert "it is off", not mcbLinkIsOn()
   put mcbLinkHandle("{" & quote & "id" & quote & ":3," & quote & "method" & quote & ":" & quote & "hello" & quote & "}") into tReply
   TestAssert "nothing is answered once stopped", tReply contains (quote & "ok" & quote & ":false") and tReply contains "turned off"
end TestTheLinkAnswersWithoutAToken

on TestTheLinkAndTheServerAreNeverOnTogether
   local tError
   TestStartLink
   try
      TestStart
   catch tError
   end try
   TestAssert "the server does not start while the link is on", tError is not empty and mcbServerPort() is empty
   mcbLinkStop
   put empty into tError
   TestStart
   try
      TestStartLink
   catch tError
   end try
   TestAssert "the link does not start while the server is on", tError is not empty and not mcbLinkIsOn()
   TestAssert "the server is still on", mcbServerPort() is not empty
end TestTheLinkAndTheServerAreNeverOnTogether

on TestTheLinkAsksBeforeARun
   local tReply
   TestStartLink
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with false
   put TestLinkCall("run_code", "{`code`:`put 6 * 7`}") into tReply
   TestAssert "asked, refused, it does not run", TestIsError(tReply) and not (TestText(tReply) contains "42") \
         and mcbTestAsked() contains "run code"
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with true
   put TestLinkCall("run_code", "{`code`:`put 6 * 7`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "allowed, it runs", not TestIsError(tReply) and TestText(tReply) contains "42"
end TestTheLinkAsksBeforeARun

-- The page's connection closed (or was made again) while the user was
-- asked: their yes reaches no one, so nothing runs and they are told
on TestAYesAfterTheLinkWasLostDoesNothing
   local tReply
   TestStartLink
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with "lose"
   put TestLinkCall("run_code", "{`code`:`put 6 * 7`}") into tReply
   TestDiagnostic TestText(tReply)
   TestAssert "nothing ran", TestIsError(tReply) and not (TestText(tReply) contains "42")
   TestAssert "the user was told", mcbTestAsked() contains "too late"
   dispatch "mcbTestSetAnswer" to stack "mcbTestIDE" with true
   put TestLinkCall("run_code", "{`code`:`put 6 * 7`}") into tReply
   TestAssert "the next request, on the new connection, runs", not TestIsError(tReply) and TestText(tReply) contains "42"
end TestAYesAfterTheLinkWasLostDoesNothing
