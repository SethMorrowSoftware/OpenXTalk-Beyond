#!/bin/bash

source "${BASEDIR}/scripts/platform.inc"
source "${BASEDIR}/scripts/lib_versions.inc"
source "${BASEDIR}/scripts/util.inc"

# Grab the source for the library
if [ "${ARCH}" == "x86" ] ; then
   CEF_DST="cef_binary_${CEF_VERSION}+${CEF_BUILDREVISION}+chromium-${CEFChromium_VERSION}_${PLATFORM}32"
   CEF_SRC="cef_binary_${CEF_VERSION}%2B${CEF_BUILDREVISION}%2Bchromium-${CEFChromium_VERSION}_${PLATFORM}32.tar.bz2"
elif [ "${ARCH}" == "x86_64" ] ; then
   # The "minimal" distribution has the same Release/ and Resources/ folders,
   # which are all that buildCEF packages, at half the download size
   CEF_DST="cef_binary_${CEF_VERSION}+${CEF_BUILDREVISION}+chromium-${CEFChromium_VERSION}_${PLATFORM}64_minimal"
   CEF_SRC="cef_binary_${CEF_VERSION}%2B${CEF_BUILDREVISION}%2Bchromium-${CEFChromium_VERSION}_${PLATFORM}64_minimal.tar.bz2"
else 
  echo "No CEF ${CEF_VERSION} binaries for ${PLATFORM}/${ARCH}; skipping"
  exit 0
fi

CEF_TGZ="${CEF_DST}.tar.bz2"
CEF_SUMS="$(cd "${BASEDIR}" && pwd)/cef-sha1sums"
cd "${BUILDDIR}"

if [ ! -d "$CEF_DST" ] ; then
	if [ ! -e "$CEF_TGZ" ] ; then
		echo "Fetching CEF source"
		fetchUrl "https://cef-builds.spotifycdn.com/${CEF_SRC}" "${CEF_TGZ}"
		if [ $? != 0 ] ; then
			echo "downloading https://cef-builds.spotifycdn.com/${CEF_SRC} failed"
			if [ -e "${CEF_TGZ}" ] ; then 
				rm ${CEF_TGZ} 
			fi
			exit
		fi
	fi
	
	# The SHA-1 that Spotify publishes for the file (prebuilt/cef-sha1sums)
	EXPECTED=$(awk -v f="${CEF_TGZ}" '$0 !~ /^#/ && $2 == f { print tolower($1) }' "${CEF_SUMS}")
	if [ -z "${EXPECTED}" ] ; then
		echo "error: ${CEF_TGZ} has no entry in prebuilt/cef-sha1sums" >&2
		exit 1
	fi
	ACTUAL=$(sha1sum "${CEF_TGZ}" | cut -d' ' -f1)
	if [ "${ACTUAL}" != "${EXPECTED}" ] ; then
		rm -f "${CEF_TGZ}"
		echo "error: SHA-1 of ${CEF_TGZ} is ${ACTUAL}, not ${EXPECTED} (prebuilt/cef-sha1sums); the download was deleted" >&2
		exit 1
	fi
	echo "SHA-1 OK: ${CEF_TGZ}"

	echo "Unpacking CEF source"
	tar -jxf "${CEF_TGZ}"
fi
				
# just repackage existing prebuilts and strip unneeded symbols
function buildCEF {
	local PLATFORM=$1
	local ARCH=$2
	
	mkdir -p "${OUTPUT_DIR}/lib/${PLATFORM}/${ARCH}/CEF"
	cp -av "${BUILDDIR}/${CEF_DST}/Release/"* "${OUTPUT_DIR}/lib/${PLATFORM}/${ARCH}/CEF/"
  cp -av "${BUILDDIR}/${CEF_DST}/Resources/"* "${OUTPUT_DIR}/lib/${PLATFORM}/${ARCH}/CEF/"
  strip --strip-unneeded "${OUTPUT_DIR}/lib/${PLATFORM}/${ARCH}/CEF/libcef.so"
}

buildCEF "${PLATFORM}" "${ARCH}"
	
