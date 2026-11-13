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

// libbrowser-cef.dll: the CEF browser factory, and libbrowser's shared
// functions forwarded to the engine's (libbrowser_cef_dll.h says why)

#include <core.h>
#include <libbrowser.h>

#include "libbrowser_internal.h"
#include "libbrowser_cef_dll.h"

#include <string.h>

extern bool MCCefBrowserFactoryCreate(MCBrowserFactoryRef &r_factory);

static MCBrowserCefHost s_host;
static bool s_have_host = false;

extern "C" __declspec(dllexport)
bool MCBrowserCefCreateFactory(const MCBrowserCefHost *p_host, MCBrowserFactoryRef *r_factory)
{
	if (p_host == nullptr || r_factory == nullptr)
		return false;
	if (p_host->version != kMCBrowserCefHostVersion || p_host->size != sizeof(MCBrowserCefHost))
		return false;

	// The engine passes the same functions each time
	memcpy(&s_host, p_host, sizeof(MCBrowserCefHost));
	s_have_host = true;

	return MCCefBrowserFactoryCreate(*r_factory);
}

////////////////////////////////////////////////////////////////////////////////
// libbrowser_memory.cpp

bool MCBrowserMemoryAllocate(size_t p_size, void *&r_mem)
{
	return s_host.memory_allocate(p_size, r_mem);
}

bool MCBrowserMemoryReallocate(void *p_mem, size_t p_new_size, void *&r_new_mem)
{
	return s_host.memory_reallocate(p_mem, p_new_size, r_new_mem);
}

void MCBrowserMemoryDeallocate(void *p_mem)
{
	s_host.memory_deallocate(p_mem);
}

void MCBrowserMemoryClear(void *p_mem, size_t p_size)
{
	memset(p_mem, 0, p_size);
}

////////////////////////////////////////////////////////////////////////////////
// libbrowser.cpp

bool MCBrowserAddRunloopAction(MCBrowserRunloopCallback p_callback, void *p_context)
{
	return s_host.add_runloop_action(p_callback, p_context);
}

void MCBrowserRemoveRunloopAction(MCBrowserRunloopCallback p_callback, void *p_context)
{
	// MCCefFinalise may run after a failed start, before any host was kept
	if (s_have_host)
		s_host.remove_runloop_action(p_callback, p_context);
}

bool MCBrowserRunloopWait()
{
	return s_host.runloop_wait();
}

void MCBrowserRunloopBreakWait()
{
	s_host.runloop_break_wait();
}

////////////////////////////////////////////////////////////////////////////////
// libbrowser_value.cpp

bool MCBrowserListCreate(MCBrowserListRef &r_list, uint32_t p_size)
{
	return s_host.list_create(r_list, p_size);
}

MCBrowserListRef MCBrowserListRetain(MCBrowserListRef p_list)
{
	return s_host.list_retain(p_list);
}

void MCBrowserListRelease(MCBrowserListRef p_list)
{
	s_host.list_release(p_list);
}

bool MCBrowserListSetBoolean(MCBrowserListRef p_list, uint32_t p_index, bool p_value)
{
	return s_host.list_set_boolean(p_list, p_index, p_value);
}

bool MCBrowserListSetInteger(MCBrowserListRef p_list, uint32_t p_index, int32_t p_value)
{
	return s_host.list_set_integer(p_list, p_index, p_value);
}

bool MCBrowserListSetDouble(MCBrowserListRef p_list, uint32_t p_index, double p_value)
{
	return s_host.list_set_double(p_list, p_index, p_value);
}

bool MCBrowserListSetUTF8String(MCBrowserListRef p_list, uint32_t p_index, const char *p_value)
{
	return s_host.list_set_utf8_string(p_list, p_index, p_value);
}

bool MCBrowserListSetList(MCBrowserListRef p_list, uint32_t p_index, MCBrowserListRef p_value)
{
	return s_host.list_set_list(p_list, p_index, p_value);
}

bool MCBrowserListSetDictionary(MCBrowserListRef p_list, uint32_t p_index, MCBrowserDictionaryRef p_value)
{
	return s_host.list_set_dictionary(p_list, p_index, p_value);
}

bool MCBrowserDictionaryCreate(MCBrowserDictionaryRef &r_dict, uint32_t p_size)
{
	return s_host.dictionary_create(r_dict, p_size);
}

void MCBrowserDictionaryRelease(MCBrowserDictionaryRef p_dict)
{
	s_host.dictionary_release(p_dict);
}

bool MCBrowserDictionarySetBoolean(MCBrowserDictionaryRef p_dict, const char *p_key, bool p_value)
{
	return s_host.dictionary_set_boolean(p_dict, p_key, p_value);
}

bool MCBrowserDictionarySetInteger(MCBrowserDictionaryRef p_dict, const char *p_key, int32_t p_value)
{
	return s_host.dictionary_set_integer(p_dict, p_key, p_value);
}

bool MCBrowserDictionarySetDouble(MCBrowserDictionaryRef p_dict, const char *p_key, double p_value)
{
	return s_host.dictionary_set_double(p_dict, p_key, p_value);
}

bool MCBrowserDictionarySetUTF8String(MCBrowserDictionaryRef p_dict, const char *p_key, const char *p_value)
{
	return s_host.dictionary_set_utf8_string(p_dict, p_key, p_value);
}

bool MCBrowserDictionarySetList(MCBrowserDictionaryRef p_dict, const char *p_key, MCBrowserListRef p_value)
{
	return s_host.dictionary_set_list(p_dict, p_key, p_value);
}

bool MCBrowserDictionarySetDictionary(MCBrowserDictionaryRef p_dict, const char *p_key, MCBrowserDictionaryRef p_value)
{
	return s_host.dictionary_set_dictionary(p_dict, p_key, p_value);
}

////////////////////////////////////////////////////////////////////////////////
// engine/src/util.cpp: libbrowser_cef.cpp and the weak stubs of libcef
// (libcefstubs.cpp) name these

extern "C" void *MCSupportLibraryLoad(const char *p_path)
{
	return s_have_host ? s_host.library_load(p_path) : nullptr;
}

// engine/src/util.h's signature (libbrowser_cef.cpp declares it returning
// void *, which it never reads)
extern "C" void MCSupportLibraryUnload(void *p_handle)
{
	if (s_have_host)
		s_host.library_unload(p_handle);
}

extern "C" void *MCSupportLibraryLookupSymbol(void *p_handle, const char *p_symbol)
{
	return s_have_host ? s_host.library_lookup_symbol(p_handle, p_symbol) : nullptr;
}

extern "C" char *MCSupportLibraryCopyNativePath(void *p_handle)
{
	return s_have_host ? s_host.library_copy_native_path(p_handle) : nullptr;
}
