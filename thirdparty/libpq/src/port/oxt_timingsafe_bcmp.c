/*
 * OXT-Beyond: timingsafe_bcmp() without OpenSSL.
 *
 * Built with OpenSSL, PostgreSQL's timingsafe_bcmp() calls CRYPTO_memcmp().
 * libpq compares the server's SCRAM signature with it whether or not the
 * connection uses TLS, and the engine's OpenSSL stubs work only once it
 * has loaded its SSL library. This builds timingsafe_bcmp.c as PostgreSQL
 * builds it without OpenSSL: a loop that takes the same time whatever the
 * bytes. thirdparty/libpq/libpq.gyp compiles this file in place of
 * timingsafe_bcmp.c (as src/port/oxt_strong_random.c stands in for
 * pg_strong_random.c).
 */
#include "c.h"

#undef USE_SSL

#include "timingsafe_bcmp.c"
