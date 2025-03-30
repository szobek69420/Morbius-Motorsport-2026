[BITS 32]

;layout:
;struct Aabb4D{
;	vec4 position;				;0
;	vec4 scale;					;16
;	vec4 velocity;				;32
;	int tag;					;48
;	Collider* lastCollision;	;52 //leider cannot handle multiple bonks
;	int lastCollisionDirection;	;56	//it is a bitmask for the collision directions, it can handle multiple bonks. it represents from which direction the collision happened
;};		60 bytes overall

section .rodata use32
	global AABB4D_POS_X
	global AABB4D_NEG_X
	global AABB4D_POS_Y
	global AABB4D_NEG_Y
	global AABB4D_POS_Z
	global AABB4D_NEG_Z
	global AABB4D_POS_W
	global AABB4D_NEG_W

	AABB4D_POS_X dd 0b00000001
	AABB4D_NEG_X dd 0b00000010
	AABB4D_POS_Y dd 0b00000100
	AABB4D_NEG_Y dd 0b00001000
	AABB4D_POS_Z dd 0b00010000
	AABB4D_NEG_Z dd 0b00100000
	AABB4D_POS_W dd 0b01000000
	AABB4D_NEG_W dd 0b10000000
	
	;deez have to have deez values
	RESOLUTION_DIR_POS_X dd 0
	RESOLUTION_DIR_NEG_X dd 1
	RESOLUTION_DIR_POS_Y dd 2
	RESOLUTION_DIR_NEG_Y dd 3
	RESOLUTION_DIR_POS_Z dd 4
	RESOLUTION_DIR_NEG_Z dd 5
	RESOLUTION_DIR_POS_W dd 6
	RESOLUTION_DIR_NEG_W dd 7
	
	NORMALIZED_POS_X dd 1.0, 0.0, 0.0, 0.0
	NORMALIZED_NEG_X dd -1.0, 0.0, 0.0, 0.0
	NORMALIZED_POS_Y dd 0.0, 1.0, 0.0, 0.0
	NORMALIZED_NEG_Y dd 0.0, -1.0, 0.0, 0.0
	NORMALIZED_POS_Z dd 0.0, 0.0, 1.0, 0.0
	NORMALIZED_NEG_Z dd 0.0, 0.0, -1.0, 0.0
	NORMALIZED_POS_W dd 0.0, 0.0, 0.0, 1.0
	NORMALIZED_NEG_W dd 0.0, 0.0, 0.0, -1.0
	
	
	EPSILON dd 0.000001
	HALF dd 0.5
	ONE dd 1.0
	MINUS_ONE dd -1.0
	VERY_BIG_NUMBER dd 69420.69420
	
	test_text db "cardiac house arrest",10,0
	test_text2 db "cardiac house arrest 2",10,0
	
section .data use32
	hyperplane_aabb4d:
	dd 0.0, 0.0, 0.0, 0.0
	dd 1.0, 0.0, 0.0, 0.0
	dd 0.0, 1.0, 0.0, 0.0
	dd 0.0, 0.0, 1.0, 0.0

section .text use32

	global aabb4d_create							;Aabb4D* aabb4d_create(vec4* position, vec4* scale)
	global aabb4d_destroy							;void aabb4d_destroy(Aabb4D* collider)
	
	global aabb4d_getPosition						;vec4* aabb4d_getPosition(Aabb4D* collider)
	global aabb4d_getVelocity						;vec4* aabb4d_getVelocity(Aabb4D* collider)
	
	;returns non-zero if there was a collision
	;sets the lastCollision and lastCollisionDetection variables if there was a collision
	;the resolutionDirection points in the direction in which the c1 should be moved (it is RESOLUTION_DIR_POS_X or etc.)
	;and the penetration is so much so that if only the c1 were to be moved, the collision would be resolved
	;int aabb4d_detectCollisionInternal(Aabb4D* c1, Aabb4D* c2, int* resolutionDirection, float* penetration)
	
	global aabb4d_resolveKinematicNonkinematic		;void aabb4d_resolveKinematicNonkinematic(Aabb4D* kinematic, Aabb4D* nonkinematic)
	global aabb4d_resolveNonkinematicNonkinematic	;void aabb4d_resolveNonkinematicNonkinematic(Aabb4D* kinematic, Aabb4D* nonkinematic)
	
	;pushes the return value onto the FPU stack
	;in case of penetration, it returns a negative value
	global aabb4d_calculateDistance					;float aabb4d_calculateDistance(Aabb4D* c1, Aabb4D* c2)
	
	;it is a state setting function
	global aabb4d_setHyperPlane				;void aabb4d_setHyperPlane(HyperPlane* hyperPlane)
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy
	
	extern vec4_add
	extern vec4_sub
	extern vec4_scale
	extern vec4_normalize
	extern vec4_dot
	
	extern hyperPlane_directionTo3d
	extern hyperPlane_directionTo4d
	
aabb4d_create:
	push ebp
	mov ebp, esp
	
	;alloc aabb
	push 60
	call my_malloc
	
	;set position
	mov ecx, dword[ebp+8]
	
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	mov edx, dword[ecx+8]
	mov dword[eax+8], edx
	mov edx, dword[ecx+12]
	mov dword[eax+12], edx
	
	;set scale
	mov ecx, dword[ebp+12]
	
	mov edx, dword[ecx]
	mov dword[eax+16], edx
	mov edx, dword[ecx+4]
	mov dword[eax+20], edx
	mov edx, dword[ecx+8]
	mov dword[eax+24], edx
	mov edx, dword[ecx+12]
	mov dword[eax+28], edx
	
	;set velocity
	mov dword[eax+32], 0
	mov dword[eax+36], 0
	mov dword[eax+40], 0
	mov dword[eax+44], 0
	
	;set tag
	mov dword[eax+48], 0
	
	;set last collision info
	mov dword[eax+52], 0
	mov dword[eax+56], 0
	
	mov esp, ebp
	pop ebp
	ret
	
	
aabb4d_destroy:
	mov eax, dword[esp+4]
	push eax
	call my_free
	add esp, 4
	ret
	
	
aabb4d_getPosition:
	mov eax, dword[esp+4]
	ret
	
aabb4d_getVelocity:
	mov eax, dword[esp+4]
	add eax, 32
	ret
	
aabb4d_calculateDistance:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;lower bound of c2 local to c1						16
	sub esp, 16				;upper bound of c2 local to c1						32
	
	sub esp, 4				;max distance										68
	
	;calculate c2 bounds
	sub esp, 12
	mov eax, dword[ebp+8]
	mov dword[esp+8], eax
	mov eax, dword[ebp+12]
	mov dword[esp+4], eax
	lea eax, [ebp-16]
	mov dword[esp], eax
	call vec4_sub
	add esp, 12
	
	
	sub esp, 12
	mov eax, dword[ebp+12]
	add eax, 16
	mov dword[esp+8], eax
	lea eax, [ebp-16]
	mov dword[esp+4], eax
	sub eax, 16
	mov dword[esp], eax
	call vec4_add
	add dword[esp], 16
	call vec4_sub
	add esp, 12
	
	
	
	;subtract c1.upperBound from c2.lowerBound (c2.lowerBound-c1.scale)
	;subtract c2.upperBound from c1.lowerBound ( -c1.scale-c2.upperBound = -(c2.upperBound+c1.scale) )	
	mov eax, dword[ebp+8]
	add eax, 16
	push eax
	lea eax, [ebp-16]
	push eax
	push eax
	call vec4_sub
	add esp, 12
	
	mov eax, dword[ebp+8]
	add eax, 16
	push eax
	lea eax, [ebp-32]
	push eax
	push eax
	call vec4_add
	add esp, 12
	xor dword[ebp-32], 0x80000000
	xor dword[ebp-28], 0x80000000
	xor dword[ebp-24], 0x80000000
	xor dword[ebp-20], 0x80000000
	
	;search for the highest distance
	mov eax, dword[VERY_BIG_NUMBER]
	xor eax, 0x80000000
	mov dword[ebp-68], eax
	
	mov eax, 8
	lea ecx, [ebp-32]
	aabb4d_calculateDistance_loop_start:
		movss xmm0, dword[ecx]
		ucomiss xmm0, dword[ebp-68]
		jbe aabb4d_calculateDistance_loop_continue
			movss dword[ebp-68], xmm0
			
		aabb4d_calculateDistance_loop_continue:
		add ecx, 4
		dec eax
		test eax, eax
		jnz aabb4d_calculateDistance_loop_start
		
	;set return value
	fld dword[ebp-68]
	
	mov esp, ebp
	pop ebp
	ret
	
	
aabb4d_resolveKinematicNonkinematic:
	push ebp
	mov ebp, esp
	
	sub esp, 4					;resolution direction											4
	sub esp, 4					;penetration													8
	sub esp, 4					;res dir scaler													12
	sub esp, 4					;unused															16
	sub esp, 16					;resolution direction in hyperplane								32
	sub esp, 4					;<normalize(resolution direction); nonkinematic.velocity>		36
	sub esp, 16					;velocity loss													52
	
	lea eax, [ebp-8]
	push eax
	lea eax, [ebp-4]
	push eax
	push dword[ebp+8]
	push dword[ebp+12]
	call aabb4d_detectCollisionInternal
	
	test eax, eax
	jz aabb4d_resolveKinematicNonkinematic_end		;no collision happened
	
	;get the resolution direction's projection to the hyperplane
	lea eax, [ebp-32]
	push eax
	mov eax, dword[ebp-4]
	shl eax, 4
	add eax, NORMALIZED_POS_X
	push eax
	push hyperplane_aabb4d
	call hyperPlane_directionTo3d
	
	lea eax, [ebp-32]
	push eax
	push eax
	push hyperplane_aabb4d
	call hyperPlane_directionTo4d
	
	;scale the resolution direction so that the original (4d) resolution happens right
	mov eax, dword[ebp-4]
	jmp dword[aabb4d_resolveKinematicNonkinematic_scaler+4*eax]
	aabb4d_resolveKinematicNonkinematic_scaler:
	dd aabb4d_resolveKinematicNonkinematic_scaler_x
	dd aabb4d_resolveKinematicNonkinematic_scaler_x
	dd aabb4d_resolveKinematicNonkinematic_scaler_y
	dd aabb4d_resolveKinematicNonkinematic_scaler_y
	dd aabb4d_resolveKinematicNonkinematic_scaler_z
	dd aabb4d_resolveKinematicNonkinematic_scaler_z
	dd aabb4d_resolveKinematicNonkinematic_scaler_w
	dd aabb4d_resolveKinematicNonkinematic_scaler_w
	aabb4d_resolveKinematicNonkinematic_scaler_x:
		fld dword[ebp-8]
		fld dword[ebp-32]
		fabs
		fdivp
		fstp dword[ebp-12]
		jmp aabb4d_resolveKinematicNonkinematic_scaler_done
		
	aabb4d_resolveKinematicNonkinematic_scaler_y:
		fld dword[ebp-8]
		fld dword[ebp-28]
		fabs
		fdivp
		fstp dword[ebp-12]
		jmp aabb4d_resolveKinematicNonkinematic_scaler_done
		
	aabb4d_resolveKinematicNonkinematic_scaler_z:
		fld dword[ebp-8]
		fld dword[ebp-24]
		fabs
		fdivp
		fstp dword[ebp-12]
		jmp aabb4d_resolveKinematicNonkinematic_scaler_done
		
	aabb4d_resolveKinematicNonkinematic_scaler_w:
		fld dword[ebp-8]
		fld dword[ebp-20]
		fabs
		fdivp
		fstp dword[ebp-12]
		jmp aabb4d_resolveKinematicNonkinematic_scaler_done
		
	aabb4d_resolveKinematicNonkinematic_scaler_done:
	
	mov eax, dword[ebp-12]
	and eax, 0x7f800000
	cmp eax, 0x7f800000
	je aabb4d_resolveKinematicNonkinematic_end					;the scaler is either +/-Inf or +/-NaN
	
	push dword[ebp-12]
	lea eax, [ebp-32]
	push eax
	push eax
	call vec4_scale
	
	;update position
	lea eax, [ebp-32]
	push eax
	push dword[ebp+12]
	push dword[ebp+12]
	call vec4_add
	
	jmp aabb4d_resolveKinematicNonkinematic_end
	
	;change velocity if necessary
	lea eax, [ebp-16]
	push eax
	call vec4_normalize
	mov eax, dword[ebp+12]
	add eax, 32
	push eax
	call vec4_dot
	fstp dword[ebp-36]
	
	test dword[ebp-36], 0x80000000
	jz aabb4d_resolveKinematicNonkinematic_end		;if the dot product is positive, then the velocity should not be tampered with
	
	push dword[ebp-36]
	lea eax, [ebp-16]
	push eax
	lea eax, [ebp-52]
	push eax
	call vec4_scale
	
	mov eax, dword[ebp+12]
	add eax, 32
	push eax
	push eax
	call vec4_sub
	
	
	aabb4d_resolveKinematicNonkinematic_end:
	mov esp, ebp
	pop ebp
	ret
	
aabb4d_resolveNonkinematicNonkinematic:
	push ebp
	mov ebp, esp
	
	sub esp, 16					;resolution direction											16
	sub esp, 4					;<normalize(resolution direction); nonkinematic.velocity>		20
	sub esp, 16					;velocity loss													36
	
	lea eax, [ebp-16]
	push eax
	push dword[ebp+12]
	push dword[ebp+8]
	call aabb4d_detectCollisionInternal
	
	test eax, eax
	jz aabb4d_resolveNonkinematicNonkinematic_end		;no collision happened
	
	;change positions
	lea eax, [ebp-16]
	push dword[HALF]
	push eax
	push eax
	call vec4_scale
	
	lea eax, [ebp-16]
	push eax
	push dword[ebp+8]
	push dword[ebp+8]
	call vec4_add
	
	lea eax, [ebp-16]
	push eax
	push dword[ebp+12]
	push dword[ebp+12]
	call vec4_sub
	
	;change velocities
	lea eax, [ebp-16]
	push eax
	call vec4_normalize
	add esp, 4
	
	;is changing c1.velocity necessary?
	lea eax, [ebp-16]
	push eax
	mov eax, dword[ebp+8]
	add eax, 32
	push eax
	call vec4_dot
	fstp dword[ebp-20]
	test dword[ebp-20], 0x80000000
	jz aabb4d_resolveNonkinematicNonkinematic_no_c1_velocity_change
	
		push dword[ebp-20]
		lea eax, [ebp-16]
		push eax
		lea eax, [ebp-36]
		push eax
		call vec4_scale
		
		mov eax, dword[ebp+8]
		add eax, 32
		push eax
		push eax
		call vec4_sub
	
	aabb4d_resolveNonkinematicNonkinematic_no_c1_velocity_change:
	
	;is changing c2.velocity necessary?
	lea eax, [ebp-16]
	push eax
	mov eax, dword[ebp+12]
	add eax, 32
	push eax
	call vec4_dot
	fstp dword[ebp-20]
	test dword[ebp-20], 0x80000000
	jnz aabb4d_resolveNonkinematicNonkinematic_no_c2_velocity_change
	
		push dword[ebp-20]
		lea eax, [ebp-16]
		push eax
		lea eax, [ebp-36]
		push eax
		call vec4_scale
		
		mov eax, dword[ebp+12]
		add eax, 32
		push eax
		push eax
		call vec4_sub
	
	aabb4d_resolveNonkinematicNonkinematic_no_c2_velocity_change:
	
	aabb4d_resolveNonkinematicNonkinematic_end:
	mov esp, ebp
	pop ebp
	ret
	
aabb4d_detectCollisionInternal:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;c1 lower bound						;16
	sub esp, 16				;c2 lower bound						;32
	sub esp, 16				;c1 upper bound						;48
	sub esp, 16				;c2 upper bound						;64
	
	sub esp, 4				;was there collision				;68
	
	sub esp, 4				;min penetration					;72
	sub esp, 16				;min penetration direction			;88 (unused)
	
	sub esp, 4				;c1 collision mask					;92
	sub esp, 4				;c2 collision mask					;96
	
	mov dword[ebp-68], 0
	mov dword[ebp-92], 0
	mov dword[ebp-96], 0
	
	mov ecx, dword[VERY_BIG_NUMBER]
	mov dword[ebp-72], ecx
	
	;calculate c1 lower and upper bound
	mov eax, dword[ebp+8]
	lea ecx, [eax+16]
	lea edx, [ebp-16]
	push ecx
	push eax
	push edx
	call vec4_sub
	lea edx, [ebp-48]
	mov dword[esp], edx
	call vec4_add
	add esp, 12
	
	;calculate c2 lower and upper bound
	mov eax, dword[ebp+12]
	lea ecx, [eax+16]
	lea edx, [ebp-32]
	push ecx
	push eax
	push edx
	call vec4_sub
	lea edx, [ebp-64]
	mov dword[esp], edx
	call vec4_add
	add esp, 12
	
	;check if there are any collisions
	movss xmm0, dword[ebp-16]
	ucomiss xmm0, dword[ebp-64]
	jae aabb4d_detectCollisionInternal_end
	movss xmm0, dword[ebp-12]
	ucomiss xmm0, dword[ebp-60]
	jae aabb4d_detectCollisionInternal_end
	movss xmm0, dword[ebp-8]
	ucomiss xmm0, dword[ebp-56]
	jae aabb4d_detectCollisionInternal_end
	movss xmm0, dword[ebp-4]
	ucomiss xmm0, dword[ebp-52]
	jae aabb4d_detectCollisionInternal_end
	
	movss xmm0, dword[ebp-32]
	ucomiss xmm0, dword[ebp-48]
	jae aabb4d_detectCollisionInternal_end
	movss xmm0, dword[ebp-28]
	ucomiss xmm0, dword[ebp-44]
	jae aabb4d_detectCollisionInternal_end
	movss xmm0, dword[ebp-24]
	ucomiss xmm0, dword[ebp-40]
	jae aabb4d_detectCollisionInternal_end
	movss xmm0, dword[ebp-20]
	ucomiss xmm0, dword[ebp-36]
	jae aabb4d_detectCollisionInternal_end
	
	mov dword[ebp-68], 69
	
	;get the minimum penetration
	movss xmm0, dword[ebp-16]
	movss xmm1, dword[ebp-64]
	subss xmm1, xmm0
	ucomiss xmm1, dword[ebp-72]
	jae aabb4d_detectCollisionInternal_not_pos_x
		movss dword[ebp-72], xmm1
		
		mov eax, dword[RESOLUTION_DIR_POS_X]
		mov ecx, dword[ebp+16]
		mov dword[ecx], eax
		
		mov eax, dword[AABB4D_NEG_X]
		mov dword[ebp-92], eax
		mov eax, dword[AABB4D_POS_X]
		mov dword[ebp-96], eax
	aabb4d_detectCollisionInternal_not_pos_x:
	
	movss xmm0, dword[ebp-12]
	movss xmm1, dword[ebp-60]
	subss xmm1, xmm0
	ucomiss xmm1, dword[ebp-72]
	jae aabb4d_detectCollisionInternal_not_pos_y
		movss dword[ebp-72], xmm1
		
		mov eax, dword[RESOLUTION_DIR_POS_Y]
		mov ecx, dword[ebp+16]
		mov dword[ecx], eax
		
		mov eax, dword[AABB4D_NEG_Y]
		mov dword[ebp-92], eax
		mov eax, dword[AABB4D_POS_Y]
		mov dword[ebp-96], eax
	aabb4d_detectCollisionInternal_not_pos_y:
	
	movss xmm0, dword[ebp-8]
	movss xmm1, dword[ebp-56]
	subss xmm1, xmm0
	ucomiss xmm1, dword[ebp-72]
	jae aabb4d_detectCollisionInternal_not_pos_z
		movss dword[ebp-72], xmm1
		
		mov eax, dword[RESOLUTION_DIR_POS_Z]
		mov ecx, dword[ebp+16]
		mov dword[ecx], eax
		
		mov eax, dword[AABB4D_NEG_Z]
		mov dword[ebp-92], eax
		mov eax, dword[AABB4D_POS_Z]
		mov dword[ebp-96], eax
	aabb4d_detectCollisionInternal_not_pos_z:
	
	movss xmm0, dword[ebp-4]
	movss xmm1, dword[ebp-52]
	subss xmm1, xmm0
	ucomiss xmm1, dword[ebp-72]
	jae aabb4d_detectCollisionInternal_not_pos_w
		movss dword[ebp-72], xmm1
		
		mov eax, dword[RESOLUTION_DIR_POS_W]
		mov ecx, dword[ebp+16]
		mov dword[ecx], eax
		
		mov eax, dword[AABB4D_NEG_W]
		mov dword[ebp-92], eax
		mov eax, dword[AABB4D_POS_W]
		mov dword[ebp-96], eax
	aabb4d_detectCollisionInternal_not_pos_w:
	
	movss xmm0, dword[ebp-32]
	movss xmm1, dword[ebp-48]
	subss xmm1, xmm0
	ucomiss xmm1, dword[ebp-72]
	jae aabb4d_detectCollisionInternal_not_neg_x
		movss dword[ebp-72], xmm1
		
		mov eax, dword[RESOLUTION_DIR_NEG_X]
		mov ecx, dword[ebp+16]
		mov dword[ecx], eax
		
		mov eax, dword[AABB4D_POS_X]
		mov dword[ebp-92], eax
		mov eax, dword[AABB4D_NEG_X]
		mov dword[ebp-96], eax
	aabb4d_detectCollisionInternal_not_neg_x:
	
	movss xmm0, dword[ebp-28]
	movss xmm1, dword[ebp-44]
	subss xmm1, xmm0
	ucomiss xmm1, dword[ebp-72]
	jae aabb4d_detectCollisionInternal_not_neg_y
		movss dword[ebp-72], xmm1
		
		mov eax, dword[RESOLUTION_DIR_NEG_Y]
		mov ecx, dword[ebp+16]
		mov dword[ecx], eax
		
		mov eax, dword[AABB4D_POS_Y]
		mov dword[ebp-92], eax
		mov eax, dword[AABB4D_NEG_Y]
		mov dword[ebp-96], eax
	aabb4d_detectCollisionInternal_not_neg_y:
	
	movss xmm0, dword[ebp-24]
	movss xmm1, dword[ebp-40]
	subss xmm1, xmm0
	ucomiss xmm1, dword[ebp-72]
	jae aabb4d_detectCollisionInternal_not_neg_z
		movss dword[ebp-72], xmm1
		
		mov eax, dword[RESOLUTION_DIR_NEG_Z]
		mov ecx, dword[ebp+16]
		mov dword[ecx], eax
		
		mov eax, dword[AABB4D_POS_Z]
		mov dword[ebp-92], eax
		mov eax, dword[AABB4D_NEG_Z]
		mov dword[ebp-96], eax
	aabb4d_detectCollisionInternal_not_neg_z:
	
	movss xmm0, dword[ebp-20]
	movss xmm1, dword[ebp-36]
	subss xmm1, xmm0
	ucomiss xmm1, dword[ebp-72]
	jae aabb4d_detectCollisionInternal_not_neg_w
		movss dword[ebp-72], xmm1
		
		mov eax, dword[RESOLUTION_DIR_NEG_W]
		mov ecx, dword[ebp+16]
		mov dword[ecx], eax
		
		mov eax, dword[AABB4D_POS_W]
		mov dword[ebp-92], eax
		mov eax, dword[AABB4D_NEG_W]
		mov dword[ebp-96], eax
	aabb4d_detectCollisionInternal_not_neg_w:
	
	;save the penetration	
	mov eax, dword[ebp+20]
	mov ecx, dword[ebp-72]
	mov dword[eax], ecx
	
	;set the collision directions
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-92]
	or dword[eax+56], ecx
	
	mov eax, dword[ebp+12]
	mov ecx, dword[ebp-96]
	or dword[eax+56], ecx
	
	;set the last collision collider
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	mov dword[eax+52], ecx
	mov dword[ecx+52], eax

	aabb4d_detectCollisionInternal_end:
	mov eax, dword[ebp-68]
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
aabb4d_setHyperPlane:
	mov eax, dword[esp+4]
	push 64
	push eax
	push hyperplane_aabb4d
	call my_memcpy
	add esp, 12
	ret