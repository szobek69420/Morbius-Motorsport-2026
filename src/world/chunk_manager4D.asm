[BITS 32]

;layout:
;struct ChunkManager4D{
;	vector<Chunk4D*> loadedChunks;								0
;	tsQueue<ChunkUpdate4D*> pendingUpdates;						16
;	tsQueue<ChunkGraphicsUpdate4D*> pendingGraphicsUpdates;		24
;	HyperPlane hyperPlane;										32
;	Mutex* loadedChunksMutex;									96
;	GLuint shader;												100
;}		104 bytes overall

;layout:
;struct ChunkUpdate4D{
;	int load;					0
;	Chunk4D* chunk;				4, used only if it is an unload update
;	int chunkX, chunkZ, chunkW	8, used only if it is a load update
;}		20 bytes overall

;layout:
;struct ChunkGraphicsUpdate4D{
;	void* data					0, it is Chunk4D* if load update, otherwise a renderable*
;	int load;					4
;}		8 bytes overall


;process of loading a chunk:
;
;chunkManager_load finds a chunk that is suitable for loading and pushes a ChunkUpdate onto pendingUpdates
;chunkManager_processUpdate finds the pushed update and calls chunk_generate to generate the chunk
;the collider is also created
;a ChunkGraphicsUpdate is pushed onto the pendingGraphicsUpdates queue
;the ChunkGraphicsUpdate is popped from the queue on the graphics(main) thread by chunkManager_processGraphicsUpdate
;the renderable of the chunk is generated
;the chunk is pushed into the loadedChunks vector

section .rodata use32
	texture_path db "./sprites/texture.bmp",0
	
	vertex_shader_path db "./shaders/chunk/chunk4D.vag",0
	fragment_shader_path db "./shaders/chunk/chunk4D.fag",0
	geometry_shader_path db "./shaders/chunk/chunk4D.gag",0
	
	uniform_name_chunkPos db "chunkPos",0
	uniform_name_hyperPlanePos db "hyperPlanePos",0
	uniform_name_hyperPlaneDir1 db "hyperPlaneDir1",0
	uniform_name_hyperPlaneDir2 db "hyperPlaneDir2",0
	uniform_name_hyperPlaneDir3 db "hyperPlaneDir3",0
	uniform_name_hyperPlaneNormal db "hyperPlaneNormal",0
	
	test_text db "you're so portuguese",10,0
	test_text2 db "you're so portuguese2",10,0
	test_text3 db "you're so portuguese3",10,0
	
section .text use32

	;should be called from the graphics thread
	global chunkManager4d_create					;ChunkManager4D* chunkManager4d_create()
	
	global chunkManager4d_load					;void chunkManager4d_load(ChunkManager4D* manager, vec3* playerPos3D, int renderDistance)
	;reloading is also registered in the chunkManager4d_unload
	global chunkManager4d_unload					;void chunkManager4d_unload(ChunkManager4D* manager, vec3* playerPos3D, int renderDistance)
	
	;immediately unloads all chunks
	;should be called from the graphics thread
	global chunkManager4d_unloadAll				;void chunkManager4d_unloadAll(ChunkManager4D* manager)
	
	global chunkManager4d_processUpdate			;void chunkManager4d_processUpdate(ChunkManager4D* manager)
	;should be called from the graphics thread
	global chunkManager4d_processGraphicsUpdate	;void chunkManager4d_processGraphicsUpdate(ChunkManager4D* manager)
	
	global chunkManager4d_render					;void chunkManager4d_render(ChunkManager4D* manager, mat4* pv)
	
	global chunkManager4d_getHyperPlane			;HyperPlane* chunkManager4d_getHyperPlane(ChunkManager4D* cm)
	global chunkManager4d_setHyperPlane			;void chunkManager4d_setHyperPlane(ChunkManager4D* cm, HyperPlane* ph)
	
	global chunkManager4d_getPlayerChunk4D			;void chunkManager4d_getPlayerChunk4D(ChunkManager4D* cm, vec3* playerPos3D, int* chunkX, int* chunkZ, int* chunkW)
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy
	extern my_qsort
	
	extern chunk4d_generate
	extern chunk4d_destroy
	extern CHUNK_WIDTH
	
	extern hyperPlane_create
	extern hyperPlane_getNormal
	
	extern mutex_create
	extern mutex_destroy
	extern mutex_lock
	extern mutex_unlock
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove
	extern vector_search
	
	extern tsQueue_init
	extern tsQueue_destroy
	extern tsQueue_push
	extern tsQueue_pop
	extern tsQueue_search
	extern tsQueue_isEmpty
	extern tsQueue_at
	extern tsQueue_size
	
	extern vec4_add
	extern vec4_scale
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_setAlbedo
	extern renderable_createShader
	extern renderable_useShader
	extern renderable_setUniform
	extern renderable_setPrimitive
	extern RENDERABLE_UNIFORM_VEC4
	
	extern GL_POINTS

chunkManager4d_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;ChunkManager4D*
	
	;alloc chunk manager
	push 104
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
	add eax, 16
	push 10000
	push 4
	push eax
	call tsQueue_init
	add esp, 12
	
	mov eax, dword[ebp-4]
	add eax, 24
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
	mov dword[ecx+96], eax
	
	;create shader
	push geometry_shader_path
	push fragment_shader_path
	push vertex_shader_path
	call renderable_createShader
	mov ecx, dword[ebp-4]
	mov dword[ecx+100], eax
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_render:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 16
	
	;set renderable primitive
	push dword[GL_POINTS]
	call renderable_setPrimitive
	add esp, 4
	
	;use shader
	mov eax, dword[ebp+16]
	push dword[eax+100]
	call renderable_useShader
	add esp, 4
	
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
	push dword[eax+100]
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
	push dword[eax+100]
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
	push dword[eax+100]
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
	push dword[eax+100]
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
	push dword[eax+100]
	call renderable_setUniform
	add esp, 28
	
	mov edi, dword[ebp+16]
	mov esi, dword[edi]				;chunk count in esi
	mov edi, dword[edi+12]			;current chunk in edi
	test esi, esi
	jz chunkManager4d_render_loop_end
	chunkManager4d_render_loop_start:
		;check if there is a renderable for the current chunk
		mov eax, dword[edi]
		cmp dword[eax+12], 0
		je chunkManager4d_render_loop_continue
		
		;set chunkPos uniform
		mov eax, dword[edi]
		sub esp, 16
		mov eax, dword[ebp+16]
		mov ecx, dword[eax]
		imul ecx, dword[CHUNK_WIDTH]
		mov dword[esp], ecx
		mov dword[esp+4], 0
		mov ecx, dword[eax+4]
		imul ecx, dword[CHUNK_WIDTH]
		mov dword[esp+8], ecx
		mov ecx, dword[eax+8]
		imul ecx, dword[CHUNK_WIDTH]
		mov dword[esp+12], ecx
		fild dword[esp]
		fstp dword[esp]
		fild dword[esp+8]
		fstp dword[esp+8]
		fild dword[esp+12]
		fstp dword[esp+12]
		push dword[RENDERABLE_UNIFORM_VEC4]
		push uniform_name_chunkPos
		push dword[eax+100]
		call renderable_setUniform
		add esp, 28
		
		;render chunk
		mov eax, dword[edi]
		push 69					;use textures
		mov ecx, dword[ebp+16]
		push dword[ecx+100]		;shader
		push dword[ebp+20]
		push dword[eax+12]
		call renderable_renderCustom
		add esp, 16
	
		chunkManager4d_render_loop_continue:
		add edi, 4
		dec esi
		test esi, esi
		jnz chunkManager4d_render_loop_start
		
	chunkManager4d_render_loop_end:
	
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
	
	sub esp, 4				;chunk update					44
	
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
					
					
					;pending updates
					lea eax, [ebp-40]
					mov ecx, dword[ebp+20]
					add ecx, 16
					sub esp, 12
					mov dword[esp+8], eax
					mov dword[esp+4], chunkManager4d_pending_updates_search
					mov dword[esp], ecx
					call tsQueue_search
					add esp, 12
					cmp eax, -1
					jne chunkManager4d_load_w_loop_continue
					
					
					;pending graphics updates
					lea eax, [ebp-40]
					mov ecx, dword[ebp+20]
					add ecx, 24
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
		jl chunkManager4d_load_radius_loop_start
		
	chunkManager4d_load_radius_loop_end:
	
	;did we find a loadable chunk?
	cmp dword[ebp-28], 0
	je chunkManager4d_load_end
	
	;alloc chunk update
	push 20
	call my_malloc
	mov dword[ebp-44], eax
	add esp, 4
	
	mov dword[eax], 69			;load
	
	mov ecx, dword[ebp-16]
	mov dword[eax+8], ecx		;chunkX
	mov ecx, dword[ebp-20]
	mov dword[eax+12], ecx		;chunkZ
	mov ecx, dword[ebp-24]
	mov dword[eax+16], ecx		;chunkW
	
	;push chunk update onto pending chunks
	mov eax, dword[ebp-44]
	mov ecx, dword[ebp+20]
	add ecx, 16
	
	push eax
	push ecx
	call tsQueue_push
	add esp, 8
	
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
	
	sub esp, 4				;chunk update				32
	
	sub esp, 4				;reload necessary			36 (unused)
	
	;it is an array of struct{int distance; Chunk* chunk}
	;which is sorted in ascending order of distances
	;distance is the greatest difference in chunk positions from the player chunk
	sub esp, 4				;helper array				40
	sub esp, 4				;helper array length		44
	
	mov dword[ebp-16], 0
	mov dword[ebp-36], 0
	
	mov dword[ebp-40], 0
	mov dword[ebp-44], 0
	
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
	
	;lock vector mutex
	mov eax, dword[ebp+20]
	push -1
	push dword[eax+96]
	call mutex_lock
	add esp, 8
	
	;check if there are any chunks loaded
	mov eax, dword[ebp+20]
	mov eax, dword[eax]
	cmp eax, 0
	jle chunkManager4d_unload_no_helper_necessary
	
	;allocate helper array
	mov dword[ebp-44], eax		;save helper length
	shl eax, 3					;eax =8 *eax
	push eax
	call my_malloc
	mov dword[ebp-40], eax
	add esp, 4
	
	
	;fill up helper array
	mov esi, dword[ebp+20]
	mov ebx, dword[esi]				;index in ebx
	mov esi, dword[esi+12]			;current chunk* in esi
	mov edi, dword[ebp-40]			;current helper element in edi
	chunkManager4d_unload_helper_loop_start:
		;calculate distance from chunk
		mov ecx, dword[esi]
		xor edx, edx
		
		;chunkX
		mov eax, dword[ecx]
		sub eax, dword[ebp-28]
		test eax, 0x80000000
		jz chunkManager4d_unload_helper_loop_x_not_negative
			neg eax
		chunkManager4d_unload_helper_loop_x_not_negative:
		mov edx, eax
		
		;chunkZ
		mov eax, dword[ecx+4]
		sub eax, dword[ebp-24]
		test eax, 0x80000000
		jz chunkManager4d_unload_helper_loop_z_not_negative
			neg eax
		chunkManager4d_unload_helper_loop_z_not_negative:
		cmp eax, edx
		jl chunkManager4d_unload_helper_loop_z_not_greater
			mov edx, eax
		chunkManager4d_unload_helper_loop_z_not_greater:
		
		;chunkW
		mov eax, dword[ecx+8]
		sub eax, dword[ebp-20]
		test eax, 0x80000000
		jz chunkManager4d_unload_helper_loop_w_not_negative
			neg eax
		chunkManager4d_unload_helper_loop_w_not_negative:
		cmp eax, edx
		jl chunkManager4d_unload_helper_loop_w_not_greater
			mov edx, eax
		chunkManager4d_unload_helper_loop_w_not_greater:
		
		;set helper value
		mov dword[edi], edx
		mov dword[edi+4], ecx
	
	
		add esi, 4
		add edi, 8
		dec ebx
		test ebx, ebx
		jnz chunkManager4d_unload_helper_loop_start
		
	chunkManager4d_unload_no_helper_necessary:
		
	;unlock vector mutex
	mov eax, dword[ebp+20]
	push dword[eax+96]
	call mutex_unlock
	add esp, 4
	
	;check if there are any chunks to be unloaded
	cmp dword[ebp-44], 0
	jle chunkManager4d_unload_end
	
	;sort the helper array according to the distance
	push chunkManager4d_unload_comparator
	push 8
	push dword[ebp-44]
	push dword[ebp-40]
	call my_qsort
	add esp, 16
	
	;search for chunk updates
	mov esi, dword[ebp-44]			;index in esi
	mov edi, dword[ebp-40]			;current helper element in edi
	chunkManager4d_unload_unload_loop_start:
		;check if the chunk is out of the render distance
		mov eax, dword[edi]
		cmp eax, dword[ebp+28]
		jg chunkManager4d_unload_unload_loop_should_unload
		
		jmp chunkManager4d_unload_unload_loop_continue
		
		chunkManager4d_unload_unload_loop_should_unload:
			mov ebx, dword[edi+4]
		
			;check if the chunk is not already in the unload queue
			push ebx
			push chunkManager4d_pending_unloads_search
			mov eax, dword[ebp+20]
			add eax, 16
			push eax
			call tsQueue_search
			add esp, 12
			cmp eax, -1
			jne chunkManager4d_unload_unload_loop_continue
		
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
		add edi, 8
		dec esi
		test esi, esi
		jnz chunkManager4d_unload_unload_loop_start
		
	chunkManager4d_unload_unload_loop_end:
	
	;destroy helper
	push dword[ebp-40]
	call my_free
	add esp, 4
		
	;did we find an unloadable chunk?
	cmp dword[ebp-16], 0
	je chunkManager4d_unload_end
	
		;alloc unload chunk update
		push 20
		call my_malloc
		mov dword[ebp-32], eax
		add esp, 4
		
		mov dword[eax], 0			;unload
		mov ecx, dword[ebp-16]
		mov dword[eax+4], ecx		;chunk
		
		;push unload chunk update onto pending chunks
		mov eax, dword[ebp-32]
		mov ecx, dword[ebp+20]
		add ecx, 16
		
		push eax
		push ecx
		call tsQueue_push
		add esp, 8
	
	chunkManager4d_unload_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
chunkManager4d_processUpdate:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;chunk					4
	sub esp, 4				;chunk update			8
	sub esp, 4				;chunk graphics update	12
	sub esp, 4				;removal successful		16
	
	;check if the pending updates queue is empty
	mov eax, dword[ebp+8]
	add eax, 16
	push eax
	call tsQueue_isEmpty
	add esp, 4
	test eax, eax
	jnz chunkManager4d_processUpdate_end
	
	;pop an update
	lea eax, [ebp-8]
	push eax
	mov eax, dword[ebp+8]
	add eax, 16
	push eax
	call tsQueue_pop
	add esp, 8

	
	;examine what kind of update it is
	mov eax, dword[ebp-8]
	cmp dword[eax], 0
	je chunkManager4d_processUpdate_unload
	chunkManager4d_processUpdate_load:
		;generate chunk
		mov eax, dword[ebp-8]
		push dword[eax+16]			;chunkw
		push dword[eax+12]			;chunkz
		push dword[eax+8]			;chunkx
		call chunk4d_generate
		mov dword[ebp-4], eax
		add esp, 12
		
		;create graphics update
		push 8
		call my_malloc
		mov dword[ebp-12], eax
		add esp, 4
		
		mov dword[eax+4], 69			;load
		mov ecx, dword[ebp-4]
		mov dword[eax], ecx				;chunk
		
		;add the graphics update to the queue
		mov ecx, dword[ebp+8]
		add ecx, 24
		
		push eax
		push ecx
		call tsQueue_push
		add esp, 8
		
		jmp chunkManager4d_processUpdate_dealloc_update
	
	chunkManager4d_processUpdate_unload:
		mov eax, dword[ebp-8]
		mov ecx, dword[eax+4]
		mov dword[ebp-4], ecx
		
		;remove chunk from loaded chunks
		mov eax, dword[ebp+8]
		push -1
		push dword[eax+96]
		call mutex_lock
		add esp, 8
		
		push dword[ebp-4]
		push dword[ebp+8]
		call vector_remove
		mov dword[ebp-16], eax
		add esp, 8
		
		mov eax, dword[ebp+8]
		push dword[eax+96]
		call mutex_unlock
		add esp, 4
		
		;flee if the removal from the loadedChunks vector was unsuccessful
		cmp dword[ebp-16], 0
		je chunkManager4d_processUpdate_dealloc_update
	
		
		;create graphics update and add it to the queue if there is a renderable
		mov eax, dword[ebp-4]
		cmp dword[eax+12], 0
		je chunkManager4d_processUpdate_unload_no_renderable
			push 8
			call my_malloc
			mov dword[ebp-12], eax
			add esp, 4
			
			mov dword[eax+4], 0			;unload
			mov ecx, dword[ebp-4]
			mov ecx, dword[ecx+12]
			mov dword[eax], ecx				;renderable
			
			;add the graphics update to the queue
			mov ecx, dword[ebp+8]
			add ecx, 24
			
			push eax
			push ecx
			call tsQueue_push
			add esp, 8
			
		chunkManager4d_processUpdate_unload_no_renderable:
		
		
		;yeet chunk
		push dword[ebp-4]
		call chunk4d_destroy
		add esp, 4
	
		jmp chunkManager4d_processUpdate_dealloc_update
	
	chunkManager4d_processUpdate_dealloc_update:
	push dword[ebp-8]
	call my_free
	add esp, 4
	
	chunkManager4d_processUpdate_end:
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager4d_processGraphicsUpdate:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;graphics update				4
	sub esp, 16			;imitated vertex vector			20
	
	;check if the pending updates queue is empty
	mov eax, dword[ebp+8]
	add eax, 24
	push eax
	call tsQueue_isEmpty
	add esp, 4
	test eax, eax
	jnz chunkManager4d_processGraphicsUpdate_end
	
	;pop an update
	lea eax, [ebp-4]
	push eax
	mov eax, dword[ebp+8]
	add eax, 24
	push eax
	call tsQueue_pop
	add esp, 8

	
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
			add esp, 20
			
			mov ecx, dword[ebp-4]
			mov ecx, dword[ecx]
			mov dword[ecx+12], eax
			
			push texture_path
			push eax
			call renderable_setAlbedo
			add esp, 8
			
			;destroy the vertex and index data in the chunk
			mov eax, dword[ebp-4]
			mov eax, dword[eax]
			push dword[eax+52]
			mov dword[eax+52], 0
			mov dword[eax+56], 0
			call my_free
			add esp, 4
		
		chunkManager4d_processGraphicsUpdate_no_mesh:
		
		;add chunk to loaded chunks
		mov eax, dword[ebp+8]
		push -1
		push dword[eax+96]
		call mutex_lock
		add esp, 8
		
		mov ecx, dword[ebp-4]
		push dword[ecx]
		push dword[ebp+8]
		call vector_push_back
		add esp, 8
			
		mov eax, dword[ebp+8]
		push dword[eax+96]
		call mutex_unlock
		add esp, 4
		
		jmp chunkManager4d_processGraphicsUpdate_dealloc_update
		
	chunkManager4d_processGraphicsUpdate_unload:
		;it is an unload update
		
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
	
	chunkManager4d_processGraphicsUpdate_end:
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
;int chunkManager4d_pending_updates_search(ChunkUpdate4D** cu, void* data)
chunkManager4d_pending_updates_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	
	mov dword[ebp-4], 69
	
	;decide what kind of an update it is
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	cmp dword[eax], 0
	je chunkManager4d_pending_updates_search_unload
		;it is a load update
		mov ecx, dword[ebp+12]
		
		mov edx, dword[ecx]
		cmp edx, dword[eax+8]
		jne chunkManager4d_pending_updates_search_end
		mov edx, dword[ecx+4]
		cmp edx, dword[eax+12]
		jne chunkManager4d_pending_updates_search_end
		mov edx, dword[ecx+8]
		cmp edx, dword[eax+16]
		jne chunkManager4d_pending_updates_search_end
		
		mov dword[ebp-4], 0
		
		jmp chunkManager4d_pending_updates_search_end
		
	chunkManager4d_pending_updates_search_unload:
		;it is an unload update
		mov eax, dword[eax+4]
		mov ecx, dword[ebp+12]
		
		mov edx, dword[ecx]
		cmp edx, dword[eax]
		jne chunkManager4d_pending_updates_search_end
		mov edx, dword[ecx+4]
		cmp edx, dword[eax+4]
		jne chunkManager4d_pending_updates_search_end
		mov edx, dword[ecx+8]
		cmp edx, dword[eax+8]
		jne chunkManager4d_pending_updates_search_end
		
		mov dword[ebp-4], 0
		
		jmp chunkManager4d_pending_updates_search_end
		
	chunkManager4d_pending_updates_search_end:
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
	
;it is a compare function for vector_search
;returns 0 if there is a match
;int chunkManager4d_loaded_chunks_search(ChunkUpdate4D** cu, Chunk4D* data)
chunkManager4d_pending_unloads_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	mov dword[ebp-4], 69
	
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	cmp dword[eax], 0
	jne chunkManager4d_pending_unloads_search_end		;not an unload update
	
	mov eax, dword[eax+4]	;chunk*
	cmp eax, dword[ebp+12]
	jne chunkManager4d_pending_unloads_search_end
		mov dword[ebp-4], 0
	
	chunkManager4d_pending_unloads_search_end:
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