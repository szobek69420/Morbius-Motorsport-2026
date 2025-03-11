[BITS 32]

;layout:
;
;struct Chunk{
;	int chunkX, chunkZ, chunkW;					;0
;	Renderable* renderable;						;12
;	MeshCollider* collider;						;16
;	vec4 lowerBound, upperBound;				;20
;	void* vertices, int vertexFloatCount		;52			;temporary, deleted as soon as the renderable is constructed
;	void* indices, int indexCount				;60			;temporary, deleted as soon as the renderable is constructed
;	int shouldBeReloaded						;64
;}		68 bytes overall
section .rodata use32

	EPSILON dd 0.00001
	VERY_BIG_NUMBER dd 69420.69420

	CHUNK_WIDTH dd 16					;1<<4
	CHUNK_HEIGHT dd 150
	
	;the height map is a (CHUNK_WIDTH+2)*(CHUNK_WIDTH+2)*(CHUNK_WIDTH+2) array that tells us how high the surface is at the possible (x,z,w) coordinates of the chunk and the chunk borders
	CHUNK_HEIGHT_MAP_LENGTH dd 5832		;CHUNK_HEIGHT_MAP_WIDTH^3
	CHUNK_HEIGHT_MAP_WIDTH dd 18		;CHUNK_WIDTH+2
	CHUNK_HEIGHT_MAP_WIDTH_SQUARED dd 324
	CHUNK_HEIGHT_MAP_WIDTH_CUBED dd 5832
	CHUNK_HEIGHT_PLUS_TWO dd 152
	
	CHUNK_BLOCK_COUNT dd 886464			;CHUNK_HEIGHT_MAP_WIDTH^3 * (CHUNK_HEIGHT+2)
	
	CHUNK_HEIGHT_MAP_FACTOR_X dd 0.013
	CHUNK_HEIGHT_MAP_FACTOR_Z dd 0.017
	CHUNK_HEIGHT_MAP_FACTOR_W dd 0.019
	
	CHUNK_HEIGHT_MAP_SCALE dd 10.0
	CHUNK_HEIGHT_MAP_BASE dd 35.0
	
	print_nl db 10,0
	print_int_space db "%d ",0
	print_int_nl db "%d",10,0
	print_float_nl db "%f",10,0
	print_two_floats_nl db "%f %f",10,0
	
	test_text db "the rizzler",10,0
	
section .text use32

	;the collider and renderable is initialized by the chunk manager
	global chunk_generate			;Chunk* chunk_generate(int chunkX, int chunkZ, int chunkW, HyperPlane* plane)
	;the collider and the renderable is destroyed by the chunk manager
	global chunk_destroy			;void chunk_destroy(Chunk* chunk)

	extern hyperPlane_getNormal
	extern hyperPlane_signedDistance

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
	extern vec4_print
	
	extern vec3_print
	extern vec3_cross
	extern vec3_dot
	extern vec3_sub
	extern vec3_normalize
	extern vec3_magnitude
	
	extern CHUNK_TESSERACT_CELL_EDGE_COUNT
	extern CHUNK_TESSERACT_POS_X
	extern CHUNK_TESSERACT_NEG_X
	extern CHUNK_TESSERACT_POS_Y
	extern CHUNK_TESSERACT_NEG_Y
	extern CHUNK_TESSERACT_POS_Z
	extern CHUNK_TESSERACT_NEG_Z
	extern CHUNK_TESSERACT_POS_W
	extern CHUNK_TESSERACT_NEG_W
	
	extern CHUNK_TESSERACT_POS_X_NORMAL
	extern CHUNK_TESSERACT_NEG_X_NORMAL
	extern CHUNK_TESSERACT_POS_Y_NORMAL
	extern CHUNK_TESSERACT_NEG_Y_NORMAL
	extern CHUNK_TESSERACT_POS_Z_NORMAL
	extern CHUNK_TESSERACT_NEG_Z_NORMAL
	extern CHUNK_TESSERACT_POS_W_NORMAL
	extern CHUNK_TESSERACT_NEG_W_NORMAL
	
	extern RENDERABLE_ATTRIB_P3UV2
	extern renderable_create
	
chunk_destroy:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret

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
	push 72
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;init the given chunk values
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp+20]
	mov dword[eax], ecx				;chunkX
	mov ecx, dword[ebp+24]
	mov dword[eax+4], ecx			;chunkZ
	mov ecx, dword[ebp+28]
	mov dword[eax+8], ecx			;chunkW
	
	mov dword[eax+12], 0			;renderable
	mov dword[eax+16], 0			;collider
	
	mov dword[eax+52], 0			;vertices
	mov dword[eax+56], 0			;vertexFloatCount
	mov dword[eax+60], 0			;indices
	mov dword[eax+64], 0			;indexCount
	
	mov dword[eax+68], 0			;shouldBeReloaded
	
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
	mov edi, 0						;y index in edi
	chunk_generate_block_types_y_loop_start:
		mov ebx, dword[ebp-8]					;current height map pos in ebx
	
		push edi								;save y index
		mov edi, 0								;x index in edi
		chunk_generate_block_types_x_loop_start:
			push edi								;save x index
			mov edi, 0								;z index in edi
			chunk_generate_block_types_z_loop_start:
				push edi								;save z index
				mov edi, 0								;w index in edi
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
					
					inc edi
					cmp edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
					jl chunk_generate_block_types_w_loop_start
				pop edi									;restore z index
				
				inc edi
				cmp edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
				jl chunk_generate_block_types_z_loop_start
			pop edi									;restore x index
			
			inc edi
			cmp edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
			jl chunk_generate_block_types_x_loop_start
		pop edi									;restore y index
		
		
		inc edi
		cmp edi, dword[CHUNK_HEIGHT_PLUS_TWO]
		jl chunk_generate_block_types_y_loop_start
		
		
	;get hyperplane normal
	lea eax, [ebp-32]
	push eax
	push dword[ebp+32]
	call hyperPlane_getNormal
	add esp, 8
	
	;init vertex and index vectors
	push 4
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
					dec eax					;an x index of 1 corresponds to an x position of 0
					mov dword[esp], eax
					
					mov eax, dword[esp+24]	;y index
					dec eax
					mov dword[esp+4], eax
					
					mov eax, dword[ebp+24]	;chunkZ
					shl eax, 4
					add eax, dword[esp+16]	;z index
					dec eax
					mov dword[esp+8], eax
					
					mov eax, dword[ebp+28]	;chunkW
					shl eax, 4
					add eax, edi			;w index
					dec eax
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
					
					;calculate the intersections, if necessary
					cmp byte[esi+1], 0
					jne chunk_generate_mesh_not_pos_w
						mov ecx, esp
						sub esp, 28
						mov dword[esp+24], CHUNK_TESSERACT_POS_W_NORMAL
						lea eax, [ebp-64]
						mov dword[esp+20], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+16], eax							;vertex vector
						mov dword[esp+12], CHUNK_TESSERACT_POS_W		;tesseract cell edges
						mov dword[esp+8], ecx							;block local plane point
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 28
					chunk_generate_mesh_not_pos_w:
					
					cmp byte[esi-1], 0
					jne chunk_generate_mesh_not_neg_w
						mov ecx, esp
						sub esp, 28
						mov dword[esp+24], CHUNK_TESSERACT_NEG_W_NORMAL
						lea eax, [ebp-64]
						mov dword[esp+20], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+16], eax							;vertex vector
						mov dword[esp+12], CHUNK_TESSERACT_NEG_W		;tesseract cell edges
						mov dword[esp+8], ecx							;block local plane point
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 28
					chunk_generate_mesh_not_neg_w:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH]
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_pos_z
						mov ecx, esp
						sub esp, 28
						mov dword[esp+24], CHUNK_TESSERACT_POS_Z_NORMAL
						lea eax, [ebp-64]
						mov dword[esp+20], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+16], eax							;vertex vector
						mov dword[esp+12], CHUNK_TESSERACT_POS_Z		;tesseract cell edges
						mov dword[esp+8], ecx							;block local plane point
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 28
					chunk_generate_mesh_not_pos_z:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_neg_z
						mov ecx, esp
						sub esp, 28
						mov dword[esp+24], CHUNK_TESSERACT_NEG_Z_NORMAL
						lea eax, [ebp-64]
						mov dword[esp+20], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+16], eax							;vertex vector
						mov dword[esp+12], CHUNK_TESSERACT_NEG_Z		;tesseract cell edges
						mov dword[esp+8], ecx							;block local plane point
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 28
					chunk_generate_mesh_not_neg_z:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_pos_x
						mov ecx, esp
						sub esp, 28
						mov dword[esp+24], CHUNK_TESSERACT_POS_X_NORMAL
						lea eax, [ebp-64]
						mov dword[esp+20], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+16], eax							;vertex vector
						mov dword[esp+12], CHUNK_TESSERACT_POS_Y		;tesseract cell edges
						mov dword[esp+8], ecx							;block local plane point
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 28
					chunk_generate_mesh_not_pos_x:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_neg_x
						mov ecx, esp
						sub esp, 28
						mov dword[esp+24], CHUNK_TESSERACT_NEG_X_NORMAL
						lea eax, [ebp-64]
						mov dword[esp+20], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+16], eax							;vertex vector
						mov dword[esp+12], CHUNK_TESSERACT_NEG_X		;tesseract cell edges
						mov dword[esp+8], ecx							;block local plane point
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 28
					chunk_generate_mesh_not_neg_x:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_pos_y
						mov ecx, esp
						sub esp, 28
						mov dword[esp+24], CHUNK_TESSERACT_POS_Y_NORMAL
						lea eax, [ebp-64]
						mov dword[esp+20], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+16], eax							;vertex vector
						mov dword[esp+12], CHUNK_TESSERACT_POS_Y		;tesseract cell edges
						mov dword[esp+8], ecx							;block local plane point
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 28
					chunk_generate_mesh_not_pos_y:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk_generate_mesh_not_neg_y
						mov ecx, esp
						sub esp, 28
						mov dword[esp+24], CHUNK_TESSERACT_NEG_Y_NORMAL
						lea eax, [ebp-64]
						mov dword[esp+20], eax							;index vector
						lea eax, [ebp-48]
						mov dword[esp+16], eax							;vertex vector
						mov dword[esp+12], CHUNK_TESSERACT_NEG_Y		;tesseract cell edges
						mov dword[esp+8], ecx							;block local plane point
						lea eax, [ebp-32]
						mov dword[esp+4], eax							;local hyperplane equation
						mov eax, dword[ebp+32]
						mov dword[esp], eax								;hyperplane
						call chunk_tesseractCell
						add esp, 28
					chunk_generate_mesh_not_neg_y:
					
					add esp, 16				;release hyperplane.point-block pos from the stack
					
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
	
	;does the mesh have any visible points?
	cmp dword[ebp-48], 0
	jle chunk_generate_no_mesh
		;save the vertex and index data
		mov eax, dword[ebp-4]
		
		mov ecx, dword[ebp-36]
		mov dword[eax+52], ecx			;vertices
		mov ecx, dword[ebp-48]
		mov dword[eax+56], ecx			;vertexFloatCount
		
		mov ecx, dword[ebp-52]
		mov dword[eax+60], ecx			;indices
		mov ecx, dword[ebp-64]
		mov dword[eax+64], ecx			;indexCount
		
		jmp chunk_generate_mesh_done
		
	chunk_generate_no_mesh:
		lea eax, [ebp-48]
		push eax
		call vector_destroy
		lea eax, [ebp-64]
		push eax
		call vector_destroy
		add esp, 8
		jmp chunk_generate_mesh_done
		
	chunk_generate_mesh_done:
	
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
;	vec4* blockLocalPlanePoint,
;	vec6* tesseractCellEdges,
;	vector<float>* meshVertices,
;	vector<int>* meshIndices
;	vec4* cellNormal
;)
chunk_tesseractCell:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 144				;6 vec6 for the intersection points				144
	sub esp, 4					;intersection point count						148
	sub esp, 4					;edge[0].distance								152
	sub esp, 4					;edge[1].distance								156
	sub esp, 4					;vertex vector length beginning					160
	sub esp, 120				;6 vec5 for the 3d intersection points			280
	sub esp, 24					;6 indices										304
	sub esp, 12					;cellNormal's projection to the hyperplane		316
	sub esp, 12					;side normal in 3d								328
	sub esp, 12					;helper vec3									340
	sub esp, 12					;helper vec3 2									352
	sub esp, 4					;highest dot product							356
	sub esp, 4					;highest dot product index						360
	sub esp, 12					;helper vec3 3									372
	
	mov dword[ebp-148], 0
	
	;calculate the intersection points
	mov esi, dword[ebp+28]			;current tesseract cell edge in esi
	mov edi, dword[CHUNK_TESSERACT_CELL_EDGE_COUNT]
	chunk_tesseractCell_intersect_loop_start:
		;calculate the distances
		push esi
		push dword[ebp+20]
		call hyperPlane_signedDistance
		fstp dword[ebp-152]
		add dword[esp+4], 24
		call hyperPlane_signedDistance
		fstp dword[ebp-156]
		add esp, 8
		
		;check if the distances are based
		mov eax, dword[ebp-152]
		mov edx, eax
		and edx, 0x7fffffff
		cmp edx, dword[EPSILON]
		jl chunk_tesseractCell_intersect_loop_continue		;|edge[0]|<EPSILON
		mov ecx, dword[ebp-156]
		;mov edx, ecx
		;and edx, 0x7fffffff
		;cmp edx, dword[EPSILON]
		;jl chunk_tesseractCell_intersect_loop_continue		;|edge[1]|<EPSILON
		
		and eax, 0x80000000
		and ecx, 0x80000000
		xor eax, ecx
		test eax, eax
		jz chunk_tesseractCell_intersect_loop_continue		;the signs of edge[0] and edge[1] are the same, meaning they are on the same side of the hyperplane
		
		;calculate the intersection point
		mov eax, dword[ebp-148]
		imul eax, 24
		lea eax, [ebp+eax-144]		;current vec6 in intersection point array in eax
		
		and dword[ebp-152], 0x7fffffff	;the sign of the distance is unnecessary now
		and dword[ebp-156], 0x7fffffff
		movss xmm2, dword[ebp-152]
		movss xmm0, dword[ebp-156]
		addss xmm0, xmm2
		divss xmm2, xmm0
		
		movss xmm0, dword[esi]			;edge[0].x
		movss xmm1, dword[esi+24]		;edge[1].x
		subss xmm1, xmm0				;edge[1].x-edge[0].x
		mulss xmm1, xmm2				;(edge[1].x-edge[0].x)*distanceFromPlaneEdge0
		addss xmm1, xmm0				;(edge[1].x-edge[0].x)*distanceFromPlaneEdge0 + edge[0].x
		movss dword[eax], xmm1
		
		movss xmm0, dword[esi+4]
		movss xmm1, dword[esi+28]
		subss xmm1, xmm0
		mulss xmm1, xmm2
		addss xmm1, xmm0
		movss dword[eax+4], xmm1
		
		movss xmm0, dword[esi+8]
		movss xmm1, dword[esi+32]
		subss xmm1, xmm0
		mulss xmm1, xmm2
		addss xmm1, xmm0
		movss dword[eax+8], xmm1
		
		movss xmm0, dword[esi+12]
		movss xmm1, dword[esi+36]
		subss xmm1, xmm0
		mulss xmm1, xmm2
		addss xmm1, xmm0
		movss dword[eax+12], xmm1
		
		movss xmm0, dword[esi+16]
		movss xmm1, dword[esi+40]
		subss xmm1, xmm0
		mulss xmm1, xmm2
		addss xmm1, xmm0
		movss dword[eax+16], xmm1
		
		movss xmm0, dword[esi+20]
		movss xmm1, dword[esi+44]
		subss xmm1, xmm0
		mulss xmm1, xmm2
		addss xmm1, xmm0
		movss dword[eax+20], xmm1
		
		inc dword[ebp-148]
		
		chunk_tesseractCell_intersect_loop_continue:
		add esi, 48				;edge=2*vec6
		dec edi
		test edi, edi
		jnz chunk_tesseractCell_intersect_loop_start
		
		
	;are there enough intersection points?
	cmp dword[ebp-148], 3
	jl chunk_tesseractCell_end
		
	;convert the intersection points to 3d
	lea esi, [ebp-144]		;current intersection point in esi
	lea edi, [ebp-280]		;current 3d intersection point in edi
	mov edx, dword[ebp-148]		;index in edx
	chunk_tesseractCell_convert_loop_start:
		push edx		;save index
		
		push dword[ebp+24]
		push esi
		push esi
		call vec4_sub		;current intersection point -= block local hyperplane point
		add esp, 12
		
		;3d positions
		mov eax, dword[ebp+16]
		add eax, 16				;&hyperplane.dir1
		push eax
		push esi
		call vec4_dot
		fstp dword[edi]
		add dword[esp+4], 16
		call vec4_dot
		fstp dword[edi+4]
		add dword[esp+4], 16
		call vec4_dot
		fstp dword[edi+8]
		add esp, 8
		
		;uv
		mov eax, dword[esi+16]
		mov dword[edi+12], eax
		mov eax, dword[esi+20]
		mov dword[edi+16], eax
		
		pop edx			;restore index

		add esi, 24
		add edi, 20
		dec edx
		test edx, edx
		jnz chunk_tesseractCell_convert_loop_start
	
	;save base vertex count
	mov eax, dword[ebp+32]		;vertex vector in eax
	mov eax, dword[eax]
	xor edx, edx
	mov ecx, 5
	idiv ecx
	mov dword[ebp-160], eax
	
	;save vertices
	lea esi, [ebp-280]				;current intersection point in esi
	mov edi, dword[ebp-148]		;index in edi
	chunk_tesseractCell_vertex_save_loop_start:
	
		sub esp, 8
		mov eax, dword[ebp+32]
		mov dword[esp], eax
		
		mov eax, dword[esi]
		mov dword[esp+4], eax
		call vector_push_back
		mov eax, dword[esi+4]
		mov dword[esp+4], eax
		call vector_push_back
		mov eax, dword[esi+8]
		mov dword[esp+4], eax
		call vector_push_back
		mov eax, dword[esi+12]
		mov dword[esp+4], eax
		call vector_push_back
		mov eax, dword[esi+16]
		mov dword[esp+4], eax
		call vector_push_back
		
		add esp, 8
	
		add esi, 20
		dec edi
		test edi, edi
		jnz chunk_tesseractCell_vertex_save_loop_start
		
	;calculate the cellnormal's projection
	mov eax, dword[ebp+16]
	add eax, 16					;&hyperplane.dir1 in eax
	mov ecx, dword[ebp+40]		;cellnormal in ecx
	push ecx
	push eax
	call vec4_dot
	fstp dword[ebp-316]
	add dword[esp], 16
	call vec4_dot
	fstp dword[ebp-312]
	add dword[esp], 16
	call vec4_dot
	fstp dword[ebp-308]
	add esp, 8
	
	;calculate the side's normal in 3d
	;it is literally the cell normals projection, but ebp-328 is left in because of legacy stuff
	
	mov eax, dword[ebp-316]
	mov dword[ebp-328], eax
	mov eax, dword[ebp-312]
	mov dword[ebp-324], eax
	mov eax, dword[ebp-308]
	mov dword[ebp-320], eax
	
	lea eax, [ebp-328]
	push eax
	call vec3_magnitude
	fstp dword[esp]
	mov eax, dword[esp]
	add esp, 4
	and eax, 0x7fffffff
	cmp eax, dword[EPSILON]
	jl chunk_tesseractCell_end			;the side is parallel to the hyperplane
	
	;lea eax, [ebp-328]
	;push eax
	;call vec3_normalize
	;add esp, 4
	
	;triangulate the face
	
	;based on my cringe C# code:
	;Vector3 faceNormal = Vector3.Normalize(Vector3.Cross(pointsOnPlane[1] - pointsOnPlane[0], pointsOnPlane[2] - pointsOnPlane[0]));
	;for(int i=1;i<pointCount;i++) {
	;    Vector3 helper = Vector3.Normalize(pointsOnPlane[i] - pointsOnPlane[0]);
	;    Vector3 helper2 = Vector3.Cross(faceNormal, helper); //the arguments have to be swapped as unity uses a linksystem
	;    int closestIndex = -1;
	;    float closestValue = 0;
	;    for(int j=1;j<pointCount;j++) {
	;        if (i == j)
	;            continue;
	;        float temp = Vector3.Dot(Vector3.Normalize(pointsOnPlane[j] - pointsOnPlane[0]), helper2);
	;        if (temp <= 0)
	;            continue;
	;        float temp2= Vector3.Dot(Vector3.Normalize(pointsOnPlane[j] - pointsOnPlane[0]), helper);
	;        if (closestIndex==-1||temp2>closestValue) {
	;            closestIndex = j;
	;            closestValue = temp2;
	;        }
	;    }
	;    if(closestIndex!=-1) {
	;        indices.Add(baseIndex);
	;        indices.Add(baseIndex + i);
	;        indices.Add(baseIndex + closestIndex);
	;    }
	;}
	
	mov esi, 1				;i in esi
	chunk_tesseractCell_triangulate_outer_loop_start:
		mov eax, esi
		imul eax, 20
		lea ecx, [ebp-280]
		push ecx
		add ecx, eax
		push ecx
		lea eax, [ebp-340]
		push eax
		call vec3_sub
		call vec3_normalize			;helper
		add esp, 12
		
		lea eax, [ebp-328]
		lea ecx, [ebp-340]
		lea edx, [ebp-352]
		push eax
		push ecx
		push edx
		call vec3_cross
		call vec3_normalize			;helper2
		add esp, 12
		
		mov eax, dword[VERY_BIG_NUMBER]
		xor eax, 0x80000000
		mov dword[ebp-356], eax	;closestValue=-VERY_BIG_NUMBER
		mov dword[ebp-360], -1		;closestIndex=-1
		mov edi, 1					;j in edi
		chunk_tesseractCell_triangulate_inner_loop_start:
			cmp esi, edi
			je chunk_tesseractCell_triangulate_inner_loop_continue
		
			mov eax, edi
			imul eax, 20
			lea ecx, [ebp-280]
			push ecx
			add ecx, eax
			push ecx
			lea eax, [ebp-372]
			push eax
			call vec3_sub				;helper3 not normalized
			add esp, 12
			
			lea eax, [ebp-352]
			push eax
			lea eax, [ebp-372]
			push eax
			call vec3_dot
			fstp dword[esp]
			movss xmm0, dword[esp]
			add esp, 8
			
			ucomiss xmm0, dword[EPSILON]
			jb chunk_tesseractCell_triangulate_inner_loop_continue		;temp<=0
		
			lea eax, [ebp-340]
			push eax
			lea eax, [ebp-372]
			push eax
			call vec3_normalize
			call vec3_dot
			fstp dword[esp]
			movss xmm0, dword[esp]
			add esp, 8
			
			ucomiss xmm0, dword[ebp-356]
			jbe chunk_tesseractCell_triangulate_inner_loop_continue
				;temp2>closestValue
				movss dword[ebp-356], xmm0
				mov dword[ebp-360], edi
		
			chunk_tesseractCell_triangulate_inner_loop_continue:
			inc edi
			cmp edi, dword[ebp-148]
			jl chunk_tesseractCell_triangulate_inner_loop_start
	
		;check if a vertex has been found
		cmp dword[ebp-360], -1
		je chunk_tesseractCell_triangulate_outer_loop_continue
			;add side
			mov eax, dword[ebp-360]
			add eax, dword[ebp-160]
			push eax
			push dword[ebp+36]
			call vector_push_back
			
			mov eax, esi
			add eax, dword[ebp-160]
			push eax
			push dword[ebp+36]
			call vector_push_back
			
			push dword[ebp-160]
			push dword[ebp+36]
			call vector_push_back
			
			add esp, 24
		
		chunk_tesseractCell_triangulate_outer_loop_continue:
		inc esi
		cmp esi, dword[ebp-148]
		jl chunk_tesseractCell_triangulate_outer_loop_start
		
	chunk_tesseractCell_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret