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


#ifndef __MC_LIBBROWSER_CEF_DESKTOP_LNX_H__
#define __MC_LIBBROWSER_CEF_DESKTOP_LNX_H__

// OXT-Beyond: [[ CEF 156 ]] The desktop's name is kept from Chromium while
// it starts in the engine's process (CefInitialize), for the browser widget
// (libbrowser_cef.cpp) and revBrowser (revbrowser/src/cefbrowser.cpp).
//
// The engine is a GTK 2 program. Chromium's own Linux UI is told to take
// nothing from GTK (--ui-toolkit=fallback), but as it starts, Chromium also
// asks for the theme of the desktop it runs on by the desktop's name
// (ui/linux/linux_ui_factory.cc, GetDefaultSystemTheme, from base/nix's
// GetDesktopEnvironment): on GNOME, Unity, Cinnamon, Xfce, Pantheon, Deepin,
// UKUI and COSMIC that is GTK's, and it loads GTK 3 (or GTK 4) into the
// process for it. GTK 2 has registered 'GtkSettings' there already, the
// newer GTK's gtk_settings_get_type gives no type, and CefInitialize read
// the class of none: with 0.2.8-dp.2 the IDE ended with "Segmentation
// fault" the first time a browser was made (the Dictionary, a browser
// widget from the Tools palette) on every such desktop, reported for
// Ubuntu 26.04 by bwmilby, and the same on Ubuntu 24.04 with
// XDG_CURRENT_DESKTOP=ubuntu:GNOME. On KDE (its theme is Qt's, for which
// CEF has no shim) and on a desktop with no name the IDE's browsers
// worked: with no name Chromium takes its own theme and loads no GTK.
//
// So Chromium starts as on a desktop with no name: the four variables it
// reads the name from are taken out of the environment for the length of
// CefInitialize and put back as they were before it returns to the engine.
// Scripts ($XDG_CURRENT_DESKTOP), shell and the programs the engine starts
// afterwards see them unchanged. CEF 74 looked at no desktop's theme.
//
// (A process's environment is not made for threads: the engine runs no
// script while CefInitialize does, and the variables are back before the
// engine goes on. Chromium's threads, which it starts in between, read
// them only as it starts.)

#include <stdlib.h>

#include <string>

class MCCefLinuxDesktopNameHider
{
public:
	MCCefLinuxDesktopNameHider(void)
	{
		for (int i = 0; i < kCount; i++)
		{
			const char *t_value = getenv(Name(i));
			m_was_set[i] = t_value != nullptr;
			if (m_was_set[i])
			{
				m_value[i] = t_value;
				unsetenv(Name(i));
			}
		}
	}
	
	~MCCefLinuxDesktopNameHider(void)
	{
		for (int i = 0; i < kCount; i++)
			if (m_was_set[i])
				setenv(Name(i), m_value[i].c_str(), 1);
	}
	
	// What base/nix/xdg_util.cc's GetDesktopEnvironment reads, in its order
	enum { kCount = 4 };
	static const char *Name(int p_index)
	{
		static const char *const kNames[kCount] =
		{
			"XDG_CURRENT_DESKTOP",
			"DESKTOP_SESSION",
			"GNOME_DESKTOP_SESSION_ID",
			"KDE_FULL_SESSION",
		};
		return kNames[p_index];
	}
	
private:
	MCCefLinuxDesktopNameHider(const MCCefLinuxDesktopNameHider &) = delete;
	MCCefLinuxDesktopNameHider &operator=(const MCCefLinuxDesktopNameHider &) = delete;
	
	bool m_was_set[kCount];
	std::string m_value[kCount];
};

#endif
