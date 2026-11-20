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
	var ground_query := PhysicsRayQueryParameters3D.create(Vector3(0, 10, 2), Vector3(0, -10, 2))
	var ground := space.intersect_ray(ground_query)
	assert(not ground.is_empty() and ground.position.y > 0.3)
	print("PASS: model ground hit at ", ground.position)
	var wall := {}
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	for z in range(-45, 10, 3):
		if not wall.is_empty(): break
		for x in range(-30, 30, 3):
			from = Vector3(x, 2.0, z)
			to = from + Vector3(3, 0, 0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
			if not hit.is_empty() and absf(hit.normal.y) < 0.5:
				wall = hit
				break
	assert(not wall.is_empty())
	var character := CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	collider.shape = sphere
	character.add_child(collider)
	world.add_child(character)
	character.global_position = from
	await physics_frame
	var collision := character.move_and_collide(to - from)
	assert(collision != null)
	print("PASS: character stopped by environment wall at ", collision.get_position())
	quit()
