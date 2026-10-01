/* Copyright (C) 2026 OXT-Beyond contributors.

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

// A platform player backed by libVLC 3.x.
//
// libVLC is loaded at run time, so the engine does not depend on it: when it
// cannot be loaded, MCPlatformCreatePlayer falls back to the DirectShow player.
// Video is decoded into memory (libvlc_video_set_callbacks) and drawn by the
// engine through LockBitmap, so the player is always "offscreen": it works in
// layered stacks, scrolling groups, snapshots, printing and edit mode, and
// objects can be drawn over it.
//
// libVLC calls the video callbacks and the event callback on its own threads.
// Everything that touches the engine is posted to a message-only window and
// handled on the main thread.
//
// Behaviour of libVLC 3 this code relies on, measured with
// tools/vlc-spike/vlcspike.c (see docs/development/vlc-player-plan.md):
//   - A media with :start-paused stops before showing any picture; one
//     libvlc_media_player_next_frame then shows the first frame.
//   - A seek while paused shows nothing new, so to show the frame at a time
//     while paused the player seeks, plays muted until one picture arrives,
//     and pauses again ("scrubbing").
//   - While paused, libVLC redisplays the last picture every 80 ms; those
//     calls are ignored.
//   - The size offered to the format callback is the decoder's aligned buffer
//     size; requesting any size other than the stored video size makes libVLC
//     rescale every frame, so the stored size is requested and the engine
//     scales when drawing.
//   - RV32 is the engine's pixel order on Windows (BGRA, alpha 0xFF).

#if defined(TARGET_PLATFORM_WINDOWS)
#include <Windows.h>
#endif

#include <string.h>
#include <atomic>
#include <mutex>

#include "globals.h"
#include "osspec.h"

#include "graphics_util.h"
#include "imagebitmap.h"
#include "platform.h"
#include "platform-internal.h"

#if defined(TARGET_PLATFORM_WINDOWS)

////////////////////////////////////////////////////////////////////////////////

// libVLC 3.x declarations, from include/vlc/libvlc*.h on the 3.0.x branch.
// Only the leading fields of libvlc_video_track_t are declared; it is only
// ever accessed through a pointer.

typedef struct libvlc_instance_t libvlc_instance_t;
typedef struct libvlc_media_t libvlc_media_t;
typedef struct libvlc_media_player_t libvlc_media_player_t;
typedef struct libvlc_event_manager_t libvlc_event_manager_t;
typedef int64_t libvlc_time_t;

struct libvlc_event_t
{
	int type;
	void *p_obj;
	union
	{
		struct { float new_cache; } media_player_buffering;
		struct { libvlc_time_t new_time; } media_player_time_changed;
		struct { libvlc_time_t new_length; } media_player_length_changed;
	} u;
};

enum
{
	kLibVLCEventPlaying = 0x104,
	kLibVLCEventPaused = 0x105,
	kLibVLCEventStopped = 0x106,
	kLibVLCEventEndReached = 0x109,
	kLibVLCEventEncounteredError = 0x10A,
	kLibVLCEventLengthChanged = 0x111,
};

enum
{
	kLibVLCStateNothingSpecial,
	kLibVLCStateOpening,
	kLibVLCStateBuffering,
	kLibVLCStatePlaying,
	kLibVLCStatePaused,
	kLibVLCStateStopped,
	kLibVLCStateEnded,
	kLibVLCStateError,
};

enum
{
	kLibVLCParseLocal = 0x00,
	kLibVLCParseNetwork = 0x01,
};

enum
{
	kLibVLCParsedStatusSkipped = 1,
	kLibVLCParsedStatusFailed,
	kLibVLCParsedStatusTimeout,
	kLibVLCParsedStatusDone,
};

enum
{
	kLibVLCTrackAudio = 0,
	kLibVLCTrackVideo = 1,
	kLibVLCTrackText = 2,
};

struct libvlc_audio_track_t
{
	unsigned i_channels;
	unsigned i_rate;
};

struct libvlc_video_track_t
{
	unsigned i_height;
	unsigned i_width;
	unsigned i_sar_num;
	unsigned i_sar_den;
	unsigned i_frame_rate_num;
	unsigned i_frame_rate_den;
};

struct libvlc_media_track_t
{
	uint32_t i_codec;
	uint32_t i_original_fourcc;
	int i_id;
	int i_type;
	int i_profile;
	int i_level;
	union
	{
		libvlc_audio_track_t *audio;
		libvlc_video_track_t *video;
		void *subtitle;
	} u;
	unsigned int i_bitrate;
	char *psz_language;
	char *psz_description;
};

typedef void (*libvlc_callback_t)(const libvlc_event_t *, void *);
typedef void *(*libvlc_video_lock_cb)(void *, void **);
typedef void (*libvlc_video_unlock_cb)(void *, void *, void *const *);
typedef void (*libvlc_video_display_cb)(void *, void *);
typedef unsigned (*libvlc_video_format_cb)(void **, char *, unsigned *, unsigned *, unsigned *, unsigned *);
typedef void (*libvlc_video_cleanup_cb)(void *);

#define MC_LIBVLC_FUNCTIONS(X) \
	X(const char *, libvlc_get_version, (void)) \
	X(libvlc_instance_t *, libvlc_new, (int, const char *const *)) \
	X(libvlc_media_t *, libvlc_media_new_path, (libvlc_instance_t *, const char *)) \
	X(libvlc_media_t *, libvlc_media_new_location, (libvlc_instance_t *, const char *)) \
	X(void, libvlc_media_release, (libvlc_media_t *)) \
	X(void, libvlc_media_add_option, (libvlc_media_t *, const char *)) \
	X(int, libvlc_media_parse_with_options, (libvlc_media_t *, int, int)) \
	X(int, libvlc_media_get_parsed_status, (libvlc_media_t *)) \
	X(libvlc_time_t, libvlc_media_get_duration, (libvlc_media_t *)) \
	X(unsigned, libvlc_media_tracks_get, (libvlc_media_t *, libvlc_media_track_t ***)) \
	X(void, libvlc_media_tracks_release, (libvlc_media_track_t **, unsigned)) \
	X(libvlc_media_player_t *, libvlc_media_player_new_from_media, (libvlc_media_t *)) \
	X(void, libvlc_media_player_release, (libvlc_media_player_t *)) \
	X(int, libvlc_media_player_play, (libvlc_media_player_t *)) \
	X(void, libvlc_media_player_set_pause, (libvlc_media_player_t *, int)) \
	X(void, libvlc_media_player_stop, (libvlc_media_player_t *)) \
	X(int, libvlc_media_player_get_state, (libvlc_media_player_t *)) \
	X(libvlc_time_t, libvlc_media_player_get_length, (libvlc_media_player_t *)) \
	X(libvlc_time_t, libvlc_media_player_get_time, (libvlc_media_player_t *)) \
	X(void, libvlc_media_player_set_time, (libvlc_media_player_t *, libvlc_time_t)) \
	X(int, libvlc_media_player_set_rate, (libvlc_media_player_t *, float)) \
	X(void, libvlc_media_player_next_frame, (libvlc_media_player_t *)) \
	X(int, libvlc_audio_set_volume, (libvlc_media_player_t *, int)) \
	X(void, libvlc_audio_set_mute, (libvlc_media_player_t *, int)) \
	X(int, libvlc_audio_set_track, (libvlc_media_player_t *, int)) \
	X(int, libvlc_video_set_track, (libvlc_media_player_t *, int)) \
	X(int, libvlc_video_set_spu, (libvlc_media_player_t *, int)) \
	X(libvlc_event_manager_t *, libvlc_media_player_event_manager, (libvlc_media_player_t *)) \
	X(int, libvlc_event_attach, (libvlc_event_manager_t *, int, libvlc_callback_t, void *)) \
	X(void, libvlc_video_set_callbacks, (libvlc_media_player_t *, libvlc_video_lock_cb, libvlc_video_unlock_cb, libvlc_video_display_cb, void *)) \
	X(void, libvlc_video_set_format_callbacks, (libvlc_media_player_t *, libvlc_video_format_cb, libvlc_video_cleanup_cb))

#define MC_LIBVLC_DECLARE(ret, name, args) ret (*name) args;
static struct { MC_LIBVLC_FUNCTIONS(MC_LIBVLC_DECLARE) } s_libvlc;
#undef MC_LIBVLC_DECLARE

static bool s_libvlc_tried = false;
static libvlc_instance_t *s_libvlc_instance = nil;

////////////////////////////////////////////////////////////////////////////////

extern HINSTANCE MChInst;

#define kMCLibVLCWindowClass "MCLIBVLCPLAYERWINDOW"

#define kMCLibVLCTimerID (1)
#define kMCLibVLCTimerInterval (100) // ms, as the DirectShow player

#define kMCLibVLCMessageFrame (WM_APP + 1)
#define kMCLibVLCMessageEvent (WM_APP + 2)
#define kMCLibVLCMessageScrubbed (WM_APP + 3)
#define kMCLibVLCMessagePrime (WM_APP + 4)

// Time while libVLC still flushes audio after a muted scrub pauses.
#define kMCLibVLCUnmuteTicks (2)

static HMODULE MCLibVLCTryLoad(const wchar_t *p_folder)
{
	wchar_t t_path[MAX_PATH];
	if (_snwprintf_s(t_path, MAX_PATH, _TRUNCATE, L"%s\\libvlc.dll", p_folder) < 0)
		return nil;

	if (GetFileAttributesW(t_path) == INVALID_FILE_ATTRIBUTES)
		return nil;

	// LOAD_WITH_ALTERED_SEARCH_PATH lets libvlc.dll find libvlccore.dll in
	// its own folder; libVLC then finds its plugins next to libvlccore.dll.
	return LoadLibraryExW(t_path, nil, LOAD_WITH_ALTERED_SEARCH_PATH);
}

static HMODULE MCLibVLCLoadLibrary(void)
{
	wchar_t t_folder[MAX_PATH];
	HMODULE t_module = nil;

	// 1. A folder given for testing.
	DWORD t_length = GetEnvironmentVariableW(L"OXT_LIBVLC_DIR", t_folder, MAX_PATH);
	if (t_length > 0 && t_length < MAX_PATH)
		t_module = MCLibVLCTryLoad(t_folder);

	// 2. A copy bundled with the application, in Externals\VLC.
	if (t_module == nil)
	{
		t_length = GetModuleFileNameW(nil, t_folder, MAX_PATH);
		if (t_length > 0 && t_length < MAX_PATH)
		{
			wchar_t *t_separator = wcsrchr(t_folder, L'\\');
			if (t_separator != nil)
			{
				*t_separator = 0;
				wcsncat_s(t_folder, MAX_PATH, L"\\Externals\\VLC", _TRUNCATE);
				t_module = MCLibVLCTryLoad(t_folder);
			}
		}
	}

	// 3. An installed VLC; its installer records its folder here. Only a
	//    64-bit VLC can load, and it records itself in the 64-bit view.
	HKEY t_key;
	if (t_module == nil &&
		RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"Software\\VideoLAN\\VLC", 0, KEY_QUERY_VALUE | KEY_WOW64_64KEY, &t_key) == ERROR_SUCCESS)
	{
		DWORD t_type = 0, t_size = sizeof(t_folder) - sizeof(wchar_t);
		MCMemoryClear(t_folder, sizeof(t_folder));
		if (RegQueryValueExW(t_key, L"InstallDir", nil, &t_type, (LPBYTE)t_folder, &t_size) == ERROR_SUCCESS && t_type == REG_SZ)
			t_module = MCLibVLCTryLoad(t_folder);
		RegCloseKey(t_key);
	}

	return t_module;
}

// Loads libVLC 3 once per process. Returns false when the player should use
// DirectShow instead.
static bool MCLibVLCInitialize(void)
{
	if (s_libvlc_tried)
		return s_libvlc_instance != nil;
	s_libvlc_tried = true;

	char t_backend[32];
	DWORD t_length = GetEnvironmentVariableA("OXT_PLAYER_BACKEND", t_backend, sizeof(t_backend));
	if (t_length > 0 && t_length < sizeof(t_backend) && _stricmp(t_backend, "directshow") == 0)
		return false;

	HMODULE t_module = MCLibVLCLoadLibrary();
	if (t_module == nil)
		return false;

	bool t_resolved = true;
#define MC_LIBVLC_RESOLVE(ret, name, args) \
	if ((*(FARPROC *)&s_libvlc.name = GetProcAddress(t_module, #name)) == nil) \
		t_resolved = false;
	MC_LIBVLC_FUNCTIONS(MC_LIBVLC_RESOLVE)
#undef MC_LIBVLC_RESOLVE

	// libVLC 4 changed the API (libvlc_media_new_path lost its instance
	// argument, among others), so anything but 3.x is refused.
	if (!t_resolved || s_libvlc.libvlc_get_version == nil || strncmp(s_libvlc.libvlc_get_version(), "3.", 2) != 0)
	{
		FreeLibrary(t_module);
		return false;
	}

	const char *t_args[] =
	{
		"--ignore-config", // the user's own VLC settings must not change the player
		"--quiet",
		"--no-video-title-show",
		"--no-osd",
		"--no-snapshot-preview",
	};
	s_libvlc_instance = s_libvlc.libvlc_new(sizeof(t_args) / sizeof(t_args[0]), t_args);

	return s_libvlc_instance != nil;
}

////////////////////////////////////////////////////////////////////////////////

struct MCLibVLCTrack
{
	uint32_t id;
	int type;
	bool enabled;
};

enum MCLibVLCPlayerState
{
	kMCLibVLCPlayerStopped, // finished; the next start begins again
	kMCLibVLCPlayerPaused,
	kMCLibVLCPlayerPlaying,
};

enum MCLibVLCPrimeState
{
	kMCLibVLCPrimeNone,
	kMCLibVLCPrimeQueued,      // the input will start when the prime message arrives
	kMCLibVLCPrimeWaitPaused,  // the input started paused; waiting for the Paused event
};

class MCLibVLCPlayer : public MCPlatformPlayer
{
public:
	MCLibVLCPlayer(void);
	virtual ~MCLibVLCPlayer(void);

	bool Initialize(void);

	virtual bool GetNativeView(void *&r_view);
	virtual bool SetNativeParentView(void *p_parent_view);

	virtual bool IsPlaying(void);
	virtual void Start(double rate);
	virtual void Stop(void);
	virtual void Step(int amount);

	virtual bool LockBitmap(const MCGIntegerSize &p_size, MCImageBitmap*& r_bitmap);
	virtual void UnlockBitmap(MCImageBitmap *bitmap);

	virtual void SetProperty(MCPlatformPlayerProperty property, MCPlatformPropertyType type, void *value);
	virtual void GetProperty(MCPlatformPlayerProperty property, MCPlatformPropertyType type, void *value);

	virtual void CountTracks(uindex_t& r_count);
	virtual bool FindTrackWithId(uint32_t id, uindex_t& r_index);
	virtual void SetTrackProperty(uindex_t index, MCPlatformPlayerTrackProperty property, MCPlatformPropertyType type, void *value);
	virtual void GetTrackProperty(uindex_t index, MCPlatformPlayerTrackProperty property, MCPlatformPropertyType type, void *value);

	// Main thread, from the message window.
	void HandleMessage(UINT p_message, WPARAM p_wparam, LPARAM p_lparam);

	// libVLC threads.
	unsigned VideoFormat(char *p_chroma, unsigned *p_width, unsigned *p_height, unsigned *p_pitches, unsigned *p_lines);
	void *VideoLock(void **p_planes);
	void VideoDisplay(void);
	void LibVLCEvent(const libvlc_event_t *p_event);

protected:
	virtual void Realize(void);
	virtual void Unrealize(void);

private:
	bool Open(MCStringRef p_location, bool p_is_url);
	void Close(void);

	bool HasVideo(void) const { return (m_media_types & kMCPlatformPlayerMediaTypeVideo) != 0; }
	int GetLibVLCState(void);
	MCPlatformPlayerDuration GetPlaybackTime(void);
	void SetCurrentTime(MCPlatformPlayerDuration p_time);
	void GetSelection(MCPlatformPlayerDuration &r_start, MCPlatformPlayerDuration &r_finish);

	void StartInput(void);
	void RestartInput(MCPlatformPlayerDuration p_time);
	void ShowFrameAt(MCPlatformPlayerDuration p_time);
	void Mute(bool p_mute);
	void ApplyVolume(void);
	void ApplyTracks(void);
	void Finish(MCPlatformPlayerDuration p_position);

	void HandleEvent(int p_type);
	void HandleTimer(void);
	void HandleScrubbed(void);

	void Post(UINT p_message, WPARAM p_wparam);

	HWND m_window;
	uint32_t m_generation;

	libvlc_media_t *m_media;
	libvlc_media_player_t *m_player;
	bool m_is_valid;
	bool m_media_repeats;

	MCPlatformPlayerMediaTypes m_media_types;
	MCPlatformPlayerDuration m_duration;
	double m_frame_length;
	uint32_t m_video_width, m_video_height;
	uint32_t m_display_width, m_display_height;
	MCLibVLCTrack *m_tracks;
	uindex_t m_track_count;
	bool m_tracks_changed;

	MCLibVLCPlayerState m_state;
	MCLibVLCPrimeState m_prime;
	MCPlatformPlayerDuration m_position;
	MCPlatformPlayerDuration m_last_tick_time;
	bool m_want_play;
	bool m_muted;
	uint32_t m_unmute_ticks;

	double m_rate;
	uint16_t m_volume;
	bool m_looping;
	bool m_play_selection;
	MCPlatformPlayerDuration m_start_time, m_finish_time;
	double m_left_balance, m_right_balance, m_pan;

	MCPlatformPlayerDurationArray m_markers;
	index_t m_last_marker;

	// Shared with libVLC's threads.
	std::atomic<uint32_t> m_post_generation;
	std::atomic<bool> m_deliver_frames;
	std::atomic<bool> m_scrubbing;
	std::atomic<bool> m_frame_posted;
	std::atomic<bool> m_mirrored;

	std::mutex m_frame_lock;
	uint8_t *m_decode_buffer; // libVLC writes the next picture here
	uint8_t *m_front_buffer;  // the last picture shown; what LockBitmap returns
	uint32_t m_frame_width, m_frame_height, m_frame_stride, m_frame_lines;
	bool m_has_frame;
	MCImageBitmap m_bitmap;
};

////////////////////////////////////////////////////////////////////////////////

static LRESULT CALLBACK MCLibVLCWindowProc(HWND p_window, UINT p_message, WPARAM p_wparam, LPARAM p_lparam)
{
	if (p_message == WM_CREATE)
	{
		CREATESTRUCT *t_create = (CREATESTRUCT *)p_lparam;
		SetWindowLongPtr(p_window, GWLP_USERDATA, (LONG_PTR)t_create->lpCreateParams);
		return 0;
	}

	if (p_message == WM_TIMER || (p_message >= kMCLibVLCMessageFrame && p_message <= kMCLibVLCMessagePrime))
	{
		MCLibVLCPlayer *t_player = (MCLibVLCPlayer *)GetWindowLongPtr(p_window, GWLP_USERDATA);
		if (t_player != nil)
			t_player->HandleMessage(p_message, p_wparam, p_lparam);
		return 0;
	}

	return DefWindowProc(p_window, p_message, p_wparam, p_lparam);
}

static bool MCLibVLCRegisterWindowClass(void)
{
	static bool s_registered = false;
	if (s_registered)
		return true;

	WNDCLASSA t_class;
	MCMemoryClear(t_class);
	t_class.lpfnWndProc = MCLibVLCWindowProc;
	t_class.hInstance = MChInst;
	t_class.lpszClassName = kMCLibVLCWindowClass;
	s_registered = RegisterClassA(&t_class) != 0;
	return s_registered;
}

static unsigned MCLibVLCVideoFormatCallback(void **p_opaque, char *p_chroma, unsigned *p_width, unsigned *p_height, unsigned *p_pitches, unsigned *p_lines)
{
	return ((MCLibVLCPlayer *)*p_opaque)->VideoFormat(p_chroma, p_width, p_height, p_pitches, p_lines);
}

static void MCLibVLCVideoCleanupCallback(void *p_opaque)
{
}

static void *MCLibVLCVideoLockCallback(void *p_opaque, void **p_planes)
{
	return ((MCLibVLCPlayer *)p_opaque)->VideoLock(p_planes);
}

static void MCLibVLCVideoUnlockCallback(void *p_opaque, void *p_picture, void *const *p_planes)
{
}

static void MCLibVLCVideoDisplayCallback(void *p_opaque, void *p_picture)
{
	((MCLibVLCPlayer *)p_opaque)->VideoDisplay();
}

static void MCLibVLCEventCallback(const libvlc_event_t *p_event, void *p_opaque)
{
	((MCLibVLCPlayer *)p_opaque)->LibVLCEvent(p_event);
}

////////////////////////////////////////////////////////////////////////////////

MCLibVLCPlayer::MCLibVLCPlayer(void)
	: m_post_generation(0), m_deliver_frames(false), m_scrubbing(false), m_frame_posted(false), m_mirrored(false)
{
	m_window = nil;
	m_generation = 0;

	m_media = nil;
	m_player = nil;
	m_is_valid = false;
	m_media_repeats = false;

	m_media_types = 0;
	m_duration = 0;
	m_frame_length = 1000.0 / 30.0;
	m_video_width = m_video_height = 0;
	m_display_width = m_display_height = 0;
	m_tracks = nil;
	m_track_count = 0;
	m_tracks_changed = false;

	m_state = kMCLibVLCPlayerPaused;
	m_prime = kMCLibVLCPrimeNone;
	m_position = 0;
	m_last_tick_time = 0;
	m_want_play = false;
	m_muted = false;
	m_unmute_ticks = 0;

	m_rate = 1.0;
	m_volume = 100;
	m_looping = false;
	m_play_selection = false;
	m_start_time = m_finish_time = 0;
	m_left_balance = m_right_balance = 100.0;
	m_pan = 0.0;

	m_markers.ptr = nil;
	m_markers.count = 0;
	m_last_marker = -1;

	m_decode_buffer = nil;
	m_front_buffer = nil;
	m_frame_width = m_frame_height = m_frame_stride = m_frame_lines = 0;
	m_has_frame = false;
	MCMemoryClear(m_bitmap);
}

MCLibVLCPlayer::~MCLibVLCPlayer(void)
{
	// Close stops libVLC's threads, so nothing is posted to the window after.
	Close();

	if (m_window != nil)
	{
		KillTimer(m_window, kMCLibVLCTimerID);
		SetWindowLongPtr(m_window, GWLP_USERDATA, 0);
		DestroyWindow(m_window);
	}

	MCPlatformArrayClear(m_markers);
}

bool MCLibVLCPlayer::Initialize(void)
{
	if (!MCLibVLCRegisterWindowClass())
		return false;

	m_window = CreateWindowA(kMCLibVLCWindowClass, "LibVLCPlayer", 0, 0, 0, 0, 0, HWND_MESSAGE, nil, MChInst, this);
	return m_window != nil;
}

void MCLibVLCPlayer::Post(UINT p_message, WPARAM p_wparam)
{
	PostMessage(m_window, p_message, p_wparam, (LPARAM)m_post_generation.load());
}

////////////////////////////////////////////////////////////////////////////////

bool MCLibVLCPlayer::Open(MCStringRef p_location, bool p_is_url)
{
	MCAutoStringRef t_location;
	if (p_is_url)
		t_location = p_location;
	else if (!MCS_pathtonative(p_location, &t_location))
		return false;

	MCAutoStringRefAsUTF8String t_utf8;
	if (!t_utf8.Lock(*t_location))
		return false;

	if (p_is_url)
		m_media = s_libvlc.libvlc_media_new_location(s_libvlc_instance, *t_utf8);
	else
		m_media = s_libvlc.libvlc_media_new_path(s_libvlc_instance, *t_utf8);
	if (m_media == nil)
		return false;

	// Parse now: the engine reads the movie size and duration as soon as the
	// filename is set. Local files take tens of milliseconds.
	s_libvlc.libvlc_media_parse_with_options(m_media, p_is_url ? kLibVLCParseNetwork : kLibVLCParseLocal, 5000);
	int t_status = 0;
	for (int t_waited = 0; t_waited < 6000; t_waited += 5)
	{
		t_status = s_libvlc.libvlc_media_get_parsed_status(m_media);
		if (t_status != 0)
			break;
		Sleep(5);
	}

	if (t_status == kLibVLCParsedStatusFailed || (!p_is_url && t_status != kLibVLCParsedStatusDone))
		return false;

	libvlc_time_t t_duration = s_libvlc.libvlc_media_get_duration(m_media);
	m_duration = t_duration > 0 ? (MCPlatformPlayerDuration)t_duration : 0;

	libvlc_media_track_t **t_tracks = nil;
	unsigned t_count = s_libvlc.libvlc_media_tracks_get(m_media, &t_tracks);
	if (t_count > 0 && !MCMemoryNewArray(t_count, m_tracks))
	{
		s_libvlc.libvlc_media_tracks_release(t_tracks, t_count);
		return false;
	}

	bool t_have_video = false, t_have_audio = false, t_have_text = false;
	for (unsigned i = 0; i < t_count; i++)
	{
		libvlc_media_track_t *t_track = t_tracks[i];
		MCLibVLCTrack &t_entry = m_tracks[m_track_count++];
		t_entry.id = (uint32_t)t_track->i_id;
		t_entry.type = t_track->i_type;
		t_entry.enabled = false;

		switch (t_track->i_type)
		{
		case kLibVLCTrackVideo:
			// libVLC plays the first video and audio tracks by default.
			t_entry.enabled = !t_have_video;
			if (!t_have_video && t_track->u.video != nil)
			{
				libvlc_video_track_t *t_video = t_track->u.video;
				m_video_width = t_video->i_width;
				m_video_height = t_video->i_height;
				m_display_width = t_video->i_width;
				m_display_height = t_video->i_height;
				if (t_video->i_sar_num != 0 && t_video->i_sar_den != 0 && t_video->i_sar_num != t_video->i_sar_den)
					m_display_width = (uint32_t)(((uint64_t)t_video->i_width * t_video->i_sar_num) / t_video->i_sar_den);
				if (t_video->i_frame_rate_num != 0 && t_video->i_frame_rate_den != 0)
					m_frame_length = 1000.0 * t_video->i_frame_rate_den / t_video->i_frame_rate_num;
			}
			t_have_video = true;
			m_media_types |= kMCPlatformPlayerMediaTypeVideo;
			break;

		case kLibVLCTrackAudio:
			t_entry.enabled = !t_have_audio;
			t_have_audio = true;
			m_media_types |= kMCPlatformPlayerMediaTypeAudio;
			break;

		case kLibVLCTrackText:
			t_have_text = true;
			m_media_types |= kMCPlatformPlayerMediaTypeText;
			break;
		}
	}
	s_libvlc.libvlc_media_tracks_release(t_tracks, t_count);

	// A local file without audio or video is not media.
	if (!p_is_url && !t_have_video && !t_have_audio)
		return false;

	m_player = s_libvlc.libvlc_media_player_new_from_media(m_media);
	if (m_player == nil)
		return false;

	s_libvlc.libvlc_video_set_callbacks(m_player, MCLibVLCVideoLockCallback, MCLibVLCVideoUnlockCallback, MCLibVLCVideoDisplayCallback, this);
	s_libvlc.libvlc_video_set_format_callbacks(m_player, MCLibVLCVideoFormatCallback, MCLibVLCVideoCleanupCallback);

	libvlc_event_manager_t *t_events = s_libvlc.libvlc_media_player_event_manager(m_player);
	const int t_types[] = { kLibVLCEventPlaying, kLibVLCEventPaused, kLibVLCEventStopped, kLibVLCEventEndReached,
	                        kLibVLCEventEncounteredError, kLibVLCEventLengthChanged };
	for (uindex_t i = 0; i < sizeof(t_types) / sizeof(t_types[0]); i++)
		s_libvlc.libvlc_event_attach(t_events, t_types[i], MCLibVLCEventCallback, this);

	// The input starts once the engine has finished setting up the player
	// (current time, looping, ...), when the prime message arrives.
	m_prime = kMCLibVLCPrimeQueued;
	Post(kMCLibVLCMessagePrime, 0);

	SetTimer(m_window, kMCLibVLCTimerID, kMCLibVLCTimerInterval, nil);

	return true;
}

void MCLibVLCPlayer::Close(void)
{
	if (m_window != nil)
		KillTimer(m_window, kMCLibVLCTimerID);

	// Stopping joins libVLC's threads; messages they posted are then ignored
	// because the generation changes.
	if (m_player != nil)
	{
		s_libvlc.libvlc_media_player_stop(m_player);
		s_libvlc.libvlc_media_player_release(m_player);
		m_player = nil;
	}

	if (m_media != nil)
	{
		s_libvlc.libvlc_media_release(m_media);
		m_media = nil;
	}

	m_generation += 1;
	m_post_generation.store(m_generation);

	MCMemoryDeleteArray(m_tracks);
	m_tracks = nil;
	m_track_count = 0;
	m_tracks_changed = false;

	m_is_valid = false;
	m_media_repeats = false;
	m_media_types = 0;
	m_duration = 0;
	m_frame_length = 1000.0 / 30.0;
	m_video_width = m_video_height = 0;
	m_display_width = m_display_height = 0;

	m_state = kMCLibVLCPlayerPaused;
	m_prime = kMCLibVLCPrimeNone;
	m_position = 0;
	m_last_tick_time = 0;
	m_want_play = false;
	m_muted = false;
	m_unmute_ticks = 0;
	m_last_marker = -1;

	m_deliver_frames.store(false);
	m_scrubbing.store(false);
	m_frame_posted.store(false);

	std::lock_guard<std::mutex> t_lock(m_frame_lock);
	MCMemoryDeallocate(m_decode_buffer);
	MCMemoryDeallocate(m_front_buffer);
	m_decode_buffer = m_front_buffer = nil;
	m_frame_width = m_frame_height = m_frame_stride = m_frame_lines = 0;
	m_has_frame = false;
}

////////////////////////////////////////////////////////////////////////////////

int MCLibVLCPlayer::GetLibVLCState(void)
{
	if (m_player == nil)
		return kLibVLCStateNothingSpecial;
	return s_libvlc.libvlc_media_player_get_state(m_player);
}

void MCLibVLCPlayer::GetSelection(MCPlatformPlayerDuration &r_start, MCPlatformPlayerDuration &r_finish)
{
	r_start = 0;
	r_finish = m_duration;

	if (m_play_selection && m_finish_time > m_start_time)
	{
		r_finish = m_duration != 0 ? MCMin(m_finish_time, m_duration) : m_finish_time;
		r_start = MCMin(m_start_time, r_finish);
	}
}

MCPlatformPlayerDuration MCLibVLCPlayer::GetPlaybackTime(void)
{
	// While paused, libVLC's time can lag by hundreds of milliseconds, so the
	// player reports the time it was last set or paused at.
	if (m_state != kMCLibVLCPlayerPlaying || m_player == nil)
		return m_position;

	libvlc_time_t t_time = s_libvlc.libvlc_media_player_get_time(m_player);
	return t_time > 0 ? (MCPlatformPlayerDuration)t_time : 0;
}

void MCLibVLCPlayer::StartInput(void)
{
	// Media options apply when the input starts. Every start is paused first,
	// so that a frame can be shown before playing; looping uses libVLC's own
	// repeat, which is almost seamless.
	if (m_prime == kMCLibVLCPrimeQueued)
	{
		s_libvlc.libvlc_media_add_option(m_media, ":start-paused");
		if (m_looping)
		{
			s_libvlc.libvlc_media_add_option(m_media, ":input-repeat=65535");
			m_media_repeats = true;
		}
	}

	m_prime = kMCLibVLCPrimeWaitPaused;
	s_libvlc.libvlc_media_player_play(m_player);
}

void MCLibVLCPlayer::RestartInput(MCPlatformPlayerDuration p_time)
{
	m_position = p_time;
	s_libvlc.libvlc_media_player_stop(m_player);
	StartInput();
}

void MCLibVLCPlayer::Mute(bool p_mute)
{
	if (m_muted == p_mute)
		return;
	m_muted = p_mute;
	s_libvlc.libvlc_audio_set_mute(m_player, p_mute ? 1 : 0);
}

void MCLibVLCPlayer::ApplyVolume(void)
{
	// libVLC 3 only applies volume to an existing audio output, and on
	// Windows the system remembers the last level per application, so the
	// player's own level is applied again whenever playback (re)starts.
	s_libvlc.libvlc_audio_set_volume(m_player, m_volume);
}

void MCLibVLCPlayer::ApplyTracks(void)
{
	if (!m_tracks_changed)
		return;

	int t_video = -1, t_audio = -1, t_text = -1;
	for (uindex_t i = 0; i < m_track_count; i++)
	{
		if (!m_tracks[i].enabled)
			continue;
		if (m_tracks[i].type == kLibVLCTrackVideo && t_video == -1)
			t_video = (int)m_tracks[i].id;
		else if (m_tracks[i].type == kLibVLCTrackAudio && t_audio == -1)
			t_audio = (int)m_tracks[i].id;
		else if (m_tracks[i].type == kLibVLCTrackText && t_text == -1)
			t_text = (int)m_tracks[i].id;
	}

	s_libvlc.libvlc_video_set_track(m_player, t_video);
	s_libvlc.libvlc_audio_set_track(m_player, t_audio);
	s_libvlc.libvlc_video_set_spu(m_player, t_text);
}

// Shows the picture at p_time while not playing.
void MCLibVLCPlayer::ShowFrameAt(MCPlatformPlayerDuration p_time)
{
	m_position = p_time;

	if (m_player == nil)
		return;

	// Before the input has paused, the time is applied when it does.
	if (m_prime != kMCLibVLCPrimeNone)
		return;

	int t_state = GetLibVLCState();
	if (t_state != kLibVLCStatePaused && t_state != kLibVLCStatePlaying)
	{
		RestartInput(p_time);
		return;
	}

	if (!HasVideo())
	{
		s_libvlc.libvlc_media_player_set_time(m_player, (libvlc_time_t)p_time);
		return;
	}

	// A seek while paused shows nothing in libVLC 3: play muted until one
	// picture arrives, then pause again (HandleScrubbed).
	m_scrubbing.store(true);
	m_unmute_ticks = 0;
	Mute(true);
	s_libvlc.libvlc_media_player_set_time(m_player, (libvlc_time_t)p_time);
	if (t_state == kLibVLCStatePaused)
		s_libvlc.libvlc_media_player_set_pause(m_player, 0);
}

void MCLibVLCPlayer::SetCurrentTime(MCPlatformPlayerDuration p_time)
{
	if (m_duration != 0 && p_time > m_duration)
		p_time = m_duration;

	if (m_state == kMCLibVLCPlayerPlaying)
	{
		// A backwards seek must not look like the media wrapping around.
		m_position = p_time;
		m_last_tick_time = p_time;
		s_libvlc.libvlc_media_player_set_time(m_player, (libvlc_time_t)p_time);
		return;
	}

	// Setting the time of a finished player makes it resume from there.
	if (m_state == kMCLibVLCPlayerStopped)
		m_state = kMCLibVLCPlayerPaused;

	ShowFrameAt(p_time);
}

void MCLibVLCPlayer::Finish(MCPlatformPlayerDuration p_position)
{
	if (m_player != nil && GetLibVLCState() == kLibVLCStatePlaying)
		s_libvlc.libvlc_media_player_set_pause(m_player, 1);

	m_position = p_position;
	m_state = kMCLibVLCPlayerStopped;
	m_want_play = false;
	m_deliver_frames.store(false);

	MCPlatformCallbackSendPlayerFinished(this);
}

////////////////////////////////////////////////////////////////////////////////

void MCLibVLCPlayer::HandleMessage(UINT p_message, WPARAM p_wparam, LPARAM p_lparam)
{
	if (p_message == WM_TIMER)
	{
		if (p_wparam == kMCLibVLCTimerID)
			HandleTimer();
		return;
	}

	// Messages posted before the media changed belong to the old media.
	if ((uint32_t)p_lparam != m_generation)
		return;

	switch (p_message)
	{
	case kMCLibVLCMessageFrame:
		m_frame_posted.store(false);
		MCPlatformCallbackSendPlayerFrameChanged(this);
		break;

	case kMCLibVLCMessageEvent:
		HandleEvent((int)p_wparam);
		break;

	case kMCLibVLCMessageScrubbed:
		HandleScrubbed();
		break;

	case kMCLibVLCMessagePrime:
		if (m_prime == kMCLibVLCPrimeQueued && m_player != nil)
			StartInput();
		break;
	}
}

void MCLibVLCPlayer::HandleEvent(int p_type)
{
	if (m_player == nil)
		return;

	switch (p_type)
	{
	case kLibVLCEventPlaying:
		ApplyVolume();
		ApplyTracks();
		break;

	case kLibVLCEventPaused:
		if (m_prime != kMCLibVLCPrimeWaitPaused)
			break;

		// The input has started, paused before its first picture.
		m_prime = kMCLibVLCPrimeNone;
		ApplyVolume();
		ApplyTracks();

		if (m_want_play)
		{
			if (m_position != 0)
				s_libvlc.libvlc_media_player_set_time(m_player, (libvlc_time_t)m_position);
			m_deliver_frames.store(true);
			s_libvlc.libvlc_media_player_set_pause(m_player, 0);
		}
		else if (HasVideo())
		{
			if (m_position == 0)
			{
				// One frame step shows the first picture without sound.
				m_scrubbing.store(true);
				s_libvlc.libvlc_media_player_next_frame(m_player);
			}
			else
				ShowFrameAt(m_position);
		}
		else if (m_position != 0)
			s_libvlc.libvlc_media_player_set_time(m_player, (libvlc_time_t)m_position);
		break;

	case kLibVLCEventEndReached:
		if (m_looping && m_state == kMCLibVLCPlayerPlaying)
		{
			// The media was opened without repeat; start it again.
			MCPlatformPlayerDuration t_start, t_finish;
			GetSelection(t_start, t_finish);
			RestartInput(t_start);
		}
		else if (m_state == kMCLibVLCPlayerPlaying)
			Finish(m_duration);
		break;

	case kLibVLCEventEncounteredError:
		if (m_state == kMCLibVLCPlayerPlaying)
			Finish(GetPlaybackTime());
		break;

	case kLibVLCEventLengthChanged:
		if (m_duration == 0)
		{
			libvlc_time_t t_length = s_libvlc.libvlc_media_player_get_length(m_player);
			if (t_length > 0)
				m_duration = (MCPlatformPlayerDuration)t_length;
		}
		break;

	case kLibVLCEventStopped:
		break;
	}
}

void MCLibVLCPlayer::HandleScrubbed(void)
{
	// A picture from a scrub or a frame step has arrived.
	if (m_state == kMCLibVLCPlayerPlaying)
		return;

	if (GetLibVLCState() == kLibVLCStatePlaying)
		s_libvlc.libvlc_media_player_set_pause(m_player, 1);

	if (m_muted)
		m_unmute_ticks = kMCLibVLCUnmuteTicks;
}

void MCLibVLCPlayer::HandleTimer(void)
{
	if (m_player == nil)
		return;

	if (m_unmute_ticks > 0 && --m_unmute_ticks == 0 && !m_scrubbing.load())
		Mute(false);

	if (m_state != kMCLibVLCPlayerPlaying || m_prime != kMCLibVLCPrimeNone)
		return;

	MCPlatformPlayerDuration t_current = GetPlaybackTime();

	// The media repeats, but looping has since been turned off: stop when the
	// time wraps around.
	if (m_media_repeats && !m_looping && t_current + 1000 < m_last_tick_time)
	{
		m_last_tick_time = 0;
		Finish(m_duration);
		return;
	}
	m_last_tick_time = t_current;

	MCPlatformPlayerDuration t_start, t_finish;
	GetSelection(t_start, t_finish);
	if (m_play_selection && t_finish > t_start)
	{
		if (t_current >= t_finish || t_current + 1000 < t_start)
		{
			if (m_looping)
			{
				s_libvlc.libvlc_media_player_set_time(m_player, (libvlc_time_t)t_start);
				t_current = t_start;
			}
			else
			{
				Finish(t_finish);
				return;
			}
		}
	}

	if (m_markers.count > 0)
	{
		while (m_last_marker >= 0 && t_current < m_markers.ptr[m_last_marker])
			m_last_marker--;

		index_t t_index = 0;
		while (t_index < (index_t)m_markers.count && m_markers.ptr[t_index] <= t_current)
			t_index++;

		if (t_index - 1 > m_last_marker)
		{
			m_last_marker = t_index - 1;
			MCPlatformCallbackSendPlayerMarkerChanged(this, m_markers.ptr[m_last_marker]);
		}
	}

	MCPlatformCallbackSendPlayerCurrentTimeChanged(this);
}

////////////////////////////////////////////////////////////////////////////////

unsigned MCLibVLCPlayer::VideoFormat(char *p_chroma, unsigned *p_width, unsigned *p_height, unsigned *p_pitches, unsigned *p_lines)
{
	// RV32 is BGRA in memory, the engine's pixel order on Windows.
	memcpy(p_chroma, "RV32", 4);

	if (m_video_width != 0 && m_video_height != 0)
	{
		*p_width = m_video_width;
		*p_height = m_video_height;
	}

	// libVLC recommends pitches and line counts that are multiples of 32.
	uint32_t t_stride = (*p_width * 4 + 31) & ~31u;
	uint32_t t_lines = (*p_height + 31) & ~31u;
	p_pitches[0] = t_stride;
	p_lines[0] = t_lines;

	std::lock_guard<std::mutex> t_lock(m_frame_lock);
	if (t_stride != m_frame_stride || t_lines != m_frame_lines || *p_width != m_frame_width || *p_height != m_frame_height)
	{
		MCMemoryDeallocate(m_decode_buffer);
		MCMemoryDeallocate(m_front_buffer);
		m_decode_buffer = m_front_buffer = nil;
		m_has_frame = false;

		if (!MCMemoryAllocate(t_stride * t_lines, m_decode_buffer) ||
			!MCMemoryAllocate(t_stride * t_lines, m_front_buffer))
		{
			MCMemoryDeallocate(m_decode_buffer);
			m_decode_buffer = nil;
			m_frame_width = m_frame_height = m_frame_stride = m_frame_lines = 0;
			return 0;
		}

		m_frame_width = *p_width;
		m_frame_height = *p_height;
		m_frame_stride = t_stride;
		m_frame_lines = t_lines;
	}

	return 1;
}

void *MCLibVLCPlayer::VideoLock(void **p_planes)
{
	// The decode buffer only changes in VideoFormat, which libVLC never calls
	// between lock and display.
	p_planes[0] = m_decode_buffer;
	return nil;
}

void MCLibVLCPlayer::VideoDisplay(void)
{
	bool t_scrubbing = m_scrubbing.load();
	if (!m_deliver_frames.load() && !t_scrubbing)
		return;

	{
		std::lock_guard<std::mutex> t_lock(m_frame_lock);
		if (m_front_buffer == nil || m_decode_buffer == nil)
			return;

		if (m_mirrored.load())
		{
			for (uint32_t y = 0; y < m_frame_height; y++)
			{
				const uint32_t *t_src = (const uint32_t *)(m_decode_buffer + y * m_frame_stride);
				uint32_t *t_dst = (uint32_t *)(m_front_buffer + y * m_frame_stride);
				for (uint32_t x = 0; x < m_frame_width; x++)
					t_dst[x] = t_src[m_frame_width - 1 - x];
			}
		}
		else
			memcpy(m_front_buffer, m_decode_buffer, m_frame_stride * m_frame_height);

		m_has_frame = true;
	}

	if (t_scrubbing && m_scrubbing.exchange(false))
		Post(kMCLibVLCMessageScrubbed, 0);

	if (!m_frame_posted.exchange(true))
		Post(kMCLibVLCMessageFrame, 0);
}

void MCLibVLCPlayer::LibVLCEvent(const libvlc_event_t *p_event)
{
	Post(kMCLibVLCMessageEvent, (WPARAM)p_event->type);
}

////////////////////////////////////////////////////////////////////////////////

bool MCLibVLCPlayer::GetNativeView(void *&r_view)
{
	// Video is always drawn by the engine.
	return false;
}

bool MCLibVLCPlayer::SetNativeParentView(void *p_parent_view)
{
	return true;
}

void MCLibVLCPlayer::Realize(void)
{
}

void MCLibVLCPlayer::Unrealize(void)
{
}

bool MCLibVLCPlayer::IsPlaying(void)
{
	return m_state == kMCLibVLCPlayerPlaying;
}

void MCLibVLCPlayer::Start(double p_rate)
{
	if (!m_is_valid || m_player == nil)
		return;

	if (p_rate > 0)
	{
		m_rate = p_rate;
		s_libvlc.libvlc_media_player_set_rate(m_player, (float)p_rate);
	}

	MCPlatformPlayerDuration t_start, t_finish;
	GetSelection(t_start, t_finish);

	// A finished player, or one outside its selection, starts from the
	// beginning of the selection.
	bool t_seek = false;
	if (m_state == kMCLibVLCPlayerStopped ||
		(m_play_selection && t_finish > t_start && (m_position < t_start || m_position >= t_finish)) ||
		(m_duration != 0 && m_position >= m_duration))
	{
		m_position = t_start;
		t_seek = true;
	}

	m_state = kMCLibVLCPlayerPlaying;
	m_want_play = true;
	m_last_tick_time = m_position;
	m_scrubbing.store(false);
	m_deliver_frames.store(true);
	m_unmute_ticks = 0;
	Mute(false);

	if (m_prime != kMCLibVLCPrimeNone)
		return; // HandleEvent starts playing when the input has paused

	int t_state = GetLibVLCState();
	if (t_state == kLibVLCStatePaused || t_state == kLibVLCStatePlaying)
	{
		if (t_seek)
			s_libvlc.libvlc_media_player_set_time(m_player, (libvlc_time_t)m_position);
		s_libvlc.libvlc_media_player_set_pause(m_player, 0);
	}
	else
		RestartInput(m_position);
}

void MCLibVLCPlayer::Stop(void)
{
	if (m_state == kMCLibVLCPlayerPlaying)
	{
		m_position = GetPlaybackTime();
		if (m_player != nil && m_prime == kMCLibVLCPrimeNone)
			s_libvlc.libvlc_media_player_set_pause(m_player, 1);
		m_state = kMCLibVLCPlayerPaused;
	}

	m_want_play = false;
	m_deliver_frames.store(false);
}

void MCLibVLCPlayer::Step(int p_amount)
{
	if (!m_is_valid)
		return;

	double t_target = (double)GetPlaybackTime() + p_amount * m_frame_length;
	if (t_target < 0)
		t_target = 0;

	SetCurrentTime((MCPlatformPlayerDuration)(t_target + 0.5));
}

bool MCLibVLCPlayer::LockBitmap(const MCGIntegerSize &p_size, MCImageBitmap*& r_bitmap)
{
	// The frame is returned at its stored size; MCPlayer::draw scales it.
	// The lock is held until UnlockBitmap so the picture cannot change while
	// it is drawn.
	m_frame_lock.lock();
	if (!m_has_frame || m_front_buffer == nil)
	{
		m_frame_lock.unlock();
		return false;
	}

	m_bitmap.width = m_frame_width;
	m_bitmap.height = m_frame_height;
	m_bitmap.stride = m_frame_stride;
	m_bitmap.data = (uint32_t *)m_front_buffer;
	m_bitmap.has_transparency = false;
	m_bitmap.has_alpha = false;

	r_bitmap = &m_bitmap;
	return true;
}

void MCLibVLCPlayer::UnlockBitmap(MCImageBitmap *p_bitmap)
{
	if (p_bitmap == &m_bitmap)
		m_frame_lock.unlock();
}

////////////////////////////////////////////////////////////////////////////////

void MCLibVLCPlayer::CountTracks(uindex_t &r_count)
{
	r_count = m_track_count;
}

bool MCLibVLCPlayer::FindTrackWithId(uint32_t p_id, uindex_t &r_index)
{
	for (uindex_t i = 0; i < m_track_count; i++)
		if (m_tracks[i].id == p_id)
		{
			r_index = i;
			return true;
		}
	return false;
}

void MCLibVLCPlayer::GetTrackProperty(uindex_t p_index, MCPlatformPlayerTrackProperty p_property, MCPlatformPropertyType p_type, void *r_value)
{
	if (p_index >= m_track_count)
		return;

	switch (p_property)
	{
	case kMCPlatformPlayerTrackPropertyId:
		*(uint32_t *)r_value = m_tracks[p_index].id;
		break;

	case kMCPlatformPlayerTrackPropertyMediaTypeName:
	{
		// The same names as the AVFoundation player.
		const char *t_name = "";
		if (m_tracks[p_index].type == kLibVLCTrackVideo)
			t_name = "vide";
		else if (m_tracks[p_index].type == kLibVLCTrackAudio)
			t_name = "soun";
		else if (m_tracks[p_index].type == kLibVLCTrackText)
			t_name = "sbtl";
		MCStringCreateWithCString(t_name, *(MCStringRef *)r_value);
		break;
	}

	case kMCPlatformPlayerTrackPropertyOffset:
		*(uint32_t *)r_value = 0;
		break;

	case kMCPlatformPlayerTrackPropertyDuration:
		*(uint32_t *)r_value = (uint32_t)MCMin(m_duration, (MCPlatformPlayerDuration)UINT32_MAX);
		break;

	case kMCPlatformPlayerTrackPropertyEnabled:
		*(bool *)r_value = m_tracks[p_index].enabled;
		break;
	}
}

void MCLibVLCPlayer::SetTrackProperty(uindex_t p_index, MCPlatformPlayerTrackProperty p_property, MCPlatformPropertyType p_type, void *p_value)
{
	if (p_index >= m_track_count || p_property != kMCPlatformPlayerTrackPropertyEnabled)
		return;

	m_tracks[p_index].enabled = *(bool *)p_value;
	m_tracks_changed = true;

	int t_state = GetLibVLCState();
	if (t_state == kLibVLCStatePlaying || t_state == kLibVLCStatePaused)
		ApplyTracks();
}

////////////////////////////////////////////////////////////////////////////////

void MCLibVLCPlayer::GetProperty(MCPlatformPlayerProperty p_property, MCPlatformPropertyType p_type, void *r_value)
{
	switch (p_property)
	{
	case kMCPlatformPlayerPropertyDuration:
		*(MCPlatformPlayerDuration *)r_value = m_duration;
		break;

	case kMCPlatformPlayerPropertyTimescale:
		*(MCPlatformPlayerDuration *)r_value = 1000; // libVLC times are milliseconds
		break;

	case kMCPlatformPlayerPropertyCurrentTime:
		*(MCPlatformPlayerDuration *)r_value = GetPlaybackTime();
		break;

	case kMCPlatformPlayerPropertyStartTime:
		*(MCPlatformPlayerDuration *)r_value = m_start_time;
		break;

	case kMCPlatformPlayerPropertyFinishTime:
		*(MCPlatformPlayerDuration *)r_value = m_finish_time;
		break;

	case kMCPlatformPlayerPropertyLoadedTime:
		*(MCPlatformPlayerDuration *)r_value = m_duration;
		break;

	case kMCPlatformPlayerPropertyLoop:
		*(bool *)r_value = m_looping;
		break;

	case kMCPlatformPlayerPropertyPlayRate:
		*(double *)r_value = m_rate;
		break;

	case kMCPlatformPlayerPropertyMovieRect:
		*(MCRectangle *)r_value = MCRectangleMake(0, 0, m_display_width, m_display_height);
		break;

	case kMCPlatformPlayerPropertyVolume:
		*(uint16_t *)r_value = m_volume;
		break;

	case kMCPlatformPlayerPropertyInvalidFilename:
		*(bool *)r_value = !m_is_valid;
		break;

	case kMCPlatformPlayerPropertyOffscreen:
		*(bool *)r_value = true;
		break;

	case kMCPlatformPlayerPropertyMirrored:
		*(bool *)r_value = m_mirrored.load();
		break;

	case kMCPlatformPlayerPropertyOnlyPlaySelection:
		*(bool *)r_value = m_play_selection;
		break;

	case kMCPlatformPlayerPropertyMediaTypes:
		*(MCPlatformPlayerMediaTypes *)r_value = m_media_types;
		break;

	// Kept for scripts; libVLC 3 has no balance or pan control.
	case kMCPlatformPlayerPropertyLeftBalance:
		*(double *)r_value = m_left_balance;
		break;

	case kMCPlatformPlayerPropertyRightBalance:
		*(double *)r_value = m_right_balance;
		break;

	case kMCPlatformPlayerPropertyPan:
		*(double *)r_value = m_pan;
		break;

	default:
		break;
	}
}

void MCLibVLCPlayer::SetProperty(MCPlatformPlayerProperty p_property, MCPlatformPropertyType p_type, void *p_value)
{
	switch (p_property)
	{
	case kMCPlatformPlayerPropertyURL:
	case kMCPlatformPlayerPropertyFilename:
	{
		MCStringRef t_location = *(MCStringRef *)p_value;
		Close();
		if (!MCStringIsEmpty(t_location))
		{
			if (Open(t_location, p_property == kMCPlatformPlayerPropertyURL))
				m_is_valid = true;
			else
				Close();
		}
		break;
	}

	case kMCPlatformPlayerPropertyCurrentTime:
		if (m_is_valid)
			SetCurrentTime(*(MCPlatformPlayerDuration *)p_value);
		break;

	case kMCPlatformPlayerPropertyStartTime:
		m_start_time = *(MCPlatformPlayerDuration *)p_value;
		break;

	case kMCPlatformPlayerPropertyFinishTime:
		m_finish_time = *(MCPlatformPlayerDuration *)p_value;
		break;

	case kMCPlatformPlayerPropertyOnlyPlaySelection:
		m_play_selection = *(bool *)p_value;
		break;

	case kMCPlatformPlayerPropertyLoop:
		m_looping = *(bool *)p_value;
		break;

	case kMCPlatformPlayerPropertyPlayRate:
	{
		double t_rate = *(double *)p_value;
		if (t_rate > 0)
		{
			m_rate = t_rate;
			if (m_player != nil)
				s_libvlc.libvlc_media_player_set_rate(m_player, (float)t_rate);
		}
		break;
	}

	case kMCPlatformPlayerPropertyVolume:
		m_volume = MCMin(*(uint16_t *)p_value, (uint16_t)100);
		if (m_player != nil)
			ApplyVolume();
		break;

	case kMCPlatformPlayerPropertyMirrored:
	{
		bool t_mirrored = *(bool *)p_value;
		if (m_mirrored.exchange(t_mirrored) != t_mirrored)
		{
			// Flip the picture on show now; later pictures are flipped as
			// they are copied.
			{
				std::lock_guard<std::mutex> t_lock(m_frame_lock);
				if (m_has_frame && m_front_buffer != nil)
					for (uint32_t y = 0; y < m_frame_height; y++)
					{
						uint32_t *t_row = (uint32_t *)(m_front_buffer + y * m_frame_stride);
						for (uint32_t x = 0; x < m_frame_width / 2; x++)
						{
							uint32_t t_pixel = t_row[x];
							t_row[x] = t_row[m_frame_width - 1 - x];
							t_row[m_frame_width - 1 - x] = t_pixel;
						}
					}
			}
			MCPlatformCallbackSendPlayerFrameChanged(this);
		}
		break;
	}

	case kMCPlatformPlayerPropertyMarkers:
	{
		MCPlatformPlayerDurationArray *t_markers = (MCPlatformPlayerDurationArray *)p_value;
		MCPlatformPlayerDurationArray t_copy = { nil, 0 };
		if (MCPlatformArrayCopy(*t_markers, t_copy))
		{
			MCPlatformArrayClear(m_markers);
			m_markers = t_copy;
			m_last_marker = -1;
		}
		break;
	}

	case kMCPlatformPlayerPropertyLeftBalance:
		m_left_balance = *(double *)p_value;
		break;

	case kMCPlatformPlayerPropertyRightBalance:
		m_right_balance = *(double *)p_value;
		break;

	case kMCPlatformPlayerPropertyPan:
		m_pan = *(double *)p_value;
		break;

	// Video is always drawn by the engine, which also draws the selection.
	default:
		break;
	}
}

////////////////////////////////////////////////////////////////////////////////

MCPlatformPlayer *MCLibVLCPlayerCreate(void)
{
	if (!MCLibVLCInitialize())
		return nil;

	MCLibVLCPlayer *t_player = new (nothrow) MCLibVLCPlayer();
	if (t_player == nil)
		return nil;

	if (!t_player->Initialize())
	{
		delete t_player;
		return nil;
	}

	return t_player;
}

#endif
