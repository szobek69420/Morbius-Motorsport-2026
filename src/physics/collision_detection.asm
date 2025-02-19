[BITS 32]

section .rodata use32
	EPSILON dd 0.00001
	
	HALF dd 0.5
	TWO dd 2.0
	
	VEC3_ZERO dd 0.0, 0.0, 0.0
	
	test_line0 dd 0.0, 0.0, -13.8
	test_line1 dd -13.8, 0.0, 0.0
	
section .bss use32
	test_vec3_buffer resb 12

section .text use32

	;returns non-zero if a collision happened
	;only supports mesh colliders with horizontal and vertical normals
	global collisionDetection_resolveCylinderMesh		;int cd_rCylinderMesh(Collider* cylinder, Collider* mesh)
	
	extern vec3_sub
	extern vec3_add
	extern vec3_dot
	extern vec3_cross
	extern vec3_normalize
	extern vec3_scale
	extern vec3_print
	
	extern my_malloc
	extern my_free
	extern my_memcpy
	
collisionDetection_resolveCylinderMesh:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;vec3* translated vertices			;4
	sub esp, 12			;mesh.position-cylinder.position	;16
	sub esp, 4			;vertex count						;20
	sub esp, 4			;triangle count						;24
	sub esp, 4			;triangle indices					;28
	sub esp, 4			;triangle normals					;32
	sub esp, 4			;min penetration					;36
	sub esp, 12			;min resolution dir					;52 (i messed this up but who cares)
	sub esp, 4			;temp penetration					;56
	sub esp, 12			;temp resolution dir				;68
	
	;get vertex count, triangle count, triangle indices and triangle normals
	mov eax, dword[ebp+24]
	mov eax, dword[eax+28]
	mov ecx, dword[eax+12]
	mov dword[ebp-20], ecx
	mov ecx, dword[eax+16]
	mov dword[ebp-24], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-28], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-32], ecx
	
	;calculate mesh.position-cylinder.position
	push dword[ebp+20]
	push dword[ebp+24]
	lea eax, [ebp-16]
	push eax
	call vec3_sub
	add esp, 12
	
	;alloc space for the translated vertices and copy them
	mov eax, dword[ebp-20]
	imul eax, 12
	push eax
	call my_malloc
	mov dword[ebp-4], eax
	mov ecx, dword[ebp+24]
	mov ecx, dword[ecx+28]
	push dword[ecx]
	push eax
	call my_memcpy
	add esp, 12
	
	;translate the vertices
	mov esi, dword[ebp-4]		;current position in buffer in esi
	mov edi, dword[ebp-20]		;index in edi
	lea eax, [ebp-16]
	push eax					;pre-push mesh.pos-cylinder.pos
	test edi, edi
	jz collisionDetection_rcm_translate_loop_end
	collisionDetection_rcm_translate_loop_start:
		push esi
		push esi
		call vec3_sub
		add esp, 8
	
		add esi, 12
		dec edi
		test edi, edi
		jnz collisionDetection_rcm_translate_loop_start
	
	collisionDetection_rcm_translate_loop_end:
	add esp, 4
	
	;resolve collision
	mov dword[ebp-36], 0x7f800000		;+infinity
	
	mov esi, dword[ebp-28]				;current indices in esi
	mov edi, dword[ebp-32]				;current normal in edi
	mov ebx, dword[ebp-24]				;index in ebx
	test ebx, ebx
	jz collisionDetection_rcm_resolve_loop_end
	collisionDetection_rcm_resolve_loop_start:
		;decide if the triangle is vertical or horizontal
		mov eax, dword[edi+4]
		and eax, 0x7fffffff
		cmp eax, dword[EPSILON]
		jg collisionDetection_rcm_resolve_loop_horizontal
		collisionDetection_rcm_resolve_loop_vertical:
			;TODO
			jmp collisionDetection_rcm_resolve_loop_continue
			
		collisionDetection_rcm_resolve_loop_horizontal:
			lea eax, [ebp-68]
			push eax				;outResolutionDir
			lea eax, [ebp-56]
			push eax				;outPenetration
			push edi				;triNormal
			
			mov eax, dword[ebp-4]
			
			mov ecx, dword[esi+8]
			imul ecx, 12
			add ecx, eax
			push ecx				;tri2
			mov ecx, dword[esi+4]
			imul ecx, 12
			add ecx, eax
			push ecx				;tri1
			mov ecx, dword[esi]
			imul ecx, 12
			add ecx, eax
			push ecx				;tri2
			
			push dword[ebp+20]		;cylinder
			
			call collisionDetection_rcmHorizontalTriangle
			add esp, 28
			
			test eax, eax
			jz collisionDetection_rcm_resolve_loop_continue			;no collision
			
				mov eax, dword[ebp-56]
				cmp eax, dword[ebp-36]
				jge collisionDetection_rcm_resolve_loop_continue	;penetration is not less
					mov ecx, dword[ebp-56]
					mov dword[ebp-36], ecx
					
					mov ecx, dword[ebp-68]
					mov dword[ebp-52], ecx
					mov ecx, dword[ebp-64]
					mov dword[ebp-48], ecx
					mov ecx, dword[ebp-60]
					mov dword[ebp-44], ecx
					
					jmp collisionDetection_rcm_resolve_loop_continue
					
		collisionDetection_rcm_resolve_loop_continue:
		add esi, 12
		add edi, 12
		dec ebx
		test ebx, ebx
		jnz collisionDetection_rcm_resolve_loop_start
		
	collisionDetection_rcm_resolve_loop_end:
	
	;check if there was a resolution
	cmp dword[ebp-36], 0x7f800000
	jne collisionDetection_rcm_collision_happened
		xor eax, eax
		jmp collisionDetection_rcm_end
		
	collisionDetection_rcm_collision_happened:
	
	;resolve according to the kinematicness of the colliders
	xor eax, eax
	
	mov ecx, dword[ebp+20]
	cmp dword[ecx+32], 0
	je collisionDetection_rcm_cylinder_kinematic
		mov eax, 0x1
	collisionDetection_rcm_cylinder_kinematic:
	mov ecx, dword[ebp+24]
	cmp dword[ecx+32], 0
	je collisionDetection_rcm_mesh_kinematic
		or eax, 0x2
	collisionDetection_rcm_mesh_kinematic:
	
	cmp eax, 1
	je collisionDetection_rcm_cylinder_nonkinematic_mesh_kinematic
	cmp eax, 2
	je collisionDetection_rcm_cylinder_kinematic_mesh_nonkinematic
	cmp eax, 3
	je collisionDetection_rcm_cylinder_nonkinematic_mesh_nonkinematic
	xor eax, eax
	jmp collisionDetection_rcm_end
	
	collisionDetection_rcm_cylinder_nonkinematic_mesh_kinematic:
		lea eax, [ebp-52]
		push eax
		push dword[ebp+20]
		push dword[ebp+20]
		call vec3_add
		mov eax, 69
		jmp collisionDetection_rcm_end
		
	collisionDetection_rcm_cylinder_kinematic_mesh_nonkinematic:
		lea eax, [ebp-52]
		push eax
		push dword[ebp+24]
		push dword[ebp+24]
		call vec3_sub
		mov eax, 69
		jmp collisionDetection_rcm_end
		
	collisionDetection_rcm_cylinder_nonkinematic_mesh_nonkinematic:
		lea eax, [ebp-52]
		push dword[TWO]
		push eax
		push eax
		call vec3_scale
		
		push dword[ebp+20]
		push dword[ebp+20]
		call vec3_add
		
		add esp, 8
		push dword[ebp+24]
		push dword[ebp+24]
		call vec3_sub
		
		mov eax, 69
		jmp collisionDetection_rcm_end
	
	collisionDetection_rcm_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
;void collisionDetection_cpol(vec3* buffer, vec3* point, vec3* line0, vec3* line1)
collisionDetection_closestPointOnLine:
	push ebp
	mov ebp, esp
	
	sub esp, 12				;line1-line0
	sub esp, 12				;point-line0
	sub esp, 12				;point-line1
	sub esp, 4				;<point-line0; line1-line0>
	sub esp, 4				;<point-line1; line1-line0>
	
	;calculate line1-line0
	push dword[ebp+16]
	push dword[ebp+20]
	lea eax, [ebp-12]
	push eax
	call vec3_sub
	
	;calculate point-line0
	push dword[ebp+16]
	push dword[ebp+12]
	lea eax, [ebp-24]
	push eax
	call vec3_sub
	
	;calculate var40
	lea eax, [ebp-12]
	push eax
	call vec3_dot
	fstp dword[ebp-40]
	test dword[ebp-40], 0x80000000
	jz collisionDetection_cpol_not_beyond_line0	;if the dot product is negative, line0 is obviously the closest point
		mov eax, dword[ebp+8]
		mov ecx, dword[ebp+16]
		mov edx, dword[ecx]
		mov dword[eax], edx
		mov edx, dword[ecx+4]
		mov dword[eax+4], edx
		mov edx, dword[ecx+8]
		mov dword[eax+8], edx
		jmp collisionDetection_closestPointOnLine_end
		
	collisionDetection_cpol_not_beyond_line0:
	
	;calculate point-line1
	push dword[ebp+20]
	push dword[ebp+12]
	lea eax, [ebp-36]
	push eax
	call vec3_sub
	
	;calculate var44
	lea eax, [ebp-12]
	push eax
	call vec3_dot
	fstp dword[ebp-44]
	test dword[ebp-44], 0x80000000
	jnz collisionDetection_cpol_not_beyond_line1	;if the dot product is non-negative, line1 is obviously the closest point
		mov eax, dword[ebp+8]
		mov ecx, dword[ebp+20]
		mov edx, dword[ecx]
		mov dword[eax], edx
		mov edx, dword[ecx+4]
		mov dword[eax+4], edx
		mov edx, dword[ecx+8]
		mov dword[eax+8], edx
		jmp collisionDetection_closestPointOnLine_end
		
	collisionDetection_cpol_not_beyond_line1:
	
	;at this point it is sure that the closest point is not an end point of the line
	lea eax, [ebp-12]
	push eax
	call vec3_normalize
	lea eax, [ebp-24]
	push eax
	call vec3_dot
	fstp dword[esp]
	lea eax, [ebp-12]
	push eax
	push eax
	call vec3_scale
	
	lea eax, [ebp-12]
	push eax
	push dword[ebp+16]
	push dword[ebp+8]
	call vec3_add
	
	collisionDetection_closestPointOnLine_end:
	mov esp, ebp
	pop ebp
	ret
	

;assumes that the point is (0,0,0)
;for the vertical collision detection this can be further optimized by assuming that the triangle is horizontal (vec2 operations instead of vec3)
;void collisionDetection_cpolo(
;	vec3* buffer,
;	vec3* line0,
;	vec3* line1
;)
collisionDetection_closestPointOnLineOrigo:
	push ebp
	mov ebp, esp
	
	sub esp, 12				;line0-line1
	sub esp, 4				;<line0; line0-line1>
	sub esp, 4				;<line1; line0-line1>
	
	;calculate line0-line1
	push dword[ebp+16]
	push dword[ebp+12]
	lea eax, [ebp-12]
	push eax
	call vec3_sub
	
	
	;calculate <line0; line0-line1>
	push dword[ebp+12]
	push eax
	lea eax, [ebp-12]
	push eax
	call vec3_dot
	fstp dword[ebp-16]
	test dword[ebp-16], 0x80000000
	jz collisionDetection_cpolo_not_beyond_line0	;if the dot product is negative, line0 is obviously the closest point
		mov eax, dword[ebp+8]
		mov ecx, dword[ebp+12]
		mov edx, dword[ecx]
		mov dword[eax], edx
		mov edx, dword[ecx+4]
		mov dword[eax+4], edx
		mov edx, dword[ecx+8]
		mov dword[eax+8], edx
		jmp collisionDetection_closestPointOnLineOrigo_end
		
	collisionDetection_cpolo_not_beyond_line0:
	
	
	;calculate <line1; line0-line1>
	push dword[ebp+16]
	lea eax, [ebp-12]
	push eax
	call vec3_dot
	fstp dword[ebp-20]
	test dword[ebp-20], 0x80000000
	jnz collisionDetection_cpolo_not_beyond_line1	;if the dot product is non-negative, line1 is obviously the closest point
		mov eax, dword[ebp+8]
		mov ecx, dword[ebp+16]
		mov edx, dword[ecx]
		mov dword[eax], edx
		mov edx, dword[ecx+4]
		mov dword[eax+4], edx
		mov edx, dword[ecx+8]
		mov dword[eax+8], edx
		jmp collisionDetection_closestPointOnLineOrigo_end
		
	collisionDetection_cpolo_not_beyond_line1:
	
	;at this point it is sure that the closest point is not an end point of the line
	;the formula for the closest point is:
	;line1+(-1)*<line1, normalize(line0-line1)>*normalize(line0-line1)
	lea eax, [ebp-12]
	push eax
	call vec3_normalize
	push dword[ebp+16]
	call vec3_dot
	fstp dword[esp]
	xor dword[esp], 0x80000000
	lea eax, [ebp-12]
	push eax
	push eax
	call vec3_scale
	
	push dword[ebp+16]
	push dword[ebp+8]
	call vec3_add
	
	collisionDetection_closestPointOnLineOrigo_end:
	mov esp, ebp
	pop ebp
	ret
	

;returns non-zero if a collision has happened	
;expects the tri0, tri1 and tri2 to be in the local space of the cylinder (the position of the cylinder is (0,0,0) )
;int collisionDetection_rcmHorizontalTriangle(
;	Collider* cylinder,
;	vec3* tri0,
;	vec3* tri1,
;	vec3* tri2,
;	vec3* triNormal,
;	float* outPenetration,
;	vec3* outResolutionDir
;)
collisionDetection_rcmHorizontalTriangle:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;possible penetration						;4
	sub esp, 4			;cylinder height							;8
	sub esp, 4			;triangle y pos								;12
	sub esp, 12			;closest point on the side of the triangle	;24
	sub esp, 4			;distance from the closest point			;28
	sub esp, 12			;triNormal x closestTriangleSide			;40
	sub esp, 4			;closest triangle side index				;44
	sub esp, 12			;closest triangle side						;56
	
	;get cylinder height
	mov eax, dword[ebp+8]
	mov eax, dword[eax+28]
	mov eax, dword[eax]
	mov dword[ebp-8], eax
	
	;get triangle pos
	mov eax, dword[ebp+12]
	mov eax, dword[eax+4]
	mov dword[ebp-12], eax
	
	;check if the triangle is too high or too low
	;abs(tri.y)>=cylinder.height?
	and eax, 0x7fffffff
	cmp eax, dword[ebp-8]
	jl collisionDetection_rcmHorizontalTriangle_within_bounds_y
		xor eax, eax
		jmp collisionDetection_rcmHorizontalTriangle_end
		
	collisionDetection_rcmHorizontalTriangle_within_bounds_y:
	
	;get the closest point on one of the sides of the triangle
	push dword[ebp+16]
	push dword[ebp+12]
	lea eax, [ebp-24]
	push eax
	call collisionDetection_closestPointOnLineOrigo
	add esp, 12
	movss xmm0, dword[ebp-24]
	mulss xmm0, xmm0
	movss xmm1, dword[ebp-16]
	mulss xmm1, xmm1
	addss xmm0, xmm1
	movss dword[ebp-28], xmm0
	fld dword[ebp-28]
	fsqrt
	fstp dword[ebp-28]
	mov dword[ebp-44], 0
	
	push dword[ebp+20]
	push dword[ebp+16]
	lea eax, [ebp-40]		;borrowing var40
	push eax
	call collisionDetection_closestPointOnLineOrigo
	sub esp, 8				;4 bytes are left on the stack
	movss xmm0, dword[ebp-40]
	mulss xmm0, xmm0
	movss xmm1, dword[ebp-32]
	mulss xmm1, xmm1
	addss xmm0, xmm1
	movss dword[esp], xmm0
	fld dword[esp]
	fsqrt
	fstp dword[esp]
	mov eax, dword[esp]
	cmp eax, dword[ebp-28]
	jge collisionDetection_rcmHorizontalTriangle_side2_not_closer
		;if the current distance is less, then this side is the closest so far
		mov dword[ebp-28], eax
		
		mov ecx, dword[ebp-40]
		mov dword[ebp-24], ecx
		mov ecx, dword[ebp-36]
		mov dword[ebp-20], ecx
		mov ecx, dword[ebp-32]
		mov dword[ebp-16], ecx
		
		mov dword[ebp-44], 1
		
	collisionDetection_rcmHorizontalTriangle_side2_not_closer:
	add esp, 4
	
	
	push dword[ebp+12]
	push dword[ebp+20]
	lea eax, [ebp-40]		;borrowing var40
	push eax
	call collisionDetection_closestPointOnLineOrigo
	sub esp, 8				;4 bytes are left on the stack
	movss xmm0, dword[ebp-40]
	mulss xmm0, xmm0
	movss xmm1, dword[ebp-32]
	mulss xmm1, xmm1
	addss xmm0, xmm1
	movss dword[esp], xmm0
	fld dword[esp]
	fsqrt
	fstp dword[esp]
	mov eax, dword[esp]
	cmp eax, dword[ebp-28]
	jge collisionDetection_rcmHorizontalTriangle_side3_not_closer
		;if the current distance is less, then this side is the closest so far
		mov dword[ebp-28], eax
		
		mov ecx, dword[ebp-40]
		mov dword[ebp-24], ecx
		mov ecx, dword[ebp-36]
		mov dword[ebp-20], ecx
		mov ecx, dword[ebp-32]
		mov dword[ebp-16], ecx
		
		mov dword[ebp-44], 2
		
	collisionDetection_rcmHorizontalTriangle_side3_not_closer:
	add esp, 4
	
	;check if the cylinder intersexts with the triangle horizontally
	mov eax, dword[ebp+8]
	mov eax, dword[eax+28]
	mov eax, dword[eax+4]			;cylinder radius
	cmp eax, dword[ebp-28]
	jl collisionDetection_rcmHorizontalTriangle_horizontal_intersection
		;if the closest point is not in the radius of the cylinder
		;there is still a chance that the cylinder is on the triangle
		;if so, < ( triNormal x closestSide ); closestPoint > will be negative
		mov eax, dword[ebp-44]
		cmp eax, 1
		je collisionDetection_rcmVertical_collision_closest_side_1
		cmp eax, 2
		je collisionDetection_rcmVertical_collision_closest_side_2
		collisionDetection_rcmVertical_collision_closest_side_0:
			push dword[ebp+12]
			push dword[ebp+16]
			lea eax, [ebp-56]
			push eax
			call vec3_sub
			add esp, 12
			jmp collisionDetection_rcmHorizontalTriangle_closest_side_calculated
		
		collisionDetection_rcmVertical_collision_closest_side_1:
			push dword[ebp+16]
			push dword[ebp+20]
			lea eax, [ebp-56]
			push eax
			call vec3_sub
			add esp, 12
			jmp collisionDetection_rcmHorizontalTriangle_closest_side_calculated
			
		collisionDetection_rcmVertical_collision_closest_side_2:
			push dword[ebp+20]
			push dword[ebp+12]
			lea eax, [ebp-56]
			push eax
			call vec3_sub
			add esp, 12
			
		collisionDetection_rcmHorizontalTriangle_closest_side_calculated:
	
		;calculate the cross product
		lea eax, [ebp-40]
		lea ecx, [ebp-56]
		push ecx
		push dword[ebp+24]
		push eax
		call vec3_cross
		lea eax, [ebp-24]
		push eax
		call vec3_dot
		fstp dword[esp]
		test dword[esp], 0x80000000
		jnz collisionDetection_rcmHorizontalTriangle_horizontal_intersection
			;now it is sure, that there is no chance for an intersection
			xor eax, eax
			jmp collisionDetection_rcmHorizontalTriangle_end
			
	collisionDetection_rcmHorizontalTriangle_horizontal_intersection:
	
	;get the penetration
	mov eax, dword[ebp+24]
	mov eax, dword[eax+4]		;triNormal.y
	test eax, 0x80000000
	jnz collisionDetection_rcmHorizontalTriangle_penetration_neg_y
	collisionDetection_rcmHorizontalTriangle_penetration_pos_y:
		mov eax, dword[ebp+28]		;outPenetration
		movss xmm0, dword[ebp-8]	;cylinder height
		movss xmm1, dword[ebp-12]	;triangle y pos
		subss xmm0, xmm1
		movss dword[eax], xmm0
		jmp collisionDetection_rcmHorizontalTriangle_penetration_done
		
	collisionDetection_rcmHorizontalTriangle_penetration_neg_y:
		mov eax, dword[ebp+28]		;outPenetration
		movss xmm0, dword[ebp-8]	;cylinder height
		movss xmm1, dword[ebp-12]	;triangle y pos
		addss xmm0, xmm1			;triY-(-height)
		movss dword[eax], xmm0
		jmp collisionDetection_rcmHorizontalTriangle_penetration_done
	
	collisionDetection_rcmHorizontalTriangle_penetration_done:
	;set the resolutionDir
	mov eax, dword[ebp+32]
	mov ecx, dword[ebp+24]
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	mov edx, dword[ecx+8]
	mov dword[eax+8], edx
	
	mov eax, 69

	collisionDetection_rcmHorizontalTriangle_end:
	mov esp, ebp
	pop ebp
	ret