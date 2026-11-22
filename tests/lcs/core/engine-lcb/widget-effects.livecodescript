script "CoreEngineLcbWidgetEffects"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- Widgets draw the graphic effects (dropShadow, innerShadow, outerGlow,
-- innerGlow, colorOverlay), as HyperXTalk's do (HyperXTalk #604). What a
-- script saw before stays as it was: a widget's module that has a property
-- of that name keeps it, and a widget that already holds a custom property
-- of that name keeps reading and setting it.

constant kEffects = "dropShadow,innerShadow,outerGlow,innerGlow,colorOverlay"

on TestSetup
   TestSkipIfNot "lcb"
   TestLoadAuxiliaryExtension "_widget_effects"
   TestLoadExtension "com.livecode.library.widgetutils"
   TestLoadExtension "com.livecode.widget.clock"
end TestSetup

private function __NewStack pName
   create stack pName
   set the defaultStack to pName
   return the long id of stack pName
end __NewStack

on TestEffectsAreTheEngines
   local tWidget, tEffect
   get __NewStack("WidgetEffects1")
   create widget "Clock" as "com.livecode.widget.clock"
   put it into tWidget
   repeat for each item tEffect in kEffects
      TestAssert tEffect && "starts unset, as on a button", the tEffect of tWidget is empty
      set the tEffect["color"] of tWidget to "255,0,0"
      TestAssert tEffect && "has the color set", the tEffect["color"] of tWidget is "255,0,0"
      TestAssert tEffect && "is an effect, not a custom property", \
            tEffect is not among the lines of the customKeys of tWidget
   end repeat
   set the dropShadow["distance"] of tWidget to 7
   TestAssert "an effect's other parts", the dropShadow["distance"] of tWidget is 7
   set the dropShadow of tWidget to empty
   TestAssert "an effect can be taken off", the dropShadow of tWidget is empty
   delete stack "WidgetEffects1"
end TestEffectsAreTheEngines

on TestEffectsAsOnAButton
   -- The same array as a button's for the same settings
   local tWidget, tButton, tEffect
   get __NewStack("WidgetEffects2")
   create widget "Clock" as "com.livecode.widget.clock"
   put it into tWidget
   create button
   put it into tButton
   repeat for each item tEffect in kEffects
      set the tEffect["color"] of tWidget to "0,128,255"
      set the tEffect["color"] of tButton to "0,128,255"
      TestAssert tEffect && "is a button's", __ArrayText(the tEffect of tWidget) is __ArrayText(the tEffect of tButton)
   end repeat
   delete stack "WidgetEffects2"
end TestEffectsAsOnAButton

on TestEffectsAreSaved
   local tFile, tEffect
   get __NewStack("WidgetEffects3")
   create widget "Clock" as "com.livecode.widget.clock"
   set the outerGlow["color"] of widget "Clock" to "1,2,3"
   set the dropShadow["distance"] of widget "Clock" to 9
   put specialFolderPath("temporary") & "/widget-effects-" & the milliseconds & ".livecode" into tFile
   save stack "WidgetEffects3" as tFile
   delete stack "WidgetEffects3"
   go invisible stack tFile
   TestAssert "outerGlow is kept in the file", the outerGlow["color"] of widget "Clock" of stack "WidgetEffects3" is "1,2,3"
   TestAssert "dropShadow is kept in the file", the dropShadow["distance"] of widget "Clock" of stack "WidgetEffects3" is 9
   delete stack "WidgetEffects3"
   delete file tFile
end TestEffectsAreSaved

on TestEffectsInTheProperties
   local tWidget, tProps
   get __NewStack("WidgetEffects4")
   create widget "Clock" as "com.livecode.widget.clock"
   put it into tWidget
   set the innerGlow["color"] of tWidget to "4,5,6"
   put the properties of tWidget into tProps
   TestAssert "the properties has innerGlow", tProps["innerGlow"]["color"] is "4,5,6"
   delete stack "WidgetEffects4"
end TestEffectsInTheProperties

on TestEffectsDrawn
   -- A widget with a drop shadow draws outside its square; without one, the
   -- same snapshot is the same as before the effect was set
   local tWidget, tPlain, tShadowed
   get __NewStack("WidgetEffects5")
   set the backgroundColor of this stack to white
   create widget "Box" as "com.livecode.lcs_tests.core.engine_lcb.widget_effects"
   put it into tWidget
   set the rect of tWidget to 20,20,80,80
   export snapshot from rect "0,0,120,120" of this card to tPlain as PNG
   set the dropShadow["color"] of tWidget to "0,0,0"
   set the dropShadow["distance"] of tWidget to 10
   set the dropShadow["size"] of tWidget to 0
   set the dropShadow["opacity"] of tWidget to 255
   export snapshot from rect "0,0,120,120" of this card to tShadowed as PNG
   TestAssert "the drop shadow is drawn", tPlain is not tShadowed
   set the dropShadow of tWidget to empty
   export snapshot from rect "0,0,120,120" of this card to tShadowed as PNG
   TestAssert "and taken off again", tPlain is tShadowed
   delete stack "WidgetEffects5"
end TestEffectsDrawn

-- What scripts saw before stays as it was

on TestModulePropertyKept
   local tWidget
   get __NewStack("WidgetEffects6")
   create widget "Box" as "com.livecode.lcs_tests.core.engine_lcb.widget_effects"
   put it into tWidget
   TestAssert "the module's outerGlow is read", the outerGlow of tWidget is "the module's"
   set the outerGlow of tWidget to "set by script"
   TestAssert "the module's outerGlow is set", the outerGlow of tWidget is "set by script"
   -- the module has no dropShadow, so that one is the engine's
   set the dropShadow["color"] of tWidget to "9,9,9"
   TestAssert "the other effects are the engine's", the dropShadow["color"] of tWidget is "9,9,9"
   delete stack "WidgetEffects6"
end TestModulePropertyKept

on TestCustomPropertyKept
   -- Before, a widget kept an effect set on it as a custom property, which
   -- nothing drew. A widget that holds one goes on reading and setting it
   local tWidget, tValue, tProps
   get __NewStack("WidgetEffects7")
   create widget "Clock" as "com.livecode.widget.clock"
   put it into tWidget
   put "older" into tValue["color"]
   put tValue into tProps["dropShadow"]
   set the customProperties of tWidget to tProps
   get the dropShadow of tWidget
   TestAssert "the custom property is read", it["color"] is "older"
   put "newer" into tValue["color"]
   set the dropShadow of tWidget to tValue
   put the customProperties of tWidget into tProps
   TestAssert "the custom property is set", tProps["dropShadow"]["color"] is "newer"
   -- An index went no further than the name, as before (the earlier build
   -- gives the same): the whole custom property is got, and set
   get the dropShadow["color"] of tWidget
   TestAssert "an index gets the whole of it, as before", it["color"] is "newer"
   set the dropShadow["color"] of tWidget to "newest"
   put the customProperties of tWidget into tProps
   TestAssert "and sets the whole of it, as before", tProps["dropShadow"] is "newest"
   -- and the other effects, which it does not hold, are the engine's
   set the innerGlow["color"] of tWidget to "1,1,1"
   TestAssert "innerGlow is the engine's", "innerGlow" is not among the lines of the customKeys of tWidget
   delete stack "WidgetEffects7"
end TestCustomPropertyKept

on TestOtherCustomPropertiesAsBefore
   local tWidget
   get __NewStack("WidgetEffects8")
   create widget "Clock" as "com.livecode.widget.clock"
   put it into tWidget
   set the cMine of tWidget to "x"
   TestAssert "a custom property of another name", the cMine of tWidget is "x"
   delete stack "WidgetEffects8"
end TestOtherCustomPropertiesAsBefore

private function __ArrayText pArray
   local tKeys, tKey, tText
   put the keys of pArray into tKeys
   sort lines of tKeys
   repeat for each line tKey in tKeys
      put tKey & "=" & pArray[tKey] & return after tText
   end repeat
   return tText
end __ArrayText
