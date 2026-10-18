script "OXTExampleRssReader"
-- OXT-Beyond: builds "RSS Reader", the remaster of the RSS Demo of
-- OpenXTalk Lite's demos (ide/Resources/Examples/RSS Demo.oxtstack), which
-- stays there as it was made. Its author is not recorded: the script of
-- its Import button begins "via theotherbassist, April 2016", and the
-- stack names no licence.
--
-- The original is one card: a field with a feed's address (the Guardian's
-- UK news), an Import button whose 26 lines read the feed's titles into a
-- field with revXML, and a Clear button. The remaster keeps that program
-- on its own card, changed only where today's web needs it (each change
-- is marked "(2026)" in the script: the feed is https now, which
-- revXMLCreateTreeFromFile cannot read, so url fetches it first; and a
-- feed that does not come ended in a loop that never stopped). Then it
-- grows the program into a reader on a wide card: feeds to pick, the
-- stories as a list with their dates, the chosen story's summary, and
-- Open in browser. The reader reads a feed the original's way (a tree,
-- its items counted, each read by its path), and reads Atom feeds too.
-- A page shows what a feed's XML looks like and the four lines that read
-- it.
--
-- Nothing is copied from the original stack: it has no pictures or other
-- assets. build-examples.livecodescript runs exBuild with the builder in
-- use.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- A program card's stage ends here
constant kNarrowRight = 600
-- The feeds to pick on the Reader: label|address|icon
constant kFeeds = "The Guardian|https://www.theguardian.com/uk/rss|newspaper,BBC News|https://feeds.bbci.co.uk/news/rss.xml|globe,NPR News|https://feeds.npr.org/1001/rss.xml|radio,NASA|https://www.nasa.gov/news-release/feed/|rocket"

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   -- (icons the kit does not have, from Lucide 0.469.0, ISC licence)
   exAddIcon "radio", "<path d='M4.9 19.1C1 15.2 1 8.8 4.9 4.9'/><path d='M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5'/><circle cx='12' cy='12' r='2'/><path d='M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5'/><path d='M19.1 4.9C23 8.8 23 15.1 19.1 19'/>"
   exAddIcon "loader-circle", "<path d='M21 12a9 9 0 1 1-6.219-8.56'/>"
   exAddIcon "wifi-off", "<path d='M12 20h.01'/><path d='M8.5 16.429a5 5 0 0 1 7 0'/><path d='M5 12.859a10 10 0 0 1 5.17-2.69'/><path d='M19 12.859a10 10 0 0 0-2.007-1.523'/><path d='M2 8.82a15 15 0 0 1 4.177-2.643'/><path d='M22 8.82a15 15 0 0 0-11.288-3.764'/><path d='m2 2 20 20'/>"
   put "RSS Reader" into tInfo["name"]
   put "from OpenXTalk Lite's demos" into tInfo["credit"]
   put "rss" into tInfo["icon"]
   put lkColor("orange") into tInfo["accent"]
   put lkColor("rose") into tInfo["accent2"]
   put "Step" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|RSS Reader|Read the news from any site that keeps a feed, in a few lines of xTalk.|rss|front" & return & \
         "Import|Import|The original program: a feed's titles, read into a field with revXML.|rss|program" & return & \
         "Reader|Reader|Pick a feed, read its stories, and open one in your browser.|newspaper|wide" & return & \
         "Inside a Feed|Inside a Feed|A feed is XML: a channel of items, each with a title, a link and a date.|list-tree|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   buildImport
   buildReader
   buildInside
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/RSS Reader.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

################################################################################
#
# Helpers
#

-- A white panel with an icon on a tint, a bold title and words under it
private command infoPanel pName, pRect, pIcon, pTitle, pText
   local tObj, tLeft, tTop, tRight
   put item 1 of pRect into tLeft
   put item 2 of pRect into tTop
   put item 3 of pRect into tRight
   get lkGroup(pName, pRect, empty)
   put exPanel(pName & "_bg", pRect, pName) into tObj
   iconTile pName & "_icon", pIcon, tLeft + 20, tTop + 20, 40, lkColor("orange"), pName
   put lkLabel(pName & "_title", lkR(tLeft + 76, tTop + 22, tRight - 20, tTop + 42), pTitle, 15, lkColor("ink"), pName) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel(pName & "_text", lkR(tLeft + 76, tTop + 48, tRight - 22, item 4 of pRect - 16), pText, 13, lkColor("soft"), pName) into tObj
end infoPanel

-- An icon on a rounded square of a tint of its colour
private command iconTile pName, pIcon, pLeft, pTop, pSize, pColor, pGroup
   local tInset
   get lkBox(pName & "Bg", lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), lkMix("255,255,255", pColor, 0.12), 11, pGroup)
   put pSize div 4 into tInset
   get exIcon(pName, pIcon, pColor, lkR(pLeft + tInset, pTop + tInset, pLeft + pSize - tInset, pTop + pSize - tInset), pGroup)
end iconTile

-- A field of code: its text in colour (the kit's colours, for a dark panel),
-- a fixed line height. The code font is chosen when the card opens
private function codeField pName, pRect, pText, pSize, pLineHeight, pGroup
   local tObj
   put lkLabel(pName, pRect, empty, pSize, lkColor("codeInk"), pGroup) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to pLineHeight
   set the dontWrap of tObj to false
   set the htmlText of tObj to lkCodeHtml(pText)
   return tObj
end codeField

-- XML in colour: tags sky, their attributes amber, the text between them
-- light
private function xmlHtml pText
   local tHtml, tLine, tOut, tPos, tChar, tInTag, tInValue
   repeat for each line tLine in pText
      put empty into tOut
      put false into tInTag
      put false into tInValue
      repeat with tPos = 1 to the number of chars of tLine
         put char tPos of tLine into tChar
         if tChar is "<" and not tInTag then
            put "<font color=" & quote & "#7dd3fc" & quote & ">&lt;" after tOut
            put true into tInTag
         else if tChar is ">" and tInTag and not tInValue then
            put "&gt;</font>" after tOut
            put false into tInTag
         else if tChar is quote and tInTag then
            if tInValue then
               put quote & "</font>" after tOut
            else
               put "<font color=" & quote & "#fcd34d" & quote & ">" & quote after tOut
            end if
            put not tInValue into tInValue
         else if tChar is "&" then
            put "&amp;" after tOut
         else
            put tChar after tOut
         end if
      end repeat
      put "<p>" & tOut & "</p>" after tHtml
   end repeat
   return tHtml
end xmlHtml

################################################################################
#
# The cards
#

-- The front page: what this is, a tile for each step, what it teaches and
-- where it came from
private command buildFront
   local tObj, tIndex, tTop, tRows
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 272), lkColor("rose") & "|" & lkColor("orange"), \
         "FROM OPENXTALK LITE'S DEMOS  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "The news, in a few lines of xTalk", \
         "A news site keeps a feed: a page of XML that lists its newest stories. The original read one " & \
         "in 26 lines, and here it grows into a reader: a list of stories, each with its summary and a link to the whole story."
   exProgramTiles 288, 3, 60, 12
   -- What it teaches, a line each
   get lkGroup("Learn", lkR(kLeft, 360, 620, kBottom), empty)
   put exPanel("Learn_bg", lkR(kLeft, 360, 620, kBottom), "Learn") into tObj
   put lkLabel("Learn_title", lkR(kLeft + 20, 380, 600, 400), "What you will learn", 15, lkColor("ink"), "Learn") into tObj
   set the textStyle of tObj to "bold"
   put "globe|Fetch a feed from the web with url." & return & \
         "list-tree|Make a tree of its XML with revXML." & return & \
         "search|Read each story's title by its path." & return & \
         "external-link|Open a story with launch url." into tRows
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put 414 + (tIndex - 1) * 48 into tTop
      iconTile "Learn_icon" & tIndex, item 1 of line tIndex of tRows, kLeft + 20, tTop, 36, lkColor("orange"), "Learn"
      -- (room for a second line, where a computer's font is wider)
      put lkLabel("Learn_text" & tIndex, lkR(kLeft + 68, tTop + 9, 604, tTop + 46), item 2 of line tIndex of tRows, 13, \
            lkColor("soft"), "Learn") into tObj
   end repeat
   set the itemDelimiter to comma
   -- Where it came from
   infoPanel "Origin", lkR(636, 360, kRight, kBottom), "heart", "Where it came from", \
         "The Import program came " & quote & "via theotherbassist, April 2016" & quote & \
         ", its script says, and OpenXTalk Lite kept it among its demos. It is here as it was, with the few " & \
         "changes today's web needs, each one marked in the script."
   put lkLabel("Origin_note", lkR(712, 548, 980, 600), \
         "The feeds come from the web, so you need to be online. The web IDE can read only some of them.", \
         12, lkColor("muted"), "Origin") into tObj
end buildFront

-- The original program, on a program card: the address, Import and Clear,
-- and the titles. The names are the original's: field "feed", buttons
-- "Import" and "Clear", field "content", labels "lbl1" and "lbl2"
private command buildImport
   local tObj, tWidth
   go card "Import"
   put lkLabel("lbl1", lkR(kLeft + 16, 124, kNarrowRight - 16, 140), "Feed URL", 12, lkColor("soft"), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkBox("feed_box", lkR(kLeft + 16, 146, kNarrowRight - 16, 184), "255,255,255", 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   -- (2026: the original's address was http://www.theguardian.com/uk/rss,
   -- which the site now sends on to its https address)
   put lkInput("feed", lkR(kLeft + 30, 162, kNarrowRight - 26, 184), "https://www.theguardian.com/uk/rss", 13, empty) into tObj
   put exButton("Import", kLeft + 16, 196, 36, "Import", "rss", "primary", lkColor("orange"), empty, empty, 0) into tWidth
   set the script of group "Import" to exScript("Import/Import")
   get exButton("Clear", kLeft + 16 + tWidth + 8, 196, 36, "Clear", "x", "ghost", lkColor("orange"), empty, empty, 0)
   set the script of group "Clear" to exScript("Import/Clear")
   put lkLabel("lbl2", lkR(kLeft + 16, 250, kNarrowRight - 16, 266), "Feed Content", 12, lkColor("soft"), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkBox("content_box", lkR(kLeft + 16, 272, kNarrowRight - 16, 600), lkMix("255,255,255", lkColor("bg"), 0.6), 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   -- (the original's field takes typing too: it is not locked)
   put lkLabel("content", lkR(kLeft + 20, 278, kNarrowRight - 26, 594), empty, 13, lkColor("ink"), empty) into tObj
   set the margins of tObj to "10,8,8,8"
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the cWheel of tObj to true
   set the cThumb of tObj to "content_thumb"
   put lkBox("content_thumb", lkR(kNarrowRight - 23, 282, kNarrowRight - 19, 320), lkColor("muted"), 2, empty) into tObj
   set the blendLevel of tObj to 30
   hide tObj
end buildImport

-- The reader, on a wide card: the feeds to pick, the address, the list of
-- stories, and the story chosen
private command buildReader
   local tObj, tLeft, tFeed, tWidth, tName, tAccent, tPanel, tIndex, tTop
   go card "Reader"
   put lkColor("orange") into tAccent
   set the script of this card to exScript("Reader/card")
   -- The feeds, a button each: its address is its custom property cURL
   get lkGroup("Feeds", lkR(kLeft + 16, 120, kRight - 16, 152), empty)
   get lkBox("Feeds_anchor", lkR(kLeft + 16, 120, kLeft + 17, 121), empty, 0, "Feeds")
   put kLeft + 16 into tLeft
   set the itemDelimiter to "|"
   repeat for each line tFeed in replaceText(kFeeds, ",(?=[A-Z])", return)
      put "Feed" & word 1 of item 1 of tFeed into tName
      put exButton(tName, tLeft, 120, 32, item 1 of tFeed, item 3 of tFeed, "ghost", tAccent, "Feeds", empty, 0) into tWidth
      set the cURL of group tName to item 2 of tFeed
      set the cPicked of group tName to lkMix("255,255,255", tAccent, 0.14)
      set the cPickedLine of group tName to lkMix("255,255,255", tAccent, 0.55)
      set the cLine of group tName to lkColor("line")
      add tWidth + 8 to tLeft
   end repeat
   set the itemDelimiter to comma
   set the script of group "Feeds" to exScript("Reader/Feeds")
   -- The address, and Read
   put lkBox("URL_box", lkR(kLeft + 16, 164, 860, 204), "255,255,255", 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   get exIcon("URL_icon", "rss", tAccent, lkR(kLeft + 30, 176, kLeft + 46, 192), empty)
   put lkInput("URL", lkR(kLeft + 58, 179, 848, 202), empty, 14, empty) into tObj
   get exButton("Read", 872, 164, 40, "Read", "arrow-right", "primary", tAccent, empty, empty, 112)
   set the right of group "Read" to kRight - 16
   set the script of group "Read" to exScript("Reader/Read")
   -- The list of stories: a title and its date, two lines each, on a
   -- tint (the graphic "Pick") behind the story chosen
   put lkLabel("ListHead", lkR(kLeft + 16, 222, kNarrowRight, 240), "Stories", 13, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   -- (while the list is empty, faint lines where the stories will be)
   get lkGroup("Placeholder", lkR(kLeft + 16, 246, kNarrowRight, 600), empty)
   get lkBox("Placeholder_anchor", lkR(kLeft + 16, 246, kLeft + 17, 247), empty, 0, "Placeholder")
   repeat with tIndex = 1 to 6
      put 264 + (tIndex - 1) * 52 into tTop
      put lkBox("Placeholder_title" & tIndex, lkR(kLeft + 28, tTop, kLeft + 28 + item tIndex of "250,196,272,180,236,208", tTop + 10), \
            lkColor("line"), 5, "Placeholder") into tObj
      set the blendLevel of tObj to (tIndex - 1) * 15
      put lkBox("Placeholder_date" & tIndex, lkR(kLeft + 28, tTop + 19, kLeft + 100, tTop + 27), lkColor("line"), 4, "Placeholder") into tObj
      set the blendLevel of tObj to 40 + (tIndex - 1) * 10
   end repeat
   get lkGroup("List", lkR(kLeft + 16, 246, kNarrowRight, 600), empty)
   get lkBox("List_anchor", lkR(kLeft + 16, 246, kLeft + 17, 247), empty, 0, "List")
   put lkBox("Pick", lkR(kLeft + 18, 250, kNarrowRight - 10, 300), lkMix("255,255,255", tAccent, 0.12), 12, "List") into tObj
   hide tObj
   put lkLabel("Stories", lkR(kLeft + 16, 250, kNarrowRight - 8, 600), empty, 13, lkColor("ink"), "List") into tObj
   set the rect of tObj to kLeft + 16, 246, kNarrowRight - 8, 600
   set the margins of tObj to "12,8,14,8"
   set the cWheel of tObj to true
   set the cThumb of tObj to "Stories_thumb"
   set the script of tObj to exScript("Reader/Stories")
   put lkBox("Stories_thumb", lkR(kNarrowRight - 6, 250, kNarrowRight - 2, 300), lkColor("muted"), 2, "List") into tObj
   set the blendLevel of tObj to 30
   hide tObj
   -- The story chosen, on a panel at the right; or a note, when there is
   -- no story to show
   put lkBox("Panel", lkR(616, 222, kRight - 16, 600), lkMix("255,255,255", lkColor("bg"), 0.7), 16, empty) into tPanel
   lkBorder tPanel, lkColor("line")
   get lkGroup("Story", lkR(616, 222, kRight - 16, 600), empty)
   get lkBox("Story_anchor", lkR(616, 222, 617, 223), empty, 0, "Story")
   put lkLabel("Source", lkR(640, 246, 960, 262), empty, 11, tAccent, "Story") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   put lkLabel("Headline", lkR(640, 268, 960, 320), empty, 19, lkColor("ink"), "Story") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("When", lkR(640, 326, 960, 344), empty, 12, lkColor("muted"), "Story") into tObj
   set the dontWrap of tObj to true
   put lkLabel("Summary", lkR(640, 354, 960, 532), empty, 14, lkColor("soft"), "Story") into tObj
   get exButton("Open", 640, 548, 36, "Open in browser", "external-link", "primary", tAccent, "Story", empty, 0)
   set the script of group "Open" to exScript("Reader/Open")
   hide group "Story"
   get lkGroup("Note", lkR(616, 222, kRight - 16, 600), empty)
   get lkBox("Note_anchor", lkR(616, 222, 617, 223), empty, 0, "Note")
   put lkOval("Note_circle", lkR(768, 296, 832, 360), lkMix("255,255,255", tAccent, 0.14), "Note") into tObj
   get exIcon("Note_rss", "rss", tAccent, lkR(786, 314, 814, 342), "Note")
   get exIcon("Note_wait", "loader-circle", tAccent, lkR(786, 314, 814, 342), "Note")
   get exIcon("Note_offline", "wifi-off", tAccent, lkR(786, 314, 814, 342), "Note")
   get exIcon("Note_alert", "triangle-alert", tAccent, lkR(786, 314, 814, 342), "Note")
   hide image "Note_wait"
   hide image "Note_offline"
   hide image "Note_alert"
   put lkLabel("Note_title", lkR(640, 376, 960, 398), "Pick a feed to read", 16, lkColor("ink"), "Note", "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Note_text", lkR(656, 404, 944, 470), \
         "Choose one above, or paste the address of any news feed, then press Read.", 13, lkColor("soft"), "Note", "center") into tObj
end buildReader

-- What a feed's XML looks like, and the four lines that read it
private command buildInside
   local tObj, tTop, tCode, tText, tIndex, tHeight, tLine, tRect
   go card "Inside a Feed"
   set the script of this card to exScript("Inside a Feed/card")
   -- The XML, on a dark panel, with the line a path leads to lit
   put lkBox("Xml_bg", lkR(kLeft, kTop, 664, kBottom), lkColor("code"), 18, empty) into tObj
   lkShadow tObj, 18, 6, 30
   get lkOval("Xml_dot1", lkR(kLeft + 18, kTop + 17, kLeft + 28, kTop + 27), "248,113,113", empty)
   get lkOval("Xml_dot2", lkR(kLeft + 34, kTop + 17, kLeft + 44, kTop + 27), "251,191,36", empty)
   get lkOval("Xml_dot3", lkR(kLeft + 50, kTop + 17, kLeft + 60, kTop + 27), "52,211,153", empty)
   put lkLabel("Xml_caption", lkR(kLeft + 72, kTop + 15, 648, kTop + 31), "a feed, as its site keeps it", 11, "100,116,139", empty) into tObj
   put lkBox("Xml_pick", lkR(kLeft + 10, kTop + 46, 654, kTop + 66), lkMix(lkColor("code"), lkColor("orange"), 0.3), 6, empty) into tObj
   put lkBox("Xml_mark", lkR(kLeft + 10, kTop + 46, kLeft + 13, kTop + 66), lkColor("orange"), 0, empty) into tObj
   put codeField("Xml", lkR(kLeft + 12, kTop + 46, 656, 520), empty, 11, 19, empty) into tObj
   set the margins of tObj to "8,0,8,0"
   set the rect of tObj to kLeft + 12, kTop + 46, 656, 520
   set the dontWrap of tObj to true
   set the htmlText of tObj to xmlHtml(exScript("feed-xml"))
   -- (the lit line: the second item's title, where the path on the right leads)
   put lineOffset("The second story", the text of tObj) into tLine
   put the formattedRect of line tLine of tObj into tRect
   set the rect of graphic "Xml_pick" to kLeft + 10, item 2 of tRect - 1, 654, item 4 of tRect + 1
   set the rect of graphic "Xml_mark" to kLeft + 10, item 2 of tRect - 1, kLeft + 13, item 4 of tRect + 1
   put lkBox("Xml_rule", lkR(kLeft + 20, 536, 644, 537), lkColor("sideLine"), 0, empty) into tObj
   get exIcon("Xml_noteIcon", "info", "125,211,252", lkR(kLeft + 20, 554, kLeft + 36, 570), empty)
   put lkLabel("Xml_note", lkR(kLeft + 48, 553, 640, 600), \
         "Atom feeds keep their stories in /feed/entry, not in /rss/channel/item. The Reader reads those too.", \
         12, lkColor("sideInk"), empty) into tObj
   -- The path to one title
   get lkGroup("Path", lkR(680, kTop, kRight, 252), empty)
   put exPanel("Path_bg", lkR(680, kTop, kRight, 252), "Path") into tObj
   put lkLabel("Path_title", lkR(698, kTop + 18, 982, kTop + 34), "THE PATH TO ONE TITLE", 11, lkColor("orange"), "Path") into tObj
   set the textStyle of tObj to "bold"
   put lkBox("Path_codeBg", lkR(698, kTop + 42, 982, kTop + 74), lkColor("code"), 8, "Path") into tObj
   put codeField("Path_code", lkR(708, kTop + 50, 978, kTop + 70), quote & "/rss/channel/item[2]/title" & quote, 12, 18, "Path") into tObj
   set the dontWrap of tObj to true
   put lkLabel("Path_text", lkR(698, kTop + 86, 982, 240), \
         "Each part is a tag inside the one before it: the channel, its second item, and that item's title. " & \
         "The lit line is where it leads.", 12, lkColor("soft"), "Path") into tObj
   -- The four lines that read a feed, as the Import card's script has them
   get lkGroup("Lines", lkR(680, 268, kRight, kBottom), empty)
   put exPanel("Lines_bg", lkR(680, 268, kRight, kBottom), "Lines") into tObj
   put lkLabel("Lines_title", lkR(698, 286, 982, 302), "FOUR LINES READ IT", 11, lkColor("orange"), "Lines") into tObj
   set the textStyle of tObj to "bold"
   put "put url tURL into tXML" into tCode[1]
   put "The feed's text, from the web." into tText[1]
   put "put revXMLCreateTree(tXML, \" & return & "  false,true,false) into tTree" into tCode[2]
   put "A tree of its XML, and the tree's number." into tText[2]
   put "put revXMLNumberOfChildren(tTree, \" & return & "  " & quote & "/rss/channel" & quote & "," & quote & "item" & quote & ",0) into tTotal" into tCode[3]
   put "How many items the channel has." into tText[3]
   put "put revXMLNodeContents(tTree, \" & return & "  " & quote & "/rss/channel/item[2]/title" & quote & ") into tA" into tCode[4]
   put "The text at a path: here, the second title." into tText[4]
   put 312 into tTop
   repeat with tIndex = 1 to 4
      put lkLabel("Lines_text" & tIndex, lkR(698, tTop, 982, tTop + 16), empty, 12, lkColor("soft"), "Lines") into tObj
      set the htmlText of tObj to "<p><font color=" & quote & lkHex(lkColor("orange")) & quote & "><b>" & tIndex & "</b></font>   " & tText[tIndex] & "</p>"
      put 10 + 17 * the number of lines of tCode[tIndex] into tHeight
      put lkBox("Lines_codeBg" & tIndex, lkR(694, tTop + 20, 986, tTop + 20 + tHeight), lkColor("code"), 8, "Lines") into tObj
      put codeField("Lines_code" & tIndex, lkR(702, tTop + 26, 984, tTop + 20 + tHeight - 2), tCode[tIndex], 11, 17, "Lines") into tObj
      set the dontWrap of tObj to true
      add 20 + tHeight + 12 to tTop
   end repeat
end buildInside

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--RSS Reader: the RSS Demo of OpenXTalk Lite's demos, remastered for OXT-Beyond in 2026
--The original's only credit, the first line of its Import button's script:
-- via theotherbassist, April 2016

--Each card's program is in the scripts of the card and its controls.
--The scripts panel beside the stage shows them (on the wide card, the drawer that the Scripts button opens).

--The mouse wheel scrolls a list that has no scrollbar: a field whose custom property cWheel is true.
--Its thumb, the graphic its custom property cThumb names, shows how far down it is.
on rawKeyDown pKey
   local tField
   if pKey is 65308 or pKey is 65309 then  --the wheel, down or up
      put wheelField() into tField
      if tField is not empty then
         if pKey is 65308 then
            set the vScroll of tField to the vScroll of tField + 48
         else
            set the vScroll of tField to the vScroll of tField - 48
         end if
         showThumb the short name of tField
         dispatch "listScrolled" to this card  --(a card that follows the scroll)
         exit rawKeyDown
      end if
   end if
   pass rawKeyDown
end rawKeyDown

private function wheelField  --the list under the pointer
   local tIndex, tField
   repeat with tIndex = 1 to the number of fields of this card
      put the long id of field tIndex of this card into tField
      if the cWheel of tField is true and the mouseLoc is within the rect of tField then
         return tField
      end if
   end repeat
   return empty
end wheelField

command showThumb pField  --as tall as the part of the list shown, as far down as it is scrolled
   local tThumb, tRoom, tShown, tHeight, tTop
   if there is not a field pField or the cThumb of field pField is empty then
      exit showThumb
   end if
   put the long id of graphic (the cThumb of field pField) into tThumb
   put the formattedHeight of field pField - the height of field pField into tRoom
   if tRoom <= 4 then
      hide tThumb
      exit showThumb
   end if
   put the height of field pField - 8 into tShown
   put max(24, round(tShown * tShown / (tShown + tRoom))) into tHeight
   put the top of field pField + 4 + round((tShown - tHeight) * min(1, the vScroll of field pField / tRoom)) into tTop
   set the rect of tThumb to item 1 of the rect of tThumb, tTop, item 3 of the rect of tThumb, tTop + tHeight
   show tThumb
end showThumb
@*/

/*@ Import/Import
-- via theotherbassist, April 2016
--(Remastered for OXT-Beyond, 2026: the lines marked "(2026)" are new or changed, and say why)

on mouseUp
   local tURL, tCurrent, x, tTREE, tTotal, tTitle, tA, tContentArray, tXML, tContent  --(2026) declared, for strict compilation
   put fld "feed" into tURL
   put 1 into tCurrent
   put 1 into x
   --(2026) was: put revXMLCreateTreeFromFile(tURL, false, true, false) into tTREE
   --that reads a file, or an http address, but not an https one, and the feeds are all https now:
   --so url fetches the feed, and revXMLCreateTree makes the tree from its text
   put url tURL into tXML
   put revXMLCreateTree(tXML,false,true,false) into tTREE
   put revXMLNumberOfChildren(tTree, "/rss/channel/", "item", 0) into tTotal
   if tTotal is not an integer or tTotal < 1 then  --(2026) no feed came: the loop below would never end
      answer "Sorry, no feed came from that address. Check it, and that this computer is online" && \
            "(in a browser, the feed's site must allow other pages to read it)." with "OK" titled "Import"
      exit mouseUp
   end if

   repeat
   put "/rss/channel/item[" & tCurrent & "]/title" into tTitle
   put revXMLNodeContents(tTREE, tTitle) into tA
   put tA & return into line 1 of tContentArray[x]
   if tTotal <= tCurrent then  --(2026) was "<": that read one item past the last, and showed an error
      revXMLDeleteAllTrees
      --(2026) was: combine tContentArray using return
      --combine puts the elements in the order of their keys as text (1, 10, 11, ... 19, 2, 20), so the
      --tenth title came second: this puts them in the order the feed has them, as combine would join them
      repeat with x = 1 to tTotal
         put tContentArray[x] after tContent
         if x < tTotal then put return after tContent
      end repeat
      put tContent into tContentArray  --(2026) the titles, joined, where combine left them
      set the unicodetext of fld "content" to uniEncode(tContentArray,"UTF8")
      --(2026) the newer way to say the same: put textDecode(tContent, "UTF-8") into fld "content"
      showThumb "content"  --(2026) the thumb beside the list, which the wheel scrolls
      exit repeat
   else
      add 1 to x
      add 1 to tCurrent
      next repeat
      end if
   end repeat

end mouseUp
@*/

/*@ Import/Clear
on mouseUp
   put empty into fld "content"
   showThumb "content"  --(2026) no list, no thumb
end mouseUp
@*/

/*@ Reader/card
--The Reader: pick a feed, read its stories, open one in your browser.
--It reads a feed as the Import card does (theotherbassist's script, 2016).
--url fetches the feed's text, and revXMLCreateTree makes a tree of it.
--revXMLNumberOfChildren counts its items, and revXMLNodeContents reads each one's title by its path:
--/rss/channel/item[3]/title.
--This card reads each item's date, link and summary too, and Atom feeds as well.

constant kMonths = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"
constant kMost = 50  --stories at most
--Time zones a feed may write as letters, and as numbers
constant kZones = "GMT +0000,UTC +0000,UT +0000,Z +0000,EST -0500,EDT -0400,CST -0600,CDT -0500,MST -0700,MDT -0600,PST -0800,PDT -0700"
--HTML's names for some letters, and their numbers (&amp; last: "&amp;lt;" means the text "&lt;")
constant kEntities = "nbsp 32,quot 34,apos 39,lt 60,gt 62,lsquo 8216,rsquo 8217,ldquo 8220,rdquo 8221,ndash 8211,mdash 8212,hellip 8230,amp 38"

local sBusy  --true while a feed is on its way
local sWaiting  --a feed that came while another card was in front

on preOpenCard
   if sWaiting is not empty then
      showFeed sWaiting
      put empty into sWaiting
   else if the number of lines of field "Stories" is 0 and not sBusy then
      showNote "rss", "Pick a feed to read", "Choose one above, or paste the address of any news feed, then press Read."
   end if
   pass preOpenCard
end preOpenCard

on returnInField  --Return in the address reads the feed
   if the short name of the target is "URL" then
      readFeed the text of field "URL"
   else
      pass returnInField
   end if
end returnInField

on enterInField
   returnInField
end enterInField

on arrowKey pKey  --up and down go from story to story
   if the selectedField is empty and (pKey is "up" or pKey is "down") and the cShown of me is an integer then
      if pKey is "up" then
         showStory the cShown of me - 1
      else
         showStory the cShown of me + 1
      end if
   else
      pass arrowKey
   end if
end arrowKey

-- Fetches a feed, and lists its stories
command readFeed pURL
   local tXML, tProblem
   if sBusy then exit readFeed  --(one feed at a time)
   put word 1 to -1 of pURL into pURL
   if pURL is empty then
      showNote "rss", "Which feed?", "Pick one above, or paste the address of a feed into the box."
      exit readFeed
   end if
   if "://" is not in pURL and not (pURL begins with "file:") then
      put "https://" before pURL  --(an address typed without its https://)
   end if
   put pURL into field "URL"
   markFeed pURL
   clearStories
   showNote "wait", "Reading the feed" & numToCodepoint(8230), pURL
   put true into sBusy
   put url pURL into tXML  --this waits until the feed has come, or has not
   put the result into tProblem
   put false into sBusy
   --(while it waited, the window may have gone to another card: the stories wait for this one)
   set the defaultStack to the short name of the owner of me
   if the long id of this card is not the long id of me then
      put tXML into sWaiting
      exit readFeed
   end if
   if tXML is empty or tProblem is not empty then
      showNote "offline", "The feed did not come", whyNot(tProblem)
      exit readFeed
   end if
   showFeed tXML
end readFeed

-- Why a feed may not come, in words
function whyNot pProblem
   if the platform is "HTML5" then
      return "A web page may read a feed from another site only if that site allows it, and this one does not." && \
            "Try another feed, or open RSS Reader in the desktop IDE, which reads any feed."
   end if
   if pProblem is empty then
      put "nothing came back" into pProblem
   end if
   return "This computer may be offline, or the site did not answer (" & pProblem & ")." && \
         "Check the address, or try another feed."
end whyNot

-- Lists the stories of a feed's text: a tree of its XML, its items counted, and each one read by its path
command showFeed pXML
   local tTree, tHead, tParent, tChild, tCount, tIndex, tPath, tStories, tLink
   put revXMLCreateTree(pXML, false, true, false) into tTree  --(the feed's bytes, as url gives them)
   if tTree is an integer and revXMLRootNode(tTree) is empty then  --(text that is not XML at all)
      revXMLDeleteTree tTree
      put "xmlerr" into tTree
   end if
   if tTree begins with "xmlerr" then
      showNote "alert", "That is not a feed", "The address answered with a page, not a feed. A site's feed often has an address that ends in /rss or /feed."
      exit showFeed
   end if
   switch revXMLRootNode(tTree)
      case "rss"  --RSS 2.0, as the Import card reads it: /rss/channel/item[1]
         put "/rss/channel" into tParent
         put "item" into tChild
         put "/rss/channel/title" into tHead
         break
      case "feed"  --Atom: /feed/entry[1]
         put "/feed" into tParent
         put "entry" into tChild
         put "/feed/title" into tHead
         break
      case "RDF"  --RSS 1.0, <rdf:RDF>: revXML names a tag without its prefix, so /RDF/item[1]
         put "/RDF" into tParent
         put "item" into tChild
         put "/RDF/channel/title" into tHead
         break
   end switch
   if tParent is not empty then
      put revXMLNumberOfChildren(tTree, tParent, tChild, 0) into tCount
   end if
   if tCount is not an integer or tCount < 1 then
      revXMLDeleteTree tTree
      showNote "alert", "No stories there", "The address answered with XML, but there are no stories in it."
      exit showFeed
   end if
   repeat with tIndex = 1 to min(tCount, kMost)
      put tParent & "/" & tChild & "[" & tIndex & "]" into tPath
      put textOfHtml(nodeText(tTree, tPath & "/title")) into tStories[tIndex]["title"]
      put firstOf(tTree, tPath, "pubDate,updated,published,date") into tStories[tIndex]["date"]  --(date: <dc:date>)
      put textOfHtml(firstOf(tTree, tPath, "description,summary,content")) into tStories[tIndex]["summary"]
      put word 1 to -1 of firstOf(tTree, tPath, "link,guid") into tLink
      if tLink is empty then
         put nodeAttribute(tTree, tPath & "/link", "href") into tLink  --(Atom's: <link href="..."/>)
      end if
      put tLink into tStories[tIndex]["link"]
   end repeat
   set the cChannel of me to textOfHtml(nodeText(tTree, tHead))
   revXMLDeleteTree tTree
   set the cStories of me to tStories
   listStories
   showStory 1
end showFeed

-- The text at a path in the tree, or empty if the feed has nothing there
function nodeText pTree, pPath
   local tText
   put revXMLNodeContents(pTree, pPath) into tText
   if tText begins with "xmlerr" then
      return empty
   end if
   return textDecode(tText, "UTF-8")  --(revXML gives its text as UTF-8)
end nodeText

-- The text of the first of some tags an item has: feeds name the same thing differently
function firstOf pTree, pPath, pTags
   local tTag, tText
   repeat for each item tTag in pTags
      put nodeText(pTree, pPath & "/" & tTag) into tText
      if tText is not empty then
         return tText
      end if
   end repeat
   return empty
end firstOf

function nodeAttribute pTree, pPath, pName
   local tText
   put revXMLAttribute(pTree, pPath, pName) into tText
   if tText begins with "xmlerr" then
      return empty
   end if
   return textDecode(tText, "UTF-8")
end nodeAttribute

-- The words of a bit of HTML: its tags out, its entities (&amp; &#8217;) made letters
function textOfHtml pHtml
   local tText, tWhole, tHex, tCode, tEntity
   put replaceText(pHtml, "<[^>]*>", " ") into tText  --a tag becomes a space
   repeat while matchText(tText, "(&#([xX]?)([0-9a-fA-F]{1,6});)", tWhole, tHex, tCode)  --a letter by its number
      if tHex is not empty then
         put baseConvert(tCode, 16, 10) into tCode
      end if
      if tCode is an integer and tCode >= 32 and tCode <= 1114111 and (tCode < 55296 or tCode > 57343) then
         replace tWhole with numToCodepoint(tCode) in tText
      else
         replace tWhole with space in tText
      end if
   end repeat
   repeat for each item tEntity in kEntities  --a letter by its name
      replace "&" & word 1 of tEntity & ";" with numToCodepoint(word 2 of tEntity) in tText
   end repeat
   return word 1 to -1 of replaceText(tText, "\s+", " ")  --one space between words
end textOfHtml

-- When a story came, in words: "40 min ago", "5 h ago", or its day.
-- RSS writes a date "Sat, 18 Oct 2026 10:15:00 GMT", and Atom "2026-10-18T10:15:00Z"
function friendlyDate pDate
   local tWhen, tZone, tAgo
   put word 1 to -1 of pDate into tWhen
   if char 5 of tWhen is "-" and char 8 of tWhen is "-" then
      put rssDate(tWhen) into tWhen  --(Atom's way, written RSS's way)
   end if
   if the last char of word 1 of tWhen is not comma then
      put "Mon, " before tWhen  --(convert wants a day of the week first, but does not check it)
   end if
   repeat for each item tZone in kZones  --(convert wants a time zone as a number)
      if word -1 of tWhen is word 1 of tZone then
         put word 2 of tZone into word -1 of tWhen
         exit repeat
      end if
   end repeat
   if matchText(word -2 of tWhen, "^[0-9]{1,2}:[0-9]{2}$") then
      put ":00" after word -2 of tWhen  --(and its seconds)
   end if
   convert tWhen from internet date to seconds
   if tWhen is not an integer then  --(a date convert cannot read: its day, as it is written)
      if char 5 of pDate is "-" then
         return char 1 to 10 of pDate
      end if
      return word 2 to 4 of pDate
   end if
   put the seconds - tWhen into tAgo
   if tAgo < 60 then
      return "just now"
   else if tAgo < 3600 then
      return tAgo div 60 && "min ago"
   else if tAgo < 86400 then
      return tAgo div 3600 && "h ago"
   else if tAgo < 172800 then
      return "yesterday"
   end if
   convert tWhen to dateItems
   return item 3 of tWhen && word (item 2 of tWhen) of kMonths && item 1 of tWhen
end friendlyDate

-- An Atom date in RSS's way: "2026-10-18T10:15:00+01:00" is "18 Oct 2026 10:15:00 +0100"
function rssDate pDate
   local tYear, tMonth, tDay, tTime, tHour, tMinute, tSeconds, tSecond, tZoneHours, tZoneMinutes, tZone, tPattern
   put "^([0-9]{4})-([0-9]{2})-([0-9]{2})" into tPattern  --a day: 2026-10-18
   put "(T([0-9]{2}):([0-9]{2})" after tPattern  --then perhaps a time: T10:15
   put "(:([0-9]{2}))?)?" after tPattern  --perhaps with seconds: :00
   if not matchText(pDate, tPattern, tYear, tMonth, tDay, tTime, tHour, tMinute, tSeconds, tSecond) then
      return pDate
   end if
   if tHour is empty then
      put "00" into tHour
      put "00" into tMinute
   end if
   if tSecond is empty then
      put "00" into tSecond
   end if
   if matchText(pDate, "([+-][0-9]{2}):?([0-9]{2})$", tZoneHours, tZoneMinutes) then
      put tZoneHours & tZoneMinutes into tZone
   else
      put "+0000" into tZone  --(Z, or none: the time is UTC)
   end if
   return (tDay + 0) && word (tMonth + 0) of kMonths && tYear && tHour & ":" & tMinute & ":" & tSecond && tZone
end rssDate

-- The list: each story's title, and under it when it came
command listStories
   local tStories, tCount, tIndex, tHtml, tWhen
   put the cStories of me into tStories
   put the number of elements of tStories into tCount
   repeat with tIndex = 1 to tCount
      put friendlyDate(tStories[tIndex]["date"]) into tWhen
      if tWhen is empty then
         put the cChannel of me into tWhen
      end if
      put "<p><b>" & htmlOf(tStories[tIndex]["title"]) & "</b></p>" & \
            "<p><font size=" & quote & "11" & quote & " color=" & quote & "#94a3b8" & quote & ">" & htmlOf(tWhen) & "</font></p>" after tHtml
   end repeat
   set the htmlText of field "Stories" to tHtml
   set the visible of group "Placeholder" to (tCount is 0)
   repeat with tIndex = 1 to tCount
      set the spaceAbove of line (2 * tIndex - 1) of field "Stories" to 6
      set the spaceBelow of line (2 * tIndex) of field "Stories" to 8
   end repeat
   set the vScroll of field "Stories" to 0
   showThumb "Stories"
   put "<b>" & htmlOf(the cChannel of me) & "</b><font color=" & quote & "#94a3b8" & quote & ">  " & \
         numToCodepoint(183) & "  " & tCount && "stories</font>" into tHtml
   set the htmlText of field "ListHead" to tHtml
end listStories

function htmlOf pText
   replace "&" with "&amp;" in pText
   replace "<" with "&lt;" in pText
   replace ">" with "&gt;" in pText
   return pText
end htmlOf

-- A story's title, when it came, where it is and what it says, on the panel at the right
command showStory pIndex
   local tStories, tLink, tTop, tText
   put the cStories of me into tStories
   if pIndex is not an integer or tStories[pIndex] is not an array then
      exit showStory
   end if
   set the cShown of me to pIndex
   put toUpper(the cChannel of me) into field "Source"
   put tStories[pIndex]["title"] into field "Headline"
   put tStories[pIndex]["link"] into tLink
   set the itemDelimiter to slash
   put friendlyDate(tStories[pIndex]["date"]) into field "When"
   if item 3 of tLink is not empty then  --the site the link goes to
      if field "When" is not empty then
         put "  " & numToCodepoint(183) & "  " after field "When"
      end if
      put replaceText(item 3 of tLink, "^www\.", "") after field "When"
   end if
   set the itemDelimiter to comma
   put tStories[pIndex]["summary"] into tText
   if the number of chars of tText > 600 then  --(a long one: its first words, and an ellipsis)
      put char 1 to 600 of tText into tText
      put word 1 to -2 of tText & numToCodepoint(8230) into tText
   end if
   put tText into field "Summary"
   -- (the title takes the lines it needs, and the rest follows it)
   set the height of field "Headline" to min(the formattedHeight of field "Headline", 108)
   set the top of field "Headline" to the bottom of field "Source" + 4
   set the top of field "When" to the bottom of field "Headline" + 4
   put the bottom of field "When" + 10 into tTop
   set the rect of field "Summary" to the left of field "Summary", tTop, the right of field "Summary", the top of group "Open" - 12
   -- (a summary too long for its room loses words at its end, and ends with an ellipsis)
   repeat while the formattedHeight of field "Summary" > the height of field "Summary" and the number of words of field "Summary" > 1
      put word 1 to -2 of field "Summary" & numToCodepoint(8230) into field "Summary"
   end repeat
   set the cLink of group "Open" to tLink
   if tLink begins with "http" then
      set the blendLevel of group "Open" to 0
   else
      set the blendLevel of group "Open" to 60
   end if
   hide group "Note"
   show group "Story"
   showPick true
end showStory

-- The tint behind the story shown, in the list; pScroll scrolls the list to it
command showPick pScroll
   local tIndex, tRect, tTop, tBottom
   put the cShown of me into tIndex
   if tIndex is not an integer or the number of lines of field "Stories" < 2 * tIndex then
      hide graphic "Pick"
      exit showPick
   end if
   put the formattedRect of line (2 * tIndex - 1) to (2 * tIndex) of field "Stories" into tRect
   put item 2 of tRect - 6 into tTop
   put item 4 of tRect + 6 into tBottom
   if pScroll is true and tTop < the top of field "Stories" then
      set the vScroll of field "Stories" to the vScroll of field "Stories" - (the top of field "Stories" - tTop) - 4
      showThumb "Stories"
      showPick false
      exit showPick
   else if pScroll is true and tBottom > the bottom of field "Stories" then
      set the vScroll of field "Stories" to the vScroll of field "Stories" + (tBottom - the bottom of field "Stories") + 4
      showThumb "Stories"
      showPick false
      exit showPick
   end if
   set the rect of graphic "Pick" to the left of field "Stories" + 2, tTop, the right of field "Stories" - 10, tBottom
   show graphic "Pick"
end showPick

on listScrolled  --the wheel scrolled the list: the tint follows its story
   showPick false
end listScrolled

-- A note on the panel at the right, in place of a story: an icon, a title, a line or two
command showNote pIcon, pTitle, pText
   local tName, tTop
   repeat for each item tName in "rss,wait,offline,alert"
      set the visible of image ("Note_" & tName) to (tName is pIcon)
   end repeat
   put pTitle into field "Note_title"
   put pText into field "Note_text"
   set the height of field "Note_text" to the formattedHeight of field "Note_text" + 4
   -- (all of it in the middle of the panel, up and down)
   put item 2 of the loc of graphic "Panel" - (64 + 16 + 24 + 6 + the height of field "Note_text") div 2 into tTop
   set the top of graphic "Note_circle" to tTop
   repeat for each item tName in "rss,wait,offline,alert"
      set the loc of image ("Note_" & tName) to the loc of graphic "Note_circle"
   end repeat
   set the top of field "Note_title" to tTop + 64 + 16 - 4
   set the top of field "Note_text" to the bottom of field "Note_title" + 6
   hide group "Story"
   show group "Note"
end showNote

-- No stories: an empty list, before a feed is read
command clearStories
   put empty into field "Stories"
   show group "Placeholder"
   set the cStories of me to empty
   set the cShown of me to empty
   hide graphic "Pick"
   showThumb "Stories"
   put "Stories" into field "ListHead"
end clearStories

-- Lights the button of the feed being read, if it is one of them
command markFeed pURL
   local tIndex, tButton
   repeat with tIndex = 1 to the number of groups of group "Feeds"
      put the long id of group tIndex of group "Feeds" into tButton
      if the cURL of tButton is pURL then
         set the cRest of tButton to the cPicked of tButton
         set the foregroundColor of graphic 1 of tButton to the cPickedLine of tButton
      else
         set the cRest of tButton to "255,255,255"
         set the foregroundColor of graphic 1 of tButton to the cLine of tButton
      end if
      set the backgroundColor of graphic 1 of tButton to the cRest of tButton
   end repeat
end markFeed
@*/

/*@ Reader/Feeds
on mouseUp  --a feed's button: its address is its custom property cURL
   local tButton
   put the long id of the target into tButton
   if the cURL of tButton is empty then
      put the long owner of the target into tButton  --(the click was on the button's label or icon)
   end if
   if the cURL of tButton is not empty then
      readFeed the cURL of tButton
   end if
end mouseUp
@*/

/*@ Reader/Read
on mouseUp
   readFeed the text of field "URL"
end mouseUp
@*/

/*@ Reader/Stories
on mouseUp  --a click on a story shows it
   local tLine
   put word 2 of the clickLine into tLine
   if tLine is an integer then
      showStory (tLine + 1) div 2  --each story is two lines: its title, and when it came
   end if
end mouseUp
@*/

/*@ Reader/Open
on mouseUp  --the whole story, in the browser
   local tLink
   put the cLink of me into tLink
   if tLink begins with "http://" or tLink begins with "https://" then  --(only a web page: a feed's link could be anything)
      launch url tLink
   end if
end mouseUp
@*/

/*@ Inside a Feed/card
on preOpenCard  --the code in a code font: the first of these that the computer has
   local tFont, tIndex, tError
   if the environment is "development" and "Source Code Pro" is not among the lines of the fontNames then
      try  --(the IDE carries it for its Script Editor, as the scripts panel knows)
         start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
      catch tError
      end try
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then
         set the textFont of field "Xml" to tFont
         set the textFont of field "Path_code" to tFont
         repeat with tIndex = 1 to 4
            set the textFont of field ("Lines_code" & tIndex) to tFont
         end repeat
         exit repeat
      end if
   end repeat
   pass preOpenCard
end preOpenCard
@*/

/*@ feed-xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>A news site</title>
    <link>https://news.example.com/</link>
    <item>
      <title>The first story</title>
      <link>https://news.example.com/1</link>
      <pubDate>Sat, 17 Oct 2026 09:30:00 GMT</pubDate>
      <description>What it is about.</description>
    </item>
    <item>
      <title>The second story</title>
      <link>https://news.example.com/2</link>
      <pubDate>Sat, 17 Oct 2026 08:05:00 GMT</pubDate>
      <description>What this one says.</description>
    </item>
  </channel>
</rss>
@*/
