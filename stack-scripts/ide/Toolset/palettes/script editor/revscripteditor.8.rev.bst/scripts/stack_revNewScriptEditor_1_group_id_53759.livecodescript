script "stack_revNewScriptEditor_1_group_id_53759"
-- Stack file: ide/Toolset/palettes/script editor/revscripteditor.8.rev
-- Object: stack "revNewScriptEditor" > substack "revNewScriptEditor 1" > card "Main" (id 1002) > group "Panes" (id 1050) > group "Search Results" (id 53759)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

command paneResizeControl
   set the rect of field 1 of me to the rect of me
end paneResizeControl

command update
   local tScroll
   put the vScroll of field 1 of me into tScroll
   
   local tHiliteColor
   put sePrefGet("editor,hiliteColor") into tHiliteColor
   set the hiliteColor of field 1 of me to tHiliteColor
   
   setResults sePrefGet("editor,lastsearchresults")
   paneResizeControl
   
   set the vScroll of field 1 of me to tScroll
end update

command paneOpenControl
   update
end paneOpenControl

command paneCloseControl
end paneCloseControl

# Parameters
#   pResultsString : A list of search results, one per line. Format described below
# Description
#   Displays the specified results. If pResultsString is empty then displays nothing.
#   Format of pResultsString is a list of search results, one per line, where each search result is in the following form:
#      <object long id> <line number> <start char> <end char> <matched text with context>
#       (all fields are separated by tabs).
#   pResultsString also contains a header, this makes up the first two lines of the string. Line 1 is the search term and line 2 is the search scope.
private command setResults pResultsString
   if pResultsString is empty then
      put empty into field 1 of me
      exit setResults
   end if
   
   local tHtml
   put "<p><b>Results for &quot;" & line 1 of pResultsString & "&quot;, searching: " & line 2 of pResultsString & "</b></p>" & return into tHtml
   
   set the itemDelimiter to tab
   
   local tResultNumber
   put 1 into tResultNumber
   
   -- OXT-Beyond: the object in grey and its line in near black on the
   -- light appearance, as before; on the dark one those were all but
   -- invisible on the dark pane, so they are light grey and near white
   local tObjectInk, tLineInk
   if revIDEAppearanceIsDark() then
      put "#AAAAAA" into tObjectInk
      put "#E6E6E6" into tLineInk
   else
      put "#505050" into tObjectInk
      put "#101010" into tLineInk
   end if
   
   local tResults
   repeat for each line tMatch in line 3 to -1 of pResultsString
      local tObjectString
      put formatObjectReference(item 1 of tMatch) into tObjectString
      
      # As the context may contains html characters if its a quoted string in the script,
      # we have to escape these to prevent the formatting of results getting messed up.
      local tContext
      put item 5 of tMatch into tContext
      
      replace "&" with "&amp;" in tContext
      replace "<" with "&lt;" in tContext
      # Strictly this should be done, but it may ommited for speed reasons.
      #replace ">" with "&gt;" in tContext
      
      put "<p><font color=" & quote & tObjectInk & quote & ">" & tObjectString & "(" & item 2 of tMatch &  "): " & "</font><font color=" & quote & tLineInk & quote & ">" & tContext & "</font></p>" & return after tHtml
      put tMatch & return after tResults
      add 1 to tResultNumber
   end repeat
   delete the last char of tResults
   
   put "<p>Total results found: " & tResultNumber - 1 & "</p>" after tHtml
   
   local tHilitedLine
   put the hilitedLine of field 1 of me into tHilitedLine
   
   local tOldText
   put the text of field 1 of me into tOldText
   
   set the htmlText of field 1 of me to tHtml
   set the cResults of field 1 of me to tResults
   
   if the text of field 1 of me is tOldText and tHilitedLine is not empty then
      set the hilitedLine of field 1 of me to tHilitedLine
   end if
end setResults

local sLastClickedLineNumber

on mouseUp
   local tLineNumber
   put word 2 of the clickLine into tLineNumber
   put tLineNumber into sLastClickedLineNumber
   
   # First line is a header and the last line is a summary, so ignore clicks on these.
   if tLineNumber = 1 or tLineNumber = (the number of lines of field 1 of me) then
      exit mouseUp
   end if
   
   # Take the header into account
   subtract 1 from tLineNumber
   
   local tMatch
   put line tLineNumber of the cResults of field 1 of me into tMatch
   
   set the itemDelimiter to tab
   local tStart, tEnd, tObject
   put item 1 of tMatch into tObject
   put item 3 of tMatch into tStart
   put item 4 of tMatch into tEnd
   
   # If the object is not being edited by the script editor, it should be added.
   local tCurrentObjects
   revSEGetTargetObjects
   put the result into tCurrentObjects
   
   if revRuggedId(tObject) is not among the lines of tCurrentObjects then
      revSEAddTargetObject tObject
   end if
   
   # Register for a callback to be sent when the object is finished loading,
   # this ables us to reselect the hilited line, which otherwise will be lost
   revSERegisterObjectCallback "objectLoadedCallback", the long id of me, tObject
   
   # It is possible that the user might have moved or deleted the match between
   # doing the search and clicking on the result. In this case we copy the visual studio
   # behavior by leaving the old search results here, and allowing the user to click on them
   # even though they won't work. We therefore encase the following two lines in a try block,
   # to prevent script editors appearing if the user has deleted the object.
   try
      revSESetCurrentObject tObject
      revSEMarkText tStart, tEnd
   end try
end mouseUp

command objectLoadedCallback pObject, pScriptEditor
   lock messages
   set the hilitedLine of field 1 of me to sLastClickedLineNumber
   unlock messages
end objectLoadedCallback

private function formatObjectReference pObject
   # Its possible that the user may have deleted the object since searching found it.
   # In this case, we can't resolve the long name, so instead just return what we know.
   local tObjectString
   if there is a pObject then
      put the long name of pObject into tObjectString
   else
      put pObject into tObjectString
   end if
   put quote & revTargetStack(pObject) & quote into word -1 of tObjectString
   return tObjectString
end formatObjectReference



