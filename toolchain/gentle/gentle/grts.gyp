# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	'includes':
	[
		'../../../common.gypi',
	],
	
	'targets':
	[
		{
			'target_name': 'grts',
			'type': 'static_library',
			
			'toolsets': ['host','target'],
			
			'product_name': 'grts',
		
			'variables':
			{
				'silence_warnings': 1,
			},

			# OXT-Beyond: gentle and reflex are pre-ANSI C (implicit int,
			# functions used before they are declared). Current clang rejects
			# that from C99 on even with warnings silenced, so compile them as
			# gnu89, where it is valid.
			'xcode_settings':
			{
				'GCC_C_LANGUAGE_STANDARD': 'gnu89',
				'OTHER_CFLAGS':
				[
					'-Wno-error=int-conversion',
					'-Wno-error=incompatible-pointer-types',
					'-Wno-error=incompatible-function-pointer-types',
				],
			},
	
			'sources':
			[
				'grts.c',
			],
			
			'target_conditions':
			[
				[
					'_toolset != "target"',
					{
						'product_name': 'grts->(_toolset)',
					},
				],
			],
		},
	],
}
