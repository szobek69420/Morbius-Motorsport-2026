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

	test_text db "buzi lightyear",10,0

section .text use32

	global light_createPoint		;PointLight* light_createPoint()
	global light_createGlobal		;GlobalLight* light_createGlobal(int isDirectional)
	global light_destroy			;void light_destroy(Light* light)
	
	
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
	