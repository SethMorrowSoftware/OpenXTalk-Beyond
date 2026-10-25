script "Matches"
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

-- HyperXTalk's "matches wildcard" and "matches regex" operators, added for
-- stacks written in HyperXTalk, and what stays as it was: "matches" is no
-- keyword, so variables, handlers and custom properties keep the name.

on TestMatchesWildcard
   TestAssert "* matches any run of characters", "hello" matches wildcard "h*o"
   TestAssert "? matches one character", "hello" matches wildcard "h?llo"
   TestAssert "a pattern that does not match", not ("hello" matches wildcard "h*x")
   TestAssert "the pattern must match the whole string", not ("hello world" matches wildcard "hello")
   TestAssert "a set of characters", "bat" matches wildcard "[a-c]at"
   TestAssert "a character outside the set", not ("rat" matches wildcard "[a-c]at")
   TestAssert "* matches empty", empty matches wildcard "*"
   TestAssert "empty matches empty", empty matches wildcard empty
   TestAssert "empty matches nothing else", not ("a" matches wildcard empty)
   TestAssert "wildcard pattern", "notes.txt" matches wildcard pattern "*.txt"
   TestAssert "a number is matched as text", 1234 matches wildcard "12*"
end TestMatchesWildcard

on TestMatchesWildcardCase
   -- as the caseSensitive says, as in the filter command
   set the caseSensitive to false
   TestAssert "ignores case when the caseSensitive is false", "Hello" matches wildcard "h*"
   set the caseSensitive to true
   TestAssert "matches case when the caseSensitive is true", not ("Hello" matches wildcard "h*")
   TestAssert "the same case matches when the caseSensitive is true", "Hello" matches wildcard "H*"
   set the caseSensitive to false
end TestMatchesWildcardCase

on TestMatchesWildcardAsFilter
   -- the filter command reads a wildcard pattern the same way
   local tLines, tPatterns, tFiltered, tLine, tSame, tCase, tPattern
   put "hello" & return & "Hello" & return & "help" & return & "a*b" & return & \
         "[x]" & return & "x" & return & "file.txt" & return & "file.txt.bak" into tLines
   put "h*" & return & "H*" & return & "*l?" & return & "a[*]b" & return & \
         "[[]x]" & return & "*.txt" & return & "?" & return & "*" into tPatterns
   put true into tSame
   repeat for each item tCase in "false,true"
      set the caseSensitive to tCase
      repeat for each line tPattern in tPatterns
         put tLines into tFiltered
         filter lines of tFiltered with tPattern
         repeat for each line tLine in tLines
            if (tLine matches wildcard tPattern) is not (tLine is among the lines of tFiltered) then
               TestDiagnostic "caseSensitive" && tCase & ":" && tLine && "with" && tPattern
               put false into tSame
            end if
         end repeat
      end repeat
   end repeat
   set the caseSensitive to false
   TestAssert "matches wildcard agrees with the filter command", tSame
end TestMatchesWildcardAsFilter

on TestMatchesRegex
   TestAssert "a regular expression", "abc" matches regex "^a.c$"
   TestAssert "a pattern that does not match", not ("abc" matches regex "^b")
   -- as in matchText: a match anywhere, unless ^ and $ say otherwise
   TestAssert "a match anywhere in the string", "xabcx" matches regex "abc"
   TestAssert "anchored", not ("xabcx" matches regex "^abc$")
   TestAssert "regex pattern", "2026-10-24" matches regex pattern "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
   TestAssert "agrees with matchText", ("a1b2" matches regex "[0-9]b") is matchText("a1b2", "[0-9]b")
end TestMatchesRegex

on TestMatchesRegexCase
   -- as in matchText: always case-sensitive, unless the pattern says (?i)
   set the caseSensitive to false
   TestAssert "matches case when the caseSensitive is false", not ("ABC" matches regex "abc")
   TestAssert "(?i) ignores case", "ABC" matches regex "(?i)abc"
   set the caseSensitive to true
   TestAssert "matches case when the caseSensitive is true", not ("ABC" matches regex "abc")
   set the caseSensitive to false
end TestMatchesRegexCase

on TestMatchesRegexBadPattern
   TestAssertThrow "a pattern that is not a regular expression throws, as in matchText", \
         "MatchBadPattern", the long id of me, "EE_MATCH_BADPATTERN"
end TestMatchesRegexBadPattern

on MatchBadPattern
   get "a" matches regex "("
end MatchBadPattern

on TestMatchesPrecedence
   -- it binds as "contains" does: after &, before "is", "and" and "or"
   TestAssert "& on the left comes first", "a" & "b" matches wildcard "ab"
   TestAssert "& on the right comes first", "ab" matches wildcard "a" & "b"
   TestAssert "and comes after", "x" matches wildcard "x" and "y" matches wildcard "y"
   TestAssert "or comes after", "x" matches wildcard "z" or "y" matches regex "y"
   TestAssert "is comes after", "x" matches wildcard "x" is true
   TestAssert "in brackets", not ("x" matches wildcard "y")
   TestAssert "beside contains", "abc" contains "b" and "abc" matches wildcard "a*"
end TestMatchesPrecedence

on TestMatchesInStatements
   local tName, tPattern, tResult
   put "notes.txt" into tName
   put "*.txt" into tPattern
   put tName matches wildcard tPattern into tResult
   TestAssert "put ... into", tResult is true
   if tName matches wildcard "*.txt" then
      TestAssert "in an if", true
   else
      TestAssert "in an if", false
   end if
   get tName matches regex "\.txt$"
   TestAssert "get", it is true
   TestAssert "in value()", value("tName matches wildcard tPattern") is true
   TestAssert "a function's parameter", matchesAsParameter(tName matches wildcard "*.doc") is false
end TestMatchesInStatements

private function matchesAsParameter pValue
   return pValue
end matchesAsParameter

-- What scripts saw before stays as it was

on TestMatchesIsStillAName
   local matches, wildcard, regex
   put "a variable" into matches
   TestAssert "a variable named matches", matches is "a variable"
   put matches && "too" into matches
   TestAssert "a variable named matches in an expression", matches is "a variable too"
   put "w" into wildcard
   put "r" into regex
   TestAssert "variables named wildcard and regex", wildcard & regex is "wr"
   TestAssert "matches wildcard with a variable named wildcard", "w" matches wildcard wildcard
end TestMatchesIsStillAName

on TestMatchesHandlers
   local wildcard
   TestAssert "a function named matches", matches(2, 3) is 5
   matches 4
   TestAssert "a command named matches", the result is 8
   -- at the start of a statement it is the command, whatever follows
   put 6 into wildcard
   matches wildcard
   TestAssert "a command named matches, with a variable named wildcard", the result is 12
end TestMatchesHandlers

function matches pLeft, pRight
   return pLeft + pRight
end matches

command matches pValue
   return pValue * 2
end matches

on TestMatchesCustomProperty
   local tName
   put "matches" into tName
   set the matches of me to "kept"
   TestAssert "a custom property named matches", the matches of me is "kept"
   TestAssert "the custom property is named matches", the tName of me is "kept"
   TestAssert "the custom property matches wildcard", the matches of me matches wildcard "k*"
end TestMatchesCustomProperty

on TestMatchesOldReadings
   -- A handler that compiles without the operator compiles as it did, as
   -- this one does: "get tText matches wildcard (3)" was "get tText", then
   -- a call of the command matches with the value of the function wildcard
   -- (both in this script), and "return" stopped before "matches"
   local tText, tResult
   put "abc" into tText
   get tText matches wildcard (3)
   put the result into tResult
   TestAssert "get, then a call of matches: it", it is "abc"
   TestAssert "get, then a call of matches: the result", tResult is 6
   TestAssert "return, then a call of matches", returnsBeforeMatches() is "abc"

   -- and so does a do script
   put empty into tResult
   do "get tText matches wildcard (3)"
   put the result into tResult
   TestAssert "in do, get, then a call of matches: it", it is "abc"
   TestAssert "in do, get, then a call of matches: the result", tResult is 6
end TestMatchesOldReadings

on TestMatchesInDo
   -- A do script that does not compile without the operator is read with
   -- it as if that were its first reading: a local it declares is no
   -- duplicate, and nothing is left of the reading without the operator,
   -- in which "get tText matches wildcard ..." made "wildcard" a variable
   -- of this handler
   local tNames
   do "local tText" & return & \
         "put" && quote & "notes.txt" & quote && "into tText" & return & \
         "get tText matches wildcard" && quote & "*.txt" & quote
   TestAssert "a do script that declares a local", it is true
   put the localNames into tNames
   replace return with comma in tNames
   TestDiagnostic tNames
   TestAssert "nothing is left of the reading without the operator", \
         "wildcard" is not among the items of tNames
end TestMatchesInDo

private function returnsBeforeMatches
   return "abc" matches wildcard (3)
end returnsBeforeMatches

function wildcard pValue
   return pValue
end wildcard

on TestMatchesErrorsAsBefore
   -- A handler that compiles neither way reports the error it reported
   -- before: where the reading without the operator failed, line 2 here,
   -- not line 3, where the reading with it fails
   local tStack, tError
   create invisible stack "MatchesErrorsAsBefore"
   put the long id of it into tStack
   set the script of tStack to "on probe" & return & \
         "get 1 matches wildcard 2" & return & \
         "put into" & return & \
         "end probe"
   put the result into tError
   delete stack "MatchesErrorsAsBefore"
   TestDiagnostic tError
   TestAssert "the error is where the first reading failed", item 2 of line 1 of tError is 2
end TestMatchesErrorsAsBefore
