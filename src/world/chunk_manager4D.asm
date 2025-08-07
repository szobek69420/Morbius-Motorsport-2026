[BITS 32]

;layout:
;struct ChunkManager4D{
;	vector<Chunk4D*> loadedChunk;								0
;	Mutex* loadedChunksMutex;									16
;	tsQueue<ChunkGraphicsUpdate4D*> pendingGraphicsUpdates;		20
;	GLuint shader;												28
;	HyperPlane hyperPlane;										32
;	hashMap<ivec3, ChangedBlockInfo>* changedBlocks;			96 //doesn't need a mutex as it is used only on the chunk generation thread
;	padding of 12 bytes
;	tsQueue<PendingChangedBlockInfo> pendingChangedBlocks;		112
;	TextureArrayInfo* blockTextures;							120
;	vector<ivec3> veteranChunks;								124 //chunks that have been loaded at least once
;	vector<struct{ivec3;Renderable*;int id}> fanthomChunks;			140 //fanthom chunks are remaining renderables of no longer existing chunks, they are kept during a reload to prevent flickering
;	Mutex* fanthomChunkMutex;									156
;}			160 bytes overall

;layout:
;struct ChunkGraphicsUpdate4D{
;	void* data					0, it is Chunk4D* if load update, otherwise a renderable*; if it is NULL, then the update is yeeted
;	int isLoadUpdate;			4
;	union{	
;		struct LoadData{};
;		struct UnloadData{
;			ChunkManager4D* chunkManager;	//NULL if no fanthom unload
;			int chunkX, chunkZ, chunkW;
;		}
;	}	
;}		8 bytes for load update, 24 bytes for unload update

;layout:
;struct ChangedBlockInfo{
;	int blockType;
;	int chunkX, chunkZ, chunkW;
;	int blockX, blockY, blockZ, blockW;
;}		32 bytes overall

;layout:
;struct PendingChangedBlockInfo{
;	ChangedBlockInfo info;			0
;	int hasPriority;				32	//necessary, because just putting the block onto the beginning of the queue doesn't guarantee a swift chunk reload
;} 36 bytes overall 

;process of loading a chunk:
;
;chunkManager_load finds a chunk that is suitable for loading and generates it (and by it, heh let's just say, the chunk)
;then (with the generated vertex data, but not with the renderable) adds the chunk to the loaded chunks viktor
;a ChunkGraphicsUpdate is also yanked onto the pendingGraphicsUpdates queue
;the ChunkGraphicsUpdate is yoinked from the queue on the graphics(main) thread by chunkManager_processGraphicsUpdate
;the renderable of the chunk is generated
;the chunk is yanks into the loadedChunks vector
;the unload function can only yeet a chunk if its chunkAlreadyProcessed flag is non-nulla

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
	
	test_text db "you're so portuguese",10,0
	test_text2 db "you're so portuguese2",10,0
	test_text3 db "you're so portuguese3",10,0
	
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_four_ints_nl db "%d %d %d %d",10,0
	print_float_nl db "%f",10,0
	print_four_floats_nl db "%f %f %f %f",10,0
	
	ZERO dd 0.0
	ONE dd 1.0
	MINUS_ONE dd -1.0
	MINUS_SIXTEEN dd -16.0
	
section .data use32
	CURRENT_FANTHOM_ID dd 0
	
section .text use32

	;should be called from the graphics thread
	global chunkManager4d_create					;ChunkManager4D* chunkManager4d_create()
	global chunkManager4d_destroy					;void chunkManager4d_destroy(ChunkManager4D*)
	
	global chunkManager4d_load					;void chunkManager4d_load(ChunkManager4D* manager, vec3* playerPos3D, int renderDistance)
	global chunkManager4d_unload					;void chunkManager4d_unload(ChunkManager4D* manager, vec3* playerPos3D, int renderDistance)
	
	;should be called from the graphics thread
	;returns 0 if no graphics update has been processed
	global chunkManager4d_processGraphicsUpdate	;int chunkManager4d_processGraphicsUpdate(ChunkManager4D* manager)
	
	global chunkManager4d_render					;void chunkManager4d_render(ChunkManager4D* manager, mat4* view, mat4* projection)
	
	global chunkManager4d_getHyperPlane			;HyperPlane* chunkManager4d_getHyperPlane(ChunkManager4D* cm)
	global chunkManager4d_setHyperPlane			;void chunkManager4d_setHyperPlane(ChunkManager4D* cm, HyperPlane* ph)
	
	global chunkManager4d_getPlayerChunk4D			;void chunkManager4d_getPlayerChunk4D(ChunkManager4D* cm, vec3* playerPos3D, int* chunkX, int* chunkZ, int* chunkW)
	
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
	
	global chunkManager4d_processChangedBlocks	;void chunkManager4d_processChangedBlock(ChunkManager4D* cm)
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy
	extern my_memset_dword
	extern my_qsort
	
	extern chunk4d_generate
	extern chunk4d_destroy
	extern CHUNK_WIDTH
	
	extern hyperPlane_create
	extern hyperPlane_getNormal
	extern hyperPlane_positionTo3d
	
	extern mutex_create
	extern mutex_destroy
	extern mutex_lock
	extern mutex_unlock
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove
	extern vector_remove_at
	extern vector_search
	extern vector_push_back_buffer
	
	extern tsQueue_init
	extern tsQueue_destroy
	extern tsQueue_push
	extern tsQueue_pushArray
	extern tsQueue_pushFront
	extern tsQueue_pushArrayFront
	extern tsQueue_pop
	extern tsQueue_search
	extern tsQueue_isEmpty
	extern tsQueue_at
	extern tsQueue_size
	extern tsQueue_forEach
	extern queue_printInfo
	
	extern hashMap_init
	extern hashMap_destroy
	extern hashMap_add
	extern hashMap_get
	
	extern vec3_normalize
	extern vec4_add
	extern vec4_scale
	extern vec4_dot
	extern vec4_mulWithMat
	extern vec4_print
	extern mat4_mul
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_setAlbedo
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	extern renderable_setUniform
	extern renderable_setPrimitive
	extern renderable_calculateNormalMatrix
	extern RENDERABLE_UNIFORM_VEC3
	extern RENDERABLE_UNIFORM_VEC4
	extern RENDERABLE_UNIFORM_MAT3
	extern RENDERABLE_UNIFORM_MAT4
	
	extern textureHandler_bindArray
	extern block_importTextures
	extern block_deleteTextures
	
	extern GL_POINTS
	extern glGetUniformLocation
	extern glUniform4f
	extern glGetError
	
	extern hyperPlane_directionTo3d
	
	extern sun_getDirection
	
	extern GL_TEXTURE0
	extern GL_TEXTURE_2D_ARRAY
	extern glActiveTexture
	extern glBindTexture

chunkManager4d_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;ChunkManager4D*
	
	;alloc chunk manager
	push 160
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;init vectors and queues
	mov eax, dword[ebp-4]
	push 4
	push eax
	call vector_init
	add esp, 8
	
	mov eax, dword[ebp-4]
	add eax, 20
	push 10000
	push 4
	push eax
	call tsQueue_init
	add esp, 12
	
	
	;init hyperplane
	mov eax, dword[ebp-4]
	add eax, 32
	push eax
	call hyperPlane_create
	
	;create loaded chunk mutex
	call mutex_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+16], eax
	
	;create shader
	push geometry_shader_path
	push fragment_shader_path
	push vertex_shader_path
	call renderable_createShader
	mov ecx, dword[ebp-4]
	mov dword[ecx+28], eax
	
	;init changed blocks hashmap
	call hashMap_init
	mov ecx, dword[ebp-4]
	mov dword[ecx+96], eax
	
	;init pending changed blocks queue
	mov eax, dword[ebp-4]
	lea eax, [eax+112]
	push 16384
	push 36
	push eax
	call tsQueue_init
	
	;import textures
	call block_importTextures
	mov ecx, dword[ebp-4]
	mov dword[ecx+120], eax
	
	;init registered chunk vector
	push 12
	mov ecx, dword[ebp-4]
	add ecx, 124
	push ecx
	call vector_init
	add esp, 8
	
	;init fanthom chunk vector
	push 20
	mov ecx, dword[ebp-4]
	add ecx, 140
	push ecx
	call vector_init
	add esp, 8
	
	;create fanthom chunk mutex
	call mutex_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+156], eax
	
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_destroy:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;unload all chunks -------------------------------
	
	;process the already pending graphics updates
	chunkManager4d_destroy_process_updates_first_loop_start:
		push dword[ebp+20]
		call chunkManager4d_processGraphicsUpdate
		add esp, 4
		cmp eax, 0
		jne chunkManager4d_destroy_process_updates_first_loop_start
		
	;unload the chunks
	chunkManager4d_unload_chunks_loop_start:
		mov eax, dword[ebp+20]
		cmp dword[eax], 0
		jle chunkManager4d_unload_chunks_loop_end		;no more chunks
		
		mov eax, dword[eax+12]
		push 69
		push 69
		push dword[eax]
		push dword[ebp+20]
		call chunkManager4d_unloadChunk_internal
		add esp, 16
		
		jmp chunkManager4d_unload_chunks_loop_start
		
	chunkManager4d_unload_chunks_loop_end:
	
	;process the newly generated pending graphics updates
	chunkManager4d_destroy_process_updates_second_loop_start:
		push dword[ebp+20]
		call chunkManager4d_processGraphicsUpdate
		add esp, 4
		cmp eax, 0
		jne chunkManager4d_destroy_process_updates_second_loop_start
		
		
	;destroy shader
	mov eax, dword[ebp+20]
	push dword[eax+28]
	call renderable_destroyShader
	
	;destroy block textures
	mov eax, dword[ebp+20]
	push dword[eax+120]
	call block_deleteTextures
	
	;destroy mutexes
	mov eax, dword[ebp+20]
	push dword[eax+16]
	call mutex_destroy
	
	mov eax, dword[ebp+20]
	push dword[eax+156]
	call mutex_destroy
	
	;destroy collections
	mov eax, dword[ebp+20]
	push eax
	call vector_destroy
	
	mov eax, dword[ebp+20]
	lea eax, [eax+20]
	push eax
	call tsQueue_destroy
	
	mov eax, dword[ebp+20]
	push dword[eax+96]
	call hashMap_destroy
	
	mov eax, dword[ebp+20]
	lea eax, [eax+112]
	push eax
	call tsQueue_destroy
	
	mov eax, dword[ebp+20]
	lea eax, [eax+124]
	push eax
	call vector_destroy
	
	mov eax, dword[ebp+20]
	lea eax, [eax+140]
	push eax
	call vector_destroy
	
	;deallocate space
	push dword[ebp+20]
	call my_free
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
chunkManager4d_render:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 16					;hyperplane normal				16
	sub esp, 4					;hyperplane equation E			20
	sub esp, 4					;hyperplane pointer				24
	sub esp, 16					;sun direction 4d and then 3d	40
	sub esp, 64					;pv	matrix						104
	sub esp, 36					;normal matrix					140
	
	
	;calculate the pv matrix
	mov eax, dword[ebp+20]			;view
	mov ecx, dword[ebp+24]			;projection
	lea edx, [ebp-104]
	push eax
	push ecx
	push edx
	call mat4_mul
	add esp, 12
	
	;calculate the normal matrix
	;NOTE: the model matrix is not necessary for it as there only translation in the case of chomks
	push dword[ebp+20]
	lea eax, [ebp-140]
	push eax
	call renderable_calculateNormalMatrix
	add esp, 8
	
	
	;obtain hyperplane, hyperplane normal and E
	push dword[ebp+16]
	call chunkManager4d_getHyperPlane
	add esp, 4
	mov dword[ebp-24], eax
	
	lea eax, [ebp-16]
	push eax
	push dword[ebp-24]
	call hyperPlane_getNormal		;calculate normal
	call vec4_dot					;calculate E
	add esp, 8
	fstp dword[ebp-20]
	xor dword[ebp-20], 0x80000000
	
	;calculate the sun direction
	lea eax, [ebp-40]
	push eax
	call sun_getDirection
	pop eax
	
	push eax
	push eax
	push dword[ebp-24]
	call hyperPlane_directionTo3d
	add esp, 8
	call vec3_normalize
	add esp, 4
	
	;set renderable primitive
	push dword[GL_POINTS]
	call renderable_setPrimitive
	add esp, 4

	;bind block textures
	push 0
	mov eax, dword[ebp+16]
	push dword[eax+120]
	call textureHandler_bindArray
	add esp, 8
	
	;use shader
	mov eax, dword[ebp+16]
	push dword[eax+28]
	call renderable_useShader
	add esp, 4
	
	;set sun direction uniform
	push dword[ebp-32]
	push dword[ebp-36]
	push dword[ebp-40]
	push dword[RENDERABLE_UNIFORM_VEC3]
	push uniform_name_sunDirection
	mov eax, dword[ebp+16]
	push dword[eax+28]
	call renderable_setUniform
	add esp, 24
	
	
	;set hyperplane pos uniform
	mov eax, dword[ebp+16]
	sub esp, 16
	mov ecx, dword[eax+32]
	mov dword[esp], ecx
	mov ecx, dword[eax+36]
	mov dword[esp+4], ecx
	mov ecx, dword[eax+40]
	mov dword[esp+8], ecx
	mov ecx, dword[eax+44]
	mov dword[esp+12], ecx
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlanePos
	push dword[eax+28]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane dir1 uniform
	mov eax, dword[ebp+16]
	sub esp, 16
	mov ecx, dword[eax+48]
	mov dword[esp], ecx
	mov ecx, dword[eax+52]
	mov dword[esp+4], ecx
	mov ecx, dword[eax+56]
	mov dword[esp+8], ecx
	mov ecx, dword[eax+60]
	mov dword[esp+12], ecx
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlaneDir1
	push dword[eax+28]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane dir2 uniform
	mov eax, dword[ebp+16]
	sub esp, 16
	mov ecx, dword[eax+64]
	mov dword[esp], ecx
	mov ecx, dword[eax+68]
	mov dword[esp+4], ecx
	mov ecx, dword[eax+72]
	mov dword[esp+8], ecx
	mov ecx, dword[eax+76]
	mov dword[esp+12], ecx
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlaneDir2
	push dword[eax+28]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane dir3 uniform
	mov eax, dword[ebp+16]
	sub esp, 16
	mov ecx, dword[eax+80]
	mov dword[esp], ecx
	mov ecx, dword[eax+84]
	mov dword[esp+4], ecx
	mov ecx, dword[eax+88]
	mov dword[esp+8], ecx
	mov ecx, dword[eax+92]
	mov dword[esp+12], ecx
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlaneDir3
	push dword[eax+28]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane normal uniform
	mov eax, dword[ebp+16]
	add eax, 32
	sub esp, 16
	mov ecx, esp
	push ecx
	push eax
	call hyperPlane_getNormal
	add esp, 8
	mov eax, dword[ebp+16]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlaneNormal
	push dword[eax+28]
	call renderable_setUniform
	add esp, 28
	
	;set normal matrix uniform
	push dword[ebp+20]
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_view_mat
	mov ecx, dword[ebp+16]
	push dword[ecx+28]
	call renderable_setUniform
	add esp, 16

	;set normal matrix uniform
	lea eax, [ebp-140]
	push eax
	push dword[RENDERABLE_UNIFORM_MAT3]
	push uniform_name_normal_mat
	mov ecx, dword[ebp+16]
	push dword[ecx+28]
	call renderable_setUniform
	add esp, 16
	
	
	mov edi, dword[ebp+16]
	mov esi, dword[edi]				;chunk count in esi
	mov edi, dword[edi+12]				;current chunk in edi
	test esi, esi
	jz chunkManager4d_render_loop_end
	chunkManager4d_render_loop_start:
		;check if there is a renderable for the current chunk
		mov eax, dword[edi]
		cmp dword[eax+12], 0
		je chunkManager4d_render_loop_continue
		
		;do frustum culling
		push dword[ebp-24]			;hyperplane
		lea eax, [ebp-104]
		push eax					;pv
		push dword[ebp-20]			;E
		lea eax, [ebp-16]
		push eax					;normal
		push dword[edi]
		call chunkManager4d_frustumCull
		add esp, 20
		test eax, eax
		jnz chunkManager4d_render_loop_continue
		
		;set chunkPos uniform
		mov eax, dword[edi]
		
		mov ecx, dword[eax+8]
		imul ecx, dword[CHUNK_WIDTH]
		push ecx
		fild dword[esp]
		fstp dword[esp]
		
		mov ecx, dword[eax+4]
		imul ecx, dword[CHUNK_WIDTH]
		push ecx
		fild dword[esp]
		fstp dword[esp]
		
		push 0
		
		mov ecx, dword[eax]
		imul ecx, dword[CHUNK_WIDTH]
		push ecx
		fild dword[esp]
		fstp dword[esp]
		
		
		push dword[RENDERABLE_UNIFORM_VEC4]
		push uniform_name_chunkPos
		mov eax, dword[ebp+16]
		push dword[eax+28]
		call renderable_setUniform
		add esp, 28
		
		;render chunk
		mov eax, dword[edi]
		push 69					;use textures
		mov ecx, dword[ebp+16]
		push dword[ecx+28]		;shader
		lea ecx, [ebp-104]
		push ecx					;pv
		push dword[eax+12]
		call renderable_renderCustom
		add esp, 16
	
		chunkManager4d_render_loop_continue:
		add edi, 4
		dec esi
		test esi, esi
		jnz chunkManager4d_render_loop_start
		
	chunkManager4d_render_loop_end:
	
	;render fanthom chunks
	mov eax, dword[ebp+16]
	cmp dword[eax+140], 0
	jle chunkManager4d_render_fanthom_chunks_skip
	
		;lock fanthom mutex
		mov eax, dword[ebp+16]
		push -1
		push dword[eax+156]
		call mutex_lock
		add esp, 8
		
		mov eax, dword[ebp+16]
		mov esi, dword[eax+140]
		mov edi, dword[eax+152]
		cmp esi, 0
		jle chunkManager4d_render_fanthom_chunks_loop_end	;ko ez a check
		chunkManager4d_render_fanthom_chunks_loop_start:
			;set chunkPos uniform
			mov ecx, dword[edi+8]
			imul ecx, dword[CHUNK_WIDTH]
			push ecx
			fild dword[esp]
			fstp dword[esp]
			
			mov ecx, dword[edi+4]
			imul ecx, dword[CHUNK_WIDTH]
			push ecx
			fild dword[esp]
			fstp dword[esp]
			
			push 0
			
			mov ecx, dword[edi]
			imul ecx, dword[CHUNK_WIDTH]
			push ecx
			fild dword[esp]
			fstp dword[esp]
			
			
			push dword[RENDERABLE_UNIFORM_VEC4]
			push uniform_name_chunkPos
			mov eax, dword[ebp+16]
			push dword[eax+28]
			call renderable_setUniform
			add esp, 28
			
			;render chunk
			push 69					;use textures
			mov ecx, dword[ebp+16]
			push dword[ecx+28]		;shader
			lea eax, [ebp-104]
			push eax					;pv
			push dword[edi+12]
			call renderable_renderCustom
			add esp, 16
			
			
			add edi, 20
			dec esi
			test esi, esi
			jnz chunkManager4d_render_fanthom_chunks_loop_start
		chunkManager4d_render_fanthom_chunks_loop_end:
		
		;unlock fanthom mutex
		mov eax, dword[ebp+16]
		push dword[eax+156]
		call mutex_unlock
		add esp, 4
	
	chunkManager4d_render_fanthom_chunks_skip:
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
chunkManager4d_load:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4				;player chunk x					4
	sub esp, 4				;player chunk z					8
	sub esp, 4				;player chunk w					12
	
	sub esp, 4				;loaded chunk X					16
	sub esp, 4				;loaded chunk Z					20
	sub esp, 4				;loaded chunk W					24
	sub esp, 4				;chunk to load found			28
	
	sub esp, 4				;temp chunk w					32
	sub esp, 4				;temp chunk z					36
	sub esp, 4				;temp chunk x					40
	
	mov dword[ebp-28], 0
	
	;calculate player chunk pos
	lea eax, [ebp-12]
	push eax
	add eax, 4
	push eax
	add eax, 4
	push eax
	push dword[ebp+24]
	push dword[ebp+20]
	call chunkManager4d_getPlayerChunk
	add esp, 20
	
	;search for an unloaded chunk
	;searches in an expanding radius from the player chunk
	xor ebx, ebx			;radius in ebx
	chunkManager4d_load_radius_loop_start:
		mov esi, ebx
		neg esi				;x index in esi
		chunkManager4d_load_x_loop_start:
			mov edi, ebx
			neg edi				;z index in edi
			chunkManager4d_load_z_loop_start:
				mov eax, ebx
				neg eax				;w index in eax
				chunkManager4d_load_w_loop_start:
					;check if the chunk is loaded
					push eax						;save eax
					
					mov ecx, dword[ebp-4]
					add ecx, esi
					mov dword[ebp-40], ecx			;chunkX
					mov ecx, dword[ebp-8]
					add ecx, edi
					mov dword[ebp-36], ecx			;chunkZ
					mov ecx, dword[ebp-12]
					add ecx, eax
					mov dword[ebp-32], ecx			;chunkW
					
					;loaded chunk
					lea eax, [ebp-40]
					mov ecx, dword[ebp+20]
					sub esp, 12
					mov dword[esp+8], eax
					mov dword[esp+4], chunkManager4d_loaded_chunks_search
					mov dword[esp], ecx
					call vector_search
					add esp, 12
					cmp eax, -1
					jne chunkManager4d_load_w_loop_continue
					
					
					;pending graphics updates
					lea eax, [ebp-40]
					mov ecx, dword[ebp+20]
					add ecx, 20
					sub esp, 12
					mov dword[esp+8], eax
					mov dword[esp+4], chunkManager4d_pending_graphics_updates_search
					mov dword[esp], ecx
					call tsQueue_search
					add esp, 12
					cmp eax, -1
					jne chunkManager4d_load_w_loop_continue
					
					
					;the chunk is not loaded yet, mark it as loadable
					mov dword[ebp-28], 69
					
					mov edx, dword[ebp-40]
					mov dword[ebp-16], edx
					mov edx, dword[ebp-36]
					mov dword[ebp-20], edx
					mov edx, dword[ebp-32]
					mov dword[ebp-24], edx
					jmp chunkManager4d_load_radius_loop_end
					
					chunkManager4d_load_w_loop_continue:
					pop eax					;restore eax
					
					inc eax
					cmp eax, ebx
					jle chunkManager4d_load_w_loop_start
				
				inc edi
				cmp edi, ebx
				jle chunkManager4d_load_z_loop_start
				
			inc esi
			cmp esi, ebx
			jle chunkManager4d_load_x_loop_start
			
		inc ebx
		cmp ebx, dword[ebp+28]
		jle chunkManager4d_load_radius_loop_start
		
	chunkManager4d_load_radius_loop_end:
	
	;did we find a loadable chunk?
	cmp dword[ebp-28], 0
	je chunkManager4d_load_end
	
		;generate chunk
		push 0
		push dword[ebp-24]			;chunkw
		push dword[ebp-20]			;chunkz
		push dword[ebp-16]			;chunkx
		push dword[ebp+20]
		call chunkManager4d_loadChunk_internal
		add esp, 20
	
	chunkManager4d_load_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
	
chunkManager4d_unload:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4				;unloaded chunk w			4
	sub esp, 4				;unloaded chunk z			8
	sub esp, 4				;unloaded chunk x			12
	sub esp, 4				;unloadable chunk			16
	
	sub esp, 4				;player chunk w				20
	sub esp, 4				;player chunk z				24
	sub esp, 4				;player chunk x				28
	
	mov dword[ebp-16], 0
	
	;calculate player chunk
	lea eax, [ebp-20]
	push eax
	sub eax, 4
	push eax
	sub eax, 4
	push eax
	push dword[ebp+24]
	push dword[ebp+20]
	call chunkManager4d_getPlayerChunk
	add esp, 20
	
	
	;check if there are any chunks loaded
	mov eax, dword[ebp+20]
	mov eax, dword[eax]
	cmp eax, 0
	jle chunkManager4d_unload_end
	
	;lock vector mutex
	mov eax, dword[ebp+20]
	push -1
	push dword[eax+16]
	call mutex_lock
	add esp, 8
	
	;search for chunk updates
	mov eax, dword[ebp+20]
	mov esi, dword[eax]				;index in esi
	mov edi, dword[eax+12]			;current chunk element in edi (edi is a Chunk4D**)
	chunkManager4d_unload_unload_loop_start:
		mov ebx, dword[edi]			;chunk in ebx
		
		;check if the chunk is processed
		cmp dword[ebx+60], 0
		je chunkManager4d_unload_unload_loop_continue
		
		;check if the chunk is out of the render distance
		mov eax, dword[ebx]
		sub eax, dword[ebp-28]
		test eax, 0x80000000
		jz chunkManager4d_unload_unload_loop_not_neg_x
			neg eax
		chunkManager4d_unload_unload_loop_not_neg_x:
		cmp eax, dword[ebp+28]
		jg chunkManager4d_unload_unload_loop_should_unload
		
		mov eax, dword[ebx+4]
		sub eax, dword[ebp-24]
		test eax, 0x80000000
		jz chunkManager4d_unload_unload_loop_not_neg_z
			neg eax
		chunkManager4d_unload_unload_loop_not_neg_z:
		cmp eax, dword[ebp+28]
		jg chunkManager4d_unload_unload_loop_should_unload
		
		mov eax, dword[ebx+8]
		sub eax, dword[ebp-20]
		test eax, 0x80000000
		jz chunkManager4d_unload_unload_loop_not_neg_w
			neg eax
		chunkManager4d_unload_unload_loop_not_neg_w:
		cmp eax, dword[ebp+28]
		jg chunkManager4d_unload_unload_loop_should_unload
		
		jmp chunkManager4d_unload_unload_loop_continue
		
		chunkManager4d_unload_unload_loop_should_unload:
			;save info
			mov dword[ebp-16], ebx
			
			mov ecx, dword[ebx]
			mov dword[ebp-12], ecx
			mov ecx, dword[ebx+4]
			mov dword[ebp-8], ecx
			mov ecx, dword[ebx+8]
			mov dword[ebp-4], ecx
			
			jmp chunkManager4d_unload_unload_loop_end
			
		chunkManager4d_unload_unload_loop_continue:
		add edi, 4
		dec esi
		test esi, esi
		jnz chunkManager4d_unload_unload_loop_start
		
	chunkManager4d_unload_unload_loop_end:
	
	;unlock vector mutex
	mov eax, dword[ebp+20]
	push dword[eax+16]
	call mutex_unlock
	add esp, 4
		
	;did we find an unloadable chunk?
	cmp dword[ebp-16], 0
	je chunkManager4d_unload_end
	
		;unload chunk
		push 69				;destroy renderable
		push 69				;chunk should be unregistered
		push dword[ebp-16]
		push dword[ebp+20]
		call chunkManager4d_unloadChunk_internal
		add esp, 16
	
	chunkManager4d_unload_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
chunkManager4d_processGraphicsUpdate:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;graphics update				4
	sub esp, 16			;imitated vertex vector			20
	sub esp, 4			;created renderable				24
	sub esp, 4			;return value					28
	
	mov dword[ebp-28], 0
	
	;check if the pending updates queue is empty
	mov eax, dword[ebp+8]
	add eax, 20
	push eax
	call tsQueue_isEmpty
	add esp, 4
	test eax, eax
	jnz chunkManager4d_processGraphicsUpdate_end
	
	;pop an update
	lea eax, [ebp-4]
	push eax
	mov eax, dword[ebp+8]
	add eax, 20
	push eax
	call tsQueue_pop
	add esp, 8
	
	;check if the update shall be yeeted
	mov eax, dword[ebp-4]
	test dword[eax], 0xffffffff
	jnz chunkManager4d_processGraphicsUpdate_no_yeet
		;set return value
		mov dword[ebp-28], 69
		
		;dealloc update
		push eax
		call my_free
		add esp, 4
		
		jmp chunkManager4d_processGraphicsUpdate_end
		
	chunkManager4d_processGraphicsUpdate_no_yeet:

	
	;examine what kind of update it is
	mov eax, dword[ebp-4]
	cmp dword[eax+4], 0
	je chunkManager4d_processGraphicsUpdate_unload
		;it is a load update
		mov eax, dword[ebp-4]
		mov eax, dword[eax]				;chunk in eax
		cmp dword[eax+56], 0
		je chunkManager4d_processGraphicsUpdate_no_mesh			;there is no mesh
		
			;create the imitated vertex vector
			mov ecx, dword[eax+56]
			mov dword[ebp-20], ecx
			mov dword[ebp-16], ecx
			mov dword[ebp-12], 4
			mov ecx, dword[eax+52]
			mov dword[ebp-8], ecx
			
			;create renderable and set texture
			push 1
			push 1
			push 4
			push 1
			push 0
			lea eax, [ebp-20]
			push eax
			call renderable_createCustom
			mov dword[ebp-24], eax
			add esp, 20
			
			;destroy the vertex and index data in the chunk
			mov eax, dword[ebp-4]
			mov eax, dword[eax]
			push dword[eax+52]
			mov dword[eax+52], 0
			mov dword[eax+56], 0
			call my_free
			add esp, 4
			
			;add renderable to the chunk
			mov ecx, dword[ebp-24]
			mov eax, dword[ebp-4]
			mov eax, dword[eax]
			mov dword[eax+12], ecx
		
		chunkManager4d_processGraphicsUpdate_no_mesh:
		
		;mark chunk as processed
		mov ecx, dword[ebp-4]
		mov ecx, dword[ecx]
		mov dword[ecx+60], 69
		
		jmp chunkManager4d_processGraphicsUpdate_dealloc_update
		
	chunkManager4d_processGraphicsUpdate_unload:
		;it is an unload update
		
		;remove the renderable from the fanthom chunks if necessary
		mov eax, dword[ebp-4]
		test dword[eax+8], 0xffffffff
		jz chunkManager4d_processGraphicsUpdate_unload_not_fanthom
			push dword[eax]
			push dword[eax+8]
			call chunkManager4d_unregisterFanthomChunk_internal
		chunkManager4d_processGraphicsUpdate_unload_not_fanthom:
		
		;destroy the renderable
		mov eax, dword[ebp-4]
		push dword[eax]
		call renderable_destroy
		add esp, 4
		
		jmp chunkManager4d_processGraphicsUpdate_dealloc_update
		
	chunkManager4d_processGraphicsUpdate_dealloc_update:
	
	;dealloc update
	push dword[ebp-4]
	call my_free
	
	mov dword[ebp-28], 69
	
	chunkManager4d_processGraphicsUpdate_end:
	mov eax, dword[ebp-28]		;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
chunkManager4d_setHyperPlane:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	add eax, 32
	push 64
	push dword[ebp+12]
	push eax
	call my_memcpy
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_getHyperPlane:
	mov eax, dword[esp+4]
	add eax, 32
	ret
	
chunkManager4d_getPlayerChunk:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;player pos 4d				16
	sub esp, 16				;helper vec4				32
	
	mov eax, dword[ebp+8]
	
	;calculate player pos 4d
	mov ecx, dword[eax+32]
	mov dword[ebp-16], ecx
	mov ecx, dword[eax+36]
	mov dword[ebp-12], ecx
	mov ecx, dword[eax+40]
	mov dword[ebp-8], ecx
	mov ecx, dword[eax+44]
	mov dword[ebp-4], ecx
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	push dword[ecx]
	lea ecx, [eax+48]		;cm.hyperplane.dir1
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
	lea ecx, [eax+64]		;cm.hyperplane.dir2
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
	lea ecx, [eax+80]		;cm.hyperplane.dir3
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
	
chunkManager4d_registerChangedBlock:
	push ebp
	mov ebp, esp
	
	push dword[ebp+24]
	mov eax, dword[ebp+20]
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	mov eax, dword[ebp+16]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push dword[ebp+12]
	mov eax, dword[ebp+8]
	lea eax, [eax+112]
	push eax
	mov ecx, tsQueue_push
	test dword[ebp+24], 0xffffffff			;does the block have priority?
	jz chunkManager4d_registerChangedBlock_no_priority
		mov ecx, tsQueue_pushFront
	chunkManager4d_registerChangedBlock_no_priority:
	call ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_registerChangedBlockArray:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16		;vector<PendingChangedBlockInfo> priority		;16
	sub esp, 16		;vector<PendingChangedBlockInfo> nonPriority	;32
	sub esp, 4		;hasPriorityArray								;36
	
	;check if there are any blocks at all
	cmp dword[ebp+24], 0
	jle chunkManager4d_registerChangedBlockArray_end
	
	;create the vectors
	push 36
	lea eax, [ebp-16]
	push eax
	call vector_init
	sub dword[esp], 16
	call vector_init
	add esp, 8
	
	;initialize the local priority array
	mov eax, dword[ebp+40]
	mov dword[ebp-36], eax
	test eax, eax
	jnz chunkManager4d_registerChangedBlockArray_priority_array_not_null
		;alloc temporary array
		mov eax, dword[ebp+24]
		shl eax, 2
		push eax
		call my_malloc
		mov dword[ebp-36], eax
		
		;set the array to all non-priority
		push 0
		push eax
		call my_memset_dword
		add esp, 12
		
	chunkManager4d_registerChangedBlockArray_priority_array_not_null:
	
	;create and separate the changed block infos
	xor ebx, ebx				;index in ebx
	mov esi, dword[ebp+32]		;current chunk pos in esi
	mov edi, dword[ebp+36]		;current chunk local pos in edi
	chunkManager4d_registerChangedBlockArray_separate_loop_start:
		mov eax, dword[ebp-36]
		push dword[eax+4*ebx]
		push dword[edi+12]
		push dword[edi+8]
		push dword[edi+4]
		push dword[edi]
		push dword[esi+8]
		push dword[esi+4]
		push dword[esi]
		mov ecx, dword[ebp+28]
		push dword[ecx+4*ebx]
		lea edx, [ebp-16]
		push edx
		test dword[eax+4*ebx], 0xffffffff
		jnz chunkManager4d_registerChangedBlockArray_separate_loop_priority
			sub dword[esp], 16
		chunkManager4d_registerChangedBlockArray_separate_loop_priority:
		call vector_push_back
		add esp, 40
		
		add esi, 12
		add edi, 16
		inc ebx
		cmp ebx, dword[ebp+24]
		jl chunkManager4d_registerChangedBlockArray_separate_loop_start
		
	;add the priority blocks to the pending queue
	cmp dword[ebp-16], 0
	jle chunkManager4d_registerChangedBlockArray_no_priority_blocks
		push dword[ebp-16]
		push dword[ebp-4]
		mov eax, dword[ebp+20]
		lea eax, [eax+112]
		push eax
		call tsQueue_pushArrayFront
		
	chunkManager4d_registerChangedBlockArray_no_priority_blocks:
	
	;add the non-priority blocks to the pending queue
	cmp dword[ebp-32], 0
	jle chunkManager4d_registerChangedBlockArray_no_non_priority_blocks
		push dword[ebp-32]
		push dword[ebp-20]
		mov eax, dword[ebp+20]
		lea eax, [eax+112]
		push eax
		call tsQueue_pushArray
		
	chunkManager4d_registerChangedBlockArray_no_non_priority_blocks:
	
	;delete the local priority array if it was created here
	test dword[ebp+40], 0xffffffff
	jnz chunkManager4d_registerChangedBlockArray_priority_array_not_null2
		;dealloc temporary array
		push dword[ebp-36]
		call my_free
		add esp, 4
		
	chunkManager4d_registerChangedBlockArray_priority_array_not_null2:
	
	;destroy the vectors
	lea eax, [ebp-16]
	push eax
	call vector_destroy
	sub dword[esp], 16
	call vector_destroy
	add esp, 4
	
	chunkManager4d_registerChangedBlockArray_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
;only reloads chunks that are already registered
chunkManager4d_processChangedBlocks:
	push ebp
	mov ebp, esp
	
	sub esp, 36				;changed block buffer				36
	sub esp, 36				;neighbour's changed block buffer	72 (helper variable)
	sub esp, 16				;changed chunks	vector<ivec3>		88
	sub esp, 4				;processed block count (debug)		92
	
	mov dword[ebp-92], 0
	
	;create changed chunks vector
	lea eax, [ebp-88]
	push 12
	push eax
	call vector_init
	add esp, 8
	
	chunkManager4d_processChangedBlocks_add_loop_start:
		;is there a pending block?
		mov eax, dword[ebp+8]
		add eax, 112
		push eax
		call tsQueue_isEmpty
		add esp, 4
		test eax, eax
		jnz chunkManager4d_processChangedBlocks_add_loop_end
		
		;pop the block
		lea eax, [ebp-36]
		push eax
		mov eax, dword[ebp+8]
		add eax, 112
		push eax
		call tsQueue_pop
		add esp, 8
		test eax, eax
		jnz chunkManager4d_processChangedBlocks_add_loop_end		;there was a problem
		
		;increment processed block count
		inc dword[ebp-92]
		
		;add the block to the chunk's changed blocks vector
		lea eax, [ebp-36]
		push eax			;value
		lea ecx, [ebp-32]
		push ecx			;key
		push dword[ebp+8]
		call chunkManager4d_processChangedBlock_internal
		add esp, 12
		
		;check if the chunk is registered as changed and do so if nicht
		lea eax, [ebp-32]
		push eax
		push chunkManager4d_changed_block_chunk_comparator
		lea eax, [ebp-88]
		push eax
		call vector_search
		add esp, 12
		cmp eax, -1
		jne chunkManager4d_processChangedBlocks_add_loop_chunk_already_registered
			lea eax, [ebp-32]
			push eax
			lea ecx, [ebp-88]
			push ecx
			call vector_push_back_buffer
			add esp, 8
		chunkManager4d_processChangedBlocks_add_loop_chunk_already_registered:
		
		
		;is the block at the neg x border?
		cmp dword[ebp-20], 0
		jne chunkManager4d_processChangedBlocks_add_loop_not_neg_x
			;copy the changed block buffer to the neighbour's changed block buffer
			push 32
			lea eax, [ebp-36]
			push eax
			lea eax, [ebp-72]
			push eax
			call my_memcpy
			add esp, 12
			;transform the neighbour's block buffer
			mov dword[ebp-56], 16
			dec dword[ebp-68]
			;add the block to the neighbouring chunk's changed blocks vector
			lea eax, [ebp-72]
			push eax			;value
			lea ecx, [ebp-68]
			push ecx			;key
			push dword[ebp+8]
			call chunkManager4d_processChangedBlock_internal
			add esp, 12
			;check if the chunk is registered as changed and do so if nicht
			lea eax, [ebp-68]
			push eax
			push chunkManager4d_changed_block_chunk_comparator
			lea eax, [ebp-88]
			push eax
			call vector_search
			add esp, 12
			cmp eax, -1
			jne chunkManager4d_processChangedBlocks_add_loop_neg_x_chunk_already_registered
				lea eax, [ebp-68]
				push eax
				lea ecx, [ebp-88]
				push ecx
				call vector_push_back_buffer
				add esp, 8
			chunkManager4d_processChangedBlocks_add_loop_neg_x_chunk_already_registered:
		chunkManager4d_processChangedBlocks_add_loop_not_neg_x:
		
		
		;is the block at the pos x border?
		cmp dword[ebp-20], 15
		jne chunkManager4d_processChangedBlocks_add_loop_not_pos_x
			;copy the changed block buffer to the neighbour's changed block buffer
			push 32
			lea eax, [ebp-36]
			push eax
			lea eax, [ebp-72]
			push eax
			call my_memcpy
			add esp, 12
			;transform the neighbour's block buffer
			mov dword[ebp-56], -1
			inc dword[ebp-68]
			;add the block to the neighbouring chunk's changed blocks vector
			lea eax, [ebp-72]
			push eax			;value
			lea ecx, [ebp-68]
			push ecx			;key
			push dword[ebp+8]
			call chunkManager4d_processChangedBlock_internal
			add esp, 12
			;check if the chunk is registered as changed and do so if nicht
			lea eax, [ebp-68]
			push eax
			push chunkManager4d_changed_block_chunk_comparator
			lea eax, [ebp-88]
			push eax
			call vector_search
			add esp, 12
			cmp eax, -1
			jne chunkManager4d_processChangedBlocks_add_loop_pos_x_chunk_already_registered
				lea eax, [ebp-68]
				push eax
				lea ecx, [ebp-88]
				push ecx
				call vector_push_back_buffer
				add esp, 8
			chunkManager4d_processChangedBlocks_add_loop_pos_x_chunk_already_registered:
		chunkManager4d_processChangedBlocks_add_loop_not_pos_x:
		
		
		;is the block at the neg z border?
		cmp dword[ebp-12], 0
		jne chunkManager4d_processChangedBlocks_add_loop_not_neg_z
			;copy the changed block buffer to the neighbour's changed block buffer
			push 32
			lea eax, [ebp-36]
			push eax
			lea eax, [ebp-72]
			push eax
			call my_memcpy
			add esp, 12
			;transform the neighbour's block buffer
			mov dword[ebp-48], 16
			dec dword[ebp-64]
			;add the block to the neighbouring chunk's changed blocks vector
			lea eax, [ebp-72]
			push eax			;value
			lea ecx, [ebp-68]
			push ecx			;key
			push dword[ebp+8]
			call chunkManager4d_processChangedBlock_internal
			add esp, 12
			;check if the chunk is registered as changed and do so if nicht
			lea eax, [ebp-68]
			push eax
			push chunkManager4d_changed_block_chunk_comparator
			lea eax, [ebp-88]
			push eax
			call vector_search
			add esp, 12
			cmp eax, -1
			jne chunkManager4d_processChangedBlocks_add_loop_neg_z_chunk_already_registered
				lea eax, [ebp-68]
				push eax
				lea ecx, [ebp-88]
				push ecx
				call vector_push_back_buffer
				add esp, 8
			chunkManager4d_processChangedBlocks_add_loop_neg_z_chunk_already_registered:
		chunkManager4d_processChangedBlocks_add_loop_not_neg_z:
		
		
		;is the block at the pos z border?
		cmp dword[ebp-12], 15
		jne chunkManager4d_processChangedBlocks_add_loop_not_pos_z
			;copy the changed block buffer to the neighbour's changed block buffer
			push 32
			lea eax, [ebp-36]
			push eax
			lea eax, [ebp-72]
			push eax
			call my_memcpy
			add esp, 12
			;transform the neighbour's block buffer
			mov dword[ebp-48], -1
			inc dword[ebp-64]
			;add the block to the neighbouring chunk's changed blocks vector
			lea eax, [ebp-72]
			push eax			;value
			lea ecx, [ebp-68]
			push ecx			;key
			push dword[ebp+8]
			call chunkManager4d_processChangedBlock_internal
			add esp, 12
			;check if the chunk is registered as changed and do so if nicht
			lea eax, [ebp-68]
			push eax
			push chunkManager4d_changed_block_chunk_comparator
			lea eax, [ebp-88]
			push eax
			call vector_search
			add esp, 12
			cmp eax, -1
			jne chunkManager4d_processChangedBlocks_add_loop_pos_z_chunk_already_registered
				lea eax, [ebp-68]
				push eax
				lea ecx, [ebp-88]
				push ecx
				call vector_push_back_buffer
				add esp, 8
			chunkManager4d_processChangedBlocks_add_loop_pos_z_chunk_already_registered:
		chunkManager4d_processChangedBlocks_add_loop_not_pos_z:
		
		
		;is the block at the neg w border?
		cmp dword[ebp-8], 0
		jne chunkManager4d_processChangedBlocks_add_loop_not_neg_w
			;copy the changed block buffer to the neighbour's changed block buffer
			push 32
			lea eax, [ebp-36]
			push eax
			lea eax, [ebp-72]
			push eax
			call my_memcpy
			add esp, 12
			;transform the neighbour's block buffer
			mov dword[ebp-44], 16
			dec dword[ebp-60]
			;add the block to the neighbouring chunk's changed blocks vector
			lea eax, [ebp-72]
			push eax			;value
			lea ecx, [ebp-68]
			push ecx			;key
			push dword[ebp+8]
			call chunkManager4d_processChangedBlock_internal
			add esp, 12
			;check if the chunk is registered as changed and do so if nicht
			lea eax, [ebp-68]
			push eax
			push chunkManager4d_changed_block_chunk_comparator
			lea eax, [ebp-88]
			push eax
			call vector_search
			add esp, 12
			cmp eax, -1
			jne chunkManager4d_processChangedBlocks_add_loop_neg_w_chunk_already_registered
				lea eax, [ebp-68]
				push eax
				lea ecx, [ebp-88]
				push ecx
				call vector_push_back_buffer
				add esp, 8
			chunkManager4d_processChangedBlocks_add_loop_neg_w_chunk_already_registered:
		chunkManager4d_processChangedBlocks_add_loop_not_neg_w:
		
		
		;is the block at the pos w border?
		cmp dword[ebp-8], 15
		jne chunkManager4d_processChangedBlocks_add_loop_not_pos_w
			;copy the changed block buffer to the neighbour's changed block buffer
			push 32
			lea eax, [ebp-36]
			push eax
			lea eax, [ebp-72]
			push eax
			call my_memcpy
			add esp, 12
			;transform the neighbour's block buffer
			mov dword[ebp-44], -1
			inc dword[ebp-60]
			;add the block to the neighbouring chunk's changed blocks vector
			lea eax, [ebp-72]
			push eax			;value
			lea ecx, [ebp-68]
			push ecx			;key
			push dword[ebp+8]
			call chunkManager4d_processChangedBlock_internal
			add esp, 12
			;check if the chunk is registered as changed and do so if nicht
			lea eax, [ebp-68]
			push eax
			push chunkManager4d_changed_block_chunk_comparator
			lea eax, [ebp-88]
			push eax
			call vector_search
			add esp, 12
			cmp eax, -1
			jne chunkManager4d_processChangedBlocks_add_loop_pos_w_chunk_already_registered
				lea eax, [ebp-68]
				push eax
				lea ecx, [ebp-88]
				push ecx
				call vector_push_back_buffer
				add esp, 8
			chunkManager4d_processChangedBlocks_add_loop_pos_w_chunk_already_registered:
		chunkManager4d_processChangedBlocks_add_loop_not_pos_w:
		
		
		jmp chunkManager4d_processChangedBlocks_add_loop_start
		
	chunkManager4d_processChangedBlocks_add_loop_end:
	
	
	;reload the chunks that can be reloaded
	push esi			;save esi
	push edi			;save edi
	
	mov esi, dword[ebp-88]				;index in esi
	mov edi, dword[ebp-76]				;current chunk in edi
	cmp esi, 0
	jle chunkManager4d_processChangedBlocks_reload_loop_end
	chunkManager4d_processChangedBlocks_reload_loop_start:
		;check if the chunk can be reloaded and do so if ja
		push dword[edi+8]
		push dword[edi+4]
		push dword[edi]
		push dword[ebp+8]
		call chunkManager4d_isChunkLoaded_internal
		test eax, eax
		jz chunkManager4d_processChangedBlocks_reload_loop_no_reload
			call chunkManager4d_reloadChunkByPosition_internal
		chunkManager4d_processChangedBlocks_reload_loop_no_reload:
		add esp, 16
	
		add edi, 12
		dec esi
		test esi, esi
		jnz chunkManager4d_processChangedBlocks_reload_loop_start
	chunkManager4d_processChangedBlocks_reload_loop_end:
	
	pop edi				;restore edi
	pop esi				;restore esi
	
	;yeet the changed chunk vector
	lea eax, [ebp-88]
	push eax
	call vector_destroy
	add esp, 4
	
	chunkManager4d_processChangedBlocks_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;loads a selected chunk
;if outUpdate is NULL, the graphics update is created and registered, otherwise only created (then *outUpdate will be set to the graphics update or NULL if there is no graphics update)
;shouldn't be called under vector mutex lock
;void chunkManager4d_loadChunk_internal(ChunkManager4D* cm, int chunkX, int chunkZ, int chunkW, ChunkGraphicsUpdate4D** outUpdate)
chunkManager4d_loadChunk_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;loaded chunk							4
	sub esp, 4				;changed blocks	vector					8
	sub esp, 4				;is first load							12
	sub esp, 16				;first load changed blocks vector		28
	
	sub esp, 4				;int* changedBlockTypes					32
	sub esp, 4				;ivec3* changedBlockChunks				36
	sub esp, 4				;ivec4* changedBlockPositions			40
	
	mov dword[ebp-12], 0
	
	;check if the chunk is already registered
	lea eax, [ebp+12]
	push eax
	push chunkManager4d_registered_chunk_comparator
	mov ecx, dword[ebp+8]
	add ecx, 124
	push ecx
	call vector_search
	add esp, 12
	
	cmp eax, -1
	jne chunkManager4d_loadChunk_internal_chunk_already_registered
		;mark chunk as first load, add it to the registered chunks vector and init first load changed blocks vector
		mov dword[ebp-12], 69
		
		lea eax, [ebp+12]
		push eax
		mov ecx, dword[ebp+8]
		add ecx, 124
		push ecx
		call vector_push_back_buffer
		add esp, 8
		
		lea eax, [ebp-28]
		push 32
		push eax
		call vector_init
		add esp, 8
		
	chunkManager4d_loadChunk_internal_chunk_already_registered:
	
	;obtain changed blocks vector
	push 12
	lea eax, [ebp+12]
	push eax
	mov eax, dword[ebp+8]
	push dword[eax+96]
	call hashMap_get
	mov dword[ebp-8], eax
	add esp, 12
	
	;generate chunk
	push 0						;first load changed blocks output vector
	cmp dword[ebp-12], 0
	je chunkManager4d_loadChunk_internal_chunk_already_registered2
		lea eax, [ebp-28]
		mov dword[esp], eax
	chunkManager4d_loadChunk_internal_chunk_already_registered2:
	push dword[ebp-8]			;changed blocks
	push dword[ebp+20]			;chunkw
	push dword[ebp+16]			;chunkz
	push dword[ebp+12]			;chunkx
	call chunk4d_generate
	mov dword[ebp-4], eax
	add esp, 20
	
	;deal with the first load changed blocks vector
	cmp dword[ebp-12], 0
	je chunkManager4d_loadChunk_internal_chunk_already_registered3	
		;check if there are first load blocks at all
		cmp dword[ebp-28], 0
		jle chunkManager4d_loadChunk_internal_no_first_load_blocks
			push esi			;save esi
			push edi			;save edi
			push ebx			;save ebx
		
			;allocate the necessary arrays for registerChangedBlockArray
			mov ebx, dword[ebp-28]
			
			lea eax, [4*ebx]
			push eax
			call my_malloc
			mov dword[ebp-32], eax		;block types
			
			lea eax, [ebx+2*ebx]
			shl eax, 2
			push eax
			call my_malloc
			mov dword[ebp-36], eax		;block chunks
			
			mov eax, ebx
			shl eax, 4
			push eax
			call my_malloc
			mov dword[ebp-40], eax		;block positions
			add esp, 12
			
			;fill up the arrays with the first block values
			mov edi, dword[ebp-28]		;index in edi
			mov esi, dword[ebp-16]		;first changed blocks in esi
			mov eax, dword[ebp-32]		;block types in eax
			mov ecx, dword[ebp-36]		;block chunks in ecx
			mov edx, dword[ebp-40]		;block positions in edx
			chunkManager4d_loadChunk_internal_block_data_transform_loop_start:
				mov ebx, dword[esi]
				mov dword[eax], ebx
				
				mov ebx, dword[esi+4]
				mov dword[ecx], ebx
				mov ebx, dword[esi+8]
				mov dword[ecx+4], ebx
				mov ebx, dword[esi+12]
				mov dword[ecx+8], ebx
				
				mov ebx, dword[esi+16]
				mov dword[edx], ebx
				mov ebx, dword[esi+20]
				mov dword[edx+4], ebx
				mov ebx, dword[esi+24]
				mov dword[edx+8], ebx
				mov ebx, dword[esi+28]
				mov dword[edx+12], ebx
			
			
				add esi, 32
				add eax, 4
				add ecx, 12
				add edx, 16
				dec edi
				test edi, edi
				jnz chunkManager4d_loadChunk_internal_block_data_transform_loop_start
				
			;register the blocks
			push 0					;no priority
			push dword[ebp-40]
			push dword[ebp-36]
			push dword[ebp-32]
			push dword[ebp-28]
			push dword[ebp+8]
			call chunkManager4d_registerChangedBlockArray
			add esp, 24
			
			;dealloc the arrays
			push dword[ebp-40]
			call my_free
			push dword[ebp-36]
			call my_free
			push dword[ebp-32]
			call my_free
			add esp, 12
		
			pop ebx				;restore ebx
			pop edi				;restore edi
			pop esi				;restore esi
		chunkManager4d_loadChunk_internal_no_first_load_blocks:
		
	
		lea eax, [ebp-28]
		push eax
		call vector_destroy
		add esp, 4
		
	chunkManager4d_loadChunk_internal_chunk_already_registered3:
	
	;add the chunk to the loaded chunks
	mov eax, dword[ebp+8]
	push -1
	push dword[eax+16]
	call mutex_lock
	add esp, 8
	
	push dword[ebp-4]
	push dword[ebp+8]
	call vector_push_back
	add esp, 8
	
	mov eax, dword[ebp+8]
	push dword[eax+16]
	call mutex_unlock
	add esp, 4
	
	;init the outBuffer if necessary
	test dword[ebp+24], 0xffffffff
	jz chunkManager4d_loadChunk_internal_no_outBuffer
		mov eax, dword[ebp+24]
		mov dword[eax], 0
	chunkManager4d_loadChunk_internal_no_outBuffer:
	
	
	;do we need a graphics update? (is the alreadyProcessed flag on?)
	mov eax, dword[ebp-4]
	cmp dword[eax+60], 0
	jne chunkManager4d_loadChunk_internal_graphics_update_done
		test dword[ebp+24], 0xffffffff
		jz chunkManager4d_loadChunk_internal_create_and_register
			;update should only be created
			push dword[ebp-4]
			push dword[ebp+8]
			call chunkManager4d_createGraphicsLoadUpdate_internal
			add esp, 8
			
			mov ecx, dword[ebp+24]
			mov dword[ecx], eax			;set the outBuffer
			jmp chunkManager4d_loadChunk_internal_graphics_update_done
			
		chunkManager4d_loadChunk_internal_create_and_register:
			;update should be created and registered
			push dword[ebp-4]
			push dword[ebp+8]
			call chunkManager4d_createAndRegisterGraphicsLoadUpdate_internal
			add esp, 8
	
	chunkManager4d_loadChunk_internal_graphics_update_done:
	
	mov esp, ebp
	pop ebp
	ret
	
	
;unloads a selected chunk
;shouldn't be called under vector mutex lock
;isChunkRegistered is non-zero, if the chunk should be only unloaded if it is registered in the chunk manager
;void chunkManager4d_unloadChunk_internal(
;	ChunkManager4D* cm,
;	Chunk4D* chunk,
;	int isChunkRegistered,
;	int shouldDestroyRenderable
;)
chunkManager4d_unloadChunk_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;graphics update				;4
	sub esp, 4		;vector_remove return value		;8
	
	;do we need to remove the chunk from the loaded chunks vector?
	cmp dword[ebp+16], 0
	je chunkManager4d_unloadChunk_internal_skip_remove
	
		;remove chunk from loaded chunks
		mov eax, dword[ebp+8]
		push -1
		push dword[eax+16]
		call mutex_lock
		add esp, 8
		
		push dword[ebp+12]
		push dword[ebp+8]
		call vector_remove
		mov dword[ebp-8], eax
		add esp, 8
		
		mov eax, dword[ebp+8]
		push dword[eax+16]
		call mutex_unlock
		add esp, 4
		
		;flee if the removal from the loadedChunks vector was unsuccessful
		cmp dword[ebp-8], 0
		je chunkManager4d_unloadChunk_internal_end
	
	chunkManager4d_unloadChunk_internal_skip_remove:
	
	;create graphics update and add it to the queue if a renderable is present and should be destroyed
	mov eax, dword[ebp+12]
	mov dword[eax+60], 69			;mark chunk as processed
	cmp dword[eax+12], 0
	je chunkManager4d_unloadChunk_internal_no_renderable		;there is no renderable
	cmp dword[ebp+20], 0
	je chunkManager4d_unloadChunk_internal_no_renderable		;renderable should not be yeeted
		mov dword[eax+60], 0			;unmark chunk as processed
	
		push dword[eax+8]
		push dword[eax+4]
		push dword[eax]
		push 0
		push dword[eax+12]
		push dword[ebp+8]
		call chunkManager4d_createAndRegisterGraphicsUnloadUpdate_internal
		add esp, 24
		
	chunkManager4d_unloadChunk_internal_no_renderable:
	
	
	;yeet chunk
	push dword[ebp+12]
	call chunk4d_destroy
	add esp, 4
	
	chunkManager4d_unloadChunk_internal_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;unloads a selected chunk
;shouldn't be called under vector mutex lock
;output is the address to which the destroyed chunks renderable goes, if output is NULL, the renderable is destroyed here
;void chunkManager4d_unloadChunkByPosition_internal(
;	ChunkManager4D* cm,
;	int chunkX,
;	int chunkZ,
;	int chunkW,
;	Renderable** output
;)
chunkManager4d_unloadChunkByPosition_internal:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+16]
	push -1
	push dword[eax+16]
	call mutex_lock
	add esp, 8
	
	mov eax, dword[ebp+16]
	mov esi, dword[eax+12]			;current chunk in esi
	mov edi, dword[eax]				;index in edi
	cmp edi, 0
	jle chunkManager4d_unloadChunkByPosition_internal_search_done
	chunkManager4d_unloadChunkByPosition_internal_loop_start:
		mov eax, dword[esi]				;chunk* in eax
		
		;check for chunk x
		mov ecx, dword[eax]
		cmp ecx, dword[ebp+20]
		jne chunkManager4d_unloadChunkByPosition_internal_loop_continue
		
		;check for chunk z
		mov ecx, dword[eax+4]
		cmp ecx, dword[ebp+24]
		jne chunkManager4d_unloadChunkByPosition_internal_loop_continue
		
		;check for chunk w
		mov ecx, dword[eax+8]
		cmp ecx, dword[ebp+28]
		jne chunkManager4d_unloadChunkByPosition_internal_loop_continue
		
			;should the renderable be destroyed?
			push 69						;renderable should be destroyed
			test dword[ebp+32], 0xffffffff
			jz chunkManager4d_unloadChunkByPosition_internal_loop_yeet_renderable
				;save renderable into output
				mov ecx, dword[ebp+32]
				mov edx, dword[eax+12]
				mov dword[ecx], edx
				
				;unyeet renderable
				mov dword[esp], 0
				
			chunkManager4d_unloadChunkByPosition_internal_loop_yeet_renderable:
			
			;unload chunk
			push 69
			push eax
			push dword[ebp+16]
			call chunkManager4d_unloadChunk_internal
			add esp, 16
			jmp chunkManager4d_unloadChunkByPosition_internal_search_done
		
		chunkManager4d_unloadChunkByPosition_internal_loop_continue:
		add esi, 4
		dec edi
		test edi, edi
		jnz chunkManager4d_unloadChunkByPosition_internal_loop_start
	
	chunkManager4d_unloadChunkByPosition_internal_search_done:
	
	;unlock vector mutex
	mov eax, dword[ebp+16]
	push dword[eax+16]
	call mutex_unlock
	add esp, 4
	
	chunkManager4d_unloadChunkByPosition_internal_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
;unloads a selected chunk
;shouldn't be called under vector mutex lock
;NOTE: this function heavily relies on two things (not anymore tho):
;	- unloadChunkByPosition always picks to first occurence of a chunk with matching chunkPos in the loaded chunks vector
;	- loadChunk always puts the newly loaded chunks at the end of the loaded chunks vector
;void chunkManager4d_reloadChunkByPosition_internal(ChunkManager4D* cm, int chunkX, int chunkZ, int chunkW)
chunkManager4d_reloadChunkByPosition_internal:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4		;renderable				4
	sub esp, 4		;unload update			8
	sub esp, 4		;load update			12
	
	;helper variables for the unload update yeeting
	sub esp, 16		;vector<Renderable*>	28
	sub esp, 12		;ivec3 chunkPos			40
	
	mov dword[ebp-4], 0
	mov dword[ebp-8], 0
	mov dword[ebp-12], 0
	
	;unload the chunk
	lea eax, [ebp-4]
	push eax
	push dword[ebp+28]
	push dword[ebp+24]
	push dword[ebp+20]
	push dword[ebp+16]
	call chunkManager4d_unloadChunkByPosition_internal
	
	test dword[ebp-4], 0xffffffff
	jz chunkManager4d_reloadChunkByPosition_internal_no_renderable
		;register the fanthom chunk
		mov eax, dword[ebp-4]
		mov dword[esp+16], eax
		call chunkManager4d_registerFanthomChunk_internal
		
		;create the unload update
		push dword[ebp+28]
		push dword[ebp+24]
		push dword[ebp+20]
		push 69					;isFanthom
		push dword[ebp-4]
		push dword[ebp+16]
		call chunkManager4d_createGraphicsUnloadUpdate_internal
		mov dword[ebp-8], eax
		add esp, 24
		
	chunkManager4d_reloadChunkByPosition_internal_no_renderable:
	add esp, 20
	
	;load the new chunk
	lea eax, [ebp-12]
	push eax					;extract the load update
	push dword[ebp+28]
	push dword[ebp+24]
	push dword[ebp+20]
	push dword[ebp+16]
	call chunkManager4d_loadChunk_internal
	add esp, 20

	;register the updates
	test dword[ebp-12], 0xffffffff
	jz chunkManager4d_reloadChunkByPosition_internal_no_load_update
		push 0
		push dword[ebp-12]
		push dword[ebp+16]
		call chunkManager4d_registerGraphicsUpdate_internal
		add esp, 8
	chunkManager4d_reloadChunkByPosition_internal_no_load_update:
	
	test dword[ebp-8], 0xffffffff
	jz chunkManager4d_reloadChunkByPosition_internal_no_unload_update
		;we need to delay the unload of any fanthom renderables for this chunk
		;first, the matching (already registered) unload updates will be yeeted and their renderable in a vector saved
		;then new updates will be erstellt using the previously gathered renderables
	
		;init the renderable vector and the chunk pos
		push 4
		lea eax, [ebp-28]
		push eax
		call vector_init
		add esp, 8
		
		mov eax, dword[ebp+28]
		mov dword[ebp-32], eax
		mov ecx, dword[ebp+24]
		mov dword[ebp-36], ecx
		mov edx, dword[ebp+20]
		mov dword[ebp-40], edx
	
		;if there is an unload update for the current renderable, remove it
		lea eax, [ebp-40]
		push eax
		push chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_helper
		mov eax, dword[ebp+16]
		add eax, 20
		push eax
		call tsQueue_forEach
		add esp, 12
		jmp chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_done
		
		;void function(ChunkGraphicsUpdate4D** pupdate, struct{ivec3, vector<Renderable*>}* data)
		chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_helper:
			mov eax, dword[esp+4]
			mov eax, dword[eax]
			mov ecx, dword[esp+8]
			
			test dword[eax+4], 0xffffffff
			jnz chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_helper_end	;skip if load update
			test dword[eax+8], 0xffffffff
			jz chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_helper_end	;should be fanthom
			
			mov edx, dword[eax+12]
			cmp dword[ecx], edx
			jne chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_helper_end 
			mov edx, dword[eax+16]
			cmp dword[ecx+4], edx
			jne chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_helper_end 
			mov edx, dword[eax+20]
			cmp dword[ecx+8], edx
			jne chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_helper_end 
				;yeet the update
				mov edx, dword[eax]		;save the renderable
				mov dword[eax], 0
				
				;add the renderable to the vector
				push edx
				add ecx, 12
				push ecx
				call vector_push_back
				add esp, 8
			
			chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_helper_end:
			ret
		
		chunkManager4d_reloadChunkByPosition_internal_unload_update_yeet_done:
		
		;re-register the yeeted unload updates
		mov esi, dword[ebp-16]			;current renderable in esi
		mov edi, dword[ebp-28]			;index in edi
		cmp edi, 0
		jle chunkManager4d_reloadChunkByPosition_internal_unload_reregister_loop_end
		chunkManager4d_reloadChunkByPosition_internal_unload_reregister_loop_start:
			push dword[ebp+28]
			push dword[ebp+24]
			push dword[ebp+20]
			push 69
			push dword[esi]
			push dword[ebp+16]
			call chunkManager4d_createAndRegisterGraphicsUnloadUpdate_internal
			add esp, 24
			
			add esi, 4
			dec edi
			test edi, edi
			jnz chunkManager4d_reloadChunkByPosition_internal_unload_reregister_loop_start
		chunkManager4d_reloadChunkByPosition_internal_unload_reregister_loop_end:	
		
		;deinit the renderable vector
		lea eax, [ebp-28]
		push eax
		call vector_destroy
		add esp, 4
	
		;register unload update
		push 0
		push dword[ebp-8]
		push dword[ebp+16]
		call chunkManager4d_registerGraphicsUpdate_internal
		add esp, 8
	chunkManager4d_reloadChunkByPosition_internal_no_unload_update:
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
;void chunkManager4d_registerGraphicsLoadUpdate_internal(ChunkManager4D* cm, ChunkGraphicsUpdate4D* update, int pushToFront)
chunkManager4d_registerGraphicsUpdate_internal:
	push ebp
	mov ebp, esp
	
	mov edx, tsQueue_push
	test dword[ebp+16], 0xffffffff
	jz chunkManager4d_registerGraphicsUpdate_internal_internal_push_back
		mov edx, tsQueue_pushFront
	chunkManager4d_registerGraphicsUpdate_internal_internal_push_back:
	
	;push the update onto the queue
	push dword[ebp+12]
	mov ecx, dword[ebp+8]
	add ecx, 20
	push ecx
	call edx
	
	mov esp, ebp
	pop ebp
	ret
	
	
;allocates space for and initializes a graphics update object 
;ChunkGraphicsUpdate4D* chunkManager4d_createGraphicsLoadUpdate_internal(ChunkManager4D* cm, Chunk4D* chomk)
chunkManager4d_createGraphicsLoadUpdate_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;graphics update			4
	
	;alloc graphics update
	push 8
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 8
	
	;init graphics update
	mov ecx, dword[ebp+12]
	mov dword[eax], ecx		;chomk
	mov dword[eax+4], 69	;load update
	
	;set return value
	mov eax, dword[ebp-4]

	mov esp, ebp
	pop ebp
	ret


;void chunkManager4d_createGraphicsUnloadUpdate_internal(ChunkManager4D* cm, Renderable* renderable, int isFanthom, int chunkX, int chunkZ, int chunkW)
chunkManager4d_createGraphicsUnloadUpdate_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;graphics update			4
	
	;alloc graphics update
	push 24
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 8
	
	;init graphics update
	mov ecx, dword[ebp+12]
	mov dword[eax], ecx		;renderable
	mov dword[eax+4], 0		;unload update
	mov dword[eax+8], 0		;not fanthom
	test dword[ebp+16], 0xffffffff
	jz chunkManager4d_createGraphicsUnloadUpdate_internal_not_fanthom
		mov ecx, dword[ebp+8]
		mov dword[eax+8], ecx
	chunkManager4d_createGraphicsUnloadUpdate_internal_not_fanthom:
	mov edx, dword[ebp+20]
	mov dword[eax+12], edx	;chunkX
	mov ecx, dword[ebp+24]
	mov dword[eax+16], ecx	;chunkZ
	mov edx, dword[ebp+28]
	mov dword[eax+20], edx	;chunkW
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
;creates a graphics load update and pushes it to the end of the pending updates queue
;void chunkManager4d_createAndRegisterGraphicsLoadUpdate_internal(ChunkManager4D* cm, Chunk4D* chomk)
chunkManager4d_createAndRegisterGraphicsLoadUpdate_internal:
	push ebp
	mov ebp, esp
	
	;create the update
	push dword[ebp+12]
	push dword[ebp+8]
	call chunkManager4d_createGraphicsLoadUpdate_internal
	
	;register the update
	push 0					;onto the end
	push eax
	push dword[ebp+8]
	call chunkManager4d_registerGraphicsUpdate_internal
	
	mov esp, ebp
	pop ebp
	ret
	

;creates a graphics unload update and pushes it onto the end of the queue	
;void chunkManager4d_createAndRegisterGraphicsUnloadUpdate_internal(ChunkManager4D* cm, Renderable* renderable, int isFanthom, int chunkX, int chunkZ, int chunkW)
chunkManager4d_createAndRegisterGraphicsUnloadUpdate_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;graphics update			4
	
	push dword[ebp+28]
	push dword[ebp+24]
	push dword[ebp+20]
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[ebp+8]
	call chunkManager4d_createGraphicsUnloadUpdate_internal
	
	;register the update
	push 0					;onto the end
	push eax
	push dword[ebp+8]
	call chunkManager4d_registerGraphicsUpdate_internal
	
	
	mov esp, ebp
	pop ebp
	ret
	

;this function shall only be called from the chunk loader thread, for there is no mutex of fanthom vector
;void chunkManager4d_registerFanthomChunk_internal(ChunkManager4D* cm, ivec3 chunkPos, Renderable* renderable)
chunkManager4d_registerFanthomChunk_internal:
	push ebp
	mov ebp, esp
	
	
	;lock fanthom mutex
	push -1
	mov eax, dword[ebp+8]
	push dword[eax+156]
	call mutex_lock
	add esp, 8
	
	;add fanthom chunk to the viktor
	inc dword[CURRENT_FANTHOM_ID]
	
	push dword[CURRENT_FANTHOM_ID]
	push dword[ebp+24]
	push dword[ebp+20]
	push dword[ebp+16]
	push dword[ebp+12]
	
	mov eax, dword[ebp+8]
	add eax, 140
	push eax
	call vector_push_back
	add esp, 24
	
	;unlock fanthom mutex
	mov eax, dword[ebp+8]
	push dword[eax+156]
	call mutex_unlock
	add esp, 4
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
;removes the fanthom chunk from the vector, but doesn't push the renderable into the graphics update queue
;void chunkManager4d_unregisterFanthomChunk_internal(ChunkManager4D* cm, Renderable* renderable)
chunkManager4d_unregisterFanthomChunk_internal:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;unused				4
	sub esp, 4			;fanthom index		8
	
	mov dword[ebp-8], 0
	
	;lock fanthom mutex
	push -1
	mov eax, dword[ebp+16]
	push dword[eax+156]
	call mutex_lock
	add esp, 8
	
	;remove fanthom chunk from the viktor
	mov eax, dword[ebp+16]
	mov esi, dword[eax+140]		;index in esi
	mov edi, dword[eax+152]		;current fanthom chunk in edi
	cmp esi, 0
	jle chunkManager4d_unregisterFanthomChunk_internal_loop_end
	chunkManager4d_unregisterFanthomChunk_internal_loop_start:
		mov eax, dword[ebp+20]
		cmp dword[edi+12], eax
		jne chunkManager4d_unregisterFanthomChunk_internal_loop_continue
			;chunk found			
			push dword[ebp-8]
			mov eax, dword[ebp+16]
			add eax, 140
			push eax
			call vector_remove_at
			add esp, 8
			
			jmp chunkManager4d_unregisterFanthomChunk_internal_loop_end
	
		chunkManager4d_unregisterFanthomChunk_internal_loop_continue:
		inc dword[ebp-8]
		add edi, 8
		dec esi
		test esi, esi
		jnz chunkManager4d_unregisterFanthomChunk_internal_loop_start
		
	chunkManager4d_unregisterFanthomChunk_internal_loop_end:
	
	;unlock fanthom mutex
	mov eax, dword[ebp+16]
	push dword[eax+156]
	call mutex_unlock
	add esp, 4
	
	
	chunkManager4d_unregisterFanthomChunk_internal_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
;returns 0 if the chunk doesn't need to be culled
;int chunkManager4d_frustumCull(
;	Chunk4D* chunk,
;	vec4* hyperPlaneNormal,
;	float hyperPlaneEquationE,
;	mat4* pv
;	HyperPlane* hp
;)
chunkManager4d_frustumCull:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4				;return value						4
	sub esp, 4				;chunk.colliderGroup				8
	sub esp, 4				;lower bound vector					12
	sub esp, 4				;upper bound vector					16
	sub esp, 16				;current bounding hyperbox vertex	32
	sub esp, 4				;are all distances negative helper	36
	sub esp, 4				;are all distances positive helper	40
	sub esp, 4				;temp distance						44
	sub esp, 16				;lower bound 3d						60
	sub esp, 16				;upper bound 3d						76
	sub esp, 4				;cull mask 3d						80
	sub esp, 16				;current 3d vector					96

	mov dword[ebp-4], 0
	
	mov dword[ebp-36], 0x80000000			;the sign bit needs to be 1 initially
	mov dword[ebp-40], 0x80000000			;the sign bit needs to be 1 initially
	
	;obtain collider group and bounds
	mov eax, dword[ebp+16]
	mov eax, dword[eax+16]
	mov dword[ebp-8], eax
	
	add eax, 16
	mov dword[ebp-12], eax
	add eax, 16
	mov dword[ebp-16], eax
	
	;is the chunk empty?
	mov eax, dword[ebp-8]
	cmp dword[eax], 0
	jg chunkManager4d_frustumCull_chunk_not_empty
		mov dword[ebp-4], 69
		jmp chunkManager4d_frustumCull_end
		
	chunkManager4d_frustumCull_chunk_not_empty:
	
	;check if the chunk intersects with the hyperplane at all
	;aka are there also positive and negative distances (given by the hyperplane's equation) between the hyperplane and the vertices of the bounding hyperbox
	;if all of the distances are negative, then if they are AND-ed together, the resulting sign bit will be 1
	;if all of the distances are positive, then if their opposites are AND-ed together, the resulting sign bit will be 1
	xor esi, esi
	chunkManager4d_frustumCull_hyperplane_intersection_loop_start:
		mov ecx, dword[ebp-12]
		mov edx, dword[ebp-16]
	
		;construct the current vertex
		mov edi, dword[ecx]
		mov dword[ebp-32], edi
		test esi, 0b0001
		jz chunkManager4d_frustumCull_hyperplane_intersection_loop_x_zero
			mov edi, dword[edx]
			mov dword[ebp-32], edi
		chunkManager4d_frustumCull_hyperplane_intersection_loop_x_zero:
		
		mov edi, dword[ecx+4]
		mov dword[ebp-28], edi
		test esi, 0b0010
		jz chunkManager4d_frustumCull_hyperplane_intersection_loop_y_zero
			mov edi, dword[edx+4]
			mov dword[ebp-28], edi
		chunkManager4d_frustumCull_hyperplane_intersection_loop_y_zero:
		
		mov edi, dword[ecx+8]
		mov dword[ebp-24], edi
		test esi, 0b0100
		jz chunkManager4d_frustumCull_hyperplane_intersection_loop_z_zero
			mov edi, dword[edx+8]
			mov dword[ebp-24], edi
		chunkManager4d_frustumCull_hyperplane_intersection_loop_z_zero:
		
		mov edi, dword[ecx+12]
		mov dword[ebp-20], edi
		test esi, 0b1000
		jz chunkManager4d_frustumCull_hyperplane_intersection_loop_w_zero
			mov edi, dword[edx+12]
			mov dword[ebp-20], edi
		chunkManager4d_frustumCull_hyperplane_intersection_loop_w_zero:
		
		;calculate the distance from the hyperplane
		push dword[ebp+20]
		lea eax, [ebp-32]
		push eax
		call vec4_dot
		add esp, 8
		fld dword[ebp+24]
		faddp
		fstp dword[ebp-44]
		mov eax, dword[ebp-44]
		and dword[ebp-36], eax
		xor eax, 0x80000000
		and dword[ebp-40], eax
	
		inc esi
		cmp esi, 16			;there are 16 vertices in a hyperbox
		jl chunkManager4d_frustumCull_hyperplane_intersection_loop_start
		
	;is the chunk on only one side of the hyperplane? (at least one helper's MSB is one)
	mov eax, dword[ebp-36]
	or eax, dword[ebp-40]
	test eax, 0x80000000
	jz chunkManager4d_frustumCull_not_outside_of_plane
		mov dword[ebp-4], 69
		jmp chunkManager4d_frustumCull_end
		
	chunkManager4d_frustumCull_not_outside_of_plane:
	
	;calculate the 3d projection of the bounds
	lea eax, [ebp-60]
	push eax
	push dword[ebp-12]
	push dword[ebp+32]
	call hyperPlane_positionTo3d
	lea eax, [ebp-76]
	push eax
	push dword[ebp-16]
	push dword[ebp+32]
	call hyperPlane_positionTo3d
	add esp, 24
	
	
	;3d frustum culling
	mov dword[ebp-80], 0b111111		;init cull mask
	
	xor esi, esi				;index in esi
	chunkManager4d_frustumCull_3d_loop_start:
		;obtain the current bounding box vertex
		mov eax, dword[ebp-60]
		test esi, 0b001
		jz chunkManager4d_frustumCull_3d_loop_not_upper_x
			mov eax, dword[ebp-76]
		chunkManager4d_frustumCull_3d_loop_not_upper_x:
		mov dword[ebp-96], eax
		
		mov eax, dword[ebp-56]
		test esi, 0b010
		jz chunkManager4d_frustumCull_3d_loop_not_upper_y
			mov eax, dword[ebp-72]
		chunkManager4d_frustumCull_3d_loop_not_upper_y:
		mov dword[ebp-92], eax
		
		mov eax, dword[ebp-52]
		test esi, 0b100
		jz chunkManager4d_frustumCull_3d_loop_not_upper_z
			mov eax, dword[ebp-68]
		chunkManager4d_frustumCull_3d_loop_not_upper_z:
		mov dword[ebp-88], eax
		
		mov eax, dword[ONE]
		mov dword[ebp-84], eax
		
		;multiply it with pv and do perspective division
		lea eax, [ebp-96]
		push dword[ebp+28]
		push eax
		call vec4_mulWithMat
		add esp, 8
		
		movups xmm0, [ebp-96]
		movss xmm1, dword[ebp-84]
		shufps xmm1, xmm1, 0b00000000
		divps xmm0, xmm1
		movups [ebp-96], xmm0
		
		;do frustum culling
		movss xmm0, dword[ebp-96]
		ucomiss xmm0, dword[ONE]
		ja chunkManager4d_frustumCull_3d_x_plus_1
			and dword[ebp-80], 0b111110
		chunkManager4d_frustumCull_3d_x_plus_1:
		
		ucomiss xmm0, dword[MINUS_ONE]
		jb chunkManager4d_frustumCull_3d_x_minus_1
			and dword[ebp-80], 0b111101
		chunkManager4d_frustumCull_3d_x_minus_1:
		
		
		movss xmm0, dword[ebp-92]
		ucomiss xmm0, dword[ONE]
		ja chunkManager4d_frustumCull_3d_y_plus_1
			and dword[ebp-80], 0b111011
		chunkManager4d_frustumCull_3d_y_plus_1:
		
		ucomiss xmm0, dword[MINUS_ONE]
		jb chunkManager4d_frustumCull_3d_y_minus_1
			and dword[ebp-80], 0b110111
		chunkManager4d_frustumCull_3d_y_minus_1:
		
		
		movss xmm0, dword[ebp-88]
		ucomiss xmm0, dword[ONE]
		ja chunkManager4d_frustumCull_3d_z_plus_1
			and dword[ebp-80], 0b101111
		chunkManager4d_frustumCull_3d_z_plus_1:
		
		ucomiss xmm0, dword[MINUS_ONE]
		jb chunkManager4d_frustumCull_3d_z_minus_1
			and dword[ebp-80], 0b011111
		chunkManager4d_frustumCull_3d_z_minus_1:
	
		inc esi
		cmp esi, 8				;the bounding box has 8 vertices
		jl chunkManager4d_frustumCull_3d_loop_start
	
	;check if the chunk is outside the frustum
	test dword[ebp-80], 0b111111
	jz chunkManager4d_frustumCull_end
	
	mov dword[ebp-4], 69
	
	chunkManager4d_frustumCull_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
;it is a compare function for vector_search
;data is the address of a memory region in which the chunkX, chunkZ and chunkW int-triplet is stored
;Chunk4D** because the comparator for vector_search expects an element* and a void* and the element is Chunk4D*
;returns 0 if there is a match
;int chunkManager4d_loaded_chunks_search(Chunk4D** chunk, void* data)
chunkManager4d_loaded_chunks_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	
	mov dword[ebp-4], 69
	
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	mov ecx, dword[ebp+12]
	
	mov edx, dword[eax]
	cmp edx, dword[ecx]
	jne chunkManager4d_loaded_chunk_search_end
	
	mov edx, dword[eax+4]
	cmp edx, dword[ecx+4]
	jne chunkManager4d_loaded_chunk_search_end
	
	mov edx, dword[eax+8]
	cmp edx, dword[ecx+8]
	jne chunkManager4d_loaded_chunk_search_end
	
	mov dword[ebp-4], 0
	
	chunkManager4d_loaded_chunk_search_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
;it is a compare function for tsQueue_search
;data is the address of a memory region in which the chunkX, chunkZ and chunkW int-triplet is stored
;returns 0 if there is a match
;int chunkManager4d_pending_graphics_updates_search(ChunkGraphicsUpdate4D** cgu, void* data)
chunkManager4d_pending_graphics_updates_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	mov dword[ebp-4], 69
	
	;check if it is a load update (unload is irrelevant)
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	cmp dword[eax+4], 0
	je chunkManager4d_pending_graphics_updates_search_end
	
		;it is a load update
		mov eax, dword[eax]
		mov ecx, dword[ebp+12]
		
		mov edx, dword[ecx]
		cmp edx, dword[eax]
		jne chunkManager4d_pending_graphics_updates_search_end
		mov edx, dword[ecx+4]
		cmp edx, dword[eax+4]
		jne chunkManager4d_pending_graphics_updates_search_end
		mov edx, dword[ecx+8]
		cmp edx, dword[eax+8]
		jne chunkManager4d_pending_graphics_updates_search_end
		
		mov dword[ebp-4], 0
	
	chunkManager4d_pending_graphics_updates_search_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	

;it is a compare function for qsort
;int chunkManager4d_unload_comparator(const struct{int; Chunk4D*}* a, const struct{int; Chunk4D*}* b)	
chunkManager4d_unload_comparator:
	mov ecx, dword[esp+4]
	mov edx, dword[esp+8]
	mov eax, dword[ecx]
	sub eax, dword[edx]
	ret
	
;it is a compare function for vector_search
;int chunkManager4d_registered_chunk_comparator(const ivec3* a, const ivec3* searchKey)
chunkManager4d_registered_chunk_comparator:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;return value			4
	
	mov dword[ebp-4], 69
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	
	mov edx, dword[eax]
	cmp edx, dword[ecx]
	jne chunkManager4d_registered_chunk_comparator_end 
	
	mov edx, dword[eax+4]
	cmp edx, dword[ecx+4]
	jne chunkManager4d_registered_chunk_comparator_end 
	
	mov edx, dword[eax+8]
	cmp edx, dword[ecx+8]
	jne chunkManager4d_registered_chunk_comparator_end 
	
	mov dword[ebp-4], 0
	
	chunkManager4d_registered_chunk_comparator_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret

;void chunkManager4d_processChangedBlockInternal(
;	ChunkManager4D* cm,
;	ivec3* key,
;	ChangedBlockInfo* value
;)
chunkManager4d_processChangedBlock_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 16			;vector buffer (if necessary)	16
	sub esp, 4			;chunk block vector	addr		20
	
	
	;obtain chunk vector
	chunkManager4d_processChangedBlock_internal_register_chunk:
	push 12
	push dword[ebp+12]
	mov eax, dword[ebp+8]
	push dword[eax+96]
	call hashMap_get
	mov dword[ebp-20], eax
	add esp, 12
	
	;register chunk in hashmap if necessary
	test eax, eax
	jnz chunkManager4d_processChangedBlock_internal_chunk_already_registered
		lea eax, [ebp-16]
		push 32
		push eax
		call vector_init
		
		push 16
		push 12
		lea eax, [ebp-16]
		push eax
		push dword[ebp+12]
		mov edx, dword[ebp+8]
		push dword[edx+96]
		call hashMap_add
		
		add esp, 28
		jmp chunkManager4d_processChangedBlock_internal_register_chunk		;infinite loop danger
		
	chunkManager4d_processChangedBlock_internal_chunk_already_registered:
	
	
	;register block into the hashmap
	push dword[ebp+16]
	push dword[ebp-20]
	call vector_push_back_buffer
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
;it is a compare function for vector_search
;int chunkManager4d_registered_chunk_comparator(const ivec3* a, const ivec3* searchKey)
chunkManager4d_changed_block_chunk_comparator:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;return value			4
	
	mov dword[ebp-4], 69
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	
	mov edx, dword[eax]
	cmp edx, dword[ecx]
	jne chunkManager4d_changed_block_chunk_comparator_end 
	
	mov edx, dword[eax+4]
	cmp edx, dword[ecx+4]
	jne chunkManager4d_changed_block_chunk_comparator_end 
	
	mov edx, dword[eax+8]
	cmp edx, dword[ecx+8]
	jne chunkManager4d_changed_block_chunk_comparator_end 
	
	mov dword[ebp-4], 0
	
	chunkManager4d_changed_block_chunk_comparator_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
;returns non-zero, if ja
;int chunkManager4d_isChunkLoaded_internal(ChunkManager4D* cm, int chunkX, int chunkZ, int chunkW)
chunkManager4d_isChunkLoaded_internal:
	push ebp
	push ebx
	mov ebp, esp
	
	sub esp, 4			;return value		4
	
	mov dword[ebp-4], eax
	
	mov edx, dword[ebp+12]
	mov eax, dword[edx]		;index in eax
	mov ecx, dword[edx+12]	;current chunk* in ecx
	cmp eax, 0
	jle chunkManager4d_isChunkLoaded_internal_end
	chunkManager4d_isChunkLoaded_internal_loop_start:
		mov ebx, dword[ecx]			;chunk* in ebx
	
		mov edx, dword[ebx]
		cmp edx, dword[ebp+16]
		jne chunkManager4d_isChunkLoaded_internal_loop_continue
		
		mov edx, dword[ebx+4]
		cmp edx, dword[ebp+20]
		jne chunkManager4d_isChunkLoaded_internal_loop_continue
		
		mov edx, dword[ebx+8]
		cmp edx, dword[ebp+24]
		jne chunkManager4d_isChunkLoaded_internal_loop_continue
		
		test dword[ebx+60], 0xffffffff
		jz chunkManager4d_isChunkLoaded_internal_end			  	;the chunk is loaded but not yet registered in a graphics update
		
		mov dword[ebp-4], 69
		jmp chunkManager4d_isChunkLoaded_internal_end
	
		chunkManager4d_isChunkLoaded_internal_loop_continue:
		add ecx, 4
		dec eax
		test eax, eax
		jnz chunkManager4d_isChunkLoaded_internal_loop_start
	
	chunkManager4d_isChunkLoaded_internal_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebx
	pop ebp
	ret