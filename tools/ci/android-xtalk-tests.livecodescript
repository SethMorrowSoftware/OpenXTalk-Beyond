-- Copyright (C) 2026 OXT-Beyond contributors.
--
-- This file is part of OXT-Beyond.
--
-- OXT-Beyond is free software; you can redistribute it and/or modify it under
-- the terms of the GNU General Public License v3 as published by the Free
-- Software Foundation.
--
-- OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License
-- along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

-- android-xtalk-tests.livecodescript - the xTalk Suite's functional tests
-- in an Android app.
--
-- The xTalk Suite's probe (android_check.py ide --probe xtalk; kXtalkSays
-- in android-check.livecodescript) calls one handler of each extension,
-- which shows that its library loads from the package and that one call
-- returns. That says nothing of what the library is for. Each function
-- here USES one extension the way an app would: known answers through its
-- cryptography, a simulation stepped, two ends of a connection inside the
-- one app exchanging bytes, a file written where an Android app may write.
--
-- This file is not a stack and is never opened. android-check.livecodescript
-- appends its text, from the one line that is its kXtalkTestsBegin (the
-- last line of this header) to the end, to the script of the xTalk probe's
-- stack, so every handler here runs in the app, on the device, called from
-- the probe's openStack like its smoke tests: android_check.py writes a
-- "test" record for each function its XTALK_TESTS names, and device --xtalk
-- fails unless the probe said each one passed. A function returns
-- "passed:" and a few words of what it saw, or a sentence that says what
-- went wrong; the probe says either in the device's log, and a handler
-- that throws is caught by the probe and said too.
--
-- The rules these keep:
--   * Nothing outside the device: no host but 127.0.0.1, no tracker, no
--     DHT, no file outside the folder xtalkTestFolder answers. The ports
--     they listen on are tried upward from a base, so one that is taken
--     is not a failure.
--   * Nothing waits for ever: every exchange has a deadline (kXtalkWait)
--     and says which step it was at when the time ran out.
--   * A comparison of two hex digests goes through xtalkSame: the engine
--     compares two texts that both read as numbers by value ("1e3" is
--     "1000"), and a digest can read as a number.
--   * Whatever a test starts it stops, on every path it returns from, so
--     that one test's failure is not the next one's.
--
-- tools/ci/tests/test_android_xtalk.py holds this file to those rules as
-- far as text can: every function of XTALK_TESTS defined here, a deadline
-- in each one that waits, no address but 127.0.0.1. Every function here
-- passed on a desktop engine before it met an emulator: the probe's whole
-- script, as android-check.livecodescript makes it, on OXT-Beyond
-- 0.2.8-dp.2's Linux standalone engine run headless (-ui), with the
-- suite's released x86_64-linux libraries (2026-11-21).

-- BEGIN the xTalk Suite's functional tests

-- How long an exchange may take, in milliseconds, and how long the script
-- sleeps between two looks (with messages: the engine's own sockets, which
-- the curl test serves from, are only read while it waits)
constant kXtalkWait = 20000
constant kXtalkTick = 10
-- Where the tests look for a free UDP port (ENet) and a free TCP port (the
-- curl test's server), and how many they try
constant kXtalkEnetPort = 47311
constant kXtalkHttpPort = 47411
constant kXtalkPortTries = 20

-- Two texts are the same text. Never "is": see the header
private function xtalkSame pA, pB
   return ("x" & pA) is ("x" & pB)
end xtalkSame

-- A folder the app may write to: an Android app has its documents folder
-- and no /tmp
private function xtalkTestFolder
   if the platform is "android" then
      return specialFolderPath("documents")
   end if
   return specialFolderPath("temporary")
end xtalkTestFolder

-- pCount bytes, each of value pByte
private function xtalkBytes pByte, pCount
   local tData
   repeat pCount times
      put numToByte(pByte) after tData
   end repeat
   return tData
end xtalkBytes

-- SodiumXT: known answers (BLAKE2b, SHA-3, Ed25519 from RFC 8032), a box
-- sealed and opened, the system's random bytes, and a file encrypted and
-- decrypted where the app may write
function xtalkTestSodium
   local tKey, tBox, tSeed, tPublic, tSecret, tSignature, tRandom, tFolder, tPlain, tText
   sxInit
   if not xtalkSame(sxBin2Hex(sxHash("abc", 32)), \
         "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319") then
      return "BLAKE2b-256 of abc is" && sxBin2Hex(sxHash("abc", 32))
   end if
   if not xtalkSame(sxBin2Hex(sxSha3_256(empty)), \
         "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a") then
      return "SHA3-256 of nothing is" && sxBin2Hex(sxSha3_256(empty))
   end if
   -- RFC 8032, section 7.1, test 1: the key of this seed, and its
   -- signature of the empty message
   put sxHex2Bin("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60") into tSeed
   sxSignKeypairFromSeed tSeed, tPublic, tSecret
   if not xtalkSame(sxBin2Hex(tPublic), \
         "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a") then
      return "the Ed25519 public key of RFC 8032's first seed is" && sxBin2Hex(tPublic)
   end if
   put sxSignDetached(empty, tSecret) into tSignature
   if not xtalkSame(sxBin2Hex(tSignature), \
         "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" & \
         "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b") then
      return "the Ed25519 signature of RFC 8032's first test is" && sxBin2Hex(tSignature)
   end if
   if not sxSignVerifyDetached(tSignature, empty, tPublic) then
      return "a signature it made does not verify"
   end if
   if sxSignVerifyDetached(tSignature, "x", tPublic) then
      return "a signature verifies for another message"
   end if
   put xtalkBytes(7, 32) into tKey
   put sxSecretBox("the quick brown fox", tKey) into tBox
   if tBox is empty or sxSecretBoxOpen(tBox, tKey) is not "the quick brown fox" then
      return "a secret box does not open to what was sealed:" && sxLastError()
   end if
   put sxRandomBytes(32) into tRandom
   if the number of bytes of tRandom is not 32 or tRandom is sxRandomBytes(32) then
      return "the system's random bytes:" && the number of bytes of tRandom && "bytes, or the same twice"
   end if
   -- a file, through the library's own file reading and writing
   put xtalkTestFolder() into tFolder
   put "OXT-Beyond xTalk test" && the milliseconds into tPlain
   put tPlain into url ("binfile:" & tFolder & "/xtalk-sodium.txt")
   sxEncryptFile tFolder & "/xtalk-sodium.txt", tFolder & "/xtalk-sodium.enc", tKey
   sxDecryptFile tFolder & "/xtalk-sodium.enc", tFolder & "/xtalk-sodium.out", tKey
   put url ("binfile:" & tFolder & "/xtalk-sodium.out") into tText
   delete file tFolder & "/xtalk-sodium.txt"
   delete file tFolder & "/xtalk-sodium.enc"
   delete file tFolder & "/xtalk-sodium.out"
   if not xtalkSame(tText, tPlain) then
      return "a file encrypted and decrypted in" && tFolder && "came back as" && \
            the number of bytes of tText && "bytes:" && sxLastError()
   end if
   return "passed: BLAKE2b, SHA-3, Ed25519 (RFC 8032), a secret box, random bytes, a file encrypted and decrypted"
end xtalkTestSodium

-- CoinXT: its library against its binding (the ABI check), known answers
-- (SHA-256, Keccak-256, the secp256k1 generator), a key checked, and ECDSA
-- and BIP-340 signatures made and verified
function xtalkTestCoin
   local tOne, tPublic, tDigest, tSignature, tKey, tXOnly
   cxCheckABI
   if not xtalkSame(cxHexEncode(cxSha256("abc")), \
         "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") then
      return "SHA-256 of abc is" && cxHexEncode(cxSha256("abc"))
   end if
   if not xtalkSame(cxHexEncode(cxKeccak256(empty)), \
         "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470") then
      return "Keccak-256 of nothing is" && cxHexEncode(cxKeccak256(empty))
   end if
   -- the public key of the secret key 1 is the curve's generator
   put xtalkBytes(0, 31) & numToByte(1) into tOne
   put cxPublicKey(tOne, true) into tPublic
   if not xtalkSame(cxHexEncode(tPublic), \
         "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798") then
      return "the public key of the secret key 1 is" && cxHexEncode(tPublic)
   end if
   put cxSha256("OXT-Beyond") into tDigest
   put cxSign(tOne, tDigest) into tSignature
   if the number of bytes of tSignature is not cxSignatureLen() or not cxVerify(tPublic, tDigest, tSignature) then
      return "an ECDSA signature it made does not verify"
   end if
   if cxVerify(tPublic, cxSha256("OXT-Beyond!"), tSignature) then
      return "an ECDSA signature verifies for another digest"
   end if
   -- a second key (CoinXT has no random source of its own: a key is 32
   -- bytes its caller brings, here a digest), checked and used for BIP-340
   put cxNewSeckey(cxSha256("OXT-Beyond xTalk test key")) into tKey
   if the number of bytes of tKey is not cxSeckeyLen() or not cxSeckeyIsValid(tKey) or cxSeckeyIsValid(xtalkBytes(0, 32)) then
      return "a secret key of" && the number of bytes of tKey && "bytes is not valid, or the key 0 is"
   end if
   put cxXOnlyPubkey(tKey) into tXOnly
   put cxSchnorrSign(tKey, tDigest, xtalkBytes(0, 32)) into tSignature
   if the number of bytes of tSignature is not cxSchnorrSignatureLen() or not cxSchnorrVerify(tXOnly, tDigest, tSignature) then
      return "a BIP-340 signature it made does not verify"
   end if
   return "passed: the ABI check, SHA-256, Keccak-256, secp256k1's generator, a key checked, ECDSA, BIP-340"
end xtalkTestCoin

-- Box2Dxt: a box dropped onto a floor comes to rest on it
function xtalkTestBox2d
   local tWorld, tFloor, tBox, tStart, tY
   put b2NewWorld(0, -10, true, true) into tWorld
   if tWorld <= 0 then return "b2NewWorld answered" && tWorld
   put b2NewStaticBody(tWorld, 0, 0) into tFloor
   get b2AddBox(tFloor, 10, 0.5, 0, 0.6, 0)
   put b2NewDynamicBody(tWorld, 0, 4) into tBox
   get b2AddBox(tBox, 0.5, 0.5, 1, 0.6, 0)
   put b2BodyY(tBox) into tStart
   repeat 240 times
      b2Step tWorld, 1 / 60, 4
   end repeat
   put b2BodyY(tBox) into tY
   b2DestroyWorld tWorld
   -- the floor's top is at 0.5 and the box is 0.5 tall above its centre
   if tStart is not 4 or tY is not a number or abs(tY - 1) > 0.05 then
      return "a box dropped from" && tStart && "onto a floor rests at" && tY & ", not 1"
   end if
   return "passed: a box dropped from 4 rests on the floor at" && round(tY, 3) && "after 240 steps"
end xtalkTestBox2d

-- enetxt: a server and a client in the app, on 127.0.0.1 over UDP: the
-- client connects, sends a small message and one of 60000 bytes (which
-- ENet splits and joins again), and disconnects
function xtalkTestEnet
   local tServer, tClient, tPeer, tPort, tTry, tDeadline, tStep, tEvent, tBig, tGot, tBigSize, tAnswer
   if enInitialize() is not 0 then return "enInitialize:" && enLastError()
   repeat with tTry = 0 to kXtalkPortTries - 1
      put kXtalkEnetPort + tTry into tPort
      put enHostCreateServer("127.0.0.1", tPort, 4, 2, 0, 0) into tServer
      if tServer > 0 then exit repeat
   end repeat
   if tServer <= 0 then
      get enLastError()
      get enDeinitialize()
      return "no UDP port from" && kXtalkEnetPort && "could be bound:" && it
   end if
   put enHostCreateClient(1, 2, 0, 0) into tClient
   put enConnect(tClient, "127.0.0.1", tPort, 2, 7) into tPeer
   put xtalkBytes(90, 60000) into tBig
   put "connecting" into tStep
   put the milliseconds + kXtalkWait into tDeadline
   repeat until tStep is "done" or the milliseconds > tDeadline or tClient <= 0 or tPeer <= 0
      repeat for each element tEvent in enPoll(tServer)
         if tEvent["name"] is "enetReceive" and tEvent["channel"] is 0 then
            put tEvent["payload"] into tGot
         else if tEvent["name"] is "enetReceive" then
            put the number of bytes of tEvent["payload"] into tBigSize
         else if tEvent["name"] is "enetDisconnect" then
            put "done" into tStep
         end if
      end repeat
      repeat for each element tEvent in enPoll(tClient)
         if tEvent["name"] is "enetConnect" and tStep is "connecting" then
            get enSendText(tPeer, 0, "hello from the client", 1)
            get enSend(tPeer, 1, tBig, 1)
            put "sent" into tStep
         end if
      end repeat
      if tStep is "sent" and tGot is not empty and tBigSize is not empty then
         get enDisconnect(tPeer, 0)
         put "closing" into tStep
      end if
      wait kXtalkTick milliseconds with messages
   end repeat
   if tStep is "done" and tGot is "hello from the client" and tBigSize is 60000 then
      put "passed: a client and a server on 127.0.0.1:" & tPort && "(UDP) exchanged a message and one of 60000 bytes," && \
            "and disconnected" into tAnswer
   else
      put "the loopback on 127.0.0.1:" & tPort && "stopped at" && quote & tStep & quote && "(the message:" && \
            quote & tGot & quote & ", the large one:" && tBigSize && "bytes):" && enLastError() into tAnswer
   end if
   get enHostDestroy(tClient)
   get enHostDestroy(tServer)
   get enDeinitialize()
   return tAnswer
end xtalkTestEnet

-- dataChannelXT: two WebRTC peers in the app. Each one's description and
-- candidates are handed to the other (the signalling an app does over its
-- own channel), a data channel opens, and a message crosses it
function xtalkTestDataChannel
   local tA, tB, tChannelA, tChannelB, tDeadline, tStep, tEvent, tOther, tGot, tAnswer, tAOpen, tBOpen
   if dcInit() is not 0 then return "dcInit:" && dcLastError()
   put dcCreatePeer(empty) into tA
   put dcCreatePeer(empty) into tB
   if tA <= 0 or tB <= 0 then
      get dcLastError()
      get dcCleanup()
      return "dcCreatePeer:" && it
   end if
   put dcCreateChannel(tA, "oxt-beyond") into tChannelA
   put "opening" into tStep
   put the milliseconds + kXtalkWait into tDeadline
   repeat until tStep is "done" or the milliseconds > tDeadline or tChannelA <= 0
      repeat for each element tEvent in dcPoll()
         if tEvent["peer"] is tA then
            put tB into tOther
         else
            put tA into tOther
         end if
         switch tEvent["name"]
            case "dcLocalDescription"
            case "dcLocalDescriptionReady"
               get dcSetRemoteDescription(tOther, tEvent["sdp"], tEvent["sdpType"])
               break
            case "dcLocalCandidate"
               get dcAddRemoteCandidate(tOther, tEvent["candidate"], tEvent["mid"])
               break
            case "dcChannelIncoming"
               if tEvent["peer"] is tB then put tEvent["channel"] into tChannelB
               break
            case "dcChannelOpen"
               if tEvent["channel"] is tChannelA then
                  put true into tAOpen
               else
                  put true into tBOpen
               end if
               break
            case "dcMessage"
               -- (a text message arrives under "text", bytes under "payload")
               put tEvent["text"] into tGot
               put "done" into tStep
               break
         end switch
      end repeat
      if tStep is "opening" and tAOpen is true and tBOpen is true then
         get dcSendText(tChannelA, "hello across the channel")
         put "sent" into tStep
      end if
      wait kXtalkTick milliseconds with messages
   end repeat
   if tStep is "done" and tGot is "hello across the channel" and dcChannelLabel(tChannelB) is "oxt-beyond" then
      put "passed: two peers in the app negotiated, opened the channel" && quote & dcChannelLabel(tChannelB) & quote && \
            "and a message crossed it" into tAnswer
   else
      put "two peers in the app stopped at" && quote & tStep & quote && "(channel open at the offerer:" && \
            (tAOpen is true) & ", at the answerer:" && (tBOpen is true) & "; got" && quote & tGot & quote & "):" && \
            dcLastError() into tAnswer
   end if
   get dcClosePeer(tA)
   get dcClosePeer(tB)
   dcFreePeer tA
   dcFreePeer tB
   get dcCleanup()
   return tAnswer
end xtalkTestDataChannel

-- TorrentXT: a session starts and listens, a torrent is made of a file
-- the app wrote, added, checked and found complete (seeding), and the
-- session stops. Nothing is announced: no tracker, and the DHT is off
-- One event btPoll answered, in a few words, for a failure to say
private function xtalkTorrentEvent pEvent
   local tSaid
   put pEvent["name"] into tSaid
   if pEvent["state"] is not empty then put " to state" && pEvent["state"] after tSaid
   if pEvent["endpoint"] is not empty then put " on" && pEvent["endpoint"] after tSaid
   if pEvent["errorMessage"] is not empty then put ":" && pEvent["errorMessage"] after tSaid
   return tSaid
end xtalkTorrentEvent

-- Where a torrent is, for a failure to say: its state as libtorrent numbers
-- it (1 checking its files, 5 seeding), and the error that stopped it
private function xtalkTorrentIs pStatus
   return "state" && quote & pStatus["state"] & quote & ", progress" && pStatus["progress"] & \
         ", seeding" && quote & pStatus["isSeeding"] & quote & ", paused" && quote & pStatus["isPaused"] & quote & \
         ", flags" && pStatus["flags"] & ", error" && quote & pStatus["error"] & quote
end xtalkTorrentIs

function xtalkTestTorrent
   local tSession, tFolder, tContent, tTorrentData, tTorrent, tDeadline, tStatus, tKey, tAnswer, tPort, tHash
   local tEvent, tSaid, tEvents, tWas
   -- RFC 8032's first seed again: the DHT's keys are Ed25519
   put btDhtKeypair("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60") into tKey
   if not xtalkSame(tKey["publicKey"], "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a") then
      return "the DHT key of RFC 8032's first seed is" && tKey["publicKey"]
   end if
   put xtalkTestFolder() & "/xtalk-torrent" into tFolder
   if there is no folder tFolder then create folder tFolder
   put xtalkBytes(65, 100000) into tContent
   put tContent into url ("binfile:" & tFolder & "/content.bin")
   put btCreateTorrent(tFolder & "/content.bin", 0, 0, empty) into tTorrentData
   if the number of bytes of tTorrentData < 100 then
      get btLastError()
      delete file tFolder & "/content.bin"
      delete folder tFolder
      return "btCreateTorrent of a file in" && tFolder && "answered" && the number of bytes of tTorrentData && "bytes:" && it
   end if
   put btStartSession() into tSession
   if tSession <= 0 then
      get btLastError()
      delete file tFolder & "/content.bin"
      delete folder tFolder
      return "btStartSession:" && it
   end if
   -- it listens on the loopback alone, on a port the system picks
   btSetString tSession, "listen_interfaces", "127.0.0.1:0"
   btSetBool tSession, "enable_dht", false
   btSetBool tSession, "enable_lsd", false
   btSetBool tSession, "enable_upnp", false
   btSetBool tSession, "enable_natpmp", false
   put btAddTorrentFile(tSession, tTorrentData, tFolder) into tTorrent
   put the milliseconds + kXtalkWait into tDeadline
   repeat until the milliseconds > tDeadline or tTorrent <= 0
      -- what the session says while it works, each thing once: a torrent
      -- that never seeds is explained by these, or by their absence
      repeat for each element tEvent in btPoll(tSession)
         put xtalkTorrentEvent(tEvent) into tSaid
         if tSaid is not among the lines of tEvents and the number of lines of tEvents < 16 then
            put tSaid & return after tEvents
         end if
      end repeat
      put btTorrentStatus(tTorrent) into tStatus
      put btListenPort(tSession) into tPort
      -- (every status value is text: seeding is "1")
      if tStatus["isSeeding"] is 1 and tPort > 0 then exit repeat
      wait kXtalkTick milliseconds with messages
   end repeat
   put btInfoHash(tTorrent) into tHash
   if tTorrent > 0 and tStatus["isSeeding"] is 1 and tPort > 0 and the number of chars of tHash >= 40 then
      put "passed: a session listening on port" && tPort & ", a torrent made of a 100000-byte file in the app's folder," && \
            "checked and seeding (info hash" && char 1 to 8 of tHash & "...)" into tAnswer
   else
      put xtalkTorrentIs(tStatus) into tWas
      replace return with "; " in tEvents
      -- one more thing a failure can say: whether the torrent only waits to
      -- be started. An app's btResume starts a paused one
      if tTorrent > 0 then
         get btResume(tTorrent)
         put the milliseconds + 3000 into tDeadline
         repeat until the milliseconds > tDeadline
            get btPoll(tSession)
            wait kXtalkTick milliseconds with messages
         end repeat
         put btTorrentStatus(tTorrent) into tStatus
      end if
      put "a torrent of a file in" && tFolder && "is not seeding after" && kXtalkWait && "ms (handle" && tTorrent & \
            ", port" && tPort & "," && tWas & "; the session said:" && tEvents & \
            " and 3000 ms after a btResume it is at" && xtalkTorrentIs(tStatus) & "):" && btLastError() into tAnswer
   end if
   btStopSession tSession
   delete file tFolder & "/content.bin"
   delete folder tFolder
   return tAnswer
end xtalkTestTorrent

-- curlxt: a request made by libcurl to a server the app itself runs on
-- 127.0.0.1 with the engine's sockets. The server answers with what it was
-- asked, so the one response shows both directions: the request line and
-- a header arrived as sent, and the code, a header and the body came back.
-- On Android the library must also have found the system's certificates
-- (it says how many)
function xtalkTestCurl
   local tPort, tTry, tRequest, tDeadline, tEnded, tAnswer, tVersion, tCount, tCode, tBody
   -- (it answers the holds now taken, 1 or more)
   if cuInitialize() < 1 then return "cuInitialize:" && cuLastError()
   put cuLibraryVersion() into tVersion
   if the platform is "android" then
      if not matchText(tVersion, "Android CA store: ([0-9]+) certificates", tCount) or tCount < 20 then
         get cuCleanup()
         return "the library found no system certificates:" && tVersion
      end if
   end if
   repeat with tTry = 0 to kXtalkPortTries - 1
      put kXtalkHttpPort + tTry into tPort
      accept connections on port tPort with message "xtalkHttpAccepted"
      if the result is empty then exit repeat
      put empty into tPort
   end repeat
   if tPort is empty then
      get cuCleanup()
      return "no TCP port from" && kXtalkHttpPort && "could be listened on:" && the result
   end if
   put cuRequestNew("GET", "http://127.0.0.1:" & tPort & "/xtalk?probe=1") into tRequest
   get cuSetHeader(tRequest, "X-Oxt-Probe: curlxt")
   get cuStart(tRequest)
   -- curlxt has no thread of its own: a request moves only inside cuPoll,
   -- and the server only while the script waits with messages
   put the milliseconds + kXtalkWait into tDeadline
   put false into tEnded
   repeat until tEnded or the milliseconds > tDeadline or tRequest <= 0
      get cuPoll()
      if cuInfo(tRequest, "state") is 2 then put true into tEnded
      wait kXtalkTick milliseconds with messages
   end repeat
   put cuInfo(tRequest, "responseCode") into tCode
   put cuBody(tRequest) into tBody
   if tEnded and cuInfo(tRequest, "result") is 0 and tCode is 200 \
         and line 1 of tBody is "hello from the app" \
         and line 2 of tBody is "GET /xtalk?probe=1 HTTP/1.1" \
         and lineOffset("X-Oxt-Probe: curlxt", tBody) > 2 \
         and cuText(tRequest, "headers") contains "X-Oxt-Answer: yes" then
      put "passed: a GET to a server in the app on 127.0.0.1:" & tPort && "carried its header and brought back 200," && \
            "a header and the body" into tAnswer
      -- (a block: a one-line "if" here would take the "else" below as its own)
      if the platform is "android" then
         put ";" && tCount && "system certificates" after tAnswer
      end if
   else
      put "a GET to the app's own server on 127.0.0.1:" & tPort && "ended" && tEnded & ", result" && \
            cuInfo(tRequest, "result") & ", code" && tCode & ", body" && quote & line 1 to 2 of tBody & quote & ":" && \
            cuText(tRequest, "error") && cuLastError() into tAnswer
   end if
   get cuFree(tRequest)
   -- (a listening socket's name is its port)
   close socket tPort
   get cuCleanup()
   return tAnswer
end xtalkTestCurl

-- The curl test's server: one request read to its blank line, and one
-- answer, which carries the request back (its line feeds alone, so the
-- test reads it by line)
on xtalkHttpAccepted pSocket
   read from socket pSocket until crlf & crlf with message "xtalkHttpAsked"
end xtalkHttpAccepted

on xtalkHttpAsked pSocket, pRequest
   local tBody
   replace numToChar(13) with empty in pRequest
   put "hello from the app" & return & pRequest into tBody
   write "HTTP/1.1 200 OK" & crlf & "Content-Type: text/plain" & crlf & "X-Oxt-Answer: yes" & crlf & \
         "Content-Length:" && the number of bytes of tBody & crlf & "Connection: close" & crlf & crlf & tBody \
         to socket pSocket with message "xtalkHttpWritten"
end xtalkHttpAsked

on xtalkHttpWritten pSocket
   close socket pSocket
end xtalkHttpWritten

-- NostrXT, a script library over CoinXT and SodiumXT: a key made, an
-- event built, signed and verified (and refused once changed), an npub
-- that decodes to its key, and a NIP-44 message encrypted to another key
-- and decrypted by it
function xtalkTestNostr
   local tSecret, tPublic, tEvent, tOther, tOtherPublic, tPayload, tNpub
   put nxKeyGenerate() into tSecret
   put nxKeyPublic(tSecret) into tPublic
   if not nxKeyIsValid(tSecret) or the number of chars of tPublic is not 64 then
      return "a new key is not valid, or its public key is" && the number of chars of tPublic && "characters:" && nxLastError()
   end if
   put nxEventBuild(1, "hello from an Android app", empty, 1700000000) into tEvent
   put nxEventSign(tEvent, tSecret, empty) into tEvent
   if tEvent is not an array or not nxEventVerify(tEvent) then
      return "an event it signed does not verify:" && nxLastError()
   end if
   put "changed" into tEvent["content"]
   if nxEventVerify(tEvent) then
      return "an event verifies after its content changed"
   end if
   put nxNpubEncode(tPublic) into tNpub
   if not (tNpub begins with "npub1") or not xtalkSame(nxNpubDecode(tNpub), tPublic) then
      return "an npub does not decode to its key:" && tNpub
   end if
   if not nxNip44HasCipher() then
      return "NIP-44 has no cipher (SodiumXT's ChaCha20):" && nxLastError()
   end if
   put nxKeyGenerate() into tOther
   put nxKeyPublic(tOther) into tOtherPublic
   put nxNip44Encrypt(tSecret, tOtherPublic, "a private word", empty) into tPayload
   if tPayload is empty or nxNip44Decrypt(tOther, tPublic, tPayload) is not "a private word" then
      return "a NIP-44 message does not decrypt to what was encrypted:" && nxLastError()
   end if
   return "passed: a key, an event signed and verified (and refused once changed), an npub, a NIP-44 message encrypted and decrypted"
end xtalkTestNostr
