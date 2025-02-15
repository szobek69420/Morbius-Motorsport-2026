[BITS 32]

;BMP header (offset, meaning)
;HEADER:
;0, magic identifier 'BM'
;2, file size in bytes
;6, unused
;10, offset of the data from the beginning of the file
;INFOHEADER:
;14, size of the infoheader
;18, width of bitmap in pixels
;22, height of bitmap in pixels
;26, number of planes (=1)
;28, bits per pixel (i'll use 24 and 32)
;30, compression (i dont care about this field)
;34, (compressed) size of the image (can be 0 if there is no compression)
;38, horizontal res in p/m
;42, vertical res in p/m
;46, idk
;50, idk
;color table comes here (only in scenarios i dont care about)
;pixel data

;the values above are little endian and the pixel data is ordered as bgr(a)

section .rodata use32
	read_mode db "r",0
	print_int db "%d",10,0

	error_invalid_file db "image_loadBMP: invalid image path",10,0
	error_not_bmp db "image_loadBMP: the given image is not a .bmp file",10,0
	error_invalid_pixel_format db "image_loadBMP: only 3 and 4 channel pixel formats are supported (8 bits/channel/pixel)",10,0

section .data use32
	flip_data dd 0			;should the image be vertically flipped

section .text use32

	;buffer will be filled according to the RGB or RGBA format
	global image_loadBMP			;void image_loadBMP(const char* imagePath, char* buffer, int* outWidth, int* outHeight, int* outBitsPerPixel)
	
	global image_flip				;void image_flip(int flipImages), it is a state-setting function
	
	extern my_printf
	extern my_fopen
	extern my_fclose
	extern my_fgetc
	extern my_fjmp
	
	
image_loadBMP:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;FILE* image
	sub esp, 4			;data offset
	sub esp, 4			;width in pixels
	sub esp, 4			;height in pixels
	sub esp, 4			;bits per pixel
	sub esp, 4			;padding at the end of the rows in 24 bit format (row size must be divisible by 4 bytes, because Bill Chilling said so)
	
	;open file
	push read_mode
	push dword[ebp+8]
	call my_fopen
	mov dword[ebp-4], eax
	add esp, 8
	
	test eax, eax
	jnz image_loadBMP_file_open_successful
		push error_invalid_file
		call my_printf
		add esp, 4
		jmp image_loadBMP_end
	image_loadBMP_file_open_successful:
	
	;is it a bmp file?
	push dword[ebp-4]
	call my_fgetc
	cmp al, 0x42
	jne image_loadBMP_error_not_bmp
	call my_fgetc
	cmp al, 0x4d
	jne image_loadBMP_error_not_bmp
	add esp, 4
	jmp image_loadBMP_good_format
	image_loadBMP_error_not_bmp:
		push error_not_bmp
		call my_printf
		add esp, 4
		jmp image_loadBMP_end_with_fclose
	image_loadBMP_good_format:
	 
	;get the data offset
	push 0
	push 10
	push dword[ebp-4]
	call my_fjmp
	call my_fgetc
	mov byte[ebp-8], al
	call my_fgetc
	mov byte[ebp-7], al
	call my_fgetc
	mov byte[ebp-6], al
	call my_fgetc
	mov byte[ebp-5], al
	add esp, 12
	
	;get the width and height of the image
	push 0
	push 18
	push dword[ebp-4]
	call my_fjmp
	call my_fgetc
	mov byte[ebp-12], al
	call my_fgetc
	mov byte[ebp-11], al
	call my_fgetc
	mov byte[ebp-10], al
	call my_fgetc
	mov byte[ebp-9], al
	call my_fgetc
	mov byte[ebp-16], al
	call my_fgetc
	mov byte[ebp-15], al
	call my_fgetc
	mov byte[ebp-14], al
	call my_fgetc
	mov byte[ebp-13], al
	add esp, 12
	
	;get the bits per pixel value
	push dword[ebp-4]
	call my_fgetc
	call my_fgetc
	
	call my_fgetc
	mov byte[ebp-20], al
	call my_fgetc
	mov byte[ebp-19], al
	mov byte[ebp-18], 0
	mov byte[ebp-17], 0
	add esp, 4
	
	;read the data
	cmp dword[ebp-20], 24
	je image_loadBMP_read_24
	cmp dword[ebp-20], 32
	je image_loadBMP_read_32
	jmp image_loadBMP_invalid_pixel_format
	
	image_loadBMP_read_24:
		;calculate padding at the end of the row
		xor edx, edx
		mov eax, dword[ebp-12]
		imul eax, 3
		mov ecx, 4
		idiv ecx
		mov dword[ebp-24], edx		;the remainder is the padding
	
		;jump to the data
		push 0
		push dword[ebp-8]
		push dword[ebp-4]
		call my_fjmp
		add esp, 12
		
		;read data
		push ebx			;save ebx
		push esi			;save esi
		push edi			;save edi
		mov ebx, dword[ebp+12]			;current pos in buffer in ebx
		mov esi, dword[ebp-16]			;height in esi
		push dword[ebp-4]
		image_loadBMP_read_24_outer_loop_start:
			mov edi, dword[ebp-12]		;width in edi
			image_loadBMP_read_24_inner_loop_start:
				call my_fgetc
				mov byte[ebx+2], al		;b
				call my_fgetc
				mov byte[ebx+1], al		;g
				call my_fgetc
				mov byte[ebx], al		;r
				
				add ebx, 3
				dec edi
				test edi, edi
				jnz image_loadBMP_read_24_inner_loop_start
		
			;jump over the padding
			push 69						;jump from current file pointer position
			push dword[ebp-24]			;padding
			push dword[ebp-4]			;file
			call my_fjmp
			add esp, 12
		
			dec esi
			test esi, esi
			jnz image_loadBMP_read_24_outer_loop_start
			
		add esp, 4
		pop edi				;restore edi
		pop esi				;restore esi
		pop ebx				;restore ebx
	
		jmp image_loadBMP_read_done
	
	image_loadBMP_read_32:
		;jump to the data
		push 0
		push dword[ebp-8]
		push dword[ebp-4]
		call my_fjmp
		add esp, 12
		
		;read data
		push esi			;save esi
		push edi			;save edi
		
		mov esi, dword[ebp+12]		;current pos in buffer in esi
		mov edi, dword[ebp-12]
		imul edi, dword[ebp-16]	;pixel count in edi
		push dword[ebp-4]			;file
		image_loadBMP_read_32_loop_start:
			call my_fgetc
			mov byte[esi+2], al		;b
			call my_fgetc
			mov byte[esi+1], al		;g
			call my_fgetc
			mov byte[esi], al		;r
			call my_fgetc
			mov byte[esi+3], al		;a
			
			add esi, 4
			dec edi
			test edi, edi
			jnz image_loadBMP_read_32_loop_start
		
		add esp, 4
		pop edi				;restore edi
		pop esi				;restore esi
	
		jmp image_loadBMP_read_done
	
	image_loadBMP_invalid_pixel_format:
		push error_invalid_pixel_format
		call my_printf
		jmp image_loadBMP_end_with_fclose
	
	image_loadBMP_read_done:
	
	;flip the data if necessary
	cmp dword[flip_data], 0
	je image_loadBMP_skip_flip
		mov eax, dword[ebp-20]
		shr eax, 3
		imul eax, dword[ebp-12]
		
		push dword[ebp-16]		;row count
		push eax				;bytes per row
		push dword[ebp+12]		;buffer
		call image_flipDataInternal
		add esp, 12
		
	image_loadBMP_skip_flip:
	
	;set outWidth, outHeight and outBitsPerPixel
	mov eax, dword[ebp+16]
	mov ecx, dword[ebp-12]
	mov dword[eax], ecx
	
	mov eax, dword[ebp+20]
	mov ecx, dword[ebp-16]
	mov dword[eax], ecx
	
	mov eax, dword[ebp+24]
	mov ecx, dword[ebp-20]
	mov dword[eax], ecx
	
	
	image_loadBMP_end_with_fclose:
	push dword[ebp-4]
	call my_fclose
	
	image_loadBMP_end:
	mov esp, ebp
	pop ebp
	ret
	
	
	
image_flip:
	mov eax, dword[esp+4]
	mov dword[flip_data], eax
	ret
	
	
;void image_flipDataInternal(char* buffer, int rowLengthInBytes, int rowCount)
image_flipDataInternal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	
	mov esi, dword[ebp+20]			;first row in esi
	mov edi, dword[ebp+28]
	dec edi
	imul edi, dword[ebp+24]
	add edi, esi					;last row in edi
	mov ebx, dword[ebp+28]
	shr ebx, 1						;row-pair count in ebx
	test ebx, ebx
	jz image_flipDataInternal_end
	
	image_flipDataInternal_outer_loop_start:
		mov edx, dword[ebp+24]		;row length in edx
		image_flipDataInternal_inner_loop_start:
			mov al, byte[esi+edx-1]
			mov cl, byte[edi+edx-1]
			mov byte[esi+edx-1], cl
			mov byte[edi+edx-1], al
			
			dec edx
			test edx, edx
			jnz image_flipDataInternal_inner_loop_start
			
		add esi, dword[ebp+24]
		sub edi, dword[ebp+24]
		dec ebx
		test ebx, ebx
		jnz image_flipDataInternal_outer_loop_start
	
	
	image_flipDataInternal_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret