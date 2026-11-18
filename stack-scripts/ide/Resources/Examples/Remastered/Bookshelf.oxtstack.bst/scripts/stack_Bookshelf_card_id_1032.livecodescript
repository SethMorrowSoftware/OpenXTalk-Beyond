script "stack_Bookshelf_card_id_1032"
-- Stack file: ide/Resources/Examples/Remastered/Bookshelf.oxtstack
-- Object: stack "Bookshelf" > card "Book Data" (id 1032)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- The Library: the card "Book Data" of Book
-- Library. Its handlers run the window: the
-- list of books, the search, and the book's
-- details. The database handlers they call
-- are in the stack's script.
-- What the remaster added or changed is
-- marked (remaster). The buttons are the
-- window's, which are groups: "group Save"
-- where the sample said "button Save".

on preOpenCard
   layoutCard

   ## Clear the search and entry fields
   put empty into field "Search Term"
   clearFields
   -- (remaster) and nothing is being edited
   lockFields
   set the enabled of group "Cancel" to false
   set the enabled of group "Save" to false
   buttonsLook

   ## Populate the list of books
   listBooks
   pass preOpenCard -- (remaster) so that the window lays the card out
end preOpenCard

command clearFields
   ## Clear the entry fields
   put empty into field "Title"
   put empty into field "Author"
   put empty into field "Comments"
   put empty into field "BookID"

   ## Set the Option menu to the default
   set the label of button "Status" to "On Shelf"
   detailsLook -- (remaster) and a blank cover
end clearFields

command editFields
   ## Make the entry fields editable
   set the lockText of field "Title" to false
   set the lockText of field "Author" to false
   set the lockText of field "Comments" to false
   set the enabled of button "Status" to true

   set the showBorder of field "Title" to true
   set the showBorder of field "Author" to true
   show group "StatusBox" -- (remaster) the Status menu's box, as the fields have their borders
   detailsLook -- (remaster)
end editFields

command lockFields
   ## Make the fields read only
   set the lockText of field "Title" to true
   set the lockText of field "Author" to true
   set the lockText of field "Comments" to true
   set the enabled of button "Status" to false

   set the showBorder of field "Title" to false
   set the showBorder of field "Author" to false
   hide group "StatusBox" -- (remaster)
   detailsLook -- (remaster)
end lockFields

command listBooks
   local tList
   put booksListAll() into tList
   put tList into field "List"
   listLook -- (remaster) the list's colours, and words when it is empty
end listBooks

command searchBooks
   local tSearchTerm, tList

   put field "Search Term" into tSearchTerm
   put booksSearch(tSearchTerm) into tList
   put tList into field "List"
   listLook -- (remaster)
end searchBooks

command showBookDetails
   local tLineNumber, tBookDetails

   ## Get the hilited line number of the list
   ## Get the text of that line
   put the hilitedLine of field "List" into tLineNumber
   if tLineNumber is empty then exit showBookDetails -- (remaster) no book chosen
   put line tLineNumber of field "List" into tBookDetails

   ## Set the item delimiter to tab
   ## This allows us to refer to each tab separated item
   set the itemDelimiter to tab
   put item 1 of tBookDetails into field "Title"
   put item 2 of tBookDetails into field "Author"
   set the label of button "Status" to item 3 of tBookDetails
   put item 4 of tBookDetails into field "Comments"

   ## The BookID is an invisible field, used to identify the book
   put item 5 of tBookDetails into field "BookID"

   ## Make the fields non editbale
   lockFields

   ## Disable the Cancel and Save buttons
   set the disabled of group "Cancel" to true
   set the disabled of group "Save" to true
   buttonsLook -- (remaster)
end showBookDetails

command saveBook
   local tTitle, tAuthor, tStatus, tComments, tBookID
   local tPath

   ## Retrieve the user input
   put field "Title" into tTitle
   put field "Author" into tAuthor
   put the label of button "Status" into tStatus
   put field "Comments" into tComments
   put field "BookID" into tBookID

   -- (remaster) A book needs a title: without one, Save says so
   if tTitle is empty then
      answer "Please give the book a title first."
      exit saveBook
   end if

   ## Check for return chracters in comments
   ## Not allowed as our data is line separated
   ## Replace with a space instead
   replace return with space in tComments
   -- (remaster) the same for the title and the author; and no tabs, which
   -- separate the list's columns
   replace return with space in tTitle
   replace return with space in tAuthor
   replace tab with space in tTitle
   replace tab with space in tAuthor
   replace tab with space in tComments

   if tBookID is empty then
      ## This is a new book
      ## Add the book to the database
      bookAdd tTitle, tAuthor, tStatus, tComments
   else
      ## This is an update
      ## Only the status can be updated
      bookUpdate tBookID, tTitle, tAuthor, tStatus, tComments
   end if

   ## Update the list of books
   ## Clear the entry fields
   lock screen
   listBooks
   clearFields
   -- (remaster) and back to reading, as when a book is chosen
   lockFields
   set the enabled of group "Cancel" to false
   set the enabled of group "Save" to false
   buttonsLook
   focus on nothing
   unlock screen
end saveBook

## Prepare the details pane for a new book entry
command newBook
   lock screen
   clearFields
   set the hilitedLines of field "List" to empty -- (remaster) no book chosen in the list

   ## Make the fields editbale
   editFields

   ## Enable the Cancel and Save buttons
   set the enabled of group "Cancel" to true
   set the enabled of group "Save" to true
   buttonsLook -- (remaster)

   focus on field "title"
   unlock screen
end newBook

## Prepare the details pane to edit a book entry
command editBook
   -- (remaster) With no book chosen, there is nothing to edit
   if the hilitedLine of field "List" is empty then
      answer "Please choose a book in the list first."
      exit editBook
   end if
   lock screen
   showBookDetails

   ## Make the fields editbale
   editFields

   ## Enable the Cancel and Save buttons
   set the enabled of group "Cancel" to true
   set the enabled of group "Save" to true
   buttonsLook -- (remaster)

   focus on field "title"
   unlock screen
end editBook

command deleteBook
   local tLineNumber, tBookID

   ## Get the hilited line number of the list
   ## Get the title of that book
   set the itemDel to tab
   put the hilitedLine of field "List" into tLineNumber
   -- (remaster) With no book chosen, there is nothing to delete
   if tLineNumber is empty then
      answer "Please choose a book in the list first."
      exit deleteBook
   end if
   put item 5 of line tLineNumber of field "List" into tBookID

   ## Check the user wants to delete the book
   answer "Are you sure you want to delete this book?" with "OK" or "Cancel"
   if it is "OK" then

      ## Delete the selected book
      bookDelete tBookID

      ## Refresh the list
      clearFields
      listBooks
   end if
end deleteBook

command layoutCard
   ## This handler lays out all controls based on the size of the stack
   -- (remaster) on the stage: the window less the sidebar at its left,
   -- the header at its top, and a margin. The list takes the left half,
   -- and the book's details the right
   local tLeftPaneWidth, tLeft, tTop, tRight, tBottom, tDiv, tX
   put 256 into tLeft
   put 104 into tTop
   put the width of this stack - 24 into tRight
   put the height of this stack - 24 into tBottom
   put round((tRight - tLeft) / 2) - 8 into tLeftPaneWidth
   put tLeft + tLeftPaneWidth into tDiv

   set the rect of graphic "verticalDiv" of me to tDiv, tTop + 1, tDiv + 1, tBottom - 1

   ## The search, the list and its buttons, on the left
   set the rect of graphic "SearchBox" of me to tLeft + 16, tTop + 16, tDiv - 16, tTop + 52
   set the topLeft of image "SearchIcon" of me to tLeft + 30, tTop + 26
   set the topRight of group "Search" of me to tDiv - 20, tTop + 20
   set the rect of field "Search Term" of me to tLeft + 50, tTop + 19, the left of group "Search" of me - 6, tTop + 49
   set the topLeft of field "SearchHint" of me to tLeft + 54, tTop + 24
   set the rect of field "List Titles" of me to tLeft + 16, tTop + 60, tDiv - 16, tTop + 84
   set the rect of field "List" of me to tLeft + 16, tTop + 84, tDiv - 16, tBottom - 64
   set the loc of field "ListEmpty" of me to the loc of field "List" of me
   set the topLeft of group "Add Book" of me to tLeft + 16, tBottom - 52
   set the topLeft of group "Edit Book" of me to the right of group "Add Book" of me + 8, tBottom - 52
   set the topRight of group "Delete Book" of me to tDiv - 16, tBottom - 52

   ## The book's details, on the right: its cover, and beside it what it is
   set the topLeft of group "Cover" of me to tDiv + 4, tTop + 8
   put the right of graphic "CoverArt" of me + 12 into tX
   set the topLeft of field "Title Label" of me to tX + 8, tTop + 16
   set the rect of field "Title" of me to tX, tTop + 36, tRight - 16, tTop + 68
   set the topLeft of field "Author Label" of me to tX + 8, tTop + 74
   set the rect of field "Author" of me to tX, tTop + 94, tRight - 16, tTop + 124
   set the topLeft of field "Status Label" of me to tX + 8, tTop + 130
   set the topLeft of group "StatusBox" of me to tX, tTop + 150
   set the rect of button "Status" of me to the rect of group "StatusBox" of me
   set the topLeft of field "Comments Label" of me to tDiv + 18, tTop + 186
   set the rect of graphic "CommentsBox" of me to tDiv + 16, tTop + 208, tRight - 16, tBottom - 68
   set the rect of field "Comments" of me to tDiv + 18, tTop + 210, tRight - 18, tBottom - 70
   set the topRight of group "Save" of me to tRight - 16, tBottom - 52
   set the topRight of group "Cancel" of me to the left of group "Save" of me - 8, tBottom - 52
end layoutCard

-- (remaster) The list's look: each book's status in its colour, a scroll
-- bar only when the books do not fit, and words in the list when it is
-- empty, which say why
command listLook
   local tCount, tIndex, tText
   put the number of lines of field "List" into tCount
   set the itemDelimiter to tab
   repeat with tIndex = 1 to tCount
      set the textColor of line tIndex of field "List" to "15,23,42"
      set the textColor of item 2 of line tIndex of field "List" to "71,85,105"
      if item 3 of line tIndex of field "List" is "On Loan" then
         set the textColor of item 3 of line tIndex of field "List" to "180,83,9"
      else
         set the textColor of item 3 of line tIndex of field "List" to "4,120,87"
      end if
   end repeat
   set the itemDelimiter to comma
   set the vScrollbar of field "List" to the formattedHeight of field "List" > the height of field "List"
   set the visible of field "SearchHint" to field "Search Term" is empty
   if tCount > 0 then
      hide field "ListEmpty"
      exit listLook
   end if
   if databaseProblem() is not empty then
      put "The library could not open." & return & databaseProblem() into tText
   else if field "Search Term" is not empty then
      put "No book has" && quote & field "Search Term" & quote & return & "in its title or its author." into tText
   else
      put "There are no books yet." & return & "Add one with Add book." into tText
   end if
   set the text of field "ListEmpty" to tText
   show field "ListEmpty"
end listLook

-- (remaster) The book's cover: its title and author on a colour of its
-- own, the same each time for the same title, or blank with no book; and
-- the comments' scroll bar, only when they do not fit
command detailsLook
   local tTitle, tSum, tCodepoint, tColor, tRect, tPalette
   put field "Title" into tTitle
   put the rect of graphic "CoverArt" into tRect
   if tTitle is empty then
      put "241,245,249" into tColor
      set the fillGradient["ramp"] of graphic "CoverArt" to "0.000," & tColor & return & "1.000," & tColor
      hide graphic "CoverSpine"
      hide graphic "CoverLine"
      show image "CoverIcon"
      set the textColor of field "CoverTitle" to "148,163,184"
      set the textSize of field "CoverTitle" to 11
      if the lockText of field "Title" then
         put "No book chosen" into field "CoverTitle"
      else
         put "A new book" into field "CoverTitle"
      end if
      set the top of field "CoverTitle" to item 2 of tRect + 72
      put empty into field "CoverAuthor"
   else
      put 0 into tSum
      repeat for each codepoint tCodepoint in tTitle
         add codepointToNum(tCodepoint) to tSum
      end repeat
      -- (ten colours, a word each: the title's letters choose one)
      put "79,70,229 124,58,237 13,148,136 2,132,199 217,119,6" && \
            "225,29,72 5,150,105 234,88,12 219,39,119 71,85,105" into tPalette
      put word (tSum mod 10) + 1 of tPalette into tColor
      set the fillGradient["ramp"] of graphic "CoverArt" to "0.000," & colorMix(tColor, "255,255,255", 0.15) & return & \
            "1.000," & colorMix(tColor, "15,23,42", 0.35)
      show graphic "CoverSpine"
      show graphic "CoverLine"
      hide image "CoverIcon"
      set the textColor of field "CoverTitle" to "255,255,255"
      set the textSize of field "CoverTitle" to 13
      put tTitle into field "CoverTitle"
      set the top of field "CoverTitle" to item 2 of tRect + 14
      put field "Author" into field "CoverAuthor"
   end if
   -- (the colour runs from the top left to the bottom right)
   set the fillGradient["type"] of graphic "CoverArt" to "linear"
   set the fillGradient["from"] of graphic "CoverArt" to item 1 of tRect & comma & item 2 of tRect
   set the fillGradient["to"] of graphic "CoverArt" to item 3 of tRect & comma & item 4 of tRect
   set the fillGradient["via"] of graphic "CoverArt" to item 1 of tRect - (item 4 of tRect - item 2 of tRect) & comma & \
         item 2 of tRect + (item 3 of tRect - item 1 of tRect)
   set the vScrollbar of field "Comments" to the formattedHeight of field "Comments" > the height of field "Comments"
   -- (no book chosen, no status: "On Shelf", what a new book starts
   -- with, shows once there is a book, or one being made)
   set the visible of button "Status" to not (the lockText of field "Title" and field "BookID" is empty)
end detailsLook

-- (remaster) A colour between two: pAmount of the way from pFrom to pTo
function colorMix pFrom, pTo, pAmount
   local tOut, tIndex
   repeat with tIndex = 1 to 3
      put round(item tIndex of pFrom + (item tIndex of pTo - item tIndex of pFrom) * pAmount) & comma after tOut
   end repeat
   delete the last char of tOut
   return tOut
end colorMix

-- (remaster) Save and Cancel are the window's buttons, groups, which look
-- the same enabled or not: a disabled one fades
command buttonsLook
   local tName
   repeat for each item tName in "Cancel,Save"
      if the enabled of group tName then
         set the blendLevel of group tName to 0
      else
         set the blendLevel of group tName to 60
      end if
   end repeat
end buttonsLook
