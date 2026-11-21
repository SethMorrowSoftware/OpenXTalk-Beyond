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

/* Background jobs: work that the engine's one thread hands to other threads
 * and hears of when it is done, so that a script that starts it is not held
 * up and the user interface is not frozen while it runs.
 *
 * This is the part that knows nothing of the engine: no value, name, object
 * or global of the engine is used here, because none of them may be touched
 * from a second thread (their reference counts are not atomic). It reads
 * and writes files, lists folders and runs processes with the system's own
 * calls, on its own threads, and queues what happened. The engine's side
 * (async.cpp) starts jobs and drains that queue on the main thread, where it
 * turns each event into a message for a script.
 *
 * It is built on its own too, with the sanitizers, by
 * tools/ci/async_core_check.py: keep it free of the engine's headers.
 *
 * Threads: every function here is for the main thread (the one that called
 * MCAsyncCoreInitialize), bar one: MCAsyncCoreWakeSignal is for any thread,
 * at any time. The wake callback is the only thing called on another
 * thread, and a native function given to MCAsyncCoreCall is run on one.
 *
 * Strings: paths and command lines are bytes as the system's calls take
 * them, but on Windows, where they are UTF-8 and are converted here. */

#ifndef __MC_ASYNC_CORE__
#define __MC_ASYNC_CORE__

#include <stddef.h>
#include <stdint.h>

/* A job's number. 0 is never a job. Numbers are not reused in a session
 * (they wrap after four thousand million jobs, and skip 0 and any still in
 * use), so a number kept after its job ended names no job: every call takes
 * it and does nothing. */
typedef uint32_t MCAsyncJobId;

enum MCAsyncError
{
	kMCAsyncErrorNone = 0,
	/* MCAsyncCoreCancel was called for the job */
	kMCAsyncErrorCancelled,
	kMCAsyncErrorOutOfMemory,
	/* This platform cannot do this (a process on Android or in a browser) */
	kMCAsyncErrorNotSupported,
	/* The file or folder could not be opened or created */
	kMCAsyncErrorOpen,
	kMCAsyncErrorRead,
	kMCAsyncErrorWrite,
	/* The folder could not be listed */
	kMCAsyncErrorList,
	/* The process could not be started */
	kMCAsyncErrorSpawn,
	/* The file is larger than a value can hold */
	kMCAsyncErrorTooLarge,
};

enum MCAsyncEventKind
{
	/* A process started with 'stream' wrote to its output (stream 1) or its
	 * error output (stream 2) */
	kMCAsyncEventData,
	/* The job is over. Every job that was started gives exactly one, and it
	 * is the job's last event. */
	kMCAsyncEventDone,
	/* A wake (MCAsyncCoreWakeCreate) was signalled, once or many times,
	 * since its last event. 'job' is the wake's number and 'context' what
	 * the wake was made with. */
	kMCAsyncEventWake,
};

struct MCAsyncEvent
{
	MCAsyncJobId job;
	/* What the job was started with */
	void *context;
	MCAsyncEventKind kind;
	/* Data: 1 or 2 */
	int stream;
	/* Data: what was written. Done: what the job made (the file read, the
	 * listing, the gathered output of a process), which a failed or
	 * cancelled process job also has, as far as it got. Allocated with
	 * malloc. The callback may keep it, by setting the field to nullptr;
	 * otherwise it is freed when the callback returns. Never nullptr when
	 * length is not 0. */
	char *data;
	size_t length;
	/* Done */
	MCAsyncError error;
	/* Done: the exit code of a process (128 + the signal's number for one
	 * that a signal ended, as a shell gives it), or the system's error code
	 * (errno, GetLastError) when error is one that the system reported */
	uint32_t code;
};

/* Tells the main thread that there are events to drain. Called on any
 * thread, with a lock held: it must not call anything of this file, and
 * must not wait for the main thread. One call may stand for many events:
 * it is not called again until MCAsyncCoreDrain has run. */
typedef void (*MCAsyncWakeCallback)(void *context);

typedef void (*MCAsyncEventCallback)(void *context, MCAsyncEvent& event);

/* Called on each new thread as it starts and as it ends (Android attaches
 * the thread to the Java machine, which the wake needs there) */
typedef void (*MCAsyncThreadCallback)(bool starting);

/* Start the core. Returns false if it is started already, or there is no
 * memory. */
bool MCAsyncCoreInitialize(MCAsyncWakeCallback p_wake, void *p_context,
                           MCAsyncThreadCallback p_thread);

bool MCAsyncCoreIsInitialized(void);

/* Wait until every write job has ended (its Done event is queued), for up
 * to p_wait_ms. True if none is left running or waiting. For the engine as
 * it quits: what a script handed over to be written is nowhere but in
 * memory, so those jobs are finished where MCAsyncCoreFinalize would drop
 * them half done. */
bool MCAsyncCoreFinishWrites(unsigned int p_wait_ms);

/* Stop the core: no wake is called once this returns. Every job is
 * cancelled and every process still running is killed, with the processes
 * it started. Waits up to p_wait_ms for the threads to end, and returns
 * true if they all did: then nothing of this file still reads what a job
 * was given (the bytes of a write job). If it returns false, a thread is
 * still in a call the system has not returned from; what its job was given
 * must be left allocated. Events not drained are dropped. */
bool MCAsyncCoreFinalize(unsigned int p_wait_ms);

/* Start a job. Each returns the job's number, or 0 if the job could not be
 * made at all (no memory, or the core is not initialized): then there is
 * no event. A job that was made always ends with a Done event, whatever
 * went wrong, and never before the call that started it returns. */

/* Read the whole of a file. Done has its contents. */
MCAsyncJobId MCAsyncCoreReadFile(const char *p_path, void *p_context);

/* Write p_length bytes to a file, replacing it or adding to its end. The
 * bytes are NOT copied: they must stay as they are until the job's Done
 * event has been drained (or MCAsyncCoreFinalize has returned true). */
MCAsyncJobId MCAsyncCoreWriteFile(const char *p_path, const void *p_bytes,
                                  size_t p_length, bool p_append,
                                  void *p_context);

/* Copy a file's contents, permissions and times. A copy that fails or is
 * cancelled leaves no file at p_to. */
MCAsyncJobId MCAsyncCoreCopyFile(const char *p_from, const char *p_to,
                                 void *p_context);

/* List a folder. Done has one line (ended by a line feed) for each entry:
 * its path from the folder, with '/' between the parts, and a '/' at the
 * end if it is a folder. The entries of a folder are in the order of their
 * bytes, and with p_recursive each folder is followed by its entries. A
 * link to a folder is listed as a folder and not entered. A name with a
 * line feed in it is left out. */
MCAsyncJobId MCAsyncCoreListFolder(const char *p_path, bool p_recursive,
                                   void *p_context);

struct MCAsyncProcessOptions
{
	/* Other than Windows: the program and its arguments, ended by nullptr.
	 * A program with no '/' in it is looked for in PATH. */
	const char *const *arguments;
	/* Windows: the command line, as CreateProcess takes it */
	const char *command_line;
	/* Windows: creation flags to add (CREATE_NEW_CONSOLE, CREATE_NO_WINDOW)
	 * and whether to start with the window hidden */
	uint32_t creation_flags;
	bool hide_window;

	/* Written to the process's input as soon as it runs; copied */
	const void *input;
	size_t input_length;
	/* Close the input once that is written, as MCAsyncCoreProcessCloseInput
	 * does */
	bool close_input;
	/* The error output joins the output (all of it is stream 1) */
	bool merge_error;
	/* Give the output as Data events as it comes. Without, it is gathered
	 * and Done has all of it (with the error output after the output, when
	 * they are not merged: use merge_error to keep their order). */
	bool stream;
};

/* Run a process. It starts (or fails to) before this returns; Done comes
 * when it has exited and its output has ended. */
MCAsyncJobId MCAsyncCoreStartProcess(const MCAsyncProcessOptions& p_options,
                                     void *p_context);

/* Whether a process can be run here at all. Where it cannot (Android, iOS
 * and a browser), MCAsyncCoreStartProcess's job is Done at once with
 * kMCAsyncErrorNotSupported. */
bool MCAsyncCoreCanStartProcesses(void);

/* Queue bytes for the process's input (they are copied). False if the job
 * is not a running process, its input is closed, or there is no memory. */
bool MCAsyncCoreProcessWrite(MCAsyncJobId p_job, const void *p_bytes,
                             size_t p_length);

/* Close the process's input once what is queued has been written */
bool MCAsyncCoreProcessCloseInput(MCAsyncJobId p_job);

/* A function of native code, with what it is called with */
typedef void (*MCAsyncNativeFunction)(void *context);

/* Call a function on another thread: Done comes when it has returned. The
 * function must touch nothing of the engine, and what p_function_context
 * points to must stay until Done. The calls have threads of their own (8),
 * so that a long one holds up no file job; a call that waits for one of
 * them and is cancelled is never made (Done says kMCAsyncErrorCancelled),
 * and one that is being made is not interrupted. */
MCAsyncJobId MCAsyncCoreCall(MCAsyncNativeFunction p_function,
                             void *p_function_context, void *p_context);

/* Ask a job to stop. It still ends with a Done event, whose error is
 * kMCAsyncErrorCancelled unless the job was over already. A process is
 * killed, with the processes it started. False if there is no such job. */
bool MCAsyncCoreCancel(MCAsyncJobId p_job);

enum MCAsyncStatus
{
	/* No such job: it never was, or its Done event has been drained */
	kMCAsyncStatusNone = 0,
	/* Waiting for a thread */
	kMCAsyncStatusQueued,
	kMCAsyncStatusRunning,
	/* Over, with its Done event waiting to be drained */
	kMCAsyncStatusFinished,
};

MCAsyncStatus MCAsyncCoreStatus(MCAsyncJobId p_job);

/* How far a job has got: bytes read, written or copied, with the total
 * where it is known (0 where not); entries listed; bytes of output a
 * process has given. False if there is no such job. */
bool MCAsyncCoreProgress(MCAsyncJobId p_job, uint64_t& r_done,
                         uint64_t& r_total);

/* Call p_callback for every event queued, in order */
void MCAsyncCoreDrain(MCAsyncEventCallback p_callback, void *p_context);

/* How many threads the file jobs may use, and the native calls: 4 and 8,
 * and 0 in a browser, where no thread can be made. This sets both. With 0,
 * or when the system refuses the first thread, such a job runs inside the
 * call that starts it: its events are queued, and the wake is called on
 * the main thread, before that call returns. Tests set it. Takes effect
 * for threads not yet started. */
void MCAsyncCoreSetThreadLimit(unsigned int p_limit);

////////////////////////////////////////////////////////////////////////////////
//
//  WAKES
//
// A wake is how a thread that is not the engine's (a native library's own)
// tells the main thread that it has something for it, without touching the
// engine: it signals the wake, and the next drain gives one Wake event,
// however many signals there were since the last.

/* A wake's number. 0 is never a wake. A number names its wake only: one
 * kept after the wake was destroyed, or after the core was finalized, names
 * nothing, and signalling it does nothing. */
typedef uint32_t MCAsyncWakeId;

/* Make a wake. 0 if the core is not initialized or there are too many
 * (256). */
MCAsyncWakeId MCAsyncCoreWakeCreate(void *p_context);

/* Destroy a wake: no event of it comes after this. False if there is no
 * such wake. MCAsyncCoreFinalize destroys them all. */
bool MCAsyncCoreWakeDestroy(MCAsyncWakeId p_wake);

/* Signal a wake. ON ANY THREAD, AT ANY TIME: before the core is
 * initialized, after it is finalized, with a number that names no wake. It
 * takes a lock for a moment, allocates nothing and waits for nothing. */
void MCAsyncCoreWakeSignal(MCAsyncWakeId p_wake);

#endif
