[BITS 32]

;layout
;struct UIImage{
;	<UIElement>
;	GLuint texture;			128	//0 means default
;	float colourR;			132
;	float colourG;			136
;	float colourB;			140
;	float colourA;			144
;}	148 bytes

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
	
	default_texture_path db "sprites/ui/ui_image_default.bmp",0
	
	error_init_already_initialized db "uiImage_init: system is already initialized",10,0
	error_deinit_already_deinitialized db "uiImage_deinit: system is already deinitialized",10,0
	
	debug_text_destroy db "ui_image destroyed",10,0
	debug_text_render db "ui_image rendered",10,0
	
	uniform_name_colour db "colour",0
	uniform_name_position db "position",0
	uniform_name_scale db "scale",0
	
	ONE dd 1.0
	
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_four_ints_nl db "%d %d %d %d",10,0
	
section .data use32
	is_initialized dd 0
	renderable dd 0
	shader dd 0
	default_texture dd 0
	
section .text use32

	global uiImage_init			;void uiImage_init()
	global uiImage_deinit		;void uiImage_deinit()
	
	global uiImage_create		;UIImage* uiImage_create()
	
	;path==NULL means default texture
	;UIImage* uiImage_setTexture(UIImage* image, const char* nullableTexturePath)
	global uiImage_setTexture
	global uiImage_setColour	;void uiImage_setColour(UIImage* image, float r, float g, float b, float a)
	
	extern uiElement_initGeneralPart
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern mat4_print
	
	extern renderable_createCustom
	extern renderable_renderCustom
	extern renderable_destroy
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	extern renderable_setUniform
	extern renderable_setExtraTexture2D
	extern RENDERABLE_UNIFORM_VEC2
	extern RENDERABLE_UNIFORM_VEC4_ARRAY
	extern RENDERABLE_UNIFORM_MAT4
	
	extern textureHandler_load
	extern textureHandler_unload
	
	extern glGetError
	extern GL_CLAMP_TO_EDGE
	extern GL_LINEAR
	
uiImage_init:
	push ebp
	mov ebp, esp
	
	
	;check if we are already morbin
	cmp dword[is_initialized], 0
	je uiImage_init_not_initialized
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
	
	;load the default texture
	push 0
	push dword[GL_LINEAR]
	push dword[GL_CLAMP_TO_EDGE]
	push default_texture_path
	call textureHandler_load
	mov dword[default_texture], eax
	add esp, 16
	
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
	
	;yeet the default textuer
	push dword[default_texture]
	call textureHandler_unload
	mov dword[default_texture], 0
	add esp, 4
	
	;yeet shader
	push dword[shader]
	call renderable_destroyShader
	mov dword[shader], 0
	add esp, 4
	
	;yeet renderable
	push dword[renderable]
	call renderable_destroy
	mov dword[renderable], 0
	add esp, 4
	
	;set initialized flag
	mov dword[is_initialized], 0
	
	uiImage_deinit_end:
	mov esp, ebp
	pop ebp
	ret
	
uiImage_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;image		4
	
	;alloc space
	push 148
	call my_malloc
	mov dword[ebp-4], eax
	
	;init the cumvas
	push dword[ebp-4]
	call uiElement_initGeneralPart
	
	;set render
	mov eax, dword[ebp-4]
	mov dword[eax+68], uiImage_render
	
	;set destroy
	mov eax, dword[ebp-4]
	mov dword[eax+72], uiImage_destroy
	
	;init values
	mov dword[eax+128], 0
	
	mov ecx, dword[ONE]
	mov dword[eax+132], ecx
	mov dword[eax+136], ecx
	mov dword[eax+140], ecx
	mov dword[eax+144], ecx
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	

uiImage_setTexture:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;new texture		4
	
	mov dword[ebp-4], 0
	
	;unload previous texture if necessary
	mov eax, dword[ebp+8]
	test dword[eax+128], 0xffffffff
	jz uiImage_setTexture_no_previous_texture
		push dword[eax+128]
		call textureHandler_unload
		
	uiImage_setTexture_no_previous_texture:
	
	;load current texture
	test dword[ebp+12], 0xffffffff
	jz uiImage_setTexture_end
		push 0
		push dword[GL_LINEAR]
		push dword[GL_CLAMP_TO_EDGE]
		push dword[ebp+12]
		call textureHandler_load
		mov dword[ebp-4], eax
	
	uiImage_setTexture_end:
	;set the new texture
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	mov dword[eax+128], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiImage_setColour:
	mov eax, dword[esp+4]
	
	mov ecx, dword[esp+8]
	mov dword[eax+132], ecx
	mov ecx, dword[esp+12]
	mov dword[eax+136], ecx
	mov ecx, dword[esp+16]
	mov dword[eax+140], ecx
	mov ecx, dword[esp+20]
	mov dword[eax+144], ecx
	
	ret
	
	
;internal functions	-------------------------------

;doesn't deallocate the memory region
;void uiImage_destroy(UIImage* image)
uiImage_destroy:
	push ebp
	mov ebp, esp
	
	;delete the texture if necessary
	mov eax, dword[ebp+8]
	test dword[eax+128], 0xffffffff
	jz uiImage_destroy_end
		;unload the texture
		push dword[eax+128]
		call textureHandler_unload
	
	uiImage_destroy_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;void uiImage_render(UIImage* image, const mat4* projection)
uiImage_render:
	push ebp
	mov ebp, esp
	
	;use shader
	push dword[shader]
	call renderable_useShader
	
	;set uniforms	
	mov eax, dword[ebp+8]
	sub esp, 8
	fild dword[eax+48]
	fstp dword[esp+4]
	fild dword[eax+44]
	fstp dword[esp]
	push dword[RENDERABLE_UNIFORM_VEC2]
	push uniform_name_position
	push dword[shader]
	call renderable_setUniform				;position
	
	mov eax, dword[ebp+8]
	sub esp, 8
	fild dword[eax+56]
	fstp dword[esp+4]
	fild dword[eax+52]
	fstp dword[esp]
	push dword[RENDERABLE_UNIFORM_VEC2]
	push uniform_name_scale
	push dword[shader]
	call renderable_setUniform				;scale

	mov eax, dword[ebp+8]
	lea eax, [eax+132]
	push eax
	push 1
	push dword[RENDERABLE_UNIFORM_VEC4_ARRAY]
	push uniform_name_colour
	push dword[shader]
	call renderable_setUniform				;colour
	
	;set texture
	mov eax, dword[ebp+8]
	test dword[eax+128], 0xffffffff
	jz uiImage_render_texture_default
		;set the non-default texture
		push dword[eax+128]
		push 0
		push dword[renderable]
		call renderable_setExtraTexture2D
		jmp uiImage_render_texture_done
		
	uiImage_render_texture_default:
		;set the default texture
		push dword[default_texture]
		push 0
		push dword[renderable]
		call renderable_setExtraTexture2D
		
	uiImage_render_texture_done:
	
	;render
	push 69
	push dword[shader]
	push dword[ebp+12]
	push dword[renderable]
	call renderable_renderCustom
	
	mov esp, ebp
	pop ebp
	ret