class_name MatchState
extends Node

## Server-side authority for one round of a multiplayer match.
##
## The host owns three things the client must never be able to fake:
##   * who is in the round (the roster),
##   * how much time is left (a countdown the server decrements itself), and
##   * who is out and in what order (placements).
##
## Clients only ever *read* this through snapshot(); they never send a timer, a
## placement or a "round over" message. Nothing in the existing intent flow is
## replaced: intents still arrive per player, movement is still simulated by the
## server, and this node decides when a round starts, ends and resets.
##
## Determinism: time only advances through tick(dt_ms). No wall clock, no
## Time.get_ticks_msec(), no _process polling by default — so the same call
## sequence produces the same result in a test and on a dedicated server. The
## optional _physics_process hook at the bottom is off unless you enable it.
##
## Additive by design: the prologue, solo arena and solo battle royale never
## instantiate this node, so offline modes cannot regress because of it.

signal state_changed(previous: StringName, current: StringName)
signal player_joined(player_id: int)
signal player_eliminated(player_id: int, placement: int)
signal round_finished(result: Dictionary)

const STATE_WAITING := &"waiting"       ## roster open, no timer
const STATE_COUNTDOWN := &"countdown"   ## roster locked, round starts when it hits zero
const STATE_ACTIVE := &"active"         ## round running, timer authoritative
const STATE_RESOLVING := &"resolving"   ## result frozen on screen, then restart or close
const STATE_CLOSED := &"closed"         ## terminal until reset()

const OK := &"ok"

## Defaults sized for the project's 16-player dedicated server.
const DEFAULT_MIN_PLAYERS := 2
const DEFAULT_MAX_PLAYERS := 16
const DEFAULT_COUNTDOWN_MS := 5_000
const DEFAULT_ROUND_MS := 180_000
const DEFAULT_RESOLVE_MS := 8_000
const MIN_ROUND_MS := 1_000

var min_players: int = DEFAULT_MIN_PLAYERS
var max_players: int = DEFAULT_MAX_PLAYERS
var countdown_ms: int = DEFAULT_COUNTDOWN_MS
var round_ms: int = DEFAULT_ROUND_MS
var resolve_ms: int = DEFAULT_RESOLVE_MS
## True: RESOLVING rolls into a fresh WAITING round. False: the match closes.
var auto_restart: bool = true

var _state: StringName = STATE_WAITING
var _time_left_ms: int = 0
var _round: int = 0
var _players: Dictionary = {}     ## player_id -> {"alive": bool, "placement": int}
var _result: Dictionary = {}      ## last finished round
var _ticked_state: StringName = &""


func _init() -> void:
	_state = STATE_WAITING


## Clamp the knobs into ranges that cannot produce a zero-length or impossible
## round. Safe to call at any time; the current timer is left alone.
func configure(p: Dictionary) -> void:
	min_players = maxi(2, int(p.get("min_players", min_players)))
	max_players = maxi(min_players, int(p.get("max_players", max_players)))
	countdown_ms = maxi(0, int(p.get("countdown_ms", countdown_ms)))
	round_ms = maxi(MIN_ROUND_MS, int(p.get("round_ms", round_ms)))
	resolve_ms = maxi(0, int(p.get("resolve_ms", resolve_ms)))
	auto_restart = bool(p.get("auto_restart", auto_restart))


# --- roster ---------------------------------------------------------------

## Admits a player. Refused unless the roster is open, so a peer that arrives
## mid-round cannot join the running simulation.
func join(player_id: int) -> StringName:
	if _state != STATE_WAITING:
		return &"not_waiting"
	if player_id <= 0:
		return &"invalid_id"
	if _players.has(player_id):
		return &"already_joined"
	if _players.size() >= max_players:
		return &"full"
	_players[player_id] = {"alive": true, "placement": 0}
	player_joined.emit(player_id)
	return OK


## Removes a player. During an active round a living player counts as eliminated
## (a quit is a death), so nobody can dodge a placement by disconnecting.
func leave(player_id: int) -> StringName:
	if not _players.has(player_id):
		return &"not_found"
	if _state == STATE_ACTIVE and bool(_players[player_id]["alive"]):
		eliminate(player_id)
	_players.erase(player_id)
	return OK


func begin_countdown() -> StringName:
	if _state != STATE_WAITING:
		return &"not_waiting"
	if _players.size() < min_players:
		return &"not_enough_players"
	_set_state(STATE_COUNTDOWN)
	_time_left_ms = countdown_ms
	# A zero countdown is legal: start the round on the next tick.
	if _time_left_ms == 0:
		_activate()
	return OK


## Marks a living player out. Placement is fixed here, from the server's own
## alive count, and never changes afterwards.
func eliminate(player_id: int) -> StringName:
	if _state != STATE_ACTIVE:
		return &"not_active"
	if not _players.has(player_id):
		return &"not_found"
	var entry: Dictionary = _players[player_id]
	if not bool(entry["alive"]):
		return &"already_eliminated"
	var placement := alive_count()
	entry["alive"] = false
	entry["placement"] = placement
	_players[player_id] = entry
	player_eliminated.emit(player_id, placement)
	if alive_count() <= 1:
		_finish(&"last_standing")
	return OK


func close() -> StringName:
	if _state == STATE_CLOSED:
		return &"already_closed"
	_set_state(STATE_CLOSED)
	_time_left_ms = 0
	return OK


## Reopens a closed match with an empty roster and no carried-over placements.
func reset() -> StringName:
	if _state != STATE_CLOSED:
		return &"not_closed"
	_players.clear()
	_result = {}
	_set_state(STATE_WAITING)
	_time_left_ms = 0
	return OK


# --- clock ----------------------------------------------------------------

## The only way time moves. Call once per server tick with the elapsed time.
## Negative or zero dt is ignored; a huge dt simply overshoots into the next
## state rather than being silently swallowed.
func tick(dt_ms: int) -> void:
	if dt_ms <= 0:
		return
	match _state:
		STATE_COUNTDOWN, STATE_ACTIVE, STATE_RESOLVING:
			_time_left_ms -= dt_ms
			if _time_left_ms > 0:
				return
			_time_left_ms = 0
			if _state == STATE_COUNTDOWN:
				_activate()
			elif _state == STATE_ACTIVE:
				_finish(&"time_expired")
			else:
				_after_resolve()
		_:
			pass


# --- read-only views ------------------------------------------------------

func state() -> StringName:
	return _state


func state_name() -> String:
	return String(_state)


func time_left_ms() -> int:
	return _time_left_ms


func round_index() -> int:
	return _round


func player_count() -> int:
	return _players.size()


func alive_count() -> int:
	var n := 0
	for id in _players:
		if bool(_players[id]["alive"]):
			n += 1
	return n


func has_player(player_id: int) -> bool:
	return _players.has(player_id)


func is_alive(player_id: int) -> bool:
	return _players.has(player_id) and bool(_players[player_id]["alive"])


func placement_of(player_id: int) -> int:
	if not _players.has(player_id):
		return 0
	return int(_players[player_id]["placement"])


## The last finished round: {reason, round, winner_id, placements, duration_ms}.
## Empty until a round has ended. Deliberately a copy.
func last_result() -> Dictionary:
	return _result.duplicate(true)


## What the server may replicate to clients for this match. It carries no
## transform, health or damage: those stay in the existing snapshot path.
func snapshot() -> Dictionary:
	var alive: Array[int] = []
	var placements: Dictionary = {}
	for id in _players:
		placements[id] = int(_players[id]["placement"])
		if bool(_players[id]["alive"]):
			alive.append(id)
	alive.sort()
	return {
		"state": String(_state),
		"time_left_ms": _time_left_ms,
		"round": _round,
		"players": _players.size(),
		"alive": alive,
		"placements": placements,
	}


# --- internals ------------------------------------------------------------

func _activate() -> void:
	_set_state(STATE_ACTIVE)
	_time_left_ms = round_ms


func _finish(reason: StringName) -> void:
	var survivors: Array[int] = []
	for id in _players:
		if bool(_players[id]["alive"]):
			survivors.append(id)
	# Simultaneous kills are ordered by id, so a replay of the same events
	# always produces the same placements.
	survivors.sort()
	for i in survivors.size():
		var entry: Dictionary = _players[survivors[i]]
		entry["placement"] = i + 1
		_players[survivors[i]] = entry
	var placements: Dictionary = {}
	for id in _players:
		placements[id] = int(_players[id]["placement"])
	_result = {
		"reason": String(reason),
		"round": _round,
		"winner_id": survivors[0] if survivors.size() > 0 else 0,
		"placements": placements,
		"duration_ms": maxi(0, round_ms - _time_left_ms),
	}
	_set_state(STATE_RESOLVING)
	_time_left_ms = resolve_ms
	round_finished.emit(last_result())
	if _time_left_ms == 0:
		_after_resolve()


func _after_resolve() -> void:
	if auto_restart:
		# A new round needs fresh admissions: the roster is cleared so stale
		# members from the finished round cannot silently play the next one.
		_players.clear()
		_round += 1
		_set_state(STATE_WAITING)
		_time_left_ms = 0
	else:
		close()


func _set_state(next: StringName) -> void:
	if _state == next:
		return
	var previous := _state
	_state = next
	state_changed.emit(previous, next)


# --- optional SceneTree integration ---------------------------------------
#
# Left disabled on purpose: the caller decides the tick rate, and tests must
# not depend on wall-clock frames. Enable it by calling enable_physics_tick().
var _physics_tick_enabled := false
var _accumulator_ms := 0
var physics_tick_ms: int = 50


func enable_physics_tick(tick_ms: int = 50) -> void:
	physics_tick_ms = maxi(1, tick_ms)
	_physics_tick_enabled = true


func _physics_process(delta: float) -> void:
	if not _physics_tick_enabled:
		return
	_accumulator_ms += int(round(delta * 1000.0))
	while _accumulator_ms >= physics_tick_ms:
		_accumulator_ms -= physics_tick_ms
		tick(physics_tick_ms)
