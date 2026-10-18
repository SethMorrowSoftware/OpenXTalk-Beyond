script "org.openxtalk.plugin.xtalkchat-core"
-- OXT-Beyond: the network side of xTalk Chat, the plugin that lets the
-- people using OXT-Beyond talk to each other: rooms everyone can read,
-- a list of who is online now, and private messages.
--
-- It is built on the xTalk Suite's NostrXT (nostrxt, nostr-relay), CoinXT
-- and SodiumXT, which OXT-Beyond ships built in. Chat goes through Nostr
-- relays: servers anyone can run, which pass on and keep signed events.
-- No server of ours is involved. Who you are is a key made on this
-- computer and kept in ~/.oxt-beyond/xtalk-chat; every message is signed
-- with it, and every message received is checked (nostr-relay verifies the
-- id and the signature before it hands an event on) before it is shown.
--
-- What goes to the relays, and so what the chat window says before anyone
-- goes online:
--  - Rooms are NIP-28 public channels. Their messages (kind 42) can be
--    read by anyone, with any Nostr client that shows channels.
--  - "Who is online" is a short signed note (kind 21042, in NIP-01's
--    ephemeral range, which relays pass on and do not keep) sent every 45
--    seconds while the window is open: the name, and the OXT-Beyond
--    version when the user lets it. A new arrival also asks the others to
--    send theirs at once, so the list fills in seconds.
--  - Private messages are NIP-17 messages: the text is encrypted with
--    NIP-44 for the other person, sealed, and wrapped under a key used
--    once, so relays see neither who wrote it nor what it says.
--  - The relays see the user's IP address, as any server does.
--
-- Nothing is sent until the user presses Go online, and the chat goes
-- offline when its window closes (xtcGoOffline). This stack is in the
-- message path only while the chat's window is open (the plugin's main
-- stack starts and stops using it). It is a library for that window: every
-- handler's name begins with xtc, and it handles no message of the
-- engine's, so a user's stack never meets it.
--
-- How it hears the relays. nostr-relay dispatches each relay's callback to
-- one object for the whole library (nxrInit), so this library never calls
-- nxrInit: a user's stack that uses NostrXT keeps its callbacks. Its
-- callback, xtcRelayCallback, is a name no other script has; dispatched to
-- that object (or the topStack), it goes up the message path to this
-- library, which is in use while the window is open.
--
-- The window is told what changed with "xtalkChatChanged pWhat, pKey", sent to
-- the object xtcSetObserver names: "status" (going online or offline, the
-- relays), "rooms", "messages" (pKey the conversation), "people" and
-- "notice" (pKey a sentence for the user). Changes that come together are
-- told once.
--
-- A conversation is named by a key: "room:<the room's event id>" or
-- "dm:<the other person's public key>". A message is an array: id, pk (the
-- author's public key), at (its unix time), text, and state ("sent",
-- "pending" while no relay has taken it yet, or "failed").
--
-- Tested by tests/lcs/xtalkchat/core.livecodescript.

-- The kinds this chat uses
constant kKindMetadata = 0
constant kKindChannel = 40
constant kKindChannelMessage = 42
constant kKindSeal = 13
constant kKindPrivate = 14
constant kKindWrap = 1059
constant kKindPresence = 21042
-- The topic tag that marks this chat's presence notes
constant kPresenceTag = "xtalk-chat"
-- How often a presence note is sent, and how long after the last one a
-- person still counts as online
constant kBeatSeconds = 45
constant kOnlineSeconds = 120
-- How many messages of each room are asked for when going online, how
-- many of each conversation are kept, and the longest message
constant kRoomHistory = 120
constant kKeepMessages = 400
constant kMaxMessageChars = 4000
-- How long a message may wait for a relay to take it before it is shown
-- as not sent
constant kSendTimeout = 12
-- NIP-59: the seal's and the wrap's times are moved back by up to two days,
-- so a relay cannot tell when a private message was written; asking for
-- three days of them finds the ones written in the last day
constant kWrapJitter = 172800
constant kWrapHistory = 259200
-- Seconds between tries to reach a relay that went away, by attempt
constant kRetrySeconds = "5,10,30,60,120"
-- The relays used unless the user names others
constant kDefaultRelays = "wss://nos.lol,wss://relay.damus.io,wss://nostr.mom"

-- The identity: sId["sk"], sId["pk"], sId["name"]
local sId
-- True while online; the generation, which ends the timers of an earlier
-- time online; the object told about changes
local sOnline, sGen, sObserver
-- The relays: the urls in use; by url, its handle, state ("connecting",
-- "open", "offline") and the try it is on; by handle, its url
local sRelayUrls, sRelayHandle, sRelayState, sRelayTry, sHandleUrl
-- Event ids already taken in, so that the same event from three relays is
-- taken once
local sSeen
-- The conversations: by key, their messages by id; their unread counts;
-- and the conversation the user is looking at (its messages are read)
local sMsgs, sUnread, sLooking
-- The people heard of: by public key, name, client, the time of their last
-- presence note, and whether their profile has been asked for
local sPeople
-- The messages sent and not yet taken by a relay: by id, the
-- conversation, the relays that refused and why
local sPending
-- The changes waiting to be told, and whether a tell is due
local sChanged, sTellDue
-- The settings the window gives: show the OXT-Beyond version
local sShowClient
-- The people the user does not want to hear (public keys, one a line)
local sMuted
-- The rooms, as xtcRooms gives them, once read
local sRooms

--------------------------------------------------------------------------------
-- The rooms

-- The rooms everyone starts with: NIP-28 channel events (kind 40),
-- signed once, when the chat was made, with a key that was then thrown
-- away, so that no one can sign changes to them (NIP-28 takes a room's
-- name and description only from the key that made it). Their ids name
-- the rooms; xtcGoOnline publishes them again to each relay, so that any
-- relay knows them. Their order is the sidebar's.
function xtcRoomEvents
   local tOut
   put "{'id':'e35bd8b523b41ad647e5d16411a533b9ab32f9a6170f59890c35b91e5ec0d58" & \
         "2','pubkey':'33530b06965d6c77e230d17009bb469f9e9ff904724c7253692504a02" & \
         "997d45d','created_at':1792358400,'kind':40,'tags':[['t','xtalk-chat']]" & \
         ",'content':'{\'name\':\'xTalk Lobby\',\'about\':\'Say hello and talk a" & \
         "bout anything xTalk: OXT-Beyond, LiveCode, HyperCard and the rest.\',\" & \
         "'picture\':\'\'}','sig':'63ca211ee9fa3e7f6b1eacef656a7d2190d0a142a5e5c" & \
         "88db47e8e8b6fca2c6e1dcf14f4f7885d9414fd62cc4182cdab3385971a701f1ee0b11" & \
         "f27052407aa39'}" & return after tOut
   put "{'id':'c4b15696220c37b5abf06b9b9f0daccae6c260ebe2f8824f6731602a5efd730" & \
         "3','pubkey':'33530b06965d6c77e230d17009bb469f9e9ff904724c7253692504a02" & \
         "997d45d','created_at':1792358400,'kind':40,'tags':[['t','xtalk-chat']]" & \
         ",'content':'{\'name\':\'xTalk Help\',\'about\':\'Ask how to do somethi" & \
         "ng in xTalk, or why a script does what it does.\',\'picture\':\'\'}','" & \
         "sig':'842fdfddee5313a16131a73bee2327bda3c6428ce29d767c5ef7edf938edd666" & \
         "6491e461c7650d2e953663f88caba9eac8fd5ac441622f552e890d0b2b7804ed'}" & return after tOut
   put "{'id':'98fde1dd20abb5c1a6f0138b8b1238fa90e9c541e3fdb437cad74bd8ed103ba" & \
         "d','pubkey':'33530b06965d6c77e230d17009bb469f9e9ff904724c7253692504a02" & \
         "997d45d','created_at':1792358400,'kind':40,'tags':[['t','xtalk-chat']]" & \
         ",'content':'{\'name\':\'xTalk Show and Tell\',\'about\':\'Share what y" & \
         "ou are making: stacks, demos, screenshots and links.\',\'picture\':\'\" & \
         "'}','sig':'f5537bb560ce3daeecacb0352ff1d3dae8140652446b6e1406970b137ca" & \
         "b4fc353e27b699078d79b310f50f6c40366177e5901bd45ff5e40456a6262537c0ef1'" & \
         "}" & return after tOut
   delete the last char of tOut
   -- (written with ' for each quote, which a string cannot hold)
   replace "'" with quote in tOut
   return tOut
end xtcRoomEvents

-- The rooms: one a line, key, name and description, tab separated
function xtcRooms
   local tOut, tLine, tEvent, tName, tAbout
   if sRooms is not empty then
      return sRooms
   end if
   repeat for each line tLine in xtcRoomEvents()
      if tLine is empty then
         next repeat
      end if
      put nxEventFromJson(tLine) into tEvent
      if tEvent["id"] is empty then
         next repeat
      end if
      put nxJsonGet(tEvent["content"], "name") into tName
      put nxJsonGet(tEvent["content"], "about") into tAbout
      put "room:" & tEvent["id"] & tab & xtcOneLine(tName) & tab & xtcOneLine(tAbout) & return after tOut
   end repeat
   delete the last char of tOut
   put tOut into sRooms
   return tOut
end xtcRooms

-- The ids of the rooms, one a line
private function xtcRoomIds
   local tOut, tLine
   set the itemDelimiter to tab
   repeat for each line tLine in xtcRooms()
      put char 6 to -1 of item 1 of tLine & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end xtcRoomIds

private function xtcOneLine pText
   replace return with space in pText
   replace tab with space in pText
   return pText
end xtcOneLine

--------------------------------------------------------------------------------
-- Who the user is

-- The folder the chat keeps its files in: .oxt-beyond/xtalk-chat in the
-- user's home folder (USERPROFILE on Windows, HOME elsewhere), beside the
-- MCP Bridge's file. XTALK_CHAT_HOME names another, for the tests.
function xtcFolder
   local tHome
   if $XTALK_CHAT_HOME is not empty then
      return $XTALK_CHAT_HOME
   end if
   if the platform is "Win32" then
      put $USERPROFILE into tHome
      replace backslash with slash in tHome
   else
      put $HOME into tHome
   end if
   if tHome is empty then
      put specialFolderPath("home") into tHome
   end if
   return tHome & "/.oxt-beyond/xtalk-chat"
end xtcFolder

function xtcIdentityFile
   return xtcFolder() & "/identity.txt"
end xtcIdentityFile

-- Whether the suite's libraries the chat needs are here: empty when they
-- are, or a sentence saying what is missing
function xtcMissing
   local tCaps, tError
   try
      get nxrVersion()
   catch tError
      return "The NostrXT extension is not loaded. Turn it on in the Extension Manager."
   end try
   try
      put nxProbeCapabilities() into tCaps
   catch tError
      return "The NostrXT extension is not loaded. Turn it on in the Extension Manager."
   end try
   if tCaps["hasCoin"] is not true or tCaps["canSign"] is not true then
      return "The CoinXT extension is not loaded, and xTalk Chat signs every message with it. Turn it on in the Extension Manager."
   end if
   if tCaps["hasSodium"] is not true then
      return "The SodiumXT extension is not loaded, and xTalk Chat makes its keys with it. Turn it on in the Extension Manager."
   end if
   return empty
end xtcMissing

-- Whether private messages can be sent (NIP-44 needs SodiumXT's cipher)
function xtcCanMessagePrivately
   local tError
   try
      return nxNip44HasCipher() is true
   catch tError
      return false
   end try
end xtcCanMessagePrivately

-- Reads the identity kept on this computer; false when there is none
function xtcIdentityLoad
   local tText, tSk, tName
   put empty into sId
   if there is no file xtcIdentityFile() then
      return false
   end if
   put textDecode(URL ("binfile:" & xtcIdentityFile()), "UTF-8") into tText
   put xtcLineValue(tText, "key") into tSk
   put xtcLineValue(tText, "name") into tName
   if not nxIsHex(tSk, 64) or not nxKeyIsValid(tSk) then
      return false
   end if
   put toLower(tSk) into sId["sk"]
   put nxKeyPublic(sId["sk"]) into sId["pk"]
   put tName into sId["name"]
   put xtcLineValue(tText, "made") into sId["made"]
   return sId["pk"] is not empty
end xtcIdentityLoad

-- The value of a "name: value" line of pText
private function xtcLineValue pText, pName
   local tLine, tStart
   put the number of chars of pName + 2 into tStart
   repeat for each line tLine in pText
      if tLine begins with (pName & ":") then
         delete char 1 to tStart - 1 of tLine
         return word 1 to -1 of tLine
      end if
   end repeat
   return empty
end xtcLineValue

-- Makes a new identity with the name pName, or (pSecret, an nsec or 64
-- hex) takes one the user already has, and keeps it. Empty, or why not.
command xtcIdentityCreate pName, pSecret
   local tSk, tDecoded
   if pSecret is empty then
      put nxKeyGenerate() into tSk
      if tSk is empty then
         return "A key could not be made:" && nxLastError()
      end if
   else
      put word 1 to -1 of pSecret into pSecret
      if pSecret begins with "nsec1" then
         put nxNsecDecode(pSecret) into tDecoded
         if tDecoded is empty then
            return "That is not a secret key (nsec1...) this chat can read."
         end if
         put tDecoded into tSk
      else if nxIsHex(pSecret, 64) then
         put toLower(pSecret) into tSk
      else
         return "That is not a secret key: paste the nsec1... text."
      end if
      if not nxKeyIsValid(tSk) then
         return "That is not a secret key this chat can use."
      end if
   end if
   put tSk into sId["sk"]
   put nxKeyPublic(tSk) into sId["pk"]
   put xtcCleanName(pName) into sId["name"]
   -- A key the user brought may have a Nostr profile of its own, which
   -- the chat must not write over (xtcPublishProfile)
   if pSecret is empty then
      put "here" into sId["made"]
   else
      put "brought" into sId["made"]
   end if
   xtcIdentitySave
   return the result
end xtcIdentityCreate

-- Writes the identity file. On Linux and macOS it is made readable by its
-- owner alone (umask 077 while it is written).
private command xtcIdentitySave
   local tText, tOldUmask, tError, tWritten
   if sId["sk"] is empty then
      return "There is no identity to keep."
   end if
   xtcEnsureFolder xtcFolder()
   put "xTalk Chat identity. The key below is who you are in xTalk Chat: anyone who has it can write as you. Keep this file to yourself." & return into tText
   put "key: " & sId["sk"] & return after tText
   put "name: " & sId["name"] & return after tText
   put "made: " & sId["made"] & return after tText
   put the umask into tOldUmask
   try
      if the platform is not "Win32" then
         set the umask to 63
      end if
      put textEncode(tText, "UTF-8") into URL ("binfile:" & xtcIdentityFile())
      put the result into tWritten
   catch tError
      set the umask to tOldUmask
      return "The identity could not be kept in" && xtcIdentityFile()
   end try
   set the umask to tOldUmask
   if tWritten is not empty then
      return "The identity could not be kept in" && xtcIdentityFile() & ":" && tWritten
   end if
   return empty
end xtcIdentitySave

private command xtcEnsureFolder pFolder
   local tPath, tPart
   set the itemDelimiter to slash
   repeat for each item tPart in pFolder
      if tPath is empty and tPart is empty then
         put "/" into tPath
         next repeat
      end if
      if tPath is empty or tPath is "/" then
         put tPath & tPart into tPath
      else
         put tPath & "/" & tPart into tPath
      end if
      if there is no folder tPath then
         create folder tPath
      end if
   end repeat
end xtcEnsureFolder

-- Forgets the identity: the file is deleted (the user was asked first)
command xtcIdentityForget
   if sOnline is true then
      xtcGoOffline
   end if
   if there is a file xtcIdentityFile() then
      delete file xtcIdentityFile()
   end if
   put empty into sId
   put empty into sMsgs
   put empty into sUnread
   put empty into sPeople
   put empty into sSeen
end xtcIdentityForget

function xtcHasIdentity
   return sId["pk"] is not empty
end xtcHasIdentity

function xtcMyKey
   return sId["pk"]
end xtcMyKey

function xtcMyName
   return sId["name"]
end xtcMyName

-- The user's public key as an npub, which the user can give others
function xtcMyNpub
   if sId["pk"] is empty then
      return empty
   end if
   return nxNpubEncode(sId["pk"])
end xtcMyNpub

-- The secret key as an nsec, for the user to keep a copy (the window asks
-- first and says what it is)
function xtcMyNsec
   if sId["sk"] is empty then
      return empty
   end if
   return nxNsecEncode(sId["sk"])
end xtcMyNsec

-- A name: one line, no more than 32 characters, never empty
function xtcCleanName pName
   put xtcOneLine(pName) into pName
   put word 1 to -1 of pName into pName
   if the number of chars of pName > 32 then
      put char 1 to 32 of pName into pName
   end if
   if pName is empty then
      put "Someone" into pName
   end if
   return pName
end xtcCleanName

-- Changes the name, keeps it, and tells the others
command xtcSetName pName
   put xtcCleanName(pName) into sId["name"]
   xtcIdentitySave
   if sOnline is true then
      xtcPublishProfile
      xtcPublishPresence "online"
   end if
   xtcChanged "people"
   xtcChanged "status"
end xtcSetName

command xtcSetShowClient pShow
   put pShow is true into sShowClient
end xtcSetShowClient

--------------------------------------------------------------------------------
-- Online and offline

command xtcSetObserver pObject
   put pObject into sObserver
end xtcSetObserver

function xtcDefaultRelays
   local tOut
   put kDefaultRelays into tOut
   replace comma with return in tOut
   return tOut
end xtcDefaultRelays

function xtcIsOnline
   return sOnline is true
end xtcIsOnline

-- Connects to the relays pRelays (one url a line; empty for the default
-- ones) and starts listening. Empty, or why it cannot.
command xtcGoOnline pRelays
   local tUrl, tMissing
   put xtcMissing() into tMissing
   if tMissing is not empty then
      return tMissing
   end if
   if sId["pk"] is empty then
      return "There is no identity yet."
   end if
   if sOnline is true then
      return empty
   end if
   if pRelays is empty then
      put xtcDefaultRelays() into pRelays
   end if
   put true into sOnline
   add 1 to sGen
   put empty into sRelayUrls
   put empty into sRelayHandle
   put empty into sRelayState
   put empty into sRelayTry
   put empty into sHandleUrl
   repeat for each line tUrl in pRelays
      put word 1 to -1 of tUrl into tUrl
      if tUrl is empty or tUrl is among the lines of sRelayUrls then
         next repeat
      end if
      if not (tUrl begins with "wss://" or tUrl begins with "ws://") then
         next repeat
      end if
      put tUrl & return after sRelayUrls
      put 0 into sRelayTry[tUrl]
      xtcConnect tUrl
   end repeat
   delete the last char of sRelayUrls
   if sRelayUrls is empty then
      put false into sOnline
      return "None of the relays is a wss:// address."
   end if
   send ("xtcBeat" && sGen) to me in kBeatSeconds seconds
   send ("xtcSweep" && sGen) to me in 15 seconds
   xtcChanged "status"
   return empty
end xtcGoOnline

-- Says goodbye (an "offline" presence note to the relays that are open),
-- closes them and stops listening
command xtcGoOffline
   local tUrl, tError
   if sOnline is not true then
      exit xtcGoOffline
   end if
   try
      xtcPublishPresence "offline"
   catch tError
   end try
   put false into sOnline
   add 1 to sGen
   repeat for each line tUrl in sRelayUrls
      if sRelayHandle[tUrl] is not empty then
         try
            nxrDisconnect sRelayHandle[tUrl]
         catch tError
         end try
      end if
   end repeat
   put empty into sRelayHandle
   put empty into sHandleUrl
   put empty into sRelayState
   put empty into sPending
   -- Whoever was online is not known to be now
   xtcForgetPresence
   xtcChanged "status"
   xtcChanged "people"
   xtcTellNow
end xtcGoOffline

-- The relays, one a line: url, tab, state
function xtcRelayStatus
   local tOut, tUrl
   repeat for each line tUrl in sRelayUrls
      put tUrl & tab & sRelayState[tUrl] & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end xtcRelayStatus

function xtcOpenRelayCount
   local tCount, tUrl
   put 0 into tCount
   repeat for each line tUrl in sRelayUrls
      if sRelayState[tUrl] is "open" then
         add 1 to tCount
      end if
   end repeat
   return tCount
end xtcOpenRelayCount

private command xtcConnect pUrl
   local tHandle, tError
   put "connecting" into sRelayState[pUrl]
   try
      nxrConnect pUrl
      put the result into tHandle
   catch tError
      put "NostrXT relay: " & tError into tHandle
   end try
   if tHandle is not an integer then
      put "offline" into sRelayState[pUrl]
      xtcRetryLater pUrl
      exit xtcConnect
   end if
   put tHandle into sRelayHandle[pUrl]
   put pUrl into sHandleUrl[tHandle]
   nxrSetCallback tHandle, "xtcRelayCallback"
end xtcConnect

-- A relay that went away is tried again, later each time
private command xtcRetryLater pUrl
   local tTry, tWait
   if sOnline is not true then
      exit xtcRetryLater
   end if
   add 1 to sRelayTry[pUrl]
   put min(sRelayTry[pUrl], the number of items of kRetrySeconds) into tTry
   put item tTry of kRetrySeconds into tWait
   send ("xtcRetry" && sGen & comma & quote & pUrl & quote) to me in tWait seconds
end xtcRetryLater

on xtcRetry pGen, pUrl
   if pGen is not sGen or sOnline is not true then
      exit xtcRetry
   end if
   if sRelayState[pUrl] is "open" or sRelayState[pUrl] is "connecting" then
      exit xtcRetry
   end if
   xtcConnect pUrl
   xtcChanged "status"
end xtcRetry

-- What a relay says: see nostr-relay's callback contract
on xtcRelayCallback pRelay, pKind, pArgOne, pArgTwo
   local tUrl, tError
   put sHandleUrl[pRelay] into tUrl
   if tUrl is empty then
      -- (a relay of an earlier time online, or not this chat's)
      exit xtcRelayCallback
   end if
   try
      switch pKind
         case "open"
            put "open" into sRelayState[tUrl]
            put 0 into sRelayTry[tUrl]
            xtcRelayOpened pRelay
            xtcChanged "status"
            break
         case "event"
            xtcTakeEvent pArgOne, pArgTwo, tUrl
            break
         case "eose"
            if pArgOne is "xtc-rooms" then
               xtcAskProfiles
            end if
            break
         case "ok"
            xtcTakeVerdict pArgOne, pArgTwo, tUrl
            break
         case "auth"
            xtcAnswerAuth pRelay, pArgOne, tUrl
            break
         case "error"
         case "disconnected"
            delete variable sHandleUrl[pRelay]
            put empty into sRelayHandle[tUrl]
            put "offline" into sRelayState[tUrl]
            xtcRetryLater tUrl
            xtcChanged "status"
            break
      end switch
   catch tError
      -- A message that cannot be read is left out; the chat goes on
   end try
end xtcRelayCallback

-- A relay is open: it is given the rooms, and asked for their messages,
-- the presence notes, and this user's private messages
private command xtcRelayOpened pRelay
   local tLine, tEvent, tFilter, tFilters, tId, tIds
   repeat for each line tLine in xtcRoomEvents()
      put nxEventFromJson(tLine) into tEvent
      if tEvent["id"] is not empty then
         nxrPublish pRelay, tEvent
      end if
   end repeat
   put xtcRoomIds() into tIds
   repeat for each line tId in tIds
      put empty into tFilter
      put kKindChannelMessage into tFilter["kinds"]
      put tId into tFilter["#e"]
      put kRoomHistory into tFilter["limit"]
      put nxFilterBuild(tFilter) & return after tFilters
   end repeat
   delete the last char of tFilters
   nxrSubscribe pRelay, "xtc-rooms", tFilters
   -- Presence notes are not kept by relays: only the ones sent from now on
   put empty into tFilter
   put kKindPresence into tFilter["kinds"]
   put kPresenceTag into tFilter["#t"]
   put nxUnixNow() - 10 into tFilter["since"]
   nxrSubscribe pRelay, "xtc-presence", nxFilterBuild(tFilter)
   put empty into tFilter
   put kKindWrap into tFilter["kinds"]
   put sId["pk"] into tFilter["#p"]
   put nxUnixNow() - kWrapHistory into tFilter["since"]
   nxrSubscribe pRelay, "xtc-private", nxFilterBuild(tFilter)
   -- Here now, and the others are asked to say so too
   xtcPublishPresenceTo pRelay, "hello"
   xtcPublishProfileTo pRelay
end xtcRelayOpened

-- NIP-42: a relay that asks who the user is is told, with a signed event
private command xtcAnswerAuth pRelay, pChallenge, pUrl
   local tEvent
   put nxAuthBuild(pUrl, pChallenge, empty) into tEvent
   put nxEventSign(tEvent, sId["sk"], empty) into tEvent
   if tEvent["sig"] is not empty then
      nxrAuth pRelay, tEvent
   end if
end xtcAnswerAuth

--------------------------------------------------------------------------------
-- What comes in

-- An event a relay sent (already checked by nostr-relay), once
private command xtcTakeEvent pSub, pJson, pUrl
   local tEvent, tId
   put nxEventFromJson(pJson) into tEvent
   put tEvent["id"] into tId
   if tId is empty then
      exit xtcTakeEvent
   end if
   if sSeen[tId] is true then
      exit xtcTakeEvent
   end if
   put true into sSeen[tId]
   switch tEvent["kind"]
      case kKindChannelMessage
         xtcTakeRoomMessage tEvent
         break
      case kKindPresence
         xtcTakePresence tEvent
         break
      case kKindWrap
         xtcTakeWrap tEvent
         break
      case kKindMetadata
         xtcTakeProfile tEvent
         break
   end switch
end xtcTakeEvent

private command xtcTakeRoomMessage pEvent
   local tRoom, tTags, tKey, tIds
   -- The room is the "e" tag marked root (NIP-28), or else the first "e"
   put xtcRootTag(pEvent) into tRoom
   put xtcRoomIds() into tIds
   if tRoom is empty or tRoom is not among the lines of tIds then
      exit xtcTakeRoomMessage
   end if
   put "room:" & tRoom into tKey
   xtcAddMessage tKey, pEvent["id"], pEvent["pubkey"], pEvent["created_at"], pEvent["content"], "sent"
end xtcTakeRoomMessage

private function xtcRootTag pEvent
   local tIndex, tCount, tTags, tFirst
   put pEvent["tags"] into tTags
   put the number of elements of tTags into tCount
   repeat with tIndex = 1 to tCount
      if tTags[tIndex][1] is not "e" then
         next repeat
      end if
      if tFirst is empty then
         put tTags[tIndex][2] into tFirst
      end if
      if tTags[tIndex][4] is "root" then
         return tTags[tIndex][2]
      end if
   end repeat
   return tFirst
end xtcRootTag

-- A message goes into its conversation, in time order; one from someone
-- muted, or too long, does not
private command xtcAddMessage pKey, pId, pPk, pAt, pText, pState
   local tMessage, tCount
   if pPk is among the lines of sMuted then
      exit xtcAddMessage
   end if
   if sMsgs[pKey][pId] is an array then
      exit xtcAddMessage
   end if
   if the number of chars of pText > kMaxMessageChars then
      put char 1 to kMaxMessageChars of pText & " ..." into pText
   end if
   -- (a time in the future would keep a message last for good)
   if pAt > nxUnixNow() + 60 then
      put nxUnixNow() into pAt
   end if
   put pId into tMessage["id"]
   put pPk into tMessage["pk"]
   put pAt into tMessage["at"]
   put pText into tMessage["text"]
   put pState into tMessage["state"]
   put tMessage into sMsgs[pKey][pId]
   -- The oldest are let go once there are too many
   put the number of elements of sMsgs[pKey] into tCount
   if tCount > kKeepMessages then
      xtcTrim pKey
   end if
   if pPk is not sId["pk"] and pKey is not sLooking then
      add 1 to sUnread[pKey]
   end if
   if sPeople[pPk]["asked"] is empty and sPeople[pPk]["name"] is empty then
      put "due" into sPeople[pPk]["asked"]
   end if
   xtcChanged "messages", pKey
end xtcAddMessage

-- Keeps the newest kKeepMessages of a conversation
private command xtcTrim pKey
   local tList, tId, tCount, tLine
   repeat for each key tId in sMsgs[pKey]
      put sMsgs[pKey][tId]["at"] & tab & tId & return after tList
   end repeat
   sort lines of tList descending numeric by item 1 of each
   put 0 into tCount
   set the itemDelimiter to tab
   repeat for each line tLine in tList
      add 1 to tCount
      if tCount > kKeepMessages then
         delete variable sMsgs[pKey][item 2 of tLine]
      end if
   end repeat
end xtcTrim

-- A presence note: who is online. "hello" is someone who just came, who
-- asks for the others' notes, which they send soon after (a few seconds
-- apart, so that a room of people does not answer at once).
private command xtcTakePresence pEvent
   local tPk, tStatus, tName, tClient
   put pEvent["pubkey"] into tPk
   put nxJsonGet(pEvent["content"], "status") into tStatus
   put nxJsonGet(pEvent["content"], "name") into tName
   put nxJsonGet(pEvent["content"], "client") into tClient
   if tPk is sId["pk"] then
      exit xtcTakePresence
   end if
   if tName is not empty then
      put xtcCleanName(tName) into sPeople[tPk]["name"]
   end if
   put char 1 to 40 of xtcOneLine(tClient) into sPeople[tPk]["client"]
   if tStatus is "offline" then
      put empty into sPeople[tPk]["seen"]
   else
      put min(nxUnixNow(), pEvent["created_at"]) into sPeople[tPk]["seen"]
      if pEvent["created_at"] < nxUnixNow() - kOnlineSeconds then
         put empty into sPeople[tPk]["seen"]
      end if
   end if
   if tStatus is "hello" and sOnline is true then
      send ("xtcAnswerHello" && sGen) to me in (1000 + random(4000)) milliseconds
   end if
   xtcChanged "people"
end xtcTakePresence

on xtcAnswerHello pGen
   if pGen is not sGen or sOnline is not true then
      exit xtcAnswerHello
   end if
   xtcPublishPresence "online"
end xtcAnswerHello

private command xtcTakeProfile pEvent
   local tProfile, tName
   put nxMetadataParse(pEvent) into tProfile
   put tProfile["display_name"] into tName
   if tName is empty then
      put tProfile["name"] into tName
   end if
   if tName is empty then
      exit xtcTakeProfile
   end if
   -- (the newest profile wins; a presence note's name is as good)
   if pEvent["created_at"] < sPeople[pEvent["pubkey"]]["profileAt"] then
      exit xtcTakeProfile
   end if
   put pEvent["created_at"] into sPeople[pEvent["pubkey"]]["profileAt"]
   put xtcCleanName(tName) into sPeople[pEvent["pubkey"]]["name"]
   xtcChanged "people"
   xtcChanged "messages"
end xtcTakeProfile

-- The profiles (names) of the people whose messages came and who have
-- not said their name yet, asked for once
private command xtcAskProfiles
   local tPk, tAuthors, tFilter, tCount, tUrl
   put 0 into tCount
   repeat for each key tPk in sPeople
      if sPeople[tPk]["asked"] is "due" then
         put tPk & return after tAuthors
         put "asked" into sPeople[tPk]["asked"]
         add 1 to tCount
      end if
   end repeat
   if tCount is 0 then
      exit xtcAskProfiles
   end if
   delete the last char of tAuthors
   put kKindMetadata into tFilter["kinds"]
   put tAuthors into tFilter["authors"]
   put tCount * 2 into tFilter["limit"]
   repeat for each line tUrl in sRelayUrls
      if sRelayState[tUrl] is "open" then
         nxrSubscribe sRelayHandle[tUrl], "xtc-names-" & sGen & "-" & the milliseconds, nxFilterBuild(tFilter)
      end if
   end repeat
end xtcAskProfiles

-- A private message: the wrap (kind 1059, from a key used once) holds a
-- seal (kind 13, signed by the writer), which holds the message (kind 14,
-- not signed: the seal's signature is what says who wrote it)
private command xtcTakeWrap pEvent
   local tSealJson, tSeal, tRumorJson, tRumor, tOther, tTo
   put nxNip44Decrypt(sId["sk"], pEvent["pubkey"], pEvent["content"]) into tSealJson
   if tSealJson is empty then
      exit xtcTakeWrap
   end if
   put nxEventFromJson(tSealJson) into tSeal
   if tSeal["kind"] is not kKindSeal or not nxEventVerify(tSeal) then
      exit xtcTakeWrap
   end if
   put nxNip44Decrypt(sId["sk"], tSeal["pubkey"], tSeal["content"]) into tRumorJson
   if tRumorJson is empty then
      exit xtcTakeWrap
   end if
   put nxEventFromJson(tRumorJson) into tRumor
   -- The message must be the seal's writer's: NIP-17's check against a
   -- seal of one person around a message that claims another
   if tRumor["kind"] is not kKindPrivate or tRumor["pubkey"] is not tSeal["pubkey"] then
      exit xtcTakeWrap
   end if
   if tRumor["id"] is empty or nxEventId(tRumor) is not tRumor["id"] then
      exit xtcTakeWrap
   end if
   put nxTagFirst(tRumor, "p") into tTo
   if tSeal["pubkey"] is sId["pk"] then
      -- (the copy of a message this user sent, from another computer)
      put tTo into tOther
   else
      put tSeal["pubkey"] into tOther
      if tTo is not sId["pk"] then
         exit xtcTakeWrap
      end if
   end if
   if not nxIsHex(tOther, 64) then
      exit xtcTakeWrap
   end if
   -- The message's own id: the two wraps of one message (the other
   -- person's and this user's copy) are one message
   if sSeen["rumor:" & tRumor["id"]] is true then
      exit xtcTakeWrap
   end if
   put true into sSeen["rumor:" & tRumor["id"]]
   xtcAddMessage "dm:" & tOther, tRumor["id"], tRumor["pubkey"], tRumor["created_at"], tRumor["content"], "sent"
   if sPeople[tOther]["asked"] is "due" then
      xtcAskProfiles
   end if
end xtcTakeWrap

-- What a relay said about an event this user sent
private command xtcTakeVerdict pId, pVerdict, pUrl
   local tOk, tReason, tKey
   if sPending[pId] is not an array then
      exit xtcTakeVerdict
   end if
   set the itemDelimiter to tab
   put item 1 of pVerdict into tOk
   put item 2 to -1 of pVerdict into tReason
   put sPending[pId]["key"] into tKey
   if tOk is "true" then
      xtcSetState tKey, sPending[pId]["message"], "sent"
      delete variable sPending[pId]
   else
      put tReason into sPending[pId]["refused"][pUrl]
      if the number of elements of sPending[pId]["refused"] >= sPending[pId]["relays"] then
         xtcSetState tKey, sPending[pId]["message"], "failed"
         xtcChanged "notice", "The relays did not take your message:" && tReason
         delete variable sPending[pId]
      end if
   end if
end xtcTakeVerdict

private command xtcSetState pKey, pId, pState
   if sMsgs[pKey][pId] is an array then
      put pState into sMsgs[pKey][pId]["state"]
      xtcChanged "messages", pKey
   end if
end xtcSetState

-- Twelve seconds on, a message no relay has taken is shown as not sent
on xtcSendTimeout pGen, pId
   if pGen is not sGen or sPending[pId] is not an array then
      exit xtcSendTimeout
   end if
   xtcSetState sPending[pId]["key"], sPending[pId]["message"], "failed"
   delete variable sPending[pId]
end xtcSendTimeout

--------------------------------------------------------------------------------
-- What goes out

-- Sends pText to the conversation pKey. Empty, or why not.
command xtcSend pKey, pText
   put xtcTrimText(pText) into pText
   if pText is empty then
      return "There is nothing to send."
   end if
   if the number of chars of pText > kMaxMessageChars then
      return "That message is too long: a message can have" && kMaxMessageChars && "characters."
   end if
   if sOnline is not true then
      return "You are offline."
   end if
   if xtcOpenRelayCount() is 0 then
      return "No relay is connected yet. Try again in a moment."
   end if
   if pKey begins with "room:" then
      xtcSendToRoom char 6 to -1 of pKey, pText
   else if pKey begins with "dm:" then
      xtcSendPrivate char 4 to -1 of pKey, pText
   else
      return "There is no such conversation."
   end if
   return the result
end xtcSend

-- Takes the empty lines and the spaces off both ends
private function xtcTrimText pText
   repeat while pText is not empty and (char 1 of pText is return or char 1 of pText is space or char 1 of pText is tab)
      delete char 1 of pText
   end repeat
   repeat while pText is not empty and (char -1 of pText is return or char -1 of pText is space or char -1 of pText is tab)
      delete char -1 of pText
   end repeat
   return pText
end xtcTrimText

private command xtcSendToRoom pRoom, pText
   local tTags, tEvent
   put "e" into tTags[1][1]
   put pRoom into tTags[1][2]
   put empty into tTags[1][3]
   put "root" into tTags[1][4]
   put nxEventBuild(kKindChannelMessage, pText, tTags, empty) into tEvent
   put nxEventSign(tEvent, sId["sk"], empty) into tEvent
   if tEvent["sig"] is empty then
      return "Your message could not be signed:" && nxLastError()
   end if
   put true into sSeen[tEvent["id"]]
   xtcAddMessage "room:" & pRoom, tEvent["id"], sId["pk"], tEvent["created_at"], pText, "pending"
   xtcPublishTracked tEvent, "room:" & pRoom, tEvent["id"]
   return empty
end xtcSendToRoom

-- NIP-17: one wrap for the other person and one for this user's own copy
-- (so another computer of the user's shows what was sent)
private command xtcSendPrivate pTo, pText
   local tRumor, tRumorJson, tTags, tWrapThem, tWrapMe
   if not nxIsHex(pTo, 64) then
      return "That is not someone this chat can write to."
   end if
   if not xtcCanMessagePrivately() then
      return "Private messages need SodiumXT 1.0.20 or newer (its ChaCha20 cipher)."
   end if
   put "p" into tTags[1][1]
   put pTo into tTags[1][2]
   put nxEventBuild(kKindPrivate, pText, tTags, empty) into tRumor
   put sId["pk"] into tRumor["pubkey"]
   put nxEventId(tRumor) into tRumor["id"]
   if tRumor["id"] is empty then
      return "Your message could not be made:" && nxLastError()
   end if
   put xtcRumorJson(tRumor) into tRumorJson
   put xtcWrap(tRumorJson, pTo) into tWrapThem
   put xtcWrap(tRumorJson, sId["pk"]) into tWrapMe
   if tWrapThem["sig"] is empty or tWrapMe["sig"] is empty then
      return "Your message could not be sealed:" && nxLastError()
   end if
   put true into sSeen[tWrapThem["id"]]
   put true into sSeen[tWrapMe["id"]]
   put true into sSeen["rumor:" & tRumor["id"]]
   xtcAddMessage "dm:" & pTo, tRumor["id"], sId["pk"], tRumor["created_at"], pText, "pending"
   xtcPublishTracked tWrapThem, "dm:" & pTo, tRumor["id"]
   get xtcPublishAll(tWrapMe)
   return empty
end xtcSendPrivate

-- The message as JSON: the event's form without "sig" (NIP-59: a rumor is
-- not signed)
private function xtcRumorJson pRumor
   local tJson
   put empty into pRumor["sig"]
   put nxEventToJson(pRumor) into tJson
   replace ("," & quote & "sig" & quote & ":" & quote & quote) with empty in tJson
   return tJson
end xtcRumorJson

-- The seal and the wrap of a message for pTo
private function xtcWrap pRumorJson, pTo
   local tSeal, tSealJson, tWrapKey, tWrap, tTags, tCipher
   put nxNip44Encrypt(sId["sk"], pTo, pRumorJson, empty) into tCipher
   if tCipher is empty then
      return empty
   end if
   put nxEventBuild(kKindSeal, tCipher, empty, xtcJitteredNow()) into tSeal
   put nxEventSign(tSeal, sId["sk"], empty) into tSeal
   put nxEventToJson(tSeal) into tSealJson
   put nxKeyGenerate() into tWrapKey
   if tWrapKey is empty or tSealJson is empty then
      return empty
   end if
   put nxNip44Encrypt(tWrapKey, pTo, tSealJson, empty) into tCipher
   if tCipher is empty then
      return empty
   end if
   put "p" into tTags[1][1]
   put pTo into tTags[1][2]
   put nxEventBuild(kKindWrap, tCipher, tTags, xtcJitteredNow()) into tWrap
   return nxEventSign(tWrap, tWrapKey, empty)
end xtcWrap

private function xtcJitteredNow
   return nxUnixNow() - random(kWrapJitter)
end xtcJitteredNow

-- Publishes to every open relay, and keeps track of whether one takes it
private command xtcPublishTracked pEvent, pKey, pMessage
   local tCount
   put xtcPublishAll(pEvent) into tCount
   put pKey into sPending[pEvent["id"]]["key"]
   put pMessage into sPending[pEvent["id"]]["message"]
   put tCount into sPending[pEvent["id"]]["relays"]
   send ("xtcSendTimeout" && sGen & comma & pEvent["id"]) to me in kSendTimeout seconds
end xtcPublishTracked

-- Publishes to every open relay; how many it went to
private function xtcPublishAll pEvent
   local tUrl, tCount
   put 0 into tCount
   repeat for each line tUrl in sRelayUrls
      if sRelayState[tUrl] is "open" then
         nxrPublish sRelayHandle[tUrl], pEvent
         if the result is empty then
            add 1 to tCount
         end if
      end if
   end repeat
   return tCount
end xtcPublishAll

private function xtcPresenceEvent pStatus
   local tContent, tTags
   put "{" & quote & "name" & quote & ":" & quote & nxJsonEscape(sId["name"]) & quote into tContent
   put "," & quote & "status" & quote & ":" & quote & pStatus & quote after tContent
   if sShowClient is true then
      put "," & quote & "client" & quote & ":" & quote & nxJsonEscape(xtcClientName()) & quote after tContent
   end if
   put "}" after tContent
   put "t" into tTags[1][1]
   put kPresenceTag into tTags[1][2]
   return nxEventSign(nxEventBuild(kKindPresence, tContent, tTags, empty), sId["sk"], empty)
end xtcPresenceEvent

-- What the presence note calls this IDE when the user lets it: the IDE's
-- version, and the platform
function xtcClientName
   local tVersion, tError
   try
      put revEnvironmentEditionProperty("version") into tVersion
   catch tError
   end try
   if tVersion is empty then
      put the version into tVersion
   end if
   return "OXT-Beyond" && tVersion && "on" && xtcPlatformName()
end xtcClientName

private function xtcPlatformName
   switch the platform
      case "Win32"
         return "Windows"
      case "MacOS"
         return "macOS"
      case "Linux"
         return "Linux"
   end switch
   return the platform
end xtcPlatformName

private command xtcPublishPresence pStatus
   local tEvent
   put xtcPresenceEvent(pStatus) into tEvent
   if tEvent["sig"] is not empty then
      get xtcPublishAll(tEvent)
   end if
end xtcPublishPresence

private command xtcPublishPresenceTo pRelay, pStatus
   local tEvent
   put xtcPresenceEvent(pStatus) into tEvent
   if tEvent["sig"] is not empty then
      nxrPublish pRelay, tEvent
   end if
end xtcPublishPresenceTo

private function xtcProfileEvent
   return nxEventSign(nxMetadataBuild(sId["name"], "Talks about xTalk in xTalk Chat, OXT-Beyond's chat.", empty, empty), sId["sk"], empty)
end xtcProfileEvent

-- The profile (kind 0) is written only for a key this chat made: one the
-- user brought keeps its own, and the name goes in the presence notes
private command xtcPublishProfile
   local tEvent
   if sId["made"] is not "here" then
      exit xtcPublishProfile
   end if
   put xtcProfileEvent() into tEvent
   if tEvent["sig"] is not empty then
      get xtcPublishAll(tEvent)
   end if
end xtcPublishProfile

private command xtcPublishProfileTo pRelay
   local tEvent
   if sId["made"] is not "here" then
      exit xtcPublishProfileTo
   end if
   put xtcProfileEvent() into tEvent
   if tEvent["sig"] is not empty then
      nxrPublish pRelay, tEvent
   end if
end xtcPublishProfileTo

-- Every 45 seconds while online: the presence note
on xtcBeat pGen
   if pGen is not sGen or sOnline is not true then
      exit xtcBeat
   end if
   xtcPublishPresence "online"
   send ("xtcBeat" && sGen) to me in kBeatSeconds seconds
end xtcBeat

-- Every 15 seconds: whoever has not been heard from is no longer online
on xtcSweep pGen
   local tPk, tChanged, tNow
   if pGen is not sGen or sOnline is not true then
      exit xtcSweep
   end if
   put nxUnixNow() into tNow
   repeat for each key tPk in sPeople
      if sPeople[tPk]["seen"] is not empty and sPeople[tPk]["seen"] < tNow - kOnlineSeconds then
         put empty into sPeople[tPk]["seen"]
         put true into tChanged
      end if
   end repeat
   if tChanged is true then
      xtcChanged "people"
   end if
   send ("xtcSweep" && sGen) to me in 15 seconds
end xtcSweep

private command xtcForgetPresence
   local tPk
   repeat for each key tPk in sPeople
      put empty into sPeople[tPk]["seen"]
   end repeat
end xtcForgetPresence

--------------------------------------------------------------------------------
-- What the window reads

-- The messages of the conversation pKey, oldest first: an array 1 to n
function xtcMessages pKey
   local tList, tId, tOut, tCount, tLine
   repeat for each key tId in sMsgs[pKey]
      put sMsgs[pKey][tId]["at"] & tab & tId & return after tList
   end repeat
   sort lines of tList ascending numeric by item 1 of each
   set the itemDelimiter to tab
   put 0 into tCount
   repeat for each line tLine in tList
      if tLine is empty then
         next repeat
      end if
      if sMsgs[pKey][item 2 of tLine]["pk"] is among the lines of sMuted then
         next repeat
      end if
      add 1 to tCount
      put sMsgs[pKey][item 2 of tLine] into tOut[tCount]
   end repeat
   return tOut
end xtcMessages

-- The private conversations, the newest first: one a line, the key, tab,
-- the time of its last message
function xtcPrivateConversations
   local tOut, tKey, tId, tLast
   repeat for each key tKey in sMsgs
      if not (tKey begins with "dm:") then
         next repeat
      end if
      put 0 into tLast
      repeat for each key tId in sMsgs[tKey]
         put max(tLast, sMsgs[tKey][tId]["at"]) into tLast
      end repeat
      put tKey & tab & tLast & return after tOut
   end repeat
   delete the last char of tOut
   set the itemDelimiter to tab
   sort lines of tOut descending numeric by item 2 of each
   return tOut
end xtcPrivateConversations

-- Opens a private conversation with pPk (the window shows it even before
-- a message is in it)
command xtcStartPrivate pPk
   if not nxIsHex(pPk, 64) then
      return "That is not someone this chat can write to."
   end if
   if sMsgs["dm:" & pPk] is not an array then
      put empty into sMsgs["dm:" & pPk]["-"]
      delete variable sMsgs["dm:" & pPk]["-"]
   end if
   return empty
end xtcStartPrivate

-- The people online now, one a line: public key, tab, name, tab, client;
-- by name
function xtcPeopleOnline
   local tOut, tPk
   repeat for each key tPk in sPeople
      if sPeople[tPk]["seen"] is empty or tPk is among the lines of sMuted then
         next repeat
      end if
      put tPk & tab & xtcName(tPk) & tab & sPeople[tPk]["client"] & return after tOut
   end repeat
   delete the last char of tOut
   set the itemDelimiter to tab
   sort lines of tOut ascending text by item 2 of each
   return tOut
end xtcPeopleOnline

function xtcIsPersonOnline pPk
   if pPk is sId["pk"] then
      return sOnline is true
   end if
   return sPeople[pPk]["seen"] is not empty
end xtcIsPersonOnline

-- What to call someone: their name, or the start of their key
function xtcName pPk
   if pPk is sId["pk"] and sId["name"] is not empty then
      return sId["name"]
   end if
   if sPeople[pPk]["name"] is not empty then
      return sPeople[pPk]["name"]
   end if
   return xtcShortKey(pPk)
end xtcName

function xtcClientOf pPk
   if pPk is sId["pk"] then
      if sShowClient is true then
         return xtcClientName()
      end if
      return empty
   end if
   return sPeople[pPk]["client"]
end xtcClientOf

-- The last four hex digits of a key, which tell two people of one name
-- apart
function xtcShortKey pPk
   return "npub..." & char -4 to -1 of pPk
end xtcShortKey

function xtcNpubOf pPk
   return nxNpubEncode(pPk)
end xtcNpubOf

-- A public key from an npub1... (or 64 hex) the user pasted; empty if it
-- is not one
function xtcKeyFromText pText
   local tKey
   put word 1 to -1 of pText into pText
   if pText begins with "nostr:" then
      delete char 1 to 6 of pText
   end if
   if pText begins with "npub1" then
      put nxNpubDecode(pText) into tKey
   else if nxIsHex(pText, 64) then
      put toLower(pText) into tKey
   end if
   return tKey
end xtcKeyFromText

function xtcUnread pKey
   if sUnread[pKey] is empty then
      return 0
   end if
   return sUnread[pKey]
end xtcUnread

-- The window shows pKey: its messages count as read
command xtcLookAt pKey
   put pKey into sLooking
   put 0 into sUnread[pKey]
end xtcLookAt

command xtcMute pPk
   if pPk is empty or pPk is sId["pk"] or pPk is among the lines of sMuted then
      exit xtcMute
   end if
   if sMuted is empty then
      put pPk into sMuted
   else
      put return & pPk after sMuted
   end if
   xtcChanged "people"
   xtcChanged "messages"
end xtcMute

command xtcUnmute pPk
   local tOut, tLine
   repeat for each line tLine in sMuted
      if tLine is not pPk and tLine is not empty then
         put tLine & return after tOut
      end if
   end repeat
   delete the last char of tOut
   put tOut into sMuted
   xtcChanged "people"
   xtcChanged "messages"
end xtcUnmute

-- (the list comes from the preferences: only keys are kept)
command xtcSetMuted pList
   local tLine, tOut
   repeat for each line tLine in pList
      put toLower(word 1 of tLine) into tLine
      if matchText(tLine, "^[0-9a-f]{64}$") and tLine is not among the lines of tOut then
         put tLine & return after tOut
      end if
   end repeat
   delete the last char of tOut
   put tOut into sMuted
end xtcSetMuted

function xtcMuted
   return sMuted
end xtcMuted

--------------------------------------------------------------------------------
-- Telling the window

-- Changes are told 60 milliseconds after the first of them, once each
command xtcChanged pWhat, pKey
   put true into sChanged[pWhat][pKey]
   if sTellDue is not true then
      put true into sTellDue
      send "xtcTell" to me in 60 milliseconds
   end if
end xtcChanged

on xtcTell
   xtcTellNow
end xtcTell

private command xtcTellNow
   local tChanged, tWhat, tKey, tError
   put false into sTellDue
   put sChanged into tChanged
   put empty into sChanged
   if sObserver is empty or there is no sObserver then
      exit xtcTellNow
   end if
   repeat for each item tWhat in "status,rooms,people,messages,notice"
      if tChanged[tWhat] is not an array then
         next repeat
      end if
      repeat for each key tKey in tChanged[tWhat]
         try
            dispatch "xtalkChatChanged" to sObserver with tWhat, tKey
         catch tError
         end try
      end repeat
   end repeat
end xtcTellNow
