[BITS 32]

;layout:
;struct{
;	float m00, m01, m02, m03;
;	float m10, m11, m12, m13;
;	float m20, m21, m22, m23;
;	float m30, m31, m32, m33;
;}
;each float is 4 bytes

section .rodata use32
	print_line_format db "| %f %f %f %f |",10,0
	print_float db "%f",10,0
	half dd 0.5
	one dd 1.0
	two dd 2.0
	minusOne dd -1.0
	DEG2RAD dd 0.017453293

section .text use32
	extern my_memcpy
	extern my_memset
	extern my_printf
	extern mat3_det
	extern mat3_print
	extern vec3_normalize
	extern vec3_cross
	
	global mat4_print		;void mat4_print(mat4* mat)
	global mat4_init		;void mat4_init(mat4* buffer, float value)		;fills the hauptdiagonal with value
	global mat4_initDiagonal	;void mat4_initDiagonal(mat4* buffer, float a, float b, float c, float d)
	global mat4_initDetailed	;void mat4_initDetailed(mat4* buffer, float* values)
	
	global mat4_add			;void mat4_add(mat4* buffer, mat4* a, mat4* b)		//buffer can point to a or b
	global mat4_sub			;void mat4_sub(mat4* buffer, mat4* a, mat4* b)		//buffer can point to a or b
	global mat4_mul			;void mat4_mul(mat4* buffer, mat4* a, mat4* b)		//buffer can point to a or b
	global mat4_scalarMul		;void mat4_scalarMul(mat4* buffer, mat4* mat, float value)	//buffer can point to mat
	
	global mat4_transpose		;void mat4_transpose(mat4* mat)
	global mat4_det			;float mat4_det(mat4* det)		//pushes the result onto the FPU stack
	global mat4_inverse		;float mat4_inverse(mat4* buffer, mat4* mat)	//buffer can point to mat
	
	global mat4_scale		;void mat4_scale(mat4* mat, vec4* factor)
	global mat4_rotate		;void mat4_rotate(mat4* mat, vec3* vec, float angleInDegrees)
	global mat4_translate		;void mat4_translate(mat4* mat, vec3* vec)
	
	global mat4_view		;void mat4_view(mat4* buffer, vec3* position, vec3* direction, vec3* worldup)
	global mat4_ortho		;void mat4_ortho(mat4* buffer, float left, float right, float bottom, float top, float near, float far)
	global mat4_perspective		;void mat4_perspective(mat4* buffer, float fovInDegrees, float aspectXY, float near, float far)
	global mat4_perspective2	;void mat4_perspective2(mat4* buffer, float fovInDegrees, float aspectXY, float near, float far)
	
mat4_print:
	push ebp
	push edi
	push esi
	mov ebp, esp
	
	mov edi, dword[ebp+16]	;mat in eax
	xor esi, esi
	
_print_loop_start:
	push dword[edi+12]
	push dword[edi+8]
	push dword[edi+4]
	push dword[edi]
	push print_line_format
	call my_printf
	add esp, 20
	
	add edi, 16
	inc esi
	cmp esi, 4
	jl _print_loop_start
	
	;print line break
	push 0
	push 10
	mov eax, esp
	push eax
	call my_printf
	
	mov esp, ebp
	pop esi
	pop edi
	pop ebp
	ret
	
	
mat4_init:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;buffer in eax
	
	push 64
	push 0
	push eax
	call my_memset
	pop eax
	
	mov ecx, dword[ebp+12]		;value in ecx
	
	mov dword[eax], ecx
	mov dword[eax+20], ecx
	mov dword[eax+40], ecx
	mov dword[eax+60], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat4_initDiagonal:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;buffer in eax
	
	push 64
	push 0
	push eax
	call my_memset
	pop eax
	
	
	mov ecx, dword[ebp+12]		;value1 in ecx
	mov dword[eax], ecx
	
	mov ecx, dword[ebp+16]		;value2 in ecx
	mov dword[eax+20], ecx
	
	mov ecx, dword[ebp+20]		;value3 in ecx
	mov dword[eax+40], ecx
	
	mov ecx, dword[ebp+24]		;value4 in ecx
	mov dword[eax+60], ecx
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat4_initDetailed:
	mov eax, dword[esp+4]		;buffer in eax
	mov ecx, dword[esp+8]		;data in ecx
	
	push 64
	push ecx
	push eax
	call my_memcpy
	add esp, 12
	
	ret
	
	
mat4_add:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;buffer in eax
	mov ecx, dword[ebp+12]		;a in ecx
	mov edx, dword[ebp+16]		;b in edx
	
	push edi
	
	xor edi, edi
_add_loop_start:
	movups xmm0, [ecx]
	movups xmm1, [edx]
	addps xmm0, xmm1
	movups [eax], xmm0
	
	add eax, 16
	add ecx, 16
	add edx, 16
	
	inc edi
	cmp edi , 4
	jl _add_loop_start
	
	pop edi
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat4_sub:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;buffer in eax
	mov ecx, dword[ebp+12]		;a in ecx
	mov edx, dword[ebp+16]		;b in edx
	
	push edi
	
	xor edi, edi
_sub_loop_start:
	movups xmm0, [ecx]
	movups xmm1, [edx]
	subps xmm0, xmm1
	movups [eax], xmm0
	
	add eax, 16
	add ecx, 16
	add edx, 16
	
	inc edi
	cmp edi , 4
	jl _sub_loop_start
	
	pop edi
	
	mov esp, ebp
	pop ebp
	ret
	

mat4_mul:
	push ebp
	mov ebp, esp
	
	sub esp, 64		;temp result
	sub esp, 64		;b transposed (<a.line;b.column>=<a.line;bt.line>)
	
	;copy and transpose b
	push 64
	mov eax, dword[ebp+16]	;b in eax
	push eax
	lea eax, [ebp-128]
	push eax
	call my_memcpy
	call mat4_transpose
	add esp, 12
	
	;multipl
	push edi
	push esi
	push ebx
	
	lea eax, [ebp-64]	;temp buffer in eax
	mov ecx, dword[ebp+12]	;a in ecx
	lea edx, [ebp-128]	;b transposed in edx
	mov ebx, edx		;save for restore
	
	xor edi, edi		;line number
_mul_outer_loop_start:
	
	mov edx, ebx		;restore b transpose line offset
	xor esi, esi		;column number
_mul_inner_loop_start:
	movups xmm0, [ecx]
	movups xmm1, [edx]
	mulps xmm0, xmm1
	haddps xmm0, xmm0
	haddps xmm0, xmm0
	movss dword[eax], xmm0
	
	add eax, 4
	add edx, 16
	inc esi
	cmp esi, 4
	jl _mul_inner_loop_start
	
	add ecx, 16
	inc edi
	cmp edi, 4
	jl _mul_outer_loop_start
	
	
	pop ebx
	pop esi
	pop edi
	
	;copy the temp result into transpose
	lea eax, [ebp-64]
	mov ecx, dword[ebp+8]
	push 64
	push eax
	push ecx
	call my_memcpy
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
mat4_scalarMul:
	push ebp
	mov ebp, esp
	
	movss xmm0, dword[ebp+16]
	movss xmm1, xmm0
	shufps xmm0, xmm1, 0		;xmm0 is filled with value
	
	mov eax, dword[ebp+8]		;buffer in eax
	mov ecx, dword[ebp+12]		;mat in ecx
	
	xor edx, edx
_scalarMul_loop_start:
	movups xmm1, [ecx]
	mulps xmm1, xmm0
	movups [eax], xmm1
	
	add eax, 16
	add ecx, 16
	inc edx
	cmp edx, 4
	jl _scalarMul_loop_start
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
mat4_transpose:
	push ebp
	mov ebp, esp
	
	sub esp, 64		;temp mat
	
	;copy matrix to temp buffer
	mov eax, dword[ebp+8]
	push 64
	push eax
	lea eax, [ebp-64]
	push eax
	call my_memcpy
	add esp, 12
	
	;it's transposin' time
	push edi
	push esi
	push ebx
	
	mov eax, dword[ebp+8]	;buffer in eax
	lea ecx, [ebp-64]	;temp buffer in ecx
	
	xor edi, edi	;index1
_transpose_outer_loop_start:
	xor esi, esi	;index2
_transpose_inner_loop_start:
	mov edx, edi
	imul edx, 16
	lea edx, [edx+4*esi]
	mov ebx, dword[ecx+edx]
	
	mov edx, esi
	imul edx, 16
	lea edx, [edx+4*edi]
	mov dword[eax+edx], ebx
	
	inc esi
	cmp esi, 4
	jl _transpose_inner_loop_start
	
	inc edi
	cmp edi, 4
	jl _transpose_outer_loop_start
	
	pop ebx
	pop esi
	pop edi
	
	mov esp, ebp
	pop ebp
	ret
	

mat4_det:		;sorfejtessel
	push ebp
	mov ebp, esp
	
	sub esp, 36		;temp submatrix
	
	push ebx
	push edi
	push esi
	push 0			;sign mask
	
	mov ebx, dword[ebp+8]	;mat in ebx
	xor edi, edi		;submatrix number
_det_submatrix_loop_start:
	
	xor ecx, ecx		;column index
	lea edx, [ebx+16]	;the current element in the second row of the matrix
	lea esi, [ebp-36]	;current element in the first row of the temp submatrix in esi
_det_copy_loop_start:
	cmp ecx, edi
	je _det_copy_loop_continue
	
	
	mov eax, dword[edx]
	mov dword[esi], eax
	
	mov eax, dword[edx+16]
	mov dword[esi+12], eax
	
	mov eax, dword[edx+32]
	mov dword[esi+24], eax
	
	add esi, 4
	
_det_copy_loop_continue:
	add edx, 4
	inc ecx
	cmp ecx, 4
	jl _det_copy_loop_start
	
	;calculate subdeterminant
	mov eax, dword[ebx+4*edi]
	xor eax, dword[esp]		;apply sign mask
	push eax
	fld dword[esp]
	add esp, 4
	
	lea eax, [ebp-36]
	push eax
	call mat3_det
	add esp, 4
	fmulp
	
	xor dword[esp], 0x80000000	;change sign mask
	
	inc edi
	cmp edi, 4
	jl _det_submatrix_loop_start
	
	faddp
	faddp
	faddp
	
	add esp, 4
	pop esi
	pop edi
	pop ebx
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat4_inverse:
	push ebp
	push edi
	push esi
	push ebx
	mov ebp, esp
	
	;align to 16 bytes
	mov eax, esp
	xor edx, edx
	mov ecx, 16
	idiv ecx
	sub esp, edx		;subtract the remainder
	
	sub esp, 128		;the temporary matrix and the result matrix merged together into a 4x8 matrix
	mov ebx, esp		;gigamatrix in ebx (it shall remain there)
	
	;fill up the gigamatrix
	mov esi, dword[ebp+24]	;mat in esi
	push 16
	push esi
	push ebx
	call my_memcpy
	add dword[esp+4], 16
	add dword[esp], 32
	call my_memcpy
	add dword[esp+4], 16
	add dword[esp], 32
	call my_memcpy
	add dword[esp+4], 16
	add dword[esp], 32
	call my_memcpy
	add esp, 12
	
	push 16
	push 0
	lea esi, [ebx+16]
	push esi
	call my_memset
	add dword[esp], 32
	call my_memset
	add dword[esp], 32
	call my_memset
	add dword[esp], 32
	call my_memset
	add esp, 12
	
	movss xmm0, dword[one]
	movss dword[ebx+16],xmm0
	movss dword[ebx+52], xmm0
	movss dword[ebx+88], xmm0
	movss dword[ebx+124], xmm0
	
	;eliminate the lower half
	xor edi, edi		;line to mog by
	_inverse_lower_outer_loop_start:
		mov eax, edi
		imul eax, 32
		add eax, ebx		;points to the mogger line
		
		movss xmm0, dword[eax+4*edi]	;current element in the hauptdiagonale in xmm0

		lea esi, [edi+1]	;moggable line index
		lea ecx, [eax+32]	;moggable line address
		_inverse_lower_inner_loop_start:
			;calculate scale factor
			movss xmm1, dword[ecx+4*edi]
			divss xmm1, xmm0
			movss xmm2, xmm1
			shufps xmm1, xmm2, 0	;xmm1 is filled with the scale factor
			
			movaps xmm2, [ecx]
			movaps xmm3, [eax]
			mulps xmm3, xmm1
			subps xmm2, xmm3
			movaps [ecx], xmm2
			
			movaps xmm2, [ecx+16]
			movaps xmm3, [eax+16]
			mulps xmm3, xmm1
			subps xmm2, xmm3
			movaps [ecx+16], xmm2
			
			add ecx, 32
			inc esi
			cmp esi, 4
			jl _inverse_lower_inner_loop_start
		
		inc edi
		cmp edi, 3
		jl _inverse_lower_outer_loop_start
	
	
	;normalize lines
	xor edi, edi
	mov eax, ebx		;gigamatrix in eax
	_inverse_normalize_loop_start:
		movss xmm0, dword[one]
		movss xmm1, dword[eax+4*edi]
		divss xmm0, xmm1
		movss xmm1, xmm0
		shufps xmm0, xmm1, 0	;xmm0 is filled with the scalefactor
		
		movaps xmm1, [eax]
		mulps xmm1, xmm0
		movaps [eax], xmm1
		
		movaps xmm1, [eax+16]
		mulps xmm1, xmm0
		movaps [eax+16], xmm1
		
		add eax, 32
		inc edi
		cmp edi, 4
		jl _inverse_normalize_loop_start

	
	;eliminate the upper half
	mov edi, 3		;line to mog by
	_inverse_upper_outer_loop_start:
		mov eax, edi
		imul eax, 32
		add eax, ebx		;points to the mogger line

		lea esi, [edi-1]	;moggable line index
		lea ecx, [eax-32]	;moggable line address
		_inverse_upper_inner_loop_start:
			;calculate scale factor
			movss xmm1, dword[ecx+4*edi]
			movss xmm2, xmm1
			shufps xmm1, xmm2, 0	;xmm1 is filled with the scale factor
			
			movaps xmm2, [ecx]
			movaps xmm3, [eax]
			mulps xmm3, xmm1
			subps xmm2, xmm3
			movaps [ecx], xmm2
			
			movaps xmm2, [ecx+16]
			movaps xmm3, [eax+16]
			mulps xmm3, xmm1
			subps xmm2, xmm3
			movaps [ecx+16], xmm2
			
			sub ecx, 32
			dec esi
			cmp esi, 0
			jge _inverse_upper_inner_loop_start
		
		dec edi
		cmp edi, 0
		jg _inverse_upper_outer_loop_start
	
	
	;copy back the rizzults
	mov eax, [ebp+20]
	lea ecx, [ebx+16]
	push 16
	push ecx
	push eax
	call my_memcpy
	add dword[esp+4], 32
	add dword[esp], 16
	call my_memcpy
	add dword[esp+4], 32
	add dword[esp], 16
	call my_memcpy
	add dword[esp+4], 32
	add dword[esp], 16
	call my_memcpy
	
	mov esp, ebp
	pop ebx
	pop esi
	pop edi
	pop ebp
	ret
	
	
mat4_scale:
	push ebp
	mov ebp, esp
	
	sub esp, 64
	mov eax, dword[ebp+12]
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	lea eax, [ebp-64]
	push eax
	call mat4_initDiagonal
	
	mov ecx, dword[ebp+8]
	push ecx
	push ecx
	call mat4_mul
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat4_translate:
	push ebp
	mov ebp, esp
	
	sub esp, 64		;translator
	
	;set the hauptdiagonale to 1
	mov eax, esp
	mov ecx, dword[one]
	push ecx
	push eax
	call mat4_init
	add esp, 8
	
	;set the remaining values
	lea eax, [esp+12]
	mov ecx, dword[ebp+12]
	
	mov edx, dword[ecx]
	mov dword[eax], edx
	
	mov edx, dword[ecx+4]
	mov dword[eax+16], edx
	
	mov edx, dword[ecx+8]
	mov dword[eax+32], edx
	
	;mol
	mov eax, esp
	mov ecx, dword[ebp+8]
	push eax
	push ecx
	push ecx
	call mat4_mul
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
mat4_rotate:
	push ebp
	mov ebp, esp
	
	sub esp, 12			;normalized axis
	sub esp, 64			;rotator

	;copy and normalize axis
	lea eax, [ebp-12]
	mov ecx, dword[ebp+12]
	
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	mov edx, dword[ecx+8]
	mov dword[eax+8], edx
	
	push eax
	call vec3_normalize
	add esp, 4
	
	
	;init variables
	lea eax, [ebp-76]		;rotator in eax
	lea ecx, [ebp-12]		;normalized axis in ecx
	
	movss xmm0, dword[DEG2RAD]
	mulss xmm0, dword[ebp+16]	;rotational angle in rads in xmm0
	
	sub esp, 8
	movss dword[esp+4], xmm0
	
	fld dword[esp+4]
	fcos
	fstp dword[esp]
	movss xmm1, dword[esp]		;cos(angle) in xmm1
	
	fld dword[esp+4]
	fsin
	fstp dword[esp]
	movss xmm2, dword[esp]		;sin(angle) in xmm2
	
	movss xmm3, dword[one]
	subss xmm3, xmm1		;1-cos(angle) in xmm3
	add esp, 8
	
	;overview
	;eax: mat
	;ecx: axis
	;xmm0: angle
	;xmm1: cos
	;xmm2: sin
	;xmm3: 1-cos
	
	;fill it up
	
	;(0,0)
	movss xmm4, dword[ecx]
	mulss xmm4, xmm4
	mulss xmm4, xmm3
	addss xmm4, xmm1
	movss dword[eax], xmm4
	
	;(0,1)
	movss xmm4, dword[ecx]
	movss xmm5, dword[ecx+4]
	mulss xmm4, xmm5
	mulss xmm4, xmm3
	movss xmm5, dword[ecx+8]
	mulss xmm5, xmm2
	subss xmm4, xmm5
	movss dword[eax+4], xmm4
	
	;(0,2)
	movss xmm4, dword[ecx]
	movss xmm5, dword[ecx+8]
	mulss xmm4, xmm5
	mulss xmm4, xmm3
	movss xmm5, dword[ecx+4]
	mulss xmm5, xmm2
	addss xmm4, xmm5
	movss dword[eax+8], xmm4
	
	;(1,0)
	movss xmm4, dword[ecx+4]
	movss xmm5, dword[ecx]
	mulss xmm4, xmm5
	mulss xmm4, xmm3
	movss xmm5, dword[ecx+8]
	mulss xmm5, xmm2
	addss xmm4, xmm5
	movss dword[eax+16], xmm4
	
	;(1,1)
	movss xmm4, dword[ecx+4]
	mulss xmm4, xmm4
	mulss xmm4, xmm3
	addss xmm4, xmm1
	movss dword[eax+20], xmm4
	
	;(1,2)
	movss xmm4, dword[ecx+4]
	movss xmm5, dword[ecx+8]
	mulss xmm4, xmm5
	mulss xmm4, xmm3
	movss xmm5, dword[ecx]
	mulss xmm5, xmm2
	subss xmm4, xmm5
	movss dword[eax+24], xmm4
	
	;(2,0)
	movss xmm4, dword[ecx+8]
	movss xmm5, dword[ecx]
	mulss xmm4, xmm5
	mulss xmm4, xmm3
	movss xmm5, dword[ecx+4]
	mulss xmm5, xmm2
	subss xmm4, xmm5
	movss dword[eax+32], xmm4
	
	;(2,1)
	movss xmm4, dword[ecx+8]
	movss xmm5, dword[ecx+4]
	mulss xmm4, xmm5
	mulss xmm4, xmm3
	movss xmm5, dword[ecx]
	mulss xmm5, xmm2
	addss xmm4, xmm5
	movss dword[eax+36], xmm4
	
	;(2,2)
	movss xmm4, dword[ecx+8]
	mulss xmm4, xmm4
	mulss xmm4, xmm3
	addss xmm4, xmm1
	movss dword[eax+40], xmm4
	
	;last column (except for (3,3) )
	mov dword[eax+12], 0
	mov dword[eax+28], 0
	mov dword[eax+44], 0
	
	;last line
	mov dword[eax+48], 0
	mov dword[eax+52], 0
	mov dword[eax+56], 0
	mov edx, dword[one]
	mov dword[eax+60], edx
	
	;morbin' time
	lea eax, [ebp-76]
	mov ecx, dword[ebp+8]
	push eax
	push ecx
	push ecx
	call mat4_mul
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat4_view:
	push ebp
	mov ebp, esp
	
	sub esp, 12	;direction
	sub esp, 12	;right
	sub esp, 12	;up
	
	;copy and normalize direction
	mov eax, dword[ebp+16]		;arg direction in eax
	push 12
	push eax
	lea eax, [ebp-12]
	push eax
	call my_memcpy
	call vec3_normalize
	add esp, 12
	
	;calculate local right with gram-schmidt
	lea eax, [ebp-12]	;direction in eax
	mov ecx, dword[ebp+20]	;worldup in ecx
	lea edx, [ebp-24]	;right in edx
	push ecx
	push eax
	push edx
	call vec3_cross
	call vec3_normalize
	add esp, 12
	
	;calculate local up with gram-schmidt
	lea eax, [ebp-12]	;direction in eax
	lea ecx, [ebp-24]	;right in ecx
	lea edx, [ebp-36]	;up in edx
	push eax
	push ecx
	push edx
	call vec3_cross
	call vec3_normalize
	add esp, 12
	
	;negate direction
	lea eax, [ebp-12]	;direction in eax
	xor dword[eax], 0x80000000
	xor dword[eax+4], 0x80000000
	xor dword[eax+8], 0x80000000
	
	;calculate rotational matrix
	mov eax, dword[ebp+8]	;buffer in eax
	push 64
	push 0
	push eax
	call my_memset
	pop eax
	add esp, 8
	
	
	lea eax, [ebp-24]	;right in eax
	push 12
	push eax
	push dword[ebp+8]
	call my_memcpy
	add esp, 12
	
	lea eax, [ebp-36]	;up in eax
	mov ecx, dword[ebp+8]	;buffer in ecx
	add ecx, 16
	push 12
	push eax
	push ecx
	call my_memcpy
	add esp, 12
	
	lea eax, [ebp-12]	;direction in eax
	mov ecx, dword[ebp+8]	;buffer in ecx
	add ecx, 32
	push 12
	push eax
	push ecx
	call my_memcpy
	add esp, 12
	
	mov ecx, dword[ebp+8]
	mov eax, dword[one]
	mov dword[ecx+60], eax
	
	;copy and negate pos
	mov eax, dword[ebp+12]
	sub esp, 12
	
	mov ecx, dword[eax]
	xor ecx, 0x80000000
	mov dword[esp], ecx
	
	mov ecx, dword[eax+4]
	xor ecx, 0x80000000
	mov dword[esp+4], ecx
	
	mov ecx, dword[eax+8]
	xor ecx, 0x80000000
	mov dword[esp+8], ecx
	
	;translation
	mov eax, esp		;-pos in eax
	mov ecx, dword[ebp+8]	;buffer in ecx
	push eax
	push ecx
	call mat4_translate
	
	mov esp, ebp
	pop ebp
	ret
	

mat4_ortho:
	push ebp
	mov ebp, esp
	
	;save xmm6 and xmm7
	sub esp, 8
	movss dword[esp+4], xmm6
	movss dword[esp], xmm7
	
	;fill the matrix with zeros
	mov eax, dword[ebp+8]
	push 64
	push 0
	push eax
	call my_memset
	add esp, 12
	
	;xmm0: left
	;xmm1: right
	;xmm2: bottom
	;xmm3: top
	;xmm4: near
	;xmm5: far
	movss xmm0, dword[ebp+12]
	movss xmm1, dword[ebp+16]
	movss xmm2, dword[ebp+20]
	movss xmm3, dword[ebp+24]
	movss xmm4, dword[ebp+28]
	movss xmm5, dword[ebp+32]
	
	
	;calculate the non-zero fields
	mov eax, dword[ebp+8]		;buffer in eax
	
	;(0,0): 2/(right-left)
	movss xmm6, dword[two]
	movss xmm7, xmm1
	subss xmm7, xmm0
	divss xmm6, xmm7
	movss dword[eax], xmm6
	
	;(1,1): 2/(top-bottom)
	movss xmm6, dword[two]
	movss xmm7, xmm3
	subss xmm7, xmm2
	divss xmm6, xmm7
	movss dword[eax+20], xmm6
	
	;(2,2): -2/(far-near)
	movss xmm6, dword[two]
	movss xmm7, xmm4
	subss xmm7, xmm5
	divss xmm6, xmm7
	movss dword[eax+40], xmm6
	
	;(0,3): -(right+left)/(right-left)
	movss xmm6, xmm1
	addss xmm6, xmm0
	movss xmm7, xmm0
	subss xmm7, xmm1
	divss xmm6, xmm7
	movss dword[eax+12], xmm6
	
	;(1,3): -(top+bottom)/(top-bottom)
	movss xmm6, xmm3
	addss xmm6, xmm2
	movss xmm7, xmm2
	subss xmm7, xmm3
	divss xmm6, xmm7
	movss dword[eax+28], xmm6
	
	;(2,3): -(far+near)/(far-near)
	movss xmm6, xmm5
	addss xmm6, xmm4
	movss xmm7, xmm4
	subss xmm7, xmm5
	divss xmm6, xmm7
	movss dword[eax+44], xmm6
	
	;(3,3): 1
	mov ecx, dword[one]
	mov dword[eax+60], ecx
	
	
	;restore xmm6 and xmm7
	movss xmm7, dword[esp]
	movss xmm6, dword[esp+4]
	
	mov esp, ebp
	pop ebp
	ret
	
mat4_perspective:
	push ebp
	mov ebp, esp
	
	;fill the matrix with zeros before everything else, so that it doesn't fuck up the xmm registers (because apparently it does)
	mov eax, dword[ebp+8]
	push 64
	push 0
	push eax
	call my_memset
	add esp, 12
	
	;calculate t (it will remain in xmm0)
	sub esp, 4
	movss xmm0, dword[ebp+12]
	mulss xmm0, dword[half]
	mulss xmm0, dword[DEG2RAD]
	movss dword[esp], xmm0
	fld dword[esp]
	fptan		; ST(0): cos, ST(1): sin
	fdivp
	fstp dword[esp]
	movss xmm0, dword[esp]
	mulss xmm0, dword[ebp+20]
	add esp, 4
	
	;calculate r (it will remain in xmm1)
	movss xmm1, xmm0
	mulss xmm1, dword[ebp+16]
	
	
	;load the remaining values
	movss xmm2, dword[ebp+20]	;near in xmm2
	movss xmm3, dword[ebp+24]	;far in xmm3
	
	
	;set the non-zero values in the matrix
	mov eax, dword[ebp+8]		;buffer in eax
	
	;(0,0): near/r
	movss xmm4, xmm2
	divss xmm4, xmm1
	movss dword[eax], xmm4
	
	;(1,1): near/t
	movss xmm4, xmm2
	divss xmm4, xmm0
	movss dword[eax+20], xmm4
	
	;(2,2): -(far+near)/(far-near)
	movss xmm4, xmm3
	addss xmm4, xmm2
	movss xmm5, xmm2
	subss xmm5, xmm3
	divss xmm4, xmm5
	movss dword[eax+40], xmm4
	
	;(2,3): -2*far*near/(far-near)
	movss xmm4, dword[two]
	mulss xmm4, xmm3
	mulss xmm4, xmm2
	divss xmm4, xmm5
	movss dword[eax+44], xmm4
	
	;(3,2): -1
	mov ecx, dword[minusOne]
	mov dword[eax+56], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
mat4_perspective2:		;https://vec3.ca/code/math/projection-direct3d
	push ebp
	mov ebp, esp
	
	sub esp, 4		;vw
	sub esp, 4		;vh
	
	;fill the matrix with zeros before everything else, so that it doesn't fuck up the xmm registers (because apparently it does)
	mov eax, dword[ebp+8]
	push 64
	push 0
	push eax
	call my_memset
	add esp, 12
	
	;calculate vh
	movss xmm0, dword[ebp+12]
	movss xmm1, dword[DEG2RAD]
	mulss xmm0, xmm1
	movss xmm1, dword[half]
	mulss xmm0, xmm1
	movss dword[ebp-8], xmm0
	fld dword[ebp-8]
	fptan
	fdivp
	fld dword[ebp+20]		;multiply with znear
	fmulp
	fstp dword[ebp-8]
	
	;calculate vw
	movss xmm0, dword[ebp-8]
	movss xmm1, dword[ebp+16]
	mulss xmm0, xmm1
	movss dword[ebp-4], xmm0
	
	mov eax, dword[ebp+8]		;buffer in eax
	
	;(0,0): 2*znear/vw
	movss xmm0, dword[ebp+20]
	movss xmm1, dword[half]
	mulss xmm0, xmm1
	movss xmm1, dword[ebp-4]
	divss xmm0, xmm1
	movss dword[eax], xmm0
	
	;(1,1): 2*znear/vh
	movss xmm0, dword[ebp+20]
	movss xmm1, dword[half]
	mulss xmm0, xmm1
	movss xmm1, dword[ebp-8]
	divss xmm0, xmm1
	movss dword[eax+20], xmm0
	
	;(2,2): zfar/(znear-zfar)
	movss xmm0, dword[ebp+24]
	movss xmm1, dword[ebp+20]
	subss xmm1, xmm0
	divss xmm0, xmm1
	movss dword[eax+40], xmm0
	
	;(2,3): znear*zfear/(znear-zfar)
	movss xmm0, dword[ebp+24]
	movss xmm1, dword[ebp+20]
	movss xmm2, xmm1
	subss xmm2, xmm0
	mulss xmm0, xmm1
	divss xmm0, xmm2
	movss dword[eax+44], xmm0
	
	;(3,2): -1
	mov ecx, dword[minusOne]
	mov dword[eax+56], ecx
	
	mov esp, ebp
	pop ebp
	ret
