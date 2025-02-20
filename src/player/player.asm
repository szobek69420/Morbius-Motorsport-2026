[BITS 32]

;layout:
;struct player{
;	camera* cum;			0
;	vec3 position;			4 (unused)
;	float pitch, yaw;		16
;	Collider* collider;		24
;}		28 bytes

section .rodata use32
	ZERO dd 0.0
	ONE dd 1.0
	MINUS_ONE dd -1.0
	
	GRAV_ACC dd -9.80625
	
	UP dd 0.0, 1.0, 0.0
	DOWN dd 0.0, -1.0, 0.0
	
	LOOK_SENSITIVITY_X dd -0.03
	LOOK_SENSITIVITY_Y dd 0.03
	
	COLLIDER_HEIGHT dd 0.9
	COLLIDER_RADIUS dd 0.12
	
	EYE_OFFSET dd 0.0, 0.75, 0.0		;the offset of the camera from the center of the collider
	
	MOVEMENT_SPEED dd 5.0
	
	print_two_floats db "%f %f",10,0
	test_text db "big chungus",10,0

section .text use32

	global player_init				;player* player_init(camera* cum)
	global player_destroy			;void player_destroy(player* player)
	global player_update 			;void player_update(player* player, float deltaTime)
	global player_updatePhysics		;void player_updatePhysics(player* player, float deltaTime)
	
	extern my_malloc
	extern my_free
	extern my_printf
	
	extern vec3_normalize
	extern vec3_scale
	extern vec3_add
	extern vec3_sub
	extern vec3_print
	
	extern camera_forward
	extern camera_right
	
	extern input_keyHeld
	extern input_mouseDeltaPosition
	extern GLFW_KEY_W
	extern GLFW_KEY_A
	extern GLFW_KEY_S
	extern GLFW_KEY_D
	extern GLFW_KEY_SPACE
	extern GLFW_KEY_LEFT_SHIFT
	
	extern collider_createCylinder
	extern collider_destroy
	extern physics_registerNonkinematic
	extern physics_unregisterNonkinematic
	
player_init:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;player*
	
	push 28
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;initialize it
	mov ecx, dword[ebp+8]
	mov dword[eax], ecx
	
	mov dword[eax+4], 0
	mov dword[eax+8], 0
	mov dword[eax+12], 0
	mov dword[eax+16], 0
	mov dword[eax+20], 0
	
	;create and register collider
	push dword[COLLIDER_RADIUS]
	push dword[COLLIDER_HEIGHT]
	call collider_createCylinder
	mov ecx, dword[ebp-4]
	mov dword[ecx+24], eax
	
	
	push eax
	call physics_registerNonkinematic
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
player_destroy:
	push ebp
	mov ebp, esp
	
	;unregister and destroy collider
	mov eax, dword[ebp+8]
	push dword[eax+24]
	call physics_unregisterNonkinematic
	call collider_destroy
	
	;dealloc
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
player_update:
	push ebp
	mov ebp, esp
	
	push dword[ebp+12]
	push dword[ebp+8]
	call player_look
	add esp, 8
	
	mov esp, ebp
	pop ebp
	ret
	
player_updatePhysics:
	push ebp
	mov ebp, esp
	
	push dword[ebp+12]
	push dword[ebp+8]
	call player_move
	add esp, 8
	
	push dword[ebp+12]
	push dword[ebp+8]
	call player_applyGravity
	add esp, 8
	
	mov eax, dword[ebp+8]
	push dword[eax+24]
	;call vec3_print
	
	mov esp, ebp
	pop ebp
	ret
	
	
player_move:		;void player_move(player* player, float deltaTime)
	push ebp
	mov ebp, esp
	
	sub esp, 12		;collider velocity
	sub esp, 12		;forward vector scaled
	sub esp, 12		;right vector scaled
	sub esp, 12		;up vector scaled
	
	;copy collider velocity
	mov eax, dword[ebp+8]		;player* in eax
	mov eax, dword[eax+24]		;collider* in eax
	mov dword[ebp-12], 0
	mov ecx, dword[eax+36]
	mov dword[ebp-8], ecx		;collider.velocity.y
	mov ecx, dword[eax+12]
	mov dword[ebp-4], 0
	
	;get and scale forward
	mov eax, dword[ebp+8]
	mov eax, dword[eax]		;camera* in eax
	lea ecx, [ebp-24]
	
	push ecx
	push eax
	call camera_forward
	add esp, 8
	
	mov dword[ebp-20], 0		;zero the y component
	lea ecx, [ebp-24]
	push ecx
	call vec3_normalize
	add esp, 4
	
	lea ecx, [ebp-24]
	push dword[MOVEMENT_SPEED]
	push ecx
	push ecx
	call vec3_scale
	add esp, 12
	
	;get and scale right
	mov eax, dword[ebp+8]
	mov eax, dword[eax]		;camera* in eax
	lea ecx, [ebp-36]
	
	push ecx
	push eax
	call camera_right
	add esp, 8
	
	lea ecx, [ebp-36]
	push dword[MOVEMENT_SPEED]
	push ecx
	push ecx
	call vec3_scale
	add esp, 12
	
	
	;check for keyboard input
	push dword[GLFW_KEY_W]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_w
		lea ecx, [ebp-12]		;&collider.velocity
		lea edx, [ebp-24]		;&player_forward
		push edx
		push ecx
		push ecx
		call vec3_add
		add esp, 12
	player_move_not_w:
	
	push dword[GLFW_KEY_S]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_s
		lea ecx, [ebp-12]		;&collider.velocity
		lea edx, [ebp-24]		;&player_forward
		push edx
		push ecx
		push ecx
		call vec3_sub
		add esp, 12
	player_move_not_s:
	
	push dword[GLFW_KEY_D]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_d
		lea ecx, [ebp-12]		;&collider.velocity
		lea edx, [ebp-36]		;&player_right
		push edx
		push ecx
		push ecx
		call vec3_add
		add esp, 12
	player_move_not_d:
	
	push dword[GLFW_KEY_A]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_a
		lea ecx, [ebp-12]		;&collider.velocity
		lea edx, [ebp-36]		;&player_right
		push edx
		push ecx
		push ecx
		call vec3_sub
		add esp, 12
	player_move_not_a:
	
	push dword[GLFW_KEY_SPACE]
	call input_keyHeld
	add esp, 4
	test eax, eax
	jz player_move_not_space
		mov ecx, dword[MOVEMENT_SPEED]
		mov dword[ebp-8], ecx
	player_move_not_space:
	
	
	;copy back the values into player.collider.velocity
	mov eax, dword[ebp+8]
	mov eax, dword[eax+24]
	
	mov ecx, dword[ebp-12]
	mov dword[eax+32], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+36], ecx
	mov ecx, dword[ebp-4]
	mov dword[eax+40], ecx
	
	;update the position of the camera
	mov eax, dword[ebp+8]
	mov edx, dword[eax]			;&player.camera
	mov eax, dword[eax+24]		;&player.collider.position in eax
	
	mov ecx, dword[eax]
	mov dword[edx], ecx
	mov ecx, dword[eax+4]
	mov dword[edx+4], ecx
	mov ecx, dword[eax+8]
	mov dword[edx+8], ecx
	
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
	mov eax, dword[eax+24]
	movss xmm0, dword[eax+36]	;player.collider.velocity.y
	
	addss xmm0, xmm1
	movss dword[eax+36], xmm0
	
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
	
	movss xmm0, dword[LOOK_SENSITIVITY_Y]
	movss xmm2, dword[ebp-16]
	mulss xmm2, xmm0
	addss xmm2, dword[ebp-8]
	movss dword[ebp-8], xmm2
	
	
	;set the values of the player
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	mov dword[eax+16], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+20], ecx
	
	;set the values of the camera as well
	mov eax, dword[ebp+8]		;player* in eax
	mov eax, dword[eax]			;camera* in eax
	
	mov ecx, dword[ebp-4]
	mov dword[eax+12], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+16], ecx
	
	player_look_end:
	mov esp, ebp
	pop ebp
	ret