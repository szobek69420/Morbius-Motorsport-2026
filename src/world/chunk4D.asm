[BITS 32]

;layout:
;
;struct Chunk4D{
;	int chunkX, chunkZ, chunkW;					;0
;	Renderable* renderable;						;12
;	ColliderGroup4D* cg;						;16
;	vec4 lowerBound, upperBound;				;20
;	void* vertices, int vertexFloatCount		;52			;temporary, deleted as soon as the renderable is constructed
;	int chunkAlreadyProcessed;					;60			;it is an indicater for the chunkManager_unload if the chunk can be unloaded
;}		64 bytes overall

SIDE_POS_X equ 0x00000000
SIDE_NEG_X equ 0x00000001
SIDE_POS_Y equ 0x00000002
SIDE_NEG_Y equ 0x00000003
SIDE_POS_Z equ 0x00000004
SIDE_NEG_Z equ 0x00000005
SIDE_POS_W equ 0x00000006
SIDE_NEG_W equ 0x00000007

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
	
	CHUNK_HEIGHT_MAP_FACTOR_X dd 0.053
	CHUNK_HEIGHT_MAP_FACTOR_Z dd 0.057
	CHUNK_HEIGHT_MAP_FACTOR_W dd 0.059
	
	CHUNK_HEIGHT_MAP_SCALE dd 20.0
	CHUNK_HEIGHT_MAP_BASE dd 80.0
	
	AABB_SCALE dd 0.5, 0.5, 0.5, 0.5
	
	print_int_nl db "%d",10,0
	
	test_text db "stalinkin park",10,0
	
section .text use32

	;the collider and renderable is initialized by the chunk manager
	global chunk4d_generate			;Chunk4D* chunk4d_generate(int chunkX, int chunkZ, int chunkW)
	;the renderable is destroyed by the chunk manager
	global chunk4d_destroy			;void chunk4d_destroy(Chunk4D* chunk)
	
	;converts a 4d position into a block position
	;ivec4 is just 4 ints
	;chunkPos is the chunkX, chunkZ, chunkW of the chunk (chunkY is always 0)
	;chunkLocalPos is the block's position local to the chunk
	global chunk4d_vec4ToBlockPos	;void chunk4d_vec4ToBlockPos(vec4* position, ivec4* chunkPos, ivec4* chunkLocalPos)
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	
	extern vec4_add
	
	extern BLOCK_AIR
	extern BLOCK_STONE
	
	extern aabb4d_create
	extern aabb4d_getPosition
	extern colliderGroup4d_create
	extern colliderGroup4d_destroy
	extern colliderGroup4d_addCollider
	extern colliderGroup4d_printInfo
	extern physics4d_registerColliderGroup
	extern physics4d_unregisterColliderGroup
	
	
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
	test ebx, 0x70000000
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
	mov dword[eax+4], 0
	and edx, 0xf
	mov dword[ecx+4], edx
	
	mov edx, dword[ebp-8]
	mov ebx, edx
	test ebx, 0x70000000
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
	mov dword[eax+8], ebx
	and edx, 0xf
	mov dword[ecx+8], edx
	
	mov edx, dword[ebp-4]
	mov ebx, edx
	test ebx, 0x70000000
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
	mov dword[eax+12], ebx
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
	
	;yeet cg
	mov eax, dword[ebp+8]
	push 69						;should destroy
	push dword[eax+16]
	call physics4d_unregisterColliderGroup
	
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
					jbe chunk4d_generate_block_types_loop_stone
						;air
						mov cl, byte[BLOCK_AIR]
						mov byte[esi], cl
						jmp chunk4d_generate_block_types_loop_block_chosen
						
					chunk4d_generate_block_types_loop_stone:
						;stone
						mov cl, byte[BLOCK_STONE]
						mov byte[esi], cl
						jmp chunk4d_generate_block_types_loop_block_chosen
					
					chunk4d_generate_block_types_loop_block_chosen:
					
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
		push edi							;save y index
		mov edi, dword[CHUNK_WIDTH]			;x index in edi
		chunk4d_generate_mesh_x_loop_start:
			push edi							;save x index
			mov edi, dword[CHUNK_WIDTH]			;z index in edi
			chunk4d_generate_mesh_z_loop_start:
				push edi							;save z index
				mov edi, dword[CHUNK_WIDTH]			;w index in edi
				chunk4d_generate_mesh_w_loop_start:
					;is the block air?
					cmp byte[esi], 0
					je chunk4d_generate_mesh_w_loop_continue
					
					mov dword[ebp-56], 0		;block is not yet visible
				
					;calculate current (chunk local) block position
					sub esp, 16				;current block position
					
					mov eax, dword[esp+20]
					dec eax
					mov dword[esp], eax
					fild dword[esp]
					fstp dword[esp]			;x index
					
					mov eax, dword[esp+24]
					dec eax
					mov dword[esp+4], eax
					fild dword[esp+4]
					fstp dword[esp+4]		;y index
					
					mov eax, dword[esp+16]
					dec eax
					mov dword[esp+8], eax
					fild dword[esp+8]
					fstp dword[esp+8]		;z index
					
					mov eax, edi
					dec eax
					mov dword[esp+12], eax
					fild dword[esp+12]
					fstp dword[esp+12]		;w index
					
					;add the side to the vertex data if it may be visible (neighbouring block is transparent)
					mov eax, dword[CHUNK_HEIGHT_MAP_WIDTH_SQUARED]
					cmp byte[esi+eax], 0
					jne chunk4d_generate_mesh_not_pos_x
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[esp+8]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[esp+12]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[esp+16]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[esp+20]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						mov dword[esp+4], SIDE_POS_X	;block type and side normal
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
						
						mov eax, dword[esp+8]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[esp+12]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[esp+16]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[esp+20]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						mov dword[esp+4], SIDE_NEG_X	;block type and side normal
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
						
						mov eax, dword[esp+8]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[esp+12]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[esp+16]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[esp+20]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						mov dword[esp+4], SIDE_POS_Y	;block type and side normal
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
						
						mov eax, dword[esp+8]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[esp+12]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[esp+16]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[esp+20]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						mov dword[esp+4], SIDE_NEG_Y	;block type and side normal
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
						
						mov eax, dword[esp+8]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[esp+12]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[esp+16]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[esp+20]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						mov dword[esp+4], SIDE_POS_Z	;block type and side normal
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
						
						mov eax, dword[esp+8]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[esp+12]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[esp+16]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[esp+20]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						mov dword[esp+4], SIDE_NEG_Z	;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_neg_z:
					
					cmp byte[esi+1], 0
					jne chunk4d_generate_mesh_not_pos_w
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[esp+8]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[esp+12]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[esp+16]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[esp+20]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						mov dword[esp+4], SIDE_POS_W	;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
						
					chunk4d_generate_mesh_not_pos_w:
					
					cmp byte[esi-1], 0
					jne chunk4d_generate_mesh_not_neg_w
						sub esp, 8
						lea eax, [ebp-48]
						mov dword[esp], eax				;vertex vector
						
						mov eax, dword[esp+8]
						mov dword[esp+4], eax			;block pos x
						call vector_push_back
						mov eax, dword[esp+12]
						mov dword[esp+4], eax			;block pos y
						call vector_push_back
						mov eax, dword[esp+16]
						mov dword[esp+4], eax			;block pos z
						call vector_push_back
						mov eax, dword[esp+20]
						mov dword[esp+4], eax			;block pos w
						call vector_push_back
						
						mov dword[esp+4], SIDE_NEG_W	;block type and side normal
						call vector_push_back
						
						mov dword[ebp-56], 69			;block is visible
						
						add esp, 8
					chunk4d_generate_mesh_not_neg_w:
					
					;add an aabb if the block is visible
					;the aabbs sind local to the chunk yet
					cmp dword[ebp-56], 0
					je chunk4d_generate_mesh_no_aabb
						mov eax, esp
						push AABB_SCALE
						push eax
						call aabb4d_create
						push eax
						push dword[ebp-52]
						call colliderGroup4d_addCollider
						add esp, 16
					
					chunk4d_generate_mesh_no_aabb:
					
					add esp, 16				;release current block position
					
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
	fild dword[CHUNK_WIDTH]
	fild dword[ebp+20]
	fmulp
	fstp dword[ebp-72]
	
	mov dword[ebp-68], 0
	
	fild dword[CHUNK_WIDTH]
	fild dword[ebp+24]
	fmulp
	fstp dword[ebp-64]
	
	fild dword[CHUNK_WIDTH]
	fild dword[ebp+28]
	fmulp
	fstp dword[ebp-60]
	
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
	
	
;generates a height map for the chunk depending on its chunk id
;heightMap is a char array with the length of (CHUNK_WIDTH+2)^3
;void chunk4d_generateHeightMap(unsigned char* heightMap, int chunkX, int chunkZ, int chunkW)
chunk4d_generateHeightMap:
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
	chunk4d_generateHeightMap_loop_x_start:
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
		chunk4d_generateHeightMap_loop_z_start:
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
			chunk4d_generateHeightMap_loop_w_start:
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