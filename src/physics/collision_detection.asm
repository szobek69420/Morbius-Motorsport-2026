[BITS 32]

section .rodata use32
	EPSILON dd 0.00001

section .text use32

	;returns non-zero if a collision happened
	;only supports mesh colliders with horizontal and vertical normals
	global collisionDetection_collisionCylinderMesh		;int cd_cCylinderMesh(Collider* cylinder, Collider* mesh)
	
	extern vec3_sub
	extern vec3_add
	extern vec3_dot
	extern vec3_normalize
	extern vec3_scale
	extern vec3_print
	
	
collisionDetection_collisionCylinderMesh:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	push test_line0
	push test_line1
	push test_point
	push test_vec3
	call collisionDetection_closestPointOnLine
	call vec3_print
	
	collisionDetection_ccm_end:
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
	
	
;int collisionDetection_ccmVerticalCollision(
collisionDetection_ccmVerticalCollision: