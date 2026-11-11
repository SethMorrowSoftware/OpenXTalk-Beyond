/*
 * OXT-Beyond: pg_strong_random() from the system, not from OpenSSL.
 *
 * PostgreSQL takes its strong random numbers from OpenSSL when it is built
 * with OpenSSL. The engine reaches OpenSSL through stubs that work only
 * once it has loaded its SSL library, and libpq needs random numbers for a
 * login (the SCRAM nonce) whether or not the connection uses TLS. This
 * builds pg_strong_random.c as PostgreSQL builds it without OpenSSL:
 * /dev/urandom on Linux and macOS, the Windows cryptographic provider on
 * Windows. thirdparty/libpq/libpq.gyp compiles this file in place of
 * pg_strong_random.c.
 */
#include "c.h"

#undef USE_OPENSSL

#include "pg_strong_random.c"
