# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	# Patterns to exclude platform-specific files
	'target_defaults':
	{
		'conditions':
		[
			[
				'OS != "win"',
				{
					'sources/':
					[
						['exclude', '_w32\\.cpp$'],
						['exclude', '(^|/)w32.+\\.cpp$'],
					],
				},
				{
					'sources/':
					[
						['exclude', '_posix\\.cpp$'],
					],
				},
			],
			[
				'OS != "mac"',
				{
					'sources/':
					[
						['exclude', '_osx\\.(cpp|mm)$'],
						['exclude', '(^|/)osx.+\\.(cpp|mm)$'],
						['exclude', '(^|/)mac-.+\\.(cpp|mm)$'],
					],
				},
			],
			[
				'OS != "linux"',
				{
					'sources/':
					[
						['exclude', '_lnx\\.cpp$'],
						['exclude', '(^|/)lnx.+\\.cpp$'],
					],
				},
			],
			[
				'OS != "android"',
				{
					'sources/':
					[
						['exclude', '_android.cpp$'],
						['exclude', '(^|/)mblandroid.*\\.cpp$'],
						['exclude', '\\.(java|aidl)$'],
					],
				},
			],
			[
				'OS != "android"',
				{
					'sources/':
					[
						['exclude', '(^|/)mbl.+\\.cpp$'],
					],
				},
			],
			[
				'OS != "mac"',
				{
					'sources/':
					[
						['exclude', '\\.m(m?)$'],
					],
				},
			],
		],
	},
}
