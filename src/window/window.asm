[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	window_could_not_be_created db "window: window could not be created",10,0
	print_int db "%d",10,0

section .data use32
	WINDOW_SIZE_X dd 600
	WINDOW_SIZE_Y dd 600
	
	global WINDOW_SIZE_X
	global WINDOW_SIZE_Y

section .text use32
	global window_create			;GLFWwindow* window_create(const char* name)
	global window_destroy			;void window_destroy(GLFWwindow* pwindow)
	
	global window_enableVsync		;void window_enableVsync(GLFWwindow* pwindow, int enable)
	
	extern glfwInit
	extern glfwTerminate
	extern glfwWindowHint
	extern glfwCreateWindow
	extern glfwDestroyWindow
	extern glfwMakeContextCurrent
	extern glfwGetCurrentContext
	extern glfwSwapInterval
	extern glfwGetProcAddress
	extern glfwGetError
	
	extern GLFW_CONTEXT_VERSION_MAJOR
	extern GLFW_CONTEXT_VERSION_MINOR
	extern GLFW_OPENGL_CORE_PROFILE
	extern GLFW_OPENGL_PROFILE
	extern GLFW_TRUE
	extern GLFW_CENTER_CURSOR
	
	extern load_gl_functions
	extern glViewport
	
	extern my_printf
	
window_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;created GLFWwindow*	4
	
	call [glfwInit]
	
	push 4
	push dword[GLFW_CONTEXT_VERSION_MAJOR]
	call [glfwWindowHint]
	add esp, 8
	
	push 6
	push dword[GLFW_CONTEXT_VERSION_MINOR]
	call [glfwWindowHint]
	add esp, 8
	
	push dword[GLFW_OPENGL_CORE_PROFILE]
	push dword[GLFW_OPENGL_PROFILE]
	call [glfwWindowHint]
	add esp, 8
	
	push dword[GLFW_TRUE]
	push dword[GLFW_CENTER_CURSOR]
	call [glfwWindowHint]
	add esp, 8
	
	;create window
	push 0
	push 0
	push dword[ebp+8]
	push dword[WINDOW_SIZE_Y]
	push dword[WINDOW_SIZE_X]
	call [glfwCreateWindow]
	mov dword[ebp-4], eax
	cmp eax, 0
	jne window_create_no_gebasz
		push window_could_not_be_created
		call my_printf
		add esp, 4
	
		call [glfwTerminate]
		mov eax, 0
		
		mov esp, ebp
		pop ebp
		ret
	window_create_no_gebasz:
	
	;set the current context to this thread
	push dword[ebp-4]
	call [glfwMakeContextCurrent]
	add esp, 4
	
	;disable vsync
	push 0
	push dword[ebp-4]
	call window_enableVsync
	add esp, 8
	
	;load the opengl functions
	push dword[glfwGetProcAddress]
	call load_gl_functions
	add esp, 4
	
	test eax, eax
	jne window_create_load_functions_no_gebasz
		push dword[ebp-4]
		call [glfwDestroyWindow]
		
		call [glfwTerminate]
		mov eax, 0
		
		mov esp, ebp
		pop ebp
		ret
	window_create_load_functions_no_gebasz:
	
	
	;set the viewport size
	push dword[WINDOW_SIZE_Y]
	push dword[WINDOW_SIZE_X]
	push 0
	push 0
	call [glViewport]
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	

window_destroy:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [glfwDestroyWindow]
	
	call [glfwTerminate]
	
	mov esp, ebp
	pop ebp
	ret
	
	
window_enableVsync:
	push ebp
	mov ebp, esp
	
	test dword[ebp+12], 0xffffffff
	jz window_enableVsync_no_vsync
		;vsync
		push 1
		call [glfwSwapInterval]
		jmp window_enableVsync_end
		
	window_enableVsync_no_vsync
		;kein vsync
		push 0
		call [glfwSwapInterval]
		
	window_enableVsync_end:
	mov esp, ebp
	pop ebp
	ret