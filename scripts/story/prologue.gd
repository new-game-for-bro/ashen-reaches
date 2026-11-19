extends Node3D

const PlayerScript = preload("res://scripts/story/story_player.gd")
const REN_POS := Vector3(0, 0, -5)
const GATE_POS := Vector3(0, 0, -38)
const TRAIN_POS := Vector3(25, 0, -38)
var player: CharacterBody3D
var ren: Node3D
var train: Node3D
var story: Dictionary
var stage: String = "duel"
var timer: float = 0.0
var objective_label: Label
var dialogue_label: Label
var timer_label: Label

func _ready() -> void:
	var json := JSON.new()
	var file := FileAccess.open("res://data/prologue.json", FileAccess.READ)
	if file == null or json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("Could not load story.json")
		return
	story = json.data
	_build_world()
	_build_ui()
	_set_stage("duel")

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202b38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5b8c9")
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color("566577")
	env.fog_density = 0.01
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color("c6d0d8")
	sun.light_energy = 0.85
	add_child(sun)
	_box(Vector3(0, -0.5, -18), Vector3(22, 1, 55), Color("4a5159"), true)
	_box(Vector3(14, -0.5, -38), Vector3(35, 1, 15), Color("414953"), true)
	# A broad rooftop, a road and the walls of Latch, all placeholders.
	_box(Vector3(-10, 1.5, -14), Vector3(1, 3, 32), Color("383f48"), true)
	_box(Vector3(10, 1.5, -14), Vector3(1, 3, 32), Color("383f48"), true)
	_box(Vector3(-8, 4, -39), Vector3(8, 8, 2), Color("353c45"), true)
	_box(Vector3(8, 4, -39), Vector3(8, 8, 2), Color("353c45"), true)
	_box(Vector3(0, 8, -39), Vector3(9, 1, 2), Color("464c55"), true)
	_label("LATCH CITY GATE", Vector3(0, 9.5, -39))
	_label("OLD PLATFORM →", Vector3(13, 3, -37))
	# Giant kneels beyond the wall.
	_box(Vector3(0, 2.7, -46), Vector3(4.5, 5.4, 2.6), Color("625b5b"))
	_box(Vector3(0, 6.2, -45), Vector3(3.0, 2.4, 2.4), Color("7a6d67"))
	_label("THE GIANT", Vector3(0, 8.2, -45))
	ren = _person(REN_POS, Color("a17b69"), "REN")
	train = Node3D.new()
	train.position = TRAIN_POS
	add_child(train)
	var carriage := MeshInstance3D.new()
	var carriage_mesh := BoxMesh.new()
	carriage_mesh.size = Vector3(10, 3.5, 3)
	carriage.mesh = carriage_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4b626e")
	carriage.material_override = material
	carriage.position.y = 1.8
	train.add_child(carriage)
	_label("THE LAST TRAIN", TRAIN_POS + Vector3(0, 5, 0))
	player = CharacterBody3D.new()
	player.name = "Amara"
	player.set_script(PlayerScript)
	add_child(player)
	player.position = Vector3(0, 0.1, 2)
	player.attack_requested.connect(_on_attack)
	player.interact_requested.connect(_on_interact)
	player.dodge_requested.connect(_on_dodge)

func _box(pos: Vector3, size: Vector3, color: Color, solid := false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.position = pos
		body.add_child(collision)
		add_child(body)

func _person(pos: Vector3, color: Color, title: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	mesh.mesh = capsule
	mesh.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	root.add_child(mesh)
	var label := Label3D.new()
	label.text = title
	label.position.y = 2.3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return root

func _label(text_value: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	add_child(label)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var header := Label.new()
	header.position = Vector2(24, 18)
	header.text = "ASHEN REACHES  /  THE LAST LOGOUT"
	header.add_theme_font_size_override("font_size", 22)
	layer.add_child(header)
	objective_label = Label.new()
	objective_label.position = Vector2(24, 55)
	objective_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(objective_label)
	timer_label = Label.new()
	timer_label.position = Vector2(24, 86)
	layer.add_child(timer_label)
	dialogue_label = Label.new()
	dialogue_label.position = Vector2(24, 570)
	dialogue_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(dialogue_label)
	var controls := Label.new()
	controls.position = Vector2(24, 675)
	controls.text = "WASD move  ·  Mouse look  ·  Shift run  ·  Space / left click attack  ·  C dodge  ·  E interact  ·  Esc cursor  ·  P menu"
	layer.add_child(controls)

func _set_stage(value: String) -> void:
	stage = value
	objective_label.text = "OBJECTIVE: " + str(story[value]["objective"])
	dialogue_label.text = str(story[value]["dialogue"])
	if value == "countdown":
		timer = 8.0
	elif value == "gate":
		ren.position = GATE_POS + Vector3(2, 0, 4)
	elif value == "train":
		ren.position = TRAIN_POS + Vector3(-4, 0, 3)
	elif value == "ending":
		ren.visible = false
		var departing := create_tween()
		departing.tween_property(train, "position:x", 75.0, 8.0)

func _process(delta: float) -> void:
	if stage == "countdown":
		timer = maxf(0.0, timer - delta)
		timer_label.text = "SHUTDOWN IN: %d" % ceili(timer)
		if timer <= 0.0:
			timer_label.text = "CONNECTION LOST"
			_set_stage("exit")

func _on_attack() -> void:
	if stage in ["duel", "counter"]:
		if player.global_position.distance_to(ren.global_position) > 3.0:
			dialogue_label.text = "REN: Come closer if you want to land that."
		elif stage == "duel":
			_set_stage("dodge")
		else:
			_set_stage("countdown")

func _on_dodge() -> void:
	if stage == "dodge":
		_set_stage("counter")

func _on_interact() -> void:
	match stage:
		"exit":
			_set_stage("gate")
		"gate":
			if player.global_position.distance_to(GATE_POS) < 9.0:
				_set_stage("train")
			else:
				dialogue_label.text = "GUARD: Off the road! The gate's moving!"
		"train":
			if player.global_position.distance_to(TRAIN_POS) < 9.0:
				_set_stage("ending")
			else:
				dialogue_label.text = "REN: Amara, the old tracks are lit!"
		"ending":
			if player.global_position.distance_to(TRAIN_POS) < 9.0:
				if train.position.x < 65.0:
					dialogue_label.text = "The doors close. The train pulls away with Ren inside."
				else:
					_set_stage("complete")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")
