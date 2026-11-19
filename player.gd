extends CharacterBody3D

var camera: Camera3D
var pitch := 0.0
var health := 100
var map_open := false
var attack_timer := 0.0

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
