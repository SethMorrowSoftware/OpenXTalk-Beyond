script "OXTExampleLearnDataChannelXT"
-- OXT-Beyond: builds "Learn dataChannelXT", eight lessons in
-- datachannelxt, the xTalk Suite's WebRTC data channel extension (over
-- libdatachannel) and its dataChannelHelpers library, which OXT-Beyond
-- has built in (https://github.com/SethMorrowSoftware/xtalk-suite,
-- datachannelxt/).
--
-- It is one of the "Learn" stacks (builder.livecodescript, "Learn stacks"):
-- each lesson says what it shows in plain words, and runs a real script
-- that calls dataChannelXT, which the user can change, run again and copy;
-- a click on a call opens its page of the reference, and the Reference
-- card has every handler of the extension and of dataChannelHelpers,
-- from the IDE's Dictionary. A lesson that connects makes BOTH peers in
-- one script and hands the offer and the answer straight across (no ICE
-- servers: they meet on this computer), waits at most 5 seconds, and
-- frees both peers before it ends. dcPoll drains every event in the
-- process, so a lesson's poll also takes the events of any other stack
-- using dataChannelXT at that moment; the lessons never call dcCleanup,
-- which would end every peer in the process, and do not use the
-- helpers' shared pump (dcStartPolling). test-learn-stacks.livecodescript
-- (in tools/examples) runs every lesson's script on a real engine with
-- dataChannelXT loaded and checks its result.

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex, tLessons
   exUseScripts the script of me
   put "Learn dataChannelXT" into tInfo["name"]
   put "WebRTC data channels, through datachannelxt" into tInfo["credit"]
   put "users" into tInfo["icon"]
   put lkColor("sky") into tInfo["accent"]
   put lkColor("emerald") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn dataChannelXT|Two programs talking directly, with WebRTC data channels.|users|front" & return & \
         "Begin|Getting Started|Start the library, and read its errors.|play|page" & return & \
         "Peers|Peers|Your end of a connection, and its state.|users|page" & return & \
         "Offer|Offers|The text a peer writes about itself.|file-text|page" & return & \
         "Connect|Connecting|Swap the offer and the answer, and connect.|zap|page" & return & \
         "Messages|Messages|Send text, and read it as events.|message-circle|page" & return & \
         "Bytes|Sending Bytes|Any bytes, their limit, and the queue.|braces|page" & return & \
         "Options|Channel Options|Unordered, unreliable and negotiated channels.|settings|page" & return & \
         "Goodbye|Saying Goodbye|Close the channel, then the connection.|power|page" & return & \
         "Reference|Reference|Every dataChannelXT handler: what it takes and gives back.|book-open|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   exLearnDocs "org.openxtalk.library.datachannel,dataChannelHelpers"
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      put exCardInfo(tIndex, "name") & comma after tLessons
   end repeat
   delete the last char of tLessons
   -- (the probe calls both halves: the extension's library version and
   -- the helpers' state names, and gives the version when both answer)
   exLearnKit "Start", tLessons, "dataChannelXT", \
         "dcLibraryVersion() & char 1 to 0 of dcStateName(2)", \
         "lcb|org.openxtalk.library.datachannel|datachannelxt" & return & \
         "lcs|dataChannelHelpers|dataChannelHelpers.livecodescript"
   repeat for each item tIndex in tLessons
      if tIndex is not "Reference" then
         exLearnLesson tIndex
      end if
   end repeat
   exLearnReference "Reference"
   exLearnFront "OXT-BEYOND  " & numToCodepoint(183) & "  WEBRTC THROUGH DATACHANNELXT", \
         "Straight to the other side", \
         "Eight short lessons in WebRTC data channels, which let two programs talk directly, with no server in between. " & \
         "Each runs a real script that you can change, run again and copy.", \
         "lightbulb|Each lesson starts in plain words; both peers live on this computer." & return & \
         "book-open|Click a call to read its parameters, units and result." & return & \
         "info|A lesson that connects waits 5 seconds at most, then frees its peers."
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn dataChannelXT.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

/*@ stack
-- Learn dataChannelXT: eight lessons in datachannelxt, the xTalk Suite's
-- WebRTC data channel extension.
-- The lessons are run by the script of the group "Learn", and the window
-- by the script of the group "Frame". It was built by
-- tools/examples/learn-datachannelxt.livecodescript in the OXT-Beyond repository;
-- build it again rather than change it here.
@*/

/*@ Begin/words
**WebRTC** lets two programs talk **directly**, peer to peer, with no server in the middle carrying the messages. Browsers use it for video calls; dataChannelXT uses its **data channels** to send text and bytes.

- `dcInit` starts the native layer (the first peer starts it too).
- `dcLibraryVersion` says which libdatachannel is built in.
- `dcLastError` says why the last call failed; `dcClearError` empties it.
@*/

/*@ Begin/try
on mouseUp
   local tOut
   -- start the native layer now (or it starts by itself
   -- at the first peer)
   get dcInit()
   put "Started:" && it && "(0 is good)" into tOut
   put cr & dcLibraryVersion() after tOut
   -- an error message stays until it is cleared
   dcClearError
   get dcLastError()
   put cr & "Last error:" && it & "(none)" after tOut
   -- states are numbers; the helpers name them
   put cr & "State 2 is" && dcStateName(2) after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Begin/expect
^Started: 0 \(0 is good\)\nlibdatachannel v\d+\.\d+\.\d+\nLast error: \(none\)\nState 2 is connected$
@*/

/*@ Peers/words
A **peer** is your end of one connection. Each connection needs its own.

- `dcCreatePeer` makes one. Its text names **ICE servers**, helpers that find a way through home routers: empty is enough for two peers on one computer, and a line like stun:stun.l.google.com:19302 helps across the internet.
- `dcPeerState` and `dcGatheringState` are numbers; `dcStateName` and `dcGatheringName` say them in words.
- `dcFreePeer` frees it, and its handle stops working.
@*/

/*@ Peers/try
on mouseUp
   local tPeer, tOut
   -- a peer connection: empty means no helper servers,
   -- enough for two peers on one computer
   put dcCreatePeer("") into tPeer
   put "Peer made?" && (tPeer > 0) into tOut
   get dcStateName(dcPeerState(tPeer))
   put cr & "State:" && it after tOut
   get dcGatheringName(dcGatheringState(tPeer))
   put cr & "Finding addresses:" && it after tOut
   -- free it when done: its handle goes stale
   get dcFreePeer(tPeer)
   get dcStateName(dcPeerState(tPeer))
   put cr & "After freeing:" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Peers/expect
^Peer made\? true\nState: new\nFinding addresses: new\nAfter freeing: unknown$
@*/

/*@ Offer/words
Before two peers can talk, they swap two short texts: an **offer** and an **answer**. Each lists a peer's **candidates**: the addresses it can be reached at.

- Making a channel makes the peer write its offer; it is done when `dcGatheringState` is 2.
- `dcLocalDescription` gives the text; `dcLocalDescriptionType` says "offer" or "answer".

How the text travels is up to you: a web server, a chat, an email, a QR code. This is **signalling**.
@*/

/*@ Offer/try
on mouseUp
   local tA, tCh, tSdp, tEnd, tOut
   put dcCreatePeer("") into tA
   -- a channel makes the peer write an offer
   put dcCreateChannel(tA, "chat") into tCh
   -- once it has found its addresses (candidates)
   put the ticks + 300 into tEnd -- at most 5 seconds
   wait until dcGatheringState(tA) = 2 or the ticks > tEnd
   put "Type:" && dcLocalDescriptionType(tA) into tOut
   -- the offer is text: send it to the other side any
   -- way you like (a server, a chat, a QR code)
   put dcLocalDescription(tA) into tSdp
   get char 1 to 3 of tSdp -- (its first line is v=0)
   put cr & "Starts:" && it after tOut
   get the number of lines of tSdp > 5
   put cr & "Many lines?" && it after tOut
   get tSdp contains "a=candidate"
   put cr & "Has addresses?" && it after tOut
   get dcFreePeer(tA)
   put tOut into field "Result"
end mouseUp
@*/

/*@ Offer/expect
^Type: offer\nStarts: v=0\nMany lines\? true\nHas addresses\? true$
@*/

/*@ Connect/words
Here both peers live in one script, so the texts go straight across:

1. A writes its offer; B takes it with `dcSetRemoteDescription` and writes its answer.
2. A takes B's answer the same way.
3. The peers try the addresses, and the channel opens.

`dcChannelIsOpen` says when it is open; `dcSelectedCandidatePair` says which addresses won. The waits stop after 5 seconds at most.
@*/

/*@ Connect/try
on mouseUp
   local tA, tB, tCh, tSdp, tEnd, tPair, tOut
   put dcCreatePeer("") into tA -- A will offer
   put dcCreatePeer("") into tB -- B will answer
   put dcCreateChannel(tA, "chat") into tCh
   put the ticks + 300 into tEnd -- at most 5 seconds
   wait until dcGatheringState(tA) = 2 or the ticks > tEnd
   put dcLocalDescription(tA) into tSdp
   get dcSetRemoteDescription(tB, tSdp, "offer")
   put dcLocalDescription(tB) into tSdp
   get dcSetRemoteDescription(tA, tSdp, "answer")
   wait until dcChannelIsOpen(tCh) or the ticks > tEnd
   put "A is:" && dcStateName(dcPeerState(tA)) into tOut
   get dcChannelIsOpen(tCh)
   put cr & "Channel open?" && it after tOut
   -- the pair of addresses the peers chose
   put dcSelectedCandidatePair(tA) into tPair
   get tPair["localCandidate"] is not empty
   put cr & "Route found?" && it after tOut
   get dcFreePeer(tA)
   get dcFreePeer(tB)
   get dcPoll() -- and drop the events left over
   put tOut into field "Result"
end mouseUp
@*/

/*@ Connect/expect
^A is: connected\nChannel open\? true\nRoute found\? true$
@*/

/*@ Messages/words
Once the channel is open, send with `dcSendText`. It arrives on the other side as an **event**.

- `dcPoll` gives every event since the last poll, oldest first, as an array. Each has a "name", the "peer" and "channel" it is about, and more.
- A message arrives as a "dcMessage" event, with the text under "text" (bytes come under "payload").

Other events say when a channel opens or closes, or a state changes. In an app, poll on a timer, or let `dcStartPolling` do it.
@*/

/*@ Messages/try
on mouseUp
   local tA, tB, tCh, tSdp, tEnd, tE, tOut
   put dcCreatePeer("") into tA -- A will offer
   put dcCreatePeer("") into tB -- B will answer
   put dcCreateChannel(tA, "chat") into tCh
   put the ticks + 300 into tEnd -- at most 5 seconds
   wait until dcGatheringState(tA) = 2 or the ticks > tEnd
   put dcLocalDescription(tA) into tSdp
   get dcSetRemoteDescription(tB, tSdp, "offer")
   put dcLocalDescription(tB) into tSdp
   get dcSetRemoteDescription(tA, tSdp, "answer")
   wait until dcChannelIsOpen(tCh) or the ticks > tEnd
   get dcSendText(tCh, "Hello, B!")
   wait 200 milliseconds -- then read every new event
   repeat for each element tE in dcPoll()
      if tE["name"] is "dcMessage" then
         put "B got:" && tE["text"] into tOut
      end if
   end repeat
   get dcFreePeer(tA)
   get dcFreePeer(tB)
   get dcPoll() -- and drop the events left over
   put tOut into field "Result"
end mouseUp
@*/

/*@ Messages/expect
^B got: Hello, B!$
@*/

/*@ Bytes/words
`dcSendData` sends **bytes**, numbers from 0 to 255: pictures, files, game moves.

- It returns 0 when the message is queued, and a negative number when not: -4 means bigger than 60000 bytes. Cut big things into pieces.
- `dcBufferedAmount` says how many bytes still wait to go out. Wait while it is high, so the queue does not grow forever.
- `dcChannelMaxMessage` says the largest message the other side takes.
@*/

/*@ Bytes/try
on mouseUp
   local tA, tB, tCh, tSdp, tEnd, tOut
   put dcCreatePeer("") into tA -- A will offer
   put dcCreatePeer("") into tB -- B will answer
   put dcCreateChannel(tA, "chat") into tCh
   put the ticks + 300 into tEnd -- at most 5 seconds
   wait until dcGatheringState(tA) = 2 or the ticks > tEnd
   put dcLocalDescription(tA) into tSdp
   get dcSetRemoteDescription(tB, tSdp, "offer")
   put dcLocalDescription(tB) into tSdp
   get dcSetRemoteDescription(tA, tSdp, "answer")
   wait until dcChannelIsOpen(tCh) or the ticks > tEnd
   -- data is any bytes, even 0 and 255
   get dcSendData(tCh, numToByte(0) & numToByte(255))
   put "Two bytes sent:" && it && "(0 is good)" into tOut
   -- over 60000 bytes is refused with error -4
   get dcSendData(tCh, binaryEncode("x60001", ""))
   put cr & "Too big:" && it after tOut
   put cr & "Queued:" && dcBufferedAmount(tCh) after tOut
   get dcFreePeer(tA)
   get dcFreePeer(tB)
   get dcPoll() -- and drop the events left over
   put tOut into field "Result"
end mouseUp
@*/

/*@ Bytes/expect
^Two bytes sent: 0 \(0 is good\)\nToo big: -4\nQueued: \d+$
@*/

/*@ Options/words
`dcCreateChannelEx` makes a channel your way. Besides its **label**, it takes:

- a **protocol**, a name for what it carries;
- **unordered** (true): a message need not wait for the one before it;
- **retries** and a **time limit** in milliseconds: 0 retries means a lost message stays lost, fine for game moves where only the newest counts; -1 means no limit;
- **negotiated** with a **stream id**: both sides make the channel themselves with the same id, and nothing is announced.
@*/

/*@ Options/try
on mouseUp
   local tA, tCh, tOut
   put dcCreatePeer("") into tA
   -- label, protocol, unordered, retries, time limit,
   -- negotiated, stream id (-1 means "not set")
   put dcCreateChannelEx(tA, "moves", "game", true, 0, \
         -1, false, -1) into tCh
   put "Label:" && dcChannelLabel(tCh) into tOut
   get dcChannelProtocol(tCh)
   put cr & "Protocol:" && it after tOut
   get dcChannelPeer(tCh) = tA
   put cr & "Belongs to A?" && it after tOut
   -- negotiated: both sides make it with the same id
   put dcCreateChannelEx(tA, "ctrl", "", false, -1, \
         -1, true, 5) into tCh
   get dcChannelStreamId(tCh)
   put cr & "Stream id:" && it after tOut
   get dcFreePeer(tA)
   put tOut into field "Result"
end mouseUp
@*/

/*@ Options/expect
^Label: moves\nProtocol: game\nBelongs to A\? true\nStream id: 5$
@*/

/*@ Goodbye/words
When you are done, close things:

- `dcCloseChannel` closes a channel; both ends get a "dcChannelClosed" event.
- `dcClosePeer` hangs up the whole connection; the other side sees its state go to closed.
- `dcFreePeer` then frees the peer and its channels.

Never call `dcCleanup` while other stacks may use dataChannelXT: it ends every peer in OXT-Beyond, not just yours.
@*/

/*@ Goodbye/try
on mouseUp
   local tA, tB, tCh, tSdp, tEnd, tOut
   put dcCreatePeer("") into tA -- A will offer
   put dcCreatePeer("") into tB -- B will answer
   put dcCreateChannel(tA, "chat") into tCh
   put the ticks + 300 into tEnd -- at most 5 seconds
   wait until dcGatheringState(tA) = 2 or the ticks > tEnd
   put dcLocalDescription(tA) into tSdp
   get dcSetRemoteDescription(tB, tSdp, "offer")
   put dcLocalDescription(tB) into tSdp
   get dcSetRemoteDescription(tA, tSdp, "answer")
   wait until dcChannelIsOpen(tCh) or the ticks > tEnd
   -- close the channel, then hang up: B hears both
   get dcCloseChannel(tCh)
   get dcClosePeer(tA) -- (A's handle still works)
   wait until dcPeerState(tB) = 5 or the ticks > tEnd
   put "Channel open?" && dcChannelIsOpen(tCh) into tOut
   get dcStateName(dcPeerState(tB))
   put cr & "B is:" && it after tOut
   get dcFreePeer(tA)
   get dcFreePeer(tB)
   get dcPoll() -- and drop the events left over
   put tOut into field "Result"
end mouseUp
@*/

/*@ Goodbye/expect
^Channel open\? false\nB is: closed$
@*/
