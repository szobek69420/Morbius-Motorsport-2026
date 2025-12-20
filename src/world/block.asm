[BITS 32]

section .rodata use32
	BLOCK_COUNT dd 7

	global BLOCK_AIR
	global BLOCK_STONE
	global BLOCK_GRASS
	global BLOCK_DIRT
	global BLOCK_OAK_LOG
	global BLOCK_OAK_LEAVES
	global BLOCK_LAMP
	
	
	BLOCK_AIR db 0
	BLOCK_STONE db 1
	BLOCK_GRASS db 2
	BLOCK_DIRT db 3
	BLOCK_OAK_LOG db 4
	BLOCK_OAK_LEAVES db 5
	BLOCK_LAMP db 6
	
	BLOCK_TEXTURE_AIR db "sprites/blocks/air.bmp",0
	BLOCK_TEXTURE_STONE db "sprites/blocks/stone.bmp",0
	BLOCK_TEXTURE_GRASS db "sprites/blocks/grass.bmp",0
	BLOCK_TEXTURE_DIRT db "sprites/blocks/dirt.bmp",0
	BLOCK_TEXTURE_OAK_LOG db "sprites/blocks/oak_log.bmp",0
	BLOCK_TEXTURE_OAK_LEAVES db "sprites/blocks/oak_leaves.bmp",0
	BLOCK_TEXTURE_LAMP db "sprites/blocks/lamp.bmp",0
	
	BLOCK_EMISSIONS:	;colour.rgb, intensity
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 1.0, 1.0, 5.0
	
	
	BLOCKS:
	dd BLOCK_AIR, BLOCK_STONE, BLOCK_GRASS, BLOCK_DIRT, BLOCK_OAK_LOG, BLOCK_OAK_LEAVES, BLOCK_LAMP
	
	BLOCK_TEXTURES:
	dd BLOCK_TEXTURE_AIR, BLOCK_TEXTURE_STONE, BLOCK_TEXTURE_GRASS, BLOCK_TEXTURE_DIRT, BLOCK_TEXTURE_OAK_LOG, BLOCK_TEXTURE_OAK_LEAVES, BLOCK_TEXTURE_LAMP
	
	BLOCK_TEXTURE_WIDTH dd 16
	BLOCK_TEXTURE_HEIGHT dd 16
	
	print_int_nl db "%d",10,0
	
section .text use32

	global block_importTextures		;TextureArrayInfo*	block_importTextures()
	global block_deleteTextures		;void block_deleteTextures(TextureArrayInfo* ta)
	
	global block_isEmissive			;int block_isEmissive(int blockAsInt)
	global block_getEmissionInfo	;void block_getEmissionInfo(int blockAsInt, vec4* colourAndIntensity)
	
	;sets a uniform array with the length of BLOCK_COUNT, where the elements are vec4(emission colour rgb, intensity)
	;DOESN'T BIND THE SHADER
	;void block_setEmissionUniforms(GLuint shader, const char* uniformName)
	global block_setEmissionUniforms
	
	extern my_printf
	
	extern textureHandler_loadArray
	extern textureHandler_unloadArray
	extern textureHandler_addImageToArray
	extern textureHandler_generateArrayMipmap
	
	extern renderable_setUniform
	extern RENDERABLE_UNIFORM_VEC4_ARRAY
	
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
	push dword[BLOCK_COUNT]
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
	
	
block_isEmissive:
	mov eax, dword[esp+4]
	rol eax, 1
	mov ecx, 12
	mov eax, dword[BLOCK_EMISSIONS+8*eax+ecx]
	ret
	
block_getEmissionInfo:
	mov eax, dword[esp+4]
	rol eax, 4
	add eax, BLOCK_EMISSIONS
	
	mov ecx, dword[esp+8]
	mov edx, dword[eax]
	mov dword[ecx], edx
	mov edx, dword[eax+4]
	mov dword[ecx+4], edx
	mov edx, dword[eax+8]
	mov dword[ecx+8], edx
	mov edx, dword[eax+12]
	mov dword[ecx+12], edx
	
	ret
	
	
	
block_setEmissionUniforms:
	push ebp
	mov ebp, esp
	
	push BLOCK_EMISSIONS
	push dword[BLOCK_COUNT]
	push dword[RENDERABLE_UNIFORM_VEC4_ARRAY]
	push dword[ebp+12]
	push dword[ebp+8]
	call renderable_setUniform
	
	mov esp, ebp
	pop ebp
	ret