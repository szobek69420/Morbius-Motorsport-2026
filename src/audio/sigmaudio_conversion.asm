[BITS 32]

;struct Sound{
;	int dataSizeInBytes;			;0
;	char* data;						;4
;	WAVEFORMATEX* formatDescriptor;	;8
;}	12 bytes overall

;struct WAVEFORMATEX{
;	uint16 wFormatTag;			;0
;	uint16 nChannels;			;2
;	uint32 nSamplesPerSec;		;4
;	uint32 nAvgBytesPerSec;		;8
;	uint16 nBlockAlign;			;12
;	uint16 wBitsPerSample;		;14
;	uint16 cbSize;				;16
;}	18 bytes overall

section .text use32

;new and original bitsPerSample should be in {8,16,24,32}
;void sigmaudio_changeBitsPerSample(Sound* sound, int bitsPerSample)
sigmaudio_changeBitsPerSample:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;new data		4
	sub esp, 4			;waveformatex	8
	sub esp, 4			;shift count	12
	sub esp, 4			;shift left		16
	sub esp, 4			;sample count	20	(numChannels is also included in the calculation)
	sub esp, 4			;source bitsPerSampel	24
	
	;obtain waveformatex and source bitsPerSample
	mov eax, dword[ebp+20]
	mov eax, dword[eax+8]
	mov dword[ebp-8], eax
	
	xor ecx, ecx
	mov cx, word[eax+14]
	mov dword[ebp-24], ecx
	
	;check if the old and new bitsPerSample are the same
	mov ecx, dword[ebp-24]
	cmp ecx, dword[ebp+24]
	je sigmaudio_changeBitsPerSample_end
	
	;check if the old bitsPerSample is valid
	mov ecx, dword[ebp-24]
	cmp ecx, 8
	je sigmaudio_changeBitsPerSample_old_value_valid
	cmp ecx, 16
	je sigmaudio_changeBitsPerSample_old_value_valid
	cmp ecx, 24
	je sigmaudio_changeBitsPerSample_old_value_valid
	cmp ecx, 32
	je sigmaudio_changeBitsPerSample_old_value_valid
		push ecx
		push sigmaudio_changeBitsPerSample_error_old_value_invalid
		call my_printf
		jmp sigmaudio_changeBitsPerSample_end
		sigmaudio_changeBitsPerSample_error_old_value_invalid db "sigmaudio_changeBitsPerSample: Source bits per sample cannot be %d",10,0
	sigmaudio_changeBitsPerSample_old_value_valid:
	
	;check if the new bitsPerSample is valid
	mov ecx, dword[ebp+24]
	cmp ecx, 8
	je sigmaudio_changeBitsPerSample_new_value_valid
	cmp ecx, 16
	je sigmaudio_changeBitsPerSample_new_value_valid
	cmp ecx, 24
	je sigmaudio_changeBitsPerSample_new_value_valid
	cmp ecx, 32
	je sigmaudio_changeBitsPerSample_new_value_valid
		push ecx
		push sigmaudio_changeBitsPerSample_error_new_value_invalid
		call my_printf
		jmp sigmaudio_changeBitsPerSample_end
		sigmaudio_changeBitsPerSample_error_new_value_invalid db "sigmaudio_changeBitsPerSample: Target bits per sample cannot be %d",10,0
	sigmaudio_changeBitsPerSample_new_value_valid:
	
	;calculate shift count
	mov dword[ebp-16], 0
	
	mov eax, dword[ebp-24]
	sub eax, dword[ebp+24]
	jg sigmaudio_changeBitsPerSample_shift_right
		mov dword[ebp-16], 69
		neg eax
	sigmaudio_changeBitsPerSample_shift_right:
	mov dword[ebp-12], eax
	
	;calculate sample count
	mov eax, dword[ebp+20]
	mov eax, dword[eax]	
	xor edx, edx
	mov ecx, dword[ebp-24]
	shr ecx, 3				;bits -> bytes
	idiv ecx
	mov dword[ebp-20], eax
	
	;alloc new data
	mov eax, dword[ebp-20]
	mov ecx, dword[ebp+24]
	shr ecx, 3
	imul eax, ecx
	push eax
	call my_malloc
	mov dword[ebp-4], eax
	
	;convert the data
	mov esi, dword[ebp+20]
	mov esi, dword[esi+4]		;source data in esi
	mov edi, dword[ebp-4]		;target data in edi
	mov ebx, dword[ebp-20]		;index in ebx
	cmp ebx, 0
	jle sigmaudio_changeBitsPerSample_loop_end
	sigmaudio_changeBitsPerSample_loop_start:
		;get the source sample and convert it to a 32-bit number in ecx
		;also step the pointer in esi
		cmp dword[ebp-24], 8
		je sigmaudio_changeBitsPerSample_loop_get_source_8
		cmp dword[ebp-24], 16
		je sigmaudio_changeBitsPerSample_loop_get_source_16
		cmp dword[ebp-24], 24
		je sigmaudio_changeBitsPerSample_loop_get_source_24
		cmp dword[ebp-24], 32
		je sigmaudio_changeBitsPerSample_loop_get_source_32
		sigmaudio_changeBitsPerSample_loop_get_source_8:
			xor ecx, ecx
			mov cl, byte[esi]
			shl ecx, 24
			inc esi
			jmp sigmaudio_changeBitsPerSample_loop_get_source_done
			
		sigmaudio_changeBitsPerSample_loop_get_source_16:
			xor ecx, ecx
			mov cx, word[esi]
			shl ecx, 16
			add esi, 2
			jmp sigmaudio_changeBitsPerSample_loop_get_source_done
			
		sigmaudio_changeBitsPerSample_loop_get_source_24:
			xor ecx, ecx
			mov cx, word[esi+1]
			shl ecx, 8
			mov cl, byte[esi]
			shl ecx, 8
			add esi, 3
			jmp sigmaudio_changeBitsPerSample_loop_get_source_done
			
		sigmaudio_changeBitsPerSample_loop_get_source_32:
			mov ecx, dword[esi]
			add esi, 4
			jmp sigmaudio_changeBitsPerSample_loop_get_source_done
		sigmaudio_changeBitsPerSample_loop_get_source_done:
		
		;convert the value in ecx and step edi
		cmp dword[ebp+24], 8
		je sigmaudio_changeBitsPerSample_loop_set_target_8
		cmp dword[ebp+24], 16
		je sigmaudio_changeBitsPerSample_loop_set_target_16
		cmp dword[ebp+24], 24
		je sigmaudio_changeBitsPerSample_loop_set_target_24
		cmp dword[ebp+24], 32
		je sigmaudio_changeBitsPerSample_loop_set_target_32
		sigmaudio_changeBitsPerSample_loop_set_target_8:
			shr ecx, 24
			mov byte[edi], cl
			inc edi
			jmp sigmaudio_changeBitsPerSample_loop_set_target_done
		sigmaudio_changeBitsPerSample_loop_set_target_16:
			shr ecx, 16
			mov word[edi], cx
			add edi, 2
			jmp sigmaudio_changeBitsPerSample_loop_set_target_done
		sigmaudio_changeBitsPerSample_loop_set_target_24:
			mov byte[edi], cl
			shr ecx, 8
			mov word[edi+1], cx
			add edi, 3
			jmp sigmaudio_changeBitsPerSample_loop_set_target_done
		sigmaudio_changeBitsPerSample_loop_set_target_32:
			mov dword[edi], ecx
			add edi, 4
			jmp sigmaudio_changeBitsPerSample_loop_set_target_done
		sigmaudio_changeBitsPerSample_loop_set_target_done:
		dec ebx
		jnz sigmaudio_changeBitsPerSample_loop_start
	sigmaudio_changeBitsPerSample_loop_end:
	
	sigmaudio_changeBitsPerSample_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
;new and original numChannels should be in {1,2}
;void sigmaudio_changeNumChannels(Sound* sound, int newNumChannels)
sigmaudio_changeNumChannels:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;waveformatex			4
	sub esp, 4			;new data				8
	sub esp, 4			;bytes per sample		12 (per channel)
	sub esp, 4			;sample count			16
	sub esp, 4			;new date size in bytes	20
	
	;get waveformatex and calculate bytes per sample and sample count
	mov eax, dword[ebp+20]
	mov eax, dword[eax+8]
	mov dword[ebp-4], eax			;waveformatex
	
	xor ecx, ecx
	mov cx, word[eax+14]
	shr ecx, 3
	mov dword[ebp-12], ecx			;bytes per sample (per channel)
	
	mov eax, dword[ebp+20]
	mov eax, dword[eax]
	xor edx, edx
	mov esi, dword[ebp-4]
	xor ecx, ecx
	mov cx, word[esi+2]
	imul ecx, dword[ebp-12]		;numChannels*bytesPerSamplePerChannel
	idiv ecx
	mov dword[ebp-16], eax			;sample count = lenData/(numChannels/bytesPerSamplePerChannel)
	
	;check if the source and target channel counts are the same
	mov eax, dword[ebp-4]
	xor ecx, ecx
	mov cx, word[eax+2]
	cmp ecx, dword[ebp+24]
	je sigmaudio_changeNumChannels_end
	
	;check if the source and target channel counts are kosher
	cmp dword[ebp+24], 1
	jl sigmaudio_changeNumChannels_invalid_count_new
	cmp dword[ebp+24], 2
	jg sigmaudio_changeNumChannels_invalid_count_new
	mov eax, dword[ebp-4]
	cmp word[eax+2], 1
	jl sigmaudio_changeNumChannels_invalid_count_old
	cmp word[eax+2], 2
	jg sigmaudio_changeNumChannels_invalid_count_old
	
	cmp dword[ebp+24], 2
	je sigmaudio_changeNumChannels_1to2
		;stereo -> mono
		
		;alloc the space for the new audio data
		mov eax, dword[ebp+20]
		mov eax, dword[eax]
		shr eax, 1
		mov dword[ebp-20], eax		;new data size
		push eax
		call my_malloc
		mov dword[ebp-8], eax
		
		;create the new data
		mov esi, dword[ebp+20]
		mov esi, dword[esi+4]		;original data in esi
		mov edi, dword[ebp-8]		;new data in edi
		mov ebx, dword[ebp-16]		;index in ebx
		mov eax, dword[ebp-12]		;helper in eax
		cmp ebx, 0
		jle sigmaudio_changeNumChannels_2to1_outer_loop_end
		sigmaudio_changeNumChannels_2to1_outer_loop_start:
			cld
			mov ecx, eax			;index in ecx
			sigmaudio_changeNumChannels_2to1_inner_loop_start:
				movsb
				dec ecx
				jnz sigmaudio_changeNumChannels_2to1_inner_loop_start
			add esi, eax
			dec ebx
			jnz sigmaudio_changeNumChannels_2to1_outer_loop_start
		sigmaudio_changeNumChannels_2to1_outer_loop_end:
		
		;delete the old data
		mov eax, dword[ebp+20]
		push dword[eax+4]
		call my_free
		
		;update the values in the sound
		mov eax, dword[ebp+20]
		mov ecx, dword[ebp-8]
		mov dword[eax+4], ecx
		mov edx, dword[ebp-20]
		mov dword[eax], edx
		
		mov eax, dword[ebp-4]
		mov word[eax+2], 1
		
		jmp sigmaudio_changeNumChannels_end
		
	sigmaudio_changeNumChannels_1to2:
		;mono -> stereo
		
		;alloc the space for the new audio data
		mov eax, dword[ebp+20]
		mov eax, dword[eax]
		shl eax, 1
		mov dword[ebp-20], eax		;new data size
		push eax
		call my_malloc
		mov dword[ebp-8], eax
		
		;create the new data
		mov esi, dword[ebp+20]
		mov esi, dword[esi+4]		;original data in esi
		mov edi, dword[ebp-8]		;new data in edi
		mov ebx, dword[ebp-16]		;index in ebx
		mov eax, dword[ebp-12]		;helper in eax
		cmp ebx, 0
		jle sigmaudio_changeNumChannels_1to2_outer_loop_end
		sigmaudio_changeNumChannels_1to2_outer_loop_start:
			;copy first channel
			cld
			mov ecx, eax			;index in ecx
			sigmaudio_changeNumChannels_1to2_inner_loop1_start:
				movsb
				dec ecx
				jnz sigmaudio_changeNumChannels_1to2_inner_loop1_start
				
			;copy second channel
			sub esi, eax
			cld
			mov ecx, eax			;index in ecx
			sigmaudio_changeNumChannels_1to2_inner_loop2_start:
				movsb
				dec ecx
				jnz sigmaudio_changeNumChannels_1to2_inner_loop2_start

			dec ebx
			jnz sigmaudio_changeNumChannels_1to2_outer_loop_start
		sigmaudio_changeNumChannels_1to2_outer_loop_end:
		
		;delete the old data
		mov eax, dword[ebp+20]
		push dword[eax+4]
		call my_free
		
		;update the values in the sound
		mov eax, dword[ebp+20]
		mov ecx, dword[ebp-8]
		mov dword[eax+4], ecx		;data
		mov edx, dword[ebp-20]
		mov dword[eax], edx			;data length
		
		mov eax, dword[ebp-4]
		mov word[eax+2], 2			;numChannels
		
		jmp sigmaudio_changeNumChannels_end
	
	jmp sigmaudio_changeNumChannels_end
	
	sigmaudio_changeNumChannels_invalid_count_old:
		push dword[ebp+24]
		push sigmaudio_changeNumChannels_error_invalid_count_old
		call my_printf
		jmp sigmaudio_changeNumChannels_end
		
		sigmaudio_changeNumChannels_error_invalid_count_old db "sigmaudio_changeNumChannels: Source channel count cannot be %d",10,0
		
	sigmaudio_changeNumChannels_invalid_count_new:
		push dword[ebp+24]
		push sigmaudio_changeNumChannels_error_invalid_count_new
		call my_printf
		jmp sigmaudio_changeNumChannels_end
		
		sigmaudio_changeNumChannels_error_invalid_count_new db "sigmaudio_changeNumChannels: Target channel count cannot be %d",10,0
	
	sigmaudio_changeNumChannels_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret