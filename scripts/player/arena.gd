extends Node3D

const WorldModels = preload("res://scripts/world/model_environment.gd")

func _ready() -> void:
	WorldModels.add_to(self, Vector3.ZERO, 42.0)
	WorldModels.ground_after_physics($TrainingDummy)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("20252a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7b8389")
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color("555961")
	env.fog_density = 0.018
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = env
	add_child(atmosphere)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_color = Color("c9b4a6")
	sun.light_energy = 0.8
	add_child(sun)
	var layer := CanvasLayer.new()
	add_child(layer)
	var instructions := Label.new()
	instructions.position = Vector2(20, 20)
	instructions.text = "TRAINING ARENA  ·  Move with the joystick; drag to look" if OS.has_feature("mobile") else "ASHEN REACHES  /  TRAINING ARENA\nWASD move  •  Mouse orbit  •  Shift run  •  Space jump  •  C dodge\nLeft click light attack  •  Right click heavy attack  •  Q lock on  •  Esc cursor"
	instructions.add_theme_font_size_override("font_size", 16)
	layer.add_child(instructions)

