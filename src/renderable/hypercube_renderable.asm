[BITS 32]

section .rodata use32
	vertex_vector:
	dd 16
	dd 16
	dd 4
	dd vertex_vector_data
	vertex_vector_data:
	dd 0.0, 0, 0.0, 1, 0.0, 2, 0.0, 3, 0.0, 4, 0.0, 5, 0.0, 6, 0.0, 7
	
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
	
section .data use32
	shader dd 0
	active_hypercubes dd 0

section .text use32
	
	global hyperCubeRenderable_create		;Renderable* hyperCubeRenderable_create()
	global hyperCubeRenderable_destroy		;void hyperCubeRenderable_destroy(Renderable* hyperCubeRenderable)
	global hyperCubeRenderable_render		;void hyperCubeRenderable_render(Renderable* hypercube, mat4* pv)
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	
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
	push 1
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
	
	hyperCubeRenderable_destroy_end:
	mov esp, ebp
	pop ebp
	ret
	
	
hyperCubeRenderable_render:
	push ebp
	mov ebp, esp
	
	push 69
	push dword[shader]
	push dword[ebp+12]
	push dword[ebp+8]
	call renderable_renderCustom
	add esp, 16
	
	mov esp, ebp
	pop ebp
	ret