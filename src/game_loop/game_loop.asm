[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

%macro render_text 5
	push %5
	push %4
	push %3
	push %2
	push %1
	call textRenderer_drawText
	add esp, 20
%endmacro

section .rodata use32
	PHYSICS_UPDATE_INTERVAL_MS dd 15
	TIME_COEFFICIENT dd 0.01		;100 seconds long days
	
	RENDER_WIDTH dd 1280
	RENDER_HEIGHT dd 800

	ZERO dd 0.0
	ONE dd 1.0
	MINUS_ONE dd -1.0
	ONE_PER_THOUSAND dd 0.001
	P15 dd 0.15
	P6 dd 0.6
	D360 dd 360.0
	
	VERY_SMALL_NUMBER dd 0.0000001
	
	PRETTY_YELLOW dd 1.0, 0.85, 0.0, 1.0
	BLACK dd 0.0, 0.0, 0.0, 1.0
	
	test_text db "OTTO VON BISMARCK",10,0
	test_text2 db "hello everybody my name is welcome",10,0
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_float db "%f",0
	print_float_nl db "%f",10,0
	print_four_floats db "%f, %f, %f, %f",0
	print_new_line db 10,0
	
	image_path db "./sprites/morbussin.bmp",0
	
	sound_path db "./sfx/ingame/battlecry.wav",0
	music_path db "./sfx/ingame/music.wavd",0
	
	error_incomplete_framebuffer db "game_loop: L framebuffer uhuhu ahah",10,0
	
	message_deinit_successful db "Deinitialization successful gg ez",10,0
	
	test_text_main db "main",10,0
	test_text_physics db "physics",10,0
	
	text_point db "Hyperplane point",0
	text_based_vectors db "Hyperplane based vectors",0
	print_vec4 db "(%f; %f; %f; %f)",0
	text_player_pos_4d db "Player position",0
	text_player_pos db "Player position on plane",0
	text_player_view_dir db "View direction on plane",0
	print_vec3 db "(%f; %f; %f)",0
	
	print_loaded_chunk_count db "Loaded chunks: %d",0
	print_fanthom_chunk_count db "Fanthom chunks: %d",0
	print_pending_graphics_update_count db "Pending graphics updates: %d",0
	print_pending_chunk_reload_count db "Pending chunk reloads: %d",0
	print_render_distance db "Render distance: %d",0
	
	print_fps db "FPS: %d",0
	print_physics_delta_time db "Physics: %d ms",0
	print_chunk_loader_delta_time db "Chunk loader: %d ms",0
	print_memory_usage db "Memory usage: %d MB",0
	
	print_raycast_hit_info db "Raycast hit: (%f; %f; %f; %f)",0
	print_raycast_no_hit_info db "Raycast hit: nothing bozo",0
	
	print_opengl_version db "OpenGL %s",0
	print_gpu_type db "%s, %s",0
	
	cursor_image_path db "./sprites/ui/ingame/cursor.bmp",0
	
section .bss use32
	return_value resb 4					;tsValue<int>*, default value is dword[GAME_STATE_INGAME], anything else breaks out of the game loop
	physics_thread resb 4				;thread*
	chunkLoader_thread resb 4			;thread*

	camera resb 36
	view_matrix resb 64
	projection_matrix resb 64
	pv_matrix resb 64
	
	projection_matrix_ui resb 64
	
	pplayer resb 4
	
	chunk_manager resb 4
	chunk_manager_4d resb 4
	
	framebuffer_gbuffer resb 4
	framebuffer_ssao resb 4
	framebuffer_pp resb 4
	
	sound_music resb 4
	
section .data use32
	render_distance dd 3

	last_frame_milliseconds dd 0		;int, the GetTickCount of the last frame
	delta_time_milliseconds dd 0		;int
	delta_time_seconds dd 0.0			;float
	
	current_window dd 0					;GLFWwindow*
	
	should_resize dd 0
	
	milliseconds_since_last_fps_update dd 0
	frames_in_this_second dd 0
	frames_in_last_second dd 0
	
	delta_time_milliseconds_physics dd 0		;int (it is just for monitoring purposes)
	delta_time_milliseconds_chunk_loader dd 0	;int (it is just for monitoring purposes)

	milliseconds_since_last_memory_diagram_update dd 0

	TIME_OF_DAY dd 0.0	;values are in [0;1], 0 and 1 are dawn
	
	SUN_DIRECTION_BUFFER dd 0.0, 1.0, 0.0, 0.0
	
	;info canvas
	CANVAS_INFO dd 0
	
	IMAGE_CURSOR dd 0
	
	TEXT_HYPERPLANE_POINT_LABEL dd 0
	TEXT_HYPERPLANE_POINT dd 0
	TEXT_HYPERPLANE_VECTOR_LABEL dd 0
	TEXT_HYPERPLANE_VECTOR_1 dd 0
	TEXT_HYPERPLANE_VECTOR_2 dd 0
	TEXT_HYPERPLANE_VECTOR_3 dd 0
	TEXT_PLAYER_POSITION_LABEL dd 0
	TEXT_PLAYER_POSITION dd 0
	TEXT_PLAYER_POSITION_3D_LABEL dd 0
	TEXT_PLAYER_POSITION_3D dd 0
	TEXT_VIEW_DIRECTION_3D_LABEL dd 0
	TEXT_VIEW_DIRECTION_3D dd 0
	TEXT_RAYCAST_HIT dd 0
	
	TEXT_FPS dd 0
	TEXT_PHYSICS_DELTA dd 0
	TEXT_CHUNK_LOADER_DELTA dd 0
	TEXT_MEMORY_USAGE dd 0
	IMAGE_MEMORY_USAGE dd 0
	
	TEXT_RENDER_DISTANCE dd 0
	TEXT_LOADED_CHUNKS dd 0
	TEXT_FANTHOM_CHUNKS dd 0
	TEXT_PENDING_GRAPHICS_UPDATES dd 0
	TEXT_PENDING_CHUNK_RELOADS dd 0
	
	TEXT_VERSION dd 0
	TEXT_GPU dd 0

section .text use32

	dll_import kernel32.dll, GetTickCount
	
	;returns the next game state
	;int gameLoop_main(GLFWwindow* pwindow)
	global gameLoop_main
	
	extern GAME_STATE_INGAME
	extern GAME_STATE_MENU
	extern GAME_STATE_DEINIT
	
	extern glClear
	extern glClearColor
	extern glClearDepthf
	extern glEnable
	extern glFrontFace
	extern glViewport
	extern glGetError
	extern glGetString
	
	extern GL_DEPTH_TEST
	extern GL_COLOR_BUFFER_BIT
	extern GL_DEPTH_BUFFER_BIT
	extern GL_CULL_FACE
	extern GL_CCW
	extern GL_POINTS
	extern GL_VENDOR
	extern GL_RENDERER
	extern GL_VERSION

	
	extern camera_init
	extern camera_forward
	extern camera_view
	extern camera_projection
	extern camera_viewProjection
	
	extern my_printf
	extern my_sprintf
	extern my_strcpy
	
	extern my_memcpy
	
	extern glfwSwapBuffers
	extern glfwPollEvents
	extern glfwWindowShouldClose
	extern glfwSetWindowShouldClose
	extern glfwSetKeyCallback
	extern glfwSetMouseButtonCallback
	extern glfwSetCursorPosCallback
	extern glfwSetScrollCallback
	extern glfwSetFramebufferSizeCallback
	extern glfwWindowShouldClose
	extern glfwGetTime
	extern GLFW_KEY_ESCAPE
	
	extern input_init
	extern input_update
	extern input_keyReleased
	extern input_setMousePosition
	extern input_keyCallback
	extern input_mouseButtonCallback
	extern input_mouseMoveCallback
	extern input_mouseScrollCallback
	extern input_hideCursor
	
	extern player_init
	extern player_destroy
	extern player_update
	extern player_updatePhysics
	extern player_drawRaycastHypercube
	
	extern hyperPlane_directionTo3d
	
	extern renderable_init
	extern renderable_deinit
	extern renderable_create
	extern renderable_destroy
	extern renderable_render
	extern renderable_setAlbedo
	extern renderable_setPosition
	extern renderable_enableDepthTest
	extern renderable_enableBlending
	extern RENDERABLE_ATTRIB_P3
	extern RENDERABLE_ATTRIB_P3UV2
	
	extern vector_init
	extern vector_destroy
	extern vector_clear
	extern tsVector_sizeNonBlocking
	extern queue_size
	extern tsQueue_sizeNonBlocking
	
	extern vec3_print
	
	extern textRenderer_init
	extern textRenderer_deinit
	extern textRenderer_drawText
	extern textRenderer_setScreenSize
	extern textRenderer_setFontSize
	extern textRenderer_setColour
	extern TEXT_ORIGIN_BOTTOM_CENTER
	extern TEXT_ORIGIN_TOP_LEFT
	extern TEXT_ORIGIN_BOTTOM_RIGHT
	extern TEXT_ORIGIN_TOP_RIGHT
	extern TEXT_ORIGIN_CENTER_CENTER
	extern TEXT_PIVOT_BOTTOM_CENTER
	extern TEXT_PIVOT_BOTTOM_RIGHT
	extern TEXT_PIVOT_TOP_LEFT
	extern TEXT_PIVOT_TOP_RIGHT
	extern TEXT_PIVOT_CENTER_CENTER
	extern FONT_CHAR_WIDTH
	extern FONT_CHAR_HEIGHT
	
	extern textureHandler_init
	extern textureHandler_deinit
	
	extern WINDOW_SIZE_X
	extern WINDOW_SIZE_Y
	
	extern aabb4d_getPosition
	extern physics4d_init
	extern physics4d_deinit
	extern physics4d_update
	
	extern thread_create
	extern thread_join
	extern thread_resume
	extern tsValue_create
	extern tsValue_destroy
	extern tsValue_get
	extern tsValue_set
	extern tsValue_isEqual
	extern tsQueue_size
	
	extern audio_loadSound
	extern audio_unloadSound
	extern audio_playSound
	extern audio_stopSound
	
	extern framebuffer_create
	extern framebuffer_destroy
	extern framebuffer_colourAttachment
	extern framebuffer_depthAttachment
	extern framebuffer_isComplete
	extern framebuffer_bind
	extern framebuffer_copyDepthBuffer
	extern FRAMEBUFFER_RED
	extern FRAMEBUFFER_RGB
	extern FRAMEBUFFER_RGBA
	extern FRAMEBUFFER_RGB16F
	extern FRAMEBUFFER_RGBA16F
	
	extern postProcessing_init
	extern postProcessing_deinit
	extern postProcessing_drawToScreen
	extern postProcessing_ssao
	extern postProcessing_deferredLighting

	
	extern chunkManager4d_create
	extern chunkManager4d_destroy
	extern chunkManager4d_load
	extern chunkManager4d_unload
	extern chunkManager4d_processUpdate
	extern chunkManager4d_processGraphicsUpdate
	extern chunkManager4d_processChangedBlocks
	extern chunkManager4d_processPendingChunkReloads
	extern chunkManager4d_render
	extern chunkManager4d_getHyperPlane
	
	extern sun_init
	extern sun_deinit
	extern sun_render
	extern sun_setAngle
	extern sun_setDistance
	extern sun_getDirection
	
	extern sky_getColour
	
	extern perlin_init2d
	extern perlin_deinit2d
	extern perlin_init3d
	extern perlin_deinit3d
	
	extern mat4_viewGlm
	extern mat4_perspective
	extern mat4_perspectiveGlm
	extern mat4_print
	extern vec4_mulWithMat
	extern vec4_print
	
	extern uiElement_init
	extern uiElement_deinit
	extern uiElement_processInput
	extern uiElement_render
	
	extern meminfo_getMemoryUsage
	extern memoryUsageDiagram_init
	extern memoryUsageDiagram_deinit
	extern memoryUsageDiagram_update
	extern memoryUsageDiagram_getTexture
	
gameLoop_main:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4		;return value helper		4
	
	;save pwindow
	mov eax, dword[ebp+20]
	mov dword[current_window], eax
	
	;init return_value
	push 4
	call tsValue_create
	mov dword[return_value], eax
	add esp, 4
	
	push dword[GAME_STATE_INGAME]
	push dword[return_value]
	call tsValue_set
	add esp, 8
	
	
	;set window resize callback
	push gameLoop_windowResizeCallback
	push dword[current_window]
	call [glfwSetFramebufferSizeCallback]
	add esp, 8
	
	mov dword[should_resize], 69
	
	;hide cursor
	push 69
	push dword[current_window]
	call input_hideCursor
	add esp, 8
	
	;init perlin noises
	push 100
	call perlin_init2d
	call perlin_init3d
	add esp, 4
	
	;init physics
	call physics4d_init
	
	;init camera
	push camera
	call camera_init
	add esp, 4
	
	;init renderable
	call renderable_init
	
	;init text renderer
	call textRenderer_init
	
	;init texture handler
	call textureHandler_init
	
	;init pp
	push dword[RENDER_HEIGHT]
	push dword[RENDER_WIDTH]
	call postProcessing_init
	add esp, 8
	
	;init ui
	call uiElement_init
	
	;create info canvas
	call gameLoop_initInfoCanvas
	
	;create framebuffers
	call gameLoop_createFramebuffers
	
	;create chunk manager 4d
	call chunkManager4d_create
	mov dword[chunk_manager_4d], eax
	
	;create player
	push dword[chunk_manager_4d]
	push camera
	call player_init
	mov dword[pplayer], eax
	add esp, 8
	
	;init sun
	call sun_init
	
	;init memory usage diagram
	call memoryUsageDiagram_init
	
	;enable depth test and face cull
	push dword[GL_DEPTH_TEST]
	call [glEnable]
	
	push dword[GL_CCW]
	call [glFrontFace]
	push dword[GL_CULL_FACE]
	call [glEnable]
	
	;audio things
	push music_path
	call audio_loadSound
	mov dword[sound_music], eax
	add esp, 4
	
	push 100000000
	push eax
	call audio_playSound
	add esp, 8
	
	;init last frame time
	call [GetTickCount]
	mov dword[last_frame_milliseconds], eax
	
	;start the physics thread
	push 69					;start immediately
	push 0
	push gameLoop_physics
	call thread_create
	mov dword[physics_thread], eax
	add esp, 12
	
	;start the chunk loader thread
	push 69
	push 0
	push gameLoop_chunkLoader
	call thread_create
	mov dword[chunkLoader_thread], eax
	add esp, 12
	
	;the actual game loop
	gameLoop_main_loop_start:
		
		;calculate delta time
		call [GetTickCount]
		mov ecx, dword[last_frame_milliseconds]
		
		mov dword[last_frame_milliseconds], eax
		sub eax, ecx
		mov dword[delta_time_milliseconds], eax
		
		fild dword[delta_time_milliseconds]
		fld dword[ONE_PER_THOUSAND]
		fmulp
		fstp dword[delta_time_seconds]
		
		;update fps counter
		inc dword[frames_in_this_second]
		
		mov eax, dword[delta_time_milliseconds]
		add dword[milliseconds_since_last_fps_update], eax
		cmp dword[milliseconds_since_last_fps_update], 1000
		jl gameLoop_main_loop_no_fps_update
			mov eax, dword[frames_in_this_second]
			mov dword[frames_in_last_second], eax
			
			mov dword[frames_in_this_second], 0
			sub dword[milliseconds_since_last_fps_update], 1000
		gameLoop_main_loop_no_fps_update:
		
		;check if the window should be resized
		cmp dword[should_resize], 0
		je gameLoop_main_loop_no_resize
			mov dword[should_resize], 0
			call gameLoop_handleWindowResize
		gameLoop_main_loop_no_resize:
		
		;process inputs for ui
		call uiElement_processInput
		
		;process a chunk graphics update 4d
		mov ebx, 5
		gameLoop_main_graphics_update_loop_start:
			push dword[chunk_manager_4d]
			call chunkManager4d_processGraphicsUpdate
			add esp, 4
			
			dec ebx
			jz gameLoop_main_graphics_update_loop_end
			test eax, eax
			jnz gameLoop_main_graphics_update_loop_start
		gameLoop_main_graphics_update_loop_end:
		
		;update time of day
		movss xmm0, dword[delta_time_seconds]
		movss xmm1, dword[TIME_COEFFICIENT]
		mulss xmm0, xmm1
		movss xmm1, dword[TIME_OF_DAY]
		addss xmm0, xmm1
		ucomiss xmm0, dword[ONE]
		jbe gameLoop_main_loop_time_no_overflow
			movss xmm1, dword[ONE]
			subss xmm0, xmm1
		gameLoop_main_loop_time_no_overflow:
		movss dword[TIME_OF_DAY], xmm0

		;update player
		push dword[delta_time_seconds]
		push dword[pplayer]
		call player_update
		add esp, 8
		
		;get sun direction
		push SUN_DIRECTION_BUFFER
		call sun_getDirection
		add esp, 4
		
		push SUN_DIRECTION_BUFFER
		push SUN_DIRECTION_BUFFER
		push dword[chunk_manager_4d]
		call chunkManager4d_getHyperPlane
		mov dword[esp], eax
		call hyperPlane_directionTo3d
		add esp, 12
		
		;get camera view, projection and pv matrix
		push view_matrix
		push camera
		call camera_view
		
		push projection_matrix
		push camera
		call camera_projection
		
		push pv_matrix
		push camera
		call camera_viewProjection
		add esp, 24
		
		;update memory diagram if necessary
		mov eax, dword[delta_time_milliseconds]
		add dword[milliseconds_since_last_memory_diagram_update], eax
		cmp dword[milliseconds_since_last_memory_diagram_update], 500
		jl gameLoop_main_loop_no_memory_diagram_update
			call memoryUsageDiagram_update
			sub dword[milliseconds_since_last_memory_diagram_update], 500
		gameLoop_main_loop_no_memory_diagram_update:
		
		;do the deferred rendering things--------------------------
		
		;set the viewport
		push dword[RENDER_HEIGHT]
		push dword[RENDER_WIDTH]
		push 0
		push 0
		call [glViewport]
		
		;clear the framebuffers
		call gameLoop_clearFramebuffers
		
		;bind the gbuffer and set viewport
		push dword[framebuffer_gbuffer]
		call framebuffer_bind
		add esp, 4
		
		;enable depth test and disable blending
		push 69
		call renderable_enableDepthTest
		push 0
		call renderable_enableBlending
		add esp, 8
		
		;render sun (this should be drawn first)
		fld dword[TIME_OF_DAY]
		fmul dword[D360]
		sub esp, 4
		fstp dword[esp]
		call sun_setAngle
		add esp, 4
		
		
		mov eax, dword[pplayer]
		push dword[eax+24]
		push dword[chunk_manager_4d]
		call chunkManager4d_getHyperPlane
		mov dword[esp], eax
		push pv_matrix
		;call sun_render
		add esp, 12
		
		;render 4d chunks
		push projection_matrix
		push view_matrix
		push dword[chunk_manager_4d]
		call chunkManager4d_render
		add esp, 12
		
		
		
		;bind the ssao fbo
		push dword[framebuffer_ssao]
		call framebuffer_bind
		add esp, 4
		
		;do ssao
		push projection_matrix
		push view_matrix
		push dword[framebuffer_gbuffer]
		push dword[framebuffer_ssao]
		call postProcessing_ssao
		add esp, 16
		
		
		;bind the post processing fbo
		push dword[framebuffer_pp]
		call framebuffer_bind
		add esp, 4
		
		;copy the depth buffer
		push dword[framebuffer_gbuffer]
		push dword[framebuffer_pp]
		call framebuffer_copyDepthBuffer
		add esp, 8
		
		;do the deferred shading part
		push view_matrix
		push SUN_DIRECTION_BUFFER
		push dword[framebuffer_ssao]
		push dword[framebuffer_gbuffer]
		push dword[framebuffer_pp]
		call postProcessing_deferredLighting
		add esp, 20
		
		;do the forward rendering things--------------------------
		
		;enable depth test
		push 69
		call renderable_enableDepthTest
		add esp, 4
		
		;draw the raycast hypercube
		push pv_matrix
		push dword[pplayer]
		call player_drawRaycastHypercube
		add esp, 8
		
		
		;set viewport
		push dword[WINDOW_SIZE_Y]
		push dword[WINDOW_SIZE_X]
		push 0
		push 0
		call [glViewport]

		;draw the render framebuffer to the screen
		push dword[framebuffer_pp]
		call postProcessing_drawToScreen
		add esp, 4
		
		;disable depth test and enable blending
		push 0
		call renderable_enableDepthTest
		push 69
		call renderable_enableBlending
		add esp, 8
		
		;render ui
		push dword[WINDOW_SIZE_Y]
		push dword[WINDOW_SIZE_X]
		push projection_matrix_ui
		call uiElement_createProjection
		add esp, 12
		
		call gameLoop_updateInfoCanvas
		
		push projection_matrix_ui
		call uiElement_render
		add esp, 4
		
		
		;enable depth test and disable blending
		push 69
		call renderable_enableDepthTest
		push 0
		call renderable_enableBlending
		add esp, 8
		
		;swap buffers
		push dword[current_window]
		call [glfwSwapBuffers]
		add esp, 4

		;poll events and update input
		call [glfwPollEvents]
		call input_update
		

		;check if the user is trying to escape
		push dword[GLFW_KEY_ESCAPE]
		call input_keyReleased
		add esp, 4
		test eax, eax
		jz gameLoop_main_loop_no_escape
			push dword[GAME_STATE_MENU]
			push dword[return_value]
			call tsValue_set
			add esp, 8
		gameLoop_main_loop_no_escape:
		
		push dword[current_window]
		call [glfwWindowShouldClose]
		add esp, 4
		test eax, eax
		jz gameLoop_main_loop_no_escape2
			push dword[GAME_STATE_DEINIT]
			push dword[return_value]
			call tsValue_set
			add esp, 8
		gameLoop_main_loop_no_escape2:
		
		;check if the window is closed or not
		push dword[GAME_STATE_INGAME]
		push dword[return_value]
		call tsValue_isEqual
		add esp, 8
		test eax, eax
		jnz gameLoop_main_loop_start


	
	;wait for the other threads
	push -1
	push dword[physics_thread]
	call thread_join
	add esp, 8
	
	push -1
	push dword[chunkLoader_thread]
	call thread_join
	add esp, 8
	
	;yeet sounds
	push dword[sound_music]
	call audio_stopSound
	call audio_unloadSound
	add esp, 4
	
	;destroy chunk manager
	push dword[chunk_manager_4d]
	;call chunkManager4d_destroy
	mov dword[chunk_manager_4d], 0
	
	;deinit memory usage diagram
	call memoryUsageDiagram_deinit
	
	;deinit sun
	call sun_deinit
	
	;destroy player
	push dword[pplayer]
	call player_destroy
	add esp, 4
	
	;destroy the framebuffers
	call gameLoop_yeetFramebuffers
	
	;deinit ui
	call uiElement_deinit
	
	;deinit pp
	call postProcessing_deinit
	
	;deinit texture handler
	call textureHandler_deinit
	
	;deinit text renderer
	call textRenderer_deinit
	
	;deinit renderable
	call renderable_deinit
	
	;deinit physics
	call physics4d_deinit
	
	;deinit perlin noise
	call perlin_deinit3d
	call perlin_deinit2d
	
	;unset window resize callback
	push 0
	push dword[current_window]
	call [glfwSetFramebufferSizeCallback]
	add esp, 8
	
	;let go of cursor
	push 0
	push dword[current_window]
	call input_hideCursor
	add esp, 8
	
	;save return value
	lea eax, [ebp-4]
	push eax
	push dword[return_value]
	call tsValue_get
	add esp, 8
	
	;destroy ts values
	push dword[return_value]
	call tsValue_destroy
	add esp, 4
	
	
	mov dword[current_window], 0
	
	;gg
	push message_deinit_successful
	call my_printf
	add esp, 4
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
;void gameLoop_physics
gameLoop_physics:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;last tick(ms) count		;4
	sub esp, 4			;current tick(ms) count		;8
	sub esp, 4			;0.001f*(current-last)		;12
	
	finit
	
	;reset last and current tick count
	call [GetTickCount]
	mov dword[ebp-4], eax
	mov dword[ebp-8], eax
	
	gameLoop_physics_loop_start:
		;check if enough time has elapsed since the last update
		call [GetTickCount]
		sub eax, dword[ebp-8]
		cmp eax, dword[PHYSICS_UPDATE_INTERVAL_MS]
		jl gameLoop_physics_loop_start
		
		;calculate the delta time
		mov eax, dword[ebp-8]
		mov dword[ebp-4], eax
		
		call [GetTickCount]
		mov dword[ebp-8], eax
		
		mov eax, dword[ebp-8]
		sub eax, dword[ebp-4]
		mov dword[ebp-12], eax
		fild dword[ebp-12]
		fstp dword[ebp-12]
		movss xmm0, dword[ebp-12]
		movss xmm1, dword[ONE_PER_THOUSAND]
		mulss xmm0, xmm1
		movss dword[ebp-12], xmm0
		
		;call physics_update
		push dword[ebp-12]
		call physics4d_update
		add esp, 4
		
		;update player
		push dword[ebp-12]
		push dword[pplayer]
		call player_updatePhysics
		add esp, 8
		
		;update the displayed delta time
		call [GetTickCount]
		sub eax, dword[ebp-8]
		mov dword[delta_time_milliseconds_physics], eax
		
		;check if an exit is necessary
		push dword[GAME_STATE_INGAME]
		push dword[return_value]
		call tsValue_isEqual
		add esp, 8
		test eax, eax
		jnz gameLoop_physics_loop_start
	
	mov esp, ebp
	pop ebp
	ret
	
	
gameLoop_chunkLoader:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;last chunk update
	
	mov dword[ebp-4], 0
	
	finit

	gameLoop_chunkLoader_loop_start:
		;check if it is already chunk load time
		call [GetTickCount]
		mov ecx, eax
		sub ecx, dword[ebp-4]
		cmp ecx, 50
		jb gameLoop_chunk_loader_loop_no_load
			mov dword[ebp-4], eax			;update the last chunk update time
			
			;reload chunks if necessary
			push dword[chunk_manager_4d]
			call chunkManager4d_processChangedBlocks
			add esp, 4
		
			;do chunk update things		
			mov eax, dword[pplayer]
			mov eax, dword[eax]				;&player.camera.position
			push dword[render_distance]
			push eax
			push dword[chunk_manager_4d]
			call chunkManager4d_load
			call chunkManager4d_unload
			add esp, 12
			
			push 5
			push dword[chunk_manager_4d]
			call chunkManager4d_processPendingChunkReloads
			add esp, 8
			
			;set the displayed delta time
			call [GetTickCount]
			sub eax, dword[ebp-4]
			mov dword[delta_time_milliseconds_chunk_loader], eax
		
		gameLoop_chunk_loader_loop_no_load:
		
		;check if an exit is necessary
		push dword[GAME_STATE_INGAME]
		push dword[return_value]
		call tsValue_isEqual
		add esp, 8
		test eax, eax
		jnz gameLoop_chunkLoader_loop_start
	
	mov esp, ebp
	pop ebp
	ret
	

	
;only sets the window size and the should_resize flag
;therefore only triggering handleWindowResize once per frame at most
gameLoop_windowResizeCallback:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	cmp eax, dword[current_window]
	jne gameLoop_windowResizeCallback_end
	
		mov eax, dword[ebp+12]
		mov dword[WINDOW_SIZE_X], eax
		mov eax, dword[ebp+16]
		mov dword[WINDOW_SIZE_Y], eax
		
		mov dword[should_resize], 69
	
	gameLoop_windowResizeCallback_end:
	mov esp, ebp
	pop ebp
	ret
	
	

;void gameLoop_createFramebuffers()
gameLoop_createFramebuffers:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;is there a problem?		4
	
	mov dword[ebp-4], 0
	
	
	;create post processing framebuffer
	push dword[RENDER_HEIGHT]
	push dword[RENDER_WIDTH]
	call framebuffer_create
	mov dword[framebuffer_pp], eax
	add esp, 4

	push 0
	push FRAMEBUFFER_RGB
	push dword[framebuffer_pp]
	call framebuffer_colourAttachment
	call framebuffer_depthAttachment
	call framebuffer_isComplete
	add dword[ebp-4], eax
	add esp, 12
	
	;create the gbuffer framebuffer
	push dword[RENDER_HEIGHT]
	push dword[RENDER_WIDTH]
	call framebuffer_create
	mov dword[framebuffer_gbuffer], eax
	add esp, 4
	
	push 0
	push FRAMEBUFFER_RGBA16F
	push dword[framebuffer_gbuffer]
	call framebuffer_colourAttachment			;colour attachment 0 is the position texture (vec4)
	add esp, 12
	
	push 1
	push FRAMEBUFFER_RGB16F
	push dword[framebuffer_gbuffer]
	call framebuffer_colourAttachment			;colour attachment 1 is the normal texture (vec3)
	add esp, 12
	
	push 2
	push FRAMEBUFFER_RGB
	push dword[framebuffer_gbuffer]
	call framebuffer_colourAttachment			;colour attachment 2 is the albedo texture (vec3)
	add esp, 12
	
	push dword[framebuffer_gbuffer]
	call framebuffer_depthAttachment
	add esp, 4
	
	push dword[framebuffer_gbuffer]
	call framebuffer_isComplete
	add dword[ebp-4], eax
	add esp, 4
	
	;create the ssao framebuffer
	push dword[RENDER_HEIGHT]
	push dword[RENDER_WIDTH]
	call framebuffer_create
	mov dword[framebuffer_ssao], eax
	add esp, 4
	
	push 0
	push FRAMEBUFFER_RED
	push dword[framebuffer_ssao]
	call framebuffer_colourAttachment
	call framebuffer_isComplete
	add dword[ebp-4], eax
	add esp, 12
	
	;print error message if error
	test dword[ebp-4], 0xffffffff
	jnz gameLoop_createFramebuffers_no_error
		push error_incomplete_framebuffer
		call my_printf
		add esp, 4
		
	gameLoop_createFramebuffers_no_error:
	
	mov esp, ebp
	pop ebp
	ret
	
	
;void gameLoop_yeetFramebuffers()
gameLoop_yeetFramebuffers:
	push ebp
	mov ebp, esp
	
	push dword[framebuffer_pp]
	call framebuffer_destroy
	add esp, 4
	
	push dword[framebuffer_gbuffer]
	call framebuffer_destroy
	add esp, 4
	
	push dword[framebuffer_ssao]
	call framebuffer_destroy
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	

;doesn't set the viewport to the render size
;void gameLoop_clearFramebuffers()
gameLoop_clearFramebuffers:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT		4
	
	;precalcute the helper value
	mov eax, dword[GL_COLOR_BUFFER_BIT]
	or eax, dword[GL_DEPTH_BUFFER_BIT]
	mov dword[ebp-4], eax
	
	;set the clear depth
	push 0x3f800000
	call dword[glClearDepthf]
	
	;clear the framebuffers with colour=(0,0,0,0)
	push 0
	push 0
	push 0
	push 0
	call [glClearColor]
	
	
	push dword[framebuffer_gbuffer]
	call framebuffer_bind
	add esp, 4
	
	push dword[ebp-4]
	call [glClear]
	
	
	push dword[framebuffer_ssao]
	call framebuffer_bind
	add esp, 4
	
	push dword[ebp-4]
	call [glClear]
	
	
	;clear the framebuffers with colour=sky colour
	sub esp, 16
	mov eax, esp
	push eax
	push dword[TIME_OF_DAY]
	call sky_getColour
	add esp, 8
	call [glClearColor]
	
	push dword[framebuffer_pp]
	call framebuffer_bind
	add esp, 4
	
	push dword[ebp-4]
	call [glClear]
	
	mov esp, ebp
	pop ebp
	ret
	

;void gameLoop_handleWindowResize()
gameLoop_handleWindowResize:
	push ebp
	mov ebp, esp
	
	;tell it to the text renderer
	push dword[WINDOW_SIZE_Y]
	push dword[WINDOW_SIZE_X]
	call textRenderer_setScreenSize
	add esp, 8
	
	;change the camera's aspect ratio
	cmp dword[WINDOW_SIZE_Y], 0
	je gameLoop_handleWindowResize_y_zero
		fild dword[WINDOW_SIZE_X]
		fild dword[WINDOW_SIZE_Y]
		fdivp
		mov eax, camera
		fstp dword[eax+32]
		jmp gameLoop_handleWindowResize_cum_aspect_done
	gameLoop_handleWindowResize_y_zero:
		mov eax, camera
		mov dword[eax+32], 0
	gameLoop_handleWindowResize_cum_aspect_done:
	
	;change viewport
	push dword[WINDOW_SIZE_Y]
	push dword[WINDOW_SIZE_X]
	push 0
	push 0
	call [glViewport]
	
	gameLoop_handleWindowResize_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
	extern uiElement_create
	extern uiElement_destroy
	extern uiElement_setStatus
	extern uiElement_setOnClick
	extern uiElement_setPosition
	extern uiElement_setSize
	extern uiElement_setParent
	extern uiElement_setAnchor
	extern uiElement_setPivot
	extern uiElement_createProjection
	extern uiImage_setTexture
	extern uiImage_setTextureGL
	extern uiText_setText
	extern uiText_setColour
	extern uiText_setFontSize
	extern uiText_setTextAlignment
	extern UI_CANVAS
	extern UI_IMAGE
	extern UI_TEXT
	extern UI_LEFT
	extern UI_BOTTOM
	extern UI_CENTER
	extern UI_RIGHT
	extern UI_TOP
	extern UI_TEXT_ALIGN_LEFT
	extern UI_TEXT_ALIGN_RIGHT
	extern UI_TEXT_ALIGN_TOP
	extern UI_TEXT_ALIGN_BOTTOM
	
%macro INIT_IMAGE 11	;image, parent, imagePath, posx, posy, scalex, scaley, anchorx, anchory, pivotx, pivoty
	push dword[UI_IMAGE]
	call uiElement_create
	mov dword[%1], eax
	add esp, 4
	
	push dword[%2]
	push dword[%1]
	call uiElement_setParent
	add esp, 8
	
	push %5
	push %4
	push dword[%1]
	call uiElement_setPosition
	add esp, 12
	
	push %7
	push %6
	push dword[%1]
	call uiElement_setSize
	add esp, 12
	
	push word[%9]
	push word[%8]
	push dword[%1]
	call uiElement_setAnchor
	add esp, 8
	
	push word[%11]
	push word[%10]
	push dword[%1]
	call uiElement_setPivot
	add esp, 8
	
	push %3
	push dword[%1]
	call uiImage_setTexture
	add esp, 8
%endmacro
	
%macro INIT_TEXT 6 ;text, parent, posx, posy, anchorx, anchory, textalignx, textaligny
	push dword[UI_TEXT]
	call uiElement_create
	mov dword[%1], eax
	add esp, 4
	
	push dword[%2]
	push dword[%1]
	call uiElement_setParent
	add esp, 8
	
	push 0
	push 0
	push dword[%1]
	call uiElement_setSize
	add esp, 12
	
	push %4
	push %3
	push dword[%1]
	call uiElement_setPosition
	add esp, 12
	
	push word[%6]
	push word[%5]
	push dword[%1]
	call uiElement_setAnchor
	add esp, 8
%endmacro

%macro FINE_TUNE_TEXT 10	;textElement, text, textalignx, textaligny, fontsizex, fontsizey, colourr, colourg, colourb, coloura
	push %2
	push dword[%1]
	call uiText_setText
	add esp, 8
	
	push word[%4]
	push word[%3]
	push dword[%1]
	call uiText_setTextAlignment
	add esp, 8
	
	push %6
	push %5
	push dword[%1]
	call uiText_setFontSize
	add esp, 12
	
	push %10
	push %9
	push %8
	push %7
	push dword[%1]
	call uiText_setColour
	add esp, 20
%endmacro

%macro SET_TEXT 1		;textElement
	lea eax, [ebp-100]
	push eax
	push dword[%1]
	call uiText_setText
	add esp, 8
%endmacro

	
;void gameLoop_initInfoCanvas()
gameLoop_initInfoCanvas:
	push ebp
	mov ebp, esp
	
	sub esp, 100			;buffer		100
	
	;create canvas
	push dword[UI_CANVAS]
	call uiElement_create
	mov dword[CANVAS_INFO], eax
	add esp, 4
	
	;create cursor
	INIT_IMAGE IMAGE_CURSOR, CANVAS_INFO, cursor_image_path, 0, 0, 80, 100, UI_CENTER, UI_CENTER, UI_LEFT, UI_CENTER
	
	;create texts
	INIT_TEXT 		TEXT_HYPERPLANE_POINT_LABEL, CANVAS_INFO, 30, 30, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_HYPERPLANE_POINT_LABEL, text_point, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_HYPERPLANE_POINT, CANVAS_INFO, 30, 45, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_HYPERPLANE_POINT, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	
	INIT_TEXT 		TEXT_HYPERPLANE_VECTOR_LABEL, CANVAS_INFO, 30, 70, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_HYPERPLANE_VECTOR_LABEL, text_based_vectors, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT 		TEXT_HYPERPLANE_VECTOR_1, CANVAS_INFO, 30, 85, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_HYPERPLANE_VECTOR_1, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT 		TEXT_HYPERPLANE_VECTOR_2, CANVAS_INFO, 30, 100, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_HYPERPLANE_VECTOR_2, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT 		TEXT_HYPERPLANE_VECTOR_3, CANVAS_INFO, 30, 115, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_HYPERPLANE_VECTOR_3, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	
	
	INIT_TEXT		TEXT_PLAYER_POSITION_LABEL, CANVAS_INFO, 30, 135, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_PLAYER_POSITION_LABEL, text_player_pos_4d, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_PLAYER_POSITION, CANVAS_INFO, 30, 150, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_PLAYER_POSITION, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_PLAYER_POSITION_3D_LABEL, CANVAS_INFO, 30, 170, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_PLAYER_POSITION_3D_LABEL, text_player_pos, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_PLAYER_POSITION_3D, CANVAS_INFO, 30, 185, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_PLAYER_POSITION_3D, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	
	
	INIT_TEXT		TEXT_VIEW_DIRECTION_3D_LABEL, CANVAS_INFO, 30, 205, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_VIEW_DIRECTION_3D_LABEL, text_player_view_dir, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_VIEW_DIRECTION_3D, CANVAS_INFO, 30, 220, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_VIEW_DIRECTION_3D, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	
	
	INIT_TEXT		TEXT_RAYCAST_HIT, CANVAS_INFO, 30, 240, UI_LEFT, UI_TOP
	FINE_TUNE_TEXT	TEXT_RAYCAST_HIT, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_TOP, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	
	
	
	
	INIT_TEXT		TEXT_FPS, CANVAS_INFO, 30, 30, UI_RIGHT, UI_TOP
	FINE_TUNE_TEXT	TEXT_FPS, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_TOP, 12, 16, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_PHYSICS_DELTA, CANVAS_INFO, 30, 55, UI_RIGHT, UI_TOP
	FINE_TUNE_TEXT	TEXT_PHYSICS_DELTA, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_TOP, 12, 16, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_CHUNK_LOADER_DELTA, CANVAS_INFO, 30, 80, UI_RIGHT, UI_TOP
	FINE_TUNE_TEXT	TEXT_CHUNK_LOADER_DELTA, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_TOP, 12, 16, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_MEMORY_USAGE, CANVAS_INFO, 30, 105, UI_RIGHT, UI_TOP
	FINE_TUNE_TEXT	TEXT_MEMORY_USAGE, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_TOP, 12, 16, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_IMAGE 		IMAGE_MEMORY_USAGE, CANVAS_INFO, 0, 30, 130, 200, 50, UI_RIGHT, UI_TOP, UI_RIGHT, UI_TOP
	
	
	INIT_TEXT		TEXT_RENDER_DISTANCE, CANVAS_INFO, 30, 130, UI_RIGHT, UI_BOTTOM
	FINE_TUNE_TEXT	TEXT_RENDER_DISTANCE, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_BOTTOM, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_LOADED_CHUNKS, CANVAS_INFO, 30, 105, UI_RIGHT, UI_BOTTOM
	FINE_TUNE_TEXT	TEXT_LOADED_CHUNKS, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_BOTTOM, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_FANTHOM_CHUNKS, CANVAS_INFO, 30, 80, UI_RIGHT, UI_BOTTOM
	FINE_TUNE_TEXT	TEXT_FANTHOM_CHUNKS, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_BOTTOM, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_PENDING_GRAPHICS_UPDATES, CANVAS_INFO, 30, 55, UI_RIGHT, UI_BOTTOM
	FINE_TUNE_TEXT	TEXT_PENDING_GRAPHICS_UPDATES, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_BOTTOM, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	INIT_TEXT		TEXT_PENDING_CHUNK_RELOADS, CANVAS_INFO, 30, 30, UI_RIGHT, UI_BOTTOM
	FINE_TUNE_TEXT	TEXT_PENDING_CHUNK_RELOADS, 0, UI_TEXT_ALIGN_RIGHT, UI_TEXT_ALIGN_BOTTOM, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	
	
	
	INIT_TEXT		TEXT_GPU, CANVAS_INFO, 30, 30, UI_LEFT, UI_BOTTOM
	FINE_TUNE_TEXT	TEXT_GPU, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_BOTTOM, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	push dword[GL_RENDERER]
	call [glGetString]
	test eax, eax
	jz gameLoop_initInfoCanvas_no_gpu_type
	push eax
	push dword[GL_VENDOR]
	call [glGetString]
	test eax, eax
	jz gameLoop_initInfoCanvas_no_gpu_type
		push eax
		push print_gpu_type
		lea ecx, [ebp-100]
		push ecx
		call my_sprintf
		add esp, 16
		SET_TEXT TEXT_GPU
	gameLoop_initInfoCanvas_no_gpu_type:
	
	INIT_TEXT		TEXT_VERSION, CANVAS_INFO, 30, 55, UI_LEFT, UI_BOTTOM
	FINE_TUNE_TEXT	TEXT_VERSION, 0, UI_TEXT_ALIGN_LEFT, UI_TEXT_ALIGN_BOTTOM, 9, 12, dword[ONE], dword[ONE], dword[ONE], dword[ONE]
	mov byte[ebp-100], 0
	push dword[GL_VERSION]
	call [glGetString]
	test eax, eax
	jz gameLoop_initInfoCanvas_no_version
		push eax
		push print_opengl_version
		lea ecx, [ebp-100]
		push ecx
		call my_sprintf
		add esp, 12
		SET_TEXT TEXT_VERSION
	gameLoop_initInfoCanvas_no_version:
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
gameLoop_updateInfoCanvas:
	push ebp
	mov ebp, esp
	
	sub esp, 100				;char buffer[100]
	
	;hyperplane point
	mov eax, dword[chunk_manager_4d]
	add eax, 100
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	
	SET_TEXT TEXT_HYPERPLANE_POINT
	
	
	;hyperplane vectors
	mov eax, dword[chunk_manager_4d]
	add eax, 116
	sub esp, 48
	mov ecx, esp
	push 48
	push eax
	push ecx
	call my_memcpy
	add esp, 12
	
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	SET_TEXT TEXT_HYPERPLANE_VECTOR_1
	
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	SET_TEXT TEXT_HYPERPLANE_VECTOR_2
	
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	SET_TEXT TEXT_HYPERPLANE_VECTOR_3
	
	
	;player positions
	mov eax, dword[pplayer]
	push dword[eax+24]
	call aabb4d_getPosition
	add esp, 4
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	SET_TEXT TEXT_PLAYER_POSITION
	
	mov eax, camera
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push print_vec3
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 20
	SET_TEXT TEXT_PLAYER_POSITION_3D
	
	;view direction
	sub esp, 12
	mov eax, esp
	push eax
	push camera
	call camera_forward
	add esp, 8
	push print_vec3
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 20
	SET_TEXT TEXT_VIEW_DIRECTION_3D
	
	;raycast hit
	mov eax, dword[pplayer]
	cmp dword[eax+56], 0
	jne gameLoop_updateInfoCanvas_raycast_hit
		;no hit
		push print_raycast_no_hit_info
		push dword[TEXT_RAYCAST_HIT]
		call uiText_setText
		add esp, 8
		jmp gameLoop_updateInfoCanvas_raycast_done
		
	gameLoop_updateInfoCanvas_raycast_hit:
		mov eax, dword[eax+56]
		push dword[eax+12]
		push dword[eax+8]
		push dword[eax+4]
		push dword[eax]
		push print_raycast_hit_info
		lea eax, [ebp-100]
		push eax
		call my_sprintf
		add esp, 24
		
		SET_TEXT TEXT_RAYCAST_HIT
	
	gameLoop_updateInfoCanvas_raycast_done:
	
	
	;fps
	push dword[frames_in_last_second]
	push print_fps
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_FPS
	
	;physics delta
	push dword[delta_time_milliseconds_physics]
	push print_physics_delta_time
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_PHYSICS_DELTA
	
	;chunk loader delta
	push dword[delta_time_milliseconds_chunk_loader]
	push print_chunk_loader_delta_time
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_CHUNK_LOADER_DELTA
	
	;memory usage things
	call meminfo_getMemoryUsage
	shr eax, 20
	push eax
	push print_memory_usage
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_MEMORY_USAGE
	
	call memoryUsageDiagram_getTexture
	push eax
	push dword[IMAGE_MEMORY_USAGE]
	call uiImage_setTextureGL
	
	
	;render distance
	push dword[render_distance]
	push print_render_distance
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_RENDER_DISTANCE
	
	;loaded chunks
	push dword[chunk_manager_4d]
	call tsVector_sizeNonBlocking
	mov dword[esp], eax
	push print_loaded_chunk_count
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_LOADED_CHUNKS
	
	;fanthom chunks
	mov eax, dword[chunk_manager_4d]
	add eax, 28
	push eax
	call tsVector_sizeNonBlocking
	mov dword[esp], eax
	push print_fanthom_chunk_count
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_FANTHOM_CHUNKS
	
	;pending graphics updates
	mov eax, dword[chunk_manager_4d]
	add eax, 36
	push eax
	call tsQueue_sizeNonBlocking
	mov dword[esp], eax
	push print_pending_graphics_update_count
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_PENDING_GRAPHICS_UPDATES
	
	;pending graphics updates
	mov eax, dword[chunk_manager_4d]
	add eax, 52
	push eax
	call queue_size
	mov dword[esp], eax
	push print_pending_chunk_reload_count
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	SET_TEXT TEXT_PENDING_CHUNK_RELOADS
	
	mov esp, ebp
	pop ebp
	ret