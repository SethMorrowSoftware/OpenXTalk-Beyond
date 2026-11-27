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

/* The externals of the web engine.
 *
 * A desktop standalone loads an external from a library of its own. A
 * browser loads no libraries, so the web engine links into itself the
 * externals that can run in a browser: revXML, revZip, revDB with its
 * SQLite driver (no other driver: a browser has no sockets) and revSpeech,
 * which speaks with the browser's speech synthesis. Each is built
 * for it with its names renamed (libexternal/src/external-static.h,
 * revdb/src/dbdriver-static.h), and registered here as a library with the
 * symbols that the engine and revDB look up in it. Loading an external by
 * name then works as on the desktop: a standalone loads the externals its
 * capsule names ("./revxml", which the web builder writes for the XML
 * inclusion), and revDB loads "<folder>/dbsqlite" on its first SQLite
 * connection. Each finds the registered library of its name
 * (libfoundation/src/system-library-emscripten.hpp). */

#include <foundation.h>
#include <foundation-system.h>

#include "em-externals.h"
#include "async.h"

/* The symbols, as each one is renamed for its library. The types are those
 * of the definitions in WebAssembly's terms (every pointer is a 32-bit
 * integer), which is what the linker checks: the address of a function
 * declared with other types would be a stub that traps. */
extern "C"
{
	/* libexternal/src/external.c */
#define EM_EXTERNAL_DECLARE(m_prefix) \
	void m_prefix##_getXtable(void *p_operations, void *p_delete, \
	                          const char **r_name, void **r_table, \
	                          void **r_external_delete); \
	void m_prefix##_configureSecurity(void *p_handlers); \
	void m_prefix##_setExternalInterfaceVersion(unsigned int p_version);

	EM_EXTERNAL_DECLARE(revxml)
	EM_EXTERNAL_DECLARE(revzip)
	EM_EXTERNAL_DECLARE(revdb)
	EM_EXTERNAL_DECLARE(revspeech)

	/* revdb/src/dbdriver.h */
	void *dbsqlite_newdbconnectionref(void);
	void dbsqlite_releasedbconnectionref(void *p_connection);
	void dbsqlite_setidcounterref(unsigned int *p_counter);
	void dbsqlite_setcallbacksref(void *p_callbacks);
}

/* What the engine looks up in an external (externalv0.cpp) */
#define EM_EXTERNAL_EXPORTS(m_prefix) \
	{ \
		{ "getXtable", reinterpret_cast<void *>(m_prefix##_getXtable) }, \
		{ "configureSecurity", reinterpret_cast<void *>(m_prefix##_configureSecurity) }, \
		{ "setExternalInterfaceVersion", reinterpret_cast<void *>(m_prefix##_setExternalInterfaceVersion) }, \
		{ nullptr, nullptr }, \
	}

static const MCSLibraryStaticExport kMCEmscriptenRevXMLExports[] =
		EM_EXTERNAL_EXPORTS(revxml);
static const MCSLibraryStaticExport kMCEmscriptenRevZipExports[] =
		EM_EXTERNAL_EXPORTS(revzip);
static const MCSLibraryStaticExport kMCEmscriptenRevDBExports[] =
		EM_EXTERNAL_EXPORTS(revdb);
static const MCSLibraryStaticExport kMCEmscriptenRevSpeechExports[] =
		EM_EXTERNAL_EXPORTS(revspeech);

/* What revDB looks up in a driver (LoadDatabaseDriverFromName) */
static const MCSLibraryStaticExport kMCEmscriptenDBSQLiteExports[] =
{
	{ "newdbconnectionref", reinterpret_cast<void *>(dbsqlite_newdbconnectionref) },
	{ "releasedbconnectionref", reinterpret_cast<void *>(dbsqlite_releasedbconnectionref) },
	{ "setidcounterref", reinterpret_cast<void *>(dbsqlite_setidcounterref) },
	{ "setcallbacksref", reinterpret_cast<void *>(dbsqlite_setcallbacksref) },
	{ nullptr, nullptr },
};

/* The engine's own functions that extensions bind to with "<builtin>",
 * which a desktop engine finds by name in its executable: the xTalk suite's
 * libraries make and read Data with them, the tree view widget decodes
 * text with MCStringDecode, the Background Jobs library starts its jobs
 * with the MCAsyncJobs functions, and an extension with native code has the
 * MCAsyncNative functions (async.cpp). Each address is taken as the
 * function's own type, so that it is the function the definition is (an
 * overload or a template of the same name is not). */
static const MCSLibraryStaticExport kMCEmscriptenEngineExports[] =
{
	{ "MCMemoryAllocate", reinterpret_cast<void *>(static_cast<bool (*)(size_t, void *&)>(MCMemoryAllocate)) },
	{ "MCMemoryDeallocate", reinterpret_cast<void *>(static_cast<void (*)(void *)>(MCMemoryDeallocate)) },
	{ "MCDataGetBytePtr", reinterpret_cast<void *>(MCDataGetBytePtr) },
	{ "MCDataGetLength", reinterpret_cast<void *>(MCDataGetLength) },
	{ "MCDataCreateWithBytes", reinterpret_cast<void *>(MCDataCreateWithBytes) },
	{ "MCStringCreateWithBytes", reinterpret_cast<void *>(MCStringCreateWithBytes) },
	{ "MCStringDecode", reinterpret_cast<void *>(MCStringDecode) },
	{ "MCStringEncode", reinterpret_cast<void *>(MCStringEncode) },
	{ "MCHandlerGetFunctionPtr", reinterpret_cast<void *>(MCHandlerGetFunctionPtr) },
	{ "MCAsyncJobsReadFile", reinterpret_cast<void *>(MCAsyncJobsReadFile) },
	{ "MCAsyncJobsWriteFile", reinterpret_cast<void *>(MCAsyncJobsWriteFile) },
	{ "MCAsyncJobsCopyFile", reinterpret_cast<void *>(MCAsyncJobsCopyFile) },
	{ "MCAsyncJobsListFolder", reinterpret_cast<void *>(MCAsyncJobsListFolder) },
	{ "MCAsyncJobsShell", reinterpret_cast<void *>(MCAsyncJobsShell) },
	{ "MCAsyncJobsProcessOpen", reinterpret_cast<void *>(MCAsyncJobsProcessOpen) },
	{ "MCAsyncJobsProcessWrite", reinterpret_cast<void *>(MCAsyncJobsProcessWrite) },
	{ "MCAsyncJobsProcessCloseInput", reinterpret_cast<void *>(MCAsyncJobsProcessCloseInput) },
	{ "MCAsyncJobsCancel", reinterpret_cast<void *>(MCAsyncJobsCancel) },
	{ "MCAsyncJobsStatus", reinterpret_cast<void *>(MCAsyncJobsStatus) },
	{ "MCAsyncJobsProgress", reinterpret_cast<void *>(MCAsyncJobsProgress) },
	{ "MCAsyncJobsList", reinterpret_cast<void *>(MCAsyncJobsList) },
	{ "MCAsyncJobsEndWithParent", reinterpret_cast<void *>(MCAsyncJobsEndWithParent) },
	{ "MCAsyncNativeCall", reinterpret_cast<void *>(MCAsyncNativeCall) },
	{ "MCAsyncNativeWakeCreate", reinterpret_cast<void *>(MCAsyncNativeWakeCreate) },
	{ "MCAsyncNativeWakeDelete", reinterpret_cast<void *>(MCAsyncNativeWakeDelete) },
	{ "MCAsyncNativeWakeSignal", reinterpret_cast<void *>(MCAsyncNativeWakeSignal) },
	{ "MCAsyncNativeWakeFunction", reinterpret_cast<void *>(MCAsyncNativeWakeFunction) },
	{ "MCAsyncNativeWakeContext", reinterpret_cast<void *>(MCAsyncNativeWakeContext) },
	{ nullptr, nullptr },
};

static MCSLibraryStaticInfo s_mc_emscripten_engine = { nullptr, "<engine>", kMCEmscriptenEngineExports };

/* The names are those of the libraries' files, without the extension */
static MCSLibraryStaticInfo s_mc_emscripten_externals[] =
{
	{ nullptr, "revxml", kMCEmscriptenRevXMLExports },
	{ nullptr, "revzip", kMCEmscriptenRevZipExports },
	{ nullptr, "revdb", kMCEmscriptenRevDBExports },
	{ nullptr, "dbsqlite", kMCEmscriptenDBSQLiteExports },
	{ nullptr, "revspeech", kMCEmscriptenRevSpeechExports },
};

void
MCEmscriptenRegisterExternals(void)
{
	for (MCSLibraryStaticInfo &t_info : s_mc_emscripten_externals)
	{
		MCSLibraryRegisterStatic(t_info);
	}
	MCSLibraryRegisterStaticMain(s_mc_emscripten_engine);
}
