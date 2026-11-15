script "CoreEnginePropertiesProp"
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
"the properties" of an EPS or a video clip crashed the engine (issue 518,
LiveCode Community 9.6.3 too): their lists of properties name some that
the object does not answer, and the engine stored the missing value.
Such a key is now left out. A crash here ends the test run, so every
test below is one that crashed before the fix, or one that pins what
an object that never crashed still gets.
*/

on TestPropertiesOfTemplateEPS
   local tProps
   put the properties of the templateEPS into tProps
   TestAssert "the properties of the templateEPS is an array", tProps is an array
   TestAssert "it has the id", "id" is among the keys of tProps
   TestAssert "it has the name", "name" is among the keys of tProps
   TestAssert "it has the rect", "rect" is among the keys of tProps
   -- An EPS answers none of its own properties, so they are left out
   -- rather than given a value that is not there.
   TestAssert "pageCount, not answered, is left out", \
         not ("pageCount" is among the keys of tProps)
end TestPropertiesOfTemplateEPS

on TestEffectivePropertiesOfTemplateEPS
   local tProps
   put the effective properties of the templateEPS into tProps
   TestAssert "the effective properties of the templateEPS is an array", \
         tProps is an array
end TestEffectivePropertiesOfTemplateEPS

on TestPropertiesOfTemplateVideoClip
   local tProps
   put the properties of the templateVideoClip into tProps
   TestAssert "the properties of the templateVideoClip is an array", \
         tProps is an array
   TestAssert "it has the id", "id" is among the keys of tProps
   TestAssert "it has the scale", "scale" is among the keys of tProps
   TestAssert "the scale is the templateVideoClip's", \
         tProps["scale"] is the scale of the templateVideoClip
   TestAssert "it has dontRefresh", "dontRefresh" is among the keys of tProps
   -- A video clip has no playLoudness of its own.
   TestAssert "playLoudness, not answered, is left out", \
         not ("playLoudness" is among the keys of tProps)
end TestPropertiesOfTemplateVideoClip

on TestPropertiesOfCreatedEPS
   local tProps
   create EPS "issue518"
   put the properties of EPS "issue518" into tProps
   TestAssert "the properties of a created EPS is an array", tProps is an array
   TestAssert "its name is the EPS's", tProps["name"] is "issue518"
end TestPropertiesOfCreatedEPS

on TestSetPropertiesOfTemplateEPSRoundTrip
   local tProps
   put the properties of the templateEPS into tProps
   set the properties of the templateEPS to tProps
   TestAssert "the properties of the templateEPS take their own array back", \
         the properties of the templateEPS is an array
   reset the templateEPS
end TestSetPropertiesOfTemplateEPSRoundTrip

on TestPropertiesOfTemplateAudioClipUnchanged
   -- An audio clip answers all four of its properties; it must get all
   -- four, as before the fix.
   local tProps, tKeys
   put the properties of the templateAudioClip into tProps
   put the keys of tProps into tKeys
   sort lines of tKeys
   TestAssert "the templateAudioClip keeps its four keys", \
         tKeys is "altID" & return & "id" & return & "name" & return & "playLoudness"
end TestPropertiesOfTemplateAudioClipUnchanged
