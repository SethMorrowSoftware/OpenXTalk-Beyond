# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	'includes':
	[
		'../../common.gypi',
	],
	
	
	'targets':
	[
		{
			'target_name': 'lc-compile',
			'type': 'none',
			
			'toolsets': ['host','target'],

			'dependencies':
			[
				'../../prebuilt/thirdparty.gyp:thirdparty_prebuilt_ffi',
			],
			
			'conditions':
			[
				[
					'cross_compile == 0',
					{
						'dependencies':
						[
							'src/lc-compile-bootstrap.gyp:lc-compile-stage3#target',
						],
						
						'direct_dependent_settings':
						{
							'variables':
							{
								'lc-compile_target': '<(PRODUCT_DIR)/lc-compile<(EXECUTABLE_SUFFIX)',
								'lc-compile_host':   '<(PRODUCT_DIR)/lc-compile<(EXECUTABLE_SUFFIX)',
							},
						},
					},
					{
						'dependencies':
						[
							'src/lc-compile-bootstrap.gyp:lc-compile-stage3#host',
						],
						
						'conditions':
						[
							[
								'mobile == 0',
								{
									'dependencies':
									[
										'src/lc-compile-bootstrap.gyp:lc-compile-stage4#target',
									],

									'direct_dependent_settings':
									{
										'variables':
										{
											'dist_files':
											[
												'>(lc-compile_target)',
											],
										},
									},
								},
							],
						],
						
						'direct_dependent_settings':
						{
							'variables':
							{
								'lc-compile_target': '<(PRODUCT_DIR)/lc-compile<(EXECUTABLE_SUFFIX)',
								'lc-compile_host':   '<(PRODUCT_DIR)/lc-compile-stage3-host<(EXECUTABLE_SUFFIX)',
							},
						},
					},
				],
			],
		},
	],
}
