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

#include "prefix.h"

#include "em-util.h"
#include "em-dc.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "exec.h"
#include "stack.h"
#include "object.h"
#include "param.h"
#include "sysdefs.h"
#include "osspec.h"
#include "globals.h"
#include "notify.h"
#include "ans.h"

#include <stdio.h>
#include <sys/stat.h>

/* ================================================================
 * Locales
 * ================================================================ */

MCLocaleRef
MCS_getsystemlocale()
{
	/* Emscripten locale is basically C.UTF-8.  There's no standard
	 * way to get the user's desired locale from ECMAScript,
	 * either. */
	MCLocaleRef t_locale;
	/* UNCHECKED */ MCLocaleCreateWithName(MCSTR("C"), t_locale);
	return t_locale;
}


bool
MCS_put(MCExecContext &ctxt, MCSPutKind p_kind, MCStringRef p_string)
{
	bool t_success;
	switch (p_kind)
	{
	case kMCSPutBeforeMessage:
        // SN-2014-04-11 [[ FasterVariable ]] parameter updated to use the new 'set' operation on variables
        t_success = MCmb -> set(ctxt, p_string, kMCVariableSetBefore);
        break;
    case kMCSPutOutput:
    case kMCSPutIntoMessage:
		t_success = MCmb -> set(ctxt, p_string);
		break;
	case kMCSPutAfterMessage:
		// SN-2014-04-11 [[ FasterVariable ]] parameter updated to use the new 'set' operation on variables
		t_success = MCmb -> set(ctxt, p_string, kMCVariableSetAfter);
		break;
	default:
		t_success = false;
		break;
	}

	// MW-2012-02-23: [[ PutUnicode ]] If we don't understand the kind
	//   then return false (caller can then throw an error).
	return t_success;
}

/* As on mobile, there is no binary output. */
bool
MCS_put_binary(MCExecContext & ctxt,
               MCSPutKind p_kind,
               MCDataRef p_data)
{
	return false;
}

/* ================================================================
 * Server properties
 *
 * The errorMode, the outputTextEncoding, the outputLineEndings and
 * the session properties belong to the server engine; as on mobile,
 * setting them does nothing.
 * ================================================================ */

void
MCS_set_errormode(MCSErrorMode p_mode)
{
}

MCSErrorMode
MCS_get_errormode()
{
	return kMCSErrorModeNone;
}

void
MCS_set_outputtextencoding(MCSOutputTextEncoding p_encoding)
{
}

MCSOutputTextEncoding
MCS_get_outputtextencoding()
{
	return kMCSOutputTextEncodingNative;
}

void
MCS_set_outputlineendings(MCSOutputLineEndings p_ending)
{
}

MCSOutputLineEndings
MCS_get_outputlineendings()
{
	return kMCSOutputLineEndingsNative;
}

bool
MCS_set_session_save_path(MCStringRef p_path)
{
	return true;
}

bool
MCS_get_session_save_path(MCStringRef & r_path)
{
	r_path = MCValueRetain(kMCEmptyString);
	return true;
}

bool
MCS_set_session_lifetime(uint32_t p_lifetime)
{
	return true;
}

uint32_t
MCS_get_session_lifetime()
{
	return 0;
}

bool
MCS_set_session_name(MCStringRef p_name)
{
	return true;
}

bool
MCS_get_session_name(MCStringRef & r_name)
{
	r_name = MCValueRetain(kMCEmptyString);
	return true;
}

bool
MCS_set_session_id(MCStringRef p_id)
{
	return true;
}

bool
MCS_get_session_id(MCStringRef & r_id)
{
	r_id = MCValueRetain(kMCEmptyString);
	return true;
}

/* ================================================================
 * Notifications
 * ================================================================ */

/* Other threads post their callbacks to the main thread with
 * MCNotifyPush() (notify.cpp).  The web engine has one thread, so
 * nothing can post one; the engine's shared code refers to it. */
bool
MCNotifyPush(void (*p_callback)(void *),
             void *p_state,
             bool p_block,
             bool p_safe,
             bool p_required)
{
	return false;
}

/* ================================================================
 * System dialogs
 *
 * answer file, answer folder, ask file and answer color use the page's
 * dialogs and the browser's file picker (em-dialog.js): the screen
 * reports the features (MCScreenDC::hasfeature), so the engine calls
 * these rather than the IDE's dialog stacks, which a web standalone
 * does not have.
 *
 * The files that the user picks are copied into /uploads, and their
 * copies' paths returned. ask file returns a path in /downloads: a
 * file written there is given to the user as a download when it is
 * closed (em-filehandle.cpp).
 *
 * Browsers open their file picker only while they answer a click or a
 * key: when the engine is not answering one, a dialog of the page asks
 * for the click first. A handler that the page calls cannot wait for a
 * dialog (em-async.js), so in one these dialogs return as cancelled.
 * ================================================================ */

extern bool MCStringsSplit(MCStringRef p_string, codepoint_t p_separator, MCStringRef*&r_strings, uindex_t& r_count);

/* Removes the spaces and tabs at the ends of a mutable string */
static bool
MCEmscriptenTrim(MCStringRef x_string)
{
	uindex_t t_length = MCStringGetLength(x_string);
	uindex_t t_end = t_length;
	while (t_end > 0 &&
	       (MCStringGetCharAtIndex(x_string, t_end - 1) == ' ' ||
	        MCStringGetCharAtIndex(x_string, t_end - 1) == '\t'))
		t_end--;
	uindex_t t_start = 0;
	while (t_start < t_end &&
	       (MCStringGetCharAtIndex(x_string, t_start) == ' ' ||
	        MCStringGetCharAtIndex(x_string, t_start) == '\t'))
		t_start++;

	return (t_end == t_length || MCStringRemove(x_string, MCRangeMake(t_end, t_length - t_end))) &&
		(t_start == 0 || MCStringRemove(x_string, MCRangeMake(0, t_start)));
}

/* Appends the extension <p_extension> ("txt" or ".txt") to the accept
 * attribute of the file picker, as ".txt". False if it names no
 * extension ("", "*" or a pattern), and so every file. */
static bool
MCEmscriptenAcceptAppendExtension(MCStringRef x_accept, MCStringRef p_extension)
{
	MCAutoStringRef t_extension;
	if (!MCStringMutableCopy(p_extension, &t_extension) ||
	    !MCEmscriptenTrim(*t_extension))
		return false;

	if (MCStringBeginsWithCString(*t_extension, (const char_t *)".", kMCStringOptionCompareExact))
		/* UNCHECKED */ MCStringRemove(*t_extension, MCRangeMake(0, 1));

	uindex_t t_offset;
	if (MCStringIsEmpty(*t_extension) ||
	    MCStringFirstIndexOfChar(*t_extension, '*', 0, kMCStringOptionCompareExact, t_offset) ||
	    MCStringFirstIndexOfChar(*t_extension, '?', 0, kMCStringOptionCompareExact, t_offset) ||
	    MCStringFirstIndexOfChar(*t_extension, '.', 0, kMCStringOptionCompareExact, t_offset) ||
	    MCStringFirstIndexOfChar(*t_extension, ',', 0, kMCStringOptionCompareExact, t_offset))
		return false;

	if (!MCStringIsEmpty(x_accept) &&
	    !MCStringAppendNativeChar(x_accept, ','))
		return false;
	return MCStringAppendFormat(x_accept, ".%@", *t_extension);
}

/* The accept attribute of the file picker for the types of answer file
 * with type ("Text files|txt,text|TEXT"): ".txt,.text". Empty (every
 * file) when a type is "All files", or names no extension. */
static void
MCEmscriptenAcceptFromTypes(MCStringRef *p_types, uindex_t p_type_count, MCStringRef &r_accept)
{
	MCAutoStringRef t_accept;
	bool t_every = p_type_count == 0;
	if (!MCStringCreateMutable(0, &t_accept))
		t_every = true;

	for (uindex_t i = 0; !t_every && i < p_type_count; i++)
	{
		MCAutoStringRefArray t_parts;
		if (!MCStringsSplit(p_types[i], '|', t_parts.PtrRef(), t_parts.CountRef()) ||
		    t_parts.Count() < 2 ||
		    MCStringIsEqualToCString(t_parts[0], "All files", kMCStringOptionCompareCaseless))
		{
			t_every = true;
			break;
		}

		MCAutoStringRefArray t_extensions;
		if (!MCStringsSplit(t_parts[1], ',', t_extensions.PtrRef(), t_extensions.CountRef()) ||
		    t_extensions.Count() == 0)
		{
			t_every = true;
			break;
		}
		for (uindex_t j = 0; !t_every && j < t_extensions.Count(); j++)
		{
			if (!MCEmscriptenAcceptAppendExtension(*t_accept, t_extensions[j]))
				t_every = true;
		}
	}

	if (t_every || !MCStringCopy(*t_accept, r_accept))
		r_accept = MCValueRetain(kMCEmptyString);
}

/* The accept attribute of the file picker for the filter of answer file
 * with filter, which has the form that the Windows dialog takes: a
 * pattern ("*.txt"), or descriptions and patterns separated by commas
 * or line feeds ("Text files,*.txt,Images,*.jpg;*.png"). Empty (every
 * file) for a pattern that is not "*.<extension>". */
static void
MCEmscriptenAcceptFromFilter(MCStringRef p_filter, MCStringRef &r_accept)
{
	r_accept = MCValueRetain(kMCEmptyString);
	if (p_filter == nil || MCStringIsEmpty(p_filter))
		return;

	MCAutoStringRef t_filter, t_accept;
	MCAutoStringRefArray t_parts;
	if (!MCStringMutableCopy(p_filter, &t_filter) ||
	    !MCStringFindAndReplaceChar(*t_filter, '\n', ',', kMCStringOptionCompareExact) ||
	    !MCStringsSplit(*t_filter, ',', t_parts.PtrRef(), t_parts.CountRef()) ||
	    !MCStringCreateMutable(0, &t_accept))
		return;

	uindex_t t_count = t_parts.Count();
	for (uindex_t i = 0; i < t_count; i += 2)
	{
		/* A single item is the pattern */
		MCStringRef t_patterns;
		if (t_count == 1)
			t_patterns = t_parts[0];
		else if (i + 1 < t_count)
			t_patterns = t_parts[i + 1];
		else
			break;

		MCAutoStringRefArray t_list;
		if (!MCStringsSplit(t_patterns, ';', t_list.PtrRef(), t_list.CountRef()))
			return;
		for (uindex_t j = 0; j < t_list.Count(); j++)
		{
			MCAutoStringRef t_pattern;
			if (!MCStringMutableCopy(t_list[j], &t_pattern) ||
			    !MCEmscriptenTrim(*t_pattern))
				return;
			if (MCStringIsEmpty(*t_pattern))
				continue;
			/* "*.txt": its extension; anything else, every file */
			if (!MCStringBeginsWithCString(*t_pattern, (const char_t *)"*.", kMCStringOptionCompareExact))
				return;
			MCAutoStringRef t_extension;
			if (!MCStringCopySubstring(*t_pattern, MCRangeMake(2, MCStringGetLength(*t_pattern) - 2), &t_extension) ||
			    !MCEmscriptenAcceptAppendExtension(*t_accept, *t_extension))
				return;
		}
	}

	MCValueRelease(r_accept);
	if (!MCStringCopy(*t_accept, r_accept))
		r_accept = MCValueRetain(kMCEmptyString);
}

static int
MCEmscriptenAnswerFile(MCStringRef p_title,
                       MCStringRef p_prompt,
                       MCStringRef p_accept,
                       unsigned int p_options,
                       bool p_folder,
                       MCStringRef & r_value,
                       MCStringRef & r_result)
{
	MCStringRef t_paths = nil;
	if (!MCEmscriptenPickFiles(p_title, p_prompt,
	                           (p_options & MCA_OPTION_PLURAL) != 0 && !p_folder,
	                           p_folder, p_accept, t_paths))
	{
		MCLog("answer %s: the engine cannot wait for the file picker in a handler that the page called",
		      p_folder ? "folder" : "file");
	}

	/* r_value stays nil when cancelled */
	if (t_paths != nil)
		r_value = t_paths;
	return 0;
}

int
MCA_file(MCStringRef p_title,
         MCStringRef p_prompt,
         MCStringRef p_filter,
         MCStringRef p_initial,
         unsigned int p_options,
         MCStringRef & r_value,
         MCStringRef & r_result)
{
	MCAutoStringRef t_accept;
	MCEmscriptenAcceptFromFilter(p_filter, &t_accept);
	return MCEmscriptenAnswerFile(p_title, p_prompt, *t_accept, p_options, false, r_value, r_result);
}

int
MCA_file_with_types(MCStringRef p_title,
                    MCStringRef p_prompt,
                    MCStringRef *p_types,
                    uint4 p_type_count,
                    MCStringRef p_initial,
                    unsigned int p_options,
                    MCStringRef & r_value,
                    MCStringRef & r_result)
{
	MCAutoStringRef t_accept;
	MCEmscriptenAcceptFromTypes(p_types, p_type_count, &t_accept);
	return MCEmscriptenAnswerFile(p_title, p_prompt, *t_accept, p_options, false, r_value, r_result);
}

int
MCA_folder(MCStringRef p_title,
           MCStringRef p_prompt,
           MCStringRef p_initial,
           unsigned int p_options,
           MCStringRef & r_value,
           MCStringRef & r_result)
{
	return MCEmscriptenAnswerFile(p_title, p_prompt, kMCEmptyString, p_options, true, r_value, r_result);
}

/* The label of the type that the name <p_name> has, of the types of ask
 * file with type ("Text files|txt,text|TEXT"): the first whose
 * extensions include the name's, else the first. If the name has no
 * extension, the first extension of the first type that has one is
 * added to it, as the Windows dialog does. */
static void
MCEmscriptenAskFileType(MCStringRef *p_types, uindex_t p_type_count, MCStringRef x_name, MCStringRef &r_label)
{
	r_label = nil;

	uindex_t t_dot;
	bool t_has_extension = MCStringLastIndexOfChar(x_name, '.', UINDEX_MAX, kMCStringOptionCompareExact, t_dot) &&
		t_dot > 0 && t_dot + 1 < MCStringGetLength(x_name);
	MCAutoStringRef t_extension;
	if (t_has_extension &&
	    !MCStringCopySubstring(x_name, MCRangeMake(t_dot + 1, MCStringGetLength(x_name) - t_dot - 1), &t_extension))
		return;

	MCStringRef t_first_label = nil;
	MCAutoStringRef t_first_extension;
	for (uindex_t i = 0; i < p_type_count && r_label == nil; i++)
	{
		MCAutoStringRefArray t_parts;
		if (!MCStringsSplit(p_types[i], '|', t_parts.PtrRef(), t_parts.CountRef()) ||
		    t_parts.Count() == 0)
			continue;
		if (t_first_label == nil)
			t_first_label = MCValueRetain(t_parts[0]);
		if (t_parts.Count() < 2)
			continue;

		MCAutoStringRefArray t_extensions;
		if (!MCStringsSplit(t_parts[1], ',', t_extensions.PtrRef(), t_extensions.CountRef()))
			continue;
		for (uindex_t j = 0; j < t_extensions.Count(); j++)
		{
			MCAutoStringRef t_candidate;
			if (!MCStringMutableCopy(t_extensions[j], &t_candidate) ||
			    !MCEmscriptenTrim(*t_candidate))
				continue;
			if (MCStringBeginsWithCString(*t_candidate, (const char_t *)".", kMCStringOptionCompareExact))
				/* UNCHECKED */ MCStringRemove(*t_candidate, MCRangeMake(0, 1));
			uindex_t t_offset;
			if (MCStringIsEmpty(*t_candidate) ||
			    MCStringFirstIndexOfChar(*t_candidate, '*', 0, kMCStringOptionCompareExact, t_offset))
				continue;
			if (*t_first_extension == nil)
				/* UNCHECKED */ MCStringCopy(*t_candidate, &t_first_extension);
			if (t_has_extension &&
			    MCStringIsEqualTo(*t_candidate, *t_extension, kMCStringOptionCompareCaseless))
			{
				r_label = MCValueRetain(t_parts[0]);
				break;
			}
		}
	}

	if (!t_has_extension && *t_first_extension != nil)
		/* UNCHECKED */ MCStringAppendFormat(x_name, ".%@", *t_first_extension);

	if (r_label == nil)
		r_label = t_first_label;
	else if (t_first_label != nil)
		MCValueRelease(t_first_label);
}

static int
MCEmscriptenAskFile(MCStringRef p_title,
                    MCStringRef p_prompt,
                    MCStringRef *p_types,
                    uindex_t p_type_count,
                    MCStringRef p_initial,
                    MCStringRef & r_value,
                    MCStringRef & r_result)
{
	/* The field shows the name of the initial file */
	MCAutoStringRef t_initial_name;
	uindex_t t_slash;
	if (p_initial == nil)
		t_initial_name = kMCEmptyString;
	else if (MCStringLastIndexOfChar(p_initial, '/', UINDEX_MAX, kMCStringOptionCompareExact, t_slash))
		/* UNCHECKED */ MCStringCopySubstring(p_initial, MCRangeMake(t_slash + 1, MCStringGetLength(p_initial) - t_slash - 1), &t_initial_name);
	else
		t_initial_name = p_initial;

	MCStringRef t_buttons[2] = { MCSTR("Cancel"), MCSTR("Save") };
	int32_t t_button;
	MCAutoStringRef t_text;
	if (!MCEmscriptenShowDialog(kMCEmscriptenDialogKindSave, 0, p_title, p_prompt,
	                            t_buttons, 2, *t_initial_name, t_button, &(&t_text)))
	{
		MCLog("ask file: the engine cannot wait for a dialog in a handler that the page called");
		return 0;
	}
	if (t_button != 1)
		return 0;

	/* A name, not a path: "/" in it becomes "_" */
	MCAutoStringRef t_name;
	if (!MCStringMutableCopy(*t_text, &t_name) ||
	    !MCEmscriptenTrim(*t_name) ||
	    !MCStringFindAndReplaceChar(*t_name, '/', '_', kMCStringOptionCompareExact) ||
	    MCStringIsEmpty(*t_name) ||
	    MCStringIsEqualToCString(*t_name, ".", kMCStringOptionCompareExact) ||
	    MCStringIsEqualToCString(*t_name, "..", kMCStringOptionCompareExact))
		return 0;

	MCStringRef t_label = nil;
	if (p_type_count > 0)
		MCEmscriptenAskFileType(p_types, p_type_count, *t_name, t_label);

	mkdir(kMCEmscriptenDownloadsFolder, 0777);

	if (!MCStringFormat(r_value, kMCEmscriptenDownloadsFolder "/%@", *t_name))
	{
		r_value = nil;
		if (t_label != nil)
			MCValueRelease(t_label);
		return 0;
	}
	if (t_label != nil)
		r_result = t_label;
	return 0;
}

int
MCA_ask_file(MCStringRef p_title,
             MCStringRef p_prompt,
             MCStringRef p_filter,
             MCStringRef p_initial,
             unsigned int p_options,
             MCStringRef & r_value,
             MCStringRef & r_result)
{
	return MCEmscriptenAskFile(p_title, p_prompt, nil, 0, p_initial, r_value, r_result);
}

int
MCA_ask_file_with_types(MCStringRef p_title,
                        MCStringRef p_prompt,
                        MCStringRef *p_types,
                        uint4 p_type_count,
                        MCStringRef p_initial,
                        unsigned int p_options,
                        MCStringRef & r_value,
                        MCStringRef & r_result)
{
	return MCEmscriptenAskFile(p_title, p_prompt, p_types, p_type_count, p_initial, r_value, r_result);
}

/* Parses "#rrggbb" */
static bool
MCEmscriptenParseHexColor(MCStringRef p_text, MCColor &r_color)
{
	MCAutoStringRefAsCString t_text;
	unsigned int t_red, t_green, t_blue;
	char t_extra;
	if (!t_text.Lock(p_text) ||
	    sscanf(*t_text, "#%2x%2x%2x%c", &t_red, &t_green, &t_blue, &t_extra) != 3)
		return false;

	/* 8-bit components to 16-bit ones, 0xff to 0xffff */
	r_color.red = t_red * 257;
	r_color.green = t_green * 257;
	r_color.blue = t_blue * 257;
	return true;
}

bool
MCA_color(MCStringRef p_title,
          MCColor p_initial_color,
          bool p_as_sheet,
          bool & r_chosen,
          MCColor & r_chosen_color)
{
	r_chosen = false;

	MCAutoStringRef t_initial;
	if (!MCStringFormat(&t_initial, "#%02x%02x%02x",
	                    p_initial_color.red >> 8, p_initial_color.green >> 8, p_initial_color.blue >> 8))
		return false;

	MCStringRef t_buttons[2] = { MCSTR("Cancel"), MCSTR("OK") };
	int32_t t_button;
	MCAutoStringRef t_text;
	if (!MCEmscriptenShowDialog(kMCEmscriptenDialogKindColor, 0, p_title, kMCEmptyString,
	                            t_buttons, 2, *t_initial, t_button, &(&t_text)))
	{
		MCLog("answer color: the engine cannot wait for a dialog in a handler that the page called");
		return true;
	}

	if (t_button == 1 && MCEmscriptenParseHexColor(*t_text, r_chosen_color))
		r_chosen = true;
	return true;
}

/* The page's colour picker has no custom colours */
void
MCA_setcolordialogcolors(MCColor *p_colors,
                         uindex_t p_count)
{
}

void
MCA_getcolordialogcolors(MCColor *& r_colors,
                         uindex_t & r_count)
{
	r_colors = nil;
	r_count = 0;
}
