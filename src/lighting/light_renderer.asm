[BITS 32]

section .rodata use32


section .text use32

	;copies the depth buffer of gBuffer into target
	;clears the target colour buffer
	;void lightRenderer_prepareTargetFBO(Framebuffer* target, Framebuffer* gBuffer)
	global lightRenderer_prepareTargetFBO
	
	;overwrites the currently bound framebuffer
	;overwrites the blendfunc
	;void lightRenderer_renderPointLights(vector<PointLight*> lights, Framebuffer* target, FrameBuffer* gBuffer)
	global lightRenderer_renderPointLights
	
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
	
	
lightRenderer_renderPointLights:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret