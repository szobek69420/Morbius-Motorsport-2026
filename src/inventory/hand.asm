[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	;shaders for the hypercube
	vertex_shader_path db "shaders/inventory/hand.vag",0
	geometry_shader_path db "shaders/inventory/hypercube.gag",0
	fragment_shader_path db "shaders/inventory/hand.fag",0
	
	;shaders for the 3d arm
	arm_vs_path db "shaders/inventory/arm.vag",0
	arm_gs_path db "shaders/inventory/arm.gag",0
	arm_fs_path db "shaders/inventory/arm.fag",0
	arm_model_path db "models/hand.geometry",0
	
	WORLD_UP dd 0.0, 1.0, 0.0
	HYPERCUBE_POSITION dd 0.6, 0.6, 0.6, 0.6
	FORWARD dd 0.0, 0.0, -1.0
	ORIGO dd 0.0, 0.0, 0.0
	
	ARM_OFFSET dd 2.5, -1.3, -6.0
	HAND_OFFSET dd 2.5, -1.0, -6.0
	
	FOV dd 60.0
	NEAR_CLIP dd 0.1
	FAR_CLIP dd 10.0
	
	uniform_name_uvZ db "uv_z",0
	uniform_name_viewMat db "view_mat",0
	uniform_name_normalMat db "normal_mat",0
	uniform_name_handOffset db "offset",0
	uniform_name_armOffset db "arm_offset",0
	
	TIME_CONVERTER dd 0.001
	CUBE_ROTATION_RATE dd 150.0
	ROTATION_PLANE_VEC_11 dd 0.828671, -0.435052, 0.165734, 0.310752
	ROTATION_PLANE_VEC_12 dd 0.316183, 0.469005, -0.790458, 0.235028
	
	CUBE_HOVER_AMPLITUDE dd 0.3
	
	DEG2RAD dd 0.01745329252
	
	ONE dd 1.0
	THREE dd 3.0
	
	test_text db "fyodor brostoevsky",10,0

section .data use32
	initialized dd 0

	cube_renderable dd 0
	cube_shader dd 0
	
	time_of_previous_hyperplane_update dd 0			;float seconds
	hyperplane:
	dd 0.0, 0.0, 0.0, 0.0,
	dd 1.0, 0.0, 0.0, 0.0,
	dd 0.0, 1.0, 0.0, 0.0,
	dd 0.0, 0.0, 1.0, 0.0
	
	previous_screen_width dd -1
	previous_screen_height dd -1
	projection_matrix:
	dd 1.1, 1.1, 1.1, 0.0,
	dd 1.1, 0.0, 1.1, 1.1,
	dd 1.1, 1.1, 1.1, 1.1,
	dd 1.1, 0.0, 1.1, 0.0
	
	view_matrix:
	dd 1.0, 0.0, 0.0, 0.0
	dd 0.0, 1.0, 0.0, 0.0
	dd 0.0, 0.0, -1.0, 0.0
	dd 0.0, 0.0, 0.0, 1.0
	
	normal_matrix:
	dd 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0
	dd 0.0, 0.0, 0.0
	
	arm_renderable dd 0
	arm_shader dd 0

section .text use32

	global hand_init			;void hand_init()
	global hand_deinit			;void hand_deinit()
	
	global hand_render			;void hand_render(TextureArrayInfo* blockTextureArray, const mat4* projection_mat)
	global hand_renderArm		;void hand_renderArm(const mat4* projection)
	
	dll_import kernel32.dll, GetTickCount
	
	extern my_printf
	extern my_memset
	
	extern vec3_add
	extern vec3_sub
	extern vec3_scale
	extern vec3_normalize
	extern vec3_cross
	extern vec3_mulWithMat
	extern mat3_transpose
	extern mat4_transpose
	extern mat4_mul
	extern mat4_viewGlm
	extern mat4_perspectiveGlm
	
	extern hyperCubeRenderable_create
	extern hyperCubeRenderable_destroy
	extern hyperCubeRenderable_render
	extern renderable_renderCustom
	extern renderable_destroy
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	extern renderable_setUniform
	extern renderable_enableDepthTest
	extern renderable_setDepthFunc
	extern renderable_calculateNormalMatrix
	extern renderable_setPosition
	extern renderable_setRotation
	extern renderable_setPrimitive
	extern RENDERABLE_UNIFORM_1F
	extern RENDERABLE_UNIFORM_VEC3
	extern RENDERABLE_UNIFORM_MAT3
	extern RENDERABLE_UNIFORM_MAT4
	extern GL_ALWAYS
	extern GL_LEQUAL
	extern GL_LESS
	extern GL_POINTS
	extern GL_TRIANGLES
	
	extern textureHandler_bindArray
	
	extern hyperPlane_create
	extern hyperPlane_rotate
	extern hyperPlane_positionTo3d
	
	extern WINDOW_SIZE_X
	extern WINDOW_SIZE_Y
	
	extern geometryImporter_import
	
	extern camera_forward
	extern camera_up
	extern camera_right
	extern camera_view
	
	extern inventoryAtlas_setHyperplane
	extern inventoryAtlas_getHotbarContent
	extern inventoryAtlas_getSelectedHotbarSlot
	
hand_init:
	push ebp
	mov ebp, esp
	
	;check if the system is already initialized
	test dword[initialized], 0xffffffff
	jz hand_init_not_initialized
		push hand_init_error_already_initialized
		call my_printf
		jmp hand_init_end
		
		hand_init_error_already_initialized db "hand_init: the system is already initialized",10,0
	hand_init_not_initialized:
	
	;create things
	push hyperplane
	call hyperPlane_create
	
	push geometry_shader_path
	push fragment_shader_path
	push vertex_shader_path
	call renderable_createShader
	mov dword[cube_shader], eax
	
	push arm_model_path
	call geometryImporter_import
	mov dword[arm_renderable], eax
	
	push arm_gs_path
	push arm_fs_path
	push arm_vs_path
	call renderable_createShader
	mov dword[arm_shader], eax
	
	;initialize things
	call hyperCubeRenderable_create
	mov dword[cube_renderable], eax
	
	mov dword[previous_screen_width], -1
	mov dword[previous_screen_height], -1
	
	push WORLD_UP
	push FORWARD
	push ORIGO
	push view_matrix
	call mat4_viewGlm
	
	push view_matrix
	push normal_matrix
	call renderable_calculateNormalMatrix
	
	;set initialized flag
	mov dword[initialized], 69
	
	hand_init_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
hand_deinit:
	push ebp
	mov ebp, esp
	
	;check if the system is not yet initialized
	test dword[initialized], 0xffffffff
	jnz hand_deinit_initialized
		push hand_deinit_error_not_initialized
		call my_printf
		jmp hand_deinit_end
		
		hand_deinit_error_not_initialized db "hand_deinit: the system is not initialized",10,0
	hand_deinit_initialized:
	
	;destroy things
	push dword[cube_renderable]
	call hyperCubeRenderable_destroy
	push dword[cube_shader]
	call renderable_destroyShader
	
	push dword[arm_renderable]
	call renderable_destroy
	push dword[arm_shader]
	call renderable_destroyShader
	
	;unset the initialized flag
	mov dword[initialized], 0
	
	hand_deinit_end:
	mov esp, ebp
	pop ebp
	ret
	
	
hand_render:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 64			;pv matrix				64
	sub esp, 12			;adjusted hand offset	76
	
	;check if the system is initialized
	test dword[initialized], 0xffffffff
	jz hand_render_end
	
	;update the projection matrix if necessary
	mov ebx, dword[previous_screen_width]
	sub ebx, dword[WINDOW_SIZE_X]
	mov edx, dword[previous_screen_height]
	sub edx, dword[WINDOW_SIZE_Y]
	or ebx, edx
	test ebx, ebx
	jz hand_render_skip_projection
		mov eax, dword[WINDOW_SIZE_X]
		mov dword[previous_screen_width], eax
		mov ecx, dword[WINDOW_SIZE_Y]
		mov dword[previous_screen_height], ecx
		
		cvtsi2ss xmm0, eax
		cvtsi2ss xmm1, ecx
		divss xmm0, xmm1			;aspect ratio in xmm0
		
		push dword[FAR_CLIP]
		push dword[NEAR_CLIP]
		sub esp, 4
		movss dword[esp], xmm0
		push dword[FOV]
		push projection_matrix
		call mat4_perspectiveGlm
		
	hand_render_skip_projection:
	
	;rotate the hyperplane
	call [GetTickCount]
	cvtsi2ss xmm0, eax
	mulss xmm0, dword[TIME_CONVERTER]
	movss xmm1, xmm0
	subss xmm1, dword[time_of_previous_hyperplane_update]
	mulss xmm1, dword[CUBE_ROTATION_RATE]
	movss dword[time_of_previous_hyperplane_update], xmm0		;update the time
	
	sub esp, 4
	movss dword[esp], xmm1
	push ROTATION_PLANE_VEC_12
	push ROTATION_PLANE_VEC_11
	push hyperplane
	call hyperPlane_rotate
	
	;also update the inventory hyperplane
	push hyperplane
	call inventoryAtlas_setHyperplane

	;calculate the adjusted hand offset
	lea eax, [ebp-76]
	push eax
	push HYPERCUBE_POSITION
	push hyperplane
	call hyperPlane_positionTo3d
	
	lea eax, [ebp-76]
	push eax
	push HAND_OFFSET
	push eax
	call vec3_sub
	
	fld dword[time_of_previous_hyperplane_update]
	fmul dword[THREE]
	fsin
	fmul dword[CUBE_HOVER_AMPLITUDE]
	fadd dword[ebp-72]
	fstp dword[ebp-72]					;hover animation
	
	;calculate the matices
	lea eax, [ebp-64]
	push view_matrix
	push dword[ebp+24]
	push eax
	call mat4_mul
	
	;prepare uniforms
	push dword[cube_shader]
	call renderable_useShader
	
	call inventoryAtlas_getSelectedHotbarSlot
	push eax
	call inventoryAtlas_getHotbarContent
	mov ecx, dword[esp]
	mov edx, dword[eax+4*ecx]
	mov dword[esp], edx					;current block
	push dword[RENDERABLE_UNIFORM_1F]
	push uniform_name_uvZ
	push dword[cube_shader]
	call renderable_setUniform
	
	push view_matrix
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_viewMat
	push dword[cube_shader]
	call renderable_setUniform
	
	push normal_matrix
	push dword[RENDERABLE_UNIFORM_MAT3]
	push uniform_name_normalMat
	push dword[cube_shader]
	call renderable_setUniform
	
	push dword[ebp-68]
	push dword[ebp-72]
	push dword[ebp-76]
	push dword[RENDERABLE_UNIFORM_VEC3]
	push uniform_name_handOffset
	push dword[cube_shader]
	call renderable_setUniform
	
	;bind block textures
	push 0
	push dword[ebp+20]
	;call textureHandler_bindArray
	
	;enable depth test and set depth func
	push 69
	call renderable_enableDepthTest
	
	push dword[GL_ALWAYS]
	call renderable_setDepthFunc
	
	;set primitive
	push dword[GL_POINTS]
	call renderable_setPrimitive
	
	;render the cube
	push dword[cube_shader]
	push HYPERCUBE_POSITION
	push hyperplane
	lea eax, [ebp-64]
	push eax
	push dword[cube_renderable]
	call hyperCubeRenderable_render
	
	;reset primitive
	push dword[GL_TRIANGLES]
	call renderable_setPrimitive
	
	;reset depth func
	push dword[GL_LEQUAL]
	call renderable_setDepthFunc
	
	
	hand_render_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
	
hand_renderArm:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 64			;pv mat				64
	
	;calculate the pv mat
	lea eax, [ebp-64]
	push view_matrix
	push dword[ebp+20]
	push eax
	call mat4_mul
	
	;set uniforms
	push dword[arm_shader]
	call renderable_useShader
	
	mov eax, ARM_OFFSET
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push dword[RENDERABLE_UNIFORM_VEC3]
	push uniform_name_armOffset
	push dword[arm_shader]
	call renderable_setUniform
	
	push view_matrix
	push dword[RENDERABLE_UNIFORM_MAT4]
	push uniform_name_viewMat
	push dword[arm_shader]
	call renderable_setUniform
	
	;set depth fun
	push dword[GL_LESS]
	call renderable_setDepthFunc
	
	;set primitive
	push dword[GL_TRIANGLES]
	call renderable_setPrimitive
	
	;render arm
	push 0
	push dword[arm_shader]
	lea eax, [ebp-64]
	push eax
	push dword[arm_renderable]
	call renderable_renderCustom
	
	;reset depth fun
	push dword[GL_LEQUAL]
	call renderable_setDepthFunc
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret