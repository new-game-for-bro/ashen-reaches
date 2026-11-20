extends SceneTree
const World = preload("res://scripts/world/model_environment.gd")
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var world := Node3D.new()
	root.add_child(world)
	World.add_to(world, Vector3(0, 0, -18), 70.0)
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	for z in [-45.0, -35.0, -25.0, -18.0, -10.0, 0.0, 2.0, 10.0]:
		for x in [-30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -30, z)))
			if not hit.is_empty(): print("PROBE ", x, " ", z, " ", hit.position, " normal=", hit.normal)
	quit()
