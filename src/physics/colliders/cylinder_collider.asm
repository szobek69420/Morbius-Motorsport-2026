[BITS 32]

;layout:
;struct CylinderColliderInfo{
;	float height;			;0		//the height of the cylinder in both the positive and negative direction on the y-axis (overall height is 2*height)
;	float radius;			;4
;//bounds are in the local space of the collider
;	vec3 lowerBound;		;8
;	vec3 upperBound;		;20
;} 32 bytes overall

section .text use32
	global cylinderCollider_createInfo			;CylinderColliderInfo* cylinderCollider_createInfo(float height, float radius)
	global cylinderCollider_destroyInfo			;void cylinderCollider_destroyInfo(CylinderColliderInfo* cci)
	
	global cylinderCollider_getBounds			;void cylinderCollider_getBounds(CylinderColliderInfo* cci, vec3* lowerBoundBuffer, vec3* upperBoundBuffer)
	
	extern my_malloc
	extern my_free
	
cylinderCollider_createInfo:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;CylinderColliderInfo*
	
	;alloc space for info
	push 32
	call my_malloc
	mov dword[ebp-4], eax
	
	;init the info
	mov eax, dword[ebp-4]
	mov ecx, dword[ebp+8]			;height
	mov dword[eax], ecx
	mov ecx, dword[ebp+12]			;radius
	mov dword[eax+4], ecx
	
	;set the bounds
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp+8]
	and ecx, 0x7fffffff				;|height| in ecx
	mov dword[eax+24], ecx			;upperBound.y
	or ecx, 0x80000000				;-|height| in ecx
	mov dword[eax+12], ecx			;lowerBound.y
	
	mov ecx, dword[ebp+12]			;radius
	and ecx, 0x7fffffff				;|radius| in ecx
	mov dword[eax+20], ecx			;upperBound.x
	mov dword[eax+28], ecx			;upperBound.z
	or ecx, 0x80000000				;-|radius| in ecx
	mov dword[eax+8], ecx			;lowerBound.x
	mov dword[eax+16], ecx			;lowerBound.z
	
	
	;set the return value
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
	
	
cylinderCollider_getBounds:
	mov eax, dword[esp+4]			;CylinderColliderInfo* in eax
	
	mov ecx, dword[esp+8]			;lowerBoundBuffer in ecx
	mov edx, dword[eax+8]
	mov dword[ecx], edx
	mov edx, dword[eax+12]
	mov dword[ecx+4], edx
	mov edx, dword[eax+16]
	mov dword[ecx+8], edx
	
	mov ecx, dword[esp+12]			;upperBoundBuffer in ecx
	mov edx, dword[eax+20]
	mov dword[ecx], edx
	mov edx, dword[eax+24]
	mov dword[ecx+4], edx
	mov edx, dword[eax+28]
	mov dword[ecx+8], edx
	
	ret