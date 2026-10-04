script "revSplashStackBehavior"
on preOpenStack
   local tSplashPath
   
   lock messages
   -- OXT-Beyond: the IDE's appearance (home.livecodescript has set it
   -- from the preference cIDEAppearance before this first window), which
   -- can differ from the system's
   if revEnvironmentIsDark() then
      put revEnvironmentEditionProperty("skin") & "/splash.png" into tSplashPath
      set the foregroundColor of this card to white
   else
      put revEnvironmentEditionProperty("skin") & "/splash-light.png" into tSplashPath
      set the foregroundColor of this card to black
   end if
   --
   set the textfont of stack "revSplash" to "(Default)"
   set the textfont of field "moreinfo" of stack "revSplash" to "(Default)"
   set the textfont of field "Status" of stack "revSplash" to "(Default)"
      set the textfont of field "Info" of stack "revSplash" to "(Text)"
   
   --
   set the textAlign of field "status" to "left"
   set the top of field "status" to 270
   set the width of field "status" to the width of card 1 of me * 0.8
   set the left of field "status" of me to 5 -- the width of card 1 of me * 0.1
   set the filename of image "Splash" to tSplashPath
   set the id of image "Splash" to the id of stack "revIcons"
   set the location of me to the screenLoc
   set the htmlText of field "License" to revEnvironmentEditionProperty("splash_strap")
   -- OXT-Beyond: the splash art carries the product and release name; under
   -- its stitches goes "<version> · It's alive!" in grey, as the artwork
   -- was drawn (Installer/oxt-beyond/branding/draw_branding.py). Field
   -- "Info", which the stack script fills with the product and version,
   -- and OpenXTalk Lite's line in "moreinfo" are not shown.
   local tVersion
   set the itemDelimiter to "/"
   put item 1 to -3 of the filename of stack "home" & "/.version" into tVersion
   set the itemDelimiter to comma
   if there is a file tVersion then
      put textDecode(url ("binfile:" & tVersion), "utf-8") into tVersion
      replace numToCodepoint(13) with empty in tVersion
      put word 1 to -1 of line 1 of tVersion into tVersion
   else
      put empty into tVersion
   end if
   if tVersion is not empty then put " " & numToCodepoint(0x00B7) & " " after tVersion
   hide field "Info" of me
   set the dontWrap of field "moreinfo" of me to true
   set the textAlign of field "moreinfo" of me to "left"
   set the textSize of field "moreinfo" of me to 20
   set the textStyle of field "moreinfo" of me to "plain"
   set the rect of field "moreinfo" of me to 24,134,560,170
   if revEnvironmentIsDark() then
      set the foregroundColor of field "moreinfo" of me to 154,163,173
   else
      set the foregroundColor of field "moreinfo" of me to 74,82,92
   end if
   put tVersion & "It" & numToCodepoint(0x2019) & "s alive!" into field "moreinfo" of me
   -- The field's text keeps the size and style it was saved with
   set the textSize of char 1 to -1 of field "moreinfo" of me to 20
   set the textStyle of char 1 to -1 of field "moreinfo" of me to "plain"
   set the foregroundColor of char 1 to -1 of field "moreinfo" of me to empty

   unlock messages
end preOpenStack

setProp statusMessage pMessage
   put pMessage into field "status" of me
end statusMessage
