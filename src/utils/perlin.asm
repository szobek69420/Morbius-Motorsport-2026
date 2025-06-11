[BITS 32]

section .rodata use32
	;the angles of the grid point vectors
	;https://youtu.be/9B89kwHvTN4?si=v68YgUcEs0hHRp2R
	TEXTURE_2D_ANGLE_RESOLUTION dd 11
	TEXTURE_2D_ANGLE_RESOLUTION_FLOAT dd 11.0
	TEXTURE_2D_ANGLE_DATA_SIZE_BYTES equ 484		;sizeof(float)*11*11, each slot contains an angle
	
	TEXTURE_3D_VECTOR_RESOLUTION dd 11
	TEXTURE_3D_VECTOR_RESOLUTION_FLOAT dd 11.0
	TEXTURE_3D_VECTOR_DATA_SIZE_BYTES equ 15972		;sizeof(vec3)*TEXTURE_3D_VECTOR_RESOLUTION^3, each slot contains a 3d vector
	
	SCALER dd 0.0000958737993		;PI/2^15  //2^15 is the maximum absolute value of a 16 bit signed integer
	SCALER2 dd 0.00003051757		;1/2^15
	
	PERLIN_2D_SCALER dd 1.4142135623731		;so that the 2d perlin noise has possible values in about [-1;1]
	PERLIN_3D_SCALER dd 1.1547005384		;so that the 3d perlin noise has possible values in about [-1;1]
	
	ZERO dd 0.0
	ONE dd 1.0
	
	VERY_SMALL_NUMBER dd 0.0000001
	ALMOST_ONE dd 0.9999999
	
	RAND_MAX dd 32768.0		;2^15, the maximum absolute value of a 16-bit signed integer
	
	HALF_PI dd 1.570796327
	
	POS_X dd 1.0, 0.0, 0.0
	POS_Y dd 0.0, 1.0, 0.0
	POS_Z dd 0.0, 0.0, 1.0
	NEG_X dd -1.0, 0.0, 0.0
	NEG_Y dd 0.0, -1.0, 0.0
	NEG_Z dd 0.0, 0.0, -1.0
	
	error_2d_not_initialized db "perlin_sample2d: you have to call perlin_init2d before sampling",10,0
	error_2d_not_initialized2 db "perlin_deinit2d: you have to call perlin_init2d before sampling",10,0
	
	error_3d_not_initialized db "perlin_sample3d: you have to call perlin_init3d before sampling",10,0
	error_3d_not_initialized2 db "perlin_deinit3d: you have to call perlin_init3d before sampling",10,0
	
	print_two_ints_nl db "%d %d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_float_nl db "%f",10,0
	print_two_floats_nl db "%f %f",10,0
	print_three_floats_nl db "%f %f %f",10,0
	
	test_text db "womb raider",10,0
	
section .bss use32
	TEXTURE_2D_ANGLE_DATA resb TEXTURE_2D_ANGLE_DATA_SIZE_BYTES		;row major order
	TEXTURE_3D_VECTOR_DATA resb TEXTURE_3D_VECTOR_DATA_SIZE_BYTES		;x,y,z order
	
section .data use32
	;these variables are initialized by an init2d call
	TEXTURE_2D_INITIALIZED dd 0
	
	TEXTURE_2D_RESOLUTION dd 0
	TEXTURE_2D_RESOLUTION_FLOAT dd 0.0
	TEXTURE_2D_DATA_SIZE_BYTES dd 0		;the size of the sample texture
	TEXTURE_2D_DATA dd 0				;the sampled values
	
	
	TEXTURE_3D_INITIALIZED dd 0
	
	TEXTURE_3D_RESOLUTION dd 0
	TEXTURE_3D_RESOLUTION_FLOAT dd 0.0
	TEXTURE_3D_DATA_SIZE_BYTES dd 0
	TEXTURE_3D_DATA dd 0
	
section .text use32

	global perlin_init2d			;void perlin_init2d(int resolution)			//resolution is the number of points on the grid along one axis, not the number of squares
	global perlin_deinit2d			;void perlin_deinit2d()
	global perlin_sample2d			;float perlin_sample2d(float x, float y)	//pushes the return value onto the FPU stack
	
	global perlin_init3d			;void perlin_init3d(int resolution)			
	global perlin_deinit3d			;void perlin_deinit3d()
	global perlin_sample3d			;float perlin_sample3d(float x, float y, float z)	//pushes the return value onto the FPU stack
	
	extern my_malloc
	extern my_free
	
	extern my_printf
	
	extern math_repeat
	extern math_lerp
	extern math_smoothstep1
	extern math_clamp
	extern math_acos
	
	extern vec3_dot
	extern vec3_print
	
perlin_init2d:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 2				;random short				2
	sub esp, 2				;random short padding		4
	
	sub esp, 4				;current left1 value		8
	sub esp, 4				;current left2 value		12
	sub esp, 4				;current right1 value		16
	sub esp, 4				;current right2 value		20
	
	sub esp, 4				;sample grid step			24
	sub esp, 4				;current sample grid pos x	28
	sub esp, 4				;current sample grid pos y	32
	
	sub esp, 4				;current x distance			36
	sub esp, 4				;current y distance			40
	sub esp, 4				;one minus current x distance	44
	sub esp, 4				;one minus current y distance	48
	sub esp, 4				;left1 x angle index		52
	sub esp, 4				;left1 y angle index		56
	
	
	;fill up the angle texture with numbers in [-pi; pi)
	mov eax, 69420					;random seen in eax
	mov esi, TEXTURE_2D_ANGLE_DATA	;current angle in esi
	mov edi, dword[TEXTURE_2D_ANGLE_RESOLUTION]
	imul edi, dword[TEXTURE_2D_ANGLE_RESOLUTION]
	perlin_init2d_angle_loop_start:
		;calculate the angle
		mov word[ebp-2], ax
		
		fild word[ebp-2]
		fmul dword[SCALER]
		fstp dword[esi]
	
		;update the random value in eax
		imul eax, 1103515245 
		add eax, 12345
	
		;continue
		add esi, 4
		dec edi
		test edi, edi
		jnz perlin_init2d_angle_loop_start
		
	;set the values in the last row the same as the values in the first row (for vertical periodicity)
	mov ebx, dword[TEXTURE_2D_ANGLE_RESOLUTION]		;index in ebx
	mov esi, TEXTURE_2D_ANGLE_DATA					;current first row element in esi
	mov edi, dword[TEXTURE_2D_ANGLE_RESOLUTION]
	imul edi, edi
	sub edi, dword[TEXTURE_2D_ANGLE_RESOLUTION]
	shl edi, 2
	add edi, esi									;current last row element in edi
	perlin_init2d_angle_last_row_loop_start:
		mov eax, dword[esi]
		mov dword[edi], eax
	
		add esi, 4
		add edi, 4
		dec ebx
		test ebx, ebx
		jnz perlin_init2d_angle_last_row_loop_start
		
	;set the values in the last column the same as the values in the first column (for horizontal periodicity)
	mov edx, dword[TEXTURE_2D_ANGLE_RESOLUTION] 
	
	mov ebx, edx									;index in ebx
	mov esi, TEXTURE_2D_ANGLE_DATA					;current first column element in esi
	mov edi, edx
	dec edi
	shl edi, 2
	add edi, esi									;current last column element in edi
	perlin_init2d_angle_last_column_loop_start:
		mov eax, dword[esi]
		mov dword[edi], eax
		
		lea esi, [esi+4*edx]
		lea edi, [edi+4*edx]
		dec ebx
		test ebx, ebx
		jnz perlin_init2d_angle_last_column_loop_start
		
	;init the sample texture variables
	mov eax, dword[ebp+20]
	mov dword[TEXTURE_2D_RESOLUTION], eax
	fild dword[TEXTURE_2D_RESOLUTION]
	fstp dword[TEXTURE_2D_RESOLUTION_FLOAT]
	
	mov eax, dword[TEXTURE_2D_RESOLUTION]
	imul eax, eax
	shl eax, 2
	mov dword[TEXTURE_2D_DATA_SIZE_BYTES], eax
	
	push eax
	call my_malloc
	mov dword[TEXTURE_2D_DATA], eax
	
	;calculate sample grid step
	fld1
	mov eax, dword[TEXTURE_2D_RESOLUTION]
	dec eax
	mov dword[ebp-24], eax
	fidiv dword[ebp-24]
	mov eax, dword[TEXTURE_2D_ANGLE_RESOLUTION]
	dec eax
	mov dword[ebp-24], eax
	fimul dword[ebp-24]
	fsub dword[VERY_SMALL_NUMBER]		;so that in the sampling part the distances will always be slightly below the max value, thus not having to handle the edge case of being on the border
	fstp dword[ebp-24]
	
	;sample the angle grid
	mov ebx, dword[TEXTURE_2D_DATA]		;current data slot in ebx
	xor esi, esi						;y index
	mov dword[ebp-32], 0				;current sample grid pos y
	perlin_init2d_sample_y_loop_start:
		;calculate y distance
		push dword[ONE]
		push dword[ebp-32]
		call math_repeat
		fstp dword[ebp-40]		;y distance
		add esp, 8
		
		fld1
		fsub dword[ebp-40]
		fstp dword[ebp-48]		;one minus y distance
		
		fld dword[ebp-32]
		fsub dword[ebp-40]
		frndint
		fistp dword[ebp-56]		;y angle index
		
		
		xor edi, edi						;x index
		mov dword[ebp-28], 0				;current sample grid pos x
		
		perlin_init2d_sample_x_loop_start:
			;calculate x distance
			push dword[ONE]
			push dword[ebp-28]
			call math_repeat
			fstp dword[ebp-36]		;x distance
			add esp, 8
			
			fld1
			fsub dword[ebp-36]
			fstp dword[ebp-44]		;one minus x distance
			
			fld dword[ebp-28]
			fsub dword[ebp-36]
			frndint
			fistp dword[ebp-52]		;x angle index
			
			;calculate left1 angle pos
			mov eax, dword[ebp-52]	;x angle index in eax
			mov ecx, dword[ebp-56]	;y angle index in ecx
			imul ecx, dword[TEXTURE_2D_ANGLE_RESOLUTION]
			add eax, ecx
			shl eax, 2
			add eax, TEXTURE_2D_ANGLE_DATA
			
			;calculate left1 angle value
			fld dword[eax]
			fsincos
			fmul dword[ebp-36]
			fstp dword[ebp-8]
			fmul dword[ebp-40]
			fadd dword[ebp-8]
			fchs					;x and y distance should be used as a negative amplitude
			fstp dword[ebp-8]
			
			;calculate right1 angle value
			add eax, 4
			fld dword[eax]
			fsincos
			fmul dword[ebp-44]
			fstp dword[ebp-12]
			fmul dword[ebp-40]
			fchs					;y distance should be used as a negative amplitude
			fadd dword[ebp-12]
			fstp dword[ebp-12]
			
			;calculate left2 angle value
			mov ecx, dword[TEXTURE_2D_ANGLE_RESOLUTION]
			dec ecx
			shl ecx, 2
			add eax, ecx
			fld dword[eax]
			fsincos
			fmul dword[ebp-36]
			fchs					;x distance should be used as a negative amplitude
			fstp dword[ebp-16]
			fmul dword[ebp-48]
			fadd dword[ebp-16]
			fstp dword[ebp-16]
			
			;calculate right2 angle value
			add eax, 4
			fld dword[eax]
			fsincos
			fmul dword[ebp-40]
			fstp dword[ebp-20]
			fmul dword[ebp-48]
			fadd dword[ebp-20]
			fstp dword[ebp-20]
			
			;interpolate on the y axis
			movss xmm0, dword[ebp-40]
			movss xmm1, dword[ebp-48]
			
			movss xmm2, dword[ebp-8]
			movss xmm3, dword[ebp-16]
			mulss xmm2, xmm1
			mulss xmm3, xmm0
			addss xmm2, xmm3
			movss dword[ebp-8], xmm2
			
			movss xmm2, dword[ebp-12]
			movss xmm3, dword[ebp-20]
			mulss xmm2, xmm1
			mulss xmm3, xmm0
			addss xmm2, xmm3
			movss dword[ebp-12], xmm2
			
			;interpolate on the x axis
			movss xmm0, dword[ebp-36]
			movss xmm1, dword[ebp-44]
			movss xmm2, dword[ebp-8]
			movss xmm3, dword[ebp-12]
			mulss xmm2, xmm1
			mulss xmm3, xmm0
			addss xmm2, xmm3
			
			;scale and save the value
			movss xmm0, dword[PERLIN_2D_SCALER]
			mulss xmm2, xmm0
			movss dword[ebx], xmm2
			
			
			;update current x pos and continue
			movss xmm0, dword[ebp-28]
			movss xmm1, dword[ebp-24]
			addss xmm0, xmm1
			movss dword[ebp-28], xmm0
			
			add ebx, 4
			
			inc edi
			cmp edi, dword[TEXTURE_2D_RESOLUTION]
			jl perlin_init2d_sample_x_loop_start
		
		;update current y pos and continue
		movss xmm0, dword[ebp-32]
		movss xmm1, dword[ebp-24]
		addss xmm0, xmm1
		movss dword[ebp-32], xmm0
		
		inc esi
		cmp esi, dword[TEXTURE_2D_RESOLUTION]
		jl perlin_init2d_sample_y_loop_start
	
	
	;set the flag
	mov dword[TEXTURE_2D_INITIALIZED], 69
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	

perlin_deinit2d:
	push ebp
	mov ebp, esp
	
	test dword[TEXTURE_2D_INITIALIZED], 0xffffffff
	jnz perlin_deinit2d_no_problem
		push error_2d_not_initialized2
		call my_printf
		add esp, 4
		jmp perlin_deinit2d_end
	
	perlin_deinit2d_no_problem:
	
	push dword[TEXTURE_2D_DATA]
	call my_free
	add esp, 4
	mov dword[TEXTURE_2D_DATA], 0
	
	mov dword[TEXTURE_2D_INITIALIZED], 0
	
	perlin_deinit2d_end:
	mov esp, ebp
	pop ebp
	ret


perlin_sample2d:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;projected x value			;4
	sub esp, 4			;projected y value			;8
	
	sub esp, 4			;x sample index				;12
	sub esp, 4			;y sample index				;16
	
	sub esp, 4			;sample distance x			;20
	sub esp, 4			;sample distance y			;24
	sub esp, 4			;one minus sample distance x;28
	sub esp, 4			;one minus sample distance y;32
	
	sub esp, 4			;helper1					;36
	sub esp, 4			;helper2					;40
	
	cmp dword[TEXTURE_2D_INITIALIZED], 0
	jne perlin_sample2d_initialized
		push error_2d_not_initialized
		call my_printf
		add esp, 4
		fldz
		jmp perlin_sample2d_end
	
	perlin_sample2d_initialized:
	
	;calculate the projected values (remainder of one, and clamp it slightly below one)
	push dword[ONE]
	push dword[ebp+8]
	call math_repeat
	fstp dword[ebp-4]
	mov eax, dword[ebp+12]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-8]
	add esp, 8
	
	push dword[ALMOST_ONE]
	push dword[ZERO]
	push dword[ebp-4]
	call math_clamp
	fstp dword[ebp-4]
	mov eax, dword[ebp-8]
	mov dword[esp], eax
	call math_clamp
	fstp dword[ebp-8]
	add esp, 12
	
	
	;get sample indices and sample distances
	fild dword[TEXTURE_2D_RESOLUTION]
	fmul dword[ebp-4]
	fist dword[ebp-12]		;x sample index
	fisub dword[ebp-12]
	fst dword[ebp-20]		;x sample distance
	fld1
	fsub st0, st1
	fstp dword[ebp-28]		;one minus x sample distance
	fstp st0
	
	fild dword[TEXTURE_2D_RESOLUTION]
	fmul dword[ebp-8]
	fist dword[ebp-16]		;y sample index
	fisub dword[ebp-16]
	fst dword[ebp-24]		;y sample distance
	fld1
	fsub st0, st1
	fstp dword[ebp-32]		;one minus y sample distance
	fstp st0
	
	;interpolate along the x axis
	mov eax, dword[TEXTURE_2D_DATA]
	mov ecx, dword[ebp-16]
	imul ecx, dword[TEXTURE_2D_RESOLUTION]
	add ecx, dword[ebp-12]
	shl ecx, 2
	add eax, ecx
	
	movss xmm0, dword[ebp-20]
	movss xmm1, dword[ebp-28]
	
	movss xmm2, dword[eax]
	movss xmm3, dword[eax+4]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-36], xmm2
	
	mov ecx, dword[TEXTURE_2D_RESOLUTION]
	shl ecx, 2
	add eax, ecx
	movss xmm2, dword[eax-4]
	movss xmm3, dword[eax]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-40], xmm2
	
	;interpolate along the y axis
	movss xmm0, dword[ebp-24]
	movss xmm1, dword[ebp-32]
	movss xmm2, dword[ebp-36]
	movss xmm3, dword[ebp-40]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-36], xmm2
	
	;set return value
	fld dword[ebp-36]

	perlin_sample2d_end:
	mov esp, ebp
	pop ebp
	ret
	
	
perlin_init3d:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4		;sample grid step					;4
	sub esp, 4		;current grid pos x					;8
	sub esp, 4		;current grid pos y					;12
	sub esp, 4		;current grid pos z					;16
	
	sub esp, 4		;sizeof(vec3)*vec_res				;20
	sub esp, 4		;sizeof(vec3)*vec_res^2				;24
	
	;calculate helper values
	mov eax, dword[TEXTURE_3D_VECTOR_RESOLUTION]
	imul eax, 12
	mov dword[ebp-20], eax
	imul eax, dword[TEXTURE_3D_VECTOR_RESOLUTION]
	mov dword[ebp-24], eax
	
	;fill up the vector texture with random unit vectors
	mov eax, 6942069				;random seed in eax
	mov esi, TEXTURE_3D_VECTOR_DATA	;current vector in esi
	mov edi, dword[TEXTURE_3D_VECTOR_RESOLUTION]
	mov ecx, edi
	imul edi, ecx
	imul edi, ecx					;index in edi
	perlin_init3d_vector_loop_start:
		;calculate the random values
		imul eax, 1103515245 
		add eax, 12345
		push eax
		imul eax, 1103515245
		add eax, 12345
		push eax
		push esi
		call perlin_init3d_gen_random_vec
		mov eax, dword[esp+4]				;restore previous random state
		add esp, 12
	
		;continue
		add esi, 12
		dec edi
		test edi, edi
		jnz perlin_init3d_vector_loop_start
		
		
	;set the values on the positive end the same as on the negative end to ensure the periodicity of the noise
	mov eax, TEXTURE_3D_VECTOR_DATA				;current vector in eax
	xor esi, esi		;x index in esi
	perlin_init3d_periodicity_x_loop_start:
		xor edi, edi		;y index in edi
		perlin_init3d_periodicity_y_loop_start:
			xor ebx, ebx		;z index in ebx
			perlin_init3d_periodicity_z_loop_start:
				test esi, esi
				jnz perlin_init3d_periodicity_z_loop_no_x
					mov ecx, eax
					add ecx, TEXTURE_3D_VECTOR_DATA_SIZE_BYTES
					sub ecx, dword[ebp-24]
					
					mov edx, dword[eax]
					mov dword[ecx], edx
					mov edx, dword[eax+4]
					mov dword[ecx+4], edx
					mov edx, dword[eax+8]
					mov dword[ecx+8], ecx
				
				perlin_init3d_periodicity_z_loop_no_x:
				
				
				test edi, edi
				jmp perlin_init3d_periodicity_z_loop_no_y
					mov ecx, eax
					add ecx, dword[ebp-24]
					sub ecx, dword[ebp-20]
					
					mov edx, dword[eax]
					mov dword[ecx], edx
					mov edx, dword[eax+4]
					mov dword[ecx+4], edx
					mov edx, dword[eax+8]
					mov dword[ecx+8], ecx
					
				perlin_init3d_periodicity_z_loop_no_y:
				
				
				test ebx, ebx
				jmp perlin_init3d_periodicity_z_loop_no_z
					mov ecx, eax
					add ecx, dword[ebp-20]
					sub ecx, 12
					
					mov edx, dword[eax]
					mov dword[ecx], edx
					mov edx, dword[eax+4]
					mov dword[ecx+4], edx
					mov edx, dword[eax+8]
					mov dword[ecx+8], ecx
					
				perlin_init3d_periodicity_z_loop_no_z:
				
				
				add eax, 12
				
				inc ebx
				cmp ebx, dword[TEXTURE_3D_VECTOR_RESOLUTION]
				jl perlin_init3d_periodicity_z_loop_start
		
			inc edi
			cmp edi, dword[TEXTURE_3D_VECTOR_RESOLUTION]
			jl perlin_init3d_periodicity_y_loop_start
		
		inc esi
		cmp esi, dword[TEXTURE_3D_VECTOR_RESOLUTION]
		jl perlin_init3d_periodicity_x_loop_start

		
	;set values and alloc space
	mov eax, dword[ebp+20]
	mov dword[TEXTURE_3D_RESOLUTION], eax
	fild dword[TEXTURE_3D_RESOLUTION]
	fstp dword[TEXTURE_3D_RESOLUTION_FLOAT]
	
	mov ecx, eax
	imul eax, ecx
	imul eax, ecx
	shl eax, 2
	mov dword[TEXTURE_3D_DATA_SIZE_BYTES], eax
	
	push eax
	call my_malloc
	mov dword[TEXTURE_3D_DATA], eax
	add esp, 4
	
	
	;calculate sample grid step
	fld1
	mov eax, dword[TEXTURE_3D_RESOLUTION]
	dec eax
	mov dword[ebp-4], eax
	fidiv dword[ebp-4]
	;fsub dword[VERY_SMALL_NUMBER]		;so that in the sampling part the distances will always be slightly below the max value, thus not having to handle the edge case of being on the border
	fstp dword[ebp-4]
	
	;sample the grid
	mov ebx, dword[TEXTURE_3D_DATA]		;current data value in ebx
	
	mov dword[ebp-8], 0					;x pos is 0
	mov esi, dword[TEXTURE_3D_RESOLUTION]	;x index in esi
	perlin_init3d_sample_x_loop_start:
		push esi								;save x index
		mov dword[ebp-12], 0					;y pos is 0
		mov esi, dword[TEXTURE_3D_RESOLUTION]	;y index in esi
		perlin_init3d_sample_y_loop_start:
			push esi								;save y index
			mov dword[ebp-16], 0					;z pos is 0
			mov esi, dword[TEXTURE_3D_RESOLUTION]	;z index in esi
			perlin_init3d_sample_z_loop_start:
				push dword[ebp-16]
				push dword[ebp-12]
				push dword[ebp-8]
				call perlin_init3d_helper
				movss dword[ebx], xmm0
				add esp, 12
			
				movss xmm0, dword[ebp-4]
				movss xmm1, dword[ebp-16]
				addss xmm1, xmm0
				movss dword[ebp-16], xmm1
				
				add ebx, 4
				
				dec esi
				test esi, esi
				jnz perlin_init3d_sample_z_loop_start
			pop esi									;restore y index
			
			movss xmm0, dword[ebp-4]
			movss xmm1, dword[ebp-12]
			addss xmm1, xmm0
			movss dword[ebp-12], xmm1
			
			dec esi
			test esi, esi
			jnz perlin_init3d_sample_y_loop_start
		pop esi									;restore x index
	
		movss xmm0, dword[ebp-4]
		movss xmm1, dword[ebp-8]
		addss xmm1, xmm0
		movss dword[ebp-8], xmm1
		
		dec esi
		test esi, esi
		jnz perlin_init3d_sample_x_loop_start
	
	mov dword[TEXTURE_3D_INITIALIZED], 69
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
;float perlin_init3d_helper(float x, float y, float z)
;samples directly from the vector grid
;RETURNS THE RESULT IN XMM0!!!
perlin_init3d_helper:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4		;padding
	sub esp, 4		;projected x value			;8
	sub esp, 4		;projected y value			;12
	sub esp, 4		;projected z value			;16
	
	sub esp, 4		;padding
	sub esp, 4		;smoothstepped x distance	;24
	sub esp, 4		;smoothstepped y distance	;28
	sub esp, 4		;smoothstepped z distance	;32
	
	sub esp, 4		;padding
	sub esp, 4		;one minus ss x distance	;40
	sub esp, 4		;one minus ss y distance 	;44
	sub esp, 4		;one minus ss z distance	;48
	
	sub esp, 4		;padding
	sub esp, 4		;vector000 x index			;56
	sub esp, 4		;vector000 y index			;60
	sub esp, 4		;vector000 z index			;64
	
	sub esp, 4		;value000					;68
	sub esp, 4		;value001					;72
	sub esp, 4		;value010					;76
	sub esp, 4		;value011					;80
	sub esp, 4		;value100					;84
	sub esp, 4		;value101					;88
	sub esp, 4		;value110					;92
	sub esp, 4		;value111					;96
	
	sub esp, 4		;vector000 address			;100
	sub esp, 4		;sizeof(vec3)*vec_res^2		;104
	sub esp, 4		;sizeof(vec3)*vec_res		;108
	
	sub esp, 4		;helper vec3				;120
	
	;calculate projected value
	mov dword[ebp-4], 0	;set the padding to 0
	
	push dword[ONE]
	push dword[ebp+20]
	call math_repeat
	fstp dword[ebp-8]
	mov eax, dword[ebp+24]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-12]
	mov eax, dword[ebp+28]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-16]
	add esp, 8

	
	movss xmm0, dword[TEXTURE_3D_VECTOR_RESOLUTION_FLOAT]
	movss xmm1, dword[ONE]
	subss xmm0, xmm1
	shufps xmm0, xmm0, 0b00000000
	movups xmm1, [ebp-16]
	mulps xmm1, xmm0
	movups [ebp-16], xmm1
	
	
	;calculate non-smoothstepped distances
	push dword[ONE]
	push dword[ebp-8]
	call math_repeat
	fstp dword[ebp-24]
	mov eax, dword[ebp-12]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-28]
	mov eax, dword[ebp-16]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-32]
	add esp, 8
	
	;calculate indices
	movups xmm0, [ebp-16]
	movups xmm1, [ebp-32]
	subps xmm0, xmm1
	roundps xmm0, xmm0, 0b100			;mode[2]==1 means overriding the default round control, mode[1:0]==00 means rounding to the nearest integer
	movups [ebp-64], xmm0
	fld dword[ebp-56]
	fistp dword[ebp-56]
	fld dword[ebp-60]
	fistp dword[ebp-60]
	fld dword[ebp-64]
	fistp dword[ebp-64]
	
	
	;smoothstep values
	push dword[ebp-24]
	call math_smoothstep1
	fstp dword[ebp-24]
	push dword[ebp-28]
	call math_smoothstep1
	fstp dword[ebp-28]
	push dword[ebp-32]
	call math_smoothstep1
	fstp dword[ebp-32]
	add esp, 12


	movss xmm0, dword[ONE]
	shufps xmm0, xmm0, 0b00000000
	movups xmm1, [ebp-32]
	subps xmm0, xmm1
	movups [ebp-48], xmm0
	
	
	
	;calculate base address and helpers
	mov eax, dword[TEXTURE_3D_VECTOR_RESOLUTION]
	mov ecx, eax
	imul ecx, 12
	mov dword[ebp-108], ecx
	imul ecx, eax
	mov dword[ebp-104], ecx
	
	mov eax, dword[ebp-56]
	imul eax, dword[ebp-104]
	mov ecx, dword[ebp-60]
	imul ecx, dword[ebp-108]
	mov edx, dword[ebp-64]
	imul edx, 12
	add eax, ecx
	add eax, edx
	add eax, TEXTURE_3D_VECTOR_DATA
	mov dword[ebp-100], eax
	
	;calculate values
	lea ebx, [ebp-68]		;current value in ebx
	xor esi, esi			;index in esi
	perlin_init3d_helper_value_loop_start:
		mov edi, TEXTURE_3D_VECTOR_DATA		;current vector will be in edi
		
		test esi, 0b100
		jnz perlin_init3d_helper_value_loop_pos_x
			;neg x
			mov eax, dword[ebp-24]
			mov dword[ebp-120], eax
			jmp perlin_init3d_helper_value_loop_x_done
		perlin_init3d_helper_value_loop_pos_x:
			;pos x
			mov eax, dword[ebp-40]
			xor eax, 0x80000000				;has to be negated
			mov dword[ebp-120], eax
			
			add edi, dword[ebp-104]
		perlin_init3d_helper_value_loop_x_done:
		
		test esi, 0b010
		jnz perlin_init3d_helper_value_loop_pos_y
			;neg y
			mov eax, dword[ebp-28]
			mov dword[ebp-116], eax
			jmp perlin_init3d_helper_value_loop_y_done
		perlin_init3d_helper_value_loop_pos_y:
			;pos y
			mov eax, dword[ebp-44]
			xor eax, 0x80000000				;has to be negated
			mov dword[ebp-116], eax
			
			add edi, dword[ebp-108]
		perlin_init3d_helper_value_loop_y_done:
		
		test esi, 0b001
		jnz perlin_init3d_helper_value_loop_pos_z
			;neg z
			mov eax, dword[ebp-32]
			mov dword[ebp-112], eax
			jmp perlin_init3d_helper_value_loop_z_done
		perlin_init3d_helper_value_loop_pos_z:
			;pos z
			mov eax, dword[ebp-48]
			xor eax, 0x80000000				;has to be negated
			mov dword[ebp-112], eax
			
			add edi, 12
		perlin_init3d_helper_value_loop_z_done:
		
		lea eax, [ebp-120]
		push eax
		push edi
		call vec3_dot
		fstp dword[ebx]
		add esp, 8
		
		sub ebx, 4
		inc esi
		cmp esi, 8
		jl perlin_init3d_helper_value_loop_start
		
	;interpolate along the z axis
	push dword[ebp-32]
	sub esp, 8
	mov eax, dword[ebp-68]
	mov dword[esp], eax
	mov ecx, dword[ebp-72]
	mov dword[esp+4], ecx
	call math_lerp
	fstp dword[ebp-68]
	mov eax, dword[ebp-76]
	mov dword[esp], eax
	mov ecx, dword[ebp-80]
	mov dword[esp+4], ecx
	call math_lerp
	fstp dword[ebp-76]
	mov eax, dword[ebp-84]
	mov dword[esp], eax
	mov ecx, dword[ebp-88]
	mov dword[esp+4], ecx
	call math_lerp
	fstp dword[ebp-84]
	mov eax, dword[ebp-92]
	mov dword[esp], eax
	mov ecx, dword[ebp-96]
	mov dword[esp+4], ecx
	call math_lerp
	fstp dword[ebp-92]
	add esp, 12
	
	;interpolate along the y axis
	push dword[ebp-28]
	sub esp, 8
	mov eax, dword[ebp-68]
	mov dword[esp], eax
	mov ecx, dword[ebp-76]
	mov dword[esp+4], ecx
	call math_lerp
	fstp dword[ebp-68]
	mov eax, dword[ebp-84]
	mov dword[esp], eax
	mov ecx, dword[ebp-92]
	mov dword[esp+4], ecx
	call math_lerp
	fstp dword[ebp-84]
	add esp, 12
	
	;interpolate along the x axis
	push dword[ebp-24]
	push dword[ebp-84]
	push dword[ebp-68]
	call math_lerp
	fstp dword[ebp-68]
	add esp, 12
	
	;set return value
	movss xmm0, dword[ebp-68]
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	

	
	
;void perlin_init3d_gen_random_vec(vec3* buffer, int random1, int random2)
;random1 and random2 are just two random integers
;generates a random unit vector
perlin_init3d_gen_random_vec:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;azimuth angle		;4
	sub esp, 4			;polar angle		;8
	
	;generate azimuth angle [-pi; pi)
	mov eax, dword[ebp+12]
	mov word[ebp-4], ax
	fild word[ebp-4]
	fmul dword[SCALER]
	fstp dword[ebp-4]
	
	;generate polar angle
	;instead of U(-pi;pi) the function uses arccos(U(-1;1)) for the polar coordinates
	;so that the generated vectors are evenly distributed across the surface of the unit sphere
	mov eax, dword[ebp+16]
	mov word[ebp-8], ax
	fild dword[ebp-8]
	fmul dword[SCALER2]
	
	sub esp, 4
	fstp dword[esp]
	call math_acos
	fsub dword[HALF_PI]
	fstp dword[ebp-8]
	add esp, 4
	
	;create unit vector
	mov eax, dword[ebp+8]		;vec in eax
	
	fld dword[ebp-8]
	fsincos
	fld dword[ebp-4]
	fsincos
	fmul st2
	fstp dword[eax]				;cos(azimuth)*cos(polar)
	fmul st1
	fstp dword[eax+8]			;sin(azimuth)*cos(polar)
	fstp st0
	fstp dword[eax+4]			;sin(polar)
	
	mov esp, ebp
	pop ebp
	ret
	
	
perlin_deinit3d:
	push ebp
	mov ebp, esp
	
	test dword[TEXTURE_3D_INITIALIZED], 0xffffffff
	jnz perlin_deinit3d_initialized
		push error_3d_not_initialized2
		call my_printf
		jmp perlin_deinit3d_end
	
	perlin_deinit3d_initialized:
	
	push dword[TEXTURE_3D_DATA]
	call my_free
	add esp, 4
	mov dword[TEXTURE_3D_DATA], 0
	
	mov dword[TEXTURE_3D_INITIALIZED], 0
	
	perlin_deinit3d_end:
	mov esp, ebp
	pop ebp
	ret
	
	
perlin_sample3d:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4		;padding
	sub esp, 4		;projected x value		;8
	sub esp, 4		;projected y value		;12
	sub esp, 4		;projected z value		;16
	
	sub esp, 4		;padding
	sub esp, 4		;value000 x index		;24
	sub esp, 4		;value000 y index		;28
	sub esp, 4		;value000 z index		;32
	
	sub esp, 4		;padding
	sub esp, 4		;x distance				;40
	sub esp, 4		;y distance				;44
	sub esp, 4		;z distance				;48
	sub esp, 4		;padding
	sub esp, 4		;one minus x distance	;56
	sub esp, 4		;one minus y distance	;60
	sub esp, 4		;one minus z distance	;64
	
	sub esp, 4		;helper00z				;68
	sub esp, 4		;helper01z				;72
	sub esp, 4		;helper10z				;76
	sub esp, 4		;helper11z				;80
	
	sub esp, 4		;value000 address		;84
	sub esp, 4		;offsetx				;88
	sub esp, 4		;offsety				;92
	
	;check if the 3d noise is initialized
	test dword[TEXTURE_3D_INITIALIZED], 0xffffffff
	jnz perlin_sample3d_initialized
		push error_3d_not_initialized
		call my_printf
		fldz
		jmp perlin_sample3d_end
	
	perlin_sample3d_initialized:
	
	;calculate projected values
	push dword[ONE]
	push dword[ebp+20]
	call math_repeat
	fstp dword[ebp-8]
	mov eax, dword[ebp+24]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-12]
	mov eax, dword[ebp+28]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-16]
	add esp, 8
	
	push dword[ALMOST_ONE]
	push 0
	push dword[ebp-8]
	call math_clamp
	fstp dword[ebp-8]
	mov eax, dword[ebp-12]
	mov dword[esp], eax
	call math_clamp
	fstp dword[ebp-12]
	mov eax, dword[ebp-16]
	mov dword[esp], eax
	call math_clamp
	fstp dword[ebp-16]
	add esp, 12
	
	mov dword[ebp-4], 0		;make the padding 0, so that no exception occurs
	
	
	;calculate distances and indices
	movss xmm0, dword[TEXTURE_3D_RESOLUTION_FLOAT]
	movss xmm1, dword[ONE]
	subss xmm0, xmm1
	shufps xmm0, xmm0, 0b00000000
	
	movups xmm1, [ebp-16]
	mulps xmm1, xmm0
	movups [ebp-32], xmm1
	
	push dword[ONE]
	push dword[ebp-24]
	call math_repeat
	fstp dword[ebp-40]			;x distance
	mov eax, dword[ebp-28]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-44]			;y distance
	mov eax, dword[ebp-32]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-48]			;z distance
	mov dword[ebp-36], 0		;padding
	add esp, 8
	
	movups xmm0, [ebp-32]
	movups xmm1, [ebp-48]
	subps xmm0, xmm1
	movups [ebp-32], xmm0
	
	fld dword[ebp-24]
	frndint
	fistp dword[ebp-24]			;x index
	fld dword[ebp-28]
	frndint
	fistp dword[ebp-28]			;y index
	fld dword[ebp-32]
	frndint
	fistp dword[ebp-32]			;z index
	
	movups xmm0, [ebp-48]
	movss xmm1, dword[ONE]
	shufps xmm1, xmm1, 0b00000000
	subps xmm1, xmm0
	movups [ebp-64], xmm1
	
	;calculate offsets
	mov eax, dword[TEXTURE_3D_RESOLUTION]
	mov ecx, eax
	shl eax, 2
	mov dword[ebp-92], eax
	imul eax, ecx
	mov dword[ebp-88], eax
	
	mov eax, dword[ebp-24]
	imul eax, dword[ebp-88]
	mov ecx, dword[ebp-28]
	imul ecx, dword[ebp-92]
	add eax, ecx
	mov ecx, dword[ebp-32]
	shl ecx, 2
	add eax, ecx
	add eax, dword[TEXTURE_3D_DATA]
	mov dword[ebp-84], eax
	
	;interpolate along the z axis
	movss xmm0, dword[ebp-40]
	movss xmm1, dword[ebp-56]
	
	movss xmm2, dword[eax]
	movss xmm3, dword[eax+4]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-68], xmm2
	
	add eax, dword[ebp-92]
	movss xmm2, dword[eax]
	movss xmm3, dword[eax+4]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-72], xmm2
	
	add eax, dword[ebp-88]
	movss xmm2, dword[eax]
	movss xmm3, dword[eax+4]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-80], xmm2		;direkt ebp-80!!!!
	
	sub eax, dword[ebp-92]
	movss xmm2, dword[eax]
	movss xmm3, dword[eax+4]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-76], xmm2
	
	;interpolate along the y axis
	movss xmm0, dword[ebp-44]
	movss xmm1, dword[ebp-60]
	
	movss xmm2, dword[ebp-68]
	movss xmm3, dword[ebp-72]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-68], xmm2
	
	movss xmm2, dword[ebp-76]
	movss xmm3, dword[ebp-80]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-76], xmm2
	
	;interpolate along the z axis
	movss xmm0, dword[ebp-48]
	movss xmm1, dword[ebp-64]
	movss xmm2, dword[ebp-68]
	movss xmm3, dword[ebp-76]
	mulss xmm2, xmm1
	mulss xmm3, xmm0
	addss xmm2, xmm3
	movss dword[ebp-68], xmm2
	
	;set the return value
	fld dword[ebp-68]
	
	perlin_sample3d_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret