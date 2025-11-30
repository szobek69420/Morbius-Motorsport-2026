[BITS 32]

;imports geometry data exported from https://github.com/szobek69420/ModelDataExtracter
section .rodata use32
	open_mode db "r",0
	
	read_vertex_count db "vertex count: %d",0
	read_vertex_data db "%f %f %f %f %f",0
	
	print_import_data db "%s was successfully imported with %d vertices",10,0
	
	print_int_nl db "%d",10,0

section .text use32
	;returns NULL if something ist fehlgeschlagen
	;otherwise creates a renderable with renderable_createCustom
	;Renderable* geometryImporter_import(const char* filePath)
	global geometryImporter_import
	
	extern my_printf
	extern my_fopen
	extern my_fclose
	extern my_fscanf
	extern my_fjmp
	extern my_fgetc
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
	
	extern renderable_createCustom
	
geometryImporter_import:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4		;renderable			4
	sub esp, 4		;file				8
	sub esp, 4		;vertex count		12
	sub esp, 16		;vertex vector		28
	sub esp, 20		;vertex buffer		48
	sub esp, 16		;index vector		64 (unused)
	sub esp, 4		;eol length			68
	
	mov dword[ebp-4], 0
	mov dword[ebp-12], -1
	
	mov dword[ebp-48], 0
	mov dword[ebp-44], 0
	mov dword[ebp-40], 0
	mov dword[ebp-36], 0
	mov dword[ebp-32], 0
	
	;open file
	push open_mode
	push dword[ebp+20]
	call my_fopen
	mov dword[ebp-8], eax
	test eax, eax
	jnz geometryImporter_import_fopen_gg
		push dword[ebp+20]
		push geometryImporter_import_error_fopen_L
		call my_printf
		jmp geometryImporter_import_end
		geometryImporter_import_error_fopen_L db "geometryImporter_import: %s could not be opened",10,0
	geometryImporter_import_fopen_gg:
	
	;get vertex count
	lea eax, [ebp-12]
	push eax
	push read_vertex_count
	push dword[ebp-8]
	call my_fscanf
	add esp, 12
	cmp dword[ebp-12], 0
	jle geometryImporter_import_close_file		;-1 also counts obv
	
	;determine the eol
	mov dword[ebp-68], 0
	push dword[ebp-8]
	geometryImporter_import_eol_loop_start:
		call my_fgetc
		
		cmp eax, 10			;line feed
		je geometryImporter_import_eol_loop_remain
		cmp eax, 13			;carriage return
		je geometryImporter_import_eol_loop_remain
		jmp geometryImporter_import_eol_loop_end
		geometryImporter_import_eol_loop_remain:
			inc dword[ebp-68]
			jmp geometryImporter_import_eol_loop_start
	geometryImporter_import_eol_loop_end:
	push 69
	push -1
	push dword[ebp-8]
	call my_fjmp
	
	cmp dword[ebp-68], 0
	jg geometryImporter_import_eol_based
		push dword[ebp+20]
		push geometryImporter_import_error_no_eol
		call my_printf
		jmp geometryImporter_import_close_file
		geometryImporter_import_error_no_eol db "geometryImporter_import: %s contains invalid end-of-line sequence",10,0
	geometryImporter_import_eol_based:
	
	;create vertex vector
	push 4
	lea eax, [ebp-28]
	push eax
	call vector_init
	
	;read vertex data
	mov esi, dword[ebp-12]			;index in esi
	lea eax, [ebp-32]
	push eax
	sub eax, 4
	push eax
	sub eax, 4
	push eax
	sub eax, 4
	push eax
	sub eax, 4
	push eax
	push read_vertex_data
	push dword[ebp-8]
	geometryImporter_import_read_loop_start:
		;read data
		call my_fscanf
		
		;eat eol
		push 69
		push dword[ebp-68]
		push dword[ebp-8]
		call my_fjmp
		add esp, 12
		
		;add vertex to the geometry
		lea eax, [ebp-28]
		sub esp, 4
		push eax
		
		mov eax, dword[ebp-48]
		mov dword[esp+4], eax
		call vector_push_back
		mov eax, dword[ebp-44]
		mov dword[esp+4], eax
		call vector_push_back
		mov eax, dword[ebp-40]
		mov dword[esp+4], eax
		call vector_push_back
		mov eax, dword[ebp-36]
		mov dword[esp+4], eax
		call vector_push_back
		mov eax, dword[ebp-32]
		mov dword[esp+4], eax
		call vector_push_back
		
		add esp, 8
		
		dec esi
		jnz geometryImporter_import_read_loop_start
		
	;create renderable
	push 0
	push 2		;uv
	push 3		;pos
	push 2
	push 0
	lea eax, [ebp-28]
	push eax
	call renderable_createCustom
	mov dword[ebp-4], eax
	
	;destroy vertex vector
	lea eax, [ebp-28]
	push eax
	call vector_destroy
	
	
	push dword[ebp-12]
	push dword[ebp+20]
	push print_import_data
	call my_printf
	
	;close file
	geometryImporter_import_close_file:
	push dword[ebp-8]
	call my_fclose
	
	geometryImporter_import_end:
	mov eax, dword[ebp-4]			;set return value
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret