[BITS 32]

;layout
;struct Renderable{
;	GLuint vao, vbo, ebo;			;0
;	int indexCount;					;12		//it is vertex count if there is no ebo
;	vec3 position;					;16
;	vec3 rotation;					;28
;	vec3 scale;						;40
;	int vertexAttribLayout;			;52
;	GLuint albedoMap, specularMap	;56
;		//the extra2DTextures use the textures GL_TEXTURE2 to GL_TEXTURE5 and they are of type GL_TEXTURE_2D.
;		//They aren't destroyed with the renderable
;	GLuint extra2DTextures[4]		;64
;}		;80 bytes overall

NO_EBO equ 0xFFFFFFFF

section .rodata

	global RENDERABLE_ATTRIB_P3
	global RENDERABLE_ATTRIB_P3UV2
	global RENDERABLE_ATTRIB_P3C3
	
	RENDERABLE_ATTRIB_P3 dd 1
	RENDERABLE_ATTRIB_P3UV2 dd 2
	RENDERABLE_ATTRIB_P3C3 dd 3
	RENDERABLE_ATTRIB_CUSTOM dd 4
	
	global RENDERABLE_UNIFORM_1F
	global RENDERABLE_UNIFORM_VEC2
	global RENDERABLE_UNIFORM_VEC3
	global RENDERABLE_UNIFORM_VEC4
	global RENDERABLE_UNIFORM_1I
	global RENDERABLE_UNIFORM_2I
	global RENDERABLE_UNIFORM_3I
	global RENDERABLE_UNIFORM_4I
	global RENDERABLE_UNIFORM_MAT3
	global RENDERABLE_UNIFORM_MAT4
	global RENDERABLE_UNIFORM_FLOAT_ARRAY
	global RENDERABLE_UNIFORM_VEC2_ARRAY
	global RENDERABLE_UNIFORM_VEC3_ARRAY
	global RENDERABLE_UNIFORM_VEC4_ARRAY
	
	RENDERABLE_UNIFORM_1F dd 0
	RENDERABLE_UNIFORM_VEC2 dd 1
	RENDERABLE_UNIFORM_VEC3 dd 2
	RENDERABLE_UNIFORM_VEC4 dd 3
	RENDERABLE_UNIFORM_1I dd 4
	RENDERABLE_UNIFORM_2I dd 5
	RENDERABLE_UNIFORM_3I dd 6
	RENDERABLE_UNIFORM_4I dd 7
	RENDERABLE_UNIFORM_MAT3 dd 8
	RENDERABLE_UNIFORM_MAT4 dd 9
	RENDERABLE_UNIFORM_FLOAT_ARRAY dd 10
	RENDERABLE_UNIFORM_VEC2_ARRAY dd 11
	RENDERABLE_UNIFORM_VEC3_ARRAY dd 12
	RENDERABLE_UNIFORM_VEC4_ARRAY dd 13
	
	
	error_not_initialized db "renderable: renderable_init has not been called",10,0
	error_unsupported_layout db "renderable_create: unsupported vertex attribute layout",10,0
	error_invalid_uniform_type db "renderable_setUniform: no such uniform type exists blud",10,0
	
	vertex_shader_p3 db "shaders/renderable/p3.vag",0
	fragment_shader_p3 db "shaders/renderable/p3.fag",0
	
	vertex_shader_p3c3 db "shaders/renderable/p3c3.vag",0
	fragment_shader_p3c3 db "shaders/renderable/p3c3.fag",0
	
	vertex_shader_p3uv2 db "shaders/renderable/p3uv2.vag",0
	fragment_shader_p3uv2 db "shaders/renderable/p3uv2.fag",0
	
	
	uniform_name_pv db "pv",0
	uniform_name_model db "model",0
	uniform_name_albedo db "albedo",0
	uniform_name_specular db "specular",0
	uniform_name_extra2DTexture0 db "extra2DTexture0",0
	uniform_name_extra2DTexture1 db "extra2DTexture1",0
	uniform_name_extra2DTexture2 db "extra2DTexture2",0
	uniform_name_extra2DTexture3 db "extra2DTexture3",0
	
	uniform_names_texture2d:		;helper for renderable_renderCustom
	dd uniform_name_albedo
	dd uniform_name_specular
	dd uniform_name_extra2DTexture0
	dd uniform_name_extra2DTexture1
	dd uniform_name_extra2DTexture2
	dd uniform_name_extra2DTexture3
	
	EPSILON dd 0.00001
	ONE dd 1.0
	
	X_AXIS dd 1.0, 0.0, 0.0
	Y_AXIS dd 0.0, 1.0, 0.0
	Z_AXIS dd 0.0, 0.0, -1.0
	
	test_text db "microsoft bing chilling",10,0
	print_int_nl db "%d",10,0
	print_four_ints_nl db "%d %d %d %d",10,0
	
section .data use32
	renderable_initialized dd 0
	shader_p3 dd 0
	shader_p3c3 dd 0
	shader_p3uv2 dd 0
	
	renderable_primitive dd 0
	
section .text use32

	global renderable_init				;void renderable_init()		//initializes the components of the renderable handler
	global renderable_deinit			;void renderable_deinit()	//undoes renderable_init
	
	global renderable_create			;Renderable* renderable_create(const vector<float>* vertices, const vector<int>* indices, int vertexAttribLayout)
	
	;the vertex attributes start from location=0 and are incremented by one
	;first have to come the float attribs (float, vec2, vec3, vec4...)
	;then the unsigned int attribs (uint, uvec2, uvec3, uvec4...)
	;Renderable* renderable_createCustom(
	;	const vector<float>* vertices,
	;	const vector<int>* indices,				//if this is NULL, then no ebo will be used
	;	int floatVertexAttribCount,
	;	int... floatsPerAttrib
	;	int uintVertexAttribCount,
	;	int... uintsPerAttrib
	;);
	global renderable_createCustom
	global renderable_destroy			;void renderable_destroy(Renderable* renderable)
	
	global renderable_render			;void renderable_render(Renderable* renderable, mat4* pv)
	global renderable_renderCustom		;void renderable_renderCustom(Renderable* renderable, mat4* pv, GLuint shader, int texturesUsed)

	;both setAlbedo and setSpecular sets the textures the 0 if the path is NULL
	global renderable_setAlbedo			;void renderable_setAlbedo(Renderable* renderable, const char* albedoMapPath)
	global renderable_setSpecular		;void renderable_setSpecular(Renderable* renderable, const char* specularMapPath)
	
	
	global renderable_getPosition		;vec3* renderable_getPosition(Renderable*)
	global renderable_getRotation		;vec3* renderable_getRotation(Renderable*)
	global renderable_getScale			;vec3* rendeable_getScale(Renderable*)
	
	global renderable_setPosition		;void renderable_setPosition(Renderable*, vec3*)
	global renderable_setRotation		;void renderable_setRotation(Renderable*, vec3*)
	global renderable_setScale			;void renderable_setScale(Renderable*, vec3*)
	
	global renderable_createShader		;GLuint renderable_createShader(const char* vertexShaderPath, const char* fragmentShaderPath, const char* geometryShaderNullablePath)
	global renderable_destroyShader		;void renderable_destroyShader(GLuint shader)
	global renderable_useShader			;void renderable_useShader(GLuint shader)
	
	global renderable_setExtraTexture2D	;void renderable_setExtraTexture2D(Renderable* renderable, int textureNumber, GLuint texture2D)
	
	;doesn't call glUseShader so make sure you use it in conjunction with renderable_useShader
	global renderable_setUniform		;void renderable_setUniform(GLuint shader, const char* uniformName, int uniformType, ...data)
	
	;it is a system state setting function
	global renderable_setPrimitive		;void renderable_setPrimitive(GLuint primitive)
	
	;it is a system state setting function
	;enable should be 0, if the depth test should be disabled
	global renderable_enableDepthTest	;void renderable_enableDepthTest(int enable)
	
	;it is a system state setting function
	;for example GL_LESS
	global renderable_setDepthFunc		;void renderable_setDepthFunc(Glenum func)
	
	;it is a system state setting function
	;enable should be 0, if the blending should be disabled
	global renderable_enableBlending	;void renderable_enableBlending(int enable)
	
	;it is a system state setting function
	;void renderable_setPointSize(float size)
	global renderable_setPointSize
	;it is a system state setting function
	;void renderable_setLineWidth(float width)
	global renderable_setLineWidth
	
	global renderable_calculateNormalMatrix	;void* renderable_calculateNormalMatrix(mat3* buffer, mat4* model_or_viewModel_matrix)
	
	extern glGenVertexArrays
	extern glGenBuffers
	extern glDeleteVertexArrays
	extern glDeleteBuffers
	extern glBindVertexArray
	extern glBindBuffer
	extern glBufferData
	extern glVertexAttribPointer
	extern glVertexAttribIPointer
	extern glEnableVertexAttribArray
	extern glGetUniformLocation
	extern glUniform1f
	extern glUniform2f
	extern glUniform3f
	extern glUniform4f
	extern glUniform1i
	extern glUniform2i
	extern glUniform3i
	extern glUniform4i
	extern glUniformMatrix3fv
	extern glUniformMatrix4fv
	extern glUniform1fv
	extern glUniform2fv
	extern glUniform3fv
	extern glUniform4fv
	extern glUseProgram
	extern glDrawArrays
	extern glDrawElements
	extern GL_ARRAY_BUFFER
	extern GL_ELEMENT_ARRAY_BUFFER
	extern GL_STATIC_DRAW
	extern GL_FLOAT
	extern GL_UNSIGNED_INT
	extern GL_TRUE
	extern GL_FALSE
	extern GL_TRIANGLES
	
	
	extern glBindTexture
	extern glActiveTexture
	extern GL_TEXTURE_2D
	extern GL_TEXTURE0
	extern GL_TEXTURE1
	extern GL_REPEAT
	extern GL_NEAREST
	
	extern glEnable
	extern glDisable
	extern GL_DEPTH_TEST
	extern glDepthFunc
	extern GL_BLEND
	extern GL_SRC_ALPHA
	extern GL_ONE_MINUS_SRC_ALPHA
	extern glBlendFunc
	
	extern glPointSize
	extern glLineWidth
	
	extern glGetError
	
	extern my_printf
	
	extern my_malloc
	extern my_free
	extern my_memset_dword
	
	extern shader_import
	extern shader_destroy
	
	extern textureHandler_load
	extern textureHandler_unload
	
	extern mat3_transpose
	extern mat3_inverse
	extern mat3_print
	extern mat4_init
	extern mat4_transpose
	extern mat4_inverse
	extern mat4_scale
	extern mat4_rotate
	extern mat4_translate
	extern mat4_convertToMat3
	
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
	
	push 0
	push fragment_shader_p3uv2
	push vertex_shader_p3uv2
	call shader_import
	mov dword[shader_p3uv2], eax
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
	
	push dword[shader_p3uv2]
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
	push 80
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;zero all of the values
	push 80
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
	
	
	lea eax, [ebp-12]
	push eax				;&vbo
	push 1
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
	
	;is there ebo?
	mov dword[ebp-16], NO_EBO
	
	cmp dword[ebp+12], 0
	je renderable_create_no_ebo
		lea eax, [ebp-16]
		push eax				;&ebo
		push 1
		call [glGenBuffers]
	
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
	renderable_create_no_ebo:
	
	;do attribute layout specific opengl things
	mov eax, dword[ebp+16]		;attrib layout in eax
	cmp eax, dword[RENDERABLE_ATTRIB_P3]
	je renderable_create_attrib_p3
	cmp eax, dword[RENDERABLE_ATTRIB_P3C3]
	je renderable_create_attrib_p3c3
	cmp eax, dword[RENDERABLE_ATTRIB_P3UV2]
	je renderable_create_attrib_p3uv2
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
		
		
	renderable_create_attrib_p3uv2:
		push 0
		push 20
		push dword[GL_FALSE]
		push dword[GL_FLOAT]
		push 3
		push 0
		call [glVertexAttribPointer]
		
		push 12
		push 20
		push dword[GL_FALSE]
		push dword[GL_FLOAT]
		push 2
		push 1
		call [glVertexAttribPointer]
		
		push 0
		call [glEnableVertexAttribArray]
		push 1
		call [glEnableVertexAttribArray]
		
		jmp renderable_create_attrib_done
		
	renderable_create_attrib_unsupported:
		push error_unsupported_layout
		call my_printf
		xor eax, eax
		jmp renderable_create_end
	
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
	
	cmp dword[ebp-16], NO_EBO
	je renderable_create_indexCount_no_ebo
	renderable_create_indexCount_ebo:
		mov ecx, dword[ebp+12]
		mov ecx, dword[ecx]		;index count in ecx
		mov dword[eax+12], ecx
		jmp renderable_create_indexCount_done
		
	renderable_create_indexCount_no_ebo:
		mov ecx, dword[ebp+8]
		mov ecx, dword[ecx]		;vertex count in ecx
		mov dword[eax+12], ecx
		jmp renderable_create_indexCount_done
		
	renderable_create_indexCount_done:
	
	
	;set return value
	mov eax, dword[ebp-4]
	
	renderable_create_end:
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_createCustom:
	push ebp
	push ebx
	push esi
	mov ebp, esp
	
	sub esp, 4				;renderable
	sub esp, 4				;stride
	sub esp, 4				;uint attrib count param location offset
	
	;create the renderable as normal
	push dword[RENDERABLE_ATTRIB_CUSTOM]
	push dword[ebp+20]
	push dword[ebp+16]
	call renderable_create
	mov dword[ebp-4], eax
	add esp, 12
	
	;the the uint attrib count param offset
	mov eax, dword[ebp+24]
	lea ecx, [ebp+28+4*eax]
	mov dword[ebp-12], ecx
	
	;get the stride
	mov dword[ebp-8], 0
	
	;float part of the stride
	cmp dword[ebp+24], 0
	jle renderable_createCustom_stride_float_loop_end
	
		xor ebx, ebx
		renderable_createCustom_stride_float_loop_start:
			mov eax, dword[ebp+28+4*ebx]
			add dword[ebp-8], eax
			
			inc ebx
			cmp ebx, dword[ebp+24]
			jl renderable_createCustom_stride_float_loop_start
		renderable_createCustom_stride_float_loop_end:
	
	;uint part of the stride
	mov esi, dword[ebp-12]
	cmp dword[esi], 0
	jle renderable_createCustom_stride_uint_loop_end
		
		xor ebx, ebx
		renderable_createCustom_stride_uint_loop_start:
			mov eax, dword[esi+4+4*ebx]
			add dword[ebp-8], eax
			
			inc ebx
			cmp ebx, dword[esi]
			jl renderable_createCustom_stride_uint_loop_start
		renderable_createCustom_stride_uint_loop_end:
	
	shl dword[ebp-8], 2
	
	;bind vao and vbo
	mov eax, dword[ebp-4]
	push dword[eax+4]
	push dword[GL_ARRAY_BUFFER]
	push dword[eax]
	call [glBindVertexArray]
	call [glBindBuffer]
	
	;set the renderable attributes
	xor esi, esi				;current vertex attrib offset
	
	cmp dword[ebp+24], 0
	jle renderable_createCustom_attrib_float_loop_end
	
		xor ebx, ebx				;index in ebx
		renderable_createCustom_attrib_float_loop_start:
			push esi						;current vertex attrib offset
			push dword[ebp-8]				;stride
			push dword[GL_FALSE]
			push dword[GL_FLOAT]
			push dword[ebp+28+4*ebx]		;float count
			push ebx						;attrib location
			call [glVertexAttribPointer]
			
			push ebx
			call [glEnableVertexAttribArray]
		
			mov eax, dword[ebp+28+4*ebx]
			lea esi, [esi+4*eax]			;update vertex attrib offset
		
			inc ebx
			cmp ebx, dword[ebp+24]
			jl renderable_createCustom_attrib_float_loop_start
		renderable_createCustom_attrib_float_loop_end:
	
	mov eax, dword[ebp-12]
	cmp dword[eax], 0
	jle renderable_createCustom_attrib_uint_loop_end
	
		xor ebx, ebx				;index in ebx
		renderable_createCustom_attrib_uint_loop_start:
			mov ecx, dword[ebp-12]
			mov edx, ebx
			add edx, dword[ebp+24]
		
			push esi						;current vertex attrib offset
			push dword[ebp-8]				;stride
			push dword[GL_UNSIGNED_INT]
			push dword[ecx+4+4*ebx]		;uint count
			push edx						;attrib location
			call [glVertexAttribIPointer]
			
			mov edx, ebx
			add edx, dword[ebp+24]
			push edx
			call [glEnableVertexAttribArray]
		
			mov ecx, dword[ebp-12]
			mov eax, dword[ecx+4+4*ebx]
			lea esi, [esi+4*eax]			;update vertex attrib offset
		
			inc ebx
			cmp ebx, dword[ecx]
			jl renderable_createCustom_attrib_uint_loop_start
		renderable_createCustom_attrib_uint_loop_end:
	
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop esi
	pop ebx
	pop ebp
	ret
	
	
renderable_destroy:
	push ebp
	mov ebp, esp
	
	;destroy textures if necessary
	mov eax, dword[ebp+8]
	cmp dword[eax+56], 0
	je renderable_destroy_no_albedo
		push dword[eax+56]
		call textureHandler_unload
		add esp, 4
	renderable_destroy_no_albedo:
	
	mov eax, dword[ebp+8]
	cmp dword[eax+60], 0
	je renderable_destroy_no_specular
		push dword[eax+60]
		call textureHandler_unload
		add esp, 4
	renderable_destroy_no_specular:
	
	;destroy buffers and vertex arrays
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
	
	;choose shader
	mov eax, dword[ebp+8]
	mov eax, dword[eax+52]
	cmp eax, dword[RENDERABLE_ATTRIB_P3]
	je renderable_render_shader_p3
	cmp eax, dword[RENDERABLE_ATTRIB_P3C3]
	je renderable_render_shader_p3c3
	cmp eax, dword[RENDERABLE_ATTRIB_P3UV2]
	je renderable_render_shader_p3uv2
	jmp renderable_render_end
	
	renderable_render_shader_p3:
		;use shader
		push dword[shader_p3]
		call renderable_useShader
		
		mov eax, dword[shader_p3]
		mov dword[ebp-4], eax
		jmp renderable_render_shader_done
		
	renderable_render_shader_p3c3:
		;use shader
		push dword[shader_p3c3]
		call renderable_useShader
		
		mov eax, dword[shader_p3c3]
		mov dword[ebp-4], eax
		jmp renderable_render_shader_done
		
	renderable_render_shader_p3uv2:
		;bind textures
		mov eax, dword[ebp+8]
		push dword[eax+60]			;specular map
		push dword[GL_TEXTURE_2D]
		push dword[GL_TEXTURE1]
		push dword[eax+56]			;albedo map
		push dword[GL_TEXTURE_2D]
		push dword[GL_TEXTURE0]
		call [glActiveTexture]
		call [glBindTexture]
		call [glActiveTexture]
		call [glBindTexture]
		
		;use shader
		push dword[shader_p3uv2]
		call renderable_useShader
		
		mov eax, dword[shader_p3uv2]
		mov dword[ebp-4], eax
		jmp renderable_render_shader_done
		
		;set texture uniforms
		push 0
		push dword[RENDERABLE_UNIFORM_1I]
		push uniform_name_albedo
		push dword[ebp-4]			;current shader
		call renderable_setUniform
		add esp, 16
		
		push 1
		push dword[RENDERABLE_UNIFORM_1I]
		push uniform_name_specular
		push dword[ebp-4]			;current shader
		call renderable_setUniform
		add esp, 16
		
		jmp renderable_render_shader_done
		
	renderable_render_shader_done:
	
	;set matrices
	push dword[ebp+12]		;pv
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_pv
	push dword[ebp-4]		;current shader
	call renderable_setUniform
	add esp, 16
	
	
	lea eax, [ebp-68]
	push eax
	push dword[ebp+8]
	call renderable_calculateModel
	add esp, 8
	
	lea ecx, [ebp-68]
	push ecx					;model
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_model
	push dword[ebp-4]
	call renderable_setUniform
	add esp, 16
	
	;render
	mov eax, dword[ebp+8]
	push dword[eax]
	call [glBindVertexArray]
	
	mov eax, dword[ebp+8]
	cmp dword[eax+8], NO_EBO
	je renderable_render_no_ebo
	
	renderable_render_ebo:
		push 0
		push dword[GL_UNSIGNED_INT]
		mov eax, dword[ebp+8]
		push dword[eax+12]
		push dword[renderable_primitive]
		call [glDrawElements]
		jmp renderable_render_done
		
	renderable_render_no_ebo:
		mov eax, dword[ebp+8]
		push dword[eax+12]
		push 0
		push dword[renderable_primitive]
		call [glDrawArrays]
		jmp renderable_render_done
		
	renderable_render_done:
	
	push 0
	call [glBindVertexArray]
	push 0
	call [glUseProgram]
	
	renderable_render_end:
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_renderCustom:
	push ebp
	mov ebp, esp
	
	sub esp, 64		;model matrix
	
	;calculate model matrix
	lea eax, [ebp-64]
	push eax
	push dword[ebp+8]
	call renderable_calculateModel
	add esp, 8
	
	;use shader
	push dword[ebp+16]
	call renderable_useShader
	add esp, 4
	
	;are textures necessary?
	cmp dword[ebp+20], 0
	je renderable_renderCustom_no_textures
		push esi			;save esi
		push edi			;save edi
		push ebx			;save ebx
		
		mov esi, dword[ebp+8]
		lea esi, [esi+56]					;current texture2d in esi
		mov edi, uniform_names_texture2d	;current uniform name in edi
		xor ebx, ebx						;index in ebx
		renderable_renderCustom_texture2d_loop_start:
			cmp dword[esi], 0
			je renderable_renderCustom_texture2d_loop_continue	;is there a texture in the slot?
				
				;bind texture
				mov eax, dword[GL_TEXTURE0]
				add eax, ebx
				push eax
				call [glActiveTexture]
				
				push dword[esi]
				push dword[GL_TEXTURE_2D]
				call [glBindTexture]
				
				;set uniform
				push ebx
				push dword[RENDERABLE_UNIFORM_1I]
				push dword[edi]
				push dword[ebp+16]			;current shader
				call renderable_setUniform
				add esp, 16
				
	
			renderable_renderCustom_texture2d_loop_continue:
			add esi, 4
			add edi, 4
			inc ebx
			cmp ebx, 6	;6 textures for albedo, specular and the 4 extra2DTextures
			jl renderable_renderCustom_texture2d_loop_start
			
		pop ebx				;restore ebx
		pop edi				;restore edi
		pop esi				;restore esi
	
	renderable_renderCustom_no_textures:
	
	;set matrices
	push dword[ebp+12]		;pv
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_pv
	push dword[ebp+16]		;current shader
	call renderable_setUniform
	add esp, 16
	
	lea ecx, [ebp-64]
	push ecx					;model
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_model
	push dword[ebp+16]
	call renderable_setUniform
	add esp, 16
	
	;render
	mov eax, dword[ebp+8]
	push dword[eax]
	call [glBindVertexArray]
	
	mov eax, dword[ebp+8]
	cmp dword[eax+8], NO_EBO
	jne renderable_renderCustom_ebo
	renderable_renderCustom_no_ebo:
		push dword[eax+12]
		push 0
		push dword[renderable_primitive]
		call [glDrawArrays]
		jmp renderable_renderCustom_done
		
	renderable_renderCustom_ebo:
		push 0
		push dword[GL_UNSIGNED_INT]
		mov eax, dword[ebp+8]
		push dword[eax+12]
		push dword[renderable_primitive]
		call [glDrawElements]
		jmp renderable_renderCustom_done
		
	renderable_renderCustom_done:
	
	push 0
	call [glBindVertexArray]
	
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
	
	
renderable_setAlbedo:
	push ebp
	mov ebp, esp
	
	;check if there is already an albedo map loaded and unload it if necessary
	mov eax, dword[ebp+8]
	cmp dword[eax+56], 0
	je renderable_setAlbedo_unload_done
		push dword[eax+56]
		call textureHandler_unload
		add esp, 4
		mov dword[eax+56], 0
	renderable_setAlbedo_unload_done:
	
	;check if the path is NULL (no texture)
	cmp dword[ebp+12], 0
	je renderable_setAlbedo_done
	
	;load the new albedo map
	push 0
	push dword[GL_NEAREST]
	push dword[GL_REPEAT]
	push dword[ebp+12]
	call textureHandler_load
	
	mov ecx, dword[ebp+8]
	mov dword[ecx+56], eax			;save the new texture
	
	renderable_setAlbedo_done:
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_setSpecular:
	push ebp
	mov ebp, esp
	
	;check if there is already a specular map loaded and unload it if necessary
	mov eax, dword[ebp+8]
	cmp dword[eax+60], 0
	je renderable_setSpecular_unload_done
		push dword[eax+60]
		call textureHandler_unload
		add esp, 4
		mov dword[eax+60], 0
	renderable_setSpecular_unload_done:
	
	;check if the path is NULL (no texture)
	cmp dword[ebp+12], 0
	je renderable_setSpecular_done
	
	;load the new specular map
	push 0
	push dword[GL_NEAREST]
	push dword[GL_REPEAT]
	push dword[ebp+12]
	call textureHandler_load
	
	mov ecx, dword[ebp+8]
	mov dword[ecx+60], eax			;save the new texture
	
	renderable_setSpecular_done:
	mov esp, ebp
	pop ebp
	ret
	
	
	
renderable_getPosition:
	mov eax, dword[esp+4]
	add eax, 16
	ret
	
	
renderable_getRotation:
	mov eax, dword[esp+4]
	add eax, 28
	ret
	
	
renderable_getScale:
	mov eax, dword[esp+4]
	add eax, 40
	ret
	
	
renderable_setPosition:
	mov eax, dword[esp+4]
	add eax, 16					;&renderable.position in eax
	mov ecx, dword[esp+8]		;&newValue in ecx
	
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	mov edx, dword[ecx+8]
	mov dword[eax+8], edx
	
	ret
	
	
renderable_setRotation:
	mov eax, dword[esp+4]
	add eax, 28					;&renderable.rotation in eax
	mov ecx, dword[esp+8]		;&newValue in ecx
	
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	mov edx, dword[ecx+8]
	mov dword[eax+8], edx
	
	ret
	
	
renderable_setScale:
	mov eax, dword[esp+4]
	add eax, 40					;&renderable.scale in eax
	mov ecx, dword[esp+8]		;&newValue in ecx
	
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	mov edx, dword[ecx+8]
	mov dword[eax+8], edx
	
	ret
	
	
renderable_createShader:
	push ebp
	mov ebp, esp
	
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[ebp+8]
	call shader_import
	
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_destroyShader:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call shader_destroy
	
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_useShader:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [glUseProgram]
	
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_setExtraTexture2D:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	lea eax, [eax+64+4*ecx]
	mov edx, dword[ebp+16]
	mov dword[eax], edx
	
	mov esp, ebp
	pop ebp
	ret
	
renderable_setUniform:
	push ebp
	mov ebp, esp
	
	sub esp, 4					;uniform location
	
	;use shader
	;push dword[ebp+8]
	;call [glUseProgram]
	
	;get uniform location
	push dword[ebp+12]
	push dword[ebp+8]
	call [glGetUniformLocation]
	mov dword[ebp-4], eax
	
	
	;decide what we want to do
	mov eax, dword[ebp+16]
	lea eax, [renderable_setUniform_switch+4*eax]
	cmp eax, renderable_setUniform_switch
	jl renderable_setUniform_error
	cmp eax, renderable_setUniform_nigga
	jge renderable_setUniform_error
	
	jmp dword[eax]
	
	renderable_setUniform_error:
		push error_invalid_uniform_type
		call my_printf
		jmp renderable_setUniform_end
	
	renderable_setUniform_switch:
	dd renderable_setUniform_float
	dd renderable_setUniform_vec2
	dd renderable_setUniform_vec3
	dd renderable_setUniform_vec4
	dd renderable_setUniform_1i
	dd renderable_setUniform_2i
	dd renderable_setUniform_3i
	dd renderable_setUniform_4i
	dd renderable_setUniform_mat3
	dd renderable_setUniform_mat4
	dd renderable_setUniform_1fv
	dd renderable_setUniform_2fv
	dd renderable_setUniform_3fv
	dd renderable_setUniform_4fv
	renderable_setUniform_nigga:
	
	renderable_setUniform_float:
		push dword[ebp+20]
		push dword[ebp-4]
		call [glUniform1f]
		jmp renderable_setUniform_end
		
	renderable_setUniform_vec2:
		push dword[ebp+24]
		push dword[ebp+20]
		push dword[ebp-4]
		call [glUniform2f]
		jmp renderable_setUniform_end
		
	renderable_setUniform_vec3:
		push dword[ebp+28]
		push dword[ebp+24]
		push dword[ebp+20]
		push dword[ebp-4]
		call [glUniform3f]
		jmp renderable_setUniform_end
		
	renderable_setUniform_vec4:		
		push dword[ebp+32]
		push dword[ebp+28]
		push dword[ebp+24]
		push dword[ebp+20]
		push dword[ebp-4]
		call [glUniform4f]
		jmp renderable_setUniform_end
		
	renderable_setUniform_1i:
		push dword[ebp+20]
		push dword[ebp-4]
		call [glUniform1i]
		jmp renderable_setUniform_end
	
	renderable_setUniform_2i:
		push dword[ebp+24]
		push dword[ebp+20]
		push dword[ebp-4]
		call [glUniform2i]
		jmp renderable_setUniform_end
		
	renderable_setUniform_3i:
		push dword[ebp+28]
		push dword[ebp+24]
		push dword[ebp+20]
		push dword[ebp-4]
		call [glUniform3i]
		jmp renderable_setUniform_end
		
	renderable_setUniform_4i:
		push dword[ebp+32]
		push dword[ebp+28]
		push dword[ebp+24]
		push dword[ebp+20]
		push dword[ebp-4]
		call [glUniform4i]
		jmp renderable_setUniform_end
		
	renderable_setUniform_mat3:
		push dword[ebp+20]
		push dword[GL_TRUE]
		push 1
		push dword[ebp-4]
		call [glUniformMatrix3fv]
		jmp renderable_setUniform_end
		
	renderable_setUniform_mat4:
		push dword[ebp+20]
		push dword[GL_TRUE]
		push 1
		push dword[ebp-4]
		call [glUniformMatrix4fv]
		jmp renderable_setUniform_end
		
	renderable_setUniform_1fv:
		push dword[ebp+24]			;array
		push dword[ebp+20]			;count
		push dword[ebp-4]
		call [glUniform1fv]
		jmp renderable_setUniform_end
		
	renderable_setUniform_2fv:
		push dword[ebp+24]			;array
		push dword[ebp+20]			;count
		push dword[ebp-4]
		call [glUniform2fv]
		jmp renderable_setUniform_end
		
	renderable_setUniform_3fv:
		push dword[ebp+24]			;array
		push dword[ebp+20]			;count
		push dword[ebp-4]
		call [glUniform3fv]
		jmp renderable_setUniform_end
		
	renderable_setUniform_4fv:
		push dword[ebp+24]			;array
		push dword[ebp+20]			;count
		push dword[ebp-4]
		call [glUniform4fv]
		jmp renderable_setUniform_end
	
	renderable_setUniform_end:
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_setPrimitive:
	mov eax, dword[esp+4]
	mov dword[renderable_primitive], eax
	ret
	
	
renderable_enableDepthTest:
	push ebp
	mov ebp, esp
	
	cmp dword[ebp+8], 0
	je renderable_enableDepthTest_disable
		push dword[GL_DEPTH_TEST]
		call [glEnable]
		jmp renderable_enableDepthTest_end
	
	renderable_enableDepthTest_disable:
		push dword[GL_DEPTH_TEST]
		call [glDisable]
	
	renderable_enableDepthTest_end:
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_setDepthFunc:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [glDepthFunc]
	
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_enableBlending:
	push ebp
	mov ebp, esp
	
	cmp dword[ebp+8], 0
	je renderable_enableBlending_disable
		push dword[GL_ONE_MINUS_SRC_ALPHA]
		push dword[GL_SRC_ALPHA]
		call [glBlendFunc]
	
		push dword[GL_BLEND]
		call [glEnable]
		jmp renderable_enableBlending_end
	
	renderable_enableBlending_disable:
		push dword[GL_BLEND]
		call [glDisable]
	
	renderable_enableBlending_end:
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_setPointSize:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [glPointSize]
	
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_setLineWidth:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [glLineWidth]
	
	mov esp, ebp
	pop ebp
	ret
	
	
renderable_calculateNormalMatrix:
	push ebp
	mov ebp, esp
	
	;convert the mat4 to a mat3
	push dword[ebp+12]
	push dword[ebp+8]
	call mat4_convertToMat3
	add esp, 8
	
	
	;calculate the inverse of the mat3
	mov eax, dword[ebp+8]
	sub esp, 8
	mov dword[esp], eax
	mov dword[esp+4], eax
	call mat3_inverse
	
	
	;calculate the transpose of the inverse of the mat3
	call mat3_transpose
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret