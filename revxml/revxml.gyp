# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	'includes':
	[
		'../common.gypi',
	],
	
	'variables':
	{
		'revxml_sources':
		[
			'src/cxml.h',
			'src/revxml.h',
			'src/revxml.cpp',
			'src/xmlattribute.cpp',
			'src/xmldoc.cpp',
			'src/xmlelement.cpp',
			'src/xmlnative.cpp',
		],
	},
	
	'targets':
	[
		{
			'target_name': 'external-revxml',
			'type': 'loadable_module',
			'mac_bundle': 1,
			'product_prefix': '',
			'product_name': 'revxml',
			
			'dependencies':
            [
                '../libexternal/libexternal.gyp:libExternal',
                '../libexternal/libexternal.gyp:libExternal-symbol-exports',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_xml',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_xslt',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_z',
			],
			
			'include_dirs':
			[
				'src',
			],
			
			'sources':
			[
				'<@(revxml_sources)',
			],
			
			'xcode_settings':
			{
				'INFOPLIST_FILE': 'rsrc/revxml-Info.plist',
				'EXPORTED_SYMBOLS_FILE': 'revxml.exports',
			},
			
			'all_dependent_settings':
			{
				'variables':
				{
					'dist_files': [ '<(PRODUCT_DIR)/<(_product_name)>(ext_bundle_suffix)' ],
				},
			},
		
			'conditions':
			[
				[
					'OS == "android"',
					{
						'product_name': 'RevXml',
						'product_extension': '',
					},
				],
			],
		},
		{
			'target_name': 'external-revxml-server',
			'type': 'loadable_module',
			'product_prefix': '',
			'product_name': 'server-revxml',
			
			'dependencies':
			[
				'../libexternal/libexternal.gyp:libExternal',
                '../libexternal/libexternal.gyp:libExternal-symbol-exports',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_xml',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_xslt',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_z',
			],
			
			'include_dirs':
			[
				'src',
			],
			
			'sources':
			[
				'<@(revxml_sources)',
			],
			
			'xcode_settings':
			{
				'INFOPLIST_FILE': 'rsrc/revxml-Info.plist',
				'EXPORTED_SYMBOLS_FILE': 'revxml.exports',
			},

			'conditions':
			[
				[
					'OS == "linux"',
					{
						'libraries':
						[
							'-Wl,-Bstatic',
							'-lstdc++',
							'-Wl,-Bdynamic',
						],
					},
				],
			],
			
			'all_dependent_settings':
			{
				'variables':
				{
					'dist_files': [ '<(PRODUCT_DIR)/<(_product_name)>(lib_suffix)' ],
				},
			},
		},
	],

	# OXT-Beyond: revXML for the web engine, which links it into itself
	# (engine/src/em-externals.cpp). Its names, and those of its copy of
	# libExternal, are renamed for it (libexternal/src/external-static.h).
	'conditions':
	[
		[
			'OS == "emscripten"',
			{
				'targets':
				[
					{
						'target_name': 'external-revxml-static',
						'type': 'static_library',

						'dependencies':
						[
							'../libexternal/libexternal.gyp:libExternal-static-revxml',
							'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_xml',
							'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_xslt',
							'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_z',
						],

						'include_dirs':
						[
							'../libexternal/include',
							'../libexternal/src',
							'src',
						],

						'defines':
						[
							'EXTERNAL_STATIC_PREFIX=revxml',
							# its POSIX code
							'_LINUX',
						],

						'cflags':
						[
							'-include', 'external-static.h',
						],

						'sources':
						[
							'<@(revxml_sources)',
						],
					},
				],
			},
		],
	],
}
