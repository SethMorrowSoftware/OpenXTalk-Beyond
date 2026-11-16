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
			'target_name': 'external-revandroid',
			'type': 'loadable_module',
			'mac_bundle': 1,
			'product_prefix': '',
			'product_name': 'revandroid',
			
			'dependencies':
			[
				'../libexternalv1/libexternalv1.gyp:libExternalV1',
			],
			
			'include_dirs':
			[
				'src',
			],
			
			'sources':
			[
				'src/revandroid.cpp',
			],
			
			'conditions':
			[
				[
					'OS == "linux"',
					{
						'libraries':
						[
							'-lpthread',
						],
					}
				],
				[
					'OS == "win"',
					{
						'libraries':
						[
							'-lWS2_32',
						],
					},
				],
			],
			
			'xcode_settings':
			{
				'INFOPLIST_FILE': 'revandroid-Info.plist',
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
