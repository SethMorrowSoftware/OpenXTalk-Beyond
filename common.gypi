# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	# Common gyp inclusions for LiveCode
	'includes':
	[
		'config/arch.gypi',
		'config/configurations.gypi',
		'config/crosscompile.gypi',
		'config/exclusions.gypi',
		'config/perl.gypi',
		'config/target_os.gypi',
		'config/thirdparty.gypi',
		'config/version.gypi',
		'config/yacc.gypi',
	],
	
	# generate platform ID once all config is included
	'variables':
	{
		'conditions':
		[
			# TODO add windows msvc compiler and crt mode to platform id
			[
				'OS == "mac"',
				{
					'platform_id': 'universal-<(OS)-<(target_sdk)',
				},
				'(OS == "win")',
				{
				'platform_id': '<(uniform_arch)-win32',
				},
				{
					'platform_id': '<(uniform_arch)-<(OS)',
				},
			],
		],
	},	
}
