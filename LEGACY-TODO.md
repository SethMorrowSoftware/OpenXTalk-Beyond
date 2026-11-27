# FIXME, TODO and HACK notes in the legacy code

Every FIXME, TODO and HACK comment in the code OXT-Beyond inherited: LiveCode Community's engine, libraries, toolchain, externals, extensions and IDE scripts, and Tom Perry's OpenXTalk Lite changes to them. It is a map of known loose ends, kept as a starting point for work; most notes were written by LiveCode's developers years ago, and some may no longer be true. When a fix removes or rewords a note, this list is made again in the same pull request.

Not covered: the third-party libraries in `thirdparty/` (each has its own upstream), the bundled copy of GYP in `gyp/`, the dictionary and guides in `docs/`, OXT-Beyond's own build and CI tools in `tools/ci/` and `tools/oxt/`, and the scripts inside the IDE's binary stacks (`.livecode`, `.rev` and `.oxtstack` files), which a text search cannot read.

How it is made: `tools/oxt/legacy_todo.py` writes this file from a case-insensitive whole-word search for `FIXME`, `TODO` and `HACK` (so `COCOA-TODO` and `V6-TODO` count, and so does "hack" in a sentence). A line with more than one marker is listed under each. Lines where the word is not a note are left out, each kind named in the script (`NOT_NOTES`): the start center's `lc-todo-list` icons, a `todo` variable in the time zone compiler, and the TAP `TODO` directive of the test libraries. Run `python3 tools/oxt/legacy_todo.py` after a change that adds, removes or moves notes; `--check` tells whether this file is up to date. The search is:

```sh
git grep -n -I -i -w -E 'FIXME|TODO|HACK' -- . ':!thirdparty' ':!prebuilt/fetched' ':!gyp' ':!docs' \
    ':!tools/ci' ':!tools/oxt' ':!*.md' ':!*.txt' ':!*.json' ':!*.map' ':!*.strings'
```

| Marker | Notes |
| --- | --- |
| [FIXME](#fixme) | 64 |
| [HACK](#hack) | 32 |
| [TODO](#todo) | 434 |

## FIXME

Code its authors knew to be wrong or incomplete. 64 notes, by part of the repository:

[engine](#fixme-engine) (33), [libfoundation](#fixme-libfoundation) (10), [tests](#fixme-tests) (8), [toolchain](#fixme-toolchain) (6), [extensions](#fixme-extensions) (2), [libscript](#fixme-libscript) (2), [builder](#fixme-builder) (1), [ide](#fixme-ide) (1), [ide-support](#fixme-ide-support) (1)

<a id="fixme-engine"></a>

### FIXME: engine (33)

- [engine/installer-armv6-hf.link:187](engine/installer-armv6-hf.link#L187) FIXME: Why do we need it? When there is no .bss section, we don't
- [engine/src/dispatch.cpp:1658](engine/src/dispatch.cpp#L1658) FIXME This is horrible
- [engine/src/em-dc-mainloop.cpp:50](engine/src/em-dc-mainloop.cpp#L50) FIXME these functions are pretty much the same for every X_init()
- [engine/src/em-event.js:641](engine/src/em-event.js#L641) FIXME Maybe this should be done in the engine?
- [engine/src/em-event.js:840](engine/src/em-event.js#L840) FIXME not supported
- [engine/src/em-filehandle.cpp:130](engine/src/em-filehandle.cpp#L130) FIXME Figure out why this is needed
- [engine/src/em-filehandle.cpp:155](engine/src/em-filehandle.cpp#L155) FIXME Figure out why this is a success
- [engine/src/em-filehandle.cpp:214](engine/src/em-filehandle.cpp#L214) FIXME figure out why this is a success
- [engine/src/em-main.cpp:89](engine/src/em-main.cpp#L89) FIXME should probably be UTF-8
- [engine/src/em-main.cpp:112](engine/src/em-main.cpp#L112) FIXME should probably be UTF-8
- [engine/src/em-preamble.js:61](engine/src/em-preamble.js#L61) FIXME Should this be moved into the engine?
- [engine/src/em-preamble.js:85](engine/src/em-preamble.js#L85) FIXME Can we cache the capsule locally?
- [engine/src/em-standalone.js:47](engine/src/em-standalone.js#L47) FIXME maybe this needs a helper function in LiveCodeUtil
- [engine/src/em-system.cpp:413](engine/src/em-system.cpp#L413) FIXME Implement CreateAlias() using symlink(2)
- [engine/src/em-system.cpp:424](engine/src/em-system.cpp#L424) FIXME Implement ResolveAlias() using readlink(2)
- [engine/src/em-system.cpp:434](engine/src/em-system.cpp#L434) FIXME use get_current_dir_name() once it's available in Emscripten's
- [engine/src/em-system.cpp:530](engine/src/em-system.cpp#L530) FIXME use scandirat() once it's available in emscripten's libc
- [engine/src/em-system.cpp:743](engine/src/em-system.cpp#L743) FIXME Implement GetFreeDiskSpace()
- [engine/src/em-system.cpp:752](engine/src/em-system.cpp#L752) FIXME Implement GetDevices()
- [engine/src/em-system.cpp:761](engine/src/em-system.cpp#L761) FIXME Implement GetDrives()
- [engine/src/em-system.cpp:921](engine/src/em-system.cpp#L921) FIXME Implement OpenDevice()
- [engine/src/em-system.cpp:974](engine/src/em-system.cpp#L974) FIXME Implement ResolvePath()
- [engine/src/em-url.js:63](engine/src/em-url.js#L63) FIXME maybe this needs a helper function in LiveCodeUtil
- [engine/src/em-url.js:307](engine/src/em-url.js#L307) FIXME this isn't quite correct; we don't correctly
- [engine/src/funcs.h:1139](engine/src/funcs.h#L1139) class MCNativeCharToNum : public MCUnaryFunctionCtxt<MCStringRef, uinteger_t, MCStringsEvalNativeCharToNum, EE_CHARTONUM_BADSOURCE, PE_CHARTONUM_BADPARAM> //...
- [engine/src/funcs.h:1154](engine/src/funcs.h#L1154) EE_NUMTOCHAR_BADSOURCE, PE_NUMTOCHAR_BADPARAM> // FIXME
- [engine/src/funcs.h:1162](engine/src/funcs.h#L1162) EE_NUMTOCHAR_BADSOURCE, PE_NUMTOCHAR_BADPARAM> // FIXME
- [engine/src/funcs.h:1595](engine/src/funcs.h#L1595) EE_CHARTONUM_BADSOURCE, PE_CHARTONUM_BADPARAM> // FIXME
- [engine/src/globals.cpp:993](engine/src/globals.cpp#L993) FIXME use MCProperListRef
- [engine/src/mcsemaphore.h:61](engine/src/mcsemaphore.h#L61) FIXME mark as explicit
- [engine/src/sysspec-url.cpp:345](engine/src/sysspec-url.cpp#L345) FIXME if wait() returns non-zero, cancel the URL
- [engine/src/widget.lcb:922](engine/src/widget.lcb#L922) FIXME not actually implemented
- [engine/src/widget.lcb:1502](engine/src/widget.lcb#L1502) FIXME not implemented

<a id="fixme-libfoundation"></a>

### FIXME: libfoundation (10)

- [libfoundation/include/system-commandline.h:81](libfoundation/include/system-commandline.h#L81) FIXME support for getting the command filename isn't implemented
- [libfoundation/src/foundation-handler.cpp:656](libfoundation/src/foundation-handler.cpp#L656) FIXME Should include information about arguments and return
- [libfoundation/src/foundation-private.h:723](libfoundation/src/foundation-private.h#L723) define __MCAssertIsLocale(x)   MCAssert(nil != (x)) /* FIXME
- [libfoundation/src/system-commandline.cpp:284](libfoundation/src/system-commandline.cpp#L284) return false; /* FIXME proper error
- [libfoundation/src/system-file-w32.cpp:290](libfoundation/src/system-file-w32.cpp#L290) FIXME Remaining weaknesses:
- [libfoundation/src/system-file-w32.cpp:488](libfoundation/src/system-file-w32.cpp#L488) FIXME[2017-04-20] there should be a "basename" function
- [libfoundation/src/system-file-w32.cpp:544](libfoundation/src/system-file-w32.cpp#L544) FIXME Currently, this function -- and thus the files API on Windows
- [libfoundation/src/system-stream.cpp:65](libfoundation/src/system-stream.cpp#L65) FIXME known issues:
- [libfoundation/src/system-stream.cpp:235](libfoundation/src/system-stream.cpp#L235) FIXME see the "known issues" at the top of this file.
- [libfoundation/src/system-stream.cpp:294](libfoundation/src/system-stream.cpp#L294) FIXME see the "known issues" at the top of this file.

<a id="fixme-tests"></a>

### FIXME: tests (8)

- [tests/_testerlib.livecodescript:272](tests/_testerlib.livecodescript#L272) FIXME this really doesn't work properly if LiveCode's stdout
- [tests/_testrunner.lcb:69](tests/_testrunner.lcb#L69) FIXME this should use proper xTalk Builder syntax for string
- [tests/_testrunner.lcb:211](tests/_testrunner.lcb#L211) FIXME HACK HACK HACK
- [tests/_testrunner.lcb:234](tests/_testrunner.lcb#L234) FIXME Currently, this is implemented by redirecting the lc-run's
- [tests/_testrunner.lcb:262](tests/_testrunner.lcb#L262) FIXME Currently, this is implemented by redirecting the lc-run's
- [tests/_testrunner.lcb:266](tests/_testrunner.lcb#L266) FIXME We may want to capture the stderr output into the log at some
- [tests/_testrunner.lcb:415](tests/_testrunner.lcb#L415) FIXME this is stupidly fragile.  We need a command-line
- [tests/lcs/core/logic/isstrictly.livecodescript:43](tests/lcs/core/logic/isstrictly.livecodescript#L43) FIXME can't currently generate nothing values in LCS

<a id="fixme-toolchain"></a>

### FIXME: toolchain (6)

- [toolchain/lc-compile-ffi-java/src/main.c:69](toolchain/lc-compile-ffi-java/src/main.c#L69) FIXME maybe we should use getopt?
- [toolchain/lc-compile-ffi-java/src/main.c:91](toolchain/lc-compile-ffi-java/src/main.c#L91) FIXME This should be expanded to support "-W error",
- [toolchain/lc-compile/src/lc-run.cpp:197](toolchain/lc-compile/src/lc-run.cpp#L197) FIXME This is currently very basic.  For correctness, it should
- [toolchain/lc-compile/src/lc-run.cpp:243](toolchain/lc-compile/src/lc-run.cpp#L243) FIXME Once we have "real" command line arguments, process them
- [toolchain/lc-compile/src/main.c:167](toolchain/lc-compile/src/main.c#L167) FIXME maybe we should use getopt?
- [toolchain/lc-compile/src/main.c:240](toolchain/lc-compile/src/main.c#L240) FIXME This should be expanded to support "-W error",

<a id="fixme-extensions"></a>

### FIXME: extensions (2)

- [extensions/libraries/iconsvg/iconsvg.lcb:1622](extensions/libraries/iconsvg/iconsvg.lcb#L1622) FIXME Just subscript by tResolved once that's implemented
- [extensions/widgets/switchbutton/switchbutton.lcb:415](extensions/widgets/switchbutton/switchbutton.lcb#L415) FIXME This is ugly!

<a id="fixme-libscript"></a>

### FIXME: libscript (2)

- [libscript/src/module-stream.cpp:27](libscript/src/module-stream.cpp#L27) FIXME This check should be handled by MCStreamWrite
- [libscript/src/unittest-impl.lcb:97](libscript/src/unittest-impl.lcb#L97) FIXME this should use LCB encoding library rather than directly

<a id="fixme-builder"></a>

### FIXME: builder (1)

- [builder/docs_builder.livecodescript:390](builder/docs_builder.livecodescript#L390) FIXME This has to be kept in sync with the installer manifest, probably

<a id="fixme-ide"></a>

### FIXME: ide (1)

- [ide/Toolset/libraries/revidelibrary.8.livecodescript:14096](ide/Toolset/libraries/revidelibrary.8.livecodescript#L14096) FIXME There is some inconsistency in the guide's files that we

<a id="fixme-ide-support"></a>

### FIXME: ide-support (1)

- [ide-support/revsaveasemscriptenstandalone.livecodescript:38](ide-support/revsaveasemscriptenstandalone.livecodescript#L38) FIXME

## HACK

Workarounds their authors were not happy with. 32 notes, by part of the repository:

[engine](#hack-engine) (8), [ide](#hack-ide) (8), [libfoundation](#hack-libfoundation) (3), [prebuilt](#hack-prebuilt) (3), [stack-scripts](#hack-stack-scripts) (3), [builder](#hack-builder) (2), [ide-support](#hack-ide-support) (2), [tests](#hack-tests) (2), [extensions](#hack-extensions) (1)

<a id="hack-engine"></a>

### HACK: engine (8)

- [engine/engine.gyp:158](engine/engine.gyp#L158) Really nasty hack to prevent this from being treated as a path
- [engine/src/font.cpp:431](engine/src/font.cpp#L431) This is a really ugly hack to get LTR/RTL overrides working correctly -
- [engine/src/font.cpp:448](engine/src/font.cpp#L448) Another ugly hack - this time, to avoid incoming strings being coerced
- [engine/src/line.h:46](engine/src/line.h#L46) Dirty hack
- [engine/src/mac-dialog.mm:437](engine/src/mac-dialog.mm#L437) MW-2014-07-25: [[ Bug 12250 ]] Hack to find tableview inside the savepanel so we can force
- [engine/src/mac-dialog.mm:458](engine/src/mac-dialog.mm#L458) MW-2014-07-25: [[ Bug 12250 ]] Use the hack from:
- [engine/src/mcutility.h:300](engine/src/mcutility.h#L300) inline char *MC_strchr(const char *s, int c) // HACK for bug in GCC 2.5.x
- [engine/src/paragraf.h:178](engine/src/paragraf.h#L178) Dirty hack until we have a proper styled text object...

<a id="hack-ide"></a>

### HACK: ide (8)

- [ide/Toolset/libraries/revdebuggerlibrary.livecodescript:1442](ide/Toolset/libraries/revdebuggerlibrary.livecodescript#L1442) For now we have to hack this without access to the parser
- [ide/Toolset/libraries/revdebuggerlibrary.livecodescript:2295](ide/Toolset/libraries/revdebuggerlibrary.livecodescript#L2295) calls IDE code, e.g get url. For now we hack around this.
- [ide/Toolset/palettes/behaviors/revinspectorbehavior.livecodescript:47](ide/Toolset/palettes/behaviors/revinspectorbehavior.livecodescript#L47) HACK for stopping the gradient and effects palette getting stuck behind the inspector!!
- [ide/Toolset/palettes/extension manager/revideextensionmanagerstorebehavior.livecodescript:29](ide/Toolset/palettes/extension%20manager/revideextensionmanagerstorebehavior.livecodescript#L29) Hack to get round bug 18946
- [ide/Toolset/palettes/reverrordisplay.livecodescript:576](ide/Toolset/palettes/reverrordisplay.livecodescript#L576) attempting to highlight the appropriate line number. This is a total hack, but there doensn't seem
- [ide/Toolset/palettes/script editor/behaviors/revsecommoneditorbehavior.livecodescript:3710](ide/Toolset/palettes/script%20editor/behaviors/revsecommoneditorbehavior.livecodescript#L3710) First wrap the script to the required width, this is a total hack as doing it properly would take quite a while.
- [ide/Toolset/palettes/script editor/behaviors/revseeditorbehavior.livecodescript:2259](ide/Toolset/palettes/script%20editor/behaviors/revseeditorbehavior.livecodescript#L2259) this is clearly a bit of a hack, but hopefully doing is this way will minimize the risk.
- [ide/Toolset/palettes/script editor/behaviors/revsevariablespanebehavior.livecodescript:116](ide/Toolset/palettes/script%20editor/behaviors/revsevariablespanebehavior.livecodescript#L116) If the user chooses a large font, we need to increase the size of the template, for now we just hack this as

<a id="hack-libfoundation"></a>

### HACK: libfoundation (3)

- [libfoundation/include/foundation.h:370](libfoundation/include/foundation.h#L370) Nasty, evil hack -- remove me
- [libfoundation/src/foundation-locale.cpp:253](libfoundation/src/foundation-locale.cpp#L253) This is a really nasty hack used to work around the fact that nativising
- [libfoundation/src/system-file-posix.cpp:285](libfoundation/src/system-file-posix.cpp#L285) MCAutoStringRefAsSysString instance, so this is a bit of a hack

<a id="hack-prebuilt"></a>

### HACK: prebuilt (3)

- [prebuilt/libicu.gyp:57](prebuilt/libicu.gyp#L57) Hack required due to GYP failure / refusal to treat this as a path
- [prebuilt/libicu.gyp:413](prebuilt/libicu.gyp#L413) Really nasty hack to prevent this from being treated as a path
- [prebuilt/thirdparty.gyp:728](prebuilt/thirdparty.gyp#L728) Hack to put licuuc after lharfbuzz in library list

<a id="hack-stack-scripts"></a>

### HACK: stack-scripts (3)

- [stack-scripts/ide/Toolset/palettes/revCore.8.livecode.bst/scripts/stack_revDataViewControl_button_id_1003.livecodescript:709](stack-scripts/ide/Toolset/palettes/revCore.8.livecode.bst/scripts/stack_revDataViewControl_button_id_1003.livecodescript#L709) hack. Use proper algorithm for adding items
- [stack-scripts/ide/Toolset/palettes/revonline.rev.bst/scripts/stack_revOnline_field_id_1006.livecodescript:12](stack-scripts/ide/Toolset/palettes/revonline.rev.bst/scripts/stack_revOnline_field_id_1006.livecodescript#L12) hack
- [stack-scripts/ide/Toolset/palettes/revonline.rev.bst/scripts/stack_revOnline_group_id_31860.livecodescript:64](stack-scripts/ide/Toolset/palettes/revonline.rev.bst/scripts/stack_revOnline_group_id_31860.livecodescript#L64) Temp hack not sure if this is right way to do it

<a id="hack-builder"></a>

### HACK: builder (2)

- [builder/builder_tool.livecodescript:43](builder/builder_tool.livecodescript#L43) Hack the arch from the platform. This should really use
- [builder/release_notes_builder.livecodescript:920](builder/release_notes_builder.livecodescript#L920) Horrible-ish hack for extracting the "real" name of the LiveCode

<a id="hack-ide-support"></a>

### HACK: ide-support (2)

- [ide-support/revdeploylibraryemscripten.livecodescript:262](ide-support/revdeploylibraryemscripten.livecodescript#L262) It will only work if firefox is not already running (or we could try a nasty apple script hack but that susceptible to menu/shortcut changes).
- [ide-support/revsaveasstandalone.livecodescript:1961](ide-support/revsaveasstandalone.livecodescript#L1961) For now however, I've added this hack to allow users to work around the issue themselves.

<a id="hack-tests"></a>

### HACK: tests (2)

- [tests/_testrunner.lcb:211](tests/_testrunner.lcb#L211) FIXME HACK HACK HACK
- [tests/lcb/vm/native-callback.lcb:81](tests/lcb/vm/native-callback.lcb#L81) handler values. We 'hack' this at the moment by massaging the types of

<a id="hack-extensions"></a>

### HACK: extensions (1)

- [extensions/extensions.gyp:213](extensions/extensions.gyp#L213) hack because gyp wants an output

## TODO

Work left for later. 434 notes, by part of the repository:

[engine](#todo-engine) (261), [libfoundation](#todo-libfoundation) (46), [revbrowser](#todo-revbrowser) (19), [toolchain](#todo-toolchain) (14), [ide](#todo-ide) (13), [tests](#todo-tests) (13), [libgraphics](#todo-libgraphics) (12), [libbrowser](#todo-libbrowser) (10), [libscript](#todo-libscript) (8), [stack-scripts](#todo-stack-scripts) (8), [tools](#todo-tools) (7), [builder](#todo-builder) (5), [(top level)](#todo-top-level) (3), [revmobile](#todo-revmobile) (3), [revxml](#todo-revxml) (3), [prebuilt](#todo-prebuilt) (2), [revdb](#todo-revdb) (2), [config](#todo-config) (1), [extensions](#todo-extensions) (1), [lcidlc](#todo-lcidlc) (1), [revspeech](#todo-revspeech) (1), [revvideograbber](#todo-revvideograbber) (1)

<a id="todo-engine"></a>

### TODO: engine (261)

- [engine/exec-tests/filters/EvalUniDecode.test:35](engine/exec-tests/filters/EvalUniDecode.test#L35) TODO - add this platform :)
- [engine/exec-tests/filters/EvalUniEncode.test:35](engine/exec-tests/filters/EvalUniEncode.test#L35) TODO - add this platform :)
- [engine/exec-tests/interface/EvalScreenName.test:8](engine/exec-tests/interface/EvalScreenName.test#L8) TODO - add other platform tests
- [engine/exec-tests/legacy/EvalScreenVendor.test:8](engine/exec-tests/legacy/EvalScreenVendor.test#L8) TODO - add tests for other platforms
- [engine/exec-tests/text/EvalFontLanguage.test:6](engine/exec-tests/text/EvalFontLanguage.test#L6) TODO - test font languages on other platforms
- [engine/exec-tests/text/EvalFontNames.test:11](engine/exec-tests/text/EvalFontNames.test#L11) TODO - check for standard fonts on other platforms
- [engine/exec-tests/text/EvalFontSizes.test:10](engine/exec-tests/text/EvalFontSizes.test#L10) TODO - test font sizes on other platforms
- [engine/exec-tests/text/EvalFontStyles.test:8](engine/exec-tests/text/EvalFontStyles.test#L8) TODO - test font sizes on other platforms
- [engine/src/block.cpp:2377](engine/src/block.cpp#L2377) else if (!IsMacLF()) // TODO: if platform reverses selected text
- [engine/src/browser.lcb:221](engine/src/browser.lcb#L221) TODO - replace literal values with constants when possible
- [engine/src/browser.lcb:240](engine/src/browser.lcb#L240) TODO - replace literal values with constants when possible
- [engine/src/browser.lcb:244](engine/src/browser.lcb#L244) TODO - replace literal values with constants when possible
- [engine/src/canvas.lcb:2197](engine/src/canvas.lcb#L2197) TODO - add image frame index property?
- [engine/src/canvas.lcb:2343](engine/src/canvas.lcb#L2343) TODO - how to specify resize quality?
- [engine/src/canvas.lcb:2344](engine/src/canvas.lcb#L2344) TODO - add resize operation? "resize <image> to <width>,<height>"
- [engine/src/canvas.lcb:2345](engine/src/canvas.lcb#L2345) TODO - implement image operations
- [engine/src/clipboard.cpp:68](engine/src/clipboard.cpp#L68) TODO: atomic operations
- [engine/src/clipboard.cpp:83](engine/src/clipboard.cpp#L83) TODO: atomic operations
- [engine/src/customprinter.cpp:366](engine/src/customprinter.cpp#L366) TODO - fix half pixels lost when insetting by odd integers
- [engine/src/customprinter.cpp:595](engine/src/customprinter.cpp#L595) TODO: Make the rasterization scale depend in some way on current scaling,
- [engine/src/desktop-dc.cpp:146](engine/src/desktop-dc.cpp#L146) COCOA-TODO: Is this still needed?
- [engine/src/desktop-dc.cpp:271](engine/src/desktop-dc.cpp#L271) COCOA-TODO: This is Mac specific
- [engine/src/desktop-dc.cpp:275](engine/src/desktop-dc.cpp#L275) COCOA-TODO: These values should be queryable (once we figure out what
- [engine/src/desktop-menu.cpp:128](engine/src/desktop-menu.cpp#L128) COCOA-TODO: Will require some restructuring in the engine menu code to support unicode
- [engine/src/desktop-stack.cpp:101](engine/src/desktop-stack.cpp#L101) \|\| mode == WM_DRAWER)  // COCOA-TODO: Implement drawers
- [engine/src/desktop-stack.cpp:269](engine/src/desktop-stack.cpp#L269) COCOA-TODO: Make sure contained views also scroll (?)
- [engine/src/desktop.cpp:112](engine/src/desktop.cpp#L112) TODO[2017-04-05] X_init() failed before initialising global
- [engine/src/desktop.cpp:664](engine/src/desktop.cpp#L664) PLATFORM-TODO: Should we do more than this? i.e. Should the dragDrop
- [engine/src/dispatch.cpp:260](engine/src/dispatch.cpp#L260) TODO[19681]: This can be removed when all engine messages are sent with
- [engine/src/dispatch.cpp:299](engine/src/dispatch.cpp#L299) TODO[19681]: This can be removed when all engine messages are sent with
- [engine/src/dispatch.cpp:1652](engine/src/dispatch.cpp#L1652) PLATFORM-TODO: This is needed at the moment to make sure that we don't
- [engine/src/dispatch.cpp:1990](engine/src/dispatch.cpp#L1990) TODO: what about other 'special' chars added by unicode?
- [engine/src/dskmac.cpp:798](engine/src/dskmac.cpp#L798) TODO Check whether the double path resolution is an issue
- [engine/src/dskmac.cpp:1274](engine/src/dskmac.cpp#L1274) TODO assign relevant error code
- [engine/src/dskmac.cpp:1296](engine/src/dskmac.cpp#L1296) TODO assign relevant error code
- [engine/src/dskmac.cpp:1341](engine/src/dskmac.cpp#L1341) void MCS_mac_closeresourcefile(ResFileRefNum p_ref) // TODO: remove?
- [engine/src/dskmac.cpp:1761](engine/src/dskmac.cpp#L1761) TODO Add MCSystemFileHandle::SetStream(char *newptr) ?
- [engine/src/dskmac.cpp:3600](engine/src/dskmac.cpp#L3600) TODO: Report errno appropriately.
- [engine/src/dskmain.cpp:227](engine/src/dskmain.cpp#L227) TODO Remove -g,-geometry flag because it's not used any more
- [engine/src/dskw32.cpp:631](engine/src/dskw32.cpp#L631) TODO: still necessary with GetFileAttributes instead of stat?
- [engine/src/dskw32.cpp:641](engine/src/dskw32.cpp#L641) TODO: still necessary with GetFileAttributes instead of stat?
- [engine/src/em-dc.js:242](engine/src/em-dc.js#L242) TODO - handle cleanup of embedded canvas
- [engine/src/em-event.js:1012](engine/src/em-event.js#L1012) TODO - reenable alt key detection
- [engine/src/em-util.js:308](engine/src/em-util.js#L308) TODO - support more value types
- [engine/src/em-util.js:336](engine/src/em-util.js#L336) TODO - for now, treat functions as objects but we may wish to differentiate them later
- [engine/src/exec-engine.cpp:523](engine/src/exec-engine.cpp#L523) TODO - create as list?
- [engine/src/exec-extension.cpp:781](engine/src/exec-extension.cpp#L781) TODO: Augment error
- [engine/src/exec-interface-stack.cpp:125](engine/src/exec-interface-stack.cpp#L125) TODO
- [engine/src/exec-network.cpp:180](engine/src/exec-network.cpp#L180) TODO - I.M. this is a bit odd, checking if we have permission to resolve a hostname AFTER we've
- [engine/src/exec-pasteboard.cpp:556](engine/src/exec-pasteboard.cpp#L556) TODO: support multiple items
- [engine/src/exec-pasteboard.cpp:691](engine/src/exec-pasteboard.cpp#L691) TODO: support multiple items
- [engine/src/exec-pasteboard.cpp:1418](engine/src/exec-pasteboard.cpp#L1418) TODO: support multiple items
- [engine/src/exec-pasteboard.cpp:1460](engine/src/exec-pasteboard.cpp#L1460) TODO: support multiple items
- [engine/src/externalv1.h:221](engine/src/externalv1.h#L221) V6-TODO: Make sure these return the same as they did in previous versions - i.e. native char
- [engine/src/externalv1.h:360](engine/src/externalv1.h#L360) V6-TODO: This method was never exposed / used so is now unimplemented.
- [engine/src/externalv1.h:363](engine/src/externalv1.h#L363) V6-TODO: These methods are not valid for V6, the array interface needs rethinking at a later
- [engine/src/fieldh.cpp:448](engine/src/fieldh.cpp#L448) TODO: TextIsExplicitLineBreak
- [engine/src/fieldh.cpp:515](engine/src/fieldh.cpp#L515) TODO: the kMCFieldExportEvent{Unicode,Native}Run constants should be merged
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
- [engine/src/internal_development.cpp:31](engine/src/internal_development.cpp#L31) Todo:
- [engine/src/java/com/android/vending/billing/IInAppBillingService.aidl:103](engine/src/java/com/android/vending/billing/IInAppBillingService.aidl#L103) TODO: change this to app-specific keys.
- [engine/src/java/com/android/vending/billing/IInAppBillingService.java:293](engine/src/java/com/android/vending/billing/IInAppBillingService.java#L293) TODO: change this to app-specific keys.
- [engine/src/java/com/android/vending/billing/IInAppBillingService.java:463](engine/src/java/com/android/vending/billing/IInAppBillingService.java#L463) TODO: change this to app-specific keys.
- [engine/src/java/com/runrev/android/NFCModule.java:167](engine/src/java/com/runrev/android/NFCModule.java#L167) Todo - expand this to include more information from the tag
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
- [engine/src/lnxans.cpp:342](engine/src/lnxans.cpp#L342) TODO : This needs to be changed to a proper callback function : gdk_event_handler_set()
- [engine/src/lnxcursor.cpp:108](engine/src/lnxcursor.cpp#L108) TODO: do we need to do this?
- [engine/src/lnxdcs.cpp:289](engine/src/lnxdcs.cpp#L289) TODO: equivalent in GDK?
- [engine/src/lnxdcs.cpp:583](engine/src/lnxdcs.cpp#L583) TODO - We may need to do clipboard persistance here
- [engine/src/lnxflst.cpp:47](engine/src/lnxflst.cpp#L47) TODO: We need to revise the situation periodically and implement
- [engine/src/lnxstack.cpp:304](engine/src/lnxstack.cpp#L304) TODO: initial input focus
- [engine/src/lnxstack.cpp:356](engine/src/lnxstack.cpp#L356) TODO: is this just another way of ensuring on-top-ness?
- [engine/src/lnxstack.cpp:378](engine/src/lnxstack.cpp#L378) TODO: input modality hints
- [engine/src/lnxstack.cpp:456](engine/src/lnxstack.cpp#L456) TODO: test if this comment is still true
- [engine/src/mac-av-player.mm:1556](engine/src/mac-av-player.mm#L1556) TODO: Add more types??
- [engine/src/mac-av-player.mm:1605](engine/src/mac-av-player.mm#L1605) TODO
- [engine/src/mac-core.mm:1688](engine/src/mac-core.mm#L1688) 0x47 */ kMCPlatformKeyCodeNumLock, // COCO-TODO: This should be keypad-clear - double-check!
- [engine/src/mac-core.mm:1755](engine/src/mac-core.mm#L1755) PLATFORM-TODO: Shifted keysym handling should be in the engine rather than
- [engine/src/mac-core.mm:1828](engine/src/mac-core.mm#L1828) COCOA-TODO: Clean up this external dependency.
- [engine/src/mac-core.mm:2350](engine/src/mac-core.mm#L2350) COCOA-TODO: Abstract Command/Control switching.
- [engine/src/mac-core.mm:2458](engine/src/mac-core.mm#L2458) COCOA-TODO: Make this is a little more discerning (only need to reset if
- [engine/src/mac-menu.mm:1921](engine/src/mac-menu.mm#L1921) COCOA-TODO: Abstract Command/Control switching.
- [engine/src/mac-surface.mm:34](engine/src/mac-surface.mm#L34) COCOA-TODO: Clean up external linkage for surface.
- [engine/src/mac-surface.mm:219](engine/src/mac-surface.mm#L219) COCOA-TODO: Getting the height to flip round is dependent on a friend.
- [engine/src/mac-surface.mm:261](engine/src/mac-surface.mm#L261) COCOA-TODO: Getting the height to flip round is dependent on a friend.
- [engine/src/mac-surface.mm:294](engine/src/mac-surface.mm#L294) COCOA-TODO: Getting the height to flip round is dependent on a friend.
- [engine/src/mac-window.mm:604](engine/src/mac-window.mm#L604) COCOA-TODO: Make sure this is necessary, apparantly things should
- [engine/src/mac-window.mm:2059](engine/src/mac-window.mm#L2059) COCOA-TODO: Sort out changes that affect window type (not needed at the moment
- [engine/src/mac-window.mm:2096](engine/src/mac-window.mm#L2096) COCOA-TODO: At the moment force a re-display here to stop redraw artifacts.
- [engine/src/mac-window.mm:2386](engine/src/mac-window.mm#L2386) COCOA-TODO: Make display update more specific.
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
- [engine/src/mblandroiddialog.cpp:148](engine/src/mblandroiddialog.cpp#L148) TODO - java -> stringref conversion
- [engine/src/mblandroidjava.cpp:784](engine/src/mblandroidjava.cpp#L784) TODO: check for exceptions
- [engine/src/mblandroidjava.cpp:847](engine/src/mblandroidjava.cpp#L847) TODO: check for exceptions
- [engine/src/mblandroidjava.cpp:1343](engine/src/mblandroidjava.cpp#L1343) TODO
- [engine/src/mblandroidjava.cpp:1348](engine/src/mblandroidjava.cpp#L1348) TODO
- [engine/src/mblandroidjava.cpp:1353](engine/src/mblandroidjava.cpp#L1353) TODO
- [engine/src/mblandroidmisc.cpp:1405](engine/src/mblandroidmisc.cpp#L1405) TODO: doing this properly requires a JNI call
- [engine/src/mblandroidstore.cpp:468](engine/src/mblandroidstore.cpp#L468) TODO - handle errors
- [engine/src/mblandroidstore.cpp:580](engine/src/mblandroidstore.cpp#L580) TODO - handle errors
- [engine/src/mcio.cpp:81](engine/src/mcio.cpp#L81) TODO - update processes to use MCNameRef
- [engine/src/mcio.cpp:462](engine/src/mcio.cpp#L462) TODO[2017-02-06] Refactor so that this doesn't allocate any
- [engine/src/mixin-refcounted.h:54](engine/src/mixin-refcounted.h#L54) TODO: atomic ops
- [engine/src/mixin-refcounted.h:62](engine/src/mixin-refcounted.h#L62) TODO: atomic ops
- [engine/src/mixin-refcounted.h:70](engine/src/mixin-refcounted.h#L70) TODO: atomic ops
- [engine/src/mode_development.cpp:440](engine/src/mode_development.cpp#L440) TODO: Script Wiping
- [engine/src/module-canvas.cpp:157](engine/src/module-canvas.cpp#L157) TODO - throw error on failure
- [engine/src/module-canvas.cpp:1282](engine/src/module-canvas.cpp#L1282) TODO - implement describe
- [engine/src/module-canvas.cpp:2007](engine/src/module-canvas.cpp#L2007) TODO - handle case of missing normal density image
- [engine/src/module-canvas.cpp:2179](engine/src/module-canvas.cpp#L2179) TODO - ask Mark how to combine hash values
- [engine/src/module-canvas.cpp:2424](engine/src/module-canvas.cpp#L2424) TODO - implement describe
- [engine/src/module-canvas.cpp:2550](engine/src/module-canvas.cpp#L2550) TODO - ask Mark how to combine hash values
- [engine/src/module-canvas.cpp:2911](engine/src/module-canvas.cpp#L2911) TODO - replace this with a binary search :)
- [engine/src/module-canvas.cpp:3096](engine/src/module-canvas.cpp#L3096) TODO - implement describe
- [engine/src/module-canvas.cpp:3350](engine/src/module-canvas.cpp#L3350) TODO - investigate error handling in libgraphics, libskia - don't think skia mem errors are tested for
- [engine/src/module-canvas.cpp:4112](engine/src/module-canvas.cpp#L4112) TODO - implement describe
- [engine/src/module-canvas.cpp:4623](engine/src/module-canvas.cpp#L4623) TODO - compare fonts
- [engine/src/module-canvas.cpp:4629](engine/src/module-canvas.cpp#L4629) TODO - compute font hash
- [engine/src/module-canvas.cpp:4673](engine/src/module-canvas.cpp#L4673) TODO - throw font creation error
- [engine/src/module-canvas.cpp:4740](engine/src/module-canvas.cpp#L4740) TODO - confirm default font size - make configurable?
- [engine/src/module-canvas.cpp:4889](engine/src/module-canvas.cpp#L4889) TODO - throw text measure error
- [engine/src/module-canvas.cpp:4960](engine/src/module-canvas.cpp#L4960) TODO - check this cast to supertype?
- [engine/src/module-canvas.cpp:4965](engine/src/module-canvas.cpp#L4965) TODO - throw error
- [engine/src/module-canvas.cpp:5025](engine/src/module-canvas.cpp#L5025) TODO - throw canvas pop error
- [engine/src/module-canvas.cpp:5125](engine/src/module-canvas.cpp#L5125) TODO - provide canvas description?
- [engine/src/module-canvas.cpp:5156](engine/src/module-canvas.cpp#L5156) TODO - throw error
- [engine/src/module-canvas.cpp:5168](engine/src/module-canvas.cpp#L5168) TODO - throw error
- [engine/src/module-canvas.cpp:5237](engine/src/module-canvas.cpp#L5237) TODO - make stippled a property of solid paint instead of canvas
- [engine/src/module-canvas.cpp:5299](engine/src/module-canvas.cpp#L5299) TODO - throw join style error
- [engine/src/module-canvas.cpp:5317](engine/src/module-canvas.cpp#L5317) TODO - throw cap style error
- [engine/src/module-canvas.cpp:5362](engine/src/module-canvas.cpp#L5362) TODO - throw dashes list type error
- [engine/src/module-canvas.h:26](engine/src/module-canvas.h#L26) TODO - move to MCImageRep wrapper library
- [engine/src/module-canvas.h:78](engine/src/module-canvas.h#L78) TODO - move to foundation library ?
- [engine/src/module-canvas.h:320](engine/src/module-canvas.h#L320) TODO - Implement image operations
- [engine/src/module-canvas.h:363](engine/src/module-canvas.h#L363) TODO - add skew?"
- [engine/src/module-engine.cpp:531](engine/src/module-engine.cpp#L531) TODO[C++11] This should be "static" but MSVC2010 doesn't support
- [engine/src/object.cpp:683](engine/src/object.cpp#L683) TODO: filter out the C1 control codes too
- [engine/src/object.cpp:1142](engine/src/object.cpp#L1142) TODO[19681]: This can be removed when all engine messages are sent with
- [engine/src/object.h:1779](engine/src/object.h#L1779) TODO[C++11] uint32_t m_part_id = 0;
- [engine/src/object.h:1782](engine/src/object.h#L1782) TODO[2017-04-27] These constructors should be constexpr
- [engine/src/object.h:1783](engine/src/object.h#L1783) TODO[C++11] constexpr MCObjectPartHandle() = default;
- [engine/src/object.h:1788](engine/src/object.h#L1788) TODO[C++11] MCObjectPartHandle(const MCObjectPartHandle&) = default;
- [engine/src/object.h:1791](engine/src/object.h#L1791) TODO[C++11] MCObjectPartHandle(MCObjectPartHandle&& other) = deafult;
- [engine/src/object.h:1802](engine/src/object.h#L1802) TODO[C++11] MCObjectPartHandle& operator=(const MCObjectPartHandle&) = default;
- [engine/src/object.h:1809](engine/src/object.h#L1809) TODO[C++11] MCObjectPartHandle& operator=(MCObjectPartHandle&&) = default;
- [engine/src/paragraf.cpp:172](engine/src/paragraf.cpp#L172) TODO: trunctation
- [engine/src/paragraf.cpp:2267](engine/src/paragraf.cpp#L2267) TODO: truncation if the paragraph would be too long
- [engine/src/paragraf.cpp:2425](engine/src/paragraf.cpp#L2425) TODO: find out if ICU break iterator makes this redundant
- [engine/src/paragraf.cpp:2441](engine/src/paragraf.cpp#L2441) TODO: find out if ICU break iterator makes this redundant
- [engine/src/paragraf.cpp:2618](engine/src/paragraf.cpp#L2618) TODO: is this necessary with the ICU break iterator?
- [engine/src/paragraf.cpp:2636](engine/src/paragraf.cpp#L2636) TODO: is this necessary with the ICU break iterator?
- [engine/src/paragraf.h:889](engine/src/paragraf.h#L889) TODO: this should probably return a StringRef or a codepoint...
- [engine/src/platform-recorder.cpp:50](engine/src/platform-recorder.cpp#L50) TODO - compression
- [engine/src/platform.h:35](engine/src/platform.h#L35) COCOA-TODO: Remove external declaration.
- [engine/src/platform.h:460](engine/src/platform.h#L460) COCOA-TODO: Do these key codes need to be mapped?
- [engine/src/platform.h:478](engine/src/platform.h#L478) TODO-REVIEW: Perhaps these would be better classed as metrics?
- [engine/src/platform.h:722](engine/src/platform.h#L722) COCOA-TODO: Add other drag operation types.
- [engine/src/player-platform.cpp:219](engine/src/player-platform.cpp#L219) TODO: Update this ugly way of adding the inner shadow 'manually'
- [engine/src/player-platform.cpp:499](engine/src/player-platform.cpp#L499) TODO: This popup_closed is for the volume, not the rate
- [engine/src/player-platform.cpp:561](engine/src/player-platform.cpp#L561) TODO: Update this ugly way of adding the inner shadow 'manually'
- [engine/src/player-platform.cpp:1957](engine/src/player-platform.cpp#L1957) COCOA-TODO
- [engine/src/player-platform.cpp:2082](engine/src/player-platform.cpp#L2082) COCOA-TODO: MCPlayer::getnodes();
- [engine/src/player-platform.cpp:2088](engine/src/player-platform.cpp#L2088) COCOA-TODO: MCPlayer::gethotspots();
- [engine/src/player-platform.cpp:2622](engine/src/player-platform.cpp#L2622) TODO: Update this ugly way of adding the inner shadow 'manually'
- [engine/src/segment.cpp:108](engine/src/segment.cpp#L108) TODO: implement
- [engine/src/segment.cpp:386](engine/src/segment.cpp#L386) TODO: vertical alignment
- [engine/src/segment.cpp:556](engine/src/segment.cpp#L556) TODO: toggle the "reversed" flag on the block or is the encoding enough?
- [engine/src/sha1.cpp:24](engine/src/sha1.cpp#L24) TODO: can we do this in an endian-proof way?
- [engine/src/srvcgi.cpp:1060](engine/src/srvcgi.cpp#L1060) TODO: currently we assume that urlencoded form data is small enough to fit into memory,
- [engine/src/srvscript.cpp:130](engine/src/srvscript.cpp#L130) TODO[2017-02-06] This is fragile; FindFile() should be
- [engine/src/stack.cpp:668](engine/src/stack.cpp#L668) COCOA-TODO: Remove dependence on ifdef
- [engine/src/stack.cpp:1568](engine/src/stack.cpp#L1568) COCOA-TODO: Remove dependence on ifdef
- [engine/src/stack.cpp:1706](engine/src/stack.cpp#L1706) TODO[19681]: This can be removed when all engine messages are sent with
- [engine/src/stackcache.cpp:210](engine/src/stackcache.cpp#L210) if defined(__ARM__) && 0 // TODO
- [engine/src/stackcache.cpp:272](engine/src/stackcache.cpp#L272) if defined(__ARM__) && 0 // TODO
- [engine/src/stackfileformat.cpp:25](engine/src/stackfileformat.cpp#L25) TODO: change this, and comparisons for version >= 7000 / 5500, etc
- [engine/src/sysdefs.h:1386](engine/src/sysdefs.h#L1386) TODO[C++11] MCObject *object = nullptr;
- [engine/src/sysdefs.h:1387](engine/src/sysdefs.h#L1387) TODO[C++11] uint32_t part_id = 0;
- [engine/src/sysdefs.h:1391](engine/src/sysdefs.h#L1391) TODO[C++11] constexpr MCObjectPtr() = default;
- [engine/src/sysdefs.h:1393](engine/src/sysdefs.h#L1393) TODO[C++11] constexpr
- [engine/src/sysspec.cpp:1818](engine/src/sysspec.cpp#L1818) TODO Change to MCDataRef or change Shell to MCStringRef
- [engine/src/text-line.cpp:322](engine/src/text-line.cpp#L322) TODO: implement
- [engine/src/text-pane.cpp:190](engine/src/text-pane.cpp#L190) TODO: examine the list of blocks in the paragraph for paragraph breaks
- [engine/src/text-paragraph.cpp:547](engine/src/text-paragraph.cpp#L547) TODO: margins, padding, etc
- [engine/src/text-paragraph.cpp:556](engine/src/text-paragraph.cpp#L556) TODO: margins, padding, etc
- [engine/src/text-paragraph.cpp:634](engine/src/text-paragraph.cpp#L634) TODO: implement
- [engine/src/text-run.cpp:99](engine/src/text-run.cpp#L99) TODO: proper attributes
- [engine/src/variable.h:155](engine/src/variable.h#L155) TODO: Make 'freed' a state of the variable.
- [engine/src/w32-clipboard.cpp:1233](engine/src/w32-clipboard.cpp#L1233) TODO: implement
- [engine/src/w32-ds-player.cpp:1543](engine/src/w32-ds-player.cpp#L1543) TODO - implement offscreen property
- [engine/src/w32-ds-player.cpp:1555](engine/src/w32-ds-player.cpp#L1555) TODO - implement mirror property
- [engine/src/w32-ds-player.cpp:1799](engine/src/w32-ds-player.cpp#L1799) TODO - implement track switching support
- [engine/src/w32-ds-player.cpp:1805](engine/src/w32-ds-player.cpp#L1805) TODO - implement track switching support
- [engine/src/w32-ds-player.cpp:1811](engine/src/w32-ds-player.cpp#L1811) TODO - implement track switching support
- [engine/src/w32-ds-player.cpp:1816](engine/src/w32-ds-player.cpp#L1816) TODO - implement track switching support
- [engine/src/w32-ds-player.cpp:2085](engine/src/w32-ds-player.cpp#L2085) TODO implement offscreen rendering
- [engine/src/w32-ds-player.cpp:2091](engine/src/w32-ds-player.cpp#L2091) TODO implement offscreen rendering
- [engine/src/w32color.cpp:102](engine/src/w32color.cpp#L102) TODO - This isn't quite right, disable for now
- [engine/src/w32dc.cpp:344](engine/src/w32dc.cpp#L344) TODO - determine the correct value on Win8.1 - this may depend on the display in question
- [engine/src/w32dce.cpp:213](engine/src/w32dce.cpp#L213) TODO - This section needs to be revised as using a hardcoded titlebar size will give the wrong results
- [engine/src/w32dcw32.cpp:895](engine/src/w32dcw32.cpp#L895) TODO: surrogate pairs?
- [engine/src/w32dcw32.cpp:1122](engine/src/w32dcw32.cpp#L1122) TODO: pay attention to the CS_INSERTCHAR and CS_NOMOVECARET flags
- [engine/src/w32dcw32.cpp:1504](engine/src/w32dcw32.cpp#L1504) TODO - look in to this further:
- [engine/src/w32printer.cpp:543](engine/src/w32printer.cpp#L543) TODO - fix half pixels lost when insetting by odd integers
- [engine/src/w32stack.cpp:560](engine/src/w32stack.cpp#L560) TODO - Windows 8 implementation will require getting the appropriate per-window value
- [engine/src/w32stack.cpp:1241](engine/src/w32stack.cpp#L1241) TODO - Windows 8.1 per-monitor DPI-awareness may require the update region be in logical coords
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
- [engine/src/widget-syntax.cpp:440](engine/src/widget-syntax.cpp#L440) TODO - coordinate transform
- [engine/src/widget-syntax.cpp:460](engine/src/widget-syntax.cpp#L460) TODO - coordinate transforms
- [engine/src/widget-syntax.cpp:478](engine/src/widget-syntax.cpp#L478) TODO: Implement asynchronous version.
- [engine/src/widget-syntax.cpp:490](engine/src/widget-syntax.cpp#L490) TODO: Implement asynchronous version.
- [engine/src/widget-syntax.cpp:580](engine/src/widget-syntax.cpp#L580) TODO: implement
- [engine/src/widget-syntax.cpp:919](engine/src/widget-syntax.cpp#L919) TODO - throw error: no native layer
- [engine/src/widget-syntax.cpp:933](engine/src/widget-syntax.cpp#L933) TODO - throw error: no native layer
- [engine/src/widget-syntax.cpp:957](engine/src/widget-syntax.cpp#L957) TODO - throw error

<a id="todo-libfoundation"></a>

### TODO: libfoundation (46)

- [libfoundation/include/foundation-locale.h:138](libfoundation/include/foundation-locale.h#L138) TODO: explain the pattern syntax for number formatting
- [libfoundation/include/foundation-span.h:47](libfoundation/include/foundation-span.h#L47) TODO[C++14] Some of the constexpr methods in MCSpan use assertions,
- [libfoundation/include/foundation-span.h:94](libfoundation/include/foundation-span.h#L94) TODO[C++14] Some compilers don't allow statements in
- [libfoundation/include/foundation-span.h:108](libfoundation/include/foundation-span.h#L108) TODO[C++11] MCSpanIterator& operator=(const MCSpanIterator& other) = default;
- [libfoundation/include/foundation-span.h:128](libfoundation/include/foundation-span.h#L128) TODO[C++14] Make these operators constexpr
- [libfoundation/include/foundation-span.h:377](libfoundation/include/foundation-span.h#L377) TODO[C++17] Remove when we have class and struct template type inference
- [libfoundation/include/foundation-span.h:446](libfoundation/include/foundation-span.h#L446) TODO[C++11] Enable this assertion once all our C++ compilers support it.
- [libfoundation/include/foundation-span.h:456](libfoundation/include/foundation-span.h#L456) TODO[C++11] Enable this assertion once all our C++ compilers support it.
- [libfoundation/include/foundation.h:793](libfoundation/include/foundation.h#L793) TODO: re-write when we adopt C++11
- [libfoundation/include/foundation.h:801](libfoundation/include/foundation.h#L801) TODO: re-write when we adopt C++11
- [libfoundation/src/foundation-array.cpp:1045](libfoundation/src/foundation-array.cpp#L1045) if defined(__ARM__) && 0 // TODO
- [libfoundation/src/foundation-bidi.cpp:399](libfoundation/src/foundation-bidi.cpp#L399) TODO
- [libfoundation/src/foundation-data.cpp:894](libfoundation/src/foundation-data.cpp#L894) TODO: Shrink the buffer if its too big.
- [libfoundation/src/foundation-foreign.cpp:967](libfoundation/src/foundation-foreign.cpp#L967) TODO[C++17] Some of the fields in here are left empty, and
- [libfoundation/src/foundation-foreign.cpp:1010](libfoundation/src/foundation-foreign.cpp#L1010) TODO[C++17] We need to use the setup_optional() and
- [libfoundation/src/foundation-hash.h:144](libfoundation/src/foundation-hash.h#L144) TODO[C++11] Enable this assertion once all our C++ compilers support it.
- [libfoundation/src/foundation-hash.h:155](libfoundation/src/foundation-hash.h#L155) TODO[C++11] Enable this assertion once all our C++ compilers support it.
- [libfoundation/src/foundation-locale.cpp:118](libfoundation/src/foundation-locale.cpp#L118) TODO: ability to cache multiple if it turns out these change frequently
- [libfoundation/src/foundation-locale.cpp:122](libfoundation/src/foundation-locale.cpp#L122) TODO: maybe a smarter way of caching pattern-based formatters to allow
- [libfoundation/src/foundation-locale.cpp:544](libfoundation/src/foundation-locale.cpp#L544) TODO: implement
- [libfoundation/src/foundation-objc.mm:959](libfoundation/src/foundation-objc.mm#L959) TODO: Check how things work with protocol class methods
- [libfoundation/src/foundation-pickle.cpp:183](libfoundation/src/foundation-pickle.cpp#L183) TODO: Implement record typeinfo reader.
- [libfoundation/src/foundation-pickle.cpp:225](libfoundation/src/foundation-pickle.cpp#L225) TODO: Implement error typeinfo reader.
- [libfoundation/src/foundation-pickle.cpp:286](libfoundation/src/foundation-pickle.cpp#L286) r_value = MCValueRetain(kMCZero); // TODO - this needs to be real zero
- [libfoundation/src/foundation-pickle.cpp:290](libfoundation/src/foundation-pickle.cpp#L290) r_value = MCValueRetain(kMCOne); // TODO - this needs to be real one
- [libfoundation/src/foundation-pickle.cpp:294](libfoundation/src/foundation-pickle.cpp#L294) r_value = MCValueRetain(kMCMinusOne); // TODO - this needs to be real minus one
- [libfoundation/src/foundation-pickle.cpp:626](libfoundation/src/foundation-pickle.cpp#L626) TODO: Write out record typeinfo.
- [libfoundation/src/foundation-pickle.cpp:642](libfoundation/src/foundation-pickle.cpp#L642) TODO: Write out error typeinfo.
- [libfoundation/src/foundation-private.h:740](libfoundation/src/foundation-private.h#L740) TODO[C++11] Obsolete this macro by using std::reverse from
- [libfoundation/src/foundation-string.cpp:1538](libfoundation/src/foundation-string.cpp#L1538) TODO[2017-03-29] This could be optimised by _not_ copying the
- [libfoundation/src/foundation-string.cpp:3674](libfoundation/src/foundation-string.cpp#L3674) TODO: Implement properly, based on properties of the needle string.
- [libfoundation/src/foundation-string.cpp:6087](libfoundation/src/foundation-string.cpp#L6087) TODO: Shrink the buffer if its too big.
- [libfoundation/src/foundation-unicodechars.cpp:26](libfoundation/src/foundation-unicodechars.cpp#L26) TODO: use ICU
- [libfoundation/src/foundation-unicodechars.cpp:53](libfoundation/src/foundation-unicodechars.cpp#L53) TODO: use ICU
- [libfoundation/src/foundation-unicodechars.cpp:80](libfoundation/src/foundation-unicodechars.cpp#L80) TODO: use ICU
- [libfoundation/src/foundation-unicodechars.cpp:110](libfoundation/src/foundation-unicodechars.cpp#L110) TODO: use ICU
- [libfoundation/src/foundation-value.cpp:763](libfoundation/src/foundation-value.cpp#L763) if defined(__ARM__) && 0 // TODO
- [libfoundation/src/foundation-value.cpp:835](libfoundation/src/foundation-value.cpp#L835) if defined(__ARM__) && 0 // TODO
- [libfoundation/src/foundation-value.cpp:882](libfoundation/src/foundation-value.cpp#L882) if defined(__ARM__) && 0 // TODO
- [libfoundation/src/foundation-value.cpp:1051](libfoundation/src/foundation-value.cpp#L1051) TODO: Shrink the table if necessary (?)
- [libfoundation/src/system-library-linux.hpp:78](libfoundation/src/system-library-linux.hpp#L78) TODO: Use dlerror
- [libfoundation/src/system-library-posix.hpp:110](libfoundation/src/system-library-posix.hpp#L110) TODO: Use dlerror
- [libfoundation/src/system-library-w32.hpp:104](libfoundation/src/system-library-w32.hpp#L104) TODO: Use GetLastError()
- [libfoundation/src/system-library-w32.hpp:149](libfoundation/src/system-library-w32.hpp#L149) TODO[2017-02-21]: Use last error
- [libfoundation/src/system-library-w32.hpp:163](libfoundation/src/system-library-w32.hpp#L163) TODO[20170221] Oh dear, the path is too long to fit into a UINDEX_MAX!?!
- [libfoundation/test/test_system-library.cpp:144](libfoundation/test/test_system-library.cpp#L144) TODO: Test error

<a id="todo-revbrowser"></a>

### TODO: revbrowser (19)

- [revbrowser/src/cefbrowser.cpp:1023](revbrowser/src/cefbrowser.cpp#L1023) TODO - Load error handling
- [revbrowser/src/cefbrowser.cpp:1350](revbrowser/src/cefbrowser.cpp#L1350) TODO - implement advanced event messages
- [revbrowser/src/cefbrowser.cpp:1386](revbrowser/src/cefbrowser.cpp#L1386) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1391](revbrowser/src/cefbrowser.cpp#L1391) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1397](revbrowser/src/cefbrowser.cpp#L1397) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1488](revbrowser/src/cefbrowser.cpp#L1488) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1494](revbrowser/src/cefbrowser.cpp#L1494) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1499](revbrowser/src/cefbrowser.cpp#L1499) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1505](revbrowser/src/cefbrowser.cpp#L1505) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1661](revbrowser/src/cefbrowser.cpp#L1661) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1720](revbrowser/src/cefbrowser.cpp#L1720) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1856](revbrowser/src/cefbrowser.cpp#L1856) TODO - get result of search
- [revbrowser/src/cefbrowser.cpp:1900](revbrowser/src/cefbrowser.cpp#L1900) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1905](revbrowser/src/cefbrowser.cpp#L1905) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1925](revbrowser/src/cefbrowser.cpp#L1925) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1930](revbrowser/src/cefbrowser.cpp#L1930) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser.cpp:1935](revbrowser/src/cefbrowser.cpp#L1935) TODO - IMPLEMENT
- [revbrowser/src/cefbrowser_lnx.cpp:190](revbrowser/src/cefbrowser_lnx.cpp#L190) TODO - implement
- [revbrowser/src/cefprocess.cpp:166](revbrowser/src/cefprocess.cpp#L166) TODO - IMPLEMENT

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

<a id="todo-ide"></a>

### TODO: ide (13)

- [ide/Documentation/html_viewer/js/bootstrap.js:1576](ide/Documentation/html_viewer/js/bootstrap.js#L1576) if (that.$element) { // TODO: Check whether guarding this code with this `if` is really necessary.
- [ide/Toolset/libraries/revidelibrary.8.livecodescript:382](ide/Toolset/libraries/revidelibrary.8.livecodescript#L382) TODO: there should be a more transparent way of ordering these
- [ide/Toolset/libraries/revinitialisationlibrary.livecodescript:34](ide/Toolset/libraries/revinitialisationlibrary.livecodescript#L34) TODO: Remove legacy message name
- [ide/Toolset/libraries/revinitialisationlibrary.livecodescript:65](ide/Toolset/libraries/revinitialisationlibrary.livecodescript#L65) TODO: Remove legacy message name
- [ide/Toolset/libraries/revinitialisationlibrary.livecodescript:93](ide/Toolset/libraries/revinitialisationlibrary.livecodescript#L93) TODO: Remove legacy message name
- [ide/Toolset/palettes/dictionary/behaviors/revdictionarybehavior.livecodescript:8](ide/Toolset/palettes/dictionary/behaviors/revdictionarybehavior.livecodescript#L8) *TODO* Tweak the CSS to rearrange things appropriately
- [ide/Toolset/palettes/inspector/editors/com.livecode.pi.editorlist.behavior.livecodescript:121](ide/Toolset/palettes/inspector/editors/com.livecode.pi.editorlist.behavior.livecodescript#L121) TODO: Use 'combine tValueArray with tDelimiter' once we add sorting option to combine
- [ide/Toolset/palettes/inspector/revstandalonesettingsnew.livecodescript:167](ide/Toolset/palettes/inspector/revstandalonesettingsnew.livecodescript#L167) TODO : Property profiles
- [ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript:67](ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript#L67) local sLockDrawing -- todo: add set/get. When locked we don't redraw when data is created, deleted, reordered or updated.
- [ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript:2569](ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript#L2569) todo: can we only perform actions if visible of scrollbar is different than pBoolean?
- [ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript:6642](ide/Toolset/palettes/revdatagridlibrary/behaviorsdatagridbuttonbehavior.livecodescript#L6642) todo: optimize so we don't toggle unless we need to
- [ide/Toolset/palettes/script editor/behaviors/revseeditorbehavior.livecodescript:728](ide/Toolset/palettes/script%20editor/behaviors/revseeditorbehavior.livecodescript#L728) TODO remove use of revAvailableHandlers here (quite invasive)
- [ide/tests/_testrunner.livecodescript:307](ide/tests/_testrunner.livecodescript#L307) TODO Can't get exit status from open process

<a id="todo-tests"></a>

### TODO: tests (13)

- [tests/_compilertestrunner.livecodescript:183](tests/_compilertestrunner.livecodescript#L183) TODO the marker position should come from the position
- [tests/_testlib.livecodescript:739](tests/_testlib.livecodescript#L739) TODO: make externals tests work in standalone test builder
- [tests/lcb/stdlib/char.lcb:277](tests/lcb/stdlib/char.lcb#L277) test diagnostic "TODO 'y' is not in 'xyz'"
- [tests/lcb/stdlib/sort.lcb:42](tests/lcb/stdlib/sort.lcb#L42) TODO allow generation of *any* codepoint
- [tests/lcb/stdlib/string.lcb:63](tests/lcb/stdlib/string.lcb#L63) test diagnostic "TODO test some Unicode corner cases"
- [tests/lcb/stdlib/string.lcb:68](tests/lcb/stdlib/string.lcb#L68) test diagnostic "TODO test some Unicode corner cases"
- [tests/lcb/stdlib/string.lcb:74](tests/lcb/stdlib/string.lcb#L74) test diagnostic "TODO case sensitivity options"
- [tests/lcb/vm/foreign-invoke.lcb:123](tests/lcb/vm/foreign-invoke.lcb#L123) TODO
- [tests/lcs/docs/validate-dictionary.livecodescript:242](tests/lcs/docs/validate-dictionary.livecodescript#L242) !TODO test associations are valid
- [tests/lcs/docs/validate-dictionary.livecodescript:301](tests/lcs/docs/validate-dictionary.livecodescript#L301) TODO this should not be necessary if we fix all these docs but baby steps!!!
- [tests/lcs/docs/validate-dictionary.livecodescript:310](tests/lcs/docs/validate-dictionary.livecodescript#L310) TODO this should not be necessary if we fix all these docs but baby steps!!!
- [tests/lcs/docs/validate-dictionary.livecodescript:383](tests/lcs/docs/validate-dictionary.livecodescript#L383) !TODO parse all summaries and descriptions etc
- [tests/lcs/extensions/libraries/resourcestest/resourcestest.lcb:27](tests/lcs/extensions/libraries/resourcestest/resourcestest.lcb#L27) TODO: once we have 'the contents of resource file' or similar,

<a id="todo-libgraphics"></a>

### TODO: libgraphics (12)

- [libgraphics/include/graphics.h:265](libgraphics/include/graphics.h#L265) TODO[C++14] In C++11, aggregate initialisation of object types
- [libgraphics/include/graphics.h:278](libgraphics/include/graphics.h#L278) TODO[C++14] In C++11, aggregate initialisation of object types
- [libgraphics/include/graphics.h:292](libgraphics/include/graphics.h#L292) TODO[C++14] In C++11, aggregate initialisation of object types
- [libgraphics/src/context.cpp:649](libgraphics/src/context.cpp#L649) Todo: support rounded rect clip regions
- [libgraphics/src/context.cpp:935](libgraphics/src/context.cpp#L935) TODO: Handle sub-pixel case!
- [libgraphics/src/graphics-internal.h:468](libgraphics/src/graphics-internal.h#L468) TODO: Shift coordinate appropriately
- [libgraphics/src/graphics-internal.h:474](libgraphics/src/graphics-internal.h#L474) TODO: Shift coordinate appropriately
- [libgraphics/src/image.cpp:154](libgraphics/src/image.cpp#L154) TODO: Implement
- [libgraphics/src/image.cpp:160](libgraphics/src/image.cpp#L160) TODO: Implement
- [libgraphics/src/lnxtext.cpp:212](libgraphics/src/lnxtext.cpp#L212) TODO: RTL
- [libgraphics/src/path.cpp:43](libgraphics/src/path.cpp#L43) TODO: Implement
- [libgraphics/src/w32text.cpp:484](libgraphics/src/w32text.cpp#L484) TODO: RTL

<a id="todo-libbrowser"></a>

### TODO: libbrowser (10)

- [libbrowser/src/libbrowser_android.cpp:601](libbrowser/src/libbrowser_android.cpp#L601) TODO - implement (not needed when used with native layers)
- [libbrowser/src/libbrowser_android.cpp:607](libbrowser/src/libbrowser_android.cpp#L607) TODO - implement (not needed when used with native layers)
- [libbrowser/src/libbrowser_cef.cpp:511](libbrowser/src/libbrowser_cef.cpp#L511) TODO[Bug 19381] On Linux and Windows, the in-git-checkout
- [libbrowser/src/libbrowser_cef.cpp:1337](libbrowser/src/libbrowser_cef.cpp#L1337) TODO - Implement OnDownload callback
- [libbrowser/src/libbrowser_cef.cpp:2111](libbrowser/src/libbrowser_cef.cpp#L2111) TODO - IMPLEMENT
- [libbrowser/src/libbrowser_cef_lnx.cpp:226](libbrowser/src/libbrowser_cef_lnx.cpp#L226) TODO - implement
- [libbrowser/src/libbrowser_cef_lnx.cpp:233](libbrowser/src/libbrowser_cef_lnx.cpp#L233) TODO - implement
- [libbrowser/src/libbrowser_cef_lnx.cpp:240](libbrowser/src/libbrowser_cef_lnx.cpp#L240) TODO - implement
- [libbrowser/src/libbrowser_cefprocess.cpp:166](libbrowser/src/libbrowser_cefprocess.cpp#L166) TODO - IMPLEMENT
- [libbrowser/src/libbrowser_osx_webview.mm:485](libbrowser/src/libbrowser_osx_webview.mm#L485) TODO - obtain directly from mainFrame dataSource data

<a id="todo-libscript"></a>

### TODO: libscript (8)

- [libscript/src/module-encoding.cpp:73](libscript/src/module-encoding.cpp#L73) TODO: Move binary encode/decode to foundation
- [libscript/src/module-encoding.cpp:80](libscript/src/module-encoding.cpp#L80) TODO: Move binary encode/decode to foundation
- [libscript/src/script-error.cpp:87](libscript/src/script-error.cpp#L87) TODO: Add expected / provided argument counts.
- [libscript/src/script-execute.cpp:293](libscript/src/script-execute.cpp#L293) _Complex long double (TODO)
- [libscript/src/script-execute.cpp:311](libscript/src/script-execute.cpp#L311) TODO: Investigate structs containing long doubles
- [libscript/src/script-execute.cpp:550](libscript/src/script-execute.cpp#L550) TODO: Split UnboxingConvert so that we don't resolve types twice.
- [libscript/src/script-private.h:834](libscript/src/script-private.h#L834) TODO: Make this better for negative numbers.
- [libscript/src/script-validate.hpp:243](libscript/src/script-validate.hpp#L243) TODO: Validate that p_address is the start of an opcode.

<a id="todo-stack-scripts"></a>

### TODO: stack-scripts (8)

- [stack-scripts/ide/Documentation/Docs Helper.livecode.bst/scripts/stack_LibrarySubstack.livecodescript:88](stack-scripts/ide/Documentation/Docs%20Helper.livecode.bst/scripts/stack_LibrarySubstack.livecodescript#L88) !TODO test associations are valid
- [stack-scripts/ide/Documentation/Docs Helper.livecode.bst/scripts/stack_LibrarySubstack.livecodescript:145](stack-scripts/ide/Documentation/Docs%20Helper.livecode.bst/scripts/stack_LibrarySubstack.livecodescript#L145) TODO this should not be necessary if we fix all these docs but baby steps!!!
- [stack-scripts/ide/Documentation/Docs Helper.livecode.bst/scripts/stack_LibrarySubstack.livecodescript:154](stack-scripts/ide/Documentation/Docs%20Helper.livecode.bst/scripts/stack_LibrarySubstack.livecodescript#L154) TODO this should not be necessary if we fix all these docs but baby steps!!!
- [stack-scripts/ide/Documentation/Docs Helper.livecode.bst/scripts/stack_LibrarySubstack.livecodescript:217](stack-scripts/ide/Documentation/Docs%20Helper.livecode.bst/scripts/stack_LibrarySubstack.livecodescript#L217) !TODO parse all summaries and descriptions etc
- [stack-scripts/ide/Toolset/palettes/revCore.8.livecode.bst/scripts/stack_revDataViewControl_button_id_1003.livecodescript:2664](stack-scripts/ide/Toolset/palettes/revCore.8.livecode.bst/scripts/stack_revDataViewControl_button_id_1003.livecodescript#L2664) TODO: [Optimization] When resizing for the first time we should look for auto hide scrollbars.
- [stack-scripts/ide/Toolset/palettes/revCore.8.livecode.bst/scripts/stack_revDataViewControl_button_id_1003.livecodescript:3009](stack-scripts/ide/Toolset/palettes/revCore.8.livecode.bst/scripts/stack_revDataViewControl_button_id_1003.livecodescript#L3009) TODO: Should this value be the average of the current content height?
- [stack-scripts/ide/Toolset/palettes/revCore.8.livecode.bst/scripts/stack_revDataViewControl_button_id_1003.livecodescript:3767](stack-scripts/ide/Toolset/palettes/revCore.8.livecode.bst/scripts/stack_revDataViewControl_button_id_1003.livecodescript#L3767) TODO: is this reliable? What if user renders view again? Will the cache update?
- [stack-scripts/ide/Toolset/palettes/revpreferencesgui.rev.bst/scripts/stack_revPreferencesGUI.livecodescript:22](stack-scripts/ide/Toolset/palettes/revpreferencesgui.rev.bst/scripts/stack_revPreferencesGUI.livecodescript#L22) TODO we need the screen the user has used the menubar on on mac not the screen the menubar is on

<a id="todo-tools"></a>

### TODO: tools (7)

- [tools/SymbolicatorScript.livecodescript:492](tools/SymbolicatorScript.livecodescript#L492) TODO: disable echo for password
- [tools/pages/check_front_page.py:144](tools/pages/check_front_page.py#L144) found, todo = [], [root]
- [tools/pages/check_front_page.py:145](tools/pages/check_front_page.py#L145) while todo:
- [tools/pages/check_front_page.py:146](tools/pages/check_front_page.py#L146) for child in children.get(todo.pop(), []):
- [tools/pages/check_front_page.py:148](tools/pages/check_front_page.py#L148) todo.append(child)
- [tools/pages/lessons/src/41-files.html:60](tools/pages/lessons/src/41-files.html#L60) <pre class="code"><code>put "/home/ada/notes/todo.txt" into tPath
- [tools/pages/lessons/src/41-files.html:66](tools/pages/lessons/src/41-files.html#L66) <pre class="out">todo.txt

<a id="todo-builder"></a>

### TODO: builder (5)

- [builder/builder_utilities.livecodescript:758](builder/builder_utilities.livecodescript#L758) TODO Add YAMLToArray script-library so we can have more
- [builder/docs_builder.livecodescript:157](builder/docs_builder.livecodescript#L157) TODO: Work out why something empty is returned
- [builder/package_compiler.livecodescript:127](builder/package_compiler.livecodescript#L127) TODO: Normalize manifest by adding missing folders
- [builder/package_compiler.livecodescript:168](builder/package_compiler.livecodescript#L168) TODO: Make sure this resolves to the final 'base' file since we don't support
- [builder/tools_builder.livecodescript:410](builder/tools_builder.livecodescript#L410) TODO: Add the initialisation library and init libs in same way as normal standalone building

<a id="todo-top-level"></a>

### TODO: (top level) (3)

- [Makefile:209](Makefile#L209) TODO Replace with real rules
- [common.gypi:25](common.gypi#L25) TODO add windows msvc compiler and crt mode to platform id
- [config.py:470](config.py#L470) TODO [2017-04-11]: This should be 2017, but it is not

<a id="todo-revmobile"></a>

### TODO: revmobile (3)

- [revmobile/src/corecon.h:55](revmobile/src/corecon.h#L55) TODO
- [revmobile/src/corecon.h:93](revmobile/src/corecon.h#L93) TODO
- [revmobile/src/corecon.h:233](revmobile/src/corecon.h#L233) TODO

<a id="todo-revxml"></a>

### TODO: revxml (3)

- [revxml/src/revxml.cpp:2549](revxml/src/revxml.cpp#L2549) TODO !!!
- [revxml/src/revxml.cpp:2552](revxml/src/revxml.cpp#L2552) TODO !!!
- [revxml/src/revxml.cpp:2555](revxml/src/revxml.cpp#L2555) TODO !!!

<a id="todo-prebuilt"></a>

### TODO: prebuilt (2)

- [prebuilt/fetch-libraries.sh:459](prebuilt/fetch-libraries.sh#L459) TODO[2017-03-03] Our official architecture name (as used in
- [prebuilt/fetch-libraries.sh:474](prebuilt/fetch-libraries.sh#L474) TODO[2017-02-17] Monkey-patch in a "Fast" prebuilt

<a id="todo-revdb"></a>

### TODO: revdb (2)

- [revdb/src/odbc_connection.cpp:475](revdb/src/odbc_connection.cpp#L475) TODO: adjust this for putting data-at-execution into action.
- [revdb/src/sqlite_cursor.cpp:308](revdb/src/sqlite_cursor.cpp#L308) TODO: get column characteristics

<a id="todo-config"></a>

### TODO: config (1)

- [config/win32.gypi:36](config/win32.gypi#L36) TODO [2017-04-11]: Remove these overrides when we can use

<a id="todo-extensions"></a>

### TODO: extensions (1)

- [extensions/script-libraries/drawing/drawing.livecodescript:2260](extensions/script-libraries/drawing/drawing.livecodescript#L2260) TODO: Handle unit in an appropriate way.

<a id="todo-lcidlc"></a>

### TODO: lcidlc (1)

- [lcidlc/src/Support.mm:4020](lcidlc/src/Support.mm#L4020) TODO

<a id="todo-revspeech"></a>

### TODO: revspeech (1)

- [revspeech/src/revspeech.cpp:454](revspeech/src/revspeech.cpp#L454) TODO: Add validity checking for given path.

<a id="todo-revvideograbber"></a>

### TODO: revvideograbber (1)

- [revvideograbber/src/qtxcapture.mm:318](revvideograbber/src/qtxcapture.mm#L318) TODO: Query for audio outputs!
