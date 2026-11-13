{
	'includes':
	[
		'../../common.gypi',
		'libcef.gypi',
	],
	
	'targets':
	[
		{
			'target_name': 'libcef_library_wrapper',
			'type': 'static_library',

			# CEF 156's headers need C++20, which the engine's MSVC v141 has
			# not: on Windows the CEF code is built with v143, which links
			# the v141 libraries it needs (libbrowser_cef_dll.h)
			'msbuild_toolset': 'v143',

			'toolsets': ['host', 'target'],
			
			'variables':
			{
				'library_for_module': 1,
				'silence_warnings': 1,
			},
			
			# OSX, Windows and Linux only
			'target_conditions':
			[
				[
					# CEF 156's headers need C++20 (tools/cxx_by_std.sh: the
					# build's GCC 9 has none, GCC 10 compiles these). Last on the
					# command line, so it wins over the engine's -std=c++11.
					'toolset_os == "linux" and toolset_arch == "x86_64"',
					{
						'cflags_cc':
						[
							'-std=c++20',
						],
					},
				],
				[
					'not toolset_os in ("mac", "win", "linux")',
					{
						'type': 'none',
					},
				],
				[
					'toolset_os == "linux" and not toolset_arch in ("x86", "x86_64")',
					{
						'type': 'none',
					},
				],
				[
					'toolset_os == "win"',
					{
						# CEF's own build defines UNICODE: its *_win.cc call
						# the wide Windows functions by their plain names
						'defines':
						[
							'NOMINMAX',
							'UNICODE',
							'_UNICODE',
						],
					},
				],
				# Since CEF 156 the wrapper has sources for one platform
				# only, named for it
				[
					'toolset_os != "win"',
					{
						'sources/':
						[
							['exclude', '_win\\.cc$'],
						],
					},
				],
				[
					'toolset_os != "linux"',
					{
						'sources/':
						[
							['exclude', '_linux\\.cc$'],
						],
					},
				],
				[
					'toolset_os != "mac"',
					{
						'sources/':
						[
							['exclude', '_mac\\.(cc|mm)$'],
						],
					},
				],
			],
			
			'include_dirs':
			[
				'.',
			],
		
			'defines':
			[
				# A whole pile of configuration options...
				'ANGLE_DX11',
				'CHROMIUM_BUILD',
				'USE_LIBJPEG_TURBO=1',
				'ENABLE_ONE_CLICK_SIGNIN',
				'ENABLE_REMOTING=1',
				'ENABLE_WEBRTC=1',
				'ENABLE_PEPPER_CDMS',
				'ENABLE_CONFIGURATION_POLICY',
				'ENABLE_INPUT_SPEECH',
				'ENABLE_NOTIFICATIONS',
				'ENABLE_HIDPI=1',
				'ENABLE_GPU=1',
				'ENABLE_EGLIMAGE=1',
				'ENABLE_TASK_MANAGER=1',
				'ENABLE_EXTENSIONS=1',
				'ENABLE_PLUGIN_INSTALLATION=1',
				'ENABLE_PLUGINS=1',
				'ENABLE_SESSION_SERVICE=1',
				'ENABLE_THEMES=1',
				'ENABLE_AUTOFILL_DIALOG=1',
				'ENABLE_BACKGROUND=1',
				'ENABLE_AUTOMATION=1',
				'ENABLE_GOOGLE_NOW=1',
				'CLD_VERSION=1',
				'ENABLE_FULL_PRINTING=1',
				'ENABLE_PRINTING=1',
				'ENABLE_SPELLCHECK=1',
				'ENABLE_CAPTIVE_PORTAL_DETECTION=1',
				'ENABLE_APP_LIST=1',
				'ENABLE_SETTINGS_APP=1',
				'ENABLE_MANAGED_USERS=1',
				'WRAPPING_CEF_SHARED',
				'__STDC_CONSTANT_MACROS',
				'__STDC_FORMAT_MACROS',
				'DYNAMIC_ANNOTATIONS_ENABLED=1',
				'WTF_USE_DYNAMIC_ANNOTATIONS=1',
                'NDEBUG',
			],
			
			'sources':
			[
				'<@(libcef_dll_sources)',
			],

			'direct_dependent_settings':
			{
				'include_dirs':
				[
					'.',
				],
			},
			
			'msvs_settings':
			{
				'VCCLCompilerTool':
				{
					'ExceptionHandling': '1',
					'AdditionalOptions': ['/std:c++20', '/Zc:__cplusplus'],
				},
			},
		},
		
		{
			'target_name': 'libcef_stubs',
			'type': 'static_library',
			
			'toolsets': ['host', 'target'],

			'variables':
			{
				'library_for_module': 1,
				'silence_warnings': 1,
			},
			
			# OSX, Windows and Linux only
			'target_conditions':
			[
				[
					'not toolset_os in ("mac", "win", "linux")',
					{
						'type': 'none',
					},
				],
			],
			
			'sources':
			[
				'<(INTERMEDIATE_DIR)/src/libcefstubs.cpp',
			],
			
			'actions':
			[
				{
					'action_name': 'generate_libcef_stubs',
					'inputs':
					[
						'../../util/weak_stub_maker.pl',
						'libcef.stubs',
					],
					'outputs':
					[
						'<(INTERMEDIATE_DIR)/src/libcefstubs.cpp',
					],
					
					'action':
					[
						'<@(perl)',
						'../../util/weak_stub_maker.pl',
						'libcef.stubs',
						'<@(_outputs)',
					],
				},
			],
		},
	],
}
