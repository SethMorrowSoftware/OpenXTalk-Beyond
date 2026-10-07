/* Copyright (C) 2003-2015 LiveCode Ltd.
 * Copyright (C) 2024-2026 OpenXTalk Contributors.

This file is part of LiveCode / OpenXTalk.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

////////////////////////////////////////////////////////////////////////////////
//
//  Private Source File:
//    dump_stack.cpp
//
//  Description:
//    Implementation of _internal dump stack command.
//    Loads a .oxtstack, .livecode, .rev or .livecodescript file and
//    outputs its object hierarchy, all script text, and detected
//    standalone inclusions.
//
//    Usage from script:
//      _internal dump stack <filepath>
//      put the result
//
////////////////////////////////////////////////////////////////////////////////

#include "prefix.h"

#include "globdefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "filedefs.h"
#include "mcio.h"

#include "exec.h"
#include "handler.h"
#include "scriptpt.h"
#include "newobj.h"
#include "cmds.h"
#include "mcerror.h"
#include "globals.h"
#include "express.h"
#include "internal.h"

#include "object.h"
#include "button.h"
#include "field.h"
#include "image.h"
#include "card.h"
#include "group.h"
#include "scrolbar.h"
#include "player.h"
#include "aclip.h"
#include "vclip.h"
#include "stack.h"
#include "dispatch.h"
#include "objptr.h"

#include "dump_stack.h"

#include <string>

////////////////////////////////////////////////////////////////////////////////
// Helpers
////////////////////////////////////////////////////////////////////////////////

static const char *chunk_type_name(Chunk_term p_type)
{
	switch (p_type)
	{
		case CT_STACK: return "stack";
		case CT_CARD: return "card";
		case CT_GROUP: return "group";
		case CT_BUTTON: return "button";
		case CT_FIELD: return "field";
		case CT_IMAGE: return "image";
		case CT_SCROLLBAR: return "scrollbar";
		case CT_PLAYER: return "player";
		case CT_GRAPHIC: return "graphic";
		case CT_EPS: return "eps";
		case CT_MAGNIFY: return "magnify";
		case CT_COLOR_PALETTE: return "palette";
		case CT_WIDGET: return "widget";
		case CT_AUDIO_CLIP: return "audioclip";
		case CT_VIDEO_CLIP: return "videoclip";
		default: return "unknown";
	}
}

static void append_escaped_script(MCStringRef r_output, MCStringRef p_script)
{
	if (p_script == nil || MCStringIsEmpty(p_script))
		return;

	// Escape backslashes and newlines so the output stays on one line per record
	MCAutoStringRefAsCString t_cstr;
	if (!t_cstr.Lock(p_script))
		return;

	const char *sptr = *t_cstr;
	for (size_t i = 0; sptr[i] != '\0'; i++)
	{
		char t_buf[3];
		switch (sptr[i])
		{
		case '\\':
			t_buf[0] = '\\'; t_buf[1] = '\\'; t_buf[2] = '\0';
			break;
		case '\n':
			t_buf[0] = '\\'; t_buf[1] = 'n'; t_buf[2] = '\0';
			break;
		case '\r':
			t_buf[0] = '\\'; t_buf[1] = 'r'; t_buf[2] = '\0';
			break;
		case '\t':
			t_buf[0] = '\\'; t_buf[1] = 't'; t_buf[2] = '\0';
			break;
		default:
			t_buf[0] = sptr[i]; t_buf[1] = '\0';
			break;
		}
		/* UNCHECKED */ MCStringAppendFormat(r_output, "%s", t_buf);
	}
}

struct MCDumpStackInclusion
{
	const char *keyword;
	const char *inclusion_name;
};

static MCDumpStackInclusion k_inclusion_map[] =
{
	{ "answer", "answer dialog" },
	{ "ask", "ask dialog" },
	{ "revOpenDatabase", "Database" },
	{ "revCloseDatabase", "Database" },
	{ "revExecuteSQL", "Database" },
	{ "revQueryDatabase", "Database" },
	{ "revXML", "XML" },
	{ "revXMLRPC", "XMLRPC" },
	{ "revZip", "Zip" },
	{ "revBrowser", "Browser" },
	{ "revSMTP", "SMTP" },
	{ "revPOP3", "Internet" },
	{ "revIMAP", "Internet" },
	{ "revPrintText", "Printing" },
	{ "revPrinter", "Printing" },
	{ "revSpeech", "Speech" },
	{ "revVideoGrabber", "Video" },
	{ "revGoURL", "Internet" },
	{ "revPostURL", "Internet" },
	{ "revSetSpeechPilot", "Speech" },
	{ "revSpeak", "Speech" },
	{ "revStopSpeech", "Speech" },
	{ "revInitializeVideoGrabber", "VideoGrabber" },
	{ "revPreviewVideo", "VideoGrabber" },
	{ "revRecordVideo", "VideoGrabber" },
	{ "revStopPreviewingVideo", "VideoGrabber" },
	{ "revStopRecordingVideo", "VideoGrabber" },
	{ "revSetVideoGrabberRect", "VideoGrabber" },
	{ "revSetVideoGrabberSettings", "VideoGrabber" },
	{ "revCloseVideoGrabber", "VideoGrabber" },
	{ "revNumberOfCameras", "VideoGrabber" },
	{ "revCameraName", "VideoGrabber" },
	{ "revNumberOfAudioInputs", "VideoGrabber" },
	{ "revSetCamera", "VideoGrabber" },
	{ "revSetAudioInput", "VideoGrabber" },
	{ "revSetVolume", "VideoGrabber" },
	{ "revCameraSettings", "VideoGrabber" },
	{ "revCurrentCameraSetting", "VideoGrabber" },
	{ "revSetVideoFormat", "VideoGrabber" },
	{ "revVideoFormat", "VideoGrabber" },
	{ "revSetAudioCaptureFormat", "VideoGrabber" },
	{ "revAudioCaptureFormat", "VideoGrabber" },
	{ nil, nil }
};

static void detect_inclusions(MCStringRef p_script, MCStringRef r_inclusions)
{
	if (p_script == nil || MCStringIsEmpty(p_script))
		return;

	MCAutoStringRefAsCString t_cstr;
	if (!t_cstr.Lock(p_script))
		return;

	const char *t_script = *t_cstr;
	for (uindex_t i = 0; k_inclusion_map[i].keyword != nil; i++)
	{
		const char *kw = k_inclusion_map[i].keyword;
		const char *found = t_script;
		while ((found = strstr(found, kw)) != nil)
		{
			// Check word boundaries
			bool t_start_ok = (found == t_script) || !isalnum((unsigned char)found[-1]);
			bool t_end_ok = !isalnum((unsigned char)found[strlen(kw)]);
			if (t_start_ok && t_end_ok)
			{
				MCStringAppendFormat(r_inclusions, "%s\n", k_inclusion_map[i].inclusion_name);
				break; // Only add once per script
			}
			found++;
		}
	}
}

static void dump_object(MCObject *p_obj, const char *p_parent_path,
                        MCStringRef r_objects, MCStringRef r_scripts,
                        MCStringRef r_inclusions)
{
	if (p_obj == nil)
		return;

	const char *t_type = chunk_type_name(p_obj->gettype());
	const char *t_name = "";
	MCAutoStringRefAsCString t_name_cstr;
	if (!MCNameIsEmpty(p_obj->getname()))
	{
		if (t_name_cstr.Lock(MCNameGetString(p_obj->getname())))
			t_name = *t_name_cstr;
	}

	// Add to objects list: type\tname\tid\tparent
	/* UNCHECKED */ MCStringAppendFormat(r_objects, "%s\t%s\t%u\t%s\n",
	                                     t_type, t_name, p_obj->getid(), p_parent_path);

	// Add script
	MCStringRef t_script = p_obj->_getscript();
	if (t_script != nil && !MCStringIsEmpty(t_script))
	{
		/* UNCHECKED */ MCStringAppendFormat(r_scripts, "%u\t", p_obj->getid());
		append_escaped_script(r_scripts, t_script);
		/* UNCHECKED */ MCStringAppendFormat(r_scripts, "\n");
		detect_inclusions(t_script, r_inclusions);
	}
}

static void dump_control_tree(MCControl *p_ctrl, const char *p_parent_path,
                              MCStringRef r_objects, MCStringRef r_scripts,
                              MCStringRef r_inclusions);

static void dump_group_contents(MCGroup *p_group, const char *p_parent_path,
                                MCStringRef r_objects, MCStringRef r_scripts,
                                MCStringRef r_inclusions)
{
	if (p_group == nil)
		return;

	MCControl *t_ctrl = p_group->getcontrols();
	if (t_ctrl == nil)
		return;

	MCControl *t_first = t_ctrl;
	do
	{
		dump_control_tree(t_ctrl, p_parent_path, r_objects, r_scripts, r_inclusions);
		t_ctrl = t_ctrl->next();
	} while (t_ctrl != nil && t_ctrl != t_first);
}

static void dump_control_tree(MCControl *p_ctrl, const char *p_parent_path,
                              MCStringRef r_objects, MCStringRef r_scripts,
                              MCStringRef r_inclusions)
{
	if (p_ctrl == nil)
		return;

	dump_object(p_ctrl, p_parent_path, r_objects, r_scripts, r_inclusions);

	// If it's a group, dump its children
	if (p_ctrl->gettype() == CT_GROUP)
	{
		MCGroup *t_group = static_cast<MCGroup *>(p_ctrl);
		char t_path[256];
		snprintf(t_path, sizeof(t_path), "%s/group-%u", p_parent_path, p_ctrl->getid());
		dump_group_contents(t_group, t_path, r_objects, r_scripts, r_inclusions);
	}
}

static void dump_card(MCCard *p_card, const char *p_stack_path,
                      MCStringRef r_objects, MCStringRef r_scripts,
                      MCStringRef r_inclusions)
{
	if (p_card == nil)
		return;

	char t_card_path[256];
	snprintf(t_card_path, sizeof(t_card_path), "%s/card-%u", p_stack_path, p_card->getid());
	dump_object(p_card, p_stack_path, r_objects, r_scripts, r_inclusions);

	// Iterate controls via objptrs
	MCObjptr *t_objptr = p_card->getobjptrs();
	if (t_objptr != nil)
	{
		MCObjptr *t_first = t_objptr;
		do
		{
			MCControl *t_ctrl = t_objptr->getref();
			if (t_ctrl != nil)
				dump_control_tree(t_ctrl, t_card_path, r_objects, r_scripts, r_inclusions);
			t_objptr = t_objptr->next();
		} while (t_objptr != nil && t_objptr != t_first);
	}
}

static void dump_stack(MCStack *p_stack, const char *p_parent_path,
                       MCStringRef r_objects, MCStringRef r_scripts,
                       MCStringRef r_inclusions)
{
	if (p_stack == nil)
		return;

	char t_stack_path[256];
	snprintf(t_stack_path, sizeof(t_stack_path), "%s/stack-%u", p_parent_path, p_stack->getid());
	dump_object(p_stack, p_parent_path, r_objects, r_scripts, r_inclusions);

	// Iterate cards
	MCCard *t_card = p_stack->getcards();
	if (t_card != nil)
	{
		MCCard *t_first = t_card;
		do
		{
			dump_card(t_card, t_stack_path, r_objects, r_scripts, r_inclusions);
			t_card = t_card->next();
		} while (t_card != nil && t_card != t_first);
	}

	// Iterate substacks
	MCStack *t_sub = p_stack->getsubstacks();
	if (t_sub != nil)
	{
		MCStack *t_first = t_sub;
		do
		{
			dump_stack(t_sub, t_stack_path, r_objects, r_scripts, r_inclusions);
			t_sub = t_sub->next();
		} while (t_sub != nil && t_sub != t_first);
	}
}

////////////////////////////////////////////////////////////////////////////////
// Command implementation
////////////////////////////////////////////////////////////////////////////////

MCInternalDumpStack::MCInternalDumpStack(void)
{
	m_path_expr = nil;
}

MCInternalDumpStack::~MCInternalDumpStack(void)
{
	delete m_path_expr;
}

Parse_stat MCInternalDumpStack::parse(MCScriptPoint& sp)
{
	if (sp.parseexp(False, True, &m_path_expr) != PS_NORMAL)
	{
		MCperror->add(PE_PUT_BADEXP, sp);
		return PS_ERROR;
	}
	return PS_NORMAL;
}

void MCInternalDumpStack::exec_ctxt(MCExecContext &ctxt)
{
	MCAutoStringRef t_path;
	if (!ctxt.EvalExprAsStringRef(m_path_expr, EE_UNDEFINED, &t_path))
		return;

	IO_handle t_stream = MCS_open(*t_path, kMCOpenFileModeRead, False, False, 0);
	if (t_stream == nil)
	{
		ctxt.SetTheResultToCString("cannot open file");
		return;
	}

	MCStack *t_stack = nil;
	const char *t_result = nil;
	IO_stat t_stat = IO_NORMAL;

	// Try binary stack first
	t_stat = MCdispatcher->trytoreadbinarystack(*t_path, kMCEmptyString,
	                                            t_stream, nil, t_stack, t_result);
	if (t_stat != IO_NORMAL || t_stack == nil)
	{
		// Reset stream and try script-only
		MCS_seek_set(t_stream, 0);
		t_stat = MCdispatcher->trytoreadscriptonlystack(*t_path, t_stream,
	                                                    nil, t_stack, t_result);
	}

	MCS_close(t_stream);

	if (t_stat != IO_NORMAL || t_stack == nil)
	{
		if (t_result != nil)
			ctxt.SetTheResultToCString(t_result);
		else
			ctxt.SetTheResultToCString("failed to read stack file");
		return;
	}

	// Build output
	MCAutoStringRef t_output;
	MCAutoStringRef t_objects, t_scripts, t_inclusions;
	/* UNCHECKED */ MCStringCreateMutable(0, &t_output);
	/* UNCHECKED */ MCStringCreateMutable(0, &t_objects);
	/* UNCHECKED */ MCStringCreateMutable(0, &t_scripts);
	/* UNCHECKED */ MCStringCreateMutable(0, &t_inclusions);

	dump_stack(t_stack, "", *t_objects, *t_scripts, *t_inclusions);

	// Build final output
	/* UNCHECKED */ MCStringAppendFormat(*t_output, "==OBJECTS==\n");
	/* UNCHECKED */ MCStringAppend(*t_output, *t_objects);
	/* UNCHECKED */ MCStringAppendFormat(*t_output, "==SCRIPTS==\n");
	/* UNCHECKED */ MCStringAppend(*t_output, *t_scripts);
	/* UNCHECKED */ MCStringAppendFormat(*t_output, "==INCLUSIONS==\n");
	/* UNCHECKED */ MCStringAppend(*t_output, *t_inclusions);

	// Clean up the loaded stack (need_remove = False since we didn't integrate it)
	MCdispatcher->destroystack(t_stack, False);

	ctxt.SetTheResultToValue(*t_output);
}
