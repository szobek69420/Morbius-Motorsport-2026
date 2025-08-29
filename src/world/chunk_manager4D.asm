[BITS 32]

;layout ChunkManager4D{
;	tsVector<Chunk4D*> loadedChunks;						0
;	hashMap<ivec3, vector<ChangedBlock>>* changedBlocks;	8
;	vector<ivec3> veteranChunks;							12
;	tsVector<FantomChunk> fantomChunks;						28
;	tsQueue<GraphicsUpdate> pendingGraphicsUpdates;			36
;	tsQueue<PendingChangedBlock> pendingChangedBlocks;		44
;	queue<ReloadUpdate>	pendingReloads;						52
;	padding of 28 bytes
;	HyperPlane hyperPlane;									100
;	GLuint shader;											164
;	TextureArrayInfo* blockTextures;						168
;}	172 bytes

;layout:
;struct GraphicsUpdate{
;	int isLoadUpdate;		0
;	union{					4
;		struct LoadData{ Chunk4D*; };
;		struct UnloadData{ Renderable*, int isFantom;};
;		struct IgnoredUpdate{ NULL; }
;	}
;}	12 bytes

;layout:
;struct ReloadUpdate{
;	ivec3 chunkPos;
;}	12 bytes

;layout:
;struct ChangedBlock{
;	int blockType;
;	ivec3 chunkPos;					4
;	ivec4 blockPos;					16
;}		32 bytes overall

;layout:
;struct PendingChangedBlock{
;	ChangedBlock info;				0
;	int hasPriority;				32	//necessary, because just putting the block onto the beginning of the queue doesn't guarantee a swift chunk reload
;} 36 bytes overall

;layout:
;struct FantomChunk{
;	Renderable* renderable;			0
;	ivec3 chunkPos;					4
;}	16 bytes

section .rodata use32
	vertex_shader_path db "./shaders/chunk/chunk4D.vag",0
	fragment_shader_path db "./shaders/chunk/chunk4D.fag",0
	geometry_shader_path db "./shaders/chunk/chunk4D.gag",0
	
	uniform_name_chunkPos db "chunkPos",0
	uniform_name_hyperPlanePos db "hyperPlanePos",0
	uniform_name_hyperPlaneDir1 db "hyperPlaneDir1",0
	uniform_name_hyperPlaneDir2 db "hyperPlaneDir2",0
	uniform_name_hyperPlaneDir3 db "hyperPlaneDir3",0
	uniform_name_hyperPlaneNormal db "hyperPlaneNormal",0
	uniform_name_sunDirection db "sunDirection",0
	
	uniform_name_view_mat db "view_mat",0
	uniform_name_projection_mat db "projection_mat",0
	uniform_name_normal_mat db "normal_mat",0

section .text use32
	;should be called from the graphics thread
	global chunkManager4d_create					;ChunkManager4D* chunkManager4d_create()
	
	;should be called from the graphics thread
	;returns 0 if no graphics update has been processed
	global chunkManager4d_processGraphicsUpdate		;int chunkManager4d_processGraphicsUpdate(ChunkManager4D* manager)
	
	;adds a block that needs to be changed to the pending changed blocks queue
	global chunkManager4d_registerChangedBlock	;void chunkManager4d_registerChangedBlock(ChunkManager4D* cm, int blockType, ivec3* chunkPos, ivec4* chunkLocalBlockPos, int hasPriority)
	
	;adds an array of blocks that needs to be changed to the pending changed blocks queue
	;separates the blocks into two arrays - blocks with and without priority
	;if nullableHasPriorityArray is NULL, all of the blocks count as non-priority
	;void chunkManager4d_registerChangedBlockArray(
	;	ChunkManager4D* cm,
	;	int blockCount,
	;	const int* blockTypeArray,
	;	const ivec3* chunkPosArray,
	;	const ivec4* chunkLocalBlockPosArray,
	;	const int* nullableHasPriorityArray)
	global chunkManager4d_registerChangedBlockArray
	
	global chunkManager4d_getHyperPlane			;HyperPlane* chunkManager4d_getHyperPlane(ChunkManager4D* cm)
	global chunkManager4d_setHyperPlane			;void chunkManager4d_setHyperPlane(ChunkManager4D* cm, HyperPlane* ph)
	
	global chunkManager4d_getPlayerChunk4D			;void chunkManager4d_getPlayerChunk4D(ChunkManager4D* cm, vec3* playerPos3D, int* chunkX, int* chunkZ, int* chunkW)
	
	extern my_malloc
	extern my_free
	
	extern vector_init
	extern tsVector_init
	extern tsVector_pushBack
	extern tsVector_remove
	extern tsVector_removeCustom
	extern tsVector_search
	
	extern queue_init
	extern tsQueue_init
	extern tsQueue_push
	extern tsQueue_pushFront
	extern tsQueue_pushArray
	extern tsQueue_pop
	extern tsQueue_search
	extern tsQueue_forEach
	
	extern renderable_createCustom
	extern renderable_destroy
	
	extern hyperPlane_create
	
	extern block_importTextures
	
chunkManager4d_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;chunk manager		4
	
	;alloc chunk manager
	push 172
	call my_malloc
	mov dword[ebp-4], eax
	
	;init loaded chunks vector
	mov ecx, dword[ebp-4], ecx
	push 4
	push ecx
	call tsVector_init
	
	;init changed blocks hashmap
	call hashMap_init
	mov ecx, dword[ebp-4]
	mov dword[ecx+8], eax
	
	;init veteran chunk vector
	mov ecx, dword[ebp-4]
	lea ecx, [ecx+12]
	push 12
	push ecx
	call vector_init
	
	;init fantom chunk vector
	mov ecx, dword[ebp-4]
	lea ecx, [ecx+28]
	push 16
	push ecx
	call vector_init
	
	;init graphics update queue
	mov ecx, dword[ebp-4]
	lea ecx, [ecx+36]
	push 1000
	push 12
	push ecx
	call tsQueue_init
	
	;init changed block queue
	mov ecx, dword[ebp-4]
	lea ecx, [ecx+44]
	push 16384
	push 36
	push ecx
	call tsQueue_init
	
	;init reload queue
	mov ecx, dword[ebp-4]
	lea ecx, [ecx+52]
	push 500
	push 12
	push ecx
	call queue_init
	
	;init hyperplane
	mov eax, dword[ebp-4]
	add eax, 100
	push eax
	call hyperPlane_create
	
	;create shader
	push geometry_shader_path
	push fragment_shader_path
	push vertex_shader_path
	call renderable_createShader
	mov ecx, dword[ebp-4]
	mov dword[ecx+164], eax
	
	;import textures
	call block_importTextures
	mov ecx, dword[ebp-4]
	mov dword[ecx+168], eax
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_processGraphicsUpdate:
	push ebp
	mov ebp, esp
	
	sub esp, 12			;graphics update buffer			12
	sub esp, 4			;has processed updates			4
	sub esp, 16			;imitated vertex vector			32
	sub esp, 4			;created renderable				36
	
	mov eax, dword[ebp+8]
	add eax, 36
	lea ecx, [ebp-12]
	push ecx
	push eax
	call tsQueue_pop
	test eax, eax
	jnz chunkManager4d_processGraphicsUpdate_end		;problem
	
	test dword[ebp-8], 0xffffffff
	jz chunkManager4d_processGraphicsUpdate_end			;ignored update
		mov dword[ebp-16], 69
	
	test dword[ebp-12], 0xffffffff
	jz chunkManager4d_processGraphicsUpdate_unload_update
		;load update
		;only chunks with mesh should be here
		
		;create the imitated vertex vector
		mov eax, dword[ebp-8]
		mov ecx, dword[eax+56]
		mov dword[ebp-32], ecx
		mov dword[ebp-28], ecx
		mov dword[ebp-24], 4
		mov ecx, dword[eax+52]
		mov dword[ebp-20], ecx
		
		;create renderable and set texture
		push 1
		push 1
		push 4
		push 1
		push 0
		lea eax, [ebp-32]
		push eax
		call renderable_createCustom
		mov dword[ebp-36], eax
		
		;destroy the vertex and index data in the chunk
		mov eax, dword[ebp-8]
		push dword[eax+52]
		mov dword[eax+52], 0
		mov dword[eax+56], 0
		call my_free
		
		;add renderable to the chunk
		mov ecx, dword[ebp-36]
		mov eax, dword[ebp-8]
		mov dword[eax+12], ecx
		
		;add chunk to the loaded chunks vector
		push dword[ebp-8]
		push dword[ebp+8]
		call tsVector_pushBack
		
		jmp chunkManager4d_processGraphicsUpdate_end
	
	chunkManager4d_processGraphicsUpdate_unload_update:
		;remove renderable from fantom array if necessary
		test dword[ebp-4], 0xffffffff
		jz chunkManager4d_processGraphicsUpdate_unload_update_not_fantom
			mov eax, dword[ebp+8]
			add eax, 28
			push dword[ebp-8]
			push chunkManager4d_processGraphicsUpdate_unload_update_fantom_comparator
			push eax
			call tsVector_removeCustom
			jmp chunkManager4d_processGraphicsUpdate_unload_update_not_fantom
			;returns 0 on match
			;int chunkManager4d_processGraphicsUpdate_unload_update_fantom_comparator(FantomChunk*, Renderable*)
			chunkManager4d_processGraphicsUpdate_unload_update_fantom_comparator:
				mov eax, 69
				mov ecx, dword[esp+4]
				mov ecx, dword[ecx]
				cmp ecx, dword[esp+8]
				jne chunkManager4d_processGraphicsUpdate_unload_update_fantom_comparator_end
					xor eax, eax
				chunkManager4d_processGraphicsUpdate_unload_update_fantom_comparator_end:
				ret
		chunkManager4d_processGraphicsUpdate_unload_update_not_fantom:
		
		;destroy renderable
		push dword[ebp-8]
		call renderable_destroy
	
	chunkManager4d_processGraphicsUpdate_end:
	mov eax, dword[ebp-16]
	
	mov esp, ebp
	pop ebp
	ret
	
chunkManager4d_registerChangedBlock:
	push ebp
	mov ebp, esp
	
	push dword[ebp+24]			;has priority
	mov eax, dword[ebp+20]		;local block pos
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	mov eax, dword[ebp+16]		;chunk pos
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push dword[ebp+12]			;block type
	mov eax, dword[ebp+8]
	lea eax, [eax+44]
	push eax
	call tsQueue_push
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_registerChangedBlockArray:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;PendingChangedBlock array		4
	
	cmp dword[ebp+24], 0
	jle chunkManager4d_registerChangedBlockArray_end
	
	;alloc buffer
	mov eax, dword[ebp+24]
	imul eax, 36
	push eax
	call my_malloc
	mov dword[ebp-4], eax
	
	;fill up buffer
	mov esi, dword[ebp-4]			;current element in buffer in esi
	xor edi, edi					;index in edi
	chunkManager4d_registerChangedBlockArray_loop_start:
		mov eax, dword[ebp+28]
		mov eax, dword[eax+4*edi]
		mov dword[esi], eax
		
		lea ecx, [edi+2*edi]
		sal ecx, 2
		add ecx, dword[ebp+32]
		mov edx, dword[ecx]
		mov dword[esi+4], edx
		mov edx, dword[ecx+4]
		mov dword[esi+8], edx
		mov edx, dword[ecx+8]
		mov dword[esi+12], edx
		
		mov eax, dword[ebp+36]
		lea eax, [eax+16*edi]
		mov ecx, dword[eax]
		mov dword[esi+16], ecx
		mov edx, dword[eax+4]
		mov dword[esi+20], edx
		mov ecx, dword[eax+8]
		mov dword[esi+24], ecx
		mov edx, dword[eax+12]
		mov dword[esi+28], edx
		
		mov dword[esi+32], 0
		test dword[ebp+40], 0xffffffff
		jz chunkManager4d_registerChangedBlockArray_loop_continue
			mov eax, dword[ebp+40]
			mov ecx, dword[eax+4*edi]
			mov dword[esi+32], ecx
		chunkManager4d_registerChangedBlockArray_loop_continue:
		add esi, 36
		inc edi
		cmp edi, dword[ebp+24]
		jl chunkManager4d_registerChangedBlockArray_loop_start
		
	;push array to queue
	push dword[ebp+24]
	push dword[ebp-4]
	mov eax, dword[ebp+20]
	add eax, 44
	push eax
	call tsQueue_pushArray
	
	;dealloc buffer
	push dword[ebp-4]
	call my_free
	
	chunkManager4d_registerChangedBlockArray_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
chunkManager4d_setHyperPlane:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	add eax, 100
	push 64
	push dword[ebp+12]
	push eax
	call my_memcpy
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_getHyperPlane:
	mov eax, dword[esp+4]
	add eax, 100
	ret
	
	
chunkManager4d_getPlayerChunk:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;player pos 4d				16
	sub esp, 16				;helper vec4				32
	
	mov eax, dword[ebp+8]
	
	;calculate player pos 4d
	mov ecx, dword[eax+100]
	mov dword[ebp-16], ecx
	mov ecx, dword[eax+104]
	mov dword[ebp-12], ecx
	mov ecx, dword[eax+108]
	mov dword[ebp-8], ecx
	mov ecx, dword[eax+112]
	mov dword[ebp-4], ecx
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	push dword[ecx]
	lea ecx, [eax+116]		;cm.hyperplane.dir1
	push ecx
	lea ecx, [ebp-32]
	push ecx
	call vec4_scale
	lea ecx, [ebp-16]
	push ecx
	push ecx
	call vec4_add
	add esp, 20
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	push dword[ecx+4]
	lea ecx, [eax+132]		;cm.hyperplane.dir2
	push ecx
	lea ecx, [ebp-32]
	push ecx
	call vec4_scale
	lea ecx, [ebp-16]
	push ecx
	push ecx
	call vec4_add
	add esp, 20
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	push dword[ecx+8]
	lea ecx, [eax+148]		;cm.hyperplane.dir3
	push ecx
	lea ecx, [ebp-32]
	push ecx
	call vec4_scale
	lea ecx, [ebp-16]
	push ecx
	push ecx
	call vec4_add
	add esp, 20
	
	;calculate the player chunk
	mov eax, dword[ebp+16]
	fld dword[ebp-16]
	fistp dword[eax]
	mov ecx, dword[eax]
	sar ecx, 4
	mov dword[eax], ecx
	
	mov eax, dword[ebp+20]
	fld dword[ebp-8]
	fistp dword[eax]
	mov ecx, dword[eax]
	sar ecx, 4
	mov dword[eax], ecx
	
	mov eax, dword[ebp+24]
	fld dword[ebp-4]
	fistp dword[eax]
	mov ecx, dword[eax]
	sar ecx, 4
	mov dword[eax], ecx
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
;internal functinos

;returns NULL, if the the chunk is already loaded
;Chunk4D* chunkManager4d_loadChunk_internal(ChunkManager4D* cm, ivec3 chunkPos)
chunkManager4d_loadChunk_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;chunk								4
	sub esp, 4			;is veteran							8
	sub esp, 4			;changed blocks vector				12
	sub esp, 16			;vector<ChangedBlock> firstTimers	28
	sub esp, 4			;block type array					32
	sub esp, 4			;chunk pos array					36
	sub esp, 4			;block pos array					40
	
	mov dword[ebp-4], 0
	mov dword[ebp-8], 0
	
	;check if the chunk is already loaded
	push dword[ebp+32]
	push dword[ebp+28]
	push dword[ebp+24]
	push dword[ebp+20]
	call chunkManager4d_isChunkLoaded
	test eax, eax
	jnz chunkManager4d_loadChunk_internal_end
	
	;get the changed blocks vector
	mov eax, dword[ebp+20]
	lea ecx, [ebp+24]
	push 12
	push ecx
	push dword[eax+4]
	call hashMap_get
	mov dword[ebp-12], eax
	
	;check if the chunk is a veteran chunk
	mov eax, dword[ebp+20]
	add eax, 12
	lea ecx, [ebp+24]
	push ecx
	push chunkManager4d_loadChunk_internal_veteran_comparator
	push eax
	call vector_search
	cmp eax, -1
	je chunkManager4d_loadChunk_internal_not_veteran
		;veteran
		push 0
		push dword[ebp-12]
		push dword[ebp+32]
		push dword[ebp+28]
		push dword[ebp+24]
		call chunk4d_generate
		mov dword[ebp-4], eax
		jmp chunkManager4d_loadChunk_internal_load_done
	
	chunkManager4d_loadChunk_internal_not_veteran:
		;add chunk to veterans
		push dword[ebp+32]
		push dword[ebp+28]
		push dword[ebp+24]
		mov eax, dword[ebp+20]
		add eax, 12
		push eax
		call vector_push_back
	
		;create first timer blocks
		push 32
		lea eax, [ebp-28]
		push eax
		call vector_init
		
		;generate chunk
		lea eax, [ebp-28]
		push eax
		push dword[ebp-12]
		push dword[ebp+32]
		push dword[ebp+28]
		push dword[ebp+24]
		call chunk4d_generate
		mov dword[ebp-4], eax
		
		;process the first timer blocks
		cmp dword[ebp-28], 0
		jle chunkManager4d_loadChunk_internal_not_veteran_no_first_timers
			;alloc arrays
			mov eax, dword[ebp-28]
			lea ecx, [4*eax]
			push ecx
			lea ecx, [eax+2*eax]
			sal ecx, 2
			push ecx
			lea ecx, [16*eax]
			push ecx
			call my_malloc
			mov dword[ebp-40], eax
			add esp, 4
			call my_malloc
			mov dword[ebp-36], eax
			add esp, 4
			call my_malloc
			mov dword[ebp-32], eax
			add esp, 4
			
			;transform the changed blocks vector
			mov ecx, dword[ebp-28]	;index in ecx
			mov edx, dword[ebp-16]	;current changed block in edx
			mov esi, dword[ebp-32]	;current block type in esi
			mov edi, dword[ebp-36]	;current chunk pos in edi
			mov ebx, dword[ebp-40]	;current block pos in ebx
			chunkManager4d_loadChunk_internal_not_veteran_loop_start:
				mov eax, dword[edx]
				mov dword[esi], eax
				
				mov eax, dword[edx+4]
				mov dword[edi], eax
				mov eax, dword[edx+8]
				mov dword[edi+4], eax
				mov eax, dword[edx+12]
				mov dword[edi+8], eax
				
				mov eax, dword[edx+16]
				mov dword[ebx], eax
				mov eax, dword[edx+20]
				mov dword[ebx+4], eax
				mov eax, dword[edx+24]
				mov dword[ebx+8], eax
				mov eax, dword[edx+28]
				mov dword[ebx+12], eax
				
				add edx, 32
				add esi, 4
				add edi, 12
				add ebx, 16
				dec ecx
				jnz chunkManager4d_loadChunk_internal_not_veteran_loop_start
				
			;add the first timers to the pending changed blocks
			push 0
			push dword[ebp-40]
			push dword[ebp-36]
			push dword[ebp-32]
			push dword[ebp-28]
			push dword[ebp+20]
			call chunkManager4d_registerChangedBlockArray
			
		chunkManager4d_loadChunk_internal_not_veteran_no_first_timers:
		
		;delete the first timer block vector
		lea eax, [ebp-28]
		push eax
		call vector_destroy
	
	chunkManager4d_loadChunk_internal_load_done:
	
	;create graphics update
	mov eax, dword[ebp-4]
	test dword[eax+52], 0xffffffff
	jz chunkManager4d_loadChunk_internal_graphics_update_no_update
		;there is a graphics update
		push 0
		push dword[ebp-4]
		push 69
		mov ecx, dword[ebp+20]
		lea ecx, [ecx+36]
		push ecx
		call tsQueue_push
		
		jmp chunkManager4d_loadChunk_internal_graphics_update_done
	
	chunkManager4d_loadChunk_internal_graphics_update_no_update:
		;there is no graphics update, straight into the loaded chunks
		push dword[ebp-4]
		mov ecx, dword[ebp+20]
		push ecx
		call tsVector_pushBack
	
	chunkManager4d_loadChunk_internal_graphics_update_done:
	
	chunkManager4d_loadChunk_internal_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	;int chunkManager4d_loadChunk_internal_veteran_comparator(Chunk4D** pchunk, ivec3* chunkPos)
	chunkManager4d_loadChunk_internal_veteran_comparator:
		push ebp
		mov ebp, esp
		sub esp, 4		;return value		4
		mov dword[ebp-4], 69
		
		mov eax, dword[ebp+8]
		mov eax, dword[eax]
		mov ecx, dword[ebp+12]
		
		mov edx, dword[eax]
		cmp edx, dword[ecx]
		jne chunkManager4d_loadChunk_internal_veteran_comparator_end
		mov edx, dword[eax+4]
		cmp edx, dword[ecx+4]
		jne chunkManager4d_loadChunk_internal_veteran_comparator_end
		mov edx, dword[eax+8]
		cmp edx, dword[ecx+8]
		jne chunkManager4d_loadChunk_internal_veteran_comparator_end
			mov dword[ebp-4], 0
		chunkManager4d_loadChunk_internal_veteran_comparator_end:
		mov eax, dword[ebp-4]
		mov esp, ebp
		pop ebp
		ret
		
	
;unregisters and destroys a chunk
;if nullableOutRenderable == NULL, a graphics unload update is pushed onto the graphics update queue (if there was a renderable)
;otherwise the renderable (or NULL if no renderable) is written into the location pointed by nullableOutRenderable
;void chunkManager4d_unloadChunk_internal(
;	ChunkManager4D* cm,
;	Chunk4D* chunk,
;	Renderable** nullableOutRenderable
;);
chunkManager4d_unloadChunk_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;chunk renderable		4
	
	;remove the chunk from the graphics update queue or the loaded chunks vector
	push dword[ebp+24]
	push chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda
	mov eax, dword[ebp+20]
	add eax, 36
	push eax
	call tsQueue_forEach
	
	push dword[ebp+24]
	push dword[ebp+20]
	call tsVector_remove
	
	;yeet the unprocessed chunk graphics data if necessary
	mov eax, dword[ebp+24]
	push dword[eax+52]
	call my_free
	
	;get the renderable
	mov eax, dword[ebp+24]
	mov eax, dword[eax+12]
	mov dword[ebp-4], eax
	
	;unload the chunk
	push dword[ebp+24]
	call chunk4d_destroy
	
	;do something with the renderable
	test dword[ebp+28], 0xffffffff
	jz chunkManager4d_unloadChunk_internal_renderable_yeet
		;write renderable into the buffer
		mov eax, dword[ebp+28]
		mov ecx, dword[ebp-4]
		mov dword[eax], ecx
		jmp chunkManager4d_unloadChunk_internal_renderable_done
		
	chunkManager4d_unloadChunk_internal_renderable_yeet:
		test dword[ebp-4], 0xffffffff
		jz chunkManager4d_unloadChunk_internal_renderable_done
			;create graphics update for the renderable
			push 0			;not fantom
			push dword[ebp-4]
			push 0
			mov eax, dword[ebp+20]
			add eax, 36
			push eax
			call tsQueue_push
		
	chunkManager4d_unloadChunk_internal_renderable_done:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	;void chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda(GraphicsUpdate*, Chunk4D*)
	chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda:
		mov eax, dword[esp+4]
		test dword[eax], 0xffffffff
		jz chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda_end	;not load update
		mov ecx, dword[esp+8]
		cmp ecx, dword[eax+4]
		jne chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda_end
			mov dword[eax+4], 0
		chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda_end:
		ret

;returns true if the chunk is either in the loaded chunks vector or in the pending graphics updates queue (as a load update)
;int chunkManager4d_isChunkLoaded(ChunkManager4D* cm, ivec3 chunkPos)
chunkManager4d_isChunkLoaded:
	push ebp
	mov ebp, esp
	
	;check for the pending graphics updates
	mov eax, dword[ebp+8]
	add eax, 36
	lea ecx, [ebp+12]
	push ecx
	push chunkManager4d_isChunkLoaded_graphics_update_comparator
	push eax
	call tsQueue_search
	
	mov ecx, eax
	mov eax, 69
	cmp ecx, -1
	jne chunkManager4d_isChunkLoaded_end
	
	
	;check for the loaded chunks
	mov eax, dword[ebp+8]
	lea ecx, [ebp+12]
	push ecx
	push chunkManager4d_isChunkLoaded_loaded_chunks_comparator
	push eax
	call tsVector_search
	
	mov ecx, eax
	mov eax, 69
	cmp ecx, -1
	jne chunkManager4d_isChunkLoaded_end
	
	
	xor eax, eax
	
	chunkManager4d_isChunkLoaded_end:	
	mov esp, ebp
	pop ebp
	ret
	;int chunkManager4d_isChunkLoaded_graphics_update_comparator(GraphicsUpdate* gu, ivec3* chunkPos)
	chunkManager4d_isChunkLoaded_graphics_update_comparator:
		push ebp
		mov ebp, esp
		
		sub esp, 4			;return value	4
		
		mov dword[ebp-4], 69
		
		mov eax, dword[ebp+8]
		test dword[eax], 0xffffffff
		jz chunkManager4d_isChunkLoaded_graphics_update_comparator_end		;not load update
		mov eax, dword[eax+4]
		mov ecx, dword[ebp+12]
		
		mov edx, dword[eax]
		cmp edx, dword[ecx]
		jne chunkManager4d_isChunkLoaded_graphics_update_comparator_end
		mov edx, dword[eax+4]
		cmp edx, dword[ecx+4]
		jne chunkManager4d_isChunkLoaded_graphics_update_comparator_end
		mov edx, dword[eax+8]
		cmp edx, dword[ecx+8]
		jne chunkManager4d_isChunkLoaded_graphics_update_comparator_end
		
		mov dword[ebp-4], 0
		
		chunkManager4d_isChunkLoaded_graphics_update_comparator_end:
		mov eax, dword[ebp-4]
		
		mov esp, ebp
		pop ebp
		ret
	;int chunkManager4d_isChunkLoaded_loaded_chunks_comparator(Chunk4D** gu, ivec3* chunkPos)
	chunkManager4d_isChunkLoaded_loaded_chunks_comparator:
		push ebp
		mov ebp, esp
		
		sub esp, 4			;return value	4
		mov dword[ebp-4], 69
		
		mov eax, dword[ebp+8]
		mov eax, dword[eax]
		mov ecx, dword[ebp+12]
		
		mov edx, dword[eax]
		cmp edx, dword[ecx]
		jne chunkManager4d_isChunkLoaded_loaded_chunks_comparator_end
		mov edx, dword[eax+4]
		cmp edx, dword[ecx+4]
		jne chunkManager4d_isChunkLoaded_loaded_chunks_comparator_end
		mov edx, dword[eax+8]
		cmp edx, dword[ecx+8]
		jne chunkManager4d_isChunkLoaded_loaded_chunks_comparator_end
		
		mov dword[ebp-4], 0
		
		chunkManager4d_isChunkLoaded_loaded_chunks_comparator_end:
		mov eax, dword[ebp-4]
		
		mov esp, ebp
		pop ebp
		ret