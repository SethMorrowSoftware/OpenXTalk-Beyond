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

// The engine's half of the CEF browser on Windows: loads libbrowser-cef.dll
// from where libcef.dll is (Externals/CEF, or CEF in a build folder) and
// makes its browser factory (libbrowser_cef_dll.h says why it is a DLL).
// If the DLL is missing, or from another build, the factory is not
// available, as when libcef.dll was missing before.

#include <core.h>
#include <libbrowser.h>

#include "libbrowser_internal.h"
#include "libbrowser_cef_dll.h"

// The engine's (engine/src/util.cpp)
extern "C" void *MCSupportLibraryLoad(const char *p_path);
extern "C" void MCSupportLibraryUnload(void *p_handle);
extern "C" char *MCSupportLibraryCopyNativePath(void *p_handle);
extern "C" void *MCSupportLibraryLookupSymbol(void *p_handle, const char *p_symbol);

static bool MCBrowserCefListCreate(MCBrowserListRef &r_list, uint32_t p_size)
{
	return MCBrowserListCreate(r_list, p_size);
}

static bool MCBrowserCefDictionaryCreate(MCBrowserDictionaryRef &r_dict, uint32_t p_size)
{
	return MCBrowserDictionaryCreate(r_dict, p_size);
}

static void *s_cef_library = nullptr;
static MCBrowserCefCreateFactoryFunc s_create_factory = nullptr;

static bool MCBrowserCefLoadLibrary()
{
	if (s_create_factory != nullptr)
		return true;

	// The order __MCCefGetLibraryPath looks for libcef in
	const char *t_paths[] =
	{
		"./CEF/" kMCBrowserCefLibraryName,
		"./Externals/CEF/" kMCBrowserCefLibraryName,
	};

	for (const char *t_path : t_paths)
	{
		void *t_library = MCSupportLibraryLoad(t_path);
		if (t_library == nullptr)
			continue;

		void *t_symbol = MCSupportLibraryLookupSymbol(t_library, kMCBrowserCefCreateFactoryName);
		if (t_symbol == nullptr)
		{
			MCSupportLibraryUnload(t_library);
			continue;
		}

		// Kept loaded for the life of the process: CEF cannot be started
		// again in one process once it has shut down
		s_cef_library = t_library;
		s_create_factory = reinterpret_cast<MCBrowserCefCreateFactoryFunc>(t_symbol);
		return true;
	}

	return false;
}

bool MCCefBrowserFactoryCreate(MCBrowserFactoryRef &r_factory)
{
	if (!MCBrowserCefLoadLibrary())
		return false;

	MCBrowserCefHost t_host = {};
	t_host.version = kMCBrowserCefHostVersion;
	t_host.size = sizeof(MCBrowserCefHost);

	t_host.memory_allocate = MCBrowserMemoryAllocate;
	t_host.memory_reallocate = MCBrowserMemoryReallocate;
	t_host.memory_deallocate = MCBrowserMemoryDeallocate;

	t_host.add_runloop_action = MCBrowserAddRunloopAction;
	t_host.remove_runloop_action = MCBrowserRemoveRunloopAction;
	t_host.runloop_wait = MCBrowserRunloopWait;
	t_host.runloop_break_wait = MCBrowserRunloopBreakWait;

	t_host.list_create = MCBrowserCefListCreate;
	t_host.list_retain = MCBrowserListRetain;
	t_host.list_release = MCBrowserListRelease;
	t_host.list_set_boolean = MCBrowserListSetBoolean;
	t_host.list_set_integer = MCBrowserListSetInteger;
	t_host.list_set_double = MCBrowserListSetDouble;
	t_host.list_set_utf8_string = MCBrowserListSetUTF8String;
	t_host.list_set_list = MCBrowserListSetList;
	t_host.list_set_dictionary = MCBrowserListSetDictionary;
	t_host.dictionary_create = MCBrowserCefDictionaryCreate;
	t_host.dictionary_release = MCBrowserDictionaryRelease;
	t_host.dictionary_set_boolean = MCBrowserDictionarySetBoolean;
	t_host.dictionary_set_integer = MCBrowserDictionarySetInteger;
	t_host.dictionary_set_double = MCBrowserDictionarySetDouble;
	t_host.dictionary_set_utf8_string = MCBrowserDictionarySetUTF8String;
	t_host.dictionary_set_list = MCBrowserDictionarySetList;
	t_host.dictionary_set_dictionary = MCBrowserDictionarySetDictionary;

	t_host.library_load = MCSupportLibraryLoad;
	t_host.library_unload = MCSupportLibraryUnload;
	t_host.library_copy_native_path = MCSupportLibraryCopyNativePath;
	t_host.library_lookup_symbol = MCSupportLibraryLookupSymbol;

	MCBrowserFactoryRef t_factory = nullptr;
	if (!s_create_factory(&t_host, &t_factory) || t_factory == nullptr)
		return false;

	r_factory = t_factory;
	return true;
}
