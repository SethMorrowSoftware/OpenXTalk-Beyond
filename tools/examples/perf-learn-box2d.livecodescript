script "OXTPerfLearnBox2D"
-- OXT-Beyond: measures what the two Box2D Learn stacks, "Learn Box2D"
-- and "Learn Box2Dxt Kit", cost the computer, lesson by lesson, on a real
-- engine with Box2Dxt and its Kit loaded.
--
--    <install>/OXT-Beyond -ui tools/examples/perf-learn-box2d.livecodescript
--
-- (on Linux, under xvfb-run where there is no display: it reads the
-- engine's own processor time from /proc/<pid>/stat, so it measures on
-- Linux only). It opens the committed stacks, or those in OXT_LEARN_BOX2D
-- and OXT_LEARN_KIT, and loads Box2Dxt and the Kit from the install it
-- runs in (or the one in OXT_INSTALL). For each card it writes a line
--
--    PERF <stack> <card> run <a> paused <b> frame <c> hidden <d> busy <e>
--
-- run      the share of one processor core (in percent) the engine used
--          while the lesson ran for three seconds, untouched
-- paused   the same, for two seconds after Pause
-- frame    the milliseconds one frame takes (the Step button, as a click
--          runs it, sixty times: a step of the world, the lesson's own
--          labStep and the drawing, with the screen updated after it)
-- hidden   the same as run, with the window hidden (on the cards in
--          kHiddenCards only: "-" on the others)
-- busy     the same as frame, after the card's button in kBusy filled
--          it with bodies, four presses ("-" on the other cards)
--
-- then "TOTAL <stack> run <sum> paused <sum> frame <sum>", and "DONE".
-- tools/examples/perf-learn-box2d.py runs it for the committed stacks and
-- for others, side by side, and checks the budgets in BUDGET there.

-- The cards also measured with their window hidden
constant kHiddenCards = "Terrain,Sprites"
-- The cards also measured busy (stack|card|the button that fills it): pressed
-- four times, then a frame is measured again, with many bodies moving
constant kBusy = "Box2D|Terrain|dropTen,Kit|Terrain|dropBalls"

local sTicksPerSecond

on startup
   local tBox2D, tKit, tInstall, tError
   set the itemDelimiter to slash
   put $OXT_LEARN_BOX2D into tBox2D
   if tBox2D is empty then
      put item 1 to -4 of the filename of me & "/ide/Resources/Examples/Remastered/Learn Box2D.oxtstack" into tBox2D
   end if
   put $OXT_LEARN_KIT into tKit
   if tKit is empty then
      put item 1 to -4 of the filename of me & "/ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack" into tKit
   end if
   put $OXT_INSTALL into tInstall
   if tInstall is empty then
      put the engine folder into tInstall
   end if
   set the itemDelimiter to comma
   -- (the kernel counts processor time in clock ticks: 100 a second on
   -- every Linux OXT-Beyond runs on)
   put 100 into sTicksPerSecond
   try
      if cpuTicks() is not a number then
         throw "cannot read the processor time from /proc"
      end if
      loadKit tInstall
      if $OXT_PERF_ONLY is not "kit" then
         measureStack tBox2D, "Box2D"
      end if
      if $OXT_PERF_ONLY is not "box2d" then
         measureStack tKit, "Kit"
      end if
   catch tError
      write "FAILED" && tError & return to stdout
      quit 1
   end try
   write "DONE" & return to stdout
   quit 0
end startup

-- Box2Dxt and the Kit, as the IDE loads them
private command loadKit pInstall
   local tFolder, tLibrary
   put pInstall & "/Extensions/org.openxtalk.box2dxt" into tFolder
   if there is no folder tFolder then
      throw "no Box2Dxt in " & pInstall
   end if
   switch the platform
      case "Linux"
         put tFolder & "/code/x86_64-linux/box2dxt.so" into tLibrary
         break
      case "Win32"
         put tFolder & "/code/x86_64-win32/box2dxt.dll" into tLibrary
         break
      default
         put tFolder & "/code/universal-mac/box2dxt.dylib" into tLibrary
   end switch
   set the revLibraryMapping["box2dxt"] to tLibrary
   load extension from file (tFolder & "/module.lcm") with resource path tFolder
   start using stack (pInstall & "/Extensions/box2dxt-kit/box2dxt-kit.livecodescript")
   if b2Version() is not 4 or b2kVersion() is not 4 then
      throw "Box2Dxt or its Kit is not version 4"
   end if
end loadKit

private command measureStack pPath, pLabel
   local tCard, tName, tRun, tPaused, tFrame, tHidden, tSumRun, tSumPaused, tSumFrame, tBusy, tDo, tCount
   go stack pPath
   put 0 into tSumRun
   put 0 into tSumPaused
   put 0 into tSumFrame
   repeat with tCard = 1 to the number of cards of stack pPath
      go card tCard of stack pPath
      put the short name of this card into tName
      if tName is "Reference" then
         next repeat
      end if
      -- (the lesson is made 20 milliseconds after the card opens; then
      -- it settles)
      waitRun 1500
      put cpuOver(3000) into tRun
      if tName is among the items of kHiddenCards then
         set the visible of stack pPath to false
         waitRun 300
         put cpuOver(3000) into tHidden
         set the visible of stack pPath to true
         waitRun 300
      else
         put "-" into tHidden
      end if
      if tCard is 1 then
         -- (the front page has no Pause or Step: its toy only runs)
         put "-" into tPaused
         put "-" into tFrame
      else
         put frameMs() into tFrame
         put cpuOver(2000) into tPaused
         add tPaused to tSumPaused
         add tFrame to tSumFrame
         dispatch "labTogglePause" to this card
      end if
      put "-" into tBusy
      repeat for each item tDo in kBusy
         replace "|" with tab in tDo
         set the itemDelimiter to tab
         if item 1 of tDo is pLabel and item 2 of tDo is tName then
            repeat with tCount = 1 to 4
               dispatch "labRun" to this card with item 3 of tDo
               waitRun 400
            end repeat
            waitRun 600
            put frameMs() into tBusy
            dispatch "labTogglePause" to this card
         end if
         set the itemDelimiter to comma
      end repeat
      add tRun to tSumRun
      write "PERF" && pLabel && tName && "run" && tRun && "paused" && tPaused && \
            "frame" && tFrame && "hidden" && tHidden && "busy" && tBusy & return to stdout
   end repeat
   write "TOTAL" && pLabel && "run" && tSumRun && "paused" && tSumPaused && \
         "frame" && format("%.2f", tSumFrame) & return to stdout
   go card 1 of stack pPath
   waitRun 300
   close stack pPath
end measureStack

-- The share of a core the engine used over pMs milliseconds, in percent
private function cpuOver pMs
   local tTicks, tStart
   put cpuTicks() into tTicks
   put the milliseconds into tStart
   waitRun pMs
   return round((cpuTicks() - tTicks) / sTicksPerSecond * 100000 / (the milliseconds - tStart))
end cpuOver

-- The milliseconds one frame takes: the Step button, sixty times
private function frameMs
   local tStart, tCount
   dispatch "labStepButton" to this card
   put the milliseconds into tStart
   repeat with tCount = 1 to 60
      dispatch "labStepButton" to this card
   end repeat
   return format("%.2f", (the milliseconds - tStart) / 60)
end frameMs

-- The engine's processor time, user and system, in clock ticks
private function cpuTicks
   local tStat
   -- (the engine reads /proc's files as empty: they say their size is 0)
   put shell("cat /proc/" & the processID & "/stat") into tStat
   -- (after the program's name in brackets: its state is word 1, and the
   -- user and system times are words 12 and 13)
   delete char 1 to offset(")", tStat) of tStat
   return word 12 of tStat + word 13 of tStat
end cpuTicks

private command waitRun pMs
   wait pMs milliseconds with messages
end waitRun
