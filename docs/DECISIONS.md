# Decisions

- The existing first-person prototype remains in `world.tscn`; the new training arena is the M1 entry point. Existing downloaded art and local editor settings are preserved.
- The renderer remains Compatibility while establishing the slice, as this machine has not yet been verified with Forward+. Renderer validation is still needed.
- Controls are registered by `scripts/player/input_setup.gd` at startup, keeping the existing project settings intact. Inventory, map, chat and skill bindings are reserved until their milestones.
- The first training dummy restores its health when depleted so training can continue. It is a local test target, not a network-authoritative enemy.
- Balance values are temporary M1 constants; moving them to JSON is still required before the combat milestone.
- Multiplayer work starts with an isolated test lobby and a server-relayed roster/chat. The listen server accepts up to 15 clients plus the host. This is not yet a shared world or dedicated-server implementation. Movement and combat must remain server-authoritative when added.
- The shared test arena uses `MultiplayerSpawner` and server-simulated input, with validated and rate-limited client input and unreliable snapshots. Clients load the arena before connecting so the spawner exists before replicated players arrive. A full MultiplayerSynchronizer implementation, authority hardening and interpolation/prediction are still pending; this is not production-ready networking.
- Dedicated hosting currently uses the default UDP port 7777 and accepts 16 clients, while a listen server allows 15 clients plus its host.
