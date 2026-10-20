#!/usr/bin/env python

# This script runs the command that links the web engine: emcc turns the
# relocatable WebAssembly object that gyp links (standalone-community.o) into
# standalone-community-<version>.js and .wasm, with the engine's JavaScript
# libraries, and writes an HTML page for it from the shell template.
#
# It runs under the Python 2.7 that gyp uses, and under Python 3.

from __future__ import print_function

import os
import re
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

    # The C stack. The engine stops a script's recursion well before this
    # (the recursionLimit, 400000 bytes by default).
    'STACK_SIZE': 4 * 1024 * 1024,

    'ALLOW_MEMORY_GROWTH': 1,
    'INITIAL_MEMORY': 64 * 1024 * 1024,

    # The function pointers of LCB handlers (callbacks that extensions give
    # C code) are JavaScript functions added to the function table
    # (libfoundation/src/foundation-handler.cpp)
    'ALLOW_TABLE_GROWTH': 1,

    # The engine only runs in web pages
    'ENVIRONMENT': 'web',

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

command = emcc + optimisation_flags + cflags

for input in options['input']:
    command.append(input)

command += ['-o', options['output'][0]]

for setting in sorted(settings.keys()):
    value = settings[setting]
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

# EXPERIMENT (not for merging): Asyncify's report of what it instruments
# and why, and function names in the WebAssembly, for
# tools/ci/asyncify_report.py
if os.getenv('OXT_ASYNCIFY_ADVISE', '0') != '0':
    command += ['-s', 'ASYNCIFY_ADVISE=1', '--profiling-funcs']
for extra in os.getenv('OXT_ASYNCIFY_EXTRA', '').split():
    command += ['-s', extra]
if os.getenv('OXT_ASYNCIFY_REMOVE', '0') != '0':
    command += ['-s', 'ASYNCIFY_REMOVE=@' + os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                         'emscripten-asyncify-remove.json')]

# Run emcc
# --------

if env_verbose.strip() != '0':
    print(" ".join(command))

emcc_result = subprocess.call(command)
sys.exit(emcc_result)
