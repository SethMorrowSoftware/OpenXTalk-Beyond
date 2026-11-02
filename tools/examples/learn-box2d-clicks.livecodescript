script "OXTLearnBox2DClicks"
-- OXT-Beyond: the stack side of tools/examples/learn-box2d-clicks.py, which
-- clicks every part of "Learn Box2D" with a real mouse (xdotool, on an X
-- server) and checks what each click did. Run by a standalone engine
-- (Runtime/Linux/x86-64/Standalone of an install), as the stack runs for
-- a user: in a real window, with its own messages, so that a click goes
-- the whole way an engine sends it (the field or button, the card, the
-- Lab, the window's frame), which a handler called from a script does not.
--
-- It loads Box2Dxt from $OXT_INSTALL, opens $OXT_LEARN_BOX2D at the top
-- left of the screen, and then, every 100 milliseconds, writes what the
-- window shows to the file $OXT_CLICKS_STATE, a "name=value" a line: the
-- card, the line of numbers, the call explained, the bodies drawn, where
-- each button and call is, where the bodies that move are, and so on.
-- The driver reads it after each click. Every error the engine reports
-- (errorDialog) is added to $OXT_CLICKS_STATE.errors.

local sStack, sOut

on startup
   local tLib, tError
   put $OXT_CLICKS_STATE into sOut
   try
      insert script of me into back
      put $OXT_INSTALL & "/Extensions/org.openxtalk.box2dxt" into tLib
      set the revLibraryMapping["box2dxt"] to tLib & "/code/x86_64-linux/box2dxt.so"
      load extension from file (tLib & "/module.lcm") with resource path tLib
      put $OXT_LEARN_BOX2D into sStack
      go stack sStack
      put the short name of stack sStack into sStack
      set the topLeft of stack sStack to 0,0
   catch tError
      put "FAILED to open:" && line 1 of tError & return after URL ("file:" & sOut & ".errors")
      quit 1
   end try
   send "clicksDump" to me in 200 milliseconds
end startup

on errorDialog pError
   put "ERROR" && line 1 of pError & return after URL ("file:" & sOut & ".errors")
end errorDialog

-- Everything the driver checks, now
on clicksDump
   local tS, tError
   try
      put clicksState() into tS
   catch tError
      put "dumperror=" & line 1 of tError & return into tS
   end try
   put tS into URL ("file:" & sOut & ".tmp")
   rename (sOut & ".tmp") to sOut
   send "clicksDump" to me in 100 milliseconds
end clicksDump

private function clicksState
   local tS, tCard, tIndex, tList, tDocs, tBody, tCount, tLab
   -- (the mouse where the card has it, as its scripts see it)
   set the defaultStack to sStack
   put the long id of this card of stack sStack into tCard
   put "card=" & the short name of tCard & return into tS
   put "number=" & the number of tCard & return after tS
   put "mouse=" & the mouseLoc & return after tS
   if there is a group "Toy" of tCard then
      put "toy=" & the number of graphics of group "Toy" of tCard & return after tS
      put "hero=" & the rect of group "hero" of tCard & return after tS
   end if
   -- the window's own buttons: Back, Next, the Scripts drawer's, the tiles
   repeat with tIndex = 1 to the number of groups of tCard
      if the cAction of group tIndex of tCard is not empty and the visible of group tIndex of tCard then
         put the cAction of group tIndex of tCard & ":" & the rect of group tIndex of tCard & ";" after tList
      end if
   end repeat
   put "actions=" & tList & return after tS
   if there is a group "Scripts" of tCard then
      put "drawer=" & the visible of group "Scripts" of tCard & return after tS
   end if
   if there is no group "Lab" of tCard then
      return tS
   end if
   put the long id of group "Lab" of tCard into tLab
   put "readout=" & field "Readout" of tCard & return after tS
   put "calldoc=" & line 1 of field "CallDoc" of tCard & return after tS
   put "bodies=" & the number of graphics of group "Bodies" of tCard & return after tS
   put "pause=" & field "LabPause_label" of tCard & return after tS
   put "court=" & the rect of graphic "Court" of tCard & return after tS
   put empty into tList
   repeat with tIndex = 1 to the number of groups of tCard
      if the short name of group tIndex of tCard begins with "Do" and the cDo of group tIndex of tCard is not empty then
         put the cDo of group tIndex of tCard & ":" & the rect of group tIndex of tCard & ";" after tList
      end if
   end repeat
   put "buttons=" & tList & return after tS
   put empty into tList
   repeat for each item tIndex in "LabStep,LabPause,LabReset"
      put tIndex & ":" & the rect of group tIndex of tCard & ";" after tList
   end repeat
   put "lab=" & tList & return after tS
   put "calls=" & the rect of field "Calls" of tCard & return after tS
   put "callsscroll=" & the vScroll of field "Calls" of tCard & return after tS
   put "callsheight=" & the textHeight of field "Calls" of tCard & return after tS
   put "callsmargin=" & item 2 of the margins of field "Calls" of tCard & return after tS
   put field "Calls" of tCard into tList
   replace return with comma in tList
   put "callnames=" & tList & return after tS
   -- the bodies that move (up to 40), where they are on the screen, from the
   -- Lab's own list of what it draws
   put value("labBodies()", tLab) into tList
   put 0 into tCount
   put empty into tDocs
   repeat for each item tBody in tList
      if b2BodyType(tBody) is 2 then
         put tBody & ":" & value("labPX(" & b2BodyX(tBody) & ")", tLab) & "," & \
               value("labPY(" & b2BodyY(tBody) & ")", tLab) & ";" after tDocs
         add 1 to tCount
         if tCount >= 40 then
            exit repeat
         end if
      end if
   end repeat
   put "dynamic=" & tDocs & return after tS
   return tS
end clicksState
