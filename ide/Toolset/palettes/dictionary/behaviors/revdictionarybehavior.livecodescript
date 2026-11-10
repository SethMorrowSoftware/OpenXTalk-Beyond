script "revDictionaryBehavior" with behavior "revPaletteBehavior"
-- The dictionary starts to hide elements at lower than 992 pixels
-- *TODO* Tweak the CSS to rearrange things appropriately
constant kDictionaryMinWidth = 992

-- Some browsers have a built-in scrollbar. Add a fudge factor to
-- take this into account
constant kScrollbarFudge = 18

-- The background colour for the dictionary stack
constant kBackColor = "Gray75"

local sTab, sEntry
-- OXT-Beyond: true in the dark appearance (dictReadAppearance); the
-- pending look again at macOS's appearance after a switch, and how many
-- looks are left
local sDark, sAppearanceMsg, sAppearanceTries
on setAsBehavior pTarget
   dispatch "setAsBehavior" to stack revIDEFrameBehavior() with the long id of this me
   set the behavior of pTarget to the long id of this me
end setAsBehavior

on openStack
   local tMinWidth
   put kDictionaryMinWidth + kScrollbarFudge into tMinWidth
   lock screen
   --Force the browser to actually resize
   set the rect of widget "Dictionary" of me to 0,0,0,0
   set the javascripthandlers of widget "Dictionary" of me to "linkClicked" & return & "showUpgradeOptions"
   set the width of me to tMinWidth
   set the minWidth of me to tMinWidth
   set the title of me to "Dictionary"
   -- set the backColor of me to kBackColor
   if sTab is empty then
      put "api" into sTab
   end if
   -- OXT-Beyond: the pages follow the desktop between light and dark
   get dictReadAppearance()
   if there is a stack "revIDELibrary" then
      revIDESubscribe "ideSystemAppearanceChanged"
   end if
   revIDEGenerateDictionaryHTML sTab, sEntry["library"], sEntry["entry"], sEntry["type"]
   put empty into sEntry
   showTab sTab
   set the cantModify of me to true
   unlock screen
   -- OXT-Beyond: the page fills the window once it is open
   send "dictFitPage" to me in 0 milliseconds
end openStack

on resizeStack
   set the rect of widget "Dictionary" of me to the contentRect of me
end resizeStack

-- OXT-Beyond: the browser widget is set to 0,0,0,0 as the window opens,
-- and was given the window's contentRect only by a resizeStack, which
-- comes when the width set above changes the window's, or by
-- browserNavigateComplete. A window that opened at the width it already
-- had (where it was last, as the IDE keeps a palette's place) got neither
-- on Windows, and its page stayed a point at the top left: the Dictionary
-- was blank, the window's own colour (the IDE tour's 13-dictionary in the
-- dark, rc.6.11 to rc.6.15; its widget read 0,0,1,1, and a resizeStack
-- drew the page). The page is now fitted once the window is open. A
-- window that got a resizeStack is given the same rect again
on dictFitPage
   if the mode of me is not 0 then
      resizeStack
   end if
end dictFitPage

on showAPIs
   showTab "api"
end showAPIs

on showGuides
   showTab "guide"
end showGuides

on showTab pTab
   hiliteFrameItem pTab
   put pTab into sTab
   -- OXT-Beyond: makes the page and its data first if they are missing
   -- (with the text dictionary chosen in Preferences they never were)
   revIDEEnsureBrowserDictionary pTab
   local tUrl
   put "file://" & revIDEGetDictionaryUrl(pTab) into tUrl
   replace " " with "%20" in tUrl
   -- (the page puts itself in the dark before it is first drawn)
   if sDark is true then
      put "?appearance=dark" after tUrl
   end if
   -- (in the web IDE it cannot read that, and reads the IDE's page)
   dictMarkWebPage
   set the url of widget "Dictionary" of me to tUrl
end showTab

on browserNavigateComplete
   -- OXT-Beyond: in the web IDE a page that has loaded is given the
   -- appearance as a switch gives it too, so one that could not read the
   -- IDE's page as it opened (dictMarkWebPage) is not left light
   if the platform is "HTML5" then
      dictApplyAppearance
   end if
   if sEntry is not empty then
      do "goEntryName('" & sEntry["library"] & "','" & sEntry["entry"] & "','" & sEntry["type"] & "')" in widget "Dictionary" of me
      put empty into sEntry
   end if
   if the mode of me is not 0 then
      resizeStack
   end if
end browserNavigateComplete

on navigateToEntry pLibrary, pEntry, pType
   put pLibrary into sEntry["library"]
   put pEntry into sEntry["entry"]
   put pType into sEntry["type"]
   if the mode of me is not 0 then
      browserNavigateComplete
   end if
   toplevel me
end navigateToEntry

on linkClicked pLink
   launch url pLink
end linkClicked

on showUpgradeOptions pEdition, pDisplayName
   put urlEncode(pDisplayName) into pDisplayName
   replace "+" with "%20" in pDisplayName

   launch url revEnvironmentEditionProperty("edition_external_url", pEdition) & \
         "?utm_source=ide&utm_medium=docs&utm_campaign="&pDisplayName
end showUpgradeOptions

# bug 17819 enable cmd+c in dictionary
on commandKeyDown pWhich
   switch pWhich
      case "A"
         -- trap Cmd + A for select all
      case "C"
         -- trap Cmd + C for copy
         break
      case "W"
         close me
         break
      default
         pass commandKeyDown
   end switch
end commandKeyDown

################################################################################
#
# OXT-Beyond: light and dark
#

-- Reads the desktop's appearance, as the Tools palette reads it (revTools'
-- tmGenerate): macOS's and Windows' systemAppearance, and on Linux, where
-- the systemAppearance is always light, how dark the GTK theme's window
-- colour is. True when it changed. The stack's own colour is put back.
private function dictReadAppearance
   local tDark, tSaved, tSum, tError
   put false into tDark
   try
      if the platform contains "linux" then
         put the backgroundColor of me into tSaved
         lock screen
         set the backgroundColor of me to empty
         put the effective backgroundColor of me into tSum
         set the backgroundColor of me to tSaved
         unlock screen
         if item 1 of tSum is a number and item 3 of tSum is a number then
            put item 1 of tSum + item 2 of tSum + item 3 of tSum < 234 into tDark
         end if
      else
         put the systemAppearance is "dark" into tDark
      end if
   catch tError
      -- (an engine without the property: light, as before)
   end try
   if tDark is (sDark is true) then
      return false
   end if
   put tDark into sDark
   return true
end dictReadAppearance

-- The page in the browser in the appearance read, after a switch: its
-- html element has the class oxt-dark in the dark (html_viewer/css/
-- oxt-dark.css), so a switch needs no new page and loses no place. (A page
-- as it opens takes it from its URL, ?appearance=dark: showTab. Asked as
-- the page has just loaded, the browser widget on Windows answered
-- nothing, which it refuses as a script error. In the web IDE, where the
-- URL cannot say it, the page is asked as it has loaded:
-- browserNavigateComplete.)
private command dictApplyAppearance
   local tError
   dictMarkWebPage
   if there is not a widget "Dictionary" of me then
      exit dictApplyAppearance
   end if
   try
      -- (the script answers a string: the browser widget refuses any
      -- other answer, as a script error)
      do "document.documentElement.classList.toggle('oxt-dark', " & (sDark is true) & "); 'ok'" in widget "Dictionary" of me
   catch tError
   end try
end dictApplyAppearance

-- In the web IDE the page cannot take the dark from its URL: the web
-- engine's browser widget shows a file from an object URL, which carries
-- no "?appearance=dark" (em-browser.js, _fileOf), so in a dark browser the
-- page opened light, white in the dark IDE (0.2.7-rc.6.10 to 0.2.7). There
-- the appearance read is said on the IDE's own page, which holds the
-- Dictionary's in a frame, and the page reads it as it opens (html_viewer's
-- templates), before it is first drawn. It is said again at each switch,
-- for the next page
private command dictMarkWebPage
   local tAppearance, tError
   if the platform is not "HTML5" then
      exit dictMarkWebPage
   end if
   if sDark is true then
      put "dark" into tAppearance
   else
      put "light" into tAppearance
   end if
   try
      do "document.documentElement.setAttribute('data-oxt-dictionary-appearance', '" & tAppearance & "'); 'ok'" as "JavaScript"
   catch tError
   end try
end dictMarkWebPage

-- On macOS the systemAppearance comes from the user defaults, which can
-- still hold the old appearance when the switch is announced: it is read
-- again every 300 milliseconds, ten times, until it has changed (as the
-- Tools palette does, tmRecheckAppearance)
on ideSystemAppearanceChanged
   if the mode of me is 0 then
      exit ideSystemAppearanceChanged
   end if
   if sAppearanceMsg is not empty then
      cancel sAppearanceMsg
      put empty into sAppearanceMsg
   end if
   put 10 into sAppearanceTries
   dictRecheckAppearance
end ideSystemAppearanceChanged

on dictRecheckAppearance
   put empty into sAppearanceMsg
   if the mode of me is 0 then
      exit dictRecheckAppearance
   end if
   if dictReadAppearance() then
      dictApplyAppearance
      exit dictRecheckAppearance
   end if
   subtract 1 from sAppearanceTries
   if sAppearanceTries > 0 then
      send "dictRecheckAppearance" to me in 300 milliseconds
      put the result into sAppearanceMsg
   end if
end dictRecheckAppearance
