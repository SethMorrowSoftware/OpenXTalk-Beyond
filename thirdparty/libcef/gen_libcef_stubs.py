#!/usr/bin/env python3

import os
import re
import sys

# generate export list

_s_type_table = {
"int":"integer",
"int16":"integer",
"uint16":"integer",
"cef_platform_thread_id_t":"integer",
"cef_platform_thread_handle_t":"integer",
"int32":"integer",
"uint32":"integer",
"int64":"integer64",
"uint64":"integer64",
"double":"double",
"void":"",
"size_t":"intsize",
"time_t":"integer64",
"cef_json_parser_options_t":"integer",
"cef_json_writer_options_t":"integer",
"cef_thread_priority_t":"integer",
"cef_message_loop_type_t":"integer",
"cef_com_init_mode_t":"integer",
"cef_path_key_t":"integer",
"cef_string_list_t":"pointer",
"cef_string_map_t":"pointer",
"cef_string_multimap_t":"pointer",
"cef_string_userfree_t":"pointer",
"cef_string_userfree_wide_t":"pointer",
"cef_string_userfree_utf8_t":"pointer",
"cef_string_userfree_utf16_t":"pointer",
"cef_thread_id_t":"integer",
"cef_uri_unescape_rule_t":"integer",
"cef_xml_encoding_type_t":"integer",
"cef_cert_status_t": "integer",
# CEF 156 spells its integers with <stdint.h>
"int32_t":"integer",
"uint16_t":"integer",
"uint32_t":"integer",
"int64_t":"integer64",
"uint64_t":"integer64",
"long long":"integer64",
# Small structs passed and returned by value, as an integer of their size:
# every ABI the engine is built for passes and returns an 8-byte struct of
# integers as it does a 64-bit integer (System V x86-64, Win64 and Win32
# alike). cef_basetime_t is { int64_t val; }, cef_point_t { int x, y; }.
"cef_basetime_t":"integer64",
"cef_point_t":"integer64",
}

# Structs that no stub type can stand for (cef_rect_t, 16 bytes: two
# registers in System V, a hidden pointer in Win64). Their functions get an
# optional stub with a pointer in its place, so that the wrapper links: it
# must never be called, and is not (they are CefDisplay's, of CEF's Views,
# which OXT does not use).
_s_unrepresentable_types = {
"cef_rect_t":"pointer",
}

def log(pMsg):
	sys.stderr.write(pMsg + "\n")
	sys.stderr.flush()

def cef_type_to_stub_type(pType):
	if pType.startswith("const "):
		pType = pType.replace("const ", "")
	if pType.startswith("enum "):
		return True, "integer"
	if pType[-1] == "*":
		return (True, "pointer")
	if pType in _s_type_table:
		return (True, _s_type_table[pType])
	if pType in _s_unrepresentable_types:
		return (True, _s_unrepresentable_types[pType])

	return (False, pType)

def conv_to_stub(pSig, pOptional = False):
	# remove CEF_EXPORT
	tSig = pSig.replace("CEF_EXPORT ", "")
	tSplit = tSig.split("(")
	if len(tSplit) != 2:
		return "# ( " + pSig

	tReturnType_Name, tParams = tSplit
	tSplit = tReturnType_Name.split(" ")

	if len(tSplit) < 2:
		return "# returntype_name " + pSig

	tReturnType = " ".join(tSplit[:-1])
	tName = tSplit[-1]

	tSplit = tParams.split(")")

	if len(tSplit) != 2:
		return "# ) " + pSig

	tParams = tSplit[0].strip()
	if tParams == "void":
		tParams = ""

	tStubParams = []

	if any(re.search(r"\b" + t + r"\b(?!\s*\*)", pSig) for t in _s_unrepresentable_types):
		pOptional = True
	tStubTypesKnown, tStubReturnType = cef_type_to_stub_type(tReturnType)
	if not tStubTypesKnown:
		log("unknown type: " + tStubReturnType)
		
	if len(tParams) > 0:
		tSplit = tParams.split(",")

		for tParam in tSplit:
			tParamSplit = tParam.strip().split(" ")
			if len(tParamSplit) < 2:
				return "# param " + str(tParamSplit) + " " + pSig
			tParamType = " ".join(tParamSplit[:-1])
			tKnown, tType = cef_type_to_stub_type(tParamType)
			if not tKnown:
				log("unknown type: " + tType)
				
			tStubTypesKnown &= tKnown
			tStubParams.append(tType)

	if tStubTypesKnown and pOptional:
		tPrefix = "	? "
	elif tStubTypesKnown:
		tPrefix = "	"
	else:
		tPrefix = "#	"
	return tPrefix + tName + ": (" + ",".join(tStubParams) + ") -> (" + tStubReturnType + ")"

def gen_stubs_file(pPaths):
	tSignatureList = []
	
	for tPath in pPaths:
		for tRoot, tFolders, tFiles in os.walk(tPath):
			# CEF's own test functions are in a libcef built for them only,
			# but the wrapper names them: optional
			tTest = os.path.basename(tRoot) == "test"
			tHeaders = filter(lambda s : s.endswith(".h"), tFiles)

			for tHeader in sorted(tHeaders):
				# Since CEF 156 one include folder has the headers of every
				# platform (thirdparty/libcef/UPDATE.md): what one platform's
				# libcef alone exports is optional, so that the others load
				tOptional = tTest or tHeader.endswith(("_win.h", "_linux.h", "_mac.h"))
				with open(os.path.join(tRoot, tHeader), "r") as tFile:
					tContents = tFile.read()
					tLines = tContents.split();

					i = 0;
					while i < len(tLines):
						tLine = tLines[i].strip()
						i += 1

						if tLine.startswith("CEF_EXPORT"):
							while i < len(tLines) and not tLine.endswith(";"):
								tLine = tLine + " " + tLines[i].strip()
								i+=1;

							tSignatureList.append(conv_to_stub(tLine, tOptional))
							#print conv_to_stub(tLine)

	tSignatureList.sort()
	
	print("cef ./Externals/CEF/libcef ./Externals/CEF/libcef ./Externals/CEF/libcef")
	print("\n".join(tSignatureList))

#get include folder from the command line
tPaths = ["."]
if len(sys.argv) > 1:
	tPaths = sys.argv[1:]

gen_stubs_file(tPaths)
