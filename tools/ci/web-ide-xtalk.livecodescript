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
-- The web IDE's engine links SodiumXT, Box2Dxt, box3dxt, render3dxt,
-- CoinXT, xlsxt, DataChannelXT (a shim over the browser's WebRTC),
-- audioxt, gamepadxt (SDL's gamepad layer, over the browser's Gamepad
-- API), webpxt, barcodext and midixt (its shim over the browser's Web
-- MIDI) into itself
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
--    gamepad     gamepadxt: a virtual pad (SDL's, which needs no
--                controller; CI's browser has none) attached, a button
--                pressed and a stick tilted, each read back as state and
--                as events after a poll, rumbled and lit as the pad saw
--                it, then unplugged
--    midi        midixt over a stand-in for the browser's Web MIDI (CI's
--                browsers have no MIDI device, and a page that asks for
--                MIDI puts the question to its visitor) with one loop
--                cable: a virtual port refused in words, nothing asked;
--                the first listing asks once, with SysEx, and says so; a
--                listing before the answer says it waits; then the
--                cable's two ends listed and opened, a note and a
--                controller sent and polled back, SysEx left out until
--                it is let in, and both ends closed, the input let go
--    render3d    render3dxt: a box drawn into a picture (its colour at the
--                middle, the background at a corner) and found there by a
--                click; drawn again lit and textured, begun and taken as
--                a frame loop does (ready at once: the web build draws on
--                one thread); the picture set as an image's imageData
--    coinxt      CoinXT: SHA-256, Keccak-256, a public key and BIP-340's
--                first vector
--    xlsx        xlsxt: a workbook with a table, a formula, a date, a
--                chart and text outside ASCII is written into the page's
--                file system and read back cell for cell; a file that is
--                no workbook is refused in words
--    webp        webpxt: a picture written as a lossless and as a lossy
--                WebP file and read back, with its transparency; an
--                animation of three frames written and read; a refusal;
--                an animation made by hand whose frames add up to more
--                than 2147483647 ms, refused when it is opened and
--                still read as a picture; the picture set as an
--                image's imageData
--    barcode     barcodext: a QR code, an EAN-13 and binary content made
--                and read back out of their own pictures, the squares
--                and the SVG of one, a refusal, and a barcode read from
--                an image's imageData
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

constant kSteps = "start,sodium,pwhash,box2d,box3d,render3d,gamepad,midi,coinxt,xlsx,webp,barcode,nostr,chat,holdem,platformer,datachannel,audio,unavailable"
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
   xtExpect "the library's ABI", word 1 to 3 of b3LibraryVersion(), "box3dxt ABI 3;"
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
   -- The sky (ABI 3): the background is a sky of one colour; a sky of
   -- two paints the picture's top row in the first, a colour out of
   -- range is refused and leaves both, and the ball is drawn as before
   xtExpect "the background is a sky of one colour", b3RenderSky(), "32,36,42,32,36,42"
   b3RenderSetSky 40, 80, 160, 200, 210, 220
   xtExpect "a sky of two colours", b3RenderSky(), "40,80,160,200,210,220"
   b3RenderSetSky 300, 0, 0, 0, 0, 0
   xtExpect "a colour out of range leaves it", b3RenderSky(), "40,80,160,200,210,220"
   xtExpect "a picture under the sky is drawn", b3RenderWorld(tWorld, 64, 48, 0), "true"
   xtExpect "the top corner is the sky's top colour", b3RenderPixel(0, 0), 40 * 65536 + 80 * 256 + 160
   xtExpect "the middle pixel still shows the ball", b3RenderShapeAt(32, 24) is tShape, "true"
   put b3RenderPixels() into tData
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

on xt_gamepad
   local tBefore, tPad, tStick
   tourRecord "INFO gpLibraryVersion()" && gpLibraryVersion()
   xtExpect "the library's ABI", gpABIVersion(), 1
   xtExpect "SDL 3", word 1 of gpLibraryVersion() && char 1 to 2 of word 2 of gpLibraryVersion(), "SDL 3."
   xtExpect "start", gpStart(), true
   -- A browser shows a page a controller only after a button on it is
   -- pressed, and CI's has none: what is there is only reported
   put gpPadCount() into tBefore
   tourRecord "INFO the browser's own pads:" && tBefore
   get gpEvents()
   put gpVirtualAttach("Web Pad") into tPad
   xtExpect "a virtual pad", tPad > 0 and gpPadIsVirtual(tPad) and gpPadCount() is tBefore + 1, true
   xtExpect "its name", gpPadName(tPad), "Web Pad"
   xtExpect "its arrival is an event", ("connected," & tPad) is among the lines of gpEvents(), true
   -- A button: seen after a poll, as state and as one event
   xtExpect "press south", gpVirtualSetButton(tPad, "south", true), true
   xtExpect "the poll's events", gpPoll(), 1
   xtExpect "south held", gpPadButton(tPad, "south"), true
   xtExpect "the event", gpEvents(), "button," & tPad & ",south,down"
   xtExpect "its printed label", gpPadButtonLabel(tPad, "south"), "a"
   -- A stick, with the round dead zone (0.15) taken out
   get gpVirtualSetAxis(tPad, "leftx", 0.1)
   get gpVirtualSetAxis(tPad, "lefty", 0)
   get gpPoll()
   xtExpect "a stick inside the dead zone", gpPadStick(tPad, "left"), "0,0"
   get gpVirtualSetAxis(tPad, "leftx", 1)
   get gpPoll()
   put gpPadStick(tPad, "left") into tStick
   xtExpect "a stick at full tilt", (item 1 of tStick is 1) && (item 2 of tStick is 0), "true true"
   -- Rumble and light, as the pad saw them
   xtExpect "rumble", gpPadRumble(tPad, 0.5, 1, 200) && (item 2 of gpVirtualRumble(tPad) is 1), "true true"
   xtExpect "the light", gpPadSetLED(tPad, 10, 128, 255) && gpVirtualLED(tPad), "true 10,128,255"
   -- Unplugged: its handle dies and says so
   gpVirtualDetach tPad
   xtExpect "unplugged", gpPadIsConnected(tPad) && (("disconnected," & tPad) is among the lines of gpEvents()), "false true"
   xtExpect "SDL's assertions", gpAssertCount(), 0
   gpStop
   xtExpect "stopped", gpIsStarted(), false
end xt_gamepad

on xt_midi
   local tEvent, tIn, tOut, tEvents
   tourRecord "INFO the browser's own Web MIDI:" && tourJS("typeof navigator.requestMIDIAccess")
   -- The browser's Web MIDI is replaced before midixt first asks for it:
   -- CI's browsers have no MIDI device, and the real question would wait
   -- for a person. The stand-in has one loop cable (what leaves by its
   -- output arrives at its input, a moment later, as a device's would)
   -- and answers only when told to, so that the wait is seen. The real
   -- Web MIDI is owed a pass in a browser with a device
   xtExpect "the stand-in", tourJS(xtMidiStandIn()), "installed"
   xtExpect "the library's ABI", midiVersion(), 2
   -- What needs no port works before anything is asked
   put midiDecode(xtBytes("903c64")) into tEvent
   xtExpect "a note-on decoded", xtMidiEvent(tEvent), "noteOn 1 60 100 903c64"
   put midiDecode(xtBytes("e10040")) into tEvent
   xtExpect "a pitch bend's 14 bits", tEvent["kind"] && tEvent["channel"] && tEvent["value14"], "pitchBend 2 8192"
   -- Web MIDI makes no port of its own: refused in words, before the
   -- browser is asked anything
   xtExpect "a virtual input", midiOpenVirtualInput("Web Show"), 0
   xtExpect "refused in words", midiLastError(), "midi: a web page has no virtual ports (Web MIDI makes none)"
   xtExpect "nothing asked for it", tourJS("String(window.oxtMidiStandIn.asks)"), "0"
   -- The first listing asks the browser, once and with SysEx; until it
   -- answers there are no ports, and each listing says why
   xtExpect "the first listing", the number of elements of midiInputPorts(), 0
   xtExpect "it says the browser was asked", midiLastError(), \
         "midi: no MIDI input backend: asked the browser whether this page may use MIDI: ask again once it has answered"
   xtExpect "asked once, with SysEx", tourJS("window.oxtMidiStandIn.asks + ' ' + window.oxtMidiStandIn.sysex"), "1 true"
   tourWait 300
   xtExpect "a listing before the answer", the number of elements of midiOutputPorts(), 0
   xtExpect "it says the browser has not answered", midiLastError(), \
         "midi: no MIDI output backend: the browser has not yet answered whether this page may use MIDI: ask again in a moment"
   xtExpect "not asked again", tourJS("String(window.oxtMidiStandIn.asks)"), "1"
   -- The answer: the cable's two ends are listed
   xtExpect "the browser answers", tourJS("window.oxtMidiStandIn.answer()"), "answered"
   xtWaitTrue "oxtWebMidiAnswered()", 5000
   xtExpect "the inputs", xtMidiPorts("in"), "0:Loop Cable"
   xtExpect "the outputs", xtMidiPorts("out"), "0:Loop Cable"
   xtExpect "and no error", midiLastError(), empty
   xtExpect "still asked once", tourJS("String(window.oxtMidiStandIn.asks)"), "1"
   -- Both ends opened; a port that is not there is refused
   put midiOpenOutput(0) into tOut
   put midiOpenInput(0) into tIn
   xtExpect "both ends open", tOut > 0 and tIn > 0, true
   xtExpect "the input listens", tourJS("window.oxtMidiStandIn.input.connection + ' ' + window.oxtMidiStandIn.listeners()"), "open 1"
   xtExpect "an input that is not there", midiOpenInput(1) && midiLastError(), "0 midi: port index out of range"
   -- A note and a controller through the cable, polled back: each its
   -- own event, the first with no time before it
   midiNoteOn tOut, 1, 60, 100
   midiControlChange tOut, 2, 7, 90
   xtExpect "sent", midiLastError(), empty
   put xtMidiPoll(tIn, 2) into tEvents
   xtExpect "two messages came back", the number of elements of tEvents, 2
   xtExpect "the note", xtMidiEvent(tEvents[1]), "noteOn 1 60 100 903c64"
   xtExpect "the time before the first", tEvents[1]["delta"], 0
   xtExpect "the controller", xtMidiEvent(tEvents[2]), "controlChange 2 7 90 b1075a"
   tourRecord "INFO the time between them:" && tEvents[2]["delta"] && "s"
   -- SysEx is left out by an input until it is let in, as RtMidi does
   midiSend tOut, xtBytes("f07d0102f7")
   xtWaitTrue "oxtWebMidiDelivered() >= 3", 5000
   xtExpect "SysEx left out", the number of elements of midiPoll(tIn), 0
   midiIgnoreTypes tIn, false, true, true
   midiSend tOut, xtBytes("f07d0102f7")
   put xtMidiPoll(tIn, 1) into tEvents
   xtExpect "SysEx let in", xtMidiEvent(tEvents[1]), "sysex 0 125 1 f07d0102f7"
   xtExpect "what the cable carried", tourJS("window.oxtMidiStandIn.sent.join('|')"), \
         "144 60 100|177 7 90|240 125 1 2 247|240 125 1 2 247"
   -- Closed: the input's last handle lets the port go; an output is left
   -- open (closing it could drop what it has not yet sent: the page
   -- closes it); a closed handle is refused in words
   midiClose tIn
   midiClose tOut
   xtExpect "the input let go", tourJS("window.oxtMidiStandIn.input.connection + ' ' + window.oxtMidiStandIn.listeners()"), "closed 0"
   xtExpect "the output left open", tourJS("window.oxtMidiStandIn.output.connection"), "open"
   xtExpect "a closed input", (the number of elements of midiPoll(tIn)) && midiLastError(), "0 midi: not an open input port"
   midiSend tOut, xtBytes("903c00")
   xtExpect "a closed output", midiLastError(), "midi: not an open output port"
end xt_midi

-- The stand-in for the browser's Web MIDI, as JavaScript that installs it
-- and says "installed": navigator.requestMIDIAccess counts its questions
-- and keeps the promise it gives until window.oxtMidiStandIn.answer();
-- the access has one input and one output, both "Loop Cable", and what is
-- sent to the output (kept in window.oxtMidiStandIn.sent) reaches the
-- input's midimessage listeners in a timer, as a device's would. Only
-- what midixt's web layer uses (its src/midi_web.c in the xTalk Suite)
function xtMidiStandIn
   return "(function(){" & \
         "var S=window.oxtMidiStandIn={asks:0,sysex:null,sent:[],delivered:0,answer:null};" & \
         "function Port(type){this.type=type;this.id='loop-cable-'+type;this.name='Loop Cable';" & \
         "this.manufacturer='';this.version='';this.state='connected';this.connection='closed';this.heard=[];}" & \
         "Port.prototype.addEventListener=function(n,f){if(n==='midimessage'&&this.heard.indexOf(f)<0){this.heard.push(f);}};" & \
         "Port.prototype.removeEventListener=function(n,f){var i=this.heard.indexOf(f);if(n==='midimessage'&&i>=0){this.heard.splice(i,1);}};" & \
         "Port.prototype.open=function(){this.connection='open';return Promise.resolve(this);};" & \
         "Port.prototype.close=function(){this.connection='closed';return Promise.resolve(this);};" & \
         "var input=S.input=new Port('input');var output=S.output=new Port('output');" & \
         "output.send=function(data){var bytes=Array.from(data);S.sent.push(bytes.join(' '));" & \
         "setTimeout(function(){var ev={data:new Uint8Array(bytes),timeStamp:performance.now()};" & \
         "input.heard.slice().forEach(function(f){f(ev);});S.delivered++;},5);};" & \
         "S.listeners=function(){return input.heard.length;};" & \
         "var access={sysexEnabled:true,inputs:new Map([[input.id,input]]),outputs:new Map([[output.id,output]]),onstatechange:null};" & \
         "var ask=function(options){S.asks++;S.sysex=!!(options&&options.sysex);" & \
         "return new Promise(function(resolve){S.answer=function(){resolve(access);return 'answered';};});};" & \
         "try{Object.defineProperty(navigator,'requestMIDIAccess',{value:ask,configurable:true,writable:true});}" & \
         "catch(e){navigator.requestMIDIAccess=ask;}" & \
         "return navigator.requestMIDIAccess===ask?'installed':'not installed';})()"
end xtMidiStandIn

function oxtWebMidiAnswered
   return (the number of elements of midiInputPorts()) > 0
end oxtWebMidiAnswered

function oxtWebMidiDelivered
   return tourJS("String(window.oxtMidiStandIn.delivered)")
end oxtWebMidiDelivered

-- The ports midiInputPorts() ("in") or midiOutputPorts() lists, as
-- "<number>:<name>" items
function xtMidiPorts pWhich
   local tPorts, tIndex, tOut
   if pWhich is "in" then
      put midiInputPorts() into tPorts
   else
      put midiOutputPorts() into tPorts
   end if
   repeat with tIndex = 1 to the number of elements of tPorts
      put comma & tIndex - 1 & ":" & tPorts[tIndex] after tOut
   end repeat
   delete char 1 of tOut
   return tOut
end xtMidiPorts

-- Polls pIn until pCount messages have come, for at most 5 s: what came,
-- as one list (an array numbered from 1), as midiPoll gives each
function xtMidiPoll pIn, pCount
   local tAll, tEvents, tIndex, tCount, tDeadline
   put 0 into tCount
   put the milliseconds + 5000 into tDeadline
   repeat until tCount >= pCount or the milliseconds > tDeadline
      put midiPoll(pIn) into tEvents
      repeat with tIndex = 1 to the number of elements of tEvents
         add 1 to tCount
         put tEvents[tIndex] into tAll[tCount]
      end repeat
      if tCount < pCount then
         wait 50 milliseconds with messages
      end if
   end repeat
   return tAll
end xtMidiPoll

-- An event as "<kind> <channel> <data1> <data2> <the bytes in hex>"
function xtMidiEvent pEvent
   return pEvent["kind"] && pEvent["channel"] && pEvent["data1"] && pEvent["data2"] && xtHex(pEvent["bytes"])
end xtMidiEvent

on xt_webp
   local tPixels, tAlpha, tRow, tFile, tInfo, tBack, tWriter, tAnim, tFrame, tWas, tN
   tourRecord "INFO wpLibraryVersion()" && wpLibraryVersion()
   xtExpect "the library's ABI", word 1 to 3 of wpLibraryVersion(), "webpxt ABI 1;"
   -- A picture of 32 x 24 pixels, as an image's imageData: red at the
   -- left, blue at the right, the top half see-through
   repeat 16 times
      put numToByte(255) & numToByte(200) & numToByte(40) & numToByte(30) after tRow
   end repeat
   repeat 16 times
      put numToByte(255) & numToByte(20) & numToByte(60) & numToByte(220) after tRow
   end repeat
   repeat 24 times
      put tRow after tPixels
   end repeat
   repeat 32 * 12 times
      put numToByte(0) after tAlpha
   end repeat
   repeat 32 * 12 times
      put numToByte(255) after tAlpha
   end repeat
   -- Lossless: the file says what it is, and every pixel that shows
   -- comes back as it went in
   put wpEncodeLossless(tPixels, tAlpha, 32, 24) into tFile
   xtExpect "a lossless file starts as WebP does", byte 1 to 4 of tFile & byte 9 to 12 of tFile, "RIFFWEBP"
   put wpInfo(tFile) into tInfo
   xtExpect "what the file says", tInfo["width"] && tInfo["height"] && tInfo["alpha"] && tInfo["animated"] && tInfo["frames"] && tInfo["compression"], "32 24 true false 1 lossless"
   put wpDecode(tFile) into tBack
   xtExpect "its size decoded", tBack["width"] && tBack["height"] && the number of bytes in tBack["imageData"] && the number of bytes in tBack["alphaData"], "32 24 3072 768"
   xtExpect "the pixels that show come back", byte (12 * 32 * 4 + 1) to -1 of tBack["imageData"] is byte (12 * 32 * 4 + 1) to -1 of tPixels, "true"
   xtExpect "the transparency comes back", tBack["alphaData"] is tAlpha, "true"
   xtExpect "translucent", tBack["translucent"], "true"
   put wpDecodeScaled(tFile, 16, 0) into tBack
   xtExpect "decoded to half its size", tBack["width"] && tBack["height"], "16 12"
   -- Lossy: a smaller file whose colours are near, not equal
   put wpEncode(tPixels, empty, 32, 24, 80) into tFile
   put wpInfo(tFile) into tInfo
   xtExpect "a lossy file", tInfo["width"] && tInfo["alpha"] && tInfo["compression"], "32 false lossy"
   put wpDecode(tFile) into tBack
   xtExpect "its left is still red", byteToNum(byte 2 of tBack["imageData"]) > 150 and byteToNum(byte 4 of tBack["imageData"]) < 90, "true"
   put wpEncodeAdvanced(tPixels, empty, 32, 24, 100, true, 6) into tFile
   put wpInfo(tFile) into tInfo
   xtExpect "every setting given", tInfo["compression"], "lossless"
   -- A refused call returns empty and says why; nothing throws
   xtExpect "a file that is not WebP", wpDecode("not a picture") is empty and wpLastError() is not empty, "true"
   -- An animation of three frames, written and read back. Each frame is
   -- the picture moved along (equal frames would be written as one)
   put wpAnimEncoderCreate(32, 24, 2, 100, true) into tWriter
   repeat with tN = 1 to 3
      xtExpect "frame" && tN && "added", wpAnimEncoderAddFrame(tWriter, tPixels, empty, 40 * tN), "true"
      put byte 33 to -1 of tPixels & byte 1 to 32 of tPixels into tPixels
   end repeat
   xtExpect "frames held", wpAnimEncoderFrameCount(tWriter), 3
   put wpAnimEncoderFinish(tWriter) into tFile
   xtExpect "the writer is closed", wpAnimEncoderIsValid(tWriter) && wpAnimEncoderOpenCount(), "false 0"
   put wpAnimOpen(tFile) into tAnim
   xtExpect "the animation", wpAnimIsValid(tAnim) && wpAnimWidth(tAnim) && wpAnimHeight(tAnim) && wpAnimFrameCount(tAnim) && wpAnimLoopCount(tAnim), "true 32 24 3 2"
   put wpAnimNextFrame(tAnim) into tFrame
   put wpAnimNextFrame(tAnim) into tFrame
   xtExpect "its second frame", tFrame["index"] && tFrame["duration"] && byteToNum(byte (8 * 4 + 2) of tFrame["imageData"]) && byteToNum(byte (7 * 4 + 2) of tFrame["imageData"]), "2 80 20 200"
   wpAnimRewind tAnim
   put wpAnimNextFrame(tAnim) into tFrame
   xtExpect "rewound", tFrame["index"], 1
   wpAnimClose tAnim
   xtExpect "nothing left open", wpAnimOpenCount() && wpAnimEncoderOpenCount(), "0 0"
   -- A whole animation ends by 2147483647 ms, the most the int libwebp
   -- times it in holds. A file whose frames add up to more is refused
   -- when it is opened, and is still read as a picture: 128 frames of
   -- the longest a frame says, 16777215 ms, add up to less; 129 to more
   put xtWebpAnimation(128, 16777215) into tFile
   put wpAnimOpen(tFile) into tAnim
   xtExpect "128 frames of 16777215 ms open", wpAnimIsValid(tAnim) && wpAnimFrameCount(tAnim), "true 128"
   wpAnimClose tAnim
   put xtWebpAnimation(129, 16777215) into tFile
   xtExpect "129 frames of 16777215 ms are refused", wpAnimOpen(tFile) && (wpLastError() contains "add up to"), "0 true"
   put wpInfo(tFile) into tInfo
   put wpDecode(tFile) into tBack
   xtExpect "and still read as a picture", tInfo["animated"] && tInfo["frames"] && tBack["width"], "true 129 1"
   xtExpect "nothing left open after them", wpAnimOpenCount(), 0
   -- An image takes a decoded picture and gives it back
   put wpDecode(wpEncodeLossless(tPixels, tAlpha, 32, 24)) into tBack
   xtExpect "decoded for an image", tBack["width"], 32
   put the defaultStack into tWas
   create invisible stack "oxtWebWebp"
   set the defaultStack to "oxtWebWebp"
   create image "picture"
   set the defaultStack to tWas
   set the width of image "picture" of stack "oxtWebWebp" to 32
   set the height of image "picture" of stack "oxtWebWebp" to 24
   set the imageData of image "picture" of stack "oxtWebWebp" to tBack["imageData"]
   set the alphaData of image "picture" of stack "oxtWebWebp" to tBack["alphaData"]
   xtExpect "an image takes the picture", the number of bytes in the imageData of image "picture" of stack "oxtWebWebp" && (the alphaData of image "picture" of stack "oxtWebWebp" is tAlpha), "3072 true"
   delete stack "oxtWebWebp"
end xt_webp

-- An animated WebP file of pCount 1 x 1 frames, each shown for pDuration
-- ms, made by hand around the VP8L chunk of a still webpxt writes: a file
-- from elsewhere can say what webpxt's own writer refuses to (the suite's
-- webpxt/tests/engine-selftest.lc makes the same one)
function xtWebpAnimation pCount, pDuration
   local tStill, tAt, tSize, tWhole, tChunk, tFrames, tBody
   put wpEncodeLossless(numToByte(0) & numToByte(200) & numToByte(100) & numToByte(50), empty, 1, 1) into tStill
   put 13 into tAt
   repeat while tAt + 7 <= the number of bytes of tStill
      put byteToNum(byte tAt + 4 of tStill) + 256 * byteToNum(byte tAt + 5 of tStill) \
            + 65536 * byteToNum(byte tAt + 6 of tStill) + 16777216 * byteToNum(byte tAt + 7 of tStill) into tSize
      put 8 + tSize + tSize mod 2 into tWhole
      if byte tAt to tAt + 3 of tStill is "VP8L" then
         put byte tAt to tAt + tWhole - 1 of tStill into tChunk
         exit repeat
      end if
      add tWhole to tAt
   end repeat
   if tChunk is empty then return empty
   -- An ANMF chunk a frame: its x, y, width and height less one (all 0),
   -- its duration, a byte of flags, then the frame's own chunk
   repeat pCount times
      put "ANMF" & xtLittleEndian(16 + the number of bytes of tChunk, 4) & xtLittleEndian(0, 12) \
            & xtLittleEndian(pDuration, 3) & numToByte(0) & tChunk after tFrames
   end repeat
   -- VP8X says it is animated, on a canvas of 1 x 1; ANIM: no background
   -- colour, and it loops for ever
   put "VP8X" & xtLittleEndian(10, 4) & numToByte(2) & xtLittleEndian(0, 9) \
         & "ANIM" & xtLittleEndian(6, 4) & xtLittleEndian(0, 6) & tFrames into tBody
   return "RIFF" & xtLittleEndian(4 + the number of bytes of tBody, 4) & "WEBP" & tBody
end xtWebpAnimation

-- pValue as pBytes bytes, the lowest first
function xtLittleEndian pValue, pBytes
   local tOut
   repeat pBytes times
      put numToByte(pValue mod 256) after tOut
      put pValue div 256 into pValue
   end repeat
   return tOut
end xtLittleEndian

on xt_barcode
   local tPicture, tFound, tRows, tSheet, tWas
   tourRecord "INFO bcLibraryVersion()" && bcLibraryVersion()
   xtExpect "the library's ABI", word 1 to 3 of bcLibraryVersion(), "barcodext ABI 1;"
   xtExpect "kinds it reads and makes", ("QR Code" is among the items of bcFormats()) && ("EAN-13" is among the items of bcWritableFormats()), "true true"
   -- A QR code made, and read back out of its own picture
   put bcCreate("https://openxtalk.org/", "QR Code", 4) into tPicture
   xtExpect "a QR code's picture", tPicture["width"] && tPicture["height"] && the number of bytes in tPicture["imageData"], "132 132 69696"
   put bcRead(tPicture["imageData"], tPicture["width"], tPicture["height"]) into tFound
   xtExpect "one barcode found", the number of elements in tFound, 1
   xtExpect "what it says", tFound[1]["format"] && tFound[1]["text"] && tFound[1]["valid"] && tFound[1]["contentType"], "QR Code https://openxtalk.org/ true Text"
   xtExpect "where it is", tFound[1]["position"], "16,16,116,16,116,116,16,116"
   xtExpect "the shortest read", bcReadText(tPicture["imageData"], tPicture["width"], tPicture["height"]), "https://openxtalk.org/"
   put bcCreateMatrix("https://openxtalk.org/", "QR Code", "") into tRows
   xtExpect "its squares", the number of lines in tRows && the number of chars in line 1 of tRows && char 1 to 7 of line 1 of tRows, "25 25 1111111"
   -- A product barcode: the check digit is worked out, the digits printed
   put bcCreateAdvanced("590123412345", "EAN-13", "", 2, true, true) into tPicture
   put bcReadFormats(tPicture["imageData"], tPicture["width"], tPicture["height"], "EAN-13") into tFound
   xtExpect "an EAN-13 with its check digit", tFound[1]["format"] && tFound[1]["text"], "EAN-13 5901234123457"
   xtExpect "asked for another kind, it is not found", the number of elements in bcReadFormats(tPicture["imageData"], tPicture["width"], tPicture["height"], "QR Code"), 0
   -- Bytes, a zero among them, kept whole
   put bcCreateFromData(numToByte(0) & numToByte(255) & numToByte(16) & "x", "QR Code", "ecLevel=H", 3) into tPicture
   put bcReadAdvanced(tPicture["imageData"], tPicture["width"], tPicture["height"], "QR Code", "pure") into tFound
   xtExpect "binary content", xtHex(tFound[1]["bytes"]) && tFound[1]["ecLevel"], "00ff1078 H"
   xtExpect "a drawing", bcCreateSVG("XTALK-39", "Code 39", "", true) begins with "<?xml" or bcCreateSVG("XTALK-39", "Code 39", "", true) begins with "<svg", "true"
   -- A refused call returns empty and says why; nothing throws
   put bcCreate("not digits", "EAN-13", 3) into tPicture
   xtExpect "content a kind cannot hold", (tPicture["width"] is empty) && (bcLastError() is not empty), "true true"
   -- An image takes a barcode's picture, and what the image gives back
   -- is read
   put bcCreate("Hello, xTalk", "Data Matrix", 5) into tPicture
   put the defaultStack into tWas
   create invisible stack "oxtWebBarcode"
   set the defaultStack to "oxtWebBarcode"
   create image "picture"
   set the defaultStack to tWas
   set the width of image "picture" of stack "oxtWebBarcode" to tPicture["width"]
   set the height of image "picture" of stack "oxtWebBarcode" to tPicture["height"]
   set the imageData of image "picture" of stack "oxtWebBarcode" to tPicture["imageData"]
   xtExpect "read from an image", bcReadText(the imageData of image "picture" of stack "oxtWebBarcode", tPicture["width"], tPicture["height"]), "Hello, xTalk"
   delete stack "oxtWebBarcode"
end xt_barcode

on xt_render3d
   local tScene, tBox, tRed, tNode, tTexture, tPlain, tLit, tBytes, tWas
   tourRecord "INFO r3LibraryVersion()" && r3LibraryVersion()
   xtExpect "the library's ABI", r3ABIVersion(), 1
   -- The web build has no threads: any count asked for draws on one
   r3SetThreadCount 4
   xtExpect "the threads it draws on", r3ThreadCount(), 1
   put r3SceneCreate() into tScene
   xtExpect "the camera a scene starts with", r3SceneCamera(tScene), "0,2,8,0,0,0,50"
   put r3MeshBox(0.5, 0.5, 0.5) into tBox
   put r3MaterialCreate(255, 0, 0) into tRed
   r3MaterialSetUnlit tRed, true
   put r3NodeCreate(tScene, tBox) into tNode
   r3NodeSetMaterial tNode, tRed
   r3SceneSetCamera tScene, 0, 0, 5, 0, 0, 0, 50
   -- The desktop's numbers (render3dxt's tests/engine-selftest.lc)
   put r3SceneRender(tScene, 64, 48) into tPlain
   xtExpect "the picture's bytes", the number of bytes in tPlain, 64 * 48 * 4
   xtExpect "the box's colour at the middle", xtPixel(tPlain, 64, 32, 24), "255,0,0"
   xtExpect "the background at the corner", xtPixel(tPlain, 64, 1, 1), "31,33,41"
   xtExpect "a click at the middle finds the box", r3ScenePick(tScene, 64, 48, 32, 24) is tNode, "true"
   xtExpect "how far the click went", format("%.4f", item 4 of r3HitText()), "4.5000"
   xtExpect "a click at the corner finds nothing", r3ScenePick(tScene, 64, 48, 1, 1), 0
   -- Lit and textured, then begun and taken as a frame loop does: with
   -- one thread the picture is drawn in the call, so it is ready at once
   r3MaterialSetUnlit tRed, false
   put r3TextureChecker(64, 8, 255, 255, 255, 0, 0, 0) into tTexture
   r3MaterialSetTexture tRed, tTexture
   put r3SceneRender(tScene, 64, 48) into tLit
   xtExpect "the lit, textured box is drawn", tLit is not tPlain and xtPixel(tLit, 64, 1, 1) is "31,33,41", "true"
   put r3SceneRenderBegin(tScene, 64, 48) into tBytes
   xtExpect "a picture begun says its bytes", tBytes, 64 * 48 * 4
   xtExpect "and is ready at once", r3SceneIsRenderReady(tScene), "true"
   xtExpect "and is the picture drawn in one call", r3SceneFrame(tScene) is tLit, "true"
   -- An image takes the picture as its imageData and gives it back
   put the defaultStack into tWas
   create invisible stack "oxtWebRender3d"
   set the defaultStack to "oxtWebRender3d"
   create image "picture"
   set the defaultStack to tWas
   set the width of image "picture" of stack "oxtWebRender3d" to 64
   set the height of image "picture" of stack "oxtWebRender3d" to 48
   set the imageData of image "picture" of stack "oxtWebRender3d" to tLit
   xtExpect "an image takes the picture", the number of bytes in the imageData of image "picture" of stack "oxtWebRender3d", 64 * 48 * 4
   delete stack "oxtWebRender3d"
   r3SceneDestroy tScene
   r3MeshDestroy tBox
   r3MaterialDestroy tRed
   r3TextureDestroy tTexture
   xtExpect "nothing is left", r3LiveCounts(), "0,0,0,0,0,0"
end xt_render3d

-- "R,G,B" of the pixel at (pX, pY) of a picture pWidth wide, as imageData
-- lays it out: four bytes a pixel, the first unused
function xtPixel pData, pWidth, pX, pY
   local tAt
   put (pY * pWidth + pX) * 4 into tAt
   return byteToNum(byte tAt + 2 of pData) & comma & byteToNum(byte tAt + 3 of pData) & comma & byteToNum(byte tAt + 4 of pData)
end xtPixel

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

on xt_xlsx
   local tPath, tBook, tSheet, tBold, tChart, tTable, tReader, tWide
   -- xlsxt: libxlsxwriter, zlib and Expat. A workbook is written into the
   -- page's own file system (a browser has no other) and read back
   tourRecord "INFO xlLibraryVersion()" && xlLibraryVersion()
   xtExpect "the ABI the binding wants", xlABIVersion(), 1
   put the temporary folder & "/oxt-web-xlsx.xlsx" into tPath
   put xlWorkbookNew(tPath) into tBook
   xtExpect "a workbook", tBook > 0 and xlWorkbookIsValid(tBook), true
   put xlWorkbookAddSheet(tBook, "Sales") into tSheet
   put xlWorkbookAddFormat(tBook) into tBold
   xlFormatSetBold tBold, true
   put "Month" & tab & "Units" & tab & "Price" & return & \
         "January" & tab & "12" & tab & "9.5" & return & \
         "February" & tab & "7" & tab & "10.25" into tTable
   xtExpect "cells written from a table", xlSheetWriteGrid(tSheet, 1, 1, tTable, "numbers", 0), 9
   xlSheetWriteText tSheet, 1, 1, "Month", tBold
   xlSheetWriteFormulaValue tSheet, 4, 3, "=SUM(C2:C3)", 19.75, 0
   xlSheetWriteDate tSheet, 5, 1, xlDateToSerial(2026, 11, 20, 0, 0, 0), 0
   xlSheetWriteBoolean tSheet, 5, 2, true, 0
   -- text outside ASCII: Latin-1, three bytes of UTF-8, and four
   put "caf" & numToCodepoint(233) && numToCodepoint(9731) && numToCodepoint(128512) into tWide
   xlSheetWriteText tSheet, 6, 1, tWide, 0
   put xlWorkbookAddChart(tBook, "column") into tChart
   xtExpect "a chart series", xlChartAddSeries(tChart, xlRangeFormula("Sales", 2, 1, 3, 1), xlRangeFormula("Sales", 2, 3, 3, 3)), 1
   xlSheetInsertChart tSheet, 2, 5, tChart, 1, 1
   xtExpect "nothing was refused", xlWorkbookErrorCount(tBook) && xlLastError(), "0 "
   -- Boolean results cross the web engine's FFI as a C int here
   xtExpect "close writes the file", xlWorkbookClose(tBook) & comma & (there is a file tPath), "true,true"
   xtExpect "the file is a zip", byte 1 to 2 of URL ("binfile:" & tPath), "PK"
   put xlReadOpen(tPath) into tReader
   xtExpect "a reader", tReader > 0 and xlReadIsValid(tReader), true
   xtExpect "its sheet", xlReadSheetCount(tReader) && xlReadSheetName(tReader, 1), "1 Sales"
   xtExpect "the sheet loads", xlReadLoad(tReader, 1), true
   xtExpect "the table read back", xlReadGrid(tReader, 1, 1, 1, 3, 3) is tTable, true
   xtExpect "a number", xlReadCellNumber(tReader, 1, 3, 3), 10.25
   xtExpect "a formula and its stored result", xlReadCellFormula(tReader, 1, 4, 3) && xlReadCellNumber(tReader, 1, 4, 3), "=SUM(C2:C3) 19.75"
   xtExpect "a date", xlReadCell(tReader, 1, 5, 1) && xlReadCellKind(tReader, 1, 5, 1), "2026-11-20 date"
   xtExpect "a boolean", xlReadCell(tReader, 1, 5, 2), "true"
   xtExpect "text outside ASCII", xlReadCell(tReader, 1, 6, 1) is tWide, true
   xlReadClose tReader
   -- A file that is no workbook is refused in words, not by a trap
   put "not a workbook" into URL ("binfile:" & tPath)
   xtExpect "a file that is no workbook", xlReadOpen(tPath) & comma & (xlLastError() is not empty), "0,true"
   delete file tPath
   xtExpect "nothing is left open", xlWorkbookCount() && xlReadCount(), "0 0"
end xt_xlsx

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
