class_name NetInputIntent
extends RefCounted

## A single sample of what an online player *intends* to do.
##
## This is the entire input contract between client and server. It deliberately
## cannot express an outcome: no transform, no health, no damage, no hit target.
## A dishonest client therefore has nothing to assert — it can only ask, and the
## server decides what actually happens.
##
## Additive by design: nothing here touches Input, the SceneTree, autoloads or a
## multiplayer peer, so the prologue, solo arena and solo battle royale never
## load it and cannot regress because of it.

const ACTION_FIRE := 1 << 0
const ACTION_JUMP := 1 << 1
const ACTION_INTERACT := 1 << 2
const ACTION_DODGE := 1 << 3
const ACTION_RELOAD := 1 << 4
const KNOWN_ACTIONS := ACTION_FIRE | ACTION_JUMP | ACTION_INTERACT | ACTION_DODGE | ACTION_RELOAD

## Per-sample ceilings. The server never simulates a value outside these.
const MAX_MOVE_LENGTH := 1.0      ## unit stick, diagonals included
const MAX_LOOK_YAW := 0.35        ## radians of yaw per sample
const MAX_LOOK_PITCH := 0.25      ## radians of pitch per sample
const MAX_SEQ := 0x7FFFFFFF

var seq: int = 0
var move: Vector2 = Vector2.ZERO    ## x = strafe, y = forward
var look: Vector2 = Vector2.ZERO    ## x = yaw delta, y = pitch delta, radians
var actions: int = 0                    ## bitmask of ACTION_*
var sample_ms: int = 0              ## client clock at sample time


func _init(
	p_seq: int = 0,
	p_move: Vector2 = Vector2.ZERO,
	p_look: Vector2 = Vector2.ZERO,
	p_actions: int = 0,
	p_sample_ms: int = 0
) -> void:
	seq = p_seq
	move = p_move
	look = p_look
	actions = p_actions
	sample_ms = p_sample_ms


func to_wire() -> Dictionary:
	return {"s": seq, "m": move, "l": look, "a": actions, "t": sample_ms}


## Clamps a decoded intent into the only range the server will simulate.
## Call this on every payload that came off the network, before simulating.
func sanitize() -> void:
	if not (is_finite(move.x) and is_finite(move.y)):
		move = Vector2.ZERO
	if not (is_finite(look.x) and is_finite(look.y)):
		look = Vector2.ZERO
	move = move.limit_length(MAX_MOVE_LENGTH)
	look = Vector2(
		clampf(look.x, -MAX_LOOK_YAW, MAX_LOOK_YAW),
		clampf(look.y, -MAX_LOOK_PITCH, MAX_LOOK_PITCH)
	)
	actions = actions & KNOWN_ACTIONS
	seq = clampi(seq, 0, MAX_SEQ)
	sample_ms = maxi(sample_ms, 0)
