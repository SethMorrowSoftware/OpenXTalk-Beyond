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

// The Linux player's GStreamer half (engine/src/lnxgstplayer.cpp) on its
// own, without the engine or a screen: tools/ci/gst_player_check.py builds
// this with it and runs it on the files of tools/ci/media. The engine's own
// player, through the same code, is checked by media_check.py.
//
//   gst-player-check [--x11] FILE...
//
// With --x11 the video is drawn into an X window of its own (DISPLAY,
// through plain X: Xvfb has no XVideo), as the engine's player draws it;
// without, it is decoded and dropped.
//
// For each file: it opens paused at its start with the duration of the
// file (3 seconds); its time moves on while it plays and stands still
// while paused; currentTime seeks; it ends once (and the event loop hears
// of it); looping, it does not end; a rate of 2 plays twice as fast;
// stepping a frame and skipping back work; the loudness is kept. Then a
// file that is not there does not open. Exit status 0 when every check
// passed.

#include "lnxgstplayer.h"

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static int s_failures = 0;
static int s_passes = 0;

static void check(bool p_ok, const char *p_file, const char *p_what, long p_value)
{
	if (p_ok)
		s_passes++;
	else
		s_failures++;
	printf("%s %s: %s (%ld)\n", p_ok ? "PASS" : "FAIL", p_file, p_what, p_value);
	fflush(stdout);
}

// GLib's default main context, which the engine iterates in its event loop
// and through which GStreamer's bus reports the end of a movie
typedef int (*g_main_context_iteration_t)(void *, int);
static g_main_context_iteration_t s_iterate = nullptr;

static double now(void)
{
	struct timespec t_time;
	clock_gettime(CLOCK_MONOTONIC, &t_time);
	return t_time.tv_sec + t_time.tv_nsec / 1e9;
}

// Runs GLib's main loop for p_seconds, as the engine's event loop would;
// true when a player ended meanwhile (TakeAnyEnded)
static bool run(double p_seconds)
{
	bool t_ended = false;
	double t_until = now() + p_seconds;
	while (now() < t_until)
	{
		while (s_iterate(nullptr, 0))
			;
		if (MCGstPlayer::TakeAnyEnded())
			t_ended = true;
		struct timespec t_nap = {0, 10 * 1000 * 1000};
		nanosleep(&t_nap, nullptr);
	}
	return t_ended;
}

static bool near(long p_value, long p_expected, long p_slack)
{
	return p_value >= p_expected - p_slack && p_value <= p_expected + p_slack;
}

static unsigned long s_xid = 0;

static void check_file(const char *p_file)
{
	MCGstPlayer *t_player = MCGstPlayer::Create(p_file, s_xid, false);
	check(t_player != nullptr, p_file, "opens", 0);
	if (t_player == nullptr)
		return;

	long t_duration = t_player->GetDuration();
	check(near(t_duration, 3000, 150), p_file, "duration is 3 seconds", t_duration);
	check(!t_player->IsPlaying(), p_file, "opens paused", 0);

	run(0.4);
	long t_time = t_player->GetCurrentTime();
	check(t_time < 50, p_file, "paused at its start", t_time);

	t_player->Play();
	check(t_player->IsPlaying(), p_file, "plays", 0);
	run(1.0);
	t_time = t_player->GetCurrentTime();
	check(near(t_time, 1000, 400), p_file, "time moves on while it plays", t_time);

	t_player->Pause();
	run(0.2);
	long t_paused = t_player->GetCurrentTime();
	run(0.5);
	t_time = t_player->GetCurrentTime();
	check(t_paused > 0 && near(t_time, t_paused, 40), p_file, "time stands still while paused", t_time - t_paused);

	t_player->SetCurrentTime(2000);
	run(0.3);
	t_time = t_player->GetCurrentTime();
	check(near(t_time, 2000, 100), p_file, "currentTime seeks", t_time);

	t_player->StepFrame();
	run(0.3);
	long t_stepped = t_player->GetCurrentTime();
	check(t_stepped > t_time && t_stepped - t_time < 300, p_file, "steps one frame", t_stepped - t_time);

	t_player->Skip(-5);
	run(0.3);
	t_time = t_player->GetCurrentTime();
	check(t_time < 50, p_file, "skipping back stops at the start", t_time);

	// The end: once, and the event loop hears of it
	t_player->SetCurrentTime(2500);
	t_player->Play();
	bool t_any = run(1.5);
	check(t_any, p_file, "the event loop hears of the end", 0);
	check(t_player->TakeEnded(), p_file, "ends at its end", 0);
	check(!t_player->TakeEnded(), p_file, "ends once", 0);

	// Looping: it does not end, and goes on from its start
	t_player->SetLooping(true);
	t_player->SetCurrentTime(2500);
	t_player->Play();
	t_any = run(1.5);
	t_time = t_player->GetCurrentTime();
	check(!t_any && !t_player->TakeEnded(), p_file, "looping, it does not end", 0);
	check(t_time > 0 && t_time < 1600, p_file, "looping, it goes on from its start", t_time);
	t_player->SetLooping(false);

	// A rate of 2 plays twice as fast
	t_player->Pause();
	t_player->SetCurrentTime(0);
	t_player->SetRate(2.0);
	t_player->Play();
	run(0.6);
	t_time = t_player->GetCurrentTime();
	check(near(t_time, 1200, 400), p_file, "a rate of 2 plays twice as fast", t_time);
	t_player->SetRate(0);
	check(t_player->IsPlaying(), p_file, "a rate of 0 is ignored", 0);
	t_player->SetRate(1.0);

	t_player->SetLoudness(40);
	check(t_player->GetLoudness() == 40, p_file, "the loudness is kept", t_player->GetLoudness());
	t_player->SetLoudness(250);
	check(t_player->GetLoudness() == 100, p_file, "the loudness is at most 100", t_player->GetLoudness());

	t_player->Redraw();
	t_player->Pause();
	delete t_player;
	check(true, p_file, "closes", 0);
}

int main(int argc, char *argv[])
{
	void *t_glib = dlopen("libglib-2.0.so.0", RTLD_NOW | RTLD_GLOBAL);
	if (t_glib != nullptr)
		s_iterate = (g_main_context_iteration_t)dlsym(t_glib, "g_main_context_iteration");
	if (s_iterate == nullptr)
	{
		printf("FAIL GLib does not load\n");
		return 1;
	}

	if (!MCGstPlayer::IsAvailable())
	{
		printf("FAIL GStreamer does not load (libgstreamer-1.0.so.0, libgstvideo-1.0.so.0)\n");
		return 1;
	}

	int t_first = 1;
	if (argc > 1 && strcmp(argv[1], "--x11") == 0)
	{
		t_first = 2;
		// libX11, looked up as the player looks up GStreamer, so that no
		// development package is needed
		typedef void *(*XOpenDisplay_t)(const char *);
		typedef unsigned long (*XDefaultRootWindow_t)(void *);
		typedef unsigned long (*XCreateSimpleWindow_t)(void *, unsigned long, int, int, unsigned int, unsigned int, unsigned int, unsigned long, unsigned long);
		typedef int (*XMapWindow_t)(void *, unsigned long);
		typedef int (*XSync_t)(void *, int);
		void *t_x11 = dlopen("libX11.so.6", RTLD_NOW | RTLD_GLOBAL);
		void *t_display = nullptr;
		if (t_x11 != nullptr)
			t_display = ((XOpenDisplay_t)dlsym(t_x11, "XOpenDisplay"))(nullptr);
		if (t_display == nullptr)
		{
			printf("FAIL no X display to draw the video in (DISPLAY)\n");
			return 1;
		}
		unsigned long t_root = ((XDefaultRootWindow_t)dlsym(t_x11, "XDefaultRootWindow"))(t_display);
		s_xid = ((XCreateSimpleWindow_t)dlsym(t_x11, "XCreateSimpleWindow"))(t_display, t_root, 0, 0, 320, 240, 0, 0, 0);
		((XMapWindow_t)dlsym(t_x11, "XMapWindow"))(t_display, s_xid);
		((XSync_t)dlsym(t_x11, "XSync"))(t_display, 0);
	}

	for (int i = t_first; i < argc; i++)
		check_file(argv[i]);

	MCGstPlayer *t_missing = MCGstPlayer::Create("/nonexistent/oxt-check.mp4", 0, false);
	check(t_missing == nullptr, "/nonexistent/oxt-check.mp4", "a file that is not there does not open", 0);
	delete t_missing;

	printf("%d passed, %d failed\n", s_passes, s_failures);
	return s_failures == 0 ? 0 : 1;
}
