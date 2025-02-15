[BITS 32]

;layout
;struct Renderable{
;	GLuint vao, vbo, ebo;		;0
;	int indexCount;				;12
;	vec3 position;				;16
;	vec3 rotation;				;28
;	vec3 scale;					;40
;	int vertexAttribLayout;		;52
;}		;56 bytes overall

section .rodata

	global RENDERABLE_ATTRIB_P3
	global RENDERABLE_ATTRIB_P3UV2
	global RENDERABLE_ATTRIB_P3C3
	
	RENDERABLE_ATTRIB_P3 dd 1
	RENDERABLE_ATTRIB_P3UV2 dd 2
	RENDERABLE_ATTRIB_P3C3 dd 3
	
	error_not_initialized db "Renderable: renderable_init has not been called",10,0
	
	vertex_shader_p3 db "shaders/p3.vag",0
	fragment_shader_p3 db "shaders/p3.fag",0
	
	vertex_shader_p3c3 db "shaders/p3c3.vag",0
	fragment_shader_p3c3 db "shaders/p3c3.fag",0
	
	uniform_name_pv db "pv",0
	uniform_name_model db "model",0
	
	EPSILON dd 0.00001
	ONE dd 1.0
	
	X_AXIS dd 1.0, 0.0, 0.0
	Y_AXIS dd 0.0, 1.0, 0.0
	Z_AXIS dd 0.0, 0.0, -1.0
	
section .data use32
	renderable_initialized dd 0
	shader_p3 dd 0
	shader_p3c3 dd 0
	
	renderable_primitive dd 0
	
section .text use32

	global renderable_init				;void renderable_init()		//initializes the components of the renderable handler
	global renderable_deinit			;void renderable_deinit()	//undoes renderable_init
	
	global renderable_create			;Renderable* renderable_create(vector<float>* vertices, vector<int>* indices, int vertexAttribLayout)
	global renderable_destroy			;void renderable_destroy(Renderable* renderable)
	
	global renderable_render			;void renderable_render(Renderable* renderable, mat4* pv, GLuint texture)
	
	global renderable_setPrimitive		;void renderable_setPrimitive(GLuint primitive)
	
	
	extern glGenVertexArrays
	extern glGenBuffers
	extern glDeleteVertexArrays
	extern glDeleteBuffers
	extern glBindVertexArray
	extern glBindBuffer
	extern glBufferData
	extern glVertexAttribPointer
	extern glEnableVertexAttribArray
	extern glGetUniformLocation
	extern glUniformMatrix4fv
	extern glUseProgram
	extern glDrawElements
	extern GL_ARRAY_BUFFER
	extern GL_ELEMENT_ARRAY_BUFFER
	extern GL_STATIC_DRAW
	extern GL_FLOAT
	extern GL_UNSIGNED_INT
	extern GL_TRUE
	extern GL_FALSE
	extern GL_TRIANGLES
	
	extern my_printf
	
	extern my_malloc
	extern my_free
	extern my_memset_dword
	
	extern shader_import
	extern shader_destroy
	
	extern mat4_init
	extern mat4_scale
	extern mat4_rotate
	extern mat4_translate
	
renderable_init:
	push ebp
	mov ebp, esp
	
	;import shaders
	push 0
	push fragment_shader_p3
	push vertex_shader_p3
	call shader_import
	mov dword[shader_p3], eax
	add esp, 12
	
	push 0
	push fragment_shader_p3c3
	push vertex_shader_p3c3
	call shader_import
	mov dword[shader_p3c3], eax
	add esp, 12
	
	;init other values
	mov eax, dword[GL_TRIANGLES]
	mov dword[renderable_primitive], eax
	
	
	;gg
	mov dword[renderable_initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	

renderable_deinit:
	push ebp
	mov ebp, esp
	
	mov dword[renderable_initialized], 0
	
	
	;obliterate shaders
	push dword[shader_p3]
	call shader_destroy
	add esp, 4
	
	push dword[shader_p3c3]
	call shader_destroy
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	
renderable_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;Renderable*
	sub esp, 4			;vao
	sub esp, 4			;vbo
	sub esp, 4			;ebo
	
	mov eax, dword[renderable_initialized]
	test eax, eax
	jnz renderable_create_initialized
		push error_not_initialized
		call my_printf
		add esp, 4
		xor eax, eax
		jmp renderable_create_end
		
	renderable_create_initialized:
	
	;alloc the space for the renderable
	push 56
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;zero all of the values
	push 56
	push 0
	push dword[ebp-4]
	call my_memset_dword
	add esp, 12
	
	;set scale and attrib layout
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp+16]
	mov dword[eax+52], ecx
	
	mov ecx, dword[ONE]
	mov dword[eax+40], ecx
	mov dword[eax+44], ecx
	mov dword[eax+48], ecx

	
	;do general opengl things
	lea eax, [ebp-8]
	push eax
	push 1
	call [glGenVertexArrays]
	
	
	lea eax, [ebp-16]
	push eax
	push 2
	call [glGenBuffers]
	
	
	push dword[ebp-8]
	call [glBindVertexArray]
	
	
	push dword[ebp-12]
	push dword[GL_ARRAY_BUFFER]
	call [glBindBuffer]
	
	
	push dword[GL_STATIC_DRAW]
	mov eax, dword[ebp+8]
	push dword[eax+12]			;vertices
	mov eax, dword[eax]
	imul eax, 4
	push eax					;sizeof(vertices)
	push dword[GL_ARRAY_BUFFER]
	call [glBufferData]
	
	
	push dword[ebp-16]
	push dword[GL_ELEMENT_ARRAY_BUFFER]
	call [glBindBuffer]
	
	push dword[GL_STATIC_DRAW]
	mov eax, dword[ebp+12]
	push dword[eax+12]			;indices
	mov eax, dword[eax]
	shl eax, 2
	push eax					;sizeof(indices)
	push dword[GL_ELEMENT_ARRAY_BUFFER]
	call [glBufferData]
	
	;do attribute layout specific opengl things
	mov eax, dword[ebp+16]		;attrib layout in eax
	cmp eax, dword[RENDERABLE_ATTRIB_P3]
	je renderable_create_attrib_p3
	cmp eax, dword[RENDERABLE_ATTRIB_P3C3]
	je renderable_create_attrib_p3c3
	jmp renderable_create_attrib_done
	renderable_create_attrib_p3:
	
		push 0
		push 12
		push dword[GL_FALSE]
		push dword[GL_FLOAT]
		push 3
		push 0
		call [glVertexAttribPointer]
		
		push 0
		call [glEnableVertexAttribArray]
		jmp renderable_create_attrib_done
		
	renderable_create_attrib_p3c3:
		
		push 0
		push 24
		push dword[GL_FALSE]
		push dword[GL_FLOAT]
		push 3
		push 0
		call [glVertexAttribPointer]
		
		push 12
		push 24
		push dword[GL_FALSE]
		push dword[GL_FLOAT]
		push 3
		push 1
		call [glVertexAttribPointer]
		
		push 0
		call [glEnableVertexAttribArray]
		push 1
		call [glEnableVertexAttribArray]
		
		jmp renderable_create_attrib_done
	
	renderable_create_attrib_done:
	
	push 0
	call [glBindVertexArray]
	
	;set vao, vbo, ebo and index count
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp-8]
	mov dword[eax], ecx
	mov ecx, dword[ebp-12]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp-16]
	mov dword[eax+8], ecx
	
	mov ecx, dword[ebp+12]
	mov ecx, dword[ecx]		;index count in ecx
	mov dword[eax+12], ecx
	
	
	
	mov eax, dword[ebp-4]
	
	renderable_create_end:
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_destroy:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	
	lea ecx, [eax]
	push ecx
	lea ecx, [eax+4]
	push ecx
	lea ecx, [eax+8]
	push eax
	push 1
	call [glDeleteBuffers]
	push 1
	call [glDeleteBuffers]
	push 1
	call [glDeleteVertexArrays]
	
	push dword[ebp+8]
	call my_free
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
renderable_render:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;currently used shader
	sub esp, 64		;model matrix
	
	;is texture necessary
	mov eax, dword[ebp+8]
	mov eax, dword[eax+52]
	cmp eax, dword[RENDERABLE_ATTRIB_P3]
	je renderable_render_bind_texture_done
	cmp eax, dword[RENDERABLE_ATTRIB_P3C3]
	je renderable_render_bind_texture_done
		;set texture
	renderable_render_bind_texture_done:
	
	;choose shader
	mov eax, dword[ebp+8]
	mov eax, dword[eax+52]
	cmp eax, dword[RENDERABLE_ATTRIB_P3]
	je renderable_render_shader_p3
	cmp eax, dword[RENDERABLE_ATTRIB_P3C3]
	je renderable_render_shader_p3c3
	jmp renderable_render_end
	
	renderable_render_shader_p3:
		push dword[shader_p3]
		call [glUseProgram]
		
		mov eax, dword[shader_p3]
		mov dword[ebp-4], eax
		jmp renderable_render_shader_done
		
	renderable_render_shader_p3c3:
		push dword[shader_p3c3]
		call [glUseProgram]
		
		mov eax, dword[shader_p3c3]
		mov dword[ebp-4], eax
		jmp renderable_render_shader_done
		
	renderable_render_shader_done:
	
	;set matrices
	push uniform_name_pv
	push dword[ebp-4]		;current shader
	call [glGetUniformLocation]
	
	push dword[ebp+12]		;pv
	push dword[GL_TRUE]
	push 1
	push eax
	call [glUniformMatrix4fv]
	
	
	lea eax, [ebp-68]
	push eax
	push dword[ebp+8]
	call renderable_calculateModel
	add esp, 8
	
	push uniform_name_model
	push dword[ebp-4]
	call [glGetUniformLocation]
	
	lea ecx, [ebp-68]
	push ecx
	push dword[GL_TRUE]
	push 1
	push eax
	call [glUniformMatrix4fv]
	
	;render
	mov eax, dword[ebp+8]
	push dword[eax]
	call [glBindVertexArray]
	
	push 0
	push dword[GL_UNSIGNED_INT]
	mov eax, dword[ebp+8]
	push dword[eax+12]
	push dword[renderable_primitive]
	call [glDrawElements]
	
	push 0
	call [glBindVertexArray]
	push 0
	call [glUseProgram]
	
	renderable_render_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;void renderable_calculateModel(Renderable* renderable, mat4* buffer)
renderable_calculateModel:
	push ebp
	mov ebp, esp
	
	;initialize buffer
	push dword[ONE]
	push dword[ebp+12]
	call mat4_init
	
	;translation
	mov eax, dword[ebp+8]
	add eax, 16
	push eax		;&position
	push dword[ebp+12]
	call mat4_translate
	
	;rotations (the ones with very little value are skipped)
	mov eax, dword[ebp+8]			;renderable in eax
	mov ecx, dword[eax+28]			;renderable.rotation.x in ecx
	and ecx, 0x7fffffff				;|renderable.rotation.x| in ecx
	cmp ecx, dword[EPSILON]
	jl renderable_calculateModel_skip_x
		push dword[eax+28]
		push X_AXIS
		push dword[ebp+12]
		call mat4_rotate
	renderable_calculateModel_skip_x:
	
	mov eax, dword[ebp+8]			;renderable in eax
	mov ecx, dword[eax+32]			;renderable.rotation.y in ecx
	and ecx, 0x7fffffff				;|renderable.rotation.y| in ecx
	cmp ecx, dword[EPSILON]
	jl renderable_calculateModel_skip_y
		push dword[eax+32]
		push Y_AXIS
		push dword[ebp+12]
		call mat4_rotate
	renderable_calculateModel_skip_y:
	
	mov eax, dword[ebp+8]			;renderable in eax
	mov ecx, dword[eax+36]			;renderable.rotation.z in ecx
	and ecx, 0x7fffffff				;|renderable.rotation.z| in ecx
	cmp ecx, dword[EPSILON]
	jl renderable_calculateModel_skip_z
		push dword[eax+36]
		push Y_AXIS
		push dword[ebp+12]
		call mat4_rotate
	renderable_calculateModel_skip_z:
	
	
	;scale
	mov eax, dword[ebp+8]
	push dword[ONE]
	push dword[eax+48]
	push dword[eax+44]
	push dword[eax+40]
	mov eax, esp
	push eax
	push dword[ebp+12]
	call mat4_scale
	
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_setPrimitive:
	mov eax, dword[esp+4]
	mov dword[renderable_primitive], eax
	ret