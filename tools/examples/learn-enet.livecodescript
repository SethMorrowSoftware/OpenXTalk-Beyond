script "OXTExampleLearnENet"
-- OXT-Beyond: builds "Learn ENet", eight lessons in enetxt, the xTalk
-- Suite's ENet extension (reliable UDP, as games use it) and its
-- enetHelpers library, which OXT-Beyond has built in
-- (https://github.com/SethMorrowSoftware/xtalk-suite, enetxt/).
--
-- It is one of the "Learn" stacks (builder.livecodescript, "Learn stacks"):
-- each lesson says what it shows in plain words, and runs a real script
-- that calls ENet, which the user can change, run again and copy; a click
-- on a call opens its page of the reference, and the Reference card has
-- every handler of the extension and of enetHelpers, from the IDE's
-- Dictionary. Every lesson talks to itself on this computer (127.0.0.1),
-- a server and a client in one script, polled in a loop of at most a
-- second, and gives back every host and its hold on ENet before it ends
-- (enInitialize is counted for the whole process). The ports are fixed,
-- 9703 to 9708, and close again at once. It does not use enetHelpers'
-- pump (enStartPolling), which is shared by every stack and would take
-- another window's events. test-learn-stacks.livecodescript (in
-- tools/examples) runs every lesson's script on a real engine with ENet
-- loaded and checks its result.

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex, tLessons
   exUseScripts the script of me
   put "Learn ENet" into tInfo["name"]
   put "Reliable UDP, through enetxt" into tInfo["credit"]
   put "gamepad-2" into tInfo["icon"]
   put lkColor("teal") into tInfo["accent"]
   put lkColor("sky") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn ENet|Fast messages between programs, the way games send them.|gamepad-2|front" & return & \
         "Begin|Getting Started|Take a hold on ENet, and give it back.|play|page" & return & \
         "Servers|Servers|A host that listens on a port.|hard-drive|page" & return & \
         "Connect|Connecting|A client joins, and polling makes it happen.|zap|page" & return & \
         "Text|Sending Text|A message that is sure to arrive.|send|page" & return & \
         "Bytes|Sending Bytes|Small packets of numbers, and their limit.|braces|page" & return & \
         "Channels|Channels|Lanes that never wait for each other.|split|page" & return & \
         "Health|Connection Health|State, bytes sent, pings and time-outs.|chart-column|page" & return & \
         "Goodbye|Saying Goodbye|End a connection politely.|power|page" & return & \
         "Reference|Reference|Every ENet handler: what it takes and gives back.|book-open|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   exLearnDocs "org.openxtalk.library.enet,enetHelpers"
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      put exCardInfo(tIndex, "name") & comma after tLessons
   end repeat
   delete the last char of tLessons
   -- (the probe calls both halves: the extension's library version and
   -- the helpers' state names, and gives the version when both answer)
   exLearnKit "Start", tLessons, "ENet", \
         "enLibraryVersion() & char 1 to 0 of enStateName(5)", \
         "lcb|org.openxtalk.library.enet|enetxt" & return & "lcs|enetHelpers|enetHelpers.livecodescript"
   repeat for each item tIndex in tLessons
      if tIndex is not "Reference" then
         exLearnLesson tIndex
      end if
   end repeat
   exLearnReference "Reference"
   exLearnFront "OXT-BEYOND  " & numToCodepoint(183) & "  RELIABLE UDP THROUGH ENETXT", \
         "Messages, fast", \
         "Eight short lessons in ENet, which sends messages between programs the way games do. " & \
         "Each runs a real script that you can change, run again and copy.", \
         "lightbulb|Each lesson starts in plain words, and talks only to this computer." & return & \
         "book-open|Click a call to read its parameters, units and result." & return & \
         "info|The lessons use ports 9703 to 9708, only while they run."
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn ENet.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

/*@ stack
-- Learn ENet: eight lessons in enetxt, the xTalk Suite's ENet extension.
-- The lessons are run by the script of the group "Learn", and the window
-- by the script of the group "Frame". It was built by
-- tools/examples/learn-enet.livecodescript in the OXT-Beyond repository;
-- build it again rather than change it here.
@*/

/*@ Begin/words
**ENet** sends messages between programs over the internet, fast, the way games do. It runs on UDP, and adds what UDP lacks: connections, and packets that arrive in order and for sure when you ask.

- `enInitialize` takes a hold on the library; `enDeinitialize` gives it back, once for each hold.
- `enLibraryVersion` says which ENet is built in.
- `enLastError` says why the last call failed; `enClearError` empties it.
@*/

/*@ Begin/try
on mouseUp
   local tOut
   -- take a hold on ENet before any other call
   get enInitialize()
   put "Started:" && it && "(0 is good)" into tOut
   put cr & "Library:" && enLibraryVersion() after tOut
   -- an error message stays until it is cleared
   enClearError
   get enLastError()
   put cr & "Last error:" && it & "(none)" after tOut
   -- give the hold back when you are done: once for
   -- each enInitialize, as a bare command
   enDeinitialize
   put cr & "Hold given back" after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Begin/expect
^Started: 0 \(0 is good\)\nLibrary: enet \d+\.\d+\.\d+\nLast error: \(none\)\nHold given back$
@*/

/*@ Servers/words
A **host** is your end of the line. A **server** host listens on a **port**, a number from 1 to 65535, for others to connect.

- `enHostCreateServer` takes the address to listen on, the port (0 for any free one), how many peers may join, the **channels** each has, and speed limits in bytes a second (0 for none).
- `enHostStatus` says where it listens and how many peers it has.
- `enHostDestroy` closes it.
@*/

/*@ Servers/try
on mouseUp
   local tSrv, tA, tOut
   get enInitialize()
   -- a server on this computer: port 0 means "any free
   -- port", at most 8 peers, 2 channels, no speed limit
   get enHostCreateServer("127.0.0.1", 0, 8, 2, 0, 0)
   put it into tSrv
   put "Server made?" && (tSrv > 0) into tOut
   put enHostStatus(tSrv) into tA
   set the itemDelimiter to ":"
   get item 1 of tA["address"]
   put cr & "Address:" && it after tOut
   get item 2 of tA["address"] > 0
   put cr & "Port chosen?" && it after tOut
   put cr & "Peers:" && tA["peerCount"] after tOut
   -- closing it frees the port
   get enHostDestroy(tSrv)
   get enHostStatus(tSrv) is empty
   put cr & "Gone after closing?" && it after tOut
   enDeinitialize
   put tOut into field "Result"
end mouseUp
@*/

/*@ Servers/expect
^Server made\? true\nAddress: 127\.0\.0\.1\nPort chosen\? true\nPeers: 0\nGone after closing\? true$
@*/

/*@ Connect/words
A **client** host connects to a server. `enConnect` returns a **peer** handle at once, but the connection is only real when an event says so.

Events come from `enPoll`, which you call over and over: nothing happens between polls. Each event has a "name": enetConnect, enetReceive or enetDisconnect.

- `enPeerStatus` and `enStateName` say how a peer is doing.
@*/

/*@ Connect/try
on mouseUp
   local tSrv, tCli, tPeer, tE, tOut
   -- a client connects, with 7 as its data (a version)
   get enInitialize()
   put enHostCreateServer("", 9703, 4, 1, 0, 0) into tSrv
   put enHostCreateClient(1, 1, 0, 0) into tCli
   put enConnect(tCli, "127.0.0.1", 9703, 1, 7) into tPeer
   -- nothing happens until a host is polled
   repeat 200 times
      get enPoll(tCli)
      put enPoll(tSrv) into tE
      if tE[1]["name"] is "enetConnect" then exit repeat
      wait 5 milliseconds
   end repeat
   put "Server got:" && tE[1]["name"] into tOut
   put cr & "With data:" && tE[1]["data"] after tOut
   put enPeerStatus(tPeer) into tE
   get enStateName(tE["state"])
   put cr & "Client is:" && it after tOut
   get enHostDestroy(tCli)
   get enHostDestroy(tSrv)
   enDeinitialize
   put tOut into field "Result"
end mouseUp
@*/

/*@ Connect/expect
^Server got: enetConnect\nWith data: 7\nClient is: connected$
@*/

/*@ Text/words
Once connected, send a **packet**: a message that arrives whole, or not at all.

- `enSendText` sends text on a channel, with a flag: 0 is **reliable**, resent until it arrives.
- The other side gets an enetReceive event. Its "payload" is bytes: `textDecode` turns them back into text.

Two programs on one computer talk through 127.0.0.1, its own address.
@*/

/*@ Text/try
on mouseUp
   local tSrv, tCli, tPeer, tE, tOut
   get enInitialize()
   put enHostCreateServer("", 9704, 4, 1, 0, 0) into tSrv
   put enHostCreateClient(1, 1, 0, 0) into tCli
   put enConnect(tCli, "127.0.0.1", 9704, 1, 0) into tPeer
   repeat 200 times
      get enPoll(tCli)
      put enPoll(tSrv) into tE
      -- connected: send on channel 0, reliably (0)
      if tE[1]["name"] is "enetConnect" then
         get enSendText(tPeer, 0, "Hello, server!", 0)
      end if
      if tE[1]["name"] is "enetReceive" then exit repeat
      wait 5 milliseconds
   end repeat
   put "Server got:" && tE[1]["name"] into tOut
   get textDecode(tE[1]["payload"], "UTF-8")
   put cr & "Text:" && it after tOut
   get enHostDestroy(tCli)
   get enHostDestroy(tSrv)
   enDeinitialize
   put tOut into field "Result"
end mouseUp
@*/

/*@ Text/expect
^Server got: enetReceive\nText: Hello, server!$
@*/

/*@ Bytes/words
Under the text, a packet is **bytes**, numbers from 0 to 255. Games send bytes because they are small.

- `enSend` sends any bytes, up to 60000 a packet. It returns 0 when the packet is queued, and a negative number when not: -4 means too big.
- Packets go out at the next `enPoll`, or at once with `enFlush`.
- `byteToNum` reads a byte back as a number.
@*/

/*@ Bytes/try
on mouseUp
   local tSrv, tCli, tPeer, tE, tOut
   get enInitialize()
   put enHostCreateServer("", 9705, 4, 1, 0, 0) into tSrv
   put enHostCreateClient(1, 1, 0, 0) into tCli
   put enConnect(tCli, "127.0.0.1", 9705, 1, 0) into tPeer
   get enSend(tPeer, 0, format("%60001s", ""), 0)
   put "60001 bytes:" && it && "(too many)" into tOut
   repeat 200 times
      get enPoll(tCli)
      put enPoll(tSrv) into tE
      if tE[1]["name"] is "enetConnect" then
         get enSend(tPeer, 0, numToByte(200), 0)
      end if
      if tE[1]["name"] is "enetReceive" then exit repeat
      wait 5 milliseconds
   end repeat
   get byteToNum(tE[1]["payload"])
   put cr & "Arrived: one byte, worth" && it after tOut
   get enHostDestroy(tCli)
   get enHostDestroy(tSrv)
   enDeinitialize
   put tOut into field "Result"
end mouseUp
@*/

/*@ Bytes/expect
^60001 bytes: -4 \(too many\)\nArrived: one byte, worth 200$
@*/

/*@ Channels/words
A connection can have several **channels**, numbered from 0. A late packet on one never holds up another.

Each send has a **delivery** flag:

- 0 **reliable**: resent until it arrives, in order. For chat and moves.
- 1 **unreliable**: in order, but may be dropped. For where a player is now: a newer one comes soon.
- 2: may be dropped or arrive out of order.
@*/

/*@ Channels/try
on mouseUp
   local tSrv, tCli, tPeer, tE, tOut
   get enInitialize()
   put enHostCreateServer("", 9706, 4, 2, 0, 0) into tSrv
   put enHostCreateClient(1, 2, 0, 0) into tCli
   put enConnect(tCli, "127.0.0.1", 9706, 2, 0) into tPeer
   repeat 200 times
      get enPoll(tCli)
      put enPoll(tSrv) into tE
      -- channel 1, unreliable (1): soon out of date
      if tE[1]["name"] is "enetConnect" then
         get enSendText(tPeer, 1, "x=10 y=20", 1)
      end if
      if tE[1]["name"] is "enetReceive" then exit repeat
      wait 5 milliseconds
   end repeat
   put "Channel:" && tE[1]["channel"] into tOut
   get textDecode(tE[1]["payload"], "UTF-8")
   put cr & "Text:" && it after tOut
   get enHostDestroy(tCli)
   get enHostDestroy(tSrv)
   enDeinitialize
   put tOut into field "Result"
end mouseUp
@*/

/*@ Channels/expect
^Channel: 1\nText: x=10 y=20$
@*/

/*@ Health/words
A game shows if a connection is good.

- `enPeerStatus` gives the peer's "state", its round trip in milliseconds ("rtt"), packets lost, and bytes sent and received.
- `enFormatBytes` writes a byte count for people: 60 B, 1.5 KiB.
- `enSetPeerPingInterval` and `enSetPeerTimeout` decide how often a quiet peer is checked, and when it counts as gone.
@*/

/*@ Health/try
on mouseUp
   local tSrv, tCli, tPeer, tE, tOut
   get enInitialize()
   put enHostCreateServer("", 9707, 4, 1, 0, 0) into tSrv
   put enHostCreateClient(1, 1, 0, 0) into tCli
   put enConnect(tCli, "127.0.0.1", 9707, 1, 0) into tPeer
   repeat 200 times
      get enPoll(tCli)
      put enPoll(tSrv) into tE
      if tE[1]["name"] is "enetConnect" then exit repeat
      wait 5 milliseconds
   end repeat
   -- ping every second; give up after 5 to 30 seconds
   get enSetPeerPingInterval(tPeer, 1000)
   get enSetPeerTimeout(tPeer, 0, 5000, 30000)
   put enPeerStatus(tPeer) into tE
   put "State:" && enStateName(tE["state"]) into tOut
   get enFormatBytes(tE["bytesSent"])
   put cr & "Bytes sent:" && it after tOut
   get enHostDestroy(tCli)
   get enHostDestroy(tSrv)
   enDeinitialize
   put tOut into field "Result"
end mouseUp
@*/

/*@ Health/expect
^State: connected\nBytes sent: \d+ B$
@*/

/*@ Goodbye/words
When you are done, say goodbye.

- `enDisconnect` ends a connection politely: queued packets go first, then both sides get an enetDisconnect event.
- `enDisconnectNow` ends it at once; `enResetPeer` just forgets it.

After that the peer handle is retired: a send to it is refused. `enHostDestroy` then closes the host, and `enDeinitialize` gives your hold back.
@*/

/*@ Goodbye/try
on mouseUp
   local tSrv, tCli, tPeer, tE, tOut
   get enInitialize()
   put enHostCreateServer("", 9708, 4, 1, 0, 0) into tSrv
   put enHostCreateClient(1, 1, 0, 0) into tCli
   put enConnect(tCli, "127.0.0.1", 9708, 1, 0) into tPeer
   repeat 200 times
      get enPoll(tCli)
      put enPoll(tSrv) into tE
      -- connected: say goodbye politely
      if tE[1]["name"] is "enetConnect" then
         get enDisconnect(tPeer, 0)
      end if
      if tE[1]["name"] = "enetDisconnect" then exit repeat
      wait 5 milliseconds
   end repeat
   put "Server got:" && tE[1]["name"] into tOut
   get enSendText(tPeer, 0, "still there?", 0)
   put cr & "A send after:" && it && "(gone)" after tOut
   get enHostDestroy(tCli)
   get enHostDestroy(tSrv)
   enDeinitialize
   put tOut into field "Result"
end mouseUp
@*/

/*@ Goodbye/expect
^Server got: enetDisconnect\nA send after: -\d+ \(gone\)$
@*/
