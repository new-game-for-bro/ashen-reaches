extends CharacterBody3D
const TouchControls = preload("res://scripts/mobile/touch_controls.gd")

const SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0
const GRAVITY: float = 18.0
const JUMP_SPEED: float = 6.0
const MAX_INPUT_RATE_MS: int = 12
const INPUT_TIMEOUT_MS: int = 500
const SNAPSHOT_INTERVAL: float = 0.05

var peer_id: int = 0
var display_name: String = "Emberbound"
var input_direction: Vector2 = Vector2.ZERO
var input_yaw: float = 0.0
var sprinting: bool = false
var jump_requested: bool = false
var last_input_ms: int = 0
var snapshot_timer: float = 0.0
var remote_position: Vector3
var has_snapshot: bool = false
var health: int = 100
var animation_state: String = "idle"
var touch_controls: CanvasLayer
var mobile_jump: bool = false
var pivot: Node3D
var visual: Node3D
var label: Label3D

func _ready() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.8
	mesh.mesh = body
	mesh.position.y = 0.9
	visual.add_child(mesh)
	label = Label3D.new()
	label.text = display_name + "  ·  HP 100"
	label.position.y = 2.2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	add_child(label)
	if multiplayer.get_unique_id() == peer_id and DisplayServer.get_name() != "headless":
		pivot = Node3D.new()
		pivot.position.y = 1.5
		add_child(pivot)
		var arm := SpringArm3D.new()
		arm.spring_length = 4.5
		arm.add_excluded_object(get_rid())
		pivot.add_child(arm)
		var camera := Camera3D.new()
		camera.current = true
		arm.add_child(camera)
		if OS.has_feature("mobile"):
			_enable_touch_controls()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not pivot:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * 0.003
		pivot.rotation.x = clampf(pivot.rotation.x - event.relative.y * 0.003, -0.8, 0.55)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if multiplayer.get_unique_id() == peer_id and pivot:
		var typing := get_viewport().gui_get_focus_owner() is LineEdit
		var axis := Vector2.ZERO if typing else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if not typing and touch_controls and touch_controls.move_vector.length() > 0.0:
			axis = touch_controls.move_vector
		var jump := not typing and (Input.is_action_just_pressed("jump") or mobile_jump)
		var run: bool = not typing and (Input.is_action_pressed("sprint") or (touch_controls != null and touch_controls.sprinting))
		mobile_jump = false
		if multiplayer.is_server():
			_set_input(axis, pivot.rotation.y, run, jump)
		else:
			_submit_input.rpc_id(1, axis, pivot.rotation.y, run, jump)
	if multiplayer.is_server():
		if Time.get_ticks_msec() - last_input_ms > INPUT_TIMEOUT_MS:
			input_direction = Vector2.ZERO
			sprinting = false
		var direction := Basis(Vector3.UP, input_yaw) * Vector3(input_direction.x, 0, input_direction.y)
		var speed := SPRINT_SPEED if sprinting else SPEED
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif jump_requested:
			velocity.y = JUMP_SPEED
		else:
			velocity.y = 0.0
		jump_requested = false
		if direction.length() > 0.1:
			visual.rotation.y = atan2(direction.x, direction.z)
		move_and_slide()
		animation_state = "fall" if not is_on_floor() and velocity.y < 0 else "jump" if not is_on_floor() else "run" if direction.length() > 0.1 and sprinting else "walk" if direction.length() > 0.1 else "idle"
		snapshot_timer -= delta
		if snapshot_timer <= 0.0:
			snapshot_timer = SNAPSHOT_INTERVAL
			_receive_state.rpc(global_position, visual.rotation.y, health, animation_state)
	elif has_snapshot:
		global_position = global_position.lerp(remote_position, minf(1.0, delta * 14.0))

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input(axis: Vector2, yaw: float, run: bool, jump: bool) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	if not axis.is_finite() or not is_finite(yaw):
		return
	var now := Time.get_ticks_msec()
	if now - last_input_ms < MAX_INPUT_RATE_MS:
		return
	_set_input(axis, yaw, run, jump)

func _set_input(axis: Vector2, yaw: float, run: bool, jump: bool) -> void:
	input_direction = axis.limit_length(1.0)
	input_yaw = wrapf(yaw, -PI, PI)
	sprinting = run
	jump_requested = jump_requested or jump
	last_input_ms = Time.get_ticks_msec()

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_state(position_value: Vector3, yaw: float, hp: int, state: String) -> void:
	if position_value.is_finite() and is_finite(yaw) and hp >= 0 and hp <= 100 and state in ["idle", "walk", "run", "jump", "fall"]:
		remote_position = position_value
		visual.rotation.y = yaw
		health = hp
		animation_state = state
		label.text = display_name + "  ·  HP " + str(health)
		has_snapshot = true


func _enable_touch_controls() -> void:
	if touch_controls:
		return
	touch_controls = TouchControls.new()
	touch_controls.mode = "network"
	add_child(touch_controls)
	touch_controls.action_pressed.connect(_on_touch_action)
	touch_controls.look_dragged.connect(_on_touch_look)

func _on_touch_action(action: String) -> void:
	match action:
		"Jump": mobile_jump = true
		"Chat":
			var arena := get_parent().get_parent()
			if arena.chat_input:
				arena.chat_input.visible = true
				arena.chat_input.grab_focus()
		"Menu":
			NetworkManager.disconnect_session()
			get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")

func _on_touch_look(relative: Vector2) -> void:
	pivot.rotation.y -= relative.x * 0.003
	pivot.rotation.x = clampf(pivot.rotation.x - relative.y * 0.003, -0.8, 0.55)
