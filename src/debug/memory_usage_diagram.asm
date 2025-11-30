[BITS 32]

section .rodata use32
	vertex_vector:
	dd 20
	dd 20
	dd 4
	dd vertex_data
	vertex_data:
	dd 0,1,2,3,4,
	dd 5,6,7,8,9
	dd 10,11,12,13,14
	dd 15,16,17,18,19

	DIAGRAM_WIDTH dd 512
	DIAGRAM_HEIGHT dd 128
	DIAGRAM_WIDTH_FLOAT dd 512.0
	DIAGRAM_HEIGHT_FLOAT dd 128.0
	
	DIAGRAM_VALUE_COUNT dd 20
	
	vertex_shader_path db "shaders/debug/memory_usage_diagram/diagram.vag",0
	geometry_shader_path_bg db "shaders/debug/memory_usage_diagram/diagram_background.gag",0
	geometry_shader_path_line db "shaders/debug/memory_usage_diagram/diagram_line.gag",0
	fragment_shader_path db "shaders/debug/memory_usage_diagram/diagram.fag",0
	
	uniform_name_values db "values",0
	uniform_name_value_offsets db "value_offsets",0
	
	error_already_initialized db "memoryUsageDiagram_init: system is already initialized",10,0
	error_already_deinitialized db "memoryUsageDiagram_deinit: system is already deinitialized",10,0

	ZERO dd 0.0
	ONE dd 1.0
	HORIZONTAL_STEP dd 0.05		;1/(21-1)
	
	print_nl db 10,0
	print_int_nl db "%d",10,0
	print_float_space db "%f ",0
	
	test_text db "Frederick Fitzgerald von Fazbearington",10,0

section .data use32

	shader_bg dd 0
	shader_line dd 0
	renderable dd 0
	framebuffer dd 0
	
	initialized dd 0
	
section .bss use32
	values resb 84			;int[21]
	value_offsets resb 84	;float[21] //ranging between 0 and 1
	
	values_float resb 84	;float[21] //scaled values for rendering
	
section .text use32

	global memoryUsageDiagram_init			;void memoryUsageDiagram_init()
	global memoryUsageDiagram_deinit		;void memoryUsageDiagram_deinit()
	
	global memoryUsageDiagram_update		;void memoryUsageDiagram_update()
	
	global memoryUsageDiagram_getTexture	;GLuint memoryUsageDiagram_getTexture()
	
	extern my_printf
	
	extern meminfo_getMemoryUsage
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	extern renderable_setUniform
	extern renderable_enableDepthTest
	extern renderable_enableBlending
	extern renderable_setPrimitive
	extern renderable_setLineWidth
	extern RENDERABLE_UNIFORM_FLOAT_ARRAY
	
	extern framebuffer_create
	extern framebuffer_destroy
	extern framebuffer_bind
	extern framebuffer_colourAttachment
	extern FRAMEBUFFER_RGBA
	
	extern glViewport
	extern glClear
	extern glClearColor
	extern glGetError
	extern GL_COLOR_BUFFER_BIT
	extern GL_POINTS
	
memoryUsageDiagram_init:
	push ebp
	mov ebp, esp
	
	;check if already initialized
	test dword[initialized], 0xffffffff
	jz memoryUsageDiagram_init_not_initialized
		push error_already_initialized
		call my_printf
		jmp memoryUsageDiagram_init_end
	memoryUsageDiagram_init_not_initialized:
	
	;init values and value offsets
	xor eax, eax			;index in eax
	movss xmm0, dword[ZERO]	;current offset in xmm0
	memoryUsageDiagram_init_value_loop_start:
		mov dword[values+4*eax], 0
		movss dword[value_offsets+4*eax], xmm0
		
		addss xmm0, dword[HORIZONTAL_STEP]
		inc eax
		cmp eax, 21
		jl memoryUsageDiagram_init_value_loop_start
	
	;compile shaders
	push geometry_shader_path_bg
	push fragment_shader_path
	push vertex_shader_path
	call renderable_createShader
	mov dword[shader_bg], eax
	
	push geometry_shader_path_line
	push fragment_shader_path
	push vertex_shader_path
	call renderable_createShader
	mov dword[shader_line], eax
	
	;create framebuffer and texture
	push dword[DIAGRAM_HEIGHT]
	push dword[DIAGRAM_WIDTH]
	call framebuffer_create
	mov dword[framebuffer], eax
	
	push 0
	push FRAMEBUFFER_RGBA
	push dword[framebuffer]
	call framebuffer_colourAttachment
	
	;genesis of renderable
	push 1
	push 1
	push 0
	push 0
	push vertex_vector
	call renderable_createCustom
	mov dword[renderable], eax
	add esp, 20
	
	;set initialized flag
	mov dword[initialized], 69
	
	memoryUsageDiagram_init_end:
	mov esp, ebp
	pop ebp
	ret
	
	
memoryUsageDiagram_deinit:
	push ebp
	mov ebp, esp
	
	;check if already deinitialized
	test dword[initialized], 0xffffffff
	jnz memoryUsageDiagram_deinit_not_deinitialized
		push error_already_deinitialized
		call my_printf
		jmp memoryUsageDiagram_deinit_end
	memoryUsageDiagram_deinit_not_deinitialized:
	
	;yeet renderable
	push dword[renderable]
	call renderable_destroy
	
	;yeet the framebuffer
	push dword[framebuffer]
	call framebuffer_destroy
	
	;yeet the shaders
	push dword[shader_bg]
	call renderable_destroyShader
	push dword[shader_line]
	call renderable_destroyShader
	
	;unset the initialized flag
	mov dword[initialized], 0
	
	memoryUsageDiagram_deinit_end:
	mov esp, ebp
	pop ebp
	ret
	
	
memoryUsageDiagram_update:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;max value		4
	sub esp, 4			;scaler			8
	
	;verschieb alte werte
	xor edi, edi			;index in edi
	memoryUsageDiagram_update_shift_loop_start:
		lea esi, [edi+1]
		mov eax, dword[values+4*esi]
		mov dword[values+4*edi], eax
		
		inc edi
		cmp edi, 20
		jl memoryUsageDiagram_update_shift_loop_start
	
	;set new value
	call meminfo_getMemoryUsage
	shr eax, 20
	mov ecx, 80
	mov dword[values+ecx], eax
	
	;get max value
	mov dword[ebp-4], 0
	xor edi, edi		;index in edi
	memoryUsageDiagram_update_max_loop_start:	
		mov eax, dword[values+4*edi]
		cmp eax, dword[ebp-4]
		jle memoryUsageDiagram_update_max_loop_continue
			mov dword[ebp-4], eax
		memoryUsageDiagram_update_max_loop_continue:
		inc edi
		cmp edi, 21
		jl memoryUsageDiagram_update_max_loop_start
		
	cmp dword[ebp-4], 10
	jge memoryUsageDiagram_update_max_gut
		mov dword[ebp-4], 10
	memoryUsageDiagram_update_max_gut:
	
	;scale max value
	movss xmm0, dword[ONE]
	cvtsi2ss xmm1, dword[ebp-4]
	divss xmm0, xmm1
	movss dword[ebp-8], xmm0
	
	xor edi, edi		;index in edi
	memoryUsageDiagram_update_scale_loop_start:
		cvtsi2ss xmm1, dword[values+4*edi]
		mulss xmm1, xmm0
		movss dword[values_float+4*edi], xmm1
		
		inc edi
		cmp edi, 21
		jl memoryUsageDiagram_update_scale_loop_start
		
	;render ----------------------------------------------------
	
	;set render things
	push 0
	call renderable_enableDepthTest
	push 69
	call renderable_enableBlending
	push dword[GL_POINTS]
	call renderable_setPrimitive
	;push 0x40a00000
	;call renderable_setLineWidth
	
	;bind and clear framebuffer
	push dword[framebuffer]
	call framebuffer_bind
	
	push dword[DIAGRAM_HEIGHT]
	push dword[DIAGRAM_WIDTH]
	push 0
	push 0
	call [glViewport]
	
	push 0
	push 0
	push 0
	push 0
	call [glClearColor]
	
	push dword[GL_COLOR_BUFFER_BIT]
	call [glClear]
	
	;render background
	push dword[shader_bg]
	call renderable_useShader
	
	push values_float
	push 21
	push dword[RENDERABLE_UNIFORM_FLOAT_ARRAY]
	push uniform_name_values
	push dword[shader_bg]
	call renderable_setUniform
	
	push value_offsets
	push 21
	push dword[RENDERABLE_UNIFORM_FLOAT_ARRAY]
	push uniform_name_value_offsets
	push dword[shader_bg]
	call renderable_setUniform
	
	push 69
	push dword[shader_bg]
	push dword[ebp+12]
	push dword[renderable]
	call renderable_renderCustom
	
	;render line
	push dword[shader_line]
	call renderable_useShader
	
	push values_float
	push 21
	push dword[RENDERABLE_UNIFORM_FLOAT_ARRAY]
	push uniform_name_values
	push dword[shader_line]
	call renderable_setUniform
	
	push value_offsets
	push 21
	push dword[RENDERABLE_UNIFORM_FLOAT_ARRAY]
	push uniform_name_value_offsets
	push dword[shader_line]
	call renderable_setUniform
	
	push 69
	push dword[shader_line]
	push dword[ebp+12]
	push dword[renderable]
	call renderable_renderCustom
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
	
memoryUsageDiagram_getTexture:
	mov eax, dword[framebuffer]
	mov eax, dword[eax+4]
	ret