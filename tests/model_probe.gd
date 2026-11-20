extends SceneTree
const World = preload("res://scripts/world/model_environment.gd")
func _initialize() -> void:
	call_deferred("run_test")
func collide(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		node.create_trimesh_collision()
	for c in node.get_children():
		collide(c)
func run_test() -> void:
	var world := Node3D.new()
	root.add_child(world)
	World.add_to(world, Vector3(0, 0, -18), 70.0)
	collide(world)
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	for z in [2.0, -5.0, -18.0, -38.0]:
		for x in [-25.0, -10.0, 0.0, 10.0, 25.0]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -50, z))
			var hit := space.intersect_ray(q)
			print("PROBE ", x, " ", z, " ", hit.get("position", "NONE"), " normal=", hit.get("normal", "NONE"))
	quit()
