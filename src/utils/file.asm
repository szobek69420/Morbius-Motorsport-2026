[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

;struct BY_HANDLE_FILE_INFORMATION {
;  DWORD    dwFileAttributes;			0
;  FILETIME ftCreationTime;				4
;  FILETIME ftLastAccessTime;			12
;  FILETIME ftLastWriteTime;			20
;  DWORD    dwVolumeSerialNumber;		28
;  DWORD    nFileSizeHigh;				32
;  DWORD    nFileSizeLow;				36
;  DWORD    nNumberOfLinks;				40
;  DWORD    nFileIndexHigh;				44
;  DWORD    nFileIndexLow;				48
;}		52 bytes

section .rodata use32
	my_fopen_mode_read db "r",0
	my_fopen_mode_write db "w",0
	my_fopen_error_1 db "my_fopen: Invalid mode bozo",10,0
	my_fopen_error_2 db "my_fopen: Failed with code %d",10,0
	my_fclose_error_1 db "my_fclose: Failed with code %d",10,0
	
	INVALID_HANDLE_VALUE dd -1
	INVALID_FILE_ATTRIBUTES dd -1
	FILE_ATTRIBUTE_DIRECTORY dd 0x00000010
	
	print_char_nl db "%c",10,0
	print_string_nl db "%s",10,0
	
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
	global my_fread			;int my_fread(void *ptr, int size, int nmemb, FILE *stream)
	
	global my_fscanf		;int my_fscanf(FILE* file, const char* format, ...args)
	
	;jumps numBytes from the specified position
	;if fromCurrent is zero, the new position of the file pointer will be numBytes, otherwise it will be the current position of the file pointer + numBytes
	global my_fjmp			;void my_fjmp(FILE* file, int numBytes, int fromCurrent)
	
	global file_getId		;void file_getId(const char* path, uint64* buffer)
	
	dll_import kernel32.dll, GetFileAttributesA
	dll_import kernel32.dll, CreateFileA
	dll_import kernel32.dll, CreateDirectoryA
	dll_import kernel32.dll, CloseHandle
	
	dll_import kernel32.dll, ReadFile
	dll_import kernel32.dll, WriteFile
	
	dll_import kernel32.dll, SetFilePointer
	
	dll_import kernel32.dll, GetFileInformationByHandle
	
	dll_import kernel32.dll, GetLastError
	
	extern my_printf
	
	extern my_malloc
	
	extern my_memcpy
	extern my_memset_dword
	
	extern my_strcmp
	extern my_sprintf
	extern my_strlen
	
	extern ctype_isSpace
	
	extern cvt_str2int
	extern cvt_str2float
	
my_fopen:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;HANDLE					;4
	sub esp, 4			;file path				;8
	sub esp, 4			;file path part count	;12
	sub esp, 4			;loop index				;16
	
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
		;segment the path
		lea eax, [ebp-12]
		push eax
		lea ecx, [ebp-8]
		push ecx
		push dword[ebp+8]
		call file_separateRelativeFilePath_internal
		add esp, 12
	
		;create any intermediate directories if necessary
		mov dword[ebp-16], 1
		cmp dword[ebp-12], 1
		jle my_fopen_read_create_directory_loop_end
		my_fopen_read_create_directory_loop_start:		
			;check if the directory exists
			push dword[ebp-8]
			call [GetFileAttributesA]
			cmp eax, dword[INVALID_FILE_ATTRIBUTES]
			je my_fopen_read_create_directory_loop_no_existence
			test eax, dword[FILE_ATTRIBUTE_DIRECTORY]
			jz my_fopen_read_create_directory_loop_no_existence
			jmp my_fopen_read_create_directory_loop_continue
			
			my_fopen_read_create_directory_loop_no_existence:
				;directory doesn't exist, create it
				push 0
				push dword[ebp-8]
				call [CreateDirectoryA]
			
			my_fopen_read_create_directory_loop_continue:
			mov eax, dword[ebp-16]
			inc eax
			cmp eax, dword[ebp-12]
			jge my_fopen_read_create_directory_loop_end
			
			mov dword[ebp-16], eax
			push dword[ebp-8]
			call my_strlen
			add esp, 4
			mov ecx, dword[ebp-8]
			mov byte[ecx+eax], '/'
			jmp my_fopen_read_create_directory_loop_start
			
		my_fopen_read_create_directory_loop_end:
	
		;actually open the file
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
	
	
my_fscanf:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 200		;buffer							200
	sub esp, 4			;current parameter offset		204
	sub esp, 4			;is % active					208
	sub esp, 4			;successful reads				212
	
	push 200
	push 0
	lea eax, [ebp-200]
	push eax
	call my_memset_dword
	
	mov dword[ebp-204], 24
	mov dword[ebp-208], 0
	mov dword[ebp-212], 0
	
	mov esi, dword[ebp+20]			;current character in esi
	my_fscanf_outer_loop_start:
		test byte[esi], 0xff
		jz my_fscanf_outer_loop_end
		
		cmp byte[esi], '%'
		jne my_fscanf_outer_loop_no_input_start
			mov dword[ebp-208], 69
			inc esi
		my_fscanf_outer_loop_no_input_start:
	
		test dword[ebp-208], 0xffffffff
		jz my_fscanf_outer_loop_no_input
			;inside input
			cmp byte[esi], 'd'
			je my_fscanf_outer_loop_int
			cmp byte[esi], 'f'
			je my_fscanf_outer_loop_float
			my_fscanf_outer_loop_int:
				;get the number string
				lea eax, [ebp-200]
				push eax
				push dword[ebp+16]
				call file_readUntilSpace_internal
				add esp, 8
				
				;convert it to int
				lea eax, [ebp-200]
				push eax
				call cvt_str2int
				add esp, 4
				
				;set the parameters
				mov ecx, dword[ebp-204]
				mov ecx, dword[ebp+ecx]
				mov dword[ecx], eax
				
				add dword[ebp-204], 4
				
				inc dword[ebp-212]
				
				;% is no more active
				mov dword[ebp-208], 0
				
				jmp my_fscanf_outer_loop_continue
				
			my_fscanf_outer_loop_float:
				;get the number string
				lea eax, [ebp-200]
				push eax
				push dword[ebp+16]
				call file_readUntilSpace_internal
				add esp, 8
				
				;convert it to float
				lea eax, [ebp-200]
				push eax
				call cvt_str2float
				fstp dword[esp]
				mov eax, dword[esp]
				add esp, 4
				
				;set the parameters
				mov ecx, dword[ebp-204]
				mov ecx, dword[ebp+ecx]
				mov dword[ecx], eax
				
				add dword[ebp-204], 4
				
				inc dword[ebp-212]
				
				;% is no more active
				mov dword[ebp-208], 0
				
				jmp my_fscanf_outer_loop_continue
				
		my_fscanf_outer_loop_no_input:
			push dword[ebp+16]
			call my_fgetc
			add esp, 4
			
			cmp al, -1
			je my_fscanf_outer_loop_end					;end of file

			cmp al, byte[esi]
			jne my_fscanf_outer_loop_end				;differing formats
		my_fscanf_outer_loop_continue:
		inc esi
		jmp my_fscanf_outer_loop_start
	my_fscanf_outer_loop_end:
	
	;set return value
	mov eax, dword[ebp-212]
	
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
	
	
;internal functinos -----------------------------------------------------------

;reads the file until the first whitespace (the whitespace doesn't get eaten and isn't added to the buffer)
;void file_readUntilSpace_internal(FILE* file, char* buffer)
file_readUntilSpace_internal:
	push ebp
	push esi
	mov ebp, esp
	
	mov esi, dword[ebp+16]			;current pos in buffer in esi
	push dword[ebp+12]
	file_readUntilSpace_internal_loop_start:
		call my_fgetc
		push eax
		call ctype_isSpace
		test eax, eax
		jnz file_readUntilSpace_internal_loop_end
			;copy the character
			pop eax
			mov byte[esi], al
		
		inc esi
		jmp file_readUntilSpace_internal_loop_start
	file_readUntilSpace_internal_loop_end:
	push 69
	push -1
	push dword[ebp+12]
	call my_fjmp			;un-eat the white space
	
	mov byte[esi], 0
	
	mov esp, ebp
	pop esi
	pop ebp
	ret
	
;separates a relative path (possible separators are '/','\' or any combination of the two )
;behaviour for absolute paths is undefined
;partCount is the number of parts in the path
;the returned char array is the concatenation of the parts, each separated with a '\0'
;returns NULL if the path is of length 0
;the returned array shall be deallocated after use
;void file_separateRelativeFilePath_internal(const char* path, char** outSeparatedPath, int* outPartCount)
file_separateRelativeFilePath_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;allocated array		4
	sub esp, 4			;part count				8
	
	mov dword[ebp-4], 0
	mov dword[ebp-8], 0
	
	;allocate the array
	push dword[ebp+20]
	call my_strlen
	test eax, eax
	jz file_separateRelativeFilePath_internal_end
	inc eax
	push eax
	call my_malloc
	mov dword[ebp-4], eax
	
	;separate the file path
	mov esi, dword[ebp+20]		;current char in path in esi
	mov edi, dword[ebp-4]		;current char in array in edi
	xor ebx, ebx				;length of current part
	file_separateRelativeFilePath_internal_loop_start:
		;has a part ended?
		cmp byte[esi], '\'
		je file_separateRelativeFilePath_internal_loop_part_end
		cmp byte[esi], '/'
		je file_separateRelativeFilePath_internal_loop_part_end
		;has the path ended?
		cmp byte[esi], 0
		je file_separateRelativeFilePath_internal_loop_path_end
			;normal character
			mov al, byte[esi]
			mov byte[edi], al
			inc ebx
			jmp file_separateRelativeFilePath_internal_loop_continue
			
		file_separateRelativeFilePath_internal_loop_part_end:
			;set the current array char to 0
			mov byte[edi], 0
			
			;eat any subsequent separators as well
			;thinks first before you change this part
			file_separateRelativeFilePath_internal_loop_part_end_loop_start:
				inc esi
				cmp byte[esi], '\'
				je file_separateRelativeFilePath_internal_loop_part_end_loop_start
				cmp byte[esi], '/'
				je file_separateRelativeFilePath_internal_loop_part_end_loop_start
				dec esi
				
			xor ebx, ebx
			inc dword[ebp-8]
			jmp file_separateRelativeFilePath_internal_loop_continue
		
		file_separateRelativeFilePath_internal_loop_path_end:
			;set the current array char to 0
			mov byte[edi], 0
			
			;increment part count only if the part exists
			test ebx, ebx
			jz file_separateRelativeFilePath_internal_loop_end
			inc dword[ebp-8]
			jmp file_separateRelativeFilePath_internal_loop_end
		
		file_separateRelativeFilePath_internal_loop_continue:
		inc esi
		inc edi
		jmp file_separateRelativeFilePath_internal_loop_start
	file_separateRelativeFilePath_internal_loop_end:
	
	file_separateRelativeFilePath_internal_end:
	;set values
	mov eax, dword[ebp+24]
	mov ecx, dword[ebp-4]
	mov dword[eax], ecx
	
	mov eax, dword[ebp+28]
	mov ecx, dword[ebp-8]
	mov dword[eax], ecx
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret


file_getId:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;handle								4
	sub esp, 52			;BY_HANDLE_FILE_INFORMATION buffer	56
	
	;create handle
	push 0
	push 0x80			;FILE_ATTRIBUTE_NORMAL
	push 3				;OPEN_EXISTING
	push 0
	push 0b1			;FILE_SHADER_READ
	push 0				;minimal desired access
	push dword[ebp+8]
	call [CreateFileA]
	mov dword[ebp-4], eax
	cmp eax, dword[INVALID_HANDLE_VALUE]
	je file_getId_error
	
	;get file info
	lea eax, [ebp-56]
	push eax
	push dword[ebp-4]
	call [GetFileInformationByHandle]
	test eax, eax
	jz file_getId_error
	
	;extract id from the buffer
	mov eax, dword[ebp+12]
	mov ecx, dword[ebp-12]
	mov edx, dword[ebp-8]
	mov dword[eax], ecx
	mov dword[eax+4], edx
	
	;close handle
	push dword[ebp-4]
	call [CloseHandle]
	
	file_getId_end:
	mov esp, ebp
	pop ebp
	ret
	file_getId_error:
		;zero out return buffer
		mov eax, dword[ebp+12]
		mov dword[eax], 0
		mov dword[eax+4], 0
		
		;print error message
		call [GetLastError]
		push eax
		push file_getId_error_something_went_wong
		call my_printf
		
		jmp file_getId_end
		file_getId_error_something_went_wong db "file_getId: i sense some skill issue with the error code of %d",10,0