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
			'target_name': 'perfect',
			'type': 'executable',

			'toolsets': ['target','host'],

			'product_name': 'perfect-<(_toolset)',

			'sources':
			[
				'perfect.c',
			],

            'variables':
            {
                'silence_warnings': 1,
            },

			'msvs_settings':
			{
				'VCLinkerTool':
				{
					'SubSystem': '1',	# /SUBSYSTEM:CONSOLE
				},
			},

			'xcode_settings':
			{
				'conditions':
				[
					[
						'OS == "mac"',
						{
							'SDKROOT': '<(host_sdk)',
						},
					],
                    [
                        'OS == "mac" and target_sdk != "macosx10.6"',
                        {
                            'ARCHS': '<(host_arch)',
                        },
                    ],
				],
			},

			'direct_dependent_settings':
			{
				'variables':
				{
					'perfect_path': '<(PRODUCT_DIR)/<(_product_name)',
				},
			},
			
			'conditions':
			[
			],
		},
	],
}
