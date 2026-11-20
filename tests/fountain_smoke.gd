extends SceneTree
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var game = load("res://scenes/story/prologue.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var fountain = game.get_node_or_null("AncientFountain")
	assert(fountain != null, "Imported fountain should be placed in the village")
	assert(fountain.scale.is_equal_approx(Vector3.ONE * 0.13))
	print("PASS: fountain model imported and placed")
	quit()
