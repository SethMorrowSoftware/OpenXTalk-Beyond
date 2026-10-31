script "stack_CustomScriptCol_graphic_id_1012"
-- Stack file: ide/Toolset/palettes/revpreferencesgui.rev
-- Object: stack "revPreferencesGUI" > substack "CustomScriptCol" > card (id 1002) > graphic "cSwatch" (id 1012)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseup
   local myColor,mySECols,tClickedLine,myNewSECols,myLine,sanityCheck,myTmpVar,sFilePath
   -- (isn't that ridiculous!)
   answer color with (the backgroundColor of me)
   put it into myColor
   if myColor is empty or myColor is cancel then exit mouseup
   --
   set the itemdelimiter to " "
   put the cClickedPart of graphic "cSwatch" into tClickedLine
   --
   put field "importantBits" of stack "CustomScriptCol" into myNewSECols
   delete line 1 to 3 of myNewSECols
   put myColor into last item of line tClickedLine of myNewSECols
   put line 1 to 3 of field "importantBits" of stack "CustomScriptCol" into myTmpVar
   put myTmpVar & return & myNewSECols into field "importantBits" of stack "CustomScriptCol"
   --
   put field "importantBits" of stack "CustomScriptCol" into myNewSECols
   if the platform contains "win" then
      put specialFolderPath(0x001a) & "/" & xtalk & "/Preferences/" into sFilePath
      create folder sFilePath
   end if
   if the platform contains "mac" then
      put specialFolderPath("Preferences") & "/" & xtalk & "/Preferences/" into sFilePath
      create folder sFilePath
   end if
   if the platform contains "lin" then
      put specialFolderPath("Home") & slash & ".runrev/" into sFilePath
      create folder sFilePath
      put specialFolderPath("Home") & slash & ".runrev/xtalk/" into sFilePath
      create folder sFilePath
      put specialFolderPath("Home") & slash & ".runrev/xtalk/Preferences" into sFilePath
      create folder sFilePath
   end if
   -- write the file
   -- reusing variables as I got fed up with having to keep declaring 'local'. Tiresome.
   if the number of words of line 2 of myNewSECols <3 then
      delete line 1 to 3 of myNewSECols
   end if
   put sFilePath & "customScriptColours.dat" into myTmpVar 
   delete file myTmpVar
   open file myTmpVar
   write myNewSECols to file myTmpVar
   close file myTmpVar
   --
   set the itemdelimiter to ","
   -- now make it 'stick' (hopefully!)
   defaultAll
   
   -- change the appearance of my clicked item
   set the backgroundColor of me to myColor
   put myColor into field "rgbValue" of stack "CustomScriptCol"
   set the textColor of line tClickedLine of field "iHateArrays" of stack "CustomScriptCol" to myColor
   send colourScript to button "update" of stack "CustomScriptCol"
   
end mouseup


on defaultAll
   revIDESetPreference "cScriptEditor," & "colorization,scheme", "Custom"
   -- OXT-Beyond: Custom shows in light and dark; drop the second, dark
   -- scheme early Beyond builds kept.
   revIDESetPreference "cScriptEditor,colorization,schemedark", empty
   updateOpenScriptEditors
end defaultAll
