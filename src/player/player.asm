[BITS 32]

;layout:
;struct player{
;	camera* cum;					0
;	vec3 position;					4 (unused)
;	float pitch, yaw;				16
;	Aabb4D* collider;				24
;	ChunkManager* chunkManager;		28
;	Mutex* hyperPlaneMutex;			32(unused)
;	vec4 previousColliderPos; 		36(unused)
;	Renderable* hypercube			52
;	Aabb4D* lastRaycastCollider		56 //zero if no hit
;	int lastRaycastDirection		60	//it's for example AABB_POS_X
;	Renderable* debugNormal			64
;	GLuint debugNormalShader		68
;}		72 bytes

section .rodata use32
	ZERO dd 0.0
	ONE dd 1.0
	MINUS_ONE dd -1.0
	HALF dd 0.5
	
	NEG_88P9 dd -88.9
	POS_88P9 dd 88.9
	
	POS_360 dd 360.0
	
	GRAV_ACC dd -9.80625
	
	START_POSITION dd 0.0, 100.0, 0.0, 0.0
	START_SCALE dd 0.1, 0.9, 0.1, 0.1
	
	UP dd 0.0, 1.0, 0.0
	DOWN dd 0.0, -1.0, 0.0
	NULL_VECTOR_4D dd 0.0, 0.0, 0.0, 0.0
	
	LOOK_SENSITIVITY_X dd -0.03
	LOOK_SENSITIVITY_Y dd 0.03
	
	COLLIDER_HEIGHT dd 0.9
	COLLIDER_RADIUS dd 0.12
	
	EYE_OFFSET dd 0.0, 0.75, 0.0, 0.0		;the offset of the camera from the center of the collider
	
	MOVEMENT_SPEED dd 5.0
	
	HYPERPLANE_ROTATION_VECTOR_1 dd 0.466323, 0.0, 0.768061, 0.438892
	HYPERPLANE_ROTATION_VECTOR_2 dd 0.5833265, 0.0, -0.639972, 0.5001663
	HYPERPLANE_ROTATION_ANGLE dd 2.0
	
	RAYCAST_MAX_DISTANCE dd 5.0
	
	CUM_NORMAL_FOV dd 60.0
	CUM_ZOOM_FOV dd 10.0
	CUM_FOV_INTERPOLATION_STRENGTH dd 0.2
	
	raycast_hypercube_texture db "sprites/player_hypercube.bmp",0
	
	debug_normal_vertex_shader db "shaders/player/debug_normal.vag",0
	debug_normal_fragment_shader db "shaders/player/debug_normal.fag",0
	
	block_break_sound_path db "./sfx/ingame/block_break.wav",0
	block_place_sound_path db "./sfx/ingame/block_place.wav",0
	
	debug_normal_vertex_vector:
	dd 2
	dd 2
	dd 4
	dd debug_normal_vertex_data
	debug_normal_vertex_data:
	dd 0.0, 1.0
	
	debug_normal_index_vector:
	dd 2
	dd 2
	dd 4
	dd debug_normal_index_data
	debug_normal_index_data:
	dd 0, 1
	
	debug_normal_length dd 1.0
	debug_normal_directions:
	dd 1.0, 0.0, 0.0, 0.0
	dd -1.0, 0.0, 0.0, 0.0
	dd 0.0, 1.0, 0.0, 0.0
	dd 0.0, -1.0, 0.0, 0.0
	dd 0.0, 0.0, 1.0, 0.0
	dd 0.0, 0.0, -1.0, 0.0
	dd 0.0, 0.0, 0.0, 1.0
	dd 0.0, 0.0, 0.0, -1.0
	
	uniform_debug_normal_lineStart_name db "lineStart",0
	uniform_debug_normal_lineDirection_name db "lineDirection",0
	
	
	print_int_nl db "%d",10,0
	print_four_ints_nl db "%d %d %d %d",10,0
	print_two_floats db "%f %f",10,0
	test_text db "big chungus",10,0
	
	print_raycast_collider_pos db "raycast hit at: (%f, %f, %f, %f)",10,0
	print_raycast_no_hit db "kein raycast hit",10,0
	

section .text use32

	global player_init					;player* player_init(camera* cum, ChunkManager4D* chunkManager)
	global player_destroy				;void player_destroy(player* player)
	global player_update 				;void player_update(player* player, float deltaTime)
	global player_updatePhysics			;void player_updatePhysics(player* player, float deltaTime)
	global player_lookDirection			;void player_lookDirection(player* player, vec4* buffer)
	global player_drawRaycastHypercube	;void player_drawRaycastHypercube(Player* player, mat4* pv)
	
	extern my_malloc
	extern my_free
	extern my_printf
	extern my_memcpy
	
	extern math_clamp
	extern math_repeat
	extern math_basedLerp
	
	extern vec3_normalize
	extern vec3_scale
	extern vec3_add
	extern vec3_sub
	extern vec3_print
	
	extern vec4_add
	extern vec4_sub
	extern vec4_scale
	extern vec4_print
	
	extern camera_forward
	extern camera_right
	
	extern input_keyHeld
	extern input_mouseButtonReleased
	extern input_mouseDeltaPosition
	extern input_mouseScrollDelta
	extern GLFW_KEY_W
	extern GLFW_KEY_A
	extern GLFW_KEY_S
	extern GLFW_KEY_D
	extern GLFW_KEY_SPACE
	extern GLFW_KEY_LEFT_SHIFT
	extern GLFW_MOUSE_BUTTON_LEFT
	extern GLFW_MOUSE_BUTTON_RIGHT
	
	extern AABB4D_POS_X
	extern AABB4D_NEG_X
	extern AABB4D_POS_Y
	extern AABB4D_NEG_Y
	extern AABB4D_POS_Z
	extern AABB4D_NEG_Z
	extern AABB4D_POS_W
	extern AABB4D_NEG_W
	extern aabb4d_create
	extern aabb4d_destroy
	extern aabb4d_getPosition
	extern aabb4d_getVelocity
	extern aabb4d_setHyperPlane
	extern physics4d_registerNonkinematic
	extern physics4d_unregisterNonkinematic
	extern physics4d_raycastColliderGroup
	
	extern mutex_create
	extern mutex_destroy
	extern mutex_lock
	extern mutex_unlock
	
	extern hyperPlane_moveInsideOfPlane
	extern hyperPlane_rotate
	extern hyperPlane_directionTo3d
	extern hyperPlane_directionTo4d
	extern hyperPlane_positionTo3d
	extern hyperPlane_positionTo4d
	
	extern BLOCK_AIR
	extern BLOCK_STONE
	extern chunk4d_vec4ToBlockPos
	extern chunkManager4d_getHyperPlane
	extern chunkManager4d_setHyperPlane
	extern chunkManager4d_registerChangedBlock
	
	extern renderable_createCustom
	extern renderable_destroy
	extern renderable_renderCustom
	extern renderable_setUniform
	extern renderable_setAlbedo
	extern renderable_createShader
	extern renderable_destroyShader
	extern renderable_useShader
	extern renderable_setPrimitive
	extern renderable_enableBlending
	extern renderable_enableDepthTest
	extern renderable_setDepthFunc
	extern hyperCubeRenderable_create
	extern hyperCubeRenderable_destroy
	extern hyperCubeRenderable_render
	extern RENDERABLE_UNIFORM_VEC3
	
	extern GL_POINTS
	extern GL_LINES
	extern GL_TRIANGLES
	extern GL_LESS
	extern GL_LEQUAL
	
	extern input_keyHeld
	extern GLFW_KEY_C
	
	extern sigmaudio_import
	extern sigmaudio_deport
	extern sigmaudio_play
	
player_init:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;player*
	
	push 72
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;initialize camera and orientation
	mov ecx, dword[ebp+8]
	mov dword[eax], ecx
	
	mov dword[eax+4], 0
	mov dword[eax+8], 0
	mov dword[eax+12], 0
	mov dword[eax+16], 0
	mov dword[eax+20], 0
	
	;create and register collider
	push START_SCALE
	push START_POSITION
	call aabb4d_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+24], eax
	
	push eax
	call physics4d_registerNonkinematic
	
	;init previous collider position
	mov eax, dword[ebp-4]
	push dword[eax+24]
	call aabb4d_getPosition
	add esp, 4
	
	push dword[eax]
	push dword[eax+4]
	push dword[eax+8]
	push dword[eax+12]
	mov eax, dword[ebp-4]
	pop dword[eax+48]
	pop dword[eax+44]
	pop dword[eax+40]
	pop dword[eax+36]
	
	;initialize hyperPlane stuff
	mov eax, dword[ebp-4]
	mov ecx, dword[ebp+12]
	mov dword[eax+28], ecx			;ChunkManager*
	
	;set the aabb4d hyperplane
	mov eax, dword[ebp-4]
	push dword[eax+28]
	call chunkManager4d_getHyperPlane
	push eax
	call aabb4d_setHyperPlane
	add esp, 8
	
	;create raycast hypercube
	call hyperCubeRenderable_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+52], eax
	
	push raycast_hypercube_texture
	push eax
	call renderable_setAlbedo
	add esp, 8
	
	;create raycast debug normal renderable and shader
	push 0
	push 1
	push 1
	push debug_normal_index_vector
	push debug_normal_vertex_vector
	call renderable_createCustom
	mov ecx, dword[ebp-4]
	mov dword[ecx+64], eax
	add esp, 20
	
	push 0
	push debug_normal_fragment_shader
	push debug_normal_vertex_shader
	call renderable_createShader
	mov ecx, dword[ebp-4]
	mov dword[ecx+68], eax
	add esp, 12
	
	;init raycast info
	mov eax, dword[ebp-4]
	mov dword[eax+56], 0
	mov dword[eax+60], 0
	
	;import sounds
	push block_break_sound_path
	call sigmaudio_import
	push block_place_sound_path
	call sigmaudio_import
	add esp, 8
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
player_destroy:
	push ebp
	mov ebp, esp
	
	;unregister and destroy collider
	push 69
	mov eax, dword[ebp+8]
	push dword[eax+24]
	call physics4d_unregisterNonkinematic
	
	;destory raycast hypercube, debug normal and shader
	mov eax, dword[ebp+8]
	push dword[eax+52]
	call hyperCubeRenderable_destroy
	
	mov eax, dword[ebp+8]
	push dword[eax+64]
	call renderable_destroy
	
	mov eax, dword[ebp+8]
	push dword[eax+68]
	call renderable_destroyShader
	
	;dealloc
	push dword[ebp+8]
	call my_free
	
	;unload sounds
	push block_break_sound_path
	call sigmaudio_deport
	push block_place_sound_path
	call sigmaudio_deport
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
	
player_update:
	push ebp
	mov ebp, esp
	
	;check for block break and place
	push dword[ebp+8]
	call player_breakBlock
	call player_placeBlock
	add esp, 4
	
	;check for hyperplane rotation
	push dword[ebp+8]
	call player_rotatePlane
	add esp, 4
	
	;process mouse movement
	push dword[ebp+12]
	push dword[ebp+8]
	call player_look
	add esp, 8
	
	;zoom
	push dword[ebp+12]
	push dword[ebp+8]
	call player_optifineZoom
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	
	
player_updatePhysics:
	push ebp
	mov ebp, esp
	
	;move player
	push dword[ebp+12]
	push dword[ebp+8]
	call player_move
	add esp, 8
	
	push dword[ebp+12]
	push dword[ebp+8]
	;call player_applyGravity
	add esp, 8
	
	push dword[ebp+8]
	call player_gaycast
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	

player_lookDirection:
	push ebp
	mov ebp, esp
	
	sub esp, 12			;player forward in 3d		12
	sub esp, 4			;hyperplane address			16
	
	;get the player's look direction in 3d
	lea eax, dword[ebp-12]
	push eax
	mov eax, dword[ebp+8]
	push dword[eax]
	call camera_forward
	add esp, 8
	
	;convert it to 4d
	mov eax, dword[ebp+8]
	push dword[eax+28]
	call chunkManager4d_getHyperPlane
	mov dword[ebp-16], eax
	add esp, 4
	
	push dword[ebp+12]
	lea eax, [ebp-12]
	push eax
	push dword[ebp-16]
	call hyperPlane_directionTo4d
	add esp, 8
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
;void player_drawRaycastHypercube(Player* player, mat4* pv)
player_drawRaycastHypercube:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;hyperplane			4
	sub esp, 4				;vec4* normalDir	8
	sub esp, 16				;lineStart4d		24
	sub esp, 16				;lineDirection4d	40
	
	;check if there was a hit
	mov eax, dword[ebp+8]
	cmp dword[eax+56], 0
	je player_drawRaycastHypercube_end
	
	;get hyperplane
	mov eax, dword[ebp+8]
	push dword[eax+28]
	call chunkManager4d_getHyperPlane
	mov dword[ebp-4], eax
	add esp, 4
	
	;set primitive to point
	push dword[GL_POINTS]
	call renderable_setPrimitive
	add esp, 4
	
	;enable blending
	push 69
	call renderable_enableBlending
	add esp, 4
	
	;set depth function to lequal
	push dword[GL_LEQUAL]
	call renderable_setDepthFunc
	add esp, 4
	
	;draw the hypercube
	mov eax, dword[ebp+8]
	push 0					;use default shader
	push dword[eax+56]
	push dword[ebp-4]
	push dword[ebp+12]
	push dword[eax+52]
	call hyperCubeRenderable_render
	add esp, 16
	
	
	jmp player_drawRaycastHypercube_skip_normal
	
		;draw the debug normal
		;get the normal direction
		mov dword[ebp-8], debug_normal_directions
		mov eax, dword[ebp+8]
		mov eax, dword[eax+60]		;raycast direction in eax
		mov ecx, 1					;mask in ecx
		player_drawRaycastHypercube_normal_loop_start:
			test eax, ecx
			jnz player_drawRaycastHypercube_normal_loop_end
			
			add dword[ebp-8], 16
			shl ecx, 1
			jmp player_drawRaycastHypercube_normal_loop_start
			
		player_drawRaycastHypercube_normal_loop_end:
		
		;calculate lineStart
		lea eax, [ebp-24]
		push eax
		mov eax, dword[ebp+8]
		push dword[eax+56]
		push dword[ebp-4]
		call hyperPlane_positionTo3d
		add esp, 12
		
		;calculate lineDirection
		push dword[debug_normal_length]
		push dword[ebp-8]
		lea eax, [ebp-40]
		push eax
		call vec4_scale

		lea eax, [ebp-40]
		push eax
		push eax
		push dword[ebp-4]
		call hyperPlane_directionTo3d
		add esp, 24
		
		
		;set uniforms
		mov eax, dword[ebp+8]
		push dword[eax+68]
		call renderable_useShader
		add esp, 4
		
		push dword[ebp-16]
		push dword[ebp-20]
		push dword[ebp-24]
		push dword[RENDERABLE_UNIFORM_VEC3]
		push uniform_debug_normal_lineStart_name
		mov eax, dword[ebp+8]
		push dword[eax+68]
		call renderable_setUniform
		add esp, 24
		
		push dword[ebp-32]
		push dword[ebp-36]
		push dword[ebp-40]
		push dword[RENDERABLE_UNIFORM_VEC3]
		push uniform_debug_normal_lineDirection_name
		mov eax, dword[ebp+8]
		push dword[eax+68]
		call renderable_setUniform
		add esp, 24
		
		;actually draw the line
		push dword[GL_LINES]
		call renderable_setPrimitive
		add esp, 4
		
		push 0
		mov eax, dword[ebp+8]
		push dword[eax+68]
		push dword[ebp+12]
		push dword[eax+64]
		call renderable_renderCustom
		add esp, 16
		
	player_drawRaycastHypercube_skip_normal:
	
	;set depth function to less
	push dword[GL_LESS]
	call renderable_setDepthFunc
	add esp, 4
	
	;disable blending
	push 0
	call renderable_enableBlending
	add esp, 4
	
	;set primitive to triangles
	push dword[GL_TRIANGLES]
	call renderable_setPrimitive
	add esp, 4
	
	player_drawRaycastHypercube_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;internal functions
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
	
	
player_move:		;void player_move(player* player, float deltaTime)
	push ebp
	mov ebp, esp
	
	sub esp, 16		;collider velocity					16
	sub esp, 16		;forward vector scaled				32
	sub esp, 16		;right vector scaled				48
	sub esp, 16		;up vector scaled					64
	sub esp, 12		;camera position 3d					76
	
	;copy collider velocity y
	mov eax, dword[ebp+8]
	push dword[eax+24]
	call aabb4d_getVelocity
	add esp, 4
	
	mov dword[ebp-16], 0
	mov ecx, dword[eax+4]
	mov dword[ebp-12], ecx
	mov dword[ebp-8], 0
	mov dword[ebp-4], 0
	
	;get and scale forward
	mov eax, dword[ebp+8]
	mov eax, dword[eax]		;camera* in eax
	lea ecx, [ebp-32]
	
	push ecx
	push eax
	call camera_forward
	add esp, 8
	
	mov dword[ebp-28], 0		;zero the y component
	lea ecx, [ebp-32]
	push ecx
	call vec3_normalize
	add esp, 4
	
	lea ecx, [ebp-32]
	push dword[MOVEMENT_SPEED]
	push ecx
	push ecx
	call vec3_scale
	add esp, 12
	
	mov eax, dword[ebp+8]
	push dword[eax+28]
	call chunkManager4d_getHyperPlane
	add esp, 4
	lea ecx, [ebp-32]
	push ecx
	push ecx
	push eax
	call hyperPlane_directionTo4d
	add esp, 12
	
	;get and scale right
	mov eax, dword[ebp+8]
	mov eax, dword[eax]		;camera* in eax
	lea ecx, [ebp-48]
	
	push ecx
	push eax
	call camera_right
	add esp, 8
	
	lea ecx, [ebp-48]
	push dword[MOVEMENT_SPEED]
	push ecx
	push ecx
	call vec3_scale
	add esp, 12
	
	mov eax, dword[ebp+8]
	push dword[eax+28]
	call chunkManager4d_getHyperPlane
	add esp, 4
	lea ecx, [ebp-48]
	push ecx
	push ecx
	push eax
	call hyperPlane_directionTo4d
	add esp, 12
	
	
	;check for keyboard input
	push dword[GLFW_KEY_W]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_w
		lea ecx, [ebp-16]		;&collider.velocity
		lea edx, [ebp-32]		;&player_forward
		push edx
		push ecx
		push ecx
		call vec4_add
		add esp, 12
	player_move_not_w:
	
	push dword[GLFW_KEY_S]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_s
		lea ecx, [ebp-16]		;&collider.velocity
		lea edx, [ebp-32]		;&player_forward
		push edx
		push ecx
		push ecx
		call vec4_sub
		add esp, 12
	player_move_not_s:
	
	push dword[GLFW_KEY_D]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_d
		lea ecx, [ebp-16]		;&collider.velocity
		lea edx, [ebp-48]		;&player_right
		push edx
		push ecx
		push ecx
		call vec4_add
		add esp, 12
	player_move_not_d:
	
	push dword[GLFW_KEY_A]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_a
		lea ecx, [ebp-16]		;&collider.velocity
		lea edx, [ebp-48]		;&player_right
		push edx
		push ecx
		push ecx
		call vec4_sub
		add esp, 12
	player_move_not_a:
	
	mov dword[ebp-12], 0
	
	push dword[GLFW_KEY_SPACE]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_space
		movss xmm0, dword[MOVEMENT_SPEED]
		movss xmm1, dword[ebp-12]
		addss xmm1, xmm0
		movss dword[ebp-12], xmm1
	player_move_not_space:
	
	
	push dword[GLFW_KEY_LEFT_SHIFT]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_left_shift
		movss xmm0, dword[MOVEMENT_SPEED]
		movss xmm1, dword[ebp-12]
		subss xmm1, xmm0
		movss dword[ebp-12], xmm1
	player_move_not_left_shift:
	
	
	;copy back the values into player.collider.velocity
	mov eax, dword[ebp+8]
	push dword[eax+24]
	call aabb4d_getVelocity
	add esp, 4
	
	mov ecx, dword[ebp-16]
	mov dword[eax], ecx
	mov ecx, dword[ebp-12]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+8], ecx
	mov ecx, dword[ebp-4]
	mov dword[eax+12], ecx
	
	;update the position of the camera (with the eye offset)
	mov eax, dword[ebp+8]
	push dword[eax+24]
	call aabb4d_getPosition
	add esp, 4
	
	lea ecx, [ebp-76]
	push ecx
	push eax
	
	mov ecx, dword[ebp+8]
	push dword[ecx+28]
	call chunkManager4d_getHyperPlane
	add esp, 4
	push eax
	
	call hyperPlane_positionTo3d
	
	lea eax, [ebp-76]
	push EYE_OFFSET
	push eax
	push eax
	call vec3_add
	add esp, 12
	
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	mov ecx, dword[ebp-76]
	mov dword[eax], ecx
	mov ecx, dword[ebp-72]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp-68]
	mov dword[eax+8], ecx
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
;void player_applyGravity(player* pplayer, float deltaTime)
player_applyGravity:
	push ebp
	mov ebp, esp
	
	movss xmm1, dword[ebp+12]
	movss xmm0, dword[GRAV_ACC]
	mulss xmm1, xmm0
	
	mov eax, dword[ebp+8]
	push dword[eax+24]
	call aabb4d_getVelocity
	movss xmm0, dword[eax+4]	;player.collider.velocity.y
	
	addss xmm0, xmm1
	movss dword[eax+4], xmm0
	
	mov esp, ebp
	pop ebp
	ret
	
player_look:		;void player_look(player* pplayer, float deltaTime)
	push ebp
	mov ebp, esp
	
	sub esp, 4		;pitch
	sub esp, 4		;yaw
	sub esp, 4		;delta pitch
	sub esp, 4		;delta yaw
	
	;copy the old values
	mov eax, dword[ebp+8]		;player* in eax
	mov ecx, dword[eax+16]
	mov dword[ebp-4], ecx
	mov ecx, dword[eax+20]
	mov dword[ebp-8], ecx
	
	
	;calculate the delta and new values
	lea eax, [ebp-12]
	lea ecx, [ebp-16]
	push eax
	push ecx
	call input_mouseDeltaPosition
	add esp, 8
	
	
	fild dword[ebp-12]
	fstp dword[ebp-12]
	fild dword[ebp-16]
	fstp dword[ebp-16]
	
	
	movss xmm0, dword[LOOK_SENSITIVITY_X]
	movss xmm2, dword[ebp-12]
	mulss xmm2, xmm0
	addss xmm2, dword[ebp-4]
	movss dword[ebp-4], xmm2
	
	push dword[POS_88P9]
	push dword[NEG_88P9]
	push dword[ebp-4]
	call math_clamp
	fstp dword[ebp-4]
	add esp, 12
	
	
	
	movss xmm0, dword[LOOK_SENSITIVITY_Y]
	movss xmm2, dword[ebp-16]
	mulss xmm2, xmm0
	addss xmm2, dword[ebp-8]
	movss dword[ebp-8], xmm2
	
	push dword[POS_360]
	push dword[ebp-8]
	call math_repeat
	fstp dword[ebp-8]
	add esp, 8
	
	
	;set the values of the player
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	mov dword[eax+16], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+20], ecx
	
	;set the values of the camera as well
	mov eax, dword[ebp+8]			;player* in eax
	mov eax, dword[eax]			;camera* in eax
	
	mov ecx, dword[ebp-4]
	mov dword[eax+12], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+16], ecx
	
	player_look_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
;void player_rotatePlane(Player* player)
player_rotatePlane:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;delta scroll x			4
	sub esp, 4			;delta scroll y			8
	
	sub esp, 4			;rotation angle			12
	
	sub esp, 64			;hyperplane				76
	
	
	;obtain scroll delta
	lea eax, [ebp-8]
	push eax
	lea eax, [ebp-4]
	push eax
	call input_mouseScrollDelta
	
	;is the delta scroll 0?
	cmp dword[ebp-8], 0
	je player_rotatePlane_end
	
	;calculate rotation angle
	fild dword[ebp-8]
	fld dword[HYPERPLANE_ROTATION_ANGLE]
	fmulp
	fstp dword[ebp-12]
	
	;update the hyperplane point
	;the hyperplane's new center is the players position in 4d, which is the players movement since the last rotation event
	mov eax, dword[ebp+8]
	push dword[eax+24]
	call aabb4d_getPosition
	push eax					;save aabb.position
	
	mov ecx, dword[ebp+8]
	push dword[ecx+28]
	call chunkManager4d_getHyperPlane
	push 64
	push eax
	lea ecx, [ebp-76]
	push ecx
	call my_memcpy
	add esp, 16
	
	pop ecx						;restore aabb.position
	lea eax, [ebp-76]
	
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	mov edx, dword[ecx+8]
	mov dword[eax+8], edx
	mov edx, dword[ecx+12]
	mov dword[eax+12], edx
	
	;set the camera's position to EYE_OFFSET, as the new center of the 3D space is the player
	mov ecx, dword[ebp+8]
	mov ecx, dword[ecx]
	
	mov eax, EYE_OFFSET
	mov edx, dword[eax]
	mov dword[ecx], edx
	mov edx, dword[eax+4]
	mov dword[ecx+4], edx
	mov edx, dword[eax+8]
	mov dword[ecx+8], edx
	
	
	;rotate plane
	push dword[ebp-12]
	push HYPERPLANE_ROTATION_VECTOR_2
	push HYPERPLANE_ROTATION_VECTOR_1
	lea eax, [ebp-76]
	push eax
	call hyperPlane_rotate
	pop eax					;restore hyperplane
	add esp, 12
	
	;set the aabb4d's hyperplane
	push eax
	call aabb4d_setHyperPlane
	add esp, 4
	
	;set the chunk manager's hyperplane
	mov eax, dword[ebp+8]
	mov eax, dword[eax+28]
	lea ecx, [ebp-76]
	push ecx
	push eax
	call chunkManager4d_setHyperPlane
	
	player_rotatePlane_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;void player_gaycast(player* player)
player_gaycast:
	push ebp
	mov ebp, esp
	
	sub esp, 16			;player position				16
	sub esp, 16			;player look direction			32
	sub esp, 4			;raycast hit collider			36
	sub esp, 4			;raycast hit direction			40
	sub esp, 4			;hyperplane address				44
	
	;get the hyperplane
	mov eax, dword[ebp+8]
	push dword[eax+28]
	call chunkManager4d_getHyperPlane
	mov dword[ebp-44], eax
	add esp, 4
	
	;get the player's position
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	lea ecx, dword[ebp-16]
	push ecx
	push eax
	push dword[ebp-44]
	call hyperPlane_positionTo4d
	add esp, 12
	
	;get the player's look direction
	lea eax, [ebp-32]
	push eax
	push dword[ebp+8]
	call player_lookDirection
	add esp, 8
	
	;cast the gay
	lea eax, [ebp-40]
	push eax
	lea eax, [ebp-36]
	push eax
	push dword[RAYCAST_MAX_DISTANCE]
	lea eax, [ebp-32]
	push eax
	lea eax, [ebp-16]
	push eax
	call physics4d_raycastColliderGroup
	add esp, 20
	
	;was there a hit
	cmp eax, 0
	je player_raycast_no_hit
		mov ecx, dword[ebp+8]
		mov eax, dword[ebp-36]
		mov dword[ecx+56], eax
		mov eax, dword[ebp-40]
		mov dword[ecx+60], eax
		jmp player_raycast_end
	
	player_raycast_no_hit:
		mov ecx, dword[ebp+8]
		mov dword[ecx+56], 0
		mov dword[ecx+60], 0
		jmp player_raycast_end
	
	player_raycast_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;void player_breakBlock(Player* player)
player_breakBlock:
	push ebp
	mov ebp, esp
	
	sub esp, 16		;ivec4 chunkLocalBlockPos		16
	sub esp, 12		;ivec3 chunkPos					28
	
	
	;check if there the raycast hit anything
	mov eax, dword[ebp+8]
	cmp dword[eax+56], 0
	je player_breakBlock_end
	
	;check if there was a mouse click
	push dword[GLFW_MOUSE_BUTTON_LEFT]
	call input_mouseButtonReleased
	add esp, 4
	test eax, eax
	jz player_breakBlock_end
	
	;calculate the block pos
	lea eax, [ebp-16]
	push eax
	lea eax, [ebp-28]
	push eax
	mov eax, dword[ebp+8]
	push dword[eax+56]
	call chunk4d_vec4ToBlockPos
	add esp, 12
	
	;register the changed block
	push 69					;has priority
	lea eax, [ebp-16]
	push eax
	lea eax, [ebp-28]
	push eax
	xor ecx, ecx
	mov cl, byte[BLOCK_AIR]
	push ecx
	mov eax, dword[ebp+8]
	push dword[eax+28]
	call chunkManager4d_registerChangedBlock
	add esp, 20
	
	;play the sound
	push 0
	push 1
	push block_break_sound_path
	call sigmaudio_play
	
	player_breakBlock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;void player_placeBlock(Player* player)
player_placeBlock:
	push ebp
	mov ebp, esp
	
	sub esp, 16		;block position vec4			16
	sub esp, 16		;ivec4 chunkLocalBlockPos		32
	sub esp, 12		;ivec3 chunkPos					44
	
	
	;check if there the raycast hit anything
	mov eax, dword[ebp+8]
	cmp dword[eax+56], 0
	je player_placeBlock_end
	
	;check if there was a mouse click
	push dword[GLFW_MOUSE_BUTTON_RIGHT]
	call input_mouseButtonReleased
	add esp, 4
	test eax, eax
	jz player_placeBlock_end
	
	;copy the collider position
	mov eax, dword[ebp+8]
	mov eax, dword[eax+56]
	
	mov ecx, dword[eax]
	mov dword[ebp-16], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-12], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-8], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-4], ecx
	
	;set the block position
	mov eax, dword[ebp+8]
	mov eax, dword[eax+60]		;raycast direction in eax
	movss xmm1, dword[ONE]
	
	cmp eax, dword[AABB4D_POS_X]
	jne player_placeBlock_direction_not_pos_x
		movss xmm0, dword[ebp-16]
		addss xmm0, xmm1
		movss dword[ebp-16], xmm0
		jmp player_placeBlock_direction_done
	player_placeBlock_direction_not_pos_x:
	cmp eax, dword[AABB4D_NEG_X]
	jne player_placeBlock_direction_not_neg_x
		movss xmm0, dword[ebp-16]
		subss xmm0, xmm1
		movss dword[ebp-16], xmm0
		jmp player_placeBlock_direction_done
	player_placeBlock_direction_not_neg_x:
	cmp eax, dword[AABB4D_POS_Y]
	jne player_placeBlock_direction_not_pos_y
		movss xmm0, dword[ebp-12]
		addss xmm0, xmm1
		movss dword[ebp-12], xmm0
		jmp player_placeBlock_direction_done
	player_placeBlock_direction_not_pos_y:
	cmp eax, dword[AABB4D_NEG_Y]
	jne player_placeBlock_direction_not_neg_y
		movss xmm0, dword[ebp-12]
		subss xmm0, xmm1
		movss dword[ebp-12], xmm0
		jmp player_placeBlock_direction_done
	player_placeBlock_direction_not_neg_y:
	cmp eax, dword[AABB4D_POS_Z]
	jne player_placeBlock_direction_not_pos_z
		movss xmm0, dword[ebp-8]
		addss xmm0, xmm1
		movss dword[ebp-8], xmm0
		jmp player_placeBlock_direction_done
	player_placeBlock_direction_not_pos_z:
	cmp eax, dword[AABB4D_NEG_Z]
	jne player_placeBlock_direction_not_neg_z
		movss xmm0, dword[ebp-8]
		subss xmm0, xmm1
		movss dword[ebp-8], xmm0
		jmp player_placeBlock_direction_done
	player_placeBlock_direction_not_neg_z:
	cmp eax, dword[AABB4D_POS_W]
	jne player_placeBlock_direction_not_pos_w
		movss xmm0, dword[ebp-4]
		addss xmm0, xmm1
		movss dword[ebp-4], xmm0
		jmp player_placeBlock_direction_done
	player_placeBlock_direction_not_pos_w:
	cmp eax, dword[AABB4D_NEG_W]
	jne player_placeBlock_direction_not_neg_w
		movss xmm0, dword[ebp-4]
		subss xmm0, xmm1
		movss dword[ebp-4], xmm0
		jmp player_placeBlock_direction_done
	player_placeBlock_direction_not_neg_w:
	
	player_placeBlock_direction_done:
	
	
	;calculate the block pos
	lea eax, [ebp-32]
	push eax
	lea eax, [ebp-44]
	push eax
	lea eax, [ebp-16]
	push eax
	call chunk4d_vec4ToBlockPos
	add esp, 12
	
	;register the changed block
	push 69							;has priority
	lea eax, [ebp-32]
	push eax
	lea eax, [ebp-44]
	push eax
	xor ecx, ecx
	mov cl, byte[BLOCK_STONE]
	push ecx
	mov eax, dword[ebp+8]
	push dword[eax+28]
	call chunkManager4d_registerChangedBlock
	add esp, 20
	
	;play the sound
	push 0
	push 1
	push block_place_sound_path
	call sigmaudio_play
	
	player_placeBlock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;void player_optifineZoom(Player* player, float deltaTime)
player_optifineZoom:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;fov				;4
	sub esp, 4			;target fov			;8
	
	;get current fov
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	mov eax, dword[eax+28]
	mov dword[ebp-4], eax
	
	;get target fov
	push dword[GLFW_KEY_C]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jnz player_optifineZoom_target_zoom
		mov ecx, dword[CUM_NORMAL_FOV]
		jmp player_optifineZoom_target_done
	player_optifineZoom_target_zoom:
		mov ecx, dword[CUM_ZOOM_FOV]
	player_optifineZoom_target_done:
	mov dword[ebp-8], ecx
	
	;calculate fov
	push dword[ebp+12]
	push dword[CUM_FOV_INTERPOLATION_STRENGTH]
	push dword[ebp-8]
	push dword[ebp-4]
	call math_basedLerp
	fstp dword[ebp-4]
	add esp, 16
	
	;change camera fov
	mov eax, dword[ebp+8]
	mov eax, dword[eax]
	mov ecx, dword[ebp-4]
	mov dword[eax+28], ecx
	
	mov esp, ebp
	pop ebp
	ret