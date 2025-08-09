[BITS 32]

;struct UICanvas{
;	<UIElement>
;}	192 bytes overall

section .rodata use32

	debug_text_destroy db "ui_canvas destroyed",10,0
	print_four_ints_nl db "%d %d %d %d",10,0

section .text use32
	
	global uiCanvas_init		;void uiCanvas_init()
	global uiCanvas_deinit		;void uiCanvas_deinit()
	
	global uiCanvas_create		;UIElement* uiCanvas_create()
	
	extern my_printf
	extern my_malloc
	
	extern uiElement_setPosition
	extern uiElement_setSize
	extern uiElement_setAnchor
	extern uiElement_initGeneralPart
	extern UI_STRETCH
	
uiCanvas_init:
	ret
	
uiCanvas_deinit:
	ret
	
uiCanvas_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;canvas		4
	
	;alloc space
	push 192
	call my_malloc
	mov dword[ebp-4], eax
	
	;init the cumvas
	push dword[ebp-4]
	call uiElement_initGeneralPart
	
	;set destroy
	mov eax, dword[ebp-4]
	mov dword[eax+72], uiCanvas_destroy
	
	;set the canvas to be stretchy
	push 0
	push 0
	push dword[ebp-4]
	call uiElement_setPosition
	call uiElement_setSize
	add esp, 12
	
	push word[UI_STRETCH]
	push word[UI_STRETCH]
	push dword[ebp-4]
	call uiElement_setAnchor
	add esp, 8
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
;void uiCanvas_destroy(UICanvas* canvas)
uiCanvas_destroy:
	ret
	

;void uiCanvas_onWindowResize(UIElement* canvas, int width, int height)
uiCanvas_onWindowResize:
	push ebp
	mov ebp, esp
	
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[ebp+8]
	call uiElement_setSize
	
	mov esp, ebp
	pop ebp
	ret