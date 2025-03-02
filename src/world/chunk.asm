[BITS 32]

;layout:
;
;struct Chunk{
;	int chunkX, chunkZ, chunkW;					;0
;	GLuint vao, vbo, ebo;						;12
;	MeshCollider* collider;						;24
;	vec4 lowerBound, upperBound;				;28
;}		60 bytes overall

section .rodata use32

	CHUNK_WIDTH dd 16					;1<<4
	CHUNK_HEIGHT dd 150
	CHUNK_BLOCK_COUNT dd 614400			;CHUNK_WIDTH^3 * CHUNK_HEIGHT
	CHUNK_HEIGHT_MAP_LENGTH dd 5832		;(CHUNK_WIDTH+2)^3
	
	CHUNK_HEIGHT_MAP_FACTOR_X dd 0.013
	CHUNK_HEIGHT_MAP_FACTOR_Z dd 0.017
	CHUNK_HEIGHT_MAP_FACTOR_W dd 0.019
	
	CHUNK_HEIGHT_MAP_SCALE dd 20.0
	CHUNK_HEIGHT_MAP_BASE dd 85.0
	
	print_int_nl db "%d",10,0
	print_float_nl db "%f",10,0
	
section .text use32
	global chunk_generateHeightMap

	extern my_printf

;generates a height map for the chunk depending on its chunk id
;heightMap is a char array with the length of (CHUNK_WIDTH+2)^3
;void chunk_generateHeightMap(unsigned char* heightMap, int chunkX, int chunkZ, int chunkW)
chunk_generateHeightMap:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	;value is what goes into the generation function (sin), base is this value at the base position of the chunk
	sub esp, 4			;x base				4
	sub esp, 4			;z base				8
	sub esp, 4			;w base				12
	
	sub esp, 4			;x value			16
	sub esp, 4			;z value			20
	sub esp, 4			;w value			24
	
	sub esp, 4			;x gen func value	28
	sub esp, 4			;z gen func value	32
	sub esp, 4			;w gen func value	36
	
	sub esp, 4			;gen helper			40
	
	
	fild dword[ebp+20]
	fimul dword[CHUNK_WIDTH]
	fmul dword[CHUNK_HEIGHT_MAP_FACTOR_X]
	fstp dword[ebp-4]
	
	fild dword[ebp+24]
	fimul dword[CHUNK_WIDTH]
	fmul dword[CHUNK_HEIGHT_MAP_FACTOR_Z]
	fstp dword[ebp-8]
	
	fild dword[ebp+28]
	fimul dword[CHUNK_WIDTH]
	fmul dword[CHUNK_HEIGHT_MAP_FACTOR_W]
	fstp dword[ebp-12]
	
	
	mov eax, dword[ebp-4]
	mov dword[ebp-16], eax				;x value is x base
	
	mov esi, dword[ebp+16]				;current height in esi
	mov edi, dword[CHUNK_WIDTH]	
	add edi, 2							;x index in edi
	chunk_generateHeightMap_loop_x_start:
		fld dword[ebp-16]
		fld st0
		fsin
		fstp dword[ebp-28]				;x gen func value
		fadd dword[CHUNK_HEIGHT_MAP_FACTOR_X]
		fstp dword[ebp-16]				;x value updated
	
		mov eax, dword[ebp-8]
		mov dword[ebp-20], eax				;z value is z base
		
		push edi							;save x index
		mov edi, dword[CHUNK_WIDTH]	
		add edi, 2							;z index in edi
		chunk_generateHeightMap_loop_z_start:
			fld dword[ebp-20]
			fld st0
			fsin
			fstp dword[ebp-32]				;z gen func value
			fadd dword[CHUNK_HEIGHT_MAP_FACTOR_Z]
			fstp dword[ebp-20]				;z value updated
		
			mov eax, dword[ebp-12]
			mov dword[ebp-24], eax				;w value is w base
			
			push edi							;save z index
			mov edi, dword[CHUNK_WIDTH]	
			add edi, 2							;w index in edi
			chunk_generateHeightMap_loop_w_start:
				fld dword[ebp-24]
				fld st0
				fsin
				fstp dword[ebp-36]				;w gen func value
				fadd dword[CHUNK_HEIGHT_MAP_FACTOR_W]
				fstp dword[ebp-24]				;w value updated
				
				movss xmm0, dword[ebp-28]
				movss xmm1, dword[ebp-32]
				addss xmm0, xmm1
				movss xmm1, dword[ebp-36]
				addss xmm0, xmm1
				
				movss xmm1, dword[CHUNK_HEIGHT_MAP_SCALE]
				mulss xmm0, xmm1
				movss xmm1, dword[CHUNK_HEIGHT_MAP_BASE]
				addss xmm0, xmm1
				movss dword[ebp-40], xmm0
				
				fld dword[ebp-40]
				fistp dword[ebp-40]
				
				mov al, byte[ebp-40]		;it is converted to unsigned char this way so that its unsignedness doesn't cause problems
				mov byte[esi], al
			
				inc esi
				
				dec edi
				test edi, edi
				jnz chunk_generateHeightMap_loop_w_start
			pop edi								;restore z index
			
			dec edi
			test edi, edi
			jnz chunk_generateHeightMap_loop_z_start
		pop edi							;restore x index
	
		dec edi
		test edi, edi
		jnz chunk_generateHeightMap_loop_x_start
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret