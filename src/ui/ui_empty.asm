[BITS 32]

;layout
;struct UIEmpty{
;	<UIElement>
;}	192 bytes

section .text use32

	global uiEmpty_init				;void uiEmpty_init()
	global uiEmpty_deinit			;void uiEmpty_deinit()
	global uiEmpty_create			;UIEmpty* uiEmpty_create()
	
	extern my_malloc
	
	extern uiElement_setPosition
	extern uiElement_setSize
	extern uiElement_initGeneralPart
	
uiEmpty_init:
	ret
	
uiEmpty_deinit:
	ret
	
uiEmpty_create:
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
	mov dword[eax+72], uiEmpty_destroy
	
	;set the canvas to be stretchy
	push 0
	push 0
	push dword[ebp-4]
	call uiElement_setPosition
	call uiElement_setSize
	add esp, 12

	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
;void uiEmpty_destroy(UIEmpty* node)
uiEmpty_destroy:
	ret