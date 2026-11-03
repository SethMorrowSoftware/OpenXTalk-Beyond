script "OXTExampleLearnTorrentXT"
-- OXT-Beyond: builds "Learn TorrentXT", nine lessons in torrentxt, the
-- xTalk Suite's BitTorrent extension (over libtorrent) and its
-- torrentHelpers library, which OXT-Beyond has built in
-- (https://github.com/SethMorrowSoftware/xtalk-suite, torrentxt/).
--
-- It is one of the "Learn" stacks (builder.livecodescript, "Learn stacks"):
-- each lesson says what it shows in plain words, and runs a real script
-- that calls TorrentXT, which the user can change, run again and copy; a
-- click on a call opens its page of the reference, and the Reference card
-- has every handler of the extension and of torrentHelpers, from the
-- IDE's Dictionary. libtorrent allows ONE session in the process, so a
-- lesson that needs one starts it, turns off the DHT and local peer
-- discovery at once (the lessons only ever share their own tiny files,
-- in the temporary folder, and never download), and stops it before it
-- ends. It keeps the handle in the global gLearnBt and first stops the
-- one that global holds, so a run that threw halfway (after an edit)
-- cannot leave a session on that refuses every later lesson's. A lesson
-- run while another stack holds the session is refused, as that stack's
-- would be. The lessons do not use the helpers' shared pump
-- (btStartPolling). test-learn-stacks.livecodescript (in tools/examples)
-- runs every lesson's script on a real engine with TorrentXT loaded and
-- checks its result.

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex, tLessons
   exUseScripts the script of me
   put "Learn TorrentXT" into tInfo["name"]
   put "BitTorrent, through torrentxt" into tInfo["credit"]
   put "package" into tInfo["icon"]
   put lkColor("orange") into tInfo["accent"]
   put lkColor("rose") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn TorrentXT|Share files peer to peer, with BitTorrent.|package|front" & return & \
         "Begin|Getting Started|Start the one session, and stop it.|play|page" & return & \
         "Settings|Settings|Turn features off, and set limits.|settings|page" & return & \
         "Create|Making a Torrent|Describe a file, so others can fetch it.|file-plus|page" & return & \
         "Seeding|Seeding|Share a file you already have.|send|page" & return & \
         "Magnets|Magnet Links|A torrent from one line of text.|hash|page" & return & \
         "Events|Events|Hear what the session did.|list|page" & return & \
         "Files|Files|The files in a torrent, and skipping some.|folder-open|page" & return & \
         "Control|Control|Pause, speed limits and the queue.|timer|page" & return & \
         "Goodbye|Saying Goodbye|Remove a torrent, and stop the session.|power|page" & return & \
         "Reference|Reference|Every TorrentXT handler: what it takes and gives back.|book-open|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   exLearnDocs "org.openxtalk.library.torrent,torrentHelpers"
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      put exCardInfo(tIndex, "name") & comma after tLessons
   end repeat
   delete the last char of tLessons
   -- (the probe calls both halves, the extension and the helpers' state
   -- names, and gives the extension's name when both answer: TorrentXT
   -- has no version call)
   exLearnKit "Start", tLessons, "TorrentXT", \
         "char 1 to 0 of (btLastError() & btStateName(5)) & the cExtension of this stack", \
         "lcb|org.openxtalk.library.torrent|torrentxt" & return & \
         "lcs|torrentHelpers|torrentHelpers.livecodescript"
   repeat for each item tIndex in tLessons
      if tIndex is not "Reference" then
         exLearnLesson tIndex
      end if
   end repeat
   exLearnReference "Reference"
   exLearnFront "OXT-BEYOND  " & numToCodepoint(183) & "  BITTORRENT THROUGH TORRENTXT", \
         "Share it with everyone", \
         "Nine short lessons in BitTorrent, which shares files among many computers, each giving pieces to the others. " & \
         "Each runs a real script that you can change, run again and copy.", \
         "lightbulb|Each lesson starts in plain words, and stays on this computer." & return & \
         "book-open|Click a call to read its parameters, units and result." & return & \
         "info|The lessons share only tiny files of their own, in the temporary folder."
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn TorrentXT.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

/*@ stack
-- Learn TorrentXT: nine lessons in torrentxt, the xTalk Suite's
-- BitTorrent extension.
-- The lessons are run by the script of the group "Learn", and the window
-- by the script of the group "Frame". It was built by
-- tools/examples/learn-torrentxt.livecodescript in the OXT-Beyond repository;
-- build it again rather than change it here.
@*/

/*@ Begin/words
**BitTorrent** shares files among many computers at once. Each one, a **peer**, gets pieces from the others and gives its pieces back, so no single server carries it all.

- `btStartSession` starts the one **session** that runs it all. Only one may be on at a time: a second call gives 0, and `btLastError` says why.
- `btStopSession` stops it. Always stop it when you are done.

The lessons keep the session in a global, gLearnBt, so a run that stops halfway can be cleaned up by the next.
@*/

/*@ Begin/try
on mouseUp
   global gLearnBt
   local tOut
   -- first stop one that an unfinished run left on
   if gLearnBt is an integer then btStopSession gLearnBt
   -- one session runs all of BitTorrent
   put btStartSession() into gLearnBt
   put "Session made?" && (gLearnBt > 0) into tOut
   -- only one may be on at a time: 0 means refused,
   -- and btLastError says why
   put cr & "A second one:" && btStartSession() after tOut
   get btListenPort(gLearnBt) > 0
   put cr & "Listening for peers?" && it after tOut
   -- always stop it when you are done
   btStopSession gLearnBt
   put tOut into field "Result"
end mouseUp
@*/

/*@ Begin/expect
^Session made\? true\nA second one: 0\nListening for peers\? true$
@*/

/*@ Settings/words
A session has hundreds of **settings**, each with a name.

- `btSetBool` turns one on or off, `btSetInt` sets a number and `btSetString` some text. Each gives 0 when it works, and -3 for a name it does not know.
- `btGetSetting` reads one back.

A new session goes online at once. To stay on this computer, the lessons turn off the **DHT** (how peers find each other over the internet) and **local peer discovery** (on your network).
@*/

/*@ Settings/try
on mouseUp
   global gLearnBt
   local tOut
   if gLearnBt is an integer then btStopSession gLearnBt
   put btStartSession() into gLearnBt
   -- on and off settings take true or false
   get btSetBool(gLearnBt, "enable_dht", false)
   put "DHT off:" && it && "(0 is good)" into tOut
   get btSetBool(gLearnBt, "enable_lsd", false)
   -- numbers: here bytes a second, 0 for no limit
   get btSetInt(gLearnBt, "upload_rate_limit", 51200)
   get btGetSetting(gLearnBt, "upload_rate_limit")
   put cr & "Limit:" && btFormatBytes(it) after tOut
   -- a name it does not know is refused
   get btSetInt(gLearnBt, "speed", 1)
   put cr & "Unknown name:" && it after tOut
   btStopSession gLearnBt
   put tOut into field "Result"
end mouseUp
@*/

/*@ Settings/expect
^DHT off: 0 \(0 is good\)\nLimit: 50 KiB\nUnknown name: -3$
@*/

/*@ Create/words
A **torrent** describes what is shared: the names and sizes of the files, and a fingerprint (**hash**) of each **piece**, so every piece can be checked when it arrives.

- `btCreateTorrent` makes one from a file or a folder, and gives its bytes. Save them as a .torrent file and give it to others.
- Its other parameters: the piece size (0 lets it choose), options (0 for the usual) and **trackers**, servers that introduce peers (none: peers come from the DHT).

It needs no session.
@*/

/*@ Create/try
on mouseUp
   local tDir, tFile, tData, tOut
   -- a file to share, in the temporary folder
   put specialFolderPath("temporary") into tDir
   put tDir & "/hello.txt" into tFile
   put "Hello, swarm!" into url ("file:" & tFile)
   put btCreateTorrent(tFile, 0, 0, empty) into tData
   -- (0: choose the piece size; 0: usual options;
   -- empty: no trackers, peers come from the DHT)
   get the number of bytes in tData
   put "Torrent:" && it && "bytes" into tOut
   get tData contains "hello.txt"
   put cr & "Names the file?" && it after tOut
   -- save it as a .torrent file to give to others
   put tDir & "/hello.torrent" into tFile
   put tData into url ("binfile:" & tFile)
   put cr & "Saved?" && (the result is empty) after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Create/expect
^Torrent: \d+ bytes\nNames the file\? true\nSaved\? true$
@*/

/*@ Seeding/words
To share a file, add its torrent to the session with `btAddTorrentFile`, saving into the folder that holds the file. The session checks every piece, finds it has them all, and starts **seeding**: giving pieces to whoever asks.

- `btTorrentStatus` gives an array about a torrent: its "state", "progress" (0 to 1), "name", "totalSize", peers, speeds and more.
- `btStateName` says a state in words, and `btFormatBytes` a size.
@*/

/*@ Seeding/try
on mouseUp
   global gLearnBt
   local tDir, tFile, tData, tT, tE, tOut
   if gLearnBt is an integer then btStopSession gLearnBt
   put btStartSession() into gLearnBt
   get btSetBool(gLearnBt, "enable_dht", false) -- offline
   get btSetBool(gLearnBt, "enable_lsd", false)
   put specialFolderPath("temporary") into tDir
   put tDir & "/hello.txt" into tFile
   put "Hello, swarm!" into url ("file:" & tFile)
   put btCreateTorrent(tFile, 0, 0, empty) into tData
   -- saved where the file is, it has it all: it seeds
   put btAddTorrentFile(gLearnBt, tData, tDir) into tT
   repeat 50 times -- it checks the file first
      put btTorrentStatus(tT) into tE
      if tE["isSeeding"] is 1 then exit repeat
      wait 20 milliseconds
   end repeat
   put "State:" && btStateName(tE["state"]) into tOut
   get tE["progress"] * 100 -- (progress is 0 to 1)
   put cr & "Have:" && it & "%" after tOut
   btStopSession gLearnBt
   put tOut into field "Result"
end mouseUp
@*/

/*@ Seeding/expect
^State: seeding\nHave: 100%$
@*/

/*@ Magnets/words
A **magnet link** is a torrent in one line of text: its **info hash** and a name. Anyone with the link can fetch the rest from peers.

- `btAddMagnet` adds one, with the folder to save into.
- `btInfoHash` gives a torrent's hash, 40 hex digits.

The state stays "fetching metadata" here: with the DHT off and no trackers, no peer can send the torrent. Online, it would.
@*/

/*@ Magnets/try
on mouseUp
   global gLearnBt
   local tDir, tLink, tT, tE, tOut
   if gLearnBt is an integer then btStopSession gLearnBt
   put btStartSession() into gLearnBt
   get btSetBool(gLearnBt, "enable_dht", false) -- offline
   get btSetBool(gLearnBt, "enable_lsd", false)
   -- a magnet link holds just the torrent's hash and name
   put "magnet:?xt=urn:btih:" & \
         "0123456789abcdef0123456789abcdef01234567" & \
         "&dn=demo" into tLink
   put specialFolderPath("temporary") into tDir
   put btAddMagnet(gLearnBt, tLink, tDir) into tT
   wait 200 milliseconds
   put btTorrentStatus(tT) into tE
   put "Name:" && tE["name"] into tOut
   get char 1 to 16 of btInfoHash(tT)
   put cr & "Hash:" && it after tOut
   -- next it would ask peers for the rest of the torrent
   put cr & btStateName(tE["state"]) after tOut
   btStopSession gLearnBt
   put tOut into field "Result"
end mouseUp
@*/

/*@ Magnets/expect
^Name: demo\nHash: 0123456789abcdef\nfetching metadata$
@*/

/*@ Events/words
The session works on its own threads, and keeps a queue of what happened: a torrent added, finished, paused, an error.

- `btPoll` gives every event since the last poll, oldest first, as an array. Each has a "name" and the "torrent" it is about, and more.
- "stateChanged" comes with each new "state".

In an app, poll on a timer, or let `btStartPolling` do it: it sends each event to your stack as a message with the event's name.
@*/

/*@ Events/try
on mouseUp
   global gLearnBt
   local tDir, tFile, tData, tT, tE, tOut
   if gLearnBt is an integer then btStopSession gLearnBt
   put btStartSession() into gLearnBt
   get btSetBool(gLearnBt, "enable_dht", false) -- offline
   get btSetBool(gLearnBt, "enable_lsd", false)
   put specialFolderPath("temporary") into tDir
   put tDir & "/hello.txt" into tFile
   put "Hello, swarm!" into url ("file:" & tFile)
   put btCreateTorrent(tFile, 0, 0, empty) into tData
   put btAddTorrentFile(gLearnBt, tData, tDir) into tT
   repeat 100 times -- poll: the events since the last
      repeat for each element tE in btPoll(gLearnBt)
         if tE["torrent"] is not tT then next repeat
         if tE["name"] is "stateChanged" then next repeat
         put tE["name"] & cr after tOut
      end repeat
      if tOut contains "Finished" then exit repeat
      wait 20 milliseconds
   end repeat
   btStopSession gLearnBt
   put tOut into field "Result"
end mouseUp
@*/

/*@ Events/expect
^torrentAdded\ntorrentResumed\ntorrentFinished\n$
@*/

/*@ Files/words
A torrent of a folder holds every file in it.

- `btFileList` lists them: each with its "path", "size", "progress" and "priority".
- `btSetFilePriority` sets one, counting files from 0: 0 skips the file, 4 is usual, 7 comes first.

Paths with .pad in them are **padding files**: empty space that lines each file up with a piece. Nothing is saved for them, so skip them.
@*/

/*@ Files/try
on mouseUp
   global gLearnBt
   local tDir, tT, tE, tOut
   if gLearnBt is an integer then btStopSession gLearnBt
   put btStartSession() into gLearnBt
   get btSetBool(gLearnBt, "enable_dht", false) -- offline
   get btSetBool(gLearnBt, "enable_lsd", false)
   put specialFolderPath("temporary") into tDir
   create folder tDir & "/pics"
   put "aaaa" into url ("file:" & tDir & "/pics/a.txt")
   put "bb" into url ("file:" & tDir & "/pics/b.txt")
   -- a folder makes one torrent of all its files
   get btCreateTorrent(tDir & "/pics", 0, 0, empty)
   put btAddTorrentFile(gLearnBt, it, tDir) into tT
   -- priority 0 skips a file (4 is usual, 7 the top)
   get btSetFilePriority(tT, 0, 0) -- the first file
   wait 300 milliseconds
   repeat for each element tE in btFileList(tT)
      if tE["path"] contains ".pad" then next repeat
      put tE["path"] && tE["priority"] & cr after tOut
   end repeat
   btStopSession gLearnBt
   put tOut into field "Result"
end mouseUp
@*/

/*@ Files/expect
^pics[\\/]a\.txt 0\npics[\\/]b\.txt 4\n$
@*/

/*@ Control/words
You decide how each torrent behaves:

- `btPause` stops it and `btResume` starts it again. The status says "isPaused".
- `btSetTorrentLimits` limits its speed, down then up, in bytes a second, as text ("0" for no limit).
- Torrents take turns: `btQueuePosition` is a torrent's place in the queue, and `btQueueUp`, `btQueueDown`, `btQueueTop` and `btQueueBottom` move it.
@*/

/*@ Control/try
on mouseUp
   global gLearnBt
   local tDir, tLink, tT, tE, tOut
   if gLearnBt is an integer then btStopSession gLearnBt
   put btStartSession() into gLearnBt
   get btSetBool(gLearnBt, "enable_dht", false) -- offline
   get btSetBool(gLearnBt, "enable_lsd", false)
   put "magnet:?xt=urn:btih:" & \
         "0123456789abcdef0123456789abcdef01234567" & \
         "&dn=demo" into tLink
   put specialFolderPath("temporary") into tDir
   put btAddMagnet(gLearnBt, tLink, tDir) into tT
   get btPause(tT) -- and btResume goes on again
   wait 100 milliseconds
   put btTorrentStatus(tT) into tE
   put "Paused?" && (tE["isPaused"] is 1) into tOut
   -- bytes a second, as text: down, then up ("0": none)
   get btSetTorrentLimits(tT, "102400", "51200")
   put cr & "Limits:" && it && "(0 is good)" after tOut
   get btQueuePosition(tT) -- they wait their turn
   put cr & "Place in queue:" && it after tOut
   btStopSession gLearnBt
   put tOut into field "Result"
end mouseUp
@*/

/*@ Control/expect
^Paused\? true\nLimits: 0 \(0 is good\)\nPlace in queue: 0$
@*/

/*@ Goodbye/words
When you are done:

- `btRemoveTorrent` takes a torrent out of the session. With true it deletes its files as well; with false it keeps them.
- `btTorrentCount` says how many torrents the session has.
- `btStopSession` stops the session and lets go of everything.

Stop the session before your app quits, for example in closeStack: nothing stops it for you.
@*/

/*@ Goodbye/try
on mouseUp
   global gLearnBt
   local tDir, tFile, tData, tT, tOut
   if gLearnBt is an integer then btStopSession gLearnBt
   put btStartSession() into gLearnBt
   get btSetBool(gLearnBt, "enable_dht", false) -- offline
   get btSetBool(gLearnBt, "enable_lsd", false)
   put specialFolderPath("temporary") into tDir
   put tDir & "/hello.txt" into tFile
   put "Hello, swarm!" into url ("file:" & tFile)
   put btCreateTorrent(tFile, 0, 0, empty) into tData
   put btAddTorrentFile(gLearnBt, tData, tDir) into tT
   put "Torrents:" && btTorrentCount(gLearnBt) into tOut
   -- true: delete its files as well (false keeps them)
   get btRemoveTorrent(gLearnBt, tT, true)
   wait 300 milliseconds
   get btTorrentCount(gLearnBt)
   put cr & "After removing:" && it after tOut
   get there is a file tFile
   put cr & "File still there?" && it after tOut
   -- and stop the session: it lets go of everything
   btStopSession gLearnBt
   put tOut into field "Result"
end mouseUp
@*/

/*@ Goodbye/expect
^Torrents: 1\nAfter removing: 0\nFile still there\? false$
@*/
