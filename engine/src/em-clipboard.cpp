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

#include "em-clipboard.h"


// Implemented in em-clipboard.js: gives the browser's clipboard the
// text, HTML and PNG image of the system clipboard (each nil if it has
// none)
extern "C" void MCEmscriptenClipboardSetSystem(const byte_t *p_text, size_t p_text_length,
                                               const byte_t *p_html, size_t p_html_length,
                                               const byte_t *p_png, size_t p_png_length);


// The system clipboard, which em-clipboard.js fills with what the user
// pastes
static MCEmscriptenRawClipboard *s_system_clipboard = nil;

// The types of the representations, as MIME types. The clipboard keeps
// text as UTF-8 only.
static const char * const s_formats[kMCRawClipboardKnownTypeLast+1] =
{
    "text/plain;charset=utf-8",     // UTF-8 text
    NULL,                           // UTF-16 text
    NULL,                           // ISO-8859-1 text
    NULL,                           // MacRoman text
    NULL,                           // Windows codepage 1252 text

    "text/rtf",                     // Rich Text format
    "text/html",                    // HTML

    "image/png",                    // PNG image
    "image/gif",                    // GIF image
    "image/jpeg",                   // JPEG image
	"image/tiff",					// TIFF image
    NULL,                           // Windows metafile
    NULL,                           // Windows enhanced metafile
    NULL,                           // Windows bitmap
    NULL,                           // Windows v5 bitmap

    "application/x-revolution",     // LiveCode serialised objects
    "text/x-revolution-styled",     // LiveCode styled text

    NULL,                           // File path
    "application/x-livecode-file-list", // File path list (OXT-Beyond)
    NULL,                           // URL
    NULL,                           // URL list
};


MCRawClipboard* MCRawClipboard::CreateSystemClipboard()
{
    MCEmscriptenRawClipboard *t_clipboard = new (nothrow) MCEmscriptenRawClipboard(true);
    if (s_system_clipboard == nil)
        s_system_clipboard = t_clipboard;
    return t_clipboard;
}

MCRawClipboard* MCRawClipboard::CreateSystemSelectionClipboard()
{
    return new (nothrow) MCEmscriptenRawClipboard(false);
}

MCRawClipboard* MCRawClipboard::CreateSystemDragboard()
{
    return new (nothrow) MCEmscriptenRawClipboard(false);
}


////////////////////////////////////////////////////////////////////////////////


MCEmscriptenRawClipboard::MCEmscriptenRawClipboard(bool p_system) :
  m_item(NULL),
  m_system(p_system),
  m_dirty(false),
  m_external_data(false)
{
}

MCEmscriptenRawClipboard::~MCEmscriptenRawClipboard()
{
    if (s_system_clipboard == this)
        s_system_clipboard = nil;
    if (m_item != NULL)
        m_item->Release();
}

uindex_t MCEmscriptenRawClipboard::GetItemCount() const
{
    return m_item == NULL ? 0 : 1;
}

const MCEmscriptenRawClipboardItem* MCEmscriptenRawClipboard::GetItemAtIndex(uindex_t p_index) const
{
    if (p_index > 0 || m_item == NULL)
        return NULL;
    m_item->Retain();
    return m_item;
}

MCEmscriptenRawClipboardItem* MCEmscriptenRawClipboard::GetItemAtIndex(uindex_t p_index)
{
    if (p_index > 0 || m_item == NULL)
        return NULL;
    m_item->Retain();
    return m_item;
}

void MCEmscriptenRawClipboard::Clear()
{
    m_dirty = true;
    m_external_data = false;
    if (m_item != NULL)
        m_item->Release();
    m_item = NULL;
}

bool MCEmscriptenRawClipboard::IsOwned() const
{
    // The data is the engine's unless the user pasted it in
    return !m_external_data;
}

bool MCEmscriptenRawClipboard::IsExternalData() const
{
    return m_external_data;
}

MCEmscriptenRawClipboardItem* MCEmscriptenRawClipboard::CreateNewItem()
{
    // The clipboard holds one item
    if (m_item != NULL)
        return NULL;

    m_item = new (nothrow) MCEmscriptenRawClipboardItem(this);
    if (m_item == NULL)
        return NULL;
    m_item->Retain();
    return m_item;
}

bool MCEmscriptenRawClipboard::AddItem(MCRawClipboardItem* p_item)
{
    // The item was added when it was created
    if (m_item != p_item)
        return false;

    m_dirty = true;
    return true;
}

// Fetches the data of a representation of the item, or nil
static MCDataRef MCEmscriptenClipboardCopyRep(const MCEmscriptenRawClipboardItem *p_item, const char *p_type)
{
    if (p_item == NULL || p_type == NULL)
        return nil;
    const MCRawClipboardItemRep *t_rep = p_item->FetchRepresentationByType(MCSTR(p_type));
    if (t_rep == NULL)
        return nil;
    return t_rep->CopyData();
}

bool MCEmscriptenRawClipboard::PushUpdates()
{
    if (!m_dirty)
        return true;
    m_dirty = false;

    // The browser's clipboard follows the system clipboard (and pasting
    // from it is what makes external data, so that is never pushed)
    if (!m_system || m_external_data)
        return true;

    MCAutoDataRef t_text, t_html, t_png;
    t_text.Give(MCEmscriptenClipboardCopyRep(m_item, s_formats[kMCRawClipboardKnownTypeUTF8]));
    t_html.Give(MCEmscriptenClipboardCopyRep(m_item, s_formats[kMCRawClipboardKnownTypeHTML]));
    t_png.Give(MCEmscriptenClipboardCopyRep(m_item, s_formats[kMCRawClipboardKnownTypePNG]));

    MCEmscriptenClipboardSetSystem(*t_text != nil ? MCDataGetBytePtr(*t_text) : nil,
                                   *t_text != nil ? MCDataGetLength(*t_text) : 0,
                                   *t_html != nil ? MCDataGetBytePtr(*t_html) : nil,
                                   *t_html != nil ? MCDataGetLength(*t_html) : 0,
                                   *t_png != nil ? MCDataGetBytePtr(*t_png) : nil,
                                   *t_png != nil ? MCDataGetLength(*t_png) : 0);
    return true;
}

bool MCEmscriptenRawClipboard::PullUpdates()
{
    // What the user pastes is put on the clipboard when it is pasted
    // (MCEmscriptenClipboardAddExternal), so there is nothing to fetch
    return true;
}

bool MCEmscriptenRawClipboard::FlushData()
{
    return true;
}

uindex_t MCEmscriptenRawClipboard::GetMaximumItemCount() const
{
    return 1;
}

MCStringRef MCEmscriptenRawClipboard::GetKnownTypeString(MCRawClipboardKnownType p_type) const
{
    if (p_type > kMCRawClipboardKnownTypeLast || s_formats[p_type] == NULL)
        return NULL;
    return MCSTR(s_formats[p_type]);
}

// OXT-Beyond: a list of files is their paths in the engine's file
// system, one a line, as UTF-8. It stays in the page: the files that the
// user drops on a stack are copied into the engine's file system first
// (MCEmscriptenHandleDrop(), em-dc.cpp), and the browser's clipboard
// only ever gets the paths as text.
MCDataRef MCEmscriptenRawClipboard::EncodeFileListForTransfer(MCStringRef p_file_list) const
{
    MCDataRef t_data = nil;
    if (!MCStringEncode(p_file_list, kMCStringEncodingUTF8, false, t_data))
        return NULL;
    return t_data;
}

MCStringRef MCEmscriptenRawClipboard::DecodeTransferredFileList(MCDataRef p_data) const
{
    MCStringRef t_list = nil;
    if (!MCStringDecode(p_data, kMCStringEncodingUTF8, false, t_list))
        return NULL;
    return t_list;
}

// HTML is UTF-8 throughout
MCDataRef MCEmscriptenRawClipboard::EncodeHTMLFragmentForTransfer(MCDataRef p_html) const
{
	return MCValueRetain(p_html);
}

MCDataRef MCEmscriptenRawClipboard::DecodeTransferredHTML(MCDataRef p_html) const
{
	return MCValueRetain(p_html);
}

void MCEmscriptenRawClipboard::SetDirty()
{
    m_dirty = true;
}

void MCEmscriptenRawClipboard::BeginExternalData()
{
    Clear();
    m_dirty = false;
    m_external_data = true;
    m_item = new (nothrow) MCEmscriptenRawClipboardItem(this);
    if (m_item != NULL)
        m_item->Retain();
}

bool MCEmscriptenRawClipboard::AddExternalData(MCRawClipboardKnownType p_type, MCDataRef p_bytes)
{
    MCStringRef t_type = GetKnownTypeString(p_type);
    if (m_item == NULL || !m_external_data || t_type == NULL)
        return false;

    // AddRepresentation marks the clipboard dirty, but this data came
    // from the browser's clipboard
    bool t_success = m_item->AddRepresentation(t_type, p_bytes);
    m_dirty = false;
    return t_success;
}


////////////////////////////////////////////////////////////////////////////////


MCEmscriptenRawClipboardItem::MCEmscriptenRawClipboardItem(MCEmscriptenRawClipboard* p_clipboard) :
  m_clipboard(p_clipboard),
  m_reps()
{
}

MCEmscriptenRawClipboardItem::~MCEmscriptenRawClipboardItem()
{
    for (uindex_t i = 0; i < m_reps.Size(); i++)
        delete m_reps[i];
}

uindex_t MCEmscriptenRawClipboardItem::GetRepresentationCount() const
{
    return m_reps.Size();
}

const MCEmscriptenRawClipboardItemRep* MCEmscriptenRawClipboardItem::FetchRepresentationAtIndex(uindex_t p_index) const
{
    if (p_index >= m_reps.Size())
        return NULL;
    return m_reps[p_index];
}

bool MCEmscriptenRawClipboardItem::AddRepresentation(MCStringRef p_type, MCDataRef p_bytes)
{
    if (p_type == NULL || p_bytes == NULL)
        return false;

    m_clipboard->SetDirty();

    // Replace the representation of this type, if there is one
    for (uindex_t i = 0; i < m_reps.Size(); i++)
    {
        if (MCStringIsEqualTo(*m_reps[i]->m_type, p_type, kMCStringOptionCompareExact))
        {
            m_reps[i]->m_bytes.Reset(p_bytes);
            return true;
        }
    }

    MCEmscriptenRawClipboardItemRep *t_rep = new (nothrow) MCEmscriptenRawClipboardItemRep(p_type, p_bytes);
    if (t_rep == NULL)
        return false;

    uindex_t t_index = m_reps.Size();
    if (!m_reps.Extend(t_index + 1))
    {
        delete t_rep;
        return false;
    }
    m_reps[t_index] = t_rep;
    return true;
}

bool MCEmscriptenRawClipboardItem::AddRepresentation(MCStringRef p_type, render_callback_t p_callback, void* p_context)
{
    // Data is never rendered on demand
    return false;
}


////////////////////////////////////////////////////////////////////////////////


MCEmscriptenRawClipboardItemRep::MCEmscriptenRawClipboardItemRep(MCStringRef p_type, MCDataRef p_bytes) :
  m_type(p_type),
  m_bytes(p_bytes)
{
}

MCEmscriptenRawClipboardItemRep::~MCEmscriptenRawClipboardItemRep()
{
}

MCStringRef MCEmscriptenRawClipboardItemRep::CopyTypeString() const
{
    return MCValueRetain(*m_type);
}

MCDataRef MCEmscriptenRawClipboardItemRep::CopyData() const
{
    return MCValueRetain(*m_bytes);
}


////////////////////////////////////////////////////////////////////////////////

// Called by em-clipboard.js when the user pastes into the page: the
// system clipboard's data becomes what was pasted, one representation
// at a time (p_type is a MCRawClipboardKnownType)

extern "C" MC_DLLEXPORT_DEF
void MCEmscriptenClipboardBeginExternal()
{
    if (s_system_clipboard != nil)
        s_system_clipboard->BeginExternalData();
}

extern "C" MC_DLLEXPORT_DEF
bool MCEmscriptenClipboardAddExternal(uint32_t p_type, const byte_t *p_bytes, uint32_t p_length)
{
    if (s_system_clipboard == nil || p_type > kMCRawClipboardKnownTypeLast)
        return false;

    MCAutoDataRef t_data;
    if (!MCDataCreateWithBytes(p_bytes, p_length, &t_data))
        return false;

    return s_system_clipboard->AddExternalData(MCRawClipboardKnownType(p_type), *t_data);
}
