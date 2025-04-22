[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	my_fopen_mode_read db "r",0
	my_fopen_mode_write db "w",0
	my_fopen_error_1 db "my_fopen: Invalid mode bozo",10,0
	my_fopen_error_2 db "my_fopen: Failed with code %d",10,0
	my_fclose_error_1 db "my_fclose: Failed with code %d",10,0
	
	INVALID_HANDLE_VALUE dd -1
	
section .bss use32
	my_fprintf_buffer resb 10000

section .text use32
	;fopen and fclose error codes:
	;https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes

	;returns 0 if there was a problem
	global my_fopen			;FILE* my_fopen(const char* filePath, const char* mode)		//mode can only be "r" or "w"
	global my_fclose		;int my_fclose(FILE* file)		;returns 0 if there is gebasz (it is a deviation from the c standard)
	
	global my_fgets			;char* my_fgets(char* buffer, int numBytes, FILE* file)
	global my_fprintf		;void my_fprintf(FILE* file, const char* format, ...args)
	global my_fgetc			;int my_fgetc(FILE* file)
	
	;ptr: the buffer in which the read data will go
	;size: the size of each element
	;nmemb: the number of elements to read
	;stream: the file
	;returns the number of elements read
	global my_fread			;int my_size_t fread(void *ptr, int size, int nmemb, FILE *stream)
	
	;jumps numBytes from the specified position
	;if fromCurrent is zero, the new position of the file pointer will be numBytes, otherwise it will be the current position of the file pointer + numBytes
	global my_fjmp			;void my_fjmp(FILE* file, int numBytes, int fromCurrent)
	
	dll_import kernel32.dll, CreateFileA
	dll_import kernel32.dll, CloseHandle
	
	dll_import kernel32.dll, ReadFile
	dll_import kernel32.dll, WriteFile
	
	dll_import kernel32.dll, SetFilePointer
	
	dll_import kernel32.dll, GetLastError
	
	extern my_printf
	
	extern my_memcpy
	
	extern my_strcmp
	extern my_sprintf
	extern my_strlen
	
	
my_fopen:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;HANDLE		;4
	
	mov dword[ebp-4], 0
	
	;check whether the mode ist koser
	push dword[ebp+12]		;mode
	push my_fopen_mode_read
	call my_strcmp
	add esp, 8
	test eax, eax
	jz my_fopen_read
	
	push dword[ebp+12]		;mode
	push my_fopen_mode_write
	call my_strcmp
	add esp, 8
	test eax, eax
	jz my_fopen_write
	
		;open mode is not bussin'
		push my_fopen_error_1
		call my_printf
		add esp, 4
		mov eax, 0
		jmp my_fopen_end
	
	my_fopen_read:
		push 0
		push 0x80				;FILE_ATTRIBUTE_NORMAL
		push 3					;OPEN_EXISTING
		push 0
		push 0					;doesn't share the file
		push 0x80000000			;GENERIC_READ
		push dword[ebp+8]		;path
		call [CreateFileA]
		mov dword[ebp-4], eax
		jmp my_fopen_check_for_valid_handle
	
	my_fopen_write:
		push 0
		push 0x80				;FILE_ATTRIBUTE_NORMAL
		push 2					;CREATE_ALWAYS
		push 0
		push 0					;doesn't share the file
		push 0x40000000			;GENERIC_WRITE
		push dword[ebp+8]		;path
		call [CreateFileA]
		mov dword[ebp-4], eax
		jmp my_fopen_check_for_valid_handle
		
	my_fopen_check_for_valid_handle:
	
	;was it successful?
	mov eax, dword[ebp-4]
	cmp eax, dword[INVALID_HANDLE_VALUE]
	jne my_fopen_end
	
		;print error code
		call [GetLastError]
		push eax
		push my_fopen_error_2
		call my_printf
		add esp, 8
		
		mov dword[ebp-4], 0
		
	my_fopen_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
my_fclose:
	push ebp
	mov ebp, esp
	
	sub esp, 4	;return value		;4
	
	push dword[ebp+8]
	call [CloseHandle]
	mov dword[ebp-4], eax
	
	;was it successful?
	test eax, eax
	jnz my_fclose_end
	
		;print error code
		call [GetLastError]
		push eax
		push my_fclose_error_1
		call my_printf
		add esp, 8
	
	my_fclose_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
my_fgets:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;number of bytes read
	
	mov eax, dword[ebp+12]
	cmp eax, 0
	jle my_fgets_error
	dec eax			;so that there is space for the closing zero
	
	lea ecx, [ebp-4]
	
	;call ReadFile
	push 0
	push ecx
	push eax
	push dword[ebp+8]		;buffer
	push dword[ebp+16]		;file
	call [ReadFile]
	test eax, eax
	jz my_fgets_error		;ReadFile was unsuccessful
	
	;check if no characters were read
	cmp dword[ebp-4], 0
	je my_fgets_error
	
	;search for the '\n' or '\0'
	mov eax, dword[ebp+8]		;current pos in buffer in eax
	mov ecx, dword[ebp-4]		;bytes read in ecx
	
	
	cmp ecx, 0			;if bytes read is "egy nagy nulla" - talek hamas, 69 BC
	jne my_fgets_line_end_loop_start
		mov byte[eax], 0		;insert a closing zero
		jmp my_fgets_end
	
	my_fgets_line_end_loop_start:
		
		cmp byte[eax], 10		; LF
		je my_fgets_line_end_loop_end
		cmp byte[eax], 0		; \0
		je my_fgets_line_end_loop_end
		
		cmp ecx, 1
		je my_fgets_line_end_loop_end		;if we're at the end of the read data
		
		
		inc eax
		dec ecx
		jmp my_fgets_line_end_loop_start
		
	my_fgets_line_end_loop_end:
	
	;insert a closing zero at the end
	mov byte[eax+1], 0
	
	;set the file pointer (because the read data and the actual line is most probably not of the same length)
	dec ecx		;because the value of ecx is 1 when the line size and the read size is the same
	xor ecx, 0xFFFFFFFF
	inc ecx		;ecx must be inverted, because the file pointer will be moved backwards
	
	push 1		;FILE_CURRENT
	push 0
	push ecx
	push dword[ebp+16]
	call [SetFilePointer]
	
	jmp my_fgets_end
	my_fgets_error:
		mov eax, 0
		mov esp, ebp
		pop ebp
		ret
		
	my_fgets_end:
	mov eax, dword[ebp+8]
	mov esp, ebp
	pop ebp
	ret
	
	
my_fprintf:
	push ebp
	mov ebp, esp
	
	;figure out how many bytes the variable arguments take
	push dword[ebp+12]
	call my_strlen
	add esp, 4
	
	cmp eax, 0		;the string is not very long
	jle my_fprintf_end
	
	mov ecx, dword[ebp+12]		;current position in format in ecx
	mov edx, 0					;the length of the variable args in bytes
	my_fprintf_input_length_loop_start:
		cmp byte[ecx], 37 ;%
		jne my_fprintf_input_length_loop_continue
		
		
		cmp byte[ecx+1], 'c'
		jne my_fprintf_input_length_loop_not_c
			add edx, 1
			jmp my_fprintf_input_length_loop_continue
		my_fprintf_input_length_loop_not_c:
		
		
		cmp byte[ecx+1], 'd'
		jne my_fprintf_input_length_loop_not_d
			add edx, 4
			jmp my_fprintf_input_length_loop_continue
		my_fprintf_input_length_loop_not_d:
		
		
		cmp byte[ecx+1], 'f'
		jne my_fprintf_input_length_loop_not_f
			add edx, 4
			jmp my_fprintf_input_length_loop_continue
		my_fprintf_input_length_loop_not_f:
		
		
		cmp byte[ecx+1], 's'
		jne my_fprintf_input_length_loop_not_s
			add edx, 4
			jmp my_fprintf_input_length_loop_continue
		my_fprintf_input_length_loop_not_s:
		
		
		my_fprintf_input_length_loop_continue:
		inc ecx
		dec eax
		cmp eax, 0
		jg my_fprintf_input_length_loop_start
		
	
	;copy the function params and call sprintf
	sub esp, edx
	mov eax, esp
	lea ecx, [ebp+16]
	
	push edx
	push ecx
	push eax
	call my_memcpy
	add esp, 12
	
	push dword[ebp+12]
	push my_fprintf_buffer
	call my_sprintf
	call my_strlen

	;output the created string onto the console
	push 0
	push 0
	push eax
	push my_fprintf_buffer
	push dword[ebp+8]
	call [WriteFile]
	
	my_fprintf_end:
	mov esp, ebp
	pop ebp
	ret
	
	
my_fgetc:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;number of bytes read
	sub esp, 4		;buffer
	
	push 0
	lea eax, [ebp-4]
	push eax
	push 1
	sub eax, 4
	push eax
	push dword[ebp+8]
	call [ReadFile]
	
	test eax, eax
	jz my_fgetc_error
	
	cmp dword[ebp-4], 1
	jne my_fgetc_error
	
	xor eax, eax
	mov al, byte[ebp-8]
	
	jmp my_fgetc_end
	my_fgetc_error:
		mov eax, -1
	my_fgetc_end:
	mov esp, ebp
	pop ebp
	ret
	
	
my_fread:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4					;return value
	
	mov dword[ebp-4], 0
	
	;is nmemb>0?
	cmp dword[ebp+24], 0
	jle my_fread_end
	
	mov esi, dword[ebp+16]		;buffer in esi
	mov edi, dword[ebp+24]		;index in edi
	my_fread_loop_start:
		;read the next memory block
		push 0				;not overlapped
		push 0
		push dword[ebp+20]	;number of bytes to read
		push esi			;buffer
		push dword[ebp+28]	;file
		call [ReadFile]
		
		;was it successful?
		test eax, eax
		jz my_fread_end
		
		;increment the successful block count
		inc dword[ebp-4]
	
		add esi, dword[ebp+20]
		dec edi
		test edi, edi
		jnz my_fread_loop_start
	
	my_fread_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
my_fjmp:
	push ebp
	mov ebp, esp
	
	push 0						;FILE_BEGIN
	cmp dword[ebp+16], 0
	je my_fjmp_from_begin
		mov dword[esp], 1		;FILE_CURRENT
	my_fjmp_from_begin:
	push 0
	push dword[ebp+12]
	push dword[ebp+8]
	call [SetFilePointer]
	
	mov esp, ebp
	pop ebp
	ret