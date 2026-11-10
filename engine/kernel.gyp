{
	'includes':
	[
		'../common.gypi',
		'engine-sources.gypi',
	],

	'targets':
	[
		{
			'target_name': 'kernel',
			'type': 'static_library',
			
			'dependencies':
			[
				'../libfoundation/libfoundation.gyp:libFoundation',
				'../libgraphics/libgraphics.gyp:libGraphics',
				'../libscript/libscript.gyp:libScript',
				'../libscript/libscript.gyp:stdscript',
				
				'../libbrowser/libbrowser.gyp:libbrowser',

				'../thirdparty/libopenssl/libopenssl.gyp:libopenssl_stubs',
				
				'../prebuilt/libopenssl.gyp:libopenssl_headers',

				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_pcre',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_jpeg',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_gif',
				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_png',

				'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_z',

				'engine-common.gyp:encode_version',
				'engine-common.gyp:quicktime_stubs',
			],
			
			'include_dirs':
			[
				'include',
				'src',
			],
			
			'sources':
			[
				'<@(engine_common_source_files)',
				'<@(engine_desktop_source_files)',
				'<@(engine_module_source_files)',
				'<@(engine_java_source_files)',
			],
			
			'conditions':
			[
				[
					'OS == "linux"',
					{
						'include_dirs':
						[
							'../thirdparty/headers/linux/include/cairo',
						],
						
						'defines':
                        [
                            # We use some features that are behind config macros in old versions of Pango
                            'PANGO_ENABLE_BACKEND',
                            'PANGO_ENABLE_ENGINE',
						],
					},
				],
				[
					'OS == "android"',
					{
						'sources!':
						[
							# Not yet supported on Android
							'src/mblactivityindicator.cpp',
							'src/mblcamera.cpp',
						],
										
						'dependencies':
						[
							'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_skia',
							'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_freetype',
							'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_harfbuzz',
						],

						'link_settings':
						{
							'ldflags':
							[
								# Force the entry point to be included in the output
								'-Wl,--undefined,Java_com_runrev_android_Engine_doCreate',
								
								# mblandroidlcb.cpp contains nothing other than the LCB Invocation Handler 
								# native callback function, so force the symbol to be included as otherwise it
								# will be discarded by the linker because nothing in the file is used statically
								'-Wl,--undefined,Java_com_runrev_android_LCBInvocationHandler_doNativeListenerCallback',
							],
						},
					},
				],
				[
					'OS == "emscripten"',
					{
						'sources':
						[
							'<@(engine_minizip_source_files)',
						],

						'dependencies':
						[
							'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_skia',
							'../prebuilt/thirdparty.gyp:thirdparty_prebuilt_freetype',
						],
					},
				],
				[
					# OXT-Beyond: a browser loads no libraries, so the web
					# engine links OpenSSL into itself, as the server engine
					# does (kernel-server.gyp), rather than the stubs that
					# load it (src/mcssl.cpp). The stubs would define its
					# functions a second time.
					'OS == "emscripten"',
					{
						'dependencies!':
						[
							'../thirdparty/libopenssl/libopenssl.gyp:libopenssl_stubs',
						],

						'dependencies':
						[
							'../prebuilt/libopenssl.gyp:libopenssl',
						],

						'defines':
						[
							# The OpenSSL API that libopenssl_stubs asks
							# for, as on the desktop
							'OPENSSL_API_COMPAT=0x10100000L',
						],
					},
				],
				[
					'OS == "mac"',
					{
						'defines':
						[
							# We want to use the new prototypes for the Objective-C
							# dispatch methods as it helps catch certain errors at
							# compile time rather than run time.
							'OBJC_OLD_DISPATCH_PROTOTYPES=0',
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
								'$(SDKROOT)/System/Library/Frameworks/AudioToolbox.framework',
								'$(SDKROOT)/System/Library/Frameworks/CoreFoundation.framework',
								'$(SDKROOT)/System/Library/Frameworks/CoreMedia.framework',
								'$(SDKROOT)/System/Library/Frameworks/IOKit.framework',
								'$(SDKROOT)/System/Library/Frameworks/Security.framework',
								'$(SDKROOT)/System/Library/Frameworks/SystemConfiguration.framework',
							],
						},
					],
					[
						'OS == "mac"',
						{
							'libraries':
							[
								'$(SDKROOT)/usr/lib/libcups.dylib',
								'$(SDKROOT)/System/Library/Frameworks/Accelerate.framework',
								'$(SDKROOT)/System/Library/Frameworks/ApplicationServices.framework',
								'$(SDKROOT)/System/Library/Frameworks/Carbon.framework',
								'$(SDKROOT)/System/Library/Frameworks/Cocoa.framework',
								'$(SDKROOT)/System/Library/Frameworks/MediaToolbox.framework',
								'$(SDKROOT)/System/Library/Frameworks/Quartz.framework',
								# CATransaction (mac-core.mm, the backdrop) lives in QuartzCore,
								# which the Quartz umbrella does not include.
								'$(SDKROOT)/System/Library/Frameworks/QuartzCore.framework',
							],
						},
					],
					[
						'OS == "mac" and target_sdk != "macosx10.6"',
                        {
							# Adding AVFoundation in the list of libraries does not allow
							# us to weak link it. Only adding the linking flag does the job
							'xcode_settings':
							{
								'OTHER_LDFLAGS':
								[
                                    '-weak_framework AVFoundation',
								]
							},
                        },
                    ],
                    [
                        'OS == "mac" and target_sdk == "macosx10.6"',
                        {
                            'libraries!':
                            [
								'$(SDKROOT)/System/Library/Frameworks/Accelerate.framework',
                                '$(SDKROOT)/System/Library/Frameworks/AVFoundation.framework',
                                '$(SDKROOT)/System/Library/Frameworks/CoreMedia.framework',
								'$(SDKROOT)/System/Library/Frameworks/MediaToolbox.framework',
                            ],
                        },
                    ],
					[
						'OS == "linux"',
						{
							'dependencies':
							[
								#'engine.gyp:create_linux_stubs',
							],
							
							'sources':
							[
								'<(SHARED_INTERMEDIATE_DIR)/src/linux.stubs.cpp',
							],
							
							'libraries':
							[
								'-ldl',
								'-lpthread',
							],
						},
					],
					[
						'OS == "android"',
						{
							'libraries':
							[
								'-lGLESv3',
								'-lEGL',
								'-ljnigraphics',
								'-llog',
								'-lm',
							],
						},
					],
					[
						'OS == "win"',
						{
							'libraries':
							[
								'-ladvapi32',
								'-lcomdlg32',
								'-lcrypt32',
								'-lgdi32',
								'-liphlpapi',
								'-limm32',
								'-lmscms',
								'-lmsimg32',
								'-lpsapi',
								'-lole32',
								'-loleaut32',
								'-lrpcrt4',
								'-lshell32',
								'-lshlwapi',
								'-lstrmiids',
								'-luser32',
								'-lusp10',
								'-lversion',
								'-lwinmm',
								'-lwinspool',
								'-lws2_32',
							],
						},
					],
				],
			},
		},
		
		{
			'target_name': 'kernel-java',
			'type': 'none',
			
			'conditions':
			[
				[
					'OS == "android"',
					{
						'variables':
						{
							'java_classes_dir_name': 'classes_livecode_community',
						},
						
						# Include the rules for compiling Java
						'includes':
						[
							'../config/java.gypi',
						],
						
						'sources':
						[
							# OXT-Beyond: each AIDL interface is compiled
							# from the Java kept beside its .aidl file, which
							# is what LiveCode's build had the SDK's aidl make
							# of it (tools/ci/android_java.py builds the Java
							# layer the same way, and its compare checks that
							# against the classes LiveCode 9.6.3 shipped). The
							# aidl of current build tools refuses the rule in
							# config/java.gypi (it wants a file's folder among
							# its import paths, spelled alike), and it would
							# write other Java than the classes apps have run.
							'<!@((for x in <@(engine_aidl_source_files); do echo "${x}"; done) | sed -e "s/\\.aidl$/\\.java/g")',
		
							# Some of the Java sources use the AIDL
							# interfaces, so they come last
							'<@(engine_java_source_files)',
						],
					}
				]
			],
		},
	],
}
