script "OXTExampleLearnNostrXT"
-- OXT-Beyond: builds "Learn NostrXT", thirteen lessons in NostrXT, the
-- xTalk Suite's Nostr extension (a script library over CoinXT and
-- SodiumXT), which OXT-Beyond has built in
-- (https://github.com/SethMorrowSoftware/xtalk-suite, nostrxt/).
--
-- It is one of the "Learn" stacks (builder.livecodescript, "Learn stacks"):
-- each lesson says what it shows in plain words, and runs a real script
-- that calls NostrXT, which the user can change, run again and copy; a
-- click on a call opens its page of the reference, and the Reference card
-- has every NostrXT handler, from the IDE's Dictionary. The lessons work
-- offline: they build, sign, read and match events and relay messages,
-- and send nothing (nostr-relay, the extension that talks to relays, is
-- for an app). Every key is made from a phrase and every time and nonce
-- is fixed, so the results are the same on every run.
-- test-learn-stacks.livecodescript (in tools/examples) runs every lesson's
-- script on a real engine with NostrXT, CoinXT and SodiumXT loaded and
-- checks its result.

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex, tLessons
   exUseScripts the script of me
   put "Learn NostrXT" into tInfo["name"]
   put "Nostr, through NostrXT" into tInfo["credit"]
   put "message-square-text" into tInfo["icon"]
   put lkColor("violet") into tInfo["accent"]
   put lkColor("pink") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn NostrXT|Keys, notes and signatures on Nostr, the open social network.|message-square-text|front" & return & \
         "Keys|Keys|Who you are on Nostr: a secret key and a public one.|key-round|page" & return & \
         "Names|npub and nsec|Keys as short names that catch typos.|type|page" & return & \
         "Events|Events|Every note, like and profile is one.|file-text|page" & return & \
         "Signing|Signatures|Prove you wrote it, and that nobody changed it.|pen-line|page" & return & \
         "Wire|Events as JSON|Send an event as text, and read one back.|braces|page" & return & \
         "Tags|Tags|Topics, mentions and links inside an event.|hash|page" & return & \
         "Replies|Replies and Likes|Events that point to other events.|message-circle|page" & return & \
         "Profiles|Profiles and Follows|Your name, and the people you follow.|user|page" & return & \
         "Links|Sharing Links|A link to a note that says where to find it.|external-link|page" & return & \
         "Secrets|Private Messages|Lock a message so only one person can read it.|lock|page" & return & \
         "Filters|Filters|Ask a relay for just the events you want.|search|page" & return & \
         "Relays|Talking to Relays|The messages a client and a relay send.|send|page" & return & \
         "Work|Proof of Work|Make a note cost a little computing.|zap|page" & return & \
         "Reference|Reference|Every NostrXT handler: what it takes and gives back.|book-open|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   exLearnDocs "nostrxt"
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      put exCardInfo(tIndex, "name") & comma after tLessons
   end repeat
   delete the last char of tLessons
   -- (the probe calls NostrXT's own hex encoder over CoinXT's SHA-256,
   -- and gives NostrXT's version when both answer)
   exLearnKit "Start", tLessons, "NostrXT", \
         "nxVersion() & char 1 to 0 of nxHexEncode(cxSha256(" & quote & "x" & quote & "))", \
         "lcb|org.openxtalk.library.coin|coinxt" & return & "lcs|coinxt|coinxt.livecodescript" & return & \
         "lcb|org.openxtalk.library.sodium|sodiumxt" & return & "lcs|nostrxt|nostrxt.livecodescript"
   repeat for each item tIndex in tLessons
      if tIndex is not "Reference" then
         exLearnLesson tIndex
      end if
   end repeat
   exLearnReference "Reference"
   exLearnFront "OXT-BEYOND  " & numToCodepoint(183) & "  NOSTR THROUGH NOSTRXT", \
         "Notes, keys and signatures", \
         "Thirteen short lessons in Nostr, the open social network with no company in charge. " & \
         "Each runs a real script that you can change, run again and copy.", \
         "lightbulb|Each lesson starts in plain words, and works offline." & return & \
         "triangle-alert|The keys here are for learning. Never post with them." & return & \
         "book-open|Click a call to read its parameters, units and result."
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn NostrXT.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

/*@ stack
-- Learn NostrXT: thirteen lessons in NostrXT, the xTalk Suite's Nostr
-- extension. The lessons are run by the script of the group "Learn", and
-- the window by the script of the group "Frame". It was built by
-- tools/examples/learn-nostrxt.livecodescript in the OXT-Beyond
-- repository; build it again rather than change it here.
@*/

/*@ Keys/words
On Nostr you have no account and no password: you have a **key pair**. The **secret key** is 64 hex digits that only you hold. The **public key** comes from it and is who you are, to everyone.

- `nxKeyIsValid` checks that a secret key can be used.
- `nxKeyPublic` makes the public key. Nobody can work back from it to the secret one.
- A real key comes from `nxKeyGenerate`, never from a phrase.
@*/

/*@ Keys/try
on mouseUp
   local tSec, tPub, tOut
   -- a secret key made from a phrase: for learning only
   -- (an app calls nxKeyGenerate() for a random one)
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   get nxKeyIsValid(tSec)
   put "Secret key valid?" && it into tOut
   -- the public key: safe to share, it is who you are
   put nxKeyPublic(tSec) into tPub
   get the length of tPub
   put cr & "Public key:" && it && "hex digits" after tOut
   put cr & char 1 to 30 of tPub & "..." after tOut
   get nxKeyPublic(tSec) is tPub
   put cr & "Same every time?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Keys/expect
^Secret key valid\? true\nPublic key: 64 hex digits\n4c03b4839d256423f8601551d16f46\.\.\.\nSame every time\? true$
@*/

/*@ Names/words
Hex is easy to mistype, so people share keys as short names with a typo check built in: an **npub** for a public key, an **nsec** for a secret one.

- `nxNpubEncode` and `nxNpubDecode` turn a public key into an npub and back.
- `nxNsecEncode` makes an nsec, for a backup only. Never paste it anywhere.
- `nxUriEncode` makes a nostr: link, and refuses an nsec.
@*/

/*@ Names/try
on mouseUp
   local tSec, tPub, tNpub, tNsec, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   -- the public key as people share it: an npub
   put nxNpubEncode(tPub) into tNpub
   put char 1 to 24 of tNpub & "..." into tOut
   get nxNpubDecode(tNpub) is tPub
   put cr & "Back to hex?" && it after tOut
   -- the secret key the same way: an nsec, never shared
   put nxNsecEncode(tSec) into tNsec
   get char 1 to 5 of tNsec
   put cr & "Secret form starts:" && it after tOut
   -- so a link to it is refused
   if nxUriEncode(tNsec) is empty then
      put cr & "A link to it? refused" after tOut
   end if
   put tOut into field "Result"
end mouseUp
@*/

/*@ Names/expect
^npub1fspmfquay4jz87rqz4g\.\.\.\nBack to hex\? true\nSecret form starts: nsec1\nA link to it\? refused$
@*/

/*@ Events/words
Everything on Nostr is an **event**: a note, a like, a profile. An event has a **kind** (1 is a short note), a time, its text and its author.

- `nxEventBuild` makes one. The time is seconds since 1970; empty means now.
- `nxEventId` gives its **id**: the SHA-256 fingerprint of its exact text.

Change one letter, and the id is different.
@*/

/*@ Events/try
on mouseUp
   local tSec, tPub, tEvent, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   -- a short note (kind 1), written at a fixed time
   get nxEventBuild(1, "Hello, Nostr!", empty, 1700000000)
   put it into tEvent
   put "Kind:" && tEvent["kind"] into tOut
   put cr & "Time:" && tEvent["created_at"] after tOut
   -- its id is the fingerprint of its exact text
   put tPub into tEvent["pubkey"]
   get char 1 to 26 of nxEventId(tEvent)
   put cr & "Id:" && it & "..." after tOut
   -- one letter changed: a different id
   put "Hello, Nostr?" into tEvent["content"]
   get char 1 to 26 of nxEventId(tEvent)
   put cr & "Id:" && it & "..." after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Events/expect
^Kind: 1\nTime: 1700000000\nId: 4ffc750d806729cc44eed47bad\.\.\.\nId: a140c3ecee6a6a6afb9fe468a5\.\.\.$
@*/

/*@ Signing/words
You **sign** an event with your secret key. Anyone can then check, with only your public key, that you wrote it and that nobody changed it.

- `nxEventSign` fills in the author, the id and the **signature** (BIP-340 Schnorr, the kind Bitcoin's Taproot uses).
- `nxEventVerify` says true only when both the id and the signature check out. Treat anything else as fake.
@*/

/*@ Signing/try
on mouseUp
   local tSec, tPub, tAux, tEvent, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   get nxEventBuild(1, "Hello, Nostr!", empty, 1700000000)
   -- (64 zeros make the same signature every run: an app
   -- passes empty, for fresh randomness)
   put format("%064d", 0) into tAux
   put nxEventSign(it, tSec, tAux) into tEvent
   get the length of tEvent["sig"]
   put "Signature:" && it && "hex digits" into tOut
   put cr & "Genuine?" && nxEventVerify(tEvent) after tOut
   -- someone changes the note on its way
   put "Hello! Send me coins." into tEvent["content"]
   put cr & "Changed?" && nxEventVerify(tEvent) after tOut
   put cr & "Any reader can check the author." after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Signing/expect
^Signature: 128 hex digits\nGenuine\? true\nChanged\? false\nAny reader can check the author\.$
@*/

/*@ Wire/words
To travel, an event becomes **JSON**: plain text that any program can read.

- `nxEventToJson` writes it; `nxEventFromJson` reads it back into an array.
- `nxJsonGet` takes one value out of JSON by its name.

Text from the internet could say anything, so call `nxEventVerify` on what you read before you trust it.
@*/

/*@ Wire/try
on mouseUp
   local tSec, tPub, tEvent, tJson, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   get nxEventBuild(1, "Hello, Nostr!", empty, 1700000000)
   put nxEventSign(it, tSec, empty) into tEvent
   -- the event as JSON text, to send or to store
   put nxEventToJson(tEvent) into tJson
   get the length of tJson
   put "As JSON:" && it && "characters" into tOut
   get nxJsonGet(tJson, "content")
   put cr & "content:" && it after tOut
   put cr & "kind:" && nxJsonGet(tJson, "kind") after tOut
   -- and back: check it before you trust it
   put nxEventFromJson(tJson) into tEvent
   get nxEventVerify(tEvent)
   put cr & "Read back, genuine?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Wire/expect
^As JSON: 355 characters\ncontent: Hello, Nostr!\nkind: 1\nRead back, genuine\? true$
@*/

/*@ Tags/words
**Tags** label an event: a topic, a person mentioned, another event. Each has a short name and a value: "t" for a topic, "p" for a person, "e" for an event.

- `nxTagsFromText` makes tags from text: one a line, a tab between parts.
- `nxTagCount` counts them; `nxTagFirst` gives the first value with a name, and `nxTagValues` every one.
@*/

/*@ Tags/try
on mouseUp
   local tSec, tPub, tTags, tEvent, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   -- tags, one a line: a name, a tab, then its value
   put "t" & tab & "openxtalk" & cr into tTags
   put "t" & tab & "learning" & cr after tTags
   put "p" & tab & tPub after tTags
   put nxTagsFromText(tTags) into tTags
   get nxEventBuild(1, "Hi #openxtalk", tTags, 1700000000)
   put it into tEvent
   put "Tags:" && nxTagCount(tEvent) into tOut
   get nxTagFirst(tEvent, "t")
   put cr & "First t:" && it after tOut
   put nxTagValues(tEvent, "t") into tTags
   replace cr with ", " in tTags
   put cr & "Every t:" && tTags after tOut
   get nxTagFirst(tEvent, "p") is tPub
   put cr & "Mentions me?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Tags/expect
^Tags: 3\nFirst t: openxtalk\nEvery t: openxtalk, learning\nMentions me\? true$
@*/

/*@ Replies/words
A conversation is events that point to each other with tags.

- `nxReplyBuild` makes a reply: an "e" tag points to the post, and a "p" tag tells its author.
- `nxReactionBuild` makes a **reaction** (kind 7), "+" for a like.

Both come back unsigned: sign them with `nxEventSign`, as any event.
@*/

/*@ Replies/try
on mouseUp
   local tSec, tPub, tPost, tReply, tLike, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   get nxEventBuild(1, "Anyone here?", empty, 1700000000)
   put nxEventSign(it, tSec, empty) into tPost
   -- a reply, a minute later, that points to the post
   put nxReplyBuild(tPost, "Me!", 1700000060) into tReply
   put "Reply kind:" && tReply["kind"] into tOut
   get nxTagFirst(tReply, "e") is tPost["id"]
   put cr & "Points to the post?" && it after tOut
   get nxTagFirst(tReply, "p") is tPub
   put cr & "Tells its author?" && it after tOut
   -- a like is a reaction: kind 7, with a +
   get nxReactionBuild(tPost, empty, 1700000090)
   put it into tLike
   put cr & "Like: kind" && tLike["kind"] after tOut
   put "," && tLike["content"] after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Replies/expect
^Reply kind: 1\nPoints to the post\? true\nTells its author\? true\nLike: kind 7, \+$
@*/

/*@ Profiles/words
Your profile is an event too: **kind 0**, with your name and a few words about you in its content. Post a new one to change it.

- `nxMetadataBuild` makes one; `nxMetadataParse` reads its fields.
- `nxContactsBuild` makes your **follow list** (kind 3): a "p" tag for each key you follow. `nxContactsParse` reads it back.
@*/

/*@ Profiles/try
on mouseUp
   local tSec, tPub, tEvent, tProfile, tKeys, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   -- your profile is an event too (kind 0)
   get nxMetadataBuild("Alice", "Hi!", empty, 1700000000)
   put nxEventSign(it, tSec, empty) into tEvent
   put nxMetadataParse(tEvent) into tProfile
   put "Name:" && tProfile["name"] into tOut
   put cr & "About:" && tProfile["about"] after tOut
   -- who you follow (kind 3): public keys, one a line
   put tPub & cr & format("%064d", 1) into tKeys
   put nxContactsBuild(tKeys, 1700000000) into tEvent
   get the number of lines of nxContactsParse(tEvent)
   put cr & "Follows:" && it && "keys" after tOut
   get tEvent["kind"]
   put cr & "Follow list: kind" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Profiles/expect
^Name: Alice\nAbout: Hi!\nFollows: 2 keys\nFollow list: kind 3$
@*/

/*@ Links/words
To share a note, send a link that says where to find it.

- `nxNeventEncode` packs a note's id with a **relay** that has it, and its author and kind.
- `nxUriEncode` adds "nostr:" in front, so apps know what to open.
- `nxEntityDecode` reads any of these names back: npub, note, nevent, nprofile and more.
@*/

/*@ Links/try
on mouseUp
   local tSec, tPub, tEvent, tLink, tFields, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   get nxEventBuild(1, "Hello, Nostr!", empty, 1700000000)
   put nxEventSign(it, tSec, empty) into tEvent
   -- a link to the note, with a relay that has it
   get "wss://relay.example.com"
   get nxNeventEncode(tEvent["id"], it, tPub, 1)
   put nxUriEncode(it) into tLink
   put char 1 to 26 of tLink & "..." into tOut
   -- anyone can read it back
   put nxEntityDecode(tLink) into tFields
   put cr & "Type:" && tFields["type"] after tOut
   put cr & "Relay:" && tFields["relays"] after tOut
   get tFields["id"] is tEvent["id"]
   put cr & "Same note?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Links/expect
^nostr:nevent1qqsyllr4pkqxw\.\.\.\nType: nevent\nRelay: wss://relay\.example\.com\nSame note\? true$
@*/

/*@ Secrets/words
Notes are public. For a private message, NIP-44 locks it so only one person can read it.

- `nxNip44ConversationKey`: your secret key and their public key give the same shared key as theirs and yours. It is never sent.
- `nxNip44Encrypt` locks a message, `nxNip44Decrypt` opens it. With the wrong key it gives nothing, and says why in `nxLastError`.
@*/

/*@ Secrets/try
on mouseUp
   local tSec, tPub, tBob, tBobPub, tNonce, tBox, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   put textEncode("bob learns too", "utf-8") into tBob
   put nxHexEncode(cxSha256(tBob)) into tBob
   put nxKeyPublic(tBob) into tBobPub
   get nxNip44ConversationKey(tSec, tBobPub)
   get it is nxNip44ConversationKey(tBob, tPub)
   put "Same key both ways?" && it into tOut
   -- (a fixed nonce, for learning: an app passes empty)
   put nxHexEncode(cxSha256("n")) into tNonce
   get "Meet at noon"
   put nxNip44Encrypt(tSec, tBobPub, it, tNonce) into tBox
   get char 1 to 20 of tBox
   put cr & "Locked:" && it & "..." after tOut
   get nxNip44Decrypt(tBob, tPub, tBox)
   put cr & "Bob reads:" && it after tOut
   -- someone else's key opens nothing
   get nxNip44Decrypt(tSec, tSec, tBox)
   put cr & "Others read:" && it & "(nothing)" after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Secrets/expect
^Same key both ways\? true\nLocked: AhsWsd9Ti6Etw/l\+27hc\.\.\.\nBob reads: Meet at noon\nOthers read: \(nothing\)$
@*/

/*@ Filters/words
A **relay** is a server that keeps events and passes them on. You ask it for events with a **filter**: whose, what kinds, how many.

- `nxFilterBuild` makes a filter from an array: "authors", "kinds", "limit", "since" and more.
- `nxFilterMatches` says whether an event fits, as a relay would decide.
@*/

/*@ Filters/try
on mouseUp
   local tSec, tPub, tAsk, tFilter, tNote, tLike, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   -- what to ask a relay for: Alice's notes, at most 10
   put tPub into tAsk["authors"]
   put "1" into tAsk["kinds"]
   put 10 into tAsk["limit"]
   put nxFilterBuild(tAsk) into tFilter
   put char 1 to 30 of tFilter & "..." into tOut
   get nxEventBuild(1, "A note", empty, 1700000000)
   put nxEventSign(it, tSec, empty) into tNote
   get nxReactionBuild(tNote, empty, 1700000060)
   put it into tLike
   put nxEventSign(tLike, tSec, empty) into tLike
   get nxFilterMatches(tFilter, tNote)
   put cr & "Her note matches?" && it after tOut
   get nxFilterMatches(tFilter, tLike)
   put cr & "Her like matches?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Filters/expect
^\{"authors":\["4c03b4839d256423f\.\.\.\nHer note matches\? true\nHer like matches\? false$
@*/

/*@ Relays/words
You talk to a relay in short JSON messages, over a websocket.

- `nxClientEvent` publishes an event; `nxClientReq` asks with filters, under a name of your choice; `nxClientClose` ends the question.
- `nxRelayParse` reads the answers: EVENT, OK, EOSE ("that is all, for now"), NOTICE and more.

nostr-relay sends them for you.
@*/

/*@ Relays/try
on mouseUp
   local tSec, tPub, tAsk, tEvent, tWire, tMsg, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   get nxEventBuild(1, "Hello, Nostr!", empty, 1700000000)
   put nxEventSign(it, tSec, empty) into tEvent
   -- what you send a relay: a note, a question, an end
   get char 1 to 9 of nxClientEvent(tEvent)
   put it & "..." into tOut
   put tPub into tAsk["authors"]
   get nxClientReq("feed", nxFilterBuild(tAsk))
   put cr & char 1 to 15 of it & "..." after tOut
   put cr & nxClientClose("feed") after tOut
   -- what a relay sends: "that is all, for now"
   put "[" & quote & "EOSE" & quote & "," into tWire
   put quote & "feed" & quote & "]" after tWire
   put nxRelayParse(tWire) into tMsg
   put cr & "Relay:" && tMsg["type"] && "for" after tOut
   put space & tMsg["subId"] after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Relays/expect
^\["EVENT",\.\.\.\n\["REQ","feed",\{\.\.\.\n\["CLOSE","feed"\]\nRelay: EOSE for feed$
@*/

/*@ Work/words
Spam is cheap; **proof of work** makes a note cost a little computing. You change a number in a "nonce" tag until the id starts with enough zero bits.

- `nxPowDifficulty` counts an id's leading zero bits.
- `nxPowCheck` says whether an event has at least that many, and promised that many.

Each extra bit doubles the work.
@*/

/*@ Work/try
on mouseUp
   local tSec, tPub, tTags, tEvent, tTry, tOut
   put textEncode("alice learns nostr", "utf-8") into tSec
   put nxHexEncode(cxSha256(tSec)) into tSec
   put nxKeyPublic(tSec) into tPub
   -- change the nonce until the id has 8 zero bits
   repeat with tTry = 1 to 5000
      get "nonce" & tab & tTry & tab & 8
      put nxTagsFromText(it) into tTags
      get nxEventBuild(1, "Read me", tTags, 1700000000)
      put it into tEvent
      put tPub into tEvent["pubkey"]
      get nxPowDifficulty(nxEventId(tEvent))
      if it >= 8 then exit repeat
   end repeat
   put nxEventSign(tEvent, tSec, empty) into tEvent
   put "Tries:" && tTry into tOut
   get nxPowDifficulty(tEvent["id"])
   put cr & "Zero bits:" && it after tOut
   get nxPowCheck(tEvent, 8)
   put cr & "Enough work?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Work/expect
^Tries: 458\nZero bits: 10\nEnough work\? true$
@*/
