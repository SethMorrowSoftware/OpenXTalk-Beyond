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

/* Background jobs, the engine's side (async.cpp): what the Background Jobs
 * library (extensions/libraries/async) binds to by name, and what the
 * engine itself calls. The work is in async-core.cpp. */

#ifndef __MC_ASYNC__
#define __MC_ASYNC__

#include <foundation.h>

/* Stop every job, as the engine quits: the processes still running are
 * killed and the threads are given a moment to end. Before the
 * notifications are finalized, because a job's thread posts one. Does
 * nothing if no job was ever started. */
void MCAsyncFinalize(void);

/* At the engine's start: a Background Workers worker ends with the process
 * that started it (async.cpp) */
void MCAsyncEndWithParentIfWorker(void);

/* What the jobs have ended with becomes pending messages, due at p_time.
 * MCUIDC::handlepending calls this at the top of each pass of a wait, so
 * that a job's message is handled there as one sent "in 0 seconds" would
 * be. Main thread only. Costs one read of a flag when no job has ended. */
void MCAsyncPostPending(double p_time);

/* The library's foreign handlers. Each one that starts a job returns its
 * number, or 0 with an error thrown. Declared here for the web engine,
 * which lists the functions that extensions bind to (em-externals.cpp). */
extern "C"
{

MC_DLLEXPORT uint32_t MCAsyncJobsReadFile(MCStringRef p_path, MCStringRef p_message);
MC_DLLEXPORT uint32_t MCAsyncJobsWriteFile(MCStringRef p_path, MCDataRef p_data, bool p_append, MCStringRef p_message);
MC_DLLEXPORT uint32_t MCAsyncJobsCopyFile(MCStringRef p_from, MCStringRef p_to, MCStringRef p_message);
MC_DLLEXPORT uint32_t MCAsyncJobsListFolder(MCStringRef p_path, bool p_recursive, MCStringRef p_message);
MC_DLLEXPORT uint32_t MCAsyncJobsShell(MCStringRef p_command, MCStringRef p_message);
MC_DLLEXPORT uint32_t MCAsyncJobsProcessOpen(MCStringRef p_program, MCValueRef p_arguments, MCStringRef p_message);
MC_DLLEXPORT bool MCAsyncJobsProcessWrite(MCValueRef p_job, MCDataRef p_data);
MC_DLLEXPORT bool MCAsyncJobsProcessCloseInput(MCValueRef p_job);
MC_DLLEXPORT bool MCAsyncJobsCancel(MCValueRef p_job);
MC_DLLEXPORT void MCAsyncJobsStatus(MCValueRef p_job, MCStringRef& r_status);
MC_DLLEXPORT void MCAsyncJobsProgress(MCValueRef p_job, MCStringRef& r_progress);
MC_DLLEXPORT void MCAsyncJobsList(MCStringRef& r_jobs);
MC_DLLEXPORT bool MCAsyncJobsEndWithParent(MCValueRef p_parent);

/* For an extension with native code (see async.cpp, and "Native code that
 * takes time, or has threads of its own" in
 * ide/Documentation/guides/Extending OXT.md). Main thread only, bar
 * MCAsyncNativeWakeSignal, which is for any thread at any time. */
MC_DLLEXPORT uint32_t MCAsyncNativeCall(void *p_function, void *p_context, MCStringRef p_message);
MC_DLLEXPORT uint32_t MCAsyncNativeWakeCreate(MCStringRef p_message);
MC_DLLEXPORT bool MCAsyncNativeWakeDelete(uint32_t p_wake);
MC_DLLEXPORT void MCAsyncNativeWakeSignal(void *p_wake_context);
MC_DLLEXPORT void *MCAsyncNativeWakeFunction(void);
MC_DLLEXPORT void *MCAsyncNativeWakeContext(uint32_t p_wake);

}

#endif
