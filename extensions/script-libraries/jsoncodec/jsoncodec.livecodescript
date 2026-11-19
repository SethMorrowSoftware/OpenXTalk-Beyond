script "com.livecode.library.jsoncodec"
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
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

The stack is named com.livecode.library.jsoncodec, though LiveCode Ltd did
not write it, because the build names every script library's package
com.livecode.library.<file name> (extensions/extensions.gyp, and the tools
that read it), and the package must be named as its stack is.

Written for OXT-Beyond from the JSON specification (RFC 8259) and from the
public descriptions of LiveCode Create's jsonEncode and jsonDecode functions
(their names, and the idea that a JSON array and a JSON object stay apart).
No LiveCode Create code was seen or used.

WHY A SHAPE, AND NOT A NEW KIND OF ARRAY: an xTalk script array has one type.
A JSON array [10, 20] can only come into script as an array keyed 1 and 2,
and from then on nothing says it was not the object {"1": 10, "2": 20}; an
empty array and an empty object are both empty. Giving the engine's arrays a
"sequence" flag would change what every array operation, custom property and
saved stack does, so instead jsonDecode hands back ordinary arrays, exactly
as script has always seen them, and, when asked, a second array (the shape)
that records what each part of the JSON was. jsonEncode reads the shape back.
Nothing else in the engine or the IDE changes, and a script that never calls
these handlers sees no difference at all.
*/

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if

   insert the script of me into back

   if the environment contains "development" then
      set the _ideoverride of me to true
   end if
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if

   remove the script of me from back
end extensionFinalize

/**

Title: JSON Codec Library

Author: OXT-Beyond contributors

Type: library

Version: 1.0.0

Description:

This library turns JSON text into xTalk values and back, and keeps the
difference between a JSON array (a sequence) and a JSON object (a
dictionary) that script arrays cannot hold by themselves.

<jsonDecode> returns ordinary arrays, keyed 1 to N for a JSON array and by
name for a JSON object. <jsonDecodeWithShape> returns the same value and
also puts the **shape** of the JSON into a variable: what each part was (a
sequence, a dictionary, a string, a number, true or false, or null), and the
order of each object's keys. <jsonEncode> takes the value and, optionally,
the shape. With the shape, decoding and encoding gives back the same JSON,
including `[]` and `{}`, an object whose keys are 1, 2, 3, the text "123"
that was a string, a number written `1.50`, and the order of the keys.

Without a shape, <jsonEncode> guesses, as most xTalk JSON libraries do.
An array keyed exactly 1 to N becomes a JSON array and any other array
an object, `true` and `false` become booleans, text that is a JSON number
becomes a number, and everything else a string.

A shape is an ordinary array too, so it can be saved with the data. To
change what a part of it says, use <jsonSetKind>; to read it, use
<jsonKindOf>; to see what <jsonEncode> would guess for a value, use
<jsonGuessShape>.

The library adds handlers and changes nothing that was there before: the
JSON Library's <JsonImport> and <JsonExport>, and mergJSON's
`JSONToArray` and `ArrayToJSON`, work as they always have. A handler of
your own named `jsonEncode` or `jsonDecode`, in your stack or in a library
you `start using`, is found before this library's.

Example:
local tJSON, tData, tShape
put "{'tags': [], 'id': '42'}" into tJSON
replace "'" with quote in tJSON
put jsonDecodeWithShape(tJSON, tShape) into tData
put "new" into tData["tags"][1]
put jsonEncode(tData, tShape) -- {"tags":["new"],"id":"42"}
put jsonEncode(tData) -- {"id":42,"tags":["new"]}, guessed

Tags: JSON, Library

*/

-- The parser's state. A JSON text is read by code unit, not by char: a
-- code unit is found in constant time, and every character JSON gives a
-- meaning to is one code unit, so nothing is lost by it.
local sText
local sPos
local sLen
local sNextBackslash
local sOffsetBase

/**
Summary: Converts JSON text to an xTalk value.

Syntax: jsonDecode(<pJSON>)

Parameters:
pJSON: The JSON text, as text (use `textDecode(tData, "UTF-8")` on bytes
read from a file or the network first).

Returns: The value: an array for a JSON array or object, and text for
anything else.

Description:
<jsonDecode> reads JSON text (RFC 8259) and returns it as an xTalk value.

- A JSON array becomes an array keyed 1 to N, in order; an empty one
  becomes empty.
- A JSON object becomes an array keyed by its names; an empty one becomes
  empty. Names that differ only in case are kept apart; set the
  caseSensitive to true to read them apart.
- A string becomes its text, with every escape undone.
- A number becomes the number exactly as the JSON wrote it (`1.50`
  stays `1.50`, and a 30-digit integer keeps all its digits); it can be used
  in arithmetic like any number.
- `true` and `false` become `true` and `false`, and `null` becomes empty.

Text that is not JSON is an error that names the line and column where
reading stopped. When an object names a key twice, the last value is kept.

What the value cannot say (whether an empty part was `[]`, `{}`, `""` or
`null`, whether an array keyed 1 to N was a JSON array or an object, whether
`true` was a boolean or a string) is in the shape that
<jsonDecodeWithShape> returns as well.

Example:
local tData
put jsonDecode("[10, [true, null], 2.50]") into tData
put tData[2][1] -- true
put tData[3] + 1 -- 3.5

Related: jsonDecodeWithShape (function), jsonEncode (function), JsonImport (handler)

Tags: JSON
*/
function jsonDecode pJSON
   local tValue, tShape
   jcDecode pJSON, tValue, tShape
   return tValue
end jsonDecode

/**
Summary: Converts JSON text to an xTalk value, and returns its shape too.

Syntax: jsonDecodeWithShape(<pJSON>, <rShape>)

Parameters:
pJSON: The JSON text, as text.

rShape: A variable, into which <jsonDecodeWithShape> puts the shape of the
JSON.

Returns: The value, as <jsonDecode> returns it.

Description:
<jsonDecodeWithShape> reads JSON text as <jsonDecode> does, and puts into
<rShape> what script arrays cannot hold: which parts were sequences and
which dictionaries, which were strings, numbers, booleans and null, and the
order of every object's keys. Give the value and the shape to
<jsonEncode> to write the same JSON back, even after changing the value.

A shape is an array: for a JSON array or object, its "kind" is `sequence`
or `dictionary`, its "items" holds the shape of each part by the same key as
the value, and, for an object, its "keys" holds the names in order, keyed 1
to N. The shape of a string, number, boolean or null is just the word
`string`, `number`, `boolean` or `null`. Read it with <jsonKindOf> and
change it with <jsonSetKind>.

Example:
local tShape, tData
put jsonDecodeWithShape("[]", tShape) into tData
put jsonKindOf(tShape, empty) -- sequence
put jsonEncode(tData, tShape) -- []
put jsonEncode(tData) -- "", the guess for empty

Example:
local tShape, tSettings
put jsonDecodeWithShape(textDecode(url ("binfile:" & tPath), "UTF-8"), tShape) into tSettings
put true into tSettings["dark"]
put textEncode(jsonEncode(tSettings, tShape), "UTF-8") into url ("binfile:" & tPath)

Related: jsonDecode (function), jsonEncode (function), jsonKindOf (function), jsonSetKind (command)

Tags: JSON
*/
function jsonDecodeWithShape pJSON, @rShape
   local tValue, tShape
   jcDecode pJSON, tValue, tShape
   put tShape into rShape
   return tValue
end jsonDecodeWithShape

/**
Summary: Converts an xTalk value to JSON text, following its shape.

Syntax: jsonEncode(<pValue> [, <pShape>])

Parameters:
pValue: The value: an array, or text.

pShape: An optional shape, from <jsonDecodeWithShape>, <jsonGuessShape> or
<jsonSetKind>, saying what each part of the value is to be in JSON.

Returns: The JSON text, with no spaces or line breaks between its parts
(use `textEncode(tJSON, "UTF-8")` to write it to a file or send it).

Description:
<jsonEncode> writes a value as JSON (RFC 8259).

Where <pShape> says what a part of the value is, and the value can be that,
it is written that way:

- `sequence`: a JSON array, of the elements in the order of their keys
  (which must all be whole numbers from 1); an empty value is `[]`.
- `dictionary`: a JSON object, with the keys in the order the shape
  records (the order <jsonDecodeWithShape> read them in), then any others in
  sorted order; an empty value is `{}`.
- `string`: a JSON string, even when the text looks like a number.
- `number`: the number as it is written, when it is a JSON number.
- `boolean`: `true` or `false`, when the value is one of them.
- `null`: `null`, when the value is empty.

Every other part is guessed: an array keyed exactly 1 to N is a JSON array
and any other array an object (keys sorted), `true` and `false` are
booleans, text that is a JSON number (`12`, `-0.5`, `1e3`, not `012` or
`.5`) is a number, and anything else, empty too, is a string. A part whose
value no longer fits the shape (a number replaced by a name, say) is
guessed, so changing data after decoding it never stops <jsonEncode>.
Keys the shape does not know, and elements added past its end, are guessed.

Strings are written with `"`, `\` and the control characters escaped, and
every other character as itself, but for half of a surrogate pair standing
alone, which is escaped so that the text stays valid Unicode.

Example:
put jsonEncode(tPerson) -- guessed

Example:
local tShape
put empty into tOrder["items"]
put "0042" into tOrder["id"]
jsonSetKind tShape, "items", "sequence"
jsonSetKind tShape, "id", "string"
put jsonEncode(tOrder, tShape) -- {"id":"0042","items":[]}

Related: jsonDecodeWithShape (function), jsonGuessShape (function), jsonSetKind (command), JsonExport (handler)

Tags: JSON
*/
function jsonEncode pValue, pShape
   return jcEncode(pValue, pShape)
end jsonEncode

/**
Summary: Returns the shape that jsonEncode would guess for a value.

Syntax: jsonGuessShape(<pValue>)

Parameters:
pValue: The value: an array, or text.

Returns: A shape, as <jsonDecodeWithShape> makes them.

Description:
<jsonGuessShape> applies <jsonEncode>'s guesses to every part of a value
and returns them as a shape, which <jsonSetKind> can then change: for
example, to make one array of a value built in script a JSON object even
though its keys are 1 to N. The keys of each dictionary are recorded in
sorted order.

Example:
local tShape
put jsonGuessShape(tData) into tShape
jsonSetKind tShape, "zip", "string"
put jsonEncode(tData, tShape)

Related: jsonEncode (function), jsonSetKind (command)

Tags: JSON
*/
function jsonGuessShape pValue
   return jcGuessShape(pValue)
end jsonGuessShape

/**
Summary: Sets what one part of a value is to be in JSON.

Syntax: jsonSetKind <xShape>, <pPath>, <pKind>

Parameters:
xShape: A variable holding a shape, or empty.

pPath: Where the part is: empty for the whole value, a key, an array of
keys keyed 1 to N (`tPath[1]` the outermost), or lines of keys.

pKind: `sequence`, `dictionary`, `string`, `number`, `boolean` or `null`;
or empty to let <jsonEncode> guess again.

Description:
<jsonSetKind> changes one part of a shape, making the parts above it
containers if they were not. It is the way to say what script arrays cannot:
that an array keyed 1 to N is an object, that an empty value is `[]` or
`{}`, that text such as "00501" is a string, or that empty is `null`.

Setting `sequence` or `dictionary` keeps what the shape already says about
the parts inside; setting anything else drops it.

Example:
local tShape
jsonSetKind tShape, "", "dictionary" -- the whole value is an object
jsonSetKind tShape, "items", "sequence" -- its "items" is an array, even empty
put jsonEncode(tOrder, tShape)

Example:
local tPath
put "users" into tPath[1]
put 2 into tPath[2]
put "zip" into tPath[3]
jsonSetKind tShape, tPath, "string"

Related: jsonKindOf (function), jsonGuessShape (function), jsonEncode (function)

Tags: JSON
*/
command jsonSetKind @xShape, pPath, pKind
   local tPath
   set the caseSensitive to true
   if pKind is not empty and \
         pKind is not among the items of "sequence,dictionary,string,number,boolean,null" then
      throw "jsonSetKind: unknown kind" && quote & pKind & quote
   end if
   put jcPathList(pPath) into tPath
   put jcSetKind(xShape, tPath, 1, pKind) into xShape
end jsonSetKind

/**
Summary: Returns what a shape says one part of a value is.

Syntax: jsonKindOf(<pShape>, <pPath>)

Parameters:
pShape: A shape, from <jsonDecodeWithShape>, <jsonGuessShape> or <jsonSetKind>.

pPath: Where the part is, as <jsonSetKind> takes it.

Returns: `sequence`, `dictionary`, `string`, `number`, `boolean` or `null`;
empty when the shape says nothing about that part.

Description:
<jsonKindOf> answers what script arrays alone cannot: whether a part read
by <jsonDecodeWithShape> was a JSON array or a JSON object, whether empty was `null`
or `""`, and whether `true` was a boolean or a string.

Example:
local tShape
get jsonDecodeWithShape("{" & quote & "list" & quote & ": []}", tShape)
put jsonKindOf(tShape, "list") -- sequence

Related: jsonSetKind (command), jsonDecodeWithShape (function)

Tags: JSON
*/
function jsonKindOf pShape, pPath
   local tPath, tNode
   set the caseSensitive to true
   put jcPathList(pPath) into tPath
   put pShape into tNode
   repeat with i = 1 to the number of elements of tPath
      if tNode is not an array then
         return empty
      end if
      put tNode["items"][tPath[i]] into tNode
   end repeat
   if tNode is an array then
      return tNode["kind"]
   end if
   return tNode
end jsonKindOf

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

-- The shape comes back through a variable of jsonDecodeWithShape's own, not
-- an optional one of jsonDecode's: in this engine a call that leaves out a
-- parameter declared with @ is an error, even when the handler never uses it.
private command jcDecode pJSON, @rValue, @rShape
   local tError

   put pJSON into sText
   put 1 into sPos
   put the number of codeunits of sText into sLen
   put 0 into sNextBackslash
   -- codeunitOffset's answer, with a number of code units to skip, counts
   -- from the start of the text in this engine (offset's counts from after
   -- the skipped part). Asking once keeps jcFind right either way.
   if codeunitOffset("b", "ab", 1) is 2 then
      put 0 into sOffsetBase
   else
      put 1 into sOffsetBase
   end if

   try
      jcSkipSpace
      if sPos > sLen then
         jcFail "there is no JSON value"
      end if
      jcParseDocument rValue, rShape
      jcSkipSpace
      if sPos <= sLen then
         jcFail "there is more text after the JSON value"
      end if
   catch tError
      put empty into sText
      throw tError
   end try
   put empty into sText
end jcDecode

-- Throws an error naming the line and column of sPos. The position is
-- counted only here, when it is needed, so reading never pays for it.
private command jcFail pMessage
   local tBefore, tLine, tColumn
   put codeunit 1 to sPos - 1 of sText into tBefore
   put the number of lines of (tBefore & "x") into tLine
   set the itemDelimiter to numToCodepoint(10)
   put the number of codeunits of the last item of (tBefore & "x") into tColumn
   put empty into sText
   throw "jsonDecode: syntax error at line" && tLine & ", column" && tColumn & ":" && pMessage
end jcFail

-- JSON's whitespace is space, tab, line feed and carriage return; nothing
-- else (a form feed, a no-break space) is.
private command jcSkipSpace
   local tCode
   repeat while sPos <= sLen
      put codepointToNum(codeunit sPos of sText) into tCode
      if tCode is 32 or tCode is 10 or tCode is 13 or tCode is 9 then
         add 1 to sPos
      else
         exit repeat
      end if
   end repeat
end jcSkipSpace

-- The whole document, without recursion: a script handler call takes about
-- a thousandth of the engine's recursion limit, so a parser that called
-- itself for each level stopped near 100 levels. Here the open arrays and
-- objects are a stack of variables, and the depth is bounded by memory.
-- tValue[d], tShape[d]: the array or object open at depth d, and its shape;
-- tCount[d]: its elements so far; tKey[d]: the name whose value is being
-- read (objects); tSeen[d]: the names already read (objects).
private command jcParseDocument @rValue, @rShape
   local tDepth, tValue, tShape, tCount, tKey, tSeen, tChar
   local tItem, tItemShape, tClosed, tName
   set the caseSensitive to true
   put 0 into tDepth
   repeat
      -- A value starts here.
      jcSkipSpace
      if sPos > sLen then
         jcFail "a value is missing"
      end if
      put codeunit sPos of sText into tChar
      put false into tClosed
      if tChar is "[" or tChar is "{" then
         add 1 to sPos
         add 1 to tDepth
         put empty into tValue[tDepth]
         put empty into tShape[tDepth]
         put 0 into tCount[tDepth]
         put empty into tSeen[tDepth]
         if tChar is "[" then
            put "sequence" into tShape[tDepth]["kind"]
         else
            put "dictionary" into tShape[tDepth]["kind"]
         end if
         jcSkipSpace
         if sPos <= sLen and codeunit sPos of sText is jcCloser(tChar) then
            -- [] or {}: closed at once
            add 1 to sPos
            put true into tClosed
         else if tChar is "[" then
            next repeat
         else
            jcParseName tName
            put tName into tKey[tDepth]
            next repeat
         end if
      else
         put empty into tItem
         put empty into tItemShape
         jcParseScalar tChar, tItem, tItemShape
      end if

      -- A value has ended: put it into the array or object it is in, and
      -- close every one that ends after it.
      repeat
         if tClosed then
            put tValue[tDepth] into tItem
            put tShape[tDepth] into tItemShape
            delete variable tValue[tDepth]
            delete variable tShape[tDepth]
            delete variable tSeen[tDepth]
            subtract 1 from tDepth
            put false into tClosed
         end if
         if tDepth is 0 then
            put tItem into rValue
            put tItemShape into rShape
            return empty
         end if
         if tShape[tDepth]["kind"] is "sequence" then
            add 1 to tCount[tDepth]
            put tItem into tValue[tDepth][tCount[tDepth]]
            put tItemShape into tShape[tDepth]["items"][tCount[tDepth]]
            put "]" into tChar
         else
            -- A name given twice keeps its first place and its last value.
            put tKey[tDepth] into tName
            if tSeen[tDepth][tName] is not true then
               put true into tSeen[tDepth][tName]
               add 1 to tCount[tDepth]
               put tName into tShape[tDepth]["keys"][tCount[tDepth]]
            end if
            put tItem into tValue[tDepth][tName]
            put tItemShape into tShape[tDepth]["items"][tName]
            put "}" into tChar
         end if

         jcSkipSpace
         if sPos > sLen then
            if tChar is "]" then
               jcFail "an array is not closed"
            end if
            jcFail "an object is not closed"
         end if
         if codeunit sPos of sText is "," then
            add 1 to sPos
            if tChar is "}" then
               jcParseName tName
               put tName into tKey[tDepth]
            end if
            exit repeat
         else if codeunit sPos of sText is tChar then
            add 1 to sPos
            put true into tClosed
         else if tChar is "]" then
            jcFail "expected , or ] in an array"
         else
            jcFail "expected , or } in an object"
         end if
      end repeat
   end repeat
end jcParseDocument

private function jcCloser pOpener
   if pOpener is "[" then
      return "]"
   end if
   return "}"
end jcCloser

-- A name in an object and the colon after it.
private command jcParseName @rName
   jcSkipSpace
   if sPos > sLen or codeunit sPos of sText is not quote then
      jcFail "expected a name in quotes"
   end if
   put empty into rName
   jcParseString rName
   jcSkipSpace
   if sPos > sLen or codeunit sPos of sText is not ":" then
      jcFail "expected : after a name"
   end if
   add 1 to sPos
end jcParseName

-- A string, number, true, false or null starting with pChar at sPos.
private command jcParseScalar pChar, @rValue, @rShape
   set the caseSensitive to true
   switch pChar
      case quote
         jcParseString rValue
         put "string" into rShape
         break
      case "t"
         jcParseLiteral "true"
         put "true" into rValue
         put "boolean" into rShape
         break
      case "f"
         jcParseLiteral "false"
         put "false" into rValue
         put "boolean" into rShape
         break
      case "n"
         jcParseLiteral "null"
         put empty into rValue
         put "null" into rShape
         break
      default
         if pChar is "-" or pChar is in "0123456789" then
            jcParseNumber rValue
            put "number" into rShape
         else
            jcFail "unexpected" && quote & pChar & quote
         end if
   end switch
end jcParseScalar

private command jcParseLiteral pWord
   set the caseSensitive to true
   if codeunit sPos to sPos + the number of codeunits of pWord - 1 of sText is not pWord then
      jcFail "expected" && pWord
   end if
   add the number of codeunits of pWord to sPos
end jcParseLiteral

-- A number is kept exactly as written: its text is already a number xTalk
-- can calculate with, and keeping it means no digits are lost to a double
-- and 1.50 is written back as 1.50.
private command jcParseNumber @rValue
   local tEnd, tText
   put sPos into tEnd
   repeat while tEnd <= sLen and codeunit tEnd of sText is in "0123456789+-.eE"
      add 1 to tEnd
   end repeat
   put codeunit sPos to tEnd - 1 of sText into tText
   if not jcIsNumber(tText) then
      jcFail "bad number" && quote & tText & quote
   end if
   put tText into rValue
   put tEnd into sPos
end jcParseNumber

-- sPos is at the opening quote. Plain runs between escapes are copied in
-- one piece; the position of the next backslash is remembered across
-- strings, so a long text with few escapes is not searched again and again.
private command jcParseString @rString
   local tQuote, tChunk, tEscape, tCode, tLow
   set the caseSensitive to true
   add 1 to sPos
   put empty into rString
   repeat
      put jcFind(quote) into tQuote
      if tQuote is 0 then
         jcFail "a string is not closed"
      end if
      if sNextBackslash is not -1 and sNextBackslash < sPos then
         put jcFind("\") into sNextBackslash
         if sNextBackslash is 0 then
            put -1 into sNextBackslash
         end if
      end if

      if sNextBackslash is not -1 and sNextBackslash < tQuote then
         put codeunit sPos to sNextBackslash - 1 of sText into tChunk
         jcCheckControl tChunk
         put tChunk after rString
         put sNextBackslash into sPos
         put codeunit sPos + 1 of sText into tEscape
         switch tEscape
            case quote
            case "\"
            case "/"
               put tEscape after rString
               add 2 to sPos
               break
            case "b"
               put numToCodepoint(8) after rString
               add 2 to sPos
               break
            case "f"
               put numToCodepoint(12) after rString
               add 2 to sPos
               break
            case "n"
               put numToCodepoint(10) after rString
               add 2 to sPos
               break
            case "r"
               put numToCodepoint(13) after rString
               add 2 to sPos
               break
            case "t"
               put numToCodepoint(9) after rString
               add 2 to sPos
               break
            case "u"
               put jcHex4(sPos + 2) into tCode
               add 6 to sPos
               -- A pair of escaped surrogates is one character.
               if tCode >= 55296 and tCode <= 56319 and \
                     codeunit sPos to sPos + 1 of sText is "\u" then
                  put jcHex4(sPos + 2) into tLow
                  if tLow >= 56320 and tLow <= 57343 then
                     put 65536 + (tCode - 55296) * 1024 + (tLow - 56320) into tCode
                     add 6 to sPos
                  end if
               end if
               put numToCodepoint(tCode) after rString
               break
            default
               add 1 to sPos
               jcFail "bad escape" && quote & "\" & tEscape & quote
         end switch
      else
         put codeunit sPos to tQuote - 1 of sText into tChunk
         jcCheckControl tChunk
         put tChunk after rString
         put tQuote + 1 into sPos
         exit repeat
      end if
   end repeat
end jcParseString

-- The position, counted from the start of the text, of the first pNeedle
-- at or after sPos; 0 when there is none.
private function jcFind pNeedle
   local tAt
   put codeunitOffset(pNeedle, sText, sPos - 1) into tAt
   if tAt is 0 then
      return 0
   end if
   return tAt + sOffsetBase * (sPos - 1)
end jcFind

private function jcHex4 pAt
   local tHex
   put codeunit pAt to pAt + 3 of sText into tHex
   if not matchText(tHex, "^[0-9A-Fa-f]{4}\z") then
      put pAt into sPos
      jcFail "bad \u escape"
   end if
   return baseConvert(tHex, 16, 10)
end jcHex4

-- RFC 8259: a control character inside a string must be escaped.
private command jcCheckControl pChunk
   if matchText(pChunk, "[\x00-\x1F]") then
      jcFail "a control character inside a string must be escaped"
   end if
end jcCheckControl


--------------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------------

-- The whole value, without recursion (see jcParseDocument): the arrays
-- being written are a stack of variables. tValue[d], tShape[d]: the array
-- at depth d and its shape; tKeys[d]: its keys in the order they are
-- written, keyed 1 to N; tIndex[d]: the key written last; tKind[d]:
-- sequence or dictionary.
private function jcEncode pValue, pShape
   local tOut, tDepth, tValue, tShape, tKeys, tIndex, tKind
   local tItem, tItemShape, tWhat, tItemKeys, tKey, tText
   set the caseSensitive to true
   put pValue into tItem
   put pShape into tItemShape
   put 0 into tDepth
   repeat
      -- Write one value, or open the array it is.
      put empty into tItemKeys
      put jcClassify(tItem, tItemShape, tItemKeys) into tWhat
      if tWhat is "sequence" or tWhat is "dictionary" then
         if the number of elements of tItemKeys is 0 then
            if tWhat is "sequence" then
               put "[]" after tOut
            else
               put "{}" after tOut
            end if
         else
            add 1 to tDepth
            put tItem into tValue[tDepth]
            put tItemShape into tShape[tDepth]
            put tItemKeys into tKeys[tDepth]
            put 0 into tIndex[tDepth]
            put tWhat into tKind[tDepth]
            if tWhat is "sequence" then
               put "[" after tOut
            else
               put "{" after tOut
            end if
         end if
      else
         put tWhat after tOut
      end if

      -- Move to the next value, closing every array that has none left.
      repeat
         if tDepth is 0 then
            return tOut
         end if
         add 1 to tIndex[tDepth]
         if tIndex[tDepth] > the number of elements of tKeys[tDepth] then
            if tKind[tDepth] is "sequence" then
               put "]" after tOut
            else
               put "}" after tOut
            end if
            delete variable tValue[tDepth]
            delete variable tShape[tDepth]
            delete variable tKeys[tDepth]
            subtract 1 from tDepth
            next repeat
         end if
         if tIndex[tDepth] > 1 then
            put "," after tOut
         end if
         put tKeys[tDepth][tIndex[tDepth]] into tKey
         if tKind[tDepth] is "dictionary" then
            put jcString(tKey) & ":" after tOut
         end if
         put tValue[tDepth][tKey] into tItem
         put tShape[tDepth]["items"][tKey] into tItemShape
         exit repeat
      end repeat
   end repeat
end jcEncode

-- What one part of a value is written as. For an array: "sequence" or
-- "dictionary", with rKeys its keys in the order they are written (keyed 1
-- to N). For anything else: its JSON text.
--
-- Where the shape says what the part is, and the value can be that, it is
-- written that way; otherwise it is guessed. A shape is still read inside
-- a part whose own kind was guessed, so a part can hold parts with kinds.
private function jcClassify pValue, pShape, @rKeys
   local tKind, tKeys
   set the caseSensitive to true
   if pShape is an array then
      put pShape["kind"] into tKind
   else
      put pShape into tKind
   end if

   switch tKind
      case empty
         break
      case "sequence"
         if pValue is an array then
            put jcIndexKeys(pValue, false) into tKeys
            if tKeys is not false then
               put jcLinesToList(tKeys) into rKeys
               return "sequence"
            end if
            put jcDictionaryKeys(pValue, pShape) into rKeys
            return "dictionary"
         else if pValue is empty then
            return "sequence"
         end if
         break
      case "dictionary"
         if pValue is an array then
            put jcDictionaryKeys(pValue, pShape) into rKeys
            return "dictionary"
         else if pValue is empty then
            return "dictionary"
         end if
         break
      case "string"
         if pValue is not an array then
            return jcString(pValue)
         end if
         break
      case "number"
         if pValue is not an array and jcIsNumber(pValue) then
            return pValue
         end if
         break
      case "boolean"
         if pValue is "true" or pValue is "false" then
            return pValue
         end if
         break
      case "null"
         if pValue is empty then
            return "null"
         end if
         break
      default
         throw "jsonEncode: unknown kind" && quote & tKind & quote & " in the shape"
   end switch

   -- The guess.
   if pValue is an array then
      put jcIndexKeys(pValue, true) into tKeys
      if tKeys is not false then
         put jcLinesToList(tKeys) into rKeys
         return "sequence"
      end if
      put jcDictionaryKeys(pValue, pShape) into rKeys
      return "dictionary"
   end if
   if pValue is "true" or pValue is "false" then
      return pValue
   end if
   if jcIsNumber(pValue) then
      return pValue
   end if
   return jcString(pValue)
end jcClassify

private function jcLinesToList pLines
   local tList, i
   put 0 into i
   repeat for each line tLine in pLines
      add 1 to i
      put tLine into tList[i]
   end repeat
   return tList
end jcLinesToList

-- The keys of an object in the order they are written: first those the
-- shape records, in its order, then the rest sorted, so that the same value
-- always gives the same text. A key with a line break in it cannot be
-- sorted as a line; those few go last, in the order the array gives them.
-- The empty key is not sorted as a line either: on its own it would be an
-- empty list of lines, which has none. It sorts before every other key, so
-- it is put first.
private function jcDictionaryKeys pArray, pShape
   local tLeft, tList, tCount, tKey, tSorted, tOdd, tEmpty
   set the caseSensitive to true
   repeat for each key tKey in pArray
      put true into tLeft[tKey]
   end repeat
   put 0 into tCount
   if pShape is an array then
      repeat with i = 1 to the number of elements of pShape["keys"]
         put pShape["keys"][i] into tKey
         if tLeft[tKey] is true then
            add 1 to tCount
            put tKey into tList[tCount]
            delete variable tLeft[tKey]
         end if
      end repeat
   end if
   put false into tEmpty
   repeat for each key tKey in tLeft
      if tKey is empty then
         put true into tEmpty
      else if return is in tKey then
         put tKey into tOdd[the number of elements of tOdd + 1]
      else
         put tKey & return after tSorted
      end if
   end repeat
   delete the last char of tSorted
   sort lines of tSorted ascending text
   if tEmpty then
      add 1 to tCount
      put empty into tList[tCount]
   end if
   repeat for each line tKey in tSorted
      add 1 to tCount
      put tKey into tList[tCount]
   end repeat
   repeat with i = 1 to the number of elements of tOdd
      add 1 to tCount
      put tOdd[i] into tList[tCount]
   end repeat
   return tList
end jcDictionaryKeys

-- The keys of an array in numeric order, one per line, when every key is a
-- whole number from 1 written without leading zeros (with pExact, only when
-- they are exactly 1 to N); false otherwise. "01" and "1.0" are not 1: they
-- are different keys of an xTalk array. The patterns here end in \z, not
-- $: in a regular expression $ also matches before a line break at the end,
-- so "1" & return would pass for 1.
private function jcIndexKeys pArray, pExact
   local tKeys, tCount
   put 0 into tCount
   repeat for each key tKey in pArray
      if not matchText(tKey, "^[1-9][0-9]{0,14}\z") then
         return false
      end if
      add 1 to tCount
      put tKey & return after tKeys
   end repeat
   delete the last char of tKeys
   if pExact then
      repeat for each line tKey in tKeys
         if tKey > tCount then
            return false
         end if
      end repeat
   end if
   sort lines of tKeys ascending numeric
   return tKeys
end jcIndexKeys

private function jcString pText
   local tCode
   replace "\" with "\\" in pText
   replace quote with "\" & quote in pText
   if matchText(pText, "[\x00-\x1F]") then
      replace numToCodepoint(8) with "\b" in pText
      replace numToCodepoint(9) with "\t" in pText
      replace numToCodepoint(10) with "\n" in pText
      replace numToCodepoint(12) with "\f" in pText
      replace numToCodepoint(13) with "\r" in pText
      repeat with tCode = 0 to 31
         replace numToCodepoint(tCode) with "\u00" & format("%02x", tCode) in pText
      end repeat
   end if
   -- Half of a surrogate pair on its own (which a \u escape can give
   -- jsonDecode) is written as an escape: written as itself it would make
   -- textEncode's UTF-8 invalid. The pattern works on UTF-16 code units.
   if matchText(pText, "[\x{D800}-\x{DBFF}](?![\x{DC00}-\x{DFFF}])|(?<![\x{D800}-\x{DBFF}])[\x{DC00}-\x{DFFF}]") then
      put jcEscapeLoneSurrogates(pText) into pText
   end if
   return quote & pText & quote
end jcString

private function jcEscapeLoneSurrogates pText
   local tOut, tCode, tNext, tCount, i
   put the number of codeunits of pText into tCount
   put 1 into i
   repeat while i <= tCount
      put codepointToNum(codeunit i of pText) into tCode
      if tCode >= 55296 and tCode <= 56319 and i < tCount then
         put codepointToNum(codeunit i + 1 of pText) into tNext
         if tNext >= 56320 and tNext <= 57343 then
            put codeunit i to i + 1 of pText after tOut
            add 2 to i
            next repeat
         end if
      end if
      if tCode >= 55296 and tCode <= 57343 then
         put "\u" & format("%04x", tCode) after tOut
      else
         put codeunit i of pText after tOut
      end if
      add 1 to i
   end repeat
   return tOut
end jcEscapeLoneSurrogates

-- JSON's grammar for a number (RFC 8259 section 6), which is narrower than
-- what xTalk calls a number: no leading zeros, no "+", no ".5", no hex,
-- and nothing after it ("42" & return is text).
private function jcIsNumber pText
   if pText is an array or pText is empty then
      return false
   end if
   return matchText(pText, "^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?\z")
end jcIsNumber

--------------------------------------------------------------------------------
-- Shapes
--------------------------------------------------------------------------------

-- The guesses are the shape that jsonDecodeWithShape reads back from the
-- guessed text: one definition of the guess, and no recursion.
private function jcGuessShape pValue
   local tValue, tShape
   jcDecode jcEncode(pValue, empty), tValue, tShape
   return tShape
end jcGuessShape

-- A path as an array keyed 1 to N.
private function jcPathList pPath
   local tPath, i
   if pPath is an array then
      return pPath
   end if
   put 0 into i
   repeat for each line tKey in pPath
      add 1 to i
      put tKey into tPath[i]
   end repeat
   return tPath
end jcPathList

private function jcSetKind pNode, pPath, pIndex, pKind
   local tKind, tContainer, tKey, tChild
   set the caseSensitive to true
   if pIndex > the number of elements of pPath then
      if pKind is "sequence" or pKind is "dictionary" then
         if pNode is an array then
            put pKind into pNode["kind"]
            if pKind is "sequence" then
               delete variable pNode["keys"]
            end if
            return pNode
         end if
         put pKind into tContainer["kind"]
         return tContainer
      end if
      if pKind is empty and pNode is an array then
         -- Guess this part again, but keep what is known about its parts.
         put empty into pNode["kind"]
         return pNode
      end if
      return pKind
   end if

   if pNode is not an array then
      put pNode into tKind
      put empty into pNode
      if tKind is "sequence" or tKind is "dictionary" then
         put tKind into pNode["kind"]
      else
         put empty into pNode["kind"]
      end if
   end if
   -- The key and the part are fetched into variables first, never written
   -- into the call: in this engine an expression written as an argument of
   -- a handler call is evaluated with the caseSensitive false, whatever the
   -- caller set, so jcSetKind(pNode["items"]["b"], ...) would read the part
   -- of "B". (Nowhere else here passes an array element to a handler.)
   put pPath[pIndex] into tKey
   put pNode["items"][tKey] into tChild
   put jcSetKind(tChild, pPath, pIndex + 1, pKind) into pNode["items"][tKey]
   return pNode
end jcSetKind
