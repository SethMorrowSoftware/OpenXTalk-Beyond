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

#include <cstdlib> 
#include <cstdio> 
#include <cmath> 
#include <ctime>
#include <vector>

#include <revolution/external.h>
#include <revolution/support.h>
#include <libxml/xpath.h>
#include <libxml/parserInternals.h>
#include <libxml/pattern.h>
#include <libxml/uri.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>

#include "cxml.h"

#define istrdup strdup

#define INTSTRSIZE 16

#ifdef _MACOSX

char *_strrev(char *str)
{
	int SmallIndex = 0;
	int BigIndex = strlen(str) - 1;
	
	while (SmallIndex < BigIndex) {
		char Temp = str[SmallIndex];
		
		str[SmallIndex] = str[BigIndex];
		str[BigIndex] = Temp;
		
		SmallIndex++;
		BigIndex--;
	}
	
	return str;
}

char *strlwr(char *str)
{
    while (*str)
    {
        *str = tolower(*str);
        str++;
    }
    return str;
}

#endif

#if defined _LINUX || defined(TARGET_SUBPLATFORM_ANDROID)
#define stricmp strcasecmp


char *_strrev(char * str)
{
	int SmallIndex = 0;
	int BigIndex = strlen(str) - 1;
	
	while (SmallIndex < BigIndex) {
		char Temp = str[SmallIndex];
		
		str[SmallIndex] = str[BigIndex];
		str[BigIndex] = Temp;
		
		SmallIndex++;
		BigIndex--;
	}
	
	return str;
	}

char *strlwr(char *str)
{
    while (*str)
    {
        *str = tolower(*str);
        str++;
    }
    return str;
}

#endif


using namespace std;

typedef vector<CXMLDocument *> VXMLDocList;

enum XMLErrs
{
	XMLERR_BADARGUMENTS,
	XMLERR_BADXML,
	XMLERR_BADELEMENT,
	XMLERR_BADATTRIBUTE,
	XMLERR_BADDOCID,
	XMLERR_BADDTD,
	XMLERR_LICENSE,
	XMLERR_BADMOVE,
	XMLERR_BADCOPY,
	XMLERR_NOFILEPERMS,
	XPATHERR_BADDOCCONTEXT,
	XPATHERR_CANTRESOLVE,
	XPATHERR_BADDOCPOINTER,
};

const char *xmlerrors[] = {
	"xmlerr, invalid number of arguments",
	"xmlerr, can't parse xml",
	"xmlerr, can't find element",
	"xmlerr, can't find attribute",
	"xmlerr, bad document id",
	"xmlerr, validation error",
	"xmlerr, restricted under current license",
	"xmlerr, can't move node into itself",
	"xmlerr, can't copy node into itself",
	"xmlerr, file access not permitted",
	"xmlerr, couldn't assign document context",
	"xmlerr, can't resolve xpath",
	"xmlerr, bad document pointer",
};

//HS-2010-10-11: [[ Bug 7586 ]] Reinstate libxml2 to create name spaces. Implement new liveCode commands to suppress name space creation.
Bool XML_ProcessNameSpaces = True;

//A class wrapped around a vector object used to keep a list of parsed XML documents
class XMLDocumentList
{
	public:
		//when class terminates make sure to free all documents 
		~XMLDocumentList() {clear();} 
	//loop through, and free all documents
	void clear()
	{
	
		if (doclist.empty()) 
			return;
		VXMLDocList::iterator theIterator;
		for (theIterator = doclist.begin(); theIterator != doclist.end(); theIterator++){
			CXMLDocument *curobject = (CXMLDocument *)(*theIterator);
			// Deleting the object frees its XPath context and stylesheet
			//   (CXMLDocument::Free) as well as its document.
			delete curobject;
		}
		doclist.clear();
	}
	VXMLDocList *getList() {return &doclist;}
	//remove document from list by document id.
	Bool erase(const int fid) 
	{
		VXMLDocList::iterator theIterator;
		for (theIterator = doclist.begin(); theIterator != doclist.end(); theIterator++){
			CXMLDocument *curobject = (CXMLDocument *)(*theIterator);
			if (curobject->GetID() == fid){
				delete curobject;
				doclist.erase(theIterator);
				return True;
			}
		}
		return False;
	}
	//find CXMLDocument by document id
	CXMLDocument *find(const int fid) 
	{
		VXMLDocList::iterator theIterator;
		for (theIterator = doclist.begin(); theIterator != doclist.end(); theIterator++){
			CXMLDocument *curobject = (CXMLDocument *)(*theIterator);
			if (curobject->GetID() == fid)
				return curobject;
		}		
		return NULL;
	}
	//return size of list
	int getsize() {return doclist.size();}
	//add xml document to list
	void add(CXMLDocument *newxmldoc) {doclist.push_back(newxmldoc);}
	protected:
		VXMLDocList doclist;

};


XMLDocumentList doclist;


//DUMMY FUNCTIONS TO KEEP LIBXML FROM DISPLAYING A CONSOLE WINDOW


void REVXML_INIT()
{

}

void REVXML_QUIT()
{
		doclist.clear();
}

//------------------------------------UTILITY FUNCTIONS--------------------------
void DispatchMetaCardMessage(const char *messagename, const char *tmessage)
{
int retvalue = 0;
SetGlobal("xmlvariable",tmessage,&retvalue);
char mcmessage[256];
// MDW-2013-07-09: [[ RevXmlXPath ]]
sprintf(mcmessage,"global xmlvariable;try;send \"%s xmlvariable\" to current card of stack the topstack;catch errno;end try;put 0 into xmlvariable",messagename);
SendCardMessage(mcmessage, &retvalue);
}

bool stringToBool(const char *p_string)
{
	if (stricmp(p_string, "true") == 0)
		return true;
	else
		return false;

}

//------------------------------------XML MESSAGES----------------------------------------

/*MESSAGE: startDocument - Called when starting parsing document*/
void CB_startDocument()
{
	DispatchMetaCardMessage("revxmlStartTree","");
}

/*MESSAGE: endDocument - Called when finished parsing document*/
void CB_endDocument()
{
	DispatchMetaCardMessage("revxmlEndTree","");
}

/*MESSAGE: startElement attlist - Called when an element's opening tag is encountered, with 
a return delimited list of attribute names and values*/
void CB_startElement(const char *name, const char **attributes)
{
	char *buffer = NULL;
	int bufsize = 0,buflen = 0;
	if (attributes) {
		const char **cur;
		for(cur = attributes; cur && *cur; cur++) {
			util_concatstring((char *)*cur, strlen(*cur), buffer, buflen , bufsize);
			util_concatstring(",", 1 ,buffer, buflen , bufsize);
			cur++;
			util_concatstring((char *)*cur, strlen(*cur), buffer, buflen , bufsize);
			util_concatstring("\n", 1 ,buffer, buflen , bufsize);
		}
	}
	if (buflen)
		buffer[buflen-1] = '\0';
	int retvalue = 0;
	char mcmessage[256];
	SetGlobal("xmlvariable",buffer,&retvalue);
	sprintf(mcmessage,"global xmlvariable;send \"revStartXMLNode %s,xmlvariable\" to current card of stack the topstack;put 0 into xmlvariable",
		name);
	SendCardMessage(mcmessage, &retvalue);
}

/*MESSAGE: endElement - Called when an element's closing tag is encountered, or immediately\par
tab after start_element() if the tag is in <tag/> format.*/
void CB_endElement(const char *name)
{
	DispatchMetaCardMessage("revEndXMLNode",(char *)name);
}


//MESSAGE: XMLElementData data - sent when element data is encountered between tags
void CB_elementData(const char *data, int length)
{
	char *buffer = new (nothrow) char[length+1];
	memcpy(buffer, data, length);
	buffer[length] = '\0';
	DispatchMetaCardMessage("revStartXMLData",(char *)buffer);
	delete[] buffer;
}


static Bool REVXMLinited = False;

#define simpleparse(a,b,c) (((b > a) | (c < a))?True:False)

// The path of a file for libxml2 or libxslt to open, in UTF-8, in a new
//   buffer. The engine passes revXML's arguments in the native encoding
//   (Windows-1252 on Windows, ISO-8859-1 on Linux), and libxml2 2.15 opens
//   files on Windows only through UTF-8: its 2.9 build fell back to the
//   native encoding. So convert the path, as revdb does for SQLite (bug
//   6429). On Linux that also opens files with accented names, which the
//   engine names in UTF-8; on macOS the path was already UTF-8.
// A script that worked around the old build on Linux passes a path that
//   is UTF-8 already, which the conversion encodes a second time: when the
//   converted path opens nothing and the path as given opens a file, the
//   path as given is used (it is UTF-8, as libxml2 needs).
static bool revxml_path_opens(const char *p_path)
{
	// libxml2's own open (on Windows, the path is UTF-8 there too);
	//   xmlCheckFilename is deprecated.
	xmlParserInputPtr t_input;
	t_input = NULL;
	if (xmlNewInputFromUrl(p_path, (xmlParserInputFlags)0, &t_input) != XML_ERR_OK || t_input == NULL)
		return false;
	xmlFreeInputStream(t_input);
	return true;
}

// A URL on the network (http:// or ftp://) as libxml2 2.9 passed it on
//   (its xmlCanonicPath): as it is when it is a URI, else with what a URI
//   may not hold escaped ("sp ace.xml" is "sp%20ace.xml"), native text
//   byte by byte ("caf%E9"). A URL is not a file name, so it is not
//   converted to UTF-8. libxml2 2.15 escapes URLs too, but not those that
//   revXML loads itself (revxml_load_url), and in another way.
static char *revxml_url_for_libxml(const char *p_url)
{
	xmlURIPtr t_uri;
	xmlChar *t_escaped;
	char *t_url;
	t_url = istrdup(p_url);
	if (t_url == NULL)
		return NULL;
#ifdef _WIN32
	// On Windows the URL comes in the path form that os_path_resolve made of
	//   it ("http:\\host\doc.xml"), which would be escaped as "http:%5C%5C...":
	//   its '\' are made '/' again first, as libxml2 does with a URL that is
	//   still in that form (xmlNewInputFromUrl).
	for (char *t_char = t_url; *t_char != '\0'; t_char++)
		if (*t_char == '\\')
			*t_char = '/';
#endif
	t_uri = xmlParseURI(t_url);
	if (t_uri != NULL)
	{
		xmlFreeURI(t_uri);
		return t_url;
	}
	t_escaped = xmlURIEscapeStr((const xmlChar *)t_url, (const xmlChar *)":/?_.#&;=");
	if (t_escaped != NULL)
	{
		t_uri = xmlParseURI((const char *)t_escaped);
		if (t_uri != NULL)
		{
			char *t_result;
			xmlFreeURI(t_uri);
			t_result = istrdup((const char *)t_escaped);
			if (t_result != NULL)
			{
				free(t_url);
				t_url = t_result;
			}
		}
		xmlFree(t_escaped);
	}
	return t_url;
}

// The path of the file: URL p_url as it is written, not unescaped, or NULL
//   when p_url is not a file: URL (the forms libxml2 2.9's xmlFileOpen
//   took).
static const char *revxml_file_url_path(const char *p_url)
{
	const char *t_path;
	if (xmlStrncasecmp((const xmlChar *)p_url, (const xmlChar *)"file://localhost/", 17) == 0)
		t_path = p_url + 16;
	else if (xmlStrncasecmp((const xmlChar *)p_url, (const xmlChar *)"file:///", 8) == 0)
		t_path = p_url + 7;
	else if (xmlStrncasecmp((const xmlChar *)p_url, (const xmlChar *)"file:/", 6) == 0)
		t_path = p_url + 5;
	else
		return NULL;
#ifdef _WIN32
	// "file:///C:/dir/doc.xml"
	t_path += 1;
#endif
	return t_path;
}

static char *revxml_path_for_libxml(const char *p_path)
{
	char *t_path;
	const char *t_literal;
	if (revxml_network_url(p_path))
		return revxml_url_for_libxml(p_path);
	t_path = os_path_to_native_utf8(p_path);
	if (t_path != NULL && strcmp(t_path, p_path) != 0 &&
		!revxml_path_opens(t_path) && revxml_path_opens(p_path))
	{
		char *t_given;
		t_given = istrdup(p_path);
		if (t_given != NULL)
		{
			free(t_path);
			t_path = t_given;
		}
	}
	// A file: URL with a '%' in its path that names a file as it is written
	//   ("file:/dir/a%41.xml" when there is an a%41.xml) is that file, as
	//   2.9 read it: its xmlFileOpen tried the path as written before it
	//   unescaped it. 2.15 always unescapes it (aA.xml), so the path is
	//   passed instead of the URL.
	t_literal = t_path != NULL ? revxml_file_url_path(t_path) : NULL;
	if (t_literal != NULL && strchr(t_literal, '%') != NULL && revxml_path_opens(t_literal))
	{
		char *t_file;
		t_file = istrdup(t_literal);
		if (t_file != NULL)
		{
			free(t_path);
			t_path = t_file;
		}
	}
	return t_path;
}


#ifndef REVDB
static int computehash(char *keystr)
{
	unsigned int value = 0;
	int length = strlen(keystr);
	const char *sptr = keystr;
	while (length--){
		value += tolower(*sptr++);
		value = value * 3;
	}
	return value & 96000 -1;
}
#else
extern int computehash(char *keystr);
extern char * _strrev(char * str);
extern char *strlwr(char *str);
#endif


// MDW-2013-06-22: [[ RevXmlXPath ]]
#define REVXML_VERSIONSTRING "6.5.0"

void REVXML_Version(char *args[], int nargs, char **retstring,
		   Bool *pass, Bool *error)
{
	char *result = NULL;
	*error = False;
	*pass = False;
	 result = istrdup(REVXML_VERSIONSTRING);
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

void XML_Init(char *args[], int nargs, char **retstring,
				Bool *pass, Bool *error)
{
	int count;
	static Bool littlecheat = False;
	char *buffer;
	int passkey = 0;
	char lencode[] = "clubfvhsqkjpymziadgxonrev";
    *pass = False;
	if (nargs == 2){*error = False;
	buffer = istrdup(args[0]);
	strlwr(buffer);
	
	_strrev(buffer);
	int keylen = strlen(buffer);
	if (simpleparse(keylen,5,40) == True || littlecheat == True)
	{*retstring = istrdup("FALSE"); free(buffer);return;}
	for (count=0;count<keylen;count++) 
		if (simpleparse(buffer[count]-97,0,26) == True){
			*retstring = istrdup("FALSE"); 
			free(buffer);
			return;
		}
		else buffer[count] = lencode[buffer[count]-97];
		passkey = computehash(buffer);
		free(buffer);
		if (atoi(args[1]) == passkey || REVXMLinited == True) {
			*retstring = istrdup("TRUE");
			REVXMLinited = True;
		}
		else {
			*retstring = istrdup("FALSE");
			littlecheat = True;
		}
	}
	else *error = True; *retstring = (char *)calloc(1, 1);
}

//------------------------------------DOCUMENT CALLBACKS--------------------------------------
/*
Function: XML_NewDocument - Parse XML document/data
Input: [0]=xml data
[1] = flag to determine whether to try parse xml data that is not well formed 
(ie. be forgiving)
Output: XML document ID. On error, 'can't parse xml' and error message.
Example: if xml_newdocument(data) is a number then beep
*/
void XML_NewDocument(char *args[], int nargs, char **retstring,
					 Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;

	if (nargs < 2){

		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		CXMLDocument *newdoc = new (nothrow) CXMLDocument;

		Bool wellformed = util_strnicmp(args[1],"TRUE",4) == 0;
		
		Bool buildtree = True;
		Bool sendmessages = False;
		if (nargs >= 3)
			buildtree = util_strnicmp(args[2],"TRUE",4) == 0;
		if (nargs >= 4)
			sendmessages = util_strnicmp(args[3],"TRUE",4) == 0;
		CXMLDocument::allowcallbacks = sendmessages;
		CXMLDocument::buildtree = buildtree;
		if (newdoc->Read(args[0],strlen(args[0]),wellformed)){
			if (CXMLDocument::buildtree){
				doclist.add(newdoc);
				unsigned int docid = newdoc->GetID();
				result = (char *)malloc(INTSTRSIZE);
				sprintf(result,"%d",docid);
			}
			else {
				delete newdoc;
				result = (char *)istrdup("0");
			}
		}
		else {
			result = (char *)malloc(1024);
			sprintf(result,"%s\n%s",xmlerrors[XMLERR_BADXML],newdoc->GetError());
			delete newdoc;
		}
	}


	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

//HS-2010-10-11: [[ Bug 7586 ]] Reinstate libxml2 to create name spaces. Implement new liveCode commands to suppress name space creation.
// See the comments of Function XML_NewDocument for detailed information of the operation
void XML_NewDocumentNNS(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
    XML_ProcessNameSpaces = False;
    XML_NewDocument(args, nargs, retstring, pass, error);
}

//HS-2010-10-11: [[ Bug 7586 ]] Reinstate libxml2 to create name spaces. Implement new liveCode commands to suppress name space creation.
// See the comments of Function XML_NewDocument for detailed information of the operation
void XML_NewDocumentNS(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
    XML_ProcessNameSpaces = True;
    XML_NewDocument(args, nargs, retstring, pass, error);
}

/*Command: XML_AddDTD - Add DTD to xml document
Input: [0]=document id
[1] = dtd data
Output: On error, DTD parser or validation error.
Example: xml_AddDTD docid,dtddata
*/
void XML_AddDTD(char *args[], int nargs, char **retstring,
				Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	static int dtdcounter = 0;
	char *result = NULL;
	if (dtdcounter)
    {
        if (nargs != 2)
        {
            *error = True;
            result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
        }
        else
        {
            int docid = atoi(args[0]);
            CXMLDocument *tdoc = doclist.find(docid);
            if (!tdoc)
                result = istrdup(xmlerrors[XMLERR_BADDOCID]);
            else  if (!tdoc->AddDTD(args[1], strlen(args[1]))) {
                result = (char *)malloc(1024);
                sprintf(result,"%s\n%s",xmlerrors[XMLERR_BADDTD],tdoc->GetError());
            }
        }
    }
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*Command: XML_ValidateDTD - validate DTD against xml document
Input: [0]=document id
[1] = dtd data
Output: empty if validated, or validation error.
Example: if xml_ValidateDTD(docid,dtddata) is empty then put "validated"
*/
void XML_ValidateDTD(char *args[], int nargs, char **retstring,
				Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 2){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
			int docid = atoi(args[0]);
			CXMLDocument *tdoc = doclist.find(docid);
			if (!tdoc)
					result = istrdup(xmlerrors[XMLERR_BADDOCID]);
			else  if (!tdoc->ValidateDTD(args[1], strlen(args[1]))) {
					result = (char *)malloc(1024);
					sprintf(result,"%s\n%s",xmlerrors[XMLERR_BADDTD],tdoc->GetError());
			}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*Function: XML_NewDocumentFromFile - Parse XML file
Input: [0]=xml data
[1] = flag to determine whether to try parse xml data that is not well formed 
(ie. be forgiving)
Output: XML document ID. On error, 'can't parse xml' and error message.
Example: if xml_newdocument(data) is a number then beep
*/

void XML_NewDocumentFromFile(char *args[], int nargs, char **retstring,
					 Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs < 2)
	{
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	if (!*error)
	{
		if (!SecurityCanAccessFile(args[0]))
		{
			*error = True;
			result = istrdup(xmlerrors[XMLERR_NOFILEPERMS]);
		}
	}
	if (!*error)
	{
		Bool wellformed = util_strnicmp(args[1],"TRUE",4) == 0;
		CXMLDocument *newdoc = new (nothrow) CXMLDocument;
		Bool buildtree = True;
		Bool sendmessages = False;
		if (nargs >= 3)
			buildtree = util_strnicmp(args[2],"TRUE",4) == 0;
		if (nargs >= 4)
			sendmessages = util_strnicmp(args[3],"TRUE",4) == 0;
		CXMLDocument::allowcallbacks = sendmessages;
		CXMLDocument::buildtree = buildtree;
		char *tfile = istrdup(args[0]);
		
		// OK-2008-01-08 : Bug 5702. Resolve ~ characters in the path
		char *t_resolved_path;
		t_resolved_path = os_path_resolve(tfile);

		// OK-2007-12-18 : Bug 4905. New path_to_native function declared which allocates a new path buffer.
		char *t_native_path;
		t_native_path = revxml_path_for_libxml(t_resolved_path);

		if (newdoc->ReadFile(t_native_path, wellformed))
		{
			if (CXMLDocument::buildtree)
			{
				doclist.add(newdoc);
				unsigned int docid = newdoc->GetID();
				result = (char *)malloc(INTSTRSIZE);
				sprintf(result,"%d",docid);
			}
			else
			{
				delete newdoc;
				result = (char *)istrdup("0");
			}
		}
		else
		{
			result = (char *)malloc(1024);
			sprintf(result,"%s\n%s",xmlerrors[XMLERR_BADXML],newdoc->GetError());
			delete newdoc;
		}
		free(tfile);
		free(t_native_path);
		delete[] t_resolved_path; /* Allocated with new[] */
		
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

//HS-2010-10-11: [[ Bug 7586 ]] Reinstate libxml2 to create name spaces. Implement new liveCode commands to suppress name space creation.
// See the comments of Function XML_NewDocumentFromFile for detailed information of the operation
void XML_NewDocumentFromFileNNS(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
    XML_ProcessNameSpaces = False;
    XML_NewDocumentFromFile(args, nargs, retstring, pass, error);
}

//HS-2010-10-11: [[ Bug 7586 ]] Reinstate libxml2 to create name spaces. Implement new liveCode commands to suppress name space creation.
// See the comments of Function XML_NewDocumentFromFile for detailed information of the operation
void XML_NewDocumentFromFileNS(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
    XML_ProcessNameSpaces = True;
    XML_NewDocumentFromFile(args, nargs, retstring, pass, error);
}

/*
Function: XML_GetDocText - Dump contents of XML document or XML element
Input: [0]=xml document id
[1]=element path (if empty dumps contents of entire document)
Output: XML formatted data
Example: put XML_GetDocText(docid,"") into field "xmlcontents"
*/
void XML_GetDocText(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs < 1){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		Bool isformatted = False;
		if (nargs ==3 && util_strnicmp(args[2],"TRUE",4) == 0)
			isformatted = True;
		CXMLDocument *tdoc = doclist.find(docid);
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			int doclength;
			CXMLElement telement;
			if (nargs > 1 && *args[1]){
				if (!tdoc->GetElementByPath(&telement,args[1]))
					result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
				else 
					telement.Write(&result,&doclength,isformatted);	
			}
			else 
				tdoc->Write(&result,&doclength,isformatted);
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Command: XML_FreeDocument - Delete/Release XML Document
Input: [0]=xml document id
Output: empty or bad doc id error
Example: XML_FreeDocument docid
*/
void XML_FreeDocument(char *args[], int nargs, char **retstring,
					  Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 1){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
			int docid = atoi(*args);
			if (doclist.find(docid)) doclist.erase(docid);
			else result = istrdup(xmlerrors[XMLERR_BADDOCID]);
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}


/*
Command: XML_BuildTree - set true to build xml tree
Input: [0]=TRUE or FALSE
Output: empty or bad doc id error
Example: XML_BuildTree true
*/
/*void XML_BuildTree(char *args[], int nargs, char **retstring,
					  Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 1){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
		CXMLDocument::buildtree = util_strnicmp(*args,"TRUE",4) == 0;
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}*/


/*
Command: XML_AllowCallbacks - set true to recieve messages while parsing
Input: [0]=TRUE or FALSE
Output: empty or bad doc id error
Example: XML_AllowCallbacks true
*/
/*void XML_AllowCallbacks(char *args[], int nargs, char **retstring,
					  Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 1){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
		CXMLDocument::allowcallbacks = util_strnicmp(*args,"TRUE",4) == 0;
	*retstring = (result != NULL ? result : (char *)calloc(1,1));;
}*/

/*
Function: XML_Documents - Returns list of loaded xml documents
Input: none
Output: return delimited list of xml document id
Example: put XML_Documents() into doclist
*/
void XML_Documents(char *args[], int nargs, char **retstring,
					   Bool *pass, Bool *error)
{
	char *result = NULL;
	*error = False;
	*pass = False;
	VXMLDocList *vdoclist = doclist.getList();
	VXMLDocList::iterator theIterator;
	if (!vdoclist->empty()){
		result = (char *)malloc(vdoclist->size() * INTSTRSIZE);
		result[0] = '\0';
		int numdocs = 0;
		for (theIterator = vdoclist->begin(); theIterator != vdoclist->end(); theIterator++){
			CXMLDocument *tdoc = (CXMLDocument *)(*theIterator);
			char idbuffer[INTSTRSIZE];
			sprintf(idbuffer,"%d",tdoc->GetID());
			strcat(result,idbuffer);
			if (++numdocs != vdoclist->size())
				strcat(result,"\n");
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}


/*
Command: XML_FreeAll - unload/release all xml documents
Input: none
Output: none
Example:  XML_FreeAll
*/
void XML_FreeAll(char *args[], int nargs, char **retstring,
					   Bool *pass, Bool *error)
{
	char *result = NULL;
	*error = False;
	*pass = False;
	doclist.clear();
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}



//-----------------------ELEMENT CALLBACKS-----------------------------------------

/*
Command: XML_AddElement - Add a child element and sets its value
Input: [0]=xml document id
[1]=parent element path
[2]=new child element name
[3]=new child element value
[4]=[ 'before' or 'after' ]

Output: full path of new child element or bad doc id error
Example: XML_AddElement docid,elementpath,"newelement",newvalue
*/
void XML_AddElement(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	
	bool before;
	if (nargs == 5)
	{
		nargs = 4;
		if (strcasecmp(args[4], "before") == 0)
			before = true;
		else if (strcasecmp(args[4], "after") == 0)
			before = false;
		else
			nargs = 5;
	}
	else
		before = false;
	
	if (nargs != 4){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else {
				CXMLElement newelement;
				if (!telement.AddChild(args[2],args[3],&newelement, before))
					result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
				else 
					result = newelement.GetPath();
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Command: XML_InsertElement - Insert an element before the specified
  element as a sibling
Input: [0]=xml document id
[1]=next sibling element
[2]=new element name
[3]=new element value

Output: full path of new sibling element or bad doc id error
Example: XML_InsertElement docid,elementpath,"newelement",newvalue
*/
void XML_InsertElement(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	
	bool before;
	if (nargs == 5)
	{
		nargs = 4;
		if (strcasecmp(args[4], "before") == 0)
			before = true;
		else if (strcasecmp(args[4], "after") == 0)
			before = false;
		else
			nargs = 5;
	}
	else
		before = false;
	
	if (nargs != 4){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else {
				CXMLElement newelement;
				if (!telement.AddSibling(args[2],args[3],&newelement, before))
					result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
				else 
					result = newelement.GetPath();
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

char *XML_ManipulateElement(int p_source_tree, char *p_source_node, int p_destination_tree, char *p_destination_node, bool p_copy, bool p_before, bool p_sibling)
{
	// Locate the source and destination documents in the list of open xml docs.
	CXMLDocument *t_source_doc;
	t_source_doc = doclist . find(p_source_tree);
	if (t_source_doc == NULL)
		return istrdup(xmlerrors[XMLERR_BADDOCID]);

	CXMLDocument *t_destination_doc;
	t_destination_doc = doclist . find(p_destination_tree);
	if (t_destination_doc == NULL)
		return istrdup(xmlerrors[XMLERR_BADDOCID]);

	// Locate the source and destination elements in their respective documents
	CXMLElement t_source_element;
	if (!t_source_doc -> GetElementByPath(&t_source_element, p_source_node))
		return istrdup(xmlerrors[XMLERR_BADELEMENT]);

	CXMLElement t_destination_element;
	if (!t_destination_doc -> GetElementByPath(&t_destination_element, p_destination_node))
		return istrdup(xmlerrors[XMLERR_BADELEMENT]);
    
    // If we are copying, then we first duplicate the node before moving it
    if (p_copy)
        t_source_element . CopyElement(&t_source_element, true);
    
    if (p_source_tree == p_destination_tree)
    {
        // Now move the source element to the new location, returning an error if fails
        if (!t_destination_element . MoveElement(&t_source_element, p_sibling, p_before))
            return istrdup(xmlerrors[XMLERR_BADCOPY]);
    }
    else
    {
        if (!t_destination_element . MoveRemoteElement(&t_source_element, p_sibling, p_before))
            return istrdup(xmlerrors[XMLERR_BADCOPY]);
    }

    // If succeeded, we return the new path of the moved element.
    return t_source_element . GetPath();
}


// [0] Doc ID
// [1] Source Element
// [2] Target Element
// [3] before/after  [after]
// [4] sibling/child [child]
//
void XML_MoveElement(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;

	bool before;
	if (nargs >= 4)
	{
		nargs -= 1;
		if (strcasecmp(args[3], "before") == 0)
			before = true;
		else if (strcasecmp(args[3], "after") == 0)
			before = false;
		else
			// Refused below. It was 6, which went on to read args[4], past
			//   the end when there were only 4 arguments.
			nargs = 0;
	}
	else
		before = false;

	bool sibling;
	if (nargs >= 4)
	{
		nargs -= 1;
		if (strcasecmp(args[4], "sibling") == 0)
			sibling = true;
		else if (strcasecmp(args[4], "child") == 0)
			sibling = false;
		else
			nargs = 6;
	}
	else
		sibling = false;
	
	if (nargs != 3)
	{
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
	{
		int t_doc_id;
		t_doc_id = atoi(args[0]);
		result = XML_ManipulateElement(t_doc_id, args[1], t_doc_id, args[2], false, before, sibling);
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

// [0] Doc ID
// [1] Source Element
// [2] Target Element
// [3] before/after  [after]
// [4] sibling/child [child]
//
void XML_CopyElement(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;

	bool before;
	if (nargs >= 4)
	{
		nargs -= 1;
		if (strcasecmp(args[3], "before") == 0)
			before = true;
		else if (strcasecmp(args[3], "after") == 0)
			before = false;
		else
			// Refused below. It was 6, which went on to read args[4], past
			//   the end when there were only 4 arguments.
			nargs = 0;
	}
	else
		before = false;

	bool sibling;
	if (nargs >= 4)
	{
		nargs -= 1;
		if (strcasecmp(args[4], "sibling") == 0)
			sibling = true;
		else if (strcasecmp(args[4], "child") == 0)
			sibling = false;
		else
			nargs = 6;
	}
	else
		sibling = false;
	
	if (nargs != 3)
	{
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
	{
		int t_doc_id;
		t_doc_id = atoi(args[0]);
		result = XML_ManipulateElement(t_doc_id, args[1], t_doc_id, args[2], true, before, sibling);
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

void XML_CopyRemoteElement(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;

	bool before;
	if (nargs >= 5)
	{
		nargs -= 1;
		if (strcasecmp(args[4], "before") == 0)
			before = true;
		else if (strcasecmp(args[4], "after") == 0)
			before = false;
		else
			// Refused below. It was 7, which went on to read args[5], past
			//   the end when there were only 5 arguments.
			nargs = 0;
	}
	else
		before = false;

	bool sibling;
	if (nargs >= 5)
	{
		nargs -= 1;
		if (strcasecmp(args[5], "sibling") == 0)
			sibling = true;
		else if (strcasecmp(args[5], "child") == 0)
			sibling = false;
		else
			nargs = 7;
	}
	else
		sibling = false;
	
	if (nargs != 4)
	{
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
	{
		int t_source_doc_id;
		t_source_doc_id = atoi(args[0]);

		int t_destination_doc_id;
		t_destination_doc_id = atoi(args[2]);

		result = XML_ManipulateElement(t_source_doc_id, args[1], t_destination_doc_id, args[3], true, before, sibling);
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

void XML_MoveRemoteElement(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;

	bool before;
	if (nargs >= 5)
	{
		nargs -= 1;
		if (strcasecmp(args[4], "before") == 0)
			before = true;
		else if (strcasecmp(args[4], "after") == 0)
			before = false;
		else
			// Refused below. It was 7, which went on to read args[5], past
			//   the end when there were only 5 arguments.
			nargs = 0;
	}
	else
		before = false;

	bool sibling;
	if (nargs >= 5)
	{
		nargs -= 1;
		if (strcasecmp(args[5], "sibling") == 0)
			sibling = true;
		else if (strcasecmp(args[5], "child") == 0)
			sibling = false;
		else
			nargs = 7;
	}
	else
		sibling = false;
	
	if (nargs != 4)
	{
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
	{
		int t_source_doc_id;
		t_source_doc_id = atoi(args[0]);

		int t_destination_doc_id;
		t_destination_doc_id = atoi(args[2]);

		result = XML_ManipulateElement(t_source_doc_id, args[1], t_destination_doc_id, args[3], false, before, sibling);
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}



/*
Command: XML_AddXML
Purpose: 
nput: [0]=xml document id
[1]=parent element path
[2]=new xml
appends new XML to the document. The
parent element, if included, would append the xml 
as children of the parent.
*/
void XML_AddXML(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 3)
    {
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
    {
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else
        {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else
            {
				CXMLDocument tnewdoc;
				// The new XML is parsed into a tree whatever the last
				//   revXMLCreateTree asked for: after one that built no tree
				//   (only SAX messages), the parse made no root element to copy.
				Bool t_buildtree = CXMLDocument::buildtree;
				CXMLDocument::buildtree = True;
				Bool t_parsed = tnewdoc.Read(args[2],strlen(args[2]),False);
				CXMLDocument::buildtree = t_buildtree;
				if (!t_parsed)
                {
					result = (char *)malloc(1024);
					sprintf(result,"%s\n%s",xmlerrors[XMLERR_BADXML],tnewdoc.GetError());
				}
				else
                {
                    // MW-2014-06-12: [[ Bug 12628 ]] Use Remote operation to copy the root out of the new document.
                    CXMLElement newelement;
					// A parse of bad data (recover mode) returns a document
					//   even when it found no element, for text that is not
					//   XML or that a wrong encoding label made unreadable;
					//   copying its missing root crashed, with 2.9 as well.
					if (!tnewdoc.GetRootElement(&newelement))
					{
						result = (char *)malloc(1024);
						sprintf(result,"%s\n%s",xmlerrors[XMLERR_BADXML],tnewdoc.GetError());
					}
                    else if (!telement.MoveRemoteElement(&newelement, false, false))
                        result = istrdup(xmlerrors[XMLERR_BADCOPY]);
                    else
                        result = newelement.GetPath();
				}
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Command: XML_RemoveElement - Removes an element from XML tree
Input: [0]=xml document id
[1]=element path
Output: empty or bad doc id error
Example: XML_RemoveElement docid,elementpath
*/
void XML_RemoveElement(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 2){
		*error = True;

		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else telement.Remove();
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}


/*
Function: XML_GetElementContents - Returns value of an element
Input: [0]=xml document id
[1]=element path
Output: value of element or bad element error
Example: put XML_GetElementContents(docid,elementpath) into edata
*/
void XML_GetElementContents(char *args[], int nargs, char **retstring,
						   Bool *pass, Bool *error)
{
	*pass = False;
	
	*error = False;
	char *result = NULL;
	if (nargs != 2){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else {
				char *elementvalue = telement.GetContent(True);
				if (elementvalue == NULL)
					result = istrdup(XMLNULLSTRING);
				else
					result = istrdup(elementvalue);
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}


// The text p_text escaped for xmlStringGetNodeList and xmlNodeSetContent,
//   as libxml2 2.9's xmlEncodeSpecialChars escaped it: '&', '<', '>' and
//   '"' as entities, a carriage return as "&#13;", every other byte as it
//   is. 2.15's xmlEncodeSpecialChars writes the control characters XML 1.0
//   does not allow (U+0001 to U+001F but tab, newline and return) as
//   "&#xFFFD;", so revXMLPutIntoNode stored U+FFFD for them, where 2.9
//   stored them and revXMLNodeContents returned them. The result is the
//   caller's to free with xmlFree.
static xmlChar *revxml_escape_content(const xmlChar *p_text)
{
	size_t t_length = 0;
	for (const xmlChar *t_in = p_text; *t_in != '\0'; t_in++)
	{
		size_t t_size;
		switch (*t_in)
		{
			case '&': t_size = 5; break;
			case '<': case '>': t_size = 4; break;
			case '"': t_size = 6; break;
			case '\r': t_size = 5; break;
			default: t_size = 1; break;
		}
		if (t_length > (size_t)-1 - 1 - t_size)
			return NULL;
		t_length += t_size;
	}

	xmlChar *t_escaped = (xmlChar *)xmlMalloc(t_length + 1);
	if (t_escaped == NULL)
		return NULL;

	xmlChar *t_out = t_escaped;
	for (const xmlChar *t_in = p_text; *t_in != '\0'; t_in++)
	{
		const char *t_entity;
		switch (*t_in)
		{
			case '&': t_entity = "&amp;"; break;
			case '<': t_entity = "&lt;"; break;
			case '>': t_entity = "&gt;"; break;
			case '"': t_entity = "&quot;"; break;
			case '\r': t_entity = "&#13;"; break;
			default: t_entity = NULL; break;
		}
		if (t_entity != NULL)
		{
			size_t t_size = strlen(t_entity);
			memcpy(t_out, t_entity, t_size);
			t_out += t_size;
		}
		else
			*t_out++ = *t_in;
	}
	*t_out = '\0';
	return t_escaped;
}

/*
Command: XML_SetElementContents - Sets value of an existing element
Input: [0]=xml document id
[1]=element path
[2]=element's new value
[3]=keep children or not
Output: empty or bad element error
Example: XML_SetElementContents docid,elementpath,newvalue
*/
void XML_SetElementContents(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 3 && nargs != 4)
	{
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
	{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else
		{
			// OK-2007-12-18 : Added ability to preserve child nodes via the optional pReplaceTextOnly parameter.
			bool t_replace_text_only;
			if (nargs == 4)
				t_replace_text_only = stringToBool(args[3]);
			else
				t_replace_text_only = false;

			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else
			{

				// OK-2008-01-30 : Bug 5283. The string passed to xmlStringGetNodeList is interpreted by libXML as
				// XML rather than as a raw string. Because of this we need to escape any special characters in the string.
				xmlChar *t_encoded_string;
				t_encoded_string = revxml_escape_content((const xmlChar *)args[2]);

				if (t_replace_text_only)
				{
					// OK-2007-01-08 : Bug 5415. Ability to preserve child nodes.

					// Remove all text nodes
				    xmlNodePtr t_current_node;
					t_current_node = telement . GetNodePtr() -> children;

					xmlNodePtr t_new_first_node;
					t_new_first_node = NULL;

					while (t_current_node != NULL)
					{
						if (t_current_node -> type == XML_TEXT_NODE)
						{
							if (t_current_node -> prev != NULL)
								t_current_node -> prev -> next = t_current_node -> next;

							if (t_current_node -> next != NULL)
								t_current_node -> next -> prev = t_current_node -> prev;
						}
						else if (t_new_first_node == NULL)
							t_new_first_node = t_current_node;
						
						t_current_node = t_current_node -> next;
					}

					telement . GetNodePtr() -> children = t_new_first_node;
                    
                    // MW-2014-04-30: [[ Bug 11748 ]] If the encoded string is empty, then GetNodeList doesn't
                    //   return anything anymore.
                    
                    if (*t_encoded_string != '\0')
                    {
                        // Insert a new text node before all the children
                        xmlNodePtr t_new_node_list;
                        t_new_node_list = xmlStringGetNodeList(tdoc -> GetDocPtr(), t_encoded_string);

                        // Create a new text element to hold the content
                        CXMLElement t_new_element;
                        t_new_element.SetNodePtr(t_new_node_list);

                        // Save the previous first child element
                        xmlNodePtr t_old_first_element;
                        t_old_first_element = telement . GetNodePtr() -> children;

                        // Set the new text element to be the first child
                        telement . GetNodePtr() -> children = t_new_element.GetNodePtr();
                        telement . GetNodePtr() -> children -> next = t_old_first_element;

                        if (t_old_first_element != NULL)
                            t_old_first_element -> prev = t_new_element.GetNodePtr();
                    }
				}
				else
					telement . SetContent((char *)t_encoded_string);
				
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Function: XML_RootName - Returns name of root element in XML document
Input: [0]=xml document id
Output: name of root element
Example: put XML_RootName(docid) into rootname
*/
void XML_RootName(char *args[], int nargs, char **retstring,
					  Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 1){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
			int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {

			if (tdoc->GetRootElement(&telement))
				result = istrdup(telement.GetName());
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Function: XML_GetChildPath
Input:
[0]=xml document id
[1]=path of parent element
[2]=inc text nodes (default false)
Output: path of child element
Example: put XML_GetChildPath(docid,elempath) into childpath
*/
void XML_GetChildPath(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 2 && nargs != 3){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		bool t_include_text = nargs == 3 && util_strnicmp(args[2],"TRUE",4) == 0;

		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
        if (!tdoc) 
		{
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		}
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else if (telement.GoChild(NULL, t_include_text))
				result = telement.GetPath();
		}		
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Function: XML_GetNextSiblingPath
Input:
[0]=xml document id
[1] = element path
[2]=inc text nodes (default false)
Output: path of next sibling element
Example: put XML_GetNextSiblingPath(docid,elempath) into siblingpath
*/
void XML_GetNextSiblingPath(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 2 && nargs != 3){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		bool t_include_text = nargs == 3 && util_strnicmp(args[2],"TRUE",4) == 0;
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else if (telement.GoNext(NULL, t_include_text))
				result = telement.GetPath();
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}


/*
Function: XML_GetPrevSiblingPath
Input:
[0]=xml document id
[1] = element path
[2]=inc text nodes (default false)
Output: path of previous sibling element
Example: put XML_GetPrevSiblingPath(docid,elempath) into siblingpath
*/
void XML_GetPrevSiblingPath(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 2 && nargs != 3){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		bool t_include_text = nargs == 3 && util_strnicmp(args[2],"TRUE",4) == 0;
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else if (telement.GoPrev(NULL, t_include_text))
					result = telement.GetPath();
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Function: XML_GetParentPath
Input: [0]=xml document id
[1] = element path
Output: path of parent element
Example: put XML_GetParentPath(docid,elempath) into parentpath
*/
void XML_GetParentPath(char *args[], int nargs, char **retstring,
							Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 2){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else if (telement.GoParent())
					result = telement.GetPath();
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}




/*
Function: XML_ChildCount - Returns number of child elements for element
Input: [0]=xml document id
[1]=path to element
[2]=optional. child name filter(empty for all)
[3]=optional. depth (0,1 for child, 2 for childs children, ect -1 to expand all of tree)
Output: number of children (with name [2])
Example: 
put XML_ChildCount(docid,elementpath,"task",-1) into childcount
put XML_ChildCount(docid,elementpath,"",0) into childcount


*/
void XML_ChildCount(char *args[], int nargs, char **retstring,
						   Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 4){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else {
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else {
				int maxdepth;
				char *childname = NULL;
				if (*args[2])
					childname = args[2];
				maxdepth = atoi(args[3]);
				int childcount = telement.ChildCount(childname,maxdepth);
				result = (char *)malloc(INTSTRSIZE);
				sprintf(result,"%d",childcount);
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Function: XML_Children - Returns names of child elements
Input: [0]=xml document id
[1]=path to element
[2]=delimiter text
[3]=child name filter(empty for all)
[4]=flag for including child counts (true or false)
[5]=include text nodes (optional)
Output: delimited list of names next generation elements
Example: 
put XML_Children(docid,elementpath,",","task","true") into childnames
*/
void XML_Children(char *args[], int nargs, char **retstring,
				  Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 5 && nargs != 6){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else {
				char *itemsep,*childfilter = NULL;
				int itemseplen,bufsize = 0,buflen = 0;
				Bool bracketflag = False;
				itemsep = args[2];
				itemseplen = strlen(itemsep);
				if (*args[3])
					childfilter = args[3];
				bracketflag = util_strnicmp(args[4],"TRUE",4) == 0;

				bool t_inc_text;
				t_inc_text = nargs == 6 && util_strnicmp(args[5],"TRUE",4) == 0;

				char subscriptbuf[INTSTRSIZE + 2];
				CXMLElementEnumerator tenum(&telement,0);
				while (tenum.Next(childfilter, t_inc_text))
				{
						CXMLElement *curelement = tenum.GetElement();
						if (!curelement->IsTextNode())
							util_concatstring(curelement->GetName(), strlen(curelement->GetName()), result, buflen , bufsize);
						if (bracketflag) {
							sprintf(subscriptbuf,"[%d]",curelement->GetIndex());
							util_concatstring(subscriptbuf, strlen(subscriptbuf),
								result, buflen , bufsize);
						}
						util_concatstring(itemsep, itemseplen,result, buflen , bufsize);
				}
				if (buflen)
					result[buflen-itemseplen] = '\0'; //strip trailing item seperator
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}




/*
Function: XML_Tree
Input: [0]=xml document id
[1]=path to element
[2]=delimiter text
[3]=pad text
[4]=flag for including child counts  in brackets after names (boolean)
[5]=depth limit (how far to expand the tree, -1 for all)
Output:
a tree structure with [1] as its root with elements seperated by [2] 
and padded with [4], according to the depth in the tree
Example: 
put XML_Tree(docid,elementpath,return,tab,true,-1) into field 1
*/
void XML_Tree(char *args[], int nargs, char **retstring,
				  Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 6){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else {
				int itemseplen, padseplen, maxdepth, bufsize = 0,buflen = 0;
				char *itemsep,*padsep;
				Bool bracketflag = False;
				itemsep = args[2];
				itemseplen = strlen(itemsep);
				padsep = args[3];
				padseplen = strlen(padsep);
				bracketflag = util_strnicmp(args[4],"TRUE",4) == 0;
				maxdepth = atoi(args[5]);
				char subscriptbuf[INTSTRSIZE + 2];
				CXMLElementEnumerator tenum(&telement,maxdepth);
				do 
				{
						CXMLElement *curelement = tenum.GetElement();

						// OK-2006-09-15-15-13: Fix for bug 2843
						if (!curelement->isinited())
						{
							result = istrdup(xmlerrors[XMLERR_BADXML]);
							break;
						}

						int i;
						int npad = tenum.GetDepth();
						for (i = 0; i < npad; i++)
							util_concatstring(padsep, padseplen, result, buflen, bufsize);
						util_concatstring(curelement->GetName(), strlen(curelement->GetName()), 
							result, buflen , bufsize);

						

						if (bracketflag) {
							sprintf(subscriptbuf,"[%d]", curelement->GetIndex());
							util_concatstring(subscriptbuf, strlen(subscriptbuf),
								result, buflen , bufsize);
						}
						util_concatstring(itemsep, itemseplen, result, buflen, bufsize);
						
				} while (tenum.Next(NULL));
				if (buflen)
					result[buflen-itemseplen] = '\0';
			}
		}
	}
		*retstring = (result != NULL ? result : (char *)calloc(1,1));
}



enum pathType
{
	pathTypeNameOnly,
	pathTypeNameWithCount,
	pathTypeRelative,
	pathTypeFull
};

/*
Function: XML_ListOfChildText
Input: [0]=xml document id
[1]=path to element
[2]=item delimiter
[3]=line delimiter
[4]=flag for including child counts  in brackets after names, or returning full paths of children
[5]=depth limit (how far to expand the tree, -1 for all)
Output: return list all children with their tags, in "lines" divided into "items" 
Example: 
put XML_ListOfChildText(docid,elementpath,",",return,2) into childnames
*/
void XML_ListOfChildText(char *args[], int nargs, char **retstring,
				  Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 6)
	{
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
	{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else 
		{
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else 
			{
				int itemseplen, maxdepth, lineseplen, bufsize = 0,buflen = 0;
				char *itemsep,*linesep;
				itemsep = args[2];
				itemseplen = strlen(itemsep);
				linesep = args[3];
				lineseplen = strlen(linesep);
				
				// OK-2007-01-10 : Added ability to return paths of children
				pathType t_path_type;
				if (util_strnicmp(args[4], "true", 4) == 0 || util_strnicmp(args[4], "leaf", 4) == 0)
					t_path_type = pathTypeNameWithCount;
				else if (util_strnicmp(args[4], "false", 5) == 0)
					t_path_type = pathTypeNameOnly;
				else if (util_strnicmp(args[4], "relative", 8) == 0)
					t_path_type = pathTypeRelative;
				else if (util_strnicmp(args[4], "full", 4) == 0)
					t_path_type = pathTypeFull;
				else
					t_path_type = pathTypeNameOnly;

				maxdepth = atoi(args[5]);
				char subscriptbuf[INTSTRSIZE + 2];
				CXMLElementEnumerator tenum(&telement,maxdepth);
				while (tenum.Next(NULL))
				{
						CXMLElement *curelement = tenum.GetElement();

						// OK-2007-01-10 : Added ability to return full paths of children
						if (t_path_type == pathTypeNameOnly)
							util_concatstring(curelement -> GetName(), strlen(curelement -> GetName()), result, buflen, bufsize);
						else if (t_path_type == pathTypeNameWithCount)
						{
							util_concatstring(curelement -> GetName(), strlen(curelement -> GetName()), result, buflen, bufsize);
							sprintf(subscriptbuf,"[%d]",curelement -> GetIndex());
							util_concatstring(subscriptbuf, strlen(subscriptbuf), result, buflen , bufsize);
						}
						else if (t_path_type == pathTypeFull)
							util_concatstring(curelement -> GetPath(), strlen(curelement -> GetPath()), result, buflen, bufsize);
						else if (t_path_type == pathTypeRelative)
						{
							char *t_full_path;
							t_full_path = curelement -> GetPath();

							char *t_relative_path;
							t_relative_path = t_full_path + strlen(telement . GetPath()) + 1;

							util_concatstring(t_relative_path, strlen(t_relative_path), result, buflen, bufsize);
						}

						util_concatstring(itemsep, itemseplen, result, buflen , bufsize);
						char *tcontent = curelement->GetContent(True);

						if (tcontent)
							util_concatstring(tcontent,  strlen(tcontent), result, buflen , bufsize);

						util_concatstring(linesep, lineseplen, result, buflen, bufsize);
						
				}
				if (buflen)
					result[buflen-lineseplen] = '\0'; //strip trailing item seperator
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

//--------------------------ELEMENT---------------------------------
/*
Command: XML_SetAttributeValue - Sets attribute value (creates attribute if doesn't exist)
Input: [0]=xml document id
[1]= path to element
[2]= attribute name
[3]= attribute value
Output: error message on bad attribute or bad element 
Example: XML_SetAttributeValue docid,elementpath,"product","livecode"
*/
void XML_SetAttributeValue(char *args[], int nargs, char **retstring,
						   Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 4){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else if (!telement.SetAttribute(args[2],args[3]))
				result = istrdup(xmlerrors[XMLERR_BADATTRIBUTE]);
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Function: XML_GetAttributeValue - Retrieves attribute value
Input: [0]=xml document id
[1]= path to element
[2]= attribute name
Output: attribute value or error message on bad attribute
Example: put XML_GetAttributeValue(docid,elementpath,"product")
*/
void XML_GetAttributeValue(char *args[], int nargs, char **retstring,
						   Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 3){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
	{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else 
		{
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else 
			{
				char *attributevalue;
				attributevalue = NULL;

				attributevalue = telement.GetAttributeValue(args[2], False);

				if (attributevalue == NULL)
					result = istrdup(xmlerrors[XMLERR_BADATTRIBUTE]);
				else
					result = attributevalue;
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}


/*
Commmad: XML_RemoveAttribute - Removes attribute
Input: [0]=xml document id
[1]= path to element
[2]= attribute name
Output: error message on bad attribute
Example: XML_RemoveAttribute docid,elementpath,"product"
*/
void XML_RemoveAttribute(char *args[], int nargs, char **retstring,
						   Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 3){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else if (!telement.RemoveAttribute(args[2]))
					result = istrdup(xmlerrors[XMLERR_BADATTRIBUTE]);
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}



/*
Function: XML_ListOfAttributes
Input: [0]=xml document id
[1]= path to element
[2]=item delimiter
[3]=line delimiter
Output: all attributes with their names and values in "lines" divided into "items" 
*/
void XML_ListOfAttributes(char *args[], int nargs, char **retstring,
						  Bool *pass, Bool *error)
{
	
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 4){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else {
				int itemseplen, lineseplen, bufsize = 0,buflen = 0;
				char *itemsep,*linesep;
				itemsep = args[2];
				itemseplen = strlen(itemsep);
				linesep = args[3];
				lineseplen = strlen(linesep);
				CXMLAttribute tattribute;
				if (telement.GetFirstAttribute(&tattribute))
					do {
						util_concatstring(tattribute.GetName(), strlen(tattribute.GetName()), 
							result, buflen , bufsize);
						util_concatstring(itemsep, itemseplen,result, buflen , bufsize);
						util_concatstring(tattribute.GetContent(),  strlen(tattribute.GetContent()),
							result, buflen , bufsize);
						util_concatstring(linesep, lineseplen, result, buflen, bufsize);
					} while (tattribute.GoNext());

				// OK-2009-01-05: [[Bug 7586]] - Some elements may have a "namespace". This is not regarded by libXML
				// as one of the elements' attributes, but is stored separately. Here we retrieve this and append it
				// to the list of attributes.
				xmlNs *t_namespace;
				t_namespace = NULL;
				telement . GetNamespace(t_namespace);

				if (t_namespace != NULL && t_namespace -> href != NULL)
				{
					util_concatstring("xmlns", strlen("xmlns"), result, buflen, bufsize);
					util_concatstring(itemsep, itemseplen,result, buflen , bufsize);
					util_concatstring((char *)t_namespace -> href, strlen((char *)t_namespace -> href) + 1, result, buflen, bufsize);
				}


				if (buflen)
					result[buflen-lineseplen] = '\0'; //strip trailing item seperator
			}
		}
	
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

/*
Function: XML_ListByAttributeValue 
Input: [0]=xml document id
[1]=path to element
[2]=child filter (empty for all)
[3]=attribute name
[4]=delimiter for output
[5]=maxdepth
Output: makes list of attribute values for specified children of parent
Example: 
put XML_ListByAttributeValue(docid,elementpath,"name","language",",",-1) into childnames
*/
void XML_ListByAttributeValue(char *args[], int nargs, char **retstring,
				  Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;
	if (nargs != 6){
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else {
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else {
				char *itemsep,*attname = NULL,*childfilter = NULL;
				int itemseplen,bufsize = 0, maxdepth,buflen = 0;
				if (*args[2])
					childfilter = args[2];
				if (*args[3])
					attname = args[3];
				itemsep = args[4];
				itemseplen = strlen(itemsep);
				maxdepth = atoi(args[5]);
				CXMLElementEnumerator tenum(&telement,maxdepth);
				while (tenum.Next(childfilter))
				{
                    if (attname != nullptr)
                    {
                        char *attributevalue =
                            tenum.GetElement()->GetAttributeValue(attname, True);

						if (attributevalue){
							util_concatstring(attributevalue, strlen(attributevalue), 
							result, buflen , bufsize);
                            free(attributevalue);
						}
                    }
                    util_concatstring(itemsep, itemseplen,result, buflen , bufsize);
				}
				if (buflen)
					result[buflen-itemseplen] = '\0'; //strip trailing item seperator
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}




/*
Function: XML_FindElementByAttributeValue
Input: [0]=xml document id
[1]=path to element
[2]=child filter (empty for all)
[3]=attribute name
[4]=attribute value
[5]=maxdepth
[6]=case sensitive
Output: full path of element that contains attribute which matches value
Example: 
put XML_FindElementByAttributeValue(docid,elementpath,"name","language","english",-1) into childnames
*/
void XML_FindElementByAttributeValue(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	char *result = NULL;

    // OK-2007-12-12 : Bug 5673 Added optional case-sensitive parameter
	if (nargs != 6 && nargs != 7)
	{
		*error = True;
		result = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
	}
	else
	{
		int docid = atoi(args[0]);
		CXMLDocument *tdoc = doclist.find(docid);
		CXMLElement telement;
		if (!tdoc)
			result = istrdup(xmlerrors[XMLERR_BADDOCID]);
		else 
		{
			if (!tdoc->GetElementByPath(&telement,args[1]))
				result = istrdup(xmlerrors[XMLERR_BADELEMENT]);
			else 
			{
				char *attname,*attvalue,*childfilter = NULL;
				int maxdepth;
				if (*args[2])
					childfilter = args[2];

				attname = args[3];
				attvalue = args[4];
				maxdepth = atoi(args[5]);
				CXMLElementEnumerator tenum(&telement,maxdepth);

				// OK-2007-12-12 : Bug 5673
				bool t_case_sensitive;
				if (nargs == 6)
					t_case_sensitive = false;
				else
					t_case_sensitive = stringToBool(args[6]);

				while (tenum.Next(childfilter))
				{
					CXMLElement *curelement = tenum.GetElement();
					char *tvalue = curelement->GetAttributeValue(attname, True);

					// OK-2007-12-12 : Bug 5673
						
					if (tvalue != NULL)
					{
						int t_comparison_result;

						if (t_case_sensitive)
							t_comparison_result = util_strncmp(attvalue, tvalue, strlen(tvalue));
						else
							t_comparison_result = util_strnicmp(attvalue, tvalue, strlen(tvalue));
                        
                        free(tvalue);
                        
                        if (t_comparison_result == 0)
                        {
                            result = curelement -> GetPath();
                            break;
                        }
					}

				}
			}
		}
	}
	*retstring = (result != NULL ? result : (char *)calloc(1,1));
}

// MDW-2013-06-22: [[ RevXmlXPath ]]

static int xpathNodeBufGetContent(xmlBufferPtr pBuffer, xmlNodePtr cur, char *pCharDelimiter);

static xmlNodeSetPtr XML_Object_to_NodeSet(xmlXPathObjectPtr pObject)
{
	return pObject->nodesetval;
}

/**
 * xpathBufferCat:
 * @buf:  the buffer to add to
 * @str:  the #xmlChar string
 *
 * Append a zero terminated string to an XML buffer.
 *
 * Returns 0 successful, a positive error code number otherwise
 *         and -1 in case of internal or API error.
 */
static int
xpathBufferCat(xmlBufferPtr pBuf, const xmlChar *pStr, char *pCharDelimiter) {
	if (pBuf == NULL)
		return(-1);
	if (pBuf->alloc == XML_BUFFER_ALLOC_IMMUTABLE)
		return -1;
	if (pStr == NULL)
		return -1;
	xmlBufferAdd(pBuf, pStr, -1);
	return xmlBufferAdd(pBuf, (xmlChar*)pCharDelimiter, -1);
}

/**
 * xmlNodeGetContent:
 * @cur:  the node being read
 *
 * Read the value of a node, this can be either the text carried
 * directly by this node if it's a TEXT node or the aggregate string
 * of the values carried by this node child's (TEXT and ENTITY_REF).
 * Entity references are substituted.
 * Returns a new #xmlChar * or NULL if no content is available.
 *     It's up to the caller to free the memory with xmlFree().
 */
static xmlChar *
xpathNodeGetContent(xmlNodePtr cur, char *pCharDelimiter)
{
    if (cur == NULL)
        return (NULL);
    switch (cur->type) {
        case XML_DOCUMENT_FRAG_NODE:
        case XML_ELEMENT_NODE:{
                xmlBufferPtr buffer;
                xmlChar *ret;

                buffer = xmlBufferCreateSize(64);
                if (buffer == NULL)
                    return (NULL);
		xpathNodeBufGetContent(buffer, cur, pCharDelimiter);
                // xmlBufferDetach, not taking buffer->content: in libxml2
                //   2.15 a buffer's memory starts at contentIO, which
                //   xmlBufferFree frees whatever content says.
                ret = xmlBufferDetach(buffer);
                xmlBufferFree(buffer);
                return (ret);
            }
        case XML_ATTRIBUTE_NODE:{
                xmlAttrPtr attr = (xmlAttrPtr) cur;

                if (attr->parent != NULL)
                    return (xmlNodeListGetString
                            (attr->parent->doc, attr->children, 1));
                else
                    return (xmlNodeListGetString(NULL, attr->children, 1));
                break;
            }
        case XML_COMMENT_NODE:
        case XML_PI_NODE:
            if (cur->content != NULL)
                return (xmlStrdup(cur->content));
            return (NULL);
        case XML_ENTITY_REF_NODE:{
                xmlEntityPtr ent;
                xmlBufferPtr buffer;
                xmlChar *ret;

                /* lookup entity declaration */
                ent = xmlGetDocEntity(cur->doc, cur->name);
                if (ent == NULL)
                    return (NULL);

                buffer = xmlBufferCreate();
                if (buffer == NULL)
                    return (NULL);

                xpathNodeBufGetContent(buffer, cur, pCharDelimiter);

                ret = xmlBufferDetach(buffer);
                xmlBufferFree(buffer);
                return (ret);
            }
        case XML_ENTITY_NODE:
        case XML_DOCUMENT_TYPE_NODE:
        case XML_NOTATION_NODE:
        case XML_DTD_NODE:
        case XML_XINCLUDE_START:
        case XML_XINCLUDE_END:
            return (NULL);
        case XML_DOCUMENT_NODE:
#ifdef LIBXML_DOCB_ENABLED
        case XML_DOCB_DOCUMENT_NODE:
#endif
        case XML_HTML_DOCUMENT_NODE: {
	    xmlBufferPtr buffer;
	    xmlChar *ret;

	    buffer = xmlBufferCreate();
	    if (buffer == NULL)
		return (NULL);

	    xpathNodeBufGetContent(buffer, (xmlNodePtr) cur, pCharDelimiter);

	    ret = xmlBufferDetach(buffer);
	    xmlBufferFree(buffer);
	    return (ret);
	}
        case XML_NAMESPACE_DECL: {
	    xmlChar *tmp;

	    tmp = xmlStrdup(((xmlNsPtr) cur)->href);
            return (tmp);
	}
        case XML_ELEMENT_DECL:
            /* TODO !!! */
            return (NULL);
        case XML_ATTRIBUTE_DECL:
            /* TODO !!! */
            return (NULL);
        case XML_ENTITY_DECL:
            /* TODO !!! */
            return (NULL);
        case XML_CDATA_SECTION_NODE:
        case XML_TEXT_NODE:
            if (cur->content != NULL)
                return (xmlStrdup(cur->content));
            return (NULL);
    }
    return (NULL);
}

/**
 * xmlNodeBufGetContent:
 * @buffer:  a buffer
 * @cur:  the node being read
 *
 * Read the value of a node @cur, this can be either the text carried
 * directly by this node if it's a TEXT node or the aggregate string
 * of the values carried by this node child's (TEXT and ENTITY_REF).
 * Entity references are substituted.
 * Fills up the buffer @buffer with this value
 * 
 * Returns 0 in case of success and -1 in case of error.
 */
static int
xpathNodeBufGetContent(xmlBufferPtr buffer, xmlNodePtr cur, char *cDelimiter)
{
    if ((cur == NULL) || (buffer == NULL)) return(-1);
    switch (cur->type) {
        case XML_CDATA_SECTION_NODE:
        case XML_TEXT_NODE:
	    xpathBufferCat(buffer, cur->content, cDelimiter);
            break;
        case XML_DOCUMENT_FRAG_NODE:
        case XML_ELEMENT_NODE:{
                xmlNodePtr tmp = cur;

                while (tmp != NULL) {
                    switch (tmp->type) {
                        case XML_CDATA_SECTION_NODE:
                        case XML_TEXT_NODE:
                            if (tmp->content != NULL)
                                xpathBufferCat(buffer, tmp->content, cDelimiter);
                            break;
                        case XML_ENTITY_REF_NODE:
                            xpathNodeBufGetContent(buffer, tmp, cDelimiter);
                            break;
                        default:
                            break;
                    }
                    /*
                     * Skip to next node
                     */
                    if (tmp->children != NULL) {
                        if (tmp->children->type != XML_ENTITY_DECL) {
                            tmp = tmp->children;
                            continue;
                        }
                    }
                    if (tmp == cur)
                        break;

                    if (tmp->next != NULL) {
                        tmp = tmp->next;
                        continue;
                    }

                    do {
                        tmp = tmp->parent;
                        if (tmp == NULL)
                            break;
                        if (tmp == cur) {
                            tmp = NULL;
                            break;
                        }
                        if (tmp->next != NULL) {
                            tmp = tmp->next;
                            break;
                        }
                    } while (tmp != NULL);
                }
		break;
            }
        case XML_ATTRIBUTE_NODE:{
                xmlAttrPtr attr = (xmlAttrPtr) cur;
		xmlNodePtr tmp = attr->children;

		while (tmp != NULL) {
		    if (tmp->type == XML_TEXT_NODE)
		        xpathBufferCat(buffer, tmp->content, cDelimiter);
		    else
		        xpathNodeBufGetContent(buffer, tmp, cDelimiter);
		    tmp = tmp->next;
		}
                break;
            }
        case XML_COMMENT_NODE:
        case XML_PI_NODE:
	    xpathBufferCat(buffer, cur->content, cDelimiter);
            break;
        case XML_ENTITY_REF_NODE:{
                xmlEntityPtr ent;
                xmlNodePtr tmp;

                /* lookup entity declaration */
                ent = xmlGetDocEntity(cur->doc, cur->name);
                if (ent == NULL)
                    return(-1);

                /* an entity content can be any "well balanced chunk",
                 * i.e. the result of the content [43] production:
                 * http://www.w3.org/TR/REC-xml#NT-content
                 * -> we iterate through child nodes and recursive call
                 * xmlNodeGetContent() which handles all possible node types */
                tmp = ent->children;
                while (tmp) {
		    xpathNodeBufGetContent(buffer, tmp, cDelimiter);
                    tmp = tmp->next;
                }
		break;
            }
        case XML_ENTITY_NODE:
        case XML_DOCUMENT_TYPE_NODE:
        case XML_NOTATION_NODE:
        case XML_DTD_NODE:
        case XML_XINCLUDE_START:
        case XML_XINCLUDE_END:
            break;
        case XML_DOCUMENT_NODE:
#ifdef LIBXML_DOCB_ENABLED
        case XML_DOCB_DOCUMENT_NODE:
#endif
        case XML_HTML_DOCUMENT_NODE:
	    cur = cur->children;
	    while (cur!= NULL) {
		if ((cur->type == XML_ELEMENT_NODE) ||
		    (cur->type == XML_TEXT_NODE) ||
		    (cur->type == XML_CDATA_SECTION_NODE)) {
		    xpathNodeBufGetContent(buffer, cur, cDelimiter);
		}
		cur = cur->next;
	    }
	    break;
        case XML_NAMESPACE_DECL:
	    xpathBufferCat(buffer, ((xmlNsPtr) cur)->href, cDelimiter);
	    break;
        case XML_ELEMENT_DECL:
        case XML_ATTRIBUTE_DECL:
        case XML_ENTITY_DECL:
            break;
    }
    return(0);
}

/**
 * xpathResultAppend
 *
 * Appends pText and then pDelimiter to xBuffer, which holds xLength bytes
 * and a terminating NUL in xSize bytes, making it bigger when it must be.
 * The two functions below used to make room for the text only, so the
 * delimiter and the NUL were written past the end of the buffer when the
 * text (nearly) filled it, and XML_ObjectPtr_to_Data grew it by doubling
 * once, which a text longer than the buffer overran by the difference.
 * Returns false, with the buffer as it was, when no memory could be had.
 */
static bool xpathResultAppend(char *&xBuffer, size_t &xLength, size_t &xSize, const char *pText, const char *pDelimiter)
{
	size_t tTextLength = strlen(pText);
	size_t tDelimiterLength = strlen(pDelimiter);
	size_t tMax = (size_t)-1;
	if (tTextLength > tMax - 1 - xLength || tDelimiterLength > tMax - 1 - xLength - tTextLength)
		return false;
	size_t tNeeded = xLength + tTextLength + tDelimiterLength + 1;
	if (tNeeded > xSize)
	{
		size_t tNewSize = xSize > 0 ? xSize : tNeeded;
		while (tNewSize < tNeeded)
			tNewSize = tNewSize <= tMax / 2 ? tNewSize * 2 : tNeeded;
		char *tNewBuffer = (char *)realloc(xBuffer, tNewSize);
		if (NULL == tNewBuffer)
			return false;
		xBuffer = tNewBuffer;
		xSize = tNewSize;
	}
	memcpy(xBuffer + xLength, pText, tTextLength);
	xLength += tTextLength;
	memcpy(xBuffer + xLength, pDelimiter, tDelimiterLength);
	xLength += tDelimiterLength;
	xBuffer[xLength] = '\0';
	return true;
}

/**
 * XML_ObjectPtr_to_Xpaths
 *
 * @pObject
 * @pLineDelimiter : delimiter between returned lines
 */
static char *XML_ObjectPtr_to_Xpaths(xmlXPathObjectPtr pObject, char *pLineDelimiter)
{
	size_t iBufferSize = 8192;
	if (NULL != pObject)
	{
		xmlNodeSetPtr nodes = XML_Object_to_NodeSet(pObject);
		if (NULL != nodes)
		{
    			int i;
			xmlNodePtr cur;
		    	int size = (nodes) ? nodes->nodeNr : 0;
			size_t iLength = 0;
			char *buffer = (char*)malloc(iBufferSize);
			if (NULL == buffer)
				return(NULL);
			*buffer = (char)0; // null-terminate to start things off

			for(i = 0; i < size; ++i)
			{
				cur = nodes->nodeTab[i];
				if (NULL != cur)
				{
					xmlChar *cPtr = xmlGetNodePath(cur);
					if (NULL != cPtr)
					{
						bool tAdded = xpathResultAppend(buffer, iLength, iBufferSize, (char*)cPtr, pLineDelimiter);
						xmlFree(cPtr);
						if (!tAdded)
						{
							free(buffer);
							return(NULL);
						}
					}
				}
			}
			return (buffer);
		}
		else
			return(NULL);
	}
	else
		return(NULL);
}

/**
 * XML_ObjectPtr_to_Xpaths
 *
 * @pObject
 * @pElementDelimiter : delimiter between returned elements
 * @pLineDelimiter : delimiter between returned lines
 */
static char *XML_ObjectPtr_to_Data(xmlXPathObjectPtr pObject, char *pElementDelimiter, char *pLineDelimiter)
{
	size_t iBufferSize = 8192;
	if (NULL != pObject)
	{
		xmlNodeSetPtr nodes = XML_Object_to_NodeSet(pObject);
		if (NULL != nodes)
		{
    			int i;
			xmlNodePtr cur;
		    	int size = (nodes) ? nodes->nodeNr : 0;
			size_t iLength = 0;
			char *buffer = (char*)malloc(iBufferSize);
			if (NULL == buffer)
				return(NULL);
			*buffer = (char)0; // null-terminate to start things off

			for(i = 0; i < size; ++i)
			{
				cur = nodes->nodeTab[i];
				if (NULL != cur)
				{
					xmlChar *cPtr = xpathNodeGetContent(cur, pElementDelimiter);
					if (NULL != cPtr)
					{
						bool tAdded = xpathResultAppend(buffer, iLength, iBufferSize, (char*)cPtr, pLineDelimiter);
						xmlFree(cPtr);
						if (!tAdded)
						{
							free(buffer);
							return(NULL);
						}
					}
				}
			}
			return (buffer);
		}
		else
			return(NULL);
	}
	else
		return(NULL);
}

/**
 * xpathContextAs29
 *
 * Makes ctx evaluate pExpression as libxml2 2.9 did where revXML's results
 * differ. 2.9 gave a location step from an empty node-set no node-set at
 * all, which revXML reports as "can't resolve xpath" (/r/nosuch/text(),
 * /r/a[@k='none']/b), unless it evaluated the expression as a stream
 * (xmlXPathTryStreamCompile): a path of names, '*', '.', '/' and '//' with
 * no predicate, function, attribute or prefix, which matched nothing as an
 * empty node-set (/r/nosuch/b). 2.15 always gives an empty node-set.
 */
static void xpathContextAs29(xmlXPathContextPtr ctx, const xmlChar *pExpression)
{
	bool tStreamed = false;
	if (xmlStrchr(pExpression, '[') == NULL && xmlStrchr(pExpression, '(') == NULL &&
		xmlStrchr(pExpression, '@') == NULL && xmlStrchr(pExpression, ':') == NULL)
	{
		xmlPatternPtr tPattern = xmlPatterncompile(pExpression, NULL, XML_PATTERN_XPATH, NULL);
		if (tPattern != NULL)
		{
			// The checks xmlXPathRunStreamEval made before it evaluated.
			tStreamed = xmlPatternStreamable(tPattern) == 1 && xmlPatternMaxDepth(tPattern) != -1 &&
				xmlPatternMinDepth(tPattern) != -1 && xmlPatternFromRoot(tPattern) >= 0;
			xmlFreePattern(tPattern);
		}
	}
	if (!tStreamed)
		ctx->flags |= XML_XPATH_EMPTY_STEP_NULL;
}

/**
 * XML_EvalXPath
 * @pDocID : xml tree id
 * @pExpression : xpath to evaluate
 * @pDelimiter : [optional] delimiter between paths (default="\n")
 *
 * Returns a cr-separated list of paths which is the result of
 * evaluating the expression against the xml tree
 *
 * Example:
 * put revXMLEvaluateXPath(tDocID, "/bookstore/books/[price<50]", tab)
 */
void XML_EvalXPath(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;

	// The tree and the expression are needed: without them args[1] was
	//   read past the end of args, and the engine crashed.
	if (nargs < 2)
	{
		*error = True;
		*retstring = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
		return;
	}

	int docID = atoi(args[0]);
	CXMLDocument *xmlDocument = doclist.find(docID);
	if (NULL != xmlDocument)
	{
		xmlDocPtr xmlDoc = xmlDocument->GetDocPtr();
		if (NULL != xmlDoc)
		{
			xmlXPathContextPtr ctx = xmlXPathNewContext(xmlDoc);
			if (NULL != ctx)
			{
				xmlChar *str = (xmlChar *)args[1];

				xpathContextAs29(ctx, str);
				xmlXPathObjectPtr result = xmlXPathEvalExpression(str, ctx);
				if (NULL != result)
				{
					char *cDelimiter;
					if (nargs > 2)
						cDelimiter = args[2];
					else
						cDelimiter = (char *)"\n";
					char *xpaths = XML_ObjectPtr_to_Xpaths(result, cDelimiter);
					if (NULL != xpaths)
					{
						*retstring = istrdup(xpaths);
						free(xpaths);
					}
					else
					{
						*retstring = istrdup(xmlerrors[XPATHERR_CANTRESOLVE]);
					}
					xmlXPathFreeObject(result);
				}
				xmlXPathFreeContext(ctx);
			}
			else
				*retstring = istrdup(xmlerrors[XPATHERR_BADDOCCONTEXT]);
		}
		else
			*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
	}
	else
		*retstring = istrdup(xmlerrors[XMLERR_BADDOCID]);
}

/**
 * XML_XPathDataFromQuery
 * @pDocID : xml tree id
 * @pExpression : xpath to evaluate
 * @pElementDelimiter : ]optional] delimiter between data elements (default="\n")
 * @pLineDelimiter : [optional] delimiter between data lines (default="\n")
 *
 * Returns a cr-separated list of data which is the result of
 * evaluating the expression against the xml tree
 *
 * put revXMLDataFromXPathQuery(tDocID, "/bookstore/books/[price<30]title", tab, cr)
 */
void XML_XPathDataFromQuery(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;

	// The tree and the expression are needed: without them args[1] was
	//   read past the end of args, and the engine crashed.
	if (nargs < 2)
	{
		*error = True;
		*retstring = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
		return;
	}

	int docID = atoi(args[0]);
	CXMLDocument *xmlDocument = doclist.find(docID);
	if (NULL != xmlDocument)
	{
		xmlDocPtr xmlDoc = xmlDocument->GetDocPtr();
		if (NULL != xmlDoc)
		{
			xmlXPathContextPtr ctx = xmlXPathNewContext(xmlDoc);
			if (NULL != ctx)
			{
				xmlChar *str = (xmlChar *)args[1];

				xpathContextAs29(ctx, str);
				xmlXPathObjectPtr result = xmlXPathEvalExpression(str, ctx);
				if (NULL != result)
				{
					char *charDelimiter;
					char *lineDelimiter;
					if (nargs > 2)
						charDelimiter = args[2];
					else
						charDelimiter = (char *)"\n";
					if (nargs > 3)
						lineDelimiter = args[3];
					else
						lineDelimiter = (char *)"\n";
					char *xpaths = XML_ObjectPtr_to_Data(result, charDelimiter, lineDelimiter);
					if (NULL != xpaths)
					{
						*retstring = istrdup(xpaths);
						free(xpaths);
					}
					else
					{
						*retstring = istrdup(xmlerrors[XPATHERR_CANTRESOLVE]);
					}
					xmlXPathFreeObject(result);
				}
				xmlXPathFreeContext(ctx);
			}
			else
				*retstring = istrdup(xmlerrors[XPATHERR_BADDOCCONTEXT]);
		}
		else
			*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
	}
	else
		*retstring = istrdup(xmlerrors[XMLERR_BADDOCID]);
}

// MDW-2013-08-09: [[ RevXmlXslt ]]
// XML stylesheet transformation functions

/**
 * XML_xsltLoadStylesheet
 * @pStylesheetDocID : xml document id
 *
 * returns an xsltStylesheetPtr which can be used in xsltApplyStyleSheet.
 * it's up to the user to free the stylesheet pointer after processing.
 *
 * put xsltLoadStylesheet(tStylesheetDocID)
 */
void XML_xsltLoadStylesheet(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	xsltStylesheetPtr cur = NULL;
	char *result;

	if (1 == nargs)
	{
		int docID = atoi(args[0]);
		CXMLDocument *xsltDocument = doclist.find(docID);
		if (NULL != xsltDocument)
		{
			xmlDocPtr xmlDoc = xsltDocument->GetDocPtr();
			if (NULL != xmlDoc)
			{
				// The stylesheet owns the document it is made from and frees it
				//   with itself, so give it a copy: the tree stays the caller's
				//   and can be deleted first, without leaving the stylesheet
				//   pointing at a freed document, which revXMLDeleteAllTrees
				//   (or quitting) then freed a second time. revXMLDeleteTree on
				//   the stylesheet's id frees the stylesheet and its copy.
				xmlDocPtr t_copy = xmlCopyDoc(xmlDoc, 1);
				if (NULL != t_copy)
				{
					cur = xsltParseStylesheetDoc(t_copy);
					if (NULL == cur)
						xmlFreeDoc(t_copy);
				}
				if (NULL != cur)
				{
					CXMLDocument *newdoc = new (nothrow) CXMLDocument(cur);
					doclist.add(newdoc);
					unsigned int docid = newdoc->GetID();

					result = (char *)malloc(INTSTRSIZE);
					sprintf(result,"%d",docid);
				
					*retstring = istrdup(result);
					free(result);
				}
				else
				{
					// couldn't parse the stylesheet
					*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
				}
			}
			// couldn't dereference the xml document
			else
				*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
		}
		// couldn't dereference the xml id
		else
			*retstring = istrdup(xmlerrors[XMLERR_BADDOCID]);
	}
	// only one argument permitted
	else
		*retstring = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
}

/**
 * XML_xsltLoadStylesheetFromFile
 * @pStylesheetPath : path to stylesheet file
 *
 * returns an xsltStylesheetPtr which can be used in xsltApplyStyleSheet
 * it's up to the user to free the stylesheet pointer after processing.
 *
 * put xsltLoadStylesheetFromFile(tPathToStylesheet)
 */
void XML_xsltLoadStylesheetFromFile(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	xsltStylesheetPtr cur = NULL;
	char *result;

	if (1 == nargs)
	{
		// MW-2013-09-11: [[ RevXmlXslt ]] Resolve the input path using the
		//   standard LiveCode convention.
		char *t_resolved_path;
		t_resolved_path = os_path_resolve(args[0]);
		char *t_native_path;
		t_native_path = revxml_path_for_libxml(t_resolved_path);
		
		cur = xsltParseStylesheetFile((const xmlChar *)t_native_path);
		if (NULL != cur)
		{
			CXMLDocument *newdoc = new (nothrow) CXMLDocument(cur);
			doclist.add(newdoc);
			unsigned int docid = newdoc->GetID();
			result = (char *)malloc(INTSTRSIZE);
			sprintf(result,"%d",docid);
			*retstring = istrdup(result);
			free(result);
		}
		else
		{
			// couldn't parse the stylesheet
			*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
		}
		
		free(t_native_path);
		free(t_resolved_path);
	}
	// only one argument permitted
	else
		*retstring = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
}

/**
 * XML_xsltFreeStylesheet
 * @pStylesheet : id of a stylesheet cursor
 *
 * frees a xsltStylesheetPtr created by xsltLoadStylesheet
 *
 * xsltFreeStylesheet tStylesheetID
 *
 * NOTE: this is no longer necessary, so I commented out the reference to it
 * but I'm keeping this here so I don't have to reinvent it if it becomes
 * necessary to pull it in again. MDW-2013-09-04
 */
void XML_xsltFreeStylesheet(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	xsltStylesheetPtr cur = NULL;

	if (1 == nargs)
	{
		int docID = atoi(args[0]);
		CXMLDocument *xsltDocument = doclist.find(docID);
		if (NULL != xsltDocument)
		{
			cur = xsltDocument->GetXsltContext();
			if (NULL != cur)
			{
				// Deleting the object frees the stylesheet; freeing it here
				//   as well would free it twice.
				doclist.erase(docID);
				*retstring = (char *)calloc(1,1);
			}
			else
			{
				*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
			}
		}
		else
		{
			// couldn't dereference the xml id
			*retstring = istrdup(xmlerrors[XMLERR_BADDOCID]);
		}
	}
	// only one argument permitted
	else
		*retstring = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
}

/**
 * XML_xsltApplyStylesheet
 * @pDocID : xml tree id (already parsed)
 * @pStylesheet : xsltStylesheetPtr from xsltLoadStylesheet
 * @pParamList : [optional] delimiter between data elements (default="\n")
 *
 * Returns the transformed xml data after applying the stylesheet.
 * Note that the user must free the stylesheet document after processing.
 *
 * put xsltApplyStylesheet(tDocID, tStylesheet, tParamList)
 * xsltFreeStylesheet tStylesheet
 */
void XML_xsltApplyStylesheet(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	xmlDocPtr res;
	xsltStylesheetPtr cur = NULL;
	int nbparams = 0;
	const char *params[16 + 1];
	
	xmlChar *doc_txt_ptr;
	int doc_txt_len;

	if (2 <= nargs)
	{
		int docID = atoi(args[0]);
		CXMLDocument *xmlDocument = doclist.find(docID);
		if (NULL != xmlDocument)
		{
			xmlDocPtr xmlDoc = xmlDocument->GetDocPtr();
			if (NULL != xmlDoc)
			{
				docID = atoi(args[1]);
				CXMLDocument *xsltDocument = doclist.find(docID);
				
				// MW-2013-09-11: [[ RevXmlXslt ]] Only try to fetch the xsltContext if
				//   we found the document.
				if (xsltDocument != NULL)
					cur = xsltDocument -> GetXsltContext();
				
				if (NULL != cur)
				{
					if (nargs > 2)
					{
						// no parameter support yet
						params[nbparams] = NULL;
					}
					else
					{
						params[nbparams] = NULL;
					}
					res = xsltApplyStylesheet(cur, xmlDoc, params);

					doc_txt_ptr = NULL;
					if (res != NULL)
						xsltSaveResultToString(&doc_txt_ptr, &doc_txt_len, res, cur);

					// libxslt leaves doc_txt_ptr NULL when the transform failed
					//   or made nothing, and the text is the caller's to free.
					*retstring = istrdup(doc_txt_ptr != NULL ? (char *)doc_txt_ptr : "");
					if (doc_txt_ptr != NULL)
						xmlFree(doc_txt_ptr);

					// free the xml document - we're done with it
					xmlFreeDoc(res);
				}
				else
					*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
			}
			else
				*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
		}
		else
			*retstring = istrdup(xmlerrors[XMLERR_BADDOCID]);
	}
	// requires at least docID and stylesheetPtr arguments
	else
		*retstring = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
}

/**
 * XML_xsltApplyStylesheetFile
 * @pDocID : xml tree id (already parsed)
 * @pStylesheetPath : path to stylesheet file
 * @pParamList : [optional] delimiter between data elements (default="\n")
 *
 * Returns the transformed xml data after applying the stylesheet.
  *
 * put xsltApplyStylesheet(tDocID, tStylesheetPath, tParamList)
 */
void XML_xsltApplyStylesheetFile(char *args[], int nargs, char **retstring, Bool *pass, Bool *error)
{
	*pass = False;
	*error = False;
	xmlDocPtr res;
	xsltStylesheetPtr cur = NULL;
	int nbparams = 0;
	const char *params[16 + 1];

	xmlChar *doc_txt_ptr;
	int doc_txt_len;

	if (2 <= nargs)
	{
		int docID = atoi(args[0]);
		CXMLDocument *xmlDocument = doclist.find(docID);
		if (NULL != xmlDocument)
		{
			xmlDocPtr xmlDoc = xmlDocument->GetDocPtr();
			if (NULL != xmlDoc)
			{
				// MW-2013-09-11: [[ RevXmlXslt ]] Resolve the input path using the
				//   standard LiveCode convention.
				char *t_resolved_path;
				t_resolved_path = os_path_resolve(args[1]);
				char *t_native_path;
				t_native_path = revxml_path_for_libxml(t_resolved_path);
				
				cur = xsltParseStylesheetFile((const xmlChar *)t_native_path);
				if (NULL != cur)
				{
					if (nargs > 2)
					{
						// no parameter support yet
						params[nbparams] = NULL;
					}
					else
					{
						params[nbparams] = NULL;
					}
					res = xsltApplyStylesheet(cur, xmlDoc, params);

					doc_txt_ptr = NULL;
					if (res != NULL)
						xsltSaveResultToString(&doc_txt_ptr, &doc_txt_len, res, cur);

					// libxslt leaves doc_txt_ptr NULL when the transform failed
					//   or made nothing, and the text is the caller's to free.
					*retstring = istrdup(doc_txt_ptr != NULL ? (char *)doc_txt_ptr : "");
					if (doc_txt_ptr != NULL)
						xmlFree(doc_txt_ptr);

					// free the xsltStylesheetPtr we just created
					xsltFreeStylesheet(cur);
					// free the xml document - we're done with it
					xmlFreeDoc(res);
				}
				// couldn't dereference the stylesheet document
				else
					*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
				
				free(t_native_path);
				free(t_resolved_path);
			}
			// couldn't dereference the xml document
			else
				*retstring = istrdup(xmlerrors[XPATHERR_BADDOCPOINTER]);
		}
		// couldn't dereference the xml id
		else
			*retstring = istrdup(xmlerrors[XMLERR_BADDOCID]);
	}
	// requires at least docID and stylesheetPath arguments
	else
		*retstring = istrdup(xmlerrors[XMLERR_BADARGUMENTS]);
}

EXTERNAL_BEGIN_DECLARATIONS("revXML")
	EXTERNAL_DECLARE_FUNCTION("revXMLinit", XML_Init)
	EXTERNAL_DECLARE_FUNCTION("revXML_version", REVXML_Version)

//HS-2010-10-11: [[ Bug 7586 ]] Reinstate libxml2 to create name spaces. Implement new liveCode commands to suppress name space creation.
	EXTERNAL_DECLARE_FUNCTION("revCreateXMLTree", XML_NewDocumentNS)
    EXTERNAL_DECLARE_FUNCTION("revCreateXMLTreeWithNamespaces", XML_NewDocumentNNS)
    EXTERNAL_DECLARE_FUNCTION("revCreateXMLTreeFromFile", XML_NewDocumentFromFileNS)
    EXTERNAL_DECLARE_FUNCTION("revCreateXMLTreeFromFileWithNamespaces", XML_NewDocumentFromFileNNS)

    EXTERNAL_DECLARE_FUNCTION("revXMLText", XML_GetDocText)
	EXTERNAL_DECLARE_FUNCTION("revXMLTrees", XML_Documents)
	EXTERNAL_DECLARE_COMMAND("revDeleteXMLTree", XML_FreeDocument)
	EXTERNAL_DECLARE_COMMAND("revXMLAddDTD", XML_AddDTD)
	EXTERNAL_DECLARE_FUNCTION("revXMLValidateDTD", XML_ValidateDTD)
	EXTERNAL_DECLARE_COMMAND("revAppendXML", XML_AddXML)
	EXTERNAL_DECLARE_COMMAND("revDeleteAllXMLTrees", XML_FreeAll)

	EXTERNAL_DECLARE_COMMAND("revAddXMLNode", XML_AddElement)
	EXTERNAL_DECLARE_COMMAND("revDeleteXMLNode", XML_RemoveElement)
	EXTERNAL_DECLARE_COMMAND("revInsertXMLNode", XML_InsertElement)
	EXTERNAL_DECLARE_COMMAND("revMoveXMLNode", XML_MoveElement)
	EXTERNAL_DECLARE_COMMAND("revCopyXMLNode", XML_CopyElement)
	EXTERNAL_DECLARE_COMMAND("revCopyRemoteXMLNode", XML_CopyRemoteElement)
	EXTERNAL_DECLARE_COMMAND("revMoveRemoteXMLNode", XML_MoveRemoteElement)
	EXTERNAL_DECLARE_FUNCTION("revXMLNodeContents", XML_GetElementContents)
	EXTERNAL_DECLARE_COMMAND("revPutIntoXMLNode", XML_SetElementContents)
	EXTERNAL_DECLARE_FUNCTION("revXMLRootNode", XML_RootName)
	EXTERNAL_DECLARE_FUNCTION("revXMLFirstChild", XML_GetChildPath)
	EXTERNAL_DECLARE_FUNCTION("revXMLNextSibling", XML_GetNextSiblingPath)
	EXTERNAL_DECLARE_FUNCTION("revXMLPreviousSibling", XML_GetPrevSiblingPath)
	EXTERNAL_DECLARE_FUNCTION("revXMLParent", XML_GetParentPath)
	EXTERNAL_DECLARE_FUNCTION("revXMLNumberOfChildren", XML_ChildCount)
	EXTERNAL_DECLARE_FUNCTION("revXMLChildNames", XML_Children)
	EXTERNAL_DECLARE_FUNCTION("revXMLTree", XML_Tree)
	EXTERNAL_DECLARE_FUNCTION("revXMLChildContents", XML_ListOfChildText)

	EXTERNAL_DECLARE_COMMAND("revSetXMLAttribute", XML_SetAttributeValue)
	EXTERNAL_DECLARE_FUNCTION("revXMLAttribute", XML_GetAttributeValue)
	EXTERNAL_DECLARE_COMMAND("revXMLRemoveAttribute", XML_RemoveAttribute)
	EXTERNAL_DECLARE_FUNCTION("revXMLAttributes", XML_ListOfAttributes)
	EXTERNAL_DECLARE_FUNCTION("revXMLMatchingNode", XML_FindElementByAttributeValue)
	EXTERNAL_DECLARE_FUNCTION("revXMLAttributeValues", XML_ListByAttributeValue)
// MDW-2013-06-22: [[ RevXmlXPath ]]
	// declared preferred synonyms for consistency and sanity
	// propose deprecating the old keywords
	EXTERNAL_DECLARE_FUNCTION("revXMLCreateTree", XML_NewDocumentNS)
    	EXTERNAL_DECLARE_FUNCTION("revXMLCreateTreeWithNamespaces", XML_NewDocumentNNS)
    	EXTERNAL_DECLARE_FUNCTION("revXMLCreateTreeFromFile", XML_NewDocumentFromFileNS)
    	EXTERNAL_DECLARE_FUNCTION("revXMLCreateTreeFromFileWithNamespaces", XML_NewDocumentFromFileNNS)
	EXTERNAL_DECLARE_COMMAND("revXMLDeleteTree", XML_FreeDocument)
	EXTERNAL_DECLARE_COMMAND("revXMLAppend", XML_AddXML)
	EXTERNAL_DECLARE_COMMAND("revXMLDeleteAllTrees", XML_FreeAll)
	EXTERNAL_DECLARE_COMMAND("revXMLAddNode", XML_AddElement)
	EXTERNAL_DECLARE_COMMAND("revXMLDeleteNode", XML_RemoveElement)
	EXTERNAL_DECLARE_COMMAND("revXMLInsertNode", XML_InsertElement)
	EXTERNAL_DECLARE_COMMAND("revXMLMoveNode", XML_MoveElement)
	EXTERNAL_DECLARE_COMMAND("revXMLCopyNode", XML_CopyElement)
	EXTERNAL_DECLARE_COMMAND("revXMLCopyRemoteNode", XML_CopyRemoteElement)
	EXTERNAL_DECLARE_COMMAND("revXMLMoveRemoteNode", XML_MoveRemoteElement)
	EXTERNAL_DECLARE_COMMAND("revXMLPutIntoNode", XML_SetElementContents)
	EXTERNAL_DECLARE_COMMAND("revXMLSetAttribute", XML_SetAttributeValue)

// MDW-2013-06-22: [[ RevXmlXPath ]]
	EXTERNAL_DECLARE_FUNCTION("revXMLEvaluateXPath", XML_EvalXPath)
	EXTERNAL_DECLARE_FUNCTION("revXMLDataFromXPathQuery", XML_XPathDataFromQuery)

// MDW-2013-08-09: [[ RevXmlXslt ]]
	EXTERNAL_DECLARE_FUNCTION("xsltApplyStylesheet", XML_xsltApplyStylesheet)
	EXTERNAL_DECLARE_FUNCTION("xsltApplyStylesheetFile", XML_xsltApplyStylesheetFile)
	EXTERNAL_DECLARE_FUNCTION("xsltLoadStylesheet", XML_xsltLoadStylesheet)
	EXTERNAL_DECLARE_FUNCTION("xsltLoadStylesheetFromFile", XML_xsltLoadStylesheetFromFile)
//	EXTERNAL_DECLARE_COMMAND("xsltFreeStylesheet", XML_xsltFreeStylesheet)
EXTERNAL_END_DECLARATIONS


#ifdef _WINDOWS
#include <windows.h>

extern void REVXML_INIT();
extern void REVXML_QUIT();

extern "C" BOOL XMLCALL xmlDllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved);

BOOL WINAPI DllMain(HINSTANCE tInstance, DWORD dwReason, LPVOID lpReserved)
{
	if (dwReason == DLL_PROCESS_ATTACH)
		REVXML_INIT();
	else if (dwReason == DLL_PROCESS_DETACH)
		REVXML_QUIT();

	return xmlDllMain(tInstance, dwReason, lpReserved);
}
#endif

