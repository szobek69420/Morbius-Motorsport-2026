[BITS 32]

;this is a wrapper for the critical section implementation
;in the case of the thread safe containers, they are used a lot like this:
;1. lock cs
;2. do operation which includes lock cs and unlock cs operations
;3. unlock cs
;the operations <1,2,3> should be atomic together, but the first operation to call unlock cs will let go of the cs

;struct ContainerCriticalSection{
;	CriticalSection* sex;			0
;	int isLockedIn;					4		//is under a special lock
;}		8 bytes overall

section .text use32

	global containerCriticalSection_create		;ContainerCriticalSection* ccs_create()
	global containerCriticalSection_destroy		;void ccs_destroy(ContainerCriticalSection* sex)
	
	;returns non-zero on success
	;if the ccs is already under special lock in, the lock operation can still succeed, but won't override the special lock in
	;int ccs_tryLock(ContainerCriticalSection* sex)
	global containerCriticalSection_tryLock
	
	;if the ccs is already under special lock in, the lock operation can still succeed, but won't override the special lock in
	;void ccs_lock(ContainerCriticalSection* sex)
	global containerCriticalSection_lock
	
	;returns 0 on success
	;if the ccs is already under special lock in, the unlock operation will fail
	;int ccs_unlock(ContainerCriticalSection* sex)
	global containerCriticalSection_unlock
	
	
	global containerCriticalSection_trySpecialLock		;int ccs_trySpecialLock(ContainerCriticalSection* sex)	//returns non-zero on success
	global containerCriticalSection_specialLock			;void ccs_specialLock(ContainerCriticalSection* sex)
	global containerCriticalSection_specialUnlock		;int ccs_specialUnlock(ContainerCriticalSection* sex)			//will also succeed on non-special block, returns 0 on success
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern criticalSection_create
	extern criticalSection_destroy
	extern criticalSection_tryLock
	extern criticalSection_lock
	extern criticalSection_unlock
	
containerCriticalSection_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;allocated ccs		4
	
	;alloc ccs
	push 8
	call my_malloc
	mov dword[ebp-4], eax
	
	;create critical seciton
	call criticalSection_create
	mov ecx, dword[ebp-4]
	mov dword[ecx], eax			;set ccs
	mov dword[ecx+4], 0		;set special lock in
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
containerCriticalSection_destroy:
	push ebp
	mov ebp, esp
	
	;destroy critical section
	mov eax, dword[ebp+8]
	push dword[eax]
	call criticalSection_destroy
	
	;dealloc space
	push dword[ebp+8]
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	

containerCriticalSection_tryLock:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax]
	call criticalSection_tryLock
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
containerCriticalSection_lock:
	push ebp
	mov ebp, esp
	
	;try lock
	push dword[ebp+8]
	call containerCriticalSection_tryLock
	test eax, eax
	jnz containerCriticalSection_lock_end
	
		;lock
		mov eax, dword[ebp+8]
		push dword[eax]
		call criticalSection_lock
	
	containerCriticalSection_lock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
containerCriticalSection_unlock:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	mov dword[ebp-4], 69
	
	mov eax, dword[ebp+8]
	test dword[eax+4], 0xffffffff
	jnz containerCriticalSection_unlock_end
	
		;unlock
		push dword[eax]
		call criticalSection_unlock
		
		mov dword[ebp-4], 0
	
	containerCriticalSection_unlock_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
containerCriticalSection_trySpecialLock:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call containerCriticalSection_tryLock
	test eax, eax
	jz containerCriticalSection_trySpecialLock_end
		;flag the lock in
		mov ecx, dword[ebp+8]
		mov dword[ecx+4], 69
	
	containerCriticalSection_trySpecialLock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
containerCriticalSection_specialLock:
	push ebp
	mov ebp, esp
	
	;try lock
	push dword[ebp+8]
	call containerCriticalSection_trySpecialLock
	test eax, eax
	jnz containerCriticalSection_specialLock_end
	
		;lock
		push dword[ebp+8]
		call containerCriticalSection_lock
		
		;flag as lock in
		mov eax, dword[ebp+8]
		mov dword[eax+4], 69
	
	containerCriticalSection_specialLock_end:
	mov esp, ebp
	pop ebp
	ret
	
	
containerCriticalSection_specialUnlock:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;return value
	mov dword[ebp-4], 69
	
	;check if we have access to the ccs
	push dword[ebp+8]
	call containerCriticalSection_trySpecialLock
	test eax, eax
	jz containerCriticalSection_specialUnlock_end
		
		;unflag the lock in
		mov eax, dword[ebp+8]
		mov dword[eax+4], 0
		
		;unlock the ccs
		push dword[ebp+8]
		call containerCriticalSection_unlock
		mov dword[ebp-4], eax
	
	containerCriticalSection_specialUnlock_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebp
	ret