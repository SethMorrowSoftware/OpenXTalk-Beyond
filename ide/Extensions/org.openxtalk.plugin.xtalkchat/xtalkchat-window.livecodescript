script "org.openxtalk.plugin.xtalkchat-window"
-- OXT-Beyond: the window of xTalk Chat (the stack "revXTalkChat", which
-- the plugin's main stack makes when the window is first opened, with this
-- stack as its behavior). It draws the window, shows what the chat's core
-- (org.openxtalk.plugin.xtalkchat-core, in use while the window is open)
-- tells it, and hands it what the user does. Here "me" is the window.
--
-- It wears the look of the IDE's learning windows (Learn, the remastered
-- examples, Home), drawn by Learn's kit, revLearnKit, which is this
-- stack's own behavior: a dark sidebar with the mark, the rooms and the
-- private conversations, and at its foot who the user is; a header with
-- the conversation's name and what it is for; the messages on slate; who
-- is online on a white panel at the right; and the box to write in, with
-- Send. Before the user goes online the page is a welcome that says, in
-- plain words, what goes to the relays and who can read it, and asks for a
-- name. Nothing connects until the user presses Go online there; someone
-- who was online when they closed the window goes online again when it
-- next opens, until they go offline. The chat goes offline when the
-- window closes.
--
-- The things that light up and do something are the kit's (lkLive, lkButton,
-- lkNavItem): a click sends "lkAction pAction" here. The messages are one
-- field of htmlText, drawn anew when they change: a name a line, in a
-- colour of its own (from the person's key), the time, and the text, with
-- code between ``` lines in a dark panel with Copy, and links that ask
-- before they open a browser. A click on a name (sLineWho) offers a
-- private message, or muting them.

constant kSide = 248
constant kHeaderHeight = 92
constant kPeopleWidth = 236
constant kWidth = 1120
constant kHeight = 720
constant kMinWidth = 820
constant kMinHeight = 560
constant kComposeMin = 46
constant kComposeMax = 132
constant kTextInset = 4
constant kCore = "org.openxtalk.plugin.xtalkchat-core"
constant kMain = "org.openxtalk.plugin.xtalkchat"
-- The longest a private conversation's list in the sidebar grows
constant kMaxPrivate = 8

-- The conversation in front (a key the core gives: "room:...", "dm:..."),
-- or "welcome"
local sView
-- The window's size, for what moves with it
local sWidth, sHeight
-- The sidebar: the conversation each nav item stands for, the private
-- conversations listed, and the highlight sliding to the one in front
local sNavKey, sPrivateKeys, sNavY, sNavTarget
-- The messages field: the person each line names (a click on a name),
-- each code block's text (Copy), each link's address
local sLineWho, sCode, sLinks
-- The people panel: the person each of its lines names
local sPeopleWho
-- What the user was writing in each conversation, kept when they switch
local sDrafts
-- The toast's time to go, and the height the composer has now
local sToastUntil, sComposeHeight
-- A redraw of the messages, pending
local sRenderDue
-- The window title's count of unread messages, last set
local sTitleCount

################################################################################
#
# Opening and closing
#

on preOpenStack
   xtcwBuild
   xtcwPlace
   pass preOpenStack
end preOpenStack

on openStack
   lkStartTicking
   xtcSetObserver the long id of me
   xtcwShowStart
   pass openStack
end openStack

-- Closing the window goes offline: the others see the user leave
on closeStack
   lkStopTicking
   xtcwSaveDraft
   try
      xtcGoOffline
   catch tError
   end try
   xtcSetObserver empty
   dispatch "xtchWindowClosed" to stack kMain
   pass closeStack
end closeStack

on resizeStack
   if the width of me is sWidth and the height of me is sHeight then
      pass resizeStack
   end if
   xtcwLayout
   if sView is "welcome" then
      xtcwRewelcome
   else
      xtcwRenderMessages
   end if
   pass resizeStack
end resizeStack

-- The welcome laid out again for the window's new width, keeping what the
-- user typed and ticked
private command xtcwRewelcome
   local tName, tClient, tFocus
   if there is not a group "welcome" then
      exit xtcwRewelcome
   end if
   put field "w_name" into tName
   put the hilite of button "w_client" into tClient
   put (the long id of the focusedObject is the long id of field "w_name") into tFocus
   lock screen
   xtcwRenderWelcome
   put tName into field "w_name"
   set the hilite of button "w_client" to tClient
   unlock screen
   if tFocus then
      focus on field "w_name"
   end if
end xtcwRewelcome

-- What the window shows when it opens: the welcome, or, for someone who
-- went online last time and has a name, the chat as it connects
private command xtcwShowStart
   local tAuto
   put xtcwPref("autoOnline") into tAuto
   if xtcHasIdentity() and tAuto is true and xtcMissing() is empty then
      xtcwGoOnline
   else
      xtcwShow "welcome"
   end if
   xtcwSyncMe
end xtcwShowStart

-- In the middle of the screen, below the menu bar, as large as it allows
private command xtcwPlace
   local tScreen, tTop, tWidth, tHeight
   put the screenRect into tScreen
   put item 2 of tScreen + 40 into tTop
   if there is a stack "revMenubar" and the visible of stack "revMenubar" then
      put max(tTop, the bottom of stack "revMenubar" + 44) into tTop
   end if
   put min(kWidth, item 3 of tScreen - item 1 of tScreen - 40) into tWidth
   put min(kHeight, item 4 of tScreen - tTop - 20) into tHeight
   put max(kMinWidth, tWidth) into tWidth
   put max(kMinHeight, tHeight) into tHeight
   if tTop + tHeight > item 4 of tScreen then
      put max(item 2 of tScreen + 31, item 4 of tScreen - tHeight) into tTop
   end if
   set the rect of me to 0, 0, tWidth, tHeight
   set the topLeft of me to max(item 1 of tScreen, (item 1 of tScreen + item 3 of tScreen - tWidth) div 2), tTop
   xtcwLayout
end xtcwPlace

################################################################################
#
# Building the window
#

private command xtcwBuild
   local tSaved
   if there is a group "side" of me then
      exit xtcwBuild
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   set the title of me to "xTalk Chat"
   set the resizable of me to true
   set the minWidth of me to kMinWidth
   set the minHeight of me to kMinHeight
   set the rect of me to 0, 0, kWidth, kHeight
   set the backgroundColor of me to lkColor("bg")
   set the linkColor of me to lkColor("teal")
   set the linkHiliteColor of me to lkMix(lkColor("teal"), lkColor("ink"), 0.3)
   set the linkVisitedColor of me to lkColor("teal")
   put kComposeMin into sComposeHeight
   xtcwBuildSide
   xtcwBuildHeader
   xtcwBuildBody
   xtcwBuildPeople
   xtcwBuildComposer
   xtcwBuildToast
   xtcwBuildMenus
   unlock messages
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end xtcwBuild

private command xtcwBuildSide
   local tObj, tY, tLine, tIndex, tKey, tName
   get lkGroup("side", lkR(0, 0, kSide, kHeight), empty)
   put lkBox("sideBg", lkR(0, 0, kSide, kHeight), lkColor("side"), 0, "side") into tObj
   lkGradient tObj, "15,23,42|17,32,56|14,48,72", "0,0", "0," & kHeight
   -- The mark
   put lkBox("sideMark", "20,22,56,58", lkColor("teal"), 22, "side") into tObj
   lkGradient tObj, "13,148,136|2,132,199", "20,22", "56,58"
   lkGlow tObj, "45,212,191", 16, 110
   get lkIcon("sideMarkIcon", "message-circle", "255,255,255", "28,30,48,50", "side")
   get lkLabel("sideTitle", lkR(66, 21, kSide - 8, 45), "xTalk Chat", 19, "255,255,255", "side")
   get lkLabel("sideSub", lkR(66, 45, kSide - 8, 61), "Talk with xTalk developers", 11, lkColor("muted"), "side")

   -- The highlight under the conversation in front
   put lkBox("navHi", lkR(10, 108, kSide - 10, 140), lkColor("side2"), 16, "side") into tObj
   lkBorder tObj, lkColor("sideLine")
   put lkBox("navBar", "10,115,14,133", lkColor("teal"), 4, "side") into tObj
   hide graphic "navHi"
   hide graphic "navBar"

   -- The rooms
   xtcwCaption "roomsCap", "ROOMS", 86
   put 106 into tY
   put 0 into tIndex
   set the itemDelimiter to tab
   repeat for each line tLine in xtcRooms()
      add 1 to tIndex
      put item 1 of tLine into tKey
      put "nav_room" & tIndex into tName
      lkNavItem tName, tY, 32, xtcwRoomName(item 2 of tLine), "hash", "go" && tKey, 14, kSide - 10
      xtcwBadge tName
      put tKey into sNavKey[tName]
      add 36 to tY
   end repeat
   set the itemDelimiter to comma
   -- The private conversations (xtcwSyncPrivate fills them in)
   add 14 to tY
   xtcwCaption "privCap", "PRIVATE MESSAGES", tY
   get lkLabel("privNone", lkR(24, tY + 22, kSide - 16, tY + 58), "Click a name to write to someone privately.", 12, "100,116,139", "side")
   -- Made once, hidden, and filled in by xtcwSyncPrivate: the kit keeps
   -- what lights up by name until its scope is forgotten, so the items are
   -- kept rather than made anew, and made before the foot's card so that
   -- a long list goes behind it
   add 20 to tY
   repeat with tIndex = 1 to kMaxPrivate
      put "nav_dm" & tIndex into tName
      lkNavItem tName, tY, 32, empty, "user", empty, 14, kSide - 10
      xtcwBadge tName
      hide group tName
      add 36 to tY
   end repeat

   -- Who the user is, at the foot
   get lkGroup("me", lkR(10, kHeight - 70, kSide - 10, kHeight - 12), "side")
   put lkBox("me_bg", lkR(10, kHeight - 70, kSide - 10, kHeight - 12), lkColor("side2"), 16, "me") into tObj
   lkBorder tObj, lkColor("sideLine")
   put lkOval("me_avatar", lkR(22, kHeight - 59, 58, kHeight - 23), lkColor("teal"), "me") into tObj
   put lkLabel("me_initials", lkR(22, kHeight - 51, 58, kHeight - 31), empty, 14, "255,255,255", "me", "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("me_name", lkR(68, kHeight - 60, kSide - 92, kHeight - 42), empty, 14, "255,255,255", "me") into tObj
   set the dontWrap of tObj to true
   put lkOval("me_dot", lkR(68, kHeight - 35, 76, kHeight - 27), lkColor("muted"), "me") into tObj
   put lkLabel("me_status", lkR(81, kHeight - 40, kSide - 92, kHeight - 24), "Offline", 11, lkColor("muted"), "me") into tObj
   set the dontWrap of tObj to true
   xtcwIconButton "me_gear", "settings", "gear", "me"
   xtcwIconButton "me_power", "power", "power", "me"
   set the tooltip of group "me_gear" to "Settings"
   set the tooltip of group "me_power" to "Go online or offline"
end xtcwBuildSide

-- The header's line under the title, kept to one line of what fits
private command xtcwFitTag
   put the cFull of field "hdrTag" into field "hdrTag"
   lkEllipsize the long id of field "hdrTag"
   if the text of field "hdrTag" is not the cFull of field "hdrTag" then
      set the tooltip of field "hdrTag" to the cFull of field "hdrTag"
   else
      set the tooltip of field "hdrTag" to empty
   end if
end xtcwFitTag

-- A round button with only an icon: the kit's dark button, made as wide as
-- it is high (the kit leaves room for a label beside the icon)
private command xtcwIconButton pName, pIcon, pAction, pGroup
   get lkButton(pName, 0, 0, 30, empty, pIcon, "dark", empty, pGroup, pAction, 30)
   set the rect of group pName to 0, 0, 30, 30
   set the rect of graphic (pName & "_bg") to 0, 0, 30, 30
   set the loc of image (pName & "_icon") to 15, 15
   hide field (pName & "_label")
end xtcwIconButton

-- A label's text centred on pMid, whatever the font's height
private command xtcwCenterV pField, pMid
   set the top of field pField to pMid - (the formattedHeight of field pField + 1) div 2
end xtcwCenterV

-- A small caption over a part of the sidebar
private command xtcwCaption pName, pText, pTop
   local tObj
   put lkLabel(pName, lkR(24, pTop, kSide - 16, pTop + 16), pText, 10, "100,116,139", "side") into tObj
   set the textStyle of tObj to "bold"
end xtcwCaption

-- A count of unread messages, at the right of a nav item, hidden at 0
private command xtcwBadge pName
   local tObj, tTop
   put the top of group pName + 8 into tTop
   put lkBox(pName & "_badgeBg", lkR(kSide - 52, tTop, kSide - 22, tTop + 18), lkColor("teal"), 9, pName) into tObj
   put lkLabel(pName & "_badge", lkR(kSide - 52, tTop + 1, kSide - 22, tTop + 17), empty, 10, "255,255,255", pName, "center") into tObj
   set the textStyle of tObj to "bold"
   hide graphic (pName & "_badgeBg")
   hide field (pName & "_badge")
end xtcwBadge

-- "xTalk Lobby" is "Lobby" here: the sidebar says where the user is
function xtcwRoomName pName
   if pName begins with "xTalk " then
      delete char 1 to 6 of pName
   end if
   return pName
end xtcwRoomName

private command xtcwBuildHeader
   local tObj
   get lkGroup("hdr", lkR(kSide, 0, kWidth, kHeaderHeight), empty)
   put lkIcon("hdrIcon", "hash", lkColor("teal"), lkR(kSide + 40, 22, kSide + 64, 46), "hdr") into tObj
   put lkLabel("hdrTitle", lkR(kSide + 74, 16, kWidth - 260, 52), empty, 26, lkColor("ink"), "hdr") into tObj
   set the dontWrap of tObj to true
   put lkLabel("hdrTag", lkR(kSide + 40, 54, kWidth - 260, 72), empty, 13, lkColor("soft"), "hdr") into tObj
   set the dontWrap of tObj to true
   put lkBox("hdrLine", lkR(kSide + 40, 78, kSide + 96, 81), lkColor("teal"), 3, "hdr") into tObj
   -- A private conversation says it is private
   get lkGroup("hdrLock", lkR(kWidth - 260, 26, kWidth - 40, 52), "hdr")
   put lkBox("hdrLock_bg", lkR(kWidth - 260, 26, kWidth - 40, 52), lkMix("255,255,255", lkColor("emerald"), 0.12), 13, "hdrLock") into tObj
   get lkIcon("hdrLock_icon", "lock", lkColor("emerald"), lkR(kWidth - 250, 31, kWidth - 234, 47), "hdrLock")
   put lkLabel("hdrLock_label", lkR(kWidth - 228, 30, kWidth - 44, 48), "End-to-end encrypted", 12, lkMix(lkColor("emerald"), lkColor("ink"), 0.35), "hdrLock") into tObj
   set the dontWrap of tObj to true
   hide group "hdrLock"
end xtcwBuildHeader

private command xtcwBuildBody
   local tObj
   put lkLabel("msgs", lkR(kSide + 24, kHeaderHeight, kWidth - kPeopleWidth - 32, kHeight - 120), empty, 14, lkColor("ink"), empty) into tObj
   set the margins of tObj to "16,6,16,12"
   set the vScrollbar of tObj to true
   set the dontWrap of tObj to false
   set the traversalOn of tObj to false
   lkScroller "msgsThumb", the long id of field "msgs", "100,116,139", 45, empty
   put lkLabel("msgsEmpty", lkR(kSide + 24, 300, kWidth - kPeopleWidth - 32, 360), empty, 14, lkColor("muted"), empty, "center") into tObj
   hide tObj
end xtcwBuildBody

private command xtcwBuildPeople
   local tObj
   get lkGroup("ppl", lkR(kWidth - kPeopleWidth - 16, kHeaderHeight + 4, kWidth - 16, kHeight - 16), empty)
   put lkBox("ppl_bg", lkR(kWidth - kPeopleWidth - 16, kHeaderHeight + 4, kWidth - 16, kHeight - 16), lkColor("panel"), 18, "ppl") into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 18, 4, 18
   get lkIcon("ppl_icon", "users", lkColor("teal"), lkR(0, 0, 18, 18), "ppl")
   put lkLabel("ppl_title", lkR(0, 0, 160, 20), "Online now", 15, lkColor("ink"), "ppl") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   put lkBox("ppl_countBg", lkR(0, 0, 30, 20), lkMix("255,255,255", lkColor("teal"), 0.14), 10, "ppl") into tObj
   put lkLabel("ppl_count", lkR(0, 0, 30, 18), "0", 11, lkMix(lkColor("teal"), lkColor("ink"), 0.3), "ppl", "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("ppl_list", lkR(0, 0, 200, 300), empty, 13, lkColor("ink"), "ppl") into tObj
   set the dontWrap of tObj to true
   set the margins of tObj to "4,4,4,4"
   set the vScrollbar of tObj to true
   lkScroller "pplThumb", the long id of field "ppl_list", "148,163,184", 50, empty
   put lkLabel("ppl_note", lkR(0, 0, 200, 60), empty, 12, lkColor("muted"), "ppl") into tObj
end xtcwBuildPeople

private command xtcwBuildComposer
   local tObj
   get lkGroup("cmp", lkR(kSide + 40, kHeight - 80, kWidth - kPeopleWidth - 48, kHeight - 34), empty)
   put lkBox("cmp_bg", lkR(kSide + 40, kHeight - 80, kWidth - kPeopleWidth - 48, kHeight - 34), lkColor("panel"), 16, "cmp") into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 14, 3, 14
   put lkLabel("cmp_hint", lkR(0, 0, 100, 20), empty, 14, lkColor("muted"), "cmp") into tObj
   set the dontWrap of tObj to true
   put lkInput("compose", lkR(0, 0, 100, 20), empty, 14, "cmp") into tObj
   set the dontWrap of tObj to false
   set the vScrollbar of tObj to false
   set the hiliteColor of tObj to lkMix("255,255,255", lkColor("teal"), 0.25)
   get lkButton("cmp_send", 0, 0, 34, "Send", "send", "primary", lkColor("teal"), "cmp", "send", 92)
   put lkLabel("cmp_keys", lkR(0, 0, 100, 16), "Return sends, Shift-Return starts a new line. Put code between lines of three backticks (```).", 11, lkColor("muted"), empty) into tObj
   set the dontWrap of tObj to true
end xtcwBuildComposer

-- A dark pill at the foot of the window, for a word on what just happened
private command xtcwBuildToast
   local tObj
   get lkGroup("toast", lkR(0, 0, 400, 40), empty)
   put lkBox("toast_bg", lkR(0, 0, 400, 40), lkColor("side"), 20, "toast") into tObj
   lkShadow tObj, 18, 6, 40
   get lkIcon("toast_icon", "check", lkColor("emerald"), "16,12,32,28", "toast")
   put lkLabel("toast_label", "42,11,390,29", empty, 13, "255,255,255", "toast") into tObj
   set the dontWrap of tObj to true
   hide group "toast"
end xtcwBuildToast

-- The menus a click on a name, and the settings button, pop up
private command xtcwBuildMenus
   create button "whoMenu"
   set the style of button "whoMenu" to "menu"
   set the menuMode of button "whoMenu" to "popup"
   set the visible of button "whoMenu" to false
   create button "gearMenu"
   set the style of button "gearMenu" to "menu"
   set the menuMode of button "gearMenu" to "popup"
   set the visible of button "gearMenu" to false
end xtcwBuildMenus

################################################################################
#
# Layout
#

-- Places what moves with the window's size
private command xtcwLayout
   local tW, tH, tSaved, tRight, tPeople, tTop
   put the width of me into tW
   put the height of me into tH
   put tW into sWidth
   put tH into sHeight
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   -- The sidebar
   set the rect of group "side" to 0, 0, kSide, tH
   set the rect of graphic "sideBg" to 0, 0, kSide, tH
   lkGradientPoints the long id of graphic "sideBg", "0,0", "0," & tH
   xtcwPlaceMe tH
   -- The people panel, on a window wide enough for it
   put tW >= 940 and sView is not "welcome" into tPeople
   if tPeople then
      put tW - kPeopleWidth - 16 into tRight
      xtcwPlacePeople tRight, kHeaderHeight + 4, tW - 16, tH - 16
      show group "ppl"
   else
      put tW into tRight
      hide group "ppl"
   end if
   -- The header
   set the rect of group "hdr" to kSide, 0, tRight, kHeaderHeight
   set the rect of field "hdrTitle" to kSide + 74, the top of field "hdrTitle", tRight - 230, the bottom of field "hdrTitle"
   set the rect of field "hdrTag" to kSide + 40, the top of field "hdrTag", tRight - 24, the bottom of field "hdrTag"
   xtcwFitTag
   xtcwPlaceLock tRight - 24
   -- The composer and the messages above it
   put tH - 32 - sComposeHeight into tTop
   xtcwPlaceComposer kSide + 40, tTop, tRight - 24, tH - 32
   set the rect of field "cmp_keys" to kSide + 44, tH - 26 - kTextInset, tRight - 24, tH - 4
   set the rect of field "msgs" to kSide + 24, kHeaderHeight + 4, tRight - 8, tTop - 10
   set the rect of field "msgsEmpty" to kSide + 24, (kHeaderHeight + tTop) div 2 - 30, tRight - 8, (kHeaderHeight + tTop) div 2 + 30
   lkScrollSync "msgsThumb"
   if there is a group "welcome" then
      set the rect of group "welcome" to kSide, 0, tW, tH
   end if
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end xtcwLayout

private command xtcwPlaceMe pH
   local tTop
   put pH - 70 into tTop
   set the rect of group "me" to 10, tTop, kSide - 10, pH - 12
   set the rect of graphic "me_bg" to 10, tTop, kSide - 10, pH - 12
   set the rect of graphic "me_avatar" to 22, tTop + 11, 58, tTop + 47
   set the rect of field "me_initials" to 22, tTop + 29 - (the formattedHeight of field "me_initials" + kTextInset) div 2, 58, tTop + 47
   set the rect of field "me_name" to 68, tTop + 10 - kTextInset, kSide - 92, tTop + 30
   set the rect of graphic "me_dot" to 68, tTop + 37, 76, tTop + 45
   set the rect of field "me_status" to 81, tTop + 33 - kTextInset, kSide - 92, tTop + 49
   set the topLeft of group "me_gear" to kSide - 86, tTop + 14
   lkRestAt "me_gear"
   set the topLeft of group "me_power" to kSide - 52, tTop + 14
   lkRestAt "me_power"
end xtcwPlaceMe

private command xtcwPlacePeople pLeft, pTop, pRight, pBottom
   set the rect of group "ppl" to pLeft - 20, pTop - 10, pRight + 20, pBottom + 30
   set the rect of graphic "ppl_bg" to pLeft, pTop, pRight, pBottom
   set the rect of image "ppl_icon" to pLeft + 18, pTop + 20, pLeft + 36, pTop + 38
   set the rect of field "ppl_title" to pLeft + 44, pTop + 18 - kTextInset, pRight - 50, pTop + 40
   set the width of field "ppl_title" to the formattedWidth of field "ppl_title" + 6
   set the left of field "ppl_title" to pLeft + 44
   xtcwCenterV "ppl_title", pTop + 29
   set the rect of graphic "ppl_countBg" to the right of field "ppl_title" + 4, pTop + 19, the right of field "ppl_title" + 4 + max(26, the formattedWidth of field "ppl_count" + 14), pTop + 39
   set the rect of field "ppl_count" to the left of graphic "ppl_countBg", pTop + 20 - kTextInset + 1, the right of graphic "ppl_countBg", pTop + 38
   xtcwCenterV "ppl_count", pTop + 29
   set the rect of field "ppl_list" to pLeft + 10, pTop + 52, pRight - 10, pBottom - 12
   set the rect of field "ppl_note" to pLeft + 18, pTop + 52, pRight - 18, pTop + 140
   lkScrollSync "pplThumb"
end xtcwPlacePeople

private command xtcwPlaceLock pRight
   local tWidth
   put the formattedWidth of field "hdrLock_label" + 46 into tWidth
   set the rect of group "hdrLock" to pRight - tWidth, 30, pRight, 56
   set the rect of graphic "hdrLock_bg" to pRight - tWidth, 30, pRight, 56
   set the rect of image "hdrLock_icon" to pRight - tWidth + 12, 35, pRight - tWidth + 28, 51
   set the rect of field "hdrLock_label" to pRight - tWidth + 34, 34 - kTextInset + 1, pRight - 6, 54
   xtcwCenterV "hdrLock_label", 43
end xtcwPlaceLock

private command xtcwPlaceComposer pLeft, pTop, pRight, pBottom
   local tSendWidth, tMid
   set the rect of group "cmp" to pLeft - 20, pTop - 10, pRight + 20, pBottom + 30
   set the rect of graphic "cmp_bg" to pLeft, pTop, pRight, pBottom
   put the width of group "cmp_send" into tSendWidth
   -- (in the middle of a box of one or two lines, at the foot of a taller one)
   if pBottom - pTop <= 64 then
      set the topLeft of group "cmp_send" to pRight - tSendWidth - 6, pTop + (pBottom - pTop - 34) div 2
   else
      set the topLeft of group "cmp_send" to pRight - tSendWidth - 6, pBottom - 40
   end if
   lkRestAt "cmp_send"
   set the rect of field "compose" to pLeft + 14, pTop + 11, pRight - tSendWidth - 16, pBottom - 8
   set the rect of field "cmp_hint" to pLeft + 18, pTop + 11, pRight - tSendWidth - 16, pTop + 33
end xtcwPlaceComposer

################################################################################
#
# What the core tells
#

on xtalkChatChanged pWhat, pKey
   local tSaved
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   switch pWhat
      case "status"
         xtcwSyncMe
         if sView is not "welcome" then
            xtcwSyncPeople
         end if
         break
      case "people"
         xtcwSyncPeople
         xtcwSyncPrivate
         -- (a name learned changes the messages' names too)
         xtcwRenderSoon
         break
      case "messages"
         if pKey is empty or pKey is sView then
            xtcwRenderSoon
         end if
         if pKey begins with "dm:" and pKey is not among the lines of sPrivateKeys then
            xtcwSyncPrivate
         end if
         xtcwSyncBadges
         break
      case "notice"
         xtcwToast pKey, "bad"
         break
   end switch
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end xtalkChatChanged

-- Messages come in bursts (a relay's history): drawn once for a burst
private command xtcwRenderSoon
   if sRenderDue is not empty then
      exit xtcwRenderSoon
   end if
   send "xtcwRenderDue" to me in 80 milliseconds
   put the result into sRenderDue
end xtcwRenderSoon

on xtcwRenderDue
   local tSaved
   put empty into sRenderDue
   if the mode of me is 0 then
      exit xtcwRenderDue
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   xtcwRenderMessages
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end xtcwRenderDue

-- Who the user is, and whether online, at the foot of the sidebar
private command xtcwSyncMe
   local tName, tOnline, tOpen, tCount, tStatus, tColor
   put xtcMyName() into tName
   if tName is empty then
      put "Not set up yet" into tName
   end if
   put tName into field "me_name"
   lkEllipsize the long id of field "me_name"
   put xtcwInitials(xtcMyName()) into field "me_initials"
   if xtcHasIdentity() then
      set the backgroundColor of graphic "me_avatar" to xtcwPersonColor(xtcMyKey())
   end if
   put xtcIsOnline() into tOnline
   put xtcOpenRelayCount() into tOpen
   put the number of lines of xtcRelayStatus() into tCount
   if not tOnline then
      put "Offline" into tStatus
      put lkColor("muted") into tColor
   else if tOpen is 0 then
      put "Connecting..." into tStatus
      put lkColor("amber") into tColor
   else
      put "Online" into tStatus
      put lkMix(lkColor("emerald"), "255,255,255", 0.2) into tColor
   end if
   put tStatus into field "me_status"
   if tOnline then
      set the tooltip of field "me_status" to "Connected to" && tOpen && "of" && tCount && "relays"
   else
      set the tooltip of field "me_status" to empty
   end if
   set the backgroundColor of graphic "me_dot" to tColor
   if tOnline then
      lkIconInk the long id of image "me_power_icon", "power", lkMix(lkColor("emerald"), "255,255,255", 0.3)
      set the tooltip of group "me_power" to "Go offline"
   else
      lkIconInk the long id of image "me_power_icon", "power", lkColor("sideInk")
      set the tooltip of group "me_power" to "Go online"
   end if
end xtcwSyncMe

-- Up to two letters for an avatar
function xtcwInitials pName
   local tOut
   if pName is empty then
      return "?"
   end if
   put toUpper(char 1 of word 1 of pName) into tOut
   if the number of words of pName > 1 then
      put toUpper(char 1 of word 2 of pName) after tOut
   end if
   return tOut
end xtcwInitials

-- Each person's colour, from their key: the same on every computer
function xtcwPersonColor pPk
   local tHue
   if pPk is empty then
      return lkColor("muted")
   end if
   put baseConvert(char 1 to 4 of pPk, 16, 10) mod 360 into tHue
   return lkHue(tHue, 0.62, 0.42)
end xtcwPersonColor

-- The people online, in the panel
private command xtcwSyncPeople
   local tList, tLine, tHtml, tCount, tRow, tIndex
   set the itemDelimiter to tab
   put xtcPeopleOnline() into tList
   put 0 into tCount
   put 0 into tRow
   put empty into sPeopleWho
   if xtcIsOnline() then
      -- The user first, as "you"
      put xtcwPersonLine(xtcMyKey(), xtcMyName(), xtcClientOf(xtcMyKey())) after tHtml
      add 1 to tCount
      put the number of lines of xtcClientOf(xtcMyKey()) + 1 + tRow into tRow
      repeat for each line tLine in tList
         if tLine is empty then
            next repeat
         end if
         add 1 to tCount
         put xtcwPersonLine(item 1 of tLine, item 2 of tLine, item 3 of tLine) after tHtml
         put item 1 of tLine into sPeopleWho[tRow + 1]
         if item 3 of tLine is not empty then
            put item 1 of tLine into sPeopleWho[tRow + 2]
            add 2 to tRow
         else
            add 1 to tRow
         end if
      end repeat
   end if
   set the itemDelimiter to comma
   set the htmlText of field "ppl_list" to tHtml
   put tCount into field "ppl_count"
   if not xtcIsOnline() then
      put "Go online to see who is here." into field "ppl_note"
      show field "ppl_note"
   else if tCount <= 1 then
      put "No one else is online right now. Rooms keep their messages, so what you write is read later." into field "ppl_note"
      set the top of field "ppl_note" to the top of field "ppl_list" + 52
      show field "ppl_note"
   else
      hide field "ppl_note"
   end if
   if the visible of group "ppl" then
      xtcwPlacePeople the left of graphic "ppl_bg", the top of graphic "ppl_bg", the right of graphic "ppl_bg", the bottom of graphic "ppl_bg"
      if tCount <= 1 and xtcIsOnline() then
         set the top of field "ppl_note" to the top of field "ppl_list" + 50
      end if
   end if
end xtcwSyncPeople

-- One person in the panel: a dot in their colour, the name, and under it
-- the IDE they use when they show it. One or two lines, each of which
-- names them for a click (sPeopleWho; not a link, which the engine would
-- underline: whether links are underlined is a global property, the
-- IDE's and the user's, not this window's).
private function xtcwPersonLine pPk, pName, pClient
   local tOut
   put "<p spaceabove=" & quote & "6" & quote & "><font color=" & quote & lkHex(xtcwPersonColor(pPk)) & quote & ">" & numToCodepoint(9679) & "</font> " into tOut
   if pPk is xtcMyKey() then
      put "<font color=" & quote & lkHex(lkColor("ink")) & quote & ">" & lkEscape(pName) & "</font>" & \
            "<font color=" & quote & lkHex(lkColor("muted")) & quote & "> (you)</font></p>" after tOut
   else
      put "<font color=" & quote & lkHex(lkColor("ink")) & quote & ">" & lkEscape(pName) & "</font></p>" after tOut
   end if
   if pClient is not empty then
      put "<p leftindent=" & quote & "16" & quote & "><font size=" & quote & "11" & quote & " color=" & quote & lkHex(lkColor("muted")) & quote & ">" & lkEscape(pClient) & "</font></p>" after tOut
   end if
   return tOut
end xtcwPersonLine

-- The private conversations in the sidebar, the newest first
private command xtcwSyncPrivate
   local tList, tLine, tKey, tIndex, tName, tKeys
   put xtcPrivateConversations() into tList
   set the itemDelimiter to tab
   repeat for each line tLine in tList
      if tLine is not empty then
         put item 1 of tLine & return after tKeys
      end if
   end repeat
   set the itemDelimiter to comma
   delete the last char of tKeys
   -- (the one in front stays listed, even before a message is in it)
   if sView begins with "dm:" and sView is not among the lines of tKeys then
      if tKeys is empty then
         put sView into tKeys
      else
         put sView & return before tKeys
      end if
   end if
   if the number of lines of tKeys > kMaxPrivate then
      put line 1 to kMaxPrivate of tKeys into tKeys
   end if
   lock screen
   put 0 into tIndex
   repeat for each line tKey in tKeys
      add 1 to tIndex
      put "nav_dm" & tIndex into tName
      put xtcName(char 4 to -1 of tKey) into field (tName & "_label")
      lkSetLook tName, "action", "go" && tKey
      put tKey into sNavKey[tName]
      show group tName
   end repeat
   repeat with tIndex = tIndex + 1 to kMaxPrivate
      put "nav_dm" & tIndex into tName
      delete variable sNavKey[tName]
      lkSetLook tName, "action", empty
      hide group tName
   end repeat
   put tKeys into sPrivateKeys
   if tKeys is empty then
      show field "privNone"
   else
      hide field "privNone"
   end if
   unlock screen
   xtcwSyncNav
   xtcwSyncBadges
end xtcwSyncPrivate

-- The unread counts on the sidebar, and in the window's title
private command xtcwSyncBadges
   local tName, tCount, tTotal
   put 0 into tTotal
   repeat for each key tName in sNavKey
      if there is not a group tName then
         next repeat
      end if
      put xtcUnread(sNavKey[tName]) into tCount
      if sNavKey[tName] is sView then
         put 0 into tCount
      end if
      add tCount to tTotal
      if tCount > 0 then
         if tCount > 99 then
            put "99+" into field (tName & "_badge")
         else
            put tCount into field (tName & "_badge")
         end if
         set the rect of graphic (tName & "_badgeBg") to kSide - 22 - max(22, the formattedWidth of field (tName & "_badge") + 12), the top of group tName + 7, kSide - 22, the top of group tName + 25
         set the rect of field (tName & "_badge") to the left of graphic (tName & "_badgeBg"), the top of group tName + 8 - kTextInset + 1, kSide - 22, the top of group tName + 24
         xtcwCenterV tName & "_badge", the top of group tName + 16
         show graphic (tName & "_badgeBg")
         show field (tName & "_badge")
      else
         hide graphic (tName & "_badgeBg")
         hide field (tName & "_badge")
      end if
   end repeat
   if tTotal is not sTitleCount then
      put tTotal into sTitleCount
      if tTotal > 0 then
         set the title of me to "xTalk Chat (" & tTotal & ")"
      else
         set the title of me to "xTalk Chat"
      end if
   end if
end xtcwSyncBadges

-- The nav item of the conversation in front is lit, and the highlight
-- slides to it
private command xtcwSyncNav
   local tName, tFound
   repeat for each key tName in sNavKey
      if there is not a group tName then
         next repeat
      end if
      if sNavKey[tName] is sView then
         lkSetLook tName, "ink0", "255,255,255"
         lkIconInk the long id of image (tName & "_icon"), xtcwNavIcon(tName), lkMix(lkColor("teal"), "255,255,255", 0.35)
         put the top of group tName into sNavTarget
         put true into tFound
      else
         lkSetLook tName, "ink0", lkColor("sideInk")
         lkIconInk the long id of image (tName & "_icon"), xtcwNavIcon(tName), lkColor("sideInk")
      end if
   end repeat
   if tFound is true then
      if not the visible of graphic "navHi" then
         put sNavTarget into sNavY
         set the top of graphic "navHi" to sNavY
         set the top of graphic "navBar" to sNavY + 7
         show graphic "navHi"
         show graphic "navBar"
         lkGlow the long id of graphic "navBar", lkColor("teal"), 10, 160
      end if
   else
      hide graphic "navHi"
      hide graphic "navBar"
      put empty into sNavTarget
   end if
end xtcwSyncNav

private function xtcwNavIcon pName
   if pName begins with "nav_dm" then
      return "user"
   end if
   return "hash"
end xtcwNavIcon

################################################################################
#
# Going online
#

-- Goes online with the name in the welcome (or the one kept). Makes the
-- identity the first time.
command xtcwGoOnline
   local tName, tMissing, tResult, tFirst
   put xtcMissing() into tMissing
   if tMissing is not empty then
      xtcwShow "welcome"
      xtcwToast tMissing, "bad"
      exit xtcwGoOnline
   end if
   if there is a field "w_name" then
      put word 1 to -1 of field "w_name" into tName
   end if
   if not xtcHasIdentity() then
      if not xtcIdentityLoad() then
         if tName is empty then
            xtcwToast "Type the name others will see first.", "warn"
            if there is a field "w_name" then
               focus on field "w_name"
            end if
            exit xtcwGoOnline
         end if
         xtcIdentityCreate tName, empty
         if the result is not empty then
            xtcwToast the result, "bad"
            exit xtcwGoOnline
         end if
         put true into tFirst
      end if
   end if
   if tName is not empty and tName is not xtcMyName() then
      xtcSetName tName
   end if
   if there is a button "w_client" then
      xtcwSetPref "showClient", the hilite of button "w_client"
   end if
   xtcSetShowClient xtcwPref("showClient") is not false
   xtcSetMuted xtcwPref("muted")
   xtcGoOnline xtcwPref("relays")
   put the result into tResult
   if tResult is not empty then
      xtcwToast tResult, "bad"
      exit xtcwGoOnline
   end if
   xtcwSetPref "autoOnline", true
   xtcwShow xtcwFirstRoom()
   xtcwSyncMe
   xtcwSyncPeople
   if tFirst is true then
      xtcwToast "You are online. Say hello!", "ok"
   end if
end xtcwGoOnline

command xtcwGoOffline
   xtcwSaveDraft
   xtcGoOffline
   xtcwSetPref "autoOnline", false
   xtcwShow "welcome"
   xtcwSyncMe
end xtcwGoOffline

private function xtcwFirstRoom
   local tLast
   put xtcwPref("lastView") into tLast
   if tLast begins with "room:" then
      set the itemDelimiter to tab
      if tLast is among the items of xtcwRoomKeys() then
         return tLast
      end if
   end if
   set the itemDelimiter to tab
   return item 1 of line 1 of xtcRooms()
end xtcwFirstRoom

private function xtcwRoomKeys
   local tOut, tLine
   set the itemDelimiter to tab
   repeat for each line tLine in xtcRooms()
      put item 1 of tLine & tab after tOut
   end repeat
   delete the last char of tOut
   return tOut
end xtcwRoomKeys

################################################################################
#
# Showing a conversation
#

-- Shows pKey ("welcome", "room:...", "dm:...")
command xtcwShow pKey
   local tSaved, tLine, tTitle, tTag, tPk
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   xtcwSaveDraft
   if pKey is not "welcome" and not xtcIsOnline() then
      put "welcome" into pKey
   end if
   put pKey into sView
   xtcLookAt pKey
   if pKey is "welcome" then
      xtcwRenderWelcome
      hide group "hdr"
      hide field "msgs"
      hide graphic "msgsThumb"
      hide field "msgsEmpty"
      hide group "cmp"
      hide field "cmp_keys"
      hide group "ppl"
   else
      if there is a group "welcome" then
         lkForget "welcome"
         delete group "welcome"
      end if
      xtcwSetPref "lastView", pKey
      show group "hdr"
      show field "msgs"
      show group "cmp"
      show field "cmp_keys"
      if pKey begins with "room:" then
         set the itemDelimiter to tab
         repeat for each line tLine in xtcRooms()
            if item 1 of tLine is pKey then
               put xtcwRoomName(item 2 of tLine) into tTitle
               put item 3 of tLine into tTag
            end if
         end repeat
         set the itemDelimiter to comma
         lkIconInk the long id of image "hdrIcon", "hash", lkColor("teal")
         hide group "hdrLock"
         put "Message the" && tTitle && "room" into field "cmp_hint"
      else
         put char 4 to -1 of pKey into tPk
         put xtcName(tPk) into tTitle
         if xtcIsPersonOnline(tPk) then
            put "Online now." into tTag
         else
            put "Not online now: they will see your message when they come." into tTag
         end if
         put space & "Only the two of you can read this conversation." after tTag
         lkIconInk the long id of image "hdrIcon", "user", lkColor("teal")
         show group "hdrLock"
         put "Message" && tTitle && "privately" into field "cmp_hint"
         xtcwSyncPrivate
      end if
      put tTitle into field "hdrTitle"
      set the cFull of field "hdrTag" to tTag
      xtcwFitTag
      xtcwFitTitle
      put sDrafts[pKey] into field "compose"
      xtcwComposeChanged
      xtcwRenderMessages true
   end if
   xtcwLayout
   xtcwSyncNav
   xtcwSyncBadges
   unlock screen
   if pKey is not "welcome" then
      focus on field "compose"
   end if
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end xtcwShow

-- A long title is set smaller, to stay on one line
private command xtcwFitTitle
   local tSize
   put 26 into tSize
   set the textSize of field "hdrTitle" to tSize
   repeat while tSize > 17 and the formattedWidth of field "hdrTitle" > the width of field "hdrTitle"
      subtract 2 from tSize
      set the textSize of field "hdrTitle" to tSize
   end repeat
end xtcwFitTitle

private command xtcwSaveDraft
   if sView is empty or sView is "welcome" or there is not a field "compose" then
      exit xtcwSaveDraft
   end if
   put field "compose" into sDrafts[sView]
end xtcwSaveDraft

################################################################################
#
# The messages
#

-- Draws the messages of the conversation in front. The view stays at the
-- newest message when it was there (or pToEnd), and where it was if the
-- user had scrolled up to read.
command xtcwRenderMessages pToEnd
   local tMsgs, tCount, tIndex, tMsg, tHtml, tLast, tLastDay, tDay, tAtEnd, tRoom, tLine
   if sView is empty or sView is "welcome" or there is not a field "msgs" then
      exit xtcwRenderMessages
   end if
   put the vScroll of field "msgs" >= the formattedHeight of field "msgs" - the height of field "msgs" - 40 into tAtEnd
   put xtcMessages(sView) into tMsgs
   put the number of elements of tMsgs into tCount
   put empty into sLineWho
   put empty into sCode
   put empty into sLinks
   put 0 into tLine
   repeat with tIndex = 1 to tCount
      put tMsgs[tIndex] into tMsg
      put xtcwDayName(tMsg["at"]) into tDay
      if tDay is not tLastDay then
         put "<p align=" & quote & "center" & quote & " spaceabove=" & quote & "14" & quote & " spacebelow=" & quote & "4" & quote & "><font size=" & quote & "11" & quote & " color=" & quote & lkHex(lkColor("muted")) & quote & "><b>" & toUpper(tDay) & "</b></font></p>" after tHtml
         add 1 to tLine
         put tDay into tLastDay
         put empty into tLast
      end if
      -- A name line when the writer changes, or five minutes passed
      if tLast is empty or tLast["pk"] is not tMsg["pk"] or tMsg["at"] - tLast["at"] > 300 then
         put xtcwNameLine(tMsg) after tHtml
         add 1 to tLine
         put tMsg["pk"] into sLineWho[tLine]
      end if
      get xtcwBodyHtml(tMsg, tLine)
      put it after tHtml
      add xtcwParaCount(it) to tLine
      put tMsg into tLast
   end repeat
   lock screen
   set the htmlText of field "msgs" to tHtml
   if tCount is 0 then
      if xtcOpenRelayCount() is 0 then
         put "Connecting to the relays..." into field "msgsEmpty"
      else if sView begins with "dm:" then
         put "No messages yet. What you write here is encrypted for the two of you." into field "msgsEmpty"
      else
         put "No messages yet. Say hello!" into field "msgsEmpty"
      end if
      show field "msgsEmpty"
   else
      hide field "msgsEmpty"
   end if
   if pToEnd is true or tAtEnd then
      set the vScroll of field "msgs" to the formattedHeight of field "msgs"
   end if
   lkScrollSync "msgsThumb"
   unlock screen
end xtcwRenderMessages

-- How many paragraphs (lines of the field) htmlText makes
private function xtcwParaCount pHtml
   local tLength
   put the number of chars of pHtml into tLength
   replace "</p>" with empty in pHtml
   return (tLength - the number of chars of pHtml) div 4
end xtcwParaCount

-- "Today", "Yesterday" or the date
private function xtcwDayName pAt
   local tDate, tToday, tYesterday
   put pAt into tDate
   convert tDate from seconds to dateItems
   put the seconds into tToday
   convert tToday to dateItems
   put the seconds - 86400 into tYesterday
   convert tYesterday to dateItems
   if item 1 to 3 of tDate is item 1 to 3 of tToday then
      return "Today"
   end if
   if item 1 to 3 of tDate is item 1 to 3 of tYesterday then
      return "Yesterday"
   end if
   put pAt into tDate
   convert tDate from seconds to long date
   return tDate
end xtcwDayName

private function xtcwTime pAt
   local tTime
   put pAt into tTime
   convert tTime from seconds to short time
   return tTime
end xtcwTime

private function xtcwNameLine pMsg
   local tOut, tName
   put xtcName(pMsg["pk"]) into tName
   put "<p spaceabove=" & quote & "12" & quote & ">" into tOut
   put "<font color=" & quote & lkHex(xtcwPersonColor(pMsg["pk"])) & quote & "><b>" & lkEscape(tName) & "</b></font>" after tOut
   if pMsg["pk"] is not xtcMyKey() and xtcwNameIsShared(pMsg["pk"], tName) then
      put "<font size=" & quote & "11" & quote & " color=" & quote & lkHex(lkColor("muted")) & quote & ">  " & lkEscape(xtcShortKey(pMsg["pk"])) & "</font>" after tOut
   end if
   put "<font size=" & quote & "11" & quote & " color=" & quote & lkHex(lkColor("muted")) & quote & ">   " & xtcwTime(pMsg["at"]) & "</font></p>" after tOut
   return tOut
end xtcwNameLine

-- A name someone else uses too, or that looks like a key: the start of
-- the key goes with it, so that no one passes for someone else
private function xtcwNameIsShared pPk, pName
   return pName begins with "npub..." or pName is xtcMyName()
end xtcwNameIsShared

-- A message's text as paragraphs: plain lines, with links; code between
-- ``` lines in a dark panel, coloured, with Copy
private function xtcwBodyHtml pMsg, pLineBefore
   local tOut, tLine, tInCode, tCode, tLines, tColor, tIndex, tCodeIndex
   put 0 into tLines
   switch pMsg["state"]
      case "pending"
         put lkHex(lkColor("muted")) into tColor
         break
      case "failed"
         put lkHex(lkColor("rose")) into tColor
         break
      default
         put lkHex(lkColor("ink")) into tColor
   end switch
   put false into tInCode
   repeat for each line tLine in pMsg["text"]
      if word 1 of tLine begins with "```" and the number of words of tLine <= 1 then
         if tInCode then
            put xtcwCodeHtml(tCode, pLineBefore + tLines) after tOut
            add the result to tLines
            put empty into tCode
            put false into tInCode
         else
            put true into tInCode
            put empty into tCode
         end if
         next repeat
      end if
      if tInCode then
         put tLine & return after tCode
      else
         put "<p><font color=" & quote & tColor & quote & ">" & xtcwInlineHtml(tLine) & "</font></p>" after tOut
         add 1 to tLines
      end if
   end repeat
   if tInCode and tCode is not empty then
      put xtcwCodeHtml(tCode, pLineBefore + tLines) after tOut
      add the result to tLines
   end if
   if pMsg["state"] is "failed" then
      put "<p><font size=" & quote & "11" & quote & " color=" & quote & lkHex(lkColor("rose")) & quote & ">Not sent: no relay took it.</font></p>" after tOut
      add 1 to tLines
   else if pMsg["state"] is "pending" then
      put "<p><font size=" & quote & "11" & quote & " color=" & quote & lkHex(lkColor("muted")) & quote & ">Sending...</font></p>" after tOut
      add 1 to tLines
   end if
   return tOut for value
end xtcwBodyHtml

-- A block of code: dark, in the code font, coloured as Learn colours it,
-- and a Copy link under it
private function xtcwCodeHtml pCode, pLineBefore
   local tOut, tLine, tIndex, tFont, tCount
   if char -1 of pCode is return then
      delete char -1 of pCode
   end if
   put the number of elements of sCode + 1 into tIndex
   put pCode into sCode[tIndex]
   put lkCodeFont() into tFont
   put 0 into tCount
   repeat for each line tLine in pCode
      put "<p bgcolor=" & quote & lkHex(lkColor("code")) & quote & " leftindent=" & quote & "4" & quote & " rightindent=" & quote & "40" & quote & " padding=" & quote & "2" & quote & ">" after tOut
      if tFont is not empty then
         put "<font face=" & quote & tFont & quote & " size=" & quote & "13" & quote & ">" & lkCodeLineHtml(tLine) & "</font>" after tOut
      else
         put "<font size=" & quote & "13" & quote & ">" & lkCodeLineHtml(tLine) & "</font>" after tOut
      end if
      put "</p>" after tOut
      add 1 to tCount
   end repeat
   put "<p spacebelow=" & quote & "4" & quote & "><font size=" & quote & "11" & quote & "><a href=" & quote & "copy:" & tIndex & quote & ">Copy code</a></font></p>" after tOut
   add 1 to tCount
   return tOut for value
end xtcwCodeHtml

-- A line of text: escaped, `code` in the code font, and web addresses as
-- links
private function xtcwInlineHtml pLine
   local tOut, tWord, tIndex, tCount, tInCode, tFont, tChar, tRun, tPos
   put lkCodeFont() into tFont
   -- Backticks first: what is between two of them is code
   put false into tInCode
   repeat for each char tChar in pLine
      if tChar is "`" then
         if tInCode then
            put xtcwCodeSpan(tRun, tFont) after tOut
         else
            put xtcwLinks(tRun) after tOut
         end if
         put empty into tRun
         put not tInCode into tInCode
      else
         put tChar after tRun
      end if
   end repeat
   if tInCode then
      put xtcwLinks("`" & tRun) after tOut
   else
      put xtcwLinks(tRun) after tOut
   end if
   return tOut
end xtcwInlineHtml

private function xtcwCodeSpan pText, pFont
   local tOut
   put "<font color=" & quote & lkHex(lkColor("violet")) & quote into tOut
   if pFont is not empty then
      put " face=" & quote & pFont & quote after tOut
   end if
   put ">" & lkEscape(pText) & "</font>" after tOut
   return tOut
end xtcwCodeSpan

-- Text with its web addresses (http:// and https://) as links
private function xtcwLinks pText
   local tOut, tIndex, tWord, tWords, tSpace, tTail
   put empty into tOut
   set the itemDelimiter to space
   put the number of items of pText into tWords
   repeat with tIndex = 1 to tWords
      put item tIndex of pText into tWord
      if tIndex > 1 then
         put space after tOut
      end if
      if tWord begins with "http://" or tWord begins with "https://" then
         -- (a full stop or a bracket after an address ends the sentence,
         -- not the address)
         put empty into tTail
         repeat while the number of chars of tWord > 8 and char -1 of tWord is among the chars of ".,;:!?)'" & quote
            put char -1 of tWord before tTail
            delete char -1 of tWord
         end repeat
         put the number of elements of sLinks + 1 into tSpace
         put tWord into sLinks[tSpace]
         put "<a href=" & quote & "link:" & tSpace & quote & ">" & lkEscape(tWord) & "</a>" & lkEscape(tTail) after tOut
      else
         put lkEscape(tWord) after tOut
      end if
   end repeat
   -- (items lose a trailing space)
   if char -1 of pText is space then
      put space after tOut
   end if
   set the itemDelimiter to comma
   return tOut
end xtcwLinks

################################################################################
#
# The welcome
#

-- Before going online: what the chat is, what others see, and a name
private command xtcwRenderWelcome
   local tX, tY, tW, tObj, tCol, tName, tCardW, tIndex, tIcon, tTitle, tText, tTop, tBottom
   if there is a group "welcome" then
      lkForget "welcome"
      delete group "welcome"
   end if
   put the width of me into tW
   put min(780, tW - kSide - 80) into tCol
   put kSide + (tW - kSide - tCol) div 2 into tX
   put 36 into tY
   get lkGroup("welcome", lkR(kSide, 0, tW, the height of me), empty)
   -- The hero
   put lkBox("w_hero", lkR(tX, tY, tX + tCol, tY + 210), lkColor("teal"), 22, "welcome") into tObj
   lkGradient tObj, "13,148,136|2,132,199|79,70,229", tX & "," & tY, (tX + tCol) & "," & (tY + 210)
   lkShadow tObj, 24, 8, 30
   repeat with tIndex = 1 to 3
      put lkOval("w_glow" & tIndex, lkR(0, 0, item tIndex of "240,180,140", item tIndex of "240,180,140"), "255,255,255", "welcome") into tObj
      lkGlowFill tObj, "255,255,255", item tIndex of "60,50,45"
      set the loc of tObj to tX + tCol * item tIndex of "0.82,0.95,0.62", tY + 210 * item tIndex of "0.3,0.9,0.95"
      set the blendLevel of tObj to 45
   end repeat
   put lkLabel("w_eyebrow", lkR(tX + 36, tY + 30, tX + tCol - 36, tY + 46), "XTALK CHAT", 12, "255,255,255", "welcome") into tObj
   set the textStyle of tObj to "bold"
   set the blendLevel of tObj to 25
   put lkLabel("w_title", lkR(tX + 36, tY + 52, tX + tCol - 36, tY + 94), "Talk with other xTalk developers", 30, "255,255,255", "welcome") into tObj
   set the textStyle of tObj to "bold"
   xtcwFit tObj
   put the bottom of tObj + 12 into tTop
   put lkLabel("w_text", lkR(tX + 36, tTop, tX + tCol - 60, tTop + 66), \
         "Ask for help, show what you are making and meet the people who use OXT-Beyond, LiveCode and HyperCard, right in the IDE. No account and no server of ours: the chat goes through Nostr relays, and who you are is a key kept on this computer.", 14, "255,255,255", "welcome") into tObj
   xtcwFit tObj
   set the blendLevel of tObj to 8
   put max(tY + 170, the bottom of tObj + 34) into tBottom
   set the rect of graphic "w_hero" to tX, tY, tX + tCol, tBottom
   lkGradientPoints the long id of graphic "w_hero", tX & "," & tY, (tX + tCol) & "," & tBottom
   put tBottom + 26 into tY

   -- What others see, in three cards
   put lkLabel("w_seeTitle", lkR(tX, tY, tX + tCol, tY + 26), "Before you go online", 18, lkColor("ink"), "welcome") into tObj
   set the textStyle of tObj to "bold"
   add 34 to tY
   put (tCol - 2 * 14) div 3 into tCardW
   put tY into tTop
   put tY + 150 into tBottom
   repeat with tIndex = 1 to 3
      switch tIndex
         case 1
            put "hash" into tIcon
            put "Rooms are public" into tTitle
            put "What you write in a room can be read by anyone, now and later, with any Nostr app. Write as you would on a forum." into tText
            break
         case 2
            put "lock" into tIcon
            put "Private messages are sealed" into tTitle
            put "They are encrypted for the person you write to. Relays see neither who wrote them nor what they say." into tText
            break
         case 3
            put "globe" into tIcon
            put "Relays see your address" into tTitle
            put "Your IP address, as any server does. You are online only while this window is open, and Go offline ends it." into tText
            break
      end switch
      put tX + (tIndex - 1) * (tCardW + 14) into tCol
      put lkBox("w_card" & tIndex, lkR(tCol, tTop, tCol + tCardW, tBottom), lkColor("panel"), 16, "welcome") into tObj
      lkBorder tObj, lkColor("line")
      put lkBox("w_cardIconBg" & tIndex, lkR(tCol + 18, tTop + 18, tCol + 50, tTop + 50), lkMix("255,255,255", lkColor("teal"), 0.12), 10, "welcome") into tObj
      get lkIcon("w_cardIcon" & tIndex, tIcon, lkColor("teal"), lkR(tCol + 26, tTop + 26, tCol + 42, tTop + 42), "welcome")
      put lkLabel("w_cardTitle" & tIndex, lkR(tCol + 18, tTop + 62, tCol + tCardW - 16, tTop + 82), tTitle, 14, lkColor("ink"), "welcome") into tObj
      set the textStyle of tObj to "bold"
      xtcwFit tObj
      put lkLabel("w_cardText" & tIndex, lkR(tCol + 18, the bottom of tObj + 6, tCol + tCardW - 16, the bottom of tObj + 60), tText, 12, lkColor("soft"), "welcome") into tObj
      xtcwFit tObj
      put max(tBottom, the bottom of tObj + 16) into tBottom
   end repeat
   repeat with tIndex = 1 to 3
      -- (the rect: setting a graphic's bottom moves it, its height kept)
      set the rect of graphic ("w_card" & tIndex) to item 1 to 3 of the rect of graphic ("w_card" & tIndex), tBottom
   end repeat
   put min(780, tW - kSide - 80) into tCol
   put tBottom + 26 into tY

   -- The name, and Go online
   put lkLabel("w_nameCap", lkR(tX, tY, tX + tCol, tY + 18), "The name others will see", 13, lkColor("soft"), "welcome") into tObj
   set the textStyle of tObj to "bold"
   add 24 to tY
   put lkBox("w_nameBg", lkR(tX, tY, tX + 340, tY + 40), lkColor("panel"), 12, "welcome") into tObj
   lkBorder tObj, lkColor("line")
   put xtcMyName() into tName
   if tName is empty then
      put xtcwSuggestedName() into tName
   end if
   put lkInput("w_name", lkR(tX + 14, tY + 11, tX + 330, tY + 31), tName, 14, "welcome") into tObj
   get lkButton("w_go", tX + 356, tY + 1, 38, "Go online", "power", "primary", lkColor("teal"), "welcome", "go online", 140, "welcome")
   add 54 to tY
   create button "w_client" in group "welcome"
   set the style of button "w_client" to "checkbox"
   set the hiliteBorder of button "w_client" to false
   set the showFocusBorder of button "w_client" to false
   set the label of button "w_client" to "Show the others which OXT-Beyond I use (its version and platform)"
   set the textSize of button "w_client" to 13
   set the textColor of button "w_client" to lkColor("soft")
   set the hilite of button "w_client" to xtcwPref("showClient") is not false
   set the rect of button "w_client" to tX - 2, tY, tX + tCol, tY + 22
   add 34 to tY
   if xtcHasIdentity() or there is a file xtcIdentityFile() then
      put "Your key is kept in" && xtcIdentityFile() & ". Settings (the gear below) can copy it, so that you can be the same person on another computer." into tText
   else
      put "Going online makes your key and keeps it in" && xtcIdentityFile() & ". Settings (the gear below) can copy it, or use a key you already have." into tText
   end if
   put lkLabel("w_keyNote", lkR(tX, tY, tX + tCol, tY + 40), tText, 12, lkColor("muted"), "welcome") into tObj
   xtcwFit tObj
   if xtcMissing() is not empty then
      add the height of tObj + 14 to tY
      put lkLabel("w_missing", lkR(tX, tY, tX + tCol, tY + 40), xtcMissing(), 13, lkColor("rose"), "welcome") into tObj
      xtcwFit tObj
   end if
   lkEnter "welcome"
end xtcwRenderWelcome

-- A first name for the welcome's box: the user's login name, if any
private function xtcwSuggestedName
   local tName
   if the platform is "Win32" then
      put $USERNAME into tName
   else
      put $USER into tName
   end if
   if tName is "root" or tName is "user" then
      put empty into tName
   end if
   return tName
end xtcwSuggestedName

-- A field made as tall as its text, its top kept
private command xtcwFit pObj
   local tTop
   put the top of pObj into tTop
   set the height of pObj to the formattedHeight of pObj + kTextInset
   set the top of pObj to tTop
end xtcwFit

################################################################################
#
# What the user does
#

on lkAction pAction
   switch word 1 of pAction
      case "go"
         if word 2 of pAction is "online" then
            xtcwGoOnline
         else
            xtcwShow word 2 of pAction
         end if
         break
      case "send"
         xtcwSend
         break
      case "power"
         if xtcIsOnline() then
            xtcwGoOffline
         else if sView is "welcome" and there is a field "w_name" then
            xtcwGoOnline
         else
            xtcwShow "welcome"
         end if
         break
      case "gear"
         xtcwGearMenu
         break
   end switch
end lkAction

-- Return sends, Shift-Return starts a new line
on returnInField
   if the short name of the target is "compose" then
      if the shiftKey is down then
         pass returnInField
      end if
      xtcwSend
   else if the short name of the target is "w_name" then
      xtcwGoOnline
   else
      pass returnInField
   end if
end returnInField

on enterInField
   if the short name of the target is "compose" then
      xtcwSend
   else if the short name of the target is "w_name" then
      xtcwGoOnline
   else
      pass enterInField
   end if
end enterInField

on textChanged
   if the short name of the target is "compose" then
      xtcwComposeChanged
   end if
   pass textChanged
end textChanged

-- The hint shows while the box is empty, and the box grows with its text
private command xtcwComposeChanged
   local tWanted
   if field "compose" is empty then
      show field "cmp_hint"
   else
      hide field "cmp_hint"
   end if
   put max(kComposeMin, min(kComposeMax, the formattedHeight of field "compose" + 22)) into tWanted
   if tWanted is not sComposeHeight then
      put tWanted into sComposeHeight
      set the vScrollbar of field "compose" to the formattedHeight of field "compose" + 22 > kComposeMax
      xtcwLayout
   end if
end xtcwComposeChanged

private command xtcwSend
   local tText
   put field "compose" into tText
   if word 1 to -1 of tText is empty then
      exit xtcwSend
   end if
   xtcSend sView, tText
   if the result is not empty then
      xtcwToast the result, "warn"
      exit xtcwSend
   end if
   put empty into field "compose"
   put empty into sDrafts[sView]
   xtcwComposeChanged
   xtcwRenderMessages true
   focus on field "compose"
end xtcwSend

-- A link in the messages or the people: copy code, open a web page (after
-- asking), or a person
on linkClicked pLink
   local tTarget
   put the short name of the target into tTarget
   if pLink begins with "copy:" then
      set the clipboardData["text"] to sCode[char 6 to -1 of pLink]
      xtcwToast "The code is on the clipboard.", "ok"
   else if pLink begins with "link:" then
      xtcwOpenLink sLinks[char 6 to -1 of pLink]
   else if pLink begins with "who:" then
      xtcwWhoMenu char 5 to -1 of pLink
   else
      pass linkClicked
   end if
end linkClicked

-- A click on a name line in the messages
on mouseUp pButton
   local tLine
   if the short name of the target is "ppl_list" and pButton is 1 then
      put word 2 of the clickLine into tLine
      if tLine is an integer and sPeopleWho[tLine] is not empty then
         xtcwWhoMenu sPeopleWho[tLine]
         exit mouseUp
      end if
   end if
   if the short name of the target is "msgs" and pButton is 1 then
      put word 2 of the clickLine into tLine
      if tLine is an integer and sLineWho[tLine] is not empty and the clickText is not empty then
         if word 1 of the clickChunk is "char" then
            xtcwWhoMenu sLineWho[tLine]
            exit mouseUp
         end if
      end if
   end if
   pass mouseUp
end mouseUp

private command xtcwOpenLink pUrl
   answer question "Open this page in your web browser?" & return & return & pUrl & return & return & "Someone in the chat sent it: open it only if you trust where it goes." with "Cancel" or "Open" titled "xTalk Chat"
   if it is "Open" then
      launch url pUrl
   end if
end xtcwOpenLink

-- What can be done with a person
private command xtcwWhoMenu pPk
   local tMenu
   if pPk is xtcMyKey() then
      put "Copy your public key (npub)" into tMenu
   else
      put "Message" && xtcwMenuSafe(xtcName(pPk)) && "privately" & return & \
            "Copy their public key (npub)" & return & "-" & return & \
            "Mute" && xtcwMenuSafe(xtcName(pPk)) into tMenu
   end if
   set the text of button "whoMenu" to tMenu
   set the cWho of button "whoMenu" to pPk
   popup button "whoMenu"
end xtcwWhoMenu

-- A name in a menu: no character that a menu reads as markup
private function xtcwMenuSafe pName
   local tChar
   repeat for each item tChar in "(,!,/,&,<,>,^,|"
      replace tChar with space in pName
   end repeat
   return word 1 to -1 of pName
end xtcwMenuSafe

on menuPick pItem
   local tPk
   switch the short name of the target
      case "whoMenu"
         put the cWho of button "whoMenu" into tPk
         if pItem begins with "Message" then
            xtcStartPrivate tPk
            xtcwShow "dm:" & tPk
         else if pItem begins with "Copy" then
            set the clipboardData["text"] to xtcNpubOf(tPk)
            xtcwToast "The public key is on the clipboard.", "ok"
         else if pItem begins with "Mute" then
            xtcwMute tPk
         end if
         break
      case "gearMenu"
         xtcwGearPick pItem
         break
      default
         pass menuPick
   end switch
end menuPick

private command xtcwMute pPk
   local tName, tList
   put xtcName(pPk) into tName
   answer question "Mute" && tName & "?" & return & return & "You will not see their messages or see them online. Settings > Muted people undoes it." with "Cancel" or "Mute" titled "xTalk Chat"
   if it is not "Mute" then
      exit xtcwMute
   end if
   xtcMute pPk
   xtcwSetPref "muted", xtcMuted()
   if sView is "dm:" & pPk then
      xtcwShow xtcwFirstRoom()
   end if
   xtcwToast tName && "is muted.", "ok"
end xtcwMute

################################################################################
#
# Settings
#

private command xtcwGearMenu
   local tMenu
   if xtcHasIdentity() then
      put "Change your name..." & return after tMenu
   end if
   if xtcwPref("showClient") is not false then
      put "!c" after tMenu
   end if
   put "Show which OXT-Beyond you use" & return after tMenu
   put "Relays..." & return after tMenu
   put "-" & return after tMenu
   if xtcHasIdentity() then
      put "Copy your public key (npub)" & return after tMenu
      put "Write to someone by their key..." & return after tMenu
      put "Copy your secret key, to use it elsewhere..." & return after tMenu
   end if
   put "Use a key you already have..." & return after tMenu
   if xtcMuted() is not empty then
      put "Unmute everyone" & return after tMenu
   end if
   put "-" & return after tMenu
   put "About xTalk Chat" & return after tMenu
   if xtcHasIdentity() then
      put "Forget who you are on this computer..." after tMenu
   end if
   set the text of button "gearMenu" to tMenu
   popup button "gearMenu"
end xtcwGearMenu

private command xtcwGearPick pItem
   local tName, tRelays, tKey, tWasOnline
   switch true
      case pItem begins with "Change your name"
         ask "The name others will see:" with xtcMyName() titled "xTalk Chat"
         if it is empty or the result is "Cancel" then
            exit xtcwGearPick
         end if
         xtcSetName it
         xtcwSyncMe
         xtcwSyncPeople
         xtcwRenderMessages
         xtcwToast "Your name is" && xtcMyName() & ".", "ok"
         break
      case pItem contains "Show which OXT-Beyond"
         xtcwSetPref "showClient", xtcwPref("showClient") is false
         xtcSetShowClient xtcwPref("showClient") is not false
         xtcwSyncPeople
         break
      case pItem begins with "Relays"
         xtcwRelaysDialog
         break
      case pItem begins with "Copy your public key"
         set the clipboardData["text"] to xtcMyNpub()
         xtcwToast "Your public key is on the clipboard: give it to anyone.", "ok"
         break
      case pItem begins with "Write to someone"
         ask "The public key (npub1...) of the person to write to:" titled "xTalk Chat"
         if it is empty or the result is "Cancel" then
            exit xtcwGearPick
         end if
         put xtcKeyFromText(it) into tKey
         if tKey is empty then
            xtcwToast "That is not a public key (npub1...).", "warn"
            exit xtcwGearPick
         end if
         xtcStartPrivate tKey
         xtcwShow "dm:" & tKey
         break
      case pItem begins with "Copy your secret key"
         answer warning "Your secret key is who you are in xTalk Chat: anyone who has it can write as you. Copy it only to use it in another chat or on another computer of yours, and never paste it into a message." with "Cancel" or "Copy Secret Key" titled "xTalk Chat"
         if it is "Copy Secret Key" then
            set the clipboardData["text"] to xtcMyNsec()
            xtcwToast "Your secret key is on the clipboard.", "warn"
         end if
         break
      case pItem begins with "Use a key"
         ask password "Paste the secret key (nsec1...) to use. The chat keeps it in" && xtcIdentityFile() & ", in place of the one there now." titled "xTalk Chat"
         if it is empty or the result is "Cancel" then
            exit xtcwGearPick
         end if
         put it into tKey
         put xtcIsOnline() into tWasOnline
         if tWasOnline then
            xtcGoOffline
         end if
         put xtcMyName() into tName
         if tName is empty then
            put xtcwSuggestedName() into tName
         end if
         xtcIdentityCreate tName, tKey
         if the result is not empty then
            xtcwToast the result, "bad"
         else
            xtcwToast "You are now the person that key belongs to.", "ok"
         end if
         if tWasOnline then
            xtcwGoOnline
         else
            xtcwShow "welcome"
         end if
         xtcwSyncMe
         break
      case pItem begins with "Unmute"
         xtcSetMuted empty
         xtcwSetPref "muted", empty
         xtcwSyncPeople
         xtcwRenderMessages
         break
      case pItem begins with "About"
         answer information "xTalk Chat lets the people who use OXT-Beyond talk to each other: rooms everyone can read, who is online now, and private messages." & return & return & \
               "It is built on the xTalk Suite's NostrXT, CoinXT and SodiumXT, which come with OXT-Beyond. Messages go through Nostr relays (Settings > Relays), are signed with your key, and are checked before they are shown. Private messages are encrypted (NIP-44) and sealed (NIP-17)." & return & return & \
               "You:" && xtcMyNpub() titled "xTalk Chat"
         break
      case pItem begins with "Forget who you are"
         answer warning "Forget who you are in xTalk Chat on this computer? Your key file is deleted, and unless you kept a copy of your secret key, no one can be you again: the next time you go online you are someone new." with "Cancel" or "Forget" titled "xTalk Chat"
         if it is "Forget" then
            xtcIdentityForget
            xtcwSetPref "autoOnline", false
            put empty into sDrafts
            xtcwShow "welcome"
            xtcwSyncPrivate
            xtcwSyncMe
         end if
         break
   end switch
end xtcwGearPick

-- The relays: one wss:// address a line, or empty for the chat's own
private command xtcwRelaysDialog
   local tNow, tNew, tLine, tOut
   put xtcwPref("relays") into tNow
   if tNow is empty then
      put xtcDefaultRelays() into tNow
   end if
   replace return with ", " in tNow
   ask "The relays the chat uses, separated by commas (each wss://...). Leave it empty for the chat's own." & return & "The people you want to talk to must share at least one." with tNow titled "xTalk Chat"
   if the result is "Cancel" then
      exit xtcwRelaysDialog
   end if
   put it into tNew
   replace comma with return in tNew
   repeat for each line tLine in tNew
      put word 1 to -1 of tLine into tLine
      if tLine is empty then
         next repeat
      end if
      if not (tLine begins with "wss://" or tLine begins with "ws://") then
         xtcwToast tLine && "is not a relay's address (wss://...).", "warn"
         exit xtcwRelaysDialog
      end if
      put tLine & return after tOut
   end repeat
   delete the last char of tOut
   if tOut is xtcDefaultRelays() then
      put empty into tOut
   end if
   xtcwSetPref "relays", tOut
   if xtcIsOnline() then
      xtcGoOffline
      xtcwGoOnline
   end if
   xtcwToast "The relays are set.", "ok"
end xtcwRelaysDialog

################################################################################
#
# Preferences, through the plugin's main stack
#

function xtcwPref pName
   local tValue
   dispatch function "xtchPref" to stack kMain with pName
   put the result into tValue
   return tValue
end xtcwPref

command xtcwSetPref pName, pValue
   dispatch "xtchSetPref" to stack kMain with pName, pValue
end xtcwSetPref

################################################################################
#
# The toast, and each frame
#

command xtcwToast pText, pKind
   local tColor, tIcon, tWidth, tLeft, tTop, tSaved
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   switch pKind
      case "warn"
         put lkColor("amber") into tColor
         put "triangle-alert" into tIcon
         break
      case "bad"
         put lkColor("rose") into tColor
         put "triangle-alert" into tIcon
         break
      default
         put lkMix(lkColor("emerald"), "255,255,255", 0.2) into tColor
         put "check" into tIcon
   end switch
   lock screen
   set the dontWrap of field "toast_label" to true
   put pText into field "toast_label"
   put min(the formattedWidth of field "toast_label", sWidth - kSide - 120) + 62 into tWidth
   put kSide + (sWidth - kSide - tWidth) div 2 into tLeft
   put sHeight - 72 into tTop
   set the rect of group "toast" to tLeft, tTop, tLeft + tWidth, tTop + 40
   set the rect of graphic "toast_bg" to tLeft, tTop, tLeft + tWidth, tTop + 40
   lkIconInk the long id of image "toast_icon", tIcon, tColor
   set the topLeft of image "toast_icon" to tLeft + 16, tTop + 12
   set the rect of field "toast_label" to tLeft + 42, tTop + 11 - kTextInset, tLeft + tWidth - 10, tTop + 31
   lkEllipsize the long id of field "toast_label"
   set the layer of group "toast" to top
   show group "toast"
   unlock screen
   put lkNow() + 3200 into sToastUntil
   if sToastUntil < 3200 then
      put the milliseconds + 3200 into sToastUntil
   end if
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end xtcwToast

on lkFrame
   local tY
   -- The sidebar's highlight slides to the conversation in front
   if sNavTarget is not empty and abs(sNavY - sNavTarget) > 0.5 then
      put sNavY + (sNavTarget - sNavY) * min(1, lkDt() * 14) into sNavY
      put round(sNavY) into tY
      set the top of graphic "navHi" to tY
      set the top of graphic "navBar" to tY + 7
   else if sNavTarget is not empty and sNavY is not sNavTarget then
      put sNavTarget into sNavY
      set the top of graphic "navHi" to sNavY
      set the top of graphic "navBar" to sNavY + 7
   end if
   if sToastUntil is not empty and lkNow() > sToastUntil then
      put empty into sToastUntil
      hide group "toast"
   end if
end lkFrame
