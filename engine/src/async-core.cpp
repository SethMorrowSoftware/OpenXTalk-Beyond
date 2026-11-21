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

/* Background jobs, the part that runs off the main thread: see async-core.h.
 *
 * How it is put together:
 *
 * - One Core holds everything, behind one lock. It is counted, and every
 *   thread holds a count, so that a thread the system has not let go of
 *   when the engine quits (a read from a share that stopped answering)
 *   finds the Core still there when it comes back, sees that it is shut
 *   down, and ends.
 * - A file job waits in a queue for one of a few threads, made as they are
 *   first needed. A process has a thread of its own, which waits on its
 *   pipes: it never blocks in a read or a write, so it can always be told
 *   to stop.
 * - A process is STARTED on the main thread, inside the call that asks for
 *   it. The engine starts its own processes there too (shell, open
 *   process), so no two starts overlap and neither hands the other's pipes
 *   to its child.
 * - What a job did is queued as events and the main thread is woken once
 *   for however many there are. A job's Done event is allocated when the
 *   job is made, so that the end of a job can always be told.
 *
 * Nothing here uses the C++ library's containers, threads or locks
 * (docs/development/C++-features.md); the engine's own values are out of
 * bounds too (async-core.h says why). */

#if defined(_WIN32)
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <process.h>
#include <stdio.h>
#include <wchar.h>
#define MCASYNC_WINDOWS 1
#else
#include <pthread.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <copyfile.h>
#if !TARGET_OS_IPHONE
#include <crt_externs.h>
#endif
#endif
#define MCASYNC_POSIX 1
#endif

#include <errno.h>
#include <stdlib.h>
#include <string.h>

#include <atomic>
#include <new>

#include "async-core.h"

/* A process can be run on the desktop systems. Android could (it has fork
 * and exec) but the engine runs none there, and neither does this. */
#if defined(MCASYNC_WINDOWS)
#define MCASYNC_PROCESSES 1
#elif defined(__EMSCRIPTEN__) || defined(__ANDROID__) || \
		(defined(__APPLE__) && TARGET_OS_IPHONE)
#define MCASYNC_PROCESSES 0
#else
#define MCASYNC_PROCESSES 1
#include <poll.h>
#include <sys/wait.h>
#endif

////////////////////////////////////////////////////////////////////////////////

/* How much is read or written between two looks at whether the job has been
 * cancelled, and between two updates of its progress */
static const size_t kMCAsyncFileChunk = 1024 * 1024;

/* The most that a job can give: what a Data value of the engine can hold */
static const uint64_t kMCAsyncDataLimit = 0xFFFFFFFEu;

#if MCASYNC_PROCESSES
/* How much is read from or written to a pipe at once */
static const size_t kMCAsyncPipeChunk = 64 * 1024;

/* Output read from a pipe joins the Data event before it in the queue (of
 * the same job and stream) up to this size, so that a main thread that is
 * busy finds a few large events, not thousands of small ones */
static const size_t kMCAsyncDataEventLimit = 256 * 1024;

/* A streaming process whose output is not being drained is no longer read
 * from above this many bytes waiting, so that its pipe fills and it waits
 * too, as it would for any slow reader */
static const size_t kMCAsyncHighWater = 8 * 1024 * 1024;

/* How long the output of a cancelled process is still read for. Killing
 * the process and those it started closes their ends of the pipes, but one
 * that left the group (a daemon) can hold an end open for ever. */
static const unsigned int kMCAsyncCancelGraceMs = 500;

/* How often a process that has closed both its outputs, and so has no pipe
 * to end when it does, is asked whether it has ended */
static const int kMCAsyncEndedPollMs = 200;
#endif

/* The size of the table of jobs (a power of two) */
static const unsigned int kMCAsyncTableSize = 256;

////////////////////////////////////////////////////////////////////////////////
//
//  LOCK, CONDITION, THREAD, CLOCK
//

namespace
{

class Lock
{
public:
#if defined(MCASYNC_WINDOWS)
	Lock() { InitializeCriticalSection(&m_section); }
	~Lock() { DeleteCriticalSection(&m_section); }
	void Enter() { EnterCriticalSection(&m_section); }
	void Leave() { LeaveCriticalSection(&m_section); }
	CRITICAL_SECTION m_section;
#else
	Lock() { pthread_mutex_init(&m_mutex, nullptr); }
	~Lock() { pthread_mutex_destroy(&m_mutex); }
	void Enter() { pthread_mutex_lock(&m_mutex); }
	void Leave() { pthread_mutex_unlock(&m_mutex); }
	pthread_mutex_t m_mutex;
#endif

private:
	Lock(const Lock&);
	Lock& operator=(const Lock&);
};

class Condition
{
public:
#if defined(MCASYNC_WINDOWS)
	Condition() { InitializeConditionVariable(&m_variable); }
	~Condition() {}
	void Wait(Lock& p_lock)
	{
		SleepConditionVariableCS(&m_variable, &p_lock.m_section, INFINITE);
	}
	void WaitFor(Lock& p_lock, unsigned int p_ms)
	{
		SleepConditionVariableCS(&m_variable, &p_lock.m_section, p_ms);
	}
	void Signal() { WakeConditionVariable(&m_variable); }
	void Broadcast() { WakeAllConditionVariable(&m_variable); }
	CONDITION_VARIABLE m_variable;
#else
	Condition() { pthread_cond_init(&m_condition, nullptr); }
	~Condition() { pthread_cond_destroy(&m_condition); }
	void Wait(Lock& p_lock)
	{
		pthread_cond_wait(&m_condition, &p_lock.m_mutex);
	}
	/* By the wall clock (macOS has no other for a condition): a wait can be
	 * cut short or drawn out when the clock is set, and every caller waits
	 * in a loop that asks its own question again */
	void WaitFor(Lock& p_lock, unsigned int p_ms)
	{
		struct timeval t_now;
		gettimeofday(&t_now, nullptr);
		struct timespec t_until;
		t_until.tv_sec = t_now.tv_sec + p_ms / 1000;
		t_until.tv_nsec = t_now.tv_usec * 1000 +
				(long)(p_ms % 1000) * 1000000;
		if (t_until.tv_nsec >= 1000000000)
		{
			t_until.tv_sec += 1;
			t_until.tv_nsec -= 1000000000;
		}
		pthread_cond_timedwait(&m_condition, &p_lock.m_mutex, &t_until);
	}
	void Signal() { pthread_cond_signal(&m_condition); }
	void Broadcast() { pthread_cond_broadcast(&m_condition); }
	pthread_cond_t m_condition;
#endif

private:
	Condition(const Condition&);
	Condition& operator=(const Condition&);
};

/* Milliseconds from a clock that only goes forward */
uint64_t
NowMs(void)
{
#if defined(MCASYNC_WINDOWS)
	return GetTickCount64();
#else
	struct timespec t_time;
	clock_gettime(CLOCK_MONOTONIC, &t_time);
	return (uint64_t)t_time.tv_sec * 1000 + t_time.tv_nsec / 1000000;
#endif
}

typedef void (*ThreadEntry)(void *);

struct ThreadStart
{
	ThreadEntry entry;
	void *argument;
	MCAsyncThreadCallback callback;
};

void
ThreadRun(ThreadStart *p_start)
{
	ThreadStart t_start = *p_start;
	free(p_start);

	if (t_start.callback != nullptr)
		t_start.callback(true);
	t_start.entry(t_start.argument);
	if (t_start.callback != nullptr)
		t_start.callback(false);
}

#if defined(MCASYNC_WINDOWS)
unsigned __stdcall
ThreadMain(void *p_start)
{
	ThreadRun(static_cast<ThreadStart *>(p_start));
	return 0;
}
#else
void *
ThreadMain(void *p_start)
{
	ThreadRun(static_cast<ThreadStart *>(p_start));
	return nullptr;
}
#endif

/* Start a thread that nothing joins: it ends when its entry returns. */
bool
ThreadCreate(ThreadEntry p_entry, void *p_argument,
             MCAsyncThreadCallback p_callback)
{
	ThreadStart *t_start =
			static_cast<ThreadStart *>(malloc(sizeof(ThreadStart)));
	if (t_start == nullptr)
		return false;
	t_start->entry = p_entry;
	t_start->argument = p_argument;
	t_start->callback = p_callback;

#if defined(MCASYNC_WINDOWS)
	uintptr_t t_thread = _beginthreadex(nullptr, 0, ThreadMain, t_start, 0,
	                                    nullptr);
	if (t_thread == 0)
	{
		free(t_start);
		return false;
	}
	CloseHandle(reinterpret_cast<HANDLE>(t_thread));
	return true;
#else
	pthread_attr_t t_attributes;
	if (pthread_attr_init(&t_attributes) != 0)
	{
		free(t_start);
		return false;
	}
	pthread_attr_setdetachstate(&t_attributes, PTHREAD_CREATE_DETACHED);

	/* The engine's signal handlers do things that only its main thread may
	 * (dsklnx.cpp, dskmac.cpp), and the system gives a signal to any thread
	 * that takes it: these threads take none. A thread starts with the mask
	 * of the one that made it, so the mask is set here for a moment, not in
	 * the thread, which would leave a gap. The signals of a fault in the
	 * thread itself stay, to reach the engine's crash handling as before. */
	sigset_t t_all, t_before;
	sigfillset(&t_all);
	sigdelset(&t_all, SIGSEGV);
	sigdelset(&t_all, SIGBUS);
	sigdelset(&t_all, SIGFPE);
	sigdelset(&t_all, SIGILL);
	sigdelset(&t_all, SIGABRT);
	sigdelset(&t_all, SIGTRAP);
	sigdelset(&t_all, SIGSYS);
	pthread_sigmask(SIG_BLOCK, &t_all, &t_before);

	pthread_t t_thread;
	int t_error = pthread_create(&t_thread, &t_attributes, ThreadMain,
	                             t_start);

	pthread_sigmask(SIG_SETMASK, &t_before, nullptr);
	pthread_attr_destroy(&t_attributes);

	if (t_error != 0)
	{
		free(t_start);
		return false;
	}
	return true;
#endif
}

////////////////////////////////////////////////////////////////////////////////
//
//  A BUFFER THAT GROWS
//

struct Buffer
{
	char *bytes;
	size_t length;
	size_t capacity;
};

void
BufferInit(Buffer& x_buffer)
{
	x_buffer.bytes = nullptr;
	x_buffer.length = 0;
	x_buffer.capacity = 0;
}

void
BufferFree(Buffer& x_buffer)
{
	free(x_buffer.bytes);
	BufferInit(x_buffer);
}

/* Make room for p_extra more bytes. False if there is no memory, or the
 * buffer would be more than a job can give. */
bool
BufferReserve(Buffer& x_buffer, size_t p_extra)
{
	if (p_extra > kMCAsyncDataLimit ||
	    x_buffer.length > kMCAsyncDataLimit - p_extra)
		return false;

	size_t t_needed = x_buffer.length + p_extra;
	if (t_needed <= x_buffer.capacity)
		return true;

	size_t t_capacity = x_buffer.capacity < 4096 ? 4096 : x_buffer.capacity;
	while (t_capacity < t_needed)
	{
		if (t_capacity > (size_t)-1 / 2)
		{
			t_capacity = t_needed;
			break;
		}
		t_capacity *= 2;
	}

	char *t_bytes = static_cast<char *>(realloc(x_buffer.bytes, t_capacity));
	if (t_bytes == nullptr)
	{
		/* Doubling asked for more than there is: ask for what is needed */
		t_capacity = t_needed;
		t_bytes = static_cast<char *>(realloc(x_buffer.bytes, t_capacity));
		if (t_bytes == nullptr)
			return false;
	}
	x_buffer.bytes = t_bytes;
	x_buffer.capacity = t_capacity;
	return true;
}

bool
BufferAppend(Buffer& x_buffer, const void *p_bytes, size_t p_length)
{
	if (p_length == 0)
		return true;
	if (!BufferReserve(x_buffer, p_length))
		return false;
	memcpy(x_buffer.bytes + x_buffer.length, p_bytes, p_length);
	x_buffer.length += p_length;
	return true;
}

/* Hand the buffer's bytes over, cut to their length (nullptr if empty) */
char *
BufferTake(Buffer& x_buffer, size_t& r_length)
{
	char *t_bytes = x_buffer.bytes;
	r_length = x_buffer.length;
	if (r_length == 0)
	{
		free(t_bytes);
		t_bytes = nullptr;
	}
	else if (x_buffer.capacity - r_length > r_length / 8)
	{
		char *t_cut = static_cast<char *>(realloc(t_bytes, r_length));
		if (t_cut != nullptr)
			t_bytes = t_cut;
	}
	BufferInit(x_buffer);
	return t_bytes;
}

////////////////////////////////////////////////////////////////////////////////
//
//  PATHS, AS THE SYSTEM TAKES THEM
//

#if defined(MCASYNC_WINDOWS)

typedef wchar_t PathChar;

/* UTF-8 to UTF-16 (nullptr if it is not UTF-8, or there is no memory) */
wchar_t *
WideFromUTF8(const char *p_string)
{
	int t_size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, p_string,
	                                 -1, nullptr, 0);
	if (t_size <= 0)
		return nullptr;
	wchar_t *t_wide =
			static_cast<wchar_t *>(malloc(sizeof(wchar_t) * (size_t)t_size));
	if (t_wide == nullptr)
		return nullptr;
	if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, p_string, -1,
	                        t_wide, t_size) <= 0)
	{
		free(t_wide);
		return nullptr;
	}
	return t_wide;
}

/* UTF-16 to UTF-8, appended to a buffer */
bool
BufferAppendWide(Buffer& x_buffer, const wchar_t *p_wide)
{
	int t_size = WideCharToMultiByte(CP_UTF8, 0, p_wide, -1, nullptr, 0,
	                                 nullptr, nullptr);
	if (t_size <= 0)
		return false;
	if (!BufferReserve(x_buffer, (size_t)t_size))
		return false;
	if (WideCharToMultiByte(CP_UTF8, 0, p_wide, -1,
	                        x_buffer.bytes + x_buffer.length, t_size,
	                        nullptr, nullptr) <= 0)
		return false;
	/* Without the NUL that was converted too */
	x_buffer.length += (size_t)t_size - 1;
	return true;
}

PathChar *
PathCopy(const char *p_path)
{
	return WideFromUTF8(p_path);
}

#else

typedef char PathChar;

char *
StringCopy(const char *p_string)
{
	size_t t_size = strlen(p_string) + 1;
	char *t_copy = static_cast<char *>(malloc(t_size));
	if (t_copy != nullptr)
		memcpy(t_copy, p_string, t_size);
	return t_copy;
}

PathChar *
PathCopy(const char *p_path)
{
	return StringCopy(p_path);
}

#endif

////////////////////////////////////////////////////////////////////////////////
//
//  THE CORE, ITS JOBS AND ITS EVENTS
//

enum JobKind
{
	kJobRead,
	kJobWrite,
	kJobCopy,
	kJobList,
	kJobProcess,
	kJobCall,
};

/* The threads that take jobs from a queue, in two pools: one for the file
 * jobs and one for the native calls, which may be long, so that neither
 * kind waits for a thread the other holds */
enum
{
	kPoolFiles = 0,
	kPoolCalls,
	kPoolCount,
};

struct QueuedEvent
{
	MCAsyncEvent event;
	QueuedEvent *next;
};

struct Process;

struct Job
{
	std::atomic<int> references;

	MCAsyncJobId id;
	JobKind kind;
	void *context;

	/* Set by the main thread, read by the job's thread */
	std::atomic<bool> cancelled;

	/* A file job's parameters, which only its thread reads once it is made */
	PathChar *path;
	PathChar *other_path;
	const void *bytes;
	size_t length;
	bool append;
	bool recursive;

	/* A native call's */
	MCAsyncNativeFunction function;
	void *function_context;

	Process *process;

	/* The pool whose queue the job waits in */
	unsigned int pool;

	/* The rest is the Core's, behind its lock */
	Job *table_next;
	Job *queue_next;
	MCAsyncStatus status;
	uint64_t done;
	uint64_t total;
	/* The job's Done event, from when the job is made until it ends */
	QueuedEvent *done_event;
};

/* Behind the Core's lock */
struct Pool
{
	Job *queue_first;
	Job *queue_last;
	/* How many jobs the queue holds */
	unsigned int queue_length;
	unsigned int threads;
	/* How many of the threads have taken a job and not yet finished it */
	unsigned int threads_busy;
	unsigned int thread_limit;
	/* The pool's threads wait here for a job */
	Condition work;
};

struct Core
{
	std::atomic<int> references;

	Lock lock;
	/* MCAsyncCoreFinalize waits here for the threads to end */
	Condition ended;

	/* Held while an append is written, so that each is whole in its file
	 * however long it is and however many are written at once. Taken
	 * before 'lock', never with it held. */
	Lock append_lock;

	bool shutdown;
	MCAsyncWakeCallback wake;
	void *wake_context;
	/* The wake has been called and the queue has not been drained since */
	bool wake_sent;
	MCAsyncThreadCallback thread_callback;

	Job *table[kMCAsyncTableSize];
	MCAsyncJobId last_id;

	Pool pools[kPoolCount];
	/* Every thread that has not ended: the pools' and the processes' */
	unsigned int threads;

	QueuedEvent *events_first;
	QueuedEvent *events_last;
};

/* The main thread's, and only its */
Core *s_core = nullptr;

#if defined(__EMSCRIPTEN__)
unsigned int s_thread_limits[kPoolCount] = {0, 0};
#else
unsigned int s_thread_limits[kPoolCount] = {4, 8};
#endif

void ProcessFree(Process *p_process);

void
CoreRelease(Core *p_core)
{
	if (p_core->references.fetch_sub(1) == 1)
		delete p_core;
}

Job *
JobCreate(JobKind p_kind, void *p_context)
{
	Job *t_job = new (std::nothrow) Job;
	if (t_job == nullptr)
		return nullptr;

	t_job->references.store(1);
	t_job->id = 0;
	t_job->kind = p_kind;
	t_job->context = p_context;
	t_job->cancelled.store(false);
	t_job->path = nullptr;
	t_job->other_path = nullptr;
	t_job->bytes = nullptr;
	t_job->length = 0;
	t_job->append = false;
	t_job->recursive = false;
	t_job->function = nullptr;
	t_job->function_context = nullptr;
	t_job->process = nullptr;
	t_job->pool = kPoolFiles;
	t_job->table_next = nullptr;
	t_job->queue_next = nullptr;
	t_job->status = kMCAsyncStatusNone;
	t_job->done = 0;
	t_job->total = 0;

	t_job->done_event =
			static_cast<QueuedEvent *>(calloc(1, sizeof(QueuedEvent)));
	if (t_job->done_event == nullptr)
	{
		delete t_job;
		return nullptr;
	}
	return t_job;
}

void
JobRelease(Job *p_job)
{
	if (p_job->references.fetch_sub(1) != 1)
		return;

	free(p_job->path);
	free(p_job->other_path);
	free(p_job->done_event);
	if (p_job->process != nullptr)
		ProcessFree(p_job->process);
	delete p_job;
}

/* With the lock held */
Job *
JobFind(Core *p_core, MCAsyncJobId p_id)
{
	if (p_id == 0)
		return nullptr;
	for (Job *t_job = p_core->table[p_id & (kMCAsyncTableSize - 1)];
	     t_job != nullptr; t_job = t_job->table_next)
	{
		if (t_job->id == p_id)
			return t_job;
	}
	return nullptr;
}

/* With the lock held: give the job its number and put it in the table,
 * which holds the count the job was made with */
void
JobRegister(Core *p_core, Job *p_job)
{
	do
	{
		p_core->last_id += 1;
	}
	while (p_core->last_id == 0 || JobFind(p_core, p_core->last_id) != nullptr);

	p_job->id = p_core->last_id;
	Job*& t_slot = p_core->table[p_job->id & (kMCAsyncTableSize - 1)];
	p_job->table_next = t_slot;
	t_slot = p_job;
}

/* With the lock held: take the job out of the table. The caller has the
 * table's count to release. */
void
JobUnregister(Core *p_core, Job *p_job)
{
	Job **t_link = &p_core->table[p_job->id & (kMCAsyncTableSize - 1)];
	while (*t_link != nullptr && *t_link != p_job)
		t_link = &(*t_link)->table_next;
	if (*t_link == p_job)
		*t_link = p_job->table_next;
	p_job->table_next = nullptr;
	p_job->status = kMCAsyncStatusNone;
}

/* With the lock held: wake the main thread, unless it has been woken and
 * has not drained since */
void
CoreWake(Core *p_core)
{
	if (!p_core->wake_sent && p_core->wake != nullptr)
	{
		p_core->wake_sent = true;
		p_core->wake(p_core->wake_context);
	}
}

/* With the lock held: queue an event and wake the main thread */
void
EventQueue(Core *p_core, QueuedEvent *p_event)
{
	p_event->next = nullptr;
	if (p_core->events_last != nullptr)
		p_core->events_last->next = p_event;
	else
		p_core->events_first = p_event;
	p_core->events_last = p_event;

	CoreWake(p_core);
}

/* End a job: queue its Done event. p_data is handed over. On any thread. */
void
JobFinish(Core *p_core, Job *p_job, MCAsyncError p_error, uint32_t p_code,
          char *p_data, size_t p_length)
{
	p_core->lock.Enter();

	QueuedEvent *t_event = p_job->done_event;
	p_job->done_event = nullptr;
	p_job->status = kMCAsyncStatusFinished;

	if (t_event == nullptr || p_core->shutdown)
	{
		/* Shut down: there is no one to tell */
		p_core->lock.Leave();
		free(t_event);
		free(p_data);
		return;
	}

	t_event->event.job = p_job->id;
	t_event->event.context = p_job->context;
	t_event->event.kind = kMCAsyncEventDone;
	t_event->event.stream = 0;
	t_event->event.data = p_data;
	t_event->event.length = p_length;
	t_event->event.error = p_error;
	t_event->event.code = p_code;
	EventQueue(p_core, t_event);

	p_core->lock.Leave();
}

void
JobSetProgress(Core *p_core, Job *p_job, uint64_t p_done, uint64_t p_total)
{
	p_core->lock.Enter();
	p_job->done = p_done;
	p_job->total = p_total;
	p_core->lock.Leave();
}

/* What a file job came to */
struct Outcome
{
	MCAsyncError error;
	uint32_t code;
	char *data;
	size_t length;
};

bool
OutcomeFail(Outcome& r_outcome, MCAsyncError p_error, uint32_t p_code)
{
	r_outcome.error = p_error;
	r_outcome.code = p_code;
	return false;
}

////////////////////////////////////////////////////////////////////////////////
//
//  FILE JOBS
//

/* One entry of a folder, for sorting */
struct ListEntry
{
	char *name;
	bool folder;
	/* A folder to list the entries of too (not a link to one) */
	bool enter;
};

struct ListEntries
{
	ListEntry *entries;
	size_t count;
	size_t capacity;
};

void
ListEntriesFree(ListEntries& x_list)
{
	for (size_t i = 0; i < x_list.count; i++)
		free(x_list.entries[i].name);
	free(x_list.entries);
	x_list.entries = nullptr;
	x_list.count = 0;
	x_list.capacity = 0;
}

/* Takes p_name, also when it fails */
bool
ListEntriesAdd(ListEntries& x_list, char *p_name, bool p_folder, bool p_enter)
{
	if (p_name == nullptr)
		return false;
	if (x_list.count == x_list.capacity)
	{
		size_t t_capacity = x_list.capacity == 0 ? 64 : x_list.capacity * 2;
		ListEntry *t_entries = static_cast<ListEntry *>(
				realloc(x_list.entries, t_capacity * sizeof(ListEntry)));
		if (t_entries == nullptr)
		{
			free(p_name);
			return false;
		}
		x_list.entries = t_entries;
		x_list.capacity = t_capacity;
	}
	x_list.entries[x_list.count].name = p_name;
	x_list.entries[x_list.count].folder = p_folder;
	x_list.entries[x_list.count].enter = p_enter;
	x_list.count += 1;
	return true;
}

int
ListEntryCompare(const void *p_left, const void *p_right)
{
	return strcmp(static_cast<const ListEntry *>(p_left)->name,
	              static_cast<const ListEntry *>(p_right)->name);
}

/* Folders inside folders are listed by a function that calls itself, this
 * deep at most: a deeper folder is listed and not entered */
static const unsigned int kMCAsyncListDepthLimit = 256;

struct ListState
{
	Core *core;
	Job *job;
	Buffer listing;
	uint64_t count;
};

/* Read the entries of one folder into r_entries, unsorted. False with the
 * system's error if the folder cannot be read. */
bool ListFolderRead(const PathChar *p_folder, ListEntries& r_entries,
                    uint32_t& r_code, bool& r_no_memory);

/* p_folder with p_name after it */
PathChar *ListFolderChild(const PathChar *p_folder, const char *p_name);

/* List p_folder, whose path from the folder asked for is p_prefix (empty,
 * or ending in '/'). Only the folder asked for (p_depth 0) fails the job
 * when it cannot be read: a folder inside it that cannot (no permission, or
 * gone since it was listed) is in the listing with nothing after it. */
bool
ListFolderWalk(ListState& x_state, const PathChar *p_folder,
               const char *p_prefix, unsigned int p_depth, Outcome& r_outcome)
{
	ListEntries t_entries = {nullptr, 0, 0};
	uint32_t t_code = 0;
	bool t_no_memory = false;
	if (!ListFolderRead(p_folder, t_entries, t_code, t_no_memory))
	{
		ListEntriesFree(t_entries);
		if (t_no_memory)
			return OutcomeFail(r_outcome, kMCAsyncErrorOutOfMemory, 0);
		if (p_depth == 0)
			return OutcomeFail(r_outcome, kMCAsyncErrorList, t_code);
		return true;
	}

	if (t_entries.count > 1)
		qsort(t_entries.entries, t_entries.count, sizeof(ListEntry),
		      ListEntryCompare);

	size_t t_prefix_length = strlen(p_prefix);
	bool t_success = true;
	for (size_t i = 0; t_success && i < t_entries.count; i++)
	{
		const ListEntry& t_entry = t_entries.entries[i];

		if (x_state.job->cancelled.load())
		{
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorCancelled, 0);
			break;
		}

		size_t t_name_length = strlen(t_entry.name);
		if (!BufferAppend(x_state.listing, p_prefix, t_prefix_length) ||
		    !BufferAppend(x_state.listing, t_entry.name, t_name_length) ||
		    !BufferAppend(x_state.listing, t_entry.folder ? "/\n" : "\n",
		                  t_entry.folder ? 2 : 1))
		{
			/* No memory, or a listing larger than a value can hold */
			t_success = OutcomeFail(r_outcome,
			                        x_state.listing.length > kMCAsyncDataLimit / 2
			                                ? kMCAsyncErrorTooLarge
			                                : kMCAsyncErrorOutOfMemory, 0);
			break;
		}

		x_state.count += 1;
		if ((x_state.count & 255) == 0)
			JobSetProgress(x_state.core, x_state.job, x_state.count, 0);

		if (!x_state.job->recursive || !t_entry.enter ||
		    p_depth + 1 >= kMCAsyncListDepthLimit)
			continue;

		PathChar *t_child = ListFolderChild(p_folder, t_entry.name);
		char *t_child_prefix = static_cast<char *>(
				malloc(t_prefix_length + t_name_length + 2));
		if (t_child == nullptr || t_child_prefix == nullptr)
		{
			free(t_child);
			free(t_child_prefix);
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorOutOfMemory, 0);
			break;
		}
		memcpy(t_child_prefix, p_prefix, t_prefix_length);
		memcpy(t_child_prefix + t_prefix_length, t_entry.name, t_name_length);
		t_child_prefix[t_prefix_length + t_name_length] = '/';
		t_child_prefix[t_prefix_length + t_name_length + 1] = '\0';

		t_success = ListFolderWalk(x_state, t_child, t_child_prefix,
		                           p_depth + 1, r_outcome);

		free(t_child);
		free(t_child_prefix);
	}

	ListEntriesFree(t_entries);
	return t_success;
}

void
RunListFolder(Core *p_core, Job *p_job, Outcome& r_outcome)
{
	ListState t_state;
	t_state.core = p_core;
	t_state.job = p_job;
	BufferInit(t_state.listing);
	t_state.count = 0;

	if (ListFolderWalk(t_state, p_job->path, "", 0, r_outcome))
	{
		JobSetProgress(p_core, p_job, t_state.count, 0);
		r_outcome.data = BufferTake(t_state.listing, r_outcome.length);
	}
	else
		BufferFree(t_state.listing);
}

#if defined(MCASYNC_POSIX)

/* A system call again while a signal interrupts it. (These threads take no
 * signal, but the file jobs also run on the main thread where there are no
 * threads.) */
#define MCASYNC_RETRY(m_result, m_call) \
	do { m_result = (m_call); } while (m_result < 0 && errno == EINTR)

#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif

void
CloseFile(int p_fd)
{
	if (p_fd >= 0)
		close(p_fd);
}

void
RunReadFile(Core *p_core, Job *p_job, Outcome& r_outcome)
{
	int t_fd;
	MCASYNC_RETRY(t_fd, open(p_job->path, O_RDONLY | O_CLOEXEC));
	if (t_fd < 0)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, (uint32_t)errno);
		return;
	}

	struct stat t_stat;
	if (fstat(t_fd, &t_stat) != 0)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, (uint32_t)errno);
		close(t_fd);
		return;
	}
	if (S_ISDIR(t_stat.st_mode))
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, EISDIR);
		close(t_fd);
		return;
	}

	/* What is not a plain file (a pipe, a device, a file of /proc) has no
	 * size to go by: it is read until it ends */
	uint64_t t_total = 0;
	if (S_ISREG(t_stat.st_mode) && t_stat.st_size > 0)
		t_total = (uint64_t)t_stat.st_size;
	if (t_total > kMCAsyncDataLimit)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorTooLarge, 0);
		close(t_fd);
		return;
	}
	JobSetProgress(p_core, p_job, 0, t_total);

	Buffer t_buffer;
	BufferInit(t_buffer);

	bool t_success = true;
	/* One byte more than the size, so that the read that finds the end of
	 * the file does not make the buffer grow */
	if (!BufferReserve(t_buffer, t_total > 0 ? (size_t)t_total + 1 : 65536))
		t_success = OutcomeFail(r_outcome, kMCAsyncErrorOutOfMemory, 0);

	while (t_success)
	{
		if (p_job->cancelled.load())
		{
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorCancelled, 0);
			break;
		}

		if (t_buffer.length == t_buffer.capacity &&
		    !BufferReserve(t_buffer, 65536))
		{
			t_success = OutcomeFail(r_outcome,
			                        t_buffer.length >= kMCAsyncDataLimit - 65536
			                                ? kMCAsyncErrorTooLarge
			                                : kMCAsyncErrorOutOfMemory, 0);
			break;
		}

		size_t t_want = t_buffer.capacity - t_buffer.length;
		if (t_want > kMCAsyncFileChunk)
			t_want = kMCAsyncFileChunk;

		ssize_t t_read;
		MCASYNC_RETRY(t_read, read(t_fd, t_buffer.bytes + t_buffer.length,
		                           t_want));
		if (t_read < 0)
		{
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorRead,
			                        (uint32_t)errno);
			break;
		}
		if (t_read == 0)
			break;

		t_buffer.length += (size_t)t_read;
		JobSetProgress(p_core, p_job, t_buffer.length, t_total);
	}

	close(t_fd);

	if (t_success)
		r_outcome.data = BufferTake(t_buffer, r_outcome.length);
	else
		BufferFree(t_buffer);
}

/* Write all of p_bytes, a chunk at a time. False with the outcome set if
 * the job is cancelled or a write fails. */
bool
WriteAll(Core *p_core, Job *p_job, int p_fd, const char *p_bytes,
         size_t p_length, uint64_t p_done_before, uint64_t p_total,
         Outcome& r_outcome)
{
	size_t t_offset = 0;
	while (t_offset < p_length)
	{
		if (p_job->cancelled.load())
			return OutcomeFail(r_outcome, kMCAsyncErrorCancelled, 0);

		size_t t_want = p_length - t_offset;
		if (t_want > kMCAsyncFileChunk)
			t_want = kMCAsyncFileChunk;

		ssize_t t_written;
		MCASYNC_RETRY(t_written, write(p_fd, p_bytes + t_offset, t_want));
		if (t_written < 0)
			return OutcomeFail(r_outcome, kMCAsyncErrorWrite,
			                   (uint32_t)errno);

		t_offset += (size_t)t_written;
		JobSetProgress(p_core, p_job, p_done_before + t_offset, p_total);
	}
	return true;
}

void
RunWriteFile(Core *p_core, Job *p_job, Outcome& r_outcome)
{
	JobSetProgress(p_core, p_job, 0, p_job->length);

	/* As the engine makes a file: for all to read and write, less what the
	 * process's mask takes away */
	int t_fd;
	MCASYNC_RETRY(t_fd, open(p_job->path,
	                         O_WRONLY | O_CREAT | O_CLOEXEC |
	                                 (p_job->append ? O_APPEND : O_TRUNC),
	                         0666));
	if (t_fd < 0)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, (uint32_t)errno);
		return;
	}

	bool t_success = WriteAll(p_core, p_job, t_fd,
	                          static_cast<const char *>(p_job->bytes),
	                          p_job->length, 0, p_job->length, r_outcome);

	/* A file on a network can refuse what was written only when it is
	 * closed */
	if (close(t_fd) != 0 && errno != EINTR && t_success)
		OutcomeFail(r_outcome, kMCAsyncErrorWrite, (uint32_t)errno);
}

void
RunCopyFile(Core *p_core, Job *p_job, Outcome& r_outcome)
{
	int t_in;
	MCASYNC_RETRY(t_in, open(p_job->path, O_RDONLY | O_CLOEXEC));
	if (t_in < 0)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, (uint32_t)errno);
		return;
	}

	struct stat t_stat;
	if (fstat(t_in, &t_stat) != 0)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, (uint32_t)errno);
		close(t_in);
		return;
	}
	if (S_ISDIR(t_stat.st_mode))
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, EISDIR);
		close(t_in);
		return;
	}

	/* A file copied onto itself would be emptied by opening it to write */
	struct stat t_to_stat;
	if (stat(p_job->other_path, &t_to_stat) == 0 &&
	    t_to_stat.st_dev == t_stat.st_dev && t_to_stat.st_ino == t_stat.st_ino)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, EEXIST);
		close(t_in);
		return;
	}

	uint64_t t_total = 0;
	if (S_ISREG(t_stat.st_mode) && t_stat.st_size > 0)
		t_total = (uint64_t)t_stat.st_size;
	JobSetProgress(p_core, p_job, 0, t_total);

	int t_out;
	MCASYNC_RETRY(t_out, open(p_job->other_path,
	                          O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC,
	                          t_stat.st_mode & 0777));
	if (t_out < 0)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, (uint32_t)errno);
		close(t_in);
		return;
	}

	bool t_success = true;
	char *t_chunk = static_cast<char *>(malloc(kMCAsyncFileChunk));
	if (t_chunk == nullptr)
		t_success = OutcomeFail(r_outcome, kMCAsyncErrorOutOfMemory, 0);

	uint64_t t_done = 0;
	while (t_success)
	{
		if (p_job->cancelled.load())
		{
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorCancelled, 0);
			break;
		}

		ssize_t t_read;
		MCASYNC_RETRY(t_read, read(t_in, t_chunk, kMCAsyncFileChunk));
		if (t_read < 0)
		{
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorRead,
			                        (uint32_t)errno);
			break;
		}
		if (t_read == 0)
			break;

		t_success = WriteAll(p_core, p_job, t_out, t_chunk, (size_t)t_read,
		                     t_done, t_total, r_outcome);
		t_done += (uint64_t)t_read;
	}
	free(t_chunk);

	if (t_success)
	{
		/* The permissions (opening the file gave it them less the process's
		 * mask) and the times, as far as the system lets this user set
		 * them: a copy without them is still the copy that was asked for */
#if defined(__APPLE__)
		fcopyfile(t_in, t_out, nullptr, COPYFILE_METADATA);
#else
		fchmod(t_out, t_stat.st_mode & 07777);
		struct timespec t_times[2];
		t_times[0] = t_stat.st_atim;
		t_times[1] = t_stat.st_mtim;
		futimens(t_out, t_times);
#endif
	}

	close(t_in);
	if (close(t_out) != 0 && errno != EINTR && t_success)
		t_success = OutcomeFail(r_outcome, kMCAsyncErrorWrite,
		                        (uint32_t)errno);

	if (!t_success)
		unlink(p_job->other_path);
}

bool
ListFolderRead(const PathChar *p_folder, ListEntries& r_entries,
               uint32_t& r_code, bool& r_no_memory)
{
	DIR *t_dir = opendir(p_folder);
	if (t_dir == nullptr)
	{
		r_code = (uint32_t)errno;
		return false;
	}

	bool t_success = true;
	for (;;)
	{
		errno = 0;
		struct dirent *t_entry = readdir(t_dir);
		if (t_entry == nullptr)
		{
			if (errno != 0)
			{
				r_code = (uint32_t)errno;
				t_success = false;
			}
			break;
		}

		const char *t_name = t_entry->d_name;
		if (strcmp(t_name, ".") == 0 || strcmp(t_name, "..") == 0)
			continue;
		/* A listing has one entry to a line */
		if (strchr(t_name, '\n') != nullptr)
			continue;

		/* A link to a folder is a folder (as 'the folders' has it) that is
		 * not entered: links can make a loop */
		bool t_folder = false;
		bool t_enter = false;
		struct stat t_stat;
		if (fstatat(dirfd(t_dir), t_name, &t_stat, AT_SYMLINK_NOFOLLOW) == 0)
		{
			if (S_ISDIR(t_stat.st_mode))
				t_folder = t_enter = true;
			else if (S_ISLNK(t_stat.st_mode) &&
			         fstatat(dirfd(t_dir), t_name, &t_stat, 0) == 0 &&
			         S_ISDIR(t_stat.st_mode))
				t_folder = true;
		}

		if (!ListEntriesAdd(r_entries, StringCopy(t_name), t_folder, t_enter))
		{
			r_no_memory = true;
			t_success = false;
			break;
		}
	}

	closedir(t_dir);
	return t_success;
}

PathChar *
ListFolderChild(const PathChar *p_folder, const char *p_name)
{
	size_t t_folder_length = strlen(p_folder);
	size_t t_name_length = strlen(p_name);
	char *t_child = static_cast<char *>(
			malloc(t_folder_length + t_name_length + 2));
	if (t_child == nullptr)
		return nullptr;
	memcpy(t_child, p_folder, t_folder_length);
	/* "/" itself, or a path given with its '/' at the end, has one already */
	if (t_folder_length > 0 && p_folder[t_folder_length - 1] != '/')
		t_child[t_folder_length++] = '/';
	memcpy(t_child + t_folder_length, p_name, t_name_length + 1);
	return t_child;
}

#else  // MCASYNC_WINDOWS

void
RunReadFile(Core *p_core, Job *p_job, Outcome& r_outcome)
{
	HANDLE t_file = CreateFileW(
			p_job->path, GENERIC_READ,
			FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
			OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
			nullptr);
	if (t_file == INVALID_HANDLE_VALUE)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, GetLastError());
		return;
	}

	uint64_t t_total = 0;
	LARGE_INTEGER t_size;
	if (GetFileType(t_file) == FILE_TYPE_DISK && GetFileSizeEx(t_file, &t_size))
		t_total = (uint64_t)t_size.QuadPart;
	if (t_total > kMCAsyncDataLimit)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorTooLarge, 0);
		CloseHandle(t_file);
		return;
	}
	JobSetProgress(p_core, p_job, 0, t_total);

	Buffer t_buffer;
	BufferInit(t_buffer);

	bool t_success = true;
	if (!BufferReserve(t_buffer, t_total > 0 ? (size_t)t_total + 1 : 65536))
		t_success = OutcomeFail(r_outcome, kMCAsyncErrorOutOfMemory, 0);

	while (t_success)
	{
		if (p_job->cancelled.load())
		{
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorCancelled, 0);
			break;
		}

		if (t_buffer.length == t_buffer.capacity &&
		    !BufferReserve(t_buffer, 65536))
		{
			t_success = OutcomeFail(r_outcome,
			                        t_buffer.length >= kMCAsyncDataLimit - 65536
			                                ? kMCAsyncErrorTooLarge
			                                : kMCAsyncErrorOutOfMemory, 0);
			break;
		}

		size_t t_want = t_buffer.capacity - t_buffer.length;
		if (t_want > kMCAsyncFileChunk)
			t_want = kMCAsyncFileChunk;

		DWORD t_read = 0;
		if (!ReadFile(t_file, t_buffer.bytes + t_buffer.length, (DWORD)t_want,
		              &t_read, nullptr))
		{
			DWORD t_error = GetLastError();
			/* A pipe ends this way */
			if (t_error == ERROR_BROKEN_PIPE || t_error == ERROR_HANDLE_EOF)
				break;
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorRead, t_error);
			break;
		}
		if (t_read == 0)
			break;

		t_buffer.length += t_read;
		JobSetProgress(p_core, p_job, t_buffer.length, t_total);
	}

	CloseHandle(t_file);

	if (t_success)
		r_outcome.data = BufferTake(t_buffer, r_outcome.length);
	else
		BufferFree(t_buffer);
}

void
RunWriteFile(Core *p_core, Job *p_job, Outcome& r_outcome)
{
	JobSetProgress(p_core, p_job, 0, p_job->length);

	/* Shared as the engine's own files are (MCS_open): a file that a script
	 * has open, or that another append is being written to, can be opened */
	HANDLE t_file = CreateFileW(
			p_job->path, p_job->append ? FILE_APPEND_DATA : GENERIC_WRITE,
			FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
			p_job->append ? OPEN_ALWAYS : CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
			nullptr);
	if (t_file == INVALID_HANDLE_VALUE)
	{
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, GetLastError());
		return;
	}

	const char *t_bytes = static_cast<const char *>(p_job->bytes);
	size_t t_offset = 0;
	bool t_success = true;
	while (t_offset < p_job->length)
	{
		if (p_job->cancelled.load())
		{
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorCancelled, 0);
			break;
		}

		size_t t_want = p_job->length - t_offset;
		if (t_want > kMCAsyncFileChunk)
			t_want = kMCAsyncFileChunk;

		DWORD t_written = 0;
		if (!WriteFile(t_file, t_bytes + t_offset, (DWORD)t_want, &t_written,
		               nullptr))
		{
			t_success = OutcomeFail(r_outcome, kMCAsyncErrorWrite,
			                        GetLastError());
			break;
		}

		t_offset += t_written;
		JobSetProgress(p_core, p_job, t_offset, p_job->length);
	}

	if (!CloseHandle(t_file) && t_success)
		OutcomeFail(r_outcome, kMCAsyncErrorWrite, GetLastError());
}

struct CopyProgress
{
	Core *core;
	Job *job;
};

DWORD CALLBACK
CopyProgressRoutine(LARGE_INTEGER p_total, LARGE_INTEGER p_done,
                    LARGE_INTEGER, LARGE_INTEGER, DWORD, DWORD, HANDLE,
                    HANDLE, LPVOID p_context)
{
	CopyProgress *t_progress = static_cast<CopyProgress *>(p_context);
	JobSetProgress(t_progress->core, t_progress->job,
	               (uint64_t)p_done.QuadPart, (uint64_t)p_total.QuadPart);
	return t_progress->job->cancelled.load() ? PROGRESS_CANCEL
	                                         : PROGRESS_CONTINUE;
}

void
RunCopyFile(Core *p_core, Job *p_job, Outcome& r_outcome)
{
	if (p_job->cancelled.load())
	{
		OutcomeFail(r_outcome, kMCAsyncErrorCancelled, 0);
		return;
	}

	/* The system's own copy: it brings the times and attributes, tells how
	 * far it is, and removes what it wrote when it is told to stop */
	CopyProgress t_progress = {p_core, p_job};
	BOOL t_cancel = FALSE;
	if (CopyFileExW(p_job->path, p_job->other_path, CopyProgressRoutine,
	                &t_progress, &t_cancel, 0))
		return;

	DWORD t_error = GetLastError();
	if (t_error == ERROR_REQUEST_ABORTED || p_job->cancelled.load())
	{
		/* Wine's copy leaves what it wrote; Windows has removed it */
		DeleteFileW(p_job->other_path);
		OutcomeFail(r_outcome, kMCAsyncErrorCancelled, 0);
		return;
	}

	/* The system does not say which of the two files it was, or whether it
	 * was opening, reading or writing that failed: the errors of a file
	 * that is not there or may not be used are "can't open", the rest
	 * "can't write" */
	switch (t_error)
	{
	case ERROR_FILE_NOT_FOUND:
	case ERROR_PATH_NOT_FOUND:
	case ERROR_ACCESS_DENIED:
	case ERROR_SHARING_VIOLATION:
	case ERROR_INVALID_NAME:
	case ERROR_BAD_PATHNAME:
	case ERROR_BAD_NETPATH:
	case ERROR_INVALID_DRIVE:
	case ERROR_DIRECTORY:
		OutcomeFail(r_outcome, kMCAsyncErrorOpen, t_error);
		break;
	default:
		OutcomeFail(r_outcome, kMCAsyncErrorWrite, t_error);
		break;
	}
}

bool
ListFolderRead(const PathChar *p_folder, ListEntries& r_entries,
               uint32_t& r_code, bool& r_no_memory)
{
	/* The folder's path with "\*" after it */
	size_t t_length = wcslen(p_folder);
	wchar_t *t_pattern =
			static_cast<wchar_t *>(malloc(sizeof(wchar_t) * (t_length + 3)));
	if (t_pattern == nullptr)
	{
		r_no_memory = true;
		return false;
	}
	memcpy(t_pattern, p_folder, sizeof(wchar_t) * t_length);
	if (t_length > 0 && p_folder[t_length - 1] != L'\\' &&
	    p_folder[t_length - 1] != L'/' && p_folder[t_length - 1] != L':')
		t_pattern[t_length++] = L'\\';
	t_pattern[t_length++] = L'*';
	t_pattern[t_length] = L'\0';

	WIN32_FIND_DATAW t_data;
	HANDLE t_find = FindFirstFileExW(t_pattern, FindExInfoBasic, &t_data,
	                                 FindExSearchNameMatch, nullptr,
	                                 FIND_FIRST_EX_LARGE_FETCH);
	free(t_pattern);
	if (t_find == INVALID_HANDLE_VALUE)
	{
		r_code = GetLastError();
		/* The root of an empty drive has not even "." */
		return r_code == ERROR_FILE_NOT_FOUND;
	}

	bool t_success = true;
	do
	{
		if (wcscmp(t_data.cFileName, L".") == 0 ||
		    wcscmp(t_data.cFileName, L"..") == 0)
			continue;

		Buffer t_name;
		BufferInit(t_name);
		if (!BufferAppendWide(t_name, t_data.cFileName) ||
		    !BufferAppend(t_name, "", 1))
		{
			BufferFree(t_name);
			r_no_memory = true;
			t_success = false;
			break;
		}

		/* A junction or a link to a folder is a folder that is not entered */
		bool t_folder =
				(t_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
		bool t_enter = t_folder &&
				(t_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0;

		if (strchr(t_name.bytes, '\n') != nullptr)
		{
			BufferFree(t_name);
			continue;
		}

		if (!ListEntriesAdd(r_entries, t_name.bytes, t_folder, t_enter))
		{
			r_no_memory = true;
			t_success = false;
			break;
		}
	}
	while (FindNextFileW(t_find, &t_data));

	if (t_success && GetLastError() != ERROR_NO_MORE_FILES)
	{
		r_code = GetLastError();
		t_success = false;
	}

	FindClose(t_find);
	return t_success;
}

PathChar *
ListFolderChild(const PathChar *p_folder, const char *p_name)
{
	wchar_t *t_name = WideFromUTF8(p_name);
	if (t_name == nullptr)
		return nullptr;

	size_t t_folder_length = wcslen(p_folder);
	size_t t_name_length = wcslen(t_name);
	wchar_t *t_child = static_cast<wchar_t *>(
			malloc(sizeof(wchar_t) * (t_folder_length + t_name_length + 2)));
	if (t_child != nullptr)
	{
		memcpy(t_child, p_folder, sizeof(wchar_t) * t_folder_length);
		if (t_folder_length > 0 && p_folder[t_folder_length - 1] != L'\\' &&
		    p_folder[t_folder_length - 1] != L'/' &&
		    p_folder[t_folder_length - 1] != L':')
			t_child[t_folder_length++] = L'\\';
		memcpy(t_child + t_folder_length, t_name,
		       sizeof(wchar_t) * (t_name_length + 1));
	}
	free(t_name);
	return t_child;
}

#endif

/* Run a job of a pool to its end, on whatever thread */
void
RunQueuedJob(Core *p_core, Job *p_job)
{
	Outcome t_outcome = {kMCAsyncErrorNone, 0, nullptr, 0};

	/* Cancelled while it waited */
	if (p_job->cancelled.load())
		t_outcome.error = kMCAsyncErrorCancelled;
	else
	{
		switch (p_job->kind)
		{
		case kJobRead:
			RunReadFile(p_core, p_job, t_outcome);
			break;
		case kJobWrite:
			if (p_job->append)
				p_core->append_lock.Enter();
			RunWriteFile(p_core, p_job, t_outcome);
			if (p_job->append)
				p_core->append_lock.Leave();
			break;
		case kJobCopy:
			RunCopyFile(p_core, p_job, t_outcome);
			break;
		case kJobList:
			RunListFolder(p_core, p_job, t_outcome);
			break;
		case kJobCall:
			p_job->function(p_job->function_context);
			break;
		case kJobProcess:
			break;
		}
	}

	JobFinish(p_core, p_job, t_outcome.error, t_outcome.code, t_outcome.data,
	          t_outcome.length);
}

/* With the lock held: the next job that waits in a pool, or nullptr */
Job *
QueuePop(Pool *p_pool)
{
	Job *t_job = p_pool->queue_first;
	if (t_job == nullptr)
		return nullptr;
	p_pool->queue_first = t_job->queue_next;
	if (p_pool->queue_first == nullptr)
		p_pool->queue_last = nullptr;
	p_pool->queue_length -= 1;
	t_job->queue_next = nullptr;
	return t_job;
}

/* With the lock held: a thread is ending */
void
ThreadEnded(Core *p_core)
{
	p_core->threads -= 1;
	p_core->ended.Broadcast();
}

/* What a pool's thread is started with: the thread frees it */
struct PoolThreadStart
{
	Core *core;
	Pool *pool;
};

void
PoolThread(void *p_argument)
{
	PoolThreadStart *t_start = static_cast<PoolThreadStart *>(p_argument);
	Core *t_core = t_start->core;
	Pool *t_pool = t_start->pool;
	free(t_start);

	t_core->lock.Enter();
	for (;;)
	{
		while (!t_core->shutdown && t_pool->queue_first == nullptr)
			t_pool->work.Wait(t_core->lock);
		if (t_core->shutdown)
			break;

		Job *t_job = QueuePop(t_pool);
		t_job->status = kMCAsyncStatusRunning;
		t_pool->threads_busy += 1;
		t_core->lock.Leave();

		RunQueuedJob(t_core, t_job);
		JobRelease(t_job);

		t_core->lock.Enter();
		t_pool->threads_busy -= 1;
	}
	t_pool->threads -= 1;
	ThreadEnded(t_core);
	t_core->lock.Leave();

	CoreRelease(t_core);
}

/* Put a new job in the table and in its pool's queue, and see that a
 * thread will take it; without threads, run it here. Takes the job. */
MCAsyncJobId
QueuedJobStart(Job *p_job, unsigned int p_pool)
{
	Core *t_core = s_core;
	Pool *t_pool = &t_core->pools[p_pool];

	/* Before the lock: a thread is given this, and frees it */
	PoolThreadStart *t_start = static_cast<PoolThreadStart *>(
			malloc(sizeof(PoolThreadStart)));

	t_core->lock.Enter();

	JobRegister(t_core, p_job);
	MCAsyncJobId t_id = p_job->id;
	p_job->status = kMCAsyncStatusQueued;
	p_job->pool = p_pool;

	/* The queue's count, which the thread that runs the job releases */
	p_job->references.fetch_add(1);
	if (t_pool->queue_last != nullptr)
		t_pool->queue_last->queue_next = p_job;
	else
		t_pool->queue_first = p_job;
	t_pool->queue_last = p_job;
	t_pool->queue_length += 1;

	/* A thread for the job, when every thread there is has a job to take
	 * or to finish. (To ask instead whether a thread is waiting would count
	 * one thread for every job queued before it has woken: six jobs asked
	 * for together were then run one after another.) */
	if (t_start != nullptr &&
	    t_pool->queue_length > t_pool->threads - t_pool->threads_busy &&
	    t_pool->threads < t_pool->thread_limit)
	{
		t_start->core = t_core;
		t_start->pool = t_pool;
		t_core->references.fetch_add(1);
		if (ThreadCreate(PoolThread, t_start, t_core->thread_callback))
		{
			t_pool->threads += 1;
			t_core->threads += 1;
			t_start = nullptr;
		}
		else
			t_core->references.fetch_sub(1);
	}

	bool t_here = t_pool->threads == 0;
	if (!t_here)
		t_pool->work.Signal();

	t_core->lock.Leave();

	free(t_start);

	while (t_here)
	{
		t_core->lock.Enter();
		Job *t_job = QueuePop(t_pool);
		if (t_job != nullptr)
			t_job->status = kMCAsyncStatusRunning;
		t_core->lock.Leave();
		if (t_job == nullptr)
			break;

		RunQueuedJob(t_core, t_job);
		JobRelease(t_job);
	}

	return t_id;
}

////////////////////////////////////////////////////////////////////////////////
//
//  WAKES
//

/* The wakes are not the core's. A thread of some library may signal one at
 * any time, when there may be no core to ask, so they are in a table that
 * is never freed, behind a lock that is never destroyed (it is made with
 * the first core, on the main thread). That lock is taken before the
 * core's, never after it. */

enum
{
	kWakeIndexBits = 8,
	kWakeLimit = 1 << kWakeIndexBits,
};

struct Wake
{
	/* 0 while the entry is free. The entry's index is in the low bits and
	 * the count of the wakes it has been in the rest, so that the number of
	 * a wake that was destroyed names no later one. */
	MCAsyncWakeId id;
	uint32_t uses;
	void *context;
	/* Signalled, with its event not yet given */
	bool signalled;
};

Wake s_wakes[kWakeLimit];
std::atomic<Lock *> s_wake_lock(nullptr);
/* Behind the wake lock: the core whose main thread the signals wake, and
 * how many wakes are signalled */
Core *s_wake_core = nullptr;
unsigned int s_wakes_signalled = 0;

/* With the wake lock held */
Wake *
WakeFind(MCAsyncWakeId p_id)
{
	if (p_id == 0)
		return nullptr;
	Wake *t_wake = &s_wakes[p_id & (kWakeLimit - 1)];
	return t_wake->id == p_id ? t_wake : nullptr;
}

////////////////////////////////////////////////////////////////////////////////
//
//  PROCESSES
//

#if MCASYNC_PROCESSES

struct Process
{
	bool stream;
	bool merge;

	/* Behind the Core's lock: what the main thread and the process's thread
	 * both use */

	/* Bytes for the process's input, from input_offset on */
	char *input;
	size_t input_length;
	size_t input_offset;
	size_t input_capacity;
	/* The input has not been closed (by us, or by the process) */
	bool input_open;
	/* Close it once what is queued has been written */
	bool close_input;
	/* The bytes of Data events not yet drained, and whether the thread has
	 * stopped reading because of them (MCAsyncCoreDrain wakes it) */
	size_t waiting;
	bool throttled;
	/* The process has been killed, or has ended and been collected: then
	 * its number may name another process, and nothing is sent to it */
	bool killed;
	bool collected;

#if defined(MCASYNC_WINDOWS)
	HANDLE process;
	/* The job object the process and those it starts are in (nullptr if
	 * the system would not put it in one), which is how all are killed */
	HANDLE job_object;
	/* Signalled to make the thread look at the above again; nullptr once
	 * the thread has ended */
	HANDLE wake_event;
	/* The thread's own */
	HANDLE in_pipe;
	HANDLE out_pipe;
	HANDLE err_pipe;
#else
	pid_t pid;
	/* A pipe written to make the thread look again; -1 once the thread has
	 * ended */
	int wake_write;
	/* The thread's own */
	int wake_read;
	int in_fd;
	int out_fd;
	int err_fd;
#endif
};

struct ProcessThreadStart
{
	Core *core;
	Job *job;
};

Process *
ProcessCreate(const MCAsyncProcessOptions& p_options)
{
	Process *t_process = static_cast<Process *>(calloc(1, sizeof(Process)));
	if (t_process == nullptr)
		return nullptr;

	t_process->stream = p_options.stream;
	t_process->merge = p_options.merge_error;
	t_process->input_open = true;
	t_process->close_input = p_options.close_input;

	if (p_options.input_length > 0)
	{
		t_process->input =
				static_cast<char *>(malloc(p_options.input_length));
		if (t_process->input == nullptr)
		{
			free(t_process);
			return nullptr;
		}
		memcpy(t_process->input, p_options.input, p_options.input_length);
		t_process->input_length = p_options.input_length;
		t_process->input_capacity = p_options.input_length;
	}

#if defined(MCASYNC_WINDOWS)
	t_process->in_pipe = INVALID_HANDLE_VALUE;
	t_process->out_pipe = INVALID_HANDLE_VALUE;
	t_process->err_pipe = INVALID_HANDLE_VALUE;
#else
	t_process->wake_write = -1;
	t_process->wake_read = -1;
	t_process->in_fd = -1;
	t_process->out_fd = -1;
	t_process->err_fd = -1;
#endif
	return t_process;
}

void
ProcessFree(Process *p_process)
{
	free(p_process->input);
	free(p_process);
}

/* With the lock held: make the process's thread look again */
void
ProcessWake(Process *p_process)
{
#if defined(MCASYNC_WINDOWS)
	if (p_process->wake_event != nullptr)
		SetEvent(p_process->wake_event);
#else
	if (p_process->wake_write >= 0)
	{
		/* A full pipe means that the thread has waking to do already */
		ssize_t t_written = write(p_process->wake_write, "", 1);
		(void)t_written;
	}
#endif
}

/* With the lock held: kill the process and those it started */
void
ProcessKill(Process *p_process)
{
	if (p_process->killed || p_process->collected)
		return;
	p_process->killed = true;

#if defined(MCASYNC_WINDOWS)
	if (p_process->job_object != nullptr)
		TerminateJobObject(p_process->job_object, 1);
	else if (p_process->process != nullptr)
		TerminateProcess(p_process->process, 1);
#else
	/* The process leads a group of its own, which those it started are in
	 * unless they left it */
	if (kill(-p_process->pid, SIGKILL) != 0)
		kill(p_process->pid, SIGKILL);
#endif
}

/* Queue output of the process as a Data event. It joins the event before
 * it in the queue where that is of the same job and stream and not yet
 * large. False if there is no memory. On the process's thread. */
bool
ProcessPostData(Core *p_core, Job *p_job, int p_stream, const char *p_bytes,
                size_t p_length)
{
	Process *t_process = p_job->process;

	p_core->lock.Enter();
	if (p_core->shutdown)
	{
		p_core->lock.Leave();
		return true;
	}
	QueuedEvent *t_last = p_core->events_last;
	if (t_last != nullptr && t_last->event.kind == kMCAsyncEventData &&
	    t_last->event.job == p_job->id && t_last->event.stream == p_stream &&
	    t_last->event.length + p_length <= kMCAsyncDataEventLimit)
	{
		char *t_grown = static_cast<char *>(
				realloc(t_last->event.data, t_last->event.length + p_length));
		if (t_grown != nullptr)
		{
			memcpy(t_grown + t_last->event.length, p_bytes, p_length);
			t_last->event.data = t_grown;
			t_last->event.length += p_length;
			t_process->waiting += p_length;
			p_core->lock.Leave();
			return true;
		}
	}
	p_core->lock.Leave();

	QueuedEvent *t_event =
			static_cast<QueuedEvent *>(calloc(1, sizeof(QueuedEvent)));
	char *t_data = static_cast<char *>(malloc(p_length));
	if (t_event == nullptr || t_data == nullptr)
	{
		free(t_event);
		free(t_data);
		return false;
	}
	memcpy(t_data, p_bytes, p_length);

	t_event->event.job = p_job->id;
	t_event->event.context = p_job->context;
	t_event->event.kind = kMCAsyncEventData;
	t_event->event.stream = p_stream;
	t_event->event.data = t_data;
	t_event->event.length = p_length;

	p_core->lock.Enter();
	if (p_core->shutdown)
	{
		p_core->lock.Leave();
		free(t_data);
		free(t_event);
		return true;
	}
	t_process->waiting += p_length;
	EventQueue(p_core, t_event);
	p_core->lock.Leave();
	return true;
}

/* What the process's thread keeps of what the process wrote */
struct ProcessOutput
{
	Core *core;
	Job *job;
	/* Without 'stream': the output and the error output, gathered */
	Buffer gathered[2];
	uint64_t total;
	/* Set when there was no memory for output: the job fails */
	bool failed;
};

void
ProcessOutputTake(ProcessOutput& x_output, int p_stream, const char *p_bytes,
                  size_t p_length)
{
	if (x_output.failed || p_length == 0)
		return;

	x_output.total += p_length;
	JobSetProgress(x_output.core, x_output.job, x_output.total, 0);

	if (x_output.job->process->stream)
	{
		if (!ProcessPostData(x_output.core, x_output.job, p_stream, p_bytes,
		                     p_length))
			x_output.failed = true;
	}
	else if (!BufferAppend(x_output.gathered[p_stream - 1], p_bytes, p_length))
		x_output.failed = true;
}

/* The thread's part of the lock-held state, looked at once a turn */
struct ProcessTurn
{
	/* Bytes to write to the input, copied out of the queue */
	size_t write_length;
	/* The input is to be closed now */
	bool close_input;
	/* Do not read: too much output waits to be drained */
	bool throttled;
};

/* p_may_write: the thread is not in the middle of a write */
void
ProcessTurnBegin(Core *p_core, Process *p_process, bool p_may_write,
                 char *p_write_buffer, ProcessTurn& r_turn)
{
	p_core->lock.Enter();

	r_turn.write_length = 0;
	if (p_process->input_open && p_may_write &&
	    p_process->input_length > p_process->input_offset)
	{
		r_turn.write_length =
				p_process->input_length - p_process->input_offset;
		if (r_turn.write_length > kMCAsyncPipeChunk)
			r_turn.write_length = kMCAsyncPipeChunk;
		memcpy(p_write_buffer, p_process->input + p_process->input_offset,
		       r_turn.write_length);
	}

	r_turn.close_input = p_process->input_open && p_process->close_input &&
			p_may_write && r_turn.write_length == 0;

	r_turn.throttled = p_process->stream &&
			p_process->waiting > kMCAsyncHighWater;
	p_process->throttled = r_turn.throttled;

	p_core->lock.Leave();
}

/* p_written bytes of the queue's front reached the process */
void
ProcessInputWritten(Core *p_core, Process *p_process, size_t p_written)
{
	p_core->lock.Enter();
	p_process->input_offset += p_written;
	if (p_process->input_offset >= p_process->input_length)
	{
		p_process->input_offset = 0;
		p_process->input_length = 0;
	}
	p_core->lock.Leave();
}

/* The input is closed: nothing more is taken for it */
void
ProcessInputClosed(Core *p_core, Process *p_process)
{
	p_core->lock.Enter();
	p_process->input_open = false;
	p_process->input_offset = 0;
	p_process->input_length = 0;
	p_core->lock.Leave();
}

/* End the process's job, with what it wrote */
void
ProcessFinish(ProcessOutput& x_output, uint32_t p_exit_code)
{
	Job *t_job = x_output.job;

	char *t_data = nullptr;
	size_t t_length = 0;
	if (!x_output.failed && !t_job->process->stream)
	{
		/* The error output after the output */
		if (BufferAppend(x_output.gathered[0], x_output.gathered[1].bytes,
		                 x_output.gathered[1].length))
			t_data = BufferTake(x_output.gathered[0], t_length);
		else
			x_output.failed = true;
	}
	BufferFree(x_output.gathered[0]);
	BufferFree(x_output.gathered[1]);

	MCAsyncError t_error = kMCAsyncErrorNone;
	if (t_job->cancelled.load())
		t_error = kMCAsyncErrorCancelled;
	else if (x_output.failed)
		t_error = kMCAsyncErrorOutOfMemory;

	JobFinish(x_output.core, t_job, t_error, p_exit_code, t_data, t_length);
}

#if defined(MCASYNC_POSIX)

bool
SetCloseOnExec(int p_fd)
{
	int t_flags = fcntl(p_fd, F_GETFD);
	return t_flags >= 0 && fcntl(p_fd, F_SETFD, t_flags | FD_CLOEXEC) == 0;
}

bool
SetNonBlocking(int p_fd)
{
	int t_flags = fcntl(p_fd, F_GETFL);
	return t_flags >= 0 && fcntl(p_fd, F_SETFL, t_flags | O_NONBLOCK) == 0;
}

void
ClosePipe(int x_fds[2])
{
	for (int i = 0; i < 2; i++)
	{
		if (x_fds[i] >= 0)
			close(x_fds[i]);
		x_fds[i] = -1;
	}
}

/* A pipe that a program started later does not get, with neither end 0, 1
 * or 2 (which they could be, in an engine started with those closed, and
 * would then be lost when the child puts its own there) */
bool
MakePipe(int r_fds[2])
{
	if (pipe(r_fds) != 0)
	{
		r_fds[0] = r_fds[1] = -1;
		return false;
	}
	for (int i = 0; i < 2; i++)
	{
		if (r_fds[i] < 3)
		{
			int t_moved = fcntl(r_fds[i], F_DUPFD, 3);
			if (t_moved < 0)
			{
				ClosePipe(r_fds);
				return false;
			}
			close(r_fds[i]);
			r_fds[i] = t_moved;
		}
		if (!SetCloseOnExec(r_fds[i]))
		{
			ClosePipe(r_fds);
			return false;
		}
	}
	return true;
}

/* The path of the program to run: p_program itself if it has a '/' in it,
 * else the first file of that name in PATH that may be executed. nullptr
 * with errno set if there is none, or no memory. Worked out before the
 * fork, because the child may do very little (see ProcessSpawn). */
char *
ResolveProgram(const char *p_program)
{
	if (strchr(p_program, '/') != nullptr)
		return StringCopy(p_program);
	if (p_program[0] == '\0')
	{
		errno = ENOENT;
		return nullptr;
	}

	const char *t_path = getenv("PATH");
	if (t_path == nullptr || t_path[0] == '\0')
		t_path = "/usr/local/bin:/usr/bin:/bin";

	size_t t_program_length = strlen(p_program);
	char *t_candidate = static_cast<char *>(
			malloc(strlen(t_path) + t_program_length + 3));
	if (t_candidate == nullptr)
	{
		errno = ENOMEM;
		return nullptr;
	}

	for (const char *t_folder = t_path;;)
	{
		const char *t_end = strchr(t_folder, ':');
		size_t t_folder_length =
				t_end != nullptr ? (size_t)(t_end - t_folder) : strlen(t_folder);

		/* An empty entry is the current folder */
		if (t_folder_length == 0)
		{
			t_candidate[0] = '.';
			t_folder_length = 1;
		}
		else
			memcpy(t_candidate, t_folder, t_folder_length);
		t_candidate[t_folder_length] = '/';
		memcpy(t_candidate + t_folder_length + 1, p_program,
		       t_program_length + 1);

		struct stat t_stat;
		if (stat(t_candidate, &t_stat) == 0 && S_ISREG(t_stat.st_mode) &&
		    access(t_candidate, X_OK) == 0)
			return t_candidate;

		if (t_end == nullptr)
			break;
		t_folder = t_end + 1;
	}

	free(t_candidate);
	errno = ENOENT;
	return nullptr;
}

#if defined(__APPLE__)
/* The environment for the program: the list of this process with only the
 * first definition of each variable. On macOS a variable that the process
 * has set can be in the list twice, its new value first, and a program
 * given both takes the last: the value from before. The engine's shell()
 * passes on the list without the repeats for that reason (fix_environ in
 * dskmac.cpp), and so does this. The strings are those of the list itself;
 * the array is for free(). nullptr if there is no memory. */
char **
MakeEnvironment(void)
{
	char **t_environ = *_NSGetEnviron();
	size_t t_count = 0;
	while (t_environ != nullptr && t_environ[t_count] != nullptr)
		t_count += 1;

	char **t_list =
			static_cast<char **>(malloc((t_count + 1) * sizeof(char *)));
	if (t_list == nullptr)
		return nullptr;

	size_t t_kept = 0;
	for (size_t i = 0; i < t_count; i++)
	{
		const char *t_equals = strchr(t_environ[i], '=');
		size_t t_name_length = t_equals != nullptr
				? (size_t)(t_equals - t_environ[i]) + 1
				: strlen(t_environ[i]) + 1;

		bool t_repeat = false;
		for (size_t j = 0; j < t_kept && !t_repeat; j++)
			t_repeat = strncmp(t_list[j], t_environ[i], t_name_length) == 0;
		if (!t_repeat)
			t_list[t_kept++] = t_environ[i];
	}
	t_list[t_kept] = nullptr;
	return t_list;
}
#endif

/* The descriptors that are open now, other than 0, 1 and 2, for the child
 * to close: the engine's own files and sockets, which would otherwise stay
 * open in the program for as long as it runs. nullptr if the system does
 * not list them. */
int *
ListOpenFiles(size_t& r_count)
{
	r_count = 0;
#if defined(__linux__)
	DIR *t_dir = opendir("/proc/self/fd");
#else
	DIR *t_dir = opendir("/dev/fd");
#endif
	if (t_dir == nullptr)
		return nullptr;

	int *t_files = nullptr;
	size_t t_capacity = 0;
	for (;;)
	{
		struct dirent *t_entry = readdir(t_dir);
		if (t_entry == nullptr)
			break;

		char *t_end = nullptr;
		long t_fd = strtol(t_entry->d_name, &t_end, 10);
		if (t_end == t_entry->d_name || *t_end != '\0' || t_fd < 3 ||
		    t_fd == dirfd(t_dir))
			continue;

		if (r_count == t_capacity)
		{
			t_capacity = t_capacity == 0 ? 64 : t_capacity * 2;
			int *t_grown = static_cast<int *>(
					realloc(t_files, t_capacity * sizeof(int)));
			if (t_grown == nullptr)
			{
				free(t_files);
				closedir(t_dir);
				r_count = 0;
				return nullptr;
			}
			t_files = t_grown;
		}
		t_files[r_count++] = (int)t_fd;
	}
	closedir(t_dir);

	if (t_files == nullptr)
		t_files = static_cast<int *>(malloc(sizeof(int)));
	return t_files;
}

/* Start the program. On the main thread. True with the process's pipes in
 * x_process; false with the system's error. */
bool
ProcessSpawn(Process *x_process, const char *const *p_arguments,
             uint32_t& r_code)
{
	if (p_arguments == nullptr || p_arguments[0] == nullptr)
	{
		r_code = ENOENT;
		return false;
	}

	char *t_program = ResolveProgram(p_arguments[0]);
	if (t_program == nullptr)
	{
		r_code = (uint32_t)errno;
		return false;
	}

#if defined(__APPLE__)
	char **t_environment = MakeEnvironment();
	if (t_environment == nullptr)
	{
		free(t_program);
		r_code = ENOMEM;
		return false;
	}
#endif

	int t_in[2] = {-1, -1};
	int t_out[2] = {-1, -1};
	int t_err[2] = {-1, -1};
	/* The child writes its error here if it cannot run the program. The
	 * end closes by itself when it can, which is how this side knows. */
	int t_status[2] = {-1, -1};
	int t_wake[2] = {-1, -1};

	bool t_success =
			MakePipe(t_in) && MakePipe(t_out) &&
			(x_process->merge || MakePipe(t_err)) && MakePipe(t_status) &&
			MakePipe(t_wake) && SetNonBlocking(t_in[1]) &&
			SetNonBlocking(t_out[0]) &&
			(x_process->merge || SetNonBlocking(t_err[0])) &&
			SetNonBlocking(t_wake[0]) && SetNonBlocking(t_wake[1]);
	if (!t_success)
		r_code = (uint32_t)errno;

	size_t t_open_count = 0;
	int *t_open = nullptr;
	long t_open_limit = 0;
	if (t_success)
	{
		t_open = ListOpenFiles(t_open_count);
		if (t_open == nullptr)
		{
			t_open_limit = sysconf(_SC_OPEN_MAX);
			if (t_open_limit < 0 || t_open_limit > 65536)
				t_open_limit = 65536;
		}
	}

	pid_t t_pid = -1;
	if (t_success)
	{
		t_pid = fork();
		if (t_pid < 0)
		{
			r_code = (uint32_t)errno;
			t_success = false;
		}
	}

	if (t_success && t_pid == 0)
	{
		/* The child. The engine has other threads, and this is a copy of
		 * one of them alone: a lock another held (the allocator's) is held
		 * for ever here. So only system calls from here to the exec, and
		 * nothing that allocates. */

		/* A group of its own, so that it can be killed with all that it
		 * starts */
		setpgid(0, 0);

		sigset_t t_none;
		sigemptyset(&t_none);
		sigprocmask(SIG_SETMASK, &t_none, nullptr);

		int t_error_fd = x_process->merge ? t_out[1] : t_err[1];
		if (dup2(t_in[0], 0) >= 0 && dup2(t_out[1], 1) >= 0 &&
		    dup2(t_error_fd, 2) >= 0)
		{
			if (t_open != nullptr)
			{
				for (size_t i = 0; i < t_open_count; i++)
					if (t_open[i] != t_status[1])
						close(t_open[i]);
			}
			else
			{
				for (int t_fd = 3; t_fd < (int)t_open_limit; t_fd++)
					if (t_fd != t_status[1])
						close(t_fd);
			}

#if defined(__APPLE__)
			execve(t_program, const_cast<char *const *>(p_arguments),
			       t_environment);
#else
			execv(t_program, const_cast<char *const *>(p_arguments));
#endif
		}

		int t_error = errno;
		ssize_t t_written = write(t_status[1], &t_error, sizeof(t_error));
		(void)t_written;
		_exit(127);
	}

	free(t_open);
	free(t_program);
#if defined(__APPLE__)
	free(t_environment);
#endif

	if (t_success)
	{
		/* Here too: whichever of the two runs first, the group is there
		 * before anything is sent to it */
		setpgid(t_pid, t_pid);

		close(t_status[1]);
		t_status[1] = -1;

		int t_error = 0;
		ssize_t t_read;
		MCASYNC_RETRY(t_read, read(t_status[0], &t_error, sizeof(t_error)));
		if (t_read == (ssize_t)sizeof(t_error))
		{
			/* The program could not be run: the child has exited */
			int t_wait;
			MCASYNC_RETRY(t_wait, waitpid(t_pid, nullptr, 0));
			r_code = (uint32_t)t_error;
			t_success = false;
		}
	}

	if (!t_success)
	{
		ClosePipe(t_in);
		ClosePipe(t_out);
		ClosePipe(t_err);
		ClosePipe(t_status);
		ClosePipe(t_wake);
		return false;
	}

	close(t_status[0]);
	close(t_in[0]);
	close(t_out[1]);
	if (t_err[1] >= 0)
		close(t_err[1]);

	x_process->pid = t_pid;
	x_process->in_fd = t_in[1];
	x_process->out_fd = t_out[0];
	x_process->err_fd = t_err[0];
	x_process->wake_read = t_wake[0];
	x_process->wake_write = t_wake[1];
	return true;
}

/* Undo ProcessSpawn when no thread could be made for the process */
void
ProcessAbandon(Process *x_process)
{
	kill(-x_process->pid, SIGKILL);
	int t_wait;
	MCASYNC_RETRY(t_wait, waitpid(x_process->pid, nullptr, 0));
	x_process->collected = true;

	CloseFile(x_process->in_fd);
	CloseFile(x_process->out_fd);
	CloseFile(x_process->err_fd);
	CloseFile(x_process->wake_read);
	CloseFile(x_process->wake_write);
	x_process->in_fd = x_process->out_fd = x_process->err_fd = -1;
	x_process->wake_read = x_process->wake_write = -1;
}

/* Read what there is in one of the process's pipes */
void
ProcessReadPipe(ProcessOutput& x_output, int p_stream, int& x_fd,
                char *p_buffer)
{
	ssize_t t_read = read(x_fd, p_buffer, kMCAsyncPipeChunk);
	if (t_read > 0)
	{
		ProcessOutputTake(x_output, p_stream, p_buffer, (size_t)t_read);
		return;
	}
	if (t_read < 0 && (errno == EAGAIN || errno == EINTR))
		return;

	/* The end: every process that had the other end has closed it */
	close(x_fd);
	x_fd = -1;
}

/* Whether the process has ended, without collecting it (see where the
 * thread waits for it). A process the system has collected itself has. */
bool
ProcessHasEnded(Process *p_process)
{
	siginfo_t t_info;
	memset(&t_info, 0, sizeof(t_info));
	if (waitid(P_PID, (id_t)p_process->pid, &t_info,
	           WEXITED | WNOHANG | WNOWAIT) != 0)
		return errno != EINTR;
	return t_info.si_pid != 0;
}

void
ProcessThread(void *p_argument)
{
	ProcessThreadStart *t_start =
			static_cast<ProcessThreadStart *>(p_argument);
	Core *t_core = t_start->core;
	Job *t_job = t_start->job;
	free(t_start);

	Process *t_process = t_job->process;

	ProcessOutput t_output;
	t_output.core = t_core;
	t_output.job = t_job;
	BufferInit(t_output.gathered[0]);
	BufferInit(t_output.gathered[1]);
	t_output.total = 0;
	t_output.failed = false;

	char *t_read_buffer = static_cast<char *>(malloc(kMCAsyncPipeChunk));
	char *t_write_buffer = static_cast<char *>(malloc(kMCAsyncPipeChunk));
	if (t_read_buffer == nullptr || t_write_buffer == nullptr)
		t_output.failed = true;

	/* Once the process has been killed (cancelled, or out of memory), its
	 * pipes are read until they end or until this time, whichever is
	 * first */
	bool t_stopping = false;
	uint64_t t_stop_at = 0;

	for (;;)
	{
		if (t_output.failed && !t_stopping)
		{
			t_core->lock.Enter();
			ProcessKill(t_process);
			t_core->lock.Leave();
		}
		if ((t_output.failed || t_job->cancelled.load()) && !t_stopping)
		{
			t_stopping = true;
			t_stop_at = NowMs() + kMCAsyncCancelGraceMs;
		}
		if (t_output.failed)
			break;

		ProcessTurn t_turn;
		ProcessTurnBegin(t_core, t_process, true, t_write_buffer, t_turn);

		if (t_turn.close_input || (t_stopping && t_process->in_fd >= 0))
		{
			close(t_process->in_fd);
			t_process->in_fd = -1;
			ProcessInputClosed(t_core, t_process);
			t_turn.write_length = 0;
		}

		/* With nothing more to read, the process may still be reading what
		 * it is given (its output goes to a file, or it closed it): it is
		 * given it until its input is closed, by the script, by the process
		 * or by its ending */
		bool t_input_only = t_process->out_fd < 0 && t_process->err_fd < 0;
		if (t_input_only && t_process->in_fd < 0)
			break;

		int t_timeout = -1;
		if (t_stopping)
		{
			uint64_t t_now = NowMs();
			if (t_now >= t_stop_at)
				break;
			t_timeout = (int)(t_stop_at - t_now);
		}

		/* No pipe ends when such a process does, if something it started
		 * still holds its input: look now and then */
		if (t_input_only)
		{
			if (ProcessHasEnded(t_process))
				break;
			if (t_timeout < 0 || t_timeout > kMCAsyncEndedPollMs)
				t_timeout = kMCAsyncEndedPollMs;
		}

		struct pollfd t_fds[4];
		int t_count = 0;
		int t_out_index = -1, t_err_index = -1, t_in_index = -1;

		t_fds[t_count].fd = t_process->wake_read;
		t_fds[t_count].events = POLLIN;
		t_count += 1;
		if (t_process->out_fd >= 0 && !t_turn.throttled)
		{
			t_out_index = t_count;
			t_fds[t_count].fd = t_process->out_fd;
			t_fds[t_count].events = POLLIN;
			t_count += 1;
		}
		if (t_process->err_fd >= 0 && !t_turn.throttled)
		{
			t_err_index = t_count;
			t_fds[t_count].fd = t_process->err_fd;
			t_fds[t_count].events = POLLIN;
			t_count += 1;
		}
		if (t_process->in_fd >= 0 &&
		    (t_turn.write_length > 0 || t_input_only))
		{
			/* (with nothing to write, poll still tells of the other end
			 * being closed) */
			t_in_index = t_count;
			t_fds[t_count].fd = t_process->in_fd;
			t_fds[t_count].events = t_turn.write_length > 0 ? POLLOUT : 0;
			t_count += 1;
		}
		for (int i = 0; i < t_count; i++)
			t_fds[i].revents = 0;

		int t_ready = poll(t_fds, (nfds_t)t_count, t_timeout);
		if (t_ready < 0)
		{
			if (errno == EINTR || errno == EAGAIN)
				continue;
			/* Not a thing that poll does with these arguments: stop rather
			 * than spin */
			break;
		}

		if (t_fds[0].revents != 0)
		{
			char t_bytes[64];
			while (read(t_process->wake_read, t_bytes, sizeof(t_bytes)) > 0)
				;
		}
		if (t_out_index >= 0 && t_fds[t_out_index].revents != 0)
			ProcessReadPipe(t_output, 1, t_process->out_fd, t_read_buffer);
		if (t_err_index >= 0 && t_fds[t_err_index].revents != 0)
			ProcessReadPipe(t_output, 2, t_process->err_fd, t_read_buffer);
		if (t_in_index >= 0 && t_fds[t_in_index].revents != 0)
		{
			ssize_t t_written = -1;
			if (t_turn.write_length > 0 &&
			    (t_fds[t_in_index].revents & POLLOUT) != 0)
			{
				t_written = write(t_process->in_fd, t_write_buffer,
				                  t_turn.write_length);
				if (t_written < 0 && (errno == EAGAIN || errno == EINTR))
					t_written = 0;
			}
			if (t_written > 0)
				ProcessInputWritten(t_core, t_process, (size_t)t_written);
			else if (t_written < 0)
			{
				/* The process has closed its input, or has ended */
				close(t_process->in_fd);
				t_process->in_fd = -1;
				ProcessInputClosed(t_core, t_process);
			}
		}
	}

	free(t_read_buffer);
	free(t_write_buffer);

	if (t_process->in_fd >= 0)
	{
		close(t_process->in_fd);
		t_process->in_fd = -1;
		ProcessInputClosed(t_core, t_process);
	}
	CloseFile(t_process->out_fd);
	CloseFile(t_process->err_fd);
	t_process->out_fd = t_process->err_fd = -1;

	/* Wait for the process to end without collecting it, so that it is
	 * collected with the lock held: until then its number is its own, and
	 * the main thread, with the lock, can kill it without hitting another */
	for (;;)
	{
		siginfo_t t_info;
		memset(&t_info, 0, sizeof(t_info));
		if (waitid(P_PID, (id_t)t_process->pid, &t_info,
		           WEXITED | WNOWAIT) == 0 || errno != EINTR)
			break;
	}

	uint32_t t_exit_code = 0;
	t_core->lock.Enter();
	{
		int t_status = 0;
		pid_t t_waited;
		MCASYNC_RETRY(t_waited, waitpid(t_process->pid, &t_status, 0));
		/* A process that a signal ended has the code a shell gives it. One
		 * that the system collected itself (the engine ignores the signal
		 * of its children while it quits) has none to tell. */
		if (t_waited == t_process->pid)
		{
			if (WIFEXITED(t_status))
				t_exit_code = (uint32_t)WEXITSTATUS(t_status);
			else if (WIFSIGNALED(t_status))
				t_exit_code = 128 + (uint32_t)WTERMSIG(t_status);
		}
		t_process->collected = true;

		close(t_process->wake_write);
		t_process->wake_write = -1;
	}
	t_core->lock.Leave();

	close(t_process->wake_read);
	t_process->wake_read = -1;

	ProcessFinish(t_output, t_exit_code);

	t_core->lock.Enter();
	ThreadEnded(t_core);
	t_core->lock.Leave();

	JobRelease(t_job);
	CoreRelease(t_core);
}

#else  // MCASYNC_WINDOWS

/* The number of pipes made, for their names. The main thread's. */
unsigned long s_pipe_serial = 0;

/* A pipe whose one end is ours, opened so that it can be waited on with
 * others, and whose other end is an ordinary handle for the program to
 * inherit. (CreatePipe gives two ends that can only be waited on by
 * reading them, which cannot be interrupted.) */
bool
MakePipe(bool p_ours_reads, HANDLE& r_ours, HANDLE& r_theirs)
{
	wchar_t t_name[80];
	s_pipe_serial += 1;
	_snwprintf(t_name, 80, L"\\\\.\\pipe\\oxt-async-%lu-%lu",
	           (unsigned long)GetCurrentProcessId(), s_pipe_serial);
	t_name[79] = L'\0';

	r_ours = CreateNamedPipeW(
			t_name,
			(p_ours_reads ? PIPE_ACCESS_INBOUND : PIPE_ACCESS_OUTBOUND) |
					FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
			PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT |
					PIPE_REJECT_REMOTE_CLIENTS,
			1, 65536, 65536, 0, nullptr);
	if (r_ours == INVALID_HANDLE_VALUE)
		return false;

	SECURITY_ATTRIBUTES t_inherit;
	t_inherit.nLength = sizeof(t_inherit);
	t_inherit.lpSecurityDescriptor = nullptr;
	t_inherit.bInheritHandle = TRUE;
	r_theirs = CreateFileW(
			t_name,
			p_ours_reads ? (GENERIC_WRITE | FILE_READ_ATTRIBUTES)
			             : (GENERIC_READ | FILE_WRITE_ATTRIBUTES),
			0, &t_inherit, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
	if (r_theirs == INVALID_HANDLE_VALUE)
	{
		DWORD t_error = GetLastError();
		CloseHandle(r_ours);
		r_ours = INVALID_HANDLE_VALUE;
		SetLastError(t_error);
		return false;
	}
	return true;
}

void
CloseIfOpen(HANDLE& x_handle)
{
	if (x_handle != INVALID_HANDLE_VALUE && x_handle != nullptr)
		CloseHandle(x_handle);
	x_handle = INVALID_HANDLE_VALUE;
}

/* Start the program. On the main thread. */
bool
ProcessSpawn(Process *x_process, const MCAsyncProcessOptions& p_options,
             uint32_t& r_code)
{
	wchar_t *t_command = p_options.command_line != nullptr
			? WideFromUTF8(p_options.command_line) : nullptr;
	if (t_command == nullptr)
	{
		r_code = ERROR_INVALID_PARAMETER;
		return false;
	}

	HANDLE t_in_theirs = INVALID_HANDLE_VALUE;
	HANDLE t_out_theirs = INVALID_HANDLE_VALUE;
	HANDLE t_err_theirs = INVALID_HANDLE_VALUE;

	bool t_success =
			MakePipe(false, x_process->in_pipe, t_in_theirs) &&
			MakePipe(true, x_process->out_pipe, t_out_theirs) &&
			(x_process->merge ||
			 MakePipe(true, x_process->err_pipe, t_err_theirs));
	if (t_success)
	{
		x_process->wake_event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
		t_success = x_process->wake_event != nullptr;
	}
	if (!t_success)
		r_code = GetLastError();

	PROCESS_INFORMATION t_info;
	ZeroMemory(&t_info, sizeof(t_info));
	if (t_success)
	{
		/* The program inherits these handles and no other of the engine's */
		HANDLE t_inherit[3];
		DWORD t_inherit_count = 0;
		t_inherit[t_inherit_count++] = t_in_theirs;
		t_inherit[t_inherit_count++] = t_out_theirs;
		if (!x_process->merge)
			t_inherit[t_inherit_count++] = t_err_theirs;

		LPPROC_THREAD_ATTRIBUTE_LIST t_attributes = nullptr;
		SIZE_T t_attributes_size = 0;
		InitializeProcThreadAttributeList(nullptr, 1, 0, &t_attributes_size);
		if (t_attributes_size > 0)
			t_attributes = static_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(
					malloc(t_attributes_size));
		bool t_listed = false;
		if (t_attributes != nullptr &&
		    InitializeProcThreadAttributeList(t_attributes, 1, 0,
		                                      &t_attributes_size))
		{
			t_listed = UpdateProcThreadAttribute(
					t_attributes, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
					t_inherit, t_inherit_count * sizeof(HANDLE), nullptr,
					nullptr) != 0;
			if (!t_listed)
				DeleteProcThreadAttributeList(t_attributes);
		}

		/* Suspended, so that it is in its job object before it runs and
		 * can start nothing outside it */
		for (int t_attempt = 0; t_attempt < 2; t_attempt++)
		{
			STARTUPINFOEXW t_startup;
			ZeroMemory(&t_startup, sizeof(t_startup));
			t_startup.StartupInfo.cb = t_listed ? sizeof(STARTUPINFOEXW)
			                                    : sizeof(STARTUPINFOW);
			t_startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
			if (p_options.hide_window)
			{
				t_startup.StartupInfo.dwFlags |= STARTF_USESHOWWINDOW;
				t_startup.StartupInfo.wShowWindow = SW_HIDE;
			}
			t_startup.StartupInfo.hStdInput = t_in_theirs;
			t_startup.StartupInfo.hStdOutput = t_out_theirs;
			t_startup.StartupInfo.hStdError =
					x_process->merge ? t_out_theirs : t_err_theirs;
			t_startup.lpAttributeList = t_listed ? t_attributes : nullptr;

			t_success = CreateProcessW(
					nullptr, t_command, nullptr, nullptr, TRUE,
					p_options.creation_flags | CREATE_SUSPENDED |
							(t_listed ? EXTENDED_STARTUPINFO_PRESENT : 0),
					nullptr, nullptr, &t_startup.StartupInfo, &t_info) != 0;
			if (t_success)
				break;

			r_code = GetLastError();
			/* Once more without the list, where the system will not have
			 * it; any other error is the program's */
			if (!t_listed || (r_code != ERROR_INVALID_PARAMETER &&
			                  r_code != ERROR_NOT_SUPPORTED))
				break;
			DeleteProcThreadAttributeList(t_attributes);
			t_listed = false;
		}

		if (t_listed)
			DeleteProcThreadAttributeList(t_attributes);
		free(t_attributes);
	}

	free(t_command);
	CloseIfOpen(t_in_theirs);
	CloseIfOpen(t_out_theirs);
	CloseIfOpen(t_err_theirs);

	if (!t_success)
	{
		CloseIfOpen(x_process->in_pipe);
		CloseIfOpen(x_process->out_pipe);
		CloseIfOpen(x_process->err_pipe);
		if (x_process->wake_event != nullptr)
			CloseHandle(x_process->wake_event);
		x_process->wake_event = nullptr;
		return false;
	}

	/* The job object is how the process is killed with those it starts. A
	 * process may still leave it where it asks to, as it may without one. */
	x_process->job_object = CreateJobObjectW(nullptr, nullptr);
	if (x_process->job_object != nullptr)
	{
		JOBOBJECT_EXTENDED_LIMIT_INFORMATION t_limits;
		ZeroMemory(&t_limits, sizeof(t_limits));
		t_limits.BasicLimitInformation.LimitFlags =
				JOB_OBJECT_LIMIT_BREAKAWAY_OK;
		SetInformationJobObject(x_process->job_object,
		                        JobObjectExtendedLimitInformation, &t_limits,
		                        sizeof(t_limits));
		if (!AssignProcessToJobObject(x_process->job_object, t_info.hProcess))
		{
			CloseHandle(x_process->job_object);
			x_process->job_object = nullptr;
		}
	}

	x_process->process = t_info.hProcess;
	ResumeThread(t_info.hThread);
	CloseHandle(t_info.hThread);
	return true;
}

void
ProcessAbandon(Process *x_process)
{
	if (x_process->job_object != nullptr)
		TerminateJobObject(x_process->job_object, 1);
	else
		TerminateProcess(x_process->process, 1);
	x_process->collected = true;

	CloseIfOpen(x_process->in_pipe);
	CloseIfOpen(x_process->out_pipe);
	CloseIfOpen(x_process->err_pipe);
	CloseHandle(x_process->process);
	x_process->process = nullptr;
	if (x_process->job_object != nullptr)
		CloseHandle(x_process->job_object);
	x_process->job_object = nullptr;
	CloseHandle(x_process->wake_event);
	x_process->wake_event = nullptr;
}

/* One of the process's pipes that is read */
struct PipeReader
{
	HANDLE *pipe;
	int stream;
	OVERLAPPED overlapped;
	char *buffer;
	/* A read has been started and its end not seen */
	bool reading;
	/* The pipe has ended, or there is none */
	bool ended;
};

bool
PipeReaderInit(PipeReader& r_reader, HANDLE *p_pipe, int p_stream)
{
	ZeroMemory(&r_reader, sizeof(r_reader));
	r_reader.pipe = p_pipe;
	r_reader.stream = p_stream;
	r_reader.ended = *p_pipe == INVALID_HANDLE_VALUE;
	if (r_reader.ended)
		return true;
	r_reader.buffer = static_cast<char *>(malloc(kMCAsyncPipeChunk));
	r_reader.overlapped.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
	return r_reader.buffer != nullptr && r_reader.overlapped.hEvent != nullptr;
}

void
PipeReaderStart(PipeReader& x_reader)
{
	if (x_reader.ended || x_reader.reading)
		return;
	/* A read that is done at once has signalled the event too: both are
	 * taken up in PipeReaderFinish */
	if (ReadFile(*x_reader.pipe, x_reader.buffer, (DWORD)kMCAsyncPipeChunk,
	             nullptr, &x_reader.overlapped) ||
	    GetLastError() == ERROR_IO_PENDING)
		x_reader.reading = true;
	else
		x_reader.ended = true;
}

/* Take up a read that is done, if it is */
void
PipeReaderFinish(PipeReader& x_reader, ProcessOutput& x_output)
{
	if (!x_reader.reading ||
	    WaitForSingleObject(x_reader.overlapped.hEvent, 0) != WAIT_OBJECT_0)
		return;

	DWORD t_read = 0;
	if (GetOverlappedResult(*x_reader.pipe, &x_reader.overlapped, &t_read,
	                        FALSE))
	{
		x_reader.reading = false;
		ProcessOutputTake(x_output, x_reader.stream, x_reader.buffer, t_read);
	}
	else if (GetLastError() != ERROR_IO_INCOMPLETE)
	{
		/* The end: every process that had the other end has closed it */
		x_reader.reading = false;
		x_reader.ended = true;
	}
}

/* Stop a read or write that has not finished and wait until it has, so
 * that its buffer and event can go */
void
CancelPending(HANDLE p_pipe, OVERLAPPED& x_overlapped, bool& x_pending)
{
	if (!x_pending)
		return;
	CancelIo(p_pipe);
	DWORD t_count = 0;
	GetOverlappedResult(p_pipe, &x_overlapped, &t_count, TRUE);
	x_pending = false;
}

void
ProcessThread(void *p_argument)
{
	ProcessThreadStart *t_start =
			static_cast<ProcessThreadStart *>(p_argument);
	Core *t_core = t_start->core;
	Job *t_job = t_start->job;
	free(t_start);

	Process *t_process = t_job->process;

	ProcessOutput t_output;
	t_output.core = t_core;
	t_output.job = t_job;
	BufferInit(t_output.gathered[0]);
	BufferInit(t_output.gathered[1]);
	t_output.total = 0;
	t_output.failed = false;

	PipeReader t_out, t_err;
	if (!PipeReaderInit(t_out, &t_process->out_pipe, 1) ||
	    !PipeReaderInit(t_err, &t_process->err_pipe, 2))
		t_output.failed = true;

	char *t_write_buffer = static_cast<char *>(malloc(kMCAsyncPipeChunk));
	OVERLAPPED t_write;
	ZeroMemory(&t_write, sizeof(t_write));
	t_write.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
	bool t_writing = false;
	if (t_write_buffer == nullptr || t_write.hEvent == nullptr)
		t_output.failed = true;

	bool t_stopping = false;
	uint64_t t_stop_at = 0;

	for (;;)
	{
		if (t_output.failed && !t_stopping)
		{
			t_core->lock.Enter();
			ProcessKill(t_process);
			t_core->lock.Leave();
		}
		if ((t_output.failed || t_job->cancelled.load()) && !t_stopping)
		{
			t_stopping = true;
			t_stop_at = NowMs() + kMCAsyncCancelGraceMs;
		}
		if (t_output.failed)
			break;

		ProcessTurn t_turn;
		ProcessTurnBegin(t_core, t_process, !t_writing, t_write_buffer,
		                 t_turn);

		if ((t_turn.close_input || t_stopping) &&
		    t_process->in_pipe != INVALID_HANDLE_VALUE)
		{
			CancelPending(t_process->in_pipe, t_write, t_writing);
			CloseIfOpen(t_process->in_pipe);
			ProcessInputClosed(t_core, t_process);
			t_turn.write_length = 0;
		}

		/* With nothing more to read, the process may still be reading what
		 * it is given (its output goes to a file, or it closed it): it is
		 * given it until its input is closed, by the script, by the process
		 * or by its ending */
		if (t_out.ended && t_err.ended &&
		    (t_process->in_pipe == INVALID_HANDLE_VALUE ||
		     WaitForSingleObject(t_process->process, 0) == WAIT_OBJECT_0))
			break;

		DWORD t_timeout = INFINITE;
		if (t_stopping)
		{
			uint64_t t_now = NowMs();
			if (t_now >= t_stop_at)
				break;
			t_timeout = (DWORD)(t_stop_at - t_now);
		}

		if (!t_turn.throttled)
		{
			PipeReaderStart(t_out);
			PipeReaderStart(t_err);
			if (t_out.ended && t_err.ended &&
			    t_process->in_pipe == INVALID_HANDLE_VALUE)
				break;
		}

		if (t_turn.write_length > 0 &&
		    t_process->in_pipe != INVALID_HANDLE_VALUE)
		{
			if (WriteFile(t_process->in_pipe, t_write_buffer,
			              (DWORD)t_turn.write_length, nullptr, &t_write) ||
			    GetLastError() == ERROR_IO_PENDING)
				t_writing = true;
			else
			{
				/* The process has closed its input, or has ended */
				CloseIfOpen(t_process->in_pipe);
				ProcessInputClosed(t_core, t_process);
			}
		}

		HANDLE t_handles[4];
		DWORD t_count = 0;
		t_handles[t_count++] = t_process->wake_event;
		if (t_out.reading)
			t_handles[t_count++] = t_out.overlapped.hEvent;
		if (t_err.reading)
			t_handles[t_count++] = t_err.overlapped.hEvent;
		if (t_writing)
			t_handles[t_count++] = t_write.hEvent;
		/* (the process's ending is then all that tells of it) */
		if (t_out.ended && t_err.ended)
			t_handles[t_count++] = t_process->process;

		if (WaitForMultipleObjects(t_count, t_handles, FALSE, t_timeout) ==
		    WAIT_FAILED)
			break;

		PipeReaderFinish(t_out, t_output);
		PipeReaderFinish(t_err, t_output);

		if (t_writing &&
		    WaitForSingleObject(t_write.hEvent, 0) == WAIT_OBJECT_0)
		{
			DWORD t_written = 0;
			if (GetOverlappedResult(t_process->in_pipe, &t_write, &t_written,
			                        FALSE))
			{
				t_writing = false;
				ProcessInputWritten(t_core, t_process, t_written);
			}
			else if (GetLastError() != ERROR_IO_INCOMPLETE)
			{
				t_writing = false;
				CloseIfOpen(t_process->in_pipe);
				ProcessInputClosed(t_core, t_process);
			}
		}
	}

	if (t_process->in_pipe != INVALID_HANDLE_VALUE)
	{
		CancelPending(t_process->in_pipe, t_write, t_writing);
		CloseIfOpen(t_process->in_pipe);
		ProcessInputClosed(t_core, t_process);
	}
	if (t_process->out_pipe != INVALID_HANDLE_VALUE)
		CancelPending(t_process->out_pipe, t_out.overlapped, t_out.reading);
	if (t_process->err_pipe != INVALID_HANDLE_VALUE)
		CancelPending(t_process->err_pipe, t_err.overlapped, t_err.reading);
	CloseIfOpen(t_process->out_pipe);
	CloseIfOpen(t_process->err_pipe);

	free(t_out.buffer);
	free(t_err.buffer);
	free(t_write_buffer);
	if (t_out.overlapped.hEvent != nullptr)
		CloseHandle(t_out.overlapped.hEvent);
	if (t_err.overlapped.hEvent != nullptr)
		CloseHandle(t_err.overlapped.hEvent);
	if (t_write.hEvent != nullptr)
		CloseHandle(t_write.hEvent);

	/* A process that was killed ends at once. One that could not be (the
	 * system refused) is not waited for for ever: its job still ends. */
	WaitForSingleObject(t_process->process, t_stopping ? 5000 : INFINITE);
	DWORD t_exit_code = 0;
	if (!GetExitCodeProcess(t_process->process, &t_exit_code) ||
	    t_exit_code == STILL_ACTIVE)
		t_exit_code = 0;

	t_core->lock.Enter();
	t_process->collected = true;
	CloseHandle(t_process->process);
	t_process->process = nullptr;
	if (t_process->job_object != nullptr)
		CloseHandle(t_process->job_object);
	t_process->job_object = nullptr;
	CloseHandle(t_process->wake_event);
	t_process->wake_event = nullptr;
	t_core->lock.Leave();

	ProcessFinish(t_output, t_exit_code);

	t_core->lock.Enter();
	ThreadEnded(t_core);
	t_core->lock.Leave();

	JobRelease(t_job);
	CoreRelease(t_core);
}

#endif  // MCASYNC_WINDOWS

#else  // !MCASYNC_PROCESSES

void
ProcessFree(Process *)
{
}

#endif

}  // namespace

////////////////////////////////////////////////////////////////////////////////
//
//  THE MAIN THREAD'S CALLS
//

bool
MCAsyncCoreInitialize(MCAsyncWakeCallback p_wake, void *p_context,
                      MCAsyncThreadCallback p_thread)
{
	if (s_core != nullptr)
		return false;

	Core *t_core = new (std::nothrow) Core;
	if (t_core == nullptr)
		return false;

	t_core->references.store(1);
	t_core->shutdown = false;
	t_core->wake = p_wake;
	t_core->wake_context = p_context;
	t_core->wake_sent = false;
	t_core->thread_callback = p_thread;
	for (unsigned int i = 0; i < kMCAsyncTableSize; i++)
		t_core->table[i] = nullptr;
	t_core->last_id = 0;
	for (unsigned int i = 0; i < kPoolCount; i++)
	{
		t_core->pools[i].queue_first = nullptr;
		t_core->pools[i].queue_last = nullptr;
		t_core->pools[i].threads = 0;
		t_core->pools[i].queue_length = 0;
		t_core->pools[i].threads_busy = 0;
		t_core->pools[i].thread_limit = s_thread_limits[i];
	}
	t_core->threads = 0;
	t_core->events_first = nullptr;
	t_core->events_last = nullptr;

	/* The lock of the wakes, made once and kept for good: a thread may
	 * signal a wake long after this core has gone */
	Lock *t_wake_lock = s_wake_lock.load();
	if (t_wake_lock == nullptr)
	{
		t_wake_lock = new (std::nothrow) Lock;
		if (t_wake_lock == nullptr)
		{
			delete t_core;
			return false;
		}
		s_wake_lock.store(t_wake_lock);
	}
	t_wake_lock->Enter();
	s_wake_core = t_core;
	t_wake_lock->Leave();

	s_core = t_core;
	return true;
}

bool
MCAsyncCoreIsInitialized(void)
{
	return s_core != nullptr;
}

bool
MCAsyncCoreFinishWrites(unsigned int p_wait_ms)
{
	Core *t_core = s_core;
	if (t_core == nullptr)
		return true;

	t_core->lock.Enter();
	uint64_t t_until = NowMs() + p_wait_ms;
	bool t_finished;
	for (;;)
	{
		t_finished = true;
		for (unsigned int i = 0; i < kMCAsyncTableSize && t_finished; i++)
			for (Job *t_job = t_core->table[i]; t_job != nullptr;
			     t_job = t_job->table_next)
				if (t_job->kind == kJobWrite &&
				    (t_job->status == kMCAsyncStatusQueued ||
				     t_job->status == kMCAsyncStatusRunning))
				{
					t_finished = false;
					break;
				}

		uint64_t t_now = NowMs();
		if (t_finished || t_now >= t_until)
			break;

		/* Nothing signals the end of one job: look again in a moment (the
		 * wait gives up the lock meanwhile) */
		uint64_t t_left = t_until - t_now;
		t_core->ended.WaitFor(t_core->lock,
		                      t_left < 10 ? (unsigned int)t_left : 10);
	}
	t_core->lock.Leave();
	return t_finished;
}

bool
MCAsyncCoreFinalize(unsigned int p_wait_ms)
{
	Core *t_core = s_core;
	if (t_core == nullptr)
		return true;
	s_core = nullptr;

	/* The wakes first: once the lock is let go, no thread that signals one
	 * is in this core, or will be */
	Lock *t_wake_lock = s_wake_lock.load();
	if (t_wake_lock != nullptr)
	{
		t_wake_lock->Enter();
		s_wake_core = nullptr;
		s_wakes_signalled = 0;
		for (unsigned int i = 0; i < kWakeLimit; i++)
		{
			s_wakes[i].id = 0;
			s_wakes[i].context = nullptr;
			s_wakes[i].signalled = false;
		}
		t_wake_lock->Leave();
	}

	t_core->lock.Enter();

	t_core->shutdown = true;
	t_core->wake = nullptr;

	/* The jobs that never got a thread */
	Job *t_dropped = nullptr;
	for (unsigned int i = 0; i < kPoolCount; i++)
	{
		for (Job *t_job = QueuePop(&t_core->pools[i]); t_job != nullptr;
		     t_job = QueuePop(&t_core->pools[i]))
		{
			t_job->queue_next = t_dropped;
			t_dropped = t_job;
		}
	}

	/* Every job that runs is told to stop, and every process is killed
	 * here and now: its thread may not get to run again before the engine
	 * has gone */
	for (unsigned int i = 0; i < kMCAsyncTableSize; i++)
	{
		for (Job *t_job = t_core->table[i]; t_job != nullptr;
		     t_job = t_job->table_next)
		{
			t_job->cancelled.store(true);
#if MCASYNC_PROCESSES
			if (t_job->process != nullptr)
			{
				ProcessKill(t_job->process);
				ProcessWake(t_job->process);
			}
#endif
		}
	}

	for (unsigned int i = 0; i < kPoolCount; i++)
		t_core->pools[i].work.Broadcast();

	uint64_t t_until = NowMs() + p_wait_ms;
	while (t_core->threads > 0)
	{
		uint64_t t_now = NowMs();
		if (t_now >= t_until)
			break;
		t_core->ended.WaitFor(t_core->lock, (unsigned int)(t_until - t_now));
	}
	bool t_all_ended = t_core->threads == 0;

	QueuedEvent *t_events = t_core->events_first;
	t_core->events_first = nullptr;
	t_core->events_last = nullptr;

	Job *t_jobs = nullptr;
	for (unsigned int i = 0; i < kMCAsyncTableSize; i++)
	{
		while (t_core->table[i] != nullptr)
		{
			Job *t_job = t_core->table[i];
			t_core->table[i] = t_job->table_next;
			t_job->table_next = t_jobs;
			t_job->status = kMCAsyncStatusNone;
			t_jobs = t_job;
		}
	}

	t_core->lock.Leave();

	while (t_events != nullptr)
	{
		QueuedEvent *t_event = t_events;
		t_events = t_event->next;
		free(t_event->event.data);
		free(t_event);
	}
	while (t_dropped != nullptr)
	{
		Job *t_job = t_dropped;
		t_dropped = t_job->queue_next;
		t_job->queue_next = nullptr;
		JobRelease(t_job);
	}
	while (t_jobs != nullptr)
	{
		Job *t_job = t_jobs;
		t_jobs = t_job->table_next;
		t_job->table_next = nullptr;
		JobRelease(t_job);
	}

	CoreRelease(t_core);
	return t_all_ended;
}

void
MCAsyncCoreSetThreadLimit(unsigned int p_limit)
{
	for (unsigned int i = 0; i < kPoolCount; i++)
		s_thread_limits[i] = p_limit;
	if (s_core != nullptr)
	{
		s_core->lock.Enter();
		for (unsigned int i = 0; i < kPoolCount; i++)
			s_core->pools[i].thread_limit = p_limit;
		s_core->lock.Leave();
	}
}

MCAsyncJobId
MCAsyncCoreReadFile(const char *p_path, void *p_context)
{
	if (s_core == nullptr || p_path == nullptr)
		return 0;

	Job *t_job = JobCreate(kJobRead, p_context);
	if (t_job == nullptr)
		return 0;
	t_job->path = PathCopy(p_path);
	if (t_job->path == nullptr)
	{
		JobRelease(t_job);
		return 0;
	}
	return QueuedJobStart(t_job, kPoolFiles);
}

MCAsyncJobId
MCAsyncCoreWriteFile(const char *p_path, const void *p_bytes, size_t p_length,
                     bool p_append, void *p_context)
{
	if (s_core == nullptr || p_path == nullptr ||
	    (p_bytes == nullptr && p_length != 0))
		return 0;

	Job *t_job = JobCreate(kJobWrite, p_context);
	if (t_job == nullptr)
		return 0;
	t_job->path = PathCopy(p_path);
	if (t_job->path == nullptr)
	{
		JobRelease(t_job);
		return 0;
	}
	t_job->bytes = p_bytes;
	t_job->length = p_length;
	t_job->append = p_append;
	return QueuedJobStart(t_job, kPoolFiles);
}

MCAsyncJobId
MCAsyncCoreCopyFile(const char *p_from, const char *p_to, void *p_context)
{
	if (s_core == nullptr || p_from == nullptr || p_to == nullptr)
		return 0;

	Job *t_job = JobCreate(kJobCopy, p_context);
	if (t_job == nullptr)
		return 0;
	t_job->path = PathCopy(p_from);
	t_job->other_path = PathCopy(p_to);
	if (t_job->path == nullptr || t_job->other_path == nullptr)
	{
		JobRelease(t_job);
		return 0;
	}
	return QueuedJobStart(t_job, kPoolFiles);
}

MCAsyncJobId
MCAsyncCoreListFolder(const char *p_path, bool p_recursive, void *p_context)
{
	if (s_core == nullptr || p_path == nullptr)
		return 0;

	Job *t_job = JobCreate(kJobList, p_context);
	if (t_job == nullptr)
		return 0;
	t_job->path = PathCopy(p_path);
	if (t_job->path == nullptr)
	{
		JobRelease(t_job);
		return 0;
	}
	t_job->recursive = p_recursive;
	return QueuedJobStart(t_job, kPoolFiles);
}

MCAsyncJobId
MCAsyncCoreCall(MCAsyncNativeFunction p_function, void *p_function_context,
                void *p_context)
{
	if (s_core == nullptr || p_function == nullptr)
		return 0;

	Job *t_job = JobCreate(kJobCall, p_context);
	if (t_job == nullptr)
		return 0;
	t_job->function = p_function;
	t_job->function_context = p_function_context;
	return QueuedJobStart(t_job, kPoolCalls);
}

MCAsyncWakeId
MCAsyncCoreWakeCreate(void *p_context)
{
	Lock *t_lock = s_wake_lock.load();
	if (s_core == nullptr || t_lock == nullptr)
		return 0;

	MCAsyncWakeId t_id = 0;
	t_lock->Enter();
	for (unsigned int i = 0; i < kWakeLimit && t_id == 0; i++)
	{
		Wake *t_wake = &s_wakes[i];
		if (t_wake->id != 0)
			continue;

		/* Never 0, so that no wake's number is */
		t_wake->uses = (t_wake->uses + 1) &
				((1u << (32 - kWakeIndexBits)) - 1);
		if (t_wake->uses == 0)
			t_wake->uses = 1;
		t_wake->id = (t_wake->uses << kWakeIndexBits) | i;
		t_wake->context = p_context;
		t_wake->signalled = false;
		t_id = t_wake->id;
	}
	t_lock->Leave();
	return t_id;
}

bool
MCAsyncCoreWakeDestroy(MCAsyncWakeId p_wake)
{
	Lock *t_lock = s_wake_lock.load();
	if (t_lock == nullptr)
		return false;

	t_lock->Enter();
	Wake *t_wake = WakeFind(p_wake);
	if (t_wake != nullptr)
	{
		if (t_wake->signalled)
			s_wakes_signalled -= 1;
		t_wake->id = 0;
		t_wake->context = nullptr;
		t_wake->signalled = false;
	}
	t_lock->Leave();
	return t_wake != nullptr;
}

void
MCAsyncCoreWakeSignal(MCAsyncWakeId p_wake)
{
	Lock *t_lock = s_wake_lock.load();
	if (t_lock == nullptr)
		return;

	t_lock->Enter();
	Wake *t_wake = WakeFind(p_wake);
	if (t_wake != nullptr && !t_wake->signalled && s_wake_core != nullptr)
	{
		t_wake->signalled = true;
		s_wakes_signalled += 1;

		/* The core is there for as long as the wake lock is held:
		 * MCAsyncCoreFinalize takes it before anything else */
		Core *t_core = s_wake_core;
		t_core->lock.Enter();
		CoreWake(t_core);
		t_core->lock.Leave();
	}
	t_lock->Leave();
}

bool
MCAsyncCoreCanStartProcesses(void)
{
	return MCASYNC_PROCESSES != 0;
}

MCAsyncJobId
MCAsyncCoreStartProcess(const MCAsyncProcessOptions& p_options,
                        void *p_context)
{
	Core *t_core = s_core;
	if (t_core == nullptr)
		return 0;

	Job *t_job = JobCreate(kJobProcess, p_context);
	if (t_job == nullptr)
		return 0;

#if MCASYNC_PROCESSES
	t_job->process = ProcessCreate(p_options);
	ProcessThreadStart *t_start = static_cast<ProcessThreadStart *>(
			malloc(sizeof(ProcessThreadStart)));
	if (t_job->process == nullptr || t_start == nullptr)
	{
		free(t_start);
		JobRelease(t_job);
		return 0;
	}
#endif

	t_core->lock.Enter();
	JobRegister(t_core, t_job);
	t_job->status = kMCAsyncStatusRunning;
	t_core->lock.Leave();
	MCAsyncJobId t_id = t_job->id;

#if MCASYNC_PROCESSES
	uint32_t t_code = 0;
#if defined(MCASYNC_WINDOWS)
	bool t_spawned = ProcessSpawn(t_job->process, p_options, t_code);
#else
	bool t_spawned = ProcessSpawn(t_job->process, p_options.arguments, t_code);
#endif
	if (!t_spawned)
	{
		free(t_start);
		t_core->lock.Enter();
		t_job->process->collected = true;
		t_job->process->input_open = false;
		t_core->lock.Leave();
		JobFinish(t_core, t_job, kMCAsyncErrorSpawn, t_code, nullptr, 0);
		return t_id;
	}

	/* The thread's counts of the job and of the core */
	t_start->core = t_core;
	t_start->job = t_job;
	t_job->references.fetch_add(1);
	t_core->references.fetch_add(1);

	t_core->lock.Enter();
	t_core->threads += 1;
	bool t_threaded =
			ThreadCreate(ProcessThread, t_start, t_core->thread_callback);
	if (!t_threaded)
	{
		t_core->threads -= 1;
		ProcessAbandon(t_job->process);
		t_job->process->input_open = false;
	}
	t_core->lock.Leave();

	if (!t_threaded)
	{
		free(t_start);
		t_job->references.fetch_sub(1);
		t_core->references.fetch_sub(1);
		JobFinish(t_core, t_job, kMCAsyncErrorOutOfMemory, 0, nullptr, 0);
	}
#else
	(void)p_options;
	JobFinish(t_core, t_job, kMCAsyncErrorNotSupported, 0, nullptr, 0);
#endif

	return t_id;
}

bool
MCAsyncCoreProcessWrite(MCAsyncJobId p_job, const void *p_bytes,
                        size_t p_length)
{
#if MCASYNC_PROCESSES
	Core *t_core = s_core;
	if (t_core == nullptr)
		return false;

	bool t_success = false;
	t_core->lock.Enter();
	Job *t_job = JobFind(t_core, p_job);
	if (t_job != nullptr && t_job->process != nullptr &&
	    t_job->process->input_open && !t_job->process->close_input)
	{
		Process *t_process = t_job->process;
		t_success = true;
		if (p_length > 0)
		{
			/* What has been written goes from the front of the queue
			 * before the queue grows */
			if (t_process->input_offset > 0)
			{
				memmove(t_process->input,
				        t_process->input + t_process->input_offset,
				        t_process->input_length - t_process->input_offset);
				t_process->input_length -= t_process->input_offset;
				t_process->input_offset = 0;
			}
			if (p_length > (size_t)-1 - t_process->input_length)
				t_success = false;
			else if (t_process->input_length + p_length >
			         t_process->input_capacity)
			{
				size_t t_capacity = t_process->input_length + p_length;
				if (t_capacity < (size_t)-1 / 2 &&
				    t_capacity < t_process->input_capacity * 2)
					t_capacity = t_process->input_capacity * 2;
				char *t_grown = static_cast<char *>(
						realloc(t_process->input, t_capacity));
				if (t_grown == nullptr)
					t_success = false;
				else
				{
					t_process->input = t_grown;
					t_process->input_capacity = t_capacity;
				}
			}
			if (t_success)
			{
				memcpy(t_process->input + t_process->input_length, p_bytes,
				       p_length);
				t_process->input_length += p_length;
				ProcessWake(t_process);
			}
		}
	}
	t_core->lock.Leave();
	return t_success;
#else
	(void)p_job;
	(void)p_bytes;
	(void)p_length;
	return false;
#endif
}

bool
MCAsyncCoreProcessCloseInput(MCAsyncJobId p_job)
{
#if MCASYNC_PROCESSES
	Core *t_core = s_core;
	if (t_core == nullptr)
		return false;

	bool t_success = false;
	t_core->lock.Enter();
	Job *t_job = JobFind(t_core, p_job);
	if (t_job != nullptr && t_job->process != nullptr &&
	    t_job->process->input_open)
	{
		t_job->process->close_input = true;
		ProcessWake(t_job->process);
		t_success = true;
	}
	t_core->lock.Leave();
	return t_success;
#else
	(void)p_job;
	return false;
#endif
}

bool
MCAsyncCoreCancel(MCAsyncJobId p_job)
{
	Core *t_core = s_core;
	if (t_core == nullptr)
		return false;

	t_core->lock.Enter();
	Job *t_job = JobFind(t_core, p_job);
	/* A job that is over, with its end not yet told, ends as it ended */
	if (t_job != nullptr && t_job->status != kMCAsyncStatusFinished)
	{
		t_job->cancelled.store(true);
#if MCASYNC_PROCESSES
		if (t_job->process != nullptr)
		{
			ProcessKill(t_job->process);
			ProcessWake(t_job->process);
		}
#endif
	}
	t_core->lock.Leave();
	return t_job != nullptr;
}

MCAsyncStatus
MCAsyncCoreStatus(MCAsyncJobId p_job)
{
	Core *t_core = s_core;
	if (t_core == nullptr)
		return kMCAsyncStatusNone;

	t_core->lock.Enter();
	Job *t_job = JobFind(t_core, p_job);
	MCAsyncStatus t_status =
			t_job != nullptr ? t_job->status : kMCAsyncStatusNone;
	t_core->lock.Leave();
	return t_status;
}

bool
MCAsyncCoreProgress(MCAsyncJobId p_job, uint64_t& r_done, uint64_t& r_total)
{
	Core *t_core = s_core;
	if (t_core == nullptr)
		return false;

	t_core->lock.Enter();
	Job *t_job = JobFind(t_core, p_job);
	if (t_job != nullptr)
	{
		r_done = t_job->done;
		r_total = t_job->total;
	}
	t_core->lock.Leave();
	return t_job != nullptr;
}

void
MCAsyncCoreDrain(MCAsyncEventCallback p_callback, void *p_context)
{
	Core *t_core = s_core;
	if (t_core == nullptr)
		return;

	t_core->lock.Enter();
	QueuedEvent *t_events = t_core->events_first;
	t_core->events_first = nullptr;
	t_core->events_last = nullptr;
	t_core->wake_sent = false;
	t_core->lock.Leave();

	while (t_events != nullptr)
	{
		QueuedEvent *t_event = t_events;
		t_events = t_event->next;

		/* A job is known until its Done event is given, here */
		Job *t_ended = nullptr;
		t_core->lock.Enter();
		Job *t_job = JobFind(t_core, t_event->event.job);
		if (t_job != nullptr)
		{
			if (t_event->event.kind == kMCAsyncEventDone)
			{
				JobUnregister(t_core, t_job);
				t_ended = t_job;
			}
#if MCASYNC_PROCESSES
			else if (t_job->process != nullptr)
			{
				Process *t_process = t_job->process;
				if (t_process->waiting >= t_event->event.length)
					t_process->waiting -= t_event->event.length;
				else
					t_process->waiting = 0;
				if (t_process->throttled &&
				    t_process->waiting <= kMCAsyncHighWater)
				{
					t_process->throttled = false;
					ProcessWake(t_process);
				}
			}
#endif
		}
		t_core->lock.Leave();

		if (p_callback != nullptr)
			p_callback(p_context, t_event->event);

		free(t_event->event.data);
		free(t_event);
		if (t_ended != nullptr)
			JobRelease(t_ended);

		/* The callback may have finalized the core: then the rest of the
		 * events are dropped, as those still queued were */
		if (s_core != t_core)
		{
			while (t_events != nullptr)
			{
				t_event = t_events;
				t_events = t_event->next;
				free(t_event->event.data);
				free(t_event);
			}
			return;
		}
	}

	/* The wakes that were signalled: one event each, however many times */
	Lock *t_wake_lock = s_wake_lock.load();
	if (t_wake_lock == nullptr)
		return;

	MCAsyncWakeId t_signalled[kWakeLimit];
	unsigned int t_count = 0;
	t_wake_lock->Enter();
	if (s_wakes_signalled != 0)
	{
		for (unsigned int i = 0; i < kWakeLimit; i++)
		{
			if (s_wakes[i].id != 0 && s_wakes[i].signalled)
			{
				s_wakes[i].signalled = false;
				t_signalled[t_count++] = s_wakes[i].id;
			}
		}
		s_wakes_signalled = 0;
	}
	t_wake_lock->Leave();

	for (unsigned int i = 0; i < t_count; i++)
	{
		/* The callback for an earlier event may have destroyed this wake,
		 * or finalized the core, which destroys them all */
		t_wake_lock->Enter();
		Wake *t_wake = WakeFind(t_signalled[i]);
		void *t_context = t_wake != nullptr ? t_wake->context : nullptr;
		t_wake_lock->Leave();
		if (t_wake == nullptr)
			continue;

		MCAsyncEvent t_event;
		t_event.job = t_signalled[i];
		t_event.context = t_context;
		t_event.kind = kMCAsyncEventWake;
		t_event.stream = 0;
		t_event.data = nullptr;
		t_event.length = 0;
		t_event.error = kMCAsyncErrorNone;
		t_event.code = 0;
		if (p_callback != nullptr)
			p_callback(p_context, t_event);
	}
}
