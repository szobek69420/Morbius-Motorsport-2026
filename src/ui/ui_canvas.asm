[BITS 32]

;struct UICanvas{
;	<UIElement>
;}	128 bytes overall

section .rodata use32

	debug_text_destroy db "ui_canvas destroyed",10,0

section .text use32
	
	global uiCanvas_init		;void uiCanvas_init()
	global uiCanvas_deinit		;void uiCanvas_deinit()
	
	global uiCanvas_create		;UIElement* uiCanvas_create()
	
	extern my_printf
	extern my_malloc
	
	extern uiElement_setSize
	extern uiElement_initGeneralPart
	
uiCanvas_init:
	ret
	
uiCanvas_deinit:
	ret
	
uiCanvas_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;canvas		4
	
	;alloc space
	push 128
	call my_malloc
	mov dword[ebp-4], eax
	
	;init the cumvas
	push dword[ebp-4]
	call uiElement_initGeneralPart
	
	;set destroy
	mov eax, dword[ebp-4]
	mov dword[eax+72], uiCanvas_destroy
	
	;set onWindowResize
	mov eax, dword[ebp-4]
	mov dword[eax+76], uiCanvas_onWindowResize
	
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