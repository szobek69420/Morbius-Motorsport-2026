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

section .rodata use32
	FONT_WIDTH dd 6
	FONT_HEIGHT dd 8
	FONT_SPACING dd 1
	LINE_SPACING dd 3
	PADDING_HORIZONTAL dd 5
	PADDING_VERTICAL dd 3
	
	WRITTEN_LINE_COLOUR dd 0.0, 1.0, 1.0, 1.0
	HISTORY_LINE_COLOUR dd 1.0, 0.85, 0.0, 1.0
	
section .data use32
	terminal_count dd 0
	registered_callbacks dd 0,0		;tsVector<{GLFWWindow*, Terminal*}>

section .text use32

	;initializes the terminal in a closed state
	;Terminal* terminal_create(int maxHistoryLength, int maxLineLength)
	global terminal_create
	
	global terminal_destroy		;void terminal_destroy(Terminal* terminator)
	
	;opens the terminal (resets the input part and makes the element visible)
	;also recalculates the content
	;void terminal_open(Terminal* terminal, GLFWWindow* pwindow)
	global terminal_open
	
	;closes the terminal
	;if desired, saves the written line into the history
	;void terminal_close(Terminal* terminal, GLFWWindow* pwindow, int saveWrittenLine)
	global terminal_close
	
	;processes keyboard input and recalculates the content if necessary
	;void terminal_processInput(Terminal* terminal)
	global terminal_processInput
	
	
	extern glfwSetCharCallback
	
	extern my_printf
	extern my_malloc
	extern my_free
	extern my_strlen
	extern my_strcpy
	
	extern ctype_toUpper
	extern ctype_isAlnum
	
	extern vector_init
	extern vector_destroy
	extern vector_insert
	extern vector_remove
	extern vector_remove_at
	extern vector_for_each
	extern tsVector_init
	extern tsVector_destroy
	extern tsVector_pushBack
	extern tsVector_removeCustom
	extern tsVector_at
	extern tsVector_search
	extern tsVector_lock
	extern tsVector_unlock
	
	extern uiElement_create
	extern uiElement_destroy
	extern uiElement_setParent
	extern uiElement_setPosition
	extern uiElement_setSize
	extern uiElement_setAnchor
	extern uiElement_setPivot
	extern uiElement_setStatus
	extern uiElement_getChildren
	extern uiText_setText
	extern uiText_setColour
	extern uiText_setTextAlignment
	extern uiText_setFontSize
	extern uiText_setSpacing
	extern UI_EMPTY
	extern UI_IMAGE
	extern UI_TEXT
	extern UI_LEFT
	extern UI_BOTTOM
	extern UI_TEXT_ALIGN_BOTTOM
	extern UI_TEXT_ALIGN_LEFT


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
	
	;create the global callback vector if necessary
	cmp dword[terminal_count], 0
	jg terminal_create_register_vector_already_created
		push 8
		push registered_callbacks
		call tsVector_init
	terminal_create_register_vector_already_created:
	inc dword[terminal_count]
	
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
	
	;destroy the callback vector if necessary
	dec dword[terminal_count]
	jnz terminal_destroy_skip_register_vector_destruction
		push registered_callbacks
		call tsVector_destroy
	terminal_destroy_skip_register_vector_destruction:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
terminal_open:
	push ebp
	mov ebp, esp
	
	;clear the written line
	mov eax, dword[ebp+8]
	mov eax, dword[eax+48]
	mov byte[eax], 0
	
	;recalculate the content
	push dword[ebp+8]
	call terminal_recalculate_internal
	
	;set the terminal as visible
	mov eax, dword[ebp+8]
	push 0
	push 69
	push dword[eax+4]
	call uiElement_setStatus
	
	;register the callback
	push dword[ebp+8]
	push dword[ebp+12]
	push registered_callbacks
	call tsVector_pushBack
	
	push terminal_charCallback_internal
	push dword[ebp+12]
	call [glfwSetCharCallback]
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
terminal_close:
	push ebp
	mov ebp, esp
	
	;unregister the callback
	push 0
	push dword[ebp+12]
	call [glfwSetCharCallback]
	
	push dword[ebp+8]
	push terminal_close_unregister_helper
	push registered_callbacks
	call tsVector_removeCustom
	jmp terminal_close_unregister_done
	terminal_close_unregister_helper:		;int func({GLFWWindow*, Terminal*}*, Terminal*)
		xor eax, eax
		mov ecx, dword[esp+4]
		mov edx, dword[esp+8]
		cmp dword[ecx+4], edx
		je terminal_close_unregister_helper_end
			mov eax, 69
		terminal_close_unregister_helper_end:
		ret
	terminal_close_unregister_done:
	
	;turn off the visibility of the terminal
	mov eax, dword[ebp+8]
	push 0
	push 0
	push dword[eax+4]
	call uiElement_setStatus
	
	;save the value of the written line if desired
	test dword[ebp+16], 0xffffffff
	jz terminal_close_no_save
		;alloc the saved line and copy the data from the written line
		mov eax, dword[ebp+8]
		push dword[eax+48]
		call my_strlen
		inc eax
		push eax
		call my_malloc
		
		mov ecx, dword[ebp+8]
		push dword[ecx+48]
		push eax
		call my_strcpy
		mov ecx, dword[ebp+8]
		add ecx, 16
		push 1
		push ecx
		call vector_insert
		
		;remove the oldest history line if necessary
		mov eax, dword[ebp+8]
		mov ecx, dword[eax+32]
		cmp dword[eax+16], ecx
		jle terminal_close_save_no_delete
			add eax, 16
			push ecx
			push eax
			call vector_remove_at
		terminal_close_save_no_delete:
		
	terminal_close_no_save:
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
terminal_processInput:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;content changed		4
	
	mov dword[ebp-4], 0
	
	;check for character input
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
;internal functinos	-----------------------------------

;if no terminal is mapped to the window, nothing happens
;otherwise the character is processed and if relevant, the current line is modified
;void terminal_charCallback_internal(GLFWWindow* pwindow, uint character)
terminal_charCallback_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4		;terminal			4
	sub esp, 4		;uppercase char		8
	
	;check if the terminal is registered
	push registered_callbacks
	call tsVector_lock
	
	push dword[ebp+20]
	push terminal_charCallback_internal_search_helper
	push registered_callbacks
	call tsVector_search
	cmp eax, -1
	je terminal_charCallback_internal_not_registered
	jmp terminal_charCallback_internal_registered
	
		terminal_charCallback_internal_search_helper:	;int func({GLFWWindow*, Terminal*}* pelement, GLFWWindow* pwindow)
			mov eax, 69
			mov ecx, dword[esp+4]
			mov edx, dword[esp+8]
			cmp dword[ecx], edx
			jne terminal_charCallback_internal_search_helper_end
				xor eax, eax
			terminal_charCallback_internal_search_helper_end:
			ret
		
	terminal_charCallback_internal_registered:
		;get the terminal
		push eax
		push registered_callbacks
		call tsVector_at
		mov eax, dword[eax+4]
		mov dword[ebp-4], eax
		
		;unlock the vector
		push registered_callbacks
		call tsVector_unlock
		
		jmp terminal_charCallback_internal_search_done
	
	terminal_charCallback_internal_not_registered:
		;unlcok the vector and flee
		push registered_callbacks
		call tsVector_unlock
		jmp terminal_charCallback_internal_end
		
	terminal_charCallback_internal_search_done:
	
	;transform the character
	push dword[ebp+24]
	call ctype_toUpper
	mov dword[ebp-8], eax
	
	;check if the character is relevant
	mov eax, dword[ebp-8]
	cmp eax, 128
	jae terminal_charCallback_internal_end
	cmp eax, 8
	je terminal_charCallback_internal_handleBackspace
	cmp eax, 10
	je terminal_charCallback_internal_handleEnter
	jmp terminal_charCallback_internal_handleRest
	terminal_charCallback_internal_handleBackspace:
		;check if there is anything in the current line
		mov ebx, dword[ebp-4]
		push dword[ebx+48]
		call my_strlen
		test eax, eax
		jz terminal_charCallback_internal_end
		
		;shorten the line and update the ui
		mov ecx, dword[ebx+48]
		mov byte[ecx+eax-1], 0
		
		push ebx
		call terminal_recalculateWritten_internal
		
		jmp terminal_charCallback_internal_end
		
	terminal_charCallback_internal_handleEnter:
		;TODO: parse statement
		
		;close the terminal an save the current line if necessary
		mov ebx, dword[ebp-4]
		push dword[ebx+48]
		call my_strlen
		push eax
		push dword[ebp+20]
		push ebx
		call terminal_close
		
		jmp terminal_charCallback_internal_end
	
	terminal_charCallback_internal_handleRest:
		;check if the character is of alphanumerical type or space
		push dword[ebp-8]
		call ctype_isAlnum
		test eax, eax
		jnz terminal_charCallback_internal_isKosher
		cmp dword[ebp-8], 32		;is space?
		je terminal_charCallback_internal_isKosher
			jmp terminal_charCallback_internal_end
		terminal_charCallback_internal_isKosher:
		
		;check if there is space left in the current line
		mov ebx, dword[ebp-4]
		push dword[ebx+48]
		call my_strlen
		cmp dword[ebx+52], eax
		jge terminal_charCallback_internal_end
		
		;append the character and update the displayed written line
		mov ecx, dword[ebx+48]
		mov edx, dword[ebp-8]
		mov byte[ecx+eax], dl
		mov byte[ecx+eax+1], 0
		
		push dword[ebp-4]
		call terminal_recalculateWritten_internal
		jmp terminal_charCallback_internal_end
		
	
	terminal_charCallback_internal_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret

;recalculates the content of the terminal based on the history
;the previous content is deleted
;void terminal_recalculate_internal(Terminal* terminal)
terminal_recalculate_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4		;background width			4
	sub esp, 4		;background height			8
	sub esp, 4		;current x pos				12
	sub esp, 4		;current y pos				16
	sub esp, 4		;delta y pos				20
	
	sub esp, 4		;isCurrentLine helper		24
	
	mov dword[ebp-24], 69
	
	;delete the previous menu texts
	mov eax, dword[ebp+20]
	push dword[eax+4]
	call uiElement_getChildren
	mov ebx, eax				;vector in ebx
	xor edi, edi				;index in edi
	terminal_recalculate_internal_delete_loop_start:
		mov eax, dword[ebp+20]
		
		mov esi, dword[ebx+12]
		mov esi, dword[esi+4*edi]
		cmp esi, dword[eax+4]
		je terminal_recalculate_internal_delete_loop_no_delete	;don't delete the background
			;deletable
			push esi
			call uiElement_destroy
			add esp, 4
			jmp terminal_recalculate_internal_delete_loop_continue
		
		terminal_recalculate_internal_delete_loop_no_delete:
			inc edi
		
		terminal_recalculate_internal_delete_loop_continue:
		cmp edi, dword[ebx]
		jl terminal_recalculate_internal_delete_loop_start
		
	
	;calculate the background size
	mov eax, dword[ebp+20]
	mov ecx, dword[FONT_WIDTH]
	add ecx, dword[FONT_SPACING]
	imul ecx, dword[eax+52]
	sub ecx, dword[FONT_SPACING]
	add ecx, dword[PADDING_HORIZONTAL]
	add ecx, dword[PADDING_HORIZONTAL]
	mov dword[ebp-4], ecx
	
	mov ecx, dword[eax+16]
	inc ecx							;for the currently typed line
	mov edx, dword[FONT_HEIGHT]
	add edx, dword[LINE_SPACING]
	imul ecx, edx
	sub ecx, dword[LINE_SPACING]
	add ecx, dword[PADDING_VERTICAL]
	add ecx, dword[PADDING_VERTICAL]
	mov dword[ebp-8], ecx
	
	;calculate the current positions and the delta y
	mov ecx, dword[FONT_HEIGHT]
	add ecx, dword[LINE_SPACING]
	mov dword[ebp-20], ecx
	
	mov ecx, dword[PADDING_HORIZONTAL]
	mov dword[ebp-12], ecx
	mov edx, dword[PADDING_VERTICAL]
	mov dword[ebp-16], edx
	
	;add the current line to the history temporarily
	mov eax, dword[ebp+20]
	lea ecx, [eax+16]
	push dword[eax+48]
	push 0
	push ecx
	call vector_insert
	
	;create the new texts
	mov eax, dword[ebp+20]
	mov esi, dword[eax+28]		;current history line in esi
	mov edi, dword[eax+16]		;index in edi
	cmp edi, 0
	jle terminal_recalculate_internal_create_loop_end
	terminal_recalculate_internal_create_loop_start:
		push dword[UI_TEXT]
		call uiElement_create
		add esp, 4
		mov ebx, eax
		
		mov eax, dword[ebp+20]
		push dword[eax+4]
		push ebx
		call uiElement_setParent
		add esp, 8
		
		push 0
		push 0
		push ebx
		call uiElement_setPosition
		call uiElement_setSize
		add esp, 12
		
		push word[UI_BOTTOM]
		push word[UI_LEFT]
		push ebx
		call uiElement_setAnchor
		call uiElement_setPivot
		add esp, 8
		
		push dword[esi]
		push ebx
		call uiText_setText
		add esp, 8
		
		push dword[FONT_HEIGHT]
		push dword[FONT_WIDTH]
		push ebx
		call uiText_setFontSize
		add esp, 12
		
		push dword[FONT_SPACING]
		push ebx
		call uiText_setSpacing
		add esp, 8
		
		push word[UI_TEXT_ALIGN_BOTTOM]
		push word[UI_TEXT_ALIGN_LEFT]
		push ebx
		call uiText_setTextAlignment
		add esp, 8
		
		
		mov eax, HISTORY_LINE_COLOUR
		test dword[ebp-24], 0xffffffff
		jz terminal_recalculate_internal_create_loop_not_written_line
			mov eax, WRITTEN_LINE_COLOUR
			mov dword[ebp-24], 0
		terminal_recalculate_internal_create_loop_not_written_line:	
		push dword[eax+12]
		push dword[eax+8]
		push dword[eax+4]
		push dword[eax]
		push ebx
		call uiText_setColour
		add esp, 20
		
		
		add esi, 4
		dec edi
		jnz terminal_recalculate_internal_create_loop_start
	
	terminal_recalculate_internal_create_loop_end:
	
	;remove the current line from the history
	mov eax, dword[ebp+20]
	lea ecx, [eax+16]
	push dword[eax+48]
	push ecx
	call vector_remove
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
	
;updates the written line text
;assumes that a call of terminal_recalculate_internal preceeds the call of this function (no call is necessary before every call of this function, but at least before the first one)
;additionally it is also assumes, that the content of the terminal was not tampered with since the call of terminal_recalculate_internal
;void terminal_recalculateWritten_internal(Terminal* terminal)
terminal_recalculateWritten_internal:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call uiElement_getChildren
	
	mov ecx, dword[eax+12]
	mov edx, dword[ebp+8]
	push dword[edx+48]
	push dword[ecx+4]			;only the background is before the written line
	call uiText_setText
	
	mov esp, ebp
	pop ebp
	ret