[BITS 32]

;struct TerminalCommand{
;	int commandType;		0
;	int dataSizeInBytes;	4
;	void* data;
;}	12 bytes overall

section .rodata use32

	test_text db "data maduroaming",10,0


	TERMINAL_COMMAND_NONE dd 0
	TERMINAL_COMMAND_WARP3 dd 1
	TERMINAL_COMMAND_WARP4 dd 2
	TERMINAL_COMMAND_TIME dd 3
	TERMINAL_COMMAND_COUNT dd 4		;should be after the last
	
	global TERMINAL_COMMAND_NONE
	global TERMINAL_COMMAND_WARP3
	global TERMINAL_COMMAND_WARP4
	global TERMINAL_COMMAND_TIME
	
	TERMINAL_COMMAND_BEGIN db ";",0
	TERMINAL_COMMAND_BEGIN_LENGTH dd 1
	
	
	TERMINAL_COMMAND_NAMES:			;indexed by the terminal command type
		dd TERMINAL_COMMAND_NAME_NONE
		dd TERMINAL_COMMAND_NAME_WARP3
		dd TERMINAL_COMMAND_NAME_WARP4
		dd TERMINAL_COMMAND_NAME_TIME
		
		TERMINAL_COMMAND_NAME_NONE db "NIGGASUS9000",0
		TERMINAL_COMMAND_NAME_WARP3 db "WARP3",0
		TERMINAL_COMMAND_NAME_WARP4 db "WARP4",0
		TERMINAL_COMMAND_NAME_TIME db "TIME",0
		
		
	;indexed by the terminal command type
	;constructors should have the following footprint:
	;TerminalCommand* constructor(const vector<char*>*)
	TERMINAL_COMMAND_CONSTRUCTORS:
		dd terminalInterpreter_createCommandNone
		dd terminalInterpreter_createCommandWarp3
		dd terminalInterpreter_createCommandWarp4
		dd terminalInterpreter_createCommandTime
		
section .text use32


	;interprets the current line as a command and returns the interpreted data (even if it's an invalid command, in that case a command of type TERMINAL_COMMAND_NONE is returned)
	;the terminal command struct needs to be freed by the caller
	;TerminalCommand* terminalInterpreter_interpretLine(const char* line)
	global terminalInterpreter_interpretLine
	
	;void terminalInterpreter_executeWarp3(TerminalCommand* warp3Command, ChunkManager4D* cm, Player* player)
	global terminalInterpreter_executeWarp3
	
	;void terminalInterpreter_executeWarp4(TerminalCommand* warp4Command, ChunkManager4D* cm, Player* player)
	global terminalInterpreter_executeWarp4
	
	;void terminalInterpreter_executeTime(TerminalCommand* timeCommand, float* normalizedTimeBuffer)
	global terminalInterpreter_executeTime
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcmp
	
	extern my_strlen
	extern my_ssplit
	
	extern cvt_trystr2int
	extern cvt_trystr2float
	
	extern vector_init
	extern vector_destroy
	extern vector_at
	extern vector_size
	extern vector_for_each
	
	extern chunkManager4d_getHyperPlane
	
	extern aabb4d_getPosition
	
	extern hyperPlane_positionTo3d
	extern hyperPlane_positionTo4d
	
	extern player_getCollider
	
	
terminalInterpreter_interpretLine:	
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16			;split string buffer		16
	sub esp, 4			;return value				20
	
	;init the buffer
	lea eax, [ebp-16]
	push 4
	push eax
	call vector_init


	
	;check if the command starts with a command
	push dword[TERMINAL_COMMAND_BEGIN_LENGTH]
	push TERMINAL_COMMAND_BEGIN
	push dword[ebp+20]
	call my_memcmp
	test eax, eax
	jnz terminalInterpreter_interpretLine_create_none
	jmp terminalInterpreter_interpretLine_create_else
	
	terminalInterpreter_interpretLine_create_none:
		lea eax, [ebp-16]
		push eax
		call terminalInterpreter_createCommandNone
		mov dword[ebp-20], eax
		jmp terminalInterpreter_interpretLine_create_done
		
	terminalInterpreter_interpretLine_create_else:
		;split the string
		mov eax, dword[ebp+20]
		add eax, dword[TERMINAL_COMMAND_BEGIN_LENGTH]
		lea ecx, [ebp-16]
		mov dl, ' '
		movzx edx, dl
		push ecx
		push edx
		push eax
		call my_ssplit
		
		
		;check if the buffer is empty
		cmp dword[ebp-16], 0
		jle terminalInterpreter_interpretLine_create_none
		
		;search for the constructor
		xor ebx, ebx	;index in ebx
		terminalInterpreter_interpretCommand_create_else_loop_start:
			lea eax, [ebp-16]
			push 0
			push eax
			call vector_at
			add esp, 8
			mov esi, dword[eax]	;first string in esi
			
			push dword[TERMINAL_COMMAND_NAMES+4*ebx]
			call my_strlen
			add esp, 4
			
			push eax
			push dword[TERMINAL_COMMAND_NAMES+4*ebx]
			push esi
			call my_memcmp
			add esp, 12
			
			test eax, eax
			jnz terminalInterpreter_interpretCommand_create_else_loop_continue
				;command found
				lea eax, [ebp-16]
				push eax
				call dword[TERMINAL_COMMAND_CONSTRUCTORS+4*ebx]
				mov dword[ebp-20], eax
				
				jmp terminalInterpreter_interpretLine_create_done
		
			terminalInterpreter_interpretCommand_create_else_loop_continue:
			inc ebx
			cmp ebx, dword[TERMINAL_COMMAND_COUNT]
			jl terminalInterpreter_interpretCommand_create_else_loop_start
			
			;command not found, create empty
			jmp terminalInterpreter_interpretLine_create_none
	
	terminalInterpreter_interpretLine_create_done:
	
	;destroy the split buffer
	lea eax, [ebp-16]
	push 0
	push terminalInterpreter_interpretLine_destroy_helper
	push eax
	call vector_for_each
	call vector_destroy
	jmp terminalInterpreter_interpretLine_destroy_done
	
	terminalInterpreter_interpretLine_destroy_helper:
		push ebp
		mov ebp, esp
		mov eax, dword[ebp+8]
		push dword[eax]
		call my_free
		mov esp, ebp
		pop ebp
		ret
		
	terminalInterpreter_interpretLine_destroy_done:
	
	;set return value
	mov eax, dword[ebp-20]
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
terminalInterpreter_executeWarp3:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;player aabb		4
	sub esp, 4		;cm hyperplane		8
	sub esp, 16		;position in 4d		24
	
	;get player collider
	push dword[ebp+16]
	call player_getCollider
	mov dword[ebp-4], eax
	
	;get the hyperplane
	push dword[ebp+12]
	call chunkManager4d_getHyperPlane
	mov dword[ebp-8], eax
	
	;calculate the 4d position
	mov eax, dword[ebp+8]
	lea ecx, [ebp-24]
	push ecx
	push dword[eax+8]
	push dword[ebp-8]
	call hyperPlane_positionTo4d
	
	;set the player's position
	push dword[ebp-4]
	call aabb4d_getPosition
	mov ecx, dword[ebp-24]
	mov dword[eax], ecx
	mov edx, dword[ebp-20]
	mov dword[eax+4], edx
	mov ecx, dword[ebp-16]
	mov dword[eax+8], ecx
	mov edx, dword[ebp-12]
	mov dword[eax+12], edx
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
terminalInterpreter_executeWarp4:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;player aabb		4
	sub esp, 4		;cm hyperplane		8
	sub esp, 16		;position in 4d		24
	
	;copy the data part
	mov eax, dword[ebp+8]
	mov eax, dword[eax+8]
	mov ecx, dword[eax]
	mov dword[ebp-24], ecx
	mov edx, dword[eax+4]
	mov dword[ebp-20], edx
	mov ecx, dword[eax+8]
	mov dword[ebp-16], ecx
	mov edx, dword[eax+12]
	mov dword[ebp-12], edx
	
	
	;get player collider
	push dword[ebp+16]
	call player_getCollider
	mov dword[ebp-4], eax
	
	;get the hyperplane
	push dword[ebp+12]
	call chunkManager4d_getHyperPlane
	mov dword[ebp-8], eax
	
	;calculate the projection onto the plane
	lea ecx, [ebp-24]
	push ecx
	push ecx
	push dword[ebp-8]
	call hyperPlane_positionTo3d
	call hyperPlane_positionTo4d
	
	;set the player's position
	push dword[ebp-4]
	call aabb4d_getPosition
	mov ecx, dword[ebp-24]
	mov dword[eax], ecx
	mov edx, dword[ebp-20]
	mov dword[eax+4], edx
	mov ecx, dword[ebp-16]
	mov dword[eax+8], ecx
	mov edx, dword[ebp-12]
	mov dword[eax+12], edx
	
	mov esp, ebp
	pop ebp
	ret
	
	
terminalInterpreter_executeTime:
	push ebp
	mov ebp, esp
	
	;calculate normalized time
	mov eax, dword[ebp+8]
	mov eax, dword[eax+8]
	mov eax, dword[eax]
	xor edx, edx
	mov ecx, 2400
	idiv ecx
	test edx, 0x80000000
	jz terminalInterpreter_executeTime_non_negative
		add edx, 2400
	terminalInterpreter_executeTime_non_negative:
	
	cvtsi2ss xmm0, edx
	mulss xmm0, dword[ONE_PER_2400]
	mov eax, dword[ebp+12]
	movss dword[eax], xmm0
	
	mov esp, ebp
	pop ebp
	ret
	ONE_PER_2400 dd 0.0004166666
	
	
;internal functinos	-------------------------------------
	
terminalInterpreter_createCommandNone:
	push ebp
	mov ebp, esp
	
	
	push 12
	call my_malloc
	
	mov ecx, dword[TERMINAL_COMMAND_NONE]
	mov dword[eax], ecx
	mov dword[eax+4], 0
	mov dword[eax+8], 0
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
;warp requires 3 coordinates as argument
terminalInterpreter_createCommandWarp3:
	push ebp
	push ebx
	mov ebp, esp
	
	sub esp, 4		;command		4
	sub esp, 4		;z pos			8
	sub esp, 4		;y pos			12
	sub esp, 4		;x pos			16
	sub esp, 4		;is valid warp	20
	
	mov dword[ebp-20], 69
	
	
	;parse the coordinates if possible
	push dword[ebp+12]
	call vector_size
	cmp eax, 4			;command plus 3 positions
	jne terminalInterpreter_createCommandWarp3_invalid
		mov ebx, 2
		terminalInterpreter_createCommandWarp3_parse_loop_start:
			lea eax, [ebx+1]
			push eax
			push dword[ebp+12]
			call vector_at
			
			lea ecx, [ebp-16+4*ebx]
			push ecx
			push dword[eax]
			call cvt_trystr2float
			
			test eax, eax
			jnz terminalInterpreter_createCommandWarp3_invalid		;unsuccessful parse
			
			add esp, 16
			dec ebx
			jns terminalInterpreter_createCommandWarp3_parse_loop_start
			
		jmp terminalInterpreter_createCommandWarp3_done
		
	terminalInterpreter_createCommandWarp3_invalid:
		mov dword[ebp-20], 0
	
	terminalInterpreter_createCommandWarp3_done:
	
	
	
	;fill up the command with sus
	test dword[ebp-20], 0xffffffff
	jnz terminalInterpreter_createCommandWarp3_warp
	
	terminalInterpreter_createCommandWarp3_none:
		push dword[ebp+12]
		call terminalInterpreter_createCommandNone
		mov dword[ebp-4], eax
		jmp terminalInterpreter_createCommandWarp3_end
	
	terminalInterpreter_createCommandWarp3_warp:
	
		;alloc space and init values
		push 12
		call my_malloc
		mov dword[ebp-4], eax
		
		mov ecx, dword[TERMINAL_COMMAND_WARP3]
		mov dword[eax], ecx
		mov dword[eax+4], 12
		
		;alloc data block and fill it
		push 12
		call my_malloc
		mov ecx, dword[ebp-4]
		mov dword[ecx+8], eax
		
		mov edx, dword[ebp-16]
		mov dword[eax], edx
		mov ecx, dword[ebp-12]
		mov dword[eax+4], ecx
		mov edx, dword[ebp-8]
		mov dword[eax+8], edx
		
		jmp terminalInterpreter_createCommandWarp3_end
	
	terminalInterpreter_createCommandWarp3_end:	
	mov eax, dword[ebp-4]			;set return value
	
	mov esp, ebp
	pop ebx
	pop ebp
	ret
	
	
;requires 4 float arguments
terminalInterpreter_createCommandWarp4:
	push ebp
	push ebx
	mov ebp, esp
	
	sub esp, 4		;command			4
	sub esp, 16		;coords				20
	
	;check if there are the right number of arguments
	mov eax, dword[ebp+12]
	cmp dword[eax], 5
	jne terminalInterpreter_createCommandWarp4_none
	
	;parse the arguments
	mov ebx, 4			;index in ebx
	terminalInterpreter_createCommandWarp4_parse_loop_start:
		push ebx
		push dword[ebp+12]
		call vector_at
		
		lea ecx, [ebp-24+4*ebx]
		push ecx
		push dword[eax]
		call cvt_trystr2float
		test eax, eax
		jnz terminalInterpreter_createCommandWarp4_none		;parse failed
		
		add esp, 16
		
		dec ebx
		jnz terminalInterpreter_createCommandWarp4_parse_loop_start
		
		
	terminalInterpreter_createCommandWarp4_warp:
		;alloc update
		push 12
		call my_malloc
		mov dword[ebp-4], eax
		
		mov ecx, dword[TERMINAL_COMMAND_WARP4]
		mov dword[eax], ecx
		mov dword[eax+4], 16
		
		;alloc the data part
		push 16
		call my_malloc
		mov ecx, dword[ebp-4]
		mov dword[ecx+8], eax
		
		mov ecx, dword[ebp-20]
		mov dword[eax], ecx
		mov edx, dword[ebp-16]
		mov dword[eax+4], edx
		mov ecx, dword[ebp-12]
		mov dword[eax+8], ecx
		mov edx, dword[ebp-8]
		mov dword[eax+12], edx
		
		jmp terminalInterpreter_createCommandWarp4_end
		
	
	terminalInterpreter_createCommandWarp4_none:
		push dword[ebp+12]
		call terminalInterpreter_createCommandNone
		mov dword[ebp-4], eax
		jmp terminalInterpreter_createCommandWarp4_end
	
	terminalInterpreter_createCommandWarp4_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebx
	pop ebp
	ret
	

;time requires an integer argument where 0 and 2400 are dawn
terminalInterpreter_createCommandTime:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;command		4
	sub esp, 4			;time			8
	
	;check if the count is kosher
	mov eax, dword[ebp+8]
	cmp dword[eax], 2
	jne terminalInterpreter_createCommandTime_none
	
		;check if the argument is kosher
		mov eax, dword[ebp+8]
		mov eax, dword[eax+12]
		lea ecx, [ebp-8]
		push ecx
		push dword[eax+4]
		call cvt_trystr2int
		test eax, eax
		jnz terminalInterpreter_createCommandTime_none
		
		;create the command
		push 12
		call my_malloc
		mov dword[ebp-4], eax
		
		mov ecx, dword[TERMINAL_COMMAND_TIME]
		mov dword[eax], ecx
		mov dword[eax+4], 4
		
		push 4
		call my_malloc
		mov ecx, dword[ebp-4]
		mov dword[ecx+8], eax
		
		mov edx, dword[ebp-8]
		mov dword[eax], edx
		
		jmp terminalInterpreter_createCommandTime_end
	
	
	terminalInterpreter_createCommandTime_none:
		push dword[ebp+8]
		call terminalInterpreter_createCommandNone
		mov dword[ebp-4], eax
		
		jmp terminalInterpreter_createCommandTime_end
	
	terminalInterpreter_createCommandTime_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebp
	ret