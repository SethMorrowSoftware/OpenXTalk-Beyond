{
	'includes':
	[
		'../../common.gypi',
	],
	
	'targets':
	[
		{
			'target_name': 'libexpat',
			'type': 'static_library',

			'toolsets': ['host', 'target'],
			
			'variables':
			{
				'silence_warnings': 1,
			},
			
			'include_dirs':
			[
				'.',
				'lib',
			],
			
			'defines':
			[
				'HAVE_EXPAT_CONFIG_H',
			],
			
			'sources':
			[
				'expat_config.h',
				'lib/ascii.h',
				'lib/asciitab.h',
				'lib/entities.h',
				'lib/expat_external.h',
				'lib/expat.h',
				'lib/fallthrough.h',
				'lib/hash_table.h',
				'lib/iasciitab.h',
				'lib/internal.h',
				'lib/latin1tab.h',
				'lib/memory_sanitizer.h',
				'lib/nametab.h',
				'lib/random_arc4random_buf.h',
				'lib/random_dev_urandom.h',
				'lib/siphash.h',
				'lib/utf8tab.h',
				'lib/xcs.h',
				'lib/xmlrole.h',
				'lib/xmltok_impl.h',
				'lib/xmltok.h',
				
				# xmltok_impl.c and xmltok_ns.c are included by xmltok.c,
				# not compiled on their own (Expat 2.10.0's CMakeLists.txt)
				'lib/xcs.c',
				'lib/xmlparse.c',
				'lib/xmlrole.c',
				'lib/xmltok.c',
				# the entropy sources expat_config.h selects
				'lib/random_arc4random_buf.c',
				'lib/random_dev_urandom.c',
			],
			
			'direct_dependent_settings':
			{
				'include_dirs':
				[
					'.',
					'lib',
				],
			},
			
			'target_conditions':
			[
				[
					'toolset_os != "android"',
					{
						'type': 'none',
					},
				],
			],
		},
	],
}
