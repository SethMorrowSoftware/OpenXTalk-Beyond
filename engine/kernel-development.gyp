{
	'variables':
	{
		'module_name': 'kernel-development',
		'module_test_dependencies':
		[
			'kernel-development',
			'engine-common.gyp:security-community',
			'../libfoundation/libfoundation.gyp:libFoundation',
			'../libgraphics/libgraphics.gyp:libGraphics',
		],
		'module_test_sources':
		[
			'<@(engine_test_source_files)',
			'src/dummystartupstack.cpp',
		],
		'module_test_include_dirs':
		[
			'include',
			'src',
		],
		'module_test_defines': [ 'MODE_DEVELOPMENT', ],
	},

	'includes':
	[
		'../common.gypi',
		'engine-sources.gypi',
		'../config/cpptest.gypi'
	],

	'targets':
	[
		{
			'target_name': 'kernel-development',
			'type': 'static_library',
			
			'includes':
			[
				'kernel-mode-template.gypi',
			],
			
			'variables':
			{
				'mode_macro': 'MODE_DEVELOPMENT',
			},
			
			'dependencies':
			[
				'kernel.gyp:kernel',

				'../thirdparty/libopenssl/libopenssl.gyp:libopenssl_stubs',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_z',
			],
			
			'sources':
			[
				'<@(engine_development_mode_source_files)',
			],
			
			'conditions':
			[
				# Tom Perry's macOS developer commands _internal build MacARM and
				# _internal dump stack (internal_development.cpp), which his macOS
				# Xcode project compiled into the development engine
				[
					'OS == "mac"',
					{
						'sources':
						[
							'src/build_macarm.h',
							'src/build_macarm.cpp',
							'src/dump_stack.h',
							'src/dump_stack.cpp',
						],
					},
				],
				[
					'mobile != 0',
					{
						'type': 'none',
					},
				],
			],
		},
	],
}
