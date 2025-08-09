[BITS 32]

;layout:
;struct UIElement{
;	int32 xPos, yPos;									0
;	int32 width, height;								8
;	int16 anchorX, anchorY;								16	//anchor is the origin point of the uielement coordinates (relative to parent)
;	int16 pivotX, pivotY;								20	//tesco pivot indicates the point whose coordinates are given by (xPos; yPos)
;	vector<UIElement*> children;						24
;	UIElement* parent;									40
;	//internal
;	int32 currentScreenPosX, currentScreenPosY;			44	//the position of the bottom left corner of the element in screen coordinates, where the bottom left corner of the screen is (0;0)
;	int32 currentScreenWidth, currentScreenHeight;		52
;	int32 isVisible;									60	//kaskades to children
;	int32 isInteractable;								64	//cascades to children
;	void (*render)(UIElement*, const mat4* projection);	68
;	void (*destroy)(UIElement*);						72	//clears up the element-specific parts (everything from byte 128 on), doesn't deallocate the element
;	void (*onWindowResize)(UIElement*, int w, int h)	76
;	void (*onClick)(UIElement*, void* param)			80
;	void* onClickParam;									84
;	padding of 104 bytes
;	arbitrary long additional data
;}	//at least 192 bytes

;if the anchor is set to UI_STRETCH, the xPos/yPos is considered the distance from the left/bottom side of the parent and the width/height is considered the distance from the right/top side of the parent
;the pivot is ignored in this case

;NOTE: negative sizes may not be handled correctly (easy fix, but it's faster without it due to using shr instead of idiv)

section .rodata use32

	CLICK_THRESHOLD equ 200				;ms

	UI_LEFT		dw	0b0001
	UI_BOTTOM	dw	0b0001
	UI_CENTER	dw	0b0010
	UI_RIGHT	dw	0b0100
	UI_TOP		dw	0b0100
	UI_STRETCH	dw 	0b1000

	global UI_LEFT
	global UI_BOTTOM
	global UI_CENTER
	global UI_RIGHT
	global UI_TOP
	global UI_STRETCH
	
	;types should be sequential
	UI_FIRST:
	UI_CANVAS	dd 0
	UI_IMAGE	dd 1
	UI_TEXT		dd 2
	UI_LAST:
	
	global UI_CANVAS
	global UI_IMAGE
	global UI_TEXT
	
	test_text db "kim dong un",10,0
	
	error_create_invalid_type db "uiElement_create: %d is not a valid element type",10,0
	error_render_not_initialized db "uiElement_render: call uiElement_init first fucko",10,0
	
	print_two_ints_nl db "%d %d",10,0
	print_two_floats_nl db "%f %f",10,0
	print_six_floats_nl db "%f %f %f %f %f %f",10,0
	
	ZERO dd 0.0
	ONE dd 1.0
	MINUS_ONE dd -1.0
	
section .data use32

	initialized dd 0
	
section .bss use32

	instantiated_vector resb 16			;vector<UIElement*>
	window_size_x resb 4				;int
	window_size_y resb 4				;int
	
	click_started resb 4				;int
	
section .text use32
	
	global uiElement_init		;void uiElement_init()
	global uiElement_deinit		;void uiElement_deinit()
	
	global uiElement_processInput	;void uiElement_processInput()
	
	global uiElement_createProjection	;void uiElement_createProjection(mat4* buffer, int screenWidth, int screenHeight)
	global uiElement_getScreenSize		;void uiElement_getScreenSize(int* width, int* height)
	
	;type can be for example dword[UI_IMAGE]
	;UIElement* uiElement_create(int type)
	global uiElement_create
	
	;destroys the children as well
	;also deallocates the memory
	;void uiElement_destroy(UIElement* element)
	global uiElement_destroy
	
	;renders the fatherless ui elements and their children
	;void uiElement_render(const mat4* projection)
	global uiElement_render

	global uiElement_setStatus					;void uiElement_setStatus(UIElement* element, int visible, int interactable)
	global uiElement_setPosition				;void uiElement_setPosition(UIElement* element, int xPos, int yPos)
	global uiElement_setSize					;void uiElement_setSize(UIElement* element, int width, int height)
	global uiElement_setAnchor					;void uiElement_setAnchor(UIElement* element, int16 anchorX, int16 anchorY)
	global uiElement_setPivot					;void uiElement_setPivot(UIElement* element, int16 pivotX, int16 pivotY)
	
	;void uiElement_setOnClick(
	;	UIElement* element,
	;	void (*onClick)(UIElement*, void* param),
	;	void* onClickParam)
	global uiElement_setOnClick
	
	;NULL means no parent
	;removes the element from the children of the former parent (no alimony then)
	;void uiElement_setParent(UIElement* element, UIElement* parent)
	global uiElement_setParent
	
	;helper function for creating a ui element
	;sets ALL function pointers to 0
	;void uiElement_initGeneralPart(UIElement* element)
	global uiElement_initGeneralPart
	
	extern my_free
	extern my_printf
	extern my_memset_dword
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove
	
	extern mat4_ortho
	
	extern WINDOW_SIZE_X
	extern WINDOW_SIZE_Y
	
	extern input_mousePosition
	extern input_mouseButtonPressed
	extern input_mouseButtonReleased
	extern GLFW_MOUSE_BUTTON_LEFT
	
	import GetTickCount kernel32.dll
	extern GetTickCount
	
	extern uiCanvas_init
	extern uiCanvas_deinit
	extern uiCanvas_create
	
	extern uiImage_init
	extern uiImage_deinit
	extern uiImage_create
	
	extern uiText_init
	extern uiText_deinit
	extern uiText_create
	
	
uiElement_init:
	push ebp
	mov ebp, esp
	
	;create instantiated vector
	push 4
	push instantiated_vector
	call vector_init
	add esp, 8
	
	;set window size
	mov dword[window_size_x], -1
	mov dword[window_size_y], -1
	
	;set everything else
	mov dword[click_started], -1
	
	;init subsystems
	call uiCanvas_init
	call uiImage_init
	call uiText_init
	
	;set initialized flag
	mov dword[initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	
uiElement_deinit:
	push ebp
	mov ebp, esp
	
	;unset initialized flag
	mov dword[initialized], 0
	
	;destroy remaining elements
	uiElement_deinit_loop_start:
		cmp dword[instantiated_vector], 0
		jle uiElement_deinit_loop_end
		
		;destroy element
		mov eax, instantiated_vector
		mov eax, dword[eax+12]
		push dword[eax]
		call uiElement_destroy
		add esp, 4
		
		jmp uiElement_deinit_loop_start
		
	uiElement_deinit_loop_end:
	
	;destroy the vector
	push instantiated_vector
	call vector_destroy
	add esp, 4
	
	;deinit subsystems
	call uiCanvas_deinit
	call uiImage_deinit
	call uiText_deinit
	
	mov esp, ebp
	pop ebp
	ret
	

uiElement_processInput:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	
	;window resize stuff -----------------------------
	
	;check if there was a window resize event
	mov eax, dword[WINDOW_SIZE_X]
	sub eax, dword[window_size_x]
	mov ecx, dword[WINDOW_SIZE_Y]
	sub ecx, dword[window_size_y]
	or eax, ecx
	test eax, eax
	jz uiElement_processInput_window_resize_skip
		call uiElement_processInput_windowResize_internal_helper
	uiElement_processInput_window_resize_skip:
	
	;mouse click
	call uiElement_processClick_internal
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
uiElement_render:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	;check if the system is initialized
	test dword[initialized], 0xffffffff
	jnz uiElement_render_initialized
		push error_render_not_initialized
		call my_printf
		jmp uiElement_render_end
	
	uiElement_render_initialized:

	;render fatherless elements
	mov eax, instantiated_vector
	mov esi, dword[eax+12]			;current element in esi
	mov edi, dword[eax]				;index in edi
	cmp edi, 0
	jle uiElement_render_loop_end
	uiElement_render_loop_start:
		;check if the element is fatherless
		mov eax, dword[esi]
		test dword[eax+40], 0xffffffff
		jnz uiElement_render_loop_continue
	
			;render child
			push dword[ebp+16]
			push dword[esi]
			call uiElement_render_internal
			add esp, 8
		
		uiElement_render_loop_continue:
		add esi, 4
		dec edi
		test edi, edi
		jnz uiElement_render_loop_start
	
	uiElement_render_loop_end:
	
	uiElement_render_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
	
uiElement_createProjection:
	push ebp
	mov ebp, esp
	
	push dword[ONE]
	push dword[MINUS_ONE]
	push dword[ebp+16]
	push 0
	push dword[ebp+12]
	push 0
	push dword[ebp+8]
	fild dword[esp+8]
	fstp dword[esp+8]
	fild dword[esp+16]
	fstp dword[esp+16]
	call mat4_ortho
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiElement_getScreenSize:
	mov eax, dword[esp+4]
	mov ecx, dword[window_size_x]
	mov dword[eax], ecx
	
	mov eax, dword[esp+8]
	mov ecx, dword[window_size_y]
	mov dword[eax], ecx
	
	ret
	
	
uiElement_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value		4
	
	mov dword[ebp-4], 0
	
	;check if the type is valid
	mov eax, dword[ebp+8]
	cmp eax, dword[UI_FIRST]
	jl uiElement_create_type_invalid
	mov ecx, UI_LAST
	cmp eax, dword[ecx-4]
	jg uiElement_create_type_invalid
	jmp uiElement_create_type_valid
	
	uiElement_create_type_invalid:
		;invalid type
		push dword[ebp+8]
		push error_create_invalid_type
		call my_printf
		add esp, 8
		
		jmp uiElement_create_done
		
	uiElement_create_type_valid:
	
	mov eax, uiElement_create_functions
	mov ecx, dword[ebp+8]
	call dword[eax+4*ecx]
	mov dword[ebp-4], eax
	jmp uiElement_create_done
	
	uiElement_create_functions:
	dd uiCanvas_create
	dd uiImage_create
	dd uiText_create
	uiElement_create_done:
	
	;was the element actually created?
	cmp dword[ebp-4], 0
	je uiElement_create_end
	
		;add the element to the instantiated vector
		push dword[ebp-4]
		push instantiated_vector
		call vector_push_back
		add esp, 8
	
	uiElement_create_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
uiElement_destroy:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	;remove from the instantiated vector
	push dword[ebp+16]
	push instantiated_vector
	call vector_remove
	add esp, 8
	
	;removes itself from the parent's children list
	push 0
	push dword[ebp+16]
	call uiElement_setParent
	add esp, 8
	
	;do a jeffrey epstein (destroy the children)
	;descending order is necessary
	mov eax, dword[ebp+16]
	mov esi, dword[eax+36]			;element array in esi
	mov edi, dword[eax+24]			;index in edi
	cmp edi, 0
	jle uiElement_destroy_loop_end
	uiElement_destroy_loop_start:
		push dword[esi+4*edi-4]		;last element
		call uiElement_destroy
		add esp, 4
		
		dec edi
		test edi, edi
		jnz uiElement_destroy_loop_start
		
	uiElement_destroy_loop_end:
	
	;destroy the specific part if necessary
	mov eax, dword[ebp+16]
	test dword[eax+72], 0xffffffff
	jz uiElement_destroy_no_custom_destroy
		push eax
		call dword[eax+72]
		add esp, 4
		
	uiElement_destroy_no_custom_destroy:
	
	;deinit the general part
	mov eax, dword[ebp+16]
	lea eax, [eax+24]
	push eax
	call vector_destroy
	add esp, 4
	
	;dealloc the memory
	push dword[ebp+16]
	call my_free
	add esp, 4
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
uiElement_setStatus:
	mov eax, dword[esp+4]
	
	mov ecx, dword[esp+8]
	mov edx, dword[esp+12]
	mov dword[eax+60], ecx
	mov dword[eax+64], edx
	
	ret
	
	
uiElement_setPosition:
	push ebp
	mov ebp, esp
	
	;set the new values
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp+12]
	mov dword[eax], ecx
	mov ecx, dword[ebp+16]
	mov dword[eax+4], ecx
	
	;refresh the element
	mov eax, dword[ebp+8]
	push dword[eax+40]		;parent
	push eax
	call uiElement_calculateCurrentPosition
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiElement_setSize:
	push ebp
	mov ebp, esp
	
	;set the new values
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp+12]
	mov dword[eax+8], ecx
	mov ecx, dword[ebp+16]
	mov dword[eax+12], ecx
	
	;refresh the element
	mov eax, dword[ebp+8]
	push dword[eax+40]		;parent
	push eax
	call uiElement_calculateCurrentPosition
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
uiElement_setAnchor:
	push ebp
	mov ebp, esp
	
	;set the new values
	mov eax, dword[ebp+8]
	
	mov cx, word[ebp+12]
	mov word[eax+16], cx
	mov cx, word[ebp+14]
	mov word[eax+18], cx
	
	;refresh the element
	mov eax, dword[ebp+8]
	push dword[eax+40]		;parent
	push eax
	call uiElement_calculateCurrentPosition
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiElement_setPivot:
	push ebp
	mov ebp, esp
	
	;set the new values
	mov eax, dword[ebp+8]
	
	mov cx, word[ebp+12]
	mov word[eax+20], cx
	mov cx, word[ebp+14]
	mov word[eax+22], cx
	
	;refresh the element
	mov eax, dword[ebp+8]
	push dword[eax+40]		;parent
	push eax
	call uiElement_calculateCurrentPosition
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiElement_setOnClick:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	mov edx, dword[esp+12]
	mov dword[eax+80], ecx
	mov dword[eax+84], edx
	ret
	

uiElement_setParent:
	push ebp
	mov ebp, esp
	
	;is the new parent the same as the old one
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	cmp dword[eax+40], ecx
	je uiElement_setParent_end
	
	;remove the element from the ex-parent
	mov eax, dword[ebp+8]
	cmp dword[eax+40], 0
	je uiElement_setParent_no_former_parent
		;yeet
		mov ecx, dword[eax+40]
		lea ecx, [ecx+24]		;ex-parent's children in ecx
		push eax
		push ecx
		call vector_remove
		add esp, 8
	
	uiElement_setParent_no_former_parent:
	
	;set the parent field to the new one
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	mov dword[eax+40], ecx
	
	;add the element to the children of the new parent
	cmp dword[ebp+12], 0
	je uiElement_setParent_no_new_parent
		;add
		mov eax, dword[ebp+12]
		lea eax, [eax+24]
		push dword[ebp+8]
		push eax
		call vector_push_back
		add esp, 8
		
	uiElement_setParent_no_new_parent:
	
	;refresh the element
	mov eax, dword[ebp+8]
	push dword[eax+40]
	push eax
	call uiElement_calculateCurrentPosition
	add esp, 8
	
	
	uiElement_setParent_end:
	mov esp, ebp
	pop ebp
	ret
	
	
uiElement_initGeneralPart:
	push ebp
	mov ebp, esp
	
	;zero out everything
	push 192
	push 0
	push dword[ebp+8]
	call my_memset_dword
	add esp, 12
	
	;set things
	;default alignment is bottom left (both for anchor and pivot)
	;default size is 100x100
	;default position is (0;0)
	push word[UI_LEFT]
	push word[UI_BOTTOM]
	push word[UI_LEFT]
	push word[UI_BOTTOM]
	push 100
	push 100
	push 0
	push 0
	push dword[ebp+8]
	call uiElement_setEverything
	add esp, 28
	
	;set isVisible
	mov eax, dword[ebp+8]
	mov dword[eax+60], 69
	
	;create children vector
	mov eax, dword[ebp+8]
	lea eax, [eax+24]
	push 4
	push eax
	call vector_init
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
	
;internal functions

;parent==NULL if root element	
;void uiElement_calculateCurrentPosition(UIElement* element, UIElement* parent)
uiElement_calculateCurrentPosition:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;x position			4
	sub esp, 4			;y position			8
	sub esp, 4			;width				12
	sub esp, 4			;height				16
	
	sub esp, 4			;parent x position	20
	sub esp, 4			;parent y position	24
	sub esp, 4			;parent width		28
	sub esp, 4			;parent height		32
	
	
	;check if there is a parent
	test dword[ebp+12], 0xffffffff
	jnz uiElement_calculateCurrentPosition_parent
		;if no parent, parent position is 0 and parent size is screen size
		mov dword[ebp-20], 0
		mov dword[ebp-24], 0
		mov eax, dword[window_size_x]
		mov dword[ebp-28], eax
		mov ecx, dword[window_size_y]
		mov dword[ebp-32], ecx
		jmp uiElement_calculateCurrentPosition_parent_done
		
		uiElement_calculateCurrentPosition_parent:
		mov eax, dword[ebp+12]
		
		mov ecx, dword[eax+44]
		mov dword[ebp-20], ecx
		mov edx, dword[eax+48]
		mov dword[ebp-24], edx
		mov ecx, dword[eax+52]
		mov dword[ebp-28], ecx
		mov edx, dword[eax+56]
		mov dword[ebp-32], edx
	
	uiElement_calculateCurrentPosition_parent_done:
	
	;calculate x position	-----------------------------------------------
	;set x width
	mov eax, dword[ebp+8]
	mov ecx, dword[eax+8]
	mov dword[ebp-12], ecx
	
	;calculate x position based on the anchor
	mov eax, dword[ebp+8]
	
	mov cx, word[UI_RIGHT]
	test word[eax+16], cx
	jnz uiElement_calculateCurrentPosition_anchor_x_right
	
	mov cx, word[UI_CENTER]
	test word[eax+16], cx
	jnz uiElement_calculateCurrentPosition_anchor_x_center
	
	mov cx, word[UI_STRETCH]
	test word[eax+16], cx
	jnz uiElement_calculateCurrentPosition_anchor_x_stretch
		;left
		mov edx, dword[eax]
		mov dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_anchor_x_done
	
	uiElement_calculateCurrentPosition_anchor_x_center:
		;center
		mov edx, dword[ebp-28]
		shr edx, 1
		add edx, dword[eax]
		mov dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_anchor_x_done
	
	uiElement_calculateCurrentPosition_anchor_x_right:
		;right
		mov edx, dword[ebp-28]
		sub edx, dword[eax]
		mov dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_anchor_x_done
		
	uiElement_calculateCurrentPosition_anchor_x_stretch:
		;stretch
		mov edx, dword[ebp-20]
		add edx, dword[eax]
		mov dword[ebp-4], edx
		
		mov edx, dword[ebp-20]
		add edx, dword[ebp-28]
		sub edx, dword[eax+8]		;in stretch mode width is the distance from the right side of the parent
		sub edx, dword[ebp-4]
		mov dword[ebp-12], edx		;new width as well
		jmp uiElement_calculateCurrentPosition_x_done		;pivot is irrelevant
	
	uiElement_calculateCurrentPosition_anchor_x_done:
	
	
	;adjust x position based on the pivot
	mov eax, dword[ebp+8]
	
	mov cx, word[UI_RIGHT]
	test word[eax+20], cx
	jnz uiElement_calculateCurrentPosition_pivot_x_right
	
	mov cx, word[UI_CENTER]
	test word[eax+20], cx
	jnz uiElement_calculateCurrentPosition_pivot_x_center
		;left
		;nothing to do
		jmp uiElement_calculateCurrentPosition_pivot_x_done
	
	uiElement_calculateCurrentPosition_pivot_x_center:
		;center
		mov edx, dword[eax+8]
		shr edx, 1
		sub dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_pivot_x_done
	
	uiElement_calculateCurrentPosition_pivot_x_right:
		;right
		mov edx, dword[eax+8]
		sub dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_pivot_x_done
	
	uiElement_calculateCurrentPosition_pivot_x_done:
	
	uiElement_calculateCurrentPosition_x_done:
	
	;calculate y position	-----------------------------------------------
	;set height
	mov eax, dword[ebp+8]
	mov ecx, dword[eax+12]
	mov dword[ebp-16], ecx
	
	;calculate y position based on the anchor
	mov eax, dword[ebp+8]
	
	mov cx, word[UI_TOP]
	test word[eax+18], cx
	jnz uiElement_calculateCurrentPosition_anchor_y_top
	
	mov cx, word[UI_CENTER]
	test word[eax+18], cx
	jnz uiElement_calculateCurrentPosition_anchor_y_center
	
	mov cx, word[UI_STRETCH]
	test word[eax+18], cx
	jnz uiElement_calculateCurrentPosition_anchor_y_stretch
	
		;left
		mov edx, dword[eax+4]
		mov dword[ebp-8], edx
		jmp uiElement_calculateCurrentPosition_anchor_y_done
	
	uiElement_calculateCurrentPosition_anchor_y_center:
		;center
		mov edx, dword[ebp-32]
		shr edx, 1
		add edx, dword[eax+4]
		mov dword[ebp-8], edx
		jmp uiElement_calculateCurrentPosition_anchor_y_done
	
	uiElement_calculateCurrentPosition_anchor_y_top:
		;top
		mov edx, dword[ebp-32]
		sub edx, dword[eax+4]
		mov dword[ebp-8], edx
		jmp uiElement_calculateCurrentPosition_anchor_y_done
		
	uiElement_calculateCurrentPosition_anchor_y_stretch:
		;stretch
		mov edx, dword[ebp-24]
		add edx, dword[eax+4]
		mov dword[ebp-8], edx
		
		mov edx, dword[ebp-24]
		add edx, dword[ebp-32]
		sub edx, dword[eax+12]		;in stretch mode height is the distance from the top side of the parent
		sub edx, dword[ebp-8]
		mov dword[ebp-16], edx		;new height as well
		jmp uiElement_calculateCurrentPosition_y_done		;pivot is irrelevant
	
	uiElement_calculateCurrentPosition_anchor_y_done:
	
	;adjust y position based on the pivot
	mov eax, dword[ebp+8]
	
	mov cx, word[UI_TOP]
	test word[eax+22], cx
	jnz uiElement_calculateCurrentPosition_pivot_y_top
	
	mov cx, word[UI_CENTER]
	test word[eax+22], cx
	jnz uiElement_calculateCurrentPosition_pivot_y_center
		;left
		;nothing to do
		jmp uiElement_calculateCurrentPosition_pivot_y_done
	
	uiElement_calculateCurrentPosition_pivot_y_center:
		;center
		mov edx, dword[eax+12]
		shr edx, 1
		sub dword[ebp-8], edx
		jmp uiElement_calculateCurrentPosition_pivot_y_done
	
	uiElement_calculateCurrentPosition_pivot_y_top:
		;top
		mov edx, dword[eax+12]
		sub dword[ebp-8], edx
		jmp uiElement_calculateCurrentPosition_pivot_y_done
	
	uiElement_calculateCurrentPosition_pivot_y_done:
	
	uiElement_calculateCurrentPosition_y_done:
	
	;add the current position of the parent to the current position
	mov ecx, dword[ebp-20]
	add dword[ebp-4], ecx
	mov ecx, dword[ebp-24]
	add dword[ebp-8], ecx
	
	;copy the results
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp-4]
	mov dword[eax+44], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+48], ecx
	mov ecx, dword[ebp-12]
	mov dword[eax+52], ecx
	mov ecx, dword[ebp-16]
	mov dword[eax+56], ecx
	
	;calculate the results for the children as well
	uiElement_calculateCurrentPosition_calculate_children:
	mov eax, dword[ebp+8]
	cmp dword[eax+24], 0		;is there a child?
	jle uiElement_calculateCurrentPosition_end
	
	push esi		;save esi
	push edi		;save edi
	
	mov esi, dword[eax+36]		;current element in esi
	mov edi, dword[eax+24]		;index in edi
	uiElement_calculateCurrentPosition_calculate_children_loop_start:
		push dword[ebp+8]
		push dword[esi]
		call uiElement_calculateCurrentPosition
		add esp, 8
	
		add esi, 4
		dec edi
		test edi, edi
		jnz uiElement_calculateCurrentPosition_calculate_children_loop_start
	
	pop edi			;restore edi
	pop esi			;restore esi
	
	uiElement_calculateCurrentPosition_end:
	mov esp, ebp
	pop ebp
	ret

;so that only one recalculation happens	
;void uiElement_setEverything(
;	UIElement* element,
;	int xPos, int yPos,
;	int width, int height,
;	int16 anchorX, int16 anchorY,
;	int16 pivotX, int16 pivotY
;)
uiElement_setEverything:
	push ebp
	mov ebp, esp
	
	;set values
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp+12]
	mov dword[eax], ecx			;x pos
	mov ecx, dword[ebp+16]
	mov dword[eax+4], ecx		;y pos
	
	mov ecx, dword[ebp+20]
	mov dword[eax+8], ecx		;width
	mov ecx, dword[ebp+24]
	mov dword[eax+12], ecx		;height
	
	mov ecx, dword[ebp+28]
	mov dword[eax+16], ecx		;x and y anchors
	mov ecx, dword[ebp+32]
	mov dword[eax+20], ecx		;x and y pivots
	
	;refresh element
	mov eax, dword[ebp+8]
	
	push dword[eax+40]
	push eax
	call uiElement_calculateCurrentPosition
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
;void uiElement_render_internal(UIElement* element, const mat4* projection)
uiElement_render_internal:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	;check if the element is visible and head out if nah
	mov eax, dword[ebp+16]
	test dword[eax+60], 0xffffffff
	jz uiElement_render_internal_end
	
	;render itself if there is a function
	test dword[eax+68], 0xffffffff
	jz uiElement_render_internal_no_bitches
		push dword[ebp+20]
		push eax
		call dword[eax+68]
		add esp, 8
		
	uiElement_render_internal_no_bitches:
	
	;render children
	mov eax, dword[ebp+16]
	mov esi, dword[eax+36]				;current child in esi
	mov edi, dword[eax+24]				;index in edi
	cmp edi, 0
	jle uiElement_render_internal_loop_end
	uiElement_render_internal_loop_start:
		;render child
		push dword[ebp+20]
		push dword[esi]
		call uiElement_render_internal
		add esp, 8
		
		add esi, 4
		dec edi
		test edi, edi
		jnz uiElement_render_internal_loop_start
	
	uiElement_render_internal_loop_end:
	
	uiElement_render_internal_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
;calls uiElement_processClick_internal_helper on the elements that are fatherless
;void uiElement_processClick_internal()
uiElement_processClick_internal:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;cursor x		4
	sub esp, 4			;cursor y		8
	
	;check if a potential click is starting
	push dword[GLFW_MOUSE_BUTTON_LEFT]
	call input_mouseButtonPressed
	test eax, 0xffffffff
	jz uiElement_processClick_internal_no_press
		call [GetTickCount]
		mov dword[click_started], eax
		
	uiElement_processClick_internal_no_press:
	
	;check if a potential click is ending
	push dword[GLFW_MOUSE_BUTTON_LEFT]
	call input_mouseButtonReleased
	test eax, 0xffffffff
	jz uiElement_processClick_internal_end
	
	call [GetTickCount]
	sub eax, dword[click_started]
	cmp eax, CLICK_THRESHOLD
	jg uiElement_processClick_internal_end	;no click
	
	;get the cursor position
	lea eax, [ebp-4]
	lea ecx, [ebp-8]
	push ecx
	push eax
	call input_mousePosition
	add esp, 8
	
	mov eax, dword[window_size_y]
	sub eax, dword[ebp-8]
	mov dword[ebp-8], eax
	
	
	;call the onClick callback of the first suitable element
	mov eax, instantiated_vector
	mov esi, dword[eax+12]			;elements in esi
	mov edi, dword[eax]				;index in edi
	cmp edi, 0
	jle uiElement_processClick_internal_end
	uiElement_processClick_internal_loop_start:
		;check if the element is fatherless
		mov eax, dword[esi]
		test dword[eax+40], 0xffffffff
		jnz uiElement_processClick_internal_loop_continue		
			;call the helper if fatherless
			push dword[ebp-8]
			push dword[ebp-4]
			push eax
			call uiElement_processClick_internal_helper
			add esp, 12
		
		uiElement_processClick_internal_loop_continue:
		add esi, 4
		dec edi
		test edi, edi
		jnz uiElement_processClick_internal_loop_start
	
	uiElement_processClick_internal_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
	
;calls itself on the children of the element
;if no children ate the click event, the element is tested as a click target
;returns non-zero if the click landed on a suitable target (cursor position is appropriate, interactable and has an onClick callback defined)
;returns if the element is non-interactable
;int uiElement_processClick_internal_helper(UIElement* element, int cursorX, int cursorY)
uiElement_processClick_internal_helper:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;click landed		4
	sub esp, 4			;helper				8
	
	mov dword[ebp-4], 0
	
	;check if the current element is interactable
	mov eax, dword[ebp+16]
	test dword[eax+64], 0xffffffff
	jz uiElement_processClick_internal_helper_end
	
	;check if children are clickable
	mov eax, dword[ebp+16]
	mov esi, dword[eax+36]		;children in esi
	mov edi, dword[eax+24]		;index in edi
	cmp edi, 0
	jle uiElement_processClick_internal_helper_children_loop_end
	uiElement_processClick_internal_helper_children_loop_start:
		push dword[ebp+24]
		push dword[ebp+20]
		push dword[esi]
		call uiElement_processClick_internal_helper
		or dword[ebp-4], eax
		add esp, 12
		
		;has the click landed?
		test eax, eax
		jnz uiElement_processClick_internal_helper_children_loop_end
		
		add esi, 4
		dec edi
		test edi, edi
		jnz uiElement_processClick_internal_helper_children_loop_start
		
	uiElement_processClick_internal_helper_children_loop_end:
	
	;return if the click has landed
	test dword[ebp-4], 0xffffffff
	jnz uiElement_processClick_internal_helper_end
	
	
	;check if the current element has an onClick callback
	mov eax, dword[ebp+16]
	test dword[eax+80], 0xffffffff
	jz uiElement_processClick_internal_helper_end
	
	
	;check if the click is inside the element
	;cursorX-posX is in [0; width]
	;cursorY-posY is in [0; height]
	mov ecx, dword[ebp+20]
	mov edx, dword[ebp+24]
	sub ecx, dword[eax+44]
	sub edx, dword[eax+48]
	
	test ecx, 0x80000000
	jnz uiElement_processClick_internal_helper_end
	test edx, 0x80000000
	jnz uiElement_processClick_internal_helper_end
	cmp ecx, dword[eax+8]
	jg uiElement_processClick_internal_helper_end
	cmp edx, dword[eax+12]
	jg uiElement_processClick_internal_helper_end
	
	;call the onClick callback and set the return value
	push dword[eax+84]
	push eax
	call dword[eax+80]
	
	mov dword[ebp-4], 69
	
	
	uiElement_processClick_internal_helper_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	

;recalculates the position of every fatherless stretchy element
;calls onWindowResize callbacks if necessary
;void uiElement_processInput_windowResizeHelper_internal()
uiElement_processInput_windowResize_internal_helper:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;update the window size 
	mov eax, dword[WINDOW_SIZE_X]
	mov dword[window_size_x], eax
	mov ecx, dword[WINDOW_SIZE_Y]
	mov dword[window_size_y], ecx
	
	;recalcuate the position of the stretchy fatherless elements
	mov eax, instantiated_vector
	mov esi, dword[eax+12]			;elements in esi
	mov edi, dword[eax]				;index in edi
	cmp edi, 0
	jle uiElement_processInput_windowResize_internal_helper_fatherless_loop_end
	uiElement_processInput_windowResize_internal_helper_fatherless_loop_start:
		mov ebx, dword[esi]
		;fatherless?
		test dword[ebx+40], 0xffffffff
		jnz uiElement_processInput_windowResize_internal_helper_fatherless_loop_continue
		;stretchy?
		mov ax, word[UI_STRETCH]
		cmp word[ebx+16], ax
		je uiElement_processInput_windowResize_internal_helper_fatherless_loop_must_recalculate
		cmp word[ebx+18], ax
		je uiElement_processInput_windowResize_internal_helper_fatherless_loop_must_recalculate
		jmp uiElement_processInput_windowResize_internal_helper_fatherless_loop_continue
		
		uiElement_processInput_windowResize_internal_helper_fatherless_loop_must_recalculate:
			;call recalculate
			push 0
			push ebx
			call uiElement_calculateCurrentPosition
			add esp, 8
		
		uiElement_processInput_windowResize_internal_helper_fatherless_loop_continue:
		add esi, 4
		dec edi
		test edi, edi
		jnz uiElement_processInput_windowResize_internal_helper_fatherless_loop_start
	uiElement_processInput_windowResize_internal_helper_fatherless_loop_end:
	

	;call the window resize callbacks if necessary
	;from last element to first
	mov eax, instantiated_vector
	mov esi, dword[eax]			;index in esi
	mov edi, dword[eax+12]		;data in edi
	cmp esi, 0
	jle uiElement_processInput_windowResize_internal_helper_window_resize_loop_end
	uiElement_processInput_windowResize_internal_helper_window_resize_loop_start:
		mov ebx, dword[edi+4*esi-4]		;current ui element in ebx
		test dword[ebx+76], 0xffffffff
		jz uiElement_processInput_windowResize_internal_helper_window_resize_loop_continue
			push dword[window_size_y]
			push dword[window_size_x]
			push ebx
			call dword[ebx+76]
			add esp, 12
	
		uiElement_processInput_windowResize_internal_helper_window_resize_loop_continue:
		dec esi
		test esi, esi
		jnz uiElement_processInput_windowResize_internal_helper_window_resize_loop_start
		
	uiElement_processInput_windowResize_internal_helper_window_resize_loop_end:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret