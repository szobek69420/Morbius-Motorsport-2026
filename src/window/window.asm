[BITS 32]

%macro dll_import 2
    import %2 %1
    extern %2
%endmacro

section .rodata use32
	window_could_not_be_created db "window: window could not be created",10,0
	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0

section .data use32
	WINDOW_SIZE_X dd 600
	WINDOW_SIZE_Y dd 600
	
	global WINDOW_SIZE_X
	global WINDOW_SIZE_Y
	
section .bss use32
	icon_buffer resb 40000			;100px*100px*4channels

section .text use32
	global window_create			;GLFWwindow* window_create(const char* name)
	global window_destroy			;void window_destroy(GLFWwindow* pwindow)
	
	global window_enableVsync		;void window_enableVsync(GLFWwindow* pwindow, int enable)
	
	;the image should be a .bmp file and consist of at most 10000 pixels (otherwise the program will probably crash lol)
	;if the imagePath is NULL, the default icon will be set
	;void window_setIcon(GLFWwindow* pwindow, const char* nullableImagePath)
	global window_setIcon
	
	extern glfwInit
	extern glfwTerminate
	extern glfwWindowHint
	extern glfwCreateWindow
	extern glfwDestroyWindow
	extern glfwMakeContextCurrent
	extern glfwGetCurrentContext
	extern glfwSwapInterval
	extern glfwSetWindowIcon
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
	extern my_malloc
	extern my_free
	
	extern image_loadBMP
	extern image_flip
	
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
		
	window_enableVsync_no_vsync:
		;kein vsync
		push 0
		call [glfwSwapInterval]
		
	window_enableVsync_end:
	mov esp, ebp
	pop ebp
	ret
	
	
window_setIcon:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;image width		4
	sub esp, 4			;image height		8
	sub esp, 4			;byte depth			12
	sub esp, 4			;full buffer		16
	
	;check if the path is null
	test dword[ebp+24], 0xffffffff
	jnz window_setIcon_not_default
		;default icon will be set
		push 0
		push 0
		push dword[ebp+20]
		call [glfwSetWindowIcon]
		jmp window_setIcon_end
	
	window_setIcon_not_default:
		;flip burgir
		push 69
		call image_flip
		add esp, 4
	
		;load image data (with byte depth in [1;4])
		lea eax, [ebp-12]
		push eax
		lea ecx, [ebp-8]
		push ecx
		lea edx, [ebp-4]
		push edx
		push icon_buffer
		push dword[ebp+24]
		call image_loadBMP
		add esp, 20
		shr dword[ebp-12], 3		;loadBMP returns bit depth instead of byte depth
		
		;allocate buffer for the image with the byte depth of 4 bytes
		mov eax, dword[ebp-4]
		imul eax, dword[ebp-8]
		shl eax, 2
		push eax
		call my_malloc
		mov dword[ebp-16], eax
		
		;generate pixel padding
		mov ebx, 0xffffffff
		mov esi, dword[ebp-12]
		window_setIcon_not_default_padding_loop_start:
			shl ebx, 8
			dec esi
			cmp esi, 0
			jg window_setIcon_not_default_padding_loop_start
		
		;copy the image data into the depthier buffer
		;the pixel data is padded to 4 bytes
		mov eax, dword[ebp-4]
		imul eax, dword[ebp-8]		;index in eax
		mov esi, icon_buffer		;source buffer in esi
		mov edi, dword[ebp-16]		;destination buffer in edi
		cmp eax, 0
		jle window_setIcon_not_default_copy_loop_end
		window_setIcon_not_default_copy_loop_start:
			mov ecx, dword[esi]
			or ecx, ebx				;add padding
			mov dword[edi], ecx
			
			add esi, dword[ebp-12]
			add edi, 4
			
			dec eax
			test eax, eax
			jnz window_setIcon_not_default_copy_loop_start
			
		window_setIcon_not_default_copy_loop_end:
		
		;set the icon
		push dword[ebp-16]
		push dword[ebp-8]
		push dword[ebp-4]
		mov eax, esp
		push esp
		push 1
		push dword[ebp+20]
		call [glfwSetWindowIcon]
		add esp, 24
		
		;free the data
		push dword[ebp-16]
		call my_free
		add esp, 4
	
	window_setIcon_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret