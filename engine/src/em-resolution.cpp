/*                                                                     -*-c++-*-

Copyright (C) 2003-2015 LiveCode Ltd.

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

/* Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
   (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
   Seth Morrow (2026); its Git history and CHANGELOG.md say what changed. */

#include "globdefs.h"
#include "filedefs.h"
#include "osspec.h"
#include "typedefs.h"
#include "parsedef.h"
#include "objdefs.h"

#include "globals.h"

#include "em-util.h"

#include "sysdefs.h"

#include "graphics.h"
#include "resolution.h"
#include "stacklst.h"

#include <emscripten.h>

/* ================================================================
 * Resolution independence
 * ================================================================ */

static MCGFloat s_emscripten_device_scale = 1.0;

void
MCResPlatformInitPixelScaling()
{
	/* OXT-Beyond: an engine without a user interface (a web worker's,
	 * em-dc-mainloop.cpp) has no window to ask, and a worker has no
	 * devicePixelRatio */
	if (MCnoui)
	{
		return;
	}

	s_emscripten_device_scale = emscripten_get_device_pixel_ratio();
}

bool
MCResPlatformSupportsPixelScaling()
{
	return true;
}

bool
MCResPlatformCanChangePixelScaling()
{
	return false;
}

bool
MCResPlatformCanSetPixelScale()
{
	return false;
}

MCGFloat
MCResPlatformGetDefaultPixelScale()
{
	return s_emscripten_device_scale;
}

MCGFloat
MCResPlatformGetUIDeviceScale()
{
	return s_emscripten_device_scale;
}

void
MCResPlatformHandleScaleChange()
{
	// Global use-pixel-scaling value has been updated, so now we just need to reopen any open stack windows
	MCstacks->reopenallstackwindows();
}

extern "C" MC_DLLEXPORT_DEF bool
MCEmscriptenHandleDevicePixelRatioChanged()
{
	MCGFloat t_scale = emscripten_get_device_pixel_ratio();
	if (t_scale != s_emscripten_device_scale)
	{
		s_emscripten_device_scale = t_scale;

		/* The engine's pixel scale is the device's, when pixel scaling
		 * is on: the stacks' windows are reopened at it, and draw with
		 * the browser's new number of pixels to a point */
		MCResSetPixelScale(t_scale);
	}

	return true;
}
