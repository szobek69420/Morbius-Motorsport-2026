[BITS 32]

section .rodata use32
	test_text db "sir, they ate the second respirator",10,0

	text_welcome db "zaoshang hao",0
	
	background_path db "sprites/ui/menu/background.bmp",0

section .data use32

	window dd 0					;GLFWwindow*
	should_resize dd 0			;tsValue<int>*
	return_value dd 0			;tsValue<int>*	;the default value is dword[GAME_STATE_MENU], some other state in order to break out of the loop
	
	;ui
	CANVAS_MENU dd 0
	IMAGE_BACKGROUND dd 0
	IMAGE_START_BUTTON dd 0
	TEXT_WELCOME dd 0
	
section .bss use32
	
	projection_matrix_ui resb 64

section .text use32

	;returns the next game state
	;int menuLoop_main(GLFWwindow* pwindow)
	global menuLoop_main
	
	
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
	
	extern window_enableVsync
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
	extern glfwWindowShouldClose
	extern GLFW_KEY_ESCAPE
	
	extern uiElement_init
	extern uiElement_deinit
	extern uiElement_processInput
	extern uiElement_render
	extern uiElement_createProjection
	extern uiElement_create
	extern uiElement_setPosition
	extern uiElement_setSize
	extern uiElement_setParent
	extern uiElement_setAnchor
	extern uiElement_setPivot
	extern uiElement_setOnClick
	extern uiElement_setStatus
	extern uiImage_setTexture
	extern uiText_setText
	extern uiText_setTextAlignment
	extern uiText_setFontSize
	extern uiText_setColour
	extern UI_CANVAS
	extern UI_IMAGE
	extern UI_TEXT
	extern UI_CENTER
	extern UI_STRETCH
	extern UI_TEXT_ALIGN_CENTER
	
	extern GAME_STATE_MENU
	extern GAME_STATE_INGAME
	extern GAME_STATE_DEINIT
	
menuLoop_main:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4		;return value helper		4
	sub esp, 4		;loop exit helper			8
	
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
	mov dword[return_value], eax
	add esp, 4
	
	push 69
	push dword[should_resize]
	call tsValue_set
	push dword[GAME_STATE_MENU]
	push dword[return_value]
	call tsValue_set
	add esp, 16
	
	;set window resize callback
	push menuLoop_windowResizeCallback
	push dword[window]
	call [glfwSetFramebufferSizeCallback]
	add esp, 8
	
	;enable vsync
	push 69
	push dword[window]
	call window_enableVsync
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
		mov dword[ebp-8], eax
		push dword[window]
		call [glfwWindowShouldClose]
		or dword[ebp-8], eax
		add esp, 8
		
		test dword[ebp-8], 0xffffffff
		jz menuLoop_main_loop_no_escape
			push dword[GAME_STATE_DEINIT]
			push dword[return_value]
			call tsValue_set
			add esp, 8
		menuLoop_main_loop_no_escape:
		
		;check if the window is closed or not
		push dword[GAME_STATE_MENU]
		push dword[return_value]
		call tsValue_isEqual
		add esp, 8
		test eax, eax
		jnz menuLoop_main_loop_start
	
	;disable vsync
	push 0
	push dword[window]
	call window_enableVsync
	add esp, 8
	
	;unset window resize callback
	push 0
	push dword[window]
	call [glfwSetFramebufferSizeCallback]
	add esp, 8
	
	;save the return value
	lea eax, [ebp-4]
	push eax
	push dword[return_value]
	call tsValue_get
	add esp, 8
	
	
	;destroy thread safe values
	push dword[should_resize]
	call tsValue_destroy
	mov dword[should_resize], 0
	add esp, 4
	
	push dword[return_value]
	call tsValue_destroy
	mov dword[return_value], 0
	add esp, 4
	
	;deinit subsystems
	call uiElement_deinit
	call textureHandler_deinit
	call textRenderer_deinit
	call renderable_deinit
	
	;set return value
	mov eax, dword[ebp-4]
	
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
	
	;create background image
	push dword[UI_IMAGE]
	call uiElement_create
	mov dword[IMAGE_BACKGROUND], eax
	
	push dword[CANVAS_MENU]
	push dword[IMAGE_BACKGROUND]
	call uiElement_setParent
	
	push word[UI_STRETCH]
	push word[UI_STRETCH]
	push dword[IMAGE_BACKGROUND]
	call uiElement_setAnchor
	
	push 0
	push 0
	push dword[IMAGE_BACKGROUND]
	call uiElement_setPosition
	call uiElement_setSize
	
	push background_path
	push dword[IMAGE_BACKGROUND]
	call uiImage_setTexture

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
	
	push dword[return_value]
	push menuLoop_startButtonCallback
	push dword[IMAGE_START_BUTTON]
	call uiElement_setOnClick
	
	push 69
	push 69
	push dword[IMAGE_START_BUTTON]
	call uiElement_setStatus
	
	;create text
	push dword[UI_TEXT]
	call uiElement_create
	mov dword[TEXT_WELCOME], eax
	
	push dword[CANVAS_MENU]
	push dword[TEXT_WELCOME]
	call uiElement_setParent
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[TEXT_WELCOME]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	push 100
	push 0
	push dword[TEXT_WELCOME]
	call uiElement_setPosition
	
	push text_welcome
	push dword[TEXT_WELCOME]
	call uiText_setText
	
	push 20
	push 30
	push dword[TEXT_WELCOME]
	call uiText_setFontSize
	
	push 0x3f800000
	push 0x3f800000
	push 0x3f800000
	push 0
	push dword[TEXT_WELCOME]
	call uiText_setColour
	
	mov esp, ebp
	pop ebp
	ret
	

;void menuLoop_startButtonCallback(UIElement* element, tsValue<int>* returnValue)
menuLoop_startButtonCallback:
	push ebp
	mov ebp, esp
	
	push dword[GAME_STATE_INGAME]
	push dword[ebp+12]
	call tsValue_set
	
	mov esp, ebp
	pop ebp
	ret