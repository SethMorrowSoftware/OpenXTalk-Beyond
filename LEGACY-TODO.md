# FIXME, TODO and HACK notes in the legacy code

Every FIXME, TODO and HACK comment in the code OXT-Beyond inherited: LiveCode Community's engine, libraries, toolchain, externals, extensions and IDE scripts, and Tom Perry's OpenXTalk Lite changes to them. It is a map of known loose ends, kept as a starting point for work; most notes were written by LiveCode's developers years ago, and some may no longer be true. When a fix removes or rewords a note, this list is made again in the same pull request.

Not covered: the third-party libraries in `thirdparty/` (each has its own upstream), the bundled copy of GYP in `gyp/`, the dictionary and guides in `docs/`, OXT-Beyond's own build and CI tools in `tools/ci/` and `tools/oxt/`, and the scripts inside the IDE's binary stacks (`.livecode`, `.rev` and `.oxtstack` files), which a text search cannot read.

How it is made: `tools/oxt/legacy_todo.py` writes this file from a case-insensitive whole-word search for `FIXME`, `TODO` and `HACK` (so `COCOA-TODO` and `V6-TODO` count, and so does "hack" in a sentence). A line with more than one marker is listed under each. Run `python3 tools/oxt/legacy_todo.py` after a change that adds, removes or moves notes; `--check` tells whether this file is up to date. The search is:

```sh
git grep -n -I -i -w -E 'FIXME|TODO|HACK' -- . ':!thirdparty' ':!prebuilt/fetched' ':!gyp' ':!docs' \
    ':!tools/ci' ':!tools/oxt' ':!*.md' ':!*.txt' ':!*.json' ':!*.map' ':!*.strings'
```

| Marker | Notes |
| --- | --- |
| [FIXME](#fixme) | 74 |
| [HACK](#hack) | 33 |
| [TODO](#todo) | 459 |

## FIXME

Code its authors knew to be wrong or incomplete. 74 notes, by part of the repository:

[engine](#fixme-engine) (40), [libfoundation](#fixme-libfoundation) (10), [tests](#fixme-tests) (8), [toolchain](#fixme-toolchain) (6), [extensions](#fixme-extensions) (2), [ide](#fixme-ide) (2), [ide-support](#fixme-ide-support) (2), [libscript](#fixme-libscript) (2), [builder](#fixme-builder) (1), [util](#fixme-util) (1)

<a id="fixme-engine"></a>

### FIXME: engine (40)

- [engine/installer-armv6-hf.link:187](engine/installer-armv6-hf.link#L187) FIXME: Why do we need it? When there is no .bss section, we don't
- [engine/src/dispatch.cpp:1577](engine/src/dispatch.cpp#L1577) FIXME This is horrible
- [engine/src/em-dc-mainloop.cpp:46](engine/src/em-dc-mainloop.cpp#L46) FIXME these functions are pretty much the same for every X_init()
- [engine/src/em-dc.cpp:190](engine/src/em-dc.cpp#L190) FIXME Implement HiDPI support
- [engine/src/em-dc.cpp:245](engine/src/em-dc.cpp#L245) FIXME Implement HiDPI support
- [engine/src/em-event.js:359](engine/src/em-event.js#L359) FIXME Maybe this should be done in the engine?
- [engine/src/em-event.js:549](engine/src/em-event.js#L549) FIXME not supported
- [engine/src/em-filehandle.cpp:86](engine/src/em-filehandle.cpp#L86) FIXME Figure out why this is needed
- [engine/src/em-filehandle.cpp:111](engine/src/em-filehandle.cpp#L111) FIXME Figure out why this is a success
- [engine/src/em-filehandle.cpp:168](engine/src/em-filehandle.cpp#L168) FIXME figure out why this is a success
- [engine/src/em-main.cpp:81](engine/src/em-main.cpp#L81) FIXME should probably be UTF-8
- [engine/src/em-main.cpp:104](engine/src/em-main.cpp#L104) FIXME should probably be UTF-8
- [engine/src/em-preamble-overlay.js:29](engine/src/em-preamble-overlay.js#L29) FIXME Massive amounts of hardcoded styling that can't be customized
- [engine/src/em-preamble-overlay.js:90](engine/src/em-preamble-overlay.js#L90) FIXME internationalise this text
- [engine/src/em-preamble.js:57](engine/src/em-preamble.js#L57) FIXME Should this be moved into the engine?
- [engine/src/em-preamble.js:81](engine/src/em-preamble.js#L81) FIXME Can we cache the capsule locally?
- [engine/src/em-standalone.js:43](engine/src/em-standalone.js#L43) FIXME maybe this needs a helper function in LiveCodeUtil
- [engine/src/em-system.cpp:328](engine/src/em-system.cpp#L328) FIXME Implement BackupFile
- [engine/src/em-system.cpp:338](engine/src/em-system.cpp#L338) FIXME Implement UnbackupFile()
- [engine/src/em-system.cpp:348](engine/src/em-system.cpp#L348) FIXME Implement CreateAlias() using symlink(2)
- [engine/src/em-system.cpp:359](engine/src/em-system.cpp#L359) FIXME Implement ResolveAlias() using readlink(2)
- [engine/src/em-system.cpp:369](engine/src/em-system.cpp#L369) FIXME use get_current_dir_name() once it's available in Emscripten's
- [engine/src/em-system.cpp:465](engine/src/em-system.cpp#L465) FIXME use scandirat() once it's available in emscripten's libc
- [engine/src/em-system.cpp:652](engine/src/em-system.cpp#L652) FIXME Implement GetFreeDiskSpace()
- [engine/src/em-system.cpp:661](engine/src/em-system.cpp#L661) FIXME Implement GetDevices()
- [engine/src/em-system.cpp:670](engine/src/em-system.cpp#L670) FIXME Implement GetDrives()
- [engine/src/em-system.cpp:796](engine/src/em-system.cpp#L796) FIXME Implement OpenDevice()
- [engine/src/em-system.cpp:830](engine/src/em-system.cpp#L830) FIXME Implement ResolvePath()
- [engine/src/em-theme.cpp:37](engine/src/em-theme.cpp#L37) FIXME not yet implemented
- [engine/src/em-url.js:59](engine/src/em-url.js#L59) FIXME maybe this needs a helper function in LiveCodeUtil
- [engine/src/em-url.js:185](engine/src/em-url.js#L185) FIXME this isn't quite correct; we don't correctly
- [engine/src/funcs.h:1118](engine/src/funcs.h#L1118) class MCNativeCharToNum : public MCUnaryFunctionCtxt<MCStringRef, uinteger_t, MCStringsEvalNativeCharToNum, EE_CHARTONUM_BADSOURCE, PE_CHARTONUM_BADPARAM> //...
- [engine/src/funcs.h:1133](engine/src/funcs.h#L1133) EE_NUMTOCHAR_BADSOURCE, PE_NUMTOCHAR_BADPARAM> // FIXME
- [engine/src/funcs.h:1141](engine/src/funcs.h#L1141) EE_NUMTOCHAR_BADSOURCE, PE_NUMTOCHAR_BADPARAM> // FIXME
- [engine/src/funcs.h:1574](engine/src/funcs.h#L1574) EE_CHARTONUM_BADSOURCE, PE_CHARTONUM_BADPARAM> // FIXME
- [engine/src/globals.cpp:985](engine/src/globals.cpp#L985) FIXME use MCProperListRef
- [engine/src/mcsemaphore.h:61](engine/src/mcsemaphore.h#L61) FIXME mark as explicit
- [engine/src/sysspec-url.cpp:341](engine/src/sysspec-url.cpp#L341) FIXME if wait() returns non-zero, cancel the URL
- [engine/src/widget.lcb:911](engine/src/widget.lcb#L911) FIXME not actually implemented
- [engine/src/widget.lcb:1491](engine/src/widget.lcb#L1491) FIXME not implemented

<a id="fixme-libfoundation"></a>

### FIXME: libfoundation (10)

- [libfoundation/include/system-commandline.h:81](libfoundation/include/system-commandline.h#L81) FIXME support for getting the command filename isn't implemented
- [libfoundation/src/foundation-handler.cpp:503](libfoundation/src/foundation-handler.cpp#L503) FIXME Should include information about arguments and return
- [libfoundation/src/foundation-private.h:710](libfoundation/src/foundation-private.h#L710) define __MCAssertIsLocale(x)   MCAssert(nil != (x)) /* FIXME
- [libfoundation/src/system-commandline.cpp:280](libfoundation/src/system-commandline.cpp#L280) return false; /* FIXME proper error
- [libfoundation/src/system-file-w32.cpp:286](libfoundation/src/system-file-w32.cpp#L286) FIXME Remaining weaknesses:
- [libfoundation/src/system-file-w32.cpp:484](libfoundation/src/system-file-w32.cpp#L484) FIXME[2017-04-20] there should be a "basename" function
- [libfoundation/src/system-file-w32.cpp:540](libfoundation/src/system-file-w32.cpp#L540) FIXME Currently, this function -- and thus the files API on Windows
- [libfoundation/src/system-stream.cpp:51](libfoundation/src/system-stream.cpp#L51) FIXME known issues:
- [libfoundation/src/system-stream.cpp:221](libfoundation/src/system-stream.cpp#L221) FIXME see the "known issues" at the top of this file.
- [libfoundation/src/system-stream.cpp:280](libfoundation/src/system-stream.cpp#L280) FIXME see the "known issues" at the top of this file.

<a id="fixme-tests"></a>

### FIXME: tests (8)

- [tests/_testerlib.livecodescript:272](tests/_testerlib.livecodescript#L272) FIXME this really doesn't work properly if LiveCode's stdout
- [tests/_testrunner.lcb:69](tests/_testrunner.lcb#L69) FIXME this should use proper LiveCode builder syntax for string
- [tests/_testrunner.lcb:211](tests/_testrunner.lcb#L211) FIXME HACK HACK HACK
- [tests/_testrunner.lcb:234](tests/_testrunner.lcb#L234) FIXME Currently, this is implemented by redirecting the lc-run's
- [tests/_testrunner.lcb:262](tests/_testrunner.lcb#L262) FIXME Currently, this is implemented by redirecting the lc-run's
- [tests/_testrunner.lcb:266](tests/_testrunner.lcb#L266) FIXME We may want to capture the stderr output into the log at some
- [tests/_testrunner.lcb:415](tests/_testrunner.lcb#L415) FIXME this is stupidly fragile.  We need a command-line
- [tests/lcs/core/logic/isstrictly.livecodescript:43](tests/lcs/core/logic/isstrictly.livecodescript#L43) FIXME can't currently generate nothing values in LCS

<a id="fixme-toolchain"></a>

### FIXME: toolchain (6)

- [toolchain/lc-compile-ffi-java/src/main.c:65](toolchain/lc-compile-ffi-java/src/main.c#L65) FIXME maybe we should use getopt?
- [toolchain/lc-compile-ffi-java/src/main.c:87](toolchain/lc-compile-ffi-java/src/main.c#L87) FIXME This should be expanded to support "-W error",
- [toolchain/lc-compile/src/lc-run.cpp:193](toolchain/lc-compile/src/lc-run.cpp#L193) FIXME This is currently very basic.  For correctness, it should
- [toolchain/lc-compile/src/lc-run.cpp:239](toolchain/lc-compile/src/lc-run.cpp#L239) FIXME Once we have "real" command line arguments, process them
- [toolchain/lc-compile/src/main.c:163](toolchain/lc-compile/src/main.c#L163) FIXME maybe we should use getopt?
- [toolchain/lc-compile/src/main.c:236](toolchain/lc-compile/src/main.c#L236) FIXME This should be expanded to support "-W error",

<a id="fixme-extensions"></a>

### FIXME: extensions (2)

- [extensions/libraries/iconsvg/iconsvg.lcb:1622](extensions/libraries/iconsvg/iconsvg.lcb#L1622) FIXME Just subscript by tResolved once that's implemented
- [extensions/widgets/switchbutton/switchbutton.lcb:388](extensions/widgets/switchbutton/switchbutton.lcb#L388) FIXME This is ugly!

<a id="fixme-ide"></a>

### FIXME: ide (2)

- [ide/Toolset/libraries/revidelibrary.8.livecodescript:11330](ide/Toolset/libraries/revidelibrary.8.livecodescript#L11330) FIXME There is some inconsistency in the guide's files that we
- [ide/Toolset/palettes/script editor/behaviors/revseleftbarbehavior.livecodescript:20](ide/Toolset/palettes/script%20editor/behaviors/revseleftbarbehavior.livecodescript#L20) FIXME What happens when the space is to short to show the filter field?

<a id="fixme-ide-support"></a>

### FIXME: ide-support (2)

- [ide-support/revsaveasemscriptenstandalone.livecodescript:33](ide-support/revsaveasemscriptenstandalone.livecodescript#L33) FIXME
- [ide-support/revsaveasemscriptenstandalone.livecodescript:147](ide-support/revsaveasemscriptenstandalone.livecodescript#L147) FIXME just copies the Emscripten-generated page into place

<a id="fixme-libscript"></a>

### FIXME: libscript (2)

- [libscript/src/module-stream.cpp:27](libscript/src/module-stream.cpp#L27) FIXME This check should be handled by MCStreamWrite
- [libscript/src/unittest-impl.lcb:97](libscript/src/unittest-impl.lcb#L97) FIXME this should use LCB encoding library rather than directly

<a id="fixme-builder"></a>

### FIXME: builder (1)

- [builder/docs_builder.livecodescript:382](builder/docs_builder.livecodescript#L382) FIXME This has to be kept in sync with the installer manifest, probably

<a id="fixme-util"></a>

### FIXME: util (1)

- [util/perfect/perfect.gyp:52](util/perfect/perfect.gyp#L52) FIXME Force the perfect executable to be put into

## HACK

Workarounds their authors were not happy with. 33 notes, by part of the repository:

[engine](#hack-engine) (8), [ide](#hack-ide) (8), [ide-support](#hack-ide-support) (4), [extensions](#hack-extensions) (3), [libfoundation](#hack-libfoundation) (3), [prebuilt](#hack-prebuilt) (3), [builder](#hack-builder) (2), [tests](#hack-tests) (2)

<a id="hack-engine"></a>

### HACK: engine (8)

- [engine/engine.gyp:154](engine/engine.gyp#L154) Really nasty hack to prevent this from being treated as a path
- [engine/src/font.cpp:427](engine/src/font.cpp#L427) This is a really ugly hack to get LTR/RTL overrides working correctly -
- [engine/src/font.cpp:444](engine/src/font.cpp#L444) Another ugly hack - this time, to avoid incoming strings being coerced
- [engine/src/line.h:46](engine/src/line.h#L46) Dirty hack
- [engine/src/mac-dialog.mm:432](engine/src/mac-dialog.mm#L432) MW-2014-07-25: [[ Bug 12250 ]] Hack to find tableview inside the savepanel so we can force
- [engine/src/mac-dialog.mm:453](engine/src/mac-dialog.mm#L453) MW-2014-07-25: [[ Bug 12250 ]] Use the hack from:
- [engine/src/mcutility.h:300](engine/src/mcutility.h#L300) inline char *MC_strchr(const char *s, int c) // HACK for bug in GCC 2.5.x
- [engine/src/paragraf.h:174](engine/src/paragraf.h#L174) Dirty hack until we have a proper styled text object...

<a id="hack-ide"></a>

### HACK: ide (8)

- [ide/Toolset/libraries/revdebuggerlibrary.livecodescript:1438](ide/Toolset/libraries/revdebuggerlibrary.livecodescript#L1438) For now we have to hack this without access to the parser
- [ide/Toolset/libraries/revdebuggerlibrary.livecodescript:2241](ide/Toolset/libraries/revdebuggerlibrary.livecodescript#L2241) calls IDE code, e.g get url. For now we hack around this.
- [ide/Toolset/palettes/behaviors/revinspectorbehavior.livecodescript:41](ide/Toolset/palettes/behaviors/revinspectorbehavior.livecodescript#L41) HACK for stopping the gradient and effects palette getting stuck behind the inspector!!
- [ide/Toolset/palettes/extension manager/revideextensionmanagerstorebehavior.livecodescript:21](ide/Toolset/palettes/extension%20manager/revideextensionmanagerstorebehavior.livecodescript#L21) Hack to get round bug 18946
- [ide/Toolset/palettes/reverrordisplay.livecodescript:550](ide/Toolset/palettes/reverrordisplay.livecodescript#L550) attempting to highlight the appropriate line number. This is a total hack, but there doensn't seem
- [ide/Toolset/palettes/script editor/behaviors/revsecommoneditorbehavior.livecodescript:3552](ide/Toolset/palettes/script%20editor/behaviors/revsecommoneditorbehavior.livecodescript#L3552) First wrap the script to the required width, this is a total hack as doing it properly would take quite a while.
- [ide/Toolset/palettes/script editor/behaviors/revseeditorbehavior.livecodescript:2222](ide/Toolset/palettes/script%20editor/behaviors/revseeditorbehavior.livecodescript#L2222) this is clearly a bit of a hack, but hopefully doing is this way will minimize the risk.
- [ide/Toolset/palettes/script editor/behaviors/revsevariablespanebehavior.livecodescript:116](ide/Toolset/palettes/script%20editor/behaviors/revsevariablespanebehavior.livecodescript#L116) If the user chooses a large font, we need to increase the size of the template, for now we just hack this as

<a id="hack-ide-support"></a>

### HACK: ide-support (4)

- [ide-support/revdeploylibraryemscripten.livecodescript:227](ide-support/revdeploylibraryemscripten.livecodescript#L227) It will only work if firefox is not already running (or we could try a nasty apple script hack but that susceptible to menu/shortcut changes).
- [ide-support/revsaveasiosstandalone.livecodescript:299](ide-support/revsaveasiosstandalone.livecodescript#L299) hack to uniquify modules
- [ide-support/revsaveasiosstandalone.livecodescript:468](ide-support/revsaveasiosstandalone.livecodescript#L468) .embeddedframework is a hack that some SDKs use for single drag and drop of
- [ide-support/revsaveasstandalone.livecodescript:1908](ide-support/revsaveasstandalone.livecodescript#L1908) For now however, I've added this hack to allow users to work around the issue themselves.

<a id="hack-extensions"></a>

### HACK: extensions (3)

- [extensions/extensions.gyp:201](extensions/extensions.gyp#L201) hack because gyp wants an output
- [extensions/libraries/ini/inih/inih.gyp:58](extensions/libraries/ini/inih/inih.gyp#L58) loadable_module is overridden for iOS so hack around that
- [extensions/libraries/timezone/tz/tz.gyp:221](extensions/libraries/timezone/tz/tz.gyp#L221) loadable_module is overridden for iOS so hack around that

<a id="hack-libfoundation"></a>

### HACK: libfoundation (3)

- [libfoundation/include/foundation.h:366](libfoundation/include/foundation.h#L366) Nasty, evil hack -- remove me
- [libfoundation/src/foundation-locale.cpp:249](libfoundation/src/foundation-locale.cpp#L249) This is a really nasty hack used to work around the fact that nativising
- [libfoundation/src/system-file-posix.cpp:281](libfoundation/src/system-file-posix.cpp#L281) MCAutoStringRefAsSysString instance, so this is a bit of a hack

<a id="hack-prebuilt"></a>

### HACK: prebuilt (3)

- [prebuilt/libicu.gyp:57](prebuilt/libicu.gyp#L57) Hack required due to GYP failure / refusal to treat this as a path
- [prebuilt/libicu.gyp:404](prebuilt/libicu.gyp#L404) Really nasty hack to prevent this from being treated as a path
- [prebuilt/thirdparty.gyp:782](prebuilt/thirdparty.gyp#L782) Hack to put licuuc after lharfbuzz in library list

<a id="hack-builder"></a>

### HACK: builder (2)

- [builder/builder_tool.livecodescript:38](builder/builder_tool.livecodescript#L38) Hack the arch from the platform. This should really use
- [builder/release_notes_builder.livecodescript:920](builder/release_notes_builder.livecodescript#L920) Horrible-ish hack for extracting the "real" name of the LiveCode

<a id="hack-tests"></a>

### HACK: tests (2)

- [tests/_testrunner.lcb:211](tests/_testrunner.lcb#L211) FIXME HACK HACK HACK
- [tests/lcb/vm/native-callback.lcb:81](tests/lcb/vm/native-callback.lcb#L81) handler values. We 'hack' this at the moment by massaging the types of

## TODO

Work left for later. 459 notes, by part of the repository:

[engine](#todo-engine) (269), [libfoundation](#todo-libfoundation) (47), [tests](#todo-tests) (20), [revbrowser](#todo-revbrowser) (19), [ide](#todo-ide) (18), [toolchain](#todo-toolchain) (14), [extensions](#todo-extensions) (12), [libgraphics](#todo-libgraphics) (12), [libscript](#todo-libscript) (12), [libbrowser](#todo-libbrowser) (10), [builder](#todo-builder) (5), [(top level)](#todo-top-level) (3), [ide-support](#todo-ide-support) (3), [revmobile](#todo-revmobile) (3), [revxml](#todo-revxml) (3), [prebuilt](#todo-prebuilt) (2), [revdb](#todo-revdb) (2), [config](#todo-config) (1), [lcidlc](#todo-lcidlc) (1), [revspeech](#todo-revspeech) (1), [revvideograbber](#todo-revvideograbber) (1), [tools](#todo-tools) (1)

<a id="todo-engine"></a>

### TODO: engine (269)

- [engine/exec-tests/filters/EvalUniDecode.test:35](engine/exec-tests/filters/EvalUniDecode.test#L35) TODO - add this platform :)
- [engine/exec-tests/filters/EvalUniEncode.test:35](engine/exec-tests/filters/EvalUniEncode.test#L35) TODO - add this platform :)
- [engine/exec-tests/interface/EvalScreenName.test:8](engine/exec-tests/interface/EvalScreenName.test#L8) TODO - add other platform tests
- [engine/exec-tests/legacy/EvalScreenVendor.test:8](engine/exec-tests/legacy/EvalScreenVendor.test#L8) TODO - add tests for other platforms
- [engine/exec-tests/text/EvalFontLanguage.test:6](engine/exec-tests/text/EvalFontLanguage.test#L6) TODO - test font languages on other platforms
- [engine/exec-tests/text/EvalFontNames.test:11](engine/exec-tests/text/EvalFontNames.test#L11) TODO - check for standard fonts on other platforms
- [engine/exec-tests/text/EvalFontSizes.test:10](engine/exec-tests/text/EvalFontSizes.test#L10) TODO - test font sizes on other platforms
- [engine/exec-tests/text/EvalFontStyles.test:8](engine/exec-tests/text/EvalFontStyles.test#L8) TODO - test font sizes on other platforms
- [engine/rsrc/emscripten-html-template.html:220](engine/rsrc/emscripten-html-template.html#L220) TODO: do not warn on ok events like simulating an infinite loop or exitStatus
- [engine/src/block.cpp:2353](engine/src/block.cpp#L2353) else if (!IsMacLF()) // TODO: if platform reverses selected text
- [engine/src/browser.lcb:221](engine/src/browser.lcb#L221) TODO - replace literal values with constants when possible
- [engine/src/browser.lcb:240](engine/src/browser.lcb#L240) TODO - replace literal values with constants when possible
- [engine/src/browser.lcb:244](engine/src/browser.lcb#L244) TODO - replace literal values with constants when possible
- [engine/src/canvas.lcb:2197](engine/src/canvas.lcb#L2197) TODO - add image frame index property?
- [engine/src/canvas.lcb:2343](engine/src/canvas.lcb#L2343) TODO - how to specify resize quality?
- [engine/src/canvas.lcb:2344](engine/src/canvas.lcb#L2344) TODO - add resize operation? "resize <image> to <width>,<height>"
- [engine/src/canvas.lcb:2345](engine/src/canvas.lcb#L2345) TODO - implement image operations
- [engine/src/clipboard.cpp:68](engine/src/clipboard.cpp#L68) TODO: atomic operations
- [engine/src/clipboard.cpp:83](engine/src/clipboard.cpp#L83) TODO: atomic operations
- [engine/src/customprinter.cpp:362](engine/src/customprinter.cpp#L362) TODO - fix half pixels lost when insetting by odd integers
- [engine/src/customprinter.cpp:591](engine/src/customprinter.cpp#L591) TODO: Make the rasterization scale depend in some way on current scaling,
- [engine/src/desktop-dc.cpp:141](engine/src/desktop-dc.cpp#L141) COCOA-TODO: Is this still needed?
- [engine/src/desktop-dc.cpp:266](engine/src/desktop-dc.cpp#L266) COCOA-TODO: This is Mac specific
- [engine/src/desktop-dc.cpp:270](engine/src/desktop-dc.cpp#L270) COCOA-TODO: These values should be queryable (once we figure out what
- [engine/src/desktop-menu.cpp:128](engine/src/desktop-menu.cpp#L128) COCOA-TODO: Will require some restructuring in the engine menu code to support unicode
- [engine/src/desktop-stack.cpp:97](engine/src/desktop-stack.cpp#L97) \|\| mode == WM_DRAWER)  // COCOA-TODO: Implement drawers
- [engine/src/desktop-stack.cpp:263](engine/src/desktop-stack.cpp#L263) COCOA-TODO: Make sure contained views also scroll (?)
- [engine/src/desktop.cpp:107](engine/src/desktop.cpp#L107) TODO[2017-04-05] X_init() failed before initialising global
- [engine/src/desktop.cpp:659](engine/src/desktop.cpp#L659) PLATFORM-TODO: Should we do more than this? i.e. Should the dragDrop
- [engine/src/dispatch.cpp:255](engine/src/dispatch.cpp#L255) TODO[19681]: This can be removed when all engine messages are sent with
- [engine/src/dispatch.cpp:305](engine/src/dispatch.cpp#L305) TODO[19681]: This can be removed when all engine messages are sent with
- [engine/src/dispatch.cpp:1571](engine/src/dispatch.cpp#L1571) PLATFORM-TODO: This is needed at the moment to make sure that we don't
- [engine/src/dispatch.cpp:1909](engine/src/dispatch.cpp#L1909) TODO: what about other 'special' chars added by unicode?
- [engine/src/dskmac.cpp:790](engine/src/dskmac.cpp#L790) TODO Check whether the double path resolution is an issue
- [engine/src/dskmac.cpp:1186](engine/src/dskmac.cpp#L1186) TODO assign relevant error code
- [engine/src/dskmac.cpp:1208](engine/src/dskmac.cpp#L1208) TODO assign relevant error code
- [engine/src/dskmac.cpp:1253](engine/src/dskmac.cpp#L1253) void MCS_mac_closeresourcefile(ResFileRefNum p_ref) // TODO: remove?
- [engine/src/dskmac.cpp:1673](engine/src/dskmac.cpp#L1673) TODO Add MCSystemFileHandle::SetStream(char *newptr) ?
- [engine/src/dskmac.cpp:3484](engine/src/dskmac.cpp#L3484) TODO: Report errno appropriately.
- [engine/src/dskmain.cpp:222](engine/src/dskmain.cpp#L222) TODO Remove -g,-geometry flag because it's not used any more
- [engine/src/dskw32.cpp:623](engine/src/dskw32.cpp#L623) TODO: still necessary with GetFileAttributes instead of stat?
- [engine/src/dskw32.cpp:633](engine/src/dskw32.cpp#L633) TODO: still necessary with GetFileAttributes instead of stat?
- [engine/src/dskw32.cpp:3020](engine/src/dskw32.cpp#L3020) TODO: set end of file...
- [engine/src/em-dc.js:146](engine/src/em-dc.js#L146) TODO - handle cleanup of embedded canvas
- [engine/src/em-dc.js:297](engine/src/em-dc.js#L297) TODO - implement
- [engine/src/em-event.js:598](engine/src/em-event.js#L598) TODO - reenable alt key detection
- [engine/src/em-util.js:304](engine/src/em-util.js#L304) TODO - support more value types
- [engine/src/em-util.js:332](engine/src/em-util.js#L332) TODO - for now, treat functions as objects but we may wish to differentiate them later
- [engine/src/exec-engine.cpp:519](engine/src/exec-engine.cpp#L519) TODO - create as list?
- [engine/src/exec-extension.cpp:769](engine/src/exec-extension.cpp#L769) TODO: Augment error
- [engine/src/exec-interface-stack.cpp:121](engine/src/exec-interface-stack.cpp#L121) TODO
- [engine/src/exec-network.cpp:165](engine/src/exec-network.cpp#L165) TODO - I.M. this is a bit odd, checking if we have permission to resolve a hostname AFTER we've
- [engine/src/exec-pasteboard.cpp:556](engine/src/exec-pasteboard.cpp#L556) TODO: support multiple items
- [engine/src/exec-pasteboard.cpp:691](engine/src/exec-pasteboard.cpp#L691) TODO: support multiple items
- [engine/src/exec-pasteboard.cpp:1418](engine/src/exec-pasteboard.cpp#L1418) TODO: support multiple items
- [engine/src/exec-pasteboard.cpp:1460](engine/src/exec-pasteboard.cpp#L1460) TODO: support multiple items
- [engine/src/externalv1.h:221](engine/src/externalv1.h#L221) V6-TODO: Make sure these return the same as they did in previous versions - i.e. native char
- [engine/src/externalv1.h:360](engine/src/externalv1.h#L360) V6-TODO: This method was never exposed / used so is now unimplemented.
- [engine/src/externalv1.h:363](engine/src/externalv1.h#L363) V6-TODO: These methods are not valid for V6, the array interface needs rethinking at a later
- [engine/src/fieldh.cpp:443](engine/src/fieldh.cpp#L443) TODO: TextIsExplicitLineBreak
- [engine/src/fieldh.cpp:510](engine/src/fieldh.cpp#L510) TODO: the kMCFieldExportEvent{Unicode,Native}Run constants should be merged
- [engine/src/fieldrtf.cpp:566](engine/src/fieldrtf.cpp#L566) TODO: paragraph metadata roundtrip - this clause breaks things at the moment :(
- [engine/src/fields.cpp:281](engine/src/fields.cpp#L281) TODO: this will become useful again for surrogate pairs
- [engine/src/graphicscontext.cpp:561](engine/src/graphicscontext.cpp#L561) TODO
- [engine/src/ibmp.cpp:2165](engine/src/ibmp.cpp#L2165) TODO - color parsing code is incomplete - ignores the key type
- [engine/src/ibmp.cpp:2275](engine/src/ibmp.cpp#L2275) if (t_success) /* TODO - this will fail if the x, y hotspot or any extension is specified
- [engine/src/ibmp.cpp:2927](engine/src/ibmp.cpp#L2927) TODO
- [engine/src/ifile.cpp:133](engine/src/ifile.cpp#L133) TODO - may be able to improve this now by rasterizing the metafile
- [engine/src/image_rep.cpp:914](engine/src/image_rep.cpp#L914) TODO - support other metadata fields
- [engine/src/imagelist.cpp:133](engine/src/imagelist.cpp#L133) TODO - determine if source rep is opaque
- [engine/src/internal.cpp:27](engine/src/internal.cpp#L27) Todo:
- [engine/src/internal_development.cpp:26](engine/src/internal_development.cpp#L26) Todo:
- [engine/src/java/com/android/vending/billing/IInAppBillingService.aidl:103](engine/src/java/com/android/vending/billing/IInAppBillingService.aidl#L103) TODO: change this to app-specific keys.
- [engine/src/java/com/android/vending/billing/IInAppBillingService.java:293](engine/src/java/com/android/vending/billing/IInAppBillingService.java#L293) TODO: change this to app-specific keys.
- [engine/src/java/com/android/vending/billing/IInAppBillingService.java:463](engine/src/java/com/android/vending/billing/IInAppBillingService.java#L463) TODO: change this to app-specific keys.
- [engine/src/java/com/runrev/android/NFCModule.java:163](engine/src/java/com/runrev/android/NFCModule.java#L163) Todo - expand this to include more information from the tag
- [engine/src/java/com/runrev/android/billing/amazon/MyPurchasingObserver.java:132](engine/src/java/com/runrev/android/billing/amazon/MyPurchasingObserver.java#L132) TODO : How to get the purchase Id
- [engine/src/java/com/runrev/android/billing/amazon/MyPurchasingObserver.java:165](engine/src/java/com/runrev/android/billing/amazon/MyPurchasingObserver.java#L165) TODO : How to get the purchase Id
- [engine/src/java/com/runrev/android/billing/amazon/MyPurchasingObserver.java:289](engine/src/java/com/runrev/android/billing/amazon/MyPurchasingObserver.java#L289) TODO : How to get the purchase Id
- [engine/src/java/com/runrev/android/billing/amazon/MyPurchasingObserver.java:293](engine/src/java/com/runrev/android/billing/amazon/MyPurchasingObserver.java#L293) TODO: MOVE THIS TO EnginePurchaseObserver.
- [engine/src/java/com/runrev/android/billing/google/GoogleBillingProvider.java:52](engine/src/java/com/runrev/android/billing/google/GoogleBillingProvider.java#L52) TODO enable debug logging (for a production application, you should set this to false).
- [engine/src/java/com/runrev/android/billing/google/GoogleBillingProvider.java:528](engine/src/java/com/runrev/android/billing/google/GoogleBillingProvider.java#L528) TODO: verify that the developer payload of the purchase is correct. It will be
- [engine/src/java/com/runrev/android/nativecontrol/ExtVideoView.java:258](engine/src/java/com/runrev/android/nativecontrol/ExtVideoView.java#L258) TODO: these constants need to be published somewhere in the framework.
- [engine/src/java/com/runrev/android/nativecontrol/NativeControl.java:84](engine/src/java/com/runrev/android/nativecontrol/NativeControl.java#L84) TODO - rework and implement
- [engine/src/java/com/sec/android/iap/sample/helper/SamsungIapHelper.java:1150](engine/src/java/com/sec/android/iap/sample/helper/SamsungIapHelper.java#L1150) TODO 삭제 대상
- [engine/src/java/com/sec/android/iap/sample/helper/SamsungIapHelper.java:1439](engine/src/java/com/sec/android/iap/sample/helper/SamsungIapHelper.java#L1439) TODO  삭제 대상
- [engine/src/line.cpp:402](engine/src/line.cpp#L402) TODO: when cx > line width, return the last block in visual order
- [engine/src/lnxans.cpp:337](engine/src/lnxans.cpp#L337) TODO : This needs to be changed to a proper callback function : gdk_event_handler_set()
- [engine/src/lnxcursor.cpp:104](engine/src/lnxcursor.cpp#L104) TODO: do we need to do this?
- [engine/src/lnxdcs.cpp:279](engine/src/lnxdcs.cpp#L279) TODO: equivalent in GDK?
- [engine/src/lnxdcs.cpp:573](engine/src/lnxdcs.cpp#L573) TODO - We may need to do clipboard persistance here
- [engine/src/lnxflst.cpp:43](engine/src/lnxflst.cpp#L43) TODO: We need to revise the situation periodically and implement
- [engine/src/lnxstack.cpp:288](engine/src/lnxstack.cpp#L288) TODO: initial input focus
- [engine/src/lnxstack.cpp:340](engine/src/lnxstack.cpp#L340) TODO: is this just another way of ensuring on-top-ness?
- [engine/src/lnxstack.cpp:362](engine/src/lnxstack.cpp#L362) TODO: input modality hints
- [engine/src/lnxstack.cpp:440](engine/src/lnxstack.cpp#L440) TODO: test if this comment is still true
- [engine/src/mac-av-player.mm:1552](engine/src/mac-av-player.mm#L1552) TODO: Add more types??
- [engine/src/mac-av-player.mm:1601](engine/src/mac-av-player.mm#L1601) TODO
- [engine/src/mac-core.mm:1578](engine/src/mac-core.mm#L1578) 0x47 */ kMCPlatformKeyCodeNumLock, // COCO-TODO: This should be keypad-clear - double-check!
- [engine/src/mac-core.mm:1645](engine/src/mac-core.mm#L1645) PLATFORM-TODO: Shifted keysym handling should be in the engine rather than
- [engine/src/mac-core.mm:1718](engine/src/mac-core.mm#L1718) COCOA-TODO: Clean up this external dependency.
- [engine/src/mac-core.mm:2240](engine/src/mac-core.mm#L2240) COCOA-TODO: Abstract Command/Control switching.
- [engine/src/mac-core.mm:2315](engine/src/mac-core.mm#L2315) COCOA-TODO: Make this is a little more discerning (only need to reset if
- [engine/src/mac-menu.mm:1886](engine/src/mac-menu.mm#L1886) COCOA-TODO: Abstract Command/Control switching.
- [engine/src/mac-surface.mm:34](engine/src/mac-surface.mm#L34) COCOA-TODO: Clean up external linkage for surface.
- [engine/src/mac-surface.mm:219](engine/src/mac-surface.mm#L219) COCOA-TODO: Getting the height to flip round is dependent on a friend.
- [engine/src/mac-surface.mm:261](engine/src/mac-surface.mm#L261) COCOA-TODO: Getting the height to flip round is dependent on a friend.
- [engine/src/mac-surface.mm:294](engine/src/mac-surface.mm#L294) COCOA-TODO: Getting the height to flip round is dependent on a friend.
- [engine/src/mac-window.mm:569](engine/src/mac-window.mm#L569) COCOA-TODO: Make sure this is necessary, apparantly things should
- [engine/src/mac-window.mm:2003](engine/src/mac-window.mm#L2003) COCOA-TODO: Sort out changes that affect window type (not needed at the moment
- [engine/src/mac-window.mm:2040](engine/src/mac-window.mm#L2040) COCOA-TODO: At the moment force a re-display here to stop redraw artifacts.
- [engine/src/mac-window.mm:2301](engine/src/mac-window.mm#L2301) COCOA-TODO: Make display update more specific.
- [engine/src/mblandroidad.cpp:171](engine/src/mblandroidad.cpp#L171) TODO - Should probably improve this to use a similar method to native controls.
- [engine/src/mblandroidcalendar.cpp:79](engine/src/mblandroidcalendar.cpp#L79) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:92](engine/src/mblandroidcalendar.cpp#L92) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:100](engine/src/mblandroidcalendar.cpp#L100) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:108](engine/src/mblandroidcalendar.cpp#L108) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:120](engine/src/mblandroidcalendar.cpp#L120) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:128](engine/src/mblandroidcalendar.cpp#L128) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:136](engine/src/mblandroidcalendar.cpp#L136) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:159](engine/src/mblandroidcalendar.cpp#L159) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:167](engine/src/mblandroidcalendar.cpp#L167) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:176](engine/src/mblandroidcalendar.cpp#L176) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:186](engine/src/mblandroidcalendar.cpp#L186) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:205](engine/src/mblandroidcalendar.cpp#L205) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroidcalendar.cpp:213](engine/src/mblandroidcalendar.cpp#L213) TODO - IMPLEMENT SUPPORT FOR API LEVEL 14
- [engine/src/mblandroiddialog.cpp:142](engine/src/mblandroiddialog.cpp#L142) TODO - java -> stringref conversion
- [engine/src/mblandroidjava.cpp:784](engine/src/mblandroidjava.cpp#L784) TODO: check for exceptions
- [engine/src/mblandroidjava.cpp:847](engine/src/mblandroidjava.cpp#L847) TODO: check for exceptions
- [engine/src/mblandroidjava.cpp:1343](engine/src/mblandroidjava.cpp#L1343) TODO
- [engine/src/mblandroidjava.cpp:1348](engine/src/mblandroidjava.cpp#L1348) TODO
- [engine/src/mblandroidjava.cpp:1353](engine/src/mblandroidjava.cpp#L1353) TODO
- [engine/src/mblandroidmisc.cpp:1405](engine/src/mblandroidmisc.cpp#L1405) TODO: doing this properly requires a JNI call
- [engine/src/mblandroidstore.cpp:468](engine/src/mblandroidstore.cpp#L468) TODO - handle errors
- [engine/src/mblandroidstore.cpp:580](engine/src/mblandroidstore.cpp#L580) TODO - handle errors
- [engine/src/mbliphonebusyindicator.mm:186](engine/src/mbliphonebusyindicator.mm#L186) TODO - update for unicode. Change false to the appropriate value.
- [engine/src/mbliphonepick.mm:1094](engine/src/mbliphonepick.mm#L1094) TODO - update to support unicode
- [engine/src/mbliphoneplayer.mm:97](engine/src/mbliphoneplayer.mm#L97) TODO - update
- [engine/src/mbliphoneplayer.mm:669](engine/src/mbliphoneplayer.mm#L669) if (t_status == AVPlayerItemStatusFailed) /* TODO - CHECK THIS
- [engine/src/mbliphonesensor.mm:145](engine/src/mbliphonesensor.mm#L145) TODO: Determine difference between location and heading error properly
- [engine/src/mcio.cpp:77](engine/src/mcio.cpp#L77) TODO - update processes to use MCNameRef
- [engine/src/mcio.cpp:449](engine/src/mcio.cpp#L449) TODO[2017-02-06] Refactor so that this doesn't allocate any
- [engine/src/mixin-refcounted.h:54](engine/src/mixin-refcounted.h#L54) TODO: atomic ops
- [engine/src/mixin-refcounted.h:62](engine/src/mixin-refcounted.h#L62) TODO: atomic ops
- [engine/src/mixin-refcounted.h:70](engine/src/mixin-refcounted.h#L70) TODO: atomic ops
- [engine/src/mode_development.cpp:374](engine/src/mode_development.cpp#L374) TODO: Script Wiping
- [engine/src/module-canvas.cpp:153](engine/src/module-canvas.cpp#L153) TODO - throw error on failure
- [engine/src/module-canvas.cpp:1278](engine/src/module-canvas.cpp#L1278) TODO - implement describe
- [engine/src/module-canvas.cpp:2003](engine/src/module-canvas.cpp#L2003) TODO - handle case of missing normal density image
- [engine/src/module-canvas.cpp:2175](engine/src/module-canvas.cpp#L2175) TODO - ask Mark how to combine hash values
- [engine/src/module-canvas.cpp:2420](engine/src/module-canvas.cpp#L2420) TODO - implement describe
- [engine/src/module-canvas.cpp:2546](engine/src/module-canvas.cpp#L2546) TODO - ask Mark how to combine hash values
- [engine/src/module-canvas.cpp:2907](engine/src/module-canvas.cpp#L2907) TODO - replace this with a binary search :)
- [engine/src/module-canvas.cpp:3092](engine/src/module-canvas.cpp#L3092) TODO - implement describe
- [engine/src/module-canvas.cpp:3346](engine/src/module-canvas.cpp#L3346) TODO - investigate error handling in libgraphics, libskia - don't think skia mem errors are tested for
- [engine/src/module-canvas.cpp:4108](engine/src/module-canvas.cpp#L4108) TODO - implement describe
- [engine/src/module-canvas.cpp:4619](engine/src/module-canvas.cpp#L4619) TODO - compare fonts
- [engine/src/module-canvas.cpp:4625](engine/src/module-canvas.cpp#L4625) TODO - compute font hash
- [engine/src/module-canvas.cpp:4669](engine/src/module-canvas.cpp#L4669) TODO - throw font creation error
- [engine/src/module-canvas.cpp:4736](engine/src/module-canvas.cpp#L4736) TODO - confirm default font size - make configurable?
- [engine/src/module-canvas.cpp:4885](engine/src/module-canvas.cpp#L4885) TODO - throw text measure error
- [engine/src/module-canvas.cpp:4956](engine/src/module-canvas.cpp#L4956) TODO - check this cast to supertype?
- [engine/src/module-canvas.cpp:4961](engine/src/module-canvas.cpp#L4961) TODO - throw error
- [engine/src/module-canvas.cpp:5021](engine/src/module-canvas.cpp#L5021) TODO - throw canvas pop error
- [engine/src/module-canvas.cpp:5121](engine/src/module-canvas.cpp#L5121) TODO - provide canvas description?
- [engine/src/module-canvas.cpp:5152](engine/src/module-canvas.cpp#L5152) TODO - throw error
- [engine/src/module-canvas.cpp:5164](engine/src/module-canvas.cpp#L5164) TODO - throw error
- [engine/src/module-canvas.cpp:5233](engine/src/module-canvas.cpp#L5233) TODO - make stippled a property of solid paint instead of canvas
- [engine/src/module-canvas.cpp:5295](engine/src/module-canvas.cpp#L5295) TODO - throw join style error
- [engine/src/module-canvas.cpp:5313](engine/src/module-canvas.cpp#L5313) TODO - throw cap style error
- [engine/src/module-canvas.cpp:5358](engine/src/module-canvas.cpp#L5358) TODO - throw dashes list type error
- [engine/src/module-canvas.h:26](engine/src/module-canvas.h#L26) TODO - move to MCImageRep wrapper library
- [engine/src/module-canvas.h:78](engine/src/module-canvas.h#L78) TODO - move to foundation library ?
- [engine/src/module-canvas.h:320](engine/src/module-canvas.h#L320) TODO - Implement image operations
- [engine/src/module-canvas.h:363](engine/src/module-canvas.h#L363) TODO - add skew?"
- [engine/src/module-engine.cpp:527](engine/src/module-engine.cpp#L527) TODO[C++11] This should be "static" but MSVC2010 doesn't support
- [engine/src/object.cpp:661](engine/src/object.cpp#L661) TODO: filter out the C1 control codes too
- [engine/src/object.cpp:1083](engine/src/object.cpp#L1083) TODO[19681]: This can be removed when all engine messages are sent with
- [engine/src/object.h:1734](engine/src/object.h#L1734) TODO[C++11] uint32_t m_part_id = 0;
- [engine/src/object.h:1737](engine/src/object.h#L1737) TODO[2017-04-27] These constructors should be constexpr
- [engine/src/object.h:1738](engine/src/object.h#L1738) TODO[C++11] constexpr MCObjectPartHandle() = default;
- [engine/src/object.h:1743](engine/src/object.h#L1743) TODO[C++11] MCObjectPartHandle(const MCObjectPartHandle&) = default;
- [engine/src/object.h:1746](engine/src/object.h#L1746) TODO[C++11] MCObjectPartHandle(MCObjectPartHandle&& other) = deafult;
- [engine/src/object.h:1757](engine/src/object.h#L1757) TODO[C++11] MCObjectPartHandle& operator=(const MCObjectPartHandle&) = default;
- [engine/src/object.h:1764](engine/src/object.h#L1764) TODO[C++11] MCObjectPartHandle& operator=(MCObjectPartHandle&&) = default;
- [engine/src/paragraf.cpp:168](engine/src/paragraf.cpp#L168) TODO: trunctation
- [engine/src/paragraf.cpp:2235](engine/src/paragraf.cpp#L2235) TODO: truncation if the paragraph would be too long
- [engine/src/paragraf.cpp:2393](engine/src/paragraf.cpp#L2393) TODO: find out if ICU break iterator makes this redundant
- [engine/src/paragraf.cpp:2409](engine/src/paragraf.cpp#L2409) TODO: find out if ICU break iterator makes this redundant
- [engine/src/paragraf.cpp:2586](engine/src/paragraf.cpp#L2586) TODO: is this necessary with the ICU break iterator?
- [engine/src/paragraf.cpp:2604](engine/src/paragraf.cpp#L2604) TODO: is this necessary with the ICU break iterator?
- [engine/src/paragraf.h:881](engine/src/paragraf.h#L881) TODO: this should probably return a StringRef or a codepoint...
- [engine/src/platform-recorder.cpp:50](engine/src/platform-recorder.cpp#L50) TODO - compression
- [engine/src/platform.h:30](engine/src/platform.h#L30) COCOA-TODO: Remove external declaration.
- [engine/src/platform.h:455](engine/src/platform.h#L455) COCOA-TODO: Do these key codes need to be mapped?
- [engine/src/platform.h:473](engine/src/platform.h#L473) TODO-REVIEW: Perhaps these would be better classed as metrics?
- [engine/src/platform.h:717](engine/src/platform.h#L717) COCOA-TODO: Add other drag operation types.
- [engine/src/player-platform.cpp:215](engine/src/player-platform.cpp#L215) TODO: Update this ugly way of adding the inner shadow 'manually'
- [engine/src/player-platform.cpp:495](engine/src/player-platform.cpp#L495) TODO: This popup_closed is for the volume, not the rate
- [engine/src/player-platform.cpp:557](engine/src/player-platform.cpp#L557) TODO: Update this ugly way of adding the inner shadow 'manually'
- [engine/src/player-platform.cpp:1953](engine/src/player-platform.cpp#L1953) COCOA-TODO
- [engine/src/player-platform.cpp:2078](engine/src/player-platform.cpp#L2078) COCOA-TODO: MCPlayer::getnodes();
- [engine/src/player-platform.cpp:2084](engine/src/player-platform.cpp#L2084) COCOA-TODO: MCPlayer::gethotspots();
- [engine/src/player-platform.cpp:2618](engine/src/player-platform.cpp#L2618) TODO: Update this ugly way of adding the inner shadow 'manually'
- [engine/src/segment.cpp:108](engine/src/segment.cpp#L108) TODO: implement
- [engine/src/segment.cpp:386](engine/src/segment.cpp#L386) TODO: vertical alignment
- [engine/src/segment.cpp:556](engine/src/segment.cpp#L556) TODO: toggle the "reversed" flag on the block or is the encoding enough?
- [engine/src/sha1.cpp:24](engine/src/sha1.cpp#L24) TODO: can we do this in an endian-proof way?
- [engine/src/srvcgi.cpp:1042](engine/src/srvcgi.cpp#L1042) TODO: currently we assume that urlencoded form data is small enough to fit into memory,
- [engine/src/srvscript.cpp:125](engine/src/srvscript.cpp#L125) TODO[2017-02-06] This is fragile; FindFile() should be
- [engine/src/stack.cpp:639](engine/src/stack.cpp#L639) COCOA-TODO: Remove dependence on ifdef
- [engine/src/stack.cpp:1539](engine/src/stack.cpp#L1539) COCOA-TODO: Remove dependence on ifdef
- [engine/src/stack.cpp:1630](engine/src/stack.cpp#L1630) TODO[19681]: This can be removed when all engine messages are sent with
- [engine/src/stackcache.cpp:210](engine/src/stackcache.cpp#L210) if defined(__ARM__) && 0 // TODO
- [engine/src/stackcache.cpp:272](engine/src/stackcache.cpp#L272) if defined(__ARM__) && 0 // TODO
- [engine/src/stackfileformat.cpp:25](engine/src/stackfileformat.cpp#L25) TODO: change this, and comparisons for version >= 7000 / 5500, etc
- [engine/src/sysdefs.h:1386](engine/src/sysdefs.h#L1386) TODO[C++11] MCObject *object = nullptr;
- [engine/src/sysdefs.h:1387](engine/src/sysdefs.h#L1387) TODO[C++11] uint32_t part_id = 0;
- [engine/src/sysdefs.h:1391](engine/src/sysdefs.h#L1391) TODO[C++11] constexpr MCObjectPtr() = default;
- [engine/src/sysdefs.h:1393](engine/src/sysdefs.h#L1393) TODO[C++11] constexpr
- [engine/src/sysspec.cpp:1734](engine/src/sysspec.cpp#L1734) TODO Change to MCDataRef or change Shell to MCStringRef
- [engine/src/text-line.cpp:322](engine/src/text-line.cpp#L322) TODO: implement
- [engine/src/text-pane.cpp:190](engine/src/text-pane.cpp#L190) TODO: examine the list of blocks in the paragraph for paragraph breaks
- [engine/src/text-paragraph.cpp:547](engine/src/text-paragraph.cpp#L547) TODO: margins, padding, etc
- [engine/src/text-paragraph.cpp:556](engine/src/text-paragraph.cpp#L556) TODO: margins, padding, etc
- [engine/src/text-paragraph.cpp:634](engine/src/text-paragraph.cpp#L634) TODO: implement
- [engine/src/text-run.cpp:99](engine/src/text-run.cpp#L99) TODO: proper attributes
- [engine/src/variable.h:155](engine/src/variable.h#L155) TODO: Make 'freed' a state of the variable.
- [engine/src/w32-clipboard.cpp:1229](engine/src/w32-clipboard.cpp#L1229) TODO: implement
- [engine/src/w32-ds-player.cpp:1220](engine/src/w32-ds-player.cpp#L1220) TODO - implement offscreen property
- [engine/src/w32-ds-player.cpp:1232](engine/src/w32-ds-player.cpp#L1232) TODO - implement mirror property
- [engine/src/w32-ds-player.cpp:1454](engine/src/w32-ds-player.cpp#L1454) TODO - implement track switching support
- [engine/src/w32-ds-player.cpp:1460](engine/src/w32-ds-player.cpp#L1460) TODO - implement track switching support
- [engine/src/w32-ds-player.cpp:1466](engine/src/w32-ds-player.cpp#L1466) TODO - implement track switching support
- [engine/src/w32-ds-player.cpp:1471](engine/src/w32-ds-player.cpp#L1471) TODO - implement track switching support
- [engine/src/w32-ds-player.cpp:1740](engine/src/w32-ds-player.cpp#L1740) TODO implement offscreen rendering
- [engine/src/w32-ds-player.cpp:1746](engine/src/w32-ds-player.cpp#L1746) TODO implement offscreen rendering
- [engine/src/w32color.cpp:102](engine/src/w32color.cpp#L102) TODO - This isn't quite right, disable for now
- [engine/src/w32dc.cpp:339](engine/src/w32dc.cpp#L339) TODO - determine the correct value on Win8.1 - this may depend on the display in question
- [engine/src/w32dce.cpp:213](engine/src/w32dce.cpp#L213) TODO - This section needs to be revised as using a hardcoded titlebar size will give the wrong results
- [engine/src/w32dcw32.cpp:849](engine/src/w32dcw32.cpp#L849) TODO: surrogate pairs?
- [engine/src/w32dcw32.cpp:1076](engine/src/w32dcw32.cpp#L1076) TODO: pay attention to the CS_INSERTCHAR and CS_NOMOVECARET flags
- [engine/src/w32dcw32.cpp:1458](engine/src/w32dcw32.cpp#L1458) TODO - look in to this further:
- [engine/src/w32printer.cpp:539](engine/src/w32printer.cpp#L539) TODO - fix half pixels lost when insetting by odd integers
- [engine/src/w32stack.cpp:471](engine/src/w32stack.cpp#L471) TODO - Windows 8 implementation will require getting the appropriate per-window value
- [engine/src/w32stack.cpp:1152](engine/src/w32stack.cpp#L1152) TODO - Windows 8.1 per-monitor DPI-awareness may require the update region be in logical coords
- [engine/src/widget-events.cpp:190](engine/src/widget-events.cpp#L190) WIDGET-TODO: Reinstate FocusEnter
- [engine/src/widget-events.cpp:202](engine/src/widget-events.cpp#L202) WIDGET-TODO: Reinstate FocusLeave
- [engine/src/widget-events.cpp:206](engine/src/widget-events.cpp#L206) TODO: does the unfocus *always* happen before the next focus?
- [engine/src/widget-events.cpp:243](engine/src/widget-events.cpp#L243) WIDGET-TODO: Reinstate keyDown
- [engine/src/widget-events.cpp:253](engine/src/widget-events.cpp#L253) WIDGET-TODO: Reinstate keyUp
- [engine/src/widget-events.cpp:415](engine/src/widget-events.cpp#L415) WIDGET-TODO: Reinstate DragStart
- [engine/src/widget-events.cpp:854](engine/src/widget-events.cpp#L854) WIDGET-TODO: Reinstate DragMove
- [engine/src/widget-events.cpp:872](engine/src/widget-events.cpp#L872) WIDGET-TODO: Reinstate DragEnter
- [engine/src/widget-events.cpp:902](engine/src/widget-events.cpp#L902) WIDGET-TODO: Reinstate DragLeave
- [engine/src/widget-events.cpp:1066](engine/src/widget-events.cpp#L1066) WIDGET-TODO: Reinstate keyDown
- [engine/src/widget-events.cpp:1068](engine/src/widget-events.cpp#L1068) Todo: key gesture (shortcuts, accelerators, etc) processing
- [engine/src/widget-events.cpp:1100](engine/src/widget-events.cpp#L1100) WIDGET-TODO: Reinstate keyUp
- [engine/src/widget-events.cpp:1102](engine/src/widget-events.cpp#L1102) Todo: key gesture (shortcuts, accelerators, etc) processing
- [engine/src/widget-popup.cpp:375](engine/src/widget-popup.cpp#L375) TODO - throw memory error
- [engine/src/widget-popup.cpp:470](engine/src/widget-popup.cpp#L470) TODO - throw error
- [engine/src/widget-syntax.cpp:337](engine/src/widget-syntax.cpp#L337) TODO - coordinate transform
- [engine/src/widget-syntax.cpp:357](engine/src/widget-syntax.cpp#L357) TODO - coordinate transforms
- [engine/src/widget-syntax.cpp:375](engine/src/widget-syntax.cpp#L375) TODO: Implement asynchronous version.
- [engine/src/widget-syntax.cpp:387](engine/src/widget-syntax.cpp#L387) TODO: Implement asynchronous version.
- [engine/src/widget-syntax.cpp:477](engine/src/widget-syntax.cpp#L477) TODO: implement
- [engine/src/widget-syntax.cpp:816](engine/src/widget-syntax.cpp#L816) TODO - throw error: no native layer
- [engine/src/widget-syntax.cpp:830](engine/src/widget-syntax.cpp#L830) TODO - throw error: no native layer
- [engine/src/widget-syntax.cpp:854](engine/src/widget-syntax.cpp#L854) TODO - throw error

<a id="todo-libfoundation"></a>

### TODO: libfoundation (47)

- [libfoundation/include/foundation-locale.h:138](libfoundation/include/foundation-locale.h#L138) TODO: explain the pattern syntax for number formatting
- [libfoundation/include/foundation-span.h:47](libfoundation/include/foundation-span.h#L47) TODO[C++14] Some of the constexpr methods in MCSpan use assertions,
- [libfoundation/include/foundation-span.h:94](libfoundation/include/foundation-span.h#L94) TODO[C++14] Some compilers don't allow statements in
- [libfoundation/include/foundation-span.h:108](libfoundation/include/foundation-span.h#L108) TODO[C++11] MCSpanIterator& operator=(const MCSpanIterator& other) = default;
- [libfoundation/include/foundation-span.h:128](libfoundation/include/foundation-span.h#L128) TODO[C++14] Make these operators constexpr
- [libfoundation/include/foundation-span.h:377](libfoundation/include/foundation-span.h#L377) TODO[C++17] Remove when we have class and struct template type inference
- [libfoundation/include/foundation-span.h:446](libfoundation/include/foundation-span.h#L446) TODO[C++11] Enable this assertion once all our C++ compilers support it.
- [libfoundation/include/foundation-span.h:456](libfoundation/include/foundation-span.h#L456) TODO[C++11] Enable this assertion once all our C++ compilers support it.
- [libfoundation/include/foundation.h:789](libfoundation/include/foundation.h#L789) TODO: re-write when we adopt C++11
- [libfoundation/include/foundation.h:797](libfoundation/include/foundation.h#L797) TODO: re-write when we adopt C++11
- [libfoundation/src/foundation-array.cpp:937](libfoundation/src/foundation-array.cpp#L937) if defined(__ARM__) && 0 // TODO
- [libfoundation/src/foundation-bidi.cpp:380](libfoundation/src/foundation-bidi.cpp#L380) TODO
- [libfoundation/src/foundation-bidi.cpp:783](libfoundation/src/foundation-bidi.cpp#L783) TODO: figure out WTH TR9 is going on about here. Somewhat unclear...
- [libfoundation/src/foundation-data.cpp:894](libfoundation/src/foundation-data.cpp#L894) TODO: Shrink the buffer if its too big.
- [libfoundation/src/foundation-foreign.cpp:967](libfoundation/src/foundation-foreign.cpp#L967) TODO[C++17] Some of the fields in here are left empty, and
- [libfoundation/src/foundation-foreign.cpp:1010](libfoundation/src/foundation-foreign.cpp#L1010) TODO[C++17] We need to use the setup_optional() and
- [libfoundation/src/foundation-hash.h:144](libfoundation/src/foundation-hash.h#L144) TODO[C++11] Enable this assertion once all our C++ compilers support it.
- [libfoundation/src/foundation-hash.h:155](libfoundation/src/foundation-hash.h#L155) TODO[C++11] Enable this assertion once all our C++ compilers support it.
- [libfoundation/src/foundation-locale.cpp:114](libfoundation/src/foundation-locale.cpp#L114) TODO: ability to cache multiple if it turns out these change frequently
- [libfoundation/src/foundation-locale.cpp:118](libfoundation/src/foundation-locale.cpp#L118) TODO: maybe a smarter way of caching pattern-based formatters to allow
- [libfoundation/src/foundation-locale.cpp:540](libfoundation/src/foundation-locale.cpp#L540) TODO: implement
- [libfoundation/src/foundation-objc.mm:959](libfoundation/src/foundation-objc.mm#L959) TODO: Check how things work with protocol class methods
- [libfoundation/src/foundation-pickle.cpp:183](libfoundation/src/foundation-pickle.cpp#L183) TODO: Implement record typeinfo reader.
- [libfoundation/src/foundation-pickle.cpp:225](libfoundation/src/foundation-pickle.cpp#L225) TODO: Implement error typeinfo reader.
- [libfoundation/src/foundation-pickle.cpp:286](libfoundation/src/foundation-pickle.cpp#L286) r_value = MCValueRetain(kMCZero); // TODO - this needs to be real zero
- [libfoundation/src/foundation-pickle.cpp:290](libfoundation/src/foundation-pickle.cpp#L290) r_value = MCValueRetain(kMCOne); // TODO - this needs to be real one
- [libfoundation/src/foundation-pickle.cpp:294](libfoundation/src/foundation-pickle.cpp#L294) r_value = MCValueRetain(kMCMinusOne); // TODO - this needs to be real minus one
- [libfoundation/src/foundation-pickle.cpp:626](libfoundation/src/foundation-pickle.cpp#L626) TODO: Write out record typeinfo.
- [libfoundation/src/foundation-pickle.cpp:642](libfoundation/src/foundation-pickle.cpp#L642) TODO: Write out error typeinfo.
- [libfoundation/src/foundation-private.h:727](libfoundation/src/foundation-private.h#L727) TODO[C++11] Obsolete this macro by using std::reverse from
- [libfoundation/src/foundation-string.cpp:1534](libfoundation/src/foundation-string.cpp#L1534) TODO[2017-03-29] This could be optimised by _not_ copying the
- [libfoundation/src/foundation-string.cpp:3670](libfoundation/src/foundation-string.cpp#L3670) TODO: Implement properly, based on properties of the needle string.
- [libfoundation/src/foundation-string.cpp:6083](libfoundation/src/foundation-string.cpp#L6083) TODO: Shrink the buffer if its too big.
- [libfoundation/src/foundation-unicodechars.cpp:26](libfoundation/src/foundation-unicodechars.cpp#L26) TODO: use ICU
- [libfoundation/src/foundation-unicodechars.cpp:53](libfoundation/src/foundation-unicodechars.cpp#L53) TODO: use ICU
- [libfoundation/src/foundation-unicodechars.cpp:80](libfoundation/src/foundation-unicodechars.cpp#L80) TODO: use ICU
- [libfoundation/src/foundation-unicodechars.cpp:110](libfoundation/src/foundation-unicodechars.cpp#L110) TODO: use ICU
- [libfoundation/src/foundation-value.cpp:763](libfoundation/src/foundation-value.cpp#L763) if defined(__ARM__) && 0 // TODO
- [libfoundation/src/foundation-value.cpp:835](libfoundation/src/foundation-value.cpp#L835) if defined(__ARM__) && 0 // TODO
- [libfoundation/src/foundation-value.cpp:882](libfoundation/src/foundation-value.cpp#L882) if defined(__ARM__) && 0 // TODO
- [libfoundation/src/foundation-value.cpp:1051](libfoundation/src/foundation-value.cpp#L1051) TODO: Shrink the table if necessary (?)
- [libfoundation/src/system-library-linux.hpp:78](libfoundation/src/system-library-linux.hpp#L78) TODO: Use dlerror
- [libfoundation/src/system-library-posix.hpp:106](libfoundation/src/system-library-posix.hpp#L106) TODO: Use dlerror
- [libfoundation/src/system-library-w32.hpp:100](libfoundation/src/system-library-w32.hpp#L100) TODO: Use GetLastError()
- [libfoundation/src/system-library-w32.hpp:145](libfoundation/src/system-library-w32.hpp#L145) TODO[2017-02-21]: Use last error
- [libfoundation/src/system-library-w32.hpp:159](libfoundation/src/system-library-w32.hpp#L159) TODO[20170221] Oh dear, the path is too long to fit into a UINDEX_MAX!?!
- [libfoundation/test/test_system-library.cpp:144](libfoundation/test/test_system-library.cpp#L144) TODO: Test error

<a id="todo-tests"></a>

### TODO: tests (20)

- [tests/_compilertestrunner.livecodescript:165](tests/_compilertestrunner.livecodescript#L165) TODO the marker position should come from the position
- [tests/_compilertestrunnerbehavior.livecodescript:137](tests/_compilertestrunnerbehavior.livecodescript#L137) put " # TODO" after tTestOutput
- [tests/_testerlib.livecodescript:193](tests/_testerlib.livecodescript#L193) case "TODO"
- [tests/_testlib.livecodescript:73](tests/_testlib.livecodescript#L73) case "TODO"
- [tests/_testlib.livecodescript:74](tests/_testlib.livecodescript#L74) return "TODO"
- [tests/_testlib.livecodescript:310](tests/_testlib.livecodescript#L310) _TestOutput pExpectTrue, pDescription, "TODO", pReasonBroken
- [tests/_testlib.livecodescript:707](tests/_testlib.livecodescript#L707) TODO: make externals tests work in standalone test builder
- [tests/_testrunner.lcb:341](tests/_testrunner.lcb#L341) Check for a diagnostic mode (TODO or SKIP)
- [tests/_testrunner.lcb:350](tests/_testrunner.lcb#L350) if 1 is the first offset of " TODO" in tLineElements[2] then
- [tests/lcb/stdlib/char.lcb:277](tests/lcb/stdlib/char.lcb#L277) test diagnostic "TODO 'y' is not in 'xyz'"
- [tests/lcb/stdlib/sort.lcb:42](tests/lcb/stdlib/sort.lcb#L42) TODO allow generation of *any* codepoint
- [tests/lcb/stdlib/string.lcb:63](tests/lcb/stdlib/string.lcb#L63) test diagnostic "TODO test some Unicode corner cases"
- [tests/lcb/stdlib/string.lcb:68](tests/lcb/stdlib/string.lcb#L68) test diagnostic "TODO test some Unicode corner cases"
- [tests/lcb/stdlib/string.lcb:74](tests/lcb/stdlib/string.lcb#L74) test diagnostic "TODO case sensitivity options"
- [tests/lcb/vm/foreign-invoke.lcb:119](tests/lcb/vm/foreign-invoke.lcb#L119) TODO
- [tests/lcs/docs/validate-dictionary.livecodescript:189](tests/lcs/docs/validate-dictionary.livecodescript#L189) !TODO test associations are valid
- [tests/lcs/docs/validate-dictionary.livecodescript:248](tests/lcs/docs/validate-dictionary.livecodescript#L248) TODO this should not be necessary if we fix all these docs but baby steps!!!
- [tests/lcs/docs/validate-dictionary.livecodescript:257](tests/lcs/docs/validate-dictionary.livecodescript#L257) TODO this should not be necessary if we fix all these docs but baby steps!!!
- [tests/lcs/docs/validate-dictionary.livecodescript:330](tests/lcs/docs/validate-dictionary.livecodescript#L330) !TODO parse all summaries and descriptions etc
- [tests/lcs/extensions/libraries/resourcestest/resourcestest.lcb:27](tests/lcs/extensions/libraries/resourcestest/resourcestest.lcb#L27) TODO: once we have 'the contents of resource file' or similar,

<a id="todo-revbrowser"></a>

### TODO: revbrowser (19)

- [revbrowser/src/cefbrowser.cpp:860](revbrowser/src/cefbrowser.cpp#L860) TODO - Load error handling
- [revbrowser/src/cefbrowser.cpp:1171](revbrowser/src/cefbrowser.cpp#L1171) TODO - implement advanced event messages
- [revbrowser/src/cefbrowser.cpp:1207](revbrowser/src/cefbrowser.cpp#L1207) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1212](revbrowser/src/cefbrowser.cpp#L1212) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1218](revbrowser/src/cefbrowser.cpp#L1218) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1305](revbrowser/src/cefbrowser.cpp#L1305) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1311](revbrowser/src/cefbrowser.cpp#L1311) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1316](revbrowser/src/cefbrowser.cpp#L1316) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1322](revbrowser/src/cefbrowser.cpp#L1322) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1478](revbrowser/src/cefbrowser.cpp#L1478) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1537](revbrowser/src/cefbrowser.cpp#L1537) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1676](revbrowser/src/cefbrowser.cpp#L1676) TODO - get result of search
- [revbrowser/src/cefbrowser.cpp:1720](revbrowser/src/cefbrowser.cpp#L1720) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1725](revbrowser/src/cefbrowser.cpp#L1725) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1745](revbrowser/src/cefbrowser.cpp#L1745) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1750](revbrowser/src/cefbrowser.cpp#L1750) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1755](revbrowser/src/cefbrowser.cpp#L1755) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser_lnx.cpp:190](revbrowser/src/cefbrowser_lnx.cpp#L190) TODO - implement
- [revbrowser/src/cefprocess.cpp:130](revbrowser/src/cefprocess.cpp#L130) TODO - IMPLEMENT

<a id="todo-ide"></a>

### TODO: ide (18)

- [ide/Documentation/html_viewer/js/bootstrap.js:1576](ide/Documentation/html_viewer/js/bootstrap.js#L1576) if (that.$element) { // TODO: Check whether guarding this code with this `if` is really necessary.
- [ide/Toolset/libraries/revidelibrary.8.livecodescript:374](ide/Toolset/libraries/revidelibrary.8.livecodescript#L374) TODO: there should be a more transparent way of ordering these
- [ide/Toolset/libraries/revinitialisationlibrary.livecodescript:34](ide/Toolset/libraries/revinitialisationlibrary.livecodescript#L34) TODO: Remove legacy message name
- [ide/Toolset/libraries/revinitialisationlibrary.livecodescript:65](ide/Toolset/libraries/revinitialisationlibrary.livecodescript#L65) TODO: Remove legacy message name
- [ide/Toolset/libraries/revinitialisationlibrary.livecodescript:93](ide/Toolset/libraries/revinitialisationlibrary.livecodescript#L93) TODO: Remove legacy message name
- [ide/Toolset/palettes/dictionary/behaviors/revdictionarybehavior.livecodescript:3](ide/Toolset/palettes/dictionary/behaviors/revdictionarybehavior.livecodescript#L3) *TODO* Tweak the CSS to rearrange things appropriately
- [ide/Toolset/palettes/inspector/editors/com.livecode.pi.editorlist.behavior.livecodescript:121](ide/Toolset/palettes/inspector/editors/com.livecode.pi.editorlist.behavior.livecodescript#L121) TODO: Use 'combine tValueArray with tDelimiter' once we add sorting option to combine
- [ide/Toolset/palettes/inspector/revstandalonesettingsnew.livecodescript:167](ide/Toolset/palettes/inspector/revstandalonesettingsnew.livecodescript#L167) TODO : Property profiles
- [ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript:63](ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript#L63) local sLockDrawing -- todo: add set/get. When locked we don't redraw when data is created, deleted, reordered or updated.
- [ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript:2565](ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript#L2565) todo: can we only perform actions if visible of scrollbar is different than pBoolean?
- [ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript:6638](ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript#L6638) todo: optimize so we don't toggle unless we need to
- [ide/Toolset/palettes/script editor/behaviors/revseeditorbehavior.livecodescript:716](ide/Toolset/palettes/script%20editor/behaviors/revseeditorbehavior.livecodescript#L716) TODO remove use of revAvailableHandlers here (quite invasive)
- [ide/Toolset/palettes/standalone settings/revstandalonesettingsinclusionsrowbehavior.livecodescript:101](ide/Toolset/palettes/standalone%20settings/revstandalonesettingsinclusionsrowbehavior.livecodescript#L101) TODO: Fetch existing value!
- [ide/Toolset/palettes/start center/revStartCenterBehavior.livecodescript:300](ide/Toolset/palettes/start%20center/revStartCenterBehavior.livecodescript#L300) put "lc-todo-list" into tArray[2]["icon"]
- [ide/Toolset/palettes/start center/revStartCenterBehavior.livecodescript:301](ide/Toolset/palettes/start%20center/revStartCenterBehavior.livecodescript#L301) put "lc-todo-list-filled" into tArray[2]["hoverIcon"]
- [ide/Toolset/palettes/start center/revStartCenterBehavior.livecodescript:312](ide/Toolset/palettes/start%20center/revStartCenterBehavior.livecodescript#L312) put "lc-todo-list" into tArray[2]["icon"]
- [ide/Toolset/palettes/start center/revStartCenterBehavior.livecodescript:313](ide/Toolset/palettes/start%20center/revStartCenterBehavior.livecodescript#L313) put "lc-todo-list-filled" into tArray[2]["hoverIcon"]
- [ide/tests/_testrunner.livecodescript:307](ide/tests/_testrunner.livecodescript#L307) TODO Can't get exit status from open process

<a id="todo-toolchain"></a>

### TODO: toolchain (14)

- [toolchain/lc-compile-ffi-java/src/bind.g:178](toolchain/lc-compile-ffi-java/src/bind.g#L178) todo - don't do this
- [toolchain/lc-compile-ffi-java/src/check.g:127](toolchain/lc-compile-ffi-java/src/check.g#L127) TODO
- [toolchain/lc-compile-ffi-java/src/generate.g:588](toolchain/lc-compile-ffi-java/src/generate.g#L588) TODO: Deal with variadic args
- [toolchain/lc-compile-ffi-java/src/generate.g:621](toolchain/lc-compile-ffi-java/src/generate.g#L621) TODO: Deal with variadic args
- [toolchain/lc-compile-ffi-java/src/generate.g:716](toolchain/lc-compile-ffi-java/src/generate.g#L716) TODO: Deal with variadic args
- [toolchain/lc-compile-ffi-java/src/generate.g:1023](toolchain/lc-compile-ffi-java/src/generate.g#L1023) TODO: use appropriate modifiers
- [toolchain/lc-compile/src/check.g:182](toolchain/lc-compile/src/check.g#L182) TODO
- [toolchain/lc-compile/src/check.g:1652](toolchain/lc-compile/src/check.g#L1652) TODO: Remove - we don't restrict types anymore - caveat coder!
- [toolchain/lc-compile/src/emit.cpp:1309](toolchain/lc-compile/src/emit.cpp#L1309) TODO: Sort out context
- [toolchain/lc-compile/src/emit.cpp:1317](toolchain/lc-compile/src/emit.cpp#L1317) TODO: Sort out iterate
- [toolchain/lc-compile/src/emit.cpp:1325](toolchain/lc-compile/src/emit.cpp#L1325) TODO: Sort out iterate
- [toolchain/lc-compile/src/emit.cpp:1491](toolchain/lc-compile/src/emit.cpp#L1491) TODO: Real / Integer types.
- [toolchain/lc-compile/src/generate.g:1839](toolchain/lc-compile/src/generate.g#L1839) TODO
- [toolchain/lc-compile/src/syntax-gen.c:523](toolchain/lc-compile/src/syntax-gen.c#L523) TODO: Check whether node is already a child of target.

<a id="todo-extensions"></a>

### TODO: extensions (12)

- [extensions/libraries/iconsvg/iconsvg.lcb:1375](extensions/libraries/iconsvg/iconsvg.lcb#L1375) put the empty array into tArray["lc-todo-list"]
- [extensions/libraries/iconsvg/iconsvg.lcb:1376](extensions/libraries/iconsvg/iconsvg.lcb#L1376) put "M12.24,10.36A.5.5,0,0,1,12,11c-1.85.76-4.07,5.33-4.77,7a.5.5,0,0,1-.46.31h0A.5.5,0,0,1,6.26,18h0s-.39-.76-2.69-2.29a.5.5,0,1,1,.55-.83,14.73,14.73,0,0,1...
- [extensions/libraries/iconsvg/iconsvg.lcb:1377](extensions/libraries/iconsvg/iconsvg.lcb#L1377) put "0" into tArray["lc-todo-list"]["codepoint"]
- [extensions/libraries/iconsvg/iconsvg.lcb:1379](extensions/libraries/iconsvg/iconsvg.lcb#L1379) put the empty array into tArray["lc-todo-list-filled"]
- [extensions/libraries/iconsvg/iconsvg.lcb:1380](extensions/libraries/iconsvg/iconsvg.lcb#L1380) put "M11.13,3.95V3a.69.69,0,0,0-.69-.69H9.59A2.27,2.27,0,1,0,5,2.27H4.2A.69.69,0,0,0,3.51,3v1h-3A.52.52,0,0,0,0,4.46V20.68a.52.52,0,0,0,.52.52h13.6a.52.52,0,...
- [extensions/libraries/iconsvg/iconsvg.lcb:1381](extensions/libraries/iconsvg/iconsvg.lcb#L1381) put "0" into tArray["lc-todo-list-filled"]["codepoint"]
- [extensions/libraries/timezone/tz/zic.c:2040](extensions/libraries/timezone/tz/zic.c#L2040) register zic_t	todo;
- [extensions/libraries/timezone/tz/zic.c:2057](extensions/libraries/timezone/tz/zic.c#L2057) todo = tadd(trans[i], -gmtoffs[j]);
- [extensions/libraries/timezone/tz/zic.c:2058](extensions/libraries/timezone/tz/zic.c#L2058) } else	todo = trans[i];
- [extensions/libraries/timezone/tz/zic.c:2060](extensions/libraries/timezone/tz/zic.c#L2060) puttzcode(todo, fp);
- [extensions/libraries/timezone/tz/zic.c:2061](extensions/libraries/timezone/tz/zic.c#L2061) else	puttzcode64(todo, fp);
- [extensions/script-libraries/drawing/drawing.livecodescript:2070](extensions/script-libraries/drawing/drawing.livecodescript#L2070) TODO: Handle unit in an appropriate way.

<a id="todo-libgraphics"></a>

### TODO: libgraphics (12)

- [libgraphics/include/graphics.h:261](libgraphics/include/graphics.h#L261) TODO[C++14] In C++11, aggregate initialisation of object types
- [libgraphics/include/graphics.h:274](libgraphics/include/graphics.h#L274) TODO[C++14] In C++11, aggregate initialisation of object types
- [libgraphics/include/graphics.h:288](libgraphics/include/graphics.h#L288) TODO[C++14] In C++11, aggregate initialisation of object types
- [libgraphics/src/context.cpp:649](libgraphics/src/context.cpp#L649) Todo: support rounded rect clip regions
- [libgraphics/src/context.cpp:935](libgraphics/src/context.cpp#L935) TODO: Handle sub-pixel case!
- [libgraphics/src/graphics-internal.h:468](libgraphics/src/graphics-internal.h#L468) TODO: Shift coordinate appropriately
- [libgraphics/src/graphics-internal.h:474](libgraphics/src/graphics-internal.h#L474) TODO: Shift coordinate appropriately
- [libgraphics/src/image.cpp:154](libgraphics/src/image.cpp#L154) TODO: Implement
- [libgraphics/src/image.cpp:160](libgraphics/src/image.cpp#L160) TODO: Implement
- [libgraphics/src/lnxtext.cpp:138](libgraphics/src/lnxtext.cpp#L138) TODO: RTL
- [libgraphics/src/path.cpp:39](libgraphics/src/path.cpp#L39) TODO: Implement
- [libgraphics/src/w32text.cpp:480](libgraphics/src/w32text.cpp#L480) TODO: RTL

<a id="todo-libscript"></a>

### TODO: libscript (12)

- [libscript/src/module-encoding.cpp:73](libscript/src/module-encoding.cpp#L73) TODO: Move binary encode/decode to foundation
- [libscript/src/module-encoding.cpp:80](libscript/src/module-encoding.cpp#L80) TODO: Move binary encode/decode to foundation
- [libscript/src/script-error.cpp:83](libscript/src/script-error.cpp#L83) TODO: Add expected / provided argument counts.
- [libscript/src/script-execute.cpp:288](libscript/src/script-execute.cpp#L288) _Complex long double (TODO)
- [libscript/src/script-execute.cpp:306](libscript/src/script-execute.cpp#L306) TODO: Investigate structs containing long doubles
- [libscript/src/script-execute.cpp:550](libscript/src/script-execute.cpp#L550) TODO: Split UnboxingConvert so that we don't resolve types twice.
- [libscript/src/script-private.h:830](libscript/src/script-private.h#L830) TODO: Make this better for negative numbers.
- [libscript/src/script-validate.hpp:243](libscript/src/script-validate.hpp#L243) TODO: Validate that p_address is the start of an opcode.
- [libscript/src/unittest.lcb:311](libscript/src/unittest.lcb#L311) MCUnitOutputTest(pCondition, "", "TODO", "")
- [libscript/src/unittest.lcb:344](libscript/src/unittest.lcb#L344) MCUnitOutputTest(pCondition, pDescription, "TODO", "")
- [libscript/src/unittest.lcb:378](libscript/src/unittest.lcb#L378) MCUnitOutputTest(pCondition, "", "TODO", pReason)
- [libscript/src/unittest.lcb:413](libscript/src/unittest.lcb#L413) MCUnitOutputTest(pCondition, pDescription, "TODO", pReason)

<a id="todo-libbrowser"></a>

### TODO: libbrowser (10)

- [libbrowser/src/libbrowser_android.cpp:601](libbrowser/src/libbrowser_android.cpp#L601) TODO - implement (not needed when used with native layers)
- [libbrowser/src/libbrowser_android.cpp:607](libbrowser/src/libbrowser_android.cpp#L607) TODO - implement (not needed when used with native layers)
- [libbrowser/src/libbrowser_cef.cpp:419](libbrowser/src/libbrowser_cef.cpp#L419) TODO[Bug 19381] On Linux and Windows, the in-git-checkout
- [libbrowser/src/libbrowser_cef.cpp:1134](libbrowser/src/libbrowser_cef.cpp#L1134) TODO - Implement OnDownload callback
- [libbrowser/src/libbrowser_cef.cpp:1870](libbrowser/src/libbrowser_cef.cpp#L1870) TODO - IMPLEMENT
- [libbrowser/src/libbrowser_cef_lnx.cpp:222](libbrowser/src/libbrowser_cef_lnx.cpp#L222) TODO - implement
- [libbrowser/src/libbrowser_cef_lnx.cpp:229](libbrowser/src/libbrowser_cef_lnx.cpp#L229) TODO - implement
- [libbrowser/src/libbrowser_cef_lnx.cpp:236](libbrowser/src/libbrowser_cef_lnx.cpp#L236) TODO - implement
- [libbrowser/src/libbrowser_cefprocess.cpp:130](libbrowser/src/libbrowser_cefprocess.cpp#L130) TODO - IMPLEMENT
- [libbrowser/src/libbrowser_osx_webview.mm:480](libbrowser/src/libbrowser_osx_webview.mm#L480) TODO - obtain directly from mainFrame dataSource data

<a id="todo-builder"></a>

### TODO: builder (5)

- [builder/builder_utilities.livecodescript:758](builder/builder_utilities.livecodescript#L758) TODO Add YAMLToArray script-library so we can have more
- [builder/docs_builder.livecodescript:154](builder/docs_builder.livecodescript#L154) TODO: Work out why something empty is returned
- [builder/package_compiler.livecodescript:127](builder/package_compiler.livecodescript#L127) TODO: Normalize manifest by adding missing folders
- [builder/package_compiler.livecodescript:168](builder/package_compiler.livecodescript#L168) TODO: Make sure this resolves to the final 'base' file since we don't support
- [builder/tools_builder.livecodescript:410](builder/tools_builder.livecodescript#L410) TODO: Add the initialisation library and init libs in same way as normal standalone building

<a id="todo-top-level"></a>

### TODO: (top level) (3)

- [Makefile:265](Makefile#L265) TODO Replace with real rules
- [common.gypi:21](common.gypi#L21) TODO add windows msvc compiler and crt mode to platform id
- [config.py:472](config.py#L472) TODO [2017-04-11]: This should be 2017, but it is not

<a id="todo-ide-support"></a>

### TODO: ide-support (3)

- [ide-support/revdeploylibraryios.livecodescript:702](ide-support/revdeploylibraryios.livecodescript#L702) TODO: Remove this workaround once bug 22887 is fixed
- [ide-support/revsaveasiosstandalone.livecodescript:317](ide-support/revsaveasiosstandalone.livecodescript#L317) TODO Add support for static libraries and frameworks by linking the engine for a simulator build
- [ide-support/revsaveasiosstandalone.livecodescript:860](ide-support/revsaveasiosstandalone.livecodescript#L860) TODO build executable

<a id="todo-revmobile"></a>

### TODO: revmobile (3)

- [revmobile/src/corecon.h:55](revmobile/src/corecon.h#L55) TODO
- [revmobile/src/corecon.h:93](revmobile/src/corecon.h#L93) TODO
- [revmobile/src/corecon.h:233](revmobile/src/corecon.h#L233) TODO

<a id="todo-revxml"></a>

### TODO: revxml (3)

- [revxml/src/revxml.cpp:2336](revxml/src/revxml.cpp#L2336) TODO !!!
- [revxml/src/revxml.cpp:2339](revxml/src/revxml.cpp#L2339) TODO !!!
- [revxml/src/revxml.cpp:2342](revxml/src/revxml.cpp#L2342) TODO !!!

<a id="todo-prebuilt"></a>

### TODO: prebuilt (2)

- [prebuilt/fetch-libraries.sh:451](prebuilt/fetch-libraries.sh#L451) TODO[2017-03-03] Our official architecture name (as used in
- [prebuilt/fetch-libraries.sh:466](prebuilt/fetch-libraries.sh#L466) TODO[2017-02-17] Monkey-patch in a "Fast" prebuilt

<a id="todo-revdb"></a>

### TODO: revdb (2)

- [revdb/src/odbc_connection.cpp:471](revdb/src/odbc_connection.cpp#L471) TODO: adjust this for putting data-at-execution into action.
- [revdb/src/sqlite_cursor.cpp:308](revdb/src/sqlite_cursor.cpp#L308) TODO: get column characteristics

<a id="todo-config"></a>

### TODO: config (1)

- [config/win32.gypi:32](config/win32.gypi#L32) TODO [2017-04-11]: Remove these overrides when we can use

<a id="todo-lcidlc"></a>

### TODO: lcidlc (1)

- [lcidlc/src/Support.mm:4020](lcidlc/src/Support.mm#L4020) TODO

<a id="todo-revspeech"></a>

### TODO: revspeech (1)

- [revspeech/src/revspeech.cpp:450](revspeech/src/revspeech.cpp#L450) TODO: Add validity checking for given path.

<a id="todo-revvideograbber"></a>

### TODO: revvideograbber (1)

- [revvideograbber/src/qtxcapture.mm:318](revvideograbber/src/qtxcapture.mm#L318) TODO: Query for audio outputs!

<a id="todo-tools"></a>

### TODO: tools (1)

- [tools/SymbolicatorScript.livecodescript:492](tools/SymbolicatorScript.livecodescript#L492) TODO: disable echo for password
