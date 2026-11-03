script "OXTExampleLearnOnionXT"
-- OXT-Beyond: builds "Learn OnionXT", six lessons in onionxt, the xTalk
-- Suite's Tor extension (a script library that drives a tor daemon run
-- beside the app) and its onion-httpd library, which OXT-Beyond has built
-- in (https://github.com/SethMorrowSoftware/xtalk-suite, onionxt/).
--
-- It is one of the "Learn" stacks (builder.livecodescript, "Learn stacks"):
-- each lesson says what it shows in plain words, and runs a real script
-- that calls OnionXT, which the user can change, run again and copy; a
-- click on a call opens its page of the reference, and the Reference card
-- has every handler of onionxt and of onion-httpd, from the IDE's
-- Dictionary. The lessons need no tor: they run what works offline (the
-- address checks, the keys inside addresses, an address made from a seed
-- with SodiumXT, which OnionXT uses for SHA3-256 and the key expansion),
-- and show the online calls only up to the checks they make before
-- touching the network, while the words say what follows with tor
-- running. OnionXT's settings (its ports, callback owner and callbacks)
-- are script-locals that every stack in the process shares, and it has
-- no getters to put them back with, so no lesson sets one, and none
-- calls oxShutdown, which would close every other stack's streams and
-- services. test-learn-stacks.livecodescript (in tools/examples) runs
-- every lesson's script on a real engine with OnionXT and SodiumXT
-- loaded and checks its result.

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex, tLessons
   exUseScripts the script of me
   put "Learn OnionXT" into tInfo["name"]
   put "Tor, through onionxt" into tInfo["credit"]
   put "lock" into tInfo["icon"]
   put lkColor("violet") into tInfo["accent"]
   put lkColor("emerald") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn OnionXT|Private connections, through Tor.|lock|front" & return & \
         "Begin|Getting Started|What Tor is, and what works without it.|play|page" & return & \
         "Addresses|Onion Addresses|Check an address before you use it.|hash|page" & return & \
         "Keys|Keys in Addresses|An address is a public key.|key-round|page" & return & \
         "Yours|Your Own Address|The same address, every time.|user|page" & return & \
         "Dialing|Dialing|Reach an address through Tor.|send|page" & return & \
         "Services|Onion Services|Let others reach you.|globe|page" & return & \
         "Reference|Reference|Every OnionXT handler: what it takes and gives back.|book-open|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   exLearnDocs "onionxt,onion-httpd"
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      put exCardInfo(tIndex, "name") & comma after tLessons
   end repeat
   delete the last char of tLessons
   -- (the probe calls both: OnionXT for its version, and SodiumXT,
   -- which the lessons need too, and gives the version when both answer)
   exLearnKit "Start", tLessons, "OnionXT", \
         "the cExtension of this stack && oxVersion() & char 1 to 0 of sxVersion()", \
         "lcb|org.openxtalk.library.sodium|sodiumxt" & return & \
         "lcs|onionxt|onionxt.livecodescript"
   repeat for each item tIndex in tLessons
      if tIndex is not "Reference" then
         exLearnLesson tIndex
      end if
   end repeat
   exLearnReference "Reference"
   exLearnFront "OXT-BEYOND  " & numToCodepoint(183) & "  TOR THROUGH ONIONXT", \
         "Talk without being followed", \
         "Six short lessons in Tor and onion addresses, which hide who talks to whom. " & \
         "Each runs a real script that you can change, run again and copy.", \
         "lightbulb|Each lesson starts in plain words, and needs no Tor to run." & return & \
         "book-open|Click a call to read its parameters, units and result." & return & \
         "info|The lessons change no OnionXT settings: every stack shares them."
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn OnionXT.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

/*@ stack
-- Learn OnionXT: six lessons in onionxt, the xTalk Suite's Tor
-- extension.
-- The lessons are run by the script of the group "Learn", and the window
-- by the script of the group "Frame". It was built by
-- tools/examples/learn-onionxt.livecodescript in the OXT-Beyond repository;
-- build it again rather than change it here.
@*/

/*@ Begin/words
**Tor** hides who talks to whom: a connection hops through three computers, and none knows both ends. **Onion addresses** work only inside Tor.

OnionXT drives a **tor** program running beside your app (Tor Browser has one). These lessons need no Tor.

- `oxVersion` gives OnionXT's version, and Tor's.
- `oxTransportInfo` says which extras work (with SodiumXT).
- `oxIsReady` is true once Tor is running and connected.
@*/

/*@ Begin/try
on mouseUp
   local tInfo, tOut
   -- OnionXT talks to Tor, a program you run beside
   -- your app; on its own it needs no network at all
   put "OnionXT" && oxVersion() into tOut
   -- what works here (true needs SodiumXT loaded)
   put oxTransportInfo() into tInfo
   get tInfo["offlineAddress"]
   put cr & "Addresses offline?" && it after tOut
   get tInfo["deterministicOnion"]
   put cr & "Stable addresses?" && it after tOut
   -- true only once Tor is running and connected
   put cr & "Tor ready?" && oxIsReady() after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Begin/expect
^OnionXT \d+\.\d+\.\d+( \(tor [^)]*\))?\nAddresses offline\? true\nStable addresses\? true\nTor ready\? (true|false)$
@*/

/*@ Addresses/words
An onion address is 56 letters and digits, then .onion. It has no owner to register with: it is made from a **key**.

- `oxIsValidAddress` checks the length, the letters, the version and a built-in **checksum**, so a typo is caught before you try it.

Old 16-letter addresses (version 2) stopped working in 2021, so they are not valid either.
@*/

/*@ Addresses/try
on mouseUp
   local tAddr, tBad, tOut
   -- an onion address: 56 letters and digits, then .onion
   put "duckduckgogg42xjoc72x3sjasow" & \
         "oarfbgcmvfimaftt6twagswzczad.onion" into tAddr
   put "Valid?" && oxIsValidAddress(tAddr) into tOut
   -- change one letter: the built-in check catches it
   put tAddr into tBad
   put "e" into char 1 of tBad
   get oxIsValidAddress(tBad)
   put cr & "One letter changed?" && it after tOut
   -- old short (version 2) addresses are gone
   get oxIsValidAddress("expyuzz4wqqyqhjn.onion")
   put cr & "An old one?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Addresses/expect
^Valid\? true\nOne letter changed\? false\nAn old one\? false$
@*/

/*@ Keys/words
An onion address is a **public key**, 32 bytes, written in **base32** (letters a to z and digits 2 to 7), with a checksum and a version number on the end.

- `oxPublicKeyFromAddress` takes the key out of an address.
- `oxAddressFromPublicKey` turns a key into its address.

Whoever holds the matching **secret key** is the only one who can run that address. That is how Tor knows it reached the right place.
@*/

/*@ Keys/try
on mouseUp
   local tAddr, tKey, tOut
   put "duckduckgogg42xjoc72x3sjasow" & \
         "oarfbgcmvfimaftt6twagswzczad.onion" into tAddr
   -- the address IS a public key, written in base32
   put oxPublicKeyFromAddress(tAddr) into tKey
   get the number of bytes in tKey
   put "Key:" && it && "bytes" into tOut
   put cr & char 1 to 16 of sxBin2Hex(tKey) after tOut
   -- and back: the key gives the same address
   get oxAddressFromPublicKey(tKey) is tAddr
   put cr & "Same address back?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Keys/expect
^Key: 32 bytes\n1d04a1d04a338c6e\nSame address back\? true$
@*/

/*@ Yours/words
Your app can have an address of its own, the same every time it starts. It comes from a **seed**: 32 secret bytes.

- `sxSignKeypairFromSeed` (SodiumXT) makes a key pair from the seed.
- `oxAddressFromPublicKey` turns its public key into the address, without Tor.
- `oxCreateServiceFromSeed` asks Tor to run it.

Keep the seed secret: anyone who has it can run your address.
@*/

/*@ Yours/try
on mouseUp
   local tSeed, tPub, tSec, tAddr, tOut
   -- 32 secret bytes (here made from a phrase; in an
   -- app use sxRandomBytes(32), and keep them safe)
   put textEncode("my seed", "utf-8") into tSeed
   put sxHash(tSeed, 32) into tSeed
   -- it makes a key pair: the public key is the address
   sxSignKeypairFromSeed tSeed, tPub, tSec
   put oxAddressFromPublicKey(tPub) into tAddr
   put char 1 to 28 of tAddr into tOut
   put cr & char 29 to -1 of tAddr after tOut
   put cr & "Valid?" && oxIsValidAddress(tAddr) after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Yours/expect
^cyhitagktc4hrm3w62o62zveuuyr\nuejtwy4m45uaejjdnyogby6dd4ad\.onion\nValid\? true$
@*/

/*@ Dialing/words
To reach an address, **dial** it through Tor.

- `oxDial` takes a host (an onion address, or a normal name) and a port. It gives a **stream** handle at once, or an error for a missing host or a bad port.
- Tor then connects. Your **stream callback** (`oxSetStreamCallback`) hears "open", then "data" as it arrives, or "error".
- `oxWrite` sends; `oxStreamState` says how a stream is; `oxCloseStream` ends it.

Tor must be running (its SOCKS port, `oxSetSocksPort`).
@*/

/*@ Dialing/try
on mouseUp
   local tOut
   -- oxDial gives a stream handle at once; Tor connects
   -- after, and your stream callback hears how it went
   -- (with no host, or a bad port, it refuses at once)
   oxDial "", 80
   get the result begins with "OnionXT:"
   put "No host refused?" && it into tOut
   oxDial "duckduckgogg42xjoc72.onion", 0
   get the result begins with "OnionXT:"
   put cr & "Port 0 refused?" && it after tOut
   -- a handle that was never opened
   put cr & "State:" && oxStreamState(999999) after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Dialing/expect
^No host refused\? true\nPort 0 refused\? true\nState: unknown$
@*/

/*@ Services/words
An **onion service** lets others dial you. Tor publishes your address and forwards each visitor to a port on this computer.

- `oxConnectControl` connects to Tor's **control port** first.
- `oxCreateService` makes a new address each time; `oxCreateServiceFromSeed` keeps one. Each gives a service handle, or an error.
- `oxSetPeerCallback` hears each visitor; `oxRemoveService` stops a service.

`oxShutdown` closes everything, when your app quits.
@*/

/*@ Services/try
on mouseUp
   local tOut
   -- a service is your own address that others dial:
   -- Tor forwards each visitor to a port on this computer
   -- (it needs Tor's control port: oxConnectControl)
   oxCreateService 80, 0 -- a local port of 0 is refused
   get the result begins with "OnionXT:"
   put "Bad port refused?" && it into tOut
   -- from a seed: the same address every time
   oxCreateServiceFromSeed "too short", 80, 8080
   get the result begins with "OnionXT:"
   put cr & "Short seed refused?" && it after tOut
   put tOut into field "Result"
end mouseUp
@*/

/*@ Services/expect
^Bad port refused\? true\nShort seed refused\? true$
@*/
