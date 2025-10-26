[BITS 32]

section .rodata use32
	file_path db "./settings/spaghetti.bolognese",0
	open_mode_read db "r",0
	open_mode_write db "w",0
	format_render_distance db "render_distance: %d",10,0
	format_resolution db "resolution: %d",10,0
	
	;resolutions
	RESOLUTION_WIDTHS dd 0, 256, 640, 1280, 1920, 1920, 2560, 15360
	RESOLUTION_HEIGHTS dd 0, 144, 480, 720, 1080, 1, 1440, 8640
	RESOLUTION_NAMES:
	dd RESOLUTION_NAME_0
	dd RESOLUTION_NAME_1
	dd RESOLUTION_NAME_2
	dd RESOLUTION_NAME_3
	dd RESOLUTION_NAME_4
	dd RESOLUTION_NAME_5
	dd RESOLUTION_NAME_6
	dd RESOLUTION_NAME_7
	
	RESOLUTION_NAME_0 db "Helen Keller (0x0)",0
	RESOLUTION_NAME_1 db "256x144",0
	RESOLUTION_NAME_2 db "640x480",0
	RESOLUTION_NAME_3 db "HD (1280x720)",0
	RESOLUTION_NAME_4 db "FHD (1920x1080)",0
	RESOLUTION_NAME_5 db "Chinese FHD (1920x1)",0
	RESOLUTION_NAME_6 db "QHD (2560x1440)",0
	RESOLUTION_NAME_7 db "Mogger (15360x8640)",0
	
	
	DEFAULT_VALUES:
	dd 3
	dd 3
	
section .bss use32
	;struct Settings{
	;	int render_distance;
	;	int resolution_index;
	;}
	SETTINGS_STRUCT_SIZE equ 8
	read_data resb SETTINGS_STRUCT_SIZE
	write_data resb SETTINGS_STRUCT_SIZE
	
section .text use32

	;returns a pointer to a Settings struct
	;the pointer should not be freed
	;the contents of the Settings struct can be overwritten by subsequent settings calls
	;Settings* settings_read()
	global settings_read
	
	;writes from the buffer returned by the last settings_getBuffer call
	;void settings_write()
	global settings_write
	
	global settings_getBuffer		;returns a Settings* from which the next settings_write call will work
	
	global settings_resolutionInfo	;void settings_resolutionInfo(int index, int* width, int* height, const char** nullableName)
	
	extern my_printf
	extern my_sprintf
	
	extern my_fopen
	extern my_fclose
	extern my_fprintf
	extern my_fscanf
	
	extern my_memcpy
	
settings_read:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;render distance		4
	sub esp, 4			;resolution				8
	sub esp, 4			;file					12
	
	;check if the settings file exists and create it if necessary
	push open_mode_read
	push file_path
	call my_fopen
	test eax, eax
	jnz settings_read_file_exists
		;save default values
		call settings_getBuffer
		push SETTINGS_STRUCT_SIZE
		push DEFAULT_VALUES
		push eax
		call my_memcpy

		call settings_write
		
		;open file noch 'mal
		push open_mode_read
		push file_path
		call my_fopen
	settings_read_file_exists:
	
	mov dword[ebp-12], eax
	
	;read values
	lea eax, [ebp-4]
	push eax
	push format_render_distance
	push dword[ebp-12]
	call my_fscanf
	
	lea eax, [ebp-8]
	push eax
	push format_resolution
	push dword[ebp-12]
	call my_fscanf
	
	;close file
	push dword[ebp-12]
	call my_fclose
	
	;set values	
	mov eax, read_data
	
	mov ecx, dword[ebp-4]
	mov dword[eax], ecx			;render distance
	mov edx, dword[ebp-8]
	mov dword[eax+4], edx		;resolution
	
	;set return value
	mov eax, read_data
	
	mov esp, ebp
	pop ebp
	ret
	
settings_write:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;file		4
	
	;open file
	push open_mode_write
	push file_path
	call my_fopen
	mov dword[ebp-4], eax
	
	;write things
	push dword[write_data]
	push format_render_distance
	push dword[ebp-4]
	call my_fprintf
	
	mov eax, write_data
	push dword[eax+4]
	push format_resolution
	push dword[ebp-4]
	call my_fprintf
	
	;close file
	push dword[ebp-4]
	call my_fclose
	
	mov esp, ebp
	pop ebp
	ret
	
	
settings_getBuffer:
	mov eax, write_data
	ret
	
	
settings_resolutionInfo:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	test eax, 0x80000000
	jnz settings_resolutionInfo_error
	cmp eax, 8
	jge settings_resolutionInfo_error
	
		mov ecx, dword[RESOLUTION_WIDTHS+4*eax]
		mov edx, dword[ebp+12]
		mov dword[edx], ecx
		
		mov ecx, dword[RESOLUTION_HEIGHTS+4*eax]
		mov edx, dword[ebp+16]
		mov dword[edx], ecx
		
		mov edx, dword[ebp+20]
		test edx, edx
		jz settings_resolutionInfo_end
		mov ecx, dword[RESOLUTION_NAMES+4*eax]
		mov dword[edx], ecx
	
	settings_resolutionInfo_end:
	mov esp, ebp
	pop ebp
	ret
	settings_resolutionInfo_error:
		push dword[ebp+8]
		push settings_resolutionInfo_error_message
		call my_printf
		jmp settings_resolutionInfo_end
		settings_resolutionInfo_error_message db "settings_resolutionInfo: %d is an invalid index",10,0