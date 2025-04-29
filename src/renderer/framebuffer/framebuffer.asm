[BITS 32]

;struct FrameBuffer{
;	GLuint fbo;					;0
;	GLuint colourAttachment0;	;4
;	GLuint colourAttachment1;	;8
;	GLuint depthAttachment;		;12	//can also contain stencil attachment
;	int width, height;			;16
;};	24 bytes overall

section .rodata use32
	global FRAMEBUFFER_RGB
	global FRAMEBUFFER_RGBA

	;colour attachment types
	FRAMEBUFFER_RGB dd GL_RGB
	FRAMEBUFFER_RGBA dd GL_RGBA
	
	print_int_nl db "%d",10,0
	print_status db "framebuffer is complete: %d",10,0
	
	test_text db "drip chungus",10,0
	

section .text use32

	global framebuffer_create		;FrameBuffer* framebuffer_create(int width, int height)
	global framebuffer_destroy		;void framebuffer_destroy(FrameBuffer* framebuffer)
	
	global framebuffer_isFramebufferComplete	;int framebuffer_isFramebufferComplete(Framebuffer* framebuffer)
	
	global framebuffer_colourAttachment0	;void framebuffer_colourAttachment0(Framebuffer* framebuffer, int attachmentType)
	global framebuffer_colourAttachment1	;void framebuffer_colourAttachment1(Framebuffer* framebuffer, int attachmentType)
	global framebuffer_depthAttachment		;void framebuffer_depthAttachment(Framebuffer* framebuffer)
	
	global framebuffer_test			;void framebuffer_test()
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern glGenFramebuffers
	extern glDeleteFramebuffers
	extern glBindFramebuffer
	extern glFramebufferTexture2D
	extern glCheckFramebufferStatus
	extern GL_FRAMEBUFFER
	extern GL_COLOR_ATTACHMENT0
	extern GL_COLOR_ATTACHMENT1
	extern GL_DEPTH_STENCIL_ATTACHMENT
	extern GL_FRAMEBUFFER_COMPLETE
	
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
	extern GL_CLAMP_TO_EDGE
	
	extern GL_RGB
	extern GL_RGBA
	extern GL_DEPTH_STENCIL
	extern GL_DEPTH24_STENCIL8
	extern GL_UNSIGNED_BYTE
	extern GL_FLOAT
	extern GL_UNSIGNED_INT_24_8
	
	extern glGetError

framebuffer_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4	;FrameBuffer		;4
	
	;alloc space for framebuffer struct
	push 24
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;gen framebuffer
	push dword[ebp-4]
	push 1
	call [glGenFramebuffers]
	
	;init the other colour attachments
	mov eax, dword[ebp-4]
	mov dword[eax+4], 0
	mov dword[eax+8], 0
	mov dword[eax+12], 0
	
	;set the size
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp+8]
	mov dword[eax+16], ecx
	mov ecx, dword[ebp+12]
	mov dword[eax+20], ecx
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
framebuffer_destroy:
	push ebp
	mov ebp, esp
	
	;delete textures
	mov eax, dword[ebp+8]
	cmp dword[eax+4], 0
	je framebuffer_destroy_no_colour0
		lea ecx, [eax+4]
		push ecx
		push 1
		call [glDeleteTextures]
	framebuffer_destroy_no_colour0:
	
	mov eax, dword[ebp+8]
	cmp dword[eax+8], 0
	je framebuffer_destroy_no_colour1
		lea ecx, [eax+8]
		push ecx
		push 1
		call [glDeleteTextures]
	framebuffer_destroy_no_colour1:
	
	mov eax, dword[ebp+8]
	cmp dword[eax+12], 0
	je framebuffer_destroy_no_depth
		lea ecx, [eax+12]
		push ecx
		push 1
		call [glDeleteTextures]
	framebuffer_destroy_no_depth:
	
	;delete framebuffer
	push dword[ebp+8]
	push 1
	call [glDeleteFramebuffers]
	
	;dealloc space
	push dword[ebp+8]
	call my_free
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
framebuffer_isFramebufferComplete:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;return value		;4
	
	;bind the framebuffer
	mov eax, dword[ebp+8]
	push dword[eax]
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;check status
	push dword[GL_FRAMEBUFFER]
	call [glCheckFramebufferStatus]
	cmp eax, dword[GL_FRAMEBUFFER_COMPLETE]
	jne framebuffer_isFramebufferComplete_not_complete
		mov dword[ebp-4], 69
		jmp framebuffer_isFramebufferComplete_done
	framebuffer_isFramebufferComplete_not_complete:
		mov dword[ebp-4], 0
	framebuffer_isFramebufferComplete_done:
	
	;unbind the framebuffer
	push 0
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
framebuffer_colourAttachment0:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;texture		;4
	
	;delete the previous attachment if necessary
	mov eax, dword[ebp+8]
	cmp dword[eax+4], 0
	je framebuffer_colourAttachment0_no_previous
		lea ecx, [eax+4]
		push ecx
		push 1
		call [glDeleteTextures]
		
	framebuffer_colourAttachment0_no_previous:
	
	;generate texture
	lea eax, [ebp-4]
	push eax
	push 1
	call [glGenTextures]
	
	;bind texture
	push dword[ebp-4]
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	;specify texture format
	push 0
	push dword[GL_UNSIGNED_BYTE]
	mov eax, dword[ebp+12]
	push dword[eax]
	push 0
	mov ecx, dword[ebp+8]
	push dword[ecx+20]
	push dword[ecx+16]
	push dword[eax]
	push 0
	push dword[GL_TEXTURE_2D]
	call [glTexImage2D]
	
	;set texture parameters
	push dword[GL_NEAREST]
	push dword[GL_TEXTURE_MIN_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_NEAREST]
	push dword[GL_TEXTURE_MAG_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_CLAMP_TO_EDGE]
	push dword[GL_TEXTURE_WRAP_S]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_CLAMP_TO_EDGE]
	push dword[GL_TEXTURE_WRAP_T]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	
	;unbind the texture
	push 0
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	;bind the framebuffer
	mov eax, dword[ebp+8]
	push dword[eax]
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;attach the texture to the framebuffer
	push 0
	push dword[ebp-4]
	push dword[GL_TEXTURE_2D]
	push dword[GL_COLOR_ATTACHMENT0]
	push dword[GL_FRAMEBUFFER]
	call [glFramebufferTexture2D]
	
	;unbind the framebuffer
	push 0
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;set the value in the fbo struct
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	mov dword[eax+4], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
framebuffer_colourAttachment1:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;texture		;4
	
	;delete the previous attachment if necessary
	mov eax, dword[ebp+8]
	cmp dword[eax+8], 0
	je framebuffer_colourAttachment1_no_previous
		lea ecx, [eax+8]
		push ecx
		push 1
		call [glDeleteTextures]
		
	framebuffer_colourAttachment1_no_previous:
	
	;generate texture
	lea eax, [ebp-4]
	push eax
	push 1
	call [glGenTextures]
	
	;bind texture
	push dword[ebp-4]
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	;specify texture format
	push 0
	push dword[GL_UNSIGNED_BYTE]
	mov eax, dword[ebp+12]
	push dword[eax]
	push 0
	mov ecx, dword[ebp+8]
	push dword[ecx+20]
	push dword[ecx+16]
	push dword[eax]
	push 0
	push dword[GL_TEXTURE_2D]
	call [glTexImage2D]
	
	;set texture parameters
	push dword[GL_NEAREST]
	push dword[GL_TEXTURE_MIN_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_NEAREST]
	push dword[GL_TEXTURE_MAG_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_CLAMP_TO_EDGE]
	push dword[GL_TEXTURE_WRAP_S]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_CLAMP_TO_EDGE]
	push dword[GL_TEXTURE_WRAP_T]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	
	;unbind the texture
	push 0
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	;bind the framebuffer
	mov eax, dword[ebp+8]
	push dword[eax]
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;attach the texture to the framebuffer
	push 0
	push dword[ebp-4]
	push dword[GL_TEXTURE_2D]
	push dword[GL_COLOR_ATTACHMENT1]
	push dword[GL_FRAMEBUFFER]
	call [glFramebufferTexture2D]
	
	;unbind the framebuffer
	push 0
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;set the value in the fbo struct
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	mov dword[eax+8], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
framebuffer_depthAttachment:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;texture		;4
	
	;delete the previous attachment if necessary
	mov eax, dword[ebp+8]
	cmp dword[eax+12], 0
	je framebuffer_depthAttachment_no_previous
		lea ecx, [eax+12]
		push ecx
		push 1
		call [glDeleteTextures]
		
	framebuffer_depthAttachment_no_previous:
	
	;generate texture
	lea eax, [ebp-4]
	push eax
	push 1
	call [glGenTextures]
	
	;bind texture
	push dword[ebp-4]
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	;specify texture format
	push 0
	push dword[GL_UNSIGNED_INT_24_8]
	push dword[GL_DEPTH_STENCIL]
	push 0
	mov ecx, dword[ebp+8]
	push dword[ecx+20]
	push dword[ecx+16]
	push dword[GL_DEPTH24_STENCIL8]
	push 0
	push dword[GL_TEXTURE_2D]
	call [glTexImage2D]
	
	;set texture parameters
	push dword[GL_NEAREST]
	push dword[GL_TEXTURE_MIN_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_NEAREST]
	push dword[GL_TEXTURE_MAG_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_CLAMP_TO_EDGE]
	push dword[GL_TEXTURE_WRAP_S]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[GL_CLAMP_TO_EDGE]
	push dword[GL_TEXTURE_WRAP_T]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	
	;unbind the texture
	push 0
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	;bind the framebuffer
	mov eax, dword[ebp+8]
	push dword[eax]
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;attach the texture to the framebuffer
	push 0
	push dword[ebp-4]
	push dword[GL_TEXTURE_2D]
	push dword[GL_DEPTH_STENCIL_ATTACHMENT]
	push dword[GL_FRAMEBUFFER]
	call [glFramebufferTexture2D]
	
	;unbind the framebuffer
	push 0
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	;set the value in the fbo struct
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	mov dword[eax+12], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
framebuffer_test:
	push ebp
	mov ebp, esp
	
	sub esp, 4
	
	call [glGetError]
	push eax
	push print_int_nl
	call my_printf
	add esp, 8
	
	;create framebuffer
	push 69
	push 420
	call framebuffer_create
	mov dword[ebp-4], eax
	add esp, 8
	
	call [glGetError]
	push eax
	push print_int_nl
	call my_printf
	add esp, 8
	
	;create attachments
	push dword[FRAMEBUFFER_RGBA]
	push dword[ebp-4]
	call framebuffer_colourAttachment0
	add esp, 8
	
	call [glGetError]
	push eax
	push print_int_nl
	call my_printf
	add esp, 8
	
	push dword[ebp-4]
	call framebuffer_depthAttachment
	add esp, 4
	
	call [glGetError]
	push eax
	push print_int_nl
	call my_printf
	add esp, 8
	
	;check status
	push dword[ebp-4]
	call framebuffer_isFramebufferComplete
	mov dword[esp], eax
	push print_status
	call my_printf
	add esp, 8
	
	;destroy framebuffer
	push dword[ebp-4]
	call framebuffer_destroy
	add esp, 4
	
	call [glGetError]
	push eax
	push print_int_nl
	call my_printf
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret