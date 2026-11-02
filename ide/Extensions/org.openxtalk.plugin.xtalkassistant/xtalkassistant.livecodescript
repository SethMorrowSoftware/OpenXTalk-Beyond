script "org.openxtalk.plugin.xtalkassistant"
-- OXT-Beyond: the xTalk Assistant, an optional AI assistant for writing
-- scripts, with the user's own API key.
--
-- Off by default. The IDE loads this stack as it loads every extension, and
-- while the assistant is off that is all that happens: this stack is not in
-- the message path, the core and the window are not loaded, and nothing
-- talks to the network. The only thing it adds is the "xTalk Assistant"
-- item of Development > Plugins (revmenubar.livecodescript), which asks
-- the user before turning the assistant on. Set the environment variable
-- OXTBEYOND_XTALK_ASSISTANT to "off" to keep it off for good, for example on
-- the computers of a classroom.
--
-- What it does: a window to talk to the model the user picks, from
-- Anthropic or OpenAI (or any service or local server with OpenAI's API),
-- with the script open in the Script Editor attached when the user wants,
-- and a button that inserts the xTalk code of the answer at the caret in
-- the Script Editor as one undoable step. The model is given the guide
-- (xtalk-guide.md, in this folder) and the notes the user keeps for it (its
-- memory, a file in the preferences folder). Every xTalk block of an answer
-- is compiled before the user reads it, and one that does not compile goes
-- back to the model with the errors, a few rounds at most (the "fix
-- rounds"). The model can ask for tools that read: the Dictionary, a
-- compile check, the user's stack (after the user allows it), the last
-- error the IDE showed the user, which a front script notes while the
-- assistant is on (xtalkassistant-errors.livecodescript), and where a
-- script paused in the debugger is. And it can ask for tools that build
-- and run (xtalkassistant-build.livecodescript): a batch of changes to the
-- user's stack (controls, cards, a new stack, properties, scripts), and
-- code to run in a sandbox or on the stack. Nothing changes and nothing
-- runs until the user says yes, in a bar the window shows: Apply for
-- changes, every time; Run for code, which the user can allow for the
-- session (code that reaches files, the network or other programs is
-- always asked about). Undo, next to what was applied in the
-- conversation, takes it back exactly, and a run on the stack goes back
-- to the checkpoint saved before it. The Settings switch "Let the model
-- change stacks and run code" takes those two tools away.
--
-- The key: what the user types or pastes in the Settings dialog is kept in
-- memory until the IDE quits or the user forgets it, and is never written
-- to the preferences, a stack or a log. Without one, ANTHROPIC_API_KEY or
-- OPENAI_API_KEY from the environment is used when it is set. Everything
-- else the dialog sets (the provider, model and base URL, the longest
-- answer, how long to wait, the fix rounds, the tools, the short guide,
-- whether the open script goes with a question) is a preference.
--
-- Files: this stack (the plugin's lifecycle, its settings, its windows
-- and the IDE glue), xtalkassistant-core.livecodescript (JSON, the
-- providers, HTTP, the compile checks, the memory and what the tools
-- read), xtalkassistant-build.livecodescript (what the tools that build
-- and run do, and Undo; both tested by tests/lcs/xtalkassistant),
-- xtalkassistant-window.livecodescript (the window's behavior),
-- xtalkassistant-settings.livecodescript (the Settings dialog's),
-- xtalkassistant-errors.livecodescript (the error hook) and
-- xtalk-guide.md (the guide).
--
-- The windows wear the look of the IDE's learning windows (Learn, Home,
-- About, xTalk Chat and the IDE's own dialogs): a dark header with the
-- violet mark and the title, one status line under it, white panels with
-- a hairline on slate, flat buttons, and code on Learn's dark code panel
-- in Learn's colours. Learn's kit (revLearnKit) is matched here by value
-- (xtaUi...), not used, so that the plugin package needs nothing of the
-- IDE's to draw itself; the layout is the one the windows had in the
-- xTalk Suite's look before (0.2.7-rc.5), so every control is where it
-- was and is named as it was.
--
-- Public handlers (all reached with dispatch, from the menu bar and the
-- window):
--    xtalkAssistantMenuPick       Development > Plugins > xTalk Assistant
--    xtaSendPrompt, xtaSendOrStop, xtaInsertCode, xtaNewConversation,
--    xtaChooseModels, xtaSetIncludeScript, xtaSetProviderByName, xtaSetModel,
--    xtaMoreMenuPick, xtaNoteClicked, xtaConversationLink, xtaAnswerAsk,
--    xtaWindowClosed,
--    xtaSettingsSave, xtaSettingsGetModels, xtaSettingsForgetKey,
--    xtaSettingsProvider, xtaSettingsLocal, xtaSettingsService
--                                 (the Settings dialog)
--    xtaSettingsPrepare, xtaSettingsDone()   (before and after it)
--    xtaIsEnabled()

constant kWindow = "revXTalkAssistant"
constant kTitle = "xTalk Assistant"
constant kCore = "org.openxtalk.plugin.xtalkassistant-core"
constant kBuild = "org.openxtalk.plugin.xtalkassistant-build"
constant kWindowBehavior = "org.openxtalk.plugin.xtalkassistant-window"
constant kErrorHook = "org.openxtalk.plugin.xtalkassistant-errors"
constant kSettingsWindow = "revXTalkAssistantSettings"
constant kSettingsBehavior = "org.openxtalk.plugin.xtalkassistant-settings"
-- What a package of this plugin for another xTalk's IDE carries
-- (tools/plugins); OXT-Beyond's own copy has no such file
constant kCompat = "org.openxtalk.plugin.xtalkassistant-compat"
-- Preferences (custom properties of the revPreferences stack)
constant kPrefEnabled = "cXTalkAssistant,enabled"
constant kPrefProvider = "cXTalkAssistant,provider"
constant kPrefModel = "cXTalkAssistant,model,"
constant kPrefBaseUrl = "cXTalkAssistant,baseUrl,"
constant kPrefIncludeScript = "cXTalkAssistant,includeScript"
constant kPrefFixRounds = "cXTalkAssistant,fixRounds"
constant kPrefShortGuide = "cXTalkAssistant,shortGuide"
constant kPrefTools = "cXTalkAssistant,tools"
constant kPrefMaxTokens = "cXTalkAssistant,maxTokens"
constant kPrefTimeout = "cXTalkAssistant,timeout"
constant kPrefBuild = "cXTalkAssistant,build"
constant kPrefPictures = "cXTalkAssistant,pictures"
-- The most of the open script that is sent with a question, in characters
constant kMaxScriptChars = 60000
-- How many times, by default and at most, code that does not compile goes
-- back to the model for each question
constant kDefaultFixRounds = 5
constant kMaxFixRounds = 10
-- How many tools the model may use for one question: building a stack,
-- trying it and correcting it takes more than reading did
constant kMaxToolCalls = 25
-- The most room an answer cut off at its length limit is asked for again
-- with, in tokens (xtaMoreRoom). Answers are not streamed: one this long
-- takes several minutes to arrive.
constant kMostRoom = 32000
-- The limits of the Settings dialog's numbers: the longest answer, in
-- tokens (the provider refuses more than its model takes, and says so),
-- and how many seconds a request may go without data
constant kMaxMaxTokens = 1000000
-- What an empty wait means, as the core's kRequestTimeoutMilliseconds: at
-- least that, and longer for an answer given more room (xtaRequestWait)
constant kDefaultTimeout = 600
constant kMinTimeout = 10
constant kMaxTimeout = 3600
constant kGuideFile = "xtalk-guide.md"
-- The memory's file, in the user's preferences folder
constant kMemoryFile = "xTalk Assistant Memory.txt"
constant kMemoryWindow = "revXTalkAssistantMemory"
-- The tools that change, run or save something, which the Settings
-- switch takes away
constant kBuildTools = "make_changes,run_code,save_stack"
-- How many of the changes of a batch the conversation lists under it,
-- and of the lines a run put into the Message Box
constant kShownChanges = 8
constant kShownOutput = 6
-- How often the activity row under the conversation is redrawn while the
-- assistant works (its clock and its spinner), in milliseconds
constant kTickMilliseconds = 125
-- The longest side of a picture of a card (look_at_card), in pixels, and
-- how many of the newest pictures go with each request (an older one is
-- left out, as the model has seen it already)
constant kPictureSide = 1024
constant kKeptPictures = 2

-- Learn's colours, by value (revLearnKit's lkColor): the page, the
-- panels and their hairline, the accent (violet) and the header's text,
-- the inks, the status colours, the entry fields' line, the code panel's
-- ground, its head and its ink, and the ground of a tool's output
constant kUiBg = "241,245,249"
constant kUiCard = "255,255,255"
constant kUiCardLine = "226,232,240"
constant kUiAccent = "124,58,237"
constant kUiAccentText = "255,255,255"
constant kUiAccentSub = "203,213,225"
constant kUiInk = "15,23,42"
constant kUiInkSoft = "71,85,105"
constant kUiMuted = "100,116,139"
constant kUiOk = "22,163,74"
constant kUiWarn = "180,83,9"
constant kUiBad = "220,38,38"
constant kUiFieldLine = "203,213,225"
constant kUiCodeBg = "15,23,42"
constant kUiCodeHead = "30,41,59"
constant kUiCodeInk = "226,232,240"
constant kUiOutputBg = "241,245,249"
-- The header's gradient (Learn's), the tint under the user's questions,
-- and inline code (a violet tint, as Learn shows a word of code in text)
constant kUiHeadFrom = "15,23,42"
constant kUiHeadTo = "36,27,82"
constant kUiTint = "245,243,255"
constant kUiInlineBg = "237,233,254"
constant kUiInlineInk = "91,33,182"
-- The header, and the windows' sizes (each fits 1200 x 640, a 720p
-- screen, as the xTalk Suite's kit asked)
constant kUiBand = 44
constant kWindowWidth = 560
constant kWindowHeight = 640
constant kSettingsWidth = 640
constant kMemoryWidth = 480

-- The keys the user typed, by provider. Only ever in memory.
local sKeys
-- The conversation: keys 1 to N, each with "role", "text" (what was typed
-- or answered) and, for a question sent with the open script, "context".
local sTurns
-- True while a question is waiting for its answer
local sBusy
-- Counts the shut-downs, so that an answer that arrives after the assistant
-- was turned off while it waited is dropped rather than kept
local sShutDowns
-- The xTalk blocks of the latest answer that had any (as xtaXTalkBlocks
-- returns them)
local sLastCode
-- The guide, read once from its file
local sGuide
-- True when the user pressed Stop while a question was being answered
local sStopAsked
-- The stacks the user allowed the model to read (by the long id of the main
-- stack), until the assistant is turned off; and those they did not, for
-- the question being answered
local sReadAllowed, sReadRefused
-- The models of a server that refused tools ("provider,model"), which are
-- then asked without them until the assistant is turned off
local sNoTools
-- The model menu each provider's list gave, by provider, until the
-- assistant is turned off (empty: the suggested models are offered)
local sModelMenus
-- While the Settings dialog is open: what was typed for a provider before
-- the dialog was switched to another (by provider: "key", "baseUrl",
-- "model"), and whether Save was pressed
local sDrafts, sSettingsSaved, sSettingsProvider
-- After Save: true when the provider's models are to be asked for (a new
-- key, base URL or provider, or no model, and Get Models did not just)
local sSettingsFetch
-- True once the window has asked for a key this session, so that it asks
-- only once
local sKeyAsked
-- While the window's bar asks the user something: "kind" ("changes", "run"
-- or "read") and "answer" ("yes", "session", "no" or "stop"; empty until
-- one is given)
local sAsk
-- Where the user let code run without asking, until the assistant is
-- turned off: "sandbox", or the long id of a main stack
local sRunAllowed
-- What the user undid since the last question, a line each, to tell the
-- model with the next one
local sUndone
-- While a question is being answered, what the activity row shows: when
-- it began ("start", the milliseconds), what the assistant is doing
-- ("phase", in words, and "kind": "wait" for the model, "tool", "check",
-- "ask" or "stop"), the requests made and their tokens so far
-- ("requests", "in", "out", "cached"), the spinner's angle ("angle") and
-- the pending redraw ("timer", a message id)
local sWork
-- True while the windows wear the dark appearance's colours (xtaUi), and
-- the pending look again at macOS's appearance after a switch, and how
-- many looks are left (xtaRecheckAppearance)
local sUiDark, sAppearanceMsg, sAppearanceTries

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   -- Part of the IDE, not of the user's work
   set the _ideoverride of me to true
   -- In another xTalk's IDE (LiveCode Community 9 and the IDEs built on
   -- it), a package of this plugin (tools/plugins) carries a stack that
   -- gives it the menu item and the Script Editor handlers that IDE lacks.
   -- OXT-Beyond's own copy has no such file, so this does nothing here.
   xtaStartCompat
   -- Turned on in an earlier session: the error hook notes the errors the
   -- user hits from the start, so that they can be explained
   if xtaIsEnabled() then
      try
         xtaStartErrorHook
      catch tError
      end try
   end if
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if
   xtaShutDown
   xtaStopCompat
end extensionFinalize

--------------------------------------------------------------------------------
-- On and off

function xtaIsEnabled
   if xtaIsLockedOff() then
      return false
   end if
   return revIDEGetPreference(kPrefEnabled) is true
end xtaIsEnabled

private function xtaIsLockedOff
   return toLower($OXTBEYOND_XTALK_ASSISTANT) is among the items of "off,0,false,no"
end xtaIsLockedOff

command xtalkAssistantMenuPick
   if xtaIsLockedOff() then
      answer information "The xTalk Assistant is turned off on this computer (by the environment variable OXTBEYOND_XTALK_ASSISTANT)." titled kTitle
      exit xtalkAssistantMenuPick
   end if
   if not xtaIsEnabled() then
      answer question "The xTalk Assistant helps you write scripts with an AI model of your choice, from Anthropic or OpenAI (or a service or local server with OpenAI's API), using your own API key. Or run a model on your own computer, with LM Studio or Ollama, which needs no key (More > Settings..., Local)." & return & return & \
            "When you press Send, what you typed is sent to that provider, with the script open in the Script Editor while" && quote & "Include the open script" & quote && "is ticked (it is to begin with), and nothing else is. Using it may cost money on your account with the provider." & return & return & \
            "It stays off until you turn it on, and you can turn it off again from its window." \
            with "Cancel" or "Turn On" titled kTitle
      if it is not "Turn On" then
         exit xtalkAssistantMenuPick
      end if
      revIDESetPreference kPrefEnabled, true
      xtaOpenWindow
      -- Just turned on: ask for the key now, in the Settings dialog, so the
      -- user sees where it goes (More > Settings... later). Not for a base
      -- URL of the user's own, which is kept when it is turned off and may
      -- need no key, as Send and Models do. Then the provider's models,
      -- which tells the user at once whether the key works, and chooses a
      -- model when none is chosen yet.
      put true into sKeyAsked
      if xtaEnsureKey(xtaProvider()) then
         xtaModelsIfNeeded true
      end if
      exit xtalkAssistantMenuPick
   end if
   xtaOpenWindow
   -- On from an earlier session: the key is asked for (once a session),
   -- and the models fetched when one was just typed or no model is chosen,
   -- as when it is turned on. In 0.2.5-rc.3 the window opened with an
   -- empty model menu and nothing more happened.
   if xtaKey(xtaProvider()) is empty and xtaBaseUrl(xtaProvider()) is empty then
      if sKeyAsked is true then
         exit xtalkAssistantMenuPick
      end if
      put true into sKeyAsked
      if xtaEnsureKey(xtaProvider()) then
         xtaModelsIfNeeded true
      end if
      exit xtalkAssistantMenuPick
   end if
   xtaModelsIfNeeded false
end xtalkAssistantMenuPick

-- The provider's models when no model is chosen yet, or (with
-- pIfNotListed) when its list has not come this session: after a key is
-- typed, they tell the user at once whether it works
private command xtaModelsIfNeeded pIfNotListed
   local tProvider
   put xtaProvider() into tProvider
   if xtaModel(tProvider) is empty or (pIfNotListed and sModelMenus[tProvider] is empty) then
      xtaChooseModels
   end if
end xtaModelsIfNeeded

private command xtaTurnOff
   local tQuestion
   put "Turn the xTalk Assistant off? Its window closes and the API keys you typed are forgotten. You can turn it on again from Development > Plugins." into tQuestion
   if xtaAppliedCount() > 0 then
      put return & return & "The changes it made to your stacks stay as they are, and can no longer be undone from the assistant." after tQuestion
   end if
   answer question tQuestion with "Cancel" or "Turn Off" titled kTitle
   if it is not "Turn Off" then
      exit xtaTurnOff
   end if
   revIDESetPreference kPrefEnabled, false
   xtaShutDown
end xtaTurnOff

-- Forgets everything and unloads what the assistant loaded. The memory's
-- file stays, for the next time it is turned on.
private command xtaShutDown
   add 1 to sShutDowns
   put false into sBusy
   put false into sStopAsked
   put empty into sKeys
   put empty into sTurns
   put empty into sLastCode
   put empty into sGuide
   put empty into sReadAllowed
   put empty into sReadRefused
   put empty into sNoTools
   put empty into sModelMenus
   put empty into sDrafts
   put empty into sKeyAsked
   put empty into sAsk
   put empty into sRunAllowed
   put empty into sUndone
   xtaStopTicking
   put empty into sWork
   xtaStopErrorHook
   if there is a stack kMemoryWindow then
      delete stack kMemoryWindow
   end if
   if there is a stack kSettingsWindow then
      close stack kSettingsWindow
   end if
   if there is a stack kSettingsWindow then
      delete stack kSettingsWindow
   end if
   if there is a stack kWindow then
      close stack kWindow
   end if
   if there is a stack kWindow then
      delete stack kWindow
   end if
   -- The journal goes, with the hidden stacks and the checkpoints: what
   -- was applied stays. While the xTalk MCP Bridge is on they stay too, as
   -- the bridge works with the same libraries and journal (it unloads them
   -- when it is turned off itself): turning the assistant off used to take
   -- away what Claude could still undo.
   if xtaBridgeOn() then
      exit xtaShutDown
   end if
   if there is a stack kBuild and the long id of stack kBuild is among the lines of xtaStacksInUse() then
      xtaBuildCleanup
      stop using stack kBuild
   end if
   if there is a stack kCore and the long id of stack kCore is among the lines of xtaStacksInUse() then
      xtaCheckCleanup
      stop using stack kCore
   end if
end xtaShutDown

-- True while the xTalk MCP Bridge is turned on
private function xtaBridgeOn
   local tOn, tError
   put false into tOn
   if there is a stack "org.openxtalk.plugin.mcpbridge" then
      try
         dispatch function "mcbIsEnabled" to stack "org.openxtalk.plugin.mcpbridge"
         put (the result is true) into tOn
      catch tError
      end try
   end if
   return tOn
end xtaBridgeOn

private function xtaStacksInUse
   local tList, tName
   repeat for each line tName in the stacksInUse
      if there is a stack tName then
         put the long id of stack tName & return after tList
      end if
   end repeat
   return tList
end xtaStacksInUse

-- Loads the core, the library that builds and runs, and the windows'
-- behaviors from this stack's folder.
private command xtaLoadParts
   local tFolder
   put xtaPluginFolder() into tFolder
   if there is not a stack kCore then
      get the short name of stack (tFolder & "/xtalkassistant-core.livecodescript")
   end if
   if the long id of stack kCore is not among the lines of xtaStacksInUse() then
      start using stack kCore
   end if
   if there is not a stack kBuild then
      get the short name of stack (tFolder & "/xtalkassistant-build.livecodescript")
   end if
   if the long id of stack kBuild is not among the lines of xtaStacksInUse() then
      start using stack kBuild
   end if
   set the _ideoverride of stack kBuild to true
   if there is not a stack kWindowBehavior then
      get the short name of stack (tFolder & "/xtalkassistant-window.livecodescript")
   end if
   if there is not a stack kSettingsBehavior then
      get the short name of stack (tFolder & "/xtalkassistant-settings.livecodescript")
   end if
   set the _ideoverride of stack kCore to true
   set the _ideoverride of stack kWindowBehavior to true
   set the _ideoverride of stack kSettingsBehavior to true
   xtaStartErrorHook
end xtaLoadParts

-- Puts the error hook in the front of the message path, where it notes
-- each error the IDE shows the user and passes it on
private command xtaStartErrorHook
   if there is not a stack kErrorHook then
      get the short name of stack (xtaPluginFolder() & "/xtalkassistant-errors.livecodescript")
      set the _ideoverride of stack kErrorHook to true
   end if
   if not (the long id of stack kErrorHook is among the lines of the frontScripts) then
      insert the script of stack kErrorHook into front
   end if
end xtaStartErrorHook

-- Takes the error hook out of the message path, and forgets the errors
private command xtaStopErrorHook
   if there is not a stack kErrorHook then
      exit xtaStopErrorHook
   end if
   if the long id of stack kErrorHook is among the lines of the frontScripts then
      remove the script of stack kErrorHook from front
   end if
   delete stack kErrorHook
end xtaStopErrorHook

--------------------------------------------------------------------------------
-- The window

private command xtaOpenWindow
   local tBuilt, tError
   xtaLoadParts
   if there is not a stack kWindow then
      xtaBuildWindow
      put true into tBuilt
   else
      -- (the desktop may have switched while the window was closed)
      get xtaFollowAppearance()
   end if
   -- Light or dark as the desktop switches (ideSystemAppearanceChanged)
   if there is a stack "revIDELibrary" then
      try
         dispatch "revIDESubscribe" to me with "ideSystemAppearanceChanged"
      catch tError
      end try
   end if
   xtaRefreshWindow
   -- The window is built invisible, and palette keeps a stack's visible as
   -- it is, so it must be shown: without this the window opened hidden and
   -- turning the assistant on seemed to do nothing. A new window opens in
   -- the middle of the screen; one the user has moved stays where it is.
   lock screen
   if tBuilt is true then
      set the loc of stack kWindow to the screenLoc
   end if
   -- Whole on the screen, title bar too: on a small screen (or one scaled
   -- up) the window is made shorter, and one left where a screen no longer
   -- is comes back
   xtaKeepOnScreen the long id of stack kWindow, true
   palette stack kWindow
   set the visible of stack kWindow to true
   -- Closed and opened again while a question is being answered: the new
   -- window shows the activity row too, its spinner and its clock, as the
   -- window showed Stop with nothing moving and seemed to have hung
   if sBusy is true and sWork["start"] is not empty then
      xtaShowActivity true
      xtaStartTicking
   end if
   unlock screen
   focus on field "Prompt" of stack kWindow
end xtaOpenWindow

on xtaWindowClosed
   -- The conversation stays for the next time the window is opened; what
   -- the bar was asking is answered as Stop would
   if sAsk["kind"] is not empty and sAsk["answer"] is empty then
      put "stop" into sAsk["answer"]
   end if
end xtaWindowClosed

-- Builds the window: a stack made here rather than shipped as a binary
-- stack, so that all of the plugin is text. Its name begins with "rev", so
-- the IDE treats it as one of its own windows. It wears the suite's look:
-- the band with the title and, at its right, the pill that says what the
-- assistant is doing; the status line; the conversation on a panel; the
-- bar that asks the user (Ask...), on a panel of its own and hidden until
-- something is asked; flat entry fields; and a footer. The behavior
-- (xtalkassistant-window.livecodescript) lays it out, as the kit leaves
-- the layout to each window.
private command xtaBuildWindow
   local tOldDefault, tName
   put the defaultStack into tOldDefault
   lock screen
   lock messages
   get xtaReadAppearance()
   create invisible stack kWindow
   set the defaultStack to kWindow
   set the resizable of stack kWindow to true
   set the destroyStack of stack kWindow to true
   xtaUiChrome kTitle, kWindowWidth, kWindowHeight
   set the minWidth of stack kWindow to 460
   set the minHeight of stack kWindow to 520
   xtaUiPill "Pill", (kWindowWidth - 108) & comma & (kUiBand - 18) div 2 & comma & (kWindowWidth - 16) & comma & (kUiBand + 18) div 2

   create button "Provider"
   set the style of button "Provider" to "menu"
   set the menuMode of button "Provider" to "option"
   set the text of button "Provider" to xtaProviderNames()
   set the tooltip of button "Provider" to "The provider of the AI model"

   create button "Model"
   set the style of button "Model" to "menu"
   set the menuMode of button "Model" to "comboBox"
   set the tooltip of button "Model" to "The model: choose one, or type its name; Models asks the provider for its list"

   create button "Models"
   set the label of button "Models" to "Models"
   set the tooltip of button "Models" to "Ask the provider which models it has"

   create button "More"
   set the style of button "More" to "menu"
   set the menuMode of button "More" to "pulldown"
   set the label of button "More" to "More"
   set the text of button "More" to xtaMoreMenuText()

   -- The conversation, on a panel (made first, so that it is behind)
   xtaUiPanel "ConversationPanel", "16,90," & (kWindowWidth - 16) & ",400"
   create field "Conversation"
   set the lockText of field "Conversation" to true
   set the traversalOn of field "Conversation" to true
   set the dontWrap of field "Conversation" to false
   set the vScrollbar of field "Conversation" to true
   set the threeD of field "Conversation" to false
   set the borderWidth of field "Conversation" to 0
   set the opaque of field "Conversation" to false
   set the margins of field "Conversation" to "8,8,8,8"
   set the textSize of field "Conversation" to 12
   set the foregroundColor of field "Conversation" to xtaUi("Ink")
   -- Its scrollbar shows while it has more than it shows (xtaFitScrollbar)
   set the vScrollbar of field "Conversation" to false

   -- The activity row, at the foot of the conversation's panel while the
   -- assistant works (xtaWorkBegin): a hairline over it, a spinner, what
   -- the assistant is doing, and for how long. Hidden until then.
   xtaUiGfx "ActivityLine", "16,380," & (kWindowWidth - 16) & ",381"
   set the style of graphic "ActivityLine" to "rectangle"
   set the filled of graphic "ActivityLine" to true
   set the backgroundColor of graphic "ActivityLine" to xtaUi("CardLine")
   set the lineSize of graphic "ActivityLine" to 0
   xtaUiGfx "ActivitySpin", "28,386,42,400"
   set the style of graphic "ActivitySpin" to "oval"
   set the filled of graphic "ActivitySpin" to false
   set the lineSize of graphic "ActivitySpin" to 2
   set the foregroundColor of graphic "ActivitySpin" to kUiAccent
   set the startAngle of graphic "ActivitySpin" to 0
   set the arcAngle of graphic "ActivitySpin" to 270
   xtaUiLabel "Activity", empty, "48,382," & (kWindowWidth - 100) & ",402", 11
   set the dontWrap of field "Activity" to true
   set the foregroundColor of field "Activity" to xtaUi("InkSoft")
   xtaUiLabel "ActivityTime", empty, (kWindowWidth - 100) & ",382," & (kWindowWidth - 28) & ",402", 11
   set the dontWrap of field "ActivityTime" to true
   set the textAlign of field "ActivityTime" to "right"
   set the textFont of field "ActivityTime" to xtaUiMonoFont()
   set the foregroundColor of field "ActivityTime" to xtaUi("Muted")
   set the visible of graphic "ActivityLine" to false
   set the visible of graphic "ActivitySpin" to false
   set the visible of field "Activity" to false
   set the visible of field "ActivityTime" to false

   -- The bar that asks the user: what is asked, its details (the changes,
   -- or the code), and the buttons that answer it
   xtaUiPanel "AskPanel", "16,230," & (kWindowWidth - 16) & ",400"
   xtaUiLabel "AskTitle", empty, "28,240," & (kWindowWidth - 28) & ",274", 13
   set the textStyle of field "AskTitle" to "bold"
   xtaUiArea "AskDetail", "28,278," & (kWindowWidth - 28) & ",358"
   set the traversalOn of field "AskDetail" to true
   repeat for each item tName in "AskNo,AskSession,AskYes"
      create button tName
   end repeat
   set the default of button "AskYes" to false
   repeat for each item tName in "AskPanel,AskTitle,AskDetail,AskNo,AskSession,AskYes"
      if tName begins with "AskP" then
         set the visible of graphic tName to false
      else if tName begins with "AskT" or tName begins with "AskD" then
         set the visible of field tName to false
      else
         set the visible of button tName to false
      end if
   end repeat

   create button "Include"
   set the style of button "Include" to "checkbox"
   -- Ticked, a checkbox made by script is drawn with a raised frame
   -- (hiliteBorder); the Tools palette's have none
   set the hiliteBorder of button "Include" to false
   set the label of button "Include" to "Include the open script"
   set the tooltip of button "Include" to "Send the script open in the Script Editor with your question"

   create button "Insert"
   set the label of button "Insert" to "Insert Code"
   set the tooltip of button "Insert" to "Insert the code of the last answer at the caret in the Script Editor (Undo takes it out again)"

   create button "New"
   set the label of button "New" to "New Chat"
   set the tooltip of button "New" to "Start a new conversation"

   -- The prompt: a white, rounded ground, whose line is the accent while
   -- the prompt has the focus; under the prompt the hint that shows while
   -- it is empty; and the prompt itself, clear, on top. Its scrollbar
   -- shows while it holds more than it shows (the window's textChanged).
   xtaUiGfx "PromptBg", "16,500," & (kWindowWidth - 104) & ",572"
   set the roundRadius of graphic "PromptBg" to 10
   set the filled of graphic "PromptBg" to true
   set the backgroundColor of graphic "PromptBg" to xtaUi("Card")
   set the lineSize of graphic "PromptBg" to 1
   set the foregroundColor of graphic "PromptBg" to xtaUi("FieldLine")
   xtaUiLabel "PromptHint", xtaPromptHint(), "16,500," & (kWindowWidth - 104) & ",572", 12
   set the margins of field "PromptHint" to "10,7,10,7"
   set the foregroundColor of field "PromptHint" to xtaUi("Muted")
   xtaUiInput "Prompt", "16,500," & (kWindowWidth - 104) & ",572"
   set the opaque of field "Prompt" to false
   set the borderWidth of field "Prompt" to 0
   set the margins of field "Prompt" to "10,7,10,7"
   set the textFont of field "Prompt" to empty
   set the textSize of field "Prompt" to 12
   set the foregroundColor of field "Prompt" to xtaUi("Ink")
   set the dontWrap of field "Prompt" to false
   set the vScrollbar of field "Prompt" to false
   set the autoTab of field "Prompt" to false
   set the tooltip of field "Prompt" to "Your question." && xtaSendKeysText() && "Escape stops the assistant."

   create button "Send"
   set the label of button "Send" to "Send"
   set the default of button "Send" to false

   xtaUiFooter xtaFooterText(), "16,614," & (kWindowWidth - 16) & ",632"
   set the dontWrap of field "uiFooter" to true
   xtaUiButtons kWindow, "Send,AskYes"

   set the behavior of stack kWindow to the long id of stack kWindowBehavior
   unlock messages
   xtaPaintWindow
   set the defaultStack to tOldDefault
   unlock screen
end xtaBuildWindow

-- What the footer says: what the assistant may do to the user's stacks
private function xtaFooterText
   if xtaBuildOn() then
      return "Nothing changes or runs until you say yes, and Undo takes it back."
   end if
   return "The model reads and answers: it cannot change your stacks."
end xtaFooterText

-- Which keys send the question, as this computer's keyboard names them.
-- The window sends on Command-Return (Control-Return) and on Enter
-- (enterInField), and Return starts a new line. A Mac's keyboard calls
-- the key Return; the main key of a PC's is labelled Enter but sends
-- Return, and only its keypad's sends Enter: the window used to say
-- "Enter sends your question" there, and that key made a new line.
private function xtaSendKeysText
   if the platform is "MacOS" then
      return "Command-Return sends your question (or Enter, on a keypad), and Return starts a new line."
   end if
   return "Ctrl+Enter sends your question (or the keypad's Enter), and Enter starts a new line."
end xtaSendKeysText

-- What the prompt says while it is empty
private function xtaPromptHint
   local tKeys
   if the platform is "MacOS" then
      put "Command-Return sends" into tKeys
   else
      put "Ctrl+Enter sends" into tKeys
   end if
   if xtaBuildOn() then
      return "Ask a question, or say what to build or fix" & return & tKeys
   end if
   return "Ask a question about xTalk Script" & return & tKeys
end xtaPromptHint

-- After the assistant put something into the prompt or emptied it: the
-- window shows the hint while it is empty, and the scrollbar while it
-- holds more than it shows (as it does as the user types)
private command xtaPromptChanged
   if there is a stack kWindow then
      dispatch "xtawPromptChanged" to stack kWindow
   end if
end xtaPromptChanged

--------------------------------------------------------------------------------
-- The suite's look
--
-- The xTalk Suite's UI kit v2 (tools/ui-kit.livecodescript), its builders
-- matched by value and named xtaUi...: each makes a control of the
-- defaultStack, which is the window being built, as the kit's do. Labels
-- here also take no focus (traversalOn false), since these windows are
-- the IDE's and Tab should go from field to field.

-- The platform's own mono face
private function xtaUiMonoFont
   if the platform is "MacOS" then
      return "Menlo"
   else if the platform is "Win32" then
      return "Consolas"
   end if
   return "DejaVu Sans Mono"
end xtaUiMonoFont

-- A colour of the windows, by its name (the kUi... constants without
-- "kUi"): Learn's light ones, or in the dark appearance Learn's dark ones
-- (revLearnKit's lkColor), with white text, not grey. The header, the
-- mark and the buttons filled with the accent are the same in both.
-- "AccentInk" is the accent as the colour of text: lighter in the dark.
private function xtaUi pName
   if sUiDark is true then
      switch pName
         case "Bg"
            return "16,22,36"
         case "Card"
            return "30,41,59"
         case "CardLine"
            return "51,65,85"
         case "FieldLine"
            return "71,85,105"
         case "Ink"
            return "255,255,255"
         case "InkSoft"
            return "226,232,240"
         case "Muted"
            return "176,190,206"
         case "Ok"
            return "74,222,128"
         case "Warn"
            return "251,191,36"
         case "Bad"
            return "248,113,113"
         case "AccentInk"
            return "196,181,253"
         case "CodeBg"
            return "2,6,23"
         case "CodeHead"
            return "30,41,59"
         case "OutputBg"
            return "15,23,42"
         case "Tint"
            return "46,38,84"
         case "InlineBg"
            return "59,47,107"
         case "InlineInk"
            return "221,214,254"
      end switch
   end if
   switch pName
      case "Bg"
         return kUiBg
      case "Card"
         return kUiCard
      case "CardLine"
         return kUiCardLine
      case "FieldLine"
         return kUiFieldLine
      case "Ink"
         return kUiInk
      case "InkSoft"
         return kUiInkSoft
      case "Muted"
         return kUiMuted
      case "Ok"
         return kUiOk
      case "Warn"
         return kUiWarn
      case "Bad"
         return kUiBad
      case "AccentInk"
         return kUiAccent
      case "CodeBg"
         return kUiCodeBg
      case "CodeHead"
         return kUiCodeHead
      case "CodeInk"
         return kUiCodeInk
      case "OutputBg"
         return kUiOutputBg
      case "Tint"
         return kUiTint
      case "InlineBg"
         return kUiInlineBg
      case "InlineInk"
         return kUiInlineInk
   end switch
   return kUiInk
end xtaUi

-- Reads the desktop's appearance into sUiDark, as the IDE's Tools palette
-- reads it: macOS's and Windows' systemAppearance, and on Linux, where
-- the systemAppearance is always light, how dark the GTK theme's window
-- colour is (this stack's, which has no colour of its own). True when it
-- changed. Light where neither can be read (another xTalk's engine).
private function xtaReadAppearance
   local tDark, tSaved, tSum, tError
   put false into tDark
   try
      if the platform contains "linux" then
         put the backgroundColor of me into tSaved
         lock screen
         set the backgroundColor of me to empty
         put the effective backgroundColor of me into tSum
         set the backgroundColor of me to tSaved
         unlock screen
         if item 1 of tSum is a number and item 3 of tSum is a number then
            put item 1 of tSum + item 2 of tSum + item 3 of tSum < 234 into tDark
         end if
      else
         put the systemAppearance is "dark" into tDark
      end if
   catch tError
   end try
   if tDark is (sUiDark is true) then
      return false
   end if
   put tDark into sUiDark
   return true
end xtaReadAppearance

-- The desktop switched between light and dark (the IDE's
-- ideSystemAppearanceChanged, which xtaOpenWindow subscribes this stack
-- to): the window is painted again in the other colours, in place, with
-- the conversation drawn again; the Settings and Memory windows take them
-- when they are next made. On macOS the appearance can still read as it
-- was when the switch is announced: it is read again every 300
-- milliseconds, ten times, until it has changed (as the Tools palette does).
on ideSystemAppearanceChanged
   if sAppearanceMsg is not empty then
      cancel sAppearanceMsg
      put empty into sAppearanceMsg
   end if
   put 10 into sAppearanceTries
   xtaRecheckAppearance
end ideSystemAppearanceChanged

on xtaRecheckAppearance
   put empty into sAppearanceMsg
   if there is not a stack kWindow then
      exit xtaRecheckAppearance
   end if
   if xtaFollowAppearance() then
      exit xtaRecheckAppearance
   end if
   subtract 1 from sAppearanceTries
   if sAppearanceTries > 0 then
      send "xtaRecheckAppearance" to me in 300 milliseconds
      put the result into sAppearanceMsg
   end if
end xtaRecheckAppearance

-- Reads the appearance, and when it changed paints the window again in
-- its colours, with the conversation drawn again; true when it changed
private function xtaFollowAppearance
   if not xtaReadAppearance() then
      return false
   end if
   if there is a stack kWindow then
      lock screen
      xtaPaintWindow
      xtaShowConversation
      xtaPaintPill
      unlock screen
   end if
   return true
end xtaFollowAppearance

-- The colours of the window's controls that change with the appearance:
-- when it is made, and again when the appearance changes. The status
-- line keeps what it says, in the new colour of its kind.
private command xtaPaintWindow
   local tOld, tKind, tName, tButton, tIndex
   if there is not a stack kWindow then
      exit xtaPaintWindow
   end if
   lock screen
   lock messages
   set the linkColor of stack kWindow to xtaUi("AccentInk")
   set the linkHiliteColor of stack kWindow to xtaUi("AccentInk")
   set the linkVisitedColor of stack kWindow to xtaUi("AccentInk")
   set the cFieldLine of stack kWindow to xtaUi("FieldLine")
   set the backgroundColor of card 1 of stack kWindow to xtaUi("Bg")
   -- the status line, in its kind's colour (the kind found by the colour,
   -- in either appearance's)
   put the foregroundColor of field "Status" of stack kWindow into tOld
   put "InkSoft" into tKind
   repeat for each item tName in "Ok,Warn,Bad"
      if tOld is xtaUiOf(tName, true) or tOld is xtaUiOf(tName, false) then
         put tName into tKind
      end if
   end repeat
   set the foregroundColor of field "Status" of stack kWindow to xtaUi(tKind)
   repeat for each item tName in "ConversationPanel,AskPanel"
      set the backgroundColor of graphic tName of stack kWindow to xtaUi("Card")
      set the foregroundColor of graphic tName of stack kWindow to xtaUi("CardLine")
      set the borderColor of graphic tName of stack kWindow to xtaUi("CardLine")
   end repeat
   set the foregroundColor of field "Conversation" of stack kWindow to xtaUi("Ink")
   set the backgroundColor of graphic "ActivityLine" of stack kWindow to xtaUi("CardLine")
   set the foregroundColor of field "Activity" of stack kWindow to xtaUi("InkSoft")
   set the foregroundColor of field "ActivityTime" of stack kWindow to xtaUi("Muted")
   set the foregroundColor of field "AskTitle" of stack kWindow to xtaUi("Ink")
   set the foregroundColor of field "AskDetail" of stack kWindow to xtaUi("Ink")
   set the backgroundColor of field "AskDetail" of stack kWindow to xtaUi("Card")
   set the borderColor of field "AskDetail" of stack kWindow to xtaUi("CardLine")
   set the foregroundColor of button "Include" of stack kWindow to xtaUi("Ink")
   set the backgroundColor of graphic "PromptBg" of stack kWindow to xtaUi("Card")
   -- (the accent while the prompt has the focus: the window's behavior)
   if the foregroundColor of graphic "PromptBg" of stack kWindow is not kUiAccent then
      set the foregroundColor of graphic "PromptBg" of stack kWindow to xtaUi("FieldLine")
   end if
   set the foregroundColor of field "PromptHint" of stack kWindow to xtaUi("Muted")
   set the foregroundColor of field "Prompt" of stack kWindow to xtaUi("Ink")
   set the foregroundColor of field "uiFooter" of stack kWindow to xtaUi("Muted")
   -- the flat buttons that are not filled with the accent
   repeat with tIndex = 1 to the number of buttons of card 1 of stack kWindow
      put the long id of button tIndex of card 1 of stack kWindow into tButton
      if the style of tButton is "roundrect" and the backgroundColor of tButton is not kUiAccent then
         xtaUiButtonColors tButton, xtaUi("CardLine"), xtaUi("Ink"), xtaUi("FieldLine")
      end if
   end repeat
   unlock messages
   unlock screen
end xtaPaintWindow

-- A colour as it is in the dark appearance (pDark) or the light one
private function xtaUiOf pName, pDark
   local tSaved, tColor
   put sUiDark into tSaved
   put pDark into sUiDark
   put xtaUi(pName) into tColor
   put tSaved into sUiDark
   return tColor
end xtaUiOf

-- The page, the header with the mark and the title, and the status line
-- under it (field "Status", which xtaStatus and the dialogs write)
private command xtaUiChrome pTitle, pWidth, pHeight
   local tHeight
   set the width of this stack to pWidth
   set the height of this stack to pHeight
   set the backgroundColor of this card to xtaUi("Bg")
   set the title of this stack to pTitle
   -- The header, dark, its gradient Learn's (xtaUiBandWidth keeps it to
   -- the window's width)
   xtaUiGfx "uiBand", "0,0," & pWidth & comma & kUiBand
   set the style of graphic "uiBand" to "rectangle"
   set the filled of graphic "uiBand" to true
   set the backgroundColor of graphic "uiBand" to kUiHeadFrom
   set the lineSize of graphic "uiBand" to 0
   xtaUiBandWidth pWidth
   -- The mark: a violet square with rounded corners, lit from above, and
   -- a four-pointed star on it
   xtaUiGfx "uiMark", "12,9,38,35"
   set the roundRadius of graphic "uiMark" to 9
   set the filled of graphic "uiMark" to true
   set the lineSize of graphic "uiMark" to 0
   set the backgroundColor of graphic "uiMark" to kUiAccent
   xtaUiFill the long id of graphic "uiMark", "157,108,242", "109,40,217", "12,9", "12,35"
   xtaUiLabel "uiMarkGlyph", numToCodepoint(10022), "12,9,38,35", 14
   set the foregroundColor of field "uiMarkGlyph" to kUiAccentText
   set the textAlign of field "uiMarkGlyph" to "center"
   put the formattedHeight of field "uiMarkGlyph" into tHeight
   if tHeight > 0 and tHeight < 26 then
      set the height of field "uiMarkGlyph" to tHeight
      set the top of field "uiMarkGlyph" to 9 + (26 - tHeight) div 2
   end if
   xtaUiLabel "uiTitle", pTitle, "46,0," & pWidth & comma & kUiBand, 15
   set the foregroundColor of field "uiTitle" to kUiAccentText
   set the textStyle of field "uiTitle" to "bold"
   set the dontWrap of field "uiTitle" to true
   -- Centered on the header by its measured height
   put the formattedHeight of field "uiTitle" into tHeight
   if tHeight > 0 and tHeight < kUiBand then
      set the height of field "uiTitle" to tHeight
      set the top of field "uiTitle" to (kUiBand - tHeight) div 2
   end if
   xtaUiLabel "Status", empty, "16," & (kUiBand + 4) & comma & (pWidth - 16) & comma & (kUiBand + 22), 11
   set the dontWrap of field "Status" to true
   set the foregroundColor of field "Status" to xtaUi("InkSoft")
end xtaUiChrome

-- The header's gradient across a window pWidth wide (and the window's
-- behavior keeps it there as the window is resized)
private command xtaUiBandWidth pWidth
   xtaUiFill the long id of graphic "uiBand", kUiHeadFrom, kUiHeadTo, "0,0", pWidth & ",0"
end xtaUiBandWidth

-- A linear gradient on graphic pObj, from pFrom at point pStart to pTo at
-- pEnd (an engine without gradients keeps the graphic's own colour)
private command xtaUiFill pObj, pFrom, pTo, pStart, pEnd
   local tFill, tError
   try
      put "linear" into tFill["type"]
      put "0.0," & pFrom & return & "1.0," & pTo into tFill["ramp"]
      put pStart into tFill["from"]
      put pEnd into tFill["to"]
      put item 1 of pStart & comma & (item 2 of pStart + 1) into tFill["via"]
      if pStart is not pEnd and item 1 of pStart is item 1 of pEnd then
         put (item 1 of pStart + 1) & comma & item 2 of pStart into tFill["via"]
      end if
      set the fillGradient of pObj to tFill
   catch tError
   end try
end xtaUiFill

-- Flat buttons, as Learn draws them: every push button of the card of
-- stack pStack a slate chip, and those named in pPrimary (the ones that
-- say yes) filled with the accent. Menus and checkboxes keep
-- the platform's look.
private command xtaUiButtons pStack, pPrimary
   local tIndex, tButton
   repeat with tIndex = 1 to the number of buttons of this card of stack pStack
      put the long id of button tIndex of this card of stack pStack into tButton
      if the style of tButton is not "standard" then
         next repeat
      end if
      set the style of tButton to "roundrect"
      set the threeD of tButton to false
      set the showBorder of tButton to false
      set the borderWidth of tButton to 0
      set the hiliteBorder of tButton to false
      set the showFocusBorder of tButton to false
      set the opaque of tButton to true
      set the textStyle of tButton to "bold"
      if the short name of tButton is among the items of pPrimary then
         xtaUiButtonColors tButton, kUiAccent, kUiAccentText, "109,40,217"
      else
         xtaUiButtonColors tButton, xtaUi("CardLine"), xtaUi("Ink"), xtaUi("FieldLine")
      end if
   end repeat
end xtaUiButtons

-- A flat button's ground, ink and colour while pressed
private command xtaUiButtonColors pButton, pGround, pInk, pPressed
   set the backgroundColor of pButton to pGround
   set the borderColor of pButton to pGround
   set the foregroundColor of pButton to pInk
   set the hiliteColor of pButton to pPressed
end xtaUiButtonColors

-- A caption at a fixed rect
private command xtaUiLabel pName, pText, pRect, pSize
   if there is not a field pName then
      create field pName
   end if
   set the rect of field pName to pRect
   set the lockText of field pName to true
   set the traversalOn of field pName to false
   set the borderWidth of field pName to 0
   set the opaque of field pName to false
   set the threeD of field pName to false
   set the textSize of field pName to pSize
   set the foregroundColor of field pName to xtaUi("Ink")
   put pText into field pName
end xtaUiLabel

-- A caption fit to the height of its text, its top where pRect says
private command xtaUiWrap pName, pText, pRect, pSize
   local tHeight
   xtaUiLabel pName, pText, pRect, pSize
   if pText is not empty then
      put the formattedHeight of field pName into tHeight
      if tHeight > 0 then
         set the height of field pName to tHeight
         set the top of field pName to item 2 of pRect
      end if
   end if
end xtaUiWrap

-- A small, muted caption
private command xtaUiCap pName, pText, pRect
   xtaUiWrap pName, pText, pRect, 10
   set the foregroundColor of field pName to xtaUi("Muted")
end xtaUiCap

-- A numbered section's header, with a hairline under it
private command xtaUiSection pName, pText, pRect
   local tBottom
   xtaUiWrap pName, pText, pRect, 13
   set the textStyle of field pName to "bold"
   put the bottom of field pName into tBottom
   xtaUiGfx pName & "Line", (item 1 of pRect) & comma & (tBottom + 1) & comma & (item 3 of pRect) & comma & (tBottom + 2)
   set the style of graphic (pName & "Line") to "rectangle"
   set the filled of graphic (pName & "Line") to true
   set the backgroundColor of graphic (pName & "Line") to xtaUi("CardLine")
   set the lineSize of graphic (pName & "Line") to 0
end xtaUiSection

-- An entry field: flat, a hairline border, the mono face
private command xtaUiInput pName, pRect
   if there is not a field pName then
      create field pName
   end if
   set the rect of field pName to pRect
   set the lockText of field pName to false
   set the traversalOn of field pName to true
   set the threeD of field pName to false
   set the borderWidth of field pName to 1
   set the borderColor of field pName to xtaUi("FieldLine")
   set the opaque of field pName to true
   set the backgroundColor of field pName to xtaUi("Card")
   set the margins of field pName to "6,6,6,6"
   set the textSize of field pName to 11
   set the textFont of field pName to xtaUiMonoFont()
end xtaUiInput

-- A read-only area for code and data: mono, flat, scrolling
private command xtaUiArea pName, pRect
   if there is not a field pName then
      create field pName
   end if
   set the rect of field pName to pRect
   set the lockText of field pName to true
   set the traversalOn of field pName to false
   set the threeD of field pName to false
   set the borderWidth of field pName to 1
   set the borderColor of field pName to xtaUi("CardLine")
   set the opaque of field pName to true
   set the backgroundColor of field pName to xtaUi("Card")
   set the foregroundColor of field pName to xtaUi("Ink")
   set the margins of field pName to "6,6,6,6"
   set the vScrollbar of field pName to true
   set the textSize of field pName to 10
   set the textFont of field pName to xtaUiMonoFont()
end xtaUiArea

private command xtaUiGfx pName, pRect
   if there is not a graphic pName then
      create graphic pName
   end if
   set the rect of graphic pName to pRect
   set the style of graphic pName to "roundRect"
   set the antialiased of graphic pName to true
end xtaUiGfx

-- A panel: white, rounded, a hairline and a soft shadow (an engine
-- without shadows shows the hairline alone)
private command xtaUiPanel pName, pRect
   local tShadow, tError
   xtaUiGfx pName, pRect
   set the roundRadius of graphic pName to 14
   set the filled of graphic pName to true
   set the backgroundColor of graphic pName to xtaUi("Card")
   set the lineSize of graphic pName to 1
   set the foregroundColor of graphic pName to xtaUi("CardLine")
   set the borderColor of graphic pName to xtaUi("CardLine")
   try
      put "15,23,42" into tShadow["color"]
      put 18 into tShadow["opacity"]
      put 10 into tShadow["size"]
      put 0 into tShadow["spread"]
      put 2 into tShadow["distance"]
      put 90 into tShadow["angle"]
      set the dropShadow of graphic pName to tShadow
   catch tError
   end try
end xtaUiPanel

-- A pill: a rounded chip (graphic pName & "Bg") and its label (field
-- pName), colored by xtaSetPill
private command xtaUiPill pName, pRect
   local tTop, tBottom, tHeight
   put item 2 of pRect into tTop
   put item 4 of pRect into tBottom
   xtaUiGfx pName & "Bg", pRect
   set the roundRadius of graphic (pName & "Bg") to tBottom - tTop
   set the filled of graphic (pName & "Bg") to true
   set the lineSize of graphic (pName & "Bg") to 0
   xtaUiLabel pName, "Ready", pRect, 10
   set the textAlign of field pName to "center"
   set the dontWrap of field pName to true
   -- Centered on the chip by its measured height
   put the formattedHeight of field pName into tHeight
   if tHeight > 0 and tHeight < tBottom - tTop then
      set the height of field pName to tHeight
      set the top of field pName to tTop + ((tBottom - tTop - tHeight) div 2)
   end if
end xtaUiPill

-- A footer: italic, muted
private command xtaUiFooter pText, pRect
   xtaUiLabel "uiFooter", pText, pRect, 11
   set the textStyle of field "uiFooter" to "italic"
   set the foregroundColor of field "uiFooter" to xtaUi("Muted")
end xtaUiFooter

private function xtaProviderNames
   local tList, tProvider
   repeat for each item tProvider in xtaProviders()
      put xtaProviderName(tProvider) & return after tList
   end repeat
   delete the last char of tList
   return tList
end xtaProviderNames

-- Shows the settings and the conversation as they are now.
private command xtaRefreshWindow
   local tProvider
   if there is not a stack kWindow then
      exit xtaRefreshWindow
   end if
   put xtaProvider() into tProvider
   lock screen
   lock messages
   set the label of button "Provider" of stack kWindow to xtaProviderName(tProvider)
   set the text of button "Model" of stack kWindow to xtaModelMenu(tProvider, sModelMenus[tProvider])
   set the label of button "Model" of stack kWindow to xtaModel(tProvider)
   set the hilite of button "Include" of stack kWindow to (revIDEGetPreference(kPrefIncludeScript) is not false)
   set the text of button "More" of stack kWindow to xtaMoreMenuText()
   set the text of field "uiFooter" of stack kWindow to xtaFooterText()
   set the text of field "PromptHint" of stack kWindow to xtaPromptHint()
   unlock messages
   xtaPromptChanged
   xtaShowConversation
   xtaUpdateButtons
   if sBusy is not true then
      xtaStatus xtaSettingsLine()
   end if
   unlock screen
end xtaRefreshWindow

-- While a question is being answered, Send is Stop, which ends the rounds
-- of corrections after the answer that is on its way.
private command xtaUpdateButtons
   if there is not a stack kWindow then
      exit xtaUpdateButtons
   end if
   if sBusy is true then
      set the label of button "Send" of stack kWindow to "Stop"
      set the tooltip of button "Send" of stack kWindow to "Stop after the answer that is on its way (Escape)"
      set the enabled of button "Send" of stack kWindow to (sStopAsked is not true)
   else
      set the label of button "Send" of stack kWindow to "Send"
      set the tooltip of button "Send" of stack kWindow to empty
      set the enabled of button "Send" of stack kWindow to true
   end if
   set the enabled of button "Models" of stack kWindow to (sBusy is not true)
   -- The provider and model of a question stay its own until it is answered
   set the enabled of button "Provider" of stack kWindow to (sBusy is not true)
   set the enabled of button "Model" of stack kWindow to (sBusy is not true)
   set the enabled of button "Insert" of stack kWindow to (sBusy is not true and the number of elements of sLastCode > 0)
   -- Copy the Conversation, once there is one
   xtaRefreshMoreMenu
   xtaPaintPill
end xtaUpdateButtons

-- The pill at the right of the band says what the assistant is doing:
-- waiting for the user's answer in the bar, waiting for the model
-- (thinking), working with its tools, without a key, or ready
private command xtaPaintPill
   local tProvider
   if there is not a stack kWindow then
      exit xtaPaintPill
   end if
   put xtaProvider() into tProvider
   if sAsk["kind"] is not empty then
      xtaSetPill "Needs you", "wait"
   else if sBusy is true and sWork["kind"] is "wait" then
      xtaSetPill "Thinking", "busy"
   else if sBusy is true then
      xtaSetPill "Working", "busy"
   else if xtaKey(tProvider) is empty and xtaBaseUrl(tProvider) is empty then
      xtaSetPill "No key", "bad"
   else
      xtaSetPill "Ready", "ok"
   end if
end xtaPaintPill

-- The pill's colours on the dark header, by kind: ok green, wait amber,
-- bad red, and otherwise ("busy") a deep violet
private command xtaSetPill pText, pKind
   local tGround, tInk
   switch pKind
      case "ok"
         put "209,250,229" into tGround
         put "6,95,70" into tInk
         break
      case "wait"
         put "254,243,199" into tGround
         put "146,64,14" into tInk
         break
      case "bad"
         put "254,226,226" into tGround
         put "153,27,27" into tInk
         break
      default
         put "76,29,149" into tGround
         put "221,214,254" into tInk
   end switch
   lock messages
   set the backgroundColor of graphic "PillBg" of stack kWindow to tGround
   set the text of field "Pill" of stack kWindow to pText
   set the foregroundColor of field "Pill" of stack kWindow to tInk
   unlock messages
end xtaSetPill

-- The items of the More menu; the short guide's is ticked while it is used
-- (and with it no tools are sent, which small models mistake), and Undo
-- All Changes is there while something the assistant did can be undone
private function xtaMoreMenuText
   local tShort, tUndo, tCopy, tIdle
   if revIDEGetPreference(kPrefShortGuide) is true then
      put "!c" into tShort
   else
      put "!n" into tShort
   end if
   if xtaAppliedCount() is 0 then
      put "(" into tUndo
   end if
   if the number of elements of sTurns is 0 then
      put "(" into tCopy
   end if
   -- While a question is being answered, what would change the provider,
   -- its key, the guide or the stacks under it waits: each round reads the
   -- settings again, and a conversation with one provider's tool calls sent
   -- to another was refused (and its key forgotten)
   if sBusy is true then
      put "(" into tIdle
      put "(" into tUndo
      put "(" before tShort
   end if
   return tIdle & "Settings..." & return & tIdle & "Set API Key..." & return & tIdle & "Forget API Key" & return & "-" & return & \
         tIdle & "Explain the Last Error" & return & tIdle & "Explain the Open Script" & return & tUndo & "Undo All Changes..." & return & \
         tCopy & "Copy the Conversation" & return & "Memory..." & return & \
         tShort & "Short Guide, No Tools (for small local models)" & return & "-" & return & \
         "Turn Off xTalk Assistant"
end xtaMoreMenuText

-- The status line, colored as the kit colors it: pKind "ok" green, "warn"
-- amber, "bad" red, anything else the soft ink
private command xtaStatus pText, pKind
   local tColor
   if there is not a stack kWindow then
      exit xtaStatus
   end if
   switch pKind
      case "ok"
         put xtaUi("Ok") into tColor
         break
      case "warn"
         put xtaUi("Warn") into tColor
         break
      case "bad"
         put xtaUi("Bad") into tColor
         break
      default
         put xtaUi("InkSoft") into tColor
   end switch
   lock messages
   set the text of field "Status" of stack kWindow to pText
   set the foregroundColor of field "Status" of stack kWindow to tColor
   -- All of it, where the line is too short for it
   set the tooltip of field "Status" of stack kWindow to pText
   unlock messages
end xtaStatus

private function xtaSettingsLine
   local tProvider, tLine
   put xtaProvider() into tProvider
   put xtaProviderName(tProvider) into tLine
   if xtaKey(tProvider) is empty then
      put xtaDot() & "no API key yet (More > Settings...)" after tLine
   else if sKeys[tProvider] is empty then
      put xtaDot() & "API key from the environment" after tLine
   end if
   if xtaModel(tProvider) is empty then
      put xtaDot() & "no model yet (Send chooses one)" after tLine
   else
      put xtaDot() & xtaModel(tProvider) after tLine
   end if
   return tLine
end xtaSettingsLine

--------------------------------------------------------------------------------
-- While the assistant works
--
-- From Send until the question is answered, a row at the foot of the
-- conversation says what the assistant is doing (waiting for the model,
-- using a tool, checking the code, waiting for the user's answer in the
-- bar), with a spinner, and how long the question has taken so far; the
-- pill says Thinking, Working or Needs you; and the status line says which
-- model is asked, how many requests the question took and their tokens so
-- far. The row is redrawn every kTickMilliseconds by a message sent to
-- this stack, which the engine delivers while it waits for the model and
-- while the bar waits for the user (both wait with messages).

-- The question was sent: the row shows, and its clock starts
private command xtaWorkBegin
   xtaStopTicking
   put empty into sWork
   put the milliseconds into sWork["start"]
   put 0 into sWork["requests"]
   put 0 into sWork["in"]
   put 0 into sWork["out"]
   put 0 into sWork["cached"]
   put 0 into sWork["angle"]
   xtaShowActivity true
   xtaStartTicking
end xtaWorkBegin

-- The question is answered (or stopped, or failed): the row goes, and
-- the conversation has its room again
private command xtaWorkEnd
   xtaStopTicking
   xtaShowActivity false
end xtaWorkEnd

private command xtaShowActivity pShow
   if there is not a stack kWindow then
      exit xtaShowActivity
   end if
   lock screen
   lock messages
   set the visible of graphic "ActivityLine" of stack kWindow to pShow
   set the visible of graphic "ActivitySpin" of stack kWindow to pShow
   set the visible of field "Activity" of stack kWindow to pShow
   set the visible of field "ActivityTime" of stack kWindow to pShow
   unlock messages
   dispatch "xtawRelayout" to stack kWindow
   if pShow then
      xtaPaintActivity
   end if
   unlock screen
end xtaShowActivity

-- What the assistant is doing now: pKind "wait" (for the model), "tool",
-- "check" (compiling an answer's code), "ask" (waiting for the user in
-- the bar) or "stop"; pText says it in words
private command xtaPhase pKind, pText
   if sBusy is not true then
      exit xtaPhase
   end if
   put pKind into sWork["kind"]
   put pText into sWork["phase"]
   xtaPaintActivity
   xtaPaintPill
end xtaPhase

-- Redraws the row: the spinner (still, and amber, while the user is
-- asked), what the assistant is doing, and the question's time so far
private command xtaPaintActivity
   local tSeconds
   if there is not a stack kWindow or sWork["start"] is empty then
      exit xtaPaintActivity
   end if
   put (the milliseconds - sWork["start"]) div 1000 into tSeconds
   lock messages
   set the startAngle of graphic "ActivitySpin" of stack kWindow to sWork["angle"]
   if sWork["kind"] is "ask" then
      set the foregroundColor of graphic "ActivitySpin" of stack kWindow to xtaUi("Warn")
   else
      set the foregroundColor of graphic "ActivitySpin" of stack kWindow to kUiAccent
   end if
   if field "Activity" of stack kWindow is not sWork["phase"] then
      set the text of field "Activity" of stack kWindow to sWork["phase"]
   end if
   set the text of field "ActivityTime" of stack kWindow to format("%d:%02d", tSeconds div 60, tSeconds mod 60)
   unlock messages
end xtaPaintActivity

-- The row's redraw: the spinner turns, and the clock goes on
on xtaActivityTick
   put empty into sWork["timer"]
   if sBusy is not true or sWork["start"] is empty or there is not a stack kWindow then
      exit xtaActivityTick
   end if
   if sWork["kind"] is not "ask" then
      put (sWork["angle"] + 30) mod 360 into sWork["angle"]
   end if
   xtaPaintActivity
   xtaStartTicking
end xtaActivityTick

private command xtaStartTicking
   if sWork["timer"] is not empty then
      exit xtaStartTicking
   end if
   send "xtaActivityTick" to me in kTickMilliseconds milliseconds
   put the result into sWork["timer"]
end xtaStartTicking

private command xtaStopTicking
   if sWork["timer"] is not empty then
      cancel sWork["timer"]
      put empty into sWork["timer"]
   end if
end xtaStopTicking

-- The status line while the assistant works: the model, and once it has
-- answered a request, how many requests and their tokens so far
private command xtaWorkStatus
   local tProvider, tLine
   put xtaProvider() into tProvider
   if sWork["requests"] is 0 then
      put "Asking" && xtaModel(tProvider) && "(" & xtaServerLabel(tProvider) & ")" into tLine
   else
      put xtaModel(tProvider) & xtaDot() & sWork["requests"] && xtaCounted(sWork["requests"], "request", "requests") into tLine
      if sWork["in"] > 0 or sWork["out"] > 0 then
         put xtaDot() & sWork["in"] && "tokens in," && sWork["out"] && "out so far" after tLine
      end if
   end if
   xtaStatus tLine
end xtaWorkStatus

-- Who answers, in a word or two: the provider, or the host of the
-- user's own server ("localhost:11434")
private function xtaServerLabel pProvider
   local tUrl
   put xtaBaseUrl(pProvider) into tUrl
   if tUrl is empty then
      if pProvider is "openai" then
         return "OpenAI"
      end if
      return xtaProviderName(pProvider)
   end if
   if tUrl contains "://" then
      put char offset("://", tUrl) + 3 to -1 of tUrl into tUrl
   end if
   set the itemDelimiter to "/"
   return item 1 of tUrl
end xtaServerLabel

-- pSingular when pCount is 1, else pPlural
private function xtaCounted pCount, pSingular, pPlural
   if pCount is 1 then
      return pSingular
   end if
   return pPlural
end xtaCounted

--------------------------------------------------------------------------------
-- The conversation
--
-- The conversation field is filled in one go from a styledText array (a
-- paragraph each: its "style" and its "runs", each run its "text" and its
-- "style"), which the engine lays out once. A run's colour is its
-- "textColor", the only name the engine takes for it: before 0.2.5-rc.5
-- the colours below were given as "foregroundColor", and none showed. Who
-- speaks heads each block, in bold: "You", "xTalk Assistant" (the accent)
-- or "Compile check" (amber), and an empty line goes between blocks, so
-- that each label begins a line of its own in the field's text too. In a
-- block:
--    the user's words, on a light tint of the accent;
--    an answer, its Markdown read: headings, lists, quotes, bold, italics,
--       `code` and links; a fenced block as a card in the code's face,
--       under a header that names its language and has Copy and, for
--       xTalk, Insert;
--    what the tools did, a line each in italics (amber when it did not
--       work), with Undo after what can be undone; under a batch of
--       changes, what they were, and under a run, what it put out;
--    after an answer, what the compile check found, and the notes it
--       proposes to remember, with Remember and Dismiss;
--    once a question is answered, how long it took and what it cost, in
--       small print at the end of its last block.
-- With no conversation yet, the field welcomes the user instead
-- (xtaDocWelcome), with questions to begin with.

private command xtaShowConversation
   local tDoc, tEntries, tStates, tIndex, tTurn, tSpeaker, tQuestion, tText, tNew
   if there is not a stack kWindow then
      exit xtaShowConversation
   end if
   -- What became of what the tools changed: applied or undone, by entry
   if xtaBuildLoaded() then
      put xtaBuildEntries() into tEntries
      repeat with tIndex = 1 to the number of elements of tEntries
         put tEntries[tIndex]["state"] into tStates[tEntries[tIndex]["number"]]
      end repeat
   end if
   if the number of elements of sTurns is 0 then
      xtaDocWelcome tDoc
   else
      put 0 into tQuestion
      repeat with tIndex = 1 to the number of elements of sTurns
         put sTurns[tIndex] into tTurn
         if tTurn["kind"] is "tools" then
            xtaDocSpeaker tDoc, tSpeaker, "xTalk Assistant"
            xtaDocTools tDoc, tTurn["results"], tStates, the result
            next repeat
         end if
         if tTurn["role"] is "assistant" then
            put xtaWithoutMemoryBlocks(tTurn["text"]) into tText
            -- An answer that only asked for tools shows as what they did
            if the number of elements of tTurn["calls"] > 0 and word 1 to -1 of tText is empty \
                  and the number of elements of tTurn["notes"] is 0 then
               next repeat
            end if
            xtaDocSpeaker tDoc, tSpeaker, "xTalk Assistant"
            put the result into tNew
            xtaDocAnswer tDoc, tText, tIndex, xtaUi("Ink"), tNew
            xtaDocCheck tDoc, tTurn["check"]
            xtaDocCut tDoc, tTurn["cut"]
            xtaDocNotes tDoc, tIndex
            next repeat
         end if
         if tTurn["kind"] is "check" then
            xtaDocSpeaker tDoc, tSpeaker, "Compile check"
            put tTurn["text"] into tText
            if tText begins with "Compile check: " then
               delete char 1 to the number of chars of "Compile check: " of tText
            end if
            xtaDocAnswer tDoc, tText, tIndex, xtaUi("InkSoft"), true
            next repeat
         end if
         -- A question: first what the one before took, then who asks
         xtaDocMeta tDoc, tQuestion
         put empty into tSpeaker
         xtaDocSpeaker tDoc, tSpeaker, "You"
         xtaDocQuestion tDoc, tTurn
         put tIndex into tQuestion
      end repeat
      xtaDocMeta tDoc, tQuestion
      xtaDocAdd tDoc, empty, empty
   end if
   lock screen
   lock messages
   set the styledText of field "Conversation" of stack kWindow to tDoc
   unlock messages
   xtaFitScrollbar
   set the vScroll of field "Conversation" of stack kWindow to the formattedHeight of field "Conversation" of stack kWindow
   unlock screen
end xtaShowConversation

-- The conversation's scrollbar, only while it has more than it shows
-- (measured with the scrollbar, so that taking it away cannot make the
-- text longer than the field)
private command xtaFitScrollbar
   lock messages
   set the vScrollbar of field "Conversation" of stack kWindow to true
   if the formattedHeight of field "Conversation" of stack kWindow <= the height of field "Conversation" of stack kWindow then
      set the vScrollbar of field "Conversation" of stack kWindow to false
   end if
   unlock messages
end xtaFitScrollbar

-- Begins a block of pName's (a label) unless xSpeaker, who spoke last,
-- is pName already. The result is true when a block was begun.
private command xtaDocSpeaker @xDoc, @xSpeaker, pName
   local tRun, tPara
   if xSpeaker is pName then
      return false
   end if
   if the number of elements of xDoc > 0 then
      xtaDocAdd xDoc, empty, empty
   end if
   put "bold" into tRun["textStyle"]
   if pName is "Compile check" then
      put xtaUi("Warn") into tRun["textColor"]
   else
      put xtaUi("AccentInk") into tRun["textColor"]
   end if
   put 2 into tPara["spaceBelow"]
   xtaDocLine xDoc, pName, tRun, tPara
   put pName into xSpeaker
   return true
end xtaDocSpeaker

-- The user's question, on the tint, with what went with it: one
-- paragraph, its lines kept apart by line breaks within it (a vertical
-- tab, which the engine lays out as one), so that the tint is one box
private command xtaDocQuestion @xDoc, pTurn
   local tRun, tSoft, tPara, tRuns, tText
   put xtaUi("Ink") into tRun["textColor"]
   put xtaUi("InkSoft") into tSoft["textColor"]
   put "italic" into tSoft["textStyle"]
   put xtaUi("Tint") into tPara["backgroundColor"]
   put 6 into tPara["padding"]
   put pTurn["text"] into tText
   replace return with numToChar(11) in tText
   xtaRunAdd tRuns, tText, tRun
   if pTurn["attach"] is not empty then
      xtaRunAdd tRuns, numToChar(11) & "(with the last error, in" && pTurn["attachName"] & ")", tSoft
   end if
   if pTurn["context"] is not empty then
      xtaRunAdd tRuns, numToChar(11) & "(with the script of" && pTurn["contextName"] & ")", tSoft
   end if
   xtaDocAdd xDoc, tRuns, tPara
end xtaDocQuestion

-- What the tools did (pResults, a tools turn's), a line each. pNew is
-- false when the line goes on the block of an answer.
private command xtaDocTools @xDoc, pResults, pStates, pNew
   local tCall, tResult, tSummary, tRuns, tStyle, tLink, tEntry, tPara, tSmall, tSub, tShown, tLine, tMore
   put xtaUi("InkSoft") into tSmall["textColor"]
   put 11 into tSmall["textSize"]
   put "disc" into tSub["listStyle"]
   put 2 into tSub["listDepth"]
   put 14 into tSub["listIndent"]
   repeat with tCall = 1 to the number of elements of pResults
      put pResults[tCall] into tResult
      put tResult["summary"] into tSummary
      replace return with space in tSummary
      put empty into tRuns
      put empty into tStyle
      put "italic" into tStyle["textStyle"]
      if tResult["error"] is true then
         put xtaUi("Warn") into tStyle["textColor"]
      else
         put xtaUi("InkSoft") into tStyle["textColor"]
      end if
      xtaRunAdd tRuns, tSummary, tStyle
      put tResult["entry"] into tEntry
      if tEntry is not empty then
         if pStates[tEntry] is "applied" then
            xtaRunAdd tRuns, "    ", tStyle
            put empty into tLink
            put "link" into tLink["textStyle"]
            put "undo," & tEntry into tLink["linkText"]
            xtaRunAdd tRuns, "Undo", tLink
         else if pStates[tEntry] is "undone" then
            xtaRunAdd tRuns, "    (undone)", tStyle
         end if
      end if
      put empty into tPara
      if tCall is 1 and pNew is false then
         put 4 into tPara["spaceAbove"]
      end if
      xtaDocAdd xDoc, tRuns, tPara
      -- What a batch changed, a line each (the first few)
      put 0 into tShown
      repeat for each line tLine in tResult["lines"]
         add 1 to tShown
         if tShown > kShownChanges then
            put the number of lines of tResult["lines"] - kShownChanges into tMore
            xtaDocLine xDoc, "... and" && tMore && "more", tSmall, tSub
            exit repeat
         end if
         xtaDocLine xDoc, tLine, tSmall, tSub
      end repeat
      -- What a run put into the Message Box, and returned
      xtaDocRunOutput xDoc, tResult
   end repeat
end xtaDocTools

-- Under a run: what it put into the Message Box (its first lines) and
-- what it returned, in the code's face
private command xtaDocRunOutput @xDoc, pResult
   local tMono, tPara, tLines, tCount, tLine, tValue
   if pResult["output"] is empty and pResult["value"] is empty then
      exit xtaDocRunOutput
   end if
   put xtaCodeFont() into tMono["textFont"]
   put 10 into tMono["textSize"]
   put xtaUi("Ink") into tMono["textColor"]
   put xtaUi("OutputBg") into tPara["backgroundColor"]
   put 16 into tPara["leftIndent"]
   put 8 into tPara["firstIndent"]
   put 0 into tCount
   if pResult["output"] is not empty then
      put the number of lines of pResult["output"] into tLines
      repeat for each line tLine in pResult["output"]
         add 1 to tCount
         if tCount > kShownOutput then
            put xtaUi("Muted") into tMono["textColor"]
            xtaDocLine xDoc, "... and" && tLines - kShownOutput && "more lines", tMono, tPara
            put xtaUi("Ink") into tMono["textColor"]
            exit repeat
         end if
         xtaDocLine xDoc, tLine, tMono, tPara
      end repeat
   end if
   if pResult["value"] is not empty then
      put line 1 of pResult["value"] into tValue
      if the number of chars of tValue > 200 then
         put char 1 to 200 of tValue & "..." into tValue
      else if the number of lines of pResult["value"] > 1 then
         put "..." after tValue
      end if
      put xtaUi("InkSoft") into tMono["textColor"]
      xtaDocLine xDoc, "returned" && tValue, tMono, tPara
   end if
end xtaDocRunOutput

-- What the compile check found of an answer's code (pCheck, its
-- summary): green when it compiles, amber when it does not
private command xtaDocCheck @xDoc, pCheck
   local tRun, tPara
   if pCheck is empty then
      exit xtaDocCheck
   end if
   put "italic" into tRun["textStyle"]
   if pCheck contains "not compile" then
      put xtaUi("Warn") into tRun["textColor"]
   else
      put xtaUi("Ok") into tRun["textColor"]
   end if
   put 4 into tPara["spaceAbove"]
   xtaDocLine xDoc, pCheck, tRun, tPara
end xtaDocCheck

-- Why an answer ends where it does, when it was cut off or stopped
-- (its "cut": xtaCutNote, xtaRefusalNote), in amber
private command xtaDocCut @xDoc, pCut
   local tRun, tPara
   if pCut is empty then
      exit xtaDocCut
   end if
   put "italic" into tRun["textStyle"]
   put xtaUi("Warn") into tRun["textColor"]
   put 4 into tPara["spaceAbove"]
   xtaDocLine xDoc, pCut, tRun, tPara
end xtaDocCut

-- The notes an answer (turn pTurn) proposes to remember: those not kept
-- yet with Remember and Dismiss as links ("remember,turn,note")
private command xtaDocNotes @xDoc, pTurn
   local tNote, tRun, tLink, tRuns, tText
   put "italic" into tRun["textStyle"]
   put xtaUi("InkSoft") into tRun["textColor"]
   put "link" into tLink["textStyle"]
   repeat with tNote = 1 to the number of elements of sTurns[pTurn]["notes"]
      put sTurns[pTurn]["notes"][tNote]["note"] into tText
      switch sTurns[pTurn]["notes"][tNote]["state"]
         case "dismissed"
            break
         case "kept"
            xtaDocLine xDoc, "Remembered" && xtaNoteScope(pTurn, tNote) & ":" && tText, tRun, empty
            break
         default
            put empty into tRuns
            xtaRunAdd tRuns, "Note to keep" && xtaNoteScope(pTurn, tNote) & ":" && tText & "    ", tRun
            put "remember," & pTurn & comma & tNote into tLink["linkText"]
            xtaRunAdd tRuns, "Remember", tLink
            xtaRunAdd tRuns, "  ", tRun
            put "dismiss," & pTurn & comma & tNote into tLink["linkText"]
            xtaRunAdd tRuns, "Dismiss", tLink
            xtaDocAdd xDoc, tRuns, empty
            break
      end switch
   end repeat
end xtaDocNotes

-- At the end of a question's last block: how long the answer took, how
-- many requests it made and the tokens they cost (its "stats", kept when
-- it was answered)
private command xtaDocMeta @xDoc, pQuestion
   local tStats, tRun, tPara
   if pQuestion is 0 or pQuestion is empty then
      exit xtaDocMeta
   end if
   put sTurns[pQuestion]["stats"] into tStats
   if tStats is not an array then
      exit xtaDocMeta
   end if
   put xtaUi("Muted") into tRun["textColor"]
   put 10 into tRun["textSize"]
   put 4 into tPara["spaceAbove"]
   xtaDocLine xDoc, xtaStatsLine(tStats), tRun, tPara
end xtaDocMeta

-- What a question took, for the conversation and the status line: "12 s,
-- 2 requests, 1200 tokens in and 300 out"
private function xtaStatsLine pStats
   local tLine
   put xtaDuration(pStats["ms"]) into tLine
   if pStats["requests"] is 1 then
      put xtaDot() & "1 request" after tLine
   else if pStats["requests"] > 1 then
      put xtaDot() & pStats["requests"] && "requests" after tLine
   end if
   if pStats["in"] > 0 or pStats["out"] > 0 then
      put xtaDot() & pStats["in"] && "tokens in," && pStats["out"] && "out" after tLine
      if pStats["cached"] > 0 then
         put " (" & pStats["cached"] && "read from the cache)" after tLine
      end if
   end if
   return tLine
end xtaStatsLine

-- pMilliseconds as the user reads a time: 0.4 s, 12 s, 1 min 05 s
private function xtaDuration pMilliseconds
   local tSeconds
   if pMilliseconds is not a number then
      return "0 s"
   end if
   if pMilliseconds < 10000 then
      return format("%.1f s", pMilliseconds / 1000)
   end if
   put round(pMilliseconds / 1000) into tSeconds
   if tSeconds < 60 then
      return tSeconds && "s"
   end if
   return tSeconds div 60 && "min" && format("%02d", tSeconds mod 60) && "s"
end xtaDuration

-- A separator between the parts of a line: a middle dot between spaces
private function xtaDot
   return space & numToCodepoint(183) & space
end xtaDot

-- The welcome, while there is no conversation: what the assistant does,
-- and questions to begin with, each a link that puts it into the prompt
-- ("example,N", xtaExampleText)
private command xtaDocWelcome @xDoc
   local tRun, tPara, tLink, tRuns, tIndex, tText, tProvider
   put "bold" into tRun["textStyle"]
   put 16 into tRun["textSize"]
   put xtaUi("Ink") into tRun["textColor"]
   put 10 into tPara["spaceAbove"]
   put 4 into tPara["spaceBelow"]
   xtaDocLine xDoc, "What shall we make?", tRun, tPara
   put empty into tRun
   put xtaUi("InkSoft") into tRun["textColor"]
   put empty into tPara
   if xtaBuildOn() then
      put "Ask about xTalk Script, or ask the assistant to build it with you: it can read your stack, make cards, controls " & \
            "and new stacks, write their scripts, run code to try it, and check that what it writes compiles. Nothing changes " & \
            "until you say yes." into tText
   else
      put "Ask about xTalk Script: the assistant can read your stack, look up the Dictionary and check that the code it " & \
            "writes compiles." into tText
   end if
   xtaDocLine xDoc, tText, tRun, tPara
   put xtaProvider() into tProvider
   if xtaKey(tProvider) is empty and xtaBaseUrl(tProvider) is empty then
      put empty into tRuns
      put 8 into tPara["spaceAbove"]
      put xtaUi("Bad") into tRun["textColor"]
      xtaRunAdd tRuns, "It needs your" && xtaProviderName(tProvider) && "API key first:", tRun
      xtaRunAdd tRuns, " ", tRun
      put "link" into tLink["textStyle"]
      put "settings" into tLink["linkText"]
      xtaRunAdd tRuns, "add it in the Settings", tLink
      xtaRunAdd tRuns, ".", tRun
      xtaDocAdd xDoc, tRuns, tPara
      put xtaUi("InkSoft") into tRun["textColor"]
   end if
   put empty into tPara
   put 12 into tPara["spaceAbove"]
   put 2 into tPara["spaceBelow"]
   put xtaUi("Muted") into tRun["textColor"]
   put 11 into tRun["textSize"]
   xtaDocLine xDoc, "Try one of these:", tRun, tPara
   put empty into tPara
   put "disc" into tPara["listStyle"]
   put 18 into tPara["listIndent"]
   put 3 into tPara["spaceBelow"]
   put "link" into tLink["textStyle"]
   repeat with tIndex = 1 to 4
      put xtaExampleText(tIndex) into tText
      if tText is empty then
         next repeat
      end if
      put "example," & tIndex into tLink["linkText"]
      put empty into tRuns
      xtaRunAdd tRuns, tText, tLink
      xtaDocAdd xDoc, tRuns, tPara
   end repeat
   put empty into tPara
   put 14 into tPara["spaceAbove"]
   put 10 into tRun["textSize"]
   xtaDocLine xDoc, xtaSendKeysText() && "Escape stops the assistant.", tRun, tPara
end xtaDocWelcome

-- The questions the welcome offers: those that build only while the
-- model may change stacks
private function xtaExampleText pIndex
   switch pIndex
      case 1
         return "How do I read a text file into a field?"
      case 2
         if xtaBuildOn() then
            return "Make a new stack with a field and a button that counts the words in it"
         end if
         return "How do I count the words in a field?"
      case 3
         if xtaBuildOn() then
            return "Add a Clear button to this card that empties every field"
         end if
         return "Write a handler that empties every field of a card"
      case 4
         return "Why did my last error happen, and how do I fix it?"
   end switch
   return empty
end xtaExampleText

-- Adds a paragraph of pRuns (as xtaRunAdd makes them) and pStyle (a
-- paragraph's styles, or empty) to xDoc
private command xtaDocAdd @xDoc, pRuns, pStyle
   local tIndex
   put the number of elements of xDoc + 1 into tIndex
   if the number of elements of pRuns is 0 then
      put empty into pRuns[1]["text"]
   end if
   put pRuns into xDoc[tIndex]["runs"]
   if pStyle is an array then
      put pStyle into xDoc[tIndex]["style"]
   end if
end xtaDocAdd

-- Adds a run of pText in pStyle (a run's styles, or empty) to xRuns
private command xtaRunAdd @xRuns, pText, pStyle
   local tIndex
   if pText is empty then
      exit xtaRunAdd
   end if
   put the number of elements of xRuns + 1 into tIndex
   put pText into xRuns[tIndex]["text"]
   if pStyle is an array then
      put pStyle into xRuns[tIndex]["style"]
   end if
end xtaRunAdd

-- One paragraph of one run
private command xtaDocLine @xDoc, pText, pRunStyle, pStyle
   local tRuns
   xtaRunAdd tRuns, pText, pRunStyle
   xtaDocAdd xDoc, tRuns, pStyle
end xtaDocLine

-- A paragraph of the runs of pText, a line of an answer, with its inline
-- Markdown read (xtaInlineRuns)
private command xtaDocInline @xDoc, pText, pRunStyle, pStyle
   xtaDocAdd xDoc, xtaInlineRuns(pText, pRunStyle), pStyle
end xtaDocInline

-- The runs of pText with what Markdown marks inside a line: `code`,
-- **bold**, *italic* and _italic_, and [words](https://...), which is a
-- link; the rest as it is. A mark that is not closed is taken as it is. A
-- star or underscore marks italics only around words (2 * 3 * 4 is not),
-- and an underscore only outside a word (a_name_like_this is not).
private function xtaInlineRuns pText, pBase
   local tRuns, tPos, tLength, tPlain, tChar, tEnd, tStyle, tUrl, tClose
   put the number of chars of pText into tLength
   put 1 into tPos
   repeat while tPos <= tLength
      put char tPos of pText into tChar
      put 0 into tEnd
      switch tChar
         case "`"
            put xtaFindAfter("`", pText, tPos + 1) into tEnd
            if tEnd > tPos + 1 then
               xtaRunAdd tRuns, tPlain, pBase
               put empty into tPlain
               put pBase into tStyle
               put xtaCodeFont() into tStyle["textFont"]
               put xtaUi("InlineBg") into tStyle["backgroundColor"]
               put xtaUi("InlineInk") into tStyle["textColor"]
               xtaRunAdd tRuns, char tPos + 1 to tEnd - 1 of pText, tStyle
               put tEnd + 1 into tPos
               next repeat
            end if
            break
         case "*"
         case "_"
            if char tPos + 1 of pText is tChar then
               -- **bold** (or __bold__)
               put xtaFindAfter(tChar & tChar, pText, tPos + 2) into tEnd
               if tEnd > tPos + 2 then
                  xtaRunAdd tRuns, tPlain, pBase
                  put empty into tPlain
                  put pBase into tStyle
                  put xtaAddTextStyle(tStyle["textStyle"], "bold") into tStyle["textStyle"]
                  xtaRunAdd tRuns, char tPos + 2 to tEnd - 1 of pText, tStyle
                  put tEnd + 2 into tPos
                  next repeat
               end if
            else if char tPos + 1 of pText is not space and char tPos + 1 of pText is not empty \
                  and (tChar is "*" or tPos is 1 or not xtaIsWordChar(char tPos - 1 of pText)) then
               put xtaFindAfter(tChar, pText, tPos + 1) into tEnd
               if tEnd > tPos + 1 and char tEnd - 1 of pText is not space \
                     and (tChar is "*" or not xtaIsWordChar(char tEnd + 1 of pText)) then
                  xtaRunAdd tRuns, tPlain, pBase
                  put empty into tPlain
                  put pBase into tStyle
                  put xtaAddTextStyle(tStyle["textStyle"], "italic") into tStyle["textStyle"]
                  xtaRunAdd tRuns, char tPos + 1 to tEnd - 1 of pText, tStyle
                  put tEnd + 1 into tPos
                  next repeat
               end if
            end if
            break
         case "["
            put xtaFindAfter("](", pText, tPos + 1) into tEnd
            if tEnd > tPos + 1 then
               put xtaFindAfter(")", pText, tEnd + 2) into tClose
               put char tEnd + 2 to tClose - 1 of pText into tUrl
               if tClose > 0 and (tUrl begins with "https://" or tUrl begins with "http://") and space is not in tUrl then
                  xtaRunAdd tRuns, tPlain, pBase
                  put empty into tPlain
                  put pBase into tStyle
                  put "link" into tStyle["textStyle"]
                  put "url," & tUrl into tStyle["linkText"]
                  xtaRunAdd tRuns, char tPos + 1 to tEnd - 1 of pText, tStyle
                  put tClose + 1 into tPos
                  next repeat
               end if
            end if
            break
      end switch
      put tChar after tPlain
      add 1 to tPos
   end repeat
   xtaRunAdd tRuns, tPlain, pBase
   return tRuns
end xtaInlineRuns

-- Where pNeedle is in pText at or after char pFrom, or 0
private function xtaFindAfter pNeedle, pText, pFrom
   local tAt
   if pFrom > the number of chars of pText then
      return 0
   end if
   put offset(pNeedle, pText, pFrom - 1) into tAt
   if tAt is 0 then
      return 0
   end if
   return tAt + pFrom - 1
end xtaFindAfter

private function xtaIsWordChar pChar
   return pChar is not empty and (pChar is a number or toLower(pChar) is not toUpper(pChar))
end xtaIsWordChar

-- pStyles (a textStyle: empty, plain, or words with commas) with pStyle
-- added
private function xtaAddTextStyle pStyles, pStyle
   if pStyles is empty or pStyles is "plain" then
      return pStyle
   end if
   if pStyle is among the items of pStyles then
      return pStyles
   end if
   return pStyles & comma & pStyle
end xtaAddTextStyle

-- The face code is shown in: the Script Editor's, else the platform's
-- mono face
private function xtaCodeFont
   local tFont
   put revIDEGetPreference("cScriptEditor,editor,font") into tFont
   if tFont is empty then
      put xtaUiMonoFont() into tFont
   end if
   return tFont
end xtaCodeFont

-- What a fenced block's language is called above it: the two of
-- OXT-Beyond by the names its Dictionary gives them, xTalk Script and
-- xTalk Builder, whatever the block is marked (livecodescript, lcb...)
private function xtaLangLabel pLang
   put toLower(word 1 to -1 of pLang) into pLang
   if xtaIsXTalkLang(pLang) then
      return "xTalk Script"
   end if
   switch pLang
      case "livecodebuilder"
      case "lcb"
         return "xTalk Builder"
      case "sh"
      case "bash"
      case "shell"
         return "Shell"
      case "js"
      case "javascript"
         return "JavaScript"
      case "c++"
      case "cpp"
         return "C++"
      case "json"
      case "html"
      case "css"
      case "sql"
      case "xml"
         return toUpper(pLang)
   end switch
   return toUpper(char 1 of pLang) & char 2 to -1 of pLang
end xtaLangLabel

-- An answer (pText, turn pTurn) onto xDoc, its Markdown read, in pInk.
-- pNew is false when it goes on a block already begun (after what its
-- tools did), and is then set apart from it. Code is numbered as
-- xtaCodeBlocks numbers it, for Copy and Insert ("copy,turn,block").
private command xtaDocAnswer @xDoc, pText, pTurn, pInk, pNew
   local tLine, tInCode, tLang, tBlock, tRuns, tRun, tPara, tTrim, tLevel, tCodeFont
   local tHeader, tLink, tSpace, tBody, tFirst, tCode, tCodePara
   put xtaCodeFont() into tCodeFont
   put false into tInCode
   put 0 into tBlock
   put pInk into tBody["textColor"]
   put tCodeFont into tCode["textFont"]
   put 11 into tCode["textSize"]
   put xtaUi("CodeInk") into tCode["textColor"]
   put xtaUi("CodeBg") into tCodePara["backgroundColor"]
   put 10 into tCodePara["firstIndent"]
   put (pNew is false) into tFirst
   put 0 into tSpace
   repeat for each line tLine in pText
      put word 1 to -1 of tLine into tTrim
      if tTrim begins with "```" then
         if tInCode then
            -- A strip of the code's ground under the last line
            put empty into tRun
            put 4 into tRun["textSize"]
            xtaDocLine xDoc, empty, tRun, tCodePara
            put false into tInCode
            put 8 into tSpace
            next repeat
         end if
         put true into tInCode
         add 1 to tBlock
         put char 4 to -1 of tTrim into tLang
         put word 1 of tLang into tLang
         -- The header: the language, then Copy and, for xTalk, Insert
         put empty into tRuns
         put empty into tRun
         put "bold" into tRun["textStyle"]
         put "148,163,184" into tRun["textColor"]
         put 10 into tRun["textSize"]
         xtaRunAdd tRuns, xtaLangLabel(tLang), tRun
         put empty into tLink
         put "link" into tLink["textStyle"]
         put 10 into tLink["textSize"]
         -- (Learn's lighter violet, which reads on the dark head)
         put "196,181,253" into tLink["textColor"]
         put "copy," & pTurn & comma & tBlock into tLink["linkText"]
         xtaRunAdd tRuns, "     ", tRun
         xtaRunAdd tRuns, "Copy", tLink
         if xtaIsXTalkLang(tLang) then
            put "insert," & pTurn & comma & tBlock into tLink["linkText"]
            xtaRunAdd tRuns, "   ", tRun
            xtaRunAdd tRuns, "Insert", tLink
         end if
         put empty into tHeader
         put xtaUi("CodeHead") into tHeader["backgroundColor"]
         put 4 into tHeader["padding"]
         put 6 into tHeader["firstIndent"]
         put max(tSpace, 6) into tHeader["spaceAbove"]
         if tFirst then
            put 8 into tHeader["spaceAbove"]
            put false into tFirst
         end if
         xtaDocAdd xDoc, tRuns, tHeader
         put 0 into tSpace
         next repeat
      end if
      if tInCode then
         -- xTalk in Learn's colours, anything else in the code's ink
         if xtaIsXTalkLang(tLang) then
            xtaDocAdd xDoc, xtaCodeRuns(tLine, tCode), tCodePara
         else
            xtaDocLine xDoc, tLine, tCode, tCodePara
         end if
         next repeat
      end if
      -- An empty line sets the next paragraph apart, rather than being a
      -- paragraph of its own
      if tTrim is empty then
         put max(tSpace, 8) into tSpace
         next repeat
      end if
      put empty into tPara
      if tFirst then
         put 6 into tSpace
         put false into tFirst
      end if
      if tSpace > 0 then
         put tSpace into tPara["spaceAbove"]
         put 0 into tSpace
      end if
      -- Headings
      if char 1 of tTrim is "#" then
         put 0 into tLevel
         repeat while char tLevel + 1 of tTrim is "#"
            add 1 to tLevel
         end repeat
         if char tLevel + 1 of tTrim is space and tLevel <= 6 then
            put tBody into tRun
            put "bold" into tRun["textStyle"]
            put max(12, 16 - tLevel) into tRun["textSize"]
            if tPara["spaceAbove"] < 6 then
               put 6 into tPara["spaceAbove"]
            end if
            put 2 into tPara["spaceBelow"]
            put char tLevel + 2 to -1 of tTrim into tTrim
            xtaDocInline xDoc, word 1 to -1 of tTrim, tRun, tPara
            next repeat
         end if
      end if
      -- Lists: - * + bullets, and 1. 2) numbers, each two spaces of indent
      -- a level deeper
      if matchText(tLine, "^(\s*)[-*+]\s+(.*)$", tLevel, tTrim) then
         put "disc" into tPara["listStyle"]
         put min(3, 1 + the number of chars of tLevel div 2) into tPara["listDepth"]
         put 18 into tPara["listIndent"]
         put 2 into tPara["spaceBelow"]
         xtaDocInline xDoc, tTrim, tBody, tPara
         next repeat
      end if
      if matchText(tLine, "^(\s*)[0-9]+[.)]\s+(.*)$", tLevel, tTrim) then
         put "decimal" into tPara["listStyle"]
         put min(3, 1 + the number of chars of tLevel div 2) into tPara["listDepth"]
         put 18 into tPara["listIndent"]
         put 2 into tPara["spaceBelow"]
         xtaDocInline xDoc, tTrim, tBody, tPara
         next repeat
      end if
      -- A quote
      if tTrim begins with ">" then
         put tBody into tRun
         put "italic" into tRun["textStyle"]
         put xtaUi("InkSoft") into tRun["textColor"]
         put 12 into tPara["leftIndent"]
         put char 2 to -1 of tTrim into tTrim
         xtaDocInline xDoc, word 1 to -1 of tTrim, tRun, tPara
         next repeat
      end if
      -- A rule
      if tTrim is "---" or tTrim is "***" or tTrim is "___" then
         xtaDocAdd xDoc, empty, tPara
         next repeat
      end if
      xtaDocInline xDoc, tLine, tBody, tPara
   end repeat
end xtaDocAnswer

-- A line of xTalk as runs in Learn's colours (revLearnKit's lkCodeLineHtml
-- and lkWordColor, by value): strings, comments, numbers, the commands
-- and control words, the little words, the objects and chunks, and the
-- constants, each a colour of its own; pBase is the run every one starts
-- from (the code's face, size and ink)
private function xtaCodeRuns pLine, pBase
   local tRuns, tPos, tLength, tChar, tStart, tWord, tStyle, tPlain
   put the number of chars of pLine into tLength
   put 1 into tPos
   repeat while tPos <= tLength
      put char tPos of pLine into tChar
      if tChar is quote then
         xtaRunAdd tRuns, tPlain, pBase
         put empty into tPlain
         put tPos into tStart
         add 1 to tPos
         repeat while tPos <= tLength and char tPos of pLine is not quote
            add 1 to tPos
         end repeat
         put pBase into tStyle
         put "252,211,77" into tStyle["textColor"]
         xtaRunAdd tRuns, char tStart to tPos of pLine, tStyle
         add 1 to tPos
      else if (tChar is "-" and char tPos + 1 of pLine is "-") or tChar is "#" then
         xtaRunAdd tRuns, tPlain, pBase
         put empty into tPlain
         put pBase into tStyle
         put "100,116,139" into tStyle["textColor"]
         xtaRunAdd tRuns, char tPos to tLength of pLine, tStyle
         exit repeat
      else if xtaIsCodeWordChar(tChar) then
         xtaRunAdd tRuns, tPlain, pBase
         put empty into tPlain
         put tPos into tStart
         repeat while tPos <= tLength and xtaIsCodeWordChar(char tPos of pLine)
            add 1 to tPos
         end repeat
         put char tStart to tPos - 1 of pLine into tWord
         put pBase into tStyle
         put xtaWordColor(tWord) into tStyle["textColor"]
         xtaRunAdd tRuns, tWord, tStyle
      else
         put tChar after tPlain
         add 1 to tPos
      end if
   end repeat
   xtaRunAdd tRuns, tPlain, pBase
   -- (an empty line is one empty run, so that it keeps its height)
   if the number of elements of tRuns is 0 then
      put empty into tRuns[1]["text"]
      put pBase into tRuns[1]["style"]
   end if
   return tRuns
end xtaCodeRuns

-- A character of a word of xTalk, as Learn reads one ("is in" ignores
-- case, so this takes capitals too)
private function xtaIsCodeWordChar pChar
   return pChar is not empty and pChar is in "abcdefghijklmnopqrstuvwxyz0123456789_"
end xtaIsCodeWordChar

-- A word of xTalk's colour, as Learn colours it
private function xtaWordColor pWord
   if pWord is a number then
      return "253,186,116"
   end if
   if pWord is among the items of "on,end,put,get,set,move,add,subtract,multiply,divide,send,dispatch,call,repeat,if,then,else,switch,case,break,default,try,catch,throw,answer,ask,create,delete,go,open,close,show,hide,lock,unlock,sort,filter,replace,convert,do,exit,pass,return,local,global,constant,cancel,launch,function,command,getprop,setprop,next,beep,play,wait,select,click,type,import,export,start,stop,read,write,save,visual,focus,choose,combine,split,insert,load,post,format,private" then
      return "196,181,253"
   end if
   if pWord is among the items of "the,of,to,into,in,with,without,waiting,messages,and,or,not,is,are,a,an,for,each,until,while,times,by,after,before,from,at,any,mod,div,as,among,contains,within" then
      return "125,211,252"
   end if
   if pWord is among the items of "field,fld,graphic,grc,button,btn,card,cd,stack,image,img,group,grp,player,widget,scrollbar,control,me,it,this,target,item,items,word,words,line,lines,char,chars,character,characters,url,file,folder,milliseconds,millisecs,ticks,seconds,second,secs" then
      return "94,234,212"
   end if
   if pWord is among the items of "true,false,empty,quote,space,tab,comma,cr,return,lf,slash,colon,pi,zero,one,two,three" then
      return "249,168,212"
   end if
   return xtaUi("CodeInk")
end xtaWordColor

-- Whom a proposed note is about, as the window says it
private function xtaNoteScope pTurn, pNote
   if sTurns[pTurn]["notes"][pNote]["scope"] is "stack" then
      if sTurns[pTurn]["stackName"] is not empty then
         return "about the stack" && quote & sTurns[pTurn]["stackName"] & quote
      end if
      return "about this stack"
   end if
   return "about you"
end xtaNoteScope

--------------------------------------------------------------------------------
-- Settings

private function xtaProvider
   local tProvider
   put revIDEGetPreference(kPrefProvider) into tProvider
   if tProvider is not among the items of xtaProviders() then
      put "anthropic" into tProvider
   end if
   return tProvider
end xtaProvider

private function xtaModel pProvider
   return revIDEGetPreference(kPrefModel & pProvider)
end xtaModel

private function xtaBaseUrl pProvider
   return revIDEGetPreference(kPrefBaseUrl & pProvider)
end xtaBaseUrl

-- The key the user typed, or else the one in the environment
private function xtaKey pProvider
   if sKeys[pProvider] is not empty then
      return sKeys[pProvider]
   end if
   switch pProvider
      case "anthropic"
         return $ANTHROPIC_API_KEY
      case "openai"
         return $OPENAI_API_KEY
   end switch
   return empty
end xtaKey

-- The settings xtaAsk and xtaListModels take
private function xtaSettings
   local tSettings, tProvider
   put xtaProvider() into tProvider
   put tProvider into tSettings["provider"]
   put xtaBaseUrl(tProvider) into tSettings["baseUrl"]
   put xtaKey(tProvider) into tSettings["key"]
   put xtaModel(tProvider) into tSettings["model"]
   put revIDEGetPreference(kPrefMaxTokens) into tSettings["maxTokens"]
   put revIDEGetPreference(kPrefTimeout) into tSettings["timeout"]
   return tSettings
end xtaSettings

on xtaSetProviderByName pName
   local tProvider
   repeat for each item tProvider in xtaProviders()
      if xtaProviderName(tProvider) is pName and tProvider is not xtaProvider() then
         revIDESetPreference kPrefProvider, tProvider
         -- The model menu lists the other provider's models
         if there is a stack kWindow then
            lock messages
            set the text of button "Model" of stack kWindow to empty
            unlock messages
         end if
      end if
   end repeat
   xtaRefreshWindow
end xtaSetProviderByName

on xtaSetModel pModel
   put word 1 to -1 of pModel into pModel
   if pModel is not xtaModel(xtaProvider()) then
      revIDESetPreference kPrefModel & xtaProvider(), pModel
   end if
   xtaStatus xtaSettingsLine()
end xtaSetModel

on xtaSetIncludeScript pInclude
   revIDESetPreference kPrefIncludeScript, (pInclude is true)
end xtaSetIncludeScript

on xtaMoreMenuPick pItem
   switch pItem
      case "Settings..."
         xtaSettingsDialog empty
         break
      case "Set API Key..."
         xtaSettingsDialog "Key"
         break
      case "Forget API Key"
         put empty into sKeys[xtaProvider()]
         xtaStatus xtaSettingsLine()
         break
      case "Explain the Last Error"
         xtaExplainLastError
         break
      case "Explain the Open Script"
         xtaExplainOpenScript
         break
      case "Copy the Conversation"
         xtaCopyConversation
         break
      case "Undo All Changes..."
         xtaUndoAll
         break
      case "Memory..."
         xtaEditMemory
         break
      case "Short Guide, No Tools (for small local models)"
         revIDESetPreference kPrefShortGuide, (revIDEGetPreference(kPrefShortGuide) is not true)
         xtaRefreshWindow
         break
      case "Turn Off xTalk Assistant"
         xtaTurnOff
         break
   end switch
end xtaMoreMenuPick

--------------------------------------------------------------------------------
-- The Settings dialog
--
-- Every setting in one place (More > Settings...): the provider, its key,
-- base URL and model, the longest answer, how long to wait for one, the
-- fix rounds, the tools, the short guide and whether the open script goes
-- with a question. The key is typed or pasted into an ordinary field: the
-- engine's "ask password" dialog keeps only keys typed one by one, so a
-- pasted key came back empty and the assistant said there was no key
-- (0.2.5-rc.3). Get Models asks the provider for its list with what is in
-- the dialog, which also tells the user whether the key works. Nothing is
-- kept until Save, and Save keeps nothing until all of it checks out.

-- Opens the dialog and waits for it to close; pFocus "Key" puts the caret
-- in the key's field. Returns true when the user pressed Save. The dialog
-- is built each time, and goes when it closes.
private function xtaOpenSettings pFocus
   xtaSettingsPrepare pFocus
   -- It is built invisible, and "modal" returns at once for an invisible
   -- stack, so it is shown first
   lock screen
   set the visible of stack kSettingsWindow to true
   unlock screen
   modal stack kSettingsWindow
   return xtaSettingsDone()
end xtaOpenSettings

-- The steps before and after the dialog's modal loop, apart so that the
-- engine tests can take them (outside the IDE "modal" returns at once)
on xtaSettingsPrepare pFocus
   local tProvider
   xtaLoadParts
   if there is a stack kSettingsWindow then
      delete stack kSettingsWindow
   end if
   xtaBuildSettings
   put xtaProvider() into tProvider
   put tProvider into sSettingsProvider
   put empty into sDrafts
   put false into sSettingsSaved
   put false into sSettingsFetch
   xtaFillSettings tProvider, true
   if pFocus is "Key" then
      set the cFocus of stack kSettingsWindow to "Key"
   end if
   if there is a stack kWindow and the visible of stack kWindow then
      set the loc of stack kSettingsWindow to the loc of stack kWindow
   else
      set the loc of stack kSettingsWindow to the screenLoc
   end if
   -- Over a window near the edge of the screen, or one taller than the
   -- dialog, it would open partly off it
   xtaKeepOnScreen the long id of stack kSettingsWindow, false
end xtaSettingsPrepare

function xtaSettingsDone
   put empty into sDrafts
   if there is a stack kSettingsWindow then
      delete stack kSettingsWindow
   end if
   xtaRefreshWindow
   return sSettingsSaved is true
end xtaSettingsDone

-- More > Settings... and More > Set API Key...: after a new key, base URL
-- or provider, the models, which tell the user at once whether it works
-- (unless Get Models just did)
private command xtaSettingsDialog pFocus
   local tProvider
   if not xtaOpenSettings(pFocus) or sSettingsFetch is not true then
      exit xtaSettingsDialog
   end if
   put xtaProvider() into tProvider
   if xtaKey(tProvider) is not empty or xtaBaseUrl(tProvider) is not empty then
      xtaChooseModels
   end if
end xtaSettingsDialog

-- Builds the dialog, invisible: a stack made here, as the window is, in
-- the suite's look: the band, then what Save and Get Models found on the
-- status line (field "Result", two lines high, since a provider's refusal
-- can be long), then numbered sections. It fits a 720p screen.
private command xtaBuildSettings
   local tOldDefault, tTop, tLeft, tRight, tWidth
   put the defaultStack into tOldDefault
   put kSettingsWidth into tWidth
   put 168 into tLeft
   put tWidth - 16 into tRight
   get xtaFollowAppearance()
   lock screen
   lock messages
   create invisible stack kSettingsWindow
   set the defaultStack to kSettingsWindow
   set the resizable of stack kSettingsWindow to false
   set the destroyStack of stack kSettingsWindow to true
   xtaUiChrome kTitle && "Settings", tWidth, 600
   set the name of field "Status" to "Result"
   set the rect of field "Result" to 16, kUiBand + 4, tRight, kUiBand + 34
   set the dontWrap of field "Result" to false

   -- (under the header and the line that says what Save found)
   put kUiBand + 30 into tTop
   xtaSettingsSection "Section1", "1  Provider and key", tTop
   xtaSettingsLabel "Provider", tTop
   create button "Provider"
   set the style of button "Provider" to "menu"
   set the menuMode of button "Provider" to "option"
   set the text of button "Provider" to xtaProviderNames()
   set the rect of button "Provider" to tLeft, tTop, tLeft + 180, tTop + 24
   -- The online services that speak OpenAI's API, each with a key of its
   -- own: the way to them, for a user who would not know the URL
   create button "Services"
   set the style of button "Services" to "menu"
   set the menuMode of button "Services" to "pulldown"
   set the label of button "Services" to "Services"
   set the text of button "Services" to xtaOnlineServiceItems()
   set the rect of button "Services" to tRight - 100, tTop, tRight, tTop + 24
   set the tooltip of button "Services" to "Use an online service with OpenAI's API (OpenRouter, Groq, Gemini, DeepSeek, Mistral and more), with its own key"

   add 30 to tTop
   xtaSettingsLabel "API key", tTop
   xtaSettingsField "Key", tLeft, tTop, tRight - 108
   set the tooltip of field "Key" to "Type or paste the API key"
   create button "Forget Key"
   set the rect of button "Forget Key" to tRight - 100, tTop, tRight, tTop + 24
   set the tooltip of button "Forget Key" to "Forget the key typed for this provider"
   add 25 to tTop
   xtaSettingsNote "Key Note", tLeft, tTop, tRight, 31

   add 32 to tTop
   xtaSettingsLabel "Base URL", tTop
   xtaSettingsField "Base URL", tLeft, tTop, tRight - 108
   -- The servers that run a model on this computer, at their own
   -- addresses: the way to them, for a user who would not know the URL
   create button "Local"
   set the style of button "Local" to "menu"
   set the menuMode of button "Local" to "pulldown"
   set the label of button "Local" to "Local"
   set the text of button "Local" to xtaLocalServerItems()
   set the rect of button "Local" to tRight - 100, tTop, tRight, tTop + 24
   set the tooltip of button "Local" to "Use a model running on this computer, in LM Studio, Ollama, llama.cpp, Jan, vLLM or KoboldCpp (no key needed)"
   add 25 to tTop
   xtaSettingsNote "Base URL Note", tLeft, tTop, tRight, 31

   add 32 to tTop
   xtaSettingsSection "Section2", "2  Model", tTop
   xtaSettingsLabel "Model", tTop
   create button "Model"
   set the style of button "Model" to "menu"
   set the menuMode of button "Model" to "comboBox"
   set the rect of button "Model" to tLeft, tTop, tRight - 108, tTop + 24
   set the tooltip of button "Model" to "Choose a model, or type its name"
   create button "Get Models"
   set the rect of button "Get Models" to tRight - 100, tTop, tRight, tTop + 24
   set the tooltip of button "Get Models" to "Ask the provider for its models (this also tries the key)"
   add 25 to tTop
   xtaSettingsNote "Model Note", tLeft, tTop, tRight, 31
   put "Choose a model or type its name. Get Models asks the provider for all of them, and tells you whether the key works." \
         into field "Model Note"

   add 32 to tTop
   xtaSettingsSection "Section3", "3  Answers", tTop
   xtaSettingsLabel "Longest answer", tTop
   xtaSettingsField "Max Tokens", tLeft, tTop, tLeft + 80
   -- (at the row's top, with the note's top margin of 6, its words are
   -- where they were at 2 points down with a margin of 4)
   xtaSettingsNote "Max Tokens Note", tLeft + 88, tTop, tRight, 20
   put "tokens (empty:" && xtaMaxTokens("anthropic", empty) && "for Anthropic; OpenAI's model decides)" into field "Max Tokens Note"

   add 30 to tTop
   xtaSettingsLabel "Fix rounds", tTop
   xtaSettingsField "Fix Rounds", tLeft, tTop, tLeft + 80
   xtaSettingsNote "Fix Rounds Note", tLeft + 88, tTop, tRight, 20
   put "0 to" && kMaxFixRounds & ": tries to correct code that does not compile" into field "Fix Rounds Note"

   add 30 to tTop
   xtaSettingsLabel "Wait for an answer", tTop
   xtaSettingsField "Timeout", tLeft, tTop, tLeft + 80
   xtaSettingsNote "Timeout Note", tLeft + 88, tTop, tRight, 20
   put "seconds (" & kMinTimeout && "to" && kMaxTimeout & "; empty:" && kDefaultTimeout & ", more for a long answer)" into field "Timeout Note"

   add 30 to tTop
   xtaSettingsSection "Section4", "4  What the model may do", tTop
   xtaSettingsCheckbox "Include", "Send the open script with each question", tLeft, tTop, tRight
   set the tooltip of button "Include" to "Send the script open in the Script Editor with each question"
   add 21 to tTop
   xtaSettingsCheckbox "Tools", "Let the model look things up, check its code and read your stack", tLeft, tTop, tRight
   set the tooltip of button "Tools" to "The Dictionary, a compile check, your stack and a paused script (when you allow it), and the last error"
   add 21 to tTop
   xtaSettingsCheckbox "Pictures", "Let the model see pictures of your cards", tLeft, tTop, tRight
   set the tooltip of button "Pictures" to "To see what it built: not with a server of your own on OpenAI's API, whose model may take no pictures"
   add 21 to tTop
   xtaSettingsCheckbox "Build", "Let the model change your stacks and run code (it asks you first)", tLeft, tTop, tRight
   set the tooltip of button "Build" to "Changes you apply or not, and code you let run; Undo takes them back"
   add 21 to tTop
   xtaSettingsCheckbox "Short Guide", "Short guide, no tools (for small local models)", tLeft, tTop, tRight

   -- The dialog is no taller than 640, the suite's limit (a 720p screen)
   add 26 to tTop
   create button "Cancel"
   set the rect of button "Cancel" to tRight - 196, tTop, tRight - 106, tTop + 24
   create button "Save"
   set the rect of button "Save" to tRight - 98, tTop, tRight, tTop + 24
   set the default of button "Save" to true
   set the height of stack kSettingsWindow to tTop + 24 + 16
   xtaUiButtons kSettingsWindow, "Save"

   set the behavior of stack kSettingsWindow to the long id of stack kSettingsBehavior
   unlock messages
   set the defaultStack to tOldDefault
   unlock screen
end xtaBuildSettings

-- A numbered section's header at xTop, which then is where its first row
-- goes (the dialog is the defaultStack while it is built)
private command xtaSettingsSection pName, pText, @xTop
   xtaSettingsSectionIn pName, pText, xTop, kSettingsWidth
end xtaSettingsSection

-- A label at the left of a row
private command xtaSettingsLabel pText, pTop
   xtaUiLabel "Label" && pText, pText, "16," & (pTop + 4) & ",158," & (pTop + 20), 11
   set the textAlign of field ("Label" && pText) to "right"
   set the dontWrap of field ("Label" && pText) to true
end xtaSettingsLabel

-- A one-line entry field
private command xtaSettingsField pName, pLeft, pTop, pRight
   xtaUiInput pName, pLeft & comma & pTop & comma & pRight & comma & (pTop + 24)
   set the dontWrap of field pName to true
   set the autoTab of field pName to false
end xtaSettingsField

-- Small text that explains the row above it (or beside it, one line).
-- The top margin is 6: the engine starts a label's words 6 points above
-- its top margin, so with 4 they started 2 points above the note, and on
-- Linux the field cut a row of pixels off the tops of the first line's
-- capitals (rc.6.12c; the IDE tour's tourFieldsWhole measures it). The
-- margins are given as four numbers, the form the suite's kit found OXT
-- keeps.
private command xtaSettingsNote pName, pLeft, pTop, pRight, pHeight
   xtaUiLabel pName, empty, pLeft & comma & pTop & comma & pRight & comma & (pTop + pHeight), 10
   set the foregroundColor of field pName to xtaUi("Muted")
   set the dontWrap of field pName to (pHeight < 24)
   set the margins of field pName to "1,6,1,1"
end xtaSettingsNote

private command xtaSettingsCheckbox pName, pLabel, pLeft, pTop, pRight
   create button pName
   set the style of button pName to "checkbox"
   set the hiliteBorder of button pName to false
   set the label of button pName to pLabel
   set the foregroundColor of button pName to xtaUi("Ink")
   set the rect of button pName to pLeft, pTop, pRight, pTop + 20
end xtaSettingsCheckbox

-- Shows pProvider's settings: what was typed for it before the dialog was
-- switched to another, else what is kept. With pAll, the settings that are
-- the same for every provider too.
private command xtaFillSettings pProvider, pAll
   local tMenu, tModel, tNote
   lock messages
   set the label of button "Provider" of stack kSettingsWindow to xtaProviderName(pProvider)
   put sDrafts[pProvider]["key"] into field "Key" of stack kSettingsWindow
   if "baseUrl" is among the keys of sDrafts[pProvider] then
      put sDrafts[pProvider]["baseUrl"] into field "Base URL" of stack kSettingsWindow
   else
      put xtaBaseUrl(pProvider) into field "Base URL" of stack kSettingsWindow
   end if
   if "model" is among the keys of sDrafts[pProvider] then
      put sDrafts[pProvider]["model"] into tModel
   else
      put xtaModel(pProvider) into tModel
   end if
   put sDrafts[pProvider]["menu"] into tMenu
   if tMenu is empty then
      put xtaModelMenu(pProvider, sModelMenus[pProvider]) into tMenu
   end if
   set the text of button "Model" of stack kSettingsWindow to tMenu
   set the label of button "Model" of stack kSettingsWindow to tModel
   put xtaKeyNote(pProvider) into field "Key Note" of stack kSettingsWindow
   put "Empty means" && xtaDefaultBaseUrl(pProvider) & "." into tNote
   if pProvider is "openai" then
      put " For a model on this computer, choose its server from Local (no key needed); for another service, from Services; or type its URL." after tNote
   else
      put " Local switches to a model on this computer, and Services to another online service." after tNote
   end if
   put tNote into field "Base URL Note" of stack kSettingsWindow
   xtaSettingsResult empty
   if pAll then
      put revIDEGetPreference(kPrefMaxTokens) into field "Max Tokens" of stack kSettingsWindow
      put xtaFixRounds() into field "Fix Rounds" of stack kSettingsWindow
      put revIDEGetPreference(kPrefTimeout) into field "Timeout" of stack kSettingsWindow
      set the hilite of button "Include" of stack kSettingsWindow to (revIDEGetPreference(kPrefIncludeScript) is not false)
      set the hilite of button "Tools" of stack kSettingsWindow to (revIDEGetPreference(kPrefTools) is not false)
      set the hilite of button "Pictures" of stack kSettingsWindow to (revIDEGetPreference(kPrefPictures) is not false)
      set the hilite of button "Build" of stack kSettingsWindow to (revIDEGetPreference(kPrefBuild) is not false)
      set the hilite of button "Short Guide" of stack kSettingsWindow to (revIDEGetPreference(kPrefShortGuide) is true)
   end if
   unlock messages
   xtaSettingsSwitches
end xtaFillSettings

-- The switches that do something with the others as they are: the tools
-- not with the short guide, and pictures and changing stacks only with
-- the tools
on xtaSettingsSwitches
   local tTools
   if there is not a stack kSettingsWindow then
      exit xtaSettingsSwitches
   end if
   put not the hilite of button "Short Guide" of stack kSettingsWindow into tTools
   set the enabled of button "Tools" of stack kSettingsWindow to tTools
   put tTools and the hilite of button "Tools" of stack kSettingsWindow into tTools
   set the enabled of button "Pictures" of stack kSettingsWindow to tTools
   set the enabled of button "Build" of stack kSettingsWindow to tTools
end xtaSettingsSwitches

-- What the dialog says on its status line (what Save and Get Models
-- found), colored as the kit colors the status line
private command xtaSettingsResult pText, pKind
   local tColor
   switch pKind
      case "ok"
         put xtaUi("Ok") into tColor
         break
      case "warn"
         put xtaUi("Warn") into tColor
         break
      case "bad"
         put xtaUi("Bad") into tColor
         break
      default
         put xtaUi("InkSoft") into tColor
   end switch
   lock messages
   set the text of field "Result" of stack kSettingsWindow to pText
   set the foregroundColor of field "Result" of stack kSettingsWindow to tColor
   unlock messages
end xtaSettingsResult

-- What the dialog says about pProvider's key. Only its last four
-- characters are ever shown.
private function xtaKeyNote pProvider
   local tName
   put xtaProviderName(pProvider) into tName
   if sKeys[pProvider] is not empty then
      return "A key is set, ending in" && quote & char -4 to -1 of sKeys[pProvider] & quote & \
            ". Paste another here to change it. It is kept in memory until you quit " & xtaHostName() & ", and never saved."
   end if
   if xtaKey(pProvider) is not empty then
      return "The key in the environment variable" && xtaKeyVariable(pProvider) && \
            "is used. Paste one here to use it instead (kept in memory until you quit, never saved)."
   end if
   return "Paste your" && tName && "API key here. It is kept in memory until you quit " & xtaHostName() & ", and never saved."
end xtaKeyNote

private function xtaKeyVariable pProvider
   switch pProvider
      case "anthropic"
         return "ANTHROPIC_API_KEY"
      case "openai"
         return "OPENAI_API_KEY"
   end switch
   return empty
end xtaKeyVariable

-- The Provider menu of the dialog: what was typed for the one shown is
-- kept as a draft, and the other's settings shown
on xtaSettingsProvider pName
   local tProvider
   if there is not a stack kSettingsWindow then
      exit xtaSettingsProvider
   end if
   repeat for each item tProvider in xtaProviders()
      if xtaProviderName(tProvider) is pName and tProvider is not sSettingsProvider then
         xtaKeepDraft sSettingsProvider
         put tProvider into sSettingsProvider
         xtaFillSettings tProvider, false
      end if
   end repeat
end xtaSettingsProvider

-- The Local menu of the dialog: one item per server (xtaLocalServers),
-- named with where it listens
private function xtaLocalServerItems
   local tItems, tLine
   set the itemDelimiter to tab
   repeat for each line tLine in xtaLocalServers()
      put item 1 of tLine && "(" & xtaHostOf(item 2 of tLine) & ")" & return after tItems
   end repeat
   delete the last char of tItems
   return tItems
end xtaLocalServerItems

-- The Services menu of the dialog: one item per service
-- (xtaOnlineServices), by name
private function xtaOnlineServiceItems
   local tItems, tLine
   set the itemDelimiter to tab
   repeat for each line tLine in xtaOnlineServices()
      put item 1 of tLine & return after tItems
   end repeat
   delete the last char of tItems
   return tItems
end xtaOnlineServiceItems

-- The host and port of a URL ("localhost:1234")
private function xtaHostOf pUrl
   if pUrl contains "://" then
      put char offset("://", pUrl) + 3 to -1 of pUrl into pUrl
   end if
   set the itemDelimiter to "/"
   return item 1 of pUrl
end xtaHostOf

-- A server on this computer chosen from Local: OpenAI's API, which those
-- servers speak, at its address. What was typed for the provider shown is
-- kept as a draft, as the Provider menu keeps it. A model of OpenAI's own
-- is not one the server has, so it goes, and Get Models asks the server
-- for its models at once: that chooses one, or says the server is not
-- running. Nothing is kept until Save.
on xtaSettingsLocal pItem
   local tLine, tUrl, tModel
   if there is not a stack kSettingsWindow then
      exit xtaSettingsLocal
   end if
   set the itemDelimiter to tab
   repeat for each line tLine in xtaLocalServers()
      if pItem begins with item 1 of tLine then
         put item 2 of tLine into tUrl
         exit repeat
      end if
   end repeat
   if tUrl is empty then
      exit xtaSettingsLocal
   end if
   if sSettingsProvider is not "openai" then
      xtaKeepDraft sSettingsProvider
      put "openai" into sSettingsProvider
      xtaFillSettings "openai", false
   end if
   lock messages
   put tUrl into field "Base URL" of stack kSettingsWindow
   put the label of button "Model" of stack kSettingsWindow into tModel
   if tModel is empty or tModel is among the lines of xtaSuggestedModels("openai") then
      set the label of button "Model" of stack kSettingsWindow to empty
      set the text of button "Model" of stack kSettingsWindow to empty
      put empty into sDrafts["openai"]["menu"]
   end if
   unlock messages
   xtaSettingsGetModels
   -- Ollama runs a model with 4096 tokens of context unless told
   -- otherwise, and cuts a longer prompt short without a word (the guide
   -- alone is longer: on a real Ollama, 2050 of its tokens arrived), so
   -- the model would answer without most of it. LM Studio refuses such a
   -- request instead, and xtaLocalServerHint says what to do then.
   if pItem begins with "Ollama" and there is a stack kSettingsWindow then
      if field "Result" of stack kSettingsWindow contains "listed" then
         xtaSettingsResult field "Result" of stack kSettingsWindow && \
               "Ollama gives a model 4096 tokens unless its Context length is raised (16000 or more), or tick Short guide.", "ok"
      end if
   end if
end xtaSettingsLocal

-- An online service chosen from Services: OpenAI's API at its address, as
-- Local does for a server on this computer. A key typed for another
-- service is not sent to this one: when the host changes, the key goes
-- from the dialog, and Save forgets it (sDrafts' "forgetKey") unless
-- another is pasted. With no key, the dialog says where to make one;
-- with one, Get Models asks the service for its models. Nothing is kept
-- until Save.
on xtaSettingsService pItem
   local tLine, tUrl, tPage, tOld, tModel
   if there is not a stack kSettingsWindow then
      exit xtaSettingsService
   end if
   set the itemDelimiter to tab
   repeat for each line tLine in xtaOnlineServices()
      if pItem is item 1 of tLine then
         put item 2 of tLine into tUrl
         put item 3 of tLine into tPage
         exit repeat
      end if
   end repeat
   if tUrl is empty then
      exit xtaSettingsService
   end if
   if sSettingsProvider is not "openai" then
      xtaKeepDraft sSettingsProvider
      put "openai" into sSettingsProvider
      xtaFillSettings "openai", false
   end if
   lock messages
   put word 1 to -1 of field "Base URL" of stack kSettingsWindow into tOld
   if tOld is empty then
      put xtaDefaultBaseUrl("openai") into tOld
   end if
   if xtaHostOf(tOld) is not xtaHostOf(tUrl) then
      put empty into field "Key" of stack kSettingsWindow
      put true into sDrafts["openai"]["forgetKey"]
      put "Paste your" && pItem && "API key here. It is kept in memory until you quit " & xtaHostName() & ", and never saved." into field "Key Note" of stack kSettingsWindow
   end if
   put tUrl into field "Base URL" of stack kSettingsWindow
   put the label of button "Model" of stack kSettingsWindow into tModel
   if tOld is not tUrl or tModel is empty or tModel is among the lines of xtaSuggestedModels("openai") then
      set the label of button "Model" of stack kSettingsWindow to empty
      set the text of button "Model" of stack kSettingsWindow to empty
      put empty into sDrafts["openai"]["menu"]
   end if
   unlock messages
   if word 1 to -1 of field "Key" of stack kSettingsWindow is empty then
      xtaKeepDraft "openai"
      xtaSettingsResult pItem & ": paste your API key (make one at" && tPage & "), then press Get Models.", "warn"
      exit xtaSettingsService
   end if
   xtaSettingsGetModels
end xtaSettingsService

private command xtaKeepDraft pProvider
   put field "Key" of stack kSettingsWindow into sDrafts[pProvider]["key"]
   put field "Base URL" of stack kSettingsWindow into sDrafts[pProvider]["baseUrl"]
   put the label of button "Model" of stack kSettingsWindow into sDrafts[pProvider]["model"]
end xtaKeepDraft

on xtaSettingsForgetKey
   if there is not a stack kSettingsWindow then
      exit xtaSettingsForgetKey
   end if
   put empty into sKeys[sSettingsProvider]
   put empty into sDrafts[sSettingsProvider]["key"]
   put empty into field "Key" of stack kSettingsWindow
   put xtaKeyNote(sSettingsProvider) into field "Key Note" of stack kSettingsWindow
   xtaSettingsResult "The key is forgotten.", "ok"
end xtaSettingsForgetKey

-- Get Models: the provider's list, asked with what is in the dialog
on xtaSettingsGetModels
   local tProvider, tSettings, tResult, tMenu, tCount, tKeyless
   if there is not a stack kSettingsWindow then
      exit xtaSettingsGetModels
   end if
   put sSettingsProvider into tProvider
   xtaKeepDraft tProvider
   put xtaSettingsChecked() into tSettings
   if tSettings["error"] is not empty then
      xtaSettingsResult tSettings["error"], "bad"
      exit xtaSettingsGetModels
   end if
   put tProvider into tSettings["provider"]
   put tSettings["drafts"][tProvider]["baseUrl"] into tSettings["baseUrl"]
   put tSettings["drafts"][tProvider]["key"] into tSettings["key"]
   -- (not the key of the service before one chosen from Services)
   if tSettings["key"] is empty and sDrafts[tProvider]["forgetKey"] is not true then
      put xtaKey(tProvider) into tSettings["key"]
   end if
   if tSettings["key"] is empty and tSettings["baseUrl"] is empty then
      xtaSettingsResult "Paste the API key first.", "warn"
      exit xtaSettingsGetModels
   end if
   xtaSettingsResult "Asking" && xtaProviderName(tProvider) && "for its models..."
   set the enabled of button "Get Models" of stack kSettingsWindow to false
   put xtaListModels(tSettings) into tResult
   -- A local server needs no key, and the words for a list say so
   put (tSettings["key"] is empty) into tKeyless
   put empty into tSettings
   -- Closed meanwhile (Cancel works while it waits), or switched provider
   if there is not a stack kSettingsWindow then
      exit xtaSettingsGetModels
   end if
   set the enabled of button "Get Models" of stack kSettingsWindow to true
   if sSettingsProvider is not tProvider then
      exit xtaSettingsGetModels
   end if
   if tResult["error"] is not empty then
      xtaSettingsResult "That did not work:" && tResult["error"], "bad"
      exit xtaSettingsGetModels
   end if
   put xtaModelMenu(tProvider, tResult["models"]) into tMenu
   put tMenu into sDrafts[tProvider]["menu"]
   put the number of lines of tResult["models"] into tCount
   lock messages
   set the text of button "Model" of stack kSettingsWindow to tMenu
   if word 1 to -1 of the label of button "Model" of stack kSettingsWindow is empty then
      set the label of button "Model" of stack kSettingsWindow to tResult["default"]
   end if
   unlock messages
   if tKeyless then
      xtaSettingsResult xtaProviderName(tProvider) && "listed" && tCount && "models. Choose one, then Save.", "ok"
   else
      xtaSettingsResult xtaProviderName(tProvider) && "listed" && tCount && "models, so it takes the key. Choose one, then Save.", "ok"
   end if
end xtaSettingsGetModels

-- What the dialog holds, checked: "drafts" (by provider: "key", "baseUrl"
-- and "model", trimmed, a base URL that is the provider's own as empty),
-- "maxTokens", "fixRounds" and "timeout"; or "error", why it cannot be
-- kept, in words for the user. The shown provider's fields must be in
-- sDrafts already (xtaKeepDraft).
private function xtaSettingsChecked
   local tChecked, tProvider, tKey, tUrl, tNumber
   repeat for each key tProvider in sDrafts
      put word 1 to -1 of sDrafts[tProvider]["key"] into tKey
      if tKey contains numToChar(10) or tKey contains numToChar(13) or tKey contains space or tKey contains tab then
         put "The" && xtaProviderName(tProvider) && "key has a space or a line break in it: paste it again, just the key." into tChecked["error"]
         return tChecked
      end if
      put tKey into tChecked["drafts"][tProvider]["key"]
      put word 1 to -1 of sDrafts[tProvider]["baseUrl"] into tUrl
      if tUrl is xtaDefaultBaseUrl(tProvider) then
         put empty into tUrl
      end if
      if tUrl is not empty and not (tUrl begins with "https://" or tUrl begins with "http://") then
         put "A base URL begins with https:// (or http:// for a server on this computer)." into tChecked["error"]
         return tChecked
      end if
      put tUrl into tChecked["drafts"][tProvider]["baseUrl"]
      put word 1 to -1 of sDrafts[tProvider]["model"] into tChecked["drafts"][tProvider]["model"]
   end repeat
   put word 1 to -1 of field "Max Tokens" of stack kSettingsWindow into tNumber
   if tNumber is not empty and not (tNumber is an integer and tNumber >= 1 and tNumber <= kMaxMaxTokens) then
      put "The longest answer is a whole number of tokens, from 1 to" && kMaxMaxTokens & ", or empty." into tChecked["error"]
      return tChecked
   end if
   put tNumber into tChecked["maxTokens"]
   put word 1 to -1 of field "Fix Rounds" of stack kSettingsWindow into tNumber
   if tNumber is empty then
      put kDefaultFixRounds into tNumber
   end if
   if not (tNumber is an integer and tNumber >= 0 and tNumber <= kMaxFixRounds) then
      put "The fix rounds are a whole number from 0 to" && kMaxFixRounds & "." into tChecked["error"]
      return tChecked
   end if
   put tNumber into tChecked["fixRounds"]
   put word 1 to -1 of field "Timeout" of stack kSettingsWindow into tNumber
   if tNumber is not empty and not (tNumber is an integer and tNumber >= kMinTimeout and tNumber <= kMaxTimeout) then
      put "The wait for an answer is a whole number of seconds, from" && kMinTimeout && "to" && kMaxTimeout & ", or empty." into tChecked["error"]
      return tChecked
   end if
   put tNumber into tChecked["timeout"]
   return tChecked
end xtaSettingsChecked

-- Save: keeps what the dialog holds, for every provider it showed, and
-- closes it; or says what is wrong and keeps it open
on xtaSettingsSave
   local tProvider, tChecked, tOther, tKey, tUrl
   if there is not a stack kSettingsWindow then
      exit xtaSettingsSave
   end if
   put sSettingsProvider into tProvider
   xtaKeepDraft tProvider
   put xtaSettingsChecked() into tChecked
   if tChecked["error"] is not empty then
      xtaSettingsResult tChecked["error"], "bad"
      exit xtaSettingsSave
   end if
   put false into sSettingsFetch
   repeat for each key tOther in tChecked["drafts"]
      put tChecked["drafts"][tOther]["key"] into tKey
      if tKey is not empty and tKey is not sKeys[tOther] then
         put tKey into sKeys[tOther]
         put empty into sModelMenus[tOther]
         if tOther is tProvider then
            put true into sSettingsFetch
         end if
      else if tKey is empty and sDrafts[tOther]["forgetKey"] is true then
         -- Another service was chosen from Services: its key is not this one's
         put empty into sKeys[tOther]
         put empty into sModelMenus[tOther]
      end if
      put tChecked["drafts"][tOther]["baseUrl"] into tUrl
      if tUrl is not xtaBaseUrl(tOther) then
         revIDESetPreference kPrefBaseUrl & tOther, tUrl
         -- The list was another server's
         put empty into sModelMenus[tOther]
         if tOther is tProvider then
            put true into sSettingsFetch
         end if
      end if
      if sDrafts[tOther]["menu"] is not empty then
         put sDrafts[tOther]["menu"] into sModelMenus[tOther]
      end if
      if tChecked["drafts"][tOther]["model"] is not xtaModel(tOther) then
         revIDESetPreference kPrefModel & tOther, tChecked["drafts"][tOther]["model"]
      end if
   end repeat
   if tProvider is not xtaProvider() then
      revIDESetPreference kPrefProvider, tProvider
      put true into sSettingsFetch
   end if
   -- The list was just asked for with these settings
   if sDrafts[tProvider]["menu"] is not empty then
      put false into sSettingsFetch
   else if xtaModel(tProvider) is empty then
      put true into sSettingsFetch
   end if
   revIDESetPreference kPrefMaxTokens, tChecked["maxTokens"]
   revIDESetPreference kPrefFixRounds, tChecked["fixRounds"] + 0
   revIDESetPreference kPrefTimeout, tChecked["timeout"]
   revIDESetPreference kPrefIncludeScript, the hilite of button "Include" of stack kSettingsWindow
   revIDESetPreference kPrefTools, the hilite of button "Tools" of stack kSettingsWindow
   revIDESetPreference kPrefPictures, the hilite of button "Pictures" of stack kSettingsWindow
   revIDESetPreference kPrefBuild, the hilite of button "Build" of stack kSettingsWindow
   revIDESetPreference kPrefShortGuide, the hilite of button "Short Guide" of stack kSettingsWindow
   put empty into tChecked
   put true into sSettingsSaved
   close stack kSettingsWindow
end xtaSettingsSave

-- Asks the provider for its models and lets the user pick one from the
-- combo box (Models, and after a key is typed).
on xtaChooseModels
   local tProvider, tError
   if sBusy is true then
      exit xtaChooseModels
   end if
   put xtaProvider() into tProvider
   if not xtaEnsureKey(tProvider) then
      exit xtaChooseModels
   end if
   put xtaLoadModels() into tError
   if tError is not empty then
      exit xtaChooseModels
   end if
   xtaStatus xtaProviderName(tProvider) && "has" && the number of lines of the text of button "Model" of stack kWindow && \
         "models. Using" && xtaModel(tProvider) & ": choose another from the model menu."
end xtaChooseModels

-- Asks the provider for its models and puts them in the model menu. When no
-- model is chosen yet, it chooses the one the provider's list suggests
-- (xtaDefaultModel), so that the assistant works without the user knowing
-- a model's name. Returns empty; or why there are none, which the user has
-- been told; or "stopped" when the user pressed Stop meanwhile (the menu is
-- filled all the same); or "closed" when the window went away.
private function xtaLoadModels
   local tProvider, tResult, tShutDowns, tModels, tStopped
   put xtaProvider() into tProvider
   put true into sBusy
   put false into sStopAsked
   xtaUpdateButtons
   xtaStatus "Asking" && xtaProviderName(tProvider) && "for its models..."
   put sShutDowns into tShutDowns
   put xtaListModels(xtaSettings()) into tResult
   if sShutDowns is not tShutDowns then
      return "closed"
   end if
   put false into sBusy
   put (sStopAsked is true) into tStopped
   put false into sStopAsked
   if there is not a stack kWindow then
      return "closed"
   end if
   xtaUpdateButtons
   if tResult["error"] is not empty then
      -- As Send does: a key the provider refused is asked for again
      if line 1 of tResult["error"] contains "API key" then
         put empty into sKeys[tProvider]
      end if
      xtaStatus xtaSettingsLine()
      answer warning tResult["error"] titled kTitle
      return tResult["error"]
   end if
   if xtaModel(tProvider) is empty then
      revIDESetPreference kPrefModel & tProvider, tResult["default"]
   end if
   put xtaModelMenu(tProvider, tResult["models"]) into tModels
   put tModels into sModelMenus[tProvider]
   lock messages
   set the text of button "Model" of stack kWindow to tModels
   set the label of button "Model" of stack kWindow to xtaModel(tProvider)
   unlock messages
   if tStopped then
      xtaStatus xtaSettingsLine()
      return "stopped"
   end if
   return empty
end xtaLoadModels

-- True when there is a key for the provider, asking the user for one (in
-- the Settings dialog) if needed. A base URL of the user's own (a local
-- server) may need none. The user may switch the provider in the dialog,
-- so the caller reads xtaProvider() again after it.
private function xtaEnsureKey pProvider
   if xtaKey(pProvider) is not empty or xtaBaseUrl(pProvider) is not empty then
      return true
   end if
   if not xtaOpenSettings("Key") then
      return false
   end if
   put xtaProvider() into pProvider
   return xtaKey(pProvider) is not empty or xtaBaseUrl(pProvider) is not empty
end xtaEnsureKey

-- How many times code that does not compile goes back to the model
private function xtaFixRounds
   local tRounds
   put revIDEGetPreference(kPrefFixRounds) into tRounds
   if tRounds is an integer then
      if tRounds >= 0 and tRounds <= kMaxFixRounds then
         return tRounds
      end if
   end if
   return kDefaultFixRounds
end xtaFixRounds

-- The folder of the plugin's files
private function xtaPluginFolder
   set the itemDelimiter to slash
   return item 1 to -2 of the effective filename of me
end xtaPluginFolder

-- What the model is told first: the guide, the same in every request and
-- so marked for the provider's cache, then the notes the user keeps, about
-- themselves and about the stack pWork (as xtaWorkStack gives it). The
-- short guide is used when the user asks for it, or when the guide's file
-- cannot be read.
private function xtaSystem pWork
   local tSystem
   if revIDEGetPreference(kPrefShortGuide) is true then
      put xtaSystemPrompt() into tSystem[1]["text"]
   else
      if sGuide is empty then
         put xtaReadGuide(xtaPluginFolder() & slash & kGuideFile) into sGuide
      end if
      if sGuide is empty then
         put xtaSystemPrompt() into tSystem[1]["text"]
      else
         put sGuide into tSystem[1]["text"]
      end if
   end if
   put true into tSystem[1]["cache"]
   put xtaMemoryPrompt(xtaCurrentMemory(), pWork["path"], pWork["name"]) into tSystem[2]["text"]
   put false into tSystem[2]["cache"]
   return tSystem
end xtaSystem

-- The stack the user is working on: that of the script open in the Script
-- Editor, or else the topmost stack that is not one of the IDE's. An array
-- with "stack" (the long id of its main stack), "path" (the main stack's
-- file) and "name" (the main stack's name), all empty when there is none,
-- and the last two when it was never saved.
private function xtaWorkStack
   local tEditor, tObject, tStack, tWork, tPath, tName
   put xtaTopScriptEditor() into tEditor
   if tEditor is not empty then
      try
         dispatch "revSEGetCurrentObject" to tEditor
         put the result into tObject
      catch tError
         put empty into tObject
      end try
   end if
   if tObject is not empty and there is a tObject then
      put revIDEStackOfObject(tObject) into tStack
   else
      -- The topStack can be one of the IDE's windows (the Project Browser,
      -- the Dictionary, ...), in front of the user's stack: then the
      -- frontmost open stack that is not (the openStacks lists them from
      -- the front)
      put the topStack into tStack
      if tStack is empty or there is not a tStack or xtaIsIDEStack(tStack) then
         put empty into tStack
         repeat for each line tName in the openStacks
            if there is a stack tName then
               if the visible of stack tName and not xtaIsIDEStack(the long id of stack tName) then
                  put the long id of stack tName into tStack
                  exit repeat
               end if
            end if
         end repeat
      end if
   end if
   if tStack is empty or there is not a tStack then
      return tWork
   end if
   if xtaIsIDEStack(tStack) then
      return tWork
   end if
   -- A substack's owner is its main stack
   if the owner of tStack is empty then
      put the long id of tStack into tWork["stack"]
   else
      put the long id of the owner of tStack into tWork["stack"]
   end if
   put the effective filename of tStack into tPath
   if tPath is empty then
      return tWork
   end if
   put tPath into tWork["path"]
   put the mainStack of tStack into tWork["name"]
   return tWork
end xtaWorkStack

-- True for one of the IDE's stacks, as revIDEStackNameIsIDEStack has it
-- (which this does not call, so that the tests need no IDE)
private function xtaIsIDEStack pStack
   local tName
   put the short name of pStack into tName
   if tName begins with "rev" or tName begins with "com.livecode." then
      return true
   end if
   if tName is among the items of "Message Box,Answer Dialog,Ask Dialog,Home" then
      return true
   end if
   return the _ideoverride of pStack is true
end xtaIsIDEStack

--------------------------------------------------------------------------------
-- Memory

-- The memory's file, in the user's preferences folder, or empty when the
-- IDE does not say where that is
private function xtaMemoryPath
   local tFolder
   try
      put revEnvironmentUserPreferencesPath() into tFolder
   catch tError
      put empty into tFolder
   end try
   if tFolder is empty then
      return empty
   end if
   return tFolder & slash & kMemoryFile
end xtaMemoryPath

-- The memory as its file has it now (the user may have edited the file)
private function xtaCurrentMemory
   return xtaMemoryLoad(xtaMemoryPath())
end xtaCurrentMemory

-- Writes the memory; the result is empty, or why it could not
private command xtaSaveMemory pMemory
   local tPath
   put xtaMemoryPath() into tPath
   if tPath is empty then
      return "The preferences folder is not known, so the notes cannot be kept."
   end if
   xtaMemorySave tPath, pMemory
   if the result is not empty then
      return "The notes could not be saved in" && tPath & ":" && the result
   end if
   return empty
end xtaSaveMemory

-- Remember or Dismiss, clicked under an answer: pLink is "remember" or
-- "dismiss", the turn and the note
on xtaNoteClicked pLink
   local tAction, tTurn, tIndex, tNote, tScope, tPath, tMemory, tProblem
   put item 1 of pLink into tAction
   put item 2 of pLink into tTurn
   put item 3 of pLink into tIndex
   if tTurn is not an integer or tIndex is not an integer then
      exit xtaNoteClicked
   end if
   put sTurns[tTurn]["notes"][tIndex]["note"] into tNote
   if tNote is empty or sTurns[tTurn]["notes"][tIndex]["state"] is not empty then
      exit xtaNoteClicked
   end if
   if tAction is "dismiss" then
      put "dismissed" into sTurns[tTurn]["notes"][tIndex]["state"]
      xtaShowConversation
      exit xtaNoteClicked
   end if
   if tAction is not "remember" then
      exit xtaNoteClicked
   end if
   put sTurns[tTurn]["notes"][tIndex]["scope"] into tScope
   put sTurns[tTurn]["stackPath"] into tPath
   if tScope is "stack" and tPath is empty then
      answer question "This note is about a stack, and the stack has never been saved, so there is no file to keep the note with. Keep it as a note about you?" \
            with "Cancel" or "Keep About Me" titled kTitle
      if it is not "Keep About Me" then
         exit xtaNoteClicked
      end if
      put "you" into tScope
      put tScope into sTurns[tTurn]["notes"][tIndex]["scope"]
   end if
   put xtaCurrentMemory() into tMemory
   xtaMemoryAdd tMemory, tScope, tPath, tNote
   put the result into tProblem
   if tProblem is empty then
      xtaSaveMemory tMemory
      put the result into tProblem
   end if
   if tProblem is not empty then
      answer warning tProblem titled kTitle
      exit xtaNoteClicked
   end if
   put "kept" into sTurns[tTurn]["notes"][tIndex]["state"]
   xtaShowConversation
end xtaNoteClicked

-- More > Memory...: the notes about the user and about the stack they are
-- working on, to read and edit, and Forget All
private command xtaEditMemory
   local tWork, tMemory, tYou, tStackNotes, tChoice, tProblem
   put xtaWorkStack() into tWork
   put xtaCurrentMemory() into tMemory
   put xtaMemoryNotes(tMemory, "you", empty) into tYou
   put xtaMemoryNotes(tMemory, "stack", tWork["path"]) into tStackNotes
   repeat forever
      put xtaMemoryDialog(tWork, tYou, tStackNotes) into tChoice
      if tChoice["choice"] is "save" then
         put tChoice["you"] into tYou
         put tChoice["stack"] into tStackNotes
         xtaMemorySetNotes tMemory, "you", empty, tYou
         put the result into tProblem
         if tProblem is empty and tWork["path"] is not empty then
            xtaMemorySetNotes tMemory, "stack", tWork["path"], tStackNotes
            put the result into tProblem
         end if
         if tProblem is empty then
            xtaSaveMemory tMemory
            put the result into tProblem
         end if
         if tProblem is empty then
            exit repeat
         end if
         answer warning tProblem titled kTitle
         -- What was refused is shown again, to correct; the memory is read
         -- again, so that nothing half-changed is kept
         put xtaCurrentMemory() into tMemory
      else if tChoice["choice"] is "forget" then
         answer question "Forget every note, about you and about every stack? This cannot be undone." \
               with "Cancel" or "Forget All" titled kTitle
         if it is "Forget All" then
            put empty into tMemory
            xtaSaveMemory tMemory
            put the result into tProblem
            if tProblem is not empty then
               answer warning tProblem titled kTitle
            end if
            exit repeat
         end if
         put tChoice["you"] into tYou
         put tChoice["stack"] into tStackNotes
      else
         exit repeat
      end if
   end repeat
end xtaEditMemory

-- Shows the memory's notes in a modal window, and returns what the user
-- chose ("choice": "save", "forget" or "cancel") and the notes as they
-- left them ("you", "stack"). The window is made here, like the
-- assistant's and in its look, and deleted when it closes.
private function xtaMemoryDialog pWork, pYou, pStackNotes
   local tOldDefault, tResult, tScript, tTop, tRight
   if there is a stack kMemoryWindow then
      delete stack kMemoryWindow
   end if
   put kMemoryWidth - 16 into tRight
   put the defaultStack into tOldDefault
   get xtaFollowAppearance()
   lock screen
   lock messages
   create invisible stack kMemoryWindow
   set the defaultStack to kMemoryWindow
   set the resizable of stack kMemoryWindow to false
   set the _ideoverride of stack kMemoryWindow to true
   xtaUiChrome kTitle && "Memory", kMemoryWidth, 480
   put "The notes go to the provider with every question. Notes that look like a key or a password are refused." into field "Status"
   set the dontWrap of field "Status" to false
   set the rect of field "Status" to 16, kUiBand + 4, tRight, kUiBand + 34

   put kUiBand + 42 into tTop
   xtaSettingsSectionIn "Section1", "1  About you", tTop, kMemoryWidth
   xtaUiCap "YouLabel", "For every stack: one note per line.", "16," & tTop & comma & tRight & comma & (tTop + 16)
   put (the bottom of field "YouLabel") + 6 into tTop
   xtaMemoryNotesField "You", 16, tTop, tRight, tTop + 112
   put pYou into field "You"

   put tTop + 124 into tTop
   xtaSettingsSectionIn "Section2", "2  About this stack", tTop, kMemoryWidth
   xtaUiCap "StackLabel", empty, "16," & tTop & comma & tRight & comma & (tTop + 28)
   set the height of field "StackLabel" to 28
   xtaMemoryNotesField "Stack", 16, tTop + 32, tRight, tTop + 144
   if pWork["path"] is empty then
      put "Open a saved stack, or save this one, to keep notes about it." into field "StackLabel"
      set the lockText of field "Stack" to true
      set the enabled of field "Stack" to false
   else
      put "The stack" && quote & pWork["name"] & quote & ", kept with its file's path (never in the stack): one note per line." into field "StackLabel"
      put pStackNotes into field "Stack"
   end if
   put tTop + 156 into tTop

   put "on mouseUp" & return & "   set the cXtaChoice of stack " & quote & kMemoryWindow & quote & " to " & quote & "[[choice]]" & quote & return & \
         "   close stack " & quote & kMemoryWindow & quote & return & "end mouseUp" into tScript
   create button "Forget"
   set the label of button "Forget" to "Forget All..."
   set the rect of button "Forget" to 16, tTop, 126, tTop + 24
   set the script of button "Forget" to replaceText(tScript, "\[\[choice\]\]", "forget")
   create button "Cancel"
   set the rect of button "Cancel" to tRight - 188, tTop, tRight - 98, tTop + 24
   set the script of button "Cancel" to replaceText(tScript, "\[\[choice\]\]", "cancel")
   create button "Save"
   set the rect of button "Save" to tRight - 90, tTop, tRight, tTop + 24
   set the script of button "Save" to replaceText(tScript, "\[\[choice\]\]", "save")
   set the cXtaChoice of stack kMemoryWindow to "cancel"
   xtaUiFooter "Kept in" && quote & kMemoryFile & quote & ", in the preferences folder.", "16," & (tTop + 32) & comma & tRight & comma & (tTop + 50)
   set the height of stack kMemoryWindow to tTop + 58
   xtaMemoryResizable

   unlock messages
   set the defaultStack to tOldDefault
   set the loc of stack kMemoryWindow to the screenLoc
   xtaKeepOnScreen the long id of stack kMemoryWindow, false
   -- Made invisible, so it is shown before it opens as a modal window (as
   -- the assistant's window must be)
   xtaUiButtons kMemoryWindow, "Save"
   set the visible of stack kMemoryWindow to true
   unlock screen
   modal stack kMemoryWindow

   if there is not a stack kMemoryWindow then
      put "cancel" into tResult["choice"]
      return tResult
   end if
   put the cXtaChoice of stack kMemoryWindow into tResult["choice"]
   put field "You" of stack kMemoryWindow into tResult["you"]
   put field "Stack" of stack kMemoryWindow into tResult["stack"]
   lock messages
   delete stack kMemoryWindow
   unlock messages
   return tResult
end xtaMemoryDialog

-- The memory window opens at the size it is built at and can be made
-- larger, never smaller: the notes fields share the height it gains and
-- take the width, and the buttons and the footer keep to its foot. Its
-- stack script does it, from a line per control: its name, how it takes
-- the width ("s" stretches, "m" moves, "f" stays), how it takes the height
-- ("g1" grows by half, "m1" moves by half, "g2" moves by half and grows by
-- the other half, "m" moves, "f" stays), and its rect as built. The
-- header's gradient is carried to the new width too.
private command xtaMemoryResizable
   local tRules, tRule, tLayout, tScript
   put "uiBand,s,f|uiTitle,s,f|Status,s,f|Section1,s,f|Section1Line,s,f|YouLabel,s,f|You,s,g1|" & \
         "Section2,s,m1|Section2Line,s,m1|StackLabel,s,m1|Stack,s,g2|Forget,f,m|Cancel,m,m|Save,m,m|uiFooter,s,m" into tRules
   replace "|" with return in tRules
   repeat for each line tRule in tRules
      put tRule & comma & the rect of control (item 1 of tRule) of this card of stack kMemoryWindow & return after tLayout
   end repeat
   delete the last char of tLayout
   set the cXtaLayout of stack kMemoryWindow to tLayout
   set the cXtaBaseWidth of stack kMemoryWindow to the width of stack kMemoryWindow
   set the cXtaBaseHeight of stack kMemoryWindow to the height of stack kMemoryWindow
   put "on resizeStack pWidth, pHeight" & return & \
         "   local tDX, tDY, tHalf, tRule, tRect, tFill, tError" & return & \
         "   put pWidth - the cXtaBaseWidth of me into tDX" & return & \
         "   put pHeight - the cXtaBaseHeight of me into tDY" & return & \
         "   put tDY div 2 into tHalf" & return & \
         "   lock screen" & return & \
         "   repeat for each line tRule in the cXtaLayout of me" & return & \
         "      put item 4 to 7 of tRule into tRect" & return & \
         "      if item 2 of tRule is " & quote & "s" & quote & " then" & return & \
         "         add tDX to item 3 of tRect" & return & \
         "      else if item 2 of tRule is " & quote & "m" & quote & " then" & return & \
         "         add tDX to item 1 of tRect" & return & \
         "         add tDX to item 3 of tRect" & return & \
         "      end if" & return & \
         "      if item 3 of tRule is " & quote & "g1" & quote & " then" & return & \
         "         add tHalf to item 4 of tRect" & return & \
         "      else if item 3 of tRule is " & quote & "m1" & quote & " then" & return & \
         "         add tHalf to item 2 of tRect" & return & \
         "         add tHalf to item 4 of tRect" & return & \
         "      else if item 3 of tRule is " & quote & "g2" & quote & " then" & return & \
         "         add tHalf to item 2 of tRect" & return & \
         "         add tDY to item 4 of tRect" & return & \
         "      else if item 3 of tRule is " & quote & "m" & quote & " then" & return & \
         "         add tDY to item 2 of tRect" & return & \
         "         add tDY to item 4 of tRect" & return & \
         "      end if" & return & \
         "      set the rect of control (item 1 of tRule) of this card of me to tRect" & return & \
         "   end repeat" & return & \
         "   try" & return & \
         "      put the fillGradient of graphic " & quote & "uiBand" & quote & " of this card of me into tFill" & return & \
         "      put pWidth & " & quote & ",0" & quote & " into tFill[" & quote & "to" & quote & "]" & return & \
         "      set the fillGradient of graphic " & quote & "uiBand" & quote & " of this card of me to tFill" & return & \
         "   catch tError" & return & \
         "   end try" & return & \
         "   unlock screen" & return & \
         "   pass resizeStack" & return & \
         "end resizeStack" into tScript
   set the script of stack kMemoryWindow to tScript
   set the minWidth of stack kMemoryWindow to the width of stack kMemoryWindow
   set the minHeight of stack kMemoryWindow to the height of stack kMemoryWindow
   set the resizable of stack kMemoryWindow to true
end xtaMemoryResizable

-- A numbered section's header at xTop in a window pWidth wide, which then
-- is where what follows it goes
private command xtaSettingsSectionIn pName, pText, @xTop, pWidth
   xtaUiSection pName, pText, "16," & xTop & comma & (pWidth - 16) & comma & (xTop + 20)
   put (the bottom of graphic (pName & "Line")) + 8 into xTop
end xtaSettingsSectionIn

-- A field of notes, one per line: an entry field of the kit's that wraps
-- and scrolls
private command xtaMemoryNotesField pName, pLeft, pTop, pRight, pBottom
   xtaUiInput pName, pLeft & comma & pTop & comma & pRight & comma & pBottom
   set the dontWrap of field pName to false
   set the vScrollbar of field pName to true
end xtaMemoryNotesField

--------------------------------------------------------------------------------
-- Tools
--
-- What the model may ask the plugin to do while it answers. Five read: the
-- Dictionary, a compile check, the user's stack and where a script of
-- theirs is paused in the debugger (which the user is asked to allow
-- first, since their scripts then go to the provider), and the last error
-- the IDE showed the user. The core makes what they read into text for the
-- model. Two change or run something (xtalkassistant-build.livecodescript
-- does both), and the window's bar asks the user first: make_changes, a
-- batch of changes to a stack, which the user applies or not, every time;
-- and run_code, code to run in a sandbox or on the user's stack, which the
-- user can allow for the session, except code that reaches files, the
-- network or other programs, which is asked about every time.

-- The tools as xtaRequestBody takes them. A backquote in a schema stands
-- for a double quote.
private function xtaTools
   local tTools, tIndex
   put "lookup_dictionary" into tTools[1]["name"]
   put "Looks up an entry of the " & xtaHostName() & " Dictionary: a command, function, property, message, keyword, constant or control structure of xTalk Script " & \
         "(put, split, topStack, mouseUp, repeat...). Gives its syntax, parameters, description and examples. Look up what you are not sure exists " & \
         "or how it is written before you use it in code, rather than guess." into tTools[1]["description"]
   put "{`type`:`object`,`properties`:{`term`:{`type`:`string`,`description`:`The entry's name alone: topStack, not the topStack`}},`required`:[`term`]}" \
         into tTools[1]["schema"]
   put "check_code" into tTools[2]["name"]
   put "Compiles xTalk Script on " & xtaHostName() & "'s engine as the Script Editor does, without running it, and gives each problem with its line: " & \
         "compile errors, curly quotes, lines outside any handler, a handler defined twice and, in handlers, names never declared. " & \
         "Give whole handlers, or statements (checked inside a handler of their own). Every livecodescript block of your answer is checked " & \
         "anyway; this lets you correct code before you answer with it." into tTools[2]["description"]
   put "{`type`:`object`,`properties`:{`code`:{`type`:`string`,`description`:`The code, as it would be in a script`}},`required`:[`code`]}" \
         into tTools[2]["schema"]
   put "read_stack" into tTools[3]["name"]
   put "Reads the stack the user is working on (that of the script open in the Script Editor, or else the stack in front). With nothing given: " & \
         "an outline of it and its substacks, their cards and their controls with ids and rects, and how long each script is. With an id from " & \
         "the outline, and the stack it is in (ids repeat from stack to stack): that card's or control's properties and script, and a card's " & \
         "controls. With only a stack: that stack's properties, cards and script. The user is asked to allow it the first time; when they do " & \
         "not, go on without it." into tTools[3]["description"]
   put "{`type`:`object`,`properties`:{`stack`:{`type`:`string`,`description`:`The name of the stack or substack, as the outline gives it`}," & \
         "`id`:{`type`:`integer`,`description`:`The id of a card or control, as the outline gives it`}}}" into tTools[3]["schema"]
   put "last_error" into tTools[4]["name"]
   put "Gives the last error the IDE showed the user while the assistant was on: the engine's messages, the object and handler it was in, " & \
         "and the lines of the script around it. Use it when the user asks about an error they hit." into tTools[4]["description"]
   put "{`type`:`object`,`properties`:{}}" into tTools[4]["schema"]
   put "debug_state" into tTools[5]["name"]
   put "Reads where a script of the user's is paused in the debugger (at a breakpoint, or at an error with Script Debug Mode on): the line " & \
         "and handler, the handlers that led there, their variables with their values, and the script around the line. Use it when the user " & \
         "asks about a script that is paused. It only reads: stepping and going on are the user's, in the Script Editor. When nothing is " & \
         "paused it says how the user can pause a script. The user is asked to allow it, as for read_stack." into tTools[5]["description"]
   put "{`type`:`object`,`properties`:{}}" into tTools[5]["schema"]
   put "make_changes" into tTools[6]["name"]
   put "Changes the user's stack, as a batch the user sees and applies or not in the assistant's window: creates controls, cards or a new " & \
         "stack; sets properties, custom properties and scripts; deletes controls or cards. Use it to build or correct what the user asks " & \
         "for, rather than telling them how or giving them code to paste. The batch is checked first, and a mistake (a property the engine " & \
         "does not have, a value it refuses, a script that does not compile) comes back to you with nothing changed, to correct and send " & \
         "again. A batch is applied whole or not at all, with messages locked (none of the user's handlers runs), and the user can undo it. " & \
         "The result gives the ids of what was created. Read the stack first (read_stack) to know its cards, ids and scripts. Each change " & \
         "has an action: create (kind: button, default button, checkbox, radio button, option menu, pulldown menu, popup menu, combo box, " & \
         "tab panel, field, text area, label, list field, table field, rectangle, round rectangle, oval, line, polygon, regular polygon, " & \
         "curve, scrollbar, slider, progress bar, image, player, group, widget (give its widget_kind), card or stack; with name, rect, " & \
         "properties, custom_properties, script, and ref, a word the later changes of the batch can use for it as object, card or group); " & \
         "set (object, and properties, custom_properties or script); or delete (object: a control or a card). A new stack is the first " & \
         "change of its batch, and the rest of the batch is in it; a new card goes after the current card. A script replaces the object's " & \
         "whole script and is made of handlers. Properties are the engine's, by name; a list of numbers is one value ([10, 20] is 10,20)." \
         into tTools[6]["description"]
   put "{`type`:`object`,`properties`:{" & \
         "`stack`:{`type`:`string`,`description`:`The stack or substack to change, by name; empty for the one the user is working on`}," & \
         "`changes`:{`type`:`array`,`description`:`The changes, made in order`,`items`:{`type`:`object`,`properties`:{" & \
         "`action`:{`type`:`string`,`enum`:[`create`,`set`,`delete`]}," & \
         "`kind`:{`type`:`string`,`description`:`create: what to create`}," & \
         "`name`:{`type`:`string`,`description`:`create: its name`}," & \
         "`ref`:{`type`:`string`,`description`:`create: a word the later changes of this batch name it by`}," & \
         "`card`:{`description`:`create: the card to put it on (an id, a ref or a card's name); the current card when none`}," & \
         "`group`:{`description`:`create: the group to put it in (an id or a ref)`}," & \
         "`rect`:{`type`:`array`,`items`:{`type`:`integer`},`description`:`create: left, top, right, bottom`}," & \
         "`widget_kind`:{`type`:`string`,`description`:`create, a widget: its kind, such as com.livecode.widget.svgpath`}," & \
         "`object`:{`description`:`set and delete: an id, a ref, or the word stack for the stack itself`}," & \
         "`properties`:{`type`:`object`,`description`:`Properties of the engine's, by name`}," & \
         "`custom_properties`:{`type`:`object`,`description`:`Custom properties, by name`}," & \
         "`script`:{`type`:`string`,`description`:`The object's whole new script: handlers`}}," & \
         "`required`:[`action`]}}},`required`:[`changes`]}" into tTools[6]["schema"]
   put "run_code" into tTools[7]["name"]
   put "Runs xTalk Script statements and gives back what they put into the Message Box (put with no container), what they returned, " & \
         "and any error with its line. Use it to try code before you give it to the user or put it in their stack, and to see what a stack " & \
         "does, rather than asking the user to run it in the Message Box. Where: sandbox (the default), a hidden stack made for the run and " & \
         "deleted after it, where the code can call the handlers you give; or stack, the user's stack, as the Message Box runs code there " & \
         "(with the stack's own handlers, me being the card or control given by target, the current card when none), after a checkpoint " & \
         "the user can go back to (on the stack, return gives nothing back: put the value instead). The user is asked first, and always " & \
         "when the code reaches files, the network or other programs. Do not use answer or ask: the run would wait for the user. A run " & \
         "that never ends is stopped only by the user (Control-period)." into tTools[7]["description"]
   put "{`type`:`object`,`properties`:{" & \
         "`code`:{`type`:`string`,`description`:`Statements, as typed into the Message Box`}," & \
         "`where`:{`type`:`string`,`enum`:[`sandbox`,`stack`]}," & \
         "`handlers`:{`type`:`string`,`description`:`sandbox: whole handlers the code can call`}," & \
         "`stack`:{`type`:`string`,`description`:`stack: the stack or substack, by name; empty for the one the user is working on`}," & \
         "`target`:{`type`:`integer`,`description`:`stack: the id of the card or control that is me`}}," & \
         "`required`:[`code`]}" into tTools[7]["schema"]
   put "look_at_card" into tTools[8]["name"]
   put "Takes a picture of a card of the user's stack as it looks now, to see what you built or what the user asks about: where " & \
         "the controls are, whether they overlap or are cut off, whether their text fits, how it all looks. read_stack gives the names, " & \
         "ids and properties; this shows the card. The user is asked to allow it the first time, as for read_stack." into tTools[8]["description"]
   put "{`type`:`object`,`properties`:{`stack`:{`type`:`string`,`description`:`The stack or substack, by name; empty for the one the user is working on`}," & \
         "`card`:{`type`:`integer`,`description`:`The id of the card, as the outline gives it; the card the stack shows when none`}}}" \
         into tTools[8]["schema"]
   put "save_stack" into tTools[9]["name"]
   put "Saves a stack of the user's to its file, with its substacks, as File > Save does. A stack that has never been saved (a new " & \
         "one you made) is saved where the user chooses, in a file dialog. The user is asked first, every time. Save when the user " & \
         "asks you to, or offer to when you have built a new stack for them. Saving cannot be undone from the assistant: Undo still " & \
         "takes back what you changed in the open stack, but the file keeps what was saved until it is saved again." into tTools[9]["description"]
   put "{`type`:`object`,`properties`:{`stack`:{`type`:`string`,`description`:`The stack to save, by name; empty for the one the user is working on`}}}" \
         into tTools[9]["schema"]
   repeat with tIndex = 1 to the number of elements of tTools
      replace "`" with quote in tTools[tIndex]["schema"]
   end repeat
   return tTools
end xtaTools

-- The tools to send for this question: none with the short guide (for
-- small local models) or with the tools turned off, or for a model whose
-- server refused them; and those that change or run something only while
-- the Settings let the model do that
private function xtaToolsToSend pProvider
   local tEmpty, tTools, tKept, tIndex, tCount, tBuild, tPictures
   if not xtaToolsOn() or sNoTools[pProvider & comma & xtaModel(pProvider)] is true then
      return tEmpty
   end if
   put xtaTools() into tTools
   put xtaBuildOn() into tBuild
   put xtaPicturesOn(pProvider) into tPictures
   put 0 into tCount
   repeat with tIndex = 1 to the number of elements of tTools
      if not tBuild and tTools[tIndex]["name"] is among the items of kBuildTools then
         next repeat
      end if
      if not tPictures and tTools[tIndex]["name"] is "look_at_card" then
         next repeat
      end if
      add 1 to tCount
      put tTools[tIndex] into tKept[tCount]
   end repeat
   return tKept
end xtaToolsToSend

-- Whether the model can be sent a picture of a card (look_at_card):
-- unless the user turned it off in the Settings, with Anthropic's API
-- (whose models all see pictures, as do the proxies that speak it) and
-- OpenAI's own; not with a server of the user's own on OpenAI's API,
-- whose model may take no pictures and refuse the request
private function xtaPicturesOn pProvider
   if revIDEGetPreference(kPrefPictures) is false then
      return false
   end if
   if pProvider is "anthropic" then
      return true
   end if
   return xtaBaseUrl(pProvider) is empty
end xtaPicturesOn

-- Whether the model may ask for tools: not with the short guide, nor when
-- the user turned them off in the Settings
private function xtaToolsOn
   return revIDEGetPreference(kPrefShortGuide) is not true and revIDEGetPreference(kPrefTools) is not false
end xtaToolsOn

-- Whether the model may also change stacks and run code (it asks first):
-- with the tools, unless the user turned it off in the Settings
private function xtaBuildOn
   return xtaToolsOn() and revIDEGetPreference(kPrefBuild) is not false
end xtaBuildOn

-- True when an answer that is not one says the server cannot take tools:
-- a local server whose model has none (Ollama), or that was started
-- without them (vLLM, llama.cpp). Only for a server of the user's own: the
-- providers' own APIs take tools, and an error of theirs that names one is
-- a mistake to show.
private function xtaToolsRefused pProvider, pReply
   if xtaBaseUrl(pProvider) is empty then
      return false
   end if
   if pReply["status"] is not among the items of "400,404,422,500,501" then
      return false
   end if
   return pReply["error"] contains "tool"
end xtaToolsRefused

-- Carries out one call the model asked for (pCall, as xtaParseReply gives
-- it). pDeclared are the names the user's open script declares, for the
-- compile check. Returns "text" (for the model), "error" (true when the
-- tool could not do it) and "summary" (one line for the window).
private function xtaRunTool pCall, pDeclared, pProvider
   local tInput, tError, tResult
   try
      put xtaJsonParse(pCall["input"]) into tInput
   catch tError
      put empty into tInput
   end try
   switch pCall["name"]
      case "lookup_dictionary"
         return xtaToolDictionary(xtaJsonText(xtaJsonMember(tInput, "term")))
      case "check_code"
         return xtaToolCheck(xtaJsonText(xtaJsonMember(tInput, "code")), pDeclared)
      case "read_stack"
         return xtaToolReadStack(xtaJsonText(xtaJsonMember(tInput, "stack")), xtaJsonText(xtaJsonMember(tInput, "id")), pProvider)
      case "last_error"
         return xtaToolLastError()
      case "debug_state"
         return xtaToolDebugState(pProvider)
      case "look_at_card"
         -- Turned off in the Settings since the model was told of it: the
         -- Settings can be changed while the model answers, and a picture
         -- is taken only while they let it be sent
         if not xtaPicturesOn(pProvider) then
            put "The assistant's Settings do not let it send you pictures of the user's cards. Go on without one: read_stack says what is on a card." \
                  into tResult["text"]
            put true into tResult["error"]
            put "Did not use look_at_card: the Settings do not let it send pictures of your cards" into tResult["summary"]
            return tResult
         end if
         return xtaToolLookAtCard(xtaJsonText(xtaJsonMember(tInput, "stack")), xtaJsonText(xtaJsonMember(tInput, "card")), pProvider)
      case "make_changes"
      case "run_code"
      case "save_stack"
         -- Turned off in the Settings since the model was told of them
         if not xtaBuildOn() then
            put "The user has not let the assistant change stacks or run code (in its Settings). Tell them what to do instead, step by step." \
                  into tResult["text"]
            put true into tResult["error"]
            put "Did not use" && pCall["name"] & ": changing stacks and running code are turned off in the Settings" into tResult["summary"]
            return tResult
         end if
         if pCall["name"] is "make_changes" then
            return xtaToolMakeChanges(tInput)
         end if
         if pCall["name"] is "save_stack" then
            return xtaToolSaveStack(xtaJsonText(xtaJsonMember(tInput, "stack")))
         end if
         return xtaToolRunCode(tInput)
   end switch
   put "There is no tool named" && quote & pCall["name"] & quote & "." into tResult["text"]
   put true into tResult["error"]
   put "Asked for a tool there is not:" && pCall["name"] into tResult["summary"]
   return tResult
end xtaRunTool

private function xtaToolDictionary pTerm
   local tTerm, tEntries, tError, tResult
   put word 1 to -1 of pTerm into tTerm
   if tTerm is empty then
      put "Give the term to look up." into tResult["text"]
      put true into tResult["error"]
      put "Looked up nothing in the Dictionary" into tResult["summary"]
      return tResult
   end if
   xtaPhase "tool", "Looking up" && quote & tTerm & quote && "in the Dictionary"
   try
      put ideDocsFetchLCSData(tTerm) into tEntries
      -- "the topStack" is the entry "topStack"
      if the number of elements of tEntries is 0 and word 1 of tTerm is "the" and the number of words of tTerm > 1 then
         put word 2 to -1 of tTerm into tTerm
         put ideDocsFetchLCSData(tTerm) into tEntries
      end if
   catch tError
      put "The Dictionary cannot be read here." into tResult["text"]
      put true into tResult["error"]
      put "Could not look up" && quote & tTerm & quote && "(the Dictionary cannot be read)" into tResult["summary"]
      return tResult
   end try
   put xtaDictionaryText(tTerm, tEntries) into tResult["text"]
   put false into tResult["error"]
   if the number of elements of tEntries is 0 then
      put "Looked up" && quote & tTerm & quote && "in the Dictionary: no entry" into tResult["summary"]
   else
      put "Looked up" && quote & tTerm & quote && "in the Dictionary" into tResult["summary"]
   end if
   return tResult
end xtaToolDictionary

private function xtaToolCheck pCode, pDeclared
   local tCheck, tResult, tLine
   if word 1 to -1 of pCode is empty then
      put "Give the code to check." into tResult["text"]
      put true into tResult["error"]
      put "Checked no code" into tResult["summary"]
      return tResult
   end if
   xtaPhase "tool", "Checking code"
   put xtaCheckScript(pCode, pDeclared) into tCheck
   put false into tResult["error"]
   if tCheck["ok"] is true then
      put "The code compiles on " & xtaHostName() & "'s engine. That is not the same as doing what was asked." into tResult["text"]
      put "Checked code: it compiles" into tResult["summary"]
   else
      put "The code does not compile on " & xtaHostName() & "'s engine:" into tResult["text"]
      repeat for each line tLine in tCheck["issues"]
         put return & "- " & tLine after tResult["text"]
      end repeat
      put "Checked code: it does not compile" into tResult["summary"]
   end if
   return tResult
end xtaToolCheck

-- The user's stack: an outline, or one stack, card or control (pStackName
-- and pId as the outline gives them). The first time for a stack, the user
-- is asked to allow it.
private function xtaToolReadStack pStackName, pId, pProvider
   local tWork, tMain, tName, tPassword, tError, tStack, tObject, tSub, tResult
   put xtaWorkStack() into tWork
   put tWork["stack"] into tMain
   if tMain is empty or there is not a tMain then
      put "The user has no stack of their own open." into tResult["text"]
      put true into tResult["error"]
      put "Found no stack to read" into tResult["summary"]
      return tResult
   end if
   put the short name of tMain into tName
   -- A password-protected stack's scripts are not sent (as with the open
   -- script, xtaScriptContext)
   put "protected" into tPassword
   try
      put the password of tMain into tPassword
   catch tError
   end try
   if tPassword is not empty then
      put "The stack" && quote & tName & quote && "is password-protected, so it is not read." into tResult["text"]
      put true into tResult["error"]
      put "Did not read the stack" && quote & tName & quote & ": it is password-protected" into tResult["summary"]
      return tResult
   end if
   if not xtaReadAllowed(tMain, pProvider) then
      put "The user did not allow reading the stack" && quote & tName & quote & ". Go on without it, and say what you would need to know." into tResult["text"]
      put true into tResult["error"]
      put "Not allowed to read the stack" && quote & tName & quote into tResult["summary"]
      return tResult
   end if

   -- The stack asked for: the main stack, or one of its substacks
   put tMain into tStack
   if word 1 to -1 of pStackName is not empty and word 1 to -1 of pStackName is not tName then
      put empty into tStack
      repeat for each line tSub in the substacks of tMain
         if tSub is word 1 to -1 of pStackName then
            put the long id of stack tSub of tMain into tStack
            exit repeat
         end if
      end repeat
      if tStack is empty then
         put "The stack" && quote & tName & quote && "has no substack" && quote & pStackName & quote & ". Its substacks:" && \
               the substacks of tMain into tResult["text"]
         replace return with ", " in tResult["text"]
         put true into tResult["error"]
         put "Looked for a substack" && quote & pStackName & quote && "that is not there" into tResult["summary"]
         return tResult
      end if
   end if
   xtaPhase "tool", "Reading the stack" && quote & tName & quote
   if pId is empty then
      if word 1 to -1 of pStackName is empty then
         put xtaStackOutline(tMain) into tResult["text"]
         put "Read the outline of the stack" && quote & tName & quote into tResult["summary"]
      else
         put xtaObjectText(tStack) into tResult["text"]
         put "Read the stack" && quote & the short name of tStack & quote into tResult["summary"]
      end if
      put false into tResult["error"]
      return tResult
   end if
   if pId is not an integer then
      put "An id is a whole number, as the outline gives it." into tResult["text"]
      put true into tResult["error"]
      put "Asked for an object by a wrong id" into tResult["summary"]
      return tResult
   end if
   if there is a card id pId of tStack then
      put the long id of card id pId of tStack into tObject
   else if there is a control id pId of tStack then
      put the long id of control id pId of tStack into tObject
   end if
   if tObject is empty then
      put "The stack" && quote & the short name of tStack & quote && "has no card or control with the id" && pId & "." into tResult["text"]
      put true into tResult["error"]
      put "Looked for the id" && pId && "that is not in the stack" && quote & the short name of tStack & quote into tResult["summary"]
      return tResult
   end if
   put xtaObjectText(tObject) into tResult["text"]
   put false into tResult["error"]
   put "Read" && the name of tObject && "of the stack" && quote & the short name of tStack & quote into tResult["summary"]
   return tResult
end xtaToolReadStack

private function xtaToolLastError
   local tError, tResult
   put xtaLastError() into tError
   if tError is empty then
      put "The IDE has shown the user no error since the assistant was turned on." into tResult["text"]
      put "Read the last error: there is none" into tResult["summary"]
   else
      put tError["text"] into tResult["text"]
      put "Read the last error, in" && tError["name"] into tResult["summary"]
   end if
   put false into tResult["error"]
   return tResult
end xtaToolLastError

-- debug_state: where a script of the user's is paused. It reads their
-- scripts and what the paused handlers hold, so it is asked about as
-- reading the stack is. With an error the IDE showed (Script Debug Mode
-- pauses at an error), the error goes with it.
private function xtaToolDebugState pProvider
   local tState, tError, tResult
   xtaPhase "tool", "Reading the debugger"
   put xtaDebugState() into tState
   if tState["paused"] is not true then
      put tState["text"] && "To pause a script, the user sets a breakpoint (a click left of a line in the Script Editor) and runs the script, " & \
            "or turns on Script Debug Mode (Development menu) and lets it stop at an error." into tResult["text"]
      put false into tResult["error"]
      put tState["summary"] into tResult["summary"]
      return tResult
   end if
   if not xtaReadAllowed(tState["stack"], pProvider) then
      put "The user did not allow reading the stack" && quote & the short name of tState["stack"] & quote & \
            ", where the script is paused. Go on without it, and say what you would need to know." into tResult["text"]
      put true into tResult["error"]
      put "Not allowed to read the stack" && quote & the short name of tState["stack"] & quote into tResult["summary"]
      return tResult
   end if
   put tState["text"] into tResult["text"]
   put xtaLastError() into tError
   if tError is not empty then
      put return & return & tError["text"] after tResult["text"]
   end if
   put false into tResult["error"]
   put tState["summary"] into tResult["summary"]
   return tResult
end xtaToolDebugState

-- look_at_card: a picture of a card as it looks now (pStackName and
-- pCardId as read_stack gives them; the card the stack shows when there
-- is no id), at kPictureSide pixels at most on its longer side, which the
-- core sends with the tool's result. It shows the stack as reading it
-- does, so the user allows it as for read_stack.
private function xtaToolLookAtCard pStackName, pCardId, pProvider
   local tWork, tTarget, tStack, tName, tCard, tLabel, tWidth, tHeight, tScale, tSize, tData, tError, tResult
   put xtaWorkStack() into tWork
   put xtaTargetStack(pStackName, tWork["stack"]) into tTarget
   if tTarget["problem"] is not empty then
      put tTarget["problem"] into tResult["text"]
      put true into tResult["error"]
      put "Found no card to look at" into tResult["summary"]
      return tResult
   end if
   put tTarget["stack"] into tStack
   put the short name of xtaMainStackOf(tStack) into tName
   if not xtaReadAllowed(xtaMainStackOf(tStack), pProvider) then
      put "The user did not allow reading the stack" && quote & tName & quote & ". Go on without it, and say what you would need to know." into tResult["text"]
      put true into tResult["error"]
      put "Not allowed to look at the stack" && quote & tName & quote into tResult["summary"]
      return tResult
   end if
   if pCardId is empty then
      put the long id of this card of tStack into tCard
   else if pCardId is an integer and there is a card id pCardId of tStack then
      put the long id of card id pCardId of tStack into tCard
   else
      put "The stack" && quote & the short name of tStack & quote && "has no card with the id" && pCardId & "." into tResult["text"]
      put true into tResult["error"]
      put "Looked for a card that is not there" into tResult["summary"]
      return tResult
   end if
   -- As read_stack names it: card "Intro" (id 1003), or card id 1002
   -- for one with no name
   put the name of tCard into tLabel
   if char 1 of word 2 of tLabel is quote then
      put "card" && quote & the short name of tCard & quote && "(id" && the short id of tCard & ")" into tLabel
   end if
   xtaPhase "tool", "Looking at" && tLabel && "of the stack" && quote & the short name of tStack & quote
   -- A card is the size of its stack's window
   put the width of tStack into tWidth
   put the height of tStack into tHeight
   put 1 into tScale
   if max(tWidth, tHeight) > kPictureSide then
      put kPictureSide / max(tWidth, tHeight) into tScale
   end if
   put max(1, round(tWidth * tScale)) & comma & max(1, round(tHeight * tScale)) into tSize
   try
      export snapshot from tCard at size tSize to tData as PNG
   catch tError
      put empty into tData
   end try
   if tData is empty then
      put "The picture of" && tLabel && "could not be taken." into tResult["text"]
      put true into tResult["error"]
      put "Could not take a picture of" && tLabel into tResult["summary"]
      return tResult
   end if
   put base64Encode(tData) into tResult["image"]
   replace return with empty in tResult["image"]
   put "image/png" into tResult["imageType"]
   put "A picture of" && tLabel && "of the stack" && quote & the short name of tStack & quote & ", as it looks now:" && \
         tWidth && "by" && tHeight && "pixels" into tResult["text"]
   if tScale < 1 then
      put ", shown at" && item 1 of tSize && "by" && item 2 of tSize after tResult["text"]
   end if
   put "." after tResult["text"]
   put false into tResult["error"]
   put "Looked at" && tLabel && "of the stack" && quote & the short name of tStack & quote into tResult["summary"]
   return tResult
end xtaToolLookAtCard

-- save_stack: the stack (its main stack, with its substacks) is saved as
-- File > Save saves it, by the IDE's own handler, which asks where for a
-- stack never saved; after the user says yes in the window's bar, every
-- time. Saving cannot be undone from the assistant, and the bar says so.
private function xtaToolSaveStack pStackName
   local tWork, tTarget, tMain, tName, tFile, tTitle, tDetail, tAnswer, tDone, tError, tResult
   put xtaWorkStack() into tWork
   put xtaTargetStack(pStackName, tWork["stack"]) into tTarget
   if tTarget["problem"] is not empty then
      put "Nothing was saved:" && tTarget["problem"] into tResult["text"]
      put true into tResult["error"]
      put "Found no stack to save" into tResult["summary"]
      return tResult
   end if
   put xtaMainStackOf(tTarget["stack"]) into tMain
   put the short name of tMain into tName
   put the effective filename of tMain into tFile
   if tFile is empty then
      put "Save the new stack" && quote & tName & quote & "?" into tTitle
      put "It has never been saved: you choose where, in the dialog that comes next, as File > Save does." into tDetail
   else
      put "Save the stack" && quote & tName & quote & "?" into tTitle
      put "It is saved to its file, with its substacks, as File > Save does:" & return & tFile into tDetail
   end if
   put return & return & "Saving cannot be undone from the assistant." after tDetail
   put xtaAskUser("save", tTitle, tDetail, "Save", empty, "Don't Save") into tAnswer
   if tAnswer is "stop" then
      put "Nothing was saved: the user pressed Stop." into tResult["text"]
      put true into tResult["error"]
      put "Did not save the stack: you pressed Stop" into tResult["summary"]
      return tResult
   end if
   if tAnswer is not "yes" then
      put "The user chose not to save the stack" && quote & tName & quote & ", and nothing was saved. Do not ask again unless they ask you to." \
            into tResult["text"]
      put true into tResult["error"]
      put "You chose not to save the stack" && quote & tName & quote into tResult["summary"]
      return tResult
   end if
   xtaPhase "tool", "Saving the stack" && quote & tName & quote
   try
      revIDEActionSaveStack tMain
      put the result into tDone
   catch tError
      put xtaPlainError(tError) into tDone
   end try
   put the effective filename of tMain into tFile
   if tDone is "Cancelled" then
      put "The user cancelled saving the stack" && quote & tName & quote & ", and nothing was saved." into tResult["text"]
      put true into tResult["error"]
      put "You cancelled saving the stack" && quote & tName & quote into tResult["summary"]
      return tResult
   end if
   if tDone is not empty or tFile is empty or there is not a file tFile then
      put "The stack" && quote & tName & quote && "was not saved" into tResult["text"]
      if tDone is not empty then
         put ":" && line 1 of tDone after tResult["text"]
      end if
      put "." after tResult["text"]
      put true into tResult["error"]
      put "Could not save the stack" && quote & tName & quote into tResult["summary"]
      return tResult
   end if
   put "Saved the stack" && quote & tName & quote && "to" && tFile & "." into tResult["text"]
   put false into tResult["error"]
   put "Saved the stack" && quote & tName & quote into tResult["summary"]
   return tResult
end xtaToolSaveStack

-- make_changes: the batch is checked, shown in the window's bar, and
-- applied only when the user presses Apply. A batch with mistakes goes
-- back to the model without asking the user.
private function xtaToolMakeChanges pInput
   local tWork, tPlan, tWhat, tTitle, tAnswer, tApplied, tResult
   put xtaWorkStack() into tWork
   xtaPhase "tool", "Checking the changes the model asks for"
   put xtaBuildPlan(pInput, tWork["stack"]) into tPlan
   if tPlan["ok"] is not true then
      put "Nothing was changed: the batch has mistakes. Correct them, then send the whole batch again." & return & tPlan["problems"] \
            into tResult["text"]
      put true into tResult["error"]
      put "Proposed changes that need correcting first" into tResult["summary"]
      return tResult
   end if
   if tPlan["newStack"] is true then
      put "a new stack" && quote & tPlan["name"] & quote into tWhat
   else
      put "the stack" && quote & tPlan["name"] & quote into tWhat
   end if
   if tPlan["count"] is 1 then
      put "Apply this change to" && tWhat & "?" into tTitle
   else
      put "Apply these" && tPlan["count"] && "changes to" && tWhat & "?" into tTitle
   end if
   put xtaAskUser("changes", tTitle, tPlan["lines"] & return & return & "Undo, in the conversation, takes them back.", "Apply", empty, "Don't Apply") \
         into tAnswer
   if tAnswer is "stop" then
      put "Nothing was changed: the user pressed Stop." into tResult["text"]
      put true into tResult["error"]
      put "Did not apply the changes: you pressed Stop" into tResult["summary"]
      return tResult
   end if
   if tAnswer is not "yes" then
      put "The user chose not to apply these changes, and nothing was changed. Ask them what they would like instead; do not send the same batch again." \
            into tResult["text"]
      put true into tResult["error"]
      put "You chose not to apply the changes to" && tWhat into tResult["summary"]
      return tResult
   end if
   xtaPhase "tool", "Applying the changes"
   put xtaBuildApply(tPlan) into tApplied
   if tApplied["ok"] is not true then
      put tApplied["error"] into tResult["text"]
      put true into tResult["error"]
      put "Could not apply the changes:" && line 1 of tApplied["error"] into tResult["summary"]
      return tResult
   end if
   put tApplied["text"] into tResult["text"]
   -- A new stack opens where the assistant's window may cover it
   if tPlan["newStack"] is true and there is a stack tPlan["name"] then
      put xtaPlaceBeside(the long id of stack tPlan["name"]) into tWhat
      if tWhat is not empty then
         put return & "Its window was put beside the assistant's, at" && tWhat & ", so as not to be under it." after tResult["text"]
      else
         xtaKeepOnScreen the long id of stack tPlan["name"], false
         put the result into tWhat
         if tWhat is not empty then
            put return & "Its window was moved to" && tWhat & ", so that all of it, its title bar too, is on the screen." after tResult["text"]
         end if
      end if
   end if
   put false into tResult["error"]
   put tApplied["summary"] into tResult["summary"]
   put tApplied["entry"] into tResult["entry"]
   put tPlan["lines"] into tResult["lines"]
   xtaRefreshMoreMenu
   return tResult
end xtaToolMakeChanges

-- Moves pStack (a long id), a stack the assistant has just made, beside
-- the assistant's window when the two overlap: to its left, else to its
-- right, where the screen has room, its top level with the window's, the
-- whole of it on the screen (xtaKeepOnScreen). Returns its new rect, or
-- empty when it was left where it was.
private function xtaPlaceBeside pStack
   local tWindow, tRect, tScreen, tLine, tWidth, tHeight, tLeft, tTop
   if there is not a stack kWindow or there is not a pStack then
      return empty
   end if
   put the rect of stack kWindow into tWindow
   put the rect of pStack into tRect
   if item 3 of tRect <= item 1 of tWindow or item 1 of tRect >= item 3 of tWindow \
         or item 4 of tRect <= item 2 of tWindow or item 2 of tRect >= item 4 of tWindow then
      return empty
   end if
   -- The screen the window is on, less the taskbar, the Dock and the menu
   -- bar
   put the working screenRect into tScreen
   repeat for each line tLine in the working screenRects
      if the loc of stack kWindow is within tLine then
         put tLine into tScreen
         exit repeat
      end if
   end repeat
   put the width of pStack into tWidth
   put the height of pStack into tHeight
   -- 24 pixels apart, for the windows' frames
   if item 1 of tWindow - 24 - tWidth >= item 1 of tScreen then
      put item 1 of tWindow - 24 - tWidth into tLeft
   else if item 3 of tWindow + 24 + tWidth <= item 3 of tScreen then
      put item 3 of tWindow + 24 into tLeft
   else
      return empty
   end if
   put max(item 2 of tScreen, min(item 2 of tWindow, item 4 of tScreen - tHeight)) into tTop
   set the rect of pStack to tLeft, tTop, tLeft + tWidth, tTop + tHeight
   -- Its title bar too
   xtaKeepOnScreen pStack, false
   return the rect of pStack
end xtaPlaceBeside

-- run_code: the code is checked and shown in the window's bar, and runs
-- when the user presses Run, or at once where they allowed runs for the
-- session (the sandbox, or a stack); code that reaches what cannot be
-- undone (files, the network, other programs...) is asked about every
-- time. A run on a stack is saved as a checkpoint first, which Undo goes
-- back to.
private function xtaToolRunCode pInput
   local tWork, tRun, tPlace, tTitle, tDetail, tSession, tAnswer, tRan, tResult, tRisks
   put xtaWorkStack() into tWork
   xtaPhase "tool", "Checking the code the model asks to run"
   put xtaRunPlan(pInput, tWork["stack"]) into tRun
   if tRun["ok"] is not true then
      put "Nothing ran:" && tRun["problems"] into tResult["text"]
      put true into tResult["error"]
      put "Proposed code to run that needs correcting first" into tResult["summary"]
      return tResult
   end if
   if tRun["where"] is "sandbox" then
      put "sandbox" into tPlace
   else
      put xtaMainStackOf(tRun["stack"]) into tPlace
   end if
   if sRunAllowed[tPlace] is not true or tRun["risks"] is not empty then
      if tRun["where"] is "sandbox" then
         put "Run this code in a sandbox?" into tTitle
         put "It runs in a hidden stack made for the run, and deleted after it." into tDetail
         put "Allow in the Sandbox" into tSession
      else
         put "Run this code on the stack" && quote & the short name of tPlace & quote & "?" into tTitle
         put tRun["label"] & ". A copy of the stack is saved first, and Undo, in the conversation, goes back to it." into tDetail
         put "Allow on This Stack" into tSession
      end if
      if tRun["risks"] is not empty then
         put tRun["risks"] into tRisks
         replace return with ", " in tRisks
         put "Careful: it uses" && tRisks & ", and what it does there cannot be undone." & return & tDetail into tDetail
         -- Asked about every time
         put empty into tSession
      end if
      put return & return & tRun["code"] after tDetail
      if tRun["handlers"] is not empty then
         put return & return & "-- With these handlers:" & return & tRun["handlers"] after tDetail
      end if
      put xtaAskUser("run", tTitle, tDetail, "Run", tSession, "Don't Run") into tAnswer
      if tAnswer is "stop" then
         put "Nothing ran: the user pressed Stop." into tResult["text"]
         put true into tResult["error"]
         put "Did not run the code: you pressed Stop" into tResult["summary"]
         return tResult
      end if
      if tAnswer is not "yes" and tAnswer is not "session" then
         put "The user chose not to run this code, and nothing ran. Ask them what they would like instead; do not send the same code again." \
               into tResult["text"]
         put true into tResult["error"]
         put "You chose not to run the code" into tResult["summary"]
         return tResult
      end if
      if tAnswer is "session" then
         put true into sRunAllowed[tPlace]
      end if
   end if
   xtaPhase "tool", "Running the code (" & xtaInterruptKeys() && "stops it)"
   put xtaRunCode(tRun) into tRan
   put tRan["text"] into tResult["text"]
   put (tRan["ok"] is not true) into tResult["error"]
   put tRan["summary"] into tResult["summary"]
   put tRan["entry"] into tResult["entry"]
   -- What it put into the Message Box and returned, for the window
   put tRan["output"] into tResult["output"]
   put tRan["value"] into tResult["value"]
   if tRan["entry"] is not empty then
      xtaRefreshMoreMenu
   end if
   return tResult
end xtaToolRunCode

-- The keys that stop a running script: the engine's interrupt
private function xtaInterruptKeys
   if the platform is "MacOS" then
      return "Command-period"
   end if
   return "Control-period"
end xtaInterruptKeys

-- The long id of the main stack of pStack (a long id)
private function xtaMainStackOf pStack
   if the owner of pStack is empty then
      return the long id of pStack
   end if
   return the long id of the owner of pStack
end xtaMainStackOf

-- True when the user lets the model read the stack pMain (the long id of
-- a main stack): its scripts then go to the provider. Asked in the
-- window's bar the first time, then allowed until the assistant is turned
-- off; Don't Allow holds until the next question.
private function xtaReadAllowed pMain, pProvider
   local tName, tAnswer
   if sReadAllowed[pMain] is true then
      return true
   end if
   if sReadRefused[pMain] is true then
      return false
   end if
   put the short name of pMain into tName
   put xtaAskUser("read", "Let the assistant read your stack" && quote & tName & quote & "?", \
         "It reads the stack's cards and controls, their properties and their scripts, what a paused script holds, and pictures of its cards. What it reads goes to" && \
         xtaProviderName(pProvider) && "with this question and the ones after it, until you turn the assistant off.", "Allow", empty, "Don't Allow") \
         into tAnswer
   if tAnswer is "yes" then
      put true into sReadAllowed[pMain]
      return true
   end if
   if tAnswer is "no" then
      put true into sReadRefused[pMain]
   end if
   return false
end xtaReadAllowed

--------------------------------------------------------------------------------
-- The bar that asks the user
--
-- What the assistant asks while it answers (apply these changes, run this
-- code, read this stack) is asked in a bar in its window, above the
-- prompt, rather than in a dialog: the user can read the conversation
-- and scroll the details before answering, and Stop answers it too.

-- Shows the bar and waits for the answer, which a click on one of its
-- buttons gives (xtaAnswerAsk): "yes", "session" (yes, and do not ask
-- again this session) or "no"; or "stop" when the user pressed Stop,
-- closed the window or turned the assistant off. pKind is what is asked
-- ("changes", "run" or "read"); pSession is the label of the button that
-- allows it for the session, empty for none.
private function xtaAskUser pKind, pTitle, pDetail, pYes, pSession, pNo
   local tShutDowns, tAnswer
   if there is not a stack kWindow or sStopAsked is true then
      return "stop"
   end if
   put pKind into sAsk["kind"]
   put empty into sAsk["answer"]
   xtaShowAsk pTitle, pDetail, pYes, pSession, pNo
   put sShutDowns into tShutDowns
   repeat while sAsk["answer"] is empty
      if sShutDowns is not tShutDowns or there is not a stack kWindow or sStopAsked is true then
         put "stop" into sAsk["answer"]
         exit repeat
      end if
      wait 50 milliseconds with messages
   end repeat
   put sAsk["answer"] into tAnswer
   put empty into sAsk
   if sShutDowns is tShutDowns then
      xtaHideAsk
      if tAnswer is not "stop" then
         xtaPhase "tool", "Going on with your answer"
      end if
      xtaWorkStatus
   end if
   return tAnswer
end xtaAskUser

private command xtaShowAsk pTitle, pDetail, pYes, pSession, pNo
   lock screen
   lock messages
   set the text of field "AskTitle" of stack kWindow to pTitle
   set the text of field "AskDetail" of stack kWindow to pDetail
   set the label of button "AskYes" of stack kWindow to pYes
   set the label of button "AskSession" of stack kWindow to pSession
   set the label of button "AskNo" of stack kWindow to pNo
   set the visible of graphic "AskPanel" of stack kWindow to true
   set the visible of field "AskTitle" of stack kWindow to true
   set the visible of field "AskDetail" of stack kWindow to true
   set the visible of button "AskYes" of stack kWindow to true
   set the visible of button "AskSession" of stack kWindow to (pSession is not empty)
   set the visible of button "AskNo" of stack kWindow to true
   unlock messages
   dispatch "xtawRelayout" to stack kWindow
   lock messages
   set the vScroll of field "AskDetail" of stack kWindow to 0
   unlock messages
   xtaPhase "ask", "Waiting for your answer, below"
   xtaStatus "Waiting for your answer, below the conversation.", "warn"
   unlock screen
end xtaShowAsk

private command xtaHideAsk
   local tName
   if there is not a stack kWindow then
      exit xtaHideAsk
   end if
   lock screen
   lock messages
   set the visible of graphic "AskPanel" of stack kWindow to false
   set the visible of field "AskTitle" of stack kWindow to false
   set the visible of field "AskDetail" of stack kWindow to false
   repeat for each item tName in "AskYes,AskSession,AskNo"
      set the visible of button tName of stack kWindow to false
   end repeat
   unlock messages
   dispatch "xtawRelayout" to stack kWindow
   xtaPaintPill
   unlock screen
end xtaHideAsk

-- A button of the bar: "yes", "session" or "no"
on xtaAnswerAsk pAnswer
   if sAsk["kind"] is empty or sAsk["answer"] is not empty then
      exit xtaAnswerAsk
   end if
   if pAnswer is among the items of "yes,session,no" then
      put pAnswer into sAsk["answer"]
   end if
end xtaAnswerAsk

--------------------------------------------------------------------------------
-- Undo
--
-- What the assistant changed, and the runs on a stack, are a journal (the
-- library's) until the assistant is turned off. Undo, after an entry in
-- the conversation, takes it back, and what was applied to the same stack
-- after it, newest first; More > Undo All Changes... takes back all of it.
-- The model is told with the next question.

-- A link of the conversation: Undo after what the tools did; Remember
-- and Dismiss under a note; Copy and Insert over a block of code ("copy"
-- or "insert", the turn and the block); a link of an answer ("url" and
-- the address, which opens in the browser); and in the welcome, a
-- question to begin with ("example" and its number), and the Settings
on xtaConversationLink pLink
   switch item 1 of pLink
      case "undo"
         xtaUndoEntry item 2 of pLink
         break
      case "remember"
      case "dismiss"
         xtaNoteClicked pLink
         break
      case "copy"
      case "insert"
         xtaCodeLink item 1 of pLink, item 2 of pLink, item 3 of pLink
         break
      case "url"
         if item 2 of pLink begins with "https://" or item 2 of pLink begins with "http://" then
            launch url (item 2 to -1 of pLink)
         end if
         break
      case "example"
         if sBusy is not true and there is a stack kWindow and xtaExampleText(item 2 of pLink) is not empty then
            put xtaExampleText(item 2 of pLink) into field "Prompt" of stack kWindow
            xtaPromptChanged
            focus on field "Prompt" of stack kWindow
            select after text of field "Prompt" of stack kWindow
         end if
         break
      case "settings"
         xtaSettingsDialog "Key"
         break
   end switch
end xtaConversationLink

-- Copy or Insert (pAction) over block pBlock of the answer of turn pTurn,
-- numbered as the conversation numbers them (xtaDocAnswer)
private command xtaCodeLink pAction, pTurn, pBlock
   local tBlocks, tCode
   if pTurn is not an integer or pBlock is not an integer or sTurns[pTurn]["role"] is not "assistant" then
      exit xtaCodeLink
   end if
   put xtaCodeBlocks(xtaWithoutMemoryBlocks(sTurns[pTurn]["text"])) into tBlocks
   if pBlock < 1 or pBlock > the number of elements of tBlocks then
      exit xtaCodeLink
   end if
   put tBlocks[pBlock]["code"] into tCode
   if pAction is "copy" then
      set the clipboardData["text"] to tCode
      xtaStatus "Copied the code to the clipboard.", "ok"
      exit xtaCodeLink
   end if
   -- Only xTalk goes into a script, as with Insert Code
   if not xtaIsXTalkLang(tBlocks[pBlock]["lang"]) then
      exit xtaCodeLink
   end if
   xtaInsertText tCode
end xtaCodeLink

-- True while the library that changes and runs is loaded (from when the
-- window is first opened until the assistant is turned off)
private function xtaBuildLoaded
   if there is not a stack kBuild then
      return false
   end if
   return the long id of stack kBuild is among the lines of xtaStacksInUse()
end xtaBuildLoaded

-- How many sets of changes, and runs on a stack, can be undone
private function xtaAppliedCount
   local tEntries, tIndex, tCount
   put 0 into tCount
   if not xtaBuildLoaded() then
      return tCount
   end if
   put xtaBuildEntries() into tEntries
   repeat with tIndex = 1 to the number of elements of tEntries
      if tEntries[tIndex]["state"] is "applied" then
         add 1 to tCount
      end if
   end repeat
   return tCount
end xtaAppliedCount

private command xtaRefreshMoreMenu
   if there is a stack kWindow then
      lock messages
      set the text of button "More" of stack kWindow to xtaMoreMenuText()
      unlock messages
   end if
end xtaRefreshMoreMenu

-- Undo, after an entry in the conversation. When the user changed some of
-- it since, they are asked first: it goes back as it was before the
-- assistant changed it, and what they changed goes too.
private command xtaUndoEntry pEntry
   local tResult
   if not xtaBuildLoaded() or pEntry is not an integer then
      exit xtaUndoEntry
   end if
   put xtaBuildUndo(pEntry, false) into tResult
   if tResult["changed"] is not empty then
      answer question "You have changed some of this since the assistant did it:" & return & tResult["changed"] & return & return & \
            "Undo puts it back as it was before, and what you changed goes too." with "Cancel" or "Undo Anyway" titled kTitle
      if it is not "Undo Anyway" then
         exit xtaUndoEntry
      end if
      put xtaBuildUndo(pEntry, true) into tResult
   end if
   xtaUndone tResult
end xtaUndoEntry

-- More > Undo All Changes...
private command xtaUndoAll
   local tCount, tResult
   put xtaAppliedCount() into tCount
   if tCount is 0 then
      xtaStatus "There is nothing to undo."
      exit xtaUndoAll
   end if
   if tCount is 1 then
      answer question "Undo what the assistant did to your stack? It goes back as it was before." with "Cancel" or "Undo All" titled kTitle
   else
      answer question "Undo all that the assistant did to your stacks:" && tCount && "sets of changes and runs, the newest first? They go back as they were before." \
            with "Cancel" or "Undo All" titled kTitle
   end if
   if it is not "Undo All" then
      exit xtaUndoAll
   end if
   put xtaBuildUndoAll(false) into tResult
   if tResult["changed"] is not empty then
      answer question "You have changed some of it since the assistant did it:" & return & tResult["changed"] & return & return & \
            "Undo puts it back as it was before, and what you changed goes too." with "Cancel" or "Undo Anyway" titled kTitle
      if it is not "Undo Anyway" then
         exit xtaUndoAll
      end if
      put xtaBuildUndoAll(true) into tResult
   end if
   xtaUndone tResult
end xtaUndoAll

-- After Undo: the window shows what is undone, and what was undone goes
-- to the model with the next question
private command xtaUndone pResult
   local tEntries, tIndex
   if pResult["undone"] is not empty then
      put xtaBuildEntries() into tEntries
      repeat for each line tIndex in pResult["undone"]
         put "- " & tEntries[tIndex]["summary"] & return after sUndone
      end repeat
   end if
   xtaShowConversation
   xtaRefreshMoreMenu
   if pResult["undone"] is empty then
      xtaStatus pResult["error"], "bad"
   else if pResult["error"] is not empty then
      xtaStatus "Undone, but not all of it.", "bad"
      answer warning "Some of it could not be undone:" & return & pResult["error"] titled kTitle
   else
      xtaStatus pResult["summary"] & ".", "ok"
   end if
end xtaUndone

-- The newest error the error hook noted that was in a script of the user's
-- (not one of the IDE's): an array with "text" (for the model: the engine's
-- messages, then the lines of the script around the error, when the script
-- can be read) and "name" (the object, for the user), or empty when there
-- is none
private function xtaLastError
   local tErrors, tIndex, tFound, tWhere, tObject, tStack, tName, tScript, tExcerpt, tPassword, tError, tResult
   if there is not a stack kErrorHook then
      return empty
   end if
   dispatch function "xtaErrorHookErrors" to stack kErrorHook
   put the result into tErrors
   put false into tFound
   repeat with tIndex = the number of elements of tErrors down to 1
      put xtaErrorWhere(tErrors[tIndex]["trace"]) into tWhere
      put tWhere["object"] into tObject
      if tObject is empty then
         put tErrors[tIndex]["target"] into tObject
      end if
      put empty into tStack
      try
         if tObject is not empty and there is a tObject then
            put xtaStackOfObject(the long id of tObject) into tStack
         end if
      catch tError
         put empty into tStack
      end try
      if tStack is not empty then
         if xtaIsIDEStack(tStack) then
            next repeat
         end if
      end if
      put true into tFound
      exit repeat
   end repeat
   if not tFound then
      return empty
   end if
   if tStack is empty then
      -- The object is gone: the error as it was reported
      put tObject into tName
   else
      put the name of tObject && "of stack" && quote & the short name of tStack & quote into tName
   end if
   put "The last error the IDE showed the user (" & the seconds - tErrors[tIndex]["seconds"] && "seconds ago), as the engine reported it:" & return & \
         xtaErrorText(tErrors[tIndex]["trace"]) into tResult["text"]
   if tStack is not empty and tWhere["line"] is not empty then
      put "protected" into tPassword
      try
         put the password of tStack into tPassword
         if tPassword is empty and the owner of tStack is not empty then
            put the password of the owner of tStack into tPassword
         end if
         if tPassword is empty then
            put the script of tObject into tScript
         end if
      catch tError
         put empty into tScript
      end try
      put xtaScriptExcerpt(tScript, tWhere["line"]) into tExcerpt
      if tExcerpt is not empty then
         put return & "The script of" && tName & ", around line" && tWhere["line"] & ":" & return & tExcerpt after tResult["text"]
      end if
   end if
   put tName into tResult["name"]
   return tResult
end xtaLastError

-- The stack an object is in, from its long id (which ends with the stack;
-- for a control of a substack, "... of stack "Sub" of stack "Main"")
private function xtaStackOfObject pObject
   local tAt
   if word 1 of pObject is "stack" then
      return pObject
   end if
   put offset(" of stack ", pObject) into tAt
   if tAt is 0 then
      return empty
   end if
   return char tAt + 4 to -1 of pObject
end xtaStackOfObject

--------------------------------------------------------------------------------
-- Asking

on xtaNewConversation
   if sBusy is true then
      exit xtaNewConversation
   end if
   put empty into sTurns
   put empty into sLastCode
   put empty into sUndone
   xtaRefreshWindow
end xtaNewConversation

-- More > Explain the Last Error: asks about the last error the IDE showed
-- the user, sent with the question (what the prompt holds, or else a
-- question of its own)
private command xtaExplainLastError
   local tError
   if sBusy is true or there is not a stack kWindow then
      exit xtaExplainLastError
   end if
   put xtaLastError() into tError
   if tError is empty then
      answer information "The IDE has shown no error in your scripts since the xTalk Assistant was turned on." titled kTitle
      exit xtaExplainLastError
   end if
   if word 1 to -1 of field "Prompt" of stack kWindow is empty then
      put "Explain the last error I hit, and how to fix it." into field "Prompt" of stack kWindow
   end if
   xtaSendPrompt tError["text"], tError["name"]
end xtaExplainLastError

-- More > Explain the Open Script: asks what the script open in the Script
-- Editor does (what the prompt holds, or else a question of its own),
-- sent with the script whether or not "Include the open script" is ticked
private command xtaExplainOpenScript
   local tContext
   if sBusy is true or there is not a stack kWindow then
      exit xtaExplainOpenScript
   end if
   put xtaScriptContext() into tContext
   if tContext["script"] is empty then
      answer information "Open a script in the Script Editor first. (The scripts of a password-protected stack are not sent.)" titled kTitle
      exit xtaExplainOpenScript
   end if
   if word 1 to -1 of field "Prompt" of stack kWindow is empty then
      put "Explain what this script does, handler by handler, and point out anything that looks wrong." into field "Prompt" of stack kWindow
   end if
   xtaSendPrompt empty, empty, true
end xtaExplainOpenScript

-- More > Copy the Conversation: all of it as text (Markdown), to paste
-- into a message or a note: who said what, the answers as the model wrote
-- them, and what the tools did
private command xtaCopyConversation
   local tText, tIndex, tTurn, tCall, tBody, tLast
   repeat with tIndex = 1 to the number of elements of sTurns
      put sTurns[tIndex] into tTurn
      -- What the tools did and the answers after them are one block, as
      -- in the window
      if tTurn["kind"] is "tools" then
         if tLast is not "assistant" then
            put "### xTalk Assistant" & return & return after tText
            put "assistant" into tLast
         end if
         repeat with tCall = 1 to the number of elements of tTurn["results"]
            put "- *" & tTurn["results"][tCall]["summary"] & "*" & return after tText
         end repeat
         put return after tText
         next repeat
      end if
      if tTurn["role"] is "assistant" then
         put xtaWithoutMemoryBlocks(tTurn["text"]) into tBody
         if word 1 to -1 of tBody is empty and tTurn["cut"] is empty then
            next repeat
         end if
         if tLast is not "assistant" then
            put "### xTalk Assistant" & return & return after tText
            put "assistant" into tLast
         end if
         if word 1 to -1 of tBody is not empty then
            put tBody & return & return after tText
         end if
         if tTurn["check"] is not empty then
            put "*" & tTurn["check"] & "*" & return & return after tText
         end if
         if tTurn["cut"] is not empty then
            put "*" & tTurn["cut"] & "*" & return & return after tText
         end if
         next repeat
      end if
      if tTurn["kind"] is "check" then
         put tTurn["text"] into tBody
         if tBody begins with "Compile check: " then
            delete char 1 to the number of chars of "Compile check: " of tBody
         end if
         put "### Compile check" & return & return & tBody & return & return after tText
         put "check" into tLast
         next repeat
      end if
      put "### You" & return & return & tTurn["text"] & return & return after tText
      put "you" into tLast
   end repeat
   if tText is empty then
      exit xtaCopyConversation
   end if
   set the clipboardData["text"] to word 1 to -1 of tText & return
   xtaStatus "Copied the conversation to the clipboard.", "ok"
end xtaCopyConversation

-- Send, or Stop while a question is being answered
on xtaSendOrStop
   if sBusy is true then
      put true into sStopAsked
      xtaUpdateButtons
      xtaPhase "stop", "Stopping after the answer that is on its way"
      xtaStatus "Stopping after the answer that is on its way..."
      exit xtaSendOrStop
   end if
   xtaSendPrompt
end xtaSendOrStop

-- Escape, in the window: Stop while a question is being answered. The
-- result is false when there is nothing to stop, and the window passes
-- the key on.
on xtaEscape
   if sBusy is not true then
      return false
   end if
   if sStopAsked is not true then
      xtaSendOrStop
   end if
   return true
end xtaEscape

-- Sends the question in the prompt, with the conversation so far, and shows
-- the answer. pAttach, when given, goes with the question (the last error,
-- for Explain the Last Error), and the window says so with pAttachName.
-- The model may ask for tools as it answers (xtaRunTool), up to
-- kMaxToolCalls for the question; their results go back to it and it goes
-- on. Every xTalk block of an answer is compiled; one that does not compile
-- goes back to the model with the errors, as a turn of the conversation the
-- user sees ("Compile check"), until the code compiles, the fix rounds are
-- used up, the model sends the same code again or none, or the user presses
-- Stop.
on xtaSendPrompt pAttach, pAttachName, pWithScript
   local tPrompt, tProvider, tCount, tContext, tReply, tStatus, tShutDowns
   local tWork, tSystem, tDeclared, tRound, tRounds, tBlocks, tCheck, tLastCode
   local tIn, tOut, tCached, tAnswered, tError, tTools, tCalls, tCall, tResults
   local tToolCalls, tRefusals, tRefusedNow, tSpent, tKind, tQuestion, tStats, tStopped
   local tSettings, tRoom, tMore, tAgain, tCutNote, tCallName, tRefused, tCrash
   if sBusy is true or there is not a stack kWindow then
      exit xtaSendPrompt
   end if
   put field "Prompt" of stack kWindow into tPrompt
   if word 1 to -1 of tPrompt is empty then
      exit xtaSendPrompt
   end if
   -- A model name typed into the combo box counts even if it was not
   -- confirmed
   xtaSetModel the label of button "Model" of stack kWindow
   put xtaProvider() into tProvider
   if not xtaEnsureKey(tProvider) then
      exit xtaSendPrompt
   end if
   put xtaProvider() into tProvider
   -- No model chosen yet: the provider's list names one (in 0.2.5-rc.3 Send
   -- only said to choose one first)
   if xtaModel(tProvider) is empty then
      if xtaLoadModels() is not empty then
         exit xtaSendPrompt
      end if
   end if

   put the number of elements of sTurns + 1 into tCount
   put tCount into tQuestion
   put "user" into sTurns[tCount]["role"]
   put tPrompt into sTurns[tCount]["text"]
   if pAttach is not empty then
      put pAttach into sTurns[tCount]["attach"]
      put pAttachName into sTurns[tCount]["attachName"]
   end if
   -- What the user undid since the last question: the model goes by what
   -- the tools told it, and the objects are gone
   if sUndone is not empty then
      put sUndone into sTurns[tCount]["undone"]
      put empty into sUndone
   end if
   if the hilite of button "Include" of stack kWindow or pWithScript is true then
      put xtaScriptContext() into tContext
      if tContext["script"] is not empty then
         put tContext["script"] into sTurns[tCount]["context"]
         put tContext["name"] into sTurns[tCount]["contextName"]
         put xtaDeclaredNames(tContext["script"]) into tDeclared
      end if
   end if
   -- The stack the question is about, for the notes about it
   put xtaWorkStack() into tWork
   put tWork["path"] into sTurns[tCount]["stackPath"]
   put tWork["name"] into sTurns[tCount]["stackName"]
   put xtaSystem(tWork) into tSystem
   put empty into field "Prompt" of stack kWindow
   xtaPromptChanged
   put true into sBusy
   put false into sStopAsked
   -- A stack the user would not let the model read is asked about again
   -- with the next question
   put empty into sReadRefused
   xtaWorkBegin
   xtaShowConversation
   xtaUpdateButtons

   put xtaFixRounds() into tRounds
   put xtaToolsToSend(tProvider) into tTools
   put 0 into tRound
   put 0 into tToolCalls
   put 0 into tRefusals
   put false into tSpent
   put 0 into tIn
   put 0 into tOut
   put 0 into tCached
   put false into tAnswered
   put sShutDowns into tShutDowns
   -- An error thrown on the way (by a tool, the conversation's display, a
   -- check) ends the question as one the server refused would: before, it
   -- left the window busy, Send showing Stop, until the assistant was
   -- turned off. What was answered so far stays.
   try
   repeat forever
      if tAgain is not empty then
         xtaPhase "wait", tAgain
         put empty into tAgain
      else if tRound > 0 then
         xtaPhase "wait", "Waiting for" && xtaModel(tProvider) && "to correct the code (round" && tRound && "of" && tRounds & ")"
      else if sWork["requests"] > 0 then
         xtaPhase "wait", "Waiting for" && xtaModel(tProvider) && "to go on"
      else
         xtaPhase "wait", "Waiting for" && xtaModel(tProvider)
      end if
      xtaWorkStatus
      put xtaSettings() into tSettings
      -- More room than the Settings give, after an answer was cut off
      if tRoom is not empty then
         put tRoom into tSettings["maxTokens"]
      end if
      put xtaAsk(tSettings, tSystem, xtaTurnsToSend(), tTools) into tReply
      if sShutDowns is not tShutDowns then
         exit xtaSendPrompt
      end if
      add 1 to sWork["requests"]
      if tReply["ok"] is not true then
         -- A server of the user's own whose model cannot take tools: asked
         -- again without them, and so until the assistant is turned off
         if tTools is not empty and xtaToolsRefused(tProvider, tReply) then
            put true into sNoTools[tProvider & comma & xtaModel(tProvider)]
            put empty into tTools
            next repeat
         end if
         exit repeat
      end if
      add tReply["inputTokens"] to tIn
      add tReply["outputTokens"] to tOut
      add tReply["cachedTokens"] to tCached
      put tIn into sWork["in"]
      put tOut into sWork["out"]
      put tCached into sWork["cached"]
      xtaWorkStatus
      -- An answer cut off at its length limit before it said anything, or
      -- while it was writing a call to a tool, is asked for again with more
      -- room (xtaMoreRoom): Anthropic's models think before they answer,
      -- and the thinking counts toward the limit. In 0.2.5-rc.4 such an
      -- answer showed as an empty one. A call that was cut off is never
      -- carried out, as its input is not whole, nor are the calls of an
      -- answer the provider stopped on safety grounds, which is not sent
      -- back either: the window says why the answer ends there (its "cut").
      put empty into tCutNote
      put empty into tCallName
      put false into tRefused
      if tTools is not empty and the number of elements of tReply["calls"] > 0 then
         put tReply["calls"][the number of elements of tReply["calls"]]["name"] into tCallName
      end if
      if tReply["stop"] is "max_tokens" or tReply["stop"] is "length" then
         if (tCallName is not empty or word 1 to -1 of tReply["text"] is empty) and sStopAsked is not true then
            put xtaMoreRoom(tProvider, tRoom) into tMore
            if tMore is not empty then
               -- Short enough for the activity row beside its clock
               put "Cut off at" && xtaRoom(tProvider, tRoom) && "tokens: asking again with room for" && tMore into tAgain
               put tMore into tRoom
               next repeat
            end if
         end if
         put xtaCutNote(tProvider, tRoom, tReply["text"], tCallName) into tCutNote
         put empty into tReply["calls"]
      else if tReply["stop"] is "refusal" or tReply["stop"] is "content_filter" then
         put xtaRefusalNote(tProvider, tReply["category"]) into tCutNote
         put true into tRefused
         put empty into tReply["calls"]
      end if
      put empty into tCalls
      if tTools is not empty then
         put tReply["calls"] into tCalls
      end if
      put the number of elements of sTurns + 1 into tCount
      put "assistant" into sTurns[tCount]["role"]
      put tReply["text"] into sTurns[tCount]["text"]
      if the number of elements of tCalls > 0 then
         put tCalls into sTurns[tCount]["calls"]
      end if
      put xtaMemoryProposals(tReply["text"]) into sTurns[tCount]["notes"]
      put sTurns[tCount - 1]["stackPath"] into sTurns[tCount]["stackPath"]
      put sTurns[tCount - 1]["stackName"] into sTurns[tCount]["stackName"]
      if tCutNote is not empty then
         put tCutNote into sTurns[tCount]["cut"]
      end if
      if tRefused then
         put true into sTurns[tCount]["refused"]
      end if
      -- Insert takes the code of the latest answer, or none when it has
      -- none; an answer that only asks for tools leaves it as the answers
      -- to this question had it
      put xtaXTalkBlocks(xtaCodeBlocks(tReply["text"])) into tBlocks
      if the number of elements of tCalls is 0 or the number of elements of tBlocks > 0 or not tAnswered then
         put tBlocks into sLastCode
      end if
      put true into tAnswered

      if the number of elements of tCalls > 0 then
         xtaShowConversation
         put empty into tResults
         put false into tRefusedNow
         repeat with tCall = 1 to the number of elements of tCalls
            if sStopAsked is true then
               put "Not run: the user pressed Stop." into tResults[tCall]["text"]
               put true into tResults[tCall]["error"]
               put "Did not use" && tCalls[tCall]["name"] & ": you pressed Stop" into tResults[tCall]["summary"]
            else if tToolCalls >= kMaxToolCalls then
               put "Not run: you have used the" && kMaxToolCalls && "tools you may use for one question. Answer with what you have." into tResults[tCall]["text"]
               put true into tResults[tCall]["error"]
               put "Did not use" && tCalls[tCall]["name"] & ": the" && kMaxToolCalls && "tool uses of a question are used up" into tResults[tCall]["summary"]
               put true into tRefusedNow
            else
               add 1 to tToolCalls
               put xtaRunTool(tCalls[tCall], tDeclared, tProvider) into tResults[tCall]
               -- A tool can ask the user, and the assistant can be turned
               -- off meanwhile
               if sShutDowns is not tShutDowns then
                  exit xtaSendPrompt
               end if
            end if
         end repeat
         put the number of elements of sTurns + 1 into tCount
         put "user" into sTurns[tCount]["role"]
         put "tools" into sTurns[tCount]["kind"]
         put tResults into sTurns[tCount]["results"]
         put sTurns[tCount - 1]["stackPath"] into sTurns[tCount]["stackPath"]
         put sTurns[tCount - 1]["stackName"] into sTurns[tCount]["stackName"]
         xtaShowConversation
         if sStopAsked is true or there is not a stack kWindow then
            exit repeat
         end if
         -- Told its tools are used up, the model has one answer more to
         -- answer without them
         if tRefusedNow then
            add 1 to tRefusals
            if tRefusals > 1 then
               put true into tSpent
               exit repeat
            end if
         end if
         next repeat
      end if

      -- The code of an answer that was cut off is not whole: it is not
      -- sent back to be corrected
      if the number of elements of tBlocks is 0 or tCutNote is not empty then
         exit repeat
      end if
      xtaShowConversation
      xtaPhase "check", "Checking that the code compiles"
      put xtaCheckBlocks(tBlocks, tDeclared) into tCheck
      put tCheck["summary"] into sTurns[tCount]["check"]
      if tCheck["ok"] is true or tRound >= tRounds or sStopAsked is true or tCheck["code"] is tLastCode then
         exit repeat
      end if
      put tCheck["code"] into tLastCode
      add 1 to tRound
      put the number of elements of sTurns + 1 into tCount
      put "user" into sTurns[tCount]["role"]
      put "check" into sTurns[tCount]["kind"]
      put tCheck["report"] into sTurns[tCount]["text"]
      put sTurns[tCount - 1]["stackPath"] into sTurns[tCount]["stackPath"]
      put sTurns[tCount - 1]["stackName"] into sTurns[tCount]["stackName"]
      xtaShowConversation
   end repeat
   catch tCrash
      put xtaThrownText(tCrash) into tCrash
      if word 1 to -1 of tCrash is empty then
         put "an unknown error" into tCrash
      end if
   end try

   -- What the question took, for the conversation and the status line
   put (sStopAsked is true) into tStopped
   put the milliseconds - sWork["start"] into tStats["ms"]
   put sWork["requests"] into tStats["requests"]
   put tIn into tStats["in"]
   put tOut into tStats["out"]
   put tCached into tStats["cached"]
   put false into sBusy
   put false into sStopAsked
   xtaWorkEnd
   if tCrash is not empty then
      put "The question stopped on an error in the xTalk Assistant:" && tCrash & "." & return & return & \
            "What was answered before it stays in the conversation; you can ask again." into tError
   else if tReply["ok"] is not true then
      put tReply["error"] into tError
      -- The turn that was not answered is taken back: the question stays in
      -- the prompt, to send again; a compile check is dropped, and the
      -- answer before it stays. The results of tools stay, as their calls
      -- did: the next question sends them.
      put the number of elements of sTurns into tCount
      if sTurns[tCount]["kind"] is not "tools" then
         -- What the user undid goes with the next question instead
         if sTurns[tCount]["undone"] is not empty then
            put sTurns[tCount]["undone"] before sUndone
         end if
         delete variable sTurns[tCount]
      end if
      if not tAnswered and there is a stack kWindow then
         put tPrompt into field "Prompt" of stack kWindow
         xtaPromptChanged
      end if
   end if
   if there is not a stack kWindow then
      exit xtaSendPrompt
   end if
   if tAnswered and sTurns[tQuestion]["role"] is "user" then
      put tStats into sTurns[tQuestion]["stats"]
   end if
   xtaShowConversation
   xtaUpdateButtons
   if tAnswered then
      put empty into tKind
      put "Answered in" && xtaStatsLine(tStats) into tStatus
      if tReply["stop"] is "max_tokens" or tReply["stop"] is "length" then
         put xtaDot() & "the answer was cut off at its length limit" after tStatus
         put "warn" into tKind
      else if tReply["stop"] is "refusal" or tReply["stop"] is "content_filter" then
         put xtaDot() & "the provider stopped the answer on safety grounds" after tStatus
         put "warn" into tKind
      end if
      if tCrash is not empty then
         put xtaDot() & "stopped on an error" after tStatus
         put "warn" into tKind
      else if tSpent then
         put xtaDot() & "stopped: the model used up its tools for this question" after tStatus
         put "warn" into tKind
      else if tStopped then
         put xtaDot() & "you stopped it" after tStatus
      end if
      if tCheck["summary"] is not empty and tCheck["ok"] is not true then
         put xtaDot() & "the code does not compile" after tStatus
         put "warn" into tKind
      end if
      xtaStatus tStatus, tKind
   else
      xtaStatus xtaSettingsLine()
   end if
   if tError is not empty then
      if line 1 of tError contains "API key" and tCrash is empty then
         put empty into sKeys[tProvider]
      end if
      answer warning tError titled kTitle
   end if
end xtaSendPrompt

-- The longest answer the next request asks for, in tokens: pRoom when an
-- answer was cut off and more room was given, otherwise what the Settings
-- say (empty when OpenAI's model decides)
private function xtaRoom pProvider, pRoom
   if pRoom is not empty then
      return pRoom
   end if
   return xtaMaxTokens(pProvider, revIDEGetPreference(kPrefMaxTokens))
end xtaRoom

-- The room to ask again with, for an answer cut off at the length limit
-- xtaRoom(pProvider, pRoom): twice that, and at least what Anthropic gets
-- by default, up to kMostRoom; empty when there is no more to give (the
-- limit is kMostRoom or more already, or OpenAI's model decides it)
private function xtaMoreRoom pProvider, pRoom
   local tNow, tMore
   put xtaRoom(pProvider, pRoom) into tNow
   if tNow is not an integer then
      return empty
   end if
   put min(max(tNow * 2, xtaMaxTokens("anthropic", empty)), kMostRoom) into tMore
   if tMore <= tNow then
      return empty
   end if
   return tMore
end xtaMoreRoom

-- Why an answer cut off at its length limit ends where it does, for the
-- window: pText is what it said, and pCallName the tool it was asking for
-- when it was cut off (empty when none)
private function xtaCutNote pProvider, pRoom, pText, pCallName
   local tRoom, tNote
   put xtaRoom(pProvider, pRoom) into tRoom
   if tRoom is empty then
      put "Cut off at the model's length limit" into tNote
   else
      put "Cut off at the length limit of" && tRoom && "tokens" into tNote
   end if
   if pCallName is not empty then
      put ", while the model was writing a call to" && pCallName & ", which was not carried out." && \
            "Ask for less at a time, such as one card or a few controls, or raise the longest answer in More > Settings." after tNote
   else if word 1 to -1 of pText is empty then
      put ", before the model wrote its answer: its thinking counts toward the limit." && \
            "Ask for less at a time, or raise the longest answer in More > Settings." after tNote
   else
      put "." && "Ask the assistant to go on, or raise the longest answer in More > Settings." after tNote
   end if
   return tNote
end xtaCutNote

-- Why an answer the provider stopped on safety grounds ends where it does
-- (Anthropic's "refusal", OpenAI's "content_filter"): pCategory is the kind
-- of request Anthropic took it for, when it says
private function xtaRefusalNote pProvider, pCategory
   local tNote
   if pProvider is "anthropic" then
      put "Anthropic stopped this answer on safety grounds" into tNote
   else
      put "The provider's content filter stopped this answer" into tNote
   end if
   if pCategory is not empty then
      put " (" & pCategory & ")" after tNote
   end if
   put ". Nothing it asked for was done, and it is not sent with your next question." after tNote
   return tNote
end xtaRefusalNote

-- The conversation as it is sent: the open script goes with the latest
-- question that had one, so that it is sent once rather than with every
-- question; what else went with a question (the last error) stays with it.
-- Of the pictures of cards (look_at_card), the newest kKeptPictures go
-- with each request: an older one the model has seen, and it would make
-- every request after it bigger. None goes once the Settings no longer let
-- pictures be sent: the user turned them off, or chose a server that is
-- not sent them, in the middle of the conversation. An answer the provider
-- stopped on safety grounds is left out (its "refused"): what it said is
-- not whole, and the model is not to go on from it.
private function xtaTurnsToSend
   local tTurns, tIndex, tLast, tCall, tPictures, tKeep
   put 0 into tLast
   repeat with tIndex = 1 to the number of elements of sTurns
      if sTurns[tIndex]["context"] is not empty then
         put tIndex into tLast
      end if
   end repeat
   repeat with tIndex = 1 to the number of elements of sTurns
      put sTurns[tIndex]["role"] into tTurns[tIndex]["role"]
      put sTurns[tIndex]["text"] into tTurns[tIndex]["text"]
      if sTurns[tIndex]["refused"] is true then
         put empty into tTurns[tIndex]["text"]
      end if
      put sTurns[tIndex]["kind"] into tTurns[tIndex]["kind"]
      put sTurns[tIndex]["calls"] into tTurns[tIndex]["calls"]
      put sTurns[tIndex]["results"] into tTurns[tIndex]["results"]
      if sTurns[tIndex]["attach"] is not empty then
         put return & return & sTurns[tIndex]["attach"] after tTurns[tIndex]["text"]
      end if
      if sTurns[tIndex]["undone"] is not empty then
         put return & return & "(Since your last answer I undid what follows, so it is no longer in the stack. Read the stack again before you change it.)" & \
               return & sTurns[tIndex]["undone"] after tTurns[tIndex]["text"]
      end if
      if tIndex is tLast then
         put return & return & "The script I am editing, of" && sTurns[tIndex]["contextName"] & ":" & return & \
               "```livecodescript" & return & sTurns[tIndex]["context"] & return & "```" after tTurns[tIndex]["text"]
      end if
   end repeat
   put kKeptPictures into tKeep
   if not xtaPicturesOn(xtaProvider()) then
      put 0 into tKeep
   end if
   put 0 into tPictures
   repeat with tIndex = the number of elements of tTurns down to 1
      repeat with tCall = the number of elements of tTurns[tIndex]["results"] down to 1
         if tTurns[tIndex]["results"][tCall]["image"] is empty then
            next repeat
         end if
         add 1 to tPictures
         if tPictures > tKeep then
            delete variable tTurns[tIndex]["results"][tCall]["image"]
            if tKeep is 0 then
               put return & "(The picture is no longer sent: the assistant's Settings no longer let it send pictures.)" \
                     after tTurns[tIndex]["results"][tCall]["text"]
            else
               put return & "(The picture is no longer sent: you saw it then. Look again for how it is now.)" \
                     after tTurns[tIndex]["results"][tCall]["text"]
            end if
         end if
      end repeat
   end repeat
   return tTurns
end xtaTurnsToSend

--------------------------------------------------------------------------------
-- The Script Editor

private function xtaTopScriptEditor
   local tEditor
   try
      put revTopMostScriptEditor() into tEditor
   catch tError
      put empty into tEditor
   end try
   if tEditor is not empty and there is not a tEditor then
      put empty into tEditor
   end if
   return tEditor
end xtaTopScriptEditor

-- The script open in the topmost Script Editor, as it is being edited
-- (applied or not): "script", and "name", the object it belongs to, named
-- without the path of its stack file.
private function xtaScriptContext
   local tEditor, tObject, tContext, tScript, tStack, tPassword
   put xtaTopScriptEditor() into tEditor
   if tEditor is empty then
      return tContext
   end if
   try
      dispatch "revSEGetCurrentObject" to tEditor
      put the result into tObject
      dispatch function "revSEGetScript" to tEditor
      put the result into tScript
   catch tError
      return tContext
   end try
   if tObject is empty or there is not a tObject then
      return tContext
   end if
   -- A password-protected stack's scripts are not sent (the test the
   -- IDE's documentation builder makes, revidelibrary.8.livecodescript)
   put revIDEStackOfObject(tObject) into tStack
   put "protected" into tPassword
   try
      put the password of tStack into tPassword
   catch tError
   end try
   if tPassword is not empty then
      return tContext
   end if
   if the number of chars of tScript > kMaxScriptChars then
      put char 1 to kMaxScriptChars of tScript & return & "-- (the rest of the script was left out)" into tScript
   end if
   put tScript into tContext["script"]
   if word 1 of the name of tObject is "stack" then
      put the name of tObject into tContext["name"]
   else
      put the name of tObject && "of stack" && quote & the short name of tStack & quote into tContext["name"]
   end if
   return tContext
end xtaScriptContext

on xtaInsertCode
   local tCode, tIndex
   if the number of elements of sLastCode is 0 then
      exit xtaInsertCode
   end if
   if the number of elements of sLastCode is 1 then
      put sLastCode[1]["code"] into tCode
   else
      answer question "The answer has" && the number of elements of sLastCode && "pieces of code. Insert which?" \
            with "Cancel" or "Last" or "First" or "All" titled kTitle
      switch it
         case "All"
            repeat with tIndex = 1 to the number of elements of sLastCode
               if tCode is not empty then
                  put return & return after tCode
               end if
               put sLastCode[tIndex]["code"] after tCode
            end repeat
            break
         case "First"
            put sLastCode[1]["code"] into tCode
            break
         case "Last"
            put sLastCode[the number of elements of sLastCode]["code"] into tCode
            break
         default
            exit xtaInsertCode
      end switch
   end if
   xtaInsertText tCode
end xtaInsertCode

-- Inserts pCode at the caret in the Script Editor, as one step its Undo
-- takes out; with no Script Editor that can take it, it goes on the
-- clipboard
private command xtaInsertText pCode
   local tEditor
   put xtaTopScriptEditor() into tEditor
   if tEditor is empty then
      set the clipboardData["text"] to pCode
      answer information "Open a script in the Script Editor first. The code is on the clipboard meanwhile." titled kTitle
      exit xtaInsertText
   end if
   dispatch "revSEInsertText" to tEditor with pCode
   if it is not "handled" then
      set the clipboardData["text"] to pCode
      answer information "This Script Editor cannot take the code; it is on the clipboard to paste." titled kTitle
      exit xtaInsertText
   end if
   xtaStatus "Inserted. Apply the script to keep it, or Undo to take it out."
end xtaInsertText

--------------------------------------------------------------------------------
-- In another xTalk's IDE

-- Loads the package's compatibility stack (xtalkassistant-compat.livecodescript),
-- when this copy of the plugin has one, and starts it; it does nothing on
-- an IDE whose menu bar and Script Editor know the plugin already
private command xtaStartCompat
   local tFile, tError
   put xtaPluginFolder() & "/xtalkassistant-compat.livecodescript" into tFile
   if there is not a file tFile then
      exit xtaStartCompat
   end if
   try
      if there is not a stack kCompat then
         get the short name of stack tFile
      end if
      if not (the long id of stack kCompat is among the lines of xtaCompatInUse()) then
         start using stack kCompat
      end if
      set the _ideoverride of stack kCompat to true
      dispatch "xtpcStart" to stack kCompat
   catch tError
   end try
end xtaStartCompat

private command xtaStopCompat
   local tError
   if there is not a stack kCompat then
      exit xtaStopCompat
   end if
   try
      dispatch "xtpcStop" to stack kCompat
      if the long id of stack kCompat is among the lines of xtaCompatInUse() then
         stop using stack kCompat
      end if
      delete stack kCompat
   catch tError
   end try
end xtaStopCompat

private function xtaCompatInUse
   local tList, tName
   repeat for each line tName in the stacksInUse
      if there is a stack tName then
         put the long id of stack tName & return after tList
      end if
   end repeat
   return tList
end xtaCompatInUse

-- The IDE's name, where the user or the model reads it: "OXT-Beyond", or,
-- in a package of the plugin installed in another xTalk's IDE, the name
-- its compatibility stack gives (tools/plugins/plugin-compat.livecodescript.in)
private function xtaHostName
   local tStack, tName
   repeat for each item tStack in "org.openxtalk.plugin.xtalkassistant-compat,org.openxtalk.plugin.mcpbridge-compat"
      if there is a stack tStack then
         dispatch function "xtpcHostName" to stack tStack
         put the result into tName
         if it is "handled" and tName is not empty then
            return tName
         end if
      end if
   end repeat
   return "OXT-Beyond"
end xtaHostName
