extends SceneTree

## Headless checks for the authoritative input layer.
##
## Run from the project root:
##   godot --headless --path . --script res://tests/net_intents_test.gd
## Exit code 0 means every check passed, so this works in CI as-is.

const Intent = preload("res://scripts/net/input_intent.gd")
const Guard = preload("res://scripts/net/intent_guard.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_wire_round_trip()
	_test_sanitize_clamps()
	_test_decode_rejects_garbage()
	_test_sequence_policy()
	_test_rate_limit()
	_test_sample_time_policy()
	_test_action_cooldown()
	_test_speed_scale()
	print("--- %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(label: String, condition: bool) -> void:
	_checks += 1
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)


func make_intent(
	seq: int,
	move: Vector2 = Vector2.ZERO,
	look: Vector2 = Vector2.ZERO,
	actions: int = 0,
	sample_ms: int = 0
) -> RefCounted:
	return Intent.new(seq, move, look, actions, sample_ms)


func _test_wire_round_trip() -> void:
	var original := make_intent(7, Vector2(0.5, -0.5), Vector2(0.1, 0.0), Intent.ACTION_FIRE, 1234)
	var decoded = Guard.decode_wire(original.to_wire())
	check("wire round trip keeps seq", decoded != null and decoded.seq == 7)
	check("wire round trip keeps action", decoded != null and (decoded.actions & Intent.ACTION_FIRE) != 0)
	check("wire round trip keeps sample_ms", decoded != null and decoded.sample_ms == 1234)


func _test_sanitize_clamps() -> void:
	var wild := make_intent(1, Vector2(60.0, 0.0), Vector2(9.0, -9.0), 0x7FFFFFFF, 0)
	wild.sanitize()
	check("move clamped to unit length", is_equal_approx(wild.move.length(), Intent.MAX_MOVE_LENGTH))
	check("yaw clamped", is_equal_approx(wild.look.x, Intent.MAX_LOOK_YAW))
	check("pitch clamped", is_equal_approx(wild.look.y, -Intent.MAX_LOOK_PITCH))
	check("unknown action bits stripped", wild.actions == Intent.KNOWN_ACTIONS)

	var nan_move := make_intent(1, Vector2(NAN, INF), Vector2(NAN, 0.0), 0, 0)
	nan_move.sanitize()
	check("non-finite move zeroed", nan_move.move == Vector2.ZERO)
	check("non-finite look zeroed", nan_move.look.x == 0.0)

	var negative := make_intent(-5, Vector2.ZERO, Vector2.ZERO, 0, -20)
	negative.sanitize()
	check("negative seq clamped", negative.seq == 0)
	check("negative sample_ms clamped", negative.sample_ms == 0)


func _test_decode_rejects_garbage() -> void:
	check("string payload rejected", Guard.decode_wire("nope") == null)
	check("null payload rejected", Guard.decode_wire(null) == null)
	check("empty dictionary rejected", Guard.decode_wire({}) == null)
	check("wrong move type rejected",
		Guard.decode_wire({"s": 1, "m": "x", "l": Vector2.ZERO, "a": 0, "t": 0}) == null)
	check("missing look rejected",
		Guard.decode_wire({"s": 1, "m": Vector2.ZERO, "a": 0, "t": 0}) == null)
	check("non-numeric seq rejected",
		Guard.decode_wire({"s": "1", "m": Vector2.ZERO, "l": Vector2.ZERO, "a": 0, "t": 0}) == null)


func _test_sequence_policy() -> void:
	var guard = Guard.new(11, 60)
	check("first intent accepted",
		guard.accept(make_intent(0, Vector2.ZERO, Vector2.ZERO, 0, 0), 0) != null)
	check("next seq accepted",
		guard.accept(make_intent(1, Vector2.ZERO, Vector2.ZERO, 0, 16), 16) != null)
	check("duplicate seq dropped",
		guard.accept(make_intent(1, Vector2.ZERO, Vector2.ZERO, 0, 32), 32) == null)
	check("duplicate reason recorded", guard.last_reject_reason == &"duplicate_seq")
	check("rewound seq dropped",
		guard.accept(make_intent(0, Vector2.ZERO, Vector2.ZERO, 0, 48), 48) == null)
	check("rewound reason recorded", guard.last_reject_reason == &"stale_seq")
	check("rejections counted", guard.reject_count == 2)


func _test_rate_limit() -> void:
	var guard = Guard.new(12, 10)
	var accepted := 0
	for i in 20:
		if guard.accept(make_intent(i, Vector2.ZERO, Vector2.ZERO, 0, i), i) != null:
			accepted += 1
	check("budget honoured inside one second", accepted == 10)
	check("flood reason recorded", guard.last_reject_reason == &"rate_limited")
	check("budget refills in the next second",
		guard.accept(make_intent(20, Vector2.ZERO, Vector2.ZERO, 0, 1200), 1200) != null)


func _test_sample_time_policy() -> void:
	var guard = Guard.new(13)
	check("stale sample dropped",
		guard.accept(make_intent(1, Vector2.ZERO, Vector2.ZERO, 0, 5000), 7000) == null)
	check("stale reason recorded", guard.last_reject_reason == &"stale_sample")
	var ahead = guard.accept(make_intent(2, Vector2.ZERO, Vector2.ZERO, 0, 60000), 7000)
	check("future sample clamped to server clock", ahead != null and ahead.sample_ms == 7000)


func _test_action_cooldown() -> void:
	var guard = Guard.new(14)
	guard.set_action_cooldown(Intent.ACTION_FIRE, 600)
	var first = guard.accept(make_intent(1, Vector2.ZERO, Vector2.ZERO, Intent.ACTION_FIRE, 0), 0)
	check("first shot accepted", first != null and (first.actions & Intent.ACTION_FIRE) != 0)
	var early = guard.accept(make_intent(2, Vector2(0.5, 0.0), Vector2.ZERO, Intent.ACTION_FIRE, 100), 100)
	check("shot on cooldown stripped", early != null and (early.actions & Intent.ACTION_FIRE) == 0)
	check("movement survives a cooldown strip", early != null and early.move == Vector2(0.5, 0.0))
	var later = guard.accept(make_intent(3, Vector2.ZERO, Vector2.ZERO, Intent.ACTION_FIRE, 700), 700)
	check("shot after cooldown accepted", later != null and (later.actions & Intent.ACTION_FIRE) != 0)


func _test_speed_scale() -> void:
	var guard = Guard.new(15)
	var slowed = guard.accept(make_intent(1, Vector2(1, 0), Vector2.ZERO, 0, 0), 0, 0.35)
	check("speed scale clamps movement",
		slowed != null and is_equal_approx(slowed.move.length(), 0.35))
	var over = guard.accept(make_intent(2, Vector2(1, 0), Vector2.ZERO, 0, 16), 16, 4.0)
	check("speed scale cannot exceed the stick",
		over != null and over.move.length() <= Intent.MAX_MOVE_LENGTH + 0.0001)
