[BITS 32]

section .rodata use32

	test_text db "lowkey ruzsa magdi",10,0

	HALF dd 0.5
	ONE dd 1.0
	THREE dd 3.0
	FIVE dd 5.0
	SEVEN dd 7.0
	
	print_int_nl db "%d",10,0
	
	print_render_distance db "Render distance: %d",0

	text_title db "settings",0
	text_returnButton db "save changes",0
	
	background_texture_path db "sprites/ui/menu/background.bmp",0
	slider_knob_texture_path db "sprites/ui/settings/slider_knob.bmp",0
	
	;resolutions
	RESOLUTION_WIDTHS dd 10, 256, 640, 1280, 1920, 1920, 2560, 15360
	RESOLUTION_HEIGHTS dd 10, 144, 480, 720, 1080, 1, 1440, 8640
	RESOLUTION_NAMES:
	dd RESOLUTION_NAME_0
	dd RESOLUTION_NAME_1
	dd RESOLUTION_NAME_2
	dd RESOLUTION_NAME_3
	dd RESOLUTION_NAME_4
	dd RESOLUTION_NAME_5
	dd RESOLUTION_NAME_6
	dd RESOLUTION_NAME_7
	
	RESOLUTION_NAME_0 db "Helen Keller (0x0)",0
	RESOLUTION_NAME_1 db "256x144",0
	RESOLUTION_NAME_2 db "640x480",0
	RESOLUTION_NAME_3 db "HD (1280x720)",0
	RESOLUTION_NAME_4 db "FHD (1920x1080)",0
	RESOLUTION_NAME_5 db "Chinese FHD (1920x1)",0
	RESOLUTION_NAME_6 db "QHD (2560x1440)",0
	RESOLUTION_NAME_7 db "Mogger (15360x8640)",0

section .data use32
	window dd 0					;GLFWwindow*
	should_resize dd 0			;tsValue<int>*
	return_value dd 0			;tsValue<int>*	;the default value is dword[GAME_STATE_MENU], some other state in order to break out of the loop

	CANVAS_SETTINGS dd 0
	IMAGE_BACKGROUND dd 0
	TEXT_TITLE dd 0
	BUTTON_RETURN dd 0
	SLIDER_RENDER_DISTANCE dd 0
	TEXT_RENDER_DISTANCE_VALUE dd 0
	SLIDER_RESOLUTION dd 0
	TEXT_RESOLUTION_VALUE dd 0
	
	;current game values
	VALUE_RENDER_DISTANCE dd 3			;int
	VALUE_RESOLUTION dd 3				;int

section .bss use32
	
	projection_matrix_ui resb 64

section .text use32

	;returns the next game state
	;int settingsLoop_main(GLFWwindow* pwindow)
	global settingsLoop_main
	
	extern my_printf
	extern my_sprintf
	
	extern input_update
	extern input_keyReleased
	
	extern tsValue_create
	extern tsValue_destroy
	extern tsValue_get
	extern tsValue_set
	extern tsValue_isEqual
	
	extern renderable_init
	extern renderable_deinit
	extern renderable_enableBlending
	extern renderable_enableDepthTest
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
	extern uiImage_setCornerRadius
	extern uiImage_setColour
	extern uiText_setText
	extern uiText_setTextAlignment
	extern uiText_setFontSize
	extern uiText_setColour
	extern uiButton_getText
	extern uiButton_getImage
	extern uiButton_setTextColour
	extern uiSlider_setOnlyInteger
	extern uiSlider_getFill
	extern uiSlider_getKnob
	extern uiSlider_getValue
	extern uiSlider_setValue
	extern uiSlider_setMinValue
	extern uiSlider_setMaxValue
	extern uiSlider_setOnValueChanged
	extern UI_CANVAS
	extern UI_IMAGE
	extern UI_TEXT
	extern UI_BUTTON
	extern UI_SLIDER
	extern UI_LEFT
	extern UI_RIGHT
	extern UI_BOTTOM
	extern UI_TOP
	extern UI_CENTER
	extern UI_STRETCH
	extern UI_TEXT_ALIGN_LEFT
	extern UI_TEXT_ALIGN_BOTTOM
	extern UI_TEXT_ALIGN_CENTER
	extern UI_TEXT_ALIGN_RIGHT
	extern UI_TEXT_ALIGN_TOP
	
	extern GAME_STATE_MENU
	extern GAME_STATE_INGAME
	extern GAME_STATE_DEINIT
	extern GAME_STATE_SETTINGS
	
settingsLoop_main:
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
	push dword[GAME_STATE_SETTINGS]
	push dword[return_value]
	call tsValue_set
	add esp, 16
	
	;set window resize callback
	push settingsLoop_windowResizeCallback
	push dword[window]
	call [glfwSetFramebufferSizeCallback]
	add esp, 8
	
	;enable vsync
	push 69
	push dword[window]
	call window_enableVsync
	add esp, 8
	
	;load values
	call settingsLoop_loadValues
	
	;create canvas
	call settingsLoop_initCanvas
	
	;menu loop
	settingsLoop_main_loop_start:
		;check if a resize is necessary
		push 0
		push dword[should_resize]
		call tsValue_isEqual
		add esp, 8
		
		test eax, eax
		jnz settingsLoop_main_loop_no_resize
			call settingsLoop_handleWindowResize
		settingsLoop_main_loop_no_resize:
		
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
		
		push 0
		call renderable_enableDepthTest
		add esp, 4
		
		push 69
		call renderable_enableBlending
		add esp, 4
		
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
		jz settingsLoop_main_loop_no_escape
			push dword[GAME_STATE_MENU]
			push dword[return_value]
			call tsValue_set
			add esp, 8
		settingsLoop_main_loop_no_escape:
		
		;check if the window is closed or not
		push dword[GAME_STATE_SETTINGS]
		push dword[return_value]
		call tsValue_isEqual
		add esp, 8
		test eax, eax
		jnz settingsLoop_main_loop_start
	
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
	
;currently only a placeholder
;void settingsLoop_loadValues()
settingsLoop_loadValues:
	push ebp
	mov ebp, esp
	
	mov dword[VALUE_RENDER_DISTANCE], 3
	mov dword[VALUE_RESOLUTION], 3
	
	mov esp, ebp
	pop ebp
	ret
	
;void settingsLoop_windowResizeCallback(GLFWwindow* pwindow, int width, int height)
settingsLoop_windowResizeCallback:
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
	
	

settingsLoop_handleWindowResize:
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
	
	
settingsLoop_initCanvas:
	push ebp
	mov ebp, esp
	
	;create canvas
	push dword[UI_CANVAS]
	call uiElement_create
	mov dword[CANVAS_SETTINGS], eax
	
	push 69
	push 69
	push dword[CANVAS_SETTINGS]
	call uiElement_setStatus
	
	;create background
	push dword[UI_IMAGE]
	call uiElement_create
	mov dword[IMAGE_BACKGROUND], eax
	
	push dword[CANVAS_SETTINGS]
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
	
	push background_texture_path
	push dword[IMAGE_BACKGROUND]
	call uiImage_setTexture
	
	push dword[ONE]
	push dword[HALF]
	push dword[HALF]
	push dword[HALF]
	push dword[IMAGE_BACKGROUND]
	call uiImage_setColour
	
	;create title
	push dword[UI_TEXT]
	call uiElement_create
	mov dword[TEXT_TITLE], eax
	
	push dword[CANVAS_SETTINGS]
	push dword[TEXT_TITLE]
	call uiElement_setParent
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[TEXT_TITLE]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	push 120
	push 0
	push dword[TEXT_TITLE]
	call uiElement_setPosition
	
	push 0
	push 0
	push dword[TEXT_TITLE]
	call uiElement_setSize
	
	push 45
	push 30
	push dword[TEXT_TITLE]
	call uiText_setFontSize
	
	push text_title
	push dword[TEXT_TITLE]
	call uiText_setText
	
	;create return button
	push dword[UI_BUTTON]
	call uiElement_create
	mov dword[BUTTON_RETURN], eax
	
	push dword[CANVAS_SETTINGS]
	push dword[BUTTON_RETURN]
	call uiElement_setParent
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[BUTTON_RETURN]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	push 0x41c00000
	push dword[BUTTON_RETURN]
	call uiButton_getImage
	mov dword[esp], eax
	call uiImage_setCornerRadius
	
	push 60
	push 300
	push dword[BUTTON_RETURN]
	call uiElement_setSize
	
	push -160
	push 0
	push dword[BUTTON_RETURN]
	call uiElement_setPosition
	
	push dword[return_value]
	push settingsLoop_initCanvas_returnButtonCallback
	push dword[BUTTON_RETURN]
	call uiElement_setOnClick
	
	push text_returnButton
	push dword[BUTTON_RETURN]
	call uiButton_getText
	mov dword[esp], eax
	call uiText_setText
	
	jmp settingsLoop_initCanvas_returnButtonCallback_skip
	;void settingsLoop_initCanvas_returnButtonCallback(UIElement* element, tsValue<int>* returnValue)
	settingsLoop_initCanvas_returnButtonCallback:
		mov eax, dword[esp+8]
		push dword[GAME_STATE_MENU]
		push eax
		call tsValue_set
		add esp, 8
		ret
	settingsLoop_initCanvas_returnButtonCallback_skip:
	
	;create render distance value text
	push dword[UI_TEXT]
	call uiElement_create
	mov dword[TEXT_RENDER_DISTANCE_VALUE], eax
	
	push dword[CANVAS_SETTINGS]
	push dword[TEXT_RENDER_DISTANCE_VALUE]
	call uiElement_setParent
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[TEXT_RENDER_DISTANCE_VALUE]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	push 0
	push 0
	push dword[TEXT_RENDER_DISTANCE_VALUE]
	call uiElement_setSize
	
	push 25
	push 0
	push dword[TEXT_RENDER_DISTANCE_VALUE]
	call uiElement_setPosition
	
	push dword[ONE]
	push dword[ONE]
	push dword[ONE]
	push 0
	push dword[TEXT_RENDER_DISTANCE_VALUE]
	call uiText_setColour
	
	
	;create render distance slider
	push dword[UI_SLIDER]
	call uiElement_create
	mov dword[SLIDER_RENDER_DISTANCE], eax
	
	push dword[CANVAS_SETTINGS]
	push dword[SLIDER_RENDER_DISTANCE]
	call uiElement_setParent
	
	push 50
	push 400
	push dword[SLIDER_RENDER_DISTANCE]
	call uiElement_setSize
	
	push 25
	push 0
	push dword[SLIDER_RENDER_DISTANCE]
	call uiElement_setPosition
	
	push 69
	push dword[SLIDER_RENDER_DISTANCE]
	call uiSlider_setOnlyInteger
	
	push dword[ONE]
	push dword[SLIDER_RENDER_DISTANCE]
	call uiSlider_setMinValue
	
	push dword[FIVE]
	push dword[SLIDER_RENDER_DISTANCE]
	call uiSlider_setMaxValue
	
	push dword[TEXT_RENDER_DISTANCE_VALUE]
	push settingsLoop_renderDistanceOnValueChangedCallback
	push dword[SLIDER_RENDER_DISTANCE]
	call uiSlider_setOnValueChanged
	
	cvtsi2ss xmm0, dword[VALUE_RENDER_DISTANCE]
	sub esp, 4
	movss dword[esp], xmm0
	push dword[SLIDER_RENDER_DISTANCE]
	call uiSlider_setValue
	
	push dword[SLIDER_RENDER_DISTANCE]
	call uiSlider_getFill
	push 0
	push 0
	push eax
	call uiElement_setStatus
	
	push dword[SLIDER_RENDER_DISTANCE]
	call uiSlider_getKnob
	push 44
	push 44
	push eax
	call uiElement_setSize
	mov dword[esp+4], slider_knob_texture_path
	call uiImage_setTexture
	
	;create resolution value text
	push dword[UI_TEXT]
	call uiElement_create
	mov dword[TEXT_RESOLUTION_VALUE], eax
	
	push dword[CANVAS_SETTINGS]
	push dword[TEXT_RESOLUTION_VALUE]
	call uiElement_setParent
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[TEXT_RESOLUTION_VALUE]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	push 0
	push 0
	push dword[TEXT_RESOLUTION_VALUE]
	call uiElement_setSize
	
	push -50
	push 0
	push dword[TEXT_RESOLUTION_VALUE]
	call uiElement_setPosition
	
	push dword[ONE]
	push dword[ONE]
	push dword[ONE]
	push 0
	push dword[TEXT_RESOLUTION_VALUE]
	call uiText_setColour
	
	
	;create resolution slider
	push dword[UI_SLIDER]
	call uiElement_create
	mov dword[SLIDER_RESOLUTION], eax
	
	push dword[CANVAS_SETTINGS]
	push dword[SLIDER_RESOLUTION]
	call uiElement_setParent
	
	push 50
	push 400
	push dword[SLIDER_RESOLUTION]
	call uiElement_setSize
	
	push -50
	push 0
	push dword[SLIDER_RESOLUTION]
	call uiElement_setPosition
	
	push 69
	push dword[SLIDER_RESOLUTION]
	call uiSlider_setOnlyInteger
	
	push 0
	push dword[SLIDER_RESOLUTION]
	call uiSlider_setMinValue
	
	push dword[SEVEN]
	push dword[SLIDER_RESOLUTION]
	call uiSlider_setMaxValue
	
	push dword[TEXT_RESOLUTION_VALUE]
	push settingsLoop_resolutionOnValueChangedCallback
	push dword[SLIDER_RESOLUTION]
	call uiSlider_setOnValueChanged
	
	cvtsi2ss xmm0, dword[VALUE_RESOLUTION]
	sub esp, 4
	movss dword[esp], xmm0
	push dword[SLIDER_RESOLUTION]
	call uiSlider_setValue
	
	push dword[SLIDER_RESOLUTION]
	call uiSlider_getFill
	push 0
	push 0
	push eax
	call uiElement_setStatus
	
	push dword[SLIDER_RESOLUTION]
	call uiSlider_getKnob
	push 44
	push 44
	push eax
	call uiElement_setSize
	mov dword[esp+4], slider_knob_texture_path
	call uiImage_setTexture
	
	mov esp, ebp
	pop ebp
	ret
	
	
;void settingsLoop_renderDistanceOnValueChangedCallback(UISlider* slider, UIText* valueText)
settingsLoop_renderDistanceOnValueChangedCallback:
	push ebp
	mov ebp, esp
	
	sub esp, 100			;text buffer		100
	
	push dword[ebp+8]
	call uiSlider_getValue
	fistp dword[VALUE_RENDER_DISTANCE]
	
	push dword[VALUE_RENDER_DISTANCE]
	push print_render_distance
	lea eax, [ebp-100]
	push eax
	call my_sprintf
	
	lea eax, [ebp-100]
	push eax
	push dword[ebp+12]
	call uiText_setText
	
	mov esp, ebp
	pop ebp
	ret
	
	
;void settingsLoop_resolutionOnValueChangedCallback(UISlider* slider, UIText* valueText)
settingsLoop_resolutionOnValueChangedCallback:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;value (int)		4
	
	;get and round value
	push dword[ebp+8]
	call uiSlider_getValue
	frndint
	fistp dword[ebp-4]
	
	;set the value
	mov eax, dword[ebp-4]
	mov dword[VALUE_RESOLUTION], eax
	
	;set the text
	mov eax, dword[ebp-4]
	push dword[RESOLUTION_NAMES+4*eax]
	push dword[ebp+12]
	call uiText_setText
	
	mov esp, ebp
	pop ebp
	ret