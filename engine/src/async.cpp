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

/* Background jobs, the engine's side.
 *
 * A script starts a job (run a command, read, write or copy a file, list a
 * folder) with a handler of the Background Jobs library
 * (extensions/libraries/async), which binds to the functions at the end of
 * this file by name. The job runs on another thread (async-core.cpp, which
 * knows nothing of the engine) while the script goes on, and the object
 * whose script started it is sent a message when it is done.
 *
 * Nothing of the engine is touched on those threads. All that a thread
 * does to the engine is to set a flag and post a notification (notify.cpp),
 * from the core's wake callback. The notification wakes the main thread's
 * wait, and it is on the main thread that each event of the core becomes a
 * pending message (MCAsyncDrain): where the notification is dispatched, and
 * at the top of every pass of a wait (MCAsyncPostPending, which
 * MCUIDC::handlepending calls before it looks for the messages that are
 * due). So a job's message arrives where a message sent "in 0 seconds"
 * would: when the handlers that are running have finished, or while one of
 * them waits "with messages".
 *
 * An extension with native code of its own has two more things here, which
 * it binds to by name as the library does (the MCAsyncNative functions): it
 * can have a function of its native code called on one of the jobs'
 * threads, and it can make a wake, which its own threads signal when they
 * have something for the script. The signal is all that such a thread does
 * to the engine, and it comes to the script as a message, as a job's end
 * does. "Native code that takes time, or has threads of its own" in
 * ide/Documentation/guides/Extending OXT.md is the account for an
 * extension's author.
 *
 * Nothing here changes what an existing script does: shell(), "open
 * process", "put URL" and the rest block as they always have. These are
 * new calls, behind a library whose handlers come last in the message
 * path. */

#include "prefix.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "mcio.h"

#include "globals.h"
#include "util.h"
#include "osspec.h"
#include "object.h"
#include "param.h"
#include "uidc.h"
#include "exec.h"
#include "notify.h"
#include "securemode.h"
#include "module-engine.h"

#include "async.h"
#include "async-core.h"

#include <cstdlib>
#include <cstring>

#if defined(_ANDROID_MOBILE)
#include "mblandroidjava.h"
#endif

#include <atomic>

////////////////////////////////////////////////////////////////////////////////

/* How long the engine waits, as it quits, for the files that scripts gave
 * it to write: a write that is cut short loses what only memory had. A
 * disk that takes longer than this for what is left is not answering. */
static const unsigned int kMCAsyncQuitWriteWaitMs = 120 * 1000;

/* And then for the threads to end, once every job has been told to stop
 * and every process has been killed */
static const unsigned int kMCAsyncQuitThreadWaitMs = 2 * 1000;

/* CreateProcess's CREATE_NEW_CONSOLE, which shell() and "open process"
 * start their programs with (dskw32.cpp); windows.h is not included here.
 * Only Windows uses it: clang refuses a constant that nothing uses. */
#if defined(_WINDOWS)
static const uint32_t kMCAsyncCreateNewConsole = 0x00000010;
#endif

////////////////////////////////////////////////////////////////////////////////
//
//  THE JOBS THAT ARE RUNNING
//

enum MCAsyncJobKind
{
	kMCAsyncJobKindRead,
	kMCAsyncJobKindWrite,
	kMCAsyncJobKindCopy,
	kMCAsyncJobKindList,
	/* A command given to the shell: its output comes whole, as text */
	kMCAsyncJobKindShell,
	/* A program that is talked to: its output comes as it is written */
	kMCAsyncJobKindProcess,
	/* A function of an extension's native code */
	kMCAsyncJobKindCall,
};

/* What the engine keeps for a job from its start to its last event. The
 * core is given the record's address as the job's context. */
struct MCAsyncJobRecord
{
	MCAsyncJobRecord *next = nullptr;
	MCAsyncJobRecord *previous = nullptr;

	MCAsyncJobId job = 0;
	MCAsyncJobKind kind = kMCAsyncJobKindRead;

	/* The object whose script started the job, which gets its messages,
	 * and the name of the message */
	MCObjectHandle target;
	MCNameRef message = nullptr;

	/* The bytes of a write, which the core reads on its thread without a
	 * copy: kept until the job is over */
	MCDataRef borrowed = nullptr;
};

/* Every job that has not had its last event, newest first. The main
 * thread's, as is everything in this file but MCAsyncWake. */
static MCAsyncJobRecord *s_jobs = nullptr;

/* Set by the wake: the core has events to drain. It is what tells the
 * engine where no notification can be posted (in a browser, or while the
 * engine starts or quits): the next call of the library drains then. */
static std::atomic<bool> s_drain_wanted(false);

/* When the messages of the drain under way are due: now, or the time that
 * the pass of the wait which fetches them is working to, so that it
 * delivers them itself rather than leaving them to the next pass */
static real8 s_message_time = 0.0;

static void MCAsyncRecordLink(MCAsyncJobRecord *p_record)
{
	p_record->next = s_jobs;
	p_record->previous = nullptr;
	if (s_jobs != nullptr)
		s_jobs->previous = p_record;
	s_jobs = p_record;
}

static void MCAsyncRecordUnlink(MCAsyncJobRecord *p_record)
{
	if (p_record->previous != nullptr)
		p_record->previous->next = p_record->next;
	else if (s_jobs == p_record)
		s_jobs = p_record->next;
	if (p_record->next != nullptr)
		p_record->next->previous = p_record->previous;
	p_record->next = p_record->previous = nullptr;
}

static void MCAsyncRecordDestroy(MCAsyncJobRecord *p_record)
{
	if (p_record == nullptr)
		return;
	MCValueRelease(p_record->message);
	MCValueRelease(p_record->borrowed);
	delete p_record;
}

/* What the engine keeps for a wake while it exists. The core is given the
 * record's address as the wake's context. */
struct MCAsyncWakeRecord
{
	MCAsyncWakeRecord *next = nullptr;

	MCAsyncWakeId wake = 0;

	/* The object whose script made the wake, which gets its message */
	MCObjectHandle target;
	MCNameRef message = nullptr;
};

/* Every wake there is, newest first. The main thread's. */
static MCAsyncWakeRecord *s_wakes = nullptr;

static MCAsyncWakeRecord *MCAsyncWakeRecordFind(MCAsyncWakeId p_wake)
{
	if (p_wake == 0)
		return nullptr;
	for (MCAsyncWakeRecord *t_record = s_wakes; t_record != nullptr;
	     t_record = t_record->next)
		if (t_record->wake == p_wake)
			return t_record;
	return nullptr;
}

/* End a wake: its record, and the core's wake if that is still there (a
 * signal that comes later, with the number it had, does nothing) */
static void MCAsyncWakeRecordDestroy(MCAsyncWakeRecord *p_record)
{
	if (p_record == nullptr)
		return;
	for (MCAsyncWakeRecord **t_link = &s_wakes; *t_link != nullptr;
	     t_link = &(*t_link)->next)
		if (*t_link == p_record)
		{
			*t_link = p_record->next;
			break;
		}
	if (p_record->wake != 0)
		MCAsyncCoreWakeDestroy(p_record->wake);
	MCValueRelease(p_record->message);
	delete p_record;
}

////////////////////////////////////////////////////////////////////////////////
//
//  FROM THE CORE'S EVENTS TO MESSAGES
//

/* What a script is told went wrong, in the words the engine's own file
 * commands put in the result where it has them */
static MCStringRef MCAsyncErrorText(MCAsyncError p_error, MCAsyncJobKind p_kind)
{
	switch (p_error)
	{
	case kMCAsyncErrorNone:
		return kMCEmptyString;
	case kMCAsyncErrorCancelled:
		return MCSTR("cancelled");
	case kMCAsyncErrorOutOfMemory:
		return MCSTR("out of memory");
	case kMCAsyncErrorNotSupported:
		return MCSTR("not supported");
	case kMCAsyncErrorOpen:
		return MCSTR("can't open file");
	case kMCAsyncErrorRead:
		return MCSTR("error reading file");
	case kMCAsyncErrorWrite:
		return MCSTR("error writing file");
	case kMCAsyncErrorList:
		return MCSTR("can't open folder");
	case kMCAsyncErrorSpawn:
		return p_kind == kMCAsyncJobKindShell ? MCSTR("can't run shell")
		                                      : MCSTR("can't run program");
	case kMCAsyncErrorTooLarge:
		return MCSTR("file too large");
	}
	return MCSTR("error");
}

/* The event's bytes as a Data value, which takes them where it can (the
 * core allocates with malloc, as the engine's values do) */
static bool MCAsyncEventData(MCAsyncEvent& x_event, MCDataRef& r_data)
{
	if (x_event.length == 0 || x_event.data == nullptr)
	{
		r_data = MCValueRetain(kMCEmptyData);
		return true;
	}
	if (!MCDataCreateWithBytesAndRelease(
				reinterpret_cast<byte_t *>(x_event.data),
				(uindex_t)x_event.length, r_data))
		return false;
	x_event.data = nullptr;
	return true;
}

/* The output of a shell command as shell() gives it (MCS_runcmd): the
 * bytes as native text, with line endings made line feeds where shell()
 * makes them so */
static bool MCAsyncEventShellText(const MCAsyncEvent& p_event, MCStringRef& r_text)
{
	if (p_event.length == 0 || p_event.data == nullptr)
	{
		r_text = MCValueRetain(kMCEmptyString);
		return true;
	}

	MCAutoStringRef t_text;
	if (!MCStringCreateWithNativeChars(
				reinterpret_cast<const char_t *>(p_event.data),
				(uindex_t)p_event.length, &t_text))
		return false;

#if defined(_SERVER) || defined(_WINDOWS)
	return MCStringNormalizeLineEndings(
			*t_text, kMCStringLineEndingStyleLF,
			kMCStringLineEndingOptionNormalizePSToLineEnding |
					kMCStringLineEndingOptionNormalizeLSToVT,
			r_text, nullptr);
#else
	r_text = MCValueRetain(*t_text);
	return true;
#endif
}

/* A folder's listing as text. The names are as the system gave them:
 * UTF-8, but on Linux, where they are in the encoding of the locale, as
 * the engine's own listings take them. */
static bool MCAsyncEventListingText(MCAsyncEvent& x_event, MCStringRef& r_text)
{
	if (x_event.length == 0 || x_event.data == nullptr)
	{
		r_text = MCValueRetain(kMCEmptyString);
		return true;
	}

#if defined(_LINUX)
	/* Every line of the listing ends with a line feed, which is where each
	 * name is ended for the conversion, and then put back. All of it at
	 * once first: it fails only if some name is not in the locale's
	 * encoding, and then each line is taken on its own, and such a name as
	 * native text (the engine's "files" gives up on the folder there). */
	char *t_bytes = x_event.data;
	size_t t_length = x_event.length;
	if (t_bytes[t_length - 1] != '\n')
		return false;

	t_bytes[t_length - 1] = '\0';
	MCAutoStringRef t_whole;
	bool t_converted = strlen(t_bytes) == t_length - 1 &&
			MCStringCreateWithSysString(t_bytes, &t_whole);
	t_bytes[t_length - 1] = '\n';
	if (t_converted)
		return MCStringFormat(r_text, "%@\n", *t_whole);

	MCAutoStringRef t_text;
	if (!MCStringCreateMutable(0, &t_text))
		return false;
	for (size_t t_start = 0; t_start < t_length;)
	{
		size_t t_end = t_start;
		while (t_bytes[t_end] != '\n')
			t_end += 1;

		t_bytes[t_end] = '\0';
		MCAutoStringRef t_line;
		bool t_line_converted =
				strlen(t_bytes + t_start) == t_end - t_start &&
				MCStringCreateWithSysString(t_bytes + t_start, &t_line);
		t_bytes[t_end] = '\n';
		if (!t_line_converted &&
		    !MCStringCreateWithNativeChars(
					reinterpret_cast<const char_t *>(t_bytes + t_start),
					(uindex_t)(t_end - t_start), &t_line))
			return false;

		if (!MCStringAppend(*t_text, *t_line) ||
		    !MCStringAppendChar(*t_text, '\n'))
			return false;
		t_start = t_end + 1;
	}
	return MCStringCopy(*t_text, r_text);
#else
	return MCStringCreateWithBytes(
			reinterpret_cast<const byte_t *>(x_event.data),
			(uindex_t)x_event.length, kMCStringEncodingUTF8, false, r_text);
#endif
}

/* Queue a message for an object with these parameters, as a socket's
 * message is queued: it is delivered in its turn among the pending
 * messages. False if there is no memory. */
static bool MCAsyncQueueMessage(MCObject *p_target, MCNameRef p_message,
                                MCValueRef *p_values, unsigned int p_count)
{
	MCParameter *t_first = nullptr;
	MCParameter *t_last = nullptr;
	for (unsigned int i = 0; i < p_count; i++)
	{
		MCParameter *t_parameter = new (nothrow) MCParameter;
		if (t_parameter == nullptr)
		{
			while (t_first != nullptr)
			{
				MCParameter *t_next = t_first->getnext();
				delete t_first;
				t_first = t_next;
			}
			return false;
		}
		t_parameter->setvalueref_argument(p_values[i]);
		if (t_last == nullptr)
			t_first = t_parameter;
		else
			t_last->setnext(t_parameter);
		t_last = t_parameter;
	}

	/* The queue owns the parameters from here */
	MCscreen->addmessage(p_target, p_message, s_message_time, t_first);
	return true;
}

/* The job's message, with the job's number and three more parameters */
static bool MCAsyncPostMessage(MCAsyncJobRecord *p_record, MCValueRef p_second,
                               MCValueRef p_third, MCValueRef p_fourth)
{
	MCAutoNumberRef t_job;
	if (!MCNumberCreateWithUnsignedInteger(p_record->job, &t_job))
		return false;

	MCValueRef t_values[4] = {*t_job, p_second, p_third, p_fourth};
	return MCAsyncQueueMessage(p_record->target.Get(), p_record->message,
	                           t_values, 4);
}

/* A wake's message: <message> pWake */
static bool MCAsyncPostWake(MCAsyncWakeRecord *p_record)
{
	MCAutoNumberRef t_wake;
	if (!MCNumberCreateWithUnsignedInteger(p_record->wake, &t_wake))
		return false;

	MCValueRef t_values[1] = {*t_wake};
	return MCAsyncQueueMessage(p_record->target.Get(), p_record->message,
	                           t_values, 1);
}

/* An event's message. p_event's data may be taken. */
static bool MCAsyncPostEvent(MCAsyncJobRecord *p_record, MCAsyncEvent& x_event)
{
	MCAutoNumberRef t_code;
	if (!MCNumberCreateWithUnsignedInteger(x_event.code, &t_code))
		return false;

	if (p_record->kind == kMCAsyncJobKindProcess)
	{
		/* <message> pJob, pEvent, pData, pCode */
		if (x_event.kind == kMCAsyncEventData)
		{
			MCAutoDataRef t_data;
			if (!MCAsyncEventData(x_event, &t_data))
				return false;
			return MCAsyncPostMessage(
					p_record,
					x_event.stream == 2 ? MCSTR("error") : MCSTR("output"),
					*t_data, kMCZero);
		}

		switch (x_event.error)
		{
		case kMCAsyncErrorNone:
			return MCAsyncPostMessage(p_record, MCSTR("exit"), kMCEmptyString,
			                          *t_code);
		case kMCAsyncErrorCancelled:
			return MCAsyncPostMessage(p_record, MCSTR("cancelled"),
			                          kMCEmptyString, kMCZero);
		default:
			return MCAsyncPostMessage(
					p_record, MCSTR("failed"),
					MCAsyncErrorText(x_event.error, p_record->kind), *t_code);
		}
	}

	/* <message> pJob, pResult, pError, pCode. A job of these kinds has one
	 * event, its last. */
	if (x_event.kind != kMCAsyncEventDone)
		return true;

	MCAutoValueRef t_result;
	switch (p_record->kind)
	{
	case kMCAsyncJobKindRead:
	{
		MCAutoDataRef t_data;
		if (!MCAsyncEventData(x_event, &t_data))
			return false;
		t_result = *t_data;
		break;
	}
	case kMCAsyncJobKindList:
	{
		MCAutoStringRef t_text;
		if (!MCAsyncEventListingText(x_event, &t_text))
			return false;
		t_result = *t_text;
		break;
	}
	case kMCAsyncJobKindShell:
	{
		MCAutoStringRef t_text;
		if (!MCAsyncEventShellText(x_event, &t_text))
			return false;
		t_result = *t_text;
		break;
	}
	default:
		t_result = kMCEmptyString;
		break;
	}

	return MCAsyncPostMessage(p_record, *t_result,
	                          MCAsyncErrorText(x_event.error, p_record->kind),
	                          *t_code);
}

/* One event of the core, on the main thread */
static void MCAsyncHandleEvent(void *p_context, MCAsyncEvent& x_event)
{
	bool *t_posted = static_cast<bool *>(p_context);

	if (x_event.kind == kMCAsyncEventWake)
	{
		MCAsyncWakeRecord *t_wake =
				static_cast<MCAsyncWakeRecord *>(x_event.context);
		if (t_wake == nullptr)
			return;

		/* An object that has been deleted has no use for its wakes: the
		 * first signal after that ends the wake */
		if (!t_wake->target.IsValid())
			MCAsyncWakeRecordDestroy(t_wake);
		else if (MCscreen != nullptr)
		{
			if (MCAsyncPostWake(t_wake))
				*t_posted = true;
			else
				MCErrorReset();
		}
		return;
	}

	MCAsyncJobRecord *t_record =
			static_cast<MCAsyncJobRecord *>(x_event.context);
	if (t_record == nullptr)
		return;

	/* An object that has been deleted has no messages coming: what its
	 * jobs still give is dropped, as its pending messages were */
	if (t_record->target.IsValid() && MCscreen != nullptr)
	{
		/* Not having the memory for a message means it is not sent: there
		 * is no one to tell. The error that says so must not stay for the
		 * next handler to trip over. */
		if (MCAsyncPostEvent(t_record, x_event))
			*t_posted = true;
		else
			MCErrorReset();
	}

	if (x_event.kind == kMCAsyncEventDone)
	{
		MCAsyncRecordUnlink(t_record);
		MCAsyncRecordDestroy(t_record);
	}
}

/* Turn what the core has queued into pending messages, due at p_time.
 * True if there were any. */
static bool MCAsyncDrainAt(real8 p_time)
{
	/* Before the drain: a wake that comes during it sets it again */
	s_drain_wanted.store(false);

	bool t_posted = false;
	s_message_time = p_time;
	MCAsyncCoreDrain(MCAsyncHandleEvent, &t_posted);
	return t_posted;
}

/* The same, outside a wait's own pass: the messages are due now */
static void MCAsyncDrain(void)
{
	/* A wait that is under way has worked out how long to sleep without
	 * these messages: have it look again (what LCB's "post" does) */
	if (MCAsyncDrainAt(MCS_time()))
		MCEngineRunloopBreakWait();
}

/* Each pass of a wait, before it handles the pending messages that are due
 * at p_time: what the jobs have ended with since the last pass joins them.
 * One read of a flag when there is nothing, which is nearly always. The
 * wait works out how long to sleep after this, so it needs no waking. */
void MCAsyncPostPending(double p_time)
{
	if (s_drain_wanted.load(std::memory_order_relaxed))
		MCAsyncDrainAt(p_time);
}

#if defined(FEATURE_NOTIFY)
static void MCAsyncDrainNotification(void *)
{
	MCAsyncDrain();
}
#endif

/* The core's wake. ON ANY THREAD, with the core's lock held: only what is
 * safe there. Posting a notification is (it is how a socket's thread
 * reaches the engine), while the notifications exist: MCAsyncFinalize ends
 * the wakes before they are finalized. "Safe": it runs where a script may. */
static void MCAsyncWake(void *)
{
	s_drain_wanted.store(true);
#if defined(_ANDROID_MOBILE)
	/* The notification wakes the engine through Java, which a thread Java
	 * does not know cannot call. The jobs' threads are known to it, and
	 * MCAsyncNativeWakeSignal sees that an extension's is; if it could not,
	 * the flag is left for the engine to find when it next looks. */
	if (MCJavaGetThreadEnv() == nil)
		return;
#endif
#if defined(FEATURE_NOTIFY)
	if (MCNotifyIsInitialized())
		MCNotifyPush(MCAsyncDrainNotification, nullptr, false, true);
#endif
}

#if defined(_ANDROID_MOBILE)
/* A thread that posts a notification on Android wakes the engine through
 * Java, so it has to be known to the Java machine while it runs */
static void MCAsyncThreadStartedOrEnding(bool p_starting)
{
	if (p_starting)
		MCJavaAttachCurrentThread();
	else
		MCJavaDetachCurrentThread();
}
#endif

////////////////////////////////////////////////////////////////////////////////
//
//  STARTING AND STOPPING
//

static bool MCAsyncThrow(const char *p_handler, const char *p_reason)
{
	MCAutoStringRef t_message;
	if (!MCStringFormat(&t_message, "%s: %s", p_handler, p_reason))
		return false;
	return MCErrorThrowGeneric(*t_message);
}

static bool MCAsyncEnsureStarted(void)
{
	if (MCAsyncCoreIsInitialized())
		return true;

	MCAsyncThreadCallback t_thread_callback = nullptr;
#if defined(_ANDROID_MOBILE)
	t_thread_callback = MCAsyncThreadStartedOrEnding;
#endif
	return MCAsyncCoreInitialize(MCAsyncWake, nullptr, t_thread_callback);
}

/* What a call of the library does once its own work is done: where no
 * notification brings the events (see s_drain_wanted), they are fetched
 * here. In a browser a file job has run inside the call that started it,
 * so its message is queued before that call returns. */
static void MCAsyncDrainIfWanted(void)
{
	if (s_drain_wanted.load())
		MCAsyncDrain();
}

void MCAsyncFinalize(void)
{
	if (!MCAsyncCoreIsInitialized())
		return;

	/* What scripts gave to be written is written; the rest is dropped */
	MCAsyncCoreFinishWrites(kMCAsyncQuitWriteWaitMs);
	bool t_ended = MCAsyncCoreFinalize(kMCAsyncQuitThreadWaitMs);
	s_drain_wanted.store(false);

	while (s_jobs != nullptr)
	{
		MCAsyncJobRecord *t_record = s_jobs;
		MCAsyncRecordUnlink(t_record);
		/* A thread the system has not let go may still be reading the
		 * bytes it was given: they stay, for the little time that is left */
		if (!t_ended)
			t_record->borrowed = nullptr;
		MCAsyncRecordDestroy(t_record);
	}

	/* The core has destroyed its wakes: a thread that signals one now, or
	 * at any time after, does nothing */
	while (s_wakes != nullptr)
		MCAsyncWakeRecordDestroy(s_wakes);
}

/* The object that gets the messages of a job started now: the one whose
 * script is running ("me" in the handler that called the library) */
static MCObject *MCAsyncCallerObject(void)
{
	extern MCExecContext *MCECptr;
	if (MCECptr != nullptr && MCECptr->GetObject() != nullptr)
		return MCECptr->GetObject();

	/* Not from a script (a widget's own code): as LCB's "post" chooses.
	 * Throws if there is none. */
	return MCEngineCurrentContextObject();
}

enum MCAsyncAccess
{
	kMCAsyncAccessDisk,
	kMCAsyncAccessProcess,
	/* Nothing a secure mode refuses: a function of code already loaded */
	kMCAsyncAccessNone,
};

/* The first half of starting a job: the checks, and the record. nullptr
 * with an error thrown. */
static MCAsyncJobRecord *MCAsyncBegin(const char *p_handler,
                                      MCAsyncJobKind p_kind,
                                      MCAsyncAccess p_access,
                                      MCStringRef p_message)
{
	/* As the engine's own commands are refused in a secure mode */
	if (p_access == kMCAsyncAccessDisk && !MCSecureModeCanAccessDisk())
	{
		MCAsyncThrow(p_handler, "disk access is not allowed");
		return nullptr;
	}
	if (p_access == kMCAsyncAccessProcess &&
	    (MCsecuremode & MC_SECUREMODE_PROCESS) != 0)
	{
		MCAsyncThrow(p_handler, "running a process is not allowed");
		return nullptr;
	}

	if (MCStringIsEmpty(p_message))
	{
		MCAsyncThrow(p_handler, "no message to send when the job is done");
		return nullptr;
	}

	MCObject *t_target = MCAsyncCallerObject();
	if (t_target == nullptr)
		return nullptr;

	if (!MCAsyncEnsureStarted())
	{
		MCAsyncThrow(p_handler, "out of memory");
		return nullptr;
	}

	MCAsyncJobRecord *t_record = new (nothrow) MCAsyncJobRecord;
	if (t_record == nullptr || !MCNameCreate(p_message, t_record->message))
	{
		MCAsyncRecordDestroy(t_record);
		MCErrorReset();
		MCAsyncThrow(p_handler, "out of memory");
		return nullptr;
	}
	t_record->kind = p_kind;
	t_record->target = t_target->GetHandle();
	return t_record;
}

/* Give up a job that was begun and not started, with an error thrown */
static uint32_t MCAsyncAbandon(MCAsyncJobRecord *p_record, const char *p_handler,
                               const char *p_reason)
{
	MCAsyncRecordDestroy(p_record);
	MCErrorReset();
	MCAsyncThrow(p_handler, p_reason);
	return 0;
}

/* The second half: p_job is what the core returned for the job */
static uint32_t MCAsyncStarted(MCAsyncJobRecord *p_record, const char *p_handler,
                               MCAsyncJobId p_job)
{
	if (p_job == 0)
		return MCAsyncAbandon(p_record, p_handler, "out of memory");

	p_record->job = p_job;
	MCAsyncRecordLink(p_record);
	MCAsyncDrainIfWanted();
	return p_job;
}

////////////////////////////////////////////////////////////////////////////////
//
//  PATHS AND STRINGS FOR THE SYSTEM
//

/* A string as the bytes the core takes: UTF-8 on Windows (it converts
 * them), on macOS and on Android, and the encoding of the locale elsewhere;
 * as the engine's own file code gives the system its paths on each. */
#if defined(_WINDOWS) || defined(_MACOSX) || defined(_ANDROID_MOBILE)
typedef MCAutoStringRefAsUTF8String MCAsyncSystemString;
#else
typedef MCAutoStringRefAsSysString MCAsyncSystemString;
#endif

enum MCAsyncPathUse
{
	kMCAsyncPathRead,
	kMCAsyncPathWrite,
	kMCAsyncPathFolder,
};

/* A path of a script as the system takes it, as MCS_loadbinaryfile makes
 * one: absolute (the job runs later, when the defaultFolder may be
 * another), and in the system's own form */
static bool MCAsyncResolvePath(MCStringRef p_path, MCAsyncPathUse p_use,
                               MCStringRef& r_native)
{
	MCAutoStringRef t_resolved;
	MCAutoStringRef t_native;
	if (!MCS_resolvepath(p_path, &t_resolved) ||
	    !MCS_pathtonative(*t_resolved, &t_native))
		return false;

#if defined(_MACOSX)
	/* A file that an application's script looks for beside its engine is
	 * in the bundle's Resources/_MacOS (dskmac.cpp): reading finds it
	 * there, as opening a file to read does */
	extern bool MCS_apply_redirect(MCStringRef p_path, bool p_is_file,
	                               MCStringRef& r_redirected);
	MCAutoStringRef t_redirected;
	if (p_use == kMCAsyncPathRead &&
	    MCS_apply_redirect(*t_native, true, &t_redirected))
	{
		r_native = MCValueRetain(*t_redirected);
		return true;
	}
#endif

	r_native = MCValueRetain(*t_native);
	return true;
}

/* A list of strings for the system, ended by nullptr: a program's
 * arguments */
class MCAsyncArguments
{
public:
	MCAsyncArguments() = default;

	~MCAsyncArguments()
	{
		for (uindex_t i = 0; i < m_count; i++)
			free(m_strings[i]);
		free(m_strings);
	}

	bool Append(MCStringRef p_string)
	{
		/* (An empty string has no bytes to lock) */
		char *t_copy;
		if (MCStringIsEmpty(p_string))
			t_copy = strdup("");
		else
		{
			MCAsyncSystemString t_bytes;
			if (!t_bytes.Lock(p_string))
				return false;
			t_copy = strdup(*t_bytes);
		}
		if (t_copy == nullptr)
			return false;

		char **t_grown = static_cast<char **>(
				realloc(m_strings, (m_count + 2) * sizeof(char *)));
		if (t_grown == nullptr)
		{
			free(t_copy);
			return false;
		}
		m_strings = t_grown;
		m_strings[m_count++] = t_copy;
		m_strings[m_count] = nullptr;
		return true;
	}

	const char *const *Ptr(void) const
	{
		return m_strings;
	}

private:
	char **m_strings = nullptr;
	uindex_t m_count = 0;
};

/* The arguments a script gave for a program, as a list of strings: an
 * array with the keys 1 to N (or the List that such an array arrives as),
 * or text with an argument on each line. Empty is none. */
static bool MCAsyncArgumentList(MCValueRef p_arguments, MCProperListRef& r_list,
                                const char *& r_wrong)
{
	MCAutoProperListRef t_list;
	if (!MCProperListCreateMutable(&t_list))
		return false;

	MCExecContext ctxt(nil, nil, nil);

	if (p_arguments == nullptr ||
	    MCValueGetTypeCode(p_arguments) == kMCValueTypeCodeNull)
	{
		/* none */
	}
	else if (MCValueGetTypeCode(p_arguments) == kMCValueTypeCodeArray ||
	         MCValueGetTypeCode(p_arguments) == kMCValueTypeCodeProperList)
	{
		bool t_is_array =
				MCValueGetTypeCode(p_arguments) == kMCValueTypeCodeArray;
		uindex_t t_count;
		if (t_is_array)
		{
			MCArrayRef t_array = static_cast<MCArrayRef>(p_arguments);
			t_count = MCArrayGetCount(t_array);
			if (t_count != 0 && !MCArrayIsSequence(t_array))
			{
				r_wrong = "the arguments are not an array with the keys 1 to N";
				return false;
			}
		}
		else
			t_count = MCProperListGetLength(
					static_cast<MCProperListRef>(p_arguments));

		for (uindex_t i = 0; i < t_count; i++)
		{
			MCValueRef t_element = nullptr;
			if (t_is_array)
			{
				if (!MCArrayFetchValueAtIndex(
							static_cast<MCArrayRef>(p_arguments),
							(index_t)(i + 1), t_element))
				{
					r_wrong = "the arguments are not an array with the keys 1 to N";
					return false;
				}
			}
			else
				t_element = MCProperListFetchElementAtIndex(
						static_cast<MCProperListRef>(p_arguments), i);

			MCValueTypeCode t_code = MCValueGetTypeCode(t_element);
			if (t_code == kMCValueTypeCodeArray ||
			    t_code == kMCValueTypeCodeProperList)
			{
				r_wrong = "an argument is an array";
				return false;
			}

			MCAutoStringRef t_string;
			if (!ctxt.ConvertToString(t_element, &t_string) ||
			    !MCProperListPushElementOntoBack(*t_list, *t_string))
				return false;
		}
	}
	else
	{
		MCAutoStringRef t_text;
		if (!ctxt.ConvertToString(p_arguments, &t_text))
			return false;

		/* As the lines of a chunk expression: a line feed at the very end
		 * ends the last line and starts no other */
		uindex_t t_length = MCStringGetLength(*t_text);
		if (t_length != 0 && MCStringGetCharAtIndex(*t_text, t_length - 1) == '\n')
			t_length -= 1;
		for (uindex_t t_start = 0; t_start <= t_length && t_length != 0;)
		{
			uindex_t t_end;
			if (!MCStringFirstIndexOfChar(*t_text, '\n', t_start,
			                              kMCStringOptionCompareExact, t_end) ||
			    t_end > t_length)
				t_end = t_length;

			MCAutoStringRef t_line;
			if (!MCStringCopySubstring(*t_text,
			                           MCRangeMakeMinMax(t_start, t_end),
			                           &t_line) ||
			    !MCProperListPushElementOntoBack(*t_list, *t_line))
				return false;
			t_start = t_end + 1;
		}
	}

	return MCProperListCopy(*t_list, r_list);
}

#if defined(_WINDOWS)
/* Add an argument to a command line so that the program's runtime gives it
 * back as it is here (the rules of CommandLineToArgvW: an argument with a
 * space or a quote in it goes in quotes, and a backslash counts only
 * before a quote) */
static bool MCAsyncAppendQuotedArgument(MCStringRef x_line, MCStringRef p_argument)
{
	uindex_t t_length = MCStringGetLength(p_argument);
	bool t_plain = t_length != 0;
	for (uindex_t i = 0; i < t_length && t_plain; i++)
	{
		unichar_t t_char = MCStringGetCharAtIndex(p_argument, i);
		t_plain = t_char != ' ' && t_char != '\t' && t_char != '\n' &&
				t_char != '\v' && t_char != '"';
	}
	if (t_plain)
		return MCStringAppend(x_line, p_argument);

	if (!MCStringAppendChar(x_line, '"'))
		return false;
	for (uindex_t i = 0;; i++)
	{
		uindex_t t_backslashes = 0;
		while (i < t_length && MCStringGetCharAtIndex(p_argument, i) == '\\')
		{
			i += 1;
			t_backslashes += 1;
		}

		/* Before the quote that ends the argument, or one inside it, each
		 * backslash is doubled so that the quote stays what it is */
		if (i == t_length)
			t_backslashes *= 2;
		else if (MCStringGetCharAtIndex(p_argument, i) == '"')
			t_backslashes = t_backslashes * 2 + 1;
		for (uindex_t j = 0; j < t_backslashes; j++)
			if (!MCStringAppendChar(x_line, '\\'))
				return false;

		if (i == t_length)
			break;
		if (!MCStringAppendChar(x_line, MCStringGetCharAtIndex(p_argument, i)))
			return false;
	}
	return MCStringAppendChar(x_line, '"');
}
#endif

/* A job's number from what a script passed for it. 0, which is no job, for
 * anything that is not the number of one: a variable still empty because
 * no job was started is not an error to cancel. */
static MCAsyncJobId MCAsyncJobFromValue(MCValueRef p_value)
{
	if (p_value == nullptr)
		return 0;

	real64_t t_number = 0.0;
	if (MCValueGetTypeCode(p_value) == kMCValueTypeCodeNumber)
		t_number = MCNumberFetchAsReal(static_cast<MCNumberRef>(p_value));
	else if (MCValueGetTypeCode(p_value) == kMCValueTypeCodeString ||
	         MCValueGetTypeCode(p_value) == kMCValueTypeCodeName ||
	         MCValueGetTypeCode(p_value) == kMCValueTypeCodeData)
	{
		MCExecContext ctxt(nil, nil, nil);
		MCAutoStringRef t_string;
		if (!ctxt.ConvertToString(p_value, &t_string) ||
		    !MCU_stor8(*t_string, t_number))
		{
			MCErrorReset();
			return 0;
		}
	}
	else
		return 0;

	if (!(t_number >= 1.0 && t_number <= 4294967295.0) ||
	    t_number != (real64_t)(MCAsyncJobId)t_number)
		return 0;
	return (MCAsyncJobId)t_number;
}

////////////////////////////////////////////////////////////////////////////////
//
//  WHAT THE LIBRARY BINDS TO
//

extern "C" MC_DLLEXPORT_DEF uint32_t MCAsyncJobsReadFile(MCStringRef p_path, MCStringRef p_message)
{
	static const char *kHandler = "asyncReadFile";
	MCAsyncJobRecord *t_record = MCAsyncBegin(
			kHandler, kMCAsyncJobKindRead, kMCAsyncAccessDisk, p_message);
	if (t_record == nullptr)
		return 0;

	MCAutoStringRef t_native;
	MCAsyncSystemString t_path;
	if (!MCAsyncResolvePath(p_path, kMCAsyncPathRead, &t_native) ||
	    !t_path.Lock(*t_native))
		return MCAsyncAbandon(t_record, kHandler, "can't use that path");

	return MCAsyncStarted(t_record, kHandler,
	                      MCAsyncCoreReadFile(*t_path, t_record));
}

extern "C" MC_DLLEXPORT_DEF uint32_t MCAsyncJobsWriteFile(MCStringRef p_path, MCDataRef p_data, bool p_append, MCStringRef p_message)
{
	const char *t_handler = p_append ? "asyncAppendFile" : "asyncWriteFile";
	MCAsyncJobRecord *t_record = MCAsyncBegin(
			t_handler, kMCAsyncJobKindWrite, kMCAsyncAccessDisk, p_message);
	if (t_record == nullptr)
		return 0;

	MCAutoStringRef t_native;
	MCAsyncSystemString t_path;
	if (!MCAsyncResolvePath(p_path, kMCAsyncPathWrite, &t_native) ||
	    !t_path.Lock(*t_native))
		return MCAsyncAbandon(t_record, t_handler, "can't use that path");

	/* The job's thread reads the value's own bytes: a copy that nothing
	 * can change, which for a value that nothing can change is the value */
	if (!MCDataCopy(p_data, t_record->borrowed))
		return MCAsyncAbandon(t_record, t_handler, "out of memory");

	return MCAsyncStarted(
			t_record, t_handler,
			MCAsyncCoreWriteFile(*t_path, MCDataGetBytePtr(t_record->borrowed),
			                     MCDataGetLength(t_record->borrowed), p_append,
			                     t_record));
}

extern "C" MC_DLLEXPORT_DEF uint32_t MCAsyncJobsCopyFile(MCStringRef p_from, MCStringRef p_to, MCStringRef p_message)
{
	static const char *kHandler = "asyncCopyFile";
	MCAsyncJobRecord *t_record = MCAsyncBegin(
			kHandler, kMCAsyncJobKindCopy, kMCAsyncAccessDisk, p_message);
	if (t_record == nullptr)
		return 0;

	MCAutoStringRef t_native_from;
	MCAutoStringRef t_native_to;
	MCAsyncSystemString t_from;
	MCAsyncSystemString t_to;
	if (!MCAsyncResolvePath(p_from, kMCAsyncPathRead, &t_native_from) ||
	    !MCAsyncResolvePath(p_to, kMCAsyncPathWrite, &t_native_to) ||
	    !t_from.Lock(*t_native_from) || !t_to.Lock(*t_native_to))
		return MCAsyncAbandon(t_record, kHandler, "can't use that path");

	return MCAsyncStarted(t_record, kHandler,
	                      MCAsyncCoreCopyFile(*t_from, *t_to, t_record));
}

extern "C" MC_DLLEXPORT_DEF uint32_t MCAsyncJobsListFolder(MCStringRef p_path, bool p_recursive, MCStringRef p_message)
{
	static const char *kHandler = "asyncListFolder";
	MCAsyncJobRecord *t_record = MCAsyncBegin(
			kHandler, kMCAsyncJobKindList, kMCAsyncAccessDisk, p_message);
	if (t_record == nullptr)
		return 0;

	MCAutoStringRef t_native;
	MCAsyncSystemString t_path;
	if (!MCAsyncResolvePath(p_path, kMCAsyncPathFolder, &t_native) ||
	    !t_path.Lock(*t_native))
		return MCAsyncAbandon(t_record, kHandler, "can't use that path");

	return MCAsyncStarted(
			t_record, kHandler,
			MCAsyncCoreListFolder(*t_path, p_recursive, t_record));
}

/* The command is run as shell() runs one on each system (dsklnx.cpp,
 * dskmac.cpp, dskw32.cpp), so that a script can change one call for the
 * other: by the shellCommand, which is given the command on its input (on
 * Windows, after "/C"), with its error output joined to its output. */
extern "C" MC_DLLEXPORT_DEF uint32_t MCAsyncJobsShell(MCStringRef p_command, MCStringRef p_message)
{
	static const char *kHandler = "asyncShell";
	MCAsyncJobRecord *t_record = MCAsyncBegin(
			kHandler, kMCAsyncJobKindShell, kMCAsyncAccessProcess, p_message);
	if (t_record == nullptr)
		return 0;

	/* Where no program can be run (Android, iOS, a browser) there is no
	 * shellCommand either: the job's message says "not supported", as the
	 * core's does for a program there (asyncProcessOpen), rather than the
	 * call failing with an error */
	if (MCStringIsEmpty(MCshellcmd) && MCAsyncCoreCanStartProcesses())
		return MCAsyncAbandon(t_record, kHandler, "no shell");

	MCAsyncProcessOptions t_options;
	memset(&t_options, 0, sizeof(t_options));
	t_options.close_input = true;
	t_options.merge_error = true;
	t_options.stream = false;

#if defined(_WINDOWS)
	MCAutoStringRef t_line;
	MCAsyncSystemString t_line_bytes;
	if (!MCStringFormat(&t_line, "%@ /C \"%@\"", MCshellcmd, p_command) ||
	    !t_line_bytes.Lock(*t_line))
		return MCAsyncAbandon(t_record, kHandler, "out of memory");

	t_options.command_line = *t_line_bytes;
	t_options.creation_flags = kMCAsyncCreateNewConsole;
	t_options.hide_window = MChidewindows == True;
#else
	MCAsyncSystemString t_shell;
	MCAutoStringRef t_input;
	MCAsyncSystemString t_input_bytes;
	if (!t_shell.Lock(MCshellcmd) ||
	    !MCStringFormat(&t_input, "%@\n", p_command) ||
	    !t_input_bytes.Lock(*t_input))
		return MCAsyncAbandon(t_record, kHandler, "out of memory");

	const char *t_arguments[3] = {*t_shell, "-s", nullptr};
	t_options.arguments = t_arguments;
	t_options.input = *t_input_bytes;
	t_options.input_length = strlen(*t_input_bytes);
#endif

	return MCAsyncStarted(t_record, kHandler,
	                      MCAsyncCoreStartProcess(t_options, t_record));
}

extern "C" MC_DLLEXPORT_DEF uint32_t MCAsyncJobsProcessOpen(MCStringRef p_program, MCValueRef p_arguments, MCStringRef p_message)
{
	static const char *kHandler = "asyncProcessOpen";
	MCAsyncJobRecord *t_record = MCAsyncBegin(
			kHandler, kMCAsyncJobKindProcess, kMCAsyncAccessProcess, p_message);
	if (t_record == nullptr)
		return 0;

	if (MCStringIsEmpty(p_program))
		return MCAsyncAbandon(t_record, kHandler, "no program");

	MCAutoProperListRef t_list;
	const char *t_wrong = nullptr;
	if (!MCAsyncArgumentList(p_arguments, &t_list, t_wrong))
		return MCAsyncAbandon(t_record, kHandler,
		                      t_wrong != nullptr ? t_wrong : "out of memory");

	/* A program named with a folder is a path as a script writes one. A
	 * bare name is looked for by the system, in PATH. */
	MCAutoStringRef t_program;
	uindex_t t_slash;
	if (MCStringFirstIndexOfChar(p_program, '/', 0, kMCStringOptionCompareExact,
	                             t_slash))
	{
		if (!MCAsyncResolvePath(p_program, kMCAsyncPathWrite, &t_program))
			return MCAsyncAbandon(t_record, kHandler, "can't use that path");
	}
	else
		t_program = p_program;

	MCAsyncProcessOptions t_options;
	memset(&t_options, 0, sizeof(t_options));
	t_options.stream = true;

#if defined(_WINDOWS)
	/* Windows runs a batch file by handing the whole command line to
	 * cmd.exe, which reads it by rules of its own that no quoting here
	 * can make safe: an argument could become a command */
	if (MCStringEndsWithCString(*t_program, (const char_t *)".bat",
	                            kMCStringOptionCompareCaseless) ||
	    MCStringEndsWithCString(*t_program, (const char_t *)".cmd",
	                            kMCStringOptionCompareCaseless))
		return MCAsyncAbandon(t_record, kHandler,
		                      "a batch file is run with asyncShell");
	uindex_t t_quote;
	if (MCStringFirstIndexOfChar(*t_program, '"', 0,
	                             kMCStringOptionCompareExact, t_quote))
		return MCAsyncAbandon(t_record, kHandler, "can't use that path");

	MCAutoStringRef t_line;
	if (!MCStringCreateMutable(0, &t_line) ||
	    !MCStringAppendChar(*t_line, '"') ||
	    !MCStringAppend(*t_line, *t_program) ||
	    !MCStringAppendChar(*t_line, '"'))
		return MCAsyncAbandon(t_record, kHandler, "out of memory");
	for (uindex_t i = 0; i < MCProperListGetLength(*t_list); i++)
		if (!MCStringAppendChar(*t_line, ' ') ||
		    !MCAsyncAppendQuotedArgument(
					*t_line, static_cast<MCStringRef>(
									 MCProperListFetchElementAtIndex(*t_list, i))))
			return MCAsyncAbandon(t_record, kHandler, "out of memory");

	MCAsyncSystemString t_line_bytes;
	if (!t_line_bytes.Lock(*t_line))
		return MCAsyncAbandon(t_record, kHandler, "out of memory");

	/* As "open process" starts a program: in a console of its own, which
	 * the hideConsoleWindows hides */
	t_options.command_line = *t_line_bytes;
	t_options.creation_flags = kMCAsyncCreateNewConsole;
	t_options.hide_window = MChidewindows == True;
#else
	MCAsyncArguments t_arguments;
	if (!t_arguments.Append(*t_program))
		return MCAsyncAbandon(t_record, kHandler, "out of memory");
	for (uindex_t i = 0; i < MCProperListGetLength(*t_list); i++)
		if (!t_arguments.Append(static_cast<MCStringRef>(
					MCProperListFetchElementAtIndex(*t_list, i))))
			return MCAsyncAbandon(t_record, kHandler, "out of memory");
	t_options.arguments = t_arguments.Ptr();
#endif

	return MCAsyncStarted(t_record, kHandler,
	                      MCAsyncCoreStartProcess(t_options, t_record));
}

extern "C" MC_DLLEXPORT_DEF bool MCAsyncJobsProcessWrite(MCValueRef p_job, MCDataRef p_data)
{
	bool t_written = MCAsyncCoreProcessWrite(
			MCAsyncJobFromValue(p_job), MCDataGetBytePtr(p_data),
			MCDataGetLength(p_data));
	MCAsyncDrainIfWanted();
	return t_written;
}

extern "C" MC_DLLEXPORT_DEF bool MCAsyncJobsProcessCloseInput(MCValueRef p_job)
{
	bool t_closed = MCAsyncCoreProcessCloseInput(MCAsyncJobFromValue(p_job));
	MCAsyncDrainIfWanted();
	return t_closed;
}

extern "C" MC_DLLEXPORT_DEF bool MCAsyncJobsCancel(MCValueRef p_job)
{
	bool t_cancelled = MCAsyncCoreCancel(MCAsyncJobFromValue(p_job));
	MCAsyncDrainIfWanted();
	return t_cancelled;
}

/* A Background Workers worker asks to end as soon as the process that
 * started it does, however that ends (see MCAsyncCoreEndWithParent). The
 * number is a process's, read as a job's number is. */
extern "C" MC_DLLEXPORT_DEF bool MCAsyncJobsEndWithParent(MCValueRef p_parent)
{
	MCAsyncJobId t_parent = MCAsyncJobFromValue(p_parent);
	if (t_parent == 0)
		return false;
	return MCAsyncCoreEndWithParent(t_parent);
}

/* A worker of the Background Workers library is the engine started with
 * OXT_WORKER set to 1 and OXT_WORKER_PARENT to the process that started
 * it, and ends with that process from the start (X_open calls this),
 * whether or not the worker loads the Background Jobs library, which a
 * worker started from a stack on the desktop does not: asyncEndWithParent
 * then never ran, and a busy worker outlived a stack that crashed or was
 * killed. Nothing else sets the two, so no other engine notices. */
void MCAsyncEndWithParentIfWorker(void)
{
	const char *t_worker = getenv("OXT_WORKER");
	const char *t_parent = getenv("OXT_WORKER_PARENT");
	if (t_worker == nullptr || strcmp(t_worker, "1") != 0 ||
	    t_parent == nullptr || *t_parent == '\0')
		return;
	char *t_end = nullptr;
	unsigned long long t_number = strtoull(t_parent, &t_end, 10);
	if (t_end == t_parent || *t_end != '\0' || t_number == 0)
		return;
	MCAsyncCoreEndWithParent(static_cast<uint64_t>(t_number));
}

extern "C" MC_DLLEXPORT_DEF void MCAsyncJobsStatus(MCValueRef p_job, MCStringRef& r_status)
{
	MCAsyncJobId t_job = MCAsyncJobFromValue(p_job);
	MCAsyncStatus t_status = MCAsyncCoreStatus(t_job);

	/* Over, with its last event still in the core: fetched now, so that a
	 * job that is neither waiting nor running has its last message queued
	 * (or has had it), which is all a script needs to tell apart */
	if (t_status == kMCAsyncStatusFinished)
	{
		MCAsyncDrain();
		t_status = MCAsyncCoreStatus(t_job);
	}
	else
		MCAsyncDrainIfWanted();

	switch (t_status)
	{
	case kMCAsyncStatusQueued:
		r_status = MCValueRetain(MCSTR("queued"));
		break;
	case kMCAsyncStatusRunning:
		r_status = MCValueRetain(MCSTR("running"));
		break;
	default:
		r_status = MCValueRetain(kMCEmptyString);
		break;
	}
}

extern "C" MC_DLLEXPORT_DEF void MCAsyncJobsProgress(MCValueRef p_job, MCStringRef& r_progress)
{
	MCAsyncDrainIfWanted();
	uint64_t t_done = 0;
	uint64_t t_total = 0;
	if (!MCAsyncCoreProgress(MCAsyncJobFromValue(p_job), t_done, t_total) ||
	    !MCStringFormat(r_progress, "%llu,%llu", (unsigned long long)t_done,
	                    (unsigned long long)t_total))
	{
		MCErrorReset();
		r_progress = MCValueRetain(kMCEmptyString);
	}
}

/* The numbers of the jobs that have not had their last message queued, one
 * to a line, oldest first */
extern "C" MC_DLLEXPORT_DEF void MCAsyncJobsList(MCStringRef& r_jobs)
{
	MCAsyncDrainIfWanted();

	MCAutoStringRef t_jobs;
	bool t_success = MCStringCreateMutable(0, &t_jobs);

	MCAsyncJobRecord *t_oldest = s_jobs;
	while (t_oldest != nullptr && t_oldest->next != nullptr)
		t_oldest = t_oldest->next;
	for (MCAsyncJobRecord *t_record = t_oldest;
	     t_success && t_record != nullptr; t_record = t_record->previous)
		t_success = MCStringAppendFormat(
				*t_jobs, t_record->previous != nullptr ? "%u\n" : "%u",
				(unsigned int)t_record->job);

	if (!t_success || !MCStringCopy(*t_jobs, r_jobs))
	{
		MCErrorReset();
		r_jobs = MCValueRetain(kMCEmptyString);
	}
}

////////////////////////////////////////////////////////////////////////////////
//
//  WHAT AN EXTENSION WITH NATIVE CODE BINDS TO
//
// For an extension whose native code would otherwise hold the engine up, or
// has threads of its own. Bound by name with "<builtin>", as the functions
// above are; on the main thread, bar MCAsyncNativeWakeSignal.

/* Call a function of native code, void (*)(void *), with p_context on
 * another thread. The object whose script is running is sent
 * "<message> pJob, empty, pError, 0" when it has returned (pError is
 * "cancelled" if the call was cancelled before it was made, or else empty).
 * Returns the job's number, which the library's asyncCancel and asyncStatus
 * take, or 0 with an error thrown.
 *
 * The function must not touch the engine: no value, no handler, no call of
 * the engine but MCAsyncNativeWakeSignal. What p_context points to must stay
 * until the message. In a browser, where there are no threads, the function
 * is called before this returns. */
extern "C" MC_DLLEXPORT_DEF uint32_t MCAsyncNativeCall(void *p_function, void *p_context, MCStringRef p_message)
{
	static const char *kHandler = "MCAsyncNativeCall";
	if (p_function == nullptr)
	{
		MCAsyncThrow(kHandler, "no function to call");
		return 0;
	}

	MCAsyncJobRecord *t_record = MCAsyncBegin(
			kHandler, kMCAsyncJobKindCall, kMCAsyncAccessNone, p_message);
	if (t_record == nullptr)
		return 0;

	return MCAsyncStarted(
			t_record, kHandler,
			MCAsyncCoreCall(reinterpret_cast<MCAsyncNativeFunction>(p_function),
			                p_context, t_record));
}

/* Make a wake: the object whose script is running is sent "<message> pWake"
 * after the wake has been signalled, once for however many signals came
 * since the message was last queued. Returns the wake's number (never 0), or
 * 0 with an error thrown. A wake lasts until it is deleted, its object is
 * deleted, or the engine quits. */
extern "C" MC_DLLEXPORT_DEF uint32_t MCAsyncNativeWakeCreate(MCStringRef p_message)
{
	static const char *kHandler = "MCAsyncNativeWakeCreate";
	if (MCStringIsEmpty(p_message))
	{
		MCAsyncThrow(kHandler, "no message to send when the wake is signalled");
		return 0;
	}

	MCObject *t_target = MCAsyncCallerObject();
	if (t_target == nullptr)
		return 0;

	if (!MCAsyncEnsureStarted())
	{
		MCAsyncThrow(kHandler, "out of memory");
		return 0;
	}

	MCAsyncWakeRecord *t_record = new (nothrow) MCAsyncWakeRecord;
	if (t_record == nullptr || !MCNameCreate(p_message, t_record->message))
	{
		MCAsyncWakeRecordDestroy(t_record);
		MCErrorReset();
		MCAsyncThrow(kHandler, "out of memory");
		return 0;
	}
	t_record->target = t_target->GetHandle();

	t_record->wake = MCAsyncCoreWakeCreate(t_record);
	if (t_record->wake == 0)
	{
		MCAsyncWakeRecordDestroy(t_record);
		MCAsyncThrow(kHandler, "too many wakes");
		return 0;
	}

	t_record->next = s_wakes;
	s_wakes = t_record;
	MCAsyncDrainIfWanted();
	return t_record->wake;
}

/* Delete a wake: no message of it is queued after this (one already queued
 * is still delivered), and signalling it does nothing. False if there is no
 * such wake. */
extern "C" MC_DLLEXPORT_DEF bool MCAsyncNativeWakeDelete(uint32_t p_wake)
{
	MCAsyncWakeRecord *t_record = MCAsyncWakeRecordFind(p_wake);
	if (t_record == nullptr)
		return false;
	MCAsyncWakeRecordDestroy(t_record);
	return true;
}

/* Signal a wake. ON ANY THREAD, AT ANY TIME: it is what an extension's
 * native code calls from a thread of its own, with what
 * MCAsyncNativeWakeContext gave for the wake. It takes a lock for a moment,
 * allocates nothing, waits for nothing and touches no value of the engine.
 * A wake that has been deleted, or any other pointer, does nothing. */
extern "C" MC_DLLEXPORT_DEF void MCAsyncNativeWakeSignal(void *p_wake_context)
{
	MCAsyncWakeId t_wake = static_cast<MCAsyncWakeId>(
			reinterpret_cast<uintptr_t>(p_wake_context));

#if defined(_ANDROID_MOBILE)
	/* The engine is woken through Java (MCAsyncWake), which has to know
	 * the thread for as long as that takes */
	bool t_attached = false;
	if (MCJavaGetThreadEnv() == nil)
		t_attached = MCJavaAttachCurrentThread() != nil;
#endif

	MCAsyncCoreWakeSignal(t_wake);

#if defined(_ANDROID_MOBILE)
	if (t_attached)
		MCJavaDetachCurrentThread();
#endif
}

/* The address of MCAsyncNativeWakeSignal, a void (*)(void *), for an
 * extension to give its native code: the engine's functions are found by
 * name from an extension's Builder code on every platform, and from native
 * code on few */
extern "C" MC_DLLEXPORT_DEF void *MCAsyncNativeWakeFunction(void)
{
	return reinterpret_cast<void *>(MCAsyncNativeWakeSignal);
}

/* What to call that function with to signal p_wake. Not an address:
 * nothing is to be read from it, or freed. */
extern "C" MC_DLLEXPORT_DEF void *MCAsyncNativeWakeContext(uint32_t p_wake)
{
	return reinterpret_cast<void *>(static_cast<uintptr_t>(p_wake));
}
