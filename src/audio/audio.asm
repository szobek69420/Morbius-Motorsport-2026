[BITS 32]

;struct WaveHeader{
;	char chunkId[4];			;0	//should be "RIFF"
;	uint32 chunkSize;			;4	//file size - 8
;	char fileType[4];			;8	//should be "WAVE"
;	char formatChunkMarker[4];	;12	//should be "fmt "
;	uint32 formatChunkSize;		;16
;	uint16 audioFormat;			;20	//1 is PCM
;	uint16 numberOfChannels;	;22
;	uint32 sampleRate;			;24
;	uint32 byteRate;			;28
;	uint16 bytesPerSampleFrame;	;32 //(blockAlign)
;	uint16 bitsPerSample;		;34
;}	36 bytes overall

;struct WAVEFORMATEX{
;	uint16  wFormatTag;			;0
;	uint16  nChannels;			;2
;	uint32 nSamplesPerSec;		;4
;	uint32 nAvgBytesPerSec;		;8
;	uint16  nBlockAlign;		;12
;	uint16  wBitsPerSample;		;14
;	uint16  cbSize;				;16
;}	18 bytes overall

section .rodata use32
	file_open_mode db "r",0
	
	based_chunk_id db "RIFF"
	based_file_type db "WAVE"
	based_format_marker db "fmt "

	error_read_failure db "audio_readWaveHeader: couldn't read the file %s",10,0
	error_invalid_chunk_id db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid chunk ID",10,0
	error_invalid_file_type db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid file type",10,0
	error_invalid_format_chunk_marker db "audio_readWaveHeader: couldn't read wave header of %s due to missing format chunk marker",10,0

	print_seven_ints_nl db "%d %d %d %d %d %d %d",10,0
	
	test_text db "hog rider",10,0

section .text use32
	
	global audio_playSound
	global audio_testGetWAVEFORMATEX
	
	extern my_printf
	
	extern my_fopen
	extern my_fclose
	extern my_fread
	
	extern my_memcmp
	extern my_memcpy
	
;void audio_testGetWAVEFORMATEX(const char* filePath)
audio_testGetWAVEFORMATEX:
	push ebp
	mov ebp, esp
	
	sub esp, 18			;WAVEFORMATEX		18
	
	lea eax, [ebp-18]
	push eax
	push dword[ebp+8]
	call audio_getWAVEFORMATEX
	add esp, 4
	test eax, eax
	jnz audio_testGetWAVEFORMATEX_end
	
	;print it
	xor ecx, ecx
	mov cx, word[ebp-18]
	push ecx
	xor ecx, ecx
	mov cx, word[ebp-16]
	push ecx
	push dword[ebp-14]
	push dword[ebp-10]
	xor ecx, ecx
	mov cx, word[ebp-6]
	push ecx
	xor ecx, ecx
	mov cx, word[ebp-4]
	push ecx
	xor ecx, ecx
	mov cx, word[ebp-2]
	push ecx
	push print_seven_ints_nl
	call my_printf
	add esp, 32
	
	audio_testGetWAVEFORMATEX_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;retrieves the WAVEFORMATEX struct corresponding to the file
;returns zero if there were no problems
;int audio_getWAVEFORMATEX(const char* filePath, WAVEFORMATEX* buffer)
audio_getWAVEFORMATEX:
	push ebp
	mov ebp, esp
	
	sub esp, 36			;wave header		;36
	sub esp, 4			;return value		;4
	
	mov dword[ebp-40], 0
	
	;read the header file
	lea eax, [ebp-36]
	push eax
	push dword[ebp+8]
	call audio_readWaveHeader
	add esp, 8
	
	;was it successful?
	test eax, eax
	jz audio_getWAVEFORMATEX_read_gg
		mov dword[ebp-40], 69
		jmp audio_getWAVEFORMATEX_end
		
	audio_getWAVEFORMATEX_read_gg:
	
	;set the values
	mov eax, dword[ebp+12]
	
	;wFormatTag
	mov cx, word[ebp-16]
	mov word[eax], cx
	
	;nChannels
	mov cx, word[ebp-14]
	mov word[eax+2], cx
	
	;nSamplesPerSec
	mov ecx, dword[ebp-12]
	mov dword[eax+4], ecx
	
	;nAvgBytesPerSec
	mov ecx, dword[ebp-8]
	mov dword[eax+8], ecx
	
	;nBlockAlign
	mov cx, word[ebp-4]
	mov word[eax+12], cx
	
	;wBitsPerSample
	mov cx, word[ebp-2]
	mov word[eax+14], cx
	
	;cbSize
	mov word[eax+16], 0
	
	audio_getWAVEFORMATEX_end:
	mov eax, dword[ebp-40]		;set return value
	
	mov esp, ebp
	pop ebp
	ret

;returns zero if there were no problems
;int audio_readWaveHeader(const char* filePath, WaveHeader* headerBuffer)
audio_readWaveHeader:
	push ebp
	mov ebp, esp
	
	sub esp, 36			;temporary header buffer	;36
	sub esp, 4			;file						;40
	sub esp, 4			;return value				;44
	
	mov dword[ebp-44], 0
	
	;open file
	push file_open_mode
	push dword[ebp+8]
	call my_fopen
	mov dword[ebp-40], eax
	test eax, eax
	jz audio_readWaveHeader_error_read_failure
	
	;read data
	push dword[ebp-40]
	push 1
	push 36
	lea eax, [ebp-36]
	push eax
	call my_fread
	add esp, 16
	
	;was the read successful?
	cmp eax, 1
	jne audio_readWaveHeader_error_read_failure
	
	
	;close the file
	push dword[ebp-40]
	call my_fclose
	add esp, 4
	test eax, eax
	;jz audio_readWaveHeader_error_read_failure
	
	
	;is the chunk id kosher?
	lea eax, [ebp-36]
	push 4
	push eax
	push based_chunk_id
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz audio_readWaveHeader_invalid_chunk_id
	
	;is the file type halal?
	lea eax, [ebp-28]
	push 4
	push eax
	push based_file_type
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz audio_readWaveHeader_invalid_file_type
	
	;is the format marker shuddha?
	lea eax, [ebp-24]
	push 4
	push eax
	push based_format_marker
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz audio_readWaveHeader_invalid_format_marker
	
	;copy the header data to the actual buffer
	push 36
	lea eax, [ebp-36]
	push eax
	push dword[ebp+12]
	call my_memcpy
	add esp, 12
	
	jmp audio_readWaveHeader_end
	
	audio_readWaveHeader_error_read_failure:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_read_failure
		call my_printf
		add esp, 8
		jmp audio_readWaveHeader_end
		
		
	audio_readWaveHeader_invalid_chunk_id:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_chunk_id
		call my_printf
		add esp, 8
		jmp audio_readWaveHeader_end
		
		
	audio_readWaveHeader_invalid_file_type:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_file_type
		call my_printf
		add esp, 8
		jmp audio_readWaveHeader_end
		
		
	audio_readWaveHeader_invalid_format_marker:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_format_chunk_marker
		call my_printf
		add esp, 8
		jmp audio_readWaveHeader_end
	
	audio_readWaveHeader_end:
	mov eax, dword[ebp-44]		;set return value
	
	mov esp, ebp
	pop ebp
	ret