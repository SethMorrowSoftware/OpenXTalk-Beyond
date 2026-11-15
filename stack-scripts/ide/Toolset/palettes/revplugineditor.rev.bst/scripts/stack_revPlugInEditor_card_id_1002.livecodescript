script "stack_revPlugInEditor_card_id_1002"
-- Stack file: ide/Toolset/palettes/revplugineditor.rev
-- Object: stack "revPlugInEditor" > card (id 1002)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on preopencard
   revIDESubscribe "idePluginsChanged"
   -- refresh the list of plugins
   revIDEUpdatePlugins
   idePluginsChanged
   
   lock messages
   set the changedStacksList of this stack to empty
   unlock messages
   send ("menuPick" && quote & line 1 of button "List" & quote) to button "List"
end preOpenCard

on idePluginsChanged
   local tPluginsA
   put revIDEPlugins() into tPluginsA
   
   local tStackPaths, tFullList, tFullStackPaths, tPlugin
   
   put the keys of tPluginsA into tFullList
   sort tFullList
   repeat for each line tPluginName in tFullList
      put tPluginsA[tPluginName] into tPlugin
      if tPlugin["menu"] then
         if tStackPaths is empty then
            put tPlugin["path"] into tStackPaths
         else
            put return & tPlugin["path"] after tStackPaths
         end if
      end if
      if tFullStackPaths is empty then
         put tPlugin["path"] into tFullStackPaths
      else
         put return & tPlugin["path"] after tFullStackPaths
      end if
   end repeat

   set the cMenuList of button "list" of stack "revPlugInEditor" to tStackPaths -- just main menu bar
   set the text of button "list" of stack "revPlugInEditor" to tFullList
   set the cStacksList of button "list" of stack "revPlugInEditor" to tFullStackPaths -- all including hidden
end idePluginsChanged

on closeStack
    global gREVStacksList, gREVMessageDispatch
    local tSavedStackVersion
    local tOpenList
    local tLoadArray
    
    -- save plugins that have changed settings
    if the changedStacksList of this stack is not empty then
        repeat for each line thisPluginPath in the changedStacksList of this stack
            -- OXT-Beyond: saved as before; where the plugin's stack cannot
            -- be saved (an install for all users), its settings are kept
            -- in the user's preferences instead
            revIDESavePluginSettings thisPluginPath
        end repeat
        set the changedStacksList of this stack to empty
    end if
    revIDEUpdatePlugins
    put empty into gREVStacksList
    put empty into gREVMessageDispatch
    put the openStacks into tOpenList
    repeat for each line l in tOpenList
        if char 1 to 3 of l is "rev" then
            if the cREVGetsUpdate of stack l is true then put l & cr after gREVStacksList
            put the customProperties["cREVLoadInfo"] of stack l into tLoadArray
            repeat for each line x in keys(tLoadArray)
                if tLoadArray[x] is true and l is not among the lines of gREVMessageDispatch[x] then put l into line (the number of lines in gREVMessageDispatch[x]+1) of gREVMessageDispatch[x]
            end repeat
        end if
    end repeat
    delete last char of gREVStacksList
    
    revIDEUnsubscribeAll
end closeStack

function currentPluginPath
  return line (the menuHistory of btn "List") of the cStacksList of btn "list"
end currentPluginPath
