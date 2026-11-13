{
	'includes':
	[
		'../common.gypi',
	],
	
	'targets':
	[
		{
			'target_name': 'libbrowser',
			'type': 'static_library',

			'toolsets': ['host', 'target'],
			
			'dependencies':
			[
				# '../libcore/libcore.gyp:libCore',
			],
			
			'include_dirs':
			[
				'include',
				'../libcore/include',
			],
			
			'sources':
			[
				'include/libbrowser.h',
				
				'src/libbrowser.cpp',
				'src/libbrowser_internal.h',
				'src/libbrowser_memory.cpp',
				'src/libbrowser_value.cpp',

				'src/libbrowser_cef.cpp',
				'src/libbrowser_cef.h',
				'src/libbrowser_cef_lnx.cpp',
				'src/libbrowser_cef_win.cpp',
				'src/libbrowser_cef_loader_win.cpp',
				
				'src/libbrowser_win.rc.h',
				'src/libbrowser_win.rc',
				
				'src/signal_restore_posix.cpp',

				'src/libbrowser_osx_webview.h',
				'src/libbrowser_osx_webview.mm',
				

				'src/libbrowser_nsvalue.h',
				'src/libbrowser_nsvalue.mm',
				
				'src/libbrowser_android.cpp',

				'src/libbrowser_em.cpp',
				
				'src/libbrowser_lnx_factories.cpp',
				'src/libbrowser_win_factories.cpp',
				'src/libbrowser_osx_factories.cpp',
				'src/libbrowser_em_factories.cpp',
			],
			
			'target_conditions':
			[
				## Exclusions
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
				# Only use CEF on desktop platforms
				[
					'not (toolset_os == "win" or (toolset_os == "linux" and toolset_arch == "x86_64"))',
					{
						'sources!':
						[
							'src/libbrowser_cef.cpp',
						],
					},
				],
				
				[
					'toolset_os != "mac"',
					{
						'sources!':
						[

							'src/libbrowser_osx_webview.h',
							'src/libbrowser_osx_webview.mm',
							
							'src/libbrowser_osx_factories.cpp',
						],
					},
				],
				
				[
					'toolset_os != "mac"',
					{
						'sources!':
						[
							'src/libbrowser_nsvalue.h',
							'src/libbrowser_nsvalue.mm',
						],
					},
				],
				
				[
					'toolset_os != "win"',
					{
						'sources!':
						[
							'src/libbrowser_cef_win.cpp',
							'src/libbrowser_cef_loader_win.cpp',
							'src/libbrowser_win.rc.h',
							'src/libbrowser_win.rc',
							
							'src/libbrowser_win_factories.cpp',
						],
					},
				],

				# On Windows the CEF code is libbrowser-cef.dll's, built with
				# v143 for CEF 156's C++20; the engine has the loader
				# (src/libbrowser_cef_dll.h)
				[
					'toolset_os == "win"',
					{
						'sources!':
						[
							'src/libbrowser_cef.cpp',
							'src/libbrowser_cef_win.cpp',
							'src/libbrowser_win.rc.h',
							'src/libbrowser_win.rc',
						],
					},
				],
				
				[
					'toolset_os != "linux"',
					{
						'sources!':
						[
							'src/libbrowser_cef_lnx.cpp',
							'src/signal_restore_posix.cpp',
							
							'src/libbrowser_lnx_factories.cpp',
						],
					},
				],

				[
					'toolset_os == "linux" and not toolset_arch == "x86_64"',
					{
						'sources!':
						[
							'src/libbrowser_cef_lnx.cpp',
						],
					},
				],
				
				
				[
					'toolset_os != "android"',
					{
						'sources!':
						[
							'src/libbrowser_android.cpp',
						],
					},
				],

				[
					'toolset_os != "emscripten"',
					{
						'sources!':
						[
							'src/libbrowser_em.cpp',
							'src/libbrowser_em_factories.cpp',
						],
					},
				],
			],

			'link_settings':
			{
				'target_conditions':
				[
					[
						'toolset_os == "mac"',
						{
							'libraries':
							[
								'$(SDKROOT)/System/Library/Frameworks/WebKit.framework',
								'$(SDKROOT)/System/Library/Frameworks/JavaScriptCore.framework',
							],
						},
					],
				],
			},
			
			# Gyp doesn't like dependencies in 'target_conditions'...
			'conditions':
			[
				[
					# Only the CEF platforms need libbrowser-cefprocess
					'OS == "linux" or host_os == "linux"',
					{
						'dependencies':
						[
							'libbrowser-cefprocess',
							'../prebuilt/libcef.gyp:libcef',
							'../prebuilt/libicu.gyp:libicu',
							'../thirdparty/libcef/libcef.gyp:libcef_library_wrapper',
							'../thirdparty/libcef/libcef.gyp:libcef_stubs',
						],
					},
				],
				
				[
					'OS == "win"',
					{	
						'dependencies':
						[
							'libbrowser-cefprocess',
							'libbrowser-cef-copy',
							'../prebuilt/libcef.gyp:libcef',
							'../prebuilt/libicu.gyp:libicu',
						],

						'copies':
						[
							{
								'destination':'<(PRODUCT_DIR)/Externals/CEF/',
								'files':
								[
									'<(PRODUCT_DIR)/libbrowser-cefprocess.exe',
								],
							},
						],
					},
				],
			],
			
			'direct_dependent_settings':
			{
				'include_dirs':
				[
					'include',
				],
			},
			
			'cflags_cc!':
			[
				'-fno-rtti',
				'-fno-exceptions',
			],
			
			'msvs_settings':
			{
				'VCCLCompilerTool':
				{
					'ExceptionHandling': '1',  # /EHsc
				},
			},
			
			
			'xcode_settings':
			{
#				'INFOPLIST_FILE': 'rsrc/libbrowser-Info.plist',
				'GCC_ENABLE_CPP_EXCEPTIONS': 'YES',
			},
		},
    ],
    
    'conditions':
    [
        [
            'OS == "win"',
            {
                'targets':
                [
                    # The browser widget's CEF code on Windows, built with
                    # v143 for CEF 156's C++20 and loaded by the engine
                    # (src/libbrowser_cef_dll.h). It lives in Externals/CEF,
                    # beside libcef.dll.
                    {
                        'target_name': 'libbrowser-cef',
                        'type': 'shared_library',
                        'product_name': 'libbrowser-cef',
                        'msbuild_toolset': 'v143',

                        'dependencies':
                        [
                            '../libcore/libcore.gyp:libCore',
                            '../thirdparty/libcef/libcef.gyp:libcef_library_wrapper',
                            '../thirdparty/libcef/libcef.gyp:libcef_stubs',
                        ],

                        'defines':
                        [
                            'MCBROWSER_CEF_DLL',
                        ],

                        'include_dirs':
                        [
                            'include',
                            'src',
                            '../libcore/include',
                        ],

                        'sources':
                        [
                            'src/libbrowser.cpp',
                            'src/libbrowser_cef.cpp',
                            'src/libbrowser_cef_win.cpp',
                            'src/libbrowser_cef_dll.h',
                            'src/libbrowser_cef_dll_win.cpp',
                            'src/libbrowser_win.rc.h',
                            'src/libbrowser_win.rc',
                        ],

                        # libbrowser_cef_win.cpp's windows and the auth
                        # dialog; inside the engine its own link had them
                        'libraries':
                        [
                            '-luser32',
                        ],

                        'msvs_settings':
                        {
                            'VCCLCompilerTool':
                            {
                                'ExceptionHandling': '1',  # /EHsc
                                'AdditionalOptions': ['/std:c++20', '/Zc:__cplusplus'],
                            },
                        },

                    },

                    # Builds libbrowser-cef.dll and puts it beside libcef.dll
                    # in the build folder, where the engine looks for it,
                    # without the engine linking to it: it is loaded when a
                    # browser is first made (dependencies_traverse: 0 keeps
                    # gyp from adding its import library to the engine's link)
                    {
                        'target_name': 'libbrowser-cef-copy',
                        'type': 'none',
                        'dependencies_traverse': 0,

                        'dependencies':
                        [
                            'libbrowser-cef',
                        ],

                        'copies':
                        [
                            {
                                'destination':'<(PRODUCT_DIR)/Externals/CEF/',
                                'files':
                                [
                                    '<(PRODUCT_DIR)/libbrowser-cef.dll',
                                ],
                            },
                        ],

                        'all_dependent_settings':
                        {
                            'variables':
                            {
                                'dist_files': [ '<(PRODUCT_DIR)/libbrowser-cef.dll' ],
                            },
                        },
                    },
                ],
            },
        ],
        [
            'OS in ("linux", "win") or host_os in ("linux", "win")',
            {
                'targets':
                [
                    {
                        'target_name': 'libbrowser-cefprocess',
                        'type': 'executable',
                        'mac_bundle': 1,
                        'product_name': 'libbrowser-cefprocess',
                        # CEF 156's C++20 on Windows (src/libbrowser_cef_dll.h)
                        'msbuild_toolset': 'v143',

                        'msvs_settings':
                        {
                            'VCCLCompilerTool':
                            {
                                'ExceptionHandling': '1',  # /EHsc
                                'AdditionalOptions': ['/std:c++20', '/Zc:__cplusplus'],
                            },
                        },
                        
			'toolsets': ['host', 'target'],

                        'dependencies':
                        [
                            '../libcore/libcore.gyp:libCore',
                            '../libfoundation/libfoundation.gyp:libFoundation',
                            '../thirdparty/libcef/libcef.gyp:libcef_library_wrapper',
                            '../prebuilt/libcef.gyp:libcef',
                        ],

                        'include_dirs':
                        [
                            'include',
                        ],
                        
                        'sources':
                        [
                            'src/libbrowser_memory.cpp',
                            'src/libbrowser_cefprocess.cpp',
                            'src/libbrowser_cefprocess_lnx.cpp',
                            'src/libbrowser_cefprocess_win.cpp',
                        ],
                        
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
								'toolset_os not in ("win", "linux")',
								{
									'type': 'none',
								},
							],
							## Exclusions
                            [
                                'toolset_os != "win"',
                                {
                                    'sources!':
                                    [
                                        'src/libbrowser_cefprocess_win.cpp',
                                    ],
                                },
                            ],
                            
                            [
                                'toolset_os != "linux"',
                                {
                                    'sources!':
                                    [
                                        'src/libbrowser_cefprocess_lnx.cpp',
                                    ],
                                },
                            ],
                            
                            [
                                'toolset_os == "win"',
                                {	
                                    'library_dirs':
                                    [
                                        # The prebuilt archives are named for the engine's v141;
                                        # CEF's import library suits any toolset
                                        '../prebuilt/unpacked/cef/<(uniform_arch)-win32-v141_static_$(ConfigurationName)/lib/CEF/',
                                    ],

                                    'libraries':
                                    [
                                        '-llibcef.lib',
                                    ],
                                },
                            ],
                            
                            [
                                'toolset_os == "linux"',
                                {
                                    'library_dirs':
                                    [
                                        '../prebuilt/lib/linux/>(toolset_arch)/CEF/',
                                    ],
                    
                                    'libraries':
                                    [
                                        '-lcef',
                                    ],
                                   
                                    'ldflags':
                                    [
                                        '-Wl,--allow-shlib-undefined',
                                        '-Wl,-rpath=\\$$ORIGIN/Externals/CEF',
                                    ],
                                },
                            ],

                            [
                                'toolset_os == "linux" and not toolset_arch == "x86_64"',
                                {
                                    'type': 'none',
                                },
                            ],
                        ],

			'all_dependent_settings':
			{
				'conditions':
				[
					[
						'OS == "win" or (OS == "linux" and target_arch == "x86_64")',
						{
							'variables':
							{
								'dist_files': [ '<(PRODUCT_DIR)/<(_product_name)>(exe_suffix)' ],
							},
						},
					],
				],
			},
                    },
                ],
            },
        ],
    ],
}
