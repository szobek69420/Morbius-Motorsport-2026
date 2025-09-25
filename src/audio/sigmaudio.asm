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
;	uint16 nBlockAlign;			;12
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
;} 	32 bytes overall; only lpData, dwBufferLength, dwFlags and dwLoops are important for us

;struct Sound{
;	int dataSizeInBytes;			;0
;	char* data;						;4
;	WAVEFORMATEX* formatDescriptor;	;8
;}	12 bytes overall

;struct Playback{
;	Sound* sound;					;0
;	int loopsLeft;					;4
;	int currentPosition;			;8	as in sample
;}

section .rodata use32

	MAX_PREPARED_BLOCKS dd 5		;the maximum number of prepared blocks waiting to play

	MMSYSERR_NOERROR dd 0

	WAVE_MAPPER dd 0xffffffff
	
	CALLBACK_FUNCTION dd 0x00030000
	WAVE_MAPPED_DEFAULT_COMMUNICATION_DEVICE dd 0x0010
	
	WHDR_BEGINLOOP dd 0x00000004
	WHDR_ENDLOOP dd 0x00000008
	
	WOM_OPEN dd 0x3bb
	WOM_CLOSE dd 0x3bc
	WOM_DONE dd 0x3bd
	
	WAVE_FORMAT_PCM dw 1
	
	file_open_mode db "r",0
	
	based_chunk_id db "RIFF"
	based_file_type db "WAVE"
	based_format_marker db "fmt "
	
	data_chunk_id db "data"

	error_read_failure db "audio_readWaveHeader: couldn't read the file %s",10,0
	error_invalid_chunk_id db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid chunk ID",10,0
	error_invalid_file_type db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid file type",10,0
	error_invalid_format_chunk_marker db "audio_readWaveHeader: couldn't read wave header of %s due to missing format chunk marker",10,0
	error_device_could_not_be_created db "audio_loadSound: audio device could not be created",10,0
	error_header_could_not_be_prepared db "audio_playSound: block header couldn't be prepared",10,0
	error_data_could_not_be_written db "audio_playSound: data couldn't be written to device",10,0

	print_seven_ints_nl db "%d %d %d %d %d %d %d",10,0
	
	test_text db "freaky golem",10,0
	
section .data use32
	
	initialized dd 0
	sample_rate dd 8000			;Hz (int)
	channels dd 2				;number of channels
	bits_per_sample dd 16		;bits per sample per channel
	block_length dd 100			;number of samples per prepared block
	
	audio_device dd 0			;waveOut device handle
	audio_thread dd 0			;Thread*
	prepared_block_count dd 0	;Semaphore*
	playbacks dd 0,0,0,0		;vector<Playback>
	
	should_stop dd 0			;tsValue<int>*
	
section .bss use32
	system_waveformatex resb 18	;the WAVEFORMATEX structure generated from the system values
	
section .text use32	

	global sigmaudio_init				;void sigmaudio_init(int sampleRate, int numChannels, int bitsPerSample)

	extern my_printf
	extern my_fopen
	extern my_fclose
	extern my_fjmp
	extern my_fread
	extern my_memcmp
	extern my_memcpy
	
	extern vector_init
	extern vector_destroy
	
	extern thread_create
	extern thread_join
	extern thread_resume
	extern semaphore_create
	extern semaphore_destroy
	extern semaphore_lock
	extern semaphore_unlock
	
	extern tsValue_create
	extern tsValue_destroy
	extern tsValue_get
	extern tsValue_set

sigmaudio_init:
	push ebp
	mov ebp, esp
	
	;check if already initialized
	test dword[initialized], 0xffffffff
	jz sigmaudio_init_not_initialized
		push sigmaudio_init_error_initialized
		call my_printf
		jmp sigmaudio_init_end
		sigmaudio_init_error_initialized db "sigmaudio_init: system is already initialized",10,0
	sigmaudio_init_not_initialized:
	
	;set values
	mov eax, dword[ebp+8]
	mov dword[sample_rate], eax
	mov ecx, dword[ebp+12]
	mov dword[channels], ecx
	mov edx, dword[ebp+16]
	mov dword[bits_per_sample], edx
	
	;generate the system WAVEFORMATEX
	mov ebx, system_waveformatex
	
	mov ax, word[WAVE_FORMAT_PCM]
	mov word[ebx], ax				;wFormatTag
	mov eax, dword[channels]
	mov word[ebx+2], ax				;nChannels
	mov eax, dword[sample_rate]
	mov dword[ebx+4], eax			;nSamplesPerSec
	mov eax, dword[bits_per_sample]
	mov word[ebx+14], ax			;nBitsPerSample
	imul eax, dword[channels]
	shr eax, 3
	mov word[ebx+12], ax			;nBlockAlign
	imul eax, dword[sample_rate]
	mov dword[ebx+8], eax			;nAvgBytesPerSec
	mov word[ebx+16], 0				;cbSize
	
	;create prepared block count
	push dword[MAX_PREPARED_BLOCKS]
	call semaphore_create
	mov dword[prepared_block_count], eax
	
	;create playback vector
	push 12
	push playbacks
	call vector_init
	
	;create and set should_stop
	push 4
	call tsValue_create
	mov dword[should_stop], eax
	push 0
	push eax
	call tsValue_set
	
	;create audio device
	push dword[CALLBACK_FUNCTION]	;the dwCallback is a function pointer
	push 0
	push sigmaudio_callback			;the callback function
	push system_waveformatex		;WAVEFORMATEX info
	push dword[WAVE_MAPPER]			;automatically map to device
	push audio_device				;HANDLE buffer
	call [waveOutOpen]
	cmp eax, dword[MMSYSERR_NOERROR]
	je sigmaudio_init_device_created
		mov dword[audio_device], 0
		
		push sigmaudio_init_error_device_not_created
		call my_printf
		jmp sigmaudio_init_end
		
		sigmaudio_init_error_device_not_created db "sigmaudio_init: Audio device couldn't be created",10,0
	sigmaudio_init_device_created:
	
	;start thread
	push 0
	push 0
	push sigmaudio_mainLoop
	call thread_create
	mov dword[audio_thread], eax
	push eax
	call thread_resume
	
	;set initialized flag
	mov dword[initialized], 69
	
	sigmaudio_init_end:
	mov esp, ebp
	pop ebp
	ret

;void sigmaudio_mainLoop()
sigmaudio_mainLoop:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret

;void sigmaudio_callback(HANDLE hwo, uint32 uMsg, Sound* sound, int* dwParam1, int* dwParam2 );
sigmaudio_callback:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+12]
	cmp eax, dword[WOM_OPEN]
	je sigmaudio_callback_device_opened
	cmp eax, dword[WOM_CLOSE]
	je sigmaudio_callback_device_closed
	cmp eax, dword[WOM_DONE]
	je sigmaudio_callback_playback_ended
	jmp audio_callback_end
	
	sigmaudio_callback_device_opened:
		jmp sigmaudio_callback_end
		
	sigmaudio_callback_device_closed:
		jmp sigmaudio_callback_end
		
	sigmaudio_callback_playback_ended:
		jmp sigmaudio_callback_end
	

	sigmaudio_callback_end:
	mov esp, ebp
	pop ebp
	ret

;dataStart: how long is the header in bytes
;dataLength: how much raw audio data is there in bytes
;returns zero if there were no problems
;int sigmaudio_readWaveHeader(const char* filePath, WaveHeader* headerBuffer, int* dataStart, int* dataLength)
sigmaudio_readWaveHeader:
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
	jz sigmaudio_readWaveHeader_error_read_failure
	
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
	jne sigmaudio_readWaveHeader_error_read_failure
	
	push 0		;not from current
	push 12		;the start of the first chunk
	push dword[ebp-40]
	call my_fjmp
	add esp, 12
	
	sigmaudio_readWaveHeader_parseChunks_loop_start:
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
		jnz sigmaudio_readWaveHeader_parseChunks_loop_continue
			;set the data size
			mov eax, dword[ebp-56]
			mov dword[ebp-52], eax
			jmp audio_readWaveHeader_parseChunks_loop_end
		
		sigmaudio_readWaveHeader_parseChunks_loop_continue:
		;add chunk size to the header size
		mov eax, dword[ebp-56]
		add dword[ebp-48], eax
		
		;skip chunk
		push 69				;from current
		push dword[ebp-56]	;chunk size
		push dword[ebp-40]	;file
		call my_fjmp
		add esp, 12
		jmp sigmaudio_readWaveHeader_parseChunks_loop_start
		
	sigmaudio_readWaveHeader_parseChunks_loop_end:
	
	
	
	;close the file
	push dword[ebp-40]
	call my_fclose
	add esp, 4
	test eax, eax
	jz sigmaudio_readWaveHeader_error_read_failure
	
	
	;is the chunk id kosher?
	lea eax, [ebp-36]
	push 4
	push eax
	push based_chunk_id
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz sigmaudio_readWaveHeader_invalid_chunk_id
	
	;is the file type halal?
	lea eax, [ebp-28]
	push 4
	push eax
	push based_file_type
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz sigmaudio_readWaveHeader_invalid_file_type
	
	;is the format marker shuddha?
	lea eax, [ebp-24]
	push 4
	push eax
	push based_format_marker
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz sigmaudio_readWaveHeader_invalid_format_marker
	
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
	
	jmp sigmaudio_readWaveHeader_end
	
	sigmaudio_readWaveHeader_error_read_failure:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_read_failure
		call my_printf
		add esp, 8
		jmp sigmaudio_readWaveHeader_end
		
		
	sigmaudio_readWaveHeader_invalid_chunk_id:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_chunk_id
		call my_printf
		add esp, 8
		jmp sigmaudio_readWaveHeader_end
		
		
	sigmaudio_readWaveHeader_invalid_file_type:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_file_type
		call my_printf
		add esp, 8
		jmp sigmaudio_readWaveHeader_end
		
		
	sigmaudio_readWaveHeader_invalid_format_marker:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_format_chunk_marker
		call my_printf
		add esp, 8
		jmp sigmaudio_readWaveHeader_end
	
	sigmaudio_readWaveHeader_end:
	mov eax, dword[ebp-44]		;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
;retrieves the WAVEFORMATEX struct corresponding to the file
;returns zero if there were no problems
;int sigmaudio_getWAVEFORMATEX(WAVEFORMATEX* buffer, WaveHeader* header)
sigmaudio_getWAVEFORMATEX:
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