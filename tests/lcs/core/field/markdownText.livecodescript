script "CoreFieldMarkdownText"
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

-- The markdownText of a field, from HyperXTalk (#448). "markdownText" is
-- no word of the language here: it is a field's Markdown only when the
-- field holds no custom property of that name (and uses its default custom
-- property set), so a stack that kept a custom property "markdownText"
-- keeps it, and every other object's custom property of that name is what
-- it was (engine/src/chunk.cpp, MCChunk::getsetmarkdowntext). Before, the
-- markdownText of a field with no such custom property was empty, and
-- setting it made one: that is the one change, listed in the pull request.

on TestSetup
   create field "md"
end TestSetup

on TestTeardown
   if there is a field "md" then delete field "md"
   if there is a button "md" then delete button "md"
end TestTeardown

--------------------------------------------------------------------------------
-- What scripts that kept a custom property "markdownText" see, as before

on TestCustomPropertyOfAFieldKept
   put "plain words" into field "md"
   -- a field of an older stack, that kept a custom property of that name
   set the customKeys of field "md" to "markdownText"
   set the markdownText of field "md" to "**kept**"
   TestAssert "a field with the custom property keeps it", the markdownText of field "md" is "**kept**"
   TestAssert "and its text is left", field "md" is "plain words"
   local tProps
   put the customProperties of field "md" into tProps
   TestAssert "the custom property holds the value", tProps["markdownText"] is "**kept**"
   TestAssert "in any case", the MARKDOWNTEXT of field "md" is "**kept**"
   set the markdowntext of field "md" to empty
   TestAssert "set to empty, it is still a custom property", "markdownText" is among the lines of the customKeys of field "md" and field "md" is "plain words"
end TestCustomPropertyOfAFieldKept

on TestCustomPropertyOfOtherObjects
   create button "md"
   set the markdownText of button "md" to "# not markdown"
   TestAssert "a button's is a custom property", the markdownText of button "md" is "# not markdown"
   TestAssert "in its custom keys", "markdownText" is among the lines of the customKeys of button "md"
   set the markdownText of this card to "card value"
   TestAssert "a card's is a custom property", the markdownText of this card is "card value"
   set the customKeys of this card to empty
end TestCustomPropertyOfOtherObjects

on TestCustomPropertySetsLeft
   put "text" into field "md"
   set the markdownText["a"] of field "md" to "indexed"
   TestAssert "an index names a custom property set", the markdownText["a"] of field "md" is "indexed"
   TestAssert "the field's text is left", field "md" is "text"
   set the customPropertySet of field "md" to "other"
   set the markdownText of field "md" to "in another set"
   TestAssert "another custom property set in use: a custom property", the markdownText of field "md" is "in another set"
   TestAssert "the field's text is left there too", field "md" is "text"
   set the customPropertySet of field "md" to empty
end TestCustomPropertySetsLeft

on TestVariableNamedMarkdownText
   local markdownText
   put "a variable" into markdownText
   TestAssert "a variable of that name", markdownText is "a variable"
end TestVariableNamedMarkdownText

on TestHandlersStillTakeIt
   set the script of field "md" to "getProp markdownText" & return & \
         "return " & quote & "from the handler" & quote & return & "end markdownText" & return & \
         "setProp markdownText pValue" & return & \
         "set the cSeen of me to pValue" & return & "end markdownText"
   put "text" into field "md"
   TestAssert "getProp is sent", the markdownText of field "md" is "from the handler"
   set the markdownText of field "md" to "**new**"
   TestAssert "setProp is sent", the cSeen of field "md" is "**new**"
   TestAssert "and the handler kept it, so the text is left", field "md" is "text"
   TestAssert "no custom property was made", "markdownText" is not among the lines of the customKeys of field "md"
end TestHandlersStillTakeIt

on TestHandlerThatPasses
   set the script of field "md" to "setProp markdownText pValue" & return & \
         "set the cSeen of me to pValue" & return & "pass markdownText" & return & "end markdownText" & return & \
         "getProp markdownText" & return & "pass markdownText" & return & "end markdownText"
   set the markdownText of field "md" to "**passed**"
   TestAssert "the handler ran", the cSeen of field "md" is "**passed**"
   TestAssert "passed, the field is filled", field "md" is "passed"
   TestAssert "a getProp that passes gives the Markdown", the markdownText of field "md" is "**passed**" & return
end TestHandlerThatPasses

on TestOwnHandlerReadsTheMarkdown
   set the script of field "md" to "getProp markdownText" & return & \
         "return " & quote & "[" & quote & " & the markdownText of me & " & quote & "]" & quote & return & \
         "end markdownText"
   put "x" into field "md"
   TestAssert "inside its own getProp, the field's Markdown", the markdownText of field "md" is "[x" & return & "]"
end TestOwnHandlerReadsTheMarkdown

on TestChunkOfAButtonStops
   create button "md"
   TestAssertThrow "a chunk of a button has no markdownText", "__ChunkOfButton", the long id of me, "EE_CHUNK_NOPROP"
end TestChunkOfAButtonStops

on __ChunkOfButton
   get the markdownText of line 1 of button "md"
end __ChunkOfButton

on TestChunkOfAFieldWithTheCustomPropertyStops
   set the customKeys of field "md" to "markdownText"
   put "a" & return & "b" into field "md"
   TestAssertThrow "a field that keeps the custom property: a chunk stops as before", "__ChunkOfField", the long id of me, "EE_CHUNK_NOPROP"
   TestAssert "and the text is left", field "md" is "a" & return & "b"
end TestChunkOfAFieldWithTheCustomPropertyStops

on __ChunkOfField
   set the markdownText of line 2 of field "md" to "**x**"
end __ChunkOfField

--------------------------------------------------------------------------------
-- The Markdown

on TestPlainText
   put "Hello world" into field "md"
   TestAssert "plain text", the markdownText of field "md" is "Hello world" & return
   set the markdownText of field "md" to "Hello world"
   TestAssert "set back", field "md" is "Hello world"
   TestAssert "no custom property is made", the customKeys of field "md" is empty
end TestPlainText

on TestEmpty
   put "x" into field "md"
   set the markdownText of field "md" to empty
   TestAssert "empty empties the field", field "md" is empty
   TestAssert "an empty field's markdownText is one empty paragraph", the markdownText of field "md" is return
end TestEmpty

on TestHeadings
   set the markdownText of field "md" to "# Title" & return & "## Sub" & return & "body"
   TestAssert "the text, a line each", field "md" is "Title" & return & "Sub" & return & "body"
   TestAssert "level 1 is 34 point", the textSize of line 1 of field "md" is 34
   TestAssert "and bold", the textStyle of line 1 of field "md" is "bold"
   TestAssert "level 2 is 24 point", the textSize of line 2 of field "md" is 24
   TestAssert "body is plain", the textSize of line 3 of field "md" is empty
   TestAssert "back to Markdown", line 1 of the markdownText of field "md" is "# Title"
   TestAssert "the second heading", line 3 of the markdownText of field "md" is "## Sub"
end TestHeadings

on TestSetextHeadings
   set the markdownText of field "md" to "Title" & return & "=====" & return & return & "Sub" & return & "---"
   TestAssert "two lines", field "md" is "Title" & return & "Sub"
   TestAssert "= is level 1", the textSize of line 1 of field "md" is 34
   TestAssert "- is level 2", the textSize of line 2 of field "md" is 24
end TestSetextHeadings

on TestEmphasis
   set the markdownText of field "md" to "**bold** *italic* ***both*** `code`"
   TestAssert "the text", field "md" is "bold italic both code"
   TestAssert "bold", the textStyle of word 1 of field "md" is "bold"
   TestAssert "italic, at the plain weight", the textStyle of word 2 of field "md" is "italic"
   TestAssert "both", the textStyle of word 3 of field "md" is "bold,italic"
   TestAssert "code in Courier", the textFont of word 4 of field "md" is "Courier"
   TestAssert "round trip", line 1 of the markdownText of field "md" is "**bold** *italic* ***both*** `code`"
end TestEmphasis

on TestLinks
   set the markdownText of field "md" to "see [the site](https://example.org/a) here"
   TestAssert "the link's text", field "md" is "see the site here"
   TestAssert "its linkText", the linkText of word 2 to 3 of field "md" is "https://example.org/a"
   TestAssert "round trip", line 1 of the markdownText of field "md" is "see [the site](https://example.org/a) here"
end TestLinks

on TestLists
   set the markdownText of field "md" to "- one" & return & "- two" & return & return & "1. first" & return & "2. second"
   TestAssert "the text", field "md" is "one" & return & "two" & return & "first" & return & "second"
   TestAssert "a bullet list", the listStyle of line 1 of field "md" is "disc"
   TestAssert "a numbered list", the listStyle of line 3 of field "md" is "decimal"
   TestAssert "back to Markdown", line 1 of the markdownText of field "md" is "- one"
end TestLists

on TestListNumbersGoOn
   -- an item after one with a listIndex goes on from it, as the field shows
   local tMarkdown
   put "a" & return & "b" & return & "c" into field "md"
   set the listStyle of line 1 to 3 of field "md" to "decimal"
   set the listIndex of line 1 of field "md" to 5
   put the markdownText of field "md" into tMarkdown
   filter tMarkdown without empty
   TestAssert "numbered as shown", tMarkdown is "5. a" & return & "6. b" & return & "7. c"
   set the markdownText of field "md" to the markdownText of field "md"
   put the markdownText of field "md" into tMarkdown
   filter tMarkdown without empty
   TestAssert "and the same after a round trip", tMarkdown is "5. a" & return & "6. b" & return & "7. c"
   TestAssert "a list after it", the listStyle of line 3 of field "md" is "decimal"
end TestListNumbersGoOn

on TestQuoteAndCode
   set the markdownText of field "md" to "> quoted" & return & return & "```" & return & "if x then *y*" & return & "```"
   TestAssert "the text", field "md" is "quoted" & return & "if x then *y*"
   TestAssert "a quote is indented", the leftIndent of line 1 of field "md" is 30
   TestAssert "code is Courier, with no markup read", the textFont of line 2 of field "md" is "Courier"
end TestQuoteAndCode

on TestCodeAsItIs
   set the markdownText of field "md" to "```" & return & "a *b*" & return & return & "c" & return & "```"
   TestAssert "code keeps its stars and its empty line", field "md" is "a *b*" & return & return & "c"
   TestAssert "in Courier", the textFont of line 1 of field "md" is "Courier" and the textFont of line 3 of field "md" is "Courier"
   set the markdownText of field "md" to "    x _y_"
   TestAssert "an indented line is code too", field "md" is "x _y_" and the textFont of line 1 of field "md" is "Courier"
end TestCodeAsItIs

on TestCodeWithBackticks
   -- code that holds backticks comes back as it was
   local tCases
   put "a ` b" & return & "``x" & return & "x`" & return & "```" & return & "`" & return & "  two  " into tCases
   repeat for each line tCode in tCases
      put tCode into field "md"
      set the textFont of char 1 to -1 of field "md" to "Courier"
      set the markdownText of field "md" to the markdownText of field "md"
      TestAssert "the same code:" && tCode, field "md" is tCode
      TestAssert "still Courier:" && tCode, the textFont of char 1 to -1 of field "md" is "Courier"
   end repeat
   set the markdownText of field "md" to "`a``b`"
   TestAssert "a span closes on a run of its own length", field "md" is "a``b"
end TestCodeWithBackticks

on TestCodeBlock
   -- lines of code in a row are one fenced block, with their empty lines,
   -- so the field comes back as it was (each was a code span, with a blank
   -- line after it, and the empty line was lost)
   local tMarkdown
   put "```" & return & "a *b*" & return & return & "  c" & return & "```" & return into tMarkdown
   set the markdownText of field "md" to tMarkdown
   TestAssert "written as the block it was", the markdownText of field "md" is tMarkdown
   set the markdownText of field "md" to the markdownText of field "md"
   TestAssert "the same text", field "md" is "a *b*" & return & return & "  c"
   TestAssert "the code in Courier", the textFont of line 1 of field "md" is "Courier" and the textFont of line 3 of field "md" is "Courier"

   -- lines a script put in Courier, between other text
   put "Before" & return & "if x then" & return & return & "   put 1" & return & "after" into field "md"
   set the textFont of line 2 to 4 of field "md" to "Courier"
   TestAssert "one block between two paragraphs", the markdownText of field "md" is \
         "Before" & return & return & "```" & return & "if x then" & return & return & "   put 1" & return & "```" & return & return & "after" & return
   set the markdownText of field "md" to the markdownText of field "md"
   TestAssert "and back", field "md" is "Before" & return & "if x then" & return & return & "   put 1" & return & "after"
   TestAssert "Courier again", the textFont of line 4 of field "md" is "Courier" and the textFont of line 5 of field "md" is not "Courier"
end TestCodeBlock

on TestCodeBlockFence
   -- the fence is longer than the backticks a line of the code starts with
   put "```" & return & "````x" into field "md"
   set the textFont of line 1 to 2 of field "md" to "Courier"
   TestAssert "five backticks", line 1 of the markdownText of field "md" is "`````"
   set the markdownText of field "md" to the markdownText of field "md"
   TestAssert "the same code", field "md" is "```" & return & "````x"
end TestCodeBlockFence

on TestOneLineOfCodeIsASpan
   put "put x" & return & "text" into field "md"
   set the textFont of line 1 of field "md" to "Courier"
   TestAssert "one line of code stays a code span", line 1 of the markdownText of field "md" is "`put x`"
   -- an empty line before or after code is not code
   put "a" & return & return & "b" into field "md"
   set the textFont of line 1 of field "md" to "Courier"
   TestAssert "an empty line after one line of code", the markdownText of field "md" is "`a`" & return & return & return & return & "b" & return
end TestOneLineOfCodeIsASpan

on TestListItemsLineByLine
   -- the items of a list follow one another line by line, as the field
   -- shows them (each had a blank line after it, which Markdown shows as
   -- a list with space between its items)
   local tMarkdown
   put "- one" & return & "- two" & return & return & "1. first" & return & "2. second" & return & return & "after" & return into tMarkdown
   set the markdownText of field "md" to tMarkdown
   TestAssert "a list's items, line by line", the markdownText of field "md" is tMarkdown
   set the markdownText of field "md" to the markdownText of field "md"
   TestAssert "the same text", field "md" is "one" & return & "two" & return & "first" & return & "second" & return & "after"
   TestAssert "the same lists", the listStyle of line 2 of field "md" is "disc" and the listStyle of line 3 of field "md" is "decimal"
   TestAssert "and a paragraph after them", the listStyle of line 5 of field "md" is empty
end TestListItemsLineByLine

on TestEscapes
   set the markdownText of field "md" to "\*not italic\* and 2 \* 3"
   TestAssert "escaped stars are stars", field "md" is "*not italic* and 2 * 3"
   TestAssert "and no style", the textStyle of line 1 of field "md" is empty
end TestEscapes

on TestEscapedStarInEmphasis
   -- an escaped star closes no span: italic "a*b" comes back as it was
   put "a*b c" into field "md"
   set the textStyle of char 1 to 3 of field "md" to "italic"
   TestAssert "written with the star escaped", line 1 of the markdownText of field "md" is "*a\*b* c"
   set the markdownText of field "md" to the markdownText of field "md"
   TestAssert "the same text", field "md" is "a*b c"
   TestAssert "italic to the end of the word", the textStyle of char 1 to 3 of field "md" is "italic"
   TestAssert "and plain after it", the textStyle of char 5 of field "md" is empty
   set the markdownText of field "md" to "*x \* y* z"
   TestAssert "read the same way", field "md" is "x * y z" and the textStyle of char 1 to 5 of field "md" is "italic"
end TestEscapedStarInEmphasis

on TestCodeInEmphasis
   -- a code span is read whole before emphasis around it is closed
   set the markdownText of field "md" to "*`a*b` c* d"
   TestAssert "the text", field "md" is "a*b c d"
   TestAssert "the code in Courier", the textFont of char 1 to 3 of field "md" is "Courier"
   TestAssert "italic to the closing star", the textStyle of char 1 to 5 of field "md" is "italic"
   TestAssert "and plain after it", the textStyle of char 7 of field "md" is empty
end TestCodeInEmphasis

on TestPlainTextComesBackPlain
   -- what would start a block at the start of a line is escaped
   local tLines
   put "1. not a list" & return & "# not a heading" & return & "> not a quote" & return & \
         "- not a bullet" & return & "---" & return & "~~~" & return & "+ plus" & return & \
         "a * b _c_ [d](e)" into tLines
   put tLines into field "md"
   set the markdownText of field "md" to the markdownText of field "md"
   TestAssert "the same text", field "md" is tLines
   TestAssert "with no list", the listStyle of line 1 of field "md" is empty
   TestAssert "no heading", the textSize of line 2 of field "md" is empty
   TestAssert "no quote", the leftIndent of line 3 of field "md" is empty or the leftIndent of line 3 of field "md" is 0
end TestPlainTextComesBackPlain

on TestStyledTextRoundTrip
   put "one two three" into field "md"
   set the textStyle of word 1 of field "md" to "bold"
   set the textStyle of word 3 of field "md" to "italic"
   set the markdownText of field "md" to the markdownText of field "md"
   TestAssert "the text", field "md" is "one two three"
   TestAssert "bold kept", the textStyle of word 1 of field "md" is "bold"
   TestAssert "plain kept", the textStyle of word 2 of field "md" is empty
   TestAssert "italic kept", the textStyle of word 3 of field "md" is "italic"
end TestStyledTextRoundTrip

on TestUnicode
   local tText
   put "caf" & numToCodepoint(233) & " " & numToCodepoint(8211) & " " & numToCodepoint(8220) & "quoted" & numToCodepoint(8221) into tText
   set the markdownText of field "md" to "**" & tText & "**"
   TestAssert "not read as bytes of another encoding", field "md" is tText
   TestAssert "bold", the textStyle of char 1 to -1 of field "md" is "bold"
   set the markdownText of field "md" to the markdownText of field "md"
   TestAssert "round trip", field "md" is tText
end TestUnicode

on TestNoHangOrCrash
   -- (HyperXTalk's importer looped for ever on a backslash that escapes
   -- nothing, and read before the line for a heading with no text)
   set the markdownText of field "md" to "C:\Users\me\"
   TestAssert "a backslash that escapes nothing is kept", field "md" is "C:\Users\me\"
   set the markdownText of field "md" to "# "
   TestAssert "a heading with no text", field "md" is empty
   set the markdownText of field "md" to "#" & return & "####### seven"
   TestAssert "not headings", field "md" is "#" & return & "####### seven"
   set the markdownText of field "md" to "[unclosed" & return & "**unclosed" & return & "`unclosed"
   TestAssert "unclosed markup is text", field "md" is "[unclosed" & return & "**unclosed" & return & "`unclosed"
end TestNoHangOrCrash

on TestHeadingKeepsItsHash
   set the markdownText of field "md" to "# C#"
   TestAssert "a hash sign with no space before it is text", field "md" is "C#"
   set the markdownText of field "md" to "# Title ##"
   TestAssert "a closing run is dropped", field "md" is "Title"
end TestHeadingKeepsItsHash

on TestChunks
   put "first" & return & "second" & return & "third" into field "md"
   set the markdownText of line 2 of field "md" to "**bold**"
   TestAssert "the chunk is replaced", field "md" is "first" & return & "bold" & return & "third"
   TestAssert "and styled", the textStyle of line 2 of field "md" is "bold"
   TestAssert "the rest is left", the textStyle of line 1 of field "md" is empty and the textStyle of line 3 of field "md" is empty
   TestAssert "a chunk's markdownText", the markdownText of line 2 of field "md" is "**bold**" & return
   TestAssert "a chunk sets no custom property", the customKeys of field "md" is empty
end TestChunks

on TestCustomPropertyRemovedGivesMarkdown
   set the customKeys of field "md" to "markdownText"
   put "x" into field "md"
   TestAssert "with the custom property: empty", the markdownText of field "md" is empty
   set the customKeys of field "md" to empty
   TestAssert "without it: the Markdown", the markdownText of field "md" is "x" & return
end TestCustomPropertyRemovedGivesMarkdown
