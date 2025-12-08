[BITS 32]

;struct PointLight4D{
;	vec4 position;		0
;	vec4 colour;		16	//colour.rgb, intensity
;}		32 bytes overall

;struct LightManager4D{
;	vector<PointLight4D*> registeredLights;								0
;	tsQueue<{PointLight4D*, int isDeleteUpdate}> pendingUpdates;		16
;}		24 bytes overall


section .text use32

	global lightManager4d_create			;LightManager4D* lightManager4d_create()
	global lightManager4d_destroy			;void lightManager4d_destroy(LightManager4D* destroy)
	
	global lightManager4d_registerLight		;PointLight4D* lightManager4d_registerLight(LightManager4D* lm, const vec4* pos4D, const vec3* colour, float intensity)
	global lightManager4d_registerLightArray	;void lightManager4d_registerLightArray(LightManager4D* lm, vector<{vec4, vec3, float}>* lights, vector<PointLight4D*> outIDs)
	
	global lightManager4d_yeetLight			;void lightManager4d_yeetLight(LightManager4D* lm, PointLight4D* light)
	
	global lightManager4d_processUpdates	;void lightManager4d_processUpdates(LightManager4D* lm)
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove_at
	extern vector_search
	extern vector_for_each
	
	extern tsQueue_init
	extern tsQueue_destroy
	extern tsQueue_pop
	extern tsQueue_push
	extern tsQueue_sizeNonBlocking
	extern tsQueue_lock
	extern tsQueue_unlock
	
	
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