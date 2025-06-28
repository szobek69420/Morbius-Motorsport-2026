[BITS 32]

;struct FrameBuffer{
;	GLuint fbo;					;0
;	GLuint colourAttachment0;	;4
;	GLuint colourAttachment1;	;8
;	GLuint colourAttachment2;	;12
;	GLuint colourAttachment3;	;16
;	GLuint depthAttachment;		;20	//can also contain stencil attachment
;	int width, height;			;24
;};	32 bytes overall

section .rodata use32
	global FRAMEBUFFER_RGB
	global FRAMEBUFFER_RGBA
	global FRAMEBUFFER_RGB16F
	global FRAMEBUFFER_RGBA16F

	;colour attachment types
	FRAMEBUFFER_RGB:
	dd GL_RGB			;internal format
	dd GL_RGB			;base format
	dd GL_UNSIGNED_BYTE	;pixel data type (not exactly necessary)
	
	FRAMEBUFFER_RGBA:
	dd GL_RGBA			;internal format
	dd GL_RGBA			;base format
	dd GL_UNSIGNED_BYTE	;pixel data type (not exactly necessary)
	
	FRAMEBUFFER_RGB16F:
	dd GL_RGB16F		;internal format
	dd GL_RGB			;base format
	dd GL_FLOAT			;pixel data type (not exactly necessary)
	
	FRAMEBUFFER_RGBA16F:
	dd GL_RGBA16F		;internal format
	dd GL_RGBA			;base format
	dd GL_FLOAT			;pixel data type (not exactly necessary)
	
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_status db "framebuffer is complete: %d",10,0
	
	test_text db "drip chungus",10,0

	error_invalid_attachment_number db "framebuffer_colourAttachment: The colour attachment (currently %d) number should be between 0 and 3",10,0

section .text use32

	global framebuffer_create		;FrameBuffer* framebuffer_create(int width, int height)
	global framebuffer_destroy		;void framebuffer_destroy(FrameBuffer* framebuffer)
	
	global framebuffer_isComplete	;int framebuffer_isComplete(Framebuffer* framebuffer)
	
	global framebuffer_colourAttachment		;void framebuffer_colourAttachment(Framebuffer* framebuffer, int attachmentType, int attachmentNumber) //attachment type can be for example FRAMEBUFFER_RGB
	global framebuffer_depthAttachment		;void framebuffer_depthAttachment(Framebuffer* framebuffer)
	
	;if framebuffer is 0, the default framebuffer is bound
	;void framebuffer_bind(Framebuffer* framebuffer)
	global framebuffer_bind
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern glGenFramebuffers
	extern glDeleteFramebuffers
	extern glBindFramebuffer
	extern glFramebufferTexture2D
	extern glCheckFramebufferStatus
	extern glDrawBuffers
	extern GL_FRAMEBUFFER
	extern GL_COLOR_ATTACHMENT0
	extern GL_COLOR_ATTACHMENT1
	extern GL_DEPTH_STENCIL_ATTACHMENT
	extern GL_FRAMEBUFFER_COMPLETE
	
	extern glGenTextures
	extern glDeleteTextures
	extern glBindTexture
	extern glActiveTexture
	extern glTexImage2D
	extern glTexParameteri
	extern GL_TEXTURE_2D
	extern GL_TEXTURE_MIN_FILTER
	extern GL_TEXTURE_MAG_FILTER
	extern GL_TEXTURE_WRAP_S
	extern GL_TEXTURE_WRAP_T
	extern GL_NEAREST
	extern GL_CLAMP_TO_EDGE
	extern GL_TEXTURE0
	
	extern GL_RGB
	extern GL_RGB16F
	extern GL_RGBA
	extern GL_RGBA16F
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
	push 32
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;gen framebuffer
	push dword[ebp-4]
	push 1
	call [glGenFramebuffers]
	
	;init the other attachments
	mov eax, dword[ebp-4]
	mov dword[eax+4], -1
	mov dword[eax+8], -1
	mov dword[eax+12], -1
	mov dword[eax+16], -1
	mov dword[eax+20], -1
	
	;set the size
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp+8]
	mov dword[eax+24], ecx
	mov ecx, dword[ebp+12]
	mov dword[eax+28], ecx
	
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
	lea eax, [eax+4]
	push eax
	push 5
	call [glDeleteTextures]
	
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
	
	
	
framebuffer_isComplete:
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
	
	
framebuffer_colourAttachment:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;texture				4
	sub esp, 4		;attachment address		8
	
	;is the attachment number kosher?
	mov eax, dword[ebp+16]
	test eax, 0x80000000
	jnz framebuffer_colourAttachment_number_error
	cmp eax, 4
	jge framebuffer_colourAttachment_number_error
	jmp framebuffer_colourAttachment_number_gg
	framebuffer_colourAttachment_number_error:
		push eax
		push error_invalid_attachment_number
		call my_printf
		add esp, 8
		jmp framebuffer_colourAttachment_end
		
	framebuffer_colourAttachment_number_gg:
	
	;calculate the attachment address
	mov eax, dword[ebp+16]
	mov ecx, dword[ebp+8]
	lea ecx, [ecx+4+4*eax]
	mov dword[ebp-8], ecx
	
	;delete the previous attachment if necessary
	mov eax, dword[ebp-8]
	cmp dword[eax], -1
	je framebuffer_colourAttachment_no_previous
		push eax
		push 1
		call [glDeleteTextures]
		
	framebuffer_colourAttachment_no_previous:
	
	;generate texture
	lea eax, [ebp-4]
	push eax
	push 1
	call [glGenTextures]
	
	;bind texture
	push dword[GL_TEXTURE0]
	call [glActiveTexture]
	
	push dword[ebp-4]
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	;specify texture format
	mov eax, dword[ebp+12]
	
	push 0
	mov ecx, dword[eax+8]
	push dword[ecx]				;pixel data type (unnecessary tbf)
	mov ecx, dword[eax+4]
	push dword[ecx]				;pixel format (also unnecessary)
	push 0
	mov ecx, dword[ebp+8]
	push dword[ecx+28]			;height
	push dword[ecx+24]			;width
	mov ecx, dword[eax]
	push dword[ecx]				;internal format
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
	mov eax, dword[GL_COLOR_ATTACHMENT0]
	add eax, dword[ebp+16]
	push eax
	push dword[GL_FRAMEBUFFER]
	call [glFramebufferTexture2D]
	
	;set the value in the fbo struct
	mov eax, dword[ebp-8]
	mov ecx, dword[ebp-4]
	mov dword[eax], ecx
	
	;update draw buffers
	push dword[ebp+8]
	call framebuffer_updateActiveBuffersInternal
	add esp, 4
	
	;unbind the framebuffer
	push 0
	push dword[GL_FRAMEBUFFER]
	call [glBindFramebuffer]
	
	
	framebuffer_colourAttachment_end:
	mov esp, ebp
	pop ebp
	ret
	
	
framebuffer_depthAttachment:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;texture		;4
	
	;delete the previous attachment if necessary
	mov eax, dword[ebp+8]
	cmp dword[eax+20], -1
	je framebuffer_depthAttachment_no_previous
		lea ecx, [eax+20]
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
	push dword[ecx+28]
	push dword[ecx+24]
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
	mov dword[eax+20], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
framebuffer_bind:
	push ebp
	mov ebp, esp
	
	cmp dword[ebp+8], 0
	je framebuffer_bind_default
		mov eax, dword[ebp+8]
		push dword[eax]
		push dword[GL_FRAMEBUFFER]
		call [glBindFramebuffer]
		jmp framebuffer_bind_done
	
	framebuffer_bind_default:
		push 0
		push dword[GL_FRAMEBUFFER]
		call [glBindFramebuffer]
	framebuffer_bind_done:
	
	mov esp, ebp
	pop ebp
	ret
	
	
;calls glDrawBuffer according to the active colour attachments
;doesn't bind framebuffer
;void framebuffer_updateActiveBuffersInternal(Framebuffer* currentlyActiveFramebuffer)
framebuffer_updateActiveBuffersInternal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4				;active colour attachment count								4
	sub esp, 36				;active colour attachment buffer (36 bytes is arbitrary)	40
	
	mov dword[ebp-4], 0

	mov eax, dword[ebp+20]
	lea esi, [eax+4]						;current attachment in esi
	mov edi, dword[GL_COLOR_ATTACHMENT0]	;current value in edi
	xor ebx, ebx							;index in ebx
	framebuffer_updateActiveBuffersInternal_loop_start:
		cmp dword[esi], -1
		je framebuffer_updateActiveBuffersInternal_loop_continue	;no texture in the attachment slot
			;set the value in the buffer
			mov eax, dword[ebp-4]
			mov dword[ebp-40+4*eax], edi
			
			;increment counter
			inc dword[ebp-4]
	
		framebuffer_updateActiveBuffersInternal_loop_continue:
		add esi, 4
		inc edi
		inc ebx
		cmp ebx, 4
		jl framebuffer_updateActiveBuffersInternal_loop_start
		
	;call glDrawBuffer
	lea eax, [ebp-40]
	push eax
	push dword[ebp-4]
	call [glDrawBuffers]
	
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret