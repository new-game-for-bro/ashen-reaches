extends Control

const CharacterCatalog = preload("res://scripts/characters/character_catalog.gd")

var username: LineEdit
var address: LineEdit
var message_input: LineEdit
var status: Label
var roster: Label
var history: RichTextLabel

func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args() or "--server" in OS.get_cmdline_args():
		var error := NetworkManager.host_server("Dedicated server", NetworkManager.DEFAULT_PORT, true)
		if error == OK:
			get_tree().change_scene_to_file.call_deferred("res://scenes/network/network_arena.tscn")
		else:
			push_error("Could not start dedicated server: " + error_string(error))
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color("1d2024")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.position = Vector2(-300, -260)
	column.size = Vector2(600, 520)
	add_child(column)
	var title := Label.new()
	title.text = "ASHEN REACHES  /  CHOOSE YOUR MODE"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var character_picker := OptionButton.new()
	character_picker.add_item("Default character", 0)
	for id in range(1, CharacterCatalog.CHARACTER_COUNT + 1):
		if CharacterCatalog.is_available(id):
			character_picker.add_item("Character %d" % id, id)
	var selected := CharacterCatalog.selected_id()
	for index in range(character_picker.item_count):
		if character_picker.get_item_id(index) == selected:
			character_picker.select(index)
	character_picker.item_selected.connect(func(index: int) -> void:
		CharacterCatalog.select(character_picker.get_item_id(index))
	)
	column.add_child(character_picker)
	username = LineEdit.new()
	username.placeholder_text = "Player name"
	username.text = "Emberbound"
	username.max_length = 24
	column.add_child(username)
	address = LineEdit.new()
	address.placeholder_text = "Server IP or hostname"
	address.text = "127.0.0.1"
	column.add_child(address)
	var buttons := GridContainer.new()
	buttons.columns = 3
	column.add_child(buttons)
	for action: String in ["Story prologue", "Solo arena", "Battle Royale", "Host", "Join", "Disconnect", "Quit"]:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(175, 50)
		button.pressed.connect(_button_pressed.bind(action))
		buttons.add_child(button)
	status = Label.new()
	status.text = "Choose a mode. Battle Royale is currently a solo match against bots."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	roster = Label.new()
	roster.text = "Players: —"
	column.add_child(roster)
	history = RichTextLabel.new()
	history.custom_minimum_size = Vector2(0, 110)
	history.bbcode_enabled = false
	column.add_child(history)
	message_input = LineEdit.new()
	message_input.placeholder_text = "Chat message (press Enter)"
	message_input.max_length = 200
	message_input.text_submitted.connect(_send_message)
	column.add_child(message_input)
	NetworkManager.connection_state_changed.connect(_set_status)
	NetworkManager.roster_changed.connect(_set_roster)
	NetworkManager.chat_received.connect(_receive_message)

func _button_pressed(action: String) -> void:
	match action:
		"Story prologue":
			NetworkManager.disconnect_session()
			get_tree().change_scene_to_file("res://scenes/story/prologue.tscn")
		"Battle Royale":
			NetworkManager.disconnect_session()
			get_tree().change_scene_to_file("res://scenes/battle_royale/battle_royale.tscn")
		"Host":
			var error := NetworkManager.host_server(username.text)
			if error != OK:
				_set_status("Host failed: " + error_string(error))
			else:
				get_tree().change_scene_to_file.call_deferred("res://scenes/network/network_arena.tscn")
		"Join":
			if address.text.strip_edges().is_empty():
				_set_status("Enter a server address.")
			else:
				NetworkManager.pending_address = address.text
				NetworkManager.pending_username = username.text
				get_tree().change_scene_to_file.call_deferred("res://scenes/network/network_arena.tscn")
		"Disconnect":
			NetworkManager.disconnect_session()
			_set_status("Offline")
		"Quit":
			NetworkManager.disconnect_session()
			get_tree().quit()
		"Solo arena":
			NetworkManager.disconnect_session()
			get_tree().change_scene_to_file("res://scenes/world/training_arena.tscn")

func _set_status(value: String) -> void:
	status.text = value
	if value == "connected":
		get_tree().change_scene_to_file.call_deferred("res://scenes/network/network_arena.tscn")

func _set_roster(players: Dictionary) -> void:
	var names: PackedStringArray = []
	for name_value: Variant in players.values():
		names.append(str(name_value))
	roster.text = "Players: " + (", ".join(names) if not names.is_empty() else "—")

func _send_message(value: String) -> void:
	NetworkManager.send_chat(value)
	message_input.clear()

func _receive_message(sender_name: String, value: String) -> void:
	history.add_text(sender_name + ": " + value + "\n")
