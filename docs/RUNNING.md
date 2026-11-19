# Running the project

Open `project.godot` in Godot 4.3 or newer and press F5. The startup menu offers Host, Join, Solo arena, Disconnect and Quit.

## Solo training

Choose **Solo arena**. WASD moves, Shift sprints, Space jumps, C or Ctrl dodges, the mouse orbits, left click performs a light attack, right click a heavy attack, Q toggles lock-on, and Escape releases the cursor. Approach and face the dummy to hit it; its health resets at zero.

## Shared arena (work in progress)

Run two instances, choose names, and press **Host** in one. In the other enter `127.0.0.1` and press **Join**. For a different machine enter the host's reachable IP; the host must allow UDP port 7777 through its firewall/router. Both players should appear in a simple shared arena. WASD moves, Shift sprints, Space jumps, the mouse orbits, Enter opens chat, and Escape releases the cursor. The server validates input and simulates movement; transforms, health placeholder and animation-state labels are sent back to clients. Disconnecting a peer removes its player.

This is not yet the full multiplayer milestone: there is no synchronized animated model, MultiplayerSynchronizer, server-authoritative combat, dodge, inventory or save system in the network arena. The player health is currently a fixed placeholder. There is no authentication, encryption, prediction or lag compensation; use only with trusted players during development. The level is a test floor rather than Cinderfall Hollow.

## Dedicated server

Run from the project directory:

```
godot --headless --path . --server
```

The dedicated server listens on UDP 7777 without creating a local player. Clients select Join as above. Use Ctrl+C to stop it. The `-- --server` user-argument form also works.

## Tests

Run each server test and its matching client test in separate terminals, from the project directory, starting the client immediately after the server:

```
godot --headless --path . --script res://tests/network_smoke.gd -- server
godot --headless --path . --script res://tests/network_smoke.gd -- client

godot --headless --path . --script res://tests/arena_smoke.gd -- server
godot --headless --path . --script res://tests/arena_smoke.gd -- client
```

The first pair tests the roster and chat on UDP 18991; the second tests spawning and server-controlled movement on UDP 18992. A dedicated server connection can be tested by running `godot --headless --path . --server` and then `godot --headless --path . --script res://tests/dedicated_smoke.gd`.

The older first-person prototype remains available as `world.tscn`.
