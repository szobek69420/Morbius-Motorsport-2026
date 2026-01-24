[BITS 32]

;struct TerminalCommand{
;	int commandType;		0
;	int dataSizeInBytes;	4
;	void* data;
;}	12 bytes overall

section .rodata use32

	test_text db "data maduroaming",10,0

	TERMINAL_COMMAND_COUNT dd 2

	TERMINAL_COMMAND_NONE dd 0
	TERMINAL_COMMAND_WARP dd 1
	
	global TERMINAL_COMMAND_NONE
	global TERMINAL_COMMAND_WARP
	
	TERMINAL_COMMAND_BEGIN db "()",0
	TERMINAL_COMMAND_BEGIN_LENGTH dd 2
	
	
	TERMINAL_COMMAND_NAMES:			;indexed by the terminal command type
		dd TERMINAL_COMMAND_NAME_NONE
		dd TERMINAL_COMMAND_NAME_WARP
		
		TERMINAL_COMMAND_NAME_NONE db "NIGGASUS9000",0
		TERMINAL_COMMAND_NAME_WARP db "WARP",0
		
		
	;indexed by the terminal command type
	;constructors should have the following footprint:
	;TerminalCommand* constructor(const vector<char*>*)
	TERMINAL_COMMAND_CONSTRUCTORS:
		dd terminalInterpreter_createCommandNone
		dd terminalInterpreter_createCommandWarp
		
section .text use32


	;interprets the current line as a command and returns the interpreted data (even if it's an invalid command, in that case a command of type TERMINAL_COMMAND_NONE is returned)
	;the terminal command struct needs to be freed by the caller
	;TerminalCommand* terminalInterpreter_interpretLine(const char* line)
	global terminalInterpreter_interpretLine
	
	;void terminalInterpreter_executeWarp(TerminalCommand* warpCommand, ChunkManager4D* cm, Player* player)
	global terminalInterpreter_executeWarp
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_memcmp
	
	extern my_strlen
	extern my_ssplit
	
	extern cvt_trystr2float
	
	extern vector_init
	extern vector_destroy
	extern vector_at
	extern vector_size
	extern vector_for_each
	
	extern chunkManager4d_getHyperPlane
	
	extern aabb4d_getPosition
	
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
	
	
terminalInterpreter_executeWarp:
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
	
	
	
terminalInterpreter_createCommandWarp:
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
	jne terminalInterpreter_createCommandWarp_invalid
		mov ebx, 2
		terminalInterpreter_createCommandWarp_parse_loop_start:
			lea eax, [ebx+1]
			push eax
			push dword[ebp+12]
			call vector_at
			
			lea ecx, [ebp-16+4*ebx]
			push ecx
			push dword[eax]
			call cvt_trystr2float
			
			test eax, eax
			jnz terminalInterpreter_createCommandWarp_invalid		;unsuccessful parse
			
			add esp, 16
			dec ebx
			jns terminalInterpreter_createCommandWarp_parse_loop_start
			
		jmp terminalInterpreter_createCommandWarp_done
		
	terminalInterpreter_createCommandWarp_invalid:
		mov dword[ebp-20], 0
	
	terminalInterpreter_createCommandWarp_done:
	
	
	
	;fill up the command with sus
	test dword[ebp-20], 0xffffffff
	jnz terminalInterpreter_createCommandWarp_warp
	
	terminalInterpreter_createCommandWarp_none:
		push dword[ebp+12]
		call terminalInterpreter_createCommandNone
		mov dword[ebp-4], eax
		jmp terminalInterpreter_createCommandWarp_end
	
	terminalInterpreter_createCommandWarp_warp:
	
		;alloc space and init values
		push 12
		call my_malloc
		mov dword[ebp-4], eax
		
		mov ecx, dword[TERMINAL_COMMAND_WARP]
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
		
		jmp terminalInterpreter_createCommandWarp_end
	
	terminalInterpreter_createCommandWarp_end:	
	mov eax, dword[ebp-4]			;set return value
	
	mov esp, ebp
	pop ebx
	pop ebp
	ret