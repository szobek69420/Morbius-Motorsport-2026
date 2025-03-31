[BITS 32]

;layout:
;struct ColliderGroup4D{
;	vector<Aabb4D*> colliders;			;0 //they act as kinematic colliders
;	vec4 lowerBound;					;16
;	vec4 upperBound;					;32
;}	48 bytes overall

section .rodata use32
	NEGATIVE_INFINITY dd 0xff800000
	POSITIVE_INFINITY dd 0x7f800000
	
	printInfo_header db "Collider group:",10,0
	printInfo_collider_count db "Collider count: %d",10,0
	printInfo_lower_bound db "Lower bound: ",0
	printInfo_upper_bound db "Upper bound: ",0
	
	test_text db "fidesz castrol",10,0
	test_text2 db "fidesz castrol2",10,0

section .text use32
	
	global colliderGroup4d_create			;ColliderGroup4D* colliderGroup4d_create()
	global colliderGroup4d_destroy			;ColliderGroup4D* colliderGroup4d_destroy(ColliderGroup4D* cg, int destroyColliders)
	
	global colliderGroup4d_addCollider		;void colliderGroup4d_addCollider(ColliderGroup4D*, Aabb4D*)
	global colliderGroup4d_removeCollider	;void colliderGroup4d_removeCollider(ColliderGroup4D*, Aabb4D*)
	;void colliderGroup4d_recalculateBounds(ColliderGroup4D*)
	
	global colliderGroup4d_resolveCollision	;void colliderGroup4d_resolveCollision(ColliderGroup4D* cg, Aabb4D* nonkinematic)
	
	;returns non-zero if there was an intersection
	;in case of an intersection, the direction buffer is also overwritten (with for example AABB4D_POS_X)
	global colliderGroup4d_intersectWithPoint	;int colliderGroup4d_intersectWithPoint(ColliderGroup4D* cg, vec4* point, int* direction)
	
	global colliderGroup4d_isPointInBounds	;int colliderGroup4d_isPointInBounds(ColliderGroup4D* cg, vec4* point)
	
	global colliderGroup4d_printInfo		;void colliderGroup4d_printInfo(ColliderGroup4D* cg)
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_qsort
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove
	
	extern vec4_add
	extern vec4_sub
	extern vec4_print
	
	extern aabb4d_resolveKinematicNonkinematic
	extern aabb4d_destroy
	extern aabb4d_calculateDistance
	
	extern AABB4D_POS_X
	extern AABB4D_NEG_X
	extern AABB4D_POS_Y
	extern AABB4D_NEG_Y
	extern AABB4D_POS_Z
	extern AABB4D_NEG_Z
	extern AABB4D_POS_W
	extern AABB4D_NEG_W

colliderGroup4d_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;collider group
	
	;alloc collider group
	push 48
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;init vector
	push 4
	push eax
	call vector_init
	add esp, 8
	
	;init bounds
	mov eax, dword[ebp-4]
	mov ecx, dword[NEGATIVE_INFINITY]
	mov edx, dword[POSITIVE_INFINITY]
	mov dword[eax+16], edx
	mov dword[eax+20], edx
	mov dword[eax+24], edx
	mov dword[eax+28], edx
	mov dword[eax+32], ecx
	mov dword[eax+36], ecx
	mov dword[eax+40], ecx
	mov dword[eax+44], ecx
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
colliderGroup4d_destroy:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	;should we yeet the colliders?
	cmp dword[ebp+20], 0
	je colliderGroup4d_destroy_spare_colliders
	
	mov eax, dword[ebp+16]
	cmp dword[eax], 0
	je colliderGroup4d_destroy_spare_colliders		;there are no collider in the cg
	
	;yeet the colliders
	mov eax, dword[ebp+16]
	mov esi, dword[eax+12]				;current collider in esi
	mov edi, dword[eax]					;index in edi
	colliderGroup4d_destroy_yeet_loop_start:
		push dword[esi]
		call aabb4d_destroy
		add esp, 4
	
		add esi, 4
		dec edi
		test edi, edi
		jnz colliderGroup4d_destroy_yeet_loop_start
	
	colliderGroup4d_destroy_spare_colliders:
	
	;destroy the vector
	push dword[ebp+16]
	call vector_destroy
	
	;dealloc cg
	push dword[ebp+16]
	call my_free
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
colliderGroup4d_addCollider:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;collider lower bound
	sub esp, 16				;collider upper bound
	
	;add collider to the viktor
	push dword[ebp+12]
	push dword[ebp+8]
	call vector_push_back
	add esp, 8
	
	;calculate the collider bounds
	mov eax, dword[ebp+12]
	lea ecx, dword[eax+16]
	push ecx
	push eax
	lea eax, [ebp-16]
	push eax
	call vec4_sub
	lea eax, [ebp-32]
	mov dword[esp], eax
	call vec4_add
	add esp, 12
	
	;update the cg bounds
	mov eax, dword[ebp+8]
	
	movss xmm0, dword[ebp-16]
	ucomiss xmm0, dword[eax+16]
	jae colliderGroup4d_addCollider_not_neg_x
		movss dword[eax+16], xmm0
	colliderGroup4d_addCollider_not_neg_x:
	
	movss xmm0, dword[ebp-12]
	ucomiss xmm0, dword[eax+20]
	jae colliderGroup4d_addCollider_not_neg_y
		movss dword[eax+20], xmm0
	colliderGroup4d_addCollider_not_neg_y:
	
	movss xmm0, dword[ebp-8]
	ucomiss xmm0, dword[eax+24]
	jae colliderGroup4d_addCollider_not_neg_z
		movss dword[eax+24], xmm0
	colliderGroup4d_addCollider_not_neg_z:
	
	movss xmm0, dword[ebp-4]
	ucomiss xmm0, dword[eax+28]
	jae colliderGroup4d_addCollider_not_neg_w
		movss dword[eax+28], xmm0
	colliderGroup4d_addCollider_not_neg_w:
	
	movss xmm0, dword[ebp-32]
	ucomiss xmm0, dword[eax+32]
	jbe colliderGroup4d_addCollider_not_pos_x
		movss dword[eax+32], xmm0
	colliderGroup4d_addCollider_not_pos_x:
	
	movss xmm0, dword[ebp-28]
	ucomiss xmm0, dword[eax+36]
	jbe colliderGroup4d_addCollider_not_pos_y
		movss dword[eax+36], xmm0
	colliderGroup4d_addCollider_not_pos_y:
	
	movss xmm0, dword[ebp-24]
	ucomiss xmm0, dword[eax+40]
	jbe colliderGroup4d_addCollider_not_pos_z
		movss dword[eax+40], xmm0
	colliderGroup4d_addCollider_not_pos_z:
	
	movss xmm0, dword[ebp-20]
	ucomiss xmm0, dword[eax+44]
	jbe colliderGroup4d_addCollider_not_pos_w
		movss dword[eax+44], xmm0
	colliderGroup4d_addCollider_not_pos_w:
	
	mov esp, ebp
	pop ebp
	ret
	
	
colliderGroup4d_removeCollider:
	push ebp
	mov ebp, esp
	
	;remove collider from the viktor
	push dword[ebp+12]
	push dword[ebp+8]
	call vector_remove
	add esp, 8
	
	;recalculate bounds
	push dword[ebp+8]
	call colliderGroup4d_recalculateBounds
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	
	
colliderGroup4d_recalculateBounds:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 16			;temp collider lower bound		;16
	sub esp, 16			;temp collider upper bound		;32
	
	;reset the bounds
	mov eax, dword[ebp-4]
	mov ecx, dword[NEGATIVE_INFINITY]
	mov edx, dword[POSITIVE_INFINITY]
	mov dword[eax+16], edx
	mov dword[eax+20], edx
	mov dword[eax+24], edx
	mov dword[eax+28], edx
	mov dword[eax+32], ecx
	mov dword[eax+36], ecx
	mov dword[eax+40], ecx
	mov dword[eax+44], ecx
	
	;calculate the bounds
	cmp dword[eax], 0
	je colliderGroup4d_recalculateBounds_end
	
	mov esi, dword[eax+12]	;current collider in esi
	mov edi, dword[eax]		;index in edi
	colliderGroup4d_recalculateBounds_loop_start:
		mov eax, dword[esi]
		
		;calculate collider bounds
		lea ecx, [eax+16]
		push ecx
		push eax
		lea ecx, [ebp-16]
		push ecx
		call vec4_sub
		sub dword[esp], 16
		call vec4_add
		add esp, 12
		
		;check if the bound should be updated
		mov eax, dword[ebp+16]
		
		movss xmm0, dword[eax+16]
		movss xmm1, dword[ebp-16]
		ucomiss xmm0, xmm1
		jbe colliderGroup4d_recalculateBounds_loop_not_neg_x
			movss dword[eax+16], xmm1
		colliderGroup4d_recalculateBounds_loop_not_neg_x:
		
		movss xmm0, dword[eax+20]
		movss xmm1, dword[ebp-12]
		ucomiss xmm0, xmm1
		jbe colliderGroup4d_recalculateBounds_loop_not_neg_y
			movss dword[eax+20], xmm1
		colliderGroup4d_recalculateBounds_loop_not_neg_y:
		
		movss xmm0, dword[eax+24]
		movss xmm1, dword[ebp-8]
		ucomiss xmm0, xmm1
		jbe colliderGroup4d_recalculateBounds_loop_not_neg_z
			movss dword[eax+24], xmm1
		colliderGroup4d_recalculateBounds_loop_not_neg_z:
		
		movss xmm0, dword[eax+28]
		movss xmm1, dword[ebp-4]
		ucomiss xmm0, xmm1
		jbe colliderGroup4d_recalculateBounds_loop_not_neg_w
			movss dword[eax+28], xmm1
		colliderGroup4d_recalculateBounds_loop_not_neg_w:
		
		movss xmm0, dword[eax+32]
		movss xmm1, dword[ebp-32]
		ucomiss xmm0, xmm1
		jae colliderGroup4d_recalculateBounds_loop_not_pos_x
			movss dword[eax+32], xmm1
		colliderGroup4d_recalculateBounds_loop_not_pos_x:
		
		movss xmm0, dword[eax+36]
		movss xmm1, dword[ebp-28]
		ucomiss xmm0, xmm1
		jae colliderGroup4d_recalculateBounds_loop_not_pos_y
			movss dword[eax+36], xmm1
		colliderGroup4d_recalculateBounds_loop_not_pos_y:
		
		movss xmm0, dword[eax+40]
		movss xmm1, dword[ebp-24]
		ucomiss xmm0, xmm1
		jae colliderGroup4d_recalculateBounds_loop_not_pos_z
			movss dword[eax+40], xmm1
		colliderGroup4d_recalculateBounds_loop_not_pos_z:
		
		movss xmm0, dword[eax+44]
		movss xmm1, dword[ebp-20]
		ucomiss xmm0, xmm1
		jae colliderGroup4d_recalculateBounds_loop_not_pos_w
			movss dword[eax+44], xmm1
		colliderGroup4d_recalculateBounds_loop_not_pos_w:
		
		add esi, 4
		dec edi
		test edi, edi
		jnz colliderGroup4d_recalculateBounds_loop_start
	
	colliderGroup4d_recalculateBounds_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
colliderGroup4d_resolveCollision:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 16				;collider lower bound			16
	sub esp, 16				;collider upper bound			32
	sub esp, 4				;helper array					36
	sub esp, 4				;collider count					40
	
	mov eax, dword[ebp+16]
	mov eax, dword[eax]
	mov dword[ebp-40], eax
	
	cmp dword[ebp-40], 0
	jle colliderGroup4d_resolveCollision_end
	
	;calculate the collider bounds
	mov eax, dword[ebp+20]
	lea ecx, dword[eax+16]
	push ecx
	push eax
	lea eax, [ebp-16]
	push eax
	call vec4_sub
	lea eax, [ebp-32]
	mov dword[esp], eax
	call vec4_add
	add esp, 12
	
	;check if the collider is in the bounds of the collider group
	mov eax, dword[ebp+16]
	
	movss xmm0, dword[ebp-16]
	ucomiss xmm0, dword[eax+32]
	jae colliderGroup4d_resolveCollision_end
	movss xmm0, dword[ebp-12]
	ucomiss xmm0, dword[eax+36]
	jae colliderGroup4d_resolveCollision_end
	movss xmm0, dword[ebp-8]
	ucomiss xmm0, dword[eax+40]
	jae colliderGroup4d_resolveCollision_end
	movss xmm0, dword[ebp-4]
	ucomiss xmm0, dword[eax+44]
	jae colliderGroup4d_resolveCollision_end
	movss xmm0, dword[ebp-32]
	ucomiss xmm0, dword[eax+16]
	jbe colliderGroup4d_resolveCollision_end
	movss xmm0, dword[ebp-28]
	ucomiss xmm0, dword[eax+20]
	jbe colliderGroup4d_resolveCollision_end
	movss xmm0, dword[ebp-24]
	ucomiss xmm0, dword[eax+24]
	jbe colliderGroup4d_resolveCollision_end
	movss xmm0, dword[ebp-20]
	ucomiss xmm0, dword[eax+28]
	jbe colliderGroup4d_resolveCollision_end
	
	
	;create helper array
	;it is an array of struct {Aabb4D* cgCollider, float distanceFromNonkinematic}
	mov eax, dword[ebp-40]
	shl eax, 3					;8*colliderCount
	push eax
	call my_malloc
	mov dword[ebp-36], eax
	add esp, 4
	
	xor esi, esi				;index in esi
	mov edi, dword[ebp-36]		;current helper item in edi
	colliderGroup4d_resolveCollision_helper_loop_start:
		;get the current collider
		mov eax, dword[ebp+16]
		mov eax, dword[eax+12]
		mov ecx, dword[eax+4*esi]
		mov dword[edi], ecx
		
		;calculate the distance from the nonkinematic collider
		push dword[ebp+20]
		push ecx
		call aabb4d_calculateDistance
		fstp dword[edi+4]
		add esp, 8
		
		add edi, 8
		inc esi
		cmp esi, dword[ebp-40]
		jl colliderGroup4d_resolveCollision_helper_loop_start
		
	;sort the helper array according to distance
	push colliderGroup4d_resolveCollisionHelperComparator
	push 8
	push dword[ebp-40]
	push dword[ebp-36]
	call my_qsort
	add esp, 16
	
	
	;resolve collision
	mov esi, dword[ebp-36]			;current helper item in esi
	mov edi, dword[ebp-40]			;index in edi
	colliderGroup4d_resolveCollision_loop_start:
		;gtfo if the collider is not getting freaky with the nonkinematic collider
		test dword[esi+4], 0x80000000
		jz colliderGroup4d_resolveCollision_loop_end
		
		;resolve collision
		push dword[ebp+20]
		push dword[esi]
		call aabb4d_resolveKinematicNonkinematic
		add esp, 8
		
		add esi, 8
		dec edi
		test edi, edi
		jnz colliderGroup4d_resolveCollision_loop_start
	colliderGroup4d_resolveCollision_loop_end:
	
	
	;free the end
	push dword[ebp-36]
	call my_free
	add esp, 4
	
	colliderGroup4d_resolveCollision_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
;a comparator function for qsort to sort the helper items into an ascending order according to the distance
;typedef struct {Aabb4D* cgCollider, float distanceFromNonkinematic} ResolutionHelper;
;int this_func(ResolutionHelper* helper1, ResolutionHelper* helper2)
colliderGroup4d_resolveCollisionHelperComparator:
	mov eax, -69
	mov ecx, dword[esp+4]
	mov edx, dword[esp+8]
	movss xmm0, dword[ecx+4]
	ucomiss xmm0, dword[edx+4]
	jbe colliderGroup4d_resolveCollisionHelperComparator_end
		mov eax, 69
	colliderGroup4d_resolveCollisionHelperComparator_end:
	ret
	
	
colliderGroup4d_intersectWithPoint:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4				;helper array				4		//it uses the same helper structure as resolveCollision
	sub esp, 4				;collider count				8
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
colliderGroup4d_isPointInBounds:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	
	mov dword[ebp-4], 0
	
	
	mov ecx, dword[ebp+8]
	mov eax, dword[ebp+12]
	
	
	movss xmm0, dword[eax]
	ucomiss xmm0, dword[ecx+16]
	jbe colliderGroup4d_isPointInBounds_end
	ucomiss xmm0, dword[ecx+32]
	jae colliderGroup4d_isPointInBounds_end
	
	movss xmm0, dword[eax+4]
	ucomiss xmm0, dword[ecx+20]
	jbe colliderGroup4d_isPointInBounds_end
	ucomiss xmm0, dword[ecx+36]
	jae colliderGroup4d_isPointInBounds_end
	
	movss xmm0, dword[eax+8]
	ucomiss xmm0, dword[ecx+24]
	jbe colliderGroup4d_isPointInBounds_end
	ucomiss xmm0, dword[ecx+40]
	jae colliderGroup4d_isPointInBounds_end
	
	movss xmm0, dword[eax+12]
	ucomiss xmm0, dword[ecx+28]
	jbe colliderGroup4d_isPointInBounds_end
	ucomiss xmm0, dword[ecx+44]
	jae colliderGroup4d_isPointInBounds_end
	
	
	mov dword[ebp-4], 69
	
	
	colliderGroup4d_isPointInBounds_end:
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
colliderGroup4d_printInfo:
	push ebp
	mov ebp, esp
	
	push printInfo_header
	call my_printf
	
	mov eax, dword[ebp+8]
	push dword[eax]
	push printInfo_collider_count
	call my_printf
	
	push printInfo_lower_bound
	call my_printf
	mov eax, dword[ebp+8]
	add eax, 16
	push eax
	call vec4_print
	
	push printInfo_upper_bound
	call my_printf
	mov eax, dword[ebp+8]
	add eax, 32
	push eax
	call vec4_print
	
	mov esp, ebp
	pop ebp
	ret