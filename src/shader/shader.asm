[BITS 32]

section .rodata use32
	print_int db "%d",10,0
	read_mode db "r",0
	
	shader_import_error_1 db "shader_import: %s could not be opened",10,0
	shader_import_error_2 db "shader_import: an error occured while compiling %s",10,0
	shader_import_error_3 db "%s",10,0
	shader_import_error_4 db "shader_import: linkin failed",10,0
	
section .bss use32
	info_buffer resb 512
	shader_buffer resb 1000
	
section .text use32
	
	global shader_import		;GLuint shader_import(const char* pathToVertexShader, const char* pathToFragmentShader, const char* nullablePathToGeometryShader)
	global shader_destroy		;void shader_destroy(GLuint program)
	
	extern my_fopen
	extern my_fclose
	extern my_fgets
	
	extern my_strlen
	extern my_strcpy
	extern my_sprintf
	
	extern my_printf
	
	extern my_malloc
	extern my_free
	
	
	extern GL_VERTEX_SHADER
	extern GL_GEOMETRY_SHADER
	extern GL_FRAGMENT_SHADER
	extern GL_COMPILE_STATUS
	extern GL_LINK_STATUS
	
	extern glAttachShader
	extern glLinkProgram
	extern glCreateProgram
	extern glCreateShader
	extern glShaderSource
	extern glCompileShader
	extern glGetShaderiv
	extern glGetShaderInfoLog
	extern glGetProgramiv
	extern glGetProgramInfoLog
	extern glDeleteShader
	extern glDeleteProgram
	extern glGetError
	
shader_import:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;program
	sub esp, 4		;unused
	sub esp, 4		;char* shaderSource
	
	sub esp, 4		;vertex shader
	sub esp, 4		;geometry shader
	sub esp, 4		;fragment shader
	
	sub esp, 4		;success helper
	
	;alloc space for shader source
	push 10000
	call my_malloc
	mov dword[ebp-12], eax
	add esp, 4
	
	;import and compile vertex shader
	push dword[ebp-12]
	push dword[ebp+8]
	call shader_import_read_file
	add esp, 8
	test eax, eax
	jz shader_import_vs_read
		;vertex shader file could not be opened
		push dword[ebp+8]
		push shader_import_error_1
		push shader_buffer
		call my_sprintf
		call my_printf
		
		xor eax, eax
		jmp shader_import_end
		
	shader_import_vs_read:
	
	
	push dword[GL_VERTEX_SHADER]
	call [glCreateShader]
	mov dword[ebp-16], eax		;save vertex shader
	
	lea eax, [ebp-12]
	push 0
	push eax
	push 1
	push dword[ebp-16]
	call [glShaderSource]
	
	push dword[ebp-16]
	call [glCompileShader]
	
	lea eax, [ebp-28]
	push eax
	push dword[GL_COMPILE_STATUS]
	push dword[ebp-16]
	call [glGetShaderiv]
	
	cmp dword[ebp-28], 0
	jne shader_import_vs_compiled
		;an error occured while compiling the shader
		push dword[ebp+8]
		push shader_import_error_2
		push shader_buffer
		call my_sprintf
		call my_printf
		add esp, 12
		
		push shader_buffer
		push 0
		push 1000
		push dword[ebp-16]
		call [glGetShaderInfoLog]
		
		push shader_buffer
		push shader_import_error_3
		call my_printf
		add esp, 8
		
		xor eax, eax
		jmp shader_import_end
		
	shader_import_vs_compiled:
	
	;import and compile the geometry shader
	;only if there is one tho lol
	mov dword[ebp-20], 0		;set the value of the geometry shader to 0 just in case
	cmp dword[ebp+16], 0
	je shader_import_no_geometry_shader
	
		push dword[ebp-12]
		push dword[ebp+16]
		call shader_import_read_file
		add esp, 8
		test eax, eax
		jz shader_import_gs_read
			;geometry shader file could not be opened
			push dword[ebp+16]
			push shader_import_error_1
			push shader_buffer
			call my_sprintf
			call my_printf
			
			xor eax, eax
			jmp shader_import_end
			
		shader_import_gs_read:
		
		
		push dword[GL_GEOMETRY_SHADER]
		call [glCreateShader]
		mov dword[ebp-20], eax		;save geometry shader
		
		lea eax, [ebp-12]
		push 0
		push eax
		push 1
		push dword[ebp-20]
		call [glShaderSource]
		
		push dword[ebp-20]
		call [glCompileShader]
		
		lea eax, [ebp-28]
		push eax
		push dword[GL_COMPILE_STATUS]
		push dword[ebp-20]
		call [glGetShaderiv]
		
		cmp dword[ebp-28], 0
		jne shader_import_gs_compiled
			;an error occured while compiling the shader
			push dword[ebp+16]
			push shader_import_error_2
			push shader_buffer
			call my_sprintf
			call my_printf
			add esp, 12
			
			push shader_buffer
			push 0
			push 1000
			push dword[ebp-16]
			call [glGetShaderInfoLog]
			
			push shader_buffer
			push shader_import_error_3
			call my_printf
			add esp, 8
			
			xor eax, eax
			jmp shader_import_end
		shader_import_gs_compiled:
		
	shader_import_no_geometry_shader:
	
	
	;import and compile fragment shader
	push dword[ebp-12]
	push dword[ebp+12]
	call shader_import_read_file
	add esp, 8
	test eax, eax
	jz shader_import_fs_read
		;fragment shader file could not be opened
		push dword[ebp+12]
		push shader_import_error_1
		push shader_buffer
		call my_sprintf
		call my_printf
		
		xor eax, eax
		jmp shader_import_end
		
	shader_import_fs_read:
	
	
	push dword[GL_FRAGMENT_SHADER]
	call [glCreateShader]
	mov dword[ebp-24], eax		;save fragment shader
	
	lea eax, [ebp-12]
	push 0
	push eax
	push 1
	push dword[ebp-24]
	call [glShaderSource]
	
	push dword[ebp-24]
	call [glCompileShader]
	
	lea eax, [ebp-28]
	push eax
	push dword[GL_COMPILE_STATUS]
	push dword[ebp-24]
	call [glGetShaderiv]
	
	cmp dword[ebp-28], 0
	jne shader_import_fs_compiled
		;an error occured while compiling the shader
		push dword[ebp+12]
		push shader_import_error_2
		push shader_buffer
		call my_sprintf
		call my_printf
		add esp, 12
		
		push shader_buffer
		push 0
		push 1000
		push dword[ebp-24]
		call [glGetShaderInfoLog]
		
		push shader_buffer
		push shader_import_error_3
		call my_printf
		add esp, 8
		
		xor eax, eax
		jmp shader_import_end
	shader_import_fs_compiled:
	
	;link shader
	call [glCreateProgram]
	mov dword[ebp-4], eax		;save the program id
	
	push dword[ebp-16]		;vertex shader
	push dword[ebp-4]		;program
	call [glAttachShader]
	
	cmp dword[ebp+16], 0
	je shader_import_no_gs_attach
		push dword[ebp-20]	;geometry shader
		push dword[ebp-4]
		call [glAttachShader]
	shader_import_no_gs_attach:
	
	push dword[ebp-24]		;fragment shader
	push dword[ebp-4]		;program
	call [glAttachShader]
	
	push dword[ebp-4]
	call [glLinkProgram]
	
	lea eax, [ebp-28]
	push eax
	push dword[GL_LINK_STATUS]
	push dword[ebp-4]		;program
	call [glGetProgramiv]
	
	cmp dword[ebp-28], 0
	jne shader_import_linked
		;program could not be linked
		push shader_import_error_4
		call my_printf
		add esp, 4
		
		push shader_buffer
		push 0
		push 1000
		push dword[ebp-4]
		call [glGetProgramInfoLog]
		
		push shader_buffer
		push shader_import_error_3
		call my_printf
		add esp, 8
		
		xor eax, eax
		jmp shader_import_end
	shader_import_linked:
	
	;the compiled shaders are no longer needed
	push dword[ebp-16]
	call [glDeleteShader]
	
	cmp dword[ebp+16], 0
	je shader_import_no_gs_delete
		push dword[ebp-20]
		call [glDeleteShader]
	shader_import_no_gs_delete:
	
	push dword[ebp-24]
	call [glDeleteShader]
	
	
	shader_import_end:
	;free shader source
	push dword[ebp-12]
	call my_free
	add esp, 4
	
	mov eax, dword[ebp-4]
	mov esp, ebp
	pop ebp
	ret
	
	
;int shader_import_read_file(const char* pathToFile, char* buffer)
;reads the contents of the file into the buffer
;returns 0 if all is well
shader_import_read_file:
	push ebp
	push ebx
	push esi
	push edi
	mov ebp, esp
	
	sub esp, 300	;line buffer
	sub esp, 4		;file
	
	;open file
	push read_mode
	push dword[ebp+20]
	call my_fopen
	mov dword[ebp-304], eax		;save the file
	add esp, 8
	
	test eax, eax
	jz shader_import_read_file_error
	
	;read the contents line by line
	mov esi, dword[ebp+24]		;the start of the next line in esi
	shader_import_read_file_loop_start:
	
		;read line into the line buffer
		lea eax, [ebp-300]
		push dword[ebp-304]
		push 300
		push eax
		call my_fgets
		add esp, 12
		
		;was it successful?
		test eax, eax
		jz shader_import_read_file_loop_end
		
		;copy the line into the shader_buffer
		lea eax, [ebp-300]
		push eax
		push esi
		call my_strcpy
		add esp, 8
		
		;adjust the value of esi
		lea eax, [ebp-300]
		push eax
		call my_strlen
		add esp, 4
		
		add esi, eax
		
		jmp shader_import_read_file_loop_start
		
	shader_import_read_file_loop_end:
	
	;close the file
	push dword[ebp-304]
	call my_fclose
	add esp, 4
	
	xor eax, eax
	jmp shader_import_read_file_end
	shader_import_read_file_error:
		mov eax, 69
		jmp shader_import_read_file_end
		
	shader_import_read_file_end:
	mov esp, ebp
	pop edi
	pop esi
	pop ebx
	pop ebp
	ret
	
	
shader_destroy:
	push ebp
	mov ebp, esp
	
	push dword[ebp+8]
	call [glDeleteProgram]
	
	mov esp, ebp
	pop ebp
	ret