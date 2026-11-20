extends CharacterBody3D
const MAW_SCENE = preload("res://maw_of_the_void_-_free_creature_asset.glb")

# Patrols the side lane until the player approaches; stays out of the duel area.
var patrol_points: Array[Vector3] = []
var patrol_index := 0
var player: Node3D
var health := 3
var agent: NavigationAgent3D

func _ready() -> void:
	name = "RuinMonster"
	add_to_group("story_monsters")
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.7
	agent.target_desired_distance = 1.0
	add_child(agent)
	var model_scene: PackedScene = MAW_SCENE
	if model_scene:
		var visual := model_scene.instantiate() as Node3D
		visual.position.y = 0.7
		visual.scale = Vector3.ONE * 1.5
		add_child(visual)
		var animation := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animation and not animation.get_animation_list().is_empty():
			animation.play(animation.get_animation_list()[0])

func _physics_process(delta: float) -> void:
	if patrol_points.is_empty() or not is_instance_valid(player):
		return
	var chase := global_position.distance_to(player.global_position) < 8.0 and player.global_position.x < -12.0
	if chase:
		agent.target_position = player.global_position
	else:
		if global_position.distance_to(patrol_points[patrol_index]) < 1.5:
			patrol_index = (patrol_index + 1) % patrol_points.size()
		agent.target_position = patrol_points[patrol_index]
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return
	var direction := agent.get_next_path_position() - global_position
	direction.y = 0.0
	if agent.is_navigation_finished() or direction.length() < 0.1:
		velocity.x = 0
		velocity.z = 0
	else:
		direction = direction.normalized()
		velocity.x = direction.x * (3.0 if chase else 1.5)
		velocity.z = direction.z * (3.0 if chase else 1.5)
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 5.0))
	velocity.y = -2.0
	move_and_slide()

func hit() -> void:
	health -= 1
	if health <= 0:
		queue_free()
