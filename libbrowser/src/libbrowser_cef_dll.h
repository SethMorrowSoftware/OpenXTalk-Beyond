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

// The browser widget's CEF code on Windows, in a DLL of its own
//
// CEF 156's headers need C++20, which the engine's MSVC v141 toolset does
// not have. On Windows the CEF half of libbrowser (libbrowser_cef.cpp,
// libbrowser_cef_win.cpp, CEF's C++ wrapper) is built with v143 into
// libbrowser-cef.dll, which the engine loads from Externals/CEF the first
// time a script makes a browser (libbrowser_cef_loader_win.cpp). The engine
// itself stays on v141.
//
// What crosses between the two:
//
// - MCBrowserFactory, MCBrowser and the handlers, as C++ objects called
//   through their virtual functions. Microsoft's toolsets v140 to v143 lay
//   out classes and vtables alike, and each object is deleted by the module
//   that made it (MCBrowserRefCounted::Destroy is virtual).
// - Everything libbrowser keeps one of, which the DLL must not have a
//   second copy of: the memory functions the engine set, the run loop
//   actions and wait functions, and the lists and dictionaries of values
//   handed to the JavaScript handler. The engine passes its own functions
//   for these in MCBrowserCefHost, and the DLL's copies of them only
//   forward (libbrowser_cef_dll_win.cpp).
// - UTF-8 strings the DLL returns (a property's value, a script's result),
//   which the engine frees with free(): both modules link the static
//   Universal CRT, whose malloc and free use the process heap, in Release.
//   (Debug builds of the two would not agree: the debug CRT keeps its own
//   records of each module's blocks.)
//
// Nothing else is shared: the DLL links its own copy of libCore, and the
// weak stubs of libcef load libcef.dll through the engine's support library
// functions, as they did inside the engine.

#ifndef __LIBBROWSER_CEF_DLL_H__
#define __LIBBROWSER_CEF_DLL_H__

#include <libbrowser.h>

#include <stddef.h>
#include <stdint.h>

// Bumped whenever MCBrowserCefHost or the factory's interface changes: the
// DLL refuses a host of another version, so an engine and a DLL from
// different builds fail to make a browser instead of crashing
#define kMCBrowserCefHostVersion 1

#define kMCBrowserCefLibraryName "libbrowser-cef"
#define kMCBrowserCefCreateFactoryName "MCBrowserCefCreateFactory"

struct MCBrowserCefHost
{
	uint32_t version;
	uint32_t size;

	// libbrowser_memory.cpp
	MCBrowserAllocator memory_allocate;
	MCBrowserReallocator memory_reallocate;
	MCBrowserDeallocator memory_deallocate;

	// libbrowser.cpp
	bool (*add_runloop_action)(MCBrowserRunloopCallback p_callback, void *p_context);
	void (*remove_runloop_action)(MCBrowserRunloopCallback p_callback, void *p_context);
	bool (*runloop_wait)(void);
	void (*runloop_break_wait)(void);

	// libbrowser_value.cpp
	bool (*list_create)(MCBrowserListRef &r_list, uint32_t p_size);
	void (*list_release)(MCBrowserListRef p_list);
	bool (*list_set_boolean)(MCBrowserListRef p_list, uint32_t p_index, bool p_value);
	bool (*list_set_integer)(MCBrowserListRef p_list, uint32_t p_index, int32_t p_value);
	bool (*list_set_double)(MCBrowserListRef p_list, uint32_t p_index, double p_value);
	bool (*list_set_utf8_string)(MCBrowserListRef p_list, uint32_t p_index, const char *p_value);
	bool (*list_set_list)(MCBrowserListRef p_list, uint32_t p_index, MCBrowserListRef p_value);
	bool (*list_set_dictionary)(MCBrowserListRef p_list, uint32_t p_index, MCBrowserDictionaryRef p_value);
	bool (*dictionary_create)(MCBrowserDictionaryRef &r_dict, uint32_t p_size);
	void (*dictionary_release)(MCBrowserDictionaryRef p_dict);
	bool (*dictionary_set_boolean)(MCBrowserDictionaryRef p_dict, const char *p_key, bool p_value);
	bool (*dictionary_set_integer)(MCBrowserDictionaryRef p_dict, const char *p_key, int32_t p_value);
	bool (*dictionary_set_double)(MCBrowserDictionaryRef p_dict, const char *p_key, double p_value);
	bool (*dictionary_set_utf8_string)(MCBrowserDictionaryRef p_dict, const char *p_key, const char *p_value);
	bool (*dictionary_set_list)(MCBrowserDictionaryRef p_dict, const char *p_key, MCBrowserListRef p_value);
	bool (*dictionary_set_dictionary)(MCBrowserDictionaryRef p_dict, const char *p_key, MCBrowserDictionaryRef p_value);

	// The engine's (engine/src/util.cpp), which the weak stubs of libcef
	// and the search for libcef.dll use
	void *(*library_load)(const char *p_path);
	void (*library_unload)(void *p_handle);
	char *(*library_copy_native_path)(void *p_handle);
	void *(*library_lookup_symbol)(void *p_handle, const char *p_symbol);
};

// libbrowser-cef.dll's one export: checks the host's version, keeps its
// functions and makes the CEF browser factory (MCCefBrowserFactoryCreate)
typedef bool (*MCBrowserCefCreateFactoryFunc)(const MCBrowserCefHost *p_host, MCBrowserFactoryRef *r_factory);

#endif
