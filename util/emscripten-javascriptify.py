#!/usr/bin/env python

# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

# This script runs the command that links the web engine: emcc turns the
# relocatable WebAssembly object that gyp links (standalone-community.o) into
# standalone-community-<version>.js and .wasm, with the engine's JavaScript
# libraries, and writes an HTML page for it from the shell template.
#
# It runs under the Python 2.7 that gyp uses, and under Python 3.

from __future__ import print_function

import os
import re
import shutil
import subprocess
import sys

# Link settings
# -------------
#
# The compiler settings are in config/emscripten-settings.gypi; these only
# apply when linking.
settings = {
    # The engine's main loop yields to the browser and is resumed by events
    # and timers (em-async.js). Asyncify saves and restores the WebAssembly
    # call stack for that, so a wait can yield from inside a handler too.
    'ASYNCIFY': 1,
    # Room for the saved locals of every function on the stack when the
    # engine yields; deep script recursion needs more than the default.
    'ASYNCIFY_STACK_SIZE': 4 * 1024 * 1024,
    # Asyncify assumes that every call through a function pointer can
    # yield, so it instruments nearly everything, and its largest
    # functions made Safari's optimizing WebAssembly compiler use
    # gigabytes of memory until Safari reloaded the page. So code that the
    # engine never yields inside is left out of it (ASYNCIFY_REMOVE,
    # below), and wasm-opt does not inline a large function into its one
    # caller.
    'BINARYEN_EXTRA_PASSES': '--one-caller-inline-max-function-size=200',

    # The C stack. The engine stops a script's recursion well before this
    # (the recursionLimit, 400000 bytes by default).
    'STACK_SIZE': 4 * 1024 * 1024,

    'ALLOW_MEMORY_GROWTH': 1,
    'INITIAL_MEMORY': 64 * 1024 * 1024,

    # The function pointers of LCB handlers (callbacks that extensions give
    # C code) are JavaScript functions added to the function table
    # (libfoundation/src/foundation-handler.cpp)
    'ALLOW_TABLE_GROWTH': 1,

    # The engine runs in web pages, and in a page's web workers (the
    # Background Workers library: each worker is the engine again, loaded
    # with importScripts). With 'web' alone Emscripten takes a page for
    # granted in its own code: since gamepadxt brought in its HTML5 event
    # library (SDL's gamepads read the Gamepad API through it), the engine
    # read `document` as it loaded, and in a worker, which has none, it
    # failed to load at all. 'web,worker' has Emscripten ask; in a page
    # every answer is the one 'web' assumed
    'ENVIRONMENT': 'web,worker',

    # C++ exceptions are caught where code was compiled to catch them. The
    # engine is not (-fno-exceptions), but revDB's SQLite driver catches
    # what the SQLite library throws on an SQL error (revdb/revdb.gyp,
    # thirdparty/libsqlite/libsqlite.gyp); without this, a throw aborts the
    # engine.
    'DISABLE_EXCEPTION_CATCHING': 0,

    # Runtime functions that the engine's JavaScript (em-*.js) and the page
    # call through Module
    'EXPORTED_RUNTIME_METHODS': [
        'ccall',
        'cwrap',
        'HEAPU8',
        'writeArrayToMemory',
        'addRunDependency',
        'removeRunDependency',
        ],
    }

# The functions that Asyncify leaves alone (names as the C++ demangler
# writes them, * for any characters). Only code that the engine can never
# yield inside belongs here: the engine yields only in MCScreenDC::wait
# (em-async.js), so a library belongs here when nothing it calls back
# (a draw, a read, a comparison, a log function) runs script or waits. If
# the engine did yield inside one of these, the stack would be restored
# wrongly; an engine linked with Asyncify's asserts traps there instead
# (BINARYEN_EXTRA_PASSES with --pass-arg=asyncify-asserts added).
asyncify_remove = [
    # Skia, ICU, FreeType and HarfBuzz: drawing, text and Unicode
    'Sk*', '(anonymous namespace)::Sk*', 'sk_*',
    'icu_78::*', '*_78',
    'FT_*', 'ft_*', 'tt_*', 'TT_*', 'cff_*', 'cf2_*', 'ps_*', 'af_*', 'T1_*', 't1_*', 'sfnt_*',
    'pfr_*', 'pcf_*', 'bdf_*', 'gray_*', 'psh_*',
    'hb_*', 'OT::*',
    # OpenSSL: its certificate check (opensslsocket.cpp) runs no script
    'ossl_*', 'OSSL_*', 'EVP_*', 'evp_*', 'RSA_*', 'rsa_*', 'AES_*', 'aes_*', 'BN_*', 'bn_*',
    'CRYPTO_*', 'ASN1_*', 'asn1_*', 'kdf_*', 'v2i_*', 'i2r_*', 'X509*', 'x509*', 'SHA1*',
    'SHA256*', 'SHA512*', 'sha1_*', 'sha256_*', 'sha512_*', 'MD5*', 'md5_*', 'HMAC*', 'PEM_*',
    'PKCS*', 'OPENSSL_*', 'RAND_*',
    # PCRE and the engine's regular expressions (regex.cpp), which set no
    # callouts
    'MCR_compile*', 'MCR_exec*', 'MCR_free*', 'MCR_clearcache*',
    'pcre16_*', 'match', 'match_ref', 'internal_dfa_exec', 'compile_regex', 'compile_branch',
    'find_minlength', 'set_start_bits', 'find_fixedlength', 'could_be_empty_branch',
    'auto_possessify', 'check_escape', 'add_to_class', 'add_list_to_class',
    'add_not_list_to_class', 'first_significant_code', 'find_recurse', 'is_anchored',
    'is_startline', 'find_firstassertedchar', 'compare_opcodes', 'get_chr_property_list',
    'check_posix_syntax', 'read_repeat_counts', 'expand_workspace', 'adjust_recurse',
    'get_othercase_range', 'set_table_bit', 'set_type_bits', 'set_nottype_bits',
    # libpng, libjpeg and zlib: an image is decoded from data already read
    'png_*', 'jpeg_*', 'jinit_*', 'read_markers',
    'inflate*', 'deflate*', 'crc32*', 'adler32*', '_tr_*',
    # SQLite, whose sync no longer waits for the browser's storage
    # (thirdparty/libsqlite/libsqlite.gyp), and whose callbacks (revDB's
    # row counts, its lpad() function, the math and REGEXP functions the
    # driver adds, thirdparty/libsqlite/src/sqlitefunctions.c) run no
    # script; its largest static functions by name, and the functions of
    # the driver's that call through a pointer: the math functions call
    # libm's, and REGEXP's compiler its next-character function (its
    # matcher, which does too, is named sqlite3re_match)
    'sqlite3*', 'fts3*', 'fts5*', 'yy_reduce', 'balance', 'resolveExprStep', 'exprAnalyze',
    'multiSelect', 'oxt_sql*', 'ceilingFunc', 'logFunc', 'math1Func', 'math2Func',
    're_subcompile_re', 're_subcompile_string',
    # operator new calls a new handler through a pointer, and the engine
    # sets none; leaving it out leaves out much of the engine that only
    # allocates
    'operator new*',
    ]
settings['ASYNCIFY_REMOVE'] = asyncify_remove

# The xTalk Suite's native libraries, which both web engines link
# (--xtalk-objects, below): pure computation over buffers, which calls no
# script back (the suite's rule: no callback runs script), so the engine
# never yields inside them. Their many calls through function pointers
# (libsodium picks its implementations at run time, Box2D's solver calls
# through tables) would otherwise make Asyncify instrument nearly all of
# them. Added only when they are linked, so the lean engine's link
# (--lean-output) is as the web standalone engine's was before them.
asyncify_remove_xtalk = [
    # SodiumXT: the shim and libsodium
    'sxt_*', 'crypto_*', '_crypto_*', 'sodium_*', 'randombytes*', 'argon2*',
    'blake2b*', 'fe25519_*', 'ge25519_*', 'sc25519_*', 'ristretto255_*',
    # Box2Dxt: the shim and Box2D
    'b2*',
    # box3dxt: the shim and Box3D. Their calls through a pointer reach
    # only their own allocator, task and tree-query callbacks, none of
    # which yields; without this the physics step is instrumented
    'b3*',
    # CoinXT: the shim, trezor-crypto and libsecp256k1
    # (a pattern no function matches is a warning of the link: the families
    # the shims never reach are left out)
    'cnx_*', 'ecdsa_*', 'secp256k1_*', 'pbkdf2_*', 'ripemd160*', 'bn_*',
    # DataChannelXT: the shim over the browser's WebRTC, whose one
    # JavaScript import only reads and queues (its events are drained by
    # dcx_poll, never delivered by a call into the engine)
    'dcx_*',
    # audioxt: the shim's exports, and miniaudio, compiled into it, whose
    # every function (its WAV, FLAC and MP3 decoders' too) is named ma_*;
    # the shim's few file-local helpers keep their own names and are
    # instrumented where they call through a pointer. Web Audio calls into
    # it for each block of sound from the browser's own event loop, while
    # the engine may be asleep, and nothing in it yields or calls back into
    # the engine (a sound's end is polled by script). No other ma_* is in
    # the web engine: MySQL's client (libmariadb) is not linked into it.
    # On a test link with the engine's Asyncify settings the list took
    # about 135 KB off the .wasm
    'aux_*', 'ma_*',
    # xlsxt: the shim, and libxlsxwriter, zlib and Expat under the names
    # the member's web build gives their globals (src/xlsx_web_names.h).
    # It reads and writes files in the page's own file system, which
    # never yields. Their file-local functions keep their own names and
    # are instrumented where they call through a pointer (Expat's
    # handlers, zlib's allocator)
    'xlx_*', 'xlxw_*',
    # gamepadxt is not here, on purpose: in an engine built with Asyncify,
    # SDL's delay sleeps through emscripten_sleep (SDL_SYS_DelayNS), and a
    # spinlock that has to wait calls it, so SDL and the shim stay
    # instrumented. A function left out that sleeps stops the engine.
    # webpxt: the shim and libwebp (decoder, encoder, mux, demux and
    # libsharpyuv), whose pixel code is reached through function pointers
    # it sets on first use; buffers in, buffers out
    'wpx_*', 'WebP*', 'VP8*', 'SharpYuv*',
    # barcodext: the shim, zxing-cpp (C++, so by its namespace wherever it
    # stands in a name: a template's name begins with its return type) and
    # the Zint writer backend, its GS1 checks and libzueci under it; a
    # picture in, symbols out. Their file-local functions keep their own
    # names and are instrumented where they call through a pointer
    'bcx_*', '*ZXing::*', '*librscpp::*', 'ZBarcode_*', 'zint_*', 'gs1_*', 'zueci_*',
    # render3dxt: the shim, and the stb_image and fast_obj compiled into
    # it, whose readers call their input functions through pointers (as
    # the shim's text results reach snprintf's). Its drawing calls none,
    # so Asyncify leaves a picture alone either way; its other functions
    # have plain names that could be anyone's, and are not listed
    'r3x_*', 'stbi*', 'fast_obj*',
    # midixt: the shim (midi_*) and its Web MIDI layer, the part of
    # RtMidi's C API the shim calls (rtmidi_*), written over the browser's
    # Web MIDI; RtMidi itself is not in the web build. Like DataChannelXT's,
    # its one JavaScript import only reads and queues: what arrives waits
    # in a queue that midiPoll drains, and nothing calls into the engine
    # from the browser's events. It calls nothing through a pointer; its
    # file-local functions keep their own names and are instrumented where
    # they reach snprintf
    'midi_*', 'rtmidi_*',
    ]

# Engine functions that JavaScript calls by name are exported. Those that
# the engine's own libraries call with ccall() are found in them (below).
exported_functions = [
    '_main',
    '_malloc',
    '_free',
    # runs an LCB handler for the function that stands for it
    # (libfoundation/src/foundation-handler.cpp)
    '_MCHandlerEmscriptenInvoke',
    ]

# Get the build type and the compiler command
# -------------------------------------------

env_verbose = os.getenv('V', '0')
# em++ rather than emcc, so that the C++ library is linked
env_emcc = os.getenv('EMXX', 'em++')
env_build_type = os.getenv('BUILDTYPE', 'Debug')
env_cflags = os.getenv('CFLAGS', '')

if env_build_type == 'Release':
    optimisation_flags = ['-Os', '-g0']
    settings['ASSERTIONS'] = 0
else:
    # Keep function names, so that stack traces can be read
    optimisation_flags = ['-O2', '-g2']
    settings['ASSERTIONS'] = 1

# Separate out separate elements of command line
emcc = env_emcc.split()
cflags = env_cflags.split()

# Process command line options
# ----------------------------
#
# Each option absorbs all subsequent arguments up to the next option.
# Options are identified by the fact they start with "--".

option = None
options = {}
for arg in sys.argv[1:]:
    if arg.startswith('--'):
        option = arg[2:]
        options[option] = []
    else:
        if option is None:
            print('ERROR: unrecognized option \'{}\''.format(arg))
            sys.exit(1)
        options[option].append(arg)

# The xTalk Suite's native libraries (engine/src/em-xtalk-web.cpp): every
# object in the folder --xtalk-objects names (which
# tools/web-ide/xtalk_web_libraries.py fetch writes), linked into the engine.
# A folder that does not exist or holds none links none.
xtalk_objects = []
for folder in options.get('xtalk-objects', []):
    if os.path.isdir(folder):
        xtalk_objects += sorted(os.path.join(folder, name) for name in os.listdir(folder)
                                if name.endswith('.o'))
if xtalk_objects:
    print('Linking the xTalk Suite libraries: ' + ', '.join(os.path.basename(o) for o in xtalk_objects))

# --lean-output <page>: the same engine again without the xTalk Suite's
# libraries, written beside the full one under the same file names in
# another folder (engine.gyp's javascriptify: <PRODUCT_DIR>/lean). The web
# builder gives a standalone that uses none of the libraries this engine
# (getEngineFiles in ide-support/revsaveasemscriptenstandalone.livecodescript),
# which is the engine every standalone had before the libraries were linked;
# the Stack Player and a standalone that uses one get the full one. The
# names are the same so that the .js finds its .wasm, and the page its .js,
# wherever the builder copies them from. Without libraries to leave out, the
# two engines would be the same, so the files are copied.
lean_output = options.get('lean-output', [None])[0]

for required in ['input', 'output']:
    if required not in options or len(options[required]) == 0:
        print('ERROR: missing option \'--{}\''.format(required))
        sys.exit(1)

# Export every engine function that the JavaScript libraries call with
# ccall('<name>', ...)
ccall_re = re.compile(r'''\bccall\(\s*['"]([A-Za-z_][A-Za-z0-9_]*)['"]''')
for library in options.get('js-library', []):
    with open(library) as library_file:
        for name in ccall_re.findall(library_file.read()):
            if '_' + name not in exported_functions:
                exported_functions.append('_' + name)

settings['EXPORTED_FUNCTIONS'] = exported_functions

# Construct emcc command line
# ---------------------------

def link_command(objects, output):
    link_settings = dict(settings)
    if objects:
        link_settings['ASYNCIFY_REMOVE'] = asyncify_remove + asyncify_remove_xtalk

    command = emcc + optimisation_flags + cflags

    for input in options['input']:
        command.append(input)
    command += objects

    command += ['-o', output]

    for setting in sorted(link_settings.keys()):
        value = link_settings[setting]
        if isinstance(value, list):
            value = ','.join(value)
        command += ['-s', '{}={}'.format(setting, value)]

    for option in ['pre-js', 'shell-file', 'js-library']:
        if option in options:
            for value in options[option]:
                command += ['--' + option, value]

    # The browser's storage (IndexedDB) as a file system, which keeps the home
    # folder between visits (em-system.js)
    command += ['-lidbfs.js']
    return command

# Run emcc
# --------

def run(command):
    if env_verbose.strip() != '0':
        print(" ".join(command))
    return subprocess.call(command)

output = options['output'][0]
emcc_result = run(link_command(xtalk_objects, output))
if emcc_result != 0 or not lean_output:
    sys.exit(emcc_result)

lean_folder = os.path.dirname(lean_output)
if lean_folder and not os.path.isdir(lean_folder):
    os.makedirs(lean_folder)
if xtalk_objects:
    print('Linking the lean engine, without the xTalk Suite libraries: ' + lean_output)
    sys.exit(run(link_command([], lean_output)))

base, lean_base = os.path.splitext(output)[0], os.path.splitext(lean_output)[0]
for extension in ('.js', '.wasm', os.path.splitext(output)[1]):
    shutil.copyfile(base + extension, lean_base + extension)
print('No xTalk Suite libraries were linked: the lean engine is a copy, ' + lean_output)
sys.exit(0)
