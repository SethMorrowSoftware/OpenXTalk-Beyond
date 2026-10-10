/*
 * config.h for the libxslt that OXT-Beyond builds with gyp, on every
 * platform but Windows (which uses win32config.h, from libxslt).
 *
 * libxslt's own builds generate this file from config.h.cmake.in; gyp runs
 * no configure step, so this hand-written copy answers the same questions.
 */

#ifndef OXT_LIBXSLT_CONFIG_H
#define OXT_LIBXSLT_CONFIG_H

/* As libxslt's configure does: locale_t and strxfrm_l are GNU extensions
   in glibc's headers. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#define HAVE_GETTIMEOFDAY 1
#define HAVE_GMTIME_R 1
#define HAVE_INTTYPES_H 1
#define HAVE_LOCALE_H 1
#define HAVE_LOCALTIME_R 1
#define HAVE_SNPRINTF 1
#define HAVE_STAT 1
#define HAVE_SYS_SELECT_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_VSNPRINTF 1

/* Language-aware sorting (xsl:sort lang="...") with strxfrm_l(): glibc
   and macOS have it, macOS in <xlocale.h>. Elsewhere (Android,
   Emscripten) xsl:sort compares the strings as they are. */
#if defined(__APPLE__)
#define HAVE_STRXFRM_L 1
#define HAVE_XLOCALE_H 1
#elif defined(__linux__) && !defined(__ANDROID__) && !defined(TARGET_SUBPLATFORM_ANDROID)
#define HAVE_STRXFRM_L 1
#endif

/* Plugin file extension; unused, since LIBXSLT_DEFAULT_PLUGINS_PATH and
   module loading are off (WITH_MODULES is 0 in xsltconfig.h). */
#if defined(__APPLE__)
#define MODULE_EXTENSION ".dylib"
#else
#define MODULE_EXTENSION ".so"
#endif

#define PACKAGE "libxslt"
#define VERSION "1.1.45"

#define WITH_DEBUGGER 1
#define WITH_PROFILER 1

#endif
