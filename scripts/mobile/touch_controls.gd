extends CanvasLayer
signal action_pressed(action: String)
signal look_dragged(relative: Vector2)
const Joystick = preload("res://scripts/mobile/joystick.gd")
const CONFIG_PATH = "user://touch_layout.cfg"
const REFERENCE_SIZE = Vector2(1280, 720)
var move_vector: Vector2 = Vector2.ZERO
var sprinting: bool = false
var mode: String = "solo"
var look_finger: int = -1
var buttons: Dictionary = {}
var joystick: Control
var look_sensitivity: float = 0.003
var invert_y: bool = false
var edit_mode := false
var selected := ""
var drag_finger := -1
var drag_offset := Vector2.ZERO
var positions: Dictionary = {}
var scales: Dictionary = {}
var base_sizes: Dictionary = {}
var editor_bar: PanelContainer
var size_slider: HSlider
var edit_button: Button
var interaction_label := ""

func _ready() -> void:
	layer = 10
	joystick = Joystick.new()
	joystick.vector_changed.connect(_on_move)
	add_child(joystick)
	base_sizes["Move"] = Vector2(180, 180)
	if mode == "story":
		_build_story_buttons()
	else:
		_build_standard_buttons()
	_build_editor()
	_load_layout()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)

func _build_story_buttons() -> void:
	_make_button("Exit", Vector2(100, 56))
	_make_button("Pause", Vector2(100, 56))
	_make_button("Interact", Vector2(140, 64))
	_make_button("Attack", Vector2(130, 105))
	_make_button("Dodge", Vector2(105, 74))
	buttons["Interact"].visible = false

func _make_button(action: String, dimensions: Vector2) -> void:
	var button := Button.new()
	button.text = action
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20 if action == "Attack" else 17)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.18, 0.78)
	style.border_color = Color(0.90, 0.75, 0.48, 0.85) if action == "Attack" else Color(0.75, 0.83, 0.90, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	button.add_theme_stylebox_override("normal", style)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.42, 0.32, 0.22, 0.9)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.pressed.connect(_on_action.bind(action))
	add_child(button)
	buttons[action] = button
	base_sizes[action] = dimensions

func _build_standard_buttons() -> void:
	var actions: Array = ["Jump", "Sprint", "Chat", "Menu"] if mode == "network" else ["Attack", "Heavy", "Dodge", "Jump", "Lock", "Sprint", "Retry", "Menu"]
	for action: String in actions:
		_make_button(action, Vector2(125, 105) if action == "Attack" else Vector2(90, 65))

func _defaults() -> Dictionary:
	if mode == "story":
		return {"Move": Vector2(0.087, 0.84), "Exit": Vector2(0.055, 0.064), "Pause": Vector2(0.945, 0.064), "Interact": Vector2(0.925, 0.59), "Attack": Vector2(0.935, 0.73), "Dodge": Vector2(0.835, 0.88)}
	if mode == "network":
		return {"Move": Vector2(0.087, 0.84), "Jump": Vector2(0.92, 0.80), "Sprint": Vector2(0.80, 0.88), "Chat": Vector2(0.82, 0.70), "Menu": Vector2(0.94, 0.06)}
	return {"Move": Vector2(0.087, 0.84), "Attack": Vector2(0.93, 0.76), "Heavy": Vector2(0.82, 0.67), "Dodge": Vector2(0.83, 0.88), "Jump": Vector2(0.92, 0.58), "Lock": Vector2(0.73, 0.76), "Sprint": Vector2(0.25, 0.88), "Retry": Vector2(0.82, 0.06), "Menu": Vector2(0.94, 0.06)}

func _build_editor() -> void:
	edit_button = Button.new()
	edit_button.text = "HUD"
	edit_button.position = Vector2(12, 90)
	edit_button.custom_minimum_size = Vector2(70, 48)
	edit_button.pressed.connect(_start_edit)
	add_child(edit_button)
	editor_bar = PanelContainer.new()
	editor_bar.position = Vector2(200, 12)
	var row := HBoxContainer.new()
	editor_bar.add_child(row)
	var label := Label.new()
	label.text = "Drag a control  •  Size"
	row.add_child(label)
	size_slider = HSlider.new()
	size_slider.min_value = 0.7
	size_slider.max_value = 1.5
	size_slider.step = 0.05
	size_slider.custom_minimum_size = Vector2(160, 40)
	size_slider.value_changed.connect(_resize_selected)
	row.add_child(size_slider)
	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_reset_layout)
	row.add_child(reset_button)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_layout)
	row.add_child(save_button)
	add_child(editor_bar)
	editor_bar.visible = false

func _load_layout() -> void:
	positions = _defaults()
	scales = {}
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for key in positions.keys():
		var point: Variant = config.get_value(mode, key + "_position", positions[key])
		var amount: Variant = config.get_value(mode, key + "_scale", 1.0)
		if point is Vector2 and is_finite(point.x) and is_finite(point.y):
			positions[key] = Vector2(clampf(point.x, 0, 1), clampf(point.y, 0, 1))
		if (amount is float or amount is int) and is_finite(float(amount)):
			scales[key] = clampf(float(amount), 0.7, 1.5)

func _apply_layout() -> void:
	if not is_instance_valid(joystick):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for key in positions:
		var control: Control = joystick if key == "Move" else buttons.get(key)
		if not is_instance_valid(control):
			continue
		var dimensions: Vector2 = base_sizes[key] * float(scales.get(key, 1.0))
		control.custom_minimum_size = dimensions
		control.size = dimensions
		var center: Vector2 = positions[key] * viewport_size
		center.x = clampf(center.x, dimensions.x / 2, viewport_size.x - dimensions.x / 2)
		center.y = clampf(center.y, dimensions.y / 2, viewport_size.y - dimensions.y / 2)
		control.position = center - dimensions / 2

func _start_edit() -> void:
	reset_input()
	edit_mode = true
	edit_button.visible = false
	editor_bar.visible = true
	if buttons.has("Interact"):
		buttons["Interact"].visible = true
	selected = "Move"
	size_slider.set_value_no_signal(float(scales.get(selected, 1.0)))

func _resize_selected(value: float) -> void:
	if edit_mode and not selected.is_empty():
		scales[selected] = value
		_apply_layout()

func _reset_layout() -> void:
	positions = _defaults()
	scales = {}
	size_slider.set_value_no_signal(1.0)
	_apply_layout()

func _save_layout() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	for key in positions:
		config.set_value(mode, key + "_position", positions[key])
		config.set_value(mode, key + "_scale", float(scales.get(key, 1.0)))
	var error := config.save(CONFIG_PATH)
	if error != OK:
		push_warning("Could not save touch layout: %s" % error)
		return
	edit_mode = false
	drag_finger = -1
	editor_bar.visible = false
	edit_button.visible = true
	set_story_interaction(interaction_label)

func _input(event: InputEvent) -> void:
	if not edit_mode:
		return
	if event is InputEventScreenTouch:
		if event.pressed and drag_finger == -1:
			for key in positions:
				var control: Control = joystick if key == "Move" else buttons.get(key)
				if is_instance_valid(control) and control.visible and control.get_global_rect().has_point(event.position):
					selected = key
					drag_finger = event.index
					drag_offset = event.position - (control.position + control.size / 2)
					size_slider.set_value_no_signal(float(scales.get(key, 1.0)))
					get_viewport().set_input_as_handled()
					break
		elif not event.pressed and event.index == drag_finger:
			drag_finger = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == drag_finger:
		var viewport_size := get_viewport().get_visible_rect().size
		var center: Vector2 = event.position - drag_offset
		positions[selected] = Vector2(clampf(center.x / viewport_size.x, 0, 1), clampf(center.y / viewport_size.y, 0, 1))
		_apply_layout()
		get_viewport().set_input_as_handled()

func set_story_interaction(label: String) -> void:
	interaction_label = label
	if mode == "story" and buttons.has("Interact"):
		buttons["Interact"].visible = edit_mode or not label.is_empty()
		buttons["Interact"].text = label if not label.is_empty() else "Interact"

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
	if edit_mode:
		return
	if action == "Sprint":
		sprinting = not sprinting
		buttons[action].text = "Run: ON" if sprinting else "Sprint"
	action_pressed.emit(action)

func _unhandled_input(event: InputEvent) -> void:
	if edit_mode:
		return
	if event is InputEventScreenTouch:
		if event.pressed and look_finger == -1 and event.position.x > get_viewport().get_visible_rect().size.x * 0.45:
			look_finger = event.index
		elif not event.pressed and event.index == look_finger:
			look_finger = -1
	elif event is InputEventScreenDrag and event.index == look_finger:
		look_dragged.emit(event.relative)
