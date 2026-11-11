/*
 * OXT-Beyond: pg_config_ext.h, which PostgreSQL makes from
 * pg_config_ext.h.in, for every platform: the name of a signed 64-bit
 * integer type (the same as in src/include/pg_config.h).
 */
#if defined(_WIN32)
#define PG_INT64_TYPE long long int
#elif defined(__LP64__) || defined(_LP64)
#define PG_INT64_TYPE long int
#else
#define PG_INT64_TYPE long long int
#endif
