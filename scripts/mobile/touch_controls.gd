extends CanvasLayer
signal action_pressed(action: String)
signal look_dragged(relative: Vector2)
const Joystick = preload("res://scripts/mobile/joystick.gd")
var move_vector: Vector2 = Vector2.ZERO
var sprinting: bool = false
var mode: String = "solo"
var look_finger: int = -1
var buttons: Dictionary = {}
var joystick: Control
var look_sensitivity: float = 0.003
var invert_y: bool = false

func _ready() -> void:
	layer = 10
	joystick = Joystick.new()
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 20
	joystick.offset_right = 200
	joystick.offset_top = -205
	joystick.offset_bottom = -25
	joystick.vector_changed.connect(_on_move)
	add_child(joystick)
	if mode == "story":
		_build_story_buttons()
	else:
		_build_standard_buttons()

func _build_story_buttons() -> void:
	_make_button("Exit", Vector2(0, 0), Rect2(20, 18, 100, 56))
	_make_button("Pause", Vector2(1, 0), Rect2(-120, 18, 100, 56))
	_make_button("Interact", Vector2(1, 1), Rect2(-165, -330, 140, 64))
	_make_button("Attack", Vector2(1, 1), Rect2(-155, -245, 130, 105))
	_make_button("Dodge", Vector2(1, 1), Rect2(-265, -125, 105, 74))
	buttons["Interact"].visible = false

func _make_button(action: String, anchor: Vector2, bounds: Rect2) -> void:
	var button := Button.new()
	button.text = action
	button.anchor_left = anchor.x
	button.anchor_right = anchor.x
	button.anchor_top = anchor.y
	button.anchor_bottom = anchor.y
	button.offset_left = bounds.position.x
	button.offset_top = bounds.position.y
	button.offset_right = bounds.end.x
	button.offset_bottom = bounds.end.y
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_on_action.bind(action))
	add_child(button)
	buttons[action] = button

func _build_standard_buttons() -> void:
	var actions: Array = ["Jump", "Sprint", "Chat", "Menu"] if mode == "network" else ["Attack", "Heavy", "Dodge", "Jump", "Lock", "Sprint", "Retry", "Menu"]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.anchor_left = 1.0
	grid.anchor_right = 1.0
	grid.anchor_top = 1.0
	grid.anchor_bottom = 1.0
	grid.offset_left = -340
	grid.offset_right = -20
	grid.offset_top = -245
	grid.offset_bottom = -20
	add_child(grid)
	for action: String in actions:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(100, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_action.bind(action))
		grid.add_child(button)
		buttons[action] = button

func set_story_interaction(label: String) -> void:
	if mode == "story" and buttons.has("Interact"):
		buttons["Interact"].visible = not label.is_empty()
		buttons["Interact"].text = label

func set_exit_attention(enabled: bool) -> void:
	if mode == "story" and buttons.has("Exit"):
		buttons["Exit"].modulate = Color("ffd366") if enabled else Color.WHITE

func reset_input() -> void:
	move_vector = Vector2.ZERO
	look_finger = -1
	joystick.reset()

func _on_move(value: Vector2) -> void:
	move_vector = value

func _on_action(action: String) -> void:
	if action == "Sprint":
		sprinting = not sprinting
		buttons[action].text = "Run: ON" if sprinting else "Sprint"
	action_pressed.emit(action)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and look_finger == -1 and event.position.x > get_viewport().get_visible_rect().size.x * 0.45:
			look_finger = event.index
		elif not event.pressed and event.index == look_finger:
			look_finger = -1
	elif event is InputEventScreenDrag and event.index == look_finger:
		look_dragged.emit(event.relative)
