# Android options
ANDROID_NDK=${ANDROID_NDK:-"${HOME}/android/toolchain/android-ndk"}
ANDROID_PLATFORM=${ANDROID_PLATFORM:-android-29}

# OXT-Beyond: an NDK from r19 on has a Clang toolchain of its own, with
# every architecture's sysroot, in toolchains/llvm/prebuilt/<host>/bin; r23
# took out the GNU tools (ar, objcopy, strip and the bfd linker) and r24
# the make_standalone_toolchain.py that made the standalone toolchains
# these scripts used (config.py's guess_ndk_llvm_bin finds the same
# folder for the engine). Prints that folder for this host, or nothing
# when ${ANDROID_NDK} has none.
function androidNdkLlvmBin {
	local HOST
	case "$(uname -s)" in
		Darwin*)
			HOST=darwin-x86_64
			;;
		CYGWIN*|MINGW*|MSYS*)
			HOST=windows-x86_64
			;;
		*)
			HOST=linux-x86_64
			;;
	esac
	local DIR="${ANDROID_NDK}/toolchains/llvm/prebuilt/${HOST}/bin"
	if [ -f "${DIR}/clang" ] || [ -f "${DIR}/clang.exe" ] ; then
		echo "${DIR}"
	fi
}

function configureAndroidToolchain {
	ANDROID_ARCH=$1

# Android architecture
if [ -z "${ANDROID_ARCH}" ] ; then
	echo >&2 "Error: \${ANDROID_ARCH} must be set"
	exit 1
fi

# Expected Android standalone toolchain directory name
case "${ANDROID_ARCH}" in
	armv6|armv7)
		ANDROID_STANDALONE_TOOLCHAIN_DIRNAME="standalone-arm"
		;;
	*)
		ANDROID_STANDALONE_TOOLCHAIN_DIRNAME="standalone-${ANDROID_ARCH}"
		;;
esac

# Expected Android target triple and architecture flag(s)
case "${ANDROID_ARCH}" in
	armv6|armv7)
		# Google recommends using Thumb instructions when targeting ARM.
		ANDROID_TRIPLE=arm-linux-androideabi
		if [ "${ANDROID_ARCH}" == "armv7" ] ; then
			BUILD_ARCH=armv7a
		else
			BUILD_ARCH=armv6
		fi
		ANDROID_TARGET_FLAGS="-target ${ANDROID_TRIPLE} -march=${BUILD_ARCH} -mthumb"
		;;
	arm64)
		ANDROID_TRIPLE=aarch64-linux-android
		ANDROID_TARGET_FLAGS="-target ${ANDROID_TRIPLE}"
		;;
	x86)
		ANDROID_TRIPLE=i686-linux-android
		ANDROID_TARGET_FLAGS="-target ${ANDROID_TRIPLE} -march=i686"
		;;
	x86_64)
		ANDROID_TRIPLE=x86_64-linux-android
		ANDROID_TARGET_FLAGS="-target ${ANDROID_TRIPLE}"
		;;
	*)
		ANDROID_TRIPLE=
		ANDROID_TARGET_FLAGS=
		;;
esac

# OXT-Beyond: with no standalone toolchain (named by ANDROID_TOOLCHAIN, or
# in ~/android/toolchain), the NDK's own Clang toolchain, when it has one
# (androidNdkLlvmBin)
ANDROID_LLVM_BIN=
if [ -z "${OBJCOPY}" ] && [ -z "${ANDROID_TOOLCHAIN}" ] &&
		[ ! -d "${HOME}/android/toolchain/${ANDROID_STANDALONE_TOOLCHAIN_DIRNAME}" ] ; then
	ANDROID_LLVM_BIN=$(androidNdkLlvmBin)
fi

# Has a full, custom toolchain been specified?
#  AR, CC, CXX, LINK, OBJCOPY, RANLIB, STRIP
if [ ! -z "${OBJCOPY}" ] ; then
	ANDROID_CC="${CC}"
	ANDROID_CXX="${CXX}"
	ANDROID_LINK="${LINK}"
elif [ -n "${ANDROID_LLVM_BIN}" ] ; then
	# The lowest Android the libraries run on (ANDROID_NDK_PLATFORM_VERSION,
	# as config.py names it; 21, Android 5.0, the lowest that a current
	# NDK builds for), in the target that Clang takes, which names it
	ANDROID_API="${ANDROID_NDK_PLATFORM_VERSION:-21}"
	case "${ANDROID_ARCH}" in
		armv7)
			# (Clang's target for ARMv7 is armv7a-, which brings the ABI's
			# float settings; Thumb, as Google recommends)
			ANDROID_TARGET_FLAGS="-target armv7a-linux-androideabi${ANDROID_API} -mthumb"
			;;
		arm64|x86|x86_64)
			ANDROID_TARGET_FLAGS="${ANDROID_TARGET_FLAGS/-target ${ANDROID_TRIPLE}/-target ${ANDROID_TRIPLE}${ANDROID_API}}"
			;;
		*)
			echo >&2 "Error: the NDK's own toolchain does not build for ${ANDROID_ARCH}"
			exit 1
			;;
	esac

	# Position-independent code, as the libraries are linked into the
	# engine and the externals, which are shared libraries: the NDK's
	# Clang makes PIE code by default, which lld refuses to link into one
	# where it refers to a symbol another library could stand in for (as
	# a Linux build of the libraries asks for -fPIC; platform.inc)
	export ANDROID_CC="${ANDROID_LLVM_BIN}/clang"
	export ANDROID_CFLAGS="${ANDROID_TARGET_FLAGS} -fPIC"
	export ANDROID_CXX="${ANDROID_LLVM_BIN}/clang++"
	export ANDROID_CXXFLAGS="${ANDROID_TARGET_FLAGS} -fPIC"
	export ANDROID_LINK="${ANDROID_LLVM_BIN}/clang++"
	export ANDROID_LDFLAGS="${ANDROID_TARGET_FLAGS}"
	export ANDROID_AR="${ANDROID_LLVM_BIN}/llvm-ar"
	export ANDROID_OBJCOPY="${ANDROID_LLVM_BIN}/llvm-objcopy"
	export ANDROID_RANLIB="${ANDROID_LLVM_BIN}/llvm-ranlib"
	export ANDROID_STRIP="${ANDROID_LLVM_BIN}/llvm-strip"

	# the toolchain's folder, whose sysroot (every architecture's headers
	# and libraries) is platform.inc's CROSS_SYSROOT
	export ANDROID_TOOLCHAIN_BASE="${ANDROID_LLVM_BIN%/bin}"
	export ANDROID_LLVM_BIN
	export ANDROID_API
	export ANDROID_TRIPLE
else
	# Attempt to set up the toolchain automatically
	if [ -z "${ANDROID_TOOLCHAIN}" ] ; then
		ANDROID_TOOLCHAIN_BASE="${HOME}/android/toolchain/${ANDROID_STANDALONE_TOOLCHAIN_DIRNAME}"
		ANDROID_TOOLCHAIN="${ANDROID_TOOLCHAIN_BASE}/bin/${ANDROID_TRIPLE}-"
	else
		# derive ANDROID_TOOLCHAIN_BASE from ANDROID_TOOLCHAIN
		ANDROID_TOOLCHAIN_BASE="${ANDROID_TOOLCHAIN%/*/*}"
	fi

	ANDROID_CC_NAME=${ANDROID_CC_NAME:-clang}
	ANDROID_CXX_NAME=${ANDROID_CXX_NAME:-clang++}

	export ANDROID_CC="${ANDROID_TOOLCHAIN}${ANDROID_CC_NAME}"
	export ANDROID_CFLAGS="${ANDROID_TARGET_FLAGS}"
	export ANDROID_CXX="${ANDROID_TOOLCHAIN}${ANDROID_CXX_NAME}"
	export ANDROID_CXXFLAGS="${ANDROID_TARGET_FLAGS}"
	export ANDROID_LINK="${ANDROID_TOOLCHAIN}${ANDROID_CXX_NAME}"
	export ANDROID_LDFLAGS="${ANDROID_TARGET_FLAGS}"
	export ANDROID_AR="${ANDROID_TOOLCHAIN}ar"
	export ANDROID_OBJCOPY="${ANDROID_TOOLCHAIN}objcopy"
	export ANDROID_RANLIB="${ANDROID_TOOLCHAIN}ranlib"
	export ANDROID_STRIP="${ANDROID_TOOLCHAIN}strip"

	export ANDROID_TOOLCHAIN_BASE
	
	# ICU needs to know the Android triple being targeted.
	export ANDROID_TRIPLE
fi

}

# Android architectures
export ARCHS="armv6 armv7 x86 x86_64"
