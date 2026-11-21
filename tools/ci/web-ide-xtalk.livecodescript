script "oxtwebxtalk"
-- The xTalk Suite's native libraries in the web IDE (EXPERIMENTAL): a
-- tour for tools/ci/web_ide_tour.py --tour, which puts this file into a
-- copy of the site's ide.zip as a script library extension, as it does
-- web-ide-tour.livecodescript, and speaks the same lines with the page
-- (that file's header lists them). Run with --relay (a Nostr relay of
-- nostr_test_relay.py on 127.0.0.1, given as window.oxtTour.relay) and
-- with Hold'em's and the platformer's scripts added beside it (--add):
--
--    python3 tools/ci/web_ide_tour.py --site SITE --out OUT \
--       --tour tools/ci/web-ide-xtalk.livecodescript --relay \
--       --add <suite>/holde-em/src/holdem.livecodescript \
--       --add <suite>/box2dxt/examples/box2dxt-platformer.livecodescript \
--       --add <suite>/datachannelxt/tests/datachannel-selftest.livecodescript \
--       --replace boot/Extensions/nostr-relay/nostr-relay.livecodescript=<suite>/nostrxt/src/nostr-relay.livecodescript
--
-- The web IDE's engine links SodiumXT, Box2Dxt, box3dxt, CoinXT,
-- DataChannelXT (a shim over the browser's WebRTC) and audioxt into itself
-- (engine/src/em-xtalk-web.cpp), and the extensions the IDE ships call
-- them unchanged. Each step calls one of them, or an app built on them,
-- as a user's script does, and checks what comes back against a value
-- known from elsewhere (a published test vector, or what the desktop
-- gives):
--    sodium      SodiumXT: its version, BLAKE2b-256 of "abc", secretbox,
--                signatures, and its Boolean results (the CBool fix)
--    pwhash      sxPwHash: the interactive preset derives a key; the
--                moderate and sensitive ones (256 MB and 1 GB) either
--                derive one or refuse with an error the script can catch,
--                and the library still works after
--    box2d       Box2Dxt: a ball dropped for 60 steps of 1/60 s
--    box3d       box3dxt: a ball dropped onto a floor, found by a ray, and
--                drawn by the library's renderer into a picture whose
--                middle pixel shows it; the picture set as an image's
--                imageData
--    coinxt      CoinXT: SHA-256, Keccak-256, a public key and BIP-340's
--                first vector
--    nostr       NostrXT's relay library over the browser's WebSocket:
--                connect to the local relay, subscribe, publish a signed
--                event, have it accepted and delivered back
--    chat        xTalk Chat: its window opens; an identity, online at the
--                local relay, a room message and a private message to
--                oneself (NIP-17, SodiumXT's cipher) each come back
--    holdem      Hold'em (holde-em/src/holdem.livecodescript): the table
--                opens, and its whole self-test (hotseat hands included)
--                runs with nothing failing
--    platformer  The Box2Dxt platformer: the title, then level 1 built
--                and playing
--    datachannel DataChannelXT over the browser's RTCPeerConnection: its
--                own harness (datachannelxt/tests/datachannel-selftest.
--                livecodescript, --add) runs to its summary, the live
--                in-page loopback included, with nothing failing
--    audio       audioxt: a tone mixed with no device, its samples the
--                desktop's bit for bit, made into a WAV file and read
--                back the same; then the browser's own playback device
--                opened (or refused with a reason: nothing may throw)
--                and everything closed
--    unavailable TorrentXT and ENetXT, which need raw TCP and UDP that a
--                page cannot open, are not in the web engine: a call to
--                each throws an error the script can catch, and the IDE
--                goes on; OnionXT's pure-script half works, and it cannot
--                reach a tor daemon
-- A step that throws fails; a step whose app is not beside this file (no
-- --add) or that has no relay (no --relay) fails as well, so that a
-- check that ran nothing cannot pass.

/**
Title: Web IDE xTalk Suite check (CI)
Author: OXT-Beyond contributors
Description:
Runs the xTalk Suite's libraries and apps in the web IDE for its CI job
(tools/ci/web_ide_tour.py --tour). Only CI's copy of the site has it.
*/

constant kSteps = "start,sodium,pwhash,box2d,box3d,coinxt,nostr,chat,holdem,platformer,datachannel,audio,unavailable"
constant kBlake2bAbc = "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319"
constant kSha256Abc = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
constant kKeccakEmpty = "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
-- SHA-1 of audioxt's mix of a 440 Hz sine of amplitude 0.5, 800 frames
-- of 16-bit stereo at 8000 Hz: the desktop's (OXT-Beyond 0.2.7-rc.6's
-- server engine, Linux x86-64), which the WebAssembly build gives too
constant kAudioMixSha1 = "6057c40db065f7ab02a05917470c3423288100f4"
constant kSecp256k1G = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
-- BIP-340's test vector 0
constant kBip340Pub = "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
constant kBip340Sig = "e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0"
constant kHoldem = "oxtWebHoldem"
constant kPlatformer = "oxtWebPlatformer"
constant kDataChannel = "oxtWebDataChannel"
-- The Tor Project's onion address, and the same with its first letter
-- changed (its checksum then fails)
constant kOnionGood = "2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion"
constant kOnionBad = "3gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion"

local sStarted, sAct, sWatchdog, sFlag, sNostr

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   if sStarted is not true and tourJS("typeof window.oxtTour") is "object" then
      put true into sStarted
      send "tourWhenStarted 0" to me in 1 second
   end if
end extensionInitialize

on tourWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then
      put the cREVLaunching of stack "Home" into tLaunching
   end if
   if (tLaunching is true or tourJS("window.oxtTour.go") is not "true") and pTries < 600 then
      send "tourWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "tourRun" to me in 2 seconds
   end if
end tourWhenStarted

on tourRun
   local tStep, tHandler, tError, tOnly
   put 0 into sAct
   put tourJS("window.oxtTour.only") into tOnly
   tourRecord "STARTED"
   tourRecord "INFO version" && the version && the buildNumber
   tourRecord "INFO platform" && the platform && the environment
   tourRecord "INFO loadedExtensions" && tourJoin(the loadedExtensions)
   tourCatchErrors
   repeat for each item tStep in kSteps
      if tOnly is not empty and tStep is not among the items of tOnly then
         next repeat
      end if
      put "xt_" & tStep into tHandler
      send "tourWatchdog" && quote & tStep & quote to me in 60 seconds
      put the result into sWatchdog
      try
         dispatch tHandler to me
         tourRecord "STEP" && tStep && "ok"
      catch tError
         tourRecord "STEP" && tStep && "FAILED" && tourJoin(tError)
      end try
      cancel sWatchdog
      tourCloseDialogs
   end repeat
   tourRecord "DONE"
end tourRun

command tourCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      put the defaultStack into tDefault
      set the defaultStack to "oxtwebxtalk"
      lock messages
      create invisible button "oxt_web_xtalk_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "tourScriptError" & quote & " to stack " & quote & "oxtwebxtalk" & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      tourRecord "INFO catching errors:" && tourJoin(tError)
   end try
end tourCatchErrors

on tourScriptError pError
   tourRecord "ERROR" && tourJoin(pError)
end tourScriptError

----------------------------------------------------------------
-- Steps

on xt_start
   tourShot "x01-ide"
end xt_start

on xt_sodium
   local tKey, tBox, tPk, tSk, tSig
   sxInit
   tourRecord "INFO sxVersion()" && sxVersion()
   xtExpect "BLAKE2b-256 of abc", sxBin2Hex(sxHash("abc", 32)), kBlake2bAbc
   put sxRandomBytes(32) into tKey
   xtExpect "sxRandomBytes(32)", the number of bytes of tKey, 32
   put sxSecretBox(textEncode("hello web", "UTF-8"), tKey) into tBox
   xtExpect "the box's length", the number of bytes of tBox, 49
   xtExpect "secretbox round trip", textDecode(sxSecretBoxOpen(tBox, tKey), "UTF-8"), "hello web"
   sxSignKeypair tPk, tSk
   xtExpect "the signing key lengths", the number of bytes of tPk & comma & the number of bytes of tSk, "32,64"
   put sxSignDetached("message", tSk) into tSig
   -- Boolean results: a 1-byte C bool, which the web engine read wrong
   -- before the CBool fix (libfoundation/src/foundation-ffi-js.cpp)
   xtExpect "a good signature verifies", sxSignVerifyDetached(tSig, "message", tPk), true
   xtExpect "a tampered message does not", sxSignVerifyDetached(tSig, "messagE", tPk), false
   xtExpect "sxMemEqual of equal data", sxMemEqual(tKey, tKey), true
   xtExpect "sxMemEqual of different data", sxMemEqual(tKey, sxRandomBytes(32)), false
end xt_sodium

on xt_pwhash
   local tSalt, tKey, tPreset, tMem, tError, tStart
   put sxRandomBytes(sxPwSaltBytes()) into tSalt
   put sxPwHash(textEncode("correct horse", "UTF-8"), tSalt, 32, "2", sxPwMemInteractive()) into tKey
   xtExpect "an interactive key's length", the number of bytes of tKey, 32
   xtExpect "the same inputs give the same key", sxPwHash(textEncode("correct horse", "UTF-8"), tSalt, 32, "2", sxPwMemInteractive()) is tKey, true
   repeat for each item tPreset in "moderate,sensitive"
      if tPreset is "moderate" then
         put sxPwMemModerate() into tMem
      else
         put sxPwMemSensitive() into tMem
      end if
      put the milliseconds into tStart
      try
         put sxPwHash(textEncode("correct horse", "UTF-8"), tSalt, 32, "3", tMem) into tKey
         tourRecord "INFO the" && tPreset && "preset (" & tMem && "bytes) derived" && the number of bytes of tKey && "bytes in" && the milliseconds - tStart && "ms"
      catch tError
         tourRecord "INFO the" && tPreset && "preset (" & tMem && "bytes) refused in" && the milliseconds - tStart && "ms:" && tourJoin(tError)
      end try
      -- Either way the library, and the engine, still work
      xtExpect "BLAKE2b-256 of abc after the" && tPreset && "preset", sxBin2Hex(sxHash("abc", 32)), kBlake2bAbc
   end repeat
end xt_pwhash

on xt_box2d
   local tWorld, tBody
   tourRecord "INFO b2Version()" && b2Version()
   put b2NewWorld(0, -10, true, true) into tWorld
   put b2NewDynamicBody(tWorld, 0, 10) into tBody
   get b2AddCircle(tBody, 0, 0, 0.5, 1, 0.3, 0)
   repeat 60 times
      b2Step tWorld, 1/60, 4
   end repeat
   -- What Box2D's step gives for one second of free fall from y = 10
   -- (the exact answer is 5), on the desktop as here
   xtExpect "y after 60 steps", format("%.6f", b2BodyY(tBody)), "4.979169"
   xtExpect "vy after 60 steps", format("%.2f", b2BodyVY(tBody)), "-10.00"
   b2DestroyWorld tWorld
end xt_box2d

on xt_box3d
   local tWorld, tFloor, tBall, tShape, tRay, tData, tWas
   tourRecord "INFO b3LibraryVersion()" && b3LibraryVersion()
   xtExpect "the library's ABI", word 1 to 3 of b3LibraryVersion(), "box3dxt ABI 2;"
   put b3WorldCreate(0, -10, 0, 1) into tWorld
   put b3BodyCreate(tWorld, 0, 0, -0.5, 0) into tFloor
   get b3ShapeAddBox(tFloor, 5, 0.5, 5, 0, 0.6, 0)
   put b3BodyCreate(tWorld, 2, 0, 5, 0) into tBall
   put b3ShapeAddSphere(tBall, 0, 0, 0, 0.5, 1, 0.5, 0) into tShape
   repeat 30 times
      b3WorldStep tWorld, 1/60, 4
   end repeat
   -- What Box3D's step gives for half a second of free fall from y = 5
   -- (the exact answer is 3.75), on the desktop as here
   xtExpect "y after 30 steps", format("%.4f", item 2 of b3BodyPosition(tBall)), "3.7396"
   repeat 150 times
      b3WorldStep tWorld, 1/60, 4
   end repeat
   xtExpect "y at rest on the floor", format("%.2f", item 2 of b3BodyPosition(tBall)), "0.50"
   xtExpect "a ray down finds the ball", b3CastRayClosest(tWorld, 0, 10, 0, 0, -20, 0) && (b3HitShape(1) is tShape), "1 true"
   -- The renderer: the ball in its own colour at the middle of the
   -- picture, the background at its corner (the desktop's numbers)
   b3RenderSetCamera 0, 2, 8, 0, 0.5, 0, 50
   b3RenderSetLight 0, 0, -1
   b3RenderSetBackground 32, 36, 42
   b3ShapeSetColor tShape, 200, 100, 50
   xtExpect "a picture is drawn", b3RenderWorld(tWorld, 64, 48, 0), "true"
   put b3RenderPixels() into tData
   xtExpect "the picture's bytes", the number of bytes in tData, 64 * 48 * 4
   xtExpect "the middle pixel shows the ball", b3RenderShapeAt(32, 24) is tShape, "true"
   xtExpect "the corner is the background", b3RenderPixel(0, 0), 32 * 65536 + 36 * 256 + 42
   put b3RenderRay(32.5, 24.5) into tRay
   xtExpect "the ray through that pixel finds it too", b3CastRayClosest(tWorld, item 1 of tRay, item 2 of tRay, item 3 of tRay, \
         50 * item 4 of tRay, 50 * item 5 of tRay, 50 * item 6 of tRay) && (b3HitShape(1) is tShape), "1 true"
   -- An image takes the picture as its imageData and gives it back
   put the defaultStack into tWas
   create invisible stack "oxtWebBox3d"
   set the defaultStack to "oxtWebBox3d"
   create image "picture"
   set the defaultStack to tWas
   set the width of image "picture" of stack "oxtWebBox3d" to 64
   set the height of image "picture" of stack "oxtWebBox3d" to 48
   set the imageData of image "picture" of stack "oxtWebBox3d" to tData
   xtExpect "an image takes the picture", the number of bytes in the imageData of image "picture" of stack "oxtWebBox3d", 64 * 48 * 4
   delete stack "oxtWebBox3d"
   b3WorldDestroy tWorld
end xt_box3d

on xt_coinxt
   local tSec, tSig
   cxCheckABI
   xtExpect "SHA-256 of abc", xtHex(cxSha256("abc")), kSha256Abc
   xtExpect "Keccak-256 of nothing", xtHex(cxKeccak256(empty)), kKeccakEmpty
   put xtBytes("0000000000000000000000000000000000000000000000000000000000000001") into tSec
   xtExpect "the public key of 1", xtHex(cxPublicKey(tSec, true)), kSecp256k1G
   put xtBytes("0000000000000000000000000000000000000000000000000000000000000003") into tSec
   xtExpect "BIP-340 vector 0's public key", xtHex(cxXOnlyPubkey(tSec)), kBip340Pub
   put cxSchnorrSign(tSec, xtBytes(xtZeros(32)), xtBytes(xtZeros(32))) into tSig
   xtExpect "BIP-340 vector 0's signature", xtHex(tSig), kBip340Sig
   xtExpect "it verifies", cxSchnorrVerify(xtBytes(kBip340Pub), xtBytes(xtZeros(32)), tSig), true
   xtExpect "a changed message does not", cxSchnorrVerify(xtBytes(kBip340Pub), xtBytes(xtZeros(31) & "01"), tSig), false
end xt_coinxt

on xt_nostr
   local tUrl, tRelay, tSk, tEvent, tFilter
   put tourJS("window.oxtTour.relay") into tUrl
   if tUrl is empty then
      throw "no relay (web_ide_tour.py --relay)"
   end if
   tourRecord "INFO nxrVersion()" && nxrVersion()
   put empty into sNostr
   nxrInit the long id of me
   nxrConnect tUrl
   put the result into tRelay
   if tRelay is not an integer then
      throw "nxrConnect:" && tRelay
   end if
   nxrSetCallback tRelay, "xtNostrCallback"
   xtWaitNostr "open", 15000
   put "1" into tFilter["kinds"]
   nxrSubscribe tRelay, "web-check", nxFilterBuild(tFilter)
   xtWaitNostr "eose", 10000
   put nxKeyGenerate() into tSk
   if tSk is empty then
      throw "nxKeyGenerate:" && nxLastError()
   end if
   put nxEventSign(nxEventBuild(1, "hello from the web IDE", empty, empty), tSk, empty) into tEvent
   if tEvent is empty then
      throw "nxEventSign:" && nxLastError()
   end if
   nxrPublish tRelay, tEvent
   if the result is not empty then
      throw "nxrPublish:" && the result
   end if
   xtWaitNostr "ok" && tEvent["id"] && "true", 10000
   xtWaitNostr "event" && tEvent["id"], 10000
   nxrDisconnect tRelay
end xt_nostr

-- The relay library's callback (nxrSetCallback): each one a line of
-- sNostr, "<kind> <first argument> <the second's first word>", and for an
-- event its id
on xtNostrCallback pRelay, pKind, pArgOne, pArgTwo
   local tEvent
   if pKind is "event" then
      put nxEventFromJson(pArgTwo) into tEvent
      put "event" && tEvent["id"] & return after sNostr
   else
      put pKind && pArgOne && word 1 of pArgTwo & return after sNostr
   end if
   tourRecord "INFO relay" && pKind && pArgOne && char 1 to 120 of pArgTwo
end xtNostrCallback

command xtWaitNostr pWhat, pMilliseconds
   local tDeadline, tLine
   put the milliseconds + pMilliseconds into tDeadline
   repeat until the milliseconds > tDeadline
      repeat for each line tLine in sNostr
         if tLine begins with pWhat then
            exit xtWaitNostr
         end if
      end repeat
      wait 100 milliseconds with messages
   end repeat
   throw "no" && pWhat && "from the relay in" && pMilliseconds && "ms; heard:" && tourJoin(sNostr)
end xtWaitNostr

on xt_chat
   local tUrl, tRoom, tMine, tResult
   put tourJS("window.oxtTour.relay") into tUrl
   if tUrl is empty then
      throw "no relay (web_ide_tour.py --relay)"
   end if
   -- Its files in a folder of the check's own
   put "/tmp/oxt-web-xtalk-chat" into $XTALK_CHAT_HOME
   dispatch "xtalkChatMenuPick" to stack "org.openxtalk.plugin.xtalkchat"
   tourWait 3000
   tourShot "x02-chat-window"
   if xtcMissing() is not empty then
      throw "xtcMissing():" && xtcMissing()
   end if
   if not xtcHasIdentity() then
      xtcIdentityCreate "Web check", empty
      if the result is not empty then
         throw "xtcIdentityCreate:" && the result
      end if
   end if
   put xtcMyKey() into tMine
   tourRecord "INFO identity" && xtcMyNpub()
   xtcGoOnline tUrl
   if the result is not empty then
      throw "xtcGoOnline:" && the result
   end if
   xtWaitTrue "xtcOpenRelayCount() > 0", 15000
   set the itemDelimiter to tab
   put item 1 of line 1 of xtcRooms() into tRoom
   xtcSend tRoom, "hello from the web IDE"
   if the result is not empty then
      throw "xtcSend to the room:" && the result
   end if
   xtWaitTrue "oxtWebXtalkHas(" & quote & tRoom & quote & ", " & quote & "hello from the web IDE" & quote & ")", 15000
   xtcStartPrivate tMine
   xtcSend "dm:" & tMine, "a private hello"
   if the result is not empty then
      throw "xtcSend to oneself:" && the result
   end if
   xtWaitTrue "oxtWebXtalkHas(" & quote & "dm:" & tMine & quote & ", " & quote & "a private hello" & quote & ")", 20000
   -- The room, as a click on it in the sidebar shows it
   if there is a stack "revXTalkChat" then
      dispatch "xtcwShow" to stack "revXTalkChat" with tRoom
   end if
   tourWait 1500
   tourShot "x03-chat-online"
   xtcGoOffline
   if there is a stack "revXTalkChat" then
      close stack "revXTalkChat"
   end if
end xt_chat

-- True when the conversation pKey has a message whose text is pText
function oxtWebXtalkHas pKey, pText
   local tMessages, tIndex
   put xtcMessages(pKey) into tMessages
   repeat for each key tIndex in tMessages
      if tMessages[tIndex]["text"] is pText then
         return true
      end if
   end repeat
   return false
end oxtWebXtalkHas

-- Waits until the expression pCondition is true, at most pMilliseconds
command xtWaitTrue pCondition, pMilliseconds
   local tDeadline
   put the milliseconds + pMilliseconds into tDeadline
   repeat until the milliseconds > tDeadline
      if value(pCondition) is true then
         exit xtWaitTrue
      end if
      wait 100 milliseconds with messages
   end repeat
   throw "not true after" && pMilliseconds && "ms:" && pCondition
end xtWaitTrue

on xt_holdem
   local tReport, tCounts, tLine
   xtAppStack kHoldem, "holdem.livecodescript"
   go stack kHoldem
   tourWait 3000
   tourShot "x04-holdem-table"
   -- Its whole self-test, the hotseat hands included (holdem.livecodescript,
   -- heSelfTest): the first line is "<n> passed, <n> failed, <n> skipped"
   dispatch function "heSelfTest" to stack kHoldem
   put the result into tReport
   put line 1 of tReport into tCounts
   tourRecord "INFO Hold'em's self-test:" && tCounts
   repeat for each line tLine in tReport
      if tLine contains "FAIL" or tLine contains "SKIP" then
         tourRecord "INFO   " & tLine
      end if
   end repeat
   if word 3 of tCounts is not "0" or word 1 of tCounts is not an integer or word 1 of tCounts < 1 then
      throw "Hold'em's self-test:" && tCounts
   end if
   tourShot "x05-holdem-after-selftest"
   close stack kHoldem
end xt_holdem

on xt_platformer
   local tHud
   -- It asks for its art folder (answer folder) and, cancelled, draws its
   -- placeholder art: the page's folder picker is cancelled as a user
   -- cancels it (headless Chromium cancels it by itself; Firefox and
   -- WebKit wait for an answer)
   send "xtCancelPicker 60" to me in 500 milliseconds
   -- (each stage is recorded as it ends, so that a stage that never ends
   -- is the one after the last line)
   xtAppStack kPlatformer, "box2dxt-platformer.livecodescript"
   tourRecord "INFO the platformer's stack is made"
   go stack kPlatformer
   tourRecord "INFO the platformer is open"
   tourWait 3000
   tourShot "x06-platformer-title"
   send "pfStartGame" to card 1 of stack kPlatformer
   tourRecord "INFO level 1 started"
   tourWait 8000
   tourShot "x07-platformer-level-1"
   if there is a field "pfHud" of stack kPlatformer then
      put the text of field "pfHud" of stack kPlatformer into tHud
      tourRecord "INFO the HUD:" && tourJoin(tHud)
   end if
   close stack kPlatformer
end xt_platformer

on xt_datachannel
   local tReport, tLine, tPassed, tFailed, tSkipped
   xtAppStack kDataChannel, "datachannel-selftest.livecodescript"
   -- Its openStack builds the window and runs the whole harness; the
   -- loopback half is pumped by a timer, so wait for its summary
   go stack kDataChannel
   xtWaitTrue "oxtWebDcDone()", 45000
   dispatch function "stReportText" to stack kDataChannel
   put the result into tReport
   repeat for each line tLine in tReport
      if tLine begins with "==" then
         tourRecord "INFO   " & tLine
      end if
      switch word 1 of tLine
         case "PASS"
            add 1 to tPassed
            break
         case "FAIL"
            add 1 to tFailed
            tourRecord "INFO   " & tLine
            break
         case "SKIP"
            add 1 to tSkipped
            tourRecord "INFO   " & tLine
            break
      end switch
   end repeat
   tourRecord "INFO DataChannelXT's harness:" && tPassed + 0 && "passed," && tFailed + 0 && "failed," && tSkipped + 0 && "skipped"
   tourShot "x08-datachannel-selftest"
   if tFailed + 0 > 0 or tPassed + 0 < 40 then
      throw "DataChannelXT's harness:" && tPassed + 0 && "passed," && tFailed + 0 && "failed"
   end if
   close stack kDataChannel
end xt_datachannel

function oxtWebDcDone
   local tReport
   dispatch function "stReportText" to stack kDataChannel
   put the result into tReport
   return "== summary ==" is in tReport and "RUN NOT FINISHED" is not in tReport
end oxtWebDcDone

on xt_audio
   local tEngine, tTone, tBlock, tWav, tPeak
   tourRecord "INFO auLibraryVersion()" && auLibraryVersion()
   xtExpect "the library's ABI", word 1 to 3 of auLibraryVersion(), "audioxt ABI 1;"
   xtExpect "the audio system", auBackendName(), "Web Audio"
   -- An engine with no device, whose mix is read as samples: the same
   -- bytes as on the desktop
   put auEngineCreateOffline(8000, 2) into tEngine
   put auSoundTone(tEngine, "sine", 440, 0.5) into tTone
   auSoundStart tTone
   put auEngineRender(tEngine, 800, "s16") into tBlock
   xtExpect "800 frames of two 16-bit channels", the number of bytes in tBlock, 3200
   xtExpect "the mix, bit for bit", xtHex(sha1Digest(tBlock)), kAudioMixSha1
   xtExpect "the clock counts them", format("%.4f", auEngineTime(tEngine)), "0.1000"
   put auEnginePeak(tEngine) into tPeak
   xtExpect "the meter reads half scale", format("%.2f,%.2f", item 1 of tPeak, item 2 of tPeak), "0.50,0.50"
   -- A WAV file made of the mix, and read back
   put auWAVEncode(tBlock, "s16", 8000, 2) into tWav
   xtExpect "a WAV file", byte 1 to 4 of tWav && the number of bytes in tWav, "RIFF 3244"
   xtExpect "read back bit for bit", auDecodeData(tWav, "s16", 0, 0) is tBlock, "true"
   auEngineFree tEngine
   -- The browser's own device: it opens, or it is refused with a reason,
   -- and nothing throws (miniaudio's JavaScript once threw through the
   -- whole engine on a page with no Web Audio). A browser holds a page's
   -- sound until the visitor's first gesture, so its clock is not asked.
   put auEngineCreate(0, 0, 0) into tEngine
   if tEngine > 0 then
      put auSoundTone(tEngine, "sine", 440, 0.1) into tTone
      auSoundStart tTone
      tourRecord "INFO a playback device opened at" && auEngineSampleRate(tEngine) && "Hz; a tone on it plays:" && auSoundIsPlaying(tTone)
   else
      tourRecord "INFO no playback device here:" && auLastError()
      xtExpect "and it says why", auLastError() is not empty, "true"
   end if
   auShutDown
   xtExpect "everything closed", auEngineIsValid(tEngine), "false"
end xt_audio

on xt_unavailable
   local tError, tGot
   -- TorrentXT and ENetXT: a catchable error, not a crash
   repeat for each item tGot in "btStartSession(),btLastError(),enInitialize(),enLibraryVersion()"
      put empty into tError
      try
         get value(tGot)
      catch tError
      end try
      if tError is empty then
         throw tGot && "answered" && quote & it & quote && "in the browser, where it cannot work"
      end if
      -- The library is named, so that a script (and the web Stack
      -- Player's message) can say which one is missing
      if "unable to load foreign library" is not in tError then
         throw tGot && "failed, but not by naming its library:" && tourJoin(tError)
      end if
      tourRecord "INFO" && tGot && "refused:" && tourJoin(tError)
   end repeat
   -- And the engine goes on
   sxInit
   xtExpect "BLAKE2b-256 of abc after them", sxBin2Hex(sxHash("abc", 32)), kBlake2bAbc
   -- OnionXT is script: what needs no daemon works, and the daemon is out
   -- of reach (a page opens no TCP socket)
   tourRecord "INFO oxVersion()" && oxVersion()
   xtExpect "a valid onion address", oxIsValidAddress(kOnionGood), true
   xtExpect "one with a bad checksum", oxIsValidAddress(kOnionBad), false
   put empty into tError
   put empty into tGot
   try
      oxConnectControl
      put the result into tGot
   catch tError
   end try
   tourRecord "INFO oxConnectControl:" && tourJoin(tGot && tError)
   tourWait 3000
   xtExpect "the control connection authenticated", oxIsControlAuthenticated(), false
   oxDisconnectControl
end xt_unavailable

-- Cancels the page's file or folder picker (em-dialog.js pickFiles) when
-- there is one, trying every half second pTries more times
on xtCancelPicker pTries
   local tGot
   put tourJS("(function(){var i=document.querySelector('input[type=file]');" & \
         "if(!i)return 'none';i.dispatchEvent(new Event('cancel'));return 'cancelled';})()") into tGot
   if tGot is "cancelled" then
      tourRecord "INFO cancelled the folder picker"
   else if pTries > 0 then
      send "xtCancelPicker" && pTries - 1 to me in 500 milliseconds
   end if
end xtCancelPicker

-- A new stack pName whose script is the app pFile, which web_ide_tour.py
-- --add put in the folder files beside this file, as its HOW TO RUN says (a new stack, the
-- file as its script)
command xtAppStack pName, pFile
   local tPath, tScript, tDefault
   set the itemDelimiter to slash
   put item 1 to -2 of the effective filename of me & "/files/" & pFile into tPath
   if there is no file tPath then
      throw pFile && "is not beside the check (web_ide_tour.py --add)"
   end if
   put textDecode(URL ("binfile:" & tPath), "UTF-8") into tScript
   if there is a stack pName then
      delete stack pName
   end if
   put the defaultStack into tDefault
   create stack pName
   set the defaultStack to tDefault
   set the script of stack pName to tScript
   if the result is not empty then
      throw pFile && "does not compile:" && tourJoin(the result)
   end if
   -- Closed (it stays in memory) and shown again by the caller's go, so
   -- that it opens as a pasted stack reopened does: with preOpenStack,
   -- openStack and openCard, which a stack created open never gets
   close stack pName
end xtAppStack

----------------------------------------------------------------
-- Checks

command xtExpect pWhat, pGot, pWant
   if pGot is not pWant then
      throw pWhat & ": got" && quote & pGot & quote & ", not" && quote & pWant & quote
   end if
   tourRecord "INFO" && pWhat & ":" && pGot
end xtExpect

function xtHex pData
   local tHex
   get binaryDecode("H*", pData, tHex)
   return toLower(tHex)
end xtHex

function xtBytes pHex
   return binaryEncode("H*", pHex)
end xtBytes

function xtZeros pBytes
   local tOut
   repeat pBytes times
      put "00" after tOut
   end repeat
   return tOut
end xtZeros

----------------------------------------------------------------
-- The page (as web-ide-tour.livecodescript)

command tourWait pMilliseconds
   wait pMilliseconds milliseconds with messages
end tourWait

command tourShot pFile
   if the lockScreen then
      -- (at most 20 times: should a lock outlast its unlock, the shot is
      -- taken locked rather than the check stopping here)
      repeat 20 times
         if not the lockScreen then
            exit repeat
         end if
         unlock screen
      end repeat
      tourWait 300
   end if
   tourAct "shot" && pFile
end tourShot

command tourAct pAction
   local tId, tDeadline
   add 1 to sAct
   put sAct into tId
   tourRecord "ACT" && tId && pAction
   put the milliseconds + 20000 into tDeadline
   repeat until tourJS("window.oxtTour.done") >= tId or the milliseconds > tDeadline
      wait 100 milliseconds with messages
   end repeat
end tourAct

-- A step still running after a minute: what it is waiting in (the
-- handlers under this one) and what is queued, again every minute while it
-- runs, so that a step that never ends says where it stopped
on tourWatchdog pStep
   tourRecord "INFO" && pStep && "still running after 60 s; open stacks:" && tourJoin(the openStacks)
   tourRecord "INFO   in:" && tourJoin(the executionContexts)
   tourRecord "INFO   queued:" && tourJoin(the pendingMessages)
   tourCloseDialogs true
   send "tourWatchdog" && quote & pStep & quote to me in 60 seconds
   put the result into sWatchdog
end tourWatchdog

function tourPageDialog
   return tourJS("document.querySelector('.oxt-dialog-default') !== null") is "true"
end tourPageDialog

command tourCloseDialogs pAnyModal
   local tName
   if tourPageDialog() then
      tourRecord "INFO closing the page's dialog"
      tourAct "dialog"
   end if
   repeat for each item tName in "Answer Dialog,Ask Dialog"
      if there is a stack tName and the mode of stack tName is not 0 then
         tourRecord "INFO closing" && tName
         close stack tName
      end if
   end repeat
   if pAnyModal is true then
      repeat for each line tName in the openStacks
         if there is a stack tName and the mode of stack tName is among the items of "5,6" then
            tourRecord "INFO closing the modal stack" && tName
            close stack tName
         end if
      end repeat
   end if
end tourCloseDialogs

command tourRecord pLine
   get tourJS("window.oxtTour.record(" & tourString(pLine) & ")")
end tourRecord

function tourJS pExpression
   do pExpression as "JavaScript"
   return the result
end tourJS

function tourString pText
   replace "\" with "\\" in pText
   replace "'" with "\'" in pText
   replace return with "\n" in pText
   replace numToChar(13) with "\r" in pText
   return "'" & pText & "'"
end tourString

function tourJoin pText
   replace return with " | " in pText
   return pText
end tourJoin
