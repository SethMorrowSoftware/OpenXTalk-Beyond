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


#ifndef EMSCRIPTEN_CLIPBOARD_H
#define EMSCRIPTEN_CLIPBOARD_H


#include "raw-clipboard.h"
#include "foundation-auto.h"


class MCEmscriptenRawClipboard;
class MCEmscriptenRawClipboardItem;


/* A representation of the item on a clipboard: its type and its data */
class MCEmscriptenRawClipboardItemRep :
  public MCRawClipboardItemRep
{
public:

    // Inherited from MCRawClipboardItemRep
    virtual MCStringRef CopyTypeString() const;
    virtual MCDataRef CopyData() const;

private:

    MCAutoStringRef m_type;
    MCAutoDataRef m_bytes;

    // Controlled by the parent MCEmscriptenRawClipboardItem
    friend class MCEmscriptenRawClipboardItem;
    MCEmscriptenRawClipboardItemRep(MCStringRef p_type, MCDataRef p_bytes);
    ~MCEmscriptenRawClipboardItemRep();
};


class MCEmscriptenRawClipboardItem :
  public MCRawClipboardItem
{
public:

    // Inherited from MCRawClipboardItem
    virtual uindex_t GetRepresentationCount() const;
    virtual const MCEmscriptenRawClipboardItemRep* FetchRepresentationAtIndex(uindex_t p_index) const;
    virtual bool AddRepresentation(MCStringRef p_type, MCDataRef p_bytes);
    virtual bool AddRepresentation(MCStringRef p_type, render_callback_t, void* p_context);

private:

    MCEmscriptenRawClipboard* m_clipboard;
    MCAutoArray<MCEmscriptenRawClipboardItemRep*> m_reps;

    // Lifetime is managed by the parent MCEmscriptenRawClipboard
    friend class MCEmscriptenRawClipboard;
    MCEmscriptenRawClipboardItem(MCEmscriptenRawClipboard* p_clipboard);
    ~MCEmscriptenRawClipboardItem();
};


/* The engine's clipboards on the web hold their data themselves: the
 * page cannot read the system's clipboard when it likes. The system
 * clipboard (the clipboard of the copy, cut and paste commands and of
 * the clipboardData) gives what is copied to the browser's clipboard,
 * and gets what the user pastes from it (em-clipboard.js). */
class MCEmscriptenRawClipboard :
  public MCRawClipboard
{
public:

    // Inherited from MCRawClipboard
    virtual uindex_t GetItemCount() const;
    virtual const MCEmscriptenRawClipboardItem* GetItemAtIndex(uindex_t p_index) const;
    virtual MCEmscriptenRawClipboardItem* GetItemAtIndex(uindex_t p_index);
    virtual void Clear();
    virtual bool IsOwned() const;
    virtual bool IsExternalData() const;
    virtual MCEmscriptenRawClipboardItem* CreateNewItem();
    virtual bool AddItem(MCRawClipboardItem* p_item);
    virtual bool PushUpdates();
    virtual bool PullUpdates();
    virtual bool FlushData();
    virtual uindex_t GetMaximumItemCount() const;
    virtual MCStringRef GetKnownTypeString(MCRawClipboardKnownType p_type) const;
    virtual MCDataRef EncodeFileListForTransfer(MCStringRef p_file_list) const;
    virtual MCStringRef DecodeTransferredFileList(MCDataRef p_data) const;
	virtual MCDataRef EncodeHTMLFragmentForTransfer(MCDataRef p_html) const;
	virtual MCDataRef DecodeTransferredHTML(MCDataRef p_html) const;

    // Marks the data as changed
    void SetDirty();

    // Replaces the data with what the user pasted into the page
    void BeginExternalData();
    bool AddExternalData(MCRawClipboardKnownType p_type, MCDataRef p_bytes);

    // p_system: the system clipboard, which the browser's clipboard
    // follows
    MCEmscriptenRawClipboard(bool p_system);

private:

    ~MCEmscriptenRawClipboard();

    // The clipboard's one item
    MCEmscriptenRawClipboardItem* m_item;

    bool m_system;
    bool m_dirty;
    bool m_external_data;
};


#endif  /* ifndef EMSCRIPTEN_CLIPBOARD_H */
