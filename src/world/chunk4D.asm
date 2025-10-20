[BITS 32]

;layout:
;
;struct Chunk4D{
;	int chunkX, chunkZ, chunkW;					;0
;	Renderable* renderable;						;12
;	ColliderGroup4D* cg;						;16
;	vec4 lowerBound, upperBound;				;20
;	void* vertices, int vertexFloatCount		;52			;temporary, deleted as soon as the renderable is constructed
;	int chunkAlreadyProcessed;					;60			;is the chunk in its final state (in practice; is there a graphics load update waiting for the chunk)
;}		64 bytes overall

SIDE_POS_X equ 0x0000
SIDE_NEG_X equ 0x0001
SIDE_POS_Y equ 0x0002
SIDE_NEG_Y equ 0x0003
SIDE_POS_Z equ 0x0004
SIDE_NEG_Z equ 0x0005
SIDE_POS_W equ 0x0006
SIDE_NEG_W equ 0x0007

section .rodata use32
	EPSILON dd 0.00001
	VERY_BIG_NUMBER dd 69420.69420

	global CHUNK_WIDTH
	global CHUNK_HEIGHT
	CHUNK_WIDTH dd 16					;1<<4
	CHUNK_HEIGHT dd 150
	
	;the height map is a (CHUNK_WIDTH+2)*(CHUNK_WIDTH+2)*(CHUNK_WIDTH+2) array that tells us how high the surface is at the possible (x,z,w) coordinates of the chunk and the chunk borders
	CHUNK_HEIGHT_MAP_LENGTH dd 5832		;CHUNK_HEIGHT_MAP_WIDTH^3
	CHUNK_HEIGHT_MAP_WIDTH dd 18		;CHUNK_WIDTH+2
	CHUNK_HEIGHT_MAP_WIDTH_SQUARED dd 324
	CHUNK_HEIGHT_MAP_WIDTH_CUBED dd 5832
	CHUNK_HEIGHT_PLUS_TWO dd 152
	
	CHUNK_BLOCK_COUNT dd 886464			;CHUNK_HEIGHT_MAP_WIDTH^3 * (CHUNK_HEIGHT+2)
	
	CHUNK_HEIGHT_MAP_OCTAVE1_X dd 0.00159
	CHUNK_HEIGHT_MAP_OCTAVE1_Z dd 0.00171
	CHUNK_HEIGHT_MAP_OCTAVE1_W dd 0.00177
	
	CHUNK_HEIGHT_MAP_OCTAVE2_X dd 0.00371
	CHUNK_HEIGHT_MAP_OCTAVE2_Z dd 0.00399
	CHUNK_HEIGHT_MAP_OCTAVE2_W dd 0.00413
	
	CHUNK_HEIGHT_MAP_SCALE2 dd 15.0
	CHUNK_HEIGHT_MAP_SCALE1 dd 40.0
	CHUNK_HEIGHT_MAP_BASE dd 80.0
	
	AABB_SCALE dd 0.5, 0.5, 0.5, 0.5
	
	print_int_nl db "%d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_four_ints_nl db "%d %d %d %d",10,0
	print_float_nl db "%f",10,0
	print_three_floats_nl db "%f %f %f",10,0
	
	test_text db "stalinkin park",10,0
	
	ONE dd 1.0
	THREE dd 3.0
	
section .text use32

	;the collider and renderable is initialized by the chunk manager
	;changedBlocks can be null
	;firstGenChangedBlocks should be empty initially, it is filled with blocks connected to terrain generation (e.g. trees) and serves as an output variable that will be used by the calling chunkmanager
	;firstGenChangedBlocks is null if it is not the first generation of the chunk
	global chunk4d_generate			;Chunk4D* chunk4d_generate(int chunkX, int chunkZ, int chunkW, const vector<ChangedBlock>* nullableChangedBlocks, vector<ChangedBlock>* firstGenChangedBlocks)
	;the renderable is destroyed by the chunk manager
	global chunk4d_destroy			;void chunk4d_destroy(Chunk4D* chunk)
	
	global chunk4d_isProcessed		;int chunkd4d_isProcessed(Chunk4D* chunk)
	global chunk4d_setProcessed		;void chunk4d_setProcessed(Chunk4D*, int isProcessed)
	
	;converts a 4d position into a block position
	;ivec3/ivec4 is just 3/4 ints
	;chunkPos is the chunkX, chunkZ, chunkW of the chunk
	;chunkLocalPos is the block's position local to the chunk
	global chunk4d_vec4ToBlockPos	;void chunk4d_vec4ToBlockPos(vec4* position, ivec3* chunkPos, ivec4* chunkLocalPos)
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_push_back_buffer
	
	extern vec4_add
	
	extern BLOCK_AIR
	extern BLOCK_GRASS
	extern BLOCK_DIRT
	extern BLOCK_STONE
	extern BLOCK_OAK_LOG
	extern BLOCK_OAK_LEAVES
	
	extern aabb4d_create
	extern aabb4d_getPosition
	extern colliderGroup4d_create
	extern colliderGroup4d_destroy
	extern colliderGroup4d_addCollider
	extern colliderGroup4d_printInfo
	extern physics4d_registerColliderGroup
	extern physics4d_unregisterColliderGroup
	
	extern perlin3d_sample
	
chunk4d_vec4ToBlockPos:
	push ebp
	push ebx
	mov ebp, esp
	
	sub esp, 16				;rounded values
	
	;convert the content of the position vector to integers
	mov eax, dword[ebp+12]
	
	fld dword[eax]
	frndint
	fistp dword[ebp-16]
	
	fld dword[eax+4]
	frndint
	fistp dword[ebp-12]
	
	fld dword[eax+8]
	frndint
	fistp dword[ebp-8]
	
	fld dword[eax+12]
	frndint
	fistp dword[ebp-4]
	
	;get the chunk position and the chunk local block position
	mov eax, dword[ebp+16]
	mov ecx, dword[ebp+20]
	
	mov edx, dword[ebp-16]
	mov ebx, edx
	test ebx, 0x80000000
	jnz chunk4d_vec4ToBlockPos_x_neg
		shr ebx, 4
		jmp chunk4d_vec4ToBlockPos_x_done
	chunk4d_vec4ToBlockPos_x_neg:
		neg ebx
		dec ebx
		shr ebx, 4
		neg ebx
		dec ebx
	chunk4d_vec4ToBlockPos_x_done:
	mov dword[eax], ebx
	and edx, 0xf
	mov dword[ecx], edx
	
	mov edx, dword[ebp-12]
	mov dword[ecx+4], edx
	
	mov edx, dword[ebp-8]
	mov ebx, edx
	test ebx, 0x80000000
	jnz chunk4d_vec4ToBlockPos_z_neg
		shr ebx, 4
		jmp chunk4d_vec4ToBlockPos_z_done
	chunk4d_vec4ToBlockPos_z_neg:
		neg ebx
		dec ebx
		shr ebx, 4
		neg ebx
		dec ebx
	chunk4d_vec4ToBlockPos_z_done:
	mov dword[eax+4], ebx
	and edx, 0xf
	mov dword[ecx+8], edx
	
	mov edx, dword[ebp-4]
	mov ebx, edx
	test ebx, 0x80000000
	jnz chunk4d_vec4ToBlockPos_w_neg
		shr ebx, 4
		jmp chunk4d_vec4ToBlockPos_w_done
	chunk4d_vec4ToBlockPos_w_neg:
		neg ebx
		dec ebx
		shr ebx, 4
		neg ebx
		dec ebx
	chunk4d_vec4ToBlockPos_w_done:
	mov dword[eax+8], ebx
	and edx, 0xf
	mov dword[ecx+12], edx
	
	
	mov esp, ebp
	pop ebx
	pop ebp
	ret
	
chunk4d_destroy:
	push ebp
	mov ebp, esp
	
	;NOTE: renderable is not destroyed here as it wasn't created here
	
	;check if there is unreleased vertex data
	mov eax, dword[ebp+8]
	test dword[eax+52], 0xffffffff
	jz chunk4d_destroy_no_vertexData
		;free vertex data
		push dword[eax+52]
		mov dword[eax+52], 0
		mov dword[eax+56], 0
		call my_free
		add esp, 4
	chunk4d_destroy_no_vertexData:
	
	;yeet cg
	mov eax, dword[ebp+8]
	test dword[eax+16], 0xffffffff
	jz chunk4d_destroy_no_collider_group
		push 69						;should destroy
		push dword[eax+16]
		call physics4d_unregisterColliderGroup
	chunk4d_destroy_no_collider_group:
	
	;dealloc chunk
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
chunk4d_generate:
	push ebp
	push ebx
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4				;chunk4d*							4
	sub esp, 4				;heightmap							8
	
	;"blocks" is a char array with the length of CHUNK_BLOCK_COUNT, the indexing looks like y*CHUNK_HEIGHT_MAP_WIDTH^3+x*CHUNK_HEIGHT_MAP_WIDTH^2+z*CHUNK_HEIGHT_MAP_WIDTH+w 
	;it is the blocks of the chunk and the blocks on the edge of the neighbouring chunks
	sub esp, 4				;blocks								12
	
	;in this configuration the next two variables are exactly a hyperplane equation
	;it is legacy stuff
	sub esp, 4				;current hyperplane equation E		16
	sub esp, 16				;hyperplane normal					32	

	sub esp, 16				;vertex vector						48
	
	sub esp, 4				;collider group						52
	sub esp, 4				;is block visible					56
	sub esp, 16				;chunk position as floats			72
	
	sub esp, 16				;origin block (tree helper)			88
	
	sub esp, 16				;conversion helper					104
	
	;alloc space for chunk
	push 64
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
	mov dword[eax+16], 0			;collider group
	
	mov dword[eax+52], 0			;vertices
	mov dword[eax+56], 0			;vertexFloatCount
	
	mov dword[eax+60], 0			;the chunk is not yet processed
	
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
	call chunk4d_generateHeightMap
	add esp, 16
	
	;alloc blocks array
	push dword[CHUNK_BLOCK_COUNT]
	call my_malloc
	mov dword[ebp-12], eax
	add esp, 4
	
	
	;set the block types
	mov esi, dword[ebp-12]			;current block in esi
	mov edi, 0						;y index in edi
	chunk4d_generate_block_types_y_loop_start:
		mov ebx, dword[ebp-8]					;current height map pos in ebx
	
		push edi								;save y index
		mov edi, 0								;x index in edi
		chunk4d_generate_block_types_x_loop_start:
			push edi								;save x index
			mov edi, 0								;z index in edi
			chunk4d_generate_block_types_z_loop_start:
				push edi								;save z index
				mov edi, 0								;w index in edi
				chunk4d_generate_block_types_w_loop_start:
					
					mov eax, dword[esp+8]					;y index in eax
					cmp al, byte[ebx]
					ja chunk4d_generate_block_types_loop_air
					inc eax
					cmp al, byte[ebx]
					ja chunk4d_generate_block_types_loop_grass
					add eax, 2
					cmp al, byte[ebx]
					ja chunk4d_generate_block_types_loop_dirt
					jmp chunk4d_generate_block_types_loop_stone
					
					chunk4d_generate_block_types_loop_air:
						mov cl, byte[BLOCK_AIR]
						jmp chunk4d_generate_block_types_loop_block_chosen
						
					chunk4d_generate_block_types_loop_grass:
						mov cl, byte[BLOCK_GRASS]
						jmp chunk4d_generate_block_types_loop_block_chosen
						
					chunk4d_generate_block_types_loop_dirt:
						mov cl, byte[BLOCK_DIRT]
						jmp chunk4d_generate_block_types_loop_block_chosen
						
					chunk4d_generate_block_types_loop_stone:
						mov cl, byte[BLOCK_STONE]
						jmp chunk4d_generate_block_types_loop_block_chosen
					
					chunk4d_generate_block_types_loop_block_chosen:
					mov byte[esi], cl
					
					inc esi
					inc ebx
					
					inc edi
					cmp edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
					jl chunk4d_generate_block_types_w_loop_start
				pop edi									;restore z index
				
				inc edi
				cmp edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
				jl chunk4d_generate_block_types_z_loop_start
			pop edi									;restore x index
			
			inc edi
			cmp edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
			jl chunk4d_generate_block_types_x_loop_start
		pop edi									;restore y index
		
		
		inc edi
		cmp edi, dword[CHUNK_HEIGHT_PLUS_TWO]
		jl chunk4d_generate_block_types_y_loop_start
		
	;generate trees (only if it's the first generation)
	cmp dword[ebp+36], 0
	je chunk4d_generate_no_trees
	
		mov esi, dword[ebp+20]
		add esi, 2346287
		mov eax, dword[ebp+24]
		add eax, 9798233
		imul esi, eax
		mov eax, dword[ebp+28]
		add eax, -4692385
		imul esi, eax					;random seed in esi
		
		
		mov edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
		dec edi							;x index in edi (from chunk_width+1 inclusive to 1 inclusive)
		chunk4d_generate_tree_x_loop_start:
		
			push edi							;save x index
			mov edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
			dec edi								;z index in edi (from chunk_width+1 inclusive to 1 inclusive)
			chunk4d_generate_tree_z_loop_start:
				push edi							;save z index
				mov edi, dword[CHUNK_HEIGHT_MAP_WIDTH]
				dec edi								;w index in edi (from chunk_width+1 inclusive to 1 inclusive)
				chunk4d_generate_tree_w_loop_start:
					;update the random value in esi
					imul esi, 1103515245 
					add esi, 12345
				
					;check if the block can be a root block by randomness
					mov eax, esi
					and eax, 0x0000ffff
					cmp eax, 65400
					jl chunk4d_generate_tree_w_loop_continue
					
					;get the current height in the height map
					mov ebx, dword[esp+4]			;x index
					imul ebx, dword[CHUNK_HEIGHT_MAP_WIDTH]
					add ebx, dword[esp]				;z index
					imul ebx, dword[CHUNK_HEIGHT_MAP_WIDTH]
					add ebx, edi					;w index in edi, offset in heightmap in ebx
					
					mov edx, dword[ebp-8]
					add edx, ebx					;current height addr in edx
				
					;check if the block is a grass block
					xor eax, eax
					mov al, byte[edx]		;current height in eax
					imul eax, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
					add eax, ebx
					add eax, dword[ebp-12]	;current block in eax
					
					
					mov cl, byte[BLOCK_GRASS]
					cmp cl, byte[eax]
					jne chunk4d_generate_tree_w_loop_continue
					
					;fill origin block buffer
					;current height addr still in edx
					mov eax, dword[esp+4]
					dec eax
					mov dword[ebp-88], eax			;block x
					xor eax, eax
					mov al, byte[edx]
					mov dword[ebp-84], eax			;block y
					mov eax, dword[esp]
					dec eax
					mov dword[ebp-80], eax			;block z
					mov eax, edi
					dec eax
					mov dword[ebp-76], eax			;block w
					
					;add tree
					lea eax, [ebp-88]
					push eax
					lea eax, [ebp+20]
					push eax
					push oak_tree
					push dword[ebp+36]
					call chunk4d_generateStructure_internal
					add esp, 16
					
					chunk4d_generate_tree_w_loop_continue:
					
					dec edi
					test edi, edi
					jnz chunk4d_generate_tree_w_loop_start
				
				pop edi					;restore z index

				dec edi
				test edi, edi
				jnz chunk4d_generate_tree_z_loop_start
			
			pop edi					;restore x index

			dec edi
			test edi, edi
			jnz chunk4d_generate_tree_x_loop_start
			
	chunk4d_generate_no_trees:
		
		
	;change blocks based on the changedBlocks vector
	cmp dword[ebp+32], 0
	je chunk4d_generate_no_changed_blocks
	
		mov eax, dword[ebp+32]
		mov esi, dword[eax+12]			;current changed block info in esi
		mov edi, dword[eax]				;index in edi
		cmp edi, 0
		jle chunk4d_generate_changed_blocks_loop_end
		chunk4d_generate_changed_blocks_loop_start:
			;check for chunk x
			mov ecx, dword[esi+4]
			cmp dword[ebp+20], ecx
			jne chunk4d_generate_changed_blocks_loop_continue
			
			;check for chunk z
			mov ecx, dword[esi+8]
			cmp dword[ebp+24], ecx
			jne chunk4d_generate_changed_blocks_loop_continue
			
			;check for chunk w
			mov ecx, dword[esi+12]
			cmp dword[ebp+28], ecx
			jne chunk4d_generate_changed_blocks_loop_continue
			
				;calculate the changed block index
				mov edx, dword[esi+20]
				inc edx
				imul edx, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
				
				mov ecx, dword[esi+16]
				inc ecx
				imul ecx, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
				add edx, ecx
				
				mov ecx, dword[esi+24]
				inc ecx
				imul ecx, dword[CHUNK_HEIGHT_MAP_WIDTH]
				add edx, ecx
				
				mov ecx, dword[esi+28]
				inc ecx
				add edx, ecx
				
				;change block
				mov ecx, dword[ebp-12]
				add ecx, edx
				
				mov eax, dword[esi]
				mov byte[ecx], al
			
			chunk4d_generate_changed_blocks_loop_continue:
			add esi, 32
			dec edi
			test edi, edi
			jnz chunk4d_generate_changed_blocks_loop_start
		chunk4d_generate_changed_blocks_loop_end:
	
	chunk4d_generate_no_changed_blocks:
	
	;init vertex vector
	push 4
	lea eax, [ebp-48]
	push eax
	call vector_init
	add esp, 8
	
	;create collider group
	call colliderGroup4d_create
	mov dword[ebp-52], eax				;save the collider group as a local variable for easier access
	mov ecx, dword[ebp-4]
	mov dword[ecx+16], eax				;save it in the chunk as well
	
	;calculate mesh
	mov esi, dword[ebp-12]
	add esi, dword[CHUNK_BLOCK_COUNT]
	dec esi
	sub esi, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
	sub esi, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
	sub esi, dword[CHUNK_HEIGHT_MAP_WIDTH]
	sub esi, 1							;current block pos in esi, it will be iterated backwards
	mov edi, dword[CHUNK_HEIGHT]		;y index in edi
	chunk4d_generate_mesh_y_loop_start:
		lea eax, [edi-1]
		cvtsi2ss xmm0, eax
		movss dword[ebp-100], xmm0
		push edi							;save y index
		mov edi, dword[CHUNK_WIDTH]			;x index in edi
		chunk4d_generate_mesh_x_loop_start:
			lea eax, [edi-1]
			cvtsi2ss xmm0, eax
			movss dword[ebp-104], xmm0
			push edi							;save x index
			mov edi, dword[CHUNK_WIDTH]			;z index in edi
			chunk4d_generate_mesh_z_loop_start:
				lea eax, [edi-1]
				cvtsi2ss xmm0, eax
				movss dword[ebp-96], xmm0
				push edi							;save z index
				mov edi, dword[CHUNK_WIDTH]			;w index in edi
				chunk4d_generate_mesh_w_loop_start:
					;is the block air?
					cmp byte[esi], 0
					je chunk4d_generate_mesh_w_loop_continue
					
					lea eax, [edi-1]
					cvtsi2ss xmm0, eax
					movss dword[ebp-92], xmm0
					
					mov dword[ebp-56], 0		;block is not yet visible
					
					;add the side to the vertex data if it may be visible (neighbouring block is transparent)
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
					cmp byte[esi+eax], 0
					jne chunk4d_generate_mesh_not_pos_x
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[ebp-104]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[ebp-100]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[ebp-96]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[ebp-92]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						xor eax, eax
						mov al, byte[esi]
						rol eax, 16
						mov ax, SIDE_POS_X
						mov dword[esp+4], eax			;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_pos_x:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk4d_generate_mesh_not_neg_x
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[ebp-104]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[ebp-100]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[ebp-96]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[ebp-92]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						xor eax, eax
						mov al, byte[esi]
						rol eax, 16
						mov ax, SIDE_NEG_X
						mov dword[esp+4], eax			;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_neg_x:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
					cmp byte[esi+eax], 0
					jne chunk4d_generate_mesh_not_pos_y
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[ebp-104]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[ebp-100]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[ebp-96]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[ebp-92]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						xor eax, eax
						mov al, byte[esi]
						rol eax, 16
						mov ax, SIDE_POS_Y
						mov dword[esp+4], eax			;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_pos_y:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_CUBED]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk4d_generate_mesh_not_neg_y
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[ebp-104]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[ebp-100]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[ebp-96]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[ebp-92]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						xor eax, eax
						mov al, byte[esi]
						rol eax, 16
						mov ax, SIDE_NEG_Y
						mov dword[esp+4], eax			;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_neg_y:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH]
					cmp byte[esi+eax], 0
					jne chunk4d_generate_mesh_not_pos_z
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[ebp-104]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[ebp-100]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[ebp-96]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[ebp-92]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						xor eax, eax
						mov al, byte[esi]
						rol eax, 16
						mov ax, SIDE_POS_Z
						mov dword[esp+4], eax			;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_pos_z:
					
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH]
					not eax
					inc eax
					cmp byte[esi+eax], 0
					jne chunk4d_generate_mesh_not_neg_z
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[ebp-104]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[ebp-100]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[ebp-96]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[ebp-92]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						xor eax, eax
						mov al, byte[esi]
						rol eax, 16
						mov ax, SIDE_NEG_Z
						mov dword[esp+4], eax			;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_neg_z:
					
					cmp byte[esi+1], 0
					jne chunk4d_generate_mesh_not_pos_w
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[ebp-104]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[ebp-100]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[ebp-96]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[ebp-92]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						xor eax, eax
						mov al, byte[esi]
						rol eax, 16
						mov ax, SIDE_POS_W
						mov dword[esp+4], eax			;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
						
					chunk4d_generate_mesh_not_pos_w:
					
					cmp byte[esi-1], 0
					jne chunk4d_generate_mesh_not_neg_w
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[ebp-104]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[ebp-100]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[ebp-96]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[ebp-92]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						xor eax, eax
						mov al, byte[esi]
						rol eax, 16
						mov ax, SIDE_NEG_W
						mov dword[esp+4], eax			;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_neg_w:
					
					;add an aabb if the block is visible
					;the aabbs sind local to the chunk yet
					cmp dword[ebp-56], 0
					je chunk4d_generate_mesh_no_aabb
						lea eax, [ebp-104]
						push AABB_SCALE
						push eax
						call aabb4d_create
						push eax
						push dword[ebp-52]
						call colliderGroup4d_addCollider
						add esp, 16
					
					chunk4d_generate_mesh_no_aabb:
					
					
					chunk4d_generate_mesh_w_loop_continue:
					dec esi
					dec edi
					test edi, edi
					jnz chunk4d_generate_mesh_w_loop_start
				pop edi								;restore z index
				
				sub esi, 2
			
				dec edi
				test edi, edi
				jnz chunk4d_generate_mesh_z_loop_start
			pop edi								;restore x index
			
			mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH]
			shl eax, 1
			sub esi, eax
			
			dec edi
			test edi, edi
			jnz chunk4d_generate_mesh_x_loop_start
		pop edi								;restore y index
	
		mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
		shl eax, 1
		sub esi, eax
		
		dec edi
		test edi, edi
		jnz chunk4d_generate_mesh_y_loop_start
	
	;does the mesh have any visible points?
	cmp dword[ebp-48], 0
	jle chunk4d_generate_no_mesh
		;save the vertex and index data
		mov eax, dword[ebp-4]
		
		mov ecx, dword[ebp-36]
		mov dword[eax+52], ecx			;vertices
		mov ecx, dword[ebp-48]
		mov dword[eax+56], ecx			;vertexFloatCount
		
		jmp chunk4d_generate_mesh_done
		
	chunk4d_generate_no_mesh:
		lea eax, [ebp-48]
		push eax
		call vector_destroy
		add esp, 8
		
		mov eax, dword[ebp-4]
		mov dword[eax+60], 69			;the chunk is already processed
		jmp chunk4d_generate_mesh_done
		
	chunk4d_generate_mesh_done:
	
	;dealloc height map
	push dword[ebp-8]
	call my_free
	add esp, 4
	
	;dealloc blocks
	push dword[ebp-12]
	call my_free
	add esp, 4
	
	;calculate the chunk's position
	cvtsi2ss xmm0, dword[CHUNK_WIDTH]
	
	cvtsi2ss xmm1, dword[ebp+20]
	mulss xmm1, xmm0
	movss dword[ebp-72], xmm1
	
	mov dword[ebp-68], 0
	
	cvtsi2ss xmm2, dword[ebp+24]
	mulss xmm2, xmm0
	movss dword[ebp-64], xmm2
	
	cvtsi2ss xmm3, dword[ebp+28]
	mulss xmm3, xmm0
	movss dword[ebp-60], xmm3
	
	
	;translate the collider group by the position of the chunk
	;as the current position and bound values are local to the chunk
	mov eax, dword[ebp-52]
	lea eax, [eax+16]
	lea ecx, [ebp-72]
	push ecx
	push eax
	push eax
	call vec4_add
	mov eax, dword[ebp-52]
	lea eax, [eax+32]
	mov dword[esp+4], eax
	mov dword[esp], eax
	call vec4_add
	
	mov eax, dword[ebp-52]
	mov esi, dword[eax+12]			;colliders in esi
	mov edi, dword[eax]			;index in edi
	test edi, edi
	jz chunk4d_generate_translate_colliders_loop_end
	lea eax, [ebp-72]
	push eax						;pre-push chunk position
	chunk4d_generate_translate_colliders_loop_start:
		mov ebx, dword[esi]			;collider in ebx
		
		push ebx
		call aabb4d_getPosition
		add esp, 4
		
		push eax
		push eax
		call vec4_add
		add esp, 8
	
		add esi, 4
		dec edi
		test edi, edi
		jnz chunk4d_generate_translate_colliders_loop_start
	
	chunk4d_generate_translate_colliders_loop_end:
	
	;register the collider group in the physics	
	push dword[ebp-52]
	call physics4d_registerColliderGroup
	add esp, 4
	
	;set return value
	mov eax, dword[ebp-4]
	
	chunk4d_generate_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebx
	pop ebp
	ret
	
	
chunk4d_isProcessed:
	mov eax, dword[esp+4]
	mov eax, dword[eax+60]
	ret
	
chunk4d_setProcessed:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	mov dword[eax+60], ecx
	ret
	
	
;generates a height map for the chunk depending on its chunk id
;heightMap is a char array with the length of (CHUNK_WIDTH+2)^3
;void chunk4d_generateHeightMap(unsigned char* heightMap, int chunkX, int chunkZ, int chunkW)
chunk4d_generateHeightMap:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	;value is what goes into the generation function (sin), base is this value at the base position of the chunk
	sub esp, 4			;x base	1			4
	sub esp, 4			;z base	1			8
	sub esp, 4			;w base	1			12
	
	sub esp, 4			;x octave 1			16
	sub esp, 4			;z octave 1			20
	sub esp, 4			;w octave 1			24
	
	sub esp, 4			;x base	2			28
	sub esp, 4			;z base	2			32
	sub esp, 4			;w base	2			36
	
	sub esp, 4			;x octave 2			40
	sub esp, 4			;z octave 2			44
	sub esp, 4			;w octave 2			48
	
	sub esp, 24			;unused
	
	sub esp, 4			;gen helper1		72
	sub esp, 4			;gen helper2		76
	
	
	cvtsi2ss xmm0, dword[CHUNK_WIDTH]
	
	cvtsi2ss xmm1, dword[ebp+20]
	mulss xmm1, xmm0
	movss xmm2, dword[CHUNK_HEIGHT_MAP_OCTAVE1_X]
	mulss xmm2, xmm1
	movss dword[ebp-4], xmm2
	movss xmm3, dword[CHUNK_HEIGHT_MAP_OCTAVE2_X]
	mulss xmm3, xmm1
	movss dword[ebp-28], xmm3
	
	cvtsi2ss xmm1, dword[ebp+24]
	mulss xmm1, xmm0
	movss xmm2, dword[CHUNK_HEIGHT_MAP_OCTAVE1_Z]
	mulss xmm2, xmm1
	movss dword[ebp-8], xmm2
	movss xmm3, dword[CHUNK_HEIGHT_MAP_OCTAVE2_Z]
	mulss xmm3, xmm1
	movss dword[ebp-32], xmm3
	
	cvtsi2ss xmm1, dword[ebp+28]
	mulss xmm1, xmm0
	movss xmm2, dword[CHUNK_HEIGHT_MAP_OCTAVE1_W]
	mulss xmm2, xmm1
	movss dword[ebp-12], xmm2
	movss xmm3, dword[CHUNK_HEIGHT_MAP_OCTAVE2_W]
	mulss xmm3, xmm1
	movss dword[ebp-36], xmm3
	
	;update current x values
	mov eax, dword[ebp-4]
	mov dword[ebp-16], eax
	mov ecx, dword[ebp-28]
	mov dword[ebp-40], ecx
	
	mov esi, dword[ebp+16]				;current height in esi
	mov edi, dword[CHUNK_WIDTH]	
	add edi, 2							;x index in edi
	chunk4d_generateHeightMap_loop_x_start:
		;update current x values
		movss xmm0, dword[ebp-16]
		addss xmm0, dword[CHUNK_HEIGHT_MAP_OCTAVE1_X]
		movss dword[ebp-16], xmm0
		movss xmm1, dword[ebp-40]
		addss xmm1, dword[CHUNK_HEIGHT_MAP_OCTAVE2_X]
		movss dword[ebp-40], xmm1
	
		;update current z values
		mov eax, dword[ebp-8]
		mov dword[ebp-20], eax
		mov ecx, dword[ebp-32]
		mov dword[ebp-44], ecx
		
		push edi							;save x index
		mov edi, dword[CHUNK_WIDTH]	
		add edi, 2							;z index in edi
		chunk4d_generateHeightMap_loop_z_start:
			;update current z values
			movss xmm0, dword[ebp-20]
			addss xmm0, dword[CHUNK_HEIGHT_MAP_OCTAVE1_Z]
			movss dword[ebp-20], xmm0
			movss xmm1, dword[ebp-44]
			addss xmm1, dword[CHUNK_HEIGHT_MAP_OCTAVE2_Z]
			movss dword[ebp-44], xmm1
		
			;update current w values
			mov eax, dword[ebp-12]
			mov dword[ebp-24], eax
			mov ecx, dword[ebp-36]
			mov dword[ebp-48], ecx
			
			push edi							;save z index
			mov edi, dword[CHUNK_WIDTH]	
			add edi, 2							;w index in edi
			chunk4d_generateHeightMap_loop_w_start:
				;update current w values
				movss xmm0, dword[ebp-24]
				addss xmm0, dword[CHUNK_HEIGHT_MAP_OCTAVE1_W]
				movss dword[ebp-24], xmm0
				movss xmm1, dword[ebp-48]
				addss xmm1, dword[CHUNK_HEIGHT_MAP_OCTAVE2_W]
				movss dword[ebp-48], xmm1
				
				;sample octaves
				push dword[ebp-24]
				push dword[ebp-20]
				push dword[ebp-16]
				call perlin3d_sample
				fstp dword[ebp-72]
				add esp, 12
				
				push dword[ebp-48]
				push dword[ebp-44]
				push dword[ebp-40]
				call perlin3d_sample
				fstp dword[ebp-76]
				add esp, 12
				
				movss xmm0, dword[ebp-72]
				mulss xmm0, dword[CHUNK_HEIGHT_MAP_SCALE1]
				movss xmm1, dword[ebp-76]
				mulss xmm1, dword[CHUNK_HEIGHT_MAP_SCALE2]
				addss xmm0, xmm1
				addss xmm0, dword[CHUNK_HEIGHT_MAP_BASE]
				cvtss2si eax, xmm0
				mov dword[ebp-72], eax
				
				mov al, byte[ebp-72]		;it is converted to unsigned char this way so that its unsignedness doesn't cause problems
				mov byte[esi], al
			
				inc esi
				
				dec edi
				test edi, edi
				jnz chunk4d_generateHeightMap_loop_w_start
			pop edi								;restore z index
			
			dec edi
			test edi, edi
			jnz chunk4d_generateHeightMap_loop_z_start
		pop edi							;restore x index
	
		dec edi
		test edi, edi
		jnz chunk4d_generateHeightMap_loop_x_start
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
;void chunk4d_generateStructure_internal(vector<ChangedBlockInfo>* output, void* structure, ivec3* originChunk, ivec4* originBlock)
chunk4d_generateStructure_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 32		;changed block buffer			32
	
	mov eax, dword[ebp+24]
	mov esi, dword[eax]				;index in esi
	lea edi, [eax+4]				;current block in edi
	cmp esi, 0
	jle chunk4d_generateStructure_internal_loop_end
	chunk4d_generateStructure_internal_loop_start:
		;prepare changed block info
		mov ebx, dword[ebp+28]			;chunk in ebx
		mov eax, dword[edi]
		mov eax, dword[eax]
		mov dword[ebp-32], eax			;block type
		mov ecx, dword[ebx]
		mov dword[ebp-28], ecx			;chunk x
		mov edx, dword[ebx+4]
		mov dword[ebp-24], edx			;chunk z
		mov eax, dword[ebx+8]
		mov dword[ebp-20], eax			;chunk w
		
		mov ebx, dword[ebp+32]			;origin block in ebx
		mov eax, dword[edi+4]
		add eax, dword[ebx]
		mov dword[ebp-16], eax			;block x
		mov eax, dword[edi+8]
		add eax, dword[ebx+4]
		mov dword[ebp-12], eax			;block y
		mov eax, dword[edi+12]
		add eax, dword[ebx+8]
		mov dword[ebp-8], eax			;block z
		mov eax, dword[edi+16]
		add eax, dword[ebx+12]
		mov dword[ebp-4], eax			;block w
		
		;check for overflow-----------------
		;x overflow
		mov eax, dword[ebp-16]
		test eax, 0x80000000
		jnz chunk4d_generateStructure_internal_loop_x_neg
			cmp eax, dword[CHUNK_WIDTH]
			jl chunk4d_generateStructure_internal_loop_x_done		;no overflow
			
			xor edx, edx
			idiv dword[CHUNK_WIDTH]
			add dword[ebp-28], eax			;add quotient to the chunk pos
			mov dword[ebp-16], edx			;remainder is the new block pos
			jmp chunk4d_generateStructure_internal_loop_x_done
			
		chunk4d_generateStructure_internal_loop_x_neg:
			cdq								;eax -> edx:eax
			idiv dword[	CHUNK_WIDTH]
			dec eax
			add dword[ebp-28], eax			;update chunk pos
			add edx, dword[CHUNK_WIDTH]
			mov dword[ebp-16], edx			;update block pos
		
		chunk4d_generateStructure_internal_loop_x_done:
		
		;y overflow
		mov eax, dword[ebp-12]
		test eax, 0x80000000
		jnz chunk4d_generateStructure_internal_loop_continue
		cmp eax, dword[CHUNK_HEIGHT]
		jge chunk4d_generateStructure_internal_loop_continue
		
		;z overflow
		mov eax, dword[ebp-8]
		test eax, 0x80000000
		jnz chunk4d_generateStructure_internal_loop_z_neg
			cmp eax, dword[CHUNK_WIDTH]
			jl chunk4d_generateStructure_internal_loop_z_done		;no overflow
			
			xor edx, edx
			idiv dword[CHUNK_WIDTH]
			add dword[ebp-24], eax			;add quotient to the chunk pos
			mov dword[ebp-8], edx			;remainder is the new block pos
			jmp chunk4d_generateStructure_internal_loop_z_done
			
		chunk4d_generateStructure_internal_loop_z_neg:
			cdq								;eax -> edx:eax
			idiv dword[	CHUNK_WIDTH]
			dec eax
			add dword[ebp-24], eax			;update chunk pos
			add edx, dword[CHUNK_WIDTH]
			mov dword[ebp-8], edx			;update block pos
		
		chunk4d_generateStructure_internal_loop_z_done:
		
		;w overflow
		mov eax, dword[ebp-4]
		test eax, 0x80000000
		jnz chunk4d_generateStructure_internal_loop_w_neg
			cmp eax, dword[CHUNK_WIDTH]
			jl chunk4d_generateStructure_internal_loop_w_done		;no overflow
			
			xor edx, edx
			idiv dword[CHUNK_WIDTH]
			add dword[ebp-20], eax			;add quotient to the chunk pos
			mov dword[ebp-4], edx			;remainder is the new block pos
			jmp chunk4d_generateStructure_internal_loop_w_done
			
		chunk4d_generateStructure_internal_loop_w_neg:
			cdq								;eax -> edx:eax
			idiv dword[	CHUNK_WIDTH]
			dec eax
			add dword[ebp-20], eax			;update chunk pos
			add edx, dword[CHUNK_WIDTH]
			mov dword[ebp-4], edx			;update block pos
		
		chunk4d_generateStructure_internal_loop_w_done:
		
		;add changed block to changed blocks vector
		lea eax, [ebp-32]
		push eax
		push dword[ebp+20]
		call vector_push_back_buffer
		add esp, 8
		
		chunk4d_generateStructure_internal_loop_continue:
		add edi, 20
		dec esi
		test esi, esi
		jnz chunk4d_generateStructure_internal_loop_start
		
	chunk4d_generateStructure_internal_loop_end:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
;structure layout:
;int blockCount
;struct{int blockType, ivec4 chunkLocalBlockPos}* blocks
oak_tree:
oak_tree_block_count dd 19
oak_tree_blocks:
dd BLOCK_OAK_LOG,		0,0,0,0
dd BLOCK_OAK_LOG,		0,1,0,0
dd BLOCK_OAK_LOG,		0,2,0,0
dd BLOCK_OAK_LOG,		0,3,0,0
dd BLOCK_OAK_LEAVES,	-2,4,0,0
dd BLOCK_OAK_LEAVES,	-1,4,0,0
dd BLOCK_OAK_LEAVES,	1,4,0,0
dd BLOCK_OAK_LEAVES,	2,4,0,0
dd BLOCK_OAK_LEAVES,	0,4,-2,0
dd BLOCK_OAK_LEAVES,	0,4,-1,0
dd BLOCK_OAK_LEAVES,	0,4,1,0
dd BLOCK_OAK_LEAVES,	0,4,2,0
dd BLOCK_OAK_LEAVES,	0,4,0,-2
dd BLOCK_OAK_LEAVES,	0,4,0,-1
dd BLOCK_OAK_LEAVES,	0,4,0,1
dd BLOCK_OAK_LEAVES,	0,4,0,2
dd BLOCK_OAK_LOG,		0,4,0,0
dd BLOCK_OAK_LEAVES,	0,5,0,0
dd BLOCK_OAK_LEAVES,	0,6,0,0

fallosz:
fallosz_block_count dd 13
fallosz_blocks:
dd BLOCK_OAK_LOG,		0,2,0,0
dd BLOCK_OAK_LOG,		0,3,0,0
dd BLOCK_OAK_LOG,		0,4,0,0
dd BLOCK_OAK_LOG,		0,5,0,0
dd BLOCK_OAK_LOG,		0,6,0,0
dd BLOCK_OAK_LOG,		0,7,0,0
dd BLOCK_OAK_LOG,		0,8,0,0
dd BLOCK_OAK_LOG,		0,9,0,0
dd BLOCK_OAK_LOG,		0,10,0,0
dd BLOCK_OAK_LOG,		0,11,0,0
dd BLOCK_OAK_LOG,		0,12,0,0
dd BLOCK_OAK_LOG,		-1,1,0,0
dd BLOCK_OAK_LOG,		1,1,0,0