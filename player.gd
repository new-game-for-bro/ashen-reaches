extends CharacterBody3D

var camera: Camera3D
var pitch := 0.0
var health := 100
var map_open := false
var attack_timer := 0.0
var sword: Node3D
var swing_time := 0.0

func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 0.65
	camera.current = true
	add_child(camera)
	_build_sword()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and not event.echo and not map_open:
		if event.keycode == KEY_SPACE:
			attack()
		elif event.keycode == KEY_E:
			get_parent().interact()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0025)
		pitch = clamp(pitch - event.relative.y * 0.0025, -1.35, 1.35)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)
	swing_time = maxf(0.0, swing_time - delta)
	if sword:
		var swing := sin((1.0 - swing_time / 0.3) * PI) if swing_time > 0.0 else 0.0
		sword.rotation.z = -0.2 - swing * 1.1
		sword.position.y = -0.42 + swing * 0.15
	var input := Vector2.ZERO
	if map_open:
		velocity.x = 0
		velocity.z = 0
		return
	input.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	input.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	input = input.normalized()
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := 10.0 if Input.is_key_pressed(KEY_SHIFT) else 6.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func attack() -> void:
	if attack_timer > 0:
		return
	attack_timer = 0.5
	swing_time = 0.3
	var best: Node3D = null
	var best_distance := 3.5
	for enemy in get_tree().get_nodes_in_group("monsters"):
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0
		var distance := offset.length()
		if distance < best_distance and distance > 0 and (-global_transform.basis.z).dot(offset.normalized()) > 0.35:
			best = enemy
			best_distance = distance
	if best:
		best.hit()
		get_parent().message.text = "Your strike hits the hollow!"
	else:
		get_parent().message.text = "Swing! Face a nearby hollow to hit it."

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		health = 100
		global_position = Vector3(0, 1, 8)
		velocity = Vector3.ZERO
		get_parent().message.text = "You fell and awoke at the haven."
	else:
		get_parent().message.text = "A hollow strikes you!"


func _build_sword() -> void:
	sword = Node3D.new()
	sword.position = Vector3(0.43, -0.42, -0.8)
	sword.rotation.z = -0.2
	camera.add_child(sword)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 0.75, 0.025)
	blade.mesh = blade_mesh
	blade.position.y = 0.45
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("a9adb1")
	steel.metallic = 0.6
	blade.material_override = steel
	sword.add_child(blade)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.25, 0.045, 0.07)
	guard.mesh = guard_mesh
	guard.position.y = 0.06
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("665544")
	guard.material_override = iron
	sword.add_child(guard)
	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.055, 0.23, 0.055)
	grip.mesh = grip_mesh
	grip.position.y = -0.07
	grip.material_override = iron
	sword.add_child(grip)
