script "SqlDate"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- HyperXTalk's "the sql date" and the convert command's "sql" format,
-- added for stacks written in HyperXTalk, and what stays as it was: "sql"
-- is no keyword, and a date in this format is still not recognised
-- unless "from sql date" names it.

on TestTheSqlDate
   local tSql, tBefore, tAfter
   -- the day before and after it, in case midnight comes between
   put the seconds into tBefore
   put the sql date into tSql
   put the seconds into tAfter
   convert tBefore to dateItems
   convert tAfter to dateItems
   TestAssert "the sql date is YYYY-MM-DD HH:MM:SS", \
         matchText(tSql, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$")
   TestAssert "the sql date has today's date", \
         char 1 to 10 of tSql is sqlDay(tBefore) or char 1 to 10 of tSql is sqlDay(tAfter)

   put the SQL Date into tSql
   TestAssert "the sql date in any case", char 5 of tSql is "-"

   -- invariant, as the internet date is
   set the useSystemDate to true
   put the sql date into tSql
   set the useSystemDate to false
   TestAssert "the sql date with the useSystemDate", \
         matchText(tSql, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$")
end TestTheSqlDate

private function sqlDay pDateItems
   return format("%04d-%02d-%02d", item 1 of pDateItems, item 2 of pDateItems, item 3 of pDateItems)
end sqlDay

on TestConvertToSql
   local tDate
   put "2026,10,24,14,30,5,7" into tDate
   convert tDate to sql date
   TestAssert "convert dateItems to sql date", tDate is "2026-10-24 14:30:05"

   put "2026,1,2,3,4,5,6" into tDate
   convert tDate to sql
   TestAssert "convert dateItems to sql", tDate is "2026-01-02 03:04:05"

   put "2026,10,24,14,30,5,7" into tDate
   convert tDate from dateItems to sql date
   TestAssert "convert from dateItems to sql date", tDate is "2026-10-24 14:30:05"
end TestConvertToSql

on TestConvertFromSql
   local tDate, tSeconds
   put "2026-10-24 14:30:05" into tDate
   convert tDate from sql date to dateItems
   TestAssert "convert from sql date to dateItems", tDate is "2026,10,24,14,30,5,7"

   put "2026-10-24" into tDate
   convert tDate from sql date to dateItems
   TestAssert "a date alone, from sql date, is midnight", tDate is "2026,10,24,0,0,0,7"

   put "2026-10-24 14:30:05" into tDate
   convert tDate from sql to dateItems
   TestAssert "convert from sql to dateItems", tDate is "2026,10,24,14,30,5,7"

   -- local time both ways
   put "2026,10,24,14,30,5,7" into tSeconds
   convert tSeconds from dateItems to seconds
   put "2026-10-24 14:30:05" into tDate
   convert tDate from sql date to seconds
   TestAssert "sql date and dateItems give the same seconds", tDate is tSeconds
   convert tDate from seconds to sql date
   TestAssert "seconds back to sql date", tDate is "2026-10-24 14:30:05"
end TestConvertFromSql

on TestConvertFromSqlRefuses
   local tDate
   put "2026-13-01 00:00:00" into tDate
   convert tDate from sql date to dateItems
   TestAssert "month 13 is refused", the result is "invalid date"
   TestAssert "a refused value is left as it was", tDate is "2026-13-01 00:00:00"

   put "2026-10-24 14:30:05 PM" into tDate
   convert tDate from sql date to dateItems
   TestAssert "text after the time is refused", the result is "invalid date"

   put "10/24/26" into tDate
   convert tDate from sql date to dateItems
   TestAssert "another format is refused", the result is "invalid date"
end TestConvertFromSqlRefuses

on TestSqlYearBefore1000
   local tDate
   -- four digits, as SQL writes a year: in two, the year 99 would read
   -- back as 1999 (the centuryCutoff)
   put "0099-10-24 14:30:05" into tDate
   convert tDate from sql date to sql date
   if the result is "invalid date" then
      -- where time_t has 32 bits (32-bit Linux), the engine converts only
      -- the years 1901 to 2038 and refuses the others
      TestAssert "a year the engine cannot convert is refused and left as it was", \
            tDate is "0099-10-24 14:30:05"
      TestSkip "a year before 1000 has four digits", "this engine converts only the years 1901 to 2038"
      exit TestSqlYearBefore1000
   end if
   TestAssert "the year 99 has four digits", tDate is "0099-10-24 14:30:05"
   convert tDate from sql date to dateItems
   TestAssert "and reads back as the year 99", item 1 to 6 of tDate is "99,10,24,14,30,5"

   put "0999,1,2,3,4,5,6" into tDate
   convert tDate from dateItems to sql date
   TestAssert "the year 999 has four digits", tDate is "0999-01-02 03:04:05"
   convert tDate from sql date to sql
   TestAssert "and keeps them", tDate is "0999-01-02 03:04:05"
end TestSqlYearBefore1000

-- What scripts saw before stays as it was

on TestSqlIsStillAName
   local sql
   put "a variable" into sql
   TestAssert "a variable named sql", sql is "a variable"
   put sql && "too" into sql
   TestAssert "a variable named sql in an expression", sql is "a variable too"
   TestAssert "a function named sql", sql(2) is 4
end TestSqlIsStillAName

function sql pValue
   if pValue is empty then put 2 into pValue
   return pValue * 2
end sql

on TestSqlCustomProperty
   -- set and read by another name too, so that a property set and read
   -- under some other name (none) would not pass
   local tName
   put "sql" into tName
   set the sql of me to "kept"
   TestAssert "a custom property named sql", the sql of me is "kept"
   TestAssert "the custom property is named sql", the tName of me is "kept"
   TestAssert "sql is among the custom keys", "sql" is among the lines of the customKeys of me
   set the tName of me to "changed"
   TestAssert "the sql of me reads it", the sql of me is "changed"
   set the sql[1] of me to "one"
   TestAssert "the sql of me with an index", the sql[1] of me is "one"
end TestSqlCustomProperty

on TestSqlVariableNamesAProperty
   -- the <variable> of an object is the property the variable names, so
   -- "the sql of" with a variable named sql reads the property it names
   local sql
   put "cSqlNamed" into sql
   set the sql of me to "named"
   TestAssert "the sql of me with a variable named sql", the cSqlNamed of me is "named"
   TestAssert "read back the same way", the sql of me is "named"
end TestSqlVariableNamesAProperty

on TestSqlTextNotRecognisedUnlessNamed
   local tDate
   TestAssert "an sql date alone is not a date", not ("2026-10-24 14:30:05" is a date)
   put "2026-10-24 14:30:05" into tDate
   convert tDate to dateItems
   TestAssert "convert without from leaves an sql date", the result is "invalid date"
end TestSqlTextNotRecognisedUnlessNamed
