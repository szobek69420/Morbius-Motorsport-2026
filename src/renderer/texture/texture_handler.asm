[BITS 32]

;layout
;struct TextureInfo{
;	GLuint texture;		;0
;	char* path;			;4
;	GLint wrap;			;8
;	GLint filter;		;12
;	int flipped;		;16
;	int importCount;	;20
;}		24 bytes overall

;layout
;struct TextureArrayInfo{
;	GLuint textureArray;	;0
;	int width, height;		;4
;	GLint wrap;				;12
;	GLint filter;			;16
;	int numLayers;			;20
;	int mipmapGenerated		;24
;}		28 bytes overall

section .rodata use32
	error_init db "textureHandler_init: fuck",10,0
	error_not_initialized db "texture handler is not initialized bozo",10,0
	error_unsupported_file_format db "textureHandler_load: unsupported file format",10,0
	error_invalid_color_depth db "textureHandler_load: only RGB and RGBA formats are supported",10,0
	
	error_texture_not_registered db "textureHandler_unload: function only handles textures that has been loaded with textureHandler_load",10,0
	error_texture_array_image_wrong_size db "textureHandler_addImageToArray: the image size of %s does not correspond with the size of the bound framebuffer", 10, 0
	error_texture_array_image_wrong_format db "textureHandler_addImageToArray: the image format of %s is invalid",10,0
	
	file_extension_bmp db ".bmp",0
	
	print_int_nl db "%d",10,0

section .data use32
	is_initialized dd 0
	import_buffer dd 0					;unsigned char*
	
section .bss use32
	imported_textures resb 16			;vector<TextureInfo>
	
section .text use32

	global textureHandler_init						;void textureHandler_init()
	global textureHandler_deinit					;void textureHandler_deinit()
	
	;supports textures up to 10MB
	global textureHandler_load						;GLuint textureHandler_load(const char* imagePath, GLint wrap, GLint filter, int flipped)
	global textureHandler_unload					;void textureHandler_unload(GLuint texture)
	
	global textureHandler_loadArray					;TextureArrayInfo* textureHandler_loadArray(int width, int height, int numLayers, GLint wrap, GLint filter)
	global textureHandler_unloadArray				;void textureHandler_unloadArray(TextureArrayInfo* ta)
	
	;returns zero on no error (non-zero is only returned on incompatible image type, opengl errors are ignored)
	;int textureHandler_addImageToArray(TextureArrayInfo* texture, const char* imagePath, int layer)
	global textureHandler_addImageToArray
	;NOTE: this function should only be called once every image has been added to the array
	;void textureHandler_generateArrayMipmap(TextureArrayInfo* tai)
	global textureHandler_generateArrayMipmap
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove_at
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcmp
	extern my_strcmp
	extern my_strlen
	extern my_strcpy
	
	extern image_loadBMP
	extern image_flip
	
	extern glActiveTexture
	extern glGenTextures
	extern glDeleteTextures
	extern glBindTexture
	extern glTexImage2D
	extern glGenerateMipmap
	extern glTexParameteri
	extern glPixelStorei
	extern glTexStorage3D
	extern glTexSubImage3D
	extern glGetError
	
	extern GL_TEXTURE0
	extern GL_TEXTURE_2D
	extern GL_TEXTURE_2D_ARRAY
	extern GL_REPEAT
	extern GL_NEAREST
	extern GL_TEXTURE_WRAP_S
	extern GL_TEXTURE_WRAP_T
	extern GL_TEXTURE_MIN_FILTER
	extern GL_TEXTURE_MAG_FILTER
	extern GL_RGBA
	extern GL_RGB
	extern GL_RGBA8
	extern GL_UNSIGNED_BYTE
	extern GL_UNPACK_ALIGNMENT

textureHandler_init:
	push ebp
	mov ebp, esp
	
	;init imported_textures
	push 24
	push imported_textures
	call vector_init
	
	;create buffer for texture import (10MB)
	push 10485760
	call my_malloc
	mov dword[import_buffer], eax
	test eax, eax
	jnz textureHandler_init_buffer_alloc_gg
		push error_init
		call my_printf
		jmp textureHandler_init_end
	textureHandler_init_buffer_alloc_gg:
	
	;mark as initialized
	mov dword[is_initialized], 69
	
	textureHandler_init_end:
	mov esp, ebp
	pop ebp
	ret
	
	
textureHandler_deinit:
	push ebp
	mov ebp, esp
	
	;mark as uninitialized
	mov dword[is_initialized], 0
	
	;empty imported_textures
	cmp dword[imported_textures], 0	
	jle textureHandler_deinit_unload_loop_end			;already empty
	textureHandler_deinit_unload_loop_start:
		mov eax, imported_textures
		mov eax, dword[eax+12]
		push dword[eax]				;gl texture in the first texture info
		call textureHandler_unload
		add esp, 4
		
		cmp dword[imported_textures], 0
		jg textureHandler_deinit_unload_loop_start
	
	textureHandler_deinit_unload_loop_end:
	
	;yeet imported_textures vector
	push imported_textures
	call vector_destroy
	
	;yeet import_buffer
	push dword[import_buffer]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
textureHandler_load:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4				;width
	sub esp, 4				;height
	sub esp, 4				;bits per pixel
	
	sub esp, 4				;gl texture
	
	;check if texture handler is initialized
	cmp dword[is_initialized], 0
	jne textureHandler_load_initialized
		push error_not_initialized
		call my_printf
		xor eax, eax
		jmp textureHandler_load_end
	textureHandler_load_initialized:
	
	;check if the image was already imported
	mov esi, dword[imported_textures]		;number of imported textures in esi
	mov edi, imported_textures
	mov edi, dword[edi+12]					;array of imported textures in edi
	test esi, esi
	jz textureHandler_load_imported_loop_end
	textureHandler_load_imported_loop_start:
		;check if the imagePath is the same
		push dword[edi+4]
		push dword[ebp+16]
		call my_strcmp
		add esp, 8
		
		test eax, eax
		jnz textureHandler_load_imported_loop_continue
		
		;check if the wrap is the same
		mov eax, dword[edi+8]
		cmp eax, dword[ebp+20]
		jne textureHandler_load_imported_loop_continue
		
		;check if the filter is the same
		mov eax, dword[edi+12]
		cmp eax, dword[ebp+24]
		jne textureHandler_load_imported_loop_continue
		
		;check if the flip is the same
		mov eax, dword[edi+16]
		cmp eax, dword[ebp+28]
		jne textureHandler_load_imported_loop_continue
		
		
		;texture found, gg bois
		inc dword[edi+20]			;increment import count
		mov eax, dword[edi]
		jmp textureHandler_load_end
		
		
		textureHandler_load_imported_loop_continue:
		add edi, 24
		dec esi
		test esi, esi
		jnz textureHandler_load_imported_loop_start
	textureHandler_load_imported_loop_end:
	
	
	;check if the file format is supported and import if da
	push dword[ebp+16]
	call my_strlen
	add esp, 4
	cmp eax, 4
	jl textureHandler_load_not_bmp
	mov ecx, dword[ebp+16]
	add ecx, eax
	sub ecx, 4
	push ecx
	push file_extension_bmp
	call my_strcmp
	add esp, 8
	test eax, eax
	jnz textureHandler_load_not_bmp
		;flip texture
		push dword[ebp+28]
		call image_flip
		add esp, 4
		
		;load data
		lea eax, [ebp-12]
		push eax					;&bytesPerPixel
		lea eax, [ebp-8]
		push eax					;&height
		lea eax, [ebp-4]
		push eax					;&width
		push dword[import_buffer]
		push dword[ebp+16]
		call image_loadBMP
		add esp, 20
		jmp textureHandler_load_import_successful
		
	textureHandler_load_not_bmp:
	textureHandler_load_unsupported_format:
		push error_unsupported_file_format
		call my_printf
		xor eax, eax
		jmp textureHandler_load_end
	textureHandler_load_import_successful:
	
	;create opengl texture
	push 1
	push dword[GL_UNPACK_ALIGNMENT]
	call [glPixelStorei]
	
	lea eax, [ebp-16]
	push eax
	push 1
	call [glGenTextures]
	
	push dword[ebp-16]
	push dword[GL_TEXTURE_2D]
	call [glBindTexture]
	
	push dword[ebp+20]
	push dword[GL_TEXTURE_WRAP_S]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[ebp+20]
	push dword[GL_TEXTURE_WRAP_T]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[ebp+24]
	push dword[GL_TEXTURE_MIN_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	push dword[ebp+24]
	push dword[GL_TEXTURE_MAG_FILTER]
	push dword[GL_TEXTURE_2D]
	call [glTexParameteri]
	
	mov eax, dword[ebp-12]			;bits per pixel
	cmp eax, 24
	je textureHandler_load_rgb
	cmp eax, 32
	je textureHandler_load_rgba
		push error_invalid_color_depth
		call my_printf
		xor eax, eax
		jmp textureHandler_load_end
	textureHandler_load_rgb:
		mov eax, dword[GL_RGB]
		jmp textureHandler_load_format_selected
	textureHandler_load_rgba:
		mov eax, dword[GL_RGBA]
		jmp textureHandler_load_format_selected
	textureHandler_load_format_selected:
	push dword[import_buffer]
	push dword[GL_UNSIGNED_BYTE]
	push eax
	push 0
	push dword[ebp-8]			;height
	push dword[ebp-4]			;width
	push eax
	push 0
	push dword[GL_TEXTURE_2D]
	call [glTexImage2D]
	
	push dword[GL_TEXTURE_2D]
	call [glGenerateMipmap]
	
	
	;add the new texture to the imported textures
	push dword[ebp+16]
	call my_strlen
	inc eax
	mov dword[esp], eax
	call my_malloc
	add esp, 4
	
	push dword[ebp+16]
	push eax
	call my_strcpy
	
	pop eax			;restore the imagePath
	
	push 1					;import count
	push dword[ebp+28]		;flipped
	push dword[ebp+24]		;filter
	push dword[ebp+20]		;wrap
	push eax				;imagePath
	push dword[ebp-16]		;gl texture
	push imported_textures
	call vector_push_back
	
	
	
	mov eax, dword[ebp-16]
	
	textureHandler_load_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
textureHandler_unload:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4				;index in imported_textures
	mov dword[ebp-4], -1
	
	;search for the imported texture
	xor esi, esi							;index in esi
	mov edi, imported_textures
	mov edi, dword[edi+12]					;textureinfo array in edi
	cmp dword[imported_textures], 0
	jle textureHandler_unload_loop_end
	textureHandler_unload_loop_start:
		;check if the current texture id is the one that we are searching for
		mov eax, dword[ebp+16]
		cmp eax, dword[edi]
		jne textureHandler_unload_loop_continue
		
		;save index and exit
		mov dword[ebp-4], esi
		jmp textureHandler_unload_loop_end
		
		textureHandler_unload_loop_continue:
		add edi, 24
		inc esi
		cmp esi, dword[imported_textures]
		jl textureHandler_unload_loop_start
	textureHandler_unload_loop_end:
	
	;check if the texture is in the registry
	cmp dword[ebp-4], -1
	jne textureHandler_unload_registered
		push error_texture_not_registered
		call my_printf
		jmp textureHandler_unload_end
	textureHandler_unload_registered:
	
	;decrement import count
	mov eax, imported_textures
	mov eax, dword[eax+12]
	
	mov ecx, dword[ebp-4]
	imul ecx, 24
	
	dec dword[eax+ecx+20]
	
	;has the import count reached 0?
	cmp dword[eax+ecx+20], 0
	jg textureHandler_unload_end			;no work left
		
		lea edx, [eax+ecx]
		push dword[edx+4]			;path
		push edx					;&gl texture
		push 1
		call [glDeleteTextures]
		call my_free
		
		push dword[ebp-4]			;index
		push imported_textures
		call vector_remove_at
	
	textureHandler_unload_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
textureHandler_loadArray:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4		;TextureArrayInfo		;4
	
	;alloc info
	push 28
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;set the values
	mov ecx, dword[ebp+16]
	mov dword[eax+4], ecx		;width
	mov ecx, dword[ebp+20]
	mov dword[eax+8], ecx		;height
	mov ecx, dword[ebp+24]
	mov dword[eax+20], ecx		;numLayers
	mov ecx, dword[ebp+28]
	mov dword[eax+12], ecx		;wrap
	mov ecx, dword[ebp+32]
	mov dword[eax+16], ecx		;filter
	
	mov dword[eax+24], 0		;mipmap has not been generated yet
	
	;generate and bind texture
	push dword[ebp-4]
	push 1
	call [glGenTextures]
	
	mov edx, dword[ebp-4]
	push dword[edx]
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glBindTexture]
	
	;init the texture
	mov eax, dword[ebp-4]
	push dword[eax+20]			;numLayers
	push dword[eax+8]			;height
	push dword[eax+4]			;width
	push dword[GL_RGBA8]
	push 1						;mipmap levels
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glTexStorage3D]
	
	;set the texture parameters
	mov eax, dword[ebp-4]
	push dword[eax+12]
	push dword[GL_TEXTURE_WRAP_S]
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glTexParameteri]
	mov eax, dword[ebp-4]
	push dword[eax+12]
	push dword[GL_TEXTURE_WRAP_T]
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glTexParameteri]
	mov eax, dword[ebp-4]
	push dword[eax+16]
	push dword[GL_TEXTURE_MIN_FILTER]
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glTexParameteri]
	mov eax, dword[ebp-4]
	push dword[eax+16]
	push dword[GL_TEXTURE_MAG_FILTER]
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glTexParameteri]
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
textureHandler_unloadArray:
	push ebp
	mov ebp, esp
	
	;delete opengl texture
	push dword[ebp+8]
	push 1
	call [glDeleteTextures]
	
	;dealloc texture info
	push dword[ebp+8]
	call my_free
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	
	
textureHandler_addImageToArray:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4		;width					;4
	sub esp, 4		;height					;8
	sub esp, 4		;bitsPerPixel			;12
	sub esp, 4		;return value			;16
	sub esp, 4		;source image format	;20
	
	mov dword[ebp-16], 0
	
	;import texture layer
	lea eax, [ebp-12]
	push eax
	lea eax, [ebp-8]
	push eax
	lea eax, [ebp-4]
	push eax
	push dword[import_buffer]
	push dword[ebp+20]
	call image_loadBMP
	add esp, 20
	
	;check if there are mismatching sizes
	mov eax, dword[ebp+16]
	
	mov ecx, dword[ebp-4]
	cmp dword[eax+4], ecx
	jne textureHandler_addImageToArray_wrong_size
	mov ecx, dword[ebp-8]
	cmp dword[eax+8], ecx
	jne textureHandler_addImageToArray_wrong_size
	jmp textureHandler_addImageToArray_wrong_size_skip
	
	textureHandler_addImageToArray_wrong_size:
		push dword[ebp+20]
		push error_texture_array_image_wrong_size
		call my_printf
		add esp, 8
		
		mov dword[ebp-16], 69
		jmp textureHandler_addImageToArray_end
		
	
	textureHandler_addImageToArray_wrong_size_skip:
	
	;determine the source image format
	cmp dword[ebp-12], 24
	je textureHandler_addImageToArray_rgb
	cmp dword[ebp-12], 32
	je textureHandler_addImageToArray_rgba
		;unsupported format
		push dword[ebp+20]
		push error_texture_array_image_wrong_format
		call my_printf
		add esp, 4
		
		mov dword[ebp-16], 69
		jmp textureHandler_addImageToArray_end
		
	textureHandler_addImageToArray_rgb:
		mov eax, dword[GL_RGB]
		mov dword[ebp-20], eax
		jmp textureHandler_addImageToArray_format_done
		
	textureHandler_addImageToArray_rgba:
		mov eax, dword[GL_RGBA]
		mov dword[ebp-20], eax
		jmp textureHandler_addImageToArray_format_done
		
	textureHandler_addImageToArray_format_done:
	
	;set the data alignment
	push 1
	push dword[GL_UNPACK_ALIGNMENT]
	call [glPixelStorei]
	
	;bind texture array
	mov eax, dword[ebp+16]
	push dword[eax]
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glBindTexture]
	
	;add layer to the texture
	push dword[import_buffer]
	push dword[GL_UNSIGNED_BYTE]
	push dword[ebp-20]				;format
	push 1							;depth?
	push dword[ebp-8]				;height
	push dword[ebp-4]				;widht
	push dword[ebp+24]				;layer
	push 0
	push 0
	push 0
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glTexSubImage3D]
	
	;unbind texture array
	push 0
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glBindTexture]
	
	textureHandler_addImageToArray_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
textureHandler_generateArrayMipmap:
	push ebp
	mov ebp, esp
	
	;bind texture array
	mov eax, dword[ebp+8]
	push dword[eax]
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glBindTexture]
	
	;generate mipmap
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glGenerateMipmap]
	
	;unbind texture array
	push 0
	push dword[GL_TEXTURE_2D_ARRAY]
	call [glBindTexture]
	
	mov esp, ebp
	pop ebp
	ret