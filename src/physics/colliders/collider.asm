[BITS 32]

;layout
;struct Collider{
;	vec3 position;							;0
;	int colliderType;						;12
;	void (*)(ColliderInfo*)	destructor;		;16
;	union{									;20
;		CylinderColliderInfo* cylinderData;
;		MeshColliderInfo* meshData;
;	}
;}		24 bytes overall

section .rodata use32
	global COLLIDER_CYLINDER
	global COLLIDER_MESH
	COLLIDER_CYLINDER dd 1
	COLLIDER_MESH dd 2

section .text use32
	
	global collider_createCylinder				;Collider* collider_createCylinder(float height, float radius)
	global collider_createMesh					;Collider* collider_createMesh(vec3* vertices, int* indices, int vertexCount, int indexCount)
	
	global collider_destroy						;void collider_destroy(Collider* collider)
	
	extern my_malloc
	extern my_free
	
	extern cylinderCollider_createInfo
	extern cylinderCollider_destroyInfo
	
	extern meshCollider_createInfo
	extern meshCollider_destroyInfo
	
collider_createCylinder:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;Collider*
	
	;alloc space for collider
	push 24
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
	
	;set destructor
	mov dword[ecx+16], cylinderCollider_destroyInfo
	
	;set info
	push dword[ebp+12]
	push dword[ebp+8]
	call cylinderCollider_createInfo
	mov ecx, dword[ebp-4]
	mov dword[ecx+20], eax
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
collider_createMesh:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;Collider*
	
	;alloc space for collider
	push 24
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
	
	;set destructor
	mov dword[ecx+16], meshCollider_destroyInfo
	
	;set info
	push dword[ebp+20]
	push dword[ebp+16]
	push dword[ebp+12]
	push dword[ebp+8]
	call meshCollider_createInfo
	mov ecx, dword[ebp-4]
	mov dword[ecx+20], eax
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
collider_destroy:
	push ebp
	mov ebp, esp
	
	;destroy info
	mov eax, dword[ebp+8]
	push dword[eax+20]
	call dword[eax+16]
	
	;dealloc collider
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret