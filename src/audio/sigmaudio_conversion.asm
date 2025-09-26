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
		jle sigmaudio_changeNumChannels_1to2_outer_loop_end
		sigmaudio_changeNumChannels_1to2_outer_loop_start:
			cld
			mov ecx, eax			;index in ecx
			sigmaudio_changeNumChannels_1to2_inner_loop_start:
				movsb
				dec ecx
				jnz sigmaudio_changeNumChannels_1to2_inner_loop_start
			add esi, eax
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
		mov dword[eax+4], ecx
		mov edx, dword[ebp-20]
		mov dword[eax], edx
		
		mov eax, dword[ebp-4]
		mov word[eax+2], 1
		
		jmp sigmaudio_changeNumChannels_end
		
	sigmaudio_changeNumChannels_1to2:
		;mono -> stereo
	
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