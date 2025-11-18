[BITS 32]

section .rodata use32

	test_text db "amogus among us",10,0
	print_int_nl db "%d",10,0

	INVENTORY_ATLAS_ROW_SLOTS dd 8
	INVENTORY_ATLAS_COLUMN_SLOTS dd 8
	INVENTORY_ATLAS_SLOT_SIZE dd 64
	INVENTORY_ATLAS_WIDTH dd 512
	INVENTORY_ATLAS_HEIGHT dd 512
	
	INVENTORY_HOTBAR_SIZE dd 5
	
	global INVENTORY_HOTBAR_SIZE
	global INVENTORY_ATLAS_ROW_SLOTS
	
	rectangle_vertex_vector:
	dd 16
	dd 16
	dd 4
	dd rectangle_vertex_data
	rectangle_vertex_data:
	dd -1.0,-1.0, 0.0, 0.0
	dd -1.0, 1.0, 0.0, 1.0
	dd 1.0, -1.0, 1.0, 0.0
	dd 1.0, 1.0, 1.0, 1.0
	
	rectangle_index_vector:
	dd 6
	dd 6
	dd 4
	dd rectangle_index_data
	rectangle_index_data:
	dd 1,0,3,3,0,2
	
	geometry_pass_vertex_shader_path db "shaders/inventory/atlas_geometry.vag",0
	geometry_pass_geometry_shader_path db "shaders/inventory/hypercube.gag",0
	geometry_pass_fragment_shader_path db "shaders/inventory/atlas_geometry.fag",0

	shading_pass_vertex_shader_path db "shaders/inventory/atlas_shading.vag",0
	shading_pass_fragment_shader_path db "shaders/inventory/atlas_shading.fag",0
	
	uniform_name_viewMat db "view_mat",0
	uniform_name_normalMat db "normal_mat",0
	uniform_name_offset db "offset",0
	uniform_name_blockUVZ db "blockUVZ",0
	
	MINUS_ANDERTHALB dd -1.5
	ANDERTHALB dd 1.5
	
	VIEW_DIR dd 0.0, 0.0, -1.0
	VIEW_POS dd 0.0, 0.0, 0.0
	VIEW_UP dd 0.0, 1.0, 0.0
	
	FOV dd 60.0
	NEAR_CLIP dd 0.1
	FAR_CLIP dd 10.0
	ASPECT_XY dd 1.0
	
	HYPERCUBE_POSITION dd 0.6, 0.6, 0.6, 0.6
	
	INVENTORY_CONTENT_DEFAULT:
	dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
	dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
	dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
	dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
	dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
	dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
	dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
	dd 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
	
section .data use32
	initialized dd 0
	
	texcoord_framebuffer dd 0
	hypercube_renderable dd 0
	geometry_pass_shader dd 0
	
	atlas_framebuffer dd 0
	rectangle_renderable dd 0
	shading_pass_shader dd 0
	
	hyperplane:
	dd 0.0, 0.0, 0.0, 0.0
	dd 1.0, 0.0, 0.0, 0.0
	dd 0.0, 1.0, 0.0, 0.0
	dd 0.0, 0.0, 1.0, 0.0
	
	geometry_pass_view_matrix:
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	geometry_pass_pv_matrix:
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0, 0.0
	geometry_pass_normal_matrix:
	dd 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0
	
section .bss use32
	inventory_content resb 256			;slot_count*sizeof(float)
	selected_hotbar_slot resb 0
	
section .text use32

	global inventoryAtlas_init			;void inventoryAtlas_init()
	global inventoryAtlas_deinit		;void inventoryAtlas_deinit()
	global inventoryAtlas_render		;void inventoryAtlas_render(TextureArrayInfo* blockTextures)
	global inventoryAtlas_processInput	;void inventoryAtlas_processInput()
	
	global inventoryAtlas_getAtlas		;GLuint inventoryAtlas_getAtlas()
	global inventoryAtlas_setHyperplane	;void inventoryAtlas_setHyperplane(const Hyperplane* plane)
	
	global inventoryAtlas_getHotbarContent	;float[INVENTORY_HOTBAR_SIZE] inventoryAtlas_getHotbarContent()
	global inventoryAtlas_getInventoryContent	;float[INVENTORY_ATLAS_ROW_SLOTS*(INVENTORY_ATLAS_COLUMN_SLOTS-1)] inventoryAtlas_getInventoryContent()
	global inventoryAtlas_getSelectedHotbarSlot	;int inventoryAtlas_getSelectedHotbarSlot()
	
	extern my_printf
	extern my_memcpy
	
	extern mat4_viewGlm
	extern mat4_perspectiveGlm
	extern mat4_ortho
	extern mat4_mul
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	extern renderable_calculateNormalMatrix
	extern renderable_setUniform
	extern renderable_setExtraTexture2D
	extern renderable_setPrimitive
	extern renderable_enableDepthTest
	extern RENDERABLE_UNIFORM_VEC3
	extern RENDERABLE_UNIFORM_MAT3
	extern RENDERABLE_UNIFORM_MAT4
	extern RENDERABLE_UNIFORM_FLOAT_ARRAY
	extern glClear
	extern glClearColor
	extern glViewport
	extern glGetError
	extern GL_COLOR_BUFFER_BIT
	extern GL_TRIANGLES
	
	extern hyperCubeRenderable_create
	extern hyperCubeRenderable_destroy
	extern hyperCubeRenderable_render
	
	extern textureHandler_bindArray
	
	extern framebuffer_create
	extern framebuffer_destroy
	extern framebuffer_bind
	extern framebuffer_colourAttachment
	extern framebuffer_isComplete
	extern FRAMEBUFFER_RGB
	extern FRAMEBUFFER_RGBA
	
	extern hyperPlane_create
	extern hyperPlane_positionTo3d
	
	extern input_keyPressed
	extern GLFW_KEY_1
	
inventoryAtlas_init:
	push ebp
	mov ebp, esp
	
	;check if the system is already initialized
	test dword[initialized], 0xffffffff
	jz inventoryAtlas_init_not_initialized
		push inventoryAtlas_init_error_already_initialized
		call my_printf
		jmp inventoryAtlas_init_end
		
		inventoryAtlas_init_error_already_initialized db "inventoryAtlas_init: the system is already initialized",10,0
	inventoryAtlas_init_not_initialized:
	
	;calculate matrices
	push VIEW_UP
	push VIEW_DIR
	push VIEW_POS
	push geometry_pass_view_matrix
	call mat4_viewGlm
	
	push dword[FAR_CLIP]
	push dword[NEAR_CLIP]
	push dword[ASPECT_XY]
	push dword[FOV]
	push geometry_pass_pv_matrix
	call mat4_perspectiveGlm
	push dword[ANDERTHALB]
	push dword[MINUS_ANDERTHALB]
	push dword[ANDERTHALB]
	push dword[MINUS_ANDERTHALB]
	push dword[ANDERTHALB]
	push dword[MINUS_ANDERTHALB]
	push geometry_pass_pv_matrix
	call mat4_ortho
	push geometry_pass_view_matrix
	push geometry_pass_pv_matrix
	push geometry_pass_pv_matrix
	call mat4_mul
	
	push geometry_pass_view_matrix
	push geometry_pass_normal_matrix
	call renderable_calculateNormalMatrix
	
	;create rectangle renderable
	push 0
	push 2
	push 2
	push 2
	push rectangle_index_vector
	push rectangle_vertex_vector
	call renderable_createCustom
	mov dword[rectangle_renderable], eax
	
	;create hypercube renderable
	call hyperCubeRenderable_create
	mov dword[hypercube_renderable], eax
	
	;create texcoord framebuffer
	push dword[INVENTORY_ATLAS_SLOT_SIZE]
	push dword[INVENTORY_ATLAS_SLOT_SIZE]
	call framebuffer_create
	mov dword[texcoord_framebuffer], eax
	
	push 0
	push FRAMEBUFFER_RGB
	push dword[texcoord_framebuffer]
	call framebuffer_colourAttachment
	
	call framebuffer_isComplete
	test eax, eax
	jnz inventoryAtlas_init_framebuffer_gg
		push inventoryAtlas_init_error_no_framebuffer
		call my_printf
		jmp inventoryAtlas_init_framebuffer_gg
		inventoryAtlas_init_error_no_framebuffer db "inventoryAtlas_init: L texcoord framebuffer, kys",10,0
	inventoryAtlas_init_framebuffer_gg:
	
	;create atlas framebuffer
	push dword[INVENTORY_ATLAS_WIDTH]
	push dword[INVENTORY_ATLAS_HEIGHT]
	call framebuffer_create
	mov dword[atlas_framebuffer], eax
	
	push 0
	push FRAMEBUFFER_RGBA
	push dword[atlas_framebuffer]
	call framebuffer_colourAttachment
	
	call framebuffer_isComplete
	test eax, eax
	jnz inventoryAtlas_init_framebuffer_gg2
		push inventoryAtlas_init_error_no_framebuffer2
		call my_printf
		jmp inventoryAtlas_init_framebuffer_gg2
		inventoryAtlas_init_error_no_framebuffer2 db "inventoryAtlas_init: L atlas framebuffer, kys",10,0
	inventoryAtlas_init_framebuffer_gg2:
	
	;create geometry pass shader and set matrix uniforms
	push geometry_pass_geometry_shader_path
	push geometry_pass_fragment_shader_path
	push geometry_pass_vertex_shader_path
	call renderable_createShader
	mov dword[geometry_pass_shader], eax
	
	push dword[geometry_pass_shader]
	call renderable_useShader
	
	push geometry_pass_view_matrix
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_viewMat
	push dword[geometry_pass_shader]
	call renderable_setUniform
	
	push geometry_pass_normal_matrix
	push dword[RENDERABLE_UNIFORM_MAT3]
	push uniform_name_normalMat
	push dword[geometry_pass_shader]
	call renderable_setUniform
	
	;create shading pass shader
	push 0
	push shading_pass_fragment_shader_path
	push shading_pass_vertex_shader_path
	call renderable_createShader
	mov dword[shading_pass_shader], eax
	
	;init hyperplane
	push hyperplane
	call hyperPlane_create
	
	;init inventory
	mov eax, dword[INVENTORY_ATLAS_ROW_SLOTS]
	imul eax, dword[INVENTORY_ATLAS_COLUMN_SLOTS]
	shl eax, 2
	push eax
	push INVENTORY_CONTENT_DEFAULT
	push inventory_content
	call my_memcpy
	
	mov dword[selected_hotbar_slot], 0

	;set initialized flag
	mov dword[initialized], 69

	inventoryAtlas_init_end:
	mov esp, ebp
	pop ebp
	ret
	
	
inventoryAtlas_deinit:
	push ebp
	mov ebp, esp
	
	;check if the system is already deinitalized
	test dword[initialized], 0xffffffff
	jnz inventoryAtlas_deinit_initialized
		push inventoryAtlas_deinit_error_not_initialized
		call my_printf
		jmp inventoryAtlas_deinit_end
		inventoryAtlas_deinit_error_not_initialized db "inventoryAtlas_deinit: the system is already deinitialized",10,0
	inventoryAtlas_deinit_initialized:
	
	;destory renderable
	push dword[hypercube_renderable]
	call hyperCubeRenderable_destroy
	
	push dword[rectangle_renderable]
	call renderable_destroy
	
	;destroy framebuffers
	push dword[texcoord_framebuffer]
	call framebuffer_destroy
	
	push dword[atlas_framebuffer]
	call framebuffer_destroy
	
	;yeet shaders
	push dword[geometry_pass_shader]
	call renderable_destroyShader
	
	push dword[shading_pass_shader]
	call renderable_destroyShader
	
	;unset the initialized flag
	mov dword[initialized], 0
	
	inventoryAtlas_deinit_end:
	mov esp, ebp
	pop ebp
	ret
	
	
inventoryAtlas_render:
	push ebp
	mov ebp, esp
	
	;geometry pass	---------------------------------------------
	push dword[texcoord_framebuffer]
	call framebuffer_bind
	
	push dword[INVENTORY_ATLAS_SLOT_SIZE]
	push dword[INVENTORY_ATLAS_SLOT_SIZE]
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
	
	push 0
	call renderable_enableDepthTest
	
	push dword[geometry_pass_shader]
	call renderable_useShader
	
	sub esp, 12
	mov eax, esp
	push eax
	push HYPERCUBE_POSITION
	push hyperplane
	call hyperPlane_positionTo3d
	add esp, 12
	xor dword[esp+8], 0x80000000
	xor dword[esp+4], 0x80000000
	xor dword[esp], 0x80000000
	push dword[RENDERABLE_UNIFORM_VEC3]
	push uniform_name_offset
	push dword[geometry_pass_shader]
	call renderable_setUniform
	
	push dword[geometry_pass_shader]
	push HYPERCUBE_POSITION
	push hyperplane
	push geometry_pass_pv_matrix
	push dword[hypercube_renderable]
	call hyperCubeRenderable_render
	
	;shading pass	-------------------------------------
	push dword[atlas_framebuffer]
	call framebuffer_bind
	
	push dword[INVENTORY_ATLAS_HEIGHT]
	push dword[INVENTORY_ATLAS_WIDTH]
	push 0
	push 0
	call [glViewport]
	
	push dword[GL_COLOR_BUFFER_BIT]
	call [glClear]
	
	mov eax, dword[texcoord_framebuffer]
	push dword[eax+4]		;colour attachment 0
	push 0
	push dword[rectangle_renderable]
	call renderable_setExtraTexture2D
	
	push 3
	push dword[ebp+8]
	call textureHandler_bindArray
	
	push dword[shading_pass_shader]
	call renderable_useShader
	
	mov eax, dword[INVENTORY_ATLAS_ROW_SLOTS]
	imul eax, dword[INVENTORY_ATLAS_COLUMN_SLOTS]
	push inventory_content
	push eax
	push dword[RENDERABLE_UNIFORM_FLOAT_ARRAY]
	push uniform_name_blockUVZ
	push dword[shading_pass_shader]
	call renderable_setUniform
	
	push dword[GL_TRIANGLES]
	call renderable_setPrimitive			;set back the primitive to triangle
	
	push 69
	push dword[shading_pass_shader]
	push geometry_pass_pv_matrix			;only as a placeholder
	push dword[rectangle_renderable]
	call renderable_renderCustom
	
	mov esp, ebp
	pop ebp
	ret
	
inventoryAtlas_processInput:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;get the current hotbar slot
	call inventoryAtlas_getSelectedHotbarSlot
	mov ebx, eax							;selected slot
	xor esi, esi							;index
	mov edi, dword[GLFW_KEY_1]				;currently tested key
	inventoryAtlas_processInput_hotbar_loop_start:
		push edi
		call input_keyPressed
		add esp, 4
		test eax, eax
		jz inventoryAtlas_processInput_hotbar_loop_continue
			;pressed
			mov ebx, esi
		inventoryAtlas_processInput_hotbar_loop_continue:
		inc edi
		inc esi
		cmp esi, dword[INVENTORY_HOTBAR_SIZE]
		jl inventoryAtlas_processInput_hotbar_loop_start
		
	mov dword[selected_hotbar_slot], ebx
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
inventoryAtlas_getAtlas:
	mov eax, dword[atlas_framebuffer]
	mov eax, dword[eax+4]
	ret
	
	
inventoryAtlas_setHyperplane:
	mov eax, [esp+4]
	push 64
	push eax
	push hyperplane
	call my_memcpy
	add esp, 12
	ret
	
inventoryAtlas_getHotbarContent:	
	mov eax, inventory_content
	ret
	
inventoryAtlas_getInventoryContent:
	mov eax, dword[INVENTORY_ATLAS_ROW_SLOTS]
	lea eax, [inventory_content+4*eax]
	ret
	
inventoryAtlas_getSelectedHotbarSlot:
	mov eax, dword[selected_hotbar_slot]
	ret