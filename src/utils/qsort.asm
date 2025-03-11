[BITS 32]

section .text use32

	global my_qsort		;void my_qsort(void* base, int elementCount, int elementSizeInBytes, int (*compare)(const void*, const void*))
	
	extern my_memcpy

my_qsort:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4				;pivot index (only used for a short time)			4
	sub esp, 4				;pivot												8
	sub esp, 4				;index of first higher element						12
	sub esp, dword[ebp+28]	;buffer												12+elementSize
	
	mov dword[ebp-12], 0
	
	;is the array too short?
	cmp dword[ebp+24], 2
	jl my_qsort_end
	
	;calculate pivot index
	mov eax, dword[ebp+24]
	shr eax, 1
	mov dword[ebp-4], eax
	
	;put the pivot at the end of the array
	mov ebx, dword[ebp+28]
	neg ebx
	lea ebx, [ebp+ebx-12]			;buffer in ebx
	
	mov esi, dword[ebp+24]
	dec esi
	imul esi, dword[ebp+28]
	add esi, dword[ebp+20]			;array+(elementCount-1)*elementSize in esi
	
	mov edi, dword[ebp-4]
	imul edi, dword[ebp+28]
	add edi, dword[ebp+20]			;array+pivotIndex*elementSize in edi
	
	
	push dword[ebp+28]
	push esi
	push ebx
	call my_memcpy
	add esp, 12
	
	push dword[ebp+28]
	push edi
	push esi
	call my_memcpy
	add esp, 12
	
	push dword[ebp+28]
	push ebx
	push edi
	call my_memcpy
	add esp, 12
	
	;get the pivot
	mov dword[ebp-8], esi
	
	;do sorting stuff
	xor ebx, ebx				;index in ebx
	mov esi, dword[ebp+20]		;current element in esi
	mov edi, esi				;first higher element in edi
	my_qsort_loop_start:
		;check if a swap is necessary
		push dword[ebp-8]			;pivot
		push esi					;current element
		call dword[ebp+32]
		add esp, 8
		
		cmp eax, 0
		jl my_qsort_loop_continue
			;current element is lower than the pivot
			;swap the current element with the first higher element
			push ebx					;save ebx
			
			mov ebx, dword[ebp+28]
			neg ebx
			lea ebx, [ebp+ebx-12]		;buffer in ebx
			
			push dword[ebp+28]
			push esi
			push ebx
			call my_memcpy
			add esp, 8
			
			push edi
			push esi
			call my_memcpy
			add esp, 8
			
			push ebx
			push edi
			call my_memcpy
			add esp, 12
			
			pop ebx						;restore ebx
			
			;increment first higher index and element
			inc dword[ebp-12]
			add edi, dword[ebp+28]
		
		my_qsort_loop_continue:
		add esi, dword[ebp+28]
		
		inc ebx
		mov eax, ebx
		inc eax
		cmp eax, dword[ebp+24]		;i<elementCount-1
		jl my_qsort_loop_start
	
	;put the pivot between the lower and higher elements
	mov ebx, dword[ebp+28]
	neg ebx
	lea ebx, [ebp+ebx-12]		;buffer in ebx
	
	mov esi, dword[ebp+24]
	dec esi
	imul esi, dword[ebp+28]
	add esi, dword[ebp+20]			;array+(elementCount-1)*elementSize in esi
	
	mov edi, dword[ebp-12]
	imul edi, dword[ebp+28]
	add edi, dword[ebp+20]			;array+firstHigherIndex*elementSize in edi
	
	
	push dword[ebp+28]
	push esi
	push ebx
	call my_memcpy
	add esp, 12
	
	push dword[ebp+28]
	push edi
	push esi
	call my_memcpy
	add esp, 12
	
	push dword[ebp+28]
	push ebx
	push edi
	call my_memcpy
	add esp, 12
	
	add esp, dword[ebp+28]			;so that we don't run out of stack space even for chungus variables
	
	;do it many more times
	push dword[ebp+32]				;compare func
	push dword[ebp+28]				;elementSize
	push dword[ebp-12]				;first higher index
	push dword[ebp+20]				;array
	call my_qsort
	add esp, 16
	
	
	
	mov eax, dword[ebp+24]
	sub eax, dword[ebp-12]
	dec eax
	
	mov ecx, dword[ebp-12]
	inc ecx
	imul ecx, dword[ebp+28]
	add ecx, dword[ebp+20]
	
	push dword[ebp+32]				;compare func
	push dword[ebp+28]				;element size
	push eax						;elementCount-firstHigherIndex-1
	push ecx						;array+(firstHigherIndex+1)*elementSize
	call my_qsort
	add esp, 16
	
	
	my_qsort_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret