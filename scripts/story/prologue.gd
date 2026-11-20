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
	sky_material.sky_top_color = Color("365f91")
	sky_material.sky_horizon_color = Color("f0b28b")
	sky_material.ground_bottom_color = Color("395743")
	sky_material.ground_horizon_color = Color("b9bd9a")
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8e6ed")
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color("b5c6bd")
	env.fog_density = 0.0035
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color("ffe1b0")
	sun.light_energy = 1.05
	add_child(sun)
	_box(Vector3(0, -0.5, -18), Vector3(90, 1, 90), Color("638653"), true)
	_build_navigation()
	_build_road_details()
	_build_fantasy_village()
	_build_colorful_nature()
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
	_box(Vector3(-29, 2, -43), Vector3(2, 4, 2), Color("776188"), true)
	_box(Vector3(-21, 2, -43), Vector3(2, 4, 2), Color("776188"), true)
	_box(Vector3(-25, 4, -43), Vector3(10, 1, 2), Color("a583aa"), true)
	_box(Vector3(-25, 1.8, -43.2), Vector3(6, 3.6, 0.15), Color("181b1b"))
	_label("HOLLOW CRYPT", Vector3(-25, 5.5, -43))

func _build_road_details() -> void:
	# A broken stone road and scattered columns frame the route to the gate.
	var stone_mesh := BoxMesh.new()
	stone_mesh.size = Vector3(1.55, 0.035, 1.85)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color("b5a48c")
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
			_box(Vector3(x, 0.5, z), Vector3(1.3, 1.0, 1.3), Color("7d8581"))
			_box(Vector3(x, 1.8, z), Vector3(0.75, 2.6, 0.75), Color("b2a59a"))
			_box(Vector3(x, 3.2, z), Vector3(1.1, 0.25, 1.1), Color("d3bf9d"))

# Original geometry inspired by misty ruined-village references; no Pinterest images are used as assets.
func _build_fantasy_village() -> void:
	for side in [-1.0, 1.0]:
		for z in [3.0, -11.0, -25.0]:
			_build_ruined_house(Vector3(side * 15.0, 0, z), side)
	for tree in [Vector3(-29, 0, 5), Vector3(30, 0, -12), Vector3(-33, 0, -29), Vector3(34, 0, -39), Vector3(-30, 0, -52)]:
		_build_dead_tree(tree)
	# A well and braziers give the square a focal point and guide the eye.
	_cylinder(Vector3(-7, 0.5, -12), 1.15, 1.0, Color("5a5950"), 10)
	_cylinder(Vector3(-7, 1.01, -12), 1.0, 0.06, Color("171f21"), 10)
	for p in [Vector3(-6, 0, 5), Vector3(6, 0, 5), Vector3(-6, 0, -29), Vector3(6, 0, -29)]:
		_build_brazier(p)
	# A subdued westward path points toward the crypt.
	for i in range(8):
		_box(Vector3(-8.0 - i * 2.2, 0.03, -33.0 - i * 1.15), Vector3(2.0, 0.06, 1.5), Color("52524c"))

func _build_colorful_nature() -> void:
	# Low-cost clusters of foliage and flowers stay clear of the road and objectives.
	var rng := RandomNumberGenerator.new()
	rng.seed = 87142
	for i in range(45):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(20.0, 41.0)
		var z := rng.randf_range(-55.0, 18.0)
		var patch := _cylinder(Vector3(x, 0.12, z), rng.randf_range(0.4, 1.0), 0.24, Color("4d9c65"), 5)
		patch.name = "FoliagePatch"
		var blossoms := _cylinder(Vector3(x, 0.31, z), 0.13, 0.2, [Color("f0a1be"), Color("ecca66"), Color("a4a4ec")][i % 3], 5)
		blossoms.name = "Wildflowers"
	for tree in [Vector3(-29, 0, 5), Vector3(30, 0, -12), Vector3(-33, 0, -29), Vector3(34, 0, -39), Vector3(-30, 0, -52)]:
		var crown := _cylinder(tree + Vector3(0, 6.4, 0), 2.3, 2.5, Color("518d67"), 7)
		crown.name = "TreeCanopy"
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 4.7, 4.8, -38), Vector3(0.08, 2.4, 1.1), Color("b9504f"))

func _build_ruined_house(pos: Vector3, side: float) -> void:
	var wall := Color("b69579")
	var wood := Color("654737")
	# Two masonry walls and an open street-facing facade keep the silhouette readable.
	_box(pos + Vector3(0, 1.55, -3), Vector3(6.2, 3.1, 0.45), wall)
	_box(pos + Vector3(0, 1.55, 3), Vector3(6.2, 3.1, 0.45), wall)
	_box(pos + Vector3(side * 3, 1.55, 0), Vector3(0.45, 3.1, 6.4), wall)
	for z in [-2.6, 0.0, 2.6]:
		_box(pos + Vector3(-side * 3, 1.55, z), Vector3(0.38, 3.1, 0.38), wood)
	_box(pos + Vector3(-side * 3, 2.85, 0), Vector3(0.4, 0.35, 6.0), wood)
	# Broken sloped roofs made from two weathered beams and roof slabs.
	for slope in [-1.0, 1.0]:
		var roof := _detail_box(pos + Vector3(slope * 1.55, 3.85, 0), Vector3(3.7, 0.18, 6.8), Color("87554b"))
		roof.rotation.z = -slope * 0.46
		var beam := _detail_box(pos + Vector3(slope * 1.65, 3.75, -3.25), Vector3(3.8, 0.16, 0.18), wood)
		beam.rotation.z = -slope * 0.46
	_box(pos + Vector3(-side * 2.95, 1.15, 0), Vector3(0.1, 2.1, 1.25), Color("1f2322"))

func _detail_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	node.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	node.material_override = material
	node.position = pos
	add_child(node)
	return node

func _cylinder(pos: Vector3, radius: float, height: float, color: Color, sides: int = 6) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.75
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node

func _build_dead_tree(pos: Vector3) -> void:
	_cylinder(pos + Vector3(0, 3.2, 0), 0.38, 6.4, Color("292c29"))
	for i in range(5):
		var angle := TAU * i / 5.0
		var branch := _cylinder(pos + Vector3(cos(angle) * 0.8, 5.0 + 0.4 * (i % 2), sin(angle) * 0.8), 0.14, 3.0, Color("292c29"), 5)
		branch.rotation = Vector3(sin(angle) * 0.65, 0, -cos(angle) * 0.65)

func _build_brazier(pos: Vector3) -> void:
	_cylinder(pos + Vector3(0, 0.65, 0), 0.19, 1.3, Color("302b26"))
	_cylinder(pos + Vector3(0, 1.35, 0), 0.43, 0.25, Color("49423a"), 8)
	var flame := _cylinder(pos + Vector3(0, 1.65, 0), 0.21, 0.45, Color("ec914d"), 6)
	var material := flame.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color("f27b32")
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.8, 0)
	light.light_color = Color("f1a064")
	light.light_energy = 0.7
	light.omni_range = 7.0
	add_child(light)

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
