[BITS 32]

;struct TerminalCommand{
;	int commandType;		0
;	int dataSizeInBytes;	4
;	void* data;
;}	12 bytes overall

section .rodata use32

	TERMINAL_COMMAND_COUNT dd 2

	TERMINAL_COMMAND_NONE dd 0
	TERMINAL_COMMAND_WARP dd 1
	
	global TERMINAL_COMMAND_NONE
	global TERMINAL_COMMAND_WARP
	
	TERMINAL_COMMAND_BEGIN db "()",0
	TERMINAL_COMMAND_BEGIN_LENGTH db 2
	
	
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
		mov eax, dword[ebp+8]
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
			push dword[TERMINAL_COMMAND_NAMES]
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
	mov ebp, esp
	
	
	mov esp, ebp
	pop ebp
	ret