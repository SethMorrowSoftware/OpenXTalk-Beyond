# xTalk MCP Bridge

The xTalk MCP Bridge lets Claude work on the stacks you have open in
OXT-Beyond, using your own Claude plan (Free, Pro, Max, Team or
Enterprise). You use Claude in Anthropic's own apps, the Claude desktop
app or Claude Code, and sign in there as usual. OXT-Beyond needs no API
key.

It sits beside the xTalk Assistant and changes nothing about it. The
assistant still works with an API key you paste, and you can use either
one, both, or neither.

## Why it works this way

Anthropic does not let other programs sign in to a Claude account or use
a Claude plan's sign-in on someone's behalf. So OXT-Beyond does not talk
to Claude. Claude's app talks to OXT-Beyond instead, through this MCP
server (`server.js`):

    Claude app  --stdio-->  server.js  --127.0.0.1-->  OXT-Beyond

Claude's app starts the server. The server reaches the IDE over a socket
that only this computer can reach, and it must send a key that the IDE
writes to `~/.oxt-beyond/mcp-bridge.json` while the bridge is on. That
file is readable only by you, and it is deleted when the bridge is turned
off.

## Setting it up

1. In OXT-Beyond, choose *Development > Plugins > xTalk MCP Bridge* and
   press **Turn On**.
2. In the window that follows:
   - For the **Claude desktop app**, press **Save Desktop Extension...**,
     then in Claude choose *Settings > Extensions > Advanced settings >
     Install Extension...* and choose the `.mcpb` file it saved (opening
     the file itself works only where the system knows it is Claude's).
     Claude's app runs the server with the Node.js it comes with, so you
     do not need to install anything else. Or press **Add to Claude
     Desktop**, which adds OXT-Beyond to Claude's settings file
     (`claude_desktop_config.json`, keeping a copy of it); that way needs
     Node.js. Quit Claude completely and open it again afterwards.
   - For **Claude Code**, press **Copy Claude Code Command** and paste
     the command into a terminal. This needs Node.js 16 or later.
   - For **another app that runs MCP servers**, press **Other MCP
     Apps...**: **Copy Codex Command** and **Copy Gemini CLI Command**
     give a command for a terminal, and **Copy MCP JSON** gives the
     `mcpServers` entry that Cursor, Windsurf, Cline, Roo Code, LM Studio,
     Continue and others read from their MCP settings file (VS Code's
     `.vscode/mcp.json` names the list `servers`). Each needs Node.js.
3. Ask Claude to work on your stack. OXT-Beyond must be open with the
   bridge on.

## In the web IDE

The bridge works in the web IDE too (the IDE in a browser tab), with
Claude's app on the same computer. A web page cannot listen for a
connection, so it is the other way round from the desktop: Claude's app
starts the same server with `--web`, the server listens on
`ws://127.0.0.1:47861`, and the page connects to it:

    Claude app  --stdio-->  server.js --web  <--WebSocket 127.0.0.1--  web IDE tab

1. In the web IDE, choose *Development > Plugins > xTalk MCP Bridge* and
   press **Connect**. Your browser may ask whether the page may reach
   apps on this device; allow it.
2. In the window that follows:
   - For the **Claude desktop app**, press **Download Desktop
     Extension** and install the file it downloads, as above. It is
     named "OXT-Beyond (web IDE)" (`oxt-beyond-web`), so it sits beside
     the desktop IDE's extension.
   - For **Claude Code**, press **Download Server**, then **Copy Claude
     Code Command**, and paste the command into a terminal. It runs the
     server from your Downloads folder; change the path in it if you
     saved the file somewhere else.
3. Keep Claude's app and the page open, and ask Claude to work on your
   stack. The page connects as soon as Claude's app is there, and again
   at your next visit, until you choose **Disconnect** in the same menu
   item.

The extension and the command carry a key that the page made and keeps
with your preferences (`OXT_MCP_WEB_KEY`), so keep them to yourself. When
the page connects, the server proves that it holds the key before the
page takes any request from it, and the page proves the same back, so a
program that took the port first gets nothing, and neither does a
program posing as the page. Set Claude up again if you use the web IDE
from another browser, since that browser has its own key.

The server also lets only pages from the hosted web IDE
(`https://sethmorrow.com`) and from this computer (`http://localhost` or
`http://127.0.0.1`, as `serve.py` in the downloadable web IDE serves it)
connect; set `OXT_MCP_WEB_ORIGINS` to a comma list of other origins to
let them in too. Only one server holds the port; when Claude's app
starts another (Claude's desktop app starts one for its chats and one
for its Cowork and Code sessions), that one passes its calls to the one
holding the port, after the two prove to each other that they hold the
same key, and takes the port over when the other quits. For
another port than 47861, set the web IDE's `cMcpBridge,webPort`
preference (for example `revIDESetPreference "cMcpBridge,webPort", 47900`
in the Message Box), connect again, and set Claude up again: the setup
gives the server that port (`OXT_MCP_WEB_PORT`). In
the web IDE, code Claude runs stays inside the browser's sandbox, and you
are asked before each run and save as on the desktop. Without `--web`,
the server does exactly what it does for the desktop IDE.

## What Claude can do

Claude can do the same things the xTalk Assistant's tools do:

- **Read and look:** read the guide to xTalk Script, list your open
  stacks, see what you have selected, the script open in the Script
  Editor and the last error the IDE showed you, read a stack's outline
  or its cards and controls (and the sounds and videos it keeps),
  search its scripts, look at a picture of a
  card (with each control's id written on it, if Claude asks), look up
  the Dictionary, check that code compiles, and read a script that is
  paused in the debugger. A long script is read in parts, with line
  numbers and where each handler is.
- **Build:** create, change and delete controls, cards and new stacks,
  and change one handler, or a few lines, of a script while leaving the
  rest of it as it is. Each request is checked first and is made
  completely or not at all.
- **Run and save:** run code in a sandbox or on your stack, and save a
  stack, to its file or, when you tell Claude where, as a new file
  (never over another file), giving a stack never saved its name as it
  is saved. Close a stack when Claude is done with it: one Claude made
  and never saved closes at once, with a copy kept in the temporary
  folder; any other is closed only after you say yes, if it has changes
  it would lose.
- **When OXT-Beyond is held up:** say what a call waits for (a question
  of OXT-Beyond's behind other windows, a script paused in the debugger,
  a dialog open in front of you), stop a paused script as Stop in the
  Script Editor does, and press a button of an `answer` or `ask` dialog
  one of your stacks opened (these two go ahead even while another call
  waits). Claude never answers OXT-Beyond's own
  questions. A client that asks for progress is told every 15 seconds
  what a long call waits for (`OXT_MCP_STATUS_INTERVAL_MS` changes it).
  Claude's apps give up on a call after about a minute, so a call still
  waiting for your answer to OXT-Beyond's question after 40 seconds is
  answered that it waits: your answer still counts, and Claude gets what
  came of it with `pending_result` instead of asking again
  (`OXT_MCP_ANSWER_WAIT_MS` changes the 40 seconds; 0 waits as before).
  A call that simply takes long (a test run, a sweep) is answered the
  same way after those 40 seconds, and goes on: `pending_result` waits
  for it, and a call sent meanwhile is told which call OXT-Beyond is
  still busy with.
- **Long work while you are away:** set a script from a file on your
  computer (`set_script_from_file`, for a script too long to send in a
  call; OXT-Beyond shows you the file's path, size, SHA-256 and text
  first, and it can be undone), wait for a stack to be ready without
  running code (`wait_until`: until a field's text contains or no
  longer contains something, a property is a value, or a stack, card or
  control is there or gone), turn the engine's sounds off for a test run
  and back on (`set_quiet`; put back by itself when the bridge is turned
  off), and quit OXT-Beyond and start it again (`restart_ide`, after you
  say yes; it asks about stacks not saved as Quit does).
- **Import from HyperCard:** a stack's file, or a stack on a Mac disk
  image, imported with messages locked so none of its scripts run.

Claude's app asks you before it uses each tool. OXT-Beyond asks you
itself in these cases:

- before running any code, which it shows you. Code runs inside
  OXT-Beyond with everything the IDE can reach (your files, the network,
  other programs), and no check of its text can see all of what it does,
  so read it before you press **Run**;
- before saving a stack;
- before setting a script from a file, and before restarting OXT-Beyond;
- before undoing something that you have changed since Claude changed it.

Anything else Claude changes or runs on a stack can be undone, either by
Claude with `undo_changes` or by you with **Undo Last Change** under
*Development > Plugins > xTalk MCP Bridge*. This works until the bridge
is turned off.

To keep the bridge off on a computer for good, set the environment
variable `OXTBEYOND_MCP_BRIDGE` to `off`.

## Which server.js runs

A desktop extension holds a copy of `server.js` from the day you saved
it, and Claude's app keeps running that copy after OXT-Beyond is
updated. So each time the bridge is turned on, OXT-Beyond writes where
its own `server.js` is to `~/.oxt-beyond/mcp-bridge-server.json`, and
the copy Claude's app starts serves with that file instead of itself.
While it runs it looks, between calls, whether that file has changed (an
update of OXT-Beyond), loads the new one and tells Claude's app that the
tools changed. Updating OXT-Beyond therefore updates the server, with
nothing to set up again. A file that is missing, half written or cannot
be loaded is left alone, and the copy serves as before. Set
`OXT_MCP_OWN_SERVER` to `1` in the server's environment to make a copy
serve by itself always. The server for the web IDE is one downloaded
file and is never replaced this way.

The server's version (in `manifest.json`, and what it tells Claude's
app) ends with a mark made from its tools, so that an app which keeps
the list of tools by version sees when the list has changed.

With both extensions installed, "OXT-Beyond" and "OXT-Beyond (web IDE)",
Claude sees the same tools twice. The web IDE's server answers for
whichever IDE is there: the web IDE's page when one is connected,
otherwise OXT-Beyond on the desktop when its bridge is on, and it says
which when that changes. Set `OXT_MCP_WEB_ONLY` to `1` to keep it to the
web IDE.

## Tests

- `tests/lcs/mcpbridge/tools.livecodescript` tests the IDE's side.
- `tools/ci/tests/test_mcp_bridge_server.py` tests this server, for
  the desktop IDE and with `--web`.
