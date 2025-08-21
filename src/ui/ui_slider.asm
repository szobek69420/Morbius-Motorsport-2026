[BITS 32]

;layout:
;struct UISlider{
;	UIElement generalPart;		0
;	UIImage* fill;				192
;	UIImage* overlay;			196
;	UIImage* knob;				200
;	padding of 8 bytes
;	float value;				212
;	float minValue, maxValue;	216
;	int onlyInteger;			224
;	void (*onValueChanged)(UISlider* slider, void* param);	228
;	void* param;
;}	236 bytes

section .rodata use32
	test_text db "a larissza az nem lany",10,0
	
	print_float_nl db "%f",10,0
	
	error_no_possible_integer db "uiSlider_setOnlyInteger: there is no integer value between minValue (%f) and maxValue (%f), abort",10,0

	DEFAULT_SLIDER_WIDTH dd 200
	DEFAULT_SLIDER_HEIGHT dd 30
	
	ONE dd 1.0

	default_fill_texture_path db "sprites/ui/ui_default/ui_slider/ui_slider_fill_default.bmp",0
	default_overlay_texture_path db "sprites/ui/ui_default/ui_slider/ui_slider_overlay_default.bmp",0
	default_knob_texture_path db "sprites/ui/ui_default/ui_slider/ui_slider_knob_default.bmp",0

section .text use32

	global uiSlider_create			;UISlider* uiSlider_create()
	
	global uiSlider_getFill			;UIImage* uiSlider_getFill(UISlider* slider)
	global uiSlider_getOverlay		;UIImage* uiSlider_getOverlay(UISlider* slider)
	global uiSlider_getKnob			;UIImage* uiSlider_getKnob(UISlider* slider)
	
	global uiSlider_getValue		;float uiSlider_getValue(UISlider* slider)	//pushes the result onto the FPU stack
	global uiSlider_setValue		;void uiSlider_setValue(UISlider* slider, float value)
	
	global uiSlider_setMinValue		;void uiSlider_setMinValue(UISlider* slider, float minValue)
	global uiSlider_setMaxValue		;void uiSlider_setMaxValue(UISlider* slider, float maxValue)
	
	;returns 0 if successful
	;void uiSlider_setOnlyInteger(UISlider* slider, int onlyInteger)
	global uiSlider_setOnlyInteger
	
	global uiSlider_setOnValueChanged	;void uiSlider_setOnValueChanged(UISlider* slider, void (*onValueChanged)(UISlider*, void* param), void* param)
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern math_clamp
	
	extern input_mousePosition
	
	extern uiElement_create
	extern uiElement_initGeneralPart
	extern uiElement_screenToLocal
	extern uiElement_setParent
	extern uiElement_setStatus
	extern uiElement_setSize
	extern uiElement_setPosition
	extern uiElement_setAnchor
	extern uiElement_setPivot
	extern uiElement_setOnHold
	extern uiImage_setTexture
	extern UI_IMAGE
	extern UI_CENTER
	extern UI_LEFT
	extern UI_STRETCH
	
uiSlider_create:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;slider			4
	sub esp, 4			;fill			8
	sub esp, 4			;overlay		12
	sub esp, 4			;knob			16
	
	;alloc space
	push 236
	call my_malloc
	mov dword[ebp-4], eax
	
	;init general part
	push eax
	call uiElement_initGeneralPart
	
	;set values
	mov eax, dword[ebp-4]
	mov dword[eax+212], 0
	mov dword[eax+216], 0
	mov ecx, dword[ONE]
	mov dword[eax+220], ecx
	
	mov dword[eax+224], 0
	
	mov dword[eax+228], 0
	mov dword[eax+232], 0
	
	;set layout things
	push dword[DEFAULT_SLIDER_HEIGHT]
	push dword[DEFAULT_SLIDER_WIDTH]
	push dword[ebp-4]
	call uiElement_setSize
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[ebp-4]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	;set functions
	push 0
	push uiSlider_onMouseHold
	push dword[ebp-4]
	call uiElement_setOnHold
	
	push 69
	push 69
	push dword[ebp-4]
	call uiElement_setStatus
	
	;create fill
	push dword[UI_IMAGE]
	call uiElement_create
	mov dword[ebp-8], eax
	
	push 5
	push 0
	push dword[ebp-8]
	call uiElement_setSize
	call uiElement_setPosition
	
	push word[UI_STRETCH]
	push word[UI_STRETCH]
	push dword[ebp-8]
	call uiElement_setAnchor
	
	push dword[ebp-4]
	push dword[ebp-8]
	call uiElement_setParent
	
	push default_fill_texture_path
	push dword[ebp-8]
	call uiImage_setTexture
	
	
	;create overlay
	push dword[UI_IMAGE]
	call uiElement_create
	mov dword[ebp-12], eax
	
	push 5
	push 0
	push dword[ebp-12]
	call uiElement_setSize
	call uiElement_setPosition
	
	push word[UI_STRETCH]
	push word[UI_STRETCH]
	push dword[ebp-12]
	call uiElement_setAnchor
	
	push dword[ebp-4]
	push dword[ebp-12]
	call uiElement_setParent
	
	push default_overlay_texture_path
	push dword[ebp-12]
	call uiImage_setTexture
	
	;create knob
	push dword[UI_IMAGE]
	call uiElement_create
	mov dword[ebp-16], eax
	
	push dword[DEFAULT_SLIDER_HEIGHT]
	push dword[DEFAULT_SLIDER_HEIGHT]
	push dword[ebp-16]
	call uiElement_setSize
	
	push 0
	push 0
	push dword[ebp-16]
	call uiElement_setPosition
	
	push word[UI_CENTER]
	push word[UI_LEFT]
	push dword[ebp-16]
	call uiElement_setAnchor
	
	push word[UI_CENTER]
	push word[UI_CENTER]
	push dword[ebp-16]
	call uiElement_setPivot
	
	push dword[ebp-4]
	push dword[ebp-16]
	call uiElement_setParent
	
	push default_knob_texture_path
	push dword[ebp-16]
	call uiImage_setTexture
	
	;set the children variables
	mov eax, dword[ebp-4]
	
	mov ecx, dword[ebp-8]
	mov dword[eax+192], ecx
	mov edx, dword[ebp-12]
	mov dword[eax+196], edx
	mov ecx, dword[ebp-16]
	mov dword[eax+200], ecx
	
	;recalculate
	push dword[ebp-4]
	call uiSlider_recalculateLayout_internal
	
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiSlider_getFill:
	mov eax, dword[esp+4]
	mov eax, dword[eax+192]
	ret
	
uiSlider_getOverlay:
	mov eax, dword[esp+4]
	mov eax, dword[eax+196]
	ret
	
uiSlider_getKnob:
	mov eax, dword[esp+4]
	mov eax, dword[eax+200]
	ret
	
	
uiSlider_getValue:
	mov eax, dword[esp+4]
	fld dword[eax+212]
	ret
	
uiSlider_setValue:
	push ebp
	mov ebp, esp
	
	;calculate value
	mov eax, dword[ebp+8]
	push dword[eax+220]
	push dword[eax+216]
	push dword[ebp+12]
	call math_clamp
	mov eax, dword[ebp+8]
	fstp dword[eax+212]
	
	;refresh the slider
	push dword[ebp+8]
	call uiSlider_recalculateLayout_internal
	
	mov esp, ebp
	pop ebp
	ret
	

uiSlider_setMinValue:
	push ebp
	mov ebp, esp
	
	;set the min value
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	mov dword[eax+216], ecx
	
	;recalculate everything
	push 0
	push dword[ebp+8]
	call uiSlider_getValue
	fstp dword[esp+4]
	call uiSlider_setValue
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiSlider_setMaxValue:
	push ebp
	mov ebp, esp
	
	;set the max value
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp+12]
	mov dword[eax+220], ecx
	
	;recalculate everything
	push 0
	push dword[ebp+8]
	call uiSlider_getValue
	fstp dword[esp+4]
	call uiSlider_setValue
	
	mov esp, ebp
	pop ebp
	ret


uiSlider_setOnlyInteger:
	push ebp
	mov ebp, esp
	
	sub esp, 4		;helper min		4
	sub esp, 4		;helper max		8
	sub esp, 4		;return value	12
	
	mov dword[ebp-12], 0
	
	test dword[ebp+12], 0xffffffff
	jnz uiSlider_setOnlyInteger_only_integer
		;not integer, no complications
		mov eax, dword[ebp+8]
		mov dword[eax+224], 0
		jmp uiSlider_setOnlyInteger_end
		
	uiSlider_setOnlyInteger_only_integer:
		;check if there is an integer between minValue and maxValue
		mov eax, dword[ebp+8]
		
		mov ecx, dword[eax+216]
		xor ecx, dword[eax+220]
		test ecx, 0x80000000
		jnz uiSlider_setOnlyInteger_only_integer_alles_gut	;different signs
		
		mov ecx, dword[eax+216]
		and ecx, 0x7fffffff
		mov dword[ebp-4], ecx
		mov edx, dword[eax+220]
		and edx, 0x7fffffff
		mov dword[ebp-8], edx
		fld dword[ebp-4]
		fistp dword[ebp-4]
		fld dword[ebp-8]
		fistp dword[ebp-8]
		mov ecx, dword[ebp-4]
		cmp ecx, dword[ebp-8]
		jne uiSlider_setOnlyInteger_only_integer_alles_gut	;(int)abs(minValue) != (int)abs(maxValue)
			;no integer between minvalue and max value, abort
			push dword[eax+220]
			push dword[eax+216]
			push error_no_possible_integer
			call my_printf
			
			mov dword[ebp-12], 69
			jmp uiSlider_setOnlyInteger_end
			
		uiSlider_setOnlyInteger_only_integer_alles_gut:
			;set flag
			mov dword[eax+224], 69
			
			;recalculate value
			push dword[ebp+8]
			call uiSlider_roundValueToInteger_internal
			
	uiSlider_setOnlyInteger_end:
	mov eax, dword[ebp-12]			;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
uiSlider_setOnValueChanged:
	mov eax, dword[esp+4]
	
	mov ecx, dword[esp+8]
	mov edx, dword[esp+12]
	mov dword[eax+228], ecx
	mov dword[eax+232], edx
	
	ret
	

	
;internal functinos	-------------------------------------------------------------------

;void uiSlider_onMouseHold(UISlider* slider, void* ignoredParam)
uiSlider_onMouseHold:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;previous value		4
	sub esp, 4			;new value			8

	
	;get previous value
	push dword[ebp+8]
	call uiSlider_getValue
	fstp dword[ebp-4]
	
	;refresh slider
	push dword[ebp+8]
	call uiSlider_calculateValue_internal
	call uiSlider_recalculateLayout_internal
	
	;check if the value changed
	push dword[ebp+8]
	call uiSlider_getValue
	fstp dword[ebp-8]
	
	mov eax, dword[ebp+8]
	test dword[eax+228], 0xffffffff
	jz uiSlider_onMouseHold_no_value_change
	mov ecx, dword[ebp-4]
	cmp ecx, dword[ebp-8]
	je uiSlider_onMouseHold_no_value_change
		;value changed
		push dword[eax+232]
		push eax
		call dword[eax+228]
	
	uiSlider_onMouseHold_no_value_change:
	
	mov esp, ebp
	pop ebp
	ret
	

;sets the value based on the mouse position
;void uiSlider_calculateValue_internal(UISlider* slider)
uiSlider_calculateValue_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;cursor y		4
	sub esp, 4			;cursor x		8
	sub esp, 4			;temp value		12
	
	;get cursor position
	lea eax, [ebp-8]
	lea ecx, [ebp-4]
	push ecx
	push eax
	call input_mousePosition
	
	;convert it to local cursor position
	lea eax, [ebp-8]
	push eax
	push dword[ebp-4]
	push dword[ebp-8]
	push dword[ebp+8]
	call uiElement_screenToLocal
	
	;scale it to [minValue; maxValue]
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-8]
	
	test ecx, 0x80000000
	jz uiSlider_calculateValue_internal_not_under_min
		xor ecx, ecx
	uiSlider_calculateValue_internal_not_under_min:
	cmp ecx, dword[eax+52]
	jle uiSlider_calculateValue_internal_not_over_max
		mov ecx, dword[eax+52]
	uiSlider_calculateValue_internal_not_over_max:
	mov dword[ebp-12], ecx
	
	fild dword[ebp-12]
	fidiv dword[eax+52]
	fstp dword[ebp-12]		;currently in [0;1]
	
	movss xmm0, dword[eax+216]
	movss xmm1, dword[eax+220]
	subss xmm1, xmm0
	mulss xmm1, dword[ebp-12]
	addss xmm1, xmm0
	movss dword[ebp-12], xmm1
	
	;save the new value
	mov eax, dword[ebp+8]
	mov ecx, dword[ebp-12]
	mov dword[eax+212], ecx
	
	;round it to an integer if necessary
	mov eax, dword[ebp+8]
	test dword[eax+224], 0xffffffff
	jz uiSlider_calculateValue_internal_not_only_integer
		push eax
		call uiSlider_roundValueToInteger_internal
	uiSlider_calculateValue_internal_not_only_integer:
	
	mov esp, ebp
	pop ebp
	ret
	
	
;recalculates the fill and knob positions based on the value
;void uiSlider_recalculateLayout_internal(UISlider* slider)
uiSlider_recalculateLayout_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;value mapped to [0;1]	4
	sub esp, 4			;goal x pos				8
	
	;map the value to [0;1]
	mov eax, dword[ebp+8]
	movss xmm0, dword[eax+216]
	movss xmm1, dword[eax+220]
	movss xmm2, dword[eax+212]
	subss xmm1, xmm0
	subss xmm2, xmm0
	divss xmm2, xmm1
	movss dword[ebp-4], xmm2
	
	;calculate the goal x position
	fld dword[ebp-4]
	fimul dword[eax+52]
	fistp dword[ebp-8]
	
	;set the knob position
	push 0
	push dword[ebp-8]
	push dword[ebp+8]
	call uiSlider_getKnob
	mov dword[esp], eax
	call uiElement_setPosition
	
	;set the fill position
	mov eax, dword[ebp+8]
	mov ecx, dword[eax+52]
	sub ecx, dword[ebp-8]
	push 0
	push ecx
	push dword[ebp+8]
	call uiSlider_getFill
	mov dword[esp], eax
	mov ecx, dword[eax+12]
	mov dword[esp+8], ecx		;keep the y size
	call uiElement_setSize
	
	mov esp, ebp
	pop ebp
	ret
	
;rounds the value of the slider to an integer value within [minValue; maxValue]
;void uiSlider_roundValueToInteger_internal(UISlider* slider)
uiSlider_roundValueToInteger_internal:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;temp value		4
	
	;round the value
	mov eax, dword[ebp+8]
	fld dword[eax+212]
	frndint
	fstp dword[ebp-4]
	
	;check if it is valid
	movss xmm0, dword[ebp-4]
	ucomiss xmm0, dword[eax+216]
	jae uiSlider_roundValueToInteger_internal_no_underflow
		addss xmm0, dword[ONE]
	uiSlider_roundValueToInteger_internal_no_underflow:
	ucomiss xmm0, dword[eax+220]
	jbe uiSlider_roundValueToInteger_internal_no_overflow
		subss xmm0, dword[ONE]
	uiSlider_roundValueToInteger_internal_no_overflow:
	movss dword[eax+212], xmm0
	
	mov esp, ebp
	pop ebp
	ret