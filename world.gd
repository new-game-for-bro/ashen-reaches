extends Node3D

const PlayerScript = preload("res://player.gd")
const MonsterScript = preload("res://monster.gd")
const MapScript = preload("res://world_map.gd")
var player: CharacterBody3D
var map_panel: Control
var hud: Label
var message: Label
var kills := 0
var seals := {}
var markers := [
	{"name":"Haven", "pos":Vector3(0, 0, 0), "color":Color("d7c79e")},
	{"name":"Blackwood", "pos":Vector3(-35, 0, -30), "color":Color("79916d")},
	{"name":"Hollow Crypt", "pos":Vector3(-48, 0, -48), "color":Color("e2ad69")},
	{"name":"Ashen Wastes", "pos":Vector3(35, 0, -25), "color":Color("b07a65")},
	{"name":"Ember Vault", "pos":Vector3(48, 0, -45), "color":Color("e2ad69")},
	{"name":"Broken Highlands", "pos":Vector3(20, 0, 40), "color":Color("989aa2")},
	{"name":"Crown of Bones", "pos":Vector3(47, 0, 46), "color":Color("e2ad69")}
]

func _ready() -> void:
	_build_environment()
	_build_landscape()
	_build_roads_and_ruins()
	_build_scenery()
	_build_dungeon(Vector3(-48, 0, -48), "HOLLOW CRYPT")
	_build_dungeon(Vector3(48, 0, -45), "EMBER VAULT")
	_build_dungeon(Vector3(47, 0, 46), "CROWN OF BONES")
	_spawn_monster(Vector3(-26, 0, -22))
	_spawn_monster(Vector3(-39, 0, -35))
	_spawn_monster(Vector3(29, 0, -28))
	_spawn_monster(Vector3(37, 0, -38))
	_spawn_monster(Vector3(30, 0, 34))
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	add_child(player)
	player.position = Vector3(0, 1, 8)
	for monster in get_tree().get_nodes_in_group("monsters"):
		monster.player = player
	var layer := CanvasLayer.new()
	add_child(layer)
	map_panel = Control.new()
	map_panel.set_script(MapScript)
	layer.add_child(map_panel)
	map_panel.set("markers", markers)
	map_panel.set("player", player)
	map_panel.visible = false
	var hint := Label.new()
	hint.text = "ASHEN REACHES   |   WASD move · mouse look · Shift run · Space attack · E shrine · M map · Esc cursor"
	hint.position = Vector2(20, 18)
	hint.add_theme_font_size_override("font_size", 15)
	layer.add_child(hint)
	hud = Label.new()
	hud.position = Vector2(20, 50)
	hud.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud)
	message = Label.new()
	message.position = Vector2(20, 80)
	message.add_theme_font_size_override("font_size", 17)
	message.text = "Defeat the hollows, then cleanse the three dungeon seals."
	layer.add_child(message)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		map_panel.visible = not map_panel.visible
		player.map_open = map_panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_panel.visible else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _box(pos: Vector3, size: Vector3, color: Color, collide := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _mat(color)
	mesh.position = pos
	add_child(mesh)
	if collide:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.position = pos
		body.add_child(collision)
		add_child(body)
	return mesh

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("161b21")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("77808a")
	environment.ambient_light_energy = 0.65
	environment.fog_enabled = true
	environment.fog_light_color = Color("555b60")
	environment.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_color = Color("b8a6a0")
	sun.light_energy = 0.85
	add_child(sun)

func _build_landscape() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(140, 1, 140), Color("343b35"), true)
	_box(Vector3(-35, 0.01, -30), Vector3(57, 0.03, 60), Color("29352e"))
	_box(Vector3(35, 0.02, -30), Vector3(57, 0.03, 60), Color("514039"))
	_box(Vector3(30, 0.03, 37), Vector3(65, 0.03, 50), Color("444448"))
	# Landmarks are intentionally primitive placeholders for later art replacement.
	var rng := RandomNumberGenerator.new()
	rng.seed = 47291
	for i in range(100):
		var x := rng.randf_range(-65, 65)
		var z := rng.randf_range(-65, 65)
		if Vector2(x, z).length() < 14 or abs(x) > 43 and abs(z) > 40:
			continue
		if x < -8:
			var h := rng.randf_range(3, 7)
			_box(Vector3(x, h / 2, z), Vector3(0.35, h, 0.35), Color("272522"))
			_box(Vector3(x, h, z), Vector3(2.0, 1.2, 2.0), Color("25342b"))
		else:
			var h := rng.randf_range(0.5, 2.5)
			_box(Vector3(x, h / 2, z), Vector3(rng.randf_range(0.8, 2.5), h, rng.randf_range(0.8, 2.5)), Color("55504b"))
	# Visible boundaries prevent walking off the prototype.
	_box(Vector3(0, 2, -70), Vector3(140, 4, 1), Color("252b2a"), true)
	_box(Vector3(0, 2, 70), Vector3(140, 4, 1), Color("252b2a"), true)
	_box(Vector3(-70, 2, 0), Vector3(1, 4, 140), Color("252b2a"), true)
	_box(Vector3(70, 2, 0), Vector3(1, 4, 140), Color("252b2a"), true)
	_box(Vector3(0, 0.2, 0), Vector3(5, 0.4, 5), Color("77746a"))

func _build_dungeon(pos: Vector3, title: String) -> void:
	_box(pos + Vector3(-2.2, 2, 0), Vector3(1.2, 4, 1.5), Color("525052"), true)
	_box(pos + Vector3(2.2, 2, 0), Vector3(1.2, 4, 1.5), Color("525052"), true)
	_box(pos + Vector3(0, 4, 0), Vector3(5.5, 1, 1.5), Color("625d5a"), true)
	_box(pos + Vector3(0, 1.8, 0.5), Vector3(3.2, 3.6, 0.1), Color("17141a"))
	var label := Label3D.new()
	label.text = title + "\nDUNGEON ENTRANCE"
	label.font_size = 28
	label.position = pos + Vector3(0, 5.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _spawn_monster(pos: Vector3) -> void:
	var monster := Node3D.new()
	monster.name = "WanderingHollow"
	monster.set_script(MonsterScript)
	monster.position = pos
	add_child(monster)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.6
	capsule.height = 2.2
	body.mesh = capsule
	body.position.y = 1.1
	body.material_override = _mat(Color("6b3631"))
	monster.add_child(body)
	var label := Label3D.new()
	label.text = "WANDERING HOLLOW"
	label.position.y = 2.7
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	monster.add_child(label)


func _build_roads_and_ruins() -> void:
	# Broken roads lead from the haven to each of the three gateways.
	for target in [Vector3(-48, 0, -48), Vector3(48, 0, -45), Vector3(47, 0, 46)]:
		var steps := 24
		for i in range(1, steps):
			var point: Vector3 = Vector3.ZERO.lerp(target, float(i) / steps)
			var slab := _box(point + Vector3(0, 0.07, 0), Vector3(2.6, 0.1, 2.0), Color("615e55"))
			slab.rotation.y = atan2(target.x, target.z)
	# Ruined standing stones give each region a landmark on the horizon.
	for center in [Vector3(-29, 0, -27), Vector3(31, 0, -24), Vector3(26, 0, 34)]:
		for i in range(5):
			var angle := TAU * float(i) / 5.0
			var offset := Vector3(cos(angle) * 4, 0, sin(angle) * 4)
			var pillar := _box(center + offset + Vector3(0, 1.4, 0), Vector3(0.8, 2.8, 0.8), Color("777069"), true)
			pillar.rotation.z = sin(angle) * 0.1
	var fire := OmniLight3D.new()
	fire.position = Vector3(0, 2, 0)
	fire.light_color = Color("ec965b")
	fire.light_energy = 1.3
	fire.omni_range = 14
	add_child(fire)


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7349
	# Jagged silhouettes frame the world without obstructing its routes.
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		var distance := rng.randf_range(64, 68)
		var h := rng.randf_range(5, 13)
		var peak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(3, 7)
		cone.height = h
		cone.radial_segments = 5
		peak.mesh = cone
		peak.material_override = _mat(Color("303237"))
		peak.position = Vector3(cos(angle) * distance, h / 2.0 - 0.4, sin(angle) * distance)
		add_child(peak)
	# Dark pines and dead trees give Blackwood a recognisable skyline.
	for i in range(48):
		var x := rng.randf_range(-62, -12)
		var z := rng.randf_range(-58, -8)
		if abs(x-z) < 5 or Vector2(x + 48, z + 48).length() < 8:
			continue
		var height := rng.randf_range(4.5, 8.0)
		_box(Vector3(x, height * 0.4, z), Vector3(0.35, height * 0.8, 0.35), Color("302b29"))
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(1.1, 1.8)
		cone.height = height * 0.75
		cone.radial_segments = 5
		crown.mesh = cone
		crown.material_override = _mat(Color("26352d"))
		crown.position = Vector3(x, height * 0.7, z)
		add_child(crown)
	# A ring of warm beacons makes the central refuge easy to find.
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var p := Vector3(cos(angle) * 7.0, 0, sin(angle) * 7.0)
		_box(p + Vector3(0, 1.1, 0), Vector3(0.25, 2.2, 0.25), Color("4b3a30"))
		var flame := MeshInstance3D.new()
		var orb := SphereMesh.new()
		orb.radius = 0.25
		orb.height = 0.5
		flame.mesh = orb
		var glow := _mat(Color("f9a558"))
		glow.emission_enabled = true
		glow.emission = Color("fa7436")
		flame.material_override = glow
		flame.position = p + Vector3(0, 2.3, 0)
		add_child(flame)
		var light := OmniLight3D.new()
		light.position = p + Vector3(0, 2.3, 0)
		light.light_color = Color("ff9752")
		light.light_energy = 0.7
		light.omni_range = 8
		add_child(light)


func _process(_delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(hud):
		hud.text = "HEALTH %d / 100    HOLLOW KILLS %d    SEALS %d / 3" % [player.health, kills, seals.size()]

func monster_defeated() -> void:
	kills += 1
	message.text = "Hollow defeated. Find the three marked dungeon seals."

func interact() -> void:
	var locations := {"HOLLOW CRYPT": Vector3(-48, 0, -48), "EMBER VAULT": Vector3(48, 0, -45), "CROWN OF BONES": Vector3(47, 0, 46)}
	for title in locations:
		var flat := player.global_position
		flat.y = 0
		if flat.distance_to(locations[title]) < 6.0:
			if seals.has(title):
				message.text = title + " is already cleansed."
			elif kills < 1:
				message.text = "Defeat a wandering hollow before cleansing a seal."
			else:
				seals[title] = true
				player.health = mini(100, player.health + 25)
				message.text = title + " cleansed! Health restored."
				if seals.size() == 3:
					message.text = "VICTORY — all three seals are cleansed!"
			return
	message.text = "No seal nearby. Follow the roads to a dungeon entrance."
