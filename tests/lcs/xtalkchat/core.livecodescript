script "TestXTalkChatCore"
-- OXT-Beyond: tests of xTalk Chat's core
-- (ide/Extensions/org.openxtalk.plugin.xtalkchat/xtalkchat-core.livecodescript),
-- with no relay and no network.
--
-- The core rests on the xTalk Suite's NostrXT, CoinXT and SodiumXT, which
-- OXT-Beyond's packages carry in their Extensions folder but a source
-- checkout does not. Without them the tests check that the core says what
-- is missing and opens nothing. With them (XTALK_SUITE_EXTENSIONS set to an
-- installed OXT-Beyond's Extensions folder) they also check the rooms'
-- signed events, the identity file, and reading keys and names.

constant kCoreFile = "/Extensions/org.openxtalk.plugin.xtalkchat/xtalkchat-core.livecodescript"

-- The folder the identity goes in for the tests, and whether the suite
-- could be loaded
local sHome, sSuite

on TestSetup
   start using stack (TestGetIDERepositoryPath() & kCoreFile)
   put the tempName into sHome
   create folder sHome
   put sHome into $XTALK_CHAT_HOME
   put TestLoadSuite() into sSuite
end TestSetup

on TestTearDown
   local tFile
   try
      xtcGoOffline
      xtcIdentityForget
   catch tError
   end try
   repeat for each line tFile in files(sHome)
      delete file (sHome & slash & tFile)
   end repeat
   delete folder sHome
end TestTearDown

-- The suite's libraries from $XTALK_SUITE_EXTENSIONS, as the IDE loads
-- them; true when all of them loaded
private function TestLoadSuite
   local tE, tCode, tError
   put $XTALK_SUITE_EXTENSIONS into tE
   if tE is empty or there is not a folder tE then
      return false
   end if
   switch the platform
      case "Win32"
         put "x86_64-win32" into tCode
         break
      case "MacOS"
         put "universal-mac" into tCode
         break
      default
         put "x86_64-linux" into tCode
   end switch
   try
      set the revLibraryMapping["sodiumxt"] to tE & "/org.openxtalk.library.sodium/code/" & tCode & "/" & TestLibName("sodiumxt")
      set the revLibraryMapping["coinxt"] to tE & "/org.openxtalk.library.coin/code/" & tCode & "/" & TestLibName("coinxt")
      load extension from file (tE & "/org.openxtalk.library.sodium/module.lcm") with resource path (tE & "/org.openxtalk.library.sodium")
      load extension from file (tE & "/org.openxtalk.library.coin/module.lcm") with resource path (tE & "/org.openxtalk.library.coin")
      start using stack (tE & "/coinxt/coinxt.livecodescript")
      start using stack (tE & "/nostrxt/nostrxt.livecodescript")
      start using stack (tE & "/nostr-relay/nostr-relay.livecodescript")
   catch tError
      return false
   end try
   return xtcMissing() is empty
end TestLoadSuite

private function TestLibName pName
   switch the platform
      case "Win32"
         return pName & ".dll"
      case "MacOS"
         return pName & ".dylib"
      default
         return pName & ".so"
   end switch
end TestLibName

-- A file's permissions in sHome, in octal
private function TestPermissions pName
   local tLine, tFiles
   put files(sHome, "detailed") into tFiles
   repeat for each line tLine in tFiles
      if urlDecode(item 1 of tLine) is pName then
         return item 10 of tLine
      end if
   end repeat
   return empty
end TestPermissions

private function TestNeedsSuite pTest
   if sSuite is not true then
      TestSkip pTest, "the xTalk Suite extensions are not loaded (XTALK_SUITE_EXTENSIONS)"
      return false
   end if
   return true
end TestNeedsSuite

--------------------------------------------------------------------------------
-- Without the suite, or before anything is set up

on TestNothingOnlineAtFirst
   TestAssert "offline", xtcIsOnline() is false
   TestAssert "no relays", xtcRelayStatus() is empty and xtcOpenRelayCount() is 0
   TestAssert "no identity", xtcHasIdentity() is false and xtcMyKey() is empty
   TestAssert "no one online", xtcPeopleOnline() is empty
end TestNothingOnlineAtFirst

on TestFolderFromEnvironment
   TestAssert "the folder", xtcFolder() is sHome
   TestAssert "the identity file in it", xtcIdentityFile() is (sHome & "/identity.txt")
end TestFolderFromEnvironment

on TestDefaultRelaysAreSecure
   local tLine, tAll
   put true into tAll
   repeat for each line tLine in xtcDefaultRelays()
      if not (tLine begins with "wss://") then
         put false into tAll
      end if
   end repeat
   TestAssert "two relays at least", the number of lines of xtcDefaultRelays() >= 2
   TestAssert "all wss://", tAll
end TestDefaultRelaysAreSecure

on TestCleanName
   TestAssert "trimmed", xtcCleanName("  Ada  ") is "Ada"
   TestAssert "one line", xtcCleanName("Ada" & return & "Lovelace") is "Ada Lovelace"
   TestAssert "at most 32 characters", the number of chars of xtcCleanName(format("%040d", 0)) is 32
   TestAssert "never empty", xtcCleanName(empty) is "Someone"
end TestCleanName

on TestGoOnlineNeedsWhatIsMissing
   if sSuite is true then
      TestSkip "without the suite", "the suite is loaded"
      exit TestGoOnlineNeedsWhatIsMissing
   end if
   TestAssert "says what is missing", xtcMissing() contains "NostrXT"
   xtcGoOnline "wss://relay.invalid"
   TestAssert "refused, with the reason", the result is xtcMissing()
   TestAssert "still offline", xtcIsOnline() is false and xtcRelayStatus() is empty
end TestGoOnlineNeedsWhatIsMissing

on TestNoMessagesOffline
   local tMsgs
   put xtcMessages("room:nothing") into tMsgs
   TestAssert "an empty list", the number of elements of tMsgs is 0
   TestAssert "nothing unread", xtcUnread("room:nothing") is 0
end TestNoMessagesOffline

--------------------------------------------------------------------------------
-- With the suite

-- The rooms are signed kind-40 events, carried in the core: each verifies,
-- and the room's key is its event's id
on TestRoomsAreSignedChannels
   local tLine, tEvent, tOk, tRooms, tIds
   if not TestNeedsSuite("the rooms") then
      exit TestRoomsAreSignedChannels
   end if
   put true into tOk
   repeat for each line tLine in xtcRoomEvents()
      put nxEventFromJson(tLine) into tEvent
      if tEvent["kind"] is not 40 or not nxEventVerify(tEvent) then
         put false into tOk
      end if
      put tEvent["id"] & return after tIds
   end repeat
   TestAssert "each verifies", tOk
   put xtcRooms() into tRooms
   TestAssert "three rooms", the number of lines of tRooms is 3
   set the itemDelimiter to tab
   TestAssert "the lobby first", item 2 of line 1 of tRooms is "xTalk Lobby"
   TestAssert "keyed by the event", item 1 of line 1 of tRooms is ("room:" & line 1 of tIds)
end TestRoomsAreSignedChannels

on TestIdentityRoundTrip
   local tPk, tText
   if not TestNeedsSuite("the identity") then
      exit TestIdentityRoundTrip
   end if
   xtcIdentityCreate "Ada", empty
   TestAssert "made", the result is empty and xtcHasIdentity()
   put xtcMyKey() into tPk
   TestAssert "a public key", nxIsHex(tPk, 64)
   TestAssert "the name", xtcMyName() is "Ada"
   TestAssert "an npub", xtcMyNpub() begins with "npub1" and nxNpubDecode(xtcMyNpub()) is tPk
   TestAssert "written", there is a file xtcIdentityFile()
   put URL ("file:" & xtcIdentityFile()) into tText
   TestAssert "made here", tText contains "made: here"
   if the platform is not "Win32" then
      TestAssert "only the user reads it", TestPermissions("identity.txt") is "600"
   end if
   -- Read back as a new session would
   TestAssert "loads", xtcIdentityLoad() and xtcMyKey() is tPk and xtcMyName() is "Ada"
end TestIdentityRoundTrip

-- A key the user brings: nsec or hex, and nothing else
on TestBringingAKey
   local tSk, tPk
   if not TestNeedsSuite("bringing a key") then
      exit TestBringingAKey
   end if
   put nxKeyGenerate() into tSk
   put nxKeyPublic(tSk) into tPk
   xtcIdentityCreate "Grace", nxNsecEncode(tSk)
   TestAssert "an nsec", the result is empty and xtcMyKey() is tPk
   TestAssert "brought, so its profile is left alone", URL ("file:" & xtcIdentityFile()) contains "made: brought"
   xtcIdentityCreate "Grace", toUpper(tSk)
   TestAssert "hex", the result is empty and xtcMyKey() is tPk
   xtcIdentityCreate "Grace", "nsec1notakey"
   TestAssert "a bad nsec is refused", the result is not empty and xtcMyKey() is tPk
   xtcIdentityCreate "Grace", "hello"
   TestAssert "text is refused", the result is not empty
end TestBringingAKey

on TestKeyFromText
   local tSk, tPk
   if not TestNeedsSuite("keys from text") then
      exit TestKeyFromText
   end if
   put nxKeyPublic(nxKeyGenerate()) into tPk
   TestAssert "an npub", xtcKeyFromText(nxNpubEncode(tPk)) is tPk
   TestAssert "an npub with nostr:", xtcKeyFromText("nostr:" & nxNpubEncode(tPk)) is tPk
   TestAssert "hex", xtcKeyFromText(toUpper(tPk)) is tPk
   TestAssert "not a key", xtcKeyFromText("bob") is empty
   TestAssert "a short name for a stranger", xtcShortKey(tPk) is ("npub..." & char -4 to -1 of tPk) and xtcName(tPk) is xtcShortKey(tPk)
end TestKeyFromText

on TestMuting
   local tPk
   if not TestNeedsSuite("muting") then
      exit TestMuting
   end if
   put nxKeyPublic(nxKeyGenerate()) into tPk
   xtcMute tPk
   TestAssert "muted", tPk is among the lines of xtcMuted()
   xtcUnmute tPk
   TestAssert "unmuted", tPk is not among the lines of xtcMuted()
   xtcSetMuted tPk & return & "not a key"
   TestAssert "only keys are kept", xtcMuted() is tPk
   xtcSetMuted empty
end TestMuting
