[BITS 32]

section .rodata use32

	ONE dd 1.0
	
	SKY_VALUES:
	dd -0.0001
	dd 0.05
	dd 0.1
	dd 0.4
	dd 0.45
	dd 0.5
	dd 0.95
	dd 1.0001
	
	SKY_COLOURS:
	dd 0.878431, 0.439215, 0.0, 1.0
	dd 1.0, 0.843137, 0.282353, 1.0
	dd 0.5294, 0.8078, 0.9215, 1.0
	dd 0.5294, 0.8078, 0.9215, 1.0
	dd 0.913725, 0.5, 0.0, 1.0
	dd 0.149019, 0.0, 0.5, 1.0
	dd 0.149019, 0.0, 0.5, 1.0
	dd 0.878431, 0.439215, 0.0, 1.0
	
	print_int_nl db "%d",10,0
	print_float_nl db "%f",10,0

section .text use32

	global sky_getColour	;void sky_getColour(float daytimeNormalized, vec4* buffer)
	
	extern vec4_sub
	extern vec4_add
	extern vec4_scale
	extern vec4_print
	
	extern my_printf
	
sky_getColour:
	push ebp
	mov ebp, esp
	
	sub esp, 4	;sky colour address		;4
	sub esp, 4	;interpolation helper	;8
	sub esp, 4	;index					;12
	sub esp, 16	;calculated colour		;28
	
	;get sky colour
	mov dword[ebp-4], SKY_COLOURS
	xor eax, eax
	movss xmm0, dword[ebp+8]
	sky_getColour_loop_start:
		
		ucomiss xmm0, dword[SKY_VALUES+4*eax]
		jbe sky_getColour_loop_value_found
		ucomiss xmm0, dword[ONE]
		jae sky_getColour_loop_value_found
		jmp sky_getColour_loop_continue
		
		sky_getColour_loop_value_found:
			mov dword[ebp-12], eax		;save index
			
			lea ecx, [SKY_VALUES+4*eax]
			movss xmm1, dword[ecx]
			movss xmm2, dword[ecx-4]
			
			movss xmm3, xmm1
			subss xmm3, xmm2
			subss xmm0, xmm2
			divss xmm0, xmm3
			movss dword[ebp-8], xmm0
			
			
			dec eax
			shl eax, 4
			add eax, SKY_COLOURS
			push eax					;previous key colour
			add eax, 16
			push eax					;current key colour
			lea ecx, [ebp-28]
			push ecx
			call vec4_sub
			add esp, 8					;keep the previous key colour on the stack
			
			lea eax, [ebp-28]
			push dword[ebp-8]
			push eax
			push eax
			call vec4_scale
			pop eax
			add esp, 8
			push eax
			push eax
			call vec4_add
			add esp, 12
			
			jmp sky_getColour_loop_end
		
		sky_getColour_loop_continue:
		inc eax
		jmp sky_getColour_loop_start
		
	sky_getColour_loop_end:
	
	;copy the vector to the buffer
	mov eax, dword[ebp+12]
	
	mov ecx, dword[ebp-28]
	mov dword[eax], ecx
	mov ecx, dword[ebp-24]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp-20]
	mov dword[eax+8], ecx
	mov ecx, dword[ebp-16]
	mov dword[eax+12], ecx
	
	
	mov esp, ebp
	pop ebp
	ret
	