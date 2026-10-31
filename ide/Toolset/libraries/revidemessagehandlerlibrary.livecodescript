script "revIdeMessageHandlerLibrary"
on extensionInitialize
   if the target is not me then
      pass "extensionInitialize"
   end if	
   insert the script of me into front
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass "extensionFinalize"
   end if
   remove the script of me from front
end extensionFinalize

#################################
# Messages handled and sent on to object
#################################
local sSelectingObjects
on selectedObjectChanged
   if not sSelectingObjects and \
         not revIDEObjectIsOnIDEStack(the long id of the target) then
      send "ideMessageSend" &&  "ideSelectedObjectChanged" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass selectedObjectChanged
end selectedObjectChanged

on objectSelectionStarted
   if not revIDEObjectIsOnIDEStack(the long id of the target) then
      put true into sSelectingObjects
      send "ideMessageSend" &&  "ideObjectSelectionStarted" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass objectSelectionStarted
end objectSelectionStarted

on objectSelectionEnded
   if not revIDEObjectIsOnIDEStack(the long id of the target) then
      put false into sSelectingObjects
      send "ideMessageSend" &&  "ideSelectedObjectChanged" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass objectSelectionEnded
end objectSelectionEnded

on resizeControl
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideResizeControl,tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass resizeControl
end resizeControl

on resumeStack
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideResumeStack","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass resumeStack
end resumeStack

on newCard
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewCard","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newCard
end newCard

on newStack
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewStack","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newStack
end newStack

on newField
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewControl","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newField
end newField

on newGraphic
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewControl","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newGraphic
end newGraphic

on newGroup
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" && "ideNewControl","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newGroup
end newGroup

on newImage
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewControl","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newImage
end newImage

on newPlayer
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewControl","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newPlayer
end newPlayer

on newScrollbar
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewControl","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newScrollbar
end newScrollbar

on newButton
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewControl","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newButton
end newButton

on newWidget
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideNewControl","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass newWidget
end newWidget

on deleteButton
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" && "ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteButton
end deleteButton

on deleteCard
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend" &&  "ideCardDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteCard
end deleteCard
   
on deleteEPS
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteEPS
end deleteEPS

on deleteField
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then   
      send "ideMessageSend ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds 
   end if
   pass deleteField
end deleteField

on deleteGraphic
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteGraphic
end deleteGraphic

on deleteGroup
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteGroup
end deleteGroup

on deleteImage
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteImage
end deleteImage

on deletePlayer
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then   
      send "ideMessageSend ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deletePlayer
end deletePlayer

on deleteScrollbar
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteScrollbar
end deleteScrollbar

on deleteWidget 
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then   
      send "ideMessageSend ideControlDeleted","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteWidget
end deleteWidget

on deleteStack
   local tLongID
   -- deleteStack is sent to the card, so the owner of the target is the stack
   put the long id of the owner of the target into tLongID
   if not revIDEStackIsIDEStack(tLongID) then
      send "ideMessageSend ideStackDeleted","tLongID" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass deleteStack
end deleteStack

on libraryStack
   local tTarget
   put the long id of the target into tTarget
   if revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend ideLibraryStack","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass libraryStack
end libraryStack

on releaseStack
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      send "ideMessageSend ideReleaseStack","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass releaseStack
end releaseStack

on nameChanged pOldName, pNewName
   local tTarget, tParams
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then   
      put pOldName into tParams[1]
      put pNewName into tParams[2]
      put tTarget into tParams[3]
      send "ideMessageSendWithParameters ideNameChanged,tTarget,tParams" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass nameChanged
end nameChanged

on openCard
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then   
      send "ideMessageSend" &&  "ideOpenCard","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass openCard
end openCard

on openStack
   local tTarget
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then   
      send "ideMessageSend" &&  "ideOpenStack","tTarget" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass openStack
end openStack

--PM-2015-10-05: [[ Bug 16099 ]] choose pointer/browse tool does not update Tools palette
on newTool pTool
   send "ideMessageSend" &&  "ideToolChanged" to stack "revIDELibrary" in 0 milliseconds
   pass newTool
end newTool

on mainstackChanged pOldMainstack, pNewMainStack
   local tTarget, tParams
   put the long id of the target into tTarget
   if not revIDEStackIsIDEStack(tTarget) then
      put pOldMainstack into tParams[1]
      put pNewMainStack into tParams[2]
      put tTarget into tParams[3]
      send "ideMessageSendWithParameters" &&  "ideMainstackChanged,tTarget, tParams" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass mainstackChanged
end mainstackChanged

-- OXT-Beyond: the stacks a moveStack found under the menu bar while the
-- mouse was down, which revIDEStackBelowMenuBar moves once it is up
local sBelowMenuBarPending

on moveStack pLeft, pTop
   local tMenuBar, tStack
   if the platform is "MacOS" then -- prevent stack getting stuck under menu bar
      put revIDEPaletteToStackName("menubar") into tMenuBar
      put revTargetStack() into tStack
      -- OXT-Beyond: not the menu bar itself. Preferences can make it a
      -- window with a title bar, which is dragged, and its top is always
      -- above its own bottom, so a drag set it its height and 20 lower.
      -- Nor a stack while the mouse is down: set during a drag, a window
      -- stays where it is dragged and the engine takes it to be where it
      -- was set, so its buttons stop working until it is set where it is
      -- (forum, bwmilby, rc.6.3: the Menubar's, then revTools'). The stack
      -- goes below the menu bar once the mouse is up, as before
      if tStack is not tMenuBar then
         if pTop < the bottom of stack tMenuBar and the right of stack tStack < the right of stack tMenuBar + 5 then
            if the mouse is down then
               if sBelowMenuBarPending[tStack] is not true then
                  put true into sBelowMenuBarPending[tStack]
                  send "revIDEStackBelowMenuBar" && quote & tStack & quote to me in 100 milliseconds
               end if
            else
               set the top of stack tStack to the bottom of stack tMenuBar + 20
            end if
         end if
      end if
   end if

   # IDE to notify any objects subscribed to the ideStackMoved Message
   local tLongID
   -- moveStack is sent to the card, so the owner of the target is the stack
   put the long id of the owner of the target into tLongID
   send "ideMessageSendWithTrigger" &&  "ideStackMoved, tLongID, tLongID" to stack "revIDELibrary" in 0 milliseconds
   pass moveStack
end moveStack

-- OXT-Beyond: the stack pStack, which a moveStack found under the menu bar
-- while the mouse was down (above), goes below it once the mouse is up, if
-- it is still under it
on revIDEStackBelowMenuBar pStack
   local tMenuBar
   if the mouse is down then
      send "revIDEStackBelowMenuBar" && quote & pStack & quote to me in 100 milliseconds
      exit revIDEStackBelowMenuBar
   end if
   delete variable sBelowMenuBarPending[pStack]
   put revIDEPaletteToStackName("menubar") into tMenuBar
   if there is not a stack pStack or there is not a stack tMenuBar then exit revIDEStackBelowMenuBar
   if the top of stack pStack < the bottom of stack tMenuBar and the right of stack pStack < the right of stack tMenuBar + 5 then
      set the top of stack pStack to the bottom of stack tMenuBar + 20
   end if
end revIDEStackBelowMenuBar

on moveControl
   # IDE to notify any objects subscribed to the ideControlMoved Message
   local tLongID
   put the long id of the target into tLongID
   send "ideMessageSendWithTrigger" &&  "ideControlMoved, tLongID, tLongID" to stack "revIDELibrary" in 0 milliseconds
   pass moveControl
end moveControl

on mouseMove pX, pY
   local tTarget, tParams
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      put pX into tParams[1]
      put pY into tParams[2]
      put tTarget into tParams[3]
      send "ideMessageSendWithParameters" &&  "ideMouseMove, tTarget, tParams" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass mouseMove
end mouseMove

on mouseDown pButton
   local tTarget, tParams
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      put pButton into tParams[1]
      put tTarget into tParams[2]
      send "ideMessageSendWithParameters" &&  "ideMouseDown, tTarget, tParams" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass mouseDown
end mouseDown

on mouseUp pButton
   local tTarget, tParams
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      put pButton into tParams[1]
      put tTarget into tParams[2]
      send "ideMessageSendWithParameters" &&  "ideMouseUp, tTarget, tParams" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass mouseUp
end mouseUp

on mouseDoubleUp pButton
   local tTarget, tParams
   put the long id of the target into tTarget
   if not revIDEObjectIsOnIDEStack(tTarget) then
      put pButton into tParams[1]
      put tTarget into tParams[2]
      send "ideMessageSendWithParameters" &&  "ideMouseDoubleUp, tTarget, tParams" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass mouseDoubleUp
end mouseDoubleUp

on closeStackRequest
   # IDE to notify any objects subscribed to the ideCloseStackRequest Message
   local tLongID
   -- closeStackRequest is sent to the card, so the owner of the target is the stack
   put the long id of the owner of the target into tLongID
   if not revIDEStackIsIDEStack(tLongID) then   
      send "ideMessageSendWithParameters" &&  "ideCloseStackRequest, tLongID, tLongID" to stack "revIDELibrary" in 0 milliseconds
   end if
   pass closeStackRequest
end closeStackRequest

on msgChanged pHandler, pLine
   local tTarget
   put the long id of the target into tTarget
   -- What the xTalk Academy's code puts goes to the Academy's output (its
   -- stage handles msgChanged after this), so it does not open the
   -- Message Box over the lesson
   if tTarget contains "stack" && quote & "revAcademyStage" & quote then
      pass msgChanged
   end if

   local tParams
   put tTarget into tParams[1]
   put pHandler into tParams[2]
   put pLine into tParams[3]
   put msg into tParams[4]
   send "ideMessageSendWithParameters" &&  "ideMsgChanged, tTarget, tParams" to stack "revIDELibrary" in 0 milliseconds
   pass msgChanged
end msgChanged

on logChanged pLog
   send "ideMessageSend ideExtensionLog, pLog" to stack "revIDELibrary" in 0 milliseconds
end logChanged

on desktopChanged
   send "ideMessageSend ideDesktopChanged" to stack "revIDELibrary" in 0 milliseconds
   pass desktopChanged
end desktopChanged

-- OXT-Beyond: the desktop switched between light and dark (macOS and
-- Windows, and on Linux a change of GTK theme): the palettes that chose
-- their colours when they were drawn (the Tools palette, the Project
-- Browser, the menu bar) subscribe to ideSystemAppearanceChanged
--
-- The engine sends the message once, to the current card of
-- the defaultStack, and in the IDE that is often one of the IDE's own
-- stacks (the palettes and editors set it as they work), so a handler in
-- the user's card or stack only ran when the switch came while that stack
-- happened to be the default (bwmilby, openxtalk.org p=25665). When the
-- message comes to an IDE stack, it is also sent to the current card of
-- the frontmost open stack that is not the IDE's, as a standalone sends it
-- to its own stack, but only when that card, its stack or its mainstack
-- (or one of their behaviors) handles it: a handler in a library or
-- backscript has already had this one
on systemAppearanceChanged
   local tCard
   send "ideMessageSend ideSystemAppearanceChanged" to stack "revIDELibrary" in 0 milliseconds
   if revIDEObjectIsOnIDEStack(the long id of the target) then
      put ideUserCardForSystemAppearance() into tCard
      if tCard is not empty then
         send "systemAppearanceChanged" to tCard in 0 milliseconds
      end if
   end if
   pass systemAppearanceChanged
end systemAppearanceChanged

-- The current card of the frontmost open stack that is not the IDE's, if
-- it, its stack or its mainstack handles systemAppearanceChanged
private function ideUserCardForSystemAppearance
   local tStack, tCard, tKind, tObject
   repeat for each line tStack in the openStacks
      if revIDEStackNameIsIDEStack(tStack) or there is not a stack tStack then
         next repeat
      end if
      put the long id of this card of stack tStack into tCard
      repeat for each item tKind in "card,stack,mainstack"
         switch tKind
            case "card"
               put tCard into tObject
               break
            case "stack"
               put the long id of stack tStack into tObject
               break
            default
               put the long id of stack (the mainStack of stack tStack) into tObject
               break
         end switch
         if ideHandlesSystemAppearance(tObject) then
            return tCard
         end if
      end repeat
      return empty
   end repeat
   return empty
end ideUserCardForSystemAppearance

-- Whether the script of pObject, or of its behavior (and theirs, in turn),
-- has an "on systemAppearanceChanged" handler
private function ideHandlesSystemAppearance pObject
   local tDepth
   put 0 into tDepth
   repeat while pObject is not empty and tDepth < 10
      if not exists(pObject) then
         exit repeat
      end if
      if ideScriptHandlesSystemAppearance(the script of pObject) then
         return true
      end if
      put the behavior of pObject into pObject
      add 1 to tDepth
   end repeat
   return false
end ideHandlesSystemAppearance

private function ideScriptHandlesSystemAppearance pScript
   local tLine
   repeat for each line tLine in pScript
      if word 1 of tLine is "on" and word 2 of tLine is "systemAppearanceChanged" then
         return true
      end if
   end repeat
   return false
end ideScriptHandlesSystemAppearance
