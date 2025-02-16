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
	global vector_pop_back		;void vector_pop_back(vector*)
	global vector_insert		;void vector_insert(vector*, int index, <element> element)
	global vector_remove_at		;void vector_remove_at(vector*, int index)
	global vector_remove		;int vector_remove(vector*, <element> element)	removes the first matching element. removes 0 if no removal took place, 69 else

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
	
	mov ecx, dword [ebp+8] ;vector* in ecx
	
	mov eax, dword[ecx]	;size
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
	
	mov eax, dword[ebp+8]	;vector* in eax
	push eax					;vector* at ebp-4
	
	;check if index is valid
	mov ecx, dword[ebp+12]
	cmp ecx, dword[eax]
	jge _remove_at_index_invalid
	cmp ecx, 0
	jl _remove_at_index_invalid	
	jmp _remove_at_index_valid
	_remove_at_index_invalid:
		mov esp, ebp
		pop ebp
		ret
	_remove_at_index_valid:

	;calculate dst*
	mov ecx, dword[ebp+12]		;index in ecx
	imul ecx, dword[eax+8]
	add ecx, dword[eax+12]
	
	;calculate copy size
	mov edx, dword[eax]
	sub edx, dword[ebp+12]
	dec edx
	imul edx, dword[eax+8]
	
	;relocate things
	push edx		;push copy size
	sub esp, 4		;alloc space for src*
	push ecx			;push dst*
	add ecx, dword[eax+8]
	mov dword[esp+4], ecx		;push the real src*
	call my_memcpy
	add esp, 12
	
	;decrement size
	mov eax, dword[ebp-4]
	mov ecx, dword[eax]
	dec ecx
	mov dword[eax], ecx
	
	;check if realloc is necessary
	mov ecx, dword[eax+4]
	shr ecx, 1
	cmp ecx, 0
	je _remove_at_realloc_done
	cmp ecx, dword[eax]
	jl _remove_at_realloc_done
	
	;calculate new size
	mov dword[eax+4], ecx		;save new capacity
	imul ecx, dword[eax+8]
	mov edx, dword[eax+12]
	
	push eax		;save vector*
	push ecx
	push edx
	call my_realloc
	add esp,8
	pop ecx		;restore vector*
	
	mov dword[ecx+12],eax		;save new data*
	
	_remove_at_realloc_done:
	mov esp, ebp
	pop ebp
	ret
	
	
vector_remove:		;int vector_remove(vector*, <element> element)
	push esi
	push edi
	push ebx
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+20]	;vector* in eax
	push eax					;vector* at ebp-4
	
	mov esi, dword[eax]		;size in esi
	mov edi, dword[eax+12]	;data* in edi 
	mov ebx, dword[eax+8]		;element size in ebx
	
	_remove_compare_loop_start:
		cmp esi, 0
		jle _remove_compare_loop_end
		
		push ebx
		push edi
		lea eax, [ebp+24]
		push eax
		call my_memcmp
		add esp, 12
		
		;check if element is found
		cmp eax, 0
		jne _remove_compare_loop_condition_end
		mov eax, dword[ebp-4]
		mov ecx, dword[eax]			;size in ecx
		sub ecx, esi				;index to delete in ecx
		push ecx
		push eax
		call vector_remove_at
		add esp, 8
		jmp _remove_compare_loop_end
		
		
		_remove_compare_loop_condition_end:
		dec esi
		add edi, ebx
		jmp _remove_compare_loop_start
	_remove_compare_loop_end:
	
	mov esp, ebp
	pop ebp
	pop ebx
	pop edi
	pop esi
	ret
