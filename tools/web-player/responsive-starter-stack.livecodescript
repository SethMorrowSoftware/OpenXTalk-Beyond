script "Responsive Starter"
-- Responsive Starter: one stack for a phone, a tablet and a desktop, with
-- the Mobile Web library. Built by
-- tools/web-player/responsive-starter.livecodescript in OXT-Beyond's
-- repository; to make your own, save a copy of it and change it.
--
-- Two lines make it responsive, in preOpenStack: mwStart (in a phone's
-- browser the stack fills the screen) and mwResponsive (the stack is laid
-- out for its size, now and whenever it changes). Most of the layout is
-- not in this script at all: each control has rules, in its mwLayout
-- custom property set, that say where it goes on a phone, a tablet and a
-- desktop. Open the Property Inspector's Custom Properties on the
-- "Nav" group, say, and choose the set mwLayout to read them. The library
-- follows them each time the stack's size changes, and then sends
-- layoutChanged, which this script uses for what rules cannot say:
-- which card the selection mark is under, and whether the place's
-- details are a pane beside the grid or a sheet over it.
--
-- Make the window narrower and wider to see the three layouts, or use
-- the buttons on the "How it works" card.

constant kTabs = "Explore,Saved,Guide"
-- the places: name|what it is|colour|best time to go|what to do there
constant kPlaceCount = 8

-- whether the Mobile Web library is there, the place picked (its number,
-- or empty), whether its details cover the screen (on a phone), the
-- places saved (a line each, their numbers), and the look ("light" or
-- "dark")
local sLibrary, sPicked, sSheet, sSaved, sLook

on preOpenStack
   put empty into sPicked
   put false into sSheet
   -- the library is in OXT-Beyond 0.2.7-rc.6.16 and later; without it,
   -- the stack keeps the desktop layout it was saved with
   put true into sLibrary
   try
      -- in a phone's browser: fill the screen, and a swipe changes tab
      mwStart the short name of me, "swipe"
      put mwAppearance() into sLook
      -- lay the stack out for its size, now and whenever it changes
      mwResponsive the short name of me
   catch tError
      put false into sLibrary
   end try
   if sLook is empty then
      put "light" into sLook
   end if
   rsTheme sLook
   rsAfterLayout
   pass preOpenStack
end preOpenStack

on closeStack
   if sLibrary then
      mwResponsive the short name of me, false
      mwStop
   end if
   pass closeStack
end closeStack

-- The stack's size changed. The rules first (mwApplyLayout), so that what
-- this script places by the controls they moved is placed from where
-- they are now; then pass the message on, as always, and the library
-- sends layoutChanged if the layout has changed
on resizeStack
   if sLibrary then
      mwApplyLayout the short name of me
   end if
   rsAfterLayout
   pass resizeStack
end resizeStack

-- A phone, a tablet or a desktop, portrait or landscape: sent by the
-- library when the stack crosses from one to another (and once at the
-- start). The rules have done the layout; this does what changes with it
on layoutChanged pClass, pOrientation
   -- the place's details are a sheet over the grid on a phone, and a pane
   -- beside it on a tablet or a desktop: a sheet open on a phone that
   -- turns into a tablet is the pane now
   if pClass is not "phone" then
      put false into sSheet
   end if
   rsAfterLayout
   pass layoutChanged
end layoutChanged

on preOpenCard
   rsAfterLayout
   pass preOpenCard
end preOpenCard

-- No field takes the keys until it is clicked: the search would take
-- the first one as the card opens, and the keys 1 to 3 with it. So the
-- search can be focused only while it is wanted (rsSearchFocus), and
-- gives the keys back when it is left
on openCard
   set the traversalOn of field "Search" of me to false
   focus on nothing
   pass openCard
end openCard

command rsSearchFocus
   set the traversalOn of field "Search" of me to true
   focus on field "Search" of me
   select after text of field "Search" of me
end rsSearchFocus

on exitField
   rsSearchLeft
   pass exitField
end exitField

on closeField
   rsSearchLeft
   pass closeField
end closeField

private command rsSearchLeft
   if the short name of the target is "Search" then
      set the traversalOn of the target to false
   end if
end rsSearchLeft

-- Follow the computer's or the browser's dark mode
on systemAppearanceChanged
   if sLibrary then
      rsTheme mwAppearance()
   end if
   pass systemAppearanceChanged
end systemAppearanceChanged

-- What this stack's layout is now: "phone", "tablet" or "desktop"
function rsClass
   if sLibrary then
      return mwLayoutClass(the short name of me)
   end if
   return "desktop"
end rsClass

private function rsInBrowser
   if sLibrary then
      return mwIsWeb()
   end if
   return the platform is "HTML5"
end rsInBrowser

-- Whether a mouse is used, so that hovering shows something
private function rsHovers
   if sLibrary then
      return mwPointer() is not "touch"
   end if
   return true
end rsHovers

-- What the rules cannot say, after each layout: the mark under the card's
-- tab, the title, the details' pane or sheet, and what the layout is
command rsAfterLayout
   local tCard, tTab, tName, tRect, tClass
   lock screen
   put the short name of this card of me into tCard
   put rsClass() into tClass
   -- the title of the card, and the search where there is something to
   -- search
   if tCard is "Guide" then
      set the text of field "Title" to "How it works"
   else
      set the text of field "Title" to tCard
   end if
   set the visible of group "Search Box" to tCard is not "Guide"
   set the visible of field "Search Hint" to field "Search" is empty
   -- the letter in the middle of the picture, whatever its height (the
   -- details are on Explore and Saved)
   if tCard is not "Guide" then
      set the topMargin of field "Photo Letter" to \
            max(0, round(the height of field "Photo Letter" / 2 - the textSize of field "Photo Letter" * 0.75))
   end if
   if tClass is "phone" then
      set the textSize of field "Title" to 22
   else
      set the textSize of field "Title" to 26
   end if
   -- the tabs' words: centred in a tab bar and the rail, from the left
   -- in the sidebar; the rail is too narrow for "How it works"
   repeat for each item tTab in kTabs
      if tClass is "desktop" then
         set the textAlign of button ("Nav" && tTab) to "left"
      else
         set the textAlign of button ("Nav" && tTab) to "center"
      end if
   end repeat
   if tClass is "tablet" then
      set the label of button "Nav Guide" to "Guide"
   else
      set the label of button "Nav Guide" to "How it works"
   end if
   -- the buttons that make the window a phone's, a tablet's or a
   -- desktop's: not in a browser, where the screen decides
   set the visible of group "Try" of card "Guide" of me to not rsInBrowser()
   -- the selection mark: under the tab of this card, a pill on a phone's
   -- tab bar and a rounded row in the rail and the sidebar
   put the rect of button ("Nav" && tCard) into tRect
   if tClass is "phone" then
      put item 1 of tRect + 14, item 2 of tRect + 8, item 3 of tRect - 14, item 4 of tRect - 8 into tRect
   else if tClass is "tablet" then
      put item 1 of tRect + 6, item 2 of tRect + 4, item 3 of tRect - 6, item 4 of tRect - 4 into tRect
   end if
   set the rect of graphic "Nav Mark" to tRect
   repeat for each item tTab in kTabs
      if tTab is tCard then
         set the textColor of button ("Nav" && tTab) to rsColor("accent")
      else
         set the textColor of button ("Nav" && tTab) to rsColor("quiet")
      end if
   end repeat
   rsShowDetail
   rsShowBadge
   -- the one line of the badge and of the search, in the middle of its
   -- pill or its box, whatever height the layout gives it
   rsCentreLine the long id of field "Badge Text"
   rsCentreLine the long id of field "Search Hint"
   rsCentreLine the long id of field "Search"
   if tCard is "Guide" then
      rsShowLive
   end if
   if tCard is "Saved" then
      set the visible of field "Saved Empty" to sSaved is empty
   end if
   unlock screen
end rsAfterLayout

-- The place's details: on a tablet or a desktop always there, as a pane
-- (with a hint until a place is picked); on a phone only while a place
-- is open, as a sheet over the grid
private command rsShowDetail
   local tShow, tName, tDetail
   -- the group is on Explore and Saved; from Guide it is still there,
   -- right for whichever of them opens next
   put the long id of group "Detail" of card "Explore" of me into tDetail
   if rsClass() is "phone" then
      put sSheet into tShow
   else
      put true into tShow
   end if
   set the visible of tDetail to tShow
   repeat for each item tName in "Photo,Photo Letter,Place Name,Place Facts,Place Text,Place Save"
      set the visible of control tName of tDetail to sPicked is not empty
   end repeat
   set the visible of field "Detail Hint" of tDetail to sPicked is empty
end rsShowDetail

-- A field of one line: its line in the middle of the field, from top to
-- bottom (a field puts its text at the top, below its topMargin)
private command rsCentreLine pField
   local tLine, tMid, tWas
   set the bottomMargin of pField to 0
   put the topMargin of pField into tWas
   put the formattedRect of line 1 of pField into tLine
   if item 4 of tLine <= item 2 of tLine then
      -- (an empty field: a line of its text size)
      put item 2 of the rect of pField + tWas into item 2 of tLine
      put item 2 of tLine + the effective textHeight of pField into item 4 of tLine
   end if
   put (item 2 of the rect of pField + item 4 of the rect of pField) / 2 into tMid
   set the topMargin of pField to max(0, round(tWas + tMid - (item 2 of tLine + item 4 of tLine) / 2))
end rsCentreLine

-- The badge: what the layout is now, as the library sees it
private command rsShowBadge
   local tText
   if sLibrary then
      put rsClass() && "·" && rsOrientation() && "·" && mwPointer() into tText
   else
      put "fixed layout (no Mobile Web library)" into tText
   end if
   set the text of field "Badge Text" to tText
end rsShowBadge

private function rsOrientation
   if the width of me > the height of me then
      return "landscape"
   end if
   return "portrait"
end rsOrientation

-- The "How it works" card's live panel: the layout now, and the rules
-- the library is following for three of the controls
command rsShowLive
   local tText, tWhat
   if not sLibrary then
      set the text of field "Live" to "The Mobile Web library is not here (it is in OXT-Beyond 0.2.7-rc.6.16 and later)."
      exit rsShowLive
   end if
   put "Layout:" && rsClass() && "·" && rsOrientation() & return after tText
   put "Window:" && the width of me && "by" && the height of me & return after tText
   put "Breakpoints:" && item 1 of mwBreakpoints() && "and" && item 2 of mwBreakpoints() & return after tText
   put "Pointer:" && mwPointer() && "·" && "Look:" && sLook & return & return after tText
   put "The rules followed now" & return after tText
   repeat for each item tWhat in "Nav,Grid,Detail"
      put tWhat & ":" && rsRuleNow(tWhat) & return after tText
   end repeat
   delete the last char of tText
   set the text of field "Live" to tText
   set the textStyle of line 6 of field "Live" to "bold"
end rsShowLive

-- The rule the library follows for a group now (the same choice it makes:
-- "<class> <orientation>", then "<class>", then "all")
private function rsRuleNow pGroup
   local tRules, tClass, tObject
   if pGroup is not "Nav" then
      -- (the grid and the details are not on the Guide card)
      put the long id of group pGroup of card "Explore" of me into tObject
   else
      put the long id of group pGroup of me into tObject
   end if
   put the customProperties["mwLayout"] of tObject into tRules
   put rsClass() into tClass
   if tRules[tClass && rsOrientation()] is not empty then
      return tRules[tClass && rsOrientation()]
   end if
   if tRules[tClass] is not empty then
      return tRules[tClass]
   end if
   return tRules["all"]
end rsRuleNow

-- The tabs: the nav's buttons, a swipe on a phone, and the keys 1 to 3
command rsGoTab pName
   local tFrom
   put the short name of this card of me into tFrom
   if pName is tFrom or pName is not among the items of kTabs then
      exit rsGoTab
   end if
   put false into sSheet
   if rsClass() is "phone" then
      lock screen for visual effect
      go card pName of stack (the short name of me)
      if itemOffset(pName, kTabs) > itemOffset(tFrom, kTabs) then
         unlock screen with visual effect push left very fast
      else
         unlock screen with visual effect push right very fast
      end if
   else
      go card pName of stack (the short name of me)
   end if
end rsGoTab

on swipe pDirection
   local tAt
   if rsClass() is not "phone" or sSheet then
      pass swipe
   end if
   put itemOffset(the short name of this card of me, kTabs) into tAt
   if pDirection is "left" and tAt < the number of items of kTabs then
      rsGoTab item tAt + 1 of kTabs
   else if pDirection is "right" and tAt > 1 then
      rsGoTab item tAt - 1 of kTabs
   end if
end swipe

-- The keyboard, for a desktop: 1, 2 and 3 change tab and / searches,
-- while no field is being typed in
on keyDown pKey
   if the selectedField is not empty then
      pass keyDown
   end if
   if pKey is among the items of "1,2,3" then
      rsGoTab item pKey of kTabs
   else if pKey is "/" and the visible of group "Search Box" then
      rsSearchFocus
   else
      pass keyDown
   end if
end keyDown

on escapeKey
   if sSheet then
      rsCloseSheet
   else
      pass escapeKey
   end if
end escapeKey

-- A place picked, in the grid or the saved ones: its details in the pane,
-- or in the sheet over the grid on a phone
command rsPick pPlace
   local tInfo
   put pPlace into sPicked
   put rsPlace(pPlace) into tInfo
   set the itemDelimiter to "|"
   set the backgroundColor of graphic "Photo" of group "Detail" to item 3 of tInfo
   set the text of field "Photo Letter" of group "Detail" to char 1 of item 1 of tInfo
   set the text of field "Place Name" of group "Detail" to item 1 of tInfo
   set the text of field "Place Facts" of group "Detail" to "Best time to go:" && item 4 of tInfo
   set the text of field "Place Text" of group "Detail" to item 2 of tInfo & "." && item 5 of tInfo
   set the itemDelimiter to comma
   rsSaveLook
   if rsClass() is "phone" then
      put true into sSheet
   end if
   rsMarkTiles
   rsShowDetail
end rsPick

command rsCloseSheet
   put false into sSheet
   rsShowDetail
end rsCloseSheet

-- Saved or not: the place's button says which
command rsToggleSave
   if sPicked is empty then
      exit rsToggleSave
   end if
   if sPicked is among the lines of sSaved then
      filter sSaved without sPicked
   else
      put sPicked & return after sSaved
      filter sSaved without empty
   end if
   rsSaveLook
   rsFillSaved
end rsToggleSave

private command rsSaveLook
   if sPicked is among the lines of sSaved then
      set the label of button "Place Save" of group "Detail" to "Saved"
      set the backgroundColor of button "Place Save" of group "Detail" to rsColor("accentSoft")
      set the borderColor of button "Place Save" of group "Detail" to rsColor("accentSoft")
      set the textColor of button "Place Save" of group "Detail" to rsColor("accent")
   else
      set the label of button "Place Save" of group "Detail" to "Save this place"
      set the backgroundColor of button "Place Save" of group "Detail" to rsColor("accent")
      set the borderColor of button "Place Save" of group "Detail" to rsColor("accent")
      set the textColor of button "Place Save" of group "Detail" to "#FFFFFF"
   end if
end rsSaveLook

-- The Saved card's grid: a copy of each saved place's card from the
-- Explore grid, laid out by the same rules
private command rsFillSaved
   local tGrid, tPlace
   lock screen
   put the long id of group "Saved Grid" of card "Saved" of me into tGrid
   repeat with i = the number of groups of tGrid down to 1
      if the short name of group i of tGrid begins with "Tile" then
         delete group i of tGrid
      end if
   end repeat
   repeat for each line tPlace in sSaved
      copy group ("Tile" && tPlace) of group "Grid" of card "Explore" of me to tGrid
   end repeat
   if sLibrary then
      mwApplyLayout the short name of me
   end if
   rsMarkTiles
   rsTheme sLook
   unlock screen
end rsFillSaved

-- The search: the cards of the grid that do not match are hidden, and
-- the grid flows again without them
command rsFilter
   local tFind, tCard, tGrid, tTile, i
   put word 1 to -1 of field "Search" into tFind
   set the visible of field "Search Hint" to field "Search" is empty
   lock screen
   repeat for each item tCard in "Explore,Saved"
      put the long id of group (rsGridName(tCard)) of card tCard of me into tGrid
      repeat with i = 1 to the number of groups of tGrid
         put the long id of group i of tGrid into tTile
         if the short name of tTile begins with "Tile" then
            set the visible of tTile to tFind is empty or \
                  (field "Name" of tTile & space & field "Blurb" of tTile) contains tFind
         end if
      end repeat
   end repeat
   if sLibrary then
      mwApplyLayout the short name of me
   end if
   unlock screen
end rsFilter

private function rsGridName pCard
   if pCard is "Saved" then
      return "Saved Grid"
   end if
   return "Grid"
end rsGridName

-- The picked place's card has a border in the accent colour
private command rsMarkTiles
   local tCard, tGrid, tTile, i
   repeat for each item tCard in "Explore,Saved"
      put the long id of group (rsGridName(tCard)) of card tCard of me into tGrid
      repeat with i = 1 to the number of groups of tGrid
         put the long id of group i of tGrid into tTile
         if the short name of tTile begins with "Tile" then
            if word 2 of the short name of tTile is sPicked then
               set the foregroundColor of graphic "Tile Back" of tTile to rsColor("accent")
               set the lineSize of graphic "Tile Back" of tTile to 2
            else
               set the foregroundColor of graphic "Tile Back" of tTile to rsColor("line")
               set the lineSize of graphic "Tile Back" of tTile to 1
            end if
         end if
      end repeat
   end repeat
end rsMarkTiles

-- A card of the grid under the mouse (not under a finger): a little
-- lighter, or darker in the dark
command rsHover pTile, pIn
   if not rsHovers() then
      exit rsHover
   end if
   if pIn then
      set the backgroundColor of graphic "Tile Back" of pTile to rsColor("hover")
   else
      set the backgroundColor of graphic "Tile Back" of pTile to rsColor("surface")
   end if
end rsHover

-- The places: name|what it is|colour|best time to go|what to do there
function rsPlace pNumber
   switch pNumber
      case 1
         return "Kyoto|Temples, gardens and quiet lanes|#F97316|April or November|" & \
               "Walk the Philosopher's Path early, before the crowds, and stay for the evening in Gion."
      case 2
         return "Reykjavik|Hot springs under the northern lights|#0EA5E9|September to March|" & \
               "Soak in a geothermal pool, then drive out of town on a clear night to see the aurora."
      case 3
         return "Lisbon|Trams, tiles and sunset viewpoints|#EAB308|May or September|" & \
               "Ride tram 28 up to Alfama and watch the sun go down from a miradouro."
      case 4
         return "Patagonia|Glaciers and granite towers|#14B8A6|December to February|" & \
               "Hike to the base of the towers at dawn, when the granite turns red."
      case 5
         return "Marrakesh|Souks, spice and riad courtyards|#EF4444|March to May|" & \
               "Lose yourself in the souks by day and eat on the square at night."
      case 6
         return "Banff|Turquoise lakes in the Rockies|#22C55E|June to September|" & \
               "Paddle a canoe on a glacier lake and look out for elk on the drive."
      case 7
         return "Hanoi|Street food and lantern-lit streets|#A855F7|October to April|" & \
               "Eat pho for breakfast, then get lost in the Old Quarter's thirty-six streets."
      case 8
         return "Cape Town|Table Mountain and two oceans|#3B82F6|November to March|" & \
               "Take the cable car up Table Mountain and drive the coast to Cape Point."
   end switch
   return empty
end rsPlace

-- The colours of the look now
function rsColor pName
   if sLook is "dark" then
      switch pName
         case "page"
            return "#0F1220"
         case "surface"
            return "#1A1F33"
         case "hover"
            return "#232946"
         case "line"
            return "#2C3350"
         case "text"
            return "#E8EAF6"
         case "quiet"
            return "#9AA0BC"
         case "accent"
            return "#8B93FF"
         case "accentSoft"
            return "#2A2F5C"
      end switch
   end if
   switch pName
      case "page"
         return "#F4F5FB"
      case "surface"
         return "#FFFFFF"
      case "hover"
         return "#F0F1FF"
      case "line"
         return "#E1E3EE"
      case "text"
         return "#1F2240"
      case "quiet"
         return "#6B6F86"
      case "accent"
         return "#4F46E5"
      case "accentSoft"
         return "#E6E8FF"
   end switch
   return "#FF00FF"
end rsColor

-- Light or dark: every control takes its colour from its role, in its
-- uRole custom property (page, surface, line, text, quiet, accent,
-- accentSoft)
command rsTheme pLook
   local tCard, tCount, i, tControl, tRole
   if pLook is not among the items of "light,dark" then
      put "light" into pLook
   end if
   put pLook into sLook
   lock screen
   set the backgroundColor of me to rsColor("page")
   repeat with tCard = 1 to the number of cards of me
      put the number of controls of card tCard of me into tCount
      repeat with i = 1 to tCount
         put the long id of control i of card tCard of me into tControl
         put the uRole of tControl into tRole
         if tRole is empty then
            next repeat
         end if
         switch word 1 of tControl
            case "graphic"
               set the backgroundColor of tControl to rsColor(tRole)
               if the uEdge of tControl is not empty then
                  set the foregroundColor of tControl to rsColor(the uEdge of tControl)
               end if
               break
            case "field"
               set the textColor of tControl to rsColor(tRole)
               if the uFill of tControl is not empty then
                  set the backgroundColor of tControl to rsColor(the uFill of tControl)
                  set the borderColor of tControl to rsColor("line")
               end if
               break
            case "button"
               set the textColor of tControl to rsColor(tRole)
               if the uFill of tControl is not empty then
                  set the backgroundColor of tControl to rsColor(the uFill of tControl)
                  set the borderColor of tControl to rsColor(the uFill of tControl)
               end if
               break
         end switch
      end repeat
   end repeat
   if sLook is "dark" then
      set the label of button "Theme" to "Light"
   else
      set the label of button "Theme" to "Dark"
   end if
   rsMarkTiles
   if sPicked is not empty then
      rsSaveLook
   end if
   rsAfterLayout
   unlock screen
end rsTheme

command rsToggleTheme
   if sLook is "dark" then
      rsTheme "light"
   else
      rsTheme "dark"
   end if
end rsToggleTheme

-- The "How it works" card's buttons, on a desktop: the window made the
-- size of a phone, a tablet or a desktop (in a browser the screen
-- decides, so they are hidden there)
command rsTrySize pWhat
   local tRect
   put the rect of me into tRect
   switch pWhat
      case "phone"
         set the rect of me to item 1 of tRect, item 2 of tRect, item 1 of tRect + 390, item 2 of tRect + 780
         break
      case "tablet"
         set the rect of me to item 1 of tRect, item 2 of tRect, item 1 of tRect + 820, item 2 of tRect + 760
         break
      case "desktop"
         set the rect of me to item 1 of tRect, item 2 of tRect, item 1 of tRect + 1240, item 2 of tRect + 780
         break
   end switch
end rsTrySize

-- A card of the grid: a tap (not a drag of the grid, which scrolls it
-- with a finger) picks its place
command rsTileDown pTile
   if sLibrary then
      mwDragScroll the long id of the owner of pTile
   end if
end rsTileDown

command rsTileUp pTile
   if sLibrary then
      if mwDragMoved() then
         exit rsTileUp
      end if
   end if
   rsPick word 2 of the short name of pTile
end rsTileUp

-- The mouse's wheel scrolls the grid (a group has no scroll bar here):
-- 65308 is the wheel turned down, 65309 up
on rawKeyDown pKey
   local tGrid
   if pKey is not among the items of "65308,65309" or the short name of this card of me is "Guide" then
      pass rawKeyDown
   end if
   put the long id of group (rsGridName(the short name of this card of me)) of this card of me into tGrid
   if pKey is 65308 then
      set the vScroll of tGrid to min(the vScroll of tGrid + 48, max(0, the formattedHeight of tGrid - the height of tGrid))
   else
      set the vScroll of tGrid to max(0, the vScroll of tGrid - 48)
   end if
end rawKeyDown

-- A field that is cut off (the guide in a small window) scrolls with a
-- finger
on mouseDown
   if the short name of the target is "Search" and word 1 of the name of the target is "field" then
      rsSearchFocus
   end if
   if sLibrary and word 1 of the name of the target is "field" and the lockText of the target then
      if the formattedHeight of the target > the height of the target then
         mwDragScroll the long id of the target
      end if
   end if
   pass mouseDown
end mouseDown
