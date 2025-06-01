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
	global perlin_sample2d			;float perlin_sample2d(float x, float y)	//pushes the return value onto the FPU stack
	
	extern math_repeat
	extern math_lerp
	
	extern my_malloc
	extern my_free
	
perlin_init2d:
	push ebp
	push esi
	push edi
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
	sub esp, 4				;one minues current x distance	44
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
	mov eax, dword[ebp+16]
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
	mov eax, dword[TEXTURE_2D_DATA]		;current data slot in eax
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
		fdiv dword[ebp-40]
		fstp dword[ebp-48]		;one minus y distance
		
		fld dword[ebp-40]
		fsub dword[ebp-48]
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
			fdiv dword[ebp-36]
			fstp dword[ebp-44]		;one minus x distance
			
			fld dword[ebp-36]
			fsub dword[ebp-44]
			frndint
			fistp dword[ebp-52]		;x angle index
			
			mov eax, dword[ebp-52]	;x angle index in eax
			mov ecx, dword[ebp-56]	;y angle index in ecx
			
			;update current x pos and continue
			movss xmm0, dword[ebp-28]
			movss xmm1, dword[ebp-24]
			addss xmm0, xmm1
			movss dword[ebp-28], xmm0
			
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
	pop edi
	pop esi
	pop ebp
	ret

perlin_sample2d:
	
	
;void perlin_init2d(int resolution)
perlin_init2d:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 2			;helper word
	
	;fill up the texture with numbers in [-pi; pi)
	mov eax, 69420						;random seed in eax
	mov esi, TEXTURE_2D_DATA			;current pixel in esi
	mov edi, dword[TEXTURE_RESOLUTION]
	imul edi, dword[TEXTURE_RESOLUTION]	;index in edi
	perlin_init2D_texture_filler_loop_start:
		imul eax, 1103515245 
		add eax, 12345
		mov word[ebp-2], ax
		
		fild word[ebp-2]
		fld dword[SCALER]
		fdivp
		fstp dword[esi]
		
		add esi, 4
		dec edi
		test edi, edi
		jnz perlin_init2D_texture_filler_loop_start
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret