[BITS 32]

section .rodata use32
	;the angles of the grid point vectors
	;https://youtu.be/9B89kwHvTN4?si=v68YgUcEs0hHRp2R
	TEXTURE_2D_ANGLE_RESOLUTION dd 11
	TEXTURE_2D_ANGLE_RESOLUTION_FLOAT dd 11.0
	TEXTURE_2D_ANGLE_DATA_SIZE_BYTES equ 484		;sizeof(float)*11*11, each slot contains an angle
	
	SCALER dd 0.0000958737993		;PI/2^15  //2^15 is the maximum absolute value of a 16 bit signed integer
	
	ZERO dd 0.0
	ONE dd 1.0
	
	VERY_SMALL_NUMBER dd 0.000000001
	ALMOST_ONE dd 0.9999999
	
	error_2d_not_initialized db "perlin_sample2d: you have to call perlin_init2d before sampling",10,0
	
section .bss use32
	TEXTURE_2D_ANGLE_DATA resb 484	;row major order
	
section .data use32
	;these variables are initialized by an init2d call
	TEXTURE_2D_INITIALIZED dd 0
	
	TEXTURE_2D_RESOLUTION dd 0
	TEXTURE_2D_RESOLUTION_FLOAT dd 0.0
	TEXTURE_2D_DATA_SIZE_BYTES dd 0		;the size of the sample texture
	TEXTURE_2D_DATA dd 0				;the sampled values
	
section .text use32

	global perlin_init2d			;void perlin_init2d(int resolution)			//resolution is the number of points on the grid along one axis, not the number of squares
	global perlin_deinit2d			;void perlin_deinit2d()
	global perlin_sample2d			;float perlin_sample2d(float x, float y)	//pushes the return value onto the FPU stack
	
	extern math_repeat
	extern math_lerp
	extern math_smoothstep1
	extern math_clamp
	
	extern my_malloc
	extern my_free
	
	extern my_printf
	
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
		fld dword[SCALER]
		fdivp
		fstp dword[esi]
	
		;update the random value in eax
		imul eax, 1103515245 
		add eax, 12345
	
		;continue
		add esi, 4
		dec edi
		test edi, edi
		jnz perlin_init2d_angle_loop_start
		
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
			fstp dword[ebp-8]
			
			;calculate right1 angle value
			add eax, 4
			fld dword[eax]
			fsincos
			fmul dword[ebp-44]
			fstp dword[ebp-12]
			fmul dword[ebp-40]
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
			
			;save the value
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
	
	push dword[TEXTURE_2D_DATA]
	call my_free
	add esp, 4
	mov dword[TEXTURE_2D_DATA], 0
	
	mov dword[TEXTURE_2D_INITIALIZED], 0
	
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
		fld1
		jmp perlin_sample2d_end
	
	perlin_sample2d_initialized:
	
	;calculate the projected values (remainder of one, and clamp it slightly below one)
	push dword[ONE]
	push dword[ZERO]
	push dword[ebp+8]
	call math_repeat
	fstp dword[ebp-4]
	mov eax, dword[ebp+12]
	mov dword[esp], eax
	call math_repeat
	fstp dword[ebp-8]
	add esp, 12
	
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