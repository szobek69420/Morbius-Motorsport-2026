[BITS 32]

section .rodata use32

	ARRAY_WHITE_SPACE db 0x20, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0xff
	ARRAY_INTEGER db '0','1','2','3','4','5','6','7','8','9','-',0xff
	ARRAY_FLOAT db '0','1','2','3','4','5','6','7','8','9','-','.',0xff

section .text use32

	global ctype_isSpace			;int ctype_isSpace(int character)	//checks whether the character is white-space
	
	global ctype_isInt				;int ctype_isInt(int character)		//checks whether the character can come up in an integer
	global ctype_isFloat			;int ctype_isFloat(int character)	//checks whether the character can come up in an float
	
ctype_isSpace:
	mov eax, dword[esp+4]
	push ARRAY_WHITE_SPACE
	push eax
	call ctype_isInArray
	add esp, 8
	ret
	
ctype_isInt:
	mov eax, dword[esp+4]
	push ARRAY_INTEGER
	push eax
	call ctype_isInArray
	add esp, 8
	ret
	
ctype_isFloat:
	mov eax, dword[esp+4]
	push ARRAY_FLOAT
	push eax
	call ctype_isInArray
	add esp, 8
	ret
	
;internal functinos --------------------------------------------------------------

;array have a stopping character of 0xff
;int ctype_isInArray(int character, const char* array)
ctype_isInArray:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	mov dword[ebp-4], 0
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	ctype_isInArray_loop_start:
		cmp byte[ecx], 0xff
		je ctype_isInArray_loop_end
		
		cmp byte[ecx], al
		jne ctype_isInArray_loop_continue
			;character found
			mov dword[ebp-4], 69
			jmp ctype_isInArray_loop_end
		
		ctype_isInArray_loop_continue:
		inc ecx
		jmp ctype_isInArray_loop_start
		
	ctype_isInArray_loop_end:
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	