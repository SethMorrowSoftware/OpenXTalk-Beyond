# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	'variables':
	{
		'mobile': 0,
	},
	
	'conditions':
	[
		[
			'OS == "mac"',
			{
				'includes':
				[
					'mac.gypi',
				],
			},
		],
		[
			'OS == "linux"',
			{
				'includes':
				[
					'linux.gypi',
				],
			},
		],
		[
			'OS == "android"',
			{
				'includes':
				[
					'android.gypi',
				],
			},
		],
		[
			'OS == "win"',
			{
				'includes':
				[
					'win32.gypi',
				],
			},
		],
		[
			'OS == "emscripten"',
			{
				'includes':
				[
					'emscripten.gypi',
				],
			},
		],
	],
}
