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

// OXT-Beyond: a movie through Media Foundation's MFPlay, for the Windows
// player when DirectShow cannot open a file (w32-mf-player.h says why).
//
// MFPlay (Windows 7 and later) is Media Foundation's simple player: it
// draws the video into a window of ours, as DirectShow's video window
// does, and it delivers its events through the message loop of the thread
// that made it, so that nothing here runs on a thread of its own.

#include "w32-mf-player.h"

#include <new>

#include <objbase.h>
#include <propidl.h>
#include <mfplay.h>

////////////////////////////////////////////////////////////////////////////////

// GUIDs from mfapi.h and mfplay.h, written out here so that the engine
// links with no Media Foundation library (they are in its uuid library)

// MFP_POSITIONTYPE_100NS (GUID_NULL): positions in 100 ns units
static const GUID kMCMFPositionType100ns =
	{ 0x00000000, 0x0000, 0x0000, { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 } };
// MF_MT_MAJOR_TYPE
static const GUID kMCMFMajorType =
	{ 0x48eba18e, 0xf8c9, 0x4687, { 0xbf, 0x11, 0x0a, 0x74, 0xc9, 0xf9, 0x6a, 0x8f } };
// MF_MT_FRAME_RATE (UINT64: numerator in the high 32 bits, denominator low)
static const GUID kMCMFFrameRate =
	{ 0xc459a2e8, 0x3d2c, 0x4e44, { 0xb1, 0x32, 0xfe, 0xe5, 0x15, 0x6c, 0x7b, 0xb0 } };
// MFMediaType_Audio ('auds')
static const GUID kMCMFMediaTypeAudio =
	{ 0x73647561, 0x0000, 0x0010, { 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 } };
// MFMediaType_Video ('vids')
static const GUID kMCMFMediaTypeVideo =
	{ 0x73646976, 0x0000, 0x0010, { 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 } };

// MFVideoARMode_None (evr.h): the video fills the window, as DirectShow's
// video window does (w32-ds-player.cpp sizes it to the whole window)
#define kMCMFAspectRatioModeNone 0

typedef HRESULT (STDAPICALLTYPE *MCMFPCreateMediaPlayerProc)(LPCWSTR, BOOL, MFP_CREATION_OPTIONS,
                                                             IMFPMediaPlayerCallback *, HWND, IMFPMediaPlayer **);

static MCMFPCreateMediaPlayerProc s_create_media_player = NULL;

bool MCWin32MFPlayback::IsAvailable(void)
{
	static bool s_tried = false;
	if (!s_tried)
	{
		s_tried = true;

		// From the system folder only: a mfplay.dll next to a stack or in the
		// current folder is never loaded
		wchar_t t_path[MAX_PATH + 16];
		UINT t_length = GetSystemDirectoryW(t_path, MAX_PATH);
		if (t_length > 0 && t_length < MAX_PATH)
		{
			lstrcpyW(t_path + t_length, L"\\mfplay.dll");
			HMODULE t_module = LoadLibraryW(t_path);
			if (t_module != NULL)
			{
				s_create_media_player = (MCMFPCreateMediaPlayerProc)(void *)GetProcAddress(t_module,
				                                                                      "MFPCreateMediaPlayer");
				// (kept loaded for the life of the process)
				if (s_create_media_player == NULL)
					FreeLibrary(t_module);
			}
		}
	}

	return s_create_media_player != NULL;
}

////////////////////////////////////////////////////////////////////////////////

// MFPlay's events, passed on to the playback. The playback clears
// m_playback before it shuts the player down, so that an event MFPlay still
// has queued finds no playback rather than a deleted one.
class MCWin32MFPlaybackCallback : public IMFPMediaPlayerCallback
{
public:
	MCWin32MFPlaybackCallback(MCWin32MFPlayback *p_playback)
		: m_references(1), m_playback(p_playback)
	{
	}

	virtual ~MCWin32MFPlaybackCallback(void)
	{
	}

	void Detach(void)
	{
		m_playback = NULL;
	}

	STDMETHODIMP QueryInterface(REFIID p_iid, void **r_object)
	{
		if (r_object == NULL)
			return E_POINTER;

		if (IsEqualIID(p_iid, __uuidof(IUnknown)) || IsEqualIID(p_iid, __uuidof(IMFPMediaPlayerCallback)))
		{
			*r_object = static_cast<IMFPMediaPlayerCallback *>(this);
			AddRef();
			return S_OK;
		}

		*r_object = NULL;
		return E_NOINTERFACE;
	}

	STDMETHODIMP_(ULONG) AddRef(void)
	{
		return (ULONG)InterlockedIncrement(&m_references);
	}

	STDMETHODIMP_(ULONG) Release(void)
	{
		LONG t_count = InterlockedDecrement(&m_references);
		if (t_count == 0)
			delete this;
		return (ULONG)t_count;
	}

	void STDMETHODCALLTYPE OnMediaPlayerEvent(MFP_EVENT_HEADER *p_event)
	{
		if (p_event == NULL || m_playback == NULL)
			return;

		switch (p_event->eEventType)
		{
		case MFP_EVENT_TYPE_MEDIAITEM_SET:
			m_playback->HandleMediaItemSet(p_event->hrEvent);
			break;

		case MFP_EVENT_TYPE_PLAYBACK_ENDED:
			m_playback->HandleEnded();
			break;

		case MFP_EVENT_TYPE_ERROR:
			// A movie that stops with an error ends, as DirectShow's
			// EC_ERRORABORT does (w32-ds-player.cpp HandleGraphEvent)
			m_playback->HandleEnded();
			break;

		default:
			break;
		}
	}

private:
	LONG m_references;
	MCWin32MFPlayback *m_playback;
};

////////////////////////////////////////////////////////////////////////////////

MCWin32MFPlayback::MCWin32MFPlayback(void)
	: m_player(NULL), m_callback(NULL), m_owner(NULL),
	  m_has_video(false), m_has_audio(false), m_frame_length(0),
	  m_item_set_done(false), m_item_set_result(S_OK)
{
}

MCWin32MFPlayback::~MCWin32MFPlayback(void)
{
	if (m_callback != NULL)
		m_callback->Detach();

	if (m_player != NULL)
	{
		m_player->Shutdown();
		m_player->Release();
		m_player = NULL;
	}

	if (m_callback != NULL)
	{
		m_callback->Release();
		m_callback = NULL;
	}
}

void MCWin32MFPlayback::HandleMediaItemSet(HRESULT p_result)
{
	m_item_set_done = true;
	m_item_set_result = p_result;
}

void MCWin32MFPlayback::HandleEnded(void)
{
	if (m_owner != NULL)
		m_owner->MFPlaybackEnded();
}

// Whether stream p_index of the item is of the major type p_type
static bool MCWin32MFStreamIsOfType(IMFPMediaItem *p_item, DWORD p_index, const GUID &p_type)
{
	PROPVARIANT t_value;
	PropVariantInit(&t_value);
	bool t_is = false;
	if (SUCCEEDED(p_item->GetStreamAttribute(p_index, kMCMFMajorType, &t_value)) && t_value.vt == VT_CLSID &&
	    t_value.puuid != NULL)
		t_is = IsEqualGUID(*t_value.puuid, p_type) != FALSE;
	PropVariantClear(&t_value);
	return t_is;
}

// The length of a frame of the item's first video stream, from its frame
// rate (100 ns units); 0 when it does not say
static int64_t MCWin32MFItemFrameLength(IMFPMediaItem *p_item)
{
	DWORD t_count = 0;
	if (FAILED(p_item->GetNumberOfStreams(&t_count)))
		return 0;

	for (DWORD i = 0; i < t_count; i++)
	{
		if (!MCWin32MFStreamIsOfType(p_item, i, kMCMFMediaTypeVideo))
			continue;

		PROPVARIANT t_value;
		PropVariantInit(&t_value);
		int64_t t_length = 0;
		if (SUCCEEDED(p_item->GetStreamAttribute(i, kMCMFFrameRate, &t_value)) && t_value.vt == VT_UI8)
		{
			uint32_t t_numerator = (uint32_t)(t_value.uhVal.QuadPart >> 32);
			uint32_t t_denominator = (uint32_t)(t_value.uhVal.QuadPart & 0xffffffff);
			if (t_numerator != 0)
				t_length = (int64_t)((10000000.0 * t_denominator) / t_numerator + 0.5);
		}
		PropVariantClear(&t_value);
		return t_length;
	}

	return 0;
}

// Makes the media item for p_path (synchronously) and sets it on the
// player, then waits for MFPlay to say whether that worked. With
// p_without_audio, the item's sound streams are left out first.
bool MCWin32MFPlayback::SetItem(const wchar_t *p_path, bool p_without_audio, WaitFunction p_wait,
                                DWORD p_timeout_ms, HRESULT &r_result)
{
	IMFPMediaItem *t_item = NULL;
	HRESULT t_result = m_player->CreateMediaItemFromURL(p_path, TRUE, 0, &t_item);

	if (SUCCEEDED(t_result) && p_without_audio)
	{
		DWORD t_count = 0;
		if (SUCCEEDED(t_item->GetNumberOfStreams(&t_count)))
			for (DWORD i = 0; i < t_count; i++)
				if (MCWin32MFStreamIsOfType(t_item, i, kMCMFMediaTypeAudio))
					t_item->SetStreamSelection(i, FALSE);
	}

	BOOL t_has_video = FALSE, t_has_audio = FALSE, t_selected = FALSE;
	if (SUCCEEDED(t_result))
	{
		if (FAILED(t_item->HasVideo(&t_has_video, &t_selected)) || !t_selected)
			t_has_video = FALSE;
		if (FAILED(t_item->HasAudio(&t_has_audio, &t_selected)) || !t_selected)
			t_has_audio = FALSE;
		if (!t_has_video && !t_has_audio)
			t_result = E_FAIL;
	}

	if (SUCCEEDED(t_result))
	{
		m_item_set_done = false;
		m_item_set_result = S_OK;
		t_result = m_player->SetMediaItem(t_item);
	}

	if (SUCCEEDED(t_result))
	{
		// MFPlay sets the item up asynchronously and says so through this
		// thread's messages, which the wait pumps
		ULONGLONG t_deadline = GetTickCount64() + p_timeout_ms;
		while (!m_item_set_done && GetTickCount64() < t_deadline)
			p_wait();

		if (!m_item_set_done)
			t_result = HRESULT_FROM_WIN32(ERROR_TIMEOUT);
		else
			t_result = m_item_set_result;
	}

	if (SUCCEEDED(t_result))
	{
		m_has_video = t_has_video != FALSE;
		m_has_audio = t_has_audio != FALSE;
		m_frame_length = m_has_video ? MCWin32MFItemFrameLength(t_item) : 0;
	}

	if (t_item != NULL)
		t_item->Release();

	r_result = t_result;
	return SUCCEEDED(t_result);
}

MCWin32MFPlayback *MCWin32MFPlayback::Open(const wchar_t *p_path, HWND p_video_window, MCWin32MFPlaybackOwner *p_owner,
                                           WaitFunction p_wait, DWORD p_timeout_ms)
{
	if (p_path == NULL || *p_path == 0 || p_wait == NULL || !IsAvailable())
		return NULL;

	MCWin32MFPlayback *t_playback = new (std::nothrow) MCWin32MFPlayback();
	if (t_playback == NULL)
		return NULL;

	t_playback->m_callback = new (std::nothrow) MCWin32MFPlaybackCallback(t_playback);
	bool t_success = t_playback->m_callback != NULL;

	if (t_success)
		t_success = SUCCEEDED(s_create_media_player(NULL, FALSE, MFP_OPTION_NONE, t_playback->m_callback,
		                                            p_video_window, &t_playback->m_player));

	HRESULT t_result = S_OK;
	if (t_success)
		t_success = t_playback->SetItem(p_path, false, p_wait, p_timeout_ms, t_result);

	// A machine with no sound device (a server, a CI runner) cannot render a
	// movie's sound, and Media Foundation then refuses the whole movie: play
	// its picture alone, as there is nothing to hear anyway. A movie that is
	// only sound still fails here.
	if (!t_success && t_playback->m_player != NULL && t_result != HRESULT_FROM_WIN32(ERROR_TIMEOUT))
	{
		HRESULT t_retry = S_OK;
		t_success = t_playback->SetItem(p_path, true, p_wait, p_timeout_ms, t_retry);
	}

	if (t_success && t_playback->m_has_video)
		t_playback->m_player->SetAspectRatioMode(kMCMFAspectRatioModeNone);

	if (!t_success)
	{
		delete t_playback;
		return NULL;
	}

	// Only now: an event during the open never reaches the owner
	t_playback->m_owner = p_owner;
	return t_playback;
}

////////////////////////////////////////////////////////////////////////////////

bool MCWin32MFPlayback::GetDuration(int64_t &r_duration)
{
	PROPVARIANT t_value;
	PropVariantInit(&t_value);
	bool t_success = SUCCEEDED(m_player->GetDuration(kMCMFPositionType100ns, &t_value));
	if (t_success)
	{
		if (t_value.vt == VT_UI8 && t_value.uhVal.QuadPart <= (ULONGLONG)INT64_MAX)
			r_duration = (int64_t)t_value.uhVal.QuadPart;
		else if (t_value.vt == VT_I8 && t_value.hVal.QuadPart >= 0)
			r_duration = t_value.hVal.QuadPart;
		else
			t_success = false;
	}
	PropVariantClear(&t_value);
	return t_success;
}

bool MCWin32MFPlayback::GetPosition(int64_t &r_position)
{
	PROPVARIANT t_value;
	PropVariantInit(&t_value);
	bool t_success = SUCCEEDED(m_player->GetPosition(kMCMFPositionType100ns, &t_value));
	if (t_success)
	{
		if (t_value.vt == VT_I8)
			r_position = t_value.hVal.QuadPart < 0 ? 0 : t_value.hVal.QuadPart;
		else if (t_value.vt == VT_UI8 && t_value.uhVal.QuadPart <= (ULONGLONG)INT64_MAX)
			r_position = (int64_t)t_value.uhVal.QuadPart;
		else
			t_success = false;
	}
	PropVariantClear(&t_value);
	return t_success;
}

bool MCWin32MFPlayback::SetPosition(int64_t p_position)
{
	PROPVARIANT t_value;
	PropVariantInit(&t_value);
	t_value.vt = VT_I8;
	t_value.hVal.QuadPart = p_position < 0 ? 0 : p_position;
	return SUCCEEDED(m_player->SetPosition(kMCMFPositionType100ns, &t_value));
}

bool MCWin32MFPlayback::GetRate(double &r_rate)
{
	float t_rate = 1.0f;
	if (FAILED(m_player->GetRate(&t_rate)))
		return false;
	r_rate = t_rate;
	return true;
}

bool MCWin32MFPlayback::SetRate(double p_rate)
{
	// Starting a player sets its rate first (w32-ds-player.cpp Start): a
	// rate it already has is not set again, so a state in which MFPlay
	// refuses a new rate never stops a movie from starting
	float t_current = 1.0f;
	if (SUCCEEDED(m_player->GetRate(&t_current)) && t_current == (float)p_rate)
		return true;
	return SUCCEEDED(m_player->SetRate((float)p_rate));
}

bool MCWin32MFPlayback::GetVolume(double &r_volume)
{
	float t_volume = 1.0f;
	if (FAILED(m_player->GetVolume(&t_volume)))
		return false;
	r_volume = t_volume;
	return true;
}

bool MCWin32MFPlayback::SetVolume(double p_volume)
{
	if (p_volume < 0.0)
		p_volume = 0.0;
	if (p_volume > 1.0)
		p_volume = 1.0;
	return SUCCEEDED(m_player->SetVolume((float)p_volume));
}

bool MCWin32MFPlayback::GetVideoSize(uint32_t &r_width, uint32_t &r_height)
{
	if (!m_has_video)
	{
		r_width = r_height = 0;
		return true;
	}

	SIZE t_size = { 0, 0 };
	SIZE t_aspect = { 0, 0 };
	if (FAILED(m_player->GetNativeVideoSize(&t_size, &t_aspect)))
		return false;

	r_width = t_size.cx < 0 ? 0 : (uint32_t)t_size.cx;
	r_height = t_size.cy < 0 ? 0 : (uint32_t)t_size.cy;
	return true;
}

bool MCWin32MFPlayback::Play(void)
{
	return SUCCEEDED(m_player->Play());
}

bool MCWin32MFPlayback::Pause(void)
{
	return SUCCEEDED(m_player->Pause());
}

void MCWin32MFPlayback::UpdateVideo(void)
{
	if (m_has_video)
		m_player->UpdateVideo();
}
