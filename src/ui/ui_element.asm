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
;
;	padding of 12 bytes
;	int32 isInteractable;								64
;	void (*render)(UIElement*, const mat4* projection);	68
;	void (*destroy)(UIElement*);						72
;	void (*onWindowResize)(UIElement*, int w, int h)	76
;	void (*onClick)(UIElement*, void* param)			80
;	void* onClickParam;									84
;	padding of 40 bytes
;	arbitrary long additional data
;}	//at least 128 bytes


section .rodata use32

	UI_LEFT		dw	0b001
	UI_BOTTOM	dw	0b001
	UI_CENTER	dw	0b010
	UI_RIGHT	dw	0b100
	UI_TOP		dw	0b100

	global UI_LEFT
	global UI_BOTTOM
	global UI_CENTER
	global UI_RIGHT
	global UI_TOP
	
	;types should be sequential
	UI_FIRST:
	UI_CANVAS	dd 0
	UI_IMAGE	dd 1
	UI_LAST:
	
	global UI_CANVAS
	global UI_IMAGE
	
	error_create_invalid_type db "uiElement_create: %d is not a valid element type",10,0
	
section .text use32
	
	;type can be for example dword[UI_IMAGE]
	;UIElement* uiElement_create(int type)
	global uiElement_create
	
	;destroys the children as well
	;also deallocates the memory
	;void uiElement_destroy(UIElement* element)
	global uiElement_destroy
	
	global uiElement_render						;void uiElement_render(UIElement* element, const mat4* projection)

	global uiElement_setPosition				;void uiElement_setPosition(UIElement* element, int xPos, int yPos)
	global uiElement_setSize					;void uiElement_setSize(UIElement* element, int width, int height)
	global uiElement_setAnchor					;void uiElement_setAnchor(UIElement* element, int16 anchorX, int16 anchorY)
	global uiElement_setPivot					;void uiElement_setPivot(UIElement* element, int16 pivotX, int16 pivotY)
	
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
	
	extern uiCanvas_create
	
	
uiElement_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value		4
	
	mov dword[ebp-4], 0
	
	;check if the type is valid
	mov eax, dword[ebp+8]
	cmp eax, dword[CANVAS_FIRST]
	jl uiElement_create_type_invalid
	mov ecx, dword[CANVAS_LAST]
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
	
	mov eax, uiElement_create_switch
	mov ecx, dword[ebp+8]
	jmp dword[eax+4*ecx]
	
	uiElement_create_switch:
	dd uiElement_create_canvas
	dd uiElement_create_image
	
	uiElement_create_canvas:
		;create canvas
		call uiCanvas_create
		mov dword[ebp-4], eax
		jmp uiElement_create_done
		
	uiElement_create_image:
		;create image
		
		jmp uiElement_create_done
	
	uiElement_create_done:
	
	
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
	
	
uiElement_render:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	;render itself if there is a function
	mov eax, dword[ebp+16]
	test dword[eax+68], 0xffffffff
	jz uiElement_render_no_bitches
		push dword[ebp+20]
		push eax
		call dword[eax+68]
		add esp, 8
		
	uiElement_render_no_bitches:
	
	;render children
	mov eax, dword[ebp+16]
	mov esi, dword[eax+36]				;current child in esi
	mov edi, dword[eax+24]				;index in edi
	cmp edi, 0
	jle uiElement_render_loop_end
	uiElement_render_loop_start:
		;render child
		push dword[ebp+20]
		push dword[esi]
		call uiElement_render
		add esp, 8
		
		add esi, 4
		dec edi
		test edi, edi
		jnz uiElement_render_loop_start
	
	uiElement_render_loop_end:
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
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
	
	uiElement_setParent_end:
	mov esp, ebp
	pop ebp
	ret
	
	
uiElement_initGeneralPart:
	push ebp
	mov ebp, esp
	
	;zero out everything
	push 128
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
	
	sub esp, 4			;x position		4
	sub esp, 4			;y position		8
	
	;check if there is a parent
	test dword[ebp+12], 0xffffffff
	jnz uiElement_calculateCurrentPosition_parent
		;if no parent, current position is position
		mov eax, dword[ebp+8]
		
		mov edx, dword[eax]
		mov dword[eax+44], edx
		mov edx, dword[eax+4]
		mov dword[eax+48], edx
		
		jmp uiElement_calculateCurrentPosition_calculate_children
	
	uiElement_calculateCurrentPosition_parent:
	
	;calculate x position based on the anchor
	mov eax, dword[ebp+8]
	
	mov cx, word[UI_RIGHT]
	test word[eax+16], cx
	jnz uiElement_calculateCurrentPosition_anchor_x_right
	
	mov cx, word[UI_CENTER]
	test word[eax+16], cx
	jnz uiElement_calculateCurrentPosition_anchor_x_center
		;left
		mov edx, dword[eax]
		mov dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_anchor_x_done
	
	uiElement_calculateCurrentPosition_anchor_x_center:
		;center
		mov ecx, dword[ebp+12]		;parent in ecx
		mov edx, dword[ecx+8]
		shr edx, 1
		add edx, dword[eax]
		mov dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_anchor_x_done
	
	uiElement_calculateCurrentPosition_anchor_x_right:
		;right
		mov ecx, dword[ebp+12]		;parent in ecx
		mov edx, dword[ecx+8]
		sub edx, dword[eax]
		mov dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_anchor_x_done
	
	uiElement_calculateCurrentPosition_anchor_x_done:
	
	
	;calculate y position based on the anchor
	mov eax, dword[ebp+8]
	
	mov cx, word[UI_TOP]
	test word[eax+18], cx
	jnz uiElement_calculateCurrentPosition_anchor_y_top
	
	mov cx, word[UI_CENTER]
	test word[eax+18], cx
	jnz uiElement_calculateCurrentPosition_anchor_y_center
		;left
		mov edx, dword[eax+4]
		mov dword[ebp-8], edx
		jmp uiElement_calculateCurrentPosition_anchor_y_done
	
	uiElement_calculateCurrentPosition_anchor_y_center:
		;center
		mov ecx, dword[ebp+12]		;parent in ecx
		mov edx, dword[ecx+12]
		shr edx, 1
		add edx, dword[eax+4]
		mov dword[ebp-8], edx
		jmp uiElement_calculateCurrentPosition_anchor_y_done
	
	uiElement_calculateCurrentPosition_anchor_y_top:
		;top
		mov ecx, dword[ebp+12]		;parent in ecx
		mov edx, dword[ecx+12]
		sub edx, dword[eax+4]
		mov dword[ebp-4], edx
		jmp uiElement_calculateCurrentPosition_anchor_y_done
	
	uiElement_calculateCurrentPosition_anchor_y_done:
	
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
	
	
	;add the current position of the parent to the current position
	mov eax, dword[ebp+12]
	
	mov ecx, dword[eax+44]
	add dword[ebp-4], ecx
	mov ecx, dword[eax+48]
	add dword[ebp-8], ecx
	
	;copy the results
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp-4]
	mov dword[eax+44], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+48], ecx
	
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