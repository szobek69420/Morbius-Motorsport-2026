[BITS 32]

;vector layout:
;struct{
;  int size;
;  int capacity;
;  int element_size;
;  void* data;
;}

section .data use32
	format db "element size: %d",10,0
	pop_error_message db "vector is empty bozo",10,0
	at_error_message db "vector_at: %d is out of bounds",10,0
	remove_at_error_message db "vector_remove_at: %d is out of bounds",10,0
	
	test_text db "aludj el szepen kicks balazs",10,0

section .text use32
	extern my_malloc
	extern my_realloc
	extern my_free
	extern my_printf
	extern my_memcpy
	extern my_memcmp

	global vector_init			;void vector_init(vector* buffer, int element_size)
	global vector_destroy		;void vector_destroy(vector*)
	global vector_clear			;void vector_clear(vector*)
	global vector_at			;<element>* vector_at(vector*, int index)
	global vector_push_back		;void vector_push_back(vector*, <element> element)
	global vector_push_back_buffer	;void vector_push_back_buffer(vector*, <element>* element)
	global vector_pop_back		;void vector_pop_back(vector*)
	global vector_insert		;void vector_insert(vector*, int index, <element> element)
	global vector_remove_at		;void vector_remove_at(vector*, int index)
	global vector_remove		;int vector_remove(vector*, <element> element)	removes the first matching element. returns 0 if no removal took place, 69 else
	;removes the first matching element. returns 0 if no removal took place, 69 else
	;the comparator must return 0 if a match is found
	global vector_removeCustom	;int vector_removeCustom(vector*, int (*comparator)(element*, void* searchKey), void* searchKey)
	
	;returns the index of the first matching element, otherwise -1 is returned
	;the comparator must return 0 if a match is found
	global vector_search		;int vector_search(vector*, int (*comparator)(element*, void* searchKey), void* searchKey)

	global vector_for_each		;void vector_for_each(vector*, void (*function)(element*, void* param), void* param)

	global vector_size			;int vector_size(vector*)
	global vector_element_size	;int vector_element_size(vector*)

vector_init: ;vector vector_init(element_size)
	push ebp
	mov ebp, esp
	
	;fill up the struct given as a target (vector* as a first parameter basically)
	mov ecx, dword[ebp+8]
	mov dword [ecx], 0 ;size
	mov dword [ecx+4], 1 ;capacity
	mov eax, dword[ebp+12]
	mov dword [ecx+8], eax ;element size
	
	push ecx
	push eax
	call my_malloc
	add esp, 4
	pop ecx
	mov dword[ecx+12], eax ;data
	
	mov eax, 0
	mov esp, ebp
	pop ebp
	ret
	
vector_destroy:		;void vector_destroy(vector* gaynigga)
	push ebp
	mov ebp, esp
	
	mov ecx, dword [ebp+8]
	mov dword [ecx], 0
	mov dword [ecx+4], 0
	mov eax, dword[ecx+12]
	push eax
	mov dword[ecx+12], 0	;set to NULL
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
vector_clear:	;void vector_clear(vector* pacalmaca)
	push ebp
	mov ebp, esp
	
	mov ecx, dword[ebp+8]	;vector* in ecx
	mov dword[ecx], 0		;size=0
	mov dword[ecx+4], 1		;capacity=1
	
	;alloc new data
	push dword[ecx+12]
	call my_free
	add esp, 4
	
	mov ecx, dword[ebp+8]
	push dword[ecx+8]		;element size
	call my_malloc
	mov ecx, dword[ebp+8]
	mov dword[ecx+12],eax		;save the new data*
	
	mov esp, ebp
	pop ebp
	ret
	
	
vector_at:		;<element>* vector_at(vector*, int index)
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;vector* in eax
	mov ecx, dword[eax+12]		;data* in ecx
	mov edx, dword[ebp+12]		;index in edx
	
	;check if index is valid
	cmp edx, 0
	jl _at_index_invalid
	cmp edx,dword[eax]
	jge _at_index_invalid
	jmp _at_index_test_done
	
	_at_index_invalid:
		push eax		;save eax
		push ecx		;save ecx
		push edx	;save edx
		push edx
		mov eax, at_error_message
		push eax
		call my_printf
		add esp,8
		pop edx		;restore edx
		pop ecx		;restore ecx
		pop eax		;restore eax
	
	_at_index_test_done:
	imul edx, dword[eax+8]
	add ecx, edx					;<element>* in ecx
	
	mov eax, ecx
	
	mov esp, ebp
	pop ebp
	ret
	
vector_push_back:	;void vector_push_back(vector* robloxman, element _element) (element is pushed to the stack)
	push ebp
	mov ebp, esp
	
	mov ecx, dword[ebp+8] ;vector* in ecx
	
	mov eax, dword[ecx]		;size
	mov edx, dword[ecx+4]	;capacity
	
	cmp eax, edx
	jl _push_back_no_realloc
	
	imul edx, 2
	mov dword[ecx+4], edx	;new capacity
	
	push ecx	;save ecx
	
	imul edx, dword[ecx+8]	;calculate new size
	push edx
	mov eax, dword[ecx+12]
	push eax
	call my_realloc
	add esp, 8
	pop ecx		;restore ecx
	
	mov dword[ecx+12], eax	;save new data*
	
_push_back_no_realloc:
	mov eax, dword[ecx]
	imul eax, dword[ecx+8]	;offset from data*
	mov edx, dword[ecx+12]
	add edx, eax

	
	mov eax, dword[ecx+8]
	push eax
	lea eax, [ebp+12]
	push eax
	push edx
	call my_memcpy
	add esp, 12
	
	mov eax, dword[ebp+8]
	mov ecx, dword[eax]
	inc ecx
	mov dword[eax],ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
vector_push_back_buffer:
	push ebp
	mov ebp, esp
	
	mov ecx, dword[ebp+8] ;vector* in ecx
	
	mov eax, dword[ecx]		;size
	mov edx, dword[ecx+4]	;capacity
	
	cmp eax, edx
	jl vector_push_back_buffer_no_realloc
	
		imul edx, 2
		mov dword[ecx+4], edx	;new capacity
		
		push ecx	;save ecx
		
		imul edx, dword[ecx+8]	;calculate new size
		push edx
		mov eax, dword[ecx+12]
		push eax
		call my_realloc
		add esp, 8
		pop ecx		;restore ecx
		
		mov dword[ecx+12], eax	;save new data*
		
	vector_push_back_buffer_no_realloc:
	
	mov eax, dword[ecx]
	imul eax, dword[ecx+8]	;offset from data*
	mov edx, dword[ecx+12]
	add edx, eax

	
	mov eax, dword[ecx+8]
	push eax
	push dword[ebp+12]
	push edx
	call my_memcpy
	add esp, 12
	
	mov eax, dword[ebp+8]
	mov ecx, dword[eax]
	inc ecx
	mov dword[eax],ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
vector_pop_back:	;void vector_pop_back(vector* borsodee)
	push ebp
	mov ebp, esp
	
	mov ecx, dword [ebp+8]	;vector* in ecx
	
	;check if size is zero
	mov eax, dword[ecx]
	cmp eax, 0
	jg _pop_back_not_empty
	
	mov eax, pop_error_message
	push eax
	call my_printf
	mov esp, ebp
	pop ebp
	ret
	
_pop_back_not_empty:
	dec dword[ecx]
	
	mov eax, dword[ecx+4]
	shr eax, 1
	cmp eax, dword[ecx]
	jl _pop_back_skip_realloc
	cmp eax, 0
	je _pop_back_skip_realloc
	
	mov dword[ecx+4], eax	;save new capacity
	imul eax, dword[ecx+8]	;calculate new size
	push eax
	mov eax, dword[ecx+12]
	push eax
	call my_realloc
	mov dword[ecx+12], eax
	
_pop_back_skip_realloc:
	mov esp, ebp
	pop ebp
	ret
	
	
vector_insert:			;void vector_insert(vector*, int index, <element> element)
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push eax		;vector* at ebp-4
	
	;check if realloc is necessary
	mov ecx, dword[eax]
	cmp ecx, dword[eax+4]
	jl _insert_realloc_done
	
		;calculate new data* size
		mov edx, dword[eax+4]
		shl edx, 1
		mov dword[eax+4], edx			;save new capacity
		imul edx, dword[eax+8]
		
		
		push edx
		push dword[eax+12]
		call my_realloc
		add esp, 8
		
		mov ecx, dword[ebp-4]
		mov dword[ecx+12],eax		;save new data*
		
	_insert_realloc_done:
	mov eax, dword[ebp-4]			;vector* in eax
	
	;calculate offset of new element
	mov ecx, dword[eax+12]
	mov edx, dword[ebp+12]		;index in edx
	imul edx, dword[eax+8]			;offset in edx
	add ecx, edx
	;calculate the size of the copied data
	mov edx, dword[eax]		;size of vector
	sub edx, dword[ebp+12]	;number of elements to copy
	imul edx, dword[eax+8]		;size copied region
	
	;copy the current data
	push ecx			;store ecx
	
	push edx		;size of copied region
	push ecx			;src*
	add ecx, dword[eax+8]
	push ecx			;dst*
	call my_memcpy
	add esp, 12
	
	pop ecx			;restore ecx
	
	;copy in the new element
	mov eax, dword[ebp-4]
	mov edx, dword[eax+8]	;element size in edx
	push edx
	lea edx, [ebp+16]		;element* in edx
	push edx
	push ecx
	call my_memcpy
	add esp, 12
	
	;increment size
	mov eax, dword[ebp-4]
	mov ecx, dword[eax]
	inc ecx
	mov dword[eax], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	

vector_remove_at:		;void vector_remove_at(vector*, int index)
	push ebp
	mov ebp, esp
	
	sub esp, 4			;new array
	sub esp, 4			;new capacity
	
	;check if the index is valid
	cmp dword[ebp+12], 0
	jl vector_remove_at_bad_index
	mov eax, dword[ebp+8]
	mov ecx, dword[eax]
	cmp dword[ebp+12], ecx
	jge vector_remove_at_bad_index
	jmp vector_remove_at_based_index
	vector_remove_at_bad_index:
		push remove_at_error_message
		call my_printf
		jmp vector_remove_at_end
	vector_remove_at_based_index:
	
	;calculate the new capacity of the vector (newCapacity = max(1, oldSize-1) <= oldCapacity/2 ? oldCapacity/2 : oldCapacity;
	mov eax, dword[ebp+8]
	mov ecx, dword[eax]
	dec ecx
	test ecx, ecx
	jnz vector_remove_at_new_size_is_not_zero
		mov ecx, 1
	vector_remove_at_new_size_is_not_zero:
	mov edx, dword[eax+4]
	shr edx, 1
	cmp ecx, edx
	jle vector_remove_at_capacity_reduced		;the capacity needs to be reduced
		mov edx, dword[eax+4]
	vector_remove_at_capacity_reduced:
	
	mov dword[ebp-8], edx						;save new capacity
	
	;alloc new data array
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-8]
	imul ecx, dword[eax+8]
	push ecx
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;copy the data before the index
	mov ecx, dword[ebp+12]
	cmp ecx, 0
	jle vector_remove_at_copy_before_index_done		;no copy is necessary
		mov eax, dword[ebp+8]
		imul ecx, dword[eax+8]
		push ecx
		push dword[eax+12]
		push dword[ebp-4]
		call my_memcpy
		add esp, 12
	
	vector_remove_at_copy_before_index_done:
	
	;copy the data after the index
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	inc ecx
	cmp ecx, dword[eax]
	jge vector_remove_at_copy_after_index_done
		mov edx, dword[eax]
		sub edx, ecx
		imul edx, dword[eax+8]
		push edx					;elementSize*(size-(index+1))
		
		mov ecx, dword[ebp+12]
		imul ecx, dword[eax+8]
		
		mov edx, dword[eax+12]
		add edx, ecx
		add edx, dword[eax+8]
		push edx
		
		mov edx, dword[ebp-4]
		add edx, ecx
		push edx
		
		call my_memcpy
		add esp, 12
	
	vector_remove_at_copy_after_index_done:
	
	;decrement the size and set the new capacity
	mov eax, dword[ebp+8]
	dec dword[eax]
	mov ecx, dword[ebp-8]
	mov dword[eax+4], ecx
	
	;yeet the previous data array and use the new one
	mov eax, dword[ebp+8]
	push dword[eax+12]
	call my_free
	add esp, 4
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	mov dword[eax+12], ecx
	
	vector_remove_at_end:
	mov esp, ebp
	pop ebp
	ret
	
	
vector_remove:		;int vector_remove(vector*, <element> element)
	push esi
	push edi
	push ebx
	push ebp
	mov ebp, esp
	
	sub esp, 4				;vector*			4
	sub esp, 4				;return value		8
	
	mov eax, dword[ebp+20]
	mov dword[ebp-4], eax
	
	mov dword[ebp-8], 0
	
	
	xor esi, esi
	mov edi, dword[eax+12]		;data* in edi 
	mov ebx, dword[eax+8]		;element size in ebx
	
	mov eax, dword[ebp+20]
	cmp dword[eax], 0
	jle _remove_compare_loop_end		;is the vector empty?
	_remove_compare_loop_start:
		
		push ebx
		push edi
		lea eax, [ebp+24]
		push eax
		call my_memcmp
		add esp, 12
		
		;check if element is found
		test eax, eax
		jnz _remove_compare_loop_continue
			mov dword[ebp-8], 69			;set return value
		
			push esi
			push dword[ebp+20]
			call vector_remove_at
			add esp, 8
			jmp _remove_compare_loop_end
		
		
		_remove_compare_loop_continue:
		add edi, ebx
		inc esi
		mov eax, dword[ebp+20]
		cmp esi, dword[eax]
		jl _remove_compare_loop_start
	_remove_compare_loop_end:
	
	
	mov eax, dword[ebp-8]
	
	mov esp, ebp
	pop ebp
	pop ebx
	pop edi
	pop esi
	ret
	
	
vector_removeCustom:	;int vector_remove(vector*, int (*comparator)(element*, void*), void*)
	push esi
	push edi
	push ebx
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value		4
	
	mov dword[ebp-4], 0
	
	mov eax, dword[ebp+20]
	xor esi, esi
	mov edi, dword[eax+12]		;data* in edi 
	mov ebx, dword[eax+8]		;element size in ebx
	
	cmp dword[eax], 0
	jle vector_removeCustom_compare_loop_end		;is the vector empty?
	vector_removeCustom_compare_loop_start:
		
		push dword[ebp+28]
		push edi
		call dword[ebp+24]
		add esp, 8
		
		;check if element is found
		test eax, eax
		jnz vector_removeCustom_compare_loop_continue
			mov dword[ebp-4], 69			;set return value
		
			push esi
			push dword[ebp+20]
			call vector_remove_at
			add esp, 8
			jmp vector_removeCustom_compare_loop_end
		
		
		vector_removeCustom_compare_loop_continue:
		add edi, ebx
		inc esi
		mov eax, dword[ebp+20]
		cmp esi, dword[eax]
		jl vector_removeCustom_compare_loop_start
	vector_removeCustom_compare_loop_end:
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	pop ebx
	pop edi
	pop esi
	ret


vector_search:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4						;index
	mov dword[ebp-4], -1
	
	xor esi, esi					;loop index in esi
	mov edi, dword[ebp+16]
	cmp dword[edi], 0
	je vector_search_loop_end
	mov edi, dword[edi+12]			;current element in edi
	
	push dword[ebp+24]
	vector_search_loop_start:
		;call the comparator
		push edi
		call dword[ebp+20]
		add esp, 4
		
		;check for a match
		test eax, eax
		jnz vector_search_loop_continue
			mov dword[ebp-4], esi
			jmp vector_search_loop_end
		
		vector_search_loop_continue:
		mov eax, dword[ebp+16]
		add edi, dword[eax+8]
		
		inc esi
		cmp esi, dword[eax]
		jl vector_search_loop_start
		
	vector_search_loop_end:
	
	;set the return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
vector_for_each:	
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	mov eax, dword[ebp+20]
	mov esi, dword[eax+12]		;current element in esi
	mov edi, dword[eax]			;index in edi
	mov ebx, dword[eax+8]		;element size in ebx
	cmp edi, 0
	jle vector_for_each_loop_end
	vector_for_each_loop_start:
		push dword[ebp+28]
		push esi
		call dword[ebp+24]
		add esp, 8
		
		add esi, ebx
		dec edi
		jnz vector_for_each_loop_start
	vector_for_each_loop_end:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
vector_size:
	mov eax, dword[esp+4]
	mov eax, dword[eax]
	ret
	
vector_element_size:
	mov eax, dword[esp+4]
	mov eax, dword[eax+8]
	ret