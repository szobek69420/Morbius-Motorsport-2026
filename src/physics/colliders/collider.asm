[BITS 32]

;layout
;struct Collider{
;	vec3 position;							;0
;	int colliderType;						;12
;	int tag;								;16
;	Collider* lastCollision;				;20
;	void (*)(ColliderInfo*)	destructor;		;24
;	union{									;28
;		CylinderColliderInfo* cylinderData;
;		MeshColliderInfo* meshData;
;	}
;}		32 bytes overall

section .rodata use32
	global COLLIDER_CYLINDER
	global COLLIDER_MESH
	COLLIDER_CYLINDER dd 1
	COLLIDER_MESH dd 2
	
	error_not_initialized_cylinder db "collider_createCylinder: collider system is not initialized",10,0
	error_not_initialized_mesh db "collider_createMesh: collider system is not initialized",10,0
	
	print_remaining_collider_count db "collider_deinit: remaining collider count is %d",10,0
	
	
section .data use32
	is_initialized dd 0
	
section .bss use32 
	loaded_colliders resb 16			;vector<Collider*>

section .text use32
	
	global collider_init						;void collider_init()
	global collider_deinit						;void collider_deinit()
	
	global collider_createCylinder				;Collider* collider_createCylinder(float height, float radius)
	global collider_createMesh					;Collider* collider_createMesh(vec3* vertices, int* indices, int vertexCount, int indexCount)
	
	global collider_destroy						;void collider_destroy(Collider* collider)
	
	extern my_printf	
	extern my_malloc
	extern my_free
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove
	
	extern cylinderCollider_createInfo
	extern cylinderCollider_destroyInfo
	
	extern meshCollider_createInfo
	extern meshCollider_destroyInfo
	
	
collider_init:
	push ebp
	mov ebp, esp
	
	;init loaded collider vector
	push 4
	push loaded_colliders
	call vector_init
	
	
	;mark as initialized
	mov dword[is_initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	
	
collider_deinit:
	push ebp
	mov ebp, esp
	
	;print the remaining collider count
	push dword[loaded_colliders]
	push print_remaining_collider_count
	call my_printf
	
	;destroy the remaining colliders
	cmp dword[loaded_colliders], 0
	je collider_deinit_destroy_loop_end			;there are no remaining colliders
	collider_deinit_destroy_loop_start:
		mov eax, loaded_colliders
		mov eax, dword[eax+12]
		push dword[eax]
		call collider_destroy
		add esp, 4
		
		cmp dword[loaded_colliders], 0
		jg collider_deinit_destroy_loop_start
		
	collider_deinit_destroy_loop_end:
	
	
	;destroy the loaded colliders vector
	push loaded_colliders
	call vector_destroy
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
collider_createCylinder:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;Collider*
	
	;check if the collider is initialized
	cmp dword[is_initialized], 0
	jne collider_createCylinder_initialized
		push error_not_initialized_cylinder
		call my_printf
		xor eax, eax
		jmp collider_createCylinder_end
	
	collider_createCylinder_initialized:
	
	;alloc space for collider
	push 32
	call my_malloc
	mov dword[ebp-4], eax
	
	
	mov ecx, dword[ebp-4]
	
	;set position
	mov dword[ecx], 0
	mov dword[ecx+4], 0
	mov dword[ecx+8], 0
	
	;set type
	mov eax, dword[COLLIDER_CYLINDER]
	mov dword[ecx+12], eax
	
	;set tag
	mov dword[ecx+16], 0
	
	;set lastCollision
	mov dword[ecx+20], 0
	
	;set destructor
	mov dword[ecx+24], cylinderCollider_destroyInfo
	
	;set info
	push dword[ebp+12]
	push dword[ebp+8]
	call cylinderCollider_createInfo
	mov ecx, dword[ebp-4]
	mov dword[ecx+28], eax
	
	
	;add collider to loaded colliders
	push dword[ebp-4]
	push loaded_colliders
	call vector_push_back
	
	;set return value
	mov eax, dword[ebp-4]
	
	collider_createCylinder_end:
	mov esp, ebp
	pop ebp
	ret
	
	
collider_createMesh:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;Collider*
	
	
	;check if the collider is initialized
	cmp dword[is_initialized], 0
	jne collider_createMesh_initialized
		push error_not_initialized_mesh
		call my_printf
		xor eax, eax
		jmp collider_createMesh_end
	
	collider_createMesh_initialized:
	
	
	
	;alloc space for collider
	push 32
	call my_malloc
	mov dword[ebp-4], eax
	
	
	mov ecx, dword[ebp-4]
	
	;set position
	mov dword[ecx], 0
	mov dword[ecx+4], 0
	mov dword[ecx+8], 0
	
	;set type
	mov eax, dword[COLLIDER_MESH]
	mov dword[ecx+12], eax
	
	;set tag
	mov dword[ecx+16], 0
	
	;set lastCollision
	mov dword[ecx+20], 0
	
	;set destructor
	mov dword[ecx+24], meshCollider_destroyInfo
	
	;set info
	push dword[ebp+20]
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[ebp+8]
	call meshCollider_createInfo
	mov ecx, dword[ebp-4]
	mov dword[ecx+28], eax
	
	
	;add collider to loaded colliders
	push dword[ebp-4]
	push loaded_colliders
	call vector_push_back
	
	;set return value
	mov eax, dword[ebp-4]
	
	
	collider_createMesh_end:
	mov esp, ebp
	pop ebp
	ret
	
	
collider_destroy:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;collider*
	
	mov ecx, dword[ebp+8]
	mov dword[ebp-4], ecx
	
	;destroy info
	mov eax, dword[ebp+8]
	push dword[eax+28]
	call dword[eax+24]
	
	;dealloc collider
	push dword[ebp+8]
	call my_free
	
	;remove collider from the loaded colliders
	push dword[ebp-4]
	push loaded_colliders
	call vector_remove
	
	mov esp, ebp
	pop ebp
	ret