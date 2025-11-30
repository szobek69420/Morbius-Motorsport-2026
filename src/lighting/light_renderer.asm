[BITS 32]

section .rodata use32
	MAX_LIGHT_COUNT dd 100
	POINT_LIGHT_SIZE dd 32		;the size of the data of one point light in the instance vbo
	GLOBAL_LIGHT_SIZE dd 32		;the size of the data of one global light in the instance vbo

section .data use32
	initialized dd 0

	global_volume_renderable dd 0
	point_volume_renderable dd 0
	
	global_instance_vbo dd 0
	point_instance_vbo dd 0

section .text use32

	global lightRenderer_init				;void lightRenderer_init()
	global lightRenderer_deinit				;void lightRenderer_deinit()

	;copies the depth buffer of gBuffer into target
	;clears the target colour buffer
	;void lightRenderer_prepareTargetFBO(Framebuffer* hdrTarget, Framebuffer* gBuffer)
	global lightRenderer_prepareTargetFBO
	
	;overwrites the currently bound framebuffer
	;overwrites the blendfunc
	;overwrites the blendequation
	;void lightRenderer_renderPointLights(vector<PointLight*> lights, Framebuffer* hdrTarget, FrameBuffer* gBuffer)
	global lightRenderer_renderPointLights
	
	extern my_printf
	
	extern lightVolume_createGlobal
	extern lightVolume_createPoint
	extern renderable_destroy
	extern renderable_getVAO
	
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
	extern GL_ARRAY_BUFFER
	extern GL_DYNAMIC_DRAW
	
	
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