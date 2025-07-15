[BITS 32]

;layout
;struct UIImage{
;	<UIElement>
;	char* texturePath;
;}	132 bytes
section .rodata use32
	vertex_vector:
	dd 8
	dd 8
	dd 4
	dd vertex_data
	vertex_data:
	dd 0.0, 0.0,
	dd 0.0, 1.0,
	dd 1.0, 0.0,
	dd 1.0, 1.0
	
	index_vector:
	dd 6
	dd 6
	dd 4
	dd index_data
	index_data:
	dd 1,0,3,3,0,2
	
	vertex_shader_path db "shaders/ui/image/image.vag",0
	fragment_shader_path db "shaders/ui/image/image.fag",0
	
	error_init_already_initialized db "uiImage_init: system is already initialized",10,0
	error_deinit_already_deinitialized db "uiImage_deinit: system is already deinitialized",10,0
	
section .data use32
	is_initialized dd 0
	renderable dd 0
	shader dd 0
	
section .text use32

	global uiImage_init			;void uiImage_init()
	global uiImage_deinit		;void uiImage_deinit()
	
	global my_printf
	global my_malloc
	global my_free
	
	global renderable_createCustom
	global renderable_destroy
	global renderable_createShader
	global renderable_destroyShader
	
uiImage_init:
	push ebp
	mov ebp, esp
	
	;check if we are already morbin
	cmp dword[is_initialized], 0
	jne uiImage_init_not_initialized
		;scheisse
		push error_init_already_initialized
		call my_printf
		add esp, 4
		
		jmp uiImage_init_end
	
	uiImage_init_not_initialized:
	
	;genesis of shader
	push 0
	push fragment_shader_path
	push vertex_shader_path
	call renderable_createShader
	mov dword[shader], eax
	add esp, 12
	
	;genesis of renderable
	push 0
	push 2
	push 1
	push index_vector
	push vertex_vector
	call renderable_createCustom
	mov dword[renderable], eax
	add esp, 20
	
	
	;set initialized flag
	mov dword[is_initialized], 69
	
	uiImage_init_end:
	mov esp, ebp
	pop ebp
	ret
	
	
uiImage_deinit:
	push ebp
	mov ebp, esp
	
	;check if a deinit is needed
	test dword[is_initialized], 0xffffffff
	jnz uiImage_deinit_not_deinitialized
		;scheisse #2
		push error_deinit_already_deinitialized
		call my_printf
		add esp, 4
		
		jmp uiImage_deinit_end
	
	uiImage_deinit_not_deinitialized:
	
	;yeet shader
	push dword[shader]
	call renderable_destroyShader
	mov dword[shader], 0
	add esp, 4
	
	;yeet renderable
	push dword[renderable]
	cal renderable_destroy
	mov dword[renderable], 0
	add esp, 4
	
	;set initialized flag
	mov dword[is_initialized], 0
	
	uiImage_deinit_end:
	mov esp, ebp
	pop ebp
	rets