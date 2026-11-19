# Asset guide

Godot uses one unit per metre. The player is about 1.8 metres tall and the visual origin is at the feet. Use glTF/GLB and orient the character so its forward direction is local +Z. Keep physics collision separate from the visual.

Open `scenes/characters/player.tscn`. The `Visual` node owns the character's `AnimationPlayer`. To replace the temporary body, remove or disable the `_add_placeholder()` call in `scripts/player/third_person.gd`, add your imported model under `Visual`, and place or retarget its animations to `Visual/AnimationPlayer` using the names in `ANIMATION_CONTRACT.md`. Keep `CollisionShape3D`, `CameraPivot` and the root unchanged. The imported model's pivot should be at its feet, and its material and texture licenses must permit your intended use.

The training dummy is `scenes/enemies/training_dummy.tscn`; replace the mesh beneath `Visual` while retaining its collision and script.
