[BITS 32]

;layout:
;struct camera{
;	vec3 position;				;0
;	float pitchInDegrees, yawInDegrees;	;12
;	float nearClip, farClip;		;20
;	float vFovInDegrees, aspectXY;		;28
;}						;36 bytes overall

section .rodata use32
	DEG2RAD dd 0.017453293

	DEFAULT_FOV dd 60.0
	DEFAULT_NEAR_CLIP dd 0.15
	DEFAULT_FAR_CLIP dd 30.0
	DEFAULT_ASPECT_XY dd 1.0
	
	WORLD_UP dd 0.0, 1.0, 0.0
	
	ONE dd 1.0

section .text use32
	extern vec3_print
	extern vec3_normalize
	extern vec3_cross
	
	extern mat4_mul
	extern mat4_view
	extern mat4_perspective2
	
	global camera_init		;void camera_init(camera* buffer);
	global camera_view		;void camera_view(camera* cum, mat4* buffer)
	global camera_projection	;void camera_projection(camera* cum, mat4* buffer)
	global camera_viewProjection	;void camera_viewProjection(camera* cum, mat4* buffer)
	global camera_forward		;void camera_forward(camera* cum, vec3* buffer)
	global camera_right		;void camera_right(camera* cum, vec3* buffer)
	global camera_up		;void camera_up(camera* cum, vec3* buffer)
	
camera_init:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;buffer in eax

	;set position and rotation
	mov dword[eax], 0
	mov dword[eax+4], 0
	mov dword[eax+8], 0
	mov dword[eax+12], 0
	mov dword[eax+16], 0
	
	mov ecx, dword[DEFAULT_NEAR_CLIP]
	mov dword[eax+20], ecx
	mov ecx, dword[DEFAULT_FAR_CLIP]
	mov dword[eax+24], ecx
	
	mov ecx, dword[DEFAULT_FOV]
	mov dword[eax+28], ecx
	mov ecx, dword[DEFAULT_ASPECT_XY]
	mov dword[eax+32], ecx
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
camera_view:
	push ebp
	mov ebp, esp
	
	sub esp, 12			;direction
	
	;calculate direction
	mov eax, dword[ebp+8]		;camera in eax
	mov ecx, esp
	push ecx
	push eax
	call camera_forward
	add esp, 8
	
	
	
	mov eax, dword[ebp+8]		;camera in eax
	mov ecx, dword[ebp+12]		;buffer in ecx
	lea edx, [ebp-12]		;direction in edx
	
	push WORLD_UP
	push edx
	push eax
	push ecx
	call mat4_view
	
	mov esp, ebp
	pop ebp
	ret
	
	
camera_projection:
	mov eax, dword[esp+4]		;camera in eax
	mov ecx, dword[esp+8]		;buffer in ecx
	
	;calc matrix
	push dword[eax+24]
	push dword[eax+20]
	push dword[eax+32]
	push dword[eax+28]
	push ecx
	call mat4_perspective2
	add esp, 20
	
	ret
	
	
camera_viewProjection:
	push ebp
	mov ebp, esp
	
	sub esp, 64			;temp view matrix
	
	mov eax, dword[ebp+8]		;camera in eax
	mov ecx, dword[ebp+12]		;buffer in ecx
	
	;calculate projection matrix
	push ecx
	push eax
	call camera_projection
	
	;calculate view matrix
	lea eax, [ebp-64]
	mov dword[esp+4], eax
	call camera_view
	add esp, 8
	
	;morb
	mov eax, dword[ebp+12]
	lea ecx, [ebp-64]
	push ecx
	push eax
	push eax
	call mat4_mul
	
	mov esp, ebp
	pop ebp
	ret
	
	
camera_forward:
	push ebp
	mov ebp, esp
	
	;calculate direction
	mov eax, dword[ebp+8]		;camera in eax
	mov edx, dword[ebp+12]		;buffer in edx
	movss xmm0, dword[DEG2RAD]
	
	movss xmm1, dword[eax+12]
	mulss xmm1, xmm0		;pitch in xmm1
	movss dword[edx+4], xmm1
	fld dword[edx+4]
	fsin
	fstp dword[edx+4]		;sin(pitch) in direction.y
	
	sub esp, 4			;temp place for cos(pitch)
	movss dword[esp], xmm1
	fld dword[esp]
	fcos
	fstp dword[esp]			
	movss xmm1, dword[esp]		;cos(pitch) in xmm1
	add esp, 4
	
	movss xmm2, dword[eax+16]
	mulss xmm2, xmm0
	movss dword[edx], xmm2
	fld dword[edx]
	fsin
	fstp dword[edx]
	movss xmm2, dword[edx]
	mulss xmm2, xmm1
	movss dword[edx], xmm2	;sin(yaw)*cos(pitch) in direction.x
	
	movss xmm2, dword[eax+16]
	mulss xmm2, xmm0
	movss dword[edx+8], xmm2
	fld dword[edx+8]
	fcos
	fstp dword[edx+8]
	movss xmm2, dword[edx+8]
	mulss xmm2, xmm1
	movss dword[edx+8], xmm2
	xor dword[edx+8], 0x80000000	;-cos(yaw)*cos(pitch) in direction.z
	
	mov esp, ebp
	pop ebp
	ret
	

camera_right:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;cum in eax
	mov ecx, dword[ebp+12]		;buffer in ecx
	
	push ecx
	push eax
	call camera_forward
	add esp, 4
	pop ecx
	
	push WORLD_UP
	push ecx
	push ecx
	call vec3_cross
	call vec3_normalize
	
	mov esp, ebp
	pop ebp
	ret
	
	
camera_up:
	push ebp
	mov ebp, esp
	
	sub esp, 12			;forward
	
	mov eax, dword[ebp+8]		;cum in eax
	mov ecx, esp
	
	push ecx
	push eax
	call camera_forward
	add esp, 4
	pop ecx
	
	mov eax, dword[ebp+12]		;buffer in eax
	push WORLD_UP
	push ecx
	push eax
	call vec3_cross
	call vec3_normalize
	pop eax
	pop ecx
	add esp, 4
	
	push eax
	push ecx
	push eax
	call vec3_cross
	
	mov esp, ebp
	pop ebp
	ret
	
