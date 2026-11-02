script "OXTLearnClicks"
-- OXT-Beyond: the stack side of tools/examples/learn-clicks.py, which
-- clicks every part of a "Learn" stack of the xTalk Suite's extensions
-- (Learn SodiumXT and the others builder.livecodescript's exLearn handlers
-- make) with a real mouse (xdotool, on an X server) and checks what each
-- click did. Run by a standalone engine (Runtime/Linux/x86-64/Standalone of
-- an install), as the stack runs for a user: in a real window, with its
-- own messages, so that a click goes the whole way an engine sends it (the
-- field or button, the group "Learn", the card, the window's frame), which
-- a handler called from a script does not.
--
-- It loads the stack's extensions from $OXT_INSTALL, as the stack's cLoad
-- says, opens $OXT_LEARN_STACK at the top left of the screen, and then,
-- every 100 milliseconds, writes what the window shows to the file
-- $OXT_CLICKS_STATE, a "name=value" a line: the card, its result, the
-- calls in its list and where each is, the reference's list, the
-- clipboard, and so on. The driver reads it after each click. Every error
-- the engine reports (errorDialog) is added to $OXT_CLICKS_STATE.errors.

local sStack, sOut

on startup
   local tError
   put $OXT_CLICKS_STATE into sOut
   try
      insert script of me into back
      put $OXT_LEARN_STACK into sStack
      -- (opened with its messages locked: its cLoad is read before its
      -- front page asks whether the extension is loaded)
      lock messages
      get the name of stack sStack
      unlock messages
      put the short name of stack sStack into sStack
      clicksLoad the cLoad of stack sStack, $OXT_INSTALL
      go stack sStack
      set the topLeft of stack sStack to 0,0
   catch tError
      put "FAILED to open:" && line 1 of tError & return after URL ("file:" & sOut & ".errors")
      quit 1
   end try
   send "clicksDump" to me in 200 milliseconds
end startup

-- Loads each extension the stack names: "lcb|<folder>|<library>" an LCB
-- module and its library, "lcs|<folder>|<stack file>" a script library
private command clicksLoad pLoad, pInstall
   local tLine, tFolder
   set the itemDelimiter to "|"
   repeat for each line tLine in pLoad
      put pInstall & "/Extensions/" & item 2 of tLine into tFolder
      if item 1 of tLine is "lcb" then
         set the revLibraryMapping[item 3 of tLine] to tFolder & "/code/x86_64-linux/" & item 3 of tLine & ".so"
         load extension from file (tFolder & "/module.lcm") with resource path tFolder
      else
         start using stack (tFolder & "/" & item 3 of tLine)
      end if
   end repeat
   set the itemDelimiter to comma
end clicksLoad

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
   local tS, tCard, tIndex, tList, tLearn, tText, tWord, tCount
   set the defaultStack to sStack
   put the long id of this card of stack sStack into tCard
   put "card=" & the short name of tCard & return into tS
   put "learn=" & the cLearn of tCard & return after tS
   put "mouse=" & the mouseLoc & return after tS
   repeat with tIndex = 1 to the number of cards of stack sStack
      put the short name of card tIndex of stack sStack & comma after tList
   end repeat
   put "cards=" & char 1 to -2 of tList & return after tS
   -- the window's own buttons: Back, Next, the tiles
   put empty into tList
   repeat with tIndex = 1 to the number of groups of tCard
      if the cAction of group tIndex of tCard is not empty and the visible of group tIndex of tCard then
         put the cAction of group tIndex of tCard & ":" & the rect of group tIndex of tCard & ";" after tList
      end if
   end repeat
   put "actions=" & tList & return after tS
   put "clipboard=" & clicksLine(the clipboardData["text"]) & return after tS
   if there is no group "Learn" of tCard then
      return tS
   end if
   put the long id of group "Learn" of tCard into tLearn
   put "status=" & clicksLine(field "learnStatus" of tLearn) & return after tS
   -- a lesson: its script, result, calls and buttons
   put "script=" & clicksLine(field "lessonScript" of tLearn) & return after tS
   put "scriptrect=" & the rect of field "lessonScript" of tLearn & return after tS
   put "own=" & (the text of field "lessonScript" of tLearn is the cScript of tCard) & return after tS
   put "result=" & clicksLine(field "Result" of tLearn) & return after tS
   put "expect=" & clicksLine(the cExpect of tCard) & return after tS
   put "sheet=" & the visible of group "lessonSheet" of tLearn & return after tS
   put "sheettext=" & line 1 of field "sheetText" of tLearn & return after tS
   put empty into tList
   repeat for each item tIndex in "lessonRun,lessonCopy,lessonReset,lessonBack"
      if the visible of group tIndex of tLearn then
         put tIndex & ":" & the rect of group tIndex of tLearn & ";" after tList
      end if
   end repeat
   put "buttons=" & tList & return after tS
   -- each call of the list, and where it is (a word in a link's style)
   put empty into tList
   put the number of words of field "lessonCalls" of tLearn into tCount
   repeat with tIndex = 1 to tCount
      if "link" is among the items of the textStyle of word tIndex of field "lessonCalls" of tLearn then
         put word tIndex of field "lessonCalls" of tLearn & ":" & \
               the formattedRect of word tIndex of field "lessonCalls" of tLearn & ";" after tList
      end if
   end repeat
   put "calls=" & tList & return after tS
   -- the Reference card: the list, what it shows, and where its lines are
   put the text of field "refList" of tLearn into tText
   put "reflist=" & clicksLine(tText) & return after tS
   put "reflines=" & the number of lines of tText & return after tS
   put "refrect=" & the rect of field "refList" of tLearn & return after tS
   put "refscroll=" & the vScroll of field "refList" of tLearn & return after tS
   put "refhilite=" & the hilitedLine of field "refList" of tLearn & return after tS
   put "reftext=" & line 1 of field "refText" of tLearn & return after tS
   put "refsearch=" & the text of field "refSearch" of tLearn & return after tS
   put "refsearchrect=" & the rect of field "refSearch" of tLearn & return after tS
   if tText is not empty then
      put "refline3=" & the formattedRect of line 3 of field "refList" of tLearn & return after tS
   end if
   put "focus=" & the short name of the focusedObject & return after tS
   put "under=" & the short name of the mouseControl & return after tS
   return tS
end clicksState

-- Text on one line of the state file: its lines joined by " | "
private function clicksLine pText
   replace return with " | " in pText
   return pText
end clicksLine
