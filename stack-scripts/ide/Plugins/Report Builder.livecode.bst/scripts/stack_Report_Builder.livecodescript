script "stack_Report_Builder"
-- Stack file: ide/Plugins/Report Builder.livecode
-- Object: stack "Report Builder"
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

--Report Builder v1.3, Terry Little ©2023. All Rights Reserved.
--This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
--as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of 
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
--Contains substack "Report"



on closeStack
   set the cPosition of stack "Report" to the topLeft of stack "Report"  --custom prop, store loc
   -- OXT-Beyond: where this stack cannot be saved (an install for all
   -- users), the Report window's place is kept in the user's preferences
   local tResult, tError
   try
      save this stack
      put the result into tResult
   catch tError
   end try
   if tResult is empty and tError is empty then
      if revIDEGetPreference("cOXTReportBuilderPosition") is not empty then
         revIDESetPreference "cOXTReportBuilderPosition", empty
      end if
   else
      revIDESetPreference "cOXTReportBuilderPosition", the cPosition of stack "Report"
   end if
   close stack "Report"  --substack
end closeStack

----------[ in button script, tabbed columns report ]
--on mouseUp  --linelist > tabbed columns report
--local tColumns, tList, tEnd, tReport
answer "Please choose number of columns for report." with "Cancel" or "3" or "2" titled "Tabbed Columns"
if it = "Cancel" then exit to top
put it into tColumns
put fld 1 into tList
filter lines of tList without empty  --blank
filter lines of tList without "--*"  --ignore
put number(lines in tList) into tEnd
repeat with i = 1 to tEnd step tColumns
   if tColumns = "2" then put line i of tList &tab& line i+1 of tList &cr after tReport
   else put line i of tList &tab& line i+1 of tList &tab& line i+2 of tList &cr after tReport
end repeat
delete char -1 of tReport  --cr
filter lines of tReport without tab &"*"  --blank
put tReport into fld 2
--end mouseUp
----------
