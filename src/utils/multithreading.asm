[BITS 32]

;layout

;struct Thread{
;	void* threadHandle;
;	int threadID;
;}			8 bytes overall

;struct Mutex{
;	void* mutexHandle;
;}		4 bytes overall

;struct Semaphore{
;	void* semaphoreHandle;
;}		4 bytes overall

;struct CriticalSection{
;	40 bytes of idk;
;}		40 bytes overall

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro


CREATE_SUSPENDED equ 0x00000004
CREATE_NOT_SUSPENDED equ 0
WAIT_INFINITE equ 0xffffffff

section .text use32

	;returns 0 if there WAS an error
	;if startImmediately is false, the thread can be started with thread_resume
	global thread_create			;Thread* thread_create(void* functionAddress, void* params, int startImmediately)
	
	;returns 0 if there were no problems
	global thread_destroy			;int thread_destroy(Thread* thread)
	
	;returns 0 if there were no problems (not zero on timeout)
	;if the waiting was successful, thread_destroy is also called
	;timeoutInMilliseconds is -1 if the waiting time is unlimited
	global thread_join				;int thread_join(Thread* thread, int timeoutInMilliseconds)
	
	
	;returns 0 if there were no problems
	global thread_resume			;int thread_resume(Thread* thread)
	
	;returns 0 if there were no problems
	global thread_suspend			;int thread_suspend(Thread* thread)
	
	;suspends the execution for the given time on the current thread
	global thread_sleep				;void thread_sleep(int milliseconds)
	
	
	;returns 0 if there WAS an error
	global mutex_create				;Mutex* mutex_create()
	
	;returns 0 if there were no problems
	global mutex_destroy			;int mutex_destroy(Mutex* mutex)
	
	;returns 0 if there were no problems (timeout counts as a problem)
	;timeoutInMilliseconds is -1 if the waiting time is unlimited
	global mutex_lock				;int mutex_lock(Mutex* mutex, int timeoutInMilliseconds)
	
	;returns 0 if there were no problems
	global mutex_unlock				;int mutex_unlock(Mutex* mutex)
	
	
	
	
	;returns 0 if there WAS an error
	global semaphore_create				;Semaphore* semaphore_create(int maxCount)
	
	;returns 0 if there were no problems
	global semaphore_destroy			;int semaphore_destroy(Semaphore* semaphore)
	
	;returns 0 if there were no problems (timeout counts as a problem)
	;timeoutInMilliseconds is -1 if the waiting time is unlimited
	global semaphore_lock				;int semaphore_lock(Semaphore* semaphore, int timeoutInMilliseconds)
	
	;returns 0 if there were no problems
	global semaphore_unlock				;int semaphore_unlock(Semaphore* semaphore)
	
	;the WinAPI docs say that this can not fail, which I would take as a challenge
	;CriticalSection* criticalSection_create()
	global criticalSection_create
	;void criticalSection_destroy(CriticalSection*)
	global criticalSection_destroy
	;void criticalSection_lock(CriticalSection*)
	global criticalSection_lock
	;tries to enter a critical section without blocking
	;returns non-zero, if the thread managed to get into the critical section or it already owned it
	;returns zero on fail
	;int criticalSection_tryLock(CriticalSection*)
	global criticalSection_tryLock
	;void criticalSection_unlock(CriticalSection*)
	global criticalSection_unlock
	
	dll_import kernel32.dll, CreateThread
	dll_import kernel32.dll, ResumeThread
	dll_import kernel32.dll, SuspendThread
	dll_import kernel32.dll, CloseHandle
	dll_import kernel32.dll, WaitForSingleObject
	dll_import kernel32.dll, Sleep
	
	dll_import kernel32.dll, CreateMutexA
	dll_import kernel32.dll, ReleaseMutex
	
	dll_import kernel32.dll, CreateSemaphoreA
	dll_import kernel32.dll, ReleaseSemaphore
	
	dll_import kernel32.dll, InitializeCriticalSection
	dll_import kernel32.dll, DeleteCriticalSection
	dll_import kernel32.dll, EnterCriticalSection
	dll_import kernel32.dll, TryEnterCriticalSection
	dll_import kernel32.dll, LeaveCriticalSection
	
	extern my_malloc
	extern my_free
	
	extern my_printf
	
thread_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;Thread*
	
	;alloc thread
	push 8
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	test eax, eax
	jz thread_create_end
	
	;create thread
	mov eax, dword[ebp-4]
	add eax, 4
	push eax			;&threadID
	push CREATE_NOT_SUSPENDED
	mov eax, dword[ebp+16]
	test eax, eax
	jnz thread_start_immediately
		mov dword[esp], CREATE_SUSPENDED
	thread_start_immediately:
	push dword[ebp+12]		;params
	push dword[ebp+8]		;start address
	push 0					;default stack size
	push 0					;default security attributes
	call [CreateThread]
	mov ecx, dword[ebp-4]
	mov dword[ecx], eax		;save handle
	
	test eax, eax
	jnz thread_create_successful
		push dword[ebp-4]
		call my_free
		xor eax, eax
		jmp thread_create_end
		
	thread_create_successful:
	
	mov eax, dword[ebp-4]		;set return value
	
	thread_create_end:
	mov esp, ebp
	pop ebp
	ret
	
	
thread_destroy:
	push ebp
	mov ebp, esp
	
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call [CloseHandle]
	
	;check if it was successful
	test eax, eax
	jnz thread_destroy_successful
		mov eax, 69
		jmp thread_destroy_end
	thread_destroy_successful:
	
	push dword[ebp+8]
	call my_free
	xor eax, eax
	
	thread_destroy_end:
	mov esp, ebp
	pop ebp
	ret
	
	
thread_join:
	push ebp
	mov ebp, esp
	
	push WAIT_INFINITE
	mov eax, dword[ebp+12]
	cmp eax, -1
	je thread_join_wait_infinite
		mov dword[esp], eax
	thread_join_wait_infinite:
	
	mov eax, dword[ebp+8]
	push dword[eax]
	
	call [WaitForSingleObject]
	
	;check if the waiting was successful
	test eax, eax
	jz thread_join_wait_successful
		mov eax, 69
		jmp thread_join_end
		
	thread_join_wait_successful:
	
	
	push dword[ebp+8]
	call thread_destroy
	
	thread_join_end:
	mov esp, ebp
	pop ebp
	ret


thread_resume:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call [ResumeThread]
	cmp eax, -1
	je thread_resume_end
	
	xor eax, eax
	
	thread_resume_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
thread_suspend:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call [SuspendThread]
	cmp eax, -1
	je thread_suspend_end
	
	xor eax, eax
	
	thread_suspend_end:
	mov esp, ebp
	pop ebp
	ret
	
	
thread_sleep:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [Sleep]
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
mutex_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;mutex*
	
	;alloc space for mutex
	push 4
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	test eax, eax
	jnz mutex_create_alloc_successful
		xor eax, eax
		jmp mutex_create_end
	
	mutex_create_alloc_successful:
	
	push 0			;unnamed mutex
	push 0			;no initial owner
	push 0			;default security attributes
	call [CreateMutexA]
	mov ecx, dword[ebp-4]
	mov dword[ecx], eax
	test eax, eax
	jnz mutex_create_creation_successful
		push dword[ebp-4]
		call my_free
		xor eax, eax
		jmp mutex_create_end
		
	mutex_create_creation_successful:
	
	mov eax, dword[ebp-4]
	
	mutex_create_end:
	mov esp, ebp
	pop ebp
	ret
	
	
mutex_destroy:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call [CloseHandle]
	
	;check if it was successful
	test eax, eax
	jnz mutex_destroy_successful
		mov eax, 69
		jmp mutex_destroy_end
	mutex_destroy_successful:
	
	push dword[ebp+8]
	call my_free
	xor eax, eax
	
	mutex_destroy_end:
	mov esp, ebp
	pop ebp
	ret
	
	
mutex_lock:
	push ebp
	mov ebp, esp
	
	push WAIT_INFINITE
	mov eax, dword[ebp+12]
	cmp eax, -1
	je mutex_lock_wait_infinite
		mov dword[esp], eax
	mutex_lock_wait_infinite:
	
	mov eax, dword[ebp+8]
	push dword[eax]
	
	call [WaitForSingleObject]
	
	;check if the waiting was successful
	test eax, eax
	jz mutex_lock_wait_successful
		mov eax, 69
		jmp mutex_lock_end
		
	mutex_lock_wait_successful:
	
	mutex_lock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
mutex_unlock:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call [ReleaseMutex]
	test eax, eax
	jnz mutex_unlock_successful
		mov eax, 69
		jmp mutex_unlock_end
	mutex_unlock_successful:
	xor eax, eax
	
	mutex_unlock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
semaphore_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;semaphore*
	
	;alloc space for semaphore
	push 4
	call my_malloc
	mov dword[ebp-4], eax
	add esp, 4
	
	test eax, eax
	jnz semaphore_create_alloc_successful
		xor eax, eax
		jmp semaphore_create_end
	
	semaphore_create_alloc_successful:
	
	push 0					;unnamed semaphore
	push dword[ebp+8]		;maxCount
	push dword[ebp+8]		;initial count
	push 0					;default security attributes
	call [CreateSemaphoreA]
	mov ecx, dword[ebp-4]
	mov dword[ecx], eax
	test eax, eax
	jnz semaphore_create_creation_successful
		push dword[ebp-4]
		call my_free
		xor eax, eax
		jmp semaphore_create_end
		
	semaphore_create_creation_successful:
	
	mov eax, dword[ebp-4]
	
	semaphore_create_end:
	mov esp, ebp
	pop ebp
	ret
	
	
semaphore_destroy:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call [CloseHandle]
	
	;check if it was successful
	test eax, eax
	jnz semaphore_destroy_successful
		mov eax, 69
		jmp semaphore_destroy_end
	semaphore_destroy_successful:
	
	push dword[ebp+8]
	call my_free
	xor eax, eax
	
	semaphore_destroy_end:
	mov esp, ebp
	pop ebp
	ret
	
	
semaphore_lock:
	push ebp
	mov ebp, esp
	
	push WAIT_INFINITE
	mov eax, dword[ebp+12]
	cmp eax, -1
	je semaphore_lock_wait_infinite
		mov dword[esp], eax
	semaphore_lock_wait_infinite:
	
	mov eax, dword[ebp+8]
	push dword[eax]
	
	call [WaitForSingleObject]
	
	;check if the waiting was successful
	test eax, eax
	jz semaphore_lock_wait_successful
		mov eax, 69
		jmp semaphore_lock_end
		
	semaphore_lock_wait_successful:
	
	semaphore_lock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
semaphore_unlock:
	push ebp
	mov ebp, esp
	
	push 0						;dont care about the previous count
	push 1						;release only 1
	mov eax, dword[ebp+8]
	push dword[eax]				;handle
	call [ReleaseSemaphore]
	test eax, eax
	jnz semaphore_unlock_successful
		mov eax, 69
		jmp semaphore_unlock_end
	semaphore_unlock_successful:
	xor eax, eax
	
	semaphore_unlock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
criticalSection_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;critical section		4
	
	;alloc space
	push 40
	call my_malloc
	mov dword[ebp-4], eax
	
	;init critical section
	push dword[ebp-4]
	call [InitializeCriticalSection]
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
criticalSection_destroy:
	push ebp
	mov ebp, esp
	
	;deinit critical section
	push dword[ebp+8]
	call [DeleteCriticalSection]
	
	;dealloc space
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
criticalSection_lock:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [EnterCriticalSection]
	
	mov esp, ebp
	pop ebp
	ret
	
	
criticalSection_tryLock:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [TryEnterCriticalSection]
	
	mov esp, ebp
	pop ebp
	ret
	
	
criticalSection_unlock:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [LeaveCriticalSection]
	
	mov esp, ebp
	pop ebp
	ret