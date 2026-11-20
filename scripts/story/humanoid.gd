extends RefCounted

# Simple stylized figures until rigged characters are ready.
static func build(root: Node3D, coat: Color, skin: Color, hair: Color) -> void:
	_part(root, Vector3(0, 1.15, 0), Vector3(0.65, 0.72, 0.35), coat)
	_part(root, Vector3(0, 0.76, 0), Vector3(0.60, 0.24, 0.37), Color("302925"))
	_part(root, Vector3(-0.17, 0.4, 0), Vector3(0.23, 0.72, 0.27), Color("34363b"))
	_part(root, Vector3(0.17, 0.4, 0), Vector3(0.23, 0.72, 0.27), Color("34363b"))
	_part(root, Vector3(-0.17, 0.09, -0.06), Vector3(0.25, 0.18, 0.40), Color("242424"))
	_part(root, Vector3(0.17, 0.09, -0.06), Vector3(0.25, 0.18, 0.40), Color("242424"))
	_part(root, Vector3(-0.43, 1.14, 0), Vector3(0.20, 0.65, 0.25), coat.darkened(0.15))
	_part(root, Vector3(0.43, 1.14, 0), Vector3(0.20, 0.65, 0.25), coat.darkened(0.15))
	_part(root, Vector3(-0.43, 0.78, 0), Vector3(0.18, 0.16, 0.20), skin)
	_part(root, Vector3(0.43, 0.78, 0), Vector3(0.18, 0.16, 0.20), skin)
	_part(root, Vector3(0, 1.78, 0), Vector3(0.42, 0.45, 0.38), skin)
	_part(root, Vector3(0, 2.02, 0.02), Vector3(0.46, 0.15, 0.41), hair)
	_part(root, Vector3(0, 1.84, 0.19), Vector3(0.45, 0.38, 0.10), hair)

static func _part(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	part.material_override = mat
	part.position = pos
	root.add_child(part)
