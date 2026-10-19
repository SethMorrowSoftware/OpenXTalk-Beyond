script "TestXTalkAssistantPlugin"
-- OXT-Beyond: tests of the xTalk Assistant plugin's main stack
-- (ide/Extensions/org.openxtalk.plugin.xtalkassistant/xtalkassistant.livecodescript),
-- loaded as the IDE loads an extension, with a stand-in for the IDE
-- handlers it calls: that it stays off and loads nothing until it is turned
-- on, that the window it builds asks a server of this process (answering as
-- Anthropic does) and shows the answer, that the guide and the user's notes
-- go with every question, that code that does not compile goes back to the
-- model and stops when it compiles or the rounds run out, that the tools
-- the model asks for are carried out and their results sent back, that the
-- error hook notes an error and passes it on, that only xTalk can be
-- inserted, that a note the answer proposes is kept only when the user
-- presses Remember, that the Settings dialog keeps what it says (the key
-- only in memory, never as a preference), that the changes and runs the
-- model asks for are asked about in the window's bar and done only when
-- the user says yes, that Undo takes them back, and that unloading it
-- takes everything away again; that while it works a row under the
-- conversation says what it does and for how long, and Escape stops it;
-- that answers are laid out (headings, lists, code with Copy and Insert),
-- that the model can look at a card and save a stack only when the user
-- says yes; that an answer cut off at its length limit is asked for again
-- with more room, and one that cannot be, or that the provider stopped on
-- safety grounds, says why it ends there and has none of its calls carried
-- out. The other dialogs (turning it on, errors,
-- the Memory window, Undo All's question), the Settings dialog's modal
-- loop and the Script Editor are not reached here: they need the IDE.
-- The window's bar is answered as the user would, by clicking its
-- buttons (TestAnswerAsks).

constant kMain = "org.openxtalk.plugin.xtalkassistant"
constant kWindow = "revXTalkAssistant"
constant kCore = "org.openxtalk.plugin.xtalkassistant-core"
constant kErrorHook = "org.openxtalk.plugin.xtalkassistant-errors"
constant kSettings = "revXTalkAssistantSettings"

-- The test server's answers (keys 1 to N, one for each request, the last
-- for any after it), how many requests it has read, the latest request, and
-- every request by number
local sResponses, sServed, sRequest, sRequests
-- The preferences folder of the stand-in IDE
local sPrefsFolder
-- The answers still to give in the window's bar, and what it asked
-- (TestAnswerAsks)
local sAnswers, sAsked
-- What the window showed while a request was on its way (by request, then
-- "asked", "escaped" and "answered": TestNoteTheWindow); how long the
-- server waits before it answers, the answers it holds meanwhile, and
-- whether it presses Escape in the window when a request comes
local sDuring, sDelay, sPending, sPressEscape
-- The angles the spinner was seen at (xtaTestSample)
local sAngles
-- The request at which the server turns the pictures switch off, as the
-- user does in the Settings while the model answers (0: none)
local sPicturesOffAt

on TestSetup
   local tLibUrl, tStub
   put specialFolderPath("temporary") & "/xta-test-prefs-" & the milliseconds into sPrefsFolder
   create folder sPrefsFolder
   if not TestIsInStandalone() then
      put TestGetEngineRepositoryPath() & "/ide-support/revliburl.livecodescript" into tLibUrl
      send "extensionInitialize" to stack tLibUrl
   end if
   -- The IDE's handlers the plugin calls: the preferences, kept in memory
   -- here so that a test can read them all, and no Script Editor
   put "local sPrefs, sSaved" & return & \
         "function revIDEGetPreference pName" & return & "return sPrefs[pName]" & return & "end revIDEGetPreference" & return & \
         "on revIDESetPreference pName, pValue" & return & "put pValue into sPrefs[pName]" & return & "end revIDESetPreference" & return & \
         "function xtaTestPrefs" & return & "return sPrefs" & return & "end xtaTestPrefs" & return & \
         "function revTopMostScriptEditor" & return & "return empty" & return & "end revTopMostScriptEditor" & return & \
         "function revEnvironmentUserPreferencesPath" & return & "return " & quote & sPrefsFolder & quote & return & \
         "end revEnvironmentUserPreferencesPath" & return into tStub
   -- File > Save: a stack with a file is saved to it; for one never saved
   -- the user cancels the dialog that asks where
   put "on revIDEActionSaveStack pStack" & return & "put pStack & return after sSaved" & return & \
         "if the effective filename of pStack is empty then" & return & "return `Cancelled`" & return & "end if" & return & \
         "save pStack" & return & "end revIDEActionSaveStack" & return & \
         "function xtaTestSaved" & return & "return sSaved" & return & "end xtaTestSaved" & return after tStub
   -- The Dictionary, with one entry
   put "function ideDocsFetchLCSData pTerm" & return & "local tData" & return & "if pTerm is `put` then" & return & \
         "put `put` into tData[1][`display name`]" & return & "put `command` into tData[1][`Type`]" & return & \
         "put `Places a value into a container.` into tData[1][`Summary`]" & return & \
         "put `put <value> into <container>` into tData[1][`Syntax`][1]" & return & \
         "end if" & return & "return tData" & return & "end ideDocsFetchLCSData" after tStub
   replace "`" with quote in tStub
   create invisible stack "xtaTestIDE"
   set the script of stack "xtaTestIDE" to tStub
   start using stack "xtaTestIDE"
   put empty into $OXTBEYOND_XTALK_ASSISTANT
   put empty into $ANTHROPIC_API_KEY
   put empty into $OPENAI_API_KEY
   -- As revInternal__LoadLibrary loads an extension: the stack is loaded
   -- and sent extensionInitialize, and is not put in the message path
   get the short name of stack (TestGetIDERepositoryPath() & "/Extensions/org.openxtalk.plugin.xtalkassistant/xtalkassistant.livecodescript")
   send "extensionInitialize" to stack kMain
end TestSetup

on TestTeardown
   if there is a file (sPrefsFolder & "/xTalk Assistant Memory.txt") then
      delete file (sPrefsFolder & "/xTalk Assistant Memory.txt")
   end if
   if there is a folder sPrefsFolder then
      delete folder sPrefsFolder
   end if
end TestTeardown

private function TestIsEnabled
   dispatch function "xtaIsEnabled" to stack kMain
   return the result
end TestIsEnabled

on TestOffByDefault
   TestAssert "off until it is turned on", TestIsEnabled() is false
   TestAssert "not in the message path", not (kMain is among the lines of the stacksInUse)
   TestAssert "the core is not loaded", there is not a stack kCore
   TestAssert "no window", there is not a stack kWindow
   revIDESetPreference "cXTalkAssistant,enabled", true
   TestAssert "on once it is turned on", TestIsEnabled() is true
   put "off" into $OXTBEYOND_XTALK_ASSISTANT
   TestAssert "kept off by the environment", TestIsEnabled() is false
   put empty into $OXTBEYOND_XTALK_ASSISTANT
end TestOffByDefault

on TestOpenWindow
   local tFill
   TestOpenTheWindow "http://127.0.0.1:1"
   TestAssert "the window is built", there is a stack kWindow
   -- It is built invisible, so it must be shown when it opens (0.2.5-rc.2
   -- left it hidden, and turning the assistant on seemed to do nothing)
   TestAssert "the window is shown", the visible of stack kWindow
   TestAssert "the window is a palette", the mode of stack kWindow is 4
   TestDiagnostic the rect of stack kWindow && "/" && the screenRect && "/" && the working screenRect
   -- In the middle of the screen, unless that would leave part of it (its
   -- title bar too) off a small screen: then it is kept whole on the screen
   TestAssert "the window is in the middle of the screen, or whole on it", \
         the loc of stack kWindow is the screenLoc \
         or TestWithin(the rect of stack kWindow, the working screenRect)
   TestAssert "the core is in use", kCore is among the lines of the stacksInUse
   TestAssert "the provider is shown", the label of button "Provider" of stack kWindow is "Anthropic"
   TestAssert "the model is shown", the label of button "Model" of stack kWindow is "test-model"
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "the key from the environment is used", field "Status" of stack kWindow contains "from the environment"
   TestAssert "nothing to insert yet", not the enabled of button "Insert" of stack kWindow
   -- Learn's look: its page, the dark header with the mark and the title,
   -- the status line under it, the conversation on a panel, the prompt
   -- above the footer, flat buttons, and a window that fits a 720p screen
   TestAssert "Learn's page", the backgroundColor of this card of stack kWindow is "241,245,249"
   -- (the header is a gradient, from Learn's dark slate)
   put the fillGradient of graphic "uiBand" of stack kWindow into tFill
   TestDiagnostic tFill["ramp"]
   TestAssert "the dark header, with the mark and the title", item 2 to 4 of line 1 of tFill["ramp"] is "15,23,42" \
         and there is a graphic "uiMark" of stack kWindow \
         and word 1 to -1 of field "uiTitle" of stack kWindow is "xTalk Assistant"
   TestAssert "Send is filled with the accent, New Chat is a chip", the backgroundColor of button "Send" of stack kWindow is "124,58,237" \
         and the backgroundColor of button "New" of stack kWindow is "226,232,240"
   TestDiagnostic the rect of field "Status" of stack kWindow && "/" && the rect of button "Provider" of stack kWindow
   TestAssert "the status line under the band, above the settings", item 2 of the rect of field "Status" of stack kWindow >= 30 \
         and item 4 of the rect of field "Status" of stack kWindow <= item 2 of the rect of button "Provider" of stack kWindow
   TestAssert "the pill says it is ready", field "Pill" of stack kWindow is "Ready" \
         and the backgroundColor of graphic "PillBg" of stack kWindow is "209,250,229"
   TestAssert "the conversation is on its panel", TestWithin(the rect of field "Conversation" of stack kWindow, \
         the rect of graphic "ConversationPanel" of stack kWindow)
   TestDiagnostic the rect of field "Prompt" of stack kWindow && "/" && the rect of field "uiFooter" of stack kWindow
   TestAssert "the prompt is laid out above the footer", \
         item 4 of the rect of field "Prompt" of stack kWindow <= item 2 of the rect of field "uiFooter" of stack kWindow \
         and item 4 of the rect of field "Prompt" of stack kWindow > item 2 of the rect of field "Prompt" of stack kWindow \
         and item 2 of the rect of field "Prompt" of stack kWindow >= item 4 of the rect of graphic "ConversationPanel" of stack kWindow
   TestAssert "the bar that asks is hidden", not the visible of graphic "AskPanel" of stack kWindow \
         and not the visible of button "AskYes" of stack kWindow
   TestAssert "the footer says nothing changes unasked", field "uiFooter" of stack kWindow begins with "Nothing changes or runs until you say yes"
   TestAssert "it fits a 720p screen", the width of stack kWindow <= 1200 and the height of stack kWindow <= 640
end TestOpenWindow

-- True when the rect pInner is inside the rect pOuter
private function TestWithin pInner, pOuter
   return item 1 of pInner >= item 1 of pOuter and item 2 of pInner >= item 2 of pOuter \
         and item 3 of pInner <= item 3 of pOuter and item 4 of pInner <= item 4 of pOuter
end TestWithin

on TestAskThroughTheWindow
   local tPort, tAnswer, tPrefs, tValue, tFound
   put "Here it is:" & return & "```livecodescript" & return & "on mouseUp" & return & \
         "   beep" & return & "end mouseUp" & return & "```" into tAnswer
   put TestStartServer("200 OK", "{" & TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & \
         TestQ("text") & ":" & TestQ(tAnswer) & "}]," & TestQ("stop_reason") & ":" & TestQ("end_turn") & "," & \
         TestQ("usage") & ":{" & TestQ("input_tokens") & ":12," & TestQ("output_tokens") & ":34}}") into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Write a mouseUp handler that beeps" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sRequest
   TestAssert "asked the provider", sRequest begins with "POST /v1/messages HTTP/1.1"
   TestAssert "with the key from the environment", TestRequestHeader("x-api-key") is "sk-from-env"
   TestAssert "the question was sent", TestRequestBody() contains "Write a mouseUp handler that beeps"
   TestAssert "no script was attached (no Script Editor is open)", not (TestRequestBody() contains "The script I am editing")
   TestDiagnostic field "Conversation" of stack kWindow
   TestAssert "the answer is shown", field "Conversation" of stack kWindow contains "end mouseUp"
   TestAssert "who asked, in bold", line 1 of field "Conversation" of stack kWindow is "You" \
         and the textStyle of line 1 of field "Conversation" of stack kWindow is "bold"
   TestAssert "who answered, in bold", line 4 of field "Conversation" of stack kWindow is "xTalk Assistant" \
         and the textStyle of line 4 of field "Conversation" of stack kWindow is "bold"
   TestAssert "a line of the answer is not bold", the textStyle of line 5 of field "Conversation" of stack kWindow is not "bold"
   TestAssert "the prompt is cleared", field "Prompt" of stack kWindow is empty
   TestAssert "the code can be inserted", the enabled of button "Insert" of stack kWindow
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "the tokens are shown", field "Status" of stack kWindow contains "12 tokens in, 34 out"
   TestAssert "and what the answer took, under it", line -1 of field "Conversation" of stack kWindow contains "1 request" \
         and line -1 of field "Conversation" of stack kWindow contains "12 tokens in, 34 out"

   -- The key is never a preference
   put xtaTestPrefs() into tPrefs
   put false into tFound
   repeat for each element tValue in tPrefs
      if tValue contains "sk-from-env" then
         put true into tFound
      end if
   end repeat
   TestAssert "the key is not in the preferences", not tFound

   dispatch "xtaNewConversation" to stack kMain
   TestDiagnostic field "Conversation" of stack kWindow
   TestAssert "a new conversation, with the welcome", line 1 of field "Conversation" of stack kWindow is "What shall we make?" \
         and not ("You" is among the lines of field "Conversation" of stack kWindow) \
         and not (field "Conversation" of stack kWindow contains "end mouseUp")
   TestAssert "nothing to insert", not the enabled of button "Insert" of stack kWindow
end TestAskThroughTheWindow

-- While the assistant works, a row at the foot of the conversation says
-- what it does and for how long, its spinner turns, and the pill says it
-- is thinking; once it has answered the row goes, and the status line and
-- the conversation say what the answer took
on TestTheActivityRowWhileItWorks
   local tPort, tStatus
   put TestStartServer("200 OK", TestAnswer("Hello.")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   TestAssert "no row before a question", not the visible of field "Activity" of stack kWindow \
         and not the visible of graphic "ActivitySpin" of stack kWindow
   -- The server takes its time, as a model does, and the spinner is
   -- looked at meanwhile
   put 1600 into sDelay
   put empty into sAngles
   send "xtaTestSample" to me in 100 milliseconds
   put "Hi" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sDuring[1]["asked"]["activity"] && "/" && sDuring[1]["asked"]["status"] && "/" && \
         sDuring[1]["answered"]["time"] && "/" && the keys of sAngles
   TestAssert "the row shows while it waits", sDuring[1]["asked"]["shown"] is true
   TestAssert "saying what it waits for", sDuring[1]["asked"]["activity"] is "Waiting for test-model"
   TestAssert "the pill says it is thinking", sDuring[1]["asked"]["pill"] is "Thinking"
   TestAssert "the status line says whom it asks", sDuring[1]["asked"]["status"] is ("Asking test-model (127.0.0.1:" & tPort & ")")
   TestAssert "Send is Stop", sDuring[1]["asked"]["send"] is "Stop"
   -- How far the clock got by then depends on how fast the computer is
   -- (the tests run four at a time in CI): only that it went on is asked
   TestAssert "the clock reads minutes and seconds", matchText(sDuring[1]["asked"]["time"], "^[0-9]+:[0-5][0-9]$") \
         and matchText(sDuring[1]["answered"]["time"], "^[0-9]+:[0-5][0-9]$")
   TestAssert "and goes on while it waits", TestClockSeconds(sDuring[1]["asked"]["time"]) < TestClockSeconds(sDuring[1]["answered"]["time"])
   TestAssert "and the spinner turns", the number of elements of sAngles >= 3
   TestAssert "the row goes once it has answered", not the visible of field "Activity" of stack kWindow \
         and not the visible of graphic "ActivitySpin" of stack kWindow and not the visible of field "ActivityTime" of stack kWindow
   TestDiagnostic the rect of field "Conversation" of stack kWindow && "/" && the rect of graphic "ConversationPanel" of stack kWindow
   TestAssert "and the conversation has its room again", \
         item 4 of the rect of field "Conversation" of stack kWindow is (item 4 of the rect of graphic "ConversationPanel" of stack kWindow) - 6
   TestAssert "the pill is ready again", field "Pill" of stack kWindow is "Ready"
   put field "Status" of stack kWindow into tStatus
   TestDiagnostic tStatus
   -- At least the 1.6 s the server held its answer
   TestAssert "the status line says what it took", tStatus begins with "Answered in " and word 3 of tStatus is a number \
         and word 3 of tStatus >= 1.6 and word 4 of tStatus is "s" and tStatus contains "1 request" \
         and tStatus contains "10 tokens in, 20 out (5000 read from the cache)"
   TestAssert "and so does the conversation, under the answer", line -1 of field "Conversation" of stack kWindow begins with (word 3 of tStatus && "s") \
         and the textSize of line -1 of field "Conversation" of stack kWindow is 10
end TestTheActivityRowWhileItWorks

-- Escape stops the assistant while it answers, as Stop does: the tools
-- the answer then asks for are not used. With nothing to stop, the key
-- goes on.
on TestEscapeStopsIt
   local tPort, tCalls
   put "last_error" into tCalls[1]["name"]
   put "{}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Done.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   dispatch "xtaEscape" to stack kMain
   TestAssert "nothing to stop: the key goes on", the result is false
   put true into sPressEscape
   put "What went wrong?" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sDuring[1]["escaped"]["status"] && "/" && sDuring[1]["escaped"]["activity"]
   TestAssert "Escape asks it to stop", sDuring[1]["escaped"]["status"] begins with "Stopping after the answer" \
         and sDuring[1]["escaped"]["activity"] begins with "Stopping after the answer"
   TestAssert "asked once", sServed is 1
   TestDiagnostic field "Conversation" of stack kWindow
   TestAssert "the tool was not used", "Did not use last_error: you pressed Stop" is among the lines of field "Conversation" of stack kWindow
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "the status line says it was stopped", field "Status" of stack kWindow contains "you stopped it"
   TestAssert "Send is Send again", the label of button "Send" of stack kWindow is "Send" and the enabled of button "Send" of stack kWindow
   TestAssert "and the row is gone", not the visible of field "Activity" of stack kWindow
end TestEscapeStopsIt

-- With no conversation, the window welcomes the user, with questions to
-- begin with: one clicked goes into the prompt, to send or change
on TestTheWelcome
   local tText, tLine
   TestOpenTheWindow "http://127.0.0.1:1"
   put field "Conversation" of stack kWindow into tText
   TestDiagnostic tText
   TestAssert "it welcomes the user", line 1 of tText is "What shall we make?" \
         and the textStyle of line 1 of field "Conversation" of stack kWindow is "bold"
   TestAssert "saying what the assistant does", tText contains "new stacks" and tText contains "Nothing changes until you say yes."
   TestAssert "naming the language as OXT-Beyond does", tText contains "xTalk Script" and not (tText contains "LiveCode")
   put lineOffset("Try one of these:", tText) into tLine
   TestAssert "with questions to begin with", tLine > 0 \
         and the linkText of line tLine + 1 of field "Conversation" of stack kWindow is "example,1" \
         and the textStyle of line tLine + 1 of field "Conversation" of stack kWindow is "link" \
         and the linkText of line tLine + 4 of field "Conversation" of stack kWindow is "example,4"
   TestAssert "and how to send and stop", tText contains "Escape stops the assistant."
   TestAssert "the empty prompt says what to type", the visible of field "PromptHint" of stack kWindow \
         and line 1 of field "PromptHint" of stack kWindow is "Ask a question, or say what to build or fix" \
         and line 2 of field "PromptHint" of stack kWindow ends with "sends"
   dispatch "xtaConversationLink" to stack kMain with "example,2"
   TestAssert "a question clicked goes into the prompt", field "Prompt" of stack kWindow is line tLine + 2 of tText
   TestAssert "and the hint goes", not the visible of field "PromptHint" of stack kWindow
   -- Without changing stacks, the welcome and its questions only ask
   put empty into field "Prompt" of stack kWindow
   revIDESetPreference "cXTalkAssistant,build", false
   dispatch "xtaNewConversation" to stack kMain
   put field "Conversation" of stack kWindow into tText
   TestDiagnostic tText
   TestAssert "without changing stacks, it does not offer to", not (tText contains "new stacks") \
         and "How do I count the words in a field?" is among the lines of tText
   TestAssert "nor does the hint", line 1 of field "PromptHint" of stack kWindow is "Ask a question about xTalk Script" \
         and the visible of field "PromptHint" of stack kWindow
   TestAssert "and neither names LiveCode", tText contains "xTalk Script" and not (tText contains "LiveCode")
end TestTheWelcome

on TestGuideAndNotesAreSent
   local tPort, tDoc, tSystem, tBody
   put "# memory" & return & "[you]" & return & "- Builds for Linux only." & return into url ("file:" & sPrefsFolder & "/xTalk Assistant Memory.txt")
   put TestStartServer("200 OK", TestAnswer("Hello.")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Hi" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   put TestRequestBody() into tBody
   put xtaJsonParse(tBody) into tDoc
   put xtaJsonMember(tDoc, "system") into tSystem
   TestAssert "the guide goes first", xtaJsonText(xtaJsonGet(tSystem, "1/text")) begins with "# The xTalk Assistant's guide"
   TestAssert "marked for the cache", xtaJsonText(xtaJsonGet(tSystem, "1/cache_control/type")) is "ephemeral"
   TestAssert "then the user's notes", xtaJsonText(xtaJsonGet(tSystem, "2/text")) contains "- Builds for Linux only."
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "what the cache saved is shown", field "Status" of stack kWindow contains "5000 read from the cache"
   TestAssert "the tools go with it", xtaJsonCount(xtaJsonMember(tDoc, "tools")) is 9 \
         and xtaJsonText(xtaJsonGet(tDoc, "tools/1/name")) is "lookup_dictionary" \
         and xtaJsonText(xtaJsonGet(tDoc, "tools/6/name")) is "make_changes" \
         and xtaJsonText(xtaJsonGet(tDoc, "tools/7/name")) is "run_code" \
         and xtaJsonText(xtaJsonGet(tDoc, "tools/8/name")) is "look_at_card" \
         and xtaJsonText(xtaJsonGet(tDoc, "tools/9/name")) is "save_stack"

   -- The short guide, for a small model, and no tools
   dispatch "xtaMoreMenuPick" to stack kMain with "Short Guide, No Tools (for small local models)"
   TestAssert "is ticked in the menu", "!cShort Guide, No Tools (for small local models)" is among the lines of the text of button "More" of stack kWindow
   put "Hi again" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   put xtaJsonParse(TestRequestBody()) into tDoc
   TestAssert "the short guide is sent instead", xtaJsonText(xtaJsonGet(tDoc, "system/1/text")) begins with "You are the xTalk Assistant"
   TestAssert "with no tools", xtaJsonType(xtaJsonMember(tDoc, "tools")) is "missing"
end TestGuideAndNotesAreSent

-- With one of the IDE's windows in front of the user's stack, the notes
-- about that stack still go with the question
on TestNotesOfTheStackBehindAnIDEWindow
   local tPort, tPath, tDoc
   put sPrefsFolder & "/xtaTestWork.livecode" into tPath
   put "[stack" && tPath & "]" & return & "- The log is in field Log." & return into url ("file:" & sPrefsFolder & "/xTalk Assistant Memory.txt")
   put TestStartServer("200 OK", TestAnswer("Hello.")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   create stack "xtaTestWork"
   set the filename of stack "xtaTestWork" to tPath
   save stack "xtaTestWork"
   go stack "xtaTestWork"
   create stack "revXtaTestFront"
   go stack "revXtaTestFront"
   TestDiagnostic "topStack:" && the short name of the topStack & return & "openStacks:" && the openStacks
   TestAssert "an IDE window is in front", the short name of the topStack is "revXtaTestFront"
   put "Hi" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   put xtaJsonParse(TestRequestBody()) into tDoc
   TestDiagnostic xtaJsonText(xtaJsonGet(tDoc, "system/2/text"))
   TestAssert "the notes about the stack behind it go with the question", \
         xtaJsonText(xtaJsonGet(tDoc, "system/2/text")) contains "The log is in field Log."
   delete stack "revXtaTestFront"
   delete stack "xtaTestWork"
   delete file tPath
end TestNotesOfTheStackBehindAnIDEWindow

on TestCodeThatDoesNotCompileGoesBack
   local tPort, tBad, tGood, tBody
   put "Here:" & return & TestBlock("livecodescript", "on mouseUp" & return & "   put 1 inot tX" & return & "end mouseUp") into tBad
   put "Fixed:" & return & TestBlock("livecodescript", "on mouseUp" & return & "   beep" & return & "end mouseUp") into tGood
   put TestStartServer("200 OK", TestAnswer(tBad)) into tPort
   TestQueueAnswer "200 OK", TestAnswer(tGood)
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Write a mouseUp handler" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked twice", sServed is 2
   put TestBodyOf(sRequests[2]) into tBody
   TestDiagnostic tBody
   TestAssert "the second time with the errors", tBody contains "Compile check:" and tBody contains "line 2, column 8"
   TestAssert "after the first answer", tBody contains "inot"
   TestDiagnostic field "Conversation" of stack kWindow
   TestAssert "the check is shown as a turn", "Compile check" is among the lines of field "Conversation" of stack kWindow
   TestAssert "the corrected answer is shown", field "Conversation" of stack kWindow contains "Fixed:"
   TestAssert "and that it compiles", "Compile check: the code compiles." is among the lines of field "Conversation" of stack kWindow
   TestAssert "the tokens of both rounds", field "Status" of stack kWindow contains "20 tokens in, 40 out"
   TestAssert "the corrected code can be inserted", the enabled of button "Insert" of stack kWindow
   TestAssert "Send is Send again", the label of button "Send" of stack kWindow is "Send"
end TestCodeThatDoesNotCompileGoesBack

on TestFixRoundsRunOut
   local tPort, tBad
   put TestBlock("livecodescript", "on mouseUp" & return & "   put 1 inot tX" & return & "end mouseUp") into tBad
   put TestStartServer("200 OK", TestAnswer(tBad)) into tPort
   TestQueueAnswer "200 OK", TestAnswer(TestBlock("livecodescript", "on mouseUp" & return & "   put 2 inot tX" & return & "end mouseUp"))
   TestQueueAnswer "200 OK", TestAnswer(TestBlock("livecodescript", "on mouseUp" & return & "   put 3 inot tX" & return & "end mouseUp"))
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   revIDESetPreference "cXTalkAssistant,fixRounds", 2
   put "Write a mouseUp handler" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "two rounds of corrections at most", sServed is 3
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "the status says the code does not compile", field "Status" of stack kWindow contains "does not compile"

   -- The same code again ends it at once
   put TestStartServer("200 OK", TestAnswer(tBad)) into tPort
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", "http://127.0.0.1:" & tPort
   revIDESetPreference "cXTalkAssistant,fixRounds", 5
   put "Again" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "the same code twice is not sent back again", sServed is 2

   -- No rounds: checked, and nothing sent back
   put TestStartServer("200 OK", TestAnswer(tBad)) into tPort
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", "http://127.0.0.1:" & tPort
   revIDESetPreference "cXTalkAssistant,fixRounds", 0
   put "Once more" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "no rounds: asked once", sServed is 1
   TestAssert "and the check is shown", line -2 of field "Conversation" of stack kWindow begins with "Compile check: the code does not compile"
end TestFixRoundsRunOut

on TestOnlyXTalkIsInserted
   local tPort, tText, tAt
   put TestStartServer("200 OK", TestAnswer(TestBlock("livecodescript", "on mouseUp" & return & "   beep" & return & "end mouseUp"))) into tPort
   TestQueueAnswer "200 OK", TestAnswer("In Python:" & return & TestBlock("python", "print(1)") & return & \
         TestBlock("livecodebuilder", "public handler f()" & return & "end handler"))
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Beep" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "code to insert", the enabled of button "Insert" of stack kWindow
   put "Print 1" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked once more (other languages are not compiled)", sServed is 2
   TestAssert "nothing to insert from the latest answer", not the enabled of button "Insert" of stack kWindow
   put field "Conversation" of stack kWindow into tText
   TestDiagnostic tText
   put lineOffset("Print 1", tText) into tAt
   TestAssert "the code of the latest answer is shown", tAt > 0 and line tAt to -1 of tText contains "print(1)" \
         and line tAt to -1 of tText contains "end handler"
   TestAssert "no compile check is shown for it", not (line tAt to -1 of tText contains "Compile check")
end TestOnlyXTalkIsInserted

-- An answer is laid out as its Markdown says: a heading, bold, italics,
-- `code`, a list and a link; each block of code under a header that names
-- its language, with Copy, and Insert for xTalk alone
on TestAnAnswerIsLaidOut
   local tPort, tAnswer, tText, tLine, tHeader, tClipboard
   put "## Counting words" & return & return & \
         "Use **the number of words** of a field, and `put` the count:" & return & return & \
         "- one *line*" & return & "- two" & return & return & \
         TestBlock("livecodescript", "on mouseUp" & return & "   put the number of words of field 1 into field 2" & return & "end mouseUp") & return & return & \
         "In Python it is:" & return & return & TestBlock("python", "len(s.split())") & return & return & \
         "See [the Dictionary](https://example.com/dict)." into tAnswer
   put TestStartServer("200 OK", TestAnswer(tAnswer)) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "How do I count words?" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   put field "Conversation" of stack kWindow into tText
   TestDiagnostic tText
   put lineOffset("Counting words", tText) into tLine
   TestAssert "the heading, bold and larger", tLine > 0 and line tLine of tText is "Counting words" \
         and the textStyle of line tLine of field "Conversation" of stack kWindow is "bold" \
         and the textSize of line tLine of field "Conversation" of stack kWindow > 12
   TestAssert "no Markdown marks are left", not (tText contains "**") and not (tText contains "## ") and not (tText contains "`")
   put lineOffset("Use the number of words", tText) into tLine
   TestAssert "bold", tLine > 0 and the textStyle of word 2 to 5 of line tLine of field "Conversation" of stack kWindow is "bold"
   TestAssert "code in the text, in the code's face", \
         the textFont of word 10 of line tLine of field "Conversation" of stack kWindow is not empty \
         and the textFont of word 1 of line tLine of field "Conversation" of stack kWindow is empty
   put lineOffset("one line", tText) into tLine
   TestAssert "a list, with italics", tLine > 0 and the listStyle of line tLine of field "Conversation" of stack kWindow is "disc" \
         and the textStyle of word 2 of line tLine of field "Conversation" of stack kWindow is "italic"
   put lineOffset("xTalk Script", tText) into tHeader
   TestAssert "the code has a header that names it", tHeader > 0 and line tHeader + 1 of tText is "on mouseUp" \
         and word 1 to 2 of line tHeader of tText is "xTalk Script"
   TestAssert "as OXT-Beyond names it, though the block is marked livecodescript", not (tText contains "LiveCode")
   TestAssert "with Copy and Insert", word -2 of line tHeader of tText is "Copy" and word -1 of line tHeader of tText is "Insert" \
         and the linkText of word -2 of line tHeader of field "Conversation" of stack kWindow is "copy,2,1" \
         and the linkText of word -1 of line tHeader of field "Conversation" of stack kWindow is "insert,2,1"
   TestAssert "its lines in the code's face", the textFont of line tHeader + 1 of field "Conversation" of stack kWindow is not empty
   TestAssert "xTalk in Learn's colours", the foregroundColor of word 1 of line tHeader + 1 of field "Conversation" of stack kWindow is "196,181,253" \
         and the foregroundColor of word 2 of line tHeader + 1 of field "Conversation" of stack kWindow is "226,232,240"
   put 0 into tHeader
   repeat with tLine = 1 to the number of lines of tText
      if word 1 of line tLine of tText is "Python" then
         put tLine into tHeader
      end if
   end repeat
   TestAssert "other languages: Copy alone", tHeader > 0 and word -1 of line tHeader of tText is "Copy" \
         and the linkText of word -1 of line tHeader of field "Conversation" of stack kWindow is "copy,2,2" \
         and line tHeader + 1 of tText is "len(s.split())"
   put lineOffset("See the Dictionary.", tText) into tLine
   TestAssert "a link", tLine > 0 and the linkText of word 2 of line tLine of field "Conversation" of stack kWindow is "url,https://example.com/dict" \
         and the textStyle of word 2 of line tLine of field "Conversation" of stack kWindow is "link"
   TestAssert "the compile check after it", "Compile check: the code compiles." is among the lines of tText

   -- Copy puts the code on the clipboard, where the clipboard can be read
   -- (not in the tests' headless runs on Linux)
   put TestClipboardWorks() into tClipboard
   dispatch "xtaConversationLink" to stack kMain with "copy,2,1"
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "Copy says it copied", field "Status" of stack kWindow is "Copied the code to the clipboard."
   if tClipboard then
      TestAssert "the code is on the clipboard", the clipboardData["text"] is \
            ("on mouseUp" & return & "   put the number of words of field 1 into field 2" & return & "end mouseUp")
   end if
   -- An Insert over code that is not xTalk does nothing, and a link to a
   -- block that is not there either
   dispatch "xtaConversationLink" to stack kMain with "insert,2,2"
   dispatch "xtaConversationLink" to stack kMain with "copy,2,9"
   TestAssert "nothing else is copied", field "Status" of stack kWindow is "Copied the code to the clipboard."
end TestAnAnswerIsLaidOut

on TestNotesToRemember
   local tPort, tMemory, tLine, tFound
   put TestStartServer("200 OK", TestAnswer("Noted." & return & TestBlock("memory", "you: Builds for Windows only." & return & "you: Likes short answers."))) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "I only build for Windows" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic field "Conversation" of stack kWindow
   TestAssert "the memory block is not shown", not (field "Conversation" of stack kWindow contains "```memory")
   put 0 into tFound
   repeat with tLine = 1 to the number of lines of field "Conversation" of stack kWindow
      if line tLine of field "Conversation" of stack kWindow begins with "Note to keep about you: Builds for Windows only." then
         put tLine into tFound
      end if
   end repeat
   TestAssert "the note is shown", tFound > 0
   TestAssert "with Remember and Dismiss as links", the textStyle of the last word of line tFound of field "Conversation" of stack kWindow is "link" \
         and the linkText of word -2 of line tFound of field "Conversation" of stack kWindow is "remember,2,1"
   TestAssert "nothing is kept yet", there is not a file (sPrefsFolder & "/xTalk Assistant Memory.txt")

   dispatch "xtaNoteClicked" to stack kMain with "remember,2,1"
   put xtaMemoryLoad(sPrefsFolder & "/xTalk Assistant Memory.txt") into tMemory
   TestAssert "Remember keeps it", tMemory["you"] is "Builds for Windows only."
   TestAssert "and says so", field "Conversation" of stack kWindow contains "Remembered about you: Builds for Windows only."
   dispatch "xtaNoteClicked" to stack kMain with "dismiss,2,2"
   TestAssert "Dismiss drops it", not (field "Conversation" of stack kWindow contains "Likes short answers")
   put xtaMemoryLoad(sPrefsFolder & "/xTalk Assistant Memory.txt") into tMemory
   TestAssert "and keeps nothing", tMemory["you"] is "Builds for Windows only."
   dispatch "xtaNoteClicked" to stack kMain with "remember,2,2"
   put xtaMemoryLoad(sPrefsFolder & "/xTalk Assistant Memory.txt") into tMemory
   TestAssert "a dismissed note cannot be kept after all", tMemory["you"] is "Builds for Windows only."
end TestNotesToRemember

-- Models fills the model menu and, with no model chosen yet, chooses the
-- one the provider's list suggests (0.2.5-rc.3 chose none, and Send only
-- said to choose one)
-- Opened with no model chosen (as after 0.2.5-rc.3, whose window stayed
-- with an empty model menu), the window asks for the models and chooses
-- one; before that the menu offers the suggested ones
on TestModelsChoosesAModel
   local tPort, tPrefs
   TestOpenTheWindow "http://127.0.0.1:1"
   TestAssert "the suggested models before the list", the text of button "Model" of stack kWindow is \
         ("claude-sonnet-5-5" & return & "claude-opus-5-5" & return & "claude-haiku-5-5" & return & "claude-fable-5-1")
   put TestStartServer("200 OK", TestModelList()) into tPort
   TestOpenTheWindowWithoutAModel "http://127.0.0.1:" & tPort
   TestDiagnostic sRequest
   TestAssert "asked for the models", sServed is 1 and sRequest begins with "GET /v1/models"
   TestAssert "the menu lists them, sorted", the text of button "Model" of stack kWindow is \
         ("claude-haiku-9" & return & "claude-opus-9" & return & "claude-sonnet-9")
   TestAssert "the newest Sonnet is chosen", the label of button "Model" of stack kWindow is "claude-sonnet-9"
   put xtaTestPrefs() into tPrefs
   TestAssert "and kept", tPrefs["cXTalkAssistant,model,anthropic"] is "claude-sonnet-9"
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "the status line says which", field "Status" of stack kWindow contains "Using claude-sonnet-9"
   TestAssert "Send is Send again", the label of button "Send" of stack kWindow is "Send" and the enabled of button "Models" of stack kWindow

   -- A model the user chose stays chosen
   revIDESetPreference "cXTalkAssistant,model,anthropic", "claude-opus-9"
   dispatch "xtaChooseModels" to stack kMain
   TestAssert "the user's model stays", the label of button "Model" of stack kWindow is "claude-opus-9"

   -- Another provider: its models are not those
   dispatch "xtaSetProviderByName" to stack kMain with "OpenAI (or compatible)"
   TestAssert "the other provider is shown", the label of button "Provider" of stack kWindow is "OpenAI (or compatible)"
   TestAssert "the model menu offers its suggestions", the text of button "Model" of stack kWindow is \
         ("gpt-6.1-sol" & return & "gpt-6-astra" & return & "gpt-6-luna")
   dispatch "xtaSetProviderByName" to stack kMain with "Anthropic"
   TestAssert "back to Anthropic, with its model", the label of button "Model" of stack kWindow is "claude-opus-9"
   TestAssert "and its list", the text of button "Model" of stack kWindow is \
         ("claude-haiku-9" & return & "claude-opus-9" & return & "claude-sonnet-9")
end TestModelsChoosesAModel

-- Send with no model chosen asks for the models first and uses the one the
-- list suggests
on TestSendChoosesAModel
   local tPort
   put TestStartServer("200 OK", TestModelList()) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Hello.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   revIDESetPreference "cXTalkAssistant,model,anthropic", empty
   set the label of button "Model" of stack kWindow to empty
   put "Say hello" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sRequests[1] & return & "---" & return & sRequests[2]
   TestAssert "two requests", sServed is 2
   TestAssert "first the models", sRequests[1] begins with "GET /v1/models"
   TestAssert "then the question", sRequests[2] begins with "POST /v1/messages"
   TestAssert "with the model the list suggests", TestBodyOf(sRequests[2]) contains (TestQ("model") & ":" & TestQ("claude-sonnet-9"))
   TestAssert "the answer is shown", field "Conversation" of stack kWindow contains "Hello."
   TestAssert "the model is shown", the label of button "Model" of stack kWindow is "claude-sonnet-9"
end TestSendChoosesAModel

on TestMoreMenu
   TestOpenTheWindow "http://127.0.0.1:1"
   TestDiagnostic the text of button "More" of stack kWindow
   TestAssert "Memory", "Memory..." is among the lines of the text of button "More" of stack kWindow
   TestAssert "Settings", "Settings..." is among the lines of the text of button "More" of stack kWindow
   TestAssert "the key, in the Settings", "Set API Key..." is among the lines of the text of button "More" of stack kWindow
   TestAssert "the fix rounds and the base URL moved to the Settings", \
         not ("Fix Rounds..." is among the lines of the text of button "More" of stack kWindow) \
         and not ("Base URL..." is among the lines of the text of button "More" of stack kWindow)
   TestAssert "the short guide, not ticked", "!nShort Guide, No Tools (for small local models)" is among the lines of the text of button "More" of stack kWindow
   TestAssert "Explain the Last Error", "Explain the Last Error" is among the lines of the text of button "More" of stack kWindow
   TestAssert "Explain the Open Script", "Explain the Open Script" is among the lines of the text of button "More" of stack kWindow
   TestAssert "Copy the Conversation, once there is one", "(Copy the Conversation" is among the lines of the text of button "More" of stack kWindow
end TestMoreMenu

-- More > Copy the Conversation: who said what, as Markdown, what the
-- tools did and the answer after them in one block, as in the window
on TestCopyTheConversation
   local tPort, tCalls, tClipboard, tText
   put "lookup_dictionary" into tCalls[1]["name"]
   put "{" & TestQ("term") & ":" & TestQ("put") & "}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("It places a value.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "What does put do?" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "it can be copied now", "Copy the Conversation" is among the lines of the text of button "More" of stack kWindow
   put TestClipboardWorks() into tClipboard
   dispatch "xtaMoreMenuPick" to stack kMain with "Copy the Conversation"
   TestAssert "the status line says so", field "Status" of stack kWindow is "Copied the conversation to the clipboard."
   if tClipboard then
      put the clipboardData["text"] into tText
      TestDiagnostic tText
      TestAssert "as Markdown", tText begins with ("### You" & return & return & "What does put do?" & return & return & "### xTalk Assistant") \
            and tText contains ("- *Looked up" && quote & "put" & quote && "in the Dictionary*") and tText contains "It places a value."
      TestAssert "the tools and the answer in one block", TestCount(tText, "### xTalk Assistant") is 1
   end if
end TestCopyTheConversation

on TestUnloadTakesItAllAway
   TestOpenTheWindow "http://127.0.0.1:1"
   TestAssert "the window is open", there is a stack kWindow
   TestAssert "the error hook is in the message path", the long id of stack kErrorHook is among the lines of the frontScripts
   -- What the IDE sends when it unloads the extension
   send "extensionFinalize" to stack kMain
   TestAssert "the window is gone", there is not a stack kWindow
   TestAssert "the core is no longer in use", not (kCore is among the lines of the stacksInUse)
   TestAssert "the compile check's stack is gone", there is not a stack "revXTalkAssistantCheck"
   TestAssert "the error hook is gone", there is not a stack kErrorHook and not (the frontScripts contains "xtalkassistant-errors")
end TestUnloadTakesItAllAway

--------------------------------------------------------------------------------
-- The Settings dialog. It is modal, and outside the IDE "modal" returns at
-- once, so the tests take the steps before and after its modal loop
-- (xtaSettingsPrepare, xtaSettingsDone) and click in it between them.

-- Everything is set in one place: what does not check out keeps the dialog
-- open and says why; Get Models fills the model menu with the dialog's key
-- and base URL; Save keeps it all, the key only in memory
on TestSettingsKeepEverything
   local tPort, tPrefs, tKey, tBody
   put TestStartServer("200 OK", TestModelList()) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Hello.")
   TestOpenTheWindow "http://127.0.0.1:1"
   dispatch "xtaSettingsPrepare" to stack kMain with empty
   TestAssert "the dialog is built", there is a stack kSettings
   TestDiagnostic the width of stack kSettings && "by" && the height of stack kSettings
   TestAssert "it fits a 720p screen", the width of stack kSettings <= 1200 and the height of stack kSettings <= 640
   TestAssert "with what is set", field "Base URL" of stack kSettings is "http://127.0.0.1:1" \
         and the label of button "Model" of stack kSettings is "test-model" and field "Fix Rounds" of stack kSettings is 5
   TestAssert "and says where the key comes from", field "Key Note" of stack kSettings begins with "The key in the environment variable ANTHROPIC_API_KEY is used."
   TestAssert "the notes say what an empty number means", \
         field "Max Tokens Note" of stack kSettings is "tokens (empty: 16000 for Anthropic; OpenAI's model decides)" \
         and field "Timeout Note" of stack kSettings is "seconds (10 to 3600; empty: 600, more for a long answer)"
   -- As pasted: with spaces and a line break around it
   put "  sk-ant-typed-1234  " & return into field "Key" of stack kSettings
   put "http://127.0.0.1:" & tPort into field "Base URL" of stack kSettings
   put "lots" into field "Max Tokens" of stack kSettings
   send "mouseUp 1" to button "Save" of stack kSettings
   TestAssert "a number that is not one keeps the dialog open", there is a stack kSettings and the visible of stack kSettings is false
   TestDiagnostic field "Result" of stack kSettings
   TestAssert "and says why", field "Result" of stack kSettings contains "longest answer"
   put 2048 into field "Max Tokens" of stack kSettings
   put 3 into field "Fix Rounds" of stack kSettings
   put 60 into field "Timeout" of stack kSettings
   set the hilite of button "Include" of stack kSettings to false
   set the hilite of button "Tools" of stack kSettings to false
   send "mouseUp 1" to button "Get Models" of stack kSettings
   TestDiagnostic field "Result" of stack kSettings
   TestAssert "Get Models fills the menu", the text of button "Model" of stack kSettings is \
         ("claude-haiku-9" & return & "claude-opus-9" & return & "claude-sonnet-9")
   TestAssert "and says the key works", field "Result" of stack kSettings contains "listed 3 models"
   TestAssert "with the key typed", TestRequestHeader("x-api-key") is "sk-ant-typed-1234"
   set the label of button "Model" of stack kSettings to "claude-opus-9"
   send "mouseUp 1" to button "Save" of stack kSettings
   dispatch function "xtaSettingsDone" to stack kMain
   TestAssert "saved", the result is true
   TestAssert "the dialog is gone", there is not a stack kSettings
   put xtaTestPrefs() into tPrefs
   TestAssert "the base URL is kept", tPrefs["cXTalkAssistant,baseUrl,anthropic"] is ("http://127.0.0.1:" & tPort)
   TestAssert "the model", tPrefs["cXTalkAssistant,model,anthropic"] is "claude-opus-9"
   TestAssert "the longest answer, the fix rounds and the wait", tPrefs["cXTalkAssistant,maxTokens"] is 2048 \
         and tPrefs["cXTalkAssistant,fixRounds"] is 3 and tPrefs["cXTalkAssistant,timeout"] is 60
   TestAssert "the boxes", tPrefs["cXTalkAssistant,includeScript"] is false and tPrefs["cXTalkAssistant,tools"] is false \
         and tPrefs["cXTalkAssistant,shortGuide"] is false
   repeat for each key tKey in tPrefs
      TestAssert "the key is not a preference:" && tKey, not (tPrefs[tKey] contains "sk-ant-typed")
   end repeat
   TestAssert "the window shows the model", the label of button "Model" of stack kWindow is "claude-opus-9"
   TestAssert "and the list", the text of button "Model" of stack kWindow is ("claude-haiku-9" & return & "claude-opus-9" & return & "claude-sonnet-9")
   TestAssert "and the box", not the hilite of button "Include" of stack kWindow
   put "Say hello" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked", sServed is 2
   TestAssert "with the key", TestRequestHeader("x-api-key") is "sk-ant-typed-1234"
   put TestRequestBody() into tBody
   TestAssert "with the longest answer", tBody contains (TestQ("max_tokens") & ":2048")
   TestAssert "and no tools", not (tBody contains TestQ("tools"))
end TestSettingsKeepEverything

-- A key pasted in the dialog (where 0.2.5-rc.3's dialog dropped it) is the
-- one used, the dialog shows only its end afterwards, and Forget Key
-- forgets it; the other provider's settings are its own
on TestSettingsForAKey
   local tPort
   revIDESetPreference "cXTalkAssistant,enabled", true
   revIDESetPreference "cXTalkAssistant,provider", "anthropic"
   put TestStartServer("200 OK", TestModelList()) into tPort
   -- With a base URL (which may need no key) and a model, opening the
   -- window asks nothing; without them it would ask for the key in the
   -- dialog, whose modal loop the tests cannot take
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", "http://127.0.0.1:" & tPort
   revIDESetPreference "cXTalkAssistant,model,anthropic", "test-model"
   dispatch "xtalkAssistantMenuPick" to stack kMain
   TestAssert "the window is open", there is a stack kWindow and there is not a stack kSettings
   TestAssert "nothing was asked of the provider", sServed is 0
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", empty
   revIDESetPreference "cXTalkAssistant,model,anthropic", empty
   dispatch "xtaSettingsPrepare" to stack kMain with "Key"
   TestAssert "it asks for the key", field "Key Note" of stack kSettings begins with "Paste your Anthropic API key here."
   TestAssert "with the caret to go in its field", the cFocus of stack kSettings is "Key"
   TestAssert "the suggested models", line 2 of the text of button "Model" of stack kSettings is "claude-opus-5-5"
   put "sk-ant-pasted-5678" into field "Key" of stack kSettings
   put "http://127.0.0.1:" & tPort into field "Base URL" of stack kSettings
   -- The other provider: its own fields, and back
   dispatch "menuPick" to button "Provider" of stack kSettings with "OpenAI (or compatible)"
   TestAssert "the other provider's key is not this one", field "Key" of stack kSettings is empty \
         and field "Base URL" of stack kSettings is empty
   TestAssert "nor its models", line 1 of the text of button "Model" of stack kSettings is "gpt-6.1-sol"
   dispatch "menuPick" to button "Provider" of stack kSettings with "Anthropic"
   TestAssert "what was typed is kept", field "Key" of stack kSettings is "sk-ant-pasted-5678"
   send "mouseUp 1" to button "Save" of stack kSettings
   dispatch function "xtaSettingsDone" to stack kMain
   TestAssert "saved", the result is true
   dispatch "xtaChooseModels" to stack kMain
   TestAssert "the models are asked for with it", sServed is 1 and TestRequestHeader("x-api-key") is "sk-ant-pasted-5678"
   TestAssert "and one chosen", the label of button "Model" of stack kWindow is "claude-sonnet-9"
   dispatch "xtaSettingsPrepare" to stack kMain with empty
   TestAssert "only its end is shown", field "Key" of stack kSettings is empty \
         and field "Key Note" of stack kSettings begins with ("A key is set, ending in" && quote & "5678" & quote)
   send "mouseUp 1" to button "Forget Key" of stack kSettings
   TestAssert "Forget Key forgets it", field "Key Note" of stack kSettings begins with "Paste your Anthropic API key here."
   send "mouseUp 1" to button "Cancel" of stack kSettings
   dispatch function "xtaSettingsDone" to stack kMain
   TestAssert "Cancel saves nothing", the result is false
   TestAssert "the status line says there is no key", field "Status" of stack kWindow contains "no API key yet (More > Settings...)"
end TestSettingsForAKey

--------------------------------------------------------------------------------
-- Tools

on TestToolCallsAreCarriedOut
   local tPort, tCalls, tDoc, tMessages, tResults, tConversation, tLabels, tLine
   put "lookup_dictionary" into tCalls[1]["name"]
   put "{" & TestQ("term") & ":" & TestQ("the put") & "}" into tCalls[1]["input"]
   put "check_code" into tCalls[2]["name"]
   put "{" & TestQ("code") & ":" & TestQ("put 1 inot tX") & "}" into tCalls[2]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("It places a value.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "What does put do?" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked twice", sServed is 2
   put xtaJsonParse(TestBodyOf(sRequests[2])) into tDoc
   put xtaJsonMember(tDoc, "messages") into tMessages
   TestDiagnostic TestBodyOf(sRequests[2])
   TestAssert "the calls went back", xtaJsonText(xtaJsonGet(tMessages, "2/content/1/name")) is "lookup_dictionary" \
         and xtaJsonText(xtaJsonGet(tMessages, "2/content/2/name")) is "check_code"
   put xtaJsonGet(tMessages, "3/content") into tResults
   TestAssert "with the Dictionary's entry (the found without the)", xtaJsonText(xtaJsonGet(tResults, "1/tool_use_id")) is "toolu_1" \
         and xtaJsonText(xtaJsonGet(tResults, "1/content")) contains "put <value> into <container>"
   TestAssert "and the compile check's errors", xtaJsonText(xtaJsonGet(tResults, "2/tool_use_id")) is "toolu_2" \
         and xtaJsonText(xtaJsonGet(tResults, "2/content")) contains "does not compile" \
         and xtaJsonText(xtaJsonGet(tResults, "2/content")) contains "line 1"
   put field "Conversation" of stack kWindow into tConversation
   TestDiagnostic tConversation
   TestAssert "what the tools did is shown", ("Looked up" && quote & "put" & quote && "in the Dictionary") is among the lines of tConversation \
         and "Checked code: it does not compile" is among the lines of tConversation
   TestAssert "the answer after them", tConversation contains "It places a value."
   put 0 into tLabels
   repeat for each line tLine in tConversation
      if tLine is "xTalk Assistant" then
         add 1 to tLabels
      end if
   end repeat
   TestAssert "an answer of calls alone shows only what they did", tLabels is 1
   TestAssert "the tool lines are in italics", the textStyle of line lineOffset("Checked code", tConversation) of field "Conversation" of stack kWindow is "italic"
   TestAssert "the tokens of both requests", field "Status" of stack kWindow contains "20 tokens in, 40 out"
end TestToolCallsAreCarriedOut

-- The user is asked in the window's bar, and Don't Allow is kept for the
-- rest of the question
on TestReadingTheStackIsAskedFirst
   local tPort, tCalls, tDoc, tResult
   put "read_stack" into tCalls[1]["name"]
   put "{}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("I could not read it.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   create stack "xtaTestWork"
   go stack "xtaTestWork"
   put "Describe my stack" into field "Prompt" of stack kWindow
   TestAnswerAsks "no"
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sAsked
   TestAssert "the bar asked", line 1 of sAsked begins with ("Let the assistant read your stack" && quote & "xtaTestWork" & quote & "?")
   TestAssert "and is gone again", not the visible of graphic "AskPanel" of stack kWindow
   put xtaJsonParse(TestBodyOf(sRequests[2])) into tDoc
   put xtaJsonGet(tDoc, "messages/3/content/1") into tResult
   TestDiagnostic xtaJsonText(xtaJsonMember(tResult, "content"))
   TestAssert "not allowed, so not read", xtaJsonText(xtaJsonMember(tResult, "content")) contains "did not allow" \
         and xtaJsonText(xtaJsonMember(tResult, "is_error")) is "true"
   TestAssert "nothing of the stack was sent", not (TestBodyOf(sRequests[2]) contains "card id")
   TestAssert "the window says so", ("Not allowed to read the stack" && quote & "xtaTestWork" & quote) is among the lines of field "Conversation" of stack kWindow
   delete stack "xtaTestWork"
end TestReadingTheStackIsAskedFirst

on TestToolsAreUsedUp
   local tPort, tCalls
   put "last_error" into tCalls[1]["name"]
   put "{}" into tCalls[1]["input"]
   -- The model asks for a tool every time
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "What went wrong?" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   -- 25 tools, then told they are used up, then asked once more
   TestAssert "it stops", sServed is 27
   TestAssert "the model was told", TestBodyOf(sRequests[27]) contains "you have used the 25 tools"
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "the status says why", field "Status" of stack kWindow contains "used up its tools"
   TestAssert "Send is Send again", the label of button "Send" of stack kWindow is "Send"
end TestToolsAreUsedUp

-- A local server whose model has no tools is asked again without them
on TestToolsRefusedByALocalServer
   local tPort, tDoc
   put TestStartServer("400 Bad Request", "{" & TestQ("error") & ":{" & TestQ("message") & ":" & \
         TestQ("registry.ollama.ai/library/tiny:1b does not support tools") & "}}") into tPort
   TestQueueAnswer "200 OK", TestAnswer("Hello.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Hi" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked twice", sServed is 2
   put xtaJsonParse(TestBodyOf(sRequests[1])) into tDoc
   TestAssert "first with tools", xtaJsonCount(xtaJsonMember(tDoc, "tools")) is 9
   put xtaJsonParse(TestBodyOf(sRequests[2])) into tDoc
   TestAssert "then without", xtaJsonType(xtaJsonMember(tDoc, "tools")) is "missing"
   TestAssert "the answer is shown", field "Conversation" of stack kWindow contains "Hello."
   -- And so for the questions after it
   put TestStartServer("200 OK", TestAnswer("Hello again.")) into tPort
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", "http://127.0.0.1:" & tPort
   put "Hi again" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   put xtaJsonParse(TestRequestBody()) into tDoc
   TestAssert "no tools from then on", sServed is 1 and xtaJsonType(xtaJsonMember(tDoc, "tools")) is "missing"
end TestToolsRefusedByALocalServer

--------------------------------------------------------------------------------
-- Answers cut off at their length limit, and answers stopped on safety
-- grounds. Anthropic's models think before they answer, and the thinking
-- counts toward the limit: in 0.2.5-rc.4 (4096 tokens) a question that
-- built a stack came back with nothing but thinking, and the window showed
-- an empty answer.

-- An answer cut off before it said anything is asked for again with twice
-- the room, and the window says why it waits again
on TestACutOffAnswerIsAskedAgain
   local tPort, tDoc, tConversation, tStatus
   put TestStartServer("200 OK", TestStopAnswer(TestThinkingBlock(), "max_tokens")) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Here is the stack.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Make me a notepad." into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked twice", sServed is 2
   TestAssert "first with the room Anthropic gets by default", TestBodyOf(sRequests[1]) contains (TestQ("max_tokens") & ":16000")
   TestAssert "then with twice as much", TestBodyOf(sRequests[2]) contains (TestQ("max_tokens") & ":32000")
   TestDiagnostic sDuring[2]["asked"]["activity"]
   TestAssert "and the window said why while it waited", \
         sDuring[2]["asked"]["activity"] is "Cut off at 16000 tokens: asking again with room for 32000"
   put xtaJsonParse(TestBodyOf(sRequests[2])) into tDoc
   TestAssert "the answer that was cut off is not sent back", xtaJsonCount(xtaJsonMember(tDoc, "messages")) is 1
   put field "Conversation" of stack kWindow into tConversation
   TestDiagnostic tConversation
   TestAssert "the answer is shown", tConversation contains "Here is the stack." and not (tConversation contains "Cut off")
   put field "Status" of stack kWindow into tStatus
   TestDiagnostic tStatus
   TestAssert "the status line counts both requests", tStatus contains "2 requests" and tStatus contains "20 tokens in, 16020 out"
   TestAssert "and has nothing to warn of", not (tStatus contains "cut off")
end TestACutOffAnswerIsAskedAgain

-- A call cut off while the model wrote it is never carried out: its input
-- is not whole. With no more room to give, the window says why the answer
-- ends there, and the next question sends no call without its result.
on TestACutOffCallIsNotCarriedOut
   local tPort, tNote, tConversation, tLine, tDoc
   put TestStartServer("200 OK", TestStopAnswer(TestTextBlock("Let me look.") & "," & \
         TestCallBlock("lookup_dictionary", "{" & TestQ("term") & ":" & TestQ("pu") & "}", 1), "max_tokens")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "What does put do?" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked again with more room, and no more", sServed is 2 \
         and TestBodyOf(sRequests[2]) contains (TestQ("max_tokens") & ":32000")
   put field "Conversation" of stack kWindow into tConversation
   TestDiagnostic tConversation
   TestAssert "the call was not carried out", not (tConversation contains "Looked up")
   put "Cut off at the length limit of 32000 tokens, while the model was writing a call to lookup_dictionary, which was not carried out." && \
         "Ask for less at a time, such as one card or a few controls, or raise the longest answer in More > Settings." into tNote
   TestAssert "what it said is shown", tConversation contains "Let me look."
   put lineOffset(tNote, tConversation) into tLine
   TestAssert "and why it ends there, in italics", tLine > 0 and line tLine of tConversation is tNote \
         and the textStyle of line tLine of field "Conversation" of stack kWindow is "italic"
   -- 0.2.5-rc.4 named the colours of the conversation's runs as the engine
   -- does not take them, and none showed
   TestAssert "in amber", the foregroundColor of line tLine of field "Conversation" of stack kWindow is "180,83,9"
   TestAssert "under who answered, in the accent", \
         the foregroundColor of line lineOffset("xTalk Assistant", tConversation) of field "Conversation" of stack kWindow is "124,58,237"
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "the status line says it was cut off", field "Status" of stack kWindow contains "the answer was cut off at its length limit"
   put TestStartServer("200 OK", TestAnswer("It places a value.")) into tPort
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", "http://127.0.0.1:" & tPort
   put "Go on" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic TestRequestBody()
   TestAssert "the next question sends no call", not (TestRequestBody() contains "tool_use") \
         and not (TestRequestBody() contains "toolu_1")
   put xtaJsonParse(TestRequestBody()) into tDoc
   TestAssert "but what was said", xtaJsonText(xtaJsonGet(tDoc, "messages/2/content")) is "Let me look." \
         and xtaJsonCount(xtaJsonMember(tDoc, "messages")) is 3
   TestAssert "with the usual room again", TestRequestBody() contains (TestQ("max_tokens") & ":16000")
end TestACutOffCallIsNotCarriedOut

-- An answer cut off once it had said something is shown with why it ends
-- there, and is not asked for again; its code is not whole, so it is not
-- sent back to be corrected
on TestACutOffAnswerIsShown
   local tPort, tAnswer, tNote, tConversation, tText
   put "Here is the first part:" & return & TestBlock("livecodescript", "on mouseUp" & return & "   put 1 inot tX") into tAnswer
   put TestStartServer("200 OK", TestStopAnswer(TestTextBlock(tAnswer), "max_tokens")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Write it all" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked once", sServed is 1
   put field "Conversation" of stack kWindow into tConversation
   TestDiagnostic tConversation
   put "Cut off at the length limit of 16000 tokens. Ask the assistant to go on, or raise the longest answer in More > Settings." into tNote
   TestAssert "what it said and why it ends there", tConversation contains "Here is the first part:" and tNote is among the lines of tConversation
   TestAssert "its code was not sent back", not (tConversation contains "Compile check")
   TestAssert "the status line says it was cut off", field "Status" of stack kWindow contains "the answer was cut off at its length limit"
   if TestClipboardWorks() then
      dispatch "xtaMoreMenuPick" to stack kMain with "Copy the Conversation"
      put the clipboardData["text"] into tText
      TestDiagnostic tText
      TestAssert "a copy of the conversation says so too", tText contains ("*" & tNote & "*")
   end if
end TestACutOffAnswerIsShown

-- An answer cut off before it said anything, with no more room to give
-- (the user's limit is the most already), says so instead of nothing
on TestACutOffAnswerWithNoMoreRoom
   local tPort, tNote
   revIDESetPreference "cXTalkAssistant,maxTokens", 64000
   put TestStartServer("200 OK", TestStopAnswer(TestThinkingBlock(), "max_tokens")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Make me a notepad." into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked once, with the user's limit", sServed is 1 and TestRequestBody() contains (TestQ("max_tokens") & ":64000")
   TestDiagnostic field "Conversation" of stack kWindow
   put "Cut off at the length limit of 64000 tokens, before the model wrote its answer: its thinking counts toward the limit." && \
         "Ask for less at a time, or raise the longest answer in More > Settings." into tNote
   TestAssert "the window says why there is no answer", tNote is among the lines of field "Conversation" of stack kWindow
   revIDESetPreference "cXTalkAssistant,maxTokens", empty
end TestACutOffAnswerWithNoMoreRoom

-- An answer the provider stopped on safety grounds: what it asked for is
-- not done, the window says why it ends there, and it is not sent with
-- the next question
on TestARefusalIsNotCarriedOut
   local tPort, tNote, tConversation, tDoc
   put TestStartServer("200 OK", TestStopAnswer(TestTextBlock("I'll start.") & "," & \
         TestCallBlock("lookup_dictionary", "{" & TestQ("term") & ":" & TestQ("put") & "}", 1), "refusal", \
         "{" & TestQ("type") & ":" & TestQ("refusal") & "," & TestQ("category") & ":" & TestQ("cyber") & "}")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Scan the ports" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked once", sServed is 1
   put field "Conversation" of stack kWindow into tConversation
   TestDiagnostic tConversation
   TestAssert "its call was not carried out", not (tConversation contains "Looked up")
   put "Anthropic stopped this answer on safety grounds (cyber). Nothing it asked for was done, and it is not sent with your next question." into tNote
   TestAssert "the window says why it ends there", tConversation contains "I'll start." and tNote is among the lines of tConversation
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "and so does the status line", field "Status" of stack kWindow contains "the provider stopped the answer on safety grounds"
   put TestStartServer("200 OK", TestAnswer("Hello.")) into tPort
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", "http://127.0.0.1:" & tPort
   put "Something else" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic TestRequestBody()
   put xtaJsonParse(TestRequestBody()) into tDoc
   TestAssert "the next question does not send it", not (TestRequestBody() contains "I'll start.") \
         and not (TestRequestBody() contains "tool_use") and xtaJsonCount(xtaJsonMember(tDoc, "messages")) is 2
end TestARefusalIsNotCarriedOut

--------------------------------------------------------------------------------
-- Changing stacks and running code

-- A batch of changes is asked about in the window's bar; Don't Apply
-- changes nothing, Apply makes it, and Undo takes it back
on TestChangesAreAskedAboutAndCanBeUndone
   local tPort, tCalls, tDoc, tText, tConversation, tLine, tUndoLine
   put "make_changes" into tCalls[1]["name"]
   put "{" & TestQ("changes") & ":[{" & TestQ("action") & ":" & TestQ("create") & "," & TestQ("kind") & ":" & TestQ("button") & "," & \
         TestQ("name") & ":" & TestQ("Hello") & "," & TestQ("rect") & ":[10,10,110,34]," & \
         TestQ("script") & ":" & TestQ("on mouseUp" & return & "   beep" & return & "end mouseUp") & "}]}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Then I will not.")
   TestQueueAnswer "200 OK", TestToolAnswer(tCalls)
   TestQueueAnswer "200 OK", TestAnswer("Done: the button beeps.")
   TestQueueAnswer "200 OK", TestAnswer("Understood.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   create stack "xtaTestWork"
   go stack "xtaTestWork"

   -- Don't Apply
   put "Add a button that beeps" into field "Prompt" of stack kWindow
   TestAnswerAsks "no"
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sAsked
   TestAssert "the bar asked first", item 1 of line 1 of sAsked is ("Apply this change to the stack" && quote & "xtaTestWork" & quote & "?")
   TestAssert "saying what it does", item 2 of line 1 of sAsked begins with ("Create a button" && quote & "Hello" & quote)
   TestAssert "with no button to allow it for the session", item 3 of line 1 of sAsked is false
   TestAssert "while the pill says it needs the user", item 4 of line 1 of sAsked is "Needs you"
   TestAssert "and the conversation made room for the bar", item 5 of line 1 of sAsked is true
   TestAssert "nothing was changed", there is not a button "Hello" of stack "xtaTestWork"
   put xtaJsonParse(TestBodyOf(sRequests[2])) into tDoc
   put xtaJsonGet(tDoc, "messages/3/content/1") into tDoc
   TestDiagnostic xtaJsonText(xtaJsonMember(tDoc, "content"))
   TestAssert "the model was told", xtaJsonText(xtaJsonMember(tDoc, "content")) contains "chose not to apply" \
         and xtaJsonText(xtaJsonMember(tDoc, "is_error")) is "true"
   TestAssert "the window says so", ("You chose not to apply the changes to the stack" && quote & "xtaTestWork" & quote) \
         is among the lines of field "Conversation" of stack kWindow
   TestAssert "Undo All is off", "(Undo All Changes..." is among the lines of the text of button "More" of stack kWindow

   -- Apply
   put "Add it after all" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "the button was made", there is a button "Hello" of stack "xtaTestWork"
   TestAssert "as the model asked", the script of button "Hello" of stack "xtaTestWork" contains "beep" \
         and the rect of button "Hello" of stack "xtaTestWork" is "10,10,110,34"
   put xtaJsonParse(TestBodyOf(sRequests[4])) into tDoc
   put xtaJsonText(xtaJsonGet(tDoc, "messages/7/content/1/content")) into tText
   TestDiagnostic tText
   TestAssert "the model learns what was made, with its id", tText contains "Applied 1 change" \
         and tText contains ("(id" && the id of button "Hello" of stack "xtaTestWork" & ")")
   put field "Conversation" of stack kWindow into tConversation
   TestDiagnostic tConversation
   put 0 into tUndoLine
   repeat with tLine = 1 to the number of lines of tConversation
      if line tLine of tConversation begins with ("Applied 1 change to the stack" && quote & "xtaTestWork" & quote) then
         put tLine into tUndoLine
      end if
   end repeat
   TestAssert "the window says what was applied", tUndoLine > 0 \
         and line tUndoLine + 1 of tConversation contains ("Create a button" && quote & "Hello" & quote)
   TestAssert "with Undo as a link", the last word of line tUndoLine of tConversation is "Undo" \
         and the textStyle of the last word of line tUndoLine of field "Conversation" of stack kWindow is "link" \
         and the linkText of the last word of line tUndoLine of field "Conversation" of stack kWindow is "undo,1"
   TestAssert "Undo All is on", "Undo All Changes..." is among the lines of the text of button "More" of stack kWindow

   -- Undo, as the link is clicked
   dispatch "xtaConversationLink" to stack kMain with "undo,1"
   TestAssert "Undo takes the button away", there is not a button "Hello" of stack "xtaTestWork"
   TestAssert "the window says it is undone", line tUndoLine of field "Conversation" of stack kWindow ends with "(undone)"
   TestDiagnostic field "Status" of stack kWindow
   TestAssert "and so does the status line", field "Status" of stack kWindow contains "Undid 1 set of changes"
   TestAssert "Undo All is off again", "(Undo All Changes..." is among the lines of the text of button "More" of stack kWindow
   put "What now?" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   put xtaJsonParse(TestRequestBody()) into tDoc
   put xtaJsonText(xtaJsonGet(tDoc, "messages/" & xtaJsonCount(xtaJsonMember(tDoc, "messages")) & "/content")) into tText
   TestDiagnostic tText
   TestAssert "the next question tells the model", tText begins with "What now?" and tText contains "I undid what follows" \
         and tText contains ("Applied 1 change to the stack" && quote & "xtaTestWork" & quote)
   delete stack "xtaTestWork"
end TestChangesAreAskedAboutAndCanBeUndone

-- A batch with a mistake goes back to the model without asking the user
on TestChangesWithAMistakeGoBack
   local tPort, tCalls, tDoc
   put "make_changes" into tCalls[1]["name"]
   put "{" & TestQ("changes") & ":[{" & TestQ("action") & ":" & TestQ("create") & "," & TestQ("kind") & ":" & TestQ("button") & "," & \
         TestQ("properties") & ":{" & TestQ("lable") & ":" & TestQ("OK") & "}}]}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Corrected.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   create stack "xtaTestWork"
   go stack "xtaTestWork"
   put "Add an OK button" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "the user was not asked", sAsked is empty
   put xtaJsonParse(TestBodyOf(sRequests[2])) into tDoc
   put xtaJsonText(xtaJsonGet(tDoc, "messages/3/content/1/content")) into tDoc
   TestDiagnostic tDoc
   TestAssert "the model is told what is wrong", tDoc contains "Nothing was changed" and tDoc contains "lable"
   TestAssert "nothing was made", the number of buttons of stack "xtaTestWork" is 0
   delete stack "xtaTestWork"
end TestChangesWithAMistakeGoBack

-- Code to run is asked about; Allow in the Sandbox lets the next run go
-- unasked, but code that reaches the network is asked about every time
on TestRunsAreAskedAbout
   local tPort, tCalls, tRisky, tDoc, tText
   put "run_code" into tCalls[1]["name"]
   put "{" & TestQ("code") & ":" & TestQ("put 6 * 7") & "}" into tCalls[1]["input"]
   put "run_code" into tRisky[1]["name"]
   put "{" & TestQ("code") & ":" & TestQ("put url " & quote & "https://example.com/" & quote & " into tPage") & "}" into tRisky[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestToolAnswer(tCalls)
   TestQueueAnswer "200 OK", TestToolAnswer(tRisky)
   TestQueueAnswer "200 OK", TestAnswer("It is 42.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "What is 6 times 7?" into field "Prompt" of stack kWindow
   TestAnswerAsks "session,no"
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sAsked
   TestAssert "the first run was asked about", item 1 of line 1 of sAsked is "Run this code in a sandbox?" \
         and item 2 of line 1 of sAsked contains "put 6 * 7"
   TestAssert "with a button to allow it for the session", item 3 of line 1 of sAsked is true
   put xtaJsonParse(TestBodyOf(sRequests[2])) into tDoc
   put xtaJsonText(xtaJsonGet(tDoc, "messages/3/content/1/content")) into tText
   TestDiagnostic tText
   TestAssert "it ran, and the model has what it put", tText contains "It put into the Message Box:" & return & "42"
   TestAssert "the second run was not asked about, and ran", the number of lines of sAsked is 2 \
         and xtaJsonText(xtaJsonGet(xtaJsonParse(TestBodyOf(sRequests[3])), "messages/5/content/1/content")) contains "42"
   TestAssert "the run that reaches the network was asked about", item 2 of line 2 of sAsked begins with "Careful: it uses the network"
   TestAssert "with no button to allow it for the session", item 3 of line 2 of sAsked is false
   put xtaJsonText(xtaJsonGet(xtaJsonParse(TestBodyOf(sRequests[4])), "messages/7/content/1/content")) into tText
   TestAssert "Don't Run: nothing ran, and the model was told", tText contains "chose not to run"
   TestAssert "the window says what ran", "Ran the code in a sandbox: no error" is among the lines of field "Conversation" of stack kWindow
   TestAssert "and what it put out, under it", line lineOffset("Ran the code in a sandbox: no error", field "Conversation" of stack kWindow) + 1 \
         of field "Conversation" of stack kWindow is "42"
   TestAssert "a run in the sandbox is not undone", not (field "Conversation" of stack kWindow contains "Undo")
end TestRunsAreAskedAbout

-- A run on the user's stack is saved as a checkpoint first, and Undo goes
-- back to it
on TestRunOnTheStackCanBeUndone
   local tPort, tCalls, tText, tConversation, tLine, tUndoLine, tFile
   put specialFolderPath("temporary") & "/xta-test-work-" & the milliseconds & ".livecode" into tFile
   create stack "xtaTestWork"
   set the fileName of stack "xtaTestWork" to tFile
   save stack "xtaTestWork"
   go stack "xtaTestWork"
   put "run_code" into tCalls[1]["name"]
   put "{" & TestQ("code") & ":" & TestQ("set the cCount of this stack to 5" & return & "put the cCount of this stack") & "," & \
         TestQ("where") & ":" & TestQ("stack") & "}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("The count is 5.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Set the count to 5" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sAsked
   TestAssert "asked, for the stack", item 1 of line 1 of sAsked is ("Run this code on the stack" && quote & "xtaTestWork" & quote & "?") \
         and item 2 of line 1 of sAsked contains "A copy of the stack is saved first"
   TestAssert "it ran on the stack", the cCount of stack "xtaTestWork" is 5
   put field "Conversation" of stack kWindow into tConversation
   TestDiagnostic tConversation
   put 0 into tUndoLine
   repeat with tLine = 1 to the number of lines of tConversation
      if line tLine of tConversation begins with ("Ran the code on the stack" && quote & "xtaTestWork" & quote) then
         put tLine into tUndoLine
      end if
   end repeat
   TestAssert "with Undo", tUndoLine > 0 and the last word of line tUndoLine of tConversation is "Undo"
   dispatch "xtaConversationLink" to stack kMain with "undo,1"
   TestAssert "Undo goes back to the checkpoint", the cCount of stack "xtaTestWork" is empty
   TestAssert "the stack keeps its file", the fileName of stack "xtaTestWork" is tFile
   delete stack "xtaTestWork"
   delete file tFile
end TestRunOnTheStackCanBeUndone

-- With nothing paused, the model is told how the user can pause a script,
-- and the user is not asked
on TestDebugStateWhenNothingIsPaused
   local tPort, tCalls, tText
   put "debug_state" into tCalls[1]["name"]
   put "{}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Nothing is paused.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put "Where is my script stuck?" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "the user was not asked", sAsked is empty
   put xtaJsonText(xtaJsonGet(xtaJsonParse(TestBodyOf(sRequests[2])), "messages/3/content/1/content")) into tText
   TestDiagnostic tText
   TestAssert "the model is told", tText contains "not paused" and tText contains "breakpoint"
   TestAssert "the window says so", "Looked at the debugger: it is not paused" is among the lines of field "Conversation" of stack kWindow
end TestDebugStateWhenNothingIsPaused

-- The model can look at a card: it is asked about as reading the stack
-- is, and the picture goes with the tool's result. Of the pictures of a
-- conversation the newest two go with each request.
on TestLookAtTheCard
   local tPort, tCalls, tContent, tText, tBody
   put "look_at_card" into tCalls[1]["name"]
   put "{}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestToolAnswer(tCalls)
   TestQueueAnswer "200 OK", TestToolAnswer(tCalls)
   TestQueueAnswer "200 OK", TestAnswer("The button fits.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   create stack "xtaTestWork"
   set the width of stack "xtaTestWork" to 320
   set the height of stack "xtaTestWork" to 240
   go stack "xtaTestWork"
   set the defaultStack to "xtaTestWork"
   create button "Hello"
   put "How does my card look?" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sAsked
   TestAssert "asked once, as reading the stack is", the number of lines of sAsked is 1 \
         and line 1 of sAsked begins with ("Let the assistant read your stack" && quote & "xtaTestWork" & quote & "?")
   TestAssert "asked four times", sServed is 4
   put xtaJsonGet(xtaJsonParse(TestBodyOf(sRequests[2])), "messages/3/content/1/content") into tContent
   put xtaJsonText(xtaJsonGet(tContent, "1/text")) into tText
   TestDiagnostic tText
   TestAssert "the result says what the picture shows", tText begins with ("A picture of card id" && the id of this card of stack "xtaTestWork") \
         and tText contains "320 by 240 pixels"
   TestAssert "and has it, a PNG", xtaJsonText(xtaJsonGet(tContent, "2/type")) is "image" \
         and xtaJsonText(xtaJsonGet(tContent, "2/source/type")) is "base64" \
         and xtaJsonText(xtaJsonGet(tContent, "2/source/media_type")) is "image/png" \
         and byte 2 to 4 of base64Decode(xtaJsonText(xtaJsonGet(tContent, "2/source/data"))) is "PNG"
   put TestBodyOf(sRequests[4]) into tBody
   TestAssert "of three pictures, the newest two go with the last request", TestCount(tBody, TestQ("media_type") & ":" & TestQ("image/png")) is 2
   TestAssert "and the model is told why the first is not there", tBody contains "The picture is no longer sent"
   TestDiagnostic field "Conversation" of stack kWindow
   TestAssert "the window says what was looked at", \
         ("Looked at card id" && the id of this card of stack "xtaTestWork" && "of the stack" && quote & "xtaTestWork" & quote) \
         is among the lines of field "Conversation" of stack kWindow
   delete stack "xtaTestWork"
end TestLookAtTheCard

-- The Settings switch for pictures takes look_at_card away; a server of
-- the user's own with OpenAI's API is not offered it at all
on TestPicturesCanBeTurnedOff
   local tPort, tDoc, tText, tIndex
   put TestStartServer("200 OK", TestAnswer("Hello.")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   revIDESetPreference "cXTalkAssistant,pictures", false
   put "Hi" into field "Prompt" of stack kWindow
   dispatch "xtaSendPrompt" to stack kMain
   put xtaJsonParse(TestRequestBody()) into tDoc
   repeat with tIndex = 1 to xtaJsonCount(xtaJsonMember(tDoc, "tools"))
      put xtaJsonText(xtaJsonGet(tDoc, "tools/" & tIndex & "/name")) & comma after tText
   end repeat
   TestDiagnostic tText
   TestAssert "no pictures: no look_at_card", tText is "lookup_dictionary,check_code,read_stack,last_error,debug_state,make_changes,run_code,save_stack,"
   dispatch "xtaSettingsPrepare" to stack kMain with empty
   TestAssert "the Settings show it off", not the hilite of button "Pictures" of stack kSettings \
         and the enabled of button "Pictures" of stack kSettings
   set the hilite of button "Tools" of stack kSettings to false
   send "mouseUp 1" to button "Tools" of stack kSettings
   TestAssert "and only with the tools", not the enabled of button "Pictures" of stack kSettings
   send "mouseUp 1" to button "Cancel" of stack kSettings
   dispatch function "xtaSettingsDone" to stack kMain
end TestPicturesCanBeTurnedOff

-- The pictures switch holds from the moment the user turns it off, in the
-- Settings while the model answers: a look_at_card on its way then takes
-- no picture, and a picture taken before goes with no request after it
on TestPicturesTurnedOffWhileItAnswers
   local tPort, tCalls, tBody
   put "look_at_card" into tCalls[1]["name"]
   put "{}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestToolAnswer(tCalls)
   TestQueueAnswer "200 OK", TestAnswer("The button fits.")
   -- Off as the second request comes, which has the first picture
   put 2 into sPicturesOffAt
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   create stack "xtaTestWork"
   go stack "xtaTestWork"
   set the defaultStack to "xtaTestWork"
   create button "Hello"
   put "How does my card look?" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sAsked
   TestAssert "asked once, to read the stack", the number of lines of sAsked is 1
   TestAssert "asked three times", sServed is 3
   TestAssert "the picture went while the switch was on", \
         TestCount(TestBodyOf(sRequests[2]), TestQ("media_type") & ":" & TestQ("image/png")) is 1
   put TestBodyOf(sRequests[3]) into tBody
   TestDiagnostic tBody
   TestAssert "the call on its way when it was turned off took none", \
         tBody contains "The assistant's Settings do not let it send you pictures of the user's cards."
   TestAssert "and the picture taken before goes no more", TestCount(tBody, TestQ("media_type") & ":" & TestQ("image/png")) is 0 \
         and tBody contains "(The picture is no longer sent: the assistant's Settings no longer let it send pictures.)"
   TestDiagnostic field "Conversation" of stack kWindow
   TestAssert "the window says so", "Did not use look_at_card: the Settings do not let it send pictures of your cards" \
         is among the lines of field "Conversation" of stack kWindow
   delete stack "xtaTestWork"
end TestPicturesTurnedOffWhileItAnswers

-- save_stack asks every time, and saves as File > Save does; Don't Save
-- saves nothing. A stack never saved goes to the dialog that asks where,
-- which the user can cancel.
on TestSaveTheStack
   local tPort, tCalls, tFile, tText
   put specialFolderPath("temporary") & "/xta-test-save-" & the milliseconds & ".livecode" into tFile
   create stack "xtaTestWork"
   set the fileName of stack "xtaTestWork" to tFile
   go stack "xtaTestWork"
   put "save_stack" into tCalls[1]["name"]
   put "{}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Then it stays as it is.")
   TestQueueAnswer "200 OK", TestToolAnswer(tCalls)
   TestQueueAnswer "200 OK", TestAnswer("Saved.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort

   -- Don't Save
   put "Save my stack" into field "Prompt" of stack kWindow
   TestAnswerAsks "no"
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sAsked
   TestAssert "the bar asked", item 1 of line 1 of sAsked is ("Save the stack" && quote & "xtaTestWork" & quote & "?") \
         and item 2 of line 1 of sAsked contains tFile and item 2 of line 1 of sAsked contains "cannot be undone"
   TestAssert "with no button to allow it for the session", item 3 of line 1 of sAsked is false
   TestAssert "nothing was saved", xtaTestSaved() is empty and there is not a file tFile
   put xtaJsonText(xtaJsonGet(xtaJsonParse(TestBodyOf(sRequests[2])), "messages/3/content/1/content")) into tText
   TestAssert "the model was told", tText contains "chose not to save"

   -- Save
   put "Save it after all" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   TestAssert "asked again", the number of lines of sAsked is 1
   TestAssert "saved as File > Save saves", the number of lines of xtaTestSaved() is 1 and there is a file tFile
   put xtaJsonText(xtaJsonGet(xtaJsonParse(TestBodyOf(sRequests[4])), "messages/7/content/1/content")) into tText
   TestDiagnostic tText
   TestAssert "the model learns where", tText is ("Saved the stack" && quote & "xtaTestWork" & quote && "to" && tFile & ".")
   TestAssert "the window says so", ("Saved the stack" && quote & "xtaTestWork" & quote) is among the lines of field "Conversation" of stack kWindow
   delete stack "xtaTestWork"
   delete file tFile

   -- A new stack: the dialog asks where, and the user cancels it
   dispatch "xtaNewConversation" to stack kMain
   create stack "xtaTestNew"
   go stack "xtaTestNew"
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Not saved.")
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", "http://127.0.0.1:" & tPort
   put "Save the new one" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   TestDiagnostic sAsked
   TestAssert "the bar says it is new", item 1 of line 1 of sAsked is ("Save the new stack" && quote & "xtaTestNew" & quote & "?") \
         and item 2 of line 1 of sAsked contains "in the dialog that comes next"
   put xtaJsonText(xtaJsonGet(xtaJsonParse(TestBodyOf(sRequests[2])), "messages/3/content/1/content")) into tText
   TestAssert "cancelled: the model is told", tText contains "cancelled saving"
   delete stack "xtaTestNew"
end TestSaveTheStack

-- The Settings switch takes the tools that change and run away, and a call
-- to one of them is refused
on TestChangingStacksCanBeTurnedOff
   local tPort, tCalls, tDoc, tText, tIndex
   put "make_changes" into tCalls[1]["name"]
   put "{" & TestQ("changes") & ":[]}" into tCalls[1]["input"]
   put TestStartServer("200 OK", TestToolAnswer(tCalls)) into tPort
   TestQueueAnswer "200 OK", TestAnswer("Then do it this way.")
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   revIDESetPreference "cXTalkAssistant,build", false
   dispatch "xtaNewConversation" to stack kMain
   TestAssert "the footer says it cannot change stacks", field "uiFooter" of stack kWindow begins with "The model reads and answers"
   put "Add a button" into field "Prompt" of stack kWindow
   TestAnswerAsks "yes"
   dispatch "xtaSendPrompt" to stack kMain
   put xtaJsonParse(TestBodyOf(sRequests[1])) into tDoc
   put empty into tText
   repeat with tIndex = 1 to xtaJsonCount(xtaJsonMember(tDoc, "tools"))
      put xtaJsonText(xtaJsonGet(tDoc, "tools/" & tIndex & "/name")) & comma after tText
   end repeat
   TestDiagnostic tText
   TestAssert "the tools that change, run and save are not sent", tText is "lookup_dictionary,check_code,read_stack,last_error,debug_state,look_at_card,"
   put xtaJsonText(xtaJsonGet(xtaJsonParse(TestBodyOf(sRequests[2])), "messages/3/content/1/content")) into tText
   TestAssert "a call to one is refused", tText contains "has not let the assistant change stacks" and sAsked is empty
end TestChangingStacksCanBeTurnedOff

--------------------------------------------------------------------------------
-- The last error

-- Turned on in an earlier session, the hook is in place from the start,
-- and nothing else is loaded
on TestErrorHookFromTheStart
   revIDESetPreference "cXTalkAssistant,enabled", true
   send "extensionInitialize" to stack kMain
   TestAssert "the error hook is in the message path", the long id of stack kErrorHook is among the lines of the frontScripts
   TestAssert "the core is not loaded", there is not a stack kCore
   TestAssert "no window", there is not a stack kWindow
end TestErrorHookFromTheStart

on TestErrorHookPassesItOn
   local tOldDefault, tErrors
   TestOpenTheWindow "http://127.0.0.1:1"
   put the defaultStack into tOldDefault
   create invisible stack "xtaTestErrors"
   set the defaultStack to "xtaTestErrors"
   create button "Catcher"
   set the script of button "Catcher" to "on errorDialog pA, pB" & return & "set the cGot of me to pA & " & quote & "|" & quote & " & pB" & return & "end errorDialog"
   set the defaultStack to tOldDefault
   dispatch "errorDialog" to button "Catcher" of stack "xtaTestErrors" with "573,2,1,frob", "parse"
   TestAssert "passed on as it came", the cGot of button "Catcher" of stack "xtaTestErrors" is "573,2,1,frob|parse"
   dispatch function "xtaErrorHookErrors" to stack kErrorHook
   put the result into tErrors
   TestAssert "and noted", tErrors[1]["trace"] is "573,2,1,frob" \
         and tErrors[1]["target"] is the long id of button "Catcher" of stack "xtaTestErrors"
   delete stack "xtaTestErrors"
end TestErrorHookPassesItOn

-- With Script Debug Mode on (the IDE's default) an error goes to the
-- debugger as traceError, and errorDialog never comes: the hook notes that
-- too, passes it on as it came, and leaves out the traceError the engine
-- sends with no error as it leaves each handler above the one that failed
-- and the same error on its way to the error window after it
on TestErrorHookNotesTheDebuggersErrors
   local tOldDefault, tErrors, tTrace
   TestOpenTheWindow "http://127.0.0.1:1"
   put the defaultStack into tOldDefault
   create invisible stack "xtaTestErrors"
   set the defaultStack to "xtaTestErrors"
   create button "Catcher"
   set the script of button "Catcher" to "on traceError pA, pB, pC, pD" & return & "set the cGot of me to pA & " & quote & "|" & quote & " & pB & " & quote & "|" & quote & " & pC & " & quote & "|" & quote & " & pD" & return & "end traceError" & return & \
         "on errorDialog" & return & "end errorDialog"
   set the defaultStack to tOldDefault
   put "219,3,11,tX" & return & "353,0,0," & the long id of button "Catcher" of stack "xtaTestErrors" into tTrace
   dispatch "traceError" to button "Catcher" of stack "xtaTestErrors" with "mouseUp", 3, 11, tTrace
   TestAssert "passed on as it came", the cGot of button "Catcher" of stack "xtaTestErrors" is ("mouseUp|3|11|" & tTrace)
   dispatch "traceError" to button "Catcher" of stack "xtaTestErrors" with "mouseUp", 2, 1, empty
   dispatch "errorDialog" to button "Catcher" of stack "xtaTestErrors" with tTrace
   dispatch function "xtaErrorHookErrors" to stack kErrorHook
   put the result into tErrors
   TestAssert "noted once", the number of elements of tErrors is 1
   TestAssert "with its trace and object", tErrors[1]["trace"] is tTrace \
         and tErrors[1]["target"] is the long id of button "Catcher" of stack "xtaTestErrors"
   delete stack "xtaTestErrors"
end TestErrorHookNotesTheDebuggersErrors

on TestExplainTheLastError
   local tPort, tOldDefault, tBody, tDoc, tText, tButton
   put TestStartServer("200 OK", TestAnswer("tX is not declared.")) into tPort
   TestOpenTheWindow "http://127.0.0.1:" & tPort
   put the defaultStack into tOldDefault
   create invisible stack "xtaTestErr"
   -- The test runner fails a test on an errorDialog that reaches it
   set the script of stack "xtaTestErr" to "on errorDialog" & return & "end errorDialog"
   set the defaultStack to "xtaTestErr"
   create button "Bad"
   set the script of button "Bad" to "on mouseUp" & return & "   local tY" & return & "   put tX + 1 into tY" & return & "end mouseUp"
   put the long id of button "Bad" into tButton
   -- An error of one of the IDE's windows after it is not the user's
   create invisible stack "revXtaTestIDE"
   set the script of stack "revXtaTestIDE" to "on errorDialog" & return & "end errorDialog"
   set the defaultStack to "revXtaTestIDE"
   create button "Theirs"
   set the defaultStack to tOldDefault
   dispatch "errorDialog" to tButton with "219,3,11,tX" & return & "241,3,1,mouseUp" & return & "353,0,0," & tButton
   dispatch "errorDialog" to button "Theirs" of stack "revXtaTestIDE" with "91,1,1" & return & "353,0,0," & the long id of button "Theirs" of stack "revXtaTestIDE"
   dispatch "xtaMoreMenuPick" to stack kMain with "Explain the Last Error"
   TestAssert "asked", sServed is 1
   put xtaJsonParse(TestRequestBody()) into tDoc
   put xtaJsonText(xtaJsonGet(tDoc, "messages/1/content")) into tText
   TestDiagnostic tText
   TestAssert "the question", tText begins with "Explain the last error I hit, and how to fix it."
   TestAssert "the error", tText contains "The last error the IDE showed the user" and tText contains "error 219" \
         and tText contains ("in the script of" && tButton)
   TestAssert "the lines around it", tText contains (">3:    put tX + 1 into tY") and tText contains (" 1: on mouseUp")
   TestAssert "the window says what went with it", field "Conversation" of stack kWindow contains \
         ("(with the last error, in button" && quote & "Bad" & quote && "of stack" && quote & "xtaTestErr" & quote & ")")
   delete stack "xtaTestErr"
   delete stack "revXtaTestIDE"
end TestExplainTheLastError

-- Turns the assistant on, as the user would, for Anthropic with a model and
-- a key from the environment, and opens its window.
private command TestOpenTheWindow pBaseUrl
   revIDESetPreference "cXTalkAssistant,enabled", true
   revIDESetPreference "cXTalkAssistant,provider", "anthropic"
   revIDESetPreference "cXTalkAssistant,model,anthropic", "test-model"
   revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", pBaseUrl
   put "sk-from-env" into $ANTHROPIC_API_KEY
   dispatch "xtalkAssistantMenuPick" to stack kMain
end TestOpenTheWindow

-- As TestOpenTheWindow, with no model chosen yet
private command TestOpenTheWindowWithoutAModel pBaseUrl
   TestOpenTheWindow pBaseUrl
   revIDESetPreference "cXTalkAssistant,model,anthropic", empty
   dispatch "xtalkAssistantMenuPick" to stack kMain
end TestOpenTheWindowWithoutAModel

-- Anthropic's model list: newest first
private function TestModelList
   return "{" & TestQ("data") & ":[{" & TestQ("id") & ":" & TestQ("claude-opus-9") & "},{" & \
         TestQ("id") & ":" & TestQ("claude-sonnet-9") & "},{" & TestQ("id") & ":" & TestQ("claude-haiku-9") & "}]," & \
         TestQ("has_more") & ":false}"
end TestModelList

-- A JSON string (the core's writer is not loaded before the window is)
private function TestQ pText
   replace numToChar(92) with numToChar(92) & numToChar(92) in pText
   replace quote with numToChar(92) & quote in pText
   replace return with numToChar(92) & "n" in pText
   return quote & pText & quote
end TestQ

--------------------------------------------------------------------------------
-- The window's bar, answered as the user answers it

-- From now on, each time the bar asks, clicks the button of the next of
-- pAnswers ("yes", "session" or "no", by items). What it asked is kept in
-- sAsked, a line each: the question, the details (return as \n), whether
-- the button that allows it for the session was there, what the pill
-- said, and whether the conversation was above the bar.
private command TestAnswerAsks pAnswers
   put pAnswers into sAnswers
   put empty into sAsked
   send "xtaTestAnswerTick" to me in 20 milliseconds
end TestAnswerAsks

on xtaTestAnswerTick
   local tAnswer, tDetail, tAbove
   if sAnswers is empty or there is not a stack kWindow then
      exit xtaTestAnswerTick
   end if
   if not the visible of graphic "AskPanel" of stack kWindow then
      send "xtaTestAnswerTick" to me in 20 milliseconds
      exit xtaTestAnswerTick
   end if
   put field "AskDetail" of stack kWindow into tDetail
   replace return with "\n" in tDetail
   replace comma with ";" in tDetail
   put item 4 of the rect of graphic "ConversationPanel" of stack kWindow <= item 2 of the rect of graphic "AskPanel" of stack kWindow into tAbove
   put field "AskTitle" of stack kWindow & comma & tDetail & comma & the visible of button "AskSession" of stack kWindow & comma & \
         field "Pill" of stack kWindow & comma & tAbove & return after sAsked
   put item 1 of sAnswers into tAnswer
   delete item 1 of sAnswers
   switch tAnswer
      case "yes"
         send "mouseUp 1" to button "AskYes" of stack kWindow
         break
      case "session"
         send "mouseUp 1" to button "AskSession" of stack kWindow
         break
      default
         send "mouseUp 1" to button "AskNo" of stack kWindow
   end switch
   -- The bar goes within one turn of its wait (50 ms), so the next ask is
   -- looked for after it
   if sAnswers is not empty then
      send "xtaTestAnswerTick" to me in 200 milliseconds
   end if
end xtaTestAnswerTick

--------------------------------------------------------------------------------
-- A server of this process that answers as the provider does

private function TestStartServer pStatus, pBody
   put empty into sResponses
   TestQueueAnswer pStatus, pBody
   put 0 into sServed
   put empty into sRequest
   put empty into sRequests
   put empty into sDuring
   put 0 into sDelay
   put false into sPressEscape
   put 0 into sPicturesOffAt
   TestSkipIfNot "sockets"
   accept connections on port 0 with message "xtaTestServerAccept"
   return it
end TestStartServer

-- Another answer, for the request after those already queued
private command TestQueueAnswer pStatus, pBody
   local tBytes
   put textEncode(pBody, "UTF-8") into tBytes
   put "HTTP/1.1" && pStatus & crlf & "Content-Type: application/json" & crlf & \
         "Content-Length:" && the number of bytes of tBytes & crlf & "Connection: close" & crlf & crlf & tBytes \
         into sResponses[the number of elements of sResponses + 1]
end TestQueueAnswer

on xtaTestServerAccept pSocket
   read from socket pSocket until crlf & crlf with message "xtaTestServerHeaders"
end xtaTestServerAccept

on xtaTestServerHeaders pSocket, pData
   local tLength, tLine
   put pData into sRequest
   repeat for each line tLine in pData
      if tLine begins with "Content-Length:" then
         put word 2 of tLine into tLength
      end if
   end repeat
   if tLength is an integer and tLength > 0 then
      read from socket pSocket for tLength bytes with message "xtaTestServerBody"
   else
      xtaTestServerBody pSocket, empty
   end if
end xtaTestServerHeaders

on xtaTestServerBody pSocket, pData
   local tAnswer
   put pData after sRequest
   add 1 to sServed
   put sRequest into sRequests[sServed]
   if sServed <= the number of elements of sResponses then
      put sResponses[sServed] into tAnswer
   else
      put sResponses[the number of elements of sResponses] into tAnswer
   end if
   TestNoteTheWindow "asked"
   -- Escape, as the user presses it in the window while it waits
   if sPressEscape is true and there is a stack kWindow then
      put false into sPressEscape
      send "escapeKey" to field "Prompt" of stack kWindow
      TestNoteTheWindow "escaped"
   end if
   -- The pictures switch, as the user turns it off in the Settings
   if sServed is sPicturesOffAt then
      revIDESetPreference "cXTalkAssistant,pictures", false
   end if
   if sDelay > 0 then
      put tAnswer into sPending[pSocket]
      send "xtaTestServerWrite" && quote & pSocket & quote to me in sDelay milliseconds
      exit xtaTestServerBody
   end if
   write tAnswer to socket pSocket
   close socket pSocket
end xtaTestServerBody

-- Notes the spinner's angle every 100 milliseconds while the row shows
on xtaTestSample
   if there is not a stack kWindow then
      exit xtaTestSample
   end if
   if the visible of graphic "ActivitySpin" of stack kWindow then
      put true into sAngles[the startAngle of graphic "ActivitySpin" of stack kWindow]
   end if
   if sServed is 0 or the visible of graphic "ActivitySpin" of stack kWindow then
      send "xtaTestSample" to me in 100 milliseconds
   end if
end xtaTestSample

-- The answer the server held back (sDelay), as a model takes its time
on xtaTestServerWrite pSocket
   TestNoteTheWindow "answered"
   write sPending[pSocket] to socket pSocket
   close socket pSocket
   delete variable sPending[pSocket]
end xtaTestServerWrite

-- What the window shows as the request sServed is on its way, kept in
-- sDuring[sServed][pWhen]
private command TestNoteTheWindow pWhen
   if there is not a stack kWindow then
      exit TestNoteTheWindow
   end if
   put the visible of field "Activity" of stack kWindow into sDuring[sServed][pWhen]["shown"]
   put field "Activity" of stack kWindow into sDuring[sServed][pWhen]["activity"]
   put field "ActivityTime" of stack kWindow into sDuring[sServed][pWhen]["time"]
   put the startAngle of graphic "ActivitySpin" of stack kWindow into sDuring[sServed][pWhen]["angle"]
   put field "Pill" of stack kWindow into sDuring[sServed][pWhen]["pill"]
   put field "Status" of stack kWindow into sDuring[sServed][pWhen]["status"]
   put the label of button "Send" of stack kWindow into sDuring[sServed][pWhen]["send"]
end TestNoteTheWindow

private function TestRequestHeader pName
   local tLine
   repeat for each line tLine in sRequest
      replace numToChar(13) with empty in tLine
      if tLine is empty then
         exit repeat
      end if
      if tLine begins with (pName & ":") then
         return word 2 to -1 of tLine
      end if
   end repeat
   return empty
end TestRequestHeader

private function TestRequestBody
   return TestBodyOf(sRequest)
end TestRequestBody

private function TestBodyOf pRequest
   local tAt
   put offset(crlf & crlf, pRequest) into tAt
   return textDecode(char tAt + 4 to -1 of pRequest, "UTF-8")
end TestBodyOf

-- An answer as Anthropic gives it, with pText as what the model said
private function TestAnswer pText
   return "{" & TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & \
         TestQ("text") & ":" & TestQ(pText) & "}]," & TestQ("stop_reason") & ":" & TestQ("end_turn") & "," & \
         TestQ("usage") & ":{" & TestQ("input_tokens") & ":10," & TestQ("output_tokens") & ":20," & \
         TestQ("cache_read_input_tokens") & ":5000}}"
end TestAnswer

-- An answer as Anthropic gives it that asks for the tools pCalls (keys 1 to
-- N, each with "name" and "input", a JSON object), with the ids toolu_1 to
-- toolu_N
private function TestToolAnswer pCalls
   local tContent, tIndex
   repeat with tIndex = 1 to the number of elements of pCalls
      if tContent is not empty then
         put comma after tContent
      end if
      put "{" & TestQ("type") & ":" & TestQ("tool_use") & "," & TestQ("id") & ":" & TestQ("toolu_" & tIndex) & "," & \
            TestQ("name") & ":" & TestQ(pCalls[tIndex]["name"]) & "," & TestQ("input") & ":" & pCalls[tIndex]["input"] & "}" after tContent
   end repeat
   return "{" & TestQ("content") & ":[" & tContent & "]," & TestQ("stop_reason") & ":" & TestQ("tool_use") & "," & \
         TestQ("usage") & ":{" & TestQ("input_tokens") & ":10," & TestQ("output_tokens") & ":20}}"
end TestToolAnswer

-- An answer as Anthropic gives it that stopped for pStop ("max_tokens",
-- "refusal"): pContent is its content blocks, and pDetails its
-- stop_details, null when empty (JSON both)
private function TestStopAnswer pContent, pStop, pDetails
   if pDetails is empty then
      put "null" into pDetails
   end if
   return "{" & TestQ("content") & ":[" & pContent & "]," & TestQ("stop_reason") & ":" & TestQ(pStop) & "," & \
         TestQ("stop_details") & ":" & pDetails & "," & \
         TestQ("usage") & ":{" & TestQ("input_tokens") & ":10," & TestQ("output_tokens") & ":16000}}"
end TestStopAnswer

-- Content blocks as Anthropic gives them: text, a call (with the id
-- toolu_pNumber, and pInput a JSON object), and the thinking of a model
-- that thinks before it answers (empty: Anthropic leaves it out unless
-- asked)
private function TestTextBlock pText
   return "{" & TestQ("type") & ":" & TestQ("text") & "," & TestQ("text") & ":" & TestQ(pText) & "}"
end TestTextBlock

private function TestCallBlock pName, pInput, pNumber
   return "{" & TestQ("type") & ":" & TestQ("tool_use") & "," & TestQ("id") & ":" & TestQ("toolu_" & pNumber) & "," & \
         TestQ("name") & ":" & TestQ(pName) & "," & TestQ("input") & ":" & pInput & "}"
end TestCallBlock

private function TestThinkingBlock
   return "{" & TestQ("type") & ":" & TestQ("thinking") & "," & TestQ("thinking") & ":" & TestQ(empty) & "," & \
         TestQ("signature") & ":" & TestQ("c2ln") & "}"
end TestThinkingBlock

-- pCode in a fenced block marked pLang
private function TestBlock pLang, pCode
   return "```" & pLang & return & pCode & return & "```"
end TestBlock

-- How many times pNeedle is in pText
private function TestCount pText, pNeedle
   local tCount, tSkip, tAt
   put 0 into tCount
   put 0 into tSkip
   repeat forever
      put offset(pNeedle, pText, tSkip) into tAt
      if tAt is 0 then
         exit repeat
      end if
      add 1 to tCount
      add tAt + the number of chars of pNeedle - 1 to tSkip
   end repeat
   return tCount
end TestCount

-- The activity row's clock ("1:05") in seconds
private function TestClockSeconds pTime
   set the itemDelimiter to ":"
   return item 1 of pTime * 60 + item 2 of pTime
end TestClockSeconds

-- True when what is put on the clipboard can be read back (not in a
-- headless run on Linux, which has no clipboard)
private function TestClipboardWorks
   local tProbe, tError
   put "xta-clipboard-" & the milliseconds into tProbe
   try
      set the clipboardData["text"] to tProbe
      return the clipboardData["text"] is tProbe
   catch tError
      return false
   end try
end TestClipboardWorks
