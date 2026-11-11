# libpq from PostgreSQL 17 (thirdparty/libpq/ORIGIN), the client library of
# the PostgreSQL database driver (revdb's dbpostgresql).
#
# PostgreSQL is built with Meson; this file builds the parts of its tree
# that libpq links (src/interfaces/libpq, and what it uses of src/common
# and src/port), with the configuration that Meson would make
# (src/include/pg_config.h and the headers beside it). TLS is OpenSSL's,
# through the engine's OpenSSL stubs, as before; the hashes and random
# numbers are PostgreSQL's own and the system's (src/include/pg_config.h
# says why).
{
	'includes':
	[
		'../../common.gypi',
	],

	'targets':
	[
		{
			'target_name': 'libpq',

			'conditions':
			[
				[
					'use_system_libpq == 0',
					{
						'type': 'static_library',

						'variables':
						{
							'library_for_module': 1,
							'silence_warnings': 1,

							# What PostgreSQL 17's Meson build sets
							'openssl_api_compat': '0x10002000L',
						},

						'dependencies':
						[
							'../libopenssl/libopenssl.gyp:libopenssl_stubs',
						],

						'include_dirs':
						[
							'src/interfaces/libpq',
							'src/port',
							'src/include',
							'include',
						],

						'defines':
						[
							'FRONTEND',
							'SO_MAJOR_VERSION=5',
						],

						'sources':
						[
							'include/libpq-fe.h',
							'include/pg_config_ext.h',
							'include/postgres_ext.h',

							'src/include/c.h',
							'src/include/common/base64.h',
							'src/include/common/cryptohash.h',
							'src/include/common/fe_memutils.h',
							'src/include/common/hmac.h',
							'src/include/common/int.h',
							'src/include/common/ip.h',
							'src/include/common/link-canary.h',
							'src/include/common/md5.h',
							'src/include/common/openssl.h',
							'src/include/common/pg_prng.h',
							'src/include/common/saslprep.h',
							'src/include/common/scram-common.h',
							'src/include/common/sha1.h',
							'src/include/common/sha2.h',
							'src/include/common/string.h',
							'src/include/common/unicode_east_asian_fw_table.h',
							'src/include/common/unicode_nonspacing_table.h',
							'src/include/common/unicode_norm.h',
							'src/include/common/unicode_norm_table.h',
							'src/include/lib/stringinfo.h',
							'src/include/libpq/libpq-fs.h',
							'src/include/libpq/pqcomm.h',
							'src/include/libpq/protocol.h',
							'src/include/mb/pg_wchar.h',
							'src/include/pg_config.h',
							'src/include/pg_config_manual.h',
							'src/include/pg_config_os.h',
							'src/include/pg_config_paths.h',
							'src/include/port.h',
							'src/include/port/darwin.h',
							'src/include/port/linux.h',
							'src/include/port/pg_bitutils.h',
							'src/include/port/pg_bswap.h',
							'src/include/port/pg_pthread.h',
							'src/include/port/simd.h',
							'src/include/port/win32.h',
							'src/include/port/win32/arpa/inet.h',
							'src/include/port/win32/dlfcn.h',
							'src/include/port/win32/grp.h',
							'src/include/port/win32/netdb.h',
							'src/include/port/win32/netinet/in.h',
							'src/include/port/win32/netinet/tcp.h',
							'src/include/port/win32/pwd.h',
							'src/include/port/win32/sys/resource.h',
							'src/include/port/win32/sys/select.h',
							'src/include/port/win32/sys/socket.h',
							'src/include/port/win32/sys/un.h',
							'src/include/port/win32/sys/wait.h',
							'src/include/port/win32_msvc/dirent.h',
							'src/include/port/win32_msvc/sys/file.h',
							'src/include/port/win32_msvc/sys/param.h',
							'src/include/port/win32_msvc/sys/time.h',
							'src/include/port/win32_msvc/unistd.h',
							'src/include/port/win32_msvc/utime.h',
							'src/include/port/win32_port.h',
							'src/include/port/win32ntdll.h',
							'src/include/postgres_fe.h',
							'src/include/utils/ascii.h',

							'src/interfaces/libpq/fe-auth-scram.c',
							'src/interfaces/libpq/fe-auth.c',
							'src/interfaces/libpq/fe-cancel.c',
							'src/interfaces/libpq/fe-connect.c',
							'src/interfaces/libpq/fe-exec.c',
							'src/interfaces/libpq/fe-lobj.c',
							'src/interfaces/libpq/fe-misc.c',
							'src/interfaces/libpq/fe-print.c',
							'src/interfaces/libpq/fe-protocol3.c',
							'src/interfaces/libpq/fe-secure-common.c',
							'src/interfaces/libpq/fe-secure-openssl.c',
							'src/interfaces/libpq/fe-secure.c',
							'src/interfaces/libpq/fe-trace.c',
							'src/interfaces/libpq/legacy-pqsignal.c',
							'src/interfaces/libpq/libpq-events.c',
							'src/interfaces/libpq/pqexpbuffer.c',
							'src/interfaces/libpq/fe-auth-sasl.h',
							'src/interfaces/libpq/fe-auth.h',
							'src/interfaces/libpq/fe-secure-common.h',
							'src/interfaces/libpq/libpq-events.h',
							'src/interfaces/libpq/libpq-int.h',
							'src/interfaces/libpq/pqexpbuffer.h',

							'src/common/base64.c',
							'src/common/cryptohash.c',
							'src/common/encnames.c',
							'src/common/hmac.c',
							'src/common/ip.c',
							'src/common/link-canary.c',
							'src/common/md5.c',
							'src/common/md5_common.c',
							'src/common/md5_int.h',
							'src/common/pg_prng.c',
							'src/common/saslprep.c',
							'src/common/scram-common.c',
							'src/common/sha1.c',
							'src/common/sha1_int.h',
							'src/common/sha2.c',
							'src/common/sha2_int.h',
							'src/common/string.c',
							'src/common/unicode_norm.c',
							'src/common/wchar.c',

							'src/port/chklocale.c',
							'src/port/inet_net_ntop.c',
							'src/port/noblock.c',
							'src/port/oxt_strong_random.c',
							'src/port/oxt_timingsafe_bcmp.c',
							'src/port/pg_bitutils.c',
							'src/port/pg_strong_random.c',
							'src/port/pgsleep.c',
							'src/port/pgstrcasecmp.c',
							'src/port/snprintf.c',
							'src/port/strerror.c',
							'src/port/timingsafe_bcmp.c',
							'src/port/user.c',
						],

						'sources!':
						[
							# Built through src/port/oxt_strong_random.c and
							# src/port/oxt_timingsafe_bcmp.c
							'src/port/pg_strong_random.c',
							'src/port/timingsafe_bcmp.c',
						],

						'direct_dependent_settings':
						{
							'include_dirs':
							[
								'include',
							],
						},

						'conditions':
						[
							[
								'OS != "win"',
								{
									'defines':
									[
										'_GNU_SOURCE',
										'_FILE_OFFSET_BITS=64',
									],

									# PostgreSQL's code relies on both
									'cflags':
									[
										'-fwrapv',
										'-fno-strict-aliasing',
									],

									'xcode_settings':
									{
										'OTHER_CFLAGS':
										[
											'-fwrapv',
											'-fno-strict-aliasing',
										],
									},
								},
							],
							[
								'OS == "linux"',
								{
									'sources':
									[
										'src/port/getpeereid.c',
										'src/port/strlcat.c',
										'src/port/strlcpy.c',
									],
								},
							],
							[
								'OS == "mac"',
								{
									'sources':
									[
										'src/port/explicit_bzero.c',
									],
								},
							],
							[
								'OS == "win"',
								{
									'include_dirs':
									[
										'src/include/port/win32',
										'src/include/port/win32_msvc',
									],

									'defines':
									[
										'WIN32',
										'WINDOWS',
										'__WINDOWS__',
										'__WIN32__',
										'_CRT_SECURE_NO_DEPRECATE',
										'_CRT_NONSTDC_NO_DEPRECATE',
									],

									'sources':
									[
										'src/interfaces/libpq/pthread-win32.c',
										'src/interfaces/libpq/win32.c',
										'src/interfaces/libpq/win32.h',
										'src/port/dirmod.c',
										'src/port/explicit_bzero.c',
										'src/port/getpeereid.c',
										'src/port/inet_aton.c',
										'src/port/open.c',
										'src/port/pthread-win32.h',
										'src/port/strlcat.c',
										'src/port/strlcpy.c',
										'src/port/win32common.c',
										'src/port/win32error.c',
										'src/port/win32gai_strerror.c',
										'src/port/win32gettimeofday.c',
										'src/port/win32ntdll.c',
										'src/port/win32setlocale.c',
										'src/port/win32stat.c',
									],

									'link_settings':
									{
										'libraries':
										[
											'-ladvapi32',
											'-lsecur32',
											'-lshell32',
											'-lwldap32',
											'-lws2_32',
										],
									},
								},
							],
						],
					},
					{
						'type': 'none',

						'link_settings':
						{
							'libraries':
							[
								'-lpq',
							],
						},
					},
				],
			],
		},
	],
}
