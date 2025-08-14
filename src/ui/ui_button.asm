[BITS 32]

;struct UIButton{
;	<UIElement> basePart;			0
;	UIText*	text;					192
;	UIImage* background;			196
;	vec4 textColour;				200		;the unmodified text colour
;	vec4 imageColour;				216		;the unmodified image colour
;	vec4 baseTint;					232
;	vec4 hoverTint;					248
;	vec4 holdTint;					264
;}		280 bytes overall

section .rodata use32
	default_text dd "mogger",0

	default_text_colour dd 1.0, 1.0, 1.0, 1.0
	default_image_colour dd 1.0, 1.0, 1.0, 1.0
	
	default_base_tint dd 1.0, 1.0, 1.0, 1.0
	default_hover_tint dd 0.75, 0.75, 0.75, 1.0
	default_hold_tint dd 0.5, 0.5, 0.5, 1.0
	
section .text use32

	global uiButton_create		;UIButton* uiButton_create()
	
	global uiButton_getText		;UIText* uiButton_getText(UIButton*)
	global uiButton_getImage	;UIImage* uiButton_getImage(UIButton*)
	
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
	
	extern uiImage_create
	
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
	
	push dword[ebp-8]
	push dword[ebp-4]
	call uiElement_setParent
	add esp, 8
	
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
	
	push dword[ebp-12]
	push dword[ebp-4]
	call uiElement_setParent
	add esp, 8
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret