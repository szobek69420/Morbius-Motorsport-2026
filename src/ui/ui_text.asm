[BITS 32]

;layout:
;struct UIText{
;	<UIElement>
;	char* text;									128	//NULL means kein text
;	float colourR, colourG, colourB, colourA;	132
;	int spacing;								148
;	int fontWidth, fontHeight;					152
;	int16 textAlignX, textAlignY;				160
;}	164 bytes

section .rodata use32
	UI_TEXT_ALIGN_LEFT		dw 0b001
	UI_TEXT_ALIGN_BOTTOM	dw 0b001
	UI_TEXT_ALIGN_CENTER	dw 0b010
	UI_TEXT_ALIGN_RIGHT		dw 0b100
	UI_TEXT_ALIGN_TOP		dw 0b100
	
	global UI_TEXT_ALIGN_LEFT
	global UI_TEXT_ALIGN_BOTTOM
	global UI_TEXT_ALIGN_CENTER
	global UI_TEXT_ALIGN_RIGHT
	global UI_TEXT_ALIGN_TOP
	
	test_text db "Mikhail Morbachev",10,0

	debug_text_destroy db "ui_text destroyed",10,0
	
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0

	ONE dd 1.0
	
section .bss use32
	;default values
	default_spacing 	resb 4		;int
	default_font_width	resb 4		;int
	default_font_height	resb 4		;int
	default_colour_rgba	resb 16		;vec4

section .text use32
	global uiText_init					;void uiText_init()
	global uiText_deinit				;void uiText_deinit()
	
	global uiText_create				;UIText* uiText_create()
	
	global uiText_setText				;void uiText_setText(UIText* element, const char* nullableText)
	global uiText_setColour				;void uiText_setColour(UIText* text, float r, float g, float b, float a)
	global uiText_setSpacing			;void uiText_setSpacing(UIText* text, int spacing)
	global uiText_setFontSize			;void uiText_setFontSize(UIText* text, int fontWidth, int fontHeight)
	global uiText_setTextAlignment		;void uiText_setTextAlignment(UIText* text, int16 xAlign, int16 yAlign) //expects arguments like word[UI_TEXT_ALIGN_LEFT]
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy
	extern my_strlen
	extern my_strcpy
	
	extern FONT_CHAR_WIDTH
	extern FONT_CHAR_HEIGHT
	
	extern textRenderer_drawText
	extern textRenderer_setScreenSize
	extern textRenderer_setFontSize
	extern textRenderer_setSpacing
	extern textRenderer_setColour
	extern TEXT_ORIGIN_BOTTOM_LEFT
	extern TEXT_PIVOT_BOTTOM_LEFT
	extern TEXT_PIVOT_BOTTOM_CENTER
	extern TEXT_PIVOT_BOTTOM_RIGHT
	extern TEXT_PIVOT_CENTER_LEFT
	extern TEXT_PIVOT_CENTER_CENTER
	extern TEXT_PIVOT_CENTER_RIGHT
	extern TEXT_PIVOT_TOP_LEFT
	extern TEXT_PIVOT_TOP_CENTER
	extern TEXT_PIVOT_TOP_RIGHT
	
	extern uiElement_initGeneralPart
	extern uiElement_getScreenSize
	
uiText_init:
	;set default values
	mov eax, dword[FONT_CHAR_WIDTH]
	shl eax, 1
	mov dword[default_font_width], eax
	mov eax, dword[FONT_CHAR_HEIGHT]
	shl eax, 1
	mov dword[default_font_height], eax
	
	mov dword[default_spacing], 3
	
	movss xmm0, dword[ONE]
	shufps xmm0, xmm0, 0b00000000
	movups [default_colour_rgba], xmm0

	ret
	
	
uiText_deinit:
	ret
	
uiText_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;element		4
	
	;alloc space
	push 164
	call my_malloc
	mov dword[ebp-4], eax
	
	;init general part
	push dword[ebp-4]
	call uiElement_initGeneralPart
	
	;set destroy and render functions
	mov eax, dword[ebp-4]
	mov dword[eax+68], uiText_render
	mov dword[eax+72], uiText_destroy
	
	;set initial values
	mov eax, dword[ebp-4]
	
	mov dword[eax+128], 0
	
	mov eax, dword[ebp-4]
	mov ecx, dword[default_spacing]
	mov dword[eax+148], ecx
	mov ecx, dword[default_font_width]
	mov dword[eax+152], ecx
	mov ecx, dword[default_font_height]
	mov dword[eax+156], ecx
	mov cx, word[UI_TEXT_ALIGN_CENTER]
	mov word[eax+160], cx
	mov word[eax+162], cx
	
	lea ecx, [eax+132]
	push 16
	push default_colour_rgba
	push ecx
	call my_memcpy
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiText_setText:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;new text		4
	
	mov dword[ebp-4], 0
	
	;check if the new text is NULL
	cmp dword[ebp+12], 0
	je uiText_setText_no_new_text
		push dword[ebp+12]
		call my_strlen
		
		inc eax
		push eax
		call my_malloc
		mov dword[ebp-4], eax
		
		push dword[ebp+12]
		push eax
		call my_strcpy
		
	uiText_setText_no_new_text:
	
	;delete previous text
	mov eax, dword[ebp+8]
	push dword[eax+128]
	call my_free
	
	;set new text
	mov eax, dword[ebp-4]
	mov ecx, dword[ebp+8]
	mov dword[ecx+128], eax
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiText_setColour:
	mov eax, dword[esp+4]
	
	mov ecx, dword[esp+8]
	mov dword[eax+132], ecx
	mov edx, dword[esp+12]
	mov dword[eax+136], edx
	mov ecx, dword[esp+16]
	mov dword[eax+140], ecx
	mov edx, dword[esp+20]
	mov dword[eax+144], edx
	
	ret
	
	
uiText_setSpacing:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	mov dword[eax+148], ecx
	ret
	
	
uiText_setFontSize:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	mov edx, dword[esp+12]
	mov dword[eax+152], ecx
	mov dword[eax+156], edx
	ret
	
uiText_setTextAlignment:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	mov dword[eax+160], ecx
	ret
	
;internal functions ---------------------------------------------

;void uiText_destroy(UIText* text)
uiText_destroy:
	push ebp
	mov ebp, esp
	
	;free text
	mov eax, dword[ebp+8]
	push dword[eax+128]
	call my_free
	
	push debug_text_destroy
	call my_printf
	
	mov esp, ebp
	pop ebp
	ret
	
;void uiText_render(UIText* text, const mat4* projection)
uiText_render:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;text pos x		4
	sub esp, 4		;text pos y		8
	sub esp, 4		;screen width	12
	sub esp, 4		;screen height	16
	sub esp, 4		;alignment		20
	
	;check if the text is NULL
	mov eax, dword[ebp+8]
	cmp dword[eax+128], 0
	je uiText_render_end
	
	mov eax, dword[TEXT_PIVOT_CENTER_CENTER]
	mov dword[ebp-20], eax
	
	;set the text renderer state
	lea eax, [ebp-12]
	lea ecx, [ebp-16]
	push ecx
	push eax
	call uiElement_getScreenSize
	
	push dword[ebp-16]
	push dword[ebp-12]
	call textRenderer_setScreenSize
	
	mov eax, dword[ebp+8]
	push dword[eax+156]
	push dword[eax+152]
	push dword[eax+148]
	call textRenderer_setSpacing
	add esp, 4
	call textRenderer_setFontSize
	
	mov eax, dword[ebp+8]
	push dword[eax+144]
	push dword[eax+140]
	push dword[eax+136]
	push dword[eax+132]
	call textRenderer_setColour
	
	;calculate the text position
	;horizontal part
	mov eax, dword[ebp+8]
	mov cx, word[eax+160]
	cmp cx, word[UI_TEXT_ALIGN_CENTER]
	je uiText_render_hpos_center
	cmp cx, word[UI_TEXT_ALIGN_RIGHT]
	je uiText_render_hpos_right
		;left
		mov ecx, dword[eax+44]
		mov dword[ebp-4], ecx
		jmp uiText_render_hpos_done
		
	uiText_render_hpos_center:
		;center
		mov ecx, dword[eax+8]
		shr ecx, 1
		add ecx, dword[eax+44]
		mov dword[ebp-4], ecx
		jmp uiText_render_hpos_done
	
	uiText_render_hpos_right:
		;right
		mov ecx, dword[eax+8]
		add ecx, dword[eax+44]
		mov dword[ebp-4], ecx
		jmp uiText_render_hpos_done
	
	uiText_render_hpos_done:
	
	;vertical part
	mov eax, dword[ebp+8]
	mov cx, word[eax+162]
	cmp cx, word[UI_TEXT_ALIGN_CENTER]
	je uiText_render_vpos_center
	cmp cx, word[UI_TEXT_ALIGN_TOP]
	je uiText_render_vpos_top
		;bottom
		mov ecx, dword[eax+48]
		mov dword[ebp-8], ecx
		jmp uiText_render_vpos_done
		
	uiText_render_vpos_center:
		;center
		mov ecx, dword[eax+12]
		shr ecx, 1
		add ecx, dword[eax+48]
		mov dword[ebp-8], ecx
		jmp uiText_render_vpos_done
	
	uiText_render_vpos_top:
		;top
		mov ecx, dword[eax+12]
		add ecx, dword[eax+48]
		mov dword[ebp-8], ecx
		jmp uiText_render_vpos_done
	
	uiText_render_vpos_done:
	
	;get the current alignment
	mov eax, dword[ebp+8]
	mov cx, word[eax+162]
	shl ecx, 16
	mov cx, word[eax+160]
	mov edx, 9
	uiText_render_alignment_loop_start:
		mov eax, ALIGNMENT_TO_PIVOT_LOOKUP
		cmp dword[eax+8*edx-8], ecx
		jne uiText_render_alignment_loop_continue
			;alignment found
			mov eax, dword[eax+8*edx-4]
			mov eax, dword[eax]
			mov dword[ebp-20], eax
			jmp uiText_render_alignment_loop_end
		
		uiText_render_alignment_loop_continue:
		dec edx
		test edx, edx
		jnz uiText_render_alignment_loop_start
	uiText_render_alignment_loop_end:
	
	;render the text
	mov eax, dword[ebp+8]
	push dword[ebp-8]
	push dword[ebp-4]
	push dword[ebp-20]
	push dword[TEXT_ORIGIN_BOTTOM_LEFT]
	push dword[eax+128]
	call textRenderer_drawText
	
	uiText_render_end:
	mov esp, ebp
	pop ebp
	ret
	
	;helper
	ALIGNMENT_TO_PIVOT_LOOKUP:
	dd 0x00010001, TEXT_PIVOT_BOTTOM_LEFT
	dd 0x00010002, TEXT_PIVOT_BOTTOM_CENTER
	dd 0x00010004, TEXT_PIVOT_BOTTOM_RIGHT
	dd 0x00020001, TEXT_PIVOT_CENTER_LEFT
	dd 0x00020002, TEXT_PIVOT_CENTER_CENTER
	dd 0x00020004, TEXT_PIVOT_CENTER_RIGHT
	dd 0x00040001, TEXT_PIVOT_TOP_LEFT
	dd 0x00040002, TEXT_PIVOT_TOP_CENTER
	dd 0x00040004, TEXT_PIVOT_TOP_RIGHT