[BITS 32]

section .rodata use32
	test_text db "sir, they ate the second respirator",10,0

section .data use32

	window dd 0					;GLFWwindow*
	should_resize dd 0			;tsValue<int>*
	should_close dd 0			;tsValue<int>*
	
	;ui
	CANVAS_MENU dd 0
	IMAGE_START_BUTTON dd 0
	
section .bss use32
	
	projection_matrix_ui resb 64

section .text use32

	global menuLoop_main		;void menuLoop_main(GLFWwindow* pwindow)
	
	
	extern my_printf
	
	extern input_update
	extern input_keyReleased
	
	extern tsValue_create
	extern tsValue_destroy
	extern tsValue_get
	extern tsValue_set
	extern tsValue_isEqual
	
	extern renderable_init
	extern renderable_deinit
	extern textRenderer_init
	extern textRenderer_deinit
	extern textureHandler_init
	extern textureHandler_deinit
	
	extern WINDOW_SIZE_X
	extern WINDOW_SIZE_Y
	
	extern glViewport
	extern glEnable
	extern glDisable
	extern glClear
	extern glClearColor
	extern GL_DEPTH_TEST
	extern GL_BLEND
	extern GL_COLOR_BUFFER_BIT
	
	extern glfwSetFramebufferSizeCallback
	extern glfwSwapBuffers
	extern glfwPollEvents
	extern GLFW_KEY_ESCAPE
	
	extern uiElement_init
	extern uiElement_deinit
	extern uiElement_processInput
	extern uiElement_render
	extern uiElement_createProjection
	extern uiElement_create
	extern uiElement_setParent
	extern uiElement_setAnchor
	extern uiElement_setPivot
	extern uiElement_setOnClick
	extern uiElement_setStatus
	extern UI_CANVAS
	extern UI_IMAGE
	extern UI_CENTER
	
menuLoop_main:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;save window
	mov eax, dword[ebp+20]
	mov dword[window], eax
	
	;init subsystems
	call renderable_init
	call textRenderer_init
	call textureHandler_init
	call uiElement_init
	
	;create thread safe values
	push 4
	call tsValue_create
	mov dword[should_resize], eax
	call tsValue_create
	mov dword[should_close], eax
	add esp, 4
	
	push 69
	push dword[should_resize]
	call tsValue_set
	push 0
	push dword[should_close]
	call tsValue_set
	add esp, 16
	
	;set window resize callback
	push menuLoop_windowResizeCallback
	push dword[window]
	call [glfwSetFramebufferSizeCallback]
	add esp, 8
	
	;create canvas
	call menuLoop_initCanvas
	
	;menu loop
	menuLoop_main_loop_start:
		;check if a resize is necessary
		push 0
		push dword[should_resize]
		call tsValue_isEqual
		add esp, 8
		
		test eax, eax
		jnz menuLoop_main_loop_no_resize
			call menuLoop_handleWindowResize
		menuLoop_main_loop_no_resize:
		
		;process ui inputs
		call uiElement_processInput
		
		
		;prepare for rendering
		push 0
		push 0
		push 0
		push 0
		call [glClearColor]
		
		push dword[GL_COLOR_BUFFER_BIT]
		call [glClear]
		
		push dword[GL_DEPTH_TEST]
		call [glDisable]
		
		push dword[GL_BLEND]
		call [glEnable]
		
		;render ui
		push dword[WINDOW_SIZE_Y]
		push dword[WINDOW_SIZE_X]
		push projection_matrix_ui
		call uiElement_createProjection
		add esp, 12
		
		push projection_matrix_ui
		call uiElement_render
		add esp, 4
		
		;swap buffers
		push dword[window]
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
		jz menuLoop_main_loop_no_escape
			push 69
			push dword[should_close]
			call tsValue_set
			add esp, 8
		menuLoop_main_loop_no_escape:
		
		;check if the window is closed or not
		push 0
		push dword[should_close]
		call tsValue_isEqual
		add esp, 8
		test eax, eax
		jnz menuLoop_main_loop_start
	
	;unset window resize callback
	push 0
	push dword[window]
	call [glfwSetFramebufferSizeCallback]
	add esp, 8
	
	;destroy thread safe values
	push dword[should_resize]
	call tsValue_destroy
	mov dword[should_resize], 0
	add esp, 4
	
	push dword[should_close]
	call tsValue_destroy
	mov dword[should_close], 0
	add esp, 4
	
	;deinit subsystems
	call uiElement_deinit
	call textureHandler_deinit
	call textRenderer_deinit
	call renderable_deinit
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
;void menuLoop_windowResizeCallback(GLFWwindow* pwindow, int width, int height)
menuLoop_windowResizeCallback:
	push ebp
	mov ebp, esp
	
	;update window size
	mov eax, dword[ebp+12]
	mov dword[WINDOW_SIZE_X], eax
	mov ecx, dword[ebp+16]
	mov dword[WINDOW_SIZE_Y], ecx
	
	;set should_resize flag
	push 69
	push dword[should_resize]
	call tsValue_set
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	

menuLoop_handleWindowResize:
	push ebp
	mov ebp, esp
	
	;change viewport
	push dword[WINDOW_SIZE_Y]
	push dword[WINDOW_SIZE_X]
	push 0
	push 0
	call [glViewport]
	
	mov esp, ebp
	pop ebp
	ret
	
	
;void menuLoop_initCanvas()
menuLoop_initCanvas:
	push ebp
	mov ebp, esp
	
	;create canvas
	push dword[UI_CANVAS]
	call uiElement_create
	mov dword[CANVAS_MENU], eax
	
	push 69
	push 69
	push dword[CANVAS_MENU]
	call uiElement_setStatus

	;create image
	push dword[UI_IMAGE]
	call uiElement_create
	mov dword[IMAGE_START_BUTTON], eax
	
	push dword[CANVAS_MENU]
	push dword[IMAGE_START_BUTTON]
	call uiElement_setParent
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[IMAGE_START_BUTTON]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	push dword[should_close]
	push menuLoop_startButtonCallback
	push dword[IMAGE_START_BUTTON]
	call uiElement_setOnClick
	
	push 69
	push 69
	push dword[IMAGE_START_BUTTON]
	call uiElement_setStatus
	
	mov esp, ebp
	pop ebp
	ret
	

;void menuLoop_startButtonCallback(UIElement* element, tsValue<int>* shouldClose)
menuLoop_startButtonCallback:
	push ebp
	mov ebp, esp
	
	push 69
	push dword[ebp+12]
	call tsValue_set
	
	mov esp, ebp
	pop ebp
	ret