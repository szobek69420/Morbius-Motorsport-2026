[BITS 32]
;https://youtu.be/9B89kwHvTN4?si=v68YgUcEs0hHRp2R

section .rodata use32
	PERLIN3D_VECTOR_GRID_WIDTH dd 11
	PERLIN3D_VECTOR_GRID_WIDTH_SQUARED dd 121
	PERLIN3D_VECTOR_GRID_WIDTH_CUBED dd 1331
	
	PERLIN3D_VECTOR_GRID_WIDTH_BYTES dd 176
	PERLIN3D_VECTOR_GRID_WIDTH_SQUARED_BYTES dd 1936
	PERLIN3D_VECTOR_GRID_WIDTH_CUBED_BYTES dd 21296
	
	PERLIN3D_SCALER dd 0.000030517578125		;1/2^15 for scaling the random value
	PERLIN3D_INTERPOLATOR_SCALER dd 10.0		;PERLIN3D_VECTOR_GRID_WIDTH-1
	
	print_two_ints_nl db "%d %d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_eight_ints_nl db "%d %d %d %d %d %d %d %d",10,0
	print_float_nl db "%f",10,0
	print_two_floats_nl db "%f %f",10,0
	print_three_floats_nl db "%f %f %f",10,0
	print_four_floats_nl db "%f %f %f %f",10,0
	print_eight_floats_nl db "%f %f %f %f %f %f %f %f",10,0
	
	test_text db "womb raider",10,0
	
	ZERO dd 0.0
	ONE dd 1.0
	
section .bss use32

	;vec4[] instead of vec3[], so that i can use the vec4 library
	;x,y,z order
	;5342=sizeof(vec4)*PERLIN3D_VECTOR_GRID_WIDTH_CUBED
	PERLIN3D_VECTOR_GRID resb 21296
	
section .data use32
	PERLIN3D_INITIALIZED dd 0
	
section .text use32

	global perlin3d_init		;void perlin3d_init()
	global perlin3d_sample		;float perlin3d_sample(float x, float y, float z)	//pushes the result onto the FPU stack
	
	extern my_printf
	
	extern vec3_normalize
	extern vec3_print
	extern vec4_dot
	extern vec4_smoothstep1
	extern math_lerp
	extern math_smoothstep1
	
perlin3d_init:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16			;random helper		16
	
	;create the random vectors
	movss xmm0, dword[PERLIN3D_SCALER]
	shufps xmm0, xmm0, 0b00000000
	mov ebx, 69420			;random seed in ebx
	mov esi, PERLIN3D_VECTOR_GRID
	mov edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_CUBED]
	perlin3d_init_generate_loop_start:
		;generate and scale random values
		imul ebx, 1103515245 
		add ebx, 12345
		
		mov ecx, ebx
		movsx eax, cx			;[-2^15; 2^15-1]
		mov dword[ebp-16], eax
		rol ecx, 16
		movsx eax, cx
		mov dword[ebp-12], eax
		
		imul ebx, 1103515245 
		add ebx, 12345
		
		movsx ecx, bx
		mov dword[ebp-8], ecx
		
		cvtpi2ps xmm1, qword[ebp-16]
		movq qword[ebp-16], xmm1
		cvtsi2ss xmm2, dword[ebp-8]
		movss dword[ebp-8], xmm2
		mov dword[ebp-4], 0
		
		movss xmm0, dword[PERLIN3D_SCALER]
		shufps xmm0, xmm0, 0b00000000
		movups xmm1, [ebp-16]
		mulps xmm1, xmm0
		movups [esi], xmm1
		
		push esi
		call vec3_normalize
		add esp, 4
		
		add esi, 16
		dec edi
		jnz perlin3d_init_generate_loop_start
		
	;make the marginal vectors the same
	mov esi, PERLIN3D_VECTOR_GRID
	mov edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_BYTES]
	sub edi, 16
	add edi, PERLIN3D_VECTOR_GRID
	mov ecx, esi
	mov esi, edi
	mov edi, ecx
	mov ebx, dword[PERLIN3D_VECTOR_GRID_WIDTH]
	perlin3d_init_marginal_z_outer_loop_start:
		mov eax, dword[PERLIN3D_VECTOR_GRID_WIDTH]
		perlin3d_init_marginal_z_inner_loop_start:
			mov ecx, dword[esi]
			mov dword[edi], ecx
			mov edx, dword[esi+4]
			mov dword[edi+4], edx
			mov ecx, dword[esi+8]
			mov dword[edi+8], ecx
		
			add esi, dword[PERLIN3D_VECTOR_GRID_WIDTH_BYTES]
			add edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_BYTES]
			dec eax
			jnz perlin3d_init_marginal_z_inner_loop_start
	
		dec ebx
		jnz perlin3d_init_marginal_z_outer_loop_start
	
	
	mov esi, PERLIN3D_VECTOR_GRID
	mov edi, PERLIN3D_VECTOR_GRID
	add edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_SQUARED_BYTES]
	sub edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_BYTES]
	mov ebx, dword[PERLIN3D_VECTOR_GRID_WIDTH]
	perlin3d_init_marginal_y_outer_loop_start:
		mov eax, dword[PERLIN3D_VECTOR_GRID_WIDTH]
		perlin3d_init_marginal_y_inner_loop_start:
			movsd
			movsd
			movsd
			add esi, 4
			add edi, 4
		
			dec eax
			jnz perlin3d_init_marginal_y_inner_loop_start
	
		sub esi, dword[PERLIN3D_VECTOR_GRID_WIDTH_BYTES]
		sub edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_BYTES]
		add esi, dword[PERLIN3D_VECTOR_GRID_WIDTH_SQUARED_BYTES]
		add edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_SQUARED_BYTES]
		dec ebx
		jnz perlin3d_init_marginal_y_outer_loop_start
		
	mov esi, PERLIN3D_VECTOR_GRID
	mov edi, PERLIN3D_VECTOR_GRID
	add edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_CUBED_BYTES]
	sub edi, dword[PERLIN3D_VECTOR_GRID_WIDTH_SQUARED_BYTES]
	mov ebx, dword[PERLIN3D_VECTOR_GRID_WIDTH]
	perlin3d_init_marginal_x_outer_loop_start:
		mov eax, dword[PERLIN3D_VECTOR_GRID_WIDTH]
		perlin3d_init_marginal_x_inner_loop_start:
			movsd
			movsd
			movsd
			add esi, 4
			add edi, 4
		
			dec eax
			jnz perlin3d_init_marginal_x_inner_loop_start
	
		dec ebx
		jnz perlin3d_init_marginal_x_outer_loop_start
		
	;set initialized flag
	mov dword[PERLIN3D_INITIALIZED], 69
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
perlin3d_sample:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16			;pos mod 1		16
	sub esp, 16			;index (int)	32
	sub esp, 16			;interpolator	48
	sub esp, 32			;helper float[8]	80
	sub esp, 16			;dot product vector	96 //helper for the dot product loop
	
	;calculate pos mod 1
	mov eax, dword[ebp+20]
	mov dword[ebp-16], eax
	mov ecx, dword[ebp+24]
	mov dword[ebp-12], ecx
	mov edx, dword[ebp+28]
	mov dword[ebp-8], edx
	mov dword[ebp-4], 0
	
	movups xmm0, [ebp-16]
	roundps xmm1, xmm0, 0b0001		;floor
	subps xmm0, xmm1
	movups [ebp-16], xmm0
	
	;calculate index and interpolator
	;pos mod 1 still in xmm0
	movss xmm1, dword[PERLIN3D_INTERPOLATOR_SCALER]
	shufps xmm1, xmm1, 0b00000000
	mulps xmm0, xmm1
	roundps xmm1, xmm0, 0b0001
	movups [ebp-32], xmm1			;index (float)
	subps xmm0, xmm1
	movups [ebp-48], xmm0		;interpolator
	
	movq xmm0, qword[ebp-32]
	cvtps2pi mm0, xmm0
	movq qword[ebp-32], mm0
	emms
	movss xmm1, dword[ebp-24]
	cvtss2si eax, xmm1
	mov dword[ebp-24], eax
	
	;calculate dot products
	mov dword[ebp-84], 0
	mov eax, dword[ebp-48]
	mov dword[ebp-96], eax
	xor esi, esi
	perlin3d_sample_dot_product_x_loop_start:
		mov eax, dword[ebp-44]
		mov dword[ebp-92], eax
		xor edi, edi
		perlin3d_sample_dot_product_y_loop_start:
			mov eax, dword[ebp-40]
			mov dword[ebp-88], eax
			xor ebx, ebx
			perlin3d_sample_dot_product_z_loop_start:
				mov eax, dword[ebp-32]
				add eax, esi
				imul eax, dword[PERLIN3D_VECTOR_GRID_WIDTH]
				add eax, dword[ebp-28]
				add eax, edi
				imul eax, dword[PERLIN3D_VECTOR_GRID_WIDTH]
				add eax, dword[ebp-24]
				add eax, ebx
				shl eax, 4
				add eax, PERLIN3D_VECTOR_GRID
				push eax
				lea ecx, [ebp-96]
				push ecx
				call vec4_dot
				add esp, 8
				
				mov eax, esi
				shl eax, 1
				add eax, edi
				shl eax, 1
				add eax, ebx
				shl eax, 2
				lea eax, [eax+ebp-80]
				fstp dword[eax]

				movss xmm2, dword[ebp-88]
				subss xmm2, dword[ONE]
				movss dword[ebp-88], xmm2
				inc ebx
				cmp ebx, 1
				jle perlin3d_sample_dot_product_z_loop_start
		
			movss xmm1, dword[ebp-92]
			subss xmm1, dword[ONE]
			movss dword[ebp-92], xmm1
			inc edi
			cmp edi, 1
			jle perlin3d_sample_dot_product_y_loop_start
	
		movss xmm0, dword[ebp-96]
		subss xmm0, dword[ONE]
		movss dword[ebp-96], xmm0
		inc esi
		cmp esi, 1
		jle perlin3d_sample_dot_product_x_loop_start
	
	;smoothstep the interpolators
	lea eax, [ebp-48]
	push eax
	call vec4_smoothstep1
	
	;interpolate the dot products
	;x axis
	movss xmm0, dword[ebp-48]
	shufps xmm0, xmm0, 0b00000000
	movups xmm1, [ebp-64]
	movups xmm2, [ebp-80]
	subps xmm1, xmm2
	vfmadd213ps xmm1, xmm0, xmm2
	
	;y axis
	;lerp(xmm[63:0], xmm[127:64], interpolator.y)
	movss xmm0, dword[ZERO]
	movaps xmm2, xmm1
	shufps xmm2, xmm0, 0b00001110
	subps xmm2, xmm1
	movss xmm0, dword[ebp-44]
	shufps xmm0, xmm0, 0b00000000
	
	vfmadd213ps xmm2, xmm0, xmm1
	movq qword[ebp-80], xmm2
	
	;z axis
	movss xmm0, dword[ebp-40]
	movss xmm1, dword[ebp-76]
	movss xmm2, dword[ebp-80]
	subss xmm1, xmm2
	vfmadd213ss xmm1, xmm0, xmm2
	movss dword[ebp-80], xmm1
	
	perlin3d_sample_end:
	;set return value
	fld dword[ebp-80]
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret