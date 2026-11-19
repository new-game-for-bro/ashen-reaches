extends Node3D

const BotScript = preload("res://scripts/battle_royale/bot.gd")
const INITIAL_RADIUS: float = 42.0
const FINAL_RADIUS: float = 8.0
const SHRINK_DELAY: float = 12.0
const SHRINK_DURATION: float = 110.0
const ZONE_DAMAGE: int = 8
const BOT_COUNT: int = 6
@onready var player: CharacterBody3D = $Player
var radius: float = INITIAL_RADIUS
var elapsed: float = 0.0
var zone_tick: float = 0.0
var match_finished: bool = false
var ring: MeshInstance3D
var status: Label
var health_label: Label
var result: Label

func _ready() -> void:
	_build_environment()
	_build_ui()
	_build_ring()
	player.add_to_group("royale_contestants")
	player.defeated.connect(_on_player_defeated)
	player.health_changed.connect(_on_health_changed)
	for i in range(BOT_COUNT):
		var angle := TAU * float(i) / float(BOT_COUNT)
		var bot := CharacterBody3D.new()
		bot.set_script(BotScript)
		bot.position = Vector3(cos(angle) * 28.0, 0.05, sin(angle) * 28.0)
		bot.eliminated.connect(_on_bot_eliminated)
		add_child(bot)
	_update_status()

func _process(delta: float) -> void:
	if match_finished:
		return
	elapsed += delta
	var progress := clampf((elapsed - SHRINK_DELAY) / SHRINK_DURATION, 0.0, 1.0)
	radius = lerpf(INITIAL_RADIUS, FINAL_RADIUS, progress)
	ring.scale = Vector3(radius, 1.0, radius)
	zone_tick += delta
	if zone_tick >= 1.0:
		zone_tick -= 1.0
		for contestant: Node in get_tree().get_nodes_in_group("royale_contestants"):
			var pos: Vector3 = contestant.global_position
			if Vector2(pos.x, pos.z).length() > radius:
				contestant.hit(ZONE_DAMAGE)
	_update_status()

func _on_bot_eliminated(_bot: Node) -> void:
	if player.alive and get_tree().get_nodes_in_group("royale_contestants").size() == 1:
		_finish("VICTORY — YOU ARE THE LAST SURVIVOR")

func _on_player_defeated() -> void:
	_finish("DEFEAT — YOU WERE ELIMINATED")

func _on_health_changed(value: int) -> void:
	health_label.text = "HEALTH %d / 100" % value

func _finish(message: String) -> void:
	if match_finished:
		return
	match_finished = true
	result.text = message + ("\nTap Retry or Menu" if OS.has_feature("mobile") else "\nR: play again   ·   P: return to menu")
	for contestant: Node in get_tree().get_nodes_in_group("royale_contestants"):
		contestant.set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")
		elif event.keycode == KEY_R and match_finished:
			get_tree().reload_current_scene()

func _update_status() -> void:
	var left := get_tree().get_nodes_in_group("royale_contestants").size()
	status.text = "SURVIVORS %d    SAFE ZONE %.0f m    %s" % [left, radius, "SHRINKING" if elapsed >= SHRINK_DELAY else "SHRINKS IN %d s" % ceili(SHRINK_DELAY - elapsed)]

func _build_ring() -> void:
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.995
	mesh.outer_radius = 1.005
	mesh.rings = 96
	mesh.ring_segments = 4
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f0a960")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	ring.position.y = 0.05
	add_child(ring)

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("202830")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a4adb5")
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = Color("59616a")
	environment.fog_density = 0.008
	var env_node := WorldEnvironment.new()
	env_node.environment = environment
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	add_child(sun)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(20, 20)
	status.add_theme_font_size_override("font_size", 20)
	layer.add_child(status)
	health_label = Label.new()
	health_label.position = Vector2(20, 50)
	health_label.text = "HEALTH 100 / 100"
	layer.add_child(health_label)
	var hint := Label.new()
	hint.position = Vector2(20, 80)
	hint.text = "" if OS.has_feature("mobile") else "WASD move  ·  Shift run  ·  Space jump  ·  C dodge  ·  Left / right click attack  ·  Q lock  ·  P menu"
	layer.add_child(hint)
	result = Label.new()
	result.position = Vector2(350, 300)
	result.add_theme_font_size_override("font_size", 26)
	layer.add_child(result)
