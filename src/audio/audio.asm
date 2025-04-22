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
;	uint16 wFormatTag;			;0
;	uint16 nChannels;			;2
;	uint32 nSamplesPerSec;		;4
;	uint32 nAvgBytesPerSec;		;8
;	uint16 nBlockAlign;		;12
;	uint16 wBitsPerSample;		;14
;	uint16 cbSize;				;16
;}	18 bytes overall

;struct WAVEHDR {
;	char* lpData;				;0
;	int dwBufferLength;			;4
;	int dwBytesRecorded;		;8
;	int* dwUser;				;12
;	int dwFlags;				;16
;	int dwLoops;				;20
;	wavehdr_tag* lpNext;		;24
;	int* reserved;				;28
;} 	32 bytes overall; only lpData, dwBufferLength and dwFlags are important for us

;struct Sound{
;	HANDLE handle;					;0
;	int dataSizeInBytes;			;4
;	char* data;						;8
;	WAVEFORMATEX* formatDescriptor;	;12
;	uint loopsLeft;					;16	//0xffffffff means infinite playback
;	WAVEHDR* currentlyPlayingBlock;	;20
;}	24 bytes overall

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	WAVE_MAPPER dd 0xffffffff
	MMSYSERR_NOERROR dd 0
	CALLBACK_FUNCTION dd 0x00030000
	WAVE_MAPPED_DEFAULT_COMMUNICATION_DEVICE dd 0x0010

	file_open_mode db "r",0
	
	based_chunk_id db "RIFF"
	based_file_type db "WAVE"
	based_format_marker db "fmt "
	
	data_chunk_id db "data"

	error_read_failure db "audio_readWaveHeader: couldn't read the file %s",10,0
	error_invalid_chunk_id db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid chunk ID",10,0
	error_invalid_file_type db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid file type",10,0
	error_invalid_format_chunk_marker db "audio_readWaveHeader: couldn't read wave header of %s due to missing format chunk marker",10,0

	print_seven_ints_nl db "%d %d %d %d %d %d %d",10,0
	
	test_text db "hog rider",10,0

section .text use32
	
	;loads the given sound
	;returns NULL if there was a problem
	;Sound* audio_loadSound(const char* filePath)
	global audio_loadSound
	
	;Sound* audio_playSound(Sound* sound, unsigned int loopCount)
	global audio_playSound
	
	dll_import winmm.dll, waveOutOpen				;creates an audio device
	dll_import winmm.dll, waveOutClose				;destroys an audio device
	dll_import winmm.dll, waveOutWrite				;writes (plays) a playback block into an audio device
	dll_import winmm.dll, waveOutPrepareHeader		;prepares a playback block to be played
	dll_import winmm.dll, waveOutUnprepareHeader	;undoes the PrepareHeader func
	

	extern my_printf
	
	extern my_fopen
	extern my_fclose
	extern my_fread
	extern my_fjmp
	
	extern my_malloc
	extern my_free
	extern my_memcmp
	extern my_memcpy
	
	
audio_loadSound:
	push ebp
	mov ebp, esp
	
	sub esp, 4	;Sound*					4
	sub esp, 4	;HANDLE					8
	sub esp, 4	;WAVEFORMATEX*			12
	sub esp, 4	;data (char*)			16
	sub esp, 4	;header length			20
	sub esp, 4	;data size				24
	sub esp, 36	;header					60
	sub esp, 4	;temp file				64
	
	mov dword[ebp-4], 0
	
	;read the header
	lea eax, [ebp-24]
	push eax
	lea eax, [ebp-20]
	push eax
	lea eax, [ebp-60]
	push eax
	push dword[ebp+8]
	call audio_readWaveHeader
	add esp, 16
	
	;check if the read was successful
	test eax, eax
	jnz audio_loadSound_end
	
	;alloc space for the data
	push dword[ebp-24]
	call my_malloc
	mov dword[ebp-16], eax
	add esp, 4
	
	;read the audio data from the file
	push file_open_mode
	push dword[ebp+8]
	call my_fopen
	mov dword[ebp-64], eax
	add esp, 8
	
	push 0		;not from current
	push dword[ebp-20]
	push dword[ebp-64]
	call my_fjmp
	add esp, 12
	
	push dword[ebp-64]
	push 1
	push dword[ebp-24]
	push dword[ebp-16]
	call my_fread
	add esp, 16
	
	push dword[ebp-64]
	call my_fclose
	add esp, 4
	
	;get the WAVEFORMATEX
	push 18
	call my_malloc
	mov dword[ebp-12], eax
	add esp, 4
	
	lea eax, [ebp-60]
	push eax
	push dword[ebp-12]
	call audio_getWAVEFORMATEX
	add esp, 8
	
	;alloc the Sound struct (necessary for waveOutOpen)
	push 24
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;create device
	mov eax, dword[CALLBACK_FUNCTION]
	or eax, dword[WAVE_MAPPED_DEFAULT_COMMUNICATION_DEVICE]
	push eax			;the dwCallback is a function pointer and the device should be the default communication device
	push dword[ebp-4]	;the sound should be passed as a parameter for the callback funciton
	push audio_callback	;the callback function
	push dword[ebp-12]	;WAVEFORMATEX info
	push dword[WAVE_MAPPER]	;automatically map to device
	lea eax, [ebp-8]
	push eax			;HANDLE buffer
	call [waveOutOpen]
	
	;init the Sound struct
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp-8]
	mov dword[eax], ecx		;HANDLE
	mov ecx, dword[ebp-24]
	mov dword[eax+4], ecx	;data size
	mov ecx, dword[ebp-16]
	mov dword[eax+8], ecx	;data
	mov ecx, dword[ebp-12]
	mov dword[eax+12], ecx	;WAVEFORMATEX*
	mov dword[eax+16], 0	;loops left
	mov dword[eax+20], 0	;current block
	
	audio_loadSound_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
;void audio_callback(HANDLE hwo, uint32 uMsg, Sound* sound, int* dwParam1, int* dwParam2 );
audio_callback:
	ret

;retrieves the WAVEFORMATEX struct corresponding to the file
;returns zero if there were no problems
;int audio_getWAVEFORMATEX(WAVEFORMATEX* buffer, WaveHeader* header)
audio_getWAVEFORMATEX:
	push ebp
	mov ebp, esp
	
	sub esp, 36			;wave header		;36
	sub esp, 4			;return value		;40
	
	mov dword[ebp-40], 0
	
	
	;set the values
	mov eax, dword[ebp+8]		;buffer in eax
	mov edx, dword[ebp+12]		;header in edx
	
	;wFormatTag
	mov cx, word[edx+20]
	mov word[eax], cx
	
	;nChannels
	mov cx, word[edx+22]
	mov word[eax+2], cx
	
	;nSamplesPerSec
	mov ecx, dword[edx+24]
	mov dword[eax+4], ecx
	
	;nAvgBytesPerSec
	mov ecx, dword[edx+28]
	mov dword[eax+8], ecx
	
	;nBlockAlign
	mov cx, word[edx+32]
	mov word[eax+12], cx
	
	;wBitsPerSample
	mov cx, word[edx+34]
	mov word[eax+14], cx
	
	;cbSize
	mov word[eax+16], 0
	

	mov eax, dword[ebp-40]		;set return value
	
	mov esp, ebp
	pop ebp
	ret

;dataStart: how long is the header in bytes
;dataLength: how much raw audio data is there in bytes
;returns zero if there were no problems
;int audio_readWaveHeader(const char* filePath, WaveHeader* headerBuffer, int* dataStart, int* dataLength)
audio_readWaveHeader:
	push ebp
	mov ebp, esp
	
	sub esp, 36			;temporary header buffer	;36
	sub esp, 4			;file						;40
	sub esp, 4			;return value				;44
	sub esp, 4			;dataStart					;48
	sub esp, 4			;dataLength					;52
	sub esp, 8			;chunk parse helper			;60
	
	mov dword[ebp-48], 0
	mov dword[ebp-52], 0
	
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
	
	push 0		;not from current
	push 12		;the start of the first chunk
	push dword[ebp-40]
	call my_fjmp
	add esp, 12
	
	audio_readWaveHeader_parseChunks_loop_start:
		;read in the chunk descriptor (chunk id, chunk size)
		push dword[ebp-40]
		push 1
		push 8
		lea eax, [ebp-60]
		push eax
		call my_fread
		add esp, 16
		
		add dword[ebp-48], 8		;increment header by the length of the chunk descriptor
		
		;check if it is the data chunk
		;if so, it contains the data length an is the last chunk
		push 4
		push data_chunk_id
		lea eax, [ebp-60]
		push eax
		call my_memcmp
		add esp, 12
		test eax, eax
		jnz audio_readWaveHeader_parseChunks_loop_continue
			;set the data size
			mov eax, dword[ebp-56]
			mov dword[ebp-52], eax
			jmp audio_readWaveHeader_parseChunks_loop_end
		
		audio_readWaveHeader_parseChunks_loop_continue:
		;add chunk size to the header size
		mov eax, dword[ebp-56]
		add dword[ebp-48], eax
		
		;skip chunk
		push 69				;from current
		push dword[ebp-56]	;chunk size
		push dword[ebp-40]	;file
		call my_fjmp
		add esp, 12
		jmp audio_readWaveHeader_parseChunks_loop_start
		
	audio_readWaveHeader_parseChunks_loop_end:
	
	
	
	;close the file
	push dword[ebp-40]
	call my_fclose
	add esp, 4
	test eax, eax
	jz audio_readWaveHeader_error_read_failure
	
	
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
	
	;copy the other things
	mov eax, dword[ebp+16]
	mov ecx, dword[ebp-48]
	mov dword[eax], ecx			;dataStart
	
	mov eax, dword[ebp+20]
	mov ecx, dword[ebp-52]
	mov dword[eax], ecx			;dataLength
	
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
	
	
;void audio_printWAVEFORMATEX(WAVEFORMATEX* info)
audio_printWAVEFORMATEX:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	
	;print it
	xor ecx, ecx
	mov cx, word[eax+16]
	push ecx
	xor ecx, ecx
	mov cx, word[eax+14]
	push ecx
	xor ecx, ecx
	mov cx, word[eax+12]
	push ecx
	push dword[eax+8]
	push dword[eax+4]
	xor ecx, ecx
	mov cx, word[eax+2]
	push ecx
	xor ecx, ecx
	mov cx, word[eax]
	push ecx
	push print_seven_ints_nl
	call my_printf
	add esp, 32


	mov esp, ebp
	pop ebp
	ret