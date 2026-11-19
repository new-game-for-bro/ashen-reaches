extends SceneTree
var observed: bool = false
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	var manager = root.get_node("NetworkManager")
	manager.roster_changed.connect(on_roster)
	assert(manager.join_server("127.0.0.1", "Test guest", 7777) == OK)
	await create_timer(5).timeout
	if not observed:
		push_error("Dedicated server handshake timed out")
		quit(1)
func on_roster(players: Dictionary) -> void:
	if players.size() == 1 and players.values().has("Test guest"):
		observed = true
		print("PASS dedicated server accepts a guest")
		quit(0)
