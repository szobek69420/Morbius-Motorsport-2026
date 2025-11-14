[BITS 32]

section .rodata use32

	INVENTORY_ATLAS_ROW_SLOTS dd 8
	INVENTORY_ATLAS_COLUMN_SLOTS dd 8
	INVENTORY_ATLAS_SLOT_SIZE dd 64
	INVENTORY_ATLAS_WIDTH dd 512
	INVENTORY_ATLAS_HEIGHT dd 512
	
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
	
	MINUS_ONE dd -1.0
	ONE dd 1.0
	
	VIEW_DIR dd 0.0, 0.0, -1.0
	VIEW_POS dd 0.0, 0.0, 0.0
	VIEW_UP dd 0.0, 1.0, 0.0
	
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
	
section .text use32

	global inventoryAtlas_init			;void inventoryAtlas_init()
	global inventoryAtlas_deinit		;void inventoryAtlas_deinit()
	
	extern my_printf
	
	extern mat4_viewGlm
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
	extern RENDERABLE_UNIFORM_MAT3
	extern RENDERABLE_UNIFORM_MAT4
	
	extern hyperCubeRenderable_create
	extern hyperCubeRenderable_destroy
	
	extern framebuffer_create
	extern framebuffer_destroy
	extern framebuffer_colourAttachment
	extern framebuffer_isComplete
	extern FRAMEBUFFER_RGB
	extern FRAMEBUFFER_RGBA
	
	extern hyperPlane_create
	
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
	
	push dword[ONE]
	push dword[MINUS_ONE]
	push dword[ONE]
	push dword[MINUS_ONE]
	push dword[ONE]
	push dword[MINUS_ONE]
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
	
	
	mov esp, ebp
	pop ebp
	ret