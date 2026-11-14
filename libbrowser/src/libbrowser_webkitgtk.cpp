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

/* OXT-Beyond: the browser widget's and revBrowser's browser on Linux where
 * CEF cannot load: WebKitGTK.
 *
 * CEF stays the browser wherever it loads; it comes first in the factory
 * list (libbrowser_lnx_factories.cpp), and the default browser is the first
 * one that loads (MCBrowserFactoryGet). CEF does not load where the package
 * has no Externals/CEF/libcef.so (Linux arm64 and x86, whose packages
 * carry no CEF), or where a library it needs is missing: there, until now, there
 * was no browser at all.
 *
 * The engine is a GTK 2 program, and WebKitGTK 4.0 and 4.1 are GTK 3
 * libraries; GTK refuses to start with both in one process. So each browser
 * is a WebKitWebView in a GtkPlug of a helper process of its own
 * (libbrowser-webkitprocess, next to the engine;
 * libbrowser_webkitprocess_lnx.cpp), whose window the engine's native layer
 * embeds through XEmbed (MCNativeLayerX11, gtk_socket_add_id), as it embeds
 * CEF's. The browser here talks to it over a socket
 * (libbrowser_webkitgtk_protocol.h). The helper loads WebKitGTK with dlopen,
 * so neither the engine nor the helper needs it to start: without it (or
 * without the helper) this factory does not load, and there is no browser,
 * as before.
 *
 * What a script sees is what CEF gives it: the same messages for the same
 * loads (none for htmlText, whose URL is empty), the result of JavaScript as
 * String(result), the javascriptHandlers' parameters with the same types,
 * the scroll bars as the body's overflow style, and an unknown URL scheme
 * as an unhandled request. The messages from the helper are handed to the
 * widget from libbrowser's runloop action, which the engine runs from its
 * event loop, never from inside a call into the browser.
 */

#include <core.h>

#include "libbrowser_internal.h"
#include "libbrowser_webkitgtk_protocol.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include <X11/Xlib.h>

#include <deque>
#include <string>
#include <vector>

extern char **environ;

////////////////////////////////////////////////////////////////////////////////

// CEF's base URL for htmlText (CEF_DUMMY_URL, libbrowser_cef.cpp): a page's
// relative URLs resolve against the same base with either browser
#define MC_WEBKITGTK_HTMLTEXT_BASE_URL "http://libbrowser_dummy_url/"

// The helper's name, next to the engine (the IDE's, a standalone's)
#define MC_WEBKITGTK_HELPER_NAME "libbrowser-webkitprocess"

// How long to wait for the helper: to start and show its first page (a cold
// WebKitGTK takes a second or two), and to answer a call that waits for it
#define MC_WEBKITGTK_START_TIMEOUT 30.0
#define MC_WEBKITGTK_CALL_TIMEOUT 30.0

// OXT-Beyond: [[ HiDPI ]] The engine's scale from points to the screen's
// pixels (lnxdc.cpp), weak so that a program without the engine's display
// code (the server engine, the check) still links: the helper's GDK_SCALE.
extern "C" double MCLinuxGetBrowserDeviceScale(void) __attribute__((weak));

static double MCWebKitGtkNow()
{
	struct timespec t_now;
	clock_gettime(CLOCK_MONOTONIC, &t_now);
	return t_now.tv_sec + t_now.tv_nsec / 1e9;
}

// OXT_BROWSER_WEBKIT_HELPER, or the helper next to the running program
static bool MCWebKitGtkGetHelperPath(std::string &r_path)
{
	const char *t_override = getenv("OXT_BROWSER_WEBKIT_HELPER");
	if (t_override != nil && *t_override != '\0')
	{
		r_path = t_override;
		return true;
	}

	char t_exe[PATH_MAX];
	ssize_t t_length = readlink("/proc/self/exe", t_exe, sizeof(t_exe) - 1);
	if (t_length <= 0)
		return false;
	t_exe[t_length] = '\0';

	char *t_slash = strrchr(t_exe, '/');
	if (t_slash == nil)
		return false;
	*t_slash = '\0';

	r_path = std::string(t_exe) + "/" MC_WEBKITGTK_HELPER_NAME;
	return true;
}

// Waits for <p_pid> to end, for up to <p_seconds>, then ends it: the
// engine's SIGCHLD handler waits only for the processes it started itself
// (MCS_handlechildexits), so the helper is this file's to wait for
static void MCWebKitGtkReap(pid_t p_pid, double p_seconds)
{
	if (p_pid <= 0)
		return;

	double t_end = MCWebKitGtkNow() + p_seconds;
	for (;;)
	{
		pid_t t_result = waitpid(p_pid, nil, WNOHANG);
		if (t_result == p_pid || (t_result < 0 && errno != EINTR))
			return;
		if (MCWebKitGtkNow() >= t_end)
			break;
		usleep(10000);
	}

	kill(p_pid, SIGKILL);
	while (waitpid(p_pid, nil, 0) < 0 && errno == EINTR)
		;
}

// Starts the helper with <p_args>, its end of a socket as its fd 3
static bool MCWebKitGtkSpawnHelper(const std::string &p_helper, const std::vector<std::string> &p_args, int &r_fd, pid_t &r_pid)
{
	int t_sockets[2];
	if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, t_sockets) != 0)
		return false;

	// The helper's end must not be fd 3 itself, or dup2 would leave its
	// close-on-exec flag set
	if (t_sockets[1] == 3)
	{
		int t_moved = fcntl(t_sockets[1], F_DUPFD_CLOEXEC, 10);
		close(t_sockets[1]);
		if (t_moved < 0)
		{
			close(t_sockets[0]);
			return false;
		}
		t_sockets[1] = t_moved;
	}

	std::vector<char *> t_argv;
	t_argv.push_back(const_cast<char *>(p_helper.c_str()));
	for (size_t i = 0; i < p_args.size(); i++)
		t_argv.push_back(const_cast<char *>(p_args[i].c_str()));
	t_argv.push_back(nil);

	posix_spawn_file_actions_t t_actions;
	posix_spawn_file_actions_init(&t_actions);
	posix_spawn_file_actions_adddup2(&t_actions, t_sockets[1], 3);
	
	// The helper starts with no signal blocked and every signal's default
	// action, whatever the engine set for its own: GLib and WebKitGTK wait
	// for processes of their own (SIGCHLD)
	posix_spawnattr_t t_attributes;
	posix_spawnattr_init(&t_attributes);
	sigset_t t_none, t_all;
	sigemptyset(&t_none);
	sigfillset(&t_all);
	sigdelset(&t_all, SIGKILL);
	sigdelset(&t_all, SIGSTOP);
	posix_spawnattr_setsigmask(&t_attributes, &t_none);
	posix_spawnattr_setsigdefault(&t_attributes, &t_all);
	posix_spawnattr_setflags(&t_attributes, POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF);
	
	pid_t t_pid = 0;
	int t_error = posix_spawn(&t_pid, p_helper.c_str(), &t_actions, &t_attributes, t_argv.data(), environ);
	posix_spawnattr_destroy(&t_attributes);
	posix_spawn_file_actions_destroy(&t_actions);
	close(t_sockets[1]);

	if (t_error != 0)
	{
		close(t_sockets[0]);
		return false;
	}

	r_fd = t_sockets[0];
	r_pid = t_pid;
	return true;
}

////////////////////////////////////////////////////////////////////////////////

class MCWebKitGtkBrowser;
static std::vector<MCWebKitGtkBrowser *> s_webkitgtk_browsers;

class MCWebKitGtkBrowser : public MCBrowserBase
{
public:
	MCWebKitGtkBrowser()
		: m_fd(-1), m_pid(0), m_xid(0), m_next_id(1),
		  m_allow_new_windows(false), m_enable_context_menu(true), m_allow_user_interaction(true)
	{
		s_webkitgtk_browsers.push_back(this);
	}

	virtual ~MCWebKitGtkBrowser()
	{
		for (size_t i = 0; i < s_webkitgtk_browsers.size(); i++)
			if (s_webkitgtk_browsers[i] == this)
			{
				s_webkitgtk_browsers.erase(s_webkitgtk_browsers.begin() + i);
				break;
			}

		if (m_fd >= 0)
		{
			// The helper ends when its socket closes, whether or not it
			// read the quit
			Send("quit");
			close(m_fd);
			m_fd = -1;
		}
		MCWebKitGtkReap(m_pid, 5.0);
	}

	bool Init(const std::string &p_helper, Display *p_display)
	{
		std::vector<std::string> t_args;
		t_args.push_back("--fd");
		t_args.push_back("3");
		if (p_display != nil && DisplayString(p_display) != nil)
		{
			// The engine's own screen, whatever DISPLAY says now
			t_args.push_back("--display");
			t_args.push_back(DisplayString(p_display));
		}
		if (MCLinuxGetBrowserDeviceScale != nullptr && getenv("GDK_SCALE") == nil)
		{
			// [[ HiDPI ]] GDK scales by whole numbers only
			int t_scale = int(MCLinuxGetBrowserDeviceScale() + 0.5);
			if (t_scale > 1)
			{
				t_args.push_back("--scale");
				t_args.push_back(std::to_string(t_scale));
			}
		}

		if (!MCWebKitGtkSpawnHelper(p_helper, t_args, m_fd, m_pid))
			return false;

		fcntl(m_fd, F_SETFL, fcntl(m_fd, F_GETFL) | O_NONBLOCK);

		// The helper's first line: its window, or why it cannot run
		double t_end = MCWebKitGtkNow() + MC_WEBKITGTK_START_TIMEOUT;
		for (;;)
		{
			std::vector<std::string> t_fields;
			if (!ReadMessage(t_fields, t_end))
				return false;
			if (t_fields[0] == "ready" && t_fields.size() >= 2)
			{
				m_xid = strtoul(t_fields[1].c_str(), nil, 10);
				return m_xid != 0;
			}
			if (t_fields[0] == "fail")
				return false;
		}
	}

	// The messages the helper sent: read what is there, then hand each on
	void Poll()
	{
		std::vector<std::string> t_fields;
		while (ReadMessage(t_fields, 0.0))
			m_queue.push_back(t_fields);

		while (!m_queue.empty())
		{
			std::vector<std::string> t_message;
			t_message.swap(m_queue.front());
			m_queue.pop_front();
			Dispatch(t_message);
		}
	}

	////////

	virtual void *GetNativeLayer()
	{
		return (void *)(uintptr_t)m_xid;
	}

	// The native layer places and sizes the browser's window, as CEF's
	virtual bool GetRect(MCBrowserRect &r_rect)
	{
		return false;
	}

	virtual bool SetRect(const MCBrowserRect &p_rect)
	{
		return false;
	}

	virtual bool GetBoolProperty(MCBrowserProperty p_property, bool &r_value)
	{
		switch (p_property)
		{
			case kMCBrowserAllowNewWindows:
				r_value = m_allow_new_windows;
				return true;
			case kMCBrowserEnableContextMenu:
				r_value = m_enable_context_menu;
				return true;
			case kMCBrowserAllowUserInteraction:
				r_value = m_allow_user_interaction;
				return true;
			case kMCBrowserVerticalScrollbarEnabled:
				r_value = !GetOverflowHidden("document.body.style.overflowY");
				return true;
			case kMCBrowserHorizontalScrollbarEnabled:
				r_value = !GetOverflowHidden("document.body.style.overflowX");
				return true;
			case kMCBrowserIsSecure:
				r_value = CallFor("get", "secure") == "1";
				return true;
			case kMCBrowserCanGoBack:
				r_value = CallFor("get", "canback") == "1";
				return true;
			case kMCBrowserCanGoForward:
				r_value = CallFor("get", "canforward") == "1";
				return true;
			default:
				return true;
		}
	}

	virtual bool SetBoolProperty(MCBrowserProperty p_property, bool p_value)
	{
		switch (p_property)
		{
			case kMCBrowserAllowNewWindows:
				m_allow_new_windows = p_value;
				Send("set", "newwindows", p_value ? "1" : "0");
				return true;
			case kMCBrowserEnableContextMenu:
				m_enable_context_menu = p_value;
				Send("set", "contextmenu", p_value ? "1" : "0");
				return true;
			case kMCBrowserAllowUserInteraction:
				m_allow_user_interaction = p_value;
				Send("set", "interaction", p_value ? "1" : "0");
				return true;
			case kMCBrowserVerticalScrollbarEnabled:
				SetOverflowHidden("document.body.style.overflowY", !p_value);
				return true;
			case kMCBrowserHorizontalScrollbarEnabled:
				SetOverflowHidden("document.body.style.overflowX", !p_value);
				return true;
			default:
				return true;
		}
	}

	virtual bool GetStringProperty(MCBrowserProperty p_property, char *&r_utf8_string)
	{
		std::string t_value;
		switch (p_property)
		{
			case kMCBrowserURL:
				t_value = CallFor("get", "url");
				break;
			case kMCBrowserHTMLText:
				t_value = CallFor("get", "source");
				break;
			case kMCBrowserUserAgent:
				// As CEF: the one the script set, empty for the browser's own
				t_value = m_user_agent;
				break;
			case kMCBrowserJavaScriptHandlers:
				t_value = m_javascript_handlers;
				break;
			default:
				break;
		}
		return MCCStringClone(t_value.c_str(), r_utf8_string);
	}

	virtual bool SetStringProperty(MCBrowserProperty p_property, const char *p_utf8_string)
	{
		const char *t_value = p_utf8_string != nil ? p_utf8_string : "";
		switch (p_property)
		{
			case kMCBrowserHTMLText:
				return LoadHTMLText(t_value, MC_WEBKITGTK_HTMLTEXT_BASE_URL);
			case kMCBrowserJavaScriptHandlers:
				m_javascript_handlers = t_value;
				return Send("handlers", t_value);
			case kMCBrowserUserAgent:
				m_user_agent = t_value;
				return Send("useragent", t_value);
			default:
				return true;
		}
	}

	virtual bool GetIntegerProperty(MCBrowserProperty p_property, int32_t &r_value)
	{
		return true;
	}

	virtual bool SetIntegerProperty(MCBrowserProperty p_property, int32_t p_value)
	{
		return true;
	}

	virtual bool GoBack()
	{
		return Send("back");
	}

	virtual bool GoForward()
	{
		return Send("forward");
	}

	virtual bool GoToURL(const char *p_url)
	{
		return Send("go", p_url != nil ? p_url : "");
	}

	virtual bool LoadHTMLText(const char *p_htmltext, const char *p_base_url)
	{
		// As CEF (Bug 12701): an empty page for empty text
		if (p_htmltext == nil || *p_htmltext == '\0')
			p_htmltext = "<html><head></head><body></body></html>";
		return Send("html", p_htmltext, p_base_url != nil ? p_base_url : MC_WEBKITGTK_HTMLTEXT_BASE_URL);
	}

	virtual bool StopLoading()
	{
		return Send("stop");
	}

	virtual bool Reload()
	{
		return Send("reload");
	}

	virtual bool EvaluateJavaScript(const char *p_script, char *&r_result)
	{
		std::string t_result;
		if (!Call("eval", p_script != nil ? p_script : "", nil, t_result))
			return false;
		return MCCStringClone(t_result.c_str(), r_result);
	}

private:
	int m_fd;
	pid_t m_pid;
	unsigned long m_xid;
	uint32_t m_next_id;

	MCWebKitGtkProtocol::LineReader m_reader;
	// Messages read while waiting for an answer, handed on by Poll
	std::deque<std::vector<std::string> > m_queue;

	bool m_allow_new_windows;
	bool m_enable_context_menu;
	bool m_allow_user_interaction;
	std::string m_user_agent;
	std::string m_javascript_handlers;

	////////

	// Sends <p_verb> with the next id; the id, for a caller that waits
	bool SendWithId(const char *p_verb, const char *p_arg1, const char *p_arg2, uint32_t &r_id)
	{
		if (m_fd < 0)
			return false;

		std::vector<std::string> t_fields;
		t_fields.push_back(p_verb);
		r_id = m_next_id++;
		t_fields.push_back(std::to_string(r_id));
		if (p_arg1 != nil)
			t_fields.push_back(p_arg1);
		if (p_arg2 != nil)
			t_fields.push_back(p_arg2);

		std::string t_line = MCWebKitGtkProtocol::Encode(t_fields);
		size_t t_sent = 0;
		while (t_sent < t_line.size())
		{
			ssize_t t_count = send(m_fd, t_line.data() + t_sent, t_line.size() - t_sent, MSG_NOSIGNAL);
			if (t_count > 0)
			{
				t_sent += t_count;
				continue;
			}
			if (t_count < 0 && errno == EINTR)
				continue;
			if (t_count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
			{
				struct pollfd t_poll = { m_fd, POLLOUT, 0 };
				poll(&t_poll, 1, 1000);
				continue;
			}
			return false;
		}
		return true;
	}

	bool Send(const char *p_verb, const char *p_arg1 = nil, const char *p_arg2 = nil)
	{
		uint32_t t_id;
		return SendWithId(p_verb, p_arg1, p_arg2, t_id);
	}

	// Sends <p_verb> and waits for its answer
	bool Call(const char *p_verb, const char *p_arg1, const char *p_arg2, std::string &r_value)
	{
		uint32_t t_id;
		if (!SendWithId(p_verb, p_arg1, p_arg2, t_id))
			return false;

		std::string t_id_text = std::to_string(t_id);
		double t_end = MCWebKitGtkNow() + MC_WEBKITGTK_CALL_TIMEOUT;
		std::vector<std::string> t_fields;
		while (ReadMessage(t_fields, t_end))
		{
			if (t_fields[0] == "ret" && t_fields.size() >= 3)
			{
				// The answers to calls nobody waits for are dropped
				if (t_fields[1] != t_id_text)
					continue;
				r_value = t_fields.size() >= 4 ? t_fields[3] : std::string();
				return t_fields[2] == "1";
			}
			m_queue.push_back(t_fields);
		}
		return false;
	}

	std::string CallFor(const char *p_verb, const char *p_arg)
	{
		std::string t_value;
		if (!Call(p_verb, p_arg, nil, t_value))
			return std::string();
		return t_value;
	}

	// The next message from the helper, waiting until <p_end> for it (no
	// wait when p_end is 0); false when there is none or the helper ended
	bool ReadMessage(std::vector<std::string> &r_fields, double p_end)
	{
		for (;;)
		{
			std::string t_line;
			while (m_reader.Next(t_line))
			{
				std::vector<std::string> t_fields;
				// A line the helper could not have written is dropped
				if (MCWebKitGtkProtocol::Decode(t_line, t_fields) && !t_fields.empty() && !t_fields[0].empty())
				{
					r_fields.swap(t_fields);
					return true;
				}
			}

			if (m_fd < 0)
				return false;

			char t_buffer[16384];
			ssize_t t_count = read(m_fd, t_buffer, sizeof(t_buffer));
			if (t_count > 0)
			{
				m_reader.Append(t_buffer, t_count);
				continue;
			}
			if (t_count == 0 || (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR))
			{
				// The helper ended: the browser shows nothing more, and
				// every call fails, without blocking the engine
				close(m_fd);
				m_fd = -1;
				MCWebKitGtkReap(m_pid, 1.0);
				m_pid = 0;
				return false;
			}
			if (errno == EINTR)
				continue;

			double t_now = MCWebKitGtkNow();
			if (p_end <= 0 || t_now >= p_end)
				return false;
			struct pollfd t_poll = { m_fd, POLLIN, 0 };
			poll(&t_poll, 1, int((p_end - t_now) * 1000) + 1);
		}
	}

	void Dispatch(const std::vector<std::string> &p_fields)
	{
		if (p_fields[0] == "ev" && p_fields.size() >= 3)
		{
			const std::string &t_kind = p_fields[1];
			const char *t_url = p_fields[2].c_str();
			const char *t_error = p_fields.size() >= 4 ? p_fields[3].c_str() : "";
			// The helper's page is its main frame's: WebKitGTK's API has
			// no messages for the loads of a page's frames
			if (t_kind == "navigateBegin")
				OnNavigationBegin(false, t_url);
			else if (t_kind == "navigateComplete")
				OnNavigationComplete(false, t_url);
			else if (t_kind == "navigateFailed")
				OnNavigationFailed(false, t_url, t_error);
			else if (t_kind == "documentLoadBegin")
				OnDocumentLoadBegin(false, t_url);
			else if (t_kind == "documentLoadComplete")
				OnDocumentLoadComplete(false, t_url);
			else if (t_kind == "documentLoadFailed")
				OnDocumentLoadFailed(false, t_url, t_error);
			else if (t_kind == "unhandled")
				OnNavigationRequestUnhandled(false, t_url);
		}
		else if (p_fields[0] == "js" && p_fields.size() >= 2)
		{
			// [<handler>, [<parameters>]]
			MCBrowserListRef t_call = nil;
			if (!MCBrowserListCreateFromJSON(p_fields[1].c_str(), t_call))
				return;

			char *t_handler = nil;
			MCBrowserListRef t_params = nil;
			uint32_t t_size = 0;
			if (MCBrowserListGetSize(t_call, t_size) && t_size == 2 &&
			    MCBrowserListGetUTF8String(t_call, 0, t_handler) &&
			    MCBrowserListGetList(t_call, 1, t_params) &&
			    IsJavaScriptHandler(t_handler))
				OnJavaScriptCall(t_handler, t_params);

			// The name is a copy (MCBrowserValueGetUTF8String), as CEF's
			// (libbrowser_cef.cpp), whether the call was taken or not
			if (t_handler != nil)
				MCCStringFree(t_handler);
			MCBrowserListRelease(t_call);
		}
	}

	// Only the handlers the script named are its to call, whatever the page
	// sends
	bool IsJavaScriptHandler(const char *p_name)
	{
		size_t t_start = 0;
		while (t_start <= m_javascript_handlers.size())
		{
			size_t t_end = m_javascript_handlers.find('\n', t_start);
			if (t_end == std::string::npos)
				t_end = m_javascript_handlers.size();
			if (m_javascript_handlers.compare(t_start, t_end - t_start, p_name) == 0)
				return true;
			t_start = t_end + 1;
		}
		return false;
	}

	// IM-2014-08-25: [[ Bug 13272 ]] As CEF: the scroll bars are the body's
	// overflow style, and are taken to be there when it cannot be read
	bool GetOverflowHidden(const char *p_property)
	{
		std::string t_value;
		if (!Call("eval", p_property, nil, t_value))
			return false;
		return t_value == "hidden";
	}

	void SetOverflowHidden(const char *p_property, bool p_hidden)
	{
		std::string t_script = std::string(p_property) + " = \"" + (p_hidden ? "hidden" : "") + "\"";
		std::string t_value;
		/* UNCHECKED */ Call("eval", t_script.c_str(), nil, t_value);
	}
};

////////////////////////////////////////////////////////////////////////////////

static void MCWebKitGtkBrowserRunloopAction(void *p_context)
{
	// A browser may be released by a handler of another's message
	std::vector<MCWebKitGtkBrowser *> t_browsers(s_webkitgtk_browsers);
	for (size_t i = 0; i < t_browsers.size(); i++)
		t_browsers[i]->Retain();
	for (size_t i = 0; i < t_browsers.size(); i++)
	{
		t_browsers[i]->Poll();
		t_browsers[i]->Release();
	}
}

class MCWebKitGtkBrowserFactory : public MCBrowserFactory
{
public:
	MCWebKitGtkBrowserFactory() : m_runloop_action(false) {}

	virtual ~MCWebKitGtkBrowserFactory()
	{
		if (m_runloop_action)
			MCBrowserRemoveRunloopAction(MCWebKitGtkBrowserRunloopAction, nil);
	}

	// The helper is there, and finds WebKitGTK and GTK 3
	bool Initialize()
	{
		if (!MCWebKitGtkGetHelperPath(m_helper))
			return false;

		struct stat t_stat;
		if (stat(m_helper.c_str(), &t_stat) != 0 || !S_ISREG(t_stat.st_mode) || access(m_helper.c_str(), X_OK) != 0)
			return false;

		std::vector<std::string> t_args(1, "--probe");
		int t_fd;
		pid_t t_pid;
		if (!MCWebKitGtkSpawnHelper(m_helper, t_args, t_fd, t_pid))
			return false;
		close(t_fd);

		int t_status = 0;
		double t_end = MCWebKitGtkNow() + 10.0;
		pid_t t_result;
		while ((t_result = waitpid(t_pid, &t_status, WNOHANG)) == 0 && MCWebKitGtkNow() < t_end)
			usleep(5000);
		if (t_result != t_pid)
		{
			MCWebKitGtkReap(t_pid, 0.0);
			return false;
		}
		if (!WIFEXITED(t_status) || WEXITSTATUS(t_status) != 0)
			return false;

		m_runloop_action = MCBrowserAddRunloopAction(MCWebKitGtkBrowserRunloopAction, nil);
		return m_runloop_action;
	}

	virtual bool CreateBrowser(void *p_display, void *p_parent_view, MCBrowser *&r_browser)
	{
		MCWebKitGtkBrowser *t_browser = new (nothrow) MCWebKitGtkBrowser();
		if (t_browser == nil)
			return false;

		if (!t_browser->Init(m_helper, (Display *)p_display))
		{
			t_browser->Release();
			return false;
		}

		r_browser = t_browser;
		return true;
	}

private:
	std::string m_helper;
	bool m_runloop_action;
};

bool MCWebKitGtkBrowserFactoryCreate(MCBrowserFactoryRef &r_factory)
{
	MCWebKitGtkBrowserFactory *t_factory = new (nothrow) MCWebKitGtkBrowserFactory();
	if (t_factory == nil)
		return false;

	if (!t_factory->Initialize())
	{
		delete t_factory;
		return false;
	}

	r_factory = t_factory;
	return true;
}

////////////////////////////////////////////////////////////////////////////////
