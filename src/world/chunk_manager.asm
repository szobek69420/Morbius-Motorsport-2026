[BITS 32]

;layout:
;struct ChunkManager{
;	vector<Chunk*> loadedChunks;								0
;	tsQueue<ChunkUpdate*> pendingUpdates;						16
;	tsQueue<ChunkGraphicsUpdate*> pendingGraphicsUpdates;		24
;	HyperPlane hyperPlane;										32
;	Mutex* loadedChunksMutex;									96
;}		100 bytes overall

;layout:
;struct ChunkUpdate{
;	int load;					0
;	Chunk* chunk;				4, used only if it is an unload update
;	int chunkX, chunkZ, chunkW	8, used only if it is a load update
;}		20 bytes overall

;layout:
;struct ChunkGraphicsUpdate{
;	void* data					0, it is Chunk* if load update, otherwise a renderable*
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

	print_int_nl db "%d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_six_ints_nl db "%d %d %d %d %d %d",10,0
	print_seven_ints_nl db "%d %d %d %d %d %d %d",10,0
	
	test_text db "Otto von Rizzmarck",10,0

section .text use32

	global chunkManager_create					;ChunkManager* chunkManager_create()
	
	global chunkManager_load					;void chunkManager_load(ChunkManager* manager, vec3* playerPos3D, int renderDistance)
	;reloading is also registered in the chunkManager_unload
	global chunkManager_unload					;void chunkManager_unload(ChunkManager* manager, vec3* playerPos3D, int renderDistance)
	
	;immediately unloads all chunks
	;should be called from the graphics thread
	global chunkManager_unloadAll				;void chunkManager_unloadAll(ChunkManager* manager)
	
	global chunkManager_processUpdate			;void chunkManager_processUpdate(ChunkManager* manager)
	;should be called from the graphics thread
	global chunkManager_processGraphicsUpdate	;void chunkManager_processGraphicsUpdate(ChunkManager* manager)
	
	global chunkManager_render					;void chunkManager_render(ChunkManager* manager, mat4* pv)
	
	global chunkManager_getHyperPlane			;HyperPlane* chunkManager_getHyperPlane(ChunkManager* cm)
	global chunkManager_setHyperPlane			;void chunkManager_setHyperPlane(ChunkManager* cm, HyperPlane* ph)
	
	global chunkManager_getPlayerChunk			;void chunkManager_getPlayerChunk(ChunkManager* cm, vec3* playerPos3D, int* chunkX, int* chunkZ, int* chunkW)
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy
	
	extern chunk_generate
	extern chunk_destroy
	
	extern hyperPlane_create
	
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
	
	extern renderable_create
	extern renderable_destroy
	extern renderable_render
	extern renderable_setAlbedo
	extern RENDERABLE_ATTRIB_P3UV2
	
chunkManager_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;ChunkManager*
	
	;alloc chunk manager
	push 100
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
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager_render:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	mov edi, dword[ebp+16]
	mov esi, dword[edi]				;chunk count in esi
	mov edi, dword[edi+12]			;current chunk in edi
	test esi, esi
	jz chunkManager_render_loop_end
	chunkManager_render_loop_start:
		;check if there is a renderable for the current chunk
		mov eax, dword[edi]
		cmp dword[eax+12], 0
		je chunkManager_render_loop_continue
		
		;render chunk
		push dword[ebp+20]
		push dword[eax+12]
		call renderable_render
		add esp, 8
	
		chunkManager_render_loop_continue:
		add edi, 4
		dec esi
		test esi, esi
		jnz chunkManager_render_loop_start
		
	chunkManager_render_loop_end:
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
chunkManager_load:
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
	call chunkManager_getPlayerChunk
	add esp, 20
	
	;search for an unloaded chunk
	;searches in an expanding radius from the player chunk
	xor ebx, ebx			;radius in ebx
	chunkManager_load_radius_loop_start:
		mov esi, ebx
		neg esi				;x index in esi
		chunkManager_load_x_loop_start:
			mov edi, ebx
			neg edi				;z index in edi
			chunkManager_load_z_loop_start:
				mov eax, ebx
				neg eax				;w index in eax
				chunkManager_load_w_loop_start:
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
					mov dword[esp+4], chunkManager_loaded_chunks_search
					mov dword[esp], ecx
					call vector_search
					add esp, 12
					cmp eax, -1
					jne chunkManager_load_w_loop_continue
					
					
					;pending updates
					lea eax, [ebp-40]
					mov ecx, dword[ebp+20]
					add ecx, 16
					sub esp, 12
					mov dword[esp+8], eax
					mov dword[esp+4], chunkManager_pending_updates_search
					mov dword[esp], ecx
					call tsQueue_search
					add esp, 12
					cmp eax, -1
					jne chunkManager_load_w_loop_continue
					
					
					;pending graphics updates
					lea eax, [ebp-40]
					mov ecx, dword[ebp+20]
					add ecx, 24
					sub esp, 12
					mov dword[esp+8], eax
					mov dword[esp+4], chunkManager_pending_graphics_updates_search
					mov dword[esp], ecx
					call tsQueue_search
					add esp, 12
					cmp eax, -1
					jne chunkManager_load_w_loop_continue
					
					
					;the chunk is not loaded yet, mark it as loadable
					mov dword[ebp-28], 69
					
					mov edx, dword[ebp-40]
					mov dword[ebp-16], edx
					mov edx, dword[ebp-36]
					mov dword[ebp-20], edx
					mov edx, dword[ebp-32]
					mov dword[ebp-24], edx
					jmp chunkManager_load_radius_loop_end
					
					chunkManager_load_w_loop_continue:
					pop eax					;restore eax
					
					inc eax
					cmp eax, ebx
					jle chunkManager_load_w_loop_start
				
				inc edi
				cmp edi, ebx
				jle chunkManager_load_z_loop_start
				
			inc esi
			cmp esi, ebx
			jle chunkManager_load_x_loop_start
			
		inc ebx
		cmp ebx, dword[ebp+28]
		jl chunkManager_load_radius_loop_start
		
	chunkManager_load_radius_loop_end:
	
	;did we find a loadable chunk?
	cmp dword[ebp-28], 0
	je chunkManager_load_end
	
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
	
	chunkManager_load_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
chunkManager_unload:
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
	
	sub esp, 4				;reload necessary			36
	
	mov dword[ebp-16], 0
	mov dword[ebp-36], 0
	
	;calculate player chunk
	lea eax, [ebp-20]
	push eax
	sub eax, 4
	push eax
	sub eax, 4
	push eax
	push dword[ebp+24]
	push dword[ebp+20]
	call chunkManager_getPlayerChunk
	add esp, 20
	
	;lock vector mutex
	mov eax, dword[ebp+20]
	push -1
	push dword[eax+96]
	call mutex_lock
	add esp, 8
	
	
	mov edi, dword[ebp+20]
	mov esi, dword[edi]				;index in esi
	mov edi, dword[edi+12]			;current chunk* in edi
	test esi, esi
	jz chunkManager_unload_loop_end
	chunkManager_unload_loop_start:
		mov ebx, dword[edi]
	
		;check chunk x
		mov eax, dword[ebx]
		sub eax, dword[ebp-28]
		test eax, 0x80000000
		jz chunkManager_unload_loop_x_not_negative
			neg eax
		chunkManager_unload_loop_x_not_negative:
		cmp eax, dword[ebp+28]
		jg chunkManager_unload_loop_should_unload			;x is further than the render distance
		
		;check chunk z
		mov eax, dword[ebx+4]
		sub eax, dword[ebp-24]
		test eax, 0x80000000
		jz chunkManager_unload_loop_z_not_negative
			neg eax
		chunkManager_unload_loop_z_not_negative:
		cmp eax, dword[ebp+28]
		jg chunkManager_unload_loop_should_unload			;z is further than the render distance
		
		;check chunk w
		mov eax, dword[ebx+8]
		sub eax, dword[ebp-20]
		test eax, 0x80000000
		jz chunkManager_unload_loop_w_not_negative
			neg eax
		chunkManager_unload_loop_w_not_negative:
		cmp eax, dword[ebp+28]
		jg chunkManager_unload_loop_should_unload			;w is further than the render distance
		
		;check if the chunk should be unloaded
		cmp dword[ebx+68], 0
		jne chunkManager_unload_loop_should_reload
		
		;the chunk is within render distance
		jmp chunkManager_unload_loop_continue
	
		chunkManager_unload_loop_should_unload:
			;check if the chunk is not already in the unload queue
			push ebx
			push chunkManager_pending_unloads_search
			mov eax, dword[ebp+20]
			add eax, 16
			push eax
			call tsQueue_search
			add esp, 12
			cmp eax, -1
			jne chunkManager_unload_loop_continue
		
			;save info
			mov dword[ebp-16], ebx
			
			mov ecx, dword[ebx]
			mov dword[ebp-12], ecx
			mov ecx, dword[ebx+4]
			mov dword[ebp-8], ecx
			mov ecx, dword[ebx+8]
			mov dword[ebp-4], ecx
			
			jmp chunkManager_unload_loop_end
			
			
		chunkManager_unload_loop_should_reload:
			;check if the chunk is not already in the unload queue
			push ebx
			push chunkManager_pending_unloads_search
			mov eax, dword[ebp+20]
			add eax, 16
			push eax
			call tsQueue_search
			add esp, 12
			cmp eax, -1
			jne chunkManager_unload_loop_continue
			
			;save info
			mov dword[ebp-36], 69			;reload is necessary
			mov dword[ebp-16], ebx
			
			mov ecx, dword[ebx]
			mov dword[ebp-12], ecx
			mov ecx, dword[ebx+4]
			mov dword[ebp-8], ecx
			mov ecx, dword[ebx+8]
			mov dword[ebp-4], ecx
			
			jmp chunkManager_unload_loop_end
		
		chunkManager_unload_loop_continue:
		add edi, 4
		dec esi
		test esi, esi
		jnz chunkManager_unload_loop_start
		
	chunkManager_unload_loop_end:
	
	;unlock vector mutex
	mov eax, dword[ebp+20]
	push dword[eax+96]
	call mutex_unlock
	add esp, 4
		
	;did we find an unloadable chunk?
	cmp dword[ebp-16], 0
	je chunkManager_unload_end
	
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
	
	;is a reload necessary?
	cmp dword[ebp-36], 0
	je chunkManager_unload_end
	
		;alloc load chunk update
		push 20
		call my_malloc
		mov dword[ebp-32], eax
		add esp, 4
		
		mov dword[eax], 69			;load
		mov ecx, dword[ebp-12]
		mov dword[eax+8], ecx		;chunkX
		mov ecx, dword[ebp-8]
		mov dword[eax+12], ecx		;chunkZ
		mov ecx, dword[ebp-4]
		mov dword[eax+16], ecx		;chunkW
		
		;push load chunk update onto pending chunks
		mov eax, dword[ebp-32]
		mov ecx, dword[ebp+20]
		add ecx, 16
		
		push eax
		push ecx
		call tsQueue_push
		add esp, 8
	
	chunkManager_unload_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
chunkManager_processUpdate:
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
	jnz chunkManager_processUpdate_end
	
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
	je chunkManager_processUpdate_unload
	chunkManager_processUpdate_load:
		;generate chunk
		mov ecx, dword[ebp+8]
		add ecx, 32					;chunkmanager.hyperplane
		push ecx
		push dword[eax+16]			;chunkw
		push dword[eax+12]			;chunkz
		push dword[eax+8]			;chunkx
		call chunk_generate
		mov dword[ebp-4], eax
		add esp, 16
		
		;TODO: create and register collider if there is a mesh
		
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
		
		jmp chunkManager_processUpdate_dealloc_update
	
	chunkManager_processUpdate_unload:
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
		je chunkManager_processUpdate_dealloc_update
		
		;TODO: unregister and yeet collider if necessary
		
		;create graphics update and add it to the queue if there is a renderable
		mov eax, dword[ebp-4]
		cmp dword[eax+12], 0
		je chunkManager_processUpdate_unload_no_renderable
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
			
		chunkManager_processUpdate_unload_no_renderable:
		
		
		;yeet chunk
		push dword[ebp-4]
		call chunk_destroy
		add esp, 4
	
		jmp chunkManager_processUpdate_dealloc_update
	
	chunkManager_processUpdate_dealloc_update:
	push dword[ebp-8]
	call my_free
	add esp, 4
	
	chunkManager_processUpdate_end:
	mov esp, ebp
	pop ebp
	ret
	
	
chunkManager_processGraphicsUpdate:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;graphics update				4
	sub esp, 16			;imitated vertex vector			20
	sub esp, 16			;imitated index vector			36
	
	;check if the pending updates queue is empty
	mov eax, dword[ebp+8]
	add eax, 24
	push eax
	call tsQueue_isEmpty
	add esp, 4
	test eax, eax
	jnz chunkManager_processGraphicsUpdate_end
	
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
	je chunkManager_processGraphicsUpdate_unload
		;it is a load update
		mov eax, dword[ebp-4]
		mov eax, dword[eax]				;chunk in eax
		cmp dword[eax+56], 0
		je chunkManager_processGraphicsUpdate_no_mesh			;there is no mesh
		
			;create the imitated vectors
			mov ecx, dword[eax+56]
			mov dword[ebp-20], ecx
			mov dword[ebp-16], ecx
			mov dword[ebp-12], 4
			mov ecx, dword[eax+52]
			mov dword[ebp-8], ecx
			
			mov ecx, dword[eax+64]
			mov dword[ebp-36], ecx
			mov dword[ebp-32], ecx
			mov dword[ebp-28], 4
			mov ecx, dword[eax+60]
			mov dword[ebp-24], ecx
			
			;create renderable and set texture
			push dword[RENDERABLE_ATTRIB_P3UV2]
			lea eax, [ebp-36]
			push eax
			lea eax, [ebp-20]
			push eax
			call renderable_create
			add esp, 12
			
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
			push dword[eax+60]
			mov dword[eax+52], 0
			mov dword[eax+56], 0
			mov dword[eax+60], 0
			mov dword[eax+64], 0
			call my_free
			add esp, 4
			call my_free
			add esp, 4
		
		chunkManager_processGraphicsUpdate_no_mesh:
		
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
		
		jmp chunkManager_processGraphicsUpdate_dealloc_update
		
	chunkManager_processGraphicsUpdate_unload:
		;it is an unload update
		
		;destroy the renderable
		mov eax, dword[ebp-4]
		push dword[eax]
		call renderable_destroy
		add esp, 4
		
		jmp chunkManager_processGraphicsUpdate_dealloc_update
		
	chunkManager_processGraphicsUpdate_dealloc_update:
	
	;dealloc update
	push dword[ebp-4]
	call my_free
	
	chunkManager_processGraphicsUpdate_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;clears the pending updates queue
;overrides every graphics load update so that there will be no mesh
;processes the pending graphics updates
;marks every loaded chunk as shouldBeReloaded
chunkManager_unloadAll:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4				;pending updates queue
	sub esp, 4				;pending graphics updates queue
	sub esp, 4				;temp update
	
	mov eax, dword[ebp+20]
	add eax, 16
	mov dword[ebp-4], eax
	add eax, 8
	mov dword[ebp-8], eax
	
	;clear the pending update queue
	chunkManager_unloadAll_clear_pending_loop_start:
		;check if the queue is empty
		push dword[ebp-4]
		call tsQueue_isEmpty
		add esp, 4
		test eax, eax
		jnz chunkManager_unloadAll_clear_pending_loop_end
		
		;pop update
		lea eax, [ebp-12]
		push eax
		push dword[ebp-4]
		call tsQueue_pop
		add esp, 8
		
		;yeet update
		push dword[ebp-12]
		call my_free
		add esp, 4
		
		jmp chunkManager_unloadAll_clear_pending_loop_start
	
	chunkManager_unloadAll_clear_pending_loop_end:
	
	;override graphics load updates
	push dword[ebp-8]
	call tsQueue_size
	add esp, 4
	mov esi, eax
	test esi, esi
	jz chunkManager_unloadAll_override_graphics_loop_end
	chunkManager_unloadAll_override_graphics_loop_start:
		;get the update
		mov ecx, esi
		dec ecx
		push ecx
		push dword[ebp-8]
		call tsQueue_at
		add esp, 8
		
		mov ecx, dword[eax]				;tsQueue_at returns a ChunkGraphicsUpdate**
		mov dword[ebp-12], ecx
		
		;see if it is a load update
		mov ecx, dword[ebp-12]
		cmp dword[ecx+4], 0
		je chunkManager_unloadAll_override_graphics_loop_continue
		
		;yeet the vertex data
		mov ecx, dword[ecx]				;chunk in ecx
		mov dword[ecx+56], 0
		mov dword[ecx+64], 0
		
		push dword[ecx+52]
		push dword[ecx+60]
		call my_free
		add esp, 4
		call my_free
		add esp, 4
		
		chunkManager_unloadAll_override_graphics_loop_continue:
		dec esi
		test esi, esi
		jnz chunkManager_unloadAll_override_graphics_loop_start
	chunkManager_unloadAll_override_graphics_loop_end:
	
	
	;process graphics updates
	chunkManager_unloadAll_process_graphics_updates_loop_start:
		;check if the queue is empty
		push dword[ebp-8]
		call tsQueue_isEmpty
		add esp, 4
		test eax, eax
		jnz chunkManager_unloadAll_process_graphics_updates_loop_end
		
		;process graphics update
		push dword[ebp+20]
		call chunkManager_processGraphicsUpdate
		add esp, 4
		
		jmp chunkManager_unloadAll_process_graphics_updates_loop_start
		
	chunkManager_unloadAll_process_graphics_updates_loop_end:
	
	
	;mark as reloadable
	mov eax, dword[ebp+20]
	push -1
	push dword[eax+96]
	call mutex_lock
	add esp, 8
	
	mov eax, dword[ebp+20]
	mov esi, dword[eax]					;index in esi
	mov edi, dword[eax+12]				;current chunk** in edi
	mov ebx, dword[eax+8]				;element size in ebx
	test esi, esi
	jz chunkManager_unloadAll_push_unload_updates_loop_end
	chunkManager_unloadAll_push_unload_updates_loop_start:
		mov ecx, dword[edi]
		mov dword[ecx+68], 69
		
		add edi, ebx
		dec esi
		test esi, esi
		jnz chunkManager_unloadAll_push_unload_updates_loop_start
		
	chunkManager_unloadAll_push_unload_updates_loop_end:
	
	mov eax, dword[ebp+20]
	push dword[eax+96]
	call mutex_unlock
	add esp, 4
	
	chunkManager_unloadAll_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
chunkManager_setHyperPlane:
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
	
	
chunkManager_getHyperPlane:
	mov eax, dword[esp+4]
	add eax, 32
	ret
	
chunkManager_getPlayerChunk:
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
;Chunk** because the comparator for vector_search expects an element* and a void* and the element is Chunk*
;returns 0 if there is a match
;int chunkManager_loaded_chunks_search(Chunk** chunk, void* data)
chunkManager_loaded_chunks_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	
	mov dword[ebp-4], 69
	
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	mov ecx, dword[ebp+12]
	
	mov edx, dword[eax]
	cmp edx, dword[ecx]
	jne chunkManager_loaded_chunk_search_end
	
	mov edx, dword[eax+4]
	cmp edx, dword[ecx+4]
	jne chunkManager_loaded_chunk_search_end
	
	mov edx, dword[eax+8]
	cmp edx, dword[ecx+8]
	jne chunkManager_loaded_chunk_search_end
	
	mov dword[ebp-4], 0
	
	chunkManager_loaded_chunk_search_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
;it is a compare function for tsQueue_search
;data is the address of a memory region in which the chunkX, chunkZ and chunkW int-triplet is stored
;returns 0 if there is a match
;int chunkManager_pending_updates_search(ChunkUpdate** cu, void* data)
chunkManager_pending_updates_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	
	mov dword[ebp-4], 69
	
	;decide what kind of an update it is
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	cmp dword[eax], 0
	je chunkManager_pending_updates_search_unload
		;it is a load update
		mov ecx, dword[ebp+12]
		
		mov edx, dword[ecx]
		cmp edx, dword[eax+8]
		jne chunkManager_pending_updates_search_end
		mov edx, dword[ecx+4]
		cmp edx, dword[eax+12]
		jne chunkManager_pending_updates_search_end
		mov edx, dword[ecx+8]
		cmp edx, dword[eax+16]
		jne chunkManager_pending_updates_search_end
		
		mov dword[ebp-4], 0
		
		jmp chunkManager_pending_updates_search_end
		
	chunkManager_pending_updates_search_unload:
		;it is an unload update
		mov eax, dword[eax+4]
		mov ecx, dword[ebp+12]
		
		mov edx, dword[ecx]
		cmp edx, dword[eax]
		jne chunkManager_pending_updates_search_end
		mov edx, dword[ecx+4]
		cmp edx, dword[eax+4]
		jne chunkManager_pending_updates_search_end
		mov edx, dword[ecx+8]
		cmp edx, dword[eax+8]
		jne chunkManager_pending_updates_search_end
		
		mov dword[ebp-4], 0
		
		jmp chunkManager_pending_updates_search_end
		
	chunkManager_pending_updates_search_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
;it is a compare function for tsQueue_search
;data is the address of a memory region in which the chunkX, chunkZ and chunkW int-triplet is stored
;returns 0 if there is a match
;int chunkManager_pending_graphics_updates_search(ChunkGraphicsUpdate** cgu, void* data)
chunkManager_pending_graphics_updates_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	mov dword[ebp-4], 69
	
	;check if it is a load update (unload is irrelevant)
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	cmp dword[eax+4], 0
	je chunkManager_pending_graphics_updates_search_end
	
		;it is a load update
		mov eax, dword[eax]
		mov ecx, dword[ebp+12]
		
		mov edx, dword[ecx]
		cmp edx, dword[eax]
		jne chunkManager_pending_graphics_updates_search_end
		mov edx, dword[ecx+4]
		cmp edx, dword[eax+4]
		jne chunkManager_pending_graphics_updates_search_end
		mov edx, dword[ecx+8]
		cmp edx, dword[eax+8]
		jne chunkManager_pending_graphics_updates_search_end
		
		mov dword[ebp-4], 0
	
	chunkManager_pending_graphics_updates_search_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
;it is a compare function for vector_search
;returns 0 if there is a match
;int chunkManager_loaded_chunks_search(ChunkUpdate** cu, Chunk* data)
chunkManager_pending_unloads_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	mov dword[ebp-4], 69
	
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	cmp dword[eax], 0
	jne chunkManager_pending_unloads_search_end		;not an unload update
	
	mov eax, dword[eax+4]	;chunk*
	cmp eax, dword[ebp+12]
	jne chunkManager_pending_unloads_search_end
		mov dword[ebp-4], 0
	
	chunkManager_pending_unloads_search_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret