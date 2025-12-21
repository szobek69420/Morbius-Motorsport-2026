[BITS 32]

;layout:
;struct Terminal{
;	int isClosed;						0
;	UIEmpty* root;						4
;	UIImage* background;				8
;	padding of 4 bytes
;	vector<char*> terminalHistory;		16
;	int maxHistoryLength;				32
;	padding of 12 bytes
;	char* currentlyTyped;				48
;	int maxLineLength;					52
;}	56 bytes overall


section .text use32

	global terminal_create		;Terminal* terminal_create(int maxHistoryLength, int maxLineLength)
	
	global terminal_destroy		;void terminal_destroy(Terminal* terminator)
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern vector_init
	extern vector_destroy
	extern vector_for_each
	
	extern uiElement_create
	extern uiElement_destroy
	extern uiElement_setParent
	extern uiElement_setPosition
	extern uiElement_setSize
	extern uiElement_setAnchor
	extern uiElement_setPivot
	extern uiElement_setStatus
	extern UI_EMPTY
	extern UI_IMAGE
	extern UI_LEFT
	extern UI_BOTTOM


terminal_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;terminal		4
	
	mov dword[ebp-4], 0
	
	;check if the inputs are kosher
	cmp dword[ebp+8], 0
	jg terminal_create_valid_history_length
		push dword[ebp+8]
		push terminal_create_error_invalid_history_length
		call my_printf
		jmp terminal_create_end
		
		terminal_create_error_invalid_history_length db "terminal_create: %d is not a valid history length (must be greater than zero)",10,0
	terminal_create_valid_history_length:
	
	cmp dword[ebp+12], 0
	jg terminal_create_valid_line_length
		push dword[ebp+12]
		push terminal_create_error_invalid_line_length
		call my_printf
		jmp terminal_create_end
		
		terminal_create_error_invalid_line_length db "terminal_create: %d is not a valid line length (must be greater than zero)",10,0
	terminal_create_valid_line_length:
	
	
	;alloc the terminal
	push 56
	call my_malloc
	mov dword[ebp-4], eax
	
	mov dword[eax], 0		;not visible initially
	
	;create the root and the background
	push dword[UI_EMPTY]
	call uiElement_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+4], eax
	
	push 0
	push 0
	push dword[ecx+4]
	call uiElement_setPosition
	call uiElement_setSize
	call uiElement_setStatus	;not visible initially
	
	push dword[UI_IMAGE]
	call uiElement_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+8], eax
	
	push word[UI_BOTTOM]
	push word[UI_LEFT]
	push eax
	call uiElement_setAnchor
	call uiElement_setPivot
	
	mov ecx, dword[ebp-4]
	push dword[ecx+4]
	push dword[ecx+8]
	call uiElement_setParent
	
	
	;init the history stuff
	mov eax, dword[ebp-4]
	add eax, 16
	push 4
	push eax
	call vector_init
	
	mov eax, dword[ebp-4]
	mov ecx, dword[ebp+8]
	mov dword[eax+32], ecx		;max history length
	
	
	;init the typed line stuff
	mov eax, dword[ebp-4]
	mov ecx, dword[ebp+12]
	mov dword[eax+52], ecx
	
	inc ecx
	push ecx
	call my_malloc
	mov byte[eax], 0
	mov ecx, dword[ebp-4]
	mov dword[ecx+48], ecx
	
	
	terminal_create_end:
	mov eax, dword[ebp-4]		;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
terminal_destroy:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;unset the parent
	mov eax, dword[ebp+20]
	push 0
	push dword[eax+4]
	call uiElement_setParent
	
	;destroy the root
	mov eax, dword[ebp+20]
	push dword[eax+4]
	call uiElement_destroy
	
	;stalin the history
	mov eax, dword[ebp+20]
	add eax, 16
	push 0
	push terminal_destroy_delete_history_helper
	push eax
	call vector_for_each
	call vector_destroy
	jmp terminal_destroy_stalin_gg
	
	terminal_destroy_delete_history_helper:	;void func(char** pHistoryLine, int nulla)
		mov eax, dword[esp+4]
		push dword[eax]
		call my_free
		add esp, 4
		ret
		
	terminal_destroy_stalin_gg:
	
	;free the line buffer
	mov eax, dword[ebp+20]
	push dword[eax+48]
	call my_free
	
	;free the sus
	push dword[ebp+20]
	call my_free
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret