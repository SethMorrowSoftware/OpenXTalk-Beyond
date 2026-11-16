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

#include "prefix.h"

#include "parsedef.h"

#include "globals.h"
#include "system.h"

/* ----------------------------------------------------------------
 * Functions implemented in em-url.js
 * ---------------------------------------------------------------- */

extern "C" bool MCEmscriptenUrlLoad(const unichar_t *p_url,
                                    uint32_t p_url_length,
                                    const unichar_t *p_headers,
                                    uint32_t p_headers_length,
                                    uint32_t p_timeout,
                                    MCSystemUrlCallback p_callback,
                                    void *p_context);

typedef bool (*MCEmscriptenUrlSendFunction)(const unichar_t *p_url,
                                            uint32_t p_url_length,
                                            const unichar_t *p_headers,
                                            uint32_t p_headers_length,
                                            const byte_t *p_data,
                                            uint32_t p_data_length,
                                            uint32_t p_timeout,
                                            MCSystemUrlCallback p_callback,
                                            void *p_context);

extern "C" bool MCEmscriptenUrlPost(const unichar_t *p_url,
                                    uint32_t p_url_length,
                                    const unichar_t *p_headers,
                                    uint32_t p_headers_length,
                                    const byte_t *p_data,
                                    uint32_t p_data_length,
                                    uint32_t p_timeout,
                                    MCSystemUrlCallback p_callback,
                                    void *p_context);

extern "C" bool MCEmscriptenUrlPut(const unichar_t *p_url,
                                   uint32_t p_url_length,
                                   const unichar_t *p_headers,
                                   uint32_t p_headers_length,
                                   const byte_t *p_data,
                                   uint32_t p_data_length,
                                   uint32_t p_timeout,
                                   MCSystemUrlCallback p_callback,
                                   void *p_context);

/* ----------------------------------------------------------------
 * Wrappers (with C++ linkage)
 * ---------------------------------------------------------------- */

bool
MCSystemLoadUrl(MCStringRef p_url,
                MCSystemUrlCallback p_callback,
                void *p_context)
{
	MCAutoStringRefAsUTF16String t_url_u16;
	if (!t_url_u16.Lock(p_url))
	{
		return false;
	}

	MCAutoStringRefAsUTF16String t_headers_u16;
	if (!t_headers_u16.Lock(MChttpheaders))
	{
		return false;
	}

	return MCEmscriptenUrlLoad(t_url_u16.Ptr(), t_url_u16.Size(),
	                           t_headers_u16.Ptr(), t_headers_u16.Size(),
	                           MCsockettimeout,
	                           p_callback, p_context);
}

static bool
MCEmscriptenUrlSend(MCEmscriptenUrlSendFunction p_send,
                    MCStringRef p_url,
                    MCDataRef p_data,
                    MCSystemUrlCallback p_callback,
                    void *p_context)
{
	MCAutoStringRefAsUTF16String t_url_u16;
	if (!t_url_u16.Lock(p_url))
	{
		return false;
	}

	MCAutoStringRefAsUTF16String t_headers_u16;
	if (!t_headers_u16.Lock(MChttpheaders))
	{
		return false;
	}

	/* The data is copied before this returns */
	return p_send(t_url_u16.Ptr(), t_url_u16.Size(),
	              t_headers_u16.Ptr(), t_headers_u16.Size(),
	              MCDataGetBytePtr(p_data), MCDataGetLength(p_data),
	              MCsockettimeout,
	              p_callback, p_context);
}

bool
MCSystemPostUrl(MCStringRef p_url,
                MCDataRef p_data,
                uint32_t p_length,
                MCSystemUrlCallback p_callback,
                void *p_context)
{
	return MCEmscriptenUrlSend(MCEmscriptenUrlPost, p_url, p_data,
	                           p_callback, p_context);
}

bool
MCSystemPutUrl(MCStringRef p_url,
               MCDataRef p_data,
               uint32_t p_length,
               MCSystemUrlCallback p_callback,
               void *p_context)
{
	return MCEmscriptenUrlSend(MCEmscriptenUrlPut, p_url, p_data,
	                           p_callback, p_context);
}

/* ---------------------------------------------------------------- */

extern "C" MC_DLLEXPORT_DEF void
MCEmscriptenUrlCallbackStarted(MCSystemUrlCallback p_callback,
                               void *p_context)
{
	p_callback(p_context, kMCSystemUrlStatusStarted, nil);
}

extern "C" MC_DLLEXPORT_DEF void
MCEmscriptenUrlCallbackProgress(uint32_t p_loaded_length,
                                int32_t p_total_length,
                                MCSystemUrlCallback p_callback,
                                void *p_context)
{
	/* Dispatch the callback.  We need to send two messages: one with
	 * the total length of the data being transferred, and one with
	 * the length transferred so far. */
	p_callback(p_context, kMCSystemUrlStatusNegotiated, &p_total_length);
	p_callback(p_context, kMCSystemUrlStatusLoadingProgress, &p_loaded_length);
}

extern "C" MC_DLLEXPORT_DEF void
MCEmscriptenUrlCallbackUploading(uint32_t p_sent_length,
                                 MCSystemUrlCallback p_callback,
                                 void *p_context)
{
	p_callback(p_context, kMCSystemUrlStatusUploading, &p_sent_length);
}

extern "C" MC_DLLEXPORT_DEF void
MCEmscriptenUrlCallbackUploaded(uint32_t p_sent_length,
                                MCSystemUrlCallback p_callback,
                                void *p_context)
{
	p_callback(p_context, kMCSystemUrlStatusUploaded, &p_sent_length);
}

extern "C" MC_DLLEXPORT_DEF void
MCEmscriptenUrlCallbackFinished(const byte_t *p_data,
                                uint32_t p_data_length,
                                MCSystemUrlCallback p_callback,
                                void *p_context)
{
	/* Assemble the request data */
	MCAutoDataRef t_data;
	if (!MCDataCreateWithBytes(p_data, p_data_length, &t_data))
	{
		t_data = kMCEmptyData;
	}

	/* Dispatch the callback. We need to send two messages: a progress
	 * message with the data received, and a finished message. */
	p_callback(p_context, kMCSystemUrlStatusLoading, *t_data);
	p_callback(p_context, kMCSystemUrlStatusFinished, nil);
}

/* A response with an error status (400 or more): the page that the
 * server sent, then the error, "<status> <reason>", as on iOS and
 * Android */
extern "C" MC_DLLEXPORT_DEF void
MCEmscriptenUrlCallbackHttpError(const byte_t *p_data,
                                 uint32_t p_data_length,
                                 const unichar_t *p_error,
                                 uint32_t p_error_length,
                                 MCSystemUrlCallback p_callback,
                                 void *p_context)
{
	MCAutoDataRef t_data;
	if (!MCDataCreateWithBytes(p_data, p_data_length, &t_data))
	{
		t_data = kMCEmptyData;
	}

	MCAutoStringRef t_error;
	if (!MCStringCreateWithChars(p_error, p_error_length, &t_error))
	{
		t_error = kMCEmptyString;
	}

	p_callback(p_context, kMCSystemUrlStatusLoading, *t_data);
	p_callback(p_context, kMCSystemUrlStatusError, *t_error);
}

extern "C" MC_DLLEXPORT_DEF void
MCEmscriptenUrlCallbackError(const unichar_t *p_error,
                             uint32_t p_error_length,
                             MCSystemUrlCallback p_callback,
                             void *p_context)
{
	/* Assemble the error information string */
	MCAutoStringRef t_error;
	if (!MCStringCreateWithChars(p_error, p_error_length, &t_error))
	{
		t_error = kMCEmptyString;
	}

	/* Dispatch the callback */
	p_callback(p_context, kMCSystemUrlStatusError, *t_error);
}
