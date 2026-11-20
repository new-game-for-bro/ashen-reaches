extends RefCounted

# This is the original model from models/library, made importable outside .gdignore.
static var collision_shapes: Dictionary = {}
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
	_add_collision(model)

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

# Static triangle collision follows the imported scan, including its ground and walls.
# Reuse collision shapes across instances during a session.
static func _add_collision(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		var mesh: Mesh = node.mesh
		var shape: ConcavePolygonShape3D = collision_shapes.get(mesh)
		if not shape:
			shape = mesh.create_trimesh_shape()
			if shape:
				shape.backface_collision = true
				collision_shapes[mesh] = shape
		if shape:
			var body := StaticBody3D.new()
			body.name = "EnvironmentCollision"
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			node.add_child(body)
	for child in node.get_children():
		if not child is StaticBody3D:
			_add_collision(child)

# Wait for the physics server to register the model before placing actors.
static func ground_after_physics(actor: Node3D) -> void:
	await actor.get_tree().physics_frame
	await actor.get_tree().physics_frame
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	place_on_ground(actor)

static func place_on_ground(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	var p := actor.global_position
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 100.0, p.z), Vector3(p.x, p.y - 100.0, p.z))
	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y > 0.5:
		actor.global_position.y = hit.position.y + 0.08
