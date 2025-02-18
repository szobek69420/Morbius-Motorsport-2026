[BITS 32]

section .text use32

	;returns non-zero if a collision happened
	;only supports mesh colliders with horizontal and vertical normals
	global collisionDetection_collisionCylinderMesh		;int cd_cCylinderMesh(Collider* cylinder, Collider* mesh)