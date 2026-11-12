script "stack_revPreferencesGUI_field_id_1475"
-- Stack file: ide/Toolset/palettes/revpreferencesgui.rev
-- Object: stack "revPreferencesGUI" > card "Debug Properties" (id 1473) > group "propgroup" (id 1474) > field "fPREFFS" (id 1475)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

global tDebugOut

on scrollBarDrag
   if not (the pendingMessages contains "tupdvis") then
      --send tupdvis to me in 1 millisecond
   end if
   pass scrollBarDrag
end scrollBarDrag

on tupdvis
   lock screen
   set the textcolor of fld "fPREFFS" to ""
   put the VScroll of cd fld "fPREFFS" / the textHeight of cd fld "fPREFFS" into tsval
   put round(tsval, 0) into tsval
   if tsval <1 then put 1 into tsval -- this is my top line
   put the height of cd fld "fPREFFS"/ the textHeight of cd fld "fPREFFS" into testlines
   put round(testlines, 0) into testlines
   
   -- this is what we think the user can currently see
   put tsval into tLineFrom
   put (tsval + testlines) into tLineTo
   get fFormatCols(tLineFrom,tLineTo) -- do the first part (so what the user can see is coloured)
   put "done third part: " & the milliseconds into line 3 of tDebugOut
   unlock screen
   
   send tupdTheRest(tLineTo,tTotalLines) to me in 5 ticks
end tupdvis

function tupdTheRest tLineTo,tTotalLines
   put the number of lines of cd fld "fPREFFS" into tTotalLines if tLineTo < tTotalLines then -- we have colouring left to do
      lock screen
      get fFormatCols(tLineTo,tTotalLines) -- do the second part (colourise what the user can't see) 
      unlock screen
   end if
   put "done fourth part: " & the milliseconds into line 4 of tDebugOut
   put the last word of line 2 of tDebugOut - the last word of line 1 of tDebugOut into tTime1
   put the last word of line 3 of tDebugOut - the last word of line 2 of tDebugOut into tTime2
   put the last word of line 4 of tDebugOut - the last word of line 3 of tDebugOut into tTime3
   
   delete line 1 to 4 of tDebugOut -- unless you want to show my workings-out
   /*
   -- uncomment if you want to see how long it took
   put "Fetching the array data took: " & tTime1  & " milliseconds (" & tTime1 /1000 & " sec)" & return &¬
   "Colouring the field data (visible) took: " &  tTime2  & " milliseconds (" & tTime2 /1000 & " sec)" & return &¬
   "Colouring the rest of the field data took: " &  tTime3  & " milliseconds (" & tTime3 /1000 & " sec)"
   */
end tupdTheRest

function fFormatCols tLineFrom,tLineTo
   -- put "0,75,255" into tBlueColour -- not using default blue anymore
   set the textstyle of field "fPREFFS" to plain
   if tLineFrom is "" then exit fFormatCols
   --if there is a cd fld "debug" then put tLineFrom & "," & tLineTo into cd fld "debug"
   put tLineFrom into tcount
   put 0 into cCount
   repeat tLineTo
      put line tcount of cd fld "fPREFFS" into tString
      if tString contains "[" then
         if tString contains "]" then
            -- we have both [  ]
            -- look for char [
            put 0 into cCount
            repeat the number of chars in tString
               add 1 to cCount
               if char cCount of tString is "[" then
                  put cCount into tFromCharNum
                  exit repeat
               end if
            end repeat
            -- look for char ]
            put 0 into cCount
            repeat the number of chars in tString
               add 1 to cCount
               if char cCount of tString is "]" then
                  put cCount into tToCharNum
                  exit repeat
               end if
            end repeat
            -- put  tFromCharNum & " to " & tToCharNum
            -- OXT-Beyond: on the IDE's selection blue, in the colour the IDE gives a row's words on it
            -- (revIDEHilitedTextColor; dataView_TextHiliteColor is the accentColor, blue on that blue)
            set the backgroundColor of char tFromCharNum to tToCharNum of line tcount of cd fld "fPREFFS" to revIDEColor("dataView_hiliteColor")
            set the foregroundColor of char tFromCharNum to tToCharNum of line tcount of cd fld "fPREFFS" to revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor"))
            set the textstyle of char tFromCharNum to tToCharNum of line tcount of cd fld "fPREFFS" to bold
            set the textSize of char tFromCharNum to tToCharNum of line tcount of cd fld "fPREFFS" to 16
         end if
      end if
      add 1 to tcount
   end repeat
   return cCount
end fFormatCols
