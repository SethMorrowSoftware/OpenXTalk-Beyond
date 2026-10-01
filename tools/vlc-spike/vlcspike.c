/* vlcspike.c - feasibility probe for a libVLC-backed player backend.
 *
 * Loads libVLC 3.x at run time (no SDK, no import library), renders video into
 * memory through libvlc_video_set_callbacks, and exercises the operations the
 * engine's MCPlatformPlayer interface needs: open, parse, play, seek, rate,
 * pause, frame step, volume, end of stream and restart. It reports which
 * threads the callbacks arrive on, the CPU cost of memory rendering, and the
 * pixel format VLC delivers, and saves frames as BMP files.
 *
 * See docs/development/vlc-player-plan.md.
 *
 * Windows (x64):  build-win.cmd
 * Linux:          cc -O2 -Wall -o vlcspike vlcspike.c -ldl -lpthread
 *
 * Usage: vlcspike <media file> [--chroma RV32|RGBA] [--out DIR] [--libvlc PATH]
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#else
#  include <dlfcn.h>
#  include <pthread.h>
#  include <time.h>
#  include <unistd.h>
#  include <sys/resource.h>
#  include <sys/syscall.h>
#endif

/* ---- libVLC 3.x declarations (include/vlc/libvlc*.h, branch 3.0.x) ---- */

typedef struct libvlc_instance_t libvlc_instance_t;
typedef struct libvlc_media_t libvlc_media_t;
typedef struct libvlc_media_player_t libvlc_media_player_t;
typedef struct libvlc_event_manager_t libvlc_event_manager_t;
typedef int64_t libvlc_time_t;

typedef struct libvlc_event_t
{
    int type;
    void *p_obj;
    union
    {
        struct { float new_cache; } media_player_buffering;
        struct { libvlc_time_t new_time; } media_player_time_changed;
        struct { libvlc_time_t new_length; } media_player_length_changed;
    } u;
} libvlc_event_t;

enum
{
    kEventOpening = 0x102,
    kEventBuffering = 0x103,
    kEventPlaying = 0x104,
    kEventPaused = 0x105,
    kEventStopped = 0x106,
    kEventEndReached = 0x109,
    kEventError = 0x10A,
    kEventTimeChanged = 0x10B,
    kEventLengthChanged = 0x111,
    kEventVout = 0x112,
};

/* Only the leading fields of libvlc_video_track_t are declared; it is only
 * ever accessed through a pointer. */
typedef struct { unsigned i_channels, i_rate; } vlc_audio_track;
typedef struct
{
    unsigned i_height, i_width;
    unsigned i_sar_num, i_sar_den;
    unsigned i_frame_rate_num, i_frame_rate_den;
} vlc_video_track;

typedef struct
{
    uint32_t i_codec;
    uint32_t i_original_fourcc;
    int i_id;
    int i_type; /* -1 unknown, 0 audio, 1 video, 2 text */
    int i_profile;
    int i_level;
    union { vlc_audio_track *audio; vlc_video_track *video; void *subtitle; } u;
    unsigned i_bitrate;
    char *psz_language;
    char *psz_description;
} vlc_media_track;

typedef void (*vlc_event_cb)(const libvlc_event_t *, void *);
typedef void *(*vlc_lock_cb)(void *, void **);
typedef void (*vlc_unlock_cb)(void *, void *, void *const *);
typedef void (*vlc_display_cb)(void *, void *);
typedef unsigned (*vlc_format_cb)(void **, char *, unsigned *, unsigned *, unsigned *, unsigned *);
typedef void (*vlc_cleanup_cb)(void *);

#define VLC_FUNCTIONS(X) \
    X(const char *, libvlc_get_version, (void)) \
    X(const char *, libvlc_errmsg, (void)) \
    X(libvlc_instance_t *, libvlc_new, (int, const char *const *)) \
    X(void, libvlc_release, (libvlc_instance_t *)) \
    X(libvlc_media_t *, libvlc_media_new_path, (libvlc_instance_t *, const char *)) \
    X(void, libvlc_media_release, (libvlc_media_t *)) \
    X(void, libvlc_media_add_option, (libvlc_media_t *, const char *)) \
    X(int, libvlc_media_parse_with_options, (libvlc_media_t *, int, int)) \
    X(int, libvlc_media_get_parsed_status, (libvlc_media_t *)) \
    X(libvlc_time_t, libvlc_media_get_duration, (libvlc_media_t *)) \
    X(unsigned, libvlc_media_tracks_get, (libvlc_media_t *, vlc_media_track ***)) \
    X(void, libvlc_media_tracks_release, (vlc_media_track **, unsigned)) \
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
    X(int, libvlc_audio_get_volume, (libvlc_media_player_t *)) \
    X(void, libvlc_audio_set_mute, (libvlc_media_player_t *, int)) \
    X(int, libvlc_video_get_size, (libvlc_media_player_t *, unsigned, unsigned *, unsigned *)) \
    X(libvlc_event_manager_t *, libvlc_media_player_event_manager, (libvlc_media_player_t *)) \
    X(int, libvlc_event_attach, (libvlc_event_manager_t *, int, vlc_event_cb, void *)) \
    X(void, libvlc_video_set_callbacks, (libvlc_media_player_t *, vlc_lock_cb, vlc_unlock_cb, vlc_display_cb, void *)) \
    X(void, libvlc_video_set_format_callbacks, (libvlc_media_player_t *, vlc_format_cb, vlc_cleanup_cb))

#define DECLARE_FUNCTION(ret, name, args) ret (*name) args;
static struct { VLC_FUNCTIONS(DECLARE_FUNCTION) } vlc;

static const char *kStateNames[] =
    { "NothingSpecial", "Opening", "Buffering", "Playing", "Paused", "Stopped", "Ended", "Error" };

/* ---- Platform helpers ---- */

#ifdef _WIN32
typedef CRITICAL_SECTION mutex_t;
static void mutex_init(mutex_t *m) { InitializeCriticalSection(m); }
static void mutex_lock(mutex_t *m) { EnterCriticalSection(m); }
static void mutex_unlock(mutex_t *m) { LeaveCriticalSection(m); }
static unsigned long thread_id(void) { return GetCurrentThreadId(); }
static void sleep_ms(int ms) { Sleep(ms); }

static double now_s(void)
{
    LARGE_INTEGER t_freq, t_count;
    QueryPerformanceFrequency(&t_freq);
    QueryPerformanceCounter(&t_count);
    return (double)t_count.QuadPart / (double)t_freq.QuadPart;
}

static double cpu_s(void)
{
    FILETIME t_create, t_exit, t_kernel, t_user;
    GetProcessTimes(GetCurrentProcess(), &t_create, &t_exit, &t_kernel, &t_user);
    ULARGE_INTEGER k, u;
    k.LowPart = t_kernel.dwLowDateTime; k.HighPart = t_kernel.dwHighDateTime;
    u.LowPart = t_user.dwLowDateTime; u.HighPart = t_user.dwHighDateTime;
    return (double)(k.QuadPart + u.QuadPart) / 1e7;
}
#else
typedef pthread_mutex_t mutex_t;
static void mutex_init(mutex_t *m) { pthread_mutex_init(m, NULL); }
static void mutex_lock(mutex_t *m) { pthread_mutex_lock(m); }
static void mutex_unlock(mutex_t *m) { pthread_mutex_unlock(m); }
static unsigned long thread_id(void) { return (unsigned long)syscall(SYS_gettid); }
static void sleep_ms(int ms) { usleep((useconds_t)ms * 1000); }

static double now_s(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static double cpu_s(void)
{
    struct rusage r;
    getrusage(RUSAGE_SELF, &r);
    return r.ru_utime.tv_sec + r.ru_utime.tv_usec / 1e6 + r.ru_stime.tv_sec + r.ru_stime.tv_usec / 1e6;
}
#endif

static double s_start;
static unsigned long s_main_thread;
static mutex_t s_log_lock;

static void say(const char *p_format, ...)
{
    va_list t_args;
    mutex_lock(&s_log_lock);
    printf("[%7.3f] ", now_s() - s_start);
    va_start(t_args, p_format);
    vprintf(p_format, t_args);
    va_end(t_args);
    printf("\n");
    fflush(stdout);
    mutex_unlock(&s_log_lock);
}

static const char *which_thread(void)
{
    return thread_id() == s_main_thread ? "main thread" : "libVLC thread";
}

/* ---- Loading libVLC ---- */

static void *load_libvlc(const char *p_path)
{
#ifdef _WIN32
    char t_path[MAX_PATH];
    if (p_path != NULL)
        snprintf(t_path, sizeof t_path, "%s", p_path);
    else
    {
        /* The VLC installer records its folder here; the engine would try a
         * bundled copy first. */
        char t_dir[MAX_PATH];
        DWORD t_size = sizeof t_dir;
        if (RegGetValueA(HKEY_LOCAL_MACHINE, "Software\\VideoLAN\\VLC", "InstallDir",
                         RRF_RT_REG_SZ, NULL, t_dir, &t_size) == ERROR_SUCCESS)
        {
            say("registry InstallDir: %s", t_dir);
            snprintf(t_path, sizeof t_path, "%s\\libvlc.dll", t_dir);
        }
        else
            snprintf(t_path, sizeof t_path, "C:\\Program Files\\VideoLAN\\VLC\\libvlc.dll");
    }
    /* LOAD_WITH_ALTERED_SEARCH_PATH lets libvlc.dll find libvlccore.dll in
     * its own folder. */
    HMODULE t_module = LoadLibraryExA(t_path, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (t_module == NULL)
        say("LoadLibrary(%s) failed: error %lu", t_path, GetLastError());
    else
        say("loaded %s", t_path);
    return t_module;
#else
    const char *t_path = p_path != NULL ? p_path : "libvlc.so.5";
    void *t_handle = dlopen(t_path, RTLD_NOW | RTLD_LOCAL);
    if (t_handle == NULL)
        say("dlopen(%s) failed: %s", t_path, dlerror());
    else
        say("loaded %s", t_path);
    return t_handle;
#endif
}

static void *find_symbol(void *p_library, const char *p_name)
{
#ifdef _WIN32
    return (void *)GetProcAddress((HMODULE)p_library, p_name);
#else
    return dlsym(p_library, p_name);
#endif
}

static int resolve_functions(void *p_library)
{
    int t_ok = 1;
#define RESOLVE_FUNCTION(ret, name, args) \
    if ((*(void **)&vlc.name = find_symbol(p_library, #name)) == NULL) \
    { \
        say("missing symbol %s", #name); \
        t_ok = 0; \
    }
    VLC_FUNCTIONS(RESOLVE_FUNCTION)
#undef RESOLVE_FUNCTION
    return t_ok;
}

/* ---- Video callbacks: the frame buffer an engine backend would keep ---- */

static struct
{
    mutex_t lock;
    char chroma[4];
    unsigned width, height, pitch, lines;
    uint8_t *decode; /* libVLC writes the next picture here */
    uint8_t *front;  /* last displayed picture; what LockBitmap would hand out */
    unsigned frames;
    unsigned format_calls;
    unsigned alpha_min, alpha_max;
    unsigned time_changed;
    unsigned display_width, display_height; /* from the parsed video track */
    int swizzle; /* convert RV32 (BGRA) to RGBA while copying */
    double play_requested_at, first_frame_at;
    double last_frame_at, max_gap;
    volatile int playing, paused, end_reached, error;
} s_video;

static unsigned on_format(void **p_opaque, char *p_chroma, unsigned *p_width, unsigned *p_height,
                          unsigned *p_pitches, unsigned *p_lines)
{
    char t_offered[5] = { 0 };
    memcpy(t_offered, p_chroma, 4);

    unsigned t_offered_width = *p_width, t_offered_height = *p_height;
    mutex_lock(&s_video.lock);
    memcpy(p_chroma, s_video.chroma, 4);
    /* The offered size is the decoder's aligned buffer size, not the visible
     * size; asking for the display size makes libVLC scale correctly. */
    if (s_video.display_width != 0 && s_video.display_height != 0)
    {
        *p_width = s_video.display_width;
        *p_height = s_video.display_height;
    }
    s_video.width = *p_width;
    s_video.height = *p_height;
    /* libVLC recommends pitches and line counts that are multiples of 32. */
    s_video.pitch = (*p_width * 4 + 31) & ~31u;
    s_video.lines = (*p_height + 31) & ~31u;
    p_pitches[0] = s_video.pitch;
    p_lines[0] = s_video.lines;
    free(s_video.decode);
    free(s_video.front);
    s_video.decode = (uint8_t *)calloc(s_video.pitch, s_video.lines);
    s_video.front = (uint8_t *)calloc(s_video.pitch, s_video.lines);
    s_video.format_calls++;
    mutex_unlock(&s_video.lock);

    say("format: decoder offered %s %ux%u, using %.4s %ux%u, pitch %u, lines %u (%s)",
        t_offered, t_offered_width, t_offered_height, s_video.chroma, *p_width, *p_height,
        s_video.pitch, s_video.lines, which_thread());
    return 1;
}

static void on_cleanup(void *p_opaque)
{
    say("format cleanup (%s)", which_thread());
}

static void *on_lock(void *p_opaque, void **p_planes)
{
    p_planes[0] = s_video.decode;
    return NULL;
}

static void on_unlock(void *p_opaque, void *p_picture, void *const *p_planes)
{
}

static void on_display(void *p_opaque, void *p_picture)
{
    mutex_lock(&s_video.lock);
    if (s_video.swizzle)
    {
        /* libVLC converts to RV32 much faster than to RGBA, so on Linux,
         * where engine pixels are RGBA, swap red and blue in this copy. */
        for (unsigned y = 0; y < s_video.height; y++)
        {
            const uint32_t *t_src = (const uint32_t *)(s_video.decode + (size_t)y * s_video.pitch);
            uint32_t *t_dst = (uint32_t *)(s_video.front + (size_t)y * s_video.pitch);
            for (unsigned x = 0; x < s_video.width; x++)
            {
                uint32_t p = t_src[x];
                t_dst[x] = (p & 0xFF00FF00u) | ((p >> 16) & 0xFFu) | ((p & 0xFFu) << 16);
            }
        }
    }
    else
        memcpy(s_video.front, s_video.decode, (size_t)s_video.pitch * s_video.height);
    unsigned t_alpha = s_video.front[3];
    if (s_video.frames == 0 || t_alpha < s_video.alpha_min)
        s_video.alpha_min = t_alpha;
    if (s_video.frames == 0 || t_alpha > s_video.alpha_max)
        s_video.alpha_max = t_alpha;
    s_video.frames++;
    double t_now = now_s();
    if (s_video.last_frame_at != 0 && t_now - s_video.last_frame_at > s_video.max_gap)
        s_video.max_gap = t_now - s_video.last_frame_at;
    s_video.last_frame_at = t_now;
    mutex_unlock(&s_video.lock);

    /* An engine backend would post one coalesced "frame changed" notice to
     * the main thread here. */
    if (s_video.first_frame_at == 0)
    {
        s_video.first_frame_at = now_s();
        say("first frame displayed %.0f ms after play (%s)",
            (s_video.first_frame_at - s_video.play_requested_at) * 1000, which_thread());
    }
}

static void on_event(const libvlc_event_t *p_event, void *p_opaque)
{
    switch (p_event->type)
    {
    case kEventTimeChanged:
        s_video.time_changed++;
        return;
    case kEventBuffering:
        return;
    case kEventOpening:
        say("event Opening (%s)", which_thread());
        break;
    case kEventPlaying:
        s_video.playing = 1;
        s_video.paused = 0;
        say("event Playing (%s)", which_thread());
        break;
    case kEventPaused:
        s_video.paused = 1;
        say("event Paused (%s)", which_thread());
        break;
    case kEventStopped:
        s_video.playing = 0;
        say("event Stopped (%s)", which_thread());
        break;
    case kEventEndReached:
        s_video.end_reached = 1;
        say("event EndReached (%s)", which_thread());
        break;
    case kEventError:
        s_video.error = 1;
        say("event EncounteredError (%s)", which_thread());
        break;
    case kEventLengthChanged:
        say("event LengthChanged %lld ms (%s)", (long long)p_event->u.media_player_length_changed.new_length, which_thread());
        break;
    case kEventVout:
        say("event Vout (%s)", which_thread());
        break;
    }
}

/* ---- Frame inspection ---- */

static void frame_stats(double *r_mean, unsigned *r_frames)
{
    double t_sum = 0;
    unsigned t_count = 0;
    mutex_lock(&s_video.lock);
    *r_frames = s_video.frames;
    if (s_video.front != NULL)
        for (unsigned y = 0; y < s_video.height; y += 7)
            for (unsigned x = 0; x < s_video.width; x += 7)
            {
                const uint8_t *p = s_video.front + (size_t)y * s_video.pitch + x * 4;
                t_sum += (p[0] + p[1] + p[2]) / 3.0;
                t_count++;
            }
    mutex_unlock(&s_video.lock);
    *r_mean = t_count != 0 ? t_sum / t_count : 0;
}

static void put_u16(FILE *f, unsigned v) { fputc(v & 0xFF, f); fputc((v >> 8) & 0xFF, f); }
static void put_u32(FILE *f, uint32_t v) { put_u16(f, v & 0xFFFF); put_u16(f, v >> 16); }

static void save_frame(const char *p_dir, const char *p_name)
{
    char t_path[1024];
    snprintf(t_path, sizeof t_path, "%s/%s", p_dir, p_name);

    mutex_lock(&s_video.lock);
    if (s_video.front == NULL || s_video.frames == 0)
    {
        mutex_unlock(&s_video.lock);
        return;
    }
    FILE *f = fopen(t_path, "wb");
    if (f == NULL)
    {
        mutex_unlock(&s_video.lock);
        say("could not write %s", t_path);
        return;
    }

    /* 32-bit top-down BMP; BMP pixels are B,G,R,X in memory. */
    uint32_t t_image_size = s_video.width * 4 * s_video.height;
    fputc('B', f); fputc('M', f);
    put_u32(f, 14 + 40 + t_image_size); put_u32(f, 0); put_u32(f, 14 + 40);
    put_u32(f, 40); put_u32(f, s_video.width); put_u32(f, (uint32_t)-(int32_t)s_video.height);
    put_u16(f, 1); put_u16(f, 32); put_u32(f, 0); put_u32(f, t_image_size);
    put_u32(f, 2835); put_u32(f, 2835); put_u32(f, 0); put_u32(f, 0);

    int t_swap = memcmp(s_video.chroma, "RGBA", 4) == 0 || s_video.swizzle;
    for (unsigned y = 0; y < s_video.height; y++)
    {
        const uint8_t *p = s_video.front + (size_t)y * s_video.pitch;
        for (unsigned x = 0; x < s_video.width; x++, p += 4)
        {
            fputc(t_swap ? p[2] : p[0], f);
            fputc(p[1], f);
            fputc(t_swap ? p[0] : p[2], f);
            fputc(0xFF, f);
        }
    }
    fclose(f);
    mutex_unlock(&s_video.lock);
    say("saved %s", t_path);
}

/* ---- Probe ---- */

static int wait_for(volatile int *p_flag, int p_timeout_ms)
{
    for (int t_waited = 0; !*p_flag && t_waited < p_timeout_ms; t_waited += 20)
        sleep_ms(20);
    return *p_flag;
}

int main(int argc, char **argv)
{
    const char *t_file = NULL, *t_out = ".", *t_libvlc = NULL;
    int t_no_hw = 0, t_repeat = 0, t_apply_sar = 0, t_prime = 0;
#ifdef _WIN32
    const char *t_chroma = "RV32"; /* engine pixels are BGRA on Windows */
#else
    const char *t_chroma = "RGBA"; /* engine pixels are RGBA on Linux */
#endif
    for (int i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "--chroma") == 0 && i + 1 < argc)
            t_chroma = argv[++i];
        else if (strcmp(argv[i], "--out") == 0 && i + 1 < argc)
            t_out = argv[++i];
        else if (strcmp(argv[i], "--libvlc") == 0 && i + 1 < argc)
            t_libvlc = argv[++i];
        else if (strcmp(argv[i], "--no-hw") == 0)
            t_no_hw = 1;
        else if (strcmp(argv[i], "--repeat") == 0)
            t_repeat = 1;
        else if (strcmp(argv[i], "--apply-sar") == 0)
            t_apply_sar = 1;
        else if (strcmp(argv[i], "--swizzle") == 0)
            s_video.swizzle = 1;
        else if (strcmp(argv[i], "--prime") == 0)
            t_prime = 1;
        else
            t_file = argv[i];
    }
    if (t_file == NULL || strlen(t_chroma) != 4)
    {
        fprintf(stderr, "usage: vlcspike <media file> [--chroma RV32|RGBA] [--out DIR] [--libvlc PATH] [--no-hw] [--repeat] [--apply-sar] [--swizzle] [--prime]\n");
        return 2;
    }

    s_start = now_s();
    s_main_thread = thread_id();
    mutex_init(&s_log_lock);
    mutex_init(&s_video.lock);
    memcpy(s_video.chroma, t_chroma, 4);

    void *t_library = load_libvlc(t_libvlc);
    if (t_library == NULL || !resolve_functions(t_library))
        return 1;
    say("libVLC version %s", vlc.libvlc_get_version());

    const char *t_args[8];
    int t_arg_count = 0;
    t_args[t_arg_count++] = "--quiet";
    t_args[t_arg_count++] = "--no-video-title-show";
#ifndef _WIN32
    t_args[t_arg_count++] = "--no-xlib"; /* the engine never calls XInitThreads */
#endif
    /* Memory rendering cannot take GPU surfaces, so hardware decoding is
     * tried and abandoned on every start unless it is turned off. */
    if (t_no_hw)
        t_args[t_arg_count++] = "--avcodec-hw=none";
    libvlc_instance_t *t_instance = vlc.libvlc_new(t_arg_count, t_args);
    if (t_instance == NULL)
    {
        say("libvlc_new failed: %s", vlc.libvlc_errmsg() ? vlc.libvlc_errmsg() : "(no message)");
        return 1;
    }
    say("libvlc_new ok (plugins found)");

    /* Parse first, so duration and tracks are known before playing, as the
     * engine's filename setter expects. */
    libvlc_media_t *t_media = vlc.libvlc_media_new_path(t_instance, t_file);
    if (t_media == NULL)
    {
        say("libvlc_media_new_path failed");
        return 1;
    }
    double t_parse_start = now_s();
    vlc.libvlc_media_parse_with_options(t_media, 0 /* parse_local */, 5000);
    int t_status = 0;
    while ((t_status = vlc.libvlc_media_get_parsed_status(t_media)) == 0 && now_s() - t_parse_start < 6)
        sleep_ms(10);
    say("parse status %d (4 = done) after %.0f ms; duration %lld ms", t_status,
        (now_s() - t_parse_start) * 1000, (long long)vlc.libvlc_media_get_duration(t_media));

    vlc_media_track **t_tracks = NULL;
    unsigned t_track_count = vlc.libvlc_media_tracks_get(t_media, &t_tracks);
    int t_has_video = 0;
    for (unsigned i = 0; i < t_track_count; i++)
    {
        vlc_media_track *t = t_tracks[i];
        char t_codec[5] = { 0 };
        memcpy(t_codec, &t->i_codec, 4);
        if (t->i_type == 1 && t->u.video != NULL)
        {
            vlc_video_track *v = t->u.video;
            t_has_video = 1;
            s_video.display_width = v->i_width;
            s_video.display_height = v->i_height;
            if (t_apply_sar && v->i_sar_num != 0 && v->i_sar_den != 0 && v->i_sar_num != v->i_sar_den)
                s_video.display_width = (unsigned)((uint64_t)v->i_width * v->i_sar_num / v->i_sar_den);
            say("track %d: video %s %ux%u, SAR %u:%u, %.3f fps", t->i_id, t_codec, v->i_width, v->i_height,
                v->i_sar_num, v->i_sar_den,
                v->i_frame_rate_den ? (double)v->i_frame_rate_num / v->i_frame_rate_den : 0.0);
        }
        else if (t->i_type == 0 && t->u.audio != NULL)
            say("track %d: audio %s, %u channels, %u Hz", t->i_id, t_codec, t->u.audio->i_channels, t->u.audio->i_rate);
        else
            say("track %d: type %d %s", t->i_id, t->i_type, t_codec);
    }
    vlc.libvlc_media_tracks_release(t_tracks, t_track_count);

    /* Looping inside libVLC, instead of stop + play on EndReached. */
    if (t_repeat)
        vlc.libvlc_media_add_option(t_media, ":input-repeat=65535");
    /* Show the first frame on load without playing, as a player object does. */
    if (t_prime)
        vlc.libvlc_media_add_option(t_media, ":start-paused");

    libvlc_media_player_t *t_player = vlc.libvlc_media_player_new_from_media(t_media);
    vlc.libvlc_media_release(t_media);
    vlc.libvlc_video_set_callbacks(t_player, on_lock, on_unlock, on_display, NULL);
    vlc.libvlc_video_set_format_callbacks(t_player, on_format, on_cleanup);

    libvlc_event_manager_t *t_events = vlc.libvlc_media_player_event_manager(t_player);
    const int t_event_types[] = { kEventOpening, kEventBuffering, kEventPlaying, kEventPaused, kEventStopped,
                                  kEventEndReached, kEventError, kEventTimeChanged, kEventLengthChanged, kEventVout };
    for (unsigned i = 0; i < sizeof t_event_types / sizeof t_event_types[0]; i++)
        vlc.libvlc_event_attach(t_events, t_event_types[i], on_event, NULL);

    /* 1. Play at normal rate and measure the cost of memory rendering. */
    if (t_prime)
    {
        say("--- prime (start paused)");
        s_video.play_requested_at = now_s();
        vlc.libvlc_media_player_play(t_player);
        if (!wait_for(&s_video.paused, 5000))
            say("never reached Paused");
        sleep_ms(300);
        say("start-paused: %u frames, time %lld ms", s_video.frames,
            (long long)vlc.libvlc_media_player_get_time(t_player));
        /* start-paused stops before the first picture; one frame step shows it. */
        vlc.libvlc_media_player_next_frame(t_player);
        for (int t_waited = 0; s_video.frames == 0 && t_waited < 3000; t_waited += 10)
            sleep_ms(10);
        say("first frame after next_frame: %.0f ms after play", (s_video.first_frame_at - s_video.play_requested_at) * 1000);
        sleep_ms(300);
        say("primed: %u frames, time %lld ms, state %s, playing flag %d", s_video.frames,
            (long long)vlc.libvlc_media_player_get_time(t_player),
            kStateNames[vlc.libvlc_media_player_get_state(t_player) & 7], s_video.playing);
        save_frame(t_out, "frame-primed.bmp");

        /* A seek while paused must show the new frame. */
        double t_mean_before, t_mean_after;
        unsigned t_before, t_after;
        frame_stats(&t_mean_before, &t_before);
        vlc.libvlc_media_player_set_time(t_player, 10000);
        sleep_ms(600);
        frame_stats(&t_mean_after, &t_after);
        say("paused seek to 10000: time %lld ms, %u display calls, brightness %.1f -> %.1f",
            (long long)vlc.libvlc_media_player_get_time(t_player), t_after - t_before, t_mean_before, t_mean_after);
        t_before = t_after;
        vlc.libvlc_media_player_next_frame(t_player);
        sleep_ms(600);
        frame_stats(&t_mean_after, &t_after);
        say("then next_frame: time %lld ms, %u display calls, brightness %.1f",
            (long long)vlc.libvlc_media_player_get_time(t_player), t_after - t_before, t_mean_after);
        save_frame(t_out, "frame-paused-seek.bmp");
        /* Scrub: seek, play muted until one new picture arrives, pause again. */
        const libvlc_time_t t_targets[] = { 5000, 30000, 12000 };
        for (int i = 0; i < 3; i++)
        {
            frame_stats(&t_mean_before, &t_before);
            double t_scrub_start = now_s();
            vlc.libvlc_audio_set_mute(t_player, 1);
            vlc.libvlc_media_player_set_time(t_player, t_targets[i]);
            vlc.libvlc_media_player_set_pause(t_player, 0);
            unsigned t_now_frames = t_before;
            while (t_now_frames == t_before && now_s() - t_scrub_start < 3)
            {
                sleep_ms(2);
                frame_stats(&t_mean_after, &t_now_frames);
            }
            double t_latency = now_s() - t_scrub_start;
            vlc.libvlc_media_player_set_pause(t_player, 1);
            sleep_ms(300);
            vlc.libvlc_audio_set_mute(t_player, 0);
            frame_stats(&t_mean_after, &t_after);
            say("scrub to %lld: first new frame after %.0f ms; paused at %lld ms; %u display calls",
                (long long)t_targets[i], t_latency * 1000, (long long)vlc.libvlc_media_player_get_time(t_player),
                t_after - t_before);
        }
        save_frame(t_out, "frame-scrubbed.bmp");
        vlc.libvlc_media_player_set_time(t_player, 0);
        sleep_ms(300);
    }

    say("--- play");
    s_video.play_requested_at = now_s();
    if (t_prime)
        vlc.libvlc_media_player_set_pause(t_player, 0);
    else
        vlc.libvlc_media_player_play(t_player);
    if (!wait_for(&s_video.playing, 5000))
    {
        say("never reached Playing (error flag %d)", s_video.error);
        return 1;
    }
    double t_wall0 = now_s(), t_cpu0 = cpu_s();
    unsigned t_frames0 = s_video.frames;
    libvlc_time_t t_time0 = vlc.libvlc_media_player_get_time(t_player);
    sleep_ms(3000);
    double t_wall = now_s() - t_wall0, t_cpu = cpu_s() - t_cpu0;
    double t_mean;
    unsigned t_frames;
    frame_stats(&t_mean, &t_frames);
    say("3 s of playback: %u frames (%.1f fps), media time advanced %lld ms, CPU %.0f%% of one core",
        t_frames - t_frames0, (t_frames - t_frames0) / t_wall,
        (long long)(vlc.libvlc_media_player_get_time(t_player) - t_time0), 100 * t_cpu / t_wall);
    say("latest frame mean brightness %.1f / 255; alpha byte range %u-%u", t_mean, s_video.alpha_min, s_video.alpha_max);
    save_frame(t_out, "frame-play.bmp");

    unsigned t_w = 0, t_h = 0;
    if (vlc.libvlc_video_get_size(t_player, 0, &t_w, &t_h) == 0)
        say("libvlc_video_get_size: %ux%u", t_w, t_h);

    /* 2. Seek to the middle. */
    libvlc_time_t t_length = vlc.libvlc_media_player_get_length(t_player);
    say("--- seek to %lld ms (length %lld ms)", (long long)(t_length / 2), (long long)t_length);
    vlc.libvlc_media_player_set_time(t_player, t_length / 2);
    sleep_ms(700);
    say("time after seek + 700 ms: %lld ms", (long long)vlc.libvlc_media_player_get_time(t_player));

    /* 3. Double speed. */
    say("--- rate 2.0");
    vlc.libvlc_media_player_set_rate(t_player, 2.0f);
    t_time0 = vlc.libvlc_media_player_get_time(t_player);
    sleep_ms(2000);
    say("2 s at rate 2.0 advanced media time %lld ms (expect ~4000)",
        (long long)(vlc.libvlc_media_player_get_time(t_player) - t_time0));
    vlc.libvlc_media_player_set_rate(t_player, 1.0f);

    /* 4. Pause, then step frame by frame. */
    say("--- pause and step");
    vlc.libvlc_media_player_set_pause(t_player, 1);
    sleep_ms(500);
    frame_stats(&t_mean, &t_frames0);
    t_time0 = vlc.libvlc_media_player_get_time(t_player);
    sleep_ms(500);
    frame_stats(&t_mean, &t_frames);
    say("paused: %u display callbacks in 500 ms; time %lld -> %lld ms; state %s", t_frames - t_frames0,
        (long long)t_time0, (long long)vlc.libvlc_media_player_get_time(t_player),
        kStateNames[vlc.libvlc_media_player_get_state(t_player) & 7]);
    for (int i = 0; i < 3; i++)
    {
        libvlc_time_t t_before = vlc.libvlc_media_player_get_time(t_player);
        vlc.libvlc_media_player_next_frame(t_player);
        sleep_ms(300);
        say("next_frame %d: time %lld -> %lld ms", i + 1, (long long)t_before,
            (long long)vlc.libvlc_media_player_get_time(t_player));
    }
    save_frame(t_out, "frame-stepped.bmp");

    /* 5. Volume, while paused and while playing. */
    say("--- volume");
    int t_result = vlc.libvlc_audio_set_volume(t_player, 50);
    say("paused: set 50 returned %d, reads back %d", t_result, vlc.libvlc_audio_get_volume(t_player));
    vlc.libvlc_media_player_set_pause(t_player, 0);
    sleep_ms(500);
    say("playing: reads back %d", vlc.libvlc_audio_get_volume(t_player));
    t_result = vlc.libvlc_audio_set_volume(t_player, 30);
    sleep_ms(100);
    say("playing: set 30 returned %d, reads back %d", t_result, vlc.libvlc_audio_get_volume(t_player));

    /* 6. Run to the end. */
    say("--- play to end");
    s_video.max_gap = 0;
    vlc.libvlc_media_player_set_time(t_player, t_length > 1500 ? t_length - 1500 : 0);
    if (t_repeat)
    {
        /* With input-repeat there is no EndReached; watch time wrap. */
        libvlc_time_t t_last = vlc.libvlc_media_player_get_time(t_player);
        double t_until = now_s() + 4;
        while (now_s() < t_until)
        {
            sleep_ms(20);
            libvlc_time_t t_now = vlc.libvlc_media_player_get_time(t_player);
            if (t_now + 1000 < t_last)
                say("time wrapped %lld -> %lld ms", (long long)t_last, (long long)t_now);
            t_last = t_now;
        }
        say("longest gap between frames around the loop: %.0f ms; EndReached %d", s_video.max_gap * 1000,
            s_video.end_reached);
    }
    else
    {
        if (!wait_for(&s_video.end_reached, 10000))
            say("EndReached not seen within 10 s");
        sleep_ms(100);
        say("state after end: %s, time %lld ms", kStateNames[vlc.libvlc_media_player_get_state(t_player) & 7],
            (long long)vlc.libvlc_media_player_get_time(t_player));

        /* 7. Restart from the main thread, as looping would. libVLC 3 needs
         * a stop before play once the end is reached. */
        say("--- restart (loop)");
        s_video.playing = 0;
        s_video.end_reached = 0;
        s_video.first_frame_at = 0;
        s_video.play_requested_at = now_s();
        vlc.libvlc_media_player_stop(t_player);
        vlc.libvlc_media_player_play(t_player);
        if (wait_for(&s_video.playing, 5000))
        {
            frame_stats(&t_mean, &t_frames0);
            sleep_ms(1000);
            frame_stats(&t_mean, &t_frames);
            say("after restart: time %lld ms, %u frames in 1 s", (long long)vlc.libvlc_media_player_get_time(t_player),
                t_frames - t_frames0);
        }
        else
            say("restart did not reach Playing");
    }

    say("--- summary: %u frames displayed, %u TimeChanged events, %u format calls, video track %s",
        s_video.frames, s_video.time_changed, s_video.format_calls, t_has_video ? "yes" : "no");

    vlc.libvlc_media_player_stop(t_player);
    vlc.libvlc_media_player_release(t_player);
    vlc.libvlc_release(t_instance);
    say("released");
    return 0;
}
