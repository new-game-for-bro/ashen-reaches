# Animation contract

The player visual may contain an AnimationPlayer with these names:

`idle`, `walk`, `run`, `jump`, `fall`, `dodge`, `attack_light_1`, `attack_light_2`, `attack_light_3`, `attack_heavy`, `skill_cast`, `hit`, `death`, `interact`.

The controller checks for each animation before playing it, so the placeholder works without animation clips. Additional combat and interaction states will be connected as those systems are built.
