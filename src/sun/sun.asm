[BITS 32]

section .rodata use32
	texture_path db "sprites/sun.bmp",0
	
	sun_rotational_plane_1 dd 0.0, 1.0, 0.0, 0.0
	sun_rotational_plane_2 dd 0.196116, 0.0, 0.58835, 0.784465
	
	deg2rad dd 0.0174533
	
	print_float_nl db "%f",10,0

section .data use32
	is_initialized dd 0
	renderable dd 0
	
	direction dd 0.0, 1.0, 0.0, 0.0
	distance dd 5.0

section .text use32

	global sun_init			;void sun_init()
	global sun_deinit		;void sun_deinit()
	global sun_render		;void sun_render(mat4* pv, Hyperplane* hp, const vec4* playerPos)
	
	;direction is multiplied by the distance when calculating the sun's position
	global sun_setAngle		;void sun_setAngle(float angleInDegrees)
	global sun_setDistance	;void sun_setDistance(float distance)
	
	extern my_printf
	
	extern vec4_scale
	extern vec4_add
	extern vec4_print
	
	extern hyperCubeRenderable_create
	extern hyperCubeRenderable_destroy
	extern hyperCubeRenderable_render
	extern renderable_setAlbedo
	extern renderable_enableDepthTest
	
	extern camera_viewProjection
	
sun_init:
	push ebp
	mov ebp, esp
	
	;create renderable
	call hyperCubeRenderable_create
	mov dword[renderable], eax
	
	;attach texture
	push texture_path
	push dword[renderable]
	call renderable_setAlbedo
	add esp, 8
	
	;set initialized flag
	mov dword[is_initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	

sun_deinit:
	push ebp
	mov ebp, esp
	
	;set initialized flag
	mov dword[is_initialized], 0
	
	;destroy renderable
	push dword[renderable]
	call hyperCubeRenderable_destroy
	add esp, 4
	mov dword[renderable], 0
	
	mov esp, ebp
	pop ebp
	ret
	

sun_render:
	push ebp
	mov ebp, esp
	
	sub esp, 16				;sun position
	
	;is initialized?
	cmp dword[is_initialized], 0
	je sun_render_end
	
	;calculate the sun's position
	push dword[distance]
	push direction
	lea eax, [ebp-16]
	push eax
	call vec4_scale
	add esp, 12
	
	push dword[ebp+16]
	lea eax, [ebp-16]
	push eax
	push eax
	call vec4_add
	add esp, 12
	
	;disable depth test
	push 0
	call renderable_enableDepthTest
	add esp, 4
	
	;render the sun
	lea eax, [ebp-16]
	push eax
	push dword[ebp+12]
	push dword[ebp+8]
	push dword[renderable]
	call hyperCubeRenderable_render
	add esp, 16
	
	;re-enable depth test
	push 69
	call renderable_enableDepthTest
	add esp, 4
	
	sun_render_end:
	mov esp, ebp
	pop ebp
	ret
	
	
sun_setAngle:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;angle in radians		4
	sub esp, 16			;temp vector
	
	;convert the angle to radians
	movss xmm0, dword[ebp+8]
	movss xmm1, dword[deg2rad]
	mulss xmm0, xmm1
	movss dword[ebp-4], xmm0
	
	;get the projection to the plane vector 1
	fld dword[ebp-4]
	fsin
	sub esp, 4
	fstp dword[esp]
	push sun_rotational_plane_1
	lea eax, [ebp-20]
	push eax
	call vec4_scale
	add esp, 12
	
	;get the projection to the plane vector 2
	fld dword[ebp-4]
	fcos
	sub esp, 4
	fstp dword[esp]
	push sun_rotational_plane_2
	push direction
	call vec4_scale
	add esp, 12
	
	;add the projections
	lea eax, [ebp-20]
	push eax
	push direction 
	push direction
	call vec4_add
	add esp, 12
	
	mov esp, ebp
	pop ebp
	ret
	
	
sun_setDistance:
	mov eax, dword[esp+4]
	mov dword[distance], eax
	ret