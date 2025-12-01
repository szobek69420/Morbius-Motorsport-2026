[BITS 32]

section .rodata use32
	test_text db "olive delights",10,0

	MAX_LIGHT_COUNT dd 100
	POINT_LIGHT_SIZE dd 32		;the size of the data of one point light in the instance vbo
	GLOBAL_LIGHT_SIZE dd 32		;the size of the data of one global light in the instance vbo

section .data use32
	initialized dd 0

	global_volume_renderable dd 0
	point_volume_renderable dd 0
	
	global_instance_vbo dd 0
	point_instance_vbo dd 0
	
	shader_global dd 0
	shader_point dd 0
	
	current_global_count dd 0
	current_point_count dd 0

section .text use32

	global lightRenderer_init				;void lightRenderer_init()
	global lightRenderer_deinit				;void lightRenderer_deinit()

	;copies the depth buffer of gBuffer into target
	;clears the target colour buffer
	;void lightRenderer_prepareTargetFBO(Framebuffer* hdrTarget, Framebuffer* gBuffer)
	global lightRenderer_prepareTargetFBO
	
	global lightRenderer_updatePointLights	;void lightRenderer_updatePointLights(vector<PointLight*> lights)
	
	;overwrites the currently bound framebuffer
	;overwrites the blend func
	;overwrites the blend equation
	;overwrites the depth func
	;overwrites the depth mask
	;void lightRenderer_renderPointLights(Framebuffer* hdrTarget, FrameBuffer* gBuffer, mat4* pv)
	global lightRenderer_renderPointLights
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern lightVolume_createGlobal
	extern lightVolume_createPoint
	extern renderable_destroy
	extern renderable_getVAO
	extern renderable_enableBlending
	extern renderable_enableDepthTest
	extern renderable_setDepthFunc
	extern renderable_renderCustomInstanced
	extern renderable_setExtraTexture2D
	
	extern renderable_useShader
	extern renderable_createShader
	extern renderable_destroyShader
	
	extern framebuffer_bind
	extern glViewport
	extern glClear
	extern glClearColor
	extern glBindFramebuffer
	extern glBlitFramebuffer
	extern GL_READ_FRAMEBUFFER
	extern GL_DRAW_FRAMEBUFFER
	extern GL_COLOR_BUFFER_BIT
	extern GL_DEPTH_BUFFER_BIT
	extern GL_NEAREST
	
	extern glGenBuffers
	extern glDeleteBuffers
	extern glBindBuffer
	extern glBindVertexArray
	extern glBufferData
	extern glBufferSubData
	extern glVertexAttribPointer
	extern glVertexAttribDivisor
	extern glEnableVertexAttribArray
	extern glBlendFunc
	extern glDepthMask
	extern GL_ARRAY_BUFFER
	extern GL_DYNAMIC_DRAW
	extern GL_FALSE
	extern GL_TRUE
	extern GL_FLOAT
	extern GL_ONE
	extern GL_SRC_ALPHA
	extern GL_ONE_MINUS_SRC_ALPHA
	extern GL_LESS
	extern GL_GREATER
	
	
lightRenderer_init:
	push ebp
	mov ebp, esp
	
	;check if the system is already initialized
	test dword[initialized], 0xffffffff
	jz lightRenderer_init_not_initialized
		push lightRenderer_init_error_already_initialized
		call my_printf
		jmp lightRenderer_init_end
		
		lightRenderer_init_error_already_initialized db "lightRenderer_init: the system is already initialized",10,0
	lightRenderer_init_not_initialized:
	
	;create the light volumes
	call lightVolume_createGlobal
	mov dword[global_volume_renderable], eax
	call lightVolume_createPoint
	mov dword[point_volume_renderable], eax
	
	;create and bind the instance vbos
	push global_instance_vbo
	push 1
	call [glGenBuffers]
	
	push dword[global_volume_renderable]
	call renderable_getVAO
	mov dword[esp], eax
	call [glBindVertexArray]
	
	push dword[global_instance_vbo]
	push dword[GL_ARRAY_BUFFER]
	call [glBindBuffer]
	
	push dword[GL_DYNAMIC_DRAW]
	push 0
	mov eax, dword[MAX_LIGHT_COUNT]
	imul eax, dword[GLOBAL_LIGHT_SIZE]
	push eax
	push dword[GL_ARRAY_BUFFER]
	call [glBufferData]
	
	push 0
	push 16
	push dword[GL_FALSE]
	push dword[GL_FLOAT]
	push 4
	push 2
	call [glVertexAttribPointer]
	push 1
	push 2
	call [glVertexAttribDivisor]
	push 2
	call [glEnableVertexAttribArray]		;vec4(normalizedDir.xyz, isDirectional)
	
	push 16
	push 16
	push dword[GL_FALSE]
	push dword[GL_FLOAT]
	push 4
	push 3
	call [glVertexAttribPointer]
	push 1
	push 3
	call [glVertexAttribDivisor]
	push 3
	call [glEnableVertexAttribArray]		;vec4(colour.rgb, intensity)
	
	
	
	push point_instance_vbo
	push 1
	call [glGenBuffers]
	
	push dword[point_volume_renderable]
	call renderable_getVAO
	mov dword[esp], eax
	call [glBindVertexArray]
	
	push dword[point_instance_vbo]
	push dword[GL_ARRAY_BUFFER]
	call [glBindBuffer]
	
	push dword[GL_DYNAMIC_DRAW]
	push 0
	mov eax, dword[MAX_LIGHT_COUNT]
	imul eax, dword[POINT_LIGHT_SIZE]
	push eax
	push dword[GL_ARRAY_BUFFER]
	call [glBufferData]
	
	push 0
	push 16
	push dword[GL_FALSE]
	push dword[GL_FLOAT]
	push 4
	push 2
	call [glVertexAttribPointer]
	push 1
	push 2
	call [glVertexAttribDivisor]
	push 2
	call [glEnableVertexAttribArray]		;vec4(pos.xyz, radius)
	
	push 16
	push 16
	push dword[GL_FALSE]
	push dword[GL_FLOAT]
	push 4
	push 3
	call [glVertexAttribPointer]
	push 1
	push 3
	call [glVertexAttribDivisor]
	push 3
	call [glEnableVertexAttribArray]		;vec4(colour.rgb, intensity)
	
	;init light counts
	mov dword[current_global_count], 0
	mov dword[current_point_count], 0
	
	;set the initialized flag
	mov dword[initialized], 69
	
	lightRenderer_init_end:
	mov esp, ebp
	pop ebp
	ret
	
	
lightRenderer_deinit:
	push ebp
	mov ebp, esp
	
	;check if the system is initialized
	test dword[initialized], 0xffffffff
	jnz lightRenderer_deinit_initialized
		push lightRenderer_deinit_error_not_initialized
		call my_printf
		jmp lightRenderer_deinit_end
		
		lightRenderer_deinit_error_not_initialized db "lightRenderer_deinit: the system is not initialized",10,0
	lightRenderer_deinit_initialized:
	
	;destroy the light volumes
	push dword[global_volume_renderable]
	call renderable_destroy
	push dword[point_volume_renderable]
	call renderable_destroy
	
	;destroy the instance vbos
	push global_instance_vbo
	push 1
	call [glDeleteBuffers]
	
	push point_instance_vbo
	push 1
	call [glDeleteBuffers]
	
	;unset the initialized flag
	mov dword[initialized], 0
	
	lightRenderer_deinit_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
lightRenderer_prepareTargetFBO:
	push ebp
	mov ebp, esp
	
	;copy the depth buffer
	mov eax, dword[ebp+12]
	push dword[eax]
	push word[GL_READ_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	mov eax, dword[ebp+8]
	push dword[eax]
	push word[GL_DRAW_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	push dword[GL_NEAREST]
	push dword[GL_DEPTH_BUFFER_BIT]
	push dword[ecx+28]
	push dword[ecx+24]
	push 0
	push 0
	push dword[eax+28]
	push dword[eax+24]
	push 0
	push 0
	call [glBlitFramebuffer]
	
	;bind target buffer
	push dword[ebp+8]
	call framebuffer_bind
	
	;clear colour buffer
	mov eax, dword[ebp+8]
	push dword[eax+28]
	push dword[eax+24]
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
	
	mov esp, ebp
	pop ebp
	ret
	
	
lightRenderer_updatePointLights:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;temp buffer data			4
	sub esp, 4			;buffer data size			8
	
	;check if the vector is kosher
	mov eax, dword[ebp+20]
	mov ecx, dword[eax]
	cmp ecx, dword[MAX_LIGHT_COUNT]
	jbe lightRenderer_updatePointLights_valid_light_count
		push dword[MAX_LIGHT_COUNT]
		push ecx
		push lightRenderer_updatePointLights_error_too_many_lights
		call my_printf
		jmp lightRenderer_updatePointLights_end
		
		lightRenderer_updatePointLights_error_too_many_lights db "lightRenderer_updatePointLights: %d is not a valid light count (should be in [0;%d])",10,0
	
	lightRenderer_updatePointLights_valid_light_count:	
	
	;set the point count
	mov dword[current_point_count], ecx
	test ecx, ecx
	jz lightRenderer_updatePointLights_end
	
	;calculate the size of the data and alloc it
	mov ecx, dword[eax]
	imul ecx, dword[POINT_LIGHT_SIZE]
	mov dword[ebp-4], ecx
	
	push ecx
	call my_malloc
	mov dword[ebp-4], eax
	
	;fill up the buffer
	mov eax, dword[ebp+20]
	mov ebx, dword[eax]			;index in ebx
	mov esi, dword[eax+12]		;current light in esi
	mov edi, dword[ebp-4]		;current pos in buffer in edi
	cmp ebx, 0
	jle lightRenderer_updatePointLights_loop_end
	lightRenderer_updatePointLights_loop_start:
		mov eax, dword[esi]
		
		mov ecx, dword[eax]
		mov dword[edi], ecx
		mov edx, dword[eax+4]
		mov dword[edi+4], edx
		mov ecx, dword[eax+8]
		mov dword[edi+8], ecx
		mov edx, dword[eax+12]
		mov dword[edi+12], edx
		mov ecx, dword[eax+16]
		mov dword[edi+16], ecx
		mov edx, dword[eax+20]
		mov dword[edi+20], edx
		mov ecx, dword[eax+24]
		mov dword[edi+24], ecx
		mov edx, dword[eax+28]
		mov dword[edi+28], edx
		
		add esi, 4
		add edi, dword[POINT_LIGHT_SIZE]
		dec ebx
		jnz lightRenderer_updatePointLights_loop_start
		
	lightRenderer_updatePointLights_loop_end:
	
	;send the buffer data to the GL
	push dword[point_instance_vbo]
	push dword[GL_ARRAY_BUFFER]
	call [glBindBuffer]
	
	push dword[ebp-4]
	push dword[ebp-8]
	push 0
	push dword[GL_ARRAY_BUFFER]
	call [glBufferSubData]
	
	push 0
	push dword[GL_ARRAY_BUFFER]
	call [glBindBuffer]
	
	
	;free the temp buffer
	push dword[ebp-4]
	call my_free
	
	
	lightRenderer_updatePointLights_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
	
lightRenderer_renderPointLights:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;check if there are any point lights
	cmp dword[current_point_count], 0
	jle lightRenderer_renderPointLights_end
	
	;enable blending and depth test
	push 69
	call renderable_enableDepthTest
	call renderable_enableBlending
	
	;set blend func
	push dword[GL_ONE]
	push dword[GL_ONE]
	call [glBlendFunc]
	
	;set depth func and depth mask
	push dword[GL_GREATER]
	call renderable_setDepthFunc
	push dword[GL_FALSE]
	call [glDepthMask]
	
	;bind the target framebuffer
	push dword[ebp+20]
	call framebuffer_bind
	
	;set the gBuffer colour attachments as extra textures
	mov ebx, dword[ebp+24]
	
	push dword[ebx+4]
	push 0
	push dword[point_volume_renderable]
	call renderable_setExtraTexture2D		;position
	
	push dword[ebx+8]
	push 1
	push dword[point_volume_renderable]
	call renderable_setExtraTexture2D		;normal
	
	push dword[ebx+12]
	push 2
	push dword[point_volume_renderable]
	call renderable_setExtraTexture2D		;albedo
	
	;use shader
	push dword[shader_point]
	call renderable_useShader
	
	;render all of the lights
	push dword[current_point_count]
	push 69
	push dword[shader_point]
	push dword[ebp+28]
	push dword[point_volume_renderable]
	call renderable_renderCustomInstanced
	
	;reset depth func and depth mask
	push dword[GL_LESS]
	call renderable_setDepthFunc
	push dword[GL_TRUE]
	call [glDepthMask]
	
	;reset the blend func
	push dword[GL_ONE_MINUS_SRC_ALPHA]
	push dword[GL_SRC_ALPHA]
	call [glBlendFunc]
	
	;disable blending and depth test
	push 0
	call renderable_enableBlending
	call renderable_enableDepthTest
	
	lightRenderer_renderPointLights_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret