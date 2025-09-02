[BITS 32]

;https://learn.microsoft.com/en-us/windows/win32/api/psapi/ns-psapi-process_memory_counters

section .data use32
	process_handle dd 0

section .text use32

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

	global meminfo_getMemoryUsage				;int meminfo_getMemoryUsage()

	dll_import kernel32.dll, GetCurrentProcess
	dll_import psapi.dll, GetProcessMemoryInfo
	
	extern my_memset_dword
	
meminfo_getMemoryUsage:
	push ebp
	mov ebp, esp
	
	sub esp, 40			;pcm		40
	
	lea eax, [ebp-40]
	push 40
	push 0
	push eax
	call my_memset_dword
	
	lea eax, [ebp-40]
	push eax
	call meminfo_getMemoryInfo_internal
	
	mov eax, dword[ebp-28]
	
	mov esp, ebp
	pop ebp
	ret
	
	
;internal functinos -------------------------------------------------

;void meminfo_getHandle_internal()
meminfo_getHandle_internal:
	push ebp
	mov ebp, esp
	
	test dword[process_handle], 0xffffffff
	jnz meminfo_getHandle_internal_end
	
	call [GetCurrentProcess]
	mov dword[process_handle], eax
	
	meminfo_getHandle_internal_end:
	mov esp, ebp
	pop ebp
	ret
	
	
;return zero if there was an error
;int meminfo_getMemoryInfo_internal(PROCESS_MEMORY_COUNTER* buffer)
meminfo_getMemoryInfo_internal:
	push ebp
	mov ebp, esp
	
	call meminfo_getHandle_internal
	
	push 40
	push dword[ebp+8]
	push dword[process_handle]
	call [GetProcessMemoryInfo]
	
	mov esp, ebp
	pop ebp
	ret