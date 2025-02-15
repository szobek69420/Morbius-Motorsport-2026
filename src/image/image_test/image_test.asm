[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	image_path db "image24.bmp",0

	print_int db "%d ",0
	print_new_line db 10,0
	

section .bss use32
	image_width resb 4
	image_height resb 4
	image_bitsPerPixel resb 4
	
	image_buffer resb 1000

section .text use32

	dll_import kernel32.dll, ExitProcess

	extern image_loadBMP
	extern image_flip
	extern my_printf

..start:
	push ebp
	mov ebp, esp
	
	push 69
	call image_flip
	add esp, 4

	push image_bitsPerPixel
	push image_height
	push image_width
	push image_buffer
	push image_path
	call image_loadBMP
	add esp, 20
	
	mov ebx, image_buffer
	mov esi, dword[image_height]
	test_outer_loop_start:
		mov edi, dword[image_width]
		test_inner_loop_start:
			sub esp, 4
			push print_int
		
			xor eax, eax
			mov al, byte[ebx]
			mov dword[esp+4], eax
			call my_printf
			
			xor eax, eax
			mov al, byte[ebx+1]
			mov dword[esp+4], eax
			call my_printf
			
			xor eax, eax
			mov al, byte[ebx+2]
			mov dword[esp+4], eax
			call my_printf
			
			add esp, 8

			add ebx, 3
			dec edi
			test edi, edi
			jnz test_inner_loop_start
	
		push print_new_line
		call my_printf
		add esp, 4
		
		dec esi
		test esi, esi
		jnz test_outer_loop_start

	mov esp, ebp
	pop ebp
	
	push 0
	call [ExitProcess]