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
			'target_name': 'libExternal',
			'type': 'static_library',

			'toolsets': ['host', 'target'],

			'variables':
			{
				'library_for_module': 1,
			},

			'dependencies':
			[
				'../libcore/libcore.gyp:libCore',
			],

			'include_dirs':
			[
				'include',
				'src',
			],
			
			'sources':
			[
				'include/revolution/external.h',
				'include/revolution/support.h',
				
				'src/external.c',
				'src/osxsupport.cpp',
				'src/unxsupport.cpp',
				'src/w32support.cpp',
			],
			
			'direct_dependent_settings':
			{
				'include_dirs':
				[
					'include',
				],
			},
			
			'conditions':
			[
				[
					'OS == "mac" or OS == "win"',
					{
						'sources!':
						[
							'src/unxsupport.cpp',
						],
					},
				],
			],
			
			'link_settings':
			{
				'conditions':
				[
					[
						'OS == "mac"',
						{
							'libraries':
							[
								'$(SDKROOT)/System/Library/Frameworks/CoreServices.framework',
							],
						},
					],
				],
			}
		},
		{
			'target_name': 'libExternal-symbol-exports',
			'type': 'none',
			
			'direct_dependent_settings':
			{				
				'variables':
				{
					'ios_external_symbols': 
					[ 
						'_getXtable', 
						'_setExternalInterfaceVersion', 
						'_configureSecurity',
					],
				},
			},
		},
	],

	# OXT-Beyond: the copies of libExternal for the externals that the web
	# engine links into itself (engine/src/em-externals.cpp), one for each,
	# with its names renamed for that external (src/external-static.h)
	'conditions':
	[
		[
			'OS == "emscripten"',
			{
				'targets':
				[
				{
					'target_name': 'libExternal-static-revxml',
					'type': 'static_library',

					'dependencies':
					[
						'../libcore/libcore.gyp:libCore',
					],

					'include_dirs':
					[
						'include',
						'src',
					],

					'defines':
					[
						'EXTERNAL_STATIC_PREFIX=revxml',
					],

					'cflags':
					[
						'-include', 'external-static.h',
					],

					'sources':
					[
						'src/external.c',
						'src/unxsupport.cpp',
					],
				},
				{
					'target_name': 'libExternal-static-revzip',
					'type': 'static_library',

					'dependencies':
					[
						'../libcore/libcore.gyp:libCore',
					],

					'include_dirs':
					[
						'include',
						'src',
					],

					'defines':
					[
						'EXTERNAL_STATIC_PREFIX=revzip',
					],

					'cflags':
					[
						'-include', 'external-static.h',
					],

					'sources':
					[
						'src/external.c',
						'src/unxsupport.cpp',
					],
				},
				{
					'target_name': 'libExternal-static-revdb',
					'type': 'static_library',

					'dependencies':
					[
						'../libcore/libcore.gyp:libCore',
					],

					'include_dirs':
					[
						'include',
						'src',
					],

					'defines':
					[
						'EXTERNAL_STATIC_PREFIX=revdb',
					],

					'cflags':
					[
						'-include', 'external-static.h',
					],

					'sources':
					[
						'src/external.c',
						'src/unxsupport.cpp',
					],
				},
				{
					'target_name': 'libExternal-static-revspeech',
					'type': 'static_library',

					'dependencies':
					[
						'../libcore/libcore.gyp:libCore',
					],

					'include_dirs':
					[
						'include',
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
						'src/external.c',
						'src/unxsupport.cpp',
					],
				},
				{
					'target_name': 'libExternal-static-dbsqlite',
					'type': 'static_library',

					'dependencies':
					[
						'../libcore/libcore.gyp:libCore',
					],

					'include_dirs':
					[
						'include',
						'src',
					],

					'defines':
					[
						'EXTERNAL_STATIC_PREFIX=dbsqlite',
					],

					'cflags':
					[
						'-include', 'external-static.h',
					],

					# A database driver calls no external interface: it uses
					# the support functions, and has MCSupportLibraryLoad and
					# the others of its own (revdb/src/dbdrivercommon.cpp)
					'sources':
					[
						'src/unxsupport.cpp',
					],
				},
				],
			},
		],
	],
}
