/* Copyright (C) 2015 LiveCode Ltd.
 
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

#include "prefix.h"

#include "widget.h"
#include "widget-ref.h"

#include "exec.h"

#include "exec-interface.h"

// OXT-Beyond: a widget whose extension is not loaded has no instance; these
// commands do nothing for it, as the widget's other actions do, rather than
// posting to no instance (which crashed the engine)
void MCInterfaceExecGoBackInWidget(MCExecContext& ctxt, MCWidget *p_widget)
{
	if (p_widget->getwidget() == nil)
		return;

	MCWidgetPost(p_widget->getwidget(), MCNAME("OnGoBack"), kMCEmptyProperList);
}

void MCInterfaceExecGoForwardInWidget(MCExecContext& ctxt, MCWidget *p_widget)
{
	if (p_widget->getwidget() == nil)
		return;

	MCWidgetPost(p_widget->getwidget(), MCNAME("OnGoForward"), kMCEmptyProperList);
}

void MCInterfaceExecLaunchUrlInWidget(MCExecContext& ctxt, MCStringRef p_url, MCWidget *p_widget)
{
	if (p_widget->getwidget() == nil)
		return;

	MCAutoProperListRef t_list;
	
	if (!MCProperListCreate((MCValueRef*)&p_url, 1, &t_list))
		return;
	
	MCWidgetPost(p_widget->getwidget(), MCNAME("OnLaunchUrl"), *t_list);
}

void MCInterfaceExecDoInWidget(MCExecContext& ctxt, MCStringRef p_script, MCWidget *p_widget)
{
	if (p_widget->getwidget() == nil)
		return;

	MCAutoProperListRef t_list;
	
	if (!MCProperListCreate((MCValueRef*)&p_script, 1, &t_list))
		return;
	
	MCWidgetPost(p_widget->getwidget(), MCNAME("OnDo"), *t_list);
}
