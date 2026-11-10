/*
 * OXT-Beyond: ma_config.h for every platform the engine is built for.
 *
 * MariaDB Connector/C makes this file with CMake from ma_config.h.in. The
 * engine builds the library with gyp, so this one header stands in for
 * CMake's checks: the Linux values are those CMake found for the library in
 * the Ubuntu 20.04 build image, the Windows values those of the library's
 * own cmake/WindowsCache.cmake, and macOS and Android those of their C
 * libraries (Android from API 21, the engine's oldest).
 */

#ifndef OXT_MA_CONFIG_H
#define OXT_MA_CONFIG_H

/* Sizes, from the compiler rather than from a check */
#if defined(_WIN64) || defined(__LP64__) || defined(_LP64)
#  define SIZEOF_CHARP 8
#else
#  define SIZEOF_CHARP 4
#endif
#define SIZEOF_INT 4
#if defined(_WIN32)
#  define SIZEOF_LONG 4
#else
#  define SIZEOF_LONG SIZEOF_CHARP
#endif
#define SIZEOF_LONG_LONG 8
#define SIZEOF_SIZE_T SIZEOF_CHARP

#define HAVE_CHARP 1
#define HAVE_INT 1
#define HAVE_LONG 1
#define HAVE_LONG_LONG 1
#define HAVE_SIZE_T 1

#if !defined(_WIN32)
/* glibc, Darwin and bionic define uint and ushort, and glibc and bionic
   ulong; Darwin has no ulong (sys/types.h has u_long), so ma_global.h
   makes it there */
#  define SIZEOF_UINT 4
#  define HAVE_UINT 1
#  define SIZEOF_USHORT 2
#  define HAVE_USHORT 1
#  if !defined(__APPLE__)
#    define SIZEOF_ULONG SIZEOF_LONG
#    define HAVE_ULONG 1
#  endif
#endif

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#  define HAVE_BIGENDIAN 1
#endif

/* Headers */
#define HAVE_FCNTL_H 1
#define HAVE_FLOAT_H 1
#define HAVE_LIMITS_H 1
#define HAVE_STDDEF_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1

#if defined(_WIN32)
#  define SOCKET_SIZE_TYPE int
#  define HAVE_SETLOCALE 1
#else
#  define SOCKET_SIZE_TYPE socklen_t
#  define HAVE_STDINT_H 1
#  define HAVE_ALLOCA_H 1
#  define HAVE_DLFCN_H 1
#  define HAVE_PWD_H 1
#  define HAVE_SYS_IOCTL_H 1
#  define HAVE_SYS_SELECT_H 1
#  define HAVE_SYS_SOCKET_H 1
#  define HAVE_SYS_UN_H 1
#  define HAVE_UNISTD_H 1
#  define HAVE_DLERROR 1
#  define HAVE_DLOPEN 1
#  define HAVE_GETPWUID 1
#  define HAVE_MEMCPY 1
#  define HAVE_POLL 1
#  if defined(__linux__) && !defined(__ANDROID__)
#    define HAVE_LINUX_LIMITS_H 1
#    define HAVE_UCONTEXT_H 1
#    define HAVE_CUSERID 1
#  endif
/* nl_langinfo is in bionic from API 26 only; it serves the "auto"
   character set, which the drivers never ask for */
#  if !defined(__ANDROID__)
#    define HAVE_SETLOCALE 1
#    define HAVE_NL_LANGINFO 1
#  endif
#endif

#define LOCAL_INFILE_MODE_OFF  0
#define LOCAL_INFILE_MODE_ON   1
#define LOCAL_INFILE_MODE_AUTO 2
#define ENABLED_LOCAL_INFILE LOCAL_INFILE_MODE_AUTO

/*
 * OXT-Beyond: the character set a connection asks for when the caller
 * names none. The library's own default is utf8mb4; MySQL Connector/C 6.0,
 * which the MySQL driver used until OXT-Beyond 0.2.8, used latin1, and a
 * server converts every text it sends to the connection's character set,
 * so latin1 keeps what scripts get back the same.
 */
#define MARIADB_DEFAULT_CHARSET "latin1"

/*
 * OXT-Beyond: DEFAULT_SSL_VERIFY_SERVER_CERT is left undefined. Defined
 * (CMake's default since Connector/C 3.4), every connection uses TLS and
 * checks the server's certificate unless told otherwise, and a server
 * without TLS or with a self-signed certificate is refused. The MySQL
 * driver has always used TLS only when a script asks for it, without
 * checking the certificate (as Connector/C 6.0 did).
 */

/* The platform the library reports to a server in its connection
   attributes (CMake passes them on the command line) */
#ifndef MARIADB_SYSTEM_TYPE
#  if defined(_WIN32)
#    define MARIADB_SYSTEM_TYPE "Windows"
#  elif defined(__APPLE__)
#    define MARIADB_SYSTEM_TYPE "Darwin"
#  elif defined(__ANDROID__)
#    define MARIADB_SYSTEM_TYPE "Android"
#  else
#    define MARIADB_SYSTEM_TYPE "Linux"
#  endif
#endif
#ifndef MARIADB_MACHINE_TYPE
#  if defined(__x86_64__) || defined(_M_X64)
#    define MARIADB_MACHINE_TYPE "x86_64"
#  elif defined(__i386__) || defined(_M_IX86)
#    define MARIADB_MACHINE_TYPE "x86"
#  elif defined(__aarch64__) || defined(_M_ARM64)
#    define MARIADB_MACHINE_TYPE "aarch64"
#  elif defined(__arm__)
#    define MARIADB_MACHINE_TYPE "arm"
#  else
#    define MARIADB_MACHINE_TYPE "unknown"
#  endif
#endif

#endif /* OXT_MA_CONFIG_H */
