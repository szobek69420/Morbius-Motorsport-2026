[BITS 32]

section .rodata use32
	EPSILON dd 0.001
	
	HALF dd 0.5
	TWO dd 2.0
	
	VEC3_ZERO dd 0.0, 0.0, 0.0
	
	print_float_nl db "%f",10,0
	print_two_floats_nl db "%f %f",10,0
	
	test_line0 dd -0.88, 0.827, -1.623
	test_line1 dd -0.88, 0.827, -21.623
	
	test_text db "feliz navidad",10,0
	
section .bss use32
	test_vec3_buffer resb 12

section .text use32

	;returns non-zero if a collision happened
	global collisionDetection_resolveKinematicNonkinematic	;int collisionDetection_resolveKinematicNonkinematic(Collider* cKinematic, Collider* cNonkinematic)

	;returns non-zero if a collision happened
	;only supports mesh colliders with horizontal and vertical normals
	;the resolution dir points in the direction of the cylinder
	;global collisionDetection_resolveCylinderMesh		;int cd_rCylinderMesh(Collider* cylinder, Collider* mesh, float* outPenetration, vec3* outResolutionDir)
	
	extern COLLIDER_CYLINDER
	extern COLLIDER_MESH
	
	extern collider_getPosition
	
	extern cylinderCollider_getBounds
	extern meshCollider_getBounds
	
	extern vec3_sub
	extern vec3_add
	extern vec3_dot
	extern vec3_cross
	extern vec3_normalize
	extern vec3_scale
	extern vec3_print
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy
	
collisionDetection_resolveKinematicNonkinematic:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;penetration
	sub esp, 12			;resolution dir
	sub esp, 4			;collision happened
	sub esp, 12			;<nkCollider.velocity; resolutionDir> * resolutionDir
	
	mov dword[ebp-20], 0
	
	
	mov eax, dword[ebp+8]
	mov ecx, dword[COLLIDER_CYLINDER]
	cmp dword[eax+12], ecx
	je collisionDetection_rkn_k_cylinder
	mov ecx, dword[COLLIDER_MESH]
	cmp dword[eax+12], ecx
	je collisionDetection_rkn_k_mesh
	xor eax, eax
	jmp collisionDetection_rkn_end
	
	collisionDetection_rkn_k_cylinder:
		mov eax, dword[ebp+12]
		mov ecx, dword[COLLIDER_MESH]
		cmp dword[eax+12], ecx
		je collisionDetection_rkn_k_cylinder_nk_mesh
		xor eax, eax
		jmp collisionDetection_rkn_end
		collisionDetection_rkn_k_cylinder_nk_mesh:
			lea eax, [ebp-16]
			push eax
			lea eax, [ebp-4]
			push eax
			push dword[ebp+12]
			push dword[ebp+8]
			call collisionDetection_resolveCylinderMesh
			mov dword[ebp-20], eax
			
			;invert the resolution direction
			;(it is now pointed as if the cylinder needs to be resolved
			;and the mesh is the non-kinematic)
			xor dword[ebp-16], 0x80000000
			xor dword[ebp-12], 0x80000000
			xor dword[ebp-8], 0x80000000
			
			jmp collisionDetection_rkn_resolve
			
	collisionDetection_rkn_k_mesh:
		mov eax, dword[ebp+12]
		mov ecx, dword[COLLIDER_CYLINDER]
		cmp dword[eax+12], ecx
		je collisionDetection_rkn_k_mesh_nk_cylinder
		xor eax, eax
		jmp collisionDetection_rkn_end
		collisionDetection_rkn_k_mesh_nk_cylinder:
			lea eax, [ebp-16]
			push eax
			lea eax, [ebp-4]
			push eax
			push dword[ebp+8]
			push dword[ebp+12]
			call collisionDetection_resolveCylinderMesh
			mov dword[ebp-20], eax
			
			jmp collisionDetection_rkn_resolve
			
	collisionDetection_rkn_resolve:
	
	;check if there was a collision
	mov eax, dword[ebp-20]
	test eax, eax
	jz collisionDetection_rkn_end
		;change the velocity of the non-kinematic collider
		mov eax, dword[ebp+12]
		add eax, 32
		push eax				;&collider.velocity
		lea eax, [ebp-16]
		push eax				;&resolutionDir
		call vec3_dot
		fstp dword[esp+4]
		lea eax, [ebp-32]
		push eax				;& the resolutionDir component in the velocity
		call vec3_scale
		
		mov eax, dword[ebp+12]
		add eax, 32
		push eax
		push eax
		call vec3_sub
		
		;change the position based on the value of the resolutionDir and penetration
		push dword[ebp-4]
		lea eax, [ebp-16]
		push eax
		push eax
		call vec3_scale
		
		push dword[ebp+12]
		push dword[ebp+12]
		call vec3_add
	
		mov eax, dword[ebp-20]
	
	collisionDetection_rkn_end:
	mov esp, ebp
	pop ebp
	ret
	
	
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
	sub esp, 16			;min resolution dir					;52 (it should have been 12 bytes but who cares)
	sub esp, 4			;temp penetration					;56
	sub esp, 12			;temp resolution dir				;68
	
	
	;check if the bounding boxes intersect
	push dword[ebp+24]
	push dword[ebp+20]
	call collisionDetection_boundsIntersectCylinderMesh
	add esp, 8
	test eax, eax
	jnz collisionDetection_rcm_bounding_boxes_intersect
		xor eax, eax
		jmp collisionDetection_rcm_end
		
	collisionDetection_rcm_bounding_boxes_intersect:
	
	
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
		call vec3_add
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
			push ecx				;tri0
			
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
	
	
	;set outPenetration and outResolutionDir
	mov eax, dword[ebp+28]
	mov ecx, dword[ebp-36]
	mov dword[eax], ecx
	
	mov eax, dword[ebp+32]
	mov ecx, dword[ebp-52]
	mov dword[eax], ecx
	mov ecx, dword[ebp-48]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp-44]
	mov dword[eax+8], ecx
	
	mov eax, 69
	
	collisionDetection_rcm_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
;returns 0 if there is no intersection
;int collisionDetection_bicm(Collider* cylinder, Collider* mesh)
collisionDetection_boundsIntersectCylinderMesh:
	push ebp
	mov ebp, esp
	
	sub esp, 12				;mesh.position-cylinder.position			;12
	sub esp, 12				;cylinder.lowerBound						;24
	sub esp, 12				;cylinder.upperBound						;36
	sub esp, 12				;mesh.lowerBound							;48
	sub esp, 12				;mesh.upperBound							;60
	
	;calculate mesh.position-cylinder.position
	push dword[ebp+8]
	call collider_getPosition
	mov dword[esp], eax
	push dword[ebp+12]
	call collider_getPosition
	mov dword[esp], eax
	lea eax, [ebp-12]
	push eax
	call vec3_sub
	
	;get the bounds
	lea eax, [ebp-36]
	push eax
	lea eax, [ebp-24]
	push eax
	mov eax, dword[ebp+8]
	push dword[eax+28]			;CylinderColliderInfo*
	call cylinderCollider_getBounds
	
	lea eax, [ebp-60]
	push eax
	lea eax, [ebp-48]
	push eax
	mov eax, dword[ebp+12]
	push dword[eax+28]			;MeshColliderInfo*
	call meshCollider_getBounds
	
	;transform the mesh collider bounds into the local space of the cylinder collider
	lea eax, [ebp-12]
	push eax
	lea eax, [ebp-48]
	push eax
	push eax
	call vec3_add
	lea eax, [ebp-60]
	mov dword[esp+4], eax
	mov dword[esp], eax
	call vec3_add
	
	
	;check for intersection
	movss xmm0, dword[ebp-36]
	movss xmm1, dword[ebp-48]
	ucomiss xmm0, xmm1
	ja collisionDetection_boundsIntersectCylinderMesh_pass_1	;cylinder.upperBound.x>mesh.lowerBound.x
		xor eax, eax
		jmp collisionDetection_boundsIntersectCylinderMesh_end
	collisionDetection_boundsIntersectCylinderMesh_pass_1:
	
	movss xmm0, dword[ebp-32]
	movss xmm1, dword[ebp-44]
	ucomiss xmm0, xmm1
	ja collisionDetection_boundsIntersectCylinderMesh_pass_2	;cylinder.upperBound.y>mesh.lowerBound.y
		xor eax, eax
		jmp collisionDetection_boundsIntersectCylinderMesh_end
	collisionDetection_boundsIntersectCylinderMesh_pass_2:
	
	movss xmm0, dword[ebp-28]
	movss xmm1, dword[ebp-40]
	ucomiss xmm0, xmm1
	ja collisionDetection_boundsIntersectCylinderMesh_pass_3	;cylinder.upperBound.z>mesh.lowerBound.z
		xor eax, eax
		jmp collisionDetection_boundsIntersectCylinderMesh_end
	collisionDetection_boundsIntersectCylinderMesh_pass_3:
	
	
	movss xmm0, dword[ebp-24]
	movss xmm1, dword[ebp-60]
	ucomiss xmm0, xmm1
	jb collisionDetection_boundsIntersectCylinderMesh_pass_4	;cylinder.lowerBound.x<mesh.upperBound.x
		xor eax, eax
		jmp collisionDetection_boundsIntersectCylinderMesh_end
	collisionDetection_boundsIntersectCylinderMesh_pass_4:
	
	movss xmm0, dword[ebp-20]
	movss xmm1, dword[ebp-56]
	ucomiss xmm0, xmm1
	jb collisionDetection_boundsIntersectCylinderMesh_pass_5	;cylinder.lowerBound.y<mesh.upperBound.y
		xor eax, eax
		jmp collisionDetection_boundsIntersectCylinderMesh_end
	collisionDetection_boundsIntersectCylinderMesh_pass_5:
	
	movss xmm0, dword[ebp-16]
	movss xmm1, dword[ebp-52]
	ucomiss xmm0, xmm1
	jb collisionDetection_boundsIntersectCylinderMesh_pass_6	;cylinder.lowerBound.z<mesh.upperBound.z
		xor eax, eax
		jmp collisionDetection_boundsIntersectCylinderMesh_end
	collisionDetection_boundsIntersectCylinderMesh_pass_6:
	
	mov eax, 69
	
	collisionDetection_boundsIntersectCylinderMesh_end:
	mov esp, ebp
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
	

;returns 0 if the closest point is not on the end of the line
;assumes that the point is (0,0,0)
;for the vertical collision detection this can be further optimized by assuming that the triangle is horizontal (vec2 operations instead of vec3)
;int collisionDetection_cpolo(
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
		
		mov eax, 69
		
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
		
		mov eax, 69
		
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
	
	xor eax, eax
	
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
	sub esp, 4			;return value of closestPointOnLineOrigo	;60
	sub esp, 4			;temp return value of cpolo					;64
	
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
	mov dword[ebp-60], eax
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
	mov dword[ebp-64], eax	;it's only temp
	add esp, 8				;4 bytes are left on the stack
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
		
		mov ecx, dword[ebp-64]
		mov dword[ebp-60], ecx		;now the return value is final
		
	collisionDetection_rcmHorizontalTriangle_side2_not_closer:
	add esp, 4
	
	
	push dword[ebp+12]
	push dword[ebp+20]
	lea eax, [ebp-40]		;borrowing var40
	push eax
	call collisionDetection_closestPointOnLineOrigo
	mov dword[ebp-64], eax	;it's only temp
	add esp, 8				;4 bytes are left on the stack
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
		
		mov ecx, dword[ebp-64]
		mov dword[ebp-60], ecx		;now the return value is final
		
	collisionDetection_rcmHorizontalTriangle_side3_not_closer:
	add esp, 4
	
	
	;check if the cylinder intersexts with the triangle horizontally
	mov eax, dword[ebp+8]
	mov eax, dword[eax+28]
	mov eax, dword[eax+4]			;cylinder radius
	cmp eax, dword[ebp-28]
	jg collisionDetection_rcmHorizontalTriangle_horizontal_intersection
		;if the point is on the end of the side
		;and not in the radius of the cylinder
		;then it is surely not in the triangle
		cmp dword[ebp-60], 0
		je collisionDetection_rcmHorizontalTriangle_not_end_of_side
			xor eax, eax
			jmp collisionDetection_rcmHorizontalTriangle_end
			
		collisionDetection_rcmHorizontalTriangle_not_end_of_side:
		
		;if the closest point is not in the radius of the cylinder
		;there is still a chance that the cylinder is on the triangle
		;if so, < ( triNormal x closestSide ); closestPoint > will be negative
		mov eax, dword[ebp-44]
		cmp eax, 1
		je collisionDetection_rcmHorizontalTriangle_collision_closest_side_1
		cmp eax, 2
		je collisionDetection_rcmHorizontalTriangle_collision_closest_side_2
		collisionDetection_rcmHorizontalTriangle_collision_closest_side_0:
			push dword[ebp+12]
			push dword[ebp+16]
			lea eax, [ebp-56]
			push eax
			call vec3_sub
			add esp, 12
			jmp collisionDetection_rcmHorizontalTriangle_closest_side_calculated
		
		collisionDetection_rcmHorizontalTriangle_collision_closest_side_1:
			push dword[ebp+16]
			push dword[ebp+20]
			lea eax, [ebp-56]
			push eax
			call vec3_sub
			add esp, 12
			jmp collisionDetection_rcmHorizontalTriangle_closest_side_calculated
			
		collisionDetection_rcmHorizontalTriangle_collision_closest_side_2:
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
	jz collisionDetection_rcmHorizontalTriangle_penetration_pos_y
	collisionDetection_rcmHorizontalTriangle_penetration_neg_y:
		mov eax, dword[ebp+28]		;outPenetration
		movss xmm0, dword[ebp-8]	;cylinder height
		movss xmm1, dword[ebp-12]	;triangle y pos
		subss xmm0, xmm1
		movss dword[eax], xmm0
		jmp collisionDetection_rcmHorizontalTriangle_penetration_done
		
	collisionDetection_rcmHorizontalTriangle_penetration_pos_y:
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
	
	
	
;returns non-zero if a collision has happened	
;expects the tri0, tri1 and tri2 to be in the local space of the cylinder (the position of the cylinder is (0,0,0) )
;int collisionDetection_rcmVerticalTriangle(
;	Collider* cylinder,
;	vec3* tri0,
;	vec3* tri1,
;	vec3* tri2,
;	vec3* triNormal,
;	float* outPenetration,
;	vec3* outResolutionDir
;)
collisionDetection_rcmVerticalTriangle:
	push ebp
	mov ebp, esp
	
	mov esp, ebp
	pop ebp
	ret
	
	
;calculates the closest point on a line to a point ( (0,0,0) ) as if they were projected onto the XZ plane (y component is ignore)
;and then returns the point as a vec3 with the correct y coordinate
;returns 0 if the closest point is not on the end of the line
;returns 1 if the closest point is on the end of the line
;returns -1 if the line is vertical
;assumes that the point (from which the distance is calculated) is (0,0,0)
;int collisionDetection_cpolo2d(
;	vec3* buffer,
;	vec3* line0,
;	vec3* line1,
;	vec3* normal			//same as the triangle normal (the normal direction is not eindeutig just from line0 and line1)
;)
collisionDetection_closestPointOnLineOrigo2d:
	push ebp
	mov ebp, esp
	
	sub esp, 8			;vec3 dir = line0.xz-line1.xz								;8
	sub esp, 4			;<line0.xz; dir>											;12
	sub esp, 4			;<line1.xz; dir>											;16
	sub esp, 8			;closestPoint.xz											;24
	sub esp, 4			;ratio=|closestPoint.xz-line1.xz|/|line0.xz-line1.xz|		;28
	
	;calculate dir
	mov eax, dword[ebp+12]			;line0 in eax
	mov ecx, dword[ebp+16]			;line1 in ecx
	
	fld dword[eax]
	fld dword[ecx]
	fsubp
	fstp dword[ebp-8]
	
	fld dword[eax+8]
	fld dword[ecx+8]
	fsubp
	fstp dword[ebp-4]
	
	;check if the line is vertical
	mov edx, dword[ebp-8]
	and edx, 0x7fffffff
	cmp edx, dword[EPSILON]
	jg collisionDetection_cpolo2d_not_vertical
	mov edx, dword[ebp-4]
	and edx, 0x7fffffff
	cmp edx, dword[EPSILON]
	jg collisionDetection_cpolo2d_not_vertical
		mov eax, 2
		jmp collisionDetection_closestPointOnLineOrigo2d_end
		
	collisionDetection_cpolo2d_not_vertical:
	
	;calculate <line0.xz; dir>
	fld dword[eax]				;line0 is still in eax!!!
	fld dword[ebp-8]
	fmulp
	fld dword[eax+8]
	fld dword[ebp-4]
	fmulp
	faddp
	fstp dword[ebp-12]
	test dword[ebp-12], 0x80000000
	jz collisionDetection_cpolo2d_not_beyond_line_0		;the dot product is negative, line0 is obviously the closest point
		mov eax, dword[ebp+8]
		mov ecx, dword[ebp+12]
		mov edx, dword[ecx]
		mov dword[eax], edx
		mov edx, dword[ecx+4]
		mov dword[eax+4], edx
		mov edx, dword[ecx+8]
		mov dword[eax+8], edx
		
		mov eax, 1
		
		jmp collisionDetection_closestPointOnLineOrigo2d_end
	
	collisionDetection_cpolo2d_not_beyond_line_0:
	
	;calculate <line1.xz; dir>
	fld dword[ecx]			;line1 is still in ecx!!!
	fld dword[ebp-8]
	fmulp
	fld dword[ecx+8]
	fld dword[ebp-4]
	fmulp
	faddp
	fstp dword[ebp-16]
	test dword[ebp-16], 0x80000000
	test dword[ebp-20], 0x80000000
	jnz collisionDetection_cpolo2d_not_beyond_line1	;if the dot product is non-negative, line1 is obviously the closest point
		mov eax, dword[ebp+8]
		mov ecx, dword[ebp+16]
		mov edx, dword[ecx]
		mov dword[eax], edx
		mov edx, dword[ecx+4]
		mov dword[eax+4], edx
		mov edx, dword[ecx+8]
		mov dword[eax+8], edx
		
		mov eax, 1
		
		jmp collisionDetection_closestPointOnLineOrigo2d_end
		
	collisionDetection_cpolo2d_not_beyond_line1:
	
	;get the closest point on the XZ plane projection
	;closestPoint.xz=point.xz-<(point.xz-line1.xz);triNormal.xz>*triNormal.xz=
	;=-<-line1.xz;triNormal.xz>*triNormal.xz=
	;=<line1.xz;triNormal.xz>*triNormal.xz
	mov edx, dword[ebp+20]				;normal in edx
	fld dword[ecx]						;line1 is still in ecx!!!
	fld dword[edx]
	fmulp
	fld dword[ecx+8]
	fld dword[edx+8]
	fmulp
	faddp
	
	fld dword[edx]
	fmul st0, st1
	fstp dword[ebp-24]
	fld dword[edx+8]
	fmul st0, st1
	fstp dword[ebp-20]
	sub esp, 4
	fstp dword[esp]
	add esp, 4
	
	
	;get the y coordinate of the closest point
	;first the ratio in which the closest point slices the line has to be obtained
	;|closestPoint.xz-line1.xz|/|line0.xz-line1.xz|
	fld dword[ebp-24]
	fld dword[ecx]			;line1 is still in ecx!!!
	fsubp
	fmul st0, st0
	fld dword[ebp-20]
	fld dword[ecx+8]
	fsubp
	fmul st0, st0
	faddp
	fsqrt					;|closestPoint.xz-line1.xz| is on the fpu stack
	
	fld dword[eax]			;line0 is still in eax!!!
	fld dword[ecx]
	fsubp
	fmul st0, st0
	fld dword[eax+8]
	fld dword[ecx+8]
	fsubp
	fmul st0, st0
	faddp
	fsqrt
	
	fdivp
	fstp dword[ebp-28]
	
	
	;calculate the closestPoint with the actual y value
	;closestPoint=ratio*(line0-line1)+line1
	fld dword[eax+4]				;line0 is still in eax!!!
	fld dword[ecx+4]				;line1 is still in ecx!!!
	fsubp
	
	mov eax, dword[ebp+8]			;buffer in eax
	
	mov edx, dword[ebp-24]
	mov dword[eax], edx				;line0.x-line1.x
	fstp dword[eax+4]				;line0.y-line1.y
	mov edx, dword[ebp-20]
	mov dword[eax+8], edx			;line0.z-line1.z
	
	
	push dword[ebp+28]
	push dword[ebp+8]
	push dword[ebp+8]
	call vec3_scale
	
	push dword[ebp+16]
	push dword[ebp+8]
	push dword[ebp+8]
	call vec3_add
	
	
	xor eax, eax
	
	collisionDetection_closestPointOnLineOrigo2d_end:
	mov esp, ebp
	pop ebp
	ret