script "org.openxtalk.plugin.xtalkchat"
-- OXT-Beyond: xTalk Chat, a chat between the people using xTalk who choose
-- to go online: public rooms, who is online now, and private messages.
--
-- It connects to nothing until the user asks. The IDE loads this stack as
-- it loads every extension, and that is all that happens at start: the
-- core and the window are not loaded and no socket is opened. The only
-- thing it adds is the "xTalk Chat" item of Development > Plugins
-- (revmenubar.livecodescript), which opens the window; the window shows a
-- welcome that says what goes to the relays and who can read it, and
-- nothing connects until the user presses Go online there. Someone who was
-- online when they last closed the window goes online again when they next
-- open it; Go offline (or the power button) ends that. Set the environment
-- variable OXTBEYOND_XTALK_CHAT to "off" to keep it off for good, for
-- example on the computers of a classroom.
--
-- How it works: over Nostr, through the xTalk Suite extensions OXT-Beyond
-- ships built in (NostrXT for events and relays, CoinXT for keys and
-- signatures, SodiumXT for encryption), on public relays, so there is no
-- server of ours. The rooms are NIP-28 channels, who is online is an
-- ephemeral event every 45 seconds, and private messages are NIP-17 (sealed
-- and gift wrapped, so relays see neither who wrote them nor what they
-- say). xtalkchat-core.livecodescript has the details.
--
-- Files: this stack (the plugin's lifecycle, its preferences and the IDE
-- glue), xtalkchat-core.livecodescript (identity, relays, rooms, presence,
-- private messages; tested by tests/lcs/xtalkchat) and
-- xtalkchat-window.livecodescript (the window's behavior, which wears
-- Learn's look through revLearnKit).
--
-- Public handlers (reached with dispatch, from the menu bar and the window):
--    xtalkChatMenuPick         Development > Plugins > xTalk Chat
--    xtchPref(), xtchSetPref   the window's preferences
--    xtchWindowClosed          the window was closed
--    xtchIsLockedOff()

constant kWindow = "revXTalkChat"
constant kTitle = "xTalk Chat"
constant kCore = "org.openxtalk.plugin.xtalkchat-core"
constant kWindowBehavior = "org.openxtalk.plugin.xtalkchat-window"
constant kKit = "revLearnKit"
-- Preferences (custom properties of the revPreferences stack), each
-- "cXTalkChat," & a name the window uses
constant kPrefPrefix = "cXTalkChat,"
constant kPrefNames = "autoOnline,showClient,relays,muted,lastView"

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   -- Part of the IDE, not of the user's work
   set the _ideoverride of me to true
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if
   xtchShutDown
end extensionFinalize

function xtchIsLockedOff
   return toLower($OXTBEYOND_XTALK_CHAT) is among the items of "off,0,false,no"
end xtchIsLockedOff

command xtalkChatMenuPick
   local tError
   if xtchIsLockedOff() then
      answer information "xTalk Chat is turned off on this computer (by the environment variable OXTBEYOND_XTALK_CHAT)." titled kTitle
      exit xtalkChatMenuPick
   end if
   if there is a stack kWindow and the mode of stack kWindow is not 0 then
      go stack kWindow
      exit xtalkChatMenuPick
   end if
   try
      xtchLoadParts
   catch tError
      answer error "xTalk Chat could not start:" && xtchErrorText(tError) titled kTitle
      exit xtalkChatMenuPick
   end try
   xtchOpenWindow
end xtalkChatMenuPick

-- The engine's error lines, as one line a person can read
private function xtchErrorText pError
   local tLine
   repeat for each line tLine in pError
      set the itemDelimiter to comma
      if item 4 of tLine is not empty and item 4 of tLine is not a number then
         return item 4 to -1 of tLine
      end if
   end repeat
   return line 1 of pError
end xtchErrorText

--------------------------------------------------------------------------------
-- Loading and unloading

-- The core (in use while the window is open), the window's behavior and
-- Learn's kit, which is the behavior's own behavior
private command xtchLoadParts
   local tFolder, tKit
   put xtchPluginFolder() into tFolder
   if there is not a stack kCore then
      get the short name of stack (tFolder & "/xtalkchat-core.livecodescript")
   end if
   set the _ideoverride of stack kCore to true
   if the long id of stack kCore is not among the lines of xtchStacksInUse() then
      start using stack kCore
   end if
   if there is not a stack kWindowBehavior then
      get the short name of stack (tFolder & "/xtalkchat-window.livecodescript")
   end if
   set the _ideoverride of stack kWindowBehavior to true
   if there is not a stack kKit then
      put xtchKitFile() into tKit
      if tKit is empty then
         throw "Learn's kit (revlearnkit.livecodescript) is not in this IDE"
      end if
      get the short name of stack tKit
   end if
   if the behavior of stack kWindowBehavior is not the long id of stack kKit then
      set the behavior of stack kWindowBehavior to the long id of stack kKit
   end if
end xtchLoadParts

-- Where Learn's kit is: in the Toolset beside Extensions, in a source tree
-- and an installed IDE alike
private function xtchKitFile
   local tFile, tToolset, tError
   set the itemDelimiter to slash
   put item 1 to -3 of xtchPluginFolder() & "/Toolset/palettes/learn/revlearnkit.livecodescript" into tFile
   if there is a file tFile then
      return tFile
   end if
   try
      put revEnvironmentToolsetPath() into tToolset
   catch tError
   end try
   if tToolset is not empty and there is a file (tToolset & "/palettes/learn/revlearnkit.livecodescript") then
      return tToolset & "/palettes/learn/revlearnkit.livecodescript"
   end if
   return empty
end xtchKitFile

-- The window goes, then the core: the chat is offline once this is done
private command xtchShutDown
   local tError
   if there is a stack kWindow then
      try
         close stack kWindow
      catch tError
      end try
   end if
   if there is a stack kWindow then
      delete stack kWindow
   end if
   xtchStopCore
end xtchShutDown

private command xtchStopCore
   local tError
   if there is not a stack kCore then
      exit xtchStopCore
   end if
   if the long id of stack kCore is among the lines of xtchStacksInUse() then
      try
         xtcGoOffline
      catch tError
      end try
      stop using stack kCore
   end if
end xtchStopCore

private function xtchStacksInUse
   local tList, tName
   repeat for each line tName in the stacksInUse
      if there is a stack tName then
         put the long id of stack tName & return after tList
      end if
   end repeat
   return tList
end xtchStacksInUse

private function xtchPluginFolder
   set the itemDelimiter to slash
   return item 1 to -2 of the effective filename of me
end xtchPluginFolder

--------------------------------------------------------------------------------
-- The window

-- Made here rather than shipped as a binary stack, so that all of the
-- plugin is text. Its name begins with "rev", so the IDE treats it as one
-- of its own windows. The behavior draws everything on preOpenStack.
private command xtchOpenWindow
   local tOldDefault
   if there is not a stack kWindow then
      put the defaultStack into tOldDefault
      lock screen
      lock messages
      create invisible stack kWindow
      set the _ideoverride of stack kWindow to true
      set the title of stack kWindow to kTitle
      set the resizable of stack kWindow to true
      set the destroyStack of stack kWindow to true
      set the destroyWindow of stack kWindow to true
      set the behavior of stack kWindow to the long id of stack kWindowBehavior
      unlock messages
      if tOldDefault is not empty and there is a stack tOldDefault then
         set the defaultStack to tOldDefault
      end if
      unlock screen
   end if
   modeless stack kWindow
   set the visible of stack kWindow to true
end xtchOpenWindow

-- The window closed: it went offline itself (closeStack), and the core is
-- let go, so the IDE carries nothing of the chat until it opens again
on xtchWindowClosed
   send "xtchStopCoreLater" to me in 0 milliseconds
end xtchWindowClosed

-- (sent, so that the window's closeStack finishes with the core in use;
-- a window opened again in between keeps it)
on xtchStopCoreLater
   if there is a stack kWindow and the mode of stack kWindow is not 0 then
      exit xtchStopCoreLater
   end if
   xtchStopCore
end xtchStopCoreLater

--------------------------------------------------------------------------------
-- Preferences

function xtchPref pName
   if pName is not among the items of kPrefNames then
      return empty
   end if
   return revIDEGetPreference(kPrefPrefix & pName)
end xtchPref

command xtchSetPref pName, pValue
   if pName is not among the items of kPrefNames then
      exit xtchSetPref
   end if
   revIDESetPreference kPrefPrefix & pName, pValue
end xtchSetPref
