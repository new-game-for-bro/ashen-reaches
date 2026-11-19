extends SceneTree
var manager: Node
var role: String
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	role = OS.get_cmdline_user_args()[0]
	manager = load("res://autoload/NetworkManager.gd").new()
	manager.name = "NetworkManager"
	root.add_child(manager)
	manager.roster_changed.connect(on_roster)
	manager.chat_received.connect(on_chat)
	if role == "server":
		assert(manager.host_server("Host", 18991) == OK)
	else:
		assert(manager.join_server("127.0.0.1", "Guest", 18991) == OK)
	await create_timer(8.0).timeout
	push_error("network test timed out " + role)
	quit(1)
func on_roster(players: Dictionary) -> void:
	if role == "client" and players.size() == 2:
		manager.send_chat("Hello from guest")
func on_chat(sender: String, message: String) -> void:
	if sender == "Guest" and message == "Hello from guest":
		print("PASS ", role, " roster and chat")
		if role == "server":
			await create_timer(0.5).timeout
		quit(0)
