[BITS 32]

;layout:
;struct UIText{
;	<UIElement>
;	char* text;									128	//NULL means kein text
;	float colourR, colourG, colourB, colourA;	132
;	int spacing;								148
;	int fontWidth, fontHeight;					152
;}	160 bytes

section .rodata use32
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
	
	global uiText_setText				;UIText* uiText_setText(UIText* element, const char* nullableText)
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy
	extern my_strlen
	extern my_strcpy
	
	extern FONT_CHAR_WIDTH
	extern FONT_CHAR_HEIGHT
	
	extern textRenderer_drawText		;void textRenderer_drawText(const char* text, int origin, int pivot, int xPos, int yPos)
	extern textRenderer_setScreenSize
	extern textRenderer_setFontSize
	extern textRenderer_setSpacing
	extern textRenderer_setColour
	extern TEXT_ORIGIN_BOTTOM_LEFT
	extern TEXT_PIVOT_CENTER_CENTER
	
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
	push 152
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
	
;internal functions ---------------------------------------------

;void uiText_destroy(UIText* text)
uiText_destroy:
	push ebp
	mov ebp, esp
	
	;free text
	mov eax, dword[ebp+8]
	push dword[eax+128]
	call my_free
	
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
	
	;check if the text is NULL
	mov eax, dword[ebp+8]
	cmp dword[eax+128], 0
	je uiText_render_end
	
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
	
	;at the moment only centered text
	mov eax, dword[ebp+8]
	
	mov ecx, dword[eax+8]
	shr ecx, 1
	add ecx, dword[eax+44]
	mov dword[ebp-4], ecx
	
	mov ecx, dword[eax+12]
	shr ecx, 1
	add ecx, dword[eax+48]
	mov dword[ebp-8], ecx
	
	push dword[ebp-8]
	push dword[ebp-4]
	push dword[TEXT_PIVOT_CENTER_CENTER]
	push dword[TEXT_ORIGIN_BOTTOM_LEFT]
	push dword[eax+128]
	call textRenderer_drawText
	
	uiText_render_end:
	mov esp, ebp
	pop ebp
	ret