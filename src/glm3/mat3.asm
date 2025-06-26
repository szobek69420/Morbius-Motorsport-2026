[BITS 32]
;layout:
;struct{
; float a00, a01, a02;
; float a10, a11, a12;
; float a20, a21, a22;
;}
;each float is 4 bytes long

section .rodata use32
	inverse_error_message db "mat3_inverse: there is no inverse",10,0

section .data use32
	print_line db "| %f, %f, %f |",10,0
	zero dd 0.0
	one dd 1.0
	epsilon dd 0.0001

section .text use32
	extern my_printf
	extern my_memcpy
	extern my_memset
	extern vec3_dot
	
	global mat3_print		;void mat3_print(mat3* mat)
	global mat3_init		;void mat3_init(mat3* buffer, float value)	//fills the hauptdiagonale with the given value
	global mat3_initDiagonal	;void mat3_initDiagonal(mat3* buffer, float a, float b, float c)
	global mat3_initDetailed	;void mat3_initDetailed(mat3* buffer, float* values)
	global mat3_add			;void mat3_add(mat3* buffer, mat3* a, mat3* b)		//buffer may point to a or b
	global mat3_sub			;void mat3_sub(mat3* buffer, mat3* a, mat3* b)		//buffer may point to a or b
	global mat3_transpose		;void mat3_transpose(mat3* mat)
	global mat3_mul			;void mat3_mul(mat3* buffer, mat3* a, mat3*)		//buffer can point to a or b
	global mat3_scalarMul		;void mat3_scalarMul(mat3* buffer, mat3* mat, float value)	//buffer can point to mat	
	global mat3_det			;float mat3_det(mat3* mat)		//pushes the result onto the FPU stack
	global mat3_inverse		;void mat3_inverse(mat3* buffer, mat3* mat)	//buffer can point to mat
	
mat3_print:
	mov eax, dword[esp+4]	;&mat in eax
	
	push ebx		;save ebx
	push edi		;save edi
	
	
	mov ebx, eax		;&mat in ebx
	mov edi, 3
_print_loop_start:
	push dword[ebx+8]
	push dword[ebx+4]
	push dword[ebx]
	push print_line
	call my_printf
	add esp, 16
	
	add ebx, 12
	dec edi
	cmp edi, 0
	jg _print_loop_start
	
	;line break
	push 0
	push 10
	lea eax, [esp]
	push eax
	call my_printf
	add esp, 12
	
	pop edi			;restore edi
	pop ebx			;restore ebx
	ret
	
mat3_init:
	mov eax, dword[esp+4]	;buffer in eax
	mov ecx, dword[esp+8]	;value in ecx
	
	push ecx	;save ecx
	push 36
	push 0
	push eax
	call my_memset
	pop eax		;restore eax
	add esp, 8
	pop ecx		;restore ecx
	
	;set the hauptdiagonale
	mov dword[eax], ecx
	mov dword[eax+16], ecx
	mov dword[eax+32], ecx
	
	ret
	
mat3_initDiagonal:
	mov eax, dword[esp+4]	;buffer in eax
	
	push 36
	push 0
	push eax
	call my_memset
	pop eax		;restore eax
	add esp, 8
	
	;set the hauptdiagonale
	mov ecx, dword[esp+8]	;value1 in ecx
	mov dword[eax], ecx
	mov ecx, dword[esp+12]	;value2 in ecx
	mov dword[eax+16], ecx
	mov ecx, dword[esp+16]	;value3 in ecx
	mov dword[eax+32], ecx
	
	ret
	
	
mat3_initDetailed:
	mov eax, dword[esp+4]	;buffer in eax
	mov ecx, dword[esp+8]	;&values in ecx
	
	push 36
	push ecx
	push eax
	call my_memcpy
	add esp, 12
	
	ret
	

mat3_add:
	mov eax, dword[esp+4]	;buffer in eax
	mov ecx, dword[esp+8]	;a in ecx
	mov edx, dword[esp+12]	;b in edx
	
	push edi	;store edi
	push ebx	;store ebx
	
	sub esp, 36	;alloc space for temporary matrix
	
	mov edi, 9
	mov ebx, esp

	;a==b?
	cmp ecx, edx
	je _add_equal_loop_start

_add_not_equal_loop_start:
	movss xmm0, dword[ecx]
	movss xmm1, dword[edx]
	addss xmm0, xmm1
	movss dword[ebx], xmm0
	
	add ebx, 4
	add ecx, 4
	add edx, 4
	dec edi
	cmp edi, 0
	jg _add_not_equal_loop_start
	
	jmp _add_copy_data
	
_add_equal_loop_start:
	movss xmm0, dword[ecx]
	addss xmm0, xmm0
	movss dword[ebx], xmm0
	
	add ebx, 4
	add ecx, 4
	dec edi
	cmp edi, 0
	jg _add_equal_loop_start
	
_add_copy_data:

	lea ebx, [esp]		;temp matrix in ebx
	push 36
	push ebx
	push eax
	call my_memcpy
	add esp, 12
	
	add esp, 36
	pop ebx		;restore ebx
	pop edi		;restore edi
	
	ret
	
	
mat3_sub:
	mov eax, dword[esp+4]	;buffer in eax
	mov ecx, dword[esp+8]	;a in ecx
	mov edx, dword[esp+12]	;b in edx
	
	push edi	;store edi
	push ebx	;store ebx
	
	sub esp, 36	;alloc space for temporary matrix
	
	mov edi, 9
	mov ebx, esp

	;a==b?
	cmp ecx, edx
	je _sub_equal

_sub_not_equal_loop_start:
	movss xmm0, dword[ecx]
	movss xmm1, dword[edx]
	subss xmm0, xmm1
	movss dword[ebx], xmm0
	
	add ebx, 4
	add ecx, 4
	add edx, 4
	dec edi
	cmp edi, 0
	jg _sub_not_equal_loop_start
	
	jmp _sub_copy_data
	
_sub_equal:
	push eax	;save eax
	push 36
	push 0
	push ebx
	call my_memset
	add esp, 12
	pop eax		;restore eax
	
_sub_copy_data:

	lea ebx, [esp]		;temp matrix in ebx
	push 36
	push ebx
	push eax
	call my_memcpy
	add esp, 12
	
	add esp, 36
	pop ebx		;restore ebx
	pop edi		;restore edi
	
	ret
	
	
mat3_transpose:
	push ebp
	mov ebp, esp
	
	sub esp, 36		;alloc space for temporary matrix
	
	;copy matrix
	push 36
	mov eax, dword[ebp+8]	;&mat in eax
	push eax
	lea eax, [ebp-36]
	push eax
	call my_memcpy
	add esp, 12
	
	;move back the transposed values
	push edi	;save edi
	push esi	;save esi
	push ebx	;save ebx
	
	xor edi, edi	;line number
	xor esi, esi	;column number
	
	lea eax, [ebp-36]	;src* in eax
	mov ecx, dword[ebp+8]	;dst* in ecx
_transpose_outer_loop_start:
_transpose_inner_loop_start:
	mov ebx, edi
	imul ebx, 12
	lea ebx, [ebx+4*esi]
	add ebx, eax
	
	mov edx, dword[ebx]
	
	mov ebx, esi
	imul ebx, 12
	lea ebx, [ebx+4*edi]
	add ebx, ecx
	
	mov dword[ebx], edx
	
	inc esi
	cmp esi, 3
	jl _transpose_inner_loop_start
	
	xor esi, esi
	inc edi
	cmp edi, 3
	jl _transpose_outer_loop_start
	
	
	pop ebx		;restore ebx
	pop esi		;restore esi
	pop edi		;restore edi
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat3_mul:
	push ebp
	mov ebp, esp
	
	sub esp, 36		;alloc space for temporary result matrix
	sub esp, 36		;alloc space for b's duplicate
	
	
	;copy b to the temporary space and transpose it
	push 36
	mov ecx, dword[ebp+16]		;b in ecx
	push ecx
	lea ecx, [ebp-72]
	push ecx
	call my_memcpy
	call mat3_transpose
	add esp, 12
	
	mov eax, dword[ebp+12]		;a in eax
	lea ecx, [ebp-72]		;b in ecx
	lea edx, [ebp-36]		;temporary buffer in edx
	
	push edi			;save edi
	push esi			;save esi
	push ebx			;save ebx
	push ebp			;save ebp
	
	mov edi, 0			;line offset
	mov esi, 0			;columns offset (actually line in the transposed one)
	
_line_loop_start:
	mov esi, 0
_column_loop_start:
	
	lea ebx, [eax+edi]	;current a* in ebx
	lea ebp, [ecx+esi]	;current b* in ebp
	
	movss xmm0, dword[zero]
	
	movss xmm1, dword[ebx]
	movss xmm2, dword[ebp]
	mulss xmm1, xmm2
	addss xmm0, xmm1
	
	movss xmm1, dword[ebx+4]
	movss xmm2, dword[ebp+4]
	mulss xmm1, xmm2
	addss xmm0, xmm1
	
	movss xmm1, dword[ebx+8]
	movss xmm2, dword[ebp+8]
	mulss xmm1, xmm2
	addss xmm0, xmm1
	
	movss dword[edx], xmm0
	add edx, 4		;increment buffer pointer
	
	add esi, 12
	cmp esi, 36
	jl _column_loop_start
	
	add edi, 12
	cmp edi, 36
	jl _line_loop_start
	
	pop ebp				;restore ebp
	pop ebx				;restore ebx
	pop esi				;restore esi
	pop edi				;restore edi
	
	;copy the temporary matrix into the buffer
	push 36
	lea eax, [ebp-36]
	push eax
	mov eax, dword[ebp+8]
	push eax
	call my_memcpy
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat3_scalarMul:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;&buffer in eax
	mov ecx, dword[ebp+12]		;&mat in ecx
	movss xmm0, dword[ebp+16]	;value in xmm0
	movss xmm1, xmm0
	shufps xmm0, xmm1, 0		;all slots in xmm0 are filled with value
	
	movups xmm1, [ecx]
	mulps xmm1, xmm0
	movups [eax], xmm1
	
	movups xmm1, [ecx+16]
	mulps xmm1, xmm0
	movups [eax+16], xmm1
	
	movss xmm1, dword[ecx+32]
	mulss xmm1, xmm0
	movss dword[eax+32], xmm1
	
	mov esp, ebp
	pop ebp
	ret
	
mat3_det:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;&mat in eax
	
	movss xmm1, dword[eax+16]
	movss xmm2, dword[eax+32]
	mulss xmm1, xmm2
	movss xmm2, dword[eax+20]
	movss xmm3, dword[eax+28]
	mulss xmm2, xmm3
	subss xmm1, xmm2
	movss xmm2, dword[eax]
	mulss xmm1, xmm2
	movss xmm0, xmm1
	
	movss xmm1, dword[eax+12]
	movss xmm2, dword[eax+32]
	mulss xmm1, xmm2
	movss xmm2, dword[eax+20]
	movss xmm3, dword[eax+24]
	mulss xmm2, xmm3
	subss xmm1, xmm2
	movss xmm2, dword[eax+4]
	mulss xmm1, xmm2
	subss xmm0, xmm1
	
	movss xmm1, dword[eax+12]
	movss xmm2, dword[eax+28]
	mulss xmm1, xmm2
	movss xmm2, dword[eax+16]
	movss xmm3, dword[eax+24]
	mulss xmm2, xmm3
	subss xmm1, xmm2
	movss xmm2, dword[eax+8]
	mulss xmm1, xmm2
	addss xmm0, xmm1
	
	sub esp, 4
	movss dword[esp], xmm0
	fld dword[esp]
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat3_inverse:
	push ebp
	mov ebp, esp
	
	sub esp, 72		;temporary matrix and helper matrix, merged into a 3x6 matrix
	sub esp, 4		;determinant
	
	;calculate determinant
	mov eax, dword[ebp+12]
	push eax
	call mat3_det
	add esp, 4
	fstp dword[ebp-76]	;store determinant
	
	;check if inverse exists
	and dword[ebp-76], 0x7fffffff		;remove the sign of the determinant
	movss xmm0, dword[epsilon]
	ucomiss xmm0, dword[ebp-76]
	jb _inverse_exists
	
	push inverse_error_message
	call my_printf
	
	mov esp, ebp
	pop ebp
	ret
	
_inverse_exists:

	;copy the matrix to the temporary location
	lea eax, [ebp-72]
	mov ecx, dword[ebp+12]
	push 12
	push ecx
	push eax
	call my_memcpy
	add dword[esp], 24
	add dword[esp+4], 12
	call my_memcpy
	add dword[esp], 24
	add dword[esp+4], 12
	call my_memcpy
	add esp, 12
	
	movss xmm0, dword[one]
	
	movss dword[ebp-60], xmm0
	mov dword[ebp-56], 0
	mov dword[ebp-52], 0
	
	mov dword[ebp-36], 0
	movss dword[ebp-32], xmm0
	mov dword[ebp-28], 0
	
	mov dword[ebp-12], 0
	mov dword[ebp-8], 0
	movss dword[ebp-4], xmm0

	push esi	;save esi
	push edi	;save edi
	push ebx	;save ebx
	
	
	;eliminate lower half
	xor esi, esi		;main line number
	
_inverse_lower_half_outer_loop_start:
	mov eax, esi
	imul eax, 28	;direkt 28!!
	lea eax, [eax+ebp-72]	;first calculated element pointer in main line
	
	mov ebx, 24
	lea ecx, [4*esi]
	sub ebx, ecx	;helper for the inner inner loop

	mov edi, esi
	inc edi		;eliminated line number
_inverse_lower_half_inner_loop_start:
	
	mov ecx, edi
	imul ecx, 24
	lea ecx, [ecx+4*esi]
	lea edx, [ebp-72]
	add ecx, edx	;first calculated element pointer in eliminated line
	
	movss xmm0, dword[ecx]
	movss xmm1, dword[eax]
	divss xmm0, xmm1	;scale factor
	
	xor edx, edx
_inverse_lower_half_inner_inner_loop_start:
	movss xmm1, dword[ecx+edx]
	movss xmm2, dword[eax+edx]
	mulss xmm2, xmm0
	subss xmm1, xmm2
	movss dword[ecx+edx], xmm1
	
	add edx,4
	cmp edx, ebx
	jl _inverse_lower_half_inner_inner_loop_start
	
	inc edi
	cmp edi, 3
	jl _inverse_lower_half_inner_loop_start
	
	inc esi
	cmp esi, 2
	jl _inverse_lower_half_outer_loop_start
	
	
	;divide lines
	xor esi, esi
	
_inverse_division_outer_loop_start:
	mov eax, esi
	imul eax, 24
	add eax, ebp
	sub eax, 72		;the current line address
	lea ecx, [4*esi]	;the column offset of the main element
	
	movss xmm0, dword[one]
	movss xmm1, dword[eax+ecx]
	divss xmm0, xmm1	;the scale factor of the line
	
	xor edi, edi
_inverse_division_inner_loop_start:
	movss xmm1, dword[eax+edi]
	mulss xmm1, xmm0
	movss dword[eax+edi], xmm1
	
	add edi, 4
	cmp edi, 24
	jl _inverse_division_inner_loop_start
	
	inc esi
	cmp esi, 3
	jl _inverse_division_outer_loop_start
	
	
	
	;eliminate upper half
	mov esi, 2		;main line number
	
_inverse_upper_half_outer_loop_start:
	mov eax, esi
	imul eax, 28	;direkt 28!!
	lea eax, [eax+ebp-72]	;first calculated element pointer in main line
	
	mov ebx, 24
	lea ecx, [4*esi]
	sub ebx, ecx	;helper for the inner inner loop

	mov edi, esi
	dec edi		;eliminated line number
_inverse_upper_half_inner_loop_start:
	
	mov ecx, edi
	imul ecx, 24
	lea ecx, [ecx+4*esi]
	lea edx, [ebp-72]
	add ecx, edx	;first calculated element pointer in eliminated line
	
	movss xmm0, dword[ecx]	;scale factor
	
	xor edx, edx
_inverse_upper_half_inner_inner_loop_start:
	movss xmm1, dword[ecx+edx]
	movss xmm2, dword[eax+edx]
	mulss xmm2, xmm0
	subss xmm1, xmm2
	movss dword[ecx+edx], xmm1
	
	add edx,4
	cmp edx, ebx
	jl _inverse_upper_half_inner_inner_loop_start
	
	dec edi
	cmp edi, 0
	jge _inverse_upper_half_inner_loop_start
	
	dec esi
	cmp esi, 0
	jg _inverse_upper_half_outer_loop_start
	
	
	;copy the results into the buffer
	mov eax, dword[ebp+8]
	lea ecx, [ebp-60]
	
	push 12
	push ecx
	push eax
	call my_memcpy
	add dword[esp+4], 24
	add dword[esp], 12
	call my_memcpy
	add dword[esp+4], 24
	add dword[esp], 12
	call my_memcpy
	add esp, 12
	
	
	pop ebx		;restore ebx
	pop edi		;restore edi
	pop esi		;restore esi
	
	mov esp, ebp
	pop ebp
	ret
