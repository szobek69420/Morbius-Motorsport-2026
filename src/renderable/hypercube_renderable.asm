[BITS 32]

section .rodata use32
	vertex_vector:
	dd 40
	dd 40
	dd 4
	dd vertex_vector_data
	vertex_vector_data:
	dd 0.0, 0.0, 0.0, 0.0, 0,
	dd 0.0, 0.0, 0.0, 0.0, 1,
	dd 0.0, 0.0, 0.0, 0.0, 2,
	dd 0.0, 0.0, 0.0, 0.0, 3,
	dd 0.0, 0.0, 0.0, 0.0, 4,
	dd 0.0, 0.0, 0.0, 0.0, 5,
	dd 0.0, 0.0, 0.0, 0.0, 6,
	dd 0.0, 0.0, 0.0, 0.0, 7
	
	index_vector:
	dd 8
	dd 8
	dd 4
	dd index_vector_data
	index_vector_data:
	dd 0, 1, 2, 3, 4, 5, 6, 7
	
	vertex_shader_path db "shaders/hypercube/hypercube.vag",0
	geometry_shader_path db "shaders/hypercube/hypercube.gag",0
	fragment_shader_path db "shaders/hypercube/hypercube.fag",0
	
	uniform_position_name db "position",0
	uniform_hyperPlanePos_name db "hyperPlanePos",0
	uniform_hyperPlaneDir1_name db "hyperPlaneDir1",0
	uniform_hyperPlaneDir2_name db "hyperPlaneDir2",0
	uniform_hyperPlaneDir3_name db "hyperPlaneDir3",0
	uniform_hyperPlaneNormal_name db "hyperPlaneNormal",0
	
	test_text db "marx verstappen",10,0
	
	print_int_nl db "%d",10,0
	
section .data use32
	shader dd 0
	active_hypercubes dd 0

section .text use32
	
	global hyperCubeRenderable_create		;Renderable* hyperCubeRenderable_create()
	global hyperCubeRenderable_destroy		;void hyperCubeRenderable_destroy(Renderable* hyperCubeRenderable)
	
	;if a custom shader is used, the default uniforms are still set
	;void hyperCubeRenderable_render(Renderable* hypercube, mat4* pv, HyperPlane* hp, vec4* position, GLuint nullableShader)
	global hyperCubeRenderable_render
	
	extern my_printf
	
	extern vec4_print
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	extern renderable_setUniform
	extern renderable_setPrimitive
	extern RENDERABLE_UNIFORM_VEC4
	extern glGetError
	extern GL_POINTS
	
	extern hyperPlane_getNormal
	
hyperCubeRenderable_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;renderable
	
	;is the shader already imported?
	cmp dword[shader], 0
	jne hyperCubeRenderable_create_shader_imported
		;import shader
		push geometry_shader_path
		push fragment_shader_path
		push vertex_shader_path
		call renderable_createShader
		mov dword[shader], eax
		add esp, 12
		
	hyperCubeRenderable_create_shader_imported:
	
	;create renderable
	push 1
	push 1
	push 4
	push 1
	push index_vector
	push vertex_vector
	call renderable_createCustom
	mov dword[ebp-4], eax
	add esp, 24
	
	inc dword[active_hypercubes]
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
hyperCubeRenderable_destroy:
	push ebp
	mov ebp, esp
	
	;destroy renderable
	push dword[ebp+8]
	call renderable_destroy
	add esp, 4
	
	dec dword[active_hypercubes]
	cmp dword[active_hypercubes], 0
	jg hyperCubeRenderable_destroy_end
		;destroy the shader
		push dword[shader]
		call renderable_destroyShader
		add esp, 4
		
		mov dword[shader], 0
	
	hyperCubeRenderable_destroy_end:
	mov esp, ebp
	pop ebp
	ret
	
	
hyperCubeRenderable_render:
	push ebp
	mov ebp, esp
	
	sub esp, 16					;hyperplane normal		16
	sub esp, 4					;used shader			20
	
	;calculate hyperplane normal
	lea eax, [ebp-16]
	push eax
	push dword[ebp+16]
	call hyperPlane_getNormal
	add esp, 8
	
	;select shader
	mov eax, dword[shader]
	mov dword[ebp-20], eax
	test dword[ebp+24], 0xffffffff
	jz hyperCubeRenderable_render_no_custom_shader
		mov ecx, dword[ebp+24]
		mov dword[ebp-20], ecx
	hyperCubeRenderable_render_no_custom_shader:
	
	;use shader
	push dword[ebp-20]
	call renderable_useShader
	add esp, 4
	
	;set position
	mov eax, dword[ebp+20]
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_position_name
	push dword[ebp-20]
	call renderable_setUniform
	add esp, 28
	
	;set hyperplane data
	mov eax, dword[ebp+16]
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_hyperPlanePos_name
	push dword[ebp-20]
	call renderable_setUniform
	add esp, 28
	
	mov eax, dword[ebp+16]
	push dword[eax+28]
	push dword[eax+24]
	push dword[eax+20]
	push dword[eax+16]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_hyperPlaneDir1_name
	push dword[ebp-20]
	call renderable_setUniform
	add esp, 28
	
	mov eax, dword[ebp+16]
	push dword[eax+44]
	push dword[eax+40]
	push dword[eax+36]
	push dword[eax+32]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_hyperPlaneDir2_name
	push dword[ebp-20]
	call renderable_setUniform
	add esp, 28
	
	mov eax, dword[ebp+16]
	push dword[eax+60]
	push dword[eax+56]
	push dword[eax+52]
	push dword[eax+48]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_hyperPlaneDir3_name
	push dword[ebp-20]
	call renderable_setUniform
	add esp, 28
	
	push dword[ebp-4]
	push dword[ebp-8]
	push dword[ebp-12]
	push dword[ebp-16]
	push dword[RENDERABLE_UNIFORM_VEC4]
	push uniform_hyperPlaneNormal_name
	push dword[ebp-20]
	call renderable_setUniform
	add esp, 28
	
	;set primitive
	push dword[GL_POINTS]
	call renderable_setPrimitive
	
	;render
	push 69
	push dword[ebp-20]
	push dword[ebp+12]
	push dword[ebp+8]
	call renderable_renderCustom
	add esp, 16
	
	mov esp, ebp
	pop ebp
	ret