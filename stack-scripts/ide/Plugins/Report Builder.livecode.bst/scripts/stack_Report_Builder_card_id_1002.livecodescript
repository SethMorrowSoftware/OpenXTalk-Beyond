script "stack_Report_Builder_card_id_1002"
-- Stack file: ide/Plugins/Report Builder.livecode
-- Object: stack "Report Builder" > card (id 1002)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

--in msg box: edit the script of stack "revPrintLibrary"  --copy revPrintField, revPrintText, and revPrintSetText handlers to modify for page break:

local lPageNumber, pageNumber --holds lPageNumber between handlers
local lAnswerPrinter = "false", lPageSetup = "false"  --false for page break
local numPages
constant kPo = "36"

on preopencard
   send openPreviewPane to this card in 40 milliseconds
end preopencard

on openPreviewPane
   open stack "Report" of stack "Report Builder"
   set the scaleFactor of stack "Report" to 1
   -- OXT-Beyond: or where the user's preferences keep it, when this stack
   -- could not be saved (an install for all users)
   if revIDEGetPreference("cOXTReportBuilderPosition") is not empty then
      set the topLeft of stack "Report" to revIDEGetPreference("cOXTReportBuilderPosition")
   else
      set the topLeft of stack "Report" to the cPosition of stack "Report"  --position, custom prop
   end if
end openPreviewPane


on revPrintField pFieldRef,pHeader,pFooter
   --pFieldRef contains a valid field descriptor
   --pHeader contains header text, either html or text
   --pFooter contains header text, either html or text
  revPrintText the htmlText of pFieldRef,pHeader,pFooter,the long id of pFieldRef
end revPrintField

on revPrintText pText,pHeader,pFooter,pSourceFieldRef,pHeaderFldRef,pFooterFldRef
   --pText contains the text, either html or text
   --pHeader contains header text, either html or text
   --pFooter contains header text, either html or text
   --pSourceFieldRef contains a vaild field descriptor
   local tActualPageWidth --width of page subtracting right and left printmargins
   local tPrintMargins --margins stored in array for script simplification
   local tPageWidth,tPageHeight --height and width of the page
   local tScrolling,tPageLine,tScrollList --scroll values for text height calculations
   lock messages
   --general initialization
   if the printPageNumber is empty then
      if lAnswerPrinter is empty then put "true" into lAnswerPrinter
      if lPageSetUp is empty then put "true" into lPageSetup
      if lPageSetup then answer page setup
      if the result is "Cancel" then return "cancel"
      if lAnswerPrinter then answer printer
      if the result is "Cancel" then return "cancel"
   end if
   open printing
   --setting up
   if pSourceFieldRef <> "" and pHeaderFldRef = "" then put pSourceFieldRef into pHeaderFldRef
   if pSourceFieldRef <> "" and pFooterFldRef = "" then put pSourceFieldRef into pFooterFldRef
   put item 1 of the printmargins into tPrintMargins["left"]
   put item 2 of the printmargins into tPrintMargins["top"]
   put item 3 of the printmargins into tPrintMargins["right"]
   put item 4 of the printmargins into tPrintMargins["bottom"]
   put item 3 of the printPaperRectangle - item 1 of the printPaperRectangle into tPageWidth
   put item 4 of the printPaperRectangle - item 2 of the printPaperRectangle into tPageHeight
   put "0" into tScrolling
   put "0" into tPageLine
   put "1" into lPageNumber
   put lPageNumber into pageNumber  --for <%pageNumber%>
   put tPageWidth - tPrintMargins["right"] - tPrintMargins["left"] into tActualPageWidth
   -- reset the stack & field templates (fixes wrapping bug where dontWrap of the templateField is set before calling)
   reset the templateStack
   reset the templateField
   -- prepare template for invisible stacks the width of the page
   set the backgroundColor of the templateStack to "white"
   if pSourceFieldRef is not empty then
      put revTargetStack(pSourceFieldRef) into tTargetStack
      set the underLineLinks of the templateStack to the underLineLinks of stack tTargetStack
      set the linkColor of the templateStack to the linkColor of stack tTargetStack
      set the linkHiliteColor of the templateStack to the linkHiliteColor of stack tTargetStack
      set the linkVisitedColor of the templateStack to the linkVisitedColor of stack tTargetStack
   end if
   set the visible of the templateStack to "false"
   set the width of the templateStack to tActualPageWidth
   --if the printerName is not "pdf" then  --original
   if "pdf" is not in the printerName then  --*forced page break update
      set the formatForPrinting of the templateStack to "false"
      set the formatForPrinting of the templateStack to "true"
   end if
   -- prepare template for fields in these stacks
   set the width of the templateField to tActualPageWidth
   -- the following three properties are set so that text height calculations are correct
   set the borderWidth of the templateField to "0"
   set the margins of the templateField to "6"
   set the showBorder of the templateField to "true"
   set the opaque of the templateField to "false"
   set the fixedLineHeight of the templateField to "false"
   set the lockLoc of the templateField to "true"
   -- header and footer initialization
   if pHeader is not empty then
      create stack "revTempHeader"
      set the defaultStack to "revTempHeader"
      set the backColor of this card to "white" -- work around 1955 unicode color issue
      revSetPrintFont pHeaderFldRef
      get revCreatePrintHeaderAndFooter(pHeader)
      -- if size of header or footer is greater then current margins will allow, then increase top or bottom margins.
      if it > tPrintMargins["top"] then put it into tPrintMargins["top"]
   end if
   if pFooter is not empty then
      create stack "revTempFooter"
      set the defaultStack to "revTempFooter"
      set the backColor of this card to "white" -- work around 1955 unicode color issue  *forced page break update
      revSetPrintFont pFooterFldRef
      get revCreatePrintHeaderAndFooter(pFooter)
      if it > tPrintMargins["bottom"] then put it into tPrintMargins["bottom"]
   end if
   --body initialization
   global gREVPrintFileName
   if gREVPrintFileName is empty or there is a stack gREVPrintFileName then put "revTempBody" into gREVPrintFileName
   create stack gREVPrintFileName
   set the defaultStack to gREVPrintFileName
   set the height of this stack to tPageHeight - tPrintMargins["bottom"] - tPrintMargins["top"]
   revSetPrintFont pSourceFieldRef
   create field
   if pSourceFieldRef is not empty then
      set the tabStops of fld 1 to the tabStops of pSourceFieldRef
      set the hGrid of fld 1 to the hGrid of pSourceFieldRef
      set the vGrid of fld 1 to the vGrid of pSourceFieldRef
      set the fixedLineHeight of fld 1 to the fixedLineHeight of pSourceFieldRef -- NEW
      set the textHeight of fld 1 to the effective textHeight of pSourceFieldRef -- NEW
      set the textAlign of fld 1 to the effective textAlign of pSourceFieldRef
      if version() >= "7.0" then set the tabAlign of fld 1 to the effective tabAlign of pSourceFieldRef --NEW
   end if
   set the rect of fld 1 to the rect of this card
   revPrintSetText pText  --convert <%expression%> to value(expression)
   
   ----*start forced page break update
   local tPgHeight, tTxtHeight, tRowsInPg, tSkipC="0", tBreakChar, tRanges, tPage, tRowsToBreak, tReturns, tCount
   put line 1 of the pageHeights of fld 1 into tPgHeight  --page height in pixels
   put the effective textHeight of fld 1 into tTxtHeight  --row height in pixels
   put trunc(tPgHeight / tTxtHeight) into tRowsInPg  --rows/page (not lines/page)
   repeat
      put offset(value(formfeed),fld 1,tSkipC) into tBreakChar  --break symbol char
      if tBreakChar = "0" then exit repeat  --escape, no break symbols
      add tBreakChar to tSkipC  --char search
      put the pageRanges of fld 1 into tRanges  --line list of page ranges: startChar,endChar
      repeat with i = 1 to number(lines in tRanges)
         if tSkipC <= item 2 of line i of tRanges then
            put i into tPage  --break symbol char on page i
            exit repeat
         end if
      end repeat
      set the vScroll of fld 1 to (tPgHeight * (tPage - 1))  --first break char on page
      select after char tSkipC of fld 1  --for selectedLoc(): vertical distance from top of stack to top of break char in pixels
      put trunc((item 2 of selectedLoc(fld 1) - the top of fld 1 + tTxtHeight) / tTxtHeight) into tRowsToBreak
      put tRowsInPg - tRowsToBreak into tReturns  --number of returns to force page break
      repeat tReturns
         put cr after tCount
      end repeat
      put tCount after char tSkipC of fld 1  --force page break
      put empty into tCount  --reset
      delete char tSkipC of fld 1  --break symbol
   end repeat
   ----*end forced page break update
   
   put the pageHeights of fld 1 into tScrollList
   --printing cycle
   -- headers and footers are split up into three fields by tab items
   set the itemDel to tab
   put the number of lines of tScrollList into numPages  --for <%numPages%>, only supported in header/footer
   --repeat  --original
   repeat numPages
      if pHeader is not empty then
         set the defaultStack to "revTempHeader"
         repeat with lLoop = 1 to 3
            put item lLoop of pHeader into fld lLoop
            if fld lLoop <> empty then revPrintSetText fld lLoop,lLoop
         end repeat
         print this card into tPrintMargins["left"],kPo,tPageWidth-tPrintMargins["right"],kPo+the height of stack "revTempHeader"
      end if
      if pFooter is not empty then
         set the defaultStack to "revTempFooter"
         repeat with lLoop = 1 to 3
            put item lLoop of pFooter into fld lLoop
            if fld lLoop <> empty then revPrintSetText fld lLoop,lLoop
         end repeat
         print this card into tPrintMargins["left"],tPageHeight-kPo-height of stack "revTempFooter",tPageWidth-tPrintMargins["right"],tPageHeight-kPo
      end if
      add 1 to tPageLine
      add 1 to lPageNumber
      put lPageNumber into pageNumber  --for <%pageNumber&>, only supported in header/footer
      set the defaultStack to gREVPrintFileName
      set the height of fld 1 to line tPageLine of tScrollList
      set the vScroll of fld 1 to tScrolling
      print this card into tPrintMargins["left"],tPrintMargins["top"],tPageWidth-tPrintMargins["right"],tPageHeight - tPrintMargins["bottom"]
      add line tPageLine of tScrollList to tScrolling  --reset
      if tPageLine = numPages then exit repeat
      print break
   end repeat
   --clean up
   close printing
   if there is a stack "revTempHeader" then delete stack "revTempHeader"
   if there is a stack "revTempFooter" then delete stack "revTempFooter"
   if there is a stack gREVPrintFileName then delete stack gREVPrintFileName  --page break update
   --delete stack gREVPrintFileName  --original
   reset the templateStack
   reset the templateField
end revPrintText

on revPrintSetText pTheText, pFldNum
  local tExpressionStart, tExpressionEnd
  if pFldNum = "" then put "1" into pFldNum
  if "<p>" is in pTheText or matchChunk(pTheText, "<(.+>.+</.+)>") is "true" then set the htmlText of fld pFldNum to pTheText
  else put pTheText into fld pFldNum
  repeat until matchChunk(fld pFldNum, "<%(.[^<]*)%>", tExpressionStart, tExpressionEnd) is "false"
    put value(char tExpressionStart to tExpressionEnd of fld pFldNum) into char tExpressionStart-2 to tExpressionEnd+2 of fld pFldNum
  end repeat
end revPrintSetText
