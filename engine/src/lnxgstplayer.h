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

// OXT-Beyond: the player's movie through GStreamer, on Linux, for a machine
// without mplayer (which many distributions no longer package). GStreamer
// is loaded with dlopen when a player first needs it, so the engine runs
// as before where it is not installed. The movie plays in playbin; its
// video is drawn into the X window the engine made for it (lnxmplayer.cpp
// makes that window, as it does for mplayer, and decides which of the two
// plays a movie).
//
// This file includes no engine header, and no GStreamer or GLib one, so it
// builds where their development packages are missing, and on its own for
// tools/ci/gst_player_check.py, which runs it without the engine.

#ifndef LNXGSTPLAYER_H
#define LNXGSTPLAYER_H

#include <stdint.h>

class MCGstPlayer
{
public:
	// Whether GStreamer and its video library load, and gst_init_check
	// succeeds; tried once, then remembered.
	static bool IsAvailable(void);

	// The movie at p_location (a path, or a URL GStreamer reads) in a new
	// player, paused at its start, its first frame drawn in the X window
	// p_xid (0: the video is not drawn, as for tools/ci's check). With
	// p_xvideo, the video goes through XVideo (xvimagesink), keeping its
	// aspect ratio, as mplayer's default output does; otherwise through
	// plain X (ximagesink), filling the window, as mplayer's "-vo x11
	// -nokeepaspect" does. nil when the movie does not open: GStreamer is
	// missing, the file is not there, or no installed plugin reads it.
	static MCGstPlayer *Create(const char *p_location, unsigned long p_xid, bool p_xvideo);

	// Whether some player has reached the end of its movie (or failed)
	// since the last call: the event loop asks, then asks each player
	// (TakeEnded). Set from GLib's main loop, which the engine runs.
	static bool TakeAnyEnded(void);

	~MCGstPlayer(void);

	void Play(void);
	void Pause(void);
	bool IsPlaying(void) const { return m_playing; }

	// True once after the movie has played to its end (and does not loop)
	// or GStreamer has failed to play it.
	bool TakeEnded(void);

	// Times in milliseconds
	uint32_t GetDuration(void);
	uint32_t GetCurrentTime(void);
	void SetCurrentTime(uint32_t p_time);

	// Moves on one frame, or by p_seconds (back when negative)
	void StepFrame(void);
	void Skip(int32_t p_seconds);

	// The rate (ignored unless above 0, as mplayer's speed), whether the
	// movie starts again at its end, and the loudness (0 to 100)
	void SetRate(double p_rate);
	void SetLooping(bool p_looping);
	void SetLoudness(uint32_t p_loudness);
	uint32_t GetLoudness(void) const { return m_loudness; }

	// The window has been moved or resized: draw the frame again
	void Redraw(void);

	// GStreamer's bus calls this (from GLib's main loop)
	bool HandleBusMessage(uint32_t p_type);

private:
	MCGstPlayer(void);

	bool Open(const char *p_uri, unsigned long p_xid, bool p_xvideo, bool p_silent);
	void Close(void);
	bool SeekTo(int64_t p_nanoseconds);

	void *m_pipeline;
	void *m_video_sink;
	void *m_bus;
	bool m_watching;
	bool m_overlay;
	bool m_playing;
	bool m_looping;
	bool m_ended;
	double m_rate;
	uint32_t m_loudness;
	uint32_t m_duration;
};

#endif
