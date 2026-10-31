script "revSaveAsEmscriptenStandalone"
/*
Copyright (C) 2015 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

-- Support for creating HTML5 standalones using Emscripten

private command logDebug pStep, pMessage
   write "[" & pStep & "]" && pMessage & return to stderr
end logDebug

----------------------------------------------------------------
-- Standalone generation
----------------------------------------------------------------

command revSaveAsEmscriptenStandalone pStack, pOutputFolder, pSettings
   
   logDebug "top", "----- Begin Emscripten standalone"
   
   -- FIXME
   --dispatch "revIDEDeployEmscriptenInitialize" to stack "revDeployLibrary"
   
   ---------- Pre-compute standalone build parameters
   
   -- Initial stack file
   local tStackFile
   put the effective filename of stack pStack into tStackFile
   
   -- Base directory
   local tBaseFolder
   set the itemDelimiter to slash
   put item 1 to -2 of tStackFile into tBaseFolder
   set the itemDelimiter to comma
   
   -- Other parameters
   local tName
   put pSettings["name"] into tName
   
   revStandaloneResetWarnings
   
   -- If we're searching for inclusions, do it here 
   if pSettings["inclusions"] is "search" then 
      revSBSearchForInclusions pStack, pSettings
   end if
   
   -- Make sure all dependencies are included
   revSBUpdateForDependencies "emscripten",,, pSettings
   
   revSBUpdateSettingsForExtensions "emscripten", pSettings
   
   -- OXT-Beyond: the engine with the xTalk Suite's libraries only for a
   -- stack that uses one of them (usesXTalkWebLibraries), or when the
   -- settings ask for it with "emscripten,xtalklibraries" set to "always"
   -- (the Stack Player, which opens stacks that may use them:
   -- tools/web-player/build-player.livecodescript)
   local tLean
   if pSettings["emscripten,xtalklibraries"] is "always" then
      put false into tLean
   else
      put not usesXTalkWebLibraries(pSettings) into tLean
   end if
   
   local tResolvedFileData
   revSBResolveCopyFilesList tBaseFolder, "emscripten", pSettings, tResolvedFileData
   
   local tDeploy
   -- Update the deploy params with script library and extension inclusions
   revSBUpdateDeployParams pStack, "emscripten", pSettings, tDeploy
   
   -- OXT-Beyond: the externals the standalone loads at startup, of those
   -- the web engine has
   put getWebExternals(pSettings) into tDeploy["externals"]

   local tError
   try
      ---------- Check deployment entitlement
      revStandaloneProgress "Checking deployment entitlement..."
      
      if not isPermittedDeployment() then
         throw "license does not permit HTML5 deployment"
      end if
      
      ---------- Create a working directory
      local tBuildFolder
      put pOutputFolder into tBuildFolder
      
      logDebug "top", "Output folder: " && pOutputFolder
      
      ---------- Create new zip archive
      revStandaloneProgress "Creating standalone archive..."
      
      local tBuildZip
      put tBuildFolder & slash & "standalone.zip" into tBuildZip
      
      logDebug "top", "Archive:" && tBuildZip
      
      revZipOpenArchive tBuildZip, "write"
      
      if the result is not empty then
         throw "could not create standalone archive"
      end if
      
      -- Store template files
      local tZipTemplateFile, tZipTemplateFolder, tZipTemplatePath
      put getStandaloneTemplateFolder() into tZipTemplateFolder
      
      repeat for each element tZipTemplateFile in getStandaloneTemplateFiles()
         put tZipTemplateFolder & slash & tZipTemplateFile into tZipTemplatePath
         logDebug "template", "Storing" && tZipTemplatePath
         revZipAddUncompressedItemWithFile tBuildZip, tZipTemplateFile, tZipTemplatePath
         if the result is not empty then
            throw "could not store template files in standalone archive"
         end if
      end repeat
      
      -- Define some paths within the zip archive
      local tBootPath, tStandalonePath
      local tDeployedStackPath
      put "boot" into tBootPath
      put tBootPath & slash & "__startup.data" into tDeployedStackPath
      put tBootPath & slash & "standalone" into tStandalonePath
      
      -- Deploy the standalone application data
      storeDeployedStack tBuildZip, tDeployedStackPath, tBuildFolder, tStackFile, tDeploy
      
      -- Store extra, copied files
      storeAssets tBuildZip, tResolvedFileData, tStandalonePath, tBaseFolder
      
      -- Close zip file
      revZipCloseArchive tBuildZip
      if the result is not empty then
         throw "could not create standalone archive:" && the result
      end if
      
      ---------- Copy the engine into the build folder
      revStandaloneProgress "Preparing engine files..."
      local tEngineFile
      repeat for each element tEngineFile in getEngineFiles(tLean)
         logDebug "engine", "Copying" && tEngineFile
         revSBCopyFileToFolder tEngineFile, tBuildFolder, \
               "revStandaloneProgressCallback", the long id of me
         
         if the result is not empty then
            throw "could not copy engine file" && the result
         end if
      end repeat
      
      ---------- Create HTML page

      -- OXT-Beyond: the engine's page, with its title and the page's
      -- settings of the HTML5 pane (createHtmlPage)
      revStandaloneProgress "Preparing HTML page..."

      local tHtmlFile
      put tBuildFolder & slash & tName & ".html" into tHtmlFile
      logDebug "html", "Creating" && tHtmlFile && "from" && getHtmlTemplateFile()
      createHtmlPage mapBinPath(getHtmlTemplateFile()), tHtmlFile, pStack, pSettings, tBaseFolder

   catch tError
      if tError is empty then
         put "an unknown error occurred" into tError
      end if
      
      -- Cleanup on failure
      if there is a folder pOutputFolder then
         revDeleteFolder pOutputFolder
      end if
   end try
   
   local tOutcome
   if tError is not empty then
      put "FAILURE" into tOutcome
   else
      put "SUCCESS" into tOutcome
   end if
   
   logDebug "top", "----- (" & tOutcome & ") Emscripten Standalone"
   
   if tError is not empty then
      throw tError
   end if
   
end revSaveAsEmscriptenStandalone

----------------------------------------------------------------
-- Standalone deployment
----------------------------------------------------------------

private command storeDeployedStack pZip, pDeployPath, pBuildFolder, pMainStack, pDeployParams
   local tTempStackData, tTempStackPath, tStartupScript, tTempDeployPath
   
   ---------- Generate the startup script
   logDebug "startup", "Generating startup script"
   
   put getTemporaryBuildFile(pBuildFolder, ".livecode") into tTempStackPath
   put getPreparedStackAsData(pMainStack, pBuildFolder) into tTempStackData
   put tTempStackData into url ("binfile:" & tTempStackPath)
   
   put getStartupScript(pDeployParams["startup_script"]) into tStartupScript
   
   put pBuildFolder & slash & "emscriptendeploy.data" into tTempDeployPath
   
   put tStartupScript into pDeployParams["startup_script"]
   put tTempStackPath into pDeployParams["stackfile"]
   put tTempDeployPath into pDeployParams["output"]
   put empty into pDeployParams["engine"]

   ---------- Perform standalone deployment
   logDebug "deploy", "Deploying standalone"
   
   _internal deploy emscripten pDeployParams
   if the result is not empty then
      throw "could not deploy startup stack:" && the result
   end if
   
   ---------- Store deployment data
   logDebug "deploy", "Storing" && tTempDeployPath
   local tDeployData
   
   -- We do this using data so that we can immediately delete the
   -- temporary file.  If used the file, we'd have to keep the
   -- file around until the zip file is finished.
   
   open file tTempDeployPath for binary read
   read from file tTempDeployPath until end
   put it into tDeployData
   close file tTempDeployPath
   
   revZipAddUncompressedItemWithData pZip, pDeployPath, "tDeployData"
   if the result is not empty then
      throw "could not store startup stack in standalone archive:" && the result
   end if
   
   ---------- Cleanup
   delete file tTempStackPath
   delete file tTempDeployPath
   
end storeDeployedStack

-- Create the startup script by processing the startup stack template.
-- Engine-specific and standalone-specific data is substituted into the
-- template in order 
private function getStartupScript pGeneratedStartupScript
   local tTemplateFile, tScript
   
   -- Load template
   put getStartupTemplateFile() into tTemplateFile
   open file tTemplateFile for "UTF-8" text read
   if the result is not empty then
      throw tTemplateFile & ":" && the result
   end if
   read from file tTemplateFile until end
   put it into tScript
   if the result is not "eof" then
      throw tTemplateFile & ":" && the result
   end if
   close file tTemplateFile

   -- Make substitutions in the startup script
   replace "@ENGINE_VERSION@" with the version in tScript
   replace "@STARTUP_SCRIPT@" with pGeneratedStartupScript in tScript
   return tScript
end getStartupScript

----------------------------------------------------------------
-- Externals
----------------------------------------------------------------

-- OXT-Beyond: the externals of the web engine. A browser loads no
-- libraries, so the web engine links into itself the externals that can
-- run in a browser (engine/src/em-externals.cpp): revXML, revZip, revDB
-- with its SQLite driver, and revSpeech with the browser's speech. A
-- standalone loads the ones its settings include by name, as a desktop
-- standalone loads its own; revDB finds its SQLite driver in the engine.
constant kWebExternals = "revxml,revzip,revdb,revspeech"
constant kWebDatabaseDrivers = "SQLite"

-- The names of the externals that the standalone loads at startup: those
-- of the web engine that the settings include (the XML, Revolution Zip,
-- Database and Speech inclusions). A warning names each other external or
-- database driver the settings include, which a browser cannot run.
private function getWebExternals pSettings
   local tMapping, tName, tExternals
   put revSBExternalsMapping() into tMapping
   repeat for each line tLibrary in pSettings["scriptLibraries"]
      -- An external's inclusion is its title in the mapping, as
      -- "revxml XML"; other inclusions are script libraries
      put empty into tName
      repeat for each item tItem in tMapping
         if word 2 to -1 of tItem is tLibrary then
            put word 1 of tItem into tName
            exit repeat
         end if
      end repeat
      if tName is empty then
         next repeat
      end if
      if tName is among the items of kWebExternals then
         if tExternals is not empty then
            put return after tExternals
         end if
         put tName after tExternals
      else
         revStandaloneAddWarning "HTML5:" && tLibrary && "is not available in a browser"
      end if
   end repeat
   
   repeat for each line tExternal in pSettings["externals"]
      revStandaloneAddWarning "HTML5: the external" && tExternal && "is not available in a browser"
   end repeat
   
   repeat for each line tDriver in pSettings["databaseDrivers"]
      if tDriver is not among the items of kWebDatabaseDrivers then
         revStandaloneAddWarning "HTML5: the" && tDriver && "database driver is not available in a browser"
      end if
   end repeat
   
   local tLog
   put tExternals into tLog
   replace return with comma in tLog
   logDebug "externals", "Loading" && quote & tLog & quote
   return tExternals
end getWebExternals

----------------------------------------------------------------
-- The HTML page
----------------------------------------------------------------

-- OXT-Beyond: write the page that loads the standalone: the engine's page, with
-- its title in place of @STACK_TITLE@ (the "emscripten,title" setting, or
-- else the stack's label or, without one, its name) and the rest of the
-- page's settings of the HTML5 pane (getPageHead()). The page loads the
-- engine's JavaScript, which loads the engine's WebAssembly and
-- standalone.zip, from the page's own folder.
private command createHtmlPage pTemplateFile, pHtmlFile, pStack, pSettings, pBaseFolder
   local tPage, tTitle, tHead, tOffset

   open file pTemplateFile for "UTF-8" text read
   if the result is not empty then
      throw pTemplateFile & ":" && the result
   end if
   read from file pTemplateFile until end
   put it into tPage
   close file pTemplateFile

   put line 1 of pSettings["emscripten,title"] into tTitle
   if tTitle is empty then
      put the label of stack pStack into tTitle
   end if
   if tTitle is empty then
      put the short name of stack pStack into tTitle
   end if
   -- The title is text in the page, not markup
   replace "&" with "&amp;" in tTitle
   replace "<" with "&lt;" in tTitle
   replace ">" with "&gt;" in tTitle
   replace "@STACK_TITLE@" with tTitle in tPage

   -- The page's other settings go at the end of its head; without them the
   -- page is the engine's as it is
   set the itemDelimiter to slash
   put getPageHead(pSettings, pBaseFolder, item 1 to -2 of pHtmlFile) into tHead
   set the itemDelimiter to comma
   if tHead is not empty then
      put offset("</head>", tPage) into tOffset
      if tOffset is 0 then
         throw pTemplateFile & ": the page has no </head>"
      end if
      put tHead before char tOffset of tPage
   end if

   open file pHtmlFile for "UTF-8" text write
   if the result is not empty then
      throw pHtmlFile & ":" && the result
   end if
   write tPage to file pHtmlFile
   close file pHtmlFile
end createHtmlPage

-- OXT-Beyond: what the settings of the HTML5 pane add to the page's head
-- (empty for none), each under the key "emscripten,<setting>":
--    icon             an image file, relative to the stack's folder
--                     (pBaseFolder) or not, which is copied into the
--                     standalone's folder (pBuildFolder) as icon.<extension>
--                     and is the page's icon
--    backgroundColor  the page's colour, #RRGGBB; white when empty
--    position         where the main stack is in the page: empty for
--                     centered at the top (the page's own place), "center"
--                     for centered in the browser's window, "topLeft" for at
--                     the top left
--    appearance       empty for the light appearance always (as every page
--                     had), "system" for the browser's colour scheme: the
--                     systemAppearance, and the colours of controls that set
--                     none, follow it (MCScreenDC::getsystemappearance in
--                     engine/src/em-dc.cpp), and so does the page's colour
--                     when it has none of its own
--    fieldBackground  empty for white fields (as every page had), "card"
--                     for fields, list fields and combo boxes that set no
--                     colour drawn in the light appearance in the grey of a
--                     card that sets none, as in the dark appearance
--                     (engine/src/em-theme.cpp)
-- A setting that cannot be used is left out, with a warning.
private function getPageHead pSettings, pBaseFolder, pBuildFolder
   local tHead, tStyle, tIcon, tExtension, tColor, tLuminance

   put pSettings["emscripten,icon"] into tIcon
   if tIcon is not empty then
      if there is a file (pBaseFolder & slash & tIcon) then
         put pBaseFolder & slash before tIcon
      end if
      if there is a file tIcon then
         set the itemDelimiter to "."
         put toLower(the last item of tIcon) into tExtension
         set the itemDelimiter to comma
         if tExtension is not among the items of "png,ico,svg,gif,jpg,jpeg,webp" then
            revStandaloneAddWarning "HTML5: the page's icon is not a PNG, ICO, SVG, GIF, JPEG or WebP image:" && tIcon
         else
            put url ("binfile:" & tIcon) into url ("binfile:" & pBuildFolder & "/icon." & tExtension)
            if the result is not empty then
               throw "could not copy the page's icon" && tIcon & ":" && the result
            end if
            put "<link rel=" & quote & "icon" & quote && "href=" & quote & "icon." & tExtension & quote & ">" after tHead
         end if
      else
         revStandaloneAddWarning "HTML5: the page's icon does not exist:" && tIcon
      end if
   end if

   put pSettings["emscripten,backgroundColor"] into tColor
   if tColor is not empty then
      if matchText(tColor, "^#[0-9A-Fa-f]{6}$") then
         put "body{background-color:" & tColor & "}" after tStyle
         -- the loading message in grey that can be read on the colour
         put 0.299 * baseConvert(char 2 to 3 of tColor, 16, 10) + \
               0.587 * baseConvert(char 4 to 5 of tColor, 16, 10) + \
               0.114 * baseConvert(char 6 to 7 of tColor, 16, 10) into tLuminance
         if tLuminance < 128 then
            put "#status{color:#cccccc}" after tStyle
         end if
      else
         revStandaloneAddWarning "HTML5: the page's colour is not #RRGGBB:" && tColor
      end if
   end if

   switch pSettings["emscripten,appearance"]
      case empty
         break
      case "system"
         put "<meta name=" & quote & "color-scheme" & quote && "content=" & quote & "light dark" & quote & ">" & \
               "<meta name=" & quote & "oxt-appearance" & quote && "content=" & quote & "system" & quote & ">" after tHead
         -- the page's dark colour, that of the stacks (em-theme.cpp), when
         -- it has none of its own
         if pSettings["emscripten,backgroundColor"] is empty then
            put "@media (prefers-color-scheme: dark){body{background-color:#202020}#status{color:#cccccc}}" after tStyle
         end if
         break
      default
         revStandaloneAddWarning "HTML5: unknown appearance of the page:" && pSettings["emscripten,appearance"]
         break
   end switch

   switch pSettings["emscripten,fieldBackground"]
      case empty
         break
      case "card"
         put "<meta name=" & quote & "oxt-field-background" & quote && "content=" & quote & "card" & quote & ">" after tHead
         break
      default
         revStandaloneAddWarning "HTML5: unknown background of the page's fields:" && pSettings["emscripten,fieldBackground"]
         break
   end switch

   switch pSettings["emscripten,position"]
      case empty
         break
      case "center"
         -- the window's height at least, with the stack in the middle of
         -- it, or at the top when it is taller (margins of a flex item do
         -- not go below 0)
         put "body{display:flex;flex-direction:column;min-height:100vh;min-height:100dvh}" & \
               "#stack{margin:auto}" after tStyle
         break
      case "topLeft"
         put "#stack{margin:0}" after tStyle
         break
      default
         revStandaloneAddWarning "HTML5: unknown place of the stack in the page:" && pSettings["emscripten,position"]
         break
   end switch

   if tStyle is not empty then
      put "<style>" & tStyle & "</style>" after tHead
   end if
   return tHead
end getPageHead

----------------------------------------------------------------
-- Extra files from "copy files"
----------------------------------------------------------------

private command storeAssets pZip, pFileData, pStandalonePath, pBaseFolder
   -- Get a list of all the files to copy
   local tPath, tFiles, tCount
   
   -- Store all the files in the zip archive
   local tFolderFilesA,tFolderFilesCount
   put 0 into tFolderFilesCount
   repeat for each element tFileInfoElement in pFileData
      if there is a file tFileInfoElement["resolved"] then
         add 1 to tFolderFilesCount
         put tFileInfoElement["name"] into tFolderFilesA[tFolderFilesCount]["name"]
         put tFileInfoElement["name"] into tFolderFilesA[tFolderFilesCount]["dest"]
         put tFileInfoElement["resolved"] into tFolderFilesA[tFolderFilesCount]["resolved"]
      else if there is a folder tFileInfoElement["resolved"] then
         local tFolderFiles
         put files(tFileInfoElement["resolved"]) into tFolderFiles
         repeat for each line tLine in tFolderFiles
            add 1 to tFolderFilesCount
            put tLine into tFolderFilesA[tFolderFilesCount]["name"]
            put tFileInfoElement["name"] & slash & tLine into tFolderFilesA[tFolderFilesCount]["dest"]
            put tFileInfoElement["resolved"] & slash & tLine into tFolderFilesA[tFolderFilesCount]["resolved"]
         end repeat
      end if
   end repeat
   
   local tZipPath
   repeat for each element tFileInfo in tFolderFilesA
      logDebug "asset", "Storing" && tFileInfo["resolved"]
      
      put pStandalonePath & slash & tFileInfo["dest"] into tZipPath
      revZipAddUncompressedItemWithFile pZip, tZipPath, tFileInfo["resolved"]
      if the result is not empty then
         throw "could not store asset file in standalone archive"
      end if
   end repeat
end storeAssets

----------------------------------------------------------------
-- Stack manipulation functions
----------------------------------------------------------------

-- Modifies a copy of <pStackFile> to prepare it for deployment,
-- and then returns the modified stack file's contents as data. 
-- <pStackFile> is not modified.
private function getPreparedStackAsData pStackFile, pBuildFolder
   local tStack, tDefaultStack, tError, tResult
   local tTempFile, tCleanTempFile
   local tStandaloneSettings
   local tStackData
   
   put the long id of stack pStackFile into tStack
   local tName
   put the short name of stack pStackFile into tName
   try
      if revIDEStackNameIsIDEStack(the name of tStack) then
         -- Don't manipulate IDE stacks if for some reason someone
         -- tries to put one into a standalone
         put the filename of tStack into tTempFile
         put false into tCleanTempFile

      else
         
         -- Get a temporary filename
         put getTemporaryBuildFile(pBuildFolder, ".livecode") into tTempFile
         put true into tCleanTempFile
         
         -- Clear standalone settings
         if not revEnvironmentEditionProperty("open_source_required") then
            set the customProperties["cRevStandaloneSettings"] of tStack to empty
         else
            -- For Community edition deployment to retain everything
            -- but the deployment password (which isn't relevant to
            -- Community edition anyway).  Keeping the deployment
            -- settings is GPL-required information.
            put the customProperties["cRevStandaloneSettings"] of tStack into tStandaloneSettings
            delete variable tStandaloneSettings["password"]
            set the customProperties["cRevStandaloneSettings"] of tStack to tStandaloneSettings
         end if
         
         -- Save the modified stack to the temporary file
         lock screen
         
         save tStack as tTempFile with newest format
         put the result into tResult
         if tResult is not empty then
            throw tTempFile & ":" && tResult
         end if
         
         set the filename of stack tName to pStackFile
         
         -- Revert to unmodified state
         
         revert stack tName
         set the defaultStack to tName
         
         unlock screen
         
      end if
      
      open file tTempFile for binary read
      if the result is not empty then
         throw tTempFile & ":" && the result
      end if
      read from file tTempFile until end
      put it into tStackData
      if the result is not "eof" then
         throw tTempFile & ":" && the result
      end if
      close file tTempFile

   catch tError
   end try
   
   if tCleanTempFile and there is a file tTempFile then
      delete file tTempFile
   end if

   if tError is not empty then
      throw tError
   end if

   return tStackData
end getPreparedStackAsData

----------------------------------------------------------------
-- File & path helper functions
----------------------------------------------------------------

-- Map a compiled file's path into an absolute filesystem path.  This
-- is used to cope with running from a git repository working tree.
private function mapBinPath pPath
   if there is a file pPath then
      return pPath
   end if
   
   if revEnvironmentIsInstalled() then
      -- We're running from an installed version of LiveCode
      return getRuntimeFolder() & slash & pPath
   else
      -- We're running from a git checkout
      return getRepoBinariesFolder() & slash & pPath
   end if
end mapBinPath

-- Map a resource file's path into an absolute filesystem path.  This
-- is used to cope with running from a git repository working tree.
private function mapResPath pPath
   if there is a file pPath then
      return pPath
   end if

   if revEnvironmentIsInstalled() then
      return getRuntimeFolder() & slash & pPath
   else
      return getRepoResourceFolder() & slash & pPath
   end if
end mapResPath

-- Scan a directory, returning a number-indexed array of files found.
-- The returned paths are relative to the specified directory.
private function scanFolder pFolder
   local tTemplateRoot, tFiles, tCount, tError
   
   -- Short-circuit if pFolder is missing
   if there is no folder pFolder then
      return empty
   end if
   
   put 0 into tCount
   put empty into tFiles
   
   revIDEPushDefaultFolder pFolder
   try
      scanFolder_recurse tCount, tFiles, empty
   catch tError
   end try
   
   revIDEPopDefaultFolder
   
   if tError is not empty then
      throw tError
   end if
   
   return tFiles
end scanFolder

-- Recursive function used by scanFolder()
private command scanFolder_recurse @xCount, @xFiles, pRelPath
   local tFile, tFilepath, tSaveFolder

   -- List files
   repeat for each line tFile in the files
      -- Skip dotfiles
      if tFile begins with "." then
         next repeat
      end if

      add 1 to xCount
      put tFile into tFilePath
      if pRelPath is not empty then
         put pRelPath & slash before tFilePath
      end if
      put tFilePath into xFiles[xCount]
   end repeat

   -- Recurse
   put the defaultfolder into tSaveFolder
   repeat for each line tFolder in the folders
      if tFolder begins with "." then
         next repeat
      end if

      set the defaultfolder to tSaveFolder & slash & tFolder
      if pRelPath is not empty then
         put pRelPath & slash before tFolder
      end if
      scanFolder_recurse xCount, xFiles, tFolder
   end repeat

   set the defaultFolder to tSaveFolder
end scanFolder_recurse

function revGetEmscriptenFiles
   return getEngineFiles(false)
end revGetEmscriptenFiles

-- Return a number-indexed array of engine files that need to be
-- copied into the standalone output folder: the engine of this
-- version (the startup script checks that it is the IDE's), its
-- JavaScript and the WebAssembly code that the JavaScript loads.
--
-- OXT-Beyond: the web engine links the xTalk Suite's native libraries
-- (engine/src/em-xtalk-web.cpp), which the Stack Player needs, and the
-- runtime has the same engine without them in lean/, under the same
-- names (tools/ci/build-web.sh). With pLean true the files are the lean
-- engine's, the engine every standalone had before the libraries were
-- linked, and smaller; a runtime without lean/ (a build from before it)
-- gives the engine it has.
private function getEngineFiles pLean
   local tFiles, tName
   put "standalone-" & getEngineType() & "-" & the version into tName
   if pLean then
      put mapBinPath("lean/" & tName & ".js") into tFiles[1]
      put mapBinPath("lean/" & tName & ".wasm") into tFiles[2]
      if there is a file tFiles[1] and there is a file tFiles[2] then
         logDebug "engine", "The lean engine, without the xTalk Suite libraries"
         return tFiles
      end if
      logDebug "engine", "No lean engine in the runtime: the engine with the xTalk Suite libraries"
   end if
   put mapBinPath(tName & ".js") into tFiles[1]
   put mapBinPath(tName & ".wasm") into tFiles[2]
   return tFiles
end getEngineFiles

-- OXT-Beyond: the extensions whose libraries the web engine links
-- (engine/src/em-xtalk-web.cpp), each as its id: the LCB libraries of
-- SodiumXT, Box2Dxt, CoinXT and DataChannelXT, and the script libraries
-- that call them (tools/oxt/xtalk-extensions.json), NostrXT's included,
-- which calls CoinXT and SodiumXT without naming them as needed.
constant kXTalkWebExtensions = "org.openxtalk.library.sodium,org.openxtalk.box2dxt,org.openxtalk.library.coin,org.openxtalk.library.datachannel,coinxt,box2dxt-kit,dataChannelHelpers,nostrxt,nostr-relay"
-- The names an LCB module binds those libraries by ("c:sodiumxt>sxt_hash")
constant kXTalkWebLibraries = "sodiumxt,box2dxt,coinxt,datachannelxt"

-- OXT-Beyond: true when the standalone includes an extension that uses
-- the xTalk Suite's libraries: one of kXTalkWebExtensions, or any LCB
-- module (another author's too) whose compiled module names one of
-- kXTalkWebLibraries. Such a standalone gets the engine with the
-- libraries, as every web standalone did in 0.2.7-rc.6.8; any other gets
-- the lean engine.
private function usesXTalkWebLibraries pSettings
   local tExtensionA, tFileA, tModule, tLibrary
   repeat for each element tExtensionA in pSettings["extensions_computed"]
      if tExtensionA["id"] is among the items of kXTalkWebExtensions then
         logDebug "engine", tExtensionA["id"] && "uses the xTalk Suite libraries"
         return true
      end if
      put revIDEExtensionFileData(tExtensionA["id"]) into tFileA
      if tFileA["type"] is not "lcb" or there is no file tFileA["file"] then
         next repeat
      end if
      put url ("binfile:" & tFileA["file"]) into tModule
      repeat for each item tLibrary in kXTalkWebLibraries
         if tLibrary & ">" is in tModule then
            logDebug "engine", tExtensionA["id"] && "binds to" && tLibrary
            return true
         end if
      end repeat
   end repeat
   return false
end usesXTalkWebLibraries

-- Get the filename of the Emscripten standalone template folder.
-- This is a folder that contains the default filesystem
-- initialisation data that's automatically included in all
-- standalones (especially fonts).
private function getStandaloneTemplateFolder
   return mapResPath("emscripten-standalone-template")
end getStandaloneTemplateFolder

-- Return a number-indexed array of files in the Emscripten standalone
-- template folder.  The paths returned are relative to the path returned
-- by getStandaloneTemplateFolder()
private function getStandaloneTemplateFiles
   return scanFolder(getStandaloneTemplateFolder())
end getStandaloneTemplateFiles

-- Get the filename of the Emscripten standalone template HTML file.
-- This has some standalone-dependent JavaScript substituted into it
-- to instantiate the engine.
private function getHtmlTemplateFile
   return mapBinPath("standalone-" & getEngineType() & "-" & the version & ".html")
end getHtmlTemplateFile

-- Get the filename of the Emscripten standalone startup script-only
-- stack template.
private function getStartupTemplateFile
   return mapResPath("emscripten-startup-template.livecodescript")
end getStartupTemplateFile

-- Get the directory containing the Emscripten runtime
private function getRuntimeFolder
   
   local tRelFolder, tOverridePath, tUserPath
   
   put slash & "Emscripten" & slash & "js" into tRelFolder
   
   put revOverrideRuntimePath() into tOverridePath
   if tOverridePath is not empty then
      put tRelFolder after tOverridePath
      if there is a folder tOverridePath then
         return tOverridePath
      end if
   end if
   
   put revEnvironmentUserRuntimePath() into tUserPath
   if tUserPath is not empty then
      put tRelFolder after tUserPath
      if there is a folder tUserPath then
         return tUserPath
      end if
   end if
   
   return revEnvironmentRuntimePath() & tRelFolder
end getRuntimeFolder

-- Get the directory where Emscripten binaries end up (specifically,
-- the engine's JavaScript file).
private function getRepoBinariesFolder
	return revEnvironmentRepositoryPath() & slash & "emscripten-bin"
end getRepoBinariesFolder

-- Get the directory where Emscripten resources are kept
private function getRepoResourceFolder
   return revEnvironmentRepositoryPath() & slash & "engine" & slash & "rsrc"
end getRepoResourceFolder

-- Get a temporary filename in <pBuildFolder> with the extension
-- <pExtension>
private function getTemporaryBuildFile pBuildFolder pExtension
   local tFile
   repeat forever
      put pBuildFolder & slash & (the random of 1000000) & pExtension into tFile
      if there is not a file tFile then
         exit repeat
      end if
   end repeat
   return tFile
end getTemporaryBuildFile

----------------------------------------------------------------
-- Other utility functions
----------------------------------------------------------------

-- Check if the license permits HTML5 deployment
private function isPermittedDeployment
   if isCommercialDeployment() then
      return ("HTML5" is among the items of line 5 of the revLicenseInfo)
   else
      return true
   end if
end isPermittedDeployment

-- Check if deploying a commercial standalone
private function isCommercialDeployment
   if revLicenseType() is "community" then
      return false
   else
      return true
   end if
end isCommercialDeployment

-- Get the engine type string ("commercial" or "community")
private function getEngineType
   if isCommercialDeployment() then
      return "commercial"
   else
      return "community"
   end if
end getEngineType
