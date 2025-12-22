[BITS 32]

;global light: a rectangle that overlays the screen
;point light: a sphere with the radius of one and inside facing triangles

section .text use32

	global lightVolume_createGlobal			;Renderable* lightVolume_createGlobal()
	global lightVolume_createPoint			;Renderable* lightVolume_createPoint()
	
	extern renderable_createCustom
	
	extern geometryImporter_import
	
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
	
	push point_volume_model_path
	call geometryImporter_import
	
	mov esp, ebp
	pop ebp
	ret
	
	

section .rodata use32

point_volume_model_path db "models/point_volume.geometry",0

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


global_volume_vertex_data:
dd -1.0, -1.0, 1.0, 0.0, 0.0		;pos.xyz, uv.xy
dd -1.0, 1.0, 1.0, 0.0, 1.0
dd 1.0, 1.0, 1.0, 1.0, 1.0
dd 1.0, -1.0, 1.0, 1.0, 0.0

global_volume_index_data:
dd 1,0,2,2,0,3