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

// The Linux browser's WebKitGTK half (libbrowser/src/libbrowser_webkitgtk*
// and its helper process, libbrowser_webkitprocess_lnx.cpp) on its own,
// without the engine: tools/ci/webkit_browser_check.py builds this with
// libbrowser's own sources and libcore and runs it on an X screen.
//
//   webkit-browser-check --helper PATH [--work DIR] [MODE]
//
// MODE is one of:
//   all             (the default) the wire format, the conversion of a
//                   page's values, the choice of the browser, and a browser
//                   through the helper: pages, events, JavaScript, handlers
//   missing-helper  no helper where the factory looks: no browser, cleanly
//   backend-cef     OXT_BROWSER_BACKEND=cef: only CEF, so no browser here
//
// The factory list is this file's own (as libbrowser_lnx_factories.cpp's
// is the engine's): a "CEF" whose constructor always fails, as CEF's does
// when libcef.so or a library it needs cannot load, ahead of "WebKitGTK".
// Each check prints PASS or FAIL and a name; the exit status is 0 when
// every check passed.

#include <core.h>

#include "libbrowser_internal.h"
#include "libbrowser_webkitgtk_protocol.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <dirent.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <algorithm>
#include <string>
#include <vector>

////////////////////////////////////////////////////////////////////////////////

extern bool MCWebKitGtkBrowserFactoryCreate(MCBrowserFactoryRef &r_factory);

static int s_cef_attempts = 0;

static bool CheckCefFactoryCreate(MCBrowserFactoryRef &r_factory)
{
	s_cef_attempts++;
	return false;
}

MCBrowserFactoryMap kMCBrowserFactoryMap[] =
{
	{ "CEF", nil, CheckCefFactoryCreate },
	{ "WebKitGTK", nil, MCWebKitGtkBrowserFactoryCreate },
	{ nil, nil, nil },
};

MCBrowserFactoryMap* s_factory_list = kMCBrowserFactoryMap;

////////////////////////////////////////////////////////////////////////////////

static int s_passed = 0;
static int s_failed = 0;

static void Check(bool p_ok, const char *p_name, const std::string &p_detail = std::string())
{
	if (p_ok)
		s_passed++;
	else
		s_failed++;
	printf("%s %s%s%s\n", p_ok ? "PASS" : "FAIL", p_name,
	       p_detail.empty() ? "" : ": ", p_detail.c_str());
	fflush(stdout);
}

// LeakSanitizer, where the check is built with it (webkit_browser_check.py
// --sanitize): weak, so a plain build has none and says so
extern "C" int __lsan_do_recoverable_leak_check(void) __attribute__((weak));

// The block a leak check must find, kept where no scan can see it while the
// check runs, and then made reachable again and freed
static uintptr_t s_hidden_block = 0;

// Out of line, so no register or stack slot of the caller still holds it
__attribute__((noinline)) static void HideBlock()
{
	s_hidden_block = ~(uintptr_t)malloc(64);
}

static void CheckNoLeaks(const char *p_name)
{
	if (__lsan_do_recoverable_leak_check == nullptr)
	{
		printf("SKIP %s: built without LeakSanitizer (--sanitize)\n", p_name);
		fflush(stdout);
		return;
	}
	// First that it can see a leak at all: a check that cannot would pass
	// whatever the code did (detect_leaks=0, say)
	HideBlock();
	bool t_armed = __lsan_do_recoverable_leak_check() != 0;
	free((void *)~s_hidden_block);
	s_hidden_block = 0;
	Check(t_armed, "leak check: it finds a leak it is shown");
	if (t_armed)
		Check(__lsan_do_recoverable_leak_check() == 0, p_name);
}

static double Now()
{
	struct timespec t_now;
	clock_gettime(CLOCK_MONOTONIC, &t_now);
	return t_now.tv_sec + t_now.tv_nsec / 1e9;
}

// The engine runs libbrowser's runloop actions about every 10 ms
// (MCScreenDC::wait, with runloop actions); so does this, until p_done says
// so or the time is up
template <typename T>
static bool Pump(T p_done, double p_seconds = 20.0)
{
	MCBrowserRunloopCallback t_callback;
	void *t_context;
	MCBrowserLibraryGetRunloopCallback(t_callback, t_context);

	double t_end = Now() + p_seconds;
	while (Now() < t_end)
	{
		t_callback(t_context);
		if (p_done())
			return true;
		usleep(10000);
	}
	t_callback(t_context);
	return p_done();
}

////////////////////////////////////////////////////////////////////////////////

struct Event
{
	std::string kind;
	bool frame;
	std::string url;
	std::string error;
};

class CheckEventHandler : public MCBrowserEventHandler
{
public:
	std::vector<Event> events;

	void Add(const char *p_kind, bool p_frame, const char *p_url, const char *p_error = "")
	{
		Event t_event;
		t_event.kind = p_kind;
		t_event.frame = p_frame;
		t_event.url = p_url != nil ? p_url : "";
		t_event.error = p_error != nil ? p_error : "";
		events.push_back(t_event);
	}

	virtual void OnNavigationBegin(MCBrowser *, bool p_frame, const char *p_url) { Add("navigateBegin", p_frame, p_url); }
	virtual void OnNavigationComplete(MCBrowser *, bool p_frame, const char *p_url) { Add("navigateComplete", p_frame, p_url); }
	virtual void OnNavigationFailed(MCBrowser *, bool p_frame, const char *p_url, const char *p_error) { Add("navigateFailed", p_frame, p_url, p_error); }
	virtual void OnDocumentLoadBegin(MCBrowser *, bool p_frame, const char *p_url) { Add("documentLoadBegin", p_frame, p_url); }
	virtual void OnDocumentLoadComplete(MCBrowser *, bool p_frame, const char *p_url) { Add("documentLoadComplete", p_frame, p_url); }
	virtual void OnDocumentLoadFailed(MCBrowser *, bool p_frame, const char *p_url, const char *p_error) { Add("documentLoadFailed", p_frame, p_url, p_error); }
	virtual void OnNavigationRequestUnhandled(MCBrowser *, bool p_frame, const char *p_url) { Add("unhandled", p_frame, p_url); }

	bool Has(const char *p_kind, const std::string &p_url)
	{
		for (size_t i = 0; i < events.size(); i++)
			if (events[i].kind == p_kind && events[i].url == p_url)
				return true;
		return false;
	}

	std::string Describe()
	{
		std::string t_text;
		for (size_t i = 0; i < events.size(); i++)
			t_text += (i == 0 ? "" : ", ") + events[i].kind + " " + events[i].url + (events[i].error.empty() ? "" : " (" + events[i].error + ")");
		return t_text.empty() ? "no events" : t_text;
	}
};

class CheckJavaScriptHandler : public MCBrowserJavaScriptHandler
{
public:
	std::vector<std::string> handlers;
	std::vector<MCBrowserListRef> params;

	virtual ~CheckJavaScriptHandler()
	{
		for (size_t i = 0; i < params.size(); i++)
			MCBrowserListRelease(params[i]);
	}

	virtual void OnJavaScriptCall(MCBrowser *, const char *p_handler, MCBrowserListRef p_params)
	{
		handlers.push_back(p_handler);
		params.push_back(MCBrowserListRetain(p_params));
	}
};

////////////////////////////////////////////////////////////////////////////////

// A list's values as text: b:true i:3 d:2.5 s:"x" [ ... ] { k: ... }, keys
// in the order MCBrowserDictionaryGetKeys gives them, sorted
static std::string Describe(MCBrowserListRef p_list);
static std::string Describe(MCBrowserDictionaryRef p_dict);

static std::string DescribeDouble(double p_value)
{
	char t_buffer[64];
	snprintf(t_buffer, sizeof(t_buffer), "%g", p_value);
	return t_buffer;
}

static std::string Describe(MCBrowserListRef p_list)
{
	uint32_t t_size = 0;
	MCBrowserListGetSize(p_list, t_size);
	std::string t_text = "[";
	for (uint32_t i = 0; i < t_size; i++)
	{
		if (i > 0)
			t_text += " ";
		MCBrowserValueType t_type = kMCBrowserValueTypeNone;
		MCBrowserListGetType(p_list, i, t_type);
		switch (t_type)
		{
			case kMCBrowserValueTypeBoolean:
			{
				bool t_value = false;
				MCBrowserListGetBoolean(p_list, i, t_value);
				t_text += t_value ? "b:true" : "b:false";
				break;
			}
			case kMCBrowserValueTypeInteger:
			{
				int32_t t_value = 0;
				MCBrowserListGetInteger(p_list, i, t_value);
				t_text += "i:" + std::to_string(t_value);
				break;
			}
			case kMCBrowserValueTypeDouble:
			{
				double t_value = 0;
				MCBrowserListGetDouble(p_list, i, t_value);
				t_text += "d:" + DescribeDouble(t_value);
				break;
			}
			case kMCBrowserValueTypeUTF8String:
			{
				char *t_value = nil;
				MCBrowserListGetUTF8String(p_list, i, t_value);
				t_text += std::string("s:\"") + (t_value != nil ? t_value : "") + "\"";
				// a copy (MCBrowserValueGetUTF8String)
				if (t_value != nil)
					MCCStringFree(t_value);
				break;
			}
			case kMCBrowserValueTypeList:
			{
				MCBrowserListRef t_value = nil;
				MCBrowserListGetList(p_list, i, t_value);
				t_text += Describe(t_value);
				break;
			}
			case kMCBrowserValueTypeDictionary:
			{
				MCBrowserDictionaryRef t_value = nil;
				MCBrowserListGetDictionary(p_list, i, t_value);
				t_text += Describe(t_value);
				break;
			}
			default:
				t_text += "?";
				break;
		}
	}
	return t_text + "]";
}

static std::string Describe(MCBrowserDictionaryRef p_dict)
{
	char **t_keys = nil;
	uint32_t t_count = 0;
	MCBrowserDictionaryGetKeys(p_dict, t_keys, t_count);
	std::vector<std::string> t_sorted;
	for (uint32_t i = 0; i < t_count; i++)
		t_sorted.push_back(t_keys[i]);
	std::sort(t_sorted.begin(), t_sorted.end());

	// Each value through a one-item list, to reuse the list's description
	std::string t_text = "{";
	for (size_t i = 0; i < t_sorted.size(); i++)
	{
		const char *t_key = t_sorted[i].c_str();
		MCBrowserValueType t_type = kMCBrowserValueTypeNone;
		MCBrowserDictionaryGetType(p_dict, t_key, t_type);
		MCBrowserListRef t_one = nil;
		MCBrowserListCreate(t_one);
		switch (t_type)
		{
			case kMCBrowserValueTypeBoolean: { bool v = false; MCBrowserDictionaryGetBoolean(p_dict, t_key, v); MCBrowserListAppendBoolean(t_one, v); break; }
			case kMCBrowserValueTypeInteger: { int32_t v = 0; MCBrowserDictionaryGetInteger(p_dict, t_key, v); MCBrowserListAppendInteger(t_one, v); break; }
			case kMCBrowserValueTypeDouble: { double v = 0; MCBrowserDictionaryGetDouble(p_dict, t_key, v); MCBrowserListAppendDouble(t_one, v); break; }
			case kMCBrowserValueTypeUTF8String: { char *v = nil; MCBrowserDictionaryGetUTF8String(p_dict, t_key, v); MCBrowserListAppendUTF8String(t_one, v != nil ? v : ""); if (v != nil) MCCStringFree(v); break; }
			case kMCBrowserValueTypeList: { MCBrowserListRef v = nil; MCBrowserDictionaryGetList(p_dict, t_key, v); MCBrowserListAppendList(t_one, v); break; }
			case kMCBrowserValueTypeDictionary: { MCBrowserDictionaryRef v = nil; MCBrowserDictionaryGetDictionary(p_dict, t_key, v); MCBrowserListAppendDictionary(t_one, v); break; }
			default: break;
		}
		std::string t_value = Describe(t_one);
		MCBrowserListRelease(t_one);
		t_text += (i == 0 ? "" : " ") + t_sorted[i] + ": " + t_value.substr(1, t_value.size() - 2);
	}
	return t_text + "}";
}

////////////////////////////////////////////////////////////////////////////////

static void CheckWireFormat()
{
	using namespace MCWebKitGtkProtocol;

	std::vector<std::string> t_fields;
	t_fields.push_back("eval");
	t_fields.push_back("12");
	t_fields.push_back("a\tb\nc\\d\re");
	t_fields.push_back("");
	t_fields.push_back("caf\xc3\xa9 \xe2\x9c\x93");

	std::string t_line = Encode(t_fields);
	Check(t_line.size() > 0 && t_line[t_line.size() - 1] == '\n' &&
	      t_line.find('\n') == t_line.size() - 1 && t_line.find('\r') == std::string::npos,
	      "wire: a message is one line, whatever its fields hold");

	std::vector<std::string> t_decoded;
	bool t_ok = Decode(t_line.substr(0, t_line.size() - 1), t_decoded);
	Check(t_ok && t_decoded == t_fields, "wire: the fields come back as they were sent");

	std::vector<std::string> t_bad;
	Check(!Decode("eval\tbad\\qescape", t_bad), "wire: an unknown escape is refused");
	Check(!Decode("eval\ttrailing\\", t_bad), "wire: a line that ends in the middle of an escape is refused");

	// Lines arrive in pieces, and several in one read
	LineReader t_reader;
	std::string t_two = Encode(std::vector<std::string>(1, "one")) + Encode(std::vector<std::string>(1, "two"));
	std::string t_line_out;
	t_reader.Append(t_two.data(), 2);
	bool t_early = t_reader.Next(t_line_out);
	t_reader.Append(t_two.data() + 2, t_two.size() - 2);
	std::string t_first, t_second, t_third;
	bool t_got_first = t_reader.Next(t_first);
	bool t_got_second = t_reader.Next(t_second);
	bool t_got_third = t_reader.Next(t_third);
	Check(!t_early && t_got_first && t_first == "one" && t_got_second && t_second == "two" && !t_got_third,
	      "wire: lines are read whole, however the bytes arrive");
}

static void CheckJSONConversion()
{
	struct { const char *json; const char *expected; const char *name; } t_cases[] =
	{
		{ "[]", "[]", "an empty list" },
		{ "[true,false]", "[b:true b:false]", "booleans" },
		{ "[0,3,-7,2147483647,-2147483648]", "[i:0 i:3 i:-7 i:2147483647 i:-2147483648]", "whole numbers in 32 bits are integers" },
		{ "[2147483648,2.5,-0.125,1e3,1.5E-2]", "[d:2.14748e+09 d:2.5 d:-0.125 d:1000 d:0.015]", "other numbers are doubles" },
		{ "[\"a\\\"b\\\\c\\/d\\n\\t\"]", "[s:\"a\"b\\c/d\n\t\"]", "string escapes" },
		{ "[\"\\u00e9\\u2713\\ud83d\\ude00\"]", "[s:\"\xc3\xa9\xe2\x9c\x93\xf0\x9f\x98\x80\"]", "\\u escapes, a surrogate pair among them, as UTF-8" },
		{ "[\"caf\xc3\xa9\"]", "[s:\"caf\xc3\xa9\"]", "UTF-8 is kept" },
		{ " [ 1 , [ 2 , [ ] ] , { } ] ", "[i:1 [i:2 []] {}]", "nesting and white space" },
		{ "[{\"b\":1,\"a\":[\"x\"],\"c\":{\"d\":true}}]", "[{a: [s:\"x\"] b: i:1 c: {d: b:true}}]", "objects are dictionaries" },
		{ "[null]", "[s:\"null\"]", "null is the text null, as CEF gives String(null)" },
	};

	for (size_t i = 0; i < sizeof(t_cases) / sizeof(t_cases[0]); i++)
	{
		MCBrowserListRef t_list = nil;
		bool t_ok = MCBrowserListCreateFromJSON(t_cases[i].json, t_list);
		std::string t_got = t_ok ? Describe(t_list) : std::string("(refused)");
		if (t_list != nil)
			MCBrowserListRelease(t_list);
		Check(t_ok && t_got == t_cases[i].expected, (std::string("json: ") + t_cases[i].name).c_str(),
		      t_got == t_cases[i].expected ? std::string() : "got " + t_got + ", expected " + t_cases[i].expected);
	}

	const char *t_bad[] = { "", "{}", "1", "[1,]", "[1", "[\"abc]", "[tru]", "[1] x", "[01]", "[\"\\ud83d\"]", "[\"a\x01\"]" };
	for (size_t i = 0; i < sizeof(t_bad) / sizeof(t_bad[0]); i++)
	{
		MCBrowserListRef t_list = nil;
		bool t_ok = MCBrowserListCreateFromJSON(t_bad[i], t_list);
		if (t_list != nil)
			MCBrowserListRelease(t_list);
		Check(!t_ok, (std::string("json: refuses ") + t_bad[i]).c_str());
	}
}

////////////////////////////////////////////////////////////////////////////////

// The helper processes running now, by the name of their executable
static int CountHelpers(const char *p_helper)
{
	const char *t_name = strrchr(p_helper, '/');
	t_name = t_name != nil ? t_name + 1 : p_helper;

	int t_count = 0;
	DIR *t_proc = opendir("/proc");
	if (t_proc == nil)
		return -1;
	struct dirent *t_entry;
	while ((t_entry = readdir(t_proc)) != nil)
	{
		if (t_entry->d_name[0] < '0' || t_entry->d_name[0] > '9')
			continue;
		char t_path[300], t_comm[256] = "";
		snprintf(t_path, sizeof(t_path), "/proc/%s/comm", t_entry->d_name);
		FILE *t_file = fopen(t_path, "r");
		if (t_file == nil)
			continue;
		if (fgets(t_comm, sizeof(t_comm), t_file) != nil)
		{
			t_comm[strcspn(t_comm, "\n")] = '\0';
			// comm is cut at 15 characters
			if (strncmp(t_comm, t_name, 15) == 0)
				t_count++;
		}
		fclose(t_file);
	}
	closedir(t_proc);
	return t_count;
}

static std::string Eval(MCBrowser *p_browser, const char *p_script, bool &r_ok)
{
	char *t_result = nil;
	r_ok = p_browser->EvaluateJavaScript(p_script, t_result);
	std::string t_text = t_result != nil ? t_result : "";
	if (t_result != nil)
		MCCStringFree(t_result);
	return t_text;
}

static std::string Eval(MCBrowser *p_browser, const char *p_script)
{
	bool t_ok;
	return Eval(p_browser, p_script, t_ok);
}

static std::string GetString(MCBrowser *p_browser, MCBrowserProperty p_property)
{
	char *t_value = nil;
	if (!p_browser->GetStringProperty(p_property, t_value))
		return "(failed)";
	std::string t_text = t_value != nil ? t_value : "";
	if (t_value != nil)
		MCCStringFree(t_value);
	return t_text;
}

static bool WriteFile(const std::string &p_path, const char *p_text)
{
	FILE *t_file = fopen(p_path.c_str(), "w");
	if (t_file == nil)
		return false;
	fputs(p_text, t_file);
	fclose(t_file);
	return true;
}

static void CheckChoice()
{
	// No backend asked for: CEF first, as always, and WebKitGTK when CEF
	// cannot load
	unsetenv("OXT_BROWSER_BACKEND");
	s_cef_attempts = 0;
	MCBrowserFactoryRef t_default = nil;
	bool t_got_default = MCBrowserFactoryGet("", t_default);
	MCBrowserFactoryRef t_webkit = nil;
	bool t_got_webkit = MCBrowserFactoryGet("WebKitGTK", t_webkit);
	Check(t_got_default && t_got_webkit && t_default == t_webkit && s_cef_attempts == 1,
	      "choice: CEF is tried first, and WebKitGTK is the browser when CEF cannot load",
	      "CEF tried " + std::to_string(s_cef_attempts) + " times");

	// OXT_BROWSER_BACKEND=webkitgtk: CEF is not tried at all
	setenv("OXT_BROWSER_BACKEND", "webkitgtk", 1);
	s_cef_attempts = 0;
	MCBrowserFactoryRef t_chosen = nil;
	bool t_got_chosen = MCBrowserFactoryGet(nil, t_chosen);
	Check(t_got_chosen && t_chosen == t_webkit && s_cef_attempts == 0,
	      "choice: OXT_BROWSER_BACKEND=webkitgtk uses WebKitGTK without trying CEF");

	// A value that names no browser is left out of the choice
	setenv("OXT_BROWSER_BACKEND", "no-such-browser", 1);
	s_cef_attempts = 0;
	t_chosen = nil;
	t_got_chosen = MCBrowserFactoryGet("default", t_chosen);
	Check(t_got_chosen && t_chosen == t_webkit && s_cef_attempts == 1,
	      "choice: an OXT_BROWSER_BACKEND that names no browser changes nothing");
	unsetenv("OXT_BROWSER_BACKEND");
}

// The engine shows a browser by embedding its native layer in a GTK 2
// GtkSocket (MCNativeLayerX11::doAttach: gtk_socket_add_id). This does the
// same, with GTK 2 loaded as the engine loads it (dlopen), and reads the
// page's colour back from the X server: the helper's GTK 3 plug must be
// embedded, sized to the socket and drawn.
typedef void *(*GtkWidgetNewFunc)(int);
typedef void *(*GtkSocketNewFunc)(void);
typedef void (*GtkWidgetFunc)(void *);
typedef void (*GtkContainerAddFunc)(void *, void *);
typedef void (*GtkSetSizeFunc)(void *, int, int);
typedef void (*GtkSocketAddIdFunc)(void *, unsigned long);
typedef void *(*GtkSocketGetPlugWindowFunc)(void *);
typedef unsigned long (*GdkGetXidFunc)(void *);
typedef int (*GtkInitCheckFunc)(int *, char ***);
typedef int (*GtkEventsPendingFunc)(void);
typedef int (*GtkMainIterationDoFunc)(int);

static void CheckEmbed(MCBrowser *p_browser)
{
	void *t_gtk = dlopen("libgtk-x11-2.0.so.0", RTLD_NOW | RTLD_GLOBAL);
	Check(t_gtk != nil, "embed: GTK 2 loads, as in the engine");
	if (t_gtk == nil)
		return;

	GtkInitCheckFunc t_init = (GtkInitCheckFunc)dlsym(t_gtk, "gtk_init_check");
	GtkWidgetNewFunc t_window_new = (GtkWidgetNewFunc)dlsym(t_gtk, "gtk_window_new");
	GtkSocketNewFunc t_socket_new = (GtkSocketNewFunc)dlsym(t_gtk, "gtk_socket_new");
	GtkContainerAddFunc t_add = (GtkContainerAddFunc)dlsym(t_gtk, "gtk_container_add");
	GtkSetSizeFunc t_set_size = (GtkSetSizeFunc)dlsym(t_gtk, "gtk_widget_set_size_request");
	GtkWidgetFunc t_show_all = (GtkWidgetFunc)dlsym(t_gtk, "gtk_widget_show_all");
	GtkWidgetFunc t_destroy = (GtkWidgetFunc)dlsym(t_gtk, "gtk_widget_destroy");
	GtkSocketAddIdFunc t_add_id = (GtkSocketAddIdFunc)dlsym(t_gtk, "gtk_socket_add_id");
	GtkSocketGetPlugWindowFunc t_plug_window = (GtkSocketGetPlugWindowFunc)dlsym(t_gtk, "gtk_socket_get_plug_window");
	GdkGetXidFunc t_get_xid = (GdkGetXidFunc)dlsym(t_gtk, "gdk_x11_drawable_get_xid");
	GdkGetXidFunc t_get_display = (GdkGetXidFunc)dlsym(t_gtk, "gdk_x11_get_default_xdisplay");
	GtkEventsPendingFunc t_pending = (GtkEventsPendingFunc)dlsym(t_gtk, "gtk_events_pending");
	GtkMainIterationDoFunc t_iterate = (GtkMainIterationDoFunc)dlsym(t_gtk, "gtk_main_iteration_do");
	if (t_init == nil || t_window_new == nil || t_socket_new == nil || t_add == nil || t_set_size == nil ||
	    t_show_all == nil || t_destroy == nil || t_add_id == nil || t_plug_window == nil || t_get_xid == nil ||
	    t_get_display == nil || t_pending == nil || t_iterate == nil || !t_init(nil, nil))
	{
		Check(false, "embed: GTK 2 starts");
		return;
	}

	void *t_window = t_window_new(0);
	void *t_socket = t_socket_new();
	t_set_size(t_socket, 320, 200);
	t_add(t_window, t_socket);
	t_show_all(t_window);

	p_browser->SetStringProperty(kMCBrowserHTMLText,
	                             "<html><body style='margin:0;background:#ff0000'></body></html>");
	t_add_id(t_socket, (unsigned long)(uintptr_t)p_browser->GetNativeLayer());

	Display *t_display = (Display *)t_get_display(nil);
	unsigned long t_plug = 0;
	unsigned int t_width = 0, t_height = 0;
	unsigned long t_pixel = 0;
	bool t_red = Pump([&]() {
		while (t_pending())
			t_iterate(0);
		void *t_gdk_plug = t_plug_window(t_socket);
		if (t_gdk_plug == nil)
			return false;
		t_plug = t_get_xid(t_gdk_plug);
		Window t_root;
		int t_x, t_y;
		unsigned int t_border, t_depth;
		if (!XGetGeometry(t_display, t_plug, &t_root, &t_x, &t_y, &t_width, &t_height, &t_border, &t_depth) ||
		    t_width < 10 || t_height < 10)
			return false;
		XImage *t_image = XGetImage(t_display, t_plug, t_width / 2, t_height / 2, 1, 1, AllPlanes, ZPixmap);
		if (t_image == nil)
			return false;
		t_pixel = XGetPixel(t_image, 0, 0) & 0xFFFFFF;
		XDestroyImage(t_image);
		return t_pixel == 0xFF0000;
	});
	char t_detail[96];
	snprintf(t_detail, sizeof(t_detail), "plug %lu, %ux%u, centre pixel #%06lx", t_plug, t_width, t_height, t_pixel);
	Check(t_plug != 0, "embed: the browser's window is the GTK 2 socket's plug (XEmbed)", t_detail);
	Check(t_width == 320 && t_height == 200, "embed: it takes the socket's size", t_detail);
	Check(t_red, "embed: the page is drawn in it", t_detail);

	t_destroy(t_window);
	while (t_pending())
		t_iterate(0);
}

static void CheckBrowser(const std::string &p_work, const char *p_helper)
{
	Display *t_display = XOpenDisplay(nil);
	Check(t_display != nil, "browser: the X display opens");
	if (t_display == nil)
		return;

	Window t_parent = XCreateSimpleWindow(t_display, DefaultRootWindow(t_display), 0, 0, 640, 480, 0, 0, 0);
	XMapWindow(t_display, t_parent);
	XSync(t_display, False);

	int t_helpers_before = CountHelpers(p_helper);

	MCBrowserFactoryRef t_factory = nil;
	MCBrowserFactoryGet("WebKitGTK", t_factory);
	MCBrowserRef t_browser_ref = nil;
	bool t_created = t_factory != nil && MCBrowserFactoryCreateBrowser(t_factory, t_display, (void *)t_parent, t_browser_ref);
	MCBrowser *t_browser = t_browser_ref;
	Check(t_created && t_browser != nil, "browser: one is made");
	if (!t_created)
	{
		XCloseDisplay(t_display);
		return;
	}

	Check(CountHelpers(p_helper) == t_helpers_before + 1, "browser: it has a helper process of its own");

	// The native layer is the X window that the engine's native layer embeds
	// (MCNativeLayerX11: gtk_socket_add_id)
	Window t_layer = (Window)(uintptr_t)t_browser->GetNativeLayer();
	XWindowAttributes t_attributes;
	Check(t_layer != None && XGetWindowAttributes(t_display, t_layer, &t_attributes) != 0,
	      "browser: its native layer is an X window");

	CheckEventHandler *t_events = new CheckEventHandler();
	t_browser->SetEventHandler(t_events);
	CheckJavaScriptHandler *t_js = new CheckJavaScriptHandler();
	t_browser->SetJavaScriptHandler(t_js);

	// htmlText: no navigation messages for the main frame, and the URL is
	// empty, as with CEF (PageOrigin::kSetSource)
	Check(t_browser->SetStringProperty(kMCBrowserHTMLText,
	                                   "<html><head><title>OXT one</title></head><body><p id='p'>first</p></body></html>"),
	      "htmlText: set");
	bool t_titled = Pump([&]() { return Eval(t_browser, "document.title") == "OXT one"; });
	Check(t_titled, "htmlText: the page shows it");
	Pump([]() { return false; }, 0.5);
	Check(t_events->events.empty(), "htmlText: no navigation messages, as with CEF", t_events->Describe());
	Check(GetString(t_browser, kMCBrowserURL) == "", "htmlText: the URL is empty, as with CEF", GetString(t_browser, kMCBrowserURL));
	std::string t_source = GetString(t_browser, kMCBrowserHTMLText);
	Check(t_source.find("<p id=\"p\">first</p>") != std::string::npos || t_source.find("<p id='p'>first</p>") != std::string::npos,
	      "htmlText: reading it gives the page's HTML", t_source);
	// As CEF (GetSource: Blink's markup of the document): the page as it is
	// now, not as it was given
	Eval(t_browser, "document.getElementById('p').textContent = 'changed'");
	t_source = GetString(t_browser, kMCBrowserHTMLText);
	Check(t_source.find(">changed</p>") != std::string::npos, "htmlText: reading it gives the page as its script left it", t_source);

	// do ... in widget
	bool t_ok = false;
	std::string t_value = Eval(t_browser, "1 + 2", t_ok);
	Check(t_ok && t_value == "3", "JavaScript: a number comes back as text", t_value);
	t_value = Eval(t_browser, "'caf\xc3\xa9\\t' + String.fromCharCode(10) + 'x'", t_ok);
	Check(t_ok && t_value == "caf\xc3\xa9\t\nx", "JavaScript: text with tabs, line ends and UTF-8 comes back whole", t_value);
	t_value = Eval(t_browser, "undefined", t_ok);
	Check(t_ok && t_value == "undefined", "JavaScript: undefined is the text undefined, as String(undefined)", t_value);
	t_value = Eval(t_browser, "[1, 'a']", t_ok);
	Check(t_ok && t_value == "1,a", "JavaScript: an array is String(array)", t_value);
	t_value = Eval(t_browser, "throw new Error('oxt')", t_ok);
	Check(!t_ok, "JavaScript: a script that throws fails");

	// The scroll bars are the body's overflow style, as with CEF
	t_browser->SetBoolProperty(kMCBrowserVerticalScrollbarEnabled, false);
	bool t_vscroll = true;
	t_browser->GetBoolProperty(kMCBrowserVerticalScrollbarEnabled, t_vscroll);
	Check(!t_vscroll && Eval(t_browser, "document.body.style.overflowY") == "hidden", "scroll bars: vScrollbar false hides them");
	t_browser->SetBoolProperty(kMCBrowserVerticalScrollbarEnabled, true);

	// javascriptHandlers: liveCode.<handler>(...) calls the script
	Check(t_browser->SetStringProperty(kMCBrowserJavaScriptHandlers, "oxtOne\noxtTwo"), "handlers: set");
	Check(GetString(t_browser, kMCBrowserJavaScriptHandlers) == "oxtOne\noxtTwo", "handlers: read back as set");
	Eval(t_browser, "liveCode.oxtOne(1, 'two', 2.5, true, [3, 'x'], {k: 'v'}, null, undefined)");
	bool t_called = Pump([&]() { return !t_js->handlers.empty(); });
	std::string t_params = t_called ? Describe(t_js->params[0]) : std::string();
	Check(t_called && t_js->handlers[0] == "oxtOne", "handlers: the page calls one");
	Check(t_params == "[i:1 s:\"two\" d:2.5 b:true [i:3 s:\"x\"] {k: s:\"v\"} s:\"null\" s:\"undefined\"]",
	      "handlers: its parameters arrive with their types", t_params);
	Check(Eval(t_browser, "typeof liveCode.oxtThree") == "undefined", "handlers: only those named are there");

	// Every call the page makes, named or not, leaves nothing behind in the
	// engine (the handler's name is a copy of its own). A page sends a name
	// the script did not give only by posting to the channel itself.
	for (int i = 0; i < 20; i++)
		Eval(t_browser, "liveCode.oxtOne(1)");
	for (int i = 0; i < 20; i++)
		Eval(t_browser, "window.webkit.messageHandlers.livecode.postMessage(JSON.stringify(['oxtThree', [1]]))");
	t_js->handlers.clear();
	Eval(t_browser, "liveCode.oxtTwo('last')");
	Pump([&]() { return !t_js->handlers.empty(); });
	CheckNoLeaks("handlers: a call leaves nothing behind, named or not");

	// Pages: the messages CEF sends for a page, in its order
	std::string t_page_one = "file://" + p_work + "/one.html";
	std::string t_page_two = "file://" + p_work + "/two.html";
	WriteFile(p_work + "/one.html", "<html><head><title>one</title></head><body>one</body></html>");
	WriteFile(p_work + "/two.html",
	          "<html><head><title>two</title></head><body>two<script>liveCode.oxtTwo('loaded')</script></body></html>");

	t_events->events.clear();
	t_js->handlers.clear();
	Check(t_browser->GoToURL(t_page_one.c_str()), "pages: go to a URL");
	bool t_loaded = Pump([&]() { return t_events->Has("navigateComplete", t_page_one); });
	Check(t_loaded, "pages: the page loads", t_events->Describe());
	bool t_order = t_events->events.size() == 4 &&
		t_events->events[0].kind == "navigateBegin" && t_events->events[1].kind == "documentLoadBegin" &&
		t_events->events[2].kind == "documentLoadComplete" && t_events->events[3].kind == "navigateComplete";
	Check(t_order, "pages: navigateBegin, documentLoadBegin, documentLoadComplete, navigateComplete", t_events->Describe());
	Check(GetString(t_browser, kMCBrowserURL) == t_page_one, "pages: the URL is the page's", GetString(t_browser, kMCBrowserURL));

	t_events->events.clear();
	t_browser->GoToURL(t_page_two.c_str());
	t_loaded = Pump([&]() { return t_events->Has("navigateComplete", t_page_two) && !t_js->handlers.empty(); });
	Check(t_loaded && t_js->handlers[0] == "oxtTwo", "handlers: a new page has them too, while it loads", t_events->Describe());

	bool t_can_back = false, t_can_forward = true;
	t_browser->GetBoolProperty(kMCBrowserCanGoBack, t_can_back);
	t_browser->GetBoolProperty(kMCBrowserCanGoForward, t_can_forward);
	Check(t_can_back && !t_can_forward, "history: can go back, not forward");

	t_events->events.clear();
	t_browser->GoBack();
	t_loaded = Pump([&]() { return t_events->Has("navigateComplete", t_page_one); });
	Check(t_loaded, "history: back to the first page", t_events->Describe());
	t_browser->GetBoolProperty(kMCBrowserCanGoForward, t_can_forward);
	Check(t_can_forward, "history: then forward is possible");

	// htmlText of a page is the document as its script left it, with its
	// doctype (as CEF: the media check reads "script ran: 3" from it)
	std::string t_page_dom = "file://" + p_work + "/dom.html";
	WriteFile(p_work + "/dom.html",
	          "<!DOCTYPE html><html><head><title>dom</title></head><body><h1 id=\"h\">waiting</h1>"
	          "<script>document.getElementById('h').textContent = 'script ran: ' + (1 + 2);</script></body></html>");
	t_events->events.clear();
	t_browser->GoToURL(t_page_dom.c_str());
	t_loaded = Pump([&]() { return t_events->Has("navigateComplete", t_page_dom); });
	t_source = GetString(t_browser, kMCBrowserHTMLText);
	Check(t_loaded && t_source.find("script ran: 3") != std::string::npos && t_source.find("waiting") == std::string::npos,
	      "htmlText: a page's is the document as its script left it", t_source);
	Check(t_source.compare(0, 15, "<!DOCTYPE html>") == 0, "htmlText: with its doctype", t_source.substr(0, 40));

	// The page's text, whatever the page's own encoding (as CEF: htmlText is
	// UTF-8 to the engine)
	std::string t_page_latin = "file://" + p_work + "/latin.html";
	std::string t_page_utf16 = "file://" + p_work + "/utf16.html";
	WriteFile(p_work + "/latin.html",
	          "<html><head><meta charset=\"windows-1252\"><title>latin</title></head><body>caf\xe9 \x80</body></html>");
	{
		// UTF-16LE with its byte order mark, written byte by byte: the text
		// holds NULs
		std::string t_text = "<html><head><title>wide</title></head><body>na\xc3\xafve</body></html>";
		std::string t_bytes = "\xff\xfe";
		for (size_t i = 0; i < t_text.size(); i++)
		{
			unsigned int t_char = (unsigned char)t_text[i];
			if (t_char == 0xc3)
				t_char = 0xc0 | ((unsigned char)t_text[++i] & 0x3f);
			t_bytes += (char)(t_char & 0xff);
			t_bytes += (char)(t_char >> 8);
		}
		FILE *t_file = fopen((p_work + "/utf16.html").c_str(), "wb");
		if (t_file != nullptr)
		{
			fwrite(t_bytes.data(), 1, t_bytes.size(), t_file);
			fclose(t_file);
		}
	}
	t_events->events.clear();
	t_browser->GoToURL(t_page_latin.c_str());
	t_loaded = Pump([&]() { return t_events->Has("navigateComplete", t_page_latin); });
	t_source = GetString(t_browser, kMCBrowserHTMLText);
	Check(t_loaded && t_source.find("caf\xc3\xa9 \xe2\x82\xac") != std::string::npos && t_source.find('\xe9') == std::string::npos,
	      "htmlText: a windows-1252 page's source reads as UTF-8", t_source);
	t_events->events.clear();
	t_browser->GoToURL(t_page_utf16.c_str());
	t_loaded = Pump([&]() { return t_events->Has("navigateComplete", t_page_utf16); });
	t_source = GetString(t_browser, kMCBrowserHTMLText);
	Check(t_loaded && t_source.find("<title>wide</title>") != std::string::npos &&
	      t_source.find("na\xc3\xafve") != std::string::npos && t_source.find('\0') == std::string::npos,
	      "htmlText: a UTF-16 page's source reads as UTF-8", t_source);
	t_events->events.clear();
	t_browser->GoToURL(t_page_two.c_str());
	t_loaded = Pump([&]() { return t_events->Has("navigateComplete", t_page_two); });
	t_source = GetString(t_browser, kMCBrowserHTMLText);
	Check(t_loaded && t_source.find("<title>two</title><") != std::string::npos,
	      "htmlText: a UTF-8 page's text", t_source);

	// A page that is not there fails, with its URL and an error
	std::string t_missing = "file://" + p_work + "/missing.html";
	t_events->events.clear();
	t_browser->GoToURL(t_missing.c_str());
	bool t_failed = Pump([&]() { return t_events->Has("navigateFailed", t_missing); });
	Check(t_failed && t_events->Has("documentLoadFailed", t_missing) && !t_events->Has("navigateComplete", t_missing),
	      "pages: a missing page sends documentLoadFailed and navigateFailed", t_events->Describe());

	// A URL whose scheme the browser does not know is the script's
	// (browserUnhandledLoadRequest), as CEF's ERR_UNKNOWN_URL_SCHEME
	t_events->events.clear();
	t_browser->GoToURL("oxtcheck:hello");
	bool t_unhandled = Pump([&]() { return t_events->Has("unhandled", "oxtcheck:hello"); });
	Check(t_unhandled && !t_events->Has("navigateFailed", "oxtcheck:hello"),
	      "pages: an unknown scheme is an unhandled request, not a failure", t_events->Describe());

	// The user agent
	t_browser->SetStringProperty(kMCBrowserUserAgent, "OXT-Check/1.0");
	Check(GetString(t_browser, kMCBrowserUserAgent) == "OXT-Check/1.0" &&
	      Eval(t_browser, "navigator.userAgent") == "OXT-Check/1.0", "userAgent: set and used");

	CheckEmbed(t_browser);

	// Releasing the browser ends its helper
	t_browser->SetEventHandler(nil);
	t_browser->SetJavaScriptHandler(nil);
	t_events->Release();
	t_js->Release();
	MCBrowserRelease(t_browser_ref);
	bool t_ended = Pump([&]() { return CountHelpers(p_helper) == t_helpers_before; }, 10.0);
	Check(t_ended, "browser: releasing it ends its helper process");

	XDestroyWindow(t_display, t_parent);
	XCloseDisplay(t_display);
}

////////////////////////////////////////////////////////////////////////////////

int main(int argc, char *argv[])
{
	const char *t_helper = nil;
	const char *t_mode = "all";
	std::string t_work = "/tmp";
	for (int i = 1; i < argc; i++)
	{
		if (strcmp(argv[i], "--helper") == 0 && i + 1 < argc)
			t_helper = argv[++i];
		else if (strcmp(argv[i], "--work") == 0 && i + 1 < argc)
			t_work = argv[++i];
		else
			t_mode = argv[i];
	}
	if (t_helper == nil)
	{
		fprintf(stderr, "usage: webkit-browser-check --helper PATH [--work DIR] [all|missing-helper|backend-cef]\n");
		return 2;
	}

	// A helper that has ended must not end this process
	signal(SIGPIPE, SIG_IGN);

	setenv("OXT_BROWSER_WEBKIT_HELPER", t_helper, 1);
	MCBrowserLibraryInitialize();

	if (strcmp(t_mode, "missing-helper") == 0)
	{
		setenv("OXT_BROWSER_WEBKIT_HELPER", (t_work + "/no-such-helper").c_str(), 1);
		MCBrowserFactoryRef t_factory = nil;
		Check(!MCBrowserFactoryGet(nil, t_factory) && t_factory == nil,
		      "missing helper: there is no browser, and no crash");
	}
	else if (strcmp(t_mode, "backend-cef") == 0)
	{
		setenv("OXT_BROWSER_BACKEND", "cef", 1);
		MCBrowserFactoryRef t_factory = nil;
		Check(!MCBrowserFactoryGet(nil, t_factory) && s_cef_attempts == 1,
		      "OXT_BROWSER_BACKEND=cef: only CEF, so no browser when CEF cannot load");
	}
	else
	{
		CheckWireFormat();
		CheckJSONConversion();
		CheckChoice();
		CheckBrowser(t_work, t_helper);
	}

	MCBrowserLibraryFinalize();

	printf("%d passed, %d failed\n", s_passed, s_failed);
	return s_failed == 0 && s_passed > 0 ? 0 : 1;
}
