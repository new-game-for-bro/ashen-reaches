# Ashen Reaches

A playable first-person dark-fantasy prototype for Godot 4. Open `project.godot` and press F5.

## How to play

- **WASD** move, **mouse** look, **Shift** run.
- **Space** swings your sword at a nearby hollow in front of you. Hollows pursue and attack when close.
- Defeat at least one hollow, then approach each of the three dungeon gateways and press **E** to cleanse its seal. Cleansing restores some health; cleanse all three to win.
- If your health reaches zero you return to the haven. Progress remains for the current run.
- **M** opens the world map and pauses monster movement. **Esc** releases the cursor; click the world to recapture it.

This is a prototype using generated placeholder geometry. The dungeon gateways are interactive seals rather than explorable interiors; there is no save system or sound yet.

## Art and animation

The game uses the newer model collection for environment and character placeholders. The reaper serves as the current enemy and crypt statue; animation and game-ready optimization are still needed.

## Asset credits

See `models/ATTRIBUTION.md` for creators, source links, and licenses.

The `models` folder uses Git LFS. Install Git LFS and run `git lfs pull` after cloning to obtain the full model files. The `environment` folder contains models used by the current scene; `library` holds high-detail source models that Godot skips importing until selected and optimized. Credits and source links are in `models/ATTRIBUTION.md`.
