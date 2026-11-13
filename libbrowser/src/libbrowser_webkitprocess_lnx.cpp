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

/* libbrowser-webkitprocess: one Linux browser widget (or revBrowser) through
 * WebKitGTK, where CEF cannot load. See libbrowser_webkitgtk.cpp for why it
 * is a process of its own, and libbrowser_webkitgtk_protocol.h for what it
 * says to the engine.
 *
 *   libbrowser-webkitprocess --fd N [--display NAME] [--scale N]
 *   libbrowser-webkitprocess --probe
 *
 * It shows a WebKitWebView in a GtkPlug (X11; the engine's native layer
 * embeds the plug through XEmbed) and talks to the engine on fd N; it ends
 * when that socket closes. --probe only checks that WebKitGTK and GTK 3
 * load, and exits 0 when they do.
 *
 * WebKitGTK 4.1 (libsoup 3), or else 4.0 (libsoup 2), is loaded with dlopen,
 * and GTK 3, GLib and JavaScriptCore through it: the helper is built with no
 * development package of any of them and needs none of them to start, so
 * the package's library check (Installer/linux/libraries.txt) and its glibc
 * floor are unchanged, and a machine without WebKitGTK has no browser, as
 * before. The functions it uses are the same in both, and in every WebKitGTK
 * since 2.22 (2018); their declarations below are those of the headers, with
 * GObject types as void pointers.
 */

#include "libbrowser_webkitgtk_protocol.h"

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#include <string>
#include <vector>

////////////////////////////////////////////////////////////////////////////////
// The libraries' types and functions

typedef int gboolean;
typedef void *gpointer;
typedef char gchar;
typedef unsigned long gulong;
typedef unsigned long XID;
typedef unsigned int GQuark;

struct GError
{
	GQuark domain;
	int code;
	gchar *message;
};

typedef void (*GCallback)(void);
typedef void (*GAsyncReadyCallback)(void *p_source, void *p_result, gpointer p_data);
typedef gboolean (*GIOFunc)(void *p_channel, int p_condition, gpointer p_data);

enum
{
	G_IO_IN = 1,
	G_IO_OUT = 4,
	G_IO_ERR = 8,
	G_IO_HUP = 16,
};

enum
{
	WEBKIT_LOAD_STARTED = 0,
	WEBKIT_LOAD_REDIRECTED = 1,
	WEBKIT_LOAD_COMMITTED = 2,
	WEBKIT_LOAD_FINISHED = 3,
};

enum
{
	WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION = 0,
	WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION = 1,
	WEBKIT_POLICY_DECISION_TYPE_RESPONSE = 2,
};

enum
{
	WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES = 0,
	WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START = 0,
};

// The errors of a load that was stopped or replaced, which CEF does not
// report either (ERR_ABORTED): WEBKIT_NETWORK_ERROR_CANCELLED and
// WEBKIT_POLICY_ERROR_FRAME_LOAD_INTERRUPTED_BY_POLICY_CHANGE
#define MC_WEBKIT_NETWORK_ERROR_CANCELLED 302
#define MC_WEBKIT_POLICY_ERROR_FRAME_LOAD_INTERRUPTED 102

#define MC_WEBKIT_FUNCTIONS(F) \
	/* GLib */ \
	F(void *, g_main_loop_new, (void *context, gboolean is_running)) \
	F(void, g_main_loop_run, (void *loop)) \
	F(void, g_main_loop_quit, (void *loop)) \
	F(void *, g_io_channel_unix_new, (int fd)) \
	F(unsigned int, g_io_add_watch, (void *channel, int condition, GIOFunc func, gpointer data)) \
	F(gboolean, g_source_remove, (unsigned int tag)) \
	F(void, g_free, (gpointer mem)) \
	F(void, g_error_free, (GError *error)) \
	F(gboolean, g_utf8_validate, (const gchar *str, long max_len, const gchar **end)) \
	F(gchar *, g_convert, (const gchar *str, long len, const gchar *to_codeset, const gchar *from_codeset, size_t *bytes_read, size_t *bytes_written, GError **error)) \
	F(GQuark, g_quark_from_string, (const gchar *string)) \
	/* GObject */ \
	F(gulong, g_signal_connect_data, (gpointer instance, const gchar *signal, GCallback handler, gpointer data, void *destroy, int flags)) \
	F(void, g_object_unref, (gpointer object)) \
	/* GTK 3 */ \
	F(unsigned int, gtk_get_major_version, (void)) \
	F(gboolean, gtk_init_check, (int *argc, char ***argv)) \
	F(void *, gtk_plug_new, (XID socket_id)) \
	F(XID, gtk_plug_get_id, (void *plug)) \
	F(void, gtk_container_add, (void *container, void *widget)) \
	F(void, gtk_widget_show_all, (void *widget)) \
	F(void, gtk_widget_set_sensitive, (void *widget, gboolean sensitive)) \
	/* WebKitGTK */ \
	F(void *, webkit_user_content_manager_new, (void)) \
	F(gboolean, webkit_user_content_manager_register_script_message_handler, (void *manager, const gchar *name)) \
	F(void, webkit_user_content_manager_add_script, (void *manager, void *script)) \
	F(void, webkit_user_content_manager_remove_all_scripts, (void *manager)) \
	F(void *, webkit_user_script_new, (const gchar *source, int frames, int time, const gchar *const *allow, const gchar *const *block)) \
	F(void, webkit_user_script_unref, (void *script)) \
	F(void *, webkit_web_view_new_with_user_content_manager, (void *manager)) \
	F(void, webkit_web_view_load_uri, (void *view, const gchar *uri)) \
	F(void, webkit_web_view_load_html, (void *view, const gchar *content, const gchar *base_uri)) \
	F(void, webkit_web_view_go_back, (void *view)) \
	F(void, webkit_web_view_go_forward, (void *view)) \
	F(void, webkit_web_view_reload, (void *view)) \
	F(void, webkit_web_view_stop_loading, (void *view)) \
	F(gboolean, webkit_web_view_can_go_back, (void *view)) \
	F(gboolean, webkit_web_view_can_go_forward, (void *view)) \
	F(const gchar *, webkit_web_view_get_uri, (void *view)) \
	F(gboolean, webkit_web_view_get_tls_info, (void *view, void **certificate, int *errors)) \
	F(void *, webkit_web_view_get_settings, (void *view)) \
	F(void, webkit_settings_set_user_agent, (void *settings, const gchar *user_agent)) \
	F(void, webkit_web_view_run_javascript, (void *view, const gchar *script, void *cancellable, GAsyncReadyCallback callback, gpointer data)) \
	F(void *, webkit_web_view_run_javascript_finish, (void *view, void *result, GError **error)) \
	F(void *, webkit_javascript_result_get_js_value, (void *result)) \
	F(void, webkit_javascript_result_unref, (void *result)) \
	F(void *, webkit_web_view_get_main_resource, (void *view)) \
	F(void, webkit_web_resource_get_data, (void *resource, void *cancellable, GAsyncReadyCallback callback, gpointer data)) \
	F(unsigned char *, webkit_web_resource_get_data_finish, (void *resource, void *result, size_t *length, GError **error)) \
	F(void *, webkit_navigation_policy_decision_get_navigation_action, (void *decision)) \
	F(void *, webkit_navigation_action_get_request, (void *action)) \
	F(const gchar *, webkit_uri_request_get_uri, (void *request)) \
	F(void, webkit_policy_decision_ignore, (void *decision)) \
	/* JavaScriptCore */ \
	F(gchar *, jsc_value_to_string, (void *value))

#define MC_WEBKIT_DECLARE(ret, name, args) typedef ret (*name##_t) args; static name##_t p_##name = nullptr;
MC_WEBKIT_FUNCTIONS(MC_WEBKIT_DECLARE)

static const char *const kMCWebKitLibraries[] =
{
	"libwebkit2gtk-4.1.so.0",
	"libwebkit2gtk-4.0.so.37",
};

// Loads WebKitGTK and finds every function; on failure, why
static bool MCWebKitLoad(std::string &r_error)
{
	void *t_library = nullptr;
	for (size_t i = 0; t_library == nullptr && i < sizeof(kMCWebKitLibraries) / sizeof(kMCWebKitLibraries[0]); i++)
		t_library = dlopen(kMCWebKitLibraries[i], RTLD_NOW | RTLD_GLOBAL);
	if (t_library == nullptr)
	{
		r_error = "WebKitGTK is not installed (libwebkit2gtk-4.1.so.0 or libwebkit2gtk-4.0.so.37)";
		return false;
	}

	// dlsym on the library's handle searches the libraries it needs too:
	// GTK 3, GLib, GObject and JavaScriptCore
#define MC_WEBKIT_RESOLVE(ret, name, args) \
	p_##name = (name##_t)dlsym(t_library, #name); \
	if (p_##name == nullptr) { r_error = "WebKitGTK has no " #name; return false; }
	MC_WEBKIT_FUNCTIONS(MC_WEBKIT_RESOLVE)
#undef MC_WEBKIT_RESOLVE

	if (p_gtk_get_major_version() != 3)
	{
		r_error = "WebKitGTK is not a GTK 3 build";
		return false;
	}
	return true;
}

static void MCSignalConnect(void *p_instance, const char *p_signal, GCallback p_handler, void *p_data = nullptr)
{
	p_g_signal_connect_data(p_instance, p_signal, p_handler, p_data, nullptr, 0);
}

////////////////////////////////////////////////////////////////////////////////
// The connection to the engine

static int s_fd = -1;
static void *s_loop = nullptr;
static MCWebKitGtkProtocol::LineReader s_reader;
static std::string s_outgoing;
static unsigned int s_out_watch = 0;

static void MCQuit()
{
	if (s_loop != nullptr)
		p_g_main_loop_quit(s_loop);
	else
		_exit(0);
}

// Writes what it can of what is waiting, without blocking: the engine may
// be busy sending, and the helper must go on reading, or both would wait
static gboolean MCFlush(void *p_channel = nullptr, int p_condition = 0, gpointer p_data = nullptr)
{
	while (!s_outgoing.empty() && s_fd >= 0)
	{
		ssize_t t_count = write(s_fd, s_outgoing.data(), s_outgoing.size());
		if (t_count > 0)
		{
			s_outgoing.erase(0, t_count);
			continue;
		}
		if (t_count < 0 && errno == EINTR)
			continue;
		if (t_count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
		{
			if (s_out_watch == 0 && s_loop != nullptr)
				s_out_watch = p_g_io_add_watch(p_g_io_channel_unix_new(s_fd), G_IO_OUT, MCFlush, nullptr);
			return 1;
		}
		// The engine has gone
		MCQuit();
		return 0;
	}
	if (s_out_watch != 0 && p_channel != nullptr)
	{
		s_out_watch = 0;
		return 0;
	}
	return 1;
}

static void MCSend(const std::vector<std::string> &p_fields)
{
	s_outgoing += MCWebKitGtkProtocol::Encode(p_fields);
	if (s_out_watch == 0)
		MCFlush();
}

static void MCSend(const char *p_a, const std::string &p_b = std::string(), const std::string &p_c = std::string(), const std::string &p_d = std::string(), int p_count = 0)
{
	std::vector<std::string> t_fields;
	t_fields.push_back(p_a);
	if (p_count >= 2) t_fields.push_back(p_b);
	if (p_count >= 3) t_fields.push_back(p_c);
	if (p_count >= 4) t_fields.push_back(p_d);
	MCSend(t_fields);
}

static void MCReturn(const std::string &p_id, bool p_success, const std::string &p_value = std::string())
{
	MCSend("ret", p_id, p_success ? "1" : "0", p_value, 4);
}

static void MCEvent(const char *p_kind, const std::string &p_url, const std::string &p_error = std::string())
{
	std::vector<std::string> t_fields;
	t_fields.push_back("ev");
	t_fields.push_back(p_kind);
	t_fields.push_back(p_url);
	if (!p_error.empty())
		t_fields.push_back(p_error);
	MCSend(t_fields);
}

////////////////////////////////////////////////////////////////////////////////
// The browser

static void *s_view = nullptr;
static void *s_content_manager = nullptr;
static void *s_plug = nullptr;

// htmlText, as CEF (PageOrigin::kSetSource): its loads send no messages, and
// the URL is empty while it shows. s_source_pending is set by "html" and
// taken by the next load that starts.
static bool s_source_pending = false;
static bool s_showing_source = false;
static std::string s_source_text;

// The load that is running failed: its end sends nothing more
static bool s_load_failed = false;

static bool s_context_menu = true;

static std::string MCCurrentURI()
{
	const char *t_uri = p_webkit_web_view_get_uri(s_view);
	return t_uri != nullptr ? t_uri : "";
}

// <p_text> as a JavaScript string literal
static std::string MCQuoteJS(const std::string &p_text)
{
	std::string t_quoted = "\"";
	for (size_t i = 0; i < p_text.size(); i++)
	{
		unsigned char t_char = (unsigned char)p_text[i];
		switch (t_char)
		{
			case '"': t_quoted += "\\\""; break;
			case '\\': t_quoted += "\\\\"; break;
			case '\n': t_quoted += "\\n"; break;
			case '\r': t_quoted += "\\r"; break;
			case '\t': t_quoted += "\\t"; break;
			default:
				if (t_char < 0x20)
				{
					char t_escape[8];
					snprintf(t_escape, sizeof(t_escape), "\\u%04x", t_char);
					t_quoted += t_escape;
				}
				// U+2028 and U+2029 end a line in older JavaScript
				else if (t_char == 0xE2 && i + 2 < p_text.size() && (unsigned char)p_text[i + 1] == 0x80 &&
				         ((unsigned char)p_text[i + 2] == 0xA8 || (unsigned char)p_text[i + 2] == 0xA9))
				{
					t_quoted += (unsigned char)p_text[i + 2] == 0xA8 ? "\\u2028" : "\\u2029";
					i += 2;
				}
				else
					t_quoted += char(t_char);
				break;
		}
	}
	return t_quoted + "\"";
}

// The liveCode object of the javascriptHandlers: liveCode.<name>(...) posts
// [<name>, [<parameters>]] as JSON to the helper. JSON has no undefined,
// functions or numbers that are not finite; CEF gives those as
// String(value), so they are made that text first.
static std::string MCHandlersScript(const std::string &p_names)
{
	std::string t_array = "[";
	size_t t_start = 0;
	bool t_first = true;
	while (!p_names.empty() && t_start <= p_names.size())
	{
		size_t t_end = p_names.find('\n', t_start);
		if (t_end == std::string::npos)
			t_end = p_names.size();
		std::string t_name = p_names.substr(t_start, t_end - t_start);
		if (!t_name.empty())
		{
			t_array += (t_first ? "" : ",") + MCQuoteJS(t_name);
			t_first = false;
		}
		t_start = t_end + 1;
	}
	t_array += "]";

	if (t_first)
		return "try { delete window.liveCode; } catch (e) {}";

	return
		"(function (names) {\n"
		"  var value = function (key, v) {\n"
		"    var type = typeof v;\n"
		"    if (type === 'undefined' || type === 'function' || type === 'symbol' || type === 'bigint' ||\n"
		"        (type === 'number' && !isFinite(v)))\n"
		"      return String(v);\n"
		"    return v;\n"
		"  };\n"
		"  var handler = function (name) {\n"
		"    return function () {\n"
		"      var params = Array.prototype.slice.call(arguments);\n"
		"      try {\n"
		"        window.webkit.messageHandlers.livecode.postMessage(JSON.stringify([name, params], value));\n"
		"      } catch (e) {}\n"
		"    };\n"
		"  };\n"
		"  var object = {};\n"
		"  for (var i = 0; i < names.length; i++)\n"
		"    object[names[i]] = handler(names[i]);\n"
		"  try {\n"
		"    Object.defineProperty(window, 'liveCode', { value: object, writable: false, configurable: true });\n"
		"  } catch (e) {}\n"
		"})(" + t_array + ");";
}

////////
// Signals of the web view

static void MCOnLoadChanged(void *p_view, int p_event, gpointer p_data)
{
	if (p_event == WEBKIT_LOAD_STARTED)
	{
		s_showing_source = s_source_pending;
		s_source_pending = false;
		s_load_failed = false;
		if (s_showing_source)
			return;
		std::string t_url = MCCurrentURI();
		MCEvent("navigateBegin", t_url);
		MCEvent("documentLoadBegin", t_url);
	}
	else if (p_event == WEBKIT_LOAD_FINISHED)
	{
		if (s_showing_source || s_load_failed)
			return;
		std::string t_url = MCCurrentURI();
		MCEvent("documentLoadComplete", t_url);
		MCEvent("navigateComplete", t_url);
	}
}

static gboolean MCOnLoadFailed(void *p_view, int p_event, const gchar *p_uri, GError *p_error, gpointer p_data)
{
	if (p_error != nullptr &&
	    ((p_error->domain == p_g_quark_from_string("WebKitNetworkError") && p_error->code == MC_WEBKIT_NETWORK_ERROR_CANCELLED) ||
	     (p_error->domain == p_g_quark_from_string("WebKitPolicyError") && p_error->code == MC_WEBKIT_POLICY_ERROR_FRAME_LOAD_INTERRUPTED)))
	{
		// Stopped, or replaced by another load: CEF sends nothing either
		// (ERR_ABORTED), and the page that replaces it sends its own
		s_load_failed = true;
		return 0;
	}

	s_load_failed = true;
	if (s_showing_source)
		return 0;

	std::string t_url = p_uri != nullptr ? p_uri : MCCurrentURI();
	std::string t_error = p_error != nullptr && p_error->message != nullptr ? p_error->message : "load failed";
	MCEvent("documentLoadFailed", t_url, t_error);
	MCEvent("navigateFailed", t_url, t_error);

	// WebKitGTK's own error page is not shown, as CEF shows none
	return 1;
}

// The URL schemes WebKitGTK loads itself; any other is the script's
// (browserUnhandledLoadRequest), as CEF's ERR_UNKNOWN_URL_SCHEME
static bool MCIsKnownScheme(const char *p_uri)
{
	static const char *const kSchemes[] = { "http:", "https:", "file:", "data:", "about:", "blob:", "javascript:" };
	for (size_t i = 0; i < sizeof(kSchemes) / sizeof(kSchemes[0]); i++)
		if (strncasecmp(p_uri, kSchemes[i], strlen(kSchemes[i])) == 0)
			return true;
	return false;
}

static gboolean MCOnDecidePolicy(void *p_view, void *p_decision, int p_type, gpointer p_data)
{
	if (p_type == WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION)
	{
		// A window of its own is not something the widget can show: CEF
		// makes such a browser windowless, where nothing shows it either
		p_webkit_policy_decision_ignore(p_decision);
		return 1;
	}
	if (p_type != WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION)
		return 0;

	void *t_action = p_webkit_navigation_policy_decision_get_navigation_action(p_decision);
	void *t_request = t_action != nullptr ? p_webkit_navigation_action_get_request(t_action) : nullptr;
	const char *t_uri = t_request != nullptr ? p_webkit_uri_request_get_uri(t_request) : nullptr;
	if (t_uri == nullptr || MCIsKnownScheme(t_uri))
		return 0;

	p_webkit_policy_decision_ignore(p_decision);
	MCEvent("unhandled", t_uri);
	return 1;
}

static void *MCOnCreate(void *p_view, void *p_action, gpointer p_data)
{
	return nullptr;
}

static gboolean MCOnContextMenu(void *p_view, void *p_menu, void *p_event, void *p_hit, gpointer p_data)
{
	// TRUE: no menu
	return s_context_menu ? 0 : 1;
}

static void MCOnScriptMessage(void *p_manager, void *p_result, gpointer p_data)
{
	void *t_value = p_webkit_javascript_result_get_js_value(p_result);
	gchar *t_json = t_value != nullptr ? p_jsc_value_to_string(t_value) : nullptr;
	if (t_json != nullptr)
	{
		MCSend("js", t_json, std::string(), std::string(), 2);
		p_g_free(t_json);
	}
}

////////
// Calls that answer later

struct MCPendingCall
{
	std::string id;
};

static void MCOnJavaScriptDone(void *p_view, void *p_result, gpointer p_data)
{
	MCPendingCall *t_call = (MCPendingCall *)p_data;
	GError *t_error = nullptr;
	void *t_result = p_webkit_web_view_run_javascript_finish(p_view, p_result, &t_error);
	if (t_result == nullptr)
		MCReturn(t_call->id, false, t_error != nullptr && t_error->message != nullptr ? t_error->message : "");
	else
	{
		gchar *t_text = p_jsc_value_to_string(p_webkit_javascript_result_get_js_value(t_result));
		MCReturn(t_call->id, t_text != nullptr, t_text != nullptr ? t_text : "");
		if (t_text != nullptr)
			p_g_free(t_text);
		p_webkit_javascript_result_unref(t_result);
	}
	delete t_call;
}

static void MCEvaluate(const std::string &p_id, const std::string &p_script)
{
	// As CEF: the value of the script's last statement, as String(value),
	// which any value has (WebKitGTK cannot hand back a DOM node or a
	// function itself). A direct eval at the top level runs the script in
	// the page's global scope, as CEF's.
	std::string t_script = "String(eval(" + MCQuoteJS(p_script) + "))";
	MCPendingCall *t_call = new MCPendingCall;
	t_call->id = p_id;
	p_webkit_web_view_run_javascript(s_view, t_script.c_str(), nullptr, MCOnJavaScriptDone, t_call);
}

// The main resource's bytes, waiting on the document's encoding
struct MCPendingSource
{
	std::string id;
	std::string bytes;
};

static void MCReturnDocumentHTML(const std::string &p_id)
{
	// The document as the page has it now
	MCEvaluate(p_id, "document.documentElement ? document.documentElement.outerHTML : ''");
}

// As CEF (GetSource): the source as text, which the engine takes as UTF-8
// (browser.lcb), whatever the page's own encoding. Without a byte order
// mark, as CEF's decoded text has none.
static void MCReturnSource(const std::string &p_id, const std::string &p_bytes, const std::string &p_charset)
{
	std::string t_text;
	bool t_utf8 = p_charset.empty() || strcasecmp(p_charset.c_str(), "UTF-8") == 0;
	if (t_utf8)
		t_text = p_bytes;
	else
	{
		size_t t_written = 0;
		GError *t_error = nullptr;
		gchar *t_converted = p_g_convert(p_bytes.data(), (long)p_bytes.size(), "UTF-8", p_charset.c_str(),
		                                 nullptr, &t_written, &t_error);
		if (t_error != nullptr)
			p_g_error_free(t_error);
		if (t_converted == nullptr)
		{
			// An encoding iconv does not know: the page's own HTML instead
			MCReturnDocumentHTML(p_id);
			return;
		}
		t_text.assign(t_converted, t_written);
		p_g_free(t_converted);
	}
	if (t_text.compare(0, 3, "\xef\xbb\xbf") == 0)
		t_text.erase(0, 3);
	// Bytes the encoding named do not decode: the page's own HTML instead,
	// never text the engine cannot read
	if (!p_g_utf8_validate(t_text.data(), (long)t_text.size(), nullptr))
	{
		MCReturnDocumentHTML(p_id);
		return;
	}
	MCReturn(p_id, true, t_text);
}

static void MCOnCharsetDone(void *p_view, void *p_result, gpointer p_data)
{
	MCPendingSource *t_source = (MCPendingSource *)p_data;
	GError *t_error = nullptr;
	void *t_result = p_webkit_web_view_run_javascript_finish(p_view, p_result, &t_error);
	std::string t_charset;
	if (t_result != nullptr)
	{
		gchar *t_text = p_jsc_value_to_string(p_webkit_javascript_result_get_js_value(t_result));
		if (t_text != nullptr)
		{
			t_charset = t_text;
			p_g_free(t_text);
		}
		p_webkit_javascript_result_unref(t_result);
	}
	if (t_error != nullptr)
		p_g_error_free(t_error);
	MCReturnSource(t_source->id, t_source->bytes, t_charset);
	delete t_source;
}

static void MCOnSourceDone(void *p_resource, void *p_result, gpointer p_data)
{
	MCPendingCall *t_call = (MCPendingCall *)p_data;
	size_t t_length = 0;
	GError *t_error = nullptr;
	unsigned char *t_data = p_webkit_web_resource_get_data_finish(p_resource, p_result, &t_length, &t_error);
	if (t_error != nullptr)
		p_g_error_free(t_error);
	if (t_data != nullptr)
	{
		// The bytes as the server sent them: the document knows how to
		// read them (its meta charset, the server's header, a byte order
		// mark)
		MCPendingSource *t_source = new MCPendingSource;
		t_source->id = t_call->id;
		t_source->bytes.assign((const char *)t_data, t_length);
		p_g_free(t_data);
		p_webkit_web_view_run_javascript(s_view, "document.characterSet", nullptr, MCOnCharsetDone, t_source);
	}
	else
		MCReturnDocumentHTML(t_call->id);
	delete t_call;
}

static void MCGetSource(const std::string &p_id)
{
	// As CEF (GetSource): the page's source; for htmlText, the text
	if (s_showing_source)
	{
		MCReturn(p_id, true, s_source_text);
		return;
	}
	void *t_resource = p_webkit_web_view_get_main_resource(s_view);
	if (t_resource == nullptr)
	{
		MCReturn(p_id, true, "");
		return;
	}
	MCPendingCall *t_call = new MCPendingCall;
	t_call->id = p_id;
	p_webkit_web_resource_get_data(t_resource, nullptr, MCOnSourceDone, t_call);
}

////////
// The engine's messages

static void MCHandleMessage(const std::vector<std::string> &p_fields)
{
	const std::string &t_verb = p_fields[0];
	std::string t_id = p_fields.size() > 1 ? p_fields[1] : std::string();
	const std::string t_empty;
	const std::string &t_arg1 = p_fields.size() > 2 ? p_fields[2] : t_empty;
	const std::string &t_arg2 = p_fields.size() > 3 ? p_fields[3] : t_empty;

	if (t_verb == "go")
	{
		s_source_pending = false;
		p_webkit_web_view_load_uri(s_view, t_arg1.c_str());
		MCReturn(t_id, true);
	}
	else if (t_verb == "html")
	{
		s_source_pending = true;
		s_source_text = t_arg1;
		p_webkit_web_view_load_html(s_view, t_arg1.c_str(), t_arg2.c_str());
		MCReturn(t_id, true);
	}
	else if (t_verb == "back" || t_verb == "forward" || t_verb == "reload" || t_verb == "stop")
	{
		s_source_pending = false;
		if (t_verb == "back")
			p_webkit_web_view_go_back(s_view);
		else if (t_verb == "forward")
			p_webkit_web_view_go_forward(s_view);
		else if (t_verb == "reload")
		{
			// Reloading htmlText reloads htmlText
			s_source_pending = s_showing_source;
			p_webkit_web_view_reload(s_view);
		}
		else
			p_webkit_web_view_stop_loading(s_view);
		MCReturn(t_id, true);
	}
	else if (t_verb == "eval")
		MCEvaluate(t_id, t_arg1);
	else if (t_verb == "handlers")
	{
		std::string t_script = MCHandlersScript(t_arg1);
		p_webkit_user_content_manager_remove_all_scripts(s_content_manager);
		void *t_user_script = p_webkit_user_script_new(t_script.c_str(), WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES,
		                                               WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, nullptr, nullptr);
		p_webkit_user_content_manager_add_script(s_content_manager, t_user_script);
		p_webkit_user_script_unref(t_user_script);
		// The page that shows now gets them too, as with CEF
		MCEvaluate(t_id, t_script);
	}
	else if (t_verb == "useragent")
	{
		// Empty: WebKitGTK's own
		p_webkit_settings_set_user_agent(p_webkit_web_view_get_settings(s_view), t_arg1.empty() ? nullptr : t_arg1.c_str());
		MCReturn(t_id, true);
	}
	else if (t_verb == "set")
	{
		bool t_value = t_arg2 == "1";
		if (t_arg1 == "contextmenu")
			s_context_menu = t_value;
		else if (t_arg1 == "interaction")
			p_gtk_widget_set_sensitive(s_view, t_value);
		// "newwindows": a page's new windows are never shown (MCOnDecidePolicy)
		MCReturn(t_id, true);
	}
	else if (t_verb == "get")
	{
		if (t_arg1 == "url")
			MCReturn(t_id, true, s_showing_source ? std::string() : MCCurrentURI());
		else if (t_arg1 == "source")
			MCGetSource(t_id);
		else if (t_arg1 == "canback")
			MCReturn(t_id, true, p_webkit_web_view_can_go_back(s_view) ? "1" : "0");
		else if (t_arg1 == "canforward")
			MCReturn(t_id, true, p_webkit_web_view_can_go_forward(s_view) ? "1" : "0");
		else if (t_arg1 == "secure")
		{
			void *t_certificate = nullptr;
			int t_errors = 0;
			bool t_secure = p_webkit_web_view_get_tls_info(s_view, &t_certificate, &t_errors) && t_errors == 0;
			MCReturn(t_id, true, t_secure ? "1" : "0");
		}
		else
			MCReturn(t_id, false);
	}
	else if (t_verb == "quit")
		MCQuit();
	else
		MCReturn(t_id, false);
}

static gboolean MCOnInput(void *p_channel, int p_condition, gpointer p_data)
{
	char t_buffer[16384];
	for (;;)
	{
		ssize_t t_count = read(s_fd, t_buffer, sizeof(t_buffer));
		if (t_count > 0)
		{
			s_reader.Append(t_buffer, t_count);
			continue;
		}
		if (t_count < 0 && errno == EINTR)
			continue;
		if (t_count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
			break;
		// The engine closed its end, or ended: so does the helper
		MCQuit();
		return 0;
	}

	std::string t_line;
	while (s_reader.Next(t_line))
	{
		std::vector<std::string> t_fields;
		if (MCWebKitGtkProtocol::Decode(t_line, t_fields) && !t_fields.empty())
			MCHandleMessage(t_fields);
	}
	return 1;
}

////////////////////////////////////////////////////////////////////////////////

int main(int argc, char *argv[])
{
	bool t_probe = false;
	int t_fd = -1;
	const char *t_display = nullptr;
	int t_scale = 0;
	for (int i = 1; i < argc; i++)
	{
		if (strcmp(argv[i], "--probe") == 0)
			t_probe = true;
		else if (strcmp(argv[i], "--fd") == 0 && i + 1 < argc)
			t_fd = atoi(argv[++i]);
		else if (strcmp(argv[i], "--display") == 0 && i + 1 < argc)
			t_display = argv[++i];
		else if (strcmp(argv[i], "--scale") == 0 && i + 1 < argc)
			t_scale = atoi(argv[++i]);
	}

	std::string t_error;
	if (t_probe)
	{
		bool t_loaded = MCWebKitLoad(t_error);
		if (!t_loaded)
			fprintf(stderr, "libbrowser-webkitprocess: %s\n", t_error.c_str());
		return t_loaded ? 0 : 1;
	}

	if (t_fd < 0)
	{
		fprintf(stderr, "usage: libbrowser-webkitprocess --fd N [--display NAME] [--scale N] | --probe\n");
		return 2;
	}
	s_fd = t_fd;
	signal(SIGPIPE, SIG_IGN);
	fcntl(s_fd, F_SETFD, FD_CLOEXEC);

	// The engine's screen, through X11: the plug is an X window, and XEmbed
	// is X11's
	setenv("GDK_BACKEND", "x11", 1);
	if (t_display != nullptr)
		setenv("DISPLAY", t_display, 1);
	if (t_scale > 1)
	{
		char t_scale_text[16];
		snprintf(t_scale_text, sizeof(t_scale_text), "%d", t_scale);
		setenv("GDK_SCALE", t_scale_text, 1);
	}

	if (!MCWebKitLoad(t_error))
	{
		MCSend("fail", t_error, std::string(), std::string(), 2);
		return 1;
	}
	if (!p_gtk_init_check(nullptr, nullptr))
	{
		MCSend("fail", "GTK 3 cannot open the display", std::string(), std::string(), 2);
		return 1;
	}

	s_content_manager = p_webkit_user_content_manager_new();
	MCSignalConnect(s_content_manager, "script-message-received::livecode", (GCallback)MCOnScriptMessage);
	p_webkit_user_content_manager_register_script_message_handler(s_content_manager, "livecode");

	s_view = p_webkit_web_view_new_with_user_content_manager(s_content_manager);
	MCSignalConnect(s_view, "load-changed", (GCallback)MCOnLoadChanged);
	MCSignalConnect(s_view, "load-failed", (GCallback)MCOnLoadFailed);
	MCSignalConnect(s_view, "decide-policy", (GCallback)MCOnDecidePolicy);
	MCSignalConnect(s_view, "create", (GCallback)MCOnCreate);
	MCSignalConnect(s_view, "context-menu", (GCallback)MCOnContextMenu);

	s_plug = p_gtk_plug_new(0);
	p_gtk_container_add(s_plug, s_view);
	p_gtk_widget_show_all(s_plug);

	s_loop = p_g_main_loop_new(nullptr, 0);
	fcntl(s_fd, F_SETFL, fcntl(s_fd, F_GETFL) | O_NONBLOCK);
	p_g_io_add_watch(p_g_io_channel_unix_new(s_fd), G_IO_IN | G_IO_HUP | G_IO_ERR, MCOnInput, nullptr);

	MCSend("ready", std::to_string(p_gtk_plug_get_id(s_plug)), std::string(), std::string(), 2);

	p_g_main_loop_run(s_loop);

	// Nothing is saved: WebKitGTK's own processes end with this one
	_exit(0);
}
