{
	'variables':
	{
		'c++_std': '<!(echo ${CXX_STD:-c++11})',
		'android_lib_path%': '<!(echo ${ANDROID_LIB_PATH:+-L${ANDROID_LIB_PATH}})',
		# OXT-Beyond: the linker, config/android.gypi's (which config.py
		# names), again here for this file's target_conditions, which see
		# a target's own variables and not a gyp file's
		'android_fuse_ld%': '<(android_fuse_ld)',
	},

	'cflags':
	[
		'-fstrict-aliasing',
		'-fvisibility=hidden',
		# OXT-Beyond: position-independent code, as everything here ends up
		# in a shared library (the engine, the externals) and as a Linux
		# build asks for it (linux-settings.gypi). A current NDK's Clang
		# makes PIE code by default, which lld refuses to link into one
		# where it refers to a symbol another library could stand in for
		# (CI's x86 build stopped on DbSqlite and libc++'s typeinfo).
		'-fPIC',
	],
	
	'cflags_c':
	[
		'-std=gnu99',
		'-Wstrict-prototypes',
	],
	
	'cflags_cc':
	[
		'-std=<(c++_std)',
		'-fno-exceptions',
		'-fno-rtti',
	],
	
	'ldflags':
	[
		'-fuse-ld=<(android_fuse_ld)',
	],
	
	'target_conditions':
	[
		[
			# OXT-Beyond: a current NDK's Clang (lld's route, config.py)
			# takes `this` as never null (Clang 13 and later mark it
			# nonnull) and deletes code's checks of it. The bundled
			# HarfBuzz (0.9) checks it in hb_object_header_t, which every
			# hb_*_destroy and hb_*_reference of a null object goes
			# through, and the engine built here died on its first text:
			# SIGSEGV at 0 in hb_unicode_funcs_destroy, from
			# hb_buffer_create (android-engine.yml's emulator run). This
			# keeps such checks, as NDK r16's Clang 5, which built the
			# 9.6.3 engine, did. A standalone toolchain builds as before.
			'android_fuse_ld == "lld"',
			{
				'cflags':
				[
					'-fno-delete-null-pointer-checks',
				],
			},
		],
		[
			'_type == "loadable_module"',
			{
				# OXT-Beyond: -lstdc++ only with a standalone toolchain, as
				# before. lld is a current NDK's linker (config.py), whose
				# clang++ links the C++ library into each library itself
				# (-static-libstdc++ in LINK); there -lstdc++ also named the
				# NDK's shared libc++, libc++_shared.so, which Android does
				# not have (CI's first whole arm64 build asked for it).
				'target_conditions':
				[
					[
						'android_fuse_ld == "lld"',
						{
							'ldflags':
							[
								'<(android_lib_path)',
								'-landroid',
							],
						},
						{
							'ldflags':
							[
								'<(android_lib_path)',
								'-lstdc++',
								'-landroid',
							],
						},
					],
				],
			},
		],
		[
			'silence_warnings == 0',
			{
				'cflags':
				[
					'-Wall',
					'-Wextra',
					'-Wno-unused-parameter',	# Just contributes build noise
					'-Werror=conversion-null',
				],
				
				'cflags_c':
				[
					'-Werror=declaration-after-statement',	# Ensure compliance with C89
				],

				'cflags_cc':
				[
					'-Werror=delete-non-virtual-dtor',
					'-Werror=overloaded-virtual',
				]
			},
			{
				'cflags':
				[
					'-w',						# Disable warnings
					'-fpermissive',				# Be more lax with old code
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
				'-O0',
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
				'-O3',
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
	
	'defines':
	[
		'TARGET_PLATFORM_MOBILE',
		'TARGET_SUBPLATFORM_ANDROID',
		'ANDROID',
		'_MOBILE',
		'ANDROID_NDK',
	],
}
