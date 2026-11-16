/*                                                                     -*-c++-*-

Copyright (C) 2003-2015 LiveCode Ltd.

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

#ifndef __MC_EMSCRIPTEN_ASYNC_H__
#define __MC_EMSCRIPTEN_ASYNC_H__

#include <foundation.h>

#if defined(__cplusplus)
extern "C" {
#endif

/* Yield to browser and wait for an event.
 *
 * If an event does not occur within the specified p_timeout_s,
 * returns zero.  Otherwise, returns non-zero.
 *
 * If p_timeout_s is negative or infinite, MCEmscriptenAsyncYield()
 * will always wait for an event to occur.  p_timeout_s is a duration
 * in seconds.
 *
 * Defined in em-async.js
 */
int MCEmscriptenAsyncYield(real64_t p_timeout_s = -1);

/* Test whether the engine can yield to the browser now.
 *
 * Returns zero while JavaScript has called into the engine: from a
 * resume hook (the engine's stack is saved) or from JavaScript that the
 * engine itself called (a JavaScript frame cannot be saved).
 *
 * Defined in em-async.js
 */
bool MCEmscriptenAsyncCanYield(void);

/* Continue running the engine's main loop on receipt of an event.
 *
 * Returns when the engine next yields.
 */
void MCEmscriptenAsyncResume(void);

#if defined(__cplusplus)
}
#endif

#endif /* !__MC_EMSCRIPTEN_ASYNC_H__ */
