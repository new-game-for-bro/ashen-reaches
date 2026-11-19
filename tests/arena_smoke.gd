extends SceneTree
var role: String
var entered: bool = false
var sent: bool = false
var ticks: int = 0
var peer_id: int = 0
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	role = OS.get_cmdline_user_args()[0]
	var manager = root.get_node("NetworkManager")
	manager.connection_state_changed.connect(on_state)
	if role == "server":
		assert(manager.host_server("Host", 18992) == OK)
		enter_arena()
	else:
		manager.pending_address = "127.0.0.1"
		manager.pending_username = "Guest"
		manager.pending_port = 18992
		enter_arena()
	await create_timer(15.0).timeout
	push_error("arena test timed out " + role)
	quit(1)
func on_state(state: String) -> void:
	if state == "connected":
		peer_id = root.get_node("NetworkManager").multiplayer.get_unique_id()
func enter_arena() -> void:
	change_scene_to_file("res://scenes/network/network_arena.tscn")
	entered = true
func _process(_delta: float) -> bool:
	if not entered or not current_scene:
		return false
	var players = current_scene.get_node_or_null("Players")
	if not players:
		return false
	if players.get_child_count() != 2:
		return false
	if role == "client":
		var player = players.get_node_or_null(str(peer_id))
		if player:
			player._submit_input.rpc_id(1, Vector2(1, 0), 0.0, false, false)
			ticks += 1
			if ticks > 10 and player.global_position.x > float(peer_id % 5) * 2.0 + 0.5:
				print("PASS client received server movement")
				quit(0)
	elif not sent:
		for player in players.get_children():
			if player.peer_id != 1 and player.last_input_ms > 0 and player.global_position.x > float(player.peer_id % 5) * 2.0 + 0.5:
				sent = true
				print("PASS server spawned and moved client")
				create_timer(3.0).timeout.connect(func(): quit(0))
	return false
