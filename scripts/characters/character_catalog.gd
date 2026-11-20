extends RefCounted

const SETTINGS_PATH := "user://character_choice.cfg"
const CHARACTER_COUNT := 4
const ACTIONS := {
	"idle": "rifle_aiming_idle",
	"walk": "walk_forward_left",
	"run": "walk_forward_left",
	"jump": "jump_down",
	"fall": "jump_down",
	"dodge": "walk_crouching_right",
	"attack_light_1": "punching",
	"attack_heavy": "standing_melee_attack_downward"
}

static func model_path(id: int) -> String:
	return "res://assets/characters/character%d/model.glb" % id

static func is_available(id: int) -> bool:
	return id >= 1 and id <= CHARACTER_COUNT and ResourceLoader.exists(model_path(id), "PackedScene")

static func selected_id() -> int:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return 0
	var value: Variant = settings.get_value("character", "id", 0)
	if value is int and is_available(value):
		return value
	return 0

static func select(id: int) -> bool:
	if id != 0 and not is_available(id):
		return false
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("character", "id", id)
	return settings.save(SETTINGS_PATH) == OK

static func attach(parent: Node3D, id: int) -> AnimationPlayer:
	if not is_available(id):
		return null
	var scene := load(model_path(id)) as PackedScene
	if not scene:
		return null
	var model := scene.instantiate() as Node3D
	if not model:
		return null
	var player := _find_player(model)
	if not player:
		model.free()
		return null
	model.name = "SelectedCharacter"
	parent.add_child(model)
	_fit_height(model)
	return player

static func play(player: AnimationPlayer, state: String) -> void:
	if not is_instance_valid(player):
		return
	var name: String = ACTIONS.get(state, "rifle_aiming_idle")
	if player.has_animation(name):
		var clip := player.get_animation(name)
		clip.loop_mode = Animation.LOOP_LINEAR if state in ["idle", "walk", "run"] else Animation.LOOP_NONE
		if player.current_animation != name or not player.is_playing():
			player.play(name, 0.12)

static func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer and node.get_animation_list().size() > 0:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null

static func _fit_height(model: Node3D) -> void:
	var points: Array[Vector3] = []
	_collect_bounds(model, Transform3D.IDENTITY, points)
	if points.is_empty():
		return
	var low := points[0]
	var high := points[0]
	for point in points:
		low = low.min(point)
		high = high.max(point)
	var height := high.y - low.y
	if height < 0.001:
		return
	var factor := 1.8 / height
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-(low.x + high.x) * factor / 2.0, -low.y * factor, -(low.z + high.z) * factor / 2.0)

static func _collect_bounds(node: Node, transform_so_far: Transform3D, points: Array[Vector3]) -> void:
	var current := transform_so_far
	if node is Node3D:
		current = transform_so_far * node.transform
	if node is MeshInstance3D and node.mesh:
		var bounds: AABB = node.mesh.get_aabb()
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					points.append(current * (bounds.position + bounds.size * Vector3(x, y, z)))
	for child in node.get_children():
		_collect_bounds(child, current, points)
