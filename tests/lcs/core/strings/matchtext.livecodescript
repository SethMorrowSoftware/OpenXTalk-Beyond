script "CoreStringsMatchText"
-- Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
-- (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
-- Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

-- Bug 16: Ensure that very deeply recursive regular expressions do
-- not cause a stack overflow in libpcre
constant kRecursionExpr = "x(?R)?"
constant kRecursionLength = 16384

on TestMatchTextRecursion

   -- Build a suitably long string
   local tTarget
   put "x" into tTarget
   repeat
      if length(tTarget) >= kRecursionLength then
         delete char (1+kRecursionLength) to -1 of tTarget
         exit repeat
      end if
      put tTarget after tTarget
   end repeat

   get matchText(tTarget, kRecursionExpr)

end TestMatchTextRecursion

on TestMatchTextMultipleMatches
    local tFound
    repeat for each item tItem in "a1,b1,a2,a3,a4,a5,a0"
         get matchText(tItem, "a([0-9])", tFound)
   end repeat

   TestAssert "check that tFound is not empty", tFound is 0

   repeat for each item tItem in "c1,c2,c3,c4"
        get matchText(tItem, "a([0-9])", tFound)
   end repeat

   TestAssert "check that tFound is empty", tFound is 0
end TestMatchTextMultipleMatches

-- The pattern always matches case, whatever the caseSensitive, as in
-- LiveCode and as the dictionary says; "(?i)" makes it ignore case.
on TestMatchTextIgnoresCaseSensitive
   set the caseSensitive to false
   TestAssert "matchText matches case when the caseSensitive is false", \
         not matchText("Hello", "hello")
   TestAssert "matchText with (?i) ignores case", \
         matchText("Hello", "(?i)hello")

   set the caseSensitive to true
   TestAssert "matchText matches case when the caseSensitive is true", \
         not matchText("Hello", "hello")
   TestAssert "matchText with (?i) ignores case when the caseSensitive is true", \
         matchText("Hello", "(?i)hello")
end TestMatchTextIgnoresCaseSensitive

on TestReplaceTextIgnoresCaseSensitive
   set the caseSensitive to false
   TestAssert "replaceText matches case when the caseSensitive is false", \
         replaceText("Hello hello", "hello", "x") is "Hello x"
   TestAssert "replaceText with (?i) ignores case", \
         replaceText("Hello hello", "(?i)hello", "x") is "x x"

   set the caseSensitive to true
   TestAssert "replaceText matches case when the caseSensitive is true", \
         replaceText("Hello hello", "hello", "x") is "Hello x"
end TestReplaceTextIgnoresCaseSensitive
