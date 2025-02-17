[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	ZERO dd 0.0
	ONE dd 1.0
	ONE_PER_THOUSAND dd 0.001
	P15 dd 0.15
	P6 dd 0.6
	
	test_text db "OTTO VON BISMARCK",0
	print_int db "%d",10,0
	print_two_ints db "%d %d",10,0
	print_float db "%f",0
	print_new_line db 10,0
	
	image_path db "./sprites/morbussin.bmp",0
	
	vertex_data_vector:		;imitates a vector
	dd 120
	dd 120
	dd 4
	dd vertex_data
	vertex_data:
	dd -1.0, -1.0, 1.0, 0.0, 0.0,
	dd -1.0, 1.0, 1.0, 0.0, 1.0,
	dd 1.0, 1.0, 1.0, 1.0, 1.0,
	dd 1.0, -1.0, 1.0, 1.0, 0.0,
	dd -1.0, -1.0, 1.0, 0.0, 0.0,
	dd -1.0, 1.0, 1.0, 0.0, 1.0,
	dd -1.0, 1.0, -1.0, 1.0, 1.0,
	dd -1.0, -1.0, -1.0, 1.0, 0.0,
	dd 1.0, -1.0, -1.0, 1.0, 0.0,
	dd 1.0, 1.0, -1.0, 1.0, 1.0,
	dd -1.0, 1.0, -1.0, 0.0, 1.0,
	dd -1.0, -1.0, -1.0, 0.0, 0.0,
	dd 1.0, -1.0, -1.0, 1.0, 0.0,
	dd 1.0, 1.0, -1.0, 1.0, 1.0,
	dd 1.0, 1.0, 1.0, 0.0, 1.0,
	dd 1.0, -1.0, 1.0, 0.0, 0.0,
	dd -1.0, 1.0, 1.0, 0.0, 0.0,
	dd -1.0, 1.0, -1.0, 0.0, 1.0,
	dd 1.0, 1.0, -1.0, 1.0, 1.0,
	dd 1.0, 1.0, 1.0, 1.0, 0.0,
	dd 1.0, -1.0, 1.0, 1.0, 0.0,
	dd 1.0, -1.0, -1.0, 1.0, 1.0,
	dd -1.0, -1.0, -1.0, 0.0, 1.0,
	dd -1.0, -1.0, 1.0, 0.0, 0.0
	
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
	dd -1.0, -1.0, 1.0
	dd -1.0, 1.0, 1.0
	dd 1.0, 1.0, 1.0
	dd 1.0, -1.0, 1.0
	dd -1.0, -1.0, 1.0
	dd -1.0, 1.0, 1.0
	dd -1.0, 1.0, -1.0
	dd -1.0, -1.0, -1.0
	dd 1.0, -1.0, -1.0
	dd 1.0, 1.0, -1.0
	dd -1.0, 1.0, -1.0
	dd -1.0, -1.0, -1.0
	dd 1.0, -1.0, -1.0
	dd 1.0, 1.0, -1.0
	dd 1.0, 1.0, 1.0
	dd 1.0, -1.0, 1.0
	dd -1.0, 1.0, 1.0
	dd -1.0, 1.0, -1.0
	dd 1.0, 1.0, -1.0
	dd 1.0, 1.0, 1.0
	dd 1.0, -1.0, 1.0
	dd 1.0, -1.0, -1.0
	dd -1.0, -1.0, -1.0
	dd -1.0, -1.0, 1.0
	
	mesh_index_count dd 36
	mesh_indices:
	dd 1,0,2,3,2,0
	dd 4,5,6,6,7,4
	dd 9,8,10,11,10,8
	dd 12,13,14,14,15,12
	dd 17,16,18,19,18,16
	dd 21,20,22,23,22,20
	
section .bss use32
	camera resb 36
	pv_matrix resb 64
	
	pplayer resb 4
	
	image_renderable resb 4
	
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
	
	extern renderable_init
	extern renderable_deinit
	extern renderable_create
	extern renderable_destroy
	extern renderable_render
	extern renderable_setAlbedo
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
	extern TEXT_PIVOT_BOTTOM_CENTER
	
	extern textureHandler_init
	extern textureHandler_deinit
	
	extern WINDOW_SIZE_X
	extern WINDOW_SIZE_Y
	
	extern collider_init
	extern collider_deinit
	extern collider_createCylinder
	extern collider_destroy
	
game_loop:
	push ebp
	mov ebp, esp
	
	
	;save pwindow
	mov eax, dword[ebp+8]
	mov dword[current_window], eax
	
	;init input and set callbacks
	call input_init
	
	
	push input_keyCallback
	push dword[current_window]
	call [glfwSetKeyCallback]
	add esp, 8
	
	push input_mouseButtonCallback
	push dword[current_window]
	call [glfwSetMouseButtonCallback]
	add esp, 8
	
	push input_mouseMoveCallback
	push dword[current_window]
	call [glfwSetCursorPosCallback]
	add esp, 8
	
	push input_mouseScrollCallback
	push dword[current_window]
	call [glfwSetScrollCallback]
	add esp, 8
	
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
	
	;create player
	push camera
	call player_init
	mov dword[pplayer], eax
	add esp, 4
	
	;create morbius poster
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
		
		
		;player
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
		
		;render morbius poster
		push pv_matrix
		push dword[image_renderable]
		call renderable_render
		add esp, 8
		
		
		;draw text
		push 0
		push 0
		push dword[TEXT_PIVOT_BOTTOM_CENTER]
		push dword[TEXT_ORIGIN_BOTTOM_CENTER]
		push test_text
		call textRenderer_drawText
		add esp, 20
		
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
			push dword[current_window]
			call [glfwSetWindowShouldClose]
			add esp, 8
		gameLoop_loop_no_escape:
		
		;check if the window is closed or not
		push dword[current_window]
		call [glfwWindowShouldClose]
		add esp, 4
		test eax, eax
		jz gameLoop_loop_start
		
	;destroy morbius poster
	push dword[image_renderable]
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
	call collider_deinit
	
	
	mov dword[current_window], 0
	
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
