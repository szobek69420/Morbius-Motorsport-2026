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

	ZERO dd 0.0
	ONE dd 1.0
	MINUS_ONE dd -1.0
	ONE_PER_THOUSAND dd 0.001
	P15 dd 0.15
	P6 dd 0.6
	
	test_text db "OTTO VON BISMARCK",0
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_float db "%f",0
	print_float_nl db "%f",10,0
	print_four_floats db "%f, %f, %f, %f",0
	print_new_line db 10,0
	
	image_path db "./sprites/morbussin.bmp",0
	
	test_text_main db "main",10,0
	test_text_physics db "physics",10,0
	
	text_point db "Hyperplane point",0
	text_based_vectors db "Hyperplane based vectors",0
	print_vec4 db "(%f; %f; %f; %f)",0
	
	vertex_data_vector:		;imitates a vector
	dd 120
	dd 120
	dd 4
	dd vertex_data
	vertex_data:
	dd -10.0, -1.0, 10.0, 0.0, 0.0,
	dd -10.0, 1.0, 10.0, 0.0, 1.0,
	dd 10.0, 1.0, 10.0, 1.0, 1.0,
	dd 10.0, -1.0, 10.0, 1.0, 0.0,
	dd -10.0, -1.0, 10.0, 0.0, 0.0,
	dd -10.0, 1.0, 10.0, 0.0, 1.0,
	dd -10.0, 1.0, -10.0, 1.0, 1.0,
	dd -10.0, -1.0, -10.0, 1.0, 0.0,
	dd 10.0, -1.0, -10.0, 1.0, 0.0,
	dd 10.0, 1.0, -10.0, 1.0, 1.0,
	dd -10.0, 1.0, -10.0, 0.0, 1.0,
	dd -10.0, -1.0, -10.0, 0.0, 0.0,
	dd 10.0, -1.0, -10.0, 1.0, 0.0,
	dd 10.0, 1.0, -10.0, 1.0, 1.0,
	dd 10.0, 1.0, 10.0, 0.0, 1.0,
	dd 10.0, -1.0, 10.0, 0.0, 0.0,
	dd -10.0, 1.0, 10.0, 0.0, 0.0,
	dd -10.0, 1.0, -10.0, 0.0, 1.0,
	dd 10.0, 1.0, -10.0, 1.0, 1.0,
	dd 10.0, 1.0, 10.0, 1.0, 0.0,
	dd 10.0, -1.0, 10.0, 1.0, 0.0,
	dd 10.0, -1.0, -10.0, 1.0, 1.0,
	dd -10.0, -1.0, -10.0, 0.0, 1.0,
	dd -10.0, -1.0, 10.0, 0.0, 0.0
	
	indices_vector:
	dd 36
	dd 36
	dd 4
	dd indices
	indices:
	dd 1,0,2,3,2,0
	dd 4,5,6,6,7,4
	dd 9,8,10,11,10,8
	dd 12,13,14,14,15,12
	dd 17,16,18,19,18,16
	dd 21,20,22,23,22,20
	
	mesh_vertex_count dd 24
	mesh_vertices:
	dd -10.0, -1.0, 10.0
	dd -10.0, 1.0, 10.0
	dd 10.0, 1.0, 10.0
	dd 10.0, -1.0, 10.0
	dd -10.0, -1.0, 10.0
	dd -10.0, 1.0, 10.0
	dd -10.0, 1.0, -10.0
	dd -10.0, -1.0, -10.0
	dd 10.0, -1.0, -10.0
	dd 10.0, 1.0, -10.0
	dd -10.0, 1.0, -10.0
	dd -10.0, -1.0, -10.0
	dd 10.0, -1.0, -10.0
	dd 10.0, 1.0, -10.0
	dd 10.0, 1.0, 10.0
	dd 10.0, -1.0, 10.0
	dd -10.0, 1.0, 10.0
	dd -10.0, 1.0, -10.0
	dd 10.0, 1.0, -10.0
	dd 10.0, 1.0, 10.0
	dd 10.0, -1.0, 10.0
	dd 10.0, -1.0, -10.0
	dd -10.0, -1.0, -10.0
	dd -10.0, -1.0, 10.0
	
	mesh_index_count dd 36
	mesh_indices:
	dd 1,0,2,3,2,0
	dd 4,5,6,6,7,4
	dd 9,8,10,11,10,8
	dd 12,13,14,14,15,12
	dd 17,16,18,19,18,16
	dd 21,20,22,23,22,20
	
	vertex_data_2_vector:
	dd 18
	dd 18
	dd 4
	dd vertex_data_2
	vertex_data_2:
	dd -1.0, 0.1, 1.0
	dd 1.0, 0.1, 1.0
	dd 0.0, 0.1, -1.0
	dd -1.0, -0.1, 1.0
	dd 1.0, -0.1, 1.0
	dd 0.0, -0.1, -1.0
	
	mesh_vertex_count_2 dd 6
	
	indices_2_vector:
	dd 24
	dd 24
	dd 4
	dd indices_2
	indices_2:
	dd 0,1,2, 5,4,3
	dd 0,3,4, 4,1,0
	dd 1,4,5, 5,2,1
	dd 2,5,3, 3,0,2
	
	position_2 dd 3.0, 1.5, 3.0
	
	
section .bss use32
	should_close resb 4					;tsValue*
	physics_thread resb 4				;thread*

	camera resb 36
	pv_matrix resb 64
	
	hyperplane resb 64
	pplayer resb 4
	
	image_renderable resb 4
	plain_renderable resb 4
	
	cylinder resb 4
	mesh resb 4
	mesh2 resb 4
	
section .data use32
	last_frame_milliseconds dd 0		;int, the GetTickCount of the last frame
	delta_time_milliseconds dd 0		;int
	delta_time_seconds dd 0.0			;float
	
	current_window dd 0					;GLFWwindow*
	
	should_resize dd 0

section .text use32

	dll_import kernel32.dll, GetTickCount
	
	
	global game_loop		;void game_loop(GLFWwindow* pwindow)
	
	extern glClear
	extern glClearColor
	extern glEnable
	extern glFrontFace
	extern glViewport
	
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
	extern TEXT_ORIGIN_BOTTOM_CENTER
	extern TEXT_ORIGIN_TOP_LEFT
	extern TEXT_ORIGIN_BOTTOM_RIGHT
	extern TEXT_ORIGIN_TOP_RIGHT
	extern TEXT_PIVOT_BOTTOM_CENTER
	extern TEXT_PIVOT_BOTTOM_RIGHT
	extern TEXT_PIVOT_TOP_LEFT
	extern TEXT_PIVOT_TOP_RIGHT
	
	extern textureHandler_init
	extern textureHandler_deinit
	
	extern WINDOW_SIZE_X
	extern WINDOW_SIZE_Y
	
	extern collider_init
	extern collider_deinit
	extern collider_createCylinder
	extern collider_createMesh
	extern collider_destroy
	extern collider_setPosition
	extern collisionDetection_resolveKinematicNonkinematic
	extern physics_init
	extern physics_deinit
	extern physics_update
	extern physics_registerNonkinematic
	extern physics_registerKinematic
	
	extern thread_create
	extern thread_join
	extern thread_resume
	extern tsValue_create
	extern tsValue_destroy
	extern tsValue_set
	extern tsValue_isEqual
	
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
	call collider_init
	call physics_init
	
	;init the two mesh colliders
	push dword[mesh_index_count]
	push dword[mesh_vertex_count]
	push mesh_indices
	push mesh_vertices
	call collider_createMesh
	add esp, 16
	mov dword[mesh], eax
	
	push dword[indices_2_vector]
	push dword[mesh_vertex_count_2]
	push indices_2
	push vertex_data_2
	call collider_createMesh
	add esp, 16
	mov dword[mesh2], eax
	push position_2
	push dword[mesh2]
	call collider_setPosition
	add esp, 8
	
	
	push dword[mesh]
	call physics_registerKinematic
	add esp, 4
	push dword[mesh2]
	call physics_registerKinematic
	add esp, 4

	
	
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
	
	;create hyperplane
	push hyperplane
	call hyperPlane_create
	add esp, 4
	
	;create player
	push hyperplane
	push camera
	call player_init
	mov dword[pplayer], eax
	add esp, 8
	
	;create morbius poster and the plain renderable
	push dword[RENDERABLE_ATTRIB_P3UV2]
	push indices_vector
	push vertex_data_vector
	call renderable_create
	add esp, 12
	mov dword[image_renderable], eax
	
	push image_path
	push dword[image_renderable]
	call renderable_setAlbedo
	add esp, 8
	
	
	push dword[RENDERABLE_ATTRIB_P3]
	push indices_2_vector
	push vertex_data_2_vector
	call renderable_create
	add esp, 12
	mov dword[plain_renderable], eax
	
	push position_2
	push dword[plain_renderable]
	call renderable_setPosition
	add esp, 8
	
	
	;enable depth test and face cull
	push dword[GL_DEPTH_TEST]
	call [glEnable]
	
	push dword[GL_CCW]
	call [glFrontFace]
	push dword[GL_CULL_FACE]
	call [glEnable]
	
	;init last frame time
	call [GetTickCount]
	mov dword[last_frame_milliseconds], eax
	
	;start the pyhsics thread
	push 69					;start immediately
	push 0
	push gameLoop_physics
	call thread_create
	mov dword[physics_thread], eax
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
		
		
		;check if the window should be resized
		cmp dword[should_resize], 0
		je gameLoop_loop_no_resize
			mov dword[should_resize], 0
			call gameLoop_handleWindowResize
		gameLoop_loop_no_resize:
		
		
		;update player
		push dword[delta_time_seconds]
		push dword[pplayer]
		call player_update
		add esp, 8
	
		;set clear color
		push dword[ONE]
		push dword[P6]
		push dword[ZERO]
		push dword[P15]
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
		
		;render morbius poster and plain object thingy
		push pv_matrix
		push dword[image_renderable]
		call renderable_render
		add esp, 8
		
		push pv_matrix
		push dword[plain_renderable]
		call renderable_render
		add esp, 8
		
		
		;draw hyperplane data
		call gameLoop_drawHyperplaneData
		
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
	
		
	;destroy morbius poster and plain object thingy
	push dword[image_renderable]
	call renderable_destroy
	add esp, 4
	push dword[plain_renderable]
	call renderable_destroy
	add esp, 4
	
	;destroy player
	push dword[pplayer]
	call player_destroy
	add esp, 4
	
	;deinit texture handler
	call textureHandler_deinit
	
	;deinit text renderer
	call textRenderer_deinit
	
	;deinit renderable
	call renderable_deinit
	
	;deinit physics
	call physics_deinit
	call collider_deinit
	
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
	sub esp, 4			;glfwGetTime test			;16
	
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
		call physics_update
		add esp, 4
		
		;update player
		push dword[ebp-12]
		push dword[pplayer]
		call player_updatePhysics
		add esp, 8
		
		
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
	
	
gameLoop_drawHyperplaneData:
	push ebp
	mov ebp, esp
	
	sub esp, 100				;char buffer[100]
	
	;draw point
	mov eax, hyperplane
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
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 50
	
	;draw based vectors
	render_text text_based_vectors, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 80
	
	mov eax, hyperplane
	add eax, 16
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
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 100
	
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 120
	
	push print_vec4
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	add esp, 24
	lea eax, [ebp-100]
	render_text eax, dword[TEXT_ORIGIN_TOP_LEFT], dword[TEXT_PIVOT_TOP_LEFT], 30, 140
	
	mov esp, ebp
	pop ebp
	ret