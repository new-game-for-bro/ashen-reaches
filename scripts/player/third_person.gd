extends CharacterBody3D

const CharacterCatalog = preload("res://scripts/characters/character_catalog.gd")

const WorldModels = preload("res://scripts/world/model_environment.gd")

signal health_changed(value: int)
signal defeated
signal ammo_changed(magazine: int, reserve: int, reloading: bool)
signal shot_feedback(hit_target: bool)

const TouchControls = preload("res://scripts/mobile/touch_controls.gd")
const InputSetup = preload("res://scripts/player/input_setup.gd")

const MOVE_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const JUMP_SPEED: float = 6.0
const GRAVITY: float = 18.0
const DODGE_SPEED: float = 12.0
const DODGE_DURATION: float = 0.28
const ATTACK_COOLDOWN: float = 0.55
const RIFLE_DAMAGE := 20
const RIFLE_RANGE := 100.0
const RIFLE_INTERVAL := 0.15
const MAGAZINE_SIZE := 30
const RELOAD_DURATION := 1.5

@onready var visual: Node3D = $Visual
@onready var pivot: Node3D = $CameraPivot
@onready var animation: AnimationPlayer = $Visual/AnimationPlayer
var touch_controls: CanvasLayer
var mobile_jump: bool = false
var mobile_dodge: bool = false
var dodge_time: float = 0.0
var attack_time: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var health: int = 100
var alive: bool = true
var target: Node3D
var placeholder_blade: MeshInstance3D
var rifle_mode := false
var fire_held := false
var ammunition := MAGAZINE_SIZE
var reserve_ammunition := 120
var reload_remaining := 0.0

func _ready() -> void:
	rifle_mode = get_parent().name == "BattleRoyale"
	WorldModels.ground_after_physics(self)
	InputSetup.configure()
	_add_placeholder()
	if OS.has_feature("mobile"):
		_enable_touch_controls()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * 0.003
		pivot.rotation.x = clampf(pivot.rotation.x - event.relative.y * 0.003, -0.8, 0.55)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if rifle_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			fire_held = event.pressed
		elif event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if rifle_mode and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		reload_rifle()
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			attack(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			attack(true)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		_lock_target()

func _physics_process(delta: float) -> void:
	attack_time = maxf(0.0, attack_time - delta)
	if rifle_mode and alive:
		if reload_remaining > 0.0:
			reload_remaining = maxf(0.0, reload_remaining - delta)
			if reload_remaining == 0.0:
				var needed := mini(MAGAZINE_SIZE - ammunition, reserve_ammunition)
				ammunition += needed
				reserve_ammunition -= needed
				ammo_changed.emit(ammunition, reserve_ammunition, false)
		if fire_held:
			fire_rifle()
	dodge_time = maxf(0.0, dodge_time - delta)
	var move_input := Vector2(Input.get_action_strength("move_right") - Input.get_action_strength("move_left"), Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")).normalized()
	if touch_controls and touch_controls.move_vector.length() > 0.0:
		move_input = touch_controls.move_vector
	var direction := (Basis(Vector3.UP, pivot.rotation.y) * Vector3(move_input.x, 0, move_input.y)).normalized()
	if (Input.is_action_just_pressed("dodge") or mobile_dodge) and dodge_time <= 0.0 and is_on_floor() and direction.length() > 0.1:
		dodge_direction = direction
		dodge_time = DODGE_DURATION
	mobile_dodge = false
	if dodge_time > 0.0:
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		_play_animation("dodge")
	else:
		var running: bool = Input.is_action_pressed("sprint") or (touch_controls != null and touch_controls.sprinting)
		var speed := RUN_SPEED if running else MOVE_SPEED
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if direction.length() > 0.1:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 12.0))
		if attack_time <= 0.0:
			_play_animation("run" if running and direction.length() > 0.1 else "walk" if direction.length() > 0.1 else "idle")
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_play_animation("fall" if velocity.y < 0.0 else "jump")
	elif Input.is_action_just_pressed("jump") or mobile_jump:
		velocity.y = JUMP_SPEED
	else:
		velocity.y = 0.0
	mobile_jump = false
	if is_instance_valid(target):
		if global_position.distance_to(target.global_position) > 20.0:
			target = null
		else:
			var offset := target.global_position - global_position
			visual.rotation.y = atan2(offset.x, offset.z)
	move_and_slide()

func reload_rifle() -> void:
	if not alive or reload_remaining > 0.0 or ammunition >= MAGAZINE_SIZE or reserve_ammunition <= 0:
		return
	reload_remaining = RELOAD_DURATION
	ammo_changed.emit(ammunition, reserve_ammunition, true)

func fire_rifle() -> void:
	if not alive or not rifle_mode or attack_time > 0.0 or reload_remaining > 0.0:
		return
	if ammunition <= 0:
		reload_rifle()
		return
	ammunition -= 1
	attack_time = RIFLE_INTERVAL
	ammo_changed.emit(ammunition, reserve_ammunition, false)
	CharacterCatalog.play(animation, "fire")
	var camera := $CameraPivot/SpringArm3D/Camera3D as Camera3D
	var viewport_center := get_viewport().get_visible_rect().size / 2.0
	var ray_origin := camera.project_ray_origin(viewport_center)
	var ray_end := ray_origin + camera.project_ray_normal(viewport_center) * RIFLE_RANGE
	var space := get_world_3d().direct_space_state
	var camera_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	camera_query.exclude = [get_rid()]
	var aim_hit := space.intersect_ray(camera_query)
	var aim_point: Vector3 = aim_hit.position if not aim_hit.is_empty() else ray_end
	# The second ray prevents shooting through cover between the player and camera aim.
	var muzzle := global_position + Vector3.UP * 1.4
	var shot_query := PhysicsRayQueryParameters3D.create(muzzle, aim_point + (aim_point - muzzle).normalized() * 0.1)
	shot_query.exclude = [get_rid()]
	var shot := space.intersect_ray(shot_query)
	var did_hit := false
	if not shot.is_empty():
		var collider: Object = shot.collider
		if collider is Node and collider.is_in_group("training_targets") and collider.has_method("hit"):
			collider.hit(RIFLE_DAMAGE)
			did_hit = true
	shot_feedback.emit(did_hit)

func attack(heavy: bool) -> void:
	if not alive:
		return
	if attack_time > 0.0 or dodge_time > 0.0:
		return
	attack_time = ATTACK_COOLDOWN * (1.5 if heavy else 1.0)
	_play_animation("attack_heavy" if heavy else "attack_light_1")
	if is_instance_valid(placeholder_blade):
		var swing := create_tween()
		placeholder_blade.rotation.z = -0.3
		swing.tween_property(placeholder_blade, "rotation:z", -1.7 if heavy else -1.3, 0.12)
		swing.tween_property(placeholder_blade, "rotation:z", -0.3, 0.22)
	var nearest: Node3D
	var closest: float = 3.0
	for candidate: Node in get_tree().get_nodes_in_group("training_targets"):
		var offset: Vector3 = candidate.global_position - global_position
		offset.y = 0
		if offset.length() < closest and offset.length() > 0.01 and visual.global_basis.z.dot(offset.normalized()) > 0.3:
			nearest = candidate as Node3D
			closest = offset.length()
	if nearest:
		nearest.hit(30 if heavy else 15)

func _lock_target() -> void:
	if is_instance_valid(target):
		target = null
		return
	var nearest_distance: float = 15.0
	for candidate: Node in get_tree().get_nodes_in_group("training_targets"):
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			target = candidate as Node3D
			nearest_distance = distance

func _play_animation(name: String) -> void:
	if animation.has_animation(name) and animation.current_animation != name:
		animation.play(name)
	else:
		CharacterCatalog.play(animation, name)

func _add_placeholder() -> void:
	var chosen := CharacterCatalog.attach(visual, CharacterCatalog.selected_id())
	if chosen:
		animation = chosen
		return
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6e747b")
	body.material_override = material
	visual.add_child(body)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.09, 0.85, 0.05)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.55, 1.0, 0.25)
	blade.rotation.z = -0.3
	visual.add_child(blade)
	placeholder_blade = blade


func hit(amount: int) -> void:
	if not alive:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health)
	if health == 0:
		alive = false
		fire_held = false
		remove_from_group("royale_contestants")
		velocity = Vector3.ZERO
		set_physics_process(false)
		set_process_unhandled_input(false)
		defeated.emit()


func _enable_touch_controls() -> void:
	if touch_controls:
		return
	touch_controls = TouchControls.new()
	touch_controls.mode = "royale" if rifle_mode else "solo"
	add_child(touch_controls)
	touch_controls.action_pressed.connect(_on_touch_action)
	touch_controls.look_dragged.connect(_on_touch_look)
	touch_controls.fire_state_changed.connect(_on_fire_state)

func _on_fire_state(pressed: bool) -> void:
	if rifle_mode:
		fire_held = pressed

func _on_touch_action(action: String) -> void:
	match action:
		"Attack": attack(false)
		"Reload": reload_rifle()
		"Heavy": attack(true)
		"Jump": mobile_jump = true
		"Dodge": mobile_dodge = true
		"Lock": _lock_target()
		"Retry":
			if get_parent().name == "BattleRoyale" and get_parent().match_finished:
				get_tree().reload_current_scene()
		"Menu": get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")

func _on_touch_look(relative: Vector2) -> void:
	pivot.rotation.y -= relative.x * 0.003
	pivot.rotation.x = clampf(pivot.rotation.x - relative.y * 0.003, -0.8, 0.55)
