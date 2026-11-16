# -*-Javascript-*-

# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	'variables':
	{
		'app_bundle_suffix': '',
		'ext_bundle_suffix': '.so',
		'lib_suffix': '.so',
		'ext_suffix': '.so',
		'exe_suffix': '.js',
		'debug_info_suffix': '.dbg',

		'c++_std': '<!(echo ${CXX_STD:-c++11})',
	},

	'defines':
	[
		'__GNU__',
	],

	# The engine is compiled to WebAssembly with a current Emscripten (see
	# docs/development/build-emscripten.md). The link settings (Asyncify,
	# memory, exports) are not compiler flags: util/emscripten-javascriptify.py
	# passes them when it links the engine's relocatable object into
	# standalone-community-<version>.js and .wasm.
	'cflags':
	[
	],

	'cflags_c':
	[
		'-std=gnu99',
		'-Wstrict-prototypes',
		'-Werror=declaration-after-statement',	# Ensure C89 compliance
	],

	'cflags_cc':
	[
		'-fno-exceptions',
		'-fno-rtti',
		'-std=<(c++_std)',
	],

	'target_conditions':
	[
		[
			'silence_warnings == 0',
			{
				'cflags':
				[
					'-Wall',
					'-Wextra',
					'-Wno-unused-parameter',
					'-Wno-ignored-attributes',

					'-Werror=conversion-null',
					'-Werror=logical-not-parentheses',
					'-Werror=return-type',
					'-Werror=tautological-compare',
					'-Werror=uninitialized',
				],
				'cflags_cc':
				[
					'-Werror=mismatched-tags',
					'-Werror=overloaded-virtual',
					'-Werror=delete-non-virtual-dtor',
				],
			},
			{
				'cflags':
				[
					'-w',
					'-fpermissive',
					'-Wno-return-type',
				],
			},
		],
	],

	'configurations':
	{
		'Debug':
		{
			'cflags':
			[
				'-O2',
				'-g3',
			],

			'defines':
			[
				'_DEBUG',
			],

		},

		'Release':
		{
			'cflags':
			[
				'-Os',
				'-g3',
			],

			'defines':
			[
				'_RELEASE',
				'NDEBUG',
			],
		},

		'Fast':
		{
			'cflags':
			[
				'-O0',
				'-g0',
			],

			'defines':
			[
				'_RELEASE',
				'NDEBUG',
			],
		},
	},
}
