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

#include "cxml.h"
#if defined _MACOSX || defined ( _LINUX ) || defined (TARGET_SUBPLATFORM_ANDROID)
#define _vsnprintf vsnprintf
#endif

//---------------------------------------GENERAL UTILITY FUNCTIONS------------------------------------


#define WHOLEMATCHES 1

int util_strnicmp(const char *one, const char *two, int n)
{
  const char *optr = (const char *)one;
  const char *tptr = (const char *)two;
  while (n--) {
    if (*optr != *tptr) {
      char o = tolower(*optr);
      char t = tolower(*tptr);
      if (o != t || o == '\0' || t == '\0')
	return o - t;
    }
    optr++;
    tptr++;
  }
  if (!WHOLEMATCHES || !*optr)
  return 0;
  return 1;
}

int util_strncmp(const char *one, const char *two, int n)
{
  const char *optr = (const char *)one;
  const char *tptr = (const char *)two;
  while (n--) {
    if (*optr != *tptr) {
      char o = *optr;
      char t = *tptr;
      if (o != t || o == '\0' || t == '\0')
	return o - t;
    }
    optr++;
    tptr++;
  }
  if (!WHOLEMATCHES || !*optr)
  return 0;
  return 1;
}

const char *util_strchr(const char *sptr, char target, int l)
{
  if (!l) l = strlen(sptr);
  const char *eptr = sptr + l;
  while (sptr < eptr) {
    if (*sptr == target) 
      return sptr;
    sptr++;
  }
  return NULL;
}

//utility function used to concat two strings..and reallocate string if neccessary
void util_concatstring(const char *s, int slen, char *&d, int &dlen, int &dalloc)
{
	int newbufsize = dalloc;
	while (dlen + slen + 1 > newbufsize)
		newbufsize += BUFSIZEINC;
	if (newbufsize != dalloc){
		dalloc = newbufsize;
		d = (char *)realloc(d, dalloc);
	}
	memcpy(d + dlen, s, slen);
	dlen += slen;


}


//----------------------------------CXMLDOCUMENT STATIC MEMBERS AND METHODS-----------------------------
unsigned int CXMLDocument::idcounter = 0;
Bool CXMLDocument::buildtree = True;
Bool CXMLDocument::allowcallbacks = False;
char CXMLDocument::errorbuf[256] = "";

// A reference to an entity that is not declared. libxml2 2.9 made a
//   reference node for one only when the entity might be declared where it
//   was not read (an external subset or a parameter entity, and the
//   document not standalone); otherwise it reported the error and dropped
//   the reference, so in a parse of bad data (recover mode) "x &nbsp; y"
//   stayed one text node "x  y". 2.15 makes a reference node for every
//   undeclared entity, which ended revXMLNodeContents and
//   revXMLChildContents at the reference, split revXMLDataFromXPathQuery
//   results, and put "&nbsp;" into revXMLText. A declared entity is still
//   a reference node, as it was in 2.9.
static void referenceCallback(void *ctx, const xmlChar *name)
{
	xmlParserCtxtPtr t_ctxt = (xmlParserCtxtPtr)ctx;
	if (t_ctxt != NULL &&
		(t_ctxt -> standalone == 1 || (t_ctxt -> hasExternalSubset == 0 && t_ctxt -> hasPErefs == 0)) &&
		(t_ctxt -> myDoc == NULL || xmlGetDocEntity(t_ctxt -> myDoc, name) == NULL))
		return;
	xmlSAX2Reference(ctx, name);
}

// A CDATA section that follows another directly. libxml2 2.9 added it to
//   that section's node, so "<a><![CDATA[x]]><![CDATA[y]]></a>" was one node
//   "xy" (the usual way to write "]]>" in CDATA is to split the section
//   there). 2.15 makes a node for each section, and revXMLNodeContents,
//   which reads the first text or CDATA child, returned only "x".
static void appendCDataBlock(void *ctx, const xmlChar *ch, int len)
{
	xmlParserCtxtPtr t_ctxt = (xmlParserCtxtPtr)ctx;
	if (t_ctxt != NULL && t_ctxt -> node != NULL && t_ctxt -> node -> last != NULL &&
		t_ctxt -> node -> last -> type == XML_CDATA_SECTION_NODE)
	{
		xmlTextConcat(t_ctxt -> node -> last, ch, len);
		return;
	}
	xmlSAX2CDataBlock(ctx, ch, len);
}

// The declaration of attribute p_name of element p_element in the internal
//   or the external subset, as libxml2 2.9 looked it up to normalize the
//   attribute's value: by the element's qualified name, then, when names are
//   split at their prefix, by its local name.
static xmlAttributePtr getAttributeDecl(xmlDocPtr p_doc, const xmlChar *p_element, const xmlChar *p_name, bool p_namespaces)
{
	xmlAttributePtr t_decl;
	t_decl = xmlGetDtdAttrDesc(p_doc -> intSubset, p_element, p_name);
	if (t_decl == NULL)
		t_decl = xmlGetDtdAttrDesc(p_doc -> extSubset, p_element, p_name);
	if (t_decl == NULL && p_namespaces)
	{
		int t_prefix_length;
		const xmlChar *t_local;
		t_local = xmlSplitQName3(p_element, &t_prefix_length);
		if (t_local != NULL && *t_local != '\0')
		{
			t_decl = xmlGetDtdAttrDesc(p_doc -> intSubset, t_local, p_name);
			if (t_decl == NULL)
				t_decl = xmlGetDtdAttrDesc(p_doc -> extSubset, t_local, p_name);
		}
	}
	return t_decl;
}

// The attributes of a start tag, with the value of each one that the DTD
//   declares with a type other than CDATA (ID, IDREF, NMTOKENS, an
//   enumeration...) normalized: no leading or trailing spaces, and each run
//   of spaces made one. libxml2 2.9 did this as it built the tree, whether
//   it validated or not; 2.15 does it only when it validates, so
//   id=" a1 " stayed " a1 " in revXMLAttribute and revXMLAttributes, and
//   id('a1') in XPath and revXMLMatchingNode did not find it. Returns
//   p_atts itself when no value changes, else a copy that
//   freeNormalizedAttributes frees. The SAX messages get the values as
//   parsed, as they did with 2.9.
static const xmlChar **normalizeDeclaredAttributes(void *ctx, const xmlChar *p_element, const xmlChar **p_atts, bool p_namespaces)
{
	xmlParserCtxtPtr t_ctxt = (xmlParserCtxtPtr)ctx;
	if (p_atts == NULL || t_ctxt == NULL || t_ctxt -> myDoc == NULL ||
		(t_ctxt -> myDoc -> intSubset == NULL && t_ctxt -> myDoc -> extSubset == NULL))
		return p_atts;

	const xmlChar **t_atts = NULL;
	for (size_t i = 0; p_atts[i] != NULL && p_atts[i + 1] != NULL; i += 2)
	{
		xmlAttributePtr t_decl;
		t_decl = getAttributeDecl(t_ctxt -> myDoc, p_element, p_atts[i], p_namespaces);
		if (t_decl == NULL || t_decl -> atype == XML_ATTRIBUTE_CDATA)
			continue;

		xmlChar *t_value = xmlStrdup(p_atts[i + 1]);
		if (t_value == NULL)
			continue;
		const xmlChar *t_src = t_value;
		xmlChar *t_dst = t_value;
		while (*t_src == 0x20)
			t_src++;
		while (*t_src != 0)
		{
			if (*t_src == 0x20)
			{
				while (*t_src == 0x20)
					t_src++;
				if (*t_src != 0)
					*t_dst++ = 0x20;
			}
			else
				*t_dst++ = *t_src++;
		}
		*t_dst = 0;
		if (xmlStrEqual(t_value, p_atts[i + 1]))
		{
			xmlFree(t_value);
			continue;
		}

		if (t_atts == NULL)
		{
			// The copy ends with two NULLs, as libxml2's own list does.
			size_t t_count = i;
			while (p_atts[t_count] != NULL && p_atts[t_count + 1] != NULL)
				t_count += 2;
			t_atts = (const xmlChar **)xmlMalloc((t_count + 2) * sizeof(xmlChar *));
			if (t_atts == NULL)
			{
				xmlFree(t_value);
				return p_atts;
			}
			memcpy(t_atts, p_atts, t_count * sizeof(xmlChar *));
			t_atts[t_count] = NULL;
			t_atts[t_count + 1] = NULL;
		}
		t_atts[i + 1] = t_value;
	}
	return t_atts != NULL ? t_atts : p_atts;
}

static void freeNormalizedAttributes(const xmlChar **p_atts, const xmlChar **p_normalized)
{
	if (p_normalized == p_atts)
		return;
	for (size_t i = 0; p_normalized[i] != NULL; i += 2)
		if (p_normalized[i + 1] != p_atts[i + 1])
			xmlFree((xmlChar *)p_normalized[i + 1]);
	xmlFree((void *)p_normalized);
}

//lists of callbacks - used to establish custom callbacks for parse errors, other callbacks in future
// A SAX1 handler (initialized is 1, not XML_SAX2_MAGIC), so that libxml2
// calls startElement and endElement with whole names. libxml2 2.14 removed
// the old unprefixed names of its default handlers (internalSubset,
// startElement...); these are the same handlers under their xmlSAX2 names.
xmlSAXHandler CXMLDocument::SAXHandlerTable = {
    xmlSAX2InternalSubset,
    xmlSAX2IsStandalone,
    xmlSAX2HasInternalSubset,
    xmlSAX2HasExternalSubset,
    xmlSAX2ResolveEntity,
    xmlSAX2GetEntity,
    xmlSAX2EntityDecl,
    xmlSAX2NotationDecl,
    xmlSAX2AttributeDecl,
    xmlSAX2ElementDecl,
    xmlSAX2UnparsedEntityDecl,
    xmlSAX2SetDocumentLocator,
    startDocumentCallback,//startDocument
    endDocumentCallback,//endDocument
    startElementCallback,//startElement
    endElementCallback,//endElement
    referenceCallback,
	elementDataCallback, //characters,
    xmlSAX2IgnorableWhitespace,
    xmlSAX2ProcessingInstruction,
    xmlSAX2Comment,
    warningCallback,
    errorCallback,
    fatalCallback,
    xmlSAX2GetParameterEntity,
    elementCDataCallback,//cdataBlock,
    xmlSAX2ExternalSubset,
	1,
    NULL,
    NULL,
    NULL,
    NULL,
};

void CXMLDocument::startDocumentCallback(void *ctx)
{
	if (allowcallbacks && revxml_sax_sending(ctx))
		CB_startDocument();
	xmlSAX2StartDocument(ctx);
}

void CXMLDocument::endDocumentCallback(void *ctx)
{
	if (allowcallbacks)
	{
		revxml_sax_flush(ctx);
		CB_endDocument();
	}
	xmlSAX2EndDocument(ctx);
}

void CXMLDocument::startElementCallback(void *ctx,
										const xmlChar *fullname,
										const xmlChar **atts)
{
    extern Bool XML_ProcessNameSpaces;
    revxml_parse_note_position(ctx);
    if (allowcallbacks)
		revxml_sax_start_element(ctx, fullname, atts);
	if (buildtree)
    {
		// The tree gets the attribute values normalized as libxml2 2.9 did
		//   (see normalizeDeclaredAttributes).
		const xmlChar **t_atts = normalizeDeclaredAttributes(ctx, fullname, atts, XML_ProcessNameSpaces == True);
        //HS-2010-10-11: [[ Bug 7586 ]] Reinstate libxml2 to create name spaces. Implement new liveCode commands to suppress name space creation.
        if (XML_ProcessNameSpaces)
        {
		    xmlSAX2StartElement(ctx,fullname,t_atts);
        }
        else
        {
            xmlSAX2StartElementNoNS(ctx,fullname,t_atts);
        }
		freeNormalizedAttributes(atts, t_atts);
    }
}

void CXMLDocument::endElementCallback(void *ctx,
									  const xmlChar *name)
{
	revxml_parse_note_position(ctx);
	if (allowcallbacks)
		revxml_sax_end_element(ctx, name);
	if (buildtree)
		xmlSAX2EndElement(ctx,name);
}


void CXMLDocument::elementCDataCallback(void *ctx,const xmlChar *ch,int len)
{
	revxml_parse_note_position(ctx);
	if (allowcallbacks)
		revxml_sax_text(ctx, ch, len, true);
	if (buildtree)
		appendCDataBlock(ctx,ch,len);
}


void CXMLDocument::elementDataCallback(void *ctx,const xmlChar *ch,int len)
{
	revxml_parse_note_position(ctx);
	// A character reference after native text, as 2.9 read it
	//   (xmlnative.cpp).
	if (!revxml_parse_char_ref(ctx, &ch, &len))
	{
		if (buildtree)
			xmlSAX2Reference(ctx, ch);
		return;
	}
	if (allowcallbacks)
		revxml_sax_text(ctx, ch, len, false);
	if (buildtree)
		xmlSAX2Characters(ctx,ch,len);
}
 

void CXMLDocument::warningCallback(void *ctx, const char *msg, ...)
{
    revxml_parse_note_error(ctx);
    va_list args;
    va_start(args, msg);
    _vsnprintf(errorbuf, 255, msg, args);
    va_end(args);
}

void CXMLDocument::errorCallback(void *ctx, const char *msg, ...)
{
    revxml_parse_note_error(ctx);
    va_list args;
    va_start(args, msg);
    _vsnprintf(errorbuf, 255, msg, args);
    va_end(args);
}

void CXMLDocument::fatalCallback(void *ctx, const char *msg, ...)
{
    revxml_parse_note_error(ctx);
    va_list args;
    va_start(args, msg);
	_vsnprintf(errorbuf, 255, msg, args);
    va_end(args);
}


//--------------------------------CXMLDOCUMENT MEMBER FUNCTIONS--------------------------------

/* New - creates new xml document. */
void CXMLDocument::New()
{
	Free(); //free document
	doc = xmlNewDoc((xmlChar *) "1.0");
}

/*Read - parse xml data and create xml tree
data - points to xml data to parse
tlength - length of xml data to parse
returns false on parse error
*/
/*Parse - parses xml data, or the file filename if data is NULL, with
the SAX handlers above, and returns the document or NULL
*/
xmlDocPtr CXMLDocument::Parse(const char *data, unsigned long tlength, const char *filename, Bool wellformed)
{
	// MW-2014-03-10: [[ Bug 11903 ]] Pass XML_PARSE_HUGE, so that the limits
	//   libxml2 2.9 introduced don't apply. LiveCode added its own functions
	//   to libxml2 for this; a parser context made with the SAX handlers
	//   does it with libxml2's own API. XML_PARSE_NOBLANKS keeps what
	//   xmlKeepBlanksDefault(0) did before: the options of a context
	//   replace libxml2's global defaults.
	// libxml2 2.15 keeps two limits even with XML_PARSE_HUGE, where 2.9 had
	//   none: elements nest at most 2048 deep, and a text node, attribute
	//   value or name holds at most 1,000,000,000 bytes. A deeper document
	//   is refused ("Excessive depth in document"), or, when bad data is
	//   parsed (XML_PARSE_RECOVER), cut off at that depth.
	int options;
	options = XML_PARSE_HUGE | XML_PARSE_NOBLANKS;
	if (!wellformed)
		options |= XML_PARSE_RECOVER;
	// A gzip-compressed file is read uncompressed, as libxml2 2.9 did for
	//   every file on macOS, Linux and the mobile platforms; since 2.14 that
	//   takes XML_PARSE_UNZIP. Data in memory never was uncompressed.
	if (data == NULL)
		options |= XML_PARSE_UNZIP;

	xmlParserCtxtPtr ctxt;
	ctxt = xmlNewSAXParserCtxt(&SAXHandlerTable, NULL);
	if (ctxt == NULL)
		return NULL;

	// libxml2 2.9 made no entity checks under XML_PARSE_HUGE: entities
	//   expanded without limit, so a small "billion laughs" document (an
	//   entity referring ten times to one referring ten times to...) made
	//   gigabytes. 2.15 keeps a check even with XML_PARSE_HUGE: past the
	//   first 1,000,000 bytes, entity text may expand to at most 5 times
	//   the document read so far ("Maximum entity amplification factor
	//   exceeded"), which an ordinary document reaches by using a declared
	//   entity in many places (a 2,000-byte entity in 600 elements of a
	//   27,000-byte file is about 50 times). Reuse expands at most by the
	//   ratio of an entity's size to that of a reference to it, so allow
	//   1000 times: a document would need an entity of many kilobytes,
	//   referred to back to back thousands of times, to reach it, while
	//   nested entities, which grow exponentially, are still refused at
	//   a size bounded by 1000 times the document.
	xmlCtxtSetMaxAmplification(ctxt, 1000);

	// Native text, text labelled UTF-16 and encodings libxml2 cannot read
	//   are read as 2.9 read them (xmlnative.cpp).
	xmlDocPtr result;
	result = revxml_parse(ctxt, data, tlength, filename, options, wellformed != False, allowcallbacks != False,
						  errorbuf, sizeof(errorbuf));

	xmlFreeParserCtxt(ctxt);
	return result;
}

Bool CXMLDocument::Read(char *data, unsigned long tlength, Bool wellformed)
{
	xmlKeepBlanksDefault(0);
	Free(); //free document	
	
	doc = Parse(data, tlength, NULL, wellformed);

	// OK-2007-12-17 : Bug 5632. If Validate() is called in this context it crashes
	// For now we just remove the validation step from here as it proved difficult to
	// find a way to make it work.
	//if (doc && wellformed && !Validate())
	//if (doc && wellformed)
	//	Free();

	return doc != NULL;
}

Bool CXMLDocument::ReadFile(char *filename,  Bool wellformed)
{
	xmlKeepBlanksDefault(0);
	Free(); //free document	
	
	doc = Parse(NULL, 0, filename, wellformed);

	// OK-2007-12-17 : Bug 5632. If Validate() is called in this context it crashes
	// For now we just remove the validation step from here as it proved difficult to
	// find a way to make it work.
	//if (doc && wellformed && !Validate())
	//	Free();

	return doc != NULL;
}

Bool CXMLDocument::Validate()
{
if (!isinited()) return False;
		if ((doc->intSubset == NULL) && (doc->extSubset == NULL))
			return True;
		// A validation context from libxml2, not one on the stack: libxml2
		// reads (and allocates) fields of it that this code never set.
		xmlValidCtxtPtr ctxt = xmlNewValidCtxt();
		if (ctxt == NULL)
			return False;
		//point to dtd error handling function
		ctxt->userData = NULL;
		ctxt->error = errorCallback; 
		ctxt->warning = warningCallback;
		Bool isvalid = xmlValidateDocument(ctxt, doc) == 1;
		xmlFreeValidCtxt(ctxt);
		return isvalid;
}

Bool CXMLDocument::AddDTD(char *data, unsigned long tlength)
{
	if (!isinited()) return False;
	xmlParserInputBufferPtr dtdInputBufferPtr; 
	xmlDtdPtr dtd; 
	dtdInputBufferPtr = xmlParserInputBufferCreateMem(data, tlength, XML_CHAR_ENCODING_UTF8); 
	dtd = xmlIOParseDTD(NULL, dtdInputBufferPtr, XML_CHAR_ENCODING_UTF8); 
	if (!dtd) return False;
	if (dtd->name != NULL)
		xmlFree((char*)dtd->name);
	CXMLElement telement;
	GetRootElement(&telement);
	dtd->name = xmlStrdup((xmlChar *)telement.GetName());
	doc->intSubset = dtd;
    if (dtd->ExternalID != NULL) { 
           xmlFree((xmlChar *) dtd->ExternalID); 
           dtd->ExternalID = NULL; 
       } 
       if (dtd->SystemID != NULL) { 
           xmlFree((xmlChar *) dtd->SystemID); 
           dtd->SystemID = NULL; 
       } 
	dtd->doc = doc;
	dtd->parent = doc;
	if (doc->children == NULL) xmlAddChild((xmlNodePtr)doc, (xmlNodePtr)dtd);
	else xmlAddPrevSibling(doc->children, (xmlNodePtr)dtd);
	return Validate();
}

Bool CXMLDocument::ValidateDTD(char *data, unsigned long tlength)
{
	if (!isinited()) return False;
	xmlParserInputBufferPtr dtdInputBufferPtr; 
	xmlDtdPtr dtd; 
	dtdInputBufferPtr = xmlParserInputBufferCreateMem(data, tlength, XML_CHAR_ENCODING_UTF8); 
	dtd = xmlIOParseDTD(NULL, dtdInputBufferPtr, XML_CHAR_ENCODING_UTF8); 
	if (!dtd) return False;
	xmlValidCtxtPtr ctxt = xmlNewValidCtxt();
	if (ctxt == NULL)
	{
		xmlFreeDtd(dtd);
		return False;
	}
	//point to dtd error handling function
	ctxt->userData = NULL;
	ctxt->error = errorCallback; 
	ctxt->warning = warningCallback;
	Bool isvalid = xmlValidateDtd(ctxt,doc,dtd);
	xmlFreeValidCtxt(ctxt);
	xmlFreeDtd(dtd);
	return isvalid;
}
	
/*Write - writes xml tree to buffer
output: 
data - is set to point to buffer containing xml data
tlength - is set to length of xml data
*/
void CXMLDocument::Write(char **data,int *tlength,Bool isformatted)
{
	if (!isinited()) return;
	xmlDocDumpFormatMemory(doc,(unsigned char**)data,tlength,isformatted);
}

/*Free - frees xml document*/
void CXMLDocument::Free()
{
	// The XPath context and the stylesheet first: a stylesheet's object has
	//   no document of its own (the stylesheet owns its copy and frees it),
	//   so returning when doc is NULL left revXMLDeleteTree on a stylesheet
	//   freeing nothing.
	if (NULL != xpathContext)
		xmlXPathFreeContext(xpathContext);
	xpathContext = NULL;
	// MDW-2013-09-04: [[ RevXmlXslt ]]
	if (NULL != xsltID)
		xsltFreeStylesheet(xsltID);
	xsltID = NULL;
	if (!isinited()) return;
	xmlFreeDoc(doc);
	doc = NULL;
}

/*CopyDocument - copies xml tree of other CXMLDocument
truecopy - if true this is set to point to xmltree of tdocument, 
otherwise this is set to point to a copy of xmltree in tdocument
output: tdocument - xml document to copy from
*/
void CXMLDocument::CopyDocument(CXMLDocument *tdocument,Bool truecopy)
{
	if (!tdocument->isinited()) return;
	Free();
	if (truecopy)
		doc = xmlCopyDoc(tdocument->GetDocPtr(),0);
	else
		doc = tdocument->GetDocPtr();
}

/*GetRootElement
telement - is set to point to root element, returns false on error
returns False on error
*/
Bool CXMLDocument::GetRootElement(CXMLElement *telement)
{
	if (!isinited()) return False;
	xmlNodePtr rootelement = xmlDocGetRootElement(doc);
	if (rootelement)
		telement->SetNodePtr(rootelement);
	return rootelement != NULL;
}

/*GetElementByPath
tpath - path of element in xml tree (ie. /rootelement/parentelement[1]/childelement)
telement - on success, output is set to point to element specified by tpath
return True if element found
*/
Bool CXMLDocument::GetElementByPath(CXMLElement *telement, char *tpath)
{
	if (!isinited()) return False;
	char *sptr = tpath;
	Bool isroot = False;

	if (!GetRootElement(telement))
		return False;

	if (*sptr == '/') sptr++;
	const char *nameend;
	char *nextname = strchr(sptr, '/');
	if (!nextname) 
	{
		if (!*sptr)
			return True;
		nextname = sptr+strlen(sptr);
		isroot = True;
		
	}
	const char *numpointer = util_strchr(sptr,'[',nextname-sptr);
	if (numpointer)
			nameend = numpointer;
	else
			nameend = nextname;
	if (!util_strnicmp(telement->GetName(),sptr,nameend-sptr))
    {
		if (isroot)
			return True;
		else
			return telement->GoChildByPath(nextname+1);
    }
	return False;
}
