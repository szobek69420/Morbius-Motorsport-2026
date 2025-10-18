[BITS 32]

;layout:
;struct{
; float a, b, c, d; //egyenkent 4 byte
;}

section .data use32
	print_format dd "(%f, %f, %f, %f)",10,0
	print_float db "%f",10,0
	
	normalize_error_message db "vec4: normalizing a null vector, eh?",10,0
	
	epsilon dd 0.0001
	zero dd 0.0
	
	deg2rad dd 0.01745329252
	
	test_text db "fuxos kondenzator",10,0
	
	ZERO dd 0.0
	ONE dd 1.0
	TWO dd 2.0
	THREE dd 3.0

section .text use32
	extern my_printf
	extern my_memcpy
	
	extern mat3_det
	
	global vec4_print		;void vec4_print(vec4*)
	global vec4_init		;void vec4_init(vec4* buffer, float a, float b, float c, float d)
	global vec4_initUniform		;void vec4_initUniform(vec4* buffer, float value)
	global vec4_add			;void vec4_add(vec4* buffer, vec4* a, vec4*b)		//buffer may point to a or b
	global vec4_sub			;void vec4_sub(vec4* buffer, vec4* a, vec4*b)		//buffer may point to a or b
	global vec4_scale		;void vec4_scale(vec4* buffer, vec4* vec, float value)	//buffer may point to vec
	global vec4_dot			;float vec4_dot(vec4* a, vec4* b)		//pushes the result onto the FPU stack
	global vec4_cross		;void vec4_cross(vec4* buffer, vec4* a, vec4* b, vec4* c)	//technically it isn't a cross product, but returns a vector that is orthogonal to a, b and c
	global vec4_sqrMagnitude	;float vec4_sqrMagnitude(vec4* vec)		//pushes the result onto the FPU stack
	global vec4_magnitude		;float vec4_magnitude(vec4* vec)		//pushes the result onto the FPU stack
	global vec4_normalize		;void vec4_normalize(vec4* vec)
	global vec4_mulWithMat		;void vec4_mulWithMat(vec4* vec, mat4* mat)
	
	;planeDir1 and planeDir2 shall be orthogoonal
	global vec4_rotateAroundPlane	;void vec4_rotateAroundPlane(vec4* vec, vec4* planeDir1, vec4* planeDir2, float angleInDegrees)
	
	;smoothstep(0,1,x) on each element of the vector
	global vec4_smoothstep1		;void vec4_smoothstep1(vec4* vec)
	
vec4_print:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	mov eax, print_format
	push eax
	call my_printf
	add esp, 20
	
	mov esp, ebp
	pop ebp
	ret
	
	
vec4_init:
	push ebp
	mov ebp, esp
	
	push 16
	lea eax, [ebp+12]
	push eax
	mov eax, dword[ebp+8]
	push eax
	call my_memcpy
	
	mov esp, ebp
	pop ebp
	ret
	
vec4_initUniform:
	mov eax, dword[esp+4]		;vec4* in eax
	mov ecx, dword[esp+8]		;value in ecx
	
	mov dword[eax], ecx
	mov dword[eax+4], ecx
	mov dword[eax+8], ecx
	mov dword[eax+12], ecx
	
	ret
	
vec4_add:
	mov eax, dword[esp+4]		;&buffer in eax
	mov ecx, dword[esp+8]		;&a in ecx
	mov edx, dword[esp+12]		;&b in edx
	
	movups xmm0, [ecx]
	movups xmm1, [edx]
	addps xmm0, xmm1
	movups [eax], xmm0
	
	ret
	
	
vec4_sub:
	mov eax, dword[esp+4]		;&buffer in eax
	mov ecx, dword[esp+8]		;&a in ecx
	mov edx, dword[esp+12]		;&b in edx
	
	movups xmm0, [ecx]
	movups xmm1, [edx]
	subps xmm0, xmm1
	movups [eax], xmm0
	
	ret
	
vec4_scale:
	mov ecx, dword[esp+4]		;buffer in ecx
	mov eax, dword[esp+8]		;vec in eax
	movss xmm0, dword[esp+12]	;value in xmm0
	movss xmm1, xmm0		;value in xmm1
	
	shufps	xmm1, xmm0, 0		;all slots in xmm1 is filled with value
	movups xmm0, [eax]		;vec in xmm0
	mulps xmm0, xmm1		;multiplication
	movups [ecx], xmm0
	
	ret
	
vec4_dot:
	mov eax, dword[esp+4]		;&a in eax
	mov ecx, dword[esp+8]		;&b in ecx
	
	movups xmm0, [eax]
	movups xmm1, [ecx]
	
	mulps xmm0, xmm1
	haddps xmm0, xmm0
	haddps xmm0, xmm0
	
	sub esp, 4
	movss dword[esp], xmm0
	fld dword[esp]
	add esp, 4
	
	ret
	
vec4_sqrMagnitude:
	mov eax, dword[esp+4]		;&vector in eax
	push eax
	push eax
	call vec4_dot
	add esp, 8
	ret
	
vec4_magnitude:
	mov eax, dword[esp+4]		;&vector in eax
	push eax
	call vec4_sqrMagnitude
	fsqrt
	add esp,4
	ret
	
vec4_normalize:
	push ebp
	mov ebp, esp
	
	sub esp,4			;alloc space for the length
	
	mov eax, dword[ebp+8]		;&vector in eax
	
	;calculate length
	push eax
	call vec4_magnitude
	fstp dword[ebp-4]		;save result
	pop eax
	
	;check if length is zero
	movss xmm0, dword[ebp-4]	;length in xmm0
	movss xmm1, dword[epsilon]	;epsilon in xmm1
	ucomiss xmm0, xmm1
	jb normalize_error_report	;length is very close to zero, can be taken as a null vector
	
	movss xmm1, xmm0		;length also in xmm1
	shufps xmm0, xmm1, 0		;fill all slots in xmm0 with length
	movups xmm1, [eax]		;vec in xmm1
	divps xmm1, xmm0		;normalized vector in xmm1
	
	movups [eax], xmm1		;save result
	
	jmp normalize_done
	
normalize_error_report:
	push normalize_error_message
	call my_printf
	
normalize_done:
	mov esp, ebp
	pop ebp
	ret
	
vec4_mulWithMat:
	mov eax, dword[esp+4]		;vec in eax
	mov ecx, dword[esp+8]		;mat in ecx
	
	movups xmm0, [eax]		;vec in xmm0
	
	movups xmm1, [ecx]
	mulps xmm1, xmm0
	haddps xmm1, xmm1
	haddps xmm1, xmm1
	movss dword[eax], xmm1
	
	movups xmm1, [ecx+16]
	mulps xmm1, xmm0
	haddps xmm1, xmm1
	haddps xmm1, xmm1
	movss dword[eax+4], xmm1
	
	movups xmm1, [ecx+32]
	mulps xmm1, xmm0
	haddps xmm1, xmm1
	haddps xmm1, xmm1
	movss dword[eax+8], xmm1
	
	movups xmm1, [ecx+48]
	mulps xmm1, xmm0
	haddps xmm1, xmm1
	haddps xmm1, xmm1
	movss dword[eax+12], xmm1
	
	ret


vec4_cross:
	push ebp
	mov ebp, esp
	
	sub esp, 36				;temp mat3				;36
	
	;calculate x
	;x=det(mat3(a.y,a.z,a.w; b.y,b.z,b.w; c.y,c.z,c.w))
	mov eax, dword[ebp+12]			;a in eax
	mov ecx, dword[eax+4]
	mov dword[ebp-36], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-32], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-28], ecx
	
	mov eax, dword[ebp+16]			;b in eax
	mov ecx, dword[eax+4]
	mov dword[ebp-24], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-20], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-16], ecx
	
	mov eax, dword[ebp+20]			;c in eax
	mov ecx, dword[eax+4]
	mov dword[ebp-12], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-8], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-4], ecx
	
	lea eax, [ebp-36]
	push eax
	call mat3_det
	mov edx, dword[ebp+8]
	fstp dword[edx]
	
	;calculate y
	;y=-det(mat3(a.x,a.z,a.w; b.x,b.z,b.w; c.x,c.z,c.w))
	mov eax, dword[ebp+12]			;a in eax
	mov ecx, dword[eax]
	mov dword[ebp-36], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-32], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-28], ecx
	
	mov eax, dword[ebp+16]			;b in eax
	mov ecx, dword[eax]
	mov dword[ebp-24], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-20], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-16], ecx
	
	mov eax, dword[ebp+20]			;c in eax
	mov ecx, dword[eax]
	mov dword[ebp-12], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-8], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-4], ecx
	
	lea eax, [ebp-36]
	push eax
	call mat3_det
	mov edx, dword[ebp+8]
	fstp dword[edx+4]
	xor dword[edx+4], 0x80000000
	
	;calculate z
	;z=det(mat3(a.x,a.y,a.w; b.x,b.y,b.w; c.x,c.y,c.w))
	mov eax, dword[ebp+12]			;a in eax
	mov ecx, dword[eax]
	mov dword[ebp-36], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-32], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-28], ecx
	
	mov eax, dword[ebp+16]			;b in eax
	mov ecx, dword[eax]
	mov dword[ebp-24], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-20], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-16], ecx
	
	mov eax, dword[ebp+20]			;c in eax
	mov ecx, dword[eax]
	mov dword[ebp-12], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-8], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-4], ecx
	
	lea eax, [ebp-36]
	push eax
	call mat3_det
	mov edx, dword[ebp+8]
	fstp dword[edx+8]
	
	
	;calculate w
	;w=-det(mat3(a.x,a.y,a.z; b.x,b.y,b.z; c.x,c.y,c.z))
	mov eax, dword[ebp+12]			;a in eax
	mov ecx, dword[eax]
	mov dword[ebp-36], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-32], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-28], ecx
	
	mov eax, dword[ebp+16]			;b in eax
	mov ecx, dword[eax]
	mov dword[ebp-24], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-20], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-16], ecx
	
	mov eax, dword[ebp+20]			;c in eax
	mov ecx, dword[eax]
	mov dword[ebp-12], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-8], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-4], ecx
	
	lea eax, [ebp-36]
	push eax
	call mat3_det
	mov edx, dword[ebp+8]
	fstp dword[edx+12]
	xor dword[edx+12], 0x80000000
	
	;normalize the results
	push dword[ebp+8]
	call vec4_normalize
	
	mov esp, ebp
	pop ebp
	ret

vec4_rotateAroundPlane:
	push ebp
	mov ebp, esp

	sub esp, 16				;normalized planeDir1								;16
	sub esp, 16				;normalized planeDir2								;32
	sub esp, 4				;<var16; vec>										;36
	sub esp, 4				;<var32; vec>										;40
	sub esp, 16				;part of vec that is invariant to the rotation		;56
	sub esp, 16				;helper vec4										;72
	sub esp, 4				;cos(angle)*var36-sin(angle)*var40					;76
	sub esp, 4				;sin(angle)*var36+cos(angle)*var40					;80
	
	;normalize planeDir1
	mov eax, dword[ebp+12]
	mov ecx, dword[eax]
	mov dword[ebp-16], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-12], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-8], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-4], ecx
	lea eax, [ebp-16]
	push eax
	call vec4_normalize
	
	;normalize planeDir2
	mov eax, dword[ebp+16]
	mov ecx, dword[eax]
	mov dword[ebp-32], ecx
	mov ecx, dword[eax+4]
	mov dword[ebp-28], ecx
	mov ecx, dword[eax+8]
	mov dword[ebp-24], ecx
	mov ecx, dword[eax+12]
	mov dword[ebp-20], ecx
	lea eax, [ebp-32]
	push eax
	call vec4_normalize
	
	;get the dot products (var36 and var40)
	push dword[ebp+8]
	lea eax, [ebp-16]
	push eax
	call vec4_dot
	fstp dword[ebp-36]
	lea eax, [ebp-32]
	mov dword[esp], eax
	call vec4_dot
	fstp dword[ebp-40]
	
	
	;calculate the invariant part of the vec
	;invariant part = vec - <normPlaneDir1; vec>*normPlaneDir1 - <normPlaneDir2; vec>*normPlaneDir2
	push dword[ebp-36]
	lea eax, [ebp-16]
	push eax
	lea eax, [ebp-56]
	push eax
	call vec4_scale
	
	push dword[ebp-40]
	lea eax, [ebp-32]
	push eax
	lea eax, [ebp-72]
	push eax
	call vec4_scale
	
	lea eax, [ebp-56]
	push eax
	push eax
	call vec4_add
	
	lea eax, [ebp-56]
	push eax
	push dword[ebp+8]
	push eax
	call vec4_sub			;invariant part in var56
	
	;calculate the rotated vector
	;rotated vector = 
	;	invariant part + 
	;	+ (cos(angle)*var36-sin(angle)*var40)*normPlaneDir1 + 
	;	+ (sin(angle)*var36+cos(angle)*var40)*normPlaneDir2
	
	fld dword[ebp+20]
	fld dword[deg2rad]
	fmulp
	fsincos					;st0=cos(angle), st1=sin(angle)
	
	fld dword[ebp-36]
	fmul st0, st1			;cos(angle)*var36
	fld dword[ebp-40]
	fmul st0, st3			;sin(angle)*var40
	fsubp
	fstp dword[ebp-76]		;cos(angle)*var36-sin(angle)*var40
	
	fld dword[ebp-36]
	fmul st0, st2			;sin(angle)*var36
	fld dword[ebp-40]
	fmul st0, st2			;cos(angle)*var40
	faddp
	fstp dword[ebp-80]		;sin(angle)*var36+cos(angle)*var40
	
	fstp st0
	fstp st0
	
	
	push dword[ebp-76]
	lea eax, [ebp-16]
	push eax
	push eax
	call vec4_scale			;(cos(angle)*var36-sin(angle)*var40)*normPlaneDir1
	
	push dword[ebp-80]
	lea eax, [ebp-32]
	push eax
	push eax
	call vec4_scale			;(sin(angle)*var36+cos(angle)*var40)*normPlaneDir2
	
	lea eax, [ebp-16]
	push eax
	lea eax, [ebp-56]
	push eax
	push eax
	call vec4_add
	
	lea eax, [ebp-32]
	mov dword[esp+8], eax
	mov eax, dword[ebp+8]
	mov dword[esp], eax
	call vec4_add			;invariant part + (cos(angle)*var36-sin(angle)*var40)*normPlaneDir1 + (sin(angle)*var36+cos(angle)*var40)*normPlaneDir2
	
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
vec4_smoothstep1:
	push ebp
	mov ebp, esp
	
	;get the vector
	mov eax, dword[ebp+8]
	movups xmm0, [eax]
	
	;clamp the values
	movss xmm1, dword[ONE]
	shufps xmm1, xmm1, 0b00000000
	movss xmm2, dword[ZERO]
	shufps xmm2, xmm2, 0b00000000
	minps xmm0, xmm1
	maxps xmm0, xmm2
	
	;smoothstep
	movss xmm2, dword[TWO]
	shufps xmm2, xmm2, 0b00000000
	movss xmm3, dword[THREE]
	shufps xmm3, xmm3, 0b00000000
	
	movaps xmm1, xmm0
	mulps xmm1, xmm1
	mulps xmm0, xmm2
	subps xmm3, xmm0
	mulps xmm1, xmm3
	
	;save the vector
	movups [eax], xmm1
	
	mov esp, ebp
	pop ebp
	ret