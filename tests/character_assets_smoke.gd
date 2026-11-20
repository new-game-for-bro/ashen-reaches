extends SceneTree
const Catalog = preload("res://scripts/characters/character_catalog.gd")
func _initialize() -> void:
	call_deferred("run_test")
func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found:
			return found
	return null
func run_test() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	for id in range(1, 5):
		assert(Catalog.is_available(id))
		assert(Catalog.select(id) and Catalog.selected_id() == id)
		var holder := Node3D.new()
		parent.add_child(holder)
		var player := Catalog.attach(holder, id)
		assert(player != null and player.has_animation("punching"))
		var skeleton := find_skeleton(holder)
		assert(skeleton != null)
		player.play("punching")
		player.advance(0.0)
		var before: Array[Quaternion] = []
		for bone in range(skeleton.get_bone_count()):
			before.append(skeleton.get_bone_pose_rotation(bone))
		player.advance(0.4)
		var moved := false
		for bone in range(skeleton.get_bone_count()):
			if not before[bone].is_equal_approx(skeleton.get_bone_pose_rotation(bone)):
				moved = true
		assert(moved)
		Catalog.play(player, "idle")
		assert(player.current_animation == "rifle_aiming_idle")
		print("PASS: selected character ", id, " action moves its skeleton")
		holder.queue_free()
		await process_frame
	assert(Catalog.select(0))
	quit()
