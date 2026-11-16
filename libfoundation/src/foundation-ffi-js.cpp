/*                                                                     -*-c++-*-
Copyright (C) 2015 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

/* Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
   (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
   Seth Morrow (2026); its Git history and CHANGELOG.md say what changed. */

#include <emscripten.h>
#include <ffi.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

/* ================================================================
 * Helper functions
 * ================================================================ */

/* Map libffi type descriptors to the type names that the runtime's
 * getValue() and setValue() take. */
static const char *
ffi_map_to_llvm_ir(ffi_type *p_type) {
	if (p_type == &ffi_type_void)
		return NULL;
	if (p_type == &ffi_type_sint8 || p_type == &ffi_type_uint8)
		return "i8";
	if (p_type == &ffi_type_uint16 || p_type == &ffi_type_sint16)
		return "i16";
	if (p_type == &ffi_type_uint32 || p_type ==  &ffi_type_sint32)
		return "i32";
	if (p_type == &ffi_type_uint64 || p_type == &ffi_type_sint64)
		return "i64";
	if (p_type == &ffi_type_float)
		return "float";
	if (p_type == &ffi_type_double)
		return "double";
	if (p_type == &ffi_type_pointer)
		return "*";

	abort(); /* Should never be reached */
	return NULL;
};

/* Call the function at p_fn in the WebAssembly function table, from
 * JavaScript: JavaScript can call a function of any signature, reading
 * each argument from the argument values array.  (An i64 is a BigInt in
 * JavaScript, as the function takes it.)
 *
 * The engine cannot yield to the browser while a JavaScript function is
 * on its stack (em-async.js), so the call is counted as a call into the
 * engine from JavaScript, as calls from a page are: a wait inside it
 * returns at once. */
EM_JS_DEPS(foundation_ffi_js,
           "$getWasmTableEntry,$getValue,$setValue,$UTF8ToString");

EM_JS(void, __MCFfiCallJS, (void *p_fn,
                            int p_nargs,
                            void *x_rvalue,
                            void **x_avalues,
                            const char *p_rvalue_type,
                            const char **p_avalue_types), {
	var func = getWasmTableEntry(p_fn);

	// Each value in the argument values array is a pointer to the
	// location where the actual argument value is stored.
	var args = [];
	for (var i = 0; i < p_nargs; ++i) {
		var type = UTF8ToString(getValue(p_avalue_types + i * 4, '*'));
		args.push(getValue(getValue(x_avalues + i * 4, '*'), type));
	}

	var callStack = null;
	if (typeof Asyncify != 'undefined') {
		callStack = Asyncify.exportCallStack;
		callStack.push('ffi_call');
	}
	var result;
	try {
		result = func.apply(null, args);
	} finally {
		if (callStack) {
			callStack.pop();
		}
	}

	if (p_rvalue_type) {
		// An integer smaller than a word is written byte by byte, in its
		// own size: its slot need not be aligned to a word (a CBool's is
		// one byte, at any address), and setValue writes a word at the
		// word boundary below an unaligned address, which left the slot
		// as it was. (OXT-Beyond: it was written as a word, as libffi
		// returns it.)
		var type = UTF8ToString(p_rvalue_type);
		if (type == 'i8' || type == 'i16') {
			var size = type == 'i8' ? 1 : 2;
			for (var b = 0; b < size; ++b) {
				setValue(x_rvalue + b, (result >> (8 * b)) & 0xff, 'i8');
			}
		} else {
			setValue(x_rvalue, result, type);
		}
	}
});

/* ================================================================
 * Emscripten-specific implementations of libffi functions
 * ================================================================ */

extern "C" ffi_status
ffi_prep_cif_machdep(ffi_cif *cif)
{
	return FFI_OK;
}

extern "C" void
ffi_call(ffi_cif *p_cif,
         void (*p_fn)(void),
         void *x_rvalue,
         void **x_avalues)
{
	/* Only pay any attention to the "default ABI", which we'll treat as the
	 * Emscripten ABI (even if it isn't). */
	assert(p_cif->abi == FFI_DEFAULT_ABI);

	/* Convert the data type information stored in the cif data to
	 * values that are more easily understood by getValue() and
	 * setValue(). */
	const char *t_rvalue_type_ir = ffi_map_to_llvm_ir(p_cif->rtype);

	const char *t_avalue_types_ir[p_cif->nargs + 1];
	for (unsigned i = 0; i < p_cif->nargs; ++i)
	{
		t_avalue_types_ir[i] = ffi_map_to_llvm_ir(p_cif->arg_types[i]);
	}

	__MCFfiCallJS(reinterpret_cast<void *>(p_fn), int(p_cif->nargs),
	              x_rvalue, x_avalues,
	              t_rvalue_type_ir, t_avalue_types_ir);
}

/* A libffi closure needs code made at run time, which WebAssembly cannot
 * do, so making one fails. A handler's function pointer (a callback) is a
 * JavaScript function in the function table instead (foundation-handler.cpp). */
extern "C" ffi_status
ffi_prep_closure_loc(ffi_closure *p_closure,
                     ffi_cif *p_cif,
                     void (*p_fun)(ffi_cif *, void *, void **, void *),
                     void *p_user_data,
                     void *p_codeloc)
{
	return FFI_BAD_ABI;
}
