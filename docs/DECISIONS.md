# Decisions

- The existing first-person prototype remains in `world.tscn`; the new training arena is the M1 entry point. Existing downloaded art and local editor settings are preserved.
- The renderer remains Compatibility while establishing the slice, as this machine has not yet been verified with Forward+. Renderer validation is still needed.
- Controls are registered by `scripts/player/input_setup.gd` at startup, keeping the existing project settings intact. Inventory, map, chat and skill bindings are reserved until their milestones.
- The first training dummy restores its health when depleted so training can continue. It is a local test target, not a network-authoritative enemy.
- Balance values are temporary M1 constants; moving them to JSON is still required before the combat milestone.
- Multiplayer work starts with an isolated test lobby and a server-relayed roster/chat. The listen server accepts up to 15 clients plus the host. This is not yet a shared world or dedicated-server implementation. Movement and combat must remain server-authoritative when added.
