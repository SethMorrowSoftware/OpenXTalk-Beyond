script "revIDEExtensionManagerStoreBehavior"
-- Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
-- (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
-- Seth Morrow (2026) and Paul McClernan (2026); its Git history and
-- CHANGELOG.md say what changed.

on preOpenCard
   send "resizeStack" to me
   browserHide
   setStatus "Loading..."
   set the repeatcount of image "loading" of me to -1
end preOpenCard

-- nudge the browser in kLoadTimeout seconds
constant kLoadTimeout = 10
on openCard
   --   hiliteFrameItem "repo"
   --   if the url of widget "browser" of me is empty then
   -- set the userAgent of widget "browser" of card "web" of me to "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36" -- Impersonate Browser
   --      set the userAgent of widget "browser" of card "web" of me to "OpenXTalk IDE" -- was "LiveCode"
   --            browserGoToExtensionStore
   --   else
   nudgeBrowser
   --   end if
   pass openCard
end openCard

on nudgeBrowser
   -- Hack to get round bug 18946
   send "browserNavigateComplete" to me in kLoadTimeout seconds
end nudgeBrowser

on setStatus pStatus
   put pStatus into field "status" of me
end setStatus

on resizeStack
   lock screen
   local tContentRect, tPadding
   put the contentrect of me into tContentRect
   put the palettePadding of me into tPadding
   set the width of field "status" of me to the width of me
   set the loc of field "status" of me to the loc of me
   set the loc of image "loading" of me to the loc of me
   set the bottom of image "loading" of me to the top of field "status" of me - tPadding
   
   set the rect of graphic "browser_background" of me to tContentRect
   set the rect of widget "browser" of me to tContentRect
   
   unlock screen
   pass resizeStack
end resizeStack

on browserHide
   hide widget "browser" of me
end browserHide

on browserShow
   show widget "browser" of me
end browserShow

on browserSetURL pURL
   lock screen
   set the url of widget "browser" of me to pURL
   nudgeBrowser
   unlock screen
end browserSetURL

on browserGoToExtensionPage pExtensionID
   hiliteFrameItem "repo"
   browserHide
   lock screen
   go to card "web" of this stack
   -- set the userAgent of widget "browser" of card "web" of this stack to "OpenXTalk IDE" -- "LiveCode"
   --set the URL of widget "Browser" of card "web" of this stack to "https://openxtalk-org.github.io/OpenXTalk-Playground/Widgets/index.html" --  "https://openxtalk-org.github.io/OpenXTalk-Playground/"
   if the URL of widget "Browser" of card "web" of this stack <> "https://openxtalk-org.github.io/OXT_Resource_Depot_Repo/index.html" then
      set the URL of widget "Browser" of card "web" of this stack to "https://openxtalk-org.github.io/OXT_Resource_Depot_Repo/index.html" --  "https://openxtalk-org.github.io/OpenXTalk-Playground/"
      send ("doXTscriptInWidget "& quote &"go last"&quote) to this stack in 10 seconds
      --else
      -- doXTscriptInWidget "go last"
   end if
   nudgeBrowser
   unlock screen
   -- browserSetURL "https://openxtalk-org.github.io/OpenXTalk-Playground/Widgets/index.html"
   -- browserSetURL revIDEWebPageURL("extensions") & pExtensionTypeID & slashs
   browserShow
end browserGoToExtensionPage

on browserGoToExtensionStore
   hiliteFrameItem "repo"
   browserHide
   lock screen
   go to card "web" of this stack
   -- set the userAgent of widget "browser" of card "web" of this stack to "OpenXTalk IDE" -- "LiveCode"
   --set the URL of widget "Browser" of card "web" of this stack to "https://openxtalk-org.github.io/OpenXTalk-Playground/Widgets/index.html" --  "https://openxtalk-org.github.io/OpenXTalk-Playground/"
   if the URL of widget "Browser" of card "web" of this stack <> "https://openxtalk-org.github.io/OXT_Resource_Depot_Repo/index.html" then
      set the URL of widget "Browser" of card "web" of this stack to "https://openxtalk-org.github.io/OXT_Resource_Depot_Repo/index.html" --  "https://openxtalk-org.github.io/OpenXTalk-Playground/"
      send ("doXTscriptInWidget "& quote &"go last"&quote) to this stack in 10 seconds
   else
      -- doXTscriptInWidget "go last"
   end if
   -- browserSetURL "https://openxtalk-org.github.io/OpenXTalk-Playground/Widgets/index.html"
   -- browserSetURL revIDEWebPageURL("extensions") & pExtensionTypeID & slashs
   
   -- if the url of widget "browser" of me is empty then
   -- impersonate Browser:
   -- set the userAgent of widget "browser" of card "web" of me to "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36" -- was "LiveCode"
   -- browserSetURL revIDEWebPageURL("extensions")
   nudgeBrowser
   unlock screen
   browserShow
end browserGoToExtensionStore

on browserDocumentLoadBegin pUrl,pError
   -- OXT-Beyond: this is the start of every load, not a failure, and the
   -- handler is browserHide (a misspelt name raised an error dialog on
   -- every page load)
   setStatus "Loading..."
   browserHide
   --   if pURL ends with ".b64" then 
   --      put "Base64 Data"
   --      --   else
   --      --      put "browserDocumentLoadBegin " & pUrl, pError & cr after msg
   --   end if
end browserDocumentLoadBegin

on browserDocumentLoadComplete pURL
   -- put "browserDocumentLoadComplete "& pURL & cr after msg
   -- put "browserNavigateComplete "& pURL & cr after msg
   setPageHandlers
   
   --   get the goSection of this stack
   --   if it is not empty then
   --      put the goSection of this stack into tGoSection
   --      -- put tGoSection
   --      if tGoSection is "Repo" then
   --         send "showExtensionStore" to this stack -- in 50 millisecs
   --         doXTscriptInWidget "go last"
   --      else if tGoSection is "Playground" then
   --         send "showExtensionStore" to this stack -- in 50 millisecs
   --         doXTscriptInWidget "go first"
   --      end if
   --   end if
   browserShow
end browserDocumentLoadComplete

on browserDocumentLoadFailed pURL,pError
   if pURL ends with ".lce.b64" then
      -- OXT-Beyond: a link to a base64-encoded package (GitHub Pages serves
      -- an .lce as a download the browser widget cannot take): fetch it
      -- and install it under the identifier its file name carries
      local tData, tResID
      put URL pURL into tData
      if the result is not empty or tData is empty then
         setStatus ("Download Failed" & cr & "URL:" & pURL & cr & "Error: " & the result)
         exit browserDocumentLoadFailed
      end if
      set the itemDelimiter to slash
      put the last item of pURL into tResID
      delete char -8 to -1 of tResID
      browserShow
      installExtensionB64Decode tData, tResID, ""
   else
      setStatus ("Document Load Failed" & cr &"URL:"& pUrl &cr& "Error: " & pError)
      -- put "browserDocumentLoadFailed " & pUrl, pError & cr after msg
   end if
   -- browserGoToExtensionStore
end browserDocumentLoadFailed

on browserNavigateBegin pURL
   -- OXT-Beyond: a package handed over as a data URI is installed (it
   -- was written to ~/test.zip while this was being worked on); the
   -- browser is hidden by browserDocumentLoadBegin when a page loads, not
   -- here, since a navigation that loads nothing would leave it hidden
   if pURL begins with "data:application/octet-stream;base64," then
      delete char 1 to 37 of pURL
      installExtensionB64Decode pURL, "", ""
   end if
end browserNavigateBegin

on browserNavigateComplete pUrl
   -- OXT-Beyond: nudgeBrowser also sends this, on a timer, so it only
   -- restores what a load resets (the page's handlers, the browser, the
   -- tab's hilite); it does not go to a section or set a URL, which
   -- pulled the palette back to this card from whichever tab was chosen
   -- meanwhile, and back to the section's first page from any link
   setPageHandlers
   if the short name of this card of this stack is not the short name of me then
      exit browserNavigateComplete
   end if
   switch the goSection of this stack
      case "Repo"
         hiliteFrameItem "repo"
         break
      case "Playground"
         hiliteFrameItem "playground"
         break
   end switch
   browserShow
end browserNavigateComplete

-- The handlers the page in the browser may call. OXT-Beyond: the two
-- install handlers only. The first version also offered doXTscript,
-- which ran whatever script the page sent, and would have done so for
-- any page reached from it.
private command setPageHandlers
   set the javaScriptHandlers of widget "browser" of me to "installExtension" & cr & "installExtensionB64Decode"
end setPageHandlers

on browserNavigateFailed pUrl, pError
   setStatus ("Navigate Failure" & cr &"URL:"& pUrl &cr& "Error: " & pError)
   --   put "browserNavigateFailed " & pUrl, pError & cr after msg
end browserNavigateFailed

on browserUnhandledLoadRequest pURL, pError
   setStatus ("Unhandled Load Request" & cr &"URL:"& pUrl &cr& "Error: " & pError)
   -- put "browserUnhandledLoadRequest " & pURL & cr after msg
end browserUnhandledLoadRequest

--on browserProgressChanged pUrl, pProgress
--   put "browserProgressChanged " & pUrl, pProgress & cr after msg
--end browserProgressChanged

--browserFrameDocumentLoadBegin	Sent when a document begins loading in a frame of the browser.	browserFrameDocumentLoadBegin pUrl
--browserFrameDocumentLoadComplete	Sent when a document has completed loading in a frame of the browser.	browserFrameDocumentLoadComplete pUrl
