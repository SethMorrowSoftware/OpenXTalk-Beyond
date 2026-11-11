/*
 * OXT-Beyond: pg_config.h for libpq on every platform the engine builds it
 * for (the desktop ones: Windows, Linux and macOS).
 *
 * PostgreSQL makes this file with Meson or configure. The engine builds
 * libpq with gyp, so this one header stands in for those checks:
 *
 * - Linux: what Meson 1.5 found for PostgreSQL 17.11 in the Ubuntu 20.04
 *   build image (glibc 2.31), with -Dssl=openssl and every other optional
 *   library off, less what only the server uses.
 * - macOS: the same, with what Darwin's C library has and lacks from macOS
 *   10.15 (the engine's oldest).
 * - Windows: what PostgreSQL's meson.build sets for Visual C++, with LDAP
 *   (wldap32), as the libpq 9.4 build before it had.
 *
 * Sizes and alignments come from the compiler, so that one header serves
 * the 32-bit and 64-bit builds and both halves of a universal Mac build.
 *
 * OXT-Beyond's other change from PostgreSQL's configuration: the hashes
 * (MD5, SHA-1, SHA-2, HMAC) are PostgreSQL's own implementations, not
 * OpenSSL's, and strong random numbers come from the system
 * (src/port/oxt_strong_random.c), so that only TLS needs OpenSSL. The engine
 * reaches OpenSSL through stubs that work only once it has loaded its SSL
 * library (revsecurity), and the PostgreSQL driver connects without TLS
 * when it cannot (sslmode=disable), as it did with libpq 9.4.
 */

#ifndef OXT_PG_CONFIG_H
#define OXT_PG_CONFIG_H

/* Version */
#define PACKAGE_BUGREPORT "pgsql-bugs@lists.postgresql.org"
#define PACKAGE_NAME "PostgreSQL"
#define PACKAGE_STRING "PostgreSQL 17.11"
#define PACKAGE_TARNAME "postgresql"
#define PACKAGE_URL "https://www.postgresql.org/"
#define PACKAGE_VERSION "17.11"
#define PG_MAJORVERSION "17"
#define PG_MAJORVERSION_NUM 17
#define PG_MINORVERSION_NUM 11
#define PG_VERSION "17.11"
#define PG_VERSION_NUM 170011
#define PG_VERSION_STR "PostgreSQL 17.11 (libpq of OXT-Beyond)"
#define CONFIGURE_ARGS ""

/* Settings that do not depend on the platform */
#define BLCKSZ 8192
#define XLOG_BLCKSZ 8192
#define RELSEG_SIZE 131072
#define DEF_PGPORT 5432
#define DEF_PGPORT_STR "5432"
#define MEMSET_LOOP_LIMIT 1024
#define PG_KRB_SRVNAM "postgres"
#define PG_USE_STDBOOL 1
#define USE_OPENSSL 1
#define HAVE_ASN1_STRING_GET0_DATA 1
#define HAVE_BIO_METH_NEW 1
#define HAVE_HMAC_CTX_FREE 1
#define HAVE_HMAC_CTX_NEW 1
#define HAVE_OPENSSL_INIT_SSL 1
#define HAVE_SSL_CTX_SET_CERT_CB 1
#define HAVE_SSL_CTX_SET_NUM_TICKETS 1
#define HAVE_X509_GET_SIGNATURE_INFO 1
#define HAVE_INET_PTON 1
/* OPENSSL_API_COMPAT is set by thirdparty/libpq/libpq.gyp
   (openssl_api_compat), as for the engine's other users of OpenSSL */

/* Sizes and alignments */
#if defined(_WIN64) || defined(__LP64__) || defined(_LP64)
#  define SIZEOF_VOID_P 8
#  define SIZEOF_SIZE_T 8
#else
#  define SIZEOF_VOID_P 4
#  define SIZEOF_SIZE_T 4
#endif
#define SIZEOF_BOOL 1
#if defined(_WIN32)
#  define SIZEOF_OFF_T 4
#else
   /* libpq.gyp builds with _FILE_OFFSET_BITS=64, as Meson does */
#  define SIZEOF_OFF_T 8
#endif
#define ALIGNOF_SHORT 2
#define ALIGNOF_INT 4

#if defined(_WIN32)
   /* LLP64: long is 32 bits, a 64-bit integer is long long */
#  define SIZEOF_LONG 4
#  define HAVE_LONG_LONG_INT_64 1
#  define PG_INT64_TYPE long long int
#  define INT64_MODIFIER "ll"
#  define ALIGNOF_LONG 4
#  define ALIGNOF_LONG_LONG_INT 8
#  define ALIGNOF_DOUBLE 8
#  define MAXIMUM_ALIGNOF 8
#elif SIZEOF_VOID_P == 8
   /* LP64 */
#  define SIZEOF_LONG 8
#  define HAVE_LONG_INT_64 1
#  define PG_INT64_TYPE long int
#  define INT64_MODIFIER "l"
#  define ALIGNOF_LONG 8
#  define ALIGNOF_DOUBLE 8
#  define MAXIMUM_ALIGNOF 8
#else
   /* ILP32 */
#  define SIZEOF_LONG 4
#  define HAVE_LONG_LONG_INT_64 1
#  define PG_INT64_TYPE long long int
#  define INT64_MODIFIER "ll"
#  define ALIGNOF_LONG 4
#  if defined(__i386__)
     /* the i386 System V ABI aligns 8-byte types to 4 in a structure */
#    define ALIGNOF_LONG_LONG_INT 4
#    define ALIGNOF_DOUBLE 4
#    define MAXIMUM_ALIGNOF 4
#  else
#    define ALIGNOF_LONG_LONG_INT 8
#    define ALIGNOF_DOUBLE 8
#    define MAXIMUM_ALIGNOF 8
#  endif
#endif

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#  define WORDS_BIGENDIAN 1
#endif

/* The compiler */
#if defined(_MSC_VER)
#  define pg_restrict __restrict
#  define HAVE__CONFIGTHREADLOCALE 1
#  define HAVE__CPUID 1
#  define HAVE__CPUIDEX 1
#  define HAVE_CRTDEFS_H 1
#else
#  define pg_restrict __restrict
#  define HAVE_COMPUTED_GOTO 1
#  define HAVE_TYPEOF 1
#  define HAVE_VISIBILITY_ATTRIBUTE 1
#  define HAVE__BUILTIN_BSWAP16 1
#  define HAVE__BUILTIN_BSWAP32 1
#  define HAVE__BUILTIN_BSWAP64 1
#  define HAVE__BUILTIN_CLZ 1
#  define HAVE__BUILTIN_CONSTANT_P 1
#  define HAVE__BUILTIN_CTZ 1
#  define HAVE__BUILTIN_FRAME_ADDRESS 1
#  define HAVE__BUILTIN_OP_OVERFLOW 1
#  define HAVE__BUILTIN_POPCOUNT 1
#  define HAVE__BUILTIN_TYPES_COMPATIBLE_P 1
#  define HAVE__BUILTIN_UNREACHABLE 1
#  define HAVE__STATIC_ASSERT 1
#  define HAVE_ATOMICS 1
#  define HAVE_SPINLOCKS 1
#  define HAVE_GCC__ATOMIC_INT32_CAS 1
#  define HAVE_GCC__ATOMIC_INT64_CAS 1
#  define HAVE_GCC__SYNC_CHAR_TAS 1
#  define HAVE_GCC__SYNC_INT32_CAS 1
#  define HAVE_GCC__SYNC_INT32_TAS 1
#  define HAVE_GCC__SYNC_INT64_CAS 1
#  if defined(__clang__)
#    define PG_C_PRINTF_ATTRIBUTE printf
#  else
#    define PG_C_PRINTF_ATTRIBUTE gnu_printf
#  endif
#endif

/* The C library */
#if defined(_WIN32)

#define DLSUFFIX ".dll"
#define HAVE_ATOMICS 1
#define HAVE_SPINLOCKS 1
#define HAVE_DECL_FDATASYNC 0
#define HAVE_DECL_F_FULLFSYNC 0
#define HAVE_DECL_MEMSET_S 0
#define HAVE_DECL_POSIX_FADVISE 0
#define HAVE_DECL_PREADV 0
#define HAVE_DECL_PWRITEV 0
#define HAVE_DECL_STRCHRNUL 0
#define HAVE_DECL_STRLCAT 0
#define HAVE_DECL_STRLCPY 0
#define HAVE_DECL_STRNLEN 1
#define HAVE_DECL_TIMINGSAFE_BCMP 0
#define HAVE_STRNLEN 1
#define USE_LDAP 1
#define HAVE_LIBWLDAP32 1
#define USE_WIN32_SEMAPHORES 1
#define USE_WIN32_SHARED_MEMORY 1

#elif defined(__APPLE__)

#define DLSUFFIX ".dylib"
#define HAVE_BACKTRACE_SYMBOLS 1
#define HAVE_COPYFILE 1
#define HAVE_COPYFILE_H 1
#define HAVE_DECL_FDATASYNC 0
#define HAVE_DECL_F_FULLFSYNC 1
#define HAVE_DECL_MEMSET_S 1
#define HAVE_DECL_POSIX_FADVISE 0
#define HAVE_DECL_PREADV 0
#define HAVE_DECL_PWRITEV 0
/* strchrnul and timingsafe_bcmp are in newer macOS only: PostgreSQL's own
   (src/port/snprintf.c, src/port/timingsafe_bcmp.c) serve every one */
#define HAVE_DECL_STRCHRNUL 0
#define HAVE_DECL_STRLCAT 1
#define HAVE_DECL_STRLCPY 1
#define HAVE_DECL_STRNLEN 1
#define HAVE_DECL_TIMINGSAFE_BCMP 0
#define HAVE_EXECINFO_H 1
#define HAVE_GETIFADDRS 1
#define HAVE_GETOPT 1
#define HAVE_GETOPT_H 1
#define HAVE_GETOPT_LONG 1
#define HAVE_GETPEEREID 1
#define HAVE_IFADDRS_H 1
#define HAVE_INET_ATON 1
#define HAVE_INT_OPTERR 1
#define HAVE_INT_OPTRESET 1
#define HAVE_INT_TIMEZONE 1
#define HAVE_KQUEUE 1
#define HAVE_LANGINFO_H 1
#define HAVE_MBSTOWCS_L 1
#define HAVE_MKDTEMP 1
#define HAVE_PTHREAD_IS_THREADED_NP 1
#define HAVE_SOCKLEN_T 1
#define HAVE_STRERROR_R 1
#define STRERROR_R_INT 1
#define HAVE_STRINGS_H 1
#define HAVE_STRLCAT 1
#define HAVE_STRLCPY 1
#define HAVE_STRNLEN 1
#define HAVE_STRSIGNAL 1
#define HAVE_STRUCT_OPTION 1
#define HAVE_STRUCT_SOCKADDR_SA_LEN 1
#define HAVE_STRUCT_TM_TM_ZONE 1
#define HAVE_SYSLOG 1
#define HAVE_SYS_EVENT_H 1
#define HAVE_SYS_UCRED_H 1
#define HAVE_TERMIOS_H 1
#define HAVE_USELOCALE 1
#define HAVE_WCSTOMBS_L 1
#define LOCALE_T_IN_XLOCALE 1
#define WCSTOMBS_L_IN_XLOCALE 1
#define USE_SYSV_SEMAPHORES 1
#define USE_SYSV_SHARED_MEMORY 1

#else /* Linux (glibc 2.31 and later) */

#define DLSUFFIX ".so"
#define HAVE_BACKTRACE_SYMBOLS 1
#define HAVE_COPY_FILE_RANGE 1
#define HAVE_DECL_FDATASYNC 1
#define HAVE_DECL_F_FULLFSYNC 0
#define HAVE_DECL_MEMSET_S 0
#define HAVE_DECL_POSIX_FADVISE 1
#define HAVE_DECL_PREADV 1
#define HAVE_DECL_PWRITEV 1
#define HAVE_DECL_STRCHRNUL 1
/* strlcat and strlcpy came in glibc 2.38: PostgreSQL's own serve here */
#define HAVE_DECL_STRLCAT 0
#define HAVE_DECL_STRLCPY 0
#define HAVE_DECL_STRNLEN 1
#define HAVE_DECL_TIMINGSAFE_BCMP 0
#define HAVE_EXECINFO_H 1
#define HAVE_EXPLICIT_BZERO 1
#define HAVE_GETIFADDRS 1
#define HAVE_GETOPT 1
#define HAVE_GETOPT_H 1
#define HAVE_GETOPT_LONG 1
#define HAVE_IFADDRS_H 1
#define HAVE_INET_ATON 1
#define HAVE_INT_OPTERR 1
#define HAVE_INT_TIMEZONE 1
#define HAVE_LANGINFO_H 1
#define HAVE_MKDTEMP 1
#define HAVE_POSIX_FADVISE 1
#define HAVE_POSIX_FALLOCATE 1
#define HAVE_PPOLL 1
#define HAVE_PTHREAD_BARRIER_WAIT 1
#define HAVE_SOCKLEN_T 1
#define HAVE_STRERROR_R 1
#define HAVE_STRINGS_H 1
#define HAVE_STRNLEN 1
#define HAVE_STRSIGNAL 1
#define HAVE_STRUCT_OPTION 1
#define HAVE_STRUCT_TM_TM_ZONE 1
#define HAVE_SYNCFS 1
#define HAVE_SYNC_FILE_RANGE 1
#define HAVE_SYSLOG 1
#define HAVE_SYS_EPOLL_H 1
#define HAVE_SYS_PERSONALITY_H 1
#define HAVE_SYS_PRCTL_H 1
#define HAVE_SYS_SIGNALFD_H 1
#define HAVE_TERMIOS_H 1
#define HAVE_USELOCALE 1
#define USE_SYSV_SHARED_MEMORY 1
#define USE_UNNAMED_POSIX_SEMAPHORES 1

#endif

#endif /* OXT_PG_CONFIG_H */
