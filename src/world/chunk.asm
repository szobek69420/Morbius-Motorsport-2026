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

	global chunk_generate			;Chunk* chunk_generate(int chunkX, int chunkZ, int chunkW, HyperPlane* plane)

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
		
	mov eax, dword[ebp-12]
	mov ecx, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
	imul ecx, 100
	add eax, ecx
	xor ecx, ecx
	mov cl, byte[eax]
	push ecx
	push print_int_nl
	call my_printf
	add esp, 8
		
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
	
	;create renderable
	push dword[RENDERABLE_ATTRIB_P3UV2]
	lea eax, [ebp-64]
	push eax
	lea eax, [ebp-48]
	push eax
	call renderable_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+12], eax
	
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
	sub esp, 4					;second index lowest- and remaining index highest dot product	356
	sub esp, 4					;highest dot product index						360
	
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
	;it is be basically normalize(vertex3D[2]-vertex3D[0] x vertex3D[1]-vertex3D[0])
	;but if its dot product with the cellnormals projection is negative, then it will be negated
	lea eax, [ebp-280]		;vertex3D[0]
	lea ecx, [ebp-240]		;vertex3D[2]
	push eax
	push ecx
	lea edx, [ebp-328]
	push edx
	call vec3_sub
	lea ecx, [ebp-260]		;vertex3D[1]
	mov dword[esp+4], ecx
	lea edx, [ebp-340]
	mov dword[esp], edx
	call vec3_sub
	add esp, 12
	
	lea eax, [ebp-340]
	lea ecx, [ebp-328]
	push eax
	push ecx
	push ecx
	call vec3_cross
	add esp, 12
	
	lea eax, [ebp-316]		;cellnormal projection
	lea ecx, [ebp-328]		;wannabe normal
	push eax
	push ecx
	call vec3_dot
	fstp dword[esp]
	mov eax, dword[esp]
	add esp, 8
	and eax, 0x80000000
	test eax, eax
	jz chunk_tesseractCell_normal_is_gut
		xor dword[ebp-328], 0x80000000
		xor dword[ebp-324], 0x80000000
		xor dword[ebp-320], 0x80000000
	chunk_tesseractCell_normal_is_gut:
	
	lea eax, [ebp-328]
	push eax
	call vec3_magnitude
	fstp dword[esp]
	mov eax, dword[esp]
	add esp, 4
	and eax, 0x7fffffff
	cmp eax, dword[EPSILON]
	jl chunk_tesseractCell_end			;the side is parallel to the hyperplane
	
	lea eax, [ebp-328]
	push eax
	call vec3_normalize
	add esp, 4
	
	;init indices array
	mov dword[ebp-304], 0
	mov dword[ebp-300], 1
	mov dword[ebp-296], 2
	mov dword[ebp-292], 3
	mov dword[ebp-288], 4
	mov dword[ebp-284], 5
	
	;get the first two indices
	;the first one will be 0
	;the second one will be determined in the following way:
	;the second index is initially 1
	;if for an index <normalize(vertex3D[testedIndex]-vertex3D[0]); normalize( sideNormal x (vertex3D[currentSecondIndex]-vertex3D[0]) )> is negative
	;then it is the new second index
	;this is iterated as long as a new second index is found
	chunk_tesseractCell_second_index_outer_loop_start:
		lea eax, [ebp-280]
		push eax
		mov ecx, dword[ebp-300]
		imul ecx, 20
		lea eax, [ebp-280+ecx]
		push eax
		lea eax, [ebp-340]
		push eax
		call vec3_sub
		add esp, 12
		
		lea eax, [ebp-340]
		lea ecx, [ebp-328]
		push eax
		push ecx
		push eax
		call vec3_cross
		call vec3_normalize		;normalize( sideNormal x (vertex3D[currentSecondIndex]-vertex3D[0]) ) in ebp-340
		add esp, 12
		
		mov esi, 2				;tested indices index (0 and 1 must not be tested)
		chunk_tesseractCell_second_index_inner_loop_start:
			;calculate normalize(vertex3D[testedIndex]-vertex3D[0])
			mov eax, dword[ebp-304+4*esi]
			imul eax, 20
			
			lea ecx, [ebp-280]
			push ecx
			lea eax, [ebp-280+eax]
			push eax
			lea eax, [ebp-352]
			push eax
			call vec3_sub
			call vec3_normalize
			add esp, 12
			
			;check if the dot product is negative
			lea eax, [ebp-340]
			lea ecx, [ebp-352]
			push eax
			push ecx
			call vec3_dot
			fstp dword[esp]
			mov eax, dword[esp]
			add esp, 8
			
			mov ecx, eax
			test ecx, 0x80000000
			jz chunk_tesseractCell_second_index_inner_loop_continue
				;new second index found, swap indices[1] and indices[tested]
				mov eax, dword[ebp-300]
				mov ecx, dword[ebp-304+4*esi]
				mov dword[ebp-300], ecx
				mov dword[ebp-304+4*esi], eax
				jmp chunk_tesseractCell_second_index_inner_loop_end
			
			chunk_tesseractCell_second_index_inner_loop_continue:
			inc esi
			cmp esi, dword[ebp-148]
			jl chunk_tesseractCell_second_index_inner_loop_start
			
		chunk_tesseractCell_second_index_inner_loop_end:
		
		;did we find a new second index?
		cmp esi, dword[ebp-148]
		jl chunk_tesseractCell_second_index_outer_loop_start
		
	;sort the remaining indices
	;< normalize( (vertex3D[lastIndex]-vertex3D[lastIndex-1]) x sideNormal); normalize(vertex3D[currentIndex]-vertex3D[lastIndex]) > shall be maximized
	mov esi, 1
	chunk_tesseractCell_remaining_indices_outer_loop_start:
		mov eax, dword[VERY_BIG_NUMBER]
		xor eax, 0x80000000					;-VERY_BIG_NUMBER
		mov dword[ebp-356], eax
	
		;calculate normalize( (vertex3D[lastIndex]-vertex3D[lastIndex-1]) x sideNormal), goes into ebp-340
		mov eax, dword[ebp-304+4*esi]
		mov ecx, dword[ebp-308+4*esi]		;direkt 308!!!
		imul eax, 20
		imul ecx, 20
		lea eax, [ebp-280+eax]
		lea ecx, [ebp-280+ecx]
		
		push ecx
		push eax
		lea edx, [ebp-340]
		push edx
		call vec3_sub
		add esp, 12
		
		lea eax, [ebp-328]
		lea ecx, [ebp-340]
		push eax
		push ecx
		push ecx
		call vec3_cross
		call vec3_normalize
		add esp, 12
		
		lea edi, [esi+1]
		chunk_tesseractCell_remaining_indices_inner_loop_start:
			;calculate normalize(vertex3D[currentIndex]-vertex3D[lastIndex])
			mov eax, esi
			imul eax, 20
			lea eax, [ebp-280+eax]
			push eax					;vertex3D[lastIndex]
			mov eax, edi
			imul eax, 20
			lea eax, [ebp-280+eax]
			push eax					;vertex3D[currentIndex]
			lea eax, [ebp-352]
			push eax
			call vec3_sub
			call vec3_normalize
			add esp, 12
			
			;calculate the dot product
			lea eax, [ebp-340]
			push eax
			lea eax, [ebp-352]
			push eax
			call vec3_dot
			fstp dword[esp]
			movss xmm0, dword[esp]
			add esp, 8
			
			;is this vertex better?
			ucomiss xmm0, dword[ebp-356]
			jb chunk_tesseractCell_remaining_indices_inner_loop_continue
				;new highest dot
				movss dword[ebp-356], xmm0
				mov dword[ebp-360], edi
		
			chunk_tesseractCell_remaining_indices_inner_loop_continue:
			inc edi
			cmp edi, dword[ebp-148]
			jl chunk_tesseractCell_remaining_indices_inner_loop_start
		
		;swap the indices
		mov eax, dword[ebp-360]
		
		mov ecx, dword[ebp-304+4*eax]
		mov edx, dword[ebp-300+4*esi]			;direkt 300, mert indices[lastIndex+1]
		mov dword[ebp-304+4*eax], edx
		mov dword[ebp-300+4*esi], ecx
	
	
		inc esi
		mov eax, esi
		inc eax
		cmp eax, dword[ebp-148]
		jl chunk_tesseractCell_remaining_indices_outer_loop_start 	;i<vertexCount-1
	
	;save indices (triangulates the side in a GL_TRIANGLE_FAN-like layout, except that the first index is repeated every triangle)
	mov esi, 2			;index in esi
	chunk_tesseractCell_save_indices_loop_start:
		sub esp, 8
		
		mov eax, dword[ebp+36]
		mov dword[esp], eax
		
		
		mov eax, dword[ebp-160]
		add eax, dword[ebp-304]
		mov dword[esp+4], eax
		call vector_push_back
		
		mov eax, dword[ebp-160]
		add eax, dword[ebp-308+4*esi]			;direkt 308, mert indices[esi-1]
		mov dword[esp+4], eax
		call vector_push_back
		
		mov eax, dword[ebp-160]
		add eax, dword[ebp-304+4*esi]
		mov dword[esp+4], eax
		call vector_push_back
		
		add esp, 8
	
		inc esi
		cmp esi, dword[ebp-148]
		jl chunk_tesseractCell_save_indices_loop_start
		
	;print indices
	lea esi, [ebp-304]
	mov edi, dword[ebp-148]
	chunk_tesseractCell_print_indices_loop_start:
		push dword[esi]
		push print_int_space
		call my_printf
		add esp, 8
	
		add esi, 4
		dec edi
		test edi, edi
		jnz chunk_tesseractCell_print_indices_loop_start
		
	push print_nl
	call my_printf
	add esp, 4
		
	chunk_tesseractCell_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret