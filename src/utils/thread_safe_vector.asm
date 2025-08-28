[BITS 32]

;struct tsVector{
;	Mutex* mutex;		0
;	vector* vec;		4
;}	8 bytes overall

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
	
	;returns the index of the first matching element, otherwise -1 is returned
	;the comparator must return 0 if a match is found
	global tsVector_search			;int tsVector_search(tsVector*, int (*comparator)(element*, void* searchKey), void* searchKey)
	
	global tsVector_elementSize	;int tsVector_elementSize(tsVector*)
	
	extern my_malloc
	extern my_realloc
	extern my_free
	extern my_printf
	extern my_memcpy
	extern my_memcmp
	
	extern mutex_create
	extern mutex_destroy
	extern mutex_lock
	extern mutex_unlock
	
	extern vector_init
	extern vector_destroy
	extern vector_clear
	extern vector_at
	extern vector_push_back_buffer
	extern vector_pop_back
	extern vector_insert
	extern vector_remove_at
	extern vector_remove
	extern vector_element_size
	extern vector_search
	
tsVector_init:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;mutex		4
	sub esp, 4		;vector		8
	
	;create mutex
	call mutex_create
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
	push dword[eax]				;mutex
	
	call mutex_destroy
	add esp, 4
	
	call vector_destroy
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_clear:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call clear
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_clear
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_at:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call at
	mov eax, dword[ebp+8]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_at
	mov dword[ebp-4], eax
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_pushBack:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pushBackBuffer
	lea ecx, [ebp+12]
	push ecx
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_push_back_buffer
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_pushBackBuffer:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pushBackBuffer
	mov eax, dword[ebp+8]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_push_back_buffer
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_popBack:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pop back
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_pop_back
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_insert:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
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
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_removeAt:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call remove at
	mov eax, dword[ebp+8]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_remove_at
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_remove:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
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
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call search
	mov eax, dword[ebp+8]
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[eax+4]
	call vector_search
	mov dword[ebp-4], eax
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsVector_elementSize:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;return value		4
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;get element size
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call vector_element_size
	mov dword[ebp-4], eax
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret