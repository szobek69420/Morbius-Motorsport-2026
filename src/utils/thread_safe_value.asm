[BITS 32]

;layout
;struct ThreadSafeValue{
;	Mutex* mutex;			;0
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
	
	extern mutex_create
	extern mutex_destroy
	extern mutex_lock
	extern mutex_unlock
	

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
	
	;create mutex
	call mutex_create
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
	
	;destroy mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_destroy
	
	;dealloc tsValue
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_get:
	push ebp
	mov ebp, esp
	
	;lock mutex
	push -1
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_lock
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	lea ecx, [eax+8]
	push ecx
	push dword[ebp+12]
	call my_memcpy
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_set:
	push ebp
	mov ebp, esp
	
	;lock mutex
	push -1
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_lock
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	lea ecx, [ebp+12]
	push ecx
	lea ecx, [eax+8]
	push ecx
	call my_memcpy
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_setBuffer:
	push ebp
	mov ebp, esp
	
	;lock mutex
	push -1
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_lock
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	push dword[ebp+12]
	lea ecx, [eax+8]
	push ecx
	call my_memcpy
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsValue_isEqual:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value of memcmp
	
	;lock mutex
	push -1
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_lock
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	lea ecx, [ebp+12]
	push ecx
	lea ecx, [eax+8]
	push ecx
	call my_memcmp
	mov dword[ebp-4], eax
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
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
	
	;lock mutex
	push -1
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_lock
	
	;copy value
	mov eax, dword[ebp+8]
	push dword[eax+4]
	push dword[ebp+12]
	lea ecx, [eax+8]
	push ecx
	call my_memcmp
	mov dword[ebp-4], eax
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	xor eax, eax
	cmp dword[ebp-4], 0
	jne tsValue_isEqualBuffer_end
		mov eax, 69
	tsValue_isEqualBuffer_end:
	mov esp, ebp
	pop ebp
	ret