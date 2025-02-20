[BITS 32]

;layout
;struct MeshColliderInfo{
;	vec3* triangleVertices;			;0		// 1 vec3/vertex
;	int* triangleIndices;			;4
;	vec3* triangleNormals;			;8		//calculated from the vertex data, 1 vec3/triangle
;	int vertexCount;				;12
;	int triangleCount;				;16		//NOT INDEX COUNT!!!
;}		20 bytes overall

section .rodata use32
	print_int_nl db "%d",10,0
	print_three_ints_three_floats_nl db "%d %d %d %f %f %f",10,0
	
	print_vertex_count db "vertex count: %d",10,0
	print_triangle_count db "triangle count: %d",10,0
	
	test_text db "globus",10,0
	
section .text use32
	
	global meshCollider_createInfo			;MeshColliderInfo* meshCollider_createInfo(vec3* vertices, int* indices, int vertexCount, int indexCount)
	global meshCollider_destroyInfo			;void meshCollider_destroyInfo(MeshColliderInfo* mci)

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
	push 20
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