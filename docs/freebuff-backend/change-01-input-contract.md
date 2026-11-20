# Change 01 — authoritative input contract

> **Superseded in part (v0.2 of the plan).** The project's `network_player.gd` already sends validated intents to an authoritative server, so most of this is likely a duplicate. Treat it as a **diff checklist, not a patch**: compare each rule below against the existing validator and keep only what is genuinely missing. If yours already does sequence checks and stick clamping, discard this entirely.

Three files, all additive. Nothing in the prologue, solo arena or solo battle royale imports them, so offline play cannot change behaviour because of this patch.

```
scripts/net/input_intent.gd    # what a player intends: stick, look delta, buttons
scripts/net/intent_guard.gd    # server-side gatekeeper: decode, rate, sequence, staleness, cooldowns
tests/net_intents_test.gd      # 36 headless checks
```

## Why this was written first

Every later phase depends on one property: **the client cannot assert an outcome.** A controller that reads `Input` inside `_physics_process` and moves the body locally is fine offline and unusable for authoritative play. This layer fixes the contract first — a payload that can only *ask* — so the player refactor becomes mechanical (feed an intent instead of reading `Input`) rather than a redesign.

## What it enforces

| Risk | Defence |
|---|---|
| Speed hacks / teleporting | `move` clamped to a unit stick, further scaled by the server's `speed_scale` |
| Snapshot/aimbot-style look snapping | look delta clamped per sample |
| Fire-rate hacks | `set_action_cooldown` is server configuration, not a client claim |
| Packet flooding | sliding one-second budget per peer, default 60/s |
| Replay / duplicate inputs | strictly increasing `seq`, duplicates and rewinds dropped |
| Delayed-input abuse, clock lies | samples older than 1s dropped, samples from the future clamped to server time |
| Malformed or malicious payloads | strict type checks; anything off-shape returns `null` |

## Install

Copy the three paths into the project unchanged. `class_name` already makes both classes globally available; no autoload, no `project.godot` edit.

## Run the tests

```bash
godot --headless --path . --script res://tests/net_intents_test.gd
echo "exit=$?"
```

Exit code 0 means all checks passed. Expected output ends with `--- 36 checks, 0 failures`.

The suite has no scene, no autoload and no peer, so it runs on a plain headless editor binary — useful for CI before any server exists.

## Next step (not in this change)

Wire a `RemoteInputProvider` behind the input seam and have the server apply `guard.accept(...)` results to the authoritative `CharacterBody3D`. That step touches `network_player.gd` and the player controller, so it needs the audit first — or a decision that the existing validator already covers it.
