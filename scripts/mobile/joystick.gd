extends Control
signal vector_changed(value: Vector2)
const RADIUS: float = 70.0
var touch_id: int = -1
var value: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(180, 180)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_update_vector(event.position)
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			value = Vector2.ZERO
			vector_changed.emit(value)
			queue_redraw()
		accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_update_vector(event.position)
		accept_event()

func _update_vector(pos: Vector2) -> void:
	value = ((pos - size / 2.0) / (RADIUS * minf(size.x, size.y) / 180.0)).limit_length(1.0)
	if value.length() < 0.12:
		value = Vector2.ZERO
	vector_changed.emit(value)
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius := RADIUS * minf(size.x, size.y) / 180.0
	draw_circle(center, radius, Color(0.12, 0.15, 0.19, 0.6))
	draw_arc(center, radius, 0, TAU, 48, Color(0.8, 0.83, 0.86, 0.5), 2)
	draw_circle(center + value * radius, 27 * radius / RADIUS, Color(0.8, 0.83, 0.86, 0.7))

func reset() -> void:
	touch_id = -1
	value = Vector2.ZERO
	vector_changed.emit(value)
	queue_redraw()
