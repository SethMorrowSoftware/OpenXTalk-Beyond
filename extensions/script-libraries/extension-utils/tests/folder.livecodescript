script "TestExtensionUtilsFolder"
-- OXT-Beyond: tests of extensionFetchSourceFromFolder, which finds an
-- extension's main source file and its support files in a folder (the
-- Extension Builder and the IDE's developer extensions use it). macOS
-- writes a "._" file of metadata beside each file on a disk it did not
-- format, and "._widget.lcb" counted as a second module, so on Windows and
-- Linux the folder was refused (Paul McClernan's fix in OXT DPE). Folders
-- without such files give what they gave before.

local sFolder

on TestSetup
   start using stack (TestGetEngineRepositoryPath() & \
         "/extensions/script-libraries/extension-utils/extension-utils.livecodescript")
   put the temporary folder & "/oxt-extension-utils-folder-" & the milliseconds into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   repeat for each line tFile in files(sFolder)
      delete file (sFolder & "/" & tFile)
   end repeat
   delete folder sFolder
end TestTeardown

private command __Make pFiles
   repeat for each line tFile in files(sFolder)
      delete file (sFolder & "/" & tFile)
   end repeat
   repeat for each item tFile in pFiles
      put "module x" & return & "end module" into url ("file:" & sFolder & "/" & tFile)
   end repeat
end __Make

on TestAppleDoubleFilesAreIgnored
   local tSource, tSupport, tType
   __Make "widget.lcb,._widget.lcb"
   extensionFetchSourceFromFolder sFolder, tSource, tSupport, tType
   local tResult
   put the result into tResult
   TestDiagnostic tResult
   TestAssert "a ._ file is not a second module", tResult is empty
   TestAssert "the main source is found beside a ._ file", tSource is "widget.lcb"
   TestAssert "the type is lcb beside a ._ file", tType is "lcb"

   __Make "widget.lcb,widget-support.lcb,._widget.lcb,._widget-support.lcb"
   extensionFetchSourceFromFolder sFolder, tSource, tSupport, tType
   TestAssert "main and support sources are found beside ._ files", \
         the result is empty and tSource is "widget.lcb" and tSupport is "widget-support.lcb"
end TestAppleDoubleFilesAreIgnored

on TestFoldersWithoutAppleDoubleFiles
   local tSource, tSupport, tType
   __Make "widget.lcb"
   extensionFetchSourceFromFolder sFolder, tSource, tSupport, tType
   TestAssert "one module", the result is empty and tSource is "widget.lcb" and tType is "lcb"

   __Make "widget.lcb,widget-support.lcb"
   extensionFetchSourceFromFolder sFolder, tSource, tSupport, tType
   TestAssert "main and support modules", \
         the result is empty and tSource is "widget.lcb" and tSupport is "widget-support.lcb"

   __Make "one.lcb,two.lcb"
   extensionFetchSourceFromFolder sFolder, tSource, tSupport, tType
   TestAssert "two main modules are still refused", the result begins with "Invalid extension folder"

   __Make "lib.livecodescript"
   extensionFetchSourceFromFolder sFolder, tSource, tSupport, tType
   TestAssert "a script extension", the result is empty and tSource is "lib.livecodescript" and tType is "lcs"

   __Make "readme.txt"
   extensionFetchSourceFromFolder sFolder, tSource, tSupport, tType
   TestAssert "no source", the result is empty and tSource is empty and tType is "none"
end TestFoldersWithoutAppleDoubleFiles
