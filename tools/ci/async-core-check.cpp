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

// Checks the engine's background jobs (engine/src/async-core.cpp) on their
// own, without the engine: tools/ci/async_core_check.py builds this file
// with that one and runs it, with the sanitizers where there are any.
//
//   async-core-check <folder to work in> [name of a group of checks]
//
// It is its own "main thread": the wake that the core calls on its threads
// signals a condition here, as it queues a notification in the engine, and
// the checks wait on it and drain the events. It is also the program that
// the process checks run (--child ...), so that they need nothing of the
// system they run on: the same checks run on Linux, macOS and Windows.
//
// Each check prints "PASS <what>" or "FAIL <what> (<value>)". Exit status 0
// when every check passed.

#include "async-core.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <atomic>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <fcntl.h>
#include <io.h>
#else
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#if defined(__APPLE__)
#include <crt_externs.h>
#endif
#endif

////////////////////////////////////////////////////////////////////////////////

static int s_passes = 0;
static int s_failures = 0;

static void check(bool p_ok, const char *p_what, long long p_value)
{
	if (p_ok)
		s_passes++;
	else
		s_failures++;
	if (p_ok)
		printf("PASS %s\n", p_what);
	else
		printf("FAIL %s (%lld)\n", p_what, p_value);
	fflush(stdout);
}

static void sleep_ms(unsigned int p_ms)
{
#if defined(_WIN32)
	Sleep(p_ms);
#else
	struct timespec t_time;
	t_time.tv_sec = p_ms / 1000;
	t_time.tv_nsec = (long)(p_ms % 1000) * 1000000;
	nanosleep(&t_time, nullptr);
#endif
}

static unsigned long long now_ms(void)
{
#if defined(_WIN32)
	return GetTickCount64();
#else
	struct timespec t_time;
	clock_gettime(CLOCK_MONOTONIC, &t_time);
	return (unsigned long long)t_time.tv_sec * 1000 + t_time.tv_nsec / 1000000;
#endif
}

////////////////////////////////////////////////////////////////////////////////
//
//  THE WAKE, AND THE EVENTS IT BRINGS
//

#if defined(_WIN32)
static HANDLE s_wake_event = nullptr;
static DWORD s_main_thread = 0;
#else
static pthread_mutex_t s_wake_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t s_wake_condition = PTHREAD_COND_INITIALIZER;
static bool s_wake_pending = false;
static pthread_t s_main_thread;
#endif

/* How often the core has woken the main thread, and whether it ever did so
 * on the main thread itself (which it does only without threads); how many
 * threads said that they started and ended */
static std::atomic<int> s_wakes(0);
static std::atomic<int> s_wakes_on_main(0);
static std::atomic<int> s_thread_starts(0);
static std::atomic<int> s_thread_ends(0);

static void wake(void *)
{
	s_wakes++;
#if defined(_WIN32)
	if (GetCurrentThreadId() == s_main_thread)
		s_wakes_on_main++;
	SetEvent(s_wake_event);
#else
	if (pthread_equal(pthread_self(), s_main_thread))
		s_wakes_on_main++;
	pthread_mutex_lock(&s_wake_mutex);
	s_wake_pending = true;
	pthread_cond_signal(&s_wake_condition);
	pthread_mutex_unlock(&s_wake_mutex);
#endif
}

static void thread_callback(bool p_starting)
{
	if (p_starting)
		s_thread_starts++;
	else
		s_thread_ends++;
}

/* Wait until the core wakes the main thread, or p_ms pass */
static void wait_for_wake(unsigned int p_ms)
{
#if defined(_WIN32)
	WaitForSingleObject(s_wake_event, p_ms);
#else
	struct timeval t_now;
	gettimeofday(&t_now, nullptr);
	struct timespec t_until;
	t_until.tv_sec = t_now.tv_sec + p_ms / 1000;
	t_until.tv_nsec = t_now.tv_usec * 1000 + (long)(p_ms % 1000) * 1000000;
	if (t_until.tv_nsec >= 1000000000)
	{
		t_until.tv_sec += 1;
		t_until.tv_nsec -= 1000000000;
	}
	pthread_mutex_lock(&s_wake_mutex);
	if (!s_wake_pending)
		pthread_cond_timedwait(&s_wake_condition, &s_wake_mutex, &t_until);
	s_wake_pending = false;
	pthread_mutex_unlock(&s_wake_mutex);
#endif
}

/* An event as it was given, kept */
struct Seen
{
	MCAsyncJobId job;
	void *context;
	MCAsyncEventKind kind;
	int stream;
	char *data;
	size_t length;
	MCAsyncError error;
	uint32_t code;
	Seen *next;
};

static Seen *s_seen_first = nullptr;
static Seen *s_seen_last = nullptr;
static int s_seen_count = 0;

static void on_event(void *, MCAsyncEvent& p_event)
{
	Seen *t_seen = (Seen *)calloc(1, sizeof(Seen));
	t_seen->job = p_event.job;
	t_seen->context = p_event.context;
	t_seen->kind = p_event.kind;
	t_seen->stream = p_event.stream;
	/* Kept, as the engine keeps what it makes a value of */
	t_seen->data = p_event.data;
	p_event.data = nullptr;
	t_seen->length = p_event.length;
	t_seen->error = p_event.error;
	t_seen->code = p_event.code;
	if (s_seen_last != nullptr)
		s_seen_last->next = t_seen;
	else
		s_seen_first = t_seen;
	s_seen_last = t_seen;
	s_seen_count++;
}

static void forget_events(void)
{
	while (s_seen_first != nullptr)
	{
		Seen *t_seen = s_seen_first;
		s_seen_first = t_seen->next;
		free(t_seen->data);
		free(t_seen);
	}
	s_seen_last = nullptr;
	s_seen_count = 0;
}

static void drain(void)
{
	MCAsyncCoreDrain(on_event, nullptr);
}

/* The Done event of a job, if it has been seen */
static Seen *find_done(MCAsyncJobId p_job)
{
	for (Seen *t_seen = s_seen_first; t_seen != nullptr; t_seen = t_seen->next)
		if (t_seen->job == p_job && t_seen->kind == kMCAsyncEventDone)
			return t_seen;
	return nullptr;
}

static int count_done(MCAsyncJobId p_job)
{
	int t_count = 0;
	for (Seen *t_seen = s_seen_first; t_seen != nullptr; t_seen = t_seen->next)
		if (t_seen->job == p_job && t_seen->kind == kMCAsyncEventDone)
			t_count++;
	return t_count;
}

/* Wait for a job's Done event, draining as the core wakes. nullptr if it
 * has not come in p_ms. */
static Seen *wait_done(MCAsyncJobId p_job, unsigned int p_ms)
{
	unsigned long long t_until = now_ms() + p_ms;
	for (;;)
	{
		drain();
		Seen *t_done = find_done(p_job);
		if (t_done != nullptr)
			return t_done;
		unsigned long long t_now = now_ms();
		if (t_now >= t_until)
			return nullptr;
		wait_for_wake((unsigned int)(t_until - t_now < 200 ? t_until - t_now
		                                                    : 200));
	}
}

/* All that a job wrote on a stream as Data events, joined (malloc) */
static char *joined_data(MCAsyncJobId p_job, int p_stream, size_t& r_length)
{
	r_length = 0;
	for (Seen *t_seen = s_seen_first; t_seen != nullptr; t_seen = t_seen->next)
		if (t_seen->job == p_job && t_seen->kind == kMCAsyncEventData &&
		    t_seen->stream == p_stream)
			r_length += t_seen->length;
	char *t_joined = (char *)malloc(r_length + 1);
	size_t t_offset = 0;
	for (Seen *t_seen = s_seen_first; t_seen != nullptr; t_seen = t_seen->next)
		if (t_seen->job == p_job && t_seen->kind == kMCAsyncEventData &&
		    t_seen->stream == p_stream)
		{
			memcpy(t_joined + t_offset, t_seen->data, t_seen->length);
			t_offset += t_seen->length;
		}
	t_joined[r_length] = '\0';
	return t_joined;
}

static bool data_is(const Seen *p_seen, const char *p_text)
{
	size_t t_length = strlen(p_text);
	return p_seen != nullptr && p_seen->length == t_length &&
			(t_length == 0 || memcmp(p_seen->data, p_text, t_length) == 0);
}

static void start_core(void)
{
	MCAsyncCoreInitialize(wake, nullptr, thread_callback);
}

/* Stop the core and say whether its threads all ended */
static bool stop_core(void)
{
	bool t_ended = MCAsyncCoreFinalize(10000);
	forget_events();
	return t_ended;
}

////////////////////////////////////////////////////////////////////////////////
//
//  FILES OF THE CHECK'S OWN
//

static char s_folder[2048];
static char s_self[2048];

/* A path in the folder the check works in (a static buffer per slot) */
static const char *path_in(int p_slot, const char *p_name)
{
	static char s_paths[8][4096];
#if defined(_WIN32)
	snprintf(s_paths[p_slot], sizeof(s_paths[p_slot]), "%s\\%s", s_folder,
	         p_name);
#else
	snprintf(s_paths[p_slot], sizeof(s_paths[p_slot]), "%s/%s", s_folder,
	         p_name);
#endif
	return s_paths[p_slot];
}

/* The bytes of a pattern that no shift or truncation leaves the same */
static char *pattern(size_t p_length)
{
	char *t_bytes = (char *)malloc(p_length + 1);
	unsigned int t_state = 12345;
	for (size_t i = 0; i < p_length; i++)
	{
		t_state = t_state * 1103515245u + 12345u;
		t_bytes[i] = (char)(t_state >> 16);
	}
	return t_bytes;
}

/* Read a file with the C library, not with what is being checked. ASCII
 * paths only on Windows. */
static char *read_plain(const char *p_path, size_t& r_length)
{
	r_length = 0;
	FILE *t_file = fopen(p_path, "rb");
	if (t_file == nullptr)
		return nullptr;
	size_t t_capacity = 1 << 16;
	char *t_bytes = (char *)malloc(t_capacity);
	for (;;)
	{
		if (r_length == t_capacity)
		{
			t_capacity *= 2;
			t_bytes = (char *)realloc(t_bytes, t_capacity);
		}
		size_t t_read = fread(t_bytes + r_length, 1, t_capacity - r_length,
		                      t_file);
		if (t_read == 0)
			break;
		r_length += t_read;
	}
	fclose(t_file);
	return t_bytes;
}

static bool write_plain(const char *p_path, const char *p_bytes,
                        size_t p_length)
{
	FILE *t_file = fopen(p_path, "wb");
	if (t_file == nullptr)
		return false;
	bool t_ok = fwrite(p_bytes, 1, p_length, t_file) == p_length;
	return fclose(t_file) == 0 && t_ok;
}

static bool file_is(const char *p_path, const char *p_bytes, size_t p_length)
{
	size_t t_length = 0;
	char *t_bytes = read_plain(p_path, t_length);
	bool t_same = t_bytes != nullptr && t_length == p_length &&
			(p_length == 0 || memcmp(t_bytes, p_bytes, p_length) == 0);
	free(t_bytes);
	return t_same;
}

static bool file_exists(const char *p_path)
{
	FILE *t_file = fopen(p_path, "rb");
	if (t_file == nullptr)
		return false;
	fclose(t_file);
	return true;
}

static bool make_folder(const char *p_path)
{
#if defined(_WIN32)
	/* The path is UTF-8, as the core takes it */
	wchar_t t_wide[4096];
	if (MultiByteToWideChar(CP_UTF8, 0, p_path, -1, t_wide, 4096) <= 0)
		return false;
	return CreateDirectoryW(t_wide, nullptr) != 0;
#else
	return mkdir(p_path, 0777) == 0;
#endif
}

////////////////////////////////////////////////////////////////////////////////
//
//  THE CHECKS: FILES
//

static void check_lifecycle(void)
{
	check(!MCAsyncCoreIsInitialized(), "the core is not initialized at first", 0);
	/* (Before any core there is not even the wakes' lock, when this is the
	 * first group to run) */
	MCAsyncCoreWakeSignal(0);
	MCAsyncCoreWakeSignal(0x101);
	check(MCAsyncCoreWakeCreate(nullptr) == 0 && !MCAsyncCoreWakeDestroy(0x101),
	      "without the core no wake is made, and signalling one does nothing", 0);
	check(MCAsyncCoreReadFile(path_in(0, "x"), nullptr) == 0,
	      "no job starts without the core", 0);
	check(MCAsyncCoreFinalize(0), "finalizing nothing is nothing", 0);
	check(MCAsyncCoreInitialize(wake, nullptr, thread_callback),
	      "the core initializes", 0);
	check(!MCAsyncCoreInitialize(wake, nullptr, thread_callback),
	      "and only once", 0);
	check(MCAsyncCoreIsInitialized(), "it says it is initialized", 0);
	check(MCAsyncCoreStatus(1) == kMCAsyncStatusNone, "job 1 is not there yet", 0);
	check(!MCAsyncCoreCancel(0) && !MCAsyncCoreCancel(1),
	      "cancelling no job does nothing", 0);
	check(stop_core(), "the core finalizes with nothing started", 0);
	check(!MCAsyncCoreIsInitialized(), "and is then not initialized", 0);
}

static void check_write_and_read(void)
{
	start_core();

	const char *t_path = path_in(0, "written.bin");
	size_t t_length = 3 * 1024 * 1024 + 17;
	char *t_bytes = pattern(t_length);

	int t_context = 0;
	MCAsyncJobId t_write =
			MCAsyncCoreWriteFile(t_path, t_bytes, t_length, false, &t_context);
	check(t_write != 0, "a write job starts", 0);
	MCAsyncStatus t_status = MCAsyncCoreStatus(t_write);
	check(t_status == kMCAsyncStatusQueued || t_status == kMCAsyncStatusRunning ||
	      t_status == kMCAsyncStatusFinished, "it has a status at once", t_status);

	Seen *t_done = wait_done(t_write, 20000);
	check(t_done != nullptr, "the write job ends", 0);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone,
	      "without an error", t_done != nullptr ? t_done->error : -1);
	check(t_done != nullptr && t_done->context == &t_context,
	      "with the context it was started with", 0);
	check(t_done != nullptr && t_done->length == 0 && t_done->data == nullptr,
	      "and nothing made", 0);
	check(file_is(t_path, t_bytes, t_length), "the file has what was written", 0);
	check(MCAsyncCoreStatus(t_write) == kMCAsyncStatusNone,
	      "a job whose end was given is no job", MCAsyncCoreStatus(t_write));
	uint64_t t_progress_done = 0, t_progress_total = 0;
	check(!MCAsyncCoreProgress(t_write, t_progress_done, t_progress_total) &&
	      !MCAsyncCoreCancel(t_write) &&
	      !MCAsyncCoreProcessWrite(t_write, "x", 1) &&
	      !MCAsyncCoreProcessCloseInput(t_write),
	      "and every call with its number does nothing", 0);

	MCAsyncJobId t_read = MCAsyncCoreReadFile(t_path, nullptr);
	check(t_read != 0 && t_read != t_write, "a read job starts, with a new number",
	      t_read);
	t_done = wait_done(t_read, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->length == t_length &&
	      memcmp(t_done->data, t_bytes, t_length) == 0,
	      "the read job gives what the file has",
	      t_done != nullptr ? (long long)t_done->length : -1);

	/* Appending */
	MCAsyncJobId t_first = MCAsyncCoreWriteFile(path_in(1, "appended.txt"),
	                                            "one,", 4, true, nullptr);
	wait_done(t_first, 20000);
	MCAsyncJobId t_second = MCAsyncCoreWriteFile(path_in(1, "appended.txt"),
	                                             "two", 3, true, nullptr);
	t_done = wait_done(t_second, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      file_is(path_in(1, "appended.txt"), "one,two", 7),
	      "appending makes the file, then adds to its end", 0);

	/* Replacing with less, and with nothing */
	MCAsyncJobId t_replace = MCAsyncCoreWriteFile(path_in(1, "appended.txt"),
	                                              "new", 3, false, nullptr);
	t_done = wait_done(t_replace, 20000);
	check(t_done != nullptr && file_is(path_in(1, "appended.txt"), "new", 3),
	      "writing replaces a longer file", 0);
	MCAsyncJobId t_empty = MCAsyncCoreWriteFile(path_in(1, "empty.bin"),
	                                            nullptr, 0, false, nullptr);
	t_done = wait_done(t_empty, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      file_is(path_in(1, "empty.bin"), "", 0), "writing nothing makes an empty file", 0);
	MCAsyncJobId t_read_empty = MCAsyncCoreReadFile(path_in(1, "empty.bin"), nullptr);
	t_done = wait_done(t_read_empty, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->length == 0 && t_done->data == nullptr,
	      "reading an empty file gives nothing, with no error", 0);

	/* A name that is not ASCII, which Windows takes as UTF-8 */
	const char *t_named = path_in(2, "caf\xc3\xa9 \xe2\x9c\x93.txt");
	MCAsyncJobId t_named_write =
			MCAsyncCoreWriteFile(t_named, "accent", 6, false, nullptr);
	t_done = wait_done(t_named_write, 20000);
	MCAsyncJobId t_named_read = MCAsyncCoreReadFile(t_named, nullptr);
	t_done = wait_done(t_named_read, 20000);
	check(data_is(t_done, "accent"), "a file with a name that is not ASCII", 0);

	free(t_bytes);
	check(stop_core(), "the threads end when the core is finalized", 0);
}

static void check_file_errors(void)
{
	start_core();

	MCAsyncJobId t_job = MCAsyncCoreReadFile(path_in(0, "not-there.bin"), nullptr);
	Seen *t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorOpen && t_done->code != 0,
	      "reading a file that is not there cannot open it",
	      t_done != nullptr ? t_done->error : -1);
#if !defined(_WIN32)
	check(t_done != nullptr && t_done->code == ENOENT,
	      "with the system's error", t_done != nullptr ? t_done->code : 0);
#else
	check(t_done != nullptr && t_done->code == ERROR_FILE_NOT_FOUND,
	      "with the system's error", t_done != nullptr ? t_done->code : 0);
#endif

	t_job = MCAsyncCoreReadFile(s_folder, nullptr);
	t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorOpen,
	      "reading a folder cannot open it", t_done != nullptr ? t_done->error : -1);

	t_job = MCAsyncCoreWriteFile(path_in(0, "no-such-folder/file.bin"), "x", 1,
	                             false, nullptr);
	t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorOpen,
	      "writing into a folder that is not there cannot open the file",
	      t_done != nullptr ? t_done->error : -1);

	t_job = MCAsyncCoreCopyFile(path_in(0, "not-there.bin"),
	                            path_in(1, "copy-of-nothing.bin"), nullptr);
	t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorOpen &&
	      !file_exists(path_in(1, "copy-of-nothing.bin")),
	      "copying a file that is not there cannot open it, and makes none",
	      t_done != nullptr ? t_done->error : -1);

	t_job = MCAsyncCoreListFolder(path_in(0, "no-such-folder"), true, nullptr);
	t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorList && t_done->code != 0,
	      "listing a folder that is not there fails",
	      t_done != nullptr ? t_done->error : -1);

	write_plain(path_in(0, "plain.txt"), "plain", 5);
	t_job = MCAsyncCoreListFolder(path_in(0, "plain.txt"), false, nullptr);
	t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorList,
	      "listing a file fails", t_done != nullptr ? t_done->error : -1);

	check(stop_core(), "the threads end after the failures", 0);
}

static void check_copy(void)
{
	start_core();

	size_t t_length = 5 * 1024 * 1024 + 3;
	char *t_bytes = pattern(t_length);
	write_plain(path_in(0, "original.bin"), t_bytes, t_length);
#if !defined(_WIN32)
	chmod(path_in(0, "original.bin"), 0640);
#endif

	MCAsyncJobId t_job = MCAsyncCoreCopyFile(path_in(0, "original.bin"),
	                                         path_in(1, "copy.bin"), nullptr);
	Seen *t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone,
	      "a copy job ends without an error", t_done != nullptr ? t_done->error : -1);
	check(file_is(path_in(1, "copy.bin"), t_bytes, t_length),
	      "the copy has what the file has", 0);
	check(file_is(path_in(0, "original.bin"), t_bytes, t_length),
	      "and the file still has it", 0);
#if !defined(_WIN32)
	struct stat t_stat, t_copy_stat;
	stat(path_in(0, "original.bin"), &t_stat);
	stat(path_in(1, "copy.bin"), &t_copy_stat);
	check((t_copy_stat.st_mode & 0777) == 0640, "the copy has the file's permissions",
	      t_copy_stat.st_mode & 0777);
	check(t_copy_stat.st_mtime == t_stat.st_mtime, "and the time it was changed",
	      (long long)(t_copy_stat.st_mtime - t_stat.st_mtime));
#endif

	/* Onto a file that is there: replaced */
	write_plain(path_in(1, "copy.bin"), "something much shorter", 22);
	t_job = MCAsyncCoreCopyFile(path_in(0, "original.bin"), path_in(1, "copy.bin"),
	                            nullptr);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      file_is(path_in(1, "copy.bin"), t_bytes, t_length),
	      "a copy replaces the file that was there", 0);

	/* Onto itself: refused, and the file is as it was */
	t_job = MCAsyncCoreCopyFile(path_in(0, "original.bin"),
	                            path_in(1, "original.bin"), nullptr);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error != kMCAsyncErrorNone,
	      "copying a file onto itself fails", t_done != nullptr ? t_done->error : -1);
	check(file_is(path_in(0, "original.bin"), t_bytes, t_length),
	      "and leaves the file as it was", 0);

	free(t_bytes);
	check(stop_core(), "the threads end after the copies", 0);
}

static void check_list(void)
{
	start_core();

	make_folder(path_in(0, "tree"));
	make_folder(path_in(0, "tree/b-folder"));
	make_folder(path_in(0, "tree/b-folder/inner"));
	make_folder(path_in(0, "tree/empty"));
	write_plain(path_in(0, "tree/a.txt"), "a", 1);
	write_plain(path_in(0, "tree/c.txt"), "c", 1);
	write_plain(path_in(0, "tree/B.txt"), "B", 1);
	write_plain(path_in(0, "tree/b-folder/one.txt"), "1", 1);
	write_plain(path_in(0, "tree/b-folder/inner/deep.txt"), "d", 1);
	write_plain(path_in(0, "tree/.hidden"), "h", 1);

	MCAsyncJobId t_job = MCAsyncCoreListFolder(path_in(0, "tree"), false, nullptr);
	Seen *t_done = wait_done(t_job, 20000);
	check(data_is(t_done, ".hidden\nB.txt\na.txt\nb-folder/\nc.txt\nempty/\n"),
	      "a folder's entries, in the order of their bytes, folders with a '/'",
	      t_done != nullptr ? (long long)t_done->length : -1);

	t_job = MCAsyncCoreListFolder(path_in(0, "tree"), true, nullptr);
	t_done = wait_done(t_job, 20000);
	check(data_is(t_done, ".hidden\nB.txt\na.txt\nb-folder/\nb-folder/inner/\n"
	                      "b-folder/inner/deep.txt\nb-folder/one.txt\nc.txt\nempty/\n"),
	      "and with the entries of each folder after it",
	      t_done != nullptr ? (long long)t_done->length : -1);
	if (t_done != nullptr && t_done->data != nullptr && s_failures > 0)
		printf("     listing was:\n%.*s", (int)t_done->length, t_done->data);

	t_job = MCAsyncCoreListFolder(path_in(0, "tree/empty"), true, nullptr);
	t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->length == 0, "an empty folder lists as nothing", 0);

#if !defined(_WIN32)
	/* The path with its '/' at the end lists the same */
	char t_slashed[4200];
	snprintf(t_slashed, sizeof(t_slashed), "%s/", path_in(0, "tree"));
	t_job = MCAsyncCoreListFolder(t_slashed, false, nullptr);
	t_done = wait_done(t_job, 20000);
	check(data_is(t_done, ".hidden\nB.txt\na.txt\nb-folder/\nc.txt\nempty/\n"),
	      "a path that ends in '/' lists the same", 0);

	/* A link to a folder is a folder that is not entered (this one would
	 * never end); a name with a line feed is left out */
	make_folder(path_in(0, "links"));
	make_folder(path_in(0, "links/real"));
	write_plain(path_in(0, "links/real/file.txt"), "f", 1);
	check(symlink("..", path_in(0, "links/real/up")) == 0 &&
	      symlink("real/file.txt", path_in(1, "links/to-file")) == 0,
	      "(links are made)", errno);
	write_plain(path_in(0, "links/two\nlines"), "x", 1);
	t_job = MCAsyncCoreListFolder(path_in(0, "links"), true, nullptr);
	t_done = wait_done(t_job, 20000);
	check(data_is(t_done, "real/\nreal/file.txt\nreal/up/\nto-file\n"),
	      "a link to a folder is listed and not entered",
	      t_done != nullptr ? (long long)t_done->length : -1);

	/* A folder that may not be read is in the listing, with nothing after */
	if (geteuid() != 0)
	{
		make_folder(path_in(0, "tree/closed"));
		write_plain(path_in(0, "tree/closed/secret.txt"), "s", 1);
		chmod(path_in(0, "tree/closed"), 0);
		t_job = MCAsyncCoreListFolder(path_in(0, "tree"), true, nullptr);
		t_done = wait_done(t_job, 20000);
		check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
		      t_done->data != nullptr &&
		      strstr(t_done->data, "closed/\nempty/\n") != nullptr,
		      "a folder inside that may not be read is listed, and the job goes on",
		      t_done != nullptr ? t_done->error : -1);
		chmod(path_in(0, "tree/closed"), 0700);
	}
#else
	make_folder(path_in(0, "tree\\caf\xc3\xa9"));
	t_job = MCAsyncCoreWriteFile(path_in(0, "tree\\caf\xc3\xa9\\\xe2\x9c\x93.txt"),
	                             "x", 1, false, nullptr);
	wait_done(t_job, 20000);
	t_job = MCAsyncCoreListFolder(path_in(0, "tree\\caf\xc3\xa9"), true, nullptr);
	t_done = wait_done(t_job, 20000);
	check(data_is(t_done, "\xe2\x9c\x93.txt\n"),
	      "names that are not ASCII are listed as UTF-8",
	      t_done != nullptr ? (long long)t_done->length : -1);
#endif

	/* Many entries, more than one read of the folder gives */
	make_folder(path_in(0, "many"));
	char t_name[64];
	for (int i = 0; i < 1500; i++)
	{
		snprintf(t_name, sizeof(t_name), "many/file-%04d", i);
		write_plain(path_in(0, t_name), "", 0);
	}
	t_job = MCAsyncCoreListFolder(path_in(0, "many"), false, nullptr);
	t_done = wait_done(t_job, 30000);
	bool t_ordered = t_done != nullptr && t_done->length == 1500 * 10;
	for (int i = 0; t_ordered && i < 1500; i++)
	{
		snprintf(t_name, sizeof(t_name), "file-%04d\n", i);
		t_ordered = memcmp(t_done->data + i * 10, t_name, 10) == 0;
	}
	check(t_ordered, "1500 entries, every one, in order",
	      t_done != nullptr ? (long long)t_done->length : -1);

	check(stop_core(), "the threads end after the listings", 0);
}

/* Many jobs at once: each ends once, in no particular order */
static void check_many(void)
{
	start_core();

	enum { kJobs = 300 };
	static MCAsyncJobId t_jobs[kJobs];
	char t_name[64];
	char t_text[64];
	int t_before = s_wakes.load();

	for (int i = 0; i < kJobs; i++)
	{
		snprintf(t_name, sizeof(t_name), "many-%03d.txt", i);
		snprintf(t_text, sizeof(t_text), "file number %d", i);
		write_plain(path_in(0, t_name), t_text, strlen(t_text));
	}
	for (int i = 0; i < kJobs; i++)
	{
		snprintf(t_name, sizeof(t_name), "many-%03d.txt", i);
		t_jobs[i] = MCAsyncCoreReadFile(path_in(0, t_name), nullptr);
	}

	bool t_all = true;
	for (int i = 0; i < kJobs; i++)
	{
		Seen *t_done = wait_done(t_jobs[i], 30000);
		snprintf(t_text, sizeof(t_text), "file number %d", i);
		if (!data_is(t_done, t_text))
			t_all = false;
	}
	check(t_all, "300 read jobs at once each give their own file", 0);

	bool t_once = true, t_distinct = true;
	for (int i = 0; i < kJobs; i++)
	{
		if (count_done(t_jobs[i]) != 1)
			t_once = false;
		for (int j = 0; j < i; j++)
			if (t_jobs[i] == t_jobs[j] || t_jobs[i] == 0)
				t_distinct = false;
	}
	check(t_once, "each ends exactly once", 0);
	check(t_distinct, "each has its own number", 0);
	check(s_seen_count == kJobs, "and there is no other event", s_seen_count);
	check(s_wakes - t_before <= kJobs, "the main thread is woken no more often than there are events",
	      s_wakes - t_before);
	check(s_thread_starts >= 1 && s_thread_starts <= 64,
	      "threads were made, and each said so", s_thread_starts);

	/* Appends to one file, started together and each longer than the piece
	 * a write is made in: every one is written, and each is whole (on
	 * Windows the second could not open a file the first had open) */
	enum { kAppends = 6, kAppendSize = 2 * 1024 * 1024 + 4096 };
	forget_events();
	remove(path_in(1, "appended.bin"));
	static char *t_blocks[kAppends];
	MCAsyncJobId t_appends[kAppends];
	for (int i = 0; i < kAppends; i++)
	{
		t_blocks[i] = (char *)malloc(kAppendSize);
		memset(t_blocks[i], 'a' + i, kAppendSize);
	}
	for (int i = 0; i < kAppends; i++)
		t_appends[i] = MCAsyncCoreWriteFile(path_in(1, "appended.bin"),
		                                    t_blocks[i], kAppendSize, true,
		                                    nullptr);
	bool t_appended = true;
	for (int i = 0; i < kAppends; i++)
	{
		Seen *t_done = wait_done(t_appends[i], 60000);
		if (t_done == nullptr || t_done->error != kMCAsyncErrorNone)
			t_appended = false;
	}
	check(t_appended, "appends to one file at once are all written", 0);

	size_t t_appended_length = 0;
	char *t_appended_bytes = read_plain(path_in(1, "appended.bin"),
	                                    t_appended_length);
	bool t_whole = t_appended_bytes != nullptr &&
			t_appended_length == (size_t)kAppends * kAppendSize;
	int t_letters_seen = 0;
	for (int i = 0; t_whole && i < kAppends; i++)
	{
		const char *t_block = t_appended_bytes + (size_t)i * kAppendSize;
		for (size_t j = 1; j < kAppendSize; j++)
			if (t_block[j] != t_block[0])
			{
				t_whole = false;
				break;
			}
		if (t_block[0] >= 'a' && t_block[0] < 'a' + kAppends)
			t_letters_seen |= 1 << (t_block[0] - 'a');
	}
	check(t_whole && t_letters_seen == (1 << kAppends) - 1,
	      "and each is whole in the file, in whatever order",
	      (long)t_appended_length);
	free(t_appended_bytes);
	for (int i = 0; i < kAppends; i++)
		free(t_blocks[i]);

	check(stop_core(), "the threads end after the many jobs", 0);
	sleep_ms(50);
	check(s_thread_ends == s_thread_starts,
	      "every thread that started said that it ended",
	      s_thread_starts - s_thread_ends);
}

/* Without threads (a browser): a job runs inside the call that starts it */
static void check_without_threads(void)
{
	MCAsyncCoreSetThreadLimit(0);
	start_core();

	int t_starts_before = s_thread_starts.load();
	int t_wakes_on_main_before = s_wakes_on_main.load();

	MCAsyncJobId t_write = MCAsyncCoreWriteFile(path_in(0, "inline.txt"),
	                                            "inline", 6, false, nullptr);
	check(t_write != 0 && MCAsyncCoreStatus(t_write) == kMCAsyncStatusFinished,
	      "without threads a job is over when the call that starts it returns",
	      MCAsyncCoreStatus(t_write));
	check(s_seen_count == 0, "but its end is not given until the queue is drained",
	      s_seen_count);
	check(s_wakes_on_main > t_wakes_on_main_before,
	      "and the wake was called on the main thread", 0);

	MCAsyncJobId t_read = MCAsyncCoreReadFile(path_in(0, "inline.txt"), nullptr);
	MCAsyncJobId t_list = MCAsyncCoreListFolder(path_in(0, "tree/b-folder"), true, nullptr);
	MCAsyncJobId t_copy = MCAsyncCoreCopyFile(path_in(0, "inline.txt"),
	                                          path_in(1, "inline-copy.txt"), nullptr);
	MCAsyncJobId t_missing = MCAsyncCoreReadFile(path_in(0, "inline-missing"), nullptr);
	drain();
	check(find_done(t_write) != nullptr && data_is(find_done(t_read), "inline") &&
	      data_is(find_done(t_list), "inner/\ninner/deep.txt\none.txt\n") &&
	      find_done(t_copy) != nullptr &&
	      file_is(path_in(1, "inline-copy.txt"), "inline", 6) &&
	      find_done(t_missing) != nullptr &&
	      find_done(t_missing)->error == kMCAsyncErrorOpen,
	      "every kind of file job works without threads", 0);
	check(s_thread_starts == t_starts_before, "and no thread was made",
	      s_thread_starts - t_starts_before);

	check(stop_core(), "the core without threads finalizes", 0);
	MCAsyncCoreSetThreadLimit(4);
}

#if !defined(_WIN32)
/* A thread of the check that opens a named pipe to write after a while,
 * which lets go a read job that waits to open it */
struct FifoWriter
{
	const char *path;
	unsigned int after_ms;
	const char *text;
};

static void *fifo_writer(void *p_argument)
{
	FifoWriter *t_writer = (FifoWriter *)p_argument;
	sleep_ms(t_writer->after_ms);
	int t_fd = open(t_writer->path, O_WRONLY);
	if (t_fd >= 0)
	{
		ssize_t t_written = write(t_fd, t_writer->text, strlen(t_writer->text));
		(void)t_written;
		close(t_fd);
	}
	return nullptr;
}
#endif

static void check_cancel(void)
{
	start_core();

	/* A job that is over ends as it ended */
	MCAsyncJobId t_job = MCAsyncCoreWriteFile(path_in(0, "kept.txt"), "kept", 4,
	                                          false, nullptr);
	unsigned long long t_until = now_ms() + 20000;
	while (MCAsyncCoreStatus(t_job) != kMCAsyncStatusFinished && now_ms() < t_until)
		sleep_ms(5);
	check(MCAsyncCoreCancel(t_job), "a job that is over can still be named", 0);
	Seen *t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone,
	      "and cancelling it then changes nothing",
	      t_done != nullptr ? t_done->error : -1);

#if !defined(_WIN32)
	/* One thread, held by a read that waits for the other end of a named
	 * pipe: the jobs behind it wait, and one of them is cancelled */
	MCAsyncCoreSetThreadLimit(1);
	stop_core();
	start_core();

	const char *t_fifo = path_in(0, "held.fifo");
	check(mkfifo(t_fifo, 0600) == 0, "(a named pipe is made)", errno);
	MCAsyncJobId t_held = MCAsyncCoreReadFile(t_fifo, nullptr);
	MCAsyncJobId t_waiting = MCAsyncCoreReadFile(path_in(1, "kept.txt"), nullptr);
	MCAsyncJobId t_cancelled = MCAsyncCoreWriteFile(path_in(2, "never.txt"),
	                                                "never", 5, false, nullptr);
	sleep_ms(100);
	check(MCAsyncCoreStatus(t_held) == kMCAsyncStatusRunning,
	      "the first job runs", MCAsyncCoreStatus(t_held));
	check(MCAsyncCoreStatus(t_waiting) == kMCAsyncStatusQueued &&
	      MCAsyncCoreStatus(t_cancelled) == kMCAsyncStatusQueued,
	      "and those behind it wait, with one thread", MCAsyncCoreStatus(t_waiting));
	check(MCAsyncCoreCancel(t_cancelled), "a waiting job is cancelled", 0);
	drain();
	check(find_done(t_cancelled) == nullptr,
	      "which does not end it before its turn", 0);

	FifoWriter t_writer = {t_fifo, 100, "through the pipe"};
	pthread_t t_thread;
	pthread_create(&t_thread, nullptr, fifo_writer, &t_writer);

	t_done = wait_done(t_held, 20000);
	check(data_is(t_done, "through the pipe"),
	      "a read of what is not a file reads until it ends", 0);
	t_done = wait_done(t_waiting, 20000);
	check(data_is(t_done, "kept"), "the job behind it then runs", 0);
	t_done = wait_done(t_cancelled, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorCancelled,
	      "and the cancelled job ends as cancelled",
	      t_done != nullptr ? t_done->error : -1);
	check(!file_exists(path_in(2, "never.txt")), "without having written", 0);
	pthread_join(t_thread, nullptr);

	/* Finalizing with a job that the system has not let go of: the core
	 * does not wait for ever, and says that a thread is left */
	t_held = MCAsyncCoreReadFile(t_fifo, nullptr);
	sleep_ms(100);
	unsigned long long t_before = now_ms();
	bool t_ended = MCAsyncCoreFinalize(300);
	forget_events();
	unsigned long long t_took = now_ms() - t_before;
	check(!t_ended, "finalizing while a read is stuck says that a thread is left", 0);
	check(t_took >= 250 && t_took < 5000, "after waiting as long as it was given",
	      (long long)t_took);
	/* Let the stuck thread go, so that it ends (it finds the core shut
	 * down) before the check does */
	FifoWriter t_release = {t_fifo, 0, "late"};
	fifo_writer(&t_release);
	sleep_ms(200);

	MCAsyncCoreSetThreadLimit(4);
	start_core();
#endif

	/* A long copy cancelled as it runs leaves no file. (It may have ended
	 * before it was cancelled on a fast disk: then it ended well.) */
	size_t t_length = 48 * 1024 * 1024;
	char *t_bytes = (char *)calloc(1, t_length);
	write_plain(path_in(0, "large.bin"), t_bytes, t_length);
	free(t_bytes);
	t_job = MCAsyncCoreCopyFile(path_in(0, "large.bin"), path_in(1, "large-copy.bin"),
	                            nullptr);
	uint64_t t_copied = 0, t_total = 0;
	t_until = now_ms() + 20000;
	while (MCAsyncCoreProgress(t_job, t_copied, t_total) && t_copied == 0 &&
	       MCAsyncCoreStatus(t_job) != kMCAsyncStatusFinished && now_ms() < t_until)
		sleep_ms(1);
	MCAsyncCoreCancel(t_job);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && (t_done->error == kMCAsyncErrorCancelled ||
	                            t_done->error == kMCAsyncErrorNone),
	      "a copy cancelled as it runs ends, cancelled or done",
	      t_done != nullptr ? t_done->error : -1);
	if (t_done != nullptr && t_done->error == kMCAsyncErrorCancelled)
		check(!file_exists(path_in(1, "large-copy.bin")),
		      "a cancelled copy leaves no file", 0);
	check(t_total == 0 || t_total == t_length, "its progress knew the file's size",
	      (long long)t_total);

	check(stop_core(), "the threads end after the cancelling", 0);
}

/* Finalizing with jobs that wait and run: no event comes after, and the
 * core starts again */
static void check_finalize_busy(void)
{
	start_core();
	size_t t_length = 4 * 1024 * 1024;
	char *t_bytes = pattern(t_length);
	char t_name[64];
	for (int i = 0; i < 40; i++)
	{
		snprintf(t_name, sizeof(t_name), "busy-%02d.bin", i);
		MCAsyncCoreWriteFile(path_in(0, t_name), t_bytes, t_length, false, nullptr);
	}
	bool t_ended = MCAsyncCoreFinalize(30000);
	check(t_ended, "finalizing with 40 writes waiting or running ends every thread", 0);
	/* Only now may what the jobs were given go */
	free(t_bytes);
	check(!MCAsyncCoreIsInitialized(), "the core is finalized", 0);
	int t_before = s_seen_count;
	drain();
	check(s_seen_count == t_before, "draining a finalized core gives nothing", 0);

	start_core();
	MCAsyncJobId t_job = MCAsyncCoreWriteFile(path_in(0, "again.txt"), "again", 5,
	                                          false, nullptr);
	Seen *t_done = wait_done(t_job, 20000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      file_is(path_in(0, "again.txt"), "again", 5),
	      "the core works again after it was finalized", 0);

	/* The engine as it quits: the writes are finished first, whole */
	t_bytes = pattern(t_length);
	MCAsyncJobId t_reading =
			MCAsyncCoreReadFile(path_in(0, "again.txt"), nullptr);
	for (int i = 0; i < 12; i++)
	{
		snprintf(t_name, sizeof(t_name), "kept-%02d.bin", i);
		MCAsyncCoreWriteFile(path_in(0, t_name), t_bytes, t_length, false, nullptr);
	}
	check(MCAsyncCoreFinishWrites(60000),
	      "waiting for the writes ends when all 12 are written", 0);
	bool t_whole = true;
	for (int i = 0; i < 12 && t_whole; i++)
	{
		snprintf(t_name, sizeof(t_name), "kept-%02d.bin", i);
		t_whole = file_is(path_in(0, t_name), t_bytes, t_length);
	}
	check(t_whole, "and every file is whole", 0);
	check(MCAsyncCoreFinishWrites(0),
	      "with no write left there is nothing to wait for", 0);
	(void)t_reading;
	check(stop_core(), "and finalizes again", 0);
	free(t_bytes);
	check(MCAsyncCoreFinishWrites(1000),
	      "a finalized core has no writes to wait for", 0);
}

////////////////////////////////////////////////////////////////////////////////
//
//  THE CHECKS: PROCESSES
//

/* The modes of this program as a process started by the checks */
static int child_main(int p_count, char **p_arguments)
{
	const char *t_mode = p_count > 0 ? p_arguments[0] : "";
	long t_number = p_count > 1 ? atol(p_arguments[1]) : 0;

#if defined(_WIN32)
	_setmode(0, _O_BINARY);
	_setmode(1, _O_BINARY);
	_setmode(2, _O_BINARY);
#endif

	if (strcmp(t_mode, "exit") == 0)
		return (int)t_number;

	if (strcmp(t_mode, "both") == 0)
	{
		fputs("out\n", stdout);
		fflush(stdout);
		fputs("err\n", stderr);
		fflush(stderr);
		return 0;
	}

	/* Everything on the input to the output, then the count of it to the
	 * error output, and exit with p_number */
	if (strcmp(t_mode, "echo") == 0)
	{
		static char t_buffer[65536];
		unsigned long long t_total = 0;
		for (;;)
		{
#if defined(_WIN32)
			int t_read = _read(0, t_buffer, sizeof(t_buffer));
#else
			ssize_t t_read = read(0, t_buffer, sizeof(t_buffer));
#endif
			if (t_read <= 0)
				break;
			t_total += (unsigned long long)t_read;
			fwrite(t_buffer, 1, (size_t)t_read, stdout);
			fflush(stdout);
		}
		fprintf(stderr, "%llu", t_total);
		return (int)t_number;
	}

	/* p_number bytes of the pattern to the output */
	if (strcmp(t_mode, "spam") == 0)
	{
		char *t_bytes = pattern((size_t)t_number);
		size_t t_offset = 0;
		while (t_offset < (size_t)t_number)
		{
			size_t t_chunk = (size_t)t_number - t_offset;
			if (t_chunk > 65536)
				t_chunk = 65536;
			if (fwrite(t_bytes + t_offset, 1, t_chunk, stdout) != t_chunk)
				break;
			t_offset += t_chunk;
		}
		fflush(stdout);
		free(t_bytes);
		return t_offset == (size_t)t_number ? 0 : 3;
	}

	if (strcmp(t_mode, "sleep") == 0)
	{
		sleep_ms((unsigned int)t_number);
		return 0;
	}

	/* Close the input at once, and stay a while */
	if (strcmp(t_mode, "deaf") == 0)
	{
#if defined(_WIN32)
		_close(0);
#else
		close(0);
#endif
		sleep_ms((unsigned int)t_number);
		fputs("deaf", stdout);
		return 0;
	}

	/* Close both outputs, then put everything on the input into the file
	 * p_arguments[2] (or, with no file, read nothing and stay p_number
	 * milliseconds), and exit with 9 */
	if (strcmp(t_mode, "mute") == 0)
	{
#if defined(_WIN32)
		_close(1);
		_close(2);
#else
		close(1);
		close(2);
#endif
		if (p_count < 3)
		{
			sleep_ms((unsigned int)t_number);
			return 9;
		}

		FILE *t_file = fopen(p_arguments[2], "wb");
		if (t_file == nullptr)
			return 5;
		static char t_buffer[65536];
		for (;;)
		{
#if defined(_WIN32)
			int t_read = _read(0, t_buffer, sizeof(t_buffer));
#else
			ssize_t t_read = read(0, t_buffer, sizeof(t_buffer));
#endif
			if (t_read <= 0)
				break;
			fwrite(t_buffer, 1, (size_t)t_read, t_file);
		}
		fclose(t_file);
		return 9;
	}

	/* Start another of this program that sleeps, with this one's output,
	 * say so, and sleep too: two processes hold the pipe */
	if (strcmp(t_mode, "family") == 0)
	{
#if defined(_WIN32)
		char t_command[4096];
		snprintf(t_command, sizeof(t_command), "\"%s\" --child sleep %ld",
		         p_arguments[2], t_number);
		STARTUPINFOA t_startup;
		ZeroMemory(&t_startup, sizeof(t_startup));
		t_startup.cb = sizeof(t_startup);
		PROCESS_INFORMATION t_info;
		if (!CreateProcessA(nullptr, t_command, nullptr, nullptr, TRUE, 0,
		                    nullptr, nullptr, &t_startup, &t_info))
			return 4;
#else
		pid_t t_pid = fork();
		if (t_pid == 0)
		{
			execl(p_arguments[2], p_arguments[2], "--child", "sleep",
			      p_arguments[1], (char *)nullptr);
			_exit(4);
		}
#endif
		fputs("started", stdout);
		fflush(stdout);
		sleep_ms((unsigned int)t_number);
		return 0;
	}

#if !defined(_WIN32)
	/* End by a signal */
	if (strcmp(t_mode, "signal") == 0)
	{
		signal((int)t_number, SIG_DFL);
		kill(getpid(), (int)t_number);
		sleep_ms(5000);
		return 0;
	}

	/* Whether descriptor p_number is open here */
	if (strcmp(t_mode, "has-fd") == 0)
	{
		fputs(fcntl((int)t_number, F_GETFD) >= 0 ? "open" : "closed", stdout);
		return 0;
	}

	/* The group this process is in, against its own number */
	if (strcmp(t_mode, "group") == 0)
	{
		fputs(getpgrp() == getpid() ? "leads" : "follows", stdout);
		return 0;
	}
#endif

#if defined(__APPLE__)
	/* Every value this process was given for OXT_ASYNC_REPEATED */
	if (strcmp(t_mode, "repeated") == 0)
	{
		char **t_environ = *_NSGetEnviron();
		for (int i = 0; t_environ[i] != nullptr; i++)
			if (strncmp(t_environ[i], "OXT_ASYNC_REPEATED=", 19) == 0)
				printf("[%s]", t_environ[i] + 19);
		return 0;
	}
#endif

	return 99;
}

/* Run this program as a process, in a mode */
static MCAsyncJobId start_child(const char *p_mode, const char *p_argument,
                                MCAsyncProcessOptions& x_options,
                                const char *p_path = nullptr)
{
#if defined(_WIN32)
	static char s_command[8192];
	snprintf(s_command, sizeof(s_command), "\"%s\" --child %s %s%s%s%s", s_self,
	         p_mode, p_argument, p_path != nullptr ? " \"" : "",
	         p_path != nullptr ? p_path : "", p_path != nullptr ? "\"" : "");
	x_options.command_line = s_command;
#else
	static const char *s_arguments[6];
	s_arguments[0] = s_self;
	s_arguments[1] = "--child";
	s_arguments[2] = p_mode;
	s_arguments[3] = p_argument;
	s_arguments[4] = p_path;
	s_arguments[5] = nullptr;
	x_options.arguments = s_arguments;
#endif
	return MCAsyncCoreStartProcess(x_options, nullptr);
}

static MCAsyncProcessOptions no_options(void)
{
	MCAsyncProcessOptions t_options;
	memset(&t_options, 0, sizeof(t_options));
	return t_options;
}

static void check_process(void)
{
	start_core();

	/* Gathered output and the exit code */
	MCAsyncProcessOptions t_options = no_options();
	MCAsyncJobId t_job = start_child("exit", "7", t_options);
	check(t_job != 0, "a process job starts", 0);
	check(MCAsyncCoreStatus(t_job) == kMCAsyncStatusRunning ||
	      MCAsyncCoreStatus(t_job) == kMCAsyncStatusFinished,
	      "it runs from the start", MCAsyncCoreStatus(t_job));
	Seen *t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->code == 7, "a process's exit code is its job's",
	      t_done != nullptr ? t_done->code : -1);
	check(t_done != nullptr && t_done->length == 0, "with no output, none", 0);

	t_options = no_options();
	t_options.merge_error = true;
	t_job = start_child("both", "0", t_options);
	t_done = wait_done(t_job, 30000);
	check(data_is(t_done, "out\nerr\n"),
	      "merged, the error output is with the output, in order",
	      t_done != nullptr ? (long long)t_done->length : -1);

	t_options = no_options();
	t_job = start_child("both", "0", t_options);
	t_done = wait_done(t_job, 30000);
	check(data_is(t_done, "out\nerr\n"),
	      "not merged, it is after the output", 0);

	/* Input given at the start, then closed */
	t_options = no_options();
	t_options.input = "from the start";
	t_options.input_length = 14;
	t_options.close_input = true;
	t_job = start_child("echo", "5", t_options);
	t_done = wait_done(t_job, 30000);
	check(data_is(t_done, "from the start14") && t_done->code == 5,
	      "input given at the start reaches the process, which then sees it end",
	      t_done != nullptr ? (long long)t_done->length : -1);
	check(count_done(t_job) == 1 && MCAsyncCoreStatus(t_job) == kMCAsyncStatusNone,
	      "a process job ends once", count_done(t_job));

	/* A conversation: written to, answered, written to again, closed */
	t_options = no_options();
	t_options.stream = true;
	t_job = start_child("echo", "0", t_options);
	check(MCAsyncCoreProcessWrite(t_job, "first", 5), "a running process takes input", 0);
	size_t t_length = 0;
	char *t_text = nullptr;
	unsigned long long t_until = now_ms() + 30000;
	for (;;)
	{
		drain();
		free(t_text);
		t_text = joined_data(t_job, 1, t_length);
		if (t_length >= 5 || now_ms() >= t_until)
			break;
		wait_for_wake(100);
	}
	check(t_length == 5 && memcmp(t_text, "first", 5) == 0,
	      "and its answer comes as it writes it, while it runs", (long long)t_length);
	check(find_done(t_job) == nullptr && MCAsyncCoreStatus(t_job) == kMCAsyncStatusRunning,
	      "it is still running", MCAsyncCoreStatus(t_job));
	check(MCAsyncCoreProcessWrite(t_job, " second", 7) &&
	      MCAsyncCoreProcessWrite(t_job, nullptr, 0),
	      "it takes more input", 0);
	check(MCAsyncCoreProcessCloseInput(t_job), "its input can be closed", 0);
	check(!MCAsyncCoreProcessWrite(t_job, "late", 4),
	      "after which it takes no more", 0);
	t_done = wait_done(t_job, 30000);
	free(t_text);
	t_text = joined_data(t_job, 1, t_length);
	check(t_length == 12 && memcmp(t_text, "first second", 12) == 0,
	      "all that was written before the close reached it", (long long)t_length);
	free(t_text);
	t_text = joined_data(t_job, 2, t_length);
	check(t_length == 2 && memcmp(t_text, "12", 2) == 0,
	      "its error output comes as stream 2", (long long)t_length);
	free(t_text);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->length == 0, "a streamed job's end has no output of its own", 0);
	Seen *t_last = s_seen_last;
	check(t_last == t_done, "and is the job's last event", 0);

	/* A program that is not there */
	forget_events();
	t_options = no_options();
#if defined(_WIN32)
	t_options.command_line = "\"C:\\no such folder\\no-such-program.exe\" x";
#else
	static const char *t_missing[] = {"/no-such-folder/no-such-program", "x", nullptr};
	t_options.arguments = t_missing;
#endif
	t_job = MCAsyncCoreStartProcess(t_options, nullptr);
	check(t_job != 0, "a program that is not there still makes a job", 0);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorSpawn && t_done->code != 0,
	      "which ends by saying that it could not be started",
	      t_done != nullptr ? t_done->error : -1);
	check(!MCAsyncCoreProcessWrite(t_job, "x", 1), "and takes no input", 0);

#if !defined(_WIN32)
	check(t_done != nullptr && t_done->code == ENOENT, "with the system's error",
	      t_done != nullptr ? t_done->code : 0);

	/* A program found in PATH, as a shell finds it; and the shell as the
	 * engine's shell() runs it: the command on its input */
	static const char *t_shell[] = {"sh", "-s", nullptr};
	t_options = no_options();
	t_options.arguments = t_shell;
	t_options.input = "echo to-out; echo to-err >&2; exit 3\n";
	t_options.input_length = strlen((const char *)t_options.input);
	t_options.close_input = true;
	t_options.merge_error = true;
	t_job = MCAsyncCoreStartProcess(t_options, nullptr);
	t_done = wait_done(t_job, 30000);
	check(data_is(t_done, "to-out\nto-err\n") && t_done->code == 3,
	      "a shell, found in PATH, runs the command given on its input",
	      t_done != nullptr ? t_done->code : -1);

	static const char *t_nowhere[] = {"oxt-no-such-program-anywhere", nullptr};
	t_options = no_options();
	t_options.arguments = t_nowhere;
	t_job = MCAsyncCoreStartProcess(t_options, nullptr);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorSpawn &&
	      t_done->code == ENOENT, "a program that is not in PATH is not started",
	      t_done != nullptr ? t_done->code : -1);

	/* A process that a signal ends has the code a shell would give */
	t_options = no_options();
	t_job = start_child("signal", "15", t_options);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->code == 128 + 15,
	      "a process ended by a signal has 128 + the signal as its code",
	      t_done != nullptr ? t_done->code : -1);

	/* The process leads a group, and gets none of the engine's files */
	t_options = no_options();
	t_job = start_child("group", "0", t_options);
	t_done = wait_done(t_job, 30000);
	check(data_is(t_done, "leads"), "a process leads a group of its own", 0);

	int t_inherited = open(path_in(0, "kept.txt"), O_RDONLY);
	int t_high = fcntl(t_inherited, F_DUPFD, 77);
	char t_number[16];
	snprintf(t_number, sizeof(t_number), "%d", t_high);
	t_options = no_options();
	t_job = start_child("has-fd", t_number, t_options);
	t_done = wait_done(t_job, 30000);
	check(data_is(t_done, "closed"),
	      "a file the engine has open is not open in the process", t_high);
	close(t_inherited);
	close(t_high);
#endif

#if defined(__APPLE__)
	/* On macOS a variable that the process has set can be in its
	 * environment twice, the new value first; the program is given the
	 * first only, as the engine's shell() gives it */
	{
		char **t_before = *_NSGetEnviron();
		size_t t_count = 0;
		while (t_before[t_count] != nullptr)
			t_count += 1;
		char **t_repeated =
				static_cast<char **>(malloc((t_count + 3) * sizeof(char *)));
		static char t_new[] = "OXT_ASYNC_REPEATED=new";
		static char t_old[] = "OXT_ASYNC_REPEATED=old";
		t_repeated[0] = t_new;
		for (size_t i = 0; i < t_count; i++)
			t_repeated[i + 1] = t_before[i];
		t_repeated[t_count + 1] = t_old;
		t_repeated[t_count + 2] = nullptr;
		*_NSGetEnviron() = t_repeated;

		t_options = no_options();
		t_job = start_child("repeated", nullptr, t_options);
		t_done = wait_done(t_job, 30000);
		check(data_is(t_done, "[new]"),
		      "a variable that is in the environment twice is given once, "
		      "with its first value",
		      t_done != nullptr ? (long long)t_done->length : -1);

		*_NSGetEnviron() = t_before;
		free(t_repeated);
	}
#endif

	check(stop_core(), "the threads end after the processes", 0);
}

/* Much output, and input a process does not take */
static void check_process_volume(void)
{
	start_core();

	const long t_size = 24 * 1024 * 1024;
	char *t_expected = pattern((size_t)t_size);
	char t_number[32];
	snprintf(t_number, sizeof(t_number), "%ld", t_size);

	MCAsyncProcessOptions t_options = no_options();
	MCAsyncJobId t_job = start_child("spam", t_number, t_options);
	Seen *t_done = wait_done(t_job, 120000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->code == 0 && t_done->length == (size_t)t_size &&
	      memcmp(t_done->data, t_expected, (size_t)t_size) == 0,
	      "24 MB of output is gathered whole",
	      t_done != nullptr ? (long long)t_done->length : -1);
	forget_events();

	/* Streamed and not drained: the process is made to wait, not read
	 * into memory without end; drained, it goes on, and none is lost */
	t_options = no_options();
	t_options.stream = true;
	t_job = start_child("spam", t_number, t_options);
	uint64_t t_given = 0, t_total = 0, t_given_later = 0;
	unsigned long long t_until = now_ms() + 60000;
	while (now_ms() < t_until)
	{
		MCAsyncCoreProgress(t_job, t_given, t_total);
		sleep_ms(300);
		MCAsyncCoreProgress(t_job, t_given_later, t_total);
		if (t_given_later == t_given && t_given > 0)
			break;
	}
	check(t_given > 0 && t_given < (uint64_t)t_size,
	      "output that is not drained stops being read", (long long)t_given);
	check(MCAsyncCoreStatus(t_job) == kMCAsyncStatusRunning,
	      "and the process waits", MCAsyncCoreStatus(t_job));
	t_done = wait_done(t_job, 120000);
	size_t t_length = 0;
	char *t_text = joined_data(t_job, 1, t_length);
	check(t_done != nullptr && t_length == (size_t)t_size &&
	      memcmp(t_text, t_expected, (size_t)t_size) == 0,
	      "drained, it goes on, and every byte comes in order", (long long)t_length);
	free(t_text);
	int t_events = 0;
	for (Seen *t_seen = s_seen_first; t_seen != nullptr; t_seen = t_seen->next)
		t_events++;
	check(t_events < 2000, "in events that were joined while they waited", t_events);
	forget_events();

	/* 6 MB in and out again */
	const size_t t_in_size = 6 * 1024 * 1024;
	t_options = no_options();
	t_options.input = t_expected;
	t_options.input_length = t_in_size;
	t_options.close_input = true;
	t_job = start_child("echo", "0", t_options);
	t_done = wait_done(t_job, 120000);
	check(t_done != nullptr && t_done->length == t_in_size + 7 &&
	      memcmp(t_done->data, t_expected, t_in_size) == 0 &&
	      memcmp(t_done->data + t_in_size, "6291456", 7) == 0,
	      "6 MB given as input comes back whole",
	      t_done != nullptr ? (long long)t_done->length : -1);
	forget_events();

	/* A process that closes its input: what is written to it is dropped,
	 * and the job ends as the process does */
	t_options = no_options();
	t_options.input = t_expected;
	t_options.input_length = t_in_size;
	t_job = start_child("deaf", "300", t_options);
	t_done = wait_done(t_job, 30000);
	check(data_is(t_done, "deaf") && t_done->error == kMCAsyncErrorNone,
	      "input that a process does not take does not hold its job up",
	      t_done != nullptr ? t_done->error : -1);

	/* A process that closes both its outputs and goes on reading (one
	 * whose output goes to a file is the same to the job): it is given what
	 * is written to it for as long as its input is open, and the job ends
	 * when it does */
	t_options = no_options();
	t_options.stream = true;
	t_job = start_child("mute", "0", t_options, path_in(1, "mute.txt"));
	sleep_ms(300);
	drain();
	check(MCAsyncCoreStatus(t_job) == kMCAsyncStatusRunning &&
	      find_done(t_job) == nullptr,
	      "a process that has closed both its outputs is still running",
	      MCAsyncCoreStatus(t_job));
	check(MCAsyncCoreProcessWrite(t_job, "kept ", 5),
	      "and still takes input", 0);
	sleep_ms(100);
	drain();
	check(MCAsyncCoreProcessWrite(t_job, "whole", 5) &&
	      MCAsyncCoreProcessCloseInput(t_job),
	      "until its input is closed", 0);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->code == 9, "its job ends when it does, with its exit code",
	      t_done != nullptr ? (long)t_done->code : -1);
	check(file_is(path_in(1, "mute.txt"), "kept whole", 10),
	      "and it was given all that was written to it", 0);

	/* The same process ending of its own accord, its input never closed
	 * and never read: its ending is seen though no pipe shows it */
	t_options = no_options();
	t_options.stream = true;
	unsigned long long t_mute_start = now_ms();
	t_job = start_child("mute", "400", t_options);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->code == 9 && now_ms() - t_mute_start < 10000,
	      "a process with no output open that ends by itself ends its job",
	      t_done != nullptr ? (long)t_done->code : -1);
	check(!MCAsyncCoreProcessWrite(t_job, "x", 1),
	      "after which it takes no input", 0);

	/* Twenty at once */
	forget_events();
	MCAsyncJobId t_jobs[20];
	char t_texts[20][32];
	for (int i = 0; i < 20; i++)
	{
		snprintf(t_texts[i], sizeof(t_texts[i]), "process %d", i);
		t_options = no_options();
		t_options.input = t_texts[i];
		t_options.input_length = strlen(t_texts[i]);
		t_options.close_input = true;
		t_options.merge_error = true;
		t_jobs[i] = start_child("echo", "0", t_options);
	}
	bool t_all = true;
	for (int i = 0; i < 20; i++)
	{
		t_done = wait_done(t_jobs[i], 60000);
		/* What the child writes: its input, and the input's length. (Not
		 * written with "%s" of t_texts[i]: the MinGW GCC of the Windows runner
		 * takes it for the whole table, and refuses the build for a buffer
		 * that could not hold that.) */
		char t_wanted[64];
		snprintf(t_wanted, sizeof(t_wanted), "process %d%d", i,
		         (int)strlen(t_texts[i]));
		if (!data_is(t_done, t_wanted))
			t_all = false;
	}
	check(t_all, "twenty processes at once each give their own output", 0);

	free(t_expected);
	check(stop_core(), "the threads end after the large outputs", 0);
}

static void check_process_cancel(void)
{
	start_core();

	MCAsyncProcessOptions t_options = no_options();
	MCAsyncJobId t_job = start_child("sleep", "60000", t_options);
	sleep_ms(200);
	unsigned long long t_before = now_ms();
	check(MCAsyncCoreCancel(t_job), "a running process is cancelled", 0);
	Seen *t_done = wait_done(t_job, 30000);
	unsigned long long t_took = now_ms() - t_before;
	check(t_done != nullptr && t_done->error == kMCAsyncErrorCancelled,
	      "its job ends as cancelled", t_done != nullptr ? t_done->error : -1);
	check(t_took < 5000, "at once, not when the process would have ended",
	      (long long)t_took);

	/* A process that started another, which holds the pipe too: both go */
	t_options = no_options();
	t_options.stream = true;
	t_job = start_child("family", "60000", t_options, s_self);
	size_t t_length = 0;
	unsigned long long t_until = now_ms() + 30000;
	for (;;)
	{
		drain();
		char *t_text = joined_data(t_job, 1, t_length);
		free(t_text);
		if (t_length >= 7 || now_ms() >= t_until)
			break;
		wait_for_wake(100);
	}
	check(t_length == 7, "(a process that started another is running)",
	      (long long)t_length);
	t_before = now_ms();
	MCAsyncCoreCancel(t_job);
	t_done = wait_done(t_job, 30000);
	t_took = now_ms() - t_before;
	check(t_done != nullptr && t_done->error == kMCAsyncErrorCancelled && t_took < 5000,
	      "cancelling it ends the job, though two processes held its pipe",
	      (long long)t_took);

	/* Cancelling twice, and cancelling while the output is not drained */
	t_options = no_options();
	t_options.stream = true;
	t_job = start_child("spam", "33554432", t_options);
	sleep_ms(500);
	MCAsyncCoreCancel(t_job);
	MCAsyncCoreCancel(t_job);
	t_done = wait_done(t_job, 30000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorCancelled &&
	      count_done(t_job) == 1,
	      "a process with output waiting is cancelled, once",
	      t_done != nullptr ? t_done->error : -1);

	/* Finalizing with processes running kills them and ends their threads */
	forget_events();
	for (int i = 0; i < 5; i++)
	{
		t_options = no_options();
		start_child("sleep", "60000", t_options);
	}
	t_options = no_options();
	t_options.stream = true;
	start_child("spam", "33554432", t_options);
	sleep_ms(200);
	t_before = now_ms();
	bool t_ended = MCAsyncCoreFinalize(20000);
	forget_events();
	t_took = now_ms() - t_before;
	check(t_ended, "finalizing with six processes running ends every thread", 0);
	check(t_took < 10000, "without waiting for the processes to end by themselves",
	      (long long)t_took);
}

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//
//  NATIVE CALLS AND WAKES
//

/* A thread of the check's own, as a native library has: not one of the
 * core's */
struct CheckThreadStart
{
	void (*function)(void *);
	void *argument;
};

#if defined(_WIN32)
typedef HANDLE CheckThread;

static DWORD WINAPI check_thread_main(LPVOID p_argument)
{
	CheckThreadStart *t_start = (CheckThreadStart *)p_argument;
	t_start->function(t_start->argument);
	free(t_start);
	return 0;
}
#else
typedef pthread_t CheckThread;

static void *check_thread_main(void *p_argument)
{
	CheckThreadStart *t_start = (CheckThreadStart *)p_argument;
	t_start->function(t_start->argument);
	free(t_start);
	return nullptr;
}
#endif

static CheckThread check_thread_start(void (*p_function)(void *), void *p_argument)
{
	CheckThreadStart *t_start =
			(CheckThreadStart *)malloc(sizeof(CheckThreadStart));
	t_start->function = p_function;
	t_start->argument = p_argument;
#if defined(_WIN32)
	return CreateThread(nullptr, 0, check_thread_main, t_start, 0, nullptr);
#else
	pthread_t t_thread;
	pthread_create(&t_thread, nullptr, check_thread_main, t_start);
	return t_thread;
#endif
}

static void check_thread_join(CheckThread p_thread)
{
#if defined(_WIN32)
	WaitForSingleObject(p_thread, INFINITE);
	CloseHandle(p_thread);
#else
	pthread_join(p_thread, nullptr);
#endif
}

static bool on_main_thread(void)
{
#if defined(_WIN32)
	return GetCurrentThreadId() == s_main_thread;
#else
	return pthread_equal(pthread_self(), s_main_thread) != 0;
#endif
}

/* What the check's native functions are called with */
struct CallState
{
	std::atomic<int> calls;
	std::atomic<int> on_main;
	std::atomic<int> entered;
	std::atomic<bool> release;
};

static void call_state_reset(CallState& x_state)
{
	x_state.calls.store(0);
	x_state.on_main.store(0);
	x_state.entered.store(0);
	x_state.release.store(false);
}

static void native_count(void *p_context)
{
	CallState *t_state = (CallState *)p_context;
	if (on_main_thread())
		t_state->on_main++;
	t_state->calls++;
}

/* Returns when it is let go */
static void native_block(void *p_context)
{
	CallState *t_state = (CallState *)p_context;
	t_state->entered++;
	while (!t_state->release.load())
		sleep_ms(1);
	t_state->calls++;
}

static bool wait_until_entered(CallState& p_state, int p_count, unsigned int p_ms)
{
	unsigned long long t_until = now_ms() + p_ms;
	while (p_state.entered.load() < p_count && now_ms() < t_until)
		sleep_ms(1);
	return p_state.entered.load() >= p_count;
}

static void check_native_calls(void)
{
	static CallState s_state;
	start_core();

	call_state_reset(s_state);
	int t_marker = 0;
	MCAsyncJobId t_call = MCAsyncCoreCall(native_count, &s_state, &t_marker);
	check(t_call != 0, "a native call is a job", 0);
	Seen *t_done = wait_done(t_call, 10000);
	check(t_done != nullptr && t_done->error == kMCAsyncErrorNone &&
	      t_done->context == &t_marker && t_done->length == 0,
	      "which ends when the function has returned", 0);
	check(s_state.calls == 1 && s_state.on_main == 0,
	      "the function was called once, on another thread", s_state.calls);
	check(MCAsyncCoreCall(nullptr, nullptr, nullptr) == 0,
	      "no function is no job", 0);

	/* Many: each is called, and each ends once */
	call_state_reset(s_state);
	forget_events();
	MCAsyncJobId t_calls[50];
	for (int i = 0; i < 50; i++)
		t_calls[i] = MCAsyncCoreCall(native_count, &s_state, nullptr);
	bool t_all = true;
	for (int i = 0; i < 50; i++)
		t_all = t_all && t_calls[i] != 0 &&
				wait_done(t_calls[i], 10000) != nullptr &&
				count_done(t_calls[i]) == 1;
	check(t_all && s_state.calls == 50, "fifty calls are each made and each end once",
	      s_state.calls);

	/* Calls that do not return: 4 are being made (the check's limit), the
	 * rest wait, and the file jobs go on beside them */
	call_state_reset(s_state);
	forget_events();
	MCAsyncJobId t_blocked[6];
	for (int i = 0; i < 6; i++)
		t_blocked[i] = MCAsyncCoreCall(native_block, &s_state, nullptr);
	check(wait_until_entered(s_state, 4, 10000), "four long calls are made at once",
	      s_state.entered);
	sleep_ms(50);
	check(s_state.entered == 4 &&
	      MCAsyncCoreStatus(t_blocked[5]) == kMCAsyncStatusQueued,
	      "and the rest wait for a thread", s_state.entered);

	MCAsyncJobId t_write = MCAsyncCoreWriteFile(path_in(0, "beside-calls.txt"),
	                                            "beside", 6, false, nullptr);
	check(wait_done(t_write, 10000) != nullptr &&
	      file_is(path_in(0, "beside-calls.txt"), "beside", 6),
	      "a file job is done while every call's thread is held", 0);

	check(MCAsyncCoreCancel(t_blocked[5]) && MCAsyncCoreCancel(t_blocked[0]),
	      "a call that waits and one that is being made are cancelled", 0);
	s_state.release.store(true);
	bool t_ended = true;
	for (int i = 0; i < 6; i++)
		t_ended = t_ended && wait_done(t_blocked[i], 10000) != nullptr;
	check(t_ended, "every call ends when the functions return", 0);
	check(find_done(t_blocked[5]) != nullptr &&
	      find_done(t_blocked[5])->error == kMCAsyncErrorCancelled &&
	      s_state.calls == 5,
	      "the one cancelled while it waited was never made", s_state.calls);
	check(find_done(t_blocked[0]) != nullptr &&
	      find_done(t_blocked[0])->error == kMCAsyncErrorNone,
	      "and the one being made was not interrupted", 0);

	/* A call still being made when the core is finalized: the wait gives up */
	call_state_reset(s_state);
	MCAsyncJobId t_stuck = MCAsyncCoreCall(native_block, &s_state, nullptr);
	check(t_stuck != 0 && wait_until_entered(s_state, 1, 10000),
	      "a call is being made", 0);
	bool t_all_ended = MCAsyncCoreFinalize(100);
	forget_events();
	check(!t_all_ended, "finalizing does not wait for a call that does not return", 0);
	s_state.release.store(true);
	unsigned long long t_until = now_ms() + 10000;
	while (s_state.calls.load() == 0 && now_ms() < t_until)
		sleep_ms(1);
	/* (its thread lets go of the core after the function returns) */
	sleep_ms(100);
	check(s_state.calls == 1, "which returns later, to a core that has gone", 0);

	/* Without threads the call is made where it is asked for */
	MCAsyncCoreSetThreadLimit(0);
	start_core();
	call_state_reset(s_state);
	MCAsyncJobId t_inline = MCAsyncCoreCall(native_count, &s_state, nullptr);
	check(t_inline != 0 && s_state.calls == 1 && s_state.on_main == 1,
	      "without threads the function is called before the call returns", 0);
	drain();
	check(find_done(t_inline) != nullptr &&
	      find_done(t_inline)->error == kMCAsyncErrorNone,
	      "and its end is given at the next drain", 0);
	check(stop_core(), "the core finalizes", 0);
	MCAsyncCoreSetThreadLimit(4);
}

/* The Wake events seen for a wake */
static int count_wakes(MCAsyncWakeId p_wake)
{
	int t_count = 0;
	for (Seen *t_seen = s_seen_first; t_seen != nullptr; t_seen = t_seen->next)
		if (t_seen->job == p_wake && t_seen->kind == kMCAsyncEventWake)
			t_count++;
	return t_count;
}

/* Wait for a wake's event, draining as the core wakes */
static bool wait_wake(MCAsyncWakeId p_wake, int p_count, unsigned int p_ms)
{
	unsigned long long t_until = now_ms() + p_ms;
	for (;;)
	{
		drain();
		if (count_wakes(p_wake) >= p_count)
			return true;
		unsigned long long t_now = now_ms();
		if (t_now >= t_until)
			return false;
		wait_for_wake((unsigned int)(t_until - t_now < 200 ? t_until - t_now
		                                                    : 200));
	}
}

struct Signaller
{
	MCAsyncWakeId wake;
	int times;
	/* Go on until told to stop instead */
	std::atomic<bool> *stop;
	std::atomic<int> *signals;
};

static void signaller_main(void *p_argument)
{
	Signaller *t_signaller = (Signaller *)p_argument;
	if (t_signaller->stop != nullptr)
	{
		while (!t_signaller->stop->load())
		{
			MCAsyncCoreWakeSignal(t_signaller->wake);
			if (t_signaller->signals != nullptr)
				(*t_signaller->signals)++;
		}
		return;
	}
	for (int i = 0; i < t_signaller->times; i++)
		MCAsyncCoreWakeSignal(t_signaller->wake);
}

static void check_wakes(void)
{
	start_core();

	int t_first_marker = 0, t_second_marker = 0;
	MCAsyncWakeId t_first = MCAsyncCoreWakeCreate(&t_first_marker);
	MCAsyncWakeId t_second = MCAsyncCoreWakeCreate(&t_second_marker);
	check(t_first != 0 && t_second != 0 && t_first != t_second,
	      "two wakes have two numbers", 0);
	drain();
	check(s_seen_count == 0, "a wake that was not signalled gives no event",
	      s_seen_count);

	/* From a thread that is not the core's */
	int t_wakes_before = s_wakes.load();
	Signaller t_once = {t_first, 1, nullptr, nullptr};
	check_thread_join(check_thread_start(signaller_main, &t_once));
	check(s_wakes > t_wakes_before,
	      "a wake signalled on another thread wakes the main thread", 0);
	check(wait_wake(t_first, 1, 10000), "and the drain gives its event", 0);
	Seen *t_event = s_seen_first;
	check(t_event != nullptr && t_event->kind == kMCAsyncEventWake &&
	      t_event->job == t_first && t_event->context == &t_first_marker &&
	      t_event->length == 0 && t_event->error == kMCAsyncErrorNone,
	      "with the wake's number and what it was made with", 0);
	check(count_wakes(t_second) == 0, "the other wake has none", 0);

	/* Many signals from many threads are one event */
	forget_events();
	Signaller t_many = {t_second, 1000, nullptr, nullptr};
	CheckThread t_threads[4];
	for (int i = 0; i < 4; i++)
		t_threads[i] = check_thread_start(signaller_main, &t_many);
	for (int i = 0; i < 4; i++)
		check_thread_join(t_threads[i]);
	drain();
	check(count_wakes(t_second) == 1 && s_seen_count == 1,
	      "four thousand signals before a drain are one event", count_wakes(t_second));
	drain();
	check(s_seen_count == 1, "which is given once", s_seen_count);
	MCAsyncCoreWakeSignal(t_second);
	drain();
	check(count_wakes(t_second) == 2, "a signal after the drain is another event",
	      count_wakes(t_second));

	/* Both at once, and on the main thread too */
	forget_events();
	MCAsyncCoreWakeSignal(t_first);
	MCAsyncCoreWakeSignal(t_second);
	drain();
	check(count_wakes(t_first) == 1 && count_wakes(t_second) == 1,
	      "each wake that was signalled has its own event", s_seen_count);

	/* Destroyed: its number names nothing */
	forget_events();
	MCAsyncCoreWakeSignal(t_first);
	check(MCAsyncCoreWakeDestroy(t_first), "a wake is destroyed", 0);
	drain();
	check(s_seen_count == 0, "and the signal it had is not given", s_seen_count);
	check(!MCAsyncCoreWakeDestroy(t_first), "it is destroyed once", 0);
	MCAsyncWakeId t_third = MCAsyncCoreWakeCreate(nullptr);
	check(t_third != 0 && t_third != t_first,
	      "the next wake has a number of its own", 0);
	MCAsyncCoreWakeSignal(t_first);
	MCAsyncCoreWakeSignal(0);
	MCAsyncCoreWakeSignal(0xffffffffu);
	MCAsyncCoreWakeSignal(t_third ^ 0x100);
	drain();
	check(s_seen_count == 0,
	      "signalling the old number, or none, or nonsense, does nothing",
	      s_seen_count);
	MCAsyncCoreWakeDestroy(t_third);
	MCAsyncCoreWakeDestroy(t_second);

	/* As many as there is room for */
	static MCAsyncWakeId s_all[300];
	int t_made = 0;
	for (int i = 0; i < 300; i++)
	{
		s_all[i] = MCAsyncCoreWakeCreate(nullptr);
		if (s_all[i] != 0)
			t_made++;
	}
	check(t_made == 256 && s_all[255] != 0 && s_all[256] == 0,
	      "there is room for 256 wakes, and no more", t_made);
	bool t_distinct = true;
	for (int i = 0; i < 256 && t_distinct; i++)
		for (int j = i + 1; j < 256 && t_distinct; j++)
			t_distinct = s_all[i] != s_all[j];
	check(t_distinct, "each with its own number", 0);
	forget_events();
	for (int i = 0; i < 256; i++)
		MCAsyncCoreWakeSignal(s_all[i]);
	drain();
	check(s_seen_count == 256, "all signalled, all are given", s_seen_count);
	for (int i = 0; i < 256; i++)
		MCAsyncCoreWakeDestroy(s_all[i]);
	MCAsyncWakeId t_after = MCAsyncCoreWakeCreate(nullptr);
	check(t_after != 0, "and when they are destroyed there is room again", 0);

	/* Threads that never stop signalling, while the wake is destroyed and
	 * the core finalized and started again under them */
	forget_events();
	std::atomic<bool> t_stop(false);
	std::atomic<int> t_signals(0);
	Signaller t_forever = {t_after, 0, &t_stop, &t_signals};
	for (int i = 0; i < 4; i++)
		t_threads[i] = check_thread_start(signaller_main, &t_forever);
	check(wait_wake(t_after, 3, 10000),
	      "a wake signalled without end gives event after event", count_wakes(t_after));
	check(stop_core(), "the core finalizes while threads signal its wake", 0);
	int t_signals_then = t_signals.load();
	unsigned long long t_until = now_ms() + 10000;
	while (t_signals.load() < t_signals_then + 1000 && now_ms() < t_until)
		sleep_ms(1);
	check(t_signals.load() >= t_signals_then + 1000,
	      "signals after that do nothing, and harm nothing", 0);

	start_core();
	MCAsyncWakeId t_new = MCAsyncCoreWakeCreate(nullptr);
	sleep_ms(20);
	drain();
	check(t_new != 0 && t_new != t_after && s_seen_count == 0,
	      "a new core's wake is not the old one, which still names nothing",
	      s_seen_count);
	MCAsyncCoreWakeSignal(t_new);
	check(wait_wake(t_new, 1, 10000), "and the new wake works", 0);
	t_stop.store(true);
	for (int i = 0; i < 4; i++)
		check_thread_join(t_threads[i]);
	check(stop_core(), "the core finalizes", 0);
	MCAsyncCoreWakeSignal(t_new);
	check(!MCAsyncCoreWakeDestroy(t_new),
	      "finalizing destroyed the wakes it had", 0);
}

struct Group
{
	const char *name;
	void (*run)(void);
};

static const Group kGroups[] =
{
	{"lifecycle", check_lifecycle},
	{"write-read", check_write_and_read},
	{"errors", check_file_errors},
	{"copy", check_copy},
	{"list", check_list},
	{"many", check_many},
	{"no-threads", check_without_threads},
	{"cancel", check_cancel},
	{"finalize", check_finalize_busy},
	{"process", check_process},
	{"process-volume", check_process_volume},
	{"process-cancel", check_process_cancel},
	{"native-calls", check_native_calls},
	{"wakes", check_wakes},
};

int main(int p_count, char **p_arguments)
{
	if (p_count >= 3 && strcmp(p_arguments[1], "--child") == 0)
		return child_main(p_count - 2, p_arguments + 2);

	if (p_count < 2)
	{
		fprintf(stderr, "usage: %s <folder to work in> [group]\n", p_arguments[0]);
		return 2;
	}

#if defined(_WIN32)
	s_wake_event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
	s_main_thread = GetCurrentThreadId();
	GetModuleFileNameA(nullptr, s_self, sizeof(s_self));
#else
	s_main_thread = pthread_self();
	snprintf(s_self, sizeof(s_self), "%s", p_arguments[0]);
	/* A process that has ended must not end this one when it is written to */
	signal(SIGPIPE, SIG_IGN);
#endif
	snprintf(s_folder, sizeof(s_folder), "%s", p_arguments[1]);

	bool t_any = false;
	for (size_t i = 0; i < sizeof(kGroups) / sizeof(kGroups[0]); i++)
	{
		if (p_count >= 3 && strcmp(p_arguments[2], kGroups[i].name) != 0)
			continue;
		t_any = true;
		printf("== %s\n", kGroups[i].name);
		fflush(stdout);
		kGroups[i].run();
		if (MCAsyncCoreIsInitialized())
			stop_core();
		forget_events();
	}
	if (!t_any)
	{
		fprintf(stderr, "no such group of checks: %s\n", p_arguments[2]);
		return 2;
	}

	printf("%d passed, %d failed\n", s_passes, s_failures);
	return s_failures == 0 ? 0 : 1;
}
