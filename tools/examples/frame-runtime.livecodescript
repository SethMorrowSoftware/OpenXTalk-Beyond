script "OXTExampleFrame"
-- OXT-Beyond: the window around a remastered example's programs.
--
-- This is the script of the group "Frame" in each remastered example
-- (tools/examples/README.md): the sidebar, with the cards' list and Back
-- and Next, and the header, with each card's title and tagline. The group
-- is a background, on every card. On every card that has a program there
-- are two more: the group "Workbench", the stage the program runs on, and
-- the group "Scripts", the panel that shows the scripts of the things on
-- the card, in colour. A card's custom property cLayout says how they go:
-- on a "program" card the panel is beside the stage, and on a "wide" card
-- the stage is as wide as the window lets it be, and the panel is a
-- drawer over it, which the Scripts button in the header opens.
--
-- A background group gets the card's messages after the card: openCard,
-- a click on the stage, a key. So the programs on the cards need nothing
-- from this script, and this script reads them as they are: the panel
-- shows the script of whatever is clicked, and the scripts the card and
-- its controls have, as chips to choose from. (A card's own preOpenCard
-- handler passes the message, so that this script lays the card out.)
--
-- A group made here that lights up when the pointer is over it, and does
-- something when clicked, has the custom properties cRest and cLit (its
-- colour at rest and lit) and cAction (what a click does: "prev", "next",
-- "go <card>", "chip <n>", "scripts", "edit" or "copy"). The colours are
-- the group's own: nothing else here names one, but the custom property
-- cAccent of this group, the example's colour.

-- The objects whose scripts the panel offers, by chip number, and the one
-- it shows
local sChips, sShown
-- The code panel's field and thumb, where the wheel is taking the field,
-- and its font
local sCodeField, sCodeThumb, sCodeGoal, sCodeFont
-- The Copy button's label, while it says "Copied"
local sCopyLabel

on preOpenCard
   frameSync
   pass preOpenCard
end preOpenCard

-- The sidebar's list and buttons, the stage and the panel, and the
-- panel's chips, for this card
command frameSync
   local tNumber, tLine, tIndex, tTab, tRect, tMid
   put the number of this card into tNumber
   put frameLine() into tLine
   -- the card's line in the list: its title white, on the pill
   if tLine <= the number of lines of field "frameList" then
      repeat with tIndex = 1 to the number of lines of field "frameList"
         put offset(tab, line tIndex of field "frameList") into tTab
         if tIndex = tLine then
            set the textColor of char tTab + 1 to -1 of line tIndex of field "frameList" to "255,255,255"
            -- (its number too, which is too dim to read on the pill)
            if tTab > 1 then
               set the textColor of char 1 to tTab - 1 of line tIndex of field "frameList" to "203,213,225"
            end if
         else
            set the textColor of char tTab + 1 to -1 of line tIndex of field "frameList" to empty
            if tTab > 1 then
               set the textColor of char 1 to tTab - 1 of line tIndex of field "frameList" to "100,116,139"
            end if
         end if
      end repeat
      put the formattedRect of line tLine of field "frameList" into tRect
      -- (a line's letters sit below the middle of its rect, by 5 pixels on
      -- Linux and in a browser alike: the pill goes round the letters)
      put (item 2 of tRect + item 4 of tRect) div 2 + 5 into tMid
      set the rect of graphic "frameHi" to item 1 of the rect of graphic "frameHi", tMid - 14, \
            item 3 of the rect of graphic "frameHi", tMid + 14
      set the loc of graphic "frameBar" to item 1 of the loc of graphic "frameBar", tMid
   end if
   frameDim "frameBack", tNumber is 1
   frameDim "frameNext", tNumber is the number of cards
   frameLayout
   if there is a group "Scripts" then
      frameFillChips
      if sChips[1] is empty then
         frameShowNone
      else
         frameShow 1
      end if
   end if
end frameSync

-- This card's line in the list, found by the card's name: a card the
-- user adds (a lesson can ask for a copy of its card) moves the numbers
-- of the cards after it. A copy has its card's name, and so its line
private function frameLine
   local tLine
   set the wholeMatches to true
   put lineOffset(the short name of this card, the cFrameCards of me) into tLine
   if tLine is 0 then
      put the number of this card into tLine
   end if
   return tLine
end frameLine

-- The stage and the panel, as this card has them: on a wide card the
-- stage is wider, and the panel is a drawer, shut when the card opens
private command frameLayout
   if there is no group "Workbench" or there is no group "Scripts" then
      if there is a group "frameScripts" then
         hide group "frameScripts"
      end if
      exit frameLayout
   end if
   if the cLayout of this card is "wide" then
      set the rect of graphic "Stage" to the cWide of group "Workbench"
      show group "frameScripts"
      frameDrawer false, false
   else
      set the rect of graphic "Stage" to the cNarrow of group "Workbench"
      hide group "frameScripts"
      show group "Scripts"
   end if
end frameLayout

-- Opens or shuts the drawer of scripts on a wide card; pSlide slides it
command frameDrawer pOpen, pSlide
   if there is no group "Scripts" or there is no group "frameScripts" then
      exit frameDrawer
   end if
   if pSlide then
      lock screen for visual effect in rect the rect of group "Scripts"
   end if
   if pOpen then
      -- (above anything the program has made since the card opened)
      relayer group "Scripts" to front of this card
      show group "Scripts"
      set the cRest of group "frameScripts" to the cOpen of group "frameScripts"
   else
      hide group "Scripts"
      set the cRest of group "frameScripts" to the cShut of group "frameScripts"
   end if
   set the backgroundColor of graphic 1 of group "frameScripts" to the cRest of group "frameScripts"
   if pSlide and pOpen then
      unlock screen with visual effect "scroll left" very fast
   else if pSlide then
      unlock screen with visual effect "reveal right" very fast
   end if
end frameDrawer

-- True on a wide card whose drawer is open
private function frameDrawerOpen
   return the cLayout of this card is "wide" and there is a group "Scripts" and the visible of group "Scripts"
end frameDrawerOpen

private command frameDim pName, pDim
   if there is no group pName then
      exit frameDim
   end if
   if pDim then
      set the blendLevel of group pName to 60
   else
      set the blendLevel of group pName to 0
   end if
end frameDim

################################################################################
#
# Going from card to card
#

on escapeKey
   if frameDrawerOpen() then
      frameDrawer false, true
   else
      pass escapeKey
   end if
end escapeKey

on arrowKey pKey
   -- (a field being typed in keeps its arrow keys)
   if the selectedField is empty and pKey is "left" then
      frameGo "prev"
   else if the selectedField is empty and pKey is "right" then
      frameGo "next"
   else
      pass arrowKey
   end if
end arrowKey

-- Goes to the previous or next card, or a card by number or name; the
-- page slides, and the sidebar stays where it is
command frameGo pWhere
   local tFrom, tTo, tEffect
   put the number of this card into tFrom
   switch pWhere
      case "prev"
         put tFrom - 1 into tTo
         break
      case "next"
         put tFrom + 1 into tTo
         break
      default
         if pWhere is an integer then
            put pWhere into tTo
         else if there is a card pWhere then
            put the number of card pWhere into tTo
         end if
   end switch
   if tTo is not an integer or tTo < 1 or tTo > the number of cards or tTo = tFrom then
      exit frameGo
   end if
   if tTo > tFrom then
      put "push left" into tEffect
   else
      put "push right" into tEffect
   end if
   lock screen for visual effect in rect the cContent of me
   go card tTo
   unlock screen with visual effect tEffect very fast
end frameGo

################################################################################
#
# Clicks, and things that light up
#

on mouseDown pButton
   local tObj, tOwner
   put the long id of the target into tObj
   -- (a click on a part of a group, such as the label of a button the kit
   -- drew, is a click on the group, whose script it is)
   put the long owner of tObj into tOwner
   repeat while the script of tObj is empty and word 1 of tOwner is "group" and not frameIsOwn(tOwner)
      put the long id of tOwner into tObj
      put the long owner of tObj into tOwner
   end repeat
   -- A click on something with a script shows that script
   if pButton is 1 and there is a group "Scripts" and not frameIsOwn(tObj) \
         and the script of tObj is not empty then
      -- (a control made since the card opened gets its chip)
      frameFillChips
      frameShowObject tObj
   end if
   pass mouseDown
end mouseDown

on mouseUp pButton
   local tGroup, tAction
   if pButton is not 1 then
      pass mouseUp
   end if
   if the short name of the target is "frameList" and word 1 of the name of the target is "field" then
      -- (the card the line names, by name: see frameLine)
      if word 2 of the clickLine is an integer and line (word 2 of the clickLine) of the cFrameCards of me is not empty then
         frameGo line (word 2 of the clickLine) of the cFrameCards of me
      else if word 2 of the clickLine is an integer then
         frameGo word 2 of the clickLine
      end if
      exit mouseUp
   end if
   put frameLitGroup(the long id of the target) into tGroup
   if tGroup is not empty then
      put the cAction of tGroup into tAction
   end if
   switch word 1 of tAction
      case "prev"
      case "next"
         frameGo tAction
         break
      case "go"
         frameGo word 2 to -1 of tAction
         break
      case "chip"
         frameShow word 2 of tAction
         break
      case "scripts"
         frameDrawer not the visible of group "Scripts", true
         break
      case "edit"
         if sShown is not empty and exists(sShown) then
            edit the script of sShown
         end if
         break
      case "copy"
         frameCopy
         break
      default
         pass mouseUp
   end switch
end mouseUp

on mouseEnter
   local tGroup
   put frameLitGroup(the long id of the target) into tGroup
   if tGroup is not empty then
      frameLight tGroup, true
   else if frameIsProgram(the long id of the target) then
      -- (a hand over what a click runs)
      lock cursor
      set the cursor to hand
   end if
   pass mouseEnter
end mouseEnter

on mouseLeave
   local tGroup
   put frameLitGroup(the long id of the target) into tGroup
   -- (the pointer going from one part of a group to another leaves it lit)
   if tGroup is not empty and the mouseLoc is not within the rect of tGroup then
      frameLight tGroup, false
   else if tGroup is empty and frameIsProgram(the long id of the target) then
      unlock cursor
   end if
   pass mouseLeave
end mouseLeave

-- True for a control on the card with a script that a click runs
private function frameIsProgram pObj
   if word 1 of pObj is "card" or word 1 of pObj is "stack" or frameIsOwn(pObj) then
      return false
   end if
   return the script of pObj contains "on mouseUp" or the script of pObj contains "on mouseDown"
end frameIsProgram

-- The group a control is in that lights up, or empty
private function frameLitGroup pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if word 1 of tObj is "group" and the cLit of tObj is not empty then
         return tObj
      end if
      put the long owner of tObj into tObj
   end repeat
   return empty
end frameLitGroup

private command frameLight pGroup, pLit
   if pLit then
      set the backgroundColor of graphic 1 of pGroup to the cLit of pGroup
      lock cursor
      set the cursor to hand
   else
      set the backgroundColor of graphic 1 of pGroup to the cRest of pGroup
      unlock cursor
   end if
end frameLight

-- True for this window's own controls: this group, the stage, the panel,
-- and what they hold
private function frameIsOwn pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if word 1 of tObj is "group" and the short name of tObj is among the items of "Frame,Workbench,Scripts" then
         return true
      end if
      put the long owner of tObj into tObj
   end repeat
   return false
end frameIsOwn

################################################################################
#
# The scripts on this card
#

-- A chip for the card, if it has a script, and for each control on it
-- that has one, in the order they are layered
command frameFillChips
   local tCount, tIndex, tObj, tShown
   put sShown into tShown
   put empty into sChips
   put 0 into tCount
   if the script of this card is not empty then
      add 1 to tCount
      put the long id of this card into sChips[tCount]
   end if
   repeat with tIndex = 1 to the number of controls of this card
      put the long id of control tIndex of this card into tObj
      if the script of tObj is empty or frameIsOwn(tObj) then
         next repeat
      end if
      add 1 to tCount
      put tObj into sChips[tCount]
   end repeat
   put the long id of field "codeText" into sCodeField
   put the long id of graphic "codeThumb" into sCodeThumb
   if sCodeFont is empty then
      put frameCodeFont() into sCodeFont
      if sCodeFont is not "-" then
         set the textFont of field "codeText" to sCodeFont
         set the textFont of field "codeRef" to sCodeFont
      end if
   end if
   frameLayChips
   put tShown into sShown
end frameFillChips

-- The chips' labels, in a row, each as wide as its label; those that do
-- not fit are hidden
private command frameLayChips
   local tIndex, tName, tX, tRight, tWidth, tLabel, tMid, tTop
   put the left of graphic "codeBg" + 16 into tX
   put the right of graphic "codeBg" - 16 into tRight
   repeat with tIndex = 1 to 5
      put "codeChip" & tIndex into tName
      if sChips[tIndex] is empty then
         hide group tName
         next repeat
      end if
      put the long id of field (tName & "_label") into tLabel
      set the text of tLabel to frameChipLabel(sChips[tIndex])
      put the formattedWidth of tLabel + 28 into tWidth
      if tX + tWidth > tRight then
         hide group tName
         next repeat
      end if
      set the rect of group tName to tX, the top of group tName, tX + tWidth, the bottom of group tName
      set the rect of graphic 1 of group tName to the rect of group tName
      -- (the label in the middle, as a button's is)
      put item 2 of the loc of group tName into tMid
      put tMid - (the formattedHeight of tLabel + 4) div 2 into tTop
      set the rect of tLabel to tX + 14, tTop, tX + 14 + the formattedWidth of tLabel + 4, \
            tTop + the formattedHeight of tLabel + 8
      show group tName
      add tWidth + 8 to tX
   end repeat
end frameLayChips

-- What a chip says: the object's name, and a letter's letter
private function frameChipLabel pObj
   local tOther, tCount
   if word 1 of pObj is "card" then
      return "This card"
   end if
   if word 1 of pObj is "field" and the number of chars of word 1 to -1 of the text of pObj is 1 then
      return the short name of pObj && "(" & word 1 of the text of pObj & ")"
   end if
   -- (two things of one name, a field "Info" and an image "Info", say
   -- which is which)
   put 0 into tCount
   repeat for each element tOther in sChips
      if word 1 of tOther is not "card" and exists(tOther) and the short name of tOther is the short name of pObj then
         add 1 to tCount
      end if
   end repeat
   if tCount > 1 then
      return the short name of pObj && "(" & word 1 of pObj & ")"
   end if
   return the short name of pObj
end frameChipLabel

-- Shows the script of an object, choosing its chip (one past the five
-- chips, or hidden because it did not fit, shows without one)
command frameShowObject pObj
   local tIndex
   repeat with tIndex = 1 to the number of elements of sChips
      if sChips[tIndex] is pObj then
         frameShow tIndex
         exit frameShowObject
      end if
   end repeat
end frameShowObject

-- Shows the script of chip pIndex, in colour
command frameShow pIndex
   local tIndex, tAccent, tObj, tRest
   if sChips[pIndex] is empty or not exists(sChips[pIndex]) then
      exit frameShow
   end if
   put sChips[pIndex] into sShown
   put the cAccent of me into tAccent
   repeat with tIndex = 1 to 5
      put "codeChip" & tIndex into tObj
      if tIndex = pIndex then
         put tAccent into tRest
         set the textColor of field (tObj & "_label") to "255,255,255"
      else
         put the cChipRest of group "Scripts" into tRest
         set the textColor of field (tObj & "_label") to the cChipInk of group "Scripts"
      end if
      set the cRest of group tObj to tRest
      set the backgroundColor of graphic 1 of group tObj to tRest
   end repeat
   if word 1 of sShown is "card" then
      set the text of field "codeRef" to "the script of this card"
   else
      set the text of field "codeRef" to "the script of" && word 1 of the name of sShown && \
            quote & the short name of sShown & quote
   end if
   if sCodeFont is not "-" then
      set the textFont of field "codeText" to sCodeFont
   end if
   frameSetCode the script of sShown
   set the vScroll of field "codeText" to 0
   put empty into sCodeGoal
   frameSyncThumb
   -- (the Script Editor is the IDE's: a standalone has none)
   show group "codeCopy"
   if the environment is "development" then
      show group "codeEdit"
      set the left of group "codeCopy" to the right of group "codeEdit" + 8
   else
      hide group "codeEdit"
      set the left of group "codeCopy" to the left of group "codeEdit"
   end if
end frameShow

-- The code, in colour, each line in from the left as far as its own
-- indent; a line too long for the panel goes on below itself, a little
-- further in
private command frameSetCode pScript
   local tHtml, tLine, tSpaces, tIndent, tCount, tIndex, tCharWidth
   put 0 into tCount
   repeat for each line tLine in pScript
      add 1 to tCount
      put 0 into tSpaces
      repeat while char tSpaces + 1 of tLine is space
         add 1 to tSpaces
      end repeat
      put tSpaces into tIndent[tCount]
      put "<p>" & frameCodeLineHtml(char tSpaces + 1 to -1 of tLine) & "</p>" after tHtml
   end repeat
   set the htmlText of sCodeField to tHtml
   put frameCharWidth() into tCharWidth
   repeat with tIndex = 1 to tCount
      set the leftIndent of line tIndex of sCodeField to round((tIndent[tIndex] + 3) * tCharWidth)
      set the firstIndent of line tIndex of sCodeField to -round(3 * tCharWidth)
   end repeat
end frameSetCode

-- The width of a letter of the code's font. (It is measured, not read
-- from the text in the field: before the card opens, the field has not
-- laid its text out, and its widths are 0.)
private function frameCharWidth
   local tWidth
   put measureText("abcdefghijklmnopqrstuvwxyz", sCodeField) into tWidth
   if tWidth is not a number or tWidth <= 0 then
      return 7
   end if
   return tWidth / 26
end frameCharWidth

-- A card with nothing that has a script yet: the card's own words for
-- that (its custom property cEmptyText), or a line on how to give a
-- control a script, in the window's own font
private command frameShowNone
   local tText, tHtml, tLine
   put empty into sShown
   set the text of field "codeRef" to empty
   put the cEmptyText of this card into tText
   if tText is empty then
      put "Nothing on this card has a script yet." & return & return & \
            "Choose the Edit tool, select a control, then Object > Object Script to give it one: " & \
            "it shows here when the card opens again." into tText
   end if
   repeat for each line tLine in tText
      if tHtml is empty then
         put "<p><font color=" & quote & "#ffffff" & quote & "><b>" & frameEscape(tLine) & "</b></font></p>" after tHtml
      else
         put "<p><font color=" & quote & "#cbd5e1" & quote & ">" & frameEscape(tLine) & "</font></p>" after tHtml
      end if
   end repeat
   set the textFont of field "codeText" to empty
   set the htmlText of field "codeText" to tHtml
   set the vScroll of field "codeText" to 0
   frameSyncThumb
   hide group "codeEdit"
   hide group "codeCopy"
end frameShowNone

-- Copies the script shown, and says so for a moment
private command frameCopy
   if sShown is empty or not exists(sShown) then
      exit frameCopy
   end if
   set the clipboardData["text"] to the script of sShown
   put the long id of field "codeCopy_label" into sCopyLabel
   set the text of sCopyLabel to "Copied"
   send "frameCopied" to me in 1500 milliseconds
end frameCopy

on frameCopied
   if sCopyLabel is not empty and exists(sCopyLabel) then
      set the text of sCopyLabel to "Copy"
   end if
   put empty into sCopyLabel
end frameCopied

################################################################################
#
# The code panel scrolls with the wheel, without a scrollbar
#

on rawKeyDown pKey
   local tGliding
   if pKey is not 65308 and pKey is not 65309 then
      pass rawKeyDown
   end if
   if sCodeField is empty or not exists(sCodeField) or there is no group "Scripts" \
         or not the visible of group "Scripts" or the mouseLoc is not within the rect of sCodeField then
      pass rawKeyDown
   end if
   -- (a glide under way takes the new goal: a second one beside it would
   -- double its speed)
   put sCodeGoal is not empty into tGliding
   if not tGliding then
      put the vScroll of sCodeField into sCodeGoal
   end if
   if pKey is 65308 then
      add 48 to sCodeGoal
   else
      subtract 48 from sCodeGoal
   end if
   put max(0, min(sCodeGoal, frameCodeRoom())) into sCodeGoal
   if not tGliding then
      frameGlide
   end if
end rawKeyDown

-- One step of the scroll toward where the wheel is taking it
on frameGlide
   local tNow, tStep
   if sCodeGoal is empty or sCodeField is empty or not exists(sCodeField) then
      put empty into sCodeGoal
      exit frameGlide
   end if
   put the vScroll of sCodeField into tNow
   put round((sCodeGoal - tNow) * 0.35) into tStep
   if abs(sCodeGoal - tNow) <= 1 or tStep is 0 then
      set the vScroll of sCodeField to sCodeGoal
      put empty into sCodeGoal
   else
      set the vScroll of sCodeField to tNow + tStep
      -- (a field that did not move is at its end: the glide is over)
      if the vScroll of sCodeField is tNow then
         put empty into sCodeGoal
      else
         send "frameGlide" to me in 16 milliseconds
      end if
   end if
   frameSyncThumb
end frameGlide

-- How far the code scrolls. The engine stops a field's scroll a few
-- pixels short of its formattedHeight less its height, so it is measured:
-- a goal past that end would never be reached.
private function frameCodeRoom
   local tNow, tRoom, tMessages
   put the vScroll of sCodeField into tNow
   put the lockMessages into tMessages
   lock screen
   lock messages
   set the vScroll of sCodeField to the formattedHeight of sCodeField + the height of sCodeField
   put the vScroll of sCodeField into tRoom
   set the vScroll of sCodeField to tNow
   set the lockMessages to tMessages
   unlock screen
   return max(0, tRoom)
end frameCodeRoom

-- The thumb at the panel's right shows how far down the script is
private command frameSyncThumb
   local tRoom, tShown, tThumb, tTop, tObj
   if sCodeField is empty or not exists(sCodeField) or not exists(sCodeThumb) then
      exit frameSyncThumb
   end if
   put sCodeThumb into tObj
   put frameCodeRoom() into tRoom
   if tRoom < 16 then
      hide tObj
      exit frameSyncThumb
   end if
   put the height of sCodeField into tShown
   put max(30, round(tShown * tShown / (tShown + tRoom))) into tThumb
   put the top of sCodeField + round((tShown - tThumb) * min(1, the vScroll of sCodeField / tRoom)) into tTop
   set the rect of tObj to item 1 of the rect of tObj, tTop, item 3 of the rect of tObj, tTop + tThumb
   show tObj
end frameSyncThumb

################################################################################
#
# Code, in colour: the same colours as Learn's code panels
#

private function frameCodeHtml pText
   local tHtml, tLine
   repeat for each line tLine in pText
      put "<p>" & frameCodeLineHtml(tLine) & "</p>" after tHtml
   end repeat
   return tHtml
end frameCodeHtml

private function frameCodeLineHtml pLine
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
         put frameSpan(char tStart to tPos of pLine, "#fcd34d") after tOut
         add 1 to tPos
      else if (tChar is "-" and char tNext of pLine is "-") or tChar is "#" then
         put frameSpan(char tPos to tLen of pLine, "#64748b") after tOut
         exit repeat
      else if frameIsWordChar(tChar) then
         put tPos into tStart
         repeat while tPos <= tLen and frameIsWordChar(char tPos of pLine)
            add 1 to tPos
         end repeat
         put char tStart to tPos - 1 of pLine into tWord
         put frameSpan(tWord, frameWordColor(tWord)) after tOut
      else
         put frameEscape(tChar) after tOut
         put tNext into tPos
      end if
   end repeat
   return tOut
end frameCodeLineHtml

private function frameIsWordChar pChar
   return pChar is not empty and pChar is in "abcdefghijklmnopqrstuvwxyz0123456789_"
end frameIsWordChar

private function frameWordColor pWord
   if pWord is a number then
      return "#fdba74"
   end if
   if pWord is among the items of "on,end,put,get,set,move,add,subtract,multiply,divide,send,dispatch,call," & \
         "repeat,if,then,else,switch,case,break,default,try,catch,throw,answer,ask,create,delete,go,open,close," & \
         "show,hide,lock,unlock,sort,filter,replace,convert,do,exit,pass,return,local,global,constant,cancel," & \
         "launch,revSpeak,function,command,getprop,setprop,next,beep,play,wait,select,click,type,import,export," & \
         "start,stop,read,write,save,visual,focus,choose,combine,split,insert,load,post,format,grab" then
      return "#c4b5fd"
   end if
   if pWord is among the items of "the,of,to,into,in,with,without,waiting,messages,and,or,not,is,are,a,an," & \
         "for,each,until,while,times,by,after,before,from,at,any,mod,div,as,among,contains,within,relative" then
      return "#7dd3fc"
   end if
   if pWord is among the items of "field,fld,graphic,grc,button,btn,card,cd,stack,image,img,group,grp,player," & \
         "widget,scrollbar,control,me,it,this,target,item,items,word,words,line,lines,char,chars,character," & \
         "characters,url,file,folder,milliseconds,millisecs,ticks,seconds,second,secs,sec" then
      return "#5eead4"
   end if
   if pWord is among the items of "true,false,empty,quote,space,tab,comma,cr,return,lf,slash,colon,pi" then
      return "#f9a8d4"
   end if
   return "#e2e8f0"
end frameWordColor

private function frameSpan pText, pColor
   return "<font color=" & quote & pColor & quote & ">" & frameEscape(pText) & "</font>"
end frameSpan

private function frameEscape pText
   replace "&" with "&amp;" in pText
   replace "<" with "&lt;" in pText
   replace ">" with "&gt;" in pText
   return pText
end frameEscape

-- The font code is shown in: Source Code Pro, which the IDE carries for
-- its Script Editor, else Droid Sans Mono, which the Dictionary's viewer
-- carries (the web engine can load that one), else a monospaced font the
-- computer has; "-" for none
private function frameCodeFont
   local tError, tFont
   if the environment is "development" then
      try
         if "Source Code Pro" is not among the lines of the fontNames then
            start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
         end if
      catch tError
      end try
      try
         if "Source Code Pro" is not among the lines of the fontNames and \
               "Droid Sans Mono" is not among the lines of the fontNames then
            start using font file (revIDESpecialFolderPath("IDE") & \
                  "/Documentation/html_viewer/resources/data/api/DroidSansMono.ttf")
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
end frameCodeFont
