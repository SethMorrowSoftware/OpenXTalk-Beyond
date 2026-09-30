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

// The light and dark appearance: the appAppearance (global), the
// stackAppearance of stacks, and which of the two the engine draws a stack
// in. docs/notes/feature-appearance.md describes the whole design.
//
// Why the default is "light": until this engine every colour a stack left
// unset came from the theme of the OS appearance, so on a dark Windows the
// text of a field whose author set a white background, and nothing else,
// came out white on white. Every stack that exists was designed on a light
// system. Windows and macOS make dark mode something an application opts
// into, and so does this engine: an application sets the appAppearance to
// "system" (or "dark") to follow the OS, and the IDE does so for its own
// windows through their stackAppearance.

#include "prefix.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "mcio.h"
#include "sysdefs.h"

#include "globals.h"
#include "uidc.h"
#include "object.h"
#include "stack.h"
#include "exec.h"
#include "dispatch.h"

MCAppearanceMode MCappappearance = kMCAppearanceModeLight;
int MCappearanceforcelight = 0;
bool MCselectioncolorisset = false;

// The OS setting, for the drawing code: on macOS reading it goes to the
// preferences system, which is too slow for every colour. It is read again
// when the OS says it changed and whenever the appearance is applied again
// (MCUIDC::updatesystemappearance and its overrides).
static bool s_system_is_dark = false;
static bool s_system_is_cached = false;

void MCAppearanceRefreshSystem(void)
{
	MCSystemAppearance t_appearance = kMCSystemAppearanceLight;
	if (MCscreen != nil)
		MCscreen->getsystemappearance(t_appearance);
	s_system_is_dark = t_appearance == kMCSystemAppearanceDark;
	// Not cached before there is a screen to ask
	s_system_is_cached = MCscreen != nil;
}

bool MCAppearanceSystemIsDark(void)
{
	if (!s_system_is_cached)
		MCAppearanceRefreshSystem();
	return s_system_is_dark;
}

MCAppearanceMode MCAppearanceResolveMode(MCStack *p_stack)
{
	// A stack with a mode of its own uses it. Otherwise a substack uses its
	// mainstack's, and a menu or popup stack the engine builds for a button
	// (its parent is the button, MCButton::findmenu) uses the button's
	// stack's; a mainstack uses the appAppearance. The bound only guards
	// against a cycle of parents.
	MCStack *t_stack = p_stack;
	for (int t_depth = 0; t_stack != nil && t_depth < 32; t_depth++)
	{
		MCAppearanceMode t_mode = t_stack->getappearancemode();
		if (t_mode != kMCAppearanceModeInherit)
			return t_mode;

		MCObject *t_parent = t_stack->getparent();
		if (t_parent == nil || t_parent == MCdispatcher)
			break;
		if (t_parent->gettype() == CT_STACK)
			t_stack = static_cast<MCStack *>(t_parent);
		else
			t_stack = t_parent->getstack();
	}
	return MCappappearance;
}

#if defined(_WINDOWS_DESKTOP)
extern bool MCWin32IsHighContrast(void);
#endif

bool MCAppearanceIsDark(MCStack *p_stack)
{
#if defined(_SERVER)
	// Nothing is drawn for a screen
	return false;
#else
	// Printing (MCPrinter), always light
	if (MCappearanceforcelight > 0)
		return false;

#if defined(_LINUX_DESKTOP)
	// GTK draws the native controls in the colours of its theme, and the
	// engine cannot draw them in another: the appearance is the theme's
	return MCAppearanceSystemIsDark();
#else
#if defined(_WINDOWS_DESKTOP)
	// With a High Contrast theme the system colours are the user's choice;
	// the light path uses them (GetSysColor), the dark one does not
	if (MCWin32IsHighContrast())
		return false;
#endif

	MCAppearanceMode t_mode = MCAppearanceResolveMode(p_stack);
	if (t_mode == kMCAppearanceModeSystem)
		return MCAppearanceSystemIsDark();
	return t_mode == kMCAppearanceModeDark;
#endif
#endif
}

void MCAppearanceChanged(void)
{
	// Colours, native parts and window frames of every window, at once; no
	// message: scripts that set the property know
	if (MCscreen != nil)
		MCscreen->updatesystemappearance();
}

void MCAppearanceSetAppMode(MCAppearanceMode p_mode)
{
	// Only a stack can inherit
	if (p_mode == kMCAppearanceModeInherit)
		p_mode = kMCAppearanceModeLight;
	if (p_mode == MCappappearance)
		return;
	MCappappearance = p_mode;
	MCAppearanceChanged();
}
