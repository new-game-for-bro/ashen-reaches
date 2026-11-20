extends SceneTree
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var game = load("res://scenes/story/prologue.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	assert(game.get_node("VillageNavigation") is NavigationRegion3D)
	assert(game.get_node("RoadStones").multimesh.instance_count == 115)
	var enemy = get_first_node_in_group("story_monsters")
	assert(enemy != null)
	var start: Vector3 = enemy.global_position
	await create_timer(1.0).timeout
	assert(enemy.global_position.distance_to(start) > 0.1, "Monster should patrol on the navigation mesh")
	game.player.global_position = enemy.global_position + Vector3(0, 0, 1)
	game._on_attack()
	game._on_attack()
	game._on_attack()
	await process_frame
	assert(not is_instance_valid(enemy), "Monster should be defeated after three hits")
	print("PASS: navigation, monster patrol and attacks, and batched road")
	quit()
