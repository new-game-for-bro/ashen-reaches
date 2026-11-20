extends SceneTree
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var world := Node3D.new()
	world.name = "BattleRoyale"
	root.add_child(world)
	var player = load("res://scenes/characters/player.tscn").instantiate()
	world.add_child(player)
	var bot := CharacterBody3D.new()
	bot.set_script(load("res://scripts/battle_royale/bot.gd"))
	bot.position = Vector3(0, 0, -5)
	world.add_child(bot)
	bot.set_physics_process(false)
	await physics_frame
	await physics_frame
	player.fire_rifle()
	assert(player.ammunition == 29)
	assert(bot.health == 40)
	player.fire_rifle()
	assert(player.ammunition == 29)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	wall_shape.shape = box
	wall.position = Vector3(0, 1, -2)
	wall.add_child(wall_shape)
	world.add_child(wall)
	await physics_frame
	player.attack_time = 0
	player.fire_rifle()
	assert(bot.health == 40)
	assert(player.ammunition == 28)
	player.reload_rifle()
	assert(player.reload_remaining > 0)
	player._physics_process(player.RELOAD_DURATION + 0.1)
	assert(player.ammunition == 30 and player.reserve_ammunition == 118)
	print("PASS: rifle aim, cover, fire rate and reload")
	quit()
