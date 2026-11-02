script "OXTExampleLearnSodiumXT"
-- OXT-Beyond: builds "Learn SodiumXT", thirteen lessons in SodiumXT, the
-- xTalk Suite's cryptography extension (libsodium), which OXT-Beyond has
-- built in (https://github.com/SethMorrowSoftware/xtalk-suite, sodiumxt/).
--
-- It is one of the "Learn" stacks (builder.livecodescript, "Learn stacks"):
-- each lesson says what it shows in plain words, and runs a real script
-- that calls SodiumXT, which the user can change, run again and copy; a
-- click on a call opens its page of the reference, and the Reference card
-- has every SodiumXT handler, from the IDE's Dictionary. The lessons'
-- words, scripts and expected results are the blocks at the end of this
-- script. test-learn-stacks.livecodescript (in tools/examples) runs every
-- lesson's script on a real engine with SodiumXT loaded and checks its
-- result.

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex, tLessons
   exUseScripts the script of me
   exAddIcon "shield", "<path d='M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z'/>"
   exAddIcon "tag", "<path d='M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z'/>" & \
         "<circle cx='7.5' cy='7.5' r='.5' fill='currentColor'/>"
   exAddIcon "stamp", "<path d='M5 22h14'/><path d='M19.27 13.73A2.5 2.5 0 0 0 17.5 13h-11A2.5 2.5 0 0 0 4 15.5V17a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-1.5c0-.66-.26-1.3-.73-1.77Z'/>" & \
         "<path d='M14 13V8.5C14 7 15 7 15 5a3 3 0 0 0-3-3c-1.69 0-3 1-3 3s1 2 1 3.5V13'/>"
   exAddIcon "waves", "<path d='M2 6c.6.5 1.2 1 2.5 1C7 7 7 5 9.5 5c2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/>" & \
         "<path d='M2 12c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/>" & \
         "<path d='M2 18c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/>"
   put "Learn SodiumXT" into tInfo["name"]
   put "libsodium, through SodiumXT" into tInfo["credit"]
   put "shield" into tInfo["icon"]
   put lkColor("indigo") into tInfo["accent"]
   put lkColor("violet") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn SodiumXT|Keep data secret, and prove it is genuine.|shield|front" & return & \
         "Random|Random Numbers|Keys and dice nobody can predict.|dices|page" & return & \
         "Bytes|Bytes and Text|Text becomes bytes, and bytes become safe letters.|type|page" & return & \
         "Hashes|Fingerprints|A short code that changes if anything changes.|hash|page" & return & \
         "Seals|Seals|Fingerprints only someone with the key can make.|stamp|page" & return & \
         "Passwords|Passwords|Store a password safely, and check it later.|key-round|page" & return & \
         "Boxes|Secret Boxes|Lock a message with a key, and notice tampering.|lock|page" & return & \
         "Labels|Boxes with Labels|A readable label, tied to a locked message.|tag|page" & return & \
         "Public|Public-key Boxes|Write to someone with only their public key.|send|page" & return & \
         "Signing|Signatures|Prove who wrote something, and that it is unchanged.|pen-line|page" & return & \
         "Exchange|Key Exchange|Two people agree on secret keys in the open.|users|page" & return & \
         "Files|Files|Lock and fingerprint whole files of any size.|file-text|page" & return & \
         "Streams|Streams|Lock data that arrives in pieces, in order.|waves|page" & return & \
         "Subkeys|Subkeys and Padding|Many keys from one, and lengths that tell less.|layers|page" & return & \
         "Reference|Reference|Every SodiumXT handler: what it takes and gives back.|book-open|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   exLearnDocs "org.openxtalk.library.sodium"
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      put exCardInfo(tIndex, "name") & comma after tLessons
   end repeat
   delete the last char of tLessons
   exLearnKit "Start", tLessons, "SodiumXT", "sxVersion()", "lcb|org.openxtalk.library.sodium|sodiumxt"
   repeat for each item tIndex in tLessons
      if tIndex is not "Reference" then
         exLearnLesson tIndex
      end if
   end repeat
   exLearnReference "Reference"
   exLearnFront "OXT-BEYOND  " & numToCodepoint(183) & "  LIBSODIUM THROUGH SODIUMXT", \
         "Cryptography, one idea at a time", \
         "Thirteen short lessons in keeping data secret, and proving it genuine. " & \
         "Each runs a real script that you can change, run again and copy.", \
         "lightbulb|Each lesson starts in plain words. No maths needed." & return & \
         "play|Press Run to run the script for real. Change it, and run it again." & return & \
         "book-open|Click a call to read its parameters, units and result."
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn SodiumXT.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

/*@ stack
-- Learn SodiumXT: thirteen lessons in SodiumXT, the xTalk Suite's
-- cryptography extension. The lessons are run by the script of the group
-- "Learn", and the window by the script of the group "Frame". It was built
-- by tools/examples/learn-sodiumxt.livecodescript in the OXT-Beyond
-- repository; build it again rather than change it here.
@*/

/*@ Random/words
Computers are bad at guessing. An ordinary random function can follow a pattern that someone could work out: fine for a game, not for a password or a key.

`sxRandomBytes` asks the computer's secure random source for bytes that nobody can predict. `sxRandomUniform` rolls a fair die with as many sides as you like.

- Bytes print as gibberish, so `sxBin2Hex` shows them as hex, two letters a byte.
- Press Run a few times: the answer is new each time.
@*/

/*@ Random/try
on mouseUp
   local tKey, tDie, tOut
   -- 16 bytes that nobody can guess: a new key
   put sxRandomBytes(16) into tKey
   put "16 random bytes, in hex:" & cr after tOut
   put sxBin2Hex(tKey) & cr & cr after tOut
   -- a fair die: 0 to 5, plus 1
   put sxRandomUniform(6) + 1 into tDie
   put "You rolled a" && tDie after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Random/expect
^16 random bytes, in hex:\n[0-9a-f]{32}\n\nYou rolled a [1-6]$
@*/

/*@ Bytes/words
Locks and fingerprints work on **bytes**, not letters. Before you lock a message, `textEncode` turns its text into bytes; after you open it, `textDecode` turns them back. Use "utf-8", and every language survives.

Raw bytes are not safe in an email or a field. Hex and base64 spell them in plain letters:

- `sxBin2Hex` and `sxHex2Bin`: two letters a byte, easy to read.
- `sxBin2Base64` and `sxBase642Bin`: shorter, four letters for three bytes.
@*/

/*@ Bytes/try
on mouseUp
   local tBytes, tHex, tBase64, tBack, tOut
   put textEncode("Hello, world", "utf-8") into tBytes
   get the number of bytes in tBytes
   put "Bytes:  " & it & cr after tOut
   -- as hex, and as base64
   put sxBin2Hex(tBytes) into tHex
   put sxBin2Base64(tBytes) into tBase64
   put "Hex:    " & tHex & cr after tOut
   put "Base64: " & tBase64 & cr after tOut
   -- and back again
   put sxHex2Bin(tHex) into tBack
   put "Back:   " & textDecode(tBack, "utf-8") after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Bytes/expect
^Bytes:  12\nHex:    48656c6c6f2c20776f726c64\nBase64: SGVsbG8sIHdvcmxk\nBack:   Hello, world$
@*/

/*@ Hashes/words
A hash is a fingerprint for data. Give it a word, a photo or a film, and it gives back a short code, always the same size.

- The same data always gives the same fingerprint.
- Change one letter, and the fingerprint is completely different.
- Nobody can work back from a fingerprint to the data.

Use one to check a download. `sxHash` is BLAKE2b, fast and modern; `sxSha3_256` is SHA-3, which many programs use.
@*/

/*@ Hashes/try
on mouseUp
   local tCat, tBat, tHex, tOut
   put sxHash(textEncode("cat", "utf-8"), 32) into tCat
   put sxHash(textEncode("bat", "utf-8"), 32) into tBat
   -- 32 bytes are 64 letters of hex: show the first 24
   put sxBin2Hex(tCat) into tHex
   put "cat: " & char 1 to 24 of tHex & cr after tOut
   put sxBin2Hex(tBat) into tHex
   put "bat: " & char 1 to 24 of tHex & cr after tOut
   -- are they the same? (compare with sxMemEqual)
   put "Same? " & sxMemEqual(tCat, tBat) & cr after tOut
   -- SHA-3, another common fingerprint
   get sxSha3_256(textEncode("cat", "utf-8"))
   get char 1 to 24 of sxBin2Hex(it)
   put "SHA-3: " & it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Hashes/expect
^cat: [0-9a-f]{24}\nbat: [0-9a-f]{24}\nSame\? false\nSHA-3: [0-9a-f]{24}$
@*/

/*@ Seals/words
Anyone can make a plain fingerprint. A **keyed** fingerprint, a seal, also needs a secret key, so only someone with the key can make one that matches. It is like a wax seal that only you and a friend can press.

- `sxHashKeyed` makes a BLAKE2b seal. `sxHmacSha256` makes the HMAC-SHA256 seal that many web services ask for.
- Check a seal with `sxMemEqual`, not `is`: it takes as long however much matches, so it gives nothing away.
@*/

/*@ Seals/try
on mouseUp
   local tKey, tMsg, tSeal, tCheck, tOut
   put sxRandomBytes(32) into tKey
   put textEncode("Pay Sam 10 dollars", "utf-8") into tMsg
   put sxHashKeyed(tMsg, tKey, 32) into tSeal
   get char 1 to 24 of sxBin2Hex(tSeal)
   put "Seal: " & it & cr after tOut
   -- someone changes the message...
   put textEncode("Pay Sam 99 dollars", "utf-8") into tMsg
   put sxHashKeyed(tMsg, tKey, 32) into tCheck
   get sxMemEqual(tSeal, tCheck)
   put "Seal still fits? " & it & cr after tOut
   -- the HMAC-SHA256 seal of the new message
   get sxBin2Hex(sxHmacSha256(tKey, tMsg))
   put "HMAC: " & char 1 to 24 of it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Seals/expect
^Seal: [0-9a-f]{24}\nSeal still fits\? false\nHMAC: [0-9a-f]{24}$
@*/

/*@ Passwords/words
Never keep a password itself: if the file leaks, every password leaks. Keep a password **hash**, and check what someone types against it.

`sxPwHashStr` uses Argon2id, slow and memory-hungry on purpose, so guessing millions of passwords costs an attacker a fortune. It gives one string, with a random salt and its settings in it: that is all you store.

- `sxPwHashStrVerify` says whether a password matches.
- `sxPwHash` turns a passphrase into a key.
@*/

/*@ Passwords/try
on mouseUp
   local tTyped, tStored, tOk, tOut
   -- when someone signs up, keep only tStored
   put textEncode("correct horse", "utf-8") into tTyped
   get sxPwMemInteractive()
   put sxPwHashStr(tTyped, "2", it) into tStored
   put textDecode(tStored, "utf-8") into tOut
   put char 1 to 31 of tOut & "..." & cr & cr into tOut
   -- when they sign in, check what they typed
   put sxPwHashStrVerify(tStored, tTyped) into tOk
   put "Right password: " & tOk & cr after tOut
   put textEncode("horse battery", "utf-8") into tTyped
   put sxPwHashStrVerify(tStored, tTyped) into tOk
   put "Wrong password: " & tOk after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Passwords/expect
^\$argon2id\$v=19\$m=65536,t=2,p=1\$\.\.\.\n\nRight password: true\nWrong password: false$
@*/

/*@ Boxes/words
A secret box is a locked box with one key. With the key you can lock a message in, or open it. Without it, the box is noise.

It also notices tampering: change one byte, and it refuses to open, rather than give you back nonsense.

- The key is 32 random bytes. Share it only with whoever must read.
- `sxSecretBox` locks. `sxSecretBoxOpen` opens, or stops with an error when the key is wrong or the box was changed: catch it with `try`.
@*/

/*@ Boxes/try
on mouseUp
   local tKey, tMsg, tBox, tBack, tOut, tError
   put sxRandomBytes(32) into tKey
   put textEncode("Meet at noon", "utf-8") into tMsg
   put sxSecretBox(tMsg, tKey) into tBox
   get the number of bytes in tBox
   put "Locked: " & it && "bytes of noise" & cr after tOut
   put sxSecretBoxOpen(tBox, tKey) into tBack
   put textDecode(tBack, "utf-8") into tBack
   put "Opened: " & tBack & cr after tOut
   -- change one byte of the box, and try again
   get byteToNum(byte 30 of tBox)
   put numToByte((it + 1) mod 256) into byte 30 of tBox
   try
      put sxSecretBoxOpen(tBox, tKey) into tBack
      put "Changed box: opened?!" after tOut
   catch tError
      put "Changed box: will not open" after tOut
   end try
   put tOut into field "Result"
end mouseUp
@*/

/*@ Boxes/expect
^Locked: 52 bytes of noise\nOpened: Meet at noon\nChanged box: will not open$
@*/

/*@ Labels/words
Sometimes part of a message must stay readable, like the address on an envelope, but nobody may swap it. `sxAeadEncrypt` locks the message and **ties** a readable label to it (its "associated data").

The label is not in the box, so send it alongside. To open the box, `sxAeadDecrypt` needs the very same label: change it, and the box will not open.

Use it for a message's number, a user's name or a file's name, so that nobody can move a locked box to the wrong place.
@*/

/*@ Labels/try
on mouseUp
   local tKey, tLabel, tMsg, tBox, tBack, tOut, tError
   put sxRandomBytes(32) into tKey
   put textEncode("to: Sam, note 7", "utf-8") into tLabel
   put textEncode("Gate code: 4417", "utf-8") into tMsg
   put sxAeadEncrypt(tMsg, tLabel, tKey) into tBox
   -- open it with its own label
   put sxAeadDecrypt(tBox, tLabel, tKey) into tBack
   get textDecode(tBack, "utf-8")
   put "Own label: " & it & cr after tOut
   -- and with another label
   put textEncode("to: Max, note 7", "utf-8") into tLabel
   try
      put sxAeadDecrypt(tBox, tLabel, tKey) into tBack
      put "Another label: opened?!" after tOut
   catch tError
      put "Another label: will not open" after tOut
   end try
   put tOut into field "Result"
end mouseUp
@*/

/*@ Labels/expect
^Own label: Gate code: 4417\nAnother label: will not open$
@*/

/*@ Public/words
With a secret box, both people need the same key, and handing it over safely is the hard part. Public-key boxes solve that. Each person makes a **keypair**: a public key for anyone, and a secret key to keep.

- `sxBox` locks a message for one person, with your secret key and their public key. `sxBoxOpen` opens it, and proves who sent it.
- `sxSeal` needs only their public key: like a postbox, anyone can post, only the owner can open, and the sender stays unknown.
@*/

/*@ Public/try
on mouseUp
   local tAnnPublic, tAnnSecret, tBobPublic, tBobSecret
   local tMsg, tBox, tBack, tOut
   sxBoxKeypair tAnnPublic, tAnnSecret
   sxBoxKeypair tBobPublic, tBobSecret
   -- Ann writes to Bob
   put textEncode("Hi Bob, it is Ann", "utf-8") into tMsg
   put sxBox(tMsg, tBobPublic, tAnnSecret) into tBox
   -- Bob opens it with Ann's public key, his secret key
   put sxBoxOpen(tBox, tAnnPublic, tBobSecret) into tBack
   get textDecode(tBack, "utf-8")
   put "Bob reads: " & it & cr into tOut
   -- anyone can seal a note that only Bob can open
   put textEncode("A secret tip", "utf-8") into tMsg
   put sxSeal(tMsg, tBobPublic) into tBox
   put sxSealOpen(tBox, tBobPublic, tBobSecret) into tBack
   put textDecode(tBack, "utf-8") into tBack
   put "Sealed note: " & tBack after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Public/expect
^Bob reads: Hi Bob, it is Ann\nSealed note: A secret tip$
@*/

/*@ Signing/words
A signature proves who wrote something, and that nobody has changed it since. It hides nothing. You sign with your **secret** key, and anyone with your **public** key can check.

- `sxSignKeypair` makes a signing keypair.
- `sxSignDetached` gives a 64-byte signature, to send with the message.
- `sxSignVerifyDetached` says true only when the message is exactly what was signed.

Software updates, licences and Nostr posts are all signed this way.
@*/

/*@ Signing/try
on mouseUp
   local tPub, tSec, tMsg, tSig, tOk, tOut
   sxSignKeypair tPub, tSec
   put textEncode("Version 2.0 is out", "utf-8") into tMsg
   put sxSignDetached(tMsg, tSec) into tSig
   get the number of bytes in tSig
   put "Signature: " & it && "bytes" & cr after tOut
   -- anyone with the public key can check it
   put sxSignVerifyDetached(tSig, tMsg, tPub) into tOk
   put "Genuine? " & tOk & cr after tOut
   -- a changed message fails the check
   put textEncode("Version 6.6 is out", "utf-8") into tMsg
   put sxSignVerifyDetached(tSig, tMsg, tPub) into tOk
   put "Changed, genuine? " & tOk after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Signing/expect
^Signature: 64 bytes\nGenuine\? true\nChanged, genuine\? false$
@*/

/*@ Exchange/words
Public-key boxes are slow for a long chat. With a key exchange, two people each mix their own keypair with the other's public key, and both get the **same** fast secret keys, without ever sending them.

- One side plays the client, the other the server: any two apps can.
- Each gets a key to send with and a key to receive with. The client's send key is the server's receive key.
- Then lock messages with secret boxes and those keys.
@*/

/*@ Exchange/try
on mouseUp
   local tCPub, tCSec, tSPub, tSSec
   local tCRx, tCTx, tSRx, tSTx
   local tBox, tOut
   sxKeyExchangeKeypair tCPub, tCSec
   sxKeyExchangeKeypair tSPub, tSSec
   -- each side needs only the other's public key
   sxKeyExchangeClient tCPub, tCSec, tSPub, tCRx, tCTx
   sxKeyExchangeServer tSPub, tSSec, tCPub, tSRx, tSTx
   get sxMemEqual(tCTx, tSRx)
   put "Same key at both ends? " & it & cr after tOut
   -- the client locks with its send key...
   get textEncode("hello, server", "utf-8")
   put sxSecretBox(it, tCTx) into tBox
   -- ...and the server opens with its receive key
   get sxSecretBoxOpen(tBox, tSRx)
   put textDecode(it, "utf-8") into tBox
   put "Server reads: " & tBox after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Exchange/expect
^Same key at both ends\? true\nServer reads: hello, server$
@*/

/*@ Files/words
A big file may not fit in memory twice. `sxEncryptFile` and `sxDecryptFile` lock and unlock a whole file of any size, a piece at a time, so its bytes never pass through your variables. The locked file notices tampering, as a secret box does.

`sxHashFile` gives the fingerprint of a whole file, to check that a copy or a download is the same.

The script writes three small files to the temporary folder, and deletes them again.
@*/

/*@ Files/try
on mouseUp
   local tKey, tFile, tSame, tOut
   put sxRandomBytes(32) into tKey
   put specialFolderPath("temporary") into tFile
   put "/learn-sodium" after tFile
   get "Dear diary: crypto is fun."
   put it into url ("file:" & tFile)
   -- lock the file, then unlock the locked copy
   sxEncryptFile tFile, tFile & ".locked", tKey
   sxDecryptFile tFile & ".locked", tFile & ".back", tKey
   get url ("binfile:" & tFile & ".locked")
   get the number of bytes in it
   put "Locked:" && it && "bytes" & cr after tOut
   get url ("file:" & tFile & ".back")
   put "Unlocked: " & it & cr after tOut
   -- the same fingerprint means the same bytes
   get sxHashFile(tFile & ".back", 32)
   put sxMemEqual(sxHashFile(tFile, 32), it) into tSame
   put "Same as before? " & tSame after tOut
   delete file tFile
   delete file (tFile & ".locked")
   delete file (tFile & ".back")
   put tOut into field "Result"
end mouseUp
@*/

/*@ Files/expect
^Locked: [0-9]+ bytes\nUnlocked: Dear diary: crypto is fun\.\nSame as before\? true$
@*/

/*@ Streams/words
Data from a network or a recording arrives in pieces. A **secret stream** locks each piece with one key, in order, and marks the last. The reader opens them in the same order, and notices a piece missing, swapped or repeated, or a stream cut short.

- `sxSecretStreamInitPush` starts one, with a header to send first.
- `sxSecretStreamPush` locks a piece: true for the last.
- `sxSecretStreamPull` opens one; `sxIsFinalTag` says if it was the last.
- `sxFreeStream` when you are done.
@*/

/*@ Streams/try
on mouseUp
   local tKey, tHeader, tS, tOne, tTwo, tTag, tBack, tOut
   put sxRandomBytes(32) into tKey
   -- the sender locks two pieces: true for the last
   put sxSecretStreamInitPush(tKey, tHeader) into tS
   get textEncode("Part one", "utf-8")
   put sxSecretStreamPush(tS, it, empty, false) into tOne
   get textEncode("part two", "utf-8")
   put sxSecretStreamPush(tS, it, empty, true) into tTwo
   sxFreeStream tS
   -- the reader opens them in the same order
   put "Each piece, then: was it the last?" & cr into tOut
   put sxSecretStreamInitPull(tKey, tHeader) into tS
   put sxSecretStreamPull(tS, tOne, "", tTag) into tBack
   put textDecode(tBack, "utf-8") after tOut
   put ":" && sxIsFinalTag(tTag) & cr after tOut
   put sxSecretStreamPull(tS, tTwo, "", tTag) into tBack
   put textDecode(tBack, "utf-8") after tOut
   put ":" && sxIsFinalTag(tTag) after tOut
   sxFreeStream tS
   put tOut into field "Result"
end mouseUp
@*/

/*@ Streams/expect
^Each piece, then: was it the last\?\nPart one: false\npart two: true$
@*/

/*@ Subkeys/words
One master key can make many keys. `sxKdfDerive` takes the master key, a number and a label of exactly 8 letters, and gives a new key. Each number gives an unrelated key, and none gives away the master: one key for files, another for messages, and so on.

A locked message shows its length: "yes" and "no thanks" are easy to tell apart by size alone. `sxPad` grows data to a whole number of blocks, so lengths say less, and `sxUnpad` takes the padding off again.
@*/

/*@ Subkeys/try
on mouseUp
   local tMaster, tLabel, tKey, tWord, tPadded, tOut
   put sxRandomBytes(32) into tMaster
   put textEncode("MyApp-v1", "utf-8") into tLabel
   -- key number 1, and key number 2
   put sxKdfDerive(tMaster, "1", tLabel, 32) into tKey
   get char 1 to 24 of sxBin2Hex(tKey)
   put "Key 1: " & it & cr into tOut
   put sxKdfDerive(tMaster, "2", tLabel, 32) into tKey
   get char 1 to 24 of sxBin2Hex(tKey)
   put "Key 2: " & it & cr after tOut
   -- padded to blocks of 16 bytes, both are as long
   repeat for each item tWord in "yes,no thanks"
      get textEncode(tWord, "utf-8")
      put sxPad(it, 16) into tPadded
      get the number of bytes in tPadded
      put tWord & ":" && it && "bytes" & cr after tOut
   end repeat
   get sxUnpad(tPadded, 16)
   put "Unpadded: " & textDecode(it, "utf-8") after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Subkeys/expect
^Key 1: [0-9a-f]{24}\nKey 2: [0-9a-f]{24}\nyes: 16 bytes\nno thanks: 16 bytes\nUnpadded: no thanks$
@*/
