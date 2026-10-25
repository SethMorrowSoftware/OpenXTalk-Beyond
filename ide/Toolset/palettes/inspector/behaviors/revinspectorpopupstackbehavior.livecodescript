script "revInspectorPopupStackBehavior"
local sTarget

on setAsBehavior pTarget
   dispatch "setAsBehavior" to revIDEInspectorBehavior() with the long id of this me
   set the behavior of pTarget to the long id of this me
end setAsBehavior

on preOpenStack
   local tMargin
   put the paletteMargin of me into tMargin
   lock messages
   set the style of the templatebutton to "standard"
   set the width of the templatebutton to "82"
   set the height of the templatebutton to "22"
   set the traversalon of the templatebutton to true
   set the default of the templatebutton to true
   create button "OK"
   
   // In LC 9.0 DP-7 you can resize the inspector window, by putting all the contents in a group "inspector" 
   // and adding a vScrollbar to the group
   // but 'modeless stack X' breaks the vScrollbar of groups, so ensure the popup stack has the correct 
   // height before going 'modeless'
   set the height of me to the formattedHeight of group "inspector" of me + 2 * tMargin
   set the topright of button "OK" to the width of me -  tMargin, the height of me 
   set the resizable of me to false
   set the height of me to the height of me + the height of button "OK" of me + tMargin
   
   reset the templatebutton
   
   -- this is a bit of a cheat, but stops input
   -- set the decorations of me to none -- not needed now
   set the style of me to modeless -- was modal, tperry 25-11-2025
   if the name of this stack contains "Gradient" then
      send delayshowMe to this stack in 1 milliseconds
   end if
   --
   
   
   unlock messages
end preOpenStack

on openStack
   lock screen
   lock messages
   ensureOnScreen
   show me
   unlock messages
   unlock screen
end openStack

on delayshowMe
   show this stack
   go this stack
   -- OXT-Beyond: placed as ensureOnScreen places it (this set its left
   -- to the right of the topstack, which by now is this stack: it moved
   -- across by its own width, and onto the object being edited)
   ensureOnScreen
end delayshowMe

on ensureOnScreen
   if there is a stack "revPropertyInspector 1" then
      -- OXT-Beyond: beside the inspector, where it covers neither the
      -- inspector nor, when there is room, the object being edited
      -- (richmond62 on rc.6.3: the Stroke gradient dialog opened on top of
      -- the graphic); only where nothing fits, over the inspector as before
      if placeBesideInspector() then exit ensureOnScreen
      -- appear like a modal dialog if the inspector is open -- tperry 10-01-2025
      set the loc of me to the loc of stack "revPropertyInspector 1"
   else
      if (the right of revIDEStackOfObject(sTarget) + 5 + the width of me) < item 3 of the screenrect then
         set the left of me to the right of revIDEStackOfObject(sTarget) + 5
      else
         set the right of me to the left of revIDEStackOfObject(sTarget) - 5
      end if
   end if
end ensureOnScreen

-- Beside the inspector, never over it (a popup behind the inspector was
-- lost there, which revInspectorBehavior's gluetoLeft was made for): to
-- its right, else its left, at its top (moved to stay on the screen), else
-- below it or above it, at its left; a place is taken only when the
-- window fits on the screen there and does not cover the object the
-- inspector shows. If every place that fits covers it, to the inspector's
-- left as before, else its right. The screen is the one the inspector is
-- on. True when one was taken.
private function placeBesideInspector
   local tInspector, tScreen, tAvoid, tW, tH, tTop, tLeft, tRect, tPlace, tPass, tPlaces
   put the rect of stack "revPropertyInspector 1" into tInspector
   put line (the screen of stack "revPropertyInspector 1") of the working screenRects into tScreen
   if the number of items of tScreen is not 4 then put the working screenRect into tScreen
   put objectScreenRect() into tAvoid
   put the width of me into tW
   put the height of me into tH
   put max(item 2 of tScreen, min(item 2 of tInspector, item 4 of tScreen - tH)) into tTop
   put max(item 1 of tScreen, min(item 1 of tInspector, item 3 of tScreen - tW)) into tLeft
   repeat for each item tPass in "avoid,any"
      if tPass is "avoid" then
         put "right,left,below,above" into tPlaces
      else
         put "left,right" into tPlaces
      end if
      repeat for each item tPlace in tPlaces
         switch tPlace
            case "right"
               put item 3 of tInspector + 5, tTop, item 3 of tInspector + 5 + tW, tTop + tH into tRect
               break
            case "left"
               put item 1 of tInspector - 5 - tW, tTop, item 1 of tInspector - 5, tTop + tH into tRect
               break
            case "below"
               put tLeft, item 4 of tInspector + 5, tLeft + tW, item 4 of tInspector + 5 + tH into tRect
               break
            case "above"
               put tLeft, item 2 of tInspector - 5 - tH, tLeft + tW, item 2 of tInspector - 5 into tRect
               break
         end switch
         if item 1 of tRect < item 1 of tScreen or item 3 of tRect > item 3 of tScreen or \
               item 2 of tRect < item 2 of tScreen or item 4 of tRect > item 4 of tScreen then
            next repeat
         end if
         if tPass is "avoid" and tAvoid is not empty and rectsOverlap(tRect, tAvoid) then next repeat
         set the rect of me to tRect
         return true
      end repeat
   end repeat
   return false
end placeBesideInspector

-- Where on the screen the selected object is, or empty; kept from the
-- first time, as the selection can be gone by the time the gradient
-- popup is shown (its window took the focus)
local sObjectScreenRect
private function objectScreenRect
   local tObject, tStack, tRect
   put line 1 of revIDESelectedObjects() into tObject
   if tObject is empty or not exists(tObject) then return sObjectScreenRect
   put revIDEStackOfObject(tObject) into tStack
   if tStack is empty or not exists(tStack) then return sObjectScreenRect
   if word 1 of tObject is "stack" then
      put the rect of tStack into sObjectScreenRect
   else
      put the rect of tObject into tRect
      put item 1 of tRect + the left of tStack, item 2 of tRect + the top of tStack, \
            item 3 of tRect + the left of tStack, item 4 of tRect + the top of tStack into sObjectScreenRect
   end if
   return sObjectScreenRect
end objectScreenRect

private function rectsOverlap pA, pB
   return item 1 of pA < item 3 of pB and item 1 of pB < item 3 of pA and \
         item 2 of pA < item 4 of pB and item 2 of pB < item 4 of pA
end rectsOverlap

on closeStack
   set the destroystack of me to true
   send "popupDismissed" to sTarget in 0 millisecs
end closeStack

on editorValueChanged pProperty, pValue, pLockUpdates
   try
      dispatch "valueChanged" to sTarget with pProperty, pValue
   catch tError
      if exists(sTarget) then
         send "popupDismissed" to sTarget in 0 millisecs
      end if
   end try
end editorValueChanged

on mouseUp
   if the long id of the target is the long id of button "OK" of me then
      send "popupDismissed" to sTarget in 0 millisecs
      set the destroystack of me to true
      close this stack
   end if
end mouseUp

setProp editorTarget pTarget
   put pTarget into sTarget
end editorTarget
