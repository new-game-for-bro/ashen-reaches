extends Node3D

const PlayerScript = preload("res://scripts/story/story_player.gd")
const Humanoid = preload("res://scripts/story/humanoid.gd")
const RuinMonster = preload("res://scripts/story/ruin_monster.gd")
const VILLAGE_PATH := "res://residential_buildings_ancient_villages.glb"
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
var modal_layer: CanvasLayer
var modal_kind: String = ""

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
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("29394d")
	sky_material.sky_horizon_color = Color("a58d83")
	sky_material.ground_bottom_color = Color("292d30")
	sky_material.ground_horizon_color = Color("7c7472")
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5b8c9")
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color("827b7a")
	env.fog_density = 0.01
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color("e3c3a5")
	sun.light_energy = 0.85
	add_child(sun)
	_box(Vector3(0, -0.5, -18), Vector3(90, 1, 90), Color("414943"), true)
	_build_navigation()
	# The enormous aerial scan remains optional: its underside is unsuitable for a walkable mobile environment.
	if not OS.has_feature("mobile"):
		_add_village_backdrop()
	_build_road_details()
	_build_dungeon_approach()
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
	player.add_to_group("player")
	_spawn_ruin_monster()
	player.attack_requested.connect(_on_attack)
	player.interact_requested.connect(_on_interact)
	player.dodge_requested.connect(_on_dodge)

# The scan is scenery beside the playable route; the existing floor and walls
# provide simple collision and keep the story route accessible.
func _add_village_backdrop() -> void:
	if not ResourceLoader.exists(VILLAGE_PATH, "PackedScene"):
		return
	var scene := load(VILLAGE_PATH) as PackedScene
	if scene == null:
		return
	var village := scene.instantiate() as Node3D
	if village == null:
		return
	village.name = "AncientVillageBackdrop"
	village.scale = Vector3.ONE * 0.18
	village.position = Vector3(39, -2.0, -32)
	add_child(village)

func _build_navigation() -> void:
	# A flat navigation polygon covers the same continuous ground as the collision floor.
	var region := NavigationRegion3D.new()
	region.name = "VillageNavigation"
	var nav := NavigationMesh.new()
	nav.vertices = PackedVector3Array([Vector3(-44, 0.05, -62), Vector3(44, 0.05, -62), Vector3(44, 0.05, 26), Vector3(-44, 0.05, 26)])
	nav.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = nav
	add_child(region)

func _spawn_ruin_monster() -> void:
	var enemy := RuinMonster.new()
	enemy.position = Vector3(-24, 0.1, -20)
	enemy.player = player
	enemy.patrol_points = [Vector3(-24, 0, -20), Vector3(-28, 0, -33), Vector3(-20, 0, -36)]
	add_child(enemy)

func _build_dungeon_approach() -> void:
	# Visible landmark with a broad, open approach on the west side of the village.
	_box(Vector3(-29, 2, -43), Vector3(2, 4, 2), Color("514b49"), true)
	_box(Vector3(-21, 2, -43), Vector3(2, 4, 2), Color("514b49"), true)
	_box(Vector3(-25, 4, -43), Vector3(10, 1, 2), Color("625a54"), true)
	_box(Vector3(-25, 1.8, -43.2), Vector3(6, 3.6, 0.15), Color("181b1b"))
	_label("HOLLOW CRYPT", Vector3(-25, 5.5, -43))

func _build_road_details() -> void:
	# A broken stone road and scattered columns frame the route to the gate.
	var stone_mesh := BoxMesh.new()
	stone_mesh.size = Vector3(1.55, 0.035, 1.85)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color("535a60")
	stone_mat.roughness = 1.0
	stone_mesh.material = stone_mat
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = stone_mesh
	instances.instance_count = 115
	for row in range(23):
		for column in range(5):
			var x := (column - 2) * 1.7 + (0.35 if row % 2 == 0 else -0.35)
			instances.set_instance_transform(row * 5 + column, Transform3D(Basis.IDENTITY, Vector3(x, 0.015, 5.0 - row * 2.05)))
	var road := MultiMeshInstance3D.new()
	road.name = "RoadStones"
	road.multimesh = instances
	add_child(road)
	for z in [0.0, -11.0, -24.0]:
		for side in [-1.0, 1.0]:
			var x: float = side * 9.3
			_box(Vector3(x, 0.5, z), Vector3(1.3, 1.0, 1.3), Color("42494e"))
			_box(Vector3(x, 1.8, z), Vector3(0.75, 2.6, 0.75), Color("555a5a"))
			_box(Vector3(x, 3.2, z), Vector3(1.1, 0.25, 1.1), Color("62625b"))
	# Low ruined buildings give the road a readable town edge.
	for z in [2.0, -12.0, -26.0]:
		_box(Vector3(-15, 2.0, z), Vector3(7.0, 4.0, 7.0), Color("65615a"))
		_box(Vector3(-15, 4.15, z), Vector3(7.5, 0.3, 7.5), Color("393c3b"))
		_box(Vector3(-11.45, 1.7, z), Vector3(0.05, 2.7, 1.3), Color("292b2c"))
		_box(Vector3(-11.44, 2.9, z - 2.0), Vector3(0.06, 1.0, 1.0), Color("353532"))
		_box(Vector3(-11.44, 2.9, z + 2.0), Vector3(0.06, 1.0, 1.0), Color("353532"))

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
	Humanoid.build(root, color, Color("bf957b"), Color("392d27"))
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
	header.position = Vector2(140, 18) if OS.has_feature("mobile") else Vector2(24, 18)
	header.text = "ASHEN REACHES  /  THE LAST LOGOUT"
	header.add_theme_font_size_override("font_size", 22)
	layer.add_child(header)
	objective_label = Label.new()
	objective_label.position = Vector2(140, 55) if OS.has_feature("mobile") else Vector2(24, 55)
	objective_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(objective_label)
	timer_label = Label.new()
	timer_label.position = Vector2(140, 86) if OS.has_feature("mobile") else Vector2(24, 86)
	layer.add_child(timer_label)
	dialogue_label = Label.new()
	dialogue_label.position = Vector2(24, 350) if OS.has_feature("mobile") else Vector2(24, 570)
	dialogue_label.size = Vector2(720, 110)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(dialogue_label)
	var controls := Label.new()
	controls.position = Vector2(24, 675)
	controls.text = "" if OS.has_feature("mobile") else "WASD move  ·  Mouse look  ·  Shift run  ·  Space / left click attack  ·  C dodge  ·  E interact  ·  Esc cursor  ·  P menu"
	layer.add_child(controls)

func _set_stage(value: String) -> void:
	stage = value
	objective_label.text = "OBJECTIVE: " + str(story[value]["objective"])
	dialogue_label.text = str(story[value]["dialogue"])
	if player.touch_controls:
		player.touch_controls.set_exit_attention(value == "exit")
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
	_update_touch_context()
	if stage == "countdown":
		timer = maxf(0.0, timer - delta)
		timer_label.text = "SHUTDOWN IN: %d" % ceili(timer)
		if timer <= 0.0:
			timer_label.text = "CONNECTION LOST"
			_set_stage("exit")

func _on_attack() -> void:
	for monster in get_tree().get_nodes_in_group("story_monsters"):
		if is_instance_valid(monster) and player.global_position.distance_to(monster.global_position) < 3.0:
			monster.hit()
			if stage not in ["duel", "counter"]:
				dialogue_label.text = "The hollow recoils."
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
			open_logout_menu()
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


func _update_touch_context() -> void:
	if not is_instance_valid(player) or not player.touch_controls:
		return
	var label := ""
	var pos: Vector3 = player.global_position
	if stage == "gate" and pos.distance_to(GATE_POS) < 9.0:
		label = "Talk"
	elif stage == "train" and pos.distance_to(TRAIN_POS) < 9.0:
		label = "Board"
	elif stage == "ending" and pos.distance_to(TRAIN_POS) < 9.0:
		label = "Look"
	player.touch_controls.set_story_interaction(label)
	player.touch_controls.set_exit_attention(stage == "exit")

func open_logout_menu() -> void:
	if modal_layer:
		return
	var text_value := "The logout option is unavailable during the duel."
	if stage == "exit":
		text_value = "RETURN ROUTE SEVERED.\nYour body is waiting."
	elif stage in ["gate", "train", "ending", "complete"]:
		text_value = "RETURN ROUTE SEVERED.\nYour body is waiting."
	_create_modal("logout", "IN-WORLD EXIT", text_value)
	_add_modal_button("Continue", _close_logout)

func open_pause_menu() -> void:
	if modal_layer:
		return
	_create_modal("pause", "PAUSED", "Touch settings")
	var column: VBoxContainer = modal_layer.get_node("Overlay/Panel/Column")
	var sensitivity_label := Label.new()
	sensitivity_label.text = "Camera sensitivity"
	column.add_child(sensitivity_label)
	var slider := HSlider.new()
	slider.min_value = 0.0015
	slider.max_value = 0.006
	slider.step = 0.0001
	slider.value = player.touch_controls.look_sensitivity if player.touch_controls else 0.003
	slider.custom_minimum_size = Vector2(400, 35)
	slider.value_changed.connect(_set_touch_sensitivity)
	column.add_child(slider)
	var invert := CheckBox.new()
	invert.text = "Invert vertical look"
	invert.button_pressed = player.touch_controls.invert_y if player.touch_controls else false
	invert.toggled.connect(_set_touch_invert)
	column.add_child(invert)
	_add_modal_button("Resume", _close_modal)
	_add_modal_button("Return to main menu", _return_to_menu)

func _create_modal(kind: String, title: String, body: String) -> void:
	modal_kind = kind
	if player.touch_controls:
		player.touch_controls.reset_input()
	player.velocity = Vector3.ZERO
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 20
	modal_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(modal_layer)
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.03, 0.04, 0.06, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(overlay)
	var panel := CenterContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.custom_minimum_size = Vector2(450, 0)
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	var description := Label.new()
	description.text = body
	description.add_theme_font_size_override("font_size", 20)
	column.add_child(description)
	get_tree().paused = true

func _add_modal_button(title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 55
	button.pressed.connect(action)
	modal_layer.get_node("Overlay/Panel/Column").add_child(button)

func _set_touch_sensitivity(value: float) -> void:
	if player.touch_controls:
		player.touch_controls.look_sensitivity = value

func _set_touch_invert(value: bool) -> void:
	if player.touch_controls:
		player.touch_controls.invert_y = value

func _close_logout() -> void:
	var advance := stage == "exit"
	_close_modal()
	if advance:
		_set_stage("gate")

func _close_modal() -> void:
	get_tree().paused = false
	if modal_layer:
		modal_layer.queue_free()
		modal_layer = null
	modal_kind = ""

func _return_to_menu() -> void:
	_close_modal()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")
