script "myLib" with behavior "myBehavior"
on mouseUp
  put tsNetGetSync("https://example.com", tHeaders, tRecv, tRes, tBytes) into t
  get JSONToArray(t)
end mouseUp

function foo
  start using stack "Helpers"
end foo
