extends SceneTree
const Catalog = preload("res://scripts/characters/character_catalog.gd")
func _initialize() -> void:
	assert(Catalog.CHARACTER_COUNT == 4)
	assert(not Catalog.is_available(-1))
	assert(not Catalog.is_available(5))
	assert(not Catalog.select(5))
	assert(Catalog.select(0))
	assert(Catalog.selected_id() == 0)
	print("PASS: character choice validation and default")
	quit()
