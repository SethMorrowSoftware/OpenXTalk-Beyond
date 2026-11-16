# Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
# (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
# Seth Morrow (2026); its Git history and CHANGELOG.md say what changed.

{

    'includes':
    [
        '../../../../common.gypi',
    ],
    
    'targets':
    [
        {
            'target_name': 'inih',
            'type': 'none',
            
            'dependencies':
            [
                'inih-build',
            ],

            'copies':
            [
                {
                    'destination': '<(PRODUCT_DIR)/packaged_extensions/com.livecode.library.ini/code/<(platform_id)/',
                    'files':
                    [
                        '<(PRODUCT_DIR)/inih<(SHARED_LIB_SUFFIX)',
                    ],
                },
            ],
        },
        {
            'target_name': 'inih-build',
            'product_prefix': '',
			'product_name': 'inih',
            'sources':
			[
				'ini.c',
                'ini.h',
			],
            
            'type': 'loadable_module',
        },
    ],

}
