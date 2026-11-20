extends Node

const CharacterCatalog = preload("res://scripts/characters/character_catalog.gd")

signal roster_changed(players: Dictionary)
signal chat_received(sender_name: String, message: String)
signal connection_state_changed(state: String)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 16
const MAX_NAME_LENGTH: int = 24
const MAX_CHAT_LENGTH: int = 200
const MIN_CHAT_INTERVAL_MS: int = 750

var dedicated: bool = false
var pending_address: String = ""
var pending_username: String = ""
var pending_port: int = DEFAULT_PORT
var players: Dictionary = {}
var character_choices: Dictionary = {}
var player_name: String = "Emberbound"
var chat_times: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

func host_server(username: String, port: int = DEFAULT_PORT, is_dedicated: bool = false) -> Error:
	if not _valid_port(port):
		return ERR_INVALID_PARAMETER
	disconnect_session()
	dedicated = is_dedicated
	player_name = _sanitize_name(username)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_PLAYERS if dedicated else MAX_PLAYERS - 1)
	if result != OK:
		return result
	multiplayer.multiplayer_peer = peer
	if not dedicated:
		players[1] = player_name
		character_choices[1] = CharacterCatalog.selected_id()
	roster_changed.emit(players.duplicate())
	connection_state_changed.emit("hosting")
	return OK

func join_server(address: String, username: String, port: int = DEFAULT_PORT) -> Error:
	if address.strip_edges().is_empty() or address.length() > 253 or not _valid_port(port):
		return ERR_INVALID_PARAMETER
	disconnect_session()
	player_name = _sanitize_name(username)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(), port)
	if result != OK:
		return result
	multiplayer.multiplayer_peer = peer
	connection_state_changed.emit("connecting")
	return OK

func disconnect_session() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	character_choices.clear()
	chat_times.clear()
	roster_changed.emit({})

func send_chat(message: String) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_accept_chat(1, message)
	else:
		_submit_chat.rpc_id(1, message)

func _connected() -> void:
	_register_name.rpc_id(1, player_name, CharacterCatalog.selected_id())
	connection_state_changed.emit("connected")

@rpc("any_peer", "call_remote", "reliable")
func _register_name(requested_name: String, character_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or not multiplayer.get_peers().has(sender) or players.has(sender) or requested_name.length() > 128:
		return
	players[sender] = _sanitize_name(requested_name)
	character_choices[sender] = character_id if CharacterCatalog.is_available(character_id) else 0
	_publish_roster()

@rpc("any_peer", "call_remote", "reliable")
func _submit_chat(message: String) -> void:
	if multiplayer.is_server():
		_accept_chat(multiplayer.get_remote_sender_id(), message)

func _accept_chat(sender: int, message: String) -> void:
	if not players.has(sender) or message.length() > MAX_CHAT_LENGTH:
		return
	var clean := message.strip_edges()
	if clean.is_empty() or clean.contains("\n") or clean.contains("\r"):
		return
	var now := Time.get_ticks_msec()
	if chat_times.has(sender) and now - int(chat_times[sender]) < MIN_CHAT_INTERVAL_MS:
		return
	chat_times[sender] = now
	_receive_chat.rpc(str(players[sender]), clean)

@rpc("authority", "call_local", "reliable")
func _receive_chat(sender_name: String, message: String) -> void:
	chat_received.emit(sender_name, message)

func _publish_roster() -> void:
	_set_roster.rpc(players)

@rpc("authority", "call_local", "reliable")
func _set_roster(value: Dictionary) -> void:
	players = value.duplicate()
	roster_changed.emit(players.duplicate())

func _peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		character_choices.erase(id)
		chat_times.erase(id)
		_publish_roster()

func _connection_failed() -> void:
	disconnect_session()
	connection_state_changed.emit("connection_failed")

func _server_disconnected() -> void:
	disconnect_session()
	connection_state_changed.emit("server_disconnected")

func _valid_port(port: int) -> bool:
	return port >= 1 and port <= 65535

func _sanitize_name(value: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ")
	if clean.is_empty():
		return "Emberbound"
	return clean.substr(0, MAX_NAME_LENGTH)
