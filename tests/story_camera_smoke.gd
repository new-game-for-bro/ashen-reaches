extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var player = load("res://scripts/story/story_player.gd").new()
	root.add_child(player)
	await process_frame
	var arm: SpringArm3D = player.camera_pivot.get_child(0)
	assert(arm.shape is SphereShape3D)
	var initial_yaw: float = player.camera_pivot.rotation.y
	player._apply_look(Vector2(100, 10000), 0.003)
	assert(is_equal_approx(player.camera_target_pitch, -0.8))
	player._process(0.016)
	assert(player.camera_pivot.rotation.y < initial_yaw)
	assert(player.camera_pivot.rotation.y > player.camera_target_yaw)
	player._process(2.0)
	assert(absf(player.camera_pivot.rotation.y - player.camera_target_yaw) < 0.001)
	player._apply_look(Vector2(0, -10000), 0.003)
	assert(is_equal_approx(player.camera_target_pitch, 0.55))
	print("PASS: camera smoothing, pitch limits and spring-arm collision shape")
	quit()
