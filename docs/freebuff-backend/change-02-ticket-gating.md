# Change 02 — ticket-gated joining for the existing ENet server

Two additive scripts and two test files. This does **not** replace `NetworkManager`, `MultiplayerSpawner`, the intent flow in `network_player.gd`, or the dedicated-server flag — all of that stays exactly as it is. It adds the one thing that path has no answer for today: *who* a connected peer is allowed to be.

```
scripts/net/match_ticket.gd   # HMAC-SHA256 ticket: issue, verify, TTL, server binding, replay cache
scripts/net/join_code.gd      # 8-char codes, no I/L/O/0/1, unbiased generation, normalisation
tests/match_ticket_test.gd
tests/join_code_test.gd
```

## Why this rather than more networking

The project already has transport, an authoritative ENet loop, validated intents, server-side movement and snapshots. The gaps left are rules and plumbing, not more netcode:

- The ENet server accepts any peer that reaches the port. With a dedicated flag and a 16-player cap, that is an open lobby to anyone on the network.
- Nothing binds a connection to a lobby, so matchmaking has nothing to hand out.
- Battle royale is a separate solo scene, so online BR does not exist yet.

## Hook it into the current flow (about 10 lines, no rewrites)

Server side, where `NetworkManager` currently accepts a peer:

```gdscript
const MatchTicket = preload("res://scripts/net/match_ticket.gd")

var _replay := MatchTicket.ReplayCache.new()

func _on_peer_connected(peer_id: int) -> void:
    # the ticket arrives in your existing connection handshake, before any spawn
    var claims := MatchTicket.verify(
        SESSION_SECRET,                          # from the environment, 32+ bytes
        _pending_tickets.get(peer_id, ""),
        Time.get_unix_time_from_system() * 1000,
        DEDICATED_SERVER_ID                      # rejects tickets for other servers
    )
    var now := Time.get_unix_time_from_system() * 1000
    if claims.is_empty() or not _replay.consume(claims["nonce"], now):
        multiplayer.multiplayer_peer.disconnect_peer(peer_id)
        return
    _admit(claims["player_id"])                  # existing spawn path, unchanged
```

The client sends the token it got from the lobby in the same message that already carries its join handshake. No change to intent framing, no change to snapshots.

## Verify

```bash
godot --headless --path . --script res://tests/match_ticket_test.gd
godot --headless --path . --script res://tests/join_code_test.gd
```

Both exit 0 on success and print a `--- N checks, 0 failures` summary (33 and 24).

## Read before exposing a port

See `docs/ticket-risks-on-enet.md`. The short version: over plain ENet the ticket is a bearer token, not an identity, and not a private channel. Fine for LAN; not yet safe on the open internet.

## Not covered here, on purpose

- **No lobby service yet.** Codes and tickets are the contract it will implement; it can be written in Go or as a tiny second Godot headless process once you pick a language.
- **No TLS.** The ticket only proves *authorisation*, not *confidentiality*.
- **No reconnect handling.** A dropped peer currently costs its ticket; reconnect needs a fresh one.
- **No integration test** against your real `NetworkManager`, which is still unread.
