/*
 * OXT-Beyond: pg_config_os.h, which PostgreSQL's build makes a copy of the
 * platform's header in src/include/port.
 */
#if defined(_WIN32)
#include "port/win32.h"
#elif defined(__APPLE__)
#include "port/darwin.h"
#else
#include "port/linux.h"
#endif
