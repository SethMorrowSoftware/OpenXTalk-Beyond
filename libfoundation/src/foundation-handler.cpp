/* Copyright (C) 2003-2015 LiveCode Ltd.
 
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

#include <foundation.h>
#include <foundation-auto.h>

#include <ffi.h>

#include "foundation-private.h"

////////////////////////////////////////////////////////////////////////////////

MC_DLLEXPORT_DEF
bool MCHandlerCreate(MCTypeInfoRef p_typeinfo, const MCHandlerCallbacks *p_callbacks, void *p_context, MCHandlerRef& r_handler)
{
	MCAssert(MCTypeInfoIsHandler(p_typeinfo));
	MCAssert(p_callbacks != nil);

    // The context data for an MCHandler is stored after the common elements. The
    // start of this is a field 'context' in the struct so we must adjust for its
    // length.
    __MCHandler *self;
    if (!__MCValueCreateExtended(kMCValueTypeCodeHandler,
         /* prevent overflow */  MCMin(p_callbacks -> size - sizeof(self->context),
                                       p_callbacks -> size),
                                 self))
        return false;
    
    MCMemoryCopy(MCHandlerGetContext(self), p_context, p_callbacks -> size);
    
    self->typeinfo = MCValueRetain(p_typeinfo);
	self->closure = nil;
    self->function_ptr = nil;
#ifdef __HAS_MULTIPLE_ABIS__
	self->other_closures = nil;
#endif
    self->callbacks = p_callbacks;
    
    r_handler = self;
    
    return true;
}

MC_DLLEXPORT_DEF
bool MCHandlerInvoke(MCHandlerRef self, MCValueRef *p_arguments, uindex_t p_argument_count, MCValueRef& r_value)
{
	__MCAssertIsHandler(self);
	MCAssert(p_arguments != nil || p_argument_count == 0);
    return self -> callbacks -> invoke(MCHandlerGetContext(self), p_arguments, p_argument_count, r_value);
}

#if defined(TARGET_SUBPLATFORM_ANDROID) && !defined(CROSS_COMPILE_HOST)
struct MCHandlerInvokeTrampolineContext
{
    MCHandlerRef self;
    MCValueRef *p_arguments;
    uindex_t p_argument_count;
    MCValueRef& r_value;
    bool return_value;
};

static void MCHandlerInvokeTrampoline(void *p_context)
{
    auto ctxt = static_cast<MCHandlerInvokeTrampolineContext *>(p_context);
    ctxt->return_value = MCHandlerInvoke(ctxt->self, ctxt->p_arguments, ctxt->p_argument_count, ctxt->r_value);
}
#endif

MC_DLLEXPORT_DEF
bool MCHandlerExternalInvoke(MCHandlerRef self, MCValueRef *p_arguments, uindex_t p_argument_count, MCValueRef& r_value)
{
#if defined(TARGET_SUBPLATFORM_ANDROID) && !defined(CROSS_COMPILE_HOST)
    extern bool MCAndroidIsOnEngineThread(void);
    if (!MCAndroidIsOnEngineThread())
    {
        typedef void (*co_yield_callback_t)(void *);
        extern void co_yield_to_engine_and_call(co_yield_callback_t callback, void *context);
        MCHandlerInvokeTrampolineContext t_context = {self, p_arguments, p_argument_count, r_value, true};
        co_yield_to_engine_and_call(MCHandlerInvokeTrampoline, &t_context);
        return t_context.return_value;
    }
#endif
    return MCHandlerInvoke(self, p_arguments, p_argument_count, r_value);
}

MC_DLLEXPORT_DEF
MCErrorRef MCHandlerTryToInvokeWithList(MCHandlerRef self, MCProperListRef& x_arguments, MCValueRef& r_value)
{
	__MCAssertIsHandler(self);
	__MCAssertIsProperList(x_arguments);
    MCAutoValueRefArray t_args;
    MCAutoProperListRef t_out_args;
    
    if (!t_args . New(MCProperListGetLength(x_arguments)))
        goto error_exit;
    
    for(uindex_t i = 0; i < MCProperListGetLength(x_arguments); i++)
        t_args[i] = MCValueRetain(MCProperListFetchElementAtIndex(x_arguments, i));
    
    if (!MCHandlerInvoke(self, t_args . Ptr(), t_args . Size(), r_value))
        goto error_exit;
    
    if (!t_args . TakeAsProperList(Out(t_out_args)))
        goto error_exit;
    
    MCValueAssign(x_arguments, t_out_args . Take());
    
    return nil;
    
error_exit:
    r_value = nil;
    
    MCErrorRef t_error;
    if (!MCErrorCatch(t_error))
        return nil;
    
    return t_error;
}

MC_DLLEXPORT_DEF
MCErrorRef MCHandlerTryToExternalInvokeWithList(MCHandlerRef self, MCProperListRef& x_arguments, MCValueRef& r_value)
{
    __MCAssertIsHandler(self);
    __MCAssertIsProperList(x_arguments);
    MCAutoValueRefArray t_args;
    MCAutoProperListRef t_out_args;
    
    if (!t_args . New(MCProperListGetLength(x_arguments)))
        goto error_exit;
    
    for(uindex_t i = 0; i < MCProperListGetLength(x_arguments); i++)
        t_args[i] = MCValueRetain(MCProperListFetchElementAtIndex(x_arguments, i));
    
    if (!MCHandlerExternalInvoke(self, t_args . Ptr(), t_args . Size(), r_value))
        goto error_exit;
    
    if (!t_args . TakeAsProperList(Out(t_out_args)))
        goto error_exit;
    
    MCValueAssign(x_arguments, t_out_args . Take());
    
    return nil;
    
error_exit:
    r_value = nil;
    
    MCErrorRef t_error;
    if (!MCErrorCatch(t_error))
        return nil;
    
    return t_error;
}

MC_DLLEXPORT_DEF
void *MCHandlerGetContext(MCHandlerRef self)
{
	__MCAssertIsHandler(self);
    return (void *)self -> context;
}

MC_DLLEXPORT_DEF
const MCHandlerCallbacks *MCHandlerGetCallbacks(MCHandlerRef self)
{
	__MCAssertIsHandler(self);
    return self -> callbacks;
}

////////////////////////////////////////////////////////////////////////////////

static void __exec_closure(ffi_cif *cif, void *ret, void **args, void *user_data)
{
    MCHandlerRef t_handler;
    t_handler = (MCHandlerRef)user_data;
    
    MCTypeInfoRef t_signature;
    t_signature = t_handler -> typeinfo;
    
    // Check the arity of the handler - at the moment we can only handle 16
    // arguments.
    uindex_t t_arity;
    t_arity = MCHandlerTypeInfoGetParameterCount(t_signature);
    if (t_arity > 16)
    {
        MCErrorThrowUnimplemented(MCSTR("closures only supported for handlers with at most 16 parameters"));
        return;
    }
    
    // Check that we can resolve the return type.
    MCTypeInfoRef t_return_type;
    t_return_type = MCHandlerTypeInfoGetReturnType(t_signature);
    
    MCResolvedTypeInfo t_resolved_return_type;
    if (!MCTypeInfoResolve(t_return_type, t_resolved_return_type))
    {
        MCErrorThrowUnboundType(t_return_type);
        return;
    }
    
    // Build the argument list, doing foreign type bridging as necessary.
    MCValueRef t_value_result;
    MCValueRef t_value_args[16];
    uindex_t t_arg_index;
    t_arg_index = 0;
    t_value_result = nil;
    for(t_arg_index = 0; t_arg_index < t_arity; t_arg_index++)
    {
        MCHandlerTypeFieldMode t_mode;
        t_mode = MCHandlerTypeInfoGetParameterMode(t_signature, t_arg_index);
        
        MCTypeInfoRef t_type;
        t_type = MCHandlerTypeInfoGetParameterType(t_signature, t_arg_index);
        
        // We don't support anything other than 'in' mode parameters at the moment.
        if (t_mode != kMCHandlerTypeFieldModeIn)
        {
            MCErrorThrowUnimplemented(MCSTR("closures only support in arguments"));
            goto cleanup;
        }
        
        // Make sure we can resolve the parameter type.
        MCResolvedTypeInfo t_resolved_type;
        if (!MCTypeInfoResolve(t_type, t_resolved_type))
        {
            MCErrorThrowUnboundType(t_type);
            goto cleanup;
        }
        
        // If the parameter type is foreign then we must attempt to bridge it
        // from the passed in type; otherwise we just retain the valueref.
        if (MCTypeInfoIsForeign(t_resolved_type . type))
        {
            const MCForeignTypeDescriptor *t_descriptor;
            t_descriptor = MCForeignTypeInfoGetDescriptor(t_resolved_type . type);
            if (t_descriptor -> defined != nil &&
                !t_descriptor -> defined(args[t_arg_index]))
                t_value_args[t_arg_index] = MCValueRetain(kMCNull);
            else
            {
                if (t_descriptor -> bridgetype != kMCNullTypeInfo)
                {
                    if (!t_descriptor -> doimport(t_descriptor, args[t_arg_index], false, t_value_args[t_arg_index]))
                        goto cleanup;
                }
                else
                {
                    if (!MCForeignValueCreate(t_resolved_type . named_type, args[t_arg_index], (MCForeignValueRef&)t_value_args[t_arg_index]))
                        goto cleanup;
                }
            }
        }
        else
        {
            t_value_args[t_arg_index] = MCValueRetain(*(MCValueRef*)args[t_arg_index]);
        }
    }
    
    // Actually call the LCB handler.
    if (!MCHandlerInvoke(t_handler, t_value_args, t_arity, t_value_result))
        goto cleanup;
    
    // If the return type is not 'void' then we must map the value back
    // appropriately.
    if (t_resolved_return_type . named_type != kMCNullTypeInfo)
    {
        if (MCTypeInfoIsForeign(t_resolved_return_type . type))
        {
            const MCForeignTypeDescriptor *t_descriptor;
            t_descriptor = MCForeignTypeInfoGetDescriptor(t_resolved_return_type . type);
            if (!t_descriptor -> doexport(t_descriptor, t_value_result, false, ret))
                goto cleanup;
        }
        else
        {
            *(MCValueRef *)ret = t_value_result;
            t_value_result = nil;
        }
    }
    
cleanup:
    if (t_value_result != nil)
        MCValueRelease(t_value_result);
    for(uindex_t i = 0; i < t_arg_index; i++)
        MCValueRelease(t_value_args[i]);
}

#if defined(__EMSCRIPTEN__)

/* OXT-Beyond: libffi makes a handler's function pointer by writing code at
 * run time, which WebAssembly cannot do (foundation-ffi-js.cpp). On the web
 * the function pointer is a JavaScript function that the engine adds to its
 * function table instead: called from C, it stores its arguments as a
 * libffi closure is given them, and runs the handler through
 * MCHandlerEmscriptenInvoke. */

#include <emscripten.h>

EM_JS_DEPS(foundation_handler_js,
           "$addFunction,$removeFunction,$stackSave,$stackAlloc,$stackRestore,$getValue,$setValue,$UTF8ToString");

/* The function of the handler <p_handler> with the WebAssembly signature
 * <p_signature> (the return type, then each parameter's: v, i, j, f or d)
 * and the libffi layout <p_cif> */
EM_JS(void *, __MCHandlerEmscriptenCreateFunction, (const char *p_signature, void *p_cif, void *p_handler), {
	var signature = UTF8ToString(p_signature);
	var types = { 'i': 'i32', 'j': 'i64', 'f': 'float', 'd': 'double' };
	var func = function() {
		// An 8-byte slot for each argument, the array of their addresses,
		// and 8 bytes for the result, on the C stack
		var count = signature.length - 1;
		var stack = stackSave();
		try {
			var slots = stackAlloc(count * 12 + 16);
			var argv = slots + count * 8;
			var result = (argv + count * 4 + 7) & ~7;
			for (var i = 0; i < count; i++) {
				setValue(slots + i * 8, arguments[i], types[signature[i + 1]]);
				setValue(argv + i * 4, slots + i * 8, '*');
			}
			setValue(result, 0, 'i64');
			_MCHandlerEmscriptenInvoke(p_cif, result, argv, p_handler);
			if (signature[0] != 'v') {
				return getValue(result, types[signature[0]]);
			}
		} finally {
			stackRestore(stack);
		}
	};
	return addFunction(func, signature);
});

EM_JS(void, __MCHandlerEmscriptenDestroyFunction, (void *p_function), {
	removeFunction(p_function);
});

/* The code of a WebAssembly type for libffi's <p_type> */
static bool __MCHandlerEmscriptenTypeCode(ffi_type *p_type, bool p_is_return, char& r_code)
{
    switch (p_type->type)
    {
        case FFI_TYPE_VOID:
            r_code = 'v';
            return p_is_return;
        case FFI_TYPE_INT:
        case FFI_TYPE_UINT8:
        case FFI_TYPE_SINT8:
        case FFI_TYPE_UINT16:
        case FFI_TYPE_SINT16:
        case FFI_TYPE_UINT32:
        case FFI_TYPE_SINT32:
        case FFI_TYPE_POINTER:
            r_code = 'i';
            return true;
        case FFI_TYPE_UINT64:
        case FFI_TYPE_SINT64:
            r_code = 'j';
            return true;
        case FFI_TYPE_FLOAT:
            r_code = 'f';
            return true;
        case FFI_TYPE_DOUBLE:
            r_code = 'd';
            return true;
        default:
            // Structures and long doubles
            return false;
    }
}

/* Runs the handler <p_handler> with the arguments <p_args>, as a libffi
 * closure does, putting its result in <x_ret>: an integer smaller than a word
 * is returned in a whole word */
extern "C" EMSCRIPTEN_KEEPALIVE
void MCHandlerEmscriptenInvoke(ffi_cif *p_cif, void *x_ret, void **p_args, void *p_handler)
{
    union
    {
        uint64_t word;
        double real;
        void *pointer;
    } t_value;
    t_value.word = 0;

    __exec_closure(p_cif, &t_value, p_args, p_handler);

    switch (p_cif->rtype->type)
    {
        case FFI_TYPE_VOID:
            break;
        case FFI_TYPE_UINT8:
            *(uint32_t *)x_ret = *(uint8_t *)&t_value;
            break;
        case FFI_TYPE_SINT8:
            *(int32_t *)x_ret = *(int8_t *)&t_value;
            break;
        case FFI_TYPE_UINT16:
            *(uint32_t *)x_ret = *(uint16_t *)&t_value;
            break;
        case FFI_TYPE_SINT16:
            *(int32_t *)x_ret = *(int16_t *)&t_value;
            break;
        default:
            MCMemoryCopy(x_ret, &t_value, MCMin(p_cif->rtype->size, sizeof(t_value)));
            break;
    }
}

/* The function pointer of the handler <self>, whose layout is <p_cif> */
static bool __MCHandlerEmscriptenFunctionPtr(MCHandlerRef self, ffi_cif *p_cif, void*& r_function_ptr)
{
    // As __exec_closure, at most 16 parameters
    char t_signature[18];
    if (p_cif->nargs > 16 ||
        !__MCHandlerEmscriptenTypeCode(p_cif->rtype, true, t_signature[0]))
        return MCErrorThrowGeneric(MCSTR("this handler type cannot be a function pointer on the web"));
    for (unsigned i = 0; i < p_cif->nargs; i++)
    {
        if (!__MCHandlerEmscriptenTypeCode(p_cif->arg_types[i], false, t_signature[i + 1]))
            return MCErrorThrowGeneric(MCSTR("this handler type cannot be a function pointer on the web"));
    }
    t_signature[p_cif->nargs + 1] = '\0';

    r_function_ptr = __MCHandlerEmscriptenCreateFunction(t_signature, p_cif, self);
    if (r_function_ptr == nil)
        return MCErrorThrowOutOfMemory();
    return true;
}

#endif

#if defined(__ANDROID__)

/* For some reason the current version / config of libffi on newer versions of
 * android fails to generate closure trampolines in memory with the exec bit
 * set. To work-around this we set the exec bit of the memory page containing
 * the function ptr directly. */

#include <sys/mman.h>

static bool ensure_block_is_executable(void *p_block, size_t p_size)
{
    /* Round the start of the block pointer down to the nearest page. */
    byte_t *t_start_page = (byte_t *)(((uintptr_t)p_block) & ~4095);
    
    /* Round the end of the block pointer up to the nearest page. */
    byte_t *t_finish_page = (byte_t *)((((uintptr_t)p_block + p_size) + 4095) & ~4095);
    
    /* Change the protection flags of the page range to read/write/exec. */
    return mprotect(t_start_page,
                    t_finish_page - t_start_page,
                    PROT_READ|PROT_EXEC|PROT_WRITE) == 0;
}

#else

/* Other platforms do not need any explicit action as libffi works correctly. */

static bool ensure_block_is_executable(void *p_block, size_t p_size)
{
    return true;
}

#endif

MC_DLLEXPORT_DEF
bool MCHandlerGetFunctionPtrWithAbi(MCHandlerRef self, MCHandlerAbiKind p_abi_kind, void*& r_function_ptr)
{
	__MCAssertIsHandler(self);

	ffi_abi t_abi;
#ifdef __HAS_MULTIPLE_ABIS__
	switch (p_abi_kind)
	{
	case kMCHandlerAbiDefault:
		t_abi = FFI_DEFAULT_ABI;
		break;
	case kMCHandlerAbiStdCall:
		t_abi = FFI_STDCALL;
		break;
	case kMCHandlerAbiThisCall:
		t_abi = FFI_THISCALL;
		break;
	case kMCHandlerAbiFastCall:
		t_abi = FFI_FASTCALL;
		break;
	case kMCHandlerAbiCDecl:
		t_abi = FFI_MS_CDECL;
		break;
	case kMCHandlerAbiPascal:
		t_abi = FFI_PASCAL;
		break;
	case kMCHandlerAbiRegister:
		t_abi = FFI_REGISTER;
		break;
	default:
		return MCErrorThrowGeneric(MCSTR("invalid abi specified"));
	};
#else
	t_abi = FFI_DEFAULT_ABI;
#endif

	/* If the ABI is default, and there is a function ptr in the main slot, then
	 * return it. */
	if (t_abi == FFI_DEFAULT_ABI &&
			self->function_ptr != nil)
	{
		r_function_ptr = self->function_ptr;
		return true;
	}

#ifdef __HAS_MULTIPLE_ABIS__
	/* If there are auxiliary closures then search for one with a matching ABI
	 * and return it, if found. */
	if (self->other_closures != nil)
	{
		for (__MCHandlerClosureWithAbi *t_closure_with_abi = self->other_closures;
				t_closure_with_abi != nil;
				t_closure_with_abi = t_closure_with_abi->next)
		{
			if (t_closure_with_abi->abi == t_abi)
			{
				r_function_ptr = t_closure_with_abi->function_ptr;
				return true;
			}
		}
	}
#endif

	ffi_cif *t_cif;
	if (!MCHandlerTypeInfoGetLayoutType(self->typeinfo, t_abi, (void*&)t_cif))
		return false;

#if defined(__EMSCRIPTEN__)
	/* OXT-Beyond: the web has one ABI, and no libffi closures */
	if (!__MCHandlerEmscriptenFunctionPtr(self, t_cif, self->function_ptr))
		return false;
	r_function_ptr = self->function_ptr;
	return true;
#endif

	void *t_closure, *t_function_ptr;
	t_closure = ffi_closure_alloc(sizeof(ffi_closure), &t_function_ptr);
	if (t_closure == nil)
		return MCErrorThrowOutOfMemory();

	if (ffi_prep_closure_loc((ffi_closure *)t_closure, t_cif, __exec_closure, self, t_function_ptr) != FFI_OK)
	{
		ffi_closure_free(t_closure);
		return MCErrorThrowGeneric(MCSTR("unexpected libffi failure"));
	}

	/* Change the protection flags of the page range to read/write/exec. */
	if (!ensure_block_is_executable(t_closure,
									sizeof(ffi_closure)))
	{
		ffi_closure_free(t_closure);
		return MCErrorThrowGeneric(MCSTR("unable to generate executable closure trampoline"));
	}

	/* We now have a closure and function ptr, if it is of default ABI we store
	 * it in the value struct. */
	if (t_abi == FFI_DEFAULT_ABI)
	{
		self->closure = t_closure;
		self->function_ptr = t_function_ptr;
	}

#ifdef __HAS_MULTIPLE_ABIS__
	/* If the ABI is non-default then we must link it into the closures list. */
	if (t_abi != FFI_DEFAULT_ABI)
	{
		__MCHandlerClosureWithAbi *t_closure_with_abi;
		if (!MCMemoryNew(t_closure_with_abi))
		{
			ffi_closure_free(t_closure);
			return MCErrorThrowOutOfMemory();
		}

		t_closure_with_abi->next = self->other_closures;
		t_closure_with_abi->abi = t_abi;
		t_closure_with_abi->closure = t_closure;
		t_closure_with_abi->function_ptr = t_function_ptr;
		self->other_closures = t_closure_with_abi;
	}
#endif

	/* We've now stored the generated closure and function ptr so return the
	 * requested one. */
	r_function_ptr = t_function_ptr;
	return true;
}

MC_DLLEXPORT_DEF
bool MCHandlerGetFunctionPtr(MCHandlerRef self, void*& r_function_ptr)
{
	return MCHandlerGetFunctionPtrWithAbi(self, kMCHandlerAbiDefault, r_function_ptr);
}

////////////////////////////////////////////////////////////////////////////////

void __MCHandlerDestroy(__MCHandler *self)
{
#if defined(__EMSCRIPTEN__)
    /* OXT-Beyond: the function that stood for the handler on the web */
    if (self -> function_ptr != nil)
        __MCHandlerEmscriptenDestroyFunction(self -> function_ptr);
#else
    if (self -> function_ptr != nil)
        ffi_closure_free(self -> closure);
#endif

#ifdef __HAS_MULTIPLE_ABIS__
	/* Free any closures created with the non-default ABI. */
	while (self->other_closures != nil)
	{
		__MCHandlerClosureWithAbi *t_closure_with_abi = self->other_closures;
		self->other_closures = self->other_closures->next;
		ffi_closure_free(t_closure_with_abi->closure);
		MCMemoryDelete(t_closure_with_abi);
	}
#endif
}

hash_t __MCHandlerHash(__MCHandler *self)
{
    return MCHashPointer(self);
}

bool __MCHandlerIsEqualTo(__MCHandler *self, __MCHandler *other_self)
{
    return self == other_self;
}

bool __MCHandlerCopyDescription(__MCHandler *self, MCStringRef& r_desc)
{
	if (NULL != self->callbacks->describe)
		return self->callbacks->describe(MCHandlerGetContext (self), r_desc);

	/* Default implementation. */
	/* FIXME Should include information about arguments and return
	 * values, extracted from the handler's typeinfo. */
	return MCStringCopy(MCSTR("<handler>"), r_desc);
}

////////////////////////////////////////////////////////////////////////////////
