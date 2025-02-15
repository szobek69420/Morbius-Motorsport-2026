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

section .text use32
	extern my_printf
	extern my_memcpy
	
	global vec4_print		;void vec4_print(vec4*)
	global vec4_init		;void vec4_init(vec4* buffer, float a, float b, float c, float d)
	global vec4_initUniform		;void vec4_initUniform(vec4* buffer, float value)
	global vec4_add			;void vec4_add(vec4* buffer, vec4* a, vec4*b)		//buffer may point to a or b
	global vec4_sub			;void vec4_sub(vec4* buffer, vec4* a, vec4*b)		//buffer may point to a or b
	global vec4_scale		;void vec4_scale(vec4* buffer, vec4* vec, float value)	//buffer may point to vec
	global vec4_dot			;float vec4_dot(vec4* a, vec4* b)		//pushes the result onto the FPU stack
	global vec4_sqrMagnitude	;float vec4_sqrMagnitude(vec4* vec)		//pushes the result onto the FPU stack
	global vec4_magnitude		;float vec4_magnitude(vec4* vec)		//pushes the result onto the FPU stack
	global vec4_normalize		;void vec4_normalize(vec4* vec)
	global vec4_mulWithMat		;void vec4_mulWithMat(vec4* vec, mat4* mat)
	
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
	
	add esp, 4
	movss dword[esp], xmm0
	fld dword[esp]
	sub esp, 4
	
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
