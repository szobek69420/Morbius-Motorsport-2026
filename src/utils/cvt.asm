[BITS 32]

section .rodata use32
	test_text db "it's orbin' time",10,0
	
	print_char_nl db "%c",10,0
	print_int_nl db "%d",10,0
	print_float_nl db "%f",10,0

	INT_VALID_CHARS db '0','1','2','3','4','5','6','7','8','9','-',-1	;-1 is the end-of-array character

	error_invalid_int db "cvt_str2int: %s is not a valid integer",10,0
	error_invalid_float db "cvt_str2float: %s is not a valid float",10,0

	zero_str db "0",0

section .text use32

	global cvt_str2int		;int cvt_str2int(const char* str)	//returns 0 on unsuccessful conversion
	
	;reduces the problem to 2 str2int calls
	;can operate on up to 199 character long strings
	;pushes the result onto the fpu stack
	;returns 0 on miserfolg
	;float cvt_str2float(const char* str)
	global cvt_str2float
	
	;returns 0 if the parsing was successful
	;int cvt_trystr2int(const char* str, int* outBuffer)
	global cvt_trystr2int
	
	;returns 0 if the parsing was successful
	;int cvt_trystr2float(const char* str, int* outBuffer)
	global cvt_trystr2float
	
	extern my_memset_dword
	extern my_printf
	extern my_strlen
	extern my_strcpy
	
cvt_str2int:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;return value				4
	sub esp, 4			;unsigned part string		8
	
	mov dword[ebp-4], 0
	
	;check if the format is valid
	push dword[ebp+16]
	call cvt_isValidInt_internal
	test eax, eax
	jnz cvt_str2int_valid
		push dword[ebp+16]
		push error_invalid_int
		call my_printf
		jmp cvt_str2int_end
		
	cvt_str2int_valid:
	
	;calculate the unsigned part pointer
	mov eax, dword[ebp+16]
	mov dword[ebp-8], eax
	cmp byte[eax], '-'
	jne cvt_str2int_no_sign
		inc dword[ebp-8]
	cvt_str2int_no_sign:
	
	;calculate the value
	mov esi, dword[ebp-8]		;current character in esi
	cvt_str2int_loop_start:
		test byte[esi], 0xff
		jz cvt_str2int_loop_end
		
		mov eax, dword[ebp-4]
		imul eax, 10
		xor ecx, ecx
		mov cl, byte[esi]
		sub cl, '0'
		add eax, ecx
		mov dword[ebp-4], eax
		
		inc esi
		jmp cvt_str2int_loop_start
	
	cvt_str2int_loop_end:
	
	;negate the value if necessary
	mov eax, dword[ebp+16]
	cmp byte[eax], '-'
	jne cvt_str2int_end
		neg dword[ebp-4]
	
	cvt_str2int_end:
	mov eax, dword[ebp-4]			;set return value
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret

cvt_str2float:
	push ebp
	mov ebp, esp
	
	sub esp, 200			;buffer for unsigned part		200
	sub esp, 4				;return value					204
	sub esp, 4				;unused							208
	sub esp, 4				;decimal point pos in buffer	212
	sub esp, 4				;ganzzahlteil					216
	sub esp, 4				;bruchteil						220
	sub esp, 4				;bruchteil character length		224
	
	mov dword[ebp-204], 0
	mov dword[ebp-212], -1
	
	push 200
	push 0
	lea eax, [ebp-200]
	push eax
	call my_memset_dword
	
	;check if valid float
	push dword[ebp+8]
	call cvt_isValidFloat_internal
	test eax, eax
	jnz cvt_str2float_valid
		push dword[ebp+8]
		push error_invalid_float
		call my_printf
		jmp cvt_str2float_end
	
	cvt_str2float_valid:
	
	;copy the unsigned part of the string in the buffer
	mov eax, dword[ebp+8]
	cmp byte[eax], '-'
	jne cvt_str2float_no_sign
		inc eax
	cvt_str2float_no_sign:
	
	push eax
	lea ecx, [ebp-200]
	push ecx
	call my_strcpy
	
	;swap the decimal point to 0
	lea eax, [ebp-200]
	xor ecx, ecx			;index in ecx
	cvt_str2float_point_loop_start:
		test byte[eax], 0xff
		jz cvt_str2float_point_loop_end
		
		cmp byte[eax], '.'
		jne cvt_str2float_point_loop_continue
			;decimal point
			mov dword[ebp-212], ecx
			mov byte[eax], 0
			jmp cvt_str2float_point_loop_end
		
		cvt_str2float_point_loop_continue:
		inc eax
		inc ecx
		jmp cvt_str2float_point_loop_start
	cvt_str2float_point_loop_end:
	
	;process the part before the decimal point
	mov dword[ebp-216], 0
	cmp dword[ebp-212], 0
	je cvt_str2float_no_ganzteil
	test byte[ebp-200], 0xff
	jz cvt_str2float_no_ganzteil		;the unsigned part is non-existent
		lea eax, [ebp-200]
		push eax
		call cvt_str2int
		mov dword[ebp-216], eax
	cvt_str2float_no_ganzteil:
	
	;process the part after the decimal point
	mov dword[ebp-220], 0
	mov dword[ebp-224], 0
	cmp dword[ebp-212], -1
	je cvt_str2float_no_bruchteil
	mov eax, dword[ebp-212]
	lea ecx, [ebp-199+eax]		;ebp-200+eax+1
	cmp byte[ecx], 0			;the bruchteil is 0 lang
	je cvt_str2float_no_bruchteil
		push ecx
		call cvt_str2int
		mov dword[ebp-220], eax
		call my_strlen
		mov dword[ebp-224], eax
	cvt_str2float_no_bruchteil:
	
	;convert the ganzteil to float
	mov eax, dword[ebp-216]
	cvtsi2ss xmm0, eax
	movss dword[ebp-216], xmm0
	
	;convert the brunchteil to float
	mov eax, dword[ebp-220]
	cvtsi2ss xmm0, eax
	movss dword[ebp-220], xmm0
	
	;transform the bruchteil into bruchteil
	mov eax, dword[ebp-224]
	mov ecx, 1					;divisor in eax
	cmp eax, 0
	jle cvt_str2float_bruchteil_transform_loop_end
	cvt_str2float_bruchteil_transform_loop_start:
		imul ecx, 10
		
		dec eax
		jnz cvt_str2float_bruchteil_transform_loop_start
	cvt_str2float_bruchteil_transform_loop_end:
	cvtsi2ss xmm0, ecx
	movss xmm1, dword[ebp-220]
	divss xmm1, xmm0
	movss dword[ebp-220], xmm1
	
	;calculate the final solution
	movss xmm0, dword[ebp-216]
	addss xmm0, dword[ebp-220]
	movss dword[ebp-204], xmm0
	
	;check if signed
	mov eax, dword[ebp+8]
	cmp byte[eax], '-'
	jne cvt_str2float_no_sign2
		or dword[ebp-204], 0x80000000
	cvt_str2float_no_sign2:
	
	cvt_str2float_end:
	fld dword[ebp-204]			;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
cvt_trystr2int:	
	push ebp
	mov ebp, esp
	
	sub esp, 4		;str2int return value		4
	
	push dword[ebp+8]
	call cvt_str2int
	mov dword[ebp-4], eax
	
	test eax, eax
	jnz cvt_trystr2int_valid
		push dword[ebp+8]
		call cvt_isValidInt_internal
		test eax, eax
		jnz cvt_trystr2int_valid
			;not valid
			mov eax, 69
			jmp cvt_trystr2int_end
	
	cvt_trystr2int_valid:
		;valid
		mov ecx, dword[ebp+12]
		mov dword[ecx], eax
		
		xor eax, eax		;set return val
	
	cvt_trystr2int_end:
	mov esp, ebp
	pop ebp
	ret
	
	
cvt_trystr2float:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;str2float return value		4
	
	;convert the nigga
	push dword[ebp+8]
	call cvt_str2float
	fstp dword[ebp-4]
	
	test eax, eax
	jnz cvt_trystr2float_valid
		;if the return value is zero, it can still be valid
		push dword[ebp+8]
		call cvt_isValidFloat_internal
		test eax, eax
		jnz cvt_trystr2float_valid
			;not valid
			mov eax, 69
			jmp cvt_trystr2float_end
	
	cvt_trystr2float_valid:
		;valid
		mov eax, dword[ebp-4]
		mov ecx, dword[ebp+12]
		mov dword[ecx], eax
		
		xor eax, eax		;set return val
	
	cvt_trystr2float_end:
	mov esp, ebp
	pop ebp
	ret
	

;internal functinos -----------------------------------------------------------------

;int cvt_isValidInt_internal(const char* number)
cvt_isValidInt_internal:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;return value						4
	sub esp, 4			;unsigned number string length		8
	sub esp, 4			;unsigned number string				12
	
	mov dword[ebp-4], 0
	mov eax, dword[ebp+16]
	mov dword[ebp-12], eax
	
	;check if the length is fine
	push dword[ebp+16]
	call my_strlen
	mov dword[ebp-8], eax
	cmp eax, 0
	jle cvt_isValidInt_internal_end
	
	;check if the first character is -
	mov eax, dword[ebp+16]
	cmp byte[eax], '-'
	jne cvt_isValidInt_internal_no_sign
		;modify the values
		inc dword[ebp-12]
		dec dword[ebp-8]
		jz cvt_isValidInt_internal_end	;check if the string is still long genug
		
	cvt_isValidInt_internal_no_sign:
	
	;check if the unsigned part is actually a number
	mov esi, dword[ebp-12]			;current char in esi
	mov edi, dword[ebp-8]			;index in edi
	cvt_isValidInt_internal_loop_start:
		cmp byte[esi], '0'
		jl cvt_isValidInt_internal_end
		cmp byte[esi], '9'
		jg cvt_isValidInt_internal_end
		
		inc esi
		dec edi
		jz cvt_isValidInt_internal_loop_end
		jmp cvt_isValidInt_internal_loop_start
	cvt_isValidInt_internal_loop_end:
		
	;if we got here, the string is valid
	mov dword[ebp-4], 69
	
	cvt_isValidInt_internal_end:
	mov eax, dword[ebp-4]			;set return value
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret


;int cvt_isValidFloat_internal(const char* number)
cvt_isValidFloat_internal:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;return value		4
	sub esp, 4			;'-' position		8
	sub esp, 4			;'.' position		12
	
	mov dword[ebp-4], 0
	mov dword[ebp-8], -1
	mov dword[ebp-12], -1
	
	;check if the string is lang genug
	push dword[ebp+16]
	call my_strlen
	cmp eax, 0
	jle cvt_isValidFloat_internal_end
	
	mov esi, dword[ebp+16]			;current character in esi
	xor edi, edi					;current position in string in edi
	cvt_isValidFloat_internal_loop_start:
		test byte[esi], 0xff
		jz cvt_isValidFloat_internal_loop_end
		
		;sign?
		cmp byte[esi], '-'
		jne cvt_isValidFloat_internal_loop_not_sign
			test edi, edi
			jnz cvt_isValidFloat_internal_end
			
			mov dword[ebp-8], 0
			jmp cvt_isValidFloat_internal_loop_continue
		cvt_isValidFloat_internal_loop_not_sign:
		
		;decimal point?
		cmp byte[esi], '.'
		jne cvt_isValidFloat_internal_loop_not_point
			cmp dword[ebp-12], -1
			jne cvt_isValidFloat_internal_end
			
			mov dword[ebp-12], edi
			jmp cvt_isValidFloat_internal_loop_continue
		cvt_isValidFloat_internal_loop_not_point:
		
		;digit?
		cmp byte[esi], '0'
		jl cvt_isValidFloat_internal_end
		cmp byte[esi], '9'
		jg cvt_isValidFloat_internal_end
		
		cvt_isValidFloat_internal_loop_continue:
		inc esi
		inc edi
		jmp cvt_isValidFloat_internal_loop_start
	
	cvt_isValidFloat_internal_loop_end:
	
	;if we're here, gg
	mov dword[ebp-4], 69
	
	cvt_isValidFloat_internal_end:
	mov eax, dword[ebp-4]			;set return value
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret