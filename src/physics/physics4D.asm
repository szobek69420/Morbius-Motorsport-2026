[BITS 32]

;layout:
;struct Physics4DRegisterOperation{
;	Aabb4D* collider or ColliderGroup4D* cg;
;	int isColliderGroup;
;	int operationInfo;		;0: register, 69: unregister, 420: unregister and destroy
;}		//overall 12 bytes

section .rodata use32
	error_not_initialized_update db "physics4d_update: physics4d_init should be called",10,0
	error_not_initialized_registerColliderGroup db "physics4d_registerColliderGroup: physics4d_init should be called",10,0
	error_not_initialized_registerNonkinematic db "physics4d_registerNonkinematic: physics4d_init should be called",10,0

	print_remaining_colliders db "physics4d_deinit:",10,9,"remaining colliders: %d",10,9,"remaining collider groups: %d",10,0
	
section .data use32
	is_initialized dd 0

section .bss use32
	registered_nonkinematic resb 16			;vector<Aabb4D*>
	registered_collider_groups resb 16		;vector<ColliderGroup4D*>
	
	register_operation_buffer resb 8		;tsQueue<Physics4DRegisterOperation>
	
section .text use32

	global physics4d_init					;void physics4d_init()
	global physics4d_deinit					;void physics4d_deinit()
	
	global physics4d_update					;void physics4d_update(float deltaTime)
	
	;void physics4d_processPendingRegisterOperations()
	global physics4d_registerNonkinematic		;void physics4d_registerNonkinematic(Aabb4D* collider)
	global physics4d_registerColliderGroup		;void physics4d_registerColliderGroup(ColliderGroup* cg)
	global physics4d_unregisterNonkinematic		;void physics4d_unregisterNonkinematic(Aabb4D* collider, int shouldDestroy)
	global physics4d_unregisterColliderGroup	;void physics4d_unregisterColliderGroup(ColliderGroup* cg, int shouldDestroy)
	
	extern aabb4d_destroy
	
	extern colliderGroup4d_destroy
	extern colliderGroup4d_resolveCollision
	
	extern my_printf
	extern my_memcpy
	
	extern hyperPlane_create
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove
	
	extern tsQueue_init
	extern tsQueue_destroy
	extern tsQueue_pushBuffer
	extern tsQueue_pop
	extern tsQueue_isEmpty
	
	extern vec4_add
	extern vec4_scale
	
	
physics4d_init:
	push ebp
	mov ebp, esp
	
	;init vectors
	push 4
	push registered_nonkinematic
	call vector_init
	
	push 4
	push registered_collider_groups
	call vector_init
	
	;init thread safe queue
	push 50
	push 12
	push register_operation_buffer
	call tsQueue_init
	
	;mark as initialized
	mov dword[is_initialized], 69
	
	mov esp, ebp
	pop ebp
	ret
	
	
physics4d_deinit:
	push ebp
	mov ebp, esp
	
	;process pending operations
	;so that if a collider is unregistered in the last frame (or after)
	;it still counts as a valid unregister (easier for debugging)
	call physics4d_processPendingRegisterOperations
	
	;print remaining colliders
	push dword[registered_collider_groups]
	push dword[registered_nonkinematic]
	push print_remaining_colliders
	call my_printf
	
	;destroy thread safe queue
	push register_operation_buffer
	call tsQueue_destroy
	
	;destroy vectors
	push registered_nonkinematic
	call vector_destroy
	
	push registered_collider_groups
	call vector_destroy
	
	
	;mark as uninitialized
	mov dword[is_initialized], 0
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
physics4d_update:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16				;helper vec4			;16
	
	;check if the system has been initialized
	cmp dword[is_initialized], 0
	jne physics4d_update_initialized
		push error_not_initialized_update
		call my_printf
		jmp physics4d_update_end
	
	physics4d_update_initialized:
	
	;process pending register operations
	call physics4d_processPendingRegisterOperations
	
	;clear collision info
	mov esi, dword[registered_nonkinematic]		;index in esi
	mov edi, registered_nonkinematic
	mov edi, dword[edi+12]						;current position in array in edi
	test esi, esi
	jz physics4d_update_clear_nonkinematic_loop_end
	physics4d_update_clear_nonkinematic_loop_start:
		mov eax, dword[edi]
		mov dword[eax+52], 0
		mov dword[eax+56], 0
		
		add edi, 4
		dec esi
		test esi, esi
		jnz physics4d_update_clear_nonkinematic_loop_start
	physics4d_update_clear_nonkinematic_loop_end:
	
	;move the bodies according to their velocity
	mov esi, dword[registered_nonkinematic]		;index in esi
	mov edi, registered_nonkinematic
	mov edi, dword[edi+12]						;current position in array in edi
	test esi, esi
	jz physics4d_update_apply_velocity_loop_end
	physics4d_update_apply_velocity_loop_start:
		push dword[ebp+20]
		mov eax, dword[edi]
		add eax, 32
		push eax
		lea eax, [ebp-16]
		push eax
		call vec4_scale
		push dword[edi]
		push dword[edi]
		call vec4_add
		
		add edi, 4
		dec esi
		test esi, esi
		jnz physics4d_update_apply_velocity_loop_start
	physics4d_update_apply_velocity_loop_end:
	
	
	;check for collisions
	mov esi, dword[registered_nonkinematic]		;index in esi
	mov edi, registered_nonkinematic
	mov edi, dword[edi+12]						;current position in array in edi
	test esi, esi
	jz physics4d_update_collision_nonkinematic_loop_end
	physics4d_update_collision_nonkinematic_loop_start:
	
		push esi		;save esi
		mov esi, dword[registered_collider_groups]	;index in esi
		mov ebx, registered_collider_groups
		mov ebx, dword[ebx+12]						;current position in array in ebx
		test esi, esi
		jz physics4d_update_collision_cg_loop_end
		physics4d_update_collision_cg_loop_start:
			
			push dword[edi]
			push dword[ebx]
			call colliderGroup4d_resolveCollision
			add esp, 8
			
			add ebx, 4
			dec esi
			test esi, esi
			jnz physics4d_update_collision_cg_loop_start
		physics4d_update_collision_cg_loop_end:
		pop esi			;restore esi
	
	physics4d_update_collision_nonkinematic_loop_end:
	
	physics4d_update_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
;void physics4d_processPendingRegisterOperation()
physics4d_processPendingRegisterOperations:
	push ebp
	mov ebp, esp
	
	sub esp, 12				;PhysicsRegisterOperation
	
	physics4d_ppro_loop_start:
		lea eax, [ebp-12]
		push eax
		push register_operation_buffer
		call tsQueue_isEmpty
		test eax, eax
		jnz physics4d_ppro_loop_end
		call tsQueue_pop
		add esp, 8
	
		push dword[ebp-12]			;collider* or collider group*
		cmp dword[ebp-8], 0		;isColliderGroup
		je physics4d_ppro_loop_isColliderGroup_false
		physics4d_ppro_loop_isColliderGroup_true:
			push registered_collider_groups
			jmp physics4d_ppro_loop_isColliderGroup_done
		physics4d_ppro_loop_isColliderGroup_false:
			push registered_nonkinematic
		physics4d_ppro_loop_isColliderGroup_done:
		cmp dword[ebp-4], 0		;register
		jne physics4d_ppro_loop_register_false
		physics4d_ppro_loop_register_true:
			mov eax, vector_push_back
			jmp physics4d_ppro_loop_register_done
		physics4d_ppro_loop_register_false:
			mov eax, vector_remove
		physics4d_ppro_loop_register_done:
		call eax
		add esp, 8
		
		;check if the collider/cg needs to be destroyed
		cmp dword[ebp-4], 420
		jne physics4d_ppro_loop_start
			mov eax, aabb4d_destroy
			cmp dword[ebp-8], 0
			je physics4d_ppro_loop_not_cg
				mov eax, colliderGroup4d_destroy
			physics4d_ppro_loop_not_cg:
		
			push dword[ebp-12]
			call eax
			add esp, 4
		
		jmp physics4d_ppro_loop_start
		
	physics4d_ppro_loop_end:
	
	mov esp, ebp
	pop ebp
	ret
	
	
physics4d_registerNonkinematic:
	push ebp
	mov ebp, esp
	
	sub esp, 12				;PhysicsRegisterOperation
	
	;check if the system has been initialized
	cmp dword[is_initialized], 0
	jne physics4d_registerNonkinematic_initialized
		push error_not_initialized_registerNonkinematic
		call my_printf
		jmp physics4d_registerNonkinematic_end
	
	physics4d_registerNonkinematic_initialized:
	
	mov ecx, dword[ebp+8]
	mov dword[ebp-12], ecx		;collider
	mov dword[ebp-8], 0		;not collider group
	mov dword[ebp-4], 0		;register
	lea eax, [ebp-12]
	push eax
	push register_operation_buffer
	call tsQueue_pushBuffer
	
	
	physics4d_registerNonkinematic_end:
	mov esp, ebp
	pop ebp
	ret
	
	
physics4d_registerColliderGroup:
	push ebp
	mov ebp, esp
	
	sub esp, 12					;PhysicsRegisterOperation
	
	;check if the system has been initialized
	cmp dword[is_initialized], 0
	jne physics4d_registerColliderGroup_initialized
		push error_not_initialized_registerColliderGroup
		call my_printf
		jmp physics4d_registerColliderGroup_end
	
	physics4d_registerColliderGroup_initialized:
	
	mov ecx, dword[ebp+8]
	mov dword[ebp-12], ecx		;collider group
	mov dword[ebp-8], 69		;it is a collider group
	mov dword[ebp-4], 0		;register
	lea eax, [ebp-12]
	push eax
	push register_operation_buffer
	call tsQueue_pushBuffer
	
	
	physics4d_registerColliderGroup_end:
	mov esp, ebp
	pop ebp
	ret
	
	
physics4d_unregisterNonkinematic:
	push ebp
	mov ebp, esp
	
	sub esp, 12					;PhysicsRegisterOperation
	
	mov dword[ebp-4], 69		;unregister
	cmp dword[ebp+12], 0
	je physics4d_unregisterNonkinematic_no_destroy
		mov dword[ebp-4], 420	;unregister and destroy
	physics4d_unregisterNonkinematic_no_destroy:
	
	mov ecx, dword[ebp+8]
	mov dword[ebp-12], ecx		;collider
	mov dword[ebp-8], 0		;not collider group
	lea eax, [ebp-12]
	push eax
	push register_operation_buffer
	call tsQueue_pushBuffer


	mov esp, ebp
	pop ebp
	ret
	
	
physics4d_unregisterColliderGroup:
	push ebp
	mov ebp, esp
	
	sub esp, 12					;PhysicsRegisterOperation
	
	mov dword[ebp-4], 69		;unregister
	cmp dword[ebp+12], 0
	je physics4d_unregisterColliderGroup_no_destroy
		mov dword[ebp-4], 420	;unregister and destroy
	physics4d_unregisterColliderGroup_no_destroy:
	
	mov ecx, dword[ebp+8]
	mov dword[ebp-12], ecx		;collider group
	mov dword[ebp-8], 69		;it is a collider group
	lea eax, [ebp-12]
	push eax
	push register_operation_buffer
	call tsQueue_pushBuffer


	mov esp, ebp
	pop ebp
	ret