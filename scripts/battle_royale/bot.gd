extends CharacterBody3D

signal eliminated(bot: Node)
const SPEED: float = 3.4
const DAMAGE: int = 12
const ATTACK_INTERVAL: float = 1.2
var health: int = 60
var cooldown: float = 0.0
var alive: bool = true
var label: Label3D

func _ready() -> void:
	add_to_group("royale_contestants")
	add_to_group("training_targets")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a2594e")
	body.material_override = mat
	visual.add_child(body)
	label = Label3D.new()
	label.position.y = 2.2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	add_child(label)
	_update_label()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	cooldown = maxf(0.0, cooldown - delta)
	var nearest: Node3D
	var distance := INF
	for candidate: Node in get_tree().get_nodes_in_group("royale_contestants"):
		if candidate == self or candidate.is_queued_for_deletion():
			continue
		var other := candidate as Node3D
		var d := global_position.distance_to(other.global_position)
		if d < distance:
			distance = d
			nearest = other
	if nearest:
		var direction := nearest.global_position - global_position
		direction.y = 0
		if direction.length() > 1.8:
			velocity.x = direction.normalized().x * SPEED
			velocity.z = direction.normalized().z * SPEED
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if cooldown <= 0.0:
				nearest.hit(DAMAGE)
				cooldown = ATTACK_INTERVAL
	velocity.y = velocity.y - 18.0 * delta if not is_on_floor() else 0.0
	move_and_slide()

func hit(amount: int) -> void:
	if not alive:
		return
	health = maxi(0, health - amount)
	_update_label()
	if health == 0:
		alive = false
		remove_from_group("royale_contestants")
		remove_from_group("training_targets")
		eliminated.emit(self)
		queue_free()

func _update_label() -> void:
	label.text = "RIVAL  ·  HP %d" % health
