/* Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

/* The xTalk Suite's native libraries on the web (EXPERIMENTAL).
 *
 * On the desktop an LCB extension that binds to "c:sodiumxt>sxt_hash" makes
 * the engine open code/<platform>/sodiumxt.dll (.so, .dylib). A browser
 * opens no library, so both web engines (engine.gyp's development-web, the
 * web IDE's, and standalone, which every HTML5 standalone and the Stack
 * Player are built on) link the libraries into themselves and registers each one here under the name
 * the extension loads it by, as em-externals.cpp registers revXML and the
 * other externals. libfoundation/src/system-library-emscripten.hpp then
 * finds "sodiumxt" by that name, and its symbols in its table.
 *
 * Each library comes from its member of the xTalk Suite as
 * src/code/wasm32-emscripten/<name>.a, pinned in
 * tools/oxt/xtalk-extensions.json ("web_libraries"): one object with the
 * library and a function, <name>_web_exports, that returns the table of
 * every symbol the member's .lcb binds to (the member generates it from
 * the .lcb). DataChannelXT's is not libdatachannel, which needs sockets a
 * page does not have, but the same functions over the browser's own WebRTC
 * (the suite's datachannelxt/src/datachannel_web.cpp). xlsxt's carries a
 * zlib of its own under names of its own (xlxw_*), so the engine's zlib
 * and its cannot meet even before the symbols are made local. gamepadxt's is SDL's
 * gamepad layer, which in a page reads the browser's Gamepad API (and its
 * virtual pads, which need no controller), never a device file. midixt's,
 * like DataChannelXT's, is not its desktop library over a page: RtMidi is
 * left out, and the same midi_* shim runs over the browser's Web MIDI
 * (the suite's midixt/src/midi_web.c), whose one JavaScript import only
 * reads and queues; what arrives waits in a queue that midiPoll drains.
 * tools/web-ide/xtalk_web_libraries.py fetches the pinned
 * archives, makes every other symbol of each object local (so two members
 * that carry the same vendored code, trezor-crypto's in SodiumXT and
 * CoinXT, cannot clash) but C++'s inline and template code, which the
 * linker merges (it says why), and util/emscripten-javascriptify.py links
 * the objects into both engines.
 *
 * audioxt (miniaudio) is the first library that JavaScript calls INTO: a
 * Web Audio ScriptProcessorNode asks it for the next block of sound from
 * the browser's own event loop, between the engine's turns, and so also
 * while the engine is asleep under Asyncify. That is safe because nothing
 * in it yields or calls back into the engine: it is a mixer and decoders,
 * and its events (a sound's end) are polled by script, never delivered.
 * util/emscripten-javascriptify.py keeps its names out of Asyncify.
 *
 * The functions are declared weak: an engine linked without a library (a
 * local build that did not fetch them) has a null address for its function,
 * and that library is simply not registered, so its extension's first call
 * fails as it did before the libraries were linked. The table's layout is
 * MCSLibraryStaticExport's: { symbol, address } pairs, ended by a null
 * symbol. */

#include <foundation.h>
#include <foundation-system.h>

extern "C"
{
	__attribute__((weak)) const MCSLibraryStaticExport *sodiumxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *box2dxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *coinxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *datachannelxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *box3dxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *render3dxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *audioxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *xlsxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *gamepadxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *webpxt_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *barcodext_web_exports(void);
	__attribute__((weak)) const MCSLibraryStaticExport *midixt_web_exports(void);
}

/* The names are those the extensions load: their libraries' files without
 * the extension */
static MCSLibraryStaticInfo s_mc_xtalk_web_libraries[] =
{
	{ nullptr, "sodiumxt", nullptr },
	{ nullptr, "box2dxt", nullptr },
	{ nullptr, "coinxt", nullptr },
	{ nullptr, "datachannelxt", nullptr },
	{ nullptr, "box3dxt", nullptr },
	{ nullptr, "render3dxt", nullptr },
	{ nullptr, "audioxt", nullptr },
	{ nullptr, "xlsxt", nullptr },
	{ nullptr, "gamepadxt", nullptr },
	{ nullptr, "webpxt", nullptr },
	{ nullptr, "barcodext", nullptr },
	{ nullptr, "midixt", nullptr },
};

/* Registered before main(), as em-externals.cpp's are early in startup:
 * the registry is a chain of static records that needs nothing else */
__attribute__((constructor)) static void
MCEmscriptenRegisterXTalkWebLibraries(void)
{
	const MCSLibraryStaticExport *(*t_exports[])(void) =
	{
		sodiumxt_web_exports,
		box2dxt_web_exports,
		coinxt_web_exports,
		datachannelxt_web_exports,
		box3dxt_web_exports,
		render3dxt_web_exports,
		audioxt_web_exports,
		xlsxt_web_exports,
		gamepadxt_web_exports,
		webpxt_web_exports,
		barcodext_web_exports,
		midixt_web_exports,
	};

	for (size_t i = 0; i < sizeof(t_exports) / sizeof(t_exports[0]); i++)
	{
		if (t_exports[i] == nullptr)
			continue;

		s_mc_xtalk_web_libraries[i].exports = t_exports[i]();
		if (s_mc_xtalk_web_libraries[i].exports != nullptr)
			MCSLibraryRegisterStatic(s_mc_xtalk_web_libraries[i]);
	}
}
