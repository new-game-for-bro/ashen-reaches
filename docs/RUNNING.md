# Running the project

Open `project.godot` in Godot 4.3 or newer and press F5. The current entry scene is a local third-person training arena.

WASD moves, Shift sprints, Space jumps, C or Ctrl dodges, the mouse orbits, left click performs a light attack, right click a heavy attack, Q toggles lock-on, and Escape releases the cursor. Approach and face the dummy to hit it; its health resets at zero.

The older first-person prototype is still available by opening `world.tscn` and running that scene. Multiplayer, menus, saved progress, inventory, skills, quests, dungeon and dedicated server are not implemented in the new slice yet.

## Multiplayer lobby (in progress)

Open `scenes/ui/network_lobby.tscn` and press F6 to run it. Start two instances: choose different names, click Host in one and Join in the other using `127.0.0.1`, then send chat with Enter. For another machine, enter the host's reachable IP and make UDP port 7777 reachable. This is currently a connection and chat test only: players do not spawn or move together yet, and dedicated server mode is not implemented.

For an automated local test, start two terminals from the project directory:

```
godot --headless --path . --script res://tests/network_smoke.gd -- server
godot --headless --path . --script res://tests/network_smoke.gd -- client
```

The server test listens on UDP port 18991. Start the client soon after the server; both should report PASS.
