[BITS 32]

section .rodata use32
	error_not_initialized_update db "physics_update: physics_init should be called",10,0
	error_not_initialized_registerKinematic db "physics_registerKinematic: physics_init should be called",10,0
	error_not_initialized_registerNonkinematic db "physics_registerNonkinematic: physics_init should be called",10,0

	print_remaining_colliders db "physics_deinit:",10,9,"remaining non-kinematic colliders: %d",10,9,"remaining kinematic colliders: %d",10,0

section .data use32
	is_initialized dd 0

section .bss use32
	registered_nonkinematic resb 16			;vector<Collider*>
	registered_kinematic resb 16			;vector<Collider*>

section .text use32

	global physics_init						;void physics_init()
	global physics_deinit					;void physics_deinit()
	
	global physics_update					;void physics_update(float deltaTime)
	
	global physics_registerNonkinematic		;void physics_registerNonkinematic(Collider* collider)
	global physics_registerKinematic		;void physics_registerKinematic(Collider* collider)
	global physics_unregisterNonkinematic	;void physics_unregisterNonkinematic(Collider* collider)
	global physics_unregisterKinematic		;void physics_unregisterKinematic(Collider* collider)
	
	
	extern collisionDetection_resolveKinematicNonkinematic
	
	extern my_printf
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove
	
	extern vec3_add
	extern vec3_scale
	
	
physics_init:
	push ebp
	mov ebp, esp
	
	;init vectors
	push 4
	push registered_nonkinematic
	call vector_init
	
	push 4
	push registered_kinematic
	call vector_init
	
	;mark as initialized
	mov dword[is_initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	
	
physics_deinit:
	push ebp
	mov ebp, esp
	
	;print remaining colliders
	push dword[registered_kinematic]
	push dword[registered_nonkinematic]
	push print_remaining_colliders
	call my_printf
	
	
	;destroy vectors
	push registered_nonkinematic
	call vector_destroy
	
	push registered_kinematic
	call vector_destroy
	
	
	;mark as uninitialized
	mov dword[is_initialized], 0
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
physics_update:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 12				;helper vec3			;12
	
	;check if the system has been initialized
	cmp dword[is_initialized], 0
	jne physics_update_initialized
		push error_not_initialized_update
		call my_printf
		jmp physics_update_end
	
	physics_update_initialized:
	
	
	;clear collision info
	mov esi, dword[registered_nonkinematic]		;index in esi
	mov edi, registered_nonkinematic
	mov edi, dword[edi+12]						;current position in array in edi
	test esi, esi
	jz physics_update_clear_loop_end
	physics_update_clear_loop_start:
		mov eax, dword[edi]
		mov dword[eax+20], 0
		
		add edi, 4
		dec esi
		test esi, esi
		jnz physics_update_clear_loop_start
		
	physics_update_clear_loop_end:
	
	;move the bodies according to their velocity
	mov esi, dword[registered_nonkinematic]		;index in esi
	mov edi, registered_nonkinematic
	mov edi, dword[edi+12]						;current position in array in edi
	test esi, esi
	jz physics_update_apply_velocity_loop_end
	physics_update_apply_velocity_loop_start:
		push dword[ebp+20]
		mov eax, dword[edi]
		add eax, 32
		push eax
		lea eax, [ebp-12]
		push eax
		call vec3_scale
		push dword[edi]
		push dword[edi]
		call vec3_add
		
		add edi, 4
		dec esi
		test esi, esi
		jnz physics_update_apply_velocity_loop_start
		
	physics_update_apply_velocity_loop_end:
	
	
	;check for collisions
	mov esi, dword[registered_nonkinematic]		;index in esi
	mov edi, registered_nonkinematic
	mov edi, dword[edi+12]						;current position in array in edi
	test esi, esi
	jz physics_update_collision_nonkinematic_loop_end
	physics_update_collision_nonkinematic_loop_start:
	
		;MAYBE TODO: sort the kinematic colliders according to their distance from the current non-kinematic
		;or maybe iterate through the kinematic colliders in the outer loop as it is most likely that there will be more kinematic colliders in the scene than non-kinematic ones
		;thus reducing the time spent sorting
		
		push esi		;save esi
		mov esi, dword[registered_kinematic]		;index in esi
		mov ebx, registered_kinematic
		mov ebx, dword[ebx+12]						;current position in array in ebx
		test esi, esi
		jz physics_update_collision_kinematic_loop_end
		physics_update_collision_kinematic_loop_start:
			
			push dword[edi]
			push dword[ebx]
			call collisionDetection_resolveKinematicNonkinematic
			add esp, 8
			
			add ebx, 4
			dec esi
			test esi, esi
			jnz physics_update_collision_kinematic_loop_start
		physics_update_collision_kinematic_loop_end:
		pop esi			;restore esi
	
	physics_update_collision_nonkinematic_loop_end:
	
	physics_update_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
physics_registerNonkinematic:
	push ebp
	mov ebp, esp
	
	;check if the system has been initialized
	cmp dword[is_initialized], 0
	jne physics_registerNonkinematic_initialized
		push error_not_initialized_registerNonkinematic
		call my_printf
		jmp physics_registerNonkinematic_end
	
	physics_registerNonkinematic_initialized:
	
	push dword[ebp+8]
	push registered_nonkinematic
	call vector_push_back
	
	physics_registerNonkinematic_end:
	mov esp, ebp
	pop ebp
	ret
	
	
physics_registerKinematic:
	push ebp
	mov ebp, esp
	
	;check if the system has been initialized
	cmp dword[is_initialized], 0
	jne physics_registerKinematic_initialized
		push error_not_initialized_registerKinematic
		call my_printf
		jmp physics_registerKinematic_end
	
	physics_registerKinematic_initialized:
	
	push dword[ebp+8]
	push registered_kinematic
	call vector_push_back
	
	physics_registerKinematic_end:
	mov esp, ebp
	pop ebp
	ret
	
	
physics_unregisterNonkinematic:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	push registered_nonkinematic
	call vector_remove

	mov esp, ebp
	pop ebp
	ret
	
	
physics_unregisterKinematic:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	push registered_kinematic
	call vector_remove

	mov esp, ebp
	pop ebp
	ret