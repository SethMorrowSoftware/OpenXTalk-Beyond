script "OXTExampleLearnCoinXT"
-- OXT-Beyond: builds "Learn CoinXT", thirteen lessons in CoinXT, the
-- xTalk Suite's Bitcoin and Ethereum extension (trezor-crypto and
-- libsecp256k1 under a script layer), which OXT-Beyond has built in
-- (https://github.com/SethMorrowSoftware/xtalk-suite, coinxt/).
--
-- It is one of the "Learn" stacks (builder.livecodescript, "Learn stacks"):
-- each lesson says what it shows in plain words, and runs a real script
-- that calls CoinXT, which the user can change, run again and copy; a
-- click on a call opens its page of the reference, and the Reference card
-- has every CoinXT handler, of the extension and of its script layer,
-- from the IDE's Dictionary. The lessons' words, scripts and expected
-- results are the blocks at the end of this script; every key in them is
-- made from a phrase or is a published test value, so the results are the
-- same on every run (and no lesson suggests that for real coins).
-- test-learn-stacks.livecodescript (in tools/examples) runs every lesson's
-- script on a real engine with CoinXT loaded and checks its result.

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex, tLessons
   exUseScripts the script of me
   exAddIcon "bitcoin", "<path d='M11.767 19.089c4.924.868 6.14-6.025 1.216-6.894m-1.216 6.894L5.86 18.047m5.908 1.042-.347 1.97m1.563-8.864c4.924.869 6.14-6.025 1.215-6.893m-1.215 6.893-3.94-.694m5.155-6.2L8.29 4.26m5.908 1.042.348-1.97M7.48 20.364l3.126-17.727'/>"
   put "Learn CoinXT" into tInfo["name"]
   put "Bitcoin and Ethereum, through CoinXT" into tInfo["credit"]
   put "bitcoin" into tInfo["icon"]
   put lkColor("amber") into tInfo["accent"]
   put lkColor("orange") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn CoinXT|Keys, addresses and signatures for Bitcoin and Ethereum.|bitcoin|front" & return & \
         "Hashes|Fingerprints|The hashes Bitcoin and Ethereum are built on.|hash|page" & return & \
         "Keys|Keys|A private key, and the public key it makes.|key-round|page" & return & \
         "Bitcoin|Bitcoin Addresses|One key, three kinds of Bitcoin address.|bitcoin|page" & return & \
         "Ethereum|Ethereum Addresses|Addresses whose capitals catch typing mistakes.|globe|page" & return & \
         "Checksums|Typo Checks|Text that notices a wrong letter.|check|page" & return & \
         "SegWit|Inside an Address|Take an address apart, and check its network.|search-code|page" & return & \
         "Words|Recovery Words|Twelve words that hold a whole wallet.|list-ordered|page" & return & \
         "Wallets|HD Wallets|A tree of keys, grown from one seed.|git-branch|page" & return & \
         "Signing|Signatures|Prove you approved a payment.|pen-line|page" & return & \
         "Recover|Who Signed?|Find the signer from the signature.|search|page" & return & \
         "Schnorr|Schnorr and Taproot|Bitcoin's newer signatures.|sparkles|page" & return & \
         "BtcTx|Bitcoin Transactions|Coins in, coins out, and an id.|send|page" & return & \
         "EthTx|Ethereum Transactions|Build, sign and pack a payment.|zap|page" & return & \
         "Reference|Reference|Every CoinXT handler: what it takes and gives back.|book-open|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   exLearnDocs "org.openxtalk.library.coin,coinxt"
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      put exCardInfo(tIndex, "name") & comma after tLessons
   end repeat
   delete the last char of tLessons
   -- (the probe calls both halves: the extension's cxSha256 and the
   -- script layer's cxHexEncode, and gives "CoinXT" when both answer)
   exLearnKit "Start", tLessons, "CoinXT", \
         quote & "CoinXT" & quote & " & char 1 to 0 of cxHexEncode(cxSha256(" & quote & "x" & quote & "))", \
         "lcb|org.openxtalk.library.coin|coinxt" & return & "lcs|coinxt|coinxt.livecodescript"
   repeat for each item tIndex in tLessons
      if tIndex is not "Reference" then
         exLearnLesson tIndex
      end if
   end repeat
   exLearnReference "Reference"
   exLearnFront "OXT-BEYOND  " & numToCodepoint(183) & "  BITCOIN AND ETHEREUM THROUGH COINXT", \
         "Coins, keys and signatures", \
         "Thirteen short lessons in how Bitcoin and Ethereum keep coins safe. " & \
         "Each runs a real script that you can change, run again and copy.", \
         "lightbulb|Each lesson starts in plain words. No maths needed." & return & \
         "triangle-alert|The keys here are for learning. Never put real coins on them." & return & \
         "book-open|Click a call to read its parameters, units and result."
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn CoinXT.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

/*@ stack
-- Learn CoinXT: thirteen lessons in CoinXT, the xTalk Suite's Bitcoin
-- and Ethereum extension. The lessons are run by the script of the group
-- "Learn", and the window by the script of the group "Frame". It was built
-- by tools/examples/learn-coinxt.livecodescript in the OXT-Beyond
-- repository; build it again rather than change it here.
@*/

/*@ Hashes/words
Coins run on **hashes**: fingerprints of data. Any bytes go in, and a short code comes out, always 32 bytes here. Change one letter and the code changes completely, and nobody can work back from it.

- `cxSha256` is the hash Bitcoin uses; `cxHash256` runs it twice, which is how Bitcoin names blocks and transactions.
- `cxKeccak256` is Ethereum's hash.
- `cxHexEncode` spells bytes as hex, two letters a byte.
@*/

/*@ Hashes/try
on mouseUp
   local tData, tOut
   put textEncode("Hello, Bitcoin", "utf-8") into tData
   -- each hash turns any bytes into a 32-byte code; here,
   -- the first 18 of its 64 hex letters
   get cxHexEncode(cxSha256(tData))
   put "SHA-256:    " & char 1 to 18 of it after tOut
   -- Bitcoin hashes twice: SHA-256 of SHA-256
   get cxHexEncode(cxHash256(tData))
   put "..." & cr & "HASH256:    " after tOut
   put char 1 to 18 of it after tOut
   -- Ethereum uses Keccak-256
   get cxHexEncode(cxKeccak256(tData))
   put "..." & cr & "Keccak-256: " after tOut
   put char 1 to 18 of it & "..." & cr after tOut
   get the number of bytes in cxSha256(empty)
   put "Each is" && it && "bytes, whatever" after tOut
   put " goes in." after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Hashes/expect
^SHA-256:    d8125d715a1f870120\.\.\.\nHASH256:    644055e4a5a523bccf\.\.\.\nKeccak-256: 1d6bbf77c5ed6566af\.\.\.\nEach is 32 bytes, whatever goes in\.$
@*/

/*@ Keys/words
A **private key** is 32 secret bytes. Whoever has it controls the coins, so a real one must come from good randomness, never from a phrase you made up.

- `cxSeckeyIsValid` checks that 32 bytes can be a key.
- `cxPublicKey` makes the **public key**, which is safe to share: 33 bytes in short form, 65 in long form.
- Nobody can work back from the public key to the private one.
@*/

/*@ Keys/try
on mouseUp
   local tKey, tPub, tOut
   -- a key made from a phrase: for learning only, never
   -- for real coins (anyone who guesses it can spend)
   put textEncode("my first key", "utf-8") into tKey
   put cxSha256(tKey) into tKey
   get cxSeckeyIsValid(tKey)
   put "Valid key?" && it & cr into tOut
   -- the public key: safe to share
   put cxPublicKey(tKey, true) into tPub
   get the number of bytes in tPub
   put "Public key:" && it && "bytes" & cr after tOut
   get cxHexEncode(tPub)
   put char 1 to 30 of it & "..." & cr after tOut
   -- the long form, which Ethereum uses
   get the number of bytes in cxPublicKey(tKey, false)
   put "Uncompressed:" && it && "bytes" after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Keys/expect
^Valid key\? true\nPublic key: 33 bytes\n03e47416d316a13dbbdde7a3060f94\.\.\.\nUncompressed: 65 bytes$
@*/

/*@ Bitcoin/words
An **address** is where people send you coins. It is made from your public key, so you can share it freely.

- `cxBtcAddressP2PKH`: the oldest kind, starting with 1.
- `cxBtcAddressP2WPKH`: SegWit, starting with bc1q. Cheaper to spend from.
- `cxBtcAddressP2TRFromInternal`: Taproot, starting with bc1p. It takes the 32-byte key from `cxXOnlyPubkey`.

All three belong to the same key.
@*/

/*@ Bitcoin/try
on mouseUp
   local tKey, tPub, tOut
   put textEncode("my first key", "utf-8") into tKey
   put cxSha256(tKey) into tKey
   put cxPublicKey(tKey, true) into tPub
   -- one key, three kinds of Bitcoin address (here,
   -- the first 22 letters of each)
   get cxBtcAddressP2PKH(tPub)
   put "Legacy:  " & char 1 to 22 of it after tOut
   put "..." & cr after tOut
   get cxBtcAddressP2WPKH(tPub)
   put "SegWit:  " & char 1 to 22 of it after tOut
   put "..." & cr after tOut
   -- Taproot uses the 32-byte "x-only" key
   get cxXOnlyPubkey(tKey)
   get cxBtcAddressP2TRFromInternal(it, empty)
   put "Taproot: " & char 1 to 22 of it after tOut
   put "..." & cr after tOut
   put "The first letters say which kind." after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Bitcoin/expect
^Legacy:  18GvyZLsvxUY7WgPANwnNz\.\.\.\nSegWit:  bc1qflxz6y7ej9ccyn87px\.\.\.\nTaproot: bc1pnc3xf8pvf9kgaslxwr\.\.\.\nThe first letters say which kind\.$
@*/

/*@ Ethereum/words
An Ethereum address is the last 20 bytes of the Keccak-256 hash of your long public key, written as hex after 0x. `cxEthAddress` makes it.

Hex has no check for typos, so Ethereum hides one in the **capital letters**:

- `cxEthAddressChecksum` writes the address with the right letters in capitals.
- `cxEthAddressIsChecksummed` says whether the capitals are right. One wrong letter, and they are not.
@*/

/*@ Ethereum/try
on mouseUp
   local tKey, tAddr, tMixed, tOut
   put textEncode("my first key", "utf-8") into tKey
   put cxSha256(tKey) into tKey
   -- Ethereum hashes the long form of the public key
   put cxEthAddress(cxPublicKey(tKey, false)) into tAddr
   put "Plain:   " & char 1 to 22 of tAddr into tOut
   -- capitals in the right places catch typing mistakes
   put cxEthAddressChecksum(tAddr) into tMixed
   put "..." & cr & "Checked: " after tOut
   put char 1 to 22 of tMixed after tOut
   get cxEthAddressIsChecksummed(tMixed)
   put "..." & cr & "Capitals right?" && it after tOut
   -- a typo: the capital C (letter 6) made small
   put "c" into char 6 of tMixed
   get cxEthAddressIsChecksummed(tMixed)
   put cr & "After a typo?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Ethereum/expect
^Plain:   0x740c064c79e895ef9617\.\.\.\nChecked: 0x740C064c79E895eF9617\.\.\.\nCapitals right\? true\nAfter a typo\? false$
@*/

/*@ Checksums/words
Some text a wallet shows you carries a **checksum**: a few extra letters worked out from the rest. A wrong letter makes them disagree, so a typo is caught before it costs money.

- `cxWifEncode` writes a private key as WIF text, which wallets import. `cxWifDecode` reads it back.
- `cxBase58CheckDecode` checks and decodes such text, and stops with an error when a letter is wrong. Catch it with **try**.
@*/

/*@ Checksums/try
on mouseUp
   local tKey, tWif, tBack, tOut
   put textEncode("my first key", "utf-8") into tKey
   put cxSha256(tKey) into tKey
   -- WIF: a private key as text a wallet can import
   get cxHexEncode(tKey)
   put cxWifEncode(it, "mainnet", true) into tWif
   put "WIF: " & char 1 to 26 of tWif into tOut
   put "..." & cr after tOut
   put cxWifDecode(tWif) into tBack
   get tBack["seckey"] = cxHexEncode(tKey)
   put "Same key back?" && it & cr after tOut
   -- one wrong letter, and Base58Check notices
   put "X" into char 10 of tWif
   try
      get cxBase58CheckDecode(tWif)
      put "A typo got through!" after tOut
   catch tError
      put "A typo: refused, as it should be." after tOut
   end try
   put tOut into field "Result"
end mouseUp
@*/

/*@ Checksums/expect
^WIF: Kzcajo7xPiFFF7v9kJKmFn1QnU\.\.\.\nSame key back\? true\nA typo: refused, as it should be\.$
@*/

/*@ SegWit/words
A SegWit address is not just letters: inside it are a **version** and a **program**, the bytes that say who can spend.

- `cxSegwitAddressDecode` takes an address apart. It also checks the network: "bc" is the real Bitcoin network, "tb" the test one.
- `cxSegwitAddressEncode` puts one together again.

A wallet that checks the network cannot send real coins to a test address by mistake.
@*/

/*@ SegWit/try
on mouseUp
   local tAddr, tParts, tOut
   put "bc1qw508d6qejxtdg4y5r3zar" into tAddr
   put "vary0c5xw7kv8f3t4" after tAddr
   -- take an address apart, checking its network
   put cxSegwitAddressDecode("bc", tAddr) into tParts
   put "Witness version:" && tParts["version"] into tOut
   get the number of bytes in tParts["program"]
   put cr & "Program:" && it && "bytes" after tOut
   -- and put it back together
   get cxSegwitAddressEncode("bc", 0, tParts["program"])
   put cr & "Same address?" && (it = tAddr) after tOut
   put cr after tOut
   -- a testnet wallet must refuse a mainnet address
   try
      get cxSegwitAddressDecode("tb", tAddr)
      put "Wrong network accepted!" after tOut
   catch tError
      put "Wrong network: refused" after tOut
   end try
   put tOut into field "Result"
end mouseUp
@*/

/*@ SegWit/expect
^Witness version: 0\nProgram: 20 bytes\nSame address\? true\nWrong network: refused$
@*/

/*@ Words/words
Twelve ordinary words can hold a whole wallet. They are the **recovery phrase**: write them on paper, and you can rebuild the wallet on any device.

- `cxMnemonicFromEntropy` turns 16 random bytes into 12 words, from a list of 2048.
- `cxMnemonicValidate` checks them. The last word holds a checksum, so a wrong word is caught.

Anyone who sees the words owns the coins. Never type real ones into a website.
@*/

/*@ Words/try
on mouseUp
   local tEntropy, tWords, tOut
   -- 16 bytes of entropy become 12 words. All zeros is a
   -- famous test value: never use it for real coins
   put "00000000000000000000000000000000" into tEntropy
   put cxHexDecode(tEntropy) into tEntropy
   put cxMnemonicFromEntropy(tEntropy) into tWords
   put "Words:" && the number of words of tWords into tOut
   put cr & word 1 to 3 of tWords & " ... " after tOut
   put word -1 of tWords after tOut
   get cxMnemonicValidate(tWords)
   put cr & "Valid?" && it after tOut
   -- the last word holds a checksum: change it
   put "zoo" into word -1 of tWords
   get cxMnemonicValidate(tWords)
   put cr & "Last word changed?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Words/expect
^Words: 12\nabandon abandon abandon \.\.\. about\nValid\? true\nLast word changed\? false$
@*/

/*@ Wallets/words
One recovery phrase can make millions of keys. `cxMnemonicToSeed` turns the words into a 64-byte **seed**, and `cxHdFromSeed` makes the root of a tree of keys.

- A **path** such as m/84'/0'/0'/0/0 picks one branch: `cxHdDerivePath` walks it.
- The same words always grow the same tree, so a new wallet finds every old address.
- The last number counts up: 0, 1, 2, a new address each time.
@*/

/*@ Wallets/try
on mouseUp
   local tWords, tSeed, tRoot, tNode, tOut
   -- a famous test phrase: never use it for real coins
   put "abandon abandon abandon abandon" into tWords
   put " abandon abandon abandon abandon" after tWords
   put " abandon abandon abandon about" after tWords
   -- the words (and an optional passphrase) make a seed
   put cxMnemonicToSeed(tWords, empty) into tSeed
   get the number of bytes in tSeed
   put "Seed:" && it && "bytes" into tOut
   -- the seed grows a tree of keys: one path, one key
   put cxHdFromSeed(tSeed) into tRoot
   put cxHdDerivePath(tRoot, "m/84'/0'/0'/0/0") into tNode
   put cr & "Depth:" && tNode["depth"] after tOut
   get cxBtcAddressP2WPKH(tNode["pubkey"])
   put cr & "First:  " & char 1 to 22 of it after tOut
   put "..." after tOut
   -- the next one along
   put cxHdDerivePath(tRoot, "m/84'/0'/0'/0/1") into tNode
   get cxBtcAddressP2WPKH(tNode["pubkey"])
   put cr & "Second: " & char 1 to 22 of it after tOut
   put "..." after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Wallets/expect
^Seed: 64 bytes\nDepth: 5\nFirst:  bc1qcr8te4kr609gcawutm\.\.\.\nSecond: bc1qnjg0jd8228aq7egyza\.\.\.$
@*/

/*@ Signing/words
To spend coins you **sign**: you prove that you hold the private key, without showing it.

- Hash the message first: a signature covers exactly 32 bytes.
- `cxSign` signs with the private key. `cxVerify` checks with the public key: anyone can check, nobody else can sign.
- Change the message, even by one letter, and the check fails.
- `cxDerEncode` packs a signature the way Bitcoin scripts carry it.
@*/

/*@ Signing/try
on mouseUp
   local tKey, tPub, tDigest, tSig, tOut
   put textEncode("my first key", "utf-8") into tKey
   put cxSha256(tKey) into tKey
   put cxPublicKey(tKey, true) into tPub
   -- sign the 32-byte digest of the message
   put textEncode("Pay Bob 5", "utf-8") into tDigest
   put cxSha256(tDigest) into tDigest
   put cxSign(tKey, tDigest) into tSig
   get the number of bytes in tSig
   put "Signature:" && it && "bytes" into tOut
   get cxVerify(tPub, tDigest, tSig)
   put cr & "Genuine?" && it after tOut
   -- a changed message no longer matches
   put textEncode("Pay Bob 500", "utf-8") into tDigest
   put cxSha256(tDigest) into tDigest
   get cxVerify(tPub, tDigest, tSig)
   put cr & "Changed?" && it after tOut
   -- Bitcoin scripts carry signatures in DER form
   get the number of bytes in cxDerEncode(tSig)
   put cr & "As DER:" && it && "bytes" after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Signing/expect
^Signature: 64 bytes\nGenuine\? true\nChanged\? false\nAs DER: 71 bytes$
@*/

/*@ Recover/words
Ethereum signatures carry one extra byte, the **recovery id**. With it, anyone can work out which public key made a signature, so a message does not need to say who sent it.

- `cxSignRecoverable` signs, adding the recovery id: 65 bytes.
- `cxRecover` finds the public key from the signature and the message.

Always compare the result with the address you expected: any signature recovers some key.
@*/

/*@ Recover/try
on mouseUp
   local tKey, tMine, tDigest, tSig, tPub, tOut
   put textEncode("my first key", "utf-8") into tKey
   put cxSha256(tKey) into tKey
   put cxEthAddress(cxPublicKey(tKey, false)) into tMine
   put textEncode("I agree", "utf-8") into tDigest
   put cxKeccak256(tDigest) into tDigest
   -- a recoverable signature: 64 bytes and a recovery id
   put cxSignRecoverable(tKey, tDigest) into tSig
   get the number of bytes in tSig
   put "Signature:" && it && "bytes" into tOut
   -- from the signature alone, find who signed
   put cxRecover(tSig, tDigest) into tPub
   get cxEthAddress(tPub)
   put cr & "Signer: " & char 1 to 22 of it after tOut
   put "..." after tOut
   -- always compare with the address you expected
   put cr & "Is it me?" && (it = tMine) after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Recover/expect
^Signature: 65 bytes\nSigner: 0x740c064c79e895ef9617\.\.\.\nIs it me\? true$
@*/

/*@ Schnorr/words
Taproot, Bitcoin's 2021 upgrade, brought **Schnorr signatures**: simpler, smaller to check, and able to combine many signers into one.

- They use the 32-byte **x-only** key from `cxXOnlyPubkey`.
- `cxSchnorrSign` signs a 32-byte message. Given empty, it mixes in fresh randomness, so each signature differs; every one still checks.
- `cxSchnorrVerify` checks one.
@*/

/*@ Schnorr/try
on mouseUp
   local tKey, tX, tMsg, tSig, tOut
   put textEncode("my first key", "utf-8") into tKey
   put cxSha256(tKey) into tKey
   -- Schnorr signatures use the 32-byte x-only key
   put cxXOnlyPubkey(tKey) into tX
   get the number of bytes in tX
   put "X-only key:" && it && "bytes" into tOut
   put cxSha256(textEncode("Taproot!", "utf-8")) into tMsg
   -- empty: fresh randomness, a new signature each time
   put cxSchnorrSign(tKey, tMsg, empty) into tSig
   get the number of bytes in tSig
   put cr & "Signature:" && it && "bytes" after tOut
   get cxSchnorrVerify(tX, tMsg, tSig)
   put cr & "Genuine?" && it after tOut
   put cxSha256(textEncode("Taproot?", "utf-8")) into tMsg
   get cxSchnorrVerify(tX, tMsg, tSig)
   put cr & "Changed?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Schnorr/expect
^X-only key: 32 bytes\nSignature: 64 bytes\nGenuine\? true\nChanged\? false$
@*/

/*@ BtcTx/words
A Bitcoin **transaction** spends earlier outputs and makes new ones.

- An **input** points at an earlier output: its transaction id and number, from `cxBtcOutpoint`.
- An **output** is an amount in satoshi (a hundred millionth of a bitcoin) and a script that locks it, from `cxBtcOutput`.
- `cxBtcTxid` gives the new transaction's id: the hash that names it on every block explorer.
@*/

/*@ BtcTx/try
on mouseUp
   local tTxid, tIn, tPay, tId, tOut
   -- spend output 0 of an earlier transaction ...
   put "4ce18f49ba153a51bcda9bb80d7f978e" into tTxid
   put "3de6e81b5fc326f00465d4a9b0d32a2b" after tTxid
   put cxHexEncode(cxBtcOutpoint(tTxid, 0)) into tIn
   -- ... paying 50,000 satoshi to a SegWit script
   get "0014751e76e8199196d454941c45d1b3a323f1433bd6"
   put cxHexEncode(cxBtcOutput(50000, it)) into tPay
   put "Input: " && (the length of tIn) / 2 into tOut
   put " bytes" & cr & "Output:" after tOut
   get (the length of tPay) / 2
   put space & it & " bytes" after tOut
   -- version 2, sequence ffffffff, locktime 0
   get 4294967295
   put cxBtcTxid(2, tIn, empty, it, tPay, 0) into tId
   put cr & "Transaction id:" & cr after tOut
   put char 1 to 32 of tId & cr after tOut
   put char 33 to 64 of tId after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ BtcTx/expect
^Input:  36 bytes\nOutput: 31 bytes\nTransaction id:\nc73feaa3700e7091e724775123c4955d\n710a10319bbbc900553f7e576bad9dd3$
@*/

/*@ EthTx/words
An Ethereum payment has fields: the chain, a counter called the nonce, the fees, the gas, who it goes to and how much. Amounts are in **wei**, a billionth of a billionth of an ether, written as hex.

- `cxEth1559Sighash` hashes the fields into the digest to sign.
- `cxSignRecoverable` signs it.
- `cxEth1559Encode` packs the fields and the signature into the bytes a node accepts, and gives its hash.
@*/

/*@ EthTx/try
on mouseUp
   local tKey, tTo, tHash, tSig, tR, tS, tV, tTx, tOut
   put textEncode("my first key", "utf-8") into tKey
   put cxSha256(tKey) into tKey
   put "3535353535353535353535353535353535353535" into tTo
   -- chain 1, nonce 0, fees and value in wei, as hex
   put cxEth1559Sighash(1, 0, "3b9aca00", "77359400", \
         21000, tTo, "0de0b6b3a7640000", empty) into tHash
   get the number of bytes in tHash
   put "Digest:" && it && "bytes" into tOut
   -- sign it, then pack the signature in
   put cxSignRecoverable(tKey, tHash) into tSig
   put cxHexEncode(byte 1 to 32 of tSig) into tR
   put cxHexEncode(byte 33 to 64 of tSig) into tS
   put byteToNum(byte 65 of tSig) into tV
   put cxEth1559Encode(1, 0, "3b9aca00", "77359400", \
         21000, tTo, "0de0b6b3a7640000", empty, \
         tV, tR, tS) into tTx
   get (the length of tTx["raw"]) / 2
   put cr & "Signed:" && it && "bytes" after tOut
   get char 1 to 16 of tTx["txhash"]
   put cr & "Hash:" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ EthTx/expect
^Digest: 32 bytes\nSigned: 117 bytes\nHash: ad35dafd696eb9d6$
@*/
