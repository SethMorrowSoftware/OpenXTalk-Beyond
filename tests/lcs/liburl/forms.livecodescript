script "TestlibUrlForms"

on TestSetup
   TestSkipIfNot "platform", "MacOS,Win32,Linux"
   TestSkipIf "environment", "server"
   
   if not TestIsInStandalone() then
      local tLibURl
      put TestGetEngineRepositoryPath() & "/ide-support/revliburl.livecodescript" into tLibUrl
      send "extensionInitialize" to stack tLibUrl
   end if
end TestSetup


on TestForm
   put empty into tForm
   put "name" into tName
   put "message" into tMessage
   put libURLMultipartFormData (tForm, "name", tName, "message", tMessage) into tError
   TestAssert "form created", tError is empty
   
   set the httpHeaders to line 1 of tForm
   delete line 1 of tForm
   
   put "<file>" &  TestGetInputFile("last, first.txt") into tFile
   put "text/plain" into tType
   put "binary" into tEnc
   put libURLMultipartFormAddPart(tForm,"file", tFile, tType, tEnc) into tError
   TestAssert "file successfully added to form", tError is empty
   
   set the httpHeaders to empty
end TestForm

-- What the test's server read: the request's header lines and its body
local sFormRequest, sFormBody

on TestMultipartFormPost
   TestSkipIf "stack", "StandaloneTestRunnerMainstack"

   local tForm, tError, tHeader, tBoundary, tBody, tPort, tResult
   put empty into tForm
   put libURLMultipartFormData(tForm, "name", "dave", \
         "message", "hello" & return & "world") into tError
   TestAssert "form created", tError is empty
   put libURLMultipartFormAddPart(tForm, "file", \
         "<file>" & TestGetInputFile("last, first.txt"), "text/plain", "binary") into tError
   TestAssert "file added to the form", tError is empty

   -- Strict multipart checks on web servers reject a quoted boundary
   -- (ModSecurity) and a Content-Transfer-Encoding header (RFC 7578, and
   -- the OWASP Core Rule Set).
   put line 1 of tForm into tHeader
   TestAssert "the form's header", \
         tHeader begins with "Content-type: multipart/form-data; boundary="
   put char (offset("boundary=", tHeader) + 9) to -1 of tHeader into tBoundary
   TestAssert "the boundary is not quoted", quote is not in tBoundary and tBoundary is not empty
   put line 2 to -1 of tForm into tBody
   TestAssert "no part has a Content-Transfer-Encoding", \
         "Content-transfer-encoding" is not in tBody

   -- Post the form to a server of this process, and compare what it reads.
   put empty into sFormRequest
   put empty into sFormBody
   accept connections on port 0 with message "FormServerAccept"
   put it into tPort
   set the httpHeaders to tHeader
   post tBody to url ("http://127.0.0.1:" & tPort & "/form")
   put the result into tResult
   set the httpHeaders to empty
   close socket tPort

   TestAssert "the post succeeded", tResult is empty and it is "ok"
   TestAssert "the request has the form's Content-Type", \
         crlf & tHeader & crlf is in sFormRequest
   TestAssert "the Content-Length is the body's", \
         crlf & "Content-Length: " & the number of bytes of tBody & crlf is in sFormRequest

   set the caseSensitive to true
   TestAssert "the server got the body unchanged", sFormBody is tBody
   TestAssert "the body has no doubled carriage returns", \
         numToChar(13) & numToChar(13) is not in sFormBody
   TestAssert "the body begins with the boundary and a CRLF", \
         sFormBody begins with "--" & tBoundary & crlf
   TestAssert "the text part's headers end with a blank line", \
         "Content-Disposition: form-data; name=" & quote & "message" & quote & crlf & crlf & \
         "hello" & return & "world" & crlf is in sFormBody
   TestAssert "the file part is intact", \
         "Content-Type: text/plain" & crlf & crlf & "A test" & crlf is in sFormBody
   TestAssert "the body ends with the final boundary", \
         sFormBody ends with crlf & "--" & tBoundary & "--"
end TestMultipartFormPost

on FormServerAccept pSocket
   read from socket pSocket until crlf & crlf with message "FormServerReadHeaders"
end FormServerAccept

on FormServerReadHeaders pSocket, pRequest
   local tLength, tLine
   put pRequest into sFormRequest
   put 0 into tLength
   repeat for each line tLine in pRequest
      if tLine begins with "Content-Length:" then
         put word 2 of tLine into tLength
         replace numToChar(13) with empty in tLength
      end if
   end repeat
   if tLength > 0 then
      read from socket pSocket for tLength chars with message "FormServerReadBody"
   else
      FormServerReadBody pSocket, empty
   end if
end FormServerReadHeaders

on FormServerReadBody pSocket, pBody
   put pBody into sFormBody
   write "HTTP/1.1 200 OK" & crlf & "Content-Length: 2" & crlf & \
         "Connection: close" & crlf & crlf & "ok" to socket pSocket
end FormServerReadBody
