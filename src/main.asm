[BITS 32]
section .rodata use32
	window_name db "Morbius Motorsport 2026",0
	test_text db "bingus my beloved",10,0
	
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
		
		;initialize the input system
		push dword[pwindow]
		call main_initializeInput
		add esp, 4
		
		;menu loop
		push dword[pwindow]
		call menuLoop_main
		add esp, 4
		
		;game loop
		push dword[pwindow]
		call gameLoop_main
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