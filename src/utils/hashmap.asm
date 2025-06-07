[BITS 32]

;struct hashmapelement{
;	void* pkey;				;0
;	void* pvalue;			;4
;	int keySizeInBytes;		;8
;	int valueSizeInBytes;	;12
;}	16 bytes overall

;struct hashmap{
;	vector<haspmapelement> buckets[256];	;0
;}	4096 bytes overall

section .rodata use32

	error_add_invalid_key db "hashMap_add: the key already exists",10,0

section .text use32

	global hashMap_init			;HashMap* hashMap_init()
	global hashMap_destroy		;void hashMap_destroy(HashMap* hm)
	
	global hashMap_add			;void hashMap_add(HashMap* hm, void* pkey, void* pvalue, int keySizeInBytes, int valueSizeInBytes)
	global hashMap_remove		;void hashMap_remove(HashMap* hm, void* pkey, int keySizeInBytes)
	global hashMap_get			;void* hashMap_get(HashMap* hm, void* pkey, int keySizeInBytes)	//returns the pointer to the value with that key, otherwise NULL
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcmp
	extern my_memcpy
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	extern vector_remove_at
	extern vector_search
	
hashMap_init:
	push ebp
	push esi
	mov ebp, esp
	
	sub esp, 4			;hashmap		;4
	
	;alloc hashmap
	push 4096
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;init buckets
	xor esi, esi
	hashMap_init_bucket_loop_start:
		mov eax, esi
		shl eax, 4
		add eax, dword[ebp-4]
		
		push 16
		push eax
		call vector_init
		add esp, 8
	
		inc esi
		cmp esi, 256
		jl hashMap_init_bucket_loop_start
		
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop esi
	pop ebp
	ret
	
	
hashMap_destroy:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;destroy the elements and buckets
	mov esi, 256				;index in esi
	mov edi, dword[ebp+20]		;current bucket in edi
	hashMap_destroy_bucket_loop_start:
		;destroy elements
		mov ebx, dword[edi]			;index in ebx
		cmp ebx, 0
		jle hashMap_destroy_element_loop_end
		hashMap_destroy_element_loop_start:
			mov eax, ebx
			shl eax, 4
			add eax, dword[edi+12]		;current element in eax
			push eax
			call hashMap_destroyElement
			add esp, 4
			
			dec ebx
			test ebx, ebx
			jnz hashMap_destroy_element_loop_start
			
		hashMap_destroy_element_loop_end:
		
		;destroy bucket
		push edi
		call vector_destroy
		add esp, 4
		
		;continue
		add edi, 16
		dec esi
		test esi, esi
		jnz hashMap_destroy_bucket_loop_start
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
hashMap_add:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;hash value			;4
	sub esp, 16			;element buffer		;20
	
	;calculate hash value
	push dword[ebp+20]
	push dword[ebp+12]
	call hashMap_calculateHashValue
	mov dword[ebp-4], eax
	add esp, 8
	
	;check if the key is already registered
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	shl ecx, 4
	add eax, ecx
	
	push dword[ebp+12]
	push hashMap_isMatching
	push eax
	call vector_search
	add esp, 12
	
	cmp eax, -1
	jne hashMap_add_valid_key
		push error_add_invalid_key
		call my_printf
		add esp, 4
		jmp hashMap_add_end
		
	hashMap_add_valid_key:
	
	
	;create the element
	push dword[ebp+24]
	push dword[ebp+20]
	push dword[ebp+16]
	push dword[ebp+12]
	lea eax, [ebp-20]
	push eax
	call hashMap_createElement
	mov dword[ebp-4], eax			;save hash value
	add esp, 20
	
	
	;add the element to the corresponding bucket
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-4]
	shl ecx, 4
	add eax, ecx
	
	push dword[ebp-8]
	push dword[ebp-12]
	push dword[ebp-16]
	push dword[ebp-20]
	push eax
	call vector_push_back
	add esp, 20
	
	
	hashMap_add_end:
	mov esp, ebp
	pop ebp
	ret
	
	
hashMap_remove:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;hash value		;4
	sub esp, 4			;chosen bucket	;8
	
	;calculate hash value
	push dword[ebp+28]
	push dword[ebp+24]
	call hashMap_calculateHashValue
	mov dword[ebp-4], eax
	add esp, 8
	
	;get the bucket
	mov eax, dword[ebp-4]
	shl eax, 4
	add eax, dword[ebp+20]
	mov dword[ebp-8], eax
	
	;remove item
	mov eax, dword[ebp-8]
	mov esi, dword[eax]			;index in esi
	mov edi, dword[eax+12]		;current element in edi
	xor ebx, ebx				;current bucket index in ebx (helper)
	cmp esi, 0
	jle hashMap_remove_loop_end
	hashMap_remove_loop_start:
		;check if the key is the same
		push dword[ebp+28]
		push dword[ebp+24]
		push dword[edi]
		call my_memcmp
		add esp, 12
		test eax, eax
		jnz hashMap_remove_loop_continue
			;remove the element and yeet the loop
			push edi
			call hashMap_destroyElement
			add esp, 4
			
			push ebx
			push dword[ebp-8]
			call vector_remove_at
			add esp, 8
			
			jmp hashMap_remove_loop_end
	
		hashMap_remove_loop_continue:
		add edi, 16
		inc ebx
		
		dec esi
		test esi, esi
		jnz hashMap_remove_loop_end
		
	hashMap_remove_loop_end:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
hashMap_get:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;hash value		;4
	sub esp, 4			;chosen bucket	;8
	sub esp, 4			;value found	;12
	
	mov dword[ebp-12], 0
	
	;calculate hash value
	push dword[ebp+28]
	push dword[ebp+24]
	call hashMap_calculateHashValue
	mov dword[ebp-4], eax
	add esp, 8
	
	;get the bucket
	mov eax, dword[ebp-4]
	shl eax, 4
	add eax, dword[ebp+20]
	mov dword[ebp-8], eax
	
	;search for item
	mov eax, dword[ebp-8]
	mov esi, dword[eax]			;index in esi
	mov edi, dword[eax+12]		;current element in edi
	xor ebx, ebx				;current bucket index in ebx (helper)
	cmp esi, 0
	jle hashMap_get_loop_end
	hashMap_get_loop_start:
		;check if the key is the same
		push dword[ebp+28]
		push dword[ebp+24]
		push dword[edi]
		call my_memcmp
		add esp, 12
		test eax, eax
		jnz hashMap_get_loop_continue
			;save the value
			mov eax, dword[edi+4]
			mov dword[ebp-12], eax
			
			jmp hashMap_get_loop_end
	
		hashMap_get_loop_continue:
		add edi, 16
		inc ebx
		
		dec esi
		test esi, esi
		jnz hashMap_get_loop_end
		
	hashMap_get_loop_end:
	
	;set return value
	mov eax, dword[ebp-12]
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
;internal functions

;int hashMap_calculateHashValue(void* pkey, int keySizeInBytes)
;returns a number between 0 and 255
hashMap_calculateHashValue:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;hash value		;4
	
	mov dword[ebp-4], eax
	
	mov eax, dword[ebp+8]		;current byte in eax
	mov ecx, dword[ebp+12]		;index in ecx
	xor edx, edx				;hash value in edx
	cmp ecx, 0
	jle hashMap_calculateHashValue_loop_end
	hashMap_calculateHashValue_loop_start:
		add edx, dword[eax]
		
		inc eax
		dec ecx
		test ecx, ecx
		jnz hashMap_calculateHashValue_loop_start
	hashMap_calculateHashValue_loop_end:
	
	and eax, 0x000000ff
	mov dword[ebp-4], edx
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	

;int hashMap_createElement(
;	hashMapElement* buffer,
;	void* pkey,
;	void* pvalue,
;	int keySizeInBytes,
;	int valueSizeInBytes
;)
;returns the hash value
hashMap_createElement:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;hash value		;4
	sub esp, 4			;key pointer	;8
	sub esp, 4			;value pointer	;12
	
	;calculate hash value
	push dword[ebp+20]
	push dword[ebp+12]
	call hashMap_calculateHashValue
	mov dword[ebp-4], eax
	add esp, 8
	
	;alloc things
	push dword[ebp+20]
	call my_malloc
	mov dword[ebp-8], eax
	push dword[ebp+12]
	push eax
	call my_memcpy
	add esp, 12
	
	push dword[ebp+24]
	call my_malloc
	mov dword[ebp-12], eax
	push dword[ebp+16]
	push eax
	call my_memcpy
	add esp, 12
	
	
	;copy data into the buffer
	mov eax, dword[ebp+8]
	
	mov ecx, dword[ebp-8]
	mov dword[eax], ecx
	mov ecx, dword[ebp-12]
	mov dword[eax+4], ecx
	mov ecx, dword[ebp+20]
	mov dword[eax+8], ecx
	mov ecx, dword[ebp+24]
	mov dword[eax+12], ecx
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	

;void hashMap_createElement(HashMapElement* pelement)
hashMap_destroyElement:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax+4]
	push dword[eax]
	call my_free
	add esp, 4
	call my_free
	add esp, 4
	
	mov esp, ebp
	pop ebp
	ret
	
;int hashMap_isMatching(HashMapElement* element, void* pkey)
;returns 0 if the keys are same, non-zero otherwise
hashMap_isMatching:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax+8]
	push dword[eax]
	push dword[ebp+12]
	call my_memcmp
	
	;return value already on the stack
	
	mov esp, ebp
	pop ebp
	ret