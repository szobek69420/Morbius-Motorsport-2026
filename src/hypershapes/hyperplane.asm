[BITS 32]

;layout:
;struct HyperPlane{
;	vec4 pointOnPlane;		0
;	vec4 directionVector1;	16
;	vec4 directionVector2;	32
;	vec4 directionVector3;	48
;}		64 bytes overall

;A, B, C, D and E are scalars so that A*x+B*y+C*z+D*w+E=distance of (x,y,z,w) from the plane
;struct HyperPlaneEquation{
;	float A, B, C, D, E;
;};		20 bytes overall

section .rodata use32
	ZERO dd 0.0
	ONE dd 1.0

section .text use32

	global hyperPlane_create		;void hyperPlane_create(HyperPlane* buffer)
	
	global hyperPlane_getNormal		;void hyperPlane_getNormal(HyperPlane* hp, vec4* buffer)
	
	;the following four functions handle overlapping direction/position and result buffers wells
	global hyperPlane_directionTo4d		;void hyperPlane_directionTo4d(HyperPlane* hp, vec3* direction, vec4* buffer)
	global hyperPlane_positionTo4d		;void hyperPlane_positionTo4d(HyperPlane* hp, vec3* position, vec4* buffer) //basically it adds the position of the hyperplane point to the end result
	global hyperPlane_directionTo3d		;void hyperPlane_directionTo3d(HyperPlane* hp, vec4* direction, vec3* buffer)
	global hyperPlane_positionTo3d		;void hyperPlane_positionTo3d(HyperPlane* hp, vec4* position, vec3* buffer) //the position of the hyperplane point is added to the position
	
	;rotates the plane
	;rotationPlaneDir1 and rotationPlaneDir2 must be orthogoonal
	global hyperPlane_rotate			;void hyperPlane_rotate(HyperPlane* hp, vec4* rotationPlaneDir1, vec4* rotationPlaneDir2, float angleInDegrees)
	
	;moves the point of the hyperplane along the based vectors of the hyperplane
	global hyperPlane_moveInsideOfPlane	;void hyperPlane_moveInsideOfPlane(HyperPlane* hp, vec3* movement)
	
	global hyperPlane_getEquation		;void hyperPlane_getEquation(HyperPlane* hp, HyperPlaneEquation* buffer)
	
	;pushes the return value onto the FPU stack
	global hyperPlane_signedDistance	;float hyperPlane_signedDistance(HyperPlaneEquation* hpe, vec4* point)
	
	
	extern my_memset
	
	extern vec4_add
	extern vec4_sub
	extern vec4_scale
	extern vec4_dot
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
	
hyperPlane_directionTo4d:
	push ebp
	mov ebp, esp
	
	sub esp, 16			;temp
	sub esp, 16			;result
	
	mov ecx, dword[ebp+8]
	add ecx, 16
	mov eax, dword[ebp+12]
	push dword[eax]
	push ecx
	lea eax, [ebp-32]
	push eax
	call vec4_scale
	
	mov ecx, dword[ebp+8]
	add ecx, 32
	mov eax, dword[ebp+12]
	push dword[eax+4]
	push ecx
	lea eax, [ebp-16]
	push eax
	call vec4_scale
	lea ecx, [ebp-16]
	push ecx
	lea eax, [ebp-32]
	push eax
	push eax
	call vec4_add
	
	mov ecx, dword[ebp+8]
	add ecx, 48
	mov eax, dword[ebp+12]
	push dword[eax+8]
	push ecx
	lea eax, [ebp-16]
	push eax
	call vec4_scale
	lea ecx, [ebp-16]
	push ecx
	lea eax, [ebp-32]
	push eax
	push eax
	call vec4_add
	
	;copy the results into the results buffer
	mov eax, dword[ebp+16]
	
	mov ecx, dword[ebp-32]
	mov dword[eax], ecx
	mov ecx, dword[ebp-28]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp-24]
	mov dword[eax+8], ecx
	mov ecx, dword[ebp-20]
	mov dword[eax+12], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
hyperPlane_positionTo4d:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;temp results
	
	lea eax, [ebp-16]
	push eax
	push dword[ebp+12]
	push dword[ebp+8]
	call hyperPlane_directionTo4d
	
	lea eax, [ebp-16]
	push dword[ebp+8]
	push eax
	push dword[ebp+16]
	call vec4_add
	
	mov esp, ebp
	pop ebp
	ret
	
	
hyperPlane_directionTo3d:
	push ebp
	mov ebp, esp
	
	sub esp, 12			;temp result
	
	;x component
	mov eax, dword[ebp+8]
	add eax, 16
	push eax
	push dword[ebp+12]
	call vec4_dot
	fstp dword[ebp-12]
	
	;y component
	mov eax, dword[ebp+8]
	add eax, 32
	push eax
	push dword[ebp+12]
	call vec4_dot
	fstp dword[ebp-8]
	
	;z component
	mov eax, dword[ebp+8]
	add eax, 48
	push eax
	push dword[ebp+12]
	call vec4_dot
	fstp dword[ebp-4]
	
	;copy the results
	mov eax, dword[ebp+16]
	
	mov ecx, dword[ebp-12]
	mov dword[eax], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp-4]
	mov dword[eax+8], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
hyperPlane_positionTo3d:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;position-hyperplane.point
	
	;calculate position- hyperPlane.point
	lea eax, [ebp-16]
	mov ecx, dword[ebp+8]
	mov edx, dword[ebp+12]
	push ecx
	push edx
	push eax
	call vec4_sub
	
	;call directionTo3d
	push dword[ebp+16]
	lea eax, [ebp-16]
	push eax
	push dword[ebp+8]
	call hyperPlane_directionTo3d
	
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
	
	
	
hyperPlane_getEquation:
	push ebp
	mov ebp, esp
	
	sub esp, 16					;hyperplane normal
	
	;get the normal vector of the hyperplane
	lea eax, [ebp-16]
	push eax
	push dword[ebp+8]
	call hyperPlane_getNormal
	
	;do things
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	
	mov edx, dword[ebp-16]
	mov dword[ecx], edx				;A
	mov edx, dword[ebp-12]
	mov dword[ecx+4], edx			;B
	mov edx, dword[ebp-8]
	mov dword[ecx+8], edx			;C
	mov edx, dword[ebp-4]
	mov dword[ecx+12], edx			;D
	
	lea ecx, [ebp-16]
	push ecx
	push eax
	call vec4_dot
	
	mov ecx, dword[ebp+12]
	fstp dword[ecx+16]
	xor dword[ecx+16], 0x80000000	;E
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
hyperPlane_signedDistance:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	fld dword[eax+16]				;E
	sub esp, 8
	mov dword[esp], ecx
	mov dword[esp+4], eax
	call vec4_dot
	add esp, 8
	faddp
	ret