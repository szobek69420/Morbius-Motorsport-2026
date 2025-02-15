[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	ONE dd 1.0
	TWO dd 2.0
	THREE dd 3.0
	FOUR dd 4.0

	print_new_line db 10,0
	print_int db "%d ",0
	print_float_nl db "%f",10,0

	sus db "sus",0
	mega db "mega",0
	
	write_mode db "w",0
	file_name db "sigma.gyatt",0
	
	format db "sugus %f %s",0
	format2 db "%d",0
	
	float_number dd -69.42
	
section .bss use32
	stdout resb 4			;HANDLE for the standard output 
	
	buffer resb 1000
	file resb 4
	
	pwindow resb 4		;GLFWwindow*
	
	queue resb 20
	queue_buffer resb 8
	

section .text use32
	
	dll_import kernel32.dll, ExitProcess
	
	extern my_printf
	
	extern window_create
	extern window_destroy
	
	extern game_loop
	
	..start:
		push ebp
		mov ebp, esp
		
		finit
		
		
		;create window and opengl context
		push sus
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