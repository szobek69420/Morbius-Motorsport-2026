[BITS 32]

;layout:
;struct Queue{
;	int startIndex;			;0
;	int size;				;4
;	int maxSize;			;8
;	int elementSizeInBytes;	;12
;	element* data;			;16
;};			//overall 20 bytes

section .rodata use32
	print_info db "start index: %d, size: %d, max size: %d, element size: %d",10,0

	error_bad_alloc db "queue_init: queue could not be created",10,0
	error_queue_is_full db "queue_push: queue is full",10,0
	error_queue_is_full_2 db "queue_pushBuffer: queue is full",10,0
	error_queue_is_full_3 db "queue_pushFront: queue is full",10,0
	error_queue_is_full_4 db "queue_pushBufferFront: queue is full",10,0
	error_queue_is_full_5 db "queue_pushArray: there is not enough space bozo",10,0
	error_queue_is_full_6 db "queue_pushArrayFront: there is not enough space bozo",10,0
	error_queue_is_empty db "queue_pop: queue is empty",10,0
	error_invalid_index db "queue_at: % is invalid index, queue size is %d",10,0
	
	test_text db "feliz navidad",10,0

section .text use32

	global queue_init			;void queue_init(queue* buffer, int elementSize, int maxSize)
	global queue_destroy		;void queue_destroy(queue* pqueue)
	
	
	;returns 0 if there were no problems
	global queue_push			;int queue_push(queue* pqueue, element elementToPush)
	
	;returns 0 if there were no problems
	;the element doesn't need to be copied onto the stack
	;the element will be added to the queue, not the pointer of the element
	global queue_pushBuffer		;int queue_pushBuffer(queue* pqueue, element* bufferToPush)
	
	;eturns 0 if there were no problems
	;the elements in the buffer will be added to the queue
	global queue_pushArray		;int queue_pushArray(queue* pqueue, element* arrayOfElement, int elementCount)
	
	;returns 0 if there were no problems
	global queue_pushFront		;int queue_pushFront(queue* pqueue, element elementToPush)
	
	;returns 0 if there were no problems
	;the element doesn't need to be copied onto the stack
	;the element will be added to the queue, not the pointer of the element
	global queue_pushBufferFront;int queue_pushBufferFront(queue* pqueue, element* bufferToPush)
	
	;eturns 0 if there were no problems
	;the elements in the buffer will be added to the queue
	global queue_pushArrayFront		;int queue_pushArrayFront(queue* pqueue, element* arrayOfElements, int elementCount)
	
	;returns 0 if there were no problems
	global queue_pop			;int queue_pop(queue* pqueue, element* nullableBuffer)
	
	;returns 0 if there were no problems
	global queue_peek			;int queue_peek(queue* pqueue, element* buffer)
	
	;index is calculated from the start of the queue, not the start of the allocated element array
	global queue_at				;element* queue_at(queue* pqueue, int index)
	
	global queue_clear			;void queue_clear(queue* pqueue)
	
	global queue_isEmpty		;int queue_isEmpty(queue* pqueue)
	
	global queue_size			;int queue_size(queue* pqueue)
	
	;returns the index of the first matching element, otherwise -1 is returned
	;the comparator must return 0 if a match is found
	global queue_search			;int queue_search(queue* pqueue, int (*comparator)(element*, void* searchKey), void* searchKey)
	
	global queue_forEach		;void queue_forEach(queue* pqueue, void (*function)(element*, void* param), void* param)
	
	global queue_printInfo		;void queue_printInfo(queue* pqueue)
	
	
	extern my_malloc
	extern my_free
	
	extern my_printf
	
	extern my_memcpy

queue_init:
	push ebp
	mov ebp, esp
	
	;set startIndex, size, elementSize and maxSize
	mov eax, dword[ebp+8]
	
	mov dword[eax], 0			;startIndex
	mov dword[eax+4], 0			;size
	mov ecx, dword[ebp+12]
	mov dword[eax+12], ecx		;elementSize
	mov ecx, dword[ebp+16]
	mov dword[eax+8], ecx		;maxSize
	
	;alloc array
	mov eax, dword[ebp+12]
	imul eax, dword[ebp+16]
	push eax
	call my_malloc
	add esp, 4
	mov ecx, dword[ebp+8]
	mov dword[ecx+16], eax
	test eax, eax
	jnz queue_init_malloc_successful
		push error_bad_alloc
		call my_printf
		jmp queue_init_end
	queue_init_malloc_successful:
	
	queue_init_end:
	mov esp, ebp
	pop ebp
	ret
	
	
queue_destroy:
	mov eax, dword[esp+4]
	push dword[eax+16]
	call my_free
	add esp, 4
	ret
	
	
queue_push:
	push ebp
	mov ebp, esp
	
	;check if the queue is not full
	mov eax, dword[ebp+8]
	mov ecx, dword[eax+4]
	cmp ecx, dword[eax+8]
	jl queue_push_not_full
		push error_queue_is_full
		call my_printf
		mov eax, 69
		jmp queue_push_end
	queue_push_not_full:
	
	
	;calculate the destination
	mov eax, dword[ebp+8]
	
	mov ecx, dword[eax]
	add ecx, dword[eax+4]
	cmp ecx, dword[eax+8]
	jl queue_push_no_overflow
		sub ecx, dword[eax+8]
	queue_push_no_overflow:
	
	imul ecx, dword[eax+12]
	add ecx, dword[eax+16]
	
	lea edx, [ebp+12]
	
	push dword[eax+12]			;element size
	push edx					;source
	push ecx					;destination
	call my_memcpy
	
	mov eax, dword[ebp+8]
	inc dword[eax+4]
	
	xor eax, eax
	
	queue_push_end:
	mov esp, ebp
	pop ebp
	ret
	

queue_pushBuffer:
	push ebp
	mov ebp, esp
	
	;check if the queue is not full
	mov eax, dword[ebp+8]
	mov ecx, dword[eax+4]
	cmp ecx, dword[eax+8]
	jl queue_pushBuffer_not_full
		push error_queue_is_full_2
		call my_printf
		mov eax, 69
		jmp queue_pushBuffer_end
	queue_pushBuffer_not_full:
	
	
	;calculate the destination
	mov eax, dword[ebp+8]
	
	mov ecx, dword[eax]
	add ecx, dword[eax+4]
	cmp ecx, dword[eax+8]
	jl queue_pushBuffer_no_overflow
		sub ecx, dword[eax+8]
	queue_pushBuffer_no_overflow:
	
	imul ecx, dword[eax+12]
	add ecx, dword[eax+16]
	
	
	push dword[eax+12]			;element size
	push dword[ebp+12]			;source
	push ecx					;destination
	call my_memcpy
	
	mov eax, dword[ebp+8]
	inc dword[eax+4]			;increment size
	
	xor eax, eax
	
	queue_pushBuffer_end:
	mov esp, ebp
	pop ebp
	ret
	
	
queue_pushArray:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;return value		4
	
	mov dword[ebp-4], 0
	
	;check if the array length is valid
	cmp dword[ebp+28], 0
	jle queue_pushArray_end
	
	;check if there is enough space
	mov eax, dword[ebp+20]
	
	mov ecx, dword[eax+8]
	sub ecx, dword[eax+4]
	cmp ecx, dword[ebp+28]
	jge queue_pushArray_enough_space
		mov dword[ebp-4], 69
	
		push error_queue_is_full_5
		call my_printf
		jmp queue_pushArray_end
	queue_pushArray_enough_space:
	
	;add the elements to the queue
	mov eax, dword[ebp+20]
	mov esi, dword[ebp+24]			;buffer in esi
	mov edi, dword[eax]
	add edi, dword[eax+4]
	cmp edi, dword[eax+8]
	jl queue_pushArray_no_overflow
		sub edi, dword[eax+8]		;target index in edi
	queue_pushArray_no_overflow:
	xor ebx, ebx					;index in ebx
	queue_pushArray_copy_loop_start:
		push eax				;save eax
		
		push dword[eax+12]
		push esi
		mov edx, dword[eax+12]
		imul edx, edi
		add edx, dword[eax+16]
		push edx
		call my_memcpy
		add esp, 12
		
		pop eax					;restore eax
		
		inc edi
		cmp edi, dword[eax+8]
		jl queue_pushArray_copy_loop_no_overflow
			xor edi, edi
		queue_pushArray_copy_loop_no_overflow:
		add esi, dword[eax+12]
		inc ebx
		cmp ebx, dword[ebp+28]
		jl queue_pushArray_copy_loop_start
		
	;update the size
	mov eax, dword[ebp+20]
	mov ecx, dword[ebp+28]
	add dword[eax+4], ecx
		
	queue_pushArray_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
queue_pushFront:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;element index			4
	
	;check if the queue is not full
	mov eax, dword[ebp+8]
	mov ecx, dword[eax+4]
	cmp ecx, dword[eax+8]
	jl queue_pushFront_not_full
		push error_queue_is_full_3
		call my_printf
		mov eax, 69
		jmp queue_pushFront_end
	queue_pushFront_not_full:
	
	
	;calculate the destination index
	mov eax, dword[ebp+8]
	mov ecx, dword[eax]
	dec ecx
	cmp ecx, 0
	jge queue_pushFront_index_not_negative
		add ecx, dword[eax+8]
	queue_pushFront_index_not_negative:
	mov dword[ebp-4], ecx
	
	;copy element
	push dword[eax+12]			;element size in bytes
	lea edx, [ebp+12]
	push edx
	imul ecx, dword[eax+12]
	add ecx, dword[eax+16]
	push ecx
	call my_memcpy
	
	;adjust index and increment size
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp-4]
	mov dword[eax], ecx
	
	inc dword[eax+4]
	
	
	queue_pushFront_end:
	mov esp, ebp
	pop ebp
	ret
	
	
queue_pushBufferFront:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;element index			4
	
	
	;check if the queue is not full
	mov eax, dword[ebp+8]
	mov ecx, dword[eax+4]
	cmp ecx, dword[eax+8]
	jl queue_pushBufferFront_not_full
		push error_queue_is_full_4
		call my_printf
		mov eax, 69

		jmp queue_pushBufferFront_end
	queue_pushBufferFront_not_full:
	
	
	;calculate the destination index
	mov eax, dword[ebp+8]
	mov ecx, dword[eax]
	dec ecx
	cmp ecx, 0
	jge queue_pushBufferFront_index_not_negative
		add ecx, dword[eax+8]
	queue_pushBufferFront_index_not_negative:
	mov dword[ebp-4], ecx
	
	;copy element
	push dword[eax+12]			;element size in bytes
	push dword[ebp+12]
	imul ecx, dword[eax+12]
	add ecx, dword[eax+16]
	push ecx
	call my_memcpy
	
	;adjust index and increment size
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp-4]
	mov dword[eax], ecx
	
	inc dword[eax+4]
	
	
	queue_pushBufferFront_end:
	mov esp, ebp
	pop ebp
	ret
	
	
queue_pushArrayFront:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;return value		4
	
	mov dword[ebp-4], 0
	
	;check if the array length is valid
	cmp dword[ebp+28], 0
	jle queue_pushArrayFront_end
	
	;check if there is enough space
	mov eax, dword[ebp+20]
	
	mov ecx, dword[eax+8]
	sub ecx, dword[eax+4]
	cmp ecx, dword[ebp+28]
	jge queue_pushArrayFront_enough_space
		mov dword[ebp-4], 69
	
		push error_queue_is_full_6
		call my_printf
		jmp queue_pushArrayFront_end
	queue_pushArrayFront_enough_space:
	
	;adjust the start index
	mov eax, dword[ebp+20]
	mov ecx, dword[ebp+28]
	sub dword[eax], ecx
	test dword[eax], 0x80000000
	jz queue_pushArrayFront_no_underflow
		mov ecx, dword[eax+8]
		add dword[eax], ecx
	queue_pushArrayFront_no_underflow:
	
	;add the elements to the queue
	mov eax, dword[ebp+20]
	mov esi, dword[ebp+24]			;buffer in esi
	mov edi, dword[eax]				;target index in edi
	xor ebx, ebx					;index in ebx
	queue_pushArrayFront_copy_loop_start:
		push eax				;save eax
		
		push dword[eax+12]
		push esi
		mov edx, dword[eax+12]
		imul edx, edi
		add edx, dword[eax+16]
		push edx
		call my_memcpy
		add esp, 12
		
		pop eax					;restore eax
		
		inc edi
		cmp edi, dword[eax+8]
		jl queue_pushArrayFront_copy_loop_no_overflow
			xor edi, edi
		queue_pushArrayFront_copy_loop_no_overflow:
		add esi, dword[eax+12]
		inc ebx
		cmp ebx, dword[ebp+28]
		jl queue_pushArrayFront_copy_loop_start
		
	;update the size
	mov eax, dword[ebp+20]
	mov ecx, dword[ebp+28]
	add dword[eax+4], ecx
		
	queue_pushArrayFront_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
queue_pop:
	push ebp
	mov ebp, esp
	
	;check if the queue is not empty
	mov eax, dword[ebp+8]
	cmp dword[eax+4], 0
	jg queue_pop_not_empty
		push error_queue_is_empty
		;call my_printf
		mov eax, 69
		jmp queue_pop_end
	queue_pop_not_empty:
	
	;should the element be saved?
	cmp dword[ebp+12], 0
	je queue_pop_element_not_saved
		;save the element
		mov eax, dword[ebp+8]
		mov ecx, dword[eax]
		imul ecx, dword[eax+12]
		add ecx, dword[eax+16]
		
		push dword[eax+12]
		push ecx
		push dword[ebp+12]
		call my_memcpy
		add esp, 12
	
	queue_pop_element_not_saved:
	;decrease the size of the queue
	mov eax, dword[ebp+8]
	mov ecx, dword[eax]
	inc ecx
	cmp ecx, dword[eax+8]
	jl queue_pop_no_overflow
		xor ecx, ecx
	queue_pop_no_overflow:
	mov dword[eax], ecx				;save the new start index
	
	dec dword[eax+4]				;decrease the size
	
	xor eax, eax
	
	queue_pop_end:
	mov esp, ebp
	pop ebp
	ret
	
queue_peek:
	push ebp
	mov ebp, esp
	
	;check if the queue is not empty
	mov eax, dword[ebp+8]
	cmp dword[eax+4], 0
	jne queue_peek_not_empty
		push error_queue_is_empty
		call my_printf
		mov eax, 69
		jmp queue_peek_end
	queue_peek_not_empty:
	
	;save the element
	mov eax, dword[ebp+8]
	mov ecx, dword[eax]
	imul ecx, dword[eax+12]
	add ecx, dword[eax+16]
	
	push dword[eax+12]
	push ecx
	push dword[ebp+12]
	call my_memcpy
	add esp, 12
	
	xor eax, eax
	
	queue_peek_end:
	mov esp, ebp
	pop ebp
	ret
	
	
queue_at:
	push ebp
	mov ebp, esp
	
	;check if the index is valid
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	cmp ecx, 0
	jl queue_at_invalid_index
	cmp ecx, dword[eax+4]
	jge queue_at_invalid_index
	jmp queue_at_valid_index
	queue_at_invalid_index:
		push dword[eax+4]
		push dword[eax]
		push error_invalid_index
		call my_printf
		xor eax, eax
		jmp queue_at_end
	queue_at_valid_index:
	
	;calculate the address
	add ecx, dword[eax]
	cmp ecx, dword[eax+8]
	jl queue_at_no_overflow
		sub ecx, dword[eax+8]
	queue_at_no_overflow:
	imul ecx, dword[eax+12]
	add ecx, dword[eax+16]
	
	mov eax, ecx
	
	queue_at_end:
	mov esp, ebp
	pop ebp
	ret
	
	
queue_clear:
	mov eax, dword[esp+4]
	mov dword[eax], 0
	mov dword[eax+4], 0
	ret
	
	
queue_isEmpty:
	xor eax, eax
	mov ecx, dword[esp+4]
	cmp dword[ecx+4], 0
	jne queue_isEmpty_end
		mov eax, 69
	
	queue_isEmpty_end:
	ret
	
	
queue_size:
	mov eax, dword[esp+4]
	mov eax, dword[eax+4]
	ret

queue_search:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4					;index
	mov dword[ebp-4], -1
	
	xor esi, esi				;loop index in esi
	mov edi, dword[ebp+16]
	cmp dword[edi+4], 0
	je queue_search_loop_end
	mov eax, dword[edi]
	imul eax, dword[edi+12]
	mov edi, dword[edi+16]
	add edi, eax				;current element in edi
	queue_search_loop_start:
		;call comparator
		push dword[ebp+24]
		push edi
		call dword[ebp+20]
		add esp, 8
		
		;check for match
		test eax, eax
		jnz queue_search_loop_continue
			mov dword[ebp-4], esi
			jmp queue_search_loop_end
		
		queue_search_loop_continue:
		mov eax, dword[ebp+16]
		add edi, dword[eax+12]
		inc esi
		cmp esi, dword[eax+4]
		jge queue_search_loop_end
		
		;check for overflow
		mov ecx, dword[eax+8]
		imul ecx, dword[eax+12]
		add ecx, dword[eax+16]			;queue.data+queue.max_size*queue.element_size
		cmp edi, ecx
		jl queue_search_loop_start
		
		mov edi, dword[eax+16]
		jmp queue_search_loop_start
		
	queue_search_loop_end:
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
queue_forEach:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;check if the queue is empty
	mov eax, dword[ebp+20]
	cmp dword[eax+4], 0
	jle queue_forEach_end
	
	;do for each stuff
	mov esi, dword[eax+16]		;elements in esi
	mov edi, dword[eax]			;current element index in edi
	mov ebx, dword[eax+4]		;index in ebx
	queue_forEach_loop_start:
		mov eax, dword[ebp+20]
		mov ecx, edi
		imul ecx, dword[eax+12]
		add ecx, esi
	
		push dword[ebp+28]
		push ecx
		call dword[ebp+24]
		add esp, 8
	
		inc edi
		mov eax, dword[ebp+20]
		cmp edi, dword[eax+8]
		jl queue_forEach_loop_no_overflow
			sub edi, dword[eax+8]
		queue_forEach_loop_no_overflow:
		
		dec ebx
		test ebx, ebx
		jnz queue_forEach_loop_start
	
	queue_forEach_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
	
queue_printInfo:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push print_info
	call my_printf
	
	mov esp, ebp
	pop ebp
	ret