extends CanvasLayer
signal action_pressed(action: String)
signal look_dragged(relative: Vector2)
const Joystick = preload("res://scripts/mobile/joystick.gd")
var move_vector: Vector2 = Vector2.ZERO
var sprinting: bool = false
var mode: String = "solo"
var look_finger: int = -1
var buttons: Dictionary = {}

func _ready() -> void:
	layer = 10
	var joystick: Control = Joystick.new()
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
	var actions: Array[String] = []
	match mode:
		"story": actions = ["Attack", "Dodge", "Interact", "Sprint", "Menu"]
		"network": actions = ["Jump", "Sprint", "Chat", "Menu"]
		_: actions = ["Attack", "Heavy", "Dodge", "Jump", "Lock", "Sprint", "Retry", "Menu"]
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
	var instruction := Label.new()
	instruction.text = "Drag here to look"
	instruction.anchor_left = 1.0
	instruction.anchor_right = 1.0
	instruction.anchor_top = 0.5
	instruction.anchor_bottom = 0.5
	instruction.offset_left = -220
	instruction.offset_right = -20
	instruction.offset_top = -110
	instruction.offset_bottom = -80
	instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(instruction)

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
