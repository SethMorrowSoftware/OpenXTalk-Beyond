script "TestIDENamedColors"
-- OXT-Beyond: revIDENamedColorToRGB
-- (ide/Toolset/libraries/revidelibrary.8.livecodescript), which the
-- Property Inspector's colour editor and the IDE's colour lists use, turns
-- colour names into RGB by setting the templateGraphic's colorOverlay to
-- each name and reading it back. Setting its color switches the overlay
-- on, and it was left on, set to the last name of the colorNames, so every
-- graphic made after the first call came out under a yellow-green overlay
-- (found by Stam Kapetanakis, HyperXTalk pull request #620). The overlay
-- the template had before (none, unless a script set one) is now put back.
-- The RGB values the function gives are unchanged.
--
-- The IDE library cannot be loaded by itself here (it has syntax only the
-- development engine compiles), so the handlers are copied from its file
-- into a stack of their own, with the script locals they share.

constant kStack = "TestIDENamedColorsStack"
constant kLib = "TestIDENamedColorsLibrary"
constant kHandlers = "__fetchNamesToColors,__fetchColorsToNames,revIDENamedColorToRGB,revIDERGBToNamedColor"

local sFolder, sSavedOverlay

-- The handlers pNames of the IDE library's file, and its line declaring
-- the script locals they keep their tables in, as a script
private function __LibraryHandlers pNames
   local tText, tScript, tIn, tName
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & \
         "/Toolset/libraries/revidelibrary.8.livecodescript"), "UTF-8") into tText
   -- A Windows checkout's file has CR LF line ends
   replace numToCodepoint(13) & numToCodepoint(10) with numToCodepoint(10) in tText
   put false into tIn
   repeat for each line tLine in tText
      if tIn then
         put tLine & return after tScript
         if word 1 of tLine is "end" and word 2 of tLine is tName then
            put false into tIn
         end if
      else if tLine is "local sNamesToColorsA, sColorsToNamesA" then
         put tLine & return after tScript
      else if (word 1 of tLine is among the items of "on,function,command" and \
            word 2 of tLine is among the items of pNames) or \
            (word 1 of tLine is "private" and word 3 of tLine is among the items of pNames) then
         if word 1 of tLine is "private" then
            put word 3 of tLine into tName
         else
            put word 2 of tLine into tName
         end if
         put tLine & return after tScript
         put true into tIn
      end if
   end repeat
   return tScript
end __LibraryHandlers

on TestSetup
   TestSkipIfNot "ide"
   TestSkipIfNot "write"
   put the colorOverlay of the templateGraphic into sSavedOverlay
   set the colorOverlay of the templateGraphic to empty
   put specialFolderPath("temporary") & "/oxt-named-colors-" & the milliseconds into sFolder
   create folder sFolder
   put textEncode("script " & quote & kLib & quote & return & \
         __LibraryHandlers(kHandlers), "UTF-8") into url ("binfile:" & sFolder & "/lib.livecodescript")
   start using stack (sFolder & "/lib.livecodescript")
   create stack kStack
   set the defaultStack to kStack
end TestSetup

on TestTeardown
   if there is a stack kStack then delete stack kStack
   if there is a stack kLib then
      stop using stack kLib
      delete stack kLib
   end if
   if sFolder is not empty and there is a folder sFolder then
      delete file (sFolder & "/lib.livecodescript")
      delete folder sFolder
   end if
   set the colorOverlay of the templateGraphic to sSavedOverlay
end TestTeardown

-- The keys of pOverlay (a colorOverlay), sorted, one line
private function __OverlayKeys pOverlay
   local tKeys
   put the keys of pOverlay into tKeys
   sort lines of tKeys
   replace return with comma in tKeys
   return tKeys
end __OverlayKeys

on TestLibraryCopied
   TestAssert "the library's handlers are copied", \
         the number of lines of the script of stack kLib > 20
end TestLibraryCopied

on TestNamesGiveTheirRGB
   -- as before: the engine's value for each name
   TestAssert "red", revIDENamedColorToRGB("red") is "255,0,0"
   TestAssert "YellowGreen", revIDENamedColorToRGB("YellowGreen") is "154,205,50"
   TestAssert "back to a name", revIDERGBToNamedColor("255,0,0") is among the lines of "red" & return & "Red"
end TestNamesGiveTheirRGB

on TestTemplateLeftWithoutOverlay
   local tOverlay
   get revIDENamedColorToRGB("blue")
   put the colorOverlay of the templateGraphic into tOverlay
   TestAssert "no overlay left on the templateGraphic", __OverlayKeys(tOverlay) is empty
   set the defaultStack to kStack
   create graphic "Made after"
   put the colorOverlay of graphic "Made after" of stack kStack into tOverlay
   TestAssert "a graphic made afterwards has no overlay", __OverlayKeys(tOverlay) is empty
end TestTemplateLeftWithoutOverlay

on TestTemplatesOwnOverlayKept
   local tOverlay
   -- an overlay a script set on the template stays as it was
   set the colorOverlay["color"] of the templateGraphic to "200,10,20"
   set the colorOverlay["opacity"] of the templateGraphic to 77
   set the colorOverlay["blendMode"] of the templateGraphic to "multiply"
   get revIDENamedColorToRGB("blue")
   put the colorOverlay of the templateGraphic into tOverlay
   TestAssert "its colour", tOverlay["color"] is "200,10,20"
   TestAssert "its opacity", tOverlay["opacity"] is 77
   TestAssert "its blend mode", tOverlay["blendMode"] is "multiply"
end TestTemplatesOwnOverlayKept
