# MariaDB Connector/C (thirdparty/libmysql/ORIGIN), the client library of
# the MySQL database driver (revdb's dbmysql). The target keeps the name
# libmysql, and the archive libmysql.a, that it had while it held MySQL
# Connector/C 6.0.
#
# Connector/C is built with CMake; this file builds the same sources with
# the configuration that CMake would make (include/ma_config.h,
# include/mariadb_version.h and libmariadb/ma_client_plugin.c are
# committed, written as ORIGIN says). TLS is OpenSSL's, through the
# engine's OpenSSL stubs, as before; the hashes are the library's own
# (libmariadb/secure/oxt_crypt.c).
{
	'includes':
	[
		'../../common.gypi',
	],

	'targets':
	[
		{
			'target_name': 'libmysql',

			'conditions':
			[
				[
					'use_system_libmysql == 0',
					{
						'type': 'static_library',

						'variables':
						{
							'library_for_module': 1,
							'silence_warnings': 1,
						},

						'dependencies':
						[
							'../libopenssl/libopenssl.gyp:libopenssl_stubs',
							'../libz/libz.gyp:libz',
						],

						'include_dirs':
						[
							'include',
							'libmariadb',
							'plugins/auth',
							'plugins/pvio',
						],

						'defines':
						[
							# As libmariadb/CMakeLists.txt and the top-level
							# CMakeLists.txt define them for an OpenSSL build
							'HAVE_COMPRESS',
							'HAVE_OPENSSL',
							'HAVE_TLS',
							'LIBMARIADB',
							'THREAD',
							'DBUG_OFF',

							# OXT-Beyond: secure/oxt_crypt.c's hashes
							# (include/ma_crypt.h)
							'OXT_BUILTIN_HASH',
						],

						'sources':
						[
							'include/errmsg.h',
							'include/ma_common.h',
							'include/ma_compress.h',
							'include/ma_config.h',
							'include/ma_context.h',
							'include/ma_crypt.h',
							'include/ma_decimal.h',
							'include/ma_global.h',
							'include/ma_hash.h',
							'include/ma_hashtbl.h',
							'include/ma_list.h',
							'include/ma_priv.h',
							'include/ma_pthread.h',
							'include/ma_pvio.h',
							'include/ma_server_error.h',
							'include/ma_string.h',
							'include/ma_sys.h',
							'include/ma_tls.h',
							'include/mariadb_async.h',
							'include/mariadb_com.h',
							'include/mariadb_ctype.h',
							'include/mariadb_dyncol.h',
							'include/mariadb_rpl.h',
							'include/mariadb_stmt.h',
							'include/mariadb_version.h',
							'include/mysql.h',
							'include/mysqld_error.h',
							'include/mysql/client_plugin.h',
							'include/mysql/plugin_auth.h',
							'include/mariadb/ma_io.h',

							'libmariadb/ma_alloc.c',
							'libmariadb/ma_array.c',
							'libmariadb/ma_charset.c',
							'libmariadb/ma_client_plugin.c',
							'libmariadb/ma_compress.c',
							'libmariadb/ma_context.c',
							'libmariadb/ma_decimal.c',
							'libmariadb/ma_default.c',
							'libmariadb/ma_dtoa.c',
							'libmariadb/ma_errmsg.c',
							'libmariadb/ma_hashtbl.c',
							'libmariadb/ma_init.c',
							'libmariadb/ma_io.c',
							'libmariadb/ma_list.c',
							'libmariadb/ma_ll2str.c',
							'libmariadb/ma_loaddata.c',
							'libmariadb/ma_net.c',
							'libmariadb/ma_password.c',
							'libmariadb/ma_pvio.c',
							'libmariadb/ma_stmt_codec.c',
							'libmariadb/ma_string.c',
							'libmariadb/ma_time.c',
							'libmariadb/ma_tls.c',
							'libmariadb/mariadb_async.c',
							'libmariadb/mariadb_charset.c',
							'libmariadb/mariadb_dyncol.c',
							'libmariadb/mariadb_lib.c',
							'libmariadb/mariadb_rpl.c',
							'libmariadb/mariadb_stmt.c',
							'libmariadb/secure/openssl.c',
							'libmariadb/secure/oxt_crypt.c',

							'plugins/auth/caching_sha2_pw.c',
							'plugins/auth/common.h',
							'plugins/auth/ed25519.c',
							'plugins/auth/ed25519_common.h',
							'plugins/auth/my_auth.c',
							'plugins/auth/old_password.c',
							'plugins/auth/server_plugin.h',
							'plugins/auth/sha256_pw.c',
							'plugins/auth/ref10/api.h',
							'plugins/auth/ref10/base.h',
							'plugins/auth/ref10/base2.h',
							'plugins/auth/ref10/crypto_hash_sha512.h',
							'plugins/auth/ref10/crypto_int32.h',
							'plugins/auth/ref10/crypto_int64.h',
							'plugins/auth/ref10/crypto_sign.h',
							'plugins/auth/ref10/crypto_uint32.h',
							'plugins/auth/ref10/crypto_uint64.h',
							'plugins/auth/ref10/crypto_verify.h',
							'plugins/auth/ref10/crypto_verify_32.h',
							'plugins/auth/ref10/d.h',
							'plugins/auth/ref10/d2.h',
							'plugins/auth/ref10/fe.h',
							'plugins/auth/ref10/fe_0.c',
							'plugins/auth/ref10/fe_1.c',
							'plugins/auth/ref10/fe_add.c',
							'plugins/auth/ref10/fe_cmov.c',
							'plugins/auth/ref10/fe_copy.c',
							'plugins/auth/ref10/fe_frombytes.c',
							'plugins/auth/ref10/fe_invert.c',
							'plugins/auth/ref10/fe_isnegative.c',
							'plugins/auth/ref10/fe_isnonzero.c',
							'plugins/auth/ref10/fe_mul.c',
							'plugins/auth/ref10/fe_neg.c',
							'plugins/auth/ref10/fe_pow22523.c',
							'plugins/auth/ref10/fe_sq.c',
							'plugins/auth/ref10/fe_sq2.c',
							'plugins/auth/ref10/fe_sub.c',
							'plugins/auth/ref10/fe_tobytes.c',
							'plugins/auth/ref10/ge.h',
							'plugins/auth/ref10/ge_add.c',
							'plugins/auth/ref10/ge_add.h',
							'plugins/auth/ref10/ge_double_scalarmult.c',
							'plugins/auth/ref10/ge_frombytes.c',
							'plugins/auth/ref10/ge_madd.c',
							'plugins/auth/ref10/ge_madd.h',
							'plugins/auth/ref10/ge_msub.c',
							'plugins/auth/ref10/ge_msub.h',
							'plugins/auth/ref10/ge_p1p1_to_p2.c',
							'plugins/auth/ref10/ge_p1p1_to_p3.c',
							'plugins/auth/ref10/ge_p2_0.c',
							'plugins/auth/ref10/ge_p2_dbl.c',
							'plugins/auth/ref10/ge_p2_dbl.h',
							'plugins/auth/ref10/ge_p3_0.c',
							'plugins/auth/ref10/ge_p3_dbl.c',
							'plugins/auth/ref10/ge_p3_to_cached.c',
							'plugins/auth/ref10/ge_p3_to_p2.c',
							'plugins/auth/ref10/ge_p3_tobytes.c',
							'plugins/auth/ref10/ge_precomp_0.c',
							'plugins/auth/ref10/ge_scalarmult_base.c',
							'plugins/auth/ref10/ge_sub.c',
							'plugins/auth/ref10/ge_sub.h',
							'plugins/auth/ref10/ge_tobytes.c',
							'plugins/auth/ref10/keypair.c',
							'plugins/auth/ref10/open.c',
							'plugins/auth/ref10/pow22523.h',
							'plugins/auth/ref10/pow225521.h',
							'plugins/auth/ref10/sc.h',
							'plugins/auth/ref10/sc_muladd.c',
							'plugins/auth/ref10/sc_reduce.c',
							'plugins/auth/ref10/sign.c',
							'plugins/auth/ref10/sqrtm1.h',
							'plugins/auth/ref10/verify.c',
							'plugins/compress/c_zlib.c',
							'plugins/pvio/pvio_socket.c',
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
								'OS == "win"',
								{
									'defines':
									[
										'WIN32_LEAN_AND_MEAN',
										'NOGDI',
										'HAVE_DLOPEN',
										'_CRT_SECURE_NO_WARNINGS',
										'_CRT_NONSTDC_NO_DEPRECATE',
									],

									'sources':
									[
										'libmariadb/win32_errmsg.c',
										'libmariadb/win32_errmsg.h',
										'plugins/pvio/pvio_npipe.c',
										'plugins/pvio/pvio_shmem.c',
									],

									'link_settings':
									{
										'libraries':
										[
											'-ladvapi32',
											'-lshlwapi',
											'-luser32',
											'-lws2_32',
										],
									},
								},
							],
							[
								'OS == "mac" or OS == "ios"',
								{
									'defines':
									[
										'_XOPEN_SOURCE',
									],
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
								'-lmariadb',
							],
						},
					},
				],
			],
		},
	],
}
