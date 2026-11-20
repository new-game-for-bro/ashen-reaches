extends SceneTree
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var Controls = load("res://scripts/mobile/touch_controls.gd")
	var pad = Controls.new()
	pad.mode = "story"
	root.add_child(pad)
	await process_frame
	pad._start_edit()
	var attack: Control = pad.buttons["Attack"]
	var start: Vector2 = attack.position + attack.size / 2
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 7
	touch.position = start
	pad._input(touch)
	assert(pad.selected == "Attack")
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = start + Vector2(-160, -70)
	pad._input(drag)
	pad._resize_selected(1.25)
	var saved: Vector2 = pad.positions["Attack"]
	touch.pressed = false
	pad._input(touch)
	pad._save_layout()
	assert(not pad.edit_mode)
	var restored = Controls.new()
	restored.mode = "story"
	root.add_child(restored)
	await process_frame
	assert(restored.positions["Attack"].distance_to(saved) < 0.001)
	assert(is_equal_approx(restored.scales["Attack"], 1.25))
	restored._start_edit()
	restored._reset_layout()
	assert(restored.positions["Attack"] == restored._defaults()["Attack"])
	restored._save_layout()
	print("PASS: drag, resize, save, reload and reset mobile layout")
	quit()
