[BITS 32]

;struct tsVector{
;	ContainerCriticalSection* sex;	0
;	vector* vec;					4
;}	8 bytes overall

section .rodata use32
	test_text db "kaktuszos royal",10,0
	test_text2 db "kaktuszos royal 2",10,0

section .text use32

	global tsVector_init			;void tsVector_init(tsVector* buffer, int element_size)
	global tsVector_destroy			;void tsVector_destroy(tsVector*)
	global tsVector_clear			;void tsVector_clear(tsVector*)
	global tsVector_at				;<element>* tsVector_at(tsVector*, int index)
	global tsVector_pushBack		;void tsVector_pushBack(tsVector*, <element> element)
	global tsVector_pushBackBuffer	;void tsVector_pushBackBuffer(tsVector*, <element>* element)
	global tsVector_popBack			;void tsVector_popBack(tsVector*)
	global tsVector_insert			;void tsVector_insert(tsVector*, int index, <element> element)
	global tsVector_removeAt		;void tsVector_removeAt(tsVector*, int index)
	global tsVector_remove			;int tsVector_remove(tsVector*, <element> element)	removes the first matching element. returns 0 if no removal took place, 69 else
	;removes the first matching element. returns 0 if no removal took place, 69 else
	;the comparator must return 0 if a match is found
	global tsVector_removeCustom	;int tsVector_removeCustom(tsVector*, int (*comparator)(element*, void* searchKey), void* searchKey)
	
	;returns the index of the first matching element, otherwise -1 is returned
	;the comparator must return 0 if a match is found
	global tsVector_search			;int tsVector_search(tsVector*, int (*comparator)(element*, void* searchKey), void* searchKey)
	
	global tsVector_forEach		;void tsVector_forEach(tsVector*, void (*function)(element*, void* param), void* param)
	
	global tsVector_size					;int tsVector_size(tsVector*)
	global tsVector_sizeNonBlocking			;int tsVector_sizeNonBlocking(tsVector*)
	global tsVector_elementSize				;int tsVector_elementSize(tsVector*)
	
	global tsVector_vector					;vector* tsVector_vector(tsVector*)
	global tsVector_lock					;void tsVector_lock(tsVector*)		//can be unlocked only with an explicit call of tsVector_unlock
	global tsVector_unlock					;void tsVector_unlock(tsVector*)
	
	
	extern my_malloc
	extern my_realloc
	extern my_free
	extern my_printf
	extern my_memcpy
	extern my_memcmp
	
	extern criticalSection_create
	extern criticalSection_destroy
	extern criticalSection_lock
	extern criticalSection_tryLock
	extern criticalSection_unlock
	
	extern vector_init
	extern vector_destroy
	extern vector_clear
	extern vector_at
	extern vector_push_back_buffer
	extern vector_pop_back
	extern vector_insert
	extern vector_remove_at
	extern vector_remove
	extern vector_removeCustom
	extern vector_size
	extern vector_element_size
	extern vector_search
	extern vector_for_each
	
tsVector_init:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;cs			4
	sub esp, 4		;vector		8
	
	;create critical section
	call criticalSection_create
	mov dword[ebp-4], eax
	
	;create vector
	push 16
	call my_malloc
	mov dword[ebp-8], eax
	
	push dword[ebp+12]
	push eax
	call vector_init
	
	;set values in the buffer
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp-4]
	mov dword[eax], ecx
	mov edx, dword[ebp-8]
	mov dword[eax+4], edx
	
	mov esp, ebp
	pop ebp
	ret
	
tsVector_destroy:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax+4]			;vector
	push dword[eax]				;cs
	
	call criticalSection_destroy
	add esp, 4
	
	call vector_destroy
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_clear:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call clear
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_clear
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_at:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call at
	mov eax, dword[ebp+8]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_at
	mov dword[ebp-4], eax
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_pushBack:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call pushBackBuffer
	lea ecx, [ebp+12]
	push ecx
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_push_back_buffer
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_pushBackBuffer:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call pushBackBuffer
	mov eax, dword[ebp+8]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_push_back_buffer
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_popBack:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call pop back
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_pop_back
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_insert:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;copy the element onto the stack
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_element_size
	
	sub esp, eax
	mov ecx, esp
	push eax
	lea edx, [ebp+16]
	push edx
	push ecx
	call my_memcpy
	add esp, 12
	
	;call insert (element data already on stack)
	push dword[ebp+12]			;index
	mov eax, dword[ebp+8]
	push dword[eax+4]			;vector
	call vector_insert
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_removeAt:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call remove at
	mov eax, dword[ebp+8]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_remove_at
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_remove:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;copy the element onto the stack
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_element_size
	
	sub esp, eax
	mov ecx, esp
	push eax
	lea edx, [ebp+12]
	push edx
	push ecx
	call my_memcpy
	add esp, 12
	
	;call remove (element data already on stack)
	mov eax, dword[ebp+8]
	push dword[eax+4]			;vector
	call vector_remove
	mov dword[ebp-4], eax
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_removeCustom:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call removeCustom
	mov eax, dword[ebp+8]
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[eax+4]			;vector
	call vector_removeCustom
	mov dword[ebp-4], eax
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call search
	mov eax, dword[ebp+8]
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_search
	mov dword[ebp-4], eax
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_forEach:
	push ebp
	mov ebp, esp
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;call search
	mov eax, dword[ebp+8]
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_for_each
	mov dword[ebp-4], eax
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
tsVector_size:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;return value		4
	
	;lock
	push dword[ebp+8]
	call tsVector_lock_internal
	
	;get size
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_size
	mov dword[ebp-4], eax
	
	;unlock
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_sizeNonBlocking:
	push ebp
	mov ebp, esp
	
	;get element size
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_size
	
	mov esp, ebp
	pop ebp
	ret
	
tsVector_elementSize:
	push ebp
	mov ebp, esp
	
	;get element size
	;no need to lock mutex, element size should not be changed anyways
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_element_size
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_vector:
	mov eax, dword[esp+4]
	mov eax, dword[eax+4]
	ret
	
tsVector_lock:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call tsVector_lock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_unlock:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call tsVector_unlock_internal
	
	mov esp, ebp
	pop ebp
	ret
	
	
;interanl functinos ---------------------------------------------

;locks the ccs without a special lock in
;void tsVector_lock_internal(tsVector* pvector)
tsVector_lock_internal:
	push ebp
	mov ebp, esp
	
	;tries to lock critical section non-blockingly (also enables repeated lock calls)
	mov eax, dword[ebp+8]
	push dword[eax]
	call criticalSection_tryLock
	test eax, eax
	jnz tsVector_lock_internal_end
	
		;waits for lock blockingly
		call criticalSection_lock
	
	tsVector_lock_internal_end:
	mov esp, ebp
	pop ebp
	ret
	
;unlocks the ccs only if there is no special lock in in place
;void tsVector_unlock_internal(tsVector* pvector)
tsVector_unlock_internal:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call criticalSection_unlock
	
	mov esp, ebp
	pop ebp
	ret