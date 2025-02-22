[BITS 32]

;layout
;struct MeshColliderInfo{
;	vec3* triangleVertices;			;0		// 1 vec3/vertex
;	int* triangleIndices;			;4
;	vec3* triangleNormals;			;8		//calculated from the vertex data, 1 vec3/triangle
;	int vertexCount;				;12
;	int triangleCount;				;16		//NOT INDEX COUNT!!!
;//bounds are in the local space of the collider
;	vec3 lowerBound;				;20
;	vec3 upperBound;				;32
;}		44 bytes overall

section .rodata use32
	print_int_nl db "%d",10,0
	print_three_ints_nl db "%d %d %d",10,0
	print_three_ints_three_floats_nl db "%d %d %d %f %f %f",10,0
	
	print_vertex_count db "vertex count: %d",10,0
	print_triangle_count db "triangle count: %d",10,0
	
	test_text db "globus",10,0
	
section .text use32
	
	global meshCollider_createInfo			;MeshColliderInfo* meshCollider_createInfo(vec3* vertices, int* indices, int vertexCount, int indexCount)
	global meshCollider_destroyInfo			;void meshCollider_destroyInfo(MeshColliderInfo* mci)

	global meshCollider_getBounds			;void meshCollider_getBounds(MeshColliderInfo* mci, vec3* lowerBoundBuffer, vec3* upperBoundBuffer)

	extern vec3_sub
	extern vec3_cross
	extern vec3_normalize
	extern vec3_print
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcpy

meshCollider_createInfo:
	push ebp
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 4			;MeshColliderInfo*					;-4
	sub esp, 4			;vec3* vertices						;-8
	sub esp, 4			;int* indices						;-12
	sub esp, 4			;vec3* normals						;-16
	sub esp, 12			;tri[2]-tri[1]						;-28
	sub esp, 12			;tri[0]-tri[1]						;-40
	
	;alloc mesh collider info
	push 44
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;alloc arrays
	mov eax, dword[ebp+24]
	imul eax, 12
	push eax
	call my_malloc
	mov dword[ebp-8], eax
	add esp, 4
	
	mov eax, dword[ebp+28]
	shl eax, 2
	push eax
	call my_malloc
	mov dword[ebp-12], eax
	add esp, 4
	
	mov eax, dword[ebp+28]
	shl eax, 2		;12 bytes * faceCount = 4 bytes * (3*faceCount) = 4 bytes * indexCount
	push eax
	call my_malloc
	mov dword[ebp-16], eax
	add esp, 4
	
	
	;copy the vertices and indices
	mov eax, dword[ebp+24]
	imul eax, 12
	push eax
	push dword[ebp+16]
	push dword[ebp-8]
	call my_memcpy
	add esp, 12
	
	mov eax, dword[ebp+28]
	shl eax, 2
	push eax
	push dword[ebp+20]
	push dword[ebp-12]
	call my_memcpy
	add esp, 12
	
	;calculate the normals
	xor esi, esi					;index index in esi
	mov edi, dword[ebp-12]			;current position in index array in edi
	cmp dword[ebp+28], 0
	je meshCollider_createInfo_normal_loop_end
	meshCollider_createInfo_normal_loop_start:
		;calculate the sides
		mov eax, dword[edi+4]
		imul eax, 12
		add eax, dword[ebp-8]
		push eax					;&triangle[1]
		mov eax, dword[edi+8]
		imul eax, 12
		add eax, dword[ebp-8]
		push eax					;&triangle[2]
		lea eax, [ebp-28]
		push eax
		call vec3_sub				;tri[2]-tri[1]
		add esp, 8					;&triangle[1] stays on the stack
		mov eax, dword[edi]
		imul eax, 12
		add eax, dword[ebp-8]
		push eax					;&triangle[0]
		lea eax, [ebp-40]
		push eax
		call vec3_sub				;tri[0]-tri[1]
		add esp, 12
		
		
		;normal
		mov ecx, esi
		shl ecx, 2			;offset in normal array = (index/3)*12 = 4*index
		add ecx, dword[ebp-16]
		
		lea eax, [ebp-40]
		push eax
		lea eax, [ebp-28]
		push eax
		push ecx
		call vec3_cross
		call vec3_normalize
		add esp, 12
		
		
		;continue
		add edi, 12
		add esi, 3
		cmp esi, dword[ebp+28]
		jl meshCollider_createInfo_normal_loop_start
		
	meshCollider_createInfo_normal_loop_end:
	
	;set the data
	mov eax, dword[ebp-4]			;mci*
	
	mov ecx, dword[ebp-8]
	mov dword[eax], ecx				;vertices
	mov ecx, dword[ebp-12]
	mov dword[eax+4], ecx			;indices
	mov ecx, dword[ebp-16]
	mov dword[eax+8], ecx			;normals
	
	mov ecx, dword[ebp+24]
	mov dword[eax+12], ecx			;vertex count
	
	mov eax, dword[ebp+28]
	xor edx, edx
	mov ecx, 3
	idiv ecx
	mov ecx, dword[ebp-4]
	mov dword[ecx+16], eax			;triangle count
	
	
	;calculate the bounds
	mov eax, dword[ebp-4]
	cmp dword[eax+12], 0			;vertex count is zero
	jne meshCollider_createInfo_calculate_bounds
		mov dword[eax+20], 0		;lowerBound=0
		mov dword[eax+24], 0
		mov dword[eax+28], 0
		mov dword[eax+32], 0		;upperBound=0
		mov dword[eax+36], 0
		mov dword[eax+40], 0
		jmp meshCollider_createInfo_calculate_bounds_done
		
	meshCollider_createInfo_calculate_bounds:
	
	mov dword[eax+20], 0x7f800000	;lowerBound=vec3(+Infinity)
	mov dword[eax+24], 0x7f800000
	mov dword[eax+28], 0x7f800000
	mov dword[eax+32], 0xff800000	;upperBound=vec3(-Infinity)
	mov dword[eax+36], 0xff800000
	mov dword[eax+40], 0xff800000
	
	mov esi, dword[eax]				;current vertex in esi
	mov edi, dword[eax+12]			;vertex count in edi
	meshCollider_createInfo_calculate_bounds_loop_start:
		;vertex.x<lowerBound.x?
		movss xmm0, dword[esi]
		movss xmm1, dword[eax+20]
		ucomiss xmm0, xmm1
		jae meshCollider_createInfo_calculate_bounds_loop_lower_x_done
			movss dword[eax+20], xmm0
		meshCollider_createInfo_calculate_bounds_loop_lower_x_done:
		
		;vertex.y<lowerBound.y?
		movss xmm0, dword[esi+4]
		movss xmm1, dword[eax+24]
		ucomiss xmm0, xmm1
		jae meshCollider_createInfo_calculate_bounds_loop_lower_y_done
			movss dword[eax+24], xmm0
		meshCollider_createInfo_calculate_bounds_loop_lower_y_done:
		
		;vertex.z<lowerBound.z?
		movss xmm0, dword[esi+8]
		movss xmm1, dword[eax+28]
		ucomiss xmm0, xmm1
		jae meshCollider_createInfo_calculate_bounds_loop_lower_z_done
			movss dword[eax+28], xmm0
		meshCollider_createInfo_calculate_bounds_loop_lower_z_done:
		
		
		;vertex.x>upperBound.x?
		movss xmm0, dword[esi]
		movss xmm1, dword[eax+32]
		ucomiss xmm0, xmm1
		jbe meshCollider_createInfo_calculate_bounds_loop_upper_x_done
			movss dword[eax+32], xmm0
		meshCollider_createInfo_calculate_bounds_loop_upper_x_done:
		
		;vertex.y>upperBound.y?
		movss xmm0, dword[esi+4]
		movss xmm1, dword[eax+36]
		ucomiss xmm0, xmm1
		jbe meshCollider_createInfo_calculate_bounds_loop_upper_y_done
			movss dword[eax+36], xmm0
		meshCollider_createInfo_calculate_bounds_loop_upper_y_done:
		
		;vertex.z>upperBound.z?
		movss xmm0, dword[esi+8]
		movss xmm1, dword[eax+40]
		ucomiss xmm0, xmm1
		jbe meshCollider_createInfo_calculate_bounds_loop_upper_z_done
			movss dword[eax+40], xmm0
		meshCollider_createInfo_calculate_bounds_loop_upper_z_done:
		
		
		add esi, 12
		dec edi
		test edi, edi
		jnz meshCollider_createInfo_calculate_bounds_loop_start
	
	meshCollider_createInfo_calculate_bounds_done:
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop edi
	pop esi
	pop ebp
	ret
	
	
meshCollider_destroyInfo:
	;dealloc arrays
	mov eax, dword[esp+4]
	cmp dword[eax], 0
	je meshCollider_destroyInfo_no_vertices
		push dword[eax]
		call my_free
		add esp, 4
	meshCollider_destroyInfo_no_vertices:
	
	mov eax, dword[esp+4]
	cmp dword[eax+4], 0
	je meshCollider_destroyInfo_no_indices
		push dword[eax+4]
		call my_free
		add esp, 4
	meshCollider_destroyInfo_no_indices:
	
	mov eax, dword[esp+4]
	cmp dword[eax+8], 0
	je meshCollider_destroyInfo_no_bitches
		push dword[eax+8]
		call my_free
		add esp, 4
	meshCollider_destroyInfo_no_bitches:
	
	;dealloc meshcolliderinfo
	mov eax, dword[esp+4]
	push eax
	call my_free
	add esp, 4
	
	ret
	
	
	
meshCollider_getBounds:
	mov eax, dword[esp+4]			;MeshColliderInfo* in eax
	
	mov ecx, dword[esp+8]			;lowerBoundBuffer in ecx
	mov edx, dword[eax+20]
	mov dword[ecx], edx
	mov edx, dword[eax+24]
	mov dword[ecx+4], edx
	mov edx, dword[eax+28]
	mov dword[ecx+8], edx
	
	mov ecx, dword[esp+12]			;upperBoundBuffer in ecx
	mov edx, dword[eax+32]
	mov dword[ecx], edx
	mov edx, dword[eax+36]
	mov dword[ecx+4], edx
	mov edx, dword[eax+40]
	mov dword[ecx+8], edx
	
	ret