script "revAbout"
-- OXT-Beyond: the About window, in the look of Home and Learn.
--
-- Help > About (revMenubar's tOpenAbout) opens it: a dark header with
-- the mark, the version, the release's name, the build and the engine,
-- and a Copy button for all of them; a white panel with the IDE's about
-- text (about.dat, the same file the classic window reads) or the
-- licences; and Release Notes, Licences and Close at its foot. It is
-- drawn by revLearnKit, which is its behavior.
--
-- The classic window (palettes/about.oxtstack) stays as it was: with the
-- Option (Alt) key down, or when this window cannot open, Help > About
-- opens it. The licences shown here are read from that stack's own
-- buttons each time, so the two never disagree, and the stack is taken
-- out of memory again unless it is open. This window changes no file.
--
-- It is a script-only stack, so it keeps no controls: this script builds
-- them when it opens. Its name begins with "rev", so the IDE treats it as
-- one of its own windows.

constant kWidth = 640
constant kHeight = 500
constant kHeroHeight = 156
constant kFootHeight = 68
constant kPad = 28
constant kClassicStack = "aboutstack"

-- What the panel shows: "about", "licences" or "licence"
local sView
-- The licences, by number: their names, and each one's text
local sLicNames, sLicTexts
-- The version line Copy puts on the clipboard
local sVersionText

################################################################################
#
# Opening and closing
#

-- Opens the window, or brings it to the front
command revAboutShow
   if the mode of me is 0 then
      put "about" into sView
      modeless me
   else
      go me
   end if
end revAboutShow

on preOpenStack
   abUseKit
   abBuild
   abPlace
   abShowView sView
   -- (a script-only stack is made invisible when it is loaded)
   show me
end preOpenStack

on openStack
   lkStartTicking
   lkEnter "side"
end openStack

on closeStack
   lkStopTicking
end closeStack

on returnKey
   close me
end returnKey

on enterKey
   close me
end enterKey

-- Escape closes it too
on rawKeyDown pKey
   if pKey is 65307 then
      close me
   else
      pass rawKeyDown
   end if
end rawKeyDown

-- The kit is this stack's behavior (see revLearnKit)
private command abUseKit
   local tKit
   if the behavior of me is not empty then
      exit abUseKit
   end if
   if there is no stack "revLearnKit" then
      put abToolset() & "/palettes/learn/revlearnkit.livecodescript" into tKit
      -- (naming the file loads the stack)
      get the short name of stack tKit
   end if
   set the behavior of me to the long id of stack "revLearnKit"
end abUseKit

-- The IDE's Toolset folder and its own folder (where .version is), from
-- this stack's file: the same in a source tree, an installed IDE and the
-- web IDE
private function abToolset
   set the itemDelimiter to slash
   return item 1 to -4 of the filename of me
end abToolset

private function abRoot
   set the itemDelimiter to slash
   return item 1 to -5 of the filename of me
end abRoot

-- In the middle of the screen, a little above it
private command abPlace
   local tScreen, tError
   put the screenRect into tScreen
   set the rect of me to 0, 0, kWidth, kHeight
   set the loc of me to (item 1 of tScreen + item 3 of tScreen) div 2, \
         max(item 2 of tScreen + kHeight div 2 + 30, (item 2 of tScreen + item 4 of tScreen) div 2 - 20)
   if there is a stack "revWebIDELibrary" then
      try
         revWebIDEKeepOnPage the long id of me, empty, true
      catch tError
      end try
   end if
end abPlace

################################################################################
#
# What it says
#

-- The first line of a file of the IDE's own folder, or empty
private function abFileLine pName
   local tFile
   put abRoot() & "/" & pName into tFile
   if there is no file tFile then
      return empty
   end if
   return word 1 to -1 of line 1 of textDecode(url ("binfile:" & tFile), "utf-8")
end abFileLine

-- about.dat: its first line is the program's name, and the rest the text,
-- with "%" for each line break and "<ln>" before a link
private function abAboutData
   local tFile
   put abRoot() & "/about.dat" into tFile
   if there is no file tFile then
      return "OXT-Beyond"
   end if
   return textDecode(url ("binfile:" & tFile), "utf-8")
end abAboutData

private function abName
   local tName
   put line 1 of abAboutData() into tName
   set the itemDelimiter to "%"
   put word 1 to -1 of item 1 of tName into tName
   if tName is empty then
      put "OXT-Beyond" into tName
   end if
   return tName
end abName

-- The about text as htmlText: a heading for a line that ends in a colon
-- or stands alone between empty lines, a bullet for "- ", and a link for
-- a line with "<ln>"
private function abAboutHtml
   local tText, tLines, tLine, tIndex, tHtml, tWord, tAccent
   put abAboutData() into tText
   replace return with empty in tText
   replace "%" with return in tText
   delete line 1 of tText
   put tText into tLines
   put lkHex(lkColor("ink")) into tAccent
   repeat with tIndex = 1 to the number of lines of tLines
      put line tIndex of tLines into tLine
      if tLine contains "<ln>" then
         replace "<ln>" with empty in tLine
         put word 1 to -1 of tLine into tWord
         put "<p><a href=" & quote & lkEscape(tWord) & quote & ">" & lkEscape(tWord) & "</a></p>" after tHtml
      else if tLine begins with "- " then
         put "<p>" & numToCodepoint(8226) & "  " & lkEscape(char 3 to -1 of tLine) & "</p>" after tHtml
      else if tLine begins with "  " then
         put "<p>   " & lkEscape(word 1 to -1 of tLine) & "</p>" after tHtml
      else if tLine is not empty and (the last char of tLine is ":" or (line tIndex - 1 of tLines is empty \
            and the number of words of tLine <= 2 and the last char of tLine is not among the items of ".,;!?")) then
         put "<p><font color=" & quote & tAccent & quote & "><b>" & lkEscape(tLine) & "</b></font></p>" after tHtml
      else
         put "<p>" & lkEscape(tLine) & "</p>" after tHtml
      end if
   end repeat
   return tHtml
end abAboutHtml

-- The licences, from the classic window's buttons (see the top)
private command abReadLicences
   local tFile, tName, tWasLoaded, tGroup, tIndex, tCount, tError
   if sLicNames is not empty then
      exit abReadLicences
   end if
   put abToolset() & "/palettes/about.oxtstack" into tFile
   if there is no file tFile then
      exit abReadLicences
   end if
   put kClassicStack is among the lines of the mainStacks into tWasLoaded
   try
      get the short name of stack tFile
      put it into tName
      put the long id of group "licbtns" of card 2 of stack tName into tGroup
      put 0 into tCount
      repeat with tIndex = 1 to the number of buttons of tGroup
         add 1 to tCount
         put the short name of button tIndex of tGroup into sLicNames[tCount]
         put the theBlurb of button tIndex of tGroup into sLicTexts[tCount]
      end repeat
   catch tError
   end try
   if not tWasLoaded and tName is not empty and tName is among the lines of the mainStacks \
         and tName is not among the lines of the openStacks then
      try
         -- (deleting a main stack takes it out of memory: its file stays
         -- as it is)
         delete stack tName
      catch tError
      end try
   end if
end abReadLicences

private function abLicencesHtml
   local tIndex, tHtml, tKeys
   abReadLicences
   put "<p>OXT-Beyond is free software under the GNU General Public License version 3, " & \
         "and is built with the work of many others. Choose one to read its licence.</p><p></p>" into tHtml
   put the keys of sLicNames into tKeys
   sort lines of tKeys numeric
   repeat for each line tIndex in tKeys
      put "<p>" & numToCodepoint(8226) & "  <a href=" & quote & "lic:" & tIndex & quote & ">" & \
            lkEscape(sLicNames[tIndex]) & "</a></p>" after tHtml
   end repeat
   if tKeys is empty then
      put "<p>The list of licences is not in this copy of the IDE.</p>" after tHtml
   end if
   put "<p></p><p>Every licence of what OXT-Beyond ships is also in " & \
         "<a href=" & quote & "doc:Open Source Licenses.txt" & quote & ">Open Source Licenses.txt</a>, " & \
         "in the IDE's folder.</p>" after tHtml
   return tHtml
end abLicencesHtml

################################################################################
#
# Building
#

private command abBuild
   local tSaved, tObj, tVersion, tCodename, tBuild, tLine, tX
   if there is a group "panel" of me then
      exit abBuild
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   set the label of me to "About" && abName()
   set the resizable of me to false
   set the destroyStack of me to true
   set the rect of me to 0, 0, kWidth, kHeight
   set the backgroundColor of me to lkColor("bg")
   set the linkColor of me to lkColor("violet")
   set the linkHiliteColor of me to lkColor("pink")
   set the linkVisitedColor of me to lkColor("violet")
   set the underlineLinks of me to false

   put abFileLine(".version") into tVersion
   put abFileLine(".codename") into tCodename
   put abFileLine(".buildnumber") into tBuild

   -- The header
   put lkBox("heroBg", lkR(0, 0, kWidth, kHeroHeight), lkColor("side"), 0, empty) into tObj
   lkGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", kWidth & "," & kHeroHeight
   put lkBox("heroMark", lkR(kPad, 30, kPad + 56, 86), lkColor("flame"), 28, empty) into tObj
   lkGradient tObj, "255,139,0|219,39,119", kPad & ",30", (kPad + 56) & ",86"
   lkGlow tObj, "255,139,0", 18, 90
   get lkIcon("heroMarkIcon", "layers", "255,255,255", lkR(kPad + 14, 44, kPad + 42, 72), empty)
   put kPad + 76 into tX
   put lkLabel("heroTitle", lkR(tX, 26, kWidth - kPad, 58), abName(), 26, "255,255,255", empty) into tObj
   set the dontWrap of tObj to true
   put tVersion into tLine
   if tCodename is not empty then
      put "  " & numToCodepoint(0x00B7) & "  " & numToCodepoint(0x201C) & tCodename & numToCodepoint(0x201D) after tLine
   end if
   put lkLabel("heroVersion", lkR(tX, 60, kWidth - kPad, 80), tLine, 15, lkColor("sideInk"), empty) into tObj
   set the dontWrap of tObj to true
   put empty into tLine
   -- (a source tree's build number is 0: no build to name)
   if tBuild is 0 then
      put empty into tBuild
   end if
   if tBuild is not empty then
      put "Build" && tBuild & "  " & numToCodepoint(0x00B7) & "  " after tLine
   end if
   put "Engine" && version() & "  " & numToCodepoint(0x00B7) & "  " & abPlatform() after tLine
   put lkLabel("heroBuild", lkR(tX, 84, kWidth - kPad, 100), tLine, 12, lkColor("muted"), empty) into tObj
   set the dontWrap of tObj to true
   put abName() && tVersion into sVersionText
   if tCodename is not empty then
      put " (" & tCodename & ")" after sVersionText
   end if
   if tBuild is not empty then
      put ", build" && tBuild after sVersionText
   end if
   put ", engine" && version() & "," && abPlatform() after sVersionText
   get lkButton("copy", tX, 112, 28, "Copy version", "copy", "dark", empty, empty, "copy", 0)
   get lkLabel("copied", lkR(tX + 150, 118, kWidth - kPad, 136), empty, 12, lkColor("emerald"), empty)

   -- The panel
   put lkBox("panelBg", lkR(kPad - 8, kHeroHeight + 20, kWidth - kPad + 8, kHeight - kFootHeight), \
         lkColor("panel"), 16, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel("panel", lkR(kPad + 8, kHeroHeight + 34, kWidth - kPad - 24, kHeight - kFootHeight - 14), \
         empty, 13, lkColor("soft"), empty) into tObj
   set the textHeight of tObj to 19
   set the vScrollbar of tObj to true
   lkScroller "panelThumb", tObj, "100,116,139", 45, empty

   -- The foot
   get lkButton("notes", kPad - 8, kHeight - kFootHeight + 18, 34, "Release notes", "file-text", "ghost", lkColor("violet"), empty, "notes", 0)
   put the right of group "notes" + 10 into tX
   get lkButton("licences", tX, kHeight - kFootHeight + 18, 34, "Licences", "book-open", "ghost", lkColor("violet"), empty, "licences", 120)
   get lkButton("close", kWidth - kPad + 8 - 110, kHeight - kFootHeight + 18, 34, "Close", empty, "primary", lkColor("violet"), empty, "close", 110)
   unlock messages
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end abBuild

private function abPlatform
   switch the platform
      case "Win32"
         return "Windows"
      case "MacOS"
         return "macOS"
      case "Linux"
         return "Linux"
      case "HTML5"
         return "Web"
   end switch
   return the platform
end abPlatform

-- The panel shows the about text, the licences, or one licence (pView
-- "licence" and its number)
private command abShowView pView, pIndex
   local tSaved
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   if pView is empty then
      put "about" into pView
   end if
   put pView into sView
   lock screen
   switch pView
      case "licences"
         set the htmlText of field "panel" to abBackHtml("about", "About") & abLicencesHtml()
         break
      case "licence"
         abReadLicences
         set the htmlText of field "panel" to abBackHtml("licences", "All licences") & "<p><font color=" & quote & \
               lkHex(lkColor("ink")) & quote & "><b>" & lkEscape(sLicNames[pIndex]) & "</b></font></p><p></p>"
         put return & sLicTexts[pIndex] after field "panel"
         break
      default
         set the htmlText of field "panel" to abAboutHtml()
   end switch
   set the vScroll of field "panel" to 0
   lkScrollSync "panelThumb"
   unlock screen
   if tSaved is not empty and there is a stack tSaved then
      set the defaultStack to tSaved
   end if
end abShowView

-- A link back, above what the panel shows
private function abBackHtml pLink, pLabel
   return "<p><a href=" & quote & pLink & quote & ">" & numToCodepoint(8592) && lkEscape(pLabel) & "</a></p><p></p>"
end abBackHtml

################################################################################
#
# What it does
#

on lkAction pAction
   switch pAction
      case "copy"
         set the clipboardData["text"] to sVersionText
         put "Copied" into field "copied"
         send "abForgetCopied" to me in 1500 milliseconds
         break
      case "licences"
         if sView is "about" then
            abShowView "licences"
         else
            abShowView "about"
         end if
         break
      case "notes"
         abReleaseNotes
         break
      case "close"
         close me
         break
   end switch
end lkAction

on abForgetCopied
   if the mode of me is not 0 then
      put empty into field "copied" of me
   end if
end abForgetCopied

-- As the classic window's Release Notes button does
private command abReleaseNotes
   local tError
   try
      send "tOpenReleaseNotes" to card "Automatic Updates" of stack "revPreferencesGUI"
   catch tError
      exit abReleaseNotes
   end try
   close me
end abReleaseNotes

on linkClicked pLink
   local tError
   if pLink is "licences" or pLink is "about" then
      abShowView pLink
      exit linkClicked
   end if
   if pLink begins with "lic:" then
      abShowView "licence", char 5 to -1 of pLink
      exit linkClicked
   end if
   try
      if pLink begins with "doc:" then
         launch document (abRoot() & "/" & char 5 to -1 of pLink)
      else if pLink contains "://" then
         launch url pLink
      end if
   catch tError
   end try
end linkClicked
