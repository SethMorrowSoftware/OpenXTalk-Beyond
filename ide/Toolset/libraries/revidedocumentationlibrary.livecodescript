script "revIDEDocumentationLibrary"
on extensionInitialize
   if the target is me then
      insert the script of me into back
   end if
end extensionInitialize

on extensionFinalize
   if the target is me then
      remove script of me from back
   end if
end extensionFinalize

# OXT-Beyond: every build of one engine version shares one documentation
# cache folder, and its api.sqlite was copied from the distributed one only
# when there was none, so the first build to make it fixed its core entries
# for good. One made by a build that shipped no api.sqlite held nothing but
# extensions' docs, and every lookup of "put" or "menuPick" found no entry,
# in the Script Editor and the xTalk Assistant alike, while the Dictionary
# window, which reads its own files, showed them. So the cache keeps a note
# of the distributed api.sqlite it holds (the file's MD5), and when that
# differs it takes the distributed libraries' entries afresh and keeps every
# other library's: an extension writes its docs here only when its own
# cached docs are out of date, so a fresh copy of the file would lose them.
constant kDocsSourceNote = "api.sqlite.source"

private function ideDocsDigest pData
   local tHex
   if pData is empty then
      return empty
   end if
   get binaryDecode("H*", md5Digest(pData), tHex)
   return tHex
end ideDocsDigest

private on ideDocsEnsureDatabase pLocation
   local tData
   if there is not a file (pLocation & slash & "api.sqlite") then
      put url ("binfile:" & revIDESpecialFolderPath("API") & slash & "api.sqlite") into tData
      put tData into url ("binfile:" & pLocation & slash & "api.sqlite")
      # A fresh copy holds the distributed entries already
      if the result is empty and tData is not empty then
         put ideDocsDigest(tData) into url ("binfile:" & pLocation & slash & kDocsSourceNote)
      end if
   end if
end ideDocsEnsureDatabase

# Brings the cache's entries for the distributed libraries up to date with
# the distributed api.sqlite, once for each one it has not seen. Whatever
# fails leaves the cache as it was.
private on ideDocsRefreshCache pConnection, pLocation
   local tSource, tDigest
   put revIDESpecialFolderPath("API") & slash & "api.sqlite" into tSource
   if there is not a file tSource then
      exit ideDocsRefreshCache
   end if
   put ideDocsDigest(url ("binfile:" & tSource)) into tDigest
   if tDigest is empty or \
         tDigest is url ("binfile:" & pLocation & slash & kDocsSourceNote) then
      exit ideDocsRefreshCache
   end if

   try
      if ideDocsMergeDistributed(pConnection, tSource) is empty then
         put tDigest into url ("binfile:" & pLocation & slash & kDocsSourceNote)
      end if
   catch tError
      # Lookups then find what they found before
   end try
end ideDocsRefreshCache

# Replaces the cache's entries for every library the distributed api.sqlite
# at pSource documents with that file's entries. Returns empty when it did,
# else what failed.
private function ideDocsMergeDistributed pConnection, pSource
   local tSourceUTF8, tFailed

   # A cache made before any extension wrote to it has no tables
   revExecuteSQL pConnection, "CREATE TABLE IF NOT EXISTS apis(api_id integer primary key, api_name text)"
   if the result is not a number then
      return "unable to create table 'apis'" & return & the result
   end if
   revExecuteSQL pConnection, "CREATE TABLE IF NOT EXISTS dictionary_data(api_id integer," && \
         "library_name text, entry_name text, entry_type text, entry_data blob)"
   if the result is not a number then
      return "unable to create table 'dictionary_data'" & return & the result
   end if

   # SQLite reads an attached file's name as UTF-8
   put textEncode(pSource, "UTF-8") into tSourceUTF8
   revExecuteSQL pConnection, "ATTACH DATABASE :1 AS oxtdist", "tSourceUTF8"
   if the result is not a number then
      return "unable to open" && pSource & return & the result
   end if
   put ideDocsMergeAttached(pConnection) into tFailed
   revExecuteSQL pConnection, "DETACH DATABASE oxtdist"
   return tFailed
end ideDocsMergeDistributed

private function ideDocsMergeAttached pConnection
   local tCount, tPairs, tFailed, tAPI, tLibrary

   # Only a distributed file that holds entries replaces any
   put revDataFromQuery(tab, return, pConnection, "SELECT count(*) FROM oxtdist.dictionary_data") into tCount
   if tCount is not an integer or tCount < 1 then
      return "no distributed entries" & return & tCount
   end if
   # Each distributed library, with the name of its API
   put revDataFromQuery(tab, return, pConnection, \
         "SELECT DISTINCT s.api_name, d.library_name FROM oxtdist.dictionary_data d" && \
         "JOIN oxtdist.apis s ON s.api_id = d.api_id") into tPairs
   if tPairs is empty or tPairs begins with "revdberr" then
      return "no distributed libraries" & return & tPairs
   end if

   revExecuteSQL pConnection, "BEGIN TRANSACTION"
   if the result is not a number then
      return "unable to begin" & return & the result
   end if

   # The distributed APIs the cache lacks
   revExecuteSQL pConnection, "INSERT INTO main.apis(api_name) SELECT DISTINCT api_name" && \
         "FROM oxtdist.apis WHERE api_name IS NOT NULL AND api_name NOT IN" && \
         "(SELECT api_name FROM main.apis WHERE api_name IS NOT NULL)"
   if the result is not a number then
      put "unable to add the distributed APIs" & return & the result into tFailed
   end if

   # The cache's entries for each distributed library go...
   set the itemDelimiter to tab
   repeat for each line tPair in tPairs
      if tFailed is not empty then
         exit repeat
      end if
      put item 1 of tPair into tAPI
      put item 2 of tPair into tLibrary
      revExecuteSQL pConnection, "DELETE FROM main.dictionary_data WHERE library_name = :1" && \
            "AND api_id IN (SELECT api_id FROM main.apis WHERE api_name = :2)", "tLibrary", "tAPI"
      if the result is not a number then
         put "unable to remove the entries of" && tLibrary & return & the result into tFailed
      end if
   end repeat

   # ...and the distributed ones come in, under the cache's id for their API
   if tFailed is empty then
      revExecuteSQL pConnection, "INSERT INTO main.dictionary_data(api_id, library_name," && \
            "entry_name, entry_type, entry_data) SELECT (SELECT min(a.api_id) FROM main.apis a" && \
            "WHERE a.api_name = s.api_name), d.library_name, d.entry_name, d.entry_type," && \
            "d.entry_data FROM oxtdist.dictionary_data d JOIN oxtdist.apis s ON s.api_id = d.api_id"
      if the result is not a number then
         put "unable to copy the distributed entries" & return & the result into tFailed
      end if
   end if

   if tFailed is empty then
      revExecuteSQL pConnection, "COMMIT"
      if the result is not a number then
         put "unable to commit" & return & the result into tFailed
      end if
   end if
   if tFailed is not empty then
      revExecuteSQL pConnection, "ROLLBACK"
   end if
   return tFailed
end ideDocsMergeAttached

local sConnectionsA
command ideDocsInitialize pDistributed
   If pDistributed is true and revEnvironmentIsInstalled() then
      ideThrow "can't write to installed IDE"
      return empty
   end if
   
   local tConnection, tLocation, tKey
   if pDistributed is true then
      put "ide" into tKey
      put revIDESpecialFolderPath("API") into tLocation
   else
      put "cache" into tKey
      put revIDESpecialFolderPath("documentation cache") into tLocation
      ideDocsEnsureDatabase tLocation
   end if
   put sConnectionsA[tKey] into tConnection
   
   if tConnection is among the items of revOpenDatabases() then
      return tConnection
   end if
   
   dispatch "revDocsOpenAPIDatabase" to stack "revDocsParser" with tLocation
   put the result into tConnection
   if tConnection is not a number then
      ideThrow "unable to open database", tConnection
   end if
   
   put tConnection into sConnectionsA[tKey]
   if tKey is "cache" then
      ideDocsRefreshCache tConnection, tLocation
   end if
   return tConnection
end ideDocsInitialize

private function __fetchDocsData pAPI, pLibraryName, pEntryName, pType
   # Ensure we have a connection
   local tConnection
   try
      ideDocsInitialize
      put the result into tConnection
   catch tError
      return tError
   end try
   
   # Find the api id
   local tSQL, tAPIID, tResult
   if pAPI is not empty then
      put "SELECT api_id FROM apis WHERE api_name = :1" into tSQL
      put revDataFromQuery(comma, return, tConnection, tSQL, "pAPI") into tAPIID
      
      put the result into tResult
      if tResult is not a number then
         return "error finding api id for" && pAPI & return & tResult
      end if
   end if
   
   local tRecordSet, tDataSet, tParamCount
   
   put "SELECT entry_data, library_name FROM dictionary_data" into tSQL
   
   local tWhere
   if pAPI is not empty then
      put "api_id" into tWhere[1]
   end if
   if pLibraryName is not empty then
      put "library_name" into tWhere[2]
   end if
   if pEntryName is not empty then
      put "entry_name" into tWhere[3]
   end if
   if pType is not empty then
      put "entry_type" into tWhere[4]
   end if
   
   local tWhereString
   repeat with x = 1 to 4
      if tWhere[x] is not empty then
         if tWhereString is empty then
            put " WHERE" && tWhere[x] & "=:" & x into tWhereString
         else
            put " AND" && tWhere[x] & "=:" & x after tWhereString
         end if
         put " COLLATE NOCASE" after tWhereString
      end if
   end repeat
   
   put tWhereString after tSQL

   # Execute the query, keeping the record set ID.
   put revQueryDatabase(tConnection, tSql, "tAPIID", "pLibraryName", "pEntryName", "pType") into tRecordSet
   if the result is not a number then
      return "entry" && pEntryName && "not found" & return & the result
   end if
   
   # Get the docs data from the record set
   local tCount, tMoreRecords, tData, tLibrary
   put true into tMoreRecords
   repeat while tMoreRecords
      get revDatabaseColumnNamed(tRecordSet, "entry_data", "tData")
      if tData is not empty then 
         get revDatabaseColumnNamed(tRecordSet, "library_name", "tLibrary")
         add 1 to tCount
         put tData into tDataSet[tCount]["data"]
         put tLibrary into tDataSet[tCount]["library"]
      end if
      revMoveToNextRecord tRecordSet
      put the result into tMoreRecords
   end repeat
   
   # Close the record set
   revCloseCursor tRecordSet
   
   return tDataSet
end __fetchDocsData

private function __ideDocsFetchData pAPI, pLibraryName, pEntryName, pType
   # Fetch the data
   local tDataA
   put __fetchDocsData(pAPI, pLibraryName, pEntryName, pType) into tDataA
   
   local tDecodedDataA
   repeat for each key tCount in tDataA
      put arrayDecode(tDataA[tCount]["data"]) into tDecodedDataA[tCount]
      put tDataA[tCount]["library"] into tDecodedDataA[tCount]["library"]
   end repeat
   
   # Return the decoded array
   return tDecodedDataA
end __ideDocsFetchData

private function ideDocsFetchElementOfType pAPI, pLibraryName, pEntryName, pType, pElement
   local tDataA
   put __ideDocsFetchData(pAPI, pLibraryName, pEntryName, pType) into tDataA
   
   return tDataA[1][pElement]
end ideDocsFetchElementOfType

private function ideDocsFetchDataOfType pAPI, pLibraryName, pEntryName, pType
   local tDataA
   put  __ideDocsFetchData(pAPI, pLibraryName, pEntryName, pType) into tDataA
   return tDataA[1]
end ideDocsFetchDataOfType

private function ideDocsFetchData pAPI, pLibraryName, pEntryName
   return __ideDocsFetchData(pAPI, pLibraryName, pEntryName)
end ideDocsFetchData

/* 
Fetch the data for LCS entries with name <pEntryName>, including extensions

Returns:
A numerically keyed array, each element of which is the array
of data 
pertaining to a LiveCode Script API entry with the given name.
*/
function ideDocsFetchScriptData pEntryName
   return ideDocsFetchData("livecode_script", "", pEntryName)
end ideDocsFetchScriptData

/* 
Fetch the data for LiveCode script dictionary entries with name <pEntryName>

Returns:
A numerically keyed array, each element of which is the array
of data 
pertaining to a  LiveCode script dictionary entry with the given name.
*/
function ideDocsFetchLCSData pEntryName
   return ideDocsFetchData("livecode_script", "LiveCode Script", pEntryName)
end ideDocsFetchLCSData

/* 
Fetch the data for the LiveCode script dictionary entry with name <pEntryName>
and type <pType>

Returns:
An array
of data pertaining to the unique LiveCode script dictionary entry with the 
given name and type.
*/
function ideDocsFetchLCSDataOfType pEntryName, pType
   return ideDocsFetchDataOfType("livecode_script", "LiveCode Script", pEntryName, pType)
end ideDocsFetchLCSDataOfType

/* 
Fetch a specific element of the array of data for the LiveCode script dictionary entry 
with name <pEntryName> and type <pType>.

Returns:
Either a string or an array
of data describing the element of the array of data
pertaining to the LiveCode script dictionary entry with the given name and type.
*/
function ideDocsFetchLCSElementOfType pEntryName, pType, pElement
   return ideDocsFetchElementOfType("livecode_script", "LiveCode Script", pEntryName, pType, pElement)
end ideDocsFetchLCSElementOfType

/* 
Fetch all docs element of the given type in the LiveCode script dictionary.

Returns:
A numerically keyed array of data, each element of which is an array of data
pertaining to a LiveCode script dictionary entry with the given type.
*/
function ideDocsFetchLCSElementsOfType pType
   return __ideDocsFetchData("livecode_script", "LiveCode Script", "", pType)
end ideDocsFetchLCSElementsOfType

/* 
Fetch the data for LiveCode builder dictionary entries with name <pEntryName>

Returns:
A numerically keyed array, each element of which is the array
of data 
pertaining to a LiveCode builder dictionary entry with the given name.
*/
function ideDocsFetchLCBData pEntryName
   return ideDocsFetchData("livecode_builder", "LiveCode Builder", pEntryName)
end ideDocsFetchLCBData

/* 
Fetch the data for the LiveCode builder dictionary entry with name <pEntryName>
and type <pType>

Returns:
An array
of data pertaining to the unique LiveCode builder dictionary entry with the 
given name and type.
*/
function ideDocsFetchLCBDataOfType pEntryName, pType
   return ideDocsFetchDataOfType("livecode_builder", "LiveCode Builder", pEntryName, pType)
end ideDocsFetchLCBDataOfType

/* 
Fetch a specific element of the array of data for the LiveCode builder dictionary entry 
with name <pEntryName> and type <pType>.

Returns:
Either a string or an array
of data describing the element of the array of data
pertaining to the LiveCode builder dictionary entry with the given name and type.
*/
function ideDocsFetchLCBElementOfType pEntryName, pType, pElement
   return ideDocsFetchElementOfType("livecode_builder", "LiveCode Builder", pEntryName, pType, pElement)
end ideDocsFetchLCBElementOfType

/* 
Fetch all docs element of the given type in the LiveCode builder dictionary.

Returns:
A numerically keyed array of data, each element of which is an array of data
pertaining to a LiveCode builder dictionary entry with the given type.
*/
function ideDocsFetchLCBElementsOfType pType
   return __ideDocsFetchData("livecode_builder", "LiveCode Builder", "", pType)
end ideDocsFetchLCBElementsOfType

/* 
Fetch the data for entries in the API for extension <pID> with name <pEntryName>

Returns:
A numerically keyed array, each element of which is the array
of data 
pertaining to an entry in the API for the given extension with the given name.
*/
function ideDocsFetchExtensionData pID, pEntryName
   local tLibraryName, tAPI
   put revIDEExtensionProperty(pID, "title") into tLibraryName
   put revIDEExtensionProperty(pID, "api") into tAPI
   return ideDocsFetchData(tAPI, tLibraryName, pEntryName)
end ideDocsFetchExtensionData

/* 
Fetch the data for the entry in the API for extension <pID> with name <pEntryName>
and type <pType>

Returns:
An array
of data pertaining to the unique entry in the API for the given extension with the 
given name and type.
*/
function ideDocsFetchExtensionDataOfType pID, pEntryName, pType
   local tLibraryName, tAPI
   put revIDEExtensionProperty(pID, "title") into tLibraryName
   put revIDEExtensionProperty(pID, "api") into tAPI
   return ideDocsFetchDataOfType(tAPI, tLibraryName, pEntryName, pType)
end ideDocsFetchExtensionDataOfType

/* 
Fetch a specific element of the array of data for the entry in the API for extension <pID>  
with name <pEntryName> and type <pType>.

Returns:
Either a string or an array
of data describing the element of the array of data
pertaining to the entry in the API for the given extension with the given name and type.
*/
function ideDocsFetchExtensionElementOfType pID, pEntryName, pType, pElement
   local tLibraryName, tAPI
   put revIDEExtensionProperty(pID, "title") into tLibraryName
   put revIDEExtensionProperty(pID, "api") into tAPI
   return ideDocsFetchElementOfType(tAPI, tLibraryName, pEntryName, pType, pElement)
end ideDocsFetchExtensionElementOfType

/* 
Fetch all docs element of the given type in the LiveCode script dictionary.

Returns:
A numerically keyed array of data, each element of which is an array of data
pertaining to a LiveCode script dictionary entry with the given type.
*/
function ideDocsFetchExtensionElementsOfType pID, pType
   local tLibraryName, tAPI
   put revIDEExtensionProperty(pID, "title") into tLibraryName
   put revIDEExtensionProperty(pID, "api") into tAPI
   return __ideDocsFetchData(tAPI, tLibraryName, "", pType)
end ideDocsFetchExtensionElementsOfType

/*
Returns a list of library names, one per line, which have API entries in the dictionary.
*/
function ideDocsFetchLibraryNames
   # Ensure we have a connection
   local tConnection
   try
      ideDocsInitialize
      put the result into tConnection
   catch tError
      return tError
   end try
   
   local tRecordSet, tData, tDataSet, tSQL
   put "SELECT library_name FROM dictionary_data" into tSQL
   put revQueryDatabase(tConnection, tSQL) into tRecordSet
   if the result is not a number then
      return "error fetching library names" & return & the result
   end if
   
   # Get the docs data from the record set
   local tCount, tMoreRecords
   put true into tMoreRecords
   repeat while tMoreRecords
      add 1 to tCount
      get revDatabaseColumnNamed(tRecordSet, "library_name", "tData")
      put true into tDataSet[tData]
      revMoveToNextRecord tRecordSet
      put the result into tMoreRecords
   end repeat

   # Close the record set
   revCloseCursor tRecordSet

   combine tDataSet with return as set
   sort tDataSet
   return tDataSet
end ideDocsFetchLibraryNames

/*
Fetch the data for all entries in a given library

Returns:
A numerically keyed array, each element of which is the array
of data pertaining to an entry in the given library API.
*/
function ideDocsFetchLibraryEntries pLibraryName
   return __ideDocsFetchData("", pLibraryName, "")
end ideDocsFetchLibraryEntries

/* 
Fetch the data for all entries in the LiveCode script dictionary

Returns:
A numerically keyed array, each element of which is the array
of data 
pertaining to an entry in the LiveCode script dictionary.
*/
function ideDocsFetchLCSEntries
   return ideDocsFetchLibraryEntries("LiveCode Script")
end ideDocsFetchLCSEntries

/* 
Fetch the data for all entries in the LiveCode builder dictionary

Returns:
A numerically keyed array, each element of which is the array
of data 
pertaining to an entry in the LiveCode builder dictionary.
*/
function ideDocsFetchLCBEntries
   return ideDocsFetchLibraryEntries("LiveCode Builder")
end ideDocsFetchLCBEntries

/* 
Fetch the data for all entries in the API for extension <pID>  

Returns:
A numerically keyed array, each element of which is the array
of data 
pertaining to an entry in the API for the given extension.
*/
function ideDocsFetchExtensionEntries pID
   local tLibraryName, tAPI
   put revIDEExtensionProperty(pID, "title") into tLibraryName
   put revIDEExtensionProperty(pID, "api") into tAPI
   return ideDocsFetchLibraryEntries(tAPI, tLibraryName)
end ideDocsFetchExtensionEntries

on ideDocsUpdateDatabase pAPI, pLibraryA, pDistributed
   if pDistributed is true and revEnvironmentIsInstalled() then
      exit ideDocsUpdateDatabase
   end if
   
   local tConnection
   ideDocsInitialize pDistributed
   put the result into tConnection
   
   local tResult
   revExecuteSQL tConnection,"BEGIN TRANSACTION"
   dispatch "revDocsUpdateDatabase" to stack "revDocsParser" with tConnection, pAPI, pLibraryA
   put the result into tResult
   
   if tResult is not empty then
      revExecuteSQL tConnection,"ROLLBACK"
      return tResult
   end if
   
   revExecuteSQL tConnection, "COMMIT"
   return empty
end ideDocsUpdateDatabase

# OXT-Beyond: an extension's entries stayed in the cache after it was
# uninstalled, so the Script Editor and the xTalk Assistant still found
# them (openxtalk.org p=25441). revIDEExtensionUninstall removes them with
# this: every entry of the library pLibraryName under the API pAPI goes,
# and where the distributed api.sqlite has a library of that name under
# that API (it has the xTalk dictionary's: LiveCode Script, LiveCode
# Builder and Data Grid), as when an extension the user installed was
# given one of their names, its entries come back from there. Returns
# empty when it did, else what failed. Whatever fails leaves the cache as
# it was.
command ideDocsRemoveLibrary pAPI, pLibraryName
   local tConnection
   try
      ideDocsInitialize
      put the result into tConnection
   catch tError
      return tError
   end try

   # SQLite attaches no file inside a transaction
   local tSource, tSourceUTF8, tAttached, tFailed
   put false into tAttached
   put revIDESpecialFolderPath("API") & slash & "api.sqlite" into tSource
   if there is a file tSource then
      # SQLite reads an attached file's name as UTF-8
      put textEncode(tSource, "UTF-8") into tSourceUTF8
      revExecuteSQL tConnection, "ATTACH DATABASE :1 AS oxtdist", "tSourceUTF8"
      put the result is a number into tAttached
   end if
   put ideDocsRemoveAttached(tConnection, pAPI, pLibraryName, tAttached) into tFailed
   if tAttached then
      revExecuteSQL tConnection, "DETACH DATABASE oxtdist"
   end if
   return tFailed
end ideDocsRemoveLibrary

private function ideDocsRemoveAttached pConnection, pAPI, pLibraryName, pAttached
   local tFailed, tCount

   # A cache made before any extension wrote to it has no tables
   revExecuteSQL pConnection, "CREATE TABLE IF NOT EXISTS apis(api_id integer primary key, api_name text)"
   if the result is not a number then
      return "unable to create table 'apis'" & return & the result
   end if
   revExecuteSQL pConnection, "CREATE TABLE IF NOT EXISTS dictionary_data(api_id integer," && \
         "library_name text, entry_name text, entry_type text, entry_data blob)"
   if the result is not a number then
      return "unable to create table 'dictionary_data'" & return & the result
   end if

   revExecuteSQL pConnection, "BEGIN TRANSACTION"
   if the result is not a number then
      return "unable to begin" & return & the result
   end if

   dispatch "revDocsRemoveLibrary" to stack "revDocsParser" with pConnection, pAPI, pLibraryName
   put the result into tFailed

   # The distributed entries of a library of that name under that API, if
   # the distributed file has any (a file that is no dictionary has none)
   if tFailed is empty and pAttached then
      put revDataFromQuery(tab, return, pConnection, "SELECT count(*) FROM oxtdist.dictionary_data d" && \
            "JOIN oxtdist.apis s ON s.api_id = d.api_id WHERE d.library_name = :1 AND s.api_name = :2", \
            "pLibraryName", "pAPI") into tCount
      if tCount is an integer and tCount > 0 then
         revExecuteSQL pConnection, "INSERT INTO main.apis(api_name) SELECT :1 WHERE NOT EXISTS" && \
               "(SELECT 1 FROM main.apis WHERE api_name = :1)", "pAPI"
         if the result is not a number then
            put "unable to add the API" && pAPI & return & the result into tFailed
         end if
         if tFailed is empty then
            revExecuteSQL pConnection, "INSERT INTO main.dictionary_data(api_id, library_name," && \
                  "entry_name, entry_type, entry_data) SELECT (SELECT min(a.api_id) FROM main.apis a" && \
                  "WHERE a.api_name = s.api_name), d.library_name, d.entry_name, d.entry_type," && \
                  "d.entry_data FROM oxtdist.dictionary_data d JOIN oxtdist.apis s ON s.api_id = d.api_id" && \
                  "WHERE d.library_name = :1 AND s.api_name = :2", "pLibraryName", "pAPI"
            if the result is not a number then
               put "unable to copy the distributed entries of" && pLibraryName & return & the result into tFailed
            end if
         end if
      end if
   end if

   if tFailed is empty then
      revExecuteSQL pConnection, "COMMIT"
      if the result is not a number then
         put "unable to commit" & return & the result into tFailed
      end if
   end if
   if tFailed is not empty then
      revExecuteSQL pConnection, "ROLLBACK"
   end if
   return tFailed
end ideDocsRemoveAttached

# OXT-Beyond: the docs of the externals the user added. The IDE loads every
# external of the user's Externals folder (revEnvironmentUserExternalsPath),
# as LiveCode did, but the Dictionary only ever read the docs of extensions,
# so an external's .lcdoc was ignored, and the way round it was to wrap the
# docs in an empty LiveCode Builder library (Skids, openxtalk.org p=25608).
# The .lcdoc files of that folder, beside the externals or in a folder of one
# (blur/ or blur.bundle/, and a bundle's Contents/Resources), now go in as an
# installed extension's api.lcdoc does (revIDEGetExtensionDocsData in
# revidelibrary). A folder with none, as every one had before, adds nothing.
# Returns a numerically keyed array, in the order of the files' names: "file"
# the .lcdoc, "key" its folder in the docs cache's Externals folder, and
# "title" the library it is shown under: its own "Library:" name, or else
# the name of its file (of its folder, for an api.lcdoc, less a .bundle)
function ideDocsUserExternalsDocs pFolder
   local tDocsA, tSeenA
   if pFolder is empty or there is not a folder pFolder then
      return tDocsA
   end if
   __ideDocsAddExternalsDocs pFolder, empty, tDocsA, tSeenA
   local tFolders
   put folders(pFolder) into tFolders
   sort lines of tFolders
   repeat for each line tSub in tFolders
      if tSub is empty or tSub begins with "." then
         next repeat
      end if
      __ideDocsAddExternalsDocs pFolder & slash & tSub, tSub, tDocsA, tSeenA
      __ideDocsAddExternalsDocs pFolder & slash & tSub & "/Contents/Resources", tSub, tDocsA, tSeenA
   end repeat
   return tDocsA
end ideDocsUserExternalsDocs

private command __ideDocsAddExternalsDocs pFolder, pOwner, @xDocsA, @xSeenA
   if there is not a folder pFolder then
      exit __ideDocsAddExternalsDocs
   end if
   local tFiles
   put files(pFolder) into tFiles
   filter tFiles with "*.lcdoc"
   sort lines of tFiles
   set the itemDelimiter to "."
   repeat for each line tFile in tFiles
      local tName, tKey, tTitle, tText, tCount
      if tFile begins with "." then
         next repeat
      end if
      put item 1 to -2 of tFile into tName
      if pOwner is empty then
         put tName into tKey
      else
         put pOwner & "_" & tName into tKey
         if tName is "api" then
            put pOwner into tName
            if tName ends with ".bundle" then
               delete the last item of tName
            end if
         end if
      end if
      -- (a bundle's api.lcdoc, both beside its Contents and in it, once)
      if xSeenA[tKey] is true then
         next repeat
      end if
      put true into xSeenA[tKey]

      put empty into tTitle
      put textDecode(url ("binfile:" & pFolder & slash & tFile), "utf-8") into tText
      get matchText(tText, "(?m)^[ \t]*Library:[ \t]*(\S[^\r\n]*?)[ \t]*\r?$", tTitle)
      if tTitle is empty then
         put tName into tTitle
      end if

      put the number of elements of xDocsA + 1 into tCount
      put pFolder & slash & tFile into xDocsA[tCount]["file"]
      put tKey into xDocsA[tCount]["key"]
      put tTitle into xDocsA[tCount]["title"]
   end repeat
end __ideDocsAddExternalsDocs

# OXT-Beyond: keeps the docs cache's folder of the user's externals
# (pCacheFolder) in step with pDocsA (ideDocsUserExternalsDocs): each .lcdoc
# gets its folder there, with the library it is shown under noted in it, and
# the folder of one that has gone goes, with its library's entries in the
# docs database (ideDocsRemoveLibrary), as an uninstalled extension's do.
# They stay when pDocsA still has a library of that name, or when it is one
# of pKeepTitles (the installed extensions'). Nothing here throws
constant kExternalsDocsTitleFile = "library.txt"

command ideDocsNoteUserExternalsDocs pCacheFolder, pDocsA, pKeepTitles
   local tKeepA, tTitlesA
   if pCacheFolder is empty then
      exit ideDocsNoteUserExternalsDocs
   end if
   try
      repeat for each element tDocA in pDocsA
         local tFolder, tNote
         put true into tKeepA[tDocA["key"]]
         put true into tTitlesA[tDocA["title"]]
         put pCacheFolder & slash & tDocA["key"] into tFolder
         if there is not a folder tFolder then
            __ideDocsEnsureFolder tFolder
         end if
         put textEncode(tDocA["title"], "utf-8") into tNote
         if url ("binfile:" & tFolder & slash & kExternalsDocsTitleFile) is not tNote then
            put tNote into url ("binfile:" & tFolder & slash & kExternalsDocsTitleFile)
         end if
      end repeat

      if there is not a folder pCacheFolder then
         exit ideDocsNoteUserExternalsDocs
      end if
      repeat for each line tSub in folders(pCacheFolder)
         local tTitle
         if tSub is empty or tSub is "." or tSub is ".." or tKeepA[tSub] is true then
            next repeat
         end if
         put textDecode(url ("binfile:" & pCacheFolder & slash & tSub & slash & \
               kExternalsDocsTitleFile), "utf-8") into tTitle
         if tTitle is not empty and tTitlesA[tTitle] is not true and \
               tTitle is not among the lines of pKeepTitles then
            try
               ideDocsRemoveLibrary "livecode_script", tTitle
            catch tError
            end try
         end if
         __ideDocsDeleteFolder pCacheFolder & slash & tSub
      end repeat
   catch tError
   end try
end ideDocsNoteUserExternalsDocs

private command __ideDocsEnsureFolder pFolder
   local tParent
   set the itemDelimiter to slash
   put item 1 to -2 of pFolder into tParent
   if tParent is not empty and there is not a folder tParent then
      __ideDocsEnsureFolder tParent
   end if
   create folder pFolder
end __ideDocsEnsureFolder

private command __ideDocsDeleteFolder pFolder
   repeat for each line tFile in files(pFolder)
      delete file (pFolder & slash & tFile)
   end repeat
   repeat for each line tSub in folders(pFolder)
      if tSub is not "." and tSub is not ".." then
         __ideDocsDeleteFolder pFolder & slash & tSub
      end if
   end repeat
   delete folder pFolder
end __ideDocsDeleteFolder
