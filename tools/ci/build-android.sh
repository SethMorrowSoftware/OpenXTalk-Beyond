#!/bin/bash
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

# Builds the Android engine of this checkout, and the externals an Android
# standalone can include, for one architecture with a current NDK, and
# writes them into a new folder laid out as an installed OXT-Beyond's
# Runtime/Android (the Android plan's phase 2):
#
#   tools/ci/build-android.sh <architecture> <runtime folder>
#   tools/ci/build-android.sh <architecture> --libraries
#
# <architecture> is arm64, armv7, x86_64 or x86 (the folders arm64-v8a,
# armeabi-v7a, x86_64 and x86, as Android names them). --libraries builds
# only the libraries below, which a cache can then keep whether the engine
# builds or not. The folder:
#
#   <abi>/Standalone                    the engine, a shared library with the
#                                       section (.project) that the IDE's
#                                       builder writes the stack into
#   <abi>/RevDb, DbSqlite, DbMysql,     the externals
#     RevXml, RevZip, RevSecurity,
#     RevPdfPrinter
#   Classes                             the Java layer (a jar)
#   Manifest.xml, livecode_inputcontrol.xml, nfc_tech_filter.xml,
#   file_provider_paths.xml, notify_icon.png
#                                       what the builder puts beside them
#
# The libraries are stripped of their debug information, which the folder
# debug/<abi> keeps (whole, unstripped). Nothing here replaces the engine
# that the packages ship (LiveCode 9.6.3's, in the runtimes asset):
# .github/workflows/android-engine.yml keeps the folder as an artifact.
#
# The toolchain is the NDK's own (Clang, the LLVM tools and lld; config.py
# and prebuilt/scripts/android.inc choose it when there is no standalone
# toolchain), of the version in config/android-ndk-version, and the
# engine runs on Android 5.0 (API 21) and later, the lowest a current NDK
# builds for. It needs Linux with the tools of a Linux build (BUILDING.md:
# gcc and g++, make, perl, bison and flex, and Python 2.7 as "python" for
# gyp and config.py), a JDK (javac and jar, for the Java layer), and the
# Android SDK with that NDK, the platform of ANDROID_API_VERSION (its
# android.jar) and build tools (config.py asks for them; the Java of the
# AIDL interfaces is kept beside their .aidl files, so aidl is not run).
#
# The libraries: the engine links OpenSSL, ICU and the Thirdparty libraries
# built for Android (prebuilt/lib/android/<architecture>/ndk21r<NDK major>),
# and the build's host tools (lc-compile, and the others that make the
# engine's sources) link ICU, libz and libffi built for Linux
# (prebuilt/lib/linux/<host architecture>). No server publishes these, so
# this script builds the ones that are missing, as build-web.sh does for
# the web: OpenSSL, ICU and the Thirdparty libraries with
# prebuilt/build-libraries.sh (OpenSSL's and ICU's sources are the only
# downloads), libz and libffi in a Linux build folder, build-linux-<arch>,
# configured for nothing else. PREBUILT_SKIP_FETCH=1, because nobody
# publishes the tarballs that prebuilt/fetch-libraries.sh would look for.
#
# Environment:
#   ANDROID_SDK          the Android SDK (or ANDROID_HOME, ANDROID_SDK_ROOT)
#   ANDROID_NDK          the NDK (default: <SDK>/ndk/<config/android-ndk-version>)
#   ANDROID_API_VERSION  the platform whose android.jar the Java layer
#                        compiles against (default 36)
#   ANDROID_BUILD_TOOLS  the build tools' version, which config.py asks for
#                        (default: the newest in the SDK)
#   JAVA_SDK             the JDK (default: the one of javac on PATH)
#   ANDROID_JOBS         how many jobs make runs at once (default: the
#                        number of processors)

set -euo pipefail

# The architectures, and Android's names for them (its ABIs)
declare -A ABIS=([arm64]=arm64-v8a [armv7]=armeabi-v7a [x86_64]=x86_64 [x86]=x86)
# The engine's gyp targets and what they make, in the runtime folder's
# names (the externals are named as the IDE's builder looks for them)
ENGINE_TARGETS=(standalone external-revdb dbsqlite dbmysql external-revxml external-revzip
	revsecurity external-revpdfprinter)
declare -A LIBRARIES=([Standalone-Community]=Standalone [RevDb]=RevDb [DbSqlite]=DbSqlite
	[DbMysql]=DbMysql [RevXml]=RevXml [RevZip]=RevZip [RevSecurity]=RevSecurity
	[RevPdfPrinter]=RevPdfPrinter)
declare -A FILES=([Classes-Community]=Classes [Manifest.xml]=Manifest.xml
	[livecode_inputcontrol.xml]=livecode_inputcontrol.xml [nfc_tech_filter.xml]=nfc_tech_filter.xml
	[file_provider_paths.xml]=file_provider_paths.xml [notify_icon.png]=notify_icon.png)
# The lowest Android the engine runs on
ANDROID_MIN_API=21

function fail {
	echo "error: $*" >&2
	exit 1
}

if [ $# -ne 2 ] ; then
	echo "usage: $0 <architecture: ${!ABIS[*]}> <runtime folder> | --libraries" >&2
	exit 2
fi

ARCH=$1
[ -n "${ABIS[${ARCH}]:-}" ] || fail "no Android architecture ${ARCH} (one of: ${!ABIS[*]})"
ABI=${ABIS[${ARCH}]}

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=
if [ "$2" != --libraries ] ; then
	OUT=$2
	case "${OUT}" in
		/*) ;;
		*) OUT="$(pwd)/${OUT}" ;;
	esac
fi
JOBS=${ANDROID_JOBS:-$(nproc)}

# A new folder, so that no file of another build stays in it
if [ -n "${OUT}" ] && [ -e "${OUT}" ] && [ -n "$(ls -A "${OUT}" 2>/dev/null)" ] ; then
	fail "${OUT} exists and is not empty"
fi

cd "${REPO}"

case "$(uname -s)" in
	Linux) ;;
	*) fail "the Android engine is built on Linux" ;;
esac

# The architecture name of prebuilt/scripts/platform.inc, which names the
# folder of the host's libraries
case "$(uname -m)" in
	x86_64) HOST_ARCH=x86_64 ;;
	*) fail "the NDK's toolchain runs on x86_64 Linux, not $(uname -m)" ;;
esac

# The tools
python -c 'import sys; sys.exit(sys.version_info[0] != 2)' 2>/dev/null ||
	fail "\"python\" must be Python 2.7 (gyp and config.py need it)"

ANDROID_SDK=${ANDROID_SDK:-${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}}
[ -n "${ANDROID_SDK}" ] && [ -d "${ANDROID_SDK}" ] ||
	fail "the Android SDK was not found: set ANDROID_SDK"
NDK_WANTED=$(head -n 1 config/android-ndk-version | tr -d '[:space:]')
[ -n "${NDK_WANTED}" ] || fail "config/android-ndk-version is empty"
ANDROID_NDK=${ANDROID_NDK:-${ANDROID_SDK}/ndk/${NDK_WANTED}}
[ -f "${ANDROID_NDK}/source.properties" ] ||
	fail "no NDK in ${ANDROID_NDK}: install ndk;${NDK_WANTED} with the SDK's sdkmanager, or set ANDROID_NDK"
NDK_FOUND=$(sed -n 's/^Pkg\.Revision *= *\([^ ]*\) *$/\1/p' "${ANDROID_NDK}/source.properties")
if [ "${NDK_FOUND}" != "${NDK_WANTED}" ] ; then
	echo "warning: NDK ${NDK_FOUND:-of an unknown version} is not the version this" \
		"repository builds with, ${NDK_WANTED} (config/android-ndk-version)" >&2
fi
LLVM_BIN="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin"
[ -x "${LLVM_BIN}/clang" ] || fail "the NDK in ${ANDROID_NDK} has no toolchain of its own (${LLVM_BIN})"

ANDROID_API_VERSION=${ANDROID_API_VERSION:-36}
ANDROID_PLATFORM=android-${ANDROID_API_VERSION}
[ -f "${ANDROID_SDK}/platforms/${ANDROID_PLATFORM}/android.jar" ] ||
	fail "the SDK has no ${ANDROID_PLATFORM} (platforms;${ANDROID_PLATFORM})"
if [ -z "${ANDROID_BUILD_TOOLS:-}" ] ; then
	ANDROID_BUILD_TOOLS=$(ls "${ANDROID_SDK}/build-tools" 2>/dev/null | sort -V | tail -n 1)
fi
[ -n "${ANDROID_BUILD_TOOLS}" ] && [ -d "${ANDROID_SDK}/build-tools/${ANDROID_BUILD_TOOLS}" ] ||
	fail "the SDK has no build tools (set ANDROID_BUILD_TOOLS)"

if [ -z "${JAVA_SDK:-}" ] ; then
	JAVAC=$(command -v javac || true)
	[ -n "${JAVAC}" ] || fail "no javac on PATH: install a JDK, or set JAVA_SDK"
	JAVA_SDK=$(dirname "$(dirname "$(readlink -f "${JAVAC}")")")
fi
[ -x "${JAVA_SDK}/bin/javac" ] && [ -x "${JAVA_SDK}/bin/jar" ] || fail "${JAVA_SDK} is not a JDK (no bin/javac and bin/jar)"

# What config.py and the prebuilt scripts read. The libraries' folder is
# named for the lowest Android and the NDK (config/android.gypi's
# android_subplatform, ndk<platform version><NDK version>), so that
# libraries of another NDK are never linked by mistake.
export ANDROID_SDK ANDROID_NDK ANDROID_API_VERSION ANDROID_PLATFORM ANDROID_BUILD_TOOLS JAVA_SDK
export ANDROID_NDK_PLATFORM_VERSION=${ANDROID_MIN_API}
export ANDROID_NDK_VERSION="r${NDK_WANTED%%.*}"
SUBPLATFORM="ndk${ANDROID_NDK_PLATFORM_VERSION}${ANDROID_NDK_VERSION}"

VERSION=$(sed -n 's/^BUILD_SHORT_VERSION *= *\([^ ]*\) *$/\1/p' version)
[ -n "${VERSION}" ] || fail "no BUILD_SHORT_VERSION in the file version"

echo "Android engine ${VERSION} for ${ARCH} (${ABI}): NDK ${NDK_FOUND} (${ANDROID_NDK}), Android ${ANDROID_MIN_API} and later,"
echo "  ${ANDROID_PLATFORM}, build tools ${ANDROID_BUILD_TOOLS}, JDK ${JAVA_SDK}, ${JOBS} jobs, host linux-${HOST_ARCH}"
echo "Runtime folder: ${OUT:-none (--libraries)}"

PREBUILT="${REPO}/prebuilt"
LIB_ANDROID="${PREBUILT}/lib/android/${ARCH}/${SUBPLATFORM}"
LIB_HOST="${PREBUILT}/lib/linux/${HOST_ARCH}"
BIN_HOST="${PREBUILT}/bin/linux/${HOST_ARCH}"

# True when every one of the libraries (lib<name>.a) is in the folder
function hasLibraries {
	local DIR=$1
	shift
	local LIB
	for LIB in "$@" ; do
		[ -f "${DIR}/${LIB}.a" ] || return 1
	done
}

# The Thirdparty libraries that the Android engine links (lib_versions.inc)
read -r -a THIRDPARTY_LIBS <<< "$(bash -c 'source prebuilt/scripts/lib_versions.inc && echo "${Thirdparty_LIBS_android}"')"
[ ${#THIRDPARTY_LIBS[@]} -gt 0 ] || fail "no Thirdparty_LIBS_android in prebuilt/scripts/lib_versions.inc"
ICU_LIBS=(libicudata libicui18n libicuio libicutu libicuuc)
ICU_LIBS_ANDROID=(libicudata libicui18n libicuio libicuuc)
ICU_DATA=$(bash -c 'source prebuilt/scripts/lib_versions.inc && echo "icudt${ICU_VERSION%%.*}l.dat"')

# Every build of the engine runs prebuilt/fetch-libraries.sh, whose
# libraries are built here, or restored by a cache
export PREBUILT_SKIP_FETCH=1

# 1. ICU, for the host (its tools build ICU's data, and the host tools link
# it) and for Android (build-icu.sh builds both; for Android without its
# tools, which build nothing there)
if hasLibraries "${LIB_ANDROID}" "${ICU_LIBS_ANDROID[@]}" && hasLibraries "${LIB_HOST}" "${ICU_LIBS[@]}" &&
		[ -x "${BIN_HOST}/icupkg" ] && [ -f "${PREBUILT}/include/unicode/uchar.h" ] &&
		[ -f "${PREBUILT}/share/${ICU_DATA}" ] ; then
	echo "ICU: already built"
else
	echo "ICU: building it for linux-${HOST_ARCH} and Android ${ARCH}"
	(cd prebuilt && PREBUILT_MAKE_JOBS="${JOBS}" PREBUILT_BUILD_LIBS=icu ./build-libraries.sh android "${ARCH}" "${SUBPLATFORM}")
fi

# 2. libz and libffi for the host, in a Linux build folder of their own
if hasLibraries "${LIB_HOST}" libz libffi ; then
	echo "libz and libffi for linux-${HOST_ARCH}: already built"
else
	echo "libz and libffi: building them for linux-${HOST_ARCH}"
	make config-linux-"${HOST_ARCH}"
	make -C build-linux-"${HOST_ARCH}"/livecode libz libffi BUILDTYPE=Release -j"${JOBS}"
	mkdir -p "${LIB_HOST}"
	for LIB in libz libffi ; do
		cp "build-linux-${HOST_ARCH}/livecode/out/Release/obj.target/thirdparty/${LIB}/${LIB}.a" "${LIB_HOST}/"
	done
fi

# 3. OpenSSL for Android (build-openssl.sh, which names its libraries
# libcustomcrypto and libcustomssl), before the Thirdparty libraries:
# libmysql includes its headers (as build-libraries.sh orders them)
if hasLibraries "${LIB_ANDROID}" libcustomcrypto libcustomssl && [ -f "${PREBUILT}/include/openssl/evp.h" ] ; then
	echo "OpenSSL for Android ${ARCH}: already built"
else
	echo "OpenSSL: building it for Android ${ARCH}"
	(cd prebuilt && MAKEFLAGS="-j${JOBS}" PREBUILT_BUILD_LIBS=openssl ./build-libraries.sh android "${ARCH}" "${SUBPLATFORM}")
fi

# 4. The Thirdparty libraries for Android (build-thirdparty.sh configures
# build-android-<architecture> and builds its target thirdparty-prebuilts)
if hasLibraries "${LIB_ANDROID}" "${THIRDPARTY_LIBS[@]}" ; then
	echo "Thirdparty libraries for Android ${ARCH}: already built"
else
	echo "Thirdparty libraries: building them for Android ${ARCH}"
	(cd prebuilt && PREBUILT_BUILD_LIBS=thirdparty ./build-libraries.sh android "${ARCH}" "${SUBPLATFORM}")
fi

if [ -z "${OUT}" ] ; then
	echo "The libraries are built."
	exit 0
fi

# 5. The engine and the externals
make config-android-"${ARCH}"
make -C build-android-"${ARCH}"/livecode "${ENGINE_TARGETS[@]}" BUILDTYPE=Release -j"${JOBS}"

# 6. The runtime folder
BUILT="${REPO}/build-android-${ARCH}/livecode/out/Release"
mkdir -p "${OUT}/${ABI}" "${OUT}/debug/${ABI}"
for NAME in "${!LIBRARIES[@]}" ; do
	FILE="${BUILT}/${NAME}"
	[ -s "${FILE}" ] || fail "the build wrote no ${FILE}"
	cp "${FILE}" "${OUT}/debug/${ABI}/${LIBRARIES[${NAME}]}"
	"${LLVM_BIN}/llvm-strip" --strip-debug -o "${OUT}/${ABI}/${LIBRARIES[${NAME}]}" "${FILE}"
done
for NAME in "${!FILES[@]}" ; do
	FILE="${BUILT}/${NAME}"
	[ -s "${FILE}" ] || fail "the build wrote no ${FILE}"
	cp "${FILE}" "${OUT}/${FILES[${NAME}]}"
done

echo
echo "Android runtime ${VERSION} (${ABI}) in ${OUT}:"
(cd "${OUT}" && find . -type f | LC_ALL=C sort | sed 's|^\./||' | while read -r FILE ; do
	printf '  %12s  %s  %s\n' "$(stat -c %s "${FILE}")" "$(sha256sum "${FILE}" | cut -c1-16)" "${FILE}"
done)
