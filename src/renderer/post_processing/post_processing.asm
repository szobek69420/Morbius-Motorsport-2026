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

section .data use32
	initialized dd 0
	renderable dd 0
	

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
	
	extern renderable_create
	extern renderable_destroy
	extern renderable_render
	extern renderable_enableDepthTest
	extern renderable_enableBlending
	extern renderable_setPrimitive
	extern RENDERABLE_ATTRIB_P3UV2
	
	extern glBindFramebuffer
	extern GL_FRAMEBUFFER
	
	extern GL_TRIANGLES
	
	
postProcessing_init:
	push ebp
	mov ebp, esp
	
	;create renderable
	push dword[RENDERABLE_ATTRIB_P3UV2]
	push index_vector
	push vertex_vector
	call renderable_create
	mov dword[renderable], eax
	
	;set initialized flag
	mov dword[initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	

postProcessing_deinit:
	push ebp
	mov ebp, esp
	
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
	mov eax, dword[renderable]
	mov ecx, dword[ebp+8]
	mov ecx, dword[ecx+4]
	mov dword[eax+56], ecx
	
	;bind the screen framebuffer
	push 0
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;render the renderable
	push mat4_identity
	push dword[renderable]
	call renderable_render
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret