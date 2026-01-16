[BITS 32]

section .rodata use32
	float_infinity db "Inf",0
	float_not_a_number db "NaN",0
	
	THOUSAND dd 1000.0
	
	char_0 db 48

section .text use32
	
	global my_strlen		;int my_strlen(const char*)
	global my_strcmp		;int my_strcmp(const char*, const char*)
	global my_strcpy		;void my_strcpy(const char* dst, const char* src)
	global my_strcat		;void my_strcat(char* dst, const char* src)
	
	global my_sprintf		;void my_sprintf(char* buffer, const char* format, ...args), it expects single-precision floating point numbers
	
	;the substrings need to be freed by the caller
	;the substrings are appended to the end of the outSubstrings vector
	;if there are multiple consecutive splitters, they are interpreted as one
	;void my_ssplit(const char* string, int splitterChar, vector<char*>* outSubstrings)
	global my_ssplit
	
	
	extern my_malloc
	extern my_memcpy
	
	extern vector_push_back
	
my_strlen:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	mov ecx, eax
	
	strlen_loop_start:
		cmp byte[eax], 0
		je strlen_loop_end
		
		inc eax
		jmp strlen_loop_start
	strlen_loop_end:
	
	sub eax, ecx
	
	mov esp, ebp
	pop ebp
	ret
	
my_strcmp:
	push ebp
	push ebx
	mov ebp, esp
	
	mov eax, dword[ebp+12]
	mov ecx, dword[ebp+16]
	
	strcmp_loop_start:
		xor edx, edx
		xor ebx, ebx
		
		cmp byte[eax], 0
		je strcmp_loop_end
		cmp byte[ecx], 0
		je strcmp_loop_end
		
		mov dl, byte[eax]
		mov bl, byte[ecx]
		sub edx, ebx
		cmp edx, 0
		jne strcmp_loop_end
		
		inc eax
		inc ecx
		jmp strcmp_loop_start
	strcmp_loop_end:
	
	cmp edx, 0
	jne strcmp_end
	
	mov dl, byte[eax]
	mov bl, byte[ecx]
	sub edx, ebx
	mov eax, edx
	
	strcmp_end:
	mov esp, ebp
	pop ebx
	pop ebp
	ret
	

my_strcpy:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;src in eax
	mov ecx, dword[ebp+12]		;src in ecx
	
	strcpy_loop_start:
		mov dl, byte[ecx]
		mov byte[eax], dl
		inc eax
		inc ecx
		cmp byte[ecx-1], 0
		jne strcpy_loop_start
	
	mov esp, ebp
	pop ebp
	ret
	
my_strcat:
	push ebp
	mov ebp, esp
	
	;get the length of the destination string
	push dword[ebp+8]
	call my_strlen
	add esp, 4
	
	;concatenate
	add eax, dword[ebp+8]
	push dword[ebp+12]
	push eax
	call my_strcpy
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
	
my_sprintf:
	push ebp
	push ebx
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;current argument address
	sub esp, 4			;current character (pointer) in buffer
	sub esp, 4			;current character (pointer) in format
	
	lea eax, [ebp+28]
	mov dword[ebp-4], eax
	
	mov eax, dword[ebp+20]
	mov dword[ebp-8], eax
	
	mov eax, dword[ebp+24]
	mov dword[ebp-12], eax
	
	sprintf_loop_start:
		mov edi, dword[ebp-8]		;current buffer pos in edi
		mov esi, dword[ebp-12]		;current format pos in esi
		
		;check for %things
		cmp byte[esi], 37		;is % ?
		jne sprintf_not_special_format
		
		; %c ?
		cmp byte[esi+1], 99
		jne sprintf_not_char
			push dword[ebp-4]
			add dword[ebp-4], 1		;shift the arg pointer
			lea eax, [ebp-8]
			push eax
			call my_sprintf_print_char
			add esp, 8
			
			add dword[ebp-12], 2
			jmp sprintf_loop_start
		sprintf_not_char:
		
		; %d ?
		cmp byte[esi+1], 100
		jne sprintf_not_int
			push dword[ebp-4]
			add dword[ebp-4], 4		;shift the arg pointer
			lea eax, [ebp-8]
			push eax
			call my_sprintf_print_int
			add esp, 8
			
			add dword[ebp-12], 2
			jmp sprintf_loop_start
		sprintf_not_int:
		
		; %s ?
		cmp byte[esi+1], 115
		jne sprintf_not_string
			push dword[ebp-4]
			add dword[ebp-4], 4		;shift the arg pointer
			lea eax, [ebp-8]
			push eax
			call my_sprintf_print_string
			add esp, 8
			
			add dword[ebp-12], 2
			jmp sprintf_loop_start
		sprintf_not_string:
		
		; %f ?
		cmp byte[esi+1], 102
		jne sprintf_not_float
			push dword[ebp-4]
			add dword[ebp-4], 4		;shift the arg pointer
			lea eax, [ebp-8]
			push eax
			call my_sprintf_print_float
			add esp, 8
			
			add dword[ebp-12], 2
			jmp sprintf_loop_start
		sprintf_not_float:
		
		sprintf_not_special_format:
		mov al, byte[esi]
		mov byte[edi], al
		inc dword[ebp-8]
		inc dword[ebp-12]
		
		cmp byte[edi], 0
		jne sprintf_loop_start
	sprintf_loop_end:
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebx
	pop ebp
	ret
	
my_sprintf_print_char:	;void my_sprintf_print_char(char** currentPositionInBuffer, char* value), saves every register
	push ebp
	push eax
	push ecx
	mov ebp, esp
	
	mov ecx, dword[ebp+20]
	mov cl, byte[ecx]
	
	mov eax, dword[ebp+16]
	mov eax, [eax]
	mov byte[eax], cl
	
	mov eax, dword[ebp+16]
	inc dword[eax]
	
	mov esp, ebp
	pop ecx
	pop eax
	pop ebp
	ret
	
	
my_sprintf_print_int:	;void my_sprintf_print_int(char** currentPositionInBuffer, int* value), saves every register
	push ebp
	push eax
	push ecx
	push edx
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;the length of the numbers (excluding sign)
	sub esp, 4			;sign length
	sub esp, 4			;absolute value of the number
	
	mov dword[ebp-4], 0
	mov dword[ebp-8], 0
	
	;is negative?
	mov eax, dword[ebp+32]
	mov eax, dword[eax]
	mov dword[ebp-12], eax
	cmp eax, 0
	jge my_sprintf_print_int_not_negative
		mov dword[ebp-8], 1
		xor eax, 0xFFFFFFFF
		inc eax
		mov dword[ebp-12], eax
	my_sprintf_print_int_not_negative:
	
	;get the length of the absolute value
	mov eax, dword[ebp-12]			;absolute value in eax
	xor edx, edx
	mov ecx, 10
	my_sprintf_print_int_length_loop_start:
		inc dword[ebp-4]
		idiv ecx
		xor edx, edx
		cmp eax, 0
		jne my_sprintf_print_int_length_loop_start
		
	;print the number
	mov esi, dword[ebp+28]
	mov esi, dword[esi]
	add esi, dword[ebp-4]
	add esi, dword[ebp-8]
	dec esi					;now the very last character (pointer) of the printed number is in esi
	
	mov eax, dword[ebp-12]			;absolute value in eax
	xor edx, edx
	mov ecx, 10
	my_sprintf_print_int_print_loop_start:
		idiv ecx
		add edx, 48			;number to char
		mov byte[esi], dl
		xor edx, edx
		dec esi
		cmp eax, 0
		jne my_sprintf_print_int_print_loop_start
		
	cmp dword[ebp-8], 0
	je my_sprintf_print_int_no_sign
		mov byte[esi], 45		;-
	my_sprintf_print_int_no_sign:
	
	;update the current position in buffer
	mov esi, dword[ebp+28]
	mov edi, esi
	mov esi, dword[esi]
	add esi, dword[ebp-4]
	add esi, dword[ebp-8]
	
	mov dword[edi], esi
	
	
	mov esp, ebp
	pop edi
	pop esi
	pop edx
	pop ecx
	pop eax
	pop ebp
	ret
	
	
my_sprintf_print_string:	;void my_sprintf_print_string(char** currentPositionInBuffer, const char** value), saves every register
	push ebp
	push eax
	push ecx
	push edx
	mov ebp, esp
	
	sub esp, 4		;the length of the string
	
	;get the length of the string
	mov eax, dword[ebp+24]
	mov eax, dword[eax]
	push eax
	call my_strlen
	mov dword[ebp-4], eax
	add esp, 4
	
	;use strcpy
	mov eax, dword[ebp+24]
	mov eax, dword[eax]
	
	mov ecx, dword[ebp+20]
	mov ecx, dword[ecx]
	
	push eax
	push ecx
	call my_strcpy
	add esp, 8
	
	;update the current position in buffer
	mov eax, dword[ebp+20]
	mov ecx, eax
	mov eax, dword[eax]
	add eax, dword[ebp-4]
	mov dword[ecx], eax
	
	mov esp, ebp
	pop edx
	pop ecx
	pop eax
	pop ebp
	ret
	
	
	
my_sprintf_print_float:	;void my_sprintf_print_float(char** currentPositionInBuffer, float* value), saves every register
	push ebp
	push eax
	push ecx
	push edx
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4		;absolute value of the number
	sub esp, 8		;8 byte helper representation
	
	;print sign and save the absolute value of the number
	mov eax, dword[ebp+32]
	mov eax, dword[eax]
	mov dword[ebp-4], eax
	mov ecx, eax
	and ecx, 0x80000000
	cmp ecx, 0
	je my_sprintf_print_float_not_negative
		and eax, 0x7FFFFFFF
		mov dword[ebp-4], eax
		
		mov ecx, dword[ebp+28]
		mov edx, ecx
		mov ecx, dword[ecx]
		mov byte[ecx], 45		;-
		inc ecx
		mov dword[edx], ecx
	my_sprintf_print_float_not_negative:
	
	;check for special values first
	mov eax, dword[ebp-4]		;absolute value in eax
	
	mov ecx, eax
	and ecx, 0b01111111100000000000000000000000
	xor ecx, 0b01111111100000000000000000000000
	cmp ecx, 0
	jne my_sprintf_print_float_not_special
		;now decide if Inf or NaN
		mov ecx, eax
		and ecx, 0b00000000011111111111111111111111
		jne my_sprintf_print_float_nan
		my_sprintf_print_float_infinity:
			sub esp, 4
			mov dword[esp], float_infinity
			mov edx, esp
			push edx
			push dword[ebp+28]
			call my_sprintf_print_string
			add esp, 12
			jmp my_sprintf_print_float_end
			
		my_sprintf_print_float_nan:
			sub esp, 4
			mov dword[esp], float_not_a_number
			mov edx, esp
			push edx
			push dword[ebp+28]
			call my_sprintf_print_string
			add esp, 12
			jmp my_sprintf_print_float_end
			
	my_sprintf_print_float_not_special:
	
	;shift the float value by the desired number of decimal places and then store it as an 8 byte integer
	fld dword[ebp-4]
	fld dword[THOUSAND]
	fmulp
	fistp dword[ebp-12]
	
	;calculate the decimals in front of and behind the decimal point
	xor edx, edx
	mov eax, dword[ebp-12]
	mov ecx, 1000
	idiv ecx
	mov dword[ebp-12], eax		;the decimals in front of the decimal point
	mov dword[ebp-8], edx		;the decimals behind the decimal point
	
	
	;print upper part
	lea eax, [ebp-12]
	push eax
	push dword[ebp+28]
	call my_sprintf_print_int
	add esp, 8
	
	;print decimal point
	mov eax, dword[ebp+28]
	mov ecx, eax
	mov eax, dword[eax]
	mov byte[eax], 46		; .
	inc eax
	mov dword[ecx], eax
	
	;print extra zeroes for the lower part if necessary
	cmp dword[ebp-8], 100
	jge my_sprintf_print_float_not_less_than_100
		push char_0
		push dword[ebp+28]
		call my_sprintf_print_char
		add esp, 8
	my_sprintf_print_float_not_less_than_100:
	
	cmp dword[ebp-8], 10
	jge my_sprintf_print_float_not_less_than_10
		push char_0
		push dword[ebp+28]
		call my_sprintf_print_char
		add esp, 8
	my_sprintf_print_float_not_less_than_10:
	
	;print lower part
	lea eax, [ebp-8]
	push eax
	push dword[ebp+28]
	call my_sprintf_print_int
	add esp, 8
	
	my_sprintf_print_float_end:
	mov esp, ebp
	pop edi
	pop esi
	pop edx
	pop ecx
	pop eax
	pop ebp
	ret
	
	
	
my_ssplit:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	mov esi, dword[ebp+20]		;start of the current substring in esi
	xor edi, edi				;index of currently examined character in edi
	my_ssplit_loop_start:
		mov al, byte[ebp+24]
		cmp byte[esi+edi], al
		je my_ssplit_loop_substring_end
		test byte[esi+edi], 0xff
		jz my_ssplit_loop_substring_end
		
		my_ssplit_loop_continue:
		inc edi
		jmp my_ssplit_loop_start 
		
		my_ssplit_loop_substring_end:
			;alloc and fill the substring
			push edi
			inc dword[esp]
			call my_malloc
			add esp, 4
			mov byte[eax+edi], 0
			
			push edi
			push esi
			push eax
			call my_memcpy
			pop eax
			add esp, 8
			
			push eax
			push dword[ebp+28]
			call vector_push_back
			add esp, 4
			
			;check if it is the end of the string
			test byte[esi+edi], 0xff
			jz my_ssplit_loop_end
			
			;check if there are following splitters
			mov bl, byte[ebp+24]
			my_ssplit_loop_substring_end_splitter_loop_start:
				inc edi
				cmp byte[esi+edi], bl
				je my_ssplit_loop_substring_end_splitter_loop_start
				
			;check if it is the end of the string again
			test byte[esi+edi], 0xff
			jz my_ssplit_loop_end
			
			;update the start of the substring
			add esi, edi
			xor edi, edi
			jmp my_ssplit_loop_start
				
	my_ssplit_loop_end:
	
	my_ssplit_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret