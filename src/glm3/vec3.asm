
[BITS 32]

;layout: (12 bytes)
;struct{
;	float x,y,z;
;}

section .data use32
	print_format db "(%f, %f, %f)",10,0
	print_float db "%f",10,0
	normalize_error_message db "vec3: normalizing a null vector, eh?",10,0
	zero dd 0.0
	epsilon dd 0.0001

section .bss use32
	print_helper resb 8

section .text use32
	extern my_printf
	extern my_memcpy

	global vec3_print		;void vec3_print(vec3* vector)
	global vec3_init		;void vec3_init(vec3* buffer, float x, float y, float z)
	global vec3_initUniform		;void vec3_initUniform(vec3* buffer, float value)	//fills the vector with the same value
	global vec3_add			;void vec3_add(vec3* buffer, vec3* a, vec3* b)			//buffer may point to a or b
	global vec3_sub			;void vec3_sub(vec3* buffer, vec3* a, vec3* b)			//buffer may point to a or b
	global vec3_dot			;float vec3_dot(vec3* a, vec3* b)			//returns the value on the FPU stack
	global vec3_cross		;void vec3_cross(vec3* buffer, vec3* a, vec3* b)	//buffer may point to a or b
	global vec3_scale		;void vec3_scale(vec3* buffer, vec3* vec, float factor)	//buffer may point to vec
	global vec3_sqrMagnitude	;float vec3_sqrMagnitude(vec3* vec)			//returns the value on the FPU stack
	global vec3_magnitude		;float vec3_magnitude(vec3* vec)			//returns the value on the FPU stack
	global vec3_normalize		;void vec3_normalize(vec3* vec)	
	global vec3_mulWithMat		;void vec3_mulWithMat(vec3* vec, mat3* mat)
	
vec3_print:
	push ebp
	mov ebp, esp
	
	mov ecx, dword[ebp+8]	;vec3* in ecx
	
	;init args
	push dword[ecx+8]
	push dword[ecx+4]
	push dword[ecx]
	push print_format
	call my_printf
	add esp, 16
	
	mov esp, ebp
	pop ebp
	ret
	
	
vec3_init:
	push ebp
	mov ebp,esp
	
	mov eax, dword[ebp+8]	;vec3* in eax
	
	mov ecx, dword[ebp+12]	;x in ecx
	mov dword[eax], ecx
	mov ecx, dword[ebp+16]	;y in ecx
	mov dword[eax+4], ecx
	mov ecx, dword[ebp+20]	;z in ecx
	mov dword[eax+8], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
vec3_initUniform:
	mov eax, dword[esp+4]	;vec3* in eax
	mov ecx, dword[esp+8]	;value in ecx
	mov dword[eax], ecx
	mov dword[eax+4], ecx
	mov dword[eax+8], ecx
	ret
	
vec3_add:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+12]		;a in eax
	mov ecx, dword[ebp+16]		;b in ecx
	mov edx, dword[ebp+8]		;buffer in edx
	
	;calculate x
	fld dword[eax]
	fld dword[ecx]
	faddp
	fstp dword[edx]
	
	;calculate y
	fld dword[eax+4]
	fld dword[ecx+4]
	faddp
	fstp dword[edx+4]
	
	;calculate z
	fld dword[eax+8]
	fld dword[ecx+8]
	faddp
	fstp dword[edx+8]
	
	mov esp, ebp
	pop ebp
	ret
	

vec3_sub:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+12]		;a in eax
	mov ecx, dword[ebp+16]		;b in ecx
	mov edx, dword[ebp+8]		;buffer in edx
	
	;calculate x
	fld dword[eax]
	fld dword[ecx]
	fsubp
	fstp dword[edx]
	
	;calculate y
	fld dword[eax+4]
	fld dword[ecx+4]
	fsubp
	fstp dword[edx+4]
	
	;calculate z
	fld dword[eax+8]
	fld dword[ecx+8]
	fsubp
	fstp dword[edx+8]
	
	
	mov esp, ebp
	pop ebp
	ret
	
vec3_dot:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]	;a in eax
	mov ecx, dword[ebp+12]	;b in ecx
	
	fld dword[eax]
	fld dword[ecx]
	fmulp
	fld dword[eax+4]
	fld dword[ecx+4]
	fmulp
	faddp
	fld dword[eax+8]
	fld dword[ecx+8]
	fmulp
	faddp
	
	mov esp, ebp
	pop ebp
	ret
	
vec3_cross:
	push ebp
	mov ebp, esp
	
	sub esp, 12		;alloc space for temporary vector
	
	mov eax, dword[ebp+8]	;&buffer in 
	mov ecx, dword[ebp+12]	;&a in ecx
	mov edx, dword[ebp+16]	;&b in edx
	
	;calculate x
	fld dword[ecx+4]
	fld dword[edx+8]
	fmulp
	fld dword[ecx+8]
	fld dword[edx+4]
	fmulp
	fsubp
	fstp dword[eax]
	
	;calculate y
	fld dword[ecx+8]
	fld dword[edx]
	fmulp
	fld dword[ecx]
	fld dword[edx+8]
	fmulp
	fsubp
	fstp dword[eax+4]
	
	;calculate z
	fld dword[ecx]
	fld dword[edx+4]
	fmulp
	fld dword[ecx+4]
	fld dword[edx]
	fmulp
	fsubp
	fstp dword[eax+8]
	
	mov esp, ebp
	pop ebp
	ret
	
	
vec3_scale:
	push ebp
	mov ebp, esp
	
	mov ecx, dword[ebp+8]		;buffer in ecx
	mov eax, dword[ebp+12]		;vec in eax
	
	movss xmm1, dword[ebp+16]	;scale factor in xmm1
	
	movss xmm0, dword[eax]
	mulss xmm0, xmm1
	movss dword[ecx], xmm0
	
	movss xmm0, dword[eax+4]
	mulss xmm0, xmm1
	movss dword[ecx+4], xmm0
	
	movss xmm0, dword[eax+8]
	mulss xmm0, xmm1
	movss dword[ecx+8], xmm0
	
	mov esp, ebp
	pop ebp
	ret
	
vec3_sqrMagnitude:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	lea ecx, zero
	movss xmm1, dword[ecx]
	
	movups xmm0,[eax]
	insertps xmm0, xmm1, 0b00110000	;fill in the last element with 0.0 (mask meaning: https://www.officedaytime.com/simd512e/simdimg/si.php?f=insertps figure 1)
	
	vmulps xmm0, xmm0	;elementwise multiplication
	haddps xmm0, xmm0	;felixcloutier.com/x86/haddps
	haddps xmm0, xmm0	;the sum of the four elements are in the lower 32 bits of xmm0
	
	sub esp, 4
	movss dword[esp], xmm0
	fld dword[esp]
	
	mov esp, ebp
	pop ebp
	ret
	
vec3_magnitude:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push eax
	call vec3_sqrMagnitude
	add esp, 4
	fsqrt
	
	mov esp, ebp
	pop ebp
	ret
	
vec3_normalize:
	push ebp
	mov ebp, esp
	
	sub esp, 16	;alloc space for temporary vector
	sub esp, 4	;alloc space for temporary value
	
	;get length
	mov eax, dword[ebp+8]
	push eax
	call vec3_magnitude
	pop eax
	fstp dword[ebp-20]
	
	
	;check if the vector is a null vector
	mov ecx, epsilon
	movss xmm1, dword[ecx]		;epsilon in xmm1
	movss xmm0, dword[ebp-20]	;length in xmm0
	ucomiss xmm0, xmm1
	jb normalize_error_report
	
	;fill up the 4 slots of xmm0 with the length (https://www.officedaytime.com/simd512e/simdimg/si.php?f=shufps figure 1)
	movss xmm1, xmm0	;length also in xmm1
	shufps xmm0, xmm1, 0b00000000
	
	;vector in xmm1, the 4th value is zeroed
	movups xmm1, [eax]		;movups, mert a movaps koveteli a 16 byte-os igazitast
	insertps xmm1, xmm1, 0b00001000
	
	;divide
	divps xmm1, xmm0
	
	;save result
	movups [ebp-16], xmm1
	
	mov ecx, dword[ebp-16]
	mov dword[eax], ecx
	mov ecx, dword[ebp-12]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp-8]
	mov dword[eax+8], ecx
	
	jmp normalize_done
	
normalize_error_report:
	push normalize_error_message
	call my_printf
	
normalize_done:
	mov esp, ebp
	pop ebp
	ret
	
	
vec3_mulWithMat:
	push ebp
	mov ebp, esp
	
	sub esp, 12		;temp vector
	
	push esi
	
	mov eax, dword[ebp+8]	;vec in eax
	mov ecx, dword[ebp+12]	;mat in ecx
	lea edx, [ebp-12]	;temp vec in edx
	
	xor esi, esi
_mulWithMat_loop_start:
	
	push edx
	push eax
	push ecx
	call vec3_dot
	pop ecx
	pop eax
	pop edx
	
	fstp dword[edx]
	
	add edx, 4
	add ecx, 12
	inc esi
	cmp esi, 3
	jl _mulWithMat_loop_start
	
	pop esi
	
	mov eax, dword[ebp+8]
	lea ecx, [ebp-12]
	push 12
	push ecx
	push eax
	call my_memcpy
	
	mov esp, ebp
	pop ebp
	ret
