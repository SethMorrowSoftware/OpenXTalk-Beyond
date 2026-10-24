{
	'includes':
	[
		'../common.gypi',
	],

	# mergJSON, Monte Goulding's JSON external (GPL 3), with the copy of
	# Jansson it is written for (MIT): see README.md. The sources are as
	# upstream; this file builds them as the other externals are built,
	# against libExternal.
	'variables':
	{
		'mergjson_sources':
		[
			'src/external.h',
			'src/mergJSON.c',
		],

		'jansson_sources':
		[
			'jansson/src/dump.c',
			'jansson/src/error.c',
			'jansson/src/hashtable.c',
			'jansson/src/hashtable.h',
			'jansson/src/hashtable_seed.c',
			'jansson/src/jansson.h',
			'jansson/src/jansson_private.h',
			'jansson/src/load.c',
			'jansson/src/lookup3.h',
			'jansson/src/memory.c',
			'jansson/src/pack_unpack.c',
			'jansson/src/strbuffer.c',
			'jansson/src/strbuffer.h',
			'jansson/src/strconv.c',
			'jansson/src/utf.c',
			'jansson/src/utf.h',
			'jansson/src/value.c',
		],
	},

	'targets':
	[
		{
			'target_name': 'external-mergjson',
			'type': 'loadable_module',
			'mac_bundle': 1,
			'product_prefix': '',
			'product_name': 'mergJSON',

			'variables':
			{
				'silence_warnings': 1,
			},

			'dependencies':
			[
				'../libexternal/libexternal.gyp:libExternal',
				'../libexternal/libexternal.gyp:libExternal-symbol-exports',
			],

			'include_dirs':
			[
				'src',
				'jansson/src',
			],

			# Jansson's configuration: the headers that its CMake build
			# would write, as the mergJSON repository keeps them for each
			# platform
			'defines':
			[
				'HAVE_CONFIG_H=1',
			],

			'sources':
			[
				'<@(mergjson_sources)',
				'<@(jansson_sources)',
			],

			'conditions':
			[
				[
					'OS == "win"',
					{
						'include_dirs':
						[
							'win-include',
						],

						'defines':
						[
							'_CRT_SECURE_NO_WARNINGS',
						],
					},
					{
						'include_dirs':
						[
							'include',
						],
					},
				],
			],

			'xcode_settings':
			{
				'INFOPLIST_FILE': 'rsrc/mergJSON-Info.plist',
				'EXPORTED_SYMBOLS_FILE': 'mergJSON.exports',
			},

			'all_dependent_settings':
			{
				'variables':
				{
					'dist_files': [ '<(PRODUCT_DIR)/<(_product_name)>(ext_bundle_suffix)' ],
				},
			},
		},
	],
}
