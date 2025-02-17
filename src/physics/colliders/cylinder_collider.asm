[BITS 32]

;layout:
;struct CylinderColliderInfo{
;	float height;			;0
;	float radius;			;4
;} 8 bytes overall

section .text use32
	global cylinderCollider_createInfo			;CylinderColliderInfo* cylinderCollider_createInfo(float height, float radius)
	global cylinderCollider_destroyInfo			;void cylinderCollider_destroyInfo(CylinderColliderInfo* cci)
	
	extern my_malloc
	extern my_free
	
cylinderCollider_createInfo:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;CylinderColliderInfo*
	
	;alloc space for info
	push 8
	call my_malloc
	mov dword[ebp-4], eax
	
	;init the info
	mov eax, dword[ebp-4]
	mov ecx, dword[ebp+8]			;height
	mov dword[eax], ecx
	mov ecx, dword[ebp+12]			;radius
	mov dword[eax+4], ecx
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
cylinderCollider_destroyInfo:
	mov eax, dword[esp+4]
	push eax
	call my_free
	add esp, 4
	ret