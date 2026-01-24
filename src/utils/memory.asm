[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro


section .rodata use32
	my_memset_dword_error_1 db "my_memset_dword: The number of bytes is not divisible by 4",10,0

	my_malloc_error_1 db "my_malloc: Where heap",10,0

section .data use32
	heap_handle dd 0			;0 if there is no heap or it hasn't been queried yet

section .text use32

	global my_memcpy			;void my_memcpy(void* dst, void* src, int numberOfBytes)
	
	global my_memset			;void my_memset(void* mem, int(!!!) byteValue, int numberOfBytes)		;the last byte of the value will be berucksichtingt
	global my_memset_dword		;void my_memset_dword(void* mem, int dwordValue, int numberOfBytes)		;the number of bytes shall be divisible by 4
	
	global my_memcmp			;int my_memcmp(void* m1, void* m2, int byteCount)
	
	global my_malloc			;void* my_malloc(int numberOfBytes)
	global my_realloc			;void* my_realloc(void* org, int newNumberOfBytes)
	global my_free				;void my_free(void* mem2yeet)
	
	extern my_printf
	
	dll_import kernel32.dll, GetProcessHeap
	dll_import kernel32.dll, HeapAlloc
	dll_import kernel32.dll, HeapReAlloc
	dll_import kernel32.dll, HeapFree
	
my_memcpy:
	push ebp
	mov ebp, esp
	
	;is the memory region of the length of zero bytes?
	mov eax, dword[ebp+16]
	cmp eax, 0
	jle my_memcpy_end
	
	;should the copy start from the front or back
	mov eax, dword[ebp+8]
	cmp eax, dword[ebp+12]
	ja my_memcpy_copy_back_to_front		;so that it handles overlapping memory regions as well
	
	my_memcpy_copy_front_to_back:
		mov eax, dword[ebp+8]				;dst in eax
		mov ecx, dword[ebp+12]				;src in ecx
		mov edx, dword[ebp+16]				;byteNum in edx
		
		push ebx
		my_memcpy_copy_front_to_back_loop_start:
			mov bl, byte[ecx]
			mov byte[eax], bl
			
			inc eax
			inc ecx
			dec edx
			test edx, edx
			jnz my_memcpy_copy_front_to_back_loop_start
		pop ebx
		
		jmp my_memcpy_end
	
	my_memcpy_copy_back_to_front:
		mov eax, dword[ebp+8]				;dst in eax
		mov ecx, dword[ebp+12]				;src in ecx
		mov edx, dword[ebp+16]				;byteNum in edx
		
		add eax, edx
		dec eax
		add ecx, edx
		dec ecx
		
		push ebx
		my_memcpy_copy_back_to_front_loop_start:
			mov bl, byte[ecx]
			mov byte[eax], bl
			
			dec eax
			dec ecx
			dec edx
			test edx, edx
			jnz my_memcpy_copy_back_to_front_loop_start
		pop ebx
	
	
	my_memcpy_end:
	mov esp, ebp
	pop ebp
	ret
	
	
my_memset:
	push ebp
	mov ebp, esp
	
	;is the number of bytes zero?
	cmp dword[ebp+16], 0
	jle my_memset_end
	
	mov eax, dword[ebp+8]		;mem in eax
	mov ecx, dword[ebp+12]		;value in cl
	mov edx, dword[ebp+16]		;byteNum in edx
	my_memset_loop_start:
		mov byte[eax], cl
		
		inc eax
		dec edx
		test edx, edx
		jnz my_memset_loop_start
	
	my_memset_end:
	mov esp, ebp
	pop ebp
	ret
	

my_memset_dword:
	push ebp
	mov ebp, esp
	
	;is the number of bytes zero?
	mov eax, dword[ebp+16]
	cmp eax, 0
	jle my_memset_dword_end
	
	;is the number of bytes divisible by 4?
	shr eax, 2
	test eax, eax
	jnz my_memset_dword_divisible_by_four
		push my_memset_dword_error_1
		call my_printf
		add esp, 4
		jmp my_memset_dword_end
	my_memset_dword_divisible_by_four:
	
	mov eax, dword[ebp+8]		;mem in eax
	mov ecx, dword[ebp+12]		;value in ecx
	mov edx, dword[ebp+16]		;byteNum in edx
	my_memset_dword_loop_start:
		mov dword[eax], ecx
		
		add eax, 4
		sub edx, 4
		test edx, edx
		jnz my_memset_dword_loop_start
	
	my_memset_dword_end:
	mov esp, ebp
	pop ebp
	ret
	
	
my_memcmp:
	push ebp
	push ebx
	mov ebp, esp
	
	;check if the byteCount is valid
	mov eax, dword[ebp+20]
	cmp eax, 0
	jg my_memcmp_byteCount_valid
		xor eax, eax
		jmp my_memcmp_end
	my_memcmp_byteCount_valid:
	
	;compare
	xor eax, eax
	mov ebx, dword[ebp+20]		;size in eax
	mov ecx, dword[ebp+12]		;m1 in ecx
	mov edx, dword[ebp+16]		;m2 in edx
	my_memcmp_loop_start:
		mov al, byte[ecx]
		sub al, byte[edx]
		test al, 0xff
		jnz my_memcmp_end
			
		inc ecx
		inc edx
		dec ebx
		test ebx, ebx
		jnz my_memcmp_loop_start
	
	my_memcmp_end:
	mov esp, ebp
	pop ebx
	pop ebp
	ret
	
	
my_malloc:
	push ebp
	mov ebp, esp
	
	;check if the heap is already found and if not, attempt to obtain it
	cmp dword[heap_handle], 0
	jne my_malloc_heap_found
		call [GetProcessHeap]
		mov dword[heap_handle], eax
		test eax, eax
		jnz my_malloc_heap_found
			;still no heap, after a definite attempt
			push my_malloc_error_1
			call my_printf
			add esp, 4
			
			xor eax, eax
			mov esp, ebp
			pop ebp
			ret
			
	my_malloc_heap_found:
	
	push dword[ebp+8]
	push 0
	push dword[heap_handle]
	call [HeapAlloc]
	
	mov esp, ebp
	pop ebp
	ret
	
	
my_realloc:
	push ebp
	mov ebp, esp
	
	;no need to check for the heap handle
	;because realloc w/o malloc would be doomed to eternal cringeness anyways
	push dword[ebp+12]
	push dword[ebp+8]
	push 0
	push dword[heap_handle]
	call [HeapReAlloc]
	
	mov esp, ebp
	pop ebp
	ret
	
	
my_free:
	push ebp
	mov ebp, esp
	
	;check if the the input is NULL
	cmp dword[ebp+8], 0
	je my_free_end
		;doesn't check for an initialized heap handle because who cares tbh
		push dword[ebp+8]
		push 0
		push dword[heap_handle]
		call [HeapFree]
	
	my_free_end:
	mov esp, ebp
	pop ebp
	ret
