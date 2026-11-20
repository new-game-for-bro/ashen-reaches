class_name NetIntentGuard
extends RefCounted

## Server-side gatekeeper for one connected player's input stream.
##
## Everything here is policy the *host* owns: how fast a client may send, how
## stale or how far ahead a sample may be, which buttons are on cooldown, and how
## much of the stick actually moves the body. The client is never asked and never
## trusted.
##
## No SceneTree, no peer, no autoloads — so it unit-tests headlessly and is dead
## weight no offline build ever constructs.

const Intent = preload("res://scripts/net/input_intent.gd")

const MAX_INTENTS_PER_SECOND := 60   ## 3x a 20 Hz server tick, generous but bounded
const MAX_FUTURE_SKEW_MS := 250      ## tolerate phone clock drift, never trust it
const MAX_STALE_MS := 1000           ## older than this and the sample is meaningless
const SEQ_RESYNC_GAP := 4096         ## jumped this far: treat as a new stream
const NO_PREVIOUS_ACTION := -1073741824

var peer_id: int = 0
var intent_budget_per_second: int = MAX_INTENTS_PER_SECOND
var reject_count: int = 0
var last_reject_reason: StringName = &""

var _last_seq: int = -1
var _window_start_ms: int = 0
var _window_count: int = 0
var _action_last_ms: Dictionary = {}
var _action_cooldown_ms: Dictionary = {}


func _init(p_peer_id: int = 0, p_intent_budget_per_second: int = MAX_INTENTS_PER_SECOND) -> void:
	peer_id = p_peer_id
	intent_budget_per_second = maxi(1, p_intent_budget_per_second)


## Fire rate, dodge recovery and the like come from server-side gameplay data,
## never from the client's claim about what it did.
func set_action_cooldown(action_bit: int, cooldown_ms: int) -> void:
	_action_cooldown_ms[action_bit] = maxi(0, cooldown_ms)


## Turns an untrusted wire payload into a sanitised intent, or null if the
## payload is not a well-formed intent at all.
static func decode_wire(data: Variant) -> Intent:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var payload: Dictionary = data
	if not payload.has("m") or not payload.has("l"):
		return null
	if typeof(payload["m"]) != TYPE_VECTOR2 or typeof(payload["l"]) != TYPE_VECTOR2:
		return null
	var raw_seq: Variant = payload.get("s", 0)
	var raw_actions: Variant = payload.get("a", 0)
	var raw_time: Variant = payload.get("t", 0)
	if not _is_finite_number(raw_seq) or not _is_finite_number(raw_actions) or not _is_finite_number(raw_time):
		return null
	var intent: Intent = Intent.new(int(raw_seq), payload["m"], payload["l"], int(raw_actions), int(raw_time))
	intent.sanitize()
	return intent


## Returns the intent the server should simulate, or null if this sample must be
## dropped. The returned object is sanitised for this tick; never the raw payload.
func accept(intent: Intent, now_ms: int, speed_scale: float = 1.0) -> Intent:
	if intent == null:
		return _reject(&"null")
	if intent.seq == _last_seq:
		return _reject(&"duplicate_seq")
	if intent.seq < _last_seq:
		return _reject(&"stale_seq")
	if _last_seq >= 0 and intent.seq - _last_seq > SEQ_RESYNC_GAP:
		_action_last_ms.clear()   # long silence: forget cooldowns, keep sequence monotonic
	if not _within_rate(now_ms):
		return _reject(&"rate_limited")
	if intent.sample_ms > now_ms + MAX_FUTURE_SKEW_MS:
		intent.sample_ms = now_ms            # clock ahead of us: use ours
	elif now_ms - intent.sample_ms > MAX_STALE_MS:
		return _reject(&"stale_sample")
	var speed_cap := clampf(speed_scale, 0.0, 1.0)
	intent.move = intent.move.limit_length(Intent.MAX_MOVE_LENGTH * speed_cap)
	intent.actions = _filter_cooldowns(intent.actions, now_ms)
	_last_seq = intent.seq
	return intent


func _within_rate(now_ms: int) -> bool:
	if _window_count == 0 or now_ms - _window_start_ms >= 1000:
		_window_start_ms = now_ms
		_window_count = 0
	_window_count += 1
	return _window_count <= intent_budget_per_second


func _filter_cooldowns(actions: int, now_ms: int) -> int:
	var kept := 0
	var bit := 1
	while bit <= Intent.KNOWN_ACTIONS:
		if actions & bit != 0:
			var cooldown: int = _action_cooldown_ms.get(bit, 0)
			var last: int = _action_last_ms.get(bit, NO_PREVIOUS_ACTION)
			if cooldown <= 0 or now_ms - last >= cooldown:
				kept |= bit
				_action_last_ms[bit] = now_ms
		bit <<= 1
	return kept


func _reject(reason: StringName) -> Intent:
	reject_count += 1
	last_reject_reason = reason
	return null


static func _is_finite_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value)
	return false
