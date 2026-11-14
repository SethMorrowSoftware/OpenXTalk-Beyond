script "stack_revReplicate_card_id_1002"
-- Stack file: ide/Toolset/palettes/revreplicate.rev
-- Object: stack "revReplicate" > card (id 1002)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on preOpenStack
  lock messages
  set the text of fld "hScale" to the cREVRotatePrev1 of stack "revPreferences" 
  set the text of fld "vScale" to the cREVRotatePrev2 of stack "revPreferences"
  set the text of fld "hOffset" to the cREVRotatePrev3 of stack "revPreferences"
  set the text of fld "vOffset" to the cREVRotatePrev4 of stack "revPreferences" 
  set the label of btn "Rotate" to the cREVRotatePrev5 of stack "revPreferences"
  enable btn "rotate"
  enable fld "label rotate"
  enable grc "label rotate"
  set the traversalOn of btn "rotate" to true
  repeat for each line l in (the selObj)
    if word 1 of l is not "graphic" or the style of l is not in "polygon curve" then
      disable btn "Rotate"
      disable fld "label rotate"
      disable grc "label rotate"
      set the traversalOn of btn "rotate" to false
      exit repeat
    end if
  end repeat
  set the loc of stack "revReplicate" to the loc of the topStack
  revReplicateLockIconColours
  unlock messages
end preOpenStack

-- OXT-Beyond: the padlocks' icons are tinted light in the dark appearance
on revReplicateLockIconColours
  local tDark, tError, tLock
  put false into tDark
  try
    put revIDEAppearanceIsDark() into tDark
  catch tError
  end try
  repeat for each item tLock in "offsetLockButton,scaleLockButton"
    if tDark is true then
      set the colorOverlay["color"] of btn tLock of me to "210,210,210"
      set the colorOverlay["opacity"] of btn tLock of me to 255
    else
      set the colorOverlay of btn tLock of me to empty
    end if
  end repeat
end revReplicateLockIconColours

on closeCard
  lock messages
  set the cREVRotatePrev1 of stack "revPreferences" to the text of fld "hScale"
  set the cREVRotatePrev2 of stack "revPreferences" to the text of fld "vScale"
  set the cREVRotatePrev3 of stack "revPreferences" to the text of fld "hOffset"
  set the cREVRotatePrev4 of stack "revPreferences" to the text of fld "vOffset"
  set the cREVRotatePrev5 of stack "revPreferences" to the label of btn "Rotate"
  unlock messages
end closeCard

on tabKey
  send "revSelectField" to me in 10 milliseconds
  pass tabKey
end tabKey

on revSelectField
  if word 1 of the focusedObject is "field" then select text of the focusedObject
  else select empty
end revSelectField

on openField
  select text of the target
end openField

on closeField
end closeField

on returnKey
  click at the loc of btn "OK"
end returnKey

on enterkey
  click at the loc of btn "OK"
end enterkey
