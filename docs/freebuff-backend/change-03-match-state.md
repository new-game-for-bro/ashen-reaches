# Change 03 — server-side match state

One script and one test file. A **reviewable draft**, not an integration: the game repository is still unreachable, so nothing here has been dropped into it, no scene references it, and no existing file was touched.

```
scripts/net/match_state.gd   # MatchState: round lifecycle, authoritative clock, eliminations, results
tests/match_state_test.gd    # 94 headless checks
```

## What it owns, and what it refuses to own

| It owns | It does not own |
|---|---|
| Who is in the round (`join`/`leave`, cap, lock during a round) | Transport, peers, RPCs |
| How much time is left (`tick(dt_ms)` decrements it) | Movement, health, damage, loot |
| Who is out, in what order (`eliminate` → placement) | Spawning (`MultiplayerSpawner` keeps that) |
| When the round starts, ends and resets | Bots, the BR ring, matchmaking |

Lifecycle: `waiting → countdown → active → resolving → (waiting | closed)`.

- `waiting` — roster open, no clock.
- `countdown` — roster locked; reaching zero starts the round. A zero-length countdown starts on the next tick.
- `active` — the round clock, the only authority on time. Ends on **last standing** or **time expired**.
- `resolving` — result frozen; after `resolve_ms` it either rolls into a fresh `waiting` round or `closed`.
- `closed` — terminal until `reset()`.

## Why it is deterministic

Time only moves through `tick(dt_ms)`. There is no wall clock, no `_process`, no autoload, no `Input`. A test and a dedicated server given the same call sequence produce the same placements. `_physics_process` exists but does nothing unless you call `enable_physics_tick(tick_ms)` — so a test can never depend on frame rate.

That matters more than it sounds: "the server owns the timer" is only true if the timer cannot be advanced by anything except the server's tick.

## Wire it in (server scene only, ~8 lines)

```gdscript
const MatchState = preload("res://scripts/net/match_state.gd")

var _match: MatchState

func _ready() -> void:
    if not NetworkManager.is_dedicated_server:
        return                          # clients and offline scenes never build this
    _match = MatchState.new()
    add_child(_match)
    _match.configure({"min_players": 2, "max_players": 16, "round_ms": 180_000})
    _match.round_finished.connect(_on_round_finished)
    _match.enable_physics_tick(50)      # or call tick() yourself from the server loop

func _on_round_finished(result: Dictionary) -> void:
    # result: {reason, round, winner_id, placements, duration_ms}
    rpc("round_result", result)
```

Feed it from the code you already have instead of adding new authority:

- after the ticket check admits a peer → `_match.join(player_id)`, and refuse the spawn if it is not `&"ok"`
- when a player's health reaches zero → `_match.eliminate(player_id)`
- on disconnect → `_match.leave(player_id)` (an active-round quit counts as a death, so nobody dodges a placement by pulling the cable)
- when everyone is in → `_match.begin_countdown()`
- every server tick → `tick()` (or enable the physics hook)
- when you need it for the HUD → `snapshot()`, which carries state, time left, alive ids and placements, and **no transform, health or damage**

## Verified

```
godot --headless --path . --script res://tests/match_state_test.gd
```

Run on a real Godot 4.3 headless binary in a scratch project containing only this script: `--- 94 checks, 0 failures`, exit 0.

Covered: initial state and inert ticks; join rules (duplicates, id 0, cap, roster lock); start refused below the minimum; countdown boundaries; the exact millisecond the round ends; placements assigned from the server's own alive count; last-standing and time-expired endings; quits counted as deaths; the resolve window and auto-restart; the closed state and `reset()`; simultaneous kills ordered deterministically by id; snapshot and result copies (mutating the returned dictionaries cannot reach server state); config clamping.

**Not verified:** that it compiles inside the game project, that its lifecycle matches what `network_arena.gd` and the BR scene actually need, or any integration with `NetworkManager`.

## Deliberate omissions

- **No reconnect.** A dropped player is out. Surviving a disconnect needs a seat reservation keyed by player id, which is a separate design decision.
- **No next-round carry-over.** The roster is cleared on restart, so a stale member cannot silently play the next round; everyone re-enters through the ticket gate. That is intentional, and it is the line to revisit first if you want persistent lobbies across rounds.
- **No bot seats.** Bots join as ordinary members when change 04 runs them server-side; the node does not know the difference.
- **No damage or death rules.** `eliminate()` is a command from the authority that already decided a player died, not a health check.
- **Resolving results are a snapshot, not a scoreboard.** Ratings, kills and placement history belong in whatever stores match records.
