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

#include "prefix.h"

#include "em-util.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "mcio.h"

#include "sysdefs.h"
#include "osspec.h"
#include "globals.h"
#include "util.h"
#include "variable.h"
#include "socket.h"
#include "param.h"
#include "mcstring.h"

/* ================================================================
 * Socket handling
 *
 * OXT-Beyond: a web page cannot open a TCP socket, but it can open a
 * WebSocket, so "open socket to" a ws:// or wss:// URL opens one
 * (em-socket.js), and the socket then works as one of the desktop's
 * does: the socket's name is what the script gave (the URL, and a
 * "|<id>" after it to open more than one to the same URL), "with
 * message" sends the message when it has opened, "read from socket"
 * reads what the server sent (each message's bytes, one after the
 * other: a text message's as UTF-8) for a count, until a string, or
 * all there is, waiting or with a message, "write to socket" sends the
 * bytes written as one message (a text message when they are UTF-8,
 * a binary one otherwise), and socketClosed, socketError and
 * socketTimeout come as on the desktop. "open secure socket to" a
 * ws:// URL opens a wss:// one.
 *
 * Any other name (host:port) fails as it always did, with "not
 * supported" in the result, as do datagram sockets; "accept
 * connections" is not possible in a page.
 * ================================================================ */

/* em-socket.js */
extern "C" uint32_t MCEmscriptenSocketOpen(const unichar_t *p_url, size_t p_length);
extern "C" bool MCEmscriptenSocketSend(uint32_t p_id, const byte_t *p_bytes, size_t p_length);
extern "C" void MCEmscriptenSocketClose(uint32_t p_id);

/* The events of a WebSocket (LiveCodeSocket's in em-socket.js) */
enum MCEmscriptenSocketEvent
{
	kMCEmscriptenSocketEventOpen = 1,
	kMCEmscriptenSocketEventData = 2,
	kMCEmscriptenSocketEventError = 3,
	kMCEmscriptenSocketEventClose = 4,
};

/* The desktop engines' sockets read the time from curtime, which their
 * event loops keep (dsklnx.cpp, dskmac.cpp, dskw32.cpp): the web engine
 * has none, and these read MCS_time() */

/* The URL of the socket named p_name: the name without any "|<id>",
 * if it is a ws:// or wss:// URL (wss:// for a secure socket) */
static bool
MCEmscriptenSocketURL(MCNameRef p_name, bool p_secure, MCStringRef &r_url)
{
	MCStringRef t_name;
	t_name = MCNameGetString(p_name);

	uindex_t t_bar;
	if (!MCStringFirstIndexOfChar(t_name, '|', 0, kMCStringOptionCompareExact, t_bar))
		t_bar = MCStringGetLength(t_name);

	MCAutoStringRef t_url;
	if (!MCStringCopySubstring(t_name, MCRangeMake(0, t_bar), &t_url))
		return false;

	if (MCStringBeginsWithCString(*t_url, (const char_t *)"wss://", kMCStringOptionCompareCaseless))
	{
		r_url = MCValueRetain(*t_url);
		return true;
	}

	if (!MCStringBeginsWithCString(*t_url, (const char_t *)"ws://", kMCStringOptionCompareCaseless))
		return false;

	if (!p_secure)
	{
		r_url = MCValueRetain(*t_url);
		return true;
	}

	MCAutoStringRef t_rest;
	if (!MCStringCopySubstring(*t_url, MCRangeMake(5, MCStringGetLength(*t_url) - 5), &t_rest))
		return false;
	return MCStringFormat(r_url, "wss://%@", *t_rest);
}

/* The sockets that have a WebSocket, to find a socket by the id of its
 * WebSocket: those the script has, and one that a script is waiting
 * to open (it joins MCsockets once it is open) */
static MCSocket **s_web_sockets = nil;
static uindex_t s_web_socket_count = 0;

static void
MCEmscriptenSocketRegister(MCSocket *p_socket)
{
	if (MCMemoryResizeArray(s_web_socket_count + 1, s_web_sockets, s_web_socket_count))
		s_web_sockets[s_web_socket_count - 1] = p_socket;
}

static void
MCEmscriptenSocketUnregister(MCSocket *p_socket)
{
	for (uindex_t i = 0; i < s_web_socket_count; i++)
	{
		if (s_web_sockets[i] != p_socket)
			continue;
		for (uindex_t j = i + 1; j < s_web_socket_count; j++)
			s_web_sockets[j - 1] = s_web_sockets[j];
		s_web_socket_count--;
		return;
	}
}

static MCSocket *
MCEmscriptenSocketFind(uint32_t p_id)
{
	for (uindex_t i = 0; i < s_web_socket_count; i++)
		if (s_web_sockets[i]->fd != 0 && uint32_t(s_web_sockets[i]->fd) == p_id)
			return s_web_sockets[i];
	return nil;
}

/* Sends the bytes of a write, and the write's message */
static bool
MCEmscriptenSocketSendWrite(MCSocket *p_socket, MCSocketwrite *p_write)
{
	if (!MCEmscriptenSocketSend(uint32_t(p_socket->fd), (const byte_t *)p_write->buffer, p_write->size))
		return false;
	p_write->done = p_write->size;
	p_write->writedone = True;
	if (p_write->message != nil && p_write->optr.IsValid())
		MCscreen->delaymessage(p_write->optr, p_write->message, MCNameGetString(p_socket->name));
	return true;
}

/* True if p_write is in the (circular) list p_list */
static bool
MCEmscriptenSocketHasWrite(MCSocketwrite *p_list, MCSocketwrite *p_write)
{
	MCSocketwrite *t_write;
	t_write = p_list;
	while (t_write != nil)
	{
		if (t_write == p_write)
			return true;
		t_write = t_write->next();
		if (t_write == p_list)
			break;
	}
	return false;
}

/* Called by the page (em-socket.js) for each event of a WebSocket. It
 * runs no script: it queues the socket's messages, as the desktop's
 * socket thread does. */
extern "C" MC_DLLEXPORT_DEF void
MCEmscriptenSocketHandleEvent(uint32_t p_id, int32_t p_event, byte_t *p_bytes, uint32_t p_length, int32_t p_flag)
{
	MCSocket *s;
	s = MCEmscriptenSocketFind(p_id);
	if (s == nil)
	{
		free(p_bytes);
		return;
	}

	switch (p_event)
	{
	case kMCEmscriptenSocketEventOpen:
		/* As writesome() does on the desktop: the message of "open
		 * socket ... with message", then the writes made before */
		if (!s->connected && s->message != nil && s->object.IsValid())
		{
			MCscreen->delaymessage(s->object, s->message, MCNameGetString(s->name));
			MCValueRelease(s->message);
			s->message = nil;
		}
		s->connected = True;
		s->added = True;
		while (s->wevents != nil)
		{
			MCSocketwrite *t_write;
			t_write = s->wevents;
			if (!MCEmscriptenSocketSendWrite(s, t_write))
				break;
			t_write->remove(s->wevents);
			/* A write with no message belongs to the script waiting
			 * for it (MCS_write_socket), which deletes it */
			if (t_write->message != nil)
				delete t_write;
		}
		/* Closed by the script while its writes waited: they are
		 * sent, and it goes, with no message */
		if (s->closing && s->wevents == nil)
			s->deletewrites();
		break;

	case kMCEmscriptenSocketEventData:
		if (p_length > 0)
		{
			if (s->nread + p_length > s->rsize)
			{
				uint4 t_size;
				t_size = s->nread + p_length + 4096;
				MCU_realloc((char **)&s->rbuffer, s->nread, t_size, sizeof(char));
				if (s->rbuffer == nil)
				{
					s->rsize = 0;
					s->nread = 0;
					break;
				}
				s->rsize = t_size;
			}
			memcpy(s->rbuffer + s->nread, p_bytes, p_length);
			s->nread += p_length;
			if (s->revents != nil)
				s->revents->timeout = MCS_time() + MCsockettimeout;
			s->processreadqueue();
		}
		break;

	case kMCEmscriptenSocketEventError:
		/* The close that follows reports it */
		if (s->error == nil)
			s->error = strclone(s->connected ? "connection lost" : "can't connect to host");
		break;

	case kMCEmscriptenSocketEventClose:
		if (p_flag == 0 && s->error == nil)
			s->error = strclone(s->connected ? "connection lost" : "can't connect to host");
		/* The socket has no WebSocket now: what it read can still be
		 * read, then it goes (IO_cleansockets) */
		s->fd = 0;
		if (s->closing)
			s->deletewrites();
		else if (s->error == nil && s->revents != nil && !s->waiting)
		{
			/* Reads with a message that wait for more than came: at the
			 * end they are done (read_done() gives them what is left,
			 * "eof"), and the last sends socketClosed when nothing is
			 * left to read (processreadqueue) */
			s->deletewrites();
			s->processreadqueue();
		}
		else
			s->doclose();
		break;
	}

	free(p_bytes);
}

MCSocket *
MCS_accept(uint16_t p_port,
           MCObject *p_object,
           MCNameRef p_message,
           Boolean p_datagram,
           Boolean p_secure,
           Boolean p_sslverify,
           MCStringRef p_sslcertfile)
{
	MCEmscriptenNotImplemented();
	return nil;
}

/* The socket's own address: a page has none it can know */
bool
MCS_ha(MCSocket *p_socket,
       MCStringRef & r_address)
{
	r_address = MCValueRetain(kMCEmptyString);
	return true;
}

MCSocket *
MCS_open_socket(MCNameRef p_name,
                MCNameRef p_from,
                Boolean p_datagram,
                MCObject *p_object,
                MCNameRef p_message,
                Boolean p_secure,
                Boolean p_sslverify,
                MCStringRef p_sslcertfile,
                MCNameRef p_end_hostname)
{
	MCAutoStringRef t_url;
	if (p_datagram || !MCEmscriptenSocketURL(p_name, p_secure, &t_url))
	{
		MCresult->sets("not supported");
		return nil;
	}

	MCAutoStringRefAsUTF16String t_url_utf16;
	if (!t_url_utf16.Lock(*t_url))
	{
		MCresult->sets("can't connect to host");
		return nil;
	}

	uint32_t t_id;
	t_id = MCEmscriptenSocketOpen(t_url_utf16.Ptr(), t_url_utf16.Size());
	if (t_id == 0)
	{
		MCresult->sets("invalid WebSocket URL");
		return nil;
	}

	MCSocket *s;
	s = new (nothrow) MCSocket(p_name, p_from, p_object, p_message, False, MCSocketHandle(t_id), False, False, p_secure);
	if (s == nil)
	{
		MCEmscriptenSocketClose(t_id);
		MCresult->sets("can't create socket");
		return nil;
	}
	s->sslverify = p_sslverify;
	s->resolve_state = kMCSocketStateConnecting;

	if (p_message == nil)
	{
		/* As on the desktop, "open socket" without a message returns
		 * when the socket is open, or has failed */
		s->waiting = True;
		while (!s->connected && s->error == nil && s->fd != 0)
		{
			if (MCS_time() > s->timeout)
			{
				s->error = strclone("timeout");
				break;
			}
			if (MCscreen->wait(READ_INTERVAL, False, True))
			{
				s->error = strclone("interrupted");
				break;
			}
		}
		s->waiting = False;
		if (!s->connected)
		{
			if (s->error != nil)
				MCresult->copysvalue(MCString(s->error));
			else
				MCresult->sets("can't connect to host");
			delete s;
			return nil;
		}
	}

	s->resolve_state = kMCSocketStateNew;
	return s;
}

void
MCS_close_socket(MCSocket *p_socket)
{
	/* As on the desktop: what is waiting to be read goes, what is
	 * waiting to be written is sent first */
	p_socket->deletereads();
	if (p_socket->wevents == nil)
		p_socket->deletewrites();
	p_socket->closing = True;
}

MCDataRef
MCS_read_socket(MCSocket *s,
                MCExecContext & ctxt,
                uint4 p_length,
                const char *p_until,
                MCNameRef p_message)
{
	MCDataRef t_data;
	t_data = nil;

	MCSocketread *eptr = new (nothrow) MCSocketread(p_length, p_until != nil ? strdup(p_until) : nil, ctxt.GetObject(), p_message);
	if (eptr == nil)
		return nil;
	eptr->appendto(s->revents);

	if (p_message != nil)
	{
		s->processreadqueue();
		ctxt.SetTheResultToEmpty();
		return nil;
	}

	/* As on the desktop: wait until the read is done, the socket has
	 * failed or closed, or the socketTimeoutInterval has passed. The
	 * wait lets the browser give the engine what the server sends. */
	s->waiting = True;
	bool t_continue;
	t_continue = true;
	if (MCscreen->wait(0.0, False, True))
	{
		MCresult->sets("interrupted");
		t_continue = false;
	}

	while (t_continue)
	{
		if (eptr == s->revents && s->read_done())
		{
			uint4 size = eptr->size;
			if (p_until != nil && *p_until == '\n' && !*(p_until + 1)
			        && size && s->rbuffer[size - 1] == '\r')
				size--;
			/* UNCHECKED */ MCDataCreateWithBytes((const byte_t *)s->rbuffer, size, t_data);
			s->nread -= eptr->size;
			memmove(s->rbuffer, s->rbuffer + eptr->size, s->nread);
			break;
		}
		if (s->error != nil)
		{
			MCresult->sets(s->error);
			break;
		}
		if (s->fd == 0)
		{
			MCresult->sets("eof");
			break;
		}
		if (MCS_time() > eptr->timeout)
		{
			MCresult->sets("timeout");
			break;
		}
		if (MCscreen->wait(READ_INTERVAL, False, True))
		{
			MCresult->sets("interrupted");
			break;
		}
	}
	eptr->remove(s->revents);
	delete eptr;
	s->waiting = False;
	return t_data;
}

void
MCS_write_socket(const MCStringRef p_data,
                 MCSocket *s,
                 MCObject *p_object,
                 MCNameRef p_message)
{
	MCSocketwrite *eptr = new (nothrow) MCSocketwrite(p_data, p_object, p_message, s->secure);
	if (eptr == nil)
		return;

	if (s->connected && s->wevents == nil && s->fd != 0)
	{
		/* A WebSocket takes the whole message at once */
		if (!MCEmscriptenSocketSendWrite(s, eptr))
			MCresult->sets("socket closed");
		delete eptr;
		return;
	}

	if (s->fd == 0)
	{
		MCresult->sets(s->error != nil ? s->error : "socket closed");
		delete eptr;
		return;
	}

	/* Not open yet: the write is sent when it opens
	 * (MCEmscriptenSocketHandleEvent) */
	eptr->appendto(s->wevents);
	if (p_message != nil)
		return;

	/* As on the desktop, a write without a message returns when it has
	 * been written */
	s->waiting = True;
	while (true)
	{
		if (eptr->writedone)
			break;
		if (s->error != nil)
		{
			MCresult->sets(s->error);
			break;
		}
		if (s->fd == 0)
		{
			MCresult->sets("socket closed");
			break;
		}
		if (MCS_time() > eptr->timeout)
		{
			MCresult->sets("timeout");
			break;
		}
		if (MCscreen->wait(READ_INTERVAL, False, True))
		{
			MCresult->sets("interrupted");
			break;
		}
	}
	/* Sent (and so taken from the list), or not (the result says why):
	 * then it is taken from it here */
	if (MCEmscriptenSocketHasWrite(s->wevents, eptr))
		eptr->remove(s->wevents);
	delete eptr;
	s->waiting = False;
}

void
MCS_secure_socket(MCSocket *p_socket,
                  Boolean p_sslverify,
                  MCNameRef p_end_hostname)
{
	/* A wss:// socket is secure from the start; another cannot become so */
	MCresult->sets("not supported");
}

/* The peer's address: the socket's URL */
bool
MCS_pa(MCSocket *p_socket,
       MCStringRef & r_address)
{
	return MCEmscriptenSocketURL(p_socket->name, p_socket->secure, r_address);
}

void
MCSocketsAppendToSocketList(MCSocket *p_socket)
{
	MCU_realloc((char **)&MCsockets, MCnsockets, MCnsockets + 1,
	            sizeof(MCSocket *));
	MCsockets[MCnsockets++] = p_socket;
}

void
MCSocketsRemoveFromSocketList(uint32_t p_socket_no)
{
	delete MCsockets[p_socket_no];
	for (uint32_t i = p_socket_no + 1; i < MCnsockets; ++i)
	{
		MCsockets[i - 1] = MCsockets[i];
	}
	MCnsockets--;
}

/* The socket's reads and writes, and the socket, as opensslsocket.cpp
 * has them where it can */

MCSocketread::MCSocketread(uint4 s, char *u, MCObject *o, MCNameRef m)
{
	size = s;
	until = u;
	timeout = MCS_time() + MCsockettimeout;
	optr = o;
	message = m != nil ? MCValueRetain(m) : nil;
}

MCSocketread::~MCSocketread()
{
	MCValueRelease(message);
	free(until);
}

MCSocketwrite::MCSocketwrite(MCStringRef d, MCObject *o, MCNameRef m, Boolean securewrite)
{
	char *t_bytes;
	t_bytes = nil;
	/* UNCHECKED */ MCStringConvertToCString(d, t_bytes);
	buffer = t_bytes;
	size = MCStringGetLength(d);
	timeout = MCS_time() + MCsockettimeout;
	secure = securewrite;
	optr = o;
	done = 0;
	writedone = False;
	message = m != nil ? MCValueRetain(m) : nil;
}

MCSocketwrite::~MCSocketwrite()
{
	MCValueRelease(message);
	MCMemoryDeleteArray(buffer);
}

MCSocket::MCSocket(MCNameRef n, MCNameRef f, MCObject *o, MCNameRef m, Boolean d, MCSocketHandle sock, Boolean a, Boolean s, Boolean issecure)
    : from(f)
{
	name = MCValueRetain(n);
	object = o;
	message = m != nil ? MCValueRetain(m) : nil;
	datagram = d;
	accepting = a;
	connected = False;
	shared = s;
	fd = sock;
	closing = doread = added = waiting = False;
	revents = nil;
	wevents = nil;
	rbuffer = nil;
	error = nil;
	rsize = nread = 0;
	timeout = MCS_time() + MCsockettimeout;
	sslstate = 0;
	sslverify = False;
	secure = issecure;
	resolve_state = kMCSocketStateNew;
	endhostname = MCValueRetain(kMCEmptyName);
	MCEmscriptenSocketRegister(this);
}

MCSocket::~MCSocket()
{
	MCEmscriptenSocketUnregister(this);
	if (fd != 0)
		close();
	MCValueRelease(name);
	MCValueRelease(message);
	deletereads();
	while (wevents != nil)
	{
		MCSocketwrite *eptr = wevents->remove(wevents);
		delete eptr;
	}
	delete[] rbuffer;
	delete[] error;
	MCValueRelease(endhostname);
}

void
MCSocket::deletereads()
{
	while (revents != nil)
	{
		MCSocketread *eptr = revents->remove(revents);
		delete eptr;
	}
	nread = 0;
}

void
MCSocket::deletewrites()
{
	while (wevents != nil)
	{
		MCSocketwrite *eptr = wevents->remove(wevents);
		/* A write with no message belongs to the script waiting for it
		 * (MCS_write_socket), which deletes it when the socket has
		 * closed: deleting it here would leave that script reading
		 * freed memory */
		if (eptr->message != nil)
			delete eptr;
	}
	if (fd != 0)
	{
		close();
		fd = 0;
	}
}

void
MCSocket::close()
{
	if (fd != 0)
		MCEmscriptenSocketClose(uint32_t(fd));
}

/* As opensslsocket.cpp's */
Boolean
MCSocket::read_done()
{
	if (revents->until != nil)
	{
		if (!*revents->until)
		{
			revents->size = nread;
			if (fd == 0)
				MCresult->sets("eof");
			return True;
		}
		if (*revents->until != '\004')
		{
			char *sptr = rbuffer;
			char *eptr = rbuffer + nread;
			char *dptr = revents->until;
			while (sptr < eptr)
			{
				if (*sptr++ == *dptr)
				{
					char *tsptr = sptr;
					char *tdptr = dptr + 1;
					while (tsptr < eptr && *tdptr && *tsptr == *tdptr)
					{
						tsptr++;
						tdptr++;
					}
					if (!*tdptr)
					{
						revents->size = tsptr - rbuffer;
						return True;
					}
				}
			}
		}
	}
	else
	{
		if (nread >= revents->size)
		{
			if (revents->size == 0)
			{
				if (nread == 0)
					return False;
				revents->size = nread;
				if (fd == 0)
					MCresult->sets("eof");
			}
			return True;
		}
	}
	if (fd == 0 && error == nil)
	{
		revents->size = nread;
		MCresult->sets("eof");
		return True;
	}
	return False;
}

/* As opensslsocket.cpp's: the reads with a message that what was read
 * completes, each sent its data */
void
MCSocket::processreadqueue()
{
	if (waiting)
		return;
	while (revents != nil)
	{
		if (!read_done())
			break;

		uint4 size = revents->size;
		if (size > 1 && revents->until != nil && *revents->until == '\n'
		        && !*(revents->until + 1) && rbuffer[size - 1] == '\r')
			rbuffer[--size] = '\n';

		MCAutoDataRef t_data;
		/* UNCHECKED */ MCDataCreateWithBytes((const byte_t *)rbuffer, size, &t_data);

		nread -= revents->size;
		memmove(rbuffer, rbuffer + revents->size, nread);
		MCSocketread *e = revents->remove(revents);
		if (e->optr.IsValid())
		{
			MCParameter *params = new (nothrow) MCParameter;
			params->setvalueref_argument(name);
			params->setnext(new MCParameter);
			params->getnext()->setvalueref_argument(*t_data);
			MCscreen->addmessage(e->optr, e->message, MCS_time(), params);
		}
		delete e;
		/* (once, after the last read: at the end every read waiting
		 * is done at once) */
		if (nread == 0 && fd == 0 && revents == nil && object.IsValid())
			MCscreen->delaymessage(object, MCM_socket_closed, MCNameGetString(name));
		added = True;
	}
}

/* As opensslsocket.cpp's: socketError, or socketClosed when nothing
 * is left to read (otherwise the last read sends it) */
void
MCSocket::doclose()
{
	deletewrites();

	if (waiting)
		return;

	if (error != nil)
	{
		if (object.IsValid())
		{
			MCAutoStringRef t_error;
			/* UNCHECKED */ MCStringCreateWithCString(error, &t_error);
			MCscreen->delaymessage(object, MCM_socket_error, MCNameGetString(name), *t_error);
		}
		added = True;
	}
	else if (nread == 0)
	{
		if (object.IsValid())
			MCscreen->delaymessage(object, MCM_socket_closed, MCNameGetString(name));
		added = True;
	}
}

/* ================================================================
 * Host names and addresses
 * ================================================================ */

bool
MCS_hn(MCStringRef & r_name)
{
	r_name = MCValueRetain(kMCEmptyString);
	return true;
}

bool
MCS_aton(MCStringRef p_address,
         MCStringRef & r_name)
{
	r_name = MCValueRetain(kMCEmptyString);
	return true;
}

bool
MCS_ntoa(MCStringRef p_hostname,
         MCObject *p_target,
         MCNameRef p_message,
         MCListRef & r_addresses)
{
	r_addresses = MCValueRetain(kMCEmptyList);
	return true;
}

bool
MCS_dnsresolve(MCStringRef p_hostname,
               MCStringRef & r_address)
{
	return false;
}

bool
MCS_hostaddress(MCStringRef & r_address)
{
	return false;
}
