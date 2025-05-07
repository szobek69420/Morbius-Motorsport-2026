[BITS 32]

section .rodata use32
	
	MAGIC_NUMBER dd 60.0
	ONE dd 1.0

section .text use32
	global math_powf		;float math_powf(float base, float power), pushes the return value onto the FPU stack
	global math_lerp		;float math_lerp(float a, float b, float i), pushes the return value onto the fpu stack
	global math_basedLerp		;float math_basedLerp(float a, float b, float i, float deltaTime), an FPS independent lin. interpolation, pushes the return value onto the fpu stack
	
	;returns the remainder of val when divided by length
	;pushes the return value onto the fpu stack
	global math_repeat		;float math_repeat(float val, float length)
	global math_clamp		;float math_clamp(float val, float min, float max)	//pushes the result onto the fpu stack
	
	
math_powf:		;https://stackoverflow.com/questions/44957136/x87-fpu-computing-e-powered-x-maybe-with-a-taylor-series
	fld1
	fld dword[esp+4]
	fyl2x
	fmul dword[esp+8]
	fld1
	fld st1
	fprem
	f2xm1
	faddp
	fscale
	fstp st1
	
	ret
	
math_lerp:
	movss xmm0, dword[esp+4]
	movss xmm1, dword[esp+8]
	movss xmm2, dword[esp+12]
	subss xmm1, xmm0
	mulss xmm1, xmm2
	addss xmm0, xmm1
	
	sub esp, 4
	movss dword[esp], xmm0
	fld dword[esp]
	add esp, 4
	
	ret
	
math_basedLerp:		;https://github.com/14islands/lerp
	movss xmm0, dword[ONE]
	movss xmm1, dword[esp+12]
	subss xmm0, xmm1
	
	movss xmm1, dword[esp+16]
	movss xmm2, dword[MAGIC_NUMBER]
	mulss xmm1, xmm2
	
	sub esp, 8
	movss dword[esp+4], xmm1
	movss dword[esp], xmm0
	call math_powf
	add esp, 8
	
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	sub esp, 4
	fld1
	fsubp
	fstp dword[esp]
	xor dword[esp], 0x80000000
	push ecx
	push eax
	call math_lerp
	add esp, 12
	
	ret
	
	
math_clamp:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	movss xmm0, dword[ebp+8]
	
	ucomiss xmm0, dword[ebp+12]
	jae math_clamp_not_smaller_than_min
		movss xmm0, dword[ebp+12]
	math_clamp_not_smaller_than_min:
	
	ucomiss xmm0, dword[ebp+16]
	jbe math_clamp_not_greater_than_max
		movss xmm0, dword[ebp+16]
	math_clamp_not_greater_than_max:
	
	;set return value
	movss dword[ebp-4], xmm0
	fld dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	

math_repeat:
	push ebp
	mov ebp, esp
	
	fld dword[ebp+12]
	fld dword[ebp+8]
	fprem
	fstp st1
	
	test dword[ebp+8], 0x70000000
	jz math_repeat_non_negative
		fadd dword[ebp+12]
	math_repeat_non_negative:
	
	mov esp, ebp
	pop ebp
	ret