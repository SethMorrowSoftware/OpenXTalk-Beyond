script "oxt_print_probe"
-- For a probe only, and removed before its pull request merges: a card
-- with text, a filled graphic and a field of white text on black, printed
-- to PDF and exported as PNG, GIF and JPEG snapshots, on the Mac
-- (richmond62 on 0.2.7-rc.6.4, macOS 12 Intel: "The PDF produced a white
-- document", and a snapshot of white text on black that should have been
-- "an inversion of the one above").
--
-- Two ways to run it:
--    in the IDE, by tools/ci/ui_tour.py --script (the tour's protocol:
--       OXT_TOUR_OUT, OXT_TOUR_LOG; one step, print-probe)
--    headless: the engine with -ui and this file, OXT_PROBE_HEADLESS=1 and
--       OXT_PROBE_OUT the folder; the lines go to stdout

local sOut, sLog, sStarted

on startup
   if $OXT_PROBE_HEADLESS is not "1" then pass startup
   put true into sStarted
   put $OXT_PROBE_OUT into sOut
   put empty into sLog
   probeRecord "STARTED"
   probeRun
   quit 0
end startup

on openStack
   if $OXT_PROBE_HEADLESS is "1" or sStarted is true then pass openStack
   put true into sStarted
   put $OXT_TOUR_OUT into sOut
   put $OXT_TOUR_LOG into sLog
   hide stack "oxt_print_probe"
   send "probeWhenStarted 0" to me in 1 second
   pass openStack
end openStack

on probeWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then put the cREVLaunching of stack "Home" into tLaunching
   if tLaunching is true and pTries < 120 then
      send "probeWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "probeInIDE" to me in 2 seconds
   end if
end probeWhenStarted

on probeInIDE
   probeRecord "STARTED"
   probeRun
   probeRecord "DONE"
end probeInIDE

command probeRun
   local tError
   probeRecord "INFO platform" && the platform && the systemVersion && the processor
   probeRecord "INFO version" && the version && the buildNumber
   probeRecord "INFO systemAppearance" && the systemAppearance
   try
      probeStack
      probeExports
      probeRecord "STEP print-probe ok"
   catch tError
      replace return with " | " in tError
      probeRecord "STEP print-probe FAILED" && tError
   end try
end probeRun

command probeStack
   create stack "print_probe"
   set the defaultStack to "print_probe"
   set the rect of stack "print_probe" to 100, 100, 500, 400
   set the backgroundColor of stack "print_probe" to "white"
   create field "Words"
   set the rect of field "Words" to 20, 20, 380, 120
   set the textSize of field "Words" to 24
   set the text of field "Words" to "Hello from OXT-Beyond"
   create graphic "Box"
   set the style of graphic "Box" to "rectangle"
   set the filled of graphic "Box" to true
   set the backgroundColor of graphic "Box" to "red"
   set the rect of graphic "Box" to 20, 140, 180, 260
   create field "Dark"
   set the rect of field "Dark" to 200, 140, 380, 260
   set the backgroundColor of field "Dark" to "black"
   set the foregroundColor of field "Dark" to "white"
   set the textSize of field "Dark" to 20
   set the text of field "Dark" to "White on black"
   go stack "print_probe"
   wait 500 milliseconds with messages
end probeStack

command probeExports
   local tFile, tFormat, tObject, tWhat
   -- the card printed to PDF, as a stack prints it
   put sOut & "/card.pdf" into tFile
   open printing to pdf tFile
   probeRecord "INFO open printing to pdf: [" & the result & "]"
   print this card
   probeRecord "INFO print this card: [" & the result & "]"
   close printing
   probeRecord "INFO close printing: [" & the result & "]"
   if there is a file tFile then
      probeRecord "INFO card.pdf" && the number of bytes of URL ("binfile:" & tFile) && "bytes"
   else
      probeRecord "INFO card.pdf was not written"
   end if
   -- the card and the white-on-black field exported as snapshots
   repeat for each item tWhat in "card,dark"
      if tWhat is "card" then
         put the long id of this card into tObject
      else
         put the long id of field "Dark" into tObject
      end if
      repeat for each item tFormat in "PNG,GIF,JPEG"
         put sOut & "/" & tWhat & "-export." & toLower(tFormat) into tFile
         if tFormat is "PNG" then
            export snapshot from tObject to file tFile as PNG
         else if tFormat is "GIF" then
            export snapshot from tObject to file tFile as GIF
         else
            export snapshot from tObject to file tFile as JPEG
         end if
         probeRecord "INFO export snapshot" && tWhat && tFormat & ": [" & the result & "]" && \
               (there is a file tFile)
      end repeat
   end repeat
   -- and the screen around the stack, for comparison (the IDE only)
   if the environment is "development" and $OXT_PROBE_HEADLESS is not "1" then
      export snapshot from rect (the rect of stack "print_probe") to file (sOut & "/screen.png") as PNG
      probeRecord "INFO screen snapshot: [" & the result & "]"
   end if
   -- the field's own colours, as a script reads them
   probeRecord "INFO Dark backgroundColor" && the backgroundColor of field "Dark" && \
         "effective" && the effective backgroundColor of field "Dark" && \
         "opaque" && the opaque of field "Dark"
   -- (a property new in 0.2.7-rc.6.4: through do, so that the script
   -- compiles on an engine without it)
   local tUse, tError
   try
      do "put the useSystemWindowColor into tUse"
   catch tError
      put "(no such property)" into tUse
   end try
   probeRecord "INFO useSystemWindowColor" && tUse
end probeExports

command probeRecord pLine
   if sLog is empty then
      write pLine & return to stdout
   else
      put textEncode(pLine & lf, "UTF-8") after URL ("binfile:" & sLog)
   end if
end probeRecord
