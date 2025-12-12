[BITS 32]

;struct PointLight4D{
;	vec4 position;		0
;	vec4 colour;		16	//colour.rgb, intensity
;}		32 bytes overall

;struct LightManager4D{
;	vector<PointLight4D*> registeredLights;								0
;	tsQueue<{PointLight4D*, int isDeleteUpdate}> pendingUpdates;		16
;}		24 bytes overall

section .rodata use32
	
	MAX_DISTANCE_FROM_PLANE dd 2.0		;very small, so that not too many lights outside of the plane are included
	DISTANCE_SCALER dd 0.5
	
	ATTENUATION_CONSTANT dd 1.0
	ATTENUATION_LINEAR dd 0.7
	ATTENUATION_QUADRATIC dd 1.8
	
	ONE dd 1.0

section .text use32

	global lightManager4d_create			;LightManager4D* lightManager4d_create()
	global lightManager4d_destroy			;void lightManager4d_destroy(LightManager4D* destroy)
	
	global lightManager4d_registerLight		;PointLight4D* lightManager4d_registerLight(LightManager4D* lm, const vec4* pos4D, const vec3* colour, float intensity)
	global lightManager4d_registerLightArray	;void lightManager4d_registerLightArray(LightManager4D* lm, vector<{vec4, vec3, float}>* lights, vector<PointLight4D*>* outIDs)
	
	global lightManager4d_yeetLight			;void lightManager4d_yeetLight(LightManager4D* lm, PointLight4D* light)
	global lightManager4d_yeetLightArray	;void lightManager4d_yeetLightArray(LightManager4D* lm, vector<PointLight4D*>* lights)
	
	global lightManager4d_processUpdates	;void lightManager4d_processUpdates(LightManager4D* lm)
	
	;recalculates the rendered lights
	;should be called from the graphics thread
	;void lightManager4d_update3d(LightManager4D* lm, HyperPlane* hp, vec4* playerPos)
	global lightManager4d_update3d
	
	extern LIGHT_RENDERER_MAX_LIGHTS
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern my_qsort
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove_at
	extern vector_search
	extern vector_for_each
	extern vector_at
	
	extern tsQueue_init
	extern tsQueue_destroy
	extern tsQueue_pop
	extern tsQueue_push
	extern tsQueue_pushArray
	extern tsQueue_sizeNonBlocking
	extern tsQueue_lock
	extern tsQueue_unlock
	extern tsQueue_queue
	
	extern vec4_sub
	extern vec4_sqrMagnitude
	
	extern lightRenderer_updatePointLights
	extern light_createPoint
	extern light_setPosition
	extern light_setColour
	extern light_setIntensity
	extern light_calculateRadius
	
	extern hyperPlane_positionTo3d
	extern hyperPlane_getEquation
	extern hyperPlane_signedDistance
	
	
lightManager4d_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;lm			4
	
	;alloc space
	push 24
	call my_malloc
	mov dword[ebp-4], eax
	
	
	;init pointlight vector
	mov eax, dword[ebp-4]
	push 4
	push eax
	call vector_init
	
	;init update queue
	mov eax, dword[ebp-4]
	add eax, 16
	push 16384
	push 8
	push eax
	call tsQueue_init
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
lightManager4d_destroy:
	push ebp
	mov ebp, esp
	
	;process all pending updates
	push dword[ebp+8]
	call lightManager4d_processUpdates
	
	;free the point lights
	push 0
	push lightManager4d_destroy_free_light
	push dword[ebp+8]
	call vector_for_each
	
	;destroy the update queue and the light vector
	mov eax, dword[ebp+8]
	push eax
	add eax, 16
	push eax
	call tsQueue_destroy
	add esp, 4
	call vector_destroy
	
	;free the lightmanager
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	lightManager4d_destroy_free_light:		;void func(PointLight4D** pElement, int zero)
		mov eax, dword[esp+4]
		push dword[eax]
		call my_free
		add esp, 4
		ret


lightManager4d_registerLight:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;point light		4
	
	;alloc point light
	push 16
	call my_malloc
	mov dword[ebp-4], eax
	
	;set point light values
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp+12]
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	mov edx, dword[ecx+8]
	mov dword[eax+8], edx
	mov edx, dword[ecx+12]
	mov dword[eax+12], edx
	
	mov ecx, dword[ebp+16]
	mov edx, dword[ecx]
	mov dword[eax+16], edx
	mov edx, dword[ecx+4]
	mov dword[eax+20], edx
	mov edx, dword[ecx+8]
	mov dword[eax+24], edx
	
	mov edx, dword[ebp+20]
	mov dword[eax+28], edx
	
	;add the values to the queue
	mov eax, dword[ebp+8]
	add eax, 16
	push 0			;not delete update
	push dword[ebp-4]
	push eax
	call tsQueue_push
	
	;return the light
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
lightManager4d_registerLightArray:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;queue				4
	sub esp, 4			;PointLight4D**		8
	sub esp, 4			;light array		12
	sub esp, 4			;register gg		16
	
	mov dword[ebp-16], 0
	
	;check if there are any lights
	mov eax, dword[ebp+24]
	cmp dword[eax], 0
	jle lightManager4d_registerLightArray_end
	
	;create all of the lights
	mov eax, dword[ebp+24]
	mov eax, dword[eax]
	shl eax, 2
	mov dword[ebp-12], eax
	push dword[ebp-12]
	call my_malloc
	mov dword[ebp-8], eax
	
	xor ebx, ebx
	mov esi, dword[ebp+24]
	mov esi, dword[esi+12]
	mov edi, dword[ebp-8]
	lightManager4d_registerLightArray_create_loop_start:
		push 32
		call my_malloc
		mov dword[edi+4*ebx], eax
		add esp, 4
		
		push edi
		mov edi, dword[edi+4*ebx]
		movsd
		movsd
		movsd
		movsd
		movsd
		movsd
		movsd
		movsd
		pop edi
		
		add edi, 4
		inc ebx
		cmp ebx, dword[ebp-12]
		jl lightManager4d_registerLightArray_create_loop_start
	
	;lock queue
	mov eax, dword[ebp+20]
	add eax, 16
	push eax
	call tsQueue_lock
	
	;check if there is enough space in the queue
	call tsQueue_queue
	mov dword[ebp-4], eax
	
	mov ecx, dword[eax+8]
	sub ecx, dword[eax+4]
	mov edx, dword[ebp+24]
	cmp ecx, dword[edx]
	jge lightManager4d_registerLightArray_enough_space
		push lightManager4d_registerLightArray_error_not_enough_space
		call my_printf
		jmp lightManager4d_registerLight_unlock
		lightManager4d_registerLightArray_error_not_enough_space db "lightManager4d_registerLightArray: there is not enough space in the pending updates queue",10,0
	lightManager4d_registerLightArray_enough_space:
	
	;register all of the lights
	mov esi, dword[ebp-8]		;current light in esi
	mov edi, dword[ebp-12]		;index in edi
	lightManager4d_registerLightArray_register_loop_start:
		push 0		;register update
		push dword[esi]
		mov eax, dword[ebp+20]
		add eax, 16
		push eax
		call tsQueue_push
		add esp, 12
		
		add esi, 4
		dec edi
		jnz lightManager4d_registerLightArray_register_loop_start
		
	;registration is complete
	mov dword[ebp-16], 69
	
	lightManager4d_registerLight_unlock:
	;unlock queue
	mov eax, dword[ebp+20]
	add eax, 16
	push eax
	call tsQueue_lock
	
	;put all of the lights into the out vector
	test dword[ebp-16], 0xffffffff
	jz lightManager4d_registerLightArray_freeArray
		mov ebx, dword[ebp+28]			;vector in ebx
		mov esi, dword[ebp-8]			;current light in esi
		mov edi, dword[ebp-12]			;index in edi
		lightManager4d_registerLightArray_out_loop_start:
			push dword[esi]
			push ebx
			call vector_push_back
			add esp, 8
		
			add esi, 4
			dec edi
			jnz lightManager4d_registerLightArray_out_loop_start
	
	;free the light array
	lightManager4d_registerLightArray_freeArray:
	push dword[ebp-8]
	call my_free
	
	lightManager4d_registerLightArray_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
lightManager4d_yeetLight:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	add eax, 16
	push 69			;delete update
	push dword[ebp+12]
	push eax
	call tsQueue_push
	
	mov esp, ebp
	pop ebp
	ret
	
	
lightManager4d_yeetLightArray:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16			;vector<{PointLight4D*,int}> deleteUpdates		16
	
	;check if there are any lights to delete
	mov eax, dword[ebp+24]
	cmp dword[eax], 0
	jle lightManager4d_yeetLightArray_end
	
	;create the vector and fill it
	push 8
	lea eax, [ebp-16]
	push eax
	call vector_init
	
	;fill the vector
	lea eax, [ebp-16]
	push eax
	push lightManager4d_yeetLightArray_fillQueueVector
	push dword[ebp+24]
	call vector_for_each
	
	;add the updates to the pending queue if possible
	mov eax, dword[ebp+20]
	add eax, 16
	push eax
	call tsQueue_lock
	
	call tsQueue_queue
	mov ecx, dword[eax+8]
	sub ecx, dword[eax+4]
	mov edx, dword[ebp+20]
	cmp ecx, dword[edx]
	jge lightManager4d_yeetLightArray_enough_space		;enough space
		push lightManager4d_yeetLightArray_error_not_enough_space
		call my_printf
		jmp lightManager4d_yeetLightArray_unlock
	
		lightManager4d_yeetLightArray_error_not_enough_space db "lightManager4d_yeetLightArray: not enough space in the update queue",10,0
	lightManager4d_yeetLightArray_enough_space:
	
	mov eax, dword[ebp+20]
	add eax, 16
	push dword[ebp-16]
	push dword[ebp-4]
	push eax
	call tsQueue_pushArray
	
	lightManager4d_yeetLightArray_unlock:
	mov eax, dword[ebp+20]
	add eax, 16
	push eax
	call tsQueue_unlock
	
	;destroy vector
	lea eax, [ebp-16]
	push eax
	call vector_destroy
	
	lightManager4d_yeetLightArray_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	lightManager4d_yeetLightArray_fillQueueVector:		;void func(PointLight4D**, vector<{PointLight4D*,int}>*)
		push ebp
		mov ebp, esp
		
		push 69				;delete update
		mov eax, dword[ebp+8]
		push dword[eax]
		push dword[ebp+12]
		call vector_push_back
		
		mov esp, ebp
		pop ebp
		ret
	
lightManager4d_processUpdates:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;tsQueue*		4
	sub esp, 8			;update buffer	12
	
	mov eax, dword[ebp+8]
	add eax, 16
	mov dword[ebp-4], eax
	
	;check if there are updates
	push dword[ebp-4]
	call tsQueue_sizeNonBlocking
	test eax, eax
	jz lightManager4d_processUpdates_end
	
	;lock the queue
	push dword[ebp-4]
	call tsQueue_lock
	
	
	lightManager4d_processUpdates_loop_start:
		;pop update
		lea eax, [ebp-12]
		push eax
		push dword[ebp-4]
		call tsQueue_pop
		add esp, 8
		test eax, eax
		jnz lightManager4d_processUpdates_loop_end	;empty
		
		test dword[ebp-8], 0xffffffff
		jnz lightManager4d_processUpdates_loop_delete
		lightManager4d_processUpdates_loop_register:
			;register update
			push dword[ebp-12]
			push dword[ebp+8]
			call vector_push_back
			
			jmp lightManager4d_processUpdates_loop_start
		
		lightManager4d_processUpdates_loop_delete:
			;delete update
			push dword[ebp-12]
			push lightManager4d_processUpdates_loop_delete_cmp
			push dword[ebp+8]
			call vector_search
			cmp eax, -1
			je lightManager4d_processUpdates_loop_start
			
			push eax
			push dword[ebp+8]
			call vector_remove_at
			
			jmp lightManager4d_processUpdates_loop_start
			lightManager4d_processUpdates_loop_delete_cmp:		;int func(PointLight4D** pElement, PointLight4D* key)
				mov eax, 69
				mov ecx, dword[esp+4]
				mov ecx, dword[ecx]
				cmp ecx, dword[esp+8]
				jne lightManager4d_processUpdates_loop_delete_cmp_end
					xor eax, eax
				lightManager4d_processUpdates_loop_delete_cmp_end
				ret
			
	lightManager4d_processUpdates_loop_end:
	
	;unlock the queue
	push dword[ebp-4]
	call tsQueue_lock
	
	lightManager4d_processUpdates_end:
	mov esp, ebp
	pop ebp
	ret
	
	
lightManager4d_update3d:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16			;vector<{PointLight*,float}> 3dLights		;16	//float is the square distance from the player in 4d
	sub esp, 20			;hyperplane equation				;36
	sub esp, 4			;helper								;40
	sub esp, 4			;scaled intensity					;44
	sub esp, 12			;3d pos								;56
	sub esp, 16			;vec4 helper						;72
	
	;check if there are any lights
	mov eax, dword[ebp+20]
	cmp dword[eax], 0
	jle lightManager4d_update3d_end
	
	;get the hyperplane equation
	lea eax, [ebp-36]
	push eax
	push dword[ebp+24]
	call hyperPlane_getEquation
	
	;create the 3d light vector
	push 8
	lea eax, [ebp-16]
	push eax
	call vector_init
	
	;create 3d lights if they are close enough to the plane
	mov esi, dword[ebp+20]
	mov edi, dword[esi]			;index in edi
	mov esi, dword[esi+12]
	lightManager4d_update3d_create_loop_start:
		mov ebx, dword[esi]
		
		;get distance
		push ebx
		lea eax, [ebp-36]
		push eax
		call hyperPlane_signedDistance
		fstp dword[ebp-40]
		and dword[ebp-40], 0x7fffffff
		
		mov eax, dword[ebp-40]
		cmp eax, dword[MAX_DISTANCE_FROM_PLANE]
		jg lightManager4d_update3d_create_loop_continue
		
		;calculate light intensity and position
		movss xmm0, dword[ONE]
		movss xmm1, dword[ebp-40]
		mulss xmm1, dword[DISTANCE_SCALER]
		subss xmm0, xmm1
		movss dword[ebp-44], xmm0
		
		lea eax, [ebp-56]
		push eax
		push ebx
		push dword[ebp+24]
		call hyperPlane_positionTo3d
		
		;calculate sqr distance
		lea eax, [ebp-72]
		push dword[ebp+28]
		push ebx
		push eax
		call vec4_sub
		call vec4_sqrMagnitude
		fstp dword[ebp-60]
		
		;create light
		call light_createPoint
		mov dword[ebp-40], eax
		
		push dword[ebp-48]
		push dword[ebp-52]
		push dword[ebp-56]
		push dword[ebp-40]
		call light_setPosition
		push dword[ebp-44]
		push dword[ebp-40]
		call light_setIntensity
		push dword[ebx+24]
		push dword[ebx+20]
		push dword[ebx+16]
		push dword[ebp-40]
		call light_setColour
		push dword[ATTENUATION_CONSTANT]
		push dword[ATTENUATION_LINEAR]
		push dword[ATTENUATION_QUADRATIC]
		push dword[ebp-40]
		call light_calculateRadius
		
		;add to vector
		lea eax, [ebp-16]
		push dword[ebp-60]		;sqrMagnitude
		push dword[ebp-40]
		push eax
		call vector_push_back
		
		lightManager4d_update3d_create_loop_continue:
		add esi, 4
		dec edi
		jnz lightManager4d_update3d_create_loop_start
		
	;check if sort and shortening is necessary
	mov eax, dword[ebp-16]
	cmp eax, dword[LIGHT_RENDERER_MAX_LIGHTS]
	jle lightManager4d_update3d_skip_sort
		;sort 
		push lightManager4d_update3d_sort_compare
		push dword[ebp-8]
		push dword[ebp-16]
		push dword[ebp-4]
		call my_qsort
		
		;delete the remaining lights
		lightManager4d_update3d_delete_surplus_loop_start:
			push dword[LIGHT_RENDERER_MAX_LIGHTS]
			lea eax, [ebp-16]
			push eax
			call vector_at
			
			push dword[eax]
			call my_free		;delete light
			add esp, 4
			
			call vector_remove_at
			add esp, 8
			
			mov eax, dword[ebp-16]
			cmp eax, dword[LIGHT_RENDERER_MAX_LIGHTS]
			jg lightManager4d_update3d_delete_surplus_loop_start
		
		jmp lightManager4d_update3d_skip_sort
		
		lightManager4d_update3d_sort_compare:		;int func({PointLight*, float}* a, {PointLight*, float}* b)
			push ebp
			mov ebp, esp
			
			sub esp, 4		;a-b		4
			
			mov eax, dword[ebp+8]
			mov ecx, dword[ebp+12]
			movss xmm0, dword[eax+4]
			subss xmm0, dword[ecx+4]
			movss dword[ebp-4], xmm0
			
			mov eax, dword[ebp-4]		;sign checks out so float is fine
			
			mov esp, ebp
			pop ebp
			ret
	lightManager4d_update3d_skip_sort:
	
	;send all of the lights to the renderer
	lea eax, [ebp-16]
	push eax
	call lightRenderer_updatePointLights
	
	;destroy the 3d light vector
	lea eax, [ebp-16]
	push eax
	call vector_destroy
	
	lightManager4d_update3d_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	