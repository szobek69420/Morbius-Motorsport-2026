[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	message1 db "sugus1",10,0
	message2 db "sugus2",10,0
	
section .bss use32
	pthread resb 4
	psemaphore resb 4
	
section .text use32
	
	dll_import kernel32.dll, ExitProcess
	
	extern my_printf
	extern thread_create
	extern thread_join
	extern thread_resume
	extern thread_suspend
	
	extern semaphore_create
	extern semaphore_destroy
	extern semaphore_lock
	extern semaphore_unlock
	
	..start:
		push ebp
		mov ebp, esp
		
		finit
		
		;init thread
		push 0		;dont start immediately
		push 0
		push test_thread_func1
		call thread_create
		mov dword[pthread], eax
		add esp, 12
		
		;init semaphore
		push 1
		call semaphore_create
		mov dword[psemaphore], eax
		add esp, 4
		
		;start thread
		push dword[pthread]
		call thread_resume
		;call thread_suspend
		add esp, 4
		
		call test_thread_func2
		
		push -1
		push dword[pthread]
		call thread_join
		add esp, 8
		
		push dword[psemaphore]
		call semaphore_destroy
		add esp, 4
		
		start_end:
		mov esp, ebp
		pop ebp
		
		push 0
		call [ExitProcess]
		
		
	test_thread_func1:
		push ebp
		mov ebp, esp
		
		mov eax, 10
		test_thread_func1_loop_start:
			push eax		;save eax
			
			push -1
			push dword[psemaphore]
			call semaphore_lock
			add esp, 8
			
			push message1
			call my_printf
			add esp, 4
			
			push dword[psemaphore]
			call semaphore_unlock
			add esp, 4
			
			pop eax			;restore eax
			
			dec eax
			test eax, eax
			jnz test_thread_func1_loop_start
		
		mov esp, ebp
		pop ebp
		ret
		
		
	test_thread_func2:
		push ebp
		mov ebp, esp
		
		mov eax, 10
		test_thread_func2_loop_start:
			push eax		;save eax
			
			push -1
			push dword[psemaphore]
			call semaphore_lock
			add esp, 8
			
			push message2
			call my_printf
			add esp, 4
			
			push dword[psemaphore]
			call semaphore_unlock
			add esp, 4
			
			pop eax			;restore eax
			
			dec eax
			test eax, eax
			jnz test_thread_func2_loop_start
		
		mov esp, ebp
		pop ebp
		ret