[BITS 32]


%macro dll_import 2
    import %2 %1
    extern %2
%endmacro



section .data use32
	stdout_handle dd 0		;0, if not yet queried
	critical_section dd 0

section .bss use32
	
	printf_buffer resb 10000


section .text use32

	global my_printf	;void printf(const char* format, ...args), expects single precision floating point numbers
	
	extern my_strlen
	extern my_sprintf
	extern my_memcpy
	
	extern criticalSection_create
	extern criticalSection_lock
	extern criticalSection_unlock
	
	dll_import kernel32.dll, GetStdHandle
	dll_import kernel32.dll, WriteFile
	
my_printf:
	push ebp
	mov ebp, esp
	
	;check for stdout and find it if necessary
	cmp dword[stdout_handle], 0
	jne my_printf_stdout_loaded
		call criticalSection_create
		mov dword[critical_section], eax
		
		call get_stdout_handle
		cmp dword[stdout_handle], 0
		jne my_printf_stdout_loaded
		jmp my_printf_end				;if the loading was unfruitful, abort
	my_printf_stdout_loaded:
	
	;figure out how many bytes the variable arguments take
	push dword[ebp+8]
	call my_strlen
	add esp, 4
	
	cmp eax, 0		;the string is not very long
	jle my_printf_end
	
	mov ecx, dword[ebp+8]		;current position in format in ecx
	mov edx, 0					;the length of the variable args in bytes
	my_printf_input_length_loop_start:
		cmp byte[ecx], 37 ;%
		jne my_printf_input_length_loop_continue
		
		
		cmp byte[ecx+1], 'c'
		jne my_printf_input_length_loop_not_c
			add edx, 1
			jmp my_printf_input_length_loop_continue
		my_printf_input_length_loop_not_c:
		
		
		cmp byte[ecx+1], 'd'
		jne my_printf_input_length_loop_not_d
			add edx, 4
			jmp my_printf_input_length_loop_continue
		my_printf_input_length_loop_not_d:
		
		
		cmp byte[ecx+1], 'f'
		jne my_printf_input_length_loop_not_f
			add edx, 4
			jmp my_printf_input_length_loop_continue
		my_printf_input_length_loop_not_f:
		
		
		cmp byte[ecx+1], 's'
		jne my_printf_input_length_loop_not_s
			add edx, 4
			jmp my_printf_input_length_loop_continue
		my_printf_input_length_loop_not_s:
		
		
		my_printf_input_length_loop_continue:
		inc ecx
		dec eax
		cmp eax, 0
		jg my_printf_input_length_loop_start
		
	
	;copy the function params and call sprintf
	sub esp, edx
	mov eax, esp
	lea ecx, [ebp+12]
	
	push edx
	push ecx
	push eax
	call my_memcpy
	add esp, 12

	;lock the critical sex
	push dword[critical_section]
	;call criticalSection_lock
	add esp, 4
	
	;get the string length
	push dword[ebp+8]
	push printf_buffer
	call my_sprintf
	call my_strlen
	
	;output the created string onto the console
	push 0
	push 0
	push eax
	push printf_buffer
	push dword[stdout_handle]
	call [WriteFile]
	
	;unlock the critical sex
	push dword[critical_section]
	;call criticalSection_unlock
	
	my_printf_end:
	mov esp, ebp
	pop ebp
	ret
	
	
get_stdout_handle:		;void get_stdout_handle(void)
	push ebp
	mov ebp, esp
	
	push -11			;stdout
	call [GetStdHandle]
	cmp eax, -1			;INVALID_HANDLE_VALUE
	je get_stdout_handle_skip_set
		mov dword[stdout_handle], eax
	get_stdout_handle_skip_set:
	
	mov esp, ebp
	pop ebp
	ret