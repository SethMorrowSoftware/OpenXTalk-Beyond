{
	'includes':
	[
		'../../common.gypi',
	],
	
	'targets':
	[
		{
			'target_name': 'libxml',
			
			'conditions':
			[
				[
					'use_system_libxml == 0',
					{
						'type': 'static_library',
						
						'variables':
						{
							'library_for_module': 1,
							'silence_warnings': 1,
						},
						
						'dependencies':
						[
							'../libz/libz.gyp:libz',
						],
						
						'include_dirs':
						[
							'include',
							'src',
							# The private headers ("private/buf.h"...),
							# kept where they find src/libxml.h.
							'src/include',
						],
						
						'defines':
						[
							# A static library: no dllexport or dllimport
							# on Windows.
							'LIBXML_STATIC=1',
						],
						
						'sources':
						[
							'include/libxml/HTMLparser.h',
							'include/libxml/HTMLtree.h',
							'include/libxml/SAX.h',
							'include/libxml/SAX2.h',
							'include/libxml/c14n.h',
							'include/libxml/catalog.h',
							'include/libxml/chvalid.h',
							'include/libxml/debugXML.h',
							'include/libxml/dict.h',
							'include/libxml/encoding.h',
							'include/libxml/entities.h',
							'include/libxml/globals.h',
							'include/libxml/hash.h',
							'include/libxml/list.h',
							'include/libxml/nanoftp.h',
							'include/libxml/nanohttp.h',
							'include/libxml/parser.h',
							'include/libxml/parserInternals.h',
							'include/libxml/pattern.h',
							'include/libxml/relaxng.h',
							'include/libxml/schemasInternals.h',
							'include/libxml/schematron.h',
							'include/libxml/threads.h',
							'include/libxml/tree.h',
							'include/libxml/uri.h',
							'include/libxml/valid.h',
							'include/libxml/xinclude.h',
							'include/libxml/xlink.h',
							'include/libxml/xmlIO.h',
							'include/libxml/xmlautomata.h',
							'include/libxml/xmlerror.h',
							'include/libxml/xmlexports.h',
							'include/libxml/xmlmemory.h',
							'include/libxml/xmlmodule.h',
							'include/libxml/xmlreader.h',
							'include/libxml/xmlregexp.h',
							'include/libxml/xmlsave.h',
							'include/libxml/xmlschemas.h',
							'include/libxml/xmlschemastypes.h',
							'include/libxml/xmlstring.h',
							'include/libxml/xmlunicode.h',
							'include/libxml/xmlversion.h',
							'include/libxml/xmlwriter.h',
							'include/libxml/xpath.h',
							'include/libxml/xpathInternals.h',
							'include/libxml/xpointer.h',
							
							'src/include/private/buf.h',
							'src/include/private/cata.h',
							'src/include/private/dict.h',
							'src/include/private/enc.h',
							'src/include/private/entities.h',
							'src/include/private/error.h',
							'src/include/private/globals.h',
							'src/include/private/html.h',
							'src/include/private/io.h',
							'src/include/private/lint.h',
							'src/include/private/memory.h',
							'src/include/private/parser.h',
							'src/include/private/regexp.h',
							'src/include/private/save.h',
							'src/include/private/string.h',
							'src/include/private/threads.h',
							'src/include/private/tree.h',
							'src/include/private/xinclude.h',
							'src/include/private/xpath.h',
							
							'src/config.h',
							'src/libxml.h',
							'src/timsort.h',
							
							'src/HTMLparser.c',
							'src/HTMLtree.c',
							'src/SAX2.c',
							'src/buf.c',
							'src/c14n.c',
							'src/catalog.c',
							'src/chvalid.c',
							'src/debugXML.c',
							'src/dict.c',
							'src/encoding.c',
							'src/entities.c',
							'src/error.c',
							'src/globals.c',
							'src/hash.c',
							'src/list.c',
							'src/parser.c',
							'src/parserInternals.c',
							'src/pattern.c',
							'src/relaxng.c',
							'src/schematron.c',
							'src/threads.c',
							'src/tree.c',
							'src/uri.c',
							'src/valid.c',
							'src/xinclude.c',
							'src/xlink.c',
							'src/xmlIO.c',
							'src/xmlmemory.c',
							'src/xmlreader.c',
							'src/xmlregexp.c',
							'src/xmlsave.c',
							'src/xmlschemas.c',
							'src/xmlschemastypes.c',
							'src/xmlstring.c',
							'src/xmlwriter.c',
							'src/xpath.c',
							'src/xpointer.c',
						],
						
						'direct_dependent_settings':
						{
							'include_dirs':
							[
								'include',
							],
							
							'defines':
							[
								'LIBXML_STATIC=1',
							],
						},
					},
					{
						'type': 'none',
						
						'link_settings':
						{
							'libraries':
							[
								'-lxml',
							],
						},
					},
				],
			],
		},
	],
}
