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
	error_queue_is_empty db "queue_pop: queue is empty",10,0
	error_invalid_index db "queue_at: % is invalid index, queue size is %d",10,0

section .text use32

	global queue_init			;void queue_init(queue* buffer, int elementSize, int maxSize)
	global queue_destroy		;void queue_destroy(queue* pqueue)
	
	;returns 0 if there were no problems
	global queue_push			;int queue_push(queue* pqueue, element elementToPush)
	;returns 0 if there were no problems
	;the element doesn't need to be copied onto the stack
	;the element will be added to the queue, not the pointer of the element
	global queue_pushBuffer		;int queue_pushBuffer(queue* pqueue, element* bufferToPush)
	;returns 0 if there were no problems
	global queue_pop			;int queue_pop(queue* pqueue, element* nullableBuffer)
	
	;index is calculated from the start of the queue, not the start of the allocated element array
	global queue_at				;element* queue_at(queue* pqueue, int index)
	
	global queue_clear			;void queue_clear(queue* pqueue)
	
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
	inc dword[eax+4]
	
	xor eax, eax
	
	queue_pushBuffer_end:
	mov esp, ebp
	pop ebp
	ret
	
	
queue_pop:
	push ebp
	mov ebp, esp
	
	;check if the queue is not empty
	mov eax, dword[ebp+8]
	cmp dword[eax+4], 0
	jne queue_pop_not_empty
		push error_queue_is_empty
		call my_printf
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