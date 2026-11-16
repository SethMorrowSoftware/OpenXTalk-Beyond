/* Copyright (C) 2003-2015 LiveCode Ltd.

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

/*
	X11Audio : Provides an abstraction between the aclip object and a Linux based audio system.
	This uses EsounD (which comes installed as part of GNOME). However, this interface will be
	simple enough to allow us to plug in any sound engine (OSS, ALSA).

	OXT-Beyond: and so it has, PulseAudio (which PipeWire's Pulse server answers too), see
	below. Current distributions ship no EsounD.
*/

#include "prefix.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"

#include "object.h"
#include "stack.h"
#include "card.h"
#include "mcerror.h"

#include "param.h"
#include "handler.h"
#include "util.h"
#include "globals.h"
#include "ports.cpp"

#include "lnxaudio.h"

#include <unistd.h>
#include <errno.h>
#include <dlfcn.h>
#include <esd.h>

extern "C" int initialise_weak_link_esd(void) ;

////////////////////////////////////////////////////////////////////////////////

// OXT-Beyond: PulseAudio's simple API, loaded when it is first wanted, so
//   the engine neither needs libpulse to build nor to run. The declarations
//   are libpulse's own (pulse/simple.h, sample.h and def.h), whose ABI has
//   not changed since PulseAudio 0.9.

typedef struct pa_simple pa_simple;
typedef uint64_t pa_usec_t;

enum
{
	kPulseSampleU8 = 0,		// PA_SAMPLE_U8
	kPulseSampleS16LE = 3,	// PA_SAMPLE_S16LE
	kPulseSampleS16BE = 4,	// PA_SAMPLE_S16BE
	kPulseStreamPlayback = 1,	// PA_STREAM_PLAYBACK
};

struct pa_sample_spec
{
	int format;
	uint32_t rate;
	uint8_t channels;
};

struct pa_buffer_attr
{
	uint32_t maxlength;
	uint32_t tlength;
	uint32_t prebuf;
	uint32_t minreq;
	uint32_t fragsize;
};

typedef pa_simple *(*pa_simple_new_t)(const char *, const char *, int, const char *, const char *, const pa_sample_spec *, const void *, const pa_buffer_attr *, int *);
typedef int (*pa_simple_write_t)(pa_simple *, const void *, size_t, int *);
typedef pa_usec_t (*pa_simple_get_latency_t)(pa_simple *, int *);
typedef int (*pa_simple_flush_t)(pa_simple *, int *);
typedef void (*pa_simple_free_t)(pa_simple *);

static pa_simple_new_t s_pa_simple_new = NULL;
static pa_simple_write_t s_pa_simple_write = NULL;
static pa_simple_get_latency_t s_pa_simple_get_latency = NULL;
static pa_simple_flush_t s_pa_simple_flush = NULL;
static pa_simple_free_t s_pa_simple_free = NULL;

static bool pulse_load(void)
{
	static bool s_tried = false;
	static bool s_loaded = false;
	if (s_tried)
		return s_loaded;
	s_tried = true;

	void *t_library;
	t_library = dlopen("libpulse-simple.so.0", RTLD_LAZY | RTLD_LOCAL);
	if (t_library == NULL)
		return false;

	s_pa_simple_new = (pa_simple_new_t)dlsym(t_library, "pa_simple_new");
	s_pa_simple_write = (pa_simple_write_t)dlsym(t_library, "pa_simple_write");
	s_pa_simple_get_latency = (pa_simple_get_latency_t)dlsym(t_library, "pa_simple_get_latency");
	s_pa_simple_flush = (pa_simple_flush_t)dlsym(t_library, "pa_simple_flush");
	s_pa_simple_free = (pa_simple_free_t)dlsym(t_library, "pa_simple_free");
	if (s_pa_simple_new == NULL || s_pa_simple_write == NULL || s_pa_simple_get_latency == NULL ||
		s_pa_simple_flush == NULL || s_pa_simple_free == NULL)
	{
		dlclose(t_library);
		return false;
	}

	s_loaded = true;
	return true;
}

////////////////////////////////////////////////////////////////////////////////

X11Audio::X11Audio ( void)
{
	m_esd_connection = -1 ;
	m_error = false ;
	m_host = NULL ;	// If this remains as NULL, esd will attempt to open on localhost:ESD_DEFAULT_PORT
	m_pulse = NULL ;
	m_pulse_failed = false ;
}


X11Audio::~X11Audio(void)
{
	closestream() ;
	if ( m_host != NULL)
		delete m_host ;
}


bool X11Audio::init(char * p_hostname, uint2 p_channels, uint2 p_width)
{
	if ( !isinit() )
	{
		MCuseESD = ( initialise_weak_link_esd() != 0 ) ;
		
		if ( p_hostname != NULL ) 
			m_host = p_hostname ;
		
		m_flags = 0 ;
		if ( p_channels == 1 )
			m_flags |= ESD_MONO ;
		else 
			m_flags |= ESD_STEREO ;
		
		
		if ( p_width == 1 )
			m_flags |= ESD_BITS8 ;
		else 
			m_flags |= ESD_BITS16 ;
		
		// m_esd_connection is no longer used to specify the network sound channel.
		// we still use it as a little flag to say we are all set-up and ready to go.
		m_esd_connection = 1;
		
		// OXT-Beyond: without EsounD a clip cannot be heard, so say so and
		//   the clip takes the engine's no-sound path (playStopped once it
		//   would have played), instead of never finishing
		return MCuseESD != False ;
	}
	return MCuseESD != False ;
	
}

int X11Audio::play(int1 * p_sample, uint4 p_samplesize, uint p_rate)
{
	if ( isinit() ) 
	{
		uint t_func = ESD_PLAY | ESD_STREAM | m_flags; 
		
		int chan ;
		chan = esd_play_stream(t_func, p_rate, NULL, NULL);
		
		uint t_bytes_written ;
		t_bytes_written = write(chan, p_sample, p_samplesize);
		
		esd_close(chan);
		
		return t_bytes_written ;
	}

    return 0;
}


void X11Audio::close(void)
{
	if ( isinit() )
	{
		esd_close(m_esd_connection);
	}
}


////////////////////////////////////////////////////////////////////////////////

bool X11Audio::openstream(uint4 p_rate, uint2 p_channels, uint2 p_width, bool p_little_endian)
{
	if (m_pulse != NULL)
		return true;
	if (m_pulse_failed)
		return false;
	m_pulse_failed = true;

	if (p_rate == 0 || p_channels == 0 || p_channels > 32 || (p_width != 1 && p_width != 2))
		return false;
	if (!pulse_load())
		return false;

	pa_sample_spec t_spec;
	if (p_width == 1)
		t_spec.format = kPulseSampleU8;
	else
		t_spec.format = p_little_endian ? kPulseSampleS16LE : kPulseSampleS16BE;
	t_spec.rate = p_rate;
	t_spec.channels = (uint8_t)p_channels;

	// Room for 2 seconds, of which the clip keeps about 1 written ahead, so
	// a write never waits. With no prebuffering playing starts at once,
	// rather than waiting for a buffer to fill that a short clip never
	// fills (with PulseAudio 16 a stream prebuffering even one frame, fed in
	// chunks, waited for ever), and a clip fed too late skips, as playing
	// keeps time, rather than pausing.
	uint4 t_frame;
	t_frame = p_width * p_channels;
	pa_buffer_attr t_attr;
	t_attr.maxlength = (uint32_t)-1;
	t_attr.tlength = p_rate * t_frame * 2;
	t_attr.prebuf = 0;
	t_attr.minreq = (uint32_t)-1;
	t_attr.fragsize = (uint32_t)-1;

	int t_error;
	m_pulse = s_pa_simple_new(NULL, program_invocation_short_name, kPulseStreamPlayback, NULL,
							  "audioClip", &t_spec, NULL, &t_attr, &t_error);
	if (m_pulse == NULL)
		return false;

	m_pulse_failed = false;
	return true;
}

bool X11Audio::writestream(const void *p_data, uint4 p_size)
{
	if (m_pulse == NULL)
		return false;
	int t_error;
	return s_pa_simple_write((pa_simple *)m_pulse, p_data, p_size, &t_error) >= 0;
}

double X11Audio::streamlatency(void)
{
	if (m_pulse == NULL)
		return -1.0;
	int t_error;
	pa_usec_t t_latency;
	t_latency = s_pa_simple_get_latency((pa_simple *)m_pulse, &t_error);
	if (t_latency == (pa_usec_t)-1)
		return -1.0;
	return t_latency / 1000000.0;
}

void X11Audio::closestream(void)
{
	m_pulse_failed = false;
	if (m_pulse == NULL)
		return;
	int t_error;
	s_pa_simple_flush((pa_simple *)m_pulse, &t_error);
	s_pa_simple_free((pa_simple *)m_pulse);
	m_pulse = NULL;
}
