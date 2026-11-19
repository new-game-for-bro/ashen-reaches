extends RefCounted

static func configure() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "dodge": KEY_C, "interact": KEY_E, "inventory": KEY_I, "map": KEY_TAB, "chat": KEY_ENTER, "lock_target": KEY_Q, "skill_1": KEY_1, "skill_2": KEY_2, "skill_3": KEY_3, "skill_4": KEY_4, "skill_5": KEY_5, "skill_6": KEY_6}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	var ctrl := InputEventKey.new()
	ctrl.physical_keycode = KEY_CTRL
	if not InputMap.action_has_event("dodge", ctrl):
		InputMap.action_add_event("dodge", ctrl)
	for action: String in ["light_attack", "heavy_attack"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT if action == "light_attack" else MOUSE_BUTTON_RIGHT
			InputMap.action_add_event(action, mouse)
