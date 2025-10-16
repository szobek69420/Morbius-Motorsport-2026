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
;	char* filePath;					;12
;	int id;							;16		//for internal use
;	int sampleCount;				;20		//sampleCount as in dataSizeInBytes/system_waveformatex->nBlockAlign
;	int importCount;				;24
;}	28 bytes overall

;struct Playback{
;	int id;							;0
;	Sound* sound;					;4
;	int loopsLeft;					;8
;	int currentPosition;			;12	as in nBlockAlign
;	int priority;					;16
;}	20 bytes overall

;struct PlaybackCommand{
;	enum{ PLAY=0, STOP=69, UNLOAD=420 } commandType;
;
;	union{
;		struct PlayCommand{ int soundId; int loopCount; int playbackId; int priority; } playCommand;
;		struct StopCommand{ int playbackId; } stopCommand;
;		struct UnloadCommand{ int soundId; } unloadCommand;
;	}
;}	20 bytes overall

%macro dll_import 2
	import %2 %1
	extern %2
%endmacro

section .rodata use32

	;the maximum number of prepared blocks waiting to play
	;if this is changed, the helpers for the main loop might need to be changed as well
	MAX_PREPARED_BLOCKS dd 5
	BLOCK_LENGTH dd 1000			;number of samples per prepared block
	MAX_PLAYBACK_COUNT dd 5			;max number of playbacks
	VOLUME_SCALER dd 0.2			;1/MAX_PLAYBACK_COUNT
	
	PLAYBACK_COMMAND_PLAY equ 0
	PLAYBACK_COMMAND_STOP equ 69
	PLAYBACK_COMMAND_UNLOAD equ 420
	

	MMSYSERR_NOERROR dd 0

	WAVE_MAPPER dd 0xffffffff
	
	CALLBACK_FUNCTION dd 0x00030000
	WAVE_MAPPED_DEFAULT_COMMUNICATION_DEVICE dd 0x0010
	
	WHDR_BEGINLOOP dd 0x00000004
	WHDR_ENDLOOP dd 0x00000008
	WHDR_DONE dd 0x00000001
	
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

	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_four_ints_nl db "%d %d %d %d",10,0
	print_seven_ints_nl db "%d %d %d %d %d %d %d",10,0
	print_string_nl db "%s",10,0
	
	test_text db "freaky golem",10,0
	test_text2 db "cheeky golem",10,0
	
	ZERO dd 0
	ONE dd 1.0
	
	;helpers for mixin
	SCALER_8BIT dd 0.0078125
	SCALER_16BIT dd 0.000030517578125
	SCALER_24BIT dd 0.00000011920928955
	SCALER_32BIT dd 0.00000000046566128730774
	UNSCALER_8BIT dd 128.0
	UNSCALER_16BIT dd 32768.0
	UNSCALER_24BIT dd 8388608.0
	UNSCALER_32BIT dd 2147483648.0
	
	
section .data use32
	
	initialized dd 0
	sample_rate dd 8000			;Hz (int)
	channels dd 2				;number of channels
	bits_per_sample dd 16		;bits per sample per channel
	
	imported_sounds dd 0,0		;tsVector<Sound*>
	
	audio_device dd 0			;waveOut device handle
	audio_thread dd 0			;Thread*
	playbacks dd 0,0			;tsVector<Playback>
	command_queue dd 0,0		;tsQueue<PlaybackCommand>
	
	should_exit dd 0			;tsValue<int>*
	
	current_sound_id dd 0		;tsValue<int>*
	current_playback_id dd 0	;tsValue<int>*
	
	;helpers for main
	prepared_block_critical_section	dd 0	;CriticalSection*
	prepared_block_count dd 0				;int
	prepared_blocks dd 0,0,0,0,0			;char prepared_blocks[MAX_PREPARED_BLOCKS][BLOCK_LENGTH * system_waveformatex->nBlockAlign]
	prepared_headers dd 0,0,0,0,0			;WAVEHDR* prepared_headers[MAX_PREPARED_BLOCKS]
	is_prepared dd 0,0,0,0,0				;int is_prepared[MAX_PREPARED_BLOCKS]
	
section .bss use32
	system_waveformatex resb 18	;the WAVEFORMATEX structure generated from the system values
	
section .text use32	

	;bitsPerSample needs to be in {8,16,24,32}
	global sigmaudio_init				;void sigmaudio_init(int sampleRate, int numChannels, int bitsPerSample)
	global sigmaudio_deinit				;void sigmaudio_deinit()

	global sigmaudio_import				;int sigmaudio_import(const char* soundPath)	//returns zero if no error occured
	global sigmaudio_deport				;void sigmaudio_deport(const char* soundPath)
	
	;returns the id of the playback if gg, else 0
	;int sigmaudio_play(const char* soundPath, int loopCount, int priority)
	global sigmaudio_play
	global sigmaudio_stop				;void sigmaudio_stop(int playbackId)
	
	extern sigmaudio_changeSamplesPerSec
	extern sigmaudio_changeNumChannels
	extern sigmaudio_changeBitsPerSample

	dll_import winmm.dll, waveOutOpen				;creates an audio device
	dll_import winmm.dll, waveOutClose				;destroys an audio device
	dll_import winmm.dll, waveOutWrite				;writes (plays) a playback block into an audio device
	dll_import winmm.dll, waveOutReset				;stops the currently playing sound on the given audio device
	dll_import winmm.dll, waveOutPause				;pauses the currently playing sound on the given audio device
	dll_import winmm.dll, waveOutRestart			;resumes the currently playing sound on the given audio device
	dll_import winmm.dll, waveOutPrepareHeader		;prepares a playback block to be played
	dll_import winmm.dll, waveOutUnprepareHeader	;undoes the PrepareHeader func

	dll_import kernel32.dll, Sleep

	extern my_printf
	extern my_malloc
	extern my_free
	extern my_fopen
	extern my_fclose
	extern my_fjmp
	extern my_fread
	extern file_getId
	extern my_memcmp
	extern my_memcpy
	extern my_memset
	extern my_strcmp
	extern my_strcpy
	extern my_strlen
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back_buffer
	
	extern tsVector_init
	extern tsVector_destroy
	extern tsVector_pushBack
	extern tsVector_pushBackBuffer
	extern tsVector_popBack
	extern tsVector_removeAt
	extern tsVector_search
	extern tsVector_forEach
	extern tsVector_at
	extern tsVector_lock
	extern tsVector_unlock
	extern tsVector_sizeNonBlocking
	
	extern tsQueue_init
	extern tsQueue_destroy
	extern tsQueue_push
	extern tsQueue_pushBuffer
	extern tsQueue_pop
	
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
	extern tsValue_lock
	extern tsValue_unlock
	
	extern criticalSection_create
	extern criticalSection_destroy
	extern criticalSection_lock
	extern criticalSection_unlock

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
	
	;create imported sounds vector
	push 4
	push imported_sounds
	call tsVector_init
	
	;create playback vector
	push 20
	push playbacks
	call tsVector_init
	
	;create command queue
	push 64
	push 20
	push command_queue
	call tsQueue_init
	
	;create and set should_stop
	push 4
	call tsValue_create
	mov dword[should_exit], eax
	push 0
	push eax
	call tsValue_set
	
	;create and set id helpers
	push 4
	call tsValue_create
	mov dword[current_sound_id], eax
	call tsValue_create
	mov dword[current_playback_id], eax
	
	push 69420
	push dword[current_sound_id]
	call tsValue_set
	push 42069
	push dword[current_playback_id]
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
	
sigmaudio_deinit:
	push ebp
	mov ebp, esp
	
	;is initialized
	test dword[initialized], 0xffffffff
	jnz sigmaudio_deinit_initialized
		push sigmaudio_deinit_error_not_initialized
		call my_printf
		jmp sigmaudio_deinit_end
		
		sigmaudio_deinit_error_not_initialized db "sigmaudio_deinit: The system is not initialized",10,0
	sigmaudio_deinit_initialized:
	
	;deport all remaining sounds
	push 0
	push sigmaudio_deinit_deporter
	push imported_sounds
	call tsVector_forEach
	jmp sigmaudio_deinit_deported
		sigmaudio_deinit_deporter:		;void deporter(Sound**, void* unused)
			mov eax, dword[esp+4]
			mov eax, dword[eax]
			push dword[eax+12]
			call sigmaudio_deport
			add esp, 4
			ret
	sigmaudio_deinit_deported:
	
	;yeet the audio thread
	push 69
	push dword[should_exit]
	call tsValue_set
	
	push -1
	push dword[audio_thread]
	call thread_join
	test eax, eax
	jz sigmaudio_deinit_thread_has_been_yeeten
		push sigmaudio_deinit_error_yeetus_fehlgeschlagen
		call my_printf
		jmp sigmaudio_deinit_end
		
		sigmaudio_deinit_error_yeetus_fehlgeschlagen db "sigmaudio_deinit: Sumting wong nig",10,0
	sigmaudio_deinit_thread_has_been_yeeten:
	
	;close the audio device
	push dword[audio_device]
	call [waveOutClose]
	
	;destroy command queue
	push command_queue
	call tsQueue_destroy
	
	;delete the playback vector
	push playbacks
	call tsVector_destroy
	
	;delete the imported sounds vector
	push imported_sounds
	call tsVector_destroy
	
	;destroy should_exit
	push dword[should_exit]
	call tsValue_destroy
	
	;destroy id helpers
	push dword[current_sound_id]
	call tsValue_destroy
	push dword[current_playback_id]
	call tsValue_destroy
	
	;unset initialized flag
	mov dword[initialized], 0
	
	sigmaudio_deinit_end:
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
	
	sub esp, 4			;prepared data size			4
	sub esp, 4			;scaler						8		//1/playbacks.size()
	sub esp, 4			;current prepared index		12
	sub esp, 4			;active playback countr		16
	sub esp, 4			;system_waveformatex->nBlockAlign	20
	sub esp, 4			;bytesPerSample				24
	sub esp, 4			;overall sample count		28		//BLOCK_LENGTH*numChannels
	sub esp, 4			;is last loop				32
	
	mov dword[ebp-32], 0
	
	;calculate prepared data size and overall sample count
	mov eax, system_waveformatex
	mov cx, word[eax+12]		;system_waveformatex->nBlockAlign
	movsx ecx, cx
	imul ecx, [BLOCK_LENGTH]
	mov dword[ebp-4], ecx
	
	mov dx, word[eax+2]
	movsx edx, dx
	imul edx, dword[BLOCK_LENGTH]
	mov dword[ebp-28], edx
	
	;get nBlockAlign and bytesPerSample
	mov eax, system_waveformatex
	mov cx, word[eax+12]
	movsx ecx, cx
	mov dword[ebp-20], ecx
	mov dx, word[eax+14]
	shr dx, 3
	movsx edx, dx
	mov dword[ebp-24], edx
	
	;create helpers
	call criticalSection_create
	mov dword[prepared_block_critical_section], eax
	
	mov dword[prepared_block_count], 0
	
	mov ebx, dword[MAX_PREPARED_BLOCKS]
	dec ebx
	sigmaudio_mainLoop_setup_prepared_loop_start:
		push dword[ebp-4]
		call my_malloc
		mov dword[prepared_blocks+4*ebx], eax
		add esp, 4
		
		push 32
		call my_malloc
		mov dword[prepared_headers+4*ebx], eax
		add esp, 4
		
		mov dword[is_prepared+4*ebx], 0
		
		dec ebx
		test ebx, 0x80000000
		jz sigmaudio_mainLoop_setup_prepared_loop_start
	
	
	sigmaudio_mainLoop_loop_start:
		
		;check if there is a block to be prepared
		;no need for lock here
		sigmaudio_mainLoop_loop_wait:	
			mov eax, dword[MAX_PREPARED_BLOCKS]
			cmp dword[prepared_block_count], eax
			jl sigmaudio_mainLoop_loop_no_more_wait
				push 5
				call [Sleep]
				
				jmp sigmaudio_mainLoop_loop_wait
				
			sigmaudio_mainLoop_loop_no_more_wait:
			;increment prepared block count
			inc dword[prepared_block_count]
			
		;check for ended (or looped) playbacks
		push 69
		push sigmaudio_mainLoop_loop_end_check_function
		push playbacks
		call tsVector_forEach
		add esp, 12
		jmp sigmaudio_mainLoop_loop_end_check_function_skip
		sigmaudio_mainLoop_loop_end_check_function:	;void func(Playback*, void* unused)
			mov eax, dword[esp+4]
			mov ecx, dword[eax+4]
			mov ecx, dword[ecx+20]
			cmp ecx, dword[eax+12]			;sound sample count > playback current position?
			jg sigmaudio_mainLoop_loop_end_check_function_end
				mov dword[eax+12], 0
				dec dword[eax+8]
				cmp dword[eax+8], 0			;are there loops left?
				jg sigmaudio_mainLoop_loop_end_check_function_end
					;yeet playback
					push dword[eax]
					call sigmaudio_stop
					add esp, 4
			sigmaudio_mainLoop_loop_end_check_function_end:
			ret
		sigmaudio_mainLoop_loop_end_check_function_skip:
			
		;process commands
		call sigmaudio_processCommands_internal
		
		;select the block to be prepared
		;it's either is_prepared[selected]==0 
		;or (prepared_header[selected]->dwFlags & WHDR_DONE)!=0
		;(in the latter case the header needs to be unprepared as well)
		xor ebx, ebx
		sigmaudio_mainLoop_loop_select_loop_start:
			test dword[is_prepared+4*ebx], 0xffffffff
			jz sigmaudio_mainLoop_loop_select_loop_end			;found
			
			mov eax, dword[prepared_headers+4*ebx]
			mov ecx, dword[WHDR_DONE]
			test dword[eax+16], ecx	;test dwFlags
			jz sigmaudio_mainLoop_loop_select_loop_continue
				;(prepared_header[selected]->dwFlags & WHDR_DONE)!=0
				;header needs to be unprepared first
				push 32
				push dword[prepared_headers+4*ebx]
				push dword[audio_device]
				call [waveOutUnprepareHeader]
				
				mov dword[is_prepared+4*ebx], 0
				
				jmp sigmaudio_mainLoop_loop_select_loop_end
			
			sigmaudio_mainLoop_loop_select_loop_continue:
			inc ebx
			cmp ebx, dword[MAX_PREPARED_BLOCKS]
			jl sigmaudio_mainLoop_loop_select_loop_start
		sigmaudio_mainLoop_loop_select_loop_end:

		;save index
		mov dword[ebp-12], ebx
		
		;calculate the scaler
		push playbacks
		call tsVector_sizeNonBlocking
		mov dword[ebp-16], eax
		add esp, 4
		
		mov eax, dword[VOLUME_SCALER]
		mov dword[ebp-8], eax
		
		;zero out the data
		mov ebx, dword[ebp-12]
		push dword[ebp-4]
		push 0
		push dword[prepared_blocks+4*ebx]
		call my_memset
		add esp, 12
		
		;mix the playbacks
		push ebp
		push sigmaudio_mainLoop_loop_mix_function
		push playbacks
		call tsVector_forEach
		add esp, 12
		jmp sigmaudio_mainLoop_loop_mix_done
		sigmaudio_mainLoop_loop_mix_function:		;void func(Playback*, void* ebpOfMainLoop)
			push ebp
			push esi
			push edi
			push ebx
			mov ebp, esp
			
			sub esp, 4			;bytesPerSample
			
			mov eax, dword[ebp+20]
			mov ecx, dword[ebp+24]
			
			mov edx, dword[ecx-24]
			mov dword[ebp-4], edx		;move bytesPerSample closer
			
			mov edx, dword[eax+12]
			imul edx, dword[ecx-20]
			mov esi, dword[eax+4]
			mov esi, dword[esi+4]
			add esi, edx							;source data in esi
			mov edi, dword[ecx-12]
			shl edi, 2
			mov edi, dword[prepared_blocks+edi]	;destination data in edi
			mov ebx, dword[ecx-28]					;index in ebx
			sigmaudio_mainLoop_loop_mix_function_loop_start:
				cmp dword[ebp-4], 2
				je sigmaudio_mainLoop_loop_mix_function_loop_16bit
				cmp dword[ebp-4], 3
				je sigmaudio_mainLoop_loop_mix_function_loop_24bit
				cmp dword[ebp-4], 4
				je sigmaudio_mainLoop_loop_mix_function_loop_32bit
					;8 bit
					mov edx, dword[ebp+24]
					
					mov al, byte[esi]
					sub al, 0xf0			;unsigned -> signed
					movsx eax, al
					mov cl, byte[edi]
					sub cl, 0xf0			;unsigned -> signed
					movsx ecx, cl
					cvtsi2ss xmm0, eax
					cvtsi2ss xmm1, ecx
					mulss xmm0, dword[SCALER_8BIT]
					mulss xmm1, dword[SCALER_8BIT]
					mulss xmm0, dword[edx-8]
					addss xmm1, xmm0
					mulss xmm1, dword[UNSCALER_8BIT]
					cvtss2si eax, xmm1
					add al, 0xf0			;signed -> unsigned
					mov byte[edi], al			;there should be no problem with the sign if the scaling is right
					
					inc esi
					inc edi
					jmp sigmaudio_mainLoop_loop_mix_function_loop_continue
				
				sigmaudio_mainLoop_loop_mix_function_loop_16bit:
					;16 bit
					mov edx, dword[ebp+24]
					
					mov ax, word[esi]
					movsx eax, ax
					mov cx, word[edi]
					movsx ecx, cx
					cvtsi2ss xmm0, eax
					cvtsi2ss xmm1,  ecx
					mulss xmm0, dword[SCALER_16BIT]
					mulss xmm1, dword[SCALER_16BIT]
					mulss xmm0, dword[edx-8]
					addss xmm1, xmm0
					mulss xmm1, dword[UNSCALER_16BIT]
					cvtss2si eax, xmm1
					mov word[edi], ax			;there should be no problem with the sign if the scaling is right
					
					add esi, 2
					add edi, 2
					jmp sigmaudio_mainLoop_loop_mix_function_loop_continue
					
				sigmaudio_mainLoop_loop_mix_function_loop_24bit:
					;24 bit
					mov edx, dword[ebp+24]
					
					xor eax, eax
					mov ax, word[esi+1]
					shl eax, 16
					mov ah, byte[esi]
					sar eax, 8
					mov cx, word[edi+1]
					shl ecx, 16
					mov ch, byte[edi]
					sar ecx, 8
					cvtsi2ss xmm0, eax
					cvtsi2ss xmm1, ecx
					mulss xmm0, dword[SCALER_24BIT]
					mulss xmm1, dword[SCALER_24BIT]
					mulss xmm0, dword[edx-8]
					addss xmm1, xmm0
					mulss xmm1, dword[UNSCALER_16BIT]
					cvtss2si eax, xmm1
					mov word[edi], ax			;there should be no problem with the sign if the scaling is right
					shr eax, 8
					mov byte[edi+2], ah
					
					add esi, 3
					add edi, 3
					jmp sigmaudio_mainLoop_loop_mix_function_loop_continue
					
				sigmaudio_mainLoop_loop_mix_function_loop_32bit:
					;32 bit
					mov edx, dword[ebp+24]
					
					mov eax, dword[esi]
					mov ecx, dword[edi]
					cvtsi2ss xmm0, eax
					cvtsi2ss xmm1, ecx
					mulss xmm0, dword[SCALER_32BIT]
					mulss xmm1, dword[SCALER_32BIT]
					mulss xmm0, dword[edx-8]
					addss xmm1, xmm0
					mulss xmm1, dword[UNSCALER_32BIT]
					cvtss2si eax, xmm1
					mov dword[edi], eax			;there should be no problem with the sign if the scaling is right
					
					add esi, 4
					add edi, 4
					
				sigmaudio_mainLoop_loop_mix_function_loop_continue:
				dec ebx
				jnz sigmaudio_mainLoop_loop_mix_function_loop_start
				
			;step the playback
			mov eax, dword[ebp+20]
			mov ecx, dword[BLOCK_LENGTH]
			add dword[eax+12], ecx
			
			mov esp, ebp
			pop ebx
			pop edi
			pop esi
			pop ebp
			ret
		sigmaudio_mainLoop_loop_mix_done:
		
		;set and prepare the header
		;> set the lpData, dwBufferLength, dwFlags and dwLoops values of the header
		mov ebx, dword[ebp-12]
		mov eax, dword[prepared_headers+4*ebx]
		mov ecx, dword[prepared_blocks+4*ebx]
		
		mov dword[eax], ecx		;lpData
		mov edx, dword[ebp-4]
		mov dword[eax+4], edx	;dwBufferLength
		mov dword[eax+16], 0	;dwFlags (the flags are for looping)
		mov dword[eax+20], 1	;dwLoops
		
		push 32
		push dword[prepared_headers+4*ebx]
		push dword[audio_device]
		call [waveOutPrepareHeader]
		
		mov dword[is_prepared+4*ebx], 69
		
		;write buffer
		push 32
		push dword[prepared_headers+4*ebx]
		push dword[audio_device]
		call [waveOutWrite]
		
		
		;was this the last loop?
		test dword[ebp-32], 0xffffffff
		jnz sigmaudio_mainLoop_loop_end
		
		;check if the next is the last loop
		;last loop only serves as a cleanup procedure
		sub esp, 4
		mov eax, esp
		push eax
		push dword[should_exit]
		call tsValue_get
		mov eax, dword[esp+8]
		add esp, 12
		test eax, eax
		jz sigmaudio_mainLoop_loop_start
			;set last loop flag
			mov dword[ebp-32], 69
			jmp sigmaudio_mainLoop_loop_start
		
	sigmaudio_mainLoop_loop_end:	
	
	;stop playbakc
	push dword[audio_device]
	call [waveOutReset]
		
	;destroy helpers
	mov ebx, dword[MAX_PREPARED_BLOCKS]
	dec ebx
	sigmaudio_mainLoop_delete_prepared_loop_start:
		;unprepare headers if necessary
		test dword[is_prepared+4*ebx], 0xffffffff
		jz sigmaudio_mainLoop_delete_prepared_loop_no_unprepare
			push 32
			push dword[prepared_headers+4*ebx]
			push dword[audio_device]
			call [waveOutUnprepareHeader]
			add esp, 12
		sigmaudio_mainLoop_delete_prepared_loop_no_unprepare:
		
		;free memory
		push dword[prepared_blocks+4*ebx]
		call my_free
		add esp, 4
		
		push dword[prepared_headers+4*ebx]
		call my_free
		add esp, 4
		
		mov dword[is_prepared+4*ebx], 0
		
		dec ebx
		test ebx, 0x80000000
		jz sigmaudio_mainLoop_delete_prepared_loop_start
	
	mov dword[prepared_block_count], 0
	
	push dword[prepared_block_critical_section]
	call criticalSection_destroy
	add esp, 4
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
;void sigmaudio_callback(HANDLE hwo, uint32 uMsg, void* unused, int* dwParam1, int* dwParam2 );
sigmaudio_callback:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+12]
	cmp eax, dword[WOM_DONE]
	jne sigmaudio_callback_end
		;decrement the currently playing blocks
		push dword[prepared_block_critical_section]
		;call criticalSection_lock
		dec dword[prepared_block_count]
		;call criticalSection_unlock
	
	sigmaudio_callback_end:
	mov esp, ebp
	pop ebp
	ret
	
	
sigmaudio_import:
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
	sub esp, 4	;copied file path		68
	sub esp, 4	;sound id				72
	sub esp, 4	;return value			76
	
	sub esp, 4	;nBlockAlign count		80
	sub esp, 4	;padded nBlockAlign count	84
	sub esp, 4	;padded data size		88
	
	mov dword[ebp-4], 0
	mov dword[ebp-76], 0
	
	;check if the sound is already imported
	push dword[ebp+8]
	push sigmaudio_import_already_imported_comparator
	push imported_sounds
	call tsVector_search
	add esp, 12
	cmp eax, -1
	jne sigmaudio_loadSound_end		;sound already imported
	jmp sigmaudio_import_not_imported
	sigmaudio_import_already_imported_comparator:		;int comparator(Sound**, const char* soundPath)
		mov eax, dword[esp+4]
		mov eax, dword[eax]
		mov ecx, dword[esp+8]
		push ecx
		push dword[eax+12]
		call my_strcmp
		add esp, 8
		test eax, eax
		jnz sigmaudio_import_already_imported_comparator_end
			mov ecx, dword[esp+4]
			mov ecx, dword[ecx]
			inc dword[ecx+24]		;increment import count!!!!!
		sigmaudio_import_already_imported_comparator_end:
		ret
	sigmaudio_import_not_imported:
	
	;read the header
	lea eax, [ebp-24]
	push eax
	lea eax, [ebp-20]
	push eax
	lea eax, [ebp-60]
	push eax
	push dword[ebp+8]
	call sigmaudio_readWaveHeader
	add esp, 16
	
	;check if the read was successful
	test eax, eax
	jz sigmaudio_loadSound_no_error
		;set return value
		mov dword[ebp-76], 69
		
		;print error and yeet
		push dword[ebp+8]
		push sigmaudio_loadSound_error_could_not_read_header
		call my_printf
		jmp sigmaudio_loadSound_end
		
		sigmaudio_loadSound_error_could_not_read_header db "sigmaudio_loadSound: Couldn't read header of %s",10,0
	sigmaudio_loadSound_no_error:
	
	;calculate the padded data size
	mov eax, dword[ebp-24]
	xor edx, edx
	xor ecx, ecx 
	mov cx, word[ebp-28]
	idiv ecx
	mov dword[ebp-80], eax		;nBlockAlign count
	
	mov eax, dword[ebp-80]
	xor edx, edx
	mov ecx, dword[BLOCK_LENGTH]
	idiv ecx
	sub ecx, edx
	mov eax, dword[ebp-80]
	add eax, ecx
	mov dword[ebp-84], eax		;padded nBlockAlign count
	
	xor ecx, ecx
	mov cx, word[ebp-28]
	imul eax, ecx
	mov dword[ebp-88], eax		;padded data size
	
	;alloc space for the data
	push dword[ebp-88]
	call my_malloc
	mov dword[ebp-16], eax
	add esp, 4
	
	;read the audio data from the file and zero out the padding
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
	
	mov eax, dword[ebp-88]
	mov ecx, dword[ebp-24]
	sub eax, ecx
	mov edx, dword[ebp-16]
	add edx, ecx
	push eax
	push 0
	push edx
	call my_memset
	
	;get the WAVEFORMATEX
	push 18
	call my_malloc
	mov dword[ebp-12], eax
	add esp, 4
	
	lea eax, [ebp-60]
	push eax
	push dword[ebp-12]
	call sigmaudio_getWAVEFORMATEX
	add esp, 8
	
	;copy the file path
	push dword[ebp+8]
	call my_strlen
	inc eax
	mov dword[esp], eax
	call my_malloc
	mov dword[ebp-68], eax
	push dword[ebp+8]
	push eax
	call my_strcpy
	
	;get the sound id and update the id helper
	push dword[current_sound_id]
	call tsValue_lock
	
	lea eax, [ebp-72]
	push eax
	push dword[current_sound_id]
	call tsValue_get
	
	mov eax, dword[ebp-72]
	inc eax
	push eax
	push dword[current_sound_id]
	call tsValue_set
	
	call tsValue_unlock
	
	;alloc the Sound struct
	push 28
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	;init the Sound struct
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp-88]
	mov dword[eax], ecx		;(padded) data size
	mov ecx, dword[ebp-16]
	mov dword[eax+4], ecx	;data
	mov ecx, dword[ebp-12]
	mov dword[eax+8], ecx	;WAVEFORMATEX*
	mov ecx, dword[ebp-68]
	mov dword[eax+12], ecx	;path
	mov ecx, dword[ebp-72]
	mov dword[eax+16], ecx	;id
	mov ecx, dword[ebp-84]
	mov dword[eax+20], ecx	;(padded) sampleCount
	mov dword[eax+24], 1	;import count
	
	;convert format to internal representation
	push dword[ebp+8]
	push print_string_nl
	call my_printf
	
	mov eax, dword[ebp-12]
	push dword[eax+4]
	push dword[sample_rate]
	push print_two_ints_nl
	call my_printf
	
	push dword[BLOCK_LENGTH]
	push dword[sample_rate]
	push dword[ebp-4]
	call sigmaudio_changeSamplesPerSec
	
	push dword[channels]
	push dword[ebp-4]
	call sigmaudio_changeNumChannels
	
	push dword[bits_per_sample]
	push dword[ebp-4]
	call sigmaudio_changeBitsPerSample
	
	;add sound to imported sounds
	push dword[ebp-4]
	push imported_sounds
	call tsVector_pushBack
	
	sigmaudio_loadSound_end:
	mov eax, dword[ebp-76]		;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
sigmaudio_deport:
	push ebp
	mov ebp, esp
	
	sub esp, 20			;command buffer		20
	sub esp, 4			;search resutl		24
	sub esp, 4			;psound				28
	
	;get the sound
	push imported_sounds
	call tsVector_lock
	
	push dword[ebp+8]
	push sigmaudio_deport_search_comparator
	push imported_sounds
	call tsVector_search
	mov dword[ebp-24], eax
	cmp eax, -1
	jne sigmaudio_deport_sound_imported
		;unlock critical sex
		push imported_sounds
		call tsVector_unlock
		
		;print error message
		push dword[ebp+8]
		push sigmaudio_deport_error_sound_not_imported
		call my_printf
		
		jmp sigmaudio_deport_end
		sigmaudio_deport_error_sound_not_imported db "sigmaudio_deport: %s is not imported",10,0
	sigmaudio_deport_sound_imported:
	
	push dword[ebp-24]
	push imported_sounds
	call tsVector_at
	mov eax, dword[eax]
	mov dword[ebp-28], eax		;sound
	
	push imported_sounds
	call tsVector_unlock
	
	;decrement the import count (and exit if it's not 0)
	mov eax, dword[ebp-28]
	dec dword[eax+24]
	jnz sigmaudio_deport_end
	
	;register unload command
	mov dword[ebp-20], PLAYBACK_COMMAND_UNLOAD
	mov eax, dword[ebp-28]
	mov eax, dword[eax+16]
	mov dword[ebp-16], eax		;sound id
	
	lea eax, [ebp-20]
	push eax
	push command_queue
	call tsQueue_pushBuffer
	
	
	sigmaudio_deport_end:
	mov esp, ebp
	pop ebp
	ret
	sigmaudio_deport_search_comparator:		;int comparator(Sound**, const char* path)
		mov eax, dword[esp+4]
		mov eax, dword[eax]
		mov ecx, dword[esp+8]
		push ecx
		push dword[eax+12]
		call my_strcmp
		add esp, 8
		ret
	
	
sigmaudio_play:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;priority				4
	sub esp, 4		;playback id			8
	sub esp, 4		;loop count				12
	sub esp, 4		;sound id				16
	sub esp, 4		;command type			20
	
	sub esp, 4		;search result			24
	sub esp, 4		;sound					28
	
	;check if the command is in the imported sounds vector
	push imported_sounds
	call tsVector_lock
	
	push dword[ebp+8]
	push sigmaudio_play_search_comparator
	push imported_sounds
	call tsVector_search
	mov dword[ebp-24], eax
	cmp eax, -1
	jne sigmaudio_play_sound_imported
		;unlock critical sex
		push imported_sounds
		call tsVector_unlock
		
		;print error message
		push dword[ebp+8]
		push sigmaudio_play_error_sound_not_imported
		call my_printf
		
		jmp sigmaudio_play_end
		sigmaudio_play_error_sound_not_imported db "sigmaudio_play: %s is not imported",10,0
	sigmaudio_play_sound_imported:
	
	push dword[ebp-24]
	push imported_sounds
	call tsVector_at
	mov eax, dword[eax]
	mov dword[ebp-28], eax		;sound
	
	push imported_sounds
	call tsVector_unlock
	
	;prepare command buffer
	mov dword[ebp-20], PLAYBACK_COMMAND_PLAY		;play command
	mov eax, dword[ebp+12]
	mov dword[ebp-12], eax		;loop count
	mov ecx, dword[ebp-28]
	mov ecx, dword[ecx+16]
	mov dword[ebp-16], ecx		;sound id
	mov edx, dword[ebp+16]
	mov dword[ebp-4], edx		;priority
	
	push dword[current_playback_id]
	call tsValue_lock
	
	lea eax, dword[ebp-8]
	push eax
	push dword[current_playback_id]
	call tsValue_get			;playback id
	
	mov eax, dword[ebp-8]
	inc eax
	push eax
	push dword[current_playback_id]
	call tsValue_set
	
	call tsValue_unlock
	
	;add the command to the command queue
	lea eax, [ebp-20]
	push eax
	push command_queue
	call tsQueue_pushBuffer
	
	sigmaudio_play_end:
	mov esp, ebp
	pop ebp
	ret
	sigmaudio_play_search_comparator:		;int comparator(Sound**, const char* path)
		mov eax, dword[esp+4]
		mov eax, dword[eax]
		mov ecx, dword[esp+8]
		push ecx
		push dword[eax+12]
		call my_strcmp
		add esp, 8
		ret
	
	
	
sigmaudio_stop:
	push ebp
	mov ebp, esp
	
	sub esp, 20		;command buffer		20
	
	;set values in the buffer
	mov dword[ebp-20], PLAYBACK_COMMAND_STOP			;stop command
	mov eax, dword[ebp+8]
	mov dword[ebp-16], eax			;playback id
	
	;add the command to the queue
	lea eax, [ebp-20]
	push eax
	push command_queue
	call tsQueue_pushBuffer
	
	mov esp, ebp
	pop ebp
	ret
	
	
;internal functinos

;void sigmaudio_processCommands_internal()
sigmaudio_processCommands_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 20			;command buffer			20
	sub esp, 20			;playback buffer		40
	sub esp, 4			;sound					44
	sub esp, 4			;lowest priority		48
	sub esp, 4			;lowest priority index	52
	
	sigmaudio_processCommands_internal_loop_start:
		;attempt to pop command
		lea eax, [ebp-20]
		push eax
		push command_queue
		call tsQueue_pop
		test eax, eax
		jnz sigmaudio_processCommands_internal_loop_end
		
		cmp dword[ebp-20], PLAYBACK_COMMAND_PLAY
		je sigmaudio_processCommands_loop_play
		cmp dword[ebp-20], PLAYBACK_COMMAND_STOP
		je sigmaudio_processCommands_loop_stop
		cmp dword[ebp-20], PLAYBACK_COMMAND_UNLOAD
		je sigmaudio_processCommands_loop_unload
		jmp sigmaudio_processCommands_internal_loop_start		;invalid command
		
		sigmaudio_processCommands_loop_play:
			;PLAY SOUND
			;check if the sound is still imported
			push imported_sounds
			call tsVector_lock
			
			push dword[ebp-16]			;sound id
			push sigmaudio_processCommands_loop_play_search_comparator
			push imported_sounds
			call tsVector_search
			cmp eax, -1
			jne sigmaudio_processCommands_loop_play_sound_imported
				;release the lock
				push imported_sounds
				call tsVector_unlock
				;print error message
				push sigmaudio_processCommands_loop_play_error_sound_not_imported
				call my_printf
				jmp sigmaudio_processCommands_internal_loop_start			;continue
				sigmaudio_processCommands_loop_play_error_sound_not_imported db "sigmaudio_processCommands_internal: sound is not imported",10,0
			sigmaudio_processCommands_loop_play_sound_imported:
			push eax
			push imported_sounds
			call tsVector_at
			mov eax, dword[eax]
			mov dword[ebp-44], eax
			
			push imported_sounds
			call tsVector_unlock
			
			;check if there is a free slot for the sound
			;if not, check if there are any sounds with lower priority
			push playbacks
			call tsVector_sizeNonBlocking
			cmp eax, dword[MAX_PLAYBACK_COUNT]
			jl sigmaudio_processCommands_loop_play_sound_slot_available
				mov dword[ebp-48], 0x7fffffff
				mov dword[ebp-52], 0
				
				push ebp
				push sigmaudio_processCommands_loop_play_sound_min_foreach_function
				push playbacks
				call tsVector_forEach
				add esp, 12
				test dword[ebp-52], 0xffffffff
				jnz sigmaudio_processCommands_loop_play_sound_unload_lower_priority_playback
					;print error message
					mov eax, dword[ebp-44]
					push dword[eax+12]
					push sigmaudio_processCommands_loop_play_sound_error_no_available_slot
					call my_printf
					add esp, 8
					jmp sigmaudio_processCommands_internal_loop_start
					
					sigmaudio_processCommands_loop_play_sound_error_no_available_slot db "sigmaudio_processCommands: %s cound not be played as too many sounds are playing already",10,0
				sigmaudio_processCommands_loop_play_sound_unload_lower_priority_playback:
				
				mov eax, dword[ebp-52]
				push dword[eax]
				call sigmaudio_stop
				add esp, 4
				jmp sigmaudio_processCommands_loop_play_sound_slot_available
				
				;void func(Playback*, void* ebpOfProcessCommands)
				;searches for the minimal priority
				sigmaudio_processCommands_loop_play_sound_min_foreach_function:
					mov eax, dword[esp+4]
					mov ecx, dword[esp+8]
					mov edx, dword[eax+16]
					cmp edx, dword[ecx-48]
					jge sigmaudio_processCommands_loop_play_sound_min_foreach_function_end
						mov dword[ecx-48], edx
						mov dword[ecx-52], eax
					sigmaudio_processCommands_loop_play_sound_min_foreach_function_end:
					ret
				
			sigmaudio_processCommands_loop_play_sound_slot_available:
			
			;init the other values
			mov eax, dword[ebp-8]
			mov dword[ebp-40], eax		;playback id
			mov ecx, dword[ebp-44]
			mov dword[ebp-36], ecx		;sound
			mov edx, dword[ebp-12]
			mov dword[ebp-32], edx		;loops left
			mov dword[ebp-28], 0		;current position
			mov eax, dword[ebp-4]
			mov dword[ebp-24], eax		;priority
			
			;add the playback to the playback vector
			lea eax, [ebp-40]
			push eax
			push playbacks
			call tsVector_pushBackBuffer
			jmp sigmaudio_processCommands_internal_loop_start
			
			sigmaudio_processCommands_loop_play_search_comparator:		;int comparator(Sound**, int soundId)
				mov ecx, dword[esp+4]
				mov ecx, dword[ecx]
				mov eax, dword[esp+8]
				sub eax, dword[ecx+16]
				ret
		
		sigmaudio_processCommands_loop_stop:
			;STOP SOUND
			;check if the playback is still playing
			push playbacks
			call tsVector_lock
			
			push dword[ebp-16]
			push sigmaudio_processCommands_loop_stop_search_comparator
			push playbacks
			call tsVector_search
			cmp eax, -1
			jne sigmaudio_processCommands_loop_stop_playback_found
				;release the lock
				push playbacks
				call tsVector_unlock
				;print error message
				push sigmaudio_processCommands_loop_stop_error_playback_not_found
				call my_printf
				jmp sigmaudio_processCommands_internal_loop_start			;continue
				sigmaudio_processCommands_loop_stop_error_playback_not_found db "sigmaudio_processCommands_internal: playback is not found",10,0
			sigmaudio_processCommands_loop_stop_playback_found:
			
			push eax
			push playbacks
			call tsVector_removeAt
			
			push playbacks
			call tsVector_unlock
			
			jmp sigmaudio_processCommands_internal_loop_start
			
			sigmaudio_processCommands_loop_stop_search_comparator:		;int comparator(Playback*, int playbackId)
				mov ecx, dword[esp+4]
				mov eax, dword[esp+8]
				sub eax, dword[ecx]
				ret
		
		sigmaudio_processCommands_loop_unload:
			;UNLOAD SOUND
			;check if the sound is still imported
			push imported_sounds
			call tsVector_lock
			
			push dword[ebp-16]			;sound id
			push sigmaudio_processCommands_loop_unload_search_comparator
			push imported_sounds
			call tsVector_search
			cmp eax, -1
			jne sigmaudio_processCommands_loop_unload_sound_imported
				;release the lock
				push imported_sounds
				call tsVector_unlock
				;print error message
				push sigmaudio_processCommands_loop_unload_error_sound_not_imported
				call my_printf
				jmp sigmaudio_processCommands_internal_loop_start			;continue
				sigmaudio_processCommands_loop_unload_error_sound_not_imported db "sigmaudio_processCommands_internal: sound is not imported",10,0
			sigmaudio_processCommands_loop_unload_sound_imported:
			push eax
			push imported_sounds
			call tsVector_at
			mov eax, dword[eax]
			mov dword[ebp-44], eax
			
			call tsVector_removeAt
			
			push imported_sounds
			call tsVector_unlock
			
			;stop every playback that belongs to the sound
			push playbacks
			call tsVector_lock
			add esp, 4
			
			sigmaudio_processCommands_loop_unload_loop_start:
				;search for playback
				mov eax, dword[ebp-44]
				push dword[eax+16]
				push sigmaudio_processCommands_loop_unload_comparator
				push playbacks
				call tsVector_search
				add esp, 12
				cmp eax, -1
				je sigmaudio_processCommands_loop_unload_loop_end
					;remove the playback
					push eax
					push playbacks
					call tsVector_removeAt
					add esp, 8
					jmp sigmaudio_processCommands_loop_unload_loop_start
			
				sigmaudio_processCommands_loop_unload_comparator: ;int thisnigga(Playback*, int soundId)
					mov ecx, dword[esp+4]
					mov eax, dword[ecx+4]
					mov eax, dword[eax+16]
					sub eax, dword[esp+8]
					ret
					
			sigmaudio_processCommands_loop_unload_loop_end:
			push playbacks
			call tsVector_unlock
			add esp, 4
			
			;unload the sound
			mov eax, dword[ebp-44]
			push eax
			push dword[eax+4]
			call my_free
			add esp, 4
			call my_free
			
			jmp sigmaudio_processCommands_internal_loop_start
			
			sigmaudio_processCommands_loop_unload_search_comparator:		;int comparator(Sound**, int soundId)
				mov ecx, dword[esp+4]
				mov ecx, dword[ecx]
				mov eax, dword[esp+8]
				sub eax, dword[ecx+16]
				ret
	
	sigmaudio_processCommands_internal_loop_end:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
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
			jmp sigmaudio_readWaveHeader_parseChunks_loop_end
		
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