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
	
	ZERO dd 0.0
	ONE dd 1.0
	TWO dd 2.0
	FLOAT_SCALER dd 65536.0

section .data use32
	initialized dd 0
	renderable dd 0
	
	shader_draw_to_screen dd 0
	shader_ssao dd 0
	

section .text use32

	global postProcessing_init		;void postProcessing_init()
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
	;void postProcessing_ssao(Framebuffer* dest, Framebuffer* src)
	global postProcessing_ssao
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_setExtraTexture2D
	extern renderable_enableDepthTest
	extern renderable_enableBlending
	extern renderable_setPrimitive
	extern renderable_createShader
	extern renderable_destroyShader
	
	extern glBindFramebuffer
	extern GL_FRAMEBUFFER
	
	extern GL_TRIANGLES
	
	
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
	
	;create ssao shader
	push 0
	push fragment_shader_ssao
	push vertex_shader_ssao
	call renderable_createShader
	mov dword[shader_ssao], eax
	add esp, 12
	
	;set initialized flag
	mov dword[initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	

postProcessing_deinit:
	push ebp
	mov ebp, esp
	
	;yeet ssao
	push dword[shader_ssao]
	call renderable_destroyShader
	mov dword[shader_ssao], 0
	add esp, 4
	
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
	push dword[ecx+4]
	push 0
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	mov ecx, dword[ebp+12]
	push dword[ecx+8]
	push 1
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	mov ecx, dword[ebp+12]
	push dword[ecx+12]
	push 2
	push dword[renderable]
	call renderable_setExtraTexture2D
	add esp, 12
	
	
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
	
	
;internal functions ------------------------------------------


;void framebuffer_generateSamplesSSAO(int sampleCount, vec3 buffer[sampleCount])
framebuffer_generateSamplesSSAO:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16					;vec3 buffer + padding		16
	
	mov dword[ebp-4], 0
	
	;check if the sample count is kosher
	cmp dword[ebp+20], 0
	jle framebuffer_generateSamplesSSAO_end
	
	;generate samples
	mov esi, dword[ebp+20]			;index in esi
	mov edi, dword[ebp+24]			;current sample in edi
	mov ebx, 42069					;random state in ebx
	framebuffer_generateSamplesSSAO_loop_start:
		;generate 3 random numbers
		push 0					;for padding
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
		jnz framebuffer_generateSamplesSSAO_loop_start
	
	framebuffer_generateSamplesSSAO_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret