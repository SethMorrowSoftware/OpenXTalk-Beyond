script "TestStandaloneBuilderWebSplash"
-- OXT-Beyond: tests of the splash image of the HTML5 pane's Splash setting
-- (ide-support/revsaveasemscriptenstandalone.livecodescript, bwmilby's
-- request, openxtalk.org p=26115): getImageDataSize, which reads an
-- image's width and height from its header (PNG, GIF, JPEG, WebP, SVG),
-- and getSplashMarkup, the style and script that the page's head gets for
-- it. The page as built without the setting is the engine's as it was:
-- getSplashHead returns empty for an empty setting before it reads any
-- file, which TestEmptySettingAddsNothing checks in the library's text.

constant kStack = "TestStandaloneBuilderWebSplashStack"
constant kHandlers = "getSplashMarkup,getImageDataSize,getImageDataNumber"

-- A 24x24 PNG, all of it the colour 0,170,0 (tools/ci/web-deploy.livecodescript's)
-- getSplashMarkup's answer for a 24x24 splash.png, as
-- tools/ci/tests/test_web_check.py has it (SPLASH_HEAD), and so as
-- tools/ci/web_check.py reads it in the page that the IDE's builder writes
constant kSplashHead24 = "<style>.oxt-splash #status{position:fixed;top:0;left:0;right:0;bottom:0;z-index:1;margin:0;box-sizing:border-box;background-color:inherit;padding:0 16px;padding-top:calc(50vh + min(24px,60vh)/2 + 12px);padding-top:calc(50dvh + min(24px,60vh)/2 + 12px)}.oxt-splash #status::before{content:'';position:absolute;left:50%;top:50%;width:24px;height:24px;max-width:calc(100% - 32px);max-height:60%;transform:translate(-50%,-50%);background:url(splash.png) center/contain no-repeat}</style><script>(function(){var r=document.documentElement;r.classList.add('oxt-splash');document.addEventListener('DOMContentLoaded',function(){var s=document.getElementById('status'),o;function done(){if(s&&s.style.display!=='none'){return false;}r.classList.remove('oxt-splash');if(o){o.disconnect();}return true;}if(!done()){o=new MutationObserver(done);o.observe(s,{attributes:true,attributeFilter:['style']});}});})();</script>"

constant kGreenPNG = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAIAAABvFaqvAAAAHklEQVR42mNgWMVAHTRq0KhBowaNGjRq0KhBA28QADGLfpBqGLo1AAAAAElFTkSuQmCC"

-- The library's text, with its lines ending in return alone, as the file
-- has them in git (a Windows checkout may end them in CRLF)
-- (the path is written out after TestGetEngineRepositoryPath() so that
-- tools/ci/web_tests.py finds it and puts the file in the web standalone)
private function libraryText
   local tText
   put textDecode(url ("binfile:" & TestGetEngineRepositoryPath() & "/ide-support/revsaveasemscriptenstandalone.livecodescript"), "UTF-8") into tText
   replace numToChar(13) & numToChar(10) with return in tText
   return tText
end libraryText

-- The functions as the library has them, made public, in the script of a
-- button in the back scripts: the library itself does not compile in the
-- standalone engine that runs these tests, as it has commands that only
-- the IDE's engine has
on TestSetup
   local tScript, tHandlers, tStart, tEnd
   put libraryText() into tScript
   repeat for each item tHandler in kHandlers
      put lineOffset("private function" && tHandler && "p", tScript) into tStart
      put lineOffset("end" && tHandler, tScript) into tEnd
      if tStart is 0 or tEnd < tStart then
         throw "the library has no function" && tHandler
      end if
      put line tStart to tEnd of tScript & return after tHandlers
   end repeat
   replace "private function" with "function" in tHandlers
   create stack kStack
   set the defaultStack to kStack
   create button "library"
   set the script of button "library" of stack kStack to tHandlers
   if the result is not empty then
      throw "the functions do not compile:" && the result
   end if
   insert the script of button "library" of stack kStack into back
end TestSetup

on TestTeardown
   if there is a stack kStack then
      remove the script of button "library" of stack kStack from back
      delete stack kStack
   end if
end TestTeardown

--------------------------------------------------------------------------------
-- Helpers

-- The bytes whose values are the items of pList
private function bytesOf pList
   local tData
   repeat for each item tByte in pList
      put numToByte(tByte) after tData
   end repeat
   return tData
end bytesOf

-- pCount zero bytes
private function zeros pCount
   local tData
   repeat pCount times
      put numToByte(0) after tData
   end repeat
   return tData
end zeros

private command checkSize pDescription, pData, pExpected
   local tSize
   put getImageDataSize(pData) into tSize
   TestDiagnostic pDescription & ":" && tSize
   TestAssert pDescription && "is" && pExpected, tSize is pExpected
end checkSize

--------------------------------------------------------------------------------
-- Tests

on TestPngSize
   checkSize "a 24x24 PNG", base64Decode(kGreenPNG), "24,24"
   -- 700 by 300: big-endian in IHDR
   checkSize "a 700x300 PNG", bytesOf("137,80,78,71,13,10,26,10,0,0,0,13") & "IHDR" & \
         bytesOf("0,0,2,188,0,0,1,44,8,6,0,0,0"), "700,300"
end TestPngSize

on TestGifSize
   -- 320 by 200: little-endian in the screen descriptor
   checkSize "a 320x200 GIF", "GIF89a" & bytesOf("64,1,200,0,0,0,0"), "320,200"
end TestGifSize

on TestJpegSize
   local tApp0
   -- start of image, an APP0 segment (to be skipped), a fill byte, then
   -- a baseline frame header: 1024 wide, 768 high
   put bytesOf("255,224,0,16") & "JFIF" & zeros(10) into tApp0
   checkSize "a 1024x768 JPEG", bytesOf("255,216") & tApp0 & \
         bytesOf("255,255,192,0,17,8,3,0,4,0,3,1,34,0") & zeros(10), "1024,768"
   -- a progressive frame (SOF2) after a DHT segment (whose code is not a
   -- frame's)
   checkSize "a 50x40 progressive JPEG", bytesOf("255,216,255,196,0,4,0,0") & \
         bytesOf("255,194,0,17,8,0,40,0,50,3") & zeros(10), "50,40"
   checkSize "a JPEG cut short", bytesOf("255,216,255,224,0,16,0,0"), empty
end TestJpegSize

on TestWebpSize
   -- extended (VP8X): 24 bits each of the width and the height less one
   checkSize "a 2000x1000 extended WebP", "RIFF" & zeros(4) & "WEBP" & "VP8X" & zeros(4) & zeros(4) & \
         bytesOf("207,7,0,231,3,0"), "2000,1000"
   -- lossy (VP8): 14 bits each, after the frame tag and the start code
   checkSize "a 640x480 lossy WebP", "RIFF" & zeros(4) & "WEBP" & "VP8 " & zeros(4) & zeros(3) & \
         bytesOf("157,1,42,128,2,224,1"), "640,480"
   -- lossless (VP8L): 14 bits of the width less one, then 14 of the height
   checkSize "a 300x200 lossless WebP", "RIFF" & zeros(4) & "WEBP" & "VP8L" & zeros(4) & \
         bytesOf("47,43,193,49,0") & zeros(5), "300,200"
end TestWebpSize

on TestSvgSize
   checkSize "an SVG with a width and a height", \
         "<?xml version='1.0'?>" & return & "<svg xmlns='http://www.w3.org/2000/svg' width='320' height='120px'></svg>", "320,120"
   checkSize "an SVG with a viewBox only", \
         "<svg xmlns=" & quote & "http://www.w3.org/2000/svg" & quote && "viewBox=" & quote & "0 0 512 256" & quote & "/>", "512,256"
   checkSize "an SVG sized in percent, with a viewBox", \
         "<svg width='100%' height='100%' viewBox='-10,-10,64.4,32'></svg>", "64,32"
   checkSize "an SVG's stroke-width is not its width", \
         "<svg stroke-width='3' viewBox='0 0 90 60'></svg>", "90,60"
   checkSize "an SVG without a size", "<svg xmlns='http://www.w3.org/2000/svg'></svg>", empty
end TestSvgSize

on TestUnknownData
   checkSize "nothing", empty, empty
   checkSize "text", "not an image", empty
   checkSize "a PNG whose width is 0", bytesOf("137,80,78,71,13,10,26,10,0,0,0,13") & "IHDR" & \
         bytesOf("0,0,0,0,0,0,1,44,8,6,0,0,0"), empty
end TestUnknownData

-- The splash: the status over the window, the image at its size in the
-- middle of it, only while the page's root has the class oxt-splash, which
-- the script takes away when the status is first hidden
on TestSplashMarkupWithASize
   local tMarkup
   put getSplashMarkup("splash.png", "240,120") into tMarkup
   TestAssert "a style and a script", tMarkup begins with "<style>" and tMarkup ends with "</script>"
   TestAssert "the status over the whole window", ".oxt-splash #status{position:fixed;top:0;left:0;right:0;bottom:0;" is in tMarkup
   TestAssert "on the page's colour", "background-color:inherit" is in tMarkup
   TestAssert "the image", "background:url(splash.png) center/contain no-repeat" is in tMarkup
   TestAssert "at its size", "width:240px;height:120px;max-width:calc(100% - 32px);max-height:60%" is in tMarkup
   TestAssert "the status's text under it", "padding-top:calc(50vh + min(120px,60vh)/2 + 12px)" is in tMarkup
   TestAssert "the class at once", "r.classList.add('oxt-splash')" is in tMarkup
   TestAssert "taken away when the status is hidden", \
         "s.style.display!=='none'" is in tMarkup and "r.classList.remove('oxt-splash')" is in tMarkup
   TestAssert "no double quotes, which would end an attribute", quote is not in tMarkup
end TestSplashMarkupWithASize

on TestSplashMarkupIsTheChecksFixture
   TestAssert "a 24x24 splash.png's markup is the one web_check.py's tests expect", \
         getSplashMarkup("splash.png", "24,24") is kSplashHead24
end TestSplashMarkupIsTheChecksFixture

on TestSplashMarkupWithoutASize
   local tMarkup
   put getSplashMarkup("splash.svg", empty) into tMarkup
   TestAssert "the image", "url(splash.svg)" is in tMarkup
   TestAssert "in a square half the window's shorter side", "width:50vmin;height:50vmin" is in tMarkup
   TestAssert "the status's text under it", "padding-top:calc(50vh + 25vmin + 12px)" is in tMarkup
end TestSplashMarkupWithoutASize

-- Without the setting, the page's head gets nothing for it: the page is
-- the engine's as it was
on TestEmptySettingAddsNothing
   local tScript, tStart, tBody
   put libraryText() into tScript
   put lineOffset("private function getSplashHead pSplash", tScript) into tStart
   TestAssert "the library has getSplashHead", tStart > 0
   put line tStart + 1 to tStart + 5 of tScript into tBody
   TestAssert "an empty setting returns empty first", \
         "if pSplash is empty then" & return & "      return empty" & return & "   end if" is in tBody
   TestAssert "getPageHead adds it", \
         "put getSplashHead(pSettings[" & quote & "emscripten,splash" & quote & "], pBaseFolder, pBuildFolder) after tHead" is in tScript
end TestEmptySettingAddsNothing
