[BITS 32]

;global light: a rectangle that overlays the screen
;point light: a sphere with the radius of one and inside facing triangles
section .text use32

	global lightVolume_createGlobal			;Renderable* lightVolume_createGlobal()
	global lightVolume_createPoint			;Renderable* lightVolume_createPoint()
	
	extern renderable_createCustom
	
lightVolume_createGlobal:
	push ebp
	mov ebp, esp
	
	push 0
	push 2
	push 3
	push 2
	push global_volume_index_vector
	push global_volume_vertex_vector
	call renderable_createCustom
	
	mov esp, ebp
	pop ebp
	ret
	
	
lightVolume_createPoint:
	push ebp
	mov ebp, esp
	
	push 0
	push 3
	push 1
	push point_volume_index_vector
	push point_volume_vertex_vector
	call renderable_createCustom
	
	mov esp, ebp
	pop ebp
	ret
	
	

section .rodata use32

global_volume_vertex_vector:
dd 20
dd 20
dd 4
dd global_volume_vertex_data
	
global_volume_index_vector:
dd 6
dd 6
dd 4
dd global_volume_index_data


point_volume_vertex_vector:
dd 186
dd 186
dd 4
dd point_volume_vertex_data

point_volume_index_vector:
dd 360
dd 360
dd 4
dd point_volume_index_data




global_volume_vertex_data:
dd -1.0, -1.0, 1.0, 0.0, 0.0		;pos.xyz, uv.xy
dd -1.0, 1.0, 1.0, 0.0, 1.0
dd 1.0, 1.0, 1.0, 1.0, 1.0
dd 1.0, -1.0, 1.0, 1.0, 0.0

global_volume_index_data:
dd 1,0,2,2,0,3



point_volume_vertex_data:
dd 0.00, 1.00, 0.00
dd 0.50, 0.87, 0.00
dd 0.43, 0.87, 0.25
dd 0.25, 0.87, 0.43
dd 0.00, 0.87, 0.50
dd -0.25, 0.87, 0.43
dd -0.43, 0.87, 0.25
dd -0.50, 0.87, 0.00
dd -0.43, 0.87, -0.25
dd -0.25, 0.87, -0.43
dd 0.00, 0.87, -0.50
dd 0.25, 0.87, -0.43
dd 0.43, 0.87, -0.25
dd 0.87, 0.50, 0.00
dd 0.75, 0.50, 0.43
dd 0.43, 0.50, 0.75
dd 0.00, 0.50, 0.87
dd -0.43, 0.50, 0.75
dd -0.75, 0.50, 0.43
dd -0.87, 0.50, 0.00
dd -0.75, 0.50, -0.43
dd -0.43, 0.50, -0.75
dd 0.00, 0.50, -0.87
dd 0.43, 0.50, -0.75
dd 0.75, 0.50, -0.43
dd 1.00, 0.00, 0.00
dd 0.87, 0.00, 0.50
dd 0.50, 0.00, 0.87
dd 0.00, 0.00, 1.00
dd -0.50, 0.00, 0.87
dd -0.87, 0.00, 0.50
dd -1.00, 0.00, 0.00
dd -0.87, 0.00, -0.50
dd -0.50, 0.00, -0.87
dd 0.00, 0.00, -1.00
dd 0.50, 0.00, -0.87
dd 0.87, 0.00, -0.50
dd 0.87, -0.50, 0.00
dd 0.75, -0.50, 0.43
dd 0.43, -0.50, 0.75
dd 0.00, -0.50, 0.87
dd -0.43, -0.50, 0.75
dd -0.75, -0.50, 0.43
dd -0.87, -0.50, 0.00
dd -0.75, -0.50, -0.43
dd -0.43, -0.50, -0.75
dd 0.00, -0.50, -0.87
dd 0.43, -0.50, -0.75
dd 0.75, -0.50, -0.43
dd 0.50, -0.87, 0.00
dd 0.43, -0.87, 0.25
dd 0.25, -0.87, 0.43
dd 0.00, -0.87, 0.50
dd -0.25, -0.87, 0.43
dd -0.43, -0.87, 0.25
dd -0.50, -0.87, 0.00
dd -0.43, -0.87, -0.25
dd -0.25, -0.87, -0.43
dd 0.00, -0.87, -0.50
dd 0.25, -0.87, -0.43
dd 0.43, -0.87, -0.25
dd 0.00, -1.00, 0.00

point_volume_index_data:
dd 1, 0, 2
dd 2, 0, 3
dd 3, 0, 4
dd 4, 0, 5
dd 5, 0, 6
dd 6, 0, 7
dd 7, 0, 8
dd 8, 0, 9
dd 9, 0, 10
dd 10, 0, 11
dd 11, 0, 12
dd 12, 0, 1
dd 13, 1, 14
dd 14, 2, 15
dd 15, 3, 16
dd 16, 4, 17
dd 17, 5, 18
dd 18, 6, 19
dd 19, 7, 20
dd 20, 8, 21
dd 21, 9, 22
dd 22, 10, 23
dd 23, 11, 24
dd 24, 12, 13
dd 14, 1, 2
dd 15, 2, 3
dd 16, 3, 4
dd 17, 4, 5
dd 18, 5, 6
dd 19, 6, 7
dd 20, 7, 8
dd 21, 8, 9
dd 22, 9, 10
dd 23, 10, 11
dd 24, 11, 12
dd 13, 12, 1
dd 25, 13, 26
dd 26, 14, 27
dd 27, 15, 28
dd 28, 16, 29
dd 29, 17, 30
dd 30, 18, 31
dd 31, 19, 32
dd 32, 20, 33
dd 33, 21, 34
dd 34, 22, 35
dd 35, 23, 36
dd 36, 24, 25
dd 26, 13, 14
dd 27, 14, 15
dd 28, 15, 16
dd 29, 16, 17
dd 30, 17, 18
dd 31, 18, 19
dd 32, 19, 20
dd 33, 20, 21
dd 34, 21, 22
dd 35, 22, 23
dd 36, 23, 24
dd 25, 24, 13
dd 37, 25, 38
dd 38, 26, 39
dd 39, 27, 40
dd 40, 28, 41
dd 41, 29, 42
dd 42, 30, 43
dd 43, 31, 44
dd 44, 32, 45
dd 45, 33, 46
dd 46, 34, 47
dd 47, 35, 48
dd 48, 36, 37
dd 38, 25, 26
dd 39, 26, 27
dd 40, 27, 28
dd 41, 28, 29
dd 42, 29, 30
dd 43, 30, 31
dd 44, 31, 32
dd 45, 32, 33
dd 46, 33, 34
dd 47, 34, 35
dd 48, 35, 36
dd 37, 36, 25
dd 49, 37, 50
dd 50, 38, 51
dd 51, 39, 52
dd 52, 40, 53
dd 53, 41, 54
dd 54, 42, 55
dd 55, 43, 56
dd 56, 44, 57
dd 57, 45, 58
dd 58, 46, 59
dd 59, 47, 60
dd 60, 48, 49
dd 50, 37, 38
dd 51, 38, 39
dd 52, 39, 40
dd 53, 40, 41
dd 54, 41, 42
dd 55, 42, 43
dd 56, 43, 44
dd 57, 44, 45
dd 58, 45, 46
dd 59, 46, 47
dd 60, 47, 48
dd 49, 48, 37
dd 49, 61, 60
dd 50, 61, 49
dd 51, 61, 50
dd 52, 61, 51
dd 53, 61, 52
dd 54, 61, 53
dd 55, 61, 54
dd 56, 61, 55
dd 57, 61, 56
dd 58, 61, 57
dd 59, 61, 58
dd 60, 61, 59