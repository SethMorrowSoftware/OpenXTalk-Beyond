script "mkprobe"
on startup
   create stack "DictProbe"
   set the script of stack "DictProbe" to URL ("file:" & $PROBE_SRC)
   set the width of stack "DictProbe" to 200
   set the height of stack "DictProbe" to 100
   save stack "DictProbe" as $PROBE_DST
   write "saved " & the result & return to stdout
   quit 0
end startup
