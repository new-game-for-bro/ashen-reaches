extends SceneTree
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var game = load("res://scenes/story/prologue.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player = game.player
	player._enable_touch_controls()
	await process_frame
	var controls = player.touch_controls
	assert(controls.buttons.has("Attack") and controls.buttons.has("Interact"))
	var stick = controls.get_child(0)
	var view_size: Vector2 = root.get_visible_rect().size
	var stick_rect: Rect2 = stick.get_global_rect()
	assert(stick_rect.position.x >= 0 and stick_rect.position.y >= 0)
	assert(stick_rect.end.x <= view_size.x and stick_rect.end.y <= view_size.y)
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.pressed = true
	touch.position = stick.size / 2.0 + Vector2(35, -35)
	stick._gui_input(touch)
	assert(controls.move_vector.distance_to(Vector2(0.5, -0.5)) < 0.01)
	touch.pressed = false
	stick._gui_input(touch)
	assert(controls.move_vector == Vector2.ZERO)
	var old_yaw: float = player.camera_pivot.rotation.y
	controls.look_dragged.emit(Vector2(10, 0))
	assert(player.camera_pivot.rotation.y < old_yaw)
	player.global_position = Vector3(0, 0, -4)
	controls._on_action("Attack")
	assert(game.stage == "dodge")
	controls._on_action("Dodge")
	assert(game.stage == "counter")
	controls._on_action("Sprint")
	assert(controls.sprinting)
	game.queue_free()
	await process_frame
	var arena = load("res://scenes/battle_royale/battle_royale.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.player._enable_touch_controls()
	await process_frame
	var pad = arena.player.touch_controls
	assert(pad.buttons.has("Jump") and pad.buttons.has("Retry"))
	pad._on_action("Jump")
	assert(arena.player.mobile_jump)
	pad._on_action("Dodge")
	assert(arena.player.mobile_dodge)
	var network_player = load("res://scripts/network/network_player.gd").new()
	root.add_child(network_player)
	network_player.pivot = Node3D.new()
	network_player.add_child(network_player.pivot)
	network_player._enable_touch_controls()
	await process_frame
	assert(network_player.touch_controls.buttons.has("Chat"))
	network_player.touch_controls._on_action("Jump")
	assert(network_player.mobile_jump)
	print("PASS: story, royale and network touch controls")
	quit()
