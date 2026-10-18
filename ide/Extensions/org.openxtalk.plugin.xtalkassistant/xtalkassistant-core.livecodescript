script "org.openxtalk.plugin.xtalkassistant-core"
-- OXT-Beyond: the core of the xTalk Assistant plugin.
--
-- Everything here works without the IDE: JSON in and out, the requests and
-- answers of the two kinds of provider, the one HTTP call, and the text the
-- assistant shows. The plugin's main stack (xtalkassistant.livecodescript)
-- holds the window, the settings and the IDE glue, and loads this stack with
-- "start using". The engine tests in tests/lcs/xtalkassistant load it the
-- same way and talk to a server of their own, so nothing here needs a key or
-- the internet to be tested.
--
-- Providers:
--    "anthropic"  the Anthropic Messages API (POST <base>/v1/messages, the
--                 key in an x-api-key header). Base: https://api.anthropic.com
--    "openai"     the OpenAI Chat Completions API (POST <base>/chat/completions,
--                 the key as a Bearer token). Base: https://api.openai.com/v1.
--                 Other services and local servers that speak the same API
--                 work with their own base URL; they may need no key.
--
-- Model names change faster than this IDE does, so the window asks the
-- provider for its list (xtaModelsUrl, xtaParseModels), which also names
-- the model to use when the user has chosen none (xtaDefaultModel). The
-- few names built in (xtaSuggestedModels) are the providers' current
-- recommendations, offered in the model menu before the list has come and
-- put first in it after; a name the user types is used as typed.
--
-- A conversation is an array of turns, keys 1 to N, each with "role"
-- ("user" or "assistant") and "text". An answer may ask for tools: its
-- turn then has "calls" (keys 1 to N, each with "id", "name" and "input",
-- the JSON object of the call's arguments), and the turn after it has
-- "kind" "tools" and "results" (keys 1 to N, one for each call in their
-- order, with "text", and "error" true when the tool could not do it).
--
-- Public handlers:
--    xtaJsonString(pText)                  pText as a JSON string
--    xtaJsonParse(pJSON)                   a parsed value (see "JSON in")
--    xtaJsonType, xtaJsonCount, xtaJsonItem, xtaJsonMember, xtaJsonText,
--    xtaJsonGet, xtaJsonRaw                read a parsed value
--    xtaProviders()                        "anthropic,openai"
--    xtaDefaultBaseUrl(pProvider)
--    xtaRequestUrl(pProvider, pBaseUrl), xtaModelsUrl(pProvider, pBaseUrl)
--    xtaRequestHeaders(pProvider, pKey)    header lines for the httpHeaders
--    xtaRequestBody(pProvider, pModel, pSystem, pTurns, pMaxTokens, pTools,
--                   pTokensName)
--    xtaMaxTokens(pProvider, pMaxTokens)   the longest answer a request
--                                          asks for (empty: none)
--    xtaParseReply(pProvider, pStatus, pBody)
--    xtaParseModels(pProvider, pStatus, pBody)
--    xtaDefaultModel(pProvider, pIds, pCreated)  the model to begin with
--    xtaSuggestedModels(pProvider), xtaModelMenu(pProvider, pIds)
--                                          the model menu
--    xtaHttpPost(pUrl, pHeaders, pBody, pTimeout),
--    xtaHttpGet(pUrl, pHeaders, pTimeout)
--    xtaRequestWait(pTimeout, pMaxTokens)  how long a request may go
--                                          without data, in seconds
--    xtaAsk(pSettings, pSystem, pTurns, pTools)  one round trip, as
--                                          xtaParseReply
--    xtaDictionaryText(pTerm, pEntries)    a Dictionary entry, for the model
--    xtaErrorText(pTrace), xtaScriptExcerpt(pScript, pLine)
--                                          an error the user hit, for the model
--    xtaStackOutline(pStack), xtaObjectText(pObject, pLean)
--                                          the user's stack, for the model
--    xtaNearest(pWord, pNames, pMax)       the names nearest a misspelt one
--    xtaCodeBlocks(pText)                  the fenced code blocks of a reply
--    xtaIsXTalkLang(pLang), xtaXTalkBlocks(pBlocks)   which blocks are xTalk
--    xtaSystemPrompt()                     the short guide, built in
--    xtaReadGuide(pPath)                   the guide (xtalk-guide.md)
--    xtaDeclaredNames(pScript)             what a script declares at its top
--    xtaScriptCounts(pCode)                its handlers and its statements
--    xtaCheckScript(pCode, pDeclared), xtaCheckBlocks(pBlocks, pDeclared),
--    xtaCheckCleanup                       compile checks (see "Checking code")
--    xtaMemoryParse, xtaMemoryFormat, xtaMemoryLoad, xtaMemorySave,
--    xtaMemoryAdd, xtaMemoryNotes, xtaMemorySetNotes, xtaMemoryNoteProblem,
--    xtaMemoryPrompt, xtaMemoryProposals, xtaWithoutMemoryBlocks
--                                          the notes it keeps (see "Memory")

-- Anthropic's API version header; the Messages API has used this one since
-- it was introduced.
constant kAnthropicVersion = "2023-06-01"
constant kAnthropicBaseUrl = "https://api.anthropic.com"
constant kOpenAIBaseUrl = "https://api.openai.com/v1"
-- Anthropic requires max_tokens; this is used when the settings give none.
-- Its models think before they answer (Claude Opus 5.5 always does), and
-- the thinking counts toward max_tokens: with the 4096 of 0.2.5-rc.4 a
-- question that builds a stack could use them all up thinking, and the
-- answer came back empty. 16000 is what Anthropic advises for a request
-- that is not streamed.
constant kDefaultMaxTokens = 16000
-- How long a request may go without data. A (non-streamed) answer arrives
-- whole when the model is done, which for kDefaultMaxTokens can take three
-- minutes or more, and libURL gives up after the engine's
-- socketTimeoutInterval (10 seconds by default). Ten minutes, as
-- Anthropic's own libraries wait; longer for an answer given more room
-- (xtaRequestWait).
constant kRequestTimeoutMilliseconds = 600000
-- How long the longest answer may take, as Anthropic's libraries reckon
-- it: an hour for 128000 tokens
constant kTokensAnHour = 128000
-- Asking for the models takes a moment, so it is not given as long
constant kListTimeoutSeconds = 180
-- How deeply JSON may nest before the reader refuses it.
constant kJsonMaxDepth = 64
-- The hidden stack whose button the compile checks set the script of. Its
-- name begins with "rev", so the IDE treats it as one of its own.
constant kCheckStack = "revXTalkAssistantCheck"
-- The handler that statements are put in to be compiled
constant kCheckHandler = "xtaCheckStatements"
-- The languages of a fenced block that are xTalk; a block with none is
-- taken for xTalk too
constant kXTalkLangs = "livecodescript,livecode,lcs,xtalk"
-- The longest note the memory keeps, and the most text of notes about the
-- user, or about one stack: all of it goes with every question
constant kMemoryMaxNote = 300
constant kMemoryMaxScope = 3000
-- The most text one tool gives the model (a Dictionary lookup, an outline
-- of a stack, an object), what of a Dictionary entry it gives, and how many
-- lines of a script it shows on each side of an error's line
constant kReadMaxChars = 24000
constant kDictionaryMaxEntries = 4
constant kDictionaryMaxDescription = 6000
constant kDictionaryMaxExamples = 5
constant kExcerptLines = 5
-- The property values shown of an object are those this long at most
constant kMaxPropertyChars = 200
-- The execution error whose hint is the object the error was in
constant kObjectNameError = 353

-- The JSON reader's state while it reads one text: the text, where it is,
-- the length in code units, the nesting depth, and the position of the next
-- backslash at or after sJPos (0 when there is none left, -1 when it has not
-- been looked for yet).
local sJText, sJPos, sJLen, sJDepth, sJNextBackslash

--------------------------------------------------------------------------------
-- JSON out

-- pText as a JSON string, with its quotes. Backslash, quote and the control
-- characters are escaped; everything else goes as it is, and the caller
-- encodes the whole request as UTF-8. The engine's "replace" works on code
-- units, so a quote followed by a combining mark is still found and escaped.
function xtaJsonString pText
   local tOut, tCode
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
         replace numToChar(tCode) with numToChar(92) & "u00" & xtaHexByte(tCode) in tOut
      end if
   end repeat
   return quote & tOut & quote
end xtaJsonString

private function xtaHexByte pCode
   local tHex
   put toLower(baseConvert(pCode, 10, 16)) into tHex
   if the number of chars of tHex < 2 then
      put "0" before tHex
   end if
   return tHex
end xtaHexByte

private function xtaJsonPair pName, pJson
   return xtaJsonString(pName) & ":" & pJson
end xtaJsonPair

--------------------------------------------------------------------------------
-- JSON in
--
-- A parsed value is an array with "type" ("object", "array", "string",
-- "number", "boolean" or "null"), "from" and "to" (where it is in the text,
-- in code units, so xtaJsonRaw can give it back exactly as it was sent), and
-- by type:
--    object   "count", "names" (1 to count, in the order they came) and
--             "members" (the values, by name)
--    array    "count" and "items" (1 to count)
--    other    "value" ("true" or "false" for a boolean, empty for null, the
--             number as written)
-- The engine's array keys ignore case, so two member names that differ only
-- in case are one member here (the later one wins). The APIs read here use
-- lower-case names.

function xtaJsonParse pJSON
   local tNode
   put pJSON into sJText
   put 1 into sJPos
   put the number of codeunits of pJSON into sJLen
   put 0 into sJDepth
   put -1 into sJNextBackslash
   put xtaJValue() into tNode
   xtaJSkip
   if sJPos <= sJLen then
      xtaJFail "there is more text after the value"
   end if
   put empty into sJText
   return tNode
end xtaJsonParse

private command xtaJFail pWhat
   put empty into sJText
   throw "xTalk Assistant: the JSON is not valid:" && pWhat && "(at character" && sJPos & ")"
end xtaJFail

private command xtaJSkip
   local tC
   repeat while sJPos <= sJLen
      put codeunit sJPos of sJText into tC
      if tC is space or tC is tab or tC is numToChar(10) or tC is numToChar(13) then
         add 1 to sJPos
      else
         exit repeat
      end if
   end repeat
end xtaJSkip

private function xtaJValue
   local tC, tNode
   xtaJSkip
   if sJPos > sJLen then
      xtaJFail "a value is missing"
   end if
   put codeunit sJPos of sJText into tC
   if tC is "{" then
      return xtaJObject()
   end if
   if tC is "[" then
      return xtaJArray()
   end if
   put sJPos into tNode["from"]
   if tC is quote then
      put "string" into tNode["type"]
      put xtaJStringBody() into tNode["value"]
   else if codeunit sJPos to sJPos + 3 of sJText is "true" then
      put "boolean" into tNode["type"]
      put "true" into tNode["value"]
      add 4 to sJPos
   else if codeunit sJPos to sJPos + 4 of sJText is "false" then
      put "boolean" into tNode["type"]
      put "false" into tNode["value"]
      add 5 to sJPos
   else if codeunit sJPos to sJPos + 3 of sJText is "null" then
      put "null" into tNode["type"]
      put empty into tNode["value"]
      add 4 to sJPos
   else
      put "number" into tNode["type"]
      put xtaJNumber() into tNode["value"]
   end if
   put sJPos - 1 into tNode["to"]
   return tNode
end xtaJValue

private function xtaJObject
   local tNode, tName, tCount, tC, tChild
   put "object" into tNode["type"]
   put sJPos into tNode["from"]
   add 1 to sJDepth
   if sJDepth > kJsonMaxDepth then
      xtaJFail "it nests too deeply"
   end if
   add 1 to sJPos
   put 0 into tCount
   xtaJSkip
   if codeunit sJPos of sJText is "}" then
      add 1 to sJPos
   else
      repeat forever
         xtaJSkip
         if sJPos > sJLen or codeunit sJPos of sJText is not quote then
            xtaJFail "a member name must be a string"
         end if
         put xtaJStringBody() into tName
         xtaJSkip
         if sJPos > sJLen or codeunit sJPos of sJText is not ":" then
            xtaJFail "a colon is missing after a member name"
         end if
         add 1 to sJPos
         put xtaJValue() into tChild
         add 1 to tCount
         put tName into tNode["names"][tCount]
         put tChild into tNode["members"][tName]
         xtaJSkip
         if sJPos > sJLen then
            xtaJFail "an object is not closed"
         end if
         put codeunit sJPos of sJText into tC
         add 1 to sJPos
         if tC is "}" then
            exit repeat
         end if
         if tC is not comma then
            xtaJFail "a comma or a closing brace is missing"
         end if
      end repeat
   end if
   put tCount into tNode["count"]
   put sJPos - 1 into tNode["to"]
   subtract 1 from sJDepth
   return tNode
end xtaJObject

private function xtaJArray
   local tNode, tCount, tC, tChild
   put "array" into tNode["type"]
   put sJPos into tNode["from"]
   add 1 to sJDepth
   if sJDepth > kJsonMaxDepth then
      xtaJFail "it nests too deeply"
   end if
   add 1 to sJPos
   put 0 into tCount
   xtaJSkip
   if codeunit sJPos of sJText is "]" then
      add 1 to sJPos
   else
      repeat forever
         put xtaJValue() into tChild
         add 1 to tCount
         put tChild into tNode["items"][tCount]
         xtaJSkip
         if sJPos > sJLen then
            xtaJFail "an array is not closed"
         end if
         put codeunit sJPos of sJText into tC
         add 1 to sJPos
         if tC is "]" then
            exit repeat
         end if
         if tC is not comma then
            xtaJFail "a comma or a closing bracket is missing"
         end if
      end repeat
   end if
   put tCount into tNode["count"]
   put sJPos - 1 into tNode["to"]
   subtract 1 from sJDepth
   return tNode
end xtaJArray

-- The text of the string that starts at sJPos (its opening quote), with its
-- escapes undone; sJPos ends after the closing quote.
private function xtaJStringBody
   local tOut, tQuote, tC, tCode, tLow
   add 1 to sJPos
   put empty into tOut
   repeat forever
      put xtaFindFrom(quote, sJText, sJPos) into tQuote
      if tQuote is 0 then
         xtaJFail "a string is not closed"
      end if
      if sJNextBackslash is not 0 and sJNextBackslash < sJPos then
         put xtaFindFrom(numToChar(92), sJText, sJPos) into sJNextBackslash
      end if
      if sJNextBackslash is 0 or sJNextBackslash > tQuote then
         if tQuote > sJPos then
            put codeunit sJPos to tQuote - 1 of sJText after tOut
         end if
         put tQuote + 1 into sJPos
         return tOut
      end if
      if sJNextBackslash > sJPos then
         put codeunit sJPos to sJNextBackslash - 1 of sJText after tOut
      end if
      put codeunit sJNextBackslash + 1 of sJText into tC
      put sJNextBackslash + 2 into sJPos
      switch tC
         case quote
         case "/"
            put tC after tOut
            break
         case numToChar(92)
            put numToChar(92) after tOut
            break
         case "n"
            put numToChar(10) after tOut
            break
         case "r"
            put numToChar(13) after tOut
            break
         case "t"
            put numToChar(9) after tOut
            break
         case "b"
            put numToChar(8) after tOut
            break
         case "f"
            put numToChar(12) after tOut
            break
         case "u"
            put xtaJHex4(sJPos) into tCode
            add 4 to sJPos
            if tCode >= 55296 and tCode <= 56319 then
               -- A high surrogate: with the low one after it, the two make
               -- one code point; alone, it stands for nothing printable.
               put empty into tLow
               if codeunit sJPos to sJPos + 1 of sJText is (numToChar(92) & "u") then
                  put xtaJHex4(sJPos + 2) into tLow
               end if
               if tLow is an integer and tLow >= 56320 and tLow <= 57343 then
                  put 65536 + (tCode - 55296) * 1024 + (tLow - 56320) into tCode
                  add 6 to sJPos
               else
                  put 65533 into tCode
               end if
            else if tCode >= 56320 and tCode <= 57343 then
               put 65533 into tCode
            end if
            put numToCodepoint(tCode) after tOut
            break
         default
            xtaJFail "a string has an unknown escape"
            break
      end switch
   end repeat
end xtaJStringBody

private function xtaJHex4 pAt
   local tHex
   put codeunit pAt to pAt + 3 of sJText into tHex
   if not matchText(tHex, "^[0-9A-Fa-f]{4}$") then
      xtaJFail "a \u escape needs four hexadecimal digits"
   end if
   return baseConvert(tHex, 16, 10)
end xtaJHex4

private function xtaJNumber
   local tStart, tC, tText
   put sJPos into tStart
   repeat while sJPos <= sJLen
      put codeunit sJPos of sJText into tC
      if tC is empty or tC is not in "0123456789+-.eE" then
         exit repeat
      end if
      add 1 to sJPos
   end repeat
   if sJPos > tStart then
      put codeunit tStart to sJPos - 1 of sJText into tText
   end if
   if not matchText(tText, "^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$") then
      xtaJFail "a value is not a string, number, object, array, true, false or null"
   end if
   return tText
end xtaJNumber

-- Where pNeedle first occurs in pText at or after code unit pStart, or 0.
-- On the 0.2.5-rc.1 engine (Linux), codeunitOffset() answers the position
-- from the start of the text even when it is given a number of code units to
-- skip, unlike offset(), which answers it from the skipped part. Both
-- readings are checked here so that the answer is right either way: a match
-- at a position at or after pStart is the first such match only if the
-- engine counts from the start.
private function xtaFindFrom pNeedle, pText, pStart
   local tFound
   put codeunitOffset(pNeedle, pText, pStart - 1) into tFound
   if tFound is 0 then
      return 0
   end if
   if tFound >= pStart and codeunit tFound to tFound + the number of codeunits of pNeedle - 1 of pText is pNeedle then
      return tFound
   end if
   return tFound + pStart - 1
end xtaFindFrom

-- "missing" for a value that is not there, else its type.
function xtaJsonType pNode
   if pNode is not an array then
      return "missing"
   end if
   if pNode["type"] is empty then
      return "missing"
   end if
   return pNode["type"]
end xtaJsonType

function xtaJsonCount pNode
   if pNode is not an array then
      return 0
   end if
   if pNode["type"] is "object" or pNode["type"] is "array" then
      return pNode["count"]
   end if
   return 0
end xtaJsonCount

-- Item pIndex (1 to count) of an array.
function xtaJsonItem pNode, pIndex
   local tEmpty
   if xtaJsonType(pNode) is not "array" then
      return tEmpty
   end if
   if pIndex is not an integer then
      return tEmpty
   end if
   return pNode["items"][pIndex]
end xtaJsonItem

function xtaJsonMember pNode, pName
   local tEmpty
   if xtaJsonType(pNode) is not "object" then
      return tEmpty
   end if
   return pNode["members"][pName]
end xtaJsonMember

-- A string or number as text, a boolean as "true" or "false"; empty for
-- null, an object, an array or a missing value.
function xtaJsonText pNode
   local tType
   put xtaJsonType(pNode) into tType
   if tType is "string" or tType is "number" or tType is "boolean" then
      return pNode["value"]
   end if
   return empty
end xtaJsonText

-- The value at a "/"-separated path of member names and item numbers, for
-- example "choices/1/message/content".
function xtaJsonGet pNode, pPath
   local tNode, tStep, tEmpty
   put pNode into tNode
   set the itemDelimiter to "/"
   repeat for each item tStep in pPath
      if tStep is empty then
         next repeat
      end if
      if xtaJsonType(tNode) is "array" then
         put xtaJsonItem(tNode, tStep) into tNode
      else if xtaJsonType(tNode) is "object" then
         put xtaJsonMember(tNode, tStep) into tNode
      else
         return tEmpty
      end if
   end repeat
   return tNode
end xtaJsonGet

-- The text a parsed value came from, exactly as it was in pJSON.
function xtaJsonRaw pJSON, pNode
   if xtaJsonType(pNode) is "missing" then
      return empty
   end if
   return codeunit pNode["from"] to pNode["to"] of pJSON
end xtaJsonRaw

--------------------------------------------------------------------------------
-- Providers

function xtaProviders
   return "anthropic,openai"
end xtaProviders

function xtaProviderName pProvider
   switch pProvider
      case "anthropic"
         return "Anthropic"
      case "openai"
         return "OpenAI (or compatible)"
   end switch
   return pProvider
end xtaProviderName

function xtaDefaultBaseUrl pProvider
   switch pProvider
      case "anthropic"
         return kAnthropicBaseUrl
      case "openai"
         return kOpenAIBaseUrl
   end switch
   return empty
end xtaDefaultBaseUrl

private function xtaBase pProvider, pBaseUrl
   local tBase
   put word 1 to -1 of pBaseUrl into tBase
   if tBase is empty then
      put xtaDefaultBaseUrl(pProvider) into tBase
   end if
   repeat while the last char of tBase is "/"
      delete the last char of tBase
   end repeat
   return tBase
end xtaBase

function xtaRequestUrl pProvider, pBaseUrl
   switch pProvider
      case "anthropic"
         return xtaBase(pProvider, pBaseUrl) & "/v1/messages"
      case "openai"
         return xtaBase(pProvider, pBaseUrl) & "/chat/completions"
   end switch
   return empty
end xtaRequestUrl

function xtaModelsUrl pProvider, pBaseUrl
   switch pProvider
      case "anthropic"
         return xtaBase(pProvider, pBaseUrl) & "/v1/models?limit=100"
      case "openai"
         return xtaBase(pProvider, pBaseUrl) & "/models"
   end switch
   return empty
end xtaModelsUrl

-- The header lines of a request, for the httpHeaders. A key with a line
-- break in it is refused: it would add header lines of its own.
function xtaRequestHeaders pProvider, pKey
   local tKey, tHeaders
   put word 1 to -1 of pKey into tKey
   if tKey contains numToChar(10) or tKey contains numToChar(13) then
      throw "xTalk Assistant: the API key has a line break in it."
   end if
   put "Content-Type: application/json" & return & "Accept: application/json" into tHeaders
   -- libURL can stall on a kept-alive connection (oxtbeyondupdater.livecodescript).
   -- OXT-Beyond: in the web IDE the browser makes the request, and a page
   -- may not set Connection (the browser refuses it, and says so in its
   -- console), so it is left out there
   if the platform is not "HTML5" then
      put return & "Connection: close" after tHeaders
   end if
   switch pProvider
      case "anthropic"
         put return & "anthropic-version:" && kAnthropicVersion after tHeaders
         -- OXT-Beyond: in the web IDE the request comes from a web page,
         -- which Anthropic's API answers only when it says it means to
         -- (without this the browser is given no CORS header and blocks
         -- the answer). The key is the user's own, typed into this page.
         if the platform is "HTML5" then
            put return & "anthropic-dangerous-direct-browser-access: true" after tHeaders
         end if
         if tKey is not empty then
            put return & "x-api-key:" && tKey after tHeaders
         end if
         break
      case "openai"
         if tKey is not empty then
            put return & "Authorization: Bearer" && tKey after tHeaders
         end if
         break
   end switch
   return tHeaders
end xtaRequestHeaders

-- The JSON of a request. pTurns is the conversation (keys 1 to N, "role" and
-- "text"); turns with no text are left out, as both APIs refuse them.
-- pSystem is what the model is told first: a text, or its parts (keys 1 to
-- N, each with "text", and "cache" true for a part that is the same in
-- every request, such as the guide). Anthropic gets the parts as the
-- blocks of its "system", with a cache breakpoint after each part marked
-- "cache": it then bills that much of the prompt at a fraction of the
-- price while it is in its cache (a part too short to be cached is sent and
-- billed as usual). OpenAI caches the start of a long prompt by itself, so
-- it gets the parts joined, in their order. A text, or one part not marked
-- "cache", goes as a plain string, as it always has.
-- pTools are the tools the model may ask for: keys 1 to N, each with
-- "name", "description" and "schema" (the JSON Schema of its input, a JSON
-- object). An answer that asked for tools goes with the results of the turn
-- after it, a call with no result as one that was not run, since both APIs
-- refuse a call without its result. Without pTools, the calls and results
-- are left out, as a server that has no tools refuses them.
function xtaRequestBody pProvider, pModel, pSystem, pTurns, pMaxTokens, pTools, pTokensName
   local tMessages, tIndex, tRole, tMax, tBody, tParts, tBlocks, tWithTools, tResults
   if word 1 to -1 of pModel is empty then
      throw "xTalk Assistant: no model is chosen."
   end if
   put xtaSystemParts(pSystem) into tParts
   put (the number of elements of pTools > 0) into tWithTools
   put empty into tMessages
   if pProvider is "openai" and the number of elements of tParts > 0 then
      put "{" & xtaJsonPair("role", xtaJsonString("system")) & comma & \
            xtaJsonPair("content", xtaJsonString(xtaSystemText(tParts))) & "}" into tMessages
   end if
   repeat with tIndex = 1 to the number of elements of pTurns
      -- Results go with the calls of the answer before them (below)
      if pTurns[tIndex]["kind"] is "tools" then
         next repeat
      end if
      if tWithTools and pTurns[tIndex]["role"] is "assistant" and the number of elements of pTurns[tIndex]["calls"] > 0 then
         put empty into tResults
         if pTurns[tIndex + 1]["kind"] is "tools" then
            put pTurns[tIndex + 1]["results"] into tResults
         end if
         if tMessages is not empty then
            put comma after tMessages
         end if
         put xtaCallMessages(pProvider, pTurns[tIndex], tResults, tIndex) after tMessages
         next repeat
      end if
      if pTurns[tIndex]["text"] is empty then
         next repeat
      end if
      put pTurns[tIndex]["role"] into tRole
      if tRole is not "assistant" then
         put "user" into tRole
      end if
      if tMessages is not empty then
         put comma after tMessages
      end if
      put "{" & xtaJsonPair("role", xtaJsonString(tRole)) & comma & \
            xtaJsonPair("content", xtaJsonString(pTurns[tIndex]["text"])) & "}" after tMessages
   end repeat

   put "{" & xtaJsonPair("model", xtaJsonString(word 1 to -1 of pModel)) into tBody
   if pProvider is "anthropic" then
      put xtaMaxTokens(pProvider, pMaxTokens) into tMax
      put comma & xtaJsonPair("max_tokens", tMax + 0) after tBody
      if the number of elements of tParts is 1 and tParts[1]["cache"] is not true then
         put comma & xtaJsonPair("system", xtaJsonString(tParts[1]["text"])) after tBody
      else if the number of elements of tParts > 0 then
         repeat with tIndex = 1 to the number of elements of tParts
            if tBlocks is not empty then
               put comma after tBlocks
            end if
            put "{" & xtaJsonPair("type", xtaJsonString("text")) & comma & \
                  xtaJsonPair("text", xtaJsonString(tParts[tIndex]["text"])) after tBlocks
            if tParts[tIndex]["cache"] is true then
               put comma & xtaJsonPair("cache_control", "{" & xtaJsonPair("type", xtaJsonString("ephemeral")) & "}") after tBlocks
            end if
            put "}" after tBlocks
         end repeat
         put comma & xtaJsonPair("system", "[" & tBlocks & "]") after tBody
      end if
   end if
   -- OpenAI needs no limit; one the user set goes as pTokensName
   if pProvider is "openai" and pMaxTokens is an integer and pMaxTokens > 0 then
      if pTokensName is empty then
         put "max_completion_tokens" into pTokensName
      end if
      put comma & xtaJsonPair(pTokensName, pMaxTokens + 0) after tBody
   end if
   if tWithTools then
      put comma & xtaJsonPair("tools", xtaToolsJson(pProvider, pTools)) after tBody
   end if
   put comma & xtaJsonPair("messages", "[" & tMessages & "]") & "}" after tBody
   return tBody
end xtaRequestBody

-- The longest answer a request asks for, in tokens: pMaxTokens when the
-- user set it; otherwise kDefaultMaxTokens for Anthropic, which requires
-- one, and empty for OpenAI, whose model then decides
function xtaMaxTokens pProvider, pMaxTokens
   if pMaxTokens is an integer and pMaxTokens > 0 then
      return pMaxTokens
   end if
   if pProvider is "anthropic" then
      return kDefaultMaxTokens
   end if
   return empty
end xtaMaxTokens

-- The tools as the provider takes them
private function xtaToolsJson pProvider, pTools
   local tIndex, tJson, tName, tSchema, tDoc, tError
   repeat with tIndex = 1 to the number of elements of pTools
      put pTools[tIndex]["name"] into tName
      put pTools[tIndex]["schema"] into tSchema
      try
         put xtaJsonParse(tSchema) into tDoc
      catch tError
         put empty into tDoc
      end try
      if xtaJsonType(tDoc) is not "object" then
         throw "xTalk Assistant: the tool" && tName && "has no schema."
      end if
      if tJson is not empty then
         put comma after tJson
      end if
      if pProvider is "anthropic" then
         put "{" & xtaJsonPair("name", xtaJsonString(tName)) & comma & \
               xtaJsonPair("description", xtaJsonString(pTools[tIndex]["description"])) & comma & \
               xtaJsonPair("input_schema", tSchema) & "}" after tJson
      else
         put "{" & xtaJsonPair("type", xtaJsonString("function")) & comma & xtaJsonPair("function", "{" & \
               xtaJsonPair("name", xtaJsonString(tName)) & comma & \
               xtaJsonPair("description", xtaJsonString(pTools[tIndex]["description"])) & comma & \
               xtaJsonPair("parameters", tSchema) & "}") & "}" after tJson
      end if
   end repeat
   return "[" & tJson & "]"
end xtaToolsJson

-- The messages of an answer that asked for tools (pTurn, turn pTurnIndex of
-- the conversation) and of their results (pResults, as the turn after it
-- has them): for Anthropic, the answer's text and tool_use blocks, then a
-- user message of tool_result blocks; for OpenAI, the answer with its
-- tool_calls, then a "tool" message for each. A result with a picture
-- ("image", base64, and "imageType", its media type) takes it along: in
-- its tool_result for Anthropic, as a text and an image block; for
-- OpenAI, whose tool messages take text alone, in a user message of the
-- pictures after the tool messages.
private function xtaCallMessages pProvider, pTurn, pResults, pTurnIndex
   local tCall, tId, tName, tInput, tDoc, tError, tText, tIsError, tCalls, tAnswers, tContent
   local tImage, tImageType, tPictures
   repeat with tCall = 1 to the number of elements of pTurn["calls"]
      put xtaCallId(pTurn["calls"][tCall]["id"], pTurnIndex, tCall) into tId
      -- Both APIs take only names of letters, digits, _ and -
      put pTurn["calls"][tCall]["name"] into tName
      if not matchText(tName, "^[A-Za-z0-9_-]{1,64}$") then
         put "unknown_tool" into tName
      end if
      put pTurn["calls"][tCall]["input"] into tInput
      try
         put xtaJsonParse(tInput) into tDoc
      catch tError
         put empty into tDoc
      end try
      if xtaJsonType(tDoc) is not "object" then
         put "{}" into tInput
      end if
      put empty into tImage
      if pResults[tCall] is an array then
         put pResults[tCall]["text"] into tText
         put (pResults[tCall]["error"] is true) into tIsError
         if tText is empty then
            put "(nothing)" into tText
         end if
         put pResults[tCall]["image"] into tImage
         put pResults[tCall]["imageType"] into tImageType
         if tImageType is empty then
            put "image/png" into tImageType
         end if
      else
         put "Not run." into tText
         put true into tIsError
      end if
      if tCalls is not empty then
         put comma after tCalls
         put comma after tAnswers
      end if
      if pProvider is "anthropic" then
         put "{" & xtaJsonPair("type", xtaJsonString("tool_use")) & comma & xtaJsonPair("id", xtaJsonString(tId)) & comma & \
               xtaJsonPair("name", xtaJsonString(tName)) & comma & xtaJsonPair("input", tInput) & "}" after tCalls
         if tImage is empty then
            put "{" & xtaJsonPair("type", xtaJsonString("tool_result")) & comma & xtaJsonPair("tool_use_id", xtaJsonString(tId)) & comma & \
                  xtaJsonPair("content", xtaJsonString(tText)) after tAnswers
         else
            put "{" & xtaJsonPair("type", xtaJsonString("tool_result")) & comma & xtaJsonPair("tool_use_id", xtaJsonString(tId)) & comma & \
                  xtaJsonPair("content", "[{" & xtaJsonPair("type", xtaJsonString("text")) & comma & xtaJsonPair("text", xtaJsonString(tText)) & "}," & \
                  "{" & xtaJsonPair("type", xtaJsonString("image")) & comma & xtaJsonPair("source", "{" & \
                  xtaJsonPair("type", xtaJsonString("base64")) & comma & xtaJsonPair("media_type", xtaJsonString(tImageType)) & comma & \
                  xtaJsonPair("data", xtaJsonString(tImage)) & "}") & "}]") after tAnswers
         end if
         if tIsError then
            put comma & xtaJsonPair("is_error", "true") after tAnswers
         end if
         put "}" after tAnswers
      else
         put "{" & xtaJsonPair("id", xtaJsonString(tId)) & comma & xtaJsonPair("type", xtaJsonString("function")) & comma & \
               xtaJsonPair("function", "{" & xtaJsonPair("name", xtaJsonString(tName)) & comma & \
               xtaJsonPair("arguments", xtaJsonString(tInput)) & "}") & "}" after tCalls
         if tIsError then
            put "Error:" && tText into tText
         end if
         put "{" & xtaJsonPair("role", xtaJsonString("tool")) & comma & xtaJsonPair("tool_call_id", xtaJsonString(tId)) & comma & \
               xtaJsonPair("content", xtaJsonString(tText)) & "}" after tAnswers
         if tImage is not empty then
            put comma & "{" & xtaJsonPair("type", xtaJsonString("image_url")) & comma & xtaJsonPair("image_url", "{" & \
                  xtaJsonPair("url", xtaJsonString("data:" & tImageType & ";base64," & tImage)) & "}") & "}" after tPictures
         end if
      end if
   end repeat
   if pProvider is "anthropic" then
      -- Anthropic refuses an empty text block
      if pTurn["text"] is not empty then
         put "{" & xtaJsonPair("type", xtaJsonString("text")) & comma & xtaJsonPair("text", xtaJsonString(pTurn["text"])) & "}," into tContent
      end if
      return "{" & xtaJsonPair("role", xtaJsonString("assistant")) & comma & xtaJsonPair("content", "[" & tContent & tCalls & "]") & "}," & \
            "{" & xtaJsonPair("role", xtaJsonString("user")) & comma & xtaJsonPair("content", "[" & tAnswers & "]") & "}"
   end if
   if tPictures is not empty then
      put ",{" & xtaJsonPair("role", xtaJsonString("user")) & comma & xtaJsonPair("content", "[{" & \
            xtaJsonPair("type", xtaJsonString("text")) & comma & xtaJsonPair("text", xtaJsonString("The pictures the tools took, in order:")) & "}" & \
            tPictures & "]") & "}" into tPictures
   end if
   -- An empty string rather than null, which some servers with OpenAI's API
   -- refuse
   return "{" & xtaJsonPair("role", xtaJsonString("assistant")) & comma & xtaJsonPair("content", xtaJsonString(pTurn["text"])) & comma & \
         xtaJsonPair("tool_calls", "[" & tCalls & "]") & "}," & tAnswers & tPictures
end xtaCallMessages

-- The id of a call as it is sent: the model's own, or, when that is not one
-- both APIs take (a local server may give none), one made from where the
-- call is in the conversation, the same for the call and its result
private function xtaCallId pId, pTurnIndex, pCall
   if matchText(pId, "^[A-Za-z0-9_-]{1,64}$") then
      return pId
   end if
   return "call_" & pTurnIndex & "_" & pCall
end xtaCallId

-- The parts of a system prompt (see xtaRequestBody), numbered from 1,
-- without the empty ones.
private function xtaSystemParts pSystem
   local tParts, tIndex, tCount
   put 0 into tCount
   if pSystem is an array then
      repeat with tIndex = 1 to the number of elements of pSystem
         if pSystem[tIndex]["text"] is not empty then
            add 1 to tCount
            put pSystem[tIndex]["text"] into tParts[tCount]["text"]
            put (pSystem[tIndex]["cache"] is true) into tParts[tCount]["cache"]
         end if
      end repeat
   else if pSystem is not empty then
      put pSystem into tParts[1]["text"]
      put false into tParts[1]["cache"]
   end if
   return tParts
end xtaSystemParts

-- The parts of a system prompt as one text, an empty line between them
private function xtaSystemText pParts
   local tText, tIndex
   repeat with tIndex = 1 to the number of elements of pParts
      if tText is not empty then
         put return & return after tText
      end if
      put pParts[tIndex]["text"] after tText
   end repeat
   return tText
end xtaSystemText

-- What an answer says. pStatus is the HTTP status (200 for success), or
-- empty when no answer came; pBody is the answer's text. Returns an array:
--    ok            true when the model answered
--    text          what it said (all its text parts, in order)
--    stop          why it stopped (the provider's word, such as "end_turn",
--                  "stop", "max_tokens" or "length"; "refusal" when
--                  Anthropic's safety check stopped it)
--    category      for a refusal, the kind of request the check took it
--                  for, when Anthropic says
--    inputTokens, outputTokens   what the request cost, when the answer says
--    cachedTokens  how much of the input was read from the provider's cache
--                  (Anthropic counts it apart from inputTokens, OpenAI in it)
--    calls         the tools it asked for, keys 1 to N, each with "id",
--                  "name" and "input" (the JSON object of the arguments)
--    status        pStatus
--    error         why there is no answer, in words for the user
function xtaParseReply pProvider, pStatus, pBody
   local tReply, tDoc, tError, tParts, tIndex, tPart, tText, tCalls, tCount, tInput
   put false into tReply["ok"]
   put pStatus into tReply["status"]
   put 0 into tCount
   try
      put xtaJsonParse(pBody) into tDoc
   catch tError
      put empty into tDoc
   end try

   put xtaApiError(pProvider, pStatus, pBody, tDoc) into tError
   if tError is not empty then
      put tError into tReply["error"]
      return tReply
   end if

   switch pProvider
      case "anthropic"
         put xtaJsonMember(tDoc, "content") into tParts
         repeat with tIndex = 1 to xtaJsonCount(tParts)
            put xtaJsonItem(tParts, tIndex) into tPart
            if xtaJsonText(xtaJsonMember(tPart, "type")) is "text" then
               put xtaJsonText(xtaJsonMember(tPart, "text")) after tText
            else if xtaJsonText(xtaJsonMember(tPart, "type")) is "tool_use" then
               add 1 to tCount
               put xtaJsonText(xtaJsonMember(tPart, "id")) into tCalls[tCount]["id"]
               put xtaJsonText(xtaJsonMember(tPart, "name")) into tCalls[tCount]["name"]
               put xtaCallInput(pBody, xtaJsonMember(tPart, "input")) into tCalls[tCount]["input"]
            end if
         end repeat
         put xtaJsonText(xtaJsonMember(tDoc, "stop_reason")) into tReply["stop"]
         put xtaJsonText(xtaJsonGet(tDoc, "stop_details/category")) into tReply["category"]
         put xtaJsonText(xtaJsonGet(tDoc, "usage/input_tokens")) into tReply["inputTokens"]
         put xtaJsonText(xtaJsonGet(tDoc, "usage/output_tokens")) into tReply["outputTokens"]
         put xtaJsonText(xtaJsonGet(tDoc, "usage/cache_read_input_tokens")) into tReply["cachedTokens"]
         if xtaJsonType(tParts) is not "array" then
            put "The answer had no content." into tReply["error"]
            return tReply
         end if
         break
      case "openai"
         put xtaJsonGet(tDoc, "choices/1/message/content") into tPart
         if xtaJsonType(xtaJsonGet(tDoc, "choices/1/message")) is not "object" then
            put "The answer had no message." into tReply["error"]
            return tReply
         end if
         put xtaJsonText(tPart) into tText
         put xtaJsonGet(tDoc, "choices/1/message/tool_calls") into tParts
         repeat with tIndex = 1 to xtaJsonCount(tParts)
            put xtaJsonItem(tParts, tIndex) into tPart
            if xtaJsonText(xtaJsonGet(tPart, "function/name")) is empty then
               next repeat
            end if
            add 1 to tCount
            put xtaJsonText(xtaJsonMember(tPart, "id")) into tCalls[tCount]["id"]
            put xtaJsonText(xtaJsonGet(tPart, "function/name")) into tCalls[tCount]["name"]
            -- The arguments are a JSON text in a string; some servers send
            -- the object itself
            put xtaJsonGet(tPart, "function/arguments") into tInput
            if xtaJsonType(tInput) is "string" then
               put xtaJsonText(tInput) into tCalls[tCount]["input"]
            else
               put xtaCallInput(pBody, tInput) into tCalls[tCount]["input"]
            end if
         end repeat
         put xtaJsonText(xtaJsonGet(tDoc, "choices/1/finish_reason")) into tReply["stop"]
         put xtaJsonText(xtaJsonGet(tDoc, "usage/prompt_tokens")) into tReply["inputTokens"]
         put xtaJsonText(xtaJsonGet(tDoc, "usage/completion_tokens")) into tReply["outputTokens"]
         put xtaJsonText(xtaJsonGet(tDoc, "usage/prompt_tokens_details/cached_tokens")) into tReply["cachedTokens"]
         break
      default
         put "Unknown provider" && quote & pProvider & quote & "." into tReply["error"]
         return tReply
   end switch

   put tText into tReply["text"]
   put tCalls into tReply["calls"]
   put true into tReply["ok"]
   return tReply
end xtaParseReply

-- The arguments of a call as JSON text, from their parsed value in pBody:
-- an object exactly as it was sent, anything else as no arguments
private function xtaCallInput pBody, pNode
   if xtaJsonType(pNode) is "object" then
      return xtaJsonRaw(pBody, pNode)
   end if
   return "{}"
end xtaCallInput

-- Why an answer is not a success, in words for the user, or empty when it
-- is one. The providers put their reason in error/message.
private function xtaApiError pProvider, pStatus, pBody, pDoc
   local tMessage, tError
   if pStatus is empty then
      return "No answer came from the server."
   end if
   put xtaJsonText(xtaJsonGet(pDoc, "error/message")) into tMessage
   if tMessage is empty then
      -- Some OpenAI-compatible servers send the error as a plain string.
      put xtaJsonText(xtaJsonMember(pDoc, "error")) into tMessage
   end if
   if pStatus is 200 and tMessage is empty and xtaJsonType(pDoc) is "object" then
      return empty
   end if
   if pStatus is 200 and tMessage is empty then
      return "The answer was not JSON:" && xtaFirstLine(pBody)
   end if

   switch pStatus
      case 401
         put "The provider did not accept the API key." into tError
         break
      case 403
         put "The provider refused the request (403)." into tError
         break
      case 404
         put "The provider has no such address or model (404). Check the base URL and the model." into tError
         break
      case 429
         put "The provider says there were too many requests, or the account has run out of credit (429)." into tError
         break
      case 529
         put "The provider is overloaded (529). Try again in a moment." into tError
         break
      default
         if pStatus is 200 then
            put "The provider answered with an error." into tError
         else
            put "The provider answered with an error (" & pStatus & ")." into tError
         end if
         break
   end switch
   if tMessage is not empty then
      put return & tMessage after tError
   else if pBody is not empty then
      put return & xtaFirstLine(pBody) after tError
   end if
   return tError
end xtaApiError

private function xtaFirstLine pText
   local tLine
   put line 1 of pText into tLine
   if the number of chars of tLine > 200 then
      put char 1 to 200 of tLine & "..." into tLine
   end if
   return tLine
end xtaFirstLine

-- The model names in an answer to xtaModelsUrl: an array with "models",
-- one per line in the provider's order, and "default", the one to use when
-- the user has chosen none (xtaDefaultModel); or with "error" when there
-- are none.
function xtaParseModels pProvider, pStatus, pBody
   local tDoc, tError, tData, tIndex, tIds, tId, tCreated, tResult
   try
      put xtaJsonParse(pBody) into tDoc
   catch tError
      put empty into tDoc
   end try
   put xtaApiError(pProvider, pStatus, pBody, tDoc) into tError
   if tError is not empty then
      put tError into tResult["error"]
      return tResult
   end if
   put xtaJsonMember(tDoc, "data") into tData
   repeat with tIndex = 1 to xtaJsonCount(tData)
      put xtaJsonText(xtaJsonGet(tData, tIndex & "/id")) into tId
      if tId is empty or return is in tId then
         next repeat
      end if
      if tIds is not empty then
         put return after tIds
      end if
      put tId after tIds
      -- OpenAI's list gives when each model was made, in seconds
      put xtaJsonText(xtaJsonGet(tData, tIndex & "/created")) into tCreated[tId]
   end repeat
   if tIds is empty then
      put "The provider listed no models." into tResult["error"]
      return tResult
   end if
   put tIds into tResult["models"]
   put xtaDefaultModel(pProvider, tIds, tCreated) into tResult["default"]
   return tResult
end xtaParseModels

-- The model to use when the user has chosen none, from the provider's list
-- (pIds, one per line in the provider's order; pCreated, when the provider
-- gives it, when each was made, by name). Families before names, which
-- change: Anthropic lists its newest models first, and the newest Sonnet
-- writes code well for less than Opus costs. OpenAI's list is in no order
-- and mixes in models that do not chat (embeddings, speech, images), so
-- the first of its suggested models it lists (xtaSuggestedModels), else
-- the newest whose name is just "gpt-" and a version (gpt-4o, gpt-5.1).
-- Otherwise, and for a local server, the first one listed.
function xtaDefaultModel pProvider, pIds, pCreated
   local tId, tBest, tBestCreated
   switch pProvider
      case "anthropic"
         repeat for each line tId in pIds
            if tId contains "sonnet" then
               return tId
            end if
         end repeat
         break
      case "openai"
         repeat for each line tId in xtaSuggestedModels(pProvider)
            if tId is among the lines of pIds then
               return tId
            end if
         end repeat
         repeat for each line tId in pIds
            if not matchText(tId, "^gpt-[0-9]+(\.[0-9]+)?o?$") then
               next repeat
            end if
            if tBest is empty then
               put tId into tBest
               put pCreated[tId] into tBestCreated
            else if pCreated[tId] is a number and (tBestCreated is not a number or pCreated[tId] > tBestCreated) then
               put tId into tBest
               put pCreated[tId] into tBestCreated
            end if
         end repeat
         if tBest is not empty then
            return tBest
         end if
         break
   end switch
   return line 1 of pIds
end xtaDefaultModel

-- The provider's current recommendations (October 2026), one per line, the
-- one to begin with first: Anthropic's Sonnet for its balance of speed,
-- cost and code, then Opus, Haiku and Fable; OpenAI's balanced model, then
-- its flagship and its smallest. The model menu offers them before the
-- provider's list has come; they are not checked against the account.
function xtaSuggestedModels pProvider
   switch pProvider
      case "anthropic"
         return "claude-sonnet-5-5" & return & "claude-opus-5-5" & return & \
               "claude-haiku-5-5" & return & "claude-fable-5-1"
      case "openai"
         return "gpt-6.1-sol" & return & "gpt-6-astra" & return & "gpt-6-luna"
   end switch
   return empty
end xtaSuggestedModels

-- The lines of the model menu: the suggested models the provider listed
-- (all of them before its list has come, when pIds is empty), then the
-- rest of its list in alphabetical order. For a local server (none of the
-- suggestions listed) that is its list, sorted.
function xtaModelMenu pProvider, pIds
   local tMenu, tId, tRest
   if pIds is empty then
      return xtaSuggestedModels(pProvider)
   end if
   repeat for each line tId in xtaSuggestedModels(pProvider)
      if tId is among the lines of pIds then
         put tId & return after tMenu
      end if
   end repeat
   repeat for each line tId in pIds
      if tId is not empty and tId is not among the lines of tMenu then
         put tId & return after tRest
      end if
   end repeat
   sort lines of tRest
   put tRest after tMenu
   delete the last char of tMenu
   return tMenu
end xtaModelMenu

--------------------------------------------------------------------------------
-- HTTP
--
-- One request at a time, through libURL (the engine's "post" and "get"),
-- which waits for the answer while the IDE keeps handling events. The
-- httpHeaders and the socketTimeoutInterval are global, so both are set
-- only for the request and put back afterwards, the key never staying in
-- the httpHeaders. Returns an array: status (the HTTP status, or empty when
-- no answer came), body (the answer as text) and error (why there was no
-- answer).

function xtaHttpPost pUrl, pHeaders, pBody, pTimeout
   return xtaHttp("post", pUrl, pHeaders, pBody, pTimeout)
end xtaHttpPost

function xtaHttpGet pUrl, pHeaders, pTimeout
   return xtaHttp("get", pUrl, pHeaders, empty, pTimeout)
end xtaHttpGet

-- pTimeout: how many seconds the request may go without data, or empty
-- for kRequestTimeoutMilliseconds
private function xtaHttp pMethod, pUrl, pHeaders, pBody, pTimeout
   local tOldHeaders, tOldTimeout, tData, tResult, tError, tAnswer
   put the httpHeaders into tOldHeaders
   put the socketTimeoutInterval into tOldTimeout
   set the httpHeaders to pHeaders
   if pTimeout is an integer and pTimeout > 0 then
      set the socketTimeoutInterval to pTimeout * 1000
   else
      set the socketTimeoutInterval to kRequestTimeoutMilliseconds
   end if
   try
      if pMethod is "post" then
         post textEncode(pBody, "UTF-8") to url pUrl
      else
         get url pUrl
      end if
      put it into tData
      put the result into tResult
   catch tError
      put "error" && tError into tResult
   end try
   set the httpHeaders to tOldHeaders
   set the socketTimeoutInterval to tOldTimeout

   -- libURL leaves the result empty for a success; an HTTP error answer
   -- gives "error <status> <reason>" with the answer's body in "it".
   -- Anything else means no answer came.
   if tResult is empty then
      put 200 into tAnswer["status"]
   else if word 1 of tResult is "error" and word 2 of tResult is an integer \
         and the number of chars of word 2 of tResult is 3 then
      put word 2 of tResult into tAnswer["status"]
   else
      put empty into tAnswer["status"]
      if tResult contains "timeout" then
         put "The server did not answer in time." into tAnswer["error"]
      else
         put "The server could not be reached:" && line 1 of tResult into tAnswer["error"]
      end if
      return tAnswer
   end if
   try
      put textDecode(tData, "UTF-8") into tAnswer["body"]
   catch tError
      put tData into tAnswer["body"]
   end try
   return tAnswer
end xtaHttp

-- How many seconds a request may go without data: pTimeout when the user
-- set it; otherwise kRequestTimeoutMilliseconds, or longer for a request
-- that gives its answer pMaxTokens of room, since a (non-streamed) answer
-- arrives whole when the model is done (kTokensAnHour), up to an hour
function xtaRequestWait pTimeout, pMaxTokens
   local tWait
   if pTimeout is an integer and pTimeout > 0 then
      return pTimeout
   end if
   put kRequestTimeoutMilliseconds div 1000 into tWait
   if pMaxTokens is an integer and pMaxTokens > 0 then
      put max(tWait, min(3600, (pMaxTokens * 3600 + kTokensAnHour - 1) div kTokensAnHour)) into tWait
   end if
   return tWait
end xtaRequestWait

-- One round trip: sends the conversation and returns what xtaParseReply
-- does. pSettings has "provider", "baseUrl", "key", "model", "maxTokens"
-- and "timeout" (seconds; the last two may be empty); pTools, when given,
-- are the tools the model may ask for (xtaRequestBody).
function xtaAsk pSettings, pSystem, pTurns, pTools
   local tProvider, tHeaders, tBody, tAnswer, tReply, tError, tTokensName
   put pSettings["provider"] into tProvider
   -- OpenAI's own API takes the limit as max_completion_tokens (its newer
   -- models refuse max_tokens); a server of the user's own, as max_tokens
   if tProvider is "openai" and pSettings["baseUrl"] is not empty then
      put "max_tokens" into tTokensName
   end if
   try
      put xtaRequestHeaders(tProvider, pSettings["key"]) into tHeaders
      put xtaRequestBody(tProvider, pSettings["model"], pSystem, pTurns, pSettings["maxTokens"], pTools, tTokensName) into tBody
   catch tError
      put false into tReply["ok"]
      put xtaPlainError(tError) into tReply["error"]
      return tReply
   end try
   put xtaHttpPost(xtaRequestUrl(tProvider, pSettings["baseUrl"]), tHeaders, tBody, \
         xtaRequestWait(pSettings["timeout"], xtaMaxTokens(tProvider, pSettings["maxTokens"]))) into tAnswer
   put empty into tHeaders
   if tAnswer["status"] is empty then
      put false into tReply["ok"]
      put tAnswer["error"] into tReply["error"]
      return tReply
   end if
   return xtaParseReply(tProvider, tAnswer["status"], tAnswer["body"])
end xtaAsk

-- The model names the provider offers, as xtaParseModels returns them.
function xtaListModels pSettings
   local tProvider, tHeaders, tAnswer, tResult, tError, tTimeout
   put pSettings["provider"] into tProvider
   put pSettings["timeout"] into tTimeout
   if not (tTimeout is an integer and tTimeout > 0) then
      put kListTimeoutSeconds into tTimeout
   end if
   try
      put xtaRequestHeaders(tProvider, pSettings["key"]) into tHeaders
   catch tError
      put xtaPlainError(tError) into tResult["error"]
      return tResult
   end try
   -- Anthropic's model list wants the version header too; neither list
   -- needs a body, so the Content-Type line does no harm.
   put xtaHttpGet(xtaModelsUrl(tProvider, pSettings["baseUrl"]), tHeaders, tTimeout) into tAnswer
   put empty into tHeaders
   if tAnswer["status"] is empty then
      put tAnswer["error"] into tResult["error"]
      return tResult
   end if
   return xtaParseModels(tProvider, tAnswer["status"], tAnswer["body"])
end xtaListModels

-- A thrown error as the words after "xTalk Assistant: ", for the user.
function xtaPlainError pError
   local tText
   put line 1 of pError into tText
   if tText begins with "xTalk Assistant: " then
      delete char 1 to the number of chars of "xTalk Assistant: " of tText
   end if
   return tText
end xtaPlainError

--------------------------------------------------------------------------------
-- Replies

-- The fenced code blocks of a reply (``` lines), keys 1 to N, each with
-- "lang" (the word after the opening fence, possibly empty) and "code".
-- A block that is never closed runs to the end of the reply.
function xtaCodeBlocks pText
   local tBlocks, tCount, tInside, tLine, tCode, tLang
   put 0 into tCount
   put false into tInside
   repeat for each line tLine in pText
      if word 1 to -1 of tLine begins with "```" then
         if tInside then
            xtaAddBlock tBlocks, tCount, tLang, tCode
            put false into tInside
         else
            put true into tInside
            put word 1 to -1 of tLine into tLang
            delete char 1 to 3 of tLang
            put word 1 of tLang into tLang
            put empty into tCode
         end if
         next repeat
      end if
      if tInside then
         put tLine & return after tCode
      end if
   end repeat
   if tInside then
      xtaAddBlock tBlocks, tCount, tLang, tCode
   end if
   return tBlocks
end xtaCodeBlocks

-- Adds a block to xBlocks, without the return after its last line.
private command xtaAddBlock @xBlocks, @xCount, pLang, pCode
   if pCode is not empty then
      delete the last char of pCode
   end if
   add 1 to xCount
   put pLang into xBlocks[xCount]["lang"]
   put pCode into xBlocks[xCount]["code"]
end xtaAddBlock

-- True when a fenced block marked pLang holds xTalk: one marked as
-- LiveCode Script, or not marked at all. A block in another language
-- (LiveCode Builder, a shell command, JSON, the assistant's memory notes)
-- is never inserted into a script.
function xtaIsXTalkLang pLang
   put toLower(word 1 to -1 of pLang) into pLang
   if pLang is empty then
      return true
   end if
   return pLang is among the items of kXTalkLangs
end xtaIsXTalkLang

-- The xTalk blocks of pBlocks (as xtaCodeBlocks returns them), in their
-- order and numbered from 1, without empty ones.
function xtaXTalkBlocks pBlocks
   local tBlocks, tIndex, tCount
   put 0 into tCount
   repeat with tIndex = 1 to the number of elements of pBlocks
      if xtaIsXTalkLang(pBlocks[tIndex]["lang"]) and word 1 to -1 of pBlocks[tIndex]["code"] is not empty then
         add 1 to tCount
         put pBlocks[tIndex] into tBlocks[tCount]
      end if
   end repeat
   return tBlocks
end xtaXTalkBlocks

-- The guide the assistant is given first (xtalk-guide.md in the plugin's
-- folder), or empty when it cannot be read. It is plain ASCII text; the
-- line endings are made returns, whatever the file has.
function xtaReadGuide pPath
   local tData, tText
   if there is not a file pPath then
      return empty
   end if
   put url ("binfile:" & pPath) into tData
   if the result is not empty then
      return empty
   end if
   put textDecode(tData, "UTF-8") into tText
   replace crlf with return in tText
   replace numToChar(13) with return in tText
   return word 1 to -1 of tText
end xtaReadGuide

-- The short guide: what the assistant is told before the conversation when
-- the guide cannot be read, or when the user asks for the short one (for a
-- small model on a server of their own, which may not hold the whole guide).
-- It names the language and the engine, and the habits that keep code
-- working on this engine and the xTalks it came from; the numbers in
-- brackets are those of xtalk-suite's docs/OXT-ENGINE-NOTES.md, where each
-- one is recorded. Where OXT-Beyond has changed what those notes saw, the
-- advice still holds and says so (3.2: README.md, 0.2.4-rc.7; a throw in a
-- catch block reached the caller on 0.2.5-rc.1), or asks only for the safe
-- form (2.5: this engine's and and or stop early, by engine/src/operator.cpp).
function xtaSystemPrompt
   local tPrompt
   put "You are the xTalk Assistant inside " & xtaHostName() & ", a free development environment" && \
         "that continues OpenXTalk Lite and LiveCode Community 9.x. Its users build" && \
         "programs from stacks, cards and controls (buttons, fields, graphics, images," && \
         "groups, widgets) and script them in xTalk Script, the English-like language" && \
         "of the HyperCard tradition that LiveCode calls LiveCode Script. Call it xTalk" && \
         "Script when you write to the user, as OXT-Beyond does." & return & return into tPrompt
   put "When you write code:" & return after tPrompt
   put "- Write xTalk Script for this engine, not HyperTalk, AppleScript or JavaScript." && \
         "Put each script in a fenced block marked livecodescript, holding whole handlers" && \
         "(on ... end, command ... end, function ... end), so the user can insert it into" && \
         "the Script Editor as it is." & return after tPrompt
   put "- Say which object each script belongs to (the button, the card, the stack)." & return after tPrompt
   put "- Declare every variable with local, and every script-level local or constant" && \
         "above the first handler that uses it: an undeclared name is not an error, it" && \
         "evaluates to its own name (1.2, 2.1). Constants must be literal values (1.3)." & return after tPrompt
   put "- Use only straight ASCII quotes; curly quotes stop a script from compiling," && \
         "even in a comment (1.4)." & return after tPrompt
   put "- Put a guard (is a number, there is a ...) in its own if before the expression" && \
         "it protects, rather than relying on and or or to skip their second operand (2.5)." & return after tPrompt
   put "- Write a call to a command with no parameters without brackets: myCommand," && \
         "not myCommand() (3.3)." & return after tPrompt
   put "- To pass an error on from a catch block, keep it in a variable and throw after" && \
         "end try: OpenXTalk and LiveCode drop a throw made inside catch (3.2), though" && \
         "OXT-Beyond 0.2.4 and later pass it on." & return after tPrompt
   put "- Handlers reached by send, dispatch or a callback message must not be private (3.5)." & return after tPrompt
   put "- Array keys ignore case: tA[" & quote & "A" & quote & "] and tA[" & quote & "a" & quote & "] are one element (2.7)." & return after tPrompt
   put "- In a handler reached by send ... in, a socket or URL callback, name controls" && \
         "with their stack, or set the defaultStack first (5.3)." & return after tPrompt
   put "- If you are not sure a command, function or property exists in xTalk Script," && \
         "say so rather than inventing one." & return & return after tPrompt
   put "Keep explanations short and plain. When the user shares a script, refer to" && \
         "its handlers by name." after tPrompt
   return tPrompt
end xtaSystemPrompt

--------------------------------------------------------------------------------
-- Checking code
--
-- Every xTalk block of an answer is compiled on this engine before the user
-- reads it, as the Script Editor checks a script (scriptCompile in
-- revseeditorbehavior.livecodescript): by setting the script of a scratch
-- button and reading the result, which is empty, or lines of
-- "code,line,column,hint" with the most telling first; the message of a code
-- is that line of the scriptParsingErrors (empty in a standalone, which
-- leaves them out). Nothing is run. Statements without a handler are
-- compiled inside one of their own. The engine says nothing of a line
-- outside any handler (it skips it) or of a handler defined twice, so those
-- are looked for here, and so are curly quotes (engine note 1.4). A block of
-- handlers is compiled a second time with the explicitVariables on, which
-- refuses a name that is not declared (engine note 2.1) or a literal that is
-- not quoted; the names given in pDeclared (those the user's script declares
-- at its top) count as declared.

-- The problems of one block of code, an array: "ok" (true when there are
-- none) and "issues" (one per line, "line N: what").
function xtaCheckScript pCode, pDeclared
   local tResult, tScan, tScript, tOffset, tError, tIssues, tName, tNames, tPrefix, tLine
   replace crlf with return in pCode
   replace numToChar(13) with return in pCode
   -- A script-only stack's first line names the stack; it is not code. It
   -- is blanked rather than deleted, so the line numbers stay those of the
   -- block.
   if word 1 of line 1 of pCode is "script" and char 1 of word 2 of line 1 of pCode is quote then
      put empty into line 1 of pCode
   end if
   put xtaScanScript(pCode) into tScan
   put tScan["issues"] into tIssues
   -- One issue per line: the scan's come without a last return, and what
   -- follows is put after them
   if tIssues is not empty then
      put return after tIssues
   end if
   put 0 into tOffset
   put pCode into tScript
   if tScan["handlers"] is 0 and tScan["statements"] > 0 then
      put "on" && kCheckHandler & return & pCode & return & "end" && kCheckHandler into tScript
      put 1 into tOffset
   else if tScan["handlers"] > 0 then
      repeat for each item tLine in tScan["statementLines"]
         put "line" && tLine & ": this line is outside any handler, and the engine ignores it" & return after tIssues
      end repeat
   end if

   put xtaCompileError(tScript, false) into tError
   if tError is not empty then
      put xtaCompileIssue(tError, tOffset, false) & return after tIssues
   else if tScan["handlers"] > 0 then
      repeat for each line tName in pDeclared
         if tName is not empty and not (tName is among the lines of tScan["declared"]) then
            if tNames is not empty then
               put comma after tNames
            end if
            put tName after tNames
         end if
      end repeat
      if tNames is not empty then
         put "local" && tNames & return into tPrefix
      end if
      put xtaCompileError(tPrefix & tScript, true) into tError
      if tError is not empty then
         put xtaCompileIssue(tError, tOffset + the number of lines of tPrefix, true) & return after tIssues
      end if
   end if
   if tIssues is not empty then
      delete the last char of tIssues
   end if
   put tIssues into tResult["issues"]
   put (tIssues is empty) into tResult["ok"]
   return tResult
end xtaCheckScript

-- The first line of the result of compiling pScript (empty when it
-- compiles), with the explicitVariables as pExplicit. Both global settings
-- are put back, and the button is left with no script, as the Script
-- Editor leaves its own.
private function xtaCompileError pScript, pExplicit
   local tButton, tOldExplicit, tError, tThrown
   put xtaCheckButton() into tButton
   put the explicitVariables into tOldExplicit
   lock messages
   try
      set the explicitVariables to (pExplicit is true)
      set the script of tButton to pScript
      put the result into tError
   catch tThrown
      put "0,1,1" into tError
   end try
   set the script of tButton to empty
   set the explicitVariables to tOldExplicit
   unlock messages
   return line 1 of tError
end xtaCompileError

-- One line of a compile result, in words, with its line number counted in
-- the block (pOffset lines were put before it to compile it)
private function xtaCompileIssue pError, pOffset, pExplicit
   local tCode, tLine, tColumn, tHint, tMessage, tText
   put item 1 of pError into tCode
   put item 2 of pError into tLine
   put item 3 of pError into tColumn
   put item 4 to -1 of pError into tHint
   if tLine is an integer then
      subtract pOffset from tLine
      if tLine < 1 then
         put 1 into tLine
      end if
   else
      put 1 into tLine
   end if
   if tCode is an integer then
      if tCode > 0 then
         put line tCode of the scriptParsingErrors into tMessage
      end if
   end if
   if tMessage is empty then
      put "compile error" && tCode into tMessage
   else
      put " (error" && tCode & ")" after tMessage
   end if
   put "line" && tLine into tText
   if tColumn is an integer then
      if tColumn > 0 then
         put ", column" && tColumn after tText
      end if
   end if
   put ":" && tMessage after tText
   if tHint is not empty then
      put " near" && quote & tHint & quote after tText
   end if
   if pExplicit then
      put "; with every variable declared (explicitVariables), a name that is not declared, or a literal that is not quoted, is refused" after tText
   end if
   return tText
end xtaCompileIssue

-- The scratch button, made the first time it is needed, in a hidden stack
-- that is never opened. Messages are locked while it is made, so the IDE
-- does not take it for the user's (engine note 5.15).
private function xtaCheckButton
   local tOldDefault
   if there is a button "Check" of stack kCheckStack then
      return the long id of button "Check" of stack kCheckStack
   end if
   put the defaultStack into tOldDefault
   lock messages
   if there is a stack kCheckStack then
      delete stack kCheckStack
   end if
   create invisible stack kCheckStack
   set the _ideoverride of stack kCheckStack to true
   set the defaultStack to kCheckStack
   create button "Check"
   set the defaultStack to tOldDefault
   -- create opens the stack it makes, and an open stack, hidden or not,
   -- can become the topStack, which the IDE's menus and xtaWorkStack take
   -- for the stack the user is working on. Closed, it stays in memory,
   -- where a script can still be set and compiled.
   close stack kCheckStack
   unlock messages
   return the long id of button "Check" of stack kCheckStack
end xtaCheckButton

-- Deletes the scratch stack, when the assistant is turned off or unloaded
command xtaCheckCleanup
   if there is a stack kCheckStack then
      lock messages
      delete stack kCheckStack
      unlock messages
   end if
end xtaCheckCleanup

-- Checks the blocks of an answer (xTalk ones, as xtaXTalkBlocks returns
-- them). Returns an array:
--    ok        true when every block passed
--    blocks, failed   how many were checked, and how many failed
--    summary   one line for the user
--    report    for the model, when a block failed: what to correct
--    code      the blocks' code, to tell whether a correction changed any
function xtaCheckBlocks pBlocks, pDeclared
   local tResult, tIndex, tCount, tCheck, tFailed, tReport, tFirst, tLine
   put the number of elements of pBlocks into tCount
   put 0 into tFailed
   repeat with tIndex = 1 to tCount
      put pBlocks[tIndex]["code"] & return & "```" & return after tResult["code"]
      put xtaCheckScript(pBlocks[tIndex]["code"], pDeclared) into tCheck
      if tCheck["ok"] is not true then
         add 1 to tFailed
         put "In xTalk block" && tIndex & ":" & return after tReport
         repeat for each line tLine in tCheck["issues"]
            put "- " & tLine & return after tReport
         end repeat
         if tFirst is empty then
            put "block" && tIndex & "," && line 1 of tCheck["issues"] into tFirst
         end if
      end if
   end repeat
   put tCount into tResult["blocks"]
   put tFailed into tResult["failed"]
   put (tFailed is 0) into tResult["ok"]
   if tFailed is 0 then
      if tCount is 1 then
         put "Compile check: the code compiles." into tResult["summary"]
      else
         put "Compile check: all" && tCount && "blocks of code compile." into tResult["summary"]
      end if
      return tResult
   end if
   if tCount is 1 then
      put "Compile check: the code does not compile (" & tFirst & ")." into tResult["summary"]
      put "Compile check: your block of xTalk Script does not compile on " & xtaHostName() & "." into tLine
   else
      put "Compile check:" && tFailed && "of" && tCount && "blocks of code do not compile (" & tFirst & ")." into tResult["summary"]
      put "Compile check:" && tFailed && "of your" && tCount && "blocks of xTalk Script do not compile on " & xtaHostName() & "." into tLine
   end if
   put tLine & return & tReport & "Answer with every block again, corrected and whole." into tResult["report"]
   return tResult
end xtaCheckBlocks

-- How pCode is made, as the compile check reads it: an array with
-- "handlers" (how many handlers it defines) and "statements" (how many
-- lines outside any handler are not declarations). An object's script is
-- handlers; statements are what the Message Box runs.
function xtaScriptCounts pCode
   local tScan, tCounts
   replace crlf with return in pCode
   replace numToChar(13) with return in pCode
   put xtaScanScript(pCode) into tScan
   put tScan["handlers"] into tCounts["handlers"]
   put tScan["statements"] into tCounts["statements"]
   return tCounts
end xtaScriptCounts

-- The names a script declares with local, global and constant outside its
-- handlers, one per line
function xtaDeclaredNames pScript
   local tScan
   replace crlf with return in pScript
   replace numToChar(13) with return in pScript
   put xtaScanScript(pScript) into tScan
   return tScan["topDeclared"]
end xtaDeclaredNames

-- Reads a script line by line, comments and the text of strings left out.
-- Returns an array:
--    handlers        how many handlers it defines
--    statements      how many lines outside any handler are not declarations
--    statementLines  their line numbers, as items (the first three)
--    declared        every name declared anywhere, parameters too, one per line
--    topDeclared     the names declared outside any handler, one per line
--    issues          what is wrong that the engine does not say, one per line
private function xtaScanScript pCode
   local tScan, tLineNo, tLine, tCode, tInComment, tHandler, tKind, tNameWord
   local tName, tKey, tSeen, tContinued, tDeclaring, tTopLevel
   put 0 into tScan["handlers"]
   put 0 into tScan["statements"]
   put false into tInComment
   put false into tContinued
   put empty into tDeclaring
   put 0 into tLineNo
   repeat for each line tLine in pCode
      add 1 to tLineNo
      if xtaHasCurlyQuote(tLine) then
         put "line" && tLineNo & ": curly quotes; use straight quotes (" & quote & " and ')" & return after tScan["issues"]
      end if
      put word 1 to -1 of xtaCodePart(tLine, tInComment) into tCode
      if tCode is empty then
         next repeat
      end if
      -- The rest of a statement continued from the line before
      if tContinued then
         put the last char of tCode is "\" into tContinued
         if tDeclaring is "parameters" then
            xtaAddParameters tScan, tCode
         else if tDeclaring is not empty then
            xtaAddDeclaredNames tScan, tCode, (tDeclaring is "top")
         end if
         next repeat
      end if
      put the last char of tCode is "\" into tContinued
      put empty into tDeclaring
      put toLower(word 1 of tCode) into tKind
      put 2 into tNameWord
      if tKind is "private" then
         put toLower(word 2 of tCode) into tKind
         put 3 into tNameWord
      end if
      put (tHandler is empty) into tTopLevel

      if tTopLevel and tKind is among the items of "on,command,function,getprop,setprop,before,after" then
         put word tNameWord of tCode into tName
         put tName into tHandler
         add 1 to tScan["handlers"]
         -- "on" and "command" handlers answer the same calls
         if tKind is "on" then
            put "command" into tKind
         end if
         put tKind & ":" & toLower(tName) into tKey
         if tSeen[tKey] is an integer then
            put "line" && tLineNo & ": the" && tKind && "handler" && tName && \
                  "is defined twice (also at line" && tSeen[tKey] & "); keep one" & return after tScan["issues"]
         else
            put tLineNo into tSeen[tKey]
         end if
         -- Its parameters are declared
         xtaAddParameters tScan, word tNameWord + 1 to -1 of tCode
         put "parameters" into tDeclaring
         next repeat
      end if
      if tKind is among the items of "local,global,constant" then
         put word 2 to -1 of tCode into tCode
         xtaAddDeclaredNames tScan, tCode, tTopLevel
         if tTopLevel then
            put "top" into tDeclaring
         else
            put "handler" into tDeclaring
         end if
         next repeat
      end if
      if tTopLevel then
         add 1 to tScan["statements"]
         if tScan["statements"] <= 3 then
            if tScan["statementLines"] is not empty then
               put comma after tScan["statementLines"]
            end if
            put tLineNo after tScan["statementLines"]
         end if
      else if tKind is "end" and toLower(word 2 of tCode) is toLower(tHandler) then
         put empty into tHandler
      end if
   end repeat
   if tScan["issues"] is not empty then
      delete the last char of tScan["issues"]
   end if
   return tScan
end xtaScanScript

-- Adds the names of a declaration (what follows local, global or
-- constant, the text of its strings left out) to xScan
private command xtaAddDeclaredNames @xScan, pText, pTopLevel
   local tPart, tName, tAt
   if the last char of pText is "\" then
      delete the last char of pText
   end if
   repeat for each item tPart in pText
      -- A value given to it ("local tCount = 0") is not part of the name
      put offset("=", tPart) into tAt
      if tAt > 0 then
         delete char tAt to -1 of tPart
      end if
      put word 1 of tPart into tName
      if tName is empty or not matchText(tName, "^[A-Za-z_][A-Za-z0-9_]*$") then
         next repeat
      end if
      put tName & return after xScan["declared"]
      if pTopLevel then
         put tName & return after xScan["topDeclared"]
      end if
   end repeat
end xtaAddDeclaredNames

-- Adds a handler's parameters (what follows its name) to xScan
private command xtaAddParameters @xScan, pText
   local tPart, tName
   if the last char of pText is "\" then
      delete the last char of pText
   end if
   repeat for each item tPart in pText
      put word 1 of tPart into tName
      if char 1 of tName is "@" then
         delete char 1 of tName
      end if
      if matchText(tName, "^[A-Za-z_][A-Za-z0-9_]*$") then
         put tName & return after xScan["declared"]
      end if
   end repeat
end xtaAddParameters

-- The code of one line: its comments left out, and the text of its strings
-- (their quotes kept), so that neither is read as code. xInComment carries
-- a /* comment */ over from one line to the next.
private function xtaCodePart pLine, @xInComment
   local tOut, tChar, tNext, tInString, tIndex, tLength
   put false into tInString
   put the number of chars of pLine into tLength
   put 1 into tIndex
   repeat while tIndex <= tLength
      put char tIndex of pLine into tChar
      put char tIndex + 1 of pLine into tNext
      if xInComment then
         if tChar is "*" and tNext is "/" then
            put false into xInComment
            put space after tOut
            add 1 to tIndex
         end if
      else if tInString then
         if tChar is quote then
            put false into tInString
            put quote after tOut
         end if
      else if tChar is quote then
         put true into tInString
         put quote after tOut
      else if tChar is "#" or (tChar is "-" and tNext is "-") or (tChar is "/" and tNext is "/") then
         exit repeat
      else if tChar is "/" and tNext is "*" then
         put true into xInComment
         add 1 to tIndex
      else
         put tChar after tOut
      end if
      add 1 to tIndex
   end repeat
   return tOut
end xtaCodePart

-- True when pText has a curly quote in it (U+2018, U+2019, U+201C, U+201D)
private function xtaHasCurlyQuote pText
   return numToCodepoint(8216) is in pText or numToCodepoint(8217) is in pText \
         or numToCodepoint(8220) is in pText or numToCodepoint(8221) is in pText
end xtaHasCurlyQuote

--------------------------------------------------------------------------------
-- What the model reads with its tools
--
-- The plugin carries out the tools the model asks for; these make what the
-- tools read into text for the model. Nothing here asks the user, runs code
-- or changes anything (the plugin asks before it reads the user's stack).

-- The names of pNames (one per line) nearest pWord, at most pMax of them,
-- the nearest first, one per line: those a few letters away (by edit
-- distance, at most a third of its length, and 2 for a short word), then
-- those that hold it or that it holds. For "did you mean" in a message:
-- a property misspelt, a Dictionary entry not found. Case is ignored.
function xtaNearest pWord, pNames, pMax
   local tWord, tName, tLower, tLimit, tScore, tScores, tLine, tResult, tCount, tSeen
   put toLower(word 1 to -1 of pWord) into tWord
   if tWord is empty or pMax is not an integer or pMax < 1 then
      return empty
   end if
   put max(2, the number of chars of tWord div 3) into tLimit
   repeat for each line tName in pNames
      put toLower(word 1 to -1 of tName) into tLower
      if tLower is empty then
         next repeat
      end if
      put xtaEditDistance(tWord, tLower, tLimit) into tScore
      if tScore > tLimit then
         if the number of chars of tWord < 3 or the number of chars of tLower < 3 then
            next repeat
         end if
         -- After every name a few letters away, the shorter first: those
         -- that hold the word, then those it holds
         if tLower contains tWord then
            put tLimit + 1 + the number of chars of tLower - the number of chars of tWord into tScore
         else if tWord contains tLower then
            put tLimit + 1000 + the number of chars of tWord - the number of chars of tLower into tScore
         else
            next repeat
         end if
      end if
      put tScore & tab & word 1 to -1 of tName & return after tScores
   end repeat
   set the itemDelimiter to tab
   sort lines of tScores numeric by item 1 of each
   put 0 into tCount
   repeat for each line tLine in tScores
      if tSeen[item 2 of tLine] is true then
         next repeat
      end if
      put true into tSeen[item 2 of tLine]
      put item 2 of tLine & return after tResult
      add 1 to tCount
      if tCount >= pMax then
         exit repeat
      end if
   end repeat
   delete the last char of tResult
   return tResult
end xtaNearest

-- The edit distance of pA and pB (letters inserted, deleted or changed),
-- or pLimit + 1 when it is more than pLimit
private function xtaEditDistance pA, pB, pLimit
   local tLenA, tLenB, tPrev, tRow, tI, tJ, tCost, tBest
   put the number of chars of pA into tLenA
   put the number of chars of pB into tLenB
   if abs(tLenA - tLenB) > pLimit then
      return pLimit + 1
   end if
   repeat with tJ = 0 to tLenB
      put tJ into tPrev[tJ]
   end repeat
   repeat with tI = 1 to tLenA
      put tI into tRow[0]
      put tI into tBest
      repeat with tJ = 1 to tLenB
         if char tI of pA is char tJ of pB then
            put 0 into tCost
         else
            put 1 into tCost
         end if
         put min(tPrev[tJ] + 1, tRow[tJ - 1] + 1, tPrev[tJ - 1] + tCost) into tRow[tJ]
         put min(tBest, tRow[tJ]) into tBest
      end repeat
      if tBest > pLimit then
         return pLimit + 1
      end if
      put tRow into tPrev
   end repeat
   return tPrev[tLenB]
end xtaEditDistance

-- The Dictionary's entries for pTerm, as the IDE's ideDocsFetchLCSData gives
-- them (keys 1 to N, each an array with "display name", "Type", "Summary",
-- "Syntax" 1 to N, "params" 1 to N with "name", "type" and "description",
-- "value" (what it returns, by name, with "description"), "Description",
-- "Example" 1 to N, "Synonyms" 1 to N, "References" (by kind, 1 to N),
-- "Introduced", "Platforms" 1 to N and "Changes"), as text for the model.
-- The Dictionary writes a word that is another entry <thus>; that is kept.
function xtaDictionaryText pTerm, pEntries
   local tCount, tText, tIndex
   put the number of elements of pEntries into tCount
   if tCount is 0 then
      return "The Dictionary has no entry for" && quote & pTerm & quote & \
            ". Look up a command, function, property or message by its name alone (topStack, not the topStack), or a word near it."
   end if
   if tCount is 1 then
      put "The Dictionary's entry for" && quote & pTerm & quote into tText
   else
      put "The Dictionary has" && tCount && "entries for" && quote & pTerm & quote into tText
   end if
   put " (a word in <angle brackets> in its text is the name of another entry):" & return after tText
   repeat with tIndex = 1 to tCount
      if tIndex > kDictionaryMaxEntries or the number of chars of tText > kReadMaxChars then
         put return & "Also:" && pEntries[tIndex]["display name"] && "(" & pEntries[tIndex]["Type"] & ")" after tText
      else
         put return & xtaDictionaryEntry(pEntries[tIndex]) after tText
      end if
   end repeat
   return tText
end xtaDictionaryText

private function xtaDictionaryEntry pEntry
   local tText, tIndex, tKey, tKeys, tList, tName, tSeen, tDescription
   put pEntry["display name"] into tText
   if pEntry["Type"] is not empty then
      put " (" & pEntry["Type"] & ")" after tText
   end if
   put return after tText
   if pEntry["Summary"] is not empty then
      put "Summary:" && pEntry["Summary"] & return after tText
   end if
   if the number of elements of pEntry["Syntax"] > 0 then
      put "Syntax:" & return after tText
      repeat with tIndex = 1 to the number of elements of pEntry["Syntax"]
         put xtaIndent(pEntry["Syntax"][tIndex]) & return after tText
      end repeat
   end if
   if the number of elements of pEntry["params"] > 0 then
      put "Parameters:" & return after tText
      repeat with tIndex = 1 to the number of elements of pEntry["params"]
         put pEntry["params"][tIndex]["name"] into tName
         if pEntry["params"][tIndex]["type"] is not empty then
            put " (" & pEntry["params"][tIndex]["type"] & ")" after tName
         end if
         if pEntry["params"][tIndex]["description"] is not empty then
            put ":" && pEntry["params"][tIndex]["description"] after tName
         end if
         put xtaIndent(tName) & return after tText
      end repeat
   end if
   if pEntry["value"] is an array then
      put the keys of pEntry["value"] into tKeys
      sort lines of tKeys
      put "Returns:" & return after tText
      repeat for each line tKey in tKeys
         put xtaIndent(tKey & ":" && pEntry["value"][tKey]["description"]) & return after tText
      end repeat
   end if
   if pEntry["Description"] is not empty then
      put pEntry["Description"] into tDescription
      if the number of chars of tDescription > kDictionaryMaxDescription then
         put char 1 to kDictionaryMaxDescription of tDescription & " ... (the rest is left out)" into tDescription
      end if
      put "Description:" & return & tDescription & return after tText
   end if
   repeat with tIndex = 1 to min(kDictionaryMaxExamples, the number of elements of pEntry["Example"])
      put "Example:" & return & xtaIndent(pEntry["Example"][tIndex]) & return after tText
   end repeat
   if the number of elements of pEntry["Synonyms"] > 0 then
      put empty into tList
      repeat with tIndex = 1 to the number of elements of pEntry["Synonyms"]
         if tList is not empty then
            put ", " after tList
         end if
         put pEntry["Synonyms"][tIndex] after tList
      end repeat
      put "Synonyms:" && tList & return after tText
   end if
   if pEntry["References"] is an array then
      put the keys of pEntry["References"] into tKeys
      sort lines of tKeys
      put empty into tList
      repeat for each line tKey in tKeys
         repeat with tIndex = 1 to the number of elements of pEntry["References"][tKey]
            put tKey && pEntry["References"][tKey][tIndex] into tName
            if tSeen[tName] is true then
               next repeat
            end if
            put true into tSeen[tName]
            if tList is not empty then
               put ", " after tList
            end if
            put tName after tList
         end repeat
      end repeat
      if tList is not empty then
         put "See also:" && tList & return after tText
      end if
   end if
   if pEntry["Introduced"] is not empty then
      put "Introduced in" && pEntry["Introduced"] & "." & return after tText
   end if
   if pEntry["Changes"] is not empty then
      put "Changes:" && pEntry["Changes"] & return after tText
   end if
   return tText
end xtaDictionaryEntry

-- pText with every line indented by four spaces
private function xtaIndent pText
   replace return with return & "    " in pText
   return "    " & pText
end xtaIndent

-- An execution error as the engine reports it (pTrace: lines of
-- "code,line,column,hint", the most telling first, as the IDE's errorDialog
-- message has it), as text for the model. A line with code 353 names the
-- object whose script the lines before it were in. The message of a code
-- is that line of the scriptExecutionErrors (empty in a standalone); an
-- error a script threw itself is its own text.
function xtaErrorText pTrace
   local tLine, tCode, tLineNumber, tColumn, tHint, tMessage, tText
   replace crlf with return in pTrace
   repeat for each line tLine in pTrace
      if word 1 to -1 of tLine is empty then
         next repeat
      end if
      put item 1 of tLine into tCode
      if tCode is not an integer then
         put "- thrown by the script:" && tLine & return after tText
         next repeat
      end if
      put item 2 of tLine into tLineNumber
      put item 3 of tLine into tColumn
      put item 4 to -1 of tLine into tHint
      if tCode is kObjectNameError then
         put "- in the script of" && tHint & return after tText
         next repeat
      end if
      put empty into tMessage
      if tCode > 0 then
         put line tCode of the scriptExecutionErrors into tMessage
      end if
      if tMessage is empty then
         put "error" && tCode into tMessage
      else
         put " (error" && tCode & ")" after tMessage
      end if
      put "- " & tMessage after tText
      if tLineNumber is an integer then
         if tLineNumber > 0 then
            put ", line" && tLineNumber after tText
            if tColumn is an integer then
               if tColumn > 0 then
                  put ", column" && tColumn after tText
               end if
            end if
         end if
      end if
      if tHint is not empty then
         put ", near" && quote & tHint & quote after tText
      end if
      put return after tText
   end repeat
   if tText is not empty then
      delete the last char of tText
   end if
   return tText
end xtaErrorText

-- Where an execution error happened: an array with "object" (the object
-- the first line with code 353 names) and "line" (the first line number
-- given, in that object's script), either empty when the trace has none
function xtaErrorWhere pTrace
   local tLine, tWhere
   replace crlf with return in pTrace
   repeat for each line tLine in pTrace
      if item 1 of tLine is kObjectNameError then
         if tWhere["object"] is empty then
            put item 4 to -1 of tLine into tWhere["object"]
         end if
      else if tWhere["line"] is empty and item 2 of tLine is an integer then
         if item 2 of tLine > 0 then
            put item 2 of tLine into tWhere["line"]
         end if
      end if
   end repeat
   return tWhere
end xtaErrorWhere

-- The lines of pScript around line pLine, numbered, pLine marked with ">"
function xtaScriptExcerpt pScript, pLine
   local tFrom, tTo, tIndex, tText
   replace crlf with return in pScript
   if pLine is not an integer then
      return empty
   end if
   if pLine < 1 or pLine > the number of lines of pScript then
      return empty
   end if
   put max(1, pLine - kExcerptLines) into tFrom
   put min(the number of lines of pScript, pLine + kExcerptLines) into tTo
   repeat with tIndex = tFrom to tTo
      if tIndex is pLine then
         put ">" after tText
      else
         put space after tText
      end if
      put tIndex & ":" && line tIndex of pScript & return after tText
   end repeat
   delete the last char of tText
   return tText
end xtaScriptExcerpt

-- An outline of the main stack pStack and its substacks, for the model:
-- each stack, its cards, and the controls on each (their type, name, id
-- and rect, a group's controls under it), with how many lines each script
-- has. A group on more than one card is listed under the first. The
-- outline stops at kReadMaxChars, and says so.
function xtaStackOutline pStack
   local tText, tSub, tSeen, tCut
   put the long id of pStack into pStack
   put xtaStackLines(pStack, tSeen) into tText
   repeat for each line tSub in the substacks of pStack
      if the number of chars of tText > kReadMaxChars then
         exit repeat
      end if
      put empty into tSeen
      put xtaStackLines(the long id of stack tSub of pStack, tSeen) after tText
   end repeat
   if the number of chars of tText > kReadMaxChars then
      put char 1 to kReadMaxChars of tText into tText
      put the number of lines of tText into tCut
      delete line tCut of tText
      put "(The outline stops here, at its length limit. Ask for a card by its stack and id to see its controls.)" after tText
   else
      delete the last char of tText
   end if
   return tText
end xtaStackOutline

-- One stack of the outline, and its cards and controls; xSeen keeps which
-- controls are listed already
private function xtaStackLines pStack, @xSeen
   local tText, tIndex, tCard
   if the mainStack of pStack is the short name of pStack then
      put "Stack" into tText
   else
      put "Substack" into tText
   end if
   put space & xtaQuoted(the short name of pStack) after tText
   if the title of pStack is not empty and the title of pStack is not the short name of pStack then
      put ", titled" && xtaQuoted(the title of pStack) after tText
   end if
   put "," && the width of pStack && "x" && the height of pStack & "," && the number of cards of pStack && "cards" after tText
   put xtaScriptNote(pStack) & return after tText
   repeat with tIndex = 1 to the number of cards of pStack
      put the long id of card tIndex of pStack into tCard
      put "  " & xtaNamed(tCard) & xtaScriptNote(tCard) & return after tText
      put xtaControlLines(tCard, xSeen, "    ") after tText
   end repeat
   return tText
end xtaStackLines

-- The controls of the card pCard, one per line, each group's controls
-- under it; xSeen has, by id, the card each was listed on before
private function xtaControlLines pCard, @xSeen, pIndent
   local tText, tIndex, tControl, tId, tDepth
   repeat with tIndex = 1 to the number of controls of pCard
      put the long id of control tIndex of pCard into tControl
      put the id of tControl into tId
      put xtaCountOf(" of group id ", tControl) into tDepth
      if xSeen[tId] is not empty then
         -- A group on this card that was listed under another
         if tDepth is 0 then
            put pIndent & xtaNamed(tControl) & ": also on" && xSeen[tId] & ", with its controls" & return after tText
         end if
         next repeat
      end if
      put xtaRef(pCard) into xSeen[tId]
      repeat tDepth times
         put "  " after tText
      end repeat
      put pIndent & xtaControlLine(tControl) & return after tText
   end repeat
   return tText
end xtaControlLines

-- One control: its type, name, id and rect, what kind of widget, whether
-- it is hidden, its behavior, and how long its script is
private function xtaControlLine pControl
   local tText
   put xtaNamed(pControl) && "at" && the rect of pControl into tText
   if word 1 of the name of pControl is "widget" then
      put ", kind" && the kind of pControl after tText
   end if
   if not the visible of pControl then
      put ", hidden" after tText
   end if
   if the behavior of pControl is not empty then
      put ", behavior" && the behavior of pControl after tText
   end if
   return tText & xtaScriptNote(pControl)
end xtaControlLine

-- ", script: N lines" for an object with a script, else empty
private function xtaScriptNote pObject
   local tScript
   put the script of pObject into tScript
   if tScript is empty then
      return empty
   end if
   return ", script:" && the number of lines of tScript && "lines"
end xtaScriptNote

-- One object of the user's stack, for the model: what and where it is, its
-- properties that have a short value, the names of its custom properties,
-- the text of a field, the controls of a card or the cards of a stack, and
-- its script. With pLean (the MCP bridge's read_stack), only the
-- properties a new object of its type would not have, and the values of
-- its custom properties (a long or many-line one by its length).
function xtaObjectText pObject, pLean
   local tText, tType, tProps, tKeys, tKey, tValue, tList, tScript, tCard, tSeen, tIndex, tDefaults, tCustom
   put the long id of pObject into pObject
   put word 1 of the name of pObject into tType
   put xtaNamed(pObject) into tText
   if tType is "stack" then
      if the mainStack of pObject is not the short name of pObject then
         put ", a substack of" && xtaQuoted(the mainStack of pObject) after tText
      end if
   else
      if tType is not "card" then
         -- The card is in the control's long id, which the engine wrote
         put char offset(" card id ", pObject) + 1 to -1 of pObject into tCard
         put " on" && xtaRef(tCard) after tText
      end if
      put " of stack" && xtaQuoted(the short name of xtaStackOfLongId(pObject)) after tText
   end if
   put return after tText

   put the properties of pObject into tProps
   put the keys of tProps into tKeys
   sort lines of tKeys
   if pLean is true then
      put xtaTemplateProperties(tType) into tDefaults
   end if
   if tDefaults is an array then
      put "Properties (those with a short value that a new" && tType && "does not have):" & return after tText
   else
      put "Properties (those with a short value):" & return after tText
   end if
   repeat for each line tKey in tKeys
      put tProps[tKey] into tValue
      if tValue is an array or tValue is empty or the number of chars of tValue > kMaxPropertyChars then
         next repeat
      end if
      if matchText(tValue, "[[:cntrl:]]") then
         next repeat
      end if
      if tDefaults is an array and tKey is among the keys of tDefaults then
         -- Compared as text, never as numbers
         if ("v" & tDefaults[tKey]) is ("v" & tValue) then
            next repeat
         end if
      end if
      put "  " & tKey & ":" && tValue & return after tText
   end repeat
   put empty into tList
   if pLean is true then
      put the customProperties of pObject into tCustom
      repeat for each line tKey in the keys of tCustom
         put tCustom[tKey] into tValue
         if tValue is an array then
            put "(an array)" into tValue
         else if the number of chars of tValue > kMaxPropertyChars or matchText(tValue, "[[:cntrl:]]") then
            put "(" & the number of chars of tValue && "characters, in" && the number of lines of tValue && "lines)" into tValue
         end if
         put "  " & tKey & ":" && tValue & return after tList
      end repeat
      if tList is not empty then
         put "Custom properties:" & return & tList after tText
      end if
   else
      repeat for each line tKey in the customKeys of pObject
         if tList is not empty then
            put ", " after tList
         end if
         put tKey after tList
      end repeat
      if tList is not empty then
         put "Custom properties (names only):" && tList & return after tText
      end if
   end if
   put empty into tList
   repeat for each line tKey in the customPropertySets of pObject
      if tList is not empty then
         put ", " after tList
      end if
      put tKey after tList
   end repeat
   if tList is not empty then
      put "Custom property sets:" && tList & return after tText
   end if

   switch tType
      case "field"
         put "Text:" & return & xtaCut(the text of pObject, kReadMaxChars div 4) & return after tText
         break
      case "button"
         if the text of pObject is not empty then
            put "Menu items or text:" & return & xtaCut(the text of pObject, kReadMaxChars div 8) & return after tText
         end if
         break
      case "card"
         put "Controls:" & return & xtaControlLines(pObject, tSeen, "  ") after tText
         break
      case "stack"
         put "Cards:" & return after tText
         repeat with tIndex = 1 to the number of cards of pObject
            put "  " & xtaNamed(the long id of card tIndex of pObject) & return after tText
         end repeat
         break
   end switch

   put the script of pObject into tScript
   repeat while the last char of tScript is return
      delete the last char of tScript
   end repeat
   if tScript is empty then
      put "No script." after tText
   else
      put "Script (" & the number of lines of tScript && "lines):" & return & "```livecodescript" & return & \
            xtaCut(tScript, kReadMaxChars) & return & "```" after tText
   end if
   return tText
end xtaObjectText

-- The properties a new object of the type pType has (those of its
-- template), or empty for a type with no template (a widget)
private function xtaTemplateProperties pType
   switch pType
      case "stack"
         return the properties of the templateStack
      case "card"
         return the properties of the templateCard
      case "button"
         return the properties of the templateButton
      case "field"
         return the properties of the templateField
      case "graphic"
         return the properties of the templateGraphic
      case "image"
         return the properties of the templateImage
      case "scrollbar"
         return the properties of the templateScrollbar
      case "player"
         return the properties of the templatePlayer
      case "group"
         return the properties of the templateGroup
   end switch
   return empty
end xtaTemplateProperties

-- The stack an object is in (the stack itself for a stack), from its long
-- id, which ends with it
private function xtaStackOfLongId pObject
   local tAt
   if word 1 of pObject is "stack" then
      return pObject
   end if
   put offset(" of stack ", pObject) into tAt
   return char tAt + 4 to -1 of pObject
end xtaStackOfLongId

-- pText, cut to pMax characters at the end of a line, saying so
private function xtaCut pText, pMax
   local tLines
   if the number of chars of pText <= pMax then
      return pText
   end if
   put the number of lines of pText into tLines
   put char 1 to pMax of pText into pText
   if the number of lines of pText > 1 then
      delete the last line of pText
   end if
   return pText & return & "... (" & tLines - the number of lines of pText && "more lines left out)"
end xtaCut

-- pText in double quotes
private function xtaQuoted pText
   return quote & pText & quote
end xtaQuoted

-- An object of the user's stack as a script would name it: its type and
-- name (button "OK"), or for one with no name its id (card id 1002)
private function xtaRef pObject
   local tName
   put the name of pObject into tName
   if char 1 of word 2 of tName is quote then
      return word 1 of tName && xtaQuoted(the short name of pObject)
   end if
   return tName
end xtaRef

-- As xtaRef, with the id after a name: button "OK" (id 1003), card id 1002
private function xtaNamed pObject
   local tRef
   put xtaRef(pObject) into tRef
   if word 2 of tRef is "id" then
      return tRef
   end if
   return tRef && "(id" && the id of pObject & ")"
end xtaNamed

-- How many times pNeedle is in pText
private function xtaCountOf pNeedle, pText
   local tCount, tAt, tFound
   put 0 into tCount
   put 0 into tAt
   repeat forever
      put offset(pNeedle, pText, tAt) into tFound
      if tFound is 0 then
         exit repeat
      end if
      add 1 to tCount
      add tFound to tAt
   end repeat
   return tCount
end xtaCountOf

--------------------------------------------------------------------------------
-- Memory
--
-- Notes the user keeps for the assistant: about themselves, for every
-- stack, and about one stack, kept by the path of its file so that nothing
-- is ever saved in a stack. They go with every question, after the guide.
-- A memory is an array: "you" (the notes about the user, one per line) and
-- "stacks" (by path, the notes about each stack, one per line). On disk it
-- is a text file the user can read and edit:
--    # a comment
--    [you]
--    - Builds for Windows and Linux only.
--    [stack /Users/ann/Inventory.livecode]
--    - The log is written to field "Log".
-- Lines of any other shape are ignored.

function xtaMemoryParse pText
   local tMemory, tLine, tScope, tPath
   replace crlf with return in pText
   replace numToChar(13) with return in pText
   put empty into tScope
   repeat for each line tLine in pText
      if tLine begins with "[" and the last char of word 1 to -1 of tLine is "]" then
         put word 1 to -1 of tLine into tLine
         if tLine is "[you]" then
            put "you" into tScope
         else if tLine begins with "[stack " then
            put "stack" into tScope
            put xtaTrim(char 8 to -2 of tLine) into tPath
            if tPath is empty then
               put empty into tScope
            end if
         else
            put empty into tScope
         end if
         next repeat
      end if
      if not (tLine begins with "- ") then
         next repeat
      end if
      put xtaTrim(char 3 to -1 of tLine) into tLine
      if tLine is empty then
         next repeat
      end if
      if tScope is "you" then
         put tLine & return after tMemory["you"]
      else if tScope is "stack" then
         put tLine & return after tMemory["stacks"][tPath]
      end if
   end repeat
   -- Without the return after the last note
   if the last char of tMemory["you"] is return then
      delete the last char of tMemory["you"]
   end if
   repeat for each key tPath in tMemory["stacks"]
      if the last char of tMemory["stacks"][tPath] is return then
         delete the last char of tMemory["stacks"][tPath]
      end if
   end repeat
   return tMemory
end xtaMemoryParse

function xtaMemoryFormat pMemory
   local tText, tPath, tPaths, tNote
   put "# The xTalk Assistant's memory (OXT-Beyond): notes that go with every" & return & \
         "# question. Edit them in the assistant's window, under More > Memory..." & return into tText
   if pMemory["you"] is not empty then
      put return & "[you]" & return after tText
      repeat for each line tNote in pMemory["you"]
         put "- " & tNote & return after tText
      end repeat
   end if
   put the keys of pMemory["stacks"] into tPaths
   sort lines of tPaths
   repeat for each line tPath in tPaths
      if pMemory["stacks"][tPath] is empty then
         next repeat
      end if
      put return & "[stack" && tPath & "]" & return after tText
      repeat for each line tNote in pMemory["stacks"][tPath]
         put "- " & tNote & return after tText
      end repeat
   end repeat
   return tText
end xtaMemoryFormat

-- The memory in the file pPath, or an empty one when there is no file
function xtaMemoryLoad pPath
   local tData, tEmpty
   if pPath is empty or there is not a file pPath then
      return tEmpty
   end if
   put url ("binfile:" & pPath) into tData
   if the result is not empty then
      return tEmpty
   end if
   return xtaMemoryParse(textDecode(tData, "UTF-8"))
end xtaMemoryLoad

-- Writes the memory to pPath (deletes the file when there are no notes).
-- The result is empty, or why it could not.
command xtaMemorySave pPath, pMemory
   local tPath, tAny
   put pMemory["you"] is not empty into tAny
   repeat for each key tPath in pMemory["stacks"]
      if pMemory["stacks"][tPath] is not empty then
         put true into tAny
      end if
   end repeat
   if not tAny then
      if there is a file pPath then
         delete file pPath
      end if
      return the result
   end if
   put textEncode(xtaMemoryFormat(pMemory), "UTF-8") into url ("binfile:" & pPath)
   return the result
end xtaMemorySave

-- The notes of a scope: "you", or "stack" with the stack file's path
function xtaMemoryNotes pMemory, pScope, pPath
   if pScope is "you" then
      return pMemory["you"]
   end if
   if pPath is empty then
      return empty
   end if
   return pMemory["stacks"][pPath]
end xtaMemoryNotes

-- Replaces the notes of a scope with pNotes (one per line; empty lines are
-- dropped). The result is empty, or why the notes were refused (and then
-- nothing changed).
command xtaMemorySetNotes @xMemory, pScope, pPath, pNotes
   local tNotes, tNote, tProblem
   replace crlf with return in pNotes
   replace numToChar(13) with return in pNotes
   repeat for each line tNote in pNotes
      replace tab with space in tNote
      put word 1 to -1 of tNote into tNote
      if tNote is empty then
         next repeat
      end if
      put xtaMemoryNoteProblem(tNote) into tProblem
      if tProblem is not empty then
         return tProblem & ":" & return & tNote
      end if
      put tNote & return after tNotes
   end repeat
   if tNotes is not empty then
      delete the last char of tNotes
   end if
   if the number of chars of tNotes > kMemoryMaxScope then
      return "The notes are too long: they go with every question, so they are kept under" && kMemoryMaxScope && "characters."
   end if
   if pScope is "you" then
      put tNotes into xMemory["you"]
   else if pPath is not empty then
      if tNotes is empty then
         delete variable xMemory["stacks"][pPath]
      else
         put tNotes into xMemory["stacks"][pPath]
      end if
   else
      return "There is no saved stack to keep notes about."
   end if
   return empty
end xtaMemorySetNotes

-- Adds one note to a scope, unless it is there already. The result is as
-- xtaMemorySetNotes gives it.
command xtaMemoryAdd @xMemory, pScope, pPath, pNote
   local tNotes
   put word 1 to -1 of pNote into pNote
   put xtaMemoryNotes(xMemory, pScope, pPath) into tNotes
   if pNote is among the lines of tNotes then
      return empty
   end if
   if tNotes is not empty then
      put return after tNotes
   end if
   put pNote after tNotes
   xtaMemorySetNotes xMemory, pScope, pPath, tNotes
   return the result
end xtaMemoryAdd

-- Why a note cannot be kept, or empty. A note goes to the provider with
-- every question, so one that looks like a key or a password is refused.
function xtaMemoryNoteProblem pNote
   if pNote contains return or pNote contains numToChar(10) then
      return "A note is one line"
   end if
   if the number of chars of pNote > kMemoryMaxNote then
      return "A note is at most" && kMemoryMaxNote && "characters"
   end if
   -- A provider's key (sk-...), an AWS key, a run of 32 or more letters and
   -- digits with both in it, or a password or key written out
   if matchText(pNote, "(?i)(sk-[A-Za-z0-9_-]{12,}|AKIA[0-9A-Z]{16}|(?=[A-Za-z0-9_-]*[0-9])(?=[A-Za-z0-9_-]*[A-Za-z])[A-Za-z0-9_-]{32,}|(password|passwd|api[ _-]?key|secret|token)\s*[:=]\s*\S)") then
      return "A note must not hold a key, password or other secret, and this one looks like it does"
   end if
   return empty
end xtaMemoryNoteProblem

-- The notes as the model is told them, after the guide: those about the
-- user, and those about the stack at pPath (named pName), or empty
function xtaMemoryPrompt pMemory, pPath, pName
   local tText, tNote, tNotes
   if pMemory["you"] is not empty then
      put return & return & "About the user:" after tText
      repeat for each line tNote in pMemory["you"]
         put return & "- " & tNote after tText
      end repeat
   end if
   put xtaMemoryNotes(pMemory, "stack", pPath) into tNotes
   if tNotes is not empty then
      put return & return & "About the stack" && quote & pName & quote && "they are working on:" after tText
      repeat for each line tNote in tNotes
         put return & "- " & tNote after tText
      end repeat
   end if
   if tText is empty then
      return empty
   end if
   return "## Notes to keep in mind" & return & return & \
         "The user keeps these notes for you." & tText
end xtaMemoryPrompt

-- The notes an answer proposes, in its blocks marked memory: keys 1 to N,
-- each with "scope" ("you" or "stack") and "note". A line without "you:"
-- or "stack:" before it is a note about the user.
function xtaMemoryProposals pText
   local tBlocks, tIndex, tLine, tProposals, tCount, tScope
   put 0 into tCount
   put xtaCodeBlocks(pText) into tBlocks
   repeat with tIndex = 1 to the number of elements of tBlocks
      if toLower(tBlocks[tIndex]["lang"]) is not "memory" then
         next repeat
      end if
      repeat for each line tLine in tBlocks[tIndex]["code"]
         put word 1 to -1 of tLine into tLine
         if tLine begins with "- " then
            put xtaTrim(char 3 to -1 of tLine) into tLine
         end if
         put "you" into tScope
         if tLine begins with "you:" then
            delete char 1 to 4 of tLine
         else if tLine begins with "stack:" then
            put "stack" into tScope
            delete char 1 to 6 of tLine
         end if
         put word 1 to -1 of tLine into tLine
         if tLine is empty then
            next repeat
         end if
         add 1 to tCount
         put tScope into tProposals[tCount]["scope"]
         put tLine into tProposals[tCount]["note"]
      end repeat
   end repeat
   return tProposals
end xtaMemoryProposals

-- pText without the spaces, tabs and returns at its start and end
private function xtaTrim pText
   return word 1 to -1 of pText
end xtaTrim

-- pText without its blocks marked memory (which the window shows as notes
-- to remember instead), and without the empty lines they leave at its end
function xtaWithoutMemoryBlocks pText
   local tOut, tLine, tInside, tSkipping
   put false into tInside
   put false into tSkipping
   repeat for each line tLine in pText
      if word 1 to -1 of tLine begins with "```" then
         if tInside then
            put false into tInside
            if tSkipping then
               put false into tSkipping
               next repeat
            end if
         else
            put true into tInside
            if toLower(word 1 of xtaTrim(char 4 to -1 of xtaTrim(tLine))) is "memory" then
               put true into tSkipping
               next repeat
            end if
         end if
      end if
      if not tSkipping then
         put tLine & return after tOut
      end if
   end repeat
   return word 1 to -1 of tOut
end xtaWithoutMemoryBlocks

-- The IDE's name, where the user or the model reads it: "OXT-Beyond", or,
-- in a package of the plugin installed in another xTalk's IDE, the name
-- its compatibility stack gives (tools/plugins/plugin-compat.livecodescript.in)
private function xtaHostName
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
end xtaHostName
