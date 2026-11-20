# Ashen Reaches — multiplayer drafts

Reviewable drafts for the game's networking, written while `new-game-for-bro/ashen-reaches` was unreachable (the organization blocks third-party apps, so every request returns 403). Nothing here is integrated into the game, no scene references it, and no existing file was modified.

Each change is additive, self-contained and tested on a real Godot 4.3 headless binary.

| Change | Files | What it is | Status |
|---|---|---|---|
| 01 | `scripts/net/input_intent.gd`, `scripts/net/intent_guard.gd` | Input contract: the client can only ask, never assert | Superseded in part — your `network_player.gd` already validates intents; use it as a diff checklist |
| 02 | `scripts/net/match_ticket.gd`, `scripts/net/join_code.gd` | Ticket-gated joining and 8-character lobby codes | Ready to review; read the transport risks first |
| 03 | `scripts/net/match_state.gd` | Server-side round lifecycle, authoritative timer, eliminations | Ready to review; not yet wired into any scene |

## Layout

The paths mirror the game project, so the files can be copied in unchanged:

```
scripts/net/*.gd    # drop into the project as-is
 tests/*.gd         # headless suites, run from the project root
docs/*.md           # one note per change, plus the ENet ticket risk review
```

`class_name` already makes the classes global; there is no autoload and no `project.godot` edit.

## Verify

```bash
godot --headless --path . --script res://tests/net_intents_test.gd
godot --headless --path . --script res://tests/match_ticket_test.gd
godot --headless --path . --script res://tests/join_code_test.gd
godot --headless --path . --script res://tests/match_state_test.gd
echo "exit=$?"
```

Each suite prints `--- N checks, 0 failures` and exits 0. Expected totals: 36, 33, 24, 94.

## Read this before exposing a port

`docs/ticket-risks-on-enet.md` explains why the ticket gate is fine for LAN testing and not yet safe on the open internet: the token travels unencrypted, it is a bearer token rather than proof of possession, and the signing secret is shared across servers.

## Not done yet

- Bots on the server (the six solo BR bots are still client-scene code).
- Battle royale as a server scene.
- The lobby service (language still undecided).
- Any integration with `NetworkManager`, `MultiplayerSpawner` or `network_arena.gd` — all of that is unread.
