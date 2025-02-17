[BITS 32]
section .rodata use32
	window_name db "Morbius Motorsport 2026",0
	
section .bss use32
	pwindow resb 4		;GLFWwindow*
	

section .text use32
	
	import ExitProcess kernel32.dll
	extern ExitProcess
	
	extern my_printf
	
	extern window_create
	extern window_destroy
	
	extern game_loop
	
	..start:
		push ebp
		mov ebp, esp
		
		finit
		
		
		;create window and opengl context
		push window_name
		call window_create
		mov dword[pwindow], eax
		add esp, 4
		
		cmp dword[pwindow], 0
		jne window_creation_successful
			jmp start_end
		window_creation_successful:
		
		;game loop
		push dword[pwindow]
		call game_loop
		add esp, 4
		
		
		;destroy window and opengl context
		push dword[pwindow]
		call window_destroy
		add esp, 4
		
		
		start_end:
		mov esp, ebp
		pop ebp
		
		push 0
		call [ExitProcess]