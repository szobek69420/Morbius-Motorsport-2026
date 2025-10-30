[BITS 32]

;layout:
;struct Camera{
;	vec3 position;				;0
;	float pitchInDegrees, yawInDegrees;	;12
;	float nearClip, farClip;		;20
;	float vFovInDegrees, aspectXY;		;28
;}						;36 bytes overall

section .rodata use32
	DEG2RAD dd 0.017453293

	DEFAULT_FOV dd 60.0
	DEFAULT_NEAR_CLIP dd 0.15
	DEFAULT_FAR_CLIP dd 100.0
	DEFAULT_ASPECT_XY dd 1.0
	
	WORLD_UP dd 0.0, 1.0, 0.0
	
	ONE dd 1.0

section .text use32
	extern vec3_print
	extern vec3_normalize
	extern vec3_cross
	
	extern mat4_mul
	extern mat4_viewGlm
	extern mat4_perspectiveGlm
	
	global camera_init				;void camera_init(camera* buffer);
	global camera_view				;void camera_view(camera* cum, mat4* buffer)
	global camera_projection		;void camera_projection(camera* cum, mat4* buffer)
	global camera_viewProjection	;void camera_viewProjection(camera* cum, mat4* buffer)
	global camera_forward			;void camera_forward(camera* cum, vec3* buffer)
	global camera_right				;void camera_right(camera* cum, vec3* buffer)
	global camera_up				;void camera_up(camera* cum, vec3* buffer)
	
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
	call mat4_viewGlm
	
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
	call mat4_perspectiveGlm
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
	
	sub esp, 4					;pitch in radians		4
	sub esp, 4					;yaw in radians			8
	sub esp, 4					;sin(pitch)				12
	sub esp, 4					;cos(pitch)				16
	sub esp, 4					;sin(yaw)				20
	sub esp, 4					;cos(yaw)				24
	
	;convert pitch and yaw
	mov eax, dword[ebp+8]
	movss xmm0, dword[DEG2RAD]
	
	movss xmm1, dword[eax+12]
	mulss xmm1, xmm0
	movss dword[ebp-4], xmm1
	
	movss xmm1, dword[eax+16]
	mulss xmm1, xmm0
	movss dword[ebp-8], xmm1
	
	;do trigonometry
	fld dword[ebp-4]
	fsincos
	fstp dword[ebp-16]
	fstp dword[ebp-12]
	
	fld dword[ebp-8]
	fsincos
	fstp dword[ebp-24]
	fstp dword[ebp-20]
	
	;calculate direction
	mov eax, dword[ebp+12]		;buffer in eax
	
	movss xmm0, dword[ebp-12]
	movss dword[eax+4], xmm0		;direction.y = sin(pitch)
	
	movss xmm0, dword[ebp-16]
	movss xmm1, dword[ebp-20]
	mulss xmm1, xmm0
	movss dword[eax], xmm1			;direction.x = cos(pitch)*sin(yaw)
	
	movss xmm1, dword[ebp-24]
	mulss xmm1, xmm0
	movss dword[eax+8], xmm1
	xor dword[eax+8], 0x80000000	;direction.z = -cos(pitch)*cos(yaw)
	
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
	
