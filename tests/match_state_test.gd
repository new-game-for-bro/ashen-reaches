extends SceneTree

## Headless checks for MatchState. Run from the project root:
##   godot --headless --path . --script res://tests/match_state_test.gd
##
## No SceneTree attachment and no wall clock: every check drives the node with
## explicit tick() calls, which is exactly how the dedicated server will.

const Match = preload("res://scripts/net/match_state.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_initial_state()
	_test_join_rules()
	_test_start_requires_players()
	_test_countdown()
	_test_eliminations()
	_test_last_standing()
	_test_time_expiry()
	_test_leaving_counts_as_death()
	_test_resolve_and_restart()
	_test_closed_match()
	_test_simultaneous_kills_are_deterministic()
	_test_snapshot_and_result_copy()
	_test_config_clamps()
	print("--- %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(label: String, condition: bool) -> void:
	_checks += 1
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)


func _test_initial_state() -> void:
	var m := Match.new()
	check("starts waiting", m.state() == Match.STATE_WAITING)
	check("no players", m.player_count() == 0)
	check("no time on the clock", m.time_left_ms() == 0)
	check("no result yet", m.last_result().is_empty())
	check("tick while waiting is inert", _tick(m, 5_000) and m.state() == Match.STATE_WAITING)
	m.free()


func _test_join_rules() -> void:
	var m := Match.new()
	m.configure({"max_players": 3})
	check("join accepted", m.join(1) == Match.OK)
	check("duplicate join refused", m.join(1) == &"already_joined")
	check("id zero refused", m.join(0) == &"invalid_id")
	check("negative id refused", m.join(-4) == &"invalid_id")
	check("second player accepted", m.join(2) == Match.OK)
	check("third player accepted", m.join(3) == Match.OK)
	check("past the cap refused", m.join(4) == &"full")
	check("count reflects admissions", m.player_count() == 3)
	check("joined player is alive", m.is_alive(1))
	check("unknown player is not alive", not m.is_alive(99))
	check("unknown player has no placement", m.placement_of(99) == 0)
	m.free()


func _test_start_requires_players() -> void:
	var m := Match.new()
	check("cannot start empty", m.begin_countdown() == &"not_enough_players")
	m.join(1)
	check("cannot start alone", m.begin_countdown() == &"not_enough_players")
	check("still waiting after refusal", m.state() == Match.STATE_WAITING)
	m.free()


func _test_countdown() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 3_000, "round_ms": 60_000})
	m.join(1)
	m.join(2)
	check("countdown starts", m.begin_countdown() == Match.OK)
	check("state is countdown", m.state() == Match.STATE_COUNTDOWN)
	check("countdown timer set", m.time_left_ms() == 3_000)
	check("roster locked during countdown", m.join(3) == &"not_waiting")
	check("countdown ticks down", _tick(m, 1_000) and m.time_left_ms() == 2_000)
	check("still counting", m.state() == Match.STATE_COUNTDOWN)
	check("double start refused", m.begin_countdown() == &"not_waiting")
	check("round begins at zero", _tick(m, 2_000) and m.state() == Match.STATE_ACTIVE)
	check("active timer is the round length", m.time_left_ms() == 60_000)
	check("roster still locked while active", m.join(3) == &"not_waiting")
	m.free()


func _test_eliminations() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 0, "round_ms": 60_000})
	for id in [1, 2, 3, 4]:
		m.join(id)
	m.begin_countdown()
	check("zero countdown starts immediately", m.state() == Match.STATE_ACTIVE)
	check("all four alive", m.alive_count() == 4)
	check("elimination closes out first place", m.eliminate(1) == Match.OK)
	check("first out takes last place", m.placement_of(1) == 4)
	check("alive count fell", m.alive_count() == 3)
	check("eliminated player is not alive", not m.is_alive(1))
	check("double elimination refused", m.eliminate(1) == &"already_eliminated")
	check("unknown player cannot be eliminated", m.eliminate(77) == &"not_found")
	check("second out takes third", m.eliminate(2) == Match.OK and m.placement_of(2) == 3)
	check("round still running", m.state() == Match.STATE_ACTIVE)
	check("no placement while alive", m.placement_of(3) == 0)
	m.free()


func _test_last_standing() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 0, "round_ms": 60_000, "resolve_ms": 4_000})
	for id in [1, 2, 3]:
		m.join(id)
	m.begin_countdown()
	m.tick(30_000)
	m.eliminate(3)
	m.eliminate(2)
	check("round ends on the last survivor", m.state() == Match.STATE_RESOLVING)
	var r := m.last_result()
	check("reason is last standing", r.get("reason", "") == "last_standing")
	check("winner is the survivor", int(r.get("winner_id", 0)) == 1)
	check("winner is placed first", int(r["placements"][1]) == 1)
	check("runner up is second", int(r["placements"][2]) == 2)
	check("eliminated players are not resurrected", m.alive_count() == 1)
	check("elapsed duration is recorded", int(r.get("duration_ms", 0)) == 30_000)
	check("resolving timer is set", m.time_left_ms() == 4_000)
	check("no eliminations after the round", m.eliminate(1) == &"not_active")
	m.free()


func _test_time_expiry() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 0, "round_ms": 10_000, "resolve_ms": 2_000})
	m.join(1)
	m.join(2)
	m.begin_countdown()
	_tick(m, 9_999)
	check("round survives until the deadline", m.state() == Match.STATE_ACTIVE)
	_tick(m, 1)
	check("round ends when the timer runs out", m.state() == Match.STATE_RESOLVING)
	var r := m.last_result()
	check("reason is time expiry", r.get("reason", "") == "time_expired")
	check("full round length recorded", int(r.get("duration_ms", -1)) == 10_000)
	check("both survivors placed", int(r["placements"][1]) == 1 and int(r["placements"][2]) == 2)
	check("winner is the lower id", int(r.get("winner_id", 0)) == 1)
	check("servers do not overrun the clock", m.time_left_ms() == 2_000)
	m.free()


func _test_leaving_counts_as_death() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 0, "round_ms": 60_000})
	m.join(1)
	m.join(2)
	check("leaving while waiting is clean", m.leave(2) == Match.OK and m.player_count() == 1)
	check("leaving twice refused", m.leave(2) == &"not_found")
	m.join(2)
	m.begin_countdown()
	check("leaving an active round", m.leave(2) == Match.OK)
	check("quitter is gone from the roster", not m.has_player(2))
	check("quit ends the round for the last player", m.state() == Match.STATE_RESOLVING)
	check("survivor wins", int(m.last_result().get("winner_id", 0)) == 1)
	m.free()


func _test_resolve_and_restart() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 0, "round_ms": 60_000, "resolve_ms": 2_000})
	m.join(1)
	m.join(2)
	m.begin_countdown()
	m.eliminate(2)
	check("round finished", m.state() == Match.STATE_RESOLVING)
	check("joins refused while resolving", m.join(5) == &"not_waiting")
	_tick(m, 1_999)
	check("still showing results", m.state() == Match.STATE_RESOLVING)
	_tick(m, 1)
	check("auto restart returns to waiting", m.state() == Match.STATE_WAITING)
	check("roster cleared for the next round", m.player_count() == 0)
	check("round counter advanced", m.round_index() == 1)
	check("previous result is retained", m.last_result().get("reason", "") == "last_standing")
	check("fresh admissions accepted", m.join(7) == Match.OK)
	check("new player starts alive", m.is_alive(7) and m.placement_of(7) == 0)
	check("clock is reset", m.time_left_ms() == 0)
	m.free()


func _test_closed_match() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 0, "round_ms": 5_000, "resolve_ms": 0, "auto_restart": false})
	m.join(1)
	m.join(2)
	m.begin_countdown()
	_tick(m, 5_000)
	check("no resolve window closes the match", m.state() == Match.STATE_CLOSED)
	check("closed match refuses joins", m.join(3) == &"not_waiting")
	check("closed match ignores ticks", _tick(m, 60_000) and m.state() == Match.STATE_CLOSED)
	check("closing twice refused", m.close() == &"already_closed")
	var fresh := Match.new()
	check("reset refused unless closed", fresh.reset() == &"not_closed")
	fresh.free()
	check("reset reopens the match", reset_reopens(m))
	m.free()


func reset_reopens(m) -> bool:
	var reopened: bool = m.reset() == Match.OK and m.state() == Match.STATE_WAITING
	reopened = reopened and m.player_count() == 0 and m.last_result().is_empty()
	return reopened


func _test_simultaneous_kills_are_deterministic() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 0, "round_ms": 60_000})
	for id in [4, 2, 1, 3]:
		m.join(id)
	m.begin_countdown()
	# Same server tick, server-ordered: the order of calls decides placement,
	# which is why the host must never take it from a client message.
	m.eliminate(4)
	m.eliminate(2)
	check("first call takes last place", m.placement_of(4) == 4)
	check("second call takes next place", m.placement_of(2) == 3)
	check("survivors keep zero placement until the finish", m.placement_of(1) == 0)
	m.eliminate(3)
	var placements: Dictionary = m.last_result()["placements"]
	check("survivor order is by id, not join order", int(placements[1]) == 1 and int(placements[3]) == 2)
	m.free()


func _test_snapshot_and_result_copy() -> void:
	var m := Match.new()
	m.configure({"countdown_ms": 0, "round_ms": 60_000})
	m.join(5)
	m.join(2)
	m.join(9)
	m.begin_countdown()
	m.eliminate(9)
	var s := m.snapshot()
	check("snapshot names the state", s.get("state", "") == "active")
	check("snapshot counts players", int(s.get("players", 0)) == 3)
	check("snapshot lists the living", s.get("alive", []) == [2, 5])
	check("snapshot has no transform", not s.has("position") and not s.has("transform"))
	check("snapshot carries placements", int(s["placements"][9]) == 3)
	s["alive"].append(99)
	check("snapshot is a copy", m.snapshot().get("alive", []).size() == 2)
	var r := m.last_result()
	check("no result mid-round", r.is_empty())
	m.eliminate(2)
	var finished := m.last_result()
	finished["placements"][5] = 99
	check("result is a deep copy", int(m.last_result()["placements"][5]) == 1)
	m.free()


func _test_config_clamps() -> void:
	var m := Match.new()
	m.configure({"min_players": 1, "max_players": 1, "round_ms": 0, "countdown_ms": -500})
	check("min players cannot drop below two", m.min_players == 2)
	check("max players cannot sit below min", m.max_players >= m.min_players)
	check("round length has a floor", m.round_ms >= Match.MIN_ROUND_MS)
	check("negative countdown clamped", m.countdown_ms == 0)
	m.free()


func _tick(m, dt: int) -> bool:
	m.tick(dt)
	return true
