[BITS 32]

section .rodata use32
	print_int db "%d",10,0

	vertices:
	dd -0.5, -0.5, 0.5,	1.0, 1.0, 1.0,
	dd -0.5, 0.5, 0.5,	1.0, 1.0, 1.0,
	dd 0.5, 0.5, 0.5,	1.0, 1.0, 1.0,
	dd 0.5, -0.5, 0.5,	1.0, 1.0, 1.0,
	dd -0.5, -0.5, 0.5,	1.0, 0.0, 1.0,
	dd -0.5, -0.5, -0.5,1.0, 0.0, 1.0,
	dd -0.5, 0.5, -0.5,	1.0, 0.0, 1.0,
	dd -0.5, 0.5, 0.5,	1.0, 0.0, 1.0,
	dd 0.5, -0.5, -0.5,	0.0, 1.0, 1.0,
	dd 0.5, 0.5, -0.5,	0.0, 1.0, 1.0,
	dd -0.5, 0.5, -0.5,	0.0, 1.0, 1.0,
	dd -0.5, -0.5, -0.5,0.0, 1.0, 1.0,
	dd 0.5, 0.5, 0.5,	1.0, 1.0, 0.0,
	dd 0.5, 0.5, -0.5,	1.0, 1.0, 0.0,
	dd 0.5, -0.5, -0.5,	1.0, 1.0, 0.0,
	dd 0.5, -0.5, 0.5,	1.0, 1.0, 0.0,
	dd -0.5, 0.5, 0.5,	1.0, 0.0, 0.0,
	dd -0.5, 0.5, -0.5,	1.0, 0.0, 0.0,
	dd 0.5, 0.5, -0.5,	1.0, 0.0, 0.0,
	dd 0.5, 0.5, 0.5,	1.0, 0.0, 0.0,
	dd 0.5, -0.5, 0.5,	0.0, 0.0, 0.0,
	dd 0.5, -0.5, -0.5,	0.0, 0.0, 0.0,
	dd -0.5, -0.5, -0.5,0.0, 0.0, 0.0,
	dd -0.5, -0.5, 0.5,	0.0, 0.0, 0.0
	
	vertices_no_colour:
	dd -0.5, -0.5, 0.5,
	dd -0.5, 0.5, 0.5,
	dd 0.5, 0.5, 0.5,
	dd 0.5, -0.5, 0.5,
	dd -0.5, -0.5, 0.5,
	dd -0.5, -0.5, -0.5,
	dd -0.5, 0.5, -0.5,
	dd -0.5, 0.5, 0.5,
	dd 0.5, -0.5, -0.5,
	dd 0.5, 0.5, -0.5,
	dd -0.5, 0.5, -0.5,
	dd -0.5, -0.5, -0.5,
	dd 0.5, 0.5, 0.5,
	dd 0.5, 0.5, -0.5,
	dd 0.5, -0.5, -0.5,
	dd 0.5, -0.5, 0.5,
	dd -0.5, 0.5, 0.5,
	dd -0.5, 0.5, -0.5,
	dd 0.5, 0.5, -0.5,
	dd 0.5, 0.5, 0.5,
	dd 0.5, -0.5, 0.5,
	dd 0.5, -0.5, -0.5,
	dd -0.5, -0.5, -0.5,
	dd -0.5, -0.5, 0.5
	
	indices:
	dd 1,0,2,2,0,3,
	dd 5,4,6,6,4,7,
	dd 9,8,10,10,8,11,
	dd 13,12,14,14,12,15,
	dd 17,16,18,18,16,19,
	dd 21,20,22,22,20,23
	
	uniform_pv db "pv",0
	
section .text use32
	
	global kuba_create		;Renderable* kuba_create()
	global kuba_destroy		;void kuba_destroy(Renderable* kuba)
	global kuba_render		;void kuba_render(Renderable* kuba, struct mat4* pv)
	
	extern my_printf
	
	extern renderable_create
	extern renderable_destroy
	extern renderable_render
	extern RENDERABLE_ATTRIB_P3
	
kuba_create:
	push ebp
	mov ebp, esp
	
	sub esp, 16		;vector<vec3> vertices
	sub esp, 16		;vector<int> indices
	
	;imitate a vector
	mov dword[ebp-16], 24
	mov dword[ebp-12], 24
	mov dword[ebp-8], 12
	mov dword[ebp-4], vertices_no_colour
	
	mov dword[ebp-32], 36
	mov dword[ebp-28], 36
	mov dword[ebp-24], 4
	mov dword[ebp-20], indices
	
	lea eax, [ebp-16]
	lea ecx, [ebp-32]
	push dword[RENDERABLE_ATTRIB_P3]
	push ecx
	push eax
	call renderable_create
	
	mov esp, ebp
	pop ebp
	ret
	
kuba_destroy:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call renderable_destroy
	
	mov esp, ebp
	pop ebp
	ret
	
	
kuba_render:
	push ebp
	mov ebp, esp
	
	push 0
	push dword[ebp+12]		;pv
	push dword[ebp+8]		;kuba
	call renderable_render
	
	mov esp, ebp
	pop ebp
	ret