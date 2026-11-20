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
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-10, 50, -10), Vector3(-10, -10, -10)))
	assert(not ground.is_empty() and ground.normal.y > 0.7)
	print("PASS: fountain ground hit at ", ground.position)
	var faller := CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	collider.shape = sphere
	faller.add_child(collider)
	world.add_child(faller)
	faller.global_position = ground.position + Vector3(0, 3, 0)
	await physics_frame
	var floor_hit := faller.move_and_collide(Vector3(0, -5, 0))
	assert(floor_hit != null)
	print("PASS: character stopped by fountain ground")
	var wall := {}
	var start := Vector3.ZERO
	var end := Vector3.ZERO
	for z in range(-35, 0, 3):
		if not wall.is_empty(): break
		for x in range(-25, 25, 3):
			var floor_sample := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 50, z), Vector3(x, -10, z)))
			if floor_sample.is_empty() or floor_sample.normal.y < 0.7: continue
			start = floor_sample.position + Vector3(0, 1, 0)
			end = start + Vector3(3, 0, 0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end))
			if not hit.is_empty() and absf(hit.normal.y) < 0.5:
				wall = hit
				break
	assert(not wall.is_empty())
	faller.global_position = start
	await physics_frame
	var wall_hit := faller.move_and_collide(end - start)
	assert(wall_hit != null)
	print("PASS: character stopped by fountain obstacle at ", wall_hit.get_position())
	quit()
