extends CharacterBody3D
signal interact_requested
signal attack_requested
signal dodge_requested
var camera_pivot: Node3D
var avatar: Node3D
var sword: Node3D
var attack_delay: float = 0.0
var control_enabled: bool = true
var dodge_time: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	avatar = Node3D.new()
	add_child(avatar)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("778ba2")
	body.material_override = material
	avatar.add_child(body)
	sword = Node3D.new()
	sword.position = Vector3(0.55, 1, 0.15)
	avatar.add_child(sword)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.1, 0.9, 0.08)
	blade.mesh = blade_mesh
	blade.position.y = 0.35
	sword.add_child(blade)
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.4
	add_child(camera_pivot)
	var arm := SpringArm3D.new()
	arm.spring_length = 5.0
	arm.add_excluded_object(get_rid())
	camera_pivot.add_child(arm)
	var camera := Camera3D.new()
	camera.current = true
	arm.add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y -= event.relative.x * 0.003
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * 0.003, -0.8, 0.55)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E and control_enabled:
			interact_requested.emit()
		elif event.keycode == KEY_SPACE and control_enabled:
			attack()
		elif event.keycode == KEY_C and control_enabled and dodge_time <= 0.0:
			dodge_direction = -avatar.global_basis.z
			dodge_time = 0.25
			dodge_requested.emit()
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT and control_enabled:
			attack()

func attack() -> void:
	if attack_delay > 0.0:
		return
	attack_delay = 0.5
	var swing := create_tween()
	sword.rotation.z = 0
	swing.tween_property(sword, "rotation:z", -1.5, 0.12)
	swing.tween_property(sword, "rotation:z", 0.0, 0.22)
	attack_requested.emit()

func _physics_process(delta: float) -> void:
	attack_delay = maxf(0.0, attack_delay - delta)
	var axis := Vector2.ZERO
	if control_enabled:
		axis = Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))).normalized()
	var direction := Basis(Vector3.UP, camera_pivot.rotation.y) * Vector3(axis.x, 0, axis.y)
	var speed := 7.5 if Input.is_key_pressed(KEY_SHIFT) else 5.0
	dodge_time = maxf(0.0, dodge_time - delta)
	if dodge_time > 0.0:
		direction = dodge_direction
		speed = 10.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = velocity.y - 20.0 * delta if not is_on_floor() else 0.0
	if direction.length() > 0.1:
		avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 12.0))
	move_and_slide()
