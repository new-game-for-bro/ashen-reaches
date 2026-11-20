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
	var look_touch := InputEventScreenTouch.new()
	look_touch.index = 5
	look_touch.position = Vector2(view_size.x * 0.65, view_size.y * 0.3)
	look_touch.pressed = true
	controls._unhandled_input(look_touch)
	var old_camera_yaw: float = player.camera_target_yaw
	var look_move := InputEventScreenDrag.new()
	look_move.index = 5
	look_move.relative = Vector2(20, 0)
	controls._unhandled_input(look_move)
	assert(player.camera_target_yaw < old_camera_yaw)
	assert(controls.move_vector.length() > 0.0)
	look_touch.pressed = false
	controls._unhandled_input(look_touch)
	touch.pressed = false
	stick._gui_input(touch)
	assert(controls.move_vector == Vector2.ZERO)
	var old_yaw: float = player.camera_target_yaw
	controls.look_dragged.emit(Vector2(10, 0))
	assert(player.camera_target_yaw < old_yaw)
	player.global_position = game.ren.global_position + Vector3(0, 0, 1)
	controls._on_action("Attack")
	assert(game.stage == "dodge")
	controls._on_action("Dodge")
	assert(game.stage == "counter")
	assert(controls.buttons.has("Exit") and controls.buttons.has("Pause"))
	assert(not controls.buttons["Interact"].visible)
	controls._on_move(Vector2(1, 0))
	player.dodge_time = 0.0
	controls._on_action("Dodge")
	assert(player.dodge_direction.x > 0.9)
	player.dodge_time = 0.0
	controls._on_move(Vector2.ZERO)
	player.avatar.rotation.y = 0.0
	controls._on_action("Dodge")
	assert(player.dodge_direction.z < -0.9)
	game._set_stage("countdown")
	controls._on_action("Pause")
	assert(game.modal_kind == "pause" and paused)
	var time_before_pause: float = game.timer
	await create_timer(0.15, true).timeout
	assert(is_equal_approx(game.timer, time_before_pause))
	game._set_touch_sensitivity(0.005)
	game._set_touch_invert(true)
	assert(is_equal_approx(controls.look_sensitivity, 0.005) and controls.invert_y)
	game._close_modal()
	assert(not paused)
	game._set_stage("exit")
	game._update_touch_context()
	assert(not controls.buttons["Interact"].visible)
	assert(controls.buttons["Exit"].modulate != Color.WHITE)
	controls._on_action("Exit")
	assert(game.modal_kind == "logout" and paused)
	game._close_logout()
	assert(game.stage == "gate" and not paused)
	game._update_touch_context()
	assert(not controls.buttons["Interact"].visible)
	player.global_position = Vector3(0, 0, -38)
	game._update_touch_context()
	assert(controls.buttons["Interact"].visible and controls.buttons["Interact"].text == "Talk")
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
