[BITS 32]

;layout:
;
;struct Chunk{
;	int chunkX, chunkZ, chunkW;					;0
;	Renderable* renderable;						;12
;	MeshCollider* collider;						;16
;	vec4 lowerBound, upperBound;				;20
;}		52 bytes overall
section .rodata use32

	CHUNK_WIDTH dd 16					;1<<4
	CHUNK_HEIGHT dd 150
	
	;the height map is a (CHUNK_WIDTH+2)*(CHUNK_WIDTH+2)*(CHUNK_WIDTH+2) array that tells us how high the surface is at the possible (x,z,w) coordinates of the chunk and the chunk borders
	CHUNK_HEIGHT_MAP_LENGTH dd 5832		;CHUNK_HEIGHT_MAP_WIDTH^3
	CHUNK_HEIGHT_MAP_WIDTH dd 18		;CHUNK_WIDTH+2
	CHUNK_HEIGHT_MAP_WIDTH_SQUARED dd 324
	CHUNK_HEIGHT_MAP_WIDTH_CUBED dd 5832
	
	CHUNK_BLOCK_COUNT dd 886464			;CHUNK_HEIGHT_MAP_WIDTH^3 * (CHUNK_HEIGHT+2)
	
	CHUNK_HEIGHT_MAP_FACTOR_X dd 0.013
	CHUNK_HEIGHT_MAP_FACTOR_Z dd 0.017
	CHUNK_HEIGHT_MAP_FACTOR_W dd 0.019
	
	CHUNK_HEIGHT_MAP_SCALE dd 20.0
	CHUNK_HEIGHT_MAP_BASE dd 85.0
	
	print_int_nl db "%d",10,0
	print_float_nl db "%f",10,0
	
	test_text db "rizzler",10,0
	
section .text use32

	global chunk_generate			;Chunk* chunk_generate(int chunkX, int chunkZ, int chunkW, HyperPlane* plane)

	extern hyperPlane_getNormal

	extern my_printf
	extern my_malloc
	extern my_free
	
	extern BLOCK_AIR
	extern BLOCK_STONE
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	
	extern vec4_dot
	extern vec4_add
	extern vec4_sub
	extern vec4_scale
	
	extern CHUNK_TESSERACT_CELL_EDGE_COUNT
	extern CHUNK_TESSERACT_POS_X
	extern CHUNK_TESSERACT_NEG_X
	extern CHUNK_TESSERACT_POS_Y
	extern CHUNK_TESSERACT_NEG_Y
	extern CHUNK_TESSERACT_POS_Z
	extern CHUNK_TESSERACT_NEG_Z
	extern CHUNK_TESSERACT_POS_W
	extern CHUNK_TESSERACT_NEG_W

chunk_generate:
	push ebp
	push ebx
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4				;chunk*								4
	sub esp, 4				;heightmap							8
	
	;"blocks" is a char array with the length of CHUNK_BLOCK_COUNT, the indexing looks like y*CHUNK_HEIGHT_MAP_WIDTH^3+x*CHUNK_HEIGHT_MAP_WIDTH^2+z*CHUNK_HEIGHT_MAP_WIDTH+w 
	;it is the blocks of the chunk and the blocks on the edge of the neighbouring chunks
	sub esp, 4				;blocks								12
	
	;in this configuration the next two variables is exactly a hyperplane equation
	sub esp, 4				;current hyperplane equation E		16
	sub esp, 16				;hyperplane normal					32	

	sub esp, 16				;vertex vector						48
	sub esp, 16				;index vector						64
	
	;alloc space for chunk
	push 52
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;alloc space for heightmap
	push dword[CHUNK_HEIGHT_MAP_LENGTH]
	call my_malloc
	mov dword[ebp-8], eax
	add esp, 4
	
	;generate height map
	push dword[ebp+28]
	push dword[ebp+24]
	push dword[ebp+20]
	push dword[ebp-8]
	call chunk_generateHeightMap
	add esp, 16
	
	;alloc blocks array
	push dword[CHUNK_BLOCK_COUNT]
	call my_malloc
	mov dword[ebp-12], eax
	add esp, 4
	
	
	;set the block types
	mov esi, dword[ebp-12]			;current block in esi
	mov edi, dword[CHUNK_HEIGHT]
	add edi,2						;y index in edi
	chunk_generate_block_types_y_loop_start:
		mov ebx, dword[ebp-8]					;current height map pos in ebx
	
		push edi								;save y index
		mov edi, dword[CHUNK_HEIGHT_MAP_WIDTH]	;x index in edi
		chunk_generate_block_types_x_loop_start:
			push edi								;save x index
			mov edi, dword[CHUNK_HEIGHT_MAP_WIDTH]	;z index in edi
			chunk_generate_block_types_z_loop_start:
				push edi								;save z index
				mov edi, dword[CHUNK_HEIGHT_MAP_WIDTH]	;w index in edi
				chunk_generate_block_types_w_loop_start:
					
					mov eax, dword[esp+8]					;y index in eax
					cmp al, byte[ebx]
					jbe chunk_generate_block_types_loop_stone
						;air
						mov cl, byte[BLOCK_AIR]
						mov byte[esi], cl
						jmp chunk_generate_block_types_loop_block_chosen
						
					chunk_generate_block_types_loop_stone:
						;stone
						mov cl, byte[BLOCK_STONE]
						mov byte[esi], cl
						jmp chunk_generate_block_types_loop_block_chosen
					
					chunk_generate_block_types_loop_block_chosen:
					
					inc esi
					inc ebx
					
					dec edi
					test edi, edi
					jnz chunk_generate_block_types_w_loop_start
				pop edi									;restore z index
				
				dec edi
				test edi, edi
				jnz chunk_generate_block_types_z_loop_start
			pop edi									;restore x index
			
			dec edi
			test edi, edi
			jnz chunk_generate_block_types_x_loop_start
		pop edi									;restore y index
		
		
		dec edi
		test edi, edi
		jnz chunk_generate_block_types_y_loop_start
		
		
	;get hyperplane normal
	lea eax, [ebp-32]
	push eax
	push dword[ebp+32]
	call hyperPlane_getNormal
	add esp, 8
	
	;init vertex and index vectors
	push 20
	lea eax, [ebp-48]
	push eax
	call vector_init
	add esp, 8
	
	push 4
	lea eax, [ebp-64]
	push eax
	call vector_init
	add esp, 8
	
	;calculate mesh
	mov esi, dword[ebp-12]
	add esi, dword[CHUNK_BLOCK_COUNT]
	dec esi
	sub esi, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
	sub esi, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
	sub esi, dword[CHUNK_HEIGHT_MAP_WIDTH]
	sub esi, 1							;current block pos in esi, it will be iterated backwards
	mov edi, dword[CHUNK_HEIGHT]		;y index in edi
	chunk_generate_mesh_y_loop_start:
		push edi							;save y index
		mov edi, dword[CHUNK_WIDTH]			;x index in edi
		chunk_generate_mesh_x_loop_start:
			push edi							;save x index
			mov edi, dword[CHUNK_WIDTH]			;z index in edi
			chunk_generate_mesh_z_loop_start:
				push edi							;save z index
				mov edi, dword[CHUNK_WIDTH]			;w index in edi
				chunk_generate_mesh_w_loop_start:
					;is the block air?
					cmp byte[esi], 0
					je chunk_generate_mesh_w_loop_continue
				
					;calculate hyperplane.position-block position
					sub esp, 16				;hyperplane.position-block position
					
					
					mov eax, dword[ebp+20]	;chunkX
					shl eax, 4
					add eax, dword[esp+20]	;x index
					mov dword[esp], eax
					
					mov eax, dword[esp+24]	;y index
					mov dword[esp+4], eax
					
					mov eax, dword[ebp+24]	;chunkZ
					shl eax, 4
					add eax, dword[esp+16]	;z index
					mov dword[esp+8], eax
					
					mov eax, dword[ebp+28]	;chunkW
					shl eax, 4
					add eax, edi			;w index
					mov dword[esp+12], eax
					
					
					mov eax, dword[ebp+32]	;hyperplane
					fld dword[eax]
					fild dword[esp]
					fsubp
					fstp dword[esp]
					
					fld dword[eax+4]
					fild dword[esp+4]
					fsubp
					fstp dword[esp+4]
					
					fld dword[eax+8]
					fild dword[esp+8]
					fsubp
					fstp dword[esp+8]
					
					fld dword[eax+12]
					fild dword[esp+12]
					fsubp
					fstp dword[esp+12]
					
					;calculate the current hyperplane equation E
					;-<hyperplane.position-block pos; hyperplane normal>
					mov eax, esp
					lea ecx, [ebp-32]
					push eax
					push ecx
					call vec4_dot
					add esp, 8
					
					fstp dword[ebp-16]
					xor dword[ebp-16], 0x80000000
					
					add esp, 16				;release the vec4 from the stack
					
					;calculate the intersections, if necessary
					cmp byte[esi+1], 0
					jne chunk_generate_mesh_not_pos_w
						sub esp, 20
						lea eax, [ebp-64]
						mov dword[esp+16], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+12], eax							;vertex vector
						mov dword[esp+8], CHUNK_TESSERACT_POS_W		;tesseract cell edges
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 20
					chunk_generate_mesh_not_pos_w:
					
					cmp byte[esi-1], 0
					jne chunk_generate_mesh_not_neg_w
						sub esp, 20
						lea eax, [ebp-64]
						mov dword[esp+16], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+12], eax							;vertex vector
						mov dword[esp+8], CHUNK_TESSERACT_NEG_W		;tesseract cell edges
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 20
					chunk_generate_mesh_not_neg_w:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH]
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_pos_z
						sub esp, 20
						lea eax, [ebp-64]
						mov dword[esp+16], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+12], eax							;vertex vector
						mov dword[esp+8], CHUNK_TESSERACT_POS_Z		;tesseract cell edges
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 20
					chunk_generate_mesh_not_pos_z:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_neg_z
						sub esp, 20
						lea eax, [ebp-64]
						mov dword[esp+16], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+12], eax							;vertex vector
						mov dword[esp+8], CHUNK_TESSERACT_NEG_Z		;tesseract cell edges
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 20
					chunk_generate_mesh_not_neg_z:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_pos_x
						sub esp, 20
						lea eax, [ebp-64]
						mov dword[esp+16], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+12], eax							;vertex vector
						mov dword[esp+8], CHUNK_TESSERACT_POS_X		;tesseract cell edges
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 20
					chunk_generate_mesh_not_pos_x:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_neg_x
						sub esp, 20
						lea eax, [ebp-64]
						mov dword[esp+16], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+12], eax							;vertex vector
						mov dword[esp+8], CHUNK_TESSERACT_NEG_X		;tesseract cell edges
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 20
					chunk_generate_mesh_not_neg_x:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_pos_y
						sub esp, 20
						lea eax, [ebp-64]
						mov dword[esp+16], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+12], eax							;vertex vector
						mov dword[esp+8], CHUNK_TESSERACT_POS_Y		;tesseract cell edges
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 20
					chunk_generate_mesh_not_pos_y:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_neg_y
						sub esp, 20
						lea eax, [ebp-64]
						mov dword[esp+16], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+12], eax							;vertex vector
						mov dword[esp+8], CHUNK_TESSERACT_NEG_Y		;tesseract cell edges
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 20
					chunk_generate_mesh_not_neg_y:
					
					chunk_generate_mesh_w_loop_continue:
					dec esi
					dec edi
					test edi, edi
					jnz chunk_generate_mesh_w_loop_start
				pop edi								;restore z index
				
				sub esi, 2
			
				dec edi
				test edi, edi
				jnz chunk_generate_mesh_z_loop_start
			pop edi								;restore x index
			
			mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH]
			shl eax, 1
			sub esi, eax
			
			dec edi
			test edi, edi
			jnz chunk_generate_mesh_x_loop_start
		pop edi								;restore y index
	
		mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
		shl eax, 1
		sub esi, eax
		
		dec edi
		test edi, edi
		jnz chunk_generate_mesh_y_loop_start
	
	;destroy vertex and index vectors
	lea eax, [ebp-48]
	push eax
	call vector_destroy
	lea eax, [ebp-64]
	push eax
	call vector_destroy
	add esp, 8
	
	;dealloc height map
	push dword[ebp-8]
	call my_free
	add esp, 4
	
	;dealloc blocks
	push dword[ebp-12]
	call my_free
	add esp, 4
	
	;set return value
	mov eax, dword[ebp-4]
	
	chunk_generate_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebx
	pop ebp
	ret

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
	
	
	
;a helper function for chunk_generate
;calculates the intersection of the given tesseract cell with the hyperplane and adds its vertices to the vectors
;void chunk_tesseractCell(
;	HyperPlane* plane,
;	HyperPlaneEquation* blockLocalEquation,
;	vec6* tesseractCellEdges,
;	vector<vec5>* meshVertices,
;	vector<int>* meshIndices
;)
chunk_tesseractCell:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret