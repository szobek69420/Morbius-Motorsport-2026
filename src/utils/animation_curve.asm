[BITS 32]

;struct AnimationCurve{
;	vector<struct{float key, float value, float param}> points;		0 //param is used if an additional parameter is necessary (e.g. velocity in case of hermite)
;	int interpolationType;		16	//linear by default
;	int minKey, maxKey;			20
;}	28 bytes overall

section .rodata use32
	INTERPOLATION_LINEAR dd 0
	INTERPOLATION_BEZIER dd 1
	INTERPOLATION_HERMITE dd 2
	
	global INTERPOLATION_LINEAR
	global INTERPOLATION_BEZIER
	global INTERPOLATION_HERMITE

section .text use32
	
	global animationCurve_create			;AnimationCurve* animationCurve_create()
	global animationCurve_destroy			;void animationCurve_destroy(AnimationCurve*)
	
	;pushes the return value onto the FPU stack
	;float animationCurve_sample(AnimationCurve* curve, float i)
	global animationCurve_sample
	
	global animationCurve_setInterpolation	;void animationCurve_setInterpolation(AnimationCurve*, int iType)
	
	;inserts a new entry based on the value of the key
	;no duplicate keys are allowed
	;the place of the entry is chosen so that the keys are in an ascending order
	;void animationCurve_add(AnimationCurve* curve, float key, float value, float param)
	global animationCurve_add
	
	;void animationCurve_removeByKey(AnimationCurve* curve, float key)
	global animationCurve_removeByKey
	
	;void animationCurve_removeByIndex(AnimationCurve* curve, int index)
	global animationCurve_removeByIndex
	
	
	global animationCurve
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern vector_init
	extern vector_destroy
	extern vector_insert
	extern vector_remove_at
	extern vector_removeCustom
	extern vector_search
	
animationCurve_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;curve			4
	
	push 28
	call my_malloc
	mov dword[ebp-4], eax
	
	push 12
	push eax
	call vector_init
	
	mov eax, dword[ebp-4]
	mov ecx, dword[INTERPOLATION_LINEAR]
	mov dword[eax+16], ecx
	mov dword[eax+20], 0
	mov dword[eax+24], 0
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
animationCurve_destroy:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call vector_destroy
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
animationCurve_sample:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	cmp dword[eax], 0
	jg animationCurve_sample_not_empty
		fldz
		jmp animationCurve_sample_end
	animationCurve_sample_not_empty:
	cmp dword[eax], 1
	jg animationCurve_sample_multiple_entries
		mov ecx, dword[eax+12]
		fld dword[ecx+4]
		jmp animationCurve_sample_end
	animationCurve_sample_multiple_entries:
	
	;check if the i is out of the range of the keys
	mov eax, dword[ebp+8]
	movss xmm0, dword[ebp+12]
	ucomiss xmm0, dword[eax+20]
	ja animationCurve_sample_i_is_above_min
		mov ecx, dword[eax+12]
		fld dword[ecx+4]
		jmp animationCurve_sample_end
		
	animationCurve_sample_i_is_above_min:
	
	ucomiss xmm0, dword[eax+24]
	jb animationCurve_smaple_i_is_below_max
		mov ecx, dword[eax]
		dec ecx
		imul ecx, 12
		add ecx, dword[eax+12]
		fld dword[ecx+4]
		jmp animationCurve_sample_end
		
	animationCurve_smaple_i_is_below_max:
	
	;call the chosen sampler
	mov eax, dword[ebp+8]
	mov eax, dword[eax+16]
	cmp eax, dword[INTERPOLATION_BEZIER]
	je animationCurve_sample_bezier
	cmp eax, dword[INTERPOLATION_HERMITE]
	je animationCurve_sample_hermite
		;linear interpolation
		push dword[ebp+12]
		push dword[ebp+8]
		call animationCurve_sampleLinear_internal
		jmp animationCurve_sample_end
		
	animationCurve_sample_bezier:
		;bezier interpolation
		push dword[ebp+12]
		push dword[ebp+8]
		call animationCurve_sampleBezier_internal
		jmp animationCurve_sample_end
		
	animationCurve_sample_hermite:
		;hermite interpolation
		push dword[ebp+12]
		push dword[ebp+8]
		call animationCurve_sampleHermite_internal
		jmp animationCurve_sample_end
	
	animationCurve_sample_end:
	mov esp, ebp
	pop ebp
	ret
	
	
animationCurve_setInterpolation:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	mov dword[eax+16], ecx
	ret
	
	
animationCurve_add:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;index of new key		4
	mov dword[ebp-4], 0
	
	;check if the key already exists
	push dword[ebp+24]
	push animationCurve_add_search_comparator
	push dword[ebp+20]
	call vector_search
	cmp eax, -1
	je animationCurve_add_not_registered
	
	push dword[ebp+24]
	push animationCurve_add_error_already_registered
	call my_printf
	jmp animationCurve_add_end
	
		;int animationCurve_add_search_comparator(struct{float,float,float}* pelement, float key)
		animationCurve_add_search_comparator:
			mov eax, dword[esp+8]
			mov ecx, dword[esp+4]
			sub eax, dword[ecx]
			ret
		
		animationCurve_add_error_already_registered db "animationCurve_add: The key %f is already registered",10,0
	
	animationCurve_add_not_registered:
	
	;determine the index of the new key
	movss xmm0, dword[ebp+24]
	mov ebx, dword[ebp+20]
	mov esi, dword[ebx+12]		;current entry in esi
	xor edi, edi				;index in edi
	cmp dword[ebx], 0
	jle animationCurve_add_loop_end
	animationCurve_add_loop_start:
		ucomiss xmm0, dword[esi]
		jb animationCurve_add_loop_end
		
		add esi, 12
		inc edi
		cmp edi, dword[ebx]
		jl animationCurve_add_loop_start
		
	animationCurve_add_loop_end:
	mov dword[ebp-4], edi
	
	;register the new entry
	push dword[ebp+32]
	push dword[ebp+28]
	push dword[ebp+24]
	push dword[ebp-4]
	push dword[ebp+20]
	call vector_insert
	
	animationCurve_add_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
animationCurve_removeByKey:
	push ebp
	mov ebp, esp
	
	push dword[ebp+12]
	push animationCurve_removeByKey_comparator
	push dword[ebp+8]
	call vector_removeCustom
	test eax, eax
	jnz animationCurve_removeByKey_end
		push dword[ebp+12]
		push animationCurve_removeByKey_error_not_found
		call my_printf
		jmp animationCurve_removeByKey_end
		
		animationCurve_removeByKey_error_not_found db "animationCurve_removeByKey: No entry is registered with a key of %f",10,0
	animationCurve_removeByKey_end:
	mov esp, ebp
	pop ebp
	ret
	;int animationCurve_removeByKey_comparator(struct{float,float,float}* pelement, float key)
	animationCurve_removeByKey_comparator:
		mov eax, dword[esp+8]
		mov ecx, dword[esp+4]
		sub eax, dword[ecx]
		ret
		
		
animationCurve_removeByIndex:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	test ecx, 0x80000000
	jnz animationCurve_removeByIndex_error
	cmp ecx, dword[eax]
	jge animationCurve_removeByIndex_error
	
	push ecx
	push eax
	call vector_remove_at
	jmp animationCurve_removeByIndex_end
	
	animationCurve_removeByIndex_error:
		mov eax, dword[ebp+8]
		push dword[eax]
		push dword[ebp+12]
		push animationCurve_removeByIndex_error_invalid_index
		call my_printf
		jmp animationCurve_removeByIndex_end
		
		animationCurve_removeByIndex_error_invalid_index db "animationCurve_removeByIndex: %d is not a valid index (there are %d entries in the curve)",10,0
	
	animationCurve_removeByIndex_end:
	mov esp, ebp
	pop ebp
	ret
	

	
;internal functinos	--------------------------------------

;void animationCurve_recalculateLimits_internal(AnimationCurve*)
animationCurve_recalculateLimits_internal:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;min key
	sub esp, 4			;max key
	
	mov dword[ebp-4], 0x7f7fffff
	mov dword[ebp-8], 0xff7fffff
	
	mov eax, dword[ebp+16]
	cmp dword[eax], 0
	jg animationCurve_recalculateLimits_internal_not_empty
		mov dword[eax+20], 0
		mov dword[eax+24], 0
		jmp animationCurve_recalculateLimits_internal_end
		
	animationCurve_recalculateLimits_internal_not_empty:
	
	mov eax, dword[ebp+16]
	mov esi, dword[eax+12]			;current element in esi
	mov edi, dword[eax]				;index in edi
	movss xmm0, dword[ebp-4]		;min in xmm0
	movss xmm1, dword[ebp-8]		;max in xmm1
	animationCurve_recalculateLimits_internal_loop_start:
		minss xmm0, dword[esi]
		maxss xmm1, dword[edi]
	
		add esi, 12
		dec edi
		jnz animationCurve_recalculateLimits_internal_loop_start
		
	mov eax, dword[ebp+16]
	movss dword[eax+20], xmm0
	movss dword[eax+24], xmm1
	
	animationCurve_recalculateLimits_internal_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
;curve needs to have at least 2 entries
;i must be in (minKey; maxKey)
;pushes the return value onto the FPU stack
;float animationCurve_sampleLinear_internal(AnimationCurve* curve, float i)
animationCurve_sampleLinear_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;index of lower entry	4
	mov dword[ebp-4], -1
	
	;search for the entry index
	mov ebx, dword[ebp+20]
	mov esi, dword[ebx+12]
	movss xmm0, dword[ebp+24]
	animationCurve_sampleLinear_internal_index_loop_start:		
		ucomiss xmm0, dword[esi]
		jb animationCurve_sampleLinear_internal_index_loop_end
		
		inc dword[ebp-4]
		add esi, 12
		jmp animationCurve_sampleLinear_internal_index_loop_start
		
	animationCurve_sampleLinear_internal_index_loop_end:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret