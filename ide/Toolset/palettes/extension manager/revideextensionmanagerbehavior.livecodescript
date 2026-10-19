script "revIDEExtensionManagerBehavior" with behavior "revPaletteBehavior"
on preOpenStack
   lock screen
   dispatch "setAsBehavior" to revIDEFrameBehavior() with the long id of this me
   
   set the behavior of card "web" of me to the long id of stack "revIDEExtensionManagerStoreBehavior"
   set the behavior of card "list" of me to the long id of stack "revIDEExtensionManagerListBehavior"
   set the zoomBox of this stack to false
   
   clearFrameData
   
   # Navigation
   -- addFrameItem pName, pLocation, pItemType, pLabel, pIcon, pIconSelected, pCallbackMessage, pCallbackTarget, pParameter
   addFrameItem "widget","header", "navigation", "Widgets", "", "","showList", the long id of me,"widget"
   addFrameItem "library","header", "navigation", "Libraries", "", "","showList", the long id of me,"library"
   -- OXT-Beyond: the Sample Stacks and Snippets tabs are blank unless an
   -- extension of that type is installed, so they are shown only then;
   -- someone who has one keeps the tab they had.
   if revIDEExtensions("sample") is an array then
      addFrameItem "sample","header", "navigation", "Sample Stacks", "", "","showList", the long id of me,"sample"
   end if
   if revIDEExtensions("snippet") is an array then
      addFrameItem "snippet","header", "navigation", "Snippets", "", "","showList", the long id of me,"snippet"
   end if
   -- OXT-Beyond: no Repo or Playground tab. Both showed a web stack from
   -- GitHub Pages in a browser widget, slow to load and dark; extensions
   -- are installed from a file with Install extension.
   addFrameItem "install", "header", "action", "Install extension", "plus", "","installNew", the long id of me
   
   set the hilitedTabColor of me to "255,255,255"
   set the navigationDisplayStyle of me to "names"
   unlock screen
end preOpenStack

on showList pSection
   lock screen
   send "showList pSection" to card "list" of this stack
   unlock screen
end showList

command refreshList
   lock screen
   send "refreshList" to card "list" of this stack
   unlock screen
end refreshList

on showExtensionStore
   -- OXT-Beyond: with no Repo tab, a request for the store (the Tools
   -- palette's "more widgets" button) shows the installed widgets
   showList "widget"
   hiliteFrameItem "widget"
   go card "list" of this stack
end showExtensionStore

-- The Repo tab's page, no longer shown (see preOpenStack)
on showExtensionRepoPage
   hiliteFrameItem "repo"
   -- browserHide
   lock screen
   set the goSection of this stack to "Repo"
   -- go to card "web" of this stack
   -- set the userAgent of widget "browser" of card "web" of this stack to "OpenXTalk IDE"
   --set the URL of widget "Browser" of card "web" of this stack to "https://openxtalk-org.github.io/OpenXTalk-Playground/Widgets/index.html" --  "https://openxtalk-org.github.io/OpenXTalk-Playground/"
   if the URL of widget "Browser" of card "web" of this stack <> "https://openxtalk-org.github.io/OXT_Resource_Depot_Repo/" then
      set the URL of widget "Browser" of card "web" of this stack to "https://openxtalk-org.github.io/OXT_Resource_Depot_Repo/" --  "https://openxtalk-org.github.io/OpenXTalk-Playground/"
      --send ("doXTscriptInWidget "& quote &"go last"&quote) to me --  in 2 seconds
      -- send ("doXTscriptInWidget "& quote &"go last"&quote) to me in 7 seconds
      -- else
      -- doXTscriptInWidget "go last" --- no longer needed as there is only 1 card in the new res depot web-stack
   end if
   unlock screen
   go card "web" of this stack
end showExtensionRepoPage

on showWebPlaygound
   hiliteFrameItem "playground"
   -- browserHide
   lock screen
   set the goSection of this stack to "Playground"
   -- 
   -- set the userAgent of widget "browser" of card "web" of this stack to "OpenXTalk IDE"
   if the URL of widget "Browser" of card "web" of this stack <> "https://openxtalk-org.github.io/OpenXTalk-Playground/" then
      set the URL of widget "Browser" of card "web" of this stack to "https://openxtalk-org.github.io/OpenXTalk-Playground/" --  "https://openxtalk-org.github.io/OpenXTalk-Playground/"
      --send ("doXTscriptInWidget "& quote &"go first"&quote) to me  -- in 1 seconds
      -- send ("doXTscriptInWidget "& quote &"go first"&quote) to me in 7 seconds
   -- else
      -- doXTscriptInWidget "go first"
   end if
   -- doXTscriptInWidget "go first"
   unlock screen
   go card "web" of this stack
   -- browserShow
end showWebPlaygound

on preferenceChanged pPreference, pValue
   revIDESetPreference pPreference, pValue
end preferenceChanged

on installNew
   -- OXT-Beyond: the file type is named for what it is, an extension package
   answer file "Choose an extension to install:" with type "xTalk Extension|lce|"
   if it is not empty and it ends with ".lce" then 
      installExtension it, "", "widget"
   end if
end installNew

on installExtension pExtensionPathOrURL, pTypeID, pType
   lock screen
   showList pType
   -- OXT-Beyond: test the parameter this handler has (the first version
   -- tested pExtensionURL, which is not one, so a URL from the web page
   -- went to the local-file install and failed)
   if pExtensionPathOrURL begins with "http" then
      // get from extensions store
      revIDEExtensionDownloadAndInstall pExtensionPathOrURL, pType
   else if pExtensionPathOrURL begins with "data:" then -- data:application/octet-stream;base64,...
      -- OXT-Beyond: a package handed over as a base64 data URI
      set the itemDelimiter to comma
      if item 1 of pExtensionPathOrURL ends with ";base64" then
         unlock screen
         installExtensionB64Decode item 2 to -1 of pExtensionPathOrURL, pTypeID, pType
         exit installExtension
      end if
   else
      // get from local .lce file
      revIDEExtensionInstall pExtensionPathOrURL, pType
   end if
   unlock screen
end installExtension

-- Writes a base64-encoded .lce package to the downloads folder (or, with
-- no identifier, where the user chooses) and installs it. The web page in
-- the Repo tab calls it, so pResID names a file: only an extension
-- identifier is accepted (letters, digits, dots, dashes and underscores),
-- never a path.
on installExtensionB64Decode pExtensionB64Encoded, pResID, pExtensionType
   local tFile
   if pExtensionType is empty then
      put "widget" into pExtensionType
   end if
   if pResID is empty then
      ask file "Save Binary as..." with "File.lce"
      if it is not empty then 
         put it into tFile
      end if
   else if matchText(pResID, "^[A-Za-z0-9][A-Za-z0-9._-]*$") then
      if pResID ends with ".lce" then
         delete char -4 to -1 of pResID
      end if
      put revIDESpecialFolderPath("downloading extensions") & slash & pResID & ".lce" into tFile
   else
      answer error "Not an extension identifier:" && pResID
      exit installExtensionB64Decode
   end if
   if tFile is not empty then
      open file tFile for binary write
      write base64Decode(pExtensionB64Encoded) to file tFile
      close file tFile
      installExtension tFile, pResID, pExtensionType
   end if
end installExtensionB64Decode

-- Runs xTalk in the web stack shown in the Repo and Playground tabs (the
-- page's own doXTscript, not one of the IDE's). The IDE offers the page no
-- handler that runs script it sends: the page's javaScriptHandlers are the
-- two install handlers above.
on doXTscriptInWidget pXTScript
   local tJS
   replace "\" with "\\" in pXTScript
   replace "'" with "\'" in pXTScript
   put "var thisStack = document.liveCode.findStackWithName('WebStack');" & cr &\
         "thisStack.doXTscript('" & pXTScript & "');" & cr into tJS
   -- OXT-Beyond: often sent from a timer, so a page that is not ready
   -- (or a palette closed meanwhile) does nothing rather than raise an
   -- error dialog
   if there is not a widget "Browser" of card "Web" of this stack then
      exit doXTscriptInWidget
   end if
   try
      do tJS in widget "Browser" of card "Web" of this stack
   catch tError
   end try
end doXTscriptInWidget

on navSelected pItemName
   if pItemName is "Repo" then
      send "showExtensionStore" to this stack
      exit navSelected
   end if
   if pItemName is "Playground" then
      send "showWebPlaygound" to this stack
      exit navSelected
   end if
   pass navSelected
end navSelected