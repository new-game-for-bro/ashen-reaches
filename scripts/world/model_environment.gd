extends RefCounted

# This is the original model from models/library, made importable outside .gdignore.
const CLOISTER = preload("res://models/environment/cloister_of_cathedral_of_st._mary.glb")

static func add_to(parent: Node3D, center: Vector3, width: float) -> void:
	var model := CLOISTER.instantiate() as Node3D
	model.name = "CloisterEnvironment"
	parent.add_child(model)
	var points: Array[Vector3] = []
	_collect_points(model, Transform3D.IDENTITY, points)
	if points.is_empty():
		push_error("The cloister model has no visible meshes")
		return
	var low := points[0]
	var high := points[0]
	for point in points:
		low = low.min(point)
		high = high.max(point)
	var span := maxf(high.x - low.x, high.z - low.z)
	if span <= 0.001:
		push_error("The cloister model has invalid dimensions")
		return
	var factor := width / span
	model.scale = Vector3.ONE * factor
	model.position = center - Vector3((low.x + high.x) / 2.0 * factor, low.y * factor, (low.z + high.z) / 2.0 * factor)

static func _collect_points(node: Node, transform_so_far: Transform3D, points: Array[Vector3]) -> void:
	var current := transform_so_far
	if node is Node3D:
		current = transform_so_far * node.transform
	if node is MeshInstance3D and node.mesh:
		var bounds: AABB = node.mesh.get_aabb()
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					points.append(current * (bounds.position + bounds.size * Vector3(x, y, z)))
	for child in node.get_children():
		_collect_points(child, current, points)
