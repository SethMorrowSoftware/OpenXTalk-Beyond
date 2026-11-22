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
-- cryptography, a simulation stepped, a scene drawn from a model file, a
-- sound mixed with no device, a picture saved and loaded again, a
-- barcode read out of a picture, two ends of a connection inside the
-- one app exchanging bytes, a file written where an Android app may
-- write, a workbook read back cell for cell.
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
--     is not a failure. One listener is on every address the device has
--     (0.0.0.0), the torrent session's: finding those addresses is what
--     its test is for, and nothing is told its port.
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
-- in each one that waits, no address but 127.0.0.1 and the torrent
-- session's one 0.0.0.0. Every function here passed on a desktop engine
-- before it met an emulator: the probe's whole script, as
-- android-check.livecodescript makes it, on OXT-Beyond 0.2.8-dp.2's Linux
-- standalone engine run headless (-ui), with the suite's released
-- x86_64-linux libraries (2026-11-21).
-- xtalkTestTorrent as it is since 2026-11-22 (a session born paused fails,
-- and it listens on every address) passed the same way, and failed both
-- ways it should with the calls Android refuses an app refused by a
-- preloaded library: a session born paused when the netlink socket's bind
-- is refused, and a session listening on no port when only its listing of
-- the interfaces is.
-- xtalkTestAudio, added when audioxt joined, passed the same way on
-- 0.2.8-dp.1's Linux server engine: the probe's script made by those
-- functions from audioxt's two records alone, with the library of the
-- pinned commit (2026-11-21).
-- xtalkTestXlsx, added when xlsxt joined, passed the same way on
-- 0.2.8-dp.2's Linux standalone engine run headless (-ui): the probe's
-- script made by those functions from xlsxt's two records alone, with
-- the library of the pinned commit (2026-11-21).
-- xtalkTestRender3d, added when render3dxt joined, passed the same way
-- on 0.2.8-dp.1's Linux server engine: the probe's script made by those
-- functions from render3dxt's two records alone, with its binding
-- compiled from the pinned commit and that commit's x86_64-linux library
-- (2026-11-21).
-- xtalkTestWebp and xtalkTestBarcode, added when webpxt and barcodext
-- joined, passed the same way on 0.2.8-dp.1's Linux server engine: the
-- probe's script made by those functions from their four records alone,
-- with their bindings compiled from the pinned commit and that commit's
-- x86_64-linux libraries (2026-11-21). Each of their checks was then
-- broken in turn and failed, saying what it saw.

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

-- The SHA-1 of some bytes, in hex. Pixels are compared by theirs through
-- xtalkSame: bytes made text there compare as text, where case does not
-- count (a byte 65 would be a byte 97)
private function xtalkDigest pData
   local tHex
   get binaryDecode("H*", sha1Digest(pData), tHex)
   return tHex
end xtalkDigest

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

-- Box3Dxt: a ball of half a metre dropped onto a floor comes to rest on it,
-- in three dimensions. The mass is a known answer too: a ball of density 1
-- weighs its volume
function xtalkTestBox3d
   local tWorld, tFloor, tBall, tShape, tMass, tStart, tFell, tY
   -- one worker: the step runs on the thread that asks for it
   put b3WorldCreate(0, -10, 0, 1) into tWorld
   if tWorld <= 0 then return "b3WorldCreate answered" && tWorld & ":" && b3LastError()
   -- the floor's top is at 0: a box of half height 1 centred at -1
   put b3BodyCreate(tWorld, 0, 0, -1, 0) into tFloor
   get b3ShapeAddBox(tFloor, 20, 1, 20, 0, 0.6, 0)
   put b3BodyCreate(tWorld, 2, 0, 5, 0) into tBall
   put b3ShapeAddSphere(tBall, 0, 0, 0, 0.5, 1, 0.6, 0) into tShape
   if tFloor <= 0 or tBall <= 0 or tShape <= 0 then
      get b3LastError()
      b3WorldDestroy tWorld
      return "a floor, a ball and its shape answered" && tFloor & "," && tBall & "," && tShape & ":" && it
   end if
   put b3BodyMass(tBall) into tMass
   put b3BodyY(tBall) into tStart
   repeat 30 times
      b3WorldStep tWorld, 1 / 60, 4
   end repeat
   put b3BodyY(tBall) into tFell
   repeat 240 times
      b3WorldStep tWorld, 1 / 60, 4
   end repeat
   put b3BodyY(tBall) into tY
   b3WorldDestroy tWorld
   if tMass is not a number or abs(tMass - 4 / 3 * pi * 0.125) > 0.001 then
      return "a ball of radius 0.5 and density 1 weighs" && tMass & ", not" && 4 / 3 * pi * 0.125
   end if
   if tStart is not 5 or tFell is not a number or tFell > tStart - 0.5 then
      return "a ball dropped from" && tStart && "is at" && tFell && "after 30 steps: it has not fallen"
   end if
   if tY is not a number or abs(tY - 0.5) > 0.03 then
      return "a ball dropped from" && tStart && "onto a floor rests at" && tY & ", not 0.5"
   end if
   if b3WorldIsValid(tWorld) then return "the world is still there after b3WorldDestroy"
   return "passed: a ball dropped from 5 rests on the floor at" && round(tY, 3) && "after 270 steps, its mass" && round(tMass, 4)
end xtalkTestBox3d

-- One pixel of a picture as imageData (four bytes a pixel, the first
-- unused) as "red,green,blue", its x and y counted from 0
private function xtalkPixel pPicture, pWidth, pX, pY
   local tAt
   put (pY * pWidth + pX) * 4 into tAt
   return byteToNum(byte tAt + 2 of pPicture) & comma & byteToNum(byte tAt + 3 of pPicture) & comma & \
         byteToNum(byte tAt + 4 of pPicture)
end xtalkPixel

-- render3dxt: a scene drawn into a picture, as an app draws one for an
-- image. Unlit, a box has the desktop's colours exactly (its own at the
-- middle, the background at a corner) and a click finds it there. A
-- model, its material file and the picture that file names are written
-- where the app may write, and the library reads all three from there
-- (fast_obj and stb_image in it): the model is drawn in the picture's
-- colour, and a click finds it. Lit, the picture is the same drawn by one
-- thread and by four, begun and taken as a frame loop does. What the test
-- made is freed, the model's own material and texture with the model, and
-- the library holds nothing after
function xtalkTestRender3d
   local tThreads, tScene, tBox, tRed, tNode, tPlain, tMiddle, tCorner, tPicked, tDistance, tMissed
   local tFolder, tObj, tMtl, tTga, tWrote, tModel, tModelNode, tSlot, tSlotTexture, tTexName, tTexture
   local tTexSize, tTriangles, tSpot, tDrawn, tModelPixel, tModelPicked, tOne, tLitMiddle, tBegun, tFour, tCount
   local tModelError, tTextureError, tOneMix, tFourMix, tLeft, tError, tAnswer
   put r3ThreadCount() into tThreads
   put r3SceneCreate() into tScene
   if tScene <= 0 then return "r3SceneCreate answered" && tScene & ":" && r3LastError()
   put r3MeshBox(0.5, 0.5, 0.5) into tBox
   put r3MaterialCreate(255, 0, 0) into tRed
   r3MaterialSetUnlit tRed, true
   put r3NodeCreate(tScene, tBox) into tNode
   r3NodeSetMaterial tNode, tRed
   r3SceneSetCamera tScene, 0, 0, 5, 0, 0, 0, 50
   -- one thread. The colours, the click and how far it went are the
   -- desktop's (render3dxt's tests/engine-selftest.lc), as in the web
   -- IDE's check (web-ide-xtalk.livecodescript)
   r3SetThreadCount 1
   put r3SceneRender(tScene, 64, 48) into tPlain
   put xtalkPixel(tPlain, 64, 32, 24) into tMiddle
   put xtalkPixel(tPlain, 64, 1, 1) into tCorner
   put r3ScenePick(tScene, 64, 48, 32, 24) is tNode into tPicked
   put format("%.4f", item 4 of r3HitText()) into tDistance
   put r3ScenePick(tScene, 64, 48, 1, 1) into tMissed
   -- A model as an app ships one: a square a metre wide right of the box,
   -- facing the camera, in an OBJ file; the MTL file it names; and the
   -- TGA picture that names, two pixels by two of one colour (stored blue,
   -- green, red, alpha), so that wherever the square is sampled the
   -- answer is that colour
   put xtalkTestFolder() into tFolder
   put "mtllib xtalk-render3d.mtl" & lf & "v 1 -0.5 0" & lf & "v 2 -0.5 0" & lf & "v 2 0.5 0" & lf & \
         "v 1 0.5 0" & lf & "vt 0 0" & lf & "vt 1 0" & lf & "vt 1 1" & lf & "vt 0 1" & lf & "vn 0 0 1" & lf & \
         "usemtl tile" & lf & "f 1/1/1 2/2/1 3/3/1 4/4/1" & lf into tObj
   put "newmtl tile" & lf & "Kd 1 1 1" & lf & "map_Kd xtalk-render3d.tga" & lf into tMtl
   put numToByte(0) & numToByte(0) & numToByte(2) & xtalkBytes(0, 9) & numToByte(2) & numToByte(0) & \
         numToByte(2) & numToByte(0) & numToByte(32) & numToByte(40) into tTga
   repeat 4 times
      put numToByte(255) & numToByte(160) & numToByte(0) & numToByte(255) after tTga
   end repeat
   put tObj into url ("binfile:" & tFolder & "/xtalk-render3d.obj")
   put the result into tWrote
   put tMtl into url ("binfile:" & tFolder & "/xtalk-render3d.mtl")
   put the result after tWrote
   put tTga into url ("binfile:" & tFolder & "/xtalk-render3d.tga")
   put the result after tWrote
   put r3MeshLoadObj(tFolder & "/xtalk-render3d.obj") into tModel
   put r3LastError() into tModelError
   put r3MeshTriangleCount(tModel) into tTriangles
   put r3TextureLoad(tFolder & "/xtalk-render3d.tga") into tTexture
   put r3LastError() into tTextureError
   put r3TextureWidth(tTexture) & "x" & r3TextureHeight(tTexture) into tTexSize
   put r3MeshSlotMaterial(tModel, 1) into tSlot
   put r3MaterialTexture(tSlot) into tSlotTexture
   put r3MeshSlotTextureName(tModel, 1) into tTexName
   put r3NodeCreate(tScene, tModel) into tModelNode
   r3MaterialSetUnlit tSlot, true
   r3TextureSetSmooth tSlotTexture, false
   -- where the square's middle lands in the picture, and what is there
   put r3SceneProject(tScene, 64, 48, 1.5, 0, 0) into tSpot
   put r3SceneRender(tScene, 64, 48) into tDrawn
   put xtalkPixel(tDrawn, 64, trunc(item 1 of tSpot), trunc(item 2 of tSpot)) into tModelPixel
   put r3ScenePick(tScene, 64, 48, item 1 of tSpot, item 2 of tSpot) is tModelNode into tModelPicked
   -- Lit, and larger: drawn by one thread, then begun with four and taken
   -- as a frame loop takes it. The picture is the same either way
   r3MaterialSetUnlit tRed, false
   r3MaterialSetUnlit tSlot, false
   r3TextureSetSmooth tSlotTexture, true
   put r3SceneRender(tScene, 160, 120) into tOne
   put xtalkPixel(tOne, 160, 80, 60) into tLitMiddle
   r3SetThreadCount 4
   put r3ThreadCount() into tCount
   put r3SceneRenderBegin(tScene, 160, 120) into tBegun
   put r3SceneFrame(tScene) into tFour
   get binaryDecode("H*", sha1Digest(tOne), tOneMix)
   get binaryDecode("H*", sha1Digest(tFour), tFourMix)
   put r3LastError() into tError
   -- everything freed, the files gone and the threads as they were,
   -- before the answer
   r3SetThreadCount tThreads
   r3SceneDestroy tScene
   r3MeshDestroy tBox
   r3MaterialDestroy tRed
   r3MeshDestroy tModel
   r3TextureDestroy tTexture
   delete file tFolder & "/xtalk-render3d.obj"
   delete file tFolder & "/xtalk-render3d.mtl"
   delete file tFolder & "/xtalk-render3d.tga"
   put r3LiveCounts() into tLeft
   if the number of bytes of tPlain is not 64 * 48 * 4 then
      put "a picture of 64 by 48 came back as" && the number of bytes of tPlain && "bytes:" && tError into tAnswer
   else if tMiddle is not "255,0,0" or tCorner is not "31,33,41" then
      put "an unlit red box is" && tMiddle && "at the middle and the background" && tCorner && \
            "at a corner, not the desktop's 255,0,0 and 31,33,41" into tAnswer
   else if not tPicked or tDistance is not "4.5000" or tMissed is not 0 then
      put "a click at the middle found the box" && tPicked && "at" && tDistance && "metres (not 4.5), and one at the" && \
            "corner found" && tMissed into tAnswer
   else if tWrote is not empty then
      put "the model's files could not be written in" && tFolder & ":" && tWrote into tAnswer
   else if tModel <= 0 or tTriangles is not 2 then
      put "the model in" && tFolder && "loaded as" && tModel && "with" && tTriangles && "triangles:" && tModelError into tAnswer
   else if tTexName is not "xtalk-render3d.tga" or tSlotTexture <= 0 or tTexSize is not "2x2" then
      put "the model's material asked for" && quote & tTexName & quote & ", its texture is" && tSlotTexture & \
            ", and the picture read alone is" && tTexSize & ":" && tModelError && tTextureError into tAnswer
   else if tModelPixel is not "0,160,255" or not tModelPicked then
      put "the model is drawn" && tModelPixel && "at" && tSpot && "(not its picture's 0,160,255), found there by a click:" && \
            tModelPicked into tAnswer
   else if tLitMiddle is "255,0,0" or tCount is not 4 or tBegun is not 160 * 120 * 4 then
      put "lit, the box's middle is" && tLitMiddle & "; four threads asked for are" && tCount & ", and a picture" && \
            "begun says" && tBegun && "bytes" into tAnswer
   else if not xtalkSame(tFourMix, tOneMix) then
      put "a picture drawn by four threads is not the one drawn by one: their SHA-1s are" && tFourMix && "and" && \
            tOneMix into tAnswer
   else if tLeft is not "0,0,0,0,0,0" then
      put "after everything was freed the library still holds" && tLeft && "(scenes, nodes, meshes, materials," && \
            "textures, lights)" into tAnswer
   else
      put "passed: a box drawn unlit in the desktop's colours and found by a click; a model, its material and its" && \
            "picture read from the app's folder and drawn in its colour; lit, the same picture from one thread and" && \
            "four, begun and taken; nothing left (" & r3LibraryVersion() & ")" into tAnswer
   end if
   return tAnswer
end xtalkTestRender3d

-- audioxt: an engine with no sound device mixes a tone into samples, and
-- they are the desktop's bit for bit: the known answer is the SHA-1 of a
-- 440 Hz sine of amplitude 0.5, 800 frames of 16-bit stereo at 8000 Hz, on
-- OXT-Beyond's Linux server engine, which a browser's gives too (the web
-- IDE's check, web-ide-xtalk.livecodescript). A WAV file of them is written
-- where the app may write, decoded from there bit for bit, and played back
-- from it, streamed, through the same engine. Nothing is heard: no device
-- is opened, and the test only asks which audio system an app would use
function xtalkTestAudio
   local tEngine, tTone, tBlock, tMix, tTime, tPeak, tFolder, tWav, tBack, tBackMix
   local tWrote, tSound, tLength, tPlayed, tEnded, tSystem, tError, tAnswer
   put auEngineCreateOffline(8000, 2) into tEngine
   if tEngine <= 0 then return "auEngineCreateOffline answered" && tEngine & ":" && auLastError()
   put auSoundTone(tEngine, "sine", 440, 0.5) into tTone
   auSoundStart tTone
   put auEngineRender(tEngine, 800, "s16") into tBlock
   get binaryDecode("H*", sha1Digest(tBlock), tMix)
   put auEngineTime(tEngine) into tTime
   put auEnginePeak(tEngine) into tPeak
   auSoundFree tTone
   put xtalkTestFolder() into tFolder
   put auWAVEncode(tBlock, "s16", 8000, 2) into tWav
   put tWav into url ("binfile:" & tFolder & "/xtalk-audio.wav")
   put the result into tWrote
   put auDecodeFile(tFolder & "/xtalk-audio.wav", "s16", 0, 0) into tBack
   get binaryDecode("H*", sha1Digest(tBack), tBackMix)
   put auSoundLoad(tEngine, tFolder & "/xtalk-audio.wav", true) into tSound
   if tSound > 0 then
      put auSoundLength(tSound) into tLength
      auSoundStart tSound
      get auEngineRender(tEngine, 1000, "s16")
      put auEnginePeak(tEngine) into tPlayed
      put auSoundAtEnd(tSound) into tEnded
   end if
   put auLastError() into tError
   put auBackendName() into tSystem
   if tSystem is empty then put "none found" into tSystem
   -- every engine and sound closed, and the file gone, before the answer
   auShutDown
   delete file tFolder & "/xtalk-audio.wav"
   if the number of bytes of tBlock is not 3200 then
      put "800 frames of 16-bit stereo came back as" && the number of bytes of tBlock && "bytes:" && tError into tAnswer
   else if not xtalkSame(tMix, "6057c40db065f7ab02a05917470c3423288100f4") then
      put "a 440 Hz tone mixed with no device is not the desktop's: its SHA-1 is" && tMix into tAnswer
   else if format("%.4f", tTime) is not "0.1000" then
      put "the engine's clock reads" && tTime && "after 800 frames at 8000 Hz, not 0.1" into tAnswer
   else if format("%.2f,%.2f", item 1 of tPeak, item 2 of tPeak) is not "0.50,0.50" then
      put "the meter read" && tPeak && "for a tone at half scale" into tAnswer
   else if byte 1 to 4 of tWav is not "RIFF" or the number of bytes of tWav is not 3244 then
      put "a WAV file of the mix is" && the number of bytes of tWav && "bytes:" && tError into tAnswer
   else if tWrote is not empty then
      put "the WAV file could not be written in" && tFolder & ":" && tWrote into tAnswer
   else if not xtalkSame(tBackMix, tMix) then
      put "the WAV file in" && tFolder && "decoded to" && the number of bytes of tBack && \
            "bytes, not the mix bit for bit:" && tError into tAnswer
   else if tSound <= 0 then
      put "the WAV file in" && tFolder && "did not load as a streamed sound:" && tError into tAnswer
   else if format("%.3f", tLength) is not "0.100" or \
         format("%.2f,%.2f", item 1 of tPlayed, item 2 of tPlayed) is not "0.50,0.50" then
      put "the sound streamed from the file is" && tLength && "s long and played at" && tPlayed & \
            ", not 0.1 s at half scale" into tAnswer
   else if tEnded is not true then
      put "the sound streamed from the file had not reached its end after 1000 frames" into tAnswer
   else if auEngineIsValid(tEngine) then
      put "the engine is still there after auShutDown" into tAnswer
   else
      put "passed: a 440 Hz tone mixed with no device, the desktop's 800 frames bit for bit; a WAV file of" && \
            "them in the app's folder decoded bit for bit and streamed back at half scale (the audio system" && \
            "an app would play through:" && tSystem & ")" into tAnswer
   end if
   return tAnswer
end xtalkTestAudio

-- xlsxt: a workbook written where the app may write, and read back from
-- there cell for cell and as one grid: text outside ASCII and on two
-- lines, a number to its last digit (0.1 + 0.2, a double that only its
-- seventeenth digit tells apart from 0.3), a formula with the result
-- stored beside it, a date in a date format and a yes. The file is a zip,
-- as every .xlsx is. With no temporary folder chosen, xlsxt makes the
-- workbook's temporary files in the workbook's own folder on Android,
-- which gives an app no /tmp: this is where that is shown. Texts are
-- compared with the case of each letter (caseSensitive), and a number's
-- digits as text (xtalkSame). Nothing is left open: the workbook is closed
-- by writing it, the reader by xlReadClose, and the file deleted, before
-- the answer
function xtalkTestXlsx
   local tFolder, tWide, tBook, tSheet, tDated, tRefused, tRefusal, tWrote, tError, tFile, tReader
   local tOpenError, tSheets, tKinds, tWideBack, tLines, tNumber, tFormula, tResult, tDate, tFormat
   local tFlag, tGrid, tOpen, tAnswer
   set the caseSensitive to true
   put xtalkTestFolder() into tFolder
   -- built by number, since this file is ASCII: Latin-1, a snowman (three
   -- bytes of UTF-8) and a face outside the BMP (four)
   put "caf" & numToCodepoint(233) && numToCodepoint(9731) && numToCodepoint(128512) into tWide
   put xlWorkbookNew(tFolder & "/xtalk-xlsx.xlsx") into tBook
   if tBook <= 0 then return "xlWorkbookNew answered" && tBook & ":" && xlLastError()
   put xlWorkbookAddSheet(tBook, "Probe") into tSheet
   put xlWorkbookAddFormat(tBook) into tDated
   xlFormatSetNumberFormat tDated, "yyyy-mm-dd"
   xlSheetWriteText tSheet, 1, 1, tWide, 0
   xlSheetWriteText tSheet, 1, 2, "two" & numToChar(10) & "lines", 0
   xlSheetWriteNumber tSheet, 2, 1, 0.1 + 0.2, 0
   xlSheetWriteNumber tSheet, 2, 2, 1250.5, 0
   xlSheetWriteFormulaValue tSheet, 2, 3, "=B2*2", 2501, 0
   xlSheetWriteDate tSheet, 3, 1, xlDateToSerial(2026, 11, 21, 0, 0, 0), tDated
   xlSheetWriteBoolean tSheet, 3, 2, true, 0
   put xlWorkbookErrorCount(tBook) into tRefused
   put xlWorkbookFirstError(tBook) into tRefusal
   -- the call that writes the file; the workbook is closed whatever it
   -- answers
   put xlWorkbookClose(tBook) into tWrote
   put xlLastError() into tError
   put url ("binfile:" & tFolder & "/xtalk-xlsx.xlsx") into tFile
   put xlReadOpen(tFolder & "/xtalk-xlsx.xlsx") into tReader
   put xlLastError() into tOpenError
   put xlReadSheetCount(tReader) && xlReadSheetName(tReader, 1) into tSheets
   put xlReadCellKind(tReader, 1, 1, 1) && xlReadCellKind(tReader, 1, 2, 1) && xlReadCellKind(tReader, 1, 2, 3) && \
         xlReadCellKind(tReader, 1, 3, 1) && xlReadCellKind(tReader, 1, 3, 2) into tKinds
   put xlReadCell(tReader, 1, 1, 1) into tWideBack
   put xlReadCell(tReader, 1, 1, 2) into tLines
   put xlReadCell(tReader, 1, 2, 1) into tNumber
   put xlReadCellFormula(tReader, 1, 2, 3) into tFormula
   put xlReadCell(tReader, 1, 2, 3) into tResult
   put xlReadCell(tReader, 1, 3, 1) into tDate
   put xlReadCellFormat(tReader, 1, 3, 1) into tFormat
   put xlReadCell(tReader, 1, 3, 2) into tFlag
   put xlReadGrid(tReader, 1, 1, 1, 0, 0) into tGrid
   -- every workbook and reader closed, and the file gone, before the answer
   xlReadClose tReader
   put xlWorkbookCount() && xlReadCount() into tOpen
   delete file tFolder & "/xtalk-xlsx.xlsx"
   if tRefused is not 0 then
      put "the workbook refused" && tRefused && "calls, the first:" && tRefusal into tAnswer
   else if tWrote is not true then
      put "the workbook could not be written in" && tFolder & ":" && tError into tAnswer
   else if byte 1 to 4 of tFile is not ("PK" & numToByte(3) & numToByte(4)) then
      put "the file written in" && tFolder && "is" && the number of bytes of tFile && "bytes and not a zip" into tAnswer
   else if tReader <= 0 then
      put "the file written in" && tFolder && "did not open for reading:" && tOpenError into tAnswer
   else if tSheets is not "1 Probe" then
      put "the file has the sheets" && tSheets & ", not 1 Probe" into tAnswer
   else if tKinds is not "text number number date boolean" then
      put "the cells read back as" && tKinds & ", not text number number date boolean" into tAnswer
   else if tWideBack is not tWide then
      put "text outside ASCII came back as" && the number of codepoints of tWideBack && "characters:" && tWideBack into tAnswer
   else if tLines is not "two" & numToChar(10) & "lines" then
      put "text on two lines came back as" && the number of lines of tLines && "lines:" && tLines into tAnswer
   else if not xtalkSame(tNumber, "0.30000000000000004") then
      put "0.1 + 0.2 came back as" && tNumber && "and not to its last digit" into tAnswer
   else if tFormula is not "=B2*2" or not xtalkSame(tResult, "2501") then
      put "a formula came back as" && tFormula && "with the result" && tResult into tAnswer
   else if tDate is not "2026-11-21" or tFormat is not "yyyy-mm-dd" then
      put "a date came back as" && tDate && "in the format" && tFormat into tAnswer
   else if tFlag is not "true" then
      put "a yes came back as" && tFlag into tAnswer
   else if tGrid is not tWide & tab & "two" & numToChar(11) & "lines" & return & \
         "0.30000000000000004" & tab & "1250.5" & tab & "2501" & return & "2026-11-21" & tab & "true" then
      put "the sheet read as one grid is" && the number of lines of tGrid && "rows:" && tGrid into tAnswer
   else if tOpen is not "0 0" then
      put "workbooks and readers still open after the file was read:" && tOpen into tAnswer
   else
      put "passed: a workbook of" && the number of bytes of tFile && "bytes written in the app's folder, a zip," && \
            "read back cell for cell and as one grid: text outside ASCII and on two lines, 0.1 + 0.2 to its" && \
            "last digit, a formula with its result, a date in its format, a yes; nothing left open" into tAnswer
   end if
   return tAnswer
end xtalkTestXlsx

-- webpxt: a picture whose top half is see-through, saved as a lossless
-- WebP file where the app may write and decoded from what was read back
-- from there: every pixel that shows and every byte of its transparency
-- come back as they went in (the colour of a pixel that does not show is
-- libwebp's to drop). A lossy file keeps the colours near, a file is
-- decoded straight to half its size, an animation of three frames is
-- written and played back, and data that is not WebP is refused with a
-- reason, not a throw
function xtalkTestWebp
   local tRow, tPixels, tAlpha, tShown, tFile, tError, tFolder, tWrote, tRead, tInfo, tBack, tHalf
   local tLossy, tLossyInfo, tLossyBack, tNear, tBest, tRefused, tRefusal, tMoved, tWriter, tAdded
   local tFrames, tAnimation, tWriterOpen, tAnim, tAnimSays, tFrame, tSecond, tRewound, tOpen, tAnswer, tN
   -- 32 x 24 pixels, as an image's imageData (a byte unused, then red,
   -- green and blue): red at the left, blue at the right
   repeat 16 times
      put numToByte(255) & numToByte(200) & numToByte(40) & numToByte(30) after tRow
   end repeat
   repeat 16 times
      put numToByte(255) & numToByte(20) & numToByte(60) & numToByte(220) after tRow
   end repeat
   repeat 24 times
      put tRow after tPixels
   end repeat
   put xtalkBytes(0, 32 * 12) & xtalkBytes(255, 32 * 12) into tAlpha
   -- the bottom half, which shows
   put byte (32 * 12 * 4 + 1) to -1 of tPixels into tShown
   put wpEncodeLossless(tPixels, tAlpha, 32, 24) into tFile
   if tFile is empty then put wpLastError() into tError
   put xtalkTestFolder() into tFolder
   put tFile into url ("binfile:" & tFolder & "/xtalk-webp.webp")
   put the result into tWrote
   put url ("binfile:" & tFolder & "/xtalk-webp.webp") into tRead
   delete file tFolder & "/xtalk-webp.webp"
   put wpInfo(tRead) into tInfo
   put wpDecode(tRead) into tBack
   put wpDecodeScaled(tRead, 16, 0) into tHalf
   -- lossy: the first pixel still red and the last still blue
   put wpEncode(tPixels, empty, 32, 24, 80) into tLossy
   put wpInfo(tLossy) into tLossyInfo
   put wpDecode(tLossy) into tLossyBack
   put byteToNum(byte 2 of tLossyBack["imageData"]) > 150 and byteToNum(byte 4 of tLossyBack["imageData"]) < 90 \
         and byteToNum(byte -3 of tLossyBack["imageData"]) < 90 and byteToNum(byte -1 of tLossyBack["imageData"]) > 150 \
         into tNear
   put wpInfo(wpEncodeAdvanced(tPixels, empty, 32, 24, 100, true, 6)) into tBest
   put wpDecode("not a picture") into tRefused
   put wpLastError() into tRefusal
   -- an animation of three frames, each the picture moved 8 pixels along
   -- (equal frames would be written as one), played twice
   put tPixels into tMoved
   put true into tAdded
   put wpAnimEncoderCreate(32, 24, 2, 100, true) into tWriter
   repeat with tN = 1 to 3
      if not wpAnimEncoderAddFrame(tWriter, tMoved, empty, 40 * tN) then put false into tAdded
      put byte 33 to -1 of tMoved & byte 1 to 32 of tMoved into tMoved
   end repeat
   put wpAnimEncoderFrameCount(tWriter) into tFrames
   -- finishing closes the writer, whatever comes of it
   put wpAnimEncoderFinish(tWriter) into tAnimation
   put wpAnimEncoderIsValid(tWriter) into tWriterOpen
   put wpAnimOpen(tAnimation) into tAnim
   put wpAnimIsValid(tAnim) && wpAnimWidth(tAnim) && wpAnimHeight(tAnim) && wpAnimFrameCount(tAnim) && \
         wpAnimLoopCount(tAnim) into tAnimSays
   get wpAnimNextFrame(tAnim)
   put wpAnimNextFrame(tAnim) into tFrame
   put tFrame["index"] && tFrame["duration"] && byteToNum(byte (8 * 4 + 2) of tFrame["imageData"]) && \
         byteToNum(byte (7 * 4 + 2) of tFrame["imageData"]) into tSecond
   wpAnimRewind tAnim
   put wpAnimNextFrame(tAnim) into tFrame
   put tFrame["index"] into tRewound
   wpAnimClose tAnim
   put wpAnimOpenCount() && wpAnimEncoderOpenCount() into tOpen
   if tFile is empty then
      put "a picture of 32 x 24 pixels did not encode as lossless WebP:" && tError into tAnswer
   else if tWrote is not empty then
      put "the WebP file could not be written in" && tFolder & ":" && tWrote into tAnswer
   else if not xtalkSame(xtalkDigest(tRead), xtalkDigest(tFile)) then
      put "the WebP file in" && tFolder && "read back as" && the number of bytes of tRead && "bytes, not the" && \
            the number of bytes of tFile && "written" into tAnswer
   else if (byte 1 to 4 of tRead & byte 9 to 12 of tRead) is not "RIFFWEBP" then
      put "the file written does not start as a WebP file does" into tAnswer
   else if (tInfo["width"] && tInfo["height"] && tInfo["alpha"] && tInfo["animated"] && tInfo["frames"] && \
         tInfo["compression"]) is not "32 24 true false 1 lossless" then
      put "the file says it is" && tInfo["width"] && tInfo["height"] && tInfo["alpha"] && tInfo["animated"] && \
            tInfo["frames"] && tInfo["compression"] & ", not 32 24 true false 1 lossless" into tAnswer
   else if (tBack["width"] && tBack["height"] && the number of bytes of tBack["imageData"] && \
         the number of bytes of tBack["alphaData"]) is not "32 24 3072 768" then
      put "the file decoded to" && tBack["width"] && "x" && tBack["height"] && "pixels," && \
            the number of bytes of tBack["imageData"] && "bytes of colour and" && \
            the number of bytes of tBack["alphaData"] && "of transparency" into tAnswer
   else if not xtalkSame(xtalkDigest(byte (32 * 12 * 4 + 1) to -1 of tBack["imageData"]), xtalkDigest(tShown)) then
      put "the pixels that show did not come back from the lossless file as they went in" into tAnswer
   else if not xtalkSame(xtalkDigest(tBack["alphaData"]), xtalkDigest(tAlpha)) then
      put "the transparency did not come back from the lossless file as it went in" into tAnswer
   else if tBack["translucent"] is not true then
      put "a picture half see-through decoded as solid" into tAnswer
   else if (tHalf["width"] && tHalf["height"]) is not "16 12" then
      put "decoded straight to half its size, the picture is" && tHalf["width"] && "x" && tHalf["height"] into tAnswer
   else if (tLossyInfo["width"] && tLossyInfo["alpha"] && tLossyInfo["compression"]) is not "32 false lossy" \
         or not tNear then
      put "a lossy file of the picture says" && tLossyInfo["width"] && tLossyInfo["alpha"] && \
            tLossyInfo["compression"] && "and decodes with its first pixel" && \
            byteToNum(byte 2 of tLossyBack["imageData"]) & comma & byteToNum(byte 3 of tLossyBack["imageData"]) & \
            comma & byteToNum(byte 4 of tLossyBack["imageData"]) into tAnswer
   else if tBest["compression"] is not "lossless" then
      put "a file with every setting given (quality 100, lossless, effort 6) is" && tBest["compression"] into tAnswer
   else if tRefused is not empty or tRefusal is empty then
      put "data that is not WebP was not refused with a reason" into tAnswer
   else if not tAdded or tFrames is not 3 or tWriterOpen is not false then
      put "an animation's writer took" && tFrames && "frames of 3, or was still open once finished" into tAnswer
   else if tAnimSays is not "true 32 24 3 2" then
      put "the animation read back says" && tAnimSays & ", not 3 frames of 32 x 24 played twice" into tAnswer
   else if tSecond is not "2 80 20 200" then
      put "its second frame says" && tSecond & ", not frame 2, 80 ms, the picture moved 8 pixels along" into tAnswer
   else if tRewound is not 1 then
      put "rewound, the animation plays frame" && tRewound && "first" into tAnswer
   else if tOpen is not "0 0" then
      put "animations left open (read, written):" && tOpen into tAnswer
   else
      put "passed: a lossless WebP file saved in the app's folder and read back, every pixel that shows and" && \
            "its transparency exact; a lossy file near; decoded at half size; an animation of 3 frames" && \
            "written and played back; data that is not WebP refused" into tAnswer
   end if
   return tAnswer
end xtalkTestWebp

-- barcodext: a QR code made and read back out of a bigger picture that
-- holds it away from its corner, as a photo would: what it says and where
-- it is. Its squares are the desktop's: the known answer is the SHA-1 of
-- bcCreateMatrix's rows on OXT-Beyond's Linux server engine. A product
-- barcode's check digit is worked out and read back, bytes with a zero
-- among them are kept whole, and text a kind cannot hold is refused with
-- a reason, not a throw
function xtalkTestBarcode
   local tPicture, tError, tWhite, tPage, tY, tFound, tSays, tRows, tRowsMix, tProduct, tProductSays
   local tOther, tBinary, tBytes, tLevel, tRefused, tRefusal, tAnswer
   put bcCreate("OXT-Beyond xTalk Suite", "QR Code", 4) into tPicture
   if tPicture is empty then put bcLastError() into tError
   -- a white page of 220 x 180 pixels, the code's 132 x 132 at 40,20
   put xtalkBytes(255, 220 * 4) into tWhite
   repeat 20 times
      put tWhite after tPage
   end repeat
   repeat with tY = 0 to 131
      put byte 1 to (40 * 4) of tWhite & byte (tY * 132 * 4 + 1) to ((tY + 1) * 132 * 4) of tPicture["imageData"] & \
            byte 1 to (48 * 4) of tWhite after tPage
   end repeat
   repeat 28 times
      put tWhite after tPage
   end repeat
   put bcRead(tPage, 220, 180) into tFound
   put the number of elements of tFound && tFound[1]["format"] && tFound[1]["text"] && tFound[1]["valid"] && \
         tFound[1]["position"] into tSays
   put bcCreateMatrix("OXT-Beyond xTalk Suite", "QR Code", empty) into tRows
   put xtalkDigest(tRows) into tRowsMix
   -- an EAN-13 with its digits printed under it: the check digit is the
   -- library's to work out
   put bcCreateAdvanced("590123412345", "EAN-13", empty, 2, true, true) into tProduct
   put bcReadFormats(tProduct["imageData"], tProduct["width"], tProduct["height"], "EAN-13") into tFound
   put tFound[1]["format"] && tFound[1]["text"] into tProductSays
   put the number of elements of bcReadFormats(tProduct["imageData"], tProduct["width"], tProduct["height"], \
         "QR Code") into tOther
   put bcCreateFromData(numToByte(0) & numToByte(255) & numToByte(16) & "x", "QR Code", "ecLevel=H", 3) into tBinary
   put bcReadAdvanced(tBinary["imageData"], tBinary["width"], tBinary["height"], "QR Code", "pure") into tFound
   get binaryDecode("H*", tFound[1]["bytes"], tBytes)
   put tFound[1]["ecLevel"] into tLevel
   put bcCreate("not digits", "EAN-13", 3) into tRefused
   put bcLastError() into tRefusal
   if (tPicture["width"] && tPicture["height"] && the number of bytes of tPicture["imageData"]) \
         is not "132 132 69696" then
      put "a QR code's picture is" && tPicture["width"] && "x" && tPicture["height"] && "pixels in" && \
            the number of bytes of tPicture["imageData"] && "bytes:" && tError into tAnswer
   else if tSays is not "1 QR Code OXT-Beyond xTalk Suite true 56,36,156,36,156,136,56,136" then
      put "read out of a picture of 220 x 180 that holds it at 40,20, the QR code says" && tSays into tAnswer
   else if the number of lines of tRows is not 25 or \
         not xtalkSame(tRowsMix, "4cde1af2ba749c8397dd21bfa6d2eb0bc1473513") then
      put "the QR code's squares are not the desktop's: the SHA-1 of its" && the number of lines of tRows && \
            "rows is" && tRowsMix into tAnswer
   else if tProductSays is not "EAN-13 5901234123457" or tOther is not 0 then
      put "an EAN-13 of 590123412345 read back as" && tProductSays & ", and as" && tOther && "QR codes" into tAnswer
   else if not xtalkSame(tBytes, "00ff1078") or tLevel is not "H" then
      put "the bytes 00 ff 10 78 came back as" && tBytes && "at error correction level" && tLevel into tAnswer
   else if tRefused["width"] is not empty or tRefusal is empty then
      put "text an EAN-13 cannot hold was not refused with a reason" into tAnswer
   else
      put "passed: a QR code read out of a bigger picture where it was put, its squares the desktop's; an" && \
            "EAN-13's check digit worked out; bytes with a zero among them kept whole; text an EAN-13" && \
            "cannot hold refused" into tAnswer
   end if
   return tAnswer
end xtalkTestBarcode

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

-- TorrentXT: a session starts, is not paused and listens on every address
-- the device has; a torrent is made of a file the app wrote, added,
-- checked and found complete (seeding); and the session stops. Nothing is
-- announced: no tracker, and the DHT is off
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
   -- It listens on every address the device has, on a port the system
   -- picks, and nothing tells anyone that port: no tracker, no DHT, no
   -- discovery on the local network, no router asked. The address is the
   -- unspecified one because finding the device's addresses behind it is
   -- half of what this test is for (below); on the loopback alone a
   -- library that finds none of them would pass
   btSetString tSession, "listen_interfaces", "0.0.0.0:0"
   btSetBool tSession, "enable_dht", false
   btSetBool tSession, "enable_lsd", false
   btSetBool tSession, "enable_upnp", false
   btSetBool tSession, "enable_natpmp", false
   -- A session born paused is a failure, and so is one that listens
   -- nowhere. On the Android 13 emulator the torrent of this test stayed
   -- at "checking its files", progress 0, for the whole wait (2026-11-21),
   -- beside the system's refusal of a netlink socket to the app (avc:
   -- denied { bind } and { nlmsg_readpriv } ... netlink_route_socket). As
   -- read in libtorrent 2.0.11: built for an Android older than 7.0 (API
   -- 24) it learns the device's addresses and watches them change over
   -- such a socket, Android 11 and later refuse an app both, the session
   -- answers the error in its own start by pausing itself, and a paused
   -- session checks nothing and seeds nothing; with no addresses found,
   -- "every address" opens no socket either. Built for API 24 it asks
   -- getifaddrs() and opens no such socket, and those are the libraries
   -- pinned here since 2026-11-22 (TorrentXT at fb2debf, the xTalk
   -- Suite's release run 44914897842). Until then this test resumed the
   -- session itself, listened on 127.0.0.1 and said in its answer that it
   -- had to. It resumes nothing now: an app should not have to
   if btSessionIsPaused(tSession) then
      btStopSession tSession
      delete file tFolder & "/content.bin"
      delete folder tFolder
      return "btStartSession answered a session that is paused, and a paused session checks and seeds nothing:" && \
            "on Android 11 and later that is a torrentxt library built for an Android older than 7.0 (API 24)," && \
            "refused the netlink socket it asks for"
   end if
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
      put "passed: a session not paused at its start and listening on every address on port" && tPort & \
            ", a torrent made of a 100000-byte file in the app's folder," && \
            "checked and seeding (info hash" && char 1 to 8 of tHash & "...)" into tAnswer
   else
      put xtalkTorrentIs(tStatus) into tWas
      replace return with "; " in tEvents
      if tTorrent > 0 and tStatus["isSeeding"] is 1 and tPort <= 0 then
         -- checked and seeding, and nobody could reach it: "every address"
         -- found none, or none could be listened on (the session says
         -- which, when it says listenFailed)
         put "the session listens on no port after" && kXtalkWait && "ms, though its torrent of a file in" && tFolder && \
               "is seeding (handle" && tTorrent & "," && tWas & "; the session said:" && tEvents & "):" && btLastError() into tAnswer
      else
         -- one more thing a failure can say: whether the torrent only waits
         -- to be started. An app's btResume starts a paused one
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
