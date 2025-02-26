[BITS 32]

;layout:
;struct HyperPlane{
;	vec4 pointOnPlane;		0
;	vec4 directionVector1;	16
;	vec4 directionVector2;	32
;	vec4 directionVector3;	48
;}		64 bytes overall

section .rodata use32
	ZERO dd 0.0
	ONE dd 1.0

section .text use32

	global hyperPlane_create		;void hyperPlane_create(HyperPlane* buffer)
	
	global hyperPlane_getNormal		;void hyperPlane_getNormal(HyperPlane* hp, vec4* buffer)
	
	;rotates the plane
	;rotationPlaneDir1 and rotationPlaneDir2 must be orthogoonal
	global hyperPlane_rotate			;void hyperPlane_rotate(HyperPlane* hp, vec4* rotationPlaneDir1, vec4* rotationPlaneDir2, float angleInDegrees)
	
	;moves the point of the hyperplane along the based vectors of the hyperplane
	global hyperPlane_moveInsideOfPlane	;void hyperPlane_moveInsideOfPlane(HyperPlane* hp, vec3* movement)
	
	extern my_memset
	
	extern vec4_add
	extern vec4_scale
	extern vec4_cross
	extern vec4_rotateAroundPlane
	
hyperPlane_create:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;buffer in eax
	
	push 64
	push 0
	push eax
	call my_memset
	pop eax
	add esp, 8
	
	mov ecx, dword[ONE]
	mov dword[eax+16], ecx
	mov dword[eax+36], ecx
	mov dword[eax+56], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
hyperPlane_getNormal:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;HyperPlane* in eax
	
	lea ecx, [eax+48]
	push ecx
	lea ecx, [eax+32]
	push ecx
	lea ecx, [eax+16]
	push ecx
	push dword[ebp+12]
	call vec4_cross
	
	mov esp, ebp
	pop ebp
	ret
	
	
hyperPlane_rotate:
	push ebp
	mov ebp, esp
	
	
	push dword[ebp+20]
	push dword[ebp+16]
	push dword[ebp+12]
	
	mov eax, dword[ebp+8]
	lea ecx, [eax+16]
	push ecx
	call vec4_rotateAroundPlane
	
	mov eax, dword[ebp+8]
	lea ecx, [eax+32]
	mov dword[esp], ecx
	call vec4_rotateAroundPlane
	
	mov eax, dword[ebp+8]
	lea ecx, [eax+48]
	mov dword[esp], ecx
	call vec4_rotateAroundPlane
	
	mov esp, ebp
	pop ebp
	ret
	
	
hyperPlane_moveInsideOfPlane:
	push ebp
	mov ebp, esp
	
	sub esp, 16					;temp vector
	
	;first component
	mov eax, dword[ebp+12]
	push dword[eax]
	mov eax, dword[ebp+8]
	lea eax, [eax+16]
	push eax
	lea eax, [ebp-16]
	push eax
	call vec4_scale
	
	push dword[ebp+8]
	push dword[ebp+8]			;&hyperPlane.position
	call vec4_add
	
	
	;second component
	mov eax, dword[ebp+12]
	push dword[eax+4]
	mov eax, dword[ebp+8]
	lea eax, [eax+32]
	push eax
	lea eax, [ebp-16]
	push eax
	call vec4_scale
	
	push dword[ebp+8]
	push dword[ebp+8]			;&hyperPlane.position
	call vec4_add
	
	
	;third component
	mov eax, dword[ebp+12]
	push dword[eax+8]
	mov eax, dword[ebp+8]
	lea eax, [eax+48]
	push eax
	lea eax, [ebp-16]
	push eax
	call vec4_scale
	
	push dword[ebp+8]
	push dword[ebp+8]			;&hyperPlane.position
	call vec4_add
	
	
	
	mov esp, ebp
	pop ebp
	ret