[BITS 32]

;struct PointLight{
;	vec3 position;			0
;	vec3 colour;			12
;	float intensity;		24
;	float calculatedRadius;	28
;}
;	32 bytes

;struct GlobalLight{
;	vec3 normalizedDir;		0
;	vec3 colour;			12
;	float intensity;		24
;	int isDirectional;		28		//if 0, ambient
;}
;	32 bytes

section .rodata use32

	ONE_PER_CUTOFF_INTENSITY dd 32.0		;256/8

	test_text db "buzi lightyear",10,0
	
	TWO dd 2.0
	FOUR dd 4.0

section .text use32

	global light_createPoint		;PointLight* light_createPoint()
	global light_createGlobal		;GlobalLight* light_createGlobal(int isDirectional)
	global light_destroy			;void light_destroy(Light* light)
	
	global light_calculateRadius	;void light_calculateRadius(PointLight* light, float quadraticAttenuation, float linearAttenuation, float constantAttenuation)
	
	extern my_malloc
	extern my_free
	extern my_memset
	
light_createPoint:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;light			4
	
	;alloc space
	push 32
	call my_malloc
	mov dword[ebp-4], eax
	
	;init values
	push 32
	push 0
	push dword[ebp-4]
	call my_memset
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
light_createGlobal:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;light			4
	
	;alloc space
	push 32
	call my_malloc
	mov dword[ebp-4], eax
	
	;init values
	push 32
	push 0
	push dword[ebp-4]
	call my_memset
	
	mov eax, dword[ebp-4]
	mov dword[eax+4], 0x3f800000
	mov ecx, dword[ebp+8]
	mov dword[eax+28], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
light_destroy:
	mov eax, dword[esp+4]
	push eax
	call my_free
	add esp, 4
	ret
	
	
light_calculateRadius:
	push ebp
	mov ebp, esp
	
	;calculate the max intensity
	;intensity*most intense colour component
	mov eax, dword[ebp+8]
	movss xmm0, dword[eax+12]
	maxss xmm0, dword[eax+16]
	maxss xmm0, dword[eax+20]
	mulss xmm0, dword[eax+24]
	movss dword[ebp-4], xmm0
	
	;calculate the cutoff radius
	;prepared equation, don't try to make sense of this
	movss xmm1, dword[ebp+12]
	movss xmm2, dword[ebp+16]
	movss xmm3, dword[ebp+20]
	
	mulss xmm0, dword[ONE_PER_CUTOFF_INTENSITY]
	subss xmm3, xmm0
	mulss xmm1, xmm3
	mulss xmm1, dword[FOUR]
	mulss xmm2, xmm2
	subss xmm2, xmm1
	sqrtss xmm2, xmm2
	subss xmm2, dword[ebp+16]
	
	movss xmm0, dword[ebp+12]
	mulss xmm0, dword[TWO]
	divss xmm2, xmm0
	
	;save the radius
	movss dword[eax+28], xmm2
	
	mov esp, ebp
	pop ebp
	ret