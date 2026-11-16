# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	'includes':
	[
		'../common.gypi',
	],
	
	'targets':
	[
		{
			'target_name': 'external-revspeech',
			'type': 'loadable_module',
			'mac_bundle': 1,
			'product_prefix': '',
			'product_name': 'revspeech',
			
			'dependencies':
			[
				'../libcore/libcore.gyp:libCore',
				'../libexternal/libexternal.gyp:libExternal',
			],
			
			'include_dirs':
			[
				'src',
			],
			
			'sources':
			[
				'src/osxspeech.h',
				'src/revspeech.h',
				'src/w32sapi5speech.h',
				'src/osxspeech.cpp',
				'src/revspeech.cpp',
				'src/w32sapi5speech.cpp',
				'src/w32speech.cpp',
			],
			
			'conditions':
			[
				[
					'OS != "mac" and OS != "win"',
					{
						'type': 'none',
					},
					{
						'all_dependent_settings':
						{
							'variables':
							{
								'dist_files': [ '<(PRODUCT_DIR)/<(_product_name)>(ext_bundle_suffix)' ],
							},
						},
					},
				],
				[
					'OS == "mac"',
					{
						'libraries':
						[
							'$(SDKROOT)/System/Library/Frameworks/Carbon.framework',
						],
					},
				],
				[
					'OS == "win"',
					{
						'libraries':
						[
							'-ladvapi32',
							'-lole32',
						],
					},
				],
			],
			
			'xcode_settings':
			{
				'INFOPLIST_FILE': 'rsrc/revspeech-Info.plist',
			},
		},
	],

	# OXT-Beyond: revSpeech for the web engine, which links it into itself
	# (engine/src/em-externals.cpp), with the browser's speech synthesis
	# (src/emscriptenspeech.cpp). Its names, and those of its copy of
	# libExternal, are renamed for it (libexternal/src/external-static.h).
	'conditions':
	[
		[
			'OS == "emscripten"',
			{
				'targets':
				[
					{
						'target_name': 'external-revspeech-static',
						'type': 'static_library',

						'dependencies':
						[
							'../libexternal/libexternal.gyp:libExternal-static-revspeech',
						],

						'include_dirs':
						[
							'../libexternal/include',
							'../libexternal/src',
							'src',
						],

						'defines':
						[
							'EXTERNAL_STATIC_PREFIX=revspeech',
						],

						'cflags':
						[
							'-include', 'external-static.h',
						],

						'sources':
						[
							'src/revspeech.h',
							'src/revspeech.cpp',
							'src/emscriptenspeech.cpp',
						],
					},
				],
			},
		],
	],
}
