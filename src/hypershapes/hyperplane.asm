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
	
	extern my_memset
	
	extern mat3_det
	
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
	
	
;uses the 4D equivalent of the cross product
hyperPlane_getNormal:
	push ebp
	mov ebp, esp
	
	sub esp, 36		;temp mat3
	
	mov eax, dword[ebp+8]		;HyperPlane* in eax
	mov edx, dword[ebp+12]		;buffer in edx
	
	;calculate the x component
	mov ecx, dword[eax+20]
	mov dword[ebp-36], ecx
	mov ecx, dword[eax+36]
	mov dword[ebp-24], ecx
	mov ecx, dword[eax+52]
	mov dword[ebp-12], ecx
	
	mov ecx, dword[eax+24]
	mov dword[ebp-32], ecx
	mov ecx, dword[eax+40]
	mov dword[ebp-20], ecx
	mov ecx, dword[eax+56]
	mov dword[ebp-8], ecx
	
	mov ecx, dword[eax+28]
	mov dword[ebp-28], ecx
	mov ecx, dword[eax+44]
	mov dword[ebp-16], ecx
	mov ecx, dword[eax+60]
	mov dword[ebp-4], ecx
	
	lea ecx, [ebp-36]
	push eax		;save eax
	push edx		;save edx
	push ecx
	call mat3_det
	add esp, 4
	pop edx			;restore edx
	pop eax			;restore eax
	
	fstp dword[edx]
	
	;calculate y component
	mov ecx, dword[eax+16]
	mov dword[ebp-36], ecx
	mov ecx, dword[eax+32]
	mov dword[ebp-24], ecx
	mov ecx, dword[eax+48]
	mov dword[ebp-12], ecx
	
	lea ecx, [ebp-36]
	push eax		;save eax
	push edx		;save edx
	push ecx
	call mat3_det
	add esp, 4
	pop edx			;restore edx
	pop eax			;restore eax
	
	fstp dword[edx+4]
	xor dword[edx+4], 0x80000000		;negation
	
	;calculate z component
	mov ecx, dword[eax+20]
	mov dword[ebp-32], ecx
	mov ecx, dword[eax+36]
	mov dword[ebp-20], ecx
	mov ecx, dword[eax+52]
	mov dword[ebp-8], ecx
	
	lea ecx, [ebp-36]
	push eax		;save eax
	push edx		;save edx
	push ecx
	call mat3_det
	add esp, 4
	pop edx			;restore edx
	pop eax			;restore eax
	
	fstp dword[edx+8]

	;calculate w component
	mov ecx, dword[eax+24]
	mov dword[ebp-28], ecx
	mov ecx, dword[eax+40]
	mov dword[ebp-16], ecx
	mov ecx, dword[eax+56]
	mov dword[ebp-4], ecx
	
	lea ecx, [ebp-36]
	push eax		;save eax
	push edx		;save edx
	push ecx
	call mat3_det
	add esp, 4
	pop edx			;restore edx
	pop eax			;restore eax
	
	fstp dword[edx+12]
	xor dword[edx+12], 0x80000000		;negation
	
	mov esp, ebp
	pop ebp
	ret