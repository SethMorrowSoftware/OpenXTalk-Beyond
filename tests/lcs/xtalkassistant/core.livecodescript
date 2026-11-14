script "TestXTalkAssistantCore"
-- OXT-Beyond: tests of the xTalk Assistant plugin's core
-- (ide/Extensions/org.openxtalk.plugin.xtalkassistant/xtalkassistant-core.livecodescript):
-- its JSON reader and writer, the requests and answers of both providers,
-- and whole round trips through libURL to a server of this process that
-- answers as the providers do. No key and no internet are needed.

-- The test server's answer, the request it read, and how long libURL
-- would wait for the answer to it (the socketTimeoutInterval then)
local sResponse, sRequest, sWaitDuring
-- The routed test server (TestStartRoutes): its answers by request line
-- ("GET /api/v1/models"), the request lines it read, one per line, and
-- the body of each, by number
local sRoutes, sRouteLog, sRouteBodies

on TestSetup
   local tCore, tLibUrl
   put TestGetIDERepositoryPath() & "/Extensions/org.openxtalk.plugin.xtalkassistant/xtalkassistant-core.livecodescript" into tCore
   start using stack tCore
   if not TestIsInStandalone() then
      put TestGetEngineRepositoryPath() & "/ide-support/revliburl.livecodescript" into tLibUrl
      send "extensionInitialize" to stack tLibUrl
   end if
end TestSetup

--------------------------------------------------------------------------------
-- JSON

on TestJsonStringEscapes
   local tText, tJson
   TestAssert "plain text", xtaJsonString("abc") is (quote & "abc" & quote)
   put quote & numToChar(92) & numToChar(10) & numToChar(13) & numToChar(9) & numToChar(1) into tText
   put xtaJsonString(tText) into tJson
   TestDiagnostic tJson
   TestAssert "quote, backslash and control characters escaped", \
         tJson is (quote & numToChar(92) & quote & numToChar(92) & numToChar(92) & \
         numToChar(92) & "n" & numToChar(92) & "r" & numToChar(92) & "t" & \
         numToChar(92) & "u0001" & quote)
   -- A quote with a combining mark after it is still escaped
   put "a" & quote & numToCodepoint(769) & "b" into tText
   TestAssert "quote before a combining mark", xtaJsonText(xtaJsonParse(xtaJsonString(tText))) is tText
   put "caf" & numToCodepoint(233) & " " & numToCodepoint(128512) into tText
   TestAssert "non-ASCII text goes as it is", xtaJsonString(tText) is (quote & tText & quote)
   TestAssert "round trip", xtaJsonText(xtaJsonParse(xtaJsonString(tText))) is tText
end TestJsonStringEscapes

on TestJsonParseValues
   local tJson, tDoc, tList, tB
   put numToChar(92) into tB
   put "{ " & quote & "a" & quote & ": [1, -2.5e3, true, false, null, " & quote & "x" & tB & "n" & tB & quote & "y" & quote & "], " & \
         quote & "b" & quote & ":{" & quote & "c" & quote & ":" & quote & tB & "u00e9" & tB & "ud83d" & tB & "ude00" & quote & "}," & \
         quote & "z" & quote & ":" & quote & quote & "}" into tJson
   put xtaJsonParse(tJson) into tDoc
   TestAssert "an object", xtaJsonType(tDoc) is "object"
   TestAssert "three members", xtaJsonCount(tDoc) is 3
   TestAssert "member order", tDoc["names"][1] is "a" and tDoc["names"][2] is "b" and tDoc["names"][3] is "z"
   put xtaJsonMember(tDoc, "a") into tList
   TestAssert "an array of six", xtaJsonType(tList) is "array" and xtaJsonCount(tList) is 6
   TestAssert "integer", xtaJsonText(xtaJsonItem(tList, 1)) is "1"
   TestAssert "number as written", xtaJsonText(xtaJsonItem(tList, 2)) is "-2.5e3"
   TestAssert "true", xtaJsonType(xtaJsonItem(tList, 3)) is "boolean" and xtaJsonText(xtaJsonItem(tList, 3)) is "true"
   TestAssert "false", xtaJsonText(xtaJsonItem(tList, 4)) is "false"
   TestAssert "null", xtaJsonType(xtaJsonItem(tList, 5)) is "null"
   TestAssert "escapes", xtaJsonText(xtaJsonItem(tList, 6)) is ("x" & numToChar(10) & quote & "y")
   TestAssert "\u escapes and a surrogate pair", \
         xtaJsonText(xtaJsonGet(tDoc, "b/c")) is (numToCodepoint(233) & numToCodepoint(128512))
   TestAssert "empty string", xtaJsonType(xtaJsonMember(tDoc, "z")) is "string" and xtaJsonText(xtaJsonMember(tDoc, "z")) is empty
   TestAssert "path into an array", xtaJsonText(xtaJsonGet(tDoc, "a/6")) is ("x" & numToChar(10) & quote & "y")
   TestAssert "missing member", xtaJsonType(xtaJsonGet(tDoc, "b/nope")) is "missing"
   TestAssert "missing item", xtaJsonType(xtaJsonGet(tDoc, "a/7")) is "missing"
   TestAssert "raw text of a value", xtaJsonRaw(tJson, xtaJsonMember(tDoc, "b")) is \
         ("{" & quote & "c" & quote & ":" & quote & tB & "u00e9" & tB & "ud83d" & tB & "ude00" & quote & "}")
   TestAssert "a lone surrogate", xtaJsonText(xtaJsonParse(quote & tB & "ud83d" & quote)) is numToCodepoint(65533)
   TestAssert "text before and after a long run without escapes", \
         xtaJsonText(xtaJsonParse(quote & "abc" & tB & tB & "def" & quote)) is ("abc" & tB & "def")
end TestJsonParseValues

on TestJsonParseRejects
   local tBad, tCount, tError, tItem
   put "{" & return & "{" & quote & "a" & quote & "}" & return & quote & "abc" & return & "[1,]" & return & \
         "[1 2]" & return & "{" & quote & "a" & quote & ":1,}" & return & "tru" & return & "01" & return & "1." & return & \
         "{" & quote & "a" & quote & ":1} x" & return & quote & numToChar(92) & "q" & quote & return & "[" & return & \
         "{1:2}" & return & quote & numToChar(92) & "u12" & quote into tBad
   put 0 into tCount
   repeat for each line tItem in tBad
      put empty into tError
      try
         get xtaJsonParse(tItem)
      catch tError
      end try
      if tError begins with "xTalk Assistant: the JSON is not valid" then
         add 1 to tCount
      else
         TestDiagnostic "accepted:" && tItem
      end if
   end repeat
   TestAssert "every malformed text refused", tCount is the number of lines of tBad
   put empty into tError
   try
      get xtaJsonParse(empty)
   catch tError
   end try
   TestAssert "empty text refused", tError begins with "xTalk Assistant: the JSON is not valid"
end TestJsonParseRejects

on TestJsonParseLongText
   local tText, tDoc
   repeat 20000
      put "line of text " & quote & "quoted" & quote & numToChar(10) after tText
   end repeat
   put xtaJsonParse("{" & quote & "t" & quote & ":" & xtaJsonString(tText) & "}") into tDoc
   TestAssert "a long string round trip", xtaJsonText(xtaJsonMember(tDoc, "t")) is tText
end TestJsonParseLongText

--------------------------------------------------------------------------------
-- Requests

private function TestTurns
   local tTurns
   put "user" into tTurns[1]["role"]
   put "Write a mouseUp handler" into tTurns[1]["text"]
   put "assistant" into tTurns[2]["role"]
   put empty into tTurns[2]["text"]
   put "assistant" into tTurns[3]["role"]
   put "on mouseUp" & return & "end mouseUp" into tTurns[3]["text"]
   put "user" into tTurns[4]["role"]
   put "Thanks" into tTurns[4]["text"]
   return tTurns
end TestTurns

on TestRequestBodyAnthropic
   local tBody, tDoc, tMessages
   put xtaRequestBody("anthropic", " some-model ", "Be brief.", TestTurns(), empty) into tBody
   TestDiagnostic tBody
   put xtaJsonParse(tBody) into tDoc
   TestAssert "model, trimmed", xtaJsonText(xtaJsonMember(tDoc, "model")) is "some-model"
   TestAssert "max_tokens is a number", xtaJsonType(xtaJsonMember(tDoc, "max_tokens")) is "number"
   TestAssert "max_tokens default", xtaJsonText(xtaJsonMember(tDoc, "max_tokens")) is 16000
   TestAssert "system", xtaJsonText(xtaJsonMember(tDoc, "system")) is "Be brief."
   put xtaJsonMember(tDoc, "messages") into tMessages
   TestAssert "the empty turn is left out", xtaJsonCount(tMessages) is 3
   TestAssert "roles", xtaJsonText(xtaJsonGet(tMessages, "1/role")) is "user" \
         and xtaJsonText(xtaJsonGet(tMessages, "2/role")) is "assistant" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/role")) is "user"
   TestAssert "text with a return", xtaJsonText(xtaJsonGet(tMessages, "2/content")) is ("on mouseUp" & return & "end mouseUp")
   put xtaRequestBody("anthropic", "m", empty, TestTurns(), 1000) into tBody
   put xtaJsonParse(tBody) into tDoc
   TestAssert "max_tokens given", xtaJsonText(xtaJsonMember(tDoc, "max_tokens")) is 1000
   TestAssert "no system when there is none", xtaJsonType(xtaJsonMember(tDoc, "system")) is "missing"
end TestRequestBodyAnthropic

on TestRequestBodyOpenAI
   local tBody, tDoc, tMessages
   put xtaRequestBody("openai", "some-model", "Be brief.", TestTurns(), 1000) into tBody
   TestDiagnostic tBody
   put xtaJsonParse(tBody) into tDoc
   put xtaJsonMember(tDoc, "messages") into tMessages
   TestAssert "the system prompt is the first message", xtaJsonText(xtaJsonGet(tMessages, "1/role")) is "system" \
         and xtaJsonText(xtaJsonGet(tMessages, "1/content")) is "Be brief."
   TestAssert "then the three turns", xtaJsonCount(tMessages) is 4
   TestAssert "the limit as OpenAI's API takes it", xtaJsonText(xtaJsonMember(tDoc, "max_completion_tokens")) is 1000 \
         and xtaJsonType(xtaJsonMember(tDoc, "max_tokens")) is "missing"
   TestAssert "no system member", xtaJsonType(xtaJsonMember(tDoc, "system")) is "missing"
   -- No limit set: none sent, as before; a local server's name for it
   put xtaJsonParse(xtaRequestBody("openai", "some-model", "Be brief.", TestTurns(), empty)) into tDoc
   TestAssert "no limit set, none sent", xtaJsonType(xtaJsonMember(tDoc, "max_completion_tokens")) is "missing" \
         and xtaJsonType(xtaJsonMember(tDoc, "max_tokens")) is "missing"
   put xtaJsonParse(xtaRequestBody("openai", "some-model", "Be brief.", TestTurns(), 500, empty, "max_tokens")) into tDoc
   TestAssert "a local server's", xtaJsonText(xtaJsonMember(tDoc, "max_tokens")) is 500
end TestRequestBodyOpenAI

-- The longest answer a request asks for: what the user set, otherwise
-- Anthropic's default, and none for OpenAI, whose model decides. The
-- default leaves room to think: Anthropic's models think before they
-- answer, the thinking counts toward the limit, and with 0.2.5-rc.4's
-- 4096 a question that built a stack came back empty.
on TestMaxTokens
   TestAssert "anthropic, none set", xtaMaxTokens("anthropic", empty) is 16000
   TestAssert "anthropic, set", xtaMaxTokens("anthropic", 2048) is 2048
   TestAssert "a limit that is not one is none", xtaMaxTokens("anthropic", "lots") is 16000 \
         and xtaMaxTokens("anthropic", 0) is 16000 and xtaMaxTokens("anthropic", -5) is 16000
   TestAssert "openai, none set", xtaMaxTokens("openai", empty) is empty
   TestAssert "openai, set", xtaMaxTokens("openai", 500) is 500
end TestMaxTokens

-- How long a request may go without data: what the user set, otherwise
-- ten minutes, and longer for an answer given more room than Anthropic's
-- libraries would wait ten minutes for, up to an hour
on TestRequestWait
   TestAssert "what the user set", xtaRequestWait(60, 32000) is 60
   TestAssert "ten minutes by default", xtaRequestWait(empty, empty) is 600 and xtaRequestWait(empty, 16000) is 600
   TestAssert "longer for more room", xtaRequestWait(empty, 32000) is 900
   TestAssert "up to an hour", xtaRequestWait(empty, 1000000) is 3600
   TestAssert "a wait that is not one is none", xtaRequestWait("soon", 16000) is 600 and xtaRequestWait(0, 32000) is 900
end TestRequestWait

-- The guide is marked for Anthropic's cache, and the notes after it are not
private function TestSystemParts
   local tSystem
   put "The guide." into tSystem[1]["text"]
   put true into tSystem[1]["cache"]
   put "The notes." into tSystem[2]["text"]
   put false into tSystem[2]["cache"]
   put empty into tSystem[3]["text"]
   return tSystem
end TestSystemParts

on TestRequestBodySystemParts
   local tBody, tDoc, tSystem
   put xtaRequestBody("anthropic", "m", TestSystemParts(), TestTurns(), empty) into tBody
   TestDiagnostic tBody
   put xtaJsonParse(tBody) into tDoc
   put xtaJsonMember(tDoc, "system") into tSystem
   TestAssert "anthropic: the system is two blocks (the empty part is left out)", \
         xtaJsonType(tSystem) is "array" and xtaJsonCount(tSystem) is 2
   TestAssert "anthropic: the guide first, as text", xtaJsonText(xtaJsonGet(tSystem, "1/type")) is "text" \
         and xtaJsonText(xtaJsonGet(tSystem, "1/text")) is "The guide."
   TestAssert "anthropic: the guide is marked for the cache", xtaJsonText(xtaJsonGet(tSystem, "1/cache_control/type")) is "ephemeral"
   TestAssert "anthropic: the notes are not", xtaJsonText(xtaJsonGet(tSystem, "2/text")) is "The notes." \
         and xtaJsonType(xtaJsonGet(tSystem, "2/cache_control")) is "missing"

   put xtaRequestBody("openai", "m", TestSystemParts(), TestTurns(), empty) into tBody
   put xtaJsonParse(tBody) into tDoc
   TestAssert "openai: one system message, the parts joined in order", \
         xtaJsonText(xtaJsonGet(tDoc, "messages/1/content")) is ("The guide." & return & return & "The notes.")
   TestAssert "openai: no cache marks", not (tBody contains "cache_control")

   -- One part that is not to be cached goes as the plain string it always was
   put empty into tSystem
   put "Be brief." into tSystem[1]["text"]
   TestAssert "one part, not cached: as a text", \
         xtaRequestBody("anthropic", "m", tSystem, TestTurns(), empty) is xtaRequestBody("anthropic", "m", "Be brief.", TestTurns(), empty)
end TestRequestBodySystemParts

on TestRequestBodyNeedsModel
   local tError
   try
      get xtaRequestBody("anthropic", "  ", empty, TestTurns(), empty)
   catch tError
   end try
   TestAssert "no model is refused", tError contains "no model"
end TestRequestBodyNeedsModel

-- A question, an answer that asked for two tools, their results (the
-- second failed), the answer after them, and an answer whose call has no
-- result, with an id and arguments no API takes
private function TestToolTurns
   local tTurns
   put "user" into tTurns[1]["role"]
   put "What does put do?" into tTurns[1]["text"]
   put "assistant" into tTurns[2]["role"]
   put "Let me look." into tTurns[2]["text"]
   put "toolu_01" into tTurns[2]["calls"][1]["id"]
   put "lookup_dictionary" into tTurns[2]["calls"][1]["name"]
   put "{" & TestQ("term") & ":" & TestQ("put") & "}" into tTurns[2]["calls"][1]["input"]
   put "toolu_02" into tTurns[2]["calls"][2]["id"]
   put "check_code" into tTurns[2]["calls"][2]["name"]
   put "{" & TestQ("code") & ":" & TestQ("put 1") & "}" into tTurns[2]["calls"][2]["input"]
   put "user" into tTurns[3]["role"]
   put "tools" into tTurns[3]["kind"]
   put "put: places a value" into tTurns[3]["results"][1]["text"]
   put false into tTurns[3]["results"][1]["error"]
   put "does not compile" into tTurns[3]["results"][2]["text"]
   put true into tTurns[3]["results"][2]["error"]
   put "assistant" into tTurns[4]["role"]
   put "It places a value." into tTurns[4]["text"]
   put "user" into tTurns[5]["role"]
   put "And my stack?" into tTurns[5]["text"]
   put "assistant" into tTurns[6]["role"]
   put empty into tTurns[6]["text"]
   put "bad id!" into tTurns[6]["calls"][1]["id"]
   put "read_stack" into tTurns[6]["calls"][1]["name"]
   put "not json" into tTurns[6]["calls"][1]["input"]
   put "user" into tTurns[7]["role"]
   put "Thanks" into tTurns[7]["text"]
   return tTurns
end TestToolTurns

private function TestTools
   local tTools
   put "lookup_dictionary" into tTools[1]["name"]
   put "Looks up the Dictionary." into tTools[1]["description"]
   put "{" & TestQ("type") & ":" & TestQ("object") & "," & TestQ("properties") & ":{" & TestQ("term") & ":{" & TestQ("type") & ":" & TestQ("string") & "}}}" into tTools[1]["schema"]
   put "last_error" into tTools[2]["name"]
   put "The last error." into tTools[2]["description"]
   put "{" & TestQ("type") & ":" & TestQ("object") & "," & TestQ("properties") & ":{}}" into tTools[2]["schema"]
   return tTools
end TestTools

on TestRequestBodyToolsAnthropic
   local tBody, tDoc, tMessages, tTools
   put xtaRequestBody("anthropic", "m", "Be brief.", TestToolTurns(), empty, TestTools()) into tBody
   TestDiagnostic tBody
   put xtaJsonParse(tBody) into tDoc
   put xtaJsonMember(tDoc, "tools") into tTools
   TestAssert "the tools, with their schemas", xtaJsonCount(tTools) is 2 and xtaJsonText(xtaJsonGet(tTools, "1/name")) is "lookup_dictionary" \
         and xtaJsonText(xtaJsonGet(tTools, "1/description")) is "Looks up the Dictionary." \
         and xtaJsonText(xtaJsonGet(tTools, "1/input_schema/properties/term/type")) is "string"
   put xtaJsonMember(tDoc, "messages") into tMessages
   -- The results with no call and the question after them are two user
   -- messages, which Anthropic takes as one
   TestAssert "eight messages", xtaJsonCount(tMessages) is 8
   TestAssert "the answer's text, then its calls", xtaJsonText(xtaJsonGet(tMessages, "2/content/1/type")) is "text" \
         and xtaJsonText(xtaJsonGet(tMessages, "2/content/1/text")) is "Let me look." \
         and xtaJsonText(xtaJsonGet(tMessages, "2/content/2/type")) is "tool_use" \
         and xtaJsonText(xtaJsonGet(tMessages, "2/content/2/id")) is "toolu_01" \
         and xtaJsonText(xtaJsonGet(tMessages, "2/content/2/name")) is "lookup_dictionary" \
         and xtaJsonText(xtaJsonGet(tMessages, "2/content/2/input/term")) is "put" \
         and xtaJsonText(xtaJsonGet(tMessages, "2/content/3/id")) is "toolu_02"
   TestAssert "the results, in a user message", xtaJsonText(xtaJsonGet(tMessages, "3/role")) is "user" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/type")) is "tool_result" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/tool_use_id")) is "toolu_01" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/content")) is "put: places a value" \
         and xtaJsonType(xtaJsonGet(tMessages, "3/content/1/is_error")) is "missing"
   TestAssert "a failed tool is an error", xtaJsonText(xtaJsonGet(tMessages, "3/content/2/tool_use_id")) is "toolu_02" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/2/is_error")) is "true"
   TestAssert "the answer after them", xtaJsonText(xtaJsonGet(tMessages, "4/content")) is "It places a value."
   TestAssert "an answer of calls alone has no empty text block", xtaJsonCount(xtaJsonGet(tMessages, "6/content")) is 1 \
         and xtaJsonText(xtaJsonGet(tMessages, "6/content/1/type")) is "tool_use"
   TestAssert "an id no API takes is made from where the call is", xtaJsonText(xtaJsonGet(tMessages, "6/content/1/id")) is "call_6_1" \
         and xtaJsonText(xtaJsonGet(tMessages, "7/content/1/tool_use_id")) is "call_6_1"
   TestAssert "arguments that are not an object are none", xtaJsonType(xtaJsonGet(tMessages, "6/content/1/input")) is "object" \
         and xtaJsonCount(xtaJsonGet(tMessages, "6/content/1/input")) is 0
   TestAssert "a call with no result was not run", xtaJsonText(xtaJsonGet(tMessages, "7/content/1/content")) is "Not run." \
         and xtaJsonText(xtaJsonGet(tMessages, "7/content/1/is_error")) is "true"
   TestAssert "and the question after it", xtaJsonCount(xtaJsonGet(tMessages, "7/content")) is 1 \
         and xtaJsonText(xtaJsonGet(tMessages, "8/role")) is "user" and xtaJsonText(xtaJsonGet(tMessages, "8/content")) is "Thanks"
end TestRequestBodyToolsAnthropic

on TestRequestBodyToolsOpenAI
   local tBody, tDoc, tMessages, tTools, tArguments
   put xtaRequestBody("openai", "m", "Be brief.", TestToolTurns(), empty, TestTools()) into tBody
   TestDiagnostic tBody
   put xtaJsonParse(tBody) into tDoc
   put xtaJsonMember(tDoc, "tools") into tTools
   TestAssert "the tools are functions", xtaJsonText(xtaJsonGet(tTools, "1/type")) is "function" \
         and xtaJsonText(xtaJsonGet(tTools, "1/function/name")) is "lookup_dictionary" \
         and xtaJsonText(xtaJsonGet(tTools, "2/function/parameters/type")) is "object"
   put xtaJsonMember(tDoc, "messages") into tMessages
   -- system, question, answer, two results, answer, question, answer, one result, question
   TestAssert "ten messages", xtaJsonCount(tMessages) is 10
   TestAssert "the answer with its calls", xtaJsonText(xtaJsonGet(tMessages, "3/role")) is "assistant" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content")) is "Let me look." \
         and xtaJsonText(xtaJsonGet(tMessages, "3/tool_calls/1/id")) is "toolu_01" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/tool_calls/1/type")) is "function" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/tool_calls/1/function/name")) is "lookup_dictionary"
   put xtaJsonText(xtaJsonGet(tMessages, "3/tool_calls/1/function/arguments")) into tArguments
   TestAssert "the arguments are JSON in a string", xtaJsonText(xtaJsonMember(xtaJsonParse(tArguments), "term")) is "put"
   TestAssert "a message for each result", xtaJsonText(xtaJsonGet(tMessages, "4/role")) is "tool" \
         and xtaJsonText(xtaJsonGet(tMessages, "4/tool_call_id")) is "toolu_01" \
         and xtaJsonText(xtaJsonGet(tMessages, "4/content")) is "put: places a value" \
         and xtaJsonText(xtaJsonGet(tMessages, "5/tool_call_id")) is "toolu_02" \
         and xtaJsonText(xtaJsonGet(tMessages, "5/content")) is "Error: does not compile"
   TestAssert "an answer of calls alone has an empty text", xtaJsonType(xtaJsonGet(tMessages, "8/content")) is "string" \
         and xtaJsonText(xtaJsonGet(tMessages, "8/content")) is empty \
         and xtaJsonText(xtaJsonGet(tMessages, "8/tool_calls/1/id")) is "call_6_1"
   TestAssert "a call with no result was not run", xtaJsonText(xtaJsonGet(tMessages, "9/tool_call_id")) is "call_6_1" \
         and xtaJsonText(xtaJsonGet(tMessages, "9/content")) is "Error: Not run."
end TestRequestBodyToolsOpenAI

-- A tool's picture (look_at_card's) goes with its result: in the
-- tool_result for Anthropic, after its text; for OpenAI, whose tool
-- messages take text alone, in a user message after the tool messages
on TestRequestBodyPictures
   local tTurns, tDoc, tMessages
   put TestToolTurns() into tTurns
   put "iVBORw0KGgo=" into tTurns[3]["results"][1]["image"]
   put "image/png" into tTurns[3]["results"][1]["imageType"]
   put xtaJsonParse(xtaRequestBody("anthropic", "m", "Be brief.", tTurns, empty, TestTools())) into tDoc
   put xtaJsonMember(tDoc, "messages") into tMessages
   TestDiagnostic xtaJsonText(xtaJsonGet(tMessages, "3/content/1/content/1/text"))
   TestAssert "Anthropic: the text, then the picture, in the result", \
         xtaJsonText(xtaJsonGet(tMessages, "3/content/1/tool_use_id")) is "toolu_01" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/content/1/type")) is "text" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/content/1/text")) is "put: places a value" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/content/2/type")) is "image" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/content/2/source/type")) is "base64" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/content/2/source/media_type")) is "image/png" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/1/content/2/source/data")) is "iVBORw0KGgo="
   TestAssert "a result without one is a text, as before", xtaJsonText(xtaJsonGet(tMessages, "3/content/2/content")) is "does not compile" \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content/2/is_error")) is "true"
   TestAssert "no other message", xtaJsonCount(tMessages) is 8
   put xtaJsonParse(xtaRequestBody("openai", "m", "Be brief.", tTurns, empty, TestTools())) into tDoc
   put xtaJsonMember(tDoc, "messages") into tMessages
   -- system, question, answer, two results, the pictures, answer,
   -- question, answer, one result, question
   TestAssert "OpenAI: one message more", xtaJsonCount(tMessages) is 11
   TestAssert "the results stay text", xtaJsonText(xtaJsonGet(tMessages, "4/content")) is "put: places a value" \
         and xtaJsonText(xtaJsonGet(tMessages, "5/role")) is "tool"
   TestAssert "then the pictures, from the user", xtaJsonText(xtaJsonGet(tMessages, "6/role")) is "user" \
         and xtaJsonText(xtaJsonGet(tMessages, "6/content/1/type")) is "text" \
         and xtaJsonText(xtaJsonGet(tMessages, "6/content/2/type")) is "image_url" \
         and xtaJsonText(xtaJsonGet(tMessages, "6/content/2/image_url/url")) is "data:image/png;base64,iVBORw0KGgo="
   TestAssert "and the answer after them", xtaJsonText(xtaJsonGet(tMessages, "7/role")) is "assistant" \
         and xtaJsonText(xtaJsonGet(tMessages, "7/content")) is "It places a value."
end TestRequestBodyPictures

-- A server with no tools is sent the conversation without calls or results
on TestRequestBodyWithoutTools
   local tDoc, tMessages
   put xtaJsonParse(xtaRequestBody("anthropic", "m", empty, TestToolTurns(), empty, empty)) into tDoc
   TestAssert "no tools", xtaJsonType(xtaJsonMember(tDoc, "tools")) is "missing"
   put xtaJsonMember(tDoc, "messages") into tMessages
   TestAssert "the texts alone", xtaJsonCount(tMessages) is 5 \
         and xtaJsonText(xtaJsonGet(tMessages, "2/content")) is "Let me look." \
         and xtaJsonText(xtaJsonGet(tMessages, "3/content")) is "It places a value." \
         and xtaJsonText(xtaJsonGet(tMessages, "5/content")) is "Thanks"
   TestAssert "and the same as before there were tools", \
         xtaRequestBody("anthropic", "m", "Be brief.", TestTurns(), empty, empty) is xtaRequestBody("anthropic", "m", "Be brief.", TestTurns(), empty)
end TestRequestBodyWithoutTools

on TestRequestBodyToolWithoutSchema
   local tTools, tError
   put TestTools() into tTools
   put "not json" into tTools[2]["schema"]
   try
      get xtaRequestBody("anthropic", "m", empty, TestTurns(), empty, tTools)
   catch tError
   end try
   TestAssert "a tool with no schema is refused", tError contains "last_error" and tError contains "schema"
end TestRequestBodyToolWithoutSchema

on TestRequestHeaders
   local tHeaders, tError
   put xtaRequestHeaders("anthropic", " sk-test ") into tHeaders
   TestDiagnostic tHeaders
   TestAssert "anthropic key", "x-api-key: sk-test" is among the lines of tHeaders
   TestAssert "anthropic version", "anthropic-version: 2023-06-01" is among the lines of tHeaders
   TestAssert "JSON", "Content-Type: application/json" is among the lines of tHeaders
   put xtaRequestHeaders("openai", "sk-test") into tHeaders
   TestAssert "openai bearer", "Authorization: Bearer sk-test" is among the lines of tHeaders
   TestAssert "no anthropic header for openai", not (tHeaders contains "x-api-key")
   put xtaRequestHeaders("openai", empty) into tHeaders
   TestAssert "no key, no Authorization line", not (tHeaders contains "Authorization")
   try
      get xtaRequestHeaders("openai", "sk" & numToChar(10) & "X-Evil: 1")
   catch tError
   end try
   TestAssert "a key with a line break is refused", tError contains "line break"
end TestRequestHeaders

on TestUrls
   TestAssert "anthropic default", xtaRequestUrl("anthropic", empty) is "https://api.anthropic.com/v1/messages"
   TestAssert "openai default", xtaRequestUrl("openai", empty) is "https://api.openai.com/v1/chat/completions"
   TestAssert "a base URL with a slash", xtaRequestUrl("openai", "http://localhost:11434/v1/") is "http://localhost:11434/v1/chat/completions"
   TestAssert "anthropic models", xtaModelsUrl("anthropic", empty) is "https://api.anthropic.com/v1/models?limit=100"
   TestAssert "openai models", xtaModelsUrl("openai", "https://example.org/v1") is "https://example.org/v1/models"
   TestAssert "unknown provider", xtaRequestUrl("nope", empty) is empty
end TestUrls

--------------------------------------------------------------------------------
-- Answers

private function TestQ pText
   return quote & pText & quote
end TestQ

on TestParseReplyAnthropic
   local tBody, tReply
   put "{" & TestQ("id") & ":" & TestQ("msg_1") & "," & TestQ("type") & ":" & TestQ("message") & "," & \
         TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & TestQ("text") & ":" & TestQ("Here it is:") & "}," & \
         "{" & TestQ("type") & ":" & TestQ("tool_use") & "," & TestQ("id") & ":" & TestQ("t1") & "," & TestQ("name") & ":" & TestQ("x") & "," & TestQ("input") & ":{}}," & \
         "{" & TestQ("type") & ":" & TestQ("text") & "," & TestQ("text") & ":" & TestQ(" done") & "}]," & \
         TestQ("stop_reason") & ":" & TestQ("end_turn") & "," & \
         TestQ("usage") & ":{" & TestQ("input_tokens") & ":12," & TestQ("output_tokens") & ":34}}" into tBody
   put xtaParseReply("anthropic", 200, tBody) into tReply
   TestAssert "ok", tReply["ok"] is true
   TestAssert "the text parts, in order", tReply["text"] is "Here it is: done"
   TestAssert "stop reason", tReply["stop"] is "end_turn"
   TestAssert "tokens", tReply["inputTokens"] is 12 and tReply["outputTokens"] is 34

   put "{" & TestQ("type") & ":" & TestQ("error") & "," & TestQ("error") & ":{" & TestQ("type") & ":" & TestQ("authentication_error") & "," & TestQ("message") & ":" & TestQ("invalid x-api-key") & "}}" into tBody
   put xtaParseReply("anthropic", 401, tBody) into tReply
   TestAssert "an error is not ok", tReply["ok"] is false
   TestAssert "the key was refused", line 1 of tReply["error"] contains "API key"
   TestAssert "the provider's message", line 2 of tReply["error"] is "invalid x-api-key"

   put xtaParseReply("anthropic", 200, "<html>proxy</html>") into tReply
   TestAssert "an answer that is not JSON", tReply["ok"] is false and tReply["error"] contains "not JSON"
   put xtaParseReply("anthropic", 502, "Bad Gateway") into tReply
   TestAssert "an error status without JSON", tReply["ok"] is false and tReply["error"] contains "502" and tReply["error"] contains "Bad Gateway"
   put xtaParseReply("anthropic", empty, empty) into tReply
   TestAssert "no answer", tReply["ok"] is false and tReply["error"] is not empty
end TestParseReplyAnthropic

-- An answer Anthropic stopped on safety grounds: what was said before
-- it, and the kind of request it was taken for when Anthropic says (its
-- stop_details can be null, or the answer empty)
on TestParseReplyRefusal
   local tBody, tReply
   put "{" & TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & TestQ("text") & ":" & TestQ("Sure") & "}]," & \
         TestQ("stop_reason") & ":" & TestQ("refusal") & "," & TestQ("stop_details") & ":{" & TestQ("type") & ":" & TestQ("refusal") & "," & \
         TestQ("category") & ":" & TestQ("cyber") & "," & TestQ("explanation") & ":" & TestQ("Declined.") & "}}" into tBody
   put xtaParseReply("anthropic", 200, tBody) into tReply
   TestAssert "an answer", tReply["ok"] is true and tReply["text"] is "Sure"
   TestAssert "stopped as a refusal", tReply["stop"] is "refusal"
   TestAssert "of its category", tReply["category"] is "cyber"
   put "{" & TestQ("content") & ":[]," & TestQ("stop_reason") & ":" & TestQ("refusal") & "," & TestQ("stop_details") & ":null}" into tBody
   put xtaParseReply("anthropic", 200, tBody) into tReply
   TestAssert "an empty one, with no details", tReply["ok"] is true and tReply["stop"] is "refusal" \
         and tReply["category"] is empty and tReply["text"] is empty
   put "{" & TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & TestQ("text") & ":" & TestQ("Hi") & "}]," & \
         TestQ("stop_reason") & ":" & TestQ("end_turn") & "}" into tBody
   put xtaParseReply("anthropic", 200, tBody) into tReply
   TestAssert "an answer that was not stopped has none", tReply["stop"] is "end_turn" and tReply["category"] is empty
end TestParseReplyRefusal

on TestParseReplyCachedTokens
   local tBody, tReply
   put "{" & TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & TestQ("text") & ":" & TestQ("x") & "}]," & \
         TestQ("usage") & ":{" & TestQ("input_tokens") & ":12," & TestQ("cache_read_input_tokens") & ":3000," & \
         TestQ("output_tokens") & ":34}}" into tBody
   put xtaParseReply("anthropic", 200, tBody) into tReply
   TestAssert "anthropic: read from the cache", tReply["cachedTokens"] is 3000 and tReply["inputTokens"] is 12
   put "{" & TestQ("choices") & ":[{" & TestQ("message") & ":{" & TestQ("content") & ":" & TestQ("x") & "}}]," & \
         TestQ("usage") & ":{" & TestQ("prompt_tokens") & ":2000," & TestQ("completion_tokens") & ":7," & \
         TestQ("prompt_tokens_details") & ":{" & TestQ("cached_tokens") & ":1024}}}" into tBody
   put xtaParseReply("openai", 200, tBody) into tReply
   TestAssert "openai: read from the cache", tReply["cachedTokens"] is 1024 and tReply["inputTokens"] is 2000
end TestParseReplyCachedTokens

on TestParseReplyOpenAI
   local tBody, tReply
   put "{" & TestQ("choices") & ":[{" & TestQ("index") & ":0," & TestQ("message") & ":{" & TestQ("role") & ":" & TestQ("assistant") & "," & \
         TestQ("content") & ":" & TestQ("Hello") & "}," & TestQ("finish_reason") & ":" & TestQ("stop") & "}]," & \
         TestQ("usage") & ":{" & TestQ("prompt_tokens") & ":5," & TestQ("completion_tokens") & ":7}}" into tBody
   put xtaParseReply("openai", 200, tBody) into tReply
   TestAssert "ok", tReply["ok"] is true
   TestAssert "text", tReply["text"] is "Hello"
   TestAssert "finish reason", tReply["stop"] is "stop"
   TestAssert "tokens", tReply["inputTokens"] is 5 and tReply["outputTokens"] is 7

   put "{" & TestQ("error") & ":{" & TestQ("message") & ":" & TestQ("Incorrect API key provided") & "," & TestQ("type") & ":" & TestQ("invalid_request_error") & "}}" into tBody
   put xtaParseReply("openai", 401, tBody) into tReply
   TestAssert "error message", tReply["ok"] is false and line 2 of tReply["error"] is "Incorrect API key provided"
   put "{" & TestQ("error") & ":" & TestQ("model not found") & "}" into tBody
   put xtaParseReply("openai", 404, tBody) into tReply
   TestAssert "an error as a plain string", tReply["ok"] is false and line 2 of tReply["error"] is "model not found"
   put xtaParseReply("openai", 200, "{" & TestQ("choices") & ":[]}") into tReply
   TestAssert "no message", tReply["ok"] is false
end TestParseReplyOpenAI

-- A local model's thinking, written in its answer, is not shown; a tag
-- anywhere but at the start is the answer's own
on TestWithoutThinking
   local tBody, tReply
   TestAssert "an answer without thinking is as it was", xtaWithoutThinking("Hello" & return & "there") is ("Hello" & return & "there")
   TestAssert "the thinking goes", xtaWithoutThinking("<think>" & return & "They want a loop." & return & "</think>" & return & return & "Use repeat.") is "Use repeat."
   TestAssert "after white space too", xtaWithoutThinking(space & return & "<think>x</think>Answer") is "Answer"
   TestAssert "with code drafted in it", xtaWithoutThinking("<think>```" & return & "put 1" & return & "```</think>" & return & "Done.") is "Done."
   TestAssert "thinking that never closes leaves nothing", xtaWithoutThinking("<think>" & return & "Let me see") is empty
   TestAssert "a tag later on stays", xtaWithoutThinking("Qwen writes <think>...</think> first.") is "Qwen writes <think>...</think> first."
   TestAssert "a closing tag alone stays", xtaWithoutThinking("Close it with </think>.") is "Close it with </think>."
   TestAssert "nothing is nothing", xtaWithoutThinking(empty) is empty
   put "{" & TestQ("choices") & ":[{" & TestQ("message") & ":{" & TestQ("role") & ":" & TestQ("assistant") & "," & \
         TestQ("content") & ":" & TestQ("<think>\nHmm.\n</think>\n\nHello") & "}," & TestQ("finish_reason") & ":" & TestQ("stop") & "}]}" into tBody
   put xtaParseReply("openai", 200, tBody) into tReply
   TestAssert "an OpenAI-style answer is read without it", tReply["ok"] is true and tReply["text"] is "Hello"
end TestWithoutThinking

-- What a server of the user's own is told to try
on TestLocalServerHint
   local tHint
   TestAssert "the local servers", line 1 to 2 of xtaLocalServers() is ("LM Studio" & tab & "http://localhost:1234/v1" & return & "Ollama" & tab & "http://localhost:11434/v1")
   TestAssert "and the others", ("llama.cpp" & tab & "http://localhost:8080/v1") is among the lines of xtaLocalServers() \
         and ("Jan" & tab & "http://localhost:1337/v1") is among the lines of xtaLocalServers()
   TestAssert "nothing for the providers' own", xtaLocalServerHint(empty, empty, "The server could not be reached: error") is empty
   put xtaLocalServerHint("http://localhost:1234/v1", empty, "The server could not be reached: error Connection refused") into tHint
   TestDiagnostic tHint
   TestAssert "a server that is not running", tHint begins with "Is the server running?" and tHint contains "LM Studio"
   put xtaLocalServerHint("http://localhost:1234/v1", 400, "The provider answered with an error (400)." & return & \
         "Trying to keep the first 9000 tokens when context the overflows. However, the model is loaded with context length of only 4096 tokens") into tHint
   TestAssert "a context too short", tHint contains "context is too short" and tHint contains "Short guide"
   TestAssert "never says tool (xtaToolsRefused)", not (tHint contains "tool")
   TestAssert "nothing for another error", xtaLocalServerHint("http://localhost:1234/v1", 404, "The provider has no such address or model (404).") is empty
end TestLocalServerHint

-- The online services: a name, a base URL on https and a page for a key
-- each, and no name the start of another's (Services matches by name)
on TestOnlineServices
   local tLine, tNames, tOk
   put true into tOk
   set the itemDelimiter to tab
   repeat for each line tLine in xtaOnlineServices()
      if the number of items of tLine is not 3 or not (item 2 of tLine begins with "https://") \
            or not (item 3 of tLine begins with "https://") or item 1 of tLine is among the lines of tNames then
         TestDiagnostic tLine
         put false into tOk
      end if
      put item 1 of tLine & return after tNames
   end repeat
   TestAssert "each has a name, a base URL and a key page", tOk
   TestAssert "OpenRouter's", line 1 of xtaOnlineServices() is ("OpenRouter" & tab & "https://openrouter.ai/api/v1" & tab & "https://openrouter.ai/keys")
   TestAssert "ten of them", the number of lines of xtaOnlineServices() is 10
end TestOnlineServices

on TestParseReplyToolCalls
   local tInput, tBody, tReply
   put "{" & TestQ("term") & ": " & TestQ("put") & ", " & TestQ("n") & ": [1, 2.5]}" into tInput
   put "{" & TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & TestQ("text") & ":" & TestQ("Let me look.") & "}," & \
         "{" & TestQ("type") & ":" & TestQ("tool_use") & "," & TestQ("id") & ":" & TestQ("toolu_01") & "," & TestQ("name") & ":" & TestQ("lookup_dictionary") & "," & \
         TestQ("input") & ":" & tInput & "}," & \
         "{" & TestQ("type") & ":" & TestQ("tool_use") & "," & TestQ("id") & ":" & TestQ("toolu_02") & "," & TestQ("name") & ":" & TestQ("last_error") & "," & \
         TestQ("input") & ":{}}]," & TestQ("stop_reason") & ":" & TestQ("tool_use") & "}" into tBody
   put xtaParseReply("anthropic", 200, tBody) into tReply
   TestAssert "anthropic: ok, with its text", tReply["ok"] is true and tReply["text"] is "Let me look." and tReply["stop"] is "tool_use"
   TestAssert "anthropic: two calls", the number of elements of tReply["calls"] is 2
   TestAssert "anthropic: the first", tReply["calls"][1]["id"] is "toolu_01" and tReply["calls"][1]["name"] is "lookup_dictionary"
   TestAssert "anthropic: its arguments exactly as they came", tReply["calls"][1]["input"] is tInput
   TestAssert "anthropic: the second", tReply["calls"][2]["name"] is "last_error" and tReply["calls"][2]["input"] is "{}"
   TestAssert "the status", tReply["status"] is 200

   put "{" & TestQ("choices") & ":[{" & TestQ("message") & ":{" & TestQ("role") & ":" & TestQ("assistant") & "," & TestQ("content") & ":null," & \
         TestQ("tool_calls") & ":[{" & TestQ("id") & ":" & TestQ("call_1") & "," & TestQ("type") & ":" & TestQ("function") & "," & \
         TestQ("function") & ":{" & TestQ("name") & ":" & TestQ("check_code") & "," & TestQ("arguments") & ":" & \
         xtaJsonString("{" & TestQ("code") & ":" & TestQ("beep") & "}") & "}}," & \
         "{" & TestQ("id") & ":" & TestQ("call_2") & "," & TestQ("type") & ":" & TestQ("function") & "," & \
         TestQ("function") & ":{" & TestQ("name") & ":" & TestQ("read_stack") & "," & TestQ("arguments") & ":{" & TestQ("id") & ":1004}}}]}," & \
         TestQ("finish_reason") & ":" & TestQ("tool_calls") & "}]}" into tBody
   TestDiagnostic tBody
   put xtaParseReply("openai", 200, tBody) into tReply
   TestAssert "openai: ok, with no text", tReply["ok"] is true and tReply["text"] is empty and tReply["stop"] is "tool_calls"
   TestAssert "openai: two calls", the number of elements of tReply["calls"] is 2
   TestAssert "openai: the arguments from their string", tReply["calls"][1]["id"] is "call_1" and tReply["calls"][1]["name"] is "check_code" \
         and xtaJsonText(xtaJsonMember(xtaJsonParse(tReply["calls"][1]["input"]), "code")) is "beep"
   TestAssert "openai: or sent as an object", tReply["calls"][2]["input"] is ("{" & TestQ("id") & ":1004}")

   put xtaParseReply("anthropic", 400, "{" & TestQ("error") & ":{" & TestQ("message") & ":" & TestQ("bad") & "}}") into tReply
   TestAssert "an error keeps its status", tReply["ok"] is false and tReply["status"] is 400
end TestParseReplyToolCalls

on TestParseModels
   local tBody, tResult
   put "{" & TestQ("data") & ":[{" & TestQ("id") & ":" & TestQ("model-a") & "},{" & TestQ("id") & ":" & TestQ("model-b") & "}]," & TestQ("has_more") & ":false}" into tBody
   put xtaParseModels("anthropic", 200, tBody) into tResult
   TestAssert "two models", tResult["models"] is ("model-a" & return & "model-b")
   TestAssert "the default is the first listed, without a Sonnet", tResult["default"] is "model-a"
   put xtaParseModels("openai", 200, "{" & TestQ("data") & ":[]}") into tResult
   TestAssert "none", tResult["error"] is not empty
   -- OpenAI's list, in no order, with when each model was made
   put "{" & TestQ("data") & ":[" & TestModelEntry("text-embedding-3-small", 1705948997) & "," & \
         TestModelEntry("gpt-5.1", 1762000000) & "," & TestModelEntry("gpt-4o", 1715367049) & "," & \
         TestModelEntry("gpt-5.2-mini", 1765000000) & "," & TestModelEntry("tts-1", 1681940951) & "]}" into tBody
   put xtaParseModels("openai", 200, tBody) into tResult
   TestAssert "OpenAI: every model is listed", the number of lines of tResult["models"] is 5
   TestAssert "OpenAI: the newest that is just gpt- and a version", tResult["default"] is "gpt-5.1"
end TestParseModels

-- The model the window begins with when the user has chosen none: a family,
-- never a name built in
on TestDefaultModel
   local tCreated
   TestAssert "Anthropic: the newest Sonnet (its list is newest first)", \
         xtaDefaultModel("anthropic", "claude-opus-9" & return & "claude-sonnet-9" & return & "claude-haiku-9" & return & "claude-sonnet-8", tCreated) is "claude-sonnet-9"
   TestAssert "Anthropic: else the first listed", \
         xtaDefaultModel("anthropic", "claude-opus-9" & return & "claude-haiku-9", tCreated) is "claude-opus-9"
   put 300 into tCreated["gpt-4o"]
   put 200 into tCreated["gpt-5"]
   put 400 into tCreated["gpt-5-mini"]
   put 100 into tCreated["o3"]
   TestAssert "OpenAI: the newest gpt- and a version, not a mini", \
         xtaDefaultModel("openai", "o3" & return & "gpt-5" & return & "gpt-5-mini" & return & "gpt-4o", tCreated) is "gpt-4o"
   TestAssert "a local server: the first listed", \
         xtaDefaultModel("openai", "llama3.2:latest" & return & "qwen2.5-coder:7b", tCreated) is "llama3.2:latest"
   TestAssert "OpenAI without the dates: the first gpt- and a version", \
         xtaDefaultModel("openai", "whisper-1" & return & "gpt-4.1" & return & "gpt-5", empty) is "gpt-4.1"
   TestAssert "OpenAI: its suggested model first, when it lists it", \
         xtaDefaultModel("openai", "gpt-6-astra" & return & "gpt-5" & return & "gpt-6.1-sol", tCreated) is "gpt-6.1-sol"
   TestAssert "a local server: not a model that only makes embeddings (LM Studio comes with one)", \
         xtaDefaultModel("openai", "text-embedding-nomic-embed-text-v1.5" & return & "qwen/qwen3-coder-30b", empty) is "qwen/qwen3-coder-30b"
   TestAssert "a local server with nothing else: the first listed", \
         xtaDefaultModel("openai", "text-embedding-nomic-embed-text-v1.5", empty) is "text-embedding-nomic-embed-text-v1.5"
end TestDefaultModel

-- The model menu: the providers' current recommendations before the list
-- has come, then those it lists first and the rest in order
on TestModelMenu
   TestAssert "Anthropic's, before its list", xtaModelMenu("anthropic", empty) is \
         ("claude-sonnet-5-5" & return & "claude-opus-5-5" & return & "claude-haiku-5-5" & return & "claude-fable-5-1")
   TestAssert "OpenAI's", xtaModelMenu("openai", empty) is ("gpt-6.1-sol" & return & "gpt-6-astra" & return & "gpt-6-luna")
   TestAssert "the listed suggestions first, then the rest sorted", \
         xtaModelMenu("anthropic", "claude-opus-5" & return & "claude-opus-5-5" & return & "claude-haiku-4-5" & return & "claude-sonnet-5-5") is \
         ("claude-sonnet-5-5" & return & "claude-opus-5-5" & return & "claude-haiku-4-5" & return & "claude-opus-5")
   TestAssert "a local server's list, sorted", xtaModelMenu("openai", "qwen2.5-coder:7b" & return & "llama3.2:latest") is \
         ("llama3.2:latest" & return & "qwen2.5-coder:7b")
   TestAssert "Anthropic's default model is listed first", line 1 of xtaSuggestedModels("anthropic") is \
         xtaDefaultModel("anthropic", xtaSuggestedModels("anthropic"), empty)
end TestModelMenu

private function TestModelEntry pId, pCreated
   return "{" & TestQ("id") & ":" & TestQ(pId) & "," & TestQ("object") & ":" & TestQ("model") & "," & TestQ("created") & ":" & pCreated & "}"
end TestModelEntry

on TestCodeBlocks
   local tText, tBlocks
   put "Put this in the button:" & return & "```livecodescript" & return & "on mouseUp" & return & return & "   beep" & return & "end mouseUp" & return & "```" & return & \
         "and then" & return & "  ``` " & return & "put 1" & return & "```" & return & "```lcs" & return & "unclosed" into tText
   put xtaCodeBlocks(tText) into tBlocks
   TestAssert "three blocks", the number of elements of tBlocks is 3
   TestAssert "language", tBlocks[1]["lang"] is "livecodescript"
   TestAssert "code with an empty line", tBlocks[1]["code"] is ("on mouseUp" & return & return & "   beep" & return & "end mouseUp")
   TestAssert "no language", tBlocks[2]["lang"] is empty and tBlocks[2]["code"] is "put 1"
   TestAssert "an unclosed block", tBlocks[3]["lang"] is "lcs" and tBlocks[3]["code"] is "unclosed"
end TestCodeBlocks

on TestXTalkBlocks
   local tBlocks, tXTalk
   put "livecodescript" into tBlocks[1]["lang"]
   put "on a" & return & "end a" into tBlocks[1]["code"]
   put "python" into tBlocks[2]["lang"]
   put "print(1)" into tBlocks[2]["code"]
   put empty into tBlocks[3]["lang"]
   put "put 1" into tBlocks[3]["code"]
   put "memory" into tBlocks[4]["lang"]
   put "you: x" into tBlocks[4]["code"]
   put "LiveCode" into tBlocks[5]["lang"]
   put "beep" into tBlocks[5]["code"]
   put "lcs" into tBlocks[6]["lang"]
   put "  " into tBlocks[6]["code"]
   put xtaXTalkBlocks(tBlocks) into tXTalk
   TestAssert "three xTalk blocks", the number of elements of tXTalk is 3
   TestAssert "in their order", tXTalk[1]["code"] is ("on a" & return & "end a") and tXTalk[2]["code"] is "put 1" \
         and tXTalk[3]["code"] is "beep"
   TestAssert "LiveCode Builder is not xTalk", not xtaIsXTalkLang("livecodebuilder")
   TestAssert "nor a shell", not xtaIsXTalkLang("sh")
   TestAssert "a block with no language is", xtaIsXTalkLang(empty)
end TestXTalkBlocks

--------------------------------------------------------------------------------
-- Checking code

on TestCheckScriptCompiles
   local tCheck
   put xtaCheckScript("local sCount" & return & "-- counts" & return & "on mouseUp pButton" & return & \
         "   local tName" & return & "   put pButton into tName" & return & "   add 1 to sCount" & return & \
         "   repeat with i = 1 to 3" & return & "   end repeat" & return & "end mouseUp", empty) into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "whole handlers that compile", tCheck["ok"] is true and tCheck["issues"] is empty
   put xtaCheckScript("put 1 into tX" & return & "answer tX", empty) into tCheck
   TestAssert "statements for the Message Box", tCheck["ok"] is true
   put xtaCheckScript("script " & quote & "MyLib" & quote & return & "on a" & return & "end a", empty) into tCheck
   TestAssert "a script-only stack's first line", tCheck["ok"] is true
   put xtaCheckScript("on a" & return & "   local tX" & return & "   put " & quote & "-- # // not comments" & quote & " into tX" & return & "end a", empty) into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "comment marks inside a string", tCheck["ok"] is true
end TestCheckScriptCompiles

on TestCheckScriptCompileErrors
   local tCheck
   put xtaCheckScript("on mouseUp" & return & "   put 1 inot tX" & return & "end mouseUp", empty) into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "a compile error", tCheck["ok"] is false
   TestAssert "with its line and column", line 1 of tCheck["issues"] begins with "line 2, column 8:"
   TestAssert "and what is wrong (the message, or in a standalone its number)", line 1 of tCheck["issues"] contains "302"
   TestAssert "near what", line 1 of tCheck["issues"] contains (quote & "inot" & quote)
   put xtaCheckScript("beep" & return & "put 1 inot tX", empty) into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "the line of a statement, counted in the block", line 1 of tCheck["issues"] begins with "line 2,"
   put xtaCheckScript("on a" & return & "   refreshList()" & return & "end a", empty) into tCheck
   TestAssert "a command called with brackets (engine note 3.3)", tCheck["ok"] is false
   put xtaCheckScript("function a" & return & "   return 1" & return & "end b", empty) into tCheck
   TestAssert "an end that does not match", tCheck["ok"] is false
end TestCheckScriptCompileErrors

on TestCheckScriptWhatTheEngineDoesNotSay
   local tCheck
   put xtaCheckScript("on a" & return & "end a" & return & "put 1 into tX" & return & "on b" & return & "end b", empty) into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "a line outside any handler", tCheck["ok"] is false and tCheck["issues"] contains "line 3: this line is outside any handler"
   put xtaCheckScript("on a" & return & "end a" & return & "command a" & return & "end a" & return & "function a" & return & "end a", empty) into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "a handler defined twice", tCheck["ok"] is false and tCheck["issues"] contains "line 3: the command handler a is defined twice (also at line 1)"
   TestAssert "a function of the same name is not a duplicate", the number of lines of tCheck["issues"] is 1
   put xtaCheckScript("on a" & return & "   answer " & numToCodepoint(8220) & "hi" & numToCodepoint(8221) & return & "end a", empty) into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "curly quotes (engine note 1.4)", tCheck["ok"] is false and tCheck["issues"] contains "line 2: curly quotes"
   put xtaCheckScript("on a" & return & "/* on b" & return & "end b */" & return & "end a" & return & "on b" & return & "end b", empty) into tCheck
   TestAssert "a handler in a comment is not a handler", tCheck["ok"] is true
end TestCheckScriptWhatTheEngineDoesNotSay

on TestCheckScriptUndeclared
   local tCheck, tScript
   put "on a" & return & "   put sTotal + 1 into tSum" & return & "end a" into tScript
   put xtaCheckScript(tScript, empty) into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "a name that is not declared (engine note 2.1)", tCheck["ok"] is false and tCheck["issues"] contains "explicitVariables"
   TestAssert "on its line", line 1 of tCheck["issues"] begins with "line 2"
   put xtaCheckScript("local tSum" & return & tScript, "sTotal") into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "names the user's script declares count", tCheck["ok"] is true
   put xtaCheckScript("on a" & return & "   set the style of button 1 to checkbox" & return & "end a", empty) into tCheck
   TestAssert "a literal that is not quoted", tCheck["ok"] is false
   put xtaCheckScript("local sTotal" & return & "on a" & return & "   local tSum" & return & "   put sTotal into tSum" & return & "end a", "sTotal" & return & "tSum") into tCheck
   TestDiagnostic tCheck["issues"]
   TestAssert "a name both declare is not declared twice", tCheck["ok"] is true
   put xtaCheckScript("put tNever into tX", empty) into tCheck
   TestAssert "statements for the Message Box need no declarations", tCheck["ok"] is true
end TestCheckScriptUndeclared

-- A whole script somebody else wrote, compiled as the engine compiles it
-- (the MCP Bridge's set_script_from_file): xtaCheckScript, for code the
-- model wrote, refuses what old scripts have and the engine allows
on TestCompileProblemIsOnlyTheEngines
   local tScript, tOld, tCheck
   put the explicitVariables into tOld
   put "put 1 into gLoose" & return & "on a" & return & "   put sTotal + 1 into tSum" & return & "end a" into tScript
   put xtaCheckScript(tScript, empty) into tCheck
   TestAssert "the check for the model's code refuses it", tCheck["ok"] is false
   TestAssert "the engine takes it: names not declared, a line outside a handler", xtaCompileProblem(tScript) is empty
   replace return with crlf in tScript
   TestAssert "with Windows's line ends too", xtaCompileProblem(tScript) is empty
   TestAssert "and an empty script", xtaCompileProblem(empty) is empty
   put "on a" & return & "   put 1 +" & return & "end a" into tScript
   TestDiagnostic xtaCompileProblem(tScript)
   TestAssert "what the engine refuses, with its line", xtaCompileProblem(tScript) begins with "line 2"
   TestAssert "nothing said of the explicitVariables, which were off", not (xtaCompileProblem(tScript) contains "explicitVariables")
   TestAssert "which are as they were", the explicitVariables is tOld
   TestAssert "the scratch button keeps no script", the script of button "Check" of stack "revXTalkAssistantCheck" is empty
   xtaCheckCleanup
end TestCompileProblemIsOnlyTheEngines

on TestCheckLeavesNothingBehind
   local tOld, tTop, tDefault
   put the explicitVariables into tOld
   put the long id of the topStack into tTop
   put the defaultStack into tDefault
   get xtaCheckScript("on a" & return & "   put x into y" & return & "end a", empty)
   TestAssert "the explicitVariables are put back", the explicitVariables is tOld
   TestAssert "the scratch button keeps no script", the script of button "Check" of stack "revXTalkAssistantCheck" is empty
   TestAssert "its stack is hidden", not the visible of stack "revXTalkAssistantCheck"
   -- Open, even hidden, it became the topStack, which the IDE takes for
   -- the user's stack
   TestAssert "and not open", "revXTalkAssistantCheck" is not among the lines of the openStacks
   TestAssert "the topStack is the same", the long id of the topStack is tTop
   TestAssert "and the defaultStack", the defaultStack is tDefault
   xtaCheckCleanup
   TestAssert "and deleted when the assistant is done", there is not a stack "revXTalkAssistantCheck"
   get xtaCheckScript("on a" & return & "end a", empty)
   TestAssert "made again when needed", there is a stack "revXTalkAssistantCheck"
   xtaCheckCleanup
end TestCheckLeavesNothingBehind

on TestCheckBlocks
   local tBlocks, tCheck
   put "on a" & return & "end a" into tBlocks[1]["code"]
   put "on b" & return & "   put 1 inot x" & return & "end b" into tBlocks[2]["code"]
   put xtaCheckBlocks(tBlocks, empty) into tCheck
   TestDiagnostic tCheck["report"]
   TestAssert "one of two fails", tCheck["ok"] is false and tCheck["blocks"] is 2 and tCheck["failed"] is 1
   TestAssert "the report names the block and the line", line 1 of tCheck["report"] begins with "Compile check:" \
         and line 2 of tCheck["report"] is "In xTalk block 2:" and line 3 of tCheck["report"] begins with "- line 2,"
   TestAssert "and asks for every block again", the last line of tCheck["report"] contains "every block again"
   TestAssert "the summary says which", tCheck["summary"] contains "block 2"
   TestAssert "the code, to tell a correction from a repeat", tCheck["code"] contains "inot"
   delete variable tBlocks[2]
   put xtaCheckBlocks(tBlocks, empty) into tCheck
   TestAssert "one block that compiles", tCheck["ok"] is true and tCheck["summary"] is "Compile check: the code compiles." \
         and tCheck["report"] is empty
end TestCheckBlocks

on TestDeclaredNames
   local tNames
   put xtaDeclaredNames("local sA, sB = 5" & return & "global gPrefs" & return & "constant kMax = " & quote & "a,b" & quote & ", kMin = 1" & return & \
         "on a pX" & return & "   local tInside" & return & "end a" & return & "local sAfter") into tNames
   TestDiagnostic tNames
   TestAssert "the script's declarations", tNames is ("sA" & return & "sB" & return & "gPrefs" & return & "kMax" & return & "kMin" & return & "sAfter" & return)
end TestDeclaredNames

--------------------------------------------------------------------------------
-- Memory

private function TestMemoryText
   return "# a comment" & return & "[you]" & return & "- Builds for Windows and Linux only." & return & "- Names globals with g." & return & \
         "not a note" & return & "[stack /home/ann/My Stack [1].livecode]" & return & "- The log is in field " & quote & "Log" & quote & "." & return & \
         "[something else]" & return & "- ignored"
end TestMemoryText

on TestMemoryParseAndFormat
   local tMemory, tAgain
   put xtaMemoryParse(TestMemoryText()) into tMemory
   TestAssert "notes about the user", tMemory["you"] is ("Builds for Windows and Linux only." & return & "Names globals with g.")
   TestAssert "notes about a stack, by its path", tMemory["stacks"]["/home/ann/My Stack [1].livecode"] is ("The log is in field " & quote & "Log" & quote & ".")
   TestAssert "nothing else", the number of elements of tMemory["stacks"] is 1
   put xtaMemoryParse(xtaMemoryFormat(tMemory)) into tAgain
   TestAssert "a round trip", tAgain["you"] is tMemory["you"] and tAgain["stacks"]["/home/ann/My Stack [1].livecode"] is tMemory["stacks"]["/home/ann/My Stack [1].livecode"]
   TestAssert "notes about one stack", xtaMemoryNotes(tMemory, "stack", "/home/ann/My Stack [1].livecode") contains "Log"
   TestAssert "no path, no stack notes", xtaMemoryNotes(tMemory, "stack", empty) is empty
end TestMemoryParseAndFormat

on TestMemoryFile
   local tPath, tMemory, tAgain
   put specialFolderPath("temporary") & "/xta-test-memory.txt" into tPath
   if there is a file tPath then
      delete file tPath
   end if
   TestAssert "no file, no notes", xtaMemoryLoad(tPath) is empty
   put xtaMemoryParse(TestMemoryText()) into tMemory
   put "caf" & numToCodepoint(233) into line 3 of tMemory["you"]
   xtaMemorySave tPath, tMemory
   TestAssert "saved", the result is empty and there is a file tPath
   put xtaMemoryLoad(tPath) into tAgain
   TestAssert "read back, in UTF-8", tAgain["you"] is tMemory["you"]
   put empty into tMemory
   xtaMemorySave tPath, tMemory
   TestAssert "no notes, no file", there is not a file tPath
end TestMemoryFile

on TestMemoryNotes
   local tMemory, tLong
   xtaMemorySetNotes tMemory, "you", empty, "  first  " & return & return & "second" & tab & "note"
   TestAssert "notes set, trimmed, without empty lines", the result is empty and tMemory["you"] is ("first" & return & "second note")
   xtaMemoryAdd tMemory, "you", empty, "first"
   TestAssert "a note that is there already is not added again", tMemory["you"] is ("first" & return & "second note")
   xtaMemoryAdd tMemory, "stack", "/a/b.livecode", "about b"
   TestAssert "a note about a stack", tMemory["stacks"]["/a/b.livecode"] is "about b"
   xtaMemoryAdd tMemory, "stack", empty, "about nothing"
   TestAssert "a stack never saved has no notes", the result is not empty
   xtaMemoryAdd tMemory, "you", empty, "My key is sk-ant-api03-abcdefghijklmnop"
   TestAssert "a key is refused", the result contains "key" and not (tMemory["you"] contains "sk-ant")
   TestAssert "a password too", xtaMemoryNoteProblem("password: hunter2") is not empty
   TestAssert "a long run of letters and digits too", xtaMemoryNoteProblem("token 3f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e") is not empty
   TestAssert "a long name is not a key", xtaMemoryNoteProblem("Calls inventoryRefreshEverythingOnTheMainCard first") is empty
   TestAssert "a path is not a key", xtaMemoryNoteProblem("Data is in /Users/ann/Documents/Inventory2024/items.csv") is empty
   repeat 31
      put "0123456789" after tLong
   end repeat
   TestAssert "a long note is refused", xtaMemoryNoteProblem("a " & tLong) is not empty
   repeat 12
      xtaMemoryAdd tMemory, "you", empty, "note" && the number of lines of tMemory["you"] && char 1 to 250 of ("x x " & tLong)
   end repeat
   TestAssert "the notes about the user are kept short", the number of chars of tMemory["you"] <= 3000
end TestMemoryNotes

on TestMemoryPrompt
   local tMemory, tPrompt
   TestAssert "no notes, nothing to say", xtaMemoryPrompt(tMemory, empty, empty) is empty
   put xtaMemoryParse(TestMemoryText()) into tMemory
   put xtaMemoryPrompt(tMemory, "/home/ann/My Stack [1].livecode", "My Stack") into tPrompt
   TestDiagnostic tPrompt
   TestAssert "a heading the guide names", line 1 of tPrompt is "## Notes to keep in mind"
   TestAssert "about the user", tPrompt contains ("About the user:" & return & "- Builds for Windows and Linux only.")
   TestAssert "about the stack, by its name", tPrompt contains ("About the stack " & quote & "My Stack" & quote)
   TestAssert "not its path", not (tPrompt contains "/home/ann")
   put xtaMemoryPrompt(tMemory, "/other.livecode", "Other") into tPrompt
   TestAssert "another stack's notes are not sent", not (tPrompt contains "Log")
end TestMemoryPrompt

on TestMemoryProposals
   local tText, tNotes, tShown
   put "Done." & return & "```livecodescript" & return & "on a" & return & "end a" & return & "```" & return & \
         "```memory" & return & "you: Builds for Windows only." & return & "- stack: Log goes to field " & quote & "Log" & quote & "." & return & \
         return & "Prefers short answers." & return & "```" into tText
   put xtaMemoryProposals(tText) into tNotes
   TestAssert "three notes proposed", the number of elements of tNotes is 3
   TestAssert "about the user", tNotes[1]["scope"] is "you" and tNotes[1]["note"] is "Builds for Windows only."
   TestAssert "about the stack", tNotes[2]["scope"] is "stack" and tNotes[2]["note"] is ("Log goes to field " & quote & "Log" & quote & ".")
   TestAssert "no scope, about the user", tNotes[3]["scope"] is "you" and tNotes[3]["note"] is "Prefers short answers."
   put xtaWithoutMemoryBlocks(tText) into tShown
   TestDiagnostic tShown
   TestAssert "the memory block is not shown", not (tShown contains "Builds for") and not (tShown contains "```memory")
   TestAssert "the rest is", tShown is ("Done." & return & "```livecodescript" & return & "on a" & return & "end a" & return & "```")
end TestMemoryProposals

on TestSystemPrompt
   local tPrompt
   put xtaSystemPrompt() into tPrompt
   TestAssert "names the language as OXT-Beyond does", tPrompt contains "Write xTalk Script for this engine" \
         and tPrompt contains "Call it xTalk Script when you write to the user"
   TestAssert "plain ASCII", not matchText(tPrompt, "[^\x09\x0A\x20-\x7E]")
end TestSystemPrompt

--------------------------------------------------------------------------------
-- What the tools read

-- An entry as the IDE's ideDocsFetchLCSData gives it (the shape the IDE's
-- documentation library had when this was written)
private function TestDictionaryEntry pName, pType
   local tEntry
   put pName into tEntry["display name"]
   put pType into tEntry["Type"]
   put "Places a <value> into a <container>." into tEntry["Summary"]
   put "put <value> [{before | into | after} <container>]" into tEntry["Syntax"][1]
   put "put <value> into URL <destinationURL>" into tEntry["Syntax"][2]
   put "value" into tEntry["params"][1]["name"]
   put "string" into tEntry["params"][1]["type"]
   put "container" into tEntry["params"][2]["name"]
   put "Where the <value> goes." & return & "A variable or a field." into tEntry["params"][2]["description"]
   put "Set to an error when writing a URL fails." into tEntry["value"]["The result"]["description"]
   put "Use the <put> command to set the value of a <variable>." into tEntry["Description"]
   put "put " & quote & "ABC" & quote into tEntry["Example"][1]
   put "local tX" & return & "put 3 into tX" into tEntry["Example"][2]
   put "URL" into tEntry["References"]["keyword"][1]
   put "binfile" into tEntry["References"]["keyword"][2]
   put "URL" into tEntry["References"]["keyword"][3]
   put "result" into tEntry["References"]["function"][1]
   put "1.0" into tEntry["Introduced"]
   return tEntry
end TestDictionaryEntry

on TestDictionaryText
   local tEntries, tText, tIndex
   put TestDictionaryEntry("put", "command") into tEntries[1]
   put xtaDictionaryText("put", tEntries) into tText
   TestDiagnostic tText
   TestAssert "names the entry", line 1 of tText begins with "The Dictionary's entry for" and "put (command)" is among the lines of tText
   TestAssert "the summary", "Summary: Places a <value> into a <container>." is among the lines of tText
   TestAssert "every syntax", "    put <value> [{before | into | after} <container>]" is among the lines of tText \
         and "    put <value> into URL <destinationURL>" is among the lines of tText
   TestAssert "the parameters", "    value (string)" is among the lines of tText \
         and "    container: Where the <value> goes." is among the lines of tText \
         and "    A variable or a field." is among the lines of tText
   TestAssert "what it returns", "    The result: Set to an error when writing a URL fails." is among the lines of tText
   TestAssert "the description", "Use the <put> command to set the value of a <variable>." is among the lines of tText
   TestAssert "the examples, indented", "    put " & quote & "ABC" & quote is among the lines of tText and "    put 3 into tX" is among the lines of tText
   TestAssert "see also, each once", "See also: function result, keyword URL, keyword binfile" is among the lines of tText
   TestAssert "when it came", "Introduced in 1.0." is among the lines of tText

   put xtaDictionaryText("nosuch", empty) into tText
   TestAssert "no entry says so", tText contains "no entry for" & quote & "nosuch" & quote or tText contains ("no entry for" && quote & "nosuch" & quote)

   repeat with tIndex = 1 to 6
      put TestDictionaryEntry("put", "command") into tEntries[tIndex]
   end repeat
   put "keyword" into tEntries[6]["Type"]
   put xtaDictionaryText("put", tEntries) into tText
   TestAssert "many entries: the first whole, the rest named", line 1 of tText begins with "The Dictionary has 6 entries" \
         and "Also: put (keyword)" is among the lines of tText
end TestDictionaryText

on TestErrorText
   local tTrace, tText, tWhere
   put "91,6,11,field" & return & "241,6,1,mouseUp" & return & "353,0,0,button id 1003 of card id 1002 of stack " & quote & "Demo" & quote into tTrace
   put xtaErrorText(tTrace) into tText
   TestDiagnostic tText
   TestAssert "one line for each", the number of lines of tText is 3
   TestAssert "the code, line, column and hint", line 1 of tText begins with "- " and line 1 of tText contains "error 91" \
         and line 1 of tText ends with ", line 6, column 11, near" && quote & "field" & quote
   TestAssert "the handler", line 2 of tText contains "error 241" and line 2 of tText contains ("near" && quote & "mouseUp" & quote)
   TestAssert "the object", line 3 of tText is ("- in the script of button id 1003 of card id 1002 of stack" && quote & "Demo" & quote)
   put xtaErrorWhere(tTrace) into tWhere
   TestAssert "where: the object and the line", tWhere["object"] is ("button id 1003 of card id 1002 of stack" && quote & "Demo" & quote) \
         and tWhere["line"] is 6
   TestAssert "an error the script threw", xtaErrorText("Out of paper") is "- thrown by the script: Out of paper"
   put xtaErrorWhere("Out of paper") into tWhere
   TestAssert "a trace with no line", tWhere["line"] is empty and tWhere["object"] is empty
end TestErrorText

on TestScriptExcerpt
   local tScript, tIndex, tText
   repeat with tIndex = 1 to 20
      put "line" && tIndex & return after tScript
   end repeat
   put xtaScriptExcerpt(tScript, 10) into tText
   TestDiagnostic tText
   TestAssert "five lines on each side", the number of lines of tText is 11 and line 1 of tText is " 5: line 5" and line -1 of tText is " 15: line 15"
   TestAssert "the line marked", line 6 of tText is ">10: line 10"
   TestAssert "at the top", line 1 of xtaScriptExcerpt(tScript, 1) is ">1: line 1"
   TestAssert "a line that is not there", xtaScriptExcerpt(tScript, 99) is empty and xtaScriptExcerpt(tScript, "x") is empty
end TestScriptExcerpt

-- A stack to read: two cards sharing a group, a substack, scripts
private command TestMakeStackToRead
   local tOldDefault
   put the defaultStack into tOldDefault
   create invisible stack "xtaReadMain"
   set the defaultStack to "xtaReadMain"
   set the script of stack "xtaReadMain" to "on openStack" & return & "end openStack"
   set the name of card 1 to "Main"
   create button "OK"
   set the rect of button "OK" to 10, 10, 110, 33
   set the script of button "OK" to "on mouseUp" & return & "   beep" & return & "end mouseUp"
   set the cSecret of button "OK" to "not shown"
   create field "Name"
   put "Ann" into field "Name"
   create group "Bar"
   create button "Inner" in group "Bar"
   set the backgroundBehavior of group "Bar" to true
   create card "Two"
   create invisible stack "xtaReadSub"
   set the mainStack of stack "xtaReadSub" to "xtaReadMain"
   set the defaultStack to "xtaReadSub"
   create button "Deep"
   set the defaultStack to tOldDefault
end TestMakeStackToRead

on TestStackOutline
   local tText
   TestMakeStackToRead
   put xtaStackOutline(the long id of stack "xtaReadMain") into tText
   TestDiagnostic tText
   TestAssert "the stack, its cards and its script", line 1 of tText begins with ("Stack" && quote & "xtaReadMain" & quote) \
         and line 1 of tText contains "2 cards" and line 1 of tText ends with ", script: 2 lines"
   TestAssert "the first card", ("  card" && quote & "Main" & quote && "(id" && the id of card "Main" of stack "xtaReadMain" & ")") is among the lines of tText
   TestAssert "a control, with its id, rect and script", \
         ("    button" && quote & "OK" & quote && "(id" && the id of button "OK" of card "Main" of stack "xtaReadMain" & ") at 10,10,110,33, script: 3 lines") is among the lines of tText
   TestAssert "a group's control under it", tText contains ("      button" && quote & "Inner" & quote)
   TestAssert "the group on the second card, listed once", tText contains ("): also on card" && quote & "Main" & quote & ", with its controls") \
         and the number of chars of tText - the number of chars of replaceText(tText, "Inner", "") is 5
   TestAssert "the substack", tText contains ("Substack" && quote & "xtaReadSub" & quote) and tText contains ("button" && quote & "Deep" & quote)
   TestAssert "a card with no name, by its id", ("  card id" && the id of card 1 of stack "xtaReadSub") is among the lines of tText
   delete stack "xtaReadMain"
end TestStackOutline

on TestObjectText
   local tText
   TestMakeStackToRead
   put xtaObjectText(the long id of button "OK" of card "Main" of stack "xtaReadMain") into tText
   TestDiagnostic tText
   TestAssert "what and where", line 1 of tText is ("button" && quote & "OK" & quote && "(id" && the id of button "OK" of card "Main" of stack "xtaReadMain" & ") on card" && \
         quote & "Main" & quote && "of stack" && quote & "xtaReadMain" & quote)
   TestAssert "its properties", "  rect: 10,10,110,33" is among the lines of tText and "  name: OK" is among the lines of tText
   TestAssert "custom properties by name only", "Custom properties (names only): cSecret" is among the lines of tText and not (tText contains "not shown")
   TestAssert "its script", tText contains ("```livecodescript" & return & "on mouseUp" & return & "   beep" & return & "end mouseUp" & return & "```")
   put xtaObjectText(the long id of field "Name" of card "Main" of stack "xtaReadMain") into tText
   TestAssert "a field's text", tText contains ("Text:" & return & "Ann") and tText ends with "No script."
   put xtaObjectText(the long id of card "Main" of stack "xtaReadMain") into tText
   TestAssert "a card's controls", tText contains ("Controls:" & return & "  button" && quote & "OK" & quote)
   put xtaObjectText(the long id of stack "xtaReadSub" of stack "xtaReadMain") into tText
   TestAssert "a substack", line 1 of tText contains ", a substack of" && quote & "xtaReadMain" & quote and tText contains "Cards:"
   delete stack "xtaReadMain"
end TestObjectText

-- Lean (the MCP bridge's read_stack): only what a new object of the
-- type would not have, and the custom properties' values
on TestObjectTextLean
   local tText, tFull
   TestMakeStackToRead
   put xtaObjectText(the long id of button "OK" of card "Main" of stack "xtaReadMain", true) into tText
   TestDiagnostic tText
   TestAssert "what it has of its own", "  rect: 10,10,110,33" is among the lines of tText and "  name: OK" is among the lines of tText
   TestAssert "custom properties with their values", "  cSecret: not shown" is among the lines of tText
   put xtaObjectText(the long id of button "OK" of card "Main" of stack "xtaReadMain") into tFull
   TestAssert "not lean, as before", "Custom properties (names only): cSecret" is among the lines of tFull
   TestAssert "not what every new button has", tText contains "that a new button does not have" \
         and the number of lines of tText * 2 < the number of lines of tFull
   delete stack "xtaReadMain"
end TestObjectTextLean

on TestNearest
   TestAssert "a letter or two away, nearest first", line 1 of xtaNearest("lable", "name" & return & "label" & return & "labels", 2) is "label"
   TestAssert "at most as many as asked", the number of lines of xtaNearest("lable", "label" & return & "labels" & return & "table", 2) is 2
   TestAssert "a name that holds it, before one it holds", xtaNearest("topstack", "stack" & return & "the topStack", 3) is ("the topStack" & return & "stack")
   TestAssert "nothing near", xtaNearest("zzzzzz", "label" & return & "name", 3) is empty
end TestNearest

--------------------------------------------------------------------------------
-- The context a local model is loaded with

-- Only a plain http:// base URL ending in /v1 is a server that may speak
-- LM Studio's own API: an online service is never asked
on TestLocalServerRoot
   TestAssert "LM Studio's", xtaLocalServerRoot("http://localhost:1234/v1") is "http://localhost:1234"
   TestAssert "with a slash after it", xtaLocalServerRoot(" http://192.168.1.5:1234/v1/ ") is "http://192.168.1.5:1234"
   TestAssert "not https", xtaLocalServerRoot("https://openrouter.ai/api/v1") is empty
   TestAssert "not without /v1", xtaLocalServerRoot("http://localhost:1234") is empty
   TestAssert "not Google's /v1beta", xtaLocalServerRoot("http://example.com/v1beta/openai") is empty
   TestAssert "not empty", xtaLocalServerRoot(empty) is empty
   TestAssert "not /v1 alone", xtaLocalServerRoot("http:///v1") is empty
end TestLocalServerRoot

-- An LM Studio model list with one model, pKey, its most context pMost
-- and its loaded instances pInstances (id <tab> context, one per line)
private function TestModelList pKey, pMost, pInstances
   local tLine, tList
   set the itemDelimiter to tab
   repeat for each line tLine in pInstances
      if tList is not empty then
         put comma after tList
      end if
      put "{" & TestQ("id") & ":" & TestQ(item 1 of tLine) & "," & TestQ("config") & ":{" & \
            TestQ("context_length") & ":" & item 2 of tLine & "," & TestQ("flash_attention") & ":true}}" after tList
   end repeat
   return "{" & TestQ("models") & ":[{" & TestQ("type") & ":" & TestQ("embedding") & "," & TestQ("key") & ":" & TestQ("text-embed") & "," & \
         TestQ("loaded_instances") & ":[]}," & "{" & TestQ("type") & ":" & TestQ("llm") & "," & TestQ("key") & ":" & TestQ(pKey) & "," & \
         TestQ("variants") & ":[" & TestQ(pKey & "@q4_k_m") & "," & TestQ(pKey & "@q8_0") & "]," & \
         TestQ("loaded_instances") & ":[" & tList & "]," & TestQ("max_context_length") & ":" & pMost & "}]}"
end TestModelList

private function TestAction pPlan
   return pPlan["action"]
end TestAction

on TestContextPlan
   local tPlan
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, empty), "qwen/qwen3-8b", 16384) into tPlan
   TestAssert "not loaded: load it", tPlan["action"] is "load" and tPlan["context"] is 16384 and tPlan["loaded"] is empty
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 4096), "qwen/qwen3-8b", 16384) into tPlan
   TestDiagnostic tPlan["action"] && tPlan["loaded"] && tPlan["unload"]
   TestAssert "loaded with less: reload it", tPlan["action"] is "reload" and tPlan["loaded"] is 4096 \
         and tPlan["unload"] is "qwen/qwen3-8b" and tPlan["context"] is 16384
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 16384), "qwen/qwen3-8b", 16384) into tPlan
   TestAssert "loaded with as much: nothing", tPlan["action"] is "none" and tPlan["loaded"] is 16384
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 32768), "qwen/qwen3-8b", 16384) into tPlan
   TestAssert "loaded with more: nothing (never made shorter)", tPlan["action"] is "none"
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 8192, empty), "qwen/qwen3-8b", 16384) into tPlan
   TestAssert "no more than the model takes", tPlan["action"] is "load" and tPlan["context"] is 8192
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 8192, "qwen/qwen3-8b" & tab & 8192), "qwen/qwen3-8b", 16384) into tPlan
   TestAssert "already all it takes: nothing", tPlan["action"] is "none"
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, empty), "qwen/qwen3-8b@q8_0", 16384) into tPlan
   TestAssert "a variant is the model's", tPlan["action"] is "load"
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 32768 & return & "qwen/qwen3-8b:2" & tab & 4096), "qwen/qwen3-8b:2", 16384) into tPlan
   TestDiagnostic tPlan["action"] && tPlan["loaded"] && tPlan["key"] && tPlan["unload"]
   TestAssert "a loaded copy named, with less: only it counts, and it is left loaded", tPlan["action"] is "instance" \
         and tPlan["loaded"] is 4096 and tPlan["key"] is "qwen/qwen3-8b" and tPlan["unload"] is empty
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 4096 & return & "qwen/qwen3-8b:2" & tab & 32768), "qwen/qwen3-8b:2", 16384) into tPlan
   TestAssert "a loaded copy named, with enough: nothing", tPlan["action"] is "none" and tPlan["loaded"] is 32768
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "my-qwen" & tab & 4096), "my-qwen", 16384) into tPlan
   TestAssert "a loaded copy under a name of the user's own, with less: left loaded", tPlan["action"] is "instance" \
         and tPlan["key"] is "qwen/qwen3-8b" and tPlan["unload"] is empty
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b@q8_0" & tab & 4096), "qwen/qwen3-8b@q8_0", 16384) into tPlan
   TestAssert "a variant's own name is the model's: reloaded", tPlan["action"] is "reload" and tPlan["unload"] is "qwen/qwen3-8b@q8_0"
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 4096 & return & "qwen/qwen3-8b:2" & tab & 32768), "qwen/qwen3-8b", 16384) into tPlan
   TestAssert "the instance the request names has less: only it is reloaded", tPlan["action"] is "reload" and tPlan["unload"] is "qwen/qwen3-8b"
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b:1" & tab & 4096 & return & "qwen/qwen3-8b:2" & tab & 32768), "qwen/qwen3-8b", 16384) into tPlan
   TestAssert "none named, one of the model's has enough: nothing", tPlan["action"] is "none" and tPlan["loaded"] is 32768
   put xtaContextPlan(TestModelList("qwen/qwen3-8b", 32768, empty), "another-model", 16384) into tPlan
   TestAssert "a model not in the list: unknown", tPlan["action"] is "unknown"
   TestAssert "an answer that is not LM Studio's: unknown", TestAction(xtaContextPlan("{" & TestQ("data") & ":[]}", "m", 16384)) is "unknown"
   TestAssert "an answer that is not JSON: unknown", TestAction(xtaContextPlan("<html>404</html>", "m", 16384)) is "unknown"
   TestAssert "no context asked for: nothing", TestAction(xtaContextPlan(TestModelList("m", 32768, empty), "m", empty)) is "none"
end TestContextPlan

-- Nothing is asked of the server but the request when no context length
-- is set, for Anthropic, or for a base URL that is not a server of the
-- user's own: requests go exactly as before
on TestEnsureContextAsksNothingWithoutIt
   local tSettings
   put "openai" into tSettings["provider"]
   put "http://127.0.0.1:1/v1" into tSettings["baseUrl"]
   put "m" into tSettings["model"]
   TestAssert "no context length", TestAction(xtaEnsureContext(tSettings)) is "none"
   put "lots" into tSettings["contextLength"]
   TestAssert "not a number", TestAction(xtaEnsureContext(tSettings)) is "none"
   put 16384 into tSettings["contextLength"]
   put "anthropic" into tSettings["provider"]
   TestAssert "not for Anthropic", TestAction(xtaEnsureContext(tSettings)) is "none"
   put "openai" into tSettings["provider"]
   put "https://openrouter.ai/api/v1" into tSettings["baseUrl"]
   TestAssert "not for an online service", TestAction(xtaEnsureContext(tSettings)) is "none"
   put empty into tSettings["baseUrl"]
   TestAssert "not for OpenAI's own", TestAction(xtaEnsureContext(tSettings)) is "none"
end TestEnsureContextAsksNothingWithoutIt

--------------------------------------------------------------------------------
-- Round trips through libURL to a server of this process

private function TestStartServer pStatus, pBody
   local tBytes
   put textEncode(pBody, "UTF-8") into tBytes
   put "HTTP/1.1" && pStatus & crlf & "Content-Type: application/json" & crlf & \
         "Content-Length:" && the number of bytes of tBytes & crlf & "Connection: close" & crlf & crlf & tBytes into sResponse
   put empty into sRequest
   TestSkipIfNot "sockets"
   accept connections on port 0 with message "xtaTestServerAccept"
   return it
end TestStartServer

on xtaTestServerAccept pSocket
   read from socket pSocket until crlf & crlf with message "xtaTestServerHeaders"
end xtaTestServerAccept

on xtaTestServerHeaders pSocket, pData
   local tLength
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
   put pData after sRequest
   put the socketTimeoutInterval into sWaitDuring
   write sResponse to socket pSocket
   close socket pSocket
end xtaTestServerBody

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
   local tAt
   put offset(crlf & crlf, sRequest) into tAt
   return textDecode(char tAt + 4 to -1 of sRequest, "UTF-8")
end TestRequestBody

on TestAskAnthropic
   local tPort, tSettings, tReply, tDoc, tOldHeaders, tOldTimeout
   put TestStartServer("200 OK", "{" & TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & \
         TestQ("text") & ":" & TestQ("Hi " & numToCodepoint(233)) & "}]," & TestQ("stop_reason") & ":" & TestQ("end_turn") & "}") into tPort
   put "anthropic" into tSettings["provider"]
   put "http://127.0.0.1:" & tPort into tSettings["baseUrl"]
   put "sk-local" into tSettings["key"]
   put "test-model" into tSettings["model"]
   set the httpHeaders to "X-Before: 1"
   put the socketTimeoutInterval into tOldTimeout
   put xtaAsk(tSettings, "System text", TestTurns()) into tReply
   TestDiagnostic sRequest
   TestAssert "the request went to /v1/messages", sRequest begins with "POST /v1/messages HTTP/1.1"
   TestAssert "the key", TestRequestHeader("x-api-key") is "sk-local"
   TestAssert "the version", TestRequestHeader("anthropic-version") is "2023-06-01"
   TestAssert "JSON", TestRequestHeader("Content-Type") is "application/json"
   put xtaJsonParse(TestRequestBody()) into tDoc
   TestAssert "the body", xtaJsonText(xtaJsonMember(tDoc, "model")) is "test-model" \
         and xtaJsonText(xtaJsonMember(tDoc, "system")) is "System text" \
         and xtaJsonCount(xtaJsonMember(tDoc, "messages")) is 3
   TestAssert "the answer", tReply["ok"] is true and tReply["text"] is ("Hi " & numToCodepoint(233))
   TestAssert "the httpHeaders are put back", the httpHeaders is "X-Before: 1"
   TestAssert "the timeout is put back", the socketTimeoutInterval is tOldTimeout
   set the httpHeaders to empty
end TestAskAnthropic

-- libURL waits ten minutes for an answer, or longer for one given more
-- room, as it arrives whole when the model is done; or as long as the user
-- said
on TestAskWaitsForTheAnswer
   local tPort, tSettings, tReply, tOldTimeout, tBody
   put "{" & TestQ("content") & ":[{" & TestQ("type") & ":" & TestQ("text") & "," & TestQ("text") & ":" & TestQ("Hi") & "}]," & \
         TestQ("stop_reason") & ":" & TestQ("end_turn") & "}" into tBody
   put the socketTimeoutInterval into tOldTimeout
   put TestStartServer("200 OK", tBody) into tPort
   put "anthropic" into tSettings["provider"]
   put "http://127.0.0.1:" & tPort into tSettings["baseUrl"]
   put "sk-local" into tSettings["key"]
   put "test-model" into tSettings["model"]
   put xtaAsk(tSettings, empty, TestTurns()) into tReply
   TestAssert "ten minutes for the default room", tReply["ok"] is true and sWaitDuring is 600000
   put TestStartServer("200 OK", tBody) into tPort
   put "http://127.0.0.1:" & tPort into tSettings["baseUrl"]
   put 32000 into tSettings["maxTokens"]
   put xtaAsk(tSettings, empty, TestTurns()) into tReply
   TestAssert "fifteen for twice as much", tReply["ok"] is true and sWaitDuring is 900000 \
         and xtaJsonText(xtaJsonMember(xtaJsonParse(TestRequestBody()), "max_tokens")) is 32000
   put TestStartServer("200 OK", tBody) into tPort
   put "http://127.0.0.1:" & tPort into tSettings["baseUrl"]
   put 60 into tSettings["timeout"]
   put xtaAsk(tSettings, empty, TestTurns()) into tReply
   TestAssert "as long as the user said", tReply["ok"] is true and sWaitDuring is 60000
   TestAssert "and the engine's is put back", the socketTimeoutInterval is tOldTimeout
end TestAskWaitsForTheAnswer

on TestAskOpenAI
   local tPort, tSettings, tReply, tDoc
   put TestStartServer("200 OK", "{" & TestQ("choices") & ":[{" & TestQ("message") & ":{" & TestQ("role") & ":" & TestQ("assistant") & "," & \
         TestQ("content") & ":" & TestQ("Hello") & "}," & TestQ("finish_reason") & ":" & TestQ("stop") & "}]}") into tPort
   put "openai" into tSettings["provider"]
   put "http://127.0.0.1:" & tPort & "/v1/" into tSettings["baseUrl"]
   put "sk-local" into tSettings["key"]
   put "test-model" into tSettings["model"]
   put xtaAsk(tSettings, "System text", TestTurns()) into tReply
   TestDiagnostic sRequest
   TestAssert "the request went to /v1/chat/completions", sRequest begins with "POST /v1/chat/completions HTTP/1.1"
   TestAssert "the bearer token", TestRequestHeader("Authorization") is "Bearer sk-local"
   put xtaJsonParse(TestRequestBody()) into tDoc
   TestAssert "the system prompt is the first message", xtaJsonText(xtaJsonGet(tDoc, "messages/1/content")) is "System text"
   TestAssert "the answer", tReply["ok"] is true and tReply["text"] is "Hello"
end TestAskOpenAI

on TestAskRefusedKey
   local tPort, tSettings, tReply
   put TestStartServer("401 Unauthorized", "{" & TestQ("type") & ":" & TestQ("error") & "," & TestQ("error") & ":{" & TestQ("type") & ":" & \
         TestQ("authentication_error") & "," & TestQ("message") & ":" & TestQ("invalid x-api-key") & "}}") into tPort
   put "anthropic" into tSettings["provider"]
   put "http://127.0.0.1:" & tPort into tSettings["baseUrl"]
   put "wrong" into tSettings["key"]
   put "test-model" into tSettings["model"]
   put xtaAsk(tSettings, empty, TestTurns()) into tReply
   TestDiagnostic tReply["error"]
   TestAssert "not ok", tReply["ok"] is false
   TestAssert "says the key was refused", tReply["error"] contains "API key" and tReply["error"] contains "invalid x-api-key"
end TestAskRefusedKey

on TestAskNoServer
   local tPort, tSettings, tReply
   -- A port that was open a moment ago and is closed now
   accept connections on port 0 with message "xtaTestServerAccept"
   put it into tPort
   close socket tPort
   put "openai" into tSettings["provider"]
   put "http://127.0.0.1:" & tPort into tSettings["baseUrl"]
   put "test-model" into tSettings["model"]
   put xtaAsk(tSettings, empty, TestTurns()) into tReply
   TestDiagnostic tReply["error"]
   TestAssert "not ok", tReply["ok"] is false
   TestAssert "says why", tReply["error"] is not empty
   TestAssert "and what to try, for a server of the user's own", line 2 of tReply["error"] begins with "Is the server running?"
   put "anthropic" into tSettings["provider"]
   put xtaAsk(tSettings, empty, TestTurns()) into tReply
   TestAssert "not for Anthropic's API", the number of lines of tReply["error"] is 1
end TestAskNoServer

on TestListModels
   local tPort, tSettings, tResult
   put TestStartServer("200 OK", "{" & TestQ("data") & ":[{" & TestQ("id") & ":" & TestQ("model-a") & "}]}") into tPort
   put "anthropic" into tSettings["provider"]
   put "http://127.0.0.1:" & tPort into tSettings["baseUrl"]
   put "sk-local" into tSettings["key"]
   put xtaListModels(tSettings) into tResult
   TestDiagnostic sRequest
   TestAssert "asked for the models", sRequest begins with "GET /v1/models?limit=100 HTTP/1.1"
   TestAssert "with the key", TestRequestHeader("x-api-key") is "sk-local"
   TestAssert "the list", tResult["models"] is "model-a"
end TestListModels

--------------------------------------------------------------------------------
-- Round trips to a server that answers each request line as it was told

private function TestStartRoutes
   put empty into sRouteLog
   put empty into sRouteBodies
   TestSkipIfNot "sockets"
   accept connections on port 0 with message "xtaTestRouteAccept"
   return it
end TestStartRoutes

private command TestRoute pRequestLine, pStatus, pBody
   local tBytes
   put textEncode(pBody, "UTF-8") into tBytes
   put "HTTP/1.1" && pStatus & crlf & "Content-Type: application/json" & crlf & \
         "Content-Length:" && the number of bytes of tBytes & crlf & "Connection: close" & crlf & crlf & tBytes into sRoutes[pRequestLine]
end TestRoute

on xtaTestRouteAccept pSocket
   read from socket pSocket until crlf & crlf with message "xtaTestRouteHeaders"
end xtaTestRouteAccept

on xtaTestRouteHeaders pSocket, pData
   local tLength, tLine
   put word 1 to 2 of line 1 of pData & return after sRouteLog
   repeat for each line tLine in pData
      if tLine begins with "Content-Length:" then
         put word 2 of tLine into tLength
      end if
   end repeat
   if tLength is an integer and tLength > 0 then
      read from socket pSocket for tLength bytes with message "xtaTestRouteBody"
   else
      xtaTestRouteBody pSocket, empty
   end if
end xtaTestRouteHeaders

on xtaTestRouteBody pSocket, pData
   local tLine, tResponse
   put the number of lines of sRouteLog into tLine
   put textDecode(pData, "UTF-8") into sRouteBodies[tLine]
   put sRoutes[line tLine of sRouteLog] into tResponse
   if tResponse is empty then
      put "HTTP/1.1 404 Not Found" & crlf & "Content-Length: 0" & crlf & "Connection: close" & crlf & crlf into tResponse
   end if
   write tResponse to socket pSocket
   close socket pSocket
end xtaTestRouteBody

private function TestChatAnswer
   return "{" & TestQ("choices") & ":[{" & TestQ("message") & ":{" & TestQ("role") & ":" & TestQ("assistant") & "," & \
         TestQ("content") & ":" & TestQ("Hello") & "}," & TestQ("finish_reason") & ":" & TestQ("stop") & "}]}"
end TestChatAnswer

private function TestLocalSettings pPort, pContext
   local tSettings
   put "openai" into tSettings["provider"]
   put "http://127.0.0.1:" & pPort & "/v1" into tSettings["baseUrl"]
   put "qwen/qwen3-8b" into tSettings["model"]
   put pContext into tSettings["contextLength"]
   return tSettings
end TestLocalSettings

-- Without a context length, only the request goes, as before
on TestAskLocalWithoutContextLength
   local tPort, tReply
   delete variable sRoutes
   put TestStartRoutes() into tPort
   TestRoute "POST /v1/chat/completions", "200 OK", TestChatAnswer()
   TestRoute "GET /api/v1/models", "200 OK", TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 4096)
   put xtaAsk(TestLocalSettings(tPort, empty), "System text", TestTurns()) into tReply
   close socket tPort
   TestDiagnostic sRouteLog
   TestAssert "the answer", tReply["ok"] is true and tReply["text"] is "Hello"
   TestAssert "only the request", sRouteLog is ("POST /v1/chat/completions" & return)
   TestAssert "and the request has no new member", not (sRouteBodies[1] contains "context")
end TestAskLocalWithoutContextLength

-- LM Studio has the model loaded with less: it is unloaded and loaded with
-- the context the user set, then the request goes
on TestAskLocalReloadsWithTheContext
   local tPort, tReply, tDoc
   delete variable sRoutes
   put TestStartRoutes() into tPort
   TestRoute "GET /api/v1/models", "200 OK", TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 4096)
   TestRoute "POST /api/v1/models/unload", "200 OK", "{" & TestQ("instance_id") & ":" & TestQ("qwen/qwen3-8b") & "}"
   TestRoute "POST /api/v1/models/load", "200 OK", "{" & TestQ("type") & ":" & TestQ("llm") & "," & TestQ("instance_id") & ":" & TestQ("qwen/qwen3-8b") & "," & TestQ("status") & ":" & TestQ("loaded") & "}"
   TestRoute "POST /v1/chat/completions", "200 OK", TestChatAnswer()
   put xtaAsk(TestLocalSettings(tPort, 16384), "System text", TestTurns()) into tReply
   close socket tPort
   TestDiagnostic sRouteLog
   TestAssert "the answer", tReply["ok"] is true and tReply["text"] is "Hello"
   TestAssert "asked for the list, unloaded, loaded, then asked", sRouteLog is \
         ("GET /api/v1/models" & return & "POST /api/v1/models/unload" & return & "POST /api/v1/models/load" & return & "POST /v1/chat/completions" & return)
   TestAssert "unloaded the instance with less", xtaJsonText(xtaJsonMember(xtaJsonParse(sRouteBodies[2]), "instance_id")) is "qwen/qwen3-8b"
   put xtaJsonParse(sRouteBodies[3]) into tDoc
   TestAssert "loaded the model with the context", xtaJsonText(xtaJsonMember(tDoc, "model")) is "qwen/qwen3-8b" \
         and xtaJsonText(xtaJsonMember(tDoc, "context_length")) is 16384
   TestAssert "and the request has no new member", not (sRouteBodies[4] contains "context")
end TestAskLocalReloadsWithTheContext

-- Loaded with enough: only the list is asked for
on TestAskLocalAlreadyLoaded
   local tPort, tReply
   delete variable sRoutes
   put TestStartRoutes() into tPort
   TestRoute "GET /api/v1/models", "200 OK", TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 16384)
   TestRoute "POST /v1/chat/completions", "200 OK", TestChatAnswer()
   put xtaAsk(TestLocalSettings(tPort, 16384), empty, TestTurns()) into tReply
   close socket tPort
   TestAssert "the answer", tReply["ok"] is true
   TestAssert "nothing loaded", sRouteLog is ("GET /api/v1/models" & return & "POST /v1/chat/completions" & return)
end TestAskLocalAlreadyLoaded

-- A server with no such list (Ollama, llama.cpp: 404) is left as it is
on TestAskLocalServerWithoutTheList
   local tPort, tReply
   delete variable sRoutes
   put TestStartRoutes() into tPort
   TestRoute "POST /v1/chat/completions", "200 OK", TestChatAnswer()
   put xtaAsk(TestLocalSettings(tPort, 16384), empty, TestTurns()) into tReply
   close socket tPort
   TestAssert "the answer", tReply["ok"] is true and tReply["text"] is "Hello"
   TestAssert "the list was asked for, nothing loaded", sRouteLog is ("GET /api/v1/models" & return & "POST /v1/chat/completions" & return)
end TestAskLocalServerWithoutTheList

-- The model is chosen by the name of a loaded copy (LM Studio names a
-- second copy of a model "<model>:2", and the user can name one), and
-- that copy has less. LM Studio loads a model by the model's own name
-- and names the copy itself, so a copy unloaded could not be had back
-- under its name: it is left loaded, the request goes to it as before,
-- and when the request is refused the error says which name to choose
on TestAskLocalNamedCopyIsLeftLoaded
   local tPort, tReply, tSettings
   delete variable sRoutes
   put TestStartRoutes() into tPort
   TestRoute "GET /api/v1/models", "200 OK", TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 32768 & return & "qwen/qwen3-8b:2" & tab & 4096)
   TestRoute "POST /api/v1/models/unload", "200 OK", "{" & TestQ("instance_id") & ":" & TestQ("qwen/qwen3-8b:2") & "}"
   TestRoute "POST /api/v1/models/load", "404 Not Found", "{" & TestQ("error") & ":{" & TestQ("message") & ":" & TestQ("Model not found") & "}}"
   TestRoute "POST /v1/chat/completions", "400 Bad Request", "{" & TestQ("error") & ":" & TestQ("the model is loaded with context length of only 4096 tokens") & "}"
   put TestLocalSettings(tPort, 16384) into tSettings
   put "qwen/qwen3-8b:2" into tSettings["model"]
   put xtaAsk(tSettings, empty, TestTurns()) into tReply
   close socket tPort
   TestDiagnostic sRouteLog
   TestDiagnostic tReply["error"]
   TestAssert "the list was asked for, nothing unloaded or loaded, then the request", sRouteLog is \
         ("GET /api/v1/models" & return & "POST /v1/chat/completions" & return)
   TestAssert "the request names the copy, as before", xtaJsonText(xtaJsonMember(xtaJsonParse(sRouteBodies[2]), "model")) is "qwen/qwen3-8b:2"
   TestAssert "not ok", tReply["ok"] is false
   TestAssert "says what it is loaded with, and which name to choose", tReply["error"] contains "qwen/qwen3-8b:2" \
         and tReply["error"] contains "4096 tokens" and tReply["error"] contains "Choose qwen/qwen3-8b in the Settings"
   -- (and a request that is answered is the answer, with nothing added)
   delete variable sRoutes
   put TestStartRoutes() into tPort
   TestRoute "GET /api/v1/models", "200 OK", TestModelList("qwen/qwen3-8b", 32768, "qwen/qwen3-8b" & tab & 32768 & return & "qwen/qwen3-8b:2" & tab & 4096)
   TestRoute "POST /v1/chat/completions", "200 OK", TestChatAnswer()
   put TestLocalSettings(tPort, 16384) into tSettings
   put "qwen/qwen3-8b:2" into tSettings["model"]
   put xtaAsk(tSettings, empty, TestTurns()) into tReply
   close socket tPort
   TestAssert "answered: the answer", tReply["ok"] is true and tReply["text"] is "Hello" and tReply["error"] is empty
   TestAssert "answered: nothing unloaded or loaded", sRouteLog is ("GET /api/v1/models" & return & "POST /v1/chat/completions" & return)
end TestAskLocalNamedCopyIsLeftLoaded

-- The model could not be loaded with the context, and the request was
-- refused: the error says why it was not loaded
on TestAskLocalLoadFails
   local tPort, tReply
   delete variable sRoutes
   put TestStartRoutes() into tPort
   TestRoute "GET /api/v1/models", "200 OK", TestModelList("qwen/qwen3-8b", 32768, empty)
   TestRoute "POST /api/v1/models/load", "500 Internal Server Error", "{" & TestQ("error") & ":{" & TestQ("message") & ":" & TestQ("Not enough memory") & "}}"
   TestRoute "POST /v1/chat/completions", "400 Bad Request", "{" & TestQ("error") & ":" & TestQ("the model is loaded with context length of only 4096 tokens") & "}"
   put xtaAsk(TestLocalSettings(tPort, 16384), empty, TestTurns()) into tReply
   close socket tPort
   TestDiagnostic tReply["error"]
   TestAssert "not ok", tReply["ok"] is false
   TestAssert "says the model could not be loaded, and why", tReply["error"] contains "could not load qwen/qwen3-8b with a context of 16384 tokens" \
         and tReply["error"] contains "Not enough memory"
end TestAskLocalLoadFails
