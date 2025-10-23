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
;	HyperPlane renderHyperPlane;							100
;	vec5 renderHyperPlaneEquation;							164		//(A,B,C,D) normal and E
;	HyperPlane* hyperPlaneBuffer;							184		//NULL or not yet applied hyperplane
;	Mutex* hyperPlaneBufferMutex;							188
;	padding of 8 bytes
;	GLuint shader;											200
;	TextureArrayInfo* blockTextures;						204
;}	208 bytes

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
	
	test_text db "you're so portuguese",10,0
	test_text2 db "you're so portuguese2",10,0
	test_text3 db "you're so portuguese3",10,0
	
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_four_ints_nl db "%d %d %d %d",10,0
	print_five_ints_nl db "%d %d %d %d %d",10,0
	print_six_ints_nl db "%d %d %d %d %d %d",10,0
	print_float_nl db "%f",10,0
	print_four_floats_nl db "%f %f %f %f",10,0
	
	ONE dd 1.0
	
section .data use32
	cull_count dd 0

section .text use32
	;should be called from the graphics thread
	global chunkManager4d_create					;ChunkManager4D* chunkManager4d_create()
	
	global chunkManager4d_load						;void chunkManager4d_load(ChunkManager4D* manager, vec3* playerPos3D, int renderDistance)
	global chunkManager4d_unload					;void chunkManager4d_unload(ChunkManager4D* manager, vec3* playerPos3D, int renderDistance)
	;returns the number of reloaded chunks
	;int chunkManager4d_processPendingChunkReloads(ChunkManager4D* cm, int maxReloads)
	global chunkManager4d_processPendingChunkReloads
	
	global chunkManager4d_render					;void chunkManager4d_render(ChunkManager4D* manager, mat4* view, mat4* projection)
	
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
	
	global chunkManager4d_processChangedBlocks	;void chunkManager4d_processChangedBlocks(ChunkManager4D* cm)
	
	global chunkManager4d_getHyperPlane			;HyperPlane* chunkManager4d_getHyperPlane(ChunkManager4D* cm)
	global chunkManager4d_setHyperPlane			;void chunkManager4d_setHyperPlane(ChunkManager4D* cm, HyperPlane* ph)
	
	global chunkManager4d_getPlayerChunk4D			;void chunkManager4d_getPlayerChunk4D(ChunkManager4D* cm, vec3* playerPos3D, int* chunkX, int* chunkZ, int* chunkW)
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy
	extern my_qsort
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_push_back_buffer
	extern vector_search
	extern vector_clear
	extern vector_at
	extern tsVector_init
	extern tsVector_pushBack
	extern tsVector_remove
	extern tsVector_removeCustom
	extern tsVector_at
	extern tsVector_search
	extern tsVector_forEach
	extern tsVector_size
	extern tsVector_lock
	extern tsVector_unlock
	
	extern queue_init
	extern queue_pushBuffer
	extern queue_pop
	extern queue_isEmpty
	extern queue_search
	extern tsQueue_init
	extern tsQueue_push
	extern tsQueue_pushFront
	extern tsQueue_pushBuffer
	extern tsQueue_pushArray
	extern tsQueue_pop
	extern tsQueue_search
	extern tsQueue_forEach
	extern tsVector_lock
	extern tsVector_unlock
	extern tsVector_vector
	
	extern hashMap_init
	extern hashMap_destroy
	extern hashMap_get
	extern hashMap_add
	
	extern mutex_create
	extern mutex_destroy
	extern mutex_lock
	extern mutex_unlock
	
	extern vec3_normalize
	extern vec4_dot
	extern vec4_add
	extern vec4_scale
	extern vec4_mulWithMat
	extern mat4_mul
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_createShader
	extern renderable_useShader
	extern renderable_calculateNormalMatrix
	extern renderable_setPrimitive
	extern renderable_setUniform
	extern RENDERABLE_UNIFORM_VEC3
	extern RENDERABLE_UNIFORM_VEC4
	extern RENDERABLE_UNIFORM_MAT3
	extern RENDERABLE_UNIFORM_MAT4
	extern textureHandler_bindArray
	extern GL_POINTS
	
	extern hyperPlane_create
	extern hyperPlane_getNormal
	extern hyperPlane_directionTo3d
	extern hyperPlane_positionTo3d
	extern hyperPlane_positionTo4d
	extern hyperPlane_signedDistance
	extern hyperPlane_intersectWithLineSegment
	
	extern chunk4d_generate
	extern chunk4d_destroy
	extern chunk4d_isProcessed
	extern chunk4d_setProcessed
	extern CHUNK_WIDTH
	extern block_importTextures
	
	extern sun_getDirection
	
chunkManager4d_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;chunk manager		4
	sub esp, 64			;temp hyperplane	68
	
	
	;alloc chunk manager
	push 208
	call my_malloc
	mov dword[ebp-4], eax
	
	;init loaded chunks vector
	mov ecx, dword[ebp-4]
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
	call tsVector_init
	
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
	
	;init hyperplane and hyperplane mutex
	mov eax, dword[ebp-4]
	mov dword[eax+184], 0
	
	call mutex_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+188], eax		;mutex needs to be created before the setHyperPlane call
	
	lea eax, [ebp-68]
	push eax
	call hyperPlane_create
	push dword[ebp-4]
	call chunkManager4d_setHyperPlane
	call chunkManager4d_applyHyperPlane_internal
	
	;create shader
	push geometry_shader_path
	push fragment_shader_path
	push vertex_shader_path
	call renderable_createShader
	mov ecx, dword[ebp-4]
	mov dword[ecx+200], eax
	
	;import textures
	call block_importTextures
	mov ecx, dword[ebp-4]
	mov dword[ecx+204], eax
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_render:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 24					;unused							24
	sub esp, 16					;sun direction 4d and then 3d	40
	sub esp, 64					;pv	matrix						104
	sub esp, 36					;normal matrix					140
	sub esp, 8					;foreach param					148
	
	;refresh hyperplane if necessary
	push dword[ebp+20]
	call chunkManager4d_applyHyperPlane_internal
	
	;calculate the pv matrix
	mov eax, dword[ebp+24]			;view
	mov ecx, dword[ebp+28]			;projection
	lea edx, [ebp-104]
	push eax
	push ecx
	push edx
	call mat4_mul
	add esp, 12
	
	;calculate the normal matrix
	;NOTE: the model matrix is not necessary for there is only translation in the case of chomks
	push dword[ebp+24]
	lea eax, [ebp-140]
	push eax
	call renderable_calculateNormalMatrix
	add esp, 8
	
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
	mov eax, dword[ebp+20]
	push dword[eax+204]
	call textureHandler_bindArray
	add esp, 8
	
	;use shader
	mov eax, dword[ebp+20]
	push dword[eax+200]
	call renderable_useShader
	add esp, 4
	
	;set sun direction uniform
	push dword[ebp-32]
	push dword[ebp-36]
	push dword[ebp-40]
	push dword[RENDERABLE_UNIFORM_VEC3]
	push uniform_name_sunDirection
	mov eax, dword[ebp+20]
	push dword[eax+200]
	call renderable_setUniform
	add esp, 24
	
	;set hyperplane pos uniform
	mov eax, dword[ebp+20]
	push dword[eax+112]
	push dword[eax+108]
	push dword[eax+104]
	push dword[eax+100]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlanePos
	push dword[eax+200]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane dir1 uniform
	mov eax, dword[ebp+20]
	push dword[eax+128]
	push dword[eax+124]
	push dword[eax+120]
	push dword[eax+116]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlaneDir1
	push dword[eax+200]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane dir2 uniform
	mov eax, dword[ebp+20]
	push dword[eax+144]
	push dword[eax+140]
	push dword[eax+136]
	push dword[eax+132]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlaneDir2
	push dword[eax+200]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane dir3 uniform
	mov eax, dword[ebp+20]
	push dword[eax+160]
	push dword[eax+156]
	push dword[eax+152]
	push dword[eax+148]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlaneDir3
	push dword[eax+200]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane normal uniform
	mov eax, dword[ebp+20]
	push dword[eax+176]
	push dword[eax+172]
	push dword[eax+168]
	push dword[eax+164]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_name_hyperPlaneNormal
	push dword[eax+200]
	call renderable_setUniform
	add esp, 28
	
	;set view matrix uniform
	push dword[ebp+24]
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_view_mat
	mov ecx, dword[ebp+20]
	push dword[ecx+200]
	call renderable_setUniform
	add esp, 16
	
	;set normal matrix uniform
	lea eax, [ebp-140]
	push eax
	push dword[RENDERABLE_UNIFORM_MAT3]
	push uniform_name_normal_mat
	mov ecx, dword[ebp+20]
	push dword[ecx+200]
	call renderable_setUniform
	add esp, 16
	
	;set render foreach param
	mov eax, dword[ebp+20]
	lea ecx, [ebp-104]			;pv
	mov dword[ebp-148], eax
	mov dword[ebp-144], ecx
	
	mov dword[cull_count], 0
	;render loaded chunks
	mov eax, dword[ebp+20]
	lea ecx, [ebp-148]
	push ecx
	push chunkManager4d_render_render_loaded_function
	push eax
	call tsVector_forEach
	
	push dword[cull_count]
	push print_int_nl
	;call my_printf
	add esp, 8
	
	;render fantom chunks
	mov eax, dword[ebp+20]
	add eax, 28
	lea ecx, [ebp-148]
	push ecx
	push chunkManager4d_render_render_fantom_function
	push eax
	call tsVector_forEach
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	;void chunkManager4d_render_render_loaded_function(Chunk4D**, struct{ChunkManager4D*, mat4* pv}*)
	chunkManager4d_render_render_loaded_function:
		push ebp
		mov ebp, esp
		
		sub esp, 4			;chunk			4
		sub esp, 4			;chunk manager	8
		sub esp, 4			;pv				12
		sub esp, 20			;hyperplane eq	32
		
		mov eax, dword[ebp+8]
		mov eax, dword[eax]
		mov dword[ebp-4], eax
		
		mov ecx, dword[ebp+12]
		mov edx, dword[ecx]
		mov dword[ebp-8], edx
		mov edx, dword[ecx+4]
		mov dword[ebp-12], edx
		
		;check if the chunk is ready
		push dword[ebp-4]
		call chunk4d_isProcessed
		test eax, eax
		jz chunkManager4d_render_render_loaded_function_end
		
		;check if there is a renderable for the current chunk
		mov eax, dword[ebp-4]
		cmp dword[eax+12], 0
		je chunkManager4d_render_render_loaded_function_end
		
		;check for frustum cull
		mov eax, dword[ebp-8]
		lea ecx, [eax+100]			;hp
		lea edx, [eax+164]			;hpe
		push ecx
		push dword[ebp-12]
		push edx
		push dword[ebp-4]
		call chunkManager4d_frustumCull
		test eax, eax
		;jnz chunkManager4d_render_render_loaded_function_end
		jz no_cull
			inc dword[cull_count]
			jmp chunkManager4d_render_render_loaded_function_end
		no_cull:
		
		;set chunkPos uniform
		mov eax, dword[ebp-4]
		
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
		mov eax, dword[ebp-8]
		push dword[eax+200]
		call renderable_setUniform
		add esp, 28
		
		;render chunk
		mov eax, dword[ebp-4]
		push 69					;use textures
		mov ecx, dword[ebp-8]
		push dword[ecx+200]		;shader
		push dword[ebp-12]			;pv
		push dword[eax+12]
		call renderable_renderCustom
		add esp, 16
		
		chunkManager4d_render_render_loaded_function_end:
		mov esp, ebp
		pop ebp
		ret
	
	;render fantom chunks
	;void chunkManager4d_render_render_loaded_function(FantomChunk*, struct{ChunkManager4D*, mat4* pv}*)
	chunkManager4d_render_render_fantom_function:
		push ebp
		mov ebp, esp
		
		sub esp, 4			;unused			4
		sub esp, 4			;chunk manager	8
		sub esp, 4			;pv				12
		
		mov ecx, dword[ebp+12]
		mov edx, dword[ecx]
		mov dword[ebp-8], edx
		mov edx, dword[ecx+4]
		mov dword[ebp-12], edx
		
		;set chunkPos uniform
		mov eax, dword[ebp+8]
		
		mov ecx, dword[eax+12]
		imul ecx, dword[CHUNK_WIDTH]
		push ecx
		fild dword[esp]
		fstp dword[esp]
		
		mov ecx, dword[eax+8]
		imul ecx, dword[CHUNK_WIDTH]
		push ecx
		fild dword[esp]
		fstp dword[esp]
		
		push 0
		
		mov ecx, dword[eax+4]
		imul ecx, dword[CHUNK_WIDTH]
		push ecx
		fild dword[esp]
		fstp dword[esp]
		
		
		push dword[RENDERABLE_UNIFORM_VEC4]
		push uniform_name_chunkPos
		mov eax, dword[ebp-8]
		push dword[eax+200]
		call renderable_setUniform
		add esp, 28
		
		;render chunk
		mov eax, dword[ebp+8]
		push 69					;use textures
		mov ecx, dword[ebp-8]
		push dword[ecx+200]		;shader
		push dword[ebp-12]		;pv
		push dword[eax]
		call renderable_renderCustom
		add esp, 16
		
		mov esp, ebp
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
					
					push dword[ebp-32]
					push dword[ebp-36]
					push dword[ebp-40]
					push dword[ebp+20]
					call chunkManager4d_getLoadedChunk
					add esp, 16
					test eax, eax
					jnz chunkManager4d_load_w_loop_continue
					
					
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
	test dword[ebp-28], 0xffffffff
	jz chunkManager4d_load_end
	
		;generate chunk
		push dword[ebp-24]			;chunkw
		push dword[ebp-20]			;chunkz
		push dword[ebp-16]			;chunkx
		push dword[ebp+20]
		call chunkManager4d_loadChunk_internal
		add esp, 16
	
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
	
	;search for an unloadable chunk
	push ebp
	push chunkManager4d_unload_remove_comparator
	push dword[ebp+20]
	call tsVector_removeCustom
	
	test dword[ebp-16], 0xffffffff
	jz chunkManager4d_unload_end
		;unload the chunk
		push 0				;destroy renderable
		push dword[ebp-16]
		push dword[ebp+20]
		call chunkManager4d_unloadChunk_internal
	
	chunkManager4d_unload_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	;int chunkManager4d_unload_remove_comparator(Chunk4D**, void* ebpOfUnload)
	chunkManager4d_unload_remove_comparator:
		push ebp
		push ebx
		mov ebp, esp
		
		sub esp, 4		;return value		4
		mov dword[ebp-4], 69
		
		;check if the chunk is out of the render distance
		mov ebx, dword[ebp+12]
		mov ebx, dword[ebx]			;chunk in ebx
		mov ecx, dword[ebp+16]
		
		mov eax, dword[ebx]
		sub eax, dword[ecx-28]
		test eax, 0x80000000
		jz chunkManager4d_unload_remove_comparator_not_neg_x
			neg eax
		chunkManager4d_unload_remove_comparator_not_neg_x:
			cmp eax, dword[ecx+28]
			jg chunkManager4d_unload_remove_comparator_should_unload
		mov eax, dword[ebx+4]
		sub eax, dword[ecx-24]
		test eax, 0x80000000
		jz chunkManager4d_unload_remove_comparator_not_neg_z
			neg eax
		chunkManager4d_unload_remove_comparator_not_neg_z:
			cmp eax, dword[ecx+28]
			jg chunkManager4d_unload_remove_comparator_should_unload
		mov eax, dword[ebx+8]
		sub eax, dword[ecx-20]
		test eax, 0x80000000
		jz chunkManager4d_unload_remove_comparator_not_neg_w
			neg eax
		chunkManager4d_unload_remove_comparator_not_neg_w:
			cmp eax, dword[ecx+28]
			jg chunkManager4d_unload_remove_comparator_should_unload
		jmp chunkManager4d_unload_remove_comparator_end
		chunkManager4d_unload_remove_comparator_should_unload:
			;save the chunk
			mov dword[ebp-4], 0
			
			mov dword[ecx-16], ebx
			
			mov eax, dword[ebx]
			mov dword[ecx-12], eax
			mov eax, dword[ebx+4]
			mov dword[ecx-8], eax
			mov eax, dword[ebx+8]
			mov dword[ecx-4], eax
		chunkManager4d_unload_remove_comparator_end:
		mov eax, dword[ebp-4]
		
		mov esp, ebp
		pop ebx
		pop ebp
		ret
	
chunkManager4d_processPendingChunkReloads:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;reloaded chunk count		4
	sub esp, 12			;chunk to reload			16
	
	mov dword[ebp-4], 0
	
	chunkManager4d_processPendingChunkReloads_loop_start:
		;is maxReloadCount reached?
		mov eax, dword[ebp-4]
		cmp eax, dword[ebp+12]
		jge chunkManager4d_processPendingChunkReloads_loop_end
		
		;are there more pending reloads?
		mov eax, dword[ebp+8]
		add eax, 52
		lea ecx, [ebp-16]
		push ecx
		push eax
		call queue_pop
		add esp, 8
		test eax, eax
		jnz chunkManager4d_processPendingChunkReloads_loop_end
		
		push dword[ebp-8]
		push dword[ebp-12]
		push dword[ebp-16]
		push dword[ebp+8]
		call chunkManager4d_reloadChunkByPosition_internal
		add esp, 16
		
		inc dword[ebp-4]
		
		jmp chunkManager4d_processPendingChunkReloads_loop_start
		
	chunkManager4d_processPendingChunkReloads_loop_end:
	mov eax, dword[ebp-4]			;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_processGraphicsUpdate:
	push ebp
	mov ebp, esp
	
	sub esp, 12			;graphics update buffer			12
	sub esp, 4			;has processed updates			16
	sub esp, 16			;imitated vertex vector			32
	sub esp, 4			;created renderable				36
	
	mov dword[ebp-16], 0
	
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
		
		;set chunk as processed (no need for lock)
		push 69
		push dword[ebp-8]
		call chunk4d_setProcessed
		
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
		
		mov eax, edi
		sal eax, 4
		add eax, dword[ebp+36]
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
	
	
chunkManager4d_processChangedBlocks:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16			;popped blocks vector			16
	sub esp, 36			;pending changed block buffer	52
	sub esp, 4			;vector<ChangedBlock>*			56
	sub esp, 12			;ivec3 previousChunkPos			68
	sub esp, 16			;vector<ivec3> changedChunks	84

	;init vectors
	push 36
	lea eax, [ebp-16]
	push eax
	call vector_init
	
	push 12
	lea eax, [ebp-84]
	push eax
	call vector_init
	
	;pop blocks
	chunkManager4d_processChangedBlocks_pop_loop_start:
		mov eax, dword[ebp+20]
		add eax, 44
		lea ecx, [ebp-52]
		push ecx
		push eax
		call tsQueue_pop
		add esp, 8
		test eax, eax
		jnz chunkManager4d_processChangedBlocks_pop_loop_end
			lea eax, [ebp-52]
			lea ecx, [ebp-16]
			push eax
			push ecx
			call vector_push_back_buffer
			add esp, 8
			
			jmp chunkManager4d_processChangedBlocks_pop_loop_start
	
	chunkManager4d_processChangedBlocks_pop_loop_end:
	
	;check if there are blocks
	cmp dword[ebp-16], 0
	jle chunkManager4d_processChangedBlocks_end
		;duplicate blocks if they are on the edge of a chunk
		lea eax, [ebp-16]
		push eax
		call chunkManager4d_processChangedBlocks_addDuplicateHelper_internal
	
		;sort the blocks in chunk order
		push chunkManager4d_processChangedBlocks_qsort_comparator
		push 36
		push dword[ebp-16]
		push dword[ebp-4]
		call my_qsort
		
		jmp chunkManager4d_processChangedBlocks_qsort_comparator_skip
		
		;int chunkManager4d_processChangedBlocks_qsort_comparator(PendingChangedBlock*, PendingChangedBlock*)
		chunkManager4d_processChangedBlocks_qsort_comparator:
			mov ecx, dword[esp+4]
			mov edx, dword[esp+8]
			
			mov eax, dword[ecx+4]
			sub eax, dword[edx+4]
			jnz chunkManager4d_processChangedBlocks_qsort_comparator_end
			mov eax, dword[ecx+8]
			sub eax, dword[edx+8]
			jnz chunkManager4d_processChangedBlocks_qsort_comparator_end
			mov eax, dword[ecx+12]
			sub eax, dword[edx+12]
			chunkManager4d_processChangedBlocks_qsort_comparator_end:
			ret
		chunkManager4d_processChangedBlocks_qsort_comparator_skip:
		
		;add the changed blocks to the hashmap
		mov esi, dword[ebp-4]			;current block in esi
		mov edi, dword[ebp-16]			;index in edi
		chunkManager4d_processChangedBlocks_register_outer_loop_start:
			;set current chunk
			mov eax, dword[esi+4]
			mov dword[ebp-68], eax
			mov ecx, dword[esi+8]
			mov dword[ebp-64], ecx
			mov edx, dword[esi+12]
			mov dword[ebp-60], edx
			
			;get the changed block vector
			mov eax, dword[ebp+20]
			lea ecx, [ebp-68]
			push 12
			push ecx
			push dword[eax+8]
			call hashMap_get
			test eax, eax
			jnz chunkManager4d_processChangedBlocks_register_outer_loop_vector_exists
				;create an empty vector and add it to the hash map
				sub esp, 16
				mov eax, esp
				push 32
				push eax
				call vector_init
				add esp, 8
				
				mov eax, dword[ebp+20]
				mov ecx, esp
				lea edx, [ebp-68]
				push 16
				push 12
				push ecx
				push edx
				push dword[eax+8]
				call hashMap_add
				add esp, 36
				
				mov eax, dword[ebp+20]
				lea ecx, [ebp-68]
				push 12
				push ecx
				push dword[eax+8]
				call hashMap_get
			chunkManager4d_processChangedBlocks_register_outer_loop_vector_exists:
			mov dword[ebp-56], eax
			
			;add blocks
			mov ebx, dword[ebp-56]		;vector in ebx
			chunkManager4d_processChangedBlocks_register_inner_loop_start:
				push esi
				push ebx
				call vector_push_back_buffer
				add esp, 8
				
				;continue if there are more blocks and the next block is in this chunk as well
				add esi, 36
				dec edi
				jz chunkManager4d_processChangedBlocks_register_inner_loop_end
				mov eax, dword[esi+4]
				cmp eax, dword[ebp-68]
				jne chunkManager4d_processChangedBlocks_register_inner_loop_end
				mov eax, dword[esi+8]
				cmp eax, dword[ebp-64]
				jne chunkManager4d_processChangedBlocks_register_inner_loop_end
				mov eax, dword[esi+12]
				cmp eax, dword[ebp-60]
				jne chunkManager4d_processChangedBlocks_register_inner_loop_end
					jmp chunkManager4d_processChangedBlocks_register_inner_loop_start
			chunkManager4d_processChangedBlocks_register_inner_loop_end:
			
			;add the chunk to the changed chunks viktor
			lea eax, [esi-32]
			push eax				;chunk pos
			lea ecx, [ebp-84]
			push ecx
			call vector_push_back_buffer
			add esp, 8
	
			cmp edi, 0
			jg chunkManager4d_processChangedBlocks_register_outer_loop_start
			
	chunkManager4d_processChangedBlocks_end:
	
	;push reload updates for the changed chunks
	mov esi, dword[ebp-72]		;current chunk pos in esi
	mov edi, dword[ebp-84]		;index in edi
	cmp edi, 0
	jle	chunkManager4d_processChangedBlocks_reload_loop_end
	chunkManager4d_processChangedBlocks_reload_loop_start:
		push esi
		push dword[ebp+20]
		call chunkManager4d_registerChunkReloadUpdate_internal
		add esp, 8
	
		push dword[esi+8]
		push dword[esi+4]
		push dword[esi]
		push dword[ebp+20]
		;call chunkManager4d_reloadChunkByPosition_internal
		add esp, 16
		
		add esi, 12
		dec edi
		jnz chunkManager4d_processChangedBlocks_reload_loop_start
	chunkManager4d_processChangedBlocks_reload_loop_end:
	
	;delete the viktors
	lea eax, [ebp-16]
	push eax
	call vector_destroy
	
	lea eax, [ebp-84]
	push eax
	call vector_destroy
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
;stashes
chunkManager4d_setHyperPlane:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;hyperplane buffer		4
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax+188]
	call mutex_lock
	
	;get or create hyperplane buffer
	mov eax, dword[ebp+8]
	test dword[eax+184], 0xffffffff
	jnz chunkManager4d_setHyperPlane_buffer_exists
		push 64
		call my_malloc
		mov ecx, eax
		mov eax, dword[ebp+8]
		mov dword[eax+184], ecx
	
	chunkManager4d_setHyperPlane_buffer_exists:
	mov ecx, dword[eax+184]
	mov dword[ebp-4], ecx
	
	;copy hyperplane
	push 64
	push dword[ebp+12]
	push dword[ebp-4]
	call my_memcpy
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax+188]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret
	
	
;always returns the rendered hyperplane
;not thread-safe
chunkManager4d_getHyperPlane:
	mov eax, dword[esp+4]
	add eax, 100
	ret
	
	
chunkManager4d_getPlayerChunk:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;player pos 4d				16
	
	;calculate player pos 4d
	mov eax, dword[ebp+8]
	add eax, 100
	lea ecx, [ebp-16]
	push ecx
	push dword[ebp+12]
	push eax
	call hyperPlane_positionTo4d
	
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

;void chunkManager4d_registerChunkReloadUpdate_internal(ChunkManager4D*, ivec3* chunkPos)
chunkManager4d_registerChunkReloadUpdate_internal:
	push ebp
	mov ebp, esp
	
	;is the chunk already scheduled for reload?
	push dword[ebp+12]
	push chunkManager4d_registerChunkReloadUpdate_internal_search_comparator
	mov eax, dword[ebp+8]
	add eax, 52
	push eax
	call queue_search
	cmp eax, -1
	jne chunkManager4d_registerChunkReloadUpdate_internal_end
		;register update
		push dword[ebp+12]
		mov eax, dword[ebp+8]
		add eax, 52
		push eax
		call queue_pushBuffer
	
	chunkManager4d_registerChunkReloadUpdate_internal_end:
	mov esp, ebp
	pop ebp
	ret
	;int chunkManager4d_registerChunkReloadUpdate_internal_search_comparator(ivec3*, ivec3*)
	chunkManager4d_registerChunkReloadUpdate_internal_search_comparator:
		push ebp
		
		xor ebp, ebp
		mov eax, dword[esp+8]
		mov ecx, dword[esp+12]
		
		mov edx, dword[eax]
		sub edx, dword[ecx]
		mov ebp, edx
		mov edx, dword[eax+4]
		sub edx, dword[ecx+4]
		or ebp, edx
		mov edx, dword[eax+8]
		sub edx, dword[ecx+8]
		or ebp, edx
		
		mov eax, ebp
		pop ebp
		ret

;if there is a hyperplane in the hyperplane buffer, the render hyperplane gets overriden by it
;void chunkManager4d_applyHyperPlane_internal(ChunkManager4D*)
chunkManager4d_applyHyperPlane_internal:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax+188]
	call mutex_lock
	
	mov eax, dword[ebp+8]
	test dword[eax+184], 0xffffffff
	jz chunkManager4d_applyHyperPlane_internal_empty_buffer
		;copy the contents of the buffer
		lea ecx, [eax+100]
		push 64
		push dword[eax+184]
		push ecx
		call my_memcpy
		
		;delete the buffer
		mov eax, dword[ebp+8]
		push dword[eax+184]
		mov dword[eax+184], 0
		call my_free
		
		;calculate the hyperplane equation	
		mov eax, dword[ebp+8]
		lea ecx, [eax+100]
		lea edx, [eax+164]
		push edx
		push ecx
		call hyperPlane_getNormal		;calculate normal
		call vec4_dot					;calculate E
		mov eax, dword[ebp+8]
		fstp dword[eax+180]
		xor dword[eax+180], 0x80000000
	
	chunkManager4d_applyHyperPlane_internal_empty_buffer:
	
	;unlock mutex
	mov eax, dword[ebp+8]
	push dword[eax+188]
	call mutex_unlock
	
	mov esp, ebp
	pop ebp
	ret


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
	
	;get the changed blocks vector
	mov eax, dword[ebp+20]
	lea ecx, [ebp+24]
	push 12
	push ecx
	push dword[eax+8]
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
			mov ecx, eax
			sal ecx, 4
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
		;there is graphics data, push graphics update and put the chunk into the loaded chunks vector as unprocessed
		push 0
		push dword[ebp-4]
		call chunk4d_setProcessed
		
		push dword[ebp-4]
		push dword[ebp+20]
		call tsVector_pushBack
		
		push dword[ebp-4]
		push dword[ebp+20]
		call chunkManager4d_pushGraphicsLoadUpdate_internal
		
		jmp chunkManager4d_loadChunk_internal_graphics_update_done
	
	chunkManager4d_loadChunk_internal_graphics_update_no_update:
		;there is no graphics update, straight into the loaded chunks as processed
		push 69
		push dword[ebp-4]
		call chunk4d_setProcessed
		
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
	;int chunkManager4d_loadChunk_internal_veteran_comparator(ivec3* chunkPos, ivec3* searchKey)
	chunkManager4d_loadChunk_internal_veteran_comparator:
		push ebp
		mov ebp, esp
		sub esp, 4		;return value		4
		mov dword[ebp-4], 69
		
		mov eax, dword[ebp+8]
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
;returns 0 if there were no problems during the unload
;int chunkManager4d_unloadChunk_internal(
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
	
	sub esp, 4			;chunk renderable				4
	sub esp, 4			;removed from graphics queue	8
	sub esp, 4			;chunk (helper)					12
	sub esp, 4			;return value					16
	
	mov dword[ebp-8], 0
	mov eax, dword[ebp+24]
	mov dword[ebp-12], eax
	mov dword[ebp-16], 0
	
	;remove the chunk from the graphics update queue and the loaded chunks vector
	lea ecx, [ebp-12]
	push ecx
	push chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda
	mov eax, dword[ebp+20]
	add eax, 36
	push eax
	call tsQueue_forEach
	test dword[ebp-8], 0xffffffff
	jnz chunkManager4d_unloadChunk_internal_graphics_update_removed
		;if the chunk is not processed, but no graphics update is removed, that means that the chunk's graphics data is currently being loaded
		push dword[ebp+24]
		call chunk4d_isProcessed
		test eax, eax
		jnz chunkManager4d_unloadChunk_internal_graphics_update_removed
			;problem, abort unload
			mov dword[ebp-16], 69
			jmp chunkManager4d_unloadChunk_internal_end
	chunkManager4d_unloadChunk_internal_graphics_update_removed:
	
	push dword[ebp+24]
	push dword[ebp+20]
	call tsVector_remove
	
	;get the renderable
	mov eax, dword[ebp+24]
	mov ecx, dword[eax+12]
	mov dword[ebp-4], ecx
	mov dword[eax+12], 0
	
	;unload the chunk (also yeets the unprocessed graphics data if necessary)
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
			push dword[ebp+20]
			call chunkManager4d_pushGraphicsUnloadUpdate_internal
		
	chunkManager4d_unloadChunk_internal_renderable_done:
	
	chunkManager4d_unloadChunk_internal_end:
	mov eax, dword[ebp-16]		;set return vale
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	;void chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda(GraphicsUpdate*, struct{Chunk4D*, int removalTookPlace}*)
	chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda:
		mov eax, dword[esp+4]
		test dword[eax], 0xffffffff
		jz chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda_end	;not load update
		mov ecx, dword[esp+8]
		mov edx, dword[ecx]
		cmp edx, dword[eax+4]
		jne chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda_end
			mov dword[eax+4], 0		;update shall be ignored
			mov dword[ecx+4], 69		;removal happened
		chunkManager4d_unloadChunk_internal_remove_from_graphics_queue_lambda_end:
		ret

;removes a chunk from the loaded chunks vector (and from the graphics update queue if necessary)
;unloads the chunk (with keeping the renderable as a fantom)
;if the unload fails, the reload is aborted
;loads a new chunk in the same position
;void chunkManager4d_reloadChunkByPosition_internal(ChunkManager4D* cm, ivec3 chunkPos)
chunkManager4d_reloadChunkByPosition_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;chunk				4
	sub esp, 12			;unused
	sub esp, 4			;renderable buffer	20
	sub esp, 4			;debug helper		24
	
	mov dword[ebp-4], 0	
	mov dword[ebp-20], 0
	
	push dword[ebp+32]
	push dword[ebp+28]
	push dword[ebp+24]
	push dword[ebp+20]
	call chunkManager4d_getLoadedChunk
	mov dword[ebp-4], eax
	test eax, eax
	jz chunkManager4d_reloadChunkByPosition_internal_end
	
	;unload chunk
	lea eax, [ebp-20]
	push eax
	push dword[ebp-4]
	push dword[ebp+20]
	call chunkManager4d_unloadChunk_internal
	test eax, eax
	jnz chunkManager4d_reloadChunkByPosition_internal_end		;problems
	
	;create fantom update if necessary
	test dword[ebp-20], 0xffffffff
	jz chunkManager4d_reloadChunkByPosition_internal_no_fantom
		;push fantom chunk
		push dword[ebp+32]
		push dword[ebp+28]
		push dword[ebp+24]
		push dword[ebp-20]
		mov ecx, dword[ebp+20]
		add ecx, 28
		push ecx
		call tsVector_pushBack
	
		;create unload update
		push 69
		push dword[ebp-20]
		push dword[ebp+20]
		call chunkManager4d_pushGraphicsUnloadUpdate_internal
		
	chunkManager4d_reloadChunkByPosition_internal_no_fantom:
	
	;load chunk
	push dword[ebp+32]
	push dword[ebp+28]
	push dword[ebp+24]
	push dword[ebp+20]
	call chunkManager4d_loadChunk_internal
	
	
	chunkManager4d_reloadChunkByPosition_internal_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	

;returns the first (and hopefully only) occurence of the chunk with matching position in the loaded chunks vector
;returns NULL on gebasz
;Chunk4D* chunkManager4d_getLoadedChunk(ChunkManager4D* cm, ivec3 chunkPos)
chunkManager4d_getLoadedChunk:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;return value			4
	mov dword[ebp-4], 0
	
	;lock the viktor
	push dword[ebp+8]
	call tsVector_lock
	
	;check for the loaded chunks
	mov eax, dword[ebp+8]
	lea ecx, [ebp+12]
	push ecx
	push chunkManager4d_getLoadedChunk_loaded_chunks_comparator
	push eax
	call tsVector_search
	cmp eax, -1
	je chunkManager4d_getLoadedChunk_end
		;retrieve chunk
		push eax
		push dword[ebp+8]
		call tsVector_at
		mov eax, dword[eax]
		mov dword[ebp-4], eax
	
	chunkManager4d_getLoadedChunk_end:	
	
	;unlock the viktor
	push dword[ebp+8]
	call tsVector_unlock
	
	mov eax, dword[ebp-4]	;set return value
	
	mov esp, ebp
	pop ebp
	ret
	;int chunkManager4d_getLoadedChunk_loaded_chunks_comparator(Chunk4D** gu, ivec3* chunkPos)
	chunkManager4d_getLoadedChunk_loaded_chunks_comparator:
		push ebp
		mov ebp, esp
		
		sub esp, 4			;return value	4
		mov dword[ebp-4], 69
		
		mov eax, dword[ebp+8]
		mov eax, dword[eax]
		mov ecx, dword[ebp+12]
		
		mov edx, dword[eax]
		cmp edx, dword[ecx]
		jne chunkManager4d_getLoadedChunk_loaded_chunks_comparator_end
		mov edx, dword[eax+4]
		cmp edx, dword[ecx+4]
		jne chunkManager4d_getLoadedChunk_loaded_chunks_comparator_end
		mov edx, dword[eax+8]
		cmp edx, dword[ecx+8]
		jne chunkManager4d_getLoadedChunk_loaded_chunks_comparator_end
		
		mov dword[ebp-4], 0
		
		chunkManager4d_getLoadedChunk_loaded_chunks_comparator_end:
		mov eax, dword[ebp-4]
		
		mov esp, ebp
		pop ebp
		ret
		
;void chunkManager4d_pushGraphicsLoadUpdate_internal(ChunkManager4D* cm, Chunk4D* chunk)
chunkManager4d_pushGraphicsLoadUpdate_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 12		;update buffer		12
	
	mov dword[ebp-12], 69	;load update
	mov eax, dword[ebp+12]
	mov dword[ebp-8], eax	;data
	mov dword[ebp-4], 0
	
	lea ecx, dword[ebp-12]
	mov eax, dword[ebp+8]
	add eax, 36
	push ecx
	push eax
	call tsQueue_pushBuffer
	
	mov esp, ebp
	pop ebp
	ret
	
	
;void chunkManager4d_pushGraphicsUnloadUpdate_internal(ChunkManager4D* cm, Renderable* renderable, int isFantom)
chunkManager4d_pushGraphicsUnloadUpdate_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 12		;update buffer		12
	
	mov dword[ebp-12], 0	;unload update
	mov eax, dword[ebp+12]
	mov dword[ebp-8], eax	;renderable
	mov ecx, dword[ebp+16]
	mov dword[ebp-4], ecx	;isFantom
	
	lea ecx, dword[ebp-12]
	mov eax, dword[ebp+8]
	add eax, 36
	push ecx
	push eax
	call tsQueue_pushBuffer
	
	mov esp, ebp
	pop ebp
	ret
	
;if "changedBlocks" contains blocks on the edge of the chunk, they are duplicated so that the block is in the neighbouring chunk
;void chunkManager4d_processChangedBlocks_addDuplicateHelper_internal(vector<PendingChangedBlock>* changedBlocks)
chunkManager4d_processChangedBlocks_addDuplicateHelper_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16			;unused								16
	sub esp, 36			;pending changed block buffer		52
	
	mov eax, dword[ebp+20]
	mov ebx, dword[eax]			;index in ebx
	chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_start:
		;get current block
		lea eax, [ebx-1]
		push eax
		push dword[ebp+20]
		call vector_at
		mov esi, eax
		add esp, 8
		
		test dword[esi+16], 0xffffffff
		jnz chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_neg_x
			mov eax, dword[esi]
			mov dword[ebp-52], eax
			mov ecx, dword[esi+4]
			dec ecx
			mov dword[ebp-48], ecx
			mov edx, dword[esi+8]
			mov dword[ebp-44], edx
			mov eax, dword[esi+12]
			mov dword[ebp-40], eax
			mov dword[ebp-36], 16
			mov edx, dword[esi+20]
			mov dword[ebp-32], edx
			mov eax, dword[esi+24]
			mov dword[ebp-28], eax
			mov ecx, dword[esi+28]
			mov dword[ebp-24], ecx
			mov dword[ebp-20], 0		;not priority
			
			lea eax, [ebp-52]
			push eax
			push dword[ebp+20]
			call vector_push_back_buffer
			add esp, 8
		chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_neg_x:
		
		cmp dword[esi+16], 15
		jne chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_pos_x
			mov eax, dword[esi]
			mov dword[ebp-52], eax
			mov ecx, dword[esi+4]
			inc ecx
			mov dword[ebp-48], ecx
			mov edx, dword[esi+8]
			mov dword[ebp-44], edx
			mov eax, dword[esi+12]
			mov dword[ebp-40], eax
			mov dword[ebp-36], -1
			mov edx, dword[esi+20]
			mov dword[ebp-32], edx
			mov eax, dword[esi+24]
			mov dword[ebp-28], eax
			mov ecx, dword[esi+28]
			mov dword[ebp-24], ecx
			mov dword[ebp-20], 0		;not priority
			
			lea eax, [ebp-52]
			push eax
			push dword[ebp+20]
			call vector_push_back_buffer
			add esp, 8
		chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_pos_x:
		
		test dword[esi+24], 0xffffffff
		jnz chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_neg_z
			mov eax, dword[esi]
			mov dword[ebp-52], eax
			mov ecx, dword[esi+4]
			mov dword[ebp-48], ecx
			mov edx, dword[esi+8]
			dec edx
			mov dword[ebp-44], edx
			mov eax, dword[esi+12]
			mov dword[ebp-40], eax
			mov ecx, dword[esi+16]
			mov dword[ebp-36], ecx
			mov edx, dword[esi+20]
			mov dword[ebp-32], edx
			mov dword[ebp-28], 16
			mov ecx, dword[esi+28]
			mov dword[ebp-24], ecx
			mov dword[ebp-20], 0		;not priority
			
			lea eax, [ebp-52]
			push eax
			push dword[ebp+20]
			call vector_push_back_buffer
			add esp, 8
		chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_neg_z:
		
		cmp dword[esi+24], 15
		jne chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_pos_z
			mov eax, dword[esi]
			mov dword[ebp-52], eax
			mov ecx, dword[esi+4]
			mov dword[ebp-48], ecx
			mov edx, dword[esi+8]
			inc edx
			mov dword[ebp-44], edx
			mov eax, dword[esi+12]
			mov dword[ebp-40], eax
			mov ecx, dword[esi+16]
			mov dword[ebp-36], ecx
			mov edx, dword[esi+20]
			mov dword[ebp-32], edx
			mov dword[ebp-28], -1
			mov ecx, dword[esi+28]
			mov dword[ebp-24], ecx
			mov dword[ebp-20], 0		;not priority
			
			lea eax, [ebp-52]
			push eax
			push dword[ebp+20]
			call vector_push_back_buffer
			add esp, 8
		chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_pos_z:
		
		test dword[esi+28], 0xffffffff
		jnz chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_neg_w
			mov eax, dword[esi]
			mov dword[ebp-52], eax
			mov ecx, dword[esi+4]
			mov dword[ebp-48], ecx
			mov edx, dword[esi+8]
			mov dword[ebp-44], edx
			mov eax, dword[esi+12]
			dec eax
			mov dword[ebp-40], eax
			mov ecx, dword[esi+16]
			mov dword[ebp-36], ecx
			mov edx, dword[esi+20]
			mov dword[ebp-32], edx
			mov eax, dword[esi+24]
			mov dword[ebp-28], eax
			mov dword[ebp-24], 16
			mov dword[ebp-20], 0		;not priority
			
			lea eax, [ebp-52]
			push eax
			push dword[ebp+20]
			call vector_push_back_buffer
			add esp, 8
		chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_neg_w:
		
		cmp dword[esi+28], 15
		jne chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_pos_w
			mov eax, dword[esi]
			mov dword[ebp-52], eax
			mov ecx, dword[esi+4]
			mov dword[ebp-48], ecx
			mov edx, dword[esi+8]
			mov dword[ebp-44], edx
			mov eax, dword[esi+12]
			inc eax
			mov dword[ebp-40], eax
			mov ecx, dword[esi+16]
			mov dword[ebp-36], ecx
			mov edx, dword[esi+20]
			mov dword[ebp-32], edx
			mov eax, dword[esi+24]
			mov dword[ebp-28], eax
			mov dword[ebp-24], -1
			mov dword[ebp-20], 0		;not priority
			
			lea eax, [ebp-52]
			push eax
			push dword[ebp+20]
			call vector_push_back_buffer
			add esp, 8
		chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_not_pos_w:
		
		dec ebx
		test ebx, ebx
		jnz chunkManager4d_processChangedBlocks_addDuplicateHelper_internal_loop_start
		
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
;returns 0 if the chunk doesn't need to be culled
;int chunkManager4d_frustumCull(
;	Chunk4D* chunk,
;	HyperplaneEquation* equation,
;	mat4* pv,
;	HyperPlane* hp
;)
chunkManager4d_frustumCull:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4				;return value						4
	sub esp, 4				;chunk.colliderGroup				8
	sub esp, 4				;lower bound vector					12
	sub esp, 4				;upper bound vector					16
	sub esp, 16				;current bounding hyperbox vertex	32
	sub esp, 4				;all distances non-negative			36
	sub esp, 4				;all distances negative				40
	sub esp, 2				;are all values smaller than -1		42
	sub esp, 2				;are all values greater than 1		44
	sub esp, 16				;copied upper bound vector			60
	sub esp, 16				;copied lower bound vector			76
	sub esp, 16				;temp vector 2						92
	sub esp, 16				;temp vector 1						108
	sub esp, 16				;temp vector 3						124
	
	mov dword[ebp-4], 0
	
	mov dword[ebp-36], 0
	mov dword[ebp-40], 0x80000000
	
	;obtain collider group and bounds
	mov eax, dword[ebp+20]
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
	
	;check if the chunk's bounding box intersects with the hyperplane
	mov eax, dword[ebp-12]
	mov eax, dword[eax]
	mov dword[ebp-32], eax			;init current vertex x
	mov esi, 1						;x index in esi
	chunkManager4d_frustumCull_intersection_x_loop_start:
		push esi						;save x index
		mov eax, dword[ebp-12]
		mov eax, dword[eax+4]
		mov dword[ebp-28], eax			;init current vertex y
		mov esi, 1						;y index in esi
		chunkManager4d_frustumCull_intersection_y_loop_start:
			push esi						;save y index
			
			mov eax, dword[ebp-12]
			mov eax, dword[eax+8]
			mov dword[ebp-24], eax			;init current vertex z
			mov esi, 1						;z index in esi
			chunkManager4d_frustumCull_intersection_z_loop_start:
				push esi						;save z index
				
				mov eax, dword[ebp-12]
				mov eax, dword[eax+12]
				mov dword[ebp-20], eax			;init current vertex w
				mov esi, 1						;w index in esi
				chunkManager4d_frustumCull_intersection_w_loop_start:
					push esi						;save w index
					
					lea eax, [ebp-32]
					push eax
					push dword[ebp+24]
					call hyperPlane_signedDistance
					fstp dword[esp]
					mov eax, dword[esp]
					add esp, 8
					
					or dword[ebp-36], eax
					and dword[ebp-40], eax
					
					pop esi							;restore w index
					mov eax, dword[ebp-16]
					mov eax, dword[eax+12]
					mov dword[ebp-20], eax	 		;update current vertex w
					dec esi
					jz chunkManager4d_frustumCull_intersection_w_loop_start
				
				pop esi							;restore z index
				mov eax, dword[ebp-16]
				mov eax, dword[eax+8]
				mov dword[ebp-24], eax	 		;update current vertex z
				dec esi
				jz chunkManager4d_frustumCull_intersection_z_loop_start
			
			pop esi							;restore y index
			mov eax, dword[ebp-16]
			mov eax, dword[eax+4]
			mov dword[ebp-28], eax	 		;update current vertex y
			dec esi
			jz chunkManager4d_frustumCull_intersection_y_loop_start
		
		pop esi							;restore x index
		mov eax, dword[ebp-16]
		mov eax, dword[eax]
		mov dword[ebp-32], eax	 		;update current vertex x
		dec esi
		jz chunkManager4d_frustumCull_intersection_x_loop_start
		
	mov dword[ebp-4], 69
	test dword[ebp-36], 0x80000000
	jz chunkManager4d_frustumCull_end
	test dword[ebp-40], 0x80000000
	jnz chunkManager4d_frustumCull_end
	mov dword[ebp-4], 0
	
	;copy the bound vectors
	mov eax, dword[ebp-12]
	mov ecx, dword[ebp-16]
	movups xmm0, [eax]
	movups [ebp-76], xmm0
	movups xmm1, [ecx]
	movups [ebp-60], xmm1
	
	;check for the intersection points of the bounding box
	mov word[ebp-42], 0b111
	mov word[ebp-44], 0b000
	
	mov ebx, 16					;index in ebx
	mov esi, chunkManager4d_frustumCull_edges
	chunkManager4d_frustumCull_fr_loop_start:
		;calculate the edge points
		lea eax, [ebp-76]
		lea ecx, [ebp-108]
		%rep 8
		mov edx, dword[esi]
		mov edx, dword[eax+edx]
		mov dword[ecx], edx
		
		add ecx, 4
		add esi, 4
		%endrep
		
		;check if there is an intersection with the plane
		lea eax, [ebp-124]
		push eax
		lea ecx, [ebp-92]
		push ecx
		lea edx, [ebp-108]
		push ecx
		push dword[ebp+24]
		call hyperPlane_intersectWithLineSegment
		add esp, 16
		test eax, eax
		jz chunkManager4d_frustumCull_fr_loop_continue
		
		;project the intersection point
		lea eax, [ebp-124]
		push eax
		push eax
		push dword[ebp+32]
		call hyperPlane_positionTo3d
		add esp, 12
		
		;calculate the projection space intersection point
		mov ecx, dword[ONE]
		mov dword[ebp-112], ecx
		
		push dword[ebp+28]
		lea eax, [ebp-124]
		push eax
		call vec4_mulWithMat
		add esp, 8
		
		;make it so that projection.w := |projection.w|
		mov eax, dword[ebp-112]
		and eax, 0x80000000
		xor dword[ebp-124], eax
		xor dword[ebp-120], eax
		xor dword[ebp-116], eax
		xor dword[ebp-112], eax
		
		;check if the values are less than -|projection.w| or greater than |projection.w|
		;aka outside of the frustum
		vbroadcastss xmm0, dword[ebp-112]
		movups xmm1, [ebp-124]
		movaps xmm2, xmm1
		subps xmm2, xmm0
		movups [ebp-92], xmm2			;negative if not greater than |projection.w|
		addps xmm1, xmm0
		movups [ebp-108], xmm1			;negative if less than -|projection.w|
		
		mov al, byte[ebp-105]
		not al
		rol al, 1
		and al, 0b00000001		;if not less than -|projection.w| then non-zero
		not al
		and byte[ebp-42], al
		
		mov cl, byte[ebp-101]
		not cl
		rol cl, 2
		and cl, 0b00000010		;if not less than -|projection.w| then non-zero
		not cl
		and byte[ebp-42], cl
		
		mov dl, byte[ebp-97]
		not dl
		rol dl, 3
		and dl, 0b00000100		;if not less than -|projection.w| then non-zero
		not dl
		and byte[ebp-42], dl
		
		mov al, byte[ebp-89]
		rol al, 1
		and al, 0b00000001
		or byte[ebp-44], al
		
		mov cl, byte[ebp-85]
		rol cl, 2
		and cl, 0b00000010
		or byte[ebp-44], cl
		
		mov dl, byte[ebp-81]
		rol dl, 3
		and dl, 0b00000100
		or byte[ebp-44], dl
		
		chunkManager4d_frustumCull_fr_loop_continue:
		dec ebx
		jnz chunkManager4d_frustumCull_fr_loop_start
		
	;check if the chunk should be culled
	mov dword[ebp-4], 69
	
	mov ax, word[ebp-42]
	and ax, 0b111
	test ax, ax
	jnz chunkManager4d_frustumCull_end
	mov cx, word[ebp-44]
	and cx, 0b111
	cmp cx, 0b111
	;jne chunkManager4d_frustumCull_end
	
	mov dword[ebp-4], 0
		
	chunkManager4d_frustumCull_end:
	mov eax, dword[ebp-4]			;set return value
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	chunkManager4d_frustumCull_edges:
		dd 0,4,8,12,	0,4,8,28
		dd 0,4,8,12,	0,4,24,12
		dd 0,4,8,12,	0,20,8,12
		dd 0,4,8,12,	16,4,8,12
		dd 0,4,8,28,	0,4,24,28
		dd 0,4,8,28,	0,20,8,28
		dd 0,4,8,28,	16,4,8,28
		dd 0,4,24,12,	0,20,24,12
		dd 0,4,24,12,	16,4,24,12
		dd 0,4,24,28,	0,20,24,28
		dd 0,4,24,28,	16,4,24,28
		dd 0,20,8,12,	0,20,8,28
		dd 0,20,8,12,	16,20,8,12
		dd 0,20,8,28,	16,20,8,28
		dd 0,20,24,12,	16,20,24,12
		dd 0,20,24,28,	16,20,24,28