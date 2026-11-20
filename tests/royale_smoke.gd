extends SceneTree
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var packed := load("res://scenes/battle_royale/battle_royale.tscn") as PackedScene
	var arena = packed.instantiate()
	root.add_child(arena)
	await process_frame
	assert(get_nodes_in_group("royale_contestants").size() == 7)
	assert(arena.MAP_WIDTH == 600.0)
	assert(arena.radius == 300.0)
	var bot = get_nodes_in_group("training_targets")[0]
	bot.hit(15)
	assert(bot.health == 45)
	arena.player.global_position = Vector3(310, 0, 0)
	arena._process(1.1)
	assert(arena.player.health == 92)
	arena.player.global_position = Vector3.ZERO
	arena._process(50.0)
	assert(arena.radius < arena.INITIAL_RADIUS)
	for rival: Node in get_nodes_in_group("training_targets"):
		rival.hit(999)
	assert(arena.match_finished and arena.result.text.contains("VICTORY"))
	arena.queue_free()
	await process_frame
	arena = packed.instantiate()
	root.add_child(arena)
	await process_frame
	arena.player.hit(100)
	assert(arena.match_finished and arena.result.text.contains("DEFEAT"))
	print("PASS: rivals, combat, shrinking zone, victory and defeat")
	quit()
