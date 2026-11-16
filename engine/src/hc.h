/* Copyright (C) 2003-2015 LiveCode Ltd.

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

//
// HyperMCCard import functions
//

#define HC_HEADER_SIZE 2048

#define HC_MESSAGE_LENGTH 256

enum HC_File_type {
    HC_RAW,
    HC_MACBIN,
    HC_BINHEX,
    HC_APPLESINGLE_FILE
};

#define HC_STAK 0x5354414b
#define HC_MAST 0x4d415354
#define HC_LIST 0x4c495354
#define HC_PAGE 0x50414745
#define HC_BKGD 0x424b4744
#define HC_CARD 0x43415244
#define HC_BMAP 0x424d4150
#define HC_STBL 0x5354424c
#define HC_FTBL 0x4654424c
#define HC_FREE 0x46524545
#define HC_PRNT 0x50524e54
#define HC_PRFT 0x50524654
#define HC_PRST 0x50525354
#define HC_TAIL 0x5441494c
#define HC_BUGS 0xFFFF5354

#define HC_ICON 0x49434f4e
#define HC_CURS 0x43555253
#define HC_SND  0x736e6420
#define HC_PICT 0x50494354
#define HC_PLTE 0x504c5445
#define HC_HCCD 0x48436364
#define HC_HCBG 0x48436267

#define HC_F_MULTIPLE       0x0010
#define HC_F_MARGINS        0x0020
#define HC_F_SHOW_LINES     0x0040
#define HC_F_AUTO_SELECT    0x0080
#define HC_F_LOCK_TEXT      0x0100
#define HC_F_AUTO_TAB       0x0200
#define HC_F_UNFIXED_HEIGHT 0x0400
#define HC_F_SHARED_TEXT    0x0800
#define HC_F_DONT_SEARCH    0x1000
#define HC_F_DONT_WRAP      0x2000
#define HC_F_INVISIBLE      0x8000

#define HC_FSTYLE_TRANS     0
#define HC_FSTYLE_OPAQUE    1
#define HC_FSTYLE_RECT      2
#define HC_FSTYLE_SHADOW    4
#define HC_FSTYLE_SCROLL    7

#define HC_B_NOT_SHARED     0x0010
#define HC_B_AUTO_HILITE    0x0020
#define HC_B_HILITED        0x0040
#define HC_B_SHOW_NAME      0x0080
#define HC_B_DISABLED       0x0100
#define HC_B_INVISIBLE      0x8000

#define HC_BSTYLE_TRANS     0
#define HC_BSTYLE_OPAQUE    1
#define HC_BSTYLE_RECT      2
#define HC_BSTYLE_ROUND     3
#define HC_BSTYLE_SHADOW    4
#define HC_BSTYLE_CHECK     5
#define HC_BSTYLE_RADIO     6
#define HC_BSTYLE_STANDARD  8
#define HC_BSTYLE_DEFAULT   9
#define HC_BSTYLE_OVAL      10
#define HC_BSTYLE_POPUP     11

#define HC_BC_DONT_SEARCH   0x08
#define HC_BC_HIDE_BMAP     0x20
#define HC_BC_CANT_DELETE   0x40

#define HC_OTYPE_BUTTON     0x01
#define HC_OTYPE_FIELD      0x02

#define HC_TSTYLE_BOLD       0x0100
#define HC_TSTYLE_ITALIC     0x0200
#define HC_TSTYLE_UNDERLINE  0x0400
#define HC_TSTYLE_OUTLINE    0x0800
#define HC_TSTYLE_SHADOW     0x1000
#define HC_TSTYLE_CONDENSE   0x2000
#define HC_TSTYLE_EXTEND     0x4000
#define HC_TSTYLE_GROUP      0x8000

#define HC_TALIGN_LEFT       0x00
#define HC_TALIGN_CENTER     0x01
#define HC_TALIGN_RIGHT      0xFF

#define HC_DEFAULT_TEXT_FONT "helvetica"
#define HC_DEFAULT_TEXT_SIZE 12

#define HC_NICONS            192
#define HC_DEFAULT_ICON      330

class MCHcstak;
class MCCdata;
class MCCard;
class MCGroup;
class MCObjptr;
class MCControl;

struct Hcfont
{
	uint2 id;
	const char *name;
};

struct Hcatts
{
	uint2 id;
	uint2 fid;
	uint2 size;
	uint2 style;
};

class MCHcsnd : public MCDLlist
{
public:
	MCNameRef m_name;
	int1 *data;
	uint4 size;
	uint2 rate;
	uint2 id;
	// 1 or 2 channels, interleaved; 1 byte a sample (signed), or 2 (signed,
	// big-endian, as an AIFF file's)
	uint2 channels;
	uint2 width;
	// why import() refused the sound, for the import log, or NULL
	const char *refusal;
	MCHcsnd();
	~MCHcsnd();
	Boolean import(uint4 inid, MCNameRef inname, char *sptr, uint4 p_length);
	Boolean importextended(const char *sptr, uint4 p_length, uint4 hsize, uint1 p_encode);
	MCAudioClip *build();
	MCHcsnd *next()
	{
		return (MCHcsnd *)MCDLlist::next();
	}
	void appendto(MCHcsnd *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHcsnd *remove
	(MCHcsnd *&list)
	{
		return (MCHcsnd *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

class MCHctext : public MCDLlist
{
public:
	// the style runs: nruns (offset, style id) pairs, then the text length
	uint2 *atts;
	uint2 nruns;
	char *string;
	Boolean card;
	uint2 id;
	uint4 cid;
	MCHctext();
	~MCHctext();
	IO_stat parse(char *sptr, uint4 p_avail, uint4 &r_length);
	MCCdata *buildf(MCHcstak *hcsptr, MCField *parent);
	MCCdata *buildb();
	char *buildm();
	MCHctext *next()
	{
		return (MCHctext *)MCDLlist::next();
	}
	void appendto(MCHctext *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHctext *remove
	(MCHctext *&list)
	{
		return (MCHctext *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

class MCHcfield : public MCDLlist
{
public:
    char *name;
    char *script;
	MCRectangle rect;
	uint2 id;
	uint2 atts;
	uint2 style;
	uint2 tfont;
	uint2 tsize;
	uint2 tstyle;
	uint2 talign;
	uint2 theight;
	uint2 hctstyle;
	MCHctext *text;
	MCHcfield();
	~MCHcfield();
	IO_stat parse(char *sptr, uint4 p_size);
	MCControl *build(MCHcstak *hcsptr, MCStack *sptr);
	MCHcfield *next()
	{
		return (MCHcfield *)MCDLlist::next();
	}
	void appendto(MCHcfield *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHcfield *remove
	(MCHcfield *&list)
	{
		return (MCHcfield *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

class MCHcbutton : public MCDLlist
{
public:
    char *name;
    char *script;
	MCRectangle rect;
	uint2 titlewidth;
	uint2 icon;
	uint2 id;
	uint2 atts;
	uint2 style;
	uint2 tfont;
	uint2 tsize;
	uint2 tstyle;
	uint2 talign;
	uint2 hctstyle;
	MCHctext *text;
	MCHcbutton();
	~MCHcbutton();
	IO_stat parse(char *sptr, uint4 p_size);
	MCControl *build(MCHcstak *hcsptr, MCStack *sptr);
	MCHcbutton *next()
	{
		return (MCHcbutton *)MCDLlist::next();
	}
	void appendto(MCHcbutton *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHcbutton *remove
	(MCHcbutton *&list)
	{
		return (MCHcbutton *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

class MCHcbmap : public MCDLlist
{
public:
	uint4 id;
	MCRectangle rect;
	MCRectangle mrect;
	Boolean visible;
	// IM-2014-04-08: [[ Bug 12101 ]] Buffers to hold 1-bit bitmaps - dimensions stored in rect (data), mrect (mask)
	uint8_t *mask;
	uint8_t *data;
    MCNameRef m_name;
	uint2 xhot;
	uint2 yhot;
	MCHcbmap();
	~MCHcbmap();
	void setvisible(Boolean newvis);
	void icon(uint4 inid, MCNameRef inname, char *sptr, uint4 p_length);
	void cursor(uint4 inid, MCNameRef inname, char *sptr, uint4 p_length);
	IO_stat parse(char *sptr, uint4 p_size);
	MCControl *build();
	MCHcbmap *next()
	{
		return (MCHcbmap *)MCDLlist::next();
	}
	void appendto(MCHcbmap *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHcbmap *remove
	(MCHcbmap *&list)
	{
		return (MCHcbmap *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

class MCHccard : public MCDLlist
{
public:
	char *name;
	char *script;
	uint2 nobjects;
	uint2 *objects;
	MCHcbutton *hcbuttons;
	MCHcfield *hcfields;
	MCHctext *hctexts;
	uint4 bkgdid;
	uint4 bmapid;
	uint1 atts;
	uint4 id;
	MCHccard();
	~MCHccard();
	IO_stat parse(char *sptr, uint4 p_size);
	MCCard *build(MCHcstak* hcsptr, MCStack *sptr);
	MCHccard *next()
	{
		return (MCHccard *)MCDLlist::next();
	}
	void appendto(MCHccard *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHccard *remove
	(MCHccard *&list)
	{
		return (MCHccard *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

// A PICT resource, decoded (hcpict.cpp)
class MCHcpict : public MCDLlist
{
public:
	MCNameRef m_name;
	uint4 id;
	uint32_t *pixels;
	uint32_t width;
	uint32_t height;
	MCHcpict();
	~MCHcpict();
	// p_ink: the image's ink, when not the template image's
	MCControl *build(uint4 p_id, bool p_keep = false, int p_ink = -1);
	MCHcpict *next()
	{
		return (MCHcpict *)MCDLlist::next();
	}
	void appendto(MCHcpict *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHcpict *remove
	(MCHcpict *&list)
	{
		return (MCHcpict *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

// A PLTE resource: a HyperCard 2 palette, a PICT with buttons on it that
// send messages, opened with "palette"
class MCHcplte : public MCDLlist
{
public:
	MCNameRef m_name;
	uint4 id;
	uint1 *data;
	uint4 size;
	MCHcplte();
	~MCHcplte();
	MCStack *build(MCHcstak *hcsptr, MCStack *p_main);
	MCHcplte *next()
	{
		return (MCHcplte *)MCDLlist::next();
	}
	void appendto(MCHcplte *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHcplte *remove
	(MCHcplte *&list)
	{
		return (MCHcplte *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

// An HCcd or HCbg resource: AddColor's colours for the card or background
// with the resource's id, and, once drawn, the image that carries them and
// where it goes
class MCHcaddcolor : public MCDLlist
{
public:
	uint4 id;
	bool card;
	uint1 *data;
	uint4 size;
	MCHcpict *layer;
	MCCard *cptr;
	MCObjptr *cafter;
	MCGroup *gptr;
	MCControl *gafter;
	MCHcaddcolor();
	~MCHcaddcolor();
	bool draw(MCHcstak *hcsptr, MCHcbutton *p_buttons, MCHcfield *p_fields);
	MCHcaddcolor *next()
	{
		return (MCHcaddcolor *)MCDLlist::next();
	}
	void appendto(MCHcaddcolor *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHcaddcolor *remove
	(MCHcaddcolor *&list)
	{
		return (MCHcaddcolor *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

class MCHcbkgd : public MCDLlist
{
public:
	char *name;
	char *script;
	uint2 nobjects;
	uint2 *objects;
	MCHcbutton *hcbuttons;
	MCHcfield *hcfields;
	MCHctext *hctexts;
	uint4 id;
	uint4 bkgdid;
	// the next background in the stack's chain of backgrounds
	uint4 nextid;
	uint4 bmapid;
	uint1 atts;
	MCHcbkgd();
	~MCHcbkgd();
	IO_stat parse(char *sptr, uint4 p_size);
	MCGroup *build(MCHcstak* hcsptr, MCStack *sptr);
	MCHcbkgd *next()
	{
		return (MCHcbkgd *)MCDLlist::next();
	}
	void appendto(MCHcbkgd *&list)
	{
		MCDLlist::appendto((MCDLlist *&)list);
	}
	MCHcbkgd *remove
	(MCHcbkgd *&list)
	{
		return (MCHcbkgd *)MCDLlist::remove
			       ((MCDLlist *&)list);
	}
};

class MCHcstak
{
public:
	MCRectangle rect;
	char *name;
	char *script;
	char *fullbuffer;
	char *buffer;
	uint4 *pages;
	uint1 *marks;
	uint4 npages;
	struct Hcfont *fonts;
	struct Hcatts *atts;
	uint2 nfonts;
	uint2 natts;
	uint2 pagesize;
	uint4 npbuffers;
	uint4 *pbuffersizes;
	uint4 *pbufferids;
	char **pbuffers;
	// the order of the PAGE blocks and their card counts, from the LIST block
	uint4 nlistpages;
	// the first background in the chain the STAK block starts
	uint4 firstbkgd;
	uint4 *listpageids;
	uint4 *listpagecounts;
	// the FTBL blocks, which hold the font names
	uint4 nfontbuffers;
	char **fontbuffers;
	MCHcbkgd *hcbkgds;
	MCHccard *hccards;
	MCHcbmap *hcbmaps;
	MCHcbmap *icons;
	MCHcbmap *cursors;
	MCHcsnd *snds;
	MCHcpict *pictures;
	MCHcplte *palettes;
	MCHcaddcolor *addcolors;
	// the path of the file being imported, or nil
	MCStringRef path;
	// the resource fork's inventory and where it came from, for the stack's
	// custom property set "uHyperCard"
	MCListRef resourcelist;
	MCListRef externallist;
	MCStringRef forksource;
	MCHcstak(char *inname);
	~MCHcstak();
	uint4 geticon(uint2 iid);
	MCHcbmap *getbmap(uint4 bid);
	MCHcbmap *removebmap(uint4 bid);
	MCHcbkgd *getbkgd(uint4 bid);
	MCHcaddcolor *getaddcolor(bool p_card, uint4 p_id);
	const char *getfont(uint2 fid);
	void getatts(uint2 aid, const char *&font, uint2 &size, uint2 &style);
	IO_stat read(IO_handle stream);
	IO_stat readblocks(const uint1 *p_data, uint4 p_size);
	void readresources(const uint1 *p_fork, uint4 p_size);
	bool readresourcefile(MCStringRef p_path, bool p_log);
	void noteresource(const char *p_type, uint2 p_id, MCNameRef p_name, uint4 p_size);
	void setforksource(const char *p_source);
	void storeinventory(MCStack *p_stack);
	bool readsidecarresources();
	MCStack *build();
	
#ifdef _MAC_DESKTOP
	IO_stat macreadresources(void);
#endif
};

extern IO_stat hc_import(MCStringRef p_name, IO_handle p_stream, MCStack *&p_sptr);

