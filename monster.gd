extends Node3D

var player: CharacterBody3D
var health := 3
var attack_timer := 0.0
var spawn_position: Vector3
var phase := 0.0

func _ready() -> void:
	spawn_position = global_position
	add_to_group("monsters")

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	phase += delta * 3.0
	var toward := player.global_position - global_position
	toward.y = 0
	var distance := toward.length()
	if distance < 16 and distance > 1.6:
		global_position += toward.normalized() * 2.4 * delta
	elif distance <= 1.6 and attack_timer <= 0:
		player.take_damage(12)
		attack_timer = 1.1
	elif distance >= 16 and global_position.distance_to(spawn_position) > 0.5:
		global_position = global_position.move_toward(spawn_position, delta)
	if get_child_count() > 0:
		get_child(0).position.y = 1.1 + sin(phase) * 0.1

func hit() -> void:
	health -= 1
	if health <= 0:
		get_parent().monster_defeated()
		queue_free()
