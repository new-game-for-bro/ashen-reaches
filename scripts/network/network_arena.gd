extends Node3D

const WorldModels = preload("res://scripts/world/model_environment.gd")

const PlayerScript = preload("res://scripts/network/network_player.gd")
const InputSetup = preload("res://scripts/player/input_setup.gd")
@onready var players_node: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
var chat_input: LineEdit
var chat_output: RichTextLabel

func _ready() -> void:
	WorldModels.add_to(self, Vector3.ZERO, 75.0)
	InputSetup.configure()
	spawner.spawn_function = _create_player
	multiplayer.peer_disconnected.connect(_remove_player)
	NetworkManager.connection_state_changed.connect(_connection_changed)
	if DisplayServer.get_name() != "headless":
		_build_ui()
	if not NetworkManager.pending_address.is_empty():
		var address: String = NetworkManager.pending_address
		var username: String = NetworkManager.pending_username
		NetworkManager.pending_address = ""
		var error := NetworkManager.join_server(address, username, NetworkManager.pending_port)
		if error != OK:
			push_error("Could not connect: " + error_string(error))
			get_tree().change_scene_to_file.call_deferred("res://scenes/ui/network_lobby.tscn")
	elif multiplayer.is_server():
		if not NetworkManager.dedicated:
			spawner.spawn({"id": 1, "name": NetworkManager.player_name})

func _create_player(info: Dictionary) -> Node:
	var player := CharacterBody3D.new()
	player.name = str(info["id"])
	player.set_script(PlayerScript)
	player.peer_id = int(info["id"])
	player.display_name = str(info["name"])
	player.position = Vector3(float(player.peer_id % 5) * 2.0, 0, 0)
	return player

@rpc("any_peer", "call_remote", "reliable")
func announce_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 1 or not NetworkManager.players.has(id) or players_node.has_node(str(id)):
		return
	spawner.spawn({"id": id, "name": NetworkManager.players[id]})

func _remove_player(id: int) -> void:
	if multiplayer.is_server():
		var player := players_node.get_node_or_null(str(id))
		if player:
			player.queue_free()

func _connection_changed(state: String) -> void:
	if state == "connected":
		announce_ready.rpc_id(1)
	if state == "server_disconnected" or state == "connection_failed":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")

func _build_ui() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.position = Vector2(20, 15)
	hint.text = "MULTIPLAYER TEST  |  Move with the joystick; drag to look" if OS.has_feature("mobile") else "MULTIPLAYER TEST  |  WASD move · Shift sprint · Space jump · Enter chat · Esc cursor"
	layer.add_child(hint)
	chat_output = RichTextLabel.new()
	chat_output.position = Vector2(20, 60)
	chat_output.size = Vector2(420, 140)
	chat_output.bbcode_enabled = false
	layer.add_child(chat_output)
	chat_input = LineEdit.new()
	chat_input.position = Vector2(20, 205)
	chat_input.size = Vector2(420, 32)
	chat_input.placeholder_text = "Enter chat message"
	chat_input.visible = false
	chat_input.text_submitted.connect(_send_chat)
	layer.add_child(chat_input)
	NetworkManager.chat_received.connect(_receive_chat)

func _input(event: InputEvent) -> void:
	if chat_input and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and not chat_input.visible:
		chat_input.visible = true
		chat_input.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()

func _send_chat(value: String) -> void:
	NetworkManager.send_chat(value)
	chat_input.clear()
	chat_input.release_focus()
	chat_input.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _receive_chat(sender_name: String, value: String) -> void:
	chat_output.add_text(sender_name + ": " + value + "\n")
