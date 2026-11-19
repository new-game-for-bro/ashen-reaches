extends CharacterBody3D

var camera: Camera3D
var pitch := 0.0

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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0025)
		pitch = clamp(pitch - event.relative.y * 0.0025, -1.35, 1.35)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
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
