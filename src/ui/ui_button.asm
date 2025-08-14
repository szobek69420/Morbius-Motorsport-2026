[BITS 32]

;struct UIButton{
;	<UIElement> basePart;			0
;	UIText*	text;					192
;	UIImage* background;			196
;	vec4 textColourRGBA;			200		;the unmodified text colour
;	vec4 imageColourRGBA;			216		;the unmodified image colour
;	vec4 baseTintRGBA;				232
;	vec4 hoverTintRGBA;				248
;	vec4 holdTintRGBA;				264
;}		280 bytes overall

section .rodata use32
	test_text db "ligma blogger",10,0

	default_text db "mogger",0

	default_text_colour dd 1.0, 1.0, 1.0, 1.0
	default_image_colour dd 1.0, 1.0, 1.0, 1.0
	
	default_base_tint dd 1.0, 1.0, 1.0, 1.0
	default_hover_tint dd 0.75, 0.75, 0.75, 1.0
	default_hold_tint dd 0.5, 0.5, 0.5, 1.0
	
section .text use32

	global uiButton_create		;UIButton* uiButton_create()
	
	global uiButton_getText			;UIText* uiButton_getText(UIButton*)
	global uiButton_getImage		;UIImage* uiButton_getImage(UIButton*)
	
	global uiButton_setTextColour	;void uiButton_setTextColour(UIButton*, vec4 textColourRGBA)
	global uiButton_setImageColour	;void uiButton_setImageColour(UIButton*, vec4 imageColourRGBA)
	global uiButton_setBaseTint		;void uiButton_setBaseTint(UIButton*, vec4 baseTintRGBA)
	global uiButton_setHoverTint	;void uiButton_setHoverTint(UIButton*, vec4 hoverTintRGBA)
	global uiButton_setHoldTint		;void uiButton_setHoldTint(UIButton*, vec4 holdTintRGBA)
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern uiElement_initGeneralPart
	extern uiElement_setPosition
	extern uiElement_setSize
	extern uiElement_setParent
	extern uiElement_setPivot
	extern uiElement_setAnchor
	extern uiElement_setStatus
	extern UI_CENTER
	extern UI_STRETCH
	
	extern uiText_create
	extern uiText_setText
	extern uiText_setColour
	
	extern uiImage_create
	extern uiImage_setColour
	
uiButton_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;button				4
	sub esp, 4			;button text		8
	sub esp, 4			;button image		12
	
	;alloc space
	push 280
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;init general part
	push dword[ebp-4]
	call uiElement_initGeneralPart
	add esp, 4
	
	;set values
	mov eax, dword[ebp-4]
	
	movups xmm0, [default_text_colour]
	movups [eax+200], xmm0
	movups xmm1, [default_image_colour]
	movups [eax+216], xmm1
	movups xmm2, [default_base_tint]
	movups [eax+232], xmm2
	movups xmm3, [default_hover_tint]
	movups [eax+248], xmm3
	movups xmm4, [default_hold_tint]
	movups [eax+264], xmm4
	
	mov dword[eax+68], uiButton_render
	mov dword[eax+72], uiButton_destroy
	
	;create and setup image
	call uiImage_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+196], eax
	mov dword[ebp-12], eax
	
	push 0
	push 0
	push dword[ebp-12]
	call uiElement_setPosition
	call uiElement_setSize
	add esp, 12
	
	push word[UI_STRETCH]
	push word[UI_STRETCH]
	push dword[ebp-12]
	call uiElement_setAnchor
	add esp, 8
	
	push 0
	push 69
	push dword[ebp-12]
	call uiElement_setStatus
	add esp, 12
	
	push dword[ebp-4]
	push dword[ebp-12]
	call uiElement_setParent
	add esp, 8
	
	;create and setup text
	call uiText_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+192], eax
	mov dword[ebp-8], eax
	
	push default_text
	push dword[ebp-8]
	call uiText_setText
	add esp, 8
	
	push 0
	push 0
	push dword[ebp-8]
	call uiElement_setPosition
	call uiElement_setSize
	add esp, 12
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[ebp-8]
	call uiElement_setPivot
	call uiElement_setAnchor
	add esp, 8
	
	push 0
	push 69
	push dword[ebp-8]
	call uiElement_setStatus
	add esp, 12
	
	push dword[ebp-4]
	push dword[ebp-8]
	call uiElement_setParent
	add esp, 8
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiButton_getText:
	mov eax, dword[esp+4]
	mov eax, dword[eax+192]
	ret
	
uiButton_getImage:
	mov eax, dword[esp+4]
	mov eax, dword[eax+196]
	ret	
	
uiButton_setTextColour:
	mov eax, dword[esp+4]
	movups xmm0, [esp+8]
	movups [eax+200], xmm0
	ret
	
uiButton_setImageColour:
	mov eax, dword[esp+4]
	movups xmm1, [esp+8]
	movups [eax+216], xmm1
	ret
	
uiButton_setBaseTint:
	mov eax, dword[esp+4]
	movups xmm0, [esp+8]
	movups [eax+232], xmm0
	ret
	
uiButton_setHoverTint:
	mov eax, dword[esp+4]
	movups xmm1, [esp+8]
	movups [eax+248], xmm1
	ret
	
uiButton_setHoldTint:
	mov eax, dword[esp+4]
	movups xmm2, [esp+8]
	movups [eax+264], xmm2
	ret
	
	
;internal functinos

;void uiButton_render(UIButton*, const mat4* projection)
uiButton_render:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;vec4* current tint		4
	sub esp, 16			;image colour			20
	sub esp, 16			;text colour			36
	
	;determine what tint shall be used
	mov eax, dword[ebp+8]
	lea ecx, [eax+232]
	mov dword[ebp-4], ecx
	test dword[eax+80], 0xffffffff
	jz uiButton_render_tint_not_hover
		lea ecx, [eax+248]
		mov dword[ebp-4], ecx
	uiButton_render_tint_not_hover:
	test dword[eax+84], 0xffffffff
	jz uiButton_render_tint_not_hold
		lea ecx, [eax+264]
		mov dword[ebp-4], ecx
	uiButton_render_tint_not_hold:
	
	;calculate the colours
	mov ecx, dword[ebp-4]
	vmovups ymm0, [eax+200]
	movups xmm1, [ecx]
	vinsertf128 ymm1, ymm1, xmm1, 0b1
	vmulps ymm0, ymm0, ymm1
	vmovups [ebp-36], ymm0
	
	;set the colours
	mov eax, dword[ebp+8]
	push dword[ebp-24]
	push dword[ebp-28]
	push dword[ebp-32]
	push dword[ebp-36]
	push dword[eax+192]
	call uiText_setColour
	
	mov eax, dword[ebp+8]
	push dword[ebp-8]
	push dword[ebp-12]
	push dword[ebp-16]
	push dword[ebp-20]
	push dword[eax+196]
	call uiImage_setColour
	
	mov esp, ebp
	pop ebp
	ret
	

;NOTE: text and image don't need to be destroyed here, leaving nothing to be done
uiButton_destroy:
	ret