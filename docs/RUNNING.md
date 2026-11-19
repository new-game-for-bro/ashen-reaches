# Running the project

The intended target is mobile. The Android prototype uses landscape touch controls; desktop keyboard and mouse controls remain available. Android device testing, mobile performance tuning and iOS export are still outstanding.

Open `project.godot` in Godot 4.3 or newer and press F5. The startup menu offers Story prologue, Solo arena, Battle Royale, Host, Join, Disconnect and Quit.

## Android prototype

On an Android device, use the left joystick to move and drag an unused area on the right to orbit the camera, including while moving. In the story, Attack and Dodge are on the lower right, and a contextual interaction button appears when you are near the gate or platform. Dodge follows the joystick direction, or moves backward if centered. Exit at the upper left opens the in-world logout menu and lights up after shutdown. Pause at the upper right stops the story and provides camera sensitivity and vertical-look settings for the current session. The action buttons vary by mode. Sprint is a toggle. In Battle Royale, Retry starts a new match after it ends; Menu returns to the mode selector. The online test has jump, sprint, chat and menu controls, but no networked combat yet.

The Android export preset builds a debug APK with a development signing key. Install the official Godot export templates matching your Godot version, an Android SDK with platform-tools and build-tools, and a compatible JDK; configure their paths and a debug keystore in Godot Editor Settings, then use Project > Export > Android > Export Project. The debug APK is not a release build. A phone has not yet been used to verify layout, performance, networking, installation or input. The preset exports only selected scenes and scripts, plus the story JSON, so unrelated local models are not packaged.

## Story prologue

Choose **Story prologue** to play *The Last Logout*. Move with WASD, orbit with the mouse, sprint with Shift, attack with Space or left click, dodge with C, and interact with E. Follow the on-screen objectives to the gate and the train. When the shutdown ends, open Exit, then continue toward the gate. Escape releases the cursor; P returns to the menu. The story currently uses placeholder shapes and scripted characters. It is single-player and has no save system yet.

The Unwritten Sky prologue and the Ashen Reaches multiplayer test now share one project and menu. Their different settings and characters have not yet been reconciled into a single continuous narrative; shared character progression and co-op story play are not implemented.

## Solo training

Choose **Solo arena**. WASD moves, Shift sprints, Space jumps, C or Ctrl dodges, the mouse orbits, left click performs a light attack, right click a heavy attack, Q toggles lock-on, and Escape releases the cursor. Approach and face the dummy to hit it; its health resets at zero.

## Battle Royale

Choose **Battle Royale** for a single-player last-survivor match against six bots. Stay inside the glowing ring as it shrinks; being outside damages you. Rivals attack each other and you. WASD moves, mouse orbits, Shift sprints, Space jumps, C dodges, left and right mouse buttons attack, and Q locks onto a rival. Press P to return to the menu; after a match, R starts another.

This is a solo prototype with placeholder art and simple bot behavior. Online battle royale, loot, equipment, matchmaking and persistent rewards are not implemented.

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

Run `godot --headless --path . --script res://tests/royale_smoke.gd` to test the battle royale rules.

Run `godot --headless --path . --script res://tests/mobile_controls_smoke.gd` to exercise the touch control signals and story, battle royale and network action wiring without a phone.
