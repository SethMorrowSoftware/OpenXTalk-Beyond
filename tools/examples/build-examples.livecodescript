script "OXTBuildExamples"
-- OXT-Beyond: builds the remastered examples (tools/examples/README.md).
--
-- Run it with the development engine of an installed OXT-Beyond, without
-- the IDE, from a checkout:
--
--    <install>/OXT-Beyond -ui tools/examples/build-examples.livecodescript
--
-- It builds every example in kExamples, or those named (by their
-- builders' file names, comma separated) in OXT_EXAMPLES, into
-- ide/Resources/Examples/Remastered, or the folder in OXT_EXAMPLES_OUT.
-- Before it saves a stack it compiles every script in it as the IDE's
-- strict compilation mode does, and a script that does not compile stops
-- the build. It writes a line for each step to stdout, and ends with
-- "DONE" (exit code 0) or "FAILED <reason>" (exit code 1).
--
-- The icons are drawn by the drawing library's drawingSvgCompile, which
-- reads SVG with revXML. Without the IDE neither is loaded, so this
-- script loads them from the install it runs in, as the IDE does.

-- The examples, by their builders' file names in this folder
constant kExamples = "animate-letter,quick-start,scroll-image,rss-reader,video-player,bouncing-balls,balloon-game,sqlite-tour,zip-archives,book-library,data-grid-tour,data-grid-table,sqlite-book-library,learn-box2d,learn-box2dxt-kit,learn-sodiumxt,learn-coinxt,learn-nostrxt,learn-enet,learn-datachannelxt,learn-torrentxt,learn-onionxt,svg-lab"

on startup
   local tFolder, tRepo, tOut, tName, tError, tExamples
   set the itemDelimiter to slash
   put item 1 to -2 of the filename of me into tFolder
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put $OXT_EXAMPLES_OUT into tOut
   if tOut is empty then
      put tRepo & "/ide/Resources/Examples/Remastered" into tOut
   end if
   put $OXT_EXAMPLES into tExamples
   if tExamples is empty then
      put kExamples into tExamples
   end if
   try
      buildDrawing
      start using stack (tRepo & "/ide/Toolset/palettes/learn/revlearnkit.livecodescript")
      start using stack (tFolder & "/builder.livecodescript")
      repeat for each item tName in tExamples
         buildLog "BUILD" && tName
         buildLooks tFolder, tName, tOut
         buildLog "SAVED" && the result
      end repeat
   catch tError
      buildLog "FAILED" && buildErrorText(tError)
      if $OXT_EXAMPLES_DEBUG is not empty then
         buildLog tError
      end if
      quit 1
   end try
   buildLog "DONE"
   quit 0
end startup

################################################################################
#
# Light and dark
#
# An example follows the desktop between light and dark, as Learn does
# (openxtalk.org p=25438). It is built twice, with the kit's colours
# light and then dark (lkSetDark), in the same order, so that the two
# builds have the same objects with the same ids. Where an object's
# colours differ between them, it keeps both: the custom property sets
# uLight and uDark, which the window's script (frame-runtime) puts on the
# objects when the card opens, light or dark as the IDE says the desktop
# is. Without the IDE (a standalone, a browser) the example stays light,
# as it is saved. The keys of the two sets:
#    props          the colour properties that differ (kLookProps), an
#                   arrayEncoded array for "set the properties"
#    c:<key>        a custom property whose value is a colour (cRest...)
#    h:<card id>    a field's htmlText on that card, where its text runs
#                   have colours of their own; x:<card id> is its text,
#                   so that a text the user has changed is left alone
#    t:             an image's text (an icon, drawn in its colour)
# The stage and what the programs put on it are not the kit's colours, so
# they come out the same in both builds and are left as they are.

constant kLookProps = "backColor,foreColor,borderColor,hiliteColor,shadowColor,topColor,bottomColor,focusColor,fillGradient,strokeGradient,dropShadow,innerShadow,outerGlow,innerGlow,colorOverlay"

-- Builds the example pName into pOut, light and dark. With
-- OXT_EXAMPLES_KEEP_LIGHT set, the light stack is the one already in pOut,
-- as it was built before, and only the dark colours and the window's
-- script are added to it: its light look stays as it was, to the pixel
command buildLooks pFolder, pName, pOut
   local tTemp, tDarkPath, tDarkName, tLightName, tLightPath
   put specialFolderPath("temporary") & "/oxt-examples-dark-" & the milliseconds & "-" & random(1000000) into tTemp
   create folder tTemp
   lkSetDark true
   buildOne pFolder, pName, tTemp
   put the result into tDarkPath
   lkSetDark false
   put the short name of stack tDarkPath into tLightName
   put tLightName && "(dark build)" into tDarkName
   set the name of stack tLightName to tDarkName
   set the itemDelimiter to slash
   put pOut & "/" & item -1 of tDarkPath into tLightPath
   set the itemDelimiter to comma
   if $OXT_EXAMPLES_KEEP_LIGHT is not empty then
      if there is no file tLightPath then
         throw "no light build of" && pName && "at" && tLightPath && "to keep"
      end if
      lock messages
      put the short name of stack tLightPath into tLightName
      unlock messages
      set the script of group "Frame" of card 1 of stack tLightName to the script of group "Frame" of card 1 of stack tDarkName
   else
      buildOne pFolder, pName, pOut
   end if
   buildPairLooks the long id of stack tLightName, the long id of stack tDarkName
   lock messages
   go card 1 of stack tLightName
   unlock messages
   save stack tLightName as tLightPath
   if the result is not empty then
      throw "cannot save " & tLightPath & ": " & the result
   end if
   -- (both stay in memory: the engine has been seen to crash when the
   -- next example is built after they are deleted)
   delete file tDarkPath
   delete folder tTemp
   return tLightPath
end buildLooks

private command buildOne pFolder, pName, pOut
   dispatch "exBuild" to stack (pFolder & "/" & pName & ".livecodescript") with pOut
   if it is not "handled" then
      throw pName & ".livecodescript has no exBuild handler"
   end if
   return the result
end buildOne

-- Pairs the light stack pLight with the dark build pDark, object by object,
-- and gives each object whose colours differ its uLight and uDark sets
private command buildPairLooks pLight, pDark
   local tCard, tCtl, tL, tD, tCount, tLightA, tDarkA, tObj, tDObj
   if the number of cards of pLight is not the number of cards of pDark then
      throw the short name of pLight && "has" && the number of cards of pLight && "cards light and" && the number of cards of pDark && "dark"
   end if
   buildPairOne pLight, pDark, empty, tLightA, tDarkA
   repeat with tCard = 1 to the number of cards of pLight
      put the long id of card tCard of pLight into tL
      put the long id of card tCard of pDark into tD
      if the id of tL is not the id of tD or the number of controls of tL is not the number of controls of tD then
         throw "card" && tCard && "of" && the short name of pLight && "differs between the light and dark builds"
      end if
      buildPairOne tL, tD, empty, tLightA, tDarkA
      repeat with tCtl = 1 to the number of controls of tL
         put the long id of control tCtl of tL into tObj
         put the long id of control tCtl of tD into tDObj
         if the id of tObj is not the id of tDObj or word 1 of tObj is not word 1 of tDObj then
            throw "control" && tCtl && "of card" && tCard && "of" && the short name of pLight && "differs between the light and dark builds"
         end if
         if buildIsPage(tObj, the cLayout of tL) then
            buildPairOne tObj, tDObj, the id of tL, tLightA, tDarkA
         end if
      end repeat
   end repeat
   -- (an object of a background is met on each of its cards: its sets are
   -- gathered by id, and given once)
   put 0 into tCount
   repeat for each key tObj in tLightA
      if tObj is "stack" then
         put pLight into tL
      else
         put buildObjectById(tObj, pLight) into tL
      end if
      set the customProperties["uLight"] of tL to tLightA[tObj]
      set the customProperties["uDark"] of tL to tDarkA[tObj]
      add 1 to tCount
   end repeat
   buildLog "LOOKS" && tCount && "objects with colours of their own in the dark"
end buildPairLooks

-- True when the control pObj is part of the page, not of a program: on a
-- card with a stage (pLayout "program" or "wide"), only the window's own
-- groups (the frame, the scripts panel) are the page; the stage, and what
-- the card's program has on it, keep their colours, which the programs
-- were written for
private function buildIsPage pObj, pLayout
   local tObj
   if word 1 of pLayout is not "program" and word 1 of pLayout is not "wide" then
      return true
   end if
   put pObj into tObj
   repeat while word 1 of the long owner of tObj is "group"
      put the long owner of tObj into tObj
   end repeat
   return word 1 of tObj is "group" and the short name of tObj is among the items of "Frame,Scripts,Focus"
end buildIsPage

-- The field pField (a long id) on the card whose id is pCardId, of its
-- stack: "field id <id> of card id <id> of stack ...", which reads and
-- sets its text on that card, where its long id reads the window's card
private function buildFieldOn pField, pCardId
   local tStack
   put the long id of pField into tStack
   put char offset(" of stack ", tStack) + 4 to -1 of tStack into tStack
   return "field id" && the id of pField && "of card id" && pCardId && "of" && tStack
end buildFieldOn

-- The object of pStack with the id pId (a card, or a control)
private function buildObjectById pId, pStack
   if there is a card id pId of pStack then
      return the long id of card id pId of pStack
   end if
   return the long id of control id pId of pStack
end buildObjectById

-- The colours of the object pL (light) and pD (dark) that differ, into
-- pLightA[id] and pDarkA[id]; for a field, its text on the card pCardId
private command buildPairOne pL, pD, pCardId, @pLightA, @pDarkA
   local tId, tProp, tL, tD, tKey, tPropsL, tPropsD, tLightP, tDarkP
   if word 1 of pL is "stack" then
      put "stack" into tId
   else
      put the id of pL into tId
   end if
   put the properties of pL into tPropsL
   put the properties of pD into tPropsD
   repeat for each item tProp in kLookProps
      if buildValue(tPropsL[tProp]) is not buildValue(tPropsD[tProp]) then
         put tPropsL[tProp] into tLightP[tProp]
         put tPropsD[tProp] into tDarkP[tProp]
      end if
   end repeat
   if tLightP is an array then
      put arrayEncode(tLightP) into pLightA[tId]["props"]
      put arrayEncode(tDarkP) into pDarkA[tId]["props"]
   end if
   -- (the custom properties that hold colours, which the runtime puts on
   -- a button lit or at rest)
   put the customProperties of pL into tPropsL
   put the customProperties of pD into tPropsD
   repeat for each key tKey in tPropsL
      put tPropsL[tKey] into tL
      put tPropsD[tKey] into tD
      if tL is not tD and buildIsColor(tL) and buildIsColor(tD) then
         put tL into pLightA[tId]["c:" & tKey]
         put tD into pDarkA[tId]["c:" & tKey]
      end if
   end repeat
   if word 1 of pL is "field" then
      -- (its text on that card: a field of a group placed on many cards
      -- has a text on each, and its long id names the card the window is
      -- on, whichever card it was asked of, so it is named by its id and
      -- the card's)
      if pCardId is not empty then
         put buildFieldOn(pL, pCardId) into pL
         put buildFieldOn(pD, pCardId) into pD
      end if
      put the htmlText of pL into tL
      put the htmlText of pD into tD
      if tL is not tD and the text of pL is the text of pD then
         put tL into pLightA[tId]["h:" & pCardId]
         put tD into pDarkA[tId]["h:" & pCardId]
         put the text of pL into pLightA[tId]["x:" & pCardId]
         put the text of pL into pDarkA[tId]["x:" & pCardId]
      end if
   else if word 1 of pL is "image" then
      if the text of pL is not the text of pD then
         put the text of pL into pLightA[tId]["t:"]
         put the text of pD into pDarkA[tId]["t:"]
      end if
   end if
end buildPairOne

-- A property's value, comparable: an array arrayEncoded
private function buildValue pValue
   if pValue is an array then
      return arrayEncode(pValue)
   end if
   return pValue
end buildValue

private function buildIsColor pValue
   return the number of items of pValue is 3 and item 1 of pValue is an integer \
         and item 2 of pValue is an integer and item 3 of pValue is an integer
end buildIsColor

command buildLog pLine
   write pLine & return to stdout
end buildLog

-- An error, in words: the compiler's or the engine's message for its first
-- line, or the text a builder threw
private function buildErrorText pError
   local tLine, tCode, tText
   -- (a message of our own: all of it, as a list of what does not fit
   -- names every problem on its own line)
   if item 1 of line 1 of pError is not an integer then
      return pError
   end if
   repeat for each line tLine in pError
      put item 1 of tLine into tCode
      if tCode is an integer and tCode > 0 then
         put line tCode of the scriptExecutionErrors into tText
         if tText is not empty then
            return tText && "(line" && item 2 of tLine & ", near" && item 4 to -1 of tLine & ")"
         end if
      end if
   end repeat
   return pError
end buildErrorText

-- Loads revXML and the drawing library, unless they are loaded already
-- (in the IDE they are)
private command buildDrawing
   local tEngine, tHelper, tLibrary, tError
   try
      if the number of bytes of drawingSvgCompile("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'><path d='M0 0h4' stroke='#000'/></svg>") > 0 then
         exit buildDrawing
      end if
   catch tError
   end try
   put specialFolderPath("engine") into tEngine
   if $OXT_INSTALL is not empty then
      put $OXT_INSTALL into tEngine
   end if
   -- (an external is loaded by a stack whose externals name it; the
   -- stack must be on disk for the engine to load them. Its file's name
   -- is this run's own, so that two builds at once do not share it)
   put specialFolderPath("temporary") & "/oxt-examples-xml-" & the milliseconds & "-" & random(1000000) & ".livecode" into tHelper
   create stack "oxtExamplesXml"
   if the platform is "Win32" then
      set the externals of stack "oxtExamplesXml" to tEngine & "/Externals/revxml.dll"
   else if the platform is "MacOS" then
      set the externals of stack "oxtExamplesXml" to tEngine & "/Externals/revxml.bundle"
   else
      set the externals of stack "oxtExamplesXml" to tEngine & "/Externals/revxml.so"
   end if
   save stack "oxtExamplesXml" as tHelper
   delete stack "oxtExamplesXml"
   start using stack tHelper
   delete file tHelper
   put tEngine & "/Extensions/com.livecode.library.drawing/drawing.livecodescript" into tLibrary
   if there is no file tLibrary then
      throw "no drawing library at " & tLibrary & ": set OXT_INSTALL to the installed OXT-Beyond"
   end if
   -- (the library's start-up handler asks the standalone builder to
   -- include it; that handler is below, and does nothing)
   insert the script of me into back
   dispatch "extensionInitialize" to stack tLibrary
   if the number of bytes of drawingSvgCompile("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'><path d='M0 0h4' stroke='#000'/></svg>") is 0 then
      throw "the drawing library draws nothing: is revXML loaded?"
   end if
end buildDrawing

on revSBAddDependencyForInclusion
end revSBAddDependencyForInclusion
