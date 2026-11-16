# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{
	'variables':
	{
		'mobile': 1,
		'output_dir': '../emscripten-bin',
	},

	'target_defaults':
	{
		'variables':
		{
			'app_bundle_suffix': '',
			'ext_bundle_suffix': '',
			'lib_suffix': '',
			'ext_suffix': '',
			'exe_suffix': '',
			'debug_info_suffix': '.dbg',

			'silence_warnings': 0,
		},

		'target_conditions':
		[
			[
				'_toolset == "host"',
				{
					'includes':
					[
						'linux-settings.gypi',
					],
				},
				{
					'includes':
					[
						'emscripten-settings.gypi',
					],
				},
			],
			[
				# An executable for the web is linked in two steps: gyp links
				# its objects and libraries into one relocatable WebAssembly
				# object (-r), and engine.gyp's javascriptify target links
				# that into the .js and .wasm files with the JavaScript
				# libraries and the link settings.
				'_toolset == "target" and _type == "executable"',
				{
					'product_extension': 'o',
					'ldflags': [ '-r', ],
				},
			],
		],
	},
}
