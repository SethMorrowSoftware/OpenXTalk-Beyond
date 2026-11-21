script "_databaseDriverPath"
/*
Run by driver_path.livecodescript in an engine of its own, with -ui, so
that revdb is loaded with no driver path set, as in a standalone. The
last argument is the revdb external's file. It writes what
revGetDatabaseDriverPath gives then, and again once a path has been set,
to a file in the temporary folder; an engine that crashes writes only
the first line.
*/

on startup
   local tFile, tArguments, tExternal, tPath
   put specialFolderPath("temporary") & "/oxt-revdb-driver-path.txt" into tFile
   -- (the commandArguments is an array, from 1 to N)
   put the commandArguments into tArguments
   put tArguments[the number of elements of tArguments] into tExternal
   set the externals of the templateStack to tExternal
   create invisible stack "revdb External"
   start using it
   put "loaded" && (the externalFunctions of it is not empty) & return into url ("binfile:" & tFile)

   put revGetDatabaseDriverPath() into tPath
   revSetDatabaseDriverPath "/oxt/drivers"
   put "loaded" && true & return & "[" & tPath & "]" & return & \
         "[" & revGetDatabaseDriverPath() & "]" & return into url ("binfile:" & tFile)
   quit 0
end startup
