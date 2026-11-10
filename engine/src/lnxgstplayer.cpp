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

// OXT-Beyond: the player's movie through GStreamer (lnxgstplayer.h says
// when). GStreamer 1.x is loaded with dlopen: the few functions used are
// looked up by name, and the types, enumerations and the one struct field
// read (a message's type) are those of GStreamer 1.0's stable ABI, written
// out here so that no development package is needed to build.

#include "lnxgstplayer.h"

#include <dlfcn.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include <new>

namespace
{
	// GLib and GStreamer 1.0's types and values, as their headers have them
	typedef int gboolean;
	typedef unsigned int guint;
	typedef int64_t gint64;
	typedef uint64_t guint64;

	enum { kGstStateNull = 1, kGstStatePaused = 3, kGstStatePlaying = 4 };
	enum { kGstStateChangeFailure = 0 };
	enum { kGstFormatTime = 3, kGstFormatBuffers = 4 };
	enum { kGstSeekFlagFlush = 1 << 0, kGstSeekFlagAccurate = 1 << 1 };
	enum { kGstSeekTypeNone = 0, kGstSeekTypeSet = 1 };
	enum { kGstMessageEos = 1 << 0, kGstMessageError = 1 << 1 };
	const int64_t kGstSecond = 1000000000LL;
	const int64_t kGstMillisecond = 1000000LL;

	// GstMiniObject, the start of every GstMessage, then the message's type
	struct GstMiniObjectABI
	{
		size_t type;
		int refcount;
		int lockstate;
		guint flags;
		void *copy;
		void *dispose;
		void *free;
		guint priv_uint;
		void *priv_pointer;
	};
	struct GstMessageABI
	{
		GstMiniObjectABI mini_object;
		guint type;
	};

	typedef gboolean (*GstBusFunc)(void *p_bus, void *p_message, void *p_data);

	struct
	{
		gboolean (*gst_init_check)(int *, char ***, void **);
		void *(*gst_element_factory_make)(const char *, const char *);
		int (*gst_element_set_state)(void *, int);
		int (*gst_element_get_state)(void *, int *, int *, guint64);
		gboolean (*gst_element_query_position)(void *, int, gint64 *);
		gboolean (*gst_element_query_duration)(void *, int, gint64 *);
		gboolean (*gst_element_seek)(void *, double, int, int, int, gint64, int, gint64);
		gboolean (*gst_element_send_event)(void *, void *);
		void *(*gst_event_new_step)(int, guint64, double, gboolean, gboolean);
		void *(*gst_element_get_bus)(void *);
		guint (*gst_bus_add_watch)(void *, GstBusFunc, void *);
		gboolean (*gst_bus_remove_watch)(void *);
		void *(*gst_object_ref_sink)(void *);
		void (*gst_object_unref)(void *);
		gboolean (*gst_uri_is_valid)(const char *);
		char *(*gst_filename_to_uri)(const char *, void **);
		void (*gst_video_overlay_set_window_handle)(void *, uintptr_t);
		void (*gst_video_overlay_expose)(void *);
		void (*g_object_set)(void *, const char *, ...);
		void (*g_free)(void *);
	} s_gst;

	// -1 not tried yet, 0 missing, 1 loaded
	int s_gst_state = -1;

	// Some player ended since the event loop last asked
	bool s_any_ended = false;

	bool load_symbol(void *p_library, const char *p_name, void *r_pointer)
	{
		void *t_symbol = p_library != nullptr ? dlsym(p_library, p_name) : nullptr;
		memcpy(r_pointer, &t_symbol, sizeof(void *));
		return t_symbol != nullptr;
	}

	bool load_gstreamer(void)
	{
		// The libraries stay loaded for the life of the process: GStreamer
		// cannot be initialised a second time
		void *t_gst = dlopen("libgstreamer-1.0.so.0", RTLD_NOW | RTLD_GLOBAL);
		void *t_video = t_gst != nullptr ? dlopen("libgstvideo-1.0.so.0", RTLD_NOW | RTLD_GLOBAL) : nullptr;
		void *t_gobject = dlopen("libgobject-2.0.so.0", RTLD_NOW | RTLD_GLOBAL);
		void *t_glib = dlopen("libglib-2.0.so.0", RTLD_NOW | RTLD_GLOBAL);

		bool t_ok = true;
#define LOAD(lib, name) t_ok = load_symbol(lib, #name, &s_gst.name) && t_ok
		LOAD(t_gst, gst_init_check);
		LOAD(t_gst, gst_element_factory_make);
		LOAD(t_gst, gst_element_set_state);
		LOAD(t_gst, gst_element_get_state);
		LOAD(t_gst, gst_element_query_position);
		LOAD(t_gst, gst_element_query_duration);
		LOAD(t_gst, gst_element_seek);
		LOAD(t_gst, gst_element_send_event);
		LOAD(t_gst, gst_event_new_step);
		LOAD(t_gst, gst_element_get_bus);
		LOAD(t_gst, gst_bus_add_watch);
		LOAD(t_gst, gst_bus_remove_watch);
		LOAD(t_gst, gst_object_ref_sink);
		LOAD(t_gst, gst_object_unref);
		LOAD(t_gst, gst_uri_is_valid);
		LOAD(t_gst, gst_filename_to_uri);
		LOAD(t_video, gst_video_overlay_set_window_handle);
		LOAD(t_video, gst_video_overlay_expose);
		LOAD(t_gobject, g_object_set);
		LOAD(t_glib, g_free);
#undef LOAD
		if (!t_ok)
			return false;

		return s_gst.gst_init_check(nullptr, nullptr, nullptr) != 0;
	}

	gboolean bus_callback(void *p_bus, void *p_message, void *p_data)
	{
		(void)p_bus;
		const GstMessageABI *t_message = static_cast<const GstMessageABI *>(p_message);
		static_cast<MCGstPlayer *>(p_data)->HandleBusMessage(t_message->type);
		// Keep the watch
		return 1;
	}
}

bool MCGstPlayer::IsAvailable(void)
{
	if (s_gst_state == -1)
		s_gst_state = load_gstreamer() ? 1 : 0;
	return s_gst_state == 1;
}

bool MCGstPlayer::TakeAnyEnded(void)
{
	bool t_ended = s_any_ended;
	s_any_ended = false;
	return t_ended;
}

MCGstPlayer::MCGstPlayer(void)
	: m_pipeline(nullptr), m_video_sink(nullptr), m_bus(nullptr), m_watching(false), m_overlay(false),
	  m_playing(false), m_looping(false), m_ended(false), m_rate(1.0),
	  m_loudness(100), m_duration(0)
{
}

MCGstPlayer::~MCGstPlayer(void)
{
	Close();
}

MCGstPlayer *MCGstPlayer::Create(const char *p_location, unsigned long p_xid, bool p_xvideo)
{
	if (p_location == nullptr || *p_location == '\0' || !IsAvailable())
		return nullptr;

	// A URL GStreamer reads (http, https, file...) as it is, a path as a
	// file: URI
	char *t_uri = nullptr;
	if (strstr(p_location, "://") != nullptr && s_gst.gst_uri_is_valid(p_location))
		t_uri = strdup(p_location);
	else
	{
		char *t_gst_uri = s_gst.gst_filename_to_uri(p_location, nullptr);
		if (t_gst_uri != nullptr)
		{
			t_uri = strdup(t_gst_uri);
			s_gst.g_free(t_gst_uri);
		}
	}
	if (t_uri == nullptr)
		return nullptr;

	MCGstPlayer *t_player = new (std::nothrow) MCGstPlayer;
	bool t_ok = t_player != nullptr;

	// A machine without a sound device (or a sound server) cannot open the
	// default audio output, and then nothing plays: the movie plays again
	// without its sound, in real time, as mplayer does there. When XVideo
	// does not open (a remote display, a driver without it), plain X does.
	if (t_ok)
	{
		static const bool kSilent[] = {false, true};
		t_ok = false;
		for (int t_xv = p_xvideo ? 1 : 0; !t_ok && t_xv >= 0; t_xv--)
			for (int t_silent = 0; !t_ok && t_silent < 2; t_silent++)
			{
				t_ok = t_player->Open(t_uri, p_xid, t_xv == 1, kSilent[t_silent]);
				if (!t_ok)
					t_player->Close();
			}
	}

	free(t_uri);
	if (!t_ok)
	{
		delete t_player;
		return nullptr;
	}
	return t_player;
}

bool MCGstPlayer::Open(const char *p_uri, unsigned long p_xid, bool p_xvideo, bool p_silent)
{
	void *t_playbin = s_gst.gst_element_factory_make("playbin", nullptr);
	if (t_playbin == nullptr)
		return false;
	m_pipeline = s_gst.gst_object_ref_sink(t_playbin);
	s_gst.g_object_set(m_pipeline, "uri", p_uri, nullptr);

	// The video in the engine's window: through XVideo when the X server has
	// it (and the movie keeps its aspect ratio), else through plain X filling
	// the window, as mplayer's two outputs do. Without a window (or without
	// either sink: gstreamer1.0-x is missing) the video is decoded and
	// dropped in time, so the movie still plays its sound and ends.
	void *t_video_sink = nullptr;
	if (p_xid != 0)
	{
		if (p_xvideo)
			t_video_sink = s_gst.gst_element_factory_make("xvimagesink", nullptr);
		if (t_video_sink == nullptr)
			t_video_sink = s_gst.gst_element_factory_make("ximagesink", nullptr);
		if (t_video_sink == nullptr)
			return false;
		s_gst.g_object_set(t_video_sink, "force-aspect-ratio", p_xvideo ? 1 : 0, nullptr);
	}
	else
	{
		t_video_sink = s_gst.gst_element_factory_make("fakesink", nullptr);
		if (t_video_sink == nullptr)
			return false;
		s_gst.g_object_set(t_video_sink, "sync", 1, nullptr);
	}
	m_video_sink = s_gst.gst_object_ref_sink(t_video_sink);
	s_gst.g_object_set(m_pipeline, "video-sink", m_video_sink, nullptr);
	m_overlay = p_xid != 0;
	if (m_overlay)
		s_gst.gst_video_overlay_set_window_handle(m_video_sink, (uintptr_t)p_xid);

	if (p_silent)
	{
		void *t_audio_sink = s_gst.gst_element_factory_make("fakesink", nullptr);
		if (t_audio_sink == nullptr)
			return false;
		s_gst.g_object_set(t_audio_sink, "sync", 1, nullptr);
		s_gst.g_object_set(m_pipeline, "audio-sink", t_audio_sink, nullptr);
	}

	s_gst.g_object_set(m_pipeline, "volume", m_loudness / 100.0, nullptr);

	// Paused at its start, with the first frame drawn: as mplayer starts.
	// The duration is known once it has prerolled, which can take a moment
	// for a URL; mplayer's answers waited as long.
	if (s_gst.gst_element_set_state(m_pipeline, kGstStatePaused) == kGstStateChangeFailure)
		return false;
	int t_state = 0;
	if (s_gst.gst_element_get_state(m_pipeline, &t_state, nullptr, 5 * kGstSecond) == kGstStateChangeFailure)
		return false;

	// The end of the movie and errors come through GLib's main loop, which
	// the engine runs in its event loop
	m_bus = s_gst.gst_element_get_bus(m_pipeline);
	if (m_bus != nullptr)
		m_watching = s_gst.gst_bus_add_watch(m_bus, bus_callback, this) != 0;

	m_playing = false;
	m_ended = false;
	return true;
}

void MCGstPlayer::Close(void)
{
	if (m_bus != nullptr)
	{
		if (m_watching)
			s_gst.gst_bus_remove_watch(m_bus);
		s_gst.gst_object_unref(m_bus);
		m_bus = nullptr;
		m_watching = false;
	}
	if (m_pipeline != nullptr)
	{
		s_gst.gst_element_set_state(m_pipeline, kGstStateNull);
		s_gst.gst_object_unref(m_pipeline);
		m_pipeline = nullptr;
	}
	if (m_video_sink != nullptr)
	{
		s_gst.gst_object_unref(m_video_sink);
		m_video_sink = nullptr;
	}
	m_overlay = false;
	m_playing = false;
	m_duration = 0;
}

bool MCGstPlayer::HandleBusMessage(uint32_t p_type)
{
	if (p_type == kGstMessageEos && m_looping)
	{
		// From the start again, as mplayer's loop does
		SeekTo(0);
		return true;
	}

	if (p_type == kGstMessageEos || p_type == kGstMessageError)
	{
		m_ended = true;
		s_any_ended = true;
	}
	return true;
}

bool MCGstPlayer::TakeEnded(void)
{
	bool t_ended = m_ended;
	m_ended = false;
	return t_ended;
}

void MCGstPlayer::Play(void)
{
	if (m_pipeline == nullptr)
		return;
	s_gst.gst_element_set_state(m_pipeline, kGstStatePlaying);
	m_playing = true;
}

void MCGstPlayer::Pause(void)
{
	if (m_pipeline == nullptr)
		return;
	s_gst.gst_element_set_state(m_pipeline, kGstStatePaused);
	m_playing = false;
}

uint32_t MCGstPlayer::GetDuration(void)
{
	if (m_duration == 0 && m_pipeline != nullptr)
	{
		gint64 t_duration = 0;
		if (s_gst.gst_element_query_duration(m_pipeline, kGstFormatTime, &t_duration) && t_duration > 0)
			m_duration = (uint32_t)((t_duration + kGstMillisecond / 2) / kGstMillisecond);
	}
	return m_duration;
}

uint32_t MCGstPlayer::GetCurrentTime(void)
{
	if (m_pipeline == nullptr)
		return 0;
	gint64 t_position = 0;
	if (!s_gst.gst_element_query_position(m_pipeline, kGstFormatTime, &t_position) || t_position < 0)
		return 0;
	return (uint32_t)((t_position + kGstMillisecond / 2) / kGstMillisecond);
}

bool MCGstPlayer::SeekTo(int64_t p_nanoseconds)
{
	if (m_pipeline == nullptr)
		return false;
	if (p_nanoseconds < 0)
		p_nanoseconds = 0;
	return s_gst.gst_element_seek(m_pipeline, m_rate, kGstFormatTime,
								  kGstSeekFlagFlush | kGstSeekFlagAccurate,
								  kGstSeekTypeSet, p_nanoseconds, kGstSeekTypeNone, -1) != 0;
}

void MCGstPlayer::SetCurrentTime(uint32_t p_time)
{
	m_ended = false;
	SeekTo((int64_t)p_time * kGstMillisecond);
}

void MCGstPlayer::StepFrame(void)
{
	if (m_pipeline == nullptr)
		return;
	void *t_event = s_gst.gst_event_new_step(kGstFormatBuffers, 1, 1.0, 1, 0);
	if (t_event != nullptr)
		s_gst.gst_element_send_event(m_pipeline, t_event);
}

void MCGstPlayer::Skip(int32_t p_seconds)
{
	m_ended = false;
	SeekTo((int64_t)GetCurrentTime() * kGstMillisecond + (int64_t)p_seconds * kGstSecond);
}

void MCGstPlayer::SetRate(double p_rate)
{
	// mplayer's speed is above 0; a rate it would not take changes nothing
	if (!(p_rate > 0) || p_rate == m_rate)
		return;
	m_rate = p_rate;
	SeekTo((int64_t)GetCurrentTime() * kGstMillisecond);
}

void MCGstPlayer::SetLooping(bool p_looping)
{
	m_looping = p_looping;
}

void MCGstPlayer::SetLoudness(uint32_t p_loudness)
{
	if (p_loudness > 100)
		p_loudness = 100;
	m_loudness = p_loudness;
	if (m_pipeline != nullptr)
		s_gst.g_object_set(m_pipeline, "volume", m_loudness / 100.0, nullptr);
}

void MCGstPlayer::Redraw(void)
{
	// (a fakesink, without a window, is no overlay: nothing to draw then)
	if (m_overlay && m_pipeline != nullptr)
		s_gst.gst_video_overlay_expose(m_video_sink);
}
