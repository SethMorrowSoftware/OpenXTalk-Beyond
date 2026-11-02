script "OXTExampleLearnRuntime"
-- OXT-Beyond: the lessons of a "Learn <extension>" example, the stacks
-- that teach the xTalk Suite extensions OXT-Beyond has built in.
--
-- This is the script of the group "Learn", a background on every lesson
-- card and on the Reference card of such a stack (builder.livecodescript,
-- exLearnKit, makes it; tools/examples/README.md says how the stacks are
-- built). The window around it is the remasters' (frame-runtime). A card's
-- custom property cLearn says which half of the group it shows:
--
--    lesson     "In plain words" (the field "lessonWords"), the calls the
--               lesson's script makes (the field "lessonCalls": a click on
--               one opens its page of the reference over the script), the
--               script itself in the code panel (the field "lessonScript",
--               which the user can edit), with Run, Copy and Reset, and the
--               field "Result", where the script shows what it did
--    reference  every handler of the extension, in a list with a search
--               box; a click on one shows its page beside the list
--
-- Run gives the script in the code panel to the button "lessonTry" and
-- sends it mouseUp, as a click on a button of yours does, so a script
-- copied from here works the same in a button of your own stack: it shows
-- what it did in a field "Result". A script that does not compile, or
-- stops with an error, says where in the field "Result", in red.
--
-- What the reference says of each handler is the stack's custom property
-- cDocsZ: an array by the handler's name in lower case of its page, as
-- htmlText, made by the build from the IDE's Dictionary, arrayEncoded and
-- compressed (learnDocs gives it back). A name in a page
-- written as a link opens that name's page; a link that begins with "card:"
-- goes to that card.

-- The code font, found once ("-" for none)
local sFont
-- True while Run runs a script, so that a mouseUp the script does not
-- handle (it reaches this group from the button "lessonTry") is not a click
local sRunning
-- The Copy button's label while it says "Copied", and the reference list's
-- names, a line each, as the list shows them
local sCopyLabel, sRefNames
-- The name whose page the Reference card shows
local sRefShown
-- The pages of the reference, from the stack's cDocsZ, the stack they
-- are of, and whether they are in the dark page's colours
local sDocs, sDocsOf, sDocsDark
-- Whether the page is dark, as the window has it (frame-runtime's
-- frameLook): the IDE says
local sDark

-- The pages of the reference (see above)
function learnDocs
   local tKey
   if sDocsOf is not the long id of this stack or sDocsDark is not sDark then
      put arrayDecode(decompress(the cDocsZ of this stack)) into sDocs
      put the long id of this stack into sDocsOf
      put sDark into sDocsDark
      -- (the accent as the build wrote it is too dark to read on the dark page)
      if sDark then
         repeat for each key tKey in sDocs
            replace the cInk of this stack with the cInkDark of this stack in sDocs[tKey]
         end repeat
      end if
   end if
   return sDocs
end learnDocs

-- Light or dark, as frame-runtime's frameLook reads it, and the links in
-- the accent of that look
private command learnLook
   local tError, tInk
   put false into sDark
   try
      if revIDEAppearanceIsDark() is true then
         put true into sDark
      end if
   catch tError
      -- (no IDE: light)
   end try
   if sDark then
      put the cInkDark of this stack into tInk
   else
      put the cInk of this stack into tInk
   end if
   set the linkColor of this stack to tInk
   set the linkVisitedColor of this stack to tInk
   set the linkHiliteColor of this stack to tInk
end learnLook

on preOpenCard
   learnLayout
   pass preOpenCard
end preOpenCard

-- Shows the half of the group this card has, with the reference sheet shut
command learnLayout
   learnLook
   if sFont is empty then
      put learnCodeFont() into sFont
      if sFont is not "-" then
         set the textFont of field "lessonScript" of me to sFont
         set the textFont of field "Result" of me to sFont
         set the textFont of field "sheetText" of me to empty
      end if
   end if
   lock screen
   if the cLearn of this card is "front" then
      hide group "lessonPart" of me
      hide group "refPart" of me
      show group "frontPart" of me
      learnStatus
   else if the cLearn of this card is "reference" then
      hide group "lessonPart" of me
      hide group "frontPart" of me
      show group "refPart" of me
      refFill
   else
      hide group "frontPart" of me
      hide group "refPart" of me
      show group "lessonPart" of me
      hide group "refPart" of me
      learnSheet false
      -- (the script in colour, as Reset or the build left it, unless the
      -- user is typing in it)
      if the selectedField is not the long id of field "lessonScript" of me then
         learnPaint
      end if
   end if
   unlock screen
end learnLayout

-- The extension's version, from the stack's cProbe (an expression such
-- as "sxVersion()"), or empty if it is not loaded
function learnVersion
   local tVersion, tError
   try
      put value(the cProbe of this stack) into tVersion
   catch tError
      put empty into tVersion
   end try
   return tVersion
end learnVersion

-- The front page says whether the lessons can run
command learnStatus
   local tVersion
   put learnVersion() into tVersion
   if tVersion is not empty then
      put tVersion && "is loaded: every lesson's script runs for real." into field "learnStatus" of me
   else
      put the cExtension of this stack && "is not loaded, so the scripts cannot run. " & \
            "See Tools > Extension Manager." into field "learnStatus" of me
   end if
end learnStatus

################################################################################
#
# Clicks
#

on mouseUp pButton
   local tObj, tDo, tWord
   if sRunning then
      exit mouseUp
   end if
   if pButton is not 1 then
      pass mouseUp
   end if
   put the long id of the target into tObj
   -- A call named in the list, or a link in a page of the reference
   if word 1 of tObj is "field" and the short name of tObj is among the items of "lessonCalls,sheetText,refText" then
      put learnLinkAt(tObj) into tWord
      if tWord is not empty then
         learnFollow tWord, the short name of tObj
      end if
      exit mouseUp
   end if
   if word 1 of tObj is "field" and the short name of tObj is "refList" then
      refChoose word 2 of the clickLine
      exit mouseUp
   end if
   -- A button: its group says what it does
   put learnDoOf(tObj) into tDo
   switch tDo
      case "run"
         learnRun
         break
      case "copy"
         learnCopy
         break
      case "reset"
         learnReset
         break
      case "back"
         learnSheet false
         break
      default
         pass mouseUp
   end switch
end mouseUp

-- What a click on pObj does: the custom property cLearnDo of the group of
-- a button it is in
private function learnDoOf pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if word 1 of tObj is "group" and the cLearnDo of tObj is not empty then
         return the cLearnDo of tObj
      end if
      put the long owner of tObj into tObj
   end repeat
   return empty
end learnDoOf

-- The name the click was on, in a field whose names are links
private function learnLinkAt pField
   local tText
   if "link" is not among the items of the textStyle of the clickChunk then
      return empty
   end if
   put the linkText of the clickChunk into tText
   if tText is empty then
      put the clickText into tText
   end if
   return tText
end learnLinkAt

-- Opens what a link names: a card ("card:<name>"), or a handler's page,
-- over the script on a lesson, in the list on the Reference card
command learnFollow pName, pFrom
   if pName begins with "card:" then
      if there is a card (char 6 to -1 of pName) then
         dispatch "frameGo" to group "Frame" with char 6 to -1 of pName
      end if
      exit learnFollow
   end if
   if the cLearn of this card is "reference" then
      refShow pName
   else
      learnExplain pName
   end if
end learnFollow

################################################################################
#
# Run, Copy, Reset
#

-- Runs the script in the code panel, as a click on a button of yours runs
-- it, and shows in the field "Result" what went wrong, if anything
command learnRun
   local tScript, tCompile, tError
   put the text of field "lessonScript" of me into tScript
   put empty into field "Result" of me
   set the textColor of field "Result" of me to "226,232,240"
   learnPaint
   if learnVersion() is empty then
      learnSay the cExtension of this stack && "is not loaded, so this script cannot run. " & \
            "It comes with OXT-Beyond: see Tools > Extension Manager.", true
      exit learnRun
   end if
   set the script of button "lessonTry" of me to tScript
   put the result into tCompile
   if tCompile is not empty then
      learnSay learnCompileText(tCompile), true
      exit learnRun
   end if
   put true into sRunning
   try
      dispatch "mouseUp" to button "lessonTry" of me with 1
   catch tError
      put false into sRunning
      learnSay learnErrorText(tError), true
      set the script of button "lessonTry" of me to empty
      exit learnRun
   end try
   put false into sRunning
   set the script of button "lessonTry" of me to empty
   if field "Result" of me is empty then
      learnSay "(The script ran, and put nothing into field " & quote & "Result" & quote & ".)", false
   end if
end learnRun

-- A line for the field "Result", in red when it says what went wrong
command learnSay pText, pBad
   if pBad then
      if field "Result" of me is not empty then
         put return & return after field "Result" of me
      end if
      put pText after field "Result" of me
      set the textColor of field "Result" of me to "251,113,133"
   else
      put pText into field "Result" of me
      set the textColor of field "Result" of me to "148,163,184"
   end if
end learnSay

-- What a script that does not compile says: its line and why
private function learnCompileText pResult
   local tLine, tWhy
   put item 2 of line 1 of pResult into tLine
   put line (item 1 of line 1 of pResult) of the scriptParsingErrors into tWhy
   return "The script does not compile, at line" && tLine & ":" && tWhy & \
         learnNear(item 4 to -1 of line 1 of pResult)
end learnCompileText

-- What a script that stopped says: the line of the script it stopped on
-- (the first that is in the script run: the lines of an error go from where
-- it happened outwards), and why, as the engine and the extension say it
private function learnErrorText pError
   local tLine, tWhere, tWhy, tText, tHint
   put empty into tWhere
   repeat for each line tLine in pError
      if item 1 of tLine is an integer and item 2 of tLine is an integer and item 2 of tLine > 0 then
         put item 2 of tLine into tWhere
         exit repeat
      end if
   end repeat
   repeat for each line tLine in pError
      if item 1 of tLine is not an integer then
         -- (a line of text of its own: an extension's or a throw's)
         put tLine into tText
         exit repeat
      end if
      put line (item 1 of tLine) of the scriptExecutionErrors into tWhy
      if item 4 to -1 of tLine is not empty and tHint is empty then
         put item 4 to -1 of tLine into tHint
      end if
      if tText is empty and tWhy is not empty and tWhy is not among the items of "Handler: error in statement,Chunk: error in object expression" then
         put tWhy into tText
      end if
   end repeat
   if tText is empty then
      put line 1 of pError into tText
   end if
   if tWhere is empty then
      return "The script stopped:" && tText & learnNear(tHint)
   end if
   return "The script stopped at line" && tWhere & ":" && tText & learnNear(tHint)
end learnErrorText

private function learnNear pHint
   if word 1 to -1 of pHint is empty then
      return empty
   end if
   return " (near " & quote & word 1 to -1 of pHint & quote & ")"
end learnNear

-- Copies the script, and says how to use it
command learnCopy
   set the clipboardData["text"] to the text of field "lessonScript" of me
   put the long id of field "lessonCopy_label" of me into sCopyLabel
   set the text of sCopyLabel to "Copied"
   learnSay "Copied. Paste it into the script of a button in a stack of your own, " & \
         "with a field named " & quote & "Result" & quote & " on its card, and click the button.", false
   send "learnCopied" to me in 1500 milliseconds
end learnCopy

on learnCopied
   if sCopyLabel is not empty and exists(sCopyLabel) then
      set the text of sCopyLabel to "Copy"
   end if
   put empty into sCopyLabel
end learnCopied

-- Puts back the lesson's own script, as it was before any edit
command learnReset
   put the cScript of this card into field "lessonScript" of me
   learnPaint
   set the vScroll of field "lessonScript" of me to 0
   put empty into field "Result" of me
   learnSay "The lesson's own script is back. Press Run to run it.", false
end learnReset

################################################################################
#
# The reference sheet, over the script, and the Reference card
#

-- Opens the page of the handler pName over the script
command learnExplain pName
   local tDocs, tKey
   put learnDocs() into tDocs
   put tolower(pName) into tKey
   if tDocs[tKey] is empty then
      exit learnExplain
   end if
   set the htmlText of field "sheetText" of me to tDocs[tKey]
   set the vScroll of field "sheetText" of me to 0
   learnSheet true
end learnExplain

command learnSheet pOpen
   if pOpen then
      show group "lessonSheet" of me
   else
      hide group "lessonSheet" of me
   end if
end learnSheet

-- Fills the reference list, from the search box
command refFill
   local tNames, tFind, tName, tList, tDocs
   put the cDocNames of this stack into tNames
   put word 1 to -1 of field "refSearch" of me into tFind
   if tFind is empty then
      put tNames into sRefNames
   else
      -- (a name or a page that has the words searched for)
      put learnDocs() into tDocs
      put empty into sRefNames
      repeat for each line tName in tNames
         if tName contains tFind or tDocs[tolower(tName)] contains tFind then
            put tName & return after sRefNames
         end if
      end repeat
      delete the last char of sRefNames
   end if
   put sRefNames into field "refList" of me
   if sRefNames is empty then
      put "Nothing matches " & quote & tFind & quote & "." into field "refList" of me
   end if
   set the vScroll of field "refList" of me to 0
   refThumb
   -- The page shown stays chosen, if the list has it; if not, the
   -- first name found shows its page (a page beside a list without it
   -- reads as the answer to the search)
   set the wholeMatches to true
   if sRefNames is empty then
      exit refFill
   else if sRefShown is not empty and lineOffset(sRefShown, sRefNames) > 0 then
      set the hilitedLine of field "refList" of me to lineOffset(sRefShown, sRefNames)
   else
      refChoose 1
   end if
end refFill

on textChanged
   if the short name of the target is "refSearch" then
      refFill
   else
      pass textChanged
   end if
end textChanged

-- Shows the page of the line pLine of the list
command refChoose pLine
   if pLine is not an integer or line pLine of sRefNames is empty then
      exit refChoose
   end if
   set the hilitedLine of field "refList" of me to pLine
   refPage line pLine of sRefNames
end refChoose

-- Shows the page of the handler pName, choosing it in the list (clearing
-- the search, if it hides the name)
command refShow pName
   local tLine, tRect
   set the wholeMatches to true
   put lineOffset(pName, sRefNames) into tLine
   if tLine is 0 and field "refSearch" of me is not empty then
      put empty into field "refSearch" of me
      refFill
      put lineOffset(pName, sRefNames) into tLine
   end if
   if tLine > 0 then
      set the hilitedLine of field "refList" of me to tLine
      -- (the line chosen in sight)
      put the formattedRect of line tLine of field "refList" of me into tRect
      if item 2 of tRect < the top of field "refList" of me or \
            item 4 of tRect > the bottom of field "refList" of me then
         set the vScroll of field "refList" of me to max(0, (tLine - 3) * the effective textHeight of field "refList" of me)
         refThumb
      end if
   end if
   refPage pName
end refShow

-- The thumb at the list's right: how much of the list shows, and where
command refThumb
   local tField, tShown, tAll, tThumb, tTop
   put the long id of field "refList" of me into tField
   put the height of tField into tShown
   put the formattedHeight of tField into tAll
   if tAll <= tShown then
      hide graphic "refThumb" of me
      exit refThumb
   end if
   put max(30, round(tShown * tShown / tAll)) into tThumb
   put the top of tField + round((tShown - tThumb) * min(1, the vScroll of tField / (tAll - tShown))) into tTop
   set the rect of graphic "refThumb" of me to item 1 of the rect of graphic "refThumb" of me, tTop, \
         item 3 of the rect of graphic "refThumb" of me, tTop + tThumb
   show graphic "refThumb" of me
end refThumb

private command refPage pName
   local tDocs
   put pName into sRefShown
   put learnDocs() into tDocs
   set the htmlText of field "refText" of me to tDocs[tolower(pName)]
   set the vScroll of field "refText" of me to 0
end refPage

################################################################################
#
# Code, in colour: the colours of the remasters' scripts panel, and the
# extension's own handlers (their names in the reference's pages) in its accent
#

command learnPaint
   local tHtml, tLine, tDocs, tVScroll
   put learnDocs() into tDocs
   put the vScroll of field "lessonScript" of me into tVScroll
   repeat for each line tLine in the text of field "lessonScript" of me
      put "<p>" & learnLineHtml(tLine, tDocs) & "</p>" after tHtml
   end repeat
   set the htmlText of field "lessonScript" of me to tHtml
   set the vScroll of field "lessonScript" of me to tVScroll
end learnPaint

private function learnLineHtml pLine, pDocs
   local tOut, tPos, tLen, tChar, tStart, tWord, tNext
   put the number of chars of pLine into tLen
   put 1 into tPos
   repeat while tPos <= tLen
      put char tPos of pLine into tChar
      put tPos + 1 into tNext
      if tChar is quote then
         put tPos into tStart
         put tNext into tPos
         repeat while tPos <= tLen and char tPos of pLine is not quote
            add 1 to tPos
         end repeat
         put learnSpan(char tStart to tPos of pLine, "#fcd34d") after tOut
         add 1 to tPos
      else if (tChar is "-" and char tNext of pLine is "-") or tChar is "#" then
         put learnSpan(char tPos to tLen of pLine, "#94a3b8") after tOut
         exit repeat
      else if learnIsWordChar(tChar) then
         put tPos into tStart
         repeat while tPos <= tLen and learnIsWordChar(char tPos of pLine)
            add 1 to tPos
         end repeat
         put char tStart to tPos - 1 of pLine into tWord
         if pDocs[tolower(tWord)] is not empty then
            put "<b>" & learnSpan(tWord, "#7dd3fc") & "</b>" after tOut
         else
            put learnSpan(tWord, learnWordColor(tWord)) after tOut
         end if
      else
         put learnEscape(tChar) after tOut
         put tNext into tPos
      end if
   end repeat
   return tOut
end learnLineHtml

private function learnIsWordChar pChar
   return pChar is not empty and pChar is in "abcdefghijklmnopqrstuvwxyz0123456789_"
end learnIsWordChar

private function learnWordColor pWord
   if pWord is a number then
      return "#fdba74"
   end if
   if pWord is among the items of "on,end,put,get,set,add,subtract,multiply,divide,send,dispatch," & \
         "repeat,if,then,else,switch,case,break,default,try,catch,throw,answer,ask,create,delete," & \
         "exit,pass,return,local,global,constant,function,command,next,wait,read,write,open,close" then
      return "#c4b5fd"
   end if
   if pWord is among the items of "the,of,to,into,in,with,and,or,not,is,are,a,an,for,each,until," & \
         "while,times,by,after,before,from,at,mod,div,as,among,contains" then
      return "#a5f3fc"
   end if
   if pWord is among the items of "field,button,card,stack,me,it,this,item,items,word,words,line," & \
         "lines,char,chars,url,file,folder,milliseconds,seconds" then
      return "#5eead4"
   end if
   if pWord is among the items of "true,false,empty,quote,space,tab,comma,cr,return,lf" then
      return "#f9a8d4"
   end if
   return "#e2e8f0"
end learnWordColor

private function learnSpan pText, pColor
   return "<font color=" & quote & pColor & quote & ">" & learnEscape(pText) & "</font>"
end learnSpan

private function learnEscape pText
   replace "&" with "&amp;" in pText
   replace "<" with "&lt;" in pText
   replace ">" with "&gt;" in pText
   return pText
end learnEscape

-- The font code is shown in, as the remasters' scripts panel finds it:
-- Source Code Pro (the IDE's Script Editor's), else Droid Sans Mono (the
-- Dictionary's), else a monospaced font the computer has; "-" for none
private function learnCodeFont
   local tError, tFont
   if the environment is "development" then
      try
         if "Source Code Pro" is not among the lines of the fontNames then
            start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
         end if
      catch tError
      end try
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then
         return tFont
      end if
   end repeat
   return "-"
end learnCodeFont

################################################################################
#
# The wheel scrolls the fields, which have no scrollbar (the engine
# scrolls only a field that has one)
#

on rawKeyDown pKey
   local tField
   if pKey is not 65308 and pKey is not 65309 then
      pass rawKeyDown
   end if
   repeat for each item tField in "lessonWords,sheetText,refText,refList,Result,lessonScript"
      if the visible of field tField of me and the mouseLoc is within the rect of field tField of me \
            and (the cLearn of this card is "reference") is (tField begins with "ref") then
         if pKey is 65308 then
            set the vScroll of field tField of me to the vScroll of field tField of me + 54
         else
            set the vScroll of field tField of me to max(0, the vScroll of field tField of me - 54)
         end if
         if tField is "refList" then
            refThumb
         end if
         exit rawKeyDown
      end if
   end repeat
   pass rawKeyDown
end rawKeyDown
