[BITS 32]
section .rodata use32
	window_name db "Morbius Motorsport 2026",0
	test_text db "bingus my beloved",10,0
	
	message_current_game_state_init db "main: current game state: init",10,0
	message_current_game_state_deinit db "main: current game state: deinit",10,0
	message_current_game_state_menu db "main: current game state: menu",10,0
	message_current_game_state_ingame db "main: current game state: ingame",10,0
	message_current_game_state_exit db "main: current game state: exit",10,0
	message_current_game_state_unknown db "main: current game state: unknown",10,0
	
section .bss use32
	pwindow resb 4		;GLFWwindow*

section .text use32
	
	import ExitProcess kernel32.dll
	extern ExitProcess
	
	extern my_printf
	
	extern window_create
	extern window_destroy
	
	extern gameLoop_main
	extern menuLoop_main
	extern GAME_STATE_EXIT
	extern GAME_STATE_INGAME
	extern GAME_STATE_MENU
	extern GAME_STATE_INIT
	extern GAME_STATE_DEINIT

	
	..start:
		push ebp
		mov ebp, esp
		
		sub esp, 4		;current game state		4
	
		mov eax, dword[GAME_STATE_INIT]
		mov dword[ebp-4], eax
		
		
		finit
		
		start_loop_start:
			mov eax, dword[ebp-4]
				cmp eax, dword[GAME_STATE_INIT]
				je start_loop_init
				cmp eax, dword[GAME_STATE_DEINIT]
				je start_loop_deinit
				cmp eax, dword[GAME_STATE_MENU]
				je start_loop_menu
				cmp eax, dword[GAME_STATE_INGAME]
				je start_loop_ingame
				cmp eax, dword[GAME_STATE_EXIT]
				je start_loop_exit
				jmp start_loop_unknown
			
			start_loop_init:
				push message_current_game_state_init
				call my_printf
				add esp, 4
			
				call main_init
				mov dword[ebp-4], eax
				
				jmp start_loop_continue
				
				
			start_loop_deinit:
				push message_current_game_state_deinit
				call my_printf
				add esp, 4
				
				call main_deinit
				mov dword[ebp-4], eax
				
				jmp start_loop_continue
				
				
			start_loop_menu:
				push message_current_game_state_menu
				call my_printf
				add esp, 4
				
				push dword[pwindow]
				call menuLoop_main
				mov dword[ebp-4], eax
				add esp, 4
				
				jmp start_loop_continue
				
				
			start_loop_ingame:
				push message_current_game_state_ingame
				call my_printf
				add esp, 4
			
				push dword[pwindow]
				call gameLoop_main
				mov dword[ebp-4], eax
				add esp, 4
				
				jmp start_loop_continue
				
				
			start_loop_exit:
				push message_current_game_state_exit
				call my_printf
				add esp, 4
				
				jmp start_loop_end
				
				
			start_loop_unknown:
				push message_current_game_state_unknown
				call my_printf
				add esp, 4
				
				mov eax, dword[GAME_STATE_EXIT]
				mov dword[ebp-4], eax
				
				jmp start_loop_continue
			
			
			start_loop_continue:
			jmp start_loop_start
		start_loop_end:
		
		
		start_end:
		mov esp, ebp
		pop ebp
		
		push 0
		call [ExitProcess]
		
;internal functions --------------------------------
;int main_init()	//returns a game state
main_init:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;return value
	
	mov eax, dword[GAME_STATE_MENU]
	mov dword[ebp-4], eax
	
	;create window and opengl context
	push window_name
	call window_create
	mov dword[pwindow], eax
	add esp, 4
	
	cmp dword[pwindow], 0
	jne main_init_windowCreationSuccessful
		mov eax, dword[GAME_STATE_EXIT]
		mov dword[ebp-4], eax
	main_init_windowCreationSuccessful:
		
	;initialize the input system
	push dword[pwindow]
	call main_initializeInput
	add esp, 4
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
		
		
;int main_deinit()		//returns a game state
main_deinit:
	push ebp
	mov ebp, esp
	
	;destroy window and opengl context
	push dword[pwindow]
	call window_destroy
	mov dword[pwindow], 0
	add esp, 4
	
	;set return value
	mov eax, dword[GAME_STATE_EXIT]
	
	mov esp, ebp
	pop ebp
	ret
		
		
		
extern input_init
extern input_keyCallback
extern input_mouseButtonCallback
extern input_mouseMoveCallback
extern input_mouseScrollCallback
extern glfwSetKeyCallback
extern glfwSetMouseButtonCallback
extern glfwSetCursorPosCallback
extern glfwSetScrollCallback
		
;void main_initializeInput(GLFWwindow* pwindow)
main_initializeInput:
	push ebp
	mov ebp, esp
	
	call input_init
	
	
	push input_keyCallback
	push dword[ebp+8]
	call [glfwSetKeyCallback]
	
	push input_mouseButtonCallback
	push dword[ebp+8]
	call [glfwSetMouseButtonCallback]
	
	push input_mouseMoveCallback
	push dword[ebp+8]
	call [glfwSetCursorPosCallback]
	
	push input_mouseScrollCallback
	push dword[ebp+8]
	call [glfwSetScrollCallback]
	
	mov esp, ebp
	pop ebp
	ret