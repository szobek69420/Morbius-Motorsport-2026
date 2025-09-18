[BITS 32]

section .rodata use32
	global GAME_STATE_EXIT
	global GAME_STATE_INGAME
	global GAME_STATE_MENU
	global GAME_STATE_SETTINGS
	global GAME_STATE_INIT
	global GAME_STATE_DEINIT

	GAME_STATE_EXIT dd 0
	GAME_STATE_INGAME dd 1
	GAME_STATE_MENU dd 2
	GAME_STATE_SETTINGS dd 3
	GAME_STATE_INIT dd 4
	GAME_STATE_DEINIT dd 5
	
	;the stages that belong to the main menu phase
	MAIN_MENU_STATES:
	dd 2	;menu
	dd 3	;settings
	dd -1	;end-of-array
	
section .text use32

	global gameState_isMainMenu		;int gameState_isMainMenu(int state)	//state is z.B. dword[GAME_STATE_EXIT]
	
gameState_isMainMenu:
	mov edx, dword[esp+4]
	xor ecx, ecx			;index
	xor eax, eax
	
	gameState_isMainMenu_loop_start:
		cmp edx, dword[MAIN_MENU_STATES+4*ecx]
		jne gameState_isMainMenu_loop_continue
			;found it
			mov eax, 69
			jmp gameState_isMainMenu_end
		gameState_isMainMenu_loop_continue:
		inc ecx
		cmp dword[MAIN_MENU_STATES+4*ecx], -1
		jne gameState_isMainMenu_loop_start
		
	gameState_isMainMenu_end:
	ret