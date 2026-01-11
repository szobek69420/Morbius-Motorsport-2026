[BITS 32]


;layout:
;struct Terminal{
;	int isOpen;				0
;	int maxHistoryLength;	4
;	int maxLineLength;		8
;	GLFWWindow* window;		12
;	padding of 16 bytes
;	queue<char*> history;	32
;	padding of 12 bytes
;	char* currentLine;		64
;	padding of 12 bytes;
;	UIEmpty* root;			80
;	UIImage* background;	84
;}	88 bytes overall

section .rodata use32

	terminal_background_path db "./sprites/ui/ingame/terminal/terminal.bmp",0
	
	TERMINAL_BACKGROUND_COLOUR dd 1.0, 1.0, 1.0, 0.5
	
	print_int_nl db "%d",10,0
	print_char_nl db "%c",10,0
	print_string_nl db "%s",10,0
	
	test_text db "why so serious",10,0
	test_text2 db "why so sus",10,0
	
section .data use32
	terminal_count dd 0
	registered_callbacks dd 0,0		;tsVector<{GLFWWindow*, Terminal*}>

section .text use32

	;initializes the terminal in a closed state
	;Terminal* terminal_create(int maxHistoryLength, int maxLineLength, GLFWWindow* window)
	global terminal_create
	
	global terminal_destroy		;void terminal_destroy(Terminal* terminator)
	
	;opens the terminal (resets the input part and makes the element visible)
	;also recalculates the content
	;void terminal_open(Terminal* terminal)
	global terminal_open
	
	;closes the terminal
	;if desired, saves the written line into the history
	;void terminal_close(Terminal* terminal, int saveWrittenLine)
	global terminal_close
	
	;void terminal_setParent(Terminal* terminal, UIElement* parent)
	global terminal_setParent
	
	;int terminal_isOpen(Terminal* terminal)
	global terminal_isOpen
	
	
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
	extern vector_push_back
	extern vector_insert
	extern vector_pop_back
	extern vector_remove
	extern vector_remove_at
	extern vector_for_each
	extern vector_at
	extern tsVector_init
	extern tsVector_destroy
	extern tsVector_pushBack
	extern tsVector_removeCustom
	extern tsVector_at
	extern tsVector_search
	extern tsVector_lock
	extern tsVector_unlock
	
	extern queue_init
	extern queue_destroy
	extern queue_push
	extern queue_pop
	extern queue_popBack
	extern queue_size
	extern queue_forEach
	extern queue_forEachReversed
	
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
	extern uiImage_setTexture
	extern uiImage_setColour
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
	
	
	;alloc terminal
	push 88
	call my_malloc
	mov dword[ebp-4], eax
	
	;set the properties
	mov eax, dword[ebp-4]
	
	mov dword[eax], 0			;closed initially
	
	mov ecx, dword[ebp+8]
	mov dword[eax+4], ecx
	mov edx, dword[ebp+12]
	mov dword[eax+8], edx
	
	mov dword[eax+64], 0		;current line is NULL
	
	mov ecx, dword[ebp+16]
	mov dword[eax+12], ecx		;window
	
	;create the history
	mov eax, dword[ebp-4]
	add eax, 32
	mov ecx, dword[ebp+8]
	inc ecx
	push ecx
	push 4
	push eax
	call queue_init
	
	;create the ui stuff
	push dword[UI_EMPTY]
	call uiElement_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+80], eax
	
	push 0
	push 0
	push eax
	call uiElement_setStatus
	
	push dword[UI_IMAGE]
	call uiElement_create
	mov ecx, dword[ebp-4]
	mov dword[ecx+84], eax
	
	push dword[ecx+80]
	push dword[ecx+84]
	call uiElement_setParent
	
	mov ecx, dword[ebp-4]
	push terminal_background_path
	push dword[ecx+84]
	call uiImage_setTexture
	
	mov eax, TERMINAL_BACKGROUND_COLOUR
	mov ecx, dword[ebp-4]
	push dword[eax+12]
	push dword[eax+8]
	push dword[eax+4]
	push dword[eax]
	push dword[ecx+84]
	call uiImage_setColour
	
	;init the registered callback vector if necessary
	test dword[terminal_count], 0xffffffff
	jnz terminal_create_skip_registered_init
		push 8
		push registered_callbacks
		call tsVector_init
	
	terminal_create_skip_registered_init:
	
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
	
	;close the terminal if necessary
	mov eax, dword[ebp+20]
	test dword[eax], 0xffffffff
	jz terminal_destroy_skip_close
		push 0
		push eax
		call terminal_close
	terminal_destroy_skip_close:
	
	;destroy the ui
	mov eax, dword[ebp+20]
	push dword[eax+80]
	call uiElement_destroy
	
	;destroy the history
	mov eax, dword[ebp+20]
	add eax, 32
	push 0
	push terminal_destroy_clear_history_helper
	push eax
	call queue_forEach
	call queue_destroy
	
	;free the sus
	push dword[ebp+20]
	call my_free
	
	;deinit the registered callbacks if necessary
	dec dword[terminal_count]
	test dword[terminal_count], 0xffffffff
	jz terminal_destroy_skip_registered_deinit
		push registered_callbacks
		call tsVector_destroy
		
	terminal_destroy_skip_registered_deinit:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	terminal_destroy_clear_history_helper:	;void func(char** pHistoryLine, void* idc)
		mov eax, dword[esp+4]
		push dword[eax]
		call my_free
		add esp, 4
		ret
		
	
	
terminal_open:
	push ebp
	mov ebp, esp
	
	;alloc the written line
	mov eax, dword[ebp+8]
	mov eax, dword[eax+8]
	inc eax
	push eax
	call my_malloc
	mov byte[eax], 0
	mov ecx, dword[ebp+8]
	mov dword[ecx+64], eax
	
	;recalculate content
	push dword[ebp+8]
	call terminal_recalculate_internal
	
	;make the ui part visible
	mov eax, dword[ebp+8]
	push 0
	push 69
	push dword[eax+80]
	call uiElement_setStatus
	
	
	;register the callback
	mov eax, dword[ebp+8]
	push terminal_charCallback_internal
	push dword[eax+12]
	call [glfwSetCharCallback]
	
	mov eax, dword[ebp+8]
	push eax
	push dword[eax+12]
	push registered_callbacks
	call tsVector_pushBack
	
	;set the isopen flag
	mov eax, dword[ebp+8]
	mov dword[eax], 69
	
	mov esp, ebp
	pop ebp
	ret
	
	
terminal_close:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;delete helper		4
	
	;unregister the callback
	mov eax, dword[ebp+8]
	push 0
	push dword[eax+12]
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
			cmp edx, dword[ecx+4]
			je terminal_close_unregister_helper_end
				mov eax, 69
			terminal_close_unregister_helper_end:
			ret
	terminal_close_unregister_done:
	
	;turn off the visibility of the terminal
	mov eax, dword[ebp+8]
	push 0
	push 0
	push dword[eax+80]
	call uiElement_setStatus
	
	;save the line if necessary
	test dword[ebp+12], 0xffffffff
	jz terminal_close_discard_line
		mov eax, dword[ebp+8]
		lea ecx, [eax+32]
		push dword[eax+64]
		push ecx
		call queue_push
		
		;check if the history is full
		call queue_size
		mov ecx, dword[ebp+8]
		cmp eax, dword[ecx+4]
		jle terminal_close_line_stuff_done
		
			lea eax, [ebp-4]
			mov dword[esp+4], eax
			call queue_pop
			
			push dword[ebp-4]
			call my_free
			jmp terminal_close_line_stuff_done
		
	terminal_close_discard_line:
		mov eax, dword[ebp+8]
		push dword[eax+64]
		call my_free
	terminal_close_line_stuff_done:
	
	mov eax, dword[ebp+8]
	mov dword[eax+64], 0
	
	;clear the isopen flag
	mov eax, dword[ebp+8]
	mov dword[eax], 0
	
	mov esp, ebp
	pop ebp
	ret
	
terminal_setParent:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[ebp+12]
	push dword[eax+80]
	call uiElement_setParent
	
	mov esp, ebp
	pop ebp
	ret
	
	
terminal_isOpen:
	mov eax, dword[esp+4]
	mov eax, dword[eax]
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
	jmp terminal_charCallback_internal_handleRest
	terminal_charCallback_internal_handleBackspace:
		;check if there is anything in the currently typed line
		mov ebx, dword[ebp-4]
		push dword[ebx+64]
		call my_strlen
		test eax, eax
		jz terminal_charCallback_internal_end
		
		mov ecx, dword[ebx+64]
		mov byte[ecx+eax-1], 0
		
		;recalculate the current line
		push ebx
		call terminal_recalculateWritten_internal
		
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
		push dword[ebx+64]
		call my_strlen
		cmp eax, dword[ebx+8]
		jge terminal_charCallback_internal_end
		
		;append the character and update the displayed written line
		mov ecx, dword[ebx+64]
		mov edx, dword[ebp-8]
		mov byte[ecx+eax], dl
		mov byte[ecx+eax+1], 0
		
		;recalculate the current line
		push ebx
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
	
	jmp terminal_recalculate_internal_data_end
	
		FONT_WIDTH dd 6
		FONT_HEIGHT dd 8
		FONT_SPACING dd 1
		LINE_SPACING dd 5
		PADDING_HORIZONTAL dd 10
		PADDING_VERTICAL dd 8
		
		WRITTEN_LINE_COLOUR dd 0.0, 1.0, 1.0, 1.0
		HISTORY_LINE_COLOUR dd 1.0, 0.85, 0.0, 1.0
	
	terminal_recalculate_internal_data_end:
	
	sub esp, 4		;background width			4
	sub esp, 4		;background height			8
	sub esp, 4		;current x pos				12
	sub esp, 4		;current y pos				16
	sub esp, 4		;delta y pos				20
	
	sub esp, 4		;isCurrentLine helper		24
	
	mov dword[ebp-24], 69
	
	;delete the previous menu texts
	mov eax, dword[ebp+20]
	push dword[eax+80]
	call uiElement_getChildren
	mov ebx, eax				;vector in ebx
	xor edi, edi				;index in edi
	terminal_recalculate_internal_delete_loop_start:
		mov eax, dword[ebp+20]
		
		mov esi, dword[ebx+12]
		mov esi, dword[esi+4*edi]
		cmp esi, dword[eax+84]
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
		
	
	;set the root's properties
	mov ebx, dword[ebp+20]
	
	push 0
	push 0
	push dword[ebx+80]
	call uiElement_setPosition
	call uiElement_setSize
	
	
	;calculate the background size
	mov ebx, dword[ebp+20]
	mov ecx, dword[FONT_WIDTH]
	add ecx, dword[FONT_SPACING]
	imul ecx, dword[ebx+8]
	sub ecx, dword[FONT_SPACING]
	add ecx, dword[PADDING_HORIZONTAL]
	add ecx, dword[PADDING_HORIZONTAL]
	mov dword[ebp-4], ecx
	
	lea ecx, [ebx+32]
	push ecx
	call queue_size
	inc eax							;for the currently typed line
	mov edx, dword[FONT_HEIGHT]
	add edx, dword[LINE_SPACING]
	imul eax, edx
	sub eax, dword[LINE_SPACING]
	add eax, dword[PADDING_VERTICAL]
	add eax, dword[PADDING_VERTICAL]
	mov dword[ebp-8], eax
	
	;set the background's properties
	mov ebx, dword[ebp+20]
	push 0
	push 0
	push dword[ebx+84]
	call uiElement_setPosition
	push dword[ebp-8]
	push dword[ebp-4]
	push dword[ebx+84]
	call uiElement_setSize
	push word[UI_BOTTOM]
	push word[UI_LEFT]
	push dword[ebx+84]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	;calculate the current positions and the delta y
	mov ecx, dword[FONT_HEIGHT]
	add ecx, dword[LINE_SPACING]
	mov dword[ebp-20], ecx
	
	mov ecx, dword[PADDING_HORIZONTAL]
	mov dword[ebp-12], ecx
	mov edx, dword[PADDING_VERTICAL]
	mov dword[ebp-16], edx
	
	;add the current line to the history temporarily
	mov ebx, dword[ebp+20]
	lea ecx, [ebx+32]
	push dword[ebx+64]
	push ecx
	call queue_push
	
	;create the new texts
	sub esp, 20			;data block
	
	mov ebx, dword[ebp+20]
	mov eax, dword[ebx+80]
	mov dword[esp], eax			;root
	mov ecx, dword[ebx+64]
	mov dword[esp+4], ecx		;current line
	mov edx, dword[ebp-12]
	mov dword[esp+8], edx		;current x pos
	mov eax, dword[ebp-16]
	mov dword[esp+12], eax		;current y pos
	mov ecx, dword[ebp-20]
	mov dword[esp+16], ecx		;delta y pos
	
	mov eax, esp
	lea ecx, [ebx+32]
	push eax
	push terminal_recalculate_internal_create_helper
	push ecx
	call queue_forEachReversed
	jmp terminal_recalculate_internal_create_done
	
	;void func(
	;	char** ptext, 
	;	struct {
	;		UIEmpty* root,
	;		const char* currentLine,
	;		int currentXPos,
	;		int currentYPos,
	;		int deltaYPos
	;	}* pdata
	;)
	terminal_recalculate_internal_create_helper:
		push ebp
		push ebx
		mov ebp, esp
		
		sub esp, 4			;root			4
		sub esp, 8			;current line	8
		
		;unwrap the data
		mov eax, dword[ebp+16]
		mov ecx, dword[eax]
		mov dword[ebp-4], ecx
		mov edx, dword[eax+4]
		mov dword[ebp-8], edx
		
		;create the element and set properties
		push dword[UI_TEXT]
		call uiElement_create
		mov ebx, eax
		
		push dword[ebp-4]
		push ebx
		call uiElement_setParent
		
		mov eax, dword[ebp+16]
		push dword[eax+12]
		push dword[eax+8]
		push ebx
		call uiElement_setPosition
		
		push 0
		push 0
		push ebx
		call uiElement_setSize
		
		push word[UI_BOTTOM]
		push word[UI_LEFT]
		push ebx
		call uiElement_setAnchor
		call uiElement_setPivot
		
		mov eax, dword[ebp+12]
		push dword[eax]
		push ebx
		call uiText_setText
		
		push dword[FONT_HEIGHT]
		push dword[FONT_WIDTH]
		push ebx
		call uiText_setFontSize
		
		push dword[FONT_SPACING]
		push ebx
		call uiText_setSpacing
		
		push word[UI_TEXT_ALIGN_BOTTOM]
		push word[UI_TEXT_ALIGN_LEFT]
		push ebx
		call uiText_setTextAlignment
		
		mov eax, HISTORY_LINE_COLOUR
		mov ecx, dword[ebp+12]
		mov ecx, dword[ecx]
		cmp ecx, dword[ebp-8]
		jne terminal_recalculate_internal_create_loop_not_written_line
			mov eax, WRITTEN_LINE_COLOUR
			mov dword[ebp-24], 0
		terminal_recalculate_internal_create_loop_not_written_line:	
		push dword[eax+12]
		push dword[eax+8]
		push dword[eax+4]
		push dword[eax]
		push ebx
		call uiText_setColour
		
		;update the current y pos
		mov eax, dword[ebp+16]
		mov ecx, dword[eax+16]
		add dword[eax+12], ecx
		
		mov esp, ebp
		pop ebx
		pop ebp
		ret
		
	terminal_recalculate_internal_create_done:
	
	;remove the current line from the history
	mov ebx, dword[ebp+20]
	add ebx, 32
	push 0
	push ebx
	call queue_popBack
	
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
	push dword[eax+80]
	call uiElement_getChildren
	
	mov ecx, dword[eax+12]
	mov edx, dword[ebp+8]
	push dword[edx+64]
	push dword[ecx+4]			;only the background is before the written line
	call uiText_setText
	
	mov esp, ebp
	pop ebp
	ret