script "CoreServerSessionCookie"
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

/*
OXT-Beyond: the sessionCookieSecure and the sessionCookieSameSite, the
opt-in Secure and SameSite attributes of the server's session cookie. Like
the other session properties they are read and set in every engine; both
are off by default, so that the cookie is LiveCode's until a script asks.
What the server engine then sends is checked by tools/ci/server_check.py.
*/

on TestSessionCookieDefaults
   TestAssert "the sessionCookieSecure is false by default", \
         the sessionCookieSecure is false
   TestAssert "the sessionCookieSameSite is empty by default", \
         the sessionCookieSameSite is empty
end TestSessionCookieDefaults

on TestSessionCookieSecure
   set the sessionCookieSecure to true
   TestAssert "it can be set to true", the sessionCookieSecure is true
   set the sessionCookieSecure to "false"
   TestAssert "it takes a string false", the sessionCookieSecure is false
end TestSessionCookieSecure

on TestSessionCookieSecureNotABoolean
   local tError
   try
      set the sessionCookieSecure to "https"
   catch tError
   end try
   TestAssert "a value that is not a boolean is refused", tError is not empty
   TestAssert "and the property is as it was", the sessionCookieSecure is false
end TestSessionCookieSecureNotABoolean

on TestSessionCookieSameSite
   local tValue
   repeat for each item tValue in "lax,strict,none"
      set the sessionCookieSameSite to tValue
      TestAssert "it can be set to" && tValue, the sessionCookieSameSite is tValue
   end repeat
   set the sessionCookieSameSite to "Strict"
   TestAssert "the value's case does not matter, and it reads back lower case", \
         the sessionCookieSameSite is "strict"
   set the sessionCookieSameSite to empty
   TestAssert "it can be set back to empty", the sessionCookieSameSite is empty
end TestSessionCookieSameSite

on TestSessionCookieSameSiteNotAValue
   local tError
   set the sessionCookieSameSite to "lax"
   try
      set the sessionCookieSameSite to "sideways"
   catch tError
   end try
   TestAssert "a value that is none of the four is refused", tError is not empty
   TestAssert "and the property is as it was", the sessionCookieSameSite is "lax"
   set the sessionCookieSameSite to empty
end TestSessionCookieSameSiteNotAValue
