[BITS 32]

;struct InventoryUI{
;	UIEmpty* root;			//also contains all of the below as children
;	UIImage* blockDisplays[INVENTORY_HOTBAR_SIZE];
;	UIImage* blockDisplayBackgrounds[INVENTORY_HOTBAR_SIZE];
;	UIImage* blockSelector;
;}		16 bytes overall

%macro INIT_IMAGE 11	;image, parent!, imagePath, posx, posy, scalex, scaley, anchorx, anchory, pivotx, pivoty
	push dword[UI_IMAGE]
	call uiElement_create
	mov dword[%1], eax
	add esp, 4
	
	push %2
	push dword[%1]
	call uiElement_setParent
	add esp, 8
	
	push %5
	push %4
	push dword[%1]
	call uiElement_setPosition
	add esp, 12
	
	push %7
	push %6
	push dword[%1]
	call uiElement_setSize
	add esp, 12
	
	push word[%9]
	push word[%8]
	push dword[%1]
	call uiElement_setAnchor
	add esp, 8
	
	push word[%11]
	push word[%10]
	push dword[%1]
	call uiElement_setPivot
	add esp, 8
	
	push %3
	push dword[%1]
	call uiImage_setTexture
	add esp, 8
%endmacro

section .rodata use32
	SLOT_SIZE equ 96
	
	background_texture_path db "sprites/ui/ingame/inventory/block_bg.bmp",0
	selector_texture_path db "sprites/ui/ingame/inventory/block_selector.bmp",0
	
	HALF dd 0.5
	ONE dd 1.0

section .text use32
	
	global inventoryUi_create		;UIEmpty* inventoryUi_create()
	global inventoryUI_update		;void inventoryUI_update(InventoryUI*)
	
	extern my_malloc
	
	extern inventoryAtlas_getAtlas
	extern inventoryAtlas_getSelectedHotbarSlot
	extern INVENTORY_HOTBAR_SIZE	;assumed to be >0
	extern INVENTORY_ATLAS_ROW_SLOTS
	
	extern uiElement_create
	extern uiElement_setParent
	extern uiElement_setSize
	extern uiElement_setPosition
	extern uiElement_setAnchor
	extern uiElement_setPivot
	extern uiImage_setTexture
	extern uiImage_setTextureGL
	extern uiImage_setUV
	extern UI_EMPTY
	extern UI_IMAGE
	extern UI_CENTER
	extern UI_BOTTOM
	
inventoryUi_create:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;root node					4
	sub esp, 4			;block displays				8
	sub esp, 4			;block display backgrounds	12
	sub esp, 4			;block selector				16
	sub esp, 4			;inventory ui struct		20
	sub esp, 4			;current x pos				24
	sub esp, 4			;block uv size				28	1/INVENTORY_ATLAS_ROW_SLOTS
	sub esp, 4			;current x uv				32
	
	;calculate current x pos
	mov eax, dword[INVENTORY_HOTBAR_SIZE]
	dec eax
	imul eax, SLOT_SIZE
	shr eax, 1
	neg eax
	mov dword[ebp-24], eax
	
	;calculate uv size
	cvtsi2ss xmm0, dword[INVENTORY_ATLAS_ROW_SLOTS]
	movss xmm1, dword[ONE]
	divss xmm1, xmm0
	movss dword[ebp-28], xmm1
	mov dword[ebp-32], 0
	
	;create root
	push dword[UI_EMPTY]
	call uiElement_create
	mov dword[ebp-4], eax
	
	push 0
	push 0
	push dword[ebp-4]
	call uiElement_setSize
	call uiElement_setPosition
	
	push word[UI_BOTTOM]
	push word[UI_CENTER]
	push dword[ebp-4]
	call uiElement_setAnchor
	call uiElement_setPivot
	
	;create block displays and backgrounds
	mov ebx, dword[INVENTORY_HOTBAR_SIZE]
	lea eax, [4*ebx]
	push eax
	call my_malloc
	mov dword[ebp-8], eax
	mov esi, eax			;displays in esi
	call my_malloc
	mov dword[ebp-12], eax
	mov edi, eax			;backgrounds in edi
	inventoryUI_create_loop_start:
		;create backgrounds
		INIT_IMAGE edi, dword[ebp-4], background_texture_path, dword[ebp-24], 0, SLOT_SIZE, SLOT_SIZE, UI_CENTER, UI_CENTER, UI_CENTER, UI_BOTTOM
		
		;create displays
		INIT_IMAGE esi, dword[ebp-4], 0, dword[ebp-24], 0, SLOT_SIZE, SLOT_SIZE, UI_CENTER, UI_CENTER, UI_CENTER, UI_BOTTOM
		
		push dword[ebp-28]
		push dword[ebp-32]
		push 0
		push dword[ebp-32]
		push dword[esi]
		movss xmm0, dword[esp+12]
		addss xmm0, dword[ebp-28]
		movss dword[esp+12], xmm0
		call uiImage_setUV
		add esp, 20
		
		
		movss xmm0, dword[ebp-32]
		addss xmm0, dword[ebp-28]
		movss dword[ebp-32], xmm0
		
		add dword[ebp-24], SLOT_SIZE
		add esi, 4
		add edi, 4
		dec ebx
		jnz inventoryUI_create_loop_start
		
	;create ui selector
	lea ebx, [ebp-16]
	INIT_IMAGE ebx, dword[ebp-4], selector_texture_path, 0, 0, SLOT_SIZE, SLOT_SIZE, UI_CENTER, UI_CENTER, UI_CENTER, UI_BOTTOM
		
	;create the ui struct
	push 16
	call my_malloc
	mov dword[ebp-20], eax
	
	mov ecx, dword[ebp-4]
	mov dword[eax], ecx
	mov edx, dword[ebp-8]
	mov dword[eax+4], edx
	mov ecx, dword[ebp-12]
	mov dword[eax+8], ecx
	mov edx, dword[ebp-16]
	mov dword[eax+12], edx
	
	;set return value
	mov eax, dword[ebp-20]
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	
inventoryUI_update:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;set the textures for the block displays
	call inventoryAtlas_getAtlas
	mov ebx, eax
	
	mov eax, dword[ebp+20]
	mov esi, dword[eax+4]		;current display in esi
	mov edi, dword[INVENTORY_HOTBAR_SIZE]	;index in edi
	inventoryUI_update_texture_loop_start:
		push ebx
		push dword[esi]
		call uiImage_setTextureGL
		add esp, 8
		
		add esi, 4
		dec edi
		jnz inventoryUI_update_texture_loop_start
		
		
	;set the selector's position
	call inventoryAtlas_getSelectedHotbarSlot
	mov ebx, eax
	imul ebx, SLOT_SIZE
	
	mov eax, dword[INVENTORY_HOTBAR_SIZE]
	dec eax
	imul eax, SLOT_SIZE
	shr eax, 1
	neg eax
	add eax, ebx
	
	mov ecx, dword[ebp+20]
	push 0
	push eax
	push dword[ecx+12]
	call uiElement_setPosition
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret