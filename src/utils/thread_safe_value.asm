[BITS 32]

;layout
;struct ThreadSafeValue{
;	CriticalSection* sex;	;0
;	int sizeOfValueInBytes	;4
;	<value_type> value;		;8
;}		//overall sizeof(<value_type>)+8 bytes

section .text use32

	global tsValue_create		;tsValue* tsValue_create(int valueSizeInBytes)
	global tsValue_destroy		;void tsValue_destroy(tsValue* value)
	
	global tsValue_get			;void tsValue_get(tsValue* value, <value_type>* buffer)
	global tsValue_set			;void tsValue_set(tsValue* value, <value_type> data)
	global tsValue_setBuffer	;void tsValue_setBuffer(tsValue* value, <value_type>* pdata)
	
	global tsValue_isEqual		;int tsValue_isEqual(tsValue* value, <value_type> data)
	global tsValue_isEqualBuffer;int tsValue_isEqualBuffer(tsValue* value, <value_type>* pdata)
	
	extern my_malloc
	extern my_free
	extern my_memcpy
	extern my_memcmp
	
	extern criticalSection_create
	extern criticalSection_destroy
	extern criticalSection_lock
	extern criticalSection_tryLock
	extern criticalSection_unlock
	

tsValue_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;tsValue*
	
	;alloc space
	mov eax, dword[ebp+8]
	add eax, 8
	push eax
	call my_malloc
	add esp, 4
	mov dword[ebp-4], eax
	
	;create cs
	call criticalSection_create
	mov ecx, dword[ebp-4]
	mov dword[ecx], eax
	
	;set size
	mov ecx, dword[ebp-4]
	mov edx, dword[ebp+8]
	mov dword[ecx+4], edx
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_destroy:
	push ebp
	mov ebp, esp
	
	;destroy cs
	mov eax, dword[ebp+8]
	push dword[eax]
	call criticalSection_destroy
	
	;dealloc tsValue
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_get:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsValue_lock_internal
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	lea ecx, [eax+8]
	push ecx
	push dword[ebp+12]
	call my_memcpy
	
	;unlock
	push dword[ebp+8]
	call tsValue_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_set:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsValue_lock_internal
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	lea ecx, [ebp+12]
	push ecx
	lea ecx, [eax+8]
	push ecx
	call my_memcpy
	
	;unlock
	push dword[ebp+8]
	call tsValue_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_setBuffer:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsValue_lock_internal
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	push dword[ebp+12]
	lea ecx, [eax+8]
	push ecx
	call my_memcpy
	
	;unlock
	push dword[ebp+8]
	call tsValue_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_isEqual:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value of memcmp
	
	;lock
	push dword[ebp+8]
	call tsValue_lock_internal
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	lea ecx, [ebp+12]
	push ecx
	lea ecx, [eax+8]
	push ecx
	call my_memcmp
	mov dword[ebp-4], eax
	
	;unlock
	push dword[ebp+8]
	call tsValue_unlock_internal
	
	xor eax, eax
	cmp dword[ebp-4], 0
	jne tsValue_isEqual_end
		mov eax, 69
	tsValue_isEqual_end:
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_isEqualBuffer:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value of memcmp
	
	;lock
	push dword[ebp+8]
	call tsValue_lock_internal
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	push dword[ebp+12]
	lea ecx, [eax+8]
	push ecx
	call my_memcmp
	mov dword[ebp-4], eax
	
	;unlock
	push dword[ebp+8]
	call tsValue_unlock_internal
	
	xor eax, eax
	cmp dword[ebp-4], 0
	jne tsValue_isEqualBuffer_end
		mov eax, 69
	tsValue_isEqualBuffer_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;internal functinos	--------------------------------

;void tsValue_lock_internal(tsValue*)
tsValue_lock_internal:
	push ebp
	mov ebp, esp
	
	;tries to lock critical section non-blockingly (also enables repeated lock calls)
	mov eax, dword[ebp+8]
	push dword[eax]
	call criticalSection_tryLock
	test eax, eax
	jnz tsValue_lock_internal_end
	
	;waits for lock blockingly
	call criticalSection_lock
	
	tsValue_lock_internal_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;void tsValue_unlock_internal(tsValue*)
tsValue_unlock_internal:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call criticalSection_unlock
	
	mov esp, ebp
	pop ebp
	ret