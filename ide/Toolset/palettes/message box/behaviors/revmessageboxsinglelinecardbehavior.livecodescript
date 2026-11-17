script "revMessageBoxSingleLineCardBehavior"
-- Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
-- (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
-- Seth Morrow (2026) and Tom Perry (2024-2026); its Git history and
-- CHANGELOG.md say what changed.

on openCard
   lock screen
   --show relevant frame items
   showFrameItem "outputSource"
   if revIDEGetPreference("IDELockedToStack") is true 
   then showFrameItem "unlockDefaultStack"
   else showFrameItem "lockDefaultStack"
   
   send "revInitialise" to field "message" of me
   
   if revIDEGetPreference("IDESingleLineMessageHistory") is not empty 
   then put line 1 of revIDEGetPreference("IDESingleLineMessageHistory") into field "message"
   else put empty into field "message"
   
   dispatch "revSEColorizeField" to stack "revSEUtilities" with the long id of field "message" of me
   
   local tActiveStack
   put revIDEGetPreference("IDEActiveStack") into tActiveStack
   revUpdateActiveStack tActiveStack, tActiveStack
   set the label of button "Open Stacks" to tActiveStack
   layoutCard
   positionOpenStacksButton
   focus field "message"
   select the text of field "message"
   set the tooltip of field "message" to "Type a command or expression and press Return"
   unlock screen
   
   -- make sure "message" field is selected (tperry 27-4-24)
   send tMsgSelect to this card in 5 ticks
   
   # AL-2015-04-17: [[ Bug 15227 ]] Pass openCard so it is handled by the palette behavior
   pass openCard
end openCard


on tMsgSelect
   -- OXT-Beyond: this runs 5 ticks after openCard, and the stack may be
   -- closed by then: at every start-up ensureMBcorrect (in the Message Box
   -- stack script) opens the stack and closes it again straight away. The
   -- select then failed with "Chunk: can't select object that isn't open",
   -- which the development layout shows in the Script Editor's debugger.
   -- Only select the text while the stack is open on this card.
   if the mode of stack "Message Box" is 0 then exit tMsgSelect
   if the short name of this card of stack "Message Box" is not "Single Line" then exit tMsgSelect
   select text of fld "message" of cd "Single Line" of stack "Message Box"
end tMsgSelect

on closeCard
   hideFrameItem "outputSource"
   hideFrameItem "unlockDefaultStack"
   hideFrameItem "lockDefaultStack"
end closeCard

on resizeStack
   layoutCard
   # AL-2015-04-17: [[ Bug 15227 ]] Pass resizeStack so it is handled by the palette behavior
   pass resizeStack
end resizeStack

-- OXT-Beyond: the positionOpenStacksButton that waits for this card, if
-- one does (see layoutCard)
local sPositionMsg

on layoutCard
   set the rect of group "fields" of me to the contentRect of me
   lock screen
   local tLeft, tTop, tRight, tBottom, tWidth
   lock messages
   
   put the left of group "fields" of me into tLeft
   put the top of group "fields" of me into tTop
   put the right of group "fields" of me into tRight
   put the bottom of group "fields" of me into tBottom
   
   local tHeight
   put the effective textHeight of field "message" of me into tHeight
   
   local tMargins
   put the margins of field "message" of me into tMargins
   if the number of items of tMargins is 1 then
      add tMargins to tHeight
   else
      add item 2 of tMargins to tHeight
   end if
   
   set the rect of field "message" of me to tLeft,tTop,tRight,(tTop + tHeight)
   set the rect of field "auto complete" of me to tLeft,tTop,tRight,(tTop + tHeight)
   set the rect of field "results" of me to tLeft,(tTop + tHeight),tRight,tBottom
   
   put (tRight - tLeft) into tWidth
   set the width of graphic "line" of me to tWidth
   set the loc of graphic "line" of me to (tWidth/2),(tTop+tHeight)
   
   unlock messages
   -- OXT-Beyond: one of these waits at a time, and the button is placed
   -- once, after the last layout. Every layout sent another, and this
   -- card is laid out each time the IDE hears that its stacks changed,
   -- which is each time a control anywhere is named: making the Tools
   -- palette once left some 17 of them waiting, a script that names a
   -- thousand controls a thousand. Each is small, but on Windows a
   -- waiting message that was due before a press of the mouse is
   -- delivered before it, so the press came late by all of them: on a
   -- CI runner 430 ms with 36 waiting and 7.8 s with 252
   cancel sPositionMsg
   send "positionOpenStacksButton" to me in 0 milliseconds
   put the result into sPositionMsg
   unlock screen
end layoutCard

on closeField
   if the short name of the target is "results" then
      put the text of the target into msg
   end if
end closeField

