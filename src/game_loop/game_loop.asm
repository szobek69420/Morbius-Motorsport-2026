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
	
	RENDER_WIDTH dd 1920
	RENDER_HEIGHT dd 1200

	ZERO dd 0.0
	ONE dd 1.0
	MINUS_ONE dd -1.0
	ONE_PER_THOUSAND dd 0.001
	P15 dd 0.15
	P6 dd 0.6
	D360 dd 360.0
	
	PRETTY_YELLOW dd 1.0, 0.85, 0.0, 1.0
	BLACK dd 0.0, 0.0, 0.0, 1.0
	
	test_text db "OTTO VON BISMARCK",0
	test_text2 db "hello everybody my name is welcome",10,0
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_float db "%f",0
	print_float_nl db "%f",10,0
	print_four_floats db "%f, %f, %f, %f",0
	print_new_line db 10,0
	
	image_path db "./sprites/morbussin.bmp",0
	
	sound_path db "./sfx/battlecry.wav",0
	music_path db "./sfx/music.wav",0
	
	error_incomplete_framebuffer db "game_loop: L framebuffer",10,0
	
	test_text_main db "main",10,0
	test_text_physics db "physics",10,0
	
	text_point db "Hyperplane point",0
	text_based_vectors db "Hyperplane based vectors",0
	print_vec4 db "(%f; %f; %f; %f)",0
	text_player_pos_4d db "Player position",0
	text_player_pos db "Player position in plane",0
	print_vec3 db "(%f; %f; %f)",0
	
	print_loaded_chunk_count db "Loaded chunks: %d",0
	print_pending_graphics_update_count db "Pending graphics updates: %d",0
	print_render_distance db "Render distance: %d",0
	
	print_fps db "FPS: %d",0
	print_physics_delta_time db "Physics: %d ms",0
	print_chunk_loader_delta_time db "Chunk loader: %d ms",0
	
	print_raycast_hit_info db "Raycast hit: (%f; %f; %f; %f)",0
	print_raycast_no_hit_info db "Raycast hit: nothing bozo",0
	
	print_cursor db "+",0
	
section .bss use32
	should_close resb 4					;tsValue*
	physics_thread resb 4				;thread*
	chunkLoader_thread resb 4			;thread*

	camera resb 36
	pv_matrix resb 64
	
	hyperplane resb 64
	pplayer resb 4
	
	chunk_manager resb 4
	chunk_manager_4d resb 4
	
	framebuffer resb 4
	
section .data use32
	render_distance dd 4

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

	TIME_OF_DAY dd 0.0	;values are in [0;1], 0 and 1 are dawn

section .text use32

	dll_import kernel32.dll, GetTickCount
	
	
	global game_loop		;void game_loop(GLFWwindow* pwindow)
	
	extern glClear
	extern glClearColor
	extern glEnable
	extern glFrontFace
	extern glViewport
	extern glGetError
	
	extern GL_DEPTH_TEST
	extern GL_COLOR_BUFFER_BIT
	extern GL_DEPTH_BUFFER_BIT
	extern GL_CULL_FACE
	extern GL_CCW
	extern GL_POINTS

	
	extern camera_init
	extern camera_viewProjection
	
	extern my_printf
	extern my_sprintf
	
	extern my_memcpy
	
	extern glfwSwapBuffers
	extern glfwPollEvents
	extern glfwWindowShouldClose
	extern glfwSetWindowShouldClose
	extern glfwSetKeyCallback
	extern glfwSetMouseButtonCallback
	extern glfwSetCursorPosCallback
	extern glfwSetScrollCallback
	extern glfwSetInputMode
	extern glfwSetFramebufferSizeCallback
	extern glfwGetTime
	extern GLFW_CURSOR
	extern GLFW_CURSOR_DISABLED
	extern GLFW_KEY_ESCAPE
	
	extern input_init
	extern input_update
	extern input_keyReleased
	extern input_setMousePosition
	extern input_keyCallback
	extern input_mouseButtonCallback
	extern input_mouseMoveCallback
	extern input_mouseScrollCallback
	
	extern player_init
	extern player_destroy
	extern player_update
	extern player_updatePhysics
	extern player_drawRaycastHypercube
	
	extern hyperPlane_create
	
	extern renderable_init
	extern renderable_deinit
	extern renderable_create
	extern renderable_destroy
	extern renderable_render
	extern renderable_setAlbedo
	extern renderable_setPosition
	extern RENDERABLE_ATTRIB_P3
	extern RENDERABLE_ATTRIB_P3UV2
	
	extern vector_init
	extern vector_destroy
	extern vector_clear
	
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
	extern tsValue_set
	extern tsValue_isEqual
	
	extern audio_loadSound
	extern audio_unloadSound
	extern audio_playSound
	
	extern framebuffer_create
	extern framebuffer_destroy
	extern framebuffer_colourAttachment0
	extern framebuffer_depthAttachment
	extern framebuffer_isComplete
	extern framebuffer_bind
	extern FRAMEBUFFER_RGBA
	
	extern postProcessing_init
	extern postProcessing_deinit
	extern postProcessing_drawToScreen
	
	extern chunkManager_create
	extern chunkManager_load
	extern chunkManager_unload
	extern chunkManager_processUpdate
	extern chunkManager_processGraphicsUpdate
	extern chunkManager_render
	
	extern chunkManager4d_create
	extern chunkManager4d_load
	extern chunkManager4d_unload
	extern chunkManager4d_processUpdate
	extern chunkManager4d_processGraphicsUpdate
	extern chunkManager4d_processChangedBlock
	extern chunkManager4d_render
	extern chunkManager4d_getHyperPlane
	
	extern sun_init
	extern sun_deinit
	extern sun_render
	extern sun_setAngle
	extern sun_setDistance
	
	extern sky_getColour
	
game_loop:
	push ebp
	mov ebp, esp
	
	;save pwindow
	mov eax, dword[ebp+8]
	mov dword[current_window], eax
	
	;init should_close
	push 4
	call tsValue_create
	mov dword[should_close], eax
	add esp, 4
	
	push 0
	push dword[should_close]
	call tsValue_set
	add esp, 8
	
	
	;init input and set callbacks
	call gameLoop_initWindow
	
	;set window resize callback
	push gameLoop_windowResizeCallback
	push dword[current_window]
	call [glfwSetFramebufferSizeCallback]
	add esp, 8
	
	;hide cursor
	push dword[GLFW_CURSOR_DISABLED]
	push dword[GLFW_CURSOR]
	push dword[current_window]
	call [glfwSetInputMode]
	add esp, 12
	
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
	call postProcessing_init
	
	;create framebuffer
	push dword[RENDER_HEIGHT]
	push dword[RENDER_WIDTH]
	call framebuffer_create
	mov dword[framebuffer], eax
	add esp, 4
	
	push dword[FRAMEBUFFER_RGBA]
	push dword[framebuffer]
	call framebuffer_colourAttachment0
	call framebuffer_depthAttachment
	call framebuffer_isComplete
	add esp, 8
	
	test eax, eax
	jnz game_loop_framebuffer_gg
		;send error message (even though it will crash anyway skull emoji)
		push error_incomplete_framebuffer
		call my_printf
		add esp, 4
	game_loop_framebuffer_gg:
	
	;create hyperplane
	push hyperplane
	call hyperPlane_create
	add esp, 4
	
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
	add esp, 4
	
	push 100000000
	push eax
	;call audio_playSound
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
	gameLoop_loop_start:
		
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
		jl gameLoop_loop_no_fps_update
			mov eax, dword[frames_in_this_second]
			mov dword[frames_in_last_second], eax
			
			mov dword[frames_in_this_second], 0
			sub dword[milliseconds_since_last_fps_update], 1000
		gameLoop_loop_no_fps_update:
		
		;check if the window should be resized
		cmp dword[should_resize], 0
		je gameLoop_loop_no_resize
			mov dword[should_resize], 0
			call gameLoop_handleWindowResize
		gameLoop_loop_no_resize:
		
		;process a chunk graphics update 4d
		push dword[chunk_manager_4d]
		call chunkManager4d_processGraphicsUpdate
		add esp, 4
		
		;update time of day
		movss xmm0, dword[delta_time_seconds]
		movss xmm1, dword[TIME_COEFFICIENT]
		mulss xmm0, xmm1
		movss xmm1, dword[TIME_OF_DAY]
		addss xmm0, xmm1
		ucomiss xmm0, dword[ONE]
		jbe gameLoop_loop_time_no_overflow
			movss xmm1, dword[ONE]
			subss xmm0, xmm1
		gameLoop_loop_time_no_overflow:
		movss dword[TIME_OF_DAY], xmm0

		;update player
		push dword[delta_time_seconds]
		push dword[pplayer]
		call player_update
		add esp, 8
		
		;bind framebuffer and set viewport
		push dword[framebuffer]
		call framebuffer_bind
		add esp, 4
		
		push dword[RENDER_HEIGHT]
		push dword[RENDER_WIDTH]
		push 0
		push 0
		call [glViewport]
		
	
		;calculate and set clear color
		sub esp, 16
		mov eax, esp
		push eax
		push dword[TIME_OF_DAY]
		call sky_getColour
		add esp, 8
		call [glClearColor]
		
		
		;clear color and depth buffer bit
		mov eax, dword[GL_COLOR_BUFFER_BIT]
		or eax, dword[GL_DEPTH_BUFFER_BIT]
		push eax
		call [glClear]
		
		;get camera pv matrix
		push pv_matrix
		push camera
		call camera_viewProjection
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
		call sun_render
		add esp, 12
		
		;render 4d chunks
		push pv_matrix
		push dword[chunk_manager_4d]
		call chunkManager4d_render
		add esp, 8
		
		;draw the raycast hypercube
		push pv_matrix
		push dword[pplayer]
		call player_drawRaycastHypercube
		add esp, 8
		
		;bind the screen framebuffer and set viewport
		push 0
		call framebuffer_bind
		add esp, 4

		push dword[WINDOW_SIZE_Y]
		push dword[WINDOW_SIZE_X]
		push 0
		push 0
		call [glViewport]

		;draw the render framebuffer to the screen
		push dword[framebuffer]
		call postProcessing_drawToScreen
		add esp, 4
		
		;draw infos
		call gameLoop_drawData
		
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
		jz gameLoop_loop_no_escape
			push 69
			push dword[should_close]
			call tsValue_set
			add esp, 8
		gameLoop_loop_no_escape:
		
		;check if the window is closed or not
		push 0
		push dword[should_close]
		call tsValue_isEqual
		add esp, 8
		test eax, eax
		jnz gameLoop_loop_start


	
	;wait for the other threads
	push -1
	push dword[physics_thread]
	call thread_join
	add esp, 8
	
	push -1
	push dword[chunkLoader_thread]
	call thread_join
	add esp, 8
	
	;deinit sun
	call sun_deinit
	
	;destroy player
	push dword[pplayer]
	call player_destroy
	add esp, 4
	
	;destroy framebuffer
	push dword[framebuffer]
	call framebuffer_destroy
	add esp, 4
	
	;deinit texture handler
	call textureHandler_deinit
	
	;deinit text renderer
	call textRenderer_deinit
	
	;deinit renderable
	call renderable_deinit
	
	;deinit physics
	call physics4d_deinit
	
	;destroy should_close
	push dword[should_close]
	call tsValue_destroy
	add esp, 4
	
	
	mov dword[current_window], 0
	
	mov esp, ebp
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
		push 0
		push dword[should_close]
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
		jl gameLoop_chunk_loader_loop_no_load
		
			mov dword[ebp-4], eax			;update the last chunk update time
			
			;reload chunks if necessary
			push dword[chunk_manager_4d]
			call chunkManager4d_processChangedBlock
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
			
			;set the displayed delta time
			call [GetTickCount]
			sub eax, dword[ebp-4]
			mov dword[delta_time_milliseconds_chunk_loader], eax
		
		gameLoop_chunk_loader_loop_no_load:
		
		
		;check if an exit is necessary
		push 0
		push dword[should_close]
		call tsValue_isEqual
		add esp, 8
		test eax, eax
		jnz gameLoop_chunkLoader_loop_start
	
	mov esp, ebp
	pop ebp
	ret
	

gameLoop_initWindow:
	push ebp
	mov ebp, esp
	
	call input_init
	
	
	push input_keyCallback
	push dword[current_window]
	call [glfwSetKeyCallback]
	
	push input_mouseButtonCallback
	push dword[current_window]
	call [glfwSetMouseButtonCallback]
	
	push input_mouseMoveCallback
	push dword[current_window]
	call [glfwSetCursorPosCallback]
	
	push input_mouseScrollCallback
	push dword[current_window]
	call [glfwSetScrollCallback]
	
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
	
	
;void gameLoop_drawData()
gameLoop_drawData:
	push ebp
	mov ebp, esp
	
	sub esp, 100				;char buffer[100]
	
	;set font size to 1.5x
	mov eax, dword[FONT_CHAR_HEIGHT]
	imul eax, 3
	shr eax, 1
	push eax
	mov eax, dword[FONT_CHAR_WIDTH]
	imul eax, 3
	shr eax, 1
	push eax
	call textRenderer_setFontSize
	add esp, 8
	
	;set font colour to yellow
	mov eax, PRETTY_YELLOW
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	call textRenderer_setColour
	add esp, 16
	
	;draw point
	mov eax, dword[chunk_manager_4d]
	add eax, 32
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	
	render_text text_point, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 30
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 45
	
	;draw based vectors
	render_text text_based_vectors, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 70
	
	mov eax, dword[chunk_manager_4d]
	add eax, 48
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
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 85
	
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 100
	
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 115
	
	;draw player position 4d and 3d
	render_text text_player_pos_4d, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 135
	
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
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 150
	
	
	render_text text_player_pos, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 170
	
	mov eax, camera
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push print_vec3
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 20
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 185
	
	;draw raycast hit
	mov eax, dword[pplayer]
	cmp dword[eax+56], 0
	jne gameLoop_drawData_raycast_hit
		;no hit
		render_text print_raycast_no_hit_info, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 205
		jmp gameLoop_drawData_raycast_done
		
	gameLoop_drawData_raycast_hit:
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
		
		lea eax, [ebp-100]
		render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 205
	
	gameLoop_drawData_raycast_done:
	
	;draw render distance
	push dword[render_distance]
	push print_render_distance
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_BOTTOM_RIGHT], dword[TEXT_PIVOT_BOTTOM_RIGHT], 30, 80
	
	;draw loaded chunk count
	mov eax, dword[chunk_manager_4d]
	push dword[eax]
	push print_loaded_chunk_count
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_BOTTOM_RIGHT], dword[TEXT_PIVOT_BOTTOM_RIGHT], 30, 55
	
	;draw pending graphics update count
	mov eax, dword[chunk_manager_4d]
	mov eax, dword[eax+24]
	push dword[eax+4]
	push print_pending_graphics_update_count
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_BOTTOM_RIGHT], dword[TEXT_PIVOT_BOTTOM_RIGHT], 30, 30
	
	
	;set font size to 2x
	mov eax, dword[FONT_CHAR_HEIGHT]
	shl eax, 1
	push eax
	mov eax, dword[FONT_CHAR_WIDTH]
	shl eax, 1
	push eax
	call textRenderer_setFontSize
	add esp, 8
	
	
	;draw frame counter
	push dword[frames_in_last_second]
	push print_fps
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_RIGHT], dword[TEXT_PIVOT_TOP_RIGHT], 30, 30
	
	
	;print physics delta time
	push dword[delta_time_milliseconds_physics]
	push print_physics_delta_time
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_RIGHT], dword[TEXT_PIVOT_TOP_RIGHT], 30, 55
	
	
	;print chunk loader delta time
	push dword[delta_time_milliseconds_chunk_loader]
	push print_chunk_loader_delta_time
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 12
	
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_RIGHT], dword[TEXT_PIVOT_TOP_RIGHT], 30, 80
	
	;set font size to 4x
	mov eax, dword[FONT_CHAR_HEIGHT]
	shl eax, 2
	push eax
	mov eax, dword[FONT_CHAR_WIDTH]
	shl eax, 2
	push eax
	call textRenderer_setFontSize
	add esp, 8
	
	;set font colour to black
	mov eax, BLACK
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	call textRenderer_setColour
	add esp, 16
	
	;print cursor
	render_text print_cursor, dword[TEXT_ORIGIN_CENTER_CENTER], dword[TEXT_PIVOT_CENTER_CENTER], 0, 0
	
	
	mov esp, ebp
	pop ebp
	ret