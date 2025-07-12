[BITS 32]

section .rodata use32
	vertex_vector:
	dd 20
	dd 20
	dd 4
	dd vertex_data
	vertex_data:
	dd -1.0, -1.0, 1.0, 0.0, 0.0
	dd -1.0, 1.0, 1.0, 0.0, 1.0
	dd 1.0, 1.0, 1.0, 1.0, 1.0
	dd 1.0, -1.0, 1.0, 1.0, 0.0
	
	
	index_vector:
	dd 6
	dd 6
	dd 4
	dd index_data
	index_data:
	dd 1,0,2,2,0,3
	
	mat4_identity:
	dd 1.0, 0.0, 0.0, 0.0
	dd 0.0, 1.0, 0.0, 0.0
	dd 0.0, 0.0, 1.0, 0.0
	dd 0.0, 0.0, 0.0, 1.0
	
	vertex_shader_draw_to_screen db "shaders/pp/draw_to_screen/draw_to_screen.vag",0
	fragment_shader_draw_to_screen db "shaders/pp/draw_to_screen/draw_to_screen.fag",0
	
	vertex_shader_ssao db "shaders/pp/ssao/ssao.vag",0
	fragment_shader_ssao db "shaders/pp/ssao/ssao.fag",0
	
	vertex_shader_deferred_lighting db "shaders/pp/deferred_lighting/deferred_lighting.vag",0
	fragment_shader_deferred_lighting db "shaders/pp/deferred_lighting/deferred_lighting.fag",0
	
	uniform_name_ssaoKernel db "samples",0
	uniform_name_ssaoFramebufferSize db "screenSize",0
	uniform_name_viewMatrix db "view",0
	uniform_name_projectionMatrix db "projection",0
	uniform_name_projectionInverseMatrix db "projection_inverse",0
	uniform_name_sunDirection db "viewSpaceSunDirection",0
	
	ZERO dd 0.0
	ONE dd 1.0
	TWO dd 2.0
	P1 dd 0.1
	SIXTY_FOUR dd 64.0
	FLOAT_SCALER dd 0.000015258789		;1/(2^16)

section .data use32
	initialized dd 0
	renderable dd 0
	
	shader_draw_to_screen dd 0
	shader_ssao dd 0
	shader_deferred_lighting dd 0
	
	texture_ssaoNoise dd 0				;the random rotation texture of the ssao
	

section .text use32

	global postProcessing_init		;void postProcessing_init(int fboWidth, int fboHeight)
	global postProcessing_deinit	;void postProcessing_deinit()
	
	;draws the colourAttachment0 of the given framebuffer to the screen framebuffer
	;DOESN'T CALL glViewport!!!!!!
	;disables depth test
	;disables blending
	;sets the primitive to GL_TRIANGLES
	;void postProcessing_drawToScreen(Framebuffer* framebuffer)
	global postProcessing_drawToScreen

	;src needs to have a colourAttachment0, a colourAttachment1 and a colourAttachment2
	;DOESN'T CALL glViewport!!!!!!
	;disables depth test
	;disables blending
	;sets the primitive to GL_TRIANGLES
	;void postProcessing_ssao(Framebuffer* dest, Framebuffer* src, mat4* view, mat4* projection)
	global postProcessing_ssao
	
	;draws the shaded scene into the dest buffers colourAttachment0
	;DOESN'T CALL glViewport
	;disables depth test
	;disables blending
	;;sets the primitive to GL_TRIANGLES
	;void postProcessing_deferredLighting(Framebuffer* dest, Framebuffer* gBuffer, Framebuffer* ssaoBuffer, vec3* sunDirection, mat4* view)
	global postProcessing_deferredLighting
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_setExtraTexture2D
	extern renderable_enableDepthTest
	extern renderable_enableBlending
	extern renderable_setPrimitive
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	extern renderable_setUniform
	extern renderable_calculateNormalMatrix
	extern RENDERABLE_UNIFORM_VEC2
	extern RENDERABLE_UNIFORM_VEC3
	extern RENDERABLE_UNIFORM_VEC3_ARRAY
	extern RENDERABLE_UNIFORM_MAT4
	
	extern glGenTextures
	extern glDeleteTextures
	extern glBindTexture
	extern glTexImage2D
	extern glTexParameteri
	extern GL_TEXTURE_2D
	extern GL_TEXTURE_MIN_FILTER
	extern GL_TEXTURE_MAG_FILTER
	extern GL_TEXTURE_WRAP_S
	extern GL_TEXTURE_WRAP_T
	extern GL_NEAREST
	extern GL_REPEAT
	extern GL_RGB16F
	extern GL_RGB
	extern GL_FLOAT
	
	extern glBindFramebuffer
	extern GL_FRAMEBUFFER
	
	extern GL_TRIANGLES
	
	extern vec3_print
	extern vec3_mulWithMat
	extern vec4_scale
	extern mat4_inverse
	extern math_lerp
	
	
postProcessing_init:
	push ebp
	mov ebp, esp
	
	;create renderable
	push 0
	push 2			;uv vec2
	push 3			;pos vec3
	push 2
	push index_vector
	push vertex_vector
	call renderable_createCustom
	mov dword[renderable], eax
	
	;create draw to screen shader
	push 0
	push fragment_shader_draw_to_screen
	push vertex_shader_draw_to_screen
	call renderable_createShader
	mov dword[shader_draw_to_screen], eax
	add esp, 12
	
	;init deferred part
	push dword[ebp+12]
	push dword[ebp+8]
	call postProcessing_initDeferredPart
	add esp, 8
	
	;set initialized flag
	mov dword[initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	

postProcessing_deinit:
	push ebp
	mov ebp, esp
	
	;yeet deferred part
	call postProcessing_deinitDeferredPart
	
	;yeet draw to screen shader
	push dword[shader_draw_to_screen]
	call renderable_destroyShader
	mov dword[shader_draw_to_screen], 0
	add esp, 4
	
	;destroy renderable
	push dword[renderable]
	call renderable_destroy
	
	;set initialized flag to 0
	mov dword[initialized], 0
	
	mov esp, ebp
	pop ebp
	ret
	

postProcessing_drawToScreen:
	push ebp
	mov ebp, esp
	
	;disable depth test
	push 0
	call renderable_enableDepthTest
	add esp, 4
	
	;disable blending
	push 0
	call renderable_enableBlending
	add esp, 4
	
	;set the primitive
	push dword[GL_TRIANGLES]
	call renderable_setPrimitive
	add esp, 4
	
	;set the texture of the renderable
	mov ecx, dword[ebp+8]
	push dword[ecx+4]
	push 0
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	;bind the screen framebuffer
	push 0
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;render the renderable
	push 69
	push dword[shader_draw_to_screen]
	push mat4_identity
	push dword[renderable]
	call renderable_renderCustom
	add esp, 16
	
	mov esp, ebp
	pop ebp
	ret
	
	
postProcessing_ssao:
	push ebp
	mov ebp, esp
	
	sub esp, 64				;projection mat inverse		64
	
	;calculate the inverse of the projection matrix
	push dword[ebp+20]
	lea eax, [ebp-64]
	push eax
	call mat4_inverse
	add esp, 8
	
	;disable depth test
	push 0
	call renderable_enableDepthTest
	add esp, 4
	
	;disable blending
	push 0
	call renderable_enableBlending
	add esp, 4
	
	;set the primitive
	push dword[GL_TRIANGLES]
	call renderable_setPrimitive
	add esp, 4
	
	;set the textures of the renderable
	mov ecx, dword[ebp+12]
	push dword[ecx+4]					;position
	push 0
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	mov ecx, dword[ebp+12]
	push dword[ecx+8]					;normals
	push 1
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	push dword[texture_ssaoNoise]		;noise texture
	push 2
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	;send over the view and projection and inverse projection matrices
	push dword[shader_ssao]
	call renderable_useShader
	add esp, 4
	
	push dword[ebp+16]
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_viewMatrix
	push dword[shader_ssao]
	call renderable_setUniform
	add esp, 16
	
	push dword[ebp+20]
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_projectionMatrix
	push dword[shader_ssao]
	call renderable_setUniform
	add esp, 16
	
	lea eax, [ebp-64]
	push eax
	push dword[RENDERABLE_UNIFORM_MAT4]	
	push uniform_name_projectionInverseMatrix
	push dword[shader_ssao]
	call renderable_setUniform
	add esp, 16
	
	
	;bind the destination framebuffer
	mov eax, dword[ebp+8]
	push dword[eax]
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;render the renderable
	push 69
	push dword[shader_ssao]
	push mat4_identity
	push dword[renderable]
	call renderable_renderCustom
	add esp, 16
	
	mov esp, ebp
	pop ebp
	ret
	
postProcessing_deferredLighting:
	push ebp
	mov ebp, esp
	
	sub esp, 36		;normal matrix		36
	sub esp, 12		;viewspace sun dir	48
	
	;calculate the view space sun direction
	push dword[ebp+24]
	lea eax, [ebp-36]
	push eax
	call renderable_calculateNormalMatrix
	add esp, 8
	
	mov eax, dword[ebp+20]
	mov ecx, dword[eax]
	mov dword[ebp-48], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-44], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-40], ecx
	
	lea eax, [ebp-36]
	push eax
	lea ecx, [ebp-48]
	push ecx
	call vec3_mulWithMat
	add esp, 8
	
	;disable depth test
	push 0
	call renderable_enableDepthTest
	add esp, 4
	
	;disable blending
	push 0
	call renderable_enableBlending
	add esp, 4
	
	;set the primitive
	push dword[GL_TRIANGLES]
	call renderable_setPrimitive
	add esp, 4
	
	;set the textures of the renderable
	mov ecx, dword[ebp+12]
	push dword[ecx+8]					;normal
	push 0
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	mov ecx, dword[ebp+12]
	push dword[ecx+12]					;albedo
	push 1
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	mov ecx, dword[ebp+16]
	push dword[ecx+4]					;ssao
	push 2
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	;send over the sun direction
	push dword[shader_deferred_lighting]
	call renderable_useShader
	add esp, 4
	
	push dword[ebp-40]
	push dword[ebp-44]
	push dword[ebp-48]
	push dword[RENDERABLE_UNIFORM_VEC3]
	push uniform_name_sunDirection
	push dword[shader_deferred_lighting]
	call renderable_setUniform
	add esp, 24
	
	;bind the destination framebuffer
	mov eax, dword[ebp+8]
	push dword[eax]
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;render the renderable
	push 69
	push dword[shader_deferred_lighting]
	push mat4_identity
	push dword[renderable]
	call renderable_renderCustom
	add esp, 16
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
;internal functions ------------------------------------------

;initializes the ssao kernel and the random rotation texture
;handles the shaders as well
;void postProcessing_initDeferredPart(int fboWidth, int fboHeight)
postProcessing_initDeferredPart:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 384			;32*sizeof(vec3)		384
	
	;create ssao shader
	push 0
	push fragment_shader_ssao
	push vertex_shader_ssao
	call renderable_createShader
	mov dword[shader_ssao], eax
	add esp, 12
	
	;create deferred lighting shader
	push 0
	push fragment_shader_deferred_lighting
	push vertex_shader_deferred_lighting
	call renderable_createShader
	mov dword[shader_deferred_lighting], eax
	add esp, 12
	
	
	;use shader
	push dword[shader_ssao]
	call renderable_useShader
	add esp, 4
	
	;set screen size
	sub esp, 8
	fild dword[ebp+20]
	fstp dword[esp]
	fild dword[ebp+24]
	fstp dword[esp+4]
	push dword[RENDERABLE_UNIFORM_VEC2]
	push uniform_name_ssaoFramebufferSize
	push dword[shader_ssao]
	call renderable_setUniform
	add esp, 20
	
	;generate the random kernel
	lea eax, [ebp-384]
	push eax
	push 32
	call postProcessing_generateSamplesSSAO
	add esp, 8
	
	;send the samples to the gpu
	lea eax, [ebp-384]
	push eax
	push 32
	push dword[RENDERABLE_UNIFORM_VEC3_ARRAY]
	push uniform_name_ssaoKernel
	push dword[shader_ssao]
	call renderable_setUniform
	add esp, 20
	
	
	;generate noise texture
	call postProcessing_generateSSAONoiseTexture
	
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
;opposite of postProcessing_initDeferredPart
;void postProcessing_deinitDeferredPart()
postProcessing_deinitDeferredPart:
	push ebp
	mov ebp, esp
	
	;yeet noise texture
	push texture_ssaoNoise
	push 1
	call [glDeleteTextures]
	mov dword[texture_ssaoNoise], 0
	
	;destroy ssao shader
	push dword[shader_ssao]
	call renderable_destroyShader
	add esp, 4
	mov dword[shader_ssao], 0
	
	;yeet defererd lighting shader
	push dword[shader_deferred_lighting]
	call renderable_destroyShader
	mov dword[shader_deferred_lighting], 0
	add esp, 4
	
	
	mov esp, ebp
	pop ebp
	ret


;void postProcessing_generateSamplesSSAO(int sampleCount, vec3 buffer[sampleCount])
postProcessing_generateSamplesSSAO:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16					;vec3 buffer + padding		16
	
	mov dword[ebp-4], 0
	
	;check if the sample count is kosher
	cmp dword[ebp+20], 0
	jle postProcessing_generateSamplesSSAO_end
	
	;generate samples
	mov esi, dword[ebp+20]			;index in esi
	mov edi, dword[ebp+24]			;current sample in edi
	mov ebx, 42069					;random state in ebx
	postProcessing_generateSamplesSSAO_loop_start:
		;generate 3 random numbers
		mov dword[ebp-4], 0			;for padding
		imul ebx, 1103515245 
		add ebx, 12345
		mov eax, ebx
		and eax, 0xffff
		mov dword[ebp-8], eax
		imul ebx, 1103515245 
		add ebx, 12345
		mov eax, ebx
		and eax, 0xffff
		mov dword[ebp-12], eax
		imul ebx, 1103515245 
		add ebx, 12345
		mov eax, ebx
		and eax, 0xffff
		mov dword[ebp-16], eax
		
		;convert them to random floats in [0; 1]
		fld dword[FLOAT_SCALER]
		fild dword[ebp-8]
		fmul st0, st1
		fstp dword[ebp-8]
		fild dword[ebp-12]
		fmul st0, st1
		fstp dword[ebp-12]
		fild dword[ebp-16]
		fmul st0, st1
		fstp dword[ebp-16]
		fstp st0
		
		;scale them (x and y component to [-1;1], z component to [0;1])
		movss xmm1, dword[TWO]
		movss xmm3, dword[ONE]
		shufps xmm1, xmm3, 0
		movss xmm2, dword[ONE]
		movss xmm3, dword[ZERO]
		shufps xmm2, xmm3, 0
		movups xmm0, [ebp-16]
		vfmsub213ps xmm0, xmm1, xmm2
		movups [ebp-16], xmm0
		
		;make them closer to the middle
		fld dword[SIXTY_FOUR]
		push esi
		fild dword[esp]
		fdivp
		fmul st0, st0
		fstp dword[esp]
		push dword[ONE]
		push dword[P1]
		call math_lerp
		add esp, 8
		fstp dword[esp]
		lea eax, [ebp-16]
		push eax
		push eax
		call vec4_scale
		add esp, 12
		
		;copy results in the buffer
		mov eax, dword[ebp-16]
		mov dword[edi], eax
		mov ecx, dword[ebp-12]
		mov dword[edi+4], ecx
		mov edx, dword[ebp-8]
		mov dword[edi+8], edx
		
		
		add edi, 12
		dec esi
		test esi, esi
		jnz postProcessing_generateSamplesSSAO_loop_start
	
	postProcessing_generateSamplesSSAO_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	

;generates a 4x4 texture and fills it with random rotation vectors
;void postProcessing_generateSSAONoiseTexture()
postProcessing_generateSSAONoiseTexture:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 192	;16*sizeof(vec3)		192
	
	
	;generate random vec3s
	mov esi, 16						;index in esi
	lea edi, [ebp-192]				;current sample in edi
	mov ebx, -42069					;random state in ebx
	postProcessing_generateSSAONoiseTexture_loop_start:
		;generate 2 random numbers
		mov dword[edi+8], 0				;z is always 0
		imul ebx, 1103515245 
		add ebx, 12345
		mov eax, ebx
		and eax, 0xffff
		mov dword[edi+4], eax
		imul ebx, 1103515245 
		add ebx, 12345
		mov eax, ebx
		and eax, 0xffff
		mov dword[edi], eax

		
		;convert them to random floats in [0; 1]
		fld dword[FLOAT_SCALER]
		fild dword[edi]
		fmul st0, st1
		fstp dword[edi]
		fild dword[edi+4]
		fmul st0, st1
		fstp dword[edi+4]
		fstp st0
		
		;scale them to [-1;1]
		movss xmm1, dword[TWO]
		movss xmm2, dword[ONE]
		
		movss xmm0, dword[edi]
		vfmsub213ss xmm0, xmm1, xmm2
		movss dword[edi], xmm0
		
		movss xmm0, dword[edi+4]
		vfmsub213ss xmm0, xmm1, xmm2
		movss dword[edi+4], xmm0
		
		add edi, 12
		dec esi
		test esi, esi
		jnz postProcessing_generateSSAONoiseTexture_loop_start
	
	
	;create texture
	push texture_ssaoNoise
	push 1
	call [glGenTextures]
	
	push dword[texture_ssaoNoise]
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	push dword[GL_NEAREST]
	push dword[GL_TEXTURE_MIN_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_NEAREST]
	push dword[GL_TEXTURE_MAG_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_REPEAT]
	push dword[GL_TEXTURE_WRAP_S]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_REPEAT]
	push dword[GL_TEXTURE_WRAP_T]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	
	
	lea eax, [ebp-192]
	push eax
	push dword[GL_FLOAT]
	push dword[GL_RGB]
	push 0
	push 4
	push 4
	push dword[GL_RGB16F]
	push 0
	push dword[GL_TEXTURE_2D]
	call [glTexImage2D]
	
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret