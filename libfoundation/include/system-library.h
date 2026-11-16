/*
Copyright (C) 2017 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

/* Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
   (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
   Seth Morrow (2026); its Git history and CHANGELOG.md say what changed. */

#if !defined(__MCS_SYSTEM_H_INSIDE__)
#	error "Only <foundation-system.h> can be included directly"
#endif

/* ================================================================
 * Loadable library handling
 * ================================================================ */

/* The MCSLibrary library provides an API for handling loadable libraries in a
 * standardized fashion. */

/* ================================================================
 * Types
 * ================================================================ */

/* An opaque custom value ref type representing a loaded library. */
typedef struct __MCSLibrary *MCSLibraryRef;

/* The binding to the internal MCTypeInfoRef for the MCSLibraryRef type */
MC_DLLEXPORT MCTypeInfoRef
MCSLibraryTypeInfo(void) ATTRIBUTE_PURE;

/* ================================================================
 * Construction and querying
 * ================================================================ */

/* Create an MCSLibraryRef object by loading the library from the specified
 * path.
 *
 * If the path is absolute, then only an attempt to load that specific library
 * will be made. If the path is relative, however, an attempt to load the
 * library will use the system's default search order.
 *
 * On Mac, bundles, frameworks and dylibs are supported. In order to load a
 * bundle, an absolute path must be supplied. Otherwise, if the path ends in
 * <LEAF>.framework then the path will be modified to end in
 * <LEAF>.framework/<LEAF>. In the dylib and framework case, dlopen's default
 * search strategy is used.
 *
 * On Windows, dlls are supported. They are loaded using LoadLibraryEx with
 * the LOAD_WITH_ALTERED_SEARCH_PATH flag set.
 *
 * On Linux, shared objects (.so) are supported. They are loaded using dlopen's
 * search strategy.
 *
 * On Android, shared objects (.so) are supported. They are loaded using
 * dlopen's search strategy which requires that non-system libraries be loaded
 * using absolute paths (otherwise they can fail to load).
 *
 * On iOS, only statically linked and registered objects are supported. The
 * name is matched exactly with the name specified in the static registration
 * record. */
MC_DLLEXPORT bool
MCSLibraryCreateWithPath(MCStringRef p_path,
                         MCSLibraryRef& r_library);

/* Create an MCSLibraryRef object by referencing the library currently loaded
 * at the specified address. */
MC_DLLEXPORT bool
MCSLibraryCreateWithAddress(void *p_address,
                            MCSLibraryRef& r_library);

/* Copy the full native path to the specified library. If the library is of
 * static type, this returns the path of the loadable object which the library
 * is linked into. */
MC_DLLEXPORT bool
MCSLibraryCopyNativePath(MCSLibraryRef p_library,
                         MCStringRef& r_path);

/* Copy the full (non-native) path to the specified library. If the library is of
 * static type, this returns the path of the loadable object which the library
 * is linked into. */
MC_DLLEXPORT bool
MCSLibraryCopyPath(MCSLibraryRef p_library,
                   MCStringRef& r_path);

/* Lookup the symbol in the specified library. */
MC_DLLEXPORT void *
MCSLibraryLookupSymbol(MCSLibraryRef p_library,
                       MCStringRef p_symbol);

#if defined(__ANDROID__)
/* Sets the path to use as the base path for the paths of libraries.
 * This must be called after MCSInitialize, with the value of the
 * Android application's context's nativeLibPath member. */
MC_DLLEXPORT void
MCSLibraryAndroidSetNativeLibPath(MCStringRef p_path);
#endif

#ifdef __MCS_INTERNAL_API__

bool
__MCSLibraryThrowCreateWithNativePathFailed(MCStringRef p_native_path,
                                            MCStringRef p_reason);
bool
__MCSLibraryThrowCreateWithAddressFailed(void *p_address);
bool
__MCSLibraryThrowResolvePathFailed(void);

#endif

/* ================================================================
 * Static binding (iOS only)
 * ================================================================ */


/* ================================================================
 * Static binding (web)
 * ================================================================ */

/* OXT-Beyond: a browser loads no libraries, so the web engine links into
 * itself the libraries it would load by name (the externals it runs) and
 * registers each one, with the symbols that are looked up in it, before it
 * starts (engine/src/em-externals.cpp). As on iOS, a registered library is
 * found by the name of its file without the folder and the extension:
 * "<folder>/revxml.so" finds the library registered as "revxml". */

#ifdef __EMSCRIPTEN__

struct MCSLibraryStaticExport
{
    const char *symbol;
    void *address;
};

struct MCSLibraryStaticInfo
{
    /* The next registered library (set by MCSLibraryRegisterStatic) */
    MCSLibraryStaticInfo *__next;
    const char *name;
    /* The symbols, ended by an entry whose symbol is nullptr */
    const MCSLibraryStaticExport *exports;
};

/* Register the given statically linked library and its symbols. The record
 * passed as p_info must exist until the foundation library is shut down. */
MC_DLLEXPORT void
MCSLibraryRegisterStatic(MCSLibraryStaticInfo& p_info);

/* Register symbols of the engine itself: those that LCB code binds to with
 * "<builtin>" or with no library ("c:>name"), which a desktop engine finds
 * in its own executable and a browser's cannot look up by name. The library
 * that a handle made with an address stands for (the engine) has them. The
 * record's name is not used. */
MC_DLLEXPORT void
MCSLibraryRegisterStaticMain(MCSLibraryStaticInfo& p_info);

#endif

/* ================================================================
 * Library API initialization
 * ================================================================ */

#ifdef __MCS_INTERNAL_API__
bool
__MCSLibraryInitialize(void);
void
__MCSLibraryFinalize(void);
#endif

/* ================================================================
 * C++ API
 * ================================================================ */

#ifdef __cplusplus

typedef MCAutoValueRefBase<MCSLibraryRef> MCSAutoLibraryRef;

#endif
