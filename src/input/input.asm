[BITS 32]

;struct KeyEvent{
;	int keyCode;
;	int pressed;
;}

;struct MouseButtonEvent{
;	int mouseButton;
;	int pressed;
;}

;struct MouseMoveEvent{
;	int x, y;
;}

;struct MouseScrollEvent{
;	int x, y;
;}

;struct Event{
;	int eventType;
;	union{
;		KeyEvent;
;		MouseButtonEvent;
;		MouseMoveEvent;
;		MouseScrollEvent;
;	}
;}   total size is 20 bytes (8 bytes reserved just in case)

NO_EVENT equ 0
KEY_EVENT equ 1
MOUSE_BUTTON_EVENT equ 2
MOUSE_MOVE_EVENT equ 3
MOUSE_SCROLL_EVENT equ 4

EVENT_QUEUE_MAX_SIZE equ 50

section .rodata use32
	test_text db "globus",10,0
	print_two_ints db "%d %d",10,0

section .bss use32
	previous_key_state resb 349		;348 is GLFW_KEY_LAST
	current_key_state resb 349
	
	previous_mouse_button_state resb 8	;7 is GLFW_MOUSE_BUTTON_LAST
	current_mouse_button_state resb 8
	
	previous_mouse_x resb 4		;int
	previous_mouse_y resb 4
	current_mouse_x resb 4
	current_mouse_y resb 4
	
	
	mouse_scroll_delta_x resb 4		;int
	mouse_scroll_delta_y resb 4
	
	event_queue_first_index resb 4	;int
	event_queue_size resb 4			;int
	event_queue_data resb 1000		;Event*, EVENT_QUEUE_MAX_SIZE*20 bytes


section .text use32

	global input_init		;void input_init()
	global input_update		;void input_update()
	
	;void input_pushEvent(Event event)
	;void input_popEvent(Event* buffer), returns a NO_EVENT if empty
	;int input_queueFull()
	;int input_queueEmpty()
	;void input_processEvent(Event event)
	
	global input_keyPressed		;int input_keyPressed(int key)
	global input_keyHeld		;int input_keyHeld(int key)
	global input_keyReleased	;int input_keyReleased(int key)
	
	global input_mouseButtonPressed		;int input_mouseButtonPressed(int mouseButton)
	global input_mouseButtonHeld		;int input_mouseButtonHeld(int mouseButton)
	global input_mouseButtonReleased	;int input_mouseButtonReleased(int mouseButton)
	
	global input_keyCallback			;void input_keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods)
	global input_mouseButtonCallback	;void input_mouseButtonCallback(GLFWwindow* window, int button, int action, int mods)
	global input_mouseMoveCallback		;void input_mouseMoveCallback(GLFWwindow* window, double xpos, double ypos)
	global input_mouseScrollCallback	;void input_mouseScrollCallback(GLFWwindow* window, double xoffset, double yoffset)
	
	global input_mousePosition			;void input_mousePosition(int* x, int* y)
	global input_mouseDeltaPosition		;void input_mouseDeltaPosition(int* x, int* y)
	global input_mouseScrollDelta		;void input_mouseScrollDelta(int* x, int* y)
	
	global input_setMousePosition		;void input_setMousePosition(GLFWWindow* window, int x, int y)
	
	extern my_memset
	extern my_memcpy
	extern my_printf
	
	extern GLFW_PRESS
	extern GLFW_RELEASE
	
	extern GLFW_KEY_LAST
	extern GLFW_MOUSE_BUTTON_LAST
	
	extern glfwSetCursorPos
	
input_init:
	push ebp
	mov ebp, esp
	
	push 349
	push 0
	push previous_key_state
	call my_memset
	add esp, 12
	
	push 349
	push 0
	push current_key_state
	call my_memset
	add esp, 12
	
	push 8
	push 0
	push previous_mouse_button_state
	call my_memset
	add esp, 12
	
	push 8
	push 0
	push current_mouse_button_state
	call my_memset
	add esp, 12
	
	mov dword[previous_mouse_x], 0
	mov dword[previous_mouse_y], 0
	mov dword[current_mouse_x], 0
	mov dword[current_mouse_y], 0
	mov dword[mouse_scroll_delta_x], 0
	mov dword[mouse_scroll_delta_y], 0
	
	;init event queue
	push 1000
	push 0
	push event_queue_data
	call my_memset
	add esp, 12
	
	mov dword[event_queue_first_index], 0
	mov dword[event_queue_size], 0
	
	mov esp, ebp
	pop ebp
	ret
	
	
input_update:
	push ebp
	mov ebp, esp
	
	push 349
	push current_key_state
	push previous_key_state
	call my_memcpy
	add esp, 12
	
	push 8
	push current_mouse_button_state
	push previous_mouse_button_state
	call my_memcpy
	add esp, 12
	
	mov ecx, dword[current_mouse_x]
	mov dword[previous_mouse_x], ecx
	
	mov ecx, dword[current_mouse_y]
	mov dword[previous_mouse_y], ecx
	
	mov dword[mouse_scroll_delta_x], 0
	mov dword[mouse_scroll_delta_y], 0
	
	;process events
	sub esp, 20			;event buffer
	input_update_process_loop_start:
		;check for event and exit if there is none left
		mov eax, esp
		push eax
		call input_popEvent
		add esp, 4
		
		cmp dword[esp], NO_EVENT
		je input_update_process_loop_end
	
		
		;process the queried event
		call input_processEvent
		
		jmp input_update_process_loop_start
		
	input_update_process_loop_end:
	add esp, 20
	
	mov esp, ebp
	pop ebp
	ret
	
input_keyPressed:
	push ebp
	mov ebp, esp
	
	xor eax, eax
	
	;check if it is a valid keycode
	mov ecx, dword[ebp+8]
	cmp ecx, 0
	jl input_keyPressed_end
	cmp ecx, dword[GLFW_KEY_LAST]
	jg input_keyPressed_end
	
	mov dl, byte[ecx+previous_key_state]
	test dl, dl
	jnz input_keyPressed_end		;the key was already down in the previous frame
	
	mov al, byte[ecx+current_key_state]
	
	input_keyPressed_end:
	mov esp, ebp
	pop ebp
	ret
	
input_keyHeld:
	push ebp
	mov ebp, esp
	
	xor eax, eax
	
	;check if it is a valid keycode
	mov ecx, dword[ebp+8]
	cmp ecx, 0
	jl input_keyHeld_end
	cmp ecx, dword[GLFW_KEY_LAST]
	jg input_keyHeld_end
	
	mov al, byte[ecx+current_key_state]
	
	input_keyHeld_end:
	mov esp, ebp
	pop ebp
	ret
	
input_keyReleased:
	push ebp
	mov ebp, esp
	
	xor eax, eax
	
	;check if it is a valid keycode
	mov ecx, dword[ebp+8]
	cmp ecx, 0
	jl input_keyReleased_end
	cmp ecx, dword[GLFW_KEY_LAST]
	jg input_keyReleased_end
	
	mov dl, byte[ecx+current_key_state]
	test dl, dl
	jnz input_keyReleased_end		;the key is (still) down
	
	mov al, byte[ecx+previous_key_state]
	
	input_keyReleased_end:
	mov esp, ebp
	pop ebp
	ret
	
	
input_mouseButtonPressed:
	push ebp
	mov ebp, esp
	
	xor eax, eax
	
	;check if it is a valid mouse button code
	mov ecx, dword[ebp+8]
	cmp ecx, 0
	jl input_mouseButtonPressed_end
	cmp ecx, dword[GLFW_MOUSE_BUTTON_LAST]
	jg input_mouseButtonPressed_end
	
	mov dl, byte[ecx+previous_mouse_button_state]
	test dl, dl
	jnz input_mouseButtonPressed_end		;the mouse button was already down in the previous frame
	
	mov al, byte[ecx+current_mouse_button_state]
	
	input_mouseButtonPressed_end:
	mov esp, ebp
	pop ebp
	ret
	
	
input_mouseButtonHeld:
	push ebp
	mov ebp, esp
	
	xor eax, eax
	
	;check if it is a valid mouse button code
	mov ecx, dword[ebp+8]
	cmp ecx, 0
	jl input_mouseButtonHeld_end
	cmp ecx, dword[GLFW_MOUSE_BUTTON_LAST]
	jg input_mouseButtonHeld_end
	
	mov al, byte[ecx+current_mouse_button_state]
	
	input_mouseButtonHeld_end:
	mov esp, ebp
	pop ebp
	ret
	
input_mouseButtonReleased:
	push ebp
	mov ebp, esp
	
	xor eax, eax
	
	;check if it is a valid mouse button code
	mov ecx, dword[ebp+8]
	cmp ecx, 0
	jl input_mouseButtonReleased_end
	cmp ecx, dword[GLFW_MOUSE_BUTTON_LAST]
	jg input_mouseButtonReleased_end
	
	mov dl, byte[ecx+current_mouse_button_state]
	test dl, dl
	jnz input_mouseButtonReleased_end		;the mouse button is (still) down
	
	mov al, byte[ecx+previous_mouse_button_state]
	
	input_mouseButtonReleased_end:
	mov esp, ebp
	pop ebp
	ret
	
	
input_mousePosition:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	mov ecx, dword[current_mouse_x]
	mov dword[eax], ecx
	
	mov eax, dword[ebp+12]
	mov ecx, dword[current_mouse_y]
	mov dword[eax], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
input_mouseDeltaPosition:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	mov ecx, dword[current_mouse_x]
	sub ecx, dword[previous_mouse_x]
	mov dword[eax], ecx
	
	mov eax, dword[ebp+12]
	mov ecx, dword[current_mouse_y]
	sub ecx, dword[previous_mouse_y]
	mov dword[eax], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
input_mouseScrollDelta:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	mov ecx, dword[mouse_scroll_delta_x]
	mov dword[eax], ecx
	
	mov eax, dword[ebp+12]
	mov ecx, dword[mouse_scroll_delta_y]
	mov dword[eax], ecx
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
input_keyCallback:
	push ebp
	mov ebp, esp
	
	sub esp, 20		;event
	
	mov eax, dword[ebp+20]
	cmp eax, dword[GLFW_PRESS]
	jne input_keyCallback_not_press
	
		mov dword[ebp-20], KEY_EVENT	;event type
		mov ecx, dword[ebp+12]
		mov dword[ebp-16], ecx		;key code
		mov dword[ebp-12], 69		;pressed=true
		call input_pushEvent		;event is already on the stack
		jmp input_keyCallback_end
		
	input_keyCallback_not_press:
	
	cmp eax, dword[GLFW_RELEASE]
	jne input_keyCallback_not_release
		mov dword[ebp-20], KEY_EVENT
		mov ecx, dword[ebp+12]
		mov dword[ebp-16], ecx
		mov dword[ebp-12], 0
		call input_pushEvent		;event is already on the stack
		jmp input_keyCallback_end
	
	input_keyCallback_not_release:
	
	input_keyCallback_end:
	mov esp, ebp
	pop ebp
	ret
	
	
input_mouseButtonCallback:
	push ebp
	mov ebp, esp
	
	sub esp, 20		;event
	
	mov eax, dword[ebp+16]		;action
	cmp eax, dword[GLFW_PRESS]
	jne input_mouseButtonCallback_not_press
		mov dword[ebp-20], MOUSE_BUTTON_EVENT	;event type
		mov ecx, dword[ebp+12]
		mov dword[ebp-16], ecx		;button code
		mov dword[ebp-12], 69		;pressed=true
		call input_pushEvent		;event is already on the stack
		jmp input_mouseButtonCallback_end
		
	input_mouseButtonCallback_not_press:
	
	cmp eax, dword[GLFW_RELEASE]
	jne input_mouseButtonCallback_not_release
		mov dword[ebp-20], MOUSE_BUTTON_EVENT
		mov ecx, dword[ebp+12]
		mov dword[ebp-16], ecx
		mov dword[ebp-12], 0
		call input_pushEvent		;event is already on the stack
		jmp input_mouseButtonCallback_end
	
	input_mouseButtonCallback_not_release:
	
	input_mouseButtonCallback_end:
	mov esp, ebp
	pop ebp
	ret
	
	
input_mouseMoveCallback:
	push ebp
	mov ebp, esp
	
	sub esp, 20		;event
	
	mov dword[ebp-20], MOUSE_MOVE_EVENT		;event type
	
	;convert the doubles to ints
	fld qword[ebp+12]
	fistp dword[ebp-16]
	fld qword[ebp+20]
	fistp dword[ebp-12]
	
	;check if any component in non-zero
	mov ecx, dword[ebp-16]
	or ecx, dword[ebp-12]
	test ecx, ecx
	jz input_mouseMoveCallback_end
		call input_pushEvent
	
	input_mouseMoveCallback_end:
	mov esp, ebp
	pop ebp
	ret
	
input_mouseScrollCallback:
	push ebp
	mov ebp, esp
	
	sub esp, 20		;event
	
	mov dword[ebp-20], MOUSE_SCROLL_EVENT		;event type
	
	;convert the doubles to ints
	fld qword[ebp+12]
	fistp dword[ebp-16]
	fld qword[ebp+20]
	fistp dword[ebp-12]
	
	call input_pushEvent
	
	mov esp, ebp
	pop ebp
	ret
	
input_setMousePosition:
	push ebp
	mov ebp, esp
	
	sub esp, 16		;space for the two double
	
	;convert the ints to doubles
	fild dword[ebp+12]
	fstp qword[ebp-16]
	fild dword[ebp+16]
	fstp qword[ebp-8]
	
	;morb ahead
	push dword[ebp+8]
	call [glfwSetCursorPos]
	add esp, 20
	
	mov esp, ebp
	pop ebp
	ret
	
input_processEvent:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]		;event type in eax
	cmp eax, KEY_EVENT
	jne input_handleEvent_not_key_event
		mov eax, dword[ebp+12]		;key code
		mov ecx, dword[ebp+16]		;is pressed
		add eax, current_key_state
		mov byte[eax], cl
		jmp input_handleEvent_end
	input_handleEvent_not_key_event:
	
	cmp eax, MOUSE_BUTTON_EVENT
	jne input_handleEvent_not_mouse_button_event
		mov eax, dword[ebp+12]		;mouse button code
		mov ecx, dword[ebp+16]		;is pressed
		add eax, current_mouse_button_state
		mov byte[eax], cl
		jmp input_handleEvent_end
	input_handleEvent_not_mouse_button_event:
	
	cmp eax, MOUSE_MOVE_EVENT
	jne input_handleEvent_not_mouse_move_event
		mov eax, dword[ebp+12]		;mouse x
		mov dword[current_mouse_x], eax
		mov eax, dword[ebp+16]		;mouse y
		mov dword[current_mouse_y], eax
		jmp input_handleEvent_end
	input_handleEvent_not_mouse_move_event:
	
	cmp eax, MOUSE_SCROLL_EVENT
	jne input_handleEvent_not_mouse_scroll_event
		mov eax, dword[ebp+12]		;scroll x
		add dword[mouse_scroll_delta_x], eax
		mov eax, dword[ebp+16]		;scroll y
		add dword[mouse_scroll_delta_y], eax
		jmp input_handleEvent_end
	input_handleEvent_not_mouse_scroll_event:
	
	
	input_handleEvent_end:
	mov esp, ebp
	pop ebp
	ret
	
input_queueFull:
	push ebp
	mov ebp, esp
	
	xor eax, eax
	cmp dword[event_queue_size], EVENT_QUEUE_MAX_SIZE
	jne input_queueFull_end
		mov eax, 69
	input_queueFull_end:
	mov esp, ebp
	pop ebp
	ret
	
input_queueEmpty:
	push ebp
	mov ebp, esp
	
	xor eax, eax
	cmp dword[event_queue_size], 0
	jne input_queueEmpty_end
		mov eax, 69
	input_queueEmpty_end:
	mov esp, ebp
	pop ebp
	ret
	
	
input_pushEvent:
	push ebp
	mov ebp, esp
	
	;check if the queue is full
	call input_queueFull
	test eax, eax
	jnz input_pushEvent_end
	
	;add the event to the queue
	mov ecx, dword[event_queue_first_index]
	add ecx, dword[event_queue_size]
	cmp ecx, EVENT_QUEUE_MAX_SIZE
	jl input_pushEvent_no_overflow
		sub ecx, EVENT_QUEUE_MAX_SIZE
	input_pushEvent_no_overflow:
	imul ecx, 20		;20=sizeof(Event)
	add ecx, event_queue_data		;now the address of the desired queue element is in ecx
	
	lea eax, [ebp+8]
	push 20
	push eax
	push ecx
	call my_memcpy
	add esp, 12
	
	inc dword[event_queue_size]
	
	input_pushEvent_end:
	mov esp, ebp
	pop ebp
	ret
	
input_popEvent:
	push ebp
	mov ebp, esp
	
	;check if queue is empty
	call input_queueEmpty
	test eax, eax
	jz input_popEvent_queue_not_empty
		mov ecx, dword[ebp+8]		;Event* in ecx
		mov dword[ecx], NO_EVENT
		mov esp, ebp
		pop ebp
		ret
		
	input_popEvent_queue_not_empty:
	
	;calculate the position of the desired event
	mov eax, dword[event_queue_first_index]
	imul eax, 20
	add eax, event_queue_data
	
	;copy the event into the buffer
	push 20
	push eax
	push dword[ebp+8]
	call my_memcpy
	add esp, 12
	
	;update the attributes of the event queue
	dec dword[event_queue_size]
	
	mov eax, dword[event_queue_first_index]
	inc eax
	cmp eax, EVENT_QUEUE_MAX_SIZE
	jl input_popEvent_no_overflow
		xor eax, eax
	input_popEvent_no_overflow:
	mov dword[event_queue_first_index], eax
	
	
	mov esp, ebp
	pop ebp
	ret