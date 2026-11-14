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

// OXT-Beyond: a movie played through Media Foundation (MFPlay), for the
// Windows player (w32-ds-player.cpp) when DirectShow cannot open a file.
//
// DirectShow has no reader for MP4 (H.264 and AAC) unless a third-party
// filter such as LAV Filters is installed; Media Foundation, part of
// Windows since Windows 7, opens it by itself. The player still opens
// every file with DirectShow first, as it always has, and only a file
// DirectShow cannot open comes here, so a file that played before plays
// through the same code as before.
//
// This file uses nothing of the engine's: it needs only the Windows
// headers, so that it can be compiled on its own (tools/ci/tests/
// test_mf_player.py). mfplay.dll is loaded at run time from the system
// folder, so that the engine still starts on a Windows without Media
// Foundation (the N editions without the Media Feature Pack, Windows
// Server without its Media Foundation feature): there the player is as
// before.

#ifndef __W32_MF_PLAYER_H__
#define __W32_MF_PLAYER_H__

#include <windows.h>
#include <stdint.h>

// What the playback tells the player that owns it. Called on the thread
// that opened it (MFPlay delivers its events through that thread's
// message loop), never from a thread of Media Foundation's own.
class MCWin32MFPlaybackOwner
{
public:
	// The movie reached its end, or Media Foundation stopped it with an
	// error (as DirectShow's EC_ERRORABORT ends a movie)
	virtual void MFPlaybackEnded(void) = 0;
};

class MCWin32MFPlaybackCallback;
struct IMFPMediaPlayer;

class MCWin32MFPlayback
{
public:
	// Pumps the thread's messages for a moment while the playback waits for
	// Media Foundation to set its movie up
	typedef void (*WaitFunction)(void);

	// Whether mfplay.dll loads (once: the answer is kept)
	static bool IsAvailable(void);

	// The movie at p_path in p_video_window (which may be NULL for sound
	// alone), paused at its start; NULL when Media Foundation cannot open
	// it. It waits (calling p_wait) until Media Foundation has set the movie
	// up, at most p_timeout_ms milliseconds, so that its duration, size and
	// media types are known when this returns, as DirectShow's are.
	static MCWin32MFPlayback *Open(const wchar_t *p_path, HWND p_video_window, MCWin32MFPlaybackOwner *p_owner,
	                               WaitFunction p_wait, DWORD p_timeout_ms);

	~MCWin32MFPlayback(void);

	bool HasVideo(void) const { return m_has_video; }
	bool HasAudio(void) const { return m_has_audio; }

	// Times are in 100-nanosecond units, as DirectShow's media time
	bool GetDuration(int64_t &r_duration);
	bool GetPosition(int64_t &r_position);
	bool SetPosition(int64_t p_position);
	// The length of a frame (100 ns units), from the movie's frame rate; 0
	// when it has no video or does not say
	int64_t GetFrameLength(void) const { return m_frame_length; }

	bool GetRate(double &r_rate);
	bool SetRate(double p_rate);

	// 0.0 (silent) to 1.0
	bool GetVolume(double &r_volume);
	bool SetVolume(double p_volume);

	bool GetVideoSize(uint32_t &r_width, uint32_t &r_height);

	bool Play(void);
	bool Pause(void);

	// Draws the current frame again, for the video window's WM_PAINT and
	// WM_SIZE (the video fills the window, as DirectShow's does)
	void UpdateVideo(void);

	// From the callback object: MFPlay's events
	void HandleMediaItemSet(HRESULT p_result);
	void HandleEnded(void);

private:
	MCWin32MFPlayback(void);

	bool SetItem(const wchar_t *p_path, bool p_without_audio, WaitFunction p_wait, DWORD p_timeout_ms,
	             HRESULT &r_result);

	IMFPMediaPlayer *m_player;
	MCWin32MFPlaybackCallback *m_callback;
	MCWin32MFPlaybackOwner *m_owner;

	bool m_has_video;
	bool m_has_audio;
	int64_t m_frame_length;

	// MFP_EVENT_TYPE_MEDIAITEM_SET: whether it came, and its result
	bool m_item_set_done;
	HRESULT m_item_set_result;
};

#endif
