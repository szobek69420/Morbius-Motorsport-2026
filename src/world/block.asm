[BITS 32]

section .rodata use32
	global BLOCK_AIR
	global BLOCK_STONE
	global BLOCK_GRASS
	global BLOCK_DIRT

	BLOCK_AIR db 0
	BLOCK_STONE db 1
	BLOCK_GRASS db 2
	BLOCK_DIRT db 3
	
	BLOCK_TEXTURE_AIR db "sprites/blocks/air.bmp",0
	BLOCK_TEXTURE_STONE db "sprites/blocks/stone.bmp",0
	BLOCK_TEXTURE_GRASS db "sprites/blocks/grass.bmp",0
	BLOCK_TEXTURE_DIRT db "sprites/blocks/dirt.bmp",0
	
	
	BLOCK_COUNT dd 4
	
	BLOCKS:
	dd BLOCK_AIR, BLOCK_STONE, BLOCK_GRASS, BLOCK_DIRT
	
	BLOCK_TEXTURES:
	dd BLOCK_TEXTURE_AIR, BLOCK_TEXTURE_STONE, BLOCK_TEXTURE_GRASS, BLOCK_TEXTURE_DIRT
	
	BLOCK_TEXTURE_WIDTH dd 16
	BLOCK_TEXTURE_HEIGHT dd 16
	BLOCK_TEXTURE_LAYERS dd 10
	
	print_int_nl db "%d",10,0
	
section .text use32

	global block_importTextures		;TextureArrayInfo*	block_importTextures()
	global block_deleteTextures		;void block_deleteTextures(TextureArrayInfo* ta)
	
	extern my_printf
	
	extern textureHandler_loadArray
	extern textureHandler_unloadArray
	extern textureHandler_addImageToArray
	extern textureHandler_generateArrayMipmap
	
	extern GL_REPEAT
	extern GL_NEAREST
	extern glGetError
	
	
block_importTextures:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;TextureArrayInfo*		;4
	
	;create texture info
	push dword[GL_NEAREST]
	push dword[GL_REPEAT]
	push dword[BLOCK_TEXTURE_LAYERS]
	push dword[BLOCK_TEXTURE_HEIGHT]
	push dword[BLOCK_TEXTURE_WIDTH]
	call textureHandler_loadArray
	mov dword[ebp-4], eax
	add esp, 20
	
	
	;import block textures
	xor esi, esi						;index in esi
	block_importTextures_loop_start:
		;import block texture
		xor edx, edx
		mov eax, dword[BLOCKS+4*esi]
		mov dl, byte[eax]
		push edx
		push dword[BLOCK_TEXTURES+4*esi]
		push dword[ebp-4]
		call textureHandler_addImageToArray
		add esp, 12
	
		inc esi
		cmp esi, dword[BLOCK_COUNT]
		jl block_importTextures_loop_start
		
	;generate mipmap
	push dword[ebp-4]
	call textureHandler_generateArrayMipmap
	add esp, 4
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
block_deleteTextures:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call textureHandler_unloadArray
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret